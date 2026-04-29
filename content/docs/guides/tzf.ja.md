---
date: '2025-07-21T12:14:46+09:00'
description: Go 版 tzf のベストプラクティスと高度な使用パターン。
draft: false
lastmod: '2025-07-21T12:14:46+09:00'
seo:
  description: Go tzf ライブラリのベストプラクティス——Finder インスタンスの再利用、グローバル変数、本番環境パターン。
  noindex: false
  title: Go (tzf) ガイド——Project tzf
summary: Go で tzf を使用する際のベストプラクティス——グローバル Finder の再利用と本番環境パターンを含む。
title: Go (tzf)
toc: true
weight: 1
---

## Finder の再利用

`Finder`、`FuzzyFinder`、`DefaultFinder` の初期化は高コストです——タイムゾーンデータファイルを読み込んで解析します。
常に単一のインスタンスを再利用してください。例えばパッケージレベルの変数として：

```go {hl_lines=["9"]}
package main

import (
	"fmt"

	"github.com/ringsaturn/tzf"
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
	fmt.Println(f.GetTimezoneName(116.3883, 39.9289))
	fmt.Println(f.GetTimezoneName(-73.935242, 40.730610))
}
```
