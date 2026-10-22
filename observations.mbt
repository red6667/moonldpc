///|
/// Hard decisions use zero -> 0. Nonfinite channel inputs are rejected.
pub fn decide(llr : Array[Double]) -> Array[Int] raise CodeError {
  for value in llr {
    if !finite(value) {
      raise InvalidNumber("nonfinite decision LLR")
    }
  }
  hard_decision(llr)
}

///|
/// Hamming distance with strict binary and length validation.
pub fn bit_distance(
  left : Array[Int],
  right : Array[Int],
) -> Int raise CodeError {
  ensure_bits(left, left.length())
  ensure_bits(right, left.length())
  let mut distance = 0
  for i, bit in left {
    if bit != right[i] {
      distance += 1
    }
  }
  distance
}

///|
/// Stable logistic conversion; returns P(bit=1), including saturated finite LLRs.
pub fn bit_one_probabilities(
  llr : Array[Double],
) -> Array[Double] raise CodeError {
  let result : Array[Double] = []
  for value in llr {
    if !finite(value) {
      raise InvalidNumber("nonfinite probability LLR")
    }
    let e = @math.exp(-value.abs())
    result.push(if value >= 0.0 { e / (1.0 + e) } else { 1.0 / (1.0 + e) })
  }
  result
}

///|
/// Probabilities of bit one become log(P0/P1). Endpoints saturate at limit.
pub fn probabilities_to_llr(
  probabilities : Array[Double],
  limit? : Double = 50.0,
) -> Array[Double] raise CodeError {
  validate_limit(limit)
  let result : Array[Double] = []
  for p in probabilities {
    if !finite(p) || p < 0.0 || p > 1.0 {
      raise InvalidNumber("probability in [0,1]")
    }
    result.push(
      if p == 0.0 {
        limit
      } else if p == 1.0 {
        -limit
      } else {
        clamp(@math.ln_1p(-p) - @math.ln(p), limit)
      },
    )
  }
  result
}
