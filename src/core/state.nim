import std/[options, tables, sequtils]
import types
import ownership
import profile
import keymap

proc resolvedSame(a, b: Option[ResolvedProfile]): bool =
  if a.isNone and b.isNone:
    return true
  if a.isSome != b.isSome:
    return false
  let av = a.get
  let bv = b.get
  av.profile.id == bv.profile.id and av.instanceId == bv.instanceId and av.state == bv.state

proc findCommand*(state: ShellState, id: CommandId): Option[Command] =
  if state.resolved.isNone: return none(Command)
  for cmd in state.resolved.get.profile.commands:
    if cmd.id == id: return some(cmd)
  none(Command)

proc reduce*(state: var ShellState, event: Event, profiles: Table[PluginId, Profile], pluginPatterns: seq[tuple[pluginId: PluginId, patterns: seq[string]]], instanceDefaults: Table[InstanceId, PluginId]): seq[Effect] =
  result = @[]
  case event.kind
  of evWindowOpened, evWindowChanged:
    state.windows[event.window.id] = event.window
  of evWindowClosed:
    state.windows.del(event.closedWindowId)
    removeWindow(state, event.closedWindowId)
    if state.focusedWindowId == some(event.closedWindowId):
      state.focusedWindowId = none(WindowId)
  of evWindowFocused:
    state.focusedWindowId = event.focusedId
    let prev = state.resolved
    state.resolved = resolveProfile(state, profiles, pluginPatterns, instanceDefaults)
    if not resolvedSame(state.resolved, prev):
      if state.resolved.isSome:
        let r = state.resolved.get
        state.keymap = rebuildKeymap(r.profile.commands, r.state, r.profile.id)
        if r.profile.kanataLayer.isSome and r.profile.kanataLayer.get != state.kanataLayer:
          result.add Effect(kind: efChangeKanataLayer, layer: r.profile.kanataLayer.get)
      else:
        state.keymap = KeymapState()
      result.add Effect(kind: efNotifySubscribers)
  of evWorkspaceActivated:
    discard
  of evKanataConnected:
    state.kanataConnected = true
  of evKanataDisconnected:
    state.kanataConnected = false
  of evKanataLayerChanged:
    state.kanataLayer = event.newLayer
  of evKanataMessage:
    discard
  of evSidebarStateRead:
    if event.sidebarInstanceId in state.instances:
      state.instances[event.sidebarInstanceId].windowIds = event.sidebarWindows
      state.instances[event.sidebarInstanceId].hidden = event.sidebarHidden
      state.instances[event.sidebarInstanceId].state = (if event.sidebarHidden: Hidden else: Active)
      for wid in event.sidebarWindows:
        state.ownership[wid] = event.sidebarInstanceId
    result.add Effect(kind: efNotifySubscribers)
  of evActivateInstance:
    state.activeInstance = some(event.targetInstance)
    let prev = state.resolved
    state.resolved = resolveProfile(state, profiles, pluginPatterns, instanceDefaults)
    if not resolvedSame(state.resolved, prev):
      if state.resolved.isSome:
        let r = state.resolved.get
        state.keymap = rebuildKeymap(r.profile.commands, r.state, r.profile.id)
      else:
        state.keymap = KeymapState()
      result.add Effect(kind: efNotifySubscribers)
  of evToggleVisibility:
    if event.toggleInstance in state.instances:
      state.instances[event.toggleInstance].hidden = not state.instances[event.toggleInstance].hidden
      state.instances[event.toggleInstance].state = (if state.instances[event.toggleInstance].hidden: Hidden else: Active)
      result.add Effect(kind: efNotifySubscribers)
  of evPrefixAdvance:
    if state.resolved.isSome:
      let r = state.resolved.get
      let trie = buildTrie(r.profile.commands.filterIt(r.state in it.whenStates))
      advancePrefix(state.keymap, event.key, trie)
    result.add Effect(kind: efNotifySubscribers)
  of evPrefixReset:
    if state.resolved.isSome:
      let r = state.resolved.get
      let available = r.profile.commands.filterIt(r.state in it.whenStates)
      let trie = buildTrie(available)
      resetPrefix(state.keymap, r.profile.commands, r.state, trie)
    result.add Effect(kind: efNotifySubscribers)
  of evFilterSet:
    if state.resolved.isSome:
      let r = state.resolved.get
      setFilter(state.keymap, event.filterText, r.profile.commands, r.state)
    result.add Effect(kind: efNotifySubscribers)
  of evCommandInvoked:
    let cmd = findCommand(state, event.commandId)
    if cmd.isSome:
      result.add Effect(kind: efExecuteAction, action: cmd.get.action)
    if state.resolved.isSome:
      let r = state.resolved.get
      let available = r.profile.commands.filterIt(r.state in it.whenStates)
      let trie = buildTrie(available)
      resetPrefix(state.keymap, r.profile.commands, r.state, trie)
    result.add Effect(kind: efNotifySubscribers)
  of evConfigReloaded:
    state.config = event.newConfig
    result.add Effect(kind: efNotifySubscribers)
  of evTimerFired:
    discard

proc initShellState*(config: SidebardConfig): ShellState =
  ShellState(
    windows: initTable[WindowId, NiriWindow](),
    focusedWindowId: none(WindowId),
    instances: initTable[InstanceId, SidebarInstance](),
    activeInstance: none(InstanceId),
    ownership: initTable[WindowId, InstanceId](),
    resolved: none(ResolvedProfile),
    keymap: KeymapState(),
    kanataConnected: false,
    kanataLayer: "",
    config: config,
  )
