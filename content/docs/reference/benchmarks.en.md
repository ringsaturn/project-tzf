---
date: '2025-07-19T13:58:16+09:00'
description: Performance, accuracy, and memory benchmarks for the tzf v2 implementations in Go, Rust, and Python.
draft: false
lastmod: '2026-09-14T00:00:00+09:00'
seo:
  description: Benchmark results for tzf v2 — query latency, accuracy against full-precision ground truth, and memory for the default, embedded, and full finders in Go, Rust, and Python.
  noindex: false
  title: Benchmarks — Project tzf
summary: Query latency, accuracy, and memory for the tzf v2 finders, from the 2026-09-14 tz-benchmark snapshot.
title: Benchmarks
toc: true
weight: 5
---

There are two benchmark setups with different purposes.

**Continuous benchmark** — source and results at
<https://github.com/ringsaturn/tz-benchmark>, visualized at
<https://ringsaturn.github.io/tz-benchmark/>. It runs in GitHub Actions on each
release for cross-package comparison. Runner hardware differs from a developer
machine, so absolute numbers differ from local runs while the relative ordering
between packages is comparable. The continuous run has covered tzf v2 since
2026-09-11.

**Dated snapshots** — the directories under
[`snapshot/`](https://github.com/ringsaturn/tz-benchmark/tree/main/snapshot) are
captured locally on an Apple M3 Max. Everything on this page comes from the
`2026-09-14` snapshot, measured against the published tzf v2.1.1 and tzf-rs 2.1.1
releases and the tzfpy 2.1.0b2 pre-release (lite and `+full` wheels), all on
tzf-dist `v0.0.2026-c-tzb2`.

## Methodology

Each finder is initialized once and reused for all queries, matching the
documented production pattern. Queries sample two datasets: 154,694 world cities
(`gt_cities.csv`) and 23,408 border-adjacent points (`gt_edges.csv`), both
resolved against full-precision `2026c` ground truth. Accuracy also runs a
uniform random dataset of 1,000,000 points in Go.

Memory is measured per candidate in an isolated child process. Four columns
appear below, and they are not interchangeable:

| Column | Meaning |
| --- | --- |
| Baseline | RSS before the candidate is constructed |
| Init peak | High-water mark (`ru_maxrss`) reached while loading. A container memory limit has to accommodate this value, or the process is killed at startup even though its steady state would have fit |
| Live | Data the candidate retains once ready to serve queries, from language-native accounting: Go `HeapAlloc` after a forced GC, Rust a counting global allocator. `n/a` for Python, whose data lives outside the Python heap |
| RSS after load | What the OS reports for a process ready to serve queries. Closer to `Init peak` than to `Live`, because freeing memory does not shrink RSS: the allocator keeps the pages mapped for reuse |

The relation `Live <= RSS after load <= Init peak` holds for every candidate.

## Query latency

Apple M3 Max, `2026c` dataset, 2026-09-14 snapshot.

### Go (tzf v2)

| Benchmark | ns/op | p50 (ns) | p99 (ns) | B/op | allocs/op |
| --- | ---: | ---: | ---: | ---: | ---: |
| `NewDefaultFinder`, world cities | 345.8 | 208.0 | 1500 | 0 | 0 |
| `NewDefaultFinder`, edge cities | 543.7 | 459.0 | 1208 | 0 | 0 |
| `NewEmbeddedFinder`, world cities | 533.7 | 333.0 | 2500 | 0 | 0 |
| `NewEmbeddedFinder`, edge cities | 1162 | 1000 | 2791 | 0 | 0 |
| `NewFullFinder`, world cities | 347.9 | 208.0 | 1583 | 0 | 0 |
| `NewFullFinder`, edge cities | 606.7 | 500.0 | 1750 | 0 | 0 |

All three finders query without allocating.

### Rust (tzf-rs 2.1)

| Benchmark | ns/iter | stddev (ns) |
| --- | ---: | ---: |
| `DefaultFinder`, random city | 221.13 | 41.39 |
| `DefaultFinder`, random edge city | 474.83 | 52.12 |
| `EmbeddedFinder`, random city | 292.68 | 51.42 |
| `EmbeddedFinder`, random edge city | 666.11 | 48.17 |

### Python (tzfpy 2.1.0b2)

`pytest-benchmark`, one `get_tz()` call per round.

| Benchmark | Median (ns) | Mean (ns) | OPS (Kops/s) |
| --- | ---: | ---: | ---: |
| Random cities, lite | 625.0 | 718.7 | 1,391.4 |
| Random edge cities, lite | 834.0 | 907.0 | 1,102.5 |
| Random cities, `+full` | 667.0 | 822.7 | 1,215.5 |
| Random edge cities, `+full` | 1,167.0 | 1,292.3 | 773.8 |

Per-call overhead is comparable to the Rust figures; the difference reflects the
Python-to-Rust call cost through PyO3. The `+full` rows are the experimental
full-precision wheel from tzfpy's own index, which runs tzf-rs's
`EmbeddedFinder` over `full.tzb`.

## Accuracy

Wrong-answer rates against full-precision `2026c` ground truth. "Offset-eq"
counts wrong answers that resolve to the same UTC offset.

| Dataset | N | Candidate | Wrong | Wrong % | Offset-eq |
| --- | ---: | --- | ---: | ---: | ---: |
| cities | 154,694 | Go `NewDefaultFinder` (lite `.tzm`) | 1 | 0.0006 | 1 |
| cities | 154,694 | Go `NewEmbeddedFinder` (lite `.tzb`) | 1 | 0.0006 | 1 |
| cities | 154,694 | Go `NewFullFinder` (full `.tzb`) | 0 | 0.0000 | 0 |
| cities | 154,694 | Rust `DefaultFinder` | 1 | 0.0006 | 1 |
| cities | 154,694 | Rust `EmbeddedFinder` | 1 | 0.0006 | 1 |
| cities | 154,694 | tzfpy | 1 | 0.0006 | 1 |
| cities | 154,694 | tzfpy `+full` | 0 | 0.0000 | 0 |
| edges | 23,408 | Go `NewDefaultFinder` (lite `.tzm`) | 1 | 0.0043 | 1 |
| edges | 23,408 | Go `NewFullFinder` (full `.tzb`) | 0 | 0.0000 | 0 |
| edges | 23,408 | Rust `DefaultFinder` | 1 | 0.0043 | 1 |
| edges | 23,408 | tzfpy | 1 | 0.0043 | 1 |
| edges | 23,408 | tzfpy `+full` | 0 | 0.0000 | 0 |
| uniform | 1,000,000 | Go `NewDefaultFinder` (lite `.tzm`) | 19 | 0.0019 | 14 |
| uniform | 1,000,000 | Go `NewFullFinder` (full `.tzb`) | 0 | 0.0000 | 0 |

The lite and full finders differ only near borders. The simplification bound is
111.2 m; see [FAQ]({{< relref "../guides/faq#is-tzf-100-accurate" >}}) for the
full displacement table.

## Memory

Values in MiB.

### Go

| Candidate | Baseline | Init peak | Live | RSS after load |
| --- | ---: | ---: | ---: | ---: |
| Go runtime floor | 4.7 | 4.7 | 0.2 | 5.0 |
| `NewDefaultFinder` (lite `.tzm`) | 5.1 | 41.5 | 13.1 | 41.5 |
| `NewEmbeddedFinder` (lite `.tzb` in place) | 5.2 | 9.2 | 0.3 | 9.6 |
| `NewFullFinder` (full `.tzb`) | 5.2 | 315.5 | 147.0 | 315.5 |

### Rust

| Candidate | Baseline | Init peak | Live | RSS after load |
| --- | ---: | ---: | ---: | ---: |
| Rust runtime floor | 5.8 | 5.9 | 0.0 | 5.9 |
| `DefaultFinder` | 5.8 | 46.6 | 22.8 | 46.5 |
| `EmbeddedFinder` | 5.8 | 10.3 | 0.2 | 10.4 |

`EmbeddedFinder` retains 0.2 MiB live: its data is the `'static` embedded
slice, and the counting allocator sees only the open-time index (chunk skip
blocks and per-group latitude stripes) that tzf-rs 2.1 builds.

### Python

| Candidate | Baseline | Init peak | Live | RSS after load |
| --- | ---: | ---: | ---: | ---: |
| Python interpreter floor | 22.4 | 22.4 | n/a | 22.4 |
| tzfpy (lite) | 22.4 | 60.3 | n/a | 60.2 |
| tzfpy `+full` | 22.4 | 38.2 | n/a | 38.2 |

## Observations

- The in-place mechanism trades query latency for memory. In Go, init peak
  drops from 41.5 MiB to 9.2 MiB while the world-cities median rises from 208 ns
  to 333 ns and the edge-cities median from 459 ns to 1,000 ns.
- Against the 2026-09-11 snapshot, the in-place edge-cities figures fell from
  8,959 ns to 1,000 ns (Go p50) and from 4,779.81 ns to 666.11 ns (Rust mean).
  The change comes from the tzf 2.1 and tzf-rs 2.1 query-walk rewrite and the
  64-point chunks in `v0.0.2026-c-tzb2`; the expanded finders are unchanged
  within noise, and results are identical.
- The tzfpy `+full` pre-release answers edge cities at a 1,167 ns median against
  834 ns for the lite wheel, at 38.2 MiB init peak against 60.3 MiB.
- The full-precision dataset costs memory rather than latency. Go init peak rises
  from 41.5 MiB to 315.5 MiB, while the world-cities median stays at 208 ns.
- Init peak overstates the steady-state cost. Go's default finder peaks at
  41.5 MiB while retaining 13.1 MiB; the full finder peaks at 315.5 MiB while
  retaining 147.0 MiB. Size a container for the peak and budget long-running cost
  from the retained figure.
- Language runtime floors differ (Go 4.7 MiB, Rust 5.8 MiB, Python 22.4 MiB), so
  cross-language totals are only comparable after subtracting them.
- The lite dataset disagrees with full-precision ground truth on 1 of 154,694
  world cities, and that answer resolves to the same UTC offset.
