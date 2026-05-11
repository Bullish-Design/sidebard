import std/[options, tables, sequtils, strutils, sets, algorithm]
import types

type
  TrieNode* = object
    children*: Table[KeyToken, TrieNode]
    commandIds*: seq[CommandId]

proc firstOpt*[T](s: seq[T]): Option[T] =
  if s.len > 0: some(s[0]) else: none(T)

proc insertCommand*(root: var TrieNode, command: Command) =
  var node = addr root
  for key in command.sequence:
    if key notin node[].children:
      node[].children[key] = TrieNode()
    node = addr node[].children[key]
  node[].commandIds.add(command.id)

proc buildTrie*(commands: seq[Command]): TrieNode =
  result = TrieNode()
  for cmd in commands:
    if cmd.sequence.len > 0:
      result.insertCommand(cmd)

proc findNode*(root: TrieNode, prefix: seq[KeyToken]): Option[TrieNode] =
  var node = root
  for key in prefix:
    if key notin node.children: return none(TrieNode)
    node = node.children[key]
  some(node)

proc collectAllCommandIds*(node: TrieNode): seq[CommandId] =
  result = node.commandIds
  for _, child in node.children:
    result.add(collectAllCommandIds(child))

proc rebuildKeymap*(commands: seq[Command], sidebarState: SidebarState, profileId: ProfileId): KeymapState =
  let available = commands.filterIt(sidebarState in it.whenStates)
  let trie = buildTrie(available)
  let nextKeys = trie.children.keys.toSeq.sorted
  KeymapState(profileId: profileId, prefix: @[], filter: "", available: available, nextKeys: nextKeys, exactMatch: none(Command))

proc advancePrefix*(state: var KeymapState, key: KeyToken, trie: TrieNode) =
  state.prefix.add(key)
  let node = findNode(trie, state.prefix)
  if node.isNone:
    state.available = @[]
    state.nextKeys = @[]
    state.exactMatch = none(Command)
    return
  let n = node.get
  let reachableIds = collectAllCommandIds(n).toHashSet
  state.available = state.available.filterIt(it.id in reachableIds)
  state.nextKeys = n.children.keys.toSeq.sorted
  if n.commandIds.len == 1:
    let matchId = n.commandIds[0]
    state.exactMatch = state.available.filterIt(it.id == matchId).firstOpt
  else:
    state.exactMatch = none(Command)

proc setFilter*(state: var KeymapState, text: string, allCommands: seq[Command], sidebarState: SidebarState) =
  state.filter = text
  if text.len == 0:
    state.available = allCommands.filterIt(sidebarState in it.whenStates)
    return
  let lowerText = text.toLowerAscii
  state.available = state.available.filterIt(
    lowerText in it.title.toLowerAscii or
    lowerText in it.description.toLowerAscii or
    it.tags.anyIt(lowerText in it.toLowerAscii)
  )

proc resetPrefix*(state: var KeymapState, allCommands: seq[Command], sidebarState: SidebarState, trie: TrieNode) =
  state.prefix = @[]
  state.filter = ""
  state.available = allCommands.filterIt(sidebarState in it.whenStates)
  state.nextKeys = trie.children.keys.toSeq.sorted
  state.exactMatch = none(Command)
