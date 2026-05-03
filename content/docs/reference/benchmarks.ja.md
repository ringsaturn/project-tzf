---
date: "2025-07-19T13:58:16+09:00"
description: Go および Rust における tzf 実装のパフォーマンスベンチマーク。
draft: false
lastmod: "2026-04-26T00:00:00+09:00"
seo:
  description: tzf と tzf-rs のパフォーマンスベンチマーク結果——デフォルト、ファジー、完全精度ファインダー、YStripes とプレインデックスを含む。
  noindex: false
  title: ベンチマーク——Project tzf
summary: tzf (Go) と tzf-rs (Rust) のベンチマーク結果——異なるファインダータイプ、データセット、インデックスモードをカバー。
title: ベンチマーク
toc: true
weight: 4
---

プロジェクトには目的の異なる 2 つの独立したベンチマークセットアップがあります：

**継続的ベンチマーク**——ソースと結果は <https://github.com/ringsaturn/tz-benchmark>、
可視化は <https://ringsaturn.github.io/tz-benchmark/> で確認できます。
各リリース時に GitHub Actions で自動実行され、パッケージ間の比較を行います。
GitHub Actions ランナーは開発マシンとハードウェアが異なるため、
絶対値はローカル実行と異なりますが、パッケージ間の相対的な傾向が重要です。

**ローカルベンチマーク**——以下の表は Apple M3 Max 搭載 MacBook Pro で測定されました。
これらは最新ハードウェアにおける実際のレイテンシをより代表するものです。

## 方法論

各ファインダーは一度初期化され、すべてのクエリで再利用されます——推奨される本番環境パターンに従っています。
クエリは世界都市座標の代表サンプルと意図的な境界エッジケースポイントを使用します。

## Go (tzf v1.2.0)

| Target        | Dataset                            | Scenario                               | Median (ns) | p99 (ns) | Approx throughput (ops/s) | Memory (MiB) |
| ------------- | ---------------------------------- | -------------------------------------- | ----------: | -------: | ------------------------: | -----------: |
| DefaultFinder | topology-simplified + preindex     | edge case · GetTimezoneName            |       500.0 |   1250.0 |                   1694.9K |        74.90 |
| FuzzyFinder   | preindex                           | edge case · GetTimezoneName            |       250.0 |    375.0 |                   3521.1K |         2.40 |
| Finder        | topology-simplified                | edge case · GetTimezoneName            |       250.0 |    875.0 |                   3022.1K |        72.70 |
| FullFinder    | full-precision + preindex          | edge case · GetTimezoneName            |       542.0 |   1375.0 |                   1586.3K |       422.90 |
| Finder        | full-precision                     | edge case · GetTimezoneName            |       292.0 |   1167.0 |                   2678.1K |       420.70 |
| DefaultFinder | topology-simplified + preindex     | random world cities · GetTimezoneName  |       167.0 |    791.0 |                   3855.1K |        74.90 |
| FuzzyFinder   | preindex                           | random world cities · GetTimezoneName  |       167.0 |    333.0 |                   4608.3K |         2.40 |
| Finder        | topology-simplified                | random world cities · GetTimezoneName  |       209.0 |   1250.0 |                   3076.0K |        72.70 |
| FullFinder    | full-precision + preindex          | random world cities · GetTimezoneName  |       208.0 |    917.0 |                   3527.3K |       422.90 |
| Finder        | full-precision                     | random world cities · GetTimezoneName  |       250.0 |   1167.0 |                   2953.3K |       420.70 |
| Finder        | topology-simplified + GridIndex    | random world cities · GetTimezoneName  |       209.0 |   1167.0 |                   3202.0K |        72.70 |
| Finder        | topology-simplified (no GridIndex) | random world cities · GetTimezoneName  |      1833.0 |   2875.0 |                    612.4K |        67.00 |
| DefaultFinder | topology-simplified + preindex     | random world cities · GetTimezoneNames |       416.0 |   1375.0 |                   1956.9K |        74.90 |
| FuzzyFinder   | preindex                           | random world cities · GetTimezoneNames |       208.0 |    334.0 |                   4347.8K |         2.40 |
| Finder        | topology-simplified                | random world cities · GetTimezoneNames |       417.0 |   1375.0 |                   1931.2K |        72.70 |
| FullFinder    | full-precision + preindex          | random world cities · GetTimezoneNames |       459.0 |   1750.0 |                   1623.1K |       422.90 |

## Rust (tzf-rs v1.3.3)

Topology-Simplified (bundled) / Random Cities:

| Target        | Dataset                        | Scenario      | Median estimate (µs) | Approx throughput (ops/s) | Avg peak RSS (MiB) |
| ------------- | ------------------------------ | ------------- | -------------------: | ------------------------: | -----------------: |
| Finder        | topology-simplified            | YStripes only |               0.6457 |                 1,548,635 |             112.30 |
| Finder        | topology-simplified            | No index      |               4.3948 |                   227,542 |              59.92 |
| DefaultFinder | topology-simplified + preindex | YStripes only |               0.3800 |                 2,631,787 |             134.48 |
| DefaultFinder | topology-simplified + preindex | No index      |               4.4922 |                   222,608 |              85.66 |

Topology-Simplified (bundled) / Edge Cities (FuzzyFinder misses)

| Target                   | Dataset                        | Scenario                          | Median estimate (µs) | Approx throughput (ops/s) |
| ------------------------ | ------------------------------ | --------------------------------- | -------------------: | ------------------------: |
| FuzzyFinder              | preindex                       | FuzzyFinder miss                  |               0.2200 |                 4,546,074 |
| DefaultFinder (YStripes) | topology-simplified + preindex | DefaultFinder (YStripes) fallback |               0.7456 |                 1,341,184 |
| Finder                   | topology-simplified            | YStripes                          |               0.4975 |                 2,010,131 |
| Finder                   | topology-simplified            | No index                          |               4.3948 |                   227,542 |
| DefaultFinder            | topology-simplified + preindex | YStripes                          |               0.7154 |                 1,397,858 |
| DefaultFinder            | topology-simplified + preindex | No index                          |               4.4922 |                   222,608 |

Full-Precision (full):

| Target               | Dataset                   | Scenario      | Median estimate (µs) | Approx throughput (ops/s) | Avg peak RSS (MiB) |
| -------------------- | ------------------------- | ------------- | -------------------: | ------------------------: | -----------------: |
| Finder (full)        | full-precision            | YStripes only |               1.7158 |                   582,819 |             568.78 |
| Finder (full)        | full-precision            | No index      |              38.9370 |                    25,683 |             260.95 |
| DefaultFinder (full) | full-precision + preindex | YStripes only |               0.4984 |                 2,006,421 |             592.25 |
| DefaultFinder (full) | full-precision + preindex | No index      |               6.6012 |                   151,488 |             287.32 |

## Python (tzfpy v1.2.0)

tzfpy は tzf-rs の PyO3 バインディングです。ベンチマークは `pytest-benchmark` を使用し、
単一の `get_tz()` 呼び出し（ランダム座標、トポロジー簡略化データセット）を測定します。
Apple M3 Max 搭載 MacBook Pro での結果です。

| インデックスモード                            | 中央値 (µs) | 平均 (µs) | スループット (Kops/s) | メモリ  |
| --------------------------------------------- | ----------: | --------: | --------------------: | ------- |
| デフォルト（YStripes 有効）                   |      1.7934 |    1.8321 |                 545.8 | ~120 MB |
| YStripes なし（`_TZFPY_DISABLE_Y_STRIPES=1`） |      2.5213 |    2.5338 |                 394.7 | 未測定  |

呼び出しあたりのオーバーヘッドは生の Rust の数値と同程度です；tzf-rs の数値との差は
PyO3 経由の Python → Rust FFI コストを反映しています。

## 主な観察結果

- **YStripes インデックス**は完全精度 Finder に劇的な改善をもたらします：37.7 µs（インデックスなし）から 2.1 µs へ——約 18 倍の高速化。トポロジー簡略化データセットでは効果は小さいですが依然として顕著です（6.5 µs → 1.2 µs、約 5 倍）。
- **DefaultFinder**（プレインデックス + ポリゴン）は一般的なワークロードで一貫して最良です：データセットに関係なく、中央値約 1 µs、メモリ約 75–126 MB。
- **FuzzyFinder**（プレインデックスのみ）は約 470 ns で最速ですが、単一のタイムゾーンポリゴン内に完全に収まるタイルのみをカバーします。境界付近や未カバータイルのポイントでは、推測せずに結果なしを返します。ワークロードがタイムゾーン境界から十分離れていることが分かっている場合にのみ単独で使用してください。
- **Python (tzfpy)** は Rust ベースラインに加えて約 0.5–1 µs の PyO3 FFI オーバーヘッドがあります。YStripes 有効時の中央値は約 1.8 µs——ほとんどのバックエンド API の予算内に十分収まります。
- **メモリはデータセットに比例します**：Rust でトポロジー簡略化から完全精度に切り替えると、YStripes 有効時で約 450 MB 増加します。
