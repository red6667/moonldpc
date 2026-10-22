///|
/// Owned coordinate permutation: indices[new_index] is the old index.
pub struct Permutation {
  priv indices : Array[Int32]
} derive(Debug)

///|
pub fn Permutation::new(indices : Array[Int32]) -> Permutation raise CodeError {
  if indices.length() > 65536 {
    raise ResourceLimit("permutation size")
  }
  let seen = Array::make(indices.length(), false)
  for i in indices {
    if i < 0 || i >= indices.length() {
      raise InvalidIndex(-1, i)
    }
    if seen[i] {
      raise DuplicateEntry(-1, i)
    }
    seen[i] = true
  }
  { indices: indices.copy(), }
}

///|
/// Reorders values without interpreting their type, including LLRs and erasures.
pub fn[T] Permutation::apply(
  self : Permutation,
  values : Array[T],
) -> Array[T] raise CodeError {
  if values.length() != self.indices.length() {
    raise LengthMismatch(self.indices.length(), values.length())
  }
  self.indices.map(fn(i) { values[i] })
}

///|
pub fn Permutation::inverse(self : Permutation) -> Permutation {
  let indices = Array::make(self.indices.length(), 0)
  for new_index, old_index in self.indices {
    indices[old_index] = new_index
  }
  { indices, }
}

///|
/// Composition applies self first and next second.
pub fn Permutation::then(
  self : Permutation,
  next : Permutation,
) -> Permutation raise CodeError {
  { indices: next.apply(self.indices), }
}

///|
pub extend Permutation with @debug.Debug::{to_repr}
