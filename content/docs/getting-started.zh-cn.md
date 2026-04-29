---
date: '2025-07-19T12:19:49+09:00'
description: 安装并使用你喜欢的编程语言运行 Project tzf——Go、Rust、Python、Swift、Ruby、Wasm 等。
draft: false
lastmod: '2025-07-19T12:19:49+09:00'
seo:
  description: 在 Go、Rust、Python、Swift、Ruby、WebAssembly 中安装并运行 GPS 坐标转时区查询，或通过 HTTP API 使用。
  title: 快速开始——Project tzf
summary: 所有支持语言的快速安装和使用示例。
title: 快速开始
toc: true
weight: 1
---

Project tzf 提供多语言支持，可根据经纬度查询时区。

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

```bash
go get github.com/ringsaturn/tzf
```

```go
// 初始化大约使用 150MB 内存，GC 后约 60MB。
package main

import (
	"fmt"

	"github.com/ringsaturn/tzf"
)

func main() {
	finder, err := tzf.NewDefaultFinder()
	if err != nil {
		panic(err)
	}
	fmt.Println(finder.GetTimezoneName(116.6386, 40.0786))
}
```

如需 100% 准确的结果，请使用 `NewFullFinder`（**尽可能复用实例**——初始化开销较大）：

```go
package main

import (
	"fmt"

	"github.com/ringsaturn/tzf"
)

func main() {
	finder, err := tzf.NewFullFinder()
	if err != nil {
		panic(err)
	}
	fmt.Println(finder.GetTimezoneName(139.6917, 35.6895))
}
```

## Rust

```bash
cargo add tzf-rs
```

```rust
use lazy_static::lazy_static;
use tzf_rs::DefaultFinder;

lazy_static! {
    static ref FINDER: DefaultFinder = DefaultFinder::new();
}

fn main() {
    // 坐标采用 (经度，纬度) 顺序。
    print!("{:?}\n", FINDER.get_tz_name(116.3883, 39.9289));
    print!("{:?}\n", FINDER.get_tz_names(116.3883, 39.9289));
}
```

<details>
<summary>完整精度支持（v1.3.0+）</summary>

自 v1.3.0 起，可通过可选的 Cargo feature 使用完整精度数据。
由于完整数据集（约 17 MB）超出 crates.io 的大小限制，需要通过 git 依赖引用：

```toml
[dependencies]
tzf-rs = { git = "https://github.com/ringsaturn/tzf-rs", tag = "v{X}.{Y}.{Z}", features = ["full"], default-features = false }
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
>>> get_tzs(87.4160, 44.0400)   # 返回所有匹配的时区
['Asia/Shanghai', 'Asia/Urumqi']
```

Python 不支持完整精度模式。

## Swift

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

Ruby 支持由 [HarlemSquirrel](https://github.com/HarlemSquirrel) 创建和维护。
详细文档请参见 [tzf-rb](https://github.com/HarlemSquirrel/tzf-rb)。

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

Go 和 Rust 实现均提供了命令行工具。

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

NixOS 用户可以通过 Nix 安装 `tzf-rs`——
详见 [NixOS packages](https://search.nixos.org/packages?channel=unstable&query=tzf-rs)。
