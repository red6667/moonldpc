///|
/// Construct the dual binary code using a basis of this code as its checks.
/// Dependent rows are harmless; a zero-dimensional generator uses one empty check.
pub fn ParityCheck::dual(self : ParityCheck) -> ParityCheck raise CodeError {
  let generator = Encoder::new(self).generator()
  let rows : Array[Array[Int]] = []
  for word in generator {
    let row : Array[Int] = []
    for v, bit in word {
      if bit == 1 {
        row.push(v)
      }
    }
    rows.push(row)
  }
  if rows.is_empty() {
    rows.push([])
  }
  ParityCheck::new(self.n, rows)
}

///|
/// Append one overall even parity coordinate. Existing columns keep their indices.
pub fn ParityCheck::extend_even_parity(
  self : ParityCheck,
) -> ParityCheck raise CodeError {
  if self.n >= 65536 {
    raise ResourceLimit("extended parity variable count")
  }
  let rows = copy_rows(self.rows)
  rows.push(Array::makei(self.n + 1, fn(i) { i }))
  ParityCheck::new(self.n + 1, rows)
}
