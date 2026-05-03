---
date: "2025-07-21T14:20:56+09:00"
description: tzf 如何实现高性能时区查询——拓扑感知简化、共享边去重、Polyline 编码、瓦片索引、YStripes 和 1°×1° 格子索引。
draft: false
lastmod: "2026-05-03T00:00:00+09:00"
seo:
  description: tzf 如何实现快速时区查询：拓扑感知简化、共享边去重、Polyline 编码、瓦片索引、YStripes 索引和 1°×1° 格子索引。
  noindex: false
  title: 技术白皮书——Project tzf
summary: tzf 数据管线和空间索引策略背后的设计理念及实现细节。
title: 技术白皮书
toc: true
weight: 1
---

## 引言

最初，tzf 是为需要将坐标转换为时区的后端服务设计的，
主要用于地理和天气服务场景。

随着项目的发展，我们需要添加 Python 支持，因为当时 timezonefinder
在边界附近的查询速度无法满足我们的需求。

这便是 tzf (Go)、tzfpy (Python) 和 tzf-rs (Rust) 诞生的原因。

设计目标如下：

- 将坐标转换为时区名称。
- 性能优于完美精度。
- 至少支持 Go 和 Python。（Rust 是因 PyO3 生态而开发的。）
- 后端服务的最小化分发/二进制体积。

本白皮书将 tzf 的核心优化技术分为两类：

**离线数据管线**——将原始边界数据转换为紧凑、带预置索引的分发文件：

1. 拓扑感知简化（第一阶段）
2. 共享边去重（第二阶段）
3. Polyline 编码（第三阶段）

**运行时查询优化**——在查询时加速检索；瓦片索引和格子索引依赖管线在
构建期嵌入的辅助数据结构：

4. 瓦片索引（FuzzyFinder 预索引）
5. YStripes 空间索引
6. 1°×1° 格子索引

## 离线数据管线

原始时区边界数据以 Protocol Buffers 二进制（`Timezones` 格式）存在，约 96 MB。
两条并行的离线管线产生三个分发文件（文件名均带有 `combined-with-oceans.` 前缀）：

**完整精度管线**——仅去重 + 压缩，不做简化：

```
原始 .bin                    (96 MB,   Timezones)
  ↓ 共享边去重
.topo.bin                   (54.6 MB, TopoTimezones,              −43%)
  ↓ Polyline 增量编码
.compress.topo.bin          (17 MB,   CompressedTopoTimezones,    −82%)  ← 内嵌（完整版）
```

**精简管线**——拓扑感知简化 + 去重 + 压缩，含预索引分支：

```
原始 .bin                              (96 MB,   Timezones)
  ↓ 拓扑感知 D-P 简化
.topology.bin                          (12.5 MB, Timezones,              −87%)
  ├─→ preindextzpb → .topology.preindex.bin  (2.0 MB)  ← 内嵌（预索引）
  ↓ 共享边去重
.topology.topo.bin                     (10.0 MB, TopoTimezones,          −90%)
  ↓ Polyline 增量编码
.topology.compress.topo.bin            ( 5.4 MB, CompressedTopoTimezones,−94%)  ← 内嵌（精简版）
```

最终的分发文件为：

| 文件                                              | 格式                      | 大小      |
| ------------------------------------------------- | ------------------------- | --------- |
| `combined-with-oceans.compress.topo.bin`          | `CompressedTopoTimezones` | 约 17 MB  |
| `combined-with-oceans.topology.compress.topo.bin` | `CompressedTopoTimezones` | 约 5.4 MB |
| `combined-with-oceans.topology.preindex.bin`      | `PreindexTimezones`       | 约 2 MB   |

完整精度数据集从约 96 MB（原始 protobuf）缩减至约 17 MB——足够小巧，
使得 tzf-rs 可以将其作为可选的 Cargo feature 提供，而无需用户手动下载文件。

这些文件通过 [`ringsaturn/tzf-dist`](https://github.com/ringsaturn/tzf-dist) 分发。

### 第一阶段——拓扑感知简化

#### 背景：逐多边形方案及其局限

原始 GeoJSON 多边形数据首先被转换为使用 Protocol Buffers 的二进制编码。
其 schema 如下：

```proto
message Point {
  float lng = 1;
  float lat = 2;
}

message Polygon {
  repeated Point points = 1;
  repeated Polygon holes = 2;
}

message Timezone {
  repeated Polygon polygons = 1;
  string name = 2;
}

message Timezones {
  repeated Timezone timezones = 1;
}
```

即使经过这一转换，数据加载到内存中仍需要约 900 MB。
自然而然的下一步是应用
[Ramer–Douglas–Peucker (RDP) 算法][Ramer–Douglas–Peucker_algorithm]
来减少每个多边形中的点数：

[Ramer–Douglas–Peucker_algorithm]: https://en.wikipedia.org/wiki/Ramer–Douglas–Peucker_algorithm

![参数化 RDP 实现中变化 epsilon 的效果，[来源](https://en.wikipedia.org/wiki/File:RDP,_varying_epsilon.gif)](/img/history-of-tzf/RDP_varying_epsilon.gif)

对每个多边形独立应用 RDP 后，数据缩减至约 11 MB。
然而，这种简单方案存在根本性的正确性问题
（[tzf#183](https://github.com/ringsaturn/tzf/issues/183)）：相邻时区
多边形共享边，但每个多边形是独立进行简化的。由于 D-P
算法从共享边界两侧移除不同的中间点，两个多边形最终得到
略有不同的边形状——产生原始数据中不可见但在简化后出现的间隙和
重叠。`DefaultFinder` 的 ±0.02° 空间容差回退是对此问题的
临时变通方案，而非真正的修复。

#### 拓扑感知方案

修复方法是将 RDP 简化集成到拓扑感知的管线中，
该管线在所有相邻多边形上一致地处理共享边界。在
任何简化进行之前，先对所有多边形环构建拓扑图：

1. **标准化环绕方向**（外环逆时针，孔顺时针），使相邻环以相反方向
   遍历共享边界——这是使反向边匹配可靠的关键。
2. **移除零长度边**（部分环中存在重复的相邻顶点会破坏共享边检测）。
3. **对齐 T 形交汇顶点**：如果拓扑节点落在相邻边的内部，
   在分析开始前将其作为新顶点插入。
4. **通过规范键哈希检测共享边**。将每个线段分类：
   - _固定点_：三个或更多环交汇处的顶点。这些锚点不能移动。
   - _共享线段内部_：可以简化，但只简化一次——所有伙伴环
     复用同一简化结果。
   - _非共享_：独立简化（海岸线、独立边界）。
5. **飞地环**（形状等同于内部时区外环的孔）特殊处理：
   两个伙伴环均旋转至字典序最小顶点（规范起点）并进入共享
   简化缓存，保证输出一致而无需任何固定顶点。
6. **回退**：对于简化后点数少于 3 个唯一点、产生零长度边
   或（对于小环 ≤ 100 点）自交的环，回退使用原始的未修改输入环。

此拓扑感知方案于 2026 年春季完成。其实现详见
[`internal/topology/README.md`](https://github.com/ringsaturn/tzf/blob/v1.1.0/internal/topology/README.md)。

**结果**：减少 86% 的点数（8 M → 1.09 M 点），且共享边界拓扑一致——
无间隙，无意外重叠。

### 第二阶段——共享边去重

简化后，较长的共享边界段仍在文件中出现两次——
每个相邻时区环各一次。`deduplicatetzpb` 工具将
`Timezones` 二进制转换为 `TopoTimezones` 格式，每个共享
段只存储一次：

- 一个全局 `SharedEdge` 库按 ID 索引每个长共享边界段。
- 每个环变为一系列 `RingSegment` 条目：要么是较短的
  内联点序列（≤ 10 点），要么是对某个 `SharedEdge` ID 的正向/反向引用。

环绕方向标准化必须在去重之前运行，原因与
简化之前相同：只有当相邻环以相反方向遍历其共享
边界时，去重才能将它们识别为同一条边（而不是
归类为争议领土的同向重叠）。

**结果（简化后数据）**：额外约 20% 的体积缩减
（12.5 MB → 10.0 MB）。`TopoTimezones` 格式还可以干净地
往返转换回完整多边形，这使其成为下游工具的便利交换格式。

### 第三阶段——Polyline 编码

最后一个离线阶段应用 Google Maps 的 Encoded Polyline 算法来
压缩存储在 `TopoTimezones` 中的坐标序列。地理上
连续的点具有较小的增量，因此增量 + zig-zag 编码在
经过简化和去重的数据上实现了约 45% 的额外压缩。

共享边点序列和内联段点均进行增量编码；
边 ID 引用（int32 正向/反向引用）保持不变。

**结果**：10.0 MB → 5.4 MB（`CompressedTopoTimezones`），
从原始 96 MB 数据源累计减少 94%。

## 运行时查询优化

### 瓦片索引

朴素的 Ray Casting 算法时间复杂度为 O(n²)，不适合
高并发后端服务。我们考虑了空间 R-tree，但考虑到全球时区
数量较少且面积分布不均，发现性能提升微乎其微。

因此，我们采用了受气象数据服务中地图瓦片格式启发的
瓦片索引方案。每个瓦片在给定缩放级别上定义一个四边形区域：

```txt
┌───────────┬───────────┬───────────┐
│           │           │           │
│           │           │           │
│ x-1,y-1,z │ x+0,y-1,z │ x+1,y-1,z │
│           │           │           │
│           │           │           │
├───────────┼───────────┼───────────┤
│           │           │           │
│           │           │           │
│ x-1,y+0,z │ x+0,y+0,z │ x+1,y+0,z │
│           │           │           │
│           │           │           │
├───────────┼───────────┼───────────┤
│           │           │           │
│           │           │           │
│ x-1,y+1,z │ x+0,y+1,z │ x+1,y+1,z │
│           │           │           │
│           │           │           │
└───────────┴───────────┴───────────┘
```

这种类四叉树布局确保父瓦片恰好包含四个子瓦片，
可以实现无间隙聚合：

![基于瓦片的时区索引演示。可通过 [tzf-web][tile_index_live_view] 查看带多边形的实时索引演示](/img/preindex-timezone-preview-berlin.webp)

[tile_index_live_view]: https://ringsaturn.github.io/tzf-web/?markers=%5B%7B%22lat%22%3A52.2076%2C%22lng%22%3A9.668%7D%5D&lat=50.310392&lng=11.887207&zoom=6&showIndex=true

每个时区独立处理。对于每个时区：

1. 在索引缩放级别（缩放级别 13）生成触及该多边形的所有瓦片。
2. 仅保留**完全位于**多边形内部的瓦片（`EnsureInside`）。
3. 删除边界瓦片——即 8 个相邻瓦片中有任何一个不在瓦片集中
   的瓦片。此步骤执行两次（`dropEdgeLayer = 2`），从内部边界
   剥离两层，使靠近多边形边缘的瓦片被排除。
4. 通过 `MergeUp` 将剩余瓦片向上合并到聚合缩放级别（缩放级别 3），
   然后对合并结果再次执行 `EnsureInside`。

由于每个时区是独立索引的，一个同时位于**多个**时区内部的瓦片
会出现在所有相关时区的索引条目中。内存中的存储结构为
`map[Tile][]string`，因此一个瓦片可以返回多个时区名称。这处理了
Asia/Shanghai 和 Asia/Urumqi 等共享区域的情况，它们重叠的内部区域
会在两个时区的预索引条目中生成匹配的瓦片。

查询时，从最粗的缩放级别（3）到最细的（13）依次查找，
返回第一个匹配瓦片的所有时区名称：

- 如果找到匹配瓦片 → 返回其时区列表（无歧义的内部瓦片返回一个，
  共享区域瓦片返回多个）。
- 如果没有瓦片匹配（边界区域、海岸线、稀疏区域）→ 预索引返回
  空结果。

`FuzzyFinder` 仅使用此预索引。`GetTimezoneNames` 返回完整列表；
`GetTimezoneName` 返回第一个条目。对于未覆盖区域，返回错误
而非猜测——调用者负责处理空结果情况。

`DefaultFinder` 自动处理此问题：首先尝试瓦片预索引；如果无结果返回，
则回退到通过 `Finder` 进行完整多边形查询。这使其对所有坐标正确，
同时为大多数世界城市查询保持预索引的速度。

瓦片预索引在离线阶段构建为独立的 `.topology.preindex.bin` 文件，
与精简压缩二进制一同加载。

### YStripes 索引

自 tzf v1.1.0 (Go) 和 tzf-rs v1.2.0 (Rust) 起，多边形级的点在多边形内
测试使用 YStripes 空间索引，该索引移植自 Josh Baker 的
[`tidwall/tg`](https://github.com/tidwall/tg) 项目。

YStripes 通过预分区每个多边形的边为水平条带来改进朴素的射线投射。
对于查询点，仅测试相关条带中的边，
大幅减少每个多边形的工作量，且没有完整空间树的开销。

默认启用；禁用（例如在内存受限的环境中）
可通过 Rust 的 `FinderOptions` 实现。使用 YStripes 后，配合 `DefaultFinder`
在现代硬件上单次随机城市查询持续低于 1 µs。

算法详情请参见作者在
[`POLYGON_INDEXING.md`](https://github.com/tidwall/tg/blob/main/docs/POLYGON_INDEXING.md) 中的解释。

### 1°×1° 格子索引

自 tzf v1.2.0 / tzf-rs v1.3.3 起，`CompressedTopoTimezones` 二进制在压缩阶段末尾自动
内嵌一个 1°×1° 格子索引。全球被划分为 360 × 180 = 64,800 个格子，
每个格子存储包围盒与其相交的时区下标升序列表。只有含至少一个时区的
格子才会写入（全球约 65,000–65,500 个），令分发文件增大约 870 KB。

查询时，`Finder` 通过 O(1) map 查找将 PIP 候选数从 ~444 个时区缩减至
通常 1–3 个。当某格子只有一个候选且查询点远离日期变更线与极点时，
PIP 测试本身也可跳过。不含格子索引的旧数据文件会透明地回退到原有的
全量线性扫描，API 对调用方无变化。

设计灵感来源于 [`twitchax/rtz`](https://github.com/twitchax/rtz)。

**性能（Apple M3 Max，2026 年 5 月）：**

| 场景                                     | 引入前  | 引入后  | 提升     |
| ---------------------------------------- | ------- | ------- | -------- |
| 边界查询（lite finder）                  | 2108 ns | 1060 ns | **2.0×** |
| 随机世界城市（lite finder）              | 1742 ns | 452 ns  | **3.9×** |
| 边界查询（full finder，无 preindex）     | 2057 ns | 1019 ns | **2.0×** |
| 随机世界城市（full finder，无 preindex） | 1955 ns | 606 ns  | **3.2×** |
