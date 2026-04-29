---
date: '2025-07-21T14:19:40+09:00'
description: Rust 版 tzf-rs 的最佳实践和高级用法模式。
draft: false
lastmod: '2025-07-21T14:19:40+09:00'
seo:
  description: Rust tzf-rs 库的最佳实践——复用 Finder 实例、YStripes 索引、完整精度模式以及集成 HTTP 和 Redis 服务。
  noindex: false
  title: Rust (tzf-rs) 指南——Project tzf
summary: tzf-rs 在 Rust 中的最佳实践——Finder 复用、YStripes 索引、完整精度模式和集成模式。
title: Rust (tzf-rs)
toc: true
weight: 2
---

## 复用 Finder

初始化 `Finder`、`FuzzyFinder` 或 `DefaultFinder` 开销较大——需要加载和解析时区数据文件。
请始终复用单个实例，例如使用 `lazy_static` 全局变量：

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
    // 坐标采用 (经度，纬度) 顺序。
    print!("{:?}\n", FINDER.get_tz_name(116.3883, 39.9289));
    print!("{:?}\n", FINDER.get_tz_names(116.3883, 39.9289));
}
```

## YStripes 索引（自 v1.2.0 起默认启用）

`DefaultFinder::new()` 默认启用 YStripes 空间索引，在现代硬件上单次随机查询约 1 µs。如需关闭（例如为了减少内存或构建时间）：

```rust
use tzf_rs::{DefaultFinder, FinderOptions};

fn main() {
    let finder = DefaultFinder::new_with_options(FinderOptions::no_index());
    println!("{}", finder.get_tz_name(139.767125, 35.681236));
}
```

| 索引模式    | 构建时间 | 内存   |
| ----------- | -------: | ----: |
| 无索引      |   ~40ms | ~70 MB |
| YStripes    |   ~50ms | ~110 MB |

## 完整精度模式（v1.3.0+）

默认情况下 tzf-rs 使用拓扑简化数据（约 5.4 MB）。如需 100% 准确的查询结果，
启用 `full` feature（完整数据集约 17 MB；因超出 crates.io 大小限制，需通过 git 依赖引用）：

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

完整精度模式使用的内存显著增加（启用 YStripes 索引时约 560 MB）。

## 集成示例

- HTTP 服务：[`racemap/rust-tz-service`](https://github.com/racemap/rust-tz-service) 演示了如何在 Axum Web 服务器中封装 tzf-rs。
- Redis 协议：[`ringsaturn/redizone`](https://github.com/ringsaturn/redizone) 演示了基于 tzf-rs 构建的 Redis 兼容服务器。
