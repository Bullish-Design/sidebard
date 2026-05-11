import std/[unittest, tables, options]
import ../src/core/[types, ownership]

proc mkState(): ShellState =
  result = ShellState(
    windows: initTable[WindowId, NiriWindow](),
    focusedWindowId: none(WindowId),
    instances: initTable[InstanceId, SidebarInstance](),
    activeInstance: none(InstanceId),
    ownership: initTable[WindowId, InstanceId](),
    resolved: none(ResolvedProfile),
    keymap: KeymapState(),
    kanataConnected: false,
    kanataLayer: "",
    config: SidebardConfig(),
  )
  result.instances[InstanceId("left")] = SidebarInstance(id: InstanceId("left"), position: Left, state: Active)
  result.instances[InstanceId("right")] = SidebarInstance(id: InstanceId("right"), position: Right, state: Active)

suite "ownership":
  test "assign and reassign windows":
    var s = mkState()
    assignWindow(s, WindowId(1), InstanceId("left"))
    check s.ownership[WindowId(1)] == InstanceId("left")
    check WindowId(1) in s.instances[InstanceId("left")].windowIds

    assignWindow(s, WindowId(1), InstanceId("right"))
    check s.ownership[WindowId(1)] == InstanceId("right")
    check WindowId(1) notin s.instances[InstanceId("left")].windowIds
    check WindowId(1) in s.instances[InstanceId("right")].windowIds

  test "remove cleans ownership":
    var s = mkState()
    assignWindow(s, WindowId(2), InstanceId("left"))
    removeWindow(s, WindowId(2))
    check WindowId(2) notin s.ownership
    check WindowId(2) notin s.instances[InstanceId("left")].windowIds

  test "repair fixes inconsistencies":
    var s = mkState()
    s.windows[WindowId(3)] = NiriWindow(id: WindowId(3))
    s.ownership[WindowId(3)] = InstanceId("left")
    s.instances[InstanceId("right")].windowIds.add(WindowId(4))
    s.windows[WindowId(4)] = NiriWindow(id: WindowId(4))
    let repairs = repair(s)
    check repairs.len > 0
    check WindowId(3) in s.instances[InstanceId("left")].windowIds
    check s.ownership[WindowId(4)] == InstanceId("right")
