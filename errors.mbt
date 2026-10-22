///|
pub suberror CodeError {
  InvalidDimensions(String)
  InvalidIndex(Int32, Int32)
  DuplicateEntry(Int32, Int32)
  InvalidBit(Int32, Int32)
  LengthMismatch(Int32, Int32)
  InvalidNumber(String)
  InvalidFormat(Int32, String)
  ResourceLimit(String)
  Inconsistent(String)
} derive(Debug)

///|
fn ensure_bits(bits : Array[Int32], expected : Int32) -> Unit raise CodeError {
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
fn copy_rows(rows : Array[Array[Int32]]) -> Array[Array[Int32]] {
  rows.map(fn(row) { row.copy() })
}

///|
pub extend CodeError with @debug.Debug::{to_repr}
