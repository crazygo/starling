# Fix Duplicate PR Auto-Review Comments

## Problem

PR [#52](https://github.com/crazygo/starling/pull/52) received 9 identical `@copilot Please go through...` comments within 10 seconds, causing spam.

### Root Cause

1. **Loop trigger**: The workflow triggered on `pull_request_review_comment.created`. Every time Copilot posted a review comment, it re-triggered the workflow, which then posted another `@copilot ...` comment.
2. **No deduplication**: No check for existing identical comments.
3. **No concurrency control**: Multiple parallel runs possible on the same PR.

## Fix

1. **Remove `pull_request_review_comment` trigger** — only keep `pull_request_review` (submitted). This breaks the feedback loop.
2. **Add `concurrency` group** scoped per PR — serializes runs per PR with `cancel-in-progress: false`, ensuring they execute one at a time and preventing parallel duplicate posts.
3. **Add deduplication check** — paginate all existing issue comments and skip if any already contains the HTML marker `<!-- copilot-auto-review-request -->` embedded in the comment body.

## Acceptance Criteria

- Each PR receives at most 1 `Please go through...` comment in total (across all review submissions).
- Same PR cannot receive duplicate comments within concurrent runs.
- Concurrency group ensures only one run executes at a time per PR.
