import std/[os, options, tables, strutils, sets, sequtils]
import results
import toml_serialization
import types

type
  DaemonConfig* = object
    socket*: string

  KanataConfig* = object
    host*: string
    port*: int
    reconnect_ms*: int

  DefaultsConfig* = object
    overlay_timeout_ms*: int
    collapsed_visible_px*: int

  PluginSizeConfig* = object
    ratio*: Option[float]
    px*: Option[int]
    visible_px*: Option[int]
    min_px*: Option[int]
    max_px*: Option[int]

  PluginSizesConfig* = object
    collapsed*: Option[PluginSizeConfig]
    inactive*: Option[PluginSizeConfig]
    active*: Option[PluginSizeConfig]
    focused*: Option[PluginSizeConfig]
    hidden*: Option[PluginSizeConfig]

  CommandActionConfig* = object
    shell*: Option[string]
    niri*: Option[string]
    window_id*: Option[uint64]
    kanata_key*: Option[string]
    key_action*: Option[string]
    rpc*: Option[string]
    args*: Option[string]

  CommandConfig* = object
    id*: string
    title*: string
    description*: string
    category*: string
    tags*: seq[string]
    sequence*: seq[string]
    when_states*: seq[string]
    action*: CommandActionConfig
    dangerous*: bool

  PluginProfileConfig* = object
    title*: string
    kanata_layer*: Option[string]
    collapsed*: Option[PluginSizeConfig]
    inactive*: Option[PluginSizeConfig]
    active*: Option[PluginSizeConfig]
    focused*: Option[PluginSizeConfig]
    hidden*: Option[PluginSizeConfig]

  PluginConfig* = object
    id*: string
    title*: string
    priority*: int
    match_app_ids*: seq[string]
    profile*: PluginProfileConfig
    commands*: seq[CommandConfig]

  InstanceOverrideConfig* = object
    sizes*: Option[PluginSizesConfig]

  InstanceConfig* = object
    id*: string
    position*: string
    default_plugin*: string

  RawConfig* = object
    daemon*: DaemonConfig
    kanata*: KanataConfig
    defaults*: DefaultsConfig

  LoadedConfig* = object
    raw*: RawConfig
    plugins*: seq[PluginConfig]
    instances*: seq[InstanceConfig]
    profiles*: Table[PluginId, Profile]
    sidebarInstances*: Table[InstanceId, SidebarInstance]
    pluginAppIdPatterns*: seq[tuple[pluginId: PluginId, patterns: seq[string]]]
    instanceDefaults*: Table[InstanceId, PluginId]

proc loadMainConfig*(path: string): Result[RawConfig, string] =
  if not fileExists(path):
    return err("config file not found: " & path)
  try:
    ok(Toml.loadFile(path, RawConfig))
  except CatchableError as e:
    err("failed to parse " & path & ": " & e.msg)

proc loadPlugins*(dir: string): Result[seq[PluginConfig], string] =
  var plugins: seq[PluginConfig] = @[]
  if not dirExists(dir):
    return ok(plugins)
  for kind, path in walkDir(dir):
    if kind == pcFile and path.endsWith(".toml"):
      try:
        plugins.add(Toml.loadFile(path, PluginConfig))
      except CatchableError as e:
        return err("failed to parse plugin " & path & ": " & e.msg)
  ok(plugins)

proc loadInstances*(dir: string): Result[seq[InstanceConfig], string] =
  var instances: seq[InstanceConfig] = @[]
  if not dirExists(dir):
    return ok(instances)
  for kind, path in walkDir(dir):
    if kind == pcFile and path.endsWith(".toml"):
      try:
        instances.add(Toml.loadFile(path, InstanceConfig))
      except CatchableError as e:
        return err("failed to parse instance " & path & ": " & e.msg)
  ok(instances)

proc toPanelSize*(cfg: PluginSizeConfig): PanelSize =
  PanelSize(ratio: cfg.ratio, px: cfg.px, visiblePx: cfg.visible_px, minPx: cfg.min_px, maxPx: cfg.max_px)

proc toProfileSizes*(cfg: Option[PluginSizesConfig]): ProfileSizes =
  if cfg.isNone:
    return default(ProfileSizes)
  let c = cfg.get
  if c.collapsed.isSome: result[Collapsed] = some(c.collapsed.get.toPanelSize)
  if c.inactive.isSome: result[Inactive] = some(c.inactive.get.toPanelSize)
  if c.active.isSome: result[Active] = some(c.active.get.toPanelSize)
  if c.focused.isSome: result[Focused] = some(c.focused.get.toPanelSize)
  if c.hidden.isSome: result[Hidden] = some(c.hidden.get.toPanelSize)

proc parsePosition*(s: string): Result[SidebarPosition, string] =
  case s.toLowerAscii
  of "left": ok(Left)
  of "right": ok(Right)
  of "bottom": ok(Bottom)
  of "top": ok(Top)
  else: err("invalid sidebar position: " & s)

proc parseWhenStates*(states: seq[string]): Result[set[SidebarState], string] =
  var parsed: set[SidebarState] = {}
  for s in states:
    case s.toLowerAscii
    of "collapsed": parsed.incl Collapsed
    of "inactive": parsed.incl Inactive
    of "active": parsed.incl Active
    of "focused": parsed.incl Focused
    of "hidden": parsed.incl Hidden
    else: return err("invalid sidebar state: " & s)
  ok(parsed)

proc toActionSpec*(cfg: CommandActionConfig): Result[ActionSpec, string] =
  if cfg.shell.isSome:
    ok(ActionSpec(kind: akShellCmd, shellCmd: cfg.shell.get))
  elif cfg.rpc.isSome:
    ok(ActionSpec(kind: akInternalRpc, rpcMethod: cfg.rpc.get, rpcArgs: cfg.args.get("")))
  elif cfg.kanata_key.isSome:
    ok(ActionSpec(kind: akKanataFakeKey, fakeKeyName: cfg.kanata_key.get, fakeKeyAction: cfg.key_action.get("Tap")))
  elif cfg.niri.isSome:
    err("niri action parsing not yet implemented")
  else:
    err("action has no recognized type field")

proc toCommand*(cfg: CommandConfig): Result[Command, string] =
  let actionRes = toActionSpec(cfg.action)
  if actionRes.isErr:
    return err("command " & cfg.id & ": " & actionRes.error)
  let statesRes = parseWhenStates(cfg.when_states)
  if statesRes.isErr:
    return err("command " & cfg.id & ": " & statesRes.error)
  ok(Command(
    id: CommandId(cfg.id),
    title: cfg.title,
    description: cfg.description,
    category: cfg.category,
    tags: cfg.tags.toHashSet,
    sequence: cfg.sequence.mapIt(KeyToken(it)),
    whenStates: statesRes.get,
    action: actionRes.get,
    dangerous: cfg.dangerous,
  ))

proc toProfile*(plugin: PluginConfig): Result[Profile, string] =
  var commands: seq[Command] = @[]
  for cmdCfg in plugin.commands:
    let cmdRes = toCommand(cmdCfg)
    if cmdRes.isErr:
      return err(cmdRes.error)
    commands.add(cmdRes.get)

  let profileSizes = PluginSizesConfig(
    collapsed: plugin.profile.collapsed,
    inactive: plugin.profile.inactive,
    active: plugin.profile.active,
    focused: plugin.profile.focused,
    hidden: plugin.profile.hidden,
  )

  ok(Profile(
    id: ProfileId(plugin.id & "/default"),
    pluginId: PluginId(plugin.id),
    title: plugin.profile.title,
    kanataLayer: plugin.profile.kanata_layer,
    sizes: toProfileSizes(some(profileSizes)),
    commands: commands,
    workspaceMatch: none(string),
  ))

proc loadConfig*(configDir: string): Result[LoadedConfig, string] =
  let rawRes = loadMainConfig(configDir / "config.toml")
  if rawRes.isErr: return err(rawRes.error)

  let pluginsRes = loadPlugins(configDir / "plugins")
  if pluginsRes.isErr: return err(pluginsRes.error)

  let instancesRes = loadInstances(configDir / "instances")
  if instancesRes.isErr: return err(instancesRes.error)

  var loaded = LoadedConfig(raw: rawRes.get, plugins: pluginsRes.get, instances: instancesRes.get)

  for plugin in loaded.plugins:
    let profileRes = toProfile(plugin)
    if profileRes.isErr: return err(profileRes.error)
    loaded.profiles[PluginId(plugin.id)] = profileRes.get
    loaded.pluginAppIdPatterns.add((PluginId(plugin.id), plugin.match_app_ids))

  for inst in loaded.instances:
    let posRes = parsePosition(inst.position)
    if posRes.isErr: return err(posRes.error)
    loaded.sidebarInstances[InstanceId(inst.id)] = SidebarInstance(
      id: InstanceId(inst.id),
      position: posRes.get,
      state: Hidden,
      windowIds: @[],
      hidden: true,
    )
    loaded.instanceDefaults[InstanceId(inst.id)] = PluginId(inst.default_plugin)

  ok(loaded)

proc toSidebardConfig*(loaded: LoadedConfig): SidebardConfig =
  SidebardConfig(
    daemonSocket: loaded.raw.daemon.socket,
    kanataHost: loaded.raw.kanata.host,
    kanataPort: loaded.raw.kanata.port,
    kanataReconnectMs: loaded.raw.kanata.reconnect_ms,
    overlayTimeoutMs: loaded.raw.defaults.overlay_timeout_ms,
    collapsedVisiblePx: loaded.raw.defaults.collapsed_visible_px,
  )
