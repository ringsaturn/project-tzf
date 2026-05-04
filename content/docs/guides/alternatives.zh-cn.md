---
date: '2025-07-19T12:39:57+09:00'
description: 其他 GPS 坐标转时区库，涵盖 Go、Rust、Python、Ruby、Swift 及数据库。
lastmod: '2025-07-19T12:39:57+09:00'
seo:
  description: 其他 GPS 坐标转时区库，适用于 Go、Rust、Python、Ruby、Swift 及数据库。
  noindex: false
  title: 替代方案 - Project tzf
summary: 各种语言和环境下替代时区查询库的汇总列表。
title: 替代方案
toc: true
weight: 90
---

请注意，不同项目可能有不同的设计目标（速度、准确性、数据来源等）。
请自行研究哪个最适合你的使用场景。

本页面并非所有替代方案的完整列表。

建议先查看 [evansiroky/timezone-boundary-builder](https://github.com/evansiroky/timezone-boundary-builder) 的 <u>[Lookup Libraries](https://github.com/evansiroky/timezone-boundary-builder?tab=readme-ov-file#lookup-libraries)</u> 部分。

Stack Overflow 上还有一个相关问题：[How to get a time zone from a location using latitude and longitude coordinates?](https://stackoverflow.com/questions/16086962/)。

## Go

- <u>**<https://github.com/ringsaturn/tzf>**</u>
- <https://github.com/bradfitz/latlong>
- <https://github.com/evanoberholster/timezoneLookup>
- <https://github.com/albertyw/localtimezone/>
- <https://github.com/ugjka/go-tz>
- <https://github.com/zsefvlol/timezonemapper>

## Rust

- <u>**<https://github.com/ringsaturn/tzf-rs>**</u>
- <https://github.com/twitchax/rtz>
- <https://github.com/huonw/tz-search>
- <https://github.com/nicholasbishop/zone-detect-rs>
- <https://github.com/moranbw/spatialtime>

## Python

- <u>**<https://github.com/ringsaturn/tzfpy>**</u>
- <https://github.com/jannikmi/timezonefinder>
  - 参见其与 tzfpy 的对比：[Comparison to tzfpy](https://timezonefinder.readthedocs.io/en/latest/3_about.html#comparison-to-tzfpy) 以及 tzfpy 相关讨论：[`ringsaturn/tzfpy#94`](https://github.com/ringsaturn/tzfpy/issues/94)
- <https://github.com/pegler/pytzwhere>

## Ruby

- <u>**<https://github.com/HarlemSquirrel/tzf-rb>**</u>
- <https://github.com/zverok/wheretz>

## Swift

- <u>**<https://github.com/ringsaturn/tzf-swift>**</u>
- <https://github.com/patrick-zippenfenig/SwiftTimeZoneLookup>

## 数据库

- <u>**<https://github.com/ringsaturn/pg-tzf>**</u>
- [Building a location to time zone API with SpatiaLite, OpenStreetMap and Datasette](https://simonwillison.net/2017/Dec/12/location-time-zone-api/)
- [Geospatial SQL queries in SQLite using TG, sqlite-tg and datasette-sqlite-tg](https://til.simonwillison.net/sqlite/sqlite-tg)
- <https://github.com/LittleGreenViper/LGV_TZ_Lookup> with MySQL
