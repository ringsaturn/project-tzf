---
date: '2025-07-21T12:06:56+09:00'
description: tzfpy 2.0 的最佳实践和集成模式：API 接口、日期时间转换、批处理、GeoJSON 导出及 Web API。
draft: false
lastmod: '2026-09-11T00:00:00+09:00'
seo:
  description: tzfpy 2.0 最佳实践：六个模块级函数、日期时间转换、使用 Pandas/Polars/NumPy 进行批处理、GeoJSON 导出以及 FastAPI 集成。
  noindex: false
  title: 'Python (tzfpy) 指南 - Project tzf'
summary: 在日期时间库、数据框（Pandas、Polars、NumPy）、GeoJSON 导出和 FastAPI 中使用 tzfpy 2.0。
title: Python (tzfpy)
toc: true
weight: 4
---

tzfpy 返回一个 IANA 时区名称字符串。本节介绍如何在常见的 Python 库中使用该名称。

## API 接口

tzfpy 2.0 是 tzf-rs 2.0 的 [PyO3](https://pyo3.rs/) 绑定，后者读取 `.tzb` 嵌入式二进制格式。公开接口是六个模块级函数，共用一个进程级全局查找器，没有需要构造的类：

```python
from tzfpy import (
    get_tz,                  # (lng, lat) -> str        第一个匹配项，预索引优先
    get_tzs,                 # (lng, lat) -> list[str]  全部匹配项，多边形精确
    timezonenames,           # () -> list[str]
    data_version,            # () -> str，例如 "2026c"
    get_tz_polygon_geojson,  # (name) -> str  以 GeoJSON 表示的边界多边形
    get_tz_index_geojson,    # (name) -> str  以 GeoJSON 表示的 FUZZY 预索引瓦片
)
```

```python
>>> get_tz(116.3883, 39.9289)   # (经度，纬度) 顺序
'Asia/Shanghai'
>>> get_tzs(87.4160, 44.0400)
['Asia/Shanghai', 'Asia/Urumqi']
```

查找器在首次使用时惰性构建。在应用启动阶段调用一次 `_ = get_tz(0, 0)`，可以把这部分开销移出首个请求。

需要 Python 3.10 或更高版本；wheel 为 3.10 起的 `abi3`。

### 查询函数的选择

`get_tz` 预索引优先：瓦片预索引可以在不做点在多边形内判定的情况下回答大部分查询。`get_tzs` 走多边形精确路径，不查询预索引，并返回全部匹配项。它适用于点可能属于多个时区的场景，以及调用方需要区分唯一匹配与被截断结果的场景。共享边界上的点属于所有与之相接的多边形。

### 适用范围

完整精度查询和原地低内存查找器只在 Go 和 Rust 中提供。tzfpy 通过单个默认查找器提供 lite 数据集。两者的说明参见[选择查找器]({{< relref "choosing-a-finder" >}})。

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

## GeoJSON 导出

两个导出函数都返回序列化后的 GeoJSON 字符串。`get_tz_polygon_geojson` 返回该时区的边界；`get_tz_index_geojson` 返回命名该时区的 FUZZY 预索引瓦片的包围矩形，即 `get_tz` 直接由预索引作答、无需回退到点在多边形内判定的区域。

```python
from tzfpy import get_tz, get_tz_index_geojson, get_tz_polygon_geojson

lng, lat = -74.0060, 40.7128
tz = get_tz(lng, lat)

with open("tz_nyc_polygon.geojson", "w") as f:
    f.write(get_tz_polygon_geojson(tz))

with open("tz_nyc_index.geojson", "w") as f:
    f.write(get_tz_index_geojson(tz))
```

传入未知时区名称时两者都抛出 `ValueError`；当没有预索引瓦片命名该时区时，`get_tz_index_geojson` 同样抛出 `ValueError`。

## 从 v1 迁移

四个查询函数没有变化。

| v1 | v2 |
| --- | --- |
| `get_tz`、`get_tzs`、`timezonenames`、`data_version` | 不变 |
| `_TZFPY_DISABLE_Y_STRIPES=1` | 已移除；YStripes 索引始终启用 |
| 内部 `.unwrap()` 抛错的 GeoJSON 辅助函数 | `get_tz_polygon_geojson` / `get_tz_index_geojson`，未命中时抛出 `ValueError` |
| — | 新增：`get_tz_index_geojson`，用于查看预索引覆盖范围 |

底层的变化：移除 protobuf 后，wheel 从 4.31 MB 降到 2.76 MB，查找器初始化从 68 ms 降到 15 ms，查询延迟不变（由维护者在 v2 切换提交上测得）。在 [tz-benchmark](https://github.com/ringsaturn/tz-benchmark) 的 2026-09-11 快照中（Apple M3 Max），tzfpy 加载后的常驻内存为 62.2 MiB，解释器基线为 22.4 MiB，随机城市查询的中位延迟为 708 ns。

v1 系列（tzfpy 1.3.x）仍然可用，并冻结在最后一个数据版本上，因为 v2 产物发布后 tzf-dist 不再发布 protobuf 产物。

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
    data_version: str = Field(..., description="数据版本", examples=["2026c"])


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
