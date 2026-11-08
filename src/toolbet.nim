import std/[json, tables, typetraits, macros, jsonutils, sequtils, sugar, logging, strformat, options]

import pkg/[jaysonrpc, casserole]

import ./[utils, types, mcpLogging, hooks, schema]

import mike/app
import mike

export jaysonrpc, json

type
  ToolContext = jaysonrpc.Context[MCP]
  ToolHandler = proc (ctx: ToolContext, arguments: Table[string, JsonNode]): JsonNode
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
    instructions: string
    tools: Table[string, Tool]
    exec: Executor[JsonNode, MCP]

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

proc initMCP*(name, title, version, instructions: string): MCP =
  let mcp = MCP(name: name, title: title, version: version, exec: initExecutor[JsonNode, MCP](), instructions: instructions)

  mcp.exec.on("tools/list") do () -> tuple[tools: seq[Tool]]:
    debug "Returning tools " & $toSeq(mcp.tools.values())
    return (tools: toSeq(mcp.tools.values()))

  mcp.exec.on("ping") do () -> JsonNode:
    newJObject()

  mcp.exec.on("server/discover") do () -> DiscoverResult:
    result = DiscoverResult(
      resultType: "complete",
      supportedVersions: @["2026-07-28"],
      capabilities: ServerCapabilities(tools: some((listChanged: false))),
      instructions: mcp.instructions
    )

  # Support the old initialize method
  mcp.exec.on("initialize") do (protocolVersion: string, capabilities: JsonNode, clientInfo: Info) -> StatefulServerCapabilities:
    info(fmt"Client {clientInfo.name} connected")
    result = default(StatefulServerCapabilities)
    result.capabilities = %* {
      "tools": {
        "listChanged": false,
        "logging": {}
      }
    }
    result.serverInfo = Info(title: some name, name: name, version: version)
    result.instructions = instructions

  mcp.exec.on("tools/call") do (ctx: ToolContext, name: string, arguments: Table[string, JsonNode]) -> CallToolResult:
    let meth = mcp.tools[name].handler
    let res = meth(ctx, arguments)
    result = CallToolResult(
      content: @[
        ContentBlock(`type`: Text, text: res.pretty())
      ],
      structuredContent: res
    )
    debug $result

  mcp.exec.on("notifications/initialized") do ():
    info("Client is ready")

  mcp.exec.on("notifications/cancelled") do (requestId: JsonNode, reason: string, ctx: ToolContext):
    info(fmt"Cancelling request {requestId} because {reason}")
    ctx.cancel(requestId)

  return mcp

proc wrapProc(prc: proc): ToolHandler =
  proc (ctx: ToolContext, arguments: Table[string, JsonNode]): JsonNode =
    # Parse everything into the args
    var args = default(createNamedTuple(prc))
    for name, field in args.fieldPairs:
      when type(field) is jaysonrpc.Context:
        field = ctx
      else:
        field.fromJson(data[name])

    # Call the original function
    result = prc.call(args).toJson()

    # Attach metadata fields
    result["_meta"] = %*{
      "io.modelcontextprotocol/serverInfo": Info(title: some ctx.data.name, name: ctx.data.name, version: ctx.data.version)
    }

macro getDescription(tool: typed): string =
  let impl = if tool.kind == nnkSym: tool.getImpl() else: tool
  if impl.kind == nnkProcDef:
    return newLit impl[^1].strVal
  else:
    return newLit $impl[^2].extractDocCommentsAndRunnables()[0]

macro returnType(x: proc): typedesc =
  result = x.getTypeImpl()[0][0]
  echo result.treeRepr

proc add*(mcp: var MCP, name, title, description: string, tool: proc) =
  mcp.tools[name] = Tool(
    name: name,
    title: title,
    description: description,
    handler: wrapProc(tool),
    inputSchema: generateSchema(createNamedTuple(tool)),
    outputSchema: generateSchema(returnType(tool))
  )

template add*(mcp: var MCP, name, title: string, tool: proc) =
  mcp.add(
    name,
    title,
    getDescription(tool),
    tool
  )



proc startStdio*(mcp: MCP) =
  ## Starts MCP over stdio
  info("Starting...")
  while true:
    let json = stdin.readline()
    debug("Got request: " & json)
    let calls = mcp.exec.getCalls(json, mcp)
    let responses = collect:
      for call in calls:
        call()
    let resp = calls.dump(responses)
    if resp.isSome:
      debug("Sending reps: " & resp.get())
      echo resp.get()
    else:
      debug "No response needed"

proc use*(app: var App, mcp: MCP, path: static[string] = "/mcp") =
  ## Adds a MCP server to mike
  app.post(path) do (body: Payload[string], ctx: mike.Context) -> JsonNode:
    let calls = mcp.exec.getCalls(body, mcp)
    let responses = collect:
      for call in calls:
        call()
    if Some(resp) ?== calls.dump(responses):
      return resp.parseJson()
    return %* {}
