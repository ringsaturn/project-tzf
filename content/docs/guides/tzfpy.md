---
title: Best Practices for tzfpy
description: ""
summary: ""
date: 2025-07-21T12:06:56+09:00
lastmod: 2025-07-21T12:06:56+09:00
draft: false
weight: 1002
toc: true
seo:
  title: "" # custom title (optional)
  description: "" # custom description (recommended)
  canonical: "" # custom canonical URL (optional)
  noindex: false # false (default) or true
---

tzfpy's feature is very simple, only convert GPS coordinates to timezone name.
In fact, those name will be used with other datatime related functions and other use cases.

## Datatime convert

### Get local time via datetime

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

### Get local time via arrow

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

### Get local time via whenever

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

## Batch convert with dataframes

Consider a table that contains many cities and their GPS coordinates.
The fastest way to get their timezone name is to use dataframes' own map/apply functions.

### Pandas

Pandas does provide built-in apply feature, however, it's not very efficient.
With NumPy's help, we can get a much faster solution.

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

# lazy init
_ = tzfpy.get_tz(0, 0)


cities_as_dict = []
for city in citiespy.all_cities():
    cities_as_dict.append({"name": city.name, "lng": city.lng, "lat": city.lat})

df = pd.DataFrame(cities_as_dict)


start = time.perf_counter()
df["tz_from_tzfpy"] = df.apply(lambda x: tzfpy.get_tz(x.lng, x.lat), axis=1)
end = time.perf_counter()
print(f"[tzfpy_with_dataframe] Pandas apply Time taken: {end - start} seconds")

vec_tzfpy_get_tz = np.vectorize(tzfpy.get_tz)
start = time.perf_counter()
df["tz_from_tzfpy_vec"] = vec_tzfpy_get_tz(df.lng, df.lat)
end = time.perf_counter()
print(
    f"[tzfpy_with_dataframe] Pandas apply with NumPy vectorize Time taken: {end - start} seconds"
)
```

Output:

```
[tzfpy_with_dataframe] Pandas apply Time taken: 0.8276746249757707 seconds
[tzfpy_with_dataframe] Pandas apply with NumPy vectorize Time taken: 0.348435917054303 seconds
```

### Polars

```bash
pip install polars tzfpy
```

```python {hl_lines=["18-24"]}
import time

import citiespy
import polars as pl
import tzfpy

# lazy init
_ = tzfpy.get_tz(0, 0)


cities_as_dict = []
for city in citiespy.all_cities():
    cities_as_dict.append({"name": city.name, "lng": city.lng, "lat": city.lat})

df = pl.from_dicts(cities_as_dict)

start = time.perf_counter()
df = df.with_columns(
    pl.struct(["lng", "lat"])
    .map_elements(
        lambda cols: tzfpy.get_tz(cols["lng"], cols["lat"]), return_dtype=pl.Utf8
    )
    .alias("tz_from_tzfpy")
)
end = time.perf_counter()
print(f"[tzfpy_with_dataframe] Polars Time taken: {end - start} seconds")
```

Output:

```
[tzfpy_with_dataframe] Polars Time taken: 0.34632241702638566 seconds
```


### Pure NumPy

```bash
pip install numpy tzfpy
```

```python {hl_lines=["21", "24"]}
import time

import citiespy
import numpy as np
import pandas as pd
import tzfpy

# lazy init
_ = tzfpy.get_tz(0, 0)


cities_as_dict = []
for city in citiespy.all_cities():
    cities_as_dict.append({"name": city.name, "lng": city.lng, "lat": city.lat})

df = pd.DataFrame(cities_as_dict)

lngs = df.lng.values
lats = df.lat.values

vec_tzfpy_get_tz = np.vectorize(tzfpy.get_tz)

start = time.perf_counter()
_ = vec_tzfpy_get_tz(lngs, lats)
end = time.perf_counter()
print(f"[tzfpy_with_dataframe] Numpy Time taken: {end - start} seconds")
```

Output:

```
[tzfpy_with_dataframe] Numpy Time taken: 0.33512612502090633 seconds
```


## Web API

### FastAPI

```bash
pip install fastapi uvicorn tzfpy
```

```python
from fastapi import FastAPI, Query
from pydantic import BaseModel, Field
from tzfpy import data_version, get_tz, get_tzs, timezonenames

# lazy init
_ = get_tz(0, 0)


class TimezoneResponse(BaseModel):
    timezone: str = Field(..., description="Timezone", examples=["Asia/Tokyo"])


class TimezonesResponse(BaseModel):
    timezones: list[str] = Field(
        ..., description="Timezones", examples=[["Asia/Shanghai", "Asia/Urumqi"]]
    )


class TimezonenamesResponse(BaseModel):
    timezonenames: list[str] = Field(
        ..., description="Timezonenames", examples=[["Etc/GMT+1", "Etc/GMT+2"]]
    )


class DataVersionResponse(BaseModel):
    data_version: str = Field(..., description="Data version", examples=["2025b"])


app = FastAPI(
    title="tzfpy with FastAPI",
    description="tzfpy with FastAPI",
    contact={
        "name": "tzfpy",
        "url": "https://github.com/ringsaturn/tzfpy",
    },
)


@app.get("/")
def read_root():
    return {"message": "Hello, World!"}


@app.get("/timezone", response_model=TimezoneResponse)
def get_timezone(
    longitude: float = Query(
        ...,
        description="Longitude",
        ge=-180,
        le=180,
        examples=[139.767125],
        openapi_examples={"example-Tokyo": {"value": 139.767125}},
    ),
    latitude: float = Query(
        ...,
        description="Latitude",
        ge=-90,
        le=90,
        examples=[35.681236],
        openapi_examples={"example-Tokyo": {"value": 35.681236}},
    ),
):
    return TimezoneResponse(timezone=get_tz(longitude, latitude))


@app.get("/timezones", response_model=TimezonesResponse)
def get_timezones(
    longitude: float = Query(
        ...,
        description="Longitude",
        ge=-180,
        le=180,
        examples=[87.617733],
        openapi_examples={"example-Urumqi": {"value": 87.617733}},
    ),
    latitude: float = Query(
        ...,
        description="Latitude",
        ge=-90,
        le=90,
        examples=[43.792818],
        openapi_examples={"example-Urumqi": {"value": 43.792818}},
    ),
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
