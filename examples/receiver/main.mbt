///|
fn main {
  run() catch {
    _ => panic()
  }
}

///|
fn run() -> Unit raise {
  // User-defined systematic QC code, not a standardized radio profile.
  let code = @moonldpc.lift_qc(
    [[0, 1, -1, 0, -1, -1], [1, 0, 2, -1, 0, -1], [2, -1, 0, -1, -1, 0]],
    7,
  )
  let encoder = @moonldpc.Encoder::new(code)
  let information = Array::makei(encoder.dimension(), fn(i) {
    (i * 7 + i / 3) % 2
  })
  let transmitted = encoder.encode(information)
  let symbols = @moonldpc.bpsk(transmitted)
  let received = symbols.map(fn(x) { 0.85 * x })
  received[0] = -0.1 * symbols[0] // one weak wrong-sign observation
  let llr = @moonldpc.awgn_llr(received, 0.4)
  let result = code.decode(
    llr,
    @moonldpc.DecoderConfig::new(@moonldpc.SumProduct, iterations=30),
  )
  assert_true(result.converged)
  assert_eq(encoder.extract(result.word), information)
  let counts = @moonldpc.ErrorCounts::new().observe(
    transmitted,
    result.word,
    result.converged,
  )
  println("receiver: 42-bit custom QC frame; information recovered")
  println(result.to_json().stringify())
  println(counts.to_json().stringify())
}
