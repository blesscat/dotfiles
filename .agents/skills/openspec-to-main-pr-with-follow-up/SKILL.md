---
name: openspec-to-main-pr-with-follow-up
description: Run the OpenSpec-to-main PR workflow, then follow reviews until the latest head passes Code Review and Security Review.
---

# OpenSpec to Main PR with Follow-up

Use this workflow when the user asks to run the OpenSpec-to-main delivery and
continue following the resulting PR's reviews in the same task.
For a request to create a PR without review follow-up, use
`$openspec-to-main-pr` on its own.

1. Run `$openspec-to-main-pr` to completion and capture its PR URL or number.
   It creates a PR ready for review after its OpenSpec, implementation, dual
   review, spec sync, archive, and publishing phases.
2. After PR creation succeeds, run `$pr-review-followup` for that exact PR and
   continue until its completion conditions pass for the latest pushed head.
   A pending review, an older review result, or one clean round is not
   completion.
3. The user's explicit request for this combined workflow authorizes the full
   follow-up loop defined by `$pr-review-followup`, including fixes, checks,
   commits, pushes, and review-thread replies or resolutions allowed by that
   skill. Keep all follow-up commits on the PR branch. Never merge or push
   directly to `main`.

If the first workflow is blocked or produces no PR URL, stop before follow-up
and report the last completed phase and the specific blocker. If follow-up is
blocked, use its handoff rules and report the exact pending review, error, or
other prerequisite.
