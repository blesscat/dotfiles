---
name: pr-review-follow-up
description: Fix and follow a PR review loop until Code and Security Review pass on the latest pushed head.
---

# PR Review Follow-up

Use after the user authorizes fixing and following reviews. Review-only requests do not authorize edits, commits, pushes, or thread changes.

## Workflow

1. Confirm the repository, PR, current head SHA, branch/worktree, changed files, checks, review results, and open threads. Preserve unrelated work.
2. For lower-trust contributor refs, disable hooks per Git command before `fetch`, `checkout`/`switch`, `worktree add`, `commit`, and `push`, using `git -c core.hooksPath=/dev/null ...` or an empty hooks directory outside the checkout. Run PR-controlled checks only in disposable, credential-free isolation; otherwise skip and report them. Do not change shared Git config.
3. Check both reviews on the initial head and after each push by watching the
   "Codex Review Summary" table on the PR (Code Review and Security Review
   statuses and their reviewed commit). Do not trigger reviews with @ mentions;
   they are started manually by the user. Treat missing or pending results as
   incomplete. Poll every 30 seconds for up to 10 minutes; report a review that
   errors or remains pending as blocked.
4. Verify each finding against the current head, make the smallest complete fix, run relevant project checks, inspect the diff, then commit and push to the PR branch. If no change is needed, do not create an empty commit.
5. Reply to findings with concise evidence, including the fix SHA after pushing. Resolve a thread only after its fix is pushed or evidence shows it is not actionable. Never merge unless asked.
6. Treat a "Complete"/pass status in the review summary only as that review run
   finishing, not as overall completion. After each review completes, recheck
   the PR for unanswered comments and open threads, and reply to every one. The
   flow is done only when both reviews explicitly pass on the latest pushed
   head, a final sweep confirms no unanswered comments or open threads remain,
   and relevant checks pass. If a required check fails or cannot run, report it
   as a blocker.

## Handoff

Report the PR link, final SHA, commits, review outcomes, checks, and any remaining issues.
