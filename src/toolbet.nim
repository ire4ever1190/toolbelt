import std/[json, tables, typetraits, macros, jsonutils, sequtils, sugar, logging, strformat, options]

import pkg/jaysonrpc

import ./[utils, types]


type
  ToolHandler = proc (ctx: Context, arguments: Table[string, JsonNode]): JsonNode
  Tool  = object
    name: string
      ## This is the machine name e.g. get_weather
    title: string
      ## Human name e.g. Weather Information Provider
    description: string
      ## Human readable description on the tool
    inputSchema: JsonNode
    outputSchema: JsonNode
    handler: ToolHandler

  MCP = ref object
    name, title, version: string

    tools: Table[string, Tool]
    exec: Executor[JsonNode]

proc toJsonHook(tool: Tool): JsonNode =
  result = %*{
    "name": tool.name,
    "title": tool.title,
    "description": tool.description,
    "inputSchema": tool.inputSchema,
    "outputSchema": tool.outputSchema
  }

proc fromJsonHook(info: var Info, data: JsonNode) =
  info.name.fromJson(data["name"])
  info.version.fromJson(data["version"])
  if "title" in data:
    info.title.fromJson(data["title"])

proc initMCP(name, title, version: string): MCP =
  let mcp = MCP(name: name, title: title, version: version, exec: initExecutor[JsonNode]())
  mcp.exec.on("tools/list") do () -> tuple[tools: seq[Tool]]:
    debug "Returning tools " & $toSeq(mcp.tools.values())
    return (tools: toSeq(mcp.tools.values()))

  mcp.exec.on("ping") do () -> JsonNode:
    newJObject()

  mcp.exec.on("initialize") do (protocolVersion: string, capabilities: JsonNode, clientInfo: Info) -> ServerCapabilities:
    info(fmt"Client {clientInfo.name} connected")
    result = default(ServerCapabilities)
    result.capabilities = %* {
      "tools": {
        "listChanged": false
      }
    }
    result.serverInfo = Info(name: name, version: version)
    result.instructions = "Call me when you need the weather"

  mcp.exec.on("tools/call") do (ctx: Context, name: string, arguments: Table[string, JsonNode]) -> CallToolResult:
    let meth = mcp.tools[name].handler
    return CallToolResult(
      content: @[
        ContentBlock(`type`: "text", text: meth(ctx, arguments).pretty())
      ]
    )

  mcp.exec.on("notifications/initialized") do ():
    info("Client is ready")

  return mcp

proc wrapProc(prc: proc): ToolHandler =
  proc (ctx: Context, arguments: Table[string, JsonNode]): JsonNode =
    # Parse everything into the args
    var args = default(createNamedTuple(prc))
    for name, field in args.fieldPairs:
      when type(field) is Context:
        field = ctx
      else:
        field.fromJson(data[name])

    # Call the original function
    result = prc.call(args).toJson()
    debug result.pretty()

macro getDescription(tool: typed): string =
  let impl = if tool.kind == nnkSym: tool.getImpl() else: tool
  if impl.kind == nnkProcDef:
    return newLit impl[^1].strVal
  else:
    return newLit $impl[^2].extractDocCommentsAndRunnables()[0]

proc add(mcp: var MCP, name, title, description: string, tool: proc) =
  mcp.tools[name] = Tool(
    name: name,
    title: title,
    description: description,
    handler: wrapProc(tool),
    inputSchema: newJObject(),
    outputSchema: %* {"type": "string", "description": "Weather for the current location"}
  )

template add(mcp: var MCP, name, title: string, tool: proc) =
  mcp.add(
    name,
    title,
    getDescription(tool),
    tool
  )

var mcp = initMCP("WeatherService", "Weather Service", "Gets weather information for a location")

mcp.add("getWeather", "Get Weather") do () -> string:
  ## Returns the weather for the users current location (Don't worry, we know it)
  debug "Returning the weather"
  return "The weather is cloudy with a chance of meat balls"

proc start(mcp: MCP) =
  info("Starting...")
  while true:
    let json = stdin.readline()
    debug("Got request: " & json)
    let calls = mcp.exec.getCalls(json)
    let responses = collect:
      for call in calls:
        call()
    let resp = calls.dump(responses)
    if resp.isSome:
      debug("Sending reps: " & resp.get())
      echo resp.get()
    else:
      debug "No response needed"
addHandler(newConsoleLogger())
addHandler(newFileLogger("/tmp/toolbelt.log", mode=fmWrite))

mcp.start()
