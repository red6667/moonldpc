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
