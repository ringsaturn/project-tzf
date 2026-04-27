---
title: "Rust (tzf-rs)"
description: "Best practices and advanced usage patterns for the Rust implementation of tzf."
summary: "Best practices for using tzf-rs in Rust — including global finder reuse and integration patterns."
date: 2025-07-21T14:19:40+09:00
lastmod: 2025-07-21T14:19:40+09:00
draft: false
weight: 2
toc: true
seo:
  title: "Rust (tzf-rs) Guide — Project tzf"
  description: "Best practices for the Rust tzf-rs library — reusing Finder instances and integrating with HTTP and Redis services."
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

## Integration examples

- HTTP service: [`racemap/rust-tz-service`](https://github.com/racemap/rust-tz-service) shows how to wrap tzf-rs in an Axum web server.
- Redis protocol: [`ringsaturn/redizone`](https://github.com/ringsaturn/redizone) demonstrates a Redis-compatible server built on tzf-rs.
