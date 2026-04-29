---
date: '2025-07-21T12:06:56+09:00'
description: Best practices and integration patterns for tzfpy — datetime conversion, batch processing, and web APIs.
draft: false
lastmod: '2025-07-21T12:06:56+09:00'
seo:
  description: tzfpy best practices — datetime conversion, batch processing with Pandas/Polars/NumPy, and FastAPI integration.
  noindex: false
  title: Python (tzfpy) Guide — Project tzf
summary: Using tzfpy with datetime libraries, data frames (Pandas, Polars, NumPy), and FastAPI.
title: Python (tzfpy)
toc: true
weight: 3
---

tzfpy returns an IANA timezone name string. This section shows how to use that name with common Python libraries.

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
    data_version: str = Field(..., description="Data version", examples=["2025b"])


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
