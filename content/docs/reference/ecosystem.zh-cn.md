---
date: '2025-07-19T11:25:25+09:00'
description: 五层架构展示时区边界数据如何从源头流向各个语言实现。
draft: false
lastmod: '2026-04-29T00:00:00+09:00'
seo:
  description: 五层 tzf 生态系统：从 evansiroky/timezone-boundary-builder GeoJSON 数据，经过处理与 tzf-dist 分发，到各语言实现和上层应用。
  noindex: false
  title: 生态系统——Project tzf
summary: GeoJSON 边界数据如何通过 tzf-dist 流入 Go、Rust、Python、Swift、Ruby、WASM 和服务层。
title: 生态系统
toc: true
weight: 2
---

```mermaid
%%{init: {"flowchart": {"htmlLabels": true}, "theme": "default"}}%%
graph TD
    %% L0 - 数据源
    subgraph L0["L0 - 数据源"]
        GeoJSON[evansiroky/timezone-boundary-builder<br/>GeoJSON 数据]
    end

    %% L1 - 核心处理
    subgraph L1["L1 - 核心处理"]
        TZF[ringsaturn/tzf<br/>Go 实现<br/>拓扑感知处理]
    end

    %% L2 - 数据分发
    subgraph L2["L2 - 数据分发"]
        TZF_DIST[ringsaturn/tzf-dist<br/>Go 模块 + Rust crate<br/>CompressedTopoTimezones 格式]
    end

    %% L3 - 语言实现
    subgraph L3["L3 - 语言实现"]
        TZF_RS[ringsaturn/tzf-rs<br/>Rust 实现]
        TZF_SWIFT[ringsaturn/tzf-swift<br/>Swift 实现]
    end

    %% L4 - 语言绑定与扩展
    subgraph L4["L4 - 绑定与扩展"]
        TZFPY[ringsaturn/tzfpy<br/>Python 绑定]
        TZF_RB[HarlemSquirrel/tzf-rb<br/>Ruby 绑定]
        TZF_WASM[ringsaturn/tzf-wasm<br/>浏览器 WASM]
        PG_TZF[ringsaturn/pg-tzf<br/>PostgreSQL 扩展]
    end

    %% L5 - 应用与服务
    subgraph L5["L5 - 应用与服务"]
        TZF_WEB[ringsaturn/tzf-web<br/>在线演示]
        RUST_TZ_SERVICE[racemap/rust-tz-service<br/>HTTP API]
    end

    %% 数据流
    GeoJSON --> TZF
    TZF --> TZF_DIST

    %% Go 直接使用 tzf-dist
    TZF_DIST --> |Go 模块| TZF
    TZF_DIST --> |Rust crate| TZF_RS
    TZF_DIST --> |内嵌| TZF_SWIFT

    %% Rust 生态
    TZF_RS --> TZFPY
    TZF_RS --> TZF_RB
    TZF_RS --> TZF_WASM
    TZF_RS --> PG_TZF
    TZF_RS --> RUST_TZ_SERVICE

    %% Web 应用
    TZF_WASM --> TZF_WEB

    %% 样式
    classDef l0 fill:#e3f2fd,stroke:#1976d2,stroke-width:2px
    classDef l1 fill:#e8f5e8,stroke:#388e3c,stroke-width:2px
    classDef l2 fill:#fff3e0,stroke:#f57c00,stroke-width:2px
    classDef l3 fill:#fce4ec,stroke:#c2185b,stroke-width:2px
    classDef l4 fill:#f3e5f5,stroke:#7b1fa2,stroke-width:2px
    classDef l5 fill:#e0f2f1,stroke:#00695c,stroke-width:2px

    class GeoJSON l0
    class TZF l1
    class TZF_DIST l2
    class TZF_RS,TZF_SWIFT l3
    class TZFPY,TZF_RB,TZF_WASM,PG_TZF l4
    class TZF_WEB,RUST_TZ_SERVICE l5
```

- **L0 - 数据源**：来自上游提供者的原始地理时区边界数据
  - [evansiroky/timezone-boundary-builder](https://github.com/evansiroky/timezone-boundary-builder)
- **L1 - 核心处理**：主要数据处理——拓扑感知多边形简化、
  共享边去重、Polyline 编码和瓦片预索引生成
  - [ringsaturn/tzf](https://github.com/ringsaturn/tzf)
- **L2 - 数据分发**：处理后的二进制数据，采用 `CompressedTopoTimezones` 格式，
  以 Go 模块和 Rust crate 形式分发
  - [ringsaturn/tzf-dist](https://github.com/ringsaturn/tzf-dist)
  - 文件：`combined-with-oceans.compress.topo.bin`（约 17 MB，完整精度）、
    `combined-with-oceans.topology.compress.topo.bin`（约 5.4 MB，精简版）、
    `combined-with-oceans.topology.preindex.bin`（约 2 MB，瓦片预索引）
- **L3 - 语言实现**：消费 tzf-dist 数据的核心时区查询实现
  - [ringsaturn/tzf-rs](https://github.com/ringsaturn/tzf-rs)
  - [ringsaturn/tzf-swift](https://github.com/ringsaturn/tzf-swift)
- **L4 - 语言绑定与扩展**：基于核心实现构建的封装库和数据库扩展
  - [ringsaturn/tzfpy](https://github.com/ringsaturn/tzfpy)
  - [HarlemSquirrel/tzf-rb](https://github.com/HarlemSquirrel/tzf-rb)
  - [ringsaturn/tzf-wasm](https://github.com/ringsaturn/tzf-wasm)
  - [ringsaturn/pg-tzf](https://github.com/ringsaturn/pg-tzf)
- **L5 - 应用与服务**：终端用户应用、Web 服务和 API 服务器
  - [ringsaturn/tzf-web](https://github.com/ringsaturn/tzf-web)
  - [racemap/rust-tz-service](https://github.com/racemap/rust-tz-service)
