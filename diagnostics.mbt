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
