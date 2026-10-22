///|
/// Affine Hx=s encoding. This is not error correction or minimum-weight solving.
pub struct CosetEncoder {
  priv encoder : Encoder
  priv offset : Array[Int32]
  priv target : Array[Int32]
} derive(Debug)

///|
pub fn CosetEncoder::new(
  code : ParityCheck,
  target : Array[Int32],
) -> CosetEncoder raise CodeError {
  let encoder = Encoder::new(code)
  let offset = encoder.solve_syndrome(target)
  { encoder, offset, target: target.copy(), }
}

///|
pub fn CosetEncoder::dimension(self : CosetEncoder) -> Int32 {
  self.encoder.dimension()
}

///|
pub fn CosetEncoder::encode(
  self : CosetEncoder,
  information : Array[Int32],
) -> Array[Int32] raise CodeError {
  let word = self.encoder.encode(information)
  for i in 0..<word.length() {
    word[i] = word[i] ^ self.offset[i]
  }
  word
}

///|
pub fn CosetEncoder::extract(
  self : CosetEncoder,
  word : Array[Int32],
) -> Array[Int32] raise CodeError {
  ensure_bits(word, self.offset.length())
  if self.encoder.code.syndrome(word) != self.target {
    raise Inconsistent("word outside target coset")
  }
  let shifted = Array::makei(word.length(), fn(i) { word[i] ^ self.offset[i] })
  self.encoder.extract(shifted)
}

///|
pub extend CosetEncoder with @debug.Debug::{to_repr}
