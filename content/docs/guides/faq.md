---
title: "FAQ"
description: "Frequently asked questions about Project tzf — accuracy, memory, coordinate order, and more."
summary: "Answers to common questions about tzf's design, limitations, and usage."
date: 2025-07-19T11:07:00+09:00
lastmod: 2025-07-19T11:07:00+09:00
draft: false
weight: 95
toc: true
seo:
  title: "FAQ — Project tzf"
  description: "Frequently asked questions about Project tzf — accuracy, memory usage, coordinate order, and data updates."
  noindex: false
---

## What is the coordinate order?

All tzf implementations use **(longitude, latitude)** order — the same as GeoJSON and most geo APIs.
Note that some systems (e.g. Google Maps URLs, many geographic textbooks) use (latitude, longitude) instead, so double-check before passing values.

## Is tzf 100% accurate?

By default, no. tzf applies polygon simplification ([Ramer–Douglas–Peucker](https://en.wikipedia.org/wiki/Ramer%E2%80%93Douglas%E2%80%93Peucker_algorithm)) to reduce data size,
which may produce incorrect results for points within roughly 1 km of a timezone boundary.

For 100% accurate lookups, use the full dataset:
- **Go**: `tzf.NewFullFinder()`
- **Rust**: load `combined-with-oceans.bin` manually (see [Getting Started]({{< relref "getting-started" >}}))
- **Python/tzfpy**: full-precision mode is not currently supported

## How much memory does tzf use?

| Mode          | Init   | After GC |
| ------------- | ------ | -------- |
| Default (Go)  | ~150 MB | ~60 MB  |
| Full (Go)     | ~900 MB | ~660 MB |

Memory figures are for the Go implementation. Rust and Python figures are similar for the default mode.

## Why is initialization slow?

The first call to `NewDefaultFinder()` / `DefaultFinder::new()` loads and parses the binary timezone data.
This is a one-time cost — subsequent lookups are very fast.
Always initialize once and reuse the instance. See the language-specific guides for patterns using global variables or `lazy_static`.

## How often is the timezone data updated?

tzf tracks [IANA timezone database](https://www.iana.org/time-zones) releases via
[evansiroky/timezone-boundary-builder](https://github.com/evansiroky/timezone-boundary-builder).
Processed data is published in [ringsaturn/tzf-rel](https://github.com/ringsaturn/tzf-rel).
Library releases follow within a short time of each upstream data release.

## What is the difference between Finder, FuzzyFinder, and DefaultFinder?

| Class           | Data used          | Accuracy      | Speed  |
| --------------- | ------------------ | ------------- | ------ |
| `FuzzyFinder`   | Tile-based index   | Approximate   | Fastest |
| `Finder`        | Simplified polygons | Good          | Fast   |
| `DefaultFinder` | Both (tile → polygon) | Good       | Fast   |

`DefaultFinder` is the recommended choice for most use cases: it uses the tile index for an O(1) initial filter and then runs precise polygon lookup only on the small set of candidates.

## What license does tzf use?

Code is MIT licensed. Timezone data (distributed via `tzf-rel`) is [ODbL](https://opendatacommons.org/licenses/odbl/),
the same as upstream [evansiroky/timezone-boundary-builder](https://github.com/evansiroky/timezone-boundary-builder).

Additionally, `tzf`, `tzf-rs`, and `tzfpy` carry an "Anti CSDN License" rider that prohibits use on the CSDN platform; this has no effect on other use cases.

See [Licenses]({{< relref "../reference/licenses" >}}) for details.
