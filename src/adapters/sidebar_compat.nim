import std/[os, json, sequtils]
import std/monotimes
import results
import ../core/types

type
  SidebarStateFile* = object
    windows*: seq[uint64]
    hidden*: bool

proc readSidebarState*(statePath: string): Result[SidebarStateFile, string] =
  if not fileExists(statePath):
    return err("state file not found: " & statePath)
  try:
    let content = readFile(statePath)
    let j = parseJson(content)
    var state = SidebarStateFile()
    if j.hasKey("windows"):
      for w in j["windows"]:
        state.windows.add(w.getInt.uint64)
    if j.hasKey("hidden"):
      state.hidden = j["hidden"].getBool
    ok(state)
  except CatchableError as e:
    err("failed to parse " & statePath & ": " & e.msg)

proc loadSidebarStates*(stateDir: string, instances: seq[InstanceId]): seq[Event] =
  result = @[]
  for instanceId in instances:
    let path = stateDir / $instanceId / "state.json"
    let stateRes = readSidebarState(path)
    if stateRes.isOk:
      let s = stateRes.get
      result.add Event(
        ts: getMonoTime(),
        kind: evSidebarStateRead,
        sidebarInstanceId: instanceId,
        sidebarWindows: s.windows.mapIt(WindowId(it)),
        sidebarHidden: s.hidden,
      )
