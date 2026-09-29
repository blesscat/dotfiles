---
name: pr-review-follow-up
description: Fix and follow a PR review loop until Code and Security Review pass on the latest pushed head.
---

# PR Review Follow-up

Use after the user authorizes fixing and following reviews. Review-only requests do not authorize edits, commits, pushes, or thread changes.

## Workflow

1. Confirm the repository, PR, current head SHA, branch/worktree, changed files, checks, review results, and open threads. Preserve unrelated work.
2. For lower-trust contributor refs, disable hooks per Git command before `fetch`, `checkout`/`switch`, `worktree add`, `commit`, and `push`, using `git -c core.hooksPath=/dev/null ...` or an empty hooks directory outside the checkout. Run PR-controlled checks only in disposable, credential-free isolation; otherwise skip and report them. Do not change shared Git config.
3. Check both reviews on the initial head and after each push by reading the
   "Codex Review Summary" on the PR. Compare each review's status and reviewed
   commit with the current full head SHA; use the summary's machine-readable
   `headSha` when present, and verify abbreviated SHAs against the full head.
   Missing, pending, or stale results are incomplete. Poll an active run every
   30 seconds for up to 10 minutes; report a run that errors or remains pending
   as blocked.
4. Before requesting a review for a stale commit, refresh the PR summary once
   after 30 seconds so an automatic review triggered by the push can register.
   Treat a queued, pending, or running result for that review type on the
   current head as already in progress. A Codex `eyes` reaction confirms that
   its matching request comment is running; correlate it to the current head
   using the SHA recorded when this workflow posted the request. A run or
   reaction tied to an older head does not cover the current head. If the
   summary or request state cannot be read or correlated to a SHA, report the
   uncertainty rather than risk a duplicate request.
5. When a review is still stale and no request or run for the current head
   exists, automatically add a PR conversation comment with the exact trigger:
   `@codex review` for Code Review or `@codex security review` for Security
   Review. Request only the stale review type. After requesting Code Review,
   recheck both rows and allow one 30-second poll interval for a configured
   Security Review to start on the current head. Do not request Security Review
   separately if it started; otherwise request it if it remains stale. Record
   each request's review type, head SHA, comment ID, and time. Do not post the
   same trigger again for that review type and SHA. Poll for the
   running state and result as above. If no activity or result appears within
   10 minutes, report the trigger/configuration issue as blocked instead of
   repeating the comment.
6. Verify each finding against the current head, make the smallest complete
   fix, run relevant project checks, inspect the diff, then commit and push to
   the PR branch. If no change is needed, do not create an empty commit.
7. Reply to findings with concise evidence, including the fix SHA after
   pushing. Resolve a thread only after its fix is pushed or evidence shows it
   is not actionable. Never merge unless asked.
8. Treat a "Complete"/pass status in the review summary only as that review run
   finishing, not as overall completion. After each review completes, recheck
   the PR for unanswered comments and open threads, and reply to every one. The
   flow is done only when both reviews explicitly pass on the latest pushed
   head, a final sweep confirms no unanswered comments or open threads remain,
   and relevant checks pass. If a required check fails or cannot run, report it
   as a blocker.

## Handoff

Report the PR link, final SHA, commits, review outcomes, checks, and any remaining issues.
