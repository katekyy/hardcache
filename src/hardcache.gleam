import file_streams/file_error
import file_streams/read_stream_error
import file_streams/read_text_stream
import file_streams/write_stream

import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

pub type Cache {
  Cache(file_path: String, content: String, auto_update: Bool)
}

pub type CacheError {
  CacheError(String)
  FileError(file_error.FileError)
  ReadStreamError(read_stream_error.ReadStreamError)
}

/// Creates a new cache by reading from the specified file path.
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
  case read_text_stream.open(file_path) {
    Ok(stream) ->
      case read_all(stream) {
        Ok(content) ->
          Ok(Cache(
            file_path: file_path,
            content: content,
            auto_update: auto_update,
          ))
        Error(e) -> Error(e)
      }
    Error(file_error.Enoent) -> {
      case write_stream.open(file_path) {
        Ok(stream) ->
          case write_stream.write_string(stream, "") {
            Error(fe) -> Error(FileError(fe))
            _ -> new(file_path, auto_update)
          }
        Error(fe) -> Error(FileError(fe))
      }
    }
    Error(fe) -> Error(FileError(fe))
  }
}

/// Sets a key-value pair in the cache.
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
  in orig: Result(Cache, CacheError),
  key key: String,
) -> Result(Cache, CacheError) {
  case orig {
    Ok(orig) -> remove(orig, key)
    e -> e
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
pub fn remove(in orig: Cache, key key: String) -> Result(Cache, CacheError) {
  case get(from: orig, key: key) {
    Ok(Some(orig_value)) -> {
      let result =
        Cache(
          file_path: orig.file_path,
          content: orig.content
            |> string.replace(stringify_entries([#(key, orig_value)]), ""),
          auto_update: orig.auto_update,
        )
      case result.auto_update {
        True -> {
          case update(result) {
            Ok(_) -> Ok(result)
            Error(fe) -> Error(fe)
          }
        }
        False -> Ok(result)
      }
    }
    Ok(None) -> Ok(orig)
    Error(e) -> Error(e)
  }
}

/// Sets a key-value pair in the cache.
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
    e -> e
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
  let result = case get(from: orig, key: key) {
    Ok(Some(orig_value)) if orig_value == value -> Ok(orig)
    Ok(Some(orig_value)) ->
      Ok(Cache(
        file_path: orig.file_path,
        content: orig.content
          |> string.replace(
          stringify_entries([#(key, orig_value)]),
          stringify_entries([#(key, value)]),
        ),
        auto_update: orig.auto_update,
      ))
    Ok(None) ->
      Ok(Cache(
        file_path: orig.file_path,
        content: orig.content <> stringify_entries([#(key, value)]),
        auto_update: orig.auto_update,
      ))
    Error(e) -> Error(e)
  }
  case result {
    Ok(result) if result.auto_update == True -> {
      case update(result) {
        Ok(_) -> Ok(result)
        Error(fe) -> Error(fe)
      }
    }
    _ -> result
  }
}

/// Sets multiple key-value pairs in the cache.
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
    e -> e
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

/// Sets multiple key-value pairs in the cache.
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
  in orig: Result(Cache, CacheError),
  key key: String,
) -> Result(Option(String), CacheError) {
  case orig {
    Ok(orig) -> get(orig, key)
    Error(e) -> Error(e)
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
///   Error(e) -> Error(e)
/// }
/// ```
/// 
pub fn get(
  from cache: Cache,
  key key: String,
) -> Result(Option(String), CacheError) {
  case
    list.filter(
      parse_entries(cache.content),
      keeping: fn(entry: #(String, String)) -> Bool { entry.0 == key },
    )
  {
    [entry] -> Ok(Some(entry.1))
    [_, ..] ->
      Error(CacheError(
        "Found multiple values with the same key in the cache. This should never happen! Was cache's content manipulated?",
      ))
    [] -> Ok(None)
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
///   |> hardcache.try_update
/// ```
/// 
pub fn try_update(
  in orig: Result(Cache, CacheError),
) -> Result(Cache, CacheError) {
  case orig {
    Ok(orig) -> update(orig)
    Error(e) -> Error(e)
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
  case write_stream.open(cache.file_path) {
    Ok(stream) ->
      case write_stream.write_string(stream, cache.content) {
        Ok(_) ->
          case write_stream.sync(stream) {
            Error(fe) -> Error(FileError(fe))
            _ -> Ok(cache)
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
/// let cache = hardcache.new("./example", False)
/// let cache = case cache {
///   Ok(cache) -> Ok(hardcache.auto_update(cache))
///   Error(e) -> Error(e)
/// }
/// ```
/// 
pub fn auto_update(cache: Cache) -> Cache {
  case cache.auto_update {
    False ->
      Cache(
        file_path: cache.file_path,
        content: cache.content,
        auto_update: True,
      )
    True -> cache
  }
}

@internal
pub fn read_all(stream: read_text_stream.ReadTextStream) -> Result(
  String,
  CacheError,
) {
  case read_text_stream.read_chars(stream, 1024) {
    Ok(char) -> {
      case read_text_stream.close(stream) {
        Ok(_) ->
          case read_all(stream) {
            Ok(next) -> Ok(char <> next)
            e -> e
          }
        Error(fe) -> Error(ReadStreamError(fe))
      }
    }
    Error(_) -> Ok("")
  }
}

@internal
pub fn parse_entries(str: String) -> List(#(String, String)) {
  string.split(str, "\n")
  |> list.filter_map(parse_line)
}

@internal
pub fn parse_line(line: String) -> Result(#(String, String), Nil) {
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

@internal
pub fn stringify_entries(entries: List(#(String, String))) -> String {
  case entries {
    [] -> ""
    [entry, ..tail] ->
      "!" <> entry.0 <> "=" <> entry.1 <> "\n" <> stringify_entries(tail)
  }
}
