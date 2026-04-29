---
author: ringsaturn
cover:
  image: https://blog-assets.ringsaturn.me/pic/tzf-spring-news/cover.webp
date: '2026-04-26'
description: 2026年春の tzf プロジェクトファミリーのメジャーアップデート——トポロジー認識処理を導入して簡略化ポリゴンデータのギャップと重複を解消、新しい効率的なデータ配布形式、Go および Rust 版向け YStripes インデックス高速化。パフォーマンスベンチマーク付き。
tags:
- tzf
- Side Project
- Geo
- timezone
title: tzf 2026年春のアップデート
---

> [!NOTE]
> 元々は個人ブログに公開：[tzf 2026年春のアップデート](https://blog.ringsaturn.me/en/posts/2026-04-26-tzf-spring-news/)

tzf プロジェクトファミリーが始まってから数年が経ちました。開発の歴史を体系的に振り返った最後の記事は、2023年初頭の [History of package tzf]({{< ref "/blog/history-of-tzf/index.md" >}}) でした。それ以降、さまざまな更新とメンテナンス作業がありましたが、主に非コアの最適化と補足機能に焦点を当てていました。

2026年春、長らく保留されていた重要な変更がついに完了しました：

1. ポリゴン簡略化時に生じるギャップと重複を解消するトポロジー認識処理の導入；
2. トポロジー認識処理に基づく、より効率的なデータ配布形式の開発——完全精度データで約 17 MB、簡略化データで約 5.4 MB；
3. tg プロジェクトに触発された YStripes インデックス高速化の導入。

## トポロジー認識処理

生データは本質的にポリゴンの集合です。生の境界は非常に詳細であるためデータ量が大きく、ポリゴン簡略化が必要です。これらのポリゴンの多くは境界を共有していますが、以前のアプローチでは各ポリゴンが RDP を使用して独立して簡略化されていました。これにより、プロジェクトの初期から存在していた[既知の問題](https://github.com/ringsaturn/tzf/issues/183)が発生していました：完全にカバーされるべき領域にギャップが現れ、簡略化によって意図しないポリゴンの重複が生じるのです：

![詳細は [`ringsaturn/tzf#183`](https://github.com/ringsaturn/tzf/issues/183) を参照](https://blog-assets.ringsaturn.me/pic/tzf-spring-news/issue_183.webp)

解決策は数年前から明らかでした：まず共有境界を特定し、それらの共有境界を簡略化し、簡略化された境界を両側のポリゴンに反映します。これにより、隣接するポリゴンが同じ簡略化された境界を参照し続け、各側での独立した簡略化によって生じるギャップや重複を防ぐことができます。

問題はデータセットが非常に大きいことでした。過去数年にわたり、私はこの戦略を手動で実装しようと複数回試みましたが、すべて失敗しました。エッジケースの蓄積とますます複雑になる戦略設計により、コードを安定して実行することが不可能になりました。

2026年に再挑戦した際、Claude と Codex を複数ラウンドの実装、検証、リファクタリングに使用し、ついに完全な戦略を動作させることができました。大まかな流れを以下に示します：

![ChatGPT によって作成](https://blog-assets.ringsaturn.me/pic/tzf-spring-news/topology_algo.en.webp)

この戦略が整ったことで、昨年設計された[新しいデータ保存形式の目標](https://github.com/ringsaturn/tzf/issues/191)を実装することも可能になりました。

後方互換性を維持するため、新しいバイナリデータは別のリポジトリに分割され、以下に説明する形式の改善が行われています。既存のデータ形式配布——tzf-rel シリーズ——は、非推奨となるまでしばらく継続されます。

共有境界を特定できるようになったため、長い境界を2回保存する必要はなくなり、一度保存してポリライン圧縮でエンコードします。

効果は顕著です。以前、tzf は完全データセットを pb 形式で配布しており、非圧縮で約 90 MB、zip で約 50 MB でした。現在、共有境界を1回だけ保存しポリラインエンコードすることで、完全精度データは約 17 MB、zip で約 10 MB になりました。完全精度データをこのサイズに圧縮できたことに非常に満足しています。また、まさにこの許容可能なファイルサイズのおかげで、tzf-rs はついに完全データセットをサポートするオプション機能を提供できるようになりました。以前は 90 MB のサイズのため、ユーザーは完全データセットを自分でダウンロードしてファイルパスを指定する必要がありました。

簡略化データセットについては、ポリライン圧縮を省略すると実際にはわずかなサイズ増加が生じます。その理由は、以前は破棄されていた多くの小さなポリゴンの詳細が、精度上の理由から新しい基準で保持されるようになったためです。一方で、境界自体がすでに大幅に簡略化されているため、共有境界を1回だけ保存することの利点は完全精度データほど顕著ではありません。現在、共有境界検出とポリライン処理により、簡略化データセットは約 5.4 MB であり、依然として許容可能です。

注目すべき点：tzf が完全精度データを使用する場合、実行時メモリ使用量は約 500 MB であり、これは大きいです——現時点ではこれをさらに最適化する計画はなく、この機能は当面 Python バインディングには提供されません。簡略化データセットでも約 100 MB のメモリが必要です。tzf ファミリー——特に Go、Rust、Python 版——は、最初から高並行性バックエンド API シナリオ向けに設計されており、ほぼゼロレイテンシの検索と過度に簡略化できない境界精度と引き換えに、ある程度のメモリフットプリントが許容されます。メモリ使用量、処理速度、データ精度はすべてバランスを取る必要があります。何を使用し、どのように使用するかは、最終的には各ユーザーの実際の要件に依存します。

この機能の詳細については、[`internal/topology/README.md`](https://github.com/ringsaturn/tzf/blob/v1.1.0/internal/topology/README.md) のコードドキュメントを参照してください。

現在のデータファイルは以下の通りです：

| ファイル                                          | サイズ | 説明                                                              |
| ------------------------------------------------- | ------ | ------------------------------------------------------------------------ |
| `combined-with-oceans.compress.topo.bin`          | ~17MB  | 完全精度：共有エッジ重複排除 + ポリライン圧縮                      |
| `combined-with-oceans.topology.compress.topo.bin` | ~5.4MB | ライト版：トポロジー認識簡略化 + 共有エッジ重複排除 + ポリライン圧縮 |
| `combined-with-oceans.reduce.preindex.bin`        | ~2MB   | FuzzyFinder 用タイルプレインデックス                                  |

## YStripes インデックス

明確にしておきます：YStripes インデックスは私の発明ではありません。Josh Baker の [`tidwall/tg`](https://github.com/tidwall/tg) プロジェクトに由来します。私は単にこのインデックスメカニズムを tzf の Go および Rust 版に移植しました。

この春から、このインデックスは tzf の Go および Rust 版のデフォルト戦略になりました。いくらかのメモリオーバーヘッドが追加されますが、パフォーマンスの向上はより顕著です。私のローカルベンチマークでは、単一ランダム検索が約 1 マイクロ秒まで低下しており、私が知るどのユースケースでもボトルネックになることはないはずです。

アルゴリズムの詳細についてはここでは触れません——興味があれば、[`POLYGON_INDEXING.md`](https://github.com/tidwall/tg/blob/main/docs/POLYGON_INDEXING.md) で作者の説明を直接読むことができます。

## ベンチマーク

以下は、Apple M3 Max 搭載 MacBook Pro で実行した私のローカルベンチマーク結果です。

これらの結果は主に戦略間の相対的な差を観察するためのものであり、絶対的なクロスマシンパフォーマンスの結論として受け取るべきではありません。

### tzf (Go)

| ターゲット     | データセット                 | シナリオ                                | 中央値 (ns) | p99 (ns) | おおよそのスループット (ops/s) | メモリ (MiB) |
| ------------- | --------------------------- | -------------------------------------- | ----------: | -------: | ---------------------------: | -----------: |
| DefaultFinder | topology-simplified + preindex | edge case · GetTimezoneName            |      3000.0 |   3000.0 |                       393.5K |        74.70 |
| Finder        | topology-simplified            | edge case · GetTimezoneName            |      2000.0 |   3000.0 |                       470.4K |        66.00 |
| FullFinder    | full-precision + preindex      | edge case · GetTimezoneName            |      3000.0 |   3000.0 |                       395.6K |       421.50 |
| Finder        | full-precision                 | edge case · GetTimezoneName            |      2000.0 |   3000.0 |                       475.3K |       412.70 |
| DefaultFinder | topology-simplified + preindex | random world cities · GetTimezoneName  |      1000.0 |   4000.0 |                      1162.4K |        74.70 |
| FuzzyFinder   | preindex                       | random world cities · GetTimezoneName  |       469.8 |   1000.0 |                      2128.6K |         8.90 |
| Finder        | topology-simplified            | random world cities · GetTimezoneName  |      2000.0 |   4000.0 |                       531.6K |        66.00 |
| FullFinder    | full-precision + preindex      | random world cities · GetTimezoneName  |      1000.0 |   4000.0 |                      1143.1K |       421.50 |
| Finder        | full-precision                 | random world cities · GetTimezoneName  |      2000.0 |   5000.0 |                       468.6K |       412.70 |
| DefaultFinder | topology-simplified + preindex | random world cities · GetTimezoneNames |      5000.0 |   9000.0 |                       208.0K |        74.70 |
| FuzzyFinder   | preindex                       | random world cities · GetTimezoneNames |       462.7 |   1000.0 |                      2161.2K |         8.90 |
| Finder        | topology-simplified            | random world cities · GetTimezoneNames |      5000.0 |   8000.0 |                       211.5K |        66.00 |
| FullFinder    | full-precision + preindex      | random world cities · GetTimezoneNames |      5000.0 |   9000.0 |                       192.8K |       421.50 |

### tzf-rs (Rust)

トポロジー簡略化（バンドル）：

| ターゲット     | データセット                 | シナリオ       | 中央値推定 (µs) | おおよそのスループット (ops/s) | 平均ピーク RSS (MiB) |
| ------------- | --------------------------- | ------------- | --------------: | ---------------------------: | ------------------: |
| Finder        | topology-simplified            | YStripes only |           1.2296 |                      813,273 |              103.30 |
| Finder        | topology-simplified            | No index      |           6.5402 |                      152,901 |               51.68 |
| DefaultFinder | topology-simplified + preindex | YStripes only |           1.1383 |                      878,503 |              125.98 |
| DefaultFinder | topology-simplified + preindex | No index      |           2.2514 |                      444,168 |               77.79 |

完全精度（フル）：

| ターゲット              | データセット              | シナリオ       | 中央値推定 (µs) | おおよそのスループット (ops/s) | 平均ピーク RSS (MiB) |
| ---------------------- | ------------------------ | ------------- | --------------: | ---------------------------: | ------------------: |
| Finder (full)           | full-precision            | YStripes only |           2.0852 |                      479,570 |              561.08 |
| Finder (full)           | full-precision            | No index      |          37.6980 |                       26,527 |              252.54 |
| DefaultFinder (full)    | full-precision + preindex | YStripes only |           1.3488 |                      741,400 |              584.30 |
| DefaultFinder (full)    | full-precision + preindex | No index      |          11.2750 |                       88,692 |              278.63 |

### Python

Python 版は主にバインディングであるため、ベンチマーク結果はここでは省略します。ただし言及する価値があるのは、wheel サイズが約 7 MB から約 4 MB に減少したことで、イメージビルドアーティファクトにとって小さくても嬉しい改善です。

### GitHub Actions での継続的ベンチマーク

以下は [Continuous Benchmark](https://github.com/marketplace/actions/continuous-benchmark) を通じて監視されている長期的なパフォーマンス指標です：

![tzf ns/op](https://blog-assets.ringsaturn.me/pic/tzf-spring-news/benchmark-tzf.webp)

![tzf-rs ns/iter](https://blog-assets.ringsaturn.me/pic/tzf-spring-news/benchmark-tzf-rs.webp)

![tzf iter/sec](https://blog-assets.ringsaturn.me/pic/tzf-spring-news/benchmark-tzfpy.webp)

## 終わりに

以上が、この忙しい春に完了した主な機能です。tzf プロジェクトファミリーにとって、このアップデートは当初の設計の重要なピースを埋めるものです：Go を使用してトポロジー認識ポリゴンデータセットの簡略化と配布を行い、その後 Go、Rust、Python、その他の言語版が同じデータ出力を直接再利用できるようにすること。

継続的なメンテナンスは比較的軽量で、主にデータファイルの更新、依存関係の更新、および軽微なインターフェース互換性作業に焦点を当てます。

上記の開発は異なる期間にわたって行われました。参考のための対応するリリース：

- https://github.com/ringsaturn/geometry-rs/releases/tag/v0.4.1
- https://github.com/ringsaturn/tzf-rs/releases/tag/v1.2.0
- https://github.com/ringsaturn/tzf-rs/releases/tag/v1.3.0
- https://github.com/ringsaturn/tzfpy/releases/tag/v1.2.0
- https://github.com/ringsaturn/tzfpy/releases/tag/v1.3.0
- https://github.com/ringsaturn/tzf/releases/tag/v1.1.0
- https://github.com/ringsaturn/tzf-dist/releases/tag/v0.0.2026-a
