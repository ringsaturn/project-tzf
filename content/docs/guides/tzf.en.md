---
date: '2025-07-21T12:14:46+09:00'
description: Best practices and advanced usage patterns for the Go implementation of tzf (v2).
draft: false
lastmod: '2026-09-11T00:00:00+09:00'
seo:
  description: Best practices for the Go tzf v2 library — the five constructors, finder reuse, GeoJSON export, in-place queries, and migrating from v1.
  noindex: false
  title: Go (tzf) Guide — Project tzf
summary: Constructor choice, finder reuse, GeoJSON export, in-place bytes, and the v1 to v2 migration table for tzf v2 in Go.
title: Go (tzf)
toc: true
weight: 2
---

## Install

tzf v2 is a new major version, so the module path carries the `/v2` suffix:

```bash
go get github.com/ringsaturn/tzf/v2
```

```go
import "github.com/ringsaturn/tzf/v2"
```

The package name is still `tzf`. v2 is protobuf-free: boundary data ships as
`.tzb` (compact transport profile) and `.tzm` (memory-image profile) files from
[`ringsaturn/tzf-dist`](https://github.com/ringsaturn/tzf-dist), embedded with
`go:embed`. See [Embedded Binary Format]({{< relref "../reference/embedded-binary-format" >}})
for the file format itself.

## The five constructors

Every constructor returns the [`F`](#the-f-interface) interface. The package
exports no finder types and no options.

| Constructor | Data | Resident | Query |
| --- | --- | --- | --- |
| `NewDefaultFinder()` | lite `.tzm` memory image, polygons aliased in place | ~12 MB heap + ~10 MB read-only data | 298 ns |
| `NewEmbeddedFinder()` | lite `.tzb`, queried in place | ~3 MB (the file bytes plus <1 KB of heap) | p50 542 ns on a preindex hit, ~6 µs on a miss |
| `NewFullFinder()` | full `.tzb`, expanded at load | ~145 MB | ~300 ns |
| `NewFinderFromTZB(data)` | your own `.tzb` bytes, always expanded | depends on the file (lite: ~27 MB) | ~290 ns |
| `NewFinderFromTZM(data)` | your own `.tzm` bytes, always aliased in place | as `NewDefaultFinder`, for the same file | ~300 ns |

Measured on an Apple M3 Max against the `2026c` dataset.

The package documentation names `NewDefaultFinder()` as the general-purpose
finder. [Choosing a Finder]({{< relref "choosing-a-finder" >}}) covers the
remaining cases: no-filesystem targets, cgroup-quota pods, and distribution size.

## Finder reuse

Construction is expensive relative to a query: it opens the file, builds the
query structures, and, for the expanded finders, decodes every polygon. A finder
is safe for concurrent use, so a process builds one and reuses it. A
package-level variable is one way to do that:

```go {hl_lines=["9"]}
package main

import (
	"fmt"

	"github.com/ringsaturn/tzf/v2"
)

var f tzf.F

func init() {
	var err error
	f, err = tzf.NewDefaultFinder()
	if err != nil {
		panic(err)
	}
}

func main() {
	// Coordinates are in (longitude, latitude) order.
	fmt.Println(f.GetTimezoneName(116.3883, 39.9289))
	fmt.Println(f.GetTimezoneName(-73.935242, 40.730610))
}
```

## The `F` interface

```go
type F interface {
	GetTimezoneName(lng float64, lat float64) string
	GetTimezoneNames(lng float64, lat float64) ([]string, error)
	TimezoneNames() []string
	DataVersion() string
}
```

- **`GetTimezoneName`:** fuzzy-first. Every tzf-dist artifact carries a FUZZY
  preindex section, so a tile lookup answers most queries with no
  point-in-polygon work; near a border the finder falls back to ray casting. The
  method returns the empty string when nothing matches.
- **`GetTimezoneNames`:** polygon-exact in every finder. It does not consult the
  preindex, and it applies when a point may belong to more than one timezone.
  Results are sorted lexicographically, and the method returns
  `tzf.ErrNoTimezoneFound` when nothing matches.
- A point on a shared border belongs to every touching polygon. Nautical zone
  borders lie on whole meridians such as 7.5° and 22.5°.

```go
names, err := f.GetTimezoneNames(87.4160, 44.0400)
// names == []string{"Asia/Shanghai", "Asia/Urumqi"}
```

## GeoJSON export

`GeoJSONer` is kept out of `F` so that test doubles and third-party `F`
implementations need not produce geometry. Every finder this package builds
satisfies it, so assert the interface on the value the constructor returned:

```go
finder, err := tzf.NewDefaultFinder()
if err != nil {
	panic(err)
}

g := finder.(tzf.GeoJSONer)

world := g.GetGeoJSON()                          // []byte, all timezones
tokyo, err := g.GetTZGeoJSON("Asia/Tokyo")       // []byte, one timezone
tiles, err := g.GetTZPreindexGeoJSON("Asia/Tokyo") // FUZZY tiles for one timezone
all, err := g.GetPreindexGeoJSON()               // the whole FUZZY preindex
```

All four methods return serialized GeoJSON bytes; the boundary-file types are
internal to the module. The preindex exports cover the area where
`GetTimezoneName` answers from the preindex without falling back to
point-in-polygon. A file without a FUZZY section returns
`tzf.ErrNoFuzzySection`.

## Bring your own bytes

Read a file from disk, an object store, or your own `go:embed`, then pick the
constructor that matches the profile:

```go
data, err := os.ReadFile("lite.tzb")
if err != nil {
	panic(err)
}
finder, err := tzf.NewFinderFromTZB(data) // expanded; data may be released
```

```go
data, err := os.ReadFile("lite.tzm")
if err != nil {
	panic(err)
}
finder, err := tzf.NewFinderFromTZM(data) // aliased in place; data must stay live
```

A `.tzm` finder's ring slices alias the source bytes, which must stay live and
unmodified for the finder's lifetime.

The M profile is generated on the host that uses it, from the `.tzb` file:

```bash
# usage: tzb2tzm [-o output] input.tzb
go run github.com/ringsaturn/tzf/v2/cmd/tzb2tzm@latest lite.tzb
```

## In-place queries over caller-owned bytes

`x.NewFinderFromTZBReaderAt` queries a `.tzb` through an `io.ReaderAt` — a file,
an `mmap`'d region, an embedded flash adapter, or a `bytes.Reader` over bytes
you already hold. Queries are allocation-free and the heap cost stays under 1 KB:

```go
import (
	"bytes"

	"github.com/ringsaturn/tzf/v2/x"
)

finder, err := x.NewFinderFromTZBReaderAt(bytes.NewReader(data), int64(len(data)))
if err != nil {
	panic(err)
}
fmt.Println(finder.GetTimezoneName(151.2093, -33.8688))
```

The `x` package is exempt from the module's semantic-versioning promise: a minor
version bump may change or remove its API. The root package changes
incompatibly only at a major version.

## Migrating from v1

v1 (`github.com/ringsaturn/tzf`, latest v1.2.x) remains available. It is frozen
at its final protobuf data release: tzf-dist stops publishing the `.bin`
artifacts once the v2 set ships.

| v1 | v2 |
| --- | --- |
| `go get github.com/ringsaturn/tzf` | `go get github.com/ringsaturn/tzf/v2` |
| `tzf.NewDefaultFinder()` | `tzf.NewDefaultFinder()` — now the lite `.tzm` memory image |
| `tzf.NewFullFinder()` | `tzf.NewFullFinder()` — now the full `.tzb`, expanded |
| `tzf.NewFuzzyFinderFromPB(...)` | removed; the FUZZY fast path is built into every finder that carries the section |
| `tzf.NewFinderFromCompressedTopo(...)`, `NewFinderFromCompressed(...)`, `NewFinderFromPB(...)` | `tzf.NewFinderFromTZB(data)` or `tzf.NewFinderFromTZM(data)` — plain `[]byte`, no protobuf message |
| `tzf.NewFinderFromRawJSON(...)` | removed; build a `.tzb` with the pipeline CLIs instead |
| `tzf.Finder`, `tzf.FuzzyFinder`, `tzf.DefaultFinder` (exported structs) | removed; every constructor returns `tzf.F` |
| `tzf.Option` / `tzf.OptionFunc` / `tzf.SetDropPBTZ` | removed; there are no options in v2 |
| `finder.GetGeoJSON()` returning `*convert.BoundaryFile` | `finder.(tzf.GeoJSONer).GetGeoJSON()` returning `[]byte` |
| `github.com/ringsaturn/tzf/gen/go/tzf/v1` (protobuf types) | gone; there is no protobuf anywhere in v2 |
| `reduce`, `preindex`, `convert.Do` (exported pipeline packages) | internal; drive the pipeline through the `cmd/` CLIs |
| `.bin` files from tzf-dist | `lite.tzb`, `lite.tzm`, `full.tzb` |

The four `F` methods are unchanged, so code that only calls
`GetTimezoneName` / `GetTimezoneNames` / `TimezoneNames` / `DataVersion` needs
nothing beyond the import-path change.

### Boundary semantics

v2 answers on-edge queries the same way v1 does after
[tzf#216](https://github.com/ringsaturn/tzf/issues/216): a point on a shared
border belongs to every touching polygon, with exterior rings allowing on-edge
containment and hole rings not. Code pinned to an earlier v1 patch release will
see border points that previously returned no result return a name.
