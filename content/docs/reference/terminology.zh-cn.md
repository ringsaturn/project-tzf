---
date: '2025-07-21T21:09:40+09:00'
description: tzf 生态系统中项目特定术语和概念的参考。
draft: false
lastmod: '2026-09-11T00:00:00+09:00'
seo:
  description: tzf 特定术语参考：查找器、.tzb 与 .tzm 文件格式、FUZZY 预索引、E 与 M profile、原地与展开加载、多边形简化、瓦片索引及 YStripes。
  noindex: false
  title: '术语表 - Project tzf'
summary: tzf 的查找器、文件格式、算法及性能参考。
title: 术语表
toc: true
weight: 4
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

## 查找器

v2 通过返回接口的构造函数提供查找器。v1 的 `Finder` / `FuzzyFinder` / `DefaultFinder` 类见 [v1 术语](#v1-terms)。

### 默认查找器 {#defaultfinder}

Go 为 `NewDefaultFinder()`，Rust 为 `DefaultFinder::new()`。读取 lite 数据集，以 FUZZY 预索引作为快速路径，其后是多边形几何数据。在 Go 中，多边形存储原地引用 `.tzm` 内存镜像：~12 MB 堆加上 ~10 MB 只读数据，在 Apple M3 Max 上针对 `2026c` 数据集每次查询 298 ns。在 Rust 中，同一构造函数把 `lite.tzb` 展开为多边形，峰值 RSS 约 46 MiB，查询 236 ns。

### 嵌入式查找器 {#embeddedfinder}

Go 为 `NewEmbeddedFinder()`，Rust 为 `EmbeddedFinder::new()`。原地查询 lite `.tzb`，除文件字节外堆占用不足 1 KB。预索引未覆盖该点时，查询延迟为微秒级。适用于嵌入式目标、内存受限的进程和无文件系统的部署。

### 完整精度查找器 {#fullfinder}

Go 为 `NewFullFinder()`，Rust 为 `DefaultFinder::new_full()`。读取展开到内存中的完整精度数据集：Go 中常驻约 145 MB。结果与未简化的边界数据一致。

### 数据版本 {#data-version}

时区边界数据的版本标识，例如 `"2026c"`。跟踪
[IANA 时区数据库](https://www.iana.org/time-zones)的发布，通过
[evansiroky/timezone-boundary-builder](https://github.com/evansiroky/timezone-boundary-builder)。
可通过 `data_version()` (Python)、`DataVersion()` (Go) 或 `data_version()` (Rust) 在运行时访问。tzf-dist 的三个产物携带相同的值。

## 数据格式

### `.tzb` {#tzb}

E profile 的 TZF 嵌入式二进制文件：紧凑的传输格式，几何数据以分块的 zigzag-LEB128 varint 流存储。所有实现都读取该格式。参见[嵌入式二进制格式]({{< relref "embedded-binary-format" >}})。

### `.tzm` {#tzm}

M profile 的 TZF 嵌入式二进制文件：同一份数据，几何数据以一个扁平的 `(int32, int32)` 对数组存储，文件布局与查询时的结构一致。由 Go 实现读取；tzf-rs 对此类文件返回 `Error::Profile`。由使用它的主机通过 tzf 的 `cmd/tzb2tzm` 生成。

### Profile E / Profile M {#profiles}

偏移 48 处的文件头字节决定 TZF 嵌入式二进制文件的布局：`0` 为 E（embedded，`.tzb`），`1` 为 M（memory image，`.tzm`）。必需区段按 profile 区分，跨 profile 的区段类型会被拒绝。

### FUZZY 区段 {#fuzzy}

区段类型 10，瓦片预索引，存储为一个有序的打包瓦片 ID 数组及其时区索引。tzf-dist 的三个产物都包含该区段。它是单名称查询的快速路径；多结果 API 不查询它。在 `2026c` 数据集上包含 87,572 个瓦片，其中 156 个命名两个时区，约 880 KB。

### 原地加载与展开加载 {#in-place-expanded}

**原地：** 查找器按每次查询的需要，从文件字节中读取几何数据。打开时不解码，堆占用极小，预索引未命中时查询为微秒级。对应 Go 的 `NewEmbeddedFinder`、`x.NewFinderFromTZBReaderAt` 和 Rust 的 `EmbeddedFinder`。

**原地引用：** M profile 按查询时的布局存储点，因此环存储直接指向映射的字节，不解码也不复制。源字节必须保持存活且不被修改。对应 Go 的 `NewFinderFromTZM`。

**展开：** 打开时把文件解码为多边形对象。打开开销和常驻内存较高，查询为纳秒级。对应 Go 的 `NewFinderFromTZB`、`NewFullFinder` 和 Rust 的 `DefaultFinder`。

## 数据文件

### tzf-dist {#tzf-dist}

当前数据分发仓库（[`ringsaturn/tzf-dist`](https://github.com/ringsaturn/tzf-dist)），
于 2026 年春季推出。以 Go 模块和 Rust crate 形式分发处理后的二进制数据。
替代 `tzf-rel` / `tzf-rel-lite` 仓库。

### 数据文件 {#data-files}

`tzf-dist` 提供的三个文件，均采用
[TZF 嵌入式二进制格式]({{< relref "embedded-binary-format" >}}) 1.1，
都带有 FUZZY 区段并携带相同的 `data_version`：

| 文件 | Profile | 大小 | 用途 |
| --- | --- | --- | --- |
| `lite.tzb` | E | 约 4 MB | 拓扑简化数据；crates.io 与 PyPI 分发的内容 |
| `lite.tzm` | M | 约 10 MB | 同一份数据的内存镜像，由 Go `NewDefaultFinder` 读取 |
| `full.tzb` | E | 约 14 MB | 完整精度数据；在 Rust crate 中仅由 git 提供 |

`full.tzm` 不做发布：把完整数据集按 M 布局展开约为 67 MB。

### tzf-rel / tzf-rel-lite（已停止） {#tzf-rel}

先前的数据分发仓库，已被 `tzf-dist` 取代。其中的 protobuf 产物不再发布。

### v1 术语 {#v1-terms}

以下术语适用于 v1 系列（tzf v1.2.x、tzf-rs 1.3.x、tzfpy 1.3.x），该系列冻结在最后一个 protobuf 数据版本上：

| 术语 | 在 v1 中的含义 | v2 中的对应物 |
| --- | --- | --- |
| `FuzzyFinder` | 仅使用瓦片预索引的查找器，覆盖瓦片之外返回空结果 | 已移除；预索引是每个查找器内部的快速路径 |
| `Finder` | 仅使用多边形的查找器 | 默认查找器；多结果 API 仍走多边形精确路径 |
| `DefaultFinder` | 预索引加多边形回退 | 默认查找器，作用相同 |
| `CompressedTopoTimezones` | 承载去重并经 polyline 编码几何数据的 protobuf 消息 | `.tzb` / `.tzm` |
| `PreindexTimezones` | 承载瓦片预索引的 protobuf 消息 | FUZZY 区段 |

## 算法与索引

### 多边形简化 {#polygon-simplification}

使用 [Ramer-Douglas-Peucker (RDP)](https://en.wikipedia.org/wiki/Ramer%E2%80%93Douglas%E2%80%93Peucker_algorithm)
算法减少时区边界多边形中的点数。v2 的 lite 数据集使用 0.001 度的 epsilon，
边界位移上限为 111.2 m，认证结果见
[BORDER_CHANGE.md](https://github.com/ringsaturn/tzf/blob/main/BORDER_CHANGE.md)。

### 拓扑感知简化 {#topology-aware}

对逐多边形 RDP 的增强，修复共享边界处的间隙/重叠问题
（[tzf#183](https://github.com/ringsaturn/tzf/issues/183)）。

首先检测相邻多边形之间的共享边，仅简化一次，然后替换回
两个多边形，防止简化过程产生新的间隙或重叠。
在 tzf v1.1.0（2026 年春季）中引入。实现细节：
[`internal/topology/README.md`](https://github.com/ringsaturn/tzf/blob/v1.1.0/internal/topology/README.md)。

### 瓦片索引 {#tile-indexing}

预计算的空间索引，在 v2 中存储为 [FUZZY 区段](#fuzzy)。参照地图瓦片格式，
将地球表面在固定缩放级别上划分为四边形瓦片。仅当某个时区多边形完全包含
该瓦片时，它才进入索引，边界瓦片被排除在外。内部点因此可以通过瓦片查找
解析，无需做多边形判定。

### YStripes 索引 {#ystripes}

从 Josh Baker 的 [`tidwall/tg`](https://github.com/tidwall/tg) 移植的逐多边形空间索引。
将每个多边形的边划分为水平条带。对于给定的查询点，仅测试匹配条带中的边。
自 tzf v1.1.0 (Go) 和 tzf-rs v1.2.0 (Rust) 起默认启用；v2 中始终启用，
`.tzm` 加载器在打开时并行重建该索引。嵌入式二进制格式的区段类型 14
为该索引保留了一种序列化形式，当前不输出。
算法详情：[`POLYGON_INDEXING.md`](https://github.com/tidwall/tg/blob/main/docs/POLYGON_INDEXING.md)。

## 内部实现

### CGO vs PyO3 {#cgo-pyo3}

tzfpy 最初通过 CGO 调用 Go 实现，编译为 `.so` 文件。
自 v0.11.0 起改为使用 [PyO3](https://pyo3.rs/) 封装 tzf-rs (Rust)。
PyO3 无需在 FFI 边界手动管理对象生命周期，
消除了 CGO 导致的内存泄漏问题（[tzf#63](https://github.com/ringsaturn/tzf/pull/63)），
并为 CPU 密集型工作负载提供更好的吞吐量。
