---
date: "2025-07-19T13:58:16+09:00"
description: tzf 各语言实现的性能基准测试，涵盖 Go 和 Rust。
draft: false
lastmod: "2026-07-15T00:00:00+09:00"
seo:
  description: tzf 和 tzf-rs 的性能基准测试结果，涵盖默认、模糊和完整精度查找器，包含 YStripes 和预索引。
  noindex: false
  title: 基准测试 - Project tzf
summary: tzf (Go) 和 tzf-rs (Rust) 基准测试结果，涵盖不同查找器类型、数据集和索引模式。
title: 基准测试
toc: true
weight: 4
---

项目有两套独立的基准测试，用途不同：

**持续基准测试**：源代码及结果位于 <https://github.com/ringsaturn/tz-benchmark>，
可视化展示在 <https://ringsaturn.github.io/tz-benchmark/>。
每次发布时在 GitHub Actions 中自动运行，用于跨包对比。
由于 GitHub Actions 运行器与开发者机器硬件不同，绝对数值与本地运行有所差异，但包之间的相对趋势可以说明问题。

**本地基准测试**：以下表格在搭载 Apple M3 Max 的 MacBook Pro 上测得。
这些结果更能反映现代硬件上真实场景的延迟。

## 测试方法

每个查找器初始化一次并复用于所有查询，匹配推荐的生产环境模式。
查询使用全球城市坐标的代表性样本加上特意选取的边界边缘案例点。

## Go (tzf v1.2.3)

| Target        | Dataset                            | Scenario                               | Median (ns) | p99 (ns) | Approx throughput (ops/s) | Memory (MiB) |
| ------------- | ---------------------------------- | -------------------------------------- | ----------: | -------: | ------------------------: | -----------: |
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

| Target        | Dataset                        | Scenario      | Median estimate (µs) | Approx throughput (ops/s) | Avg peak RSS (MiB) |
| ------------- | ------------------------------ | ------------- | -------------------: | ------------------------: | -----------------: |
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

| Target               | Dataset                   | Scenario      | Median estimate (µs) | Approx throughput (ops/s) | Avg peak RSS (MiB) |
| -------------------- | ------------------------- | ------------- | -------------------: | ------------------------: | -----------------: |
| Finder (full)        | full-precision            | YStripes only |               1.2227 |                   817,862 |             314.59 |
| Finder (full)        | full-precision            | No index      |              43.0520 |                    23,228 |             157.02 |
| DefaultFinder (full) | full-precision + preindex | YStripes only |               0.5527 |                 1,809,136 |             323.58 |
| DefaultFinder (full) | full-precision + preindex | No index      |               7.4823 |                   133,649 |             171.44 |

## Python (tzfpy v1.3.2)

tzfpy 是基于 tzf-rs 的 PyO3 绑定。基准测试使用 `pytest-benchmark` 测量
单次 `get_tz()` 调用（随机坐标，拓扑简化数据集）。
结果来自搭载 Apple M3 Max 的 MacBook Pro。

| 索引模式                                    | 中位数 (µs) | 平均值 (µs) | 吞吐量 (Kops/s) |     内存 |
| ------------------------------------------- | ----------: | ----------: | --------------: | -------: |
| 默认（YStripes 启用）                       |      0.6533 |      0.6711 |          1490.1 | ~70.5 MB |
| 无 YStripes（`_TZFPY_DISABLE_Y_STRIPES=1`） |      1.6410 |      1.6548 |           604.3 | ~57.5 MB |

每次调用开销与原始 Rust 数据相当。与 tzf-rs 数据的差异反映了通过 PyO3 的 Python → Rust FFI 开销。

## 关键结论

- **YStripes 可显著降低多边形查询延迟**。Rust `Finder` 使用完整精度数据时，中位延迟从 43.0520 µs 降至 1.2227 µs，速度提升 35.2 倍。使用拓扑简化数据时，中位延迟从 4.9164 µs 降至 0.5698 µs，速度提升 8.6 倍。
- **DefaultFinder 是 Rust 通用场景的最佳选择**。拓扑简化数据的中位延迟为 0.3040 µs，完整精度数据为 0.5527 µs。与启用 YStripes 的对应 `Finder` 相比，预索引增加约 9 到 12 MiB 内存。
- **FuzzyFinder 适合作为配有回退机制的快速路径**。查询未命中时耗时 0.1564 µs，`DefaultFinder` 通过 YStripes 回退处理相同的边界城市工作负载时耗时 0.6256 µs。仅当查询坐标确定远离时区边界时，才适合单独使用 FuzzyFinder。
- **Python 同样能从 YStripes 中显著受益**。tzfpy 的中位延迟从 1.6410 µs 降至 0.6533 µs，吞吐量从 604.3 Kops/s 提升至 1490.1 Kops/s，约为原来的 2.5 倍。
- **完整精度数据会增加内存开销**。启用 YStripes 时，从拓扑简化数据切换到完整精度数据会使 Rust 峰值 RSS 增加约 241 到 245 MiB。在 Go 中，对应 Finder 的内存占用从约 30 MiB 增至约 153 到 155 MiB。
