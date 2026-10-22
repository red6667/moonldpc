///|
pub suberror CodeError {
  InvalidDimensions(String)
  InvalidIndex(Int, Int)
  DuplicateEntry(Int, Int)
  InvalidBit(Int, Int)
  LengthMismatch(Int, Int)
  InvalidNumber(String)
  InvalidFormat(Int, String)
  ResourceLimit(String)
  Inconsistent(String)
} derive(Debug)

///|
fn ensure_bits(bits : Array[Int], expected : Int) -> Unit raise CodeError {
  if bits.length() != expected {
    raise LengthMismatch(expected, bits.length())
  }
  for i, bit in bits {
    if bit != 0 && bit != 1 {
      raise InvalidBit(i, bit)
    }
  }
}

///|
fn finite(x : Double) -> Bool {
  !x.is_nan() && !x.is_inf()
}

///|
fn clamp(x : Double, bound : Double) -> Double {
  x.max(-bound).min(bound)
}

///|
fn copy_rows(rows : Array[Array[Int]]) -> Array[Array[Int]] {
  rows.map(fn(row) { row.copy() })
}

///|
pub extend CodeError with @debug.Debug::{to_repr}
