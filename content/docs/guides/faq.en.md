---
date: '2025-07-19T11:07:00+09:00'
description: Frequently asked questions about Project tzf — accuracy, memory, coordinate order, and more.
draft: false
lastmod: '2026-07-26T00:00:00+09:00'
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

The default finder is not guaranteed to match the full-precision dataset near timezone boundaries. It applies topology-aware [Douglas-Peucker simplification](https://en.wikipedia.org/wiki/Ramer%E2%80%93Douglas%E2%80%93Peucker_algorithm) with an epsilon of 0.001 degrees, which limits boundary displacement to roughly 111 m.

Measurements against the full-precision 2026c dataset are documented in [BORDER_CHANGE.md](https://github.com/ringsaturn/tzf/blob/main/BORDER_CHANGE.md):

| Metric                                            | Result                         |
| ------------------------------------------------- | ------------------------------ |
| Certified maximum boundary displacement           | 111.2 m, with 1.0 m tolerance  |
| Boundary length displaced more than 100 m         | 0.41%                          |
| Boundary length displaced more than 500 m         | 0%                             |
| Total mis-assigned area                           | 16,828 km², about 0.003% of Earth |
| Mis-assigned area within 100 m of the true border | 92.8%                          |

Only queries within roughly 111 m of a timezone boundary can differ from the full-precision result, and most of the affected band is much narrower.

For 100% accurate lookups, use the full dataset:

- **Go**: `tzf.NewFullFinder()`
- **Rust**: enable the `full` feature (see [Getting Started]({{< relref "getting-started#rust" >}}))
- **Python/tzfpy**: full-precision mode is not currently supported

## How much memory does tzf use?

Initialization cost and runtime cost are not the same number. Building a finder decodes the whole `.pb` dataset into an intermediate representation, builds the query structures from it, and then drops the intermediate — but freeing memory does not shrink RSS, because the allocator keeps the pages mapped for reuse. So the steady-state data a finder actually retains is several times smaller than the high-water mark reached while loading.

The following figures were measured on an Apple M3 Max in the [2026-07-26 benchmark snapshot](https://github.com/ringsaturn/tz-benchmark/blob/main/snapshot/2026-07-26-8d0fed77a8efb102ea3e3848781b5a000bbfb548/README.md#memory).

| Implementation | Mode                                      | Init peak | Live      |
| -------------- | ----------------------------------------- | --------: | --------: |
| Go             | `FuzzyFinder` (preindex only)             |  30.4 MiB |   2.6 MiB |
| Go             | `Finder` (topology-simplified)            | 127.8 MiB |  30.0 MiB |
| Go             | `DefaultFinder` (simplified + preindex)   | 124.3 MiB |  32.3 MiB |
| Go             | `FullFinder` (full-precision + preindex)  | 359.4 MiB | 155.7 MiB |
| Rust           | `FuzzyFinder` (preindex only)             |  23.8 MiB |   5.1 MiB |
| Rust           | `Finder` (topology-simplified)            |  48.0 MiB |  20.7 MiB |
| Rust           | `DefaultFinder` (simplified + preindex)   |  77.0 MiB |  36.3 MiB |
| Python         | tzfpy `DefaultFinder`                     |  94.8 MiB |       n/a |

- **Init peak** is the high-water mark (`ru_maxrss`) reached while loading. This is what a container memory limit has to accommodate, or the process is killed at startup even though its steady state would have fit.
- **Live** is what the finder retains once it is ready to serve queries, from language-native accounting (Go `HeapAlloc` after a forced GC, Rust a counting global allocator). It is `n/a` for Python, whose candidates keep their data outside the Python heap.

Size the container for the init peak, but expect the long-running cost to be the live figure. Actual usage varies by platform, allocator, and dataset version.

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
