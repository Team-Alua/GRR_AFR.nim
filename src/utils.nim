import endians
import strutils
import GoldHENPlugin

proc performPatch*(processInfo: ProcessInfo, offset: uint64, patch: openArray[byte]) : cint =
  var patchAddress = processInfo.baseAddress + offset
  if writeMemory(processInfo, offset, patch) != 0:
    echo "Failed to patch memory at " , toHex(patchAddress)
    return -1
  return 0

proc createThunkFunction*(processInfo: ProcessInfo, unusedFuncAddress: uint64, jumpAddress: uint64): cint {.cdecl.} =
  var arbitraryJumpPatch = [
        byte(0xFF), 0x25, 0x00, 0x00, 0x00, 0x00, # jmp qword ptr [$+6]
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 # ptr
  ]
  littleEndian64(arbitraryJumpPatch[6].addr, jumpAddress.addr)
  if writeMemory(processInfo, unusedFuncAddress, arbitraryJumpPatch) != 0:
    echo "Failed to patch memory"
    return -1
  return 0
