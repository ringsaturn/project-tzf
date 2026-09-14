---
date: '2025-07-21T12:14:46+09:00'
description: Go 版 tzf (v2) のベストプラクティスと高度な使用パターン。
draft: false
lastmod: '2026-09-14T00:00:00+09:00'
seo:
  description: Go tzf v2 ライブラリのベストプラクティス。5 つのコンストラクタ、Finder の再利用、GeoJSON エクスポート、インプレースクエリ、v1 からの移行を扱います。
  noindex: false
  title: 'Go (tzf) ガイド - Project tzf'
summary: tzf v2 を Go で使用する際のコンストラクタの選択、Finder の再利用、GeoJSON エクスポート、インプレースのバイト列、v1 から v2 への移行表。
title: Go (tzf)
toc: true
weight: 2
---

## インストール

tzf v2 は新しいメジャーバージョンであるため、モジュールパスに `/v2` サフィックスが付きます。

```bash
go get github.com/ringsaturn/tzf/v2
```

```go
import "github.com/ringsaturn/tzf/v2"
```

パッケージ名は引き続き `tzf` です。v2 は protobuf を使用しません。境界データは [`ringsaturn/tzf-dist`](https://github.com/ringsaturn/tzf-dist) から `.tzb`（コンパクトな転送用プロファイル）と `.tzm`（メモリイメージプロファイル）のファイルとして配布され、`go:embed` で埋め込まれます。ファイル形式そのものについては[埋め込みバイナリ形式]({{< relref "../reference/embedded-binary-format" >}})を参照してください。

## 5 つのコンストラクタ

すべてのコンストラクタが [`F`](#f-インターフェイス) インターフェイスを返します。このパッケージは Finder 型もオプションもエクスポートしません。

| コンストラクタ | データ | 常駐 | クエリ |
| --- | --- | --- | --- |
| `NewDefaultFinder()` | lite `.tzm` メモリイメージ、ポリゴンをインプレースで参照 | ヒープ約 12 MB + 読み取り専用データ約 10 MB | 298 ns |
| `NewEmbeddedFinder()` | lite `.tzb` をインプレースで参照 | 約 4 MB（ファイルバイト列 + 約 30 KB のヒープ） | プレインデックスヒット時 p50 333 ns、ミス時約 1.2 µs |
| `NewFullFinder()` | full `.tzb`、ロード時に展開 | 約 145 MB | 約 300 ns |
| `NewFinderFromTZB(data)` | 呼び出し側の `.tzb` バイト列、常に展開 | ファイルに依存（lite: 約 27 MB） | 約 290 ns |
| `NewFinderFromTZM(data)` | 呼び出し側の `.tzm` バイト列、常にインプレースで参照 | 同一ファイルであれば `NewDefaultFinder` と同等 | 約 300 ns |

Apple M3 Max で `2026c` データセットを対象に測定した値です。`NewEmbeddedFinder` の行は tzf-dist `v0.0.2026-c-tzb2` 上の tzf v2.1.1 の値です。インプレースのクエリ走査の書き直しと 64 点チャンクにより、プレインデックスミス時の p50 は v2.0.0 の約 6 µs から 1.2 µs になり、Finder はオープン時に構築するチャンクのブロックテーブルとプレインデックスのズーム範囲を保持するようになりました。

パッケージのドキュメントでは `NewDefaultFinder()` を汎用の Finder として位置づけています。ファイルシステムのない環境、cgroup クォータ下の Pod、配布サイズなどのその他のケースについては [Finder の選択]({{< relref "choosing-a-finder" >}})を参照してください。

## Finder の再利用

構築のコストはクエリと比べて大きくなります。ファイルを開き、クエリ構造を構築し、展開方式の Finder ではすべてのポリゴンをデコードします。Finder は並行利用が安全なため、プロセスは 1 つを構築して再利用します。パッケージレベルの変数はその方法の 1 つです。

```go {hl_lines=["9"]}
package main

import (
	"fmt"

	"github.com/ringsaturn/tzf/v2"
)

var f tzf.F

func init() {
	var err error
	f, err = tzf.NewDefaultFinder()
	if err != nil {
		panic(err)
	}
}

func main() {
	// 座標は (経度，緯度) の順です。
	fmt.Println(f.GetTimezoneName(116.3883, 39.9289))
	fmt.Println(f.GetTimezoneName(-73.935242, 40.730610))
}
```

## `F` インターフェイス

```go
type F interface {
	GetTimezoneName(lng float64, lat float64) string
	GetTimezoneNames(lng float64, lat float64) ([]string, error)
	TimezoneNames() []string
	DataVersion() string
}
```

- **`GetTimezoneName`：** ファジー優先です。tzf-dist のすべての成果物が FUZZY プレインデックスセクションを含むため、タイル検索が大部分のクエリを point-in-polygon なしで解決します。境界付近では Finder がレイキャスティングにフォールバックします。一致がない場合は空文字列を返します。
- **`GetTimezoneNames`：** すべての Finder でポリゴンによる厳密な判定を行います。プレインデックスは参照せず、地点が複数のタイムゾーンに属する可能性がある場合に該当します。結果は辞書順にソートされ、一致がない場合は `tzf.ErrNoTimezoneFound` を返します。
- 共有境界上の地点は、接するすべてのポリゴンに属します。海上タイムゾーンの境界は 7.5°、22.5° のような整数分割の経線上にあります。

```go
names, err := f.GetTimezoneNames(87.4160, 44.0400)
// names == []string{"Asia/Shanghai", "Asia/Urumqi"}
```

## GeoJSON エクスポート

`GeoJSONer` は `F` に含めていません。テストダブルやサードパーティの `F` 実装がジオメトリを生成する必要をなくすためです。このパッケージが構築するすべての Finder が `GeoJSONer` を満たすため、コンストラクタが返した値に対してインターフェイスをアサートします。

```go
finder, err := tzf.NewDefaultFinder()
if err != nil {
	panic(err)
}

g := finder.(tzf.GeoJSONer)

world := g.GetGeoJSON()                          // []byte、全タイムゾーン
tokyo, err := g.GetTZGeoJSON("Asia/Tokyo")       // []byte、単一タイムゾーン
tiles, err := g.GetTZPreindexGeoJSON("Asia/Tokyo") // 単一タイムゾーンの FUZZY タイル
all, err := g.GetPreindexGeoJSON()               // FUZZY プレインデックス全体
```

4 つのメソッドはいずれもシリアライズ済みの GeoJSON バイト列を返します。境界ファイルの型はモジュール内部のものです。プレインデックスのエクスポートは、`GetTimezoneName` が point-in-polygon にフォールバックせずプレインデックスから応答する領域を対象とします。FUZZY セクションを持たないファイルでは `tzf.ErrNoFuzzySection` を返します。

## 独自のバイト列を使用する

ディスク、オブジェクトストレージ、あるいは独自の `go:embed` からファイルを読み込み、プロファイルに対応するコンストラクタを選択します。

```go
data, err := os.ReadFile("lite.tzb")
if err != nil {
	panic(err)
}
finder, err := tzf.NewFinderFromTZB(data) // 展開する。data は解放してよい
```

```go
data, err := os.ReadFile("lite.tzm")
if err != nil {
	panic(err)
}
finder, err := tzf.NewFinderFromTZM(data) // インプレースで参照する。data は保持し続ける
```

`.tzm` の Finder のリングスライスはソースのバイト列を参照するため、そのバイト列は Finder の生存期間中、有効かつ変更されない状態を保つ必要があります。

M プロファイルは、それを使用するホスト上で `.tzb` ファイルから生成します。

```bash
# usage: tzb2tzm [-o output] input.tzb
go run github.com/ringsaturn/tzf/v2/cmd/tzb2tzm@latest lite.tzb
```

## 呼び出し側が保持するバイト列へのインプレースクエリ

`x.NewFinderFromTZBReaderAt` は `io.ReaderAt` 経由で `.tzb` にクエリします。対象はファイル、`mmap` した領域、組み込みフラッシュのアダプタ、あるいは既に保持しているバイト列に対する `bytes.Reader` です。クエリはアロケーションを行わず、ヒープコストは約 30 KB に収まります。

```go
import (
	"bytes"

	"github.com/ringsaturn/tzf/v2/x"
)

finder, err := x.NewFinderFromTZBReaderAt(bytes.NewReader(data), int64(len(data)))
if err != nil {
	panic(err)
}
fmt.Println(finder.GetTimezoneName(151.2093, -33.8688))
```

`x` パッケージはモジュールのセマンティックバージョニングの約束の対象外です。マイナーバージョンの更新で API が変更または削除される場合があります。ルートパッケージが非互換に変更されるのはメジャーバージョンの更新時のみです。

## v1 からの移行

v1（`github.com/ringsaturn/tzf`、最新は v1.2.x）は引き続き利用できます。ただし最後の protobuf データリリースで凍結されます。v2 のセットが公開された時点で tzf-dist は `.bin` の成果物の配布を終了します。

| v1 | v2 |
| --- | --- |
| `go get github.com/ringsaturn/tzf` | `go get github.com/ringsaturn/tzf/v2` |
| `tzf.NewDefaultFinder()` | `tzf.NewDefaultFinder()` — lite `.tzm` メモリイメージを使用 |
| `tzf.NewFullFinder()` | `tzf.NewFullFinder()` — full `.tzb` を展開して使用 |
| `tzf.NewFuzzyFinderFromPB(...)` | 削除。FUZZY 高速パスは該当セクションを持つすべての Finder に組み込まれています |
| `tzf.NewFinderFromCompressedTopo(...)`、`NewFinderFromCompressed(...)`、`NewFinderFromPB(...)` | `tzf.NewFinderFromTZB(data)` または `tzf.NewFinderFromTZM(data)` — protobuf メッセージではなく `[]byte` |
| `tzf.NewFinderFromRawJSON(...)` | 削除。パイプラインの CLI で `.tzb` を生成します |
| `tzf.Finder`、`tzf.FuzzyFinder`、`tzf.DefaultFinder`（エクスポートされた構造体） | 削除。すべてのコンストラクタが `tzf.F` を返します |
| `tzf.Option` / `tzf.OptionFunc` / `tzf.SetDropPBTZ` | 削除。v2 にオプションはありません |
| `*convert.BoundaryFile` を返す `finder.GetGeoJSON()` | `[]byte` を返す `finder.(tzf.GeoJSONer).GetGeoJSON()` |
| `github.com/ringsaturn/tzf/gen/go/tzf/v1`（protobuf 型） | 削除。v2 に protobuf は含まれません |
| `reduce`、`preindex`、`convert.Do`（エクスポートされたパイプラインパッケージ） | internal 化。パイプラインは `cmd/` の CLI から実行します |
| tzf-dist の `.bin` ファイル | `lite.tzb`、`lite.tzm`、`full.tzb` |

`F` の 4 つのメソッドは変更されていません。`GetTimezoneName` / `GetTimezoneNames` / `TimezoneNames` / `DataVersion` のみを呼び出しているコードは、インポートパスの変更以外に対応は不要です。

### 境界の扱い

v2 は境界上のクエリを [tzf#216](https://github.com/ringsaturn/tzf/issues/216) 以降の v1 と同じ方法で処理します。共有境界上の地点は接するすべてのポリゴンに属し、外周リングは境界上を内包として扱い、穴のリングは扱いません。それ以前の v1 パッチリリースに固定しているコードでは、これまで結果を返さなかった境界上の地点が名前を返すようになります。
