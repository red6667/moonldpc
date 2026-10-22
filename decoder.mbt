///|
pub(all) enum Algorithm {
  SumProduct
  MinSum
  LayeredMinSum
} derive(Debug, Eq)

///|
pub struct DecoderConfig {
  priv iterations : Int32
  priv algorithm : Algorithm
  priv normalization : Double
  priv offset : Double
  priv llr_limit : Double
} derive(Debug)

///|
/// Min-sum uses sign*normalization*max(minimum-offset,0).
/// SumProduct ignores normalization/offset, and rejects non-default values.
pub fn DecoderConfig::new(
  algorithm : Algorithm,
  iterations~ : Int32 = 50,
  normalization~ : Double = 1.0,
  offset~ : Double = 0.0,
  llr_limit~ : Double = 50.0,
) -> DecoderConfig raise CodeError {
  if iterations < 0 || iterations > 10000 {
    raise InvalidNumber("iterations 0..10000")
  }
  if !finite(normalization) || normalization <= 0.0 || normalization > 1.0 {
    raise InvalidNumber("normalization in (0,1]")
  }
  if !finite(offset) || offset < 0.0 || offset > 100.0 {
    raise InvalidNumber("offset 0..100")
  }
  if !finite(llr_limit) || llr_limit < 1.0 || llr_limit > 100.0 {
    raise InvalidNumber("LLR limit 1..100")
  }
  if algorithm == SumProduct && (normalization != 1.0 || offset != 0.0) {
    raise InvalidNumber("sum-product has no min-sum correction")
  }
  { iterations, algorithm, normalization, offset, llr_limit, }
}

///|
pub struct DecodeReport {
  word : Array[Int32]
  posterior_llr : Array[Double]
  converged : Bool
  iterations : Int32
  syndrome_weights : Array[Int32]
} derive(Debug, ToJson)

///|
fn hard_decision(values : Array[Double]) -> Array[Int32] {
  values.map(fn(x) { if x < 0.0 { 1 } else { 0 } })
}

///|
/// Stable box-plus. exp arguments are nonpositive, so no overflow or tanh saturation.
fn box_plus(a : Double, b : Double) -> Double {
  if a.is_inf() {
    return b
  }
  if b.is_inf() {
    return a
  }
  let sign = if (a < 0.0) != (b < 0.0) { -1.0 } else { 1.0 }
  sign * a.abs().min(b.abs()) +
  @math.ln_1p(@math.exp(-(a + b).abs())) -
  @math.ln_1p(@math.exp(-(a - b).abs()))
}

///|
/// Check-to-variable extrinsic messages in O(degree), with exact degree-one semantics.
fn check_messages(
  values : Array[Double],
  config : DecoderConfig,
) -> Array[Double] {
  let d = values.length()
  if d == 0 {
    return []
  }
  if d == 1 {
    return [config.llr_limit]
  }
  if config.algorithm == SumProduct {
    let prefix = Array::make(d + 1, 1.0 / 0.0)
    let suffix = Array::make(d + 1, 1.0 / 0.0)
    for i in 0..<d {
      prefix[i + 1] = box_plus(prefix[i], values[i])
    }
    for i = d - 1; i >= 0; i = i - 1 {
      suffix[i] = box_plus(values[i], suffix[i + 1])
    }
    return Array::makei(d, fn(i) {
      clamp(box_plus(prefix[i], suffix[i + 1]), config.llr_limit)
    })
  }
  let mut negative = false
  let mut minimum = 1.0 / 0.0
  let mut second = 1.0 / 0.0
  let mut minimum_index = -1
  for i, value in values {
    if value < 0.0 {
      negative = !negative
    }
    let absolute = value.abs()
    if absolute < minimum {
      second = minimum
      minimum = absolute
      minimum_index = i
    } else if absolute < second {
      second = absolute
    }
  }
  Array::makei(d, fn(i) {
    let magnitude = if i == minimum_index { second } else { minimum }
    let corrected = config.normalization * (magnitude - config.offset).max(0.0)
    if negative != (values[i] < 0.0) {
      -corrected
    } else {
      corrected
    }
  })
}

///|
/// Positive LLR means bit zero. Convergence means H*word=0, not proof of transmission correctness.
pub fn ParityCheck::decode(
  self : ParityCheck,
  llr : Array[Double],
  config : DecoderConfig,
) -> DecodeReport raise CodeError {
  if llr.length() != self.n {
    raise LengthMismatch(self.n, llr.length())
  }
  for value in llr {
    if !finite(value) {
      raise InvalidNumber("nonfinite channel LLR")
    }
  }
  if self.edges().to_int64() * config.iterations.to_int64() > 50000000L {
    raise ResourceLimit("decoder edge-iteration budget")
  }
  let channel = llr.map(fn(x) { clamp(x, config.llr_limit) })
  // Posterior sums remain unclipped internally. Clipping before subtracting a previous
  // check message destroys extrinsic information, especially for layered decoding.
  let posterior = channel.copy()
  let incoming = self.edge_variables.map(fn(v) { channel[v] })
  let outgoing = Array::make(self.edges(), 0.0)
  let weights = [self.syndrome_weight(hard_decision(posterior))]
  if weights[0] == 0 || config.iterations == 0 {
    return {
      word: hard_decision(posterior),
      posterior_llr: posterior,
      converged: weights[0] == 0,
      iterations: 0,
      syndrome_weights: weights,
    }
  }
  let mut completed = 0
  for iteration in 1..<=config.iterations {
    if config.algorithm == LayeredMinSum {
      for edges in self.row_edges {
        let values = edges.map(fn(e) {
          clamp(
            posterior[self.edge_variables[e]] - outgoing[e],
            config.llr_limit,
          )
        })
        let messages = check_messages(values, config)
        for i, e in edges {
          let v = self.edge_variables[e]
          posterior[v] = posterior[v] - outgoing[e] + messages[i]
          outgoing[e] = messages[i]
        }
      }
    } else {
      for edges in self.row_edges {
        let values = edges.map(fn(e) { incoming[e] })
        let messages = check_messages(values, config)
        for i, e in edges {
          outgoing[e] = messages[i]
        }
      }
      for v in 0..<self.n {
        let mut sum = channel[v]
        for e in self.column_edges[v] {
          sum += outgoing[e]
        }
        posterior[v] = sum
        for e in self.column_edges[v] {
          incoming[e] = clamp(sum - outgoing[e], config.llr_limit)
        }
      }
    }
    completed = iteration
    let weight = self.syndrome_weight(hard_decision(posterior))
    weights.push(weight)
    if weight == 0 {
      break
    }
  }
  let word = hard_decision(posterior)
  {
    word,
    posterior_llr: posterior.map(fn(x) { clamp(x, config.llr_limit) }),
    converged: weights[weights.length() - 1] == 0,
    iterations: completed,
    syndrome_weights: weights,
  }
}

///|
pub extend Algorithm with @debug.Debug::{to_repr}

///|
pub extend Algorithm with Eq::{equal, not_equal}

///|
pub extend DecoderConfig with @debug.Debug::{to_repr}

///|
pub extend DecodeReport with @debug.Debug::{to_repr}

///|
pub extend DecodeReport with ToJson::{to_json}
