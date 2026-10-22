///|
/// Owned sparse binary matrix. Each edge is present once; rows are sorted.
/// Construction is bounded to one million edges and 65536 variables/checks.
pub struct ParityCheck {
  priv n : Int
  priv rows : Array[Array[Int]]
  priv columns : Array[Array[Int]]
  priv row_edges : Array[Array[Int]]
  priv column_edges : Array[Array[Int]]
  priv edge_variables : Array[Int]
  priv edge_checks : Array[Int]
} derive(Debug)

///|
pub fn ParityCheck::new(
  variables : Int,
  checks : Array[Array[Int]],
) -> ParityCheck raise CodeError {
  if variables <= 0 ||
    variables > 65536 ||
    checks.is_empty() ||
    checks.length() > 65536 {
    raise InvalidDimensions("require 1..65536 variables and checks")
  }
  let mut count = 0
  for row in checks {
    if row.length() > 1000000 - count {
      raise ResourceLimit("matrix edges")
    }
    count += row.length()
  }
  let rows = copy_rows(checks)
  let columns : Array[Array[Int]] = Array::makei(variables, fn(_) { [] })
  let row_edges : Array[Array[Int]] = []
  let column_edges : Array[Array[Int]] = Array::makei(variables, fn(_) { [] })
  let edge_variables : Array[Int] = []
  let edge_checks : Array[Int] = []
  for c, row in rows {
    row.sort()
    let edges : Array[Int] = []
    let mut previous = -1
    for v in row {
      if v < 0 || v >= variables {
        raise InvalidIndex(c, v)
      }
      if v == previous {
        raise DuplicateEntry(c, v)
      }
      previous = v
      let edge = edge_variables.length()
      edge_variables.push(v)
      edge_checks.push(c)
      edges.push(edge)
      columns[v].push(c)
      column_edges[v].push(edge)
    }
    row_edges.push(edges)
  }
  {
    n: variables,
    rows,
    columns,
    row_edges,
    column_edges,
    edge_variables,
    edge_checks,
  }
}

///|
pub fn ParityCheck::variables(self : ParityCheck) -> Int {
  self.n
}

///|
pub fn ParityCheck::checks(self : ParityCheck) -> Int {
  self.rows.length()
}

///|
pub fn ParityCheck::edges(self : ParityCheck) -> Int {
  self.edge_variables.length()
}

///|
pub fn ParityCheck::check_variables(
  self : ParityCheck,
  check : Int,
) -> Array[Int] raise CodeError {
  if check < 0 || check >= self.checks() {
    raise InvalidIndex(check, -1)
  }
  self.rows[check].copy()
}

///|
pub fn ParityCheck::variable_checks(
  self : ParityCheck,
  variable : Int,
) -> Array[Int] raise CodeError {
  if variable < 0 || variable >= self.n {
    raise InvalidIndex(-1, variable)
  }
  self.columns[variable].copy()
}

///|
pub fn ParityCheck::syndrome(
  self : ParityCheck,
  word : Array[Int],
) -> Array[Int] raise CodeError {
  ensure_bits(word, self.n)
  self.rows.map(fn(row) {
    let mut parity = 0
    for v in row {
      parity = parity ^ word[v]
    }
    parity
  })
}

///|
pub fn ParityCheck::is_codeword(
  self : ParityCheck,
  word : Array[Int],
) -> Bool raise CodeError {
  self.syndrome(word).all(fn(x) { x == 0 })
}

///|
fn ParityCheck::syndrome_weight(self : ParityCheck, word : Array[Int]) -> Int {
  let mut count = 0
  for row in self.rows {
    let mut bit = 0
    for v in row {
      bit = bit ^ word[v]
    }
    count += bit
  }
  count
}

///|
/// Reindex columns. permutation[new_index] gives the old index.
pub fn ParityCheck::permute(
  self : ParityCheck,
  permutation : Array[Int],
) -> ParityCheck raise CodeError {
  if permutation.length() != self.n {
    raise LengthMismatch(self.n, permutation.length())
  }
  let inverse = Array::make(self.n, -1)
  for new_index, old_index in permutation {
    if old_index < 0 || old_index >= self.n {
      raise InvalidIndex(new_index, old_index)
    }
    if inverse[old_index] != -1 {
      raise DuplicateEntry(new_index, old_index)
    }
    inverse[old_index] = new_index
  }
  ParityCheck::new(
    self.n,
    self.rows.map(fn(row) { row.map(fn(v) { inverse[v] }) }),
  )
}

///|
/// Block-diagonal composition represents independent codewords, not concatenation.
pub fn ParityCheck::direct_sum(
  self : ParityCheck,
  other : ParityCheck,
) -> ParityCheck raise CodeError {
  if self.n > 65536 - other.n {
    raise ResourceLimit("direct sum variables")
  }
  let rows = copy_rows(self.rows)
  for row in other.rows {
    rows.push(row.map(fn(v) { v + self.n }))
  }
  ParityCheck::new(self.n + other.n, rows)
}

///|
/// Repeat one parity constraint for every adjacent pair (dimension one).
pub fn repetition_code(length : Int) -> ParityCheck raise CodeError {
  if length < 2 || length > 65536 {
    raise InvalidDimensions("repetition length 2..65536")
  }
  ParityCheck::new(length, Array::makei(length - 1, fn(i) { [i, i + 1] }))
}

///|
/// Hamming (7,4), columns are the nonzero three-bit integers 1..7.
pub fn hamming7() -> ParityCheck {
  ParityCheck::new(7, [[0, 2, 4, 6], [1, 2, 5, 6], [3, 4, 5, 6]]) catch {
    _ => abort("constant matrix is valid")
  }
}

///|
pub extend ParityCheck with @debug.Debug::{to_repr}

///|
pub fn ParityCheck::edge_endpoints(
  self : ParityCheck,
  edge : Int,
) -> (Int, Int) raise CodeError {
  if edge < 0 || edge >= self.edges() {
    raise InvalidIndex(-1, edge)
  }
  (self.edge_checks[edge], self.edge_variables[edge])
}
