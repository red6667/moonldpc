///|
/// Lexical safety pass before the standard parser. Full grammar validation remains
/// the parser's job. Decode object keys so escaped aliases cannot bypass strict fields.
fn guard_json(text : String) -> Unit raise CodeError {
  let units = text.to_array()
  let objects : Array[Bool] = []
  let key_expected : Array[Bool] = []
  let keys : Array[Map[String, Bool]] = []
  let mut i = 0
  while i < units.length() {
    let c = units[i]
    if c == '"' {
      let start = i
      i += 1
      let mut closed = false
      while i < units.length() {
        if units[i] == '\\' {
          i += 2
        } else if units[i] == '"' {
          i += 1
          closed = true
          break
        } else {
          i += 1
        }
      }
      if !closed {
        raise InvalidFormat(0, "unterminated string")
      }
      if !objects.is_empty() &&
        objects[objects.length() - 1] &&
        key_expected[key_expected.length() - 1] {
        let token = String::from_array(units[start:i].to_owned())
        let value = @json.parse(token) catch {
          _ => raise InvalidFormat(0, "invalid object key")
        }
        let key = match value {
          String(key) => key
          _ => raise InvalidFormat(0, "expected key")
        }
        let names = keys[keys.length() - 1]
        if names.contains(key) {
          raise InvalidFormat(0, "duplicate object key")
        }
        names[key] = true
        key_expected[key_expected.length() - 1] = false
      }
      continue
    }
    if c == '{' || c == '[' {
      if objects.length() >= 32 {
        raise ResourceLimit("JSON nesting depth")
      }
      objects.push(c == '{')
      key_expected.push(c == '{')
      keys.push(Map([]))
    } else if c == '}' || c == ']' {
      if objects.is_empty() {
        raise InvalidFormat(0, "unbalanced container")
      }
      ignore(objects.pop())
      ignore(key_expected.pop())
      ignore(keys.pop())
    } else if c == ',' && !objects.is_empty() && objects[objects.length() - 1] {
      key_expected[key_expected.length() - 1] = true
    }
    i += 1
  }
}
