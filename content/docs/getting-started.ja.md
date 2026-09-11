---
date: '2025-07-19T12:19:49+09:00'
description: Go、Rust、Python、Swift、Ruby、Wasm などで Project tzf をインストールして実行する方法。
draft: false
lastmod: '2026-09-11T00:00:00+09:00'
seo:
  description: Go、Rust、Python、Swift、Ruby、WebAssembly で GPS 座標からタイムゾーンを検索する方法。HTTP API 経由でも利用できます。
  title: 'はじめる - Project tzf'
summary: 対応言語とサービスのインストール手順と使用例。
title: はじめる
toc: true
weight: 1
---

Project tzf は複数の言語とサービスに対応し、経度・緯度からタイムゾーンを検索できます。

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

tzf v2 は新しいメジャーバージョンであるため、モジュールパスに `/v2` サフィックスが付きます。

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
	// 構築のコストはクエリと比べて大きいため、Finder は一度だけ構築します。
	finder, err := tzf.NewDefaultFinder()
	if err != nil {
		panic(err)
	}
	// 座標は (経度，緯度) の順です。
	fmt.Println(finder.GetTimezoneName(116.6386, 40.0786))
}
```

コンストラクタは 5 つあり、いずれも `tzf.F` インターフェイスを返します。

| コンストラクタ | 対象 |
| --- | --- |
| `NewDefaultFinder()` | 汎用用途：lite メモリイメージ、ヒープ約 12 MB + 読み取り専用データ 10 MB、クエリ 298 ns |
| `NewEmbeddedFinder()` | 組み込みおよびメモリ制約のある環境：合計約 3 MB、マイクロ秒単位のクエリ |
| `NewFullFinder()` | 完全精度データセットと一致する結果（約 145 MB） |
| `NewFinderFromTZB(data)` | 呼び出し側が用意した `.tzb` バイト列、ロード時に展開 |
| `NewFinderFromTZM(data)` | 呼び出し側が用意した `.tzm` バイト列、インプレースで参照 |

数値は Apple M3 Max で `2026c` データセットを対象に測定した値です。

100% 正確な結果が必要な場合は `NewFullFinder` を使用します。初期化コストが高いため、できるだけ再利用してください：

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

GeoJSON エクスポート、独自のバイト列に対するインプレースクエリ、v1 から v2 への移行表については [Go ガイド]({{< relref "guides/tzf" >}})を参照してください。

## Rust

```bash
cargo add tzf-rs
```

```rust
use std::sync::LazyLock;
use tzf_rs::DefaultFinder;

static FINDER: LazyLock<DefaultFinder> = LazyLock::new(DefaultFinder::new);

fn main() {
    // 座標は (経度，緯度) の順です。
    print!("{:?}\n", FINDER.get_tz_name(116.3883, 39.9289));
    print!("{:?}\n", FINDER.get_tz_names(116.3883, 39.9289));
}
```

tzf-rs 2.0 は 2 つの Finder を提供します。デフォルトの `DefaultFinder`（ピーク RSS 約 47 MiB、ランダム都市検索 229 ns）と、埋め込みファイルをインプレースで参照する `EmbeddedFinder`（約 10 MiB、マイクロ秒単位のレイテンシ）です。いずれも [tz-benchmark](https://github.com/ringsaturn/tz-benchmark) の 2026-09-11 スナップショットにおいて、Apple M3 Max で `2026c` データセットを対象に測定した値です。

<details>
<summary>完全精度サポート</summary>

オプションの Cargo feature で完全精度データを利用できます。
完全データセットは約 14 MB あり、crates.io のサイズ制限を超えるため git 依存関係で参照する必要があり、
バンドルされた lite データセットとは排他です：

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

tzfpy 2.0 は Python 3.10 以降が必要で、tzf-rs 2.0 をバインドします。`timezonenames()`、`data_version()`、`get_tz_polygon_geojson(name)`、`get_tz_index_geojson(name)` も公開しています。Python 版では完全精度モードは利用できません。

## Swift

Swift、Ruby、ブラウザ向け Wasm のバインディングは、2026-09-10 時点で v1 系列の上に構築されています。tzf-rb は [HarlemSquirrel](https://github.com/HarlemSquirrel) が独立して保守しています。

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

Ruby 版は [HarlemSquirrel](https://github.com/HarlemSquirrel) が作成し、保守しています。
詳しい使い方は [tzf-rb](https://github.com/HarlemSquirrel/tzf-rb) を参照してください。

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
      import init, { WasmFinder } from "https://www.unpkg.com/tzf-wasm@2.0.0/tzf_wasm.js";

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

NixOS ユーザーは Nix 経由で `tzf-rs` をインストールできます。
詳細は [NixOS packages](https://search.nixos.org/packages?channel=unstable&query=tzf-rs) を参照してください。
