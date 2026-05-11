import std/[unittest, options, tables]
import std/monotimes
import ../src/core/[types, state]

suite "state":
  test "window open/close":
    var st = initShellState(SidebardConfig())
    let ev1 = Event(ts: getMonoTime(), kind: evWindowOpened, window: NiriWindow(id: WindowId(1)))
    discard reduce(st, ev1, initTable[PluginId, Profile](), @[], initTable[InstanceId, PluginId]())
    check WindowId(1) in st.windows
    let ev2 = Event(ts: getMonoTime(), kind: evWindowClosed, closedWindowId: WindowId(1))
    discard reduce(st, ev2, initTable[PluginId, Profile](), @[], initTable[InstanceId, PluginId]())
    check WindowId(1) notin st.windows
