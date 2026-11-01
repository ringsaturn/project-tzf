---
date: '2025-07-19T13:58:16+09:00'
description: tzf v2 在 Go、Rust 和 Python 中的性能、精度与内存基准测试。
draft: false
lastmod: '2026-11-01T00:00:00+09:00'
seo:
  description: tzf v2 的基准测试结果：Go、Rust 和 Python 中默认、嵌入式和完整精度查找器的查询延迟、与完整精度基准的精度对比及内存占用。
  noindex: false
  title: '基准测试 - Project tzf'
summary: 来自 2026-11-01 tz-benchmark 快照的 tzf v2 查找器查询延迟、精度和内存数据。
title: 基准测试
toc: true
weight: 5
---

项目有两套用途不同的基准测试。

**持续基准测试**：源代码及结果位于 <https://github.com/ringsaturn/tz-benchmark>，可视化展示在 <https://ringsaturn.github.io/tz-benchmark/>。它在每次发布时于 GitHub Actions 中运行，用于跨包对比。运行器硬件与开发机不同，因此绝对数值与本地运行有差异，包之间的相对次序可以对比。持续基准测试自 2026-09-11 起覆盖 tzf v2。

**按日期归档的快照**：[`snapshot/`](https://github.com/ringsaturn/tz-benchmark/tree/main/snapshot) 下的目录在 Apple M3 Max 上本机取得。本页全部数据来自 `2026-11-01` 快照，针对已发布的 tzf v2.1.4、tzf-rs 2.1.4 和 tzfpy 2.1.2（lite 与 `+full` 两种 wheel）测得，三者均基于 tzf-dist `v0.0.2026-f`。

## 测试方法

每个查找器初始化一次并复用于所有查询，与文档中的生产环境用法一致。查询采样两个数据集：170,540 个世界城市（`gt_cities.csv`）和 23,408 个靠近边界的点（`gt_edges.csv`），均以完整精度的 `2026f` 数据作为基准。精度测试在 Go 中还运行了 1,000,000 个均匀随机点的数据集。

内存按候选项在独立的子进程中测量。下文出现四列，它们的口径互不相同：

| 列 | 含义 |
| --- | --- |
| 基线 | 构造候选项之前的 RSS |
| 初始化峰值 | 加载过程中达到的高水位（`ru_maxrss`）。容器内存限制必须能容纳该值，否则进程会在启动阶段被杀死，即便它稳定运行时的占用完全放得下 |
| 常驻 | 候选项准备好接受查询后实际持有的数据量，来自语言原生的内存统计：Go 为强制 GC 后的 `HeapAlloc`，Rust 为计数型全局分配器。Python 的数据保存在 Python 堆之外，因此为 `n/a` |
| 加载后 RSS | 进程准备好接受查询时操作系统报告的值。它更接近初始化峰值而非常驻值，因为释放内存并不会让 RSS 缩小，分配器会保留这些页面以便复用 |

每个候选项的 `常驻` 都是三个数值中最小的；`加载后 RSS` 比 `初始化峰值` 最多高 0.5 MiB。

## 查询延迟

Apple M3 Max，`2026f` 数据集，2026-11-01 快照。

### Go (tzf v2)

| 基准项 | ns/op | p50 (ns) | p99 (ns) | B/op | allocs/op |
| --- | ---: | ---: | ---: | ---: | ---: |
| `NewDefaultFinder`，世界城市 | 350.0 | 208.0 | 1500 | 0 | 0 |
| `NewDefaultFinder`，边界城市 | 556.5 | 500.0 | 1250 | 0 | 0 |
| `NewEmbeddedFinder`，世界城市 | 535.8 | 333.0 | 2542 | 0 | 0 |
| `NewEmbeddedFinder`，边界城市 | 1230 | 1042 | 2750 | 0 | 0 |
| `NewFullFinder`，世界城市 | 354.5 | 208.0 | 1708 | 0 | 0 |
| `NewFullFinder`，边界城市 | 591.8 | 500.0 | 1542 | 0 | 0 |

三个查找器的查询过程都不分配内存。

### Rust (tzf-rs 2.1.4)

| 基准项 | ns/iter | 标准差 (ns) |
| --- | ---: | ---: |
| `DefaultFinder`，随机城市 | 225.62 | 21.17 |
| `DefaultFinder`，随机边界城市 | 489.33 | 10.13 |
| `EmbeddedFinder`，随机城市 | 350.34 | 110.85 |
| `EmbeddedFinder`，随机边界城市 | 686.94 | 8.99 |

### Python (tzfpy 2.1.2)

使用 `pytest-benchmark`，每轮调用一次 `get_tz()`。

| 基准项 | 中位数 (ns) | 平均 (ns) | OPS (Kops/s) |
| --- | ---: | ---: | ---: |
| 随机城市，lite | 666.0 | 745.4 | 1,341.6 |
| 随机边界城市，lite | 875.0 | 958.8 | 1,042.9 |
| 随机城市，`+full` | 667.0 | 810.5 | 1,233.8 |
| 随机边界城市，`+full` | 1,208.0 | 1,313.5 | 761.4 |

单次调用的开销与 Rust 的数值相当，差异来自通过 PyO3 从 Python 调用 Rust 的开销。`+full` 两行是 tzfpy 自有索引发布的实验性完整精度 wheel，它用 tzf-rs 的 `EmbeddedFinder` 原地查询 `full.tzb`。

## 精度

与完整精度 `2026f` 基准对比的错误率。「偏移量相同」统计的是对应 UTC 偏移量相同的错误结果。

| 数据集 | N | 候选项 | 错误数 | 错误率 % | 偏移量相同 |
| --- | ---: | --- | ---: | ---: | ---: |
| cities | 170,540 | Go `NewDefaultFinder`（lite `.tzm`） | 2 | 0.0012 | 1 |
| cities | 170,540 | Go `NewEmbeddedFinder`（lite `.tzb`） | 2 | 0.0012 | 1 |
| cities | 170,540 | Go `NewFullFinder`（full `.tzb`） | 0 | 0.0000 | 0 |
| cities | 170,540 | Rust `DefaultFinder` | 2 | 0.0012 | 1 |
| cities | 170,540 | Rust `EmbeddedFinder` | 2 | 0.0012 | 1 |
| cities | 170,540 | tzfpy | 2 | 0.0012 | 1 |
| cities | 170,540 | tzfpy `+full` | 0 | 0.0000 | 0 |
| edges | 23,408 | Go `NewDefaultFinder`（lite `.tzm`） | 1 | 0.0043 | 1 |
| edges | 23,408 | Go `NewFullFinder`（full `.tzb`） | 0 | 0.0000 | 0 |
| edges | 23,408 | Rust `DefaultFinder` | 1 | 0.0043 | 1 |
| edges | 23,408 | tzfpy | 1 | 0.0043 | 1 |
| edges | 23,408 | tzfpy `+full` | 0 | 0.0000 | 0 |
| uniform | 1,000,000 | Go `NewDefaultFinder`（lite `.tzm`） | 21 | 0.0021 | 14 |
| uniform | 1,000,000 | Go `NewFullFinder`（full `.tzb`） | 0 | 0.0000 | 0 |

lite 与完整精度查找器的差异只出现在边界附近。简化的位移上限为 111.2 m，完整的位移数据见[常见问题]({{< relref "../guides/faq#is-tzf-100-accurate" >}})。

## 内存

数值单位为 MiB。

### Go

| 候选项 | 基线 | 初始化峰值 | 常驻 | 加载后 RSS |
| --- | ---: | ---: | ---: | ---: |
| Go 运行时基线 | 5.1 | 5.1 | 0.3 | 5.4 |
| `NewDefaultFinder`（lite `.tzm`） | 5.5 | 44.5 | 13.3 | 44.6 |
| `NewEmbeddedFinder`（lite `.tzb` 原地查询） | 5.7 | 9.6 | 0.4 | 10.1 |
| `NewFullFinder`（full `.tzb`） | 5.7 | 266.7 | 148.9 | 266.9 |

### Rust

| 候选项 | 基线 | 初始化峰值 | 常驻 | 加载后 RSS |
| --- | ---: | ---: | ---: | ---: |
| Rust 运行时基线 | 5.8 | 5.8 | 0.0 | 5.9 |
| `DefaultFinder` | 5.8 | 44.5 | 23.1 | 44.3 |
| `EmbeddedFinder` | 5.8 | 10.2 | 0.2 | 10.2 |

`EmbeddedFinder` 的常驻值为 0.2 MiB：其数据是 `'static` 的嵌入切片，计数型分配器记录到的只有 tzf-rs 2.1 在打开时构建的索引（chunk 跳过块和每个 group 的纬度条带）。

### Python

| 候选项 | 基线 | 初始化峰值 | 常驻 | 加载后 RSS |
| --- | ---: | ---: | ---: | ---: |
| Python 解释器基线 | 22.5 | 22.5 | n/a | 22.5 |
| tzfpy（lite） | 22.5 | 61.3 | n/a | 61.2 |
| tzfpy `+full` | 22.5 | 38.8 | n/a | 38.8 |

## 观察结果

- 原地机制以查询延迟换取内存。在 Go 中，初始化峰值从 44.5 MiB 降到 9.6 MiB，同时世界城市的中位延迟从 208 ns 升到 333 ns，边界城市的中位延迟从 500 ns 升到 1,042 ns。
- 与 2026-09-14 快照（tzf v2.1.1、`2026c`）相比，Go 世界城市的中位延迟仍为 208、333、208 ns，Go 边界城市的中位延迟相差最多 42 ns。Rust `EmbeddedFinder` 随机城市的平均值从 292.68 ns 升到 350.34 ns，本次运行的标准差为 110.85 ns。Go `NewFullFinder` 的初始化峰值从 315.5 MiB 降到 266.7 MiB，常驻堆保持在约 148 MiB；初始化峰值变化的原因未查明。
- tz-benchmark 于 2026-09-20 更新了基准数据文件，世界城市数据集从 154,694 个增加到 170,540 个，因此精度计数不能与 2026-09-14 的表格直接比较。
- tzfpy `+full` wheel 的边界城市中位延迟为 1,208 ns（lite wheel 为 875 ns），初始化峰值 38.8 MiB（lite wheel 为 61.3 MiB）。
- 完整精度数据集增加的是内存而非延迟。Go 的初始化峰值从 44.5 MiB 升到 266.7 MiB，世界城市的中位延迟保持在 208 ns。
- 初始化峰值高于稳定状态的开销。Go 默认查找器峰值 44.5 MiB，常驻 13.3 MiB；完整精度查找器峰值 266.7 MiB，常驻 148.9 MiB。容器内存按峰值规划，长期运行成本按常驻值估算。
- 各语言的运行时基线不同（Go 5.1 MiB、Rust 5.8 MiB、Python 22.5 MiB），跨语言比较总量前需要先减去这部分。
- lite 数据集在 170,540 个世界城市中与完整精度基准有 2 处不一致，测试工具将其中 1 处计为 UTC 偏移量相同。
