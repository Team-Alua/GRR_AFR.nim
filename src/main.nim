import endians 
import strutils
import hash_lookup
import tables
import md5
import GoldHENPlugin

let g_pluginName* {.exportc, dynlib.}: cstring  = "Gravity Rush AFR"
let g_pluginDesc* {.exportc, dynlib.}: cstring  = "This does a basic AFR for GRR"
let g_pluginAuth* {.exportc, dynlib.}: cstring  = "Team-Alua"

type FiosReadResult = object
  unk1: uint64
  unk2: array[0x18, byte]
  size: uint64

type LuaExecCode = proc(luaState: pointer, code:cstring, codeLength: uint64, filepath: cstring) : cint {.cdecl.}

var luaExec: LuaExecCode


proc luaExec_hook(luaState: pointer, code: cstring, codeLength: uint64, filepath: cstring): cint {.cdecl.} =
  echo "Code Length:", codeLength, " filepath: ", filepath 
  luaExec(luaState, code, codeLength, filepath)


proc performPatch(processInfo: ProcessInfo, offset: uint64, patch: openArray[byte]) : cint =
  var patchAddress = processInfo.baseAddress + offset
  if writeMemory(processInfo, offset, patch) != 0:
    echo "Failed to patch memory at " , toHex(patchAddress)
    return -1
  return 0

proc createCallPatches(processInfo: ProcessInfo): cint {.cdecl.} = 
  # Ordered by call address. Least to greatest address
  discard performPatch(processInfo, 0x001f471c, [byte(0xE8), 0xDF, 0x01, 0xE1, 0xFF])
  discard performPatch(processInfo, 0x001f47c3, [byte(0xE9), 0x38, 0x01, 0xE1, 0xFF])
  discard performPatch(processInfo, 0x001f49f1, [byte(0xE8), 0x0A, 0xFF, 0xE0, 0xFF])
  discard performPatch(processInfo, 0x001f4aa3, [byte(0xE9), 0x58, 0xFE, 0xE0, 0xFF])
  discard performPatch(processInfo, 0x00d717c7, [byte(0xE8), 0x34, 0x31, 0x29, 0xFF])
  discard performPatch(processInfo, 0x00d748bf, [byte(0xE8), 0x3C, 0x00, 0x29, 0xFF])
  return 0

proc createThunkFunction(processInfo: ProcessInfo, unusedFuncAddress: uint64, jumpAddress: uint64): cint {.cdecl.} =
  var arbitraryJumpPatch = [
        byte(0xFF), 0x25, 0x00, 0x00, 0x00, 0x00, # jmp qword ptr [$+6]
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 # ptr
  ]
  littleEndian64(arbitraryJumpPatch[6].addr, jumpAddress.addr)
  if writeMemory(processInfo, unusedFuncAddress, arbitraryJumpPatch) != 0:
    echo "Failed to patch memory"
    return -1
  return 0

proc module_start(argc : int64, args: pointer): int32 {.exportc, cdecl.} =
  var processInfo = getProcessInfo()

  if processInfo.isNil:
    echo "Failed to get process info"
    return -1

  if processInfo.titleId != "CUSA01130":
    echo "Unsupported process"
    return -1

  if createCallPatches(processInfo) != 0:
    return -1

  luaExec = cast[LuaExecCode](processInfo.baseAddress + 0x00d5ce20)

  var freeFuncAddress: uint64 = 0x4900
  if createThunkFunction(processInfo, freeFuncAddress, cast[uint64](luaExec_hook)) != 0:
    return -1

  echo "Successfully applied patches"
  return 0

proc module_stop(argc : int64, args: pointer): int32 {.exportc, cdecl.} =
  echo "I am in module_stop"
  return 0
