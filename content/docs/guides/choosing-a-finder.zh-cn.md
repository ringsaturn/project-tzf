---
date: '2026-09-10T00:00:00+09:00'
description: tzf v2 各个查找器的内存、延迟和加载耗时数据，以及容器、嵌入式目标和受配额限制的 Pod 的部署方式。
draft: false
lastmod: '2026-09-11T00:00:00+09:00'
seo:
  description: tzf v2 部署指南：查找器对照表（内存、延迟、加载耗时）、无文件系统与 mmap 方案、cgroup 配额 Pod、tzb2tzm 转码及分发体积。
  noindex: false
  title: '选择查找器 - Project tzf'
summary: tzf v2 各查找器的实测开销，以及容器、嵌入式目标和单核 Pod 的部署方式。
title: 选择查找器
toc: true
weight: 1
---

tzf v2 的每个查找器都基于同一份数据集作答，区别在于常驻内存、打开耗时，以及预索引未覆盖该点时的查询延迟。本页汇总实测数据，以及由此得出的部署方式。

## 各语言的推荐用法

| 场景 | Go | Rust | Python |
| --- | --- | --- | --- |
| 后端服务，常规容器 | `NewDefaultFinder()` | `DefaultFinder::new()` | `get_tz()`（模块本身即为共享的默认查找器） |
| 内存为数十 MB，或没有文件系统 | `NewEmbeddedFinder()` | `EmbeddedFinder::new()` | 不提供 |
| 边界 ~111 m 以内需要精确结果 | `NewFullFinder()` | `DefaultFinder::new_full()`（仅 git 提供的 `full` feature） | 不提供 |
| 自行从磁盘或对象存储读取的字节 | `NewFinderFromTZB` / `NewFinderFromTZM` | `DefaultFinder::from_tzb` / `EmbeddedFinder::from_tzb` | 不提供 |

## 部署对照表

在 Apple M3 Max 上针对 `2026c` 数据集测得。单核打开耗时对应 CPU 配额低于一核的 Pod，16 核一列对应不受限的笔记本或节点。

| 机制 | Go 构造函数 | 打开耗时，16 核 / 1 核 | 常驻 | 查询 |
| --- | --- | ---: | --- | ---: |
| lite `.tzm` 内存镜像 | `NewDefaultFinder()` | 7.7 ms / 28 ms | ~12 MB 堆 + 10 MB 只读数据 | 298 ns |
| lite `.tzb` 原地查询 | `NewEmbeddedFinder()` | 1.7 ms / 1.7 ms | ~3 MB | ~6 µs（预索引命中时 p50 为 542 ns） |
| lite `.tzb` 展开 | `NewFinderFromTZB(lite)` | 19.9 ms / 41 ms | ~27 MB | ~290 ns |
| full `.tzb` 展开 | `NewFullFinder()` | 78.5 ms / 214 ms | ~145 MB | ~300 ns |
| full protobuf（v1，用于对照） | — | 288 ms / 344 ms | ~153 MB | ~290 ns |

之后加入的字节读取快速路径进一步降低了展开路径的打开耗时。同一台机器上五次预热取最优：lite 展开 20.2 → 16.8 ms，full 展开 72.7 → 63.5 ms，lite `.tzm` 7.5 → 6.9 ms。

各列的含义：

- **打开耗时：** 一次性开销。每个查找器都可并发使用，因此进程构建一个查找器并复用。打开耗时影响启动延迟、缩容到零的函数计算和命令行工具。
- **常驻：** 进程在处理查询期间持有的内存。对 `.tzm` 内存镜像，其中约 10 MB 是页缓存可在进程间共享的只读映射，其余为堆内存。
- **查询：** 对随机世界城市执行一次 `GetTimezoneName`。原地机制的数值为微秒级，因为每次回退到点在多边形内判定时都要从压缩文件中解码几何数据。

## 无文件系统或内存很小的场景

`NewEmbeddedFinder()` 原地读取 lite `.tzb`：除文件字节外堆占用不足 1 KB，合计约 3 MB，加载时不做解码，查询过程不分配内存。适用场景为嵌入式目标、1.7 ms 打开耗时比 6 µs 尾延迟更重要的缩容到零函数计算，以及内存上限较低的进程。

如果字节不是编译进二进制的，例如磁盘上的文件、`mmap` 映射区域或对象存储中的 blob，可以走实验性的 `x` 包，而不必把整个文件读入内存：

```go
f, err := os.Open("lite.tzb")
if err != nil {
	panic(err)
}
info, err := f.Stat()
if err != nil {
	panic(err)
}
finder, err := x.NewFinderFromTZBReaderAt(f, info.Size())
```

`*os.File` 满足 `io.ReaderAt`，`mmap` 封装同样满足。文件在打开时校验一次，之后查询只读取所需的字节。`ReaderAt` 访问在内部串行化，以保持查询路径不分配内存，因此吞吐量不随核数增长。并发吞吐量比堆占用更重要时，适用 `.tzm` 内存镜像。

`x` 包不在 tzf 的语义化版本承诺范围内：次版本号变更即可能修改或移除其 API。

## 多核节点与 cgroup 配额 Pod

`.tzm` 加载器在打开时并行重建 YStripes 多边形索引。在 16 核上该步骤约需 5 ms；在 CPU 配额低于一核时，上表 7.7 ms 与 28 ms 的差距大部分来自这一步。对完整数据集，同一步骤在单核下需要 158 ms。

Pod 的 CPU 配额不足一核，且启动延迟受 SLO 约束时，可选方案有：

- `NewEmbeddedFinder()`，其 1.7 ms 打开耗时不依赖核数；
- 使用 `NewDefaultFinder()`，并在就绪探针返回就绪之前完成构建；
- 在平台支持的情况下，为启动阶段提高 CPU 配额。

查询延迟不依赖核数。

## 本地生成 `.tzm`

`tzf-dist` 分发 `lite.tzm`，因为 `NewDefaultFinder()` 需要读取它。仓库不分发 `full.tzm`：该文件为 63.6 MB，而 `full.tzb` 为 13.77 MB。M profile 在使用它的主机上生成。

转换过程不涉及 protobuf，输出与从源数据直接编码 M profile 的结果逐字节相同：

```bash
go run github.com/ringsaturn/tzf/v2/cmd/tzb2tzm@latest -o full.tzm full.tzb
```

用 `NewFinderFromTZM(data)` 加载结果，或者 `mmap` 该文件并传入映射得到的字节。这些字节在查找器的生命周期内必须保持存活且不被修改，因为环存储直接引用它们。在小端主机上，若切片按 8 字节对齐，加载器采用零拷贝视图；在未对齐或大端主机上，加载器回退为一次性解码副本，内存占用约为原来的两倍。

## 分发体积

| 分发渠道 | 包含内容 | 体积 |
| --- | --- | --- |
| Go 模块（`tzf-dist`） | `lite.tzb` + `lite.tzm` + `full.tzb` | 压缩后 2.55 + 6.35 + 10.39 MB，合计约 19.3 MB |
| Rust crate（crates.io） | 仅 `lite.tzb` | ~4 MB |
| Rust crate（git，`full` feature） | `full.tzb` | ~14 MB |
| Python wheel（`tzfpy`） | 扩展模块内的 `lite.tzb` | 2.76 MB（v1 为 4.31 MB） |

Go 模块这一组比 v1 的 protobuf 组合（压缩后约 16 MB）大约 3 MB，因为它同时携带 lite 数据集的两种 profile。Python wheel 变小，是因为移除了 protobuf 解码路径。

## 多结果 API 的适用场景

`GetTimezoneName` / `get_tz_name` / `get_tz` 返回单个名称，并优先走预索引：瓦片查找可以在不做点在多边形内判定的情况下回答大部分查询。以下情况适用多结果 API，即 `GetTimezoneNames` / `get_tz_names` / `get_tzs`：

- **边界重叠：** 源数据中存在被多个时区覆盖的区域，例如 Asia/Shanghai 与 Asia/Urumqi 共有的区域。
- **位于共享边界上的点：** 共享边界上的点属于所有与之相接的多边形。海上时区边界位于整数经线上，例如 7.5° 和 22.5°。
- **需要多边形精确结果：** 多结果 API 在任何查找器中都不查询预索引，并会计算每个候选项。
- **接口需要表达歧义：** 单名称 API 返回第一个匹配项，调用方无法区分唯一结果与被截断的结果。

其开销更高：在 tzf-rs 自带的 criterion 基准测试中（Apple M3 Max，lite 数据集），`DefaultFinder` 随机城市查询的多边形精确路径为 178 ns，预索引优先路径为 75 ns，边界附近的差距更大。

## 与完整数据集的精度差异

lite 数据集经过 epsilon 为 0.001 度的拓扑感知 Douglas-Peucker 简化，边界位移上限约为 111 m。在 2026-09-11 快照中，lite 查找器对 154,694 个世界城市的查询结果与完整精度基准相比有 1 处不一致（0.0006%），且该结果对应的 UTC 偏移量相同。

查询点可能落在边界 ~111 m 以内且需要精确名称时适用完整数据集，例如地理围栏、计费或司法辖区判定。实测位移数据见[常见问题]({{< relref "faq#is-tzf-100-accurate" >}})。
