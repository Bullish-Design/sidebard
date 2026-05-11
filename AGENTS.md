# AGENTS.md

## Purpose
This repository builds `sidebard`, a Nim daemon and CLI for managing sidebar behavior in Niri sessions. It maintains runtime shell state, reacts to compositor changes, and exposes a local command/RPC surface for automation and UI integrations.

## Project Scope
`sidebard` owns:
- Runtime shell/session state (focused window, sidebar ownership, active profile).
- Reactive reducers that transform compositor events into deterministic state transitions.
- Command dispatch for sidebar actions and internal control operations.
- Local IPC/RPC interface used by CLI calls and external tools.
- Configuration loading/validation for sidebard runtime behavior.
- Adapter boundaries for Niri and optional external integrations.

`sidebard` does not own:
- Niri protocol schema or low-level transport internals (owned by `nimri-ipc`).
- Window manager policy outside sidebard-defined behavior.
- Persistent cloud services or remote control planes.
- Desktop UX outside explicit sidebard command integrations.

## Architecture
Expected layout under `src/`:

| Module | Role | I/O |
|---|---|---|
| `sidebard.nim` | Program entrypoint and mode dispatch | Yes |
| `cli.nim` | CLI command parsing and request sending | Yes |
| `core/types.nim` | Domain identifiers and state/value types | No |
| `core/config.nim` | Config schema + load/validate | File I/O |
| `core/state.nim` | Reducer + state transitions + effect intents | No |
| `core/profile.nim` | Profile resolution from window/context | No |
| `core/ownership.nim` | Window/sidebar ownership rules | No |
| `core/keymap.nim` | Keymap and command routing model | No |
| `adapters/niri.nim` | Niri-facing adapter (via `nimri-ipc`) | Yes |
| `adapters/rpc.nim` | Local RPC server/client transport | Yes |
| `adapters/kanata.nim` | Optional key-layer adapter | Yes |

Key architectural decisions:
- Core logic remains pure and testable; adapters handle I/O.
- Effects are represented as explicit intents from reducer logic.
- CLI and daemon share contracts to avoid drift.
- Integration with Niri stays behind adapter boundaries.

## Dependency Rules
```
sidebard.nim     -> cli, core/*, adapters/*
cli.nim          -> core/types, core/config, adapters/rpc
core/state.nim   -> core/types, core/profile, core/ownership, core/keymap
core/profile.nim -> core/types
core/ownership.nim -> core/types
core/keymap.nim  -> core/types
adapters/niri.nim -> core/types (+ nimri-ipc)
adapters/rpc.nim -> core/types
adapters/kanata.nim -> core/types
```

## Forbidden Couplings
- Core modules must not do socket, process, or filesystem side effects (except `core/config.nim`).
- `adapters/*` must not embed business policy that belongs in reducer/profile logic.
- CLI mode must not bypass RPC contracts with daemon-specific hidden state.
- Do not spread Niri-specific transport handling outside `adapters/niri.nim`.

## Development Environment
All compilation, testing, and tooling should run inside `devenv` for reproducible Nim/Nimble versions.

### Common commands
```bash
devenv shell -- nimble test
devenv shell -- nimble build
devenv shell -- nim c -r tests/test_state.nim
```

### Agent rule
When compiling or testing, run through `devenv shell -- <command>` unless you are already inside a devenv shell.

## Technology Stack
- Nim >= 2.0
- Nimble for package/build workflow
- `results` for typed error returns
- Stdlib async/process/json/tables/options modules as needed
- `nimri-ipc` for Niri protocol interaction

## Design Principles
1. Deterministic reducer behavior from explicit inputs.
2. Explicit, typed contracts at module boundaries.
3. Side effects isolated to adapters.
4. Stable local control surface (CLI/RPC) over ad-hoc scripts.
5. Clear ownership boundaries between sidebard and nimri-ipc.

## Testing Expectations
- Add or update tests for each behavior change.
- Prioritize pure core tests for reducers/profile/ownership/keymap logic.
- Use adapter-focused tests for parse/translation and failure handling.
- If integration tests rely on a live Niri socket, ensure they skip cleanly when unavailable.

## Agent Workflow
1. Confirm task scope and impacted boundary (core vs adapter vs interface).
2. Implement changes in the narrowest valid module.
3. Add/update tests near changed behavior.
4. Run targeted tests, then broader suite as needed.
5. Report what was validated and any residual risk.
