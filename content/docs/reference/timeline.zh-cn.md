---
date: '2025-07-21T10:52:43+09:00'
description: 'Project tzf 开发历史 - 从最初的 Go 实现到 2026 年的 v2 发布。'
draft: false
lastmod: '2026-09-11T00:00:00+09:00'
seo:
  description: 'Project tzf 的开发时间线 - 从 2022 年首个 Go 版本到 2026 年移除 protobuf 的 v2 发布。'
  noindex: false
  title: '时间线 - Project tzf'
summary: tzf 生态系统中各关键里程碑的时间顺序历史。
title: 时间线
toc: true
weight: 6
---

## 2022

### 2022-05-29

创建仓库 <https://github.com/ringsaturn/tzf>。

### 2022-08-01

发布 tzfpy 首个版本 [`v0.6.0`](https://pypi.org/project/tzfpy/0.6.0/)，
基于 Go 的 CGO 特性。

### 2022-11-06

为 tzf 设计了基于瓦片的索引。

### 2022-11-20

发布 <https://github.com/ringsaturn/tzf-rs> 首个版本。

### 2022-11-21

使用 PyO3 替代 Go 绑定，发布为 Rust 绑定，
tzfpy 版本 [`0.10.0`](https://pypi.org/project/tzfpy/0.10.0/)。

tzfpy 迁移至独立仓库 <https://github.com/ringsaturn/tzfpy>。

## 2024

### 2024-04-22

创建 <https://github.com/ringsaturn/tzf-wasm>，即 tzf-rs 的 WebAssembly 版本。

## 2025

### 2025-02-21

创建 <https://github.com/ringsaturn/tzf-swift>，即 tzf 的 Swift 版本。

### 2025-03-24

发布 tzf、tzf-rs、tzfpy、tzf-wasm、tzf-swift 的 v1.0.0。

tzf 仓库的 API 现已稳定。

### 2025-05-03

创建 <https://github.com/ringsaturn/pg-tzf>，即 tzf-rs 的 PostgreSQL 扩展。

## 2026

### 2026 春季

**拓扑感知简化**在 tzf v1.1.0 中实现，解决了一个长期存在的问题
（[tzf#183](https://github.com/ringsaturn/tzf/issues/183)）：独立逐多边形
RDP 简化会在共享时区边界处产生间隙和重叠。
新方案首先检测共享边，仅简化一次，然后将简化后的边界
替换回两个相邻多边形中。

**全新数据分发仓库** [`ringsaturn/tzf-dist`](https://github.com/ringsaturn/tzf-dist)
推出，以新的 `CompressedTopoTimezones` 格式分发数据：

| 文件 | 大小 | 描述 |
| --- | --- | --- |
| `combined-with-oceans.compress.topo.bin` | 约 17 MB | 完整精度 |
| `combined-with-oceans.topology.compress.topo.bin` | 约 5.4 MB | 拓扑简化（精简版） |
| `combined-with-oceans.topology.preindex.bin` | 约 2 MB | 瓦片预索引 |

完整精度数据集从约 90 MB 缩减至约 17 MB，使得在 tzf-rs v1.3.0 中
作为可选 Cargo feature 提供成为可能（`DefaultFinder::new_full()`）。

**YStripes 空间索引**（移植自 [`tidwall/tg`](https://github.com/tidwall/tg)）
成为 tzf v1.1.0 (Go) 和 tzf-rs v1.2.0 (Rust) 中的默认多边形级索引。
在 Apple M3 Max 上单次随机城市查询约 1 µs。

此轮发布包括：tzf v1.1.0、tzf-rs v1.2.0 / v1.3.0、tzfpy v1.2.0 / v1.3.0、
tzf-dist v0.0.2026-a、geometry-rs v0.4.1。

更多详情请参阅博客文章 [tzf 2026 春季更新]({{< ref "/blog/2026-spring-news/index.md" >}})。

### 2026-07-19

TZF 嵌入式二进制格式规范在 1.0 版本上标记为 Final（见[格式参考](/zh-cn/docs/reference/embedded-binary-format/)）。它定义了 `TZFB` 容器：64 字节文件头、区段表、区段类型 1 到 9，以及 CRC32 校验尾，几何数据以分块的 zigzag-LEB128 varint 流存储。该布局使读取方无需解码整个文件即可回答查询。

### 2026-08-16

格式 1.1 加入 v2 运行时所需的部分：文件头偏移 48 处的 `profile` 字节、区段类型 10（`FUZZY`，瓦片预索引），以及包含区段类型 12（`FLATPOINTS`）、13（`FLATRINGDIR`）和 14（`YSTRIPES`，已分配但不输出）的 M profile。必需区段改为按 profile 区分。

### 2026-08-18

确定 v2 API：五个返回 `F` 的构造函数，没有选项，不导出查找器类型，并以 `x` 承载语义化版本承诺之外的接口。FUZZY 快速路径同日进入原地查找器，使其在 lite 文件上的中位查询延迟从 4.7 µs 降到 542 ns。

### 2026-08-28

protobuf 从 tzf 代码树中移除。管线改用原生 Go 结构体，中间产物使用 `encoding/gob`，这些中间产物仅在构建内部使用，不做分发。模块就地变更为 `github.com/ringsaturn/tzf/v2`，不设 `v2/` 子目录。tzf-rs 在同一时间段移植到 `.tzb` 运行时；其 `.tzm` 加载器经过测量，节省约 3 ms 打开耗时但内存占用更高，随后被移除，因此 tzf-rs 只读取 E profile。

tzf-dist 停止发布 protobuf 产物，改为分发 `lite.tzb`、`lite.tzm` 和 `full.tzb`。v1 数据线冻结在最后一个 protobuf 版本上。

在 Apple M3 Max 上使用 `2026c` 数据集与 protobuf 路径对比测得：

| 路径 | 打开耗时 | 常驻 | 查询 |
| --- | ---: | ---: | ---: |
| Go，full protobuf（v1） | 288 ms | ~153 MB | ~290 ns |
| Go，full `.tzb` 展开 | 78.5 ms | ~145 MB | ~300 ns |
| Go，lite `.tzm` 内存镜像 | 7.7 ms | ~12 MB 堆 + 10 MB 只读 | 298 ns |
| Go，lite `.tzb` 原地查询 | 1.7 ms | ~3 MB | ~6 µs |
| Rust，lite protobuf（v1） | 71 ms | 峰值 RSS 77.8 MiB | 316 ns |
| Rust，lite `.tzb` | 冷启动 18 ms | 峰值 RSS 44.1 MiB | 260 ns |

### 2026-09

tzf（Go）、tzf-rs（Rust）和 tzfpy（Python）发布 v2。tzf-dist 于 2026-09-10 打出第一个 `.tzb`/`.tzm` 工件集的 tag `v0.0.2026-c-tzb1`，tzf v2.0.0 同日发布，tzf-rs 2.0.0 与 tzfpy 2.0.0 于 2026-09-11 发布。Go 模块路径增加 `/v2` 后缀，tzf-rs 到达 2.0.0，tzfpy 绑定 tzf-rs 2.0。v1 系列（tzf v1.2.x、tzf-rs 1.3.x、tzfpy 1.3.x）仍然可用，并冻结在最后一个 protobuf 数据版本上。tzf-wasm 2.0.0 于 2026-09-11 基于 tzf-rs 2.0.0 发布，tzf-web 已使用该版本。截至该时间点，tzf-swift 基于 v1 系列构建，独立维护的 tzf-rb 同样如此。
