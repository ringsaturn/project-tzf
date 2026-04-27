---
title: "Getting Started"
description: "Install and use Project tzf in your preferred programming language — Go, Rust, Python, Swift, Ruby, Wasm, and more."
summary: "Quick install and usage examples for all supported languages."
date: 2025-07-19T12:19:49+09:00
lastmod: 2025-07-19T12:19:49+09:00
draft: false
weight: 1
toc: true
seo:
  title: "Getting Started — Project tzf"
  description: "Install and run timezone lookup from GPS coordinates in Go, Rust, Python, Swift, Ruby, WebAssembly, or via HTTP API."
---

Project tzf provides multi-language support for looking up a timezone by longitude and latitude.

| Language or Server        | Repository                                                              | API Docs                                                                                                    |
| ------------------------- | ----------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| Go                        | [`ringsaturn/tzf`](https://github.com/ringsaturn/tzf)                   | [![](https://pkg.go.dev/badge/github.com/ringsaturn/tzf.svg)](https://pkg.go.dev/github.com/ringsaturn/tzf) |
| Rust                      | [`ringsaturn/tzf-rs`](https://github.com/ringsaturn/tzf-rs)             | [![](https://docs.rs/tzf-rs/badge.svg)](https://docs.rs/tzf-rs)                                             |
| Python                    | [`ringsaturn/tzfpy`](https://github.com/ringsaturn/tzfpy)               | [`tzfpy.pyi`](https://github.com/ringsaturn/tzfpy/blob/main/tzfpy.pyi)                                      |
| Swift                     | [`ringsaturn/tzf-swift`](https://github.com/ringsaturn/tzf-swift)       | [![][swift_doc_badge]][swift_doc_url]                                                                        |
| Ruby                      | [`HarlemSquirrel/tzf-rb`](https://github.com/HarlemSquirrel/tzf-rb)     |                                                                                                             |
| JS via Wasm (browser)     | [`ringsaturn/tzf-wasm`](https://github.com/ringsaturn/tzf-wasm)         |                                                                                                             |
| HTTP API                  | [`racemap/rust-tz-service`](https://github.com/racemap/rust-tz-service) |                                                                                                             |
| Redis Server              | [`ringsaturn/tzf-server`](https://github.com/ringsaturn/tzf-server)     |                                                                                                             |
| Online Demo               | [`ringsaturn/tzf-web`](https://github.com/ringsaturn/tzf-web)           |                                                                                                             |

[swift_doc_url]: https://swiftpackageindex.com/ringsaturn/tzf-swift
[swift_doc_badge]: https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fringsaturn%2Ftzf-swift%2Fbadge%3Ftype%3Dswift-versions

## Go

```bash
go get github.com/ringsaturn/tzf
```

```go
// Use about 150MB memory for init, and 60MB after GC.
package main

import (
	"fmt"

	"github.com/ringsaturn/tzf"
)

func main() {
	finder, err := tzf.NewDefaultFinder()
	if err != nil {
		panic(err)
	}
	fmt.Println(finder.GetTimezoneName(116.6386, 40.0786))
}
```

For 100% accurate results, use `NewFullFinder` (**reuse it when possible** — initialization is expensive):

```go
package main

import (
	"fmt"

	"github.com/ringsaturn/tzf"
)

func main() {
	finder, err := tzf.NewFullFinder()
	if err != nil {
		panic(err)
	}
	fmt.Println(finder.GetTimezoneName(139.6917, 35.6895))
}
```

## Rust

```bash
cargo add tzf-rs
```

```rust
use lazy_static::lazy_static;
use tzf_rs::DefaultFinder;

lazy_static! {
    static ref FINDER: DefaultFinder = DefaultFinder::new();
}

fn main() {
    // Coordinates are in (longitude, latitude) order.
    print!("{:?}\n", FINDER.get_tz_name(116.3883, 39.9289));
    print!("{:?}\n", FINDER.get_tz_names(116.3883, 39.9289));
}
```

<details>
<summary>Full-precision support</summary>

By default, tzf-rs uses simplified shape data. For 100% accurate lookup, download the
[full dataset](https://github.com/ringsaturn/tzf-rel/blob/main/combined-with-oceans.bin)
(~90 MB) and load it manually:

```rust
use tzf_rs::Finder;
use tzf_rs::gen::tzf::v1::Timezones;

pub fn load_full() -> Vec<u8> {
    include_bytes!("./combined-with-oceans.bin").to_vec()
}

fn main() {
    let file_bytes: Vec<u8> = load_full();
    let finder = Finder::from_pb(Timezones::try_from(file_bytes).unwrap_or_default());
    let tz_name = finder.get_tz_name(139.767125, 35.681236);
    println!("tz_name: {}", tz_name);
}
```

A full example is available [here](https://github.com/ringsaturn/tzf-rs/pull/170).

</details>

## Python

```bash
# Install just tzfpy
pip install tzfpy

# Install with pytz
pip install "tzfpy[pytz]"

# Install with tzdata
pip install "tzfpy[tzdata]"

# Install via conda
conda install -c conda-forge tzfpy
```

```python
>>> from tzfpy import get_tz, get_tzs
>>> get_tz(116.3883, 39.9289)   # (longitude, latitude) order
'Asia/Shanghai'
>>> get_tzs(87.4160, 44.0400)   # returns all matching timezones
['Asia/Shanghai', 'Asia/Urumqi']
```

Python does not support full-precision mode.

## Swift

Add the package to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/ringsaturn/tzf-swift.git", from: "{latest_version}")
]
```

```swift
import Foundation
import tzf

do {
    let finder = try DefaultFinder()

    let timezone = try finder.getTimezone(lng: 116.3833, lat: 39.9167)
    print("Beijing timezone:", timezone)

    let timezones = try finder.getTimezones(lng: 87.5703, lat: 43.8146)
    print("Multiple possible timezones:", timezones)

    print("Data version:", finder.dataVersion())
} catch {
    print("Error:", error)
}
```

## Ruby

Ruby support is created and maintained by
[HarlemSquirrel](https://github.com/HarlemSquirrel).
See [tzf-rb](https://github.com/HarlemSquirrel/tzf-rb) for detailed documentation.

```bash
bundle add tzf
# or
gem install tzf
```

```ruby
require 'tzf'

TZF.tz_name(40.74771675713742, -73.99350390136448)
# => "America/New_York"

TZF.tz_names(40.74771675713742, -73.99350390136448)
# => ["America/New_York"]
```

## WebAssembly

```html
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <title>tzf-wasm Example</title>
    <script type="module">
      import init, { WasmFinder } from "https://www.unpkg.com/tzf-wasm@v0.1.4/tzf_wasm.js";

      async function loadWasm() {
        await init();
        const finder = new WasmFinder();
        const timezone = finder.get_tz_name(-74.006, 40.7128);
        console.log("Timezone for New York:", timezone);
      }

      loadWasm();
    </script>
  </head>
  <body></body>
</html>
```

Online preview: <http://ringsaturn.github.io/tzf-web/>

## CLI

Both the Go and Rust implementations ship a command-line tool.

### Go CLI

```bash
go install github.com/ringsaturn/tzf/cmd/tzf@latest
```

```bash
tzf -lng 116.3883 -lat 39.9289

# Batch via stdin
echo -e "116.3883 39.9289\n116.3883, 39.9289" | tzf -stdin-order lng-lat
```

### Rust CLI

```bash
cargo install tzf-rs
```

```bash
tzf --lng 116.3883 --lat 39.9289

# Batch via stdin
echo -e "116.3883 39.9289\n116.3883, 39.9289" | tzf --stdin-order lng-lat
```

NixOS users can install `tzf-rs` via Nix —
see [NixOS packages](https://search.nixos.org/packages?channel=unstable&query=tzf-rs) for details.
