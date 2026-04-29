---
date: '2025-07-21T12:14:46+09:00'
description: Go 版 tzf 的最佳实践和高级用法模式。
draft: false
lastmod: '2025-07-21T12:14:46+09:00'
seo:
  description: Go tzf 库的最佳实践——重用 Finder 实例、全局变量及生产环境模式。
  noindex: false
  title: Go (tzf) 指南——Project tzf
summary: tzf 在 Go 中的最佳实践——包括全局 Finder 复用及生产环境模式。
title: Go (tzf)
toc: true
weight: 1
---

## 复用 Finder

初始化 `Finder`、`FuzzyFinder` 或 `DefaultFinder` 开销较大——需要加载和解析时区数据文件。
请始终复用单个实例，例如作为包级变量：

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
