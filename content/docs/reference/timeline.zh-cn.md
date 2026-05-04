---
date: '2025-07-21T10:52:43+09:00'
description: Project tzf 开发历史 - 从最初的 Go 实现到 2026 年春季更新。
draft: false
lastmod: '2026-04-26T00:00:00+09:00'
seo:
  description: Project tzf 的开发时间线 - 从 2022 年首个 Go 版本到 2025 年 v1.0.0 稳定版发布。
  noindex: false
  title: 时间线 - Project tzf
summary: tzf 生态系统中各关键里程碑的时间顺序历史。
title: 时间线
toc: true
weight: 5
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
