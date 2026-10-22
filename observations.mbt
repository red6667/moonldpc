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
