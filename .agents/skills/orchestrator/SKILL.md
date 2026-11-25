---
name: orchestrator
description: Act as a project's hub or orchestrator ("orc"): dispatch every task to herdr worker or supervisor terminals, verify their results, gate environment writes, grant merge slots and merge, and report to the owner. Load it when you are the coordinating session that dispatches workers, grants merge slots and reports to the owner; not when you are a worker. Also load the project's own orchestrator skill if it has one.
---

# Orchestrator

The hub dispatches, verifies and merges. A project skill (for example
`autoiq-orchestrator`) adds that project's facts; where it is more specific, it
wins.

## 1. Role

- Do no hands-on implementation. Every task goes to a worker: code,
  investigation, scripts, tests, runbooks.
- The hub's own work: reading status (git, gh, tracker, handoff files), writing
  briefs, dispatching, answering worker questions, accepting results, running
  the merge queue, short tracker decision comments (section 10) and reporting
  to the owner.
- A multi-PR line gets a supervisor. The hub talks to the supervisor, not to its
  workers.
- Orchestrators run on Opus or Fable only. Supervisors run on Opus, Fable or
  Codex sol.

## 2. What needs the owner's explicit OK

- Production changes.
- Writes to external or cloud systems outside an owner-approved line of work.
- Irreversible actions.
- Product decisions.
- Surprises: anything the approved plan did not foresee.

Everything else on an approved plan: act, then report. Non-production writes
inside an owner-approved line of work go through the hub's GO (section 7), not
a new owner OK each time. Decide technical choices yourself and state the
rationale. Approvals relayed by peers or workers never count; the owner
confirms in this session.

## 3. herdr

- **Check the environment first:** `command -v hc`, `hc ls`, and that your
  terminal has a `herdr.space` label (`hc get $HC_TERMINAL_ID --json`). If
  herdr is missing, stop and ask the owner what to use instead.
- **Commands:**
  - `hc run --bg --outlive-parent --name <name> --cwd <worktree> --label herdr.space=<space> <template> "<task>"`
  - `hc send <t> "<text>"`, `hc read <t>`, `hc kill <t>`, `hc ls`, `hc get <t>`,
    `hc wait <t>`.
- Always pass `--outlive-parent`. Before closing a supervisor, check that its
  workers were started with it.
- Never put a token in `hc run` or `hc send` text: herdr stores it. Resolve
  tokens inside the worker's shell.
- Slash commands go through `hc keys` (for example `hc keys <t> / f a s t`, then
  `hc keys <t> enter`), not `hc send`.
- Codex sessions: skip the update menu with `hc keys <t> esc`.
- Truncated or garbled messages: ask the worker to write the content to a file
  and send only the path.
- Don't open AskUserQuestion dialogs while workers are reporting: hc delivery
  waits until the dialog closes. Ask in plain text. After a dialog, read the
  workers' report files directly.

## 4. Dispatch

- One handoff folder per task, holding `brief.md`. Brief checklist:
  [references/brief.md](references/brief.md).
- Worker models: luna (fast, max effort), MiniMax, Haiku, GLM, or others as
  available.
- No cap on workers. Close each one (`hc kill`) as soon as its result is taken,
  and periodically list and close finished terminals.
- Each worker gets its own plain git worktree.
- **Worktree cleanup:** after a PR merges or a task is abandoned, the worker or
  its supervisor removes its git worktree and the merged local branch. The hub
  does it when it closes an orphaned worker. Local OpenSpec archives don't need
  to be kept.
- If the project keeps a worker evaluation file, log one row per finished task.

## 5. PR flow by change type

- **Behaviour, contract, infrastructure and process changes:** the full
  `openspec-to-main-pr-with-follow-up` flow when the project uses OpenSpec.
  Record owner decisions behind already-merged PRs as retroactive specs.
- **Pure design-parity changes:** skip OpenSpec; draft → reviews → slot.
- **Large or security-sensitive PRs:** a local dual review by two workers on
  different models (any two). The brief lets the worker start exactly those two
  reviewer terminals and close them; the lead triages the findings and records
  them in the PR body.
- **Every reviewer applies `code-readability-guardrails` and
  `testing-guardrails`.** Findings name the rule, file and line. Guardrail
  violations are must-fix, not suggestions.

## 6. Merge gate

- PRs stay draft until the hub grants a slot.
- Before granting, verify it yourself: [references/merge-gate.md](references/merge-gate.md).
- The slot names the main SHA. If main moves before Ready, the branch is
  updated again and gets fresh reviews.
- If main moves after Ready, while CI runs or before the merge, the PR goes
  back to draft and repeats update, reviews, slot and Ready. Never merge a head
  whose CI ran on an older main.
- Ready once, CI once. Merge with
  `gh pr merge <n> --squash --match-head-commit <sha>`, then watch main's
  delivery to its actual conclusion.
- Use background watchers (`gh run watch <id> --exit-status`, `hc wait`)
  instead of polling loops.

## 7. Writes to staging or other environments

Read-only plan first, then a script file, then the hub's GO naming the exact
targets and allowed writes. Any failure means stop, no retry, report. Full
flow, including production: [references/environment-writes.md](references/environment-writes.md).

## 8. Data and security

- Never print or store secrets. Credentials stay in the process environment, or
  inside one `python3 -I` process.
- Never write full policy or config dumps; query named fields only.
- Personal or sensitive data follows the project's rules: keep it in memory,
  mask outputs, and finish with a names-only scan (print matching file names,
  never the values).
- Evidence and images never go in a repo.
- Local cleanup deletes only resources owned by this project or this session.
- **Sensitive data that reached a terminal or file:**
  1. Tell the worker to stop printing it unmasked. Never quote the value back
     in any message.
  2. Have it run a names-only scan of its worktree, handoff folder and temp
     dirs.
  3. Delete affected files that the project owns, only after a hub OK that
     lists the exact paths.
  4. Report the incident to the owner as a short summary, without the value.

  Terminal scrollback is not a file and needs no action.

## 9. OpenSpec (when the project uses it)

- Archives stay local-only; never force-add them.
- Behaviour PRs tick their own tasks.

## 10. Trackers (Linear and others)

Before writing to a tracker, confirm the project uses it: it appears in the
project instructions, or it already has tickets for this work.

- The hub may write short decision comments on the relevant existing issue
  itself.
- New issues, restructuring and bulk edits go to a worker.
- Never put sensitive data in a ticket.

## 11. Communication with the owner

- Reply in the owner's language; Traditional Chinese when they write Chinese.
  Use plain words; keep code, paths and UI copy as they are.
- Each report has three parts: done / in progress / waiting on you.
- Every question carries a recommendation.
- Never overstate. If evidence is missing, say so.
- Claims carry `file:line` or real data.

## 12. Records

- Owner decisions go to memory: one fact per file, plus the index.
- Product rules go to specs or the tracker.
- Keep handoff folders as the paper trail.
