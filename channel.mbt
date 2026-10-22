///|
/// BPSK mapping: 0 -> +1, 1 -> -1.
pub fn bpsk(word : Array[Int32]) -> Array[Double] raise CodeError {
  ensure_bits(word, word.length())
  word.map(fn(bit) { if bit == 0 { 1.0 } else { -1.0 } })
}

///|
/// AWGN LLR uses noise variance sigma^2 per real sample, NOT Eb/N0.
/// Caller supplies received real samples; this function does not generate noise.
pub fn awgn_llr(
  samples : Array[Double],
  variance : Double,
  limit~ : Double = 50.0,
) -> Array[Double] raise CodeError {
  if !finite(variance) || variance <= 0.0 {
    raise InvalidNumber("positive finite noise variance")
  }
  validate_limit(limit)
  let result : Array[Double] = []
  for sample in samples {
    if !finite(sample) {
      raise InvalidNumber("nonfinite received sample")
    }
    // Divide before multiply; overflow simply saturates to the documented finite bound.
    result.push(clamp(sample / variance * 2.0, limit))
  }
  result
}

///|
fn validate_limit(limit : Double) -> Unit raise CodeError {
  if !finite(limit) || limit < 1.0 || limit > 100.0 {
    raise InvalidNumber("LLR limit 1..100")
  }
}

///|
/// BSC crossover probability must lie strictly between zero and one half.
pub fn bsc_llr(
  received : Array[Int32],
  crossover : Double,
  limit~ : Double = 50.0,
) -> Array[Double] raise CodeError {
  ensure_bits(received, received.length())
  if !finite(crossover) || crossover <= 0.0 || crossover >= 0.5 {
    raise InvalidNumber("BSC crossover in (0,0.5)")
  }
  validate_limit(limit)
  let magnitude = clamp(@math.ln_1p(-crossover) - @math.ln(crossover), limit)
  received.map(fn(bit) { if bit == 0 { magnitude } else { -magnitude } })
}

///|
/// BEC -> soft observations; an erasure has exactly zero LLR.
pub fn bec_llr(
  observations : Array[Int32?],
  limit~ : Double = 50.0,
) -> Array[Double] raise CodeError {
  validate_limit(limit)
  let result : Array[Double] = []
  for i, value in observations {
    match value {
      None => result.push(0.0)
      Some(0) => result.push(limit)
      Some(1) => result.push(-limit)
      Some(bit) => raise InvalidBit(i, bit)
    }
  }
  result
}

///|
pub struct ErrorCounts {
  priv frames : Int64
  priv frame_errors : Int64
  priv bits : Int64
  priv bit_errors : Int64
  priv nonconverged : Int64
} derive(Debug, ToJson)

///|
pub fn ErrorCounts::new() -> ErrorCounts {
  { frames: 0L, frame_errors: 0L, bits: 0L, bit_errors: 0L, nonconverged: 0L, }
}

///|
/// Pure aggregation: each result is a new value, no aliasing or partial mutation on error.
pub fn ErrorCounts::observe(
  self : ErrorCounts,
  transmitted : Array[Int32],
  decoded : Array[Int32],
  converged : Bool,
) -> ErrorCounts raise CodeError {
  ensure_bits(transmitted, transmitted.length())
  ensure_bits(decoded, transmitted.length())
  if self.frames >= 1000000000000L ||
    self.bits > 1000000000000000L - transmitted.length().to_int64() {
    raise ResourceLimit("error counter capacity")
  }
  let mut errors = 0L
  for i, bit in transmitted {
    if bit != decoded[i] {
      errors += 1L
    }
  }
  {
    frames: self.frames + 1L,
    frame_errors: self.frame_errors + (if errors > 0L { 1L } else { 0L }),
    bits: self.bits + transmitted.length().to_int64(),
    bit_errors: self.bit_errors + errors,
    nonconverged: self.nonconverged + (if converged { 0L } else { 1L }),
  }
}

///|
pub fn ErrorCounts::bit_error_rate(self : ErrorCounts) -> Double? {
  if self.bits == 0L {
    None
  } else {
    Some(self.bit_errors.to_double() / self.bits.to_double())
  }
}

///|
pub fn ErrorCounts::frame_error_rate(self : ErrorCounts) -> Double? {
  if self.frames == 0L {
    None
  } else {
    Some(self.frame_errors.to_double() / self.frames.to_double())
  }
}

///|
pub extend ErrorCounts with @debug.Debug::{to_repr}

///|
pub extend ErrorCounts with ToJson::{to_json}

///|
/// Heteroscedastic real AWGN demapping. Each sample has its own noise variance.
pub fn awgn_llr_per_sample(
  samples : Array[Double],
  variances : Array[Double],
  limit~ : Double = 50.0,
) -> Array[Double] raise CodeError {
  if samples.length() != variances.length() {
    raise LengthMismatch(samples.length(), variances.length())
  }
  validate_limit(limit)
  let result : Array[Double] = []
  for i, sample in samples {
    let variance = variances[i]
    if !finite(sample) || !finite(variance) || variance <= 0.0 {
      raise InvalidNumber("finite sample and positive finite variance")
    }
    result.push(clamp(sample / variance * 2.0, limit))
  }
  result
}

///|
/// Merge independent simulation shards without sharing mutable counters.
pub fn ErrorCounts::merge(
  self : ErrorCounts,
  other : ErrorCounts,
) -> ErrorCounts raise CodeError {
  if self.frames > 1000000000000L - other.frames ||
    self.bits > 1000000000000000L - other.bits {
    raise ResourceLimit("merged error counter capacity")
  }
  {
    frames: self.frames + other.frames,
    frame_errors: self.frame_errors + other.frame_errors,
    bits: self.bits + other.bits,
    bit_errors: self.bit_errors + other.bit_errors,
    nonconverged: self.nonconverged + other.nonconverged,
  }
}

///|
pub fn ErrorCounts::nonconvergence_rate(self : ErrorCounts) -> Double? {
  if self.frames == 0L {
    None
  } else {
    Some(self.nonconverged.to_double() / self.frames.to_double())
  }
}
