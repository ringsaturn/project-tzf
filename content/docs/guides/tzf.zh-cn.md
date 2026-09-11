---
date: '2025-07-21T12:14:46+09:00'
description: Go 版 tzf（v2）的最佳实践和高级用法模式。
draft: false
lastmod: '2026-09-11T00:00:00+09:00'
seo:
  description: Go tzf v2 库的最佳实践：五个构造函数、查找器复用、GeoJSON 导出、原地查询，以及从 v1 迁移。
  noindex: false
  title: 'Go (tzf) 指南 - Project tzf'
summary: tzf v2 在 Go 中的构造函数选择、查找器复用、GeoJSON 导出、原地字节查询，以及 v1 到 v2 的迁移对照表。
title: Go (tzf)
toc: true
weight: 2
---

## 安装

tzf v2 是新的主版本，因此模块路径带有 `/v2` 后缀：

```bash
go get github.com/ringsaturn/tzf/v2
```

```go
import "github.com/ringsaturn/tzf/v2"
```

包名仍为 `tzf`。v2 不再使用 protobuf：边界数据以 `.tzb`（紧凑的传输 profile）和 `.tzm`（内存镜像 profile）文件的形式来自 [`ringsaturn/tzf-dist`](https://github.com/ringsaturn/tzf-dist)，通过 `go:embed` 嵌入。文件格式本身参见[嵌入式二进制格式]({{< relref "../reference/embedded-binary-format" >}})。

## 五个构造函数

每个构造函数都返回 [`F`](#the-f-interface) 接口。该包不导出查找器类型，也不提供选项。

| 构造函数 | 数据 | 常驻 | 查询 |
| --- | --- | --- | --- |
| `NewDefaultFinder()` | lite `.tzm` 内存镜像，多边形原地引用 | ~12 MB 堆 + ~10 MB 只读数据 | 298 ns |
| `NewEmbeddedFinder()` | lite `.tzb`，原地查询 | ~3 MB（文件字节加上不足 1 KB 的堆） | 预索引命中时 p50 为 542 ns，未命中时约 6 µs |
| `NewFullFinder()` | full `.tzb`，加载时展开 | ~145 MB | ~300 ns |
| `NewFinderFromTZB(data)` | 自行提供的 `.tzb` 字节，始终展开 | 取决于文件（lite 约 27 MB） | ~290 ns |
| `NewFinderFromTZM(data)` | 自行提供的 `.tzm` 字节，始终原地引用 | 同一文件下与 `NewDefaultFinder` 相同 | ~300 ns |

在 Apple M3 Max 上针对 `2026c` 数据集测得。

包文档把 `NewDefaultFinder()` 列为通用查找器。其余场景，包括无文件系统的目标、cgroup 配额 Pod 和分发体积，参见[选择查找器]({{< relref "choosing-a-finder" >}})。

## 复用查找器

相对于一次查询，构造开销较大：它要打开文件、建立查询结构，对展开型查找器还要解码全部多边形。查找器可并发使用，因此进程构建一个并复用。使用包级变量是一种做法：

```go {hl_lines=["9"]}
package main

import (
	"fmt"

	"github.com/ringsaturn/tzf/v2"
)

var f tzf.F

func init() {
	var err error
	f, err = tzf.NewDefaultFinder()
	if err != nil {
		panic(err)
	}
}

func main() {
	// 坐标采用 (经度，纬度) 顺序。
	fmt.Println(f.GetTimezoneName(116.3883, 39.9289))
	fmt.Println(f.GetTimezoneName(-73.935242, 40.730610))
}
```

## `F` 接口

```go
type F interface {
	GetTimezoneName(lng float64, lat float64) string
	GetTimezoneNames(lng float64, lat float64) ([]string, error)
	TimezoneNames() []string
	DataVersion() string
}
```

- **`GetTimezoneName`：** 预索引优先。每个 tzf-dist 产物都带有 FUZZY 预索引区段，因此瓦片查找可以在不做点在多边形内判定的情况下回答大部分查询；边界附近则回退到射线法。无匹配时该方法返回空字符串。
- **`GetTimezoneNames`：** 在所有查找器中都走多边形精确路径。它不查询预索引，适用于点可能属于多个时区的场景。结果按字典序排序，无匹配时返回 `tzf.ErrNoTimezoneFound`。
- 共享边界上的点属于所有与之相接的多边形。海上时区边界位于整数经线上，例如 7.5° 和 22.5°。

```go
names, err := f.GetTimezoneNames(87.4160, 44.0400)
// names == []string{"Asia/Shanghai", "Asia/Urumqi"}
```

## GeoJSON 导出

`GeoJSONer` 不放入 `F`，这样测试替身和第三方 `F` 实现无需产出几何数据。本包构建的每个查找器都实现了它，因此在构造函数返回的值上做接口断言：

```go
finder, err := tzf.NewDefaultFinder()
if err != nil {
	panic(err)
}

g := finder.(tzf.GeoJSONer)

world := g.GetGeoJSON()                          // []byte，全部时区
tokyo, err := g.GetTZGeoJSON("Asia/Tokyo")       // []byte，单个时区
tiles, err := g.GetTZPreindexGeoJSON("Asia/Tokyo") // 单个时区的 FUZZY 瓦片
all, err := g.GetPreindexGeoJSON()               // 整个 FUZZY 预索引
```

四个方法都返回序列化后的 GeoJSON 字节，边界文件类型是模块内部类型。预索引导出覆盖的是 `GetTimezoneName` 直接由预索引作答、无需回退到点在多边形内判定的区域。文件不含 FUZZY 区段时返回 `tzf.ErrNoFuzzySection`。

## 使用自行提供的字节

从磁盘、对象存储或自己的 `go:embed` 读取文件，然后按 profile 选择对应的构造函数：

```go
data, err := os.ReadFile("lite.tzb")
if err != nil {
	panic(err)
}
finder, err := tzf.NewFinderFromTZB(data) // 展开；data 之后可以释放
```

```go
data, err := os.ReadFile("lite.tzm")
if err != nil {
	panic(err)
}
finder, err := tzf.NewFinderFromTZM(data) // 原地引用；data 必须保持存活
```

`.tzm` 查找器的环切片直接引用源字节，这些字节在查找器的生命周期内必须保持存活且不被修改。

M profile 由使用它的主机从 `.tzb` 文件生成：

```bash
# usage: tzb2tzm [-o output] input.tzb
go run github.com/ringsaturn/tzf/v2/cmd/tzb2tzm@latest lite.tzb
```

## 对调用方持有字节的原地查询

`x.NewFinderFromTZBReaderAt` 通过 `io.ReaderAt` 查询 `.tzb`，来源可以是文件、`mmap` 映射区域、嵌入式 flash 适配层，或对已持有字节的 `bytes.Reader`。查询过程不分配内存，堆开销保持在 1 KB 以内：

```go
import (
	"bytes"

	"github.com/ringsaturn/tzf/v2/x"
)

finder, err := x.NewFinderFromTZBReaderAt(bytes.NewReader(data), int64(len(data)))
if err != nil {
	panic(err)
}
fmt.Println(finder.GetTimezoneName(151.2093, -33.8688))
```

`x` 包不在该模块的语义化版本承诺范围内：次版本号变更即可能修改或移除其 API。根包只在主版本号变更时发生不兼容变更。

## 从 v1 迁移

v1（`github.com/ringsaturn/tzf`，最新为 v1.2.x）仍然可用。它冻结在最后一个 protobuf 数据版本上：v2 产物发布后，tzf-dist 不再发布 `.bin` 产物。

| v1 | v2 |
| --- | --- |
| `go get github.com/ringsaturn/tzf` | `go get github.com/ringsaturn/tzf/v2` |
| `tzf.NewDefaultFinder()` | `tzf.NewDefaultFinder()`，现读取 lite `.tzm` 内存镜像 |
| `tzf.NewFullFinder()` | `tzf.NewFullFinder()`，现读取展开后的 full `.tzb` |
| `tzf.NewFuzzyFinderFromPB(...)` | 已移除；FUZZY 快速路径内置于每个带该区段的查找器中 |
| `tzf.NewFinderFromCompressedTopo(...)`、`NewFinderFromCompressed(...)`、`NewFinderFromPB(...)` | `tzf.NewFinderFromTZB(data)` 或 `tzf.NewFinderFromTZM(data)`，参数为普通 `[]byte`，不涉及 protobuf 消息 |
| `tzf.NewFinderFromRawJSON(...)` | 已移除；改用管线命令行工具构建 `.tzb` |
| `tzf.Finder`、`tzf.FuzzyFinder`、`tzf.DefaultFinder`（导出的结构体） | 已移除；所有构造函数返回 `tzf.F` |
| `tzf.Option` / `tzf.OptionFunc` / `tzf.SetDropPBTZ` | 已移除；v2 没有选项 |
| 返回 `*convert.BoundaryFile` 的 `finder.GetGeoJSON()` | `finder.(tzf.GeoJSONer).GetGeoJSON()`，返回 `[]byte` |
| `github.com/ringsaturn/tzf/gen/go/tzf/v1`（protobuf 类型） | 已移除；v2 中不存在 protobuf |
| `reduce`、`preindex`、`convert.Do`（导出的管线包） | 已内部化；通过 `cmd/` 下的命令行工具驱动管线 |
| tzf-dist 的 `.bin` 文件 | `lite.tzb`、`lite.tzm`、`full.tzb` |

`F` 的四个方法没有变化，因此只调用 `GetTimezoneName` / `GetTimezoneNames` / `TimezoneNames` / `DataVersion` 的代码，除了修改导入路径之外无需改动。

### 边界语义

v2 对落在边上的查询的处理方式，与 v1 在 [tzf#216](https://github.com/ringsaturn/tzf/issues/216) 之后一致：共享边界上的点属于所有与之相接的多边形，外环允许点落在边上视为包含，内环不允许。锁定在更早 v1 补丁版本上的代码，会看到此前返回空结果的边界点开始返回名称。
