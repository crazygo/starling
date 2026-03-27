# Task Plan: Add planning-memory workflow rule

## Background
The team wants a persistent memory rule (similar to AGENTS.md) so each task has planning context captured and reused in PR communication.

## Plan
1. Add a root `AGENTS.md` memory file to store workflow rules.
2. Record the required rule:
   - For each feature/task, create a markdown plan in `docs/plans/`.
   - Use filename prefix `YYYY-mm-dd-hh-mm`.
   - After coding and opening a PR, use the plan content as the PR message.

## Implementation Notes
- This task only updates process documentation (no runtime code changes).
- This plan file itself demonstrates the new planning format.
