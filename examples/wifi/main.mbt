///|
fn main {
  run() catch {
    _ => panic()
  }
}

///|
fn run() -> Unit raise {
  let wifi = @moonldpc.WifiLdpc1944R34::new()
  let information = Array::makei(1458, fn(i) { (i * 13 + i / 7) % 2 })
  let word = wifi.encode(information)
  let llr = word.map(fn(bit) { if bit == 0 { 7.0 } else { -7.0 } })
  for i in [0, 80, 815, 1457, 1458, 1943] {
    llr[i] = -llr[i] / 35.0
  }
  let decoded = wifi
    .parity_check()
    .decode(
      llr,
      @moonldpc.DecoderConfig::new(@moonldpc.SumProduct, iterations=50),
    )
  assert_true(decoded.converged)
  assert_eq(decoded.word, word)
  assert_eq(wifi.extract(decoded.word), information)
  println(
    "IEEE 802.11 LDPC n=1944 k=1458 rate=3/4: six weak sign errors recovered",
  )
  println("iterations: \{decoded.iterations}")
}
