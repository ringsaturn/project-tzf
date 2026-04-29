---
date: '2025-07-21T21:09:40+09:00'
description: Reference of project-specific terms and concepts in the tzf ecosystem.
draft: false
lastmod: '2026-04-29T00:00:00+09:00'
seo:
  description: 'Reference of tzf-specific terms: Finder classes, tzf-dist data files, polygon simplification, topology-aware processing, tile indexing, YStripes, and memory usage.'
  noindex: false
  title: Terminology — Project tzf
summary: Finder classes, data files, algorithms, and performance reference for tzf.
title: Terminology
toc: true
weight: 3
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

## Finder Classes

### FuzzyFinder {#fuzzyfinder}

Uses the tile preindex only. Each tile in the index covers an area that lies **entirely within** a single timezone polygon.

- Point falls in a covered tile → returns the correct timezone immediately, no polygon test needed.
- Point falls outside any covered tile (near borders, coastlines, sparse regions) → **returns nothing**.

Results are accurate for covered tiles; the caller must handle the empty case.
Fastest option (~470 ns / ~9 MB) but does not cover all coordinates.

### Finder {#finder}

Full polygon lookup using the topology-simplified dataset with YStripes index.
Covers all global coordinates (~1–2 µs, ~66 MB).

### DefaultFinder {#defaultfinder}

Combines FuzzyFinder and Finder: consults the tile preindex first; if no result is returned,
falls through to full polygon lookup. Delivers preindex speed for the majority of well-interior
queries while remaining correct everywhere (~1 µs, ~75 MB). **Recommended for most use cases.**

### Data Version {#data-version}

Version identifier for the timezone boundary data, e.g. `"2025b"`. Tracks
[IANA timezone database](https://www.iana.org/time-zones) releases via
[evansiroky/timezone-boundary-builder](https://github.com/evansiroky/timezone-boundary-builder).
Accessible at runtime via `data_version()` (Python), `DataVersion()` (Go), or `data_version()` (Rust).

## Data Files

### tzf-dist {#tzf-dist}

Current data distribution repository ([`ringsaturn/tzf-dist`](https://github.com/ringsaturn/tzf-dist)),
introduced in Spring 2026. Distributes processed binary data as both a Go module and a Rust crate.
Replaces the older `tzf-rel` / `tzf-rel-lite` repositories (planned for deprecation).

### Data Files {#data-files}

Three binary files shipped by `tzf-dist`, all in `CompressedTopoTimezones` format:

| File | Size | Purpose |
| --- | --- | --- |
| `combined-with-oceans.compress.topo.bin` | ~17 MB | Full-precision data |
| `combined-with-oceans.topology.compress.topo.bin` | ~5.4 MB | Topology-simplified (default) |
| `combined-with-oceans.topology.preindex.bin` | ~2 MB | Tile preindex for FuzzyFinder |

### tzf-rel / tzf-rel-lite (deprecated) {#tzf-rel}

Previous data distribution repositories, now superseded by `tzf-dist`.
Still functional but no longer receiving updates.

## Algorithms & Indexing

### Polygon Simplification {#polygon-simplification}

Applies the [Ramer–Douglas–Peucker (RDP)](https://en.wikipedia.org/wiki/Ramer%E2%80%93Douglas%E2%80%93Peucker_algorithm)
algorithm to reduce the number of points in timezone boundary polygons.
Shrinks the raw protobuf data from ~900 MB in-memory to ~11 MB on disk, with acceptable accuracy loss
(results may be incorrect within ~1 km of a border).

### Topology-Aware Simplification {#topology-aware}

Enhancement to per-polygon RDP that fixes the gap/overlap problem at shared borders
([tzf#183](https://github.com/ringsaturn/tzf/issues/183)).

Shared edges between adjacent polygons are detected first, simplified once, then substituted back
into both polygons — preventing simplification from creating new gaps or overlaps.
Introduced in tzf v1.1.0 (Spring 2026). Implementation details:
[`internal/topology/README.md`](https://github.com/ringsaturn/tzf/blob/v1.1.0/internal/topology/README.md).

### Tile-Based Indexing {#tile-indexing}

Precomputed spatial index used by `FuzzyFinder`. Earth's surface is partitioned into
quadrilateral tiles at a fixed zoom level (inspired by map tile formats). A tile is added to
the index only when it is completely contained by one timezone polygon — boundary tiles are
intentionally excluded. Enables O(1) pre-filtering without polygon testing for interior points.

### YStripes Index {#ystripes}

Per-polygon spatial index ported from Josh Baker's [`tidwall/tg`](https://github.com/tidwall/tg).
Partitions each polygon's edges into horizontal stripes; only edges in the matching stripe are
tested for a given query point. Default since tzf v1.1.0 (Go) and tzf-rs v1.2.0 (Rust).
Brings single random-city lookup to ~1 µs on modern hardware.
Algorithm details: [`POLYGON_INDEXING.md`](https://github.com/tidwall/tg/blob/main/docs/POLYGON_INDEXING.md).

## Performance

### Memory Usage {#memory-usage}

Approximate figures for the Go implementation (Rust is similar):

| Mode | Memory |
| --- | --- |
| DefaultFinder (topology-simplified + preindex) | ~75 MB |
| Finder (topology-simplified) | ~66 MB |
| FullFinder (full-precision + preindex) | ~422 MB |
| FullFinder (full-precision only) | ~413 MB |

Rust with YStripes index adds ~30–40 MB above the no-index baseline.
Full-precision mode in Rust (with YStripes) requires ~560 MB.
Python (tzfpy) uses the Rust binary internally; expect ~120 MB for the default mode.

## Internals

### CGO vs PyO3 {#cgo-pyo3}

tzfpy originally called the Go implementation via CGO, compiled to a `.so` file.
Since v0.11.0 it uses [PyO3](https://pyo3.rs/) to wrap tzf-rs (Rust) instead.
PyO3 removes the need to manually manage object lifetimes across the FFI boundary,
eliminating the memory leak ([tzf#63](https://github.com/ringsaturn/tzf/pull/63))
that CGO caused, and delivers better throughput for CPU-intensive workloads.
