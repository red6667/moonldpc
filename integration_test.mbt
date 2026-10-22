///|
test "permutations preserve code membership and observation alignment" {
  let order = [6, 4, 2, 0, 5, 3, 1]
  let p = @moonldpc.Permutation::new(order)
  let code = @moonldpc.hamming7()
  let permuted = code.permute(order)
  order[0] = 0
  for mask in 0..<128 {
    let word = bits(mask, 7)
    assert_eq(code.is_codeword(word), permuted.is_codeword(p.apply(word)))
    assert_eq(p.inverse().apply(p.apply(word)), word)
    assert_eq(p.then(p.inverse()).apply(word), word)
  }
  assert_eq(@moonldpc.Permutation::new([1, 0]).apply([Some(1), None]), [
    None,
    Some(1),
  ])
  rejects(() => @moonldpc.Permutation::new([0, 0]))
  rejects(() => @moonldpc.Permutation::new([2]))
  rejects(() => p.apply([1.0]))
}
