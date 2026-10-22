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
