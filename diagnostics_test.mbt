///|
test "stopping sets agree with exhaustive BEC peeling residuals" {
  let code = @moonldpc.hamming7()
  for mask in 0..<128 {
    let selected : Array[Int32] = []
    let observation : Array[Int32?] = Array::make(7, Some(0))
    for v in 0..<7 {
      if ((mask >> v) & 1) == 1 {
        selected.push(v)
        observation[v] = None
      }
    }
    let report = code.stopping_set_report(selected)
    let residual = code.peel(observation).unresolved
    assert_true(code.stopping_set_report(residual).is_stopping_set)
    assert_eq(report.is_stopping_set, selected.length() == residual.length())
    for c in report.singleton_checks {
      let mut degree = 0
      for v in code.check_variables(c) {
        if selected.contains(v) {
          degree += 1
        }
      }
      assert_eq(degree, 1)
    }
  }
  rejects(() => code.stopping_set_report([0, 0]))
  rejects(() => code.stopping_set_report([7]))
}

///|
test "single error correction is exhaustive and ambiguity aware" {
  let code = @moonldpc.hamming7()
  let encoder = @moonldpc.Encoder::new(code)
  for mask in 0..<16 {
    let word = encoder.encode(bits(mask, 4))
    assert_true(code.correct_single(word).unchanged)
    for v in 0..<7 {
      let noisy = word.copy()
      noisy[v] = noisy[v] ^ 1
      let report = code.correct_single(noisy)
      assert_eq(report.word, Some(word))
      assert_eq(report.candidates, [v])
    }
  }
  let ambiguous = @moonldpc.ParityCheck::new(2, [[0, 1]]).correct_single([1, 0])
  assert_eq(ambiguous.word, None)
  assert_eq(ambiguous.candidates, [0, 1])
  assert_eq(
    @moonldpc.ParityCheck::new(2, [[0], [1]]).correct_single([1, 1]).word,
    None,
  )
  rejects(() => code.correct_single([2]))
}
