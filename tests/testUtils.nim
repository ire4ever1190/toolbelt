import toolbet {.all.}, utils

import std/[unittest]

proc foo(a = 1): int =
  ## Some description
  return 9
suite "Getting docs":
  test "Proc reference":
    check getDescription(foo) == "Some description"
  test "Inline":
    let docs = getDescription() do () -> int:
      ## test
      return 5
    check docs == "test"

suite "Converting to tuple":
  test "Supports defaults":
    let idk = default(createNamedTuple(foo))
    check idk.a == 1

  test "Supports basic":
    proc foo2(a: string): int = discard
    let idk = default(createNamedTuple(foo2))
    check idk.a is string
