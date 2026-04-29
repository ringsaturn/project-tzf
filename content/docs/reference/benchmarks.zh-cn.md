---
date: '2025-07-19T13:58:16+09:00'
description: tzf 各语言实现的性能基准测试，涵盖 Go 和 Rust。
draft: false
lastmod: '2026-04-26T00:00:00+09:00'
seo:
  description: tzf 和 tzf-rs 的性能基准测试结果，涵盖默认、模糊和完整精度查找器，包含 YStripes 和预索引。
  noindex: false
  title: 基准测试——Project tzf
summary: tzf (Go) 和 tzf-rs (Rust) 基准测试结果，涵盖不同查找器类型、数据集和索引模式。
title: 基准测试
toc: true
weight: 4
---

项目有两套独立的基准测试，用途不同：

**持续基准测试**——源代码及结果位于 <https://github.com/ringsaturn/tz-benchmark>，
可视化展示在 <https://ringsaturn.github.io/tz-benchmark/>。
每次发布时在 GitHub Actions 中自动运行，用于跨包对比。
由于 GitHub Actions 运行器与开发者机器硬件不同，绝对数值与本地运行有所差异，但包之间的相对趋势可以说明问题。

**本地基准测试**——以下表格在搭载 Apple M3 Max 的 MacBook Pro 上测得。
这些结果更能反映现代硬件上真实场景的延迟。

## 测试方法

每个查找器初始化一次并复用于所有查询，匹配推荐的生产环境模式。
查询使用全球城市坐标的代表性样本加上特意选取的边界边缘案例点。

## Go (tzf v1.1.0)

| 目标          | 数据集                      | 场景                                   | 中位数 (ns) | p99 (ns) | 吞吐量 (ops/s) | 内存 (MiB) |
| ------------- | --------------------------- | -------------------------------------- | ----------: | -------: | -------------: | ---------: |
| DefaultFinder | topology-simplified + preindex | edge case · GetTimezoneName            |      3000.0 |   3000.0 |         393.5K |      74.70 |
| Finder        | topology-simplified            | edge case · GetTimezoneName            |      2000.0 |   3000.0 |         470.4K |      66.00 |
| FullFinder    | full-precision + preindex      | edge case · GetTimezoneName            |      3000.0 |   3000.0 |         395.6K |     421.50 |
| Finder        | full-precision                 | edge case · GetTimezoneName            |      2000.0 |   3000.0 |         475.3K |     412.70 |
| DefaultFinder | topology-simplified + preindex | random world cities · GetTimezoneName  |      1000.0 |   4000.0 |        1162.4K |      74.70 |
| FuzzyFinder   | preindex                       | random world cities · GetTimezoneName  |       469.8 |   1000.0 |        2128.6K |       8.90 |
| Finder        | topology-simplified            | random world cities · GetTimezoneName  |      2000.0 |   4000.0 |         531.6K |      66.00 |
| FullFinder    | full-precision + preindex      | random world cities · GetTimezoneName  |      1000.0 |   4000.0 |        1143.1K |     421.50 |
| Finder        | full-precision                 | random world cities · GetTimezoneName  |      2000.0 |   5000.0 |         468.6K |     412.70 |
| DefaultFinder | topology-simplified + preindex | random world cities · GetTimezoneNames |      5000.0 |   9000.0 |         208.0K |      74.70 |
| FuzzyFinder   | preindex                       | random world cities · GetTimezoneNames |       462.7 |   1000.0 |        2161.2K |       8.90 |
| Finder        | topology-simplified            | random world cities · GetTimezoneNames |      5000.0 |   8000.0 |         211.5K |      66.00 |
| FullFinder    | full-precision + preindex      | random world cities · GetTimezoneNames |      5000.0 |   9000.0 |         192.8K |     421.50 |

## Rust (tzf-rs v1.2.0 / v1.3.0)

### 拓扑简化（默认内置）

| 目标          | 数据集                      | 场景          | 中位数 (µs) | 吞吐量 (ops/s) | 内存 (MiB) |
| ------------- | --------------------------- | ------------- | ----------: | -------------: | ---------: |
| Finder        | topology-simplified            | YStripes only |      1.2296 |        813,273 |     103.30 |
| Finder        | topology-simplified            | No index      |      6.5402 |        152,901 |      51.68 |
| DefaultFinder | topology-simplified + preindex | YStripes only |      1.1383 |        878,503 |     125.98 |
| DefaultFinder | topology-simplified + preindex | No index      |      2.2514 |        444,168 |      77.79 |

### 完整精度（可选 `full` feature）

| 目标                 | 数据集                   | 场景          | 中位数 (µs) | 吞吐量 (ops/s) | 内存 (MiB) |
| -------------------- | ------------------------ | ------------- | ----------: | -------------: | ---------: |
| Finder (full)        | full-precision            | YStripes only |      2.0852 |        479,570 |     561.08 |
| Finder (full)        | full-precision            | No index      |     37.6980 |         26,527 |     252.54 |
| DefaultFinder (full) | full-precision + preindex | YStripes only |      1.3488 |        741,400 |     584.30 |
| DefaultFinder (full) | full-precision + preindex | No index      |     11.2750 |         88,692 |     278.63 |

## Python (tzfpy v1.2.0)

tzfpy 是基于 tzf-rs 的 PyO3 绑定。基准测试使用 `pytest-benchmark` 测量
单次 `get_tz()` 调用（随机坐标，拓扑简化数据集）。
结果来自搭载 Apple M3 Max 的 MacBook Pro。

| 索引模式                                   | 中位数 (µs) | 平均值 (µs) | 吞吐量 (Kops/s) | 内存       |
| ------------------------------------------ | ----------: | ----------: | --------------: | ---------- |
| 默认（YStripes 启用）                       |      1.7934 |      1.8321 |           545.8 | ~120 MB    |
| 无 YStripes（`_TZFPY_DISABLE_Y_STRIPES=1`） |      2.5213 |      2.5338 |           394.7 | 未测量     |

每次调用开销与原始 Rust 数据相当；与 tzf-rs 数据的差异反映了通过 PyO3 的 Python → Rust FFI 开销。

## 关键结论

- **YStripes 索引**为完整精度 Finder 带来显著提升：从 37.7 µs（无索引）降至 2.1 µs——约 18 倍加速。对拓扑简化数据集效果较小但仍然显著（6.5 µs → 1.2 µs，约 5 倍加速）。
- **DefaultFinder**（预索引 + 多边形）在一般工作负载中始终表现最佳：中位数约 1 µs，内存约 75–126 MB，与数据集无关。
- **FuzzyFinder**（仅预索引）在约 470 ns 时最快，但仅覆盖完全位于单个时区多边形内部的瓦片。对于靠近边界或未覆盖瓦片的点，它返回空结果而非猜测。仅在你的工作负载已知远离时区边界时单独使用。
- **Python (tzfpy)** 在 Rust 基线之上增加了约 0.5–1 µs 的 PyO3 FFI 开销。启用 YStripes 后中位数约为 1.8 µs——在大多数后端 API 预算范围内。
- **内存随数据集扩展**：在 Rust 中从拓扑简化切换到完整精度，启用 YStripes 后内存增加约 450 MB。
