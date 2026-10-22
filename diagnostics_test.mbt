///|
test "stopping sets agree with exhaustive BEC peeling residuals" {
  let code = @moonldpc.hamming7()
  for mask in 0..<128 {
    let selected : Array[Int] = []
    let observation : Array[Int?] = Array::make(7, Some(0))
    for v in 0..<7 {
      if ((mask >> v) & 1) == 1 {
        selected.push(v)
        observation[v] = None
      }
    }
    let report = code.stopping_set_report(selected)
    let residual = code.peel(observation).unresolved
    assert_true(code.stopping_set_report(residual).is_stopping_set)
    assert_eq(report.is_stopping_set, selected.length() == residual.length())
    for c in report.singleton_checks {
      let mut degree = 0
      for v in code.check_variables(c) {
        if selected.contains(v) {
          degree += 1
        }
      }
      assert_eq(degree, 1)
    }
  }
  rejects(() => code.stopping_set_report([0, 0]))
  rejects(() => code.stopping_set_report([7]))
}
