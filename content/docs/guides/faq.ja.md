---
date: '2025-07-19T11:07:00+09:00'
description: Project tzf のよくある質問——精度、メモリ、座標順序など。
draft: false
lastmod: '2025-07-19T11:07:00+09:00'
seo:
  description: Project tzf のよくある質問——精度、メモリ使用量、座標順序、データ更新について。
  noindex: false
  title: よくある質問——Project tzf
summary: tzf の設計、制限、使い方に関するよくある質問への回答。
title: よくある質問
toc: true
weight: 95
---

## 座標の順序は？

すべての tzf 実装は **(経度，緯度)** の順序を使用します——GeoJSON やほとんどの地理 API と同様です。
一部のシステム（Google Maps URL、多くの地理教科書など）では (緯度，経度) を使用するため、値を渡す前に再確認してください。

## tzf は 100% 正確ですか？

デフォルトではいいえ。tzf はデータサイズを削減するためにポリゴン簡略化（[Ramer–Douglas–Peucker](https://en.wikipedia.org/wiki/Ramer%E2%80%93Douglas%E2%80%93Peucker_algorithm)）を適用しており、
タイムゾーン境界から約 1 km 以内の地点では誤った結果を返す可能性があります。

100% 正確な検索には、完全データセットを使用してください：
- **Go**: `tzf.NewFullFinder()`
- **Rust**: `full` feature を有効にする（[はじめる]({{< relref "getting-started" >}})を参照）
- **Python/tzfpy**: 完全精度モードは現在サポートされていません

## tzf はどのくらいメモリを使用しますか？

| モード (Go)                                   | メモリ  |
| --------------------------------------------- | ------- |
| DefaultFinder（トポロジー簡略化 + プレインデックス） | ~75 MB |
| Finder（トポロジー簡略化）                      | ~66 MB |
| FullFinder（完全精度 + プレインデックス）       | ~422 MB |

Rust のメモリも同様です；YStripes インデックスを有効にすると約 30–40 MB 増加します。
Rust の完全精度モード（YStripes 有効）は約 560 MB を使用します。
Python は内部的に Rust バイナリを使用するため、メモリ使用量は Rust のデフォルトモードと一致します。

## 初期化が遅いのはなぜですか？

`NewDefaultFinder()` / `DefaultFinder::new()` の最初の呼び出しは、バイナリタイムゾーンデータを読み込んで解析します。
これは一度限りのコストです——その後の検索は非常に高速です。
常に一度だけ初期化し、インスタンスを再利用してください。グローバル変数や `lazy_static` を使用するパターンについては、各言語ガイドを参照してください。

## タイムゾーンデータはどのくらいの頻度で更新されますか？

tzf は [evansiroky/timezone-boundary-builder](https://github.com/evansiroky/timezone-boundary-builder) 経由で [IANA タイムゾーンデータベース](https://www.iana.org/time-zones)のリリースを追跡しています。
処理済みデータは [ringsaturn/tzf-rel](https://github.com/ringsaturn/tzf-rel) で公開されています。
ライブラリのリリースは各上流データリリースの直後に行われます。

## Finder、FuzzyFinder、DefaultFinder の違いは何ですか？

| クラス          | 使用データ            | カバレッジ                               | 速度   |
| --------------- | -------------------- | ---------------------------------------- | ------ |
| `FuzzyFinder`   | タイルプレインデックスのみ | 内部タイルのみ——境界/未カバーエリアは結果なし | 最速   |
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

また、`tzf`、`tzf-rs`、`tzfpy` には「反 CSDN ライセンス」条項が付随しており、CSDN プラットフォームでの使用を禁止しています；この条項は他のユースケースに影響しません。

詳細は [ライセンス]({{< relref "../reference/licenses" >}}) を参照してください。
