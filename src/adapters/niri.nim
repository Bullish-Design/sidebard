import std/[options, tables]
import std/monotimes
import chronos
import results
import ../nimri_ipc
import ../core/types

type
  NiriAdapter* = ref object
    client*: nimri_ipc.NiriClient
    eventStream*: nimri_ipc.NiriEventStream

proc connect*(config: NiriConnectConfig = initNiriConnectConfig()): Future[Result[NiriAdapter, string]] {.async.} =
  let clientRes = await nimri_ipc.openClient(config)
  if clientRes.isErr:
    return err("Failed to connect command client: " & $clientRes.error)

  let streamRes = await nimri_ipc.openEventStream(config)
  if streamRes.isErr:
    clientRes.get.close()
    return err("Failed to open event stream: " & $streamRes.error)

  ok(NiriAdapter(client: clientRes.get, eventStream: streamRes.get))

proc toDomain*(w: nimri_ipc.Window): NiriWindow =
  NiriWindow(
    id: types.WindowId(uint64(w.id)),
    appId: w.appId,
    title: w.title,
    workspaceId: (if w.workspaceId.isSome: some(types.WorkspaceId(uint64(w.workspaceId.get))) else: none(types.WorkspaceId)),
    outputId: none(types.OutputId),
    isFocused: w.isFocused,
    isFloating: w.isFloating,
  )

proc toDomainEvent*(niriEvent: nimri_ipc.NiriEvent): Option[Event] =
  let ts = getMonoTime()
  case niriEvent.kind
  of nimri_ipc.neWindowOpenedOrChanged:
    some(Event(ts: ts, kind: evWindowOpened, window: niriEvent.window.toDomain))
  of nimri_ipc.neWindowClosed:
    some(Event(ts: ts, kind: evWindowClosed, closedWindowId: types.WindowId(uint64(niriEvent.closedId))))
  of nimri_ipc.neWindowFocusChanged:
    some(Event(ts: ts, kind: evWindowFocused,
      focusedId: (if niriEvent.focusedId.isSome: some(types.WindowId(uint64(niriEvent.focusedId.get))) else: none(types.WindowId))))
  of nimri_ipc.neWorkspaceActivated:
    some(Event(ts: ts, kind: evWorkspaceActivated,
      workspaceId: types.WorkspaceId(uint64(niriEvent.activatedId)), workspaceFocused: niriEvent.activatedFocused))
  else:
    none(Event)

proc seedState*(adapter: NiriAdapter, state: ptr ShellState): Future[Result[void, string]] {.async.} =
  let windowsRes = await adapter.client.getWindows()
  if windowsRes.isErr:
    return err("Failed to get windows: " & $windowsRes.error)
  for w in windowsRes.get:
    state[].windows[types.WindowId(uint64(w.id))] = w.toDomain

  let focusedRes = await adapter.client.getFocusedWindow()
  if focusedRes.isErr:
    return err("Failed to get focused window: " & $focusedRes.error)
  if focusedRes.get.isSome:
    state[].focusedWindowId = some(types.WindowId(uint64(focusedRes.get.get.id)))

  ok()

proc readNextEvent*(adapter: NiriAdapter): Future[Result[Event, string]] {.async.} =
  let eventRes = await adapter.eventStream.next()
  if eventRes.isErr:
    return err("Event stream error: " & $eventRes.error)

  let domainEvent = toDomainEvent(eventRes.get)
  if domainEvent.isNone:
    return err("unhandled event type")

  ok(domainEvent.get)

proc executeNiriAction*(adapter: NiriAdapter, action: NiriActionSpec): Future[Result[void, string]] {.async.} =
  let niriAction = case action.kind
    of naFocusWindow:
      nimri_ipc.focusWindow(nimri_ipc.WindowId(uint64(action.focusWindowId)))
    of naCloseWindow:
      nimri_ipc.closeWindow(some(nimri_ipc.WindowId(uint64(action.closeWindowId))))
    of naSetColumnWidth:
      return err("SetColumnWidth not yet implemented")
    of naMoveToFloating:
      nimri_ipc.moveWindowToFloating(some(nimri_ipc.WindowId(uint64(action.floatWindowId))))
    of naMoveToWorkspace:
      nimri_ipc.moveWindowToWorkspace(
        nimri_ipc.WorkspaceRef(kind: wrkById, id: nimri_ipc.WorkspaceId(uint64(action.moveWorkspaceId))),
        focus = false,
        windowId = some(nimri_ipc.WindowId(uint64(action.moveWindowId))),
      )

  let res = await adapter.client.doAction(niriAction)
  if res.isErr:
    return err("Niri action failed: " & $res.error)
  ok()
