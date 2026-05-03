---
date: "2025-07-19T13:58:16+09:00"
description: Performance benchmarks for tzf implementations across Go and Rust.
draft: false
lastmod: "2026-04-26T00:00:00+09:00"
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

**Local benchmark** — the tables below were measured on an Apple MacBook Pro with Apple M3 Max.
These give a more representative picture of real-world latency on modern hardware.

## Methodology

Each finder is initialized once and reused for all queries, matching the recommended production pattern.
Queries use a representative sample of global city coordinates plus intentional edge-case border points.

## Go (tzf v1.2.0)

| Target        | Dataset                            | Scenario                               | Median (ns) | p99 (ns) | Approx throughput (ops/s) | Memory (MiB) |
| ------------- | ---------------------------------- | -------------------------------------- | ----------: | -------: | ------------------------: | -----------: |
| DefaultFinder | topology-simplified + preindex     | edge case · GetTimezoneName            |       500.0 |   1250.0 |                   1694.9K |        74.90 |
| FuzzyFinder   | preindex                           | edge case · GetTimezoneName            |       250.0 |    375.0 |                   3521.1K |         2.40 |
| Finder        | topology-simplified                | edge case · GetTimezoneName            |       250.0 |    875.0 |                   3022.1K |        72.70 |
| FullFinder    | full-precision + preindex          | edge case · GetTimezoneName            |       542.0 |   1375.0 |                   1586.3K |       422.90 |
| Finder        | full-precision                     | edge case · GetTimezoneName            |       292.0 |   1167.0 |                   2678.1K |       420.70 |
| DefaultFinder | topology-simplified + preindex     | random world cities · GetTimezoneName  |       167.0 |    791.0 |                   3855.1K |        74.90 |
| FuzzyFinder   | preindex                           | random world cities · GetTimezoneName  |       167.0 |    333.0 |                   4608.3K |         2.40 |
| Finder        | topology-simplified                | random world cities · GetTimezoneName  |       209.0 |   1250.0 |                   3076.0K |        72.70 |
| FullFinder    | full-precision + preindex          | random world cities · GetTimezoneName  |       208.0 |    917.0 |                   3527.3K |       422.90 |
| Finder        | full-precision                     | random world cities · GetTimezoneName  |       250.0 |   1167.0 |                   2953.3K |       420.70 |
| Finder        | topology-simplified + GridIndex    | random world cities · GetTimezoneName  |       209.0 |   1167.0 |                   3202.0K |        72.70 |
| Finder        | topology-simplified (no GridIndex) | random world cities · GetTimezoneName  |      1833.0 |   2875.0 |                    612.4K |        67.00 |
| DefaultFinder | topology-simplified + preindex     | random world cities · GetTimezoneNames |       416.0 |   1375.0 |                   1956.9K |        74.90 |
| FuzzyFinder   | preindex                           | random world cities · GetTimezoneNames |       208.0 |    334.0 |                   4347.8K |         2.40 |
| Finder        | topology-simplified                | random world cities · GetTimezoneNames |       417.0 |   1375.0 |                   1931.2K |        72.70 |
| FullFinder    | full-precision + preindex          | random world cities · GetTimezoneNames |       459.0 |   1750.0 |                   1623.1K |       422.90 |

## Rust (tzf-rs v1.2.0 / v1.3.0)

Topology-Simplified (bundled) / Random Cities:

| Target        | Dataset                        | Scenario      | Median estimate (µs) | Approx throughput (ops/s) | Avg peak RSS (MiB) |
| ------------- | ------------------------------ | ------------- | -------------------: | ------------------------: | -----------------: |
| Finder        | topology-simplified            | YStripes only |               0.6457 |                 1,548,635 |             112.30 |
| Finder        | topology-simplified            | No index      |               4.3948 |                   227,542 |              59.92 |
| DefaultFinder | topology-simplified + preindex | YStripes only |               0.3800 |                 2,631,787 |             134.48 |
| DefaultFinder | topology-simplified + preindex | No index      |               4.4922 |                   222,608 |              85.66 |

Topology-Simplified (bundled) / Edge Cities (FuzzyFinder misses)

| Target                   | Dataset                        | Scenario                          | Median estimate (µs) | Approx throughput (ops/s) |
| ------------------------ | ------------------------------ | --------------------------------- | -------------------: | ------------------------: |
| FuzzyFinder              | preindex                       | FuzzyFinder miss                  |               0.2200 |                 4,546,074 |
| DefaultFinder (YStripes) | topology-simplified + preindex | DefaultFinder (YStripes) fallback |               0.7456 |                 1,341,184 |
| Finder                   | topology-simplified            | YStripes                          |               0.4975 |                 2,010,131 |
| Finder                   | topology-simplified            | No index                          |               4.3948 |                   227,542 |
| DefaultFinder            | topology-simplified + preindex | YStripes                          |               0.7154 |                 1,397,858 |
| DefaultFinder            | topology-simplified + preindex | No index                          |               4.4922 |                   222,608 |

Full-Precision (full):

| Target               | Dataset                   | Scenario      | Median estimate (µs) | Approx throughput (ops/s) | Avg peak RSS (MiB) |
| -------------------- | ------------------------- | ------------- | -------------------: | ------------------------: | -----------------: |
| Finder (full)        | full-precision            | YStripes only |               1.7158 |                   582,819 |             568.78 |
| Finder (full)        | full-precision            | No index      |              38.9370 |                    25,683 |             260.95 |
| DefaultFinder (full) | full-precision + preindex | YStripes only |               0.4984 |                 2,006,421 |             592.25 |
| DefaultFinder (full) | full-precision + preindex | No index      |               6.6012 |                   151,488 |             287.32 |

## Python (tzfpy v1.2.0)

tzfpy is a PyO3 binding over tzf-rs. The benchmark uses `pytest-benchmark` and measures
a single `get_tz()` call (random coordinate, topology-simplified dataset).
Results from Apple MacBook Pro with Apple M3 Max.

| Index mode                                 | Median (µs) | Mean (µs) | Throughput (Kops/s) | Memory       |
| ------------------------------------------ | ----------: | --------: | ------------------: | ------------ |
| Default (YStripes enabled)                 |      1.7934 |    1.8321 |               545.8 | ~120 MB      |
| No YStripes (`_TZFPY_DISABLE_Y_STRIPES=1`) |      2.5213 |    2.5338 |               394.7 | Not measured |

Per-call overhead is comparable to the raw Rust figures; the difference from tzf-rs numbers
reflects the Python → Rust FFI cost via PyO3.

## Key observations

- **YStripes index** brings a dramatic improvement for full-precision Finder: from 37.7 µs (no index) to 2.1 µs — an ~18× speedup. The effect is smaller but still significant for the topology-simplified dataset (6.5 µs → 1.2 µs, ~5×).
- **DefaultFinder** (preindex + polygon) consistently wins for general workloads: ~1 µs median with ~75–126 MB memory, regardless of dataset.
- **FuzzyFinder** (preindex only) is the fastest at ~470 ns, but only covers tiles that lie entirely within a single timezone polygon. For points near borders or outside covered tiles it returns no result rather than guessing. Only use it standalone if your workload is known to be well away from timezone borders.
- **Python (tzfpy)** adds ~0.5–1 µs of PyO3 FFI overhead on top of the Rust baseline. With YStripes enabled the median sits at ~1.8 µs — well within the range of most backend API budgets.
- **Memory scales with dataset**: switching from topology-simplified to full-precision in Rust adds roughly 450 MB with YStripes enabled.
