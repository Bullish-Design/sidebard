import std/[unittest, sets]
import ../src/core/[types, keymap]

proc mkCmd(id, a, b: string): Command =
  Command(id: CommandId(id), title: id, sequence: @[KeyToken(a), KeyToken(b)], whenStates: {Active}, tags: initHashSet[string]())

suite "keymap":
  test "trie and prefix":
    let cmds = @[mkCmd("c1", "Leader", "R"), mkCmd("c2", "Leader", "J")]
    let trie = buildTrie(cmds)
    var ks = rebuildKeymap(cmds, Active, ProfileId("p"))
    advancePrefix(ks, KeyToken("Leader"), trie)
    check ks.nextKeys.len == 2
