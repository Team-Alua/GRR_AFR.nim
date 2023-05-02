import std/strutils
import os
--os:orbis
switch "o", "grr_afr.elf"
switch "app", "lib"
switch "noMain", "on"
switch "nimcache", "./cache"
switch "threads", "off"
switch "stackTrace", "off"

proc getOOBinaryPath(binName: string): string =
  var osDir: string
  if hostOS == "linux":
    osDir = "linux"
  elif hostOS == "windows":
    osDir = "windows"
  elif hostOS == "darwin":
    osDir = "macos"
  else:
    raise newException(ValueError, "Invalid host os $#" % hostOS)
  

  result.addf("$#/bin/$#/$#",getEnv("OO_PS4_TOOLCHAIN"), osDir, binName)
  if ExeExt != "":
    result = addFileExt(result, ExeExt)

proc executeCmd(cmd: string) = 
  # echo "Executing: ", cmd
  exec cmd

proc generateLibrary(elfIn:string, libPath: string) =
  var fselfBin = getOOBinaryPath("create-fself")
  var fselfParamFmt = "$# --lib=$# -in=$# --paid 0x3800000000000010"
  executeCmd(fselfParamFmt % [fselfBin, libPath, elfIn, elfIn])

task build_lib, "builds a sample library":
  var paramsList = os.commandLineParams()
  var extraParams : string
  if paramsList.len > 1:
    extraParams.add(paramsList[1..^1].join(" ")) 
  echo extraParams
  selfExec "c --os:orbis -d:ghLibrary -d:nimAllocPagesViaMalloc " & extraParams
  if getEnv("OO_PS4_TOOLCHAIN") == "":
    raise newException(ValueError, "Must set OO_PS4_TOOLCHAIN environment variable")
  generateLibrary("grr_afr.elf", "grr_afr.prx")

