---
date: '2025-07-19T12:39:57+09:00'
description: Go、Rust、Python、Ruby、Swift、データベース向けの他の GPS 座標→タイムゾーン変換ライブラリ。
lastmod: '2025-07-19T12:39:57+09:00'
seo:
  description: Go、Rust、Python、Ruby、Swift、データベース向けの他の GPS 座標→タイムゾーン変換ライブラリ。
  noindex: false
  title: 代替ライブラリ——Project tzf
summary: さまざまな言語と環境向けの代替タイムゾーン検索ライブラリの一覧。
title: 代替ライブラリ
toc: true
weight: 90
---

異なるプロジェクトには異なる設計目標（速度、精度、データソースなど）があることにご注意ください。
ご自身のユースケースに最適なものをご自身で調査してください。

このページはすべての代替ライブラリの完全なリストではありません。

まず [evansiroky/timezone-boundary-builder](https://github.com/evansiroky/timezone-boundary-builder) の <u>[Lookup Libraries](https://github.com/evansiroky/timezone-boundary-builder?tab=readme-ov-file#lookup-libraries)</u> セクションを確認することをお勧めします。

Stack Overflow の関連質問もあります：[How to get a time zone from a location using latitude and longitude coordinates?](https://stackoverflow.com/questions/16086962/)

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
  - tzfpy との比較を参照：[Comparison to tzfpy](https://timezonefinder.readthedocs.io/en/latest/3_about.html#comparison-to-tzfpy) および tzfpy の issue：[`ringsaturn/tzfpy#94`](https://github.com/ringsaturn/tzfpy/issues/94)
- <https://github.com/pegler/pytzwhere>

## Ruby

- <u>**<https://github.com/HarlemSquirrel/tzf-rb>**</u>
- <https://github.com/zverok/wheretz>

## Swift

- <u>**<https://github.com/ringsaturn/tzf-swift>**</u>
- <https://github.com/patrick-zippenfenig/SwiftTimeZoneLookup>

## データベース

- <u>**<https://github.com/ringsaturn/pg_tzf>**</u>
- [Building a location to time zone API with SpatiaLite, OpenStreetMap and Datasette](https://simonwillison.net/2017/Dec/12/location-time-zone-api/)
- [Geospatial SQL queries in SQLite using TG, sqlite-tg and datasette-sqlite-tg](https://til.simonwillison.net/sqlite/sqlite-tg)
- <https://github.com/LittleGreenViper/LGV_TZ_Lookup> with MySQL
