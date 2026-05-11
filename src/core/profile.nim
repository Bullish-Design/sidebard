import std/[options, tables, re]
import types

proc matchesPlugin*(window: NiriWindow, patterns: seq[string]): bool =
  if window.appId.isNone: return false
  let appId = window.appId.get
  for pattern in patterns:
    if appId.match(re(pattern)): return true
  false

proc findPluginForWindow*(window: NiriWindow, pluginPatterns: seq[tuple[pluginId: PluginId, patterns: seq[string]]]): Option[PluginId] =
  for (pluginId, patterns) in pluginPatterns:
    if matchesPlugin(window, patterns): return some(pluginId)
  none(PluginId)

proc resolveSize*(profile: Profile, state: SidebarState): PanelSize =
  if profile.sizes[state].isSome: profile.sizes[state].get else: PanelSize(ratio: some(0.25))

proc resolveProfile*(
  state: ShellState,
  profiles: Table[PluginId, Profile],
  pluginPatterns: seq[tuple[pluginId: PluginId, patterns: seq[string]]],
  instanceDefaults: Table[InstanceId, PluginId],
): Option[ResolvedProfile] =
  if state.activeInstance.isNone: return none(ResolvedProfile)
  let activeInst = state.activeInstance.get
  if activeInst notin state.instances: return none(ResolvedProfile)
  let instance = state.instances[activeInst]
  var pluginId: Option[PluginId] = none(PluginId)

  if state.focusedWindowId.isSome:
    let focusedId = state.focusedWindowId.get
    if focusedId in state.ownership and focusedId in state.windows:
      pluginId = findPluginForWindow(state.windows[focusedId], pluginPatterns)

  if pluginId.isNone and activeInst in instanceDefaults:
    pluginId = some(instanceDefaults[activeInst])

  if pluginId.isNone or pluginId.get notin profiles: return none(ResolvedProfile)
  let profile = profiles[pluginId.get]
  some(ResolvedProfile(profile: profile, instanceId: activeInst, state: instance.state, size: resolveSize(profile, instance.state)))
