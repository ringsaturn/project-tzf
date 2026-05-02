---
date: '2025-07-21T14:20:56+09:00'
description: How tzf achieves high-performance timezone lookup — topology-aware simplification, shared-edge deduplication, Polyline encoding, tile-based indexing, and YStripes.
draft: false
lastmod: '2026-04-27T00:00:00+09:00'
seo:
  description: 'How tzf achieves fast timezone lookup: topology-aware simplification, shared-edge deduplication, Polyline encoding, tile-based indexing, and YStripes index.'
  noindex: false
  title: Technical White Paper — Project tzf
summary: Design rationale and implementation details behind tzf's data pipeline and spatial indexing strategy.
title: Technical White Paper
toc: true
weight: 1
---

## Introduction

In the beginning, tzf was designed for backend services that need to convert
coordinates to timezones, mostly for geo and weather services.

As the project evolved, we needed to add Python support since timezonefinder's
speed around borders could not satisfy our needs back then.

That's why tzf (Go), tzfpy (Python), and tzf-rs (Rust) were created.

The design goals are:

- Convert coordinates to timezones.
- Performance is more important than perfect accuracy.
- At least support Go and Python. (Rust was developed because of PyO3's ecosystem.)
- Minimal distribution/binary size for backend services.

This white paper covers the five core techniques used in tzf:

1. Topology-aware simplification (data pipeline stage 1)
2. Shared-edge deduplication (data pipeline stage 2)
3. Polyline encoding (data pipeline stage 3)
4. Tile-based indexing (FuzzyFinder pre-index)
5. YStripes spatial index

## Data pipeline overview

The raw timezone boundary data starts at ~96 MB as a Protocol Buffers binary
(`Timezones` format). Two parallel offline pipelines produce three distribution
files (file names carry the `combined-with-oceans.` prefix):

**Full-precision pipeline** — dedup + compress only, no simplification:

```
Raw .bin                    (96 MB,   Timezones)
  ↓ shared-edge deduplication
.topo.bin                   (54.6 MB, TopoTimezones,              −43%)
  ↓ Polyline delta encoding
.compress.topo.bin          (17 MB,   CompressedTopoTimezones,    −82%)  ← embedded (full)
```

**Lite pipeline** — topology-aware simplification + dedup + compress, with a
preindex branch:

```
Raw .bin                              (96 MB,   Timezones)
  ↓ topology-aware D-P simplification
.topology.bin                         (12.5 MB, Timezones,              −87%)
  ├─→ preindextzpb → .topology.preindex.bin  (2.0 MB)  ← embedded (preindex)
  ↓ shared-edge deduplication
.topology.topo.bin                    (10.0 MB, TopoTimezones,          −90%)
  ↓ Polyline delta encoding
.topology.compress.topo.bin           ( 5.4 MB, CompressedTopoTimezones,−94%)  ← embedded (lite)
```

The resulting distribution files are:

| File | Format | Size |
| ---- | ------ | ---- |
| `combined-with-oceans.compress.topo.bin` | `CompressedTopoTimezones` | ~17 MB |
| `combined-with-oceans.topology.compress.topo.bin` | `CompressedTopoTimezones` | ~5.4 MB |
| `combined-with-oceans.topology.preindex.bin` | `PreindexTimezones` | ~2 MB |

The full-precision dataset shrank from ~96 MB (raw protobuf) to ~17 MB — small
enough that tzf-rs now provides it as an optional Cargo feature rather than
requiring a manual file download.

These files are distributed via [`ringsaturn/tzf-dist`](https://github.com/ringsaturn/tzf-dist).

## Stage 1 — Topology-aware simplification

### Background: the per-polygon approach and its limits

The raw GeoJSON polygon data is first converted into a binary encoding using
Protocol Buffers. The schema is straightforward:

```proto
message Point {
  float lng = 1;
  float lat = 2;
}

message Polygon {
  repeated Point points = 1;
  repeated Polygon holes = 2;
}

message Timezone {
  repeated Polygon polygons = 1;
  string name = 2;
}

message Timezones {
  repeated Timezone timezones = 1;
}
```

Even after this conversion the data still requires roughly 900 MB of memory
to load. The natural first step is to apply the
[Ramer–Douglas–Peucker (RDP) algorithm][Ramer–Douglas–Peucker_algorithm]
to reduce the number of points in each polygon:

[Ramer–Douglas–Peucker_algorithm]: https://en.wikipedia.org/wiki/Ramer–Douglas–Peucker_algorithm

![The effect of varying epsilon in a parametric implementation of RDP, [source](https://en.wikipedia.org/wiki/File:RDP,_varying_epsilon.gif)](/img/history-of-tzf/RDP_varying_epsilon.gif)

Applying RDP independently to each polygon shrank the data to about 11 MB.
However, this naive approach had a fundamental correctness problem
([tzf#183](https://github.com/ringsaturn/tzf/issues/183)): adjacent timezone
polygons share edges, but each polygon is simplified in isolation. Because D-P
removes different intermediate points from each side of a shared boundary, the
two polygons end up with slightly different edge shapes — producing gaps and
overlaps that are invisible in the raw data but appear after simplification.
The `DefaultFinder`'s ±0.02° spatial-tolerance fallback was a workaround for
this, not a real fix.

### Topology-aware approach

The fix is to integrate RDP simplification into a topology-aware pipeline that
processes shared boundaries consistently across all adjacent polygons. Before
any simplification takes place, a topology graph is built over all polygon rings:

1. **Normalize windings** (CCW exterior, CW holes) so adjacent rings traverse a
   shared boundary in opposite directions — this is what makes reverse-edge
   matching reliable.
2. **Remove zero-length edges** from source data (some rings contain duplicate
   adjacent vertices that break shared-edge detection).
3. **Snap T-junction vertices**: if a topology node falls on the interior of an
   adjacent edge, insert it as a new vertex before analysis begins.
4. **Detect shared edges** via canonical-key hashing. Classify each segment:
   - *Fixed*: vertices where three or more rings meet. These anchor points must
     not move.
   - *Shared segment interior*: free to be simplified, but only once — all
     partner rings reuse the same simplified result.
   - *Non-shared*: simplified independently (coastlines, standalone boundaries).
5. **Enclave rings** (a hole whose shape equals an inner timezone's exterior)
   are handled specially: both partner rings rotate to the lexicographically
   smallest vertex (canonical start) and enter a shared simplification cache,
   guaranteeing identical output without any fixed vertices.
6. **Fallback**: rings that simplify to fewer than 3 unique points, produce
   zero-length edges, or (for small rings ≤ 100 pts) are self-intersecting
   revert to the original unmodified input ring.

This topology-aware approach was completed in Spring 2026. Its implementation
is documented in
[`internal/topology/README.md`](https://github.com/ringsaturn/tzf/blob/v1.1.0/internal/topology/README.md).

**Result**: 86% point reduction (8 M → 1.09 M points) with topologically
consistent shared boundaries — no gaps, no unintended overlaps.

## Stage 2 — Shared-edge deduplication

After simplification, long shared boundary segments still appear twice in the
file — once per adjacent timezone ring. The `deduplicatetzpb` tool converts
the `Timezones` binary into a `TopoTimezones` format that stores each shared
segment only once:

- A global `SharedEdge` library indexes each long shared boundary segment by ID.
- Each ring becomes a sequence of `RingSegment` entries: either a short inline
  point sequence (≤ 10 pts) or a forward/reversed reference to a `SharedEdge` ID.

Winding normalization must run before this step for the same reason it must
run before simplification: only when adjacent rings traverse their shared
boundary in opposite directions does the deduplication recognise them as the
same edge (rather than classifying them as disputed-territory same-direction
overlaps).

**Result on the simplified data**: ~20% further size reduction
(12.5 MB → 10.0 MB). The `TopoTimezones` format also round-trips cleanly back
to full polygons, which makes it a useful interchange format for downstream
tools.

## Stage 3 — Polyline encoding

The final offline stage applies Google Maps' Encoded Polyline algorithm to
compress the coordinate sequences stored in `TopoTimezones`. Geographically
sequential points have small deltas, so delta + zig-zag encoding achieves
roughly 45% additional compression on the simplified and deduplicated data.

Shared-edge point sequences and inline segment points are delta-encoded;
edge ID references (int32 forward/reversed references) pass through unchanged.

**Result**: 10.0 MB → 5.4 MB (`CompressedTopoTimezones`), for a combined
pipeline reduction of 94% from the raw 96 MB source.

## Tile-based indexing

A naïve Ray Casting approach operates in O(n²) time, which is unsuitable for
high-concurrency backend services. We considered spatial R-trees but found
minimal performance gains given the small number of global time zones and their
uneven area distributions.

Instead, we adopted a tile-based indexing scheme inspired by map tile formats
used in weather data services. Each tile defines a quadrilateral region at a
given zoom level:

```txt
┌───────────┬───────────┬───────────┐
│           │           │           │
│           │           │           │
│ x-1,y-1,z │ x+0,y-1,z │ x+1,y-1,z │
│           │           │           │
│           │           │           │
├───────────┼───────────┼───────────┤
│           │           │           │
│           │           │           │
│ x-1,y+0,z │ x+0,y+0,z │ x+1,y+0,z │
│           │           │           │
│           │           │           │
├───────────┼───────────┼───────────┤
│           │           │           │
│           │           │           │
│ x-1,y+1,z │ x+0,y+1,z │ x+1,y+1,z │
│           │           │           │
│           │           │           │
└───────────┴───────────┴───────────┘
```

This quadtree-like layout ensures parent tiles contain exactly four child tiles,
allowing aggregation without gaps:

![Tile-based timezone index demo. A live demo showing polygons and their index is available via [tzf-web][tile_index_live_view]](/img/preindex-timezone-preview-berlin.webp)

[tile_index_live_view]: https://ringsaturn.github.io/tzf-web/?markers=%5B%7B%22lat%22%3A52.2076%2C%22lng%22%3A9.668%7D%5D&lat=50.310392&lng=11.887207&zoom=6&showIndex=true

Each timezone is processed independently. For each timezone:

1. Generate all tiles at the index zoom level (zoom 13) that touch the polygon.
2. Keep only tiles that fall **entirely within** the polygon (`EnsureInside`).
3. Drop edge tiles — tiles where any of the 8 surrounding neighbors are absent from the
   set. This step is applied twice (`dropEdgeLayer = 2`), peeling back two layers from
   the interior boundary so that tiles near the polygon edge are excluded.
4. Merge the remaining tiles upward to the aggregation zoom level (zoom 3) via
   `MergeUp`, then apply `EnsureInside` again on the merged result.

Because each timezone is indexed independently, a tile that falls inside **multiple**
timezones appears in all of their index entries. The in-memory map is
`map[Tile][]string`, so a single tile can return several timezone names. This handles
shared areas such as Asia/Shanghai and Asia/Urumqi, whose overlapping interior region
generates matching tiles in both timezones' preindex entries.

When querying a point, the lookup walks from the coarsest zoom (3) to the finest (13)
and returns all timezone names at the first matching tile:
- If a matching tile is found → return its timezone list (one name for unambiguous
  interior tiles, multiple names for shared-area tiles).
- If no tile matches (border region, coastline, sparse area) → the preindex returns
  nothing.

`FuzzyFinder` uses this preindex alone. `GetTimezoneNames` returns the full list;
`GetTimezoneName` returns the first entry. For uncovered areas it returns an error
rather than guessing — the caller is responsible for handling the empty case.

`DefaultFinder` handles this automatically: it tries the tile preindex first; if no
result is returned, it falls through to full polygon lookup via `Finder`. This makes
it correct for all coordinates while retaining preindex speed for the majority of
world-city queries.

## YStripes index

Starting from tzf v1.1.0 (Go) and tzf-rs v1.2.0 (Rust), the polygon-level point-in-polygon
test uses a YStripes spatial index, ported from Josh Baker's
[`tidwall/tg`](https://github.com/tidwall/tg) project.

YStripes improves on naive ray casting by pre-partitioning each polygon's edges into
horizontal stripes. For a query point, only edges in the relevant stripe are tested,
reducing per-polygon work substantially without the overhead of a full spatial tree.

This is enabled by default; disabling it (e.g. in memory-constrained environments)
is possible via `FinderOptions` in Rust. With YStripes, single random-city lookups
consistently run below 1 µs on modern hardware with `DefaultFinder`.

For algorithm details, see the author's explanation in
[`POLYGON_INDEXING.md`](https://github.com/tidwall/tg/blob/main/docs/POLYGON_INDEXING.md).
