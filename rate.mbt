///|
/// Explicit coordinate map. Unlisted coordinates are punctured (zero LLR).
/// Repeated transmitted coordinates are independent observations combined by LLR sum.
pub struct RatePlan {
  priv n : Int
  priv transmitted : Array[Int]
  priv shortened : Array[(Int, Int)]
} derive(Debug)

///|
pub fn RatePlan::new(
  variables : Int,
  transmitted : Array[Int],
  shortened? : Array[(Int, Int)] = [],
) -> RatePlan raise CodeError {
  if variables <= 0 || variables > 65536 {
    raise InvalidDimensions("rate-plan variables")
  }
  if transmitted.length() > 1000000 {
    raise ResourceLimit("transmitted observations")
  }
  let known = Array::make(variables, -1)
  for (v, bit) in shortened {
    if v < 0 || v >= variables {
      raise InvalidIndex(-1, v)
    }
    if bit != 0 && bit != 1 {
      raise InvalidBit(v, bit)
    }
    if known[v] != -1 {
      raise DuplicateEntry(-1, v)
    }
    known[v] = bit
  }
  for v in transmitted {
    if v < 0 || v >= variables {
      raise InvalidIndex(-1, v)
    }
    if known[v] != -1 {
      raise Inconsistent("shortened coordinate cannot also be transmitted")
    }
  }
  {
    n: variables,
    transmitted: transmitted.copy(),
    shortened: shortened.copy(),
  }
}

///|
pub fn RatePlan::observation_count(self : RatePlan) -> Int {
  self.transmitted.length()
}

///|
pub fn RatePlan::punctured_positions(self : RatePlan) -> Array[Int] {
  let present = Array::make(self.n, false)
  for v in self.transmitted {
    present[v] = true
  }
  for (v, _) in self.shortened {
    present[v] = true
  }
  let result : Array[Int] = []
  for v in 0..<self.n {
    if !present[v] {
      result.push(v)
    }
  }
  result
}

///|
/// Projection checks the shortening assertion, but does not itself validate H*word.
pub fn RatePlan::project(
  self : RatePlan,
  word : Array[Int],
) -> Array[Int] raise CodeError {
  ensure_bits(word, self.n)
  for (v, bit) in self.shortened {
    if word[v] != bit {
      raise Inconsistent("word disagrees with shortening")
    }
  }
  self.transmitted.map(fn(v) { word[v] })
}

///|
/// Each input observation is bounded before combining. Summation clips only once
/// after all observations, preserving cancellation for mixed-sign repetitions.
pub fn RatePlan::restore_llr(
  self : RatePlan,
  observations : Array[Double],
  limit? : Double = 50.0,
) -> Array[Double] raise CodeError {
  if observations.length() != self.transmitted.length() {
    raise LengthMismatch(self.transmitted.length(), observations.length())
  }
  validate_limit(limit)
  let values = Array::make(self.n, 0.0)
  let correction = Array::make(self.n, 0.0)
  for i, value in observations {
    if !finite(value) {
      raise InvalidNumber("nonfinite rate-matched LLR")
    }
    let v = self.transmitted[i]
    let adjusted = clamp(value, limit) - correction[v]
    let next = values[v] + adjusted
    correction[v] = next - values[v] - adjusted
    values[v] = next
  }
  for v in 0..<self.n {
    values[v] = clamp(values[v], limit)
  }
  for (v, bit) in self.shortened {
    values[v] = if bit == 0 { limit } else { -limit }
  }
  values
}

///|
/// A finite shortening prior is not a hard decoder constraint; verify afterwards.
pub fn RatePlan::accepts(
  self : RatePlan,
  word : Array[Int],
) -> Bool raise CodeError {
  ensure_bits(word, self.n)
  self.shortened.all(fn(pair) { word[pair.0] == pair.1 })
}

///|
pub extend RatePlan with @debug.Debug::{to_repr}

///|
/// Restore BEC observations; repeated known observations must agree.
/// Punctured coordinates remain erased, while shortened coordinates are exact.
pub fn RatePlan::restore_bec(
  self : RatePlan,
  observations : Array[Int?],
) -> Array[Int?] raise CodeError {
  if observations.length() != self.transmitted.length() {
    raise LengthMismatch(self.transmitted.length(), observations.length())
  }
  let values : Array[Int?] = Array::make(self.n, None)
  for i, observation in observations {
    match observation {
      None => ()
      Some(bit) => {
        if bit != 0 && bit != 1 {
          raise InvalidBit(i, bit)
        }
        let v = self.transmitted[i]
        match values[v] {
          Some(previous) =>
            if previous != bit {
              raise Inconsistent("conflicting repeated BEC observations")
            }
          None => values[v] = Some(bit)
        }
      }
    }
  }
  for (v, bit) in self.shortened {
    values[v] = Some(bit)
  }
  values
}
