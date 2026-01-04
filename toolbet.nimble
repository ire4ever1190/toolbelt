# Package

version       = "0.1.0"
author        = "Jake Leahy"
description   = "MCP library"
license       = "MIT"
srcDir        = "src"
installExt    = @["nim"]
bin           = @["toolbet"]


# Dependencies

requires "nim >= 2.0.0"
requires "gh:ire4ever1190/jaysonrpc#0f1f4fc"
requires "db_connector"
