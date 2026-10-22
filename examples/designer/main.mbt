///|
fn main {
  run() catch {
    _ => panic()
  }
}

///|
fn run() -> Unit raise {
  let code = @moonldpc.lift_qc([[0, 1, -1], [-1, 0, 2]], 5)
  let interchange = code.to_alist()
  let imported = @moonldpc.parse_alist(interchange)
  assert_eq(imported.to_alist(), interchange)
  let encoder = @moonldpc.Encoder::new(imported)
  let word = encoder.encode(Array::make(encoder.dimension(), 1))
  assert_true(imported.is_codeword(word))
  println("designer: QC -> alist -> sparse matrix -> encode -> syndrome")
  println(imported.analyze().to_json().stringify())
  println("dimension=\{encoder.dimension()}")
  assert_eq(imported.girth(), None)
  // True code projection differs from a transmission observation map.
  let projected = imported.puncture([0, 1])
  let reduced = word[2:].to_owned()
  assert_true(projected.is_codeword(reduced))
  println(projected.analyze().to_json().stringify())
  println(
    @moonldpc.Encoder::new(@moonldpc.hamming7())
    .distance_report()
    .to_json()
    .stringify(),
  )
}
