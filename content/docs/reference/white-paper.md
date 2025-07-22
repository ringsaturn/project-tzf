---
title: "Technical White Paper"
description: ""
summary: ""
date: 2025-07-21T14:20:56+09:00
lastmod: 2025-07-21T14:20:56+09:00
draft: false
weight: 100
toc: true
seo:
  title: "" # custom title (optional)
  description: "" # custom description (recommended)
  canonical: "" # custom canonical URL (optional)
  noindex: false # false (default) or true
---

## Introduction

In the beginning, tzf was designed for backend services that need to convert
coordinates to timezones, mostly for geo and weather services.

As the project evolved, we need to add Python support since timezonefinder's
speed around borders could not satisfy our needs back then.

Thats why tzf(Golang), tzfpy(Python), tzf-rs(Rust) were created.

It's clear that we need a high performance library for this purpose, and we can
accept not too accurate around borders, let's say incorrect result around
borders 1KM range is acceptable for us.

So we need a library that can:

- Convert coordinates to timezones.
- Performance is more important than accuracy
- At least support Go and Python. (Rust was developed because of the the
  ecosystem of PyO3).
- Less distribution/binary size, since we need to use it in backend services.

In these white paper, two topics will be explained in detail:

- Polygon simplification
- Tile based indexing

Others, like the implementation details of the library, will be explained in the
codebase.

## Polygon simplification

First, we converted the GeoJSON polygon data into a binary encoding using
Protocol Buffers, reducing the file size by approximately 80 MB:

```proto
message Point {
  float lng = 1;
  float lat = 2;
}

message Polygon {
  repeated Point points = 1;
  repeated Polygon holes = 2;
}

message Timezone {
  repeated Polygon polygons = 1;
  string name = 2;
}

message Timezones {
  repeated Timezone timezones = 1;
}
```

This conversion still required about 900 MB of memory to load. To further
optimize, we applied the
[Ramer–Douglas–Peucker (RDP) algorithm][Ramer–Douglas–Peucker_algorithm]
to simplify polygon shapes by reducing the number of points:

[Ramer–Douglas–Peucker_algorithm]: https://en.wikipedia.org/wiki/Ramer–Douglas–Peucker_algorithm

![The effect of varying epsilon in a parametric implementation of RDP, [source](https://en.wikipedia.org/wiki/File:RDP,_varying_epsilon.gif)](/img/history-of-tzf/RDP_varying_epsilon.gif)

After filtering, the data size dropped to approximately 11 MB. Finally, we
employed Google Maps' Polyline encoding algorithm to compress the coordinate
sequences into a compact ASCII representation, reducing the file size to about
4.6 MB for efficient distribution.

If you want to know the actual parameter for the simplification, you can see
[the code](https://github.com/ringsaturn/tzf/blob/aa625496b23f1e6af92e9b457394bc3e4dc19bbf/reduce/reduce.go#L18).

## Tile based indexing

A naïve Ray Casting approach operates in O(n^2) time, which is unsuitable for
high-concurrency backend services. We considered spatial R-trees but found
minimal performance gains given the small number of global time zones and their
uneven area distributions.

Instead, we adopted a tile-based indexing scheme inspired by map tile formats
used in weather data services. Each tile defines a quadrilateral region at a
given zoom level:

```txt
┌───────────┬───────────┬───────────┐
│           │           │           │
│           │           │           │
│ x-1,y-1,z │ x+0,y-1,z │ x+1,y-1,z │
│           │           │           │
│           │           │           │
├───────────┼───────────┼───────────┤
│           │           │           │
│           │           │           │
│ x-1,y+0,z │ x+0,y+0,z │ x+1,y+0,z │
│           │           │           │
│           │           │           │
├───────────┼───────────┼───────────┤
│           │           │           │
│           │           │           │
│ x-1,y+1,z │ x+0,y+1,z │ x+1,y+1,z │
│           │           │           │
│           │           │           │
└───────────┴───────────┴───────────┘
```

This quadtree-like layout ensures parent tiles contain exactly four child tiles,
allowing aggregation without gaps:

![Tile-based timezone index demo(not the real data being used), A live demo to show polygon and it's index can be view via [tzf-web][tile_index_live_view]](/img/history-of-tzf/preindex-timezone-preview-we.png)

[tile_index_live_view]: https://ringsaturn.github.io/tzf-web/?markers=%5B%7B%22lat%22%3A52.2076%2C%22lng%22%3A9.668%7D%5D&lat=50.310392&lng=11.887207&zoom=6&showIndex=true

When querying a point's timezone, we identify the corresponding tile at the
precomputed zoom level and only test against the small subset of polygons
indexed within that tile, achieving near-constant query time.
