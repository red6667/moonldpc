///|
fn object(value : Json) -> Map[String, Json] raise CodeError {
  match value {
    Object(fields) => fields
    _ => raise InvalidFormat(0, "expected JSON object")
  }
}

///|
fn allowed(
  fields : Map[String, Json],
  names : Array[String],
) -> Unit raise CodeError {
  for key, _ in fields {
    if !names.contains(key) {
      raise InvalidFormat(0, "unknown field: " + key)
    }
  }
}

///|
fn required(fields : Map[String, Json], key : String) -> Json raise CodeError {
  match fields.get(key) {
    Some(value) => value
    None => raise InvalidFormat(0, "missing field: " + key)
  }
}

///|
fn json_integer(value : Json) -> Int raise CodeError {
  match value {
    Number(x, ..) => {
      if !finite(x) || x < -1000000.0 || x > 1000000.0 || @math.floor(x) != x {
        raise InvalidFormat(0, "integer outside [-1000000,1000000]")
      }
      x.to_int()
    }
    _ => raise InvalidFormat(0, "expected integer")
  }
}

///|
fn json_string(value : Json) -> String raise CodeError {
  match value {
    String(text) => text
    _ => raise InvalidFormat(0, "expected string")
  }
}

///|
fn json_array(value : Json) -> Array[Json] raise CodeError {
  match value {
    Array(values) => {
      if values.length() > 1000000 {
        raise ResourceLimit("JSON array")
      }
      values
    }
    _ => raise InvalidFormat(0, "expected array")
  }
}

///|
fn json_ints(value : Json) -> Array[Int] raise CodeError {
  let result : Array[Int] = []
  for item in json_array(value) {
    result.push(json_integer(item))
  }
  result
}

///|
fn json_rows(value : Json) -> Array[Array[Int]] raise CodeError {
  let result : Array[Array[Int]] = []
  let mut count = 0
  for row in json_array(value) {
    let values = json_ints(row)
    if values.length() > 1000000 - count {
      raise ResourceLimit("JSON matrix cells")
    }
    count += values.length()
    result.push(values)
  }
  result
}

///|
fn json_double(value : Json) -> Double raise CodeError {
  match value {
    Number(x, ..) =>
      if finite(x) {
        x
      } else {
        raise InvalidNumber("finite JSON number required")
      }
    _ => raise InvalidFormat(0, "expected number")
  }
}

///|
fn json_doubles(value : Json) -> Array[Double] raise CodeError {
  let result : Array[Double] = []
  for item in json_array(value) {
    result.push(json_double(item))
  }
  result
}

///|
fn code_from_json(value : Json) -> ParityCheck raise CodeError {
  let fields = object(value)
  if fields.contains("alist") {
    allowed(fields, ["alist"])
    return parse_alist(json_string(required(fields, "alist")))
  }
  if fields.contains("base") {
    allowed(fields, ["base", "lift"])
    return lift_qc(
      json_rows(required(fields, "base")),
      json_integer(required(fields, "lift")),
    )
  }
  allowed(fields, ["variables", "rows"])
  ParityCheck::new(
    json_integer(required(fields, "variables")),
    json_rows(required(fields, "rows")),
  )
}

///|
fn config_from_json(value : Json) -> DecoderConfig raise CodeError {
  let fields = object(value)
  allowed(fields, [
    "algorithm", "iterations", "normalization", "offset", "llr_limit",
  ])
  let name = match fields.get("algorithm") {
    Some(v) => json_string(v)
    None => "sum-product"
  }
  let algorithm = match name {
    "sum-product" => SumProduct
    "min-sum" => MinSum
    "layered-min-sum" => LayeredMinSum
    _ => raise InvalidFormat(0, "unknown decoder algorithm")
  }
  let iterations = match fields.get("iterations") {
    Some(v) => json_integer(v)
    None => 50
  }
  let normalization = match fields.get("normalization") {
    Some(v) => json_double(v)
    None => 1.0
  }
  let offset = match fields.get("offset") {
    Some(v) => json_double(v)
    None => 0.0
  }
  let limit = match fields.get("llr_limit") {
    Some(v) => json_double(v)
    None => 50.0
  }
  DecoderConfig::new(
    algorithm,
    iterations~,
    normalization~,
    offset~,
    llr_limit=limit,
  )
}

///|
/// Host-neutral JSON protocol v1. Error output is structured; no files or network are accessed.
pub fn process_json(request : Json) -> Json raise CodeError {
  let fields = object(request)
  let action = json_string(required(fields, "action"))
  let code = code_from_json(required(fields, "code"))
  match action {
    "analyze" => {
      allowed(fields, ["action", "code"])
      let encoder = Encoder::new(code)
      let graph = code.analyze()
      {
        "ok": true,
        "graph": graph.to_json(),
        "rank": encoder.rank(),
        "dimension": encoder.dimension(),
        "girth": code.girth().to_json(),
      }
    }
    "encode" => {
      allowed(fields, ["action", "code", "information"])
      let encoder = Encoder::new(code)
      let word = encoder.encode(json_ints(required(fields, "information")))
      {
        "ok": true,
        "word": word.to_json(),
        "information_positions": encoder.information_positions().to_json(),
        "syndrome": code.syndrome(word).to_json(),
      }
    }
    "decode" => {
      allowed(fields, ["action", "code", "llr", "config"])
      let config = match fields.get("config") {
        Some(value) => config_from_json(value)
        None => DecoderConfig::new(SumProduct)
      }
      let result = code.decode(json_doubles(required(fields, "llr")), config)
      { "ok": true, "result": result.to_json() }
    }
    "peel" | "recover" => {
      allowed(fields, ["action", "code", "observations"])
      let observations : Array[Int?] = []
      for value in json_array(required(fields, "observations")) {
        if value is Null {
          observations.push(None)
        } else {
          observations.push(Some(json_integer(value)))
        }
      }
      let result = if action == "peel" {
        code.peel(observations).to_json()
      } else {
        code.recover_erasures(observations).to_json()
      }
      { "ok": true, "result": result }
    }
    "bit-flip" => {
      allowed(fields, ["action", "code", "word", "iterations"])
      let iterations = match fields.get("iterations") {
        Some(v) => json_integer(v)
        None => 50
      }
      let result = code.bit_flip(
        json_ints(required(fields, "word")),
        iterations~,
      )
      { "ok": true, "result": result.to_json() }
    }
    "distance" => {
      allowed(fields, ["action", "code"])
      let result = Encoder::new(code).distance_report()
      { "ok": true, "result": result.to_json() }
    }
    "exact-decode" => {
      allowed(fields, ["action", "code", "llr", "limit"])
      let limit = match fields.get("limit") {
        Some(v) => json_double(v)
        None => 50.0
      }
      let result = Encoder::new(code).decode_exact(
        json_doubles(required(fields, "llr")),
        limit~,
      )
      { "ok": true, "result": result.to_json() }
    }
    "nearest" => {
      allowed(fields, ["action", "code", "word"])
      let result = Encoder::new(code).nearest_word(
        json_ints(required(fields, "word")),
      )
      { "ok": true, "result": result.to_json() }
    }
    "correct-single" => {
      allowed(fields, ["action", "code", "word"])
      let result = code.correct_single(json_ints(required(fields, "word")))
      { "ok": true, "result": result.to_json() }
    }
    "stopping" => {
      allowed(fields, ["action", "code", "variables"])
      let result = code.stopping_set_report(
        json_ints(required(fields, "variables")),
      )
      { "ok": true, "result": result.to_json() }
    }
    "coset-encode" => {
      allowed(fields, ["action", "code", "syndrome", "information"])
      let encoder = CosetEncoder::new(
        code,
        json_ints(required(fields, "syndrome")),
      )
      let word = encoder.encode(json_ints(required(fields, "information")))
      {
        "ok": true,
        "word": word.to_json(),
        "syndrome": code.syndrome(word).to_json(),
      }
    }
    "alist" => {
      allowed(fields, ["action", "code"])
      { "ok": true, "alist": code.to_alist() }
    }
    _ => raise InvalidFormat(0, "unknown action")
  }
}

///|
/// Errors are data, including JSON syntax errors. CLI exits zero on a protocol error;
/// automation must inspect the `ok` field, not treat process exit as decode success.
pub fn execute(request : String) -> String {
  if request.length() > 16777216 {
    return "{\"ok\":false,\"error\":\"request size limit\"}"
  }
  guard_json(request) catch {
    _ =>
      return "{\"ok\":false,\"error\":\"invalid JSON structure or duplicate key\"}"
  }
  let parsed = @json.parse(request) catch {
    _ => return "{\"ok\":false,\"error\":\"invalid JSON\"}"
  }
  let response = process_json(parsed) catch {
    error => {
      let diagnostic = error.to_repr().to_string()
      let result : Json = { "ok": false, "error": diagnostic }
      return result.stringify()
    }
  }
  response.stringify()
}
