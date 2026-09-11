---
date: '2025-07-19T13:58:16+09:00'
description: tzf v2 在 Go、Rust 和 Python 中的性能、精度与内存基准测试。
draft: false
lastmod: '2026-09-11T00:00:00+09:00'
seo:
  description: tzf v2 的基准测试结果：Go、Rust 和 Python 中默认、嵌入式和完整精度查找器的查询延迟、与完整精度基准的精度对比及内存占用。
  noindex: false
  title: '基准测试 - Project tzf'
summary: 来自 2026-09-11 tz-benchmark 快照的 tzf v2 查找器查询延迟、精度和内存数据。
title: 基准测试
toc: true
weight: 5
---

项目有两套用途不同的基准测试。

**持续基准测试**：源代码及结果位于 <https://github.com/ringsaturn/tz-benchmark>，可视化展示在 <https://ringsaturn.github.io/tz-benchmark/>。它在每次发布时于 GitHub Actions 中运行，用于跨包对比。运行器硬件与开发机不同，因此绝对数值与本地运行有差异，包之间的相对次序可以对比。持续基准测试自 2026-09-11 起覆盖 tzf v2。

**按日期归档的快照**：[`snapshot/`](https://github.com/ringsaturn/tz-benchmark/tree/main/snapshot) 下的目录在 Apple M3 Max 上本机取得。本页全部数据来自 `2026-09-11` 快照，针对已发布的 tzf v2.0.0、tzf-rs 2.0.0 和 tzfpy 2.0.0 测得。

## 测试方法

每个查找器初始化一次并复用于所有查询，与文档中的生产环境用法一致。查询采样两个数据集：154,694 个世界城市（`gt_cities.csv`）和 23,408 个靠近边界的点（`gt_edges.csv`），均以完整精度的 `2026c` 数据作为基准。精度测试在 Go 中还运行了 1,000,000 个均匀随机点的数据集。

内存按候选项在独立的子进程中测量。下文出现四列，它们的口径互不相同：

| 列 | 含义 |
| --- | --- |
| 基线 | 构造候选项之前的 RSS |
| 初始化峰值 | 加载过程中达到的高水位（`ru_maxrss`）。容器内存限制必须能容纳该值，否则进程会在启动阶段被杀死，即便它稳定运行时的占用完全放得下 |
| 常驻 | 候选项准备好接受查询后实际持有的数据量，来自语言原生的内存统计：Go 为强制 GC 后的 `HeapAlloc`，Rust 为计数型全局分配器。Python 的数据保存在 Python 堆之外，因此为 `n/a` |
| 加载后 RSS | 进程准备好接受查询时操作系统报告的值。它更接近初始化峰值而非常驻值，因为释放内存并不会让 RSS 缩小，分配器会保留这些页面以便复用 |

每个候选项都满足 `常驻 <= 加载后 RSS <= 初始化峰值`。

## 查询延迟

Apple M3 Max，`2026c` 数据集，2026-09-11 快照。

### Go (tzf v2)

| 基准项 | ns/op | p50 (ns) | p99 (ns) | B/op | allocs/op |
| --- | ---: | ---: | ---: | ---: | ---: |
| `NewDefaultFinder`，世界城市 | 357.5 | 208.0 | 1667 | 0 | 0 |
| `NewDefaultFinder`，边界城市 | 553.6 | 500.0 | 1292 | 0 | 0 |
| `NewEmbeddedFinder`，世界城市 | 2207 | 583.0 | 21250 | 0 | 0 |
| `NewEmbeddedFinder`，边界城市 | 10170 | 8959 | 30791 | 0 | 0 |
| `NewFullFinder`，世界城市 | 394.6 | 208.0 | 2250 | 0 | 0 |
| `NewFullFinder`，边界城市 | 612.1 | 500.0 | 1708 | 0 | 0 |

三个查找器的查询过程都不分配内存。

### Rust (tzf-rs 2.0)

| 基准项 | ns/iter | 标准差 (ns) |
| --- | ---: | ---: |
| `DefaultFinder`，随机城市 | 228.81 | 86.41 |
| `DefaultFinder`，随机边界城市 | 519.44 | 108.17 |
| `EmbeddedFinder`，随机城市 | 1,182.07 | 224.02 |
| `EmbeddedFinder`，随机边界城市 | 4,779.81 | 327.40 |

### Python (tzfpy 2.0)

使用 `pytest-benchmark`，每轮调用一次 `get_tz()`。

| 基准项 | 中位数 (ns) | 平均 (ns) | OPS (Kops/s) |
| --- | ---: | ---: | ---: |
| 随机城市 | 708.0 | 913.7 | 1,094.4 |
| 随机边界城市 | 1,125.0 | 1,284.0 | 778.8 |

单次调用的开销与 Rust 的数值相当，差异来自通过 PyO3 从 Python 调用 Rust 的开销。

## 精度

与完整精度 `2026c` 基准对比的错误率。「偏移量相同」统计的是对应 UTC 偏移量相同的错误结果。

| 数据集 | N | 候选项 | 错误数 | 错误率 % | 偏移量相同 |
| --- | ---: | --- | ---: | ---: | ---: |
| cities | 154,694 | Go `NewDefaultFinder`（lite `.tzm`） | 1 | 0.0006 | 1 |
| cities | 154,694 | Go `NewEmbeddedFinder`（lite `.tzb`） | 1 | 0.0006 | 1 |
| cities | 154,694 | Go `NewFullFinder`（full `.tzb`） | 0 | 0.0000 | 0 |
| cities | 154,694 | Rust `DefaultFinder` | 1 | 0.0006 | 1 |
| cities | 154,694 | Rust `EmbeddedFinder` | 1 | 0.0006 | 1 |
| cities | 154,694 | tzfpy | 1 | 0.0006 | 1 |
| edges | 23,408 | Go `NewDefaultFinder`（lite `.tzm`） | 1 | 0.0043 | 1 |
| edges | 23,408 | Go `NewFullFinder`（full `.tzb`） | 0 | 0.0000 | 0 |
| edges | 23,408 | Rust `DefaultFinder` | 1 | 0.0043 | 1 |
| edges | 23,408 | tzfpy | 1 | 0.0043 | 1 |
| uniform | 1,000,000 | Go `NewDefaultFinder`（lite `.tzm`） | 19 | 0.0019 | 14 |
| uniform | 1,000,000 | Go `NewFullFinder`（full `.tzb`） | 0 | 0.0000 | 0 |

lite 与完整精度查找器的差异只出现在边界附近。简化的位移上限为 111.2 m，完整的位移数据见[常见问题]({{< relref "../guides/faq#is-tzf-100-accurate" >}})。

## 内存

数值单位为 MiB。

### Go

| 候选项 | 基线 | 初始化峰值 | 常驻 | 加载后 RSS |
| --- | ---: | ---: | ---: | ---: |
| Go 运行时基线 | 4.7 | 4.7 | 0.2 | 5.0 |
| `NewDefaultFinder`（lite `.tzm`） | 5.1 | 43.4 | 13.1 | 43.4 |
| `NewEmbeddedFinder`（lite `.tzb` 原地查询） | 4.9 | 8.7 | 0.3 | 9.1 |
| `NewFullFinder`（full `.tzb`） | 5.2 | 315.0 | 147.0 | 315.0 |

### Rust

| 候选项 | 基线 | 初始化峰值 | 常驻 | 加载后 RSS |
| --- | ---: | ---: | ---: | ---: |
| Rust 运行时基线 | 5.8 | 5.8 | 0.0 | 5.9 |
| `DefaultFinder` | 5.8 | 46.8 | 22.8 | 46.8 |
| `EmbeddedFinder` | 5.8 | 9.8 | 0.0 | 9.8 |

`EmbeddedFinder` 的常驻值为 0.0，因为其数据是 `'static` 的嵌入切片，计数型分配器未记录到堆保留量。

### Python

| 候选项 | 基线 | 初始化峰值 | 常驻 | 加载后 RSS |
| --- | ---: | ---: | ---: | ---: |
| Python 解释器基线 | 22.4 | 22.4 | n/a | 22.4 |
| tzfpy | 22.4 | 62.3 | n/a | 62.2 |

## 观察结果

- 原地机制以查询延迟换取内存。在 Go 中，初始化峰值从 43.4 MiB 降到 8.7 MiB，同时世界城市的中位延迟从 208 ns 升到 583 ns，边界城市的中位延迟从 500 ns 升到 8,959 ns。
- 完整精度数据集增加的是内存而非延迟。Go 的初始化峰值从 43.4 MiB 升到 315.0 MiB，世界城市的中位延迟保持在 208 ns。
- 初始化峰值高于稳定状态的开销。Go 默认查找器峰值 43.4 MiB，常驻 13.1 MiB；完整精度查找器峰值 315.0 MiB，常驻 147.0 MiB。容器内存按峰值规划，长期运行成本按常驻值估算。
- 各语言的运行时基线不同（Go 4.7 MiB、Rust 5.8 MiB、Python 22.4 MiB），跨语言比较总量前需要先减去这部分。
- lite 数据集在 154,694 个世界城市中与完整精度基准有 1 处不一致，且该结果对应的 UTC 偏移量相同。
