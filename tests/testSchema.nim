import std/[unittest, json, options]

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

  test "Tuple with optional":
    check generateSchema(tuple[x: Option[string]]) == %* {
      "type": "object",
      "required": [],
      "properties": {"x":
        {
          "oneOf": [
            {"type": "string"},
            {"type": "null"}
          ]
        }
      }
    }

  test "Defaults":
    check generateSchema(tuple[x: string = "hello"]) == %* {
      "type": "object",
      "required": [],
      "properties": {"x": {"type": "string", "default": "hello"}}
    }
