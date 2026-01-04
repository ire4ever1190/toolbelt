import std/[json, jsonutils]
import ./[types, utils]

proc toJsonHook*(content: ContentBlock, opt = initToJsonOptions()): JsonNode =
  result = %*{"type": $content.`type`}
  result.update(case content.`type`
                  of Text:
                    %* {"text": content.text}
                  of Image, Audio: content.data.toJson(opt)
                  of ResourceLink: content.link.toJson(opt)
                  of Resource: content.link.toJson(opt))
