# hardcache

[![Package Version](https://img.shields.io/hexpm/v/hardcache)](https://hex.pm/packages/hardcache)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/hardcache/)

Hardcache is a Gleam module that provides primitives for caching key-value pairs in files and using files as caches.

```sh
gleam add hardcache
```

```gleam
import hardcache

import gleam/float

pub fn main() {
  let calculation = 0.1 + 0.2
  let cache =
    hardcache.new("calc", True)
    |> hardcache.try_set(float.to_string(calculation))
}
```

Further documentation can be found at <https://hexdocs.pm/hardcache>.

## Development

```sh
gleam test # Run the tests
```
