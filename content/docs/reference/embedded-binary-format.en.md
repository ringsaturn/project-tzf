---
date: '2026-09-10T00:00:00+09:00'
description: 'Reference for the TZF embedded binary format: file layout, profiles, section types, and lookup semantics for .tzb and .tzm files.'
draft: false
lastmod: '2026-09-14T00:00:00+09:00'
seo:
  description: The TZF embedded binary format — header, section table, CRC footer, E and M profiles, section types 1 to 14, and the rules for reproducing tzf lookup results.
  noindex: false
  title: Embedded Binary Format — Project tzf
summary: On-disk layout of the .tzb and .tzm files, and the rules required to read one safely and reproduce tzf lookup results.
title: Embedded Binary Format
toc: true
weight: 2
---

This is a compact reference for the TZF embedded binary format — the `.tzb` and
`.tzm` files that carry boundary data from
[`ringsaturn/tzf-dist`](https://github.com/ringsaturn/tzf-dist) into every v2
implementation. It describes the on-disk layout and the rules required to read a
file safely and reproduce tzf timezone lookup results.

The format replaced protobuf in v2. It supports querying in place: directories
are fixed-width records, geometry carries a bounding box at every level, and a
reader can answer a query by reading only the bytes that query requires.

This page is the public reference for the format. The reference
implementation is `internal/embedbin` in the
[tzf repository](https://github.com/ringsaturn/tzf).

## 1. Conventions

- Magic: `TZFB`
- Format version: `1.1` (`format_major` 1, `format_minor` 1)
- Byte order: little-endian for every fixed-width integer
- Coordinates: signed `int32`, degrees multiplied by `100000`
- Coordinate order: longitude, then latitude
- Bounding box order: `min_lng, min_lat, max_lng, max_lat`
- Signed values in point streams: zigzag encoded, then unsigned LEB128 encoded
- LEB128 values: minimal encoding, at most 5 bytes
- Section offsets and fixed-width records: 4-byte aligned
- Maximum file size: less than 4 GiB

Stored coordinates and bounding boxes must be within:

```
longitude: -18000000..18000000
latitude:   -9000000..9000000
```

## 2. Profiles

Format 1.1 assigns the first reserved header byte (offset 48) as `profile`.
Two profiles share one container:

| Profile | Value | Extension | Shape |
| --- | ---: | --- | --- |
| E (embedded) | 0 | `.tzb` | Chunked varint geometry; the transport format |
| M (memory image) | 1 | `.tzm` | Flat `(i32, i32)` point array, laid out as the query-time structure |

Every file written before 1.1 carries 0 at that offset, so all format 1.0 files
are retroactively valid E-profile files. Readers must reject unknown profile
values.

Mandatory sections are per-profile:

| Profile | Required | Optional |
| --- | --- | --- |
| E | NAMES, TZDIR, POLYDIR, RINGDIR, RINGOPS, GROUPDIR, CHUNKDIR, POINTS | GRID, FUZZY |
| M | NAMES, TZDIR, POLYDIR, FLATRINGDIR, FLATPOINTS | GRID, FUZZY, YSTRIPES |

Cross-profile section types are rejected. NAMES, TZDIR, POLYDIR, GRID, and FUZZY
are byte-identical in both profiles, which is what lets `.tzb` → `.tzm`
transcoding copy them across verbatim.

The M profile is generated on the host that uses it, with tzf's `cmd/tzb2tzm`;
the output is byte-identical to encoding the M profile from source. The Go
implementation is the only consumer of the M profile; tzf-rs returns
`Error::Profile` for such files.

## 3. Top-level layout

```
Header                 64 bytes
Section table          section_count * 16 bytes
NAMES                  type 1
TZDIR                  type 2
POLYDIR                type 3
RINGDIR                type 4     E profile
RINGOPS                type 5     E profile
GROUPDIR               type 6     E profile
CHUNKDIR               type 7     E profile
GRID                   type 8     optional
FUZZY                  type 10    optional
FLATPOINTS             type 12    M profile
FLATRINGDIR            type 13    M profile
YSTRIPES               type 14    M profile, optional, not emitted today
POINTS                 type 9     E profile, last
CRC32 footer           4 bytes
```

Writers emit sections in that order, with the bulk geometry last. Readers use
the section table to locate sections and skip unknown types, which is how a
format 1.0 reader ignores a FUZZY section.

Section type 11 (`META`) is assigned but reserved.

### 3.1 Header

| Offset | Size | Field | Meaning |
| ---: | ---: | --- | --- |
| 0 | 4 | `magic` | ASCII `TZFB` |
| 4 | 1 | `format_major` | `1` |
| 5 | 1 | `format_minor` | `1` |
| 6 | 2 | `header_size` | `64` |
| 8 | 4 | `flags` | See below |
| 12 | 4 | `coord_scale` | `100000` |
| 16 | 4 | `file_size` | Total size including footer |
| 20 | 4 | `section_count` | Section table entry count |
| 24 | 16 | `data_version` | NUL-padded UTF-8, such as `2026c` |
| 40 | 4 | `tz_count` | Number of timezone entries |
| 44 | 4 | `chunk_target` | Informative target points per chunk |
| 48 | 1 | `profile` | `0` = E, `1` = M |
| 49 | 15 | reserved | Writers emit zero |

Flags:

| Bit | Name | Meaning |
| ---: | --- | --- |
| 0 | `GRID_PRESENT` | A `GRID` section is present |
| 1 | `NO_SHORTCUT` | Disable the single-candidate lookup shortcut |
| 2..31 | reserved | Writers emit zero |

### 3.2 Section table

The section table starts immediately after the header. Each entry is 16 bytes:

| Offset | Size | Field |
| ---: | ---: | --- |
| 0 | 4 | `type` |
| 4 | 4 | `offset`, from the start of the file |
| 8 | 4 | `length`, in bytes |
| 12 | 4 | reserved |

Known section types must be unique. Sections must be in bounds and must not
overlap the header, section table, footer, or another section.

### 3.3 Footer

The final 4 bytes contain an IEEE CRC32 over bytes `[0, file_size - 4)`. A file
must be checked before its first query. A device may perform this check once when
provisioning the file into trusted storage.

## 4. Shared sections

Directory indices are zero-based. A `first` plus `count` pair always selects a
contiguous range in the referenced section.

### 4.1 NAMES, type 1

```
u32 blob_len
u32 offsets[tz_count + 1]
u8  blob[blob_len]
```

Timezone name `i` is `blob[offsets[i] : offsets[i + 1]]`. Names are non-empty
UTF-8 strings without NUL bytes; offsets are nondecreasing, `offsets[0]` is zero,
and `offsets[tz_count]` equals `blob_len`. Timezone indices mean the same thing
in NAMES, TZDIR, GRID, and FUZZY.

### 4.2 TZDIR, type 2

`tz_count` records, 24 bytes each:

| Offset | Size | Field |
| ---: | ---: | --- |
| 0 | 4 | `poly_first`, index into POLYDIR |
| 4 | 2 | `poly_count` |
| 6 | 2 | reserved |
| 8 | 16 | timezone bounding box, four `i32` values |

### 4.3 POLYDIR, type 3

24-byte records:

| Offset | Size | Field |
| ---: | ---: | --- |
| 0 | 4 | `ring_first`, index into RINGDIR (E) or FLATRINGDIR (M) |
| 4 | 2 | `ring_count` |
| 6 | 2 | reserved |
| 8 | 16 | exterior-ring bounding box, four `i32` values |

The first ring is the exterior; the rest are first-level holes. The format
cannot represent nested holes.

### 4.4 GRID, type 8 (optional)

A dense 1° × 1° candidate index:

```
i16 lng_min
i16 lat_min
u16 lng_cells
u16 lat_cells
u32 cand_count
u32 cells[lng_cells * lat_cells]
u16 candidates[cand_count]
```

For an input coordinate:

```
cx = floor(lng) - lng_min
cy = floor(lat) - lat_min
cell_index = cy * lng_cells + cx
```

An out-of-range cell has no candidate. A cell word encodes:

```
count  = cells[cell_index] >> 28
offset = cells[cell_index] & 0x0fffffff
```

The candidate list is `candidates[offset : offset + count]`, holding ascending
timezone indices; lists may be shared between cells. Grid keys may extend one
cell beyond the query domain (`lng_min: -181..180`, `lat_min: -91..90`) because
they can be copied from an upstream floating-point index. Each cell holds at
most 15 candidates, `cand_count` is less than 2²⁸, and every candidate is less
than `tz_count`. When GRID is absent, a reader scans TZDIR.

### 4.5 FUZZY, type 10 (optional)

The tile preindex, stored as one sorted tile-ID array. This is the fast path
that answers most single-name queries without any point-in-polygon work.

```
u8  idx_zoom
u8  agg_zoom               // agg_zoom <= idx_zoom
u16 reserved (0)
u32 tile_count
u32 multi_group_count
u32 multi_value_count
u64 keys[tile_count]       // packed TileID, strictly ascending
u16 values[tile_count]
u16 multi_dir[multi_group_count * 2]   // (first, count) pairs
u16 multi_values[multi_value_count]    // NAMES indices
(zero padding to 4-byte alignment)
```

A key packs as `uint64(z) << 56 | uint64(x) << 28 | uint64(y)`. In a value, bit
15 clear means bits 0–14 are a NAMES index; bit 15 set means bits 0–14 index
`multi_dir`, for the tiles that name more than one timezone. The section must be
8-byte aligned and `keys` starts at section offset 16.

Limits:

| Field | Width | Limit |
| --- | --- | --- |
| NAMES index / `multi_dir` index | 15 bits | ≤ 32,767, so `tz_count` ≤ 32,768 when FUZZY is present |
| `multi_dir.first + count` | u16 | `multi_value_count` ≤ 65,535 |
| tile x, y | 28 bits | < 2²⁸ |

For the `2026c` dataset that is 87,572 tiles, 156 of which name two timezones —
about 880 KB encoded. An encoder emitting FUZZY must verify that the preindex
version, the geometry version, and the header `data_version` all agree.

## 5. E-profile geometry

### 5.1 RINGDIR, type 4

28-byte records:

| Offset | Size | Field |
| ---: | ---: | --- |
| 0 | 4 | `op_first`, index into RINGOPS |
| 4 | 4 | `point_count`, expanded open-form vertex count |
| 8 | 2 | `op_count` |
| 10 | 2 | reserved |
| 12 | 16 | ring bounding box, four `i32` values |

A ring contains at least 3 open-form points. Its operations form a cycle and
share junction vertices: for each cyclic pair, the first operation's ring-order
exit point equals the next operation's ring-order entry point. The stored count
satisfies:

```
ring.point_count = sum(referenced_group.point_count) - ring.op_count
```

### 5.2 RINGOPS, type 5

An array of `u32` words:

```
bit 31:     reversed
bits 0..30: group index into GROUPDIR
```

The flag describes ring-order traversal, and encoders set it only for shared
edges. Point-in-polygon evaluation may scan every group forward, because
ray-crossing parity depends on the segment set, not on segment order.

### 5.3 GROUPDIR, type 6

44-byte records:

| Offset | Size | Field |
| ---: | ---: | --- |
| 0 | 4 | `chunk_first`, index into CHUNKDIR |
| 4 | 4 | `point_count` |
| 8 | 2 | `chunk_count` |
| 10 | 2 | reserved |
| 12 | 8 | first point, `first_lng, first_lat` |
| 20 | 8 | last point, `last_lng, last_lat` |
| 28 | 16 | group bounding box, four `i32` values |

A group is either a shared edge or a merged inline run; both have the same
representation. It holds at least 2 points, stores both endpoints, and has no
duplicate consecutive points. A single-op closed ring may have `first == last`.
For a forward operation entry is `first` and exit is `last`; a reversed operation
swaps them.

Shared-edge deduplication is represented in this section: a boundary between two
timezones is stored once as a group and referenced by both rings, once forward
and once reversed.

### 5.4 CHUNKDIR, type 7

24-byte records:

| Offset | Size | Field |
| ---: | ---: | --- |
| 0 | 4 | `point_off`, byte offset in POINTS |
| 4 | 2 | `point_count` |
| 6 | 2 | reserved |
| 8 | 16 | segment bounding box, four `i32` values |

A group's chunks are contiguous, ordered, and partition its points; every group
has at least one chunk and every chunk at least one point. `point_off` values are
strictly increasing, and a chunk's byte range ends at the next chunk's
`point_off` — the final chunk ends at the end of POINTS.

A chunk bounding box covers the segments between consecutive points inside the
chunk, plus the segment from its last point to the next chunk's first point when
a next chunk exists in the same group. A reader can therefore skip a chunk
without decoding it.

The encoder's target chunk size is recorded in the header's `chunk_target` field
and does not affect decoding. The artifacts published up to tzf-dist
`v0.0.2026-c-tzb1` used 256-point chunks; `v0.0.2026-c-tzb2` (2026-09-14) and
the `topo2embed` default since tzf v2.1.0 use 64, which shortens the byte range
a reader decodes around a query at the cost of about 5% (lite) to 11% (full) in
file size. The format itself is unchanged, and either reader opens either data
release.

A decoder consumes exactly `point_count` points within the chunk byte range. The
cursor must equal the range end after the final latitude varint; crossing the
range boundary or leaving trailing bytes is an error.

### 5.5 POINTS, type 9

POINTS is the concatenation of independently decodable chunk streams:

```
zigzag-LEB128 absolute_lng
zigzag-LEB128 absolute_lat

repeat point_count - 1 times:
    zigzag-LEB128 delta_lng
    zigzag-LEB128 delta_lat
```

Each chunk restarts with an absolute point, so chunks can be skipped
independently. Decode deltas with checked `int32` accumulation. Zigzag encoding
for an `int32` value `v` is `uint32((v << 1) ^ (v >> 31))`.

## 6. M-profile geometry

The M profile replaces the chunk machinery with two sections, so no decoding
happens at open time: ring storage aliases the mapped file directly.

### 6.1 FLATPOINTS, type 12

A bare array of `(int32 lng, int32 lat)` pairs, little-endian, concatenating
every ring's open point sequence, with junction duplicates already expanded.
The pair count is the section length divided by 8; the section must be 8-byte
aligned and its length a multiple of 8.

### 6.2 FLATRINGDIR, type 13

24-byte records:

| Offset | Size | Field |
| ---: | ---: | --- |
| 0 | 4 | `point_first`, pair index into FLATPOINTS |
| 4 | 4 | `point_count`, open-form vertex count, ≥ 3 |
| 8 | 16 | ring bounding box, four `i32` values |

### 6.3 YSTRIPES, type 14 (assigned, not emitted)

A serialized form of the per-ring horizontal-stripe point-in-polygon index:

```
RINGSTRIPEDIR[ring_count]   (24-byte records, parallel to FLATRINGDIR):
    u32 stripe_first     // into STRIPES, absolute
    u32 stripe_count     // 0 -> no index for this ring (linear scan)
    u32 index_first      // into INDEXES, absolute
    u32 index_count
    i32 min_y
    i32 height
STRIPES:  (u32 start, u32 count) pairs; start relative to index_first
INDEXES:  u32 segment indices, packed by stripe
```

Stored content must be bit-identical to what tzf's `geom.buildYStripes`
produces. The first M-profile release does not emit the section: on the lite
dataset it would add an estimated 6–10 MB to a 10 MB file, while rebuilding the
index at open costs about 5 ms on a multi-core host. Specifying it now keeps a
later addition within a `format_minor` increment.
[Choosing a Finder]({{< relref "../guides/choosing-a-finder" >}}) records the
open-time cost of that rebuild under a single-core CPU quota.

### 6.4 Size breakdown

Lite `2026c`, M profile, no YSTRIPES:

| Component | Size |
| --- | ---: |
| FLATPOINTS (1,304,553 pairs) | 10,436 KB |
| FLATRINGDIR (2,078 records) | 49 KB |
| TZDIR + POLYDIR + NAMES | ~51 KB |
| GRID | ~569 KB |
| FUZZY | ~880 KB |
| **Total** | **≈ 12.0 MB** |

Expanding the same way on the full dataset yields 8,377,299 pairs, about 67 MB.
`full.tzm` is not distributed.

## 7. Lookup semantics

1. Reject NaN, infinity, longitude outside `-180..180`, or latitude outside
   `-90..90`.
2. Scale once without rounding: `x = float64(lng) * 100000.0`,
   `y = float64(lat) * 100000.0`.
3. Read candidates from GRID, or scan TZDIR when GRID is absent.
4. If the grid cell has exactly one candidate, `NO_SHORTCUT` is clear,
   `-179 < lng < 179`, and `-89 < lat < 89`, return that candidate directly.
5. Otherwise test candidates in stored ascending order, applying timezone,
   polygon, ring, group, and chunk bounding boxes before decoding any geometry.
6. A polygon contains the point when its exterior contains it and none of its
   holes does.
7. Return the first containing candidate, or no result when none contains it.

For point-in-polygon evaluation in the E profile, scan each referenced group's
stored points forward regardless of the `reversed` flag, evaluate the segment
joining consecutive chunks, and for each cyclic operation junction derive exit
and entry from GROUPDIR — equal endpoints add no segment, differing endpoints
add the segment from exit to entry.

A group or chunk can be skipped when:

```
y < min_lat
y > max_lat
max_lng < x
```

Multi-result lookup disables the single-candidate shortcut, evaluates every
candidate, and sorts matches lexicographically by unsigned UTF-8 name bytes.

### Boundary semantics

Timezone polygons cover the globe without gaps, so a query on a shared border
falls on two polygons at once. The v2 runtime uses allow-on-edge containment:
an exterior ring treats a point on one of its segments as contained, a hole ring
does not. A point on a shared border therefore belongs to every touching polygon.

Earlier revisions of this format stated the rule under which a point on any
ring segment counts as outside that ring; they predated
[tzf#216](https://github.com/ringsaturn/tzf/issues/216). The current rule is
the implemented behaviour described here.

## 8. Validation and compatibility

A reader must reject structural errors without panic, overread, integer
overflow, or undefined behaviour. At open time, validate at least:

- magic, major version, header size, coordinate scale, profile, and actual file
  size;
- section table bounds using wide arithmetic;
- presence and uniqueness of the sections mandatory for the profile, and absence
  of cross-profile section types;
- agreement between `GRID_PRESENT` and the GRID section;
- section alignment, bounds, and non-overlap;
- directory section lengths against their record widths;
- NAMES offsets and string validity;
- GRID dimensions, section length, and coordinate-key bounds;
- FUZZY section length against its declared counts.

Directory ranges, group and ring point-count sums, operation indices, chunk
offsets, exact varint termination, bounding box order, candidate indices, and
delta overflow must be checked either at open time or before first use.

Reserved fields and bits are written as zero and ignored on read; readers also
ignore unknown section types. An incompatible layout increments `format_major`.
Additive changes increment `format_minor` and may add section types, flag bits,
or meanings for reserved fields. Format 1.1 used that mechanism to add the
profile byte and the FUZZY, FLATPOINTS, FLATRINGDIR, and YSTRIPES types.

Deep semantic checks — bounding-box containment, stored group endpoints,
junction connectivity, geometry parity — are encoder and build-pipeline
responsibilities. The CRC protects a verified artifact against accidental
corruption.

`data_version` identifies the timezone dataset independently of the format
version.

## 9. Published artifacts

| File | Profile | Size | Backs |
| --- | --- | ---: | --- |
| `lite.tzb` | E | 3,973,696 B (~4 MB) | Go `NewEmbeddedFinder`, Rust `EmbeddedFinder` / `DefaultFinder`, tzfpy |
| `lite.tzm` | M | 10,180,180 B (~10 MB) | Go `NewDefaultFinder` |
| `full.tzb` | E | 13,765,490 B (~14 MB) | Go `NewFullFinder`, Rust `DefaultFinder::new_full` |

All three carry a FUZZY section and the same `data_version`. There is no
published `full.tzm`; derive it locally with `cmd/tzb2tzm` when you need it.
