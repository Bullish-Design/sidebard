import std/[options, sets, tables, hashes]
import std/monotimes
import results

type
  WindowId* = distinct uint64
  WorkspaceId* = distinct uint64
  OutputId* = distinct string
  InstanceId* = distinct string
  PluginId* = distinct string
  ProfileId* = distinct string
  CommandId* = distinct string

proc `==`*(a, b: WindowId): bool {.borrow.}
proc hash*(a: WindowId): Hash {.borrow.}
proc `$`*(a: WindowId): string {.borrow.}
proc `==`*(a, b: WorkspaceId): bool {.borrow.}
proc hash*(a: WorkspaceId): Hash {.borrow.}
proc `$`*(a: WorkspaceId): string {.borrow.}
proc `==`*(a, b: OutputId): bool {.borrow.}
proc hash*(a: OutputId): Hash {.borrow.}
proc `$`*(a: OutputId): string {.borrow.}
proc `==`*(a, b: InstanceId): bool {.borrow.}
proc hash*(a: InstanceId): Hash {.borrow.}
proc `$`*(a: InstanceId): string {.borrow.}
proc `==`*(a, b: PluginId): bool {.borrow.}
proc hash*(a: PluginId): Hash {.borrow.}
proc `$`*(a: PluginId): string {.borrow.}
proc `==`*(a, b: ProfileId): bool {.borrow.}
proc hash*(a: ProfileId): Hash {.borrow.}
proc `$`*(a: ProfileId): string {.borrow.}
proc `==`*(a, b: CommandId): bool {.borrow.}
proc hash*(a: CommandId): Hash {.borrow.}
proc `$`*(a: CommandId): string {.borrow.}

type
  NiriWindow* = object
    id*: WindowId
    appId*: Option[string]
    title*: Option[string]
    workspaceId*: Option[WorkspaceId]
    outputId*: Option[OutputId]
    isFocused*: bool
    isFloating*: bool

  SidebarState* = enum
    Collapsed
    Inactive
    Active
    Focused
    Hidden

  SidebarPosition* = enum
    Left
    Right
    Bottom
    Top

  PanelSize* = object
    ratio*: Option[float]
    px*: Option[int]
    visiblePx*: Option[int]
    minPx*: Option[int]
    maxPx*: Option[int]

  ProfileSizes* = array[SidebarState, Option[PanelSize]]

  SidebarInstance* = object
    id*: InstanceId
    position*: SidebarPosition
    state*: SidebarState
    windowIds*: seq[WindowId]
    hidden*: bool

  ActionKind* = enum
    akShellCmd
    akNiriAction
    akKanataFakeKey
    akInternalRpc

  NiriActionKind* = enum
    naFocusWindow
    naCloseWindow
    naSetColumnWidth
    naMoveToFloating
    naMoveToWorkspace

  NiriActionSpec* = object
    case kind*: NiriActionKind
    of naFocusWindow:
      focusWindowId*: WindowId
    of naCloseWindow:
      closeWindowId*: WindowId
    of naSetColumnWidth:
      widthChange*: string
    of naMoveToFloating:
      floatWindowId*: WindowId
    of naMoveToWorkspace:
      moveWindowId*: WindowId
      moveWorkspaceId*: WorkspaceId

  ActionSpec* = object
    case kind*: ActionKind
    of akShellCmd:
      shellCmd*: string
    of akNiriAction:
      niriAction*: NiriActionSpec
    of akKanataFakeKey:
      fakeKeyName*: string
      fakeKeyAction*: string
    of akInternalRpc:
      rpcMethod*: string
      rpcArgs*: string

  KeyToken* = distinct string

proc `==`*(a, b: KeyToken): bool {.borrow.}
proc `<`*(a, b: KeyToken): bool {.borrow.}
proc hash*(a: KeyToken): Hash {.borrow.}
proc `$`*(a: KeyToken): string {.borrow.}

type
  Command* = object
    id*: CommandId
    title*: string
    description*: string
    category*: string
    tags*: HashSet[string]
    sequence*: seq[KeyToken]
    whenStates*: set[SidebarState]
    action*: ActionSpec
    dangerous*: bool

  Profile* = object
    id*: ProfileId
    pluginId*: PluginId
    title*: string
    kanataLayer*: Option[string]
    sizes*: ProfileSizes
    commands*: seq[Command]
    workspaceMatch*: Option[string]

  ResolvedProfile* = object
    profile*: Profile
    instanceId*: InstanceId
    state*: SidebarState
    size*: PanelSize

  KeymapState* = object
    profileId*: ProfileId
    prefix*: seq[KeyToken]
    filter*: string
    available*: seq[Command]
    nextKeys*: seq[KeyToken]
    exactMatch*: Option[Command]

  SidebardConfig* = object
    daemonSocket*: string
    kanataHost*: string
    kanataPort*: int
    kanataReconnectMs*: int
    overlayTimeoutMs*: int
    collapsedVisiblePx*: int

  ShellState* = object
    windows*: Table[WindowId, NiriWindow]
    focusedWindowId*: Option[WindowId]
    instances*: Table[InstanceId, SidebarInstance]
    activeInstance*: Option[InstanceId]
    ownership*: Table[WindowId, InstanceId]
    resolved*: Option[ResolvedProfile]
    keymap*: KeymapState
    kanataConnected*: bool
    kanataLayer*: string
    config*: SidebardConfig

  EventKind* = enum
    evWindowOpened
    evWindowChanged
    evWindowClosed
    evWindowFocused
    evWorkspaceActivated
    evKanataConnected
    evKanataDisconnected
    evKanataLayerChanged
    evKanataMessage
    evSidebarStateRead
    evActivateInstance
    evToggleVisibility
    evPrefixAdvance
    evPrefixReset
    evFilterSet
    evCommandInvoked
    evConfigReloaded
    evTimerFired

  Event* = object
    ts*: MonoTime
    case kind*: EventKind
    of evWindowOpened, evWindowChanged:
      window*: NiriWindow
    of evWindowClosed:
      closedWindowId*: WindowId
    of evWindowFocused:
      focusedId*: Option[WindowId]
    of evWorkspaceActivated:
      workspaceId*: WorkspaceId
      workspaceFocused*: bool
    of evKanataConnected, evKanataDisconnected, evPrefixReset:
      discard
    of evKanataLayerChanged:
      oldLayer*: string
      newLayer*: string
    of evKanataMessage:
      message*: string
    of evSidebarStateRead:
      sidebarInstanceId*: InstanceId
      sidebarWindows*: seq[WindowId]
      sidebarHidden*: bool
    of evActivateInstance:
      targetInstance*: InstanceId
    of evToggleVisibility:
      toggleInstance*: InstanceId
    of evPrefixAdvance:
      key*: KeyToken
    of evFilterSet:
      filterText*: string
    of evCommandInvoked:
      commandId*: CommandId
    of evConfigReloaded:
      newConfig*: SidebardConfig
    of evTimerFired:
      timerId*: string

  EffectKind* = enum
    efChangeKanataLayer
    efExecuteAction
    efStartTimer
    efCancelTimer
    efNotifySubscribers
    efNiriAction

  Effect* = object
    case kind*: EffectKind
    of efChangeKanataLayer:
      layer*: string
    of efExecuteAction:
      action*: ActionSpec
    of efStartTimer:
      timerId*: string
      durationMs*: int
    of efCancelTimer:
      cancelTimerId*: string
    of efNotifySubscribers:
      discard
    of efNiriAction:
      niriAction*: NiriActionSpec
