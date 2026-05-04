---
date: "2025-07-19T13:58:16+09:00"
description: tzf 各语言实现的性能基准测试，涵盖 Go 和 Rust。
draft: false
lastmod: "2026-04-26T00:00:00+09:00"
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

## Rust (tzf-rs v1.3.0)

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

tzfpy 是基于 tzf-rs 的 PyO3 绑定。基准测试使用 `pytest-benchmark` 测量
单次 `get_tz()` 调用（随机坐标，拓扑简化数据集）。
结果来自搭载 Apple M3 Max 的 MacBook Pro。

| 索引模式                                    | 中位数 (µs) | 平均值 (µs) | 吞吐量 (Kops/s) | 内存    |
| ------------------------------------------- | ----------: | ----------: | --------------: | ------- |
| 默认（YStripes 启用）                       |      1.7934 |      1.8321 |           545.8 | ~120 MB |
| 无 YStripes（`_TZFPY_DISABLE_Y_STRIPES=1`） |      2.5213 |      2.5338 |           394.7 | 未测量  |

每次调用开销与原始 Rust 数据相当。与 tzf-rs 数据的差异反映了通过 PyO3 的 Python → Rust FFI 开销。

## 关键结论

- **YStripes 索引**为完整精度 Finder 带来显著提升：从 37.7 µs（无索引）降至 2.1 µs，约 18 倍加速。对拓扑简化数据集效果较小但仍然显著（6.5 µs → 1.2 µs，约 5 倍加速）。
- **DefaultFinder**（预索引 + 多边形）在一般工作负载中始终表现最佳：中位数约 1 µs，内存约 75 到 126 MB，与数据集无关。
- **FuzzyFinder**（仅预索引）在约 470 ns 时最快，但仅覆盖完全位于单个时区多边形内部的瓦片。对于靠近边界或未覆盖瓦片的点，它返回空结果而非猜测。仅在你的工作负载已知远离时区边界时单独使用。
- **Python (tzfpy)** 在 Rust 基线之上增加了约 0.5 到 1 µs 的 PyO3 FFI 开销。启用 YStripes 后中位数约为 1.8 µs，处于大多数后端 API 的预算范围内。
- **内存随数据集扩展**：在 Rust 中从拓扑简化切换到完整精度，启用 YStripes 后内存增加约 450 MB。
