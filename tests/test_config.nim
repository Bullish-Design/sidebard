import std/[unittest, os, options, tables]
import results
import ../src/core/[config, types]

suite "config":
  test "load fixtures":
    let loaded = loadConfig(getCurrentDir() / "tests/fixtures")
    check loaded.isErr == false
    check loaded.get.raw.kanata.port == 6666
    check loaded.get.plugins.len == 1
    check loaded.get.instances.len == 1
    let p = loaded.get.profiles[PluginId("chat")]
    check p.sizes[Active].isSome
    check p.sizes[Active].get.ratio.isSome
