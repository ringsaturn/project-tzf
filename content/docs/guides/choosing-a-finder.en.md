---
date: '2026-09-10T00:00:00+09:00'
description: The memory, latency and load-time figures for each tzf v2 finder, with deployment patterns for containers, embedded targets and quota-constrained pods.
draft: false
lastmod: '2026-09-14T00:00:00+09:00'
seo:
  description: Deployment guide for tzf v2 — the finder matrix (memory vs latency vs load time), no-filesystem and mmap patterns, cgroup-quota pods, tzb2tzm transcoding, and distribution sizes.
  noindex: false
  title: Choosing a Finder — Project tzf
summary: Measured cost of each tzf v2 finder, and the deployment patterns for containers, embedded targets and single-core pods.
title: Choosing a Finder
toc: true
weight: 1
---

Every tzf v2 finder answers from the same dataset. They differ in resident
memory, open time, and query latency when the preindex does not cover the point.
This page collects the measured figures and the deployment patterns that follow
from them.

## Recommendation by language

| Situation | Go | Rust | Python |
| --- | --- | --- | --- |
| Backend service, ordinary container | `NewDefaultFinder()` | `DefaultFinder::new()` | `get_tz()`; the module holds one shared finder |
| Tens of MB of RAM, or no filesystem | `NewEmbeddedFinder()` | `EmbeddedFinder::new()` | the `+full` pre-release wheel, which queries `full.tzb` in place (experimental) |
| Exact answers within ~111 m of a border | `NewFullFinder()` | `DefaultFinder::new_full()` (git-only `full` feature) | the `+full` pre-release wheel from tzfpy's own index (experimental) |
| Caller-supplied bytes from disk or an object store | `NewFinderFromTZB` / `NewFinderFromTZM` | `DefaultFinder::from_tzb` / `EmbeddedFinder::from_tzb` | not available |

## Deployment matrix

Measured on an Apple M3 Max against the `2026c` dataset. The single-core open
column models a pod with a CPU quota below one core; the 16-core column is an
unconstrained laptop or node.

| Mechanism | Go constructor | Open, 16 cores / 1 core | Resident | Query |
| --- | --- | ---: | --- | ---: |
| lite `.tzm` memory image | `NewDefaultFinder()` | 7.7 ms / 28 ms | ~12 MB heap + 10 MB read-only data | 298 ns |
| lite `.tzb` in place | `NewEmbeddedFinder()` | 2.4 ms / 2.4 ms | ~4 MB | ~1.2 µs (333 ns p50 on a preindex hit) |
| lite `.tzb` expanded | `NewFinderFromTZB(lite)` | 19.9 ms / 41 ms | ~27 MB | ~290 ns |
| full `.tzb` expanded | `NewFullFinder()` | 78.5 ms / 214 ms | ~145 MB | ~300 ns |
| full protobuf (v1, for reference) | — | 288 ms / 344 ms | ~153 MB | ~290 ns |

A later byte-backed decode fast path reduced the expanded open times further.
Warm best-of-five on the same machine: lite expanded 20.2 → 16.8 ms, full
expanded 72.7 → 63.5 ms, lite `.tzm` 7.5 → 6.9 ms.

Reading the columns:

- **Open:** a one-time cost. Every finder is safe for concurrent use, so a
  process builds one finder and reuses it. Open time affects startup latency,
  scale-to-zero functions, and CLI tools.
- **Resident:** what the process holds while serving queries. For the `.tzm`
  memory image, about 10 MB of that is a read-only mapping the page cache can
  share between processes; the remainder is heap.
- **Query:** a single `GetTimezoneName` over random world cities. The in-place
  mechanism reports about a microsecond because it decodes geometry from the
  compressed file on each point-in-polygon fallback.

## Low-memory and no-filesystem targets

`NewEmbeddedFinder()` reads the lite `.tzb` in place: about 30 KB of heap beyond
the file bytes (a chunk block table and the preindex zoom ranges, built at
open), about 4 MB in total, with no geometry decoding at load time. Queries are
allocation-free. The applicable cases are embedded targets, scale-to-zero
functions where the 2.4 ms open time dominates the latency budget, and processes
under a low memory limit.

For bytes that are not compiled in (a file on disk, an `mmap`'d region, a blob
from an object store), the experimental `x` package avoids reading the whole file
into memory:

```go
f, err := os.Open("lite.tzb")
if err != nil {
	panic(err)
}
info, err := f.Stat()
if err != nil {
	panic(err)
}
finder, err := x.NewFinderFromTZBReaderAt(f, info.Size())
```

`*os.File` satisfies `io.ReaderAt`, and so does an `mmap` wrapper. The file is
validated once at open; after that a query reads only the bytes it needs.
Since tzf 2.1 neither in-place backend holds a lock on the query path: the
byte-backed reader decodes off the slice, and the `ReaderAt` backend decodes
through a pool of reader views, so throughput scales with core count on both.

The `x` package is exempt from tzf's semantic-versioning promise: a minor version
bump may change or remove its API.

## Multi-core nodes vs cgroup-quota pods

The `.tzm` loader rebuilds the YStripes polygon index in parallel at open. On 16
cores that step costs about 5 ms; under a CPU quota below one core it accounts
for most of the difference between the 7.7 ms and 28 ms columns above. On the
full dataset the same step takes 158 ms at one core.

Options when a pod has a fractional CPU quota and startup latency is bounded by
an SLO:

- `NewEmbeddedFinder()`, whose 2.4 ms open time does not depend on core count;
- `NewDefaultFinder()` with the finder built before the readiness probe reports
  ready;
- a raised CPU quota for the startup window, where the platform supports it.

Query latency does not depend on core count.

## Local `.tzm` transcoding

`tzf-dist` publishes `lite.tzm` because `NewDefaultFinder()` reads it. It
publishes no `full.tzm`: that file is 63.6 MB, against 15.26 MB for `full.tzb`.
The M profile is generated on the host that uses it.

The conversion runs without protobuf and produces output byte-identical to
encoding the M profile from source:

```bash
go run github.com/ringsaturn/tzf/v2/cmd/tzb2tzm@latest -o full.tzm full.tzb
```

Load the result with `NewFinderFromTZM(data)`, or `mmap` the file and pass the
mapped bytes. The bytes must stay live and unmodified for the finder's lifetime,
because ring storage aliases them in place. On a little-endian host with an
8-byte-aligned slice the loader takes a zero-copy view; on a misaligned or
big-endian host it falls back to a one-time decoded copy, which approximately
doubles the memory.

## Distribution size

| Channel | What ships | Size |
| --- | --- | --- |
| Go module (`tzf-dist`) | `lite.tzb` + `lite.tzm` + `full.tzb` | 2.93 + 8.51 + 12.66 MB deflated, ≈24.1 MB total |
| Rust crate (crates.io) | `lite.tzb` only | ~4 MB |
| Rust crate (git, `full` feature) | `full.tzb` | ~15 MB |
| Python wheel (`tzfpy`) | `lite.tzb` inside the extension module | 2.76 MB for 2.0.0 on PyPI, 3.0 MB for the 2.1.0b2 pre-release (v1 was 4.31 MB) |

The Go module set is about 8 MB larger than the v1 protobuf pair (~16 MB
deflated), because it carries both profiles of the lite dataset and, since
`v0.0.2026-c-tzb2`, 64-point chunks. The Python wheel is smaller than v1 because
the protobuf decode path was removed.

## When to use the multi-result API

`GetTimezoneName` / `get_tz_name` / `get_tz` returns one name and is fuzzy-first:
a tile lookup answers most queries with no point-in-polygon work. Use the
multi-result API — `GetTimezoneNames` / `get_tz_names` / `get_tzs` — when:

- **Overlapping boundaries:** the source data contains regions covered by more
  than one timezone, such as the area shared by Asia/Shanghai and Asia/Urumqi.
- **Points on a shared border:** a point on a shared border belongs to every
  touching polygon. Nautical zone borders lie on whole meridians such as 7.5°
  and 22.5°.
- **Polygon-exact results:** the multi-result API does not consult the preindex
  in any finder, and evaluates every candidate.
- **Ambiguity in an interface:** the single-name API returns the first match,
  and the caller cannot tell an unambiguous answer from a truncated one.

It costs more: in tzf-rs's own criterion benchmark (Apple M3 Max, lite dataset),
`DefaultFinder` random-city lookups run 178 ns polygon-exact against 75 ns
fuzzy-first, and the difference is larger near borders.

## Accuracy versus the full dataset

The lite dataset is topology-aware Douglas-Peucker simplified with an epsilon of
0.001 degrees, which caps boundary displacement at about 111 m. On the
2026-09-14 snapshot the lite finders answer 154,694 world cities with one
disagreement (0.0006%) against full-precision ground truth, and that one
disagreement resolves to the same UTC offset.

The full dataset applies where a query may land within ~111 m of a border and
the exact name is required, such as geofencing, billing, or jurisdiction
determination. See [FAQ]({{< relref "faq#is-tzf-100-accurate" >}}) for the
measured displacement table.
