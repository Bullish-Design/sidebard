import std/[options, strutils, sequtils, sets]
import types

type
  ApiWindow* = object
    id*: uint64
    appId*: Option[string]
    title*: Option[string]
    workspaceId*: Option[uint64]
    isFocused*: bool
    isFloating*: bool
  ApiSidebarInstance* = object
    id*: string
    position*: string
    state*: string
    windowIds*: seq[uint64]
    hidden*: bool
  ApiCommand* = object
    id*: string
    title*: string
    description*: string
    category*: string
    tags*: seq[string]
    sequence*: seq[string]
    dangerous*: bool
  ApiKeymapState* = object
    profileId*: string
    prefix*: seq[string]
    filter*: string
    available*: seq[ApiCommand]
    nextKeys*: seq[string]
    exactMatch*: Option[ApiCommand]
  ApiResolvedProfile* = object
    profileId*: string
    pluginId*: string
    title*: string
    instanceId*: string
    state*: string
    kanataLayer*: Option[string]
  ApiStateSnapshot* = object
    focusedWindowId*: Option[uint64]
    activeInstance*: Option[string]
    resolved*: Option[ApiResolvedProfile]
    keymap*: ApiKeymapState
    kanataConnected*: bool
    kanataLayer*: string

proc toApi*(w: NiriWindow): ApiWindow =
  ApiWindow(id: uint64(w.id), appId: w.appId, title: w.title, workspaceId: (if w.workspaceId.isSome: some(uint64(w.workspaceId.get)) else: none(uint64)), isFocused: w.isFocused, isFloating: w.isFloating)
proc toApi*(inst: SidebarInstance): ApiSidebarInstance =
  ApiSidebarInstance(id: $inst.id, position: ($inst.position).toLowerAscii, state: ($inst.state).toLowerAscii, windowIds: inst.windowIds.mapIt(uint64(it)), hidden: inst.hidden)
proc toApi*(cmd: Command): ApiCommand =
  ApiCommand(id: $cmd.id, title: cmd.title, description: cmd.description, category: cmd.category, tags: cmd.tags.toSeq, sequence: cmd.sequence.mapIt($it), dangerous: cmd.dangerous)
proc toApi*(ks: KeymapState): ApiKeymapState =
  ApiKeymapState(profileId: $ks.profileId, prefix: ks.prefix.mapIt($it), filter: ks.filter, available: ks.available.mapIt(it.toApi), nextKeys: ks.nextKeys.mapIt($it), exactMatch: (if ks.exactMatch.isSome: some(ks.exactMatch.get.toApi) else: none(ApiCommand)))
proc toApi*(rp: ResolvedProfile): ApiResolvedProfile =
  ApiResolvedProfile(profileId: $rp.profile.id, pluginId: $rp.profile.pluginId, title: rp.profile.title, instanceId: $rp.instanceId, state: ($rp.state).toLowerAscii, kanataLayer: rp.profile.kanataLayer)
proc toApiSnapshot*(state: ShellState): ApiStateSnapshot =
  ApiStateSnapshot(
    focusedWindowId: (if state.focusedWindowId.isSome: some(uint64(state.focusedWindowId.get)) else: none(uint64)),
    activeInstance: (if state.activeInstance.isSome: some($state.activeInstance.get) else: none(string)),
    resolved: (if state.resolved.isSome: some(state.resolved.get.toApi) else: none(ApiResolvedProfile)),
    keymap: state.keymap.toApi,
    kanataConnected: state.kanataConnected,
    kanataLayer: state.kanataLayer,
  )
