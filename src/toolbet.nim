import std/[json, tables, typetraits, macros, jsonutils, sequtils, sugar, logging, strformat, options]

import pkg/jaysonrpc

import ./toolbet/[utils, types, logging, hooks]


type
  ToolContext = Context[void]
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
    name, title, version, instructions: string

    tools: Table[string, Tool]
    exec: Executor[JsonNode, void]

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

proc initMCP(name, title, version, instructions: string): MCP =
  let mcp = MCP(name: name, title: title, version: version, instructions: instructions, exec: initExecutor[JsonNode, void]())

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
      when type(field) is Context:
        field = ctx
      else:
        field.fromJson(arguments[name])

    # Call the original function
    result = prc.call(args).toJson()

macro getDescription(tool: typed): string =
  let impl = if tool.kind == nnkSym: tool.getImpl() else: tool
  if impl.kind == nnkProcDef:
    return newLit impl[^1].strVal
  else:
    return newLit $impl[^2].extractDocCommentsAndRunnables()[0]

proc generateSchema(typ: typedesc[string]): JsonNode =
  return %* {"type": "string"}

proc generateSchema(typ: typedesc[tuple]): JsonNode =
  result = %* {"type": "object", "required": [], "properties": {}}
  for field, val in default(typ).fieldPairs():
    result["properties"][field] = generateSchema(typeof(val))
    result["required"] &= %field

macro returnType(x: proc): typedesc =
  result = x.getTypeImpl()[0][0]
  echo result.treeRepr

proc add(mcp: var MCP, name, title, description: string, tool: proc) =
  mcp.tools[name] = Tool(
    name: name,
    title: title,
    description: description,
    handler: wrapProc(tool),
    inputSchema: generateSchema(createNamedTuple(tool)),
    outputSchema: generateSchema(returnType(tool))
  )

template add(mcp: var MCP, name, title: string, tool: proc) =
  mcp.add(
    name,
    title,
    getDescription(tool),
    tool
  )

proc start*(mcp: MCP) =
  info("Starting...")
  addHandler(newMCPLogger())

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

when isMainModule:
  var mcp = initMCP(
    "ODBC",
    "ODBC connection",
    "ODBC multiplexer for interacting with mutliple databases",
    """
    Use the `listDatabases` tool to get all the available connections, then use that connection when going forward
    """
  )

  import db_connector/odbcsql

  type DBHandle = ref object
    typ: TSqlSmallInt
    data: SqlHandle

  proc `=destroy`(handle: var typeof(DBHandle()[])) =
    if handle.data != nil:
      discard SQLFreeHandle(handle.typ, handle.data)
      handle.data = nil

  proc checkDB(handle: DBHandle, ret: TSqlSmallInt) =
    if ret != SQL_SUCCESS:
      echo ret
      var
        stateBuffer = newString(6)
        msgBuffer = newString(4096)
        nativeError: TSqlInteger
        msgLength: TSqlSmallInt
      discard SQLGetDiagRec(handle.typ, handle.data, 1, addr stateBuffer[0], nativeError, addr msgBuffer[0], TSqlSmallInt(msgBuffer.len), msgLength)
      msgBuffer.setLen(msgLength)
      echo nativeError
      raise (ref CatchableError)(msg: msgBuffer)

  type
    ConnectionMeta = object
      name, description: string
  proc initHandle(typ: TSqlSmallInt): DBHandle =
    result = DBHandle(typ: typ, data: nil)
    result.checkDB SQLAllocHandle(typ, SQL_NULL_HANDLE, result.data)
    # Set ODBC version for environment handles
    if typ == SQL_HANDLE_ENV:
      result.checkDB SQLSetEnvAttr(result.data, SQL_ATTR_ODBC_VERSION, cast[SqlPointer](SQL_OV_ODBC3), SQL_IS_INTEGER)

  iterator dataSources(): ConnectionMeta =
    let env = initHandle(SQL_HANDLE_ENV)
    var nameBuffer = newString(SQL_MAX_DSN_LENGTH + 1)
    var nameLength: TSqlSmallInt
    var description = newString(255)
    var descriptionLength: TSqlSmallInt
    while true:
      let ret = SQLDataSources(env.data, SQL_FETCH_FIRST, addr nameBuffer[0], TSqlSmallInt(nameBuffer.len), addr nameLength, addr description[0], TSqlSmallInt(description.len), addr descriptionLength)
      echo ret
      if ret == SQL_NO_DATA: break
      env.checkDB ret
      yield ConnectionMeta(name: nameBuffer, description: description)

  for source in dataSources():
    echo source
  # mcp.add("listDatabases", "Get databases") do () -> list[string]:
  #   ## Returns list of all configured database connections
  #   debug "Returning the weather..."
  #   return (msg: "The weather is cloudy with a chance of meat balls")
  # mcp.start()
