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

///|
test "per sample noise calibration agrees with scalar demapping" {
  assert_eq(@moonldpc.awgn_llr_per_sample([1.0, -2.0, 1.0], [2.0, 0.5, 0.01]), [
    1.0, -8.0, 50.0,
  ])
  assert_eq(
    @moonldpc.awgn_llr_per_sample([0.25, -2.0], [0.5, 0.5]),
    @moonldpc.awgn_llr([0.25, -2.0], 0.5),
  )
  rejects(() => @moonldpc.awgn_llr_per_sample([1.0], []))
  rejects(() => @moonldpc.awgn_llr_per_sample([1.0], [0.0]))
  rejects(() => @moonldpc.awgn_llr_per_sample([1.0], [0.0 / 0.0]))
}

///|
test "immutable shard statistics merge matches serial aggregation" {
  let empty = @moonldpc.ErrorCounts::new()
  let first = empty.observe([0, 1], [0, 0], false)
  let second = empty.observe([1, 1], [1, 1], true)
  let merged = first.merge(second)
  assert_eq(merged.to_json(), first.observe([1, 1], [1, 1], true).to_json())
  assert_eq(merged.nonconvergence_rate(), Some(0.5))
  assert_eq(empty.nonconvergence_rate(), None)
  assert_eq(first.merge(empty).to_json(), first.to_json())
  let mut huge = second
  for _ in 0..<39 {
    huge = huge.merge(huge)
  }
  rejects(() => huge.merge(huge))
}
