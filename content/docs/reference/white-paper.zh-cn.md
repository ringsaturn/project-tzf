---
date: '2025-07-21T14:20:56+09:00'
description: tzf 的高性能时区查询实现，包括拓扑感知简化、共享边去重、Polyline 编码、瓦片索引、YStripes 和 1°×1° 格子索引。
draft: false
lastmod: '2026-09-14T00:00:00+09:00'
seo:
  description: tzf 快速时区查询的实现方式：拓扑感知简化、共享边去重、Polyline 编码、瓦片索引、YStripes 索引和 1°×1° 格子索引。
  noindex: false
  title: '技术白皮书 - Project tzf'
summary: tzf 数据管线和空间索引策略的设计理念与实现细节。
title: 技术白皮书
toc: true
weight: 1
---

## 引言

tzf 最初面向需要将坐标转换为时区的后端服务，
主要用于地理服务和天气服务场景。

随着项目发展，我们需要增加 Python 支持。当时 timezonefinder
在边界附近的查询速度无法满足项目需求。

因此，项目陆续形成了 tzf (Go)、tzfpy (Python) 和 tzf-rs (Rust)。

设计目标如下：

- 将坐标转换为时区名称。
- 优先保证性能，同时提供完整精度模式。
- 至少支持 Go 和 Python。（Rust 是因 PyO3 生态而开发的。）
- 面向后端服务控制分发文件和二进制体积。

本白皮书将 tzf 的核心优化技术分为两类：

下文的管线各阶段体积数据在 protobuf 时期的构建上测得。v2 移除了 protobuf：
管线现在使用字段与已停用 schema 对应的原生 Go 结构体，中间产物用 `encoding/gob`
序列化，最后一个阶段输出
[TZF 嵌入式二进制格式]({{< relref "embedded-binary-format" >}})，
不再输出 protobuf 产物。各阶段本身没有变化，从原始 GeoJSON 重新构建可以得到
逐字节相同的 `full.tzb`。

**离线数据管线**：将原始边界数据转换为紧凑、带预置索引的分发文件：

1. 拓扑感知简化（第一阶段）
2. 共享边去重（第二阶段）
3. Polyline 编码（第三阶段）

**运行时查询优化**：在查询时加速检索。瓦片索引和格子索引依赖管线在
构建期嵌入的辅助数据结构：

4. 瓦片索引（FUZZY 预索引）
5. 1°×1° 格子索引
6. YStripes 空间索引

## 离线数据管线

原始时区边界数据在扁平的 `Timezones` 表示下约 96 MB。两条并行的离线管线分别产生
lite 和完整精度数据集。下文的中间文件名均带有 `combined-with-oceans.` 前缀，
体积数据来自 protobuf 时期的构建：

**完整精度管线**：仅去重 + 压缩，不做简化：

```
原始 .bin                    (96 MB,   Timezones)
  ↓ 共享边去重
.topo.bin                   (54.6 MB, TopoTimezones,              −43%)
  ↓ Polyline 增量编码
.compress.topo.bin          (17 MB,   CompressedTopoTimezones,    −82%)  ← 内嵌（完整版）
```

**精简管线**：拓扑感知简化 + 去重 + 压缩，含预索引分支：

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

在 v2 中，去重并简化后的几何数据与瓦片预索引被编码进每个数据集各自的单个容器，
预索引存储为 FUZZY 区段，不再是独立文件：

| 文件 | Profile | 体积 | 内容 |
| --- | --- | ---: | --- |
| `lite.tzb` | E | 约 4 MB | 拓扑简化的几何数据、GRID、FUZZY |
| `lite.tzm` | M | 约 10 MB | 同一份数据，几何数据按查询时的布局存储 |
| `full.tzb` | E | 约 15 MB | 完整精度几何数据、GRID、FUZZY |

完整精度数据集从原始表示下的约 96 MB 缩减至 13.77 MB（256 点 chunk；`v0.0.2026-c-tzb2` 起的 64 点 chunk 为 15.26 MB），该体积在 tzf-rs 可以作为
可选 Cargo feature 携带的范围内，无需用户手动下载文件。

这些文件通过 [`ringsaturn/tzf-dist`](https://github.com/ringsaturn/tzf-dist) 分发。
容器布局的说明见[嵌入式二进制格式]({{< relref "embedded-binary-format" >}})。

### 第一阶段 - 拓扑感知简化

#### 背景：逐多边形方案及其局限

原始 GeoJSON 多边形数据首先被转换为二进制编码。下面的 schema 是已停用的 protobuf
定义，v2 管线使用字段相同的原生 Go 结构体：

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
下一步是应用
[Ramer-Douglas-Peucker (RDP) 算法][Ramer-Douglas-Peucker_algorithm]
来减少每个多边形中的点数：

[Ramer-Douglas-Peucker_algorithm]: https://en.wikipedia.org/wiki/Ramer%E2%80%93Douglas%E2%80%93Peucker_algorithm

![参数化 RDP 实现中变化 epsilon 的效果，[来源](https://en.wikipedia.org/wiki/File:RDP,_varying_epsilon.gif)](/img/history-of-tzf/RDP_varying_epsilon.gif)

对每个多边形独立应用 RDP 后，数据缩减至约 11 MB。
然而这种简单方案存在根本性的正确性问题
（[tzf#183](https://github.com/ringsaturn/tzf/issues/183)）：相邻时区
多边形共享边，但每个多边形是独立进行简化的。由于 D-P
算法从共享边界两侧移除不同的中间点，两个多边形最终得到
略有不同的边界形状，导致原始数据中不可见但在简化后出现的间隙和
重叠。`DefaultFinder` 的 ±0.02° 空间容差回退是对此问题的
临时变通方案，并不能从数据层面修复问题。

#### 拓扑感知方案

修复方法是将 RDP 简化集成到拓扑感知的管线中，
该管线会在所有相邻多边形上一致处理共享边界。
在执行任何简化之前，先对所有多边形环构建拓扑图：

1. **标准化环绕方向**（外环逆时针，孔顺时针），使相邻环以相反方向
   遍历共享边界，这是反向边匹配可靠的关键。
2. **移除零长度边**（部分环中存在重复的相邻顶点会破坏共享边检测）。
3. **对齐 T 形交汇顶点**：如果拓扑节点落在相邻边的内部，
   在分析开始前将其作为新顶点插入。
4. **通过规范键哈希检测共享边**。将每个线段分类：
   - _固定点_：三个或更多环交汇处的顶点。这些锚点不能移动。
   - _共享线段内部_：可以简化，但只简化一次，所有伙伴环
     复用同一简化结果。
   - _非共享_：独立简化（海岸线、独立边界）。
5. **飞地环**（形状等同于内部时区外环的孔）特殊处理：
   两个伙伴环均旋转至字典序最小顶点（规范起点）并进入共享
   简化缓存，在没有固定顶点的情况下仍保证输出一致。
6. **回退**：对于简化后点数少于 3 个唯一点、产生零长度边
   或（对于小环 ≤ 100 点）自交的环，回退使用原始的未修改输入环。

此拓扑感知方案于 2026 年春季完成。其实现详见
[`internal/topology/README.md`](https://github.com/ringsaturn/tzf/blob/v1.1.0/internal/topology/README.md)。

**结果**：点数减少 86%（8 M → 1.09 M 点），共享边界保持拓扑一致，
无间隙，无意外重叠。

### 第二阶段 - 共享边去重

简化后，较长的共享边界段仍会在文件中出现两次，
每个相邻时区环各一次。`deduplicatetzpb` 工具将
`Timezones` 二进制转换为 `TopoTimezones` 格式，每个共享
段只存储一次：

- 一个全局 `SharedEdge` 库按 ID 索引每个长共享边界段。
- 每个环变为一系列 `RingSegment` 条目：要么是较短的
  内联点序列（≤ 10 点），要么是对某个 `SharedEdge` ID 的正向/反向引用。

环绕方向标准化必须在去重之前运行，原因与
简化之前相同：只有当相邻环以相反方向遍历其共享
边界时，去重才能将它们识别为同一条边。否则会被
归类为争议领土的同向重叠。

**结果（简化后数据）**：额外约 20% 的体积缩减
（12.5 MB → 10.0 MB）。`TopoTimezones` 格式还可以干净地
往返转换回完整多边形，这使其成为下游工具的便利交换格式。

### 第三阶段 - Polyline 编码

最后一个离线阶段应用 Google Maps 的 Encoded Polyline 算法来
压缩存储在 `TopoTimezones` 中的坐标序列。地理上
连续的点具有较小的增量，因此增量 + zig-zag 编码在
经过简化和去重的数据上实现了约 45% 的额外压缩。

共享边点序列和内联段点均进行增量编码。
边 ID 引用（int32 正向/反向引用）保持不变。

**结果**：10.0 MB → 5.4 MB（`CompressedTopoTimezones`），
从原始 96 MB 数据源累计减少 94%。

## 运行时查询优化

### 瓦片索引

原始的 Ray Casting 算法时间复杂度为 O(n²)，不适合
高并发后端服务。项目曾评估空间 R-tree，但全球时区
数量较少且面积分布不均，实际性能收益很有限。

因此，tzf 采用了受气象数据服务中地图瓦片格式启发的
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
3. 删除边界瓦片，即 8 个相邻瓦片中有任何一个不在瓦片集中
   的瓦片。此步骤执行两次（`dropEdgeLayer = 2`），从内部边界
   剥离两层，使靠近多边形边缘的瓦片被排除。
4. 通过 `MergeUp` 将剩余瓦片向上合并到聚合缩放级别（缩放级别 3），
   然后对合并结果再次执行 `EnsureInside`。

由于每个时区是独立索引的，一个同时位于**多个**时区内部的瓦片
会出现在所有相关时区的索引条目中。内存中的存储结构为
`map[Tile][]string`，因此一个瓦片可以返回多个时区名称。这处理了
Asia/Shanghai 和 Asia/Urumqi 等共享区域的情况，它们重叠的内部区域
会在两个时区的预索引条目中生成匹配的瓦片。

查询时，从最粗的缩放级别（3）到最细的缩放级别（13）依次查找，
并返回第一个匹配瓦片的全部时区名称：

- 如果找到匹配瓦片 → 返回其时区列表（无歧义的内部瓦片返回一个，
  共享区域瓦片返回多个）。
- 如果没有瓦片匹配（边界区域、海岸线、稀疏区域）→ 预索引返回
  空结果。

在 v1 中，该预索引由独立的 `FuzzyFinder` 使用，未覆盖区域返回空结果，
空结果交由调用方处理。v2 移除了这个类。预索引现在是每个数据文件带有 FUZZY 区段的
查找器内部的快速路径：覆盖该点的瓦片会立即回答 `GetTimezoneName`，未被覆盖的点
在同一个查找器内回退到多边形查询。`GetTimezoneNames` 在任何查找器中都不查询预索引。

预索引在离线阶段构建，并存储为嵌入式二进制文件的区段类型 10，不再是独立产物。
在 `2026c` 数据集上，它包含 87,572 个瓦片，其中 156 个命名两个时区，约 880 KB。

### 1°×1° 格子索引

自 tzf v1.2.0 / tzf-rs v1.3.3 起，分发的二进制会在压缩阶段末尾自动内嵌一个
1°×1° 格子索引；在 v2 中它是嵌入式二进制文件的区段类型 8。全球被划分为
360 × 180 = 64,800 个格子，
每个格子存储包围盒与其相交的时区下标升序列表。只有含至少一个时区的
格子才会写入（全球约 65,000 到 65,500 个），分发文件会因此增大约 870 KB。

查询时，`Finder` 通过 O(1) map 查找将 PIP 候选数从 ~444 个时区缩减至
通常 1 到 3 个。当某格子只有一个候选且查询点远离日期变更线与极点时，
PIP 测试本身也可跳过。不含格子索引的旧数据文件会透明地回退到原有的
全量线性扫描，API 对调用方无变化。

设计灵感来源于 [`twitchax/rtz`](https://github.com/twitchax/rtz)。

### YStripes 索引

自 tzf v1.1.0 (Go) 和 tzf-rs v1.2.0 (Rust) 起，多边形级的点在多边形内
测试使用 YStripes 空间索引，该索引移植自 Josh Baker 的
[`tidwall/tg`](https://github.com/tidwall/tg) 项目。

YStripes 预先把每个多边形的边划分为水平条带，从而减少射线投射的工作量。
对于查询点，仅测试相关条带中的边，不需要完整空间树的开销。

v1 允许通过 Rust 的 `FinderOptions` 关闭它；v2 移除了该选项，索引始终构建。
`.tzm` 加载器在打开时并行重建该索引，在 lite 数据集上 16 核约需 5 ms，
单核约需 28 ms。嵌入式二进制格式的区段类型 14 为该索引保留了一种序列化形式，
当前不输出。

算法详情请参见作者在
[`POLYGON_INDEXING.md`](https://github.com/tidwall/tg/blob/main/docs/POLYGON_INDEXING.md) 中的解释。
