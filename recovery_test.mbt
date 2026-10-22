///|
test "exact affine recovery versus all 3^7 ternary Hamming observations" {
  let code = @moonldpc.hamming7()
  let encoder = @moonldpc.Encoder::new(code)
  let words = Array::makei(16, fn(i) raise { encoder.encode(bits(i, 4)) })
  for pattern in 0..<2187 {
    let mut remaining = pattern
    let observations : Array[Int?] = []
    for _ in 0..<7 {
      let digit = remaining % 3
      remaining /= 3
      observations.push(if digit == 2 { None } else { Some(digit) })
    }
    let compatible = words.filter(fn(word) {
      let mut valid = true
      for i in 0..<7 {
        if observations[i] is Some(bit) && bit != word[i] {
          valid = false
        }
      }
      valid
    })
    if compatible.is_empty() {
      rejects(fn() raise @moonldpc.CodeError {
        code.recover_erasures(observations)
      })
    } else {
      let result = code.recover_erasures(observations)
      assert_eq(1 << result.ambiguity_dimension, compatible.length())
      assert_eq(result.unique, compatible.length() == 1)
      assert_true(compatible.contains(result.particular_word))
      let mut newly_known = 0
      let mut unresolved = 0
      for v in 0..<7 {
        let forced = compatible.all(fn(word) { word[v] == compatible[0][v] })
        assert_eq(
          result.values[v],
          if forced {
            Some(compatible[0][v])
          } else {
            None
          },
        )
        if !forced {
          unresolved += 1
        }
        if forced && observations[v] is None {
          newly_known += 1
        }
      }
      assert_eq(result.recovered, newly_known)
      assert_eq(result.unresolved.length(), unresolved)
    }
  }
}

///|
test "Gaussian fallback resolves a peeling stopping set without claiming all sets unique" {
  let code = @moonldpc.ParityCheck::new(3, [[0, 1], [1, 2], [0, 1, 2]])
  assert_eq(code.peel([None, None, None]).unresolved.length(), 3)
  let result = code.recover_erasures([None, None, None])
  assert_true(result.unique)
  assert_eq(result.values, [Some(0), Some(0), Some(0)])
  let partial = @moonldpc.ParityCheck::new(3, [[0], [1, 2]]).recover_erasures([
    None,
    None,
    None,
  ])
  assert_eq(partial.values, [Some(0), None, None])
  assert_eq(partial.ambiguity_dimension, 1)
  assert_true(!partial.unique)
  rejects(fn() raise @moonldpc.CodeError {
    code.recover_erasures([Some(2), None, None])
  })
  rejects(fn() raise @moonldpc.CodeError { code.recover_erasures([]) })
}

///|
test "puncturing equals set projection for all 127 proper Hamming coordinate subsets" {
  let original = @moonldpc.hamming7()
  let encoder = @moonldpc.Encoder::new(original)
  for mask in 0..<127 {
    let removed : Array[Int] = []
    let retained : Array[Int] = []
    for v in 0..<7 {
      if ((mask >> v) & 1) == 1 {
        removed.push(v)
      } else {
        retained.push(v)
      }
    }
    let projected = original.puncture(removed)
    let possible : Array[Array[Int]] = []
    for information in 0..<16 {
      let word = encoder.encode(bits(information, 4))
      let shortened = retained.map(fn(v) { word[v] })
      if !possible.contains(shortened) {
        possible.push(shortened)
      }
    }
    for candidate in 0..<(1 << retained.length()) {
      let word = bits(candidate, retained.length())
      assert_eq(projected.is_codeword(word), possible.contains(word))
    }
  }
  let pair = @moonldpc.ParityCheck::new(2, [[0, 1]])
  assert_eq(pair.puncture([0]).check_variables(0), []) // truncating row would be wrong
  rejects(fn() raise @moonldpc.CodeError { pair.puncture([0, 1]) })
  rejects(fn() raise @moonldpc.CodeError { pair.puncture([0, 0]) })
  rejects(fn() raise @moonldpc.CodeError { pair.puncture([2]) })
}
