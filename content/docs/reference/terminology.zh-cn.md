---
date: '2025-07-21T21:09:40+09:00'
description: tzf 生态系统中项目特定术语和概念的参考。
draft: false
lastmod: '2026-04-29T00:00:00+09:00'
seo:
  description: tzf 特定术语参考：Finder 类、tzf-dist 数据文件、多边形简化、拓扑感知处理、瓦片索引、YStripes 及内存用量。
  noindex: false
  title: 术语表 - Project tzf
summary: tzf 的 Finder 类、数据文件、算法及性能参考。
title: 术语表
toc: true
weight: 3
---

## API 行为

### 坐标顺序 {#coordinate-order}

所有 tzf 实现均采用 **(经度，纬度)** 顺序，与 GeoJSON 和大多数地理 API 一致。
请注意，部分系统（Google Maps URL、许多教材）使用 (纬度，经度)，传递数值前请仔细确认。

### 多时区 {#multiple-timezones}

位于时区边界附近的点可能属于多个时区。
使用多结果 API 获取所有候选项：

| 语言   | 函数                  |
| ------ | --------------------- |
| Go     | `GetTimezoneNames()`  |
| Rust   | `get_tz_names()`      |
| Python | `get_tzs()`           |
| Swift  | `getTimezones()`      |

## Finder 类

### FuzzyFinder {#fuzzyfinder}

仅使用瓦片预索引。索引中的每个瓦片覆盖的区域**完全位于**单个时区多边形内部。

- 点落在被覆盖的瓦片中 → 立即返回正确的时区，无需多边形测试。
- 点落在任何覆盖瓦片之外（边界、海岸线、稀疏区域）→ **返回空结果**。

对被覆盖的瓦片，结果是准确的。调用者需处理空结果情况。
最快的选项（约 470 ns / 约 9 MB），但不覆盖所有坐标。

### Finder {#finder}

使用拓扑简化数据集和 YStripes 索引进行完整多边形查询。
覆盖全球全部坐标（约 1 到 2 µs，约 66 MB）。

### DefaultFinder {#defaultfinder}

结合 FuzzyFinder 和 Finder：首先查询瓦片预索引。如果无结果返回，
则回退到完整多边形查询。对大多数内部区域查询提供预索引速度，
同时对所有坐标保持正确性（约 1 µs，约 75 MB）。**推荐用于大多数使用场景。**

### 数据版本 {#data-version}

时区边界数据的版本标识，例如 `"2025b"`。跟踪
[IANA 时区数据库](https://www.iana.org/time-zones)的发布，通过
[evansiroky/timezone-boundary-builder](https://github.com/evansiroky/timezone-boundary-builder)。
可通过 `data_version()` (Python)、`DataVersion()` (Go) 或 `data_version()` (Rust) 在运行时访问。

## 数据文件

### tzf-dist {#tzf-dist}

当前数据分发仓库（[`ringsaturn/tzf-dist`](https://github.com/ringsaturn/tzf-dist)），
于 2026 年春季推出。以 Go 模块和 Rust crate 形式分发处理后的二进制数据。
替代旧的 `tzf-rel` / `tzf-rel-lite` 仓库（计划弃用）。

### 数据文件 {#data-files}

`tzf-dist` 提供的三个二进制文件，均采用 `CompressedTopoTimezones` 格式：

| 文件 | 大小 | 用途 |
| --- | --- | --- |
| `combined-with-oceans.compress.topo.bin` | 约 17 MB | 完整精度数据 |
| `combined-with-oceans.topology.compress.topo.bin` | 约 5.4 MB | 拓扑简化（默认） |
| `combined-with-oceans.topology.preindex.bin` | 约 2 MB | FuzzyFinder 瓦片预索引 |

### tzf-rel / tzf-rel-lite（已弃用） {#tzf-rel}

先前的数据分发仓库，现已被 `tzf-dist` 取代。
仍可使用，但不再接收更新。

## 算法与索引

### 多边形简化 {#polygon-simplification}

使用 [Ramer-Douglas-Peucker (RDP)](https://en.wikipedia.org/wiki/Ramer%E2%80%93Douglas%E2%80%93Peucker_algorithm)
算法减少时区边界多边形中的点数。
将原始 protobuf 数据从内存中约 900 MB 缩减到磁盘上约 11 MB，精度损失可接受
（在距离边界约 1 公里以内的结果可能不正确）。

### 拓扑感知简化 {#topology-aware}

对逐多边形 RDP 的增强，修复共享边界处的间隙/重叠问题
（[tzf#183](https://github.com/ringsaturn/tzf/issues/183)）。

首先检测相邻多边形之间的共享边，仅简化一次，然后替换回
两个多边形，防止简化过程产生新的间隙或重叠。
在 tzf v1.1.0（2026 年春季）中引入。实现细节：
[`internal/topology/README.md`](https://github.com/ringsaturn/tzf/blob/v1.1.0/internal/topology/README.md)。

### 瓦片索引 {#tile-indexing}

`FuzzyFinder` 使用的预计算空间索引。将地球表面在固定缩放级别上
划分为四边形瓦片（受地图瓦片格式启发）。仅当瓦片完全被一个时区多边形
包含时才添加到索引中。边界瓦片会被有意排除。
对内部点实现无需多边形测试的 O(1) 预过滤。

### YStripes 索引 {#ystripes}

从 Josh Baker 的 [`tidwall/tg`](https://github.com/tidwall/tg) 移植的逐多边形空间索引。
将每个多边形的边划分为水平条带。对于给定的查询点，仅测试匹配条带中的边。
自 tzf v1.1.0 (Go) 和 tzf-rs v1.2.0 (Rust) 起默认启用。
在现代硬件上单次随机城市查询约 1 µs。
算法详情：[`POLYGON_INDEXING.md`](https://github.com/tidwall/tg/blob/main/docs/POLYGON_INDEXING.md)。

## 性能

### 内存用量 {#memory-usage}

Go 实现的近似数值（Rust 类似）：

| 模式 | 内存 |
| --- | --- |
| DefaultFinder（拓扑简化 + 预索引） | 约 75 MB |
| Finder（拓扑简化） | 约 66 MB |
| FullFinder（完整精度 + 预索引） | 约 422 MB |
| FullFinder（仅完整精度） | 约 413 MB |

Rust 启用 YStripes 索引后，相比无索引基线约增加 30 到 40 MB。
Rust 完整精度模式（启用 YStripes）约需 560 MB。
Python (tzfpy) 内部使用 Rust 二进制文件，默认模式约需 120 MB。

## 内部实现

### CGO vs PyO3 {#cgo-pyo3}

tzfpy 最初通过 CGO 调用 Go 实现，编译为 `.so` 文件。
自 v0.11.0 起改为使用 [PyO3](https://pyo3.rs/) 封装 tzf-rs (Rust)。
PyO3 无需在 FFI 边界手动管理对象生命周期，
消除了 CGO 导致的内存泄漏问题（[tzf#63](https://github.com/ringsaturn/tzf/pull/63)），
并为 CPU 密集型工作负载提供更好的吞吐量。
