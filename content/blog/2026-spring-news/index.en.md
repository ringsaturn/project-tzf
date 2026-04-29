---
author: ringsaturn
cover:
  image: https://blog-assets.ringsaturn.me/pic/tzf-spring-news/cover.webp
date: '2026-04-26'
description: A major update for the tzf project family in spring 2026, introducing topology-aware processing to eliminate gaps and overlaps in simplified polygon data, a new efficient data distribution format, and YStripes index acceleration for Go and Rust versions. Performance benchmarks included.
tags:
- tzf
- Side Project
- Geo
- timezone
title: tzf Spring 2026 Update
---

> [!NOTE]
> Originally published on my personal blog: [tzf Spring 2026 Update](https://blog.ringsaturn.me/en/posts/2026-04-26-tzf-spring-news/)

It has been a few years since the tzf project family was started. The last systematic look back at its development history was [History of package tzf]({{< ref "/blog/history-of-tzf/index.md" >}}) in early 2023. Since then, there have been various updates and maintenance work, mostly focused on non-core optimizations and supplementary features.

In spring 2026, several long-pending important changes were finally completed:

1. Introducing topology-aware processing to eliminate gaps and overlaps introduced during polygon simplification;
2. Based on topology-aware processing, developing a more efficient data distribution format — ~17 MB for full-precision data and ~5.4 MB for simplified data;
3. Introducing YStripes index acceleration, inspired by the tg project.

## Topology-Aware Processing

The raw data is essentially a collection of polygons. Because the raw boundaries are highly detailed, the data volume is large, so polygon simplification is necessary. Many of these polygons share boundaries, but in the previous approach, each polygon was simplified independently using RDP. This caused a [known issue](https://github.com/ringsaturn/tzf/issues/183) that existed since the project's early days: gaps appearing in areas that should be fully covered, and unwanted polygon overlaps introduced by simplification:

![See details in [`ringsaturn/tzf#183`](https://github.com/ringsaturn/tzf/issues/183)](https://blog-assets.ringsaturn.me/pic/tzf-spring-news/issue_183.webp)

The solution had been clear for years: first identify shared boundaries, simplify those shared boundaries, then substitute the simplified boundaries back into the polygons on both sides. This ensures adjacent polygons continue to reference the same simplified boundary, preventing gaps or overlaps caused by independent simplification on each side.

The problem was that the dataset is very large. Over the past few years I made multiple attempts to implement this strategy by hand, and all of them failed. Accumulating edge cases and increasingly complex strategy design made the code impossible to run stably.

When I tried again in 2026, I used Claude and Codex across multiple rounds of implementation, verification, and refactoring, and finally got the complete strategy working. The rough flow is illustrated below:

![Made by ChatGPT](https://blog-assets.ringsaturn.me/pic/tzf-spring-news/topology_algo.en.webp)

With this strategy in place, it also became possible to implement the [new data storage format goals](https://github.com/ringsaturn/tzf/issues/191) designed last year.

To maintain backward compatibility, the new binary data has been split into a new repository to carry the format improvements described below. The existing data format distribution — the tzf-rel series — will continue for a while before being deprecated.

Since shared boundaries can now be identified, there is no need to store lengthy boundaries twice; they are stored once and encoded with polyline compression.

The effect is significant. Previously, tzf distributed the full dataset in pb format at roughly 90 MB uncompressed and ~50 MB zipped. Now, with shared boundaries stored only once and polyline-encoded, the full-precision data is ~17 MB, or ~10 MB zipped. I'm quite satisfied that full-precision data can be compressed to this size. This acceptable file size is what makes it possible for tzf-rs to now finally offer an optional feature to support the full dataset. Previously, due to the 90 MB size, users had to download the full dataset themselves and provide the file path.

For the simplified dataset, omitting polyline compression would actually cause a slight size increase. The reason is that many small polygon details that were previously discarded are now retained under new criteria for precision reasons. On the other hand, because the boundaries themselves have already been greatly simplified, the benefit of storing shared boundaries only once is less pronounced than with full-precision data. Currently, with shared-boundary detection and polyline processing, the simplified dataset is ~5.4 MB, which is still acceptable.

One thing worth noting: when tzf uses full-precision data, runtime memory usage is around 500 MB, which is significant — there are no plans to optimize this further for now, and this feature will not be ported to the Python bindings for the time being. Even with the simplified dataset, around 100 MB of memory is needed. The tzf family — especially the Go, Rust, and Python versions — was designed from the start for high-concurrency backend API scenarios, where a certain memory footprint is acceptable in exchange for near-zero-latency lookups and boundary accuracy that cannot be overly simplified. Memory usage, processing speed, and data precision all need to be balanced together. What to use and how to use it ultimately depends on each user's actual requirements.

For more details on this feature, refer to the code documentation at [`internal/topology/README.md`](https://github.com/ringsaturn/tzf/blob/v1.1.0/internal/topology/README.md).

Current data files are as follows:

| File                                              | Size   | Description                                                              |
| ------------------------------------------------- | ------ | ------------------------------------------------------------------------ |
| `combined-with-oceans.compress.topo.bin`          | ~17MB  | Full precision: shared-edge dedup + polyline compression                 |
| `combined-with-oceans.topology.compress.topo.bin` | ~5.4MB | Lite: topology-aware simplify + shared-edge dedup + polyline compression |
| `combined-with-oceans.topology.preindex.bin`        | ~2MB   | Tile pre-index for FuzzyFinder                                           |

## YStripes Index

To be clear: the YStripes index is not my invention. It comes from Josh Baker's [`tidwall/tg`](https://github.com/tidwall/tg) project. I simply ported this indexing mechanism into the Go and Rust versions of tzf.

Starting this spring, this index has become the default strategy for the Go and Rust versions of tzf. It does add some memory overhead, but the performance gains are more substantial. In my local benchmarks, a single random lookup has come down to around 1 microsecond, which should not be a bottleneck in any of the use cases I am aware of.

I won't go into the algorithm details here — if you're interested, you can read the author's explanation directly in [`POLYGON_INDEXING.md`](https://github.com/tidwall/tg/blob/main/docs/POLYGON_INDEXING.md).

## Benchmark

Here are my local benchmark results, run on a MacBook Pro with Apple M3 Max.

These results are primarily for observing relative differences between strategies and should not be taken as absolute cross-machine performance conclusions.

### tzf (Go)

| Target        | Dataset                        | Scenario                               | Median (ns) | p99 (ns) | Approx throughput (ops/s) | Memory (MiB) |
| ------------- | ------------------------------ | -------------------------------------- | ----------: | -------: | ------------------------: | -----------: |
| DefaultFinder | topology-simplified + preindex | edge case · GetTimezoneName            |      3000.0 |   3000.0 |                    393.5K |        74.70 |
| Finder        | topology-simplified            | edge case · GetTimezoneName            |      2000.0 |   3000.0 |                    470.4K |        66.00 |
| FullFinder    | full-precision + preindex      | edge case · GetTimezoneName            |      3000.0 |   3000.0 |                    395.6K |       421.50 |
| Finder        | full-precision                 | edge case · GetTimezoneName            |      2000.0 |   3000.0 |                    475.3K |       412.70 |
| DefaultFinder | topology-simplified + preindex | random world cities · GetTimezoneName  |      1000.0 |   4000.0 |                   1162.4K |        74.70 |
| FuzzyFinder   | preindex                       | random world cities · GetTimezoneName  |       469.8 |   1000.0 |                   2128.6K |         8.90 |
| Finder        | topology-simplified            | random world cities · GetTimezoneName  |      2000.0 |   4000.0 |                    531.6K |        66.00 |
| FullFinder    | full-precision + preindex      | random world cities · GetTimezoneName  |      1000.0 |   4000.0 |                   1143.1K |       421.50 |
| Finder        | full-precision                 | random world cities · GetTimezoneName  |      2000.0 |   5000.0 |                    468.6K |       412.70 |
| DefaultFinder | topology-simplified + preindex | random world cities · GetTimezoneNames |      5000.0 |   9000.0 |                    208.0K |        74.70 |
| FuzzyFinder   | preindex                       | random world cities · GetTimezoneNames |       462.7 |   1000.0 |                   2161.2K |         8.90 |
| Finder        | topology-simplified            | random world cities · GetTimezoneNames |      5000.0 |   8000.0 |                    211.5K |        66.00 |
| FullFinder    | full-precision + preindex      | random world cities · GetTimezoneNames |      5000.0 |   9000.0 |                    192.8K |       421.50 |

### tzf-rs (Rust)

Topology-Simplified (bundled):

| Target        | Dataset                        | Scenario      | Median estimate (µs) | Approx throughput (ops/s) | Avg peak RSS (MiB) |
| ------------- | ------------------------------ | ------------- | -------------------: | ------------------------: | -----------------: |
| Finder        | topology-simplified            | YStripes only |               1.2296 |                   813,273 |             103.30 |
| Finder        | topology-simplified            | No index      |               6.5402 |                   152,901 |              51.68 |
| DefaultFinder | topology-simplified + preindex | YStripes only |               1.1383 |                   878,503 |             125.98 |
| DefaultFinder | topology-simplified + preindex | No index      |               2.2514 |                   444,168 |              77.79 |

Full-Precision (full):

| Target               | Dataset                   | Scenario      | Median estimate (µs) | Approx throughput (ops/s) | Avg peak RSS (MiB) |
| -------------------- | ------------------------- | ------------- | -------------------: | ------------------------: | -----------------: |
| Finder (full)        | full-precision            | YStripes only |               2.0852 |                   479,570 |             561.08 |
| Finder (full)        | full-precision            | No index      |              37.6980 |                    26,527 |             252.54 |
| DefaultFinder (full) | full-precision + preindex | YStripes only |               1.3488 |                   741,400 |             584.30 |
| DefaultFinder (full) | full-precision + preindex | No index      |              11.2750 |                    88,692 |             278.63 |

### Python

The Python version is primarily a binding, so benchmark results are omitted here. Worth mentioning though: the wheel size dropped from ~7 MB to ~4 MB, which is a small but welcome improvement for image build artifacts.

### Continuous Benchmark in GitHub Actions

Below are long-term performance metrics monitored through [Continuous Benchmark](https://github.com/marketplace/actions/continuous-benchmark):

![tzf ns/op](https://blog-assets.ringsaturn.me/pic/tzf-spring-news/benchmark-tzf.webp)

![tzf-rs ns/iter](https://blog-assets.ringsaturn.me/pic/tzf-spring-news/benchmark-tzf-rs.webp)

![tzf iter/sec](https://blog-assets.ringsaturn.me/pic/tzf-spring-news/benchmark-tzfpy.webp)

## End

That covers the main features completed during this busy spring. For the tzf project family, this update fills in a key piece of the original design: using Go to perform topology-aware polygon dataset simplification and distribution, and then letting the Go, Rust, Python, and other language versions directly reuse the same data output.

Ongoing maintenance will be relatively light, focusing mainly on data file updates, dependency updates, and minor interface compatibility work.

The development above was spread across different time periods. Corresponding releases for reference:

- https://github.com/ringsaturn/geometry-rs/releases/tag/v0.4.1
- https://github.com/ringsaturn/tzf-rs/releases/tag/v1.2.0
- https://github.com/ringsaturn/tzf-rs/releases/tag/v1.3.0
- https://github.com/ringsaturn/tzfpy/releases/tag/v1.2.0
- https://github.com/ringsaturn/tzfpy/releases/tag/v1.3.0
- https://github.com/ringsaturn/tzf/releases/tag/v1.1.0
- https://github.com/ringsaturn/tzf-dist/releases/tag/v0.0.2026-a
