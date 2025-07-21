---
title: "Best Practices for tzf-rs"
description: ""
summary: ""
date: 2025-07-21T14:19:40+09:00
lastmod: 2025-07-21T14:19:40+09:00
draft: false
weight: 1001
toc: true
seo:
  title: "" # custom title (optional)
  description: "" # custom description (recommended)
  canonical: "" # custom canonical URL (optional)
  noindex: false # false (default) or true
---

It's expensive to init tzf-rs's `Finder`/`FuzzyFinder`/`DefaultFinder`, so
please consider reusing instances or creating one as a global variable. Below is
a global variable example:

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
    // Please note coords are lng-lat.
    print!("{:?}\n", FINDER.get_tz_name(116.3883, 39.9289));
    print!("{:?}\n", FINDER.get_tz_names(116.3883, 39.9289));
}
```

For reuse,
[`racemap/rust-tz-service`](https://github.com/racemap/rust-tz-service) provides
a good example.

A Redis protocol demo could be used here:
[`ringsaturn/redizone`](https://github.com/ringsaturn/redizone).
