---
name: openspec-apply-review
description: Apply an OpenSpec change and gate handoff with exactly two read-only, scope-bounded subagent reviews, repeating at most five rounds until no valid major findings remain.
---

# OpenSpec Apply Review

Run the normal OpenSpec apply workflow and then hold the change at a controlled
compliance gate. This skill owns only apply and review; it does not synchronize
main specs, archive the change, commit, push, or create a pull request.

## Review contract

The following rules are mandatory:

- Dispatch exactly two independent, read-only subagents in every completed
  review round. Run them in parallel when the available delegation mechanism
  supports it, then wait for both reports.
- Review only the current change's OpenSpec context and the implementation
  scope produced by that apply. Do not turn unrelated files, repository cleanup,
  refactoring preferences, or future work into findings.
- Reviewers may inspect a directly referenced dependency when it is necessary
  to understand changed behavior, but may not propose changes outside the
  supplied scope. The main-spec sync, archive, publishing, and PR workflow are
  outside this review's scope.
- A review round is the pair of reviewer reports. The initial pair is round 1;
  the total number of rounds must not exceed 5. Never start a sixth round.
- Round 5 is the final independently reviewed state. If it produces a valid
  in-scope major, critical, or blocking finding, fixing it does not permit
  handoff without another pair: do not start a sixth round and keep this
  invocation blocked because the fix is unreviewed.
- The gate passes only when both reports have no valid in-scope major, critical,
  or blocking finding. Minor findings may be reported as residual risk, but
  they must not be relabeled as major merely to force another round.
- If round 5 still has a valid unresolved major, critical, or blocking finding,
  stop and block the handoff. Do not claim readiness for sync, archive, or
  publication.

## 1. Apply first

Accept the same optional change name as `$openspec-apply-change`.

Before applying, record the current worktree status and changed paths so
pre-existing user changes remain outside the review boundary:

```bash
git status --short --untracked-files=all
git diff --name-only
```

Use `$openspec-apply-change` with the same change argument. Let it select the
change, read the CLI-provided context files, implement every pending task, run
the relevant checks, and mark completed tasks. Preserve any paths that were
already changed before apply. If a required task overlaps a pre-existing dirty
path and ownership cannot be separated safely, pause and report that scope
conflict instead of absorbing the user's changes.

If apply is paused, blocked, errors, or leaves pending tasks, stop without
dispatching reviewers and report the apply state. Review starts only after the
apply workflow is complete.

## 2. Build the review packet

After apply, run the equivalent store-scoped command used by apply. Preserve the
same selected store or local OpenSpec root; do not silently rediscover a
different change location. When apply selected a named store, include its id:

```bash
openspec instructions apply --change "<name>" --json --store "<store-id>"
```

When no named store was selected, omit `--store` and use the nearest local
OpenSpec root, as apply did.

Read every path in `contextFiles` from that result. Capture:

- the change name and schema;
- the completed-task summary and the `all_done`/progress state;
- the exact validation commands and results already run; and
- the changed-file set relative to the pre-apply baseline.

The review scope consists of the context files, the files changed by this apply,
and a directly required test or configuration file when it is needed to verify
the changed behavior. Exclude paths that were already dirty before apply. If
the ownership of a changed path cannot be determined, stop and ask rather than
expanding the scope silently.

Do not use a raw repository-wide review as a substitute for this scope. Review
the implementation against the proposal, specs, design, tasks, and acceptance
criteria for this change, not against unrelated conventions or an imagined
follow-up change.

## 3. Dispatch the two reviewers

For each round, first use Section 2 to build a fresh review packet. Round 1 uses
the packet captured after apply; before every later round, rerun the
store-scoped instructions command, reread every current `contextFiles` path, and
recapture the current state, progress, validation results, and changed-file scope
after the accepted fix. If the packet cannot be rebuilt, keep the gate blocked.
Give both subagents the same snapshot and the round number. Use the available
subagent/delegation mechanism; do not silently replace the two-subagent review
with a self-review or a local-only review. Both subagents must be told that they
are read-only and must not edit, stage, commit, install, publish, sync specs,
archive, or invoke unrelated external actions.

Use complementary lenses while keeping the same scope:

Reviewer A — OpenSpec compliance:

```text
Review completed OpenSpec change <name> for round <round>.

You are the independent compliance reviewer. Work read-only: do not edit,
stage, commit, install, publish, sync, or archive anything.

Read these OpenSpec context files:
<contextFiles>

Inspect only this implementation scope:
<changedFiles>

Pre-existing paths are excluded:
<excludedFiles>

Review packet (populate this identically for both reviewers):
- Change: <name>
- OpenSpec store/root: <store-id or local root>
- Schema: <schema>
- Apply state: <state>; progress: <completed>/<total>
- Completed tasks: <completed-task-summary>
- Validation commands and results: <validation-summary>

Check whether the implemented behavior satisfies the proposal, requirements,
scenarios, design decisions, tasks, and acceptance criteria. Do not report
style preferences, unrelated cleanup, speculative improvements, or requests
that would expand the approved change.

Return:
- Verdict: pass / major-findings / needs-discussion
- Findings ordered by severity. For each finding include severity, in-scope
  status, file:line evidence, the exact OpenSpec requirement or task affected,
  and a minimal remediation.
- Missing or weak behavior-focused tests within scope
- Verification gaps
- Residual risks when there are no substantive findings
```

Reviewer B — implementation, verification, and scope:

```text
Review completed OpenSpec change <name> for round <round>.

You are the second independent reviewer. Work read-only: do not edit, stage,
commit, install, publish, sync, or archive anything.

Read these OpenSpec context files:
<contextFiles>

Inspect only this implementation scope:
<changedFiles>

Pre-existing paths are excluded:
<excludedFiles>

Review packet (populate this identically for both reviewers):
- Change: <name>
- OpenSpec store/root: <store-id or local root>
- Schema: <schema>
- Apply state: <state>; progress: <completed>/<total>
- Completed tasks: <completed-task-summary>
- Validation commands and results: <validation-summary>

Check behavior, edge cases, integration points, regression risk, and the
behavior-focused verification for the specified change. Confirm that the
implementation stays within the proposal and task scope. Do not report style
preferences, unrelated cleanup, speculative improvements, or requests that
would expand the approved change.

Return:
- Verdict: pass / major-findings / needs-discussion
- Findings ordered by severity. For each finding include severity, in-scope
  status, file:line evidence, the exact OpenSpec requirement or task affected,
  and a minimal remediation.
- Test or validation gaps within scope
- Residual risks when there are no substantive findings
```

Require both reports before triage. A report without evidence, a requirement
mapping, or a clear in-scope decision is incomplete and cannot by itself pass
the gate.

## 4. Triage and bounded remediation

The primary agent, not either reviewer, decides whether a finding is valid:

1. Check each finding against the context files and the changed-file boundary.
   Dismiss out-of-scope, speculative, duplicate, or unsupported findings with a
   short reason; they do not block the gate.
2. Treat an in-scope missing or incorrect specified behavior, failed acceptance
   scenario, task that is marked complete but is not fully implemented, or
   verification failure that prevents compliance as a valid major, critical, or
   blocking finding when its evidence warrants that severity. A style
   preference, unrelated defect, optional refactor, and future enhancement are
   not blocking findings.
3. Fix valid findings only within the existing OpenSpec intent. If the fix
   requires new behavior, a new file family, a changed acceptance criterion, or
   another scope expansion, pause and request an artifact update instead of
   silently broadening the change.
4. Run targeted validation after every accepted fix and update the tasks
   artifact only when the task is fully complete. If a fix materially changes
   behavior, it requires another pair of reviewers.
5. When any valid in-scope major, critical, or blocking finding was fixed and
   the current round is below 5, rebuild the review packet and start the next
   round with both subagents. Do not send only the reviewer who found it. Keep
   the round count visible and stop at 5.
6. If round 5 contains any valid in-scope major, critical, or blocking finding,
   whether or not a fix was applied, the gate remains blocked. The fix has not
   received a new independent pair; do not hand off on the basis of an
   unreviewed fix and do not start round 6.

If both reports contain no valid in-scope major, critical, or blocking findings,
the review gate passes even when non-blocking residual risks are recorded. If a
requirement is ambiguous and the disagreement could change behavior, mark the
round `needs-discussion` and pause; do not guess or declare pass.

## 5. Handoff

Only after a passing pair of reports, report:

- change name, apply schema, and `all_done`/task progress;
- review rounds used, confirming each round had exactly two reports;
- the final verdict and any dismissed findings with reasons;
- changed-file scope and excluded pre-existing paths; and
- validation commands/results and non-blocking residual risk.

Then hand off to `$openspec-sync-specs`. A blocked fifth round, unavailable
subagent support, incomplete report, unresolved ambiguity, or unresolved major,
critical, or blocking finding is a failed gate and must not hand off.

## Guardrails

- Do not dispatch review before all apply tasks are complete.
- Keep both reviewers read-only; the primary agent owns edits, triage, and
  verification.
- Preserve unrelated user changes and never use `git add -A` or a force-add to
  manufacture scope.
- Do not claim compliance from reviewer verdict labels alone; require evidence
  tied to the OpenSpec artifacts.
- Do not use review rounds to negotiate a larger change. Update the OpenSpec
  artifacts through the appropriate workflow first when requirements change.
