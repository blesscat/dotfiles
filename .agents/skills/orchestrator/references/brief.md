# Dispatch brief checklist

Each task gets its own handoff folder with a `brief.md` that covers:

- **Goal:** the outcome, and how the lead will check it.
- **Read first:** the files, specs, memory notes and earlier handoffs to read
  before starting. If the worker's harness has no tracker connector, export the
  tracker text into the folder.
- **Scope and non-scope:** what to change and what not to touch. When the
  worker must not read beyond certain files, say "only these files".
- **Rules:** the project rules that apply: environments, secrets, PR flow and
  change type, review gate, merge slot. For a PR that needs a local dual
  review, name the two reviewer templates the worker may start.
- **Screenshots:** take them only as a headless browser page screenshot of the
  worker's own local or approved URL, checking the page URL before saving.
  Never use desktop or window capture tools: they can capture the owner's
  screen, including sign-in pages with live codes.
- **Stop conditions:** a gate in the brief; anything that blocks or hangs;
  needing to install or download a tool; anything outside scope. On any of
  these, stop and report; don't work around it.
- **Output:** the deliverables and the report path inside the folder.
- **Report back:** the exact command, for example
  `hc send <lead> "<2-4 sentence summary> Report: <path>"`.

Launch the worker with the folder in its task:

```sh
hc run --bg --outlive-parent --name <prefix>-<task> --cwd <worktree> \
  --label herdr.space=<space> <template> \
  "Read <folder>/brief.md and do the task exactly. Report to <lead> with hc send."
```
