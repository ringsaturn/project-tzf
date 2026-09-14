---
author: ringsaturn
date: '2026-09-11'
description: tzf v2 removes protobuf from the runtime and the data pipeline. Boundary data now ships as the TZF embedded binary format, which the finders query directly. This post records the format, the finder lineup in Go, Rust and Python, the measured load and memory figures, and the migration path from v1.
draft: false
tags:
- tzf
- Side Project
- Geo
- timezone
title: tzf v2
---

Update, 2026-09-14: tzf v2.1.1, tzf-rs 2.1.1 and the tzfpy 2.1.0b2 pre-release
rewrote the in-place query walk and moved the data to 64-point chunks (tzf-dist
`v0.0.2026-c-tzb2`). The in-place figures in this post describe 2.0.0. On the
2026-09-14 snapshot the Go `NewEmbeddedFinder` edge-city p50 is 1,000 ns (was
8,959 ns), the Rust `EmbeddedFinder` edge-city mean is 666 ns (was 4,780 ns),
and the in-place finders hold a small open-time index (about 30 KB in Go)
instead of under 1 KB of heap. Current tables are on the
[Benchmarks]({{< relref "/docs/reference/benchmarks" >}}) page.

The [Spring 2026 update]({{< ref "/blog/2026-spring-news/index.md" >}}) finished
the data side of tzf: topology-aware simplification, shared-edge deduplication,
and polyline compression brought the full-precision dataset from about 90 MB to
about 17 MB. What it did not change was how that data reaches memory. Every
implementation still parsed a protobuf message into an object graph at startup,
then built its query structures from that graph and discarded it.

v2 removes protobuf from both the runtime and the pipeline. Boundary data now
ships in a container the finders read directly.

<!--more-->

## Reasons for removing protobuf

Three costs are attributable to the parse step.

**Open time.** Loading the full-precision dataset in Go took 288 ms. The same
dataset in the new format opens in 78.5 ms. In Rust, the lite dataset went from
71 ms to 18 ms cold.

**Peak memory during load.** The decoded message and the query structures built
from it are live at the same time, so the high-water mark exceeds the steady
state by a wide margin: in the 2026-09-11 benchmark snapshot, Go's full finder
peaks at 315.0 MiB while retaining 147.0 MiB. That peak is what a container
memory limit has to accommodate.

**No in-place option.** A protobuf message has to be fully parsed before any
field is readable, which rules out answering a query by reading a few kilobytes
of a file. There was no mechanism for deployments limited to a few tens of
megabytes of RAM.

The pipeline that builds the data also carried protobuf, along with generated
code and a schema compiler in the build. Intermediates now use native Go structs
with `encoding/gob`; they are build-internal and are not distributed. Rebuilding
the full dataset from raw GeoJSON produces a byte-identical `full.tzb`, which is
how the change was verified.

## The embedded binary format

The `.tzb` file is a sectioned little-endian container: a 64-byte header, a
section table, the data sections, and a CRC32 footer. Directories are
fixed-width records, every ring, group and chunk carries a bounding box, and
coordinates are `int32` degrees scaled by 100000. A reader locates a candidate
timezone through a 1° × 1° grid section, then descends through the bounding
boxes and decodes only the geometry that survives them.

Two profiles share the container, selected by a header byte:

| Profile | Extension | Geometry storage |
| --- | --- | --- |
| E (embedded) | `.tzb` | Chunked zigzag-LEB128 varint streams |
| M (memory image) | `.tzm` | One flat array of `(int32, int32)` pairs |

The M profile stores points in the layout the query code uses, so ring storage
points directly at the mapped file with no decode and no copy. It is larger:
10.18 MB against 3.97 MB for the same lite dataset. `full.tzm` would be about
67 MB and is not published; it is generated on the host that uses it, with
`cmd/tzb2tzm`.

Section type 10 carries the tile preindex, which earlier versions distributed as
a separate file. On the `2026c` dataset it holds 87,572 tiles, 156 of which name
two timezones, in about 880 KB. All three published artifacts carry it.

The full layout is documented in
[Embedded Binary Format]({{< relref "/docs/reference/embedded-binary-format" >}}).

## Finders

### Go

Five constructors, all returning the `tzf.F` interface. The package exports no
finder types and no options.

| Constructor | Data | Resident | Query |
| --- | --- | --- | ---: |
| `NewDefaultFinder()` | lite `.tzm`, aliased in place | ~12 MB heap + 10 MB read-only | 298 ns |
| `NewEmbeddedFinder()` | lite `.tzb`, queried in place | ~3 MB | ~6 µs |
| `NewFullFinder()` | full `.tzb`, expanded | ~145 MB | ~300 ns |
| `NewFinderFromTZB(data)` | caller-supplied `.tzb` | file-dependent | ~290 ns |
| `NewFinderFromTZM(data)` | caller-supplied `.tzm` | file-dependent | ~300 ns |

`NewEmbeddedFinder` is new. It holds under 1 KB of heap beyond the file bytes and
queries without allocating. For bytes the caller already owns, or an `mmap`'d
region, `x.NewFinderFromTZBReaderAt` takes an `io.ReaderAt`; the `x` package is
outside the module's semantic-versioning promise.

`GeoJSONer` is asserted rather than being part of `F`, and now exports the
preindex tiles as well as the boundary polygons.

### Rust

tzf-rs 2.0 has `DefaultFinder` and `EmbeddedFinder`. `FuzzyFinder`, `Finder` and
`FinderOptions` are gone: the preindex is the fast path inside both finders, and
the YStripes index is always built. The crate reads `.tzb` only, and returns
`Error::Profile` for `.tzm` bytes. The crates.io package carries `lite.tzb`
(~4 MB); `full.tzb` (~14 MB) comes from git behind the `full` feature.

Byte constructors now return `Result`: files are CRC-checked and structurally
validated at open, so malformed data surfaces as an error rather than an empty
finder.

### Python

tzfpy 2.0 binds tzf-rs 2.0. The four query functions are unchanged, and two
GeoJSON exporters were added. Dropping the protobuf path took the wheel from
4.31 MB to 2.76 MB and finder initialization from 68 ms to 15 ms, with query
latency unchanged. The `_TZFPY_DISABLE_Y_STRIPES` escape hatch was removed along
with the option it controlled.

## Measurements

Apple M3 Max, `2026c` dataset. Open times and resident memory from the v2 design
records; query latency, accuracy and memory columns from the
[tz-benchmark](https://github.com/ringsaturn/tz-benchmark) snapshot of
2026-09-11, taken locally on the same machine against the published 2.0.0
releases.

| Path | Open | Resident | Query, world cities |
| --- | ---: | ---: | ---: |
| Go, full protobuf (v1) | 288 ms | ~153 MB | ~290 ns |
| Go, full `.tzb` expanded | 78.5 ms | ~145 MB | ~300 ns |
| Go, lite `.tzm` | 7.7 ms | ~12 MB heap + 10 MB read-only | 298 ns |
| Go, lite `.tzb` in place | 1.7 ms | ~3 MB | ~6 µs |
| Rust, lite protobuf (v1) | 71 ms | 77.8 MiB peak RSS | 316 ns |
| Rust, lite `.tzb` | 18 ms cold | 44.1 MiB peak RSS | 260 ns |

Go and Rust return identical `GetTimezoneName` and `GetTimezoneNames` results
over about 195,000 boundary-heavy samples per artifact, plus the world-cities
set. Against full-precision ground truth, the lite finders disagree on 1 of
154,694 world cities (0.0006%), and that answer resolves to the same UTC offset.

A `.tzm` loader was also built for Rust. It saved about 3 ms of open time and
raised peak RSS from 44.1 MiB to 68.7 MiB, and was removed; tzf-rs consumes the E
profile only.

## Migration

The query interfaces are unchanged in all three languages. Most call sites need
only the dependency change.

- Go: the module path becomes `github.com/ringsaturn/tzf/v2`. See the
  [Go guide]({{< relref "/docs/guides/tzf" >}}) for the mapping table.
- Rust: `DefaultFinder::new()` and `new_full()` keep their signatures; the
  removed types are listed in the [Rust guide]({{< relref "/docs/guides/tzf-rs" >}}).
- Python: see the [Python guide]({{< relref "/docs/guides/tzfpy" >}}).
- [Choosing a Finder]({{< relref "/docs/guides/choosing-a-finder" >}}) covers
  which constructor fits a given deployment.

## Status of the v1 line

tzf v1.2.x, tzf-rs 1.3.x and tzfpy 1.3.x remain available and continue to work.
tzf-dist stops publishing the protobuf artifact set, so those versions are frozen
at their last data release; updated boundaries require moving to v2. tzf-wasm
2.0.0 builds on tzf-rs 2.0.0 and tzf-web serves it. tzf-swift 2.0.0 is a
protobuf-free port that reads `lite.tzb` directly and ships `DefaultFinder`
and `EmbeddedFinder`. tzf-rb is a third-party Ruby binding
maintained by [HarlemSquirrel](https://github.com/HarlemSquirrel) and currently
builds on the v1 line.

## Acknowledgements

The YStripes index is from Josh Baker's
[`tidwall/tg`](https://github.com/tidwall/tg); tzf ports it rather than
reimplementing it. The boundary data comes from
[evansiroky/timezone-boundary-builder](https://github.com/evansiroky/timezone-boundary-builder),
which tracks IANA timezone database releases. The v2 implementation and the
parity work between Go and Rust were carried out with Claude and Codex across
multiple rounds of implementation, verification and refactoring.
