import gleeunit
import gleeunit/should

import hardcache

pub fn main() {
  gleeunit.main()
}

pub fn cache_test() {
  hardcache.new("./test/test_file.txt", True)
  |> hardcache.try_set("a", "A")
  |> hardcache.try_defaults([#("default", "1"), #("a", "abc")])
  |> hardcache.try_set_many([])
  |> hardcache.try_set_many([
    #("msg", "Hello!"),
    #("user_secret", "81924759284011"),
  ])
  |> hardcache.try_update
  |> hardcache.try_set("msg", "Hello, World!")
  |> hardcache.try_remove("user_secret")
  |> should.equal(
    Ok(hardcache.Cache(
      "./test/test_file.txt",
      [#("a", "A"), #("default", "1"), #("msg", "Hello, World!")],
      True,
    )),
  )
}

pub fn pair_parsing_test() {
  let pairs =
    hardcache.parse_entries("!a=Hello, World!\n!b=SGVsbG8sIFdvcmxkIQ==\n")
  pairs
  |> should.equal(hardcache.parse_entries(hardcache.stringify_entries(pairs)))
}
