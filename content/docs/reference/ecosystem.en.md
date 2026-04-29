---
date: '2025-07-19T11:25:25+09:00'
description: Five-layer architecture showing how timezone boundary data flows from source to every language implementation.
draft: false
lastmod: '2026-04-29T00:00:00+09:00'
seo:
  description: 'The five-layer tzf ecosystem: from evansiroky/timezone-boundary-builder GeoJSON through processing, distribution via tzf-dist, language implementations, and applications.'
  noindex: false
  title: Ecosystem — Project tzf
summary: How GeoJSON boundary data flows through tzf-dist into Go, Rust, Python, Swift, Ruby, WASM, and service layers.
title: Ecosystem
toc: true
weight: 2
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
        TZF[ringsaturn/tzf<br/>Go Implementation<br/>Topology-aware processing]
    end

    %% L2 - Data Distribution
    subgraph L2["L2 - Data Distribution"]
        TZF_DIST[ringsaturn/tzf-dist<br/>Go module + Rust crate<br/>CompressedTopoTimezones format]
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
        PG_TZF[ringsaturn/pg-tzf<br/>PostgreSQL Extension]
    end

    %% L5 - Applications & Services
    subgraph L5["L5 - Applications & Services"]
        TZF_WEB[ringsaturn/tzf-web<br/>Online Demo]
        RUST_TZ_SERVICE[racemap/rust-tz-service<br/>HTTP API]
    end

    %% Data Flow
    GeoJSON --> TZF
    TZF --> TZF_DIST

    %% Go uses tzf-dist directly
    TZF_DIST --> |Go module| TZF
    TZF_DIST --> |Rust crate| TZF_RS
    TZF_DIST --> |embedded| TZF_SWIFT

    %% Rust Ecosystem
    TZF_RS --> TZFPY
    TZF_RS --> TZF_RB
    TZF_RS --> TZF_WASM
    TZF_RS --> PG_TZF
    TZF_RS --> RUST_TZ_SERVICE

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
    class TZF_DIST l2
    class TZF_RS,TZF_SWIFT l3
    class TZFPY,TZF_RB,TZF_WASM,PG_TZF l4
    class TZF_WEB,RUST_TZ_SERVICE l5
```

- **L0 - Data Source**: Raw geographic timezone boundary data from upstream providers
  - [evansiroky/timezone-boundary-builder](https://github.com/evansiroky/timezone-boundary-builder)
- **L1 - Core Processing**: Primary data processing — topology-aware polygon simplification,
  shared-edge deduplication, Polyline encoding, and tile pre-index generation
  - [ringsaturn/tzf](https://github.com/ringsaturn/tzf)
- **L2 - Data Distribution**: Processed binary data in `CompressedTopoTimezones` format,
  distributed as a Go module and Rust crate
  - [ringsaturn/tzf-dist](https://github.com/ringsaturn/tzf-dist)
  - Files: `combined-with-oceans.compress.topo.bin` (~17 MB, full precision),
    `combined-with-oceans.topology.compress.topo.bin` (~5.4 MB, lite),
    `combined-with-oceans.topology.preindex.bin` (~2 MB, tile preindex)
- **L3 - Language Implementations**: Core timezone lookup implementations consuming tzf-dist data
  - [ringsaturn/tzf-rs](https://github.com/ringsaturn/tzf-rs)
  - [ringsaturn/tzf-swift](https://github.com/ringsaturn/tzf-swift)
- **L4 - Language Bindings & Extensions**: Wrapper libraries and database extensions built on top of core implementations
  - [ringsaturn/tzfpy](https://github.com/ringsaturn/tzfpy)
  - [HarlemSquirrel/tzf-rb](https://github.com/HarlemSquirrel/tzf-rb)
  - [ringsaturn/tzf-wasm](https://github.com/ringsaturn/tzf-wasm)
  - [ringsaturn/pg-tzf](https://github.com/ringsaturn/pg-tzf)
- **L5 - Applications & Services**: End-user applications, web services, and API servers
  - [ringsaturn/tzf-web](https://github.com/ringsaturn/tzf-web)
  - [racemap/rust-tz-service](https://github.com/racemap/rust-tz-service)
