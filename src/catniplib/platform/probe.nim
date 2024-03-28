import os
import strformat
import math
import strutils
import parsecfg
import posix_utils
from unicode import toLower
from "../global/definitions" import DistroId

proc getDistro*(): string =
    ## Returns the name of the running linux distro
    result = "/etc/os-release".loadConfig.getSectionValue("", "PRETTY_NAME") & " " & uname().machine

proc getDistroId*(): DistroId =
    ## Returns the DistroId of the running linux distro
    if fileExists("/boot/issue.txt"): # Check if raspbian else get distroid from /etc/os-release
        result.id = "raspbian"
        result.like = "debian"
    else:
        result.id = "/etc/os-release".loadConfig.getSectionValue("", "ID").toLower()
        result.like = "/etc/os-release".loadConfig.getSectionValue("", "ID_LIKE").toLower()

proc getUptime*(): string =
    ## Returns the system uptime as a string (DAYS, HOURS, MINUTES)

    # Uptime in sec
    let uptime = "/proc/uptime".open.readLine.split(".")[0]

    let
        utu = uptime.parseUInt
        uth = utu div 3600 mod 24 # hours
        utm = utu mod 3600 div 60 # minutes
        utd = utu div 3600 div 24 # days

    if utd == 0 and uth != 0:
      result = &"{uth}h {utm}m" # return hours and mins
    elif uth == 0 and utd == 0:
      result = &"{utm}m" # return only mins
    else:
      result = &"{utd}d {uth}h {utm}m" # return days, hours and mins

proc getHostname*(): string =
    ## Returns the system hostname
    result = uname().nodename

proc getUser*(): string =
    ## Returns the current username
    result = getEnv("USER")

proc getKernel*(): string =
    ## Returns the active kernel version
    result = "/proc/version".open.readLine.split(" ")[2]

proc getParentPid(pid: int): int =
    let statusFilePath = "/proc/" & $pid & "/status"
    let statusLines = readFile(statusFilePath).split("\n")
    for rawline in statusLines:
        let stat = rawline.split(":")
        if stat[0] == "PPid": # Filter CurrentProcessInfo for Parent pid
            let pPid = parseInt(stat[1].strip())
            return pPid
    return -1

proc getProcessName(pid: int): string =
    let statusLines = readFile("/proc/" & $pid & "/status").split("\n")
    for rawLine in statusLines:
        let stat = rawLine.split(":")
        if stat[0] == "Name": # Filter ParentProcessInfo for Parent Name
            return stat[1].strip()

proc getTerminal*(): string =
    ## Returns the currently running terminal emulator
    result = getCurrentProcessID().getParentPid().getParentPid().getProcessName()
    if result == "login" or result == "sshd":
        result = "tty"

proc getShell*(): string =
    ## Returns the system shell
    result = getCurrentProcessID().getParentPid().getProcessName()

proc getDesktop*(): string =
    ## Returns the running desktop env
    result = getEnv("XDG_CURRENT_DESKTOP")
    if result == "":
        if getEnv("XDG_SESSION_TYPE") == "tty": # Check if in tty mode (Method 1)
            result = "Headless"

    if result == "": # Check if in tty mode (Method 2)
        if getTerminal() == "tty":
            result = "Headless"

    if result == "": # Unknown desktop
            result = "Unknown"

proc getMemory*(mb: bool): string =
    ## Returns statistics about the memory
    let 
        fileSeq: seq[string] = "/proc/meminfo".readLines(3)

        dividend: uint = if mb: 1000 else: 1024
        suffix: string = if mb: "MB" else: "MiB"

        memTotalString = fileSeq[0].split(" ")[^2]
        memAvailableString = fileSeq[2].split(" ")[^2]

        memTotalInt = memTotalString.parseUInt div dividend
        memAvailableInt = memAvailableString.parseUInt div dividend

        memUsedInt = memTotalInt - memAvailableInt
  
    result = &"{memUsedInt}/{memTotalInt} {suffix}"

proc getDisk*(): string =
    proc getTotalDiskSpace(): cfloat {.importc, varargs, header: "getDiskSpace.hpp".}
    proc getUsedDiskSpace(): cfloat {.importc, varargs, header: "getDiskSpace.hpp".}

    let total = getTotalDiskSpace().round().int()
    let used = getUsedDiskSpace().round().int()
    let percentage = ((used / total) * 100).round().int()
    result = &"{used} / {total} GB ({percentage}%)"

proc getCpu*(): string =
    let rawLines = readFile("/proc/cpuinfo").split("\n")
    
    var key_name = "model name"
    if getDistroId().id == "raspbian": key_name = "Model"

    for rawLine in rawLines:
        let line = rawLine.split(":")

        if line.len < 2: continue

        let
            key  = line[0].strip()
            val  = line[1].strip()
        if key == key_name: 
            result = val
            break
