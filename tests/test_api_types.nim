import std/[unittest, options]
import jsony
import ../src/core/[types, state, api_types]

suite "api":
  test "snapshot serializes":
    let st = initShellState(SidebardConfig())
    let j = toApiSnapshot(st).toJson
    check j.len > 2
