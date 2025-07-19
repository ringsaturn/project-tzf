---
title: "Quick Start"
description: "Guides lead a user through a specific task they want to accomplish, often with a sequence of steps."
summary: ""
date: 2025-07-19T12:19:49+09:00
lastmod: 2025-07-19T12:19:49+09:00
draft: false
weight: 810
toc: true
seo:
  title: "" # custom title (optional)
  description: "" # custom description (recommended)
  canonical: "" # custom canonical URL (optional)
  robots: "" # custom robot tags (optional)
---

Project tzf provides multiple languages supports to lookup timezone by longitude and latitude.

| Language or Sever         | Link                                                                    | Note                |
| ------------------------- | ----------------------------------------------------------------------- | ------------------- |
| Go                        | [`ringsaturn/tzf`](https://github.com/ringsaturn/tzf)                   |                     |
| Ruby                      | [`HarlemSquirrel/tzf-rb`](https://github.com/HarlemSquirrel/tzf-rb)     | build with tzf-rs   |
| Rust                      | [`ringsaturn/tzf-rs`](https://github.com/ringsaturn/tzf-rs)             |                     |
| Swift                     | [`ringsaturn/tzf-swift`](https://github.com/ringsaturn/tzf-swift)       |                     |
| Python                    | [`ringsaturn/tzfpy`](https://github.com/ringsaturn/tzfpy)               | build with tzf-rs   |
| HTTP API                  | [`racemap/rust-tz-service`](https://github.com/racemap/rust-tz-service) | build with tzf-rs   |
| Redis Server              | [`ringsaturn/tzf-server`](https://github.com/ringsaturn/tzf-server)     | build with tzf      |
| JS via Wasm(browser only) | [`ringsaturn/tzf-wasm`](https://github.com/ringsaturn/tzf-wasm)         | build with tzf-rs   |
| Online                    | [`ringsaturn/tzf-web`](https://github.com/ringsaturn/tzf-web)           | build with tzf-wasm |

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

<details>
<summary>Full precise support</summary>

```go
// Use about 900MB memory for init, and 660MB after GC.
package main

import (
	"fmt"

	"github.com/ringsaturn/tzf"
	tzfrel "github.com/ringsaturn/tzf-rel"
	pb "github.com/ringsaturn/tzf/gen/go/tzf/v1"
	"google.golang.org/protobuf/proto"
)

func main() {
	input := &pb.Timezones{}

	// Full data, about 83.5MB
	dataFile := tzfrel.FullData

	if err := proto.Unmarshal(dataFile, input); err != nil {
		panic(err)
	}
	finder, _ := tzf.NewFinderFromPB(input)
	fmt.Println(finder.GetTimezoneName(116.6386, 40.0786))
}
```

</details>

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
    // Please note coords are lng-lat.
    print!("{:?}\n", FINDER.get_tz_name(116.3883, 39.9289));
    print!("{:?}\n", FINDER.get_tz_names(116.3883, 39.9289));
}
```

<details>
<summary>Full precise support</summary>

By default, tzf-rs uses a simplified shape data. If you need 100% accurate
lookup, you can use the following code to setup.

1. Download
   [full data set](https://github.com/ringsaturn/tzf-rel/blob/main/combined-with-oceans.bin),
   about 90MB.
2. Use the following code to setup.

```rust
use tzf_rs::Finder;
use tzf_rs::gen::tzf::v1::Timezones;

pub fn load_full() -> Vec<u8> {
    include_bytes!("./combined-with-oceans.bin").to_vec()
}

fn main() {
    println!("Hello, world!");
    let file_bytes: Vec<u8> = load_full();

    let finder = Finder::from_pb(Timezones::try_from(file_bytes).unwrap_or_default());
    let tz_name = finder.get_tz_name(139.767125, 35.681236);
    println!("tz_name: {}", tz_name);
}
```

A full example can be found
[here](https://github.com/ringsaturn/tzf-rs/pull/170).

</details>

## Python

```bash
pip install tzfpy
```

```bash
>>> from tzfpy import get_tz, get_tzs
>>> get_tz(116.3883, 39.9289)  # in (longitude, latitude) order.
'Asia/Shanghai'
>>> get_tzs(87.4160, 44.0400)  # in (longitude, latitude) order.
['Asia/Shanghai', 'Asia/Urumqi']
```

Python version does not support full precise support.

## Wasm

```html
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>tzf-web Example</title>
    <script type="module">
      import init, { WasmFinder } from "https://www.unpkg.com/tzf-wasm@v0.1.4/tzf_wasm.js";

      let finder;

      async function loadWasm() {
        await init();
        finder = new WasmFinder();
        const lng = -74.006;
        const lat = 40.7128;
        const timezone = finder.get_tz_name(lng, lat);
        console.log(`Timezone for (${lat}, ${lng}): ${timezone}`);
      }

      loadWasm();
    </script>
  </head>
  <body></body>
</html>
```

Online preview: <http://ringsaturn.github.io/tzf-web/>

## Swift

Add the dependency to your `Package.swift` file:

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

    // Test for Beijing
    let timezone = try finder.getTimezone(lng: 116.3833, lat: 39.9167)
    print("Beijing timezone:", timezone)

    // Test for a location with multiple possible timezones
    let timezones = try finder.getTimezones(lng: 87.5703, lat: 43.8146)
    print("Multiple possible timezones:", timezones)

    // Get data version
    print("Data version:", finder.dataVersion())

} catch {
    print("Error:", error)
}
```
