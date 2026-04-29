---
author: ringsaturn
cover:
  image: https://blog-assets.ringsaturn.me/pic/tzf-spring-news/cover.webp
date: '2026-04-26'
tags:
- tzf
- Side Project
- Geo
- timezone
title: tzf 的春季更新
---
<!-- [History of package tzf]({{< ref "/blog/history-of-tzf/index.md" >}}) -->

距离 tzf 系列项目启动已经过去了几年。上次系统性回顾开发历史，还是 2023 年初的 [tzf 的演进过程]({{< ref "/blog/history-of-tzf/index.zh-cn.md" >}})。此后项目也有一些更新和维护，但主要集中在非核心功能优化和辅助功能补充上。

到了 2026 年春天，之前几个悬而未决的重要改动陆续完成了：

1. 引入拓扑感知机制，解决多边形简化过程中额外引入的空隙和重叠问题；
2. 基于拓扑感知机制，开发更高效的数据分发格式，完整精度数据约 17MB，简化数据约 5.4MB；
3. 参考 tidwall/tg 项目，引入 YStripes 索引加速。

## 拓扑感知机制

原始数据本质上是一组多边形。由于原始边界过于精细，数据体积很大，所以需要对多边形进行简化处理。这些多边形之间存在大量共享边界，但在之前的处理中，每个多边形都是各自独立进行 RDP 简化。这就带来了 tzf 系列项目从上线开始就存在的[问题](https://github.com/ringsaturn/tzf/issues/183)：原本完整覆盖的区域，在简化后出现了空隙，以及本不该有的多边形重叠：

![See details in [`ringsaturn/tzf#183`](https://github.com/ringsaturn/tzf/issues/183)](https://blog-assets.ringsaturn.me/pic/tzf-spring-news/issue_183.webp)

解决方案几年前就已经明确：先识别共享边界，再对共享边界进行简化，最后把简化后的边界替换回两侧多边形。这样可以保证相邻多边形继续引用同一条简化后的边界，从而避免因为两侧独立简化而产生新的空隙或重叠。

但是数据量确实很大。过去几年我多次尝试手动实现这个策略，最终都失败了。各种边缘情况和复杂的策略设计不断叠加，最后都会让代码无法稳定运行。

2026 年再次尝试解决这个问题时，我借助 Claude 和 Codex 做了多轮实现、验证和重构，最终把这套策略完整实现了。大致流程可以参考下面这张策略说明图：

![Made by ChatGPT](https://blog-assets.ringsaturn.me/pic/tzf-spring-news/topology_algo.zh.webp)

这个策略实现之后，也就具备了实现去年设计的[新数据存储格式目标](https://github.com/ringsaturn/tzf/issues/191)的基础。

为了维持向前兼容，新的二进制数据被拆分到了新的仓库中，用于承载下文提到的格式优化。原有的数据格式分发，也就是 tzf-rel 系列，还会继续维持一段时间，之后再准备停止运行。

既然已经可以识别共享边界，那么冗长的边界就没有必要存储两遍，只需要存储一次，再使用 polyline 进行编码压缩。

这个策略的效果非常明显。tzf 系列项目此前使用 pb 格式分发完整数据集，不做 zip 压缩大约 90MB，zip 后大约 50MB。现在共享边界只存储一次，并经过 polyline 编码压缩，完整精度数据约 17MB，再做 zip 压缩后约 10MB。完整精度数据能压缩到这个体积，我自己还是比较满意的。也正是因为这个体积已经可以接受，tzf-rs 终于开始提供可选 feature 来支持完整数据集了。在此之前，受限于 90MB 的庞大体积，完整数据集只能让用户自行下载并提供访问路径。

对于简化后的数据集，如果不做 polyline 压缩，体积还会轻微膨胀。原因是此前有很多小的多边形细节会被直接抹去，现在引入了新的判定条件，出于精度考虑保留了大量细小多边形细节。另一方面，因为边界本身已经被大幅简化，共享边界只存储一份带来的优化效果也没有完整精度数据那么显著。目前引入共享边界识别和 polyline 处理后，简化数据集大约 5.4MB，仍然可以接受。

不过这里还是要提一句，tzf 系列项目使用完整精度数据时，运行过程中需要的内存在 500MB 左右，这个占用还是很大，暂时没有进一步优化的计划，并且这个功能暂时不会下放到 Python binding 中。即使使用简化数据集，也需要约 100MB 内存。tzf 系列项目，特别是 Go、Rust、Python 三个版本，设计之初就是为了服务高并发后端 API 场景，可以接受一定的内存占用，换取几乎无感的处理耗时，同时边界精度也不能过度简化。在这个场景下，内存占用、处理速度、数据精度需要一起权衡。具体用什么、怎么用，还是要以各自的实际情况为准。

具体的功能可以参考代码的文档 [`internal/topology/README.md`](https://github.com/ringsaturn/tzf/blob/v1.1.0/internal/topology/README.md)。

目前的数据文件列表如下：

| 文件名                                            | 大小   | 说明                                                |
| ------------------------------------------------- | ------ | --------------------------------------------------- |
| `combined-with-oceans.compress.topo.bin`          | ~17MB  | 完整精度：共享边界去重 + polyline 压缩              |
| `combined-with-oceans.topology.compress.topo.bin` | ~5.4MB | 简化版：拓扑感知简化 + 共享边界去重 + polyline 压缩 |
| `combined-with-oceans.topology.preindex.bin`        | ~2MB   | FuzzyFinder 使用的瓦片预索引                        |

## YStripes 索引

首先声明，YStripes 索引不是我发明的，它来自 Josh Baker 此前发布的 [`tidwall/tg`](https://github.com/tidwall/tg) 项目。只是将这个索引机制移植到了 tzf 的 Go 和 Rust 版本中。

从这个春天开始，这个索引已经成为 tzf 的 Go 和 Rust 版本的默认策略。它确实增加了一些内存占用，但性能收益更明显。在我的本地 benchmark 中，单次随机查询已经降到 1 微秒左右，基本不会构成我已知使用场景中的性能瓶颈。

对应的算法原理这里就不展开了，感兴趣可以直接阅读作者的说明文档 [`POLYGON_INDEXING.md`](https://github.com/tidwall/tg/blob/main/docs/POLYGON_INDEXING.md)。

## Benchmark

这里简单展示一下我本地的 benchmark 结果。测试设备是 MacBook Pro with Apple M3 Max。

以下结果主要用于观察不同策略之间的相对差异，不建议直接作为跨机器的绝对性能结论。

### tzf(Go)

| Target        | Dataset                        | Scenario                               | Median (ns) | p99 (ns) | Approx throughput (ops/s) | Memory (MiB) |
| ------------- | ------------------------------ | -------------------------------------- | ----------: | -------: | ------------------------: | -----------: |
| DefaultFinder | topology-simplified + preindex | edge case · GetTimezoneName            |      3000.0 |   3000.0 |                    393.5K |        74.70 |
| Finder        | topology-simplified            | edge case · GetTimezoneName            |      2000.0 |   3000.0 |                    470.4K |        66.00 |
| FullFinder    | full-precision + preindex      | edge case · GetTimezoneName            |      3000.0 |   3000.0 |                    395.6K |       421.50 |
| Finder        | full-precision                 | edge case · GetTimezoneName            |      2000.0 |   3000.0 |                    475.3K |       412.70 |
| DefaultFinder | topology-simplified + preindex | random world cities · GetTimezoneName  |      1000.0 |   4000.0 |                   1162.4K |        74.70 |
| FuzzyFinder   | preindex                       | random world cities · GetTimezoneName  |       469.8 |   1000.0 |                   2128.6K |         8.90 |
| Finder        | topology-simplified            | random world cities · GetTimezoneName  |      2000.0 |   4000.0 |                    531.6K |        66.00 |
| FullFinder    | full-precision + preindex      | random world cities · GetTimezoneName  |      1000.0 |   4000.0 |                   1143.1K |       421.50 |
| Finder        | full-precision                 | random world cities · GetTimezoneName  |      2000.0 |   5000.0 |                    468.6K |       412.70 |
| DefaultFinder | topology-simplified + preindex | random world cities · GetTimezoneNames |      5000.0 |   9000.0 |                    208.0K |        74.70 |
| FuzzyFinder   | preindex                       | random world cities · GetTimezoneNames |       462.7 |   1000.0 |                   2161.2K |         8.90 |
| Finder        | topology-simplified            | random world cities · GetTimezoneNames |      5000.0 |   8000.0 |                    211.5K |        66.00 |
| FullFinder    | full-precision + preindex      | random world cities · GetTimezoneNames |      5000.0 |   9000.0 |                    192.8K |       421.50 |

### tzf-rs(Rust)

Topology-Simplified (bundled):

| Target        | Dataset                        | Scenario      | Median estimate (µs) | Approx throughput (ops/s) | Avg peak RSS (MiB) |
| ------------- | ------------------------------ | ------------- | -------------------: | ------------------------: | -----------------: |
| Finder        | topology-simplified            | YStripes only |               1.2296 |                   813,273 |             103.30 |
| Finder        | topology-simplified            | No index      |               6.5402 |                   152,901 |              51.68 |
| DefaultFinder | topology-simplified + preindex | YStripes only |               1.1383 |                   878,503 |             125.98 |
| DefaultFinder | topology-simplified + preindex | No index      |               2.2514 |                   444,168 |              77.79 |

Full-Precision (full):

| Target               | Dataset                   | Scenario      | Median estimate (µs) | Approx throughput (ops/s) | Avg peak RSS (MiB) |
| -------------------- | ------------------------- | ------------- | -------------------: | ------------------------: | -----------------: |
| Finder (full)        | full-precision            | YStripes only |               2.0852 |                   479,570 |             561.08 |
| Finder (full)        | full-precision            | No index      |              37.6980 |                    26,527 |             252.54 |
| DefaultFinder (full) | full-precision + preindex | YStripes only |               1.3488 |                   741,400 |             584.30 |
| DefaultFinder (full) | full-precision + preindex | No index      |              11.2750 |                    88,692 |             278.63 |

### Python

Python 本身主要是 binding，这里就不贴 benchmark 结果了。不过值得一提的是，whl 体积从 7MB 左右降到了 4MB 左右，也算是对镜像构建产物的一点小优化。

### Continuous Benchmark in GitHub Actions

下面是利用 [Continuous Benchmark](https://github.com/marketplace/actions/continuous-benchmark) 监控的长期性能指标：

![tzf ns/op](https://blog-assets.ringsaturn.me/pic/tzf-spring-news/benchmark-tzf.webp)

![tzf-rs ns/iter](https://blog-assets.ringsaturn.me/pic/tzf-spring-news/benchmark-tzf-rs.webp)

![tzf iter/sec](https://blog-assets.ringsaturn.me/pic/tzf-spring-news/benchmark-tzfpy.webp)

## End

以上就是这个春天密集完成的主要功能。对 tzf 系列项目来说，这次更新也算是补上了最早设计里的关键功能：用 Go 完成拓扑感知的多边形数据集简化和分发，再让 Go、Rust、Python 等不同语言版本直接复用同一套数据结果。

后续维护工作会相对轻一些，主要集中在数据文件更新、项目依赖更新和少量接口兼容工作上。

上述的开发分散在不同时间段，对应的 release 参考：

- https://github.com/ringsaturn/geometry-rs/releases/tag/v0.4.1
- https://github.com/ringsaturn/tzf-rs/releases/tag/v1.2.0
- https://github.com/ringsaturn/tzf-rs/releases/tag/v1.3.0
- https://github.com/ringsaturn/tzfpy/releases/tag/v1.2.0
- https://github.com/ringsaturn/tzfpy/releases/tag/v1.3.0
- https://github.com/ringsaturn/tzf/releases/tag/v1.1.0
- https://github.com/ringsaturn/tzf-dist/releases/tag/v0.0.2026-a
