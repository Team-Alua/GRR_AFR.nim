import "luaexec" as leh
import "customarc" as carc
let g_pluginName* {.exportc, dynlib.}: cstring  = "Gravity Rush AFR"
let g_pluginDesc* {.exportc, dynlib.}: cstring  = "This does a basic AFR for GRR"
let g_pluginAuth* {.exportc, dynlib.}: cstring  = "Team-Alua"


proc module_start(argc : int64, args: pointer): int32 {.exportc, cdecl.} =
  let setupFuncs = [
    leh.setup,
    carc.setup
  ];
  for setupFunc in setupFuncs:
    let res =  setupFunc()
    if res != 0:
      return res
  return 0

proc module_stop(argc : int64, args: pointer): int32 {.exportc, cdecl.} =
  echo "I am in module_stop"
  return 0
