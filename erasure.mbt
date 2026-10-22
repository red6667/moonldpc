///|
pub struct ErasureReport {
  values : Array[Int32?]
  recovered : Int32
  unresolved : Array[Int32]
  complete : Bool
} derive(Debug)

///|
/// Queue-based BEC peeling; None is an erasure, not a guessed zero.
/// A stopping set is returned explicitly. Contradictory known observations raise.
pub fn ParityCheck::peel(
  self : ParityCheck,
  observations : Array[Int32?],
) -> ErasureReport raise CodeError {
  if observations.length() != self.n {
    raise LengthMismatch(self.n, observations.length())
  }
  let values = observations.copy()
  for i, value in values {
    match value {
      Some(bit) => if bit != 0 && bit != 1 { raise InvalidBit(i, bit) }
      None => ()
    }
  }
  let unknown = Array::make(self.checks(), 0)
  let parity = Array::make(self.checks(), 0)
  let queue : Array[Int32] = []
  for c, row in self.rows {
    for v in row {
      match values[v] {
        Some(bit) => parity[c] = parity[c] ^ bit
        None => unknown[c] += 1
      }
    }
    if unknown[c] == 0 && parity[c] != 0 {
      raise Inconsistent("known bits violate a check")
    }
    if unknown[c] == 1 {
      queue.push(c)
    }
  }
  let mut recovered = 0
  let mut head = 0
  while head < queue.length() {
    let c = queue[head]
    head += 1
    if unknown[c] != 1 {
      continue
    }
    let mut target = -1
    for v in self.rows[c] {
      if values[v] is None {
        target = v
        break
      }
    }
    if target < 0 {
      raise Inconsistent("peeling bookkeeping")
    }
    let bit = parity[c]
    values[target] = Some(bit)
    recovered += 1
    for check in self.columns[target] {
      parity[check] = parity[check] ^ bit
      unknown[check] -= 1
      if unknown[check] == 0 && parity[check] != 0 {
        raise Inconsistent("recovered bits contradict another check")
      }
      if unknown[check] == 1 {
        queue.push(check)
      }
    }
  }
  let unresolved : Array[Int32] = []
  for v, value in values {
    if value is None {
      unresolved.push(v)
    }
  }
  { values, recovered, unresolved, complete: unresolved.is_empty(), }
}

///|
pub struct BitFlipReport {
  word : Array[Int32]
  converged : Bool
  iterations : Int32
  syndrome_weights : Array[Int32]
} derive(Debug, ToJson)

///|
/// Parallel strict-majority bit flipping. Useful as a hard-decision baseline only.
/// A flip requires more unsatisfied than satisfied incident checks; ties do not flip.
pub fn ParityCheck::bit_flip(
  self : ParityCheck,
  received : Array[Int32],
  iterations~ : Int32 = 50,
) -> BitFlipReport raise CodeError {
  ensure_bits(received, self.n)
  if iterations < 0 || iterations > 10000 {
    raise InvalidNumber("bit-flip iterations")
  }
  if iterations.to_int64() * self.edges().to_int64() > 50000000L {
    raise ResourceLimit("bit-flip edge-iterations")
  }
  let word = received.copy()
  let weights = [self.syndrome_weight(word)]
  let mut completed = 0
  if weights[0] != 0 {
    for step in 1..<=iterations {
      let bad = Array::make(self.n, 0)
      for row in self.rows {
        let mut bit = 0
        for v in row {
          bit = bit ^ word[v]
        }
        if bit == 1 {
          for v in row {
            bad[v] += 1
          }
        }
      }
      let mut flips = 0
      for v in 0..<self.n {
        if bad[v] * 2 > self.columns[v].length() {
          word[v] = 1 - word[v]
          flips += 1
        }
      }
      completed = step
      let weight = self.syndrome_weight(word)
      weights.push(weight)
      if weight == 0 || flips == 0 {
        break
      }
    }
  }
  {
    word,
    converged: weights[weights.length() - 1] == 0,
    iterations: completed,
    syndrome_weights: weights,
  }
}

///|
pub extend ErasureReport with @debug.Debug::{to_repr}

///|
pub extend ErasureReport with ToJson::{to_json}

///|
pub extend BitFlipReport with @debug.Debug::{to_repr}

///|
pub extend BitFlipReport with ToJson::{to_json}

///|
/// JSON erasures are null, known bits are numbers (not generic Option arrays).
pub impl ToJson for ErasureReport with fn to_json(self) {
  let values = self.values.map(fn(value) {
    match value {
      None => Json::null()
      Some(bit) => Json(bit)
    }
  })
  {
    "values": Json(values),
    "recovered": self.recovered,
    "unresolved": Json(self.unresolved),
    "complete": self.complete,
  }
}
