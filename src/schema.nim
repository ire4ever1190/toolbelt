import std/[json, options, tables, enumutils, sequtils, macros, times]
import pkg/libdump

# Utilities

type
  JsonDescrible = concept
    ## Any type that can be described in JSON
    proc generateSchema(inp: typedesc[Self]): JsonNode

const timeFormat = "yyyy-MM-dd'T'HH:mm:sszzz"

proc fromJsonHook*(time: var DateTime, data: JsonNode) =
  ## Hook so dates use what our schema says
  time = data.to(string).parse(timeFormat)

proc toJsonHook*(time: DateTime): JsonNode =
  ## Hook so dates use what our schema says
  %time.format(timeFormat)

# All container types first
proc generateSchema*[T](typ: typedesc[seq[T]]): JsonNode
proc generateSchema*[V](typ: typedesc[Table[string, V]]): JsonNode
proc generateSchema*(typ: typedesc[tuple | object]): JsonNode
proc generateSchema*[T](typ: typedesc[Option[T]]): JsonNode

# Now atoms, so we can reference later
proc generateSchema*(typ: typedesc[string]): JsonNode =
  return %* {"type": "string"}

proc generateSchema*(typ: typedesc[typeof(nil)]): JsonNode =
  return %* {"type": "null"}

proc generateSchema*(typ: typedesc[SomeFloat]): JsonNode =
  return %* {"type": "number"}

proc generateSchema*(typ: typedesc[SomeInteger]): JsonNode =
  return %* {"type": "integer"}

proc generateSchema*(typ: typedesc[bool]): JsonNode =
  return %* {"type": "integer"}

proc generateSchema*(typ: typedesc[DateTime]): JsonNode =
  return %* {"type": "string", "format": "date-time"}

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
    result["properties"][field] = generateSchema(typeof(val))

    when not (typeof(val) is Option or val.hasDefaultValue()):
      result["required"] &= %field

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

macro typedescs(loop: ForLoopStmt) =
  echo loop.treeRepr

macro oneOf*(typs: varargs[typed]): JsonNode =
  ## Accepts any of `typs`
  let possIdent = nskVar.genSym()
  result = newStmtList()
  result.add quote do:
    var `possIdent`: seq[JsonNode]
  for typ in typs:
    result.add quote do:
      `possIdent` &= generateSchema(`typ`)
  result.add quote do:
    %* {"oneOf": `possIdent`}

proc generateSchema*[T](typ: typedesc[Option[T]]): JsonNode =
  return oneOf(T, typeof(nil))
