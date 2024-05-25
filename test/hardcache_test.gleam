import gleeunit
import gleeunit/should

import file_streams/file_stream_error

import hardcache

pub fn main() {
  gleeunit.main()
}

pub fn cache_test() {
  let cache =
    hardcache.new("./test/test_file.txt", True)
    |> hardcache.try_set("a", "A")
    |> hardcache.try_defaults([#("default", "1"), #("a", "abc")])
    |> hardcache.try_set_many([])
    |> hardcache.try_set_many([
      #("msg", "Hello!"),
      #("user_secret", "81924759284011"),
    ])
    |> hardcache.try_update()
    |> hardcache.try_set("msg", "Hello, World!")
    |> hardcache.try_remove("user_secret")
  should.be_true(case cache {
    Ok(hardcache.Cache(
      "./test/test_file.txt",
      [#("a", "A"), #("default", "1"), #("msg", "Hello, World!")],
      True,
      _,
      _,
    )) -> True
    _ -> False
  })
}

pub fn non_existent_cache_test() {
  hardcache.new("./test/doesnt_exist/test_file.txt", True)
  |> hardcache.try_set("a", "A")
  |> hardcache.try_defaults([#("default", "1"), #("a", "abc")])
  |> hardcache.try_set_many([])
  |> hardcache.try_set_many([
    #("msg", "Hello!"),
    #("user_secret", "81924759284011"),
  ])
  |> hardcache.try_update()
  |> hardcache.try_set("msg", "Hello, World!")
  |> hardcache.try_remove("user_secret")
  |> hardcache.try_get_unwrap("msg", "encountered an error")
  |> should.equal("encountered an error")

  hardcache.new("./test/doesnt_exist/test_file.txt", True)
  |> hardcache.try_get("test")
  |> should.equal(Error(hardcache.FileError(file_stream_error.Enoent)))
}

pub fn pair_parsing_test() {
  let pairs =
    hardcache.default_decoder("!a=Hello, World!\n!b=SGVsbG8sIFdvcmxkIQ==\n")

  pairs
  |> should.equal(hardcache.default_decoder(hardcache.default_encoder(pairs)))

  pairs
  |> hardcache.default_encoder()
  |> hardcache.default_decoder()
  |> should.equal([#("a", "Hello, World!"), #("b", "SGVsbG8sIFdvcmxkIQ==")])
}
