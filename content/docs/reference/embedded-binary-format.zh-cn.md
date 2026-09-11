---
date: '2026-09-10T00:00:00+09:00'
description: TZF 嵌入式二进制格式参考：.tzb 与 .tzm 文件的布局、profile、区段类型及查询语义。
draft: false
lastmod: '2026-09-11T00:00:00+09:00'
seo:
  description: TZF 嵌入式二进制格式：文件头、区段表、CRC 校验尾、E 与 M 两种 profile、区段类型 1 到 14，以及复现 tzf 查询结果所需的规则。
  noindex: false
  title: '嵌入式二进制格式 - Project tzf'
summary: .tzb 与 .tzm 文件的磁盘布局，以及安全读取并复现 tzf 查询结果所需的规则。
title: 嵌入式二进制格式
toc: true
weight: 2
---

本文是 TZF 嵌入式二进制格式的简要参考。`.tzb` 与 `.tzm` 文件把边界数据从 [`ringsaturn/tzf-dist`](https://github.com/ringsaturn/tzf-dist) 带入每个 v2 实现。本文描述其磁盘布局，以及安全读取文件并复现 tzf 时区查询结果所需的规则。

该格式在 v2 中取代了 protobuf，支持原地查询：目录项为定长记录，几何数据在每一层都带有包围盒，读取方只需读取该查询所需的字节即可作答。

本页是该格式的公开参考。参考实现是 [tzf 仓库](https://github.com/ringsaturn/tzf)中的 `internal/embedbin`。

## 1. 约定

- Magic：`TZFB`
- 格式版本：`1.1`（`format_major` 为 1，`format_minor` 为 1）
- 字节序：所有定宽整数均为小端
- 坐标：有符号 `int32`，为度数乘以 `100000`
- 坐标顺序：先经度，后纬度
- 包围盒顺序：`min_lng, min_lat, max_lng, max_lat`
- 点流中的有符号值：先 zigzag 编码，再做无符号 LEB128 编码
- LEB128 值：最小编码，最多 5 字节
- 区段偏移与定宽记录：按 4 字节对齐
- 文件大小上限：小于 4 GiB

存储的坐标与包围盒必须落在以下范围内：

```
longitude: -18000000..18000000
latitude:   -9000000..9000000
```

## 2. Profile

格式 1.1 把文件头中第一个保留字节（偏移 48）指定为 `profile`。两种 profile 共用同一容器：

| Profile | 取值 | 扩展名 | 结构 |
| --- | ---: | --- | --- |
| E（embedded） | 0 | `.tzb` | 分块 varint 几何数据，用于传输 |
| M（memory image） | 1 | `.tzm` | 扁平的 `(i32, i32)` 点数组，按查询时的结构排布 |

1.1 之前写出的文件在该偏移处均为 0，因此所有格式 1.0 文件都可视为合法的 E profile 文件。读取方必须拒绝未知的 profile 取值。

必需区段按 profile 区分：

| Profile | 必需 | 可选 |
| --- | --- | --- |
| E | NAMES、TZDIR、POLYDIR、RINGDIR、RINGOPS、GROUPDIR、CHUNKDIR、POINTS | GRID、FUZZY |
| M | NAMES、TZDIR、POLYDIR、FLATRINGDIR、FLATPOINTS | GRID、FUZZY、YSTRIPES |

跨 profile 的区段类型会被拒绝。NAMES、TZDIR、POLYDIR、GRID 和 FUZZY 在两种 profile 下逐字节相同，因此 `.tzb` → `.tzm` 转码可以直接原样复制这些区段。

M profile 由使用它的主机通过 tzf 的 `cmd/tzb2tzm` 生成，输出与从源数据直接编码 M profile 的结果逐字节相同。M profile 目前只有 Go 实现读取，tzf-rs 对此类文件返回 `Error::Profile`。

## 3. 顶层布局

```
Header                 64 bytes
Section table          section_count * 16 bytes
NAMES                  type 1
TZDIR                  type 2
POLYDIR                type 3
RINGDIR                type 4     E profile
RINGOPS                type 5     E profile
GROUPDIR               type 6     E profile
CHUNKDIR               type 7     E profile
GRID                   type 8     optional
FUZZY                  type 10    optional
FLATPOINTS             type 12    M profile
FLATRINGDIR            type 13    M profile
YSTRIPES               type 14    M profile, optional, not emitted today
POINTS                 type 9     E profile, last
CRC32 footer           4 bytes
```

写入方按上述顺序输出区段，几何数据放在最后。读取方通过区段表定位区段并跳过未知类型，格式 1.0 的读取方就是这样忽略 FUZZY 区段的。

区段类型 11（`META`）已分配但保留未用。

### 3.1 文件头

| 偏移 | 长度 | 字段 | 含义 |
| ---: | ---: | --- | --- |
| 0 | 4 | `magic` | ASCII `TZFB` |
| 4 | 1 | `format_major` | `1` |
| 5 | 1 | `format_minor` | `1` |
| 6 | 2 | `header_size` | `64` |
| 8 | 4 | `flags` | 见下 |
| 12 | 4 | `coord_scale` | `100000` |
| 16 | 4 | `file_size` | 含校验尾的总大小 |
| 20 | 4 | `section_count` | 区段表条目数 |
| 24 | 16 | `data_version` | NUL 填充的 UTF-8，例如 `2026c` |
| 40 | 4 | `tz_count` | 时区条目数 |
| 44 | 4 | `chunk_target` | 每个 chunk 的目标点数，仅供参考 |
| 48 | 1 | `profile` | `0` 为 E，`1` 为 M |
| 49 | 15 | 保留 | 写入方填零 |

标志位：

| 位 | 名称 | 含义 |
| ---: | --- | --- |
| 0 | `GRID_PRESENT` | 存在 `GRID` 区段 |
| 1 | `NO_SHORTCUT` | 禁用单候选查询快捷路径 |
| 2..31 | 保留 | 写入方填零 |

### 3.2 区段表

区段表紧接文件头。每个条目 16 字节：

| 偏移 | 长度 | 字段 |
| ---: | ---: | --- |
| 0 | 4 | `type` |
| 4 | 4 | `offset`，自文件起始计 |
| 8 | 4 | `length`，字节数 |
| 12 | 4 | 保留 |

已知区段类型必须唯一。区段必须落在文件范围内，且不得与文件头、区段表、校验尾或其他区段重叠。

### 3.3 校验尾

最后 4 字节为字节区间 `[0, file_size - 4)` 上的 IEEE CRC32。文件在首次查询前必须校验。设备可以在把文件写入可信存储时执行一次该校验。

## 4. 公共区段

目录索引从零开始。`first` 与 `count` 组成的一对值始终选取被引用区段中的一段连续区间。

### 4.1 NAMES，类型 1

```
u32 blob_len
u32 offsets[tz_count + 1]
u8  blob[blob_len]
```

第 `i` 个时区名称为 `blob[offsets[i] : offsets[i + 1]]`。名称为非空、不含 NUL 字节的 UTF-8 字符串；offsets 非递减，`offsets[0]` 为零，`offsets[tz_count]` 等于 `blob_len`。时区索引在 NAMES、TZDIR、GRID 和 FUZZY 中含义一致。

### 4.2 TZDIR，类型 2

`tz_count` 条记录，每条 24 字节：

| 偏移 | 长度 | 字段 |
| ---: | ---: | --- |
| 0 | 4 | `poly_first`，指向 POLYDIR 的索引 |
| 4 | 2 | `poly_count` |
| 6 | 2 | 保留 |
| 8 | 16 | 时区包围盒，四个 `i32` 值 |

### 4.3 POLYDIR，类型 3

24 字节记录：

| 偏移 | 长度 | 字段 |
| ---: | ---: | --- |
| 0 | 4 | `ring_first`，指向 RINGDIR（E）或 FLATRINGDIR（M）的索引 |
| 4 | 2 | `ring_count` |
| 6 | 2 | 保留 |
| 8 | 16 | 外环包围盒，四个 `i32` 值 |

第一个环为外环，其余为第一层内环。该格式不支持嵌套内环。

### 4.4 GRID，类型 8（可选）

稠密的 1° × 1° 候选索引：

```
i16 lng_min
i16 lat_min
u16 lng_cells
u16 lat_cells
u32 cand_count
u32 cells[lng_cells * lat_cells]
u16 candidates[cand_count]
```

对输入坐标：

```
cx = floor(lng) - lng_min
cy = floor(lat) - lat_min
cell_index = cy * lng_cells + cx
```

超出范围的单元没有候选项。单元字的编码方式为：

```
count  = cells[cell_index] >> 28
offset = cells[cell_index] & 0x0fffffff
```

候选列表为 `candidates[offset : offset + count]`，其中时区索引按升序排列；多个单元可以共享同一候选列表。网格键可能比查询域多出一个单元（`lng_min: -181..180`，`lat_min: -91..90`），因为它们可以从上游的浮点索引直接复制。每个单元最多 15 个候选项，`cand_count` 小于 2²⁸，每个候选项均小于 `tz_count`。GRID 不存在时，读取方扫描 TZDIR。

### 4.5 FUZZY，类型 10（可选）

瓦片预索引，存储为一个有序的瓦片 ID 数组。它是快速路径，可在不做点在多边形内判定的情况下回答大部分单名称查询。

```
u8  idx_zoom
u8  agg_zoom               // agg_zoom <= idx_zoom
u16 reserved (0)
u32 tile_count
u32 multi_group_count
u32 multi_value_count
u64 keys[tile_count]       // packed TileID, strictly ascending
u16 values[tile_count]
u16 multi_dir[multi_group_count * 2]   // (first, count) pairs
u16 multi_values[multi_value_count]    // NAMES indices
(zero padding to 4-byte alignment)
```

键的打包方式为 `uint64(z) << 56 | uint64(x) << 28 | uint64(y)`。在值中，第 15 位为 0 时，第 0 到 14 位为 NAMES 索引；第 15 位为 1 时，第 0 到 14 位为 `multi_dir` 的索引，用于命名多个时区的瓦片。该区段必须按 8 字节对齐，`keys` 从区段偏移 16 开始。

限制：

| 字段 | 位宽 | 上限 |
| --- | --- | --- |
| NAMES 索引 / `multi_dir` 索引 | 15 位 | ≤ 32,767，因此存在 FUZZY 时 `tz_count` ≤ 32,768 |
| `multi_dir.first + count` | u16 | `multi_value_count` ≤ 65,535 |
| 瓦片 x、y | 28 位 | < 2²⁸ |

在 `2026c` 数据集上为 87,572 个瓦片，其中 156 个命名两个时区，编码后约 880 KB。输出 FUZZY 的编码器必须确认预索引版本、几何数据版本与文件头 `data_version` 三者一致。

## 5. E profile 几何数据

### 5.1 RINGDIR，类型 4

28 字节记录：

| 偏移 | 长度 | 字段 |
| ---: | ---: | --- |
| 0 | 4 | `op_first`，指向 RINGOPS 的索引 |
| 4 | 4 | `point_count`，展开后的开环顶点数 |
| 8 | 2 | `op_count` |
| 10 | 2 | 保留 |
| 12 | 16 | 环包围盒，四个 `i32` 值 |

一个环至少包含 3 个开环点。其操作构成一个环路并共享连接顶点：对每一对循环相邻的操作，前一个操作在环序上的出点等于后一个操作在环序上的入点。存储的点数满足：

```
ring.point_count = sum(referenced_group.point_count) - ring.op_count
```

### 5.2 RINGOPS，类型 5

`u32` 字数组：

```
bit 31:     reversed
bits 0..30: group index into GROUPDIR
```

该标志描述环序遍历方向，编码器仅对共享边设置它。点在多边形内判定可以对每个 group 一律正向扫描，因为射线穿越的奇偶性取决于线段集合，与线段顺序无关。

### 5.3 GROUPDIR，类型 6

44 字节记录：

| 偏移 | 长度 | 字段 |
| ---: | ---: | --- |
| 0 | 4 | `chunk_first`，指向 CHUNKDIR 的索引 |
| 4 | 4 | `point_count` |
| 8 | 2 | `chunk_count` |
| 10 | 2 | 保留 |
| 12 | 8 | 首点，`first_lng, first_lat` |
| 20 | 8 | 末点，`last_lng, last_lat` |
| 28 | 16 | group 包围盒，四个 `i32` 值 |

一个 group 或者是一条共享边，或者是一段合并后的内联点序列，两者表示方式相同。group 至少包含 2 个点，同时存储两个端点，内部没有连续重复点。只有一个操作的闭合环可能出现 `first == last`。正向操作的入点为 `first`、出点为 `last`，反向操作则相反。

共享边去重体现在该区段中：两个时区之间的边界只作为一个 group 存储一次，由两侧的环分别以正向和反向引用。

### 5.4 CHUNKDIR，类型 7

24 字节记录：

| 偏移 | 长度 | 字段 |
| ---: | ---: | --- |
| 0 | 4 | `point_off`，在 POINTS 中的字节偏移 |
| 4 | 2 | `point_count` |
| 6 | 2 | 保留 |
| 8 | 16 | 线段包围盒，四个 `i32` 值 |

同一 group 的各 chunk 连续、有序，并划分该 group 的全部点；每个 group 至少有一个 chunk，每个 chunk 至少有一个点。`point_off` 在 CHUNKDIR 中严格递增，chunk 的字节区间在下一个 chunk 的 `point_off` 处结束，最后一个 chunk 在 POINTS 末尾结束。

chunk 包围盒覆盖该 chunk 内相邻点之间的线段；当同一 group 中还有下一个 chunk 时，也覆盖从本 chunk 末点到下一个 chunk 首点的线段。读取方因此可以在不解码的情况下跳过某个 chunk。

解码器在 chunk 的字节区间内恰好消费 `point_count` 个点。读到最后一个纬度 varint 之后，游标必须正好等于区间末尾；越过区间边界或残留字节均为错误。

### 5.5 POINTS，类型 9

POINTS 是各个可独立解码的 chunk 流的拼接：

```
zigzag-LEB128 absolute_lng
zigzag-LEB128 absolute_lat

repeat point_count - 1 times:
    zigzag-LEB128 delta_lng
    zigzag-LEB128 delta_lat
```

每个 chunk 都以一个绝对点重新开始，因此各 chunk 可以独立跳过。解码增量时使用带检查的 `int32` 累加。`int32` 值 `v` 的 zigzag 编码为 `uint32((v << 1) ^ (v >> 31))`。

## 6. M profile 几何数据

M profile 用两个区段替代了 chunk 机制，因此打开时不做解码：环存储直接引用映射的文件。

### 6.1 FLATPOINTS，类型 12

小端 `(int32 lng, int32 lat)` 对的纯数组，拼接每个环的开环点序列，连接点的重复顶点已经展开。点对数量为区段长度除以 8；该区段必须按 8 字节对齐，长度为 8 的整数倍。

### 6.2 FLATRINGDIR，类型 13

24 字节记录：

| 偏移 | 长度 | 字段 |
| ---: | ---: | --- |
| 0 | 4 | `point_first`，指向 FLATPOINTS 的点对索引 |
| 4 | 4 | `point_count`，开环顶点数，≥ 3 |
| 8 | 16 | 环包围盒，四个 `i32` 值 |

### 6.3 YSTRIPES，类型 14（已分配，当前不输出）

逐环的水平条带点在多边形内判定索引的序列化形式：

```
RINGSTRIPEDIR[ring_count]   (24-byte records, parallel to FLATRINGDIR):
    u32 stripe_first     // into STRIPES, absolute
    u32 stripe_count     // 0 -> no index for this ring (linear scan)
    u32 index_first      // into INDEXES, absolute
    u32 index_count
    i32 min_y
    i32 height
STRIPES:  (u32 start, u32 count) pairs; start relative to index_first
INDEXES:  u32 segment indices, packed by stripe
```

存储内容必须与 tzf 的 `geom.buildYStripes` 输出逐位相同。M profile 的首个版本不输出该区段：在 lite 数据集上，它会给一个 10 MB 的文件增加约 6 到 10 MB，而在多核主机上于打开时重建该索引约需 5 ms。现在给出规范，可使日后增加该区段仍属于 `format_minor` 递增。单核 CPU 配额下该重建的耗时记录在[选择查找器]({{< relref "../guides/choosing-a-finder" >}})。

### 6.4 体积构成

lite `2026c`，M profile，不含 YSTRIPES：

| 组成部分 | 体积 |
| --- | ---: |
| FLATPOINTS（1,304,553 个点对） | 10,436 KB |
| FLATRINGDIR（2,078 条记录） | 49 KB |
| TZDIR + POLYDIR + NAMES | ~51 KB |
| GRID | ~569 KB |
| FUZZY | ~880 KB |
| 合计 | ≈ 12.0 MB |

以同样方式展开完整数据集会得到 8,377,299 个点对，约 67 MB。`full.tzm` 不做分发。

## 7. 查询语义

1. 拒绝 NaN、无穷大、经度超出 `-180..180` 或纬度超出 `-90..90` 的输入。
2. 一次性缩放且不做取整：`x = float64(lng) * 100000.0`，`y = float64(lat) * 100000.0`。
3. 从 GRID 读取候选项；GRID 不存在时扫描 TZDIR。
4. 若网格单元恰好只有一个候选项，`NO_SHORTCUT` 未置位，且 `-179 < lng < 179`、`-89 < lat < 89`，直接返回该候选项。
5. 否则按存储的升序逐个测试候选项，在解码几何数据之前先应用时区、多边形、环、group 和 chunk 的包围盒。
6. 当多边形的外环包含该点且没有任何内环包含该点时，该多边形包含该点。
7. 返回第一个包含该点的候选项；没有候选项包含该点时返回空结果。

在 E profile 中做点在多边形内判定时，对每个被引用 group 的存储点一律正向扫描，不考虑 `reversed` 标志；计算相邻 chunk 之间的连接线段；对每个循环操作连接处，从 GROUPDIR 取出出点与入点，端点相同则不产生线段，端点不同则加入从出点到入点的线段。

满足以下条件时可以跳过 group 或 chunk：

```
y < min_lat
y > max_lat
max_lng < x
```

多结果查询会禁用单候选快捷路径，计算每个候选项，并按名称的无符号 UTF-8 字节序对匹配结果排序。

### 边界语义

时区多边形无缝覆盖全球，因此落在共享边界上的查询同时落在两个多边形上。v2 运行时采用允许落在边上的包含判定：外环把落在其线段上的点视为被包含，内环则不视为被包含。因此共享边界上的点属于所有与之相接的多边形。

该格式早先的版本写的是此前的规则，即落在任一环线段上的点视为在该环之外；它早于 [tzf#216](https://github.com/ringsaturn/tzf/issues/216)。当前规则是本页描述的实现行为。

## 8. 校验与兼容性

读取方必须在不触发 panic、越界读取、整数溢出或未定义行为的前提下拒绝结构错误。打开时至少校验：

- magic、主版本号、文件头大小、坐标缩放系数、profile 及实际文件大小；
- 用宽整数运算校验区段表范围；
- 该 profile 必需区段的存在性与唯一性，以及不存在跨 profile 的区段类型；
- `GRID_PRESENT` 与 GRID 区段是否一致；
- 区段的对齐、范围与不重叠；
- 各目录区段长度与其记录宽度是否匹配；
- NAMES 的 offsets 与字符串合法性；
- GRID 的尺寸、区段长度与坐标键范围；
- FUZZY 区段长度与其声明的各项计数是否匹配。

目录区间、group 与环的点数之和、操作索引、chunk 偏移、varint 的精确终止、包围盒顺序、候选索引以及增量溢出，必须在打开时或首次使用前完成校验。

保留字段与保留位写入为零，读取时忽略；读取方同样忽略未知的区段类型。不兼容的布局变更递增 `format_major`。增量式变更递增 `format_minor`，可以新增区段类型、标志位或为保留字段赋予含义。格式 1.1 正是通过该机制加入了 profile 字节以及 FUZZY、FLATPOINTS、FLATRINGDIR 和 YSTRIPES 类型。

更深层的语义检查，包括包围盒包含关系、存储的 group 端点、连接处的连通性和几何数据的一致性，由编码器和构建管线负责。CRC 用于保护已校验的产物不被意外损坏。

`data_version` 标识时区数据集，与格式版本相互独立。

## 9. 分发的产物

| 文件 | Profile | 体积 | 对应的查找器 |
| --- | --- | ---: | --- |
| `lite.tzb` | E | 3,973,696 B（~4 MB） | Go `NewEmbeddedFinder`、Rust `EmbeddedFinder` / `DefaultFinder`、tzfpy |
| `lite.tzm` | M | 10,180,180 B（~10 MB） | Go `NewDefaultFinder` |
| `full.tzb` | E | 13,765,490 B（~14 MB） | Go `NewFullFinder`、Rust `DefaultFinder::new_full` |

三个文件都带有 FUZZY 区段，并携带相同的 `data_version`。仓库不分发 `full.tzm`，需要时用 `cmd/tzb2tzm` 在本地生成。
