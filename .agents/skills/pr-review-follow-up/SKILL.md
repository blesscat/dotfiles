---
name: pr-review-follow-up
description: Fix and follow a PR review loop until the Code and Security Reviews that the latest pushed head needs have passed, then mark a draft PR ready and wait for the required checks.
---

# PR Review Follow-up

Use after the user authorizes fixing and following reviews. It works on draft PRs. Do not rely on automatic reviews: request each needed review by comment unless it is already queued, running, or complete on the current head. Review-only requests do not authorize edits, commits, pushes, or thread changes.

## Reviews a head needs

Decide this for the initial head and again after every push. Do not request a
review the head does not need.

- **Code Review** is needed on every head, including a head that only rebases
  onto or merges the base branch. Repeat runs on an unchanged diff have found
  real defects, so an earlier pass does not cover a new head.
- **Security Review** is needed on every head whose own diff differs from that
  of the last head that passed Security Review. No file type is exempt:
  documentation, tests, fonts and images need it too. A head that only rebases
  onto or merges the base branch, leaving the PR's own diff unchanged, is still
  covered by the earlier pass.

  To check whether the PR's own diff is unchanged, compare what each head's
  diff touches: every file's mode and content ID before and after the PR. Fill
  in only the PR number and the two full commit IDs. Never type a branch name
  into a command: it can contain shell syntax. Both fetches run with hooks
  disabled, because a hooks directory in the checkout can come from the PR.
  Every step is chained, so a failed lookup, fetch or diff requests the review.
  Run it where `origin` is the PR's base repository.

  ```sh
  if base_ref=$(gh pr view <pr-number> --json baseRefName --jq .baseRefName) &&
    git -c core.hooksPath=/dev/null fetch --quiet origin \
      "+refs/heads/${base_ref}:refs/remotes/origin/${base_ref}" &&
    base=$(git rev-parse --verify --quiet "refs/remotes/origin/${base_ref}^{commit}") &&
    { git cat-file -e '<passed-head-sha>^{commit}' 2>/dev/null ||
      git -c core.hooksPath=/dev/null fetch --quiet origin <passed-head-sha>; } &&
    passed=$(git diff --raw --no-renames --no-abbrev --ignore-submodules=none \
      "$base...<passed-head-sha>") &&
    new=$(git diff --raw --no-renames --no-abbrev --ignore-submodules=none \
      "$base...<new-head-sha>") &&
    [ "$passed" = "$new" ]; then
    echo 'PR diff unchanged'
  else
    echo 'PR diff changed or not comparable: request Security Review'
  fi
  ```

  Only the line `PR diff unchanged` means the earlier pass still covers the new
  head. Any other outcome, including an error, means the head needs Security
  Review. When it is not needed, post one PR comment with the new head SHA,
  "Security Review not required" and the head that passed with the same diff.

## Workflow

1. Confirm the repository, PR, current head SHA, branch/worktree, changed files, checks, review results, and open threads. Preserve unrelated work.
2. For lower-trust contributor refs, disable hooks per Git command before `fetch`, `checkout`/`switch`, `worktree add`, `commit`, and `push`, using `git -c core.hooksPath=/dev/null ...` or an empty hooks directory outside the checkout. Run PR-controlled checks only in disposable, credential-free isolation; otherwise skip and report them. Do not change shared Git config.
3. Check the reviews the head needs on the initial head and after each push by
   reading the "Codex Review Summary" on the PR. Compare each review's status
   and reviewed commit with the current full head SHA; use the summary's
   machine-readable `headSha` when present, and verify abbreviated SHAs against
   the full head. A missing, pending, or stale result for a needed review is
   incomplete. Poll an active run every 30 seconds for up to 10 minutes; report
   a run that errors or remains pending as blocked.
4. Before requesting a review for a stale commit, refresh the PR summary once
   after 30 seconds in case a run already registered. Treat a queued, pending, or running result for that review type on the
   current head as already in progress. A Codex `eyes` reaction confirms that
   its matching request comment is running; correlate it to the current head
   using the SHA recorded when this workflow posted the request. A run or
   reaction tied to an older head does not cover the current head. If the
   summary or request state cannot be read or correlated to a SHA, report the
   uncertainty rather than risk a duplicate request.
5. After the initial head and every push to a new head, when a needed review is
   stale and no request or run for the current head exists, add a PR
   conversation comment with the exact trigger: `@codex review` for Code Review
   or `@codex security review` for Security Review. Request each needed type
   that has not started on the current head, instead of waiting for an
   automatic review. Skip a type that the head does not need or that is already
   queued, running, or complete on the current head. Record each request's
   review type, head SHA, comment ID, and time. Do not post the same trigger
   again for that review type and SHA. Poll for the running state and result as
   above. If no activity or result appears within 10 minutes, report the
   trigger/configuration issue as blocked instead of repeating the comment.
6. Verify each finding against the current head, make the smallest complete
   fix, run relevant project checks, inspect the diff, then commit and push to
   the PR branch. If no change is needed, do not create an empty commit.
7. Reply to findings with concise evidence, including the fix SHA after
   pushing. Resolve a thread only after its fix is pushed or evidence shows it
   is not actionable. When a finding reports a part that another PR supplies,
   make sure the PR description lists that PR under a `Depends on` heading with
   what it supplies, adding the entry if it is missing, and reply with the
   dependency. Never merge unless asked.
8. Treat a "Complete"/pass status in the review summary only as that review run
   finishing, not as overall completion. After each review completes, recheck
   the PR for unanswered comments and open threads, and reply to every one. The
   flow is done only when every review the latest pushed head needs has
   explicitly passed on it, a final sweep confirms no
   unanswered comments or open threads remain,
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
    draft-skipping CI does not rerun on every fix push. Fix, push, request the
    reviews the new head needs (steps 5-8), then mark ready again. Never merge.

## Handoff

Report the PR link, final SHA, draft/ready state, commits, review outcomes (including any Security Review that was not required, with its evidence), CI result, and any remaining issues.
