import std/[unittest, options]
import std/monotimes
import ../src/core/types

suite "types":
  test "distinct IDs are type-safe":
    let w = WindowId(42)
    let i = InstanceId("left")
    check $w == "42"
    check $i == "left"

  test "SidebarState is a closed enum":
    check SidebarState.low == Collapsed
    check SidebarState.high == Hidden

  test "ProfileSizes is enum-indexed":
    var sizes: ProfileSizes
    sizes[Active] = some(PanelSize(ratio: some(0.34)))
    check sizes[Active].isSome
    check sizes[Collapsed].isNone

  test "Event variant construction":
    let ev = Event(
      ts: getMonoTime(),
      kind: evWindowOpened,
      window: NiriWindow(id: WindowId(1), isFocused: false, isFloating: false)
    )
    check ev.kind == evWindowOpened
    check ev.window.id == WindowId(1)
