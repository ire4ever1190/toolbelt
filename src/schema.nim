import std/[json, options, tables, enumutils, sequtils]
import pkg/libdump

# All container types first
proc generateSchema*[T](typ: typedesc[seq[T]]): JsonNode
proc generateSchema*[V](typ: typedesc[Table[string, V]]): JsonNode
proc generateSchema*(typ: typedesc[tuple | object]): JsonNode

# Now atoms, so we can reference later
proc generateSchema*(typ: typedesc[string]): JsonNode =
  return %* {"type": "string"}

proc generateSchema*(typ: typedesc[SomeFloat]): JsonNode =
  return %* {"type": "number"}

proc generateSchema*(typ: typedesc[SomeInteger]): JsonNode =
  return %* {"type": "integer"}

proc generateSchema*(typ: typedesc[bool]): JsonNode =
  return %* {"type": "integer"}

proc generateSchema*(typ: typedesc[enum]): JsonNode =
  result = %* {"enum": typ.toSeq()}

proc generateSchema*(typ: typedesc[JsonNode]): JsonNode =
  result = %* {} # Any type

proc generateSchema*(typ: typedesc[tuple | object]): JsonNode =
  result = %* {
    "type": "object",
    "required": [],
    "properties": {}
  }
  for field, val in default(typ).fieldPairs():
    when typeof(val) isnot Option:
      result["properties"][field] = generateSchema(typeof(val))
      result["required"] &= %field
    else:
      result["properties"][field] = generateSchema(typeof(val.T))
    when val.hasDefaultValue():
      result["properties"][field]["default"] = %val

proc generateSchema*[T](typ: typedesc[seq[T]]): JsonNode =
  return %* {
    "type": "array",
    "items": generateSchema(T)
  }

proc generateSchema*[V](typ: typedesc[Table[string, V]]): JsonNode =
  return %* {
    "type": "object",
    "additionalProperties": generateSchema(V),
  }
