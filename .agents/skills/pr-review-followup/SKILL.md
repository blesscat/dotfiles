---
name: pr-review-followup
description: Fix and follow an explicitly authorized PR review loop until Code and Security Review pass on the latest pushed head.
---

# PR Review Follow-up

Use this skill only when the user has authorized the mutation loop (for example,
"fix it, commit, push, resolve, and keep following"). A request to review only
does not authorize source edits, commits, GitHub comments, thread resolution, or
pushes.

## Completion condition

Do not stop after one review round. The task is complete only when all of these
are true for the latest pushed head SHA:

- Code Review is explicitly completed with no actionable findings.
- Security Review is explicitly completed with no security findings.
- No actionable inline review thread remains unresolved.
- Local verification relevant to the changes passes, or every unavailable check
  is reported with its exact command and reason.
- All changes from this task are committed and pushed to the intended PR branch.
  Unrelated pre-existing work remains untouched and is reported separately.

"Running", an old review result, a green local test, or a resolved thread alone
is not completion. If a new review produces a finding, return to the fix loop.

## Establish scope before changing anything

1. Identify the repository from the current workspace remote and resolve the PR
   number or URL. Fetch PR metadata: title, description, base, head branch,
   current head SHA, state, mergeability, changed files, and available CI.
2. Preserve existing user work. Inspect `git status` before switching branches;
   do not overwrite dirty changes. Fetch the PR head and work on its branch (or
   an isolated worktree) so commits go to the PR, not to `main`.
3. Read repository `AGENTS.md`, README/project configuration, and the relevant
   source, tests, schemas, migrations, deployment files, and call sites.
4. Collect the complete diff plus all review evidence: top-level review
   summaries, Code Review and Security Review results, inline threads including
   resolved/outdated state, and CI/status checks. Separate findings for the
   current head from stale findings on earlier SHAs.

When connected GitHub tools are available, prefer the repository-native PR
operations (`get_pr_info`, PR patch/diff, PR comments, review submissions,
review threads, commit status, reply, resolve, and issue comment). Use `git`
for branch, file, test, commit, and push operations. Do not merge the PR unless
the user explicitly asks for merging.

## Review and fix loop

For each batch of findings on the current head, verify and fix valid findings
in severity order. Then validate the cohesive batch and publish it once:

1. Reproduce or verify the finding against the current diff and surrounding
   code. Check whether it is still valid, outdated, or already covered by a
   later commit. Do not manufacture findings or resolve a valid finding without
   addressing it.
2. Implement the smallest complete fix that preserves the requested behavior.
   Add or update behavior-focused regression coverage when the risk warrants
   it. Follow repository formatting, lint, type-check, build, and test rules.
3. Run focused checks first, then the repository checks required by local
   instructions. Record exact commands and outcomes. Do not claim a check
   passed without running it.
4. Inspect the final diff and `git diff --check`. Create one or more focused
   commits for the batch on the PR branch, then push once. Prefer a new fix commit; do not rewrite shared
   history unless the user explicitly requests it.
5. After the push succeeds, reply to each addressed inline thread with the fix
   commit SHA and concise evidence. Resolve the thread only after the reply and
   only when the finding is fixed or the response establishes that it is not
   actionable. Never resolve a thread merely to make the PR look clean.
6. Re-read the PR at the new head. If the review integration does not
   automatically run for new commits, trigger exactly one Code Review and one
   Security Review for that SHA (for example `@codex review` and
   `@codex security review`). Avoid duplicate triggers while either review is
   already running.

## Follow-up monitoring

After every push, monitor the latest review summary and thread list. Prefer a
product-provided wait/monitor mechanism; otherwise poll at bounded intervals
and provide a concise progress update during long waits. Never use a blocking
wait longer than 60 seconds.

For each new review result:

- Confirm it names the current head SHA.
- Treat `running` or missing status as pending, not as success.
- Inspect new inline comments and open threads, including comments that arrive
  after the summary changes.
- If Code Review or Security Review has a finding, repeat the fix/verify/
  commit/push/reply/resolve cycle.
- If both explicitly report no findings, perform one final thread, branch,
  worktree, and CI/status check before handing off.

If the external review service remains pending or errors, say exactly which
review is pending/error and keep the task open when the product supports
continued monitoring. Do not claim the PR is clean based only on local checks.

## Handoff

Report the PR link, final head SHA, commits made, findings fixed, threads
resolved, final Code Review and Security Review outcomes, verification commands,
and any checks that could not run. Mention non-blocking warnings separately.
