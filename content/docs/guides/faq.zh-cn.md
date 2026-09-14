---
date: '2025-07-19T11:07:00+09:00'
description: 'Project tzf 常见问题解答 - 准确性、内存、坐标顺序等。'
draft: false
lastmod: '2026-09-14T00:00:00+09:00'
seo:
  description: 'Project tzf 常见问题解答 - 准确性、内存使用、坐标顺序及数据更新。'
  noindex: false
  title: '常见问题 - Project tzf'
summary: 关于 tzf 设计、限制和使用的常见问题解答。
title: 常见问题
toc: true
weight: 95
---

## 坐标顺序是什么？

所有 tzf 实现均采用 **(经度，纬度)** 顺序，与 GeoJSON 和大多数地理 API 一致。
请注意，部分系统（如 Google Maps URL、许多地理教材）使用 (纬度，经度) 顺序，传递数值前请仔细确认。

## tzf 是 100% 准确的吗？

默认查询器在时区边界附近无法保证与完整精度数据集一致。它使用 epsilon 为 0.001 度的拓扑感知 [Douglas-Peucker 简化算法](https://en.wikipedia.org/wiki/Ramer%E2%80%93Douglas%E2%80%93Peucker_algorithm)，将边界位移限制在约 111 米内。

与完整精度的 2026c 数据集对比后，测量结果记录在 [BORDER_CHANGE.md](https://github.com/ringsaturn/tzf/blob/main/BORDER_CHANGE.md) 中：

| 指标                              | 结果                         |
| --------------------------------- | ---------------------------- |
| 经认证的最大边界位移          | 111.7 米，容差 1.0 米       |
| 位移超过 100 米的边界长度占比 | 0.41%                        |
| 位移超过 500 米的边界长度占比 | 0%                           |
| 误分配区域总面积                  | 16,962 平方公里，约占地球面积的 0.003% |
| 真实边界 100 米内的误分配面积占比 | 92.8%                 |

只有位于时区边界约 111 米以内的查询才可能与完整精度结果不同，大多数受影响区域的宽度还要更小。

如需 100% 准确的查询，请使用完整数据集：

- **Go**：`tzf.NewFullFinder()`
- **Rust**：在 `default-features = false` 的前提下启用仅 git 提供的 `full` feature（参见[快速开始]({{< relref "getting-started#rust" >}})）
- **Python/tzfpy**：使用 tzfpy 自有索引发布的实验性 `+full` 预发布 wheel（`pip install --pre tzfpy --index-url https://ringsaturn.github.io/tzfpy/full/simple/`）；PyPI 上的 wheel 只包含 lite 数据集

在 [tz-benchmark](https://github.com/ringsaturn/tz-benchmark) 的 2026-09-14 快照中，lite 查找器在 154,694 个世界城市上与完整精度基准有 1 处不一致（0.0006%），且该结果对应的 UTC 偏移量相同。

## tzf 使用多少内存？

初始化开销和运行时开销不是同一个数字。构建查找器时分配的内存远多于查找器最终持有的量：文件被解码，据此建立查询结构，中间结果随后成为垃圾；而释放内存并不会让 RSS 缩小，分配器会保留这些页面以便复用。因此查找器稳定运行时持有的数据，比加载过程中的高水位小好几倍。

以下数据来自 [2026-09-14 基准快照](https://github.com/ringsaturn/tz-benchmark/tree/main/snapshot)，在 Apple M3 Max 上针对 `2026c` 数据集测得。每个候选项都在独立的子进程中运行。

| 实现   | 查找器 | 初始化峰值 | 常驻 | 加载后 RSS |
| ------ | ------ | ---------: | ---: | ---------: |
| Go | `NewDefaultFinder`（lite `.tzm`） | 41.5 MiB | 13.1 MiB | 41.5 MiB |
| Go | `NewEmbeddedFinder`（lite `.tzb` 原地查询） | 9.2 MiB | 0.3 MiB | 9.6 MiB |
| Go | `NewFullFinder`（full `.tzb`） | 315.5 MiB | 147.0 MiB | 315.5 MiB |
| Rust | `DefaultFinder` | 46.6 MiB | 22.8 MiB | 46.5 MiB |
| Rust | `EmbeddedFinder` | 10.3 MiB | 0.2 MiB | 10.4 MiB |
| Python | tzfpy（lite，默认查找器） | 60.3 MiB | n/a | 60.2 MiB |
| Python | tzfpy `+full`（预发布版，原地查询） | 38.2 MiB | n/a | 38.2 MiB |

- **初始化峰值：** 加载过程中达到的高水位（`ru_maxrss`）。容器内存限制必须能容纳这个值，否则进程会在启动阶段被杀死，即便它稳定运行时的占用完全放得下。
- **常驻：** 查找器准备好接受查询后实际持有的数据量，来自语言原生的内存统计（Go 为强制 GC 后的 `HeapAlloc`，Rust 为计数型全局分配器）。Python 的数据保存在 Python 堆之外，因此为 `n/a`。Rust 的 `EmbeddedFinder` 显示约 0，因为其数据是 `'static` 的嵌入切片，不在堆上。
- 同一测试环境中，各语言运行时的基线分别为 Go 4.7 MiB、Rust 5.8 MiB、Python 解释器 22.4 MiB，跨语言比较前需要先减去这部分。

按初始化峰值来规划容器内存，长期运行的实际成本以常驻值为准。实际内存用量会因平台、内存分配器和数据集版本而变化。

## 为什么初始化较慢？

首次调用 `NewDefaultFinder()` / `DefaultFinder::new()` 会加载并解析二进制时区数据。
这是一次性开销，后续查询非常快。
务必初始化一次并复用实例。有关使用全局变量或 `lazy_static` 的模式，请参见各语言指南。

## 时区数据多久更新一次？

tzf 通过 [evansiroky/timezone-boundary-builder](https://github.com/evansiroky/timezone-boundary-builder) 跟踪 [IANA 时区数据库](https://www.iana.org/time-zones) 的发布。
处理后的数据发布在 [ringsaturn/tzf-dist](https://github.com/ringsaturn/tzf-dist)，
包含 `lite.tzb`、`lite.tzm` 和 `full.tzb`，三者携带相同的 `data_version`。
各语言库版本会在上游数据发布后的短时间内跟进。

此前的 `tzf-rel` / `tzf-rel-lite` protobuf 产物不再发布。v1 系列（tzf v1.2.x、
tzf-rs 1.3.x、tzfpy 1.3.x）仍然可用，但冻结在最后一个 protobuf 数据版本上，
获取更新后的边界数据需要迁移到 v2。

## 应该使用哪个查找器？

v2 移除了独立的 `FuzzyFinder`。瓦片预索引现在是每个数据文件带有 FUZZY 区段的查找器内部的快速路径，tzf-dist 的三个产物都带有该区段。覆盖该点的瓦片会立即给出结果；边界附近查找器在内部回退到点在多边形内判定，因此调用方不需要处理空结果的情况。

| Go 构造函数 | Rust | 数据 | 常驻 | 查询 |
| --- | --- | --- | --- | --- |
| `NewDefaultFinder()` | `DefaultFinder::new()` | lite 内存镜像 / 展开的 lite | ~12 MB 堆 + 10 MB 只读（Go） | ~300 ns |
| `NewEmbeddedFinder()` | `EmbeddedFinder::new()` | 原地查询的 lite 文件 | ~4 MB（Go） | 预索引未命中时约 1.2 µs |
| `NewFullFinder()` | `DefaultFinder::new_full()` | 完整精度 | ~145 MB（Go） | ~300 ns |

包文档把 `NewDefaultFinder()` / `DefaultFinder::new()` 列为通用查找器。其余场景的实测数据，包括单核 Pod 和无文件系统的目标，记录在[选择查找器]({{< relref "choosing-a-finder" >}})。

## protobuf 去哪了？

v2 移除了它。边界数据现在以 TZF 嵌入式二进制格式分发：`.tzb` 用于传输，`.tzm` 为 Go 使用的内存镜像。两者的布局都支持直接查询，无需先把文件解析成对象图。`NewEmbeddedFinder` 读取的正是这种布局，它同时降低了打开耗时：在 Apple M3 Max 上，Go 完整精度查找器的打开耗时为 78.5 ms，protobuf 路径为 288 ms。

格式说明参见[嵌入式二进制格式]({{< relref "../reference/embedded-binary-format" >}})，迁移对照表参见各语言指南。

## tzf 使用什么许可证？

代码使用 MIT 许可证。时区数据（通过 `tzf-dist` 分发）使用 [ODbL](https://opendatacommons.org/licenses/odbl/)，
与上游 [evansiroky/timezone-boundary-builder](https://github.com/evansiroky/timezone-boundary-builder) 一致。

详见[许可证]({{< relref "../reference/licenses" >}})。
