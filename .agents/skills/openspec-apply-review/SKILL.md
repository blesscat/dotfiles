---
name: openspec-apply-review
description: Apply an OpenSpec change, then verify it with exactly two independent reviewers per round, for at most five rounds.
---

# OpenSpec Apply Review

Own apply and independent review only. Do not sync, archive, commit, push, or
create a PR. A passing result hands control back to the caller; the caller
continues to sync only when that next phase is authorized.

## Apply and establish scope

Record initial worktree status and the existing diff before using
`$openspec-apply-change`. Preserve pre-existing work. Determine review scope
from the task's actual changes, not a blanket exclusion of every initially dirty
file. When changes share a file, distinguish their hunks and necessary context;
pause only if ownership cannot be separated safely.

Complete pending tasks and relevant checks before dispatching reviewers.
Repair recoverable failures within the approved intent. Do not waive specified
behavior or mark partial work complete to reach review.

## Review packet

After apply, obtain `openspec instructions apply --change "<name>" --json`
using the same selected root and `--store <id>` when applicable. Read its
contextFiles and capture:

- change, planning root/store, schema, apply state, and task progress;
- concrete context paths and acceptance criteria;
- baseline, current diff, included changes, and excluded pre-existing changes;
- validation commands and results.

For later rounds, refresh CLI state and the current diff. Reuse context already
read only when it remains unchanged; reread changed or newly relevant artifacts.
Give each fresh reviewer enough current context to judge the result independently.

## Exactly two reviewers

Dispatch exactly two independent, read-only subagents per round, in parallel
when supported. Both receive the same current packet and round number.
Do not substitute a self-review or a single reviewer.

- Reviewer A checks OpenSpec requirements, scenarios, design, and task compliance.
- Reviewer B checks implementation behavior, integration, regressions, and tests.

Both may inspect directly required dependencies to understand changed behavior.
Keep actionable findings within this change; exclude unrelated cleanup,
speculative improvements, and personal style preferences. Reviewers must not
edit, stage, commit, install, publish, sync, archive, or trigger external actions.

Require each report to include a verdict, prioritized findings with file:line
evidence and the affected requirement or contract, minimal remediation,
verification gaps, and residual risk. A passing report needs evidence of what
was inspected, not just a verdict label. Wait for both reports before triage.

## Triage and bounded fixes

The primary agent validates findings against evidence and the approved intent.
Dismiss duplicates, unsupported claims, and out-of-scope requests with a reason.
Severity follows concrete impact; do not promote minor findings to force a round.

Fix valid in-scope findings and rerun affected checks. Necessary tests, helpers,
or configuration files do not by themselves expand scope when they implement
already agreed behavior. Ask only when the fix changes intended behavior,
acceptance criteria, authority, or a material product/design decision.

The initial pair is round 1. After fixing a major, critical, or blocking finding,
or otherwise materially changing behavior, refresh the packet and obtain another
pair. Never run more than five rounds. Round 5 must itself pass: a fix after a
failing fifth round remains unreviewed and cannot pass this invocation.
Do not start round 6.

The gate passes only when both current reports contain no valid in-scope major,
critical, or blocking findings. Report minor findings as residual risk.
Missing subagent capability, incomplete reports, unresolved material ambiguity,
or a failing fifth round blocks handoff.

## Handoff

Report completed tasks, reviewed scope and exclusions, both final verdicts,
round count, accepted/dismissed findings, verification results, and residual risk.
On failure, report the unresolved condition without claiming readiness for sync,
archive, or publication.
