---
date: '2025-07-21T14:19:40+09:00'
description: Rust 版 tzf-rs のベストプラクティスと高度な使用パターン。
draft: false
lastmod: '2025-07-21T14:19:40+09:00'
seo:
  description: Rust tzf-rs ライブラリのベストプラクティス——Finder インスタンスの再利用、YStripes インデックス、完全精度モード、HTTP および Redis サービスとの統合。
  noindex: false
  title: Rust (tzf-rs) ガイド——Project tzf
summary: Rust で tzf-rs を使用する際のベストプラクティス——Finder の再利用、YStripes インデックス、完全精度モード、統合パターン。
title: Rust (tzf-rs)
toc: true
weight: 2
---

## Finder の再利用

`Finder`、`FuzzyFinder`、`DefaultFinder` の初期化は高コストです——タイムゾーンデータを読み込んで解析します。
常に単一のインスタンスを再利用してください。例えば `lazy_static` グローバル変数として：

```bash
cargo add tzf-rs lazy_static
```

```rust {hl_lines=["4-6"]}
use lazy_static::lazy_static;
use tzf_rs::DefaultFinder;

lazy_static! {
    static ref FINDER: DefaultFinder = DefaultFinder::new();
}

fn main() {
    // 座標は (経度, 緯度) の順です。
    print!("{:?}\n", FINDER.get_tz_name(116.3883, 39.9289));
    print!("{:?}\n", FINDER.get_tz_names(116.3883, 39.9289));
}
```

## YStripes インデックス (v1.2.0 以降デフォルト)

`DefaultFinder::new()` は YStripes 空間インデックスをデフォルトで有効にし、最新のハードウェアで単一ランダム検索を約 1 µs にします。無効にするには（メモリやビルド時間を削減する場合）：

```rust
use tzf_rs::{DefaultFinder, FinderOptions};

fn main() {
    let finder = DefaultFinder::new_with_options(FinderOptions::no_index());
    println!("{}", finder.get_tz_name(139.767125, 35.681236));
}
```

| インデックスモード | ビルド時間 | メモリ  |
| ----------------- | --------: | -----: |
| インデックスなし  |    ~40ms | ~70 MB |
| YStripes          |    ~50ms | ~110 MB |

## 完全精度モード (v1.3.0+)

デフォルトでは tzf-rs はトポロジー簡略化データ（約 5.4 MB）を使用します。100% 正確な検索には
`full` feature を有効にします（完全データセット約 17 MB；サイズ制限のため crates.io ではなく git 依存関係で利用）：

```toml
[dependencies]
tzf-rs = { git = "https://github.com/ringsaturn/tzf-rs", tag = "v{X}.{Y}.{Z}", features = ["full"], default-features = false }
```

```rust
use tzf_rs::DefaultFinder;

fn main() {
    let finder = DefaultFinder::new_full();
    let tz_name = finder.get_tz_name(139.767125, 35.681236);
    println!("tz_name: {}", tz_name);
}
```

完全精度モードは大幅に多くのメモリを使用します（YStripes インデックス有効時で約 560 MB）。

## 統合例

- HTTP サービス：[`racemap/rust-tz-service`](https://github.com/racemap/rust-tz-service) は Axum Web サーバーで tzf-rs をラップする方法を示しています。
- Redis プロトコル：[`ringsaturn/redizone`](https://github.com/ringsaturn/redizone) は tzf-rs 上に構築された Redis 互換サーバーを示しています。
