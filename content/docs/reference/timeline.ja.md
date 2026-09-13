---
date: '2025-07-21T10:52:43+09:00'
description: 'Project tzf の開発史 - 最初の Go 実装から 2026 年の v2 リリースまで。'
draft: false
lastmod: '2026-09-12T00:00:00+09:00'
seo:
  description: 'Project tzf の開発タイムライン - 2022 年の最初の Go リリースから 2026 年の protobuf を使用しない v2 リリースまで。'
  noindex: false
  title: 'タイムライン - Project tzf'
summary: tzf エコシステムにおける主要マイルストーンの時系列の歴史。
title: タイムライン
toc: true
weight: 6
---

## 2022

### 2022-05-29

リポジトリ <https://github.com/ringsaturn/tzf> を作成。

### 2022-08-01

Go の CGO 機能をベースにした tzfpy の最初のバージョン [`v0.6.0`](https://pypi.org/project/tzfpy/0.6.0/) をリリース。

### 2022-11-06

tzf 用のタイルベースインデックスを設計。

### 2022-11-20

<https://github.com/ringsaturn/tzf-rs> の最初のバージョンをリリース。

### 2022-11-21

Go バインディングを PyO3 経由の Rust バインディングに置き換え、
tzfpy の [`0.10.0`](https://pypi.org/project/tzfpy/0.10.0/) としてリリース。

tzfpy を独自のリポジトリ <https://github.com/ringsaturn/tzfpy> に移動。

## 2024

### 2024-04-22

tzf-rs の WebAssembly 版である <https://github.com/ringsaturn/tzf-wasm> を作成。

## 2025

### 2025-02-21

tzf の Swift 版である <https://github.com/ringsaturn/tzf-swift> を作成。

### 2025-03-24

tzf、tzf-rs、tzfpy、tzf-wasm、tzf-swift の v1.0.0 をリリース。

tzf リポジトリの API が安定版になりました。

### 2025-05-03

tzf-rs の PostgreSQL 拡張である <https://github.com/ringsaturn/pg-tzf> を作成。

## 2026

### 2026 年春

**トポロジー認識簡略化**を tzf v1.1.0 で実装し、長年の課題
（[tzf#183](https://github.com/ringsaturn/tzf/issues/183)）を解決しました。独立した
ポリゴンごとの RDP 簡略化が共有タイムゾーン境界にギャップと重複を生じさせていました。
新しいアプローチでは、まず共有エッジを検出し、一度だけ簡略化してから、
簡略化された境界を両方の隣接ポリゴンに反映します。

**新しいデータ配布リポジトリ** [`ringsaturn/tzf-dist`](https://github.com/ringsaturn/tzf-dist)
を導入し、新しい `CompressedTopoTimezones` 形式でデータを配布：

| ファイル | サイズ | 説明 |
| --- | --- | --- |
| `combined-with-oceans.compress.topo.bin` | 約 17 MB | 完全精度 |
| `combined-with-oceans.topology.compress.topo.bin` | 約 5.4 MB | トポロジー簡略化（ライト版） |
| `combined-with-oceans.topology.preindex.bin` | 約 2 MB | タイルプレインデックス |

完全精度データセットが約 90 MB から約 17 MB に縮小され、
tzf-rs v1.3.0 でオプションの Cargo feature として提供可能になりました
（`DefaultFinder::new_full()`）。

**YStripes 空間インデックス**（[`tidwall/tg`](https://github.com/tidwall/tg) から移植）が
tzf v1.1.0 (Go) および tzf-rs v1.2.0 (Rust) でデフォルトのポリゴンレベルインデックスに。
Apple M3 Max で単一ランダム都市検索が約 1 µs。

この波のリリース：tzf v1.1.0、tzf-rs v1.2.0 / v1.3.0、tzfpy v1.2.0 / v1.3.0、
tzf-dist v0.0.2026-a、geometry-rs v0.4.1。

詳細はブログ記事 [tzf 2026 年春のアップデート]({{< ref "/blog/2026-spring-news/index.md" >}}) をご覧ください。

### 2026-07-19

TZF 埋め込みバイナリ形式の仕様がバージョン 1.0 として Final になりました（[形式リファレンス](/ja/docs/reference/embedded-binary-format/)を参照）。`TZFB` コンテナを定義し、64 バイトのヘッダ、セクションテーブル、セクション種別 1 から 9、CRC32 フッタで構成され、ジオメトリはチャンク化された zigzag-LEB128 varint ストリームとして格納されます。このレイアウトにより、読み手はファイル全体をデコードせずにクエリへ応答できます。

### 2026-08-16

形式 1.1 で、v2 のランタイムが必要とする要素が追加されました。ヘッダのオフセット 48 の `profile` バイト、セクション種別 10（`FUZZY`、タイルプレインデックス）、およびセクション種別 12（`FLATPOINTS`）、13（`FLATRINGDIR`）、14（`YSTRIPES`、割り当て済みで未出力）を持つ M プロファイルです。必須セクションはプロファイルごとに定義されるようになりました。

### 2026-08-18

v2 の API が定義されました。`F` を返す 5 つのコンストラクタ、オプションなし、Finder 型のエクスポートなし、そしてセマンティックバージョニングの約束の対象外となる領域のための `x` パッケージです。同日、インプレース Finder に FUZZY 高速パスが入り、lite ファイルに対するクエリの中央値が 4.7 µs から 542 ns になりました。

### 2026-08-28

tzf のツリーから protobuf が削除されました。パイプラインはネイティブな Go の構造体と `encoding/gob` の中間表現に移行し、これらはビルド内部のもので配布されません。モジュールは `v2/` サブディレクトリを作らず、その場で `github.com/ringsaturn/tzf/v2` になりました。同じ時期に tzf-rs が `.tzb` ランタイムへ移植されました。tzf-rs の `.tzm` ローダーは測定の結果、オープン時間を約 3 ms 短縮する一方でメモリが増加することが分かり、削除されました。tzf-rs が読み込むのは E プロファイルのみです。

tzf-dist は protobuf の成果物の配布を終了し、`lite.tzb`、`lite.tzm`、`full.tzb` を配布します。v1 のデータ系列は最後の protobuf リリースで凍結されます。

Apple M3 Max で `2026c` データセットを対象に、protobuf 経路と比較した測定値は次の通りです。

| 経路 | オープン | 常駐 | クエリ |
| --- | ---: | ---: | ---: |
| Go、full protobuf (v1) | 288 ms | 約 153 MB | 約 290 ns |
| Go、full `.tzb` を展開 | 78.5 ms | 約 145 MB | 約 300 ns |
| Go、lite `.tzm` メモリイメージ | 7.7 ms | ヒープ約 12 MB + 読み取り専用 10 MB | 298 ns |
| Go、lite `.tzb` をインプレースで参照 | 1.7 ms | 約 3 MB | 約 6 µs |
| Rust、lite protobuf (v1) | 71 ms | ピーク RSS 77.8 MiB | 316 ns |
| Rust、lite `.tzb` | コールド 18 ms | ピーク RSS 44.1 MiB | 260 ns |

### 2026-09

tzf (Go)、tzf-rs (Rust)、tzfpy (Python) の v2 をリリース。tzf-dist は 2026-09-10 に最初の `.tzb`/`.tzm` アーティファクトセットのタグ `v0.0.2026-c-tzb1` を打ち、同日に tzf v2.0.0 が、2026-09-11 に tzf-rs 2.0.0 と tzfpy 2.0.0 がリリースされました。Go のモジュールパスに `/v2` サフィックスが付き、tzf-rs は 2.0.0 に、tzfpy は tzf-rs 2.0 をバインドします。tzf-wasm 2.0.0 は 2026-09-11 に tzf-rs 2.0.0 の上でリリースされ、tzf-web はそれを使用しています。tzf-swift 2.0.0 は 2026-09-12 に、protobuf に依存せず `lite.tzb` を直接読み込む移植としてリリースされ、`DefaultFinder` と省メモリの `EmbeddedFinder` を提供します。v1 系列（tzf v1.2.x、tzf-rs 1.3.x、tzfpy 1.3.x、tzf-swift 1.2.x）は引き続き利用でき、最後の protobuf データリリースで凍結されます。この時点で、独立して保守されている tzf-rb は v1 系列の上に構築されています。
