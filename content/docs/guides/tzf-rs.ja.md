---
date: '2025-07-21T14:19:40+09:00'
description: Rust 版 tzf-rs (v2) のベストプラクティスと高度な使用パターン。
draft: false
lastmod: '2026-09-14T00:00:00+09:00'
seo:
  description: Rust tzf-rs v2 crate のベストプラクティス。DefaultFinder と EmbeddedFinder、cargo feature、GeoJSON エクスポート、v1 からの移行を扱います。
  noindex: false
  title: 'Rust (tzf-rs) ガイド - Project tzf'
summary: tzf-rs 2.0 の 2 つの Finder、cargo feature、GeoJSON エクスポート、統合パターン、v1 から v2 への移行表。
title: Rust (tzf-rs)
toc: true
weight: 3
---

## インストール

```bash
cargo add tzf-rs
```

tzf-rs 2.0 は protobuf を使用しません。[`ringsaturn/tzf-dist`](https://github.com/ringsaturn/tzf-dist) が公開する TZF 埋め込みバイナリ形式（`.tzb`）を読み込みます。デフォルトの `bundled` feature は lite ファイル（約 4 MB）を crate 内に含みます。形式そのものについては[埋め込みバイナリ形式]({{< relref "../reference/embedded-binary-format" >}})を参照してください。

## 2 つの Finder

| 型 | データ | ピーク RSS | クエリ（ランダム都市 / 境界都市） |
| --- | --- | ---: | ---: |
| `DefaultFinder` | lite `.tzb` をポリゴンに展開、FUZZY 高速パス | 約 47 MiB | 221 ns / 475 ns |
| `EmbeddedFinder` | lite `.tzb` をインプレースで参照 | 約 10 MiB | 293 ns / 666 ns |

[tz-benchmark](https://github.com/ringsaturn/tz-benchmark) の 2026-09-14 スナップショットにおいて、Apple M3 Max で `2026c` データセットを対象に、tzf-dist `0.0.2026-c-tzb2` 上の tzf-rs 2.1.1 を測定した値です。このハーネスにおける Rust ランタイムの下限値は 5.8 MiB です。tzf-rs 2.1 は `EmbeddedFinder` のクエリ走査を書き直し（オープン時の検証、チャンクブロックと端点パリティによるスキップ、グループごとの緯度ストライプ、キーを持つズームレベルに限定したプレインデックス探索）、64 点チャンクのデータに移行しました。結果は変わらず、境界都市の値は 2.0.0 では 4.78 µs でした。

`DefaultFinder::new()` のオープン時間は約 13 ms、`EmbeddedFinder::new()` は約 2 ms です。カウント機能付きアロケータは `EmbeddedFinder` のヒープ保持量を 0.2 MiB と報告します。データは `&'static` の埋め込みスライスで、それに加えてオープン時に構築するチャンクのスキップブロックと緯度ストライプのインデックス（lite で約 100 KB）を保持するためです。`EmbeddedFinder` が該当するのはメモリ制約のある環境で、境界都市の検索時間は `DefaultFinder` の約 1.4 倍です。その他のケースについては [Finder の選択]({{< relref "choosing-a-finder" >}})を参照してください。

## Finder の再利用

構築時にファイル全体を読み込んで検証するため、プロセスは 1 つの Finder を構築して再利用します。`LazyLock` の static は、依存関係を追加せずにこれを保持します。

```rust {hl_lines=["4"]}
use std::sync::LazyLock;
use tzf_rs::DefaultFinder;

static FINDER: LazyLock<DefaultFinder> = LazyLock::new(DefaultFinder::new);

fn main() {
    // 座標は (経度，緯度) の順です。
    println!("{:?}", FINDER.get_tz_name(116.3883, 39.9289));
    println!("{:?}", FINDER.get_tz_names(116.3883, 39.9289));
}
```

`lazy_static` も使用できます。`LazyLock` は Rust 1.80 以降、標準ライブラリに含まれています。

## クエリ

どちらの Finder も同じ 4 つのメソッドを公開します。

```rust
finder.get_tz_name(lng, lat)   // -> &str、一致がない場合は空
finder.get_tz_names(lng, lat)  // -> Vec<&str>、辞書順にソート
finder.timezonenames()         // -> Vec<&str>
finder.data_version()          // -> &str、例："2026c"
```

- `get_tz_name` はファジー優先です。FUZZY タイルプレインデックスが大部分のクエリを point-in-polygon なしで解決します。
- `get_tz_names` はどちらの Finder でもポリゴンによる厳密な判定を行い、プレインデックスを参照しません。地点が複数のタイムゾーンに属する可能性がある場合に該当します。共有境界上の地点は、接するすべてのポリゴンに属します。

## 独自のバイト列を使用する

```rust
use tzf_rs::{DefaultFinder, EmbeddedFinder};

let data = std::fs::read("lite.tzb")?;
let finder = DefaultFinder::from_tzb(&data)?;   // ロード中は借用し、その後展開する
```

```rust
static DATA: &[u8] = include_bytes!("../data/lite.tzb");
let finder = EmbeddedFinder::from_tzb(DATA)?;   // コピーなし。クエリはインプレースで読む
```

`EmbeddedFinder::from_tzb` は `impl Into<Cow<'static, [u8]>>` を受け取ります。`include_bytes!` による `&'static [u8]` はコピーせずにそのまま使用され、所有権を持つ `Vec<u8>` も受け付けます。どちらのコンストラクタも `Result<_, tzf_rs::Error>` を返します。ファイルはオープン時に CRC と構造の検証を受けるため、不正なデータは空の Finder ではなくエラーとして現れます。

`Error` は `#[non_exhaustive]` で、`Malformed`、`Profile`、`NoFuzzy`、`Index` のバリアントを持ちます。`.tzm` メモリイメージのバイト列は `Profile` を返します。tzf-rs が読み込むのは `.tzb` プロファイルのみで、M プロファイルは Go の実装が読み込みます。

## Cargo feature

| Feature | デフォルト | 効果 |
| --- | --- | --- |
| `bundled` | 有効 | tzf-dist の lite `.tzb`（約 4 MB）を埋め込み、`new()` を有効化します |
| `clap` | 有効 | `tzf` CLI バイナリをビルドします |
| `full` | 無効 | git 限定の完全精度 `.tzb`（約 14 MB）。`new_full()` を有効化します |
| `export-geojson` | 無効 | GeoJSON エクスポートのメソッド |

`full` は `bundled` と排他です。両方を有効にすると crate が `compile_error!` を発生させます。完全精度データセットは crates.io のサイズ制限を超えるため、git から参照します。

```toml
[dependencies]
tzf-rs = { git = "https://github.com/ringsaturn/tzf-rs", rev = "v{X}.{Y}.{Z}", features = ["full"], default-features = false }
```

```rust
use tzf_rs::DefaultFinder;

let finder = DefaultFinder::new_full();
println!("{}", finder.get_tz_name(139.767125, 35.681236));
```

ライブラリとしてのビルドで CLI バイナリを外す場合は `cargo build --no-default-features --features bundled` を使用します。

## GeoJSON エクスポート

`export-geojson` を有効にすると、どちらの Finder も 4 つのエクスポート関数を公開します。

```rust
let world = finder.to_geojson();                            // BoundaryFile
let tokyo = finder.get_tz_geojson("Asia/Tokyo");            // Option<BoundaryFile>
let tiles = finder.get_tz_preindex_geojson("Asia/Tokyo");   // Option<BoundaryFile>
let all_tiles = finder.to_preindex_geojson();               // Option<BoundaryFile>
```

プレインデックスのエクスポートは、対象のタイムゾーンを指す FUZZY タイルのバウンディング矩形を返します。これは `get_tz_name` が point-in-polygon にフォールバックせずプレインデックスから応答する領域です。FUZZY セクションを持たないファイルでは `None` を返します。

## v1 からの移行

| v1 | v2 |
| --- | --- |
| `DefaultFinder::new()` | `DefaultFinder::new()` — 呼び出し箇所の変更は不要 |
| `DefaultFinder::new_full()` | `DefaultFinder::new_full()` — 呼び出し箇所の変更は不要 |
| `Finder`（ポリゴンのみ） | `DefaultFinder`。`get_tz_names` はポリゴンによる厳密な判定を維持します |
| `FuzzyFinder`（タイルのみ） | 削除。プレインデックスはすべての Finder 内部の高速パスになりました |
| `Finder::from_compressed_topo(pb)` | `DefaultFinder::from_tzb(bytes)` |
| `FuzzyFinder::from_pb(pb)` | 削除。代替はありません |
| `FinderOptions` / `new_with_options` | 削除。YStripes は常に有効です |
| `finder.finder.get_tz_geojson(...)` | `finder.get_tz_geojson(...)` |
| `FuzzyFinder` のタイル境界 GeoJSON | `get_tz_preindex_geojson` / `to_preindex_geojson` に置き換え |
| — | 追加：インプレースで低メモリの `EmbeddedFinder` |

動作の変更点は次の通りです。

- `get_tz_names` の結果が辞書順にソートされるようになりました。
- `DefaultFinder` の `get_tz_name` はカバーするプレインデックスタイルから応答します。これは v1 の `DefaultFinder` の動作と一致します。v1 の `Finder` でポリゴンによる厳密な複数結果を取得していたコードは `get_tz_names` を呼び出します。
- バイト列を受け取るコンストラクタは、空の Finder へのフォールバックではなく `Result` を返します。
- GeoJSON のエクスポートは、protobuf の展開時に保持されていた接合点の重複頂点（長さ 0 のセグメント）を含みません。クエリ結果に影響はありません。
- protobuf とともに削除されたもの：`Finder::from_pb`、`Finder::from_compressed_topo`、`FuzzyFinder::from_pb`、`pbgen` モジュール、`prost` 依存、`revert_timezones`。

v1 系列（tzf-rs 1.3.x）は引き続き利用でき、最後のデータリリースで凍結されます。v2 のセットが公開された時点で tzf-dist は protobuf の成果物の配布を終了するため、更新された境界データを使用するには v2 への移行が必要です。

## 統合例

- HTTP サービス：[`racemap/rust-tz-service`](https://github.com/racemap/rust-tz-service) は Axum Web サーバーで tzf-rs をラップしています。
- Redis プロトコル：[`ringsaturn/redizone`](https://github.com/ringsaturn/redizone) は tzf-rs 上に構築された Redis 互換サーバーです。
- PostgreSQL：[`ringsaturn/pg-tzf`](https://github.com/ringsaturn/pg-tzf) は tzf-rs をデータベース拡張として公開します。
