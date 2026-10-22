///|
#cfg(target="js")
fn argument_prefix_length() -> Int {
  // Node supplies its executable and script before user arguments.
  2
}

///|
#cfg(not(target="js"))
fn argument_prefix_length() -> Int {
  1
}

///|
fn main {
  let args = @env.args()
  let prefix = argument_prefix_length()
  if args.length() != prefix + 1 {
    println(
      "MoonLDPC local JSON protocol v1: moon run cmd/main -- '<JSON request>'",
    )
  } else {
    println(@moonldpc.execute(args[prefix]))
  }
}
