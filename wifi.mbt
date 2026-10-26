///|
/// IEEE 802.11 LDPC: only n=1944, rate=3/4, z=81. Information bits
/// occupy coordinates 0..1457; parity follows. Not a complete Wi-Fi PHY.
pub struct WifiLdpc1944R34 {
  priv code : ParityCheck
} derive(Debug)

///|
/// Matrix transcribed by ishmal/ldpc802-js, cross-checked with tavildar/LDPC.
/// Exact revisions, attribution and limitations: docs/wifi-compatibility.md.
fn wifi_1944_r34_base() -> Array[Array[Int32]] {
  [
    [
      48, 29, 28, 39, 9, 61, -1, -1, -1, 63, 45, 80, -1, -1, -1, 37, 32, 22, 1, 0,
      -1, -1, -1, -1,
    ],
    [
      4, 49, 42, 48, 11, 30, -1, -1, -1, 49, 17, 41, 37, 15, -1, 54, -1, -1, -1,
      0, 0, -1, -1, -1,
    ],
    [
      35, 76, 78, 51, 37, 35, 21, -1, 17, 64, -1, -1, -1, 59, 7, -1, -1, 32, -1,
      -1, 0, 0, -1, -1,
    ],
    [
      9, 65, 44, 9, 54, 56, 73, 34, 42, -1, -1, -1, 35, -1, -1, -1, 46, 39, 0, -1,
      -1, 0, 0, -1,
    ],
    [
      3, 62, 7, 80, 68, 26, -1, 80, 55, -1, 36, -1, 26, -1, 9, -1, 72, -1, -1, -1,
      -1, -1, 0, 0,
    ],
    [
      26, 75, 33, 21, 69, 59, 3, 38, -1, -1, -1, 35, -1, 62, 36, 26, -1, -1, 1, -1,
      -1, -1, -1, 0,
    ],
  ]
}

///|
pub fn WifiLdpc1944R34::new() -> WifiLdpc1944R34 raise CodeError {
  { code: lift_qc(wifi_1944_r34_base(), 81), }
}

///|
pub fn WifiLdpc1944R34::parity_check(self : WifiLdpc1944R34) -> ParityCheck {
  self.code
}

///|
/// Solve the fixed parity staircase directly over GF(2), without dense RREF.
/// XORing all six block equations cancels p1..p5 and both shifted p0
/// terms, leaving p0 = XOR of the six information syndromes.
pub fn WifiLdpc1944R34::encode(
  self : WifiLdpc1944R34,
  information : Array[Int32],
) -> Array[Int32] raise CodeError {
  ensure_bits(information, 1458)
  let word = Array::make(1944, 0)
  for i, bit in information {
    word[i] = bit
  }
  let syndromes = Array::makei(486, fn(r) {
    let mut bit = 0
    for col in self.code.rows[r] {
      if col < 1458 {
        bit = bit ^ information[col]
      }
    }
    bit
  })
  for i in 0..<81 {
    let mut bit = 0
    for block in 0..<6 {
      bit = bit ^ syndromes[block * 81 + i]
    }
    word[1458 + i] = bit
  }
  // Each of the first five block rows has one unsolved identity block.
  for block in 0..<5 {
    for i in 0..<81 {
      let row = block * 81 + i
      let target = 1458 + (block + 1) * 81 + i
      let mut bit = syndromes[row]
      for col in self.code.rows[row] {
        if col >= 1458 && col != target {
          bit = bit ^ word[col]
        }
      }
      word[target] = bit
    }
  }
  if !self.code.is_codeword(word) {
    raise Inconsistent("Wi-Fi profile parity construction")
  }
  word
}

///|
/// Check the full codeword before returning its leading information bits.
pub fn WifiLdpc1944R34::extract(
  self : WifiLdpc1944R34,
  word : Array[Int32],
) -> Array[Int32] raise CodeError {
  if !self.code.is_codeword(word) {
    raise Inconsistent("nonzero Wi-Fi syndrome")
  }
  Array::makei(1458, fn(i) { word[i] })
}

///|
pub extend WifiLdpc1944R34 with @debug.Debug::{to_repr}
