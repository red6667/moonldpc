///|
/// Dense elimination is deliberately bounded separately from sparse decoding.
pub struct Encoder {
  priv code : ParityCheck
  priv reduced : Array[Array[Int]]
  priv pivots : Array[Int]
  priv free : Array[Int]
} derive(Debug)

///|
pub fn Encoder::new(code : ParityCheck) -> Encoder raise CodeError {
  if code.n > 2048 || code.checks() > 2048 || code.n * code.checks() > 1048576 {
    raise ResourceLimit(
      "GF(2) elimination: at most 2048 axes and 1048576 cells",
    )
  }
  let reduced = Array::makei(code.checks(), fn(c) {
    let row = Array::make(code.n, 0)
    for v in code.rows[c] {
      row[v] = 1
    }
    row
  })
  let pivots : Array[Int] = []
  let mut work = 0L
  let mut pivot_row = 0
  for col in 0..<code.n {
    let mut selected = -1
    for row in pivot_row..<code.checks() {
      if reduced[row][col] == 1 {
        selected = row
        break
      }
    }
    if selected == -1 {
      continue
    }
    let temp = reduced[pivot_row]
    reduced[pivot_row] = reduced[selected]
    reduced[selected] = temp
    for row in 0..<code.checks() {
      if row != pivot_row && reduced[row][col] == 1 {
        work += (code.n - col).to_int64()
        if work > 50000000L {
          raise ResourceLimit("encoder elimination work")
        }
        for k in col..<code.n {
          reduced[row][k] = reduced[row][k] ^ reduced[pivot_row][k]
        }
      }
    }
    pivots.push(col)
    pivot_row += 1
    if pivot_row == code.checks() {
      break
    }
  }
  let free : Array[Int] = []
  let mut p = 0
  for col in 0..<code.n {
    if p < pivots.length() && pivots[p] == col {
      p += 1
    } else {
      free.push(col)
    }
  }
  { code, reduced, pivots, free, }
}

///|
pub fn Encoder::rank(self : Encoder) -> Int {
  self.pivots.length()
}

///|
pub fn Encoder::dimension(self : Encoder) -> Int {
  self.free.length()
}

///|
pub fn Encoder::information_positions(self : Encoder) -> Array[Int] {
  self.free.copy()
}

///|
pub fn Encoder::parity_positions(self : Encoder) -> Array[Int] {
  self.pivots.copy()
}

///|
pub fn Encoder::rate(self : Encoder) -> Double {
  self.dimension().to_double() / self.code.n.to_double()
}

///|
/// Free columns carry information; pivot columns are solved from RREF.
pub fn Encoder::encode(
  self : Encoder,
  information : Array[Int],
) -> Array[Int] raise CodeError {
  ensure_bits(information, self.dimension())
  let word = Array::make(self.code.n, 0)
  for i, v in self.free {
    word[v] = information[i]
  }
  for r, pivot in self.pivots {
    let mut value = 0
    for v in self.free {
      value = value ^ (self.reduced[r][v] & word[v])
    }
    word[pivot] = value
  }
  word
}

///|
/// Extraction rejects a non-codeword rather than silently accepting corruption.
pub fn Encoder::extract(
  self : Encoder,
  word : Array[Int],
) -> Array[Int] raise CodeError {
  if !self.code.is_codeword(word) {
    raise Inconsistent("nonzero syndrome")
  }
  self.free.map(fn(v) { word[v] })
}

///|
pub fn Encoder::generator(self : Encoder) -> Array[Array[Int]] raise CodeError {
  if self.dimension() * self.code.n > 1048576 {
    raise ResourceLimit("generator cells")
  }
  let result : Array[Array[Int]] = []
  for i in 0..<self.dimension() {
    let unit = Array::make(self.dimension(), 0)
    unit[i] = 1
    result.push(self.encode(unit))
  }
  result
}

///|
/// Solve Hx=s over GF(2), choosing all free variables zero.
/// This is an algebraic solution, NOT a minimum-weight error estimate.
pub fn Encoder::solve_syndrome(
  self : Encoder,
  syndrome : Array[Int],
) -> Array[Int] raise CodeError {
  ensure_bits(syndrome, self.code.checks())
  let rows = Array::makei(self.code.checks(), fn(c) {
    let row = Array::make(self.code.n + 1, 0)
    for v in self.code.rows[c] {
      row[v] = 1
    }
    row[self.code.n] = syndrome[c]
    row
  })
  let mut work = 0L
  let mut rank = 0
  let pivots : Array[Int] = []
  for col in 0..<self.code.n {
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
    let tmp = rows[rank]
    rows[rank] = rows[selected]
    rows[selected] = tmp
    for r in 0..<rows.length() {
      if r != rank && rows[r][col] == 1 {
        work += (self.code.n + 1 - col).to_int64()
        if work > 50000000L {
          raise ResourceLimit("syndrome elimination work")
        }
        for k in col..<(self.code.n + 1) {
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
    if rows[r][self.code.n] != 0 {
      raise Inconsistent("syndrome contradicts dependent checks")
    }
  }
  let result = Array::make(self.code.n, 0)
  for r, col in pivots {
    result[col] = rows[r][self.code.n]
  }
  result
}

///|
pub extend Encoder with @debug.Debug::{to_repr}
