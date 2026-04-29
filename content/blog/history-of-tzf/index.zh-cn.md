---
author: ringsaturn
authorTwitter: ringsaturn_me
cover:
  image: https://blog-assets.ringsaturn.me/pic/tzf-post-cover.webp
date: '2023-01-31'
description: 介绍 tzf 的演进过程，从最初的 Go 实现到后来的 Python 扩展，再到现在的 Rust 实现，以及 PyO3 的封装。
lastmod: '2025-04-29'
math: true
post_pdf_url: https://blog-assets.ringsaturn.me/pdf/2023-01-31-history-of-tzf.pdf
summary: 介绍 tzf 的演进过程，从最初的 Go 实现到后来的 Python 扩展，再到现在的 Rust 实现，以及 PyO3 的封装。
tags:
- Python
- Go
- Geo
- Timezone
- Rust
- PyO3
- Geometry
- Caiyun
- tzf
- tzfpy
- tzf-rs
title: tzf 的演进过程
toc: true
---

tzf
及相关项目的基础开发工作基本稳定了，在之前的文章零星有些开发和设计过程的资料:

- 2022-05-29,
  [在 Go 中将经纬度转时区](https://blog.ringsaturn.me/posts/timezone-go/)
- 2022-08-01,
  [Python 中经纬度转时区新的选择](https://blog.ringsaturn.me/posts/tzfpy/)
- 2022-08-27,
  [用 Go 编写 Python 扩展](https://blog.ringsaturn.me/posts/py-ext-go/)
- 2022-09-10,
  [tzf 预览图制作](https://blog.ringsaturn.me/posts/tzf-social-media/)
- 2022-11-24,
  [tzfpy Rust 重写](https://blog.ringsaturn.me/posts/tzfpy-tzfpy-rust/)

这一篇是最终的总结，从项目的启动到逐步优化和演进的过程。

---

目前在用的经纬度转时区的库是
[timezonefinder](https://github.com/jannikmi/timezonefinder)
目前使用的问题是多边形边缘会比较慢，在之前的版本中多边形边缘的查询可能需要 200ms
甚至 800ms， 在
[timezonefinder@6.1.0](https://github.com/jannikmi/timezonefinder/blob/master/CHANGELOG.rst#610-2022-08-15)
版本中切换到了 C 实现的 Ray Cast
算法上，但还是不那么稳定，最快与最慢之间的耗时差距比较大，
于是尝试自己开发一个经纬度转时区的包库。

在之前的[行政区划数据处理][lnglat2adcode]中已经了解了 Point in Polygon 问题以及
Ray Casting 算法。 所以问题就缩小到了数据从哪里来。 感谢开源社区的力量，有个
[timezone-boundary-builder](https://github.com/evansiroky/timezone-boundary-builder)
项目会大体跟随 [Timezone Database](https://www.iana.org/time-zones)
的更新而发布最新的时区多边形信息（但是作者不保证每次数据库的更新都会跟随发布）。
在 GitHub Release 中，作者会同时发布 GeoJSON 和 ShapeFile 两种格式的数据文件。

[lnglat2adcode]: https://blog.ringsaturn.me/posts/geo-computing-2/

采用了 GeoJSON 做处理。 这个文件压缩后 45MB 左右，解压缩后
155MB，对于项目而言太大了，所以第一个问题就是如何降低数据体积。

一个最简单的思路就是用效率更高的二进制编码格式存储，团队对 Protocol Buffers
比较熟悉， 也就编写了 [`tzinfo.proto`][tzpb] 文件。需要注意的是在 GeoJSON 的定义
[RFC 7946][rfc7946] 中 Polygon
是很多曲线形状，其中第一个表示的多边形的外部形状，
其余的都是内部形状，即多边形中间的洞。 这类数据用 proto 语法是
`repeated repeated Point`，这是不被 Protocol Buffers 支持的定义。
需要拆成两个字段才能表示：

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

[tzpb]: https://github.com/ringsaturn/tzf/blob/main/pb/tzf/v1/tzinfo.proto
[rfc7946]: https://www.rfc-editor.org/rfc/rfc7946

经过处理后文件体积降低了 80MB 左右。 这部分数据完整加载到内存里大约需要 900MB
左右，体积太大了，需要再降低。 如果细看 GeoJSON
文件里的坐标会发现他们的点间距是比较密的，但是实际业务中不需要那么高的精度。
所以第一个优化策略就是降低点的数据量。

那么怎么有效降低多边形散点数量呢？在这个领域里最常用的算法是
[Ramer–Douglas–Peucker algorithm](https://en.wikipedia.org/wiki/Ramer–Douglas–Peucker_algorithm):

![The effect of varying epsilon in a parametric implementation of RDP, [source](https://en.wikipedia.org/wiki/File:RDP,_varying_epsilon.gif)](https://blog-assets.ringsaturn.me/pic/RDP_varying_epsilon.gif)

如 GIF 图片展示所示，一个复杂的曲线可以在保持大致形状的前提下简化到更少的点。
经过算法的过滤，文件的体积降低到了 11MB。

做到这里在想，11MB
的二进制文件放到各种二进制分发场景里是不是还是有点大，于是调研了一下坐标数据压缩的方案，
发现 [Polyline] 是比较合适的。 这是 Google Maps
压缩连续坐标的算法，原理是除了第一个点以外点，全部存储成相对于上一个点的偏移量，
然后将偏移量通过位运算取出对二进制序列做运算后处理成 ASCII。
经过一通数据处理，时区多边形数据文件压缩到了
4.6MB，对于二进制分发而言已经非常友好。

[polyline]: https://developers.google.com/maps/documentation/utilities/polylinealgorithm

其实做到这里一个能用的时区库就已经诞生了，查询性能上已经比 timezonefinder
略快了。
但是正如上一节提到的，业务需求场景要面对高并发的流量压力，这部分的执行频次又非常高，越快越好。
由于用了 Ray casting 算法，时间复杂度在 $O(n^2)$
比较慢，所以期望这部分执行的频次要尽可能低，所以开始设计时区的索引机制。

按照行政区划的处理经验，这里应该启用 RTree，避免遍历所有的多边形。
但是在全球城市数据的 benchmark 中并没有太好的收益。 原因有两个：

1. 时区的总数量并不大，只有几百个，和行政区划数千个相比差了 10 倍。
   在静态语言里这个量级的遍历对性能影响还不构成绝对大头。
2. 行政区划的多边形之间的面积区别不是很大，但是时区的多边形差距很大。
   搜索范围设置小了会找不大时区信息，调大了又起不到明显降低搜索数量的作用。

所以 RTree 并不太适合。

那么怎么构造时区的索引数据呢？ 10
月底时候我在想，既然多边形能用外嵌的四边形模糊匹配，那能否用内镶多边形表示近似的形状？
之前在行政区划上用 Uber H3 做过类型的事情， 但是因为 H3
的父节点不能完整包含子节点会留下太多的真空地带，效果并不好。
于是目光转向了[气象站数据查询][geo-computing-1]用的地图瓦片格式。

[geo-computing-1]: https://blog.ringsaturn.me/posts/geo-computing-1/

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

说来神奇，还真行，是能表示一定的形状信息的。 而且瓦片因为设计上采用了
QuadTree（四叉树），父节点恰好包含 4 个子节点，
可以利用小瓦片聚合，不用担心有遗留的区域：

![](https://blog-assets.ringsaturn.me/pic/geo-computing/preindex-timezone-preview-we.webp)

<!-- ## Go 实现 -->

---

在最开始，这个时区项目是在 Go 中尝试实现的，项目在 MIT License 下开源
[tzf](https://github.com/ringsaturn/tzf)。
上文提到的数据时区数据转换、降低数据量、压缩、构造索引的功能都是命令行工具， 在
[tzf/cmd] 目录下， 构造好的二进制数据文件则发布在 [tzf-rel] 仓库中，利用 Go 的
`embed` 机制发布。

[tzf/cmd]: https://github.com/ringsaturn/tzf/tree/main/cmd
[tzf-rel]: https://github.com/ringsaturn/tzf-rel

Go 里都就绪之后尝试用 CGO 打包成 `.so` 文件供 Python 调用。 利用 [cibuildwheel]
构建各个平台的 wheel 避免安装的时候再走编译。
基本的测试用下来没有什么问题，就是发现需要手动回收返回的对象，否则会发生内存泄漏
[tzf#63]。 但是在 Python 侧调用 CGO
的回收方法会导致程序某些情况的执行速度慢一倍左右。 在想有没有更优雅的方式呢？

[cibuildwheel]: https://github.com/pypa/cibuildwheel
[tzf#63]: https://github.com/ringsaturn/tzf/pull/63

将目光转向了 Rust，这门语言有 [PyO3](https://github.com/PyO3/pyo3) 和
[Maturin](https://github.com/PyO3/maturin) 这样的好工具能直接打包成 Python
包库， 也不用手动回收对象，并且在之前做的一些 benchmark 中发现 CPU 密集型场景
Rust 比 Go 会快一些。

于是开始用 Rust 实现 tzf 里的数据文件加载、构造地图索引、多边形搜索等事情。
基本还是顺利的，比如开源的 [georust/geo](https://github.com/georust/geo)
有非常丰富的地理计算功能。

结果在时区数据处理上，耗时 1700000 ns，而在 Go 里一般在 12000 ns，慢了 100
多倍。 这个问题大概率是算法实现的效率问题，所以经过了一个下午和编译器的报警， 将
Go 里用的地理计算功能移植到了 Rust 中，项目是 [geometry-rs]。 重新运行了
benchmark，

[geometry-rs]: https://github.com/ringsaturn/geometry-rs

结果耗时 3300000 ns，更慢了。

原因在哪里呢？
首先做了尝试，在循环遍历的时候尽量不迭代对象，而是用索引值去取，至少在 Go
里这个是有一定优化空间的。 想试一下，结果没有什么波动。
然后偶然间注意到了当时因为和 Rust 编译器大战各种报错的时候，
图省事直接将点序列用了 `to_owned` 向函数传递，而这个对象很大，有几百万个点。
将这一步[替换成指针][fix_vec]，性能立刻就上来了，大约 30000 ns， 因为原始的的 Go
实现在多边形数据内部还额外构造了一层预索引， 而 Rust
并没有实现这部分功能，所以慢一些是可以接受的。

[fix_vec]: https://github.com/ringsaturn/geometry-rs/commit/925593c825dcbe0a704f65802b6e541b85108771

在 Rust 实现性能稳定之后开始用 PyO3 封装 Python 库 [tzfpy]，整个过程还算顺利，
用了 lazy init 来初始化全局的 Finder
实现，所以第一次调用会比较慢，之后就很快了。

[tzfpy]: https://github.com/ringsaturn/tzfpy

安装及使用：

```bash
pip install tzfpy
```

```python
>>> from tzfpy import get_tz
>>> print(get_tz(116.3883, 39.9289))
```

目前 tzf-rs&tzfpy 用的还是没有用 Polyline
压缩的数据，后续会切换过去，能进一步压缩二进制的体积。
