---
date: '2025-07-19T13:58:16+09:00'
description: Go および Rust における tzf 実装のパフォーマンスベンチマーク。
draft: false
lastmod: '2026-04-26T00:00:00+09:00'
seo:
  description: tzf と tzf-rs のパフォーマンスベンチマーク結果——デフォルト、ファジー、完全精度ファインダー、YStripes とプレインデックスを含む。
  noindex: false
  title: ベンチマーク——Project tzf
summary: tzf (Go) と tzf-rs (Rust) のベンチマーク結果——異なるファインダータイプ、データセット、インデックスモードをカバー。
title: ベンチマーク
toc: true
weight: 4
---

プロジェクトには目的の異なる2つの独立したベンチマークセットアップがあります：

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

## Go (tzf v1.1.0)

| ターゲット     | データセット                 | シナリオ                                | 中央値 (ns) | p99 (ns) | スループット (ops/s) | メモリ (MiB) |
| ------------- | --------------------------- | -------------------------------------- | ----------: | -------: | -------------------: | -----------: |
| DefaultFinder | topology-simplified + preindex | edge case · GetTimezoneName            |      3000.0 |   3000.0 |              393.5K |        74.70 |
| Finder        | topology-simplified            | edge case · GetTimezoneName            |      2000.0 |   3000.0 |              470.4K |        66.00 |
| FullFinder    | full-precision + preindex      | edge case · GetTimezoneName            |      3000.0 |   3000.0 |              395.6K |       421.50 |
| Finder        | full-precision                 | edge case · GetTimezoneName            |      2000.0 |   3000.0 |              475.3K |       412.70 |
| DefaultFinder | topology-simplified + preindex | random world cities · GetTimezoneName  |      1000.0 |   4000.0 |             1162.4K |        74.70 |
| FuzzyFinder   | preindex                       | random world cities · GetTimezoneName  |       469.8 |   1000.0 |             2128.6K |         8.90 |
| Finder        | topology-simplified            | random world cities · GetTimezoneName  |      2000.0 |   4000.0 |              531.6K |        66.00 |
| FullFinder    | full-precision + preindex      | random world cities · GetTimezoneName  |      1000.0 |   4000.0 |             1143.1K |       421.50 |
| Finder        | full-precision                 | random world cities · GetTimezoneName  |      2000.0 |   5000.0 |              468.6K |       412.70 |
| DefaultFinder | topology-simplified + preindex | random world cities · GetTimezoneNames |      5000.0 |   9000.0 |              208.0K |        74.70 |
| FuzzyFinder   | preindex                       | random world cities · GetTimezoneNames |       462.7 |   1000.0 |             2161.2K |         8.90 |
| Finder        | topology-simplified            | random world cities · GetTimezoneNames |      5000.0 |   8000.0 |              211.5K |        66.00 |
| FullFinder    | full-precision + preindex      | random world cities · GetTimezoneNames |      5000.0 |   9000.0 |              192.8K |       421.50 |

## Rust (tzf-rs v1.2.0 / v1.3.0)

### トポロジー簡略化（デフォルトバンドル）

| ターゲット     | データセット                 | シナリオ       | 中央値 (µs) | スループット (ops/s) | メモリ (MiB) |
| ------------- | --------------------------- | ------------- | ----------: | ------------------: | -----------: |
| Finder        | topology-simplified            | YStripes only |      1.2296 |             813,273 |       103.30 |
| Finder        | topology-simplified            | No index      |      6.5402 |             152,901 |        51.68 |
| DefaultFinder | topology-simplified + preindex | YStripes only |      1.1383 |             878,503 |       125.98 |
| DefaultFinder | topology-simplified + preindex | No index      |      2.2514 |             444,168 |        77.79 |

### 完全精度（オプション `full` feature）

| ターゲット              | データセット              | シナリオ       | 中央値 (µs) | スループット (ops/s) | メモリ (MiB) |
| ---------------------- | ------------------------ | ------------- | ----------: | ------------------: | -----------: |
| Finder (full)           | full-precision            | YStripes only |      2.0852 |             479,570 |       561.08 |
| Finder (full)           | full-precision            | No index      |     37.6980 |              26,527 |       252.54 |
| DefaultFinder (full)    | full-precision + preindex | YStripes only |      1.3488 |             741,400 |       584.30 |
| DefaultFinder (full)    | full-precision + preindex | No index      |     11.2750 |              88,692 |       278.63 |

## Python (tzfpy v1.2.0)

tzfpy は tzf-rs の PyO3 バインディングです。ベンチマークは `pytest-benchmark` を使用し、
単一の `get_tz()` 呼び出し（ランダム座標、トポロジー簡略化データセット）を測定します。
Apple M3 Max 搭載 MacBook Pro での結果です。

| インデックスモード                            | 中央値 (µs) | 平均 (µs) | スループット (Kops/s) | メモリ      |
| ------------------------------------------- | ----------: | --------: | -------------------: | ---------- |
| デフォルト（YStripes 有効）                   |      1.7934 |    1.8321 |                545.8 | ~120 MB    |
| YStripes なし（`_TZFPY_DISABLE_Y_STRIPES=1`） |      2.5213 |    2.5338 |                394.7 | 未測定      |

呼び出しあたりのオーバーヘッドは生の Rust の数値と同程度です；tzf-rs の数値との差は
PyO3 経由の Python → Rust FFI コストを反映しています。

## 主な観察結果

- **YStripes インデックス**は完全精度 Finder に劇的な改善をもたらします：37.7 µs（インデックスなし）から 2.1 µs へ——約 18 倍の高速化。トポロジー簡略化データセットでは効果は小さいですが依然として顕著です（6.5 µs → 1.2 µs、約 5 倍）。
- **DefaultFinder**（プレインデックス + ポリゴン）は一般的なワークロードで一貫して最良です：データセットに関係なく、中央値約 1 µs、メモリ約 75–126 MB。
- **FuzzyFinder**（プレインデックスのみ）は約 470 ns で最速ですが、単一のタイムゾーンポリゴン内に完全に収まるタイルのみをカバーします。境界付近や未カバータイルのポイントでは、推測せずに結果なしを返します。ワークロードがタイムゾーン境界から十分離れていることが分かっている場合にのみ単独で使用してください。
- **Python (tzfpy)** は Rust ベースラインに加えて約 0.5–1 µs の PyO3 FFI オーバーヘッドがあります。YStripes 有効時の中央値は約 1.8 µs——ほとんどのバックエンド API の予算内に十分収まります。
- **メモリはデータセットに比例します**：Rust でトポロジー簡略化から完全精度に切り替えると、YStripes 有効時で約 450 MB 増加します。

## 自身でベンチマークを実行する

継続的ベンチマークリポジトリには、同じスイートをローカルで実行するためのスクリプトも含まれています：

```bash
git clone https://github.com/ringsaturn/tz-benchmark
cd tz-benchmark
# 各言語のセットアップと実行手順については README に従ってください
```

絶対値はマシンによって異なります。意味のある指標として、ファインダータイプとインデックスモード間の相対的な差を使用してください。
