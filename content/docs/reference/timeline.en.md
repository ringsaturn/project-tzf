---
date: '2025-07-21T10:52:43+09:00'
description: Project tzf development history — from the initial Go implementation through the 2026 Spring updates.
draft: false
lastmod: '2026-04-26T00:00:00+09:00'
seo:
  description: Development timeline for Project tzf — from the first Go release in 2022 through the v1.0.0 stable release in 2025.
  noindex: false
  title: Timeline — Project tzf
summary: Chronological history of key milestones in the tzf ecosystem.
title: Timeline
toc: true
weight: 5
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
