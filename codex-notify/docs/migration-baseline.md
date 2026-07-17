# Notification migration baseline

Captured on 2026-07-16 before repository-managed installation work.

## Repository state

The pre-existing working tree was captured in baseline commit
`6784a90b5c9be92a87959d921512675713984b9d`
(`chore: capture dotfiles and notification change plan`). It contains the
OpenSpec artifacts and the user's existing fish, Ghostty, and Yazelix changes.
The implementation branch starts from that commit so those paths can be kept
separate from notification implementation work.

## Installed scripts

| Script | Mode | Size | SHA-256 |
| --- | --- | ---: | --- |
| `~/.local/bin/codex-notify` | `755` | 4862 | `9a6655f064471029b5a4e2f8d74d9683e6de0d01d265bbcb5cc6a442a4cc7767` |
| `~/.local/bin/codex-permission-notify` | `755` | 2282 | `cc2bc61ccd7c8aaba9c5ff9fc40aaf15113d3c8f6fbe96875f439786296b09e6` |
| `~/.local/bin/codex-notification-route` | `755` | 6342 | `9f60dea1286d9a13e8f9c1256fe513e59136f32b305513b26e455591ba1e6e49` |

The repository copies matched these hashes before any portability edits.

## Installed helper application

`codesign --verify --deep --strict --verbose=2
~/.local/share/codex-notify/terminal-notifier.app` exited successfully and
reported that the app is valid on disk and satisfies its designated
requirement.

## Owned configuration shape

- Top-level Codex `notify` invokes Sky Computer Use with `turn-ended`, then
  chains to `~/.local/bin/codex-notify --native-only`.
- `[tui].notifications` is `false`.
- `hooks.json` contains one `PermissionRequest` matcher (`*`) with one
  command hook targeting `~/.local/bin/codex-permission-notify` and timeout
  `10`.

Only those entries are candidates for installer ownership; unrelated
configuration and hooks must be preserved.

## Behavior suite

`/bin/zsh ~/.codex/tests/codex-notify-test.zsh` exited successfully with:

```text
PASS: signed helper + codex-notify behavior suite
```
