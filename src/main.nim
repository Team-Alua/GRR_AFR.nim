import hash_lookup
import hashes
let g_pluginName* {.exportc, dynlib.}: cstring  = "Gravity Rush AFR"
let g_pluginDesc* {.exportc, dynlib.}: cstring  = "This does a basic AFR for GRR"
let g_pluginAuth* {.exportc, dynlib.}: cstring  = "Team-Alua"

type FiosReadResult = object
  unk1: array[0x18, byte]
  size: uint64

var original_cb: proc(unk1: pointer, unk2:pointer) {.cdecl.}

proc fios_read_cb(unk1: pointer, readResult: ptr FiosReadResult) {.cdecl.} =
  if readResult.isNil:
    original_cb(unk1, readResult)
    return
  var rr = readResult[] 

  var filesize = rr.size - 32
  let dataOffset = cast[int64](readResult) + 32
  var dataHash = hashData(cast[pointer](dataOffset), filesize.int)
  echo "The hash is ", dataHash
  original_cb(unk1, readResult)

proc module_start(argc : int64, args: pointer): int32 {.exportc, cdecl.} =
  echo "I am in module_start"
  return 0

proc module_stop(argc : int64, args: pointer): int32 {.exportc, cdecl.} =
  echo "I am in module_stop"
  return 0
