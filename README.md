# hardcache

[![Package Version](https://img.shields.io/hexpm/v/hardcache)](https://hex.pm/packages/hardcache)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/hardcache/)

Hardcache is a Gleam module that provides primitives for caching key-value pairs in files and using files as caches.

## Examples

```gleam
import hardcache

import gleam/float
import gleam/option

pub fn main() {
  let cache = hardcache.new("./expensive", True)
  case hardcache.try_get(cache, "expensive_calculation") {
    Ok(option.None) -> {
      let _ =
        hardcache.try_set(cache, "expensive_calculation", float.to_string(0.1 +. 0.2))
    }
    _ -> Nil
  }
}
```

## Installation

If available on the Hex package manager, you can add **hardcache** to your project by running the command below:

```sh
gleam add hardcache
```

Further documentation can be found at <https://hexdocs.pm/hardcache>.

## Development

```sh
gleam test # Run the tests
```
