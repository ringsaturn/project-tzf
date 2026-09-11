---
date: '2025-07-19T11:07:00+09:00'
description: Frequently asked questions about Project tzf — accuracy, memory, coordinate order, and more.
draft: false
lastmod: '2026-09-11T00:00:00+09:00'
seo:
  description: Frequently asked questions about Project tzf — accuracy, memory usage, coordinate order, and data updates.
  noindex: false
  title: FAQ — Project tzf
summary: Answers to common questions about tzf's design, limitations, and usage.
title: FAQ
toc: true
weight: 95
---

## What is the coordinate order?

All tzf implementations use **(longitude, latitude)** order — the same as GeoJSON and most geo APIs.
Note that some systems (e.g. Google Maps URLs, many geographic textbooks) use (latitude, longitude) instead, so double-check before passing values.

## Is tzf 100% accurate?

The default finder is not guaranteed to match the full-precision dataset near timezone boundaries. It applies topology-aware [Douglas-Peucker simplification](https://en.wikipedia.org/wiki/Ramer%E2%80%93Douglas%E2%80%93Peucker_algorithm) with an epsilon of 0.001 degrees, which limits boundary displacement to roughly 111 m.

Measurements against the full-precision 2026c dataset are documented in [BORDER_CHANGE.md](https://github.com/ringsaturn/tzf/blob/main/BORDER_CHANGE.md):

| Metric                                            | Result                         |
| ------------------------------------------------- | ------------------------------ |
| Certified maximum boundary displacement           | 111.7 m, with 1.0 m tolerance  |
| Boundary length displaced more than 100 m         | 0.41%                          |
| Boundary length displaced more than 500 m         | 0%                             |
| Total mis-assigned area                           | 16,962 km², about 0.003% of Earth |
| Mis-assigned area within 100 m of the true border | 92.8%                          |

Only queries within roughly 111 m of a timezone boundary can differ from the full-precision result, and most of the affected band is much narrower.

For 100% accurate lookups, use the full dataset:

- **Go**: `tzf.NewFullFinder()`
- **Rust**: enable the git-only `full` feature with `default-features = false` (see [Getting Started]({{< relref "getting-started#rust" >}}))
- **Python/tzfpy**: full-precision mode is not currently supported

In the [tz-benchmark](https://github.com/ringsaturn/tz-benchmark) 2026-09-11
snapshot, the lite finders disagreed with full-precision ground truth on 1 of
154,694 world cities (0.0006%), and that single disagreement resolves to the
same UTC offset.

## How much memory does tzf use?

Initialization cost and runtime cost are not the same number. Building a finder
allocates far more than the finder ends up holding: the file is decoded, the
query structures are built from it, and the intermediate is then garbage — but
freeing memory does not shrink RSS, because the allocator keeps the pages mapped
for reuse. So the steady-state data a finder retains is several times smaller
than the high-water mark reached while loading.

The figures below are from the
[2026-09-11 benchmark snapshot](https://github.com/ringsaturn/tz-benchmark/tree/main/snapshot),
measured on an Apple M3 Max against the `2026c` dataset. Each candidate runs in
an isolated child process.

| Implementation | Finder | Init peak | Live | RSS after load |
| -------------- | ------ | --------: | ---: | -------------: |
| Go | `NewDefaultFinder` (lite `.tzm`) | 43.4 MiB | 13.1 MiB | 43.4 MiB |
| Go | `NewEmbeddedFinder` (lite `.tzb` in place) | 8.7 MiB | 0.3 MiB | 9.1 MiB |
| Go | `NewFullFinder` (full `.tzb`) | 315.0 MiB | 147.0 MiB | 315.0 MiB |
| Rust | `DefaultFinder` | 46.8 MiB | 22.8 MiB | 46.8 MiB |
| Rust | `EmbeddedFinder` | 9.8 MiB | ~0 MiB | 9.8 MiB |
| Python | tzfpy (default finder) | 62.3 MiB | n/a | 62.2 MiB |

- **Init peak** is the high-water mark (`ru_maxrss`) reached while loading. This
  is what a container memory limit has to accommodate, or the process is killed
  at startup even though its steady state would have fit.
- **Live** is what the finder retains once it is ready to serve queries, from
  language-native accounting (Go `HeapAlloc` after a forced GC, Rust a counting
  global allocator). It is `n/a` for Python, whose data lives outside the Python
  heap. Rust's `EmbeddedFinder` shows ~0 because its data is the `'static`
  embedded slice, not heap.
- The runtime floors in the same harness are 4.7 MiB for Go, 5.8 MiB for Rust,
  and 22.4 MiB for the Python interpreter — subtract them before comparing
  across languages.

Size the container for the init peak, but expect the long-running cost to be the
live figure. Actual usage varies by platform, allocator, and dataset version.

## Why is initialization slow?

The first call to `NewDefaultFinder()` / `DefaultFinder::new()` loads and parses the binary timezone data.
This is a one-time cost — subsequent lookups are very fast.
Always initialize once and reuse the instance. See the language-specific guides for patterns using global variables or `lazy_static`.

## How often is the timezone data updated?

tzf tracks [IANA timezone database](https://www.iana.org/time-zones) releases via
[evansiroky/timezone-boundary-builder](https://github.com/evansiroky/timezone-boundary-builder).
Processed data is published in [ringsaturn/tzf-dist](https://github.com/ringsaturn/tzf-dist)
as `lite.tzb`, `lite.tzm`, and `full.tzb`, all carrying the same `data_version`.
Library releases follow within a short time of each upstream data release.

The older `tzf-rel` / `tzf-rel-lite` protobuf artifacts are no longer published.
The v1 library line (tzf v1.2.x, tzf-rs 1.3.x, tzfpy 1.3.x) keeps working, but is
frozen at its last protobuf data release — updated boundaries require moving to
v2.

## Which finder should I use?

v2 removed the standalone `FuzzyFinder`. The tile preindex is now the fast path
inside every finder whose data file carries a FUZZY section, which all three
tzf-dist artifacts do. A covering tile answers the query immediately; near a
border the finder falls back to point-in-polygon internally, so the caller has no
empty-result case to handle.

| Go constructor | Rust | Data | Resident | Query |
| --- | --- | --- | --- | --- |
| `NewDefaultFinder()` | `DefaultFinder::new()` | lite memory image / expanded lite | ~12 MB heap + 10 MB read-only (Go) | ~300 ns |
| `NewEmbeddedFinder()` | `EmbeddedFinder::new()` | lite file queried in place | ~3 MB (Go) | ~6 µs |
| `NewFullFinder()` | `DefaultFinder::new_full()` | full precision | ~145 MB (Go) | ~300 ns |

The package documentation names `NewDefaultFinder()` / `DefaultFinder::new()` as
the general-purpose finder. [Choosing a Finder]({{< relref "choosing-a-finder" >}})
records the measured figures for the remaining cases, including single-core pods
and no-filesystem targets.

## What happened to protobuf?

v2 removed it. Boundary data now ships as the TZF embedded binary format:
`.tzb` for transport, `.tzm` for the Go memory image. Both are laid out to be
queried directly, without first parsing the file into an object graph. That
layout is what `NewEmbeddedFinder` reads, and it reduced open times: on an Apple
M3 Max, the Go full-precision finder opens in 78.5 ms against 288 ms for the
protobuf path.

See [Embedded Binary Format]({{< relref "../reference/embedded-binary-format" >}})
for the format, and the language guides for the migration tables.

## What license does tzf use?

Code is MIT licensed. Timezone data (distributed via `tzf-dist`) is [ODbL](https://opendatacommons.org/licenses/odbl/),
the same as upstream [evansiroky/timezone-boundary-builder](https://github.com/evansiroky/timezone-boundary-builder).

See [Licenses]({{< relref "../reference/licenses" >}}) for details.
