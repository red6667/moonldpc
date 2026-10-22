///|
/// Exact affine erasure analysis. Only bits shared by every completion are marked
/// recovered; a particular valid completion is separate and is NOT evidence of uniqueness.
pub struct RecoveryReport {
  values : Array[Int?]
  recovered : Int
  unresolved : Array[Int]
  ambiguity_dimension : Int
  unique : Bool
  particular_word : Array[Int]
} derive(Debug)

///|
/// Gaussian fallback for BEC stopping sets. This uses dense GF(2), unlike linear-time
/// peeling, and is limited to 2048 unknowns/checks and one million augmented cells.
pub fn ParityCheck::recover_erasures(
  self : ParityCheck,
  observations : Array[Int?],
) -> RecoveryReport raise CodeError {
  if observations.length() != self.n {
    raise LengthMismatch(self.n, observations.length())
  }
  let unknown_positions : Array[Int] = []
  let unknown_index = Array::make(self.n, -1)
  let particular_word = Array::make(self.n, 0)
  for v, observation in observations {
    match observation {
      None => {
        unknown_index[v] = unknown_positions.length()
        unknown_positions.push(v)
      }
      Some(bit) => {
        if bit != 0 && bit != 1 {
          raise InvalidBit(v, bit)
        }
        particular_word[v] = bit
      }
    }
  }
  let unknown_count = unknown_positions.length()
  if unknown_count > 2048 ||
    self.checks() > 2048 ||
    (unknown_count + 1).to_int64() * self.checks().to_int64() > 1048576L {
    raise ResourceLimit("erasure elimination dimensions")
  }
  let rows = Array::makei(self.checks(), fn(c) {
    let row = Array::make(unknown_count + 1, 0)
    let mut rhs = 0
    for v in self.rows[c] {
      let index = unknown_index[v]
      if index >= 0 {
        row[index] = 1
      } else {
        rhs = rhs ^ particular_word[v]
      }
    }
    row[unknown_count] = rhs
    row
  })
  let pivots : Array[Int] = []
  let mut rank = 0
  let mut work = 0L
  for col in 0..<unknown_count {
    let mut selected = -1
    for r in rank..<rows.length() {
      if rows[r][col] == 1 {
        selected = r
        break
      }
    }
    if selected < 0 {
      continue
    }
    let temporary = rows[rank]
    rows[rank] = rows[selected]
    rows[selected] = temporary
    for r in 0..<rows.length() {
      if r != rank && rows[r][col] == 1 {
        work += (unknown_count + 1 - col).to_int64()
        if work > 50000000L {
          raise ResourceLimit("erasure elimination work")
        }
        for k in col..<(unknown_count + 1) {
          rows[r][k] = rows[r][k] ^ rows[rank][k]
        }
      }
    }
    pivots.push(col)
    rank += 1
    if rank == rows.length() {
      break
    }
  }
  for r in rank..<rows.length() {
    if rows[r][unknown_count] != 0 {
      raise Inconsistent("erasure observations have no codeword completion")
    }
  }
  let is_pivot = Array::make(unknown_count, false)
  for col in pivots {
    is_pivot[col] = true
  }
  let values = observations.copy()
  let mut recovered = 0
  for r, col in pivots {
    let mut forced = true
    for k in 0..<unknown_count {
      if !is_pivot[k] && rows[r][k] != 0 {
        forced = false
        break
      }
    }
    let v = unknown_positions[col]
    particular_word[v] = rows[r][unknown_count]
    if forced {
      values[v] = Some(particular_word[v])
      recovered += 1
    }
  }
  let unresolved : Array[Int] = []
  for v, value in values {
    if value is None {
      unresolved.push(v)
    }
  }
  {
    values,
    recovered,
    unresolved,
    ambiguity_dimension: unknown_count - rank,
    unique: rank == unknown_count,
    particular_word,
  }
}

///|
/// Return the projected linear code after deleting coordinates. This is true
/// puncturing: checks involving deleted bits must be eliminated, NOT just truncated.
/// Result columns retain the original relative order. An unconstrained projected
/// code is represented by one empty check. All-deleted projections are rejected.
pub fn ParityCheck::puncture(
  self : ParityCheck,
  removed : Array[Int],
) -> ParityCheck raise CodeError {
  if self.n > 2048 ||
    self.checks() > 2048 ||
    self.n.to_int64() * self.checks().to_int64() > 1048576L {
    raise ResourceLimit("puncture elimination dimensions")
  }
  let deleted = Array::make(self.n, false)
  for v in removed {
    if v < 0 || v >= self.n {
      raise InvalidIndex(-1, v)
    }
    if deleted[v] {
      raise DuplicateEntry(-1, v)
    }
    deleted[v] = true
  }
  if removed.length() == self.n {
    raise InvalidDimensions("puncturing must retain at least one coordinate")
  }
  let dense = Array::makei(self.checks(), fn(c) {
    let row = Array::make(self.n, 0)
    for v in self.rows[c] {
      row[v] = 1
    }
    row
  })
  let mut rank = 0
  let mut work = 0L
  // Eliminate ONLY removed columns. Pivot rows constrain discarded coordinates
  // and vanish under projection; remaining rows are the constraints on retained bits.
  for col in 0..<self.n {
    if !deleted[col] {
      continue
    }
    let mut selected = -1
    for r in rank..<dense.length() {
      if dense[r][col] == 1 {
        selected = r
        break
      }
    }
    if selected < 0 {
      continue
    }
    let temporary = dense[rank]
    dense[rank] = dense[selected]
    dense[selected] = temporary
    for r in (rank + 1)..<dense.length() {
      if dense[r][col] == 1 {
        work += self.n.to_int64()
        if work > 50000000L {
          raise ResourceLimit("puncture elimination work")
        }
        // Retained columns before this pivot also matter, so xor the full row.
        for k in 0..<self.n {
          dense[r][k] = dense[r][k] ^ dense[rank][k]
        }
      }
    }
    rank += 1
    if rank == dense.length() {
      break
    }
  }
  let projected_rows : Array[Array[Int]] = []
  for r in rank..<dense.length() {
    let row : Array[Int] = []
    let mut target = 0
    for v in 0..<self.n {
      if !deleted[v] {
        if dense[r][v] == 1 {
          row.push(target)
        }
        target += 1
      }
    }
    if !row.is_empty() {
      projected_rows.push(row)
    }
  }
  if projected_rows.is_empty() {
    projected_rows.push([])
  }
  ParityCheck::new(self.n - removed.length(), projected_rows)
}

///|
pub extend RecoveryReport with @debug.Debug::{to_repr}

///|
pub extend RecoveryReport with ToJson::{to_json}

///|
/// JSON erasures are null, known bits are numbers (not generic Option arrays).
pub impl ToJson for RecoveryReport with fn to_json(self) {
  let values = self.values.map(fn(value) {
    match value {
      None => Json::null()
      Some(bit) => bit.to_json()
    }
  })
  {
    "values": values.to_json(),
    "recovered": self.recovered,
    "unresolved": self.unresolved.to_json(),
    "ambiguity_dimension": self.ambiguity_dimension,
    "unique": self.unique,
    "particular_word": self.particular_word.to_json(),
  }
}
