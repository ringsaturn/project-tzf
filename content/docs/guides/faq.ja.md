---
date: '2025-07-19T11:07:00+09:00'
description: 'Project tzf のよくある質問 - 精度、メモリ、座標順序など。'
draft: false
lastmod: '2026-07-17T22:31:39+09:00'
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
| 認証済みの最大境界変位                 | 111.2 m、許容誤差 1.0 m     |
| 100 m を超えて変位した境界長の割合     | 0.41%                        |
| 500 m を超えて変位した境界長の割合     | 0%                           |
| 誤って割り当てられた総面積             | 16,828 km²、地球面積の約 0.003% |
| 真の境界から 100 m 以内にある誤割当面積の割合 | 92.8%                 |

完全精度の結果と異なる可能性があるのは、タイムゾーン境界から約 111 m 以内のクエリのみです。影響を受ける帯域の大部分はさらに狭くなっています。

100% 正確な検索には、完全データセットを使用してください：

- **Go**: `tzf.NewFullFinder()`
- **Rust**: `full` feature を有効にする（[はじめる]({{< relref "getting-started#rust" >}})を参照）
- **Python/tzfpy**: 完全精度モードは現在サポートされていません

## tzf はどのくらいメモリを使用しますか？

以下のピーク常駐メモリは、Apple M3 Max で測定した [2026-07-14 ベンチマークスナップショット](https://github.com/ringsaturn/tz-benchmark/blob/main/snapshot/2026-07-14-91bb3495bd282773baf61eac79a5f258b54d5656/README.md#memory)の値です。増分は Go、Rust、Python ランタイムのベースラインを除いた値です。

| 実装   | モード                                  | ピーク RSS | ベースラインからの増分 |
| ------ | --------------------------------------- | ---------: | ---------------------: |
| Go     | `FuzzyFinder`（プレインデックスのみ）   |   30.3 MiB |               24.7 MiB |
| Go     | `Finder`（トポロジー簡略化）            |  114.7 MiB |              109.0 MiB |
| Go     | `DefaultFinder`（簡略化 + プレインデックス） | 132.9 MiB |          127.1 MiB |
| Go     | `FullFinder`（完全精度 + プレインデックス） | 363.7 MiB |          357.9 MiB |
| Rust   | `FuzzyFinder`（プレインデックスのみ）   |   23.9 MiB |               18.1 MiB |
| Rust   | `Finder`（トポロジー簡略化）            |   48.6 MiB |               42.8 MiB |
| Rust   | `DefaultFinder`（簡略化 + プレインデックス） | 77.4 MiB |           71.5 MiB |
| Python | tzfpy `DefaultFinder`                   |   92.4 MiB |               69.8 MiB |

実際のメモリ使用量は、プラットフォーム、アロケータ、データセットのバージョンによって異なります。

## 初期化が遅いのはなぜですか？

`NewDefaultFinder()` / `DefaultFinder::new()` の最初の呼び出しは、バイナリタイムゾーンデータを読み込んで解析します。
これは一度限りのコストで、その後の検索は非常に高速です。
常に一度だけ初期化し、インスタンスを再利用してください。グローバル変数や `lazy_static` を使用するパターンについては、各言語ガイドを参照してください。

## タイムゾーンデータはどのくらいの頻度で更新されますか？

tzf は [evansiroky/timezone-boundary-builder](https://github.com/evansiroky/timezone-boundary-builder) 経由で [IANA タイムゾーンデータベース](https://www.iana.org/time-zones)のリリースを追跡しています。
処理済みデータは [ringsaturn/tzf-rel](https://github.com/ringsaturn/tzf-rel) で公開されています。
ライブラリのリリースは各上流データリリースの直後に行われます。

## Finder、FuzzyFinder、DefaultFinder の違いは何ですか？

| クラス          | 使用データ            | カバレッジ                               | 速度   |
| --------------- | -------------------- | ---------------------------------------- | ------ |
| `FuzzyFinder`   | タイルプレインデックスのみ | 内部タイルのみ、境界/未カバーエリアは結果なし | 最速   |
| `Finder`        | ポリゴンデータ         | 全世界をカバー                            | 高速   |
| `DefaultFinder` | タイルプレインデックス + ポリゴン | 全世界をカバー                    | 高速   |

**FuzzyFinder** プレインデックスは、単一のタイムゾーンポリゴン内に完全に収まるタイルのみを保存します。
クエリポイントがカバーされたタイル内にある場合、すぐに正しいタイムゾーンを返します。
カバーされていないエリア（境界付近、海岸線、疎な地域）では、推測せずに結果なしを返します。
「近似」ではありません：結果は正確ですが、カバレッジが不完全です。

**DefaultFinder**（推奨）は、最初にタイルプレインデックスを試み、結果が返されなかった場合に完全な
ポリゴン検索にフォールバックします。これにより、ほとんどの世界都市クエリでほぼ一定の速度を保ちながら、
すべての座標に対して正確な結果を得られます。

## tzf はどのようなライセンスですか？

コードは MIT ライセンスです。タイムゾーンデータ（`tzf-rel` 経由で配布）は上流の [evansiroky/timezone-boundary-builder](https://github.com/evansiroky/timezone-boundary-builder) と同様に [ODbL](https://opendatacommons.org/licenses/odbl/) です。

また、`tzf`、`tzf-rs`、`tzfpy` には「反 CSDN ライセンス」条項が付随しており、CSDN プラットフォームでの使用を禁止しています。この条項は他のユースケースに影響しません。

詳細は [ライセンス]({{< relref "../reference/licenses" >}}) を参照してください。
