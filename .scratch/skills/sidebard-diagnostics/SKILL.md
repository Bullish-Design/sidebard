# Skill: Sidebard Diagnostics and Explainability

## Purpose
Keep sidebard diagnostics actionable by preserving typed errors, clear context, and predictable logs across core and adapter boundaries.

## Use This Skill When
- Editing error types/messages.
- Adding log lines around event handling, command dispatch, or adapter failures.
- Investigating reducer mismatches or translation failures.

## Primary Targets
- `src/core/state.nim`
- `src/core/config.nim`
- `src/adapters/*.nim`
- `src/cli.nim`
- `tests/**` (especially failure-path tests)

## Workflow
1. Identify error origin and propagation path.
2. Keep low-level error detail close to failing boundary.
3. Add high-level context without obscuring root cause.
4. Validate both failure and success paths with tests.

## Guardrails
- Do not replace typed errors with opaque strings.
- Do not log sensitive paths/secrets unnecessarily.
- Do not add noisy logs that obscure key state transitions.

## Done Criteria
- Errors remain typed and debuggable.
- Logs explain what failed and where.
- Failure-path tests reflect the changed behavior.
