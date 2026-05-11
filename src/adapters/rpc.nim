import std/[options, tables, json, strutils, sequtils, sets, times, os]
import std/monotimes
import chronos
import jsony
import ../core/[types, api_types]

type
  Subscription* = ref object
    id*: string
    topics*: HashSet[string]
    socket*: StreamTransport

  RpcContext* = ref object
    state*: ptr ShellState
    eventCallback*: proc(event: Event) {.gcsafe, raises: [].}
    subscriptions*: Table[string, Subscription]

proc rpcResult(id: JsonNode, payload: JsonNode): string =
  $(%*{"jsonrpc": "2.0", "id": id, "result": payload}) & "\n"

proc rpcError(id: JsonNode, msg: string): string =
  $(%*{"jsonrpc": "2.0", "id": id, "error": {"code": -32000, "message": msg}}) & "\n"

proc dispatchMethod(ctx: RpcContext, meth: string, params: JsonNode): JsonNode =
  case meth
  of "state":
    parseJson(ctx.state[].toApiSnapshot.toJson)
  of "profile":
    if ctx.state[].resolved.isSome: parseJson(ctx.state[].resolved.get.toApi.toJson) else: newJNull()
  of "keymap":
    parseJson(ctx.state[].keymap.toApi.toJson)
  of "commands":
    if ctx.state[].resolved.isSome:
      parseJson(ctx.state[].resolved.get.profile.commands.mapIt(it.toApi).toJson)
    else:
      newJArray()
  of "instances":
    var arr = newJArray()
    for _, inst in ctx.state[].instances:
      arr.add(parseJson(inst.toApi.toJson))
    arr
  of "windows":
    var arr = newJArray()
    for _, w in ctx.state[].windows:
      arr.add(parseJson(w.toApi.toJson))
    arr
  else:
    newJNull()

proc emitEvent(ctx: RpcContext, meth: string, params: JsonNode) {.raises: [].} =
  try:
    let ts = getMonoTime()
    case meth
    of "activate":
      ctx.eventCallback(Event(ts: ts, kind: evActivateInstance, targetInstance: InstanceId(params["instance"].getStr)))
    of "toggle":
      ctx.eventCallback(Event(ts: ts, kind: evToggleVisibility, toggleInstance: InstanceId(params["instance"].getStr)))
    of "prefix.advance":
      ctx.eventCallback(Event(ts: ts, kind: evPrefixAdvance, key: KeyToken(params["key"].getStr)))
    of "prefix.reset":
      ctx.eventCallback(Event(ts: ts, kind: evPrefixReset))
    of "filter":
      ctx.eventCallback(Event(ts: ts, kind: evFilterSet, filterText: params["text"].getStr))
    of "run":
      ctx.eventCallback(Event(ts: ts, kind: evCommandInvoked, commandId: CommandId(params["command"].getStr)))
    else:
      discard
  except CatchableError:
    discard

proc notifySubscribers*(ctx: RpcContext) {.async.} =
  for _, sub in ctx.subscriptions:
    for topic in sub.topics:
      let payload = case topic
        of "state": parseJson(ctx.state[].toApiSnapshot.toJson)
        of "keymap": parseJson(ctx.state[].keymap.toApi.toJson)
        of "profile":
          if ctx.state[].resolved.isSome:
            parseJson(ctx.state[].resolved.get.toApi.toJson)
          else:
            newJNull()
        else: newJNull()
      let msg = $(%*{"jsonrpc": "2.0", "method": "notify." & topic, "params": payload}) & "\n"
      discard await sub.socket.write(msg)

proc handleClient(ctx: RpcContext, conn: StreamTransport) {.async.} =
  while true:
    let line = await conn.readLine()
    if line.len == 0:
      break
    try:
      let req = parseJson(line)
      let id = if req.hasKey("id"): req["id"] else: newJNull()
      let meth = req["method"].getStr
      let params = if req.hasKey("params"): req["params"] else: newJObject()

      if meth == "subscribe":
        let subId = "sub-" & $epochTime().int & "-" & $ctx.subscriptions.len
        var topics = initHashSet[string]()
        if params.hasKey("topics"):
          for t in params["topics"]:
            topics.incl(t.getStr)
        ctx.subscriptions[subId] = Subscription(id: subId, topics: topics, socket: conn)
        discard await conn.write(rpcResult(id, %subId))
      elif meth == "unsubscribe":
        let subId = params["subscriptionId"].getStr
        if subId in ctx.subscriptions:
          ctx.subscriptions.del(subId)
        discard await conn.write(rpcResult(id, newJNull()))
      elif meth in ["activate", "toggle", "prefix.advance", "prefix.reset", "filter", "run"]:
        emitEvent(ctx, meth, params)
        discard await conn.write(rpcResult(id, newJNull()))
      elif meth in ["state", "profile", "keymap", "commands", "instances", "windows"]:
        discard await conn.write(rpcResult(id, dispatchMethod(ctx, meth, params)))
      else:
        discard await conn.write(rpcError(id, "unknown meth: " & meth))
    except CatchableError as e:
      discard await conn.write(rpcError(newJNull(), e.msg))

proc runRpcServer*(ctx: RpcContext, socketPath: string): Future[void] {.async.} =
  try:
    removeFile(socketPath)
  except CatchableError:
    discard
  let listenAddr = initTAddress(socketPath)
  let server = createStreamServer(listenAddr)
  while true:
    let client = await server.accept()
    asyncSpawn handleClient(ctx, client)
