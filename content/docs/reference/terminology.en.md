---
date: '2025-07-21T21:09:40+09:00'
description: Reference of project-specific terms and concepts in the tzf ecosystem.
draft: false
lastmod: '2026-09-11T00:00:00+09:00'
seo:
  description: 'Reference of tzf-specific terms: finders, the .tzb and .tzm file formats, FUZZY preindex, E and M profiles, in-place and expanded loading, polygon simplification, tile indexing, and YStripes.'
  noindex: false
  title: Terminology — Project tzf
summary: Finders, file formats, algorithms, and performance reference for tzf.
title: Terminology
toc: true
weight: 4
---

## API Behavior

### Coordinate Order {#coordinate-order}

All tzf implementations use **(longitude, latitude)** order — consistent with GeoJSON and most geo APIs.
Note that some systems (Google Maps URLs, many textbooks) use (latitude, longitude), so double-check before passing values.

### Multiple Timezones {#multiple-timezones}

Locations near timezone boundaries may belong to more than one timezone.
Use the multi-result API to retrieve all candidates:

| Language | Function |
| --- | --- |
| Go | `GetTimezoneNames()` |
| Rust | `get_tz_names()` |
| Python | `get_tzs()` |
| Swift | `getTimezones()` |

## Finders

v2 exposes finders through constructors that return an interface. The v1
`Finder` / `FuzzyFinder` / `DefaultFinder` classes are described under
[v1 terms](#v1-terms).

### Default finder {#defaultfinder}

Go `NewDefaultFinder()`, Rust `DefaultFinder::new()`. Reads the lite dataset with
the FUZZY preindex as the fast path and polygon geometry behind it. In Go the
polygon storage aliases the `.tzm` memory image in place: ~12 MB heap plus ~10 MB
of read-only data, 298 ns per query on an Apple M3 Max against the `2026c`
dataset. In Rust the same constructor expands `lite.tzb` into polygons and
reports ~46 MiB peak RSS with 236 ns queries.

### Embedded finder {#embeddedfinder}

Go `NewEmbeddedFinder()`, Rust `EmbeddedFinder::new()`. Queries the lite `.tzb`
in place, holding under 1 KB of heap beyond the file bytes. Query latency is
microseconds when the preindex does not cover the point. Applies to embedded
targets, memory-limited processes, and no-filesystem deployments.

### Full finder {#fullfinder}

Go `NewFullFinder()`, Rust `DefaultFinder::new_full()`. Reads the full-precision
dataset expanded into memory: ~145 MB resident in Go. Results match the
unsimplified boundary data.

### Data Version {#data-version}

Version identifier for the timezone boundary data, e.g. `"2026c"`. Tracks
[IANA timezone database](https://www.iana.org/time-zones) releases via
[evansiroky/timezone-boundary-builder](https://github.com/evansiroky/timezone-boundary-builder).
Accessible at runtime via `data_version()` (Python), `DataVersion()` (Go), or
`data_version()` (Rust). All three tzf-dist artifacts carry the same value.

## Data Format

### `.tzb` {#tzb}

A TZF embedded binary file in the E profile: the compact transport format, with
geometry stored as chunked zigzag-LEB128 varint streams. Consumed by every
implementation. See
[Embedded Binary Format]({{< relref "embedded-binary-format" >}}).

### `.tzm` {#tzm}

A TZF embedded binary file in the M profile: the same data with geometry stored
as one flat array of `(int32, int32)` pairs, so the file layout matches the
query-time structure. Read by the Go implementation; tzf-rs returns
`Error::Profile` for such files. Generated on the host that uses it with tzf's
`cmd/tzb2tzm`.

### Profile E / Profile M {#profiles}

The header byte at offset 48 selects the layout of a TZF embedded binary file:
`0` for E (embedded, `.tzb`), `1` for M (memory image, `.tzm`). Mandatory
sections differ per profile, and cross-profile section types are rejected.

### FUZZY section {#fuzzy}

Section type 10, the tile preindex stored as one sorted array of packed tile IDs
with their timezone indices. Present in all three tzf-dist artifacts. It is the
fast path for single-name queries; the multi-result API does not consult it. On
the `2026c` dataset it holds 87,572 tiles, 156 of which name two timezones, in
about 880 KB.

### In-place versus expanded loading {#in-place-expanded}

**In place:** the finder reads geometry out of the file bytes as each query needs
it. No decode at open, minimal heap, microsecond queries on a preindex miss.
Go `NewEmbeddedFinder`, `x.NewFinderFromTZBReaderAt`, Rust `EmbeddedFinder`.

**Aliased in place:** the M profile stores points in the query-time layout, so
ring storage points directly at the mapped bytes with no decode and no copy. The
source bytes must stay live and unmodified. Go `NewFinderFromTZM`.

**Expanded:** the file is decoded into polygon objects at open. Higher open cost
and higher resident memory, nanosecond queries. Go `NewFinderFromTZB`,
`NewFullFinder`, Rust `DefaultFinder`.

## Data Files

### tzf-dist {#tzf-dist}

Current data distribution repository
([`ringsaturn/tzf-dist`](https://github.com/ringsaturn/tzf-dist)), introduced in
Spring 2026. Distributes processed binary data as both a Go module and a Rust
crate. Replaces the `tzf-rel` / `tzf-rel-lite` repositories.

### Data Files {#data-files}

Three files shipped by `tzf-dist`, all in the
[TZF embedded binary format]({{< relref "embedded-binary-format" >}}) 1.1 and all
carrying a FUZZY section and the same `data_version`:

| File | Profile | Size | Purpose |
| --- | --- | --- | --- |
| `lite.tzb` | E | ~4 MB | Topology-simplified data; the crates.io and PyPI payload |
| `lite.tzm` | M | ~10 MB | Memory image of the same data, read by Go `NewDefaultFinder` |
| `full.tzb` | E | ~14 MB | Full-precision data; git-only in the Rust crate |

`full.tzm` is not published: expanding the full dataset into the M layout
produces about 67 MB.

### tzf-rel / tzf-rel-lite (retired) {#tzf-rel}

Previous data distribution repositories, superseded by `tzf-dist`. The protobuf
artifacts they carried are no longer published.

### v1 terms {#v1-terms}

Terms that apply to the v1 line (tzf v1.2.x, tzf-rs 1.3.x, tzfpy 1.3.x), which is
frozen at its last protobuf data release:

| Term | Meaning in v1 | v2 equivalent |
| --- | --- | --- |
| `FuzzyFinder` | Tile-preindex-only finder; returned no result outside covered tiles | Removed; the preindex is the fast path inside every finder |
| `Finder` | Polygon-only finder | Default finder; the multi-result API stays polygon-exact |
| `DefaultFinder` | Preindex with polygon fallback | Default finder, same role |
| `CompressedTopoTimezones` | Protobuf message carrying deduplicated, polyline-encoded geometry | `.tzb` / `.tzm` |
| `PreindexTimezones` | Protobuf message carrying the tile preindex | FUZZY section |

## Algorithms & Indexing

### Polygon Simplification {#polygon-simplification}

Applies the [Ramer–Douglas–Peucker (RDP)](https://en.wikipedia.org/wiki/Ramer%E2%80%93Douglas%E2%80%93Peucker_algorithm)
algorithm to reduce the number of points in timezone boundary polygons. The v2
lite dataset uses an epsilon of 0.001 degrees, which caps boundary displacement at
111.2 m as certified in
[BORDER_CHANGE.md](https://github.com/ringsaturn/tzf/blob/main/BORDER_CHANGE.md).

### Topology-Aware Simplification {#topology-aware}

Enhancement to per-polygon RDP that fixes the gap/overlap problem at shared borders
([tzf#183](https://github.com/ringsaturn/tzf/issues/183)).

Shared edges between adjacent polygons are detected first, simplified once, then substituted back
into both polygons — preventing simplification from creating new gaps or overlaps.
Introduced in tzf v1.1.0 (Spring 2026). Implementation details:
[`internal/topology/README.md`](https://github.com/ringsaturn/tzf/blob/v1.1.0/internal/topology/README.md).

### Tile-Based Indexing {#tile-indexing}

Precomputed spatial index, stored in v2 as the [FUZZY section](#fuzzy). Earth's
surface is partitioned into quadrilateral tiles at a fixed zoom level, following
map tile formats. A tile enters the index only when one timezone polygon contains
it completely; boundary tiles are excluded. Interior points are then resolved by
tile lookup without a polygon test.

### YStripes Index {#ystripes}

Per-polygon spatial index ported from Josh Baker's [`tidwall/tg`](https://github.com/tidwall/tg).
Partitions each polygon's edges into horizontal stripes; only edges in the matching stripe are
tested for a given query point. Default since tzf v1.1.0 (Go) and tzf-rs v1.2.0 (Rust);
in v2 it is always on, and the `.tzm` loader rebuilds it in parallel at open.
Section type 14 of the embedded binary format reserves a serialized form of the
index, which is not emitted today.
Algorithm details: [`POLYGON_INDEXING.md`](https://github.com/tidwall/tg/blob/main/docs/POLYGON_INDEXING.md).

## Internals

### CGO vs PyO3 {#cgo-pyo3}

tzfpy originally called the Go implementation via CGO, compiled to a `.so` file.
Since v0.11.0 it uses [PyO3](https://pyo3.rs/) to wrap tzf-rs (Rust) instead.
PyO3 removes the need to manually manage object lifetimes across the FFI boundary,
eliminating the memory leak ([tzf#63](https://github.com/ringsaturn/tzf/pull/63))
that CGO caused, and delivers better throughput for CPU-intensive workloads.
