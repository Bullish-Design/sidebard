import std/[json]
import std/monotimes
import chronos
import results
import ../core/types

type
  KanataAdapter* = ref object
    host*: string
    port*: int
    connected*: bool
    reconnectMs*: int

proc connect*(host: string, port: int): Future[Result[KanataAdapter, string]] {.async.} =
  ok(KanataAdapter(host: host, port: port, connected: false))

proc sendCommand*(adapter: KanataAdapter, command: JsonNode): Future[Result[void, string]] {.async.} =
  if not adapter.connected:
    return err("Not connected to Kanata")
  discard command
  ok()

proc changeLayer*(adapter: KanataAdapter, layer: string): Future[Result[void, string]] {.async.} =
  await adapter.sendCommand(%*{"ChangeLayer": {"new": layer}})

proc fakeKeyAction*(adapter: KanataAdapter, name: string, action: string): Future[Result[void, string]] {.async.} =
  await adapter.sendCommand(%*{"ActOnFakeKey": {"name": name, "action": action}})

proc readEvent*(adapter: KanataAdapter): Future[Result[Event, string]] {.async.} =
  if not adapter.connected:
    return err("Not connected")
  await sleepAsync(100.milliseconds)
  ok(Event(ts: getMonoTime(), kind: evKanataMessage, message: "stub"))
