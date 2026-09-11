---
date: '2025-07-21T14:19:40+09:00'
description: Rust 版 tzf（v2）的最佳实践和高级用法模式。
draft: false
lastmod: '2026-09-11T00:00:00+09:00'
seo:
  description: Rust tzf-rs v2 crate 的最佳实践：DefaultFinder 与 EmbeddedFinder、cargo feature、GeoJSON 导出，以及从 v1 迁移。
  noindex: false
  title: 'Rust (tzf-rs) 指南 - Project tzf'
summary: tzf-rs 2.0 的两个查找器、cargo feature、GeoJSON 导出、集成模式，以及 v1 到 v2 的迁移对照表。
title: Rust (tzf-rs)
toc: true
weight: 3
---

## 安装

```bash
cargo add tzf-rs
```

tzf-rs 2.0 不再使用 protobuf。它读取由 [`ringsaturn/tzf-dist`](https://github.com/ringsaturn/tzf-dist) 发布的 TZF 嵌入式二进制格式（`.tzb`）；默认的 `bundled` feature 把 lite 文件（~4 MB）携带在 crate 内。格式本身参见[嵌入式二进制格式]({{< relref "../reference/embedded-binary-format" >}})。

## 两个查找器

| 类型 | 数据 | 峰值 RSS | 查询（随机城市 / 边界城市） |
| --- | --- | ---: | ---: |
| `DefaultFinder` | lite `.tzb` 展开为多边形，带 FUZZY 快速路径 | ~47 MiB | 229 ns / 519 ns |
| `EmbeddedFinder` | lite `.tzb` 原地查询 | ~10 MiB | 1.18 µs / 4.78 µs |

数据来自 [tz-benchmark](https://github.com/ringsaturn/tz-benchmark) 的 2026-09-11 快照，在 Apple M3 Max 上针对 `2026c` 数据集测得；该测试环境中 Rust 运行时的基线为 5.8 MiB。

`DefaultFinder::new()` 约需 13 ms 打开，`EmbeddedFinder::new()` 约需 2 ms。计数型分配器对 `EmbeddedFinder` 未记录到堆保留量：其数据是 `&'static` 的嵌入切片，另加约 1 KB 的状态。`EmbeddedFinder` 适用于可以接受微秒级查询的内存受限目标。其余场景参见[选择查找器]({{< relref "choosing-a-finder" >}})。

## 复用查找器

构造过程会加载并校验整个文件，因此进程构建一个查找器并复用。用 `LazyLock` 静态变量持有它，不需要额外依赖：

```rust {hl_lines=["4"]}
use std::sync::LazyLock;
use tzf_rs::DefaultFinder;

static FINDER: LazyLock<DefaultFinder> = LazyLock::new(DefaultFinder::new);

fn main() {
    // 坐标采用 (经度，纬度) 顺序。
    println!("{:?}", FINDER.get_tz_name(116.3883, 39.9289));
    println!("{:?}", FINDER.get_tz_names(116.3883, 39.9289));
}
```

`lazy_static` 同样可用。`LazyLock` 自 Rust 1.80 起进入标准库。

## 查询

两个查找器提供相同的四个方法：

```rust
finder.get_tz_name(lng, lat)   // -> &str，无匹配时为空
finder.get_tz_names(lng, lat)  // -> Vec<&str>，按字典序排序
finder.timezonenames()         // -> Vec<&str>
finder.data_version()          // -> &str，例如 "2026c"
```

- `get_tz_name` 预索引优先：FUZZY 瓦片预索引可以在不做点在多边形内判定的情况下回答大部分查询。
- `get_tz_names` 在两个查找器中都走多边形精确路径，不查询预索引。它适用于点可能属于多个时区的场景；共享边界上的点属于所有与之相接的多边形。

## 使用自行提供的字节

```rust
use tzf_rs::{DefaultFinder, EmbeddedFinder};

let data = std::fs::read("lite.tzb")?;
let finder = DefaultFinder::from_tzb(&data)?;   // 加载期间借用，随后展开
```

```rust
static DATA: &[u8] = include_bytes!("../data/lite.tzb");
let finder = EmbeddedFinder::from_tzb(DATA)?;   // 不复制；查询时原地读取
```

`EmbeddedFinder::from_tzb` 接受 `impl Into<Cow<'static, [u8]>>`，因此来自 `include_bytes!` 的 `&'static [u8]` 无需复制即可接管，持有所有权的 `Vec<u8>` 同样可以传入。两个构造函数都返回 `Result<_, tzf_rs::Error>`：文件在打开时会做 CRC 校验和结构校验，数据损坏时返回错误，而不产生空的查找器。

`Error` 带有 `#[non_exhaustive]`，包含 `Malformed`、`Profile`、`NoFuzzy` 和 `Index` 四个变体。传入 `.tzm` 内存镜像字节时返回 `Profile`：tzf-rs 只读取 `.tzb` profile，M profile 由 Go 实现读取。

## Cargo feature

| Feature | 默认 | 作用 |
| --- | --- | --- |
| `bundled` | 是 | 嵌入 tzf-dist 的 lite `.tzb`（~4 MB），启用 `new()` |
| `clap` | 是 | 构建 `tzf` 命令行程序 |
| `full` | 否 | 仅 git 提供的完整精度 `.tzb`（~14 MB），启用 `new_full()` |
| `export-geojson` | 否 | GeoJSON 导出方法 |

`full` 与 `bundled` 互斥；同时启用时 crate 会触发 `compile_error!`。完整数据集超出 crates.io 的体积限制，因此从 git 引用：

```toml
[dependencies]
tzf-rs = { git = "https://github.com/ringsaturn/tzf-rs", rev = "v{X}.{Y}.{Z}", features = ["full"], default-features = false }
```

```rust
use tzf_rs::DefaultFinder;

let finder = DefaultFinder::new_full();
println!("{}", finder.get_tz_name(139.767125, 35.681236));
```

在库构建中去掉命令行程序：`cargo build --no-default-features --features bundled`。

## GeoJSON 导出

启用 `export-geojson` 后，两个查找器都提供四个导出方法：

```rust
let world = finder.to_geojson();                            // BoundaryFile
let tokyo = finder.get_tz_geojson("Asia/Tokyo");            // Option<BoundaryFile>
let tiles = finder.get_tz_preindex_geojson("Asia/Tokyo");   // Option<BoundaryFile>
let all_tiles = finder.to_preindex_geojson();               // Option<BoundaryFile>
```

预索引导出方法返回命名某个时区的 FUZZY 瓦片的包围矩形，即 `get_tz_name` 直接由预索引作答、无需回退到点在多边形内判定的区域。文件不含 FUZZY 区段时返回 `None`。

## 从 v1 迁移

| v1 | v2 |
| --- | --- |
| `DefaultFinder::new()` | `DefaultFinder::new()`，调用处不变 |
| `DefaultFinder::new_full()` | `DefaultFinder::new_full()`，调用处不变 |
| `Finder`（仅多边形） | `DefaultFinder`；`get_tz_names` 仍为多边形精确路径 |
| `FuzzyFinder`（仅瓦片） | 已移除；预索引是每个查找器内部的快速路径 |
| `Finder::from_compressed_topo(pb)` | `DefaultFinder::from_tzb(bytes)` |
| `FuzzyFinder::from_pb(pb)` | 已移除，无替代 |
| `FinderOptions` / `new_with_options` | 已移除；YStripes 始终启用 |
| `finder.finder.get_tz_geojson(...)` | `finder.get_tz_geojson(...)` |
| `FuzzyFinder` 的瓦片包围盒 GeoJSON | 由 `get_tz_preindex_geojson` / `to_preindex_geojson` 取代 |
| — | 新增：`EmbeddedFinder`，原地查询且内存占用低 |

行为变化：

- `get_tz_names` 的结果现按字典序排序。
- `DefaultFinder` 的 `get_tz_name` 由覆盖该点的预索引瓦片作答，与 v1 `DefaultFinder` 的语义一致。此前用 v1 `Finder` 获取多边形精确多结果的代码改调用 `get_tz_names`。
- 字节构造函数返回 `Result`，不再回退为空查找器。
- GeoJSON 导出不再包含 protobuf 展开时保留的重复连接顶点（长度为零的线段）。查询结果不受影响。
- 随 protobuf 一并移除的还有：`Finder::from_pb`、`Finder::from_compressed_topo`、`FuzzyFinder::from_pb`、`pbgen` 模块、`prost` 依赖和 `revert_timezones`。

v1 系列（tzf-rs 1.3.x）仍然可用，并冻结在最后一个数据版本上：v2 产物发布后，tzf-dist 不再发布 protobuf 产物，因此获取更新后的边界数据需要迁移到 v2。

## 集成示例

- HTTP 服务：[`racemap/rust-tz-service`](https://github.com/racemap/rust-tz-service) 在 Axum Web 服务器中封装 tzf-rs。
- Redis 协议：[`ringsaturn/redizone`](https://github.com/ringsaturn/redizone) 是基于 tzf-rs 构建的 Redis 兼容服务器。
- PostgreSQL：[`ringsaturn/pg-tzf`](https://github.com/ringsaturn/pg-tzf) 把 tzf-rs 作为数据库扩展提供。
