///|
/// Padded alist reader. Whitespace separates nonnegative decimal integers.
/// Both row and column adjacency sections are required and cross-validated.
pub fn parse_alist(text : String) -> ParityCheck raise CodeError {
  if text.length() > 16777216 {
    raise ResourceLimit("alist input characters")
  }
  let tokens : Array[Int] = []
  let mut active = false
  let mut number = 0
  let mut line = 1
  for c in text {
    if c >= '0' && c <= '9' {
      let digit = c.to_int() - '0'.to_int()
      if number > (1000000 - digit) / 10 {
        raise InvalidFormat(line, "integer exceeds 1000000")
      }
      number = number * 10 + digit
      active = true
    } else if c == ' ' || c == '\t' || c == '\r' || c == '\n' {
      if active {
        if tokens.length() >= 2200000 {
          raise ResourceLimit("alist tokens")
        }
        tokens.push(number)
        active = false
        number = 0
      }
      if c == '\n' {
        line += 1
      }
    } else {
      raise InvalidFormat(
        line, "expected nonnegative decimal integer or whitespace",
      )
    }
  }
  if active {
    tokens.push(number)
  }
  if tokens.length() < 4 {
    raise InvalidFormat(line, "missing alist header")
  }
  let n = tokens[0]
  let m = tokens[1]
  let max_column = tokens[2]
  let max_row = tokens[3]
  if n <= 0 || n > 65536 || m <= 0 || m > 65536 {
    raise InvalidDimensions("alist axes 1..65536")
  }
  if max_column > m || max_row > n {
    raise InvalidFormat(1, "degree maximum exceeds axis")
  }
  let expected = 4L +
    n.to_int64() +
    m.to_int64() +
    n.to_int64() * max_column.to_int64() +
    m.to_int64() * max_row.to_int64()
  if expected > 2200000L {
    raise ResourceLimit("padded alist cells")
  }
  if expected != tokens.length().to_int64() {
    raise InvalidFormat(line, "incorrect padded alist token count")
  }
  let column_degrees = Array::makei(n, fn(v) { tokens[4 + v] })
  let row_degrees = Array::makei(m, fn(c) { tokens[4 + n + c] })
  if column_degrees.any(fn(d) { d > max_column }) ||
    row_degrees.any(fn(d) { d > max_row }) {
    raise InvalidFormat(2, "degree exceeds declared maximum")
  }
  if column_degrees.fold(init=0, fn(a, b) { a + b }) > 1000000 {
    raise ResourceLimit("alist edges")
  }
  let rows : Array[Array[Int]] = Array::makei(m, fn(_) { [] })
  let mut cursor = 4 + n + m
  for v in 0..<n {
    let seen : Map[Int, Bool] = Map([])
    for k in 0..<max_column {
      let value = tokens[cursor]
      cursor += 1
      if k < column_degrees[v] {
        if value < 1 || value > m {
          raise InvalidFormat(0, "column neighbor out of range")
        }
        if seen.contains(value) {
          raise DuplicateEntry(value - 1, v)
        }
        seen[value] = true
        rows[value - 1].push(v)
      } else if value != 0 {
        raise InvalidFormat(0, "column padding must be zero")
      }
    }
  }
  let code = ParityCheck::new(n, rows)
  for c in 0..<m {
    if code.rows[c].length() != row_degrees[c] {
      raise InvalidFormat(0, "row degree mismatch")
    }
    let listed : Array[Int] = []
    for k in 0..<max_row {
      let value = tokens[cursor]
      cursor += 1
      if k < row_degrees[c] {
        if value < 1 || value > n {
          raise InvalidFormat(0, "row neighbor out of range")
        }
        listed.push(value - 1)
      } else if value != 0 {
        raise InvalidFormat(0, "row padding must be zero")
      }
    }
    listed.sort()
    if listed != code.rows[c] {
      raise InvalidFormat(0, "row and column adjacency disagree")
    }
  }
  code
}

///|
pub fn ParityCheck::to_alist(self : ParityCheck) -> String raise CodeError {
  let max_column = self.columns.fold(init=0, fn(a, row) { a.max(row.length()) })
  let max_row = self.rows.fold(init=0, fn(a, row) { a.max(row.length()) })
  let cells = self.n.to_int64() * max_column.to_int64() +
    self.checks().to_int64() * max_row.to_int64()
  if cells > 2000000L {
    raise ResourceLimit("alist padded output cells")
  }
  let out = StringBuilder()
  out.write_string("\{self.n} \{self.checks()}\n\{max_column} \{max_row}\n")
  for v in 0..<self.n {
    if v > 0 {
      out.write_char(' ')
    }
    out.write_string(self.columns[v].length().to_string())
  }
  out.write_char('\n')
  for c in 0..<self.checks() {
    if c > 0 {
      out.write_char(' ')
    }
    out.write_string(self.rows[c].length().to_string())
  }
  out.write_char('\n')
  for column in self.columns {
    for k in 0..<max_column {
      if k > 0 {
        out.write_char(' ')
      }
      out.write_string(
        if k < column.length() {
          (column[k] + 1).to_string()
        } else {
          "0"
        },
      )
    }
    out.write_char('\n')
  }
  for row in self.rows {
    for k in 0..<max_row {
      if k > 0 {
        out.write_char(' ')
      }
      out.write_string(
        if k < row.length() {
          (row[k] + 1).to_string()
        } else {
          "0"
        },
      )
    }
    out.write_char('\n')
  }
  out.to_string()
}

///|
/// Base cells -1 are zero blocks; 0..lift-1 denote cyclic permutation blocks.
/// Row r of a block with shift s has its one in column (r+s) mod lift.
pub fn lift_qc(
  base : Array[Array[Int]],
  lift : Int,
) -> ParityCheck raise CodeError {
  if base.is_empty() || base[0].is_empty() || lift <= 0 || lift > 4096 {
    raise InvalidDimensions("nonempty QC base and lift 1..4096")
  }
  let columns = base[0].length()
  if columns > 65536 / lift || base.length() > 65536 / lift {
    raise ResourceLimit("QC lifted axes")
  }
  let mut blocks = 0
  for c, row in base {
    if row.length() != columns {
      raise InvalidDimensions("ragged QC base")
    }
    for shift in row {
      if shift < -1 || shift >= lift {
        raise InvalidIndex(c, shift)
      }
      if shift >= 0 {
        blocks += 1
      }
    }
  }
  if blocks > 1000000 / lift {
    raise ResourceLimit("QC lifted edges")
  }
  let rows : Array[Array[Int]] = []
  for base_row in base {
    for r in 0..<lift {
      let row : Array[Int] = []
      for column, shift in base_row {
        if shift >= 0 {
          row.push(column * lift + (r + shift) % lift)
        }
      }
      rows.push(row)
    }
  }
  ParityCheck::new(columns * lift, rows)
}
