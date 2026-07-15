---
date: "2025-07-19T13:58:16+09:00"
description: Go および Rust における tzf 実装のパフォーマンスベンチマーク。
draft: false
lastmod: "2026-07-15T00:00:00+09:00"
seo:
  description: tzf と tzf-rs のパフォーマンスベンチマーク結果 - デフォルト、ファジー、完全精度ファインダー、YStripes とプレインデックスを含む。
  noindex: false
  title: ベンチマーク - Project tzf
summary: tzf (Go) と tzf-rs (Rust) のベンチマーク結果 - 異なるファインダータイプ、データセット、インデックスモードをカバー。
title: ベンチマーク
toc: true
weight: 4
---

プロジェクトには目的の異なる 2 つの独立したベンチマークセットアップがあります：

**継続的ベンチマーク**：ソースと結果は <https://github.com/ringsaturn/tz-benchmark>、
可視化は <https://ringsaturn.github.io/tz-benchmark/> で確認できます。
各リリース時に GitHub Actions で自動実行され、パッケージ間の比較を行います。
GitHub Actions ランナーは開発マシンとハードウェアが異なるため、
絶対値はローカル実行と異なりますが、パッケージ間の相対的な傾向が重要です。

**ローカルベンチマーク**：以下の表は Apple M3 Max 搭載 MacBook Pro で測定されました。
これらは最新ハードウェアにおける実際のレイテンシをより代表するものです。

## 方法論

各ファインダーは一度初期化され、すべてのクエリで再利用されます。これは推奨される本番環境パターンです。
クエリは世界都市座標の代表サンプルと意図的な境界エッジケースポイントを使用します。

## Go (tzf v1.2.3)

| Target        | Dataset                            | Scenario                               | Median (ns) | p99 (ns) | Approx throughput (ops/s) | Memory (MiB) |
| ------------- | ---------------------------------- | -------------------------------------- | ----------: | -------: | ------------------------: | -----------: |
| DefaultFinder | topology-simplified + preindex     | edge case · GetTimezoneName            |       625.0 |   2250.0 |                   1083.8K |        31.90 |
| FuzzyFinder   | preindex                           | edge case · GetTimezoneName            |       250.0 |    542.0 |                   3216.5K |         2.40 |
| Finder        | topology-simplified                | edge case · GetTimezoneName            |       334.0 |   1667.0 |                   2145.0K |        29.70 |
| FullFinder    | full-precision + preindex          | edge case · GetTimezoneName            |       709.0 |   2875.0 |                   1111.7K |       155.30 |
| Finder        | full-precision                     | edge case · GetTimezoneName            |       416.0 |   2709.0 |                   1652.6K |       153.00 |
| DefaultFinder | topology-simplified + preindex     | random world cities · GetTimezoneName  |       208.0 |   1208.0 |                   3283.0K |        31.90 |
| FuzzyFinder   | preindex                           | random world cities · GetTimezoneName  |       208.0 |    542.0 |                   3717.5K |         2.40 |
| Finder        | topology-simplified                | random world cities · GetTimezoneName  |       292.0 |   2208.0 |                   2058.0K |        29.70 |
| FullFinder    | full-precision + preindex          | random world cities · GetTimezoneName  |       208.0 |   1375.0 |                   3147.6K |       155.30 |
| Finder        | full-precision                     | random world cities · GetTimezoneName  |       333.0 |   1959.0 |                   1993.6K |       153.00 |
| Finder        | topology-simplified + GridIndex    | random world cities · GetTimezoneName  |       250.0 |   1667.0 |                   2387.2K |        29.70 |
| Finder        | topology-simplified (no GridIndex) | random world cities · GetTimezoneName  |      2292.0 |   4375.0 |                    471.7K |        24.00 |
| DefaultFinder | topology-simplified + preindex     | random world cities · GetTimezoneNames |       625.0 |   3833.0 |                    971.8K |        31.90 |
| FuzzyFinder   | preindex                           | random world cities · GetTimezoneNames |       209.0 |    583.0 |                   3534.8K |         2.40 |
| Finder        | topology-simplified                | random world cities · GetTimezoneNames |       583.0 |   2833.0 |                   1277.3K |        29.70 |
| FullFinder    | full-precision + preindex          | random world cities · GetTimezoneNames |       709.0 |   3292.0 |                   1059.0K |       155.30 |

## Rust (tzf-rs v1.3.6)

Topology-Simplified (bundled) / Random Cities

| Target        | Dataset                        | Scenario      | Median estimate (µs) | Approx throughput (ops/s) | Avg peak RSS (MiB) |
| ------------- | ------------------------------ | ------------- | -------------------: | ------------------------: | -----------------: |
| Finder        | topology-simplified            | YStripes only |               0.5698 |                 1,755,033 |              69.72 |
| Finder        | topology-simplified            | No index      |               4.9164 |                   203,401 |              42.46 |
| DefaultFinder | topology-simplified + preindex | YStripes only |               0.3040 |                 3,289,365 |              82.10 |
| DefaultFinder | topology-simplified + preindex | No index      |               5.0438 |                   198,263 |              58.11 |

Topology-Simplified (bundled) / Edge Cities (FuzzyFinder misses)

| Target                   | Dataset                        | Scenario                          | Median estimate (µs) | Approx throughput (ops/s) |
| ------------------------ | ------------------------------ | --------------------------------- | -------------------: | ------------------------: |
| FuzzyFinder              | preindex                       | FuzzyFinder miss                  |               0.1564 |                 6,393,044 |
| DefaultFinder (YStripes) | topology-simplified + preindex | DefaultFinder (YStripes) fallback |               0.6256 |                 1,598,338 |
| Finder                   | topology-simplified            | YStripes                          |               0.4421 |                 2,261,676 |
| Finder                   | topology-simplified            | No index                          |               4.9164 |                   203,401 |
| DefaultFinder            | topology-simplified + preindex | YStripes                          |               0.6069 |                 1,647,718 |
| DefaultFinder            | topology-simplified + preindex | No index                          |               5.0438 |                   198,263 |

Full-Precision (full)

| Target               | Dataset                   | Scenario      | Median estimate (µs) | Approx throughput (ops/s) | Avg peak RSS (MiB) |
| -------------------- | ------------------------- | ------------- | -------------------: | ------------------------: | -----------------: |
| Finder (full)        | full-precision            | YStripes only |               1.2227 |                   817,862 |             314.59 |
| Finder (full)        | full-precision            | No index      |              43.0520 |                    23,228 |             157.02 |
| DefaultFinder (full) | full-precision + preindex | YStripes only |               0.5527 |                 1,809,136 |             323.58 |
| DefaultFinder (full) | full-precision + preindex | No index      |               7.4823 |                   133,649 |             171.44 |

## Python (tzfpy v1.3.2)

tzfpy は tzf-rs の PyO3 バインディングです。ベンチマークは `pytest-benchmark` を使用し、
単一の `get_tz()` 呼び出し（ランダム座標、トポロジー簡略化データセット）を測定します。
Apple M3 Max 搭載 MacBook Pro での結果です。

| インデックスモード                            | 中央値 (µs) | 平均 (µs) | スループット (Kops/s) |   メモリ |
| --------------------------------------------- | ----------: | --------: | --------------------: | -------: |
| デフォルト（YStripes 有効）                   |      0.6533 |    0.6711 |                1490.1 | ~70.5 MB |
| YStripes なし（`_TZFPY_DISABLE_Y_STRIPES=1`） |      1.6410 |    1.6548 |                 604.3 | ~57.5 MB |

呼び出しあたりのオーバーヘッドは生の Rust の数値と同程度です。tzf-rs の数値との差は
PyO3 経由の Python → Rust FFI コストを反映しています。

## 主な観察結果

- **YStripes はポリゴン検索のレイテンシを大幅に短縮します**。Rust の `Finder` では、完全精度データの中央値が 43.0520 µs から 1.2227 µs へ短縮され、35.2 倍高速になります。トポロジー簡略化データでは 4.9164 µs から 0.5698 µs へ短縮され、8.6 倍高速になります。
- **DefaultFinder は汎用用途で最も優れた Rust の選択肢です**。中央値はトポロジー簡略化データで 0.3040 µs、完全精度データで 0.5527 µs です。プレインデックスによるメモリ増加は、対応する YStripes 有効の `Finder` と比べて約 9 から 12 MiB です。
- **FuzzyFinder はフォールバックと組み合わせる高速パスに適しています**。ミスは 0.1564 µs で完了し、`DefaultFinder` は同じ境界都市のワークロードを YStripes フォールバック経由で 0.6256 µs で解決します。単独利用は、クエリがタイムゾーン境界から離れていると分かっている場合に限って適しています。
- **Python でも YStripes の効果は顕著です**。tzfpy の中央値は 1.6410 µs から 0.6533 µs へ短縮され、スループットは 604.3 Kops/s から 1490.1 Kops/s へ約 2.5 倍向上します。
- **完全精度データには明確なメモリコストがあります**。YStripes 有効時にトポロジー簡略化データから完全精度データへ切り替えると、Rust のピーク RSS は約 241 から 245 MiB 増加します。Go では、対応する Finder のメモリが約 30 MiB から約 153 から 155 MiB へ増加します。
