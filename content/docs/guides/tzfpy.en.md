---
date: '2025-07-21T12:06:56+09:00'
description: Best practices and integration patterns for tzfpy 2.0 — API surface, datetime conversion, batch processing, GeoJSON export, and web APIs.
draft: false
lastmod: '2026-09-11T00:00:00+09:00'
seo:
  description: tzfpy 2.0 best practices — the six module functions, datetime conversion, batch processing with Pandas/Polars/NumPy, GeoJSON export, and FastAPI integration.
  noindex: false
  title: Python (tzfpy) Guide — Project tzf
summary: Using tzfpy 2.0 with datetime libraries, data frames (Pandas, Polars, NumPy), GeoJSON export, and FastAPI.
title: Python (tzfpy)
toc: true
weight: 4
---

tzfpy returns an IANA timezone name string. This section shows how to use that name with common Python libraries.

## The API surface

tzfpy 2.0 is a [PyO3](https://pyo3.rs/) binding over tzf-rs 2.0, which reads the
`.tzb` embedded binary format. The public surface is six module-level functions
over one process-global finder; there is no class to construct:

```python
from tzfpy import (
    get_tz,                  # (lng, lat) -> str        first match, fuzzy-first
    get_tzs,                 # (lng, lat) -> list[str]  every match, polygon-exact
    timezonenames,           # () -> list[str]
    data_version,            # () -> str, e.g. "2026c"
    get_tz_polygon_geojson,  # (name) -> str  boundary polygons as GeoJSON
    get_tz_index_geojson,    # (name) -> str  FUZZY preindex tiles as GeoJSON
)
```

```python
>>> get_tz(116.3883, 39.9289)   # (longitude, latitude) order
'Asia/Shanghai'
>>> get_tzs(87.4160, 44.0400)
['Asia/Shanghai', 'Asia/Urumqi']
```

The finder is built lazily on first use. A call such as `_ = get_tz(0, 0)` during
application startup moves that cost out of the first request.

Requires Python 3.10 or newer; wheels are `abi3` from 3.10 up.

### Which query to call

`get_tz` is fuzzy-first: a tile preindex answers most queries with no
point-in-polygon work. `get_tzs` is polygon-exact, does not consult the preindex,
and returns every match. It applies where a point may belong to several
timezones, and where the caller needs to distinguish a single match from a
truncated list. A point on a shared border belongs to every touching polygon.

### Scope

Full-precision lookups and the in-place low-memory finder are available in Go and
Rust only. tzfpy exposes the lite dataset through a single default finder.
[Choosing a Finder]({{< relref "choosing-a-finder" >}}) covers both.

## Datetime conversion

### Using `zoneinfo` (stdlib)

```bash
pip install tzfpy
```

```python
# https://github.com/ringsaturn/tzfpy/blob/main/examples/tzfpy_with_datetime.py
from datetime import datetime, timezone
from zoneinfo import ZoneInfo

from tzfpy import get_tz

tz = get_tz(139.7744, 35.6812)  # Tokyo

now = datetime.now(timezone.utc)
now = now.replace(tzinfo=ZoneInfo(tz))
print(now)
```

Output:

```
2025-04-29 01:33:56.325194+09:00
```

### Using `arrow`

```bash
pip install arrow tzfpy
```

```python
# https://github.com/ringsaturn/tzfpy/blob/main/examples/tzfpy_with_arrow.py
from zoneinfo import ZoneInfo

import arrow
from tzfpy import get_tz

tz = get_tz(139.7744, 35.6812)  # Tokyo

arrow_now = arrow.now(ZoneInfo(tz))
print(arrow_now)
```

Output:

```
2025-04-29T10:33:45.551282+09:00
```

### Using `whenever`

```bash
pip install tzfpy whenever
```

```python
# https://github.com/ringsaturn/tzfpy/blob/main/examples/tzfpy_with_whenever.py
from tzfpy import get_tz
from whenever import Instant

now = Instant.now()
tz = get_tz(139.7744, 35.6812)  # Tokyo
now = now.to_tz(tz)
print(now)
```

Output:

```
2025-04-29T10:33:28.427784+09:00[Asia/Tokyo]
```

## Batch processing with data frames

For bulk coordinate-to-timezone conversion, use vectorized operations rather than row-by-row loops.

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

# Trigger lazy init before the benchmark
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

Output:

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

Output:

```
Polars: 0.346s
```

### Pure NumPy

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

Output:

```
NumPy: 0.335s
```

## GeoJSON export

Both exporters return a serialized GeoJSON string. `get_tz_polygon_geojson`
returns the timezone's boundaries. `get_tz_index_geojson` returns the bounding
rectangles of the FUZZY preindex tiles that name it: the area where `get_tz`
answers from the preindex without falling back to point-in-polygon.

```python
from tzfpy import get_tz, get_tz_index_geojson, get_tz_polygon_geojson

lng, lat = -74.0060, 40.7128
tz = get_tz(lng, lat)

with open("tz_nyc_polygon.geojson", "w") as f:
    f.write(get_tz_polygon_geojson(tz))

with open("tz_nyc_index.geojson", "w") as f:
    f.write(get_tz_index_geojson(tz))
```

Both raise `ValueError` for an unknown timezone name, and
`get_tz_index_geojson` also raises it when no preindex tile names the timezone.

## Migrating from v1

The four query functions are unchanged.

| v1 | v2 |
| --- | --- |
| `get_tz`, `get_tzs`, `timezonenames`, `data_version` | unchanged |
| `_TZFPY_DISABLE_Y_STRIPES=1` | removed — the YStripes index is always on |
| GeoJSON helpers raising on internal `.unwrap()` | `get_tz_polygon_geojson` / `get_tz_index_geojson`, raising `ValueError` on a miss |
| — | new: `get_tz_index_geojson` for preindex coverage |

What changed underneath: dropping protobuf took the wheel from 4.31 MB to
2.76 MB and finder initialization from 68 ms to 15 ms, with query latency
unchanged (measured by the maintainer on the v2 switchover commit).
In the [tz-benchmark](https://github.com/ringsaturn/tz-benchmark) 2026-09-11
snapshot on an Apple M3 Max, tzfpy's resident set after load is 62.2 MiB against
an interpreter floor of 22.4 MiB, and the median random-city lookup is 708 ns.

The v1 line (tzfpy 1.3.x) remains available and is frozen at its last data
release, because tzf-dist stops publishing the protobuf artifacts once the v2 set
ships.

## Web API with FastAPI

```bash
pip install fastapi uvicorn tzfpy
```

```python
from fastapi import FastAPI, Query
from pydantic import BaseModel, Field
from tzfpy import data_version, get_tz, get_tzs, timezonenames

# Trigger lazy init at startup
_ = get_tz(0, 0)


class TimezoneResponse(BaseModel):
    timezone: str = Field(..., description="Timezone", examples=["Asia/Tokyo"])


class TimezonesResponse(BaseModel):
    timezones: list[str] = Field(
        ..., description="Timezones", examples=[["Asia/Shanghai", "Asia/Urumqi"]]
    )


class TimezonenamesResponse(BaseModel):
    timezonenames: list[str] = Field(
        ..., description="All timezone names", examples=[["Etc/GMT+1", "Etc/GMT+2"]]
    )


class DataVersionResponse(BaseModel):
    data_version: str = Field(..., description="Data version", examples=["2026c"])


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
