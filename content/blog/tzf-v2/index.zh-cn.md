---
author: ringsaturn
date: '2026-09-11'
description: tzf v2 从运行时和数据管线中移除了 protobuf。边界数据改为以 TZF 嵌入式二进制格式分发，由查找器直接查询。本文记录该格式、Go、Rust 和 Python 三个版本的查找器构成、实测的加载与内存数据，以及从 v1 迁移的方式。
draft: false
tags:
- tzf
- Side Project
- Geo
- timezone
title: tzf v2
---

[2026 春季更新]({{< ref "/blog/2026-spring-news/index.md" >}})完成了 tzf 数据侧的工作：拓扑感知简化、共享边去重和 polyline 压缩把完整精度数据集从约 90MB 降到约 17MB。这次更新没有改变的是数据进入内存的方式。各语言实现在启动时仍然要把一条 protobuf 消息解析成对象图，再据此建立查询结构，然后丢弃该对象图。

v2 从运行时和管线中同时移除了 protobuf。边界数据改为以查找器可直接读取的容器分发。

<!--more-->

## 移除 protobuf 的原因

有三项开销来自解析这一步。

**打开耗时。** 在 Go 中加载完整精度数据集需要 288ms。同一份数据在新格式下的打开耗时为 78.5ms。在 Rust 中，lite 数据集从 71ms 降到冷启动 18ms。

**加载期间的内存峰值。** 解码后的消息与据此建立的查询结构同时存活，因此高水位远高于稳定状态：在 2026-09-11 的基准快照中，Go 完整精度查找器峰值为 315.0MiB，常驻为 147.0MiB。容器内存限制需要容纳的是这个峰值。

**没有原地查询的途径。** protobuf 消息必须完整解析之后才能读取其中任何字段，因此无法通过只读取文件的几 KB 来回答查询。对内存只有数十 MB 的部署没有可用的方案。

构建数据的管线同样带着 protobuf，构建过程中还包含生成代码和 schema 编译器。中间产物现在使用原生 Go 结构体加 `encoding/gob`，仅在构建内部使用，不做分发。从原始 GeoJSON 重新构建完整数据集可以得到逐字节相同的 `full.tzb`，这次改动就是这样验证的。

## 嵌入式二进制格式

`.tzb` 文件是一个分区段的小端容器：64 字节文件头、区段表、各数据区段，以及 CRC32 校验尾。目录项为定长记录，每个环、group 和 chunk 都带有包围盒，坐标为按 100000 缩放的 `int32` 度数。读取方先通过 1° × 1° 的格子区段定位候选时区，再逐层沿包围盒下探，只解码通过筛选的几何数据。

两种 profile 共用该容器，由文件头中的一个字节选择：

| Profile | 扩展名 | 几何数据存储方式 |
| --- | --- | --- |
| E（embedded） | `.tzb` | 分块的 zigzag-LEB128 varint 流 |
| M（memory image） | `.tzm` | 一个扁平的 `(int32, int32)` 对数组 |

M profile 按查询代码使用的布局存储点，因此环存储直接指向映射的文件，不解码也不复制。它的体积更大：同一份 lite 数据集下为 10.18MB，`.tzb` 为 3.97MB。`full.tzm` 约为 67MB，不做分发，由使用它的主机通过 `cmd/tzb2tzm` 生成。

区段类型 10 承载瓦片预索引，早期版本把它作为独立文件分发。在 `2026c` 数据集上，它包含 87,572 个瓦片，其中 156 个命名两个时区，约 880KB。三个分发的产物都带有该区段。

完整布局记录在[嵌入式二进制格式]({{< relref "/docs/reference/embedded-binary-format" >}})。

## 查找器

### Go

五个构造函数，全部返回 `tzf.F` 接口。该包不导出查找器类型，也不提供选项。

| 构造函数 | 数据 | 常驻 | 查询 |
| --- | --- | --- | ---: |
| `NewDefaultFinder()` | lite `.tzm`，原地引用 | ~12MB 堆 + 10MB 只读 | 298ns |
| `NewEmbeddedFinder()` | lite `.tzb`，原地查询 | ~3MB | ~6µs |
| `NewFullFinder()` | full `.tzb`，展开 | ~145MB | ~300ns |
| `NewFinderFromTZB(data)` | 调用方提供的 `.tzb` | 取决于文件 | ~290ns |
| `NewFinderFromTZM(data)` | 调用方提供的 `.tzm` | 取决于文件 | ~300ns |

`NewEmbeddedFinder` 是新增的。它除文件字节外堆占用不足 1KB，查询过程不分配内存。对于调用方已持有的字节或 `mmap` 映射区域，`x.NewFinderFromTZBReaderAt` 接受一个 `io.ReaderAt`；`x` 包不在该模块的语义化版本承诺范围内。

`GeoJSONer` 通过接口断言获取，不属于 `F`，现在除边界多边形外还可以导出预索引瓦片。

### Rust

tzf-rs 2.0 提供 `DefaultFinder` 和 `EmbeddedFinder`。`FuzzyFinder`、`Finder` 和 `FinderOptions` 已移除：预索引是两个查找器内部的快速路径，YStripes 索引始终构建。该 crate 只读取 `.tzb`，传入 `.tzm` 字节时返回 `Error::Profile`。crates.io 上的包携带 `lite.tzb`（~4MB）；`full.tzb`（~14MB）通过 `full` feature 从 git 获取。

字节构造函数现在返回 `Result`：文件在打开时会做 CRC 校验和结构校验，数据损坏时返回错误，而不产生空的查找器。

### Python

tzfpy 2.0 绑定 tzf-rs 2.0。四个查询函数没有变化，另外新增了两个 GeoJSON 导出函数。移除 protobuf 路径后，wheel 从 4.31MB 降到 2.76MB，查找器初始化从 68ms 降到 15ms，查询延迟不变。`_TZFPY_DISABLE_Y_STRIPES` 这一开关随其控制的选项一并移除。

## 测量数据

Apple M3 Max，`2026c` 数据集。打开耗时和常驻内存来自 v2 的设计记录；查询延迟、精度和内存各列来自 [tz-benchmark](https://github.com/ringsaturn/tz-benchmark) 的 2026-09-11 快照，在同一台机器上针对已发布的 2.0.0 版本本机取得。

| 路径 | 打开耗时 | 常驻 | 查询，世界城市 |
| --- | ---: | ---: | ---: |
| Go，full protobuf（v1） | 288ms | ~153MB | ~290ns |
| Go，full `.tzb` 展开 | 78.5ms | ~145MB | ~300ns |
| Go，lite `.tzm` | 7.7ms | ~12MB 堆 + 10MB 只读 | 298ns |
| Go，lite `.tzb` 原地查询 | 1.7ms | ~3MB | ~6µs |
| Rust，lite protobuf（v1） | 71ms | 峰值 RSS 77.8MiB | 316ns |
| Rust，lite `.tzb` | 冷启动 18ms | 峰值 RSS 44.1MiB | 260ns |

在每个产物约 195,000 个靠近边界的采样点以及世界城市数据集上，Go 与 Rust 的 `GetTimezoneName` 和 `GetTimezoneNames` 返回结果完全一致。与完整精度基准相比，lite 查找器在 154,694 个世界城市中有 1 处不一致（0.0006%），该结果对应的 UTC 偏移量相同。

Rust 侧也实现过一个 `.tzm` 加载器。它节省约 3ms 打开耗时，同时把峰值 RSS 从 44.1MiB 提高到 68.7MiB，随后被移除；tzf-rs 只读取 E profile。

## 迁移

三种语言的查询接口都没有变化，大部分调用处只需改动依赖。

- Go：模块路径变为 `github.com/ringsaturn/tzf/v2`。对照表见 [Go 指南]({{< relref "/docs/guides/tzf" >}})。
- Rust：`DefaultFinder::new()` 和 `new_full()` 的签名不变；移除的类型列在 [Rust 指南]({{< relref "/docs/guides/tzf-rs" >}})。
- Python：参见 [Python 指南]({{< relref "/docs/guides/tzfpy" >}})。
- 某个部署适合哪个构造函数，参见[选择查找器]({{< relref "/docs/guides/choosing-a-finder" >}})。

## v1 系列的状态

tzf v1.2.x、tzf-rs 1.3.x 和 tzfpy 1.3.x 仍然可用，也可以继续工作。tzf-dist 停止发布 protobuf 产物，因此这些版本冻结在最后一个数据版本上；获取更新后的边界数据需要迁移到 v2。tzf-wasm 2.0.0 基于 tzf-rs 2.0.0 构建，tzf-web 已使用该版本。tzf-swift 2.0.0 是不依赖 protobuf 的移植，直接读取 `lite.tzb`，提供 `DefaultFinder` 和 `EmbeddedFinder`。tzf-rb 是由 [HarlemSquirrel](https://github.com/HarlemSquirrel) 维护的第三方 Ruby 绑定，目前基于 v1 系列构建。

## 致谢

YStripes 索引来自 Josh Baker 的 [`tidwall/tg`](https://github.com/tidwall/tg) 项目，tzf 是移植而非重新实现。边界数据来自 [evansiroky/timezone-boundary-builder](https://github.com/evansiroky/timezone-boundary-builder)，该项目跟踪 IANA 时区数据库的发布。v2 的实现以及 Go 与 Rust 之间的一致性验证工作，借助 Claude 和 Codex 经过多轮实现、验证和重构完成。
