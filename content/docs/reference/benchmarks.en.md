---
date: '2025-07-19T13:58:16+09:00'
description: Performance benchmarks for tzf implementations across Go and Rust.
draft: false
lastmod: '2026-04-26T00:00:00+09:00'
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

## Go (tzf v1.1.0)

| Target        | Dataset                        | Scenario                               | Median (ns) | p99 (ns) | Throughput (ops/s) | Memory (MiB) |
| ------------- | ------------------------------ | -------------------------------------- | ----------: | -------: | -----------------: | -----------: |
| DefaultFinder | topology-simplified + preindex | edge case · GetTimezoneName            |      3000.0 |   3000.0 |             393.5K |        74.70 |
| Finder        | topology-simplified            | edge case · GetTimezoneName            |      2000.0 |   3000.0 |             470.4K |        66.00 |
| FullFinder    | full-precision + preindex      | edge case · GetTimezoneName            |      3000.0 |   3000.0 |             395.6K |       421.50 |
| Finder        | full-precision                 | edge case · GetTimezoneName            |      2000.0 |   3000.0 |             475.3K |       412.70 |
| DefaultFinder | topology-simplified + preindex | random world cities · GetTimezoneName  |      1000.0 |   4000.0 |            1162.4K |        74.70 |
| FuzzyFinder   | preindex                       | random world cities · GetTimezoneName  |       469.8 |   1000.0 |            2128.6K |         8.90 |
| Finder        | topology-simplified            | random world cities · GetTimezoneName  |      2000.0 |   4000.0 |             531.6K |        66.00 |
| FullFinder    | full-precision + preindex      | random world cities · GetTimezoneName  |      1000.0 |   4000.0 |            1143.1K |       421.50 |
| Finder        | full-precision                 | random world cities · GetTimezoneName  |      2000.0 |   5000.0 |             468.6K |       412.70 |
| DefaultFinder | topology-simplified + preindex | random world cities · GetTimezoneNames |      5000.0 |   9000.0 |             208.0K |        74.70 |
| FuzzyFinder   | preindex                       | random world cities · GetTimezoneNames |       462.7 |   1000.0 |            2161.2K |         8.90 |
| Finder        | topology-simplified            | random world cities · GetTimezoneNames |      5000.0 |   8000.0 |             211.5K |        66.00 |
| FullFinder    | full-precision + preindex      | random world cities · GetTimezoneNames |      5000.0 |   9000.0 |             192.8K |       421.50 |

## Rust (tzf-rs v1.2.0 / v1.3.0)

### Topology-Simplified (bundled default)

| Target        | Dataset                        | Scenario      | Median (µs) | Throughput (ops/s) | Memory (MiB) |
| ------------- | ------------------------------ | ------------- | ----------: | -----------------: | -----------: |
| Finder        | topology-simplified            | YStripes only |      1.2296 |            813,273 |       103.30 |
| Finder        | topology-simplified            | No index      |      6.5402 |            152,901 |        51.68 |
| DefaultFinder | topology-simplified + preindex | YStripes only |      1.1383 |            878,503 |       125.98 |
| DefaultFinder | topology-simplified + preindex | No index      |      2.2514 |            444,168 |        77.79 |

### Full-Precision (optional `full` feature)

| Target               | Dataset                   | Scenario      | Median (µs) | Throughput (ops/s) | Memory (MiB) |
| -------------------- | ------------------------- | ------------- | ----------: | -----------------: | -----------: |
| Finder (full)        | full-precision            | YStripes only |      2.0852 |            479,570 |       561.08 |
| Finder (full)        | full-precision            | No index      |     37.6980 |             26,527 |       252.54 |
| DefaultFinder (full) | full-precision + preindex | YStripes only |      1.3488 |            741,400 |       584.30 |
| DefaultFinder (full) | full-precision + preindex | No index      |     11.2750 |             88,692 |       278.63 |

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

## Running benchmarks yourself

The continuous benchmark repo also contains scripts for running the same suite locally:

```bash
git clone https://github.com/ringsaturn/tz-benchmark
cd tz-benchmark
# Follow the README for language-specific setup and run instructions
```

Note that absolute numbers will vary by machine. Use the relative differences between finder types and index modes as the meaningful signal.
