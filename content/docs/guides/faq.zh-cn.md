---
date: '2025-07-19T11:07:00+09:00'
description: 'Project tzf 常见问题解答 - 准确性、内存、坐标顺序等。'
draft: false
lastmod: '2026-07-17T22:31:39+09:00'
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
| 经认证的最大边界位移          | 111.2 米，容差 1.0 米       |
| 位移超过 100 米的边界长度占比 | 0.41%                        |
| 位移超过 500 米的边界长度占比 | 0%                           |
| 误分配区域总面积                  | 16,828 平方公里，约占地球面积的 0.003% |
| 真实边界 100 米内的误分配面积占比 | 92.8%                 |

只有位于时区边界约 111 米以内的查询才可能与完整精度结果不同，大多数受影响区域的宽度还要更小。

如需 100% 准确的查询，请使用完整数据集：

- **Go**：`tzf.NewFullFinder()`
- **Rust**：启用 `full` feature（参见[快速开始]({{< relref "getting-started#rust" >}})）
- **Python/tzfpy**：目前不支持完整精度模式

## tzf 使用多少内存？

以下峰值常驻内存数据来自 Apple M3 Max 上的 [2026-07-14 基准快照](https://github.com/ringsaturn/tz-benchmark/blob/main/snapshot/2026-07-14-91bb3495bd282773baf61eac79a5f258b54d5656/README.md#memory)。增量已排除 Go、Rust 或 Python 运行时的基线内存。

| 实现   | 模式                              | 峰值 RSS | 相对基线增量 |
| ------ | --------------------------------- | -------: | -----------: |
| Go     | `FuzzyFinder`（仅预索引）         | 30.3 MiB |     24.7 MiB |
| Go     | `Finder`（拓扑简化）              | 114.7 MiB |   109.0 MiB |
| Go     | `DefaultFinder`（简化 + 预索引）  | 132.9 MiB |   127.1 MiB |
| Go     | `FullFinder`（完整精度 + 预索引） | 363.7 MiB |   357.9 MiB |
| Rust   | `FuzzyFinder`（仅预索引）         | 23.9 MiB |     18.1 MiB |
| Rust   | `Finder`（拓扑简化）              | 48.6 MiB |     42.8 MiB |
| Rust   | `DefaultFinder`（简化 + 预索引）  | 77.4 MiB |     71.5 MiB |
| Python | tzfpy `DefaultFinder`             | 92.4 MiB |     69.8 MiB |

实际内存用量会因平台、内存分配器和数据集版本而变化。

## 为什么初始化较慢？

首次调用 `NewDefaultFinder()` / `DefaultFinder::new()` 会加载并解析二进制时区数据。
这是一次性开销，后续查询非常快。
务必初始化一次并复用实例。有关使用全局变量或 `lazy_static` 的模式，请参见各语言指南。

## 时区数据多久更新一次？

tzf 通过 [evansiroky/timezone-boundary-builder](https://github.com/evansiroky/timezone-boundary-builder) 跟踪 [IANA 时区数据库](https://www.iana.org/time-zones) 的发布。
处理后的数据发布在 [ringsaturn/tzf-rel](https://github.com/ringsaturn/tzf-rel)。
各语言库版本会在上游数据发布后的短时间内跟进。

## Finder、FuzzyFinder 和 DefaultFinder 有什么区别？

| 类              | 使用的数据            | 覆盖范围                        | 速度   |
| --------------- | -------------------- | ------------------------------- | ------ |
| `FuzzyFinder`   | 仅瓦片预索引          | 仅内部瓦片，边界/未覆盖区域无结果 | 最快   |
| `Finder`        | 多边形数据            | 全球完整覆盖                     | 快     |
| `DefaultFinder` | 瓦片预索引 + 多边形   | 全球完整覆盖                     | 快     |

**FuzzyFinder** 预索引仅存储完全位于单个时区多边形内部的瓦片。
当查询点落在被覆盖的瓦片中时，可立即返回正确的时区。
当查询点落在未覆盖区域，例如边界附近、海岸线或稀疏区域时，返回空结果而不猜测。
它并非"近似"：结果准确，但覆盖范围不完整。

**DefaultFinder**（推荐）首先尝试瓦片预索引。如果未找到结果，则回退到完整多边形查询。
这使得大多数世界城市查询保持近乎恒定的速度，同时对所有坐标保持正确性。

## tzf 使用什么许可证？

代码使用 MIT 许可证。时区数据（通过 `tzf-rel` 分发）使用 [ODbL](https://opendatacommons.org/licenses/odbl/)，
与上游 [evansiroky/timezone-boundary-builder](https://github.com/evansiroky/timezone-boundary-builder) 一致。

此外，`tzf`、`tzf-rs` 和 `tzfpy` 附带"反 CSDN 许可证"条款，禁止在 CSDN 平台上使用该代码。该条款对其他使用场景无影响。

详见[许可证]({{< relref "../reference/licenses" >}})。
