///|
fn oracle_decode(
  n : Int32,
  rows : Array[Array[Int32]],
  channel : Array[Double],
  algorithm : @moonldpc.Algorithm,
  iterations : Int32,
  alpha : Double,
  offset : Double,
  expected : Array[Double],
  history : Array[Int32],
) -> Unit raise {
  let code = @moonldpc.ParityCheck::new(n, rows)
  let config = @moonldpc.DecoderConfig::new(
    algorithm,
    iterations~,
    normalization=alpha,
    offset~,
    llr_limit=8.0,
  )
  let result = code.decode(channel, config)
  assert_eq(result.syndrome_weights, history)
  assert_eq(result.iterations, history.length() - 1)
  assert_eq(result.converged, history[history.length() - 1] == 0)
  for i in 0..<n {
    close(result.posterior_llr[i], expected[i], tolerance=0.0000001)
    if expected[i].abs() > 0.0000001 {
      assert_eq(result.word[i], if expected[i] < 0.0 { 1 } else { 0 })
    }
  }
}

///|
fn oracle_kernel(
  n : Int32,
  rows : Array[Array[Int32]],
  expected : Array[Int32],
) -> Unit raise {
  let code = @moonldpc.ParityCheck::new(n, rows)
  let encoder = @moonldpc.Encoder::new(code)
  assert_eq(1 << encoder.dimension(), expected.length())
  let actual : Array[Int32] = []
  for mask in 0..<(1 << encoder.dimension()) {
    let information = bits(mask, encoder.dimension())
    let word = encoder.encode(information)
    assert_eq(encoder.extract(word), information)
    assert_eq(code.syndrome(word), Array::make(rows.length(), 0))
    let mut packed = 0
    for i in 0..<n {
      packed += word[i] << i
    }
    actual.push(packed)
  }
  actual.sort()
  assert_eq(actual, expected)
  let weights = Array::make(n + 1, 0)
  for mask in expected {
    weights[bits(mask, n).fold(init=0, fn(a, b) { a + b })] += 1
  }
  assert_eq(encoder.distance_report().weight_distribution, weights)
  for mask in 0..<(1 << n) {
    let syndrome = code.syndrome(bits(mask, n))
    assert_eq(code.syndrome(encoder.solve_syndrome(syndrome)), syndrome)
  }
}
