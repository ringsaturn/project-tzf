---
date: '2025-07-19T12:19:49+09:00'
description: お好みのプログラミング言語で Project tzf をインストールして使用——Go、Rust、Python、Swift、Ruby、Wasm など。
draft: false
lastmod: '2025-07-19T12:19:49+09:00'
seo:
  description: Go、Rust、Python、Swift、Ruby、WebAssembly で GPS 座標からタイムゾーン検索をインストールして実行、または HTTP API 経由で利用。
  title: はじめる——Project tzf
summary: 全対応言語のクイックインストールと使用例。
title: はじめる
toc: true
weight: 1
---

Project tzf は経度・緯度からタイムゾーンを検索するための多言語サポートを提供します。

| 言語 / サービス          | リポジトリ                                                              | API ドキュメント                                                                                            |
| ----------------------- | ----------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| Go                      | [`ringsaturn/tzf`](https://github.com/ringsaturn/tzf)                   | [![](https://pkg.go.dev/badge/github.com/ringsaturn/tzf.svg)](https://pkg.go.dev/github.com/ringsaturn/tzf) |
| Rust                    | [`ringsaturn/tzf-rs`](https://github.com/ringsaturn/tzf-rs)             | [![](https://docs.rs/tzf-rs/badge.svg)](https://docs.rs/tzf-rs)                                             |
| Python                  | [`ringsaturn/tzfpy`](https://github.com/ringsaturn/tzfpy)               | [`tzfpy.pyi`](https://github.com/ringsaturn/tzfpy/blob/main/tzfpy.pyi)                                      |
| Swift                   | [`ringsaturn/tzf-swift`](https://github.com/ringsaturn/tzf-swift)       | [![][swift_doc_badge]][swift_doc_url]                                                                        |
| Ruby                    | [`HarlemSquirrel/tzf-rb`](https://github.com/HarlemSquirrel/tzf-rb)     |                                                                                                             |
| JS (ブラウザ Wasm)      | [`ringsaturn/tzf-wasm`](https://github.com/ringsaturn/tzf-wasm)         |                                                                                                             |
| HTTP API                | [`racemap/rust-tz-service`](https://github.com/racemap/rust-tz-service) |                                                                                                             |
| オンラインデモ          | [`ringsaturn/tzf-web`](https://github.com/ringsaturn/tzf-web)           |                                                                                                             |

[swift_doc_url]: https://swiftpackageindex.com/ringsaturn/tzf-swift
[swift_doc_badge]: https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fringsaturn%2Ftzf-swift%2Fbadge%3Ftype%3Dswift-versions

## Go

```bash
go get github.com/ringsaturn/tzf
```

```go
// 初期化に約 150MB のメモリを使用し、GC 後は約 60MB。
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

100% 正確な結果が必要な場合は `NewFullFinder` を使用します（**必ず再利用してください**——初期化コストが高いです）：

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
    // 座標は (経度，緯度) の順です。
    print!("{:?}\n", FINDER.get_tz_name(116.3883, 39.9289));
    print!("{:?}\n", FINDER.get_tz_names(116.3883, 39.9289));
}
```

<details>
<summary>完全精度サポート (v1.3.0+)</summary>

v1.3.0 以降、オプションの Cargo feature で完全精度データを利用できます。
完全データセット（約 17 MB）は crates.io のサイズ制限を超えるため、
git 依存関係で参照する必要があります：

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
# tzfpy のみインストール
pip install tzfpy

# pytz サポート付きでインストール
pip install "tzfpy[pytz]"

# tzdata サポート付きでインストール
pip install "tzfpy[tzdata]"

# conda でインストール
conda install -c conda-forge tzfpy
```

```python
>>> from tzfpy import get_tz, get_tzs
>>> get_tz(116.3883, 39.9289)   # (経度，緯度) の順
'Asia/Shanghai'
>>> get_tzs(87.4160, 44.0400)   # 一致するすべてのタイムゾーンを返す
['Asia/Shanghai', 'Asia/Urumqi']
```

Python は完全精度モードをサポートしていません。

## Swift

`Package.swift` にパッケージを追加します：

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
    print("北京のタイムゾーン：", timezone)

    let timezones = try finder.getTimezones(lng: 87.5703, lat: 43.8146)
    print("複数の候補タイムゾーン：", timezones)

    print("データバージョン：", finder.dataVersion())
} catch {
    print("エラー:", error)
}
```

## Ruby

Ruby サポートは [HarlemSquirrel](https://github.com/HarlemSquirrel) によって作成・保守されています。
詳細なドキュメントは [tzf-rb](https://github.com/HarlemSquirrel/tzf-rb) を参照してください。

```bash
bundle add tzf
# または
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
    <title>tzf-wasm 例</title>
    <script type="module">
      import init, { WasmFinder } from "https://www.unpkg.com/tzf-wasm@v0.1.4/tzf_wasm.js";

      async function loadWasm() {
        await init();
        const finder = new WasmFinder();
        const timezone = finder.get_tz_name(-74.006, 40.7128);
        console.log("ニューヨークのタイムゾーン：", timezone);
      }

      loadWasm();
    </script>
  </head>
  <body></body>
</html>
```

オンラインプレビュー：<http://ringsaturn.github.io/tzf-web/>

## CLI

Go と Rust の両方の実装にコマンドラインツールが付属しています。

### Go CLI

```bash
go install github.com/ringsaturn/tzf/cmd/tzf@latest
```

```bash
tzf -lng 116.3883 -lat 39.9289

# stdin 経由のバッチ処理
echo -e "116.3883 39.9289\n116.3883, 39.9289" | tzf -stdin-order lng-lat
```

### Rust CLI

```bash
cargo install tzf-rs
```

```bash
tzf --lng 116.3883 --lat 39.9289

# stdin 経由のバッチ処理
echo -e "116.3883 39.9289\n116.3883, 39.9289" | tzf --stdin-order lng-lat
```

NixOS ユーザーは Nix 経由で `tzf-rs` をインストールできます——
詳細は [NixOS packages](https://search.nixos.org/packages?channel=unstable&query=tzf-rs) を参照してください。
