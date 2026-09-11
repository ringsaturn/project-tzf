---
date: '2025-07-19T12:19:49+09:00'
description: 使用 Go、Rust、Python、Swift、Ruby、Wasm 等语言安装并运行 Project tzf。
draft: false
lastmod: '2026-09-11T00:00:00+09:00'
seo:
  description: 使用 Go、Rust、Python、Swift、Ruby、WebAssembly 安装并运行 GPS 坐标到时区查询，也可通过 HTTP API 调用。
  title: '快速开始 - Project tzf'
summary: 支持语言和服务的快速安装与使用示例。
title: 快速开始
toc: true
weight: 1
---

Project tzf 支持多种语言和服务，可根据经纬度查询时区。

| 语言或服务              | 仓库                                                                    | API 文档                                                                                                    |
| ----------------------- | ----------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| Go                      | [`ringsaturn/tzf`](https://github.com/ringsaturn/tzf)                   | [![](https://pkg.go.dev/badge/github.com/ringsaturn/tzf.svg)](https://pkg.go.dev/github.com/ringsaturn/tzf) |
| Rust                    | [`ringsaturn/tzf-rs`](https://github.com/ringsaturn/tzf-rs)             | [![](https://docs.rs/tzf-rs/badge.svg)](https://docs.rs/tzf-rs)                                             |
| Python                  | [`ringsaturn/tzfpy`](https://github.com/ringsaturn/tzfpy)               | [`tzfpy.pyi`](https://github.com/ringsaturn/tzfpy/blob/main/tzfpy.pyi)                                      |
| Swift                   | [`ringsaturn/tzf-swift`](https://github.com/ringsaturn/tzf-swift)       | [![][swift_doc_badge]][swift_doc_url]                                                                        |
| Ruby                    | [`HarlemSquirrel/tzf-rb`](https://github.com/HarlemSquirrel/tzf-rb)     |                                                                                                             |
| JS (浏览器 Wasm)        | [`ringsaturn/tzf-wasm`](https://github.com/ringsaturn/tzf-wasm)         |                                                                                                             |
| HTTP API                | [`racemap/rust-tz-service`](https://github.com/racemap/rust-tz-service) |                                                                                                             |
| 在线演示                | [`ringsaturn/tzf-web`](https://github.com/ringsaturn/tzf-web)           |                                                                                                             |

[swift_doc_url]: https://swiftpackageindex.com/ringsaturn/tzf-swift
[swift_doc_badge]: https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fringsaturn%2Ftzf-swift%2Fbadge%3Ftype%3Dswift-versions

## Go

tzf v2 是新的主版本，因此模块路径带有 `/v2` 后缀：

```bash
go get github.com/ringsaturn/tzf/v2
```

```go
package main

import (
	"fmt"

	"github.com/ringsaturn/tzf/v2"
)

func main() {
	// 相对于一次查询，构造开销较大，查找器只构建一次。
	finder, err := tzf.NewDefaultFinder()
	if err != nil {
		panic(err)
	}
	// 坐标采用 (经度，纬度) 顺序。
	fmt.Println(finder.GetTimezoneName(116.6386, 40.0786))
}
```

共有五个构造函数，全部返回 `tzf.F` 接口：

| 构造函数 | 适用场景 |
| --- | --- |
| `NewDefaultFinder()` | 通用场景：lite 内存镜像，~12 MB 堆 + 10 MB 只读数据，查询 298 ns |
| `NewEmbeddedFinder()` | 嵌入式和内存受限目标：合计约 3 MB，查询为微秒级 |
| `NewFullFinder()` | 结果与完整精度数据集一致（~145 MB） |
| `NewFinderFromTZB(data)` | 调用方提供的 `.tzb` 字节，加载时展开 |
| `NewFinderFromTZM(data)` | 调用方提供的 `.tzm` 字节，原地引用 |

以上数据在 Apple M3 Max 上针对 `2026c` 数据集测得。

如需 100% 准确的结果，请使用 `NewFullFinder`。该实例初始化开销较大，建议尽可能复用：

```go
package main

import (
	"fmt"

	"github.com/ringsaturn/tzf/v2"
)

func main() {
	finder, err := tzf.NewFullFinder()
	if err != nil {
		panic(err)
	}
	fmt.Println(finder.GetTimezoneName(139.6917, 35.6895))
}
```

GeoJSON 导出、对自行提供字节的原地查询，以及 v1 到 v2 的迁移对照表，参见 [Go 指南]({{< relref "guides/tzf" >}})。

## Rust

```bash
cargo add tzf-rs
```

```rust
use std::sync::LazyLock;
use tzf_rs::DefaultFinder;

static FINDER: LazyLock<DefaultFinder> = LazyLock::new(DefaultFinder::new);

fn main() {
    // 坐标采用 (经度，纬度) 顺序。
    print!("{:?}\n", FINDER.get_tz_name(116.3883, 39.9289));
    print!("{:?}\n", FINDER.get_tz_names(116.3883, 39.9289));
}
```

tzf-rs 2.0 提供两个查找器：`DefaultFinder`（默认，峰值 RSS 约 47 MiB，随机城市查询 229 ns），以及 `EmbeddedFinder`，后者原地查询嵌入的文件，占用约 10 MiB，延迟为微秒级。两者的数据来自 [tz-benchmark](https://github.com/ringsaturn/tz-benchmark) 的 2026-09-11 快照，在 Apple M3 Max 上针对 `2026c` 数据集测得。

<details>
<summary>完整精度支持</summary>

可通过可选 Cargo feature 使用完整精度数据。由于完整数据集约 14 MB，超出 crates.io 的大小限制，需要通过 git 依赖引用，并且它与内置的 lite 数据集互斥：

```toml
[dependencies]
tzf-rs = { git = "https://github.com/ringsaturn/tzf-rs", rev = "v{X}.{Y}.{Z}", features = ["full"], default-features = false }
```

```rust
use tzf_rs::DefaultFinder;

fn main() {
    let finder = DefaultFinder::new_full();
    let tz_name = finder.get_tz_name(139.767125, 35.681236);
    println!("tz_name: {}", tz_name);
}
```

</details>

## Python

```bash
# 只安装 tzfpy
pip install tzfpy

# 安装 pytz 支持
pip install "tzfpy[pytz]"

# 安装 tzdata 支持
pip install "tzfpy[tzdata]"

# 通过 conda 安装
conda install -c conda-forge tzfpy
```

```python
>>> from tzfpy import get_tz, get_tzs
>>> get_tz(116.3883, 39.9289)   # (经度，纬度) 顺序
'Asia/Shanghai'
>>> get_tzs(87.4160, 44.0400)   # 返回全部匹配时区
['Asia/Shanghai', 'Asia/Urumqi']
```

tzfpy 2.0 需要 Python 3.10 或更高版本，绑定 tzf-rs 2.0。它还提供 `timezonenames()`、`data_version()`、`get_tz_polygon_geojson(name)` 和 `get_tz_index_geojson(name)`。Python 版本不提供完整精度模式。

## Swift

截至 2026-09-10，Swift、Ruby 和浏览器 Wasm 绑定基于 v1 系列构建。tzf-rb 由 [HarlemSquirrel](https://github.com/HarlemSquirrel) 独立维护。

将包添加到你的 `Package.swift`：

```swift
dependencies: [
    .package(url: "https://github.com/ringsaturn/tzf-swift.git", from: "{latest_version}")
]
```

```swift
import Foundation
import tzf

do {
    let finder = try DefaultFinder()

    let timezone = try finder.getTimezone(lng: 116.3833, lat: 39.9167)
    print("北京时区：", timezone)

    let timezones = try finder.getTimezones(lng: 87.5703, lat: 43.8146)
    print("可能存在的多个时区：", timezones)

    print("数据版本：", finder.dataVersion())
} catch {
    print("错误：", error)
}
```

## Ruby

Ruby 版本由 [HarlemSquirrel](https://github.com/HarlemSquirrel) 创建并维护。
详细用法请参见 [tzf-rb](https://github.com/HarlemSquirrel/tzf-rb)。

```bash
bundle add tzf
# 或
gem install tzf
```

```ruby
require 'tzf'

TZF.tz_name(40.74771675713742, -73.99350390136448)
# => "America/New_York"

TZF.tz_names(40.74771675713742, -73.99350390136448)
# => ["America/New_York"]
```

## WebAssembly

```html
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <title>tzf-wasm 示例</title>
    <script type="module">
      import init, { WasmFinder } from "https://www.unpkg.com/tzf-wasm@v0.1.4/tzf_wasm.js";

      async function loadWasm() {
        await init();
        const finder = new WasmFinder();
        const timezone = finder.get_tz_name(-74.006, 40.7128);
        console.log("纽约时区：", timezone);
      }

      loadWasm();
    </script>
  </head>
  <body></body>
</html>
```

在线预览：<http://ringsaturn.github.io/tzf-web/>

## CLI

Go 和 Rust 实现均提供命令行工具。

### Go CLI

```bash
go install github.com/ringsaturn/tzf/cmd/tzf@latest
```

```bash
tzf -lng 116.3883 -lat 39.9289

# 通过 stdin 批量处理
echo -e "116.3883 39.9289\n116.3883, 39.9289" | tzf -stdin-order lng-lat
```

### Rust CLI

```bash
cargo install tzf-rs
```

```bash
tzf --lng 116.3883 --lat 39.9289

# 通过 stdin 批量处理
echo -e "116.3883 39.9289\n116.3883, 39.9289" | tzf --stdin-order lng-lat
```

NixOS 用户可以通过 Nix 安装 `tzf-rs`。
详见 [NixOS packages](https://search.nixos.org/packages?channel=unstable&query=tzf-rs)。
