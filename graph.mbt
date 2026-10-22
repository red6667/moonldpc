///|
pub struct GraphReport {
  variables : Int
  checks : Int
  edges : Int
  isolated_variables : Int
  empty_checks : Int
  components : Int
  variable_degrees : Array[Int]
  check_degrees : Array[Int]
  four_cycles : Int64
} derive(Debug, ToJson)

///|
/// Computes exact four-cycle count. Comparison budget bounds dense adversarial input.
pub fn ParityCheck::analyze(self : ParityCheck) -> GraphReport raise CodeError {
  let mut work = 0L
  for column in self.columns {
    let degree = column.length().to_int64()
    work += degree * (degree - 1L) / 2L
    if work > 2000000L {
      raise ResourceLimit("four-cycle pair budget")
    }
  }
  let pairs : Map[(Int, Int), Int] = Map([])
  let mut four_cycles = 0L
  for column in self.columns {
    for a in 0..<column.length() {
      for b in (a + 1)..<column.length() {
        let key = (column[a], column[b])
        let previous = pairs.get(key).unwrap_or(0)
        four_cycles += previous.to_int64()
        pairs[key] = previous + 1
      }
    }
  }
  let seen = Array::make(self.n + self.checks(), false)
  let mut components = 0
  for start in 0..<seen.length() {
    if seen[start] {
      continue
    }
    components += 1
    let queue = [start]
    seen[start] = true
    let mut head = 0
    while head < queue.length() {
      let node = queue[head]
      head += 1
      if node < self.n {
        for check in self.columns[node] {
          let target = self.n + check
          if !seen[target] {
            seen[target] = true
            queue.push(target)
          }
        }
      } else {
        for variable in self.rows[node - self.n] {
          if !seen[variable] {
            seen[variable] = true
            queue.push(variable)
          }
        }
      }
    }
  }
  {
    variables: self.n,
    checks: self.checks(),
    edges: self.edges(),
    isolated_variables: self.columns.filter(fn(row) { row.is_empty() }).length(),
    empty_checks: self.rows.filter(fn(row) { row.is_empty() }).length(),
    components,
    variable_degrees: self.columns.map(fn(row) { row.length() }),
    check_degrees: self.rows.map(fn(row) { row.length() }),
    four_cycles,
  }
}

///|
/// Exact Tanner girth by BFS, limited to 20 million traversed edges.
/// None means acyclic. Never reports a partial traversal as an exact girth.
pub fn ParityCheck::girth(self : ParityCheck) -> Int? raise CodeError {
  let total = self.n + self.checks()
  if total > 8192 {
    raise ResourceLimit("girth vertices")
  }
  let mut work = 0
  let mut best = total + 1
  for start in 0..<total {
    let distances = Array::make(total, -1)
    let parents = Array::make(total, -1)
    let queue = [start]
    distances[start] = 0
    let mut head = 0
    while head < queue.length() {
      let node = queue[head]
      head += 1
      let targets = if node < self.n {
        self.columns[node].map(fn(c) { c + self.n })
      } else {
        self.rows[node - self.n]
      }
      for target in targets {
        work += 1
        if work > 20000000 {
          raise ResourceLimit("girth edge visits")
        }
        if distances[target] < 0 {
          distances[target] = distances[node] + 1
          parents[target] = node
          queue.push(target)
        } else if parents[node] != target {
          best = best.min(distances[node] + distances[target] + 1)
        }
      }
    }
    if best == 4 {
      return Some(4)
    }
  }
  if best > total {
    None
  } else {
    Some(best)
  }
}

///|
pub struct DistanceReport {
  dimension : Int
  examined_nonzero_words : Int
  minimum_distance : Int?
  weight_distribution : Array[Int]
} derive(Debug, ToJson)

///|
/// Exhaustive exact analysis of small linear codes only (k<=20, n*2^k<=8M).
pub fn Encoder::distance_report(
  self : Encoder,
) -> DistanceReport raise CodeError {
  let k = self.dimension()
  if k > 20 {
    raise ResourceLimit("distance dimension")
  }
  let count = 1 << k
  if self.code.n.to_int64() * count.to_int64() > 8000000L {
    raise ResourceLimit("distance enumeration work")
  }
  let generator = self.generator()
  let word = Array::make(self.code.n, 0)
  let distribution = Array::make(self.code.n + 1, 0)
  distribution[0] = 1
  let mut previous_gray = 0
  let mut minimum = self.code.n + 1
  for index in 1..<count {
    let gray = index ^ (index >> 1)
    let changed = gray ^ previous_gray
    let mut bit = 0
    while ((changed >> bit) & 1) == 0 {
      bit += 1
    }
    let mut weight = 0
    for v in 0..<self.code.n {
      word[v] = word[v] ^ generator[bit][v]
      weight += word[v]
    }
    distribution[weight] += 1
    minimum = minimum.min(weight)
    previous_gray = gray
  }
  {
    dimension: k,
    examined_nonzero_words: count - 1,
    minimum_distance: if count == 1 {
      None
    } else {
      Some(minimum)
    },
    weight_distribution: distribution,
  }
}

///|
pub extend GraphReport with @debug.Debug::{to_repr}

///|
pub extend GraphReport with ToJson::{to_json}

///|
pub extend DistanceReport with @debug.Debug::{to_repr}

///|
pub extend DistanceReport with ToJson::{to_json}
