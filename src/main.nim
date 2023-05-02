import GoldHENPlugin

import "afr" as cafr
let g_pluginName* {.exportc, dynlib.}: cstring  = "Gravity Rush AFR"
let g_pluginDesc* {.exportc, dynlib.}: cstring  = "This does a basic AFR for GRR"
let g_pluginAuth* {.exportc, dynlib.}: cstring  = "Team-Alua"


const SUPPORTED_TITLE_IDS = [
    "PCAS00035",
    "PCJS50004",
    "PCJS50008",
    "PCJS66015",
    "CUSA00546",
    "CUSA01112",
    "CUSA01113",
    "CUSA01130",
    "CUSA02318",
]

proc isSupportedTitleId(cTitleId: string) : bool =
  for titleId in SUPPORTED_TITLE_IDS:
    if titleId == cTitleId:
      return true
  return false

proc module_start(argc : int64, args: pointer): int32 {.exportc, cdecl.} =
  var processInfo = getProcessInfo()

  if processInfo.isNil:
    echo "Failed to get process info"
    return -1
  if not isSupportedTitleId(processInfo.titleId):
    echo "Title Id ", processInfo.titleId , " not supported."
    return -1

  let setupFuncs = [
#    leh.setup,
#    carc.setup,
    cafr.setup,
  ];

  for setupFunc in setupFuncs:
    let res =  setupFunc(processInfo)
    if res != 0:
      return res
  return 0

proc module_stop(argc : int64, args: pointer): int32 {.exportc, cdecl.} =
  echo "I am in module_stop"
  return 0
