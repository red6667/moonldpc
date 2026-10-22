///|
fn main {
  run() catch {
    _ => panic()
  }
}

///|
fn run() -> Unit raise {
  let code = @moonldpc.repetition_code(5)
  let encoder = @moonldpc.Encoder::new(code)
  let word = encoder.encode([1])
  let plan = @moonldpc.RatePlan::new(5, [0, 2, 4, 4])
  let transmitted = plan.project(word)
  let channel = @moonldpc.bsc_llr(transmitted, 0.05)
  let restored = plan.restore_llr(channel)
  let result = code.decode(
    restored,
    @moonldpc.DecoderConfig::new(@moonldpc.LayeredMinSum),
  )
  assert_true(result.converged && plan.accepts(result.word))
  assert_eq(result.word, word)
  let erased = code.peel([None, None, Some(1), None, None])
  assert_true(erased.complete)
  println("telemetry: repetition/puncturing LLRs and BEC recovery")
  println(result.to_json().stringify())
  println(erased.to_json().stringify())
  // A stopping set can have a unique algebraic solution despite peeling stalling.
  let stopping = @moonldpc.ParityCheck::new(3, [[0, 1], [1, 2], [0, 1, 2]])
  assert_true(!stopping.peel([None, None, None]).complete)
  let exact = stopping.recover_erasures([None, None, None])
  assert_true(exact.unique)
  println(exact.to_json().stringify())
}
