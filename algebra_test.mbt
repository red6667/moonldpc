///|
test "dense interchange round trip validates shape and owns data" {
  let dense = [[1, 0, 1], [0, 1, 1]]
  let code = @moonldpc.ParityCheck::from_dense(dense)
  dense[0][0] = 0
  assert_eq(code.to_dense(), [[1, 0, 1], [0, 1, 1]])
  let exported = code.to_dense()
  exported[0][0] = 0
  assert_eq(code.check_variables(0), [0, 2])
  rejects(() => @moonldpc.ParityCheck::from_dense([]))
  rejects(() => @moonldpc.ParityCheck::from_dense([[1], [0, 1]]))
  rejects(() => @moonldpc.ParityCheck::from_dense([[2]]))
  rejects(() => {
    @moonldpc.ParityCheck::new(65536, Array::makei(17, fn(_) { [] })).to_dense()
  })
}

///|
test "dual orthogonality and bidual membership exhaustively" {
  let code = @moonldpc.hamming7()
  let dual = code.dual()
  assert_eq(@moonldpc.Encoder::new(dual).dimension(), 3)
  let bidual = dual.dual()
  for mask in 0..<128 {
    assert_eq(
      code.is_codeword(bits(mask, 7)),
      bidual.is_codeword(bits(mask, 7)),
    )
  }
  for a in @moonldpc.Encoder::new(code).generator() {
    for b in @moonldpc.Encoder::new(dual).generator() {
      let mut dot = 0
      for i in 0..<7 {
        dot = dot ^ (a[i] & b[i])
      }
      assert_eq(dot, 0)
    }
  }
  let zero = @moonldpc.ParityCheck::new(2, [[0], [1]])
  assert_eq(@moonldpc.Encoder::new(zero.dual()).dimension(), 2)
}

///|
test "Hamming overall parity extension has distance four" {
  let code = @moonldpc.hamming7()
  let extended = code.extend_even_parity()
  let enc = @moonldpc.Encoder::new(extended)
  assert_eq(enc.dimension(), 4)
  assert_eq(enc.distance_report().minimum_distance, Some(4))
  let original = @moonldpc.Encoder::new(code)
  for mask in 0..<16 {
    let word = original.encode(bits(mask, 4))
    let mut parity = 0
    for bit in word {
      parity = parity ^ bit
    }
    word.push(parity)
    assert_true(extended.is_codeword(word))
  }
  rejects(() => @moonldpc.ParityCheck::new(65536, [[]]).extend_even_parity())
}

///|
test "affine encoding enumerates each Hamming syndrome coset" {
  let code = @moonldpc.hamming7()
  for syndrome in 0..<8 {
    let target = bits(syndrome, 3)
    let coset = @moonldpc.CosetEncoder::new(code, target)
    assert_eq(coset.dimension(), 4)
    target[0] = target[0] ^ 1
    for mask in 0..<16 {
      let info = bits(mask, 4)
      let word = coset.encode(info)
      assert_eq(code.syndrome(word), bits(syndrome, 3))
      assert_eq(coset.extract(word), info)
    }
  }
  rejects(() => {
    @moonldpc.CosetEncoder::new(@moonldpc.ParityCheck::new(2, [[0], [0]]), [
      0, 1,
    ])
  })
  rejects(() => {
    @moonldpc.CosetEncoder::new(code, [1, 0, 0]).extract(Array::make(7, 0))
  })
}
