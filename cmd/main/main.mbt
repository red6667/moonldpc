///|
fn main {
  let args = @env.args()
  if args.length() != 2 {
    println(
      "MoonLDPC local JSON protocol v1: moon run cmd/main -- '<JSON request>'",
    )
  } else {
    println(@moonldpc.execute(args[1]))
  }
}
