///|
pub struct StoppingReport {
  variables : Array[Int]
  singleton_checks : Array[Int]
  is_stopping_set : Bool
} derive(Debug, ToJson)

///|
/// A stopping set has no check touching exactly one selected variable.
/// The empty set qualifies vacuously; it is not a nontrivial decoding failure.
pub fn ParityCheck::stopping_set_report(
  self : ParityCheck,
  variables : Array[Int],
) -> StoppingReport raise CodeError {
  let selected = Array::make(self.n, false)
  for v in variables {
    if v < 0 || v >= self.n {
      raise InvalidIndex(-1, v)
    }
    if selected[v] {
      raise DuplicateEntry(-1, v)
    }
    selected[v] = true
  }
  let singleton_checks : Array[Int] = []
  for c, row in self.rows {
    let mut degree = 0
    for v in row {
      if selected[v] {
        degree += 1
      }
    }
    if degree == 1 {
      singleton_checks.push(c)
    }
  }
  let owned = variables.copy()
  owned.sort()
  {
    variables: owned,
    singleton_checks,
    is_stopping_set: singleton_checks.is_empty(),
  }
}

///|
pub extend StoppingReport with @debug.Debug::{to_repr}

///|
pub extend StoppingReport with ToJson::{to_json}

///|
pub struct SingleErrorReport {
  word : Array[Int]?
  candidates : Array[Int]
  syndrome : Array[Int]
  unchanged : Bool
} derive(Debug, ToJson)

///|
/// Sparse unique one-bit correction. This assumes at most one channel error;
/// a legal result does not certify the assumption. Ambiguous columns are not guessed.
pub fn ParityCheck::correct_single(
  self : ParityCheck,
  received : Array[Int],
) -> SingleErrorReport raise CodeError {
  let syndrome = self.syndrome(received)
  let active : Array[Int] = []
  for c, bit in syndrome {
    if bit == 1 {
      active.push(c)
    }
  }
  if active.is_empty() {
    return {
      word: Some(received.copy()),
      candidates: [],
      syndrome,
      unchanged: true,
    }
  }
  let candidates : Array[Int] = []
  for v in self.rows[active[0]] {
    if self.columns[v] == active {
      candidates.push(v)
    }
  }
  let word = if candidates.length() == 1 {
    let corrected = received.copy()
    corrected[candidates[0]] = corrected[candidates[0]] ^ 1
    Some(corrected)
  } else {
    None
  }
  { word, candidates, syndrome, unchanged: false, }
}

///|
pub extend SingleErrorReport with @debug.Debug::{to_repr}

///|
pub extend SingleErrorReport with ToJson::{to_json}
