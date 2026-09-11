---
date: '2025-07-19T11:07:00+09:00'
description: 'Project tzf のよくある質問 - 精度、メモリ、座標順序など。'
draft: false
lastmod: '2026-09-11T00:00:00+09:00'
seo:
  description: 'Project tzf のよくある質問 - 精度、メモリ使用量、座標順序、データ更新について。'
  noindex: false
  title: 'よくある質問 - Project tzf'
summary: tzf の設計、制限、使い方に関するよくある質問への回答。
title: よくある質問
toc: true
weight: 95
---

## 座標の順序は？

すべての tzf 実装は **(経度，緯度)** の順序を使用します。GeoJSON やほとんどの地理 API と同じです。
一部のシステム（Google Maps URL、多くの地理教科書など）では (緯度，経度) を使用するため、値を渡す前に再確認してください。

## tzf は 100% 正確ですか？

デフォルトの Finder は、タイムゾーン境界付近で完全精度データセットと同じ結果を保証しません。epsilon が 0.001 度のトポロジー対応 [Douglas-Peucker 簡略化](https://en.wikipedia.org/wiki/Ramer%E2%80%93Douglas%E2%80%93Peucker_algorithm)を使用し、境界の変位を約 111 m 以内に抑えています。

完全精度の 2026c データセットと比較した測定結果は [BORDER_CHANGE.md](https://github.com/ringsaturn/tzf/blob/main/BORDER_CHANGE.md) に記録されています。

| 指標                                   | 結果                         |
| -------------------------------------- | ---------------------------- |
| 認証済みの最大境界変位                 | 111.7 m、許容誤差 1.0 m     |
| 100 m を超えて変位した境界長の割合     | 0.41%                        |
| 500 m を超えて変位した境界長の割合     | 0%                           |
| 誤って割り当てられた総面積             | 16,962 km²、地球面積の約 0.003% |
| 真の境界から 100 m 以内にある誤割当面積の割合 | 92.8%                 |

完全精度の結果と異なる可能性があるのは、タイムゾーン境界から約 111 m 以内のクエリのみです。影響を受ける帯域の大部分はさらに狭くなっています。

100% 正確な検索には、完全データセットを使用してください：

- **Go**: `tzf.NewFullFinder()`
- **Rust**: `default-features = false` を指定して git 限定の `full` feature を有効にする（[はじめる]({{< relref "getting-started#rust" >}})を参照）
- **Python/tzfpy**: 完全精度モードは現在サポートされていません

[tz-benchmark](https://github.com/ringsaturn/tz-benchmark) の 2026-09-11 スナップショットでは、lite の Finder は 154,694 件の世界都市のうち 1 件（0.0006%）で完全精度の正解データと異なる結果を返し、その 1 件も UTC オフセットは同じでした。

## tzf はどのくらいメモリを使用しますか？

初期化コストと実行時コストは同じ数値ではありません。Finder の構築では、最終的に保持する量よりはるかに多くのメモリを確保します。ファイルをデコードし、そこからクエリ構造を構築し、中間表現はその後不要になります。しかしメモリを解放しても RSS は縮みません。アロケータが再利用のためにページを保持し続けるからです。そのため、Finder が定常状態で保持しているデータは、ロード中の高水位より数倍小さくなります。

以下の数値は [2026-09-11 のベンチマークスナップショット](https://github.com/ringsaturn/tz-benchmark/tree/main/snapshot)のもので、Apple M3 Max で `2026c` データセットを対象に測定されています。各候補は隔離された子プロセスで実行されます。

| 実装 | Finder | 初期化ピーク | 常駐 | ロード後 RSS |
| ------ | ------ | -----------: | ---: | -----------: |
| Go | `NewDefaultFinder`（lite `.tzm`） | 43.4 MiB | 13.1 MiB | 43.4 MiB |
| Go | `NewEmbeddedFinder`（lite `.tzb` をインプレースで参照） | 8.7 MiB | 0.3 MiB | 9.1 MiB |
| Go | `NewFullFinder`（full `.tzb`） | 315.0 MiB | 147.0 MiB | 315.0 MiB |
| Rust | `DefaultFinder` | 46.8 MiB | 22.8 MiB | 46.8 MiB |
| Rust | `EmbeddedFinder` | 9.8 MiB | 約 0 MiB | 9.8 MiB |
| Python | tzfpy（デフォルト Finder） | 62.3 MiB | n/a | 62.2 MiB |

- **初期化ピーク**は、ロード中に到達する高水位（`ru_maxrss`）です。コンテナのメモリ上限はこの値を収容できる必要があります。そうでなければ、定常状態なら収まるはずのプロセスが起動時に kill されます。
- **常駐**は、Finder がクエリを処理できる状態になった後に保持しているデータ量で、言語ネイティブの計測（Go は強制 GC 後の `HeapAlloc`、Rust はカウント機能付きグローバルアロケータ）によるものです。Python は Python ヒープの外にデータを保持するため `n/a` です。Rust の `EmbeddedFinder` が約 0 となるのは、データがヒープではなく `'static` の埋め込みスライスであるためです。
- 同じハーネスにおけるランタイムの下限値は Go が 4.7 MiB、Rust が 5.8 MiB、Python インタプリタが 22.4 MiB です。言語間で比較する際はこれらを差し引いてください。

コンテナのメモリは初期化ピークに合わせて確保しつつ、長期運用時の実コストは常駐値で見積もってください。実際のメモリ使用量は、プラットフォーム、アロケータ、データセットのバージョンによって異なります。

## 初期化が遅いのはなぜですか？

`NewDefaultFinder()` / `DefaultFinder::new()` の最初の呼び出しは、バイナリタイムゾーンデータを読み込んで解析します。
これは一度限りのコストで、その後の検索は非常に高速です。
常に一度だけ初期化し、インスタンスを再利用してください。グローバル変数や `lazy_static` を使用するパターンについては、各言語ガイドを参照してください。

## タイムゾーンデータはどのくらいの頻度で更新されますか？

tzf は [evansiroky/timezone-boundary-builder](https://github.com/evansiroky/timezone-boundary-builder) 経由で [IANA タイムゾーンデータベース](https://www.iana.org/time-zones)のリリースを追跡しています。
処理済みデータは [ringsaturn/tzf-dist](https://github.com/ringsaturn/tzf-dist) で `lite.tzb`、`lite.tzm`、`full.tzb` として公開されており、いずれも同じ `data_version` を持ちます。
ライブラリのリリースは各上流データリリースの直後に行われます。

以前の `tzf-rel` / `tzf-rel-lite` の protobuf 成果物は配布されなくなりました。v1 のライブラリ系列（tzf v1.2.x、tzf-rs 1.3.x、tzfpy 1.3.x）は引き続き動作しますが、最後の protobuf データリリースで凍結されます。更新された境界データを使用するには v2 への移行が必要です。

## どの Finder を使用すべきですか？

v2 では単独の `FuzzyFinder` を削除しました。タイルプレインデックスは、FUZZY セクションを持つデータファイルを読むすべての Finder 内部の高速パスになりました。tzf-dist の 3 つの成果物はいずれもこのセクションを持ちます。カバーするタイルがあればクエリはただちに解決され、境界付近では Finder が内部で point-in-polygon にフォールバックするため、呼び出し側が空結果を処理する必要はありません。

| Go のコンストラクタ | Rust | データ | 常駐 | クエリ |
| --- | --- | --- | --- | --- |
| `NewDefaultFinder()` | `DefaultFinder::new()` | lite メモリイメージ / lite を展開 | ヒープ約 12 MB + 読み取り専用 10 MB（Go） | 約 300 ns |
| `NewEmbeddedFinder()` | `EmbeddedFinder::new()` | lite ファイルをインプレースで参照 | 約 3 MB（Go） | 約 6 µs |
| `NewFullFinder()` | `DefaultFinder::new_full()` | 完全精度 | 約 145 MB（Go） | 約 300 ns |

パッケージのドキュメントでは `NewDefaultFinder()` / `DefaultFinder::new()` を汎用の Finder として位置づけています。シングルコアの Pod やファイルシステムのない環境を含むその他のケースの実測値は [Finder の選択]({{< relref "choosing-a-finder" >}})に記載しています。

## protobuf はどうなりましたか？

v2 で削除されました。境界データは TZF 埋め込みバイナリ形式で配布されます。転送用が `.tzb`、Go のメモリイメージが `.tzm` です。どちらも、ファイルをオブジェクトグラフに解析することなく直接クエリできるレイアウトになっています。`NewEmbeddedFinder` が読み込むのはこのレイアウトであり、オープン時間も短縮されました。Apple M3 Max では、Go の完全精度 Finder は protobuf 経路の 288 ms に対して 78.5 ms でオープンします。

形式については[埋め込みバイナリ形式]({{< relref "../reference/embedded-binary-format" >}})を、移行表については各言語のガイドを参照してください。

## tzf はどのようなライセンスですか？

コードは MIT ライセンスです。タイムゾーンデータ（`tzf-dist` 経由で配布）は上流の [evansiroky/timezone-boundary-builder](https://github.com/evansiroky/timezone-boundary-builder) と同様に [ODbL](https://opendatacommons.org/licenses/odbl/) です。

詳細は [ライセンス]({{< relref "../reference/licenses" >}}) を参照してください。
