///|
test "protocol all actions code forms decoder options and explicit null erasures" {
  let code : Json = { "variables": 3, "rows": [[0, 1], [1, 2]] }
  let requests : Array[Json] = [
    { "action": "analyze", "code": code },
    { "action": "encode", "code": code, "information": [1] },
    { "action": "decode", "code": code, "llr": [-3.0, 0.1, -3.0] },
    {
      "action": "decode",
      "code": code,
      "llr": [-3.0, 0.1, -3.0],
      "config": {
        "algorithm": "min-sum",
        "iterations": 20,
        "normalization": 0.8,
        "offset": 0.1,
        "llr_limit": 8.0,
      },
    },
    {
      "action": "decode",
      "code": code,
      "llr": [-3.0, 0.1, -3.0],
      "config": { "algorithm": "layered-min-sum" },
    },
    { "action": "peel", "code": code, "observations": [null, 1, null] },
    { "action": "recover", "code": code, "observations": [null, 1, null] },
    { "action": "bit-flip", "code": code, "word": [1, 0, 1], "iterations": 10 },
    { "action": "distance", "code": code },
    { "action": "alist", "code": code },
    { "action": "analyze", "code": { "base": [[0, 1]], "lift": 3 } },
    {
      "action": "analyze",
      "code": { "alist": @moonldpc.repetition_code(3).to_alist() },
    },
  ]
  for request in requests {
    let response = @json.parse(@moonldpc.execute(request.stringify()))
    assert_true(response is Object(fields) && fields.get("ok") is Some(True))
  }
  let partial = @moonldpc.repetition_code(3).peel([None, None, None]).to_json()
  assert_true(
    partial is Object(fields) &&
    fields.get("values") is Some(Array(values)) &&
    values.all(fn(v) { v is Null }),
  )
  // Delimiters/escapes inside a string must not count as nesting or object keys.
  let quoted : Json = { "action": "bad\\\"{[", "code": code }
  assert_true(
    @json.parse(@moonldpc.execute(quoted.stringify())) is Object(fields) &&
    fields.get("ok") is Some(False),
  )
}

///|
test "protocol invalid forms never become successful operations" {
  let code : Json = { "variables": 3, "rows": [[0, 1], [1, 2]] }
  let bad : Array[Json] = [
    { "action": "unknown", "code": code },
    { "action": 1, "code": code },
    { "action": "analyze" },
    { "action": "analyze", "code": { "variables": 3, "rows": "not rows" } },
    { "action": "analyze", "code": { "variables": 3, "rows": [[true]] } },
    { "action": "analyze", "code": { "base": [[0]], "lift": 2, "rows": [] } },
    { "action": "analyze", "code": { "alist": 0 } },
    { "action": "decode", "code": code, "llr": [0, false, 1] },
    { "action": "decode", "code": code, "llr": [0, 1, 1], "config": [] },
    {
      "action": "decode",
      "code": code,
      "llr": [0, 1, 1],
      "config": { "algorithm": "bad" },
    },
    {
      "action": "decode",
      "code": code,
      "llr": [0, 1, 1],
      "config": { "extra": 1 },
    },
    { "action": "peel", "code": code, "observations": [2, null, null] },
    { "action": "bit-flip", "code": code, "word": [1, 0, 1], "iterations": -1 },
    { "action": "encode", "code": code, "information": [true] },
    { "action": "encode", "code": code, "information": [1000001] },
  ]
  for request in bad {
    assert_true(
      @json.parse(@moonldpc.execute(request.stringify())) is Object(fields) &&
      fields.get("ok") is Some(False),
    )
  }
  for
    text in [
      "{\"a\":\"\\uZZZZ\"}", "{\"a\":\"unterminated", "}", "{\"a\":0,\"a\":1}", "{\"a\":{\"b\":0,\"b\":1}}",
      "{\"action\":\"analyze\",\"code\":{\"variables\":1e999,\"rows\":[[]]}}",
    ] {
    assert_true(
      @json.parse(@moonldpc.execute(text)) is Object(fields) &&
      fields.get("ok") is Some(False),
    )
  }
}

///|
test "reference and diagnostic protocol actions preserve strict schemas" {
  let code : Json = { "variables": 3, "rows": [[0, 1], [1, 2]] }
  let valid : Array[Json] = [
    {
      "action": "exact-decode",
      "code": code,
      "llr": [1.0, -0.1, 2.0],
      "limit": 8.0,
    },
    { "action": "nearest", "code": code, "word": [1, 0, 1] },
    { "action": "correct-single", "code": code, "word": [1, 0, 1] },
    { "action": "stopping", "code": code, "variables": [0, 1, 2] },
    {
      "action": "coset-encode",
      "code": code,
      "syndrome": [1, 0],
      "information": [1],
    },
  ]
  for request in valid {
    assert_true(
      @json.parse(@moonldpc.execute(request.stringify())) is Object(f) &&
      f.get("ok") is Some(True),
    )
  }
  let invalid : Array[Json] = [
    { "action": "exact-decode", "code": code, "llr": [1, 2, 3], "limit": 0 },
    { "action": "nearest", "code": code, "word": [1, 0, 1], "iterations": 10 },
    { "action": "correct-single", "code": code, "word": [1, 2, 1] },
    { "action": "stopping", "code": code, "variables": [0, 0] },
    {
      "action": "coset-encode",
      "code": code,
      "syndrome": [1],
      "information": [1],
    },
  ]
  for request in invalid {
    assert_true(
      @json.parse(@moonldpc.execute(request.stringify())) is Object(f) &&
      f.get("ok") is Some(False),
    )
  }
}
