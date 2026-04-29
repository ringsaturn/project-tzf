---
date: '2025-07-21T10:52:43+09:00'
description: Project tzf の開発史——最初の Go 実装から 2026 年春のアップデートまで。
draft: false
lastmod: '2026-04-26T00:00:00+09:00'
seo:
  description: Project tzf の開発タイムライン——2022 年の最初の Go リリースから 2025 年の v1.0.0 安定版リリースまで。
  noindex: false
  title: タイムライン——Project tzf
summary: tzf エコシステムにおける主要マイルストーンの時系列の歴史。
title: タイムライン
toc: true
weight: 5
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
（[tzf#183](https://github.com/ringsaturn/tzf/issues/183)）を解決——独立した
ポリゴンごとの RDP 簡略化が共有タイムゾーン境界にギャップと重複を生じさせていました。
新しいアプローチでは、まず共有エッジを検出し、一度だけ簡略化してから、
簡略化された境界を両方の隣接ポリゴンに反映します。

**新しいデータ配布リポジトリ** [`ringsaturn/tzf-dist`](https://github.com/ringsaturn/tzf-dist)
を導入し、新しい `CompressedTopoTimezones` 形式でデータを配布：

| ファイル | サイズ | 説明 |
| --- | --- | --- |
| `combined-with-oceans.compress.topo.bin` | 約 17 MB | 完全精度 |
| `combined-with-oceans.topology.compress.topo.bin` | 約 5.4 MB | トポロジー簡略化（ライト版） |
| `combined-with-oceans.reduce.preindex.bin` | 約 2 MB | タイルプレインデックス |

完全精度データセットが約 90 MB から約 17 MB に縮小され、
tzf-rs v1.3.0 でオプションの Cargo feature として提供可能になりました
（`DefaultFinder::new_full()`）。

**YStripes 空間インデックス**（[`tidwall/tg`](https://github.com/tidwall/tg) から移植）が
tzf v1.1.0 (Go) および tzf-rs v1.2.0 (Rust) でデフォルトのポリゴンレベルインデックスに。
Apple M3 Max で単一ランダム都市検索が約 1 µs。

この波のリリース：tzf v1.1.0、tzf-rs v1.2.0 / v1.3.0、tzfpy v1.2.0 / v1.3.0、
tzf-dist v0.0.2026-a、geometry-rs v0.4.1。

詳細はブログ記事 [tzf 2026 年春のアップデート]({{< ref "/blog/2026-spring-news/index.md" >}}) をご覧ください。
