---
date: '2025-07-19T13:58:16+09:00'
description: tzf v2 在 Go、Rust 和 Python 中的性能、精度与内存基准测试。
draft: false
lastmod: '2026-09-14T00:00:00+09:00'
seo:
  description: tzf v2 的基准测试结果：Go、Rust 和 Python 中默认、嵌入式和完整精度查找器的查询延迟、与完整精度基准的精度对比及内存占用。
  noindex: false
  title: '基准测试 - Project tzf'
summary: 来自 2026-09-14 tz-benchmark 快照的 tzf v2 查找器查询延迟、精度和内存数据。
title: 基准测试
toc: true
weight: 5
---

项目有两套用途不同的基准测试。

**持续基准测试**：源代码及结果位于 <https://github.com/ringsaturn/tz-benchmark>，可视化展示在 <https://ringsaturn.github.io/tz-benchmark/>。它在每次发布时于 GitHub Actions 中运行，用于跨包对比。运行器硬件与开发机不同，因此绝对数值与本地运行有差异，包之间的相对次序可以对比。持续基准测试自 2026-09-11 起覆盖 tzf v2。

**按日期归档的快照**：[`snapshot/`](https://github.com/ringsaturn/tz-benchmark/tree/main/snapshot) 下的目录在 Apple M3 Max 上本机取得。本页全部数据来自 `2026-09-14` 快照，针对已发布的 tzf v2.1.1、tzf-rs 2.1.1 以及 tzfpy 2.1.0b2 预发布版（lite 与 `+full` 两种 wheel）测得，三者均基于 tzf-dist `v0.0.2026-c-tzb2`。

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

Apple M3 Max，`2026c` 数据集，2026-09-14 快照。

### Go (tzf v2)

| 基准项 | ns/op | p50 (ns) | p99 (ns) | B/op | allocs/op |
| --- | ---: | ---: | ---: | ---: | ---: |
| `NewDefaultFinder`，世界城市 | 345.8 | 208.0 | 1500 | 0 | 0 |
| `NewDefaultFinder`，边界城市 | 543.7 | 459.0 | 1208 | 0 | 0 |
| `NewEmbeddedFinder`，世界城市 | 533.7 | 333.0 | 2500 | 0 | 0 |
| `NewEmbeddedFinder`，边界城市 | 1162 | 1000 | 2791 | 0 | 0 |
| `NewFullFinder`，世界城市 | 347.9 | 208.0 | 1583 | 0 | 0 |
| `NewFullFinder`，边界城市 | 606.7 | 500.0 | 1750 | 0 | 0 |

三个查找器的查询过程都不分配内存。

### Rust (tzf-rs 2.1)

| 基准项 | ns/iter | 标准差 (ns) |
| --- | ---: | ---: |
| `DefaultFinder`，随机城市 | 221.13 | 41.39 |
| `DefaultFinder`，随机边界城市 | 474.83 | 52.12 |
| `EmbeddedFinder`，随机城市 | 292.68 | 51.42 |
| `EmbeddedFinder`，随机边界城市 | 666.11 | 48.17 |

### Python (tzfpy 2.1.0b2)

使用 `pytest-benchmark`，每轮调用一次 `get_tz()`。

| 基准项 | 中位数 (ns) | 平均 (ns) | OPS (Kops/s) |
| --- | ---: | ---: | ---: |
| 随机城市，lite | 625.0 | 718.7 | 1,391.4 |
| 随机边界城市，lite | 834.0 | 907.0 | 1,102.5 |
| 随机城市，`+full` | 667.0 | 822.7 | 1,215.5 |
| 随机边界城市，`+full` | 1,167.0 | 1,292.3 | 773.8 |

单次调用的开销与 Rust 的数值相当，差异来自通过 PyO3 从 Python 调用 Rust 的开销。`+full` 两行是 tzfpy 自有索引发布的实验性完整精度 wheel，它用 tzf-rs 的 `EmbeddedFinder` 原地查询 `full.tzb`。

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
| cities | 154,694 | tzfpy `+full` | 0 | 0.0000 | 0 |
| edges | 23,408 | Go `NewDefaultFinder`（lite `.tzm`） | 1 | 0.0043 | 1 |
| edges | 23,408 | Go `NewFullFinder`（full `.tzb`） | 0 | 0.0000 | 0 |
| edges | 23,408 | Rust `DefaultFinder` | 1 | 0.0043 | 1 |
| edges | 23,408 | tzfpy | 1 | 0.0043 | 1 |
| edges | 23,408 | tzfpy `+full` | 0 | 0.0000 | 0 |
| uniform | 1,000,000 | Go `NewDefaultFinder`（lite `.tzm`） | 19 | 0.0019 | 14 |
| uniform | 1,000,000 | Go `NewFullFinder`（full `.tzb`） | 0 | 0.0000 | 0 |

lite 与完整精度查找器的差异只出现在边界附近。简化的位移上限为 111.2 m，完整的位移数据见[常见问题]({{< relref "../guides/faq#is-tzf-100-accurate" >}})。

## 内存

数值单位为 MiB。

### Go

| 候选项 | 基线 | 初始化峰值 | 常驻 | 加载后 RSS |
| --- | ---: | ---: | ---: | ---: |
| Go 运行时基线 | 4.7 | 4.7 | 0.2 | 5.0 |
| `NewDefaultFinder`（lite `.tzm`） | 5.1 | 41.5 | 13.1 | 41.5 |
| `NewEmbeddedFinder`（lite `.tzb` 原地查询） | 5.2 | 9.2 | 0.3 | 9.6 |
| `NewFullFinder`（full `.tzb`） | 5.2 | 315.5 | 147.0 | 315.5 |

### Rust

| 候选项 | 基线 | 初始化峰值 | 常驻 | 加载后 RSS |
| --- | ---: | ---: | ---: | ---: |
| Rust 运行时基线 | 5.8 | 5.9 | 0.0 | 5.9 |
| `DefaultFinder` | 5.8 | 46.6 | 22.8 | 46.5 |
| `EmbeddedFinder` | 5.8 | 10.3 | 0.2 | 10.4 |

`EmbeddedFinder` 的常驻值为 0.2 MiB：其数据是 `'static` 的嵌入切片，计数型分配器记录到的只有 tzf-rs 2.1 在打开时构建的索引（chunk 跳过块和每个 group 的纬度条带）。

### Python

| 候选项 | 基线 | 初始化峰值 | 常驻 | 加载后 RSS |
| --- | ---: | ---: | ---: | ---: |
| Python 解释器基线 | 22.4 | 22.4 | n/a | 22.4 |
| tzfpy（lite） | 22.4 | 60.3 | n/a | 60.2 |
| tzfpy `+full` | 22.4 | 38.2 | n/a | 38.2 |

## 观察结果

- 原地机制以查询延迟换取内存。在 Go 中，初始化峰值从 41.5 MiB 降到 9.2 MiB，同时世界城市的中位延迟从 208 ns 升到 333 ns，边界城市的中位延迟从 459 ns 升到 1,000 ns。
- 与 2026-09-11 快照相比，原地查找器的边界城市数值从 8,959 ns 降到 1,000 ns（Go p50）、从 4,779.81 ns 降到 666.11 ns（Rust 平均值）。变化来自 tzf 2.1 与 tzf-rs 2.1 重写的查询遍历，以及 `v0.0.2026-c-tzb2` 的 64 点 chunk；展开式查找器在噪声范围内不变，结果完全一致。
- tzfpy `+full` 预发布版的边界城市中位延迟为 1,167 ns（lite wheel 为 834 ns），初始化峰值 38.2 MiB（lite wheel 为 60.3 MiB）。
- 完整精度数据集增加的是内存而非延迟。Go 的初始化峰值从 41.5 MiB 升到 315.5 MiB，世界城市的中位延迟保持在 208 ns。
- 初始化峰值高于稳定状态的开销。Go 默认查找器峰值 41.5 MiB，常驻 13.1 MiB；完整精度查找器峰值 315.5 MiB，常驻 147.0 MiB。容器内存按峰值规划，长期运行成本按常驻值估算。
- 各语言的运行时基线不同（Go 4.7 MiB、Rust 5.8 MiB、Python 22.4 MiB），跨语言比较总量前需要先减去这部分。
- lite 数据集在 154,694 个世界城市中与完整精度基准有 1 处不一致，且该结果对应的 UTC 偏移量相同。
