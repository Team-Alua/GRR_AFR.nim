import strutils
import os
import streams
import GoldHENPlugin
import utils


proc createCallPatches(processInfo: ProcessInfo): cint {.cdecl.} = 
  # Ordered by call address. Least to greatest address
  discard performPatch(processInfo, 0x001f471c, [byte(0xE8), 0xDF, 0x01, 0xE1, 0xFF])
  discard performPatch(processInfo, 0x001f47c3, [byte(0xE9), 0x38, 0x01, 0xE1, 0xFF])
  discard performPatch(processInfo, 0x001f49f1, [byte(0xE8), 0x0A, 0xFF, 0xE0, 0xFF])
  discard performPatch(processInfo, 0x001f4aa3, [byte(0xE9), 0x58, 0xFE, 0xE0, 0xFF])
  discard performPatch(processInfo, 0x00d717c7, [byte(0xE8), 0x34, 0x31, 0x29, 0xFF])
  discard performPatch(processInfo, 0x00d748bf, [byte(0xE8), 0x3C, 0x00, 0x29, 0xFF])
  return 0

type LuaExecCode = proc(luaState: pointer, code:pointer, codeLength: uint64, filepath: cstring) : cint {.cdecl.}

var luaExec : LuaExecCode 



proc luaExec_hook(luaState:pointer, code: pointer, codeLength: uint64, filepath: cstring): cint {.cdecl.} = 
  var luaFilePath = toLowerAscii($filepath)
  var targetFilePath = joinPath("/data", "GRR", luaFilePath)
  var fileStream = newFileStream(targetFilePath)
  echo "(LuaExec) Path: ", filepath
  if fileStream.isNil:
    return luaExec(luaState, code, codeLength, filepath)
  echo "(LuaExec) ", $filepath, " => " , targetFilePath
  var userCode = fileStream.readAll() 
  var res = luaExec(luaState, userCode.cstring, userCode.len.uint64, filepath)
  if res != 0:
    echo "(LuaExec) Failed to execute: ", targetFilePath
    return luaExec(luaState, code, codeLength, filepath)
  return res

proc setup*(processInfo: ProcessInfo) : cint {.cdecl.} = 
  if createCallPatches(processInfo) != 0:
    return -1
  luaExec = cast[LuaExecCode](processInfo.baseAddress + 0x00d5ce20)
  var freeFuncAddress: uint64 = 0x4900
  if createThunkFunction(processInfo, freeFuncAddress, cast[uint64](luaExec_hook)) != 0:
    return -1
  echo "Successfully applied patches"
  return 0

