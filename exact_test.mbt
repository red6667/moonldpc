///|
test "bounded nearest word agrees with all Hamming single errors" {
  let code = @moonldpc.hamming7()
  let encoder = @moonldpc.Encoder::new(code)
  for mask in 0..<128 {
    let received = bits(mask, 7)
    let exact = encoder.nearest_word(received)
    assert_eq(exact.word, code.correct_single(received).word)
    assert_eq(exact.ties, 1)
    assert_eq(exact.examined, 16)
    assert_true(exact.distance <= 1)
  }
  let tie = @moonldpc.Encoder::new(@moonldpc.repetition_code(2)).nearest_word([
    1, 0,
  ])
  assert_eq(tie.word, None)
  assert_eq(tie.distance, 1)
  assert_eq(tie.ties, 2)
  rejects(() => {
    @moonldpc.Encoder::new(@moonldpc.ParityCheck::new(17, [[]])).nearest_word(
      Array::make(17, 0),
    )
  })
}
