///|
/// Import a bounded dense binary matrix. All rows must have identical width.
pub fn ParityCheck::from_dense(
  matrix : Array[Array[Int]],
) -> ParityCheck raise CodeError {
  if matrix.is_empty() {
    raise InvalidDimensions("dense matrix requires rows")
  }
  let n = matrix[0].length()
  if n <= 0 || n > 65536 || matrix.length() > 65536 {
    raise InvalidDimensions("dense matrix axes")
  }
  if matrix.length().to_int64() * n.to_int64() > 1048576L {
    raise ResourceLimit("dense matrix cells")
  }
  let rows : Array[Array[Int]] = []
  for row in matrix {
    ensure_bits(row, n)
    let indices : Array[Int] = []
    for i, bit in row {
      if bit == 1 {
        indices.push(i)
      }
    }
    rows.push(indices)
  }
  ParityCheck::new(n, rows)
}

///|
/// Export independent dense rows. Bound the allocation before creating rows.
pub fn ParityCheck::to_dense(
  self : ParityCheck,
) -> Array[Array[Int]] raise CodeError {
  if self.n.to_int64() * self.checks().to_int64() > 1048576L {
    raise ResourceLimit("dense matrix cells")
  }
  self.rows.map(fn(row) {
    let dense = Array::make(self.n, 0)
    for v in row {
      dense[v] = 1
    }
    dense
  })
}
