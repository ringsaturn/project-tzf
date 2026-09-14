---
date: '2025-07-21T21:09:40+09:00'
description: tzf エコシステムにおけるプロジェクト固有の用語と概念のリファレンス。
draft: false
lastmod: '2026-09-14T00:00:00+09:00'
seo:
  description: tzf 固有の用語リファレンス：Finder、.tzb と .tzm のファイル形式、FUZZY プレインデックス、E と M のプロファイル、インプレースと展開のロード方式、ポリゴン簡略化、タイルインデックス、YStripes。
  noindex: false
  title: '用語集 - Project tzf'
summary: tzf の Finder、ファイル形式、アルゴリズム、パフォーマンスリファレンス。
title: 用語集
toc: true
weight: 4
---

## API の動作

### 座標順序 {#coordinate-order}

すべての tzf 実装は **(経度，緯度)** の順序を使用します。GeoJSON やほとんどの地理 API と同じです。
一部のシステム（Google Maps URL、多くの教科書）では (緯度，経度) を使用するため、値を渡す前に再確認してください。

### 複数タイムゾーン {#multiple-timezones}

タイムゾーン境界付近の地点は複数のタイムゾーンに属する場合があります。
複数結果 API を使用してすべての候補を取得してください：

| 言語   | 関数                  |
| ------ | --------------------- |
| Go     | `GetTimezoneNames()`  |
| Rust   | `get_tz_names()`      |
| Python | `get_tzs()`           |
| Swift  | `getTimezones()`      |

## Finder

v2 では、インターフェイスを返すコンストラクタを通じて Finder を公開します。v1 の `Finder` / `FuzzyFinder` / `DefaultFinder` クラスについては [v1 の用語](#v1-terms)を参照してください。

### デフォルト Finder {#defaultfinder}

Go の `NewDefaultFinder()`、Rust の `DefaultFinder::new()` です。lite データセットを読み込み、FUZZY プレインデックスを高速パス、ポリゴンジオメトリをその背後の処理として使用します。Go ではポリゴンのストレージが `.tzm` メモリイメージをインプレースで参照し、ヒープ約 12 MB に読み取り専用データ約 10 MB を加えた構成で、Apple M3 Max の `2026c` データセットに対してクエリは 298 ns です。Rust では同じコンストラクタが `lite.tzb` をポリゴンに展開し、ピーク RSS 約 47 MiB、クエリ 221 ns となります（2026-09-14 スナップショット）。

### 埋め込み Finder {#embeddedfinder}

Go の `NewEmbeddedFinder()`、Rust の `EmbeddedFinder::new()` です。lite `.tzb` をインプレースで参照し、ファイルバイト列に加えてオープン時に構築する小さなインデックス（2.1 以降、Go で約 30 KB、Rust で約 100 KB）を保持します。プレインデックスが地点をカバーしていない場合、境界都市のクエリは約 1 µs です（2026-09-14 スナップショットで Go の p50 1,000 ns、Rust の平均 666 ns）。組み込み環境、メモリ上限のあるプロセス、ファイルシステムのない配置が該当します。

### 完全精度 Finder {#fullfinder}

Go の `NewFullFinder()`、Rust の `DefaultFinder::new_full()` です。完全精度データセットをメモリに展開して読み込み、Go では約 145 MB が常駐します。結果は簡略化前の境界データと一致します。

### データバージョン {#data-version}

タイムゾーン境界データのバージョン識別子（例：`"2026c"`）。
[evansiroky/timezone-boundary-builder](https://github.com/evansiroky/timezone-boundary-builder) 経由で
[IANA タイムゾーンデータベース](https://www.iana.org/time-zones)のリリースを追跡します。
`data_version()` (Python)、`DataVersion()` (Go)、`data_version()` (Rust) で実行時にアクセス可能です。tzf-dist の 3 つの成果物はいずれも同じ値を持ちます。

## データ形式

### `.tzb` {#tzb}

E プロファイルの TZF 埋め込みバイナリファイルです。コンパクトな転送用形式で、ジオメトリはチャンク化された zigzag-LEB128 varint ストリームとして格納されます。すべての実装が読み込みます。[埋め込みバイナリ形式]({{< relref "embedded-binary-format" >}})を参照してください。

### `.tzm` {#tzm}

M プロファイルの TZF 埋め込みバイナリファイルです。同じデータのジオメトリを `(int32, int32)` ペアの 1 つのフラット配列として格納するため、ファイルのレイアウトがクエリ時の構造と一致します。Go の実装が読み込みます。tzf-rs はこの形式のファイルに対して `Error::Profile` を返します。使用するホスト上で tzf の `cmd/tzb2tzm` により生成します。

### プロファイル E / プロファイル M {#profiles}

オフセット 48 のヘッダバイトが TZF 埋め込みバイナリファイルのレイアウトを選択します。`0` が E（embedded、`.tzb`）、`1` が M（メモリイメージ、`.tzm`）です。必須セクションはプロファイルごとに異なり、プロファイルをまたぐセクション種別は拒否されます。

### FUZZY セクション {#fuzzy}

セクション種別 10 です。タイルプレインデックスを、パックされたタイル ID とタイムゾーンインデックスのソート済み配列 1 つとして格納します。tzf-dist の 3 つの成果物すべてに含まれます。単一名クエリの高速パスであり、複数結果 API はこれを参照しません。`2026c` データセットでは 87,572 個のタイルを保持し、そのうち 156 個が 2 つのタイムゾーンを指し、サイズは約 880 KB です。

### インプレースと展開のロード方式 {#in-place-expanded}

**インプレース：** Finder が各クエリの必要に応じてファイルバイト列からジオメトリを読み出します。オープン時にジオメトリのデコードはなく、ヒープにはオープン時に構築する小さなインデックスのみを持ち、プレインデックスがミスした場合のクエリは約 1 µs です。Go の `NewEmbeddedFinder`、`x.NewFinderFromTZBReaderAt`、Rust の `EmbeddedFinder` が該当します。

**インプレース参照：** M プロファイルはクエリ時のレイアウトで点を格納するため、リングのストレージがデコードもコピーもなくマップされたバイト列を直接指します。ソースのバイト列は有効かつ変更されない状態を保つ必要があります。Go の `NewFinderFromTZM` が該当します。

**展開：** オープン時にファイルをポリゴンオブジェクトへデコードします。オープンコストと常駐メモリは大きくなり、クエリはナノ秒単位です。Go の `NewFinderFromTZB`、`NewFullFinder`、Rust の `DefaultFinder` が該当します。

## データファイル

### tzf-dist {#tzf-dist}

2026 年春に導入された現在のデータ配布リポジトリ（[`ringsaturn/tzf-dist`](https://github.com/ringsaturn/tzf-dist)）。
処理済みバイナリデータを Go モジュールと Rust crate の両方として配布します。
`tzf-rel` / `tzf-rel-lite` リポジトリを置き換えます。

### データファイル {#data-files}

`tzf-dist` が提供する 3 つのファイルです。いずれも
[TZF 埋め込みバイナリ形式]({{< relref "embedded-binary-format" >}}) 1.1 で、FUZZY セクションと同じ `data_version` を持ちます。

| ファイル | プロファイル | サイズ | 用途 |
| --- | --- | --- | --- |
| `lite.tzb` | E | 約 4 MB | トポロジー簡略化データ。crates.io と PyPI に含まれる本体 |
| `lite.tzm` | M | 約 10 MB | 同じデータのメモリイメージ。Go の `NewDefaultFinder` が読み込みます |
| `full.tzb` | E | 約 14 MB | 完全精度データ。Rust crate では git 限定 |

`full.tzm` は配布されません。完全精度データセットを M のレイアウトに展開すると約 67 MB になるためです。

### tzf-rel / tzf-rel-lite（提供終了） {#tzf-rel}

以前のデータ配布リポジトリで、`tzf-dist` に置き換えられています。これらが提供していた protobuf 成果物は配布されなくなりました。

### v1 の用語 {#v1-terms}

v1 系列（tzf v1.2.x、tzf-rs 1.3.x、tzfpy 1.3.x）に適用される用語です。この系列は最後の protobuf データリリースで凍結されます。

| 用語 | v1 における意味 | v2 での対応 |
| --- | --- | --- |
| `FuzzyFinder` | タイルプレインデックスのみを使う Finder。カバーされたタイルの外では結果を返しませんでした | 削除。プレインデックスはすべての Finder 内部の高速パスです |
| `Finder` | ポリゴンのみを使う Finder | デフォルト Finder。複数結果 API はポリゴンによる厳密な判定を維持します |
| `DefaultFinder` | プレインデックスとポリゴンへのフォールバック | デフォルト Finder。役割は同じです |
| `CompressedTopoTimezones` | 重複排除と polyline エンコードを施したジオメトリを保持する protobuf メッセージ | `.tzb` / `.tzm` |
| `PreindexTimezones` | タイルプレインデックスを保持する protobuf メッセージ | FUZZY セクション |

## アルゴリズムとインデックス

### ポリゴン簡略化 {#polygon-simplification}

[Ramer-Douglas-Peucker (RDP)](https://en.wikipedia.org/wiki/Ramer%E2%80%93Douglas%E2%80%93Peucker_algorithm)
アルゴリズムを適用して、タイムゾーン境界ポリゴンのポイント数を削減します。
v2 の lite データセットは epsilon 0.001 度を使用しており、
[BORDER_CHANGE.md](https://github.com/ringsaturn/tzf/blob/main/BORDER_CHANGE.md)
で認証されている通り、境界の変位は 111.2 m に抑えられます。

### トポロジー認識簡略化 {#topology-aware}

ポリゴンごとの RDP を強化し、共有境界でのギャップ/重複問題を修正します
（[tzf#183](https://github.com/ringsaturn/tzf/issues/183)）。

隣接ポリゴン間の共有エッジを最初に検出し、一度だけ簡略化してから、
両方のポリゴンに反映します。これにより、簡略化によって新しいギャップや重複が生じるのを防ぎます。
tzf v1.1.0（2026 年春）で導入。実装詳細：
[`internal/topology/README.md`](https://github.com/ringsaturn/tzf/blob/v1.1.0/internal/topology/README.md)。

### タイルベースインデックス {#tile-indexing}

事前計算された空間インデックスで、v2 では [FUZZY セクション](#fuzzy)として格納されます。
地図タイル形式に倣い、地球表面を固定ズームレベルで四辺形タイルに分割します。
タイルは、1 つのタイムゾーンポリゴンに完全に含まれる場合のみインデックスに追加され、
境界タイルは除外されます。内部の地点はポリゴンテストなしにタイル検索で解決されます。

### YStripes インデックス {#ystripes}

Josh Baker の [`tidwall/tg`](https://github.com/tidwall/tg) から移植されたポリゴンごとの空間インデックス。
各ポリゴンのエッジを水平ストライプに分割し、クエリポイントに対して該当するストライプ内の
エッジのみをテストします。tzf v1.1.0 (Go) および tzf-rs v1.2.0 (Rust) 以降デフォルトであり、
v2 では常に有効です。`.tzm` のローダーはオープン時にこれを並列で再構築します。
埋め込みバイナリ形式のセクション種別 14 はこのインデックスのシリアライズ形式を予約していますが、
現時点では出力されません。
アルゴリズム詳細：[`POLYGON_INDEXING.md`](https://github.com/tidwall/tg/blob/main/docs/POLYGON_INDEXING.md)。

## 内部実装

### CGO vs PyO3 {#cgo-pyo3}

tzfpy は当初 CGO 経由で Go 実装を呼び出し、`.so` ファイルにコンパイルしていました。
v0.11.0 以降は [PyO3](https://pyo3.rs/) を使用して tzf-rs (Rust) をラップしています。
PyO3 は FFI 境界を越えてオブジェクトのライフタイムを手動管理する必要がなくなり、
CGO が引き起こしていたメモリリーク（[tzf#63](https://github.com/ringsaturn/tzf/pull/63)）を解消し、
CPU 集約的なワークロードでより優れたスループットを提供します。
