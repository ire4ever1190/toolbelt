import std/[macros, json]

macro createNamedTuple*(prc: proc): untyped =
  ## Takes in the NimNode for a proc type and returns a named tuple to
  ## parse the parameters.
  ## Tuple has default values set
  let
    typ = prc.getTypeImpl()
    params = typ[0][1 .. ^1]
  # First we need to construct the type
  let tupleType = nnkTupleTy.newTree()
  for param in params:
    # We need to desym the params
    tupleType &= newIdentDefs(ident param[0].strVal, param[1], param[2])
  tupleType


proc update*(res: var JsonNode, value: JsonNode) =
  ## Merges keys rom `value` into `res`
  for key in value.keys():
    res[key] = value[key]
