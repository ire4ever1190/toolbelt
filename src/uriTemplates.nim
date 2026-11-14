## Implements a basic version (i.e. features I care about) version of
## [RFC-6570](https://datatracker.ietf.org/doc/html/rfc6570) so basically just
## variables

import pkg/[nort, casserole]
import std/[strutils, parseutils]

export nort

type
  URIPart {.cased.} = object
    case
    of Literal:
      val: string
    of Variable:
      name: string

  URITemplate = seq[URIPart]


# Grammars

let
  varName = +e(IdentStartChars - {'_'})

  variable = varName.between(e'{', e'}').map do (name: string) -> URIPart:
    URIPart.Variable(name)

  literal = (+((not e({'{', '}'})) * dot())).map do (value: string) -> URIPart:
    URIPart.Literal(value)

  urlTemplate* = +(literal | variable)
    ## Grammar for matching a URL template

proc matcher*(temp: URITemplate): Combinator[seq[string]] =
  ## Creates a combinator for matching a URL template
  result = succeed(newSeq[string]())
  for part in temp:
    case part
    of Literal(val):
      result = result <* e(val)
    of Variable(_):
      result = map(result <*> dot().until(e'/')) do (inp: (seq[string], string)) -> seq[string]:
        result = inp[0]
        result &= inp[1]

proc variableNames*(uriTemplate: string): seq[string] =
  ## Very simple parser to get the names. Lets us run it at compile time
  var i = 0
  while i < uriTemplate.len:
    i += uriTemplate.skipUntil('{', i) + 1
    var name: string
    i += uriTemplate.parseUntil(name, '}', i) + 1
    result &= name
