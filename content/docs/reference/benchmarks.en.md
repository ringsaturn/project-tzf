---
date: '2025-07-19T13:58:16+09:00'
description: Performance, accuracy, and memory benchmarks for the tzf v2 implementations in Go, Rust, and Python.
draft: false
lastmod: '2026-11-01T00:00:00+09:00'
seo:
  description: Benchmark results for tzf v2 — query latency, accuracy against full-precision ground truth, and memory for the default, embedded, and full finders in Go, Rust, and Python.
  noindex: false
  title: Benchmarks — Project tzf
summary: Query latency, accuracy, and memory for the tzf v2 finders, from the 2026-11-01 tz-benchmark snapshot.
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
`2026-11-01` snapshot, measured against the published tzf v2.1.4, tzf-rs 2.1.4 and
tzfpy 2.1.2 releases (lite and `+full` wheels), all on tzf-dist
`v0.0.2026-f`.

## Methodology

Each finder is initialized once and reused for all queries, matching the
documented production pattern. Queries sample two datasets: 170,540 world cities
(`gt_cities.csv`) and 23,408 border-adjacent points (`gt_edges.csv`), both
resolved against full-precision `2026f` ground truth. Accuracy also runs a
uniform random dataset of 1,000,000 points in Go.

Memory is measured per candidate in an isolated child process. Four columns
appear below, and they are not interchangeable:

| Column | Meaning |
| --- | --- |
| Baseline | RSS before the candidate is constructed |
| Init peak | High-water mark (`ru_maxrss`) reached while loading. A container memory limit has to accommodate this value, or the process is killed at startup even though its steady state would have fit |
| Live | Data the candidate retains once ready to serve queries, from language-native accounting: Go `HeapAlloc` after a forced GC, Rust a counting global allocator. `n/a` for Python, whose data lives outside the Python heap |
| RSS after load | What the OS reports for a process ready to serve queries. Closer to `Init peak` than to `Live`, because freeing memory does not shrink RSS: the allocator keeps the pages mapped for reuse |

`Live` is the smallest of the three figures for every candidate. `RSS after
load` is at most 0.5 MiB above `Init peak`.

## Query latency

Apple M3 Max, `2026f` dataset, 2026-11-01 snapshot.

### Go (tzf v2)

| Benchmark | ns/op | p50 (ns) | p99 (ns) | B/op | allocs/op |
| --- | ---: | ---: | ---: | ---: | ---: |
| `NewDefaultFinder`, world cities | 350.0 | 208.0 | 1500 | 0 | 0 |
| `NewDefaultFinder`, edge cities | 556.5 | 500.0 | 1250 | 0 | 0 |
| `NewEmbeddedFinder`, world cities | 535.8 | 333.0 | 2542 | 0 | 0 |
| `NewEmbeddedFinder`, edge cities | 1230 | 1042 | 2750 | 0 | 0 |
| `NewFullFinder`, world cities | 354.5 | 208.0 | 1708 | 0 | 0 |
| `NewFullFinder`, edge cities | 591.8 | 500.0 | 1542 | 0 | 0 |

All three finders query without allocating.

### Rust (tzf-rs 2.1.4)

| Benchmark | ns/iter | stddev (ns) |
| --- | ---: | ---: |
| `DefaultFinder`, random city | 225.62 | 21.17 |
| `DefaultFinder`, random edge city | 489.33 | 10.13 |
| `EmbeddedFinder`, random city | 350.34 | 110.85 |
| `EmbeddedFinder`, random edge city | 686.94 | 8.99 |

### Python (tzfpy 2.1.2)

`pytest-benchmark`, one `get_tz()` call per round.

| Benchmark | Median (ns) | Mean (ns) | OPS (Kops/s) |
| --- | ---: | ---: | ---: |
| Random cities, lite | 666.0 | 745.4 | 1,341.6 |
| Random edge cities, lite | 875.0 | 958.8 | 1,042.9 |
| Random cities, `+full` | 667.0 | 810.5 | 1,233.8 |
| Random edge cities, `+full` | 1,208.0 | 1,313.5 | 761.4 |

Per-call overhead is comparable to the Rust figures; the difference reflects the
Python-to-Rust call cost through PyO3. The `+full` rows are the experimental
full-precision wheel from tzfpy's own index, which runs tzf-rs's
`EmbeddedFinder` over `full.tzb`.

## Accuracy

Wrong-answer rates against full-precision `2026f` ground truth. "Offset-eq"
counts wrong answers that resolve to the same UTC offset.

| Dataset | N | Candidate | Wrong | Wrong % | Offset-eq |
| --- | ---: | --- | ---: | ---: | ---: |
| cities | 170,540 | Go `NewDefaultFinder` (lite `.tzm`) | 2 | 0.0012 | 1 |
| cities | 170,540 | Go `NewEmbeddedFinder` (lite `.tzb`) | 2 | 0.0012 | 1 |
| cities | 170,540 | Go `NewFullFinder` (full `.tzb`) | 0 | 0.0000 | 0 |
| cities | 170,540 | Rust `DefaultFinder` | 2 | 0.0012 | 1 |
| cities | 170,540 | Rust `EmbeddedFinder` | 2 | 0.0012 | 1 |
| cities | 170,540 | tzfpy | 2 | 0.0012 | 1 |
| cities | 170,540 | tzfpy `+full` | 0 | 0.0000 | 0 |
| edges | 23,408 | Go `NewDefaultFinder` (lite `.tzm`) | 1 | 0.0043 | 1 |
| edges | 23,408 | Go `NewFullFinder` (full `.tzb`) | 0 | 0.0000 | 0 |
| edges | 23,408 | Rust `DefaultFinder` | 1 | 0.0043 | 1 |
| edges | 23,408 | tzfpy | 1 | 0.0043 | 1 |
| edges | 23,408 | tzfpy `+full` | 0 | 0.0000 | 0 |
| uniform | 1,000,000 | Go `NewDefaultFinder` (lite `.tzm`) | 21 | 0.0021 | 14 |
| uniform | 1,000,000 | Go `NewFullFinder` (full `.tzb`) | 0 | 0.0000 | 0 |

The lite and full finders differ only near borders. The simplification bound is
111.2 m; see [FAQ]({{< relref "../guides/faq#is-tzf-100-accurate" >}}) for the
full displacement table.

## Memory

Values in MiB.

### Go

| Candidate | Baseline | Init peak | Live | RSS after load |
| --- | ---: | ---: | ---: | ---: |
| Go runtime floor | 5.1 | 5.1 | 0.3 | 5.4 |
| `NewDefaultFinder` (lite `.tzm`) | 5.5 | 44.5 | 13.3 | 44.6 |
| `NewEmbeddedFinder` (lite `.tzb` in place) | 5.7 | 9.6 | 0.4 | 10.1 |
| `NewFullFinder` (full `.tzb`) | 5.7 | 266.7 | 148.9 | 266.9 |

### Rust

| Candidate | Baseline | Init peak | Live | RSS after load |
| --- | ---: | ---: | ---: | ---: |
| Rust runtime floor | 5.8 | 5.8 | 0.0 | 5.9 |
| `DefaultFinder` | 5.8 | 44.5 | 23.1 | 44.3 |
| `EmbeddedFinder` | 5.8 | 10.2 | 0.2 | 10.2 |

`EmbeddedFinder` retains 0.2 MiB live: its data is the `'static` embedded
slice, and the counting allocator sees only the open-time index (chunk skip
blocks and per-group latitude stripes) that tzf-rs 2.1 builds.

### Python

| Candidate | Baseline | Init peak | Live | RSS after load |
| --- | ---: | ---: | ---: | ---: |
| Python interpreter floor | 22.5 | 22.5 | n/a | 22.5 |
| tzfpy (lite) | 22.5 | 61.3 | n/a | 61.2 |
| tzfpy `+full` | 22.5 | 38.8 | n/a | 38.8 |

## Observations

- The in-place mechanism trades query latency for memory. In Go, init peak
  drops from 44.5 MiB to 9.6 MiB while the world-cities median rises from 208 ns
  to 333 ns and the edge-cities median from 500 ns to 1,042 ns.
- Against the 2026-09-14 snapshot (tzf v2.1.1, `2026c`), the Go world-cities
  medians are unchanged at 208, 333 and 208 ns, and the Go edge-cities medians
  differ by at most 42 ns. The Rust `EmbeddedFinder` random-city mean rose from
  292.68 ns to 350.34 ns, with a standard deviation of 110.85 ns in this run.
  The Go `NewFullFinder` init peak fell from 315.5 MiB to 266.7 MiB while its
  live heap stayed near 148 MiB; the cause of the init-peak change has not been
  established.
- The cities dataset grew from 154,694 to 170,540 entries when tz-benchmark
  refreshed its ground-truth files on 2026-09-20, so the accuracy counts are not
  directly comparable with the 2026-09-14 tables.
- The tzfpy `+full` wheel answers edge cities at a 1,208 ns median against
  875 ns for the lite wheel, at 38.8 MiB init peak against 61.3 MiB.
- The full-precision dataset costs memory rather than latency. Go init peak rises
  from 44.5 MiB to 266.7 MiB, while the world-cities median stays at 208 ns.
- Init peak overstates the steady-state cost. Go's default finder peaks at
  44.5 MiB while retaining 13.3 MiB; the full finder peaks at 266.7 MiB while
  retaining 148.9 MiB. Size a container for the peak and budget long-running cost
  from the retained figure.
- Language runtime floors differ (Go 5.1 MiB, Rust 5.8 MiB, Python 22.5 MiB), so
  cross-language totals are only comparable after subtracting them.
- The lite dataset disagrees with full-precision ground truth on 2 of 170,540
  world cities; the harness counts one of the two as resolving to the same UTC
  offset.
