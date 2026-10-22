///|
test "validated hard decisions and Hamming metric" {
  assert_eq(@moonldpc.decide([0.0, -0.0, 2.0, -3.0]), [0, 0, 0, 1])
  assert_eq(@moonldpc.bit_distance([1, 0, 1], [0, 0, 0]), 2)
  assert_eq(@moonldpc.bit_distance([], []), 0)
  rejects(() => @moonldpc.bit_distance([2], [0]))
  rejects(() => @moonldpc.bit_distance([0], []))
  rejects(() => @moonldpc.decide([0.0 / 0.0]))
}
