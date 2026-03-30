# Fix Duplicate PR Auto-Review Comments

## Problem

PR [#52](https://github.com/crazygo/starling/pull/52) received 9 identical `@copilot Please go through...` comments within 10 seconds, causing spam.

### Root Cause

1. **Loop trigger**: The workflow triggered on `pull_request_review_comment.created`. Every time Copilot posted a review comment, it re-triggered the workflow, which then posted another `@copilot ...` comment.
2. **No deduplication**: No check for existing identical comments.
3. **No concurrency control**: Multiple parallel runs possible on the same PR.

## Fix

1. **Remove `pull_request_review_comment` trigger** — only keep `pull_request_review` (submitted). This breaks the feedback loop.
2. **Add `concurrency` group** scoped per PR — cancels stale runs, prevents parallel duplicate posts.
3. **Add deduplication check** — list existing issue comments and skip if one already contains `Please go through`.

## Acceptance Criteria

- Each PR receives at most 1 `Please go through...` comment per review submission.
- Same PR cannot receive duplicate comments within concurrent runs.
- Concurrency group ensures only one run executes at a time per PR.
