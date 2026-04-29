---
date: '2025-07-19T11:07:00+09:00'
description: Frequently asked questions about Project tzf — accuracy, memory, coordinate order, and more.
draft: false
lastmod: '2025-07-19T11:07:00+09:00'
seo:
  description: Frequently asked questions about Project tzf — accuracy, memory usage, coordinate order, and data updates.
  noindex: false
  title: FAQ — Project tzf
summary: Answers to common questions about tzf's design, limitations, and usage.
title: FAQ
toc: true
weight: 95
---

## What is the coordinate order?

All tzf implementations use **(longitude, latitude)** order — the same as GeoJSON and most geo APIs.
Note that some systems (e.g. Google Maps URLs, many geographic textbooks) use (latitude, longitude) instead, so double-check before passing values.

## Is tzf 100% accurate?

By default, no. tzf applies polygon simplification ([Ramer–Douglas–Peucker](https://en.wikipedia.org/wiki/Ramer%E2%80%93Douglas%E2%80%93Peucker_algorithm)) to reduce data size,
which may produce incorrect results for points within roughly 1 km of a timezone boundary.

For 100% accurate lookups, use the full dataset:
- **Go**: `tzf.NewFullFinder()`
- **Rust**: enable the `full` feature (see [Getting Started]({{< relref "getting-started" >}}))
- **Python/tzfpy**: full-precision mode is not currently supported

## How much memory does tzf use?

| Mode (Go)                                     | Memory  |
| --------------------------------------------- | ------- |
| DefaultFinder (topology-simplified + preindex) | ~75 MB |
| Finder (topology-simplified)                   | ~66 MB |
| FullFinder (full-precision + preindex)         | ~422 MB |

Rust memory is similar; enabling the YStripes index adds roughly 30–40 MB.
Full-precision mode in Rust (with YStripes) uses ~560 MB.
Python uses the Rust binary internally, so its footprint matches the Rust default mode.

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

| Class           | Data used               | Coverage                          | Speed   |
| --------------- | ----------------------- | --------------------------------- | ------- |
| `FuzzyFinder`   | Tile preindex only      | Interior tiles only — no result for border/uncovered areas | Fastest |
| `Finder`        | Polygon data            | Full global coverage              | Fast    |
| `DefaultFinder` | Tile preindex + polygon | Full global coverage              | Fast    |

**FuzzyFinder** preindex stores only tiles that lie entirely within a single timezone polygon.
When a query point lands in a covered tile it returns the correct timezone immediately.
When it does not — near borders, coastlines, or sparse regions — it returns nothing rather than guessing.
It is not "approximate": results are accurate, but coverage is incomplete.

**DefaultFinder** (recommended) tries the tile preindex first; if no result is found it falls back to full
polygon lookup. This gives near-constant speed for the majority of world-city queries while remaining
correct for all coordinates.

## What license does tzf use?

Code is MIT licensed. Timezone data (distributed via `tzf-rel`) is [ODbL](https://opendatacommons.org/licenses/odbl/),
the same as upstream [evansiroky/timezone-boundary-builder](https://github.com/evansiroky/timezone-boundary-builder).

Additionally, `tzf`, `tzf-rs`, and `tzfpy` carry an "Anti CSDN License" rider that prohibits use on the CSDN platform; this has no effect on other use cases.

See [Licenses]({{< relref "../reference/licenses" >}}) for details.
