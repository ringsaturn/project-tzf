---
title: "Benchmarks"
description: "Performance benchmarks for tzf implementations across Go, Rust, and Python."
summary: "Benchmark results and methodology for the tzf timezone lookup ecosystem."
date: 2025-07-19T13:58:16+09:00
lastmod: 2025-07-19T13:58:16+09:00
draft: false
weight: 4
toc: true
seo:
  title: "Benchmarks — Project tzf"
  description: "Performance benchmark results for tzf, tzf-rs, and tzfpy timezone lookup libraries."
  noindex: false
---

Benchmark source code and results are maintained in a dedicated repository:

**<https://github.com/ringsaturn/tz-benchmark>**

The repository covers:

- Single-point lookup latency across implementations
- Throughput (queries per second) comparisons
- Memory usage after initialization and GC
- Cross-language comparisons (Go, Rust, Python)

## Methodology

Benchmarks use a representative sample of global city coordinates to avoid cache effects from repeated identical lookups.
Each finder is initialized once and reused for all queries, matching the recommended production pattern.

## Key findings

- `DefaultFinder` (tile + polygon) outperforms naive `Finder` (polygon-only) for most real-world workloads.
- tzf-rs matches or exceeds tzf (Go) in single-threaded throughput after the initial optimization described in the [Technical White Paper]({{< relref "white-paper" >}}).
- tzfpy (Python via PyO3) achieves comparable per-call latency to the raw Rust implementation; Python overhead is primarily in the calling loop, not the lookup itself.

## Running benchmarks locally

```bash
git clone https://github.com/ringsaturn/tz-benchmark
cd tz-benchmark
# Follow the README for language-specific instructions
```
