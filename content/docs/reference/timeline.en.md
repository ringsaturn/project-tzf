---
date: '2025-07-21T10:52:43+09:00'
description: Project tzf development history, from the initial Go implementation through the v2 release in 2026.
draft: false
lastmod: '2026-09-11T00:00:00+09:00'
seo:
  description: Development timeline for Project tzf, from the first Go release in 2022 through the protobuf-free v2 release in 2026.
  noindex: false
  title: Timeline — Project tzf
summary: Chronological history of key milestones in the tzf ecosystem.
title: Timeline
toc: true
weight: 6
---

## 2022

### 2022-05-29

Repo <https://github.com/ringsaturn/tzf> created.

### 2022-08-01

First version [`v0.6.0`](https://pypi.org/project/tzfpy/0.6.0/) of tzfpy
released, based on Go's CGO feature.

### 2022-11-06

Designed tile based index for tzf.

### 2022-11-20

Release first version of <https://github.com/ringsaturn/tzf-rs>.

### 2022-11-21

Replace Go binding with Rust binding via PyO3, released as
[`0.10.0`](https://pypi.org/project/tzfpy/0.10.0/) of tzfpy.

tzfpy moved to its own repo <https://github.com/ringsaturn/tzfpy>.

## 2024

### 2024-04-22

Created <https://github.com/ringsaturn/tzf-wasm>, which is a WebAssembly version
of tzf-rs.

## 2025

### 2025-02-21

Created <https://github.com/ringsaturn/tzf-swift>, which is a Swift version of
tzf.

### 2025-03-24

Release v1.0.0 for tzf, tzf-rs, tzfpy, tzf-wasm, tzf-swift.

tzf-repos' API is stable now.

### 2025-05-03

Created <https://github.com/ringsaturn/pg-tzf>, which is a PostgreSQL extension
of tzf-rs.

## 2026

### 2026 Spring

**Topology-aware simplification** implemented in tzf v1.1.0, resolving a long-standing
issue ([tzf#183](https://github.com/ringsaturn/tzf/issues/183)) where independent
per-polygon RDP simplification created gaps and overlaps at shared timezone borders.
The new approach detects shared edges first, simplifies them once, and substitutes
the simplified boundary back into both adjacent polygons.

**New data distribution repository** [`ringsaturn/tzf-dist`](https://github.com/ringsaturn/tzf-dist)
introduced, distributing data in the new `CompressedTopoTimezones` format:

| File | Size | Description |
| --- | --- | --- |
| `combined-with-oceans.compress.topo.bin` | ~17 MB | Full precision |
| `combined-with-oceans.topology.compress.topo.bin` | ~5.4 MB | Topology-simplified (lite) |
| `combined-with-oceans.topology.preindex.bin` | ~2 MB | Tile preindex |

The full-precision dataset shrank from ~90 MB to ~17 MB, making it viable to ship
as an optional Cargo feature in tzf-rs v1.3.0 (`DefaultFinder::new_full()`).

**YStripes spatial index** (ported from [`tidwall/tg`](https://github.com/tidwall/tg))
becomes the default polygon-level index in tzf v1.1.0 (Go) and tzf-rs v1.2.0 (Rust).
Single random-city lookup: ~1 µs on Apple M3 Max.

Releases in this wave: tzf v1.1.0, tzf-rs v1.2.0 / v1.3.0, tzfpy v1.2.0 / v1.3.0,
tzf-dist v0.0.2026-a, geometry-rs v0.4.1.

Check blog post [tzf Spring 2026 Update]({{< ref "/blog/2026-spring-news/index.md" >}}) for more details.

### 2026-07-19

The TZF embedded binary format specification is marked Final at version 1.0
(see the [format reference](/docs/reference/embedded-binary-format/)). It
defines the `TZFB` container: a 64-byte header, a section table, section types 1
to 9, and a CRC32 footer, with geometry stored as chunked zigzag-LEB128 varint
streams. The layout allows a reader to answer a query without decoding the whole
file.

### 2026-08-16

Format 1.1 adds the pieces the v2 runtime needs: the `profile` byte at header
offset 48, section type 10 (`FUZZY`, the tile preindex), and the M profile with
section types 12 (`FLATPOINTS`), 13 (`FLATRINGDIR`) and 14 (`YSTRIPES`, assigned
and not emitted). Mandatory sections become per-profile.

### 2026-08-18

The v2 API is specified: five constructors returning `F`, no options, no exported
finder types, and `x` for surface outside the semantic-versioning promise. The
FUZZY fast path lands in the in-place finder the same day, taking its median
query on the lite file from 4.7 µs to 542 ns.

### 2026-08-28

Protobuf is removed from the tzf tree. The pipeline moves to native Go structs
with `encoding/gob` intermediates, which are build-internal and never
distributed. The module becomes `github.com/ringsaturn/tzf/v2` in place, with no
`v2/` subdirectory. tzf-rs is ported to the `.tzb` runtime in the same window;
its `.tzm` loader is measured, found to save about 3 ms of open time at higher
memory, and removed, so tzf-rs consumes the E profile only.

tzf-dist stops publishing the protobuf artifact set and ships `lite.tzb`,
`lite.tzm` and `full.tzb`. The v1 data line is frozen at its last protobuf
release.

Measured against the protobuf path on an Apple M3 Max with the `2026c` dataset:

| Path | Open | Resident | Query |
| --- | ---: | ---: | ---: |
| Go, full protobuf (v1) | 288 ms | ~153 MB | ~290 ns |
| Go, full `.tzb` expanded | 78.5 ms | ~145 MB | ~300 ns |
| Go, lite `.tzm` memory image | 7.7 ms | ~12 MB heap + 10 MB read-only | 298 ns |
| Go, lite `.tzb` in place | 1.7 ms | ~3 MB | ~6 µs |
| Rust, lite protobuf (v1) | 71 ms | 77.8 MiB peak RSS | 316 ns |
| Rust, lite `.tzb` | 18 ms cold | 44.1 MiB peak RSS | 260 ns |

### 2026-09

v2 releases for tzf (Go), tzf-rs (Rust) and tzfpy (Python). tzf-dist tagged
the first `.tzb`/`.tzm` artifact set, `v0.0.2026-c-tzb1`, on 2026-09-10; tzf
v2.0.0 followed the same day, and tzf-rs 2.0.0 and tzfpy 2.0.0 on 2026-09-11.
The Go module path gains the `/v2` suffix, tzf-rs reaches 2.0.0, and tzfpy
binds tzf-rs 2.0. The v1 lines (tzf v1.2.x, tzf-rs 1.3.x, tzfpy 1.3.x) remain
available and frozen at their last protobuf data release. tzf-swift and
tzf-wasm build on the v1 line at this date, as does the independently
maintained tzf-rb.
