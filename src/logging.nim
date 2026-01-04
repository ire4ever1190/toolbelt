import std/[logging, strutils, jsonutils]

import pkg/jaysonrpc

type
  MCPLogger = ref object of Logger

func newMCPLogger*(): MCPLogger =
  result = MCPLogger(fmtStr: defaultFmtStr)

const
  logCall = MethodDef[tuple[level: string, logger: string, data: JsonNode], void](name: "notifications/message")

method log*(logger: MCPLogger, level: Level, args: varargs[string, `$`]) {.gcsafe.} =
  {.gcsafe.}:
    echo logCall.notify(($level, "server", %*{"msg": args.join("")})).toJson()
