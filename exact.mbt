///|
fn Encoder::enumeration_count(self : Encoder) -> Int raise CodeError {
  let k = self.dimension()
  if k > 16 || self.code.n > 256 {
    raise ResourceLimit("exact decoder: dimension <=16 and length <=256")
  }
  let count = 1 << k
  if count.to_int64() * self.code.n.to_int64() * (k + 1).to_int64() > 20000000L {
    raise ResourceLimit("exact decoder work")
  }
  count
}

///|
pub struct NearestReport {
  word : Array[Int]?
  distance : Int
  ties : Int
  examined : Int
} derive(Debug, ToJson)

///|
/// Exhaustive nearest codeword for small codes, NOT a scalable LDPC decoder.
/// A tied minimum returns no word rather than silently choosing a correction.
pub fn Encoder::nearest_word(
  self : Encoder,
  received : Array[Int],
) -> NearestReport raise CodeError {
  ensure_bits(received, self.code.n)
  let count = self.enumeration_count()
  let mut best = self.code.n + 1
  let mut ties = 0
  let mut candidate : Array[Int]? = None
  for mask in 0..<count {
    let info = Array::makei(self.dimension(), fn(i) { (mask >> i) & 1 })
    let word = self.encode(info)
    let distance = bit_distance(word, received)
    if distance < best {
      best = distance
      ties = 1
      candidate = Some(word)
    } else if distance == best {
      ties += 1
      candidate = None
    }
  }
  { word: candidate, distance: best, ties, examined: count, }
}

///|
pub extend NearestReport with @debug.Debug::{to_repr}

///|
pub extend NearestReport with ToJson::{to_json}

///|
fn log_add(left : Double, right : Double) -> Double {
  if left.is_inf() && left < 0.0 {
    return right
  }
  if right.is_inf() && right < 0.0 {
    return left
  }
  left.max(right) + @math.ln_1p(@math.exp(-(left - right).abs()))
}

///|
pub struct ExactDecodeReport {
  word : Array[Int]
  posterior_llr : Array[Double]
  ties : Int
  examined : Int
} derive(Debug, ToJson)

///|
/// Exact sequence ML word and bitwise MAP marginals under a uniform codeword prior.
/// Input LLRs and output marginals saturate at limit; ties select the first information
/// mask deterministically. Bitwise posterior decisions need not form a codeword.
pub fn Encoder::decode_exact(
  self : Encoder,
  llr : Array[Double],
  limit? : Double = 50.0,
) -> ExactDecodeReport raise CodeError {
  if llr.length() != self.code.n {
    raise LengthMismatch(self.code.n, llr.length())
  }
  validate_limit(limit)
  for value in llr {
    if !finite(value) {
      raise InvalidNumber("nonfinite exact-decoder LLR")
    }
  }
  let values = llr.map(fn(x) { clamp(x, limit) })
  let count = self.enumeration_count()
  let negative_infinity = -1.0 / 0.0
  let zero = Array::make(self.code.n, negative_infinity)
  let one = Array::make(self.code.n, negative_infinity)
  let mut best = negative_infinity
  let mut best_word = Array::make(self.code.n, 0)
  let mut ties = 0
  for mask in 0..<count {
    let word = self.encode(
      Array::makei(self.dimension(), fn(i) { (mask >> i) & 1 }),
    )
    let mut weight = 0.0
    for i, bit in word {
      if bit == 1 {
        weight -= values[i]
      }
    }
    if weight > best {
      best = weight
      best_word = word
      ties = 1
    } else if weight == best {
      ties += 1
    }
    for i, bit in word {
      if bit == 0 {
        zero[i] = log_add(zero[i], weight)
      } else {
        one[i] = log_add(one[i], weight)
      }
    }
  }
  let posterior_llr = Array::makei(self.code.n, fn(i) {
    clamp(zero[i] - one[i], limit)
  })
  { word: best_word, posterior_llr, ties, examined: count, }
}

///|
pub extend ExactDecodeReport with @debug.Debug::{to_repr}

///|
pub extend ExactDecodeReport with ToJson::{to_json}
