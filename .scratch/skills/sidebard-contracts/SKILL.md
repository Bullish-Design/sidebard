# Skill: Sidebard Runtime Contracts

## Purpose
Maintain clear, typed contracts between sidebard core state, adapters, and command/RPC surfaces.

## Use This Skill When
- Adding/changing command payloads or RPC request/response types.
- Adding new reducer events or effect intents.
- Adjusting adapter-to-core translation boundaries.
- Auditing contract drift between daemon and CLI modes.

## Canonical Ownership
- Core state and event/effect types: `src/core/types.nim`, `src/core/state.nim`
- Command/profile/keymap contracts: `src/core/profile.nim`, `src/core/keymap.nim`
- External translation boundaries: `src/adapters/*.nim`
- Entrypoints and user-facing control surface: `src/sidebard.nim`, `src/cli.nim`

## Ownership Rules
1. Reducer state/event/effect schemas live in core modules.
2. Adapter modules only translate transport/protocol inputs and outputs.
3. CLI and daemon share the same contract types.
4. Runtime policy belongs in core logic, not adapter glue.

## Workflow
1. Classify change: contract, policy, or transport translation.
2. Edit canonical files only for that concern.
3. Update tests that verify typed mapping and behavior.
4. Validate targeted build/tests.
5. Report changed files, validated behavior, and risks.

## Guardrails
- Never duplicate command or event schemas across modules.
- Never hide reducer behavior in adapter callbacks.
- Never change external contract semantics without updating tests.

## Done Criteria
- Contract boundaries are explicit and consistent.
- CLI/daemon behavior stays aligned.
- Tests cover changed contract behavior.
