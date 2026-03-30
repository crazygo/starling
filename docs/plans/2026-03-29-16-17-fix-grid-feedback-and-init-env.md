# Plan: Address grid-overlay review feedback + initialize Codex env

## Goals
- Address review comments from the previous celestial/horizon grid PR.
- Use the repository-provided Codex initialization script to install missing commands.
- Re-run formatting/validation commands that previously failed due missing toolchain.

## Steps
1. Inspect current code and identify likely review issues (logic, style, duplication, rendering correctness).
2. Run `scripts/init_codex_env.sh` and confirm `flutter`/`dart` availability.
3. Apply fixes based on review feedback and keep defaults/behavior per requirement.
4. Run formatting and validation (`dart format`, `flutter analyze`/tests as feasible).
5. Commit changes and create PR message from this plan.

## Notes
- Preserve functional requirements:
  - Horizon grid default ON.
  - Celestial grid default OFF.
  - Both can be shown simultaneously with visual distinction.
  - Polaris validation expectation for celestial grid.
