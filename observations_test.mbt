///|
test "validated hard decisions and Hamming metric" {
  assert_eq(@moonldpc.decide([0.0, -0.0, 2.0, -3.0]), [0, 0, 0, 1])
  assert_eq(@moonldpc.bit_distance([1, 0, 1], [0, 0, 0]), 2)
  assert_eq(@moonldpc.bit_distance([], []), 0)
  rejects(() => @moonldpc.bit_distance([2], [0]))
  rejects(() => @moonldpc.bit_distance([0], []))
  rejects(() => @moonldpc.decide([0.0 / 0.0]))
}

///|
test "stable logistic probability round trip and saturation" {
  let probabilities = [0.01, 0.25, 0.5, 0.75, 0.99]
  let actual = @moonldpc.bit_one_probabilities(
    @moonldpc.probabilities_to_llr(probabilities),
  )
  for i, value in actual {
    close(value, probabilities[i])
  }
  assert_eq(@moonldpc.probabilities_to_llr([0.0, 1.0]), [50.0, -50.0])
  assert_eq(@moonldpc.bit_one_probabilities([1000.0, -1000.0]), [0.0, 1.0])
  rejects(() => @moonldpc.probabilities_to_llr([-0.1]))
  rejects(() => @moonldpc.probabilities_to_llr([1.1]))
  rejects(() => @moonldpc.bit_one_probabilities([1.0 / 0.0]))
}
