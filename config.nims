# begin Nimble config (version 2)
when withDir(thisDir(), system.fileExists("nimble.paths")):
  include "nimble.paths"
# end Nimble config
switch("d", "jaysonrpc.allowExtraArguments")
switch("d", "ssl")
switch("d", "chronicles_sinks=textblocks")
