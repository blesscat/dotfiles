---
name: pr-review-follow-up
description: Fix and follow a PR review loop until Code and Security Review pass on the latest pushed head, then mark a draft PR ready and wait for the required checks.
---

# PR Review Follow-up

Use after the user authorizes fixing and following reviews. It works on draft PRs. Do not rely on automatic reviews: request each review by comment unless it is already queued, running, or complete on the current head. Review-only requests do not authorize edits, commits, pushes, or thread changes.

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
   after 30 seconds in case a run already registered. Treat a queued, pending, or running result for that review type on the
   current head as already in progress. A Codex `eyes` reaction confirms that
   its matching request comment is running; correlate it to the current head
   using the SHA recorded when this workflow posted the request. A run or
   reaction tied to an older head does not cover the current head. If the
   summary or request state cannot be read or correlated to a SHA, report the
   uncertainty rather than risk a duplicate request.
5. After the initial head and every push to a new head, when a review is stale
   and no request or run for the current head exists, add a PR conversation comment with the exact trigger:
   `@codex review` for Code Review or `@codex security review` for Security
   Review. Request each type that has not started
   on the current head, both types after every push to a new head, instead of
   waiting for an automatic review. Skip a type that is already queued, running, or
   complete on the current head. Record
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
   and relevant checks pass, except required checks the repository defers until a
   PR is ready; those are required only after step 9. A required check that fails goes
   through the fix loop (steps 6-8), keeping a draft PR draft and converting a
   ready PR with `gh pr ready --undo` before pushing. If a
   required check cannot run or cannot be fixed, report it as a blocker.
9. When that holds, run `gh pr ready <n>` if the PR is a draft, then wait for the
   repository's required checks on the latest head (for example `CI result`). If
   the repository's CI skips draft PRs, full CI runs only once the PR is ready;
   otherwise drafts may still run CI. Do not request reviews again for the ready
   transition.
10. If required checks fail, run `gh pr ready --undo` before pushing fixes so a
    draft-skipping CI does not rerun on every fix push. Fix, push, re-trigger both
    reviews for the new head (steps 5-8), then mark ready again. Never merge.

## Handoff

Report the PR link, final SHA, draft/ready state, commits, review outcomes, CI result, and any remaining issues.
