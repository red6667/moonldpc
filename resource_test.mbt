///|
test "resource budgets reject adversarial matrices before expensive work" {
  let oversized = @moonldpc.ParityCheck::new(2049, [[]])
  rejects(() => @moonldpc.Encoder::new(oversized))
  rejects(() => oversized.recover_erasures(Array::make(2049, None)))
  let many_checks = @moonldpc.ParityCheck::new(
    1,
    Array::makei(2049, fn(_) { [0] }),
  )
  rejects(() => many_checks.analyze())
  let dense = @moonldpc.ParityCheck::new(
    256,
    Array::makei(256, fn(_) { Array::makei(256, fn(i) { i }) }),
  )
  rejects(() => {
    dense.decode(
      Array::make(256, 1.0),
      @moonldpc.DecoderConfig::new(MinSum, iterations=10000),
    )
  })
  let expensive = @moonldpc.Encoder::new(
    @moonldpc.ParityCheck::new(256, [Array::makei(244, fn(i) { i })]),
  )
  rejects(() => expensive.decode_exact(Array::make(256, 0.0)))
  rejects(() => @moonldpc.ParityCheck::new(1, [[0, 0]]))
  rejects(() => @moonldpc.ParityCheck::new(65537, [[]]))
}

///|
test "finite posterior invariants at extreme channel dynamic range" {
  let code = @moonldpc.hamming7()
  let encoder = @moonldpc.Encoder::new(code)
  for
    algorithm in [
      @moonldpc.SumProduct,
      @moonldpc.MinSum,
      @moonldpc.LayeredMinSum,
    ] {
    for mask in 0..<16 {
      let word = encoder.encode(bits(mask, 4))
      let input = @moonldpc.bpsk(word).map(fn(x) { x * 1.0e300 })
      let report = code.decode(
        input,
        @moonldpc.DecoderConfig::new(algorithm, llr_limit=100.0),
      )
      assert_eq(report.word, word)
      for value in report.posterior_llr {
        assert_true(!value.is_nan() && !value.is_inf())
      }
      assert_eq(input[0].abs(), 1.0e300)
    }
  }
  rejects(() => {
    code.decode(
      [0.0 / 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
      @moonldpc.DecoderConfig::new(SumProduct),
    )
  })
  let exact = encoder.decode_exact([1.0e300, -1.0e300, 0.0, 0.0, 0.0, 0.0, 0.0])
  for value in exact.posterior_llr {
    assert_true(!value.is_nan() && !value.is_inf())
  }
}
