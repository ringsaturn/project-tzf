---
date: '2025-07-19T11:25:25+09:00'
description: タイムゾーン境界データがソースから各言語実装に流れるまでの 5 層アーキテクチャ。
draft: false
lastmod: '2026-04-29T00:00:00+09:00'
seo:
  description: 5 層の tzf エコシステム：evansiroky/timezone-boundary-builder の GeoJSON から処理、tzf-dist 経由の配布、言語実装、アプリケーションまで。
  noindex: false
  title: エコシステム - Project tzf
summary: GeoJSON 境界データが tzf-dist を通じて Go、Rust、Python、Swift、Ruby、WASM、サービス層に流れる仕組み。
title: エコシステム
toc: true
weight: 2
---

```mermaid
%%{init: {"flowchart": {"htmlLabels": true}, "theme": "default"}}%%
graph TD
    %% L0 - データソース
    subgraph L0["L0 - データソース"]
        GeoJSON[evansiroky/timezone-boundary-builder<br/>GeoJSON データ]
    end

    %% L1 - コア処理
    subgraph L1["L1 - コア処理"]
        TZF[ringsaturn/tzf<br/>Go 実装<br/>トポロジー認識処理]
    end

    %% L2 - データ配布
    subgraph L2["L2 - データ配布"]
        TZF_DIST[ringsaturn/tzf-dist<br/>Go モジュール + Rust crate<br/>CompressedTopoTimezones 形式]
    end

    %% L3 - 言語実装
    subgraph L3["L3 - 言語実装"]
        TZF_RS[ringsaturn/tzf-rs<br/>Rust 実装]
        TZF_SWIFT[ringsaturn/tzf-swift<br/>Swift 実装]
    end

    %% L4 - 言語バインディングと拡張
    subgraph L4["L4 - バインディングと拡張"]
        TZFPY[ringsaturn/tzfpy<br/>Python バインディング]
        TZF_RB[HarlemSquirrel/tzf-rb<br/>Ruby バインディング]
        TZF_WASM[ringsaturn/tzf-wasm<br/>ブラウザ用 WASM]
        PG_TZF[ringsaturn/pg-tzf<br/>PostgreSQL 拡張]
    end

    %% L5 - アプリケーションとサービス
    subgraph L5["L5 - アプリケーションとサービス"]
        TZF_WEB[ringsaturn/tzf-web<br/>オンラインデモ]
        RUST_TZ_SERVICE[racemap/rust-tz-service<br/>HTTP API]
    end

    %% データフロー
    GeoJSON --> TZF
    TZF --> TZF_DIST

    %% Go は tzf-dist を直接使用
    TZF_DIST --> |Go モジュール| TZF
    TZF_DIST --> |Rust crate| TZF_RS
    TZF_DIST --> |埋め込み| TZF_SWIFT

    %% Rust エコシステム
    TZF_RS --> TZFPY
    TZF_RS --> TZF_RB
    TZF_RS --> TZF_WASM
    TZF_RS --> PG_TZF
    TZF_RS --> RUST_TZ_SERVICE

    %% Web アプリケーション
    TZF_WASM --> TZF_WEB

    %% スタイル
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

- **L0 - データソース**：上流プロバイダからの生の地理的タイムゾーン境界データ
  - [evansiroky/timezone-boundary-builder](https://github.com/evansiroky/timezone-boundary-builder)
- **L1 - コア処理**：主要データ処理として、トポロジー認識ポリゴン簡略化、
  共有エッジ重複排除、Polyline エンコーディング、タイルプレインデックス生成
  - [ringsaturn/tzf](https://github.com/ringsaturn/tzf)
- **L2 - データ配布**：処理済みバイナリデータを `CompressedTopoTimezones` 形式で
  Go モジュールおよび Rust crate として配布
  - [ringsaturn/tzf-dist](https://github.com/ringsaturn/tzf-dist)
  - ファイル：`combined-with-oceans.compress.topo.bin`（約 17 MB、完全精度）、
    `combined-with-oceans.topology.compress.topo.bin`（約 5.4 MB、ライト版）、
    `combined-with-oceans.topology.preindex.bin`（約 2 MB、タイルプレインデックス）
- **L3 - 言語実装**：tzf-dist データを消費するコアタイムゾーン検索実装
  - [ringsaturn/tzf-rs](https://github.com/ringsaturn/tzf-rs)
  - [ringsaturn/tzf-swift](https://github.com/ringsaturn/tzf-swift)
- **L4 - 言語バインディングと拡張**：コア実装上に構築されたラッパーライブラリとデータベース拡張
  - [ringsaturn/tzfpy](https://github.com/ringsaturn/tzfpy)
  - [HarlemSquirrel/tzf-rb](https://github.com/HarlemSquirrel/tzf-rb)
  - [ringsaturn/tzf-wasm](https://github.com/ringsaturn/tzf-wasm)
  - [ringsaturn/pg-tzf](https://github.com/ringsaturn/pg-tzf)
- **L5 - アプリケーションとサービス**：エンドユーザーアプリケーション、Web サービス、API サーバー
  - [ringsaturn/tzf-web](https://github.com/ringsaturn/tzf-web)
  - [racemap/rust-tz-service](https://github.com/racemap/rust-tz-service)
