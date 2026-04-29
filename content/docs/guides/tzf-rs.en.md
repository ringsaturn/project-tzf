---
title: "Rust (tzf-rs)"
description: "Best practices and advanced usage patterns for the Rust implementation of tzf."
summary: "Best practices for using tzf-rs in Rust — Finder reuse, YStripes index, full-precision mode, and integration patterns."
date: 2025-07-21T14:19:40+09:00
lastmod: 2025-07-21T14:19:40+09:00
draft: false
weight: 2
toc: true
seo:
  title: "Rust (tzf-rs) Guide — Project tzf"
  description: "Best practices for the Rust tzf-rs library — reusing Finder instances, YStripes index, full-precision mode, and integrating with HTTP and Redis services."
  noindex: false
---

## Reuse the Finder

Initializing a `Finder`, `FuzzyFinder`, or `DefaultFinder` is expensive — it loads and parses the timezone data.
Always reuse a single instance, for example as a `lazy_static` global:

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
    // Coordinates are in (longitude, latitude) order.
    print!("{:?}\n", FINDER.get_tz_name(116.3883, 39.9289));
    print!("{:?}\n", FINDER.get_tz_names(116.3883, 39.9289));
}
```

## YStripes index (default since v1.2.0)

`DefaultFinder::new()` enables the YStripes spatial index by default, bringing single random lookup to
~1 µs on modern hardware. To opt out (e.g. to reduce memory or build time):

```rust
use tzf_rs::{DefaultFinder, FinderOptions};

fn main() {
    let finder = DefaultFinder::new_with_options(FinderOptions::no_index());
    println!("{}", finder.get_tz_name(139.767125, 35.681236));
}
```

| Index mode    | Build time | Memory |
| ------------- | ---------: | -----: |
| No index      |       ~40ms | ~70 MB |
| YStripes      |       ~50ms | ~110 MB |

## Full-precision mode (v1.3.0+)

By default tzf-rs uses topology-simplified data (~5.4 MB). For 100% accurate lookups,
enable the `full` feature (full dataset ~17 MB; not on crates.io due to size limits):

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

Full-precision mode uses significantly more memory (~560 MB with YStripes index).

## Integration examples

- HTTP service: [`racemap/rust-tz-service`](https://github.com/racemap/rust-tz-service) shows how to wrap tzf-rs in an Axum web server.
- Redis protocol: [`ringsaturn/redizone`](https://github.com/ringsaturn/redizone) demonstrates a Redis-compatible server built on tzf-rs.
