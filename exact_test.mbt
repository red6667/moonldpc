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

///|
test "exact posterior marginals match independent probability enumeration" {
  let code = @moonldpc.hamming7()
  let encoder = @moonldpc.Encoder::new(code)
  let llr = [1.1, -0.7, 0.2, 1.3, -0.4, 2.0, -0.1]
  let exact = encoder.decode_exact(llr)
  let zero = Array::make(7, 0.0)
  let one = Array::make(7, 0.0)
  let probabilities = @moonldpc.bit_one_probabilities(llr)
  for mask in 0..<128 {
    let word = bits(mask, 7)
    if !code.is_codeword(word) {
      continue
    }
    let mut weight = 1.0
    for i, bit in word {
      weight *= if bit == 1 { probabilities[i] } else { 1.0 - probabilities[i] }
    }
    for i, bit in word {
      if bit == 0 {
        zero[i] += weight
      } else {
        one[i] += weight
      }
    }
  }
  for i in 0..<7 {
    close(exact.posterior_llr[i], @math.ln(zero[i] / one[i]))
  }
  assert_true(code.is_codeword(exact.word))
  let rep = @moonldpc.Encoder::new(@moonldpc.repetition_code(3)).decode_exact([
    1.0, -0.5, 2.0,
  ])
  for value in rep.posterior_llr {
    close(value, 2.5)
  }
  assert_eq(encoder.decode_exact(Array::make(7, 0.0)).ties, 16)
  let fixed = @moonldpc.Encoder::new(@moonldpc.ParityCheck::new(1, [[0]])).decode_exact([
      0.0,
    ],
  )
  assert_eq(fixed.posterior_llr, [50.0])
  rejects(() => encoder.decode_exact([1.0 / 0.0]))
}
