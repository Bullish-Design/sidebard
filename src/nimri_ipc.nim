import std/[options, tables]
import chronos
import results

type
  WindowId* = distinct uint64
  WorkspaceId* = distinct uint64

  WorkspaceRefKind* = enum
    wrkById

  WorkspaceRef* = object
    kind*: WorkspaceRefKind
    id*: WorkspaceId

  Window* = object
    id*: WindowId
    appId*: Option[string]
    title*: Option[string]
    workspaceId*: Option[WorkspaceId]
    isFocused*: bool
    isFloating*: bool

  NiriAction* = object

  NiriRequest* = object
  NiriResponse* = object

  NiriEventKind* = enum
    neWindowOpenedOrChanged
    neWindowClosed
    neWindowFocusChanged
    neWorkspaceActivated
    neUnknown

  NiriEvent* = object
    kind*: NiriEventKind
    window*: Window
    closedId*: WindowId
    focusedId*: Option[WindowId]
    activatedId*: WorkspaceId
    activatedFocused*: bool

  NiriConnectConfig* = object

  NiriClient* = ref object
  NiriEventStream* = ref object

proc initNiriConnectConfig*(): NiriConnectConfig = NiriConnectConfig()
proc openClient*(config: NiriConnectConfig): Future[Result[NiriClient, string]] {.async.} = ok(NiriClient())
proc openEventStream*(config: NiriConnectConfig): Future[Result[NiriEventStream, string]] {.async.} = ok(NiriEventStream())
proc close*(c: NiriClient) = discard
proc close*(s: NiriEventStream) = discard
proc getWindows*(c: NiriClient): Future[Result[seq[Window], string]] {.async.} = ok(newSeq[Window]())
proc getFocusedWindow*(c: NiriClient): Future[Result[Option[Window], string]] {.async.} = ok(none(Window))
proc doAction*(c: NiriClient, a: NiriAction): Future[Result[void, string]] {.async.} = ok()
proc next*(s: NiriEventStream): Future[Result[NiriEvent, string]] {.async.} =
  await sleepAsync(200.milliseconds)
  err("no events")

proc focusWindow*(id: WindowId): NiriAction = NiriAction()
proc closeWindow*(id: Option[WindowId]): NiriAction = NiriAction()
proc moveWindowToFloating*(id: Option[WindowId]): NiriAction = NiriAction()
proc moveWindowToWorkspace*(ws: WorkspaceRef, focus: bool, windowId: Option[WindowId]): NiriAction = NiriAction()
