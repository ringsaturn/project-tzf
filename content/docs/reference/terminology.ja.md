---
date: '2025-07-21T21:09:40+09:00'
description: tzf エコシステムにおけるプロジェクト固有の用語と概念のリファレンス。
draft: false
lastmod: '2026-04-29T00:00:00+09:00'
seo:
  description: tzf 固有の用語リファレンス：Finder クラス、tzf-dist データファイル、ポリゴン簡略化、トポロジー認識処理、タイルインデックス、YStripes、メモリ使用量。
  noindex: false
  title: 用語集——Project tzf
summary: tzf の Finder クラス、データファイル、アルゴリズム、パフォーマンスリファレンス。
title: 用語集
toc: true
weight: 3
---

## API の動作

### 座標順序 {#coordinate-order}

すべての tzf 実装は **(経度，緯度)** の順序を使用します——GeoJSON やほとんどの地理 API と同様です。
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

## Finder クラス

### FuzzyFinder {#fuzzyfinder}

タイルプレインデックスのみを使用します。インデックス内の各タイルは、単一のタイムゾーンポリゴン内に**完全に収まる**領域をカバーします。

- ポイントがカバーされたタイル内にある → ポリゴンテストなしで正しいタイムゾーンを即座に返します。
- ポイントがカバーされたタイルの外にある（境界付近、海岸線、疎な地域）→ **結果なしを返します**。

カバーされたタイルの結果は正確です；呼び出し側は空のケースを処理する必要があります。
最速のオプション（約 470 ns / 約 9 MB）ですが、すべての座標をカバーするわけではありません。

### Finder {#finder}

トポロジー簡略化データセットと YStripes インデックスを使用した完全なポリゴン検索。
全世界の座標をカバーします（約 1–2 µs、約 66 MB）。

### DefaultFinder {#defaultfinder}

FuzzyFinder と Finder を組み合わせたものです：まずタイルプレインデックスを参照し、結果が返されなかった場合に
完全なポリゴン検索にフォールバックします。大部分の内部クエリにプレインデックスの速度を提供しつつ、
すべての座標で正確な結果を保証します（約 1 µs、約 75 MB）。**ほとんどのユースケースで推奨。**

### データバージョン {#data-version}

タイムゾーン境界データのバージョン識別子（例：`"2025b"`）。
[evansiroky/timezone-boundary-builder](https://github.com/evansiroky/timezone-boundary-builder) 経由で
[IANA タイムゾーンデータベース](https://www.iana.org/time-zones)のリリースを追跡します。
`data_version()` (Python)、`DataVersion()` (Go)、`data_version()` (Rust) で実行時にアクセス可能です。

## データファイル

### tzf-dist {#tzf-dist}

2026 年春に導入された現在のデータ配布リポジトリ（[`ringsaturn/tzf-dist`](https://github.com/ringsaturn/tzf-dist)）。
処理済みバイナリデータを Go モジュールと Rust crate の両方として配布します。
古い `tzf-rel` / `tzf-rel-lite` リポジトリを置き換えます（非推奨予定）。

### データファイル {#data-files}

`tzf-dist` が提供する 3 つのバイナリファイル、すべて `CompressedTopoTimezones` 形式：

| ファイル | サイズ | 用途 |
| --- | --- | --- |
| `combined-with-oceans.compress.topo.bin` | 約 17 MB | 完全精度データ |
| `combined-with-oceans.topology.compress.topo.bin` | 約 5.4 MB | トポロジー簡略化（デフォルト） |
| `combined-with-oceans.topology.preindex.bin` | 約 2 MB | FuzzyFinder 用タイルプレインデックス |

### tzf-rel / tzf-rel-lite（非推奨） {#tzf-rel}

以前のデータ配布リポジトリ。現在は `tzf-dist` に取って代わられています。
引き続き機能しますが、更新は行われません。

## アルゴリズムとインデックス

### ポリゴン簡略化 {#polygon-simplification}

[Ramer–Douglas–Peucker (RDP)](https://en.wikipedia.org/wiki/Ramer%E2%80%93Douglas%E2%80%93Peucker_algorithm)
アルゴリズムを適用して、タイムゾーン境界ポリゴンのポイント数を削減します。
生の protobuf データをメモリ内の約 900 MB からディスク上の約 11 MB に縮小し、
許容可能な精度損失（境界から約 1 km 以内で誤った結果が出る可能性があります）を伴います。

### トポロジー認識簡略化 {#topology-aware}

ポリゴンごとの RDP を強化し、共有境界でのギャップ/重複問題を修正します
（[tzf#183](https://github.com/ringsaturn/tzf/issues/183)）。

隣接ポリゴン間の共有エッジを最初に検出し、一度だけ簡略化してから、
両方のポリゴンに反映します——簡略化によって新しいギャップや重複が生じるのを防ぎます。
tzf v1.1.0（2026 年春）で導入。実装詳細：
[`internal/topology/README.md`](https://github.com/ringsaturn/tzf/blob/v1.1.0/internal/topology/README.md)。

### タイルベースインデックス {#tile-indexing}

`FuzzyFinder` が使用する事前計算された空間インデックス。地球表面を固定ズームレベルで
四辺形タイルに分割します（地図タイル形式に着想）。タイルは、1 つのタイムゾーンポリゴンに
完全に含まれる場合のみインデックスに追加されます——境界タイルは意図的に除外されます。
内部ポイントに対してポリゴンテストなしの O(1) プレフィルタリングを可能にします。

### YStripes インデックス {#ystripes}

Josh Baker の [`tidwall/tg`](https://github.com/tidwall/tg) から移植されたポリゴンごとの空間インデックス。
各ポリゴンのエッジを水平ストライプに分割し、クエリポイントに対して該当するストライプ内の
エッジのみをテストします。tzf v1.1.0 (Go) および tzf-rs v1.2.0 (Rust) 以降デフォルト。
最新ハードウェアで単一ランダム都市検索を約 1 µs にします。
アルゴリズム詳細：[`POLYGON_INDEXING.md`](https://github.com/tidwall/tg/blob/main/docs/POLYGON_INDEXING.md)。

## パフォーマンス

### メモリ使用量 {#memory-usage}

Go 実装のおおよその数値（Rust も同様）：

| モード | メモリ |
| --- | --- |
| DefaultFinder（トポロジー簡略化 + プレインデックス） | 約 75 MB |
| Finder（トポロジー簡略化） | 約 66 MB |
| FullFinder（完全精度 + プレインデックス） | 約 422 MB |
| FullFinder（完全精度のみ） | 約 413 MB |

Rust で YStripes インデックスを有効にすると、インデックスなしのベースラインから約 30–40 MB 追加されます。
Rust の完全精度モード（YStripes 有効）は約 560 MB 必要です。
Python (tzfpy) は内部的に Rust バイナリを使用します；デフォルトモードで約 120 MB を想定してください。

## 内部実装

### CGO vs PyO3 {#cgo-pyo3}

tzfpy は当初 CGO 経由で Go 実装を呼び出し、`.so` ファイルにコンパイルしていました。
v0.11.0 以降は [PyO3](https://pyo3.rs/) を使用して tzf-rs (Rust) をラップしています。
PyO3 は FFI 境界を越えてオブジェクトのライフタイムを手動管理する必要がなくなり、
CGO が引き起こしていたメモリリーク（[tzf#63](https://github.com/ringsaturn/tzf/pull/63)）を解消し、
CPU 集約的なワークロードでより優れたスループットを提供します。
