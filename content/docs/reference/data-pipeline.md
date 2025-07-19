---
title: "Data Pipeline"
description: ""
summary: ""
date: 2025-07-19T11:25:25+09:00
lastmod: 2025-07-19T11:25:25+09:00
weight: 999
toc: true
seo:
  title: "" # custom title (optional)
  description: "" # custom description (recommended)
  canonical: "" # custom canonical URL (optional)
  noindex: false # false (default) or true
---


```mermaid
%%{init: {"flowchart": {"htmlLabels": true}, "theme": "default"}}%%
graph TD
    %% L0 - Data Source
    subgraph L0["L0 - Data Source"]
        GeoJSON[evansiroky/timezone-boundary-builder<br/>GeoJSON Data]
    end

    %% L1 - Core Processing
    subgraph L1["L1 - Core Processing"]
        TZF[ringsaturn/tzf<br/>Go Implementation]
    end

    %% L2 - Data Distribution
    subgraph L2["L2 - Data Distribution"]
        TZF_REL[ringsaturn/tzf-rel<br/>CI/CD & Data Processing]
        TZF_REL_LITE[ringsaturn/tzf-rel-lite<br/>Lite Version for Go]
        TZF_RUST_CRATE[tzf-rel Rust Crate<br/>Published Data]
    end

    %% L3 - Language Implementations
    subgraph L3["L3 - Language Implementations"]
        TZF_RS[ringsaturn/tzf-rs<br/>Rust Implementation]
        TZF_SWIFT[ringsaturn/tzf-swift<br/>Swift Implementation]
    end

    %% L4 - Language Bindings & Extensions
    subgraph L4["L4 - Bindings & Extensions"]
        TZFPY[ringsaturn/tzfpy<br/>Python Bindings]
        TZF_RB[HarlemSquirrel/tzf-rb<br/>Ruby Bindings]
        TZF_WASM[ringsaturn/tzf-wasm<br/>WASM for Browsers]
        PG_TZF[ringsaturn/pg_tzf<br/>PostgreSQL Extension]
    end

    %% L5 - Applications & Services
    subgraph L5["L5 - Applications & Services"]
        TZF_WEB[ringsaturn/tzf-web<br/>Online Demo]
        TZF_SERVER[ringsaturn/tzf-server<br/>HTTP API & Redis]
        RUST_TZ_SERVICE[racemap/rust-tz-service<br/>HTTP API]
        REDIZONE[ringsaturn/redizone<br/>Redis Server]
    end

    %% Data Flow
    GeoJSON --> TZF
    TZF --> TZF_REL
    TZF_REL --> |copy| TZF_REL_LITE
    TZF_REL --> |publish| TZF_RUST_CRATE
    TZF_REL --> |copy| TZF_SWIFT

    %% Go Usage
    TZF_REL_LITE --> TZF
    TZF --> TZF_SERVER

    %% Rust Ecosystem
    TZF_RUST_CRATE --> TZF_RS
    TZF_RS --> TZFPY
    TZF_RS --> TZF_RB
    TZF_RS --> TZF_WASM
    TZF_RS --> PG_TZF
    TZF_RS --> RUST_TZ_SERVICE
    TZF_RS --> REDIZONE

    %% Web Applications
    TZF_WASM --> TZF_WEB

    %% Styling
    classDef l0 fill:#e3f2fd,stroke:#1976d2,stroke-width:2px
    classDef l1 fill:#e8f5e8,stroke:#388e3c,stroke-width:2px
    classDef l2 fill:#fff3e0,stroke:#f57c00,stroke-width:2px
    classDef l3 fill:#fce4ec,stroke:#c2185b,stroke-width:2px
    classDef l4 fill:#f3e5f5,stroke:#7b1fa2,stroke-width:2px
    classDef l5 fill:#e0f2f1,stroke:#00695c,stroke-width:2px

    class GeoJSON l0
    class TZF l1
    class TZF_REL,TZF_REL_LITE,TZF_RUST_CRATE l2
    class TZF_RS,TZF_SWIFT l3
    class TZFPY,TZF_RB,TZF_WASM,PG_TZF l4
    class TZF_WEB,TZF_SERVER,RUST_TZ_SERVICE,REDIZONE l5
```

- **L0 - Data Source**: Raw geographic timezone boundary data from upstream providers
- **L1 - Core Processing**: Primary data processing and CI/CD infrastructure for the ecosystem
- **L2 - Data Distribution**: Processed and packaged data ready for consumption by different language ecosystems
- **L3 - Language Implementations**: Core timezone lookup implementations in different programming languages
- **L4 - Language Bindings & Extensions**: Wrapper libraries and database extensions built on top of core implementations
- **L5 - Applications & Services**: End-user applications, web services, and API servers
