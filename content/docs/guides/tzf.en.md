---
title: "Go (tzf)"
description: "Best practices and advanced usage patterns for the Go implementation of tzf."
summary: "Best practices for using tzf in Go — including global finder reuse and production patterns."
date: 2025-07-21T12:14:46+09:00
lastmod: 2025-07-21T12:14:46+09:00
draft: false
weight: 1
toc: true
seo:
  title: "Go (tzf) Guide — Project tzf"
  description: "Best practices for the Go tzf library — reusing Finder instances, global variables, and production patterns."
  noindex: false
---

## Reuse the Finder

Initializing a `Finder`, `FuzzyFinder`, or `DefaultFinder` is expensive — it loads and parses the timezone data file.
Always reuse a single instance, for example as a package-level variable:

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
