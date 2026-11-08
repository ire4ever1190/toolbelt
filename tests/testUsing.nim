import toolbet

## Test everything compiles

var mcp = initMCP(
  "AddingService",
  "Calc",
  "Calculates stuff",
  "Call when you need to use a calc (calculator) for big numbers"
)

mcp.add("add", "Add two numbers") do (a, b: int) -> int:
  ## Adds `a` and `b` together
  return a + b

proc separateFunc(a, b: int): int =
  ## Docs
  return a * b

mcp.add("product", "Multiply two numbers", separateFunc)
