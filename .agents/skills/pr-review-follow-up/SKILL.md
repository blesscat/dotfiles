---
name: pr-review-follow-up
description: Fix and follow a PR review loop until the Code and Security Reviews that the latest pushed head needs have passed, request a merge slot while the PR is still a draft, then mark it ready once and wait for the required checks.
---

# PR Review Follow-up

Use after the user authorizes fixing and following reviews. It works on draft PRs: the PR stays draft until the merge-queue owner grants a slot, because every push to a ready PR starts a full CI run of about 30 minutes in this repository, so Ready is reserved for a final head. Do not rely on automatic reviews: request each needed review by comment unless it is already queued, running, or complete on the current head. Review-only requests do not authorize edits, commits, pushes, or thread changes.

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
   review loop is done only when every review the latest pushed head needs has
   explicitly passed on it, a final sweep confirms no unanswered comments or
   open threads remain, and the checks the repository's CI runs for the changed
   areas pass locally, including the database tests and the Docker-related
   checks when those areas changed. A locally failing check goes through the
   fix loop (steps 6-8); one that cannot run or cannot be fixed is a blocker.
9. With every gate except CI passed, request a merge slot from the merge-queue
   owner (the coordinating hub, or the user when no queue exists) while the PR
   is still a draft: report the head SHA, each review request's comment ID, and
   the unresolved-thread count. Marking the PR ready before a slot is granted
   is out of flow. Only a granted slot, whose answer names the main SHA to
   take, leads to Ready: update the branch onto that SHA, run the review loop
   the new head needs (steps 3-8), then run `gh pr ready <n>` once and wait for
   the repository's required checks on that head (for example `CI result`).
   Report the CI run ID to the queue owner, who merges. Never push to a ready
   PR while its CI is running. A denied slot keeps the PR draft: fix the cited
   gates (steps 3-8) and request one again. Only a conflict-free update onto
   the named main SHA is covered by the grant; any other push after the slot
   request (a late finding, a conflict-resolution commit, a post-update fix)
   or a main that moved past the named SHA voids the slot: redo the affected
   gates and request a fresh slot before Ready. After `gh pr ready`, do not
   request reviews again for that transition.
10. A ready PR's head must stay final. Before pushing again for any reason (a
    late review finding, a failed check, a main update, a typo), run
    `gh pr ready --undo` first, push every fix, run the review loop the new
    head needs (steps 3-8), request a fresh merge slot (step 9), then mark it
    ready once. Never merge.

## Handoff

Report the PR link, final SHA, draft/ready state, commits, review outcomes (including any Security Review that was not required, with its evidence), merge-slot request and grant, CI run ID and result, and any remaining issues.
