---
date: '2025-07-21T12:06:56+09:00'
description: tzfpy 2.0 のベストプラクティスと統合パターン。API の構成、日時変換、バッチ処理、GeoJSON エクスポート、Web API を扱います。
draft: false
lastmod: '2026-09-14T00:00:00+09:00'
seo:
  description: tzfpy 2.0 のベストプラクティス。6 つのモジュール関数、日時変換、Pandas/Polars/NumPy を使ったバッチ処理、GeoJSON エクスポート、FastAPI 統合を扱います。
  noindex: false
  title: 'Python (tzfpy) ガイド - Project tzf'
summary: tzfpy 2.0 を日時ライブラリ、データフレーム（Pandas、Polars、NumPy）、GeoJSON エクスポート、FastAPI で使用する方法。
title: Python (tzfpy)
toc: true
weight: 4
---

tzfpy は IANA タイムゾーン名の文字列を返します。このセクションでは、その名前を一般的な Python ライブラリで使用する方法を紹介します。

## API の構成

tzfpy 2.0 は tzf-rs 2.0 に対する [PyO3](https://pyo3.rs/) バインディングであり、tzf-rs は `.tzb` 埋め込みバイナリ形式を読み込みます。公開されているのは、プロセスグローバルな 1 つの Finder に対する 6 つのモジュールレベル関数です。構築するクラスはありません。

```python
from tzfpy import (
    get_tz,                  # (lng, lat) -> str        最初の一致、ファジー優先
    get_tzs,                 # (lng, lat) -> list[str]  すべての一致、ポリゴンで厳密に判定
    timezonenames,           # () -> list[str]
    data_version,            # () -> str、例："2026c"
    get_tz_polygon_geojson,  # (name) -> str  境界ポリゴンを GeoJSON で返す
    get_tz_index_geojson,    # (name) -> str  FUZZY プレインデックスタイルを GeoJSON で返す
)
```

```python
>>> get_tz(116.3883, 39.9289)   # (経度，緯度) の順
'Asia/Shanghai'
>>> get_tzs(87.4160, 44.0400)
['Asia/Shanghai', 'Asia/Urumqi']
```

Finder は初回使用時に遅延構築されます。アプリケーションの起動時に `_ = get_tz(0, 0)` のような呼び出しを行うと、そのコストが最初のリクエストの外に移ります。

Python 3.10 以降が必要です。wheel は 3.10 以降の `abi3` です。

### どちらのクエリを呼ぶか

`get_tz` はファジー優先です。タイルプレインデックスが大部分のクエリを point-in-polygon なしで解決します。`get_tzs` はポリゴンによる厳密な判定を行い、プレインデックスを参照せず、すべての一致を返します。地点が複数のタイムゾーンに属する可能性がある場合や、呼び出し側が単一の一致と切り詰められた結果を区別する必要がある場合に該当します。共有境界上の地点は、接するすべてのポリゴンに属します。

### 対象範囲

PyPI の wheel は 1 つのデフォルト Finder を通じて lite データセットを公開します。lite データセットに対するインプレースの低メモリ Finder は Go と Rust で利用できます。完全精度の検索は実験的な `+full` wheel として提供され、プレリリースタグ（これまでに 2.1.0b1 と 2.1.0b2）から tzfpy 独自のインデックスと GitHub Releases にのみ公開されます。PyPI には公開されません。

```bash
pip install --pre tzfpy --index-url https://ringsaturn.github.io/tzfpy/full/simple/
```

`+full` ビルドは tzf-rs の `EmbeddedFinder` で `full.tzb` を参照するため、lite wheel より保持するメモリが少なく、境界付近の地点には簡略化前の境界データで回答します。インポート名と API は同じで、`importlib.metadata.version("tzfpy")` の末尾が `+full` になります。Apple M3 Max（CPython 3.14）で citiespy の全 154,694 都市を対象に、tzfpy 2.1.0b2 を測定した値は次の通りです。

| 指標 | Lite | `+full` |
| --- | ---: | ---: |
| wheel サイズ（macOS arm64） | 3.0 MB | 11.8 MB |
| 初回クエリ後の RSS 増分 | 39.0 MB | 16.0 MB |
| コールドスタート（import + 初回クエリ） | 15 ms | 10 ms |
| `get_tz` 中央値 | 208 ns | 250 ns |
| `get_tzs` 中央値（ポリゴン走査） | 375 ns | 791 ns |

どちらについても [Finder の選択]({{< relref "choosing-a-finder" >}})を参照してください。

## 日時変換

### `zoneinfo` を使用（標準ライブラリ）

```bash
pip install tzfpy
```

```python
# https://github.com/ringsaturn/tzfpy/blob/main/examples/tzfpy_with_datetime.py
from datetime import datetime, timezone
from zoneinfo import ZoneInfo

from tzfpy import get_tz

tz = get_tz(139.7744, 35.6812)  # 東京

now = datetime.now(timezone.utc)
now = now.replace(tzinfo=ZoneInfo(tz))
print(now)
```

出力：

```
2025-04-29 01:33:56.325194+09:00
```

### `arrow` を使用

```bash
pip install arrow tzfpy
```

```python
# https://github.com/ringsaturn/tzfpy/blob/main/examples/tzfpy_with_arrow.py
from zoneinfo import ZoneInfo

import arrow
from tzfpy import get_tz

tz = get_tz(139.7744, 35.6812)  # 東京

arrow_now = arrow.now(ZoneInfo(tz))
print(arrow_now)
```

出力：

```
2025-04-29T10:33:45.551282+09:00
```

### `whenever` を使用

```bash
pip install tzfpy whenever
```

```python
# https://github.com/ringsaturn/tzfpy/blob/main/examples/tzfpy_with_whenever.py
from tzfpy import get_tz
from whenever import Instant

now = Instant.now()
tz = get_tz(139.7744, 35.6812)  # 東京
now = now.to_tz(tz)
print(now)
```

出力：

```
2025-04-29T10:33:28.427784+09:00[Asia/Tokyo]
```

## データフレームを使ったバッチ処理

大量の座標からタイムゾーンへ変換する場合は、行ごとのループを避け、ベクトル化された操作を使用してください。

### Pandas + NumPy

```bash
pip install pandas numpy tzfpy
```

```python {hl_lines=["21","25","27"]}
# https://github.com/ringsaturn/tzfpy/blob/main/examples/tzfpy_with_dataframe_pandas.py
import time

import citiespy
import numpy as np
import pandas as pd
import tzfpy

# ベンチマーク前に遅延初期化をトリガー
_ = tzfpy.get_tz(0, 0)

cities_as_dict = [{"name": c.name, "lng": c.lng, "lat": c.lat} for c in citiespy.all_cities()]
df = pd.DataFrame(cities_as_dict)

start = time.perf_counter()
df["tz"] = df.apply(lambda x: tzfpy.get_tz(x.lng, x.lat), axis=1)
end = time.perf_counter()
print(f"Pandas apply: {end - start:.3f}s")

vec_get_tz = np.vectorize(tzfpy.get_tz)
start = time.perf_counter()
df["tz_vec"] = vec_get_tz(df.lng, df.lat)
end = time.perf_counter()
print(f"NumPy vectorize: {end - start:.3f}s")
```

出力：

```
Pandas apply: 0.828s
NumPy vectorize: 0.348s
```

### Polars

```bash
pip install polars tzfpy
```

```python {hl_lines=["13-19"]}
import time

import citiespy
import polars as pl
import tzfpy

_ = tzfpy.get_tz(0, 0)

cities_as_dict = [{"name": c.name, "lng": c.lng, "lat": c.lat} for c in citiespy.all_cities()]
df = pl.from_dicts(cities_as_dict)

start = time.perf_counter()
df = df.with_columns(
    pl.struct(["lng", "lat"])
    .map_elements(
        lambda cols: tzfpy.get_tz(cols["lng"], cols["lat"]), return_dtype=pl.Utf8
    )
    .alias("tz")
)
end = time.perf_counter()
print(f"Polars: {end - start:.3f}s")
```

出力：

```
Polars: 0.346s
```

### 純粋な NumPy

```bash
pip install numpy tzfpy
```

```python {hl_lines=["14", "17"]}
import time

import citiespy
import numpy as np
import pandas as pd
import tzfpy

_ = tzfpy.get_tz(0, 0)

cities_as_dict = [{"name": c.name, "lng": c.lng, "lat": c.lat} for c in citiespy.all_cities()]
df = pd.DataFrame(cities_as_dict)

vec_get_tz = np.vectorize(tzfpy.get_tz)
start = time.perf_counter()
_ = vec_get_tz(df.lng.values, df.lat.values)
end = time.perf_counter()
print(f"NumPy: {end - start:.3f}s")
```

出力：

```
NumPy: 0.335s
```

## GeoJSON エクスポート

どちらのエクスポート関数もシリアライズ済みの GeoJSON 文字列を返します。`get_tz_polygon_geojson` はタイムゾーンの境界を返します。`get_tz_index_geojson` は、そのタイムゾーンを指す FUZZY プレインデックスタイルのバウンディング矩形を返します。これは `get_tz` が point-in-polygon にフォールバックせずプレインデックスから応答する領域です。

```python
from tzfpy import get_tz, get_tz_index_geojson, get_tz_polygon_geojson

lng, lat = -74.0060, 40.7128
tz = get_tz(lng, lat)

with open("tz_nyc_polygon.geojson", "w") as f:
    f.write(get_tz_polygon_geojson(tz))

with open("tz_nyc_index.geojson", "w") as f:
    f.write(get_tz_index_geojson(tz))
```

どちらも未知のタイムゾーン名に対して `ValueError` を送出します。`get_tz_index_geojson` は、そのタイムゾーンを指すプレインデックスタイルが存在しない場合にも `ValueError` を送出します。

## v1 からの移行

4 つのクエリ関数は変更されていません。

| v1 | v2 |
| --- | --- |
| `get_tz`、`get_tzs`、`timezonenames`、`data_version` | 変更なし |
| `_TZFPY_DISABLE_Y_STRIPES=1` | 削除。YStripes インデックスは常に有効です |
| 内部の `.unwrap()` で例外を送出していた GeoJSON ヘルパー | `get_tz_polygon_geojson` / `get_tz_index_geojson`。一致しない場合は `ValueError` を送出します |
| — | 追加：プレインデックスのカバー範囲を返す `get_tz_index_geojson` |

内部の変更点は次の通りです。protobuf の削除により wheel は 4.31 MB から 2.76 MB に、Finder の初期化は 68 ms から 15 ms になり、クエリレイテンシは変わりませんでした（v2 への切り替えコミットでメンテナが測定）。[tz-benchmark](https://github.com/ringsaturn/tz-benchmark) の 2026-09-14 スナップショット（Apple M3 Max、tzfpy 2.1.0b2）では、lite wheel のロード後の常駐セットは 60.2 MiB、インタプリタの下限値は 22.4 MiB、ランダム都市検索の中央値は 625 ns です。`+full` wheel は 38.2 MiB と 667 ns です。

v1 系列（tzfpy 1.3.x）は引き続き利用でき、最後のデータリリースで凍結されます。v2 のセットが公開された時点で tzf-dist は protobuf の成果物の配布を終了するためです。

## FastAPI を使った Web API

```bash
pip install fastapi uvicorn tzfpy
```

```python
from fastapi import FastAPI, Query
from pydantic import BaseModel, Field
from tzfpy import data_version, get_tz, get_tzs, timezonenames

# 起動時に遅延初期化をトリガー
_ = get_tz(0, 0)


class TimezoneResponse(BaseModel):
    timezone: str = Field(..., description="タイムゾーン", examples=["Asia/Tokyo"])


class TimezonesResponse(BaseModel):
    timezones: list[str] = Field(
        ..., description="タイムゾーン一覧", examples=[["Asia/Shanghai", "Asia/Urumqi"]]
    )


class TimezonenamesResponse(BaseModel):
    timezonenames: list[str] = Field(
        ..., description="全タイムゾーン名", examples=[["Etc/GMT+1", "Etc/GMT+2"]]
    )


class DataVersionResponse(BaseModel):
    data_version: str = Field(..., description="データバージョン", examples=["2026c"])


app = FastAPI(title="tzfpy with FastAPI")


@app.get("/timezone", response_model=TimezoneResponse)
def get_timezone(
    longitude: float = Query(..., ge=-180, le=180, examples=[139.767125]),
    latitude: float = Query(..., ge=-90, le=90, examples=[35.681236]),
):
    return TimezoneResponse(timezone=get_tz(longitude, latitude))


@app.get("/timezones", response_model=TimezonesResponse)
def get_timezones(
    longitude: float = Query(..., ge=-180, le=180, examples=[87.617733]),
    latitude: float = Query(..., ge=-90, le=90, examples=[43.792818]),
):
    return TimezonesResponse(timezones=get_tzs(longitude, latitude))


@app.get("/timezonenames", response_model=TimezonenamesResponse)
def get_all_timezones():
    return TimezonenamesResponse(timezonenames=timezonenames())


@app.get("/data_version", response_model=DataVersionResponse)
def get_data_version():
    return DataVersionResponse(data_version=data_version())


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8010)
```
