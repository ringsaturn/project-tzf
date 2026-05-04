---
date: '2025-07-19T11:07:00+09:00'
description: Project tzf 常见问题解答 - 准确性、内存、坐标顺序等。
draft: false
lastmod: '2025-07-19T11:07:00+09:00'
seo:
  description: Project tzf 常见问题解答 - 准确性、内存使用、坐标顺序及数据更新。
  noindex: false
  title: 常见问题 - Project tzf
summary: 关于 tzf 设计、限制和使用的常见问题解答。
title: 常见问题
toc: true
weight: 95
---

## 坐标顺序是什么？

所有 tzf 实现均采用 **(经度，纬度)** 顺序，与 GeoJSON 和大多数地理 API 一致。
请注意，部分系统（如 Google Maps URL、许多地理教材）使用 (纬度，经度) 顺序，传递数值前请仔细确认。

## tzf 是 100% 准确的吗？

默认情况下不是。tzf 使用多边形简化算法（[Ramer-Douglas-Peucker](https://en.wikipedia.org/wiki/Ramer%E2%80%93Douglas%E2%80%93Peucker_algorithm)）来减小数据体积，
对于距离时区边界约 1 公里以内的点，可能产生不正确的结果。

如需 100% 准确的查询，请使用完整数据集：
- **Go**：`tzf.NewFullFinder()`
- **Rust**：启用 `full` feature（参见[快速开始]({{< relref "getting-started#rust" >}})）
- **Python/tzfpy**：目前不支持完整精度模式

## tzf 使用多少内存？

| 模式 (Go)                                     | 内存    |
| --------------------------------------------- | ------- |
| DefaultFinder（拓扑简化 + 预索引）             | ~75 MB  |
| Finder（拓扑简化）                             | ~66 MB  |
| FullFinder（完整精度 + 预索引）                | ~422 MB |

Rust 内存用量相似。启用 YStripes 索引大约增加 30 到 40 MB。
Rust 完整精度模式（启用 YStripes）约使用 560 MB。
Python 内部使用 Rust 二进制文件，因此内存占用与 Rust 默认模式一致。

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
