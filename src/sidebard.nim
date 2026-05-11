import std/[os, options, tables, sequtils]
import chronos
import chronicles
import cligen
import core/[types, config, state, profile, keymap]
import adapters/[niri, kanata, rpc, sidebar_compat]
import ./cli

proc runDaemon*() {.async.} =
  let configDir = getEnv("SIDEBARD_CONFIG_DIR", getCurrentDir() / "tests/fixtures")
  let loadedConfigRes = loadConfig(configDir)
  if loadedConfigRes.isErr:
    error "Failed to load config", err = loadedConfigRes.error
    quit(1)
  let loadedConfig = loadedConfigRes.get

  var shellState = initShellState(loadedConfig.toSidebardConfig())
  for instanceId, inst in loadedConfig.sidebarInstances:
    shellState.instances[instanceId] = inst

  let sidebarStateDir = getEnv("SIDEBARD_STATE_DIR", getCurrentDir() / "tests/fixtures")
  let sidebarEvents = loadSidebarStates(sidebarStateDir, loadedConfig.sidebarInstances.keys.toSeq)
  for ev in sidebarEvents:
    discard reduce(shellState, ev, loadedConfig.profiles, loadedConfig.pluginAppIdPatterns, loadedConfig.instanceDefaults)

  shellState.resolved = resolveProfile(shellState, loadedConfig.profiles, loadedConfig.pluginAppIdPatterns, loadedConfig.instanceDefaults)
  if shellState.resolved.isSome:
    let r = shellState.resolved.get
    shellState.keymap = rebuildKeymap(r.profile.commands, r.state, r.profile.id)

  var kanataAdapter: Option[KanataAdapter] = none(KanataAdapter)
  let kanataRes = await kanata.connect(shellState.config.kanataHost, shellState.config.kanataPort)
  if kanataRes.isOk:
    kanataAdapter = some(kanataRes.get)
    shellState.kanataConnected = true

  var rpcCtx = RpcContext(
    state: addr shellState,
    eventCallback: proc(ev: Event) {.gcsafe, raises: [].} =
      try:
        discard reduce(shellState, ev, loadedConfig.profiles, loadedConfig.pluginAppIdPatterns, loadedConfig.instanceDefaults)
      except CatchableError:
        discard,
    subscriptions: initTable[string, Subscription](),
  )

  asyncSpawn rpcCtx.runRpcServer(shellState.config.daemonSocket)

  let niriRes = await niri.connect()
  if niriRes.isErr:
    warn "Failed to connect to Niri", err = niriRes.error
    while true:
      await sleepAsync(1000.milliseconds)
  let niriAdapter = niriRes.get
  discard await niriAdapter.seedState(addr shellState)

  while true:
    let eventRes = await niriAdapter.readNextEvent()
    if eventRes.isErr:
      await sleepAsync(100.milliseconds)
      continue

    let effects = reduce(shellState, eventRes.get, loadedConfig.profiles, loadedConfig.pluginAppIdPatterns, loadedConfig.instanceDefaults)
    for eff in effects:
      case eff.kind
      of efChangeKanataLayer:
        if kanataAdapter.isSome:
          discard await kanataAdapter.get.changeLayer(eff.layer)
      of efNiriAction:
        discard await niriAdapter.executeNiriAction(eff.niriAction)
      of efNotifySubscribers:
        await rpcCtx.notifySubscribers()
      else:
        discard

proc daemon*() =
  waitFor runDaemon()

when isMainModule:
  dispatchMulti([daemon])
