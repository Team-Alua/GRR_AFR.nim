import os
import GoldHENPlugin
import utils
import endians
import strutils

const CUSTOM_ARC_BITOFFSET = 0x5
const MIN_EPISODE_COUNT = 0x20
const MAX_EPISODE_COUNT = 0x32
const MAX_PSARCS = CUSTOM_ARC_BITOFFSET + (MAX_EPISODE_COUNT - 1) - MIN_EPISODE_COUNT

type MountArcDecl = proc(filePath : cstring) : cint {.cdecl.}
var mountArc: MountArcDecl

proc createEpisodeToArcBitOffsetTable(processInfo: ProcessInfo, lookupTableOffset: uint64): cint {.cdecl.} = 
  var newLookupTable : array[MAX_EPISODE_COUNT, byte]
  newLookupTable[0] = 0
  for i in 0x1..<0x8:
    newLookupTable[i] = 1
  for i in 0x8..<0xC:
    newLookupTable[i] = 2
  for i in 0xC..<0x1F:
    newLookupTable[i] = 3
  newLookupTable[0x1F] = 4
  var baseCustomArcIdx = CUSTOM_ARC_BITOFFSET

  for i in MIN_EPISODE_COUNT..<MAX_EPISODE_COUNT:
    newLookupTable[i] = byte(baseCustomArcIdx + i - MIN_EPISODE_COUNT)
  return writeMemory(processInfo, lookupTableOffset, newLookupTable)


proc createArcEpisodeRangeTable(processInfo: ProcessInfo, pairTableOffset: uint64) : cint {.cdecl.} = 
  const ARRAY_SIZE = MAX_PSARCS * 0xC
  var newPairsTable: array[ARRAY_SIZE, byte]
  var pairs: array[MAX_PSARCS, (byte, byte, byte)]
  pairs[0] = (0, 0, 0)
  pairs[1] = (0, 1, 7)
  pairs[2] = (1, 8, 11)
  pairs[3] = (2, 12, 30)
  pairs[4] = (3, 31, 31)

  for i in CUSTOM_ARC_BITOFFSET..<MAX_PSARCS:
    var episode: byte = byte(0x20 + i - CUSTOM_ARC_BITOFFSET)
    # For some reason this needs to be at less than 4
    pairs[i] = (3, episode, episode)

  for index, pair in pairs:
    newPairsTable[index * 0xC + 0] = pair[0]
    newPairsTable[index * 0xC + 0x4] = pair[1]
    newPairsTable[index * 0xC + 0x8] = pair[2]

  return writeMemory(processInfo, pairTableOffset, newPairsTable)

proc applyPatches(processInfo: ProcessInfo): cint {.cdecl.} = 
  let epiToArcTableOffset: uint64 = 0x014093d3
  discard createEpisodeToArcBitOffsetTable(processInfo, epiToArcTableOffset)
  
  let arcEpiRangeTableOffset: uint64 = 0x01409b88
  discard createArcEpisodeRangeTable(processInfo, arcEpiRangeTableOffset)


  ## MountEpisode patches
  # Set max episode to 50
  # cmp edi, 0x32
  discard performPatch(processInfo, 0x001ebfaf, [byte(0x83), 0xFF, MAX_EPISODE_COUNT])
  
  # Change the static array table to new array
  block:
    var patchAddress: uint64 = 0x001ebfb7
    var patch : array[0x07, byte]
    patch[0] = 0x48
    patch[1] = 0x8D
    patch[2] = 0x0D
    var offset: int32 = (epiToArcTableOffset - (patchAddress + patch.len.uint64)).int32
    dec offset, 0x8
    littleEndian32(patch[3].addr, offset.addr)
    discard performPatch(processInfo, patchAddress, patch)
  #
  # Changes max amoumnt of arcs to open
  discard performPatch(processInfo, 0x001ebfc3, [byte(0x83), 0xFB, MAX_PSARCS])

  # Change decimal pairs table address
  block:
    var patchAddress: uint64 = 0x001ec000
    var patch: array[0x7, byte]
    patch[0] = 0x4C
    patch[1] = 0x8D
    patch[2] = 0x35
    var offset: int32 = (arcEpiRangeTableOffset - (patchAddress + patch.len.uint64)).int32
    # It starts weirdly
    inc offset, 0x8
    littleEndian32(patch[3].addr, offset.addr)
    discard performPatch(processInfo, patchAddress, patch)
  
  ## IsEpisodeMounted
  # Changes the max episode amount
  discard performPatch(processInfo, 0x001ecdad, [byte(0x83), 0xf8, MAX_EPISODE_COUNT-1])


  # Changes where it looks for the table
  block:
    var patchAddress: uint64 = 0x001ecdb4
    var patch: array[0x7, byte]
    patch[0] = 0x48
    patch[1] = 0x8D
    patch[2] = 0x0D
    var offset: int32 = (epiToArcTableOffset - (patchAddress + patch.len.uint64)).int32
    dec offset, 0x8
    littleEndian32(patch[3].addr, offset.addr)
    discard performPatch(processInfo, patchAddress, patch)
  return 0  
proc getEpisodeNumberFromFileName(fileName: cstring) : string =
  var underscores: int = 0
  var idx = 0
  while idx < fileName.len:
    if fileName[idx] == '_':
      inc underscores
    inc idx
    if underscores == 4:
      break

  while idx < fileName.len:
    if fileName[idx] == '.':
      break
    result.add(fileName[idx]) 
    inc idx

proc loadArc_hook(fileName: cstring) {.cdecl.} = 
  var episodeNumber: string = getEpisodeNumberFromFileName(fileName)
  var targetPath: string
  if parseint(episodeNumber) < 0x20:
    targetPath = joinPath("/app0/arc/", $fileName)
    echo "Loading...", targetPath
    discard mountArc(targetPath.cstring)
    return

  var overrideFileName = "arc" & episodeNumber & ".psarc" 
  targetPath = joinPath("/data/", "GRR", "arc", overrideFileName)
  echo "Looking for...", targetPath
  if fileExists(targetPath):
    echo $fileName, " => ", targetPath
    discard mountArc(targetPath.cstring)
    return
  else:
    echo "File not found."
  targetPath = joinPath("/app0/arc/", $fileName)
  echo "Loading...", targetPath
  discard mountArc(targetPath.cstring)

proc setup*(processInfo: ProcessInfo): cint {.cdecl.} =
  if applyPatches(processInfo) != 0:
    return -1
  var freeFuncAddress: uint64 = 0x5010
  if createThunkFunction(processInfo, freeFuncAddress, cast[uint64](loadArcHook)) != 0:
    return -1
  mountArc = cast[MountArcDecl](processInfo.baseAddress + 0x001ed860)
  return 0

