---
date: '2025-07-21T12:06:56+09:00'
description: tzfpy 最佳实践和集成模式——日期时间转换、批处理及 Web API。
draft: false
lastmod: '2025-07-21T12:06:56+09:00'
seo:
  description: tzfpy 最佳实践——日期时间转换、使用 Pandas/Polars/NumPy 进行批处理以及 FastAPI 集成。
  noindex: false
  title: Python (tzfpy) 指南——Project tzf
summary: 在日期时间库、数据框（Pandas、Polars、NumPy）和 FastAPI 中使用 tzfpy。
title: Python (tzfpy)
toc: true
weight: 3
---

tzfpy 返回一个 IANA 时区名称字符串。本节介绍如何在常见的 Python 库中使用该名称。

## 日期时间转换

### 使用 `zoneinfo`（标准库）

```bash
pip install tzfpy
```

```python
# https://github.com/ringsaturn/tzfpy/blob/main/examples/tzfpy_with_datetime.py
from datetime import datetime, timezone
from zoneinfo import ZoneInfo

from tzfpy import get_tz

tz = get_tz(139.7744, 35.6812)  # 东京

now = datetime.now(timezone.utc)
now = now.replace(tzinfo=ZoneInfo(tz))
print(now)
```

输出：

```
2025-04-29 01:33:56.325194+09:00
```

### 使用 `arrow`

```bash
pip install arrow tzfpy
```

```python
# https://github.com/ringsaturn/tzfpy/blob/main/examples/tzfpy_with_arrow.py
from zoneinfo import ZoneInfo

import arrow
from tzfpy import get_tz

tz = get_tz(139.7744, 35.6812)  # 东京

arrow_now = arrow.now(ZoneInfo(tz))
print(arrow_now)
```

输出：

```
2025-04-29T10:33:45.551282+09:00
```

### 使用 `whenever`

```bash
pip install tzfpy whenever
```

```python
# https://github.com/ringsaturn/tzfpy/blob/main/examples/tzfpy_with_whenever.py
from tzfpy import get_tz
from whenever import Instant

now = Instant.now()
tz = get_tz(139.7744, 35.6812)  # 东京
now = now.to_tz(tz)
print(now)
```

输出：

```
2025-04-29T10:33:28.427784+09:00[Asia/Tokyo]
```

## 使用数据框进行批处理

对于批量坐标转时区转换，请使用向量化操作而不是逐行循环。

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

# 在基准测试之前触发延迟初始化
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

输出：

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

输出：

```
Polars: 0.346s
```

### 纯 NumPy

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

输出：

```
NumPy: 0.335s
```

## 使用 FastAPI 构建 Web API

```bash
pip install fastapi uvicorn tzfpy
```

```python
from fastapi import FastAPI, Query
from pydantic import BaseModel, Field
from tzfpy import data_version, get_tz, get_tzs, timezonenames

# 在启动时触发延迟初始化
_ = get_tz(0, 0)


class TimezoneResponse(BaseModel):
    timezone: str = Field(..., description="时区", examples=["Asia/Tokyo"])


class TimezonesResponse(BaseModel):
    timezones: list[str] = Field(
        ..., description="时区列表", examples=[["Asia/Shanghai", "Asia/Urumqi"]]
    )


class TimezonenamesResponse(BaseModel):
    timezonenames: list[str] = Field(
        ..., description="所有时区名称", examples=[["Etc/GMT+1", "Etc/GMT+2"]]
    )


class DataVersionResponse(BaseModel):
    data_version: str = Field(..., description="数据版本", examples=["2025b"])


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
