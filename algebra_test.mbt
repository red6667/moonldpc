///|
test "dense interchange round trip validates shape and owns data" {
  let dense = [[1, 0, 1], [0, 1, 1]]
  let code = @moonldpc.ParityCheck::from_dense(dense)
  dense[0][0] = 0
  assert_eq(code.to_dense(), [[1, 0, 1], [0, 1, 1]])
  let exported = code.to_dense()
  exported[0][0] = 0
  assert_eq(code.check_variables(0), [0, 2])
  rejects(() => @moonldpc.ParityCheck::from_dense([]))
  rejects(() => @moonldpc.ParityCheck::from_dense([[1], [0, 1]]))
  rejects(() => @moonldpc.ParityCheck::from_dense([[2]]))
  rejects(() => {
    @moonldpc.ParityCheck::new(65536, Array::makei(17, fn(_) { [] })).to_dense()
  })
}
