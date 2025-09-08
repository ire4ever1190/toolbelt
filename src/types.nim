import std/[json, options, uri]

type
  Info* = object
    name*, version*: string
    title*: Option[string]
  ServerCapabilities* = object
    protocolVersion* = "2025-06-18"
    capabilities*: JsonNode
    serverInfo*: Info
    instructions*: string

  ContentType* = enum
    Text = "text" ## https://modelcontextprotocol.io/specification/2025-06-18/server/tools#text-content
    Image = "image" ## https://modelcontextprotocol.io/specification/2025-06-18/server/tools#image-content
    Audio = "audio" ## https://modelcontextprotocol.io/specification/2025-06-18/server/tools#audio-content
    ResourceLink = "resource_link" ## https://modelcontextprotocol.io/specification/2025-06-18/server/tools#resource-links
    Resource = "resource"

  AudioVisual = object
    data, mimetype: string

  ContentBlock* = object
    case `type`: ContentType
    of Text:
      text*: (string,)
    of Image, Audio:
      data: tuple[data, mimetype: string]
    of ResourceLink:
      link: tuple[uri: Uri, name, description, mimeType: string]
    of Resource:
      embed: tuple[uri: Uri, name, title, mimeType, text: string]

  CallToolResult* = object
    content*: seq[ContentBlock]
    structuredContent*: JsonNode
    isError*: bool
