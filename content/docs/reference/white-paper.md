---
title: "Technical White Paper"
description: "How tzf achieves high-performance timezone lookup — polygon simplification, topology-aware processing, tile-based indexing, and YStripes."
summary: "Design rationale and implementation details behind tzf's data pipeline and spatial indexing strategy."
date: 2025-07-21T14:20:56+09:00
lastmod: 2026-04-26T00:00:00+09:00
draft: false
weight: 1
toc: true
seo:
  title: "Technical White Paper — Project tzf"
  description: "How tzf achieves fast timezone lookup: polygon simplification, topology-aware processing, Polyline encoding, tile-based indexing, and YStripes index."
  noindex: false
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

This white paper covers the four core techniques used in tzf:

1. Polygon simplification
2. Topology-aware simplification
3. Tile-based indexing (FuzzyFinder pre-index)
4. YStripes spatial index

## Polygon simplification

First, we converted the GeoJSON polygon data into a binary encoding using
Protocol Buffers, reducing the file size by approximately 80 MB:

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

This conversion still required about 900 MB of memory to load. To further
optimize, we applied the
[Ramer–Douglas–Peucker (RDP) algorithm][Ramer–Douglas–Peucker_algorithm]
to simplify polygon shapes by reducing the number of points:

[Ramer–Douglas–Peucker_algorithm]: https://en.wikipedia.org/wiki/Ramer–Douglas–Peucker_algorithm

![The effect of varying epsilon in a parametric implementation of RDP, [source](https://en.wikipedia.org/wiki/File:RDP,_varying_epsilon.gif)](/img/history-of-tzf/RDP_varying_epsilon.gif)

After filtering, the data size dropped to approximately 11 MB. We then applied
Google Maps' Polyline encoding algorithm to compress coordinate sequences into
a compact ASCII representation, reducing the file to about 4.6 MB.

If you want to see the actual simplification parameters, refer to
[the code](https://github.com/ringsaturn/tzf/blob/aa625496b23f1e6af92e9b457394bc3e4dc19bbf/reduce/reduce.go#L18).

## Topology-aware simplification

The original per-polygon RDP approach had a fundamental problem ([tzf#183](https://github.com/ringsaturn/tzf/issues/183)):
adjacent timezone polygons share edges, but each polygon was simplified independently.
This caused gaps and overlaps at boundaries that were invisible in the raw data but
appeared after simplification.

The fix: detect shared edges first, simplify them once, then substitute the
simplified version back into both adjacent polygons. Neighboring polygons now always
reference the same simplified boundary, preventing new gaps or overlaps from forming.

This topology-aware approach was completed in Spring 2026. Its implementation is
documented in [`internal/topology/README.md`](https://github.com/ringsaturn/tzf/blob/v1.1.0/internal/topology/README.md).

The results of combining topology-aware simplification with shared-edge storage
(each shared edge stored only once) and Polyline compression are significant:

| Dataset                   | Format                    | Size  |
| ------------------------- | ------------------------- | ----- |
| Full precision            | `CompressedTopoTimezones` | ~17 MB |
| Topology-simplified (lite)| `CompressedTopoTimezones` | ~5.4 MB |
| Tile preindex             | `PreindexTimezones`       | ~2 MB  |

The full-precision dataset shrank from ~90 MB (raw protobuf) to ~17 MB — small
enough that tzf-rs now provides it as an optional Cargo feature rather than
requiring a manual file download.

These files are distributed via [`ringsaturn/tzf-dist`](https://github.com/ringsaturn/tzf-dist).

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

![Tile-based timezone index demo (not the real data being used). A live demo showing polygons and their index is available via [tzf-web][tile_index_live_view]](/img/history-of-tzf/preindex-timezone-preview-we.png)

[tile_index_live_view]: https://ringsaturn.github.io/tzf-web/?markers=%5B%7B%22lat%22%3A52.2076%2C%22lng%22%3A9.668%7D%5D&lat=50.310392&lng=11.887207&zoom=6&showIndex=true

The preindex stores only tiles that fall **entirely within** a single timezone polygon.
A tile is added to the index only when it is completely contained by one timezone —
boundary tiles that straddle multiple polygons are intentionally excluded.

When querying a point:
- If the point falls in a covered tile → the timezone is known immediately, with no polygon test needed.
- If the point falls outside any covered tile (near a border, on a coastline, or in a sparse region) → the preindex returns nothing.

`FuzzyFinder` uses this preindex alone. Its results are accurate for covered tiles, but it returns no
result rather than guessing for uncovered areas — the caller is responsible for handling the empty case.

`DefaultFinder` handles this automatically: it tries the tile preindex first; if no result is returned,
it falls through to full polygon lookup via `Finder`. This makes it correct for all coordinates while
retaining preindex speed for the majority of world-city queries.

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
