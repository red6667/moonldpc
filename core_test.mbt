///|
fn close(
  a : Double,
  b : Double,
  tolerance~ : Double = 0.00000001,
) -> Unit raise {
  assert_true(
    (a - b).abs() <= tolerance,
    msg="numerical mismatch: \{a} vs \{b}",
  )
}

///|
fn[T] rejects(f : () -> T raise @moonldpc.CodeError) -> Unit raise {
  let result = f() catch { _ => return }
  ignore(result)
  fail("expected CodeError")
}

///|
fn bits(mask : Int32, n : Int32) -> Array[Int32] {
  Array::makei(n, fn(i) { (mask >> i) & 1 })
}

///|
test "Hamming exhaustive independent parity and systematic bijection" {
  let code = @moonldpc.hamming7()
  let encoder = @moonldpc.Encoder::new(code)
  assert_eq(encoder.rank(), 3)
  assert_eq(encoder.dimension(), 4)
  let mut valid = 0
  for mask in 0..<128 {
    let word = bits(mask, 7)
    let mut syndrome = 0
    for i in 0..<7 {
      if word[i] == 1 {
        syndrome = syndrome ^ (i + 1)
      }
    }
    assert_eq(code.is_codeword(word), syndrome == 0)
    if syndrome == 0 {
      valid += 1
      assert_eq(encoder.encode(encoder.extract(word)), word)
    }
    let checks = bits(syndrome, 3)
    assert_eq(code.syndrome(encoder.solve_syndrome(checks)), checks)
  }
  assert_eq(valid, 16)
  for mask in 0..<16 {
    let information = bits(mask, 4)
    assert_eq(encoder.extract(encoder.encode(information)), information)
  }
  let distance = encoder.distance_report()
  assert_eq(distance.minimum_distance, Some(3))
  assert_eq(distance.examined_nonzero_words, 15)
  assert_eq(distance.weight_distribution, [1, 0, 0, 7, 7, 0, 0, 1])
}

///|
test "rank deficient and zero dimensional codes are not silently changed" {
  let dependent = @moonldpc.Encoder::new(
    @moonldpc.ParityCheck::new(3, [[0, 1], [0, 1], []]),
  )
  assert_eq(dependent.rank(), 1)
  assert_eq(dependent.dimension(), 2)
  rejects(fn() raise @moonldpc.CodeError { dependent.solve_syndrome([0, 1, 0]) })
  rejects(fn() raise @moonldpc.CodeError { dependent.solve_syndrome([0, 0, 1]) })
  let full = @moonldpc.Encoder::new(@moonldpc.ParityCheck::new(2, [[0], [1]]))
  assert_eq(full.encode([]), [0, 0])
  assert_eq(full.distance_report().minimum_distance, None)
  let free = @moonldpc.Encoder::new(@moonldpc.ParityCheck::new(3, [[]]))
  assert_eq(free.encode([1, 0, 1]), [1, 0, 1])
  assert_eq(free.distance_report().minimum_distance, Some(1))
  close(full.rate(), 0.0)
  close(free.rate(), 1.0)
}

///|
test "ownership permutations direct sums and graph invariants" {
  let input = [[2, 0], [1, 2]]
  let code = @moonldpc.ParityCheck::new(4, input)
  input[0][0] = 3
  let row = code.check_variables(0)
  row[0] = 3
  assert_eq(code.check_variables(0), [0, 2])
  let col = code.variable_checks(2)
  col.clear()
  assert_eq(code.variable_checks(2), [0, 1])
  assert_eq(code.edge_endpoints(0), (0, 0))
  assert_eq(code.girth(), None)
  let graph = code.analyze()
  assert_eq(graph.components, 2)
  assert_eq(graph.isolated_variables, 1)
  let cycle4 = @moonldpc.ParityCheck::new(2, [[0, 1], [0, 1]])
  assert_eq(cycle4.girth(), Some(4))
  assert_eq(cycle4.analyze().four_cycles, 1L)
  let cycle6 = @moonldpc.ParityCheck::new(3, [[0, 1], [1, 2], [0, 2]])
  assert_eq(cycle6.girth(), Some(6))
  assert_eq(cycle6.analyze().four_cycles, 0L)
  let empty = @moonldpc.ParityCheck::new(2, [[], []]).analyze()
  assert_eq(empty.components, 4)
  assert_eq(empty.empty_checks, 2)
  let permutation = [3, 2, 0, 1]
  let permuted = code.permute(permutation)
  for mask in 0..<16 {
    let word = bits(mask, 4)
    assert_eq(
      code.syndrome(word),
      permuted.syndrome(permutation.map(fn(i) { word[i] })),
    )
  }
  let joined = code.direct_sum(cycle4)
  assert_eq(joined.variables(), 6)
  assert_eq(joined.analyze().components, 3)
}

///|
test "matrix and encoder reject invalid inputs and bounded work" {
  rejects(fn() raise @moonldpc.CodeError { @moonldpc.ParityCheck::new(0, [[]]) })
  rejects(fn() raise @moonldpc.CodeError { @moonldpc.ParityCheck::new(2, []) })
  rejects(fn() raise @moonldpc.CodeError {
    @moonldpc.ParityCheck::new(2, [[0, 0]])
  })
  rejects(fn() raise @moonldpc.CodeError {
    @moonldpc.ParityCheck::new(2, [[-1]])
  })
  rejects(fn() raise @moonldpc.CodeError {
    @moonldpc.ParityCheck::new(2, [[2]])
  })
  let code = @moonldpc.hamming7()
  rejects(fn() raise @moonldpc.CodeError { code.syndrome([0]) })
  rejects(fn() raise @moonldpc.CodeError {
    code.syndrome([0, 0, 0, 0, 0, 0, 2])
  })
  rejects(fn() raise @moonldpc.CodeError { code.check_variables(-1) })
  rejects(fn() raise @moonldpc.CodeError { code.variable_checks(7) })
  rejects(fn() raise @moonldpc.CodeError { code.edge_endpoints(100) })
  rejects(fn() raise @moonldpc.CodeError { code.permute([0, 0, 1, 2, 3, 4, 5]) })
  rejects(fn() raise @moonldpc.CodeError { code.permute([0]) })
  let encoder = @moonldpc.Encoder::new(code)
  rejects(fn() raise @moonldpc.CodeError { encoder.encode([0]) })
  rejects(fn() raise @moonldpc.CodeError {
    encoder.extract([1, 0, 0, 0, 0, 0, 0])
  })
  rejects(fn() raise @moonldpc.CodeError {
    @moonldpc.Encoder::new(@moonldpc.repetition_code(2049))
  })
  rejects(fn() raise @moonldpc.CodeError {
    @moonldpc.Encoder::new(@moonldpc.ParityCheck::new(21, [[]])).distance_report()
  })
  rejects(fn() raise @moonldpc.CodeError {
    @moonldpc.repetition_code(8192).girth()
  })
}

///|
test "BEC exhaustive masks retain evidence and never invent stopping-set bits" {
  let code = @moonldpc.hamming7()
  let encoder = @moonldpc.Encoder::new(code)
  for message in 0..<16 {
    let word = encoder.encode(bits(message, 4))
    for mask in 0..<128 {
      let observations = Array::makei(7, fn(i) {
        if (mask & (1 << i)) == 0 {
          Some(word[i])
        } else {
          None
        }
      })
      let result = code.peel(observations)
      for i in 0..<7 {
        if result.values[i] is Some(bit) {
          assert_eq(bit, word[i])
        }
        assert_eq(
          observations[i],
          if (mask & (1 << i)) == 0 {
            Some(word[i])
          } else {
            None
          },
        )
      }
      assert_eq(result.complete, result.unresolved.is_empty())
      assert_eq(
        result.recovered + result.unresolved.length(),
        bits(mask, 7).fold(init=0, fn(a, b) { a + b }),
      )
    }
  }
  let chain = @moonldpc.repetition_code(5)
  assert_eq(chain.peel([None, None, Some(1), None, None]).values, [
    Some(1),
    Some(1),
    Some(1),
    Some(1),
    Some(1),
  ])
  assert_eq(chain.peel([None, None, None, None, None]).unresolved.length(), 5)
  rejects(fn() raise @moonldpc.CodeError {
    chain.peel([Some(0), None, None, None, Some(1)])
  })
  rejects(fn() raise @moonldpc.CodeError {
    chain.peel([Some(2), None, None, None, None])
  })
  rejects(fn() raise @moonldpc.CodeError { chain.peel([]) })
}

///|
test "alist roundtrip preserves exact sparse matrix including empty sections" {
  for
    code in [
      @moonldpc.hamming7(),
      @moonldpc.repetition_code(9),
      @moonldpc.ParityCheck::new(4, [[], []]),
      @moonldpc.ParityCheck::new(4, [[0], [], [2, 3]]),
    ] {
    let text = code.to_alist()
    let restored = @moonldpc.parse_alist(text)
    assert_eq(restored.to_alist(), text)
    assert_eq(restored.variables(), code.variables())
    for c in 0..<code.checks() {
      assert_eq(restored.check_variables(c), code.check_variables(c))
    }
  }
  rejects(fn() raise @moonldpc.CodeError {
    @moonldpc.parse_alist("2 1 1 2 1 1 2 1 1 1 1")
  }) // duplicate row neighbor
  rejects(fn() raise @moonldpc.CodeError {
    @moonldpc.parse_alist("2 1 1 2 1 1 2 1 1 1 2 99")
  }) // trailing token
  rejects(fn() raise @moonldpc.CodeError {
    @moonldpc.parse_alist("2 1 1 2 1 0 1 1 1 1 0")
  }) // nonzero padding
  rejects(fn() raise @moonldpc.CodeError { @moonldpc.parse_alist("-1 0") })
  rejects(fn() raise @moonldpc.CodeError { @moonldpc.parse_alist("1000001") })
  let qc = @moonldpc.lift_qc([[0, 1, -1], [-1, 0, 2]], 3)
  assert_eq(qc.variables(), 9)
  assert_eq(qc.checks(), 6)
  assert_eq(qc.check_variables(0), [0, 4])
  assert_eq(qc.check_variables(2), [2, 3])
  assert_eq(qc.check_variables(3), [3, 8])
  rejects(fn() raise @moonldpc.CodeError { @moonldpc.lift_qc([[3]], 3) })
  rejects(fn() raise @moonldpc.CodeError { @moonldpc.lift_qc([[0], [0, 1]], 3) })
  rejects(fn() raise @moonldpc.CodeError { @moonldpc.lift_qc([[0]], 0) })
}

///|
test "channels rates repetitions cancellation and independent counters" {
  assert_eq(@moonldpc.bpsk([0, 1]), [1.0, -1.0])
  assert_eq(@moonldpc.awgn_llr([0.5, -1.0, 1000.0], 0.5), [2.0, -4.0, 50.0])
  let bsc = @moonldpc.bsc_llr([0, 1], 0.1)
  close(bsc[0], @math.ln(9.0))
  close(bsc[1], -@math.ln(9.0))
  assert_eq(@moonldpc.bec_llr([None, Some(0), Some(1)]), [0.0, 50.0, -50.0])
  let positions = [0, 0, 0, 1]
  let plan = @moonldpc.RatePlan::new(4, positions, shortened=[(3, 1)])
  positions[0] = 2
  assert_eq(plan.restore_llr([50.0, 50.0, -50.0, 2.0]), [50.0, 2.0, 0.0, -50.0])
  assert_eq(plan.project([1, 0, 1, 1]), [1, 1, 1, 0])
  assert_eq(plan.punctured_positions(), [2])
  assert_eq(plan.observation_count(), 4)
  assert_true(!plan.accepts([0, 0, 0, 0]))
  rejects(fn() raise @moonldpc.CodeError { plan.project([0, 0, 0, 0]) })
  rejects(fn() raise @moonldpc.CodeError { plan.restore_llr([0.0]) })
  rejects(fn() raise @moonldpc.CodeError {
    @moonldpc.RatePlan::new(2, [1], shortened=[(1, 0)])
  })
  rejects(fn() raise @moonldpc.CodeError {
    @moonldpc.RatePlan::new(2, [], shortened=[(1, 0), (1, 1)])
  })
  rejects(fn() raise @moonldpc.CodeError { @moonldpc.awgn_llr([0.0], 0.0) })
  rejects(fn() raise @moonldpc.CodeError {
    @moonldpc.awgn_llr([1.0 / 0.0], 1.0)
  })
  rejects(fn() raise @moonldpc.CodeError { @moonldpc.bsc_llr([0], 0.5) })
  rejects(fn() raise @moonldpc.CodeError { @moonldpc.bec_llr([Some(-1)]) })
  let empty = @moonldpc.ErrorCounts::new()
  assert_eq(empty.bit_error_rate(), None)
  let count = empty.observe([0, 1], [1, 1], true).observe([0, 1], [0, 1], false)
  assert_eq(empty.frame_error_rate(), None)
  assert_eq(count.bit_error_rate(), Some(0.25))
  assert_eq(count.frame_error_rate(), Some(0.5))
  rejects(fn() raise @moonldpc.CodeError { empty.observe([0], [], true) })
}

///|
test "decoder termination constraints degree-one and numerical saturation" {
  let chain = @moonldpc.repetition_code(5)
  for
    algorithm in [
      @moonldpc.SumProduct,
      @moonldpc.MinSum,
      @moonldpc.LayeredMinSum,
    ] {
    let config = @moonldpc.DecoderConfig::new(algorithm)
    let result = chain.decode([4.0, 4.0, -0.2, 4.0, 4.0], config)
    assert_eq(result.word, [0, 0, 0, 0, 0])
    assert_true(result.converged)
    assert_eq(result.syndrome_weights.length(), result.iterations + 1)
    let stopped = chain.decode(
      [4.0, -1.0, 4.0, 4.0, 4.0],
      @moonldpc.DecoderConfig::new(algorithm, iterations=0),
    )
    assert_eq(stopped.iterations, 0)
    assert_true(!stopped.converged)
    let wrong = chain.decode([-4.0, -4.0, -4.0, -4.0, -4.0], config)
    assert_true(wrong.converged)
    assert_eq(wrong.iterations, 0) // valid word does not imply transmission correct
    let degree1 = @moonldpc.ParityCheck::new(1, [[0]]).decode([-1.0], config)
    assert_eq(degree1.word, [0])
  }
  rejects(fn() raise @moonldpc.CodeError {
    @moonldpc.DecoderConfig::new(@moonldpc.SumProduct, normalization=0.8)
  })
  rejects(fn() raise @moonldpc.CodeError {
    @moonldpc.DecoderConfig::new(@moonldpc.MinSum, iterations=-1)
  })
  rejects(fn() raise @moonldpc.CodeError {
    @moonldpc.DecoderConfig::new(@moonldpc.MinSum, offset=-1.0)
  })
  rejects(fn() raise @moonldpc.CodeError {
    chain.decode([0.0], @moonldpc.DecoderConfig::new(@moonldpc.SumProduct))
  })
  rejects(fn() raise @moonldpc.CodeError {
    chain.decode(
      [0.0, 0.0, 0.0, 0.0, 0.0 / 0.0],
      @moonldpc.DecoderConfig::new(@moonldpc.SumProduct),
    )
  })
  let flip = chain.bit_flip([0, 0, 1, 0, 0])
  assert_true(flip.converged)
  assert_eq(flip.word, [0, 0, 0, 0, 0])
  rejects(fn() raise @moonldpc.CodeError {
    chain.bit_flip([0, 0, 0, 0, 0], iterations=-1)
  })
}

///|
test "strict JSON protocol success and structured failures" {
  let request = "{\"action\":\"encode\",\"code\":{\"variables\":3,\"rows\":[[0,1],[1,2]]},\"information\":[1]}"
  let output = @json.parse(@moonldpc.execute(request))
  assert_true(output is Object(fields) && fields.get("ok") is Some(True))
  for
    bad in [
      "{", "[]", "null", "{\"action\":\"analyze\",\"action\":\"encode\"}", "{\"action\":\"a\",\"\\u0061ction\":\"b\"}",
      "{\"action\":\"analyze\",\"code\":{\"variables\":1,\"rows\":[[]]},\"extra\":0}",
      "{\"action\":\"analyze\",\"code\":{\"variables\":1.5,\"rows\":[[]]}}",
    ] {
    let result = @json.parse(@moonldpc.execute(bad))
    assert_true(result is Object(fields) && fields.get("ok") is Some(False))
  }
  let deep = StringBuilder()
  for _ in 0..<33 {
    deep.write_string("[")
  }
  deep.write_string("0")
  for _ in 0..<33 {
    deep.write_string("]")
  }
  assert_true(
    @json.parse(@moonldpc.execute(deep.to_string())) is Object(fields) &&
    fields.get("ok") is Some(False),
  )
}
