import std/[tables, options, sequtils]
import types

proc removeFromSeq(s: var seq[WindowId], val: WindowId) =
  var i = 0
  while i < s.len:
    if s[i] == val:
      s.del(i)
    else:
      inc i

proc assignWindow*(state: var ShellState, windowId: WindowId, instanceId: InstanceId) =
  if windowId in state.ownership:
    let existing = state.ownership[windowId]
    if existing != instanceId and existing in state.instances:
      removeFromSeq(state.instances[existing].windowIds, windowId)

  state.ownership[windowId] = instanceId
  if instanceId in state.instances and windowId notin state.instances[instanceId].windowIds:
    state.instances[instanceId].windowIds.add(windowId)

proc removeWindow*(state: var ShellState, windowId: WindowId) =
  if windowId in state.ownership:
    let instanceId = state.ownership[windowId]
    if instanceId in state.instances:
      removeFromSeq(state.instances[instanceId].windowIds, windowId)
  state.ownership.del(windowId)

proc ownerOf*(state: ShellState, windowId: WindowId): Option[InstanceId] =
  if windowId in state.ownership: some(state.ownership[windowId]) else: none(InstanceId)

proc windowsOf*(state: ShellState, instanceId: InstanceId): seq[WindowId] =
  if instanceId in state.instances: state.instances[instanceId].windowIds else: @[]

proc repair*(state: var ShellState): seq[string] =
  var repairs: seq[string] = @[]

  var orphanOwnership: seq[WindowId] = @[]
  for windowId, instanceId in state.ownership:
    if instanceId notin state.instances:
      orphanOwnership.add(windowId)
    elif windowId notin state.instances[instanceId].windowIds:
      state.instances[instanceId].windowIds.add(windowId)
      repairs.add("Added missing window " & $windowId & " to instance " & $instanceId & " windowIds")

  for windowId in orphanOwnership:
    repairs.add("Removed orphan ownership: window " & $windowId)
    state.ownership.del(windowId)

  for instanceId, instance in state.instances:
    for windowId in instance.windowIds:
      if windowId notin state.ownership:
        state.ownership[windowId] = instanceId
        repairs.add("Added missing ownership: window " & $windowId & " -> instance " & $instanceId)

  var deadWindows: seq[WindowId] = @[]
  for windowId in state.ownership.keys.toSeq:
    if windowId notin state.windows:
      deadWindows.add(windowId)
  for windowId in deadWindows:
    removeWindow(state, windowId)
    repairs.add("Removed dead window " & $windowId & " from ownership")

  repairs
