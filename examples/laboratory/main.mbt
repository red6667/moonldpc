///|
/// Receiver calibration, coordinate mapping and exact small-code cross-check.
fn main raise {
  let code = @moonldpc.hamming7().extend_even_parity()
  let encoder = @moonldpc.Encoder::new(code)
  let word = encoder.encode([1, 0, 1, 1]) catch { _ => abort("encode") }
  let mapping = @moonldpc.Permutation::new([7, 5, 3, 1, 6, 4, 2, 0]) catch {
    _ => abort("mapping")
  }
  let samples = mapping.apply(@moonldpc.bpsk(word) catch { _ => abort("bpsk") }) catch {
    _ => abort("map samples")
  }
  let variances = Array::make(8, 0.5)
  variances[0] = 2.0
  let channel = @moonldpc.awgn_llr_per_sample(samples, variances) catch {
    _ => abort("demap")
  }
  let aligned = mapping.inverse().apply(channel) catch { _ => abort("align") }
  let exact = encoder.decode_exact(aligned) catch { _ => abort("exact") }
  if exact.word != word {
    abort("laboratory regression")
  }
  let probabilities = @moonldpc.bit_one_probabilities(exact.posterior_llr) catch {
    _ => abort("probabilities")
  }
  println("laboratory: calibrated/interleaved extended Hamming frame recovered")
  println(exact.to_json().stringify())
  println(Json(probabilities).stringify())
}
