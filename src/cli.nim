import std/[os, json]
import chronos
import cligen

proc getSocketPath*(): string =
  getEnv("SIDEBARD_SOCKET", "/tmp/sidebard.sock")

proc rpcCall*(socketPath: string, meth: string, params: JsonNode = newJObject()): Future[JsonNode] {.async.} =
  let socket = await connect(initTAddress(socketPath))
  let request = %*{"jsonrpc": "2.0", "id": 1, "method": meth, "params": params}
  discard await socket.write($request & "\n")
  let response = await socket.readLine()
  await socket.closeWait()

  let parsed = parseJson(response)
  if parsed.hasKey("error"):
    raise newException(IOError, parsed["error"]["message"].getStr)
  parsed["result"]

proc state*(pretty: bool = false) =
  let result = waitFor rpcCall(getSocketPath(), "state")
  if pretty: echo result.pretty else: echo $result

proc profile*() =
  echo $(waitFor rpcCall(getSocketPath(), "profile"))

proc keymap*() =
  echo $(waitFor rpcCall(getSocketPath(), "keymap"))

proc commands*() =
  echo $(waitFor rpcCall(getSocketPath(), "commands"))

proc activate*(instance: string) =
  discard waitFor rpcCall(getSocketPath(), "activate", %*{"instance": instance})

proc toggle*(instance: string) =
  discard waitFor rpcCall(getSocketPath(), "toggle", %*{"instance": instance})

proc prefixAdvance*(key: string) =
  discard waitFor rpcCall(getSocketPath(), "prefix.advance", %*{"key": key})

proc prefixReset*() =
  discard waitFor rpcCall(getSocketPath(), "prefix.reset", newJObject())

proc filter*(text: string) =
  discard waitFor rpcCall(getSocketPath(), "filter", %*{"text": text})

proc run*(command: string) =
  discard waitFor rpcCall(getSocketPath(), "run", %*{"command": command})

proc watch*(topic: string) =
  let socket = waitFor connect(initTAddress(getSocketPath()))
  let subReq = %*{"jsonrpc": "2.0", "id": 1, "method": "subscribe", "params": {"topics": [topic]}}
  discard waitFor socket.write($subReq & "\n")
  discard waitFor socket.readLine()
  while true:
    let line = waitFor socket.readLine()
    if line.len == 0: break
    echo line

when isMainModule:
  dispatchMulti(
    [state], [profile], [keymap], [commands],
    [activate], [toggle], [prefixAdvance], [prefixReset], [filter], [run], [watch]
  )
