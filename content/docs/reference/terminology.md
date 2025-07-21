---
title: "Terminology"
description: "Comprehensive reference of terms and concepts used in the tzf ecosystem"
summary: "Key terminology for GPS coordinate to timezone conversion using the tzf ecosystem"
date: 2025-07-21T21:09:40+09:00
lastmod: 2025-07-21T21:09:40+09:00
draft: false
weight: 999
toc: true
seo:
  title: "TZF Terminology Reference" # custom title (optional)
  description: "Complete reference of terms used in the tzf ecosystem for GPS coordinate to timezone conversion" # custom description (recommended)
  canonical: "" # custom canonical URL (optional)
  noindex: false # false (default) or true
---

## Geographic and Coordinate Terms

### GPS Coordinates / GPS Points

Latitude and longitude pairs used to specify exact locations on Earth's surface.
Expressed as decimal degrees (e.g., 116.3883, 39.9289 for Beijing) and used as
input for timezone lookup operations.

### Longitude (lng)

East-west position on Earth's surface, ranging from -180 to 180 degrees. First
coordinate in coordinate pairs throughout the tzf ecosystem, critical for
timezone boundary calculations.

### Latitude (lat)

North-south position on Earth's surface, ranging from -90 to 90 degrees. Second
coordinate in coordinate pairs throughout the tzf ecosystem, used alongside
longitude for precise location identification.

### Coordinate Order

Standard format: longitude, latitude (lng, lat). Consistently used across all
tzf implementations, different from some geographic systems that use lat, lng
order.

## Timezone and Temporal Concepts

### Timezone Name

IANA timezone identifier (e.g., "Asia/Shanghai", "America/New_York"). Primary
output of tzf lookup operations, used with datetime libraries for time
conversions.

### Timezone Lookup

Process of converting GPS coordinates to timezone identifiers. Core
functionality provided by all tzf implementations, can return single timezone or
multiple timezones for boundary regions.

### Multiple Timezones

Locations near timezone boundaries may return multiple possible timezones.
Handled by functions like `get_tzs()`, `get_tz_names()`, `getTimezones()`,
providing flexibility for applications dealing with boundary ambiguity.

## Core TZF Ecosystem Terms

### Project TZF

Multi-language ecosystem for converting GPS coordinates to timezones.
Prioritizes performance over perfect accuracy around boundaries, supporting Go,
Rust, Python, Swift, Ruby, JavaScript/WASM, and more.

### tzf (Go Implementation)

Original Go library (`ringsaturn/tzf`). Core processing engine for the entire
ecosystem, provides `DefaultFinder`, `Finder`, and `FuzzyFinder` classes.

### tzf-rs (Rust Implementation)

Rust port of tzf (`ringsaturn/tzf-rs`). Foundation for Python, Ruby, and WASM
bindings, offers `DefaultFinder`, `Finder`, and `FuzzyFinder` implementations.

### tzfpy (Python Bindings)

Python bindings for tzf-rs using PyO3. Simple API with `get_tz()` and
`get_tzs()` functions.

### tzf-swift (Swift Implementation)

Native Swift implementation. Provides `DefaultFinder`, `Finder`, and
`FuzzyFinder` classes, includes data version tracking functionality.

### tzf-rb / tzf-wasm

Ruby bindings (community maintained) and WebAssembly version. Extend tzf
functionality to web browsers and Ruby applications, enable client-side timezone
lookups.

## Data and Performance Concepts

### Default Data vs Full Data

- **Full Data**: Complete precision data (~90MB) for 100% accurate lookups
- **Lite Data**: Simplified polygon shapes (~10MB) for faster performance
- **Compressed Data**: Compressed Lite Data\* (~4.6MB) for efficient data distribution, use Polyline encoding.
- **Preindex Data**: Tile-based indexing data (~1.78MB).

Trade-off between memory usage, accuracy, and performance.

### Polygon Simplification

Process using Ramer-Douglas-Peucker (RDP) algorithm. Reduces timezone boundary
complexity while maintaining reasonable accuracy, key optimization technique for
reducing memory footprint.

### Tile-Based Indexing

Spatial indexing scheme inspired by map tile formats. Divides Earth's surface
into quadrilateral tiles at different zoom levels, enables O(1) lookup
performance instead of O(n²) naive approaches.

### Finder Classes

- **Finder**: Polygon-based implementation for precise timezone lookups
- **FuzzyFinder**: Tile-index based implementation for fast approximate lookups
- **DefaultFinder**: Combined implementation using both Finder and FuzzyFinder
  for optimal performance

### Data Version

Version identifier for timezone boundary data (e.g., "2025b"). Based on IANA
timezone database releases, accessible through `data_version()` functions across
implementations.

## Technical Implementation Terms

### Protocol Buffers (protobuf)

Binary encoding format used for efficient data storage and transmission. Reduces
timezone data size by approximately 80MB compared to GeoJSON, enables
cross-language compatibility in the tzf ecosystem.

### Polyline Encoding

Google Maps algorithm for compressing coordinate sequences. Applied after
polygon simplification to achieve final data compression, reduces final data
size to ~4.6MB for distribution.

### Ray Casting

Geometric algorithm for point-in-polygon testing. Naive O(n²) approach replaced
by tile-based indexing, traditional method for determining if coordinates fall
within timezone boundaries.

### CGO vs PyO3

- **CGO**: Original Go-to-Python binding method (deprecated in tzfpy)
- **PyO3**: Current Rust-to-Python binding framework used in tzfpy

PyO3 provides better performance and maintainability.

## API and Integration Terms

### Batch Processing

Processing multiple coordinate pairs efficiently. Supported through vectorized
operations in NumPy, Pandas, and Polars, critical for applications processing
large datasets.

### Global Variable Pattern

Recommended practice for reusing expensive finder initialization. Prevents
repeated memory allocation and data loading, essential for production
applications and web services.

### Memory Usage

- Default implementation: ~150MB init, ~60MB after GC
- Full precision: ~900MB init, ~660MB after GC

Important consideration for deployment and scaling.

### Lazy Initialization

Pattern of initializing finder objects only when first used. Reduces startup
time for applications, recommended in production environments.

## Distribution and Ecosystem Terms

### tzf-rel / tzf-rel-lite

Data distribution repositories containing processed timezone data.
It's only empact on Go side, for other languages.

- **tzf-rel**: Full ecosystem data distribution
- **tzf-rel-lite**: Lightweight version specifically for Go applications, which removed full data

For Rust side, tzf-rel will publish a crate, because of the file-size limit, full data is not included.

For Python side, since tzfpy is just a wrapper, so it's not necessary to publish a crate.

For Swift side, full-data is not included.

### Data Pipeline

5-layer architecture from source data to end applications. L0: Source data, L1:
Core processing, L2: Distribution, L3: Language implementations, L4: Bindings,
L5: Applications. Ensures consistent data flow across the entire ecosystem.

See more in [Data Pipeline]({{< relref "data-pipeline" >}}).

### CLI Tools

Command-line interfaces available for both Go (`tzf`) and Rust (`tzf-rs`).
Support single coordinate lookup and batch processing via stdin, enable shell
scripting and automation workflows.

## Application and Service Terms

### HTTP API / Web Services

RESTful services like `racemap/rust-tz-service` and `ringsaturn/tzf-server`.
Enable timezone lookups over network protocols, support for production web
applications.

### Redis Protocol

Redis-compatible server implementations (`redizone`). Enables high-performance
lookups, integrates with existing Redis infrastructure.

### WebAssembly (WASM)

Browser-compatible version for client-side timezone lookups. Eliminates server
round-trips for web applications, available through `tzf-wasm` package.

### PostgreSQL Extension

Database extension (`pg_tzf`) for in-database timezone lookups. Enables SQL
queries with timezone conversion, integrates timezone functionality directly
into database operations.
