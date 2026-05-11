# Skill: Sidebard Change Validation

## Purpose
Run practical validation for sidebard changes and clearly report what was verified.

## Use This Skill When
- Editing any `src/` module.
- Changing contracts between core, CLI/RPC, and adapters.
- Preparing a concise implementation report.

## Validation Ladder
1. Static sanity:
- `rg "<symbol-or-field>" src tests -n`

2. Build:
- `devenv shell -- nimble build`

3. Tests:
- Run targeted tests first for changed modules.
- Run broader suite when contract-level behavior changed.

4. Contract checks:
- Verify CLI and daemon agree on request/response structures.
- Verify adapter translation matches core event/effect types.

## Reporting Template
- Files changed:
- Validation run:
- Result:
- Residual risks:

## Guardrails
- Do not claim live Niri behavior was tested unless it was.
- If full tests cannot run, state exact scope executed.
- If interfaces changed, explicitly note compatibility risk.
