///|
test "Wi-Fi soft decoding repairs deterministic wrong-sign observations" {
  let wifi = @moonldpc.WifiLdpc1944R34::new()
  let information = Array::makei(1458, fn(i) { (i * 13 + i / 7) % 2 })
  let word = wifi.encode(information)
  let clean = word.map(fn(bit) { if bit == 0 { 7.0 } else { -7.0 } })
  for
    algorithm in [
      @moonldpc.SumProduct,
      @moonldpc.MinSum,
      @moonldpc.LayeredMinSum,
    ] {
    let config = @moonldpc.DecoderConfig::new(algorithm, iterations=50)
    let noiseless = wifi.parity_check().decode(clean, config)
    assert_true(noiseless.converged)
    assert_eq(noiseless.word, word)
    let noisy = clean.copy()
    for i in [0, 80, 815, 1457, 1458, 1943] {
      noisy[i] = -clean[i] / 35.0
    }
    assert_eq(@moonldpc.bit_distance(@moonldpc.decide(noisy), word), 6)
    let result = wifi.parity_check().decode(noisy, config)
    assert_true(result.converged)
    assert_true(result.iterations > 0)
    assert_eq(result.word, word)
    assert_eq(wifi.extract(result.word), information)
  }
}

///|
test "Wi-Fi rejects invalid data and distinguishes syndrome from compatibility" {
  let wifi = @moonldpc.WifiLdpc1944R34::new()
  rejects(() => wifi.encode([]))
  rejects(() => wifi.encode(Array::make(1457, 0)))
  rejects(() => wifi.encode(Array::make(1459, 0)))
  let invalid = Array::make(1458, 0)
  invalid[1457] = 2
  rejects(() => wifi.encode(invalid))
  rejects(() => wifi.extract(Array::make(1943, 0)))
  let information = Array::makei(1458, fn(i) { (i * 13 + i / 7) % 2 })
  let word = wifi.encode(information)
  let broken = word.copy()
  broken[1943] = broken[1943] ^ 1
  rejects(() => wifi.extract(broken))
  broken[1943] = -1
  rejects(() => wifi.extract(broken))
  let code = wifi.parity_check()
  // Another valid codeword passes Hc=0 but fails the expected message comparison.
  let other = information.copy()
  other[0] = other[0] ^ 1
  let other_word = wifi.encode(other)
  assert_true(code.is_codeword(other_word))
  assert_true(other_word != word)
  assert_true(wifi.extract(other_word) != information)
  // Swapping the bit order within information octets changes this codeword.
  let reversed = Array::makei(1458, fn(i) {
    let j = i / 8 * 8 + 7 - i % 8
    information[if j < 1458 { j } else { i }]
  })
  assert_true(wifi.encode(reversed) != word)
  let llr = word.map(fn(bit) { if bit == 0 { 7.0 } else { -7.0 } })
  llr[0] = -llr[0]
  let stopped = code.decode(
    llr,
    @moonldpc.DecoderConfig::new(@moonldpc.SumProduct, iterations=0),
  )
  assert_true(!stopped.converged)
  assert_true(stopped.word != word)
}
