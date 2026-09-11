---
date: '2025-07-21T14:19:40+09:00'
description: Best practices and advanced usage patterns for the Rust implementation of tzf (v2).
draft: false
lastmod: '2026-09-11T00:00:00+09:00'
seo:
  description: Best practices for the Rust tzf-rs v2 crate — DefaultFinder and EmbeddedFinder, cargo features, GeoJSON export, and migrating from v1.
  noindex: false
  title: Rust (tzf-rs) Guide — Project tzf
summary: The two finders, cargo features, GeoJSON export, integration patterns, and the v1 to v2 migration table for tzf-rs 2.0.
title: Rust (tzf-rs)
toc: true
weight: 3
---

## Install

```bash
cargo add tzf-rs
```

tzf-rs 2.0 is protobuf-free. It reads the TZF embedded binary format (`.tzb`)
published by [`ringsaturn/tzf-dist`](https://github.com/ringsaturn/tzf-dist);
the default `bundled` feature carries the lite file (~4 MB) inside the crate.
See [Embedded Binary Format]({{< relref "../reference/embedded-binary-format" >}})
for the format itself.

## Two finders

| Type | Data | Peak RSS | Query (random city / edge city) |
| --- | --- | ---: | ---: |
| `DefaultFinder` | lite `.tzb` expanded into polygons, FUZZY fast path | ~47 MiB | 229 ns / 519 ns |
| `EmbeddedFinder` | lite `.tzb` queried in place | ~10 MiB | 1.18 µs / 4.78 µs |

Measured in the [tz-benchmark](https://github.com/ringsaturn/tz-benchmark)
2026-09-11 snapshot on an Apple M3 Max against the `2026c` dataset; the Rust
runtime floor in that harness is 5.8 MiB.

`DefaultFinder::new()` opens in about 13 ms, `EmbeddedFinder::new()` in about
2 ms. The counting allocator reports no heap retention for `EmbeddedFinder`: its
data is the `&'static` embedded slice, plus roughly 1 KB of state.
`EmbeddedFinder` applies to memory-constrained targets that can accept
microsecond lookups. [Choosing a Finder]({{< relref "choosing-a-finder" >}})
covers the remaining cases.

## Finder reuse

Construction loads and validates the whole file, so a process builds one finder
and reuses it. A `LazyLock` static holds it without an extra dependency:

```rust {hl_lines=["4"]}
use std::sync::LazyLock;
use tzf_rs::DefaultFinder;

static FINDER: LazyLock<DefaultFinder> = LazyLock::new(DefaultFinder::new);

fn main() {
    // Coordinates are in (longitude, latitude) order.
    println!("{:?}", FINDER.get_tz_name(116.3883, 39.9289));
    println!("{:?}", FINDER.get_tz_names(116.3883, 39.9289));
}
```

`lazy_static` also works. `LazyLock` has been in the standard library since Rust
1.80.

## Queries

Both finders expose the same four methods:

```rust
finder.get_tz_name(lng, lat)   // -> &str, empty when nothing matches
finder.get_tz_names(lng, lat)  // -> Vec<&str>, sorted lexicographically
finder.timezonenames()         // -> Vec<&str>
finder.data_version()          // -> &str, e.g. "2026c"
```

- `get_tz_name` is fuzzy-first: the FUZZY tile preindex answers most queries
  with no point-in-polygon work.
- `get_tz_names` is polygon-exact in both finders and does not consult the
  preindex. It applies when a point may belong to more than one timezone; a
  point on a shared border belongs to every touching polygon.

## Bring your own bytes

```rust
use tzf_rs::{DefaultFinder, EmbeddedFinder};

let data = std::fs::read("lite.tzb")?;
let finder = DefaultFinder::from_tzb(&data)?;   // borrows during load, then expands
```

```rust
static DATA: &[u8] = include_bytes!("../data/lite.tzb");
let finder = EmbeddedFinder::from_tzb(DATA)?;   // no copy; queries read in place
```

`EmbeddedFinder::from_tzb` takes `impl Into<Cow<'static, [u8]>>`, so a
`&'static [u8]` from `include_bytes!` is adopted without copying, and an owned
`Vec<u8>` is also accepted. Both constructors return `Result<_, tzf_rs::Error>`:
files are CRC-checked and structurally validated at open, and malformed data
surfaces as an error rather than an empty finder.

`Error` is `#[non_exhaustive]` with `Malformed`, `Profile`, `NoFuzzy`, and
`Index` variants. `.tzm` memory-image bytes return `Profile`: tzf-rs consumes
the `.tzb` profile only, and the M profile is read by the Go implementation.

## Cargo features

| Feature | Default | Effect |
| --- | --- | --- |
| `bundled` | yes | Embeds the lite `.tzb` from tzf-dist (~4 MB); enables `new()` |
| `clap` | yes | Builds the `tzf` CLI binary |
| `full` | no | Git-only full-precision `.tzb` (~14 MB); enables `new_full()` |
| `export-geojson` | no | GeoJSON export methods |

`full` is mutually exclusive with `bundled`; the crate raises a `compile_error!`
when both are enabled. The full dataset exceeds the crates.io size limit, so it
is referenced from git:

```toml
[dependencies]
tzf-rs = { git = "https://github.com/ringsaturn/tzf-rs", rev = "v{X}.{Y}.{Z}", features = ["full"], default-features = false }
```

```rust
use tzf_rs::DefaultFinder;

let finder = DefaultFinder::new_full();
println!("{}", finder.get_tz_name(139.767125, 35.681236));
```

To drop the CLI binary from a library build:
`cargo build --no-default-features --features bundled`.

## GeoJSON export

With `export-geojson` enabled, both finders expose four exporters:

```rust
let world = finder.to_geojson();                            // BoundaryFile
let tokyo = finder.get_tz_geojson("Asia/Tokyo");            // Option<BoundaryFile>
let tiles = finder.get_tz_preindex_geojson("Asia/Tokyo");   // Option<BoundaryFile>
let all_tiles = finder.to_preindex_geojson();               // Option<BoundaryFile>
```

The preindex exporters return the bounding rectangles of the FUZZY tiles that
name a timezone: the area where `get_tz_name` answers from the preindex without
falling back to point-in-polygon. They return `None` when the file has no FUZZY
section.

## Migrating from v1

| v1 | v2 |
| --- | --- |
| `DefaultFinder::new()` | `DefaultFinder::new()` — unchanged call sites |
| `DefaultFinder::new_full()` | `DefaultFinder::new_full()` — unchanged call sites |
| `Finder` (polygon-only) | `DefaultFinder`; `get_tz_names` stays polygon-exact |
| `FuzzyFinder` (tile-only) | removed — the preindex is the fast path inside every finder |
| `Finder::from_compressed_topo(pb)` | `DefaultFinder::from_tzb(bytes)` |
| `FuzzyFinder::from_pb(pb)` | removed, no replacement |
| `FinderOptions` / `new_with_options` | removed — YStripes is always on |
| `finder.finder.get_tz_geojson(...)` | `finder.get_tz_geojson(...)` |
| `FuzzyFinder` tile-bbox GeoJSON | replaced by `get_tz_preindex_geojson` / `to_preindex_geojson` |
| — | new: `EmbeddedFinder`, in-place and low-memory |

Behaviour changes:

- `get_tz_names` results are now sorted lexicographically.
- `get_tz_name` on `DefaultFinder` answers from a covering preindex tile, which
  matches v1 `DefaultFinder` semantics. Code that used v1 `Finder` for
  polygon-exact multi-results calls `get_tz_names`.
- Byte constructors return `Result` instead of falling back to an empty finder.
- GeoJSON exports omit the duplicated junction vertices the protobuf expansion
  retained (zero-length segments). Query results are unaffected.
- Removed along with protobuf: `Finder::from_pb`, `Finder::from_compressed_topo`,
  `FuzzyFinder::from_pb`, the `pbgen` module, the `prost` dependency, and
  `revert_timezones`.

The v1 line (tzf-rs 1.3.x) remains available and is frozen at its last data
release: tzf-dist stops publishing the protobuf artifacts once the v2 set ships,
so updated boundaries require moving to v2.

## Integration examples

- HTTP service: [`racemap/rust-tz-service`](https://github.com/racemap/rust-tz-service) wraps tzf-rs in an Axum web server.
- Redis protocol: [`ringsaturn/redizone`](https://github.com/ringsaturn/redizone) is a Redis-compatible server built on tzf-rs.
- PostgreSQL: [`ringsaturn/pg-tzf`](https://github.com/ringsaturn/pg-tzf) exposes tzf-rs as a database extension.
