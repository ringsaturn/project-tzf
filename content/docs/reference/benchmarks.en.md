---
date: '2025-07-19T13:58:16+09:00'
description: Performance benchmarks for tzf implementations across Go and Rust.
draft: false
lastmod: '2026-07-26T00:00:00+09:00'
seo:
  description: Performance benchmark results for tzf and tzf-rs covering default, fuzzy, and full-precision finders with YStripes and preindex.
  noindex: false
  title: Benchmarks — Project tzf
summary: Benchmark results for tzf (Go) and tzf-rs (Rust) covering different finder types, datasets, and index modes.
title: Benchmarks
toc: true
weight: 4
---

There are two separate benchmark setups with different purposes:

**Continuous benchmark** — source and results at <https://github.com/ringsaturn/tz-benchmark>,
visualized at <https://ringsaturn.github.io/tz-benchmark/>.
Runs automatically in GitHub Actions on each release for cross-package comparison.
Because GitHub Actions runners have different hardware than a developer machine,
the absolute numbers differ from local runs, but the relative trends between packages are what matters here.
The dated snapshots under [`snapshot/`](https://github.com/ringsaturn/tz-benchmark/tree/main/snapshot)
are a separate thing: those are captured locally on the same Apple M3 Max as the tables below,
so their absolute numbers are directly comparable to this page.

**Local benchmark** — the tables below were measured on an Apple MacBook Pro with Apple M3 Max.
These give a more representative picture of real-world latency on modern hardware.

## Methodology

Each finder is initialized once and reused for all queries, matching the recommended production pattern.
Queries use a representative sample of global city coordinates plus intentional edge-case border points.

Two different notions of memory appear below, and they are not interchangeable.
The Go tables report **retained memory** — what the finder still holds once it is
ready to serve queries. The Rust and Python tables report **peak RSS** — the
high-water mark reached while loading, which is several times larger because
building a finder decodes the whole `.pb` dataset into an intermediate
representation before discarding it, and freeing memory does not return the
pages to the kernel. Do not read a Go figure and a Rust figure as the same
measurement. See
[How much memory does tzf use?]({{< relref "../guides/faq#how-much-memory-does-tzf-use" >}})
for both figures measured side by side on the same runs.

## Go (tzf v1.2.3)

| Target        | Dataset                            | Scenario                               | Median (ns) | p99 (ns) | Approx throughput (ops/s) | Retained (MiB) |
| ------------- | ---------------------------------- | -------------------------------------- | ----------: | -------: | ------------------------: | -------------: |
| DefaultFinder | topology-simplified + preindex     | edge case · GetTimezoneName            |       625.0 |   2250.0 |                   1083.8K |        31.90 |
| FuzzyFinder   | preindex                           | edge case · GetTimezoneName            |       250.0 |    542.0 |                   3216.5K |         2.40 |
| Finder        | topology-simplified                | edge case · GetTimezoneName            |       334.0 |   1667.0 |                   2145.0K |        29.70 |
| FullFinder    | full-precision + preindex          | edge case · GetTimezoneName            |       709.0 |   2875.0 |                   1111.7K |       155.30 |
| Finder        | full-precision                     | edge case · GetTimezoneName            |       416.0 |   2709.0 |                   1652.6K |       153.00 |
| DefaultFinder | topology-simplified + preindex     | random world cities · GetTimezoneName  |       208.0 |   1208.0 |                   3283.0K |        31.90 |
| FuzzyFinder   | preindex                           | random world cities · GetTimezoneName  |       208.0 |    542.0 |                   3717.5K |         2.40 |
| Finder        | topology-simplified                | random world cities · GetTimezoneName  |       292.0 |   2208.0 |                   2058.0K |        29.70 |
| FullFinder    | full-precision + preindex          | random world cities · GetTimezoneName  |       208.0 |   1375.0 |                   3147.6K |       155.30 |
| Finder        | full-precision                     | random world cities · GetTimezoneName  |       333.0 |   1959.0 |                   1993.6K |       153.00 |
| Finder        | topology-simplified + GridIndex    | random world cities · GetTimezoneName  |       250.0 |   1667.0 |                   2387.2K |        29.70 |
| Finder        | topology-simplified (no GridIndex) | random world cities · GetTimezoneName  |      2292.0 |   4375.0 |                    471.7K |        24.00 |
| DefaultFinder | topology-simplified + preindex     | random world cities · GetTimezoneNames |       625.0 |   3833.0 |                    971.8K |        31.90 |
| FuzzyFinder   | preindex                           | random world cities · GetTimezoneNames |       209.0 |    583.0 |                   3534.8K |         2.40 |
| Finder        | topology-simplified                | random world cities · GetTimezoneNames |       583.0 |   2833.0 |                   1277.3K |        29.70 |
| FullFinder    | full-precision + preindex          | random world cities · GetTimezoneNames |       709.0 |   3292.0 |                   1059.0K |       155.30 |

## Rust (tzf-rs v1.3.6)

Topology-Simplified (bundled) / Random Cities

| Target        | Dataset                        | Scenario      | Median estimate (µs) | Approx throughput (ops/s) | Avg init peak RSS (MiB) |
| ------------- | ------------------------------ | ------------- | -------------------: | ------------------------: | ----------------------: |
| Finder        | topology-simplified            | YStripes only |               0.5698 |                 1,755,033 |              69.72 |
| Finder        | topology-simplified            | No index      |               4.9164 |                   203,401 |              42.46 |
| DefaultFinder | topology-simplified + preindex | YStripes only |               0.3040 |                 3,289,365 |              82.10 |
| DefaultFinder | topology-simplified + preindex | No index      |               5.0438 |                   198,263 |              58.11 |

Topology-Simplified (bundled) / Edge Cities (FuzzyFinder misses)

| Target                   | Dataset                        | Scenario                          | Median estimate (µs) | Approx throughput (ops/s) |
| ------------------------ | ------------------------------ | --------------------------------- | -------------------: | ------------------------: |
| FuzzyFinder              | preindex                       | FuzzyFinder miss                  |               0.1564 |                 6,393,044 |
| DefaultFinder (YStripes) | topology-simplified + preindex | DefaultFinder (YStripes) fallback |               0.6256 |                 1,598,338 |
| Finder                   | topology-simplified            | YStripes                          |               0.4421 |                 2,261,676 |
| Finder                   | topology-simplified            | No index                          |               4.9164 |                   203,401 |
| DefaultFinder            | topology-simplified + preindex | YStripes                          |               0.6069 |                 1,647,718 |
| DefaultFinder            | topology-simplified + preindex | No index                          |               5.0438 |                   198,263 |

Full-Precision (full)

| Target               | Dataset                   | Scenario      | Median estimate (µs) | Approx throughput (ops/s) | Avg init peak RSS (MiB) |
| -------------------- | ------------------------- | ------------- | -------------------: | ------------------------: | ----------------------: |
| Finder (full)        | full-precision            | YStripes only |               1.2227 |                   817,862 |             314.59 |
| Finder (full)        | full-precision            | No index      |              43.0520 |                    23,228 |             157.02 |
| DefaultFinder (full) | full-precision + preindex | YStripes only |               0.5527 |                 1,809,136 |             323.58 |
| DefaultFinder (full) | full-precision + preindex | No index      |               7.4823 |                   133,649 |             171.44 |

## Python (tzfpy v1.3.2)

tzfpy is a PyO3 binding over tzf-rs. The benchmark uses `pytest-benchmark` and measures
a single `get_tz()` call (random coordinate, topology-simplified dataset).
Results from Apple MacBook Pro with Apple M3 Max.

| Index mode                                 | Median (µs) | Mean (µs) | Throughput (Kops/s) | Peak RSS |
| ------------------------------------------ | ----------: | --------: | ------------------: | -------: |
| Default (YStripes enabled)                 |      0.6533 |    0.6711 |              1490.1 | ~70.5 MB |
| No YStripes (`_TZFPY_DISABLE_Y_STRIPES=1`) |      1.6410 |    1.6548 |               604.3 | ~57.5 MB |

Per-call overhead is comparable to the raw Rust figures; the difference from tzf-rs numbers
reflects the Python → Rust FFI cost via PyO3.

## Key observations

- **YStripes substantially reduces polygon lookup latency**. For Rust `Finder`, the full-precision median falls from 43.0520 µs to 1.2227 µs, a 35.2× speedup. On the topology-simplified dataset it falls from 4.9164 µs to 0.5698 µs, an 8.6× speedup.
- **DefaultFinder is the strongest general-purpose Rust option**. Its median is 0.3040 µs on topology-simplified data and 0.5527 µs on full-precision data. The preindex adds about 9 to 12 MiB of init peak RSS over the corresponding YStripes-enabled `Finder`.
- **FuzzyFinder is useful as a fast path with a fallback**. A miss completes in 0.1564 µs, while `DefaultFinder` resolves the same edge-city workload through its YStripes fallback in 0.6256 µs. Standalone use remains suitable only when queries are known to stay away from timezone borders.
- **Python benefits significantly from YStripes**. The tzfpy median falls from 1.6410 µs to 0.6533 µs, and throughput rises from 604.3 to 1490.1 Kops/s, about 2.5×.
- **Full-precision data has a clear memory cost**. With YStripes enabled, moving from topology-simplified to full-precision data adds about 241 to 245 MiB of init peak RSS in Rust. In Go, retained memory rises from about 30 MiB to about 153 to 155 MiB. These are the two different bases described in [Methodology](#methodology), so the Rust and Go increases are not directly comparable.
- **Init peak is not what tzf costs to keep running**. The Rust peak RSS figures above overstate steady state by roughly 2× to 3×: in the [2026-07-26 snapshot](https://github.com/ringsaturn/tz-benchmark/blob/main/snapshot/2026-07-26-8d0fed77a8efb102ea3e3848781b5a000bbfb548/README.md#memory), measured on the same machine, `DefaultFinder` on topology-simplified data peaks at 77.0 MiB while retaining 36.3 MiB, and `Finder` peaks at 48.0 MiB while retaining 20.7 MiB. Size a container for the peak; budget long-running cost from the retained figure.
