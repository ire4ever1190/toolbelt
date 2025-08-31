import std/[json, options]

type
  Info* = object
    name*, version*: string
    title*: Option[string]
  ServerCapabilities* = object
    protocolVersion* = "2025-06-18"
    capabilities*: JsonNode
    serverInfo*: Info
    instructions*: string

  ContentBlock* = object
    `type`*: string
    text*: string

  CallToolResult* = object
    content*: seq[ContentBlock]
