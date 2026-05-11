import std/[unittest, tables, options]
import ../src/core/[types, profile, state]

suite "profile":
  test "resolve default plugin":
    var st = initShellState(SidebardConfig())
    st.instances[InstanceId("right")] = SidebarInstance(id: InstanceId("right"), position: Right, state: Active)
    st.activeInstance = some(InstanceId("right"))
    var profiles = initTable[PluginId, Profile]()
    profiles[PluginId("chat")] = Profile(id: ProfileId("chat/default"), pluginId: PluginId("chat"), title: "Chat")
    var defaults = initTable[InstanceId, PluginId]()
    defaults[InstanceId("right")] = PluginId("chat")
    let rp = resolveProfile(st, profiles, @[], defaults)
    check rp.isSome
