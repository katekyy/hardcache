import file_streams/file_stream
import file_streams/file_stream_error

import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

pub type Cache {
  Cache(
    file_path: String,
    entries: List(#(String, String)),
    auto_update: Bool,
    decode: fn(String) -> List(#(String, String)),
    encode: fn(List(#(String, String))) -> String,
  )
}

pub type CacheError {
  FileError(file_stream_error.FileStreamError)
}

/// Creates a new cache by reading from the specified file path.
/// Uses the default encoder and decoder.
/// 
/// ## Examples
/// 
/// ```gleam
/// let cache = hardcache.new("./example.txt", True)
/// ```
/// 
pub fn new(
  path file_path: String,
  auto_update auto_update: Bool,
) -> Result(Cache, CacheError) {
  new_custom_format(file_path, auto_update, default_decoder, default_encoder)
}

/// Creates a new cache by reading from the specified file path.
/// 
/// ## Examples
/// 
/// ```gleam
/// let cache =
///   hardcache.new_custom_format("./example.txt", True, hardcache.default_decoder, hardcache.default_encoder)
/// ```
/// 
pub fn new_custom_format(
  path file_path: String,
  auto_update auto_update: Bool,
  decoder decode: fn(String) -> List(#(String, String)),
  encoder encode: fn(List(#(String, String))) -> String,
) -> Result(Cache, CacheError) {
  case file_stream.open_read(file_path) {
    Ok(stream) ->
      case read_all(stream) {
        Ok(content) ->
          Ok(Cache(
            file_path: file_path,
            entries: decode(content),
            auto_update: auto_update,
            decode: decode,
            encode: encode,
          ))
        Error(err) -> Error(err)
      }
    Error(file_stream_error.Enoent) -> {
      case create_file(file_path) {
        Ok(_) -> new_custom_format(file_path, auto_update, decode, encode)
        Error(fe) -> Error(FileError(fe))
      }
    }
    Error(fe) -> Error(FileError(fe))
  }
}

/// Sets a key-value pair in the cache or propagates the error.
/// 
/// ## Examples
/// 
/// ```gleam
/// let cache =
///   hardcache.new("./example.txt", True)
///   |> hardcache.try_set("a", "A")
/// // -> Ok(Cache("./example.txt", "!a=A\n", True))
/// let cache =
///   cache
///   |> hardcache.try_remove("a")
/// // -> Ok(Cache("./example.txt", "", True))
/// ```
/// 
pub fn try_remove(
  from orig: Result(Cache, CacheError),
  key key: String,
) -> Result(Cache, CacheError) {
  case orig {
    Ok(orig) -> remove(orig, key)
    err -> err
  }
}

/// Removes a key-value pair from the cache.
/// 
/// ## Examples
/// 
/// ```gleam
/// let cache =
///   hardcache.new("./example.txt", True)
///   |> hardcache.try_set("a", "A")
/// // -> Ok(Cache("./example.txt", "!a=A\n", True))
/// let cache = case cache {
///   Ok(cache) ->
///     cache
///     |> hardcache.remove("a")
///   Error(e) -> Error(e)
/// }
/// // -> Ok(Cache("./example.txt", "", True))
/// ```
/// 
pub fn remove(from orig: Cache, key key: String) -> Result(Cache, CacheError) {
  case list.key_pop(orig.entries, key) {
    Ok(#(_, rest)) -> {
      let result =
        Cache(
          file_path: orig.file_path,
          entries: rest,
          auto_update: orig.auto_update,
          decode: orig.decode,
          encode: orig.encode,
        )
      case result.auto_update {
        True ->
          case update(result) {
            Ok(result) -> Ok(result)
            err -> err
          }
        False -> Ok(result)
      }
    }
    Error(_) -> Ok(orig)
  }
}

/// Sets a key-value pair in the list if it is not already set or propagates the error. 
/// 
/// ## Examples
/// 
/// ```gleam
/// let cache =
///   hardcache.new("./example.txt", True)
///   |> hardcache.try_defaults(cache, [#("msg", "Hello!")])
/// ```
/// 
pub fn try_defaults(
  in orig: Result(Cache, CacheError),
  defaults entries: List(#(String, String)),
) -> Result(Cache, CacheError) {
  case orig {
    Ok(orig) -> defaults(orig, entries)
    err -> err
  }
}

/// Sets a key-value pair in the list if it is not already set. 
/// 
/// ## Examples
/// 
/// ```gleam
/// let cache = case hardcache.new("./example.txt", True) {
///   Ok(cache) -> hardcache.defaults(cache, [#("msg", "Hello!")])
///   err -> err
/// }
/// ```
/// 
pub fn defaults(
  in orig: Cache,
  defaults entries: List(#(String, String)),
) -> Result(Cache, CacheError) {
  case entries {
    [] -> Ok(orig)
    [entry, ..tail] ->
      case get(orig, entry.0) {
        Some(_) -> defaults(orig, tail)
        None ->
          case set(orig, entry.0, entry.1) {
            Ok(result) -> defaults(result, tail)
            err -> err
          }
      }
  }
}

/// Sets a key-value pair in the cache or propagates the error.
/// 
/// ## Examples
/// 
/// ```gleam
/// let cache =
///   hardcache.new("./example.txt", True)
///   |> hardcache.try_set("a", "A")
/// ```
/// 
pub fn try_set(
  in orig: Result(Cache, CacheError),
  key key: String,
  value value: String,
) -> Result(Cache, CacheError) {
  case orig {
    Ok(orig) -> set(orig, key, value)
    err -> err
  }
}

/// Sets a key-value pair in the cache.
/// 
/// ## Examples
/// 
/// ```gleam
/// let cache = hardcache.new("./example.txt", True)
/// let cache = case cache {
///   Ok(cache) ->
///     cache
///     |> hardcache.set("a", "A")
///   Error(e) -> Error(e)
/// }
/// ```
/// 
pub fn set(
  in orig: Cache,
  key key: String,
  value value: String,
) -> Result(Cache, CacheError) {
  let result =
    Cache(
      file_path: orig.file_path,
      entries: list.key_set(orig.entries, key, value),
      auto_update: orig.auto_update,
      decode: orig.decode,
      encode: orig.encode,
    )
  case result.auto_update {
    True ->
      case update(result) {
        Ok(result) -> Ok(result)
        err -> err
      }
    False -> Ok(result)
  }
}

/// Sets multiple key-value pairs in the cache or propagates the error.
/// 
/// ## Examples
/// 
/// ```gleam
/// let cache =
///   hardcache.new("./example.txt", True)
///   |> hardcache.try_set_many([#("a", "A"), #("b", "B")])
/// ```
/// 
pub fn try_set_many(
  in orig: Result(Cache, CacheError),
  entries entries: List(#(String, String)),
) -> Result(Cache, CacheError) {
  case orig {
    Ok(orig) -> set_many(orig, entries)
    err -> err
  }
}

/// Sets multiple key-value pairs in the cache.
/// 
/// ## Examples
/// 
/// ```gleam
/// let cache = hardcache.new("./example.txt", True)
/// let cache = case cache {
///   Ok(cache) ->
///     cache
///     |> hardcache.set_many([#("a", "A"), #("b", "B")])
///   Error(e) -> Error(e)
/// }
/// ```
/// 
pub fn set_many(
  in orig: Cache,
  entries entries: List(#(String, String)),
) -> Result(Cache, CacheError) {
  case entries {
    [] -> Ok(orig)
    [entry, ..tail] ->
      case set(orig, entry.0, entry.1) {
        Ok(result) -> set_many(result, tail)
        fe -> fe
      }
  }
}

/// Gets a string assigned to the `key` (2nd argument) or returns the string `or` (3rd argument) when unsuccessful
/// (when the 1st argument is a `CacheError` or when there's no value assigned to the `key`).
/// 
/// ## Example
/// 
/// ```gleam
/// let cache =
///   hardcache.new("./non_existent_directory/example.txt", True)
///   |> hardcache.try_set("test", "something important") // propagates the error from `new`
/// // -> Error(FileError(Enoent))
/// let a =
///   cache
///   |> hardcache.get_unwrap("test", "(none)")
/// // -> "(none)"
/// ```
/// 
pub fn try_get_unwrap(
  in orig: Result(Cache, CacheError),
  key key: String,
  or when_none_or_error: String,
) -> String {
  case try_get(orig, key) {
    Ok(option_string) ->
      case option_string {
        Some(string) -> string
        None -> when_none_or_error
      }
    Error(_) -> when_none_or_error
  }
}

/// Gets a string assigned to the `key` (2nd argument) or returns the string `or` (3rd argument) when there's no value assigned to the `key`.
/// 
/// ## Example
/// 
/// ```gleam
/// let cache = hardcache.new("./example.txt", True)
/// let a =
///   cache
///   |> hardcache.get_unwrap("test", "(none)")
/// // -> "(none)"
/// ```
/// 
pub fn get_unwrap(
  in orig: Cache,
  key key: String,
  or when_none: String,
) -> String {
  case get(orig, key) {
    Some(string) -> string
    None -> when_none
  }
}

/// Sets multiple key-value pairs in the cache or propagates the error.
/// 
/// ## Examples
/// 
/// ```gleam
/// let cache =
///   hardcache.new("./example.txt", True)
///   |> hardcache.try_set("a", "A")
/// let a =
///   cache
///   |> hardcache.try_get("a")
/// ```
/// 
pub fn try_get(
  from orig: Result(Cache, CacheError),
  key key: String,
) -> Result(Option(String), CacheError) {
  case orig {
    Ok(orig) -> Ok(get(orig, key))
    Error(err) -> Error(err)
  }
}

/// Gets the value associated with a key in the cache.
/// 
/// ## Examples
/// 
/// ```gleam
/// let cache =
///   hardcache.new("./example.txt", True)
///   |> hardcache.try_set("a", "A")
/// let a = case cache {
///   Ok(cache) ->
///     cache
///     |> hardcache.get("a")
///   Error(_) -> option.None
/// }
/// ```
/// 
pub fn get(from cache: Cache, key key: String) -> Option(String) {
  case list.key_find(cache.entries, key) {
    Ok(value) -> Some(value)
    Error(_) -> None
  }
}

/// Updates the cache file with the current cache content or propagates the error.
/// 
/// ## Examples
/// 
/// ```gleam
/// let cache =
///   hardcache.new("./example.txt", False)
///   |> hardcache.try_set("a", "A")
///   |> hardcache.try_set("b", "B")
///   |> hardcache.try_set_many([#("c", "C")])
///   |> hardcache.try_update
/// ```
/// 
pub fn try_update(cache: Result(Cache, CacheError)) -> Result(Cache, CacheError) {
  case cache {
    Ok(cache) -> update(cache)
    err -> err
  }
}

/// Updates the cache file with the current cache content.
/// 
/// ## Examples
/// 
/// ```gleam
/// let cache =
///   hardcache.new("./example.txt", False)
///   |> hardcache.try_set("a", "A")
///   |> hardcache.try_set("b", "B")
///   |> hardcache.try_set_many([#("c", "C")])
/// 
/// let cache = case cache {
///   Ok(cache) -> hardcache.update(cache)
///   Error(e) -> Error(e)
/// }
/// ```
/// 
pub fn update(cache: Cache) -> Result(Cache, CacheError) {
  case file_stream.open_write(cache.file_path) {
    Ok(stream) ->
      case
        file_stream.write_bytes(stream, <<cache.encode(cache.entries):utf8>>)
      {
        Ok(_) ->
          case file_stream.sync(stream) {
            Ok(_) ->
              case file_stream.close(stream) {
                Ok(_) -> Ok(cache)
                Error(fe) -> Error(FileError(fe))
              }
            Error(fe) -> Error(FileError(fe))
          }
        Error(fe) -> Error(FileError(fe))
      }
    Error(fe) -> Error(FileError(fe))
  }
}

/// Sets the auto_update field of the cache to True.
/// 
/// ## Examples
/// 
/// ```gleam
/// let cache = hardcache.new("./example.txt", False)
/// let cache = case cache {
///   Ok(cache) -> Ok(hardcache.auto_update(cache))
///   Error(e) -> Error(e)
/// }
/// ```
/// 
pub fn auto_update(cache: Cache) -> Cache {
  case cache.auto_update {
    True -> cache
    False ->
      Cache(
        file_path: cache.file_path,
        entries: cache.entries,
        auto_update: True,
        decode: cache.decode,
        encode: cache.encode,
      )
  }
}

/// Parses a string into key-value pairs.
/// 
/// ## Example
/// 
/// ```gleam
/// hardcache.default_decoder("!key=value\n")
/// // -> [#("key", "value")]
/// ```
/// 
pub fn default_decoder(string: String) -> List(#(String, String)) {
  string.split(string, "\n")
  |> list.filter_map(parse_line)
}

/// Converts key-value pairs to a string.
/// 
/// ## Example
/// 
/// ```gleam
/// hardcache.default_encoder([#("key", "value")])
/// // -> "!key=value\n"
/// ```
/// 
pub fn default_encoder(entries: List(#(String, String))) -> String {
  case entries {
    [] -> ""
    [entry, ..tail] ->
      "!" <> entry.0 <> "=" <> entry.1 <> "\n" <> default_encoder(tail)
  }
}

fn create_file(
  file_path: String,
) -> Result(Nil, file_stream_error.FileStreamError) {
  case file_stream.open_write(file_path) {
    Ok(stream) -> file_stream.close(stream)
    Error(fe) -> Error(fe)
  }
}

fn read_all(stream: file_stream.FileStream) -> Result(String, CacheError) {
  case file_stream.read_chars(stream, 1024) {
    Ok(char) -> {
      case file_stream.close(stream) {
        Ok(_) ->
          case read_all(stream) {
            Ok(next) -> Ok(char <> next)
            err -> err
          }
        Error(fe) -> Error(FileError(fe))
      }
    }
    _ -> Ok("")
  }
}

fn parse_line(line: String) -> Result(#(String, String), Nil) {
  let parts = string.split(line, "=")
  case parts {
    [key, ..value] ->
      case string.first(key) {
        Ok("!") ->
          Ok(#(
            string.drop_left(key, 1),
            string.join(value, "="),
            // Restore the equal signs
          ))
        _ -> Error(Nil)
      }
    _ -> Error(Nil)
  }
}
