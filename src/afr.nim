import GoldHENPlugin
import endians
import utils
import strutils
import posix

type FiosFindAbsPathDecl = proc(foundPath: ptr array[256, char], relativePath: cstring, fileType: cint) : cint {.cdecl.} 
var fiosFindAbsPath : FiosFindAbsPathDecl

proc fiosFindAbsPath_hook(foundPath: ptr array[256, char], relativePath: cstring, fileType: cint): cint {.cdecl.} = 
  if relativePath[0] == '\x00':
    return fiosFindAbsPath(foundPath, relativePath, fileType)

  const overrideDir = "/data/GRR/"
  var newPath: array[256, char]
  var newPathLength : int
  for idx in 0..<overrideDir.len:
    newPath[idx] = overrideDir[idx]
    newPathLength = newPathLength + 1 
  var startIdx = newPathLength
  # Lower case all upper case letters
  for idx in 0..<relativePath.len:
    newPath[idx + startIdx] = relativePath[idx]
    newPathLength = newPathLength + 1

  for idx in startIdx..<newPathLength:
    if not (newPath[idx] < 'A' or newPath[idx] > 'Z'):
      newPath[idx] = char((newPath[idx].byte - 'A'.byte) + 'a'.byte)
  # remove duplicate // 
  for idx in 0..(newPathLength - 2):
    if newPath[idx] == '/' and newPath[idx + 1] == '/':
      for idx2 in (idx+1)..(newPathLength - 1):
        newPath[idx2-1] = newPath[idx2]
      newPathLength = newPathLength - 1
      newPath[newPathLength] = '\x00'

  if fileType == 1:
    var fd = open(cast[cstring](newPath[0].addr), O_DIRECTORY, 0777)
    if fd == -1:
      return fiosFindAbsPath(foundPath, relativePath, fileType)
    discard close(fd)
    for idx in 0..newPath.len:
      if newPath[idx] == '\x00':
        break
      foundPath[][idx] = newPath[idx]
    return 0
  var fd = open(cast[cstring](newPath[0].addr), O_RDONLY, 0777)
  if fd == -1:
    return fiosFindAbsPath(foundPath, relativePath, fileType)
  discard close(fd)

  for idx in 0..newPath.len:
    foundPath[][idx] = newPath[idx]
    if newPath[idx] == '\x00':
      break
  return 0

proc writeCall(processInfo: ProcessInfo, callOffset: uint64, newFunctionOffset: uint64) : cint {.cdecl.} = 
  # Assume it's a 5 byte 0xE8 instruction
  var patch: array[5, byte]
  patch[0] = 0xE8

  var offset: int32 = (callOffset.int32 + patch.len.int32) # relative rip
  offset = newFunctionOffset.int32 - offset
  if newFunctionOffset.int32 < offset:
    offset = -offset

  littleEndian32(patch[1].addr, offset.addr)
  return writeMemory(processInfo,callOffset, patch)

proc applyPatches(processInfo: ProcessInfo, newFunctionOffset: uint64) : cint {.cdecl.} =
  discard writeCall(processInfo, 0x51A2, newFunctionOffset)
  discard writeCall(processInfo, 0x549F, newFunctionOffset)
  discard writeCall(processInfo, 0x5A02, newFunctionOffset)
  discard writeCall(processInfo, 0x5CDD, newFunctionOffset)
  discard writeCall(processInfo, 0x5FED, newFunctionOffset)
  discard writeCall(processInfo, 0x62AE, newFunctionOffset)
  discard writeCall(processInfo, 0x6474, newFunctionOffset)
  return 0
proc setup*(processInfo: ProcessInfo): cint {.cdecl.} =
  # This does the synchronous file reading
  var freeFuncAddress: uint64 = 0x4900
  if createThunkFunction(processInfo, freeFuncAddress, cast[uint64](fiosFindAbsPath_hook)) != 0:
    return -1
  if applyPatches(processInfo, freeFuncAddress) != 0:
    return -1
  fiosFindAbsPath = cast[FiosFindAbsPathDecl](processInfo.baseAddress + 0x52C0)
  return 0

