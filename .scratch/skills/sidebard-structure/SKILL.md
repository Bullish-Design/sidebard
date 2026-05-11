# Skill: Sidebard Structure Navigation

## Purpose
Quickly place changes in the right sidebard layer and preserve separation between pure core logic and I/O adapters.

## Use This Skill When
- A task is ambiguous about module placement.
- You need fast repo orientation before implementing changes.
- You need to prevent coupling regressions.

## Mental Model
- Entrypoints: `src/sidebard.nim`, `src/cli.nim`
- Pure runtime domain: `src/core/*.nim`
- I/O and integrations: `src/adapters/*.nim`
- Tests and fixtures: `tests/**`

## Workflow
1. Start from the affected interface (CLI, RPC, reducer event, adapter input).
2. Place behavior in pure core modules first when possible.
3. Keep transport/protocol conversion inside adapters.
4. Use `rg` to verify call sites and boundary consistency.

## Handy Commands
- `rg --files src tests`
- `rg "proc\s+|type\s+|export|\*" src -n`
- `rg "state|event|effect|rpc|adapter|profile|keymap" src tests -n`

## Done Criteria
- Change is in the correct layer.
- Core/adapters boundary stays clean.
- No duplicated ownership introduced.
