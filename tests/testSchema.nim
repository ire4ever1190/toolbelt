import std/[unittest, json]

import schema

suite "Schema":
  test "Enum":
    type
      Options = enum
        A = "a"
        B = "b"
        C = "c"
    check generateSchema(Options) == %* {
      "enum": ["a", "b", "c"]
    }
