import toolbet {.all.}

import std/[unittest]

proc foo(): int =
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
