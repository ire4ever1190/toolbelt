import uriTemplates
import std/unittest

const uriTemp = "file://folder/{folder}/{file}"

test "Can create a matcher":
  let file = urlTemplate.match(uriTemp).get().matcher().match("file://folder/fod/test.nim").get()
  check file == @["fod", "test.nim"]

test "Can grab variable names":
  const varNames = uriTemp.variableNames()
  check varNames == @["folder", "file"]
