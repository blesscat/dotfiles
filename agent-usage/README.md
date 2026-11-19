# Agent usage page

A small page that shows how much quota is left for Claude Code, Codex, ZCode,
MiniMax (mcode) and Antigravity, so a phone can check it. It runs on Linux and
macOS with Python 3.8+ and only the standard library; the ZCode helper needs
Node 18+.

## Install

```sh
~/.cider/agent-usage/install.sh
```

- Linux: a systemd user service, `agent-usage.service`. For it to start at
  boot and keep running after logout, linger must be on
  (`loginctl enable-linger "$USER"`); the script says so when it is off.
- macOS: a launchd agent, `local.cider.agent-usage`, that starts at login.
  Logs go to `~/Library/Logs/agent-usage.log`.

Run the script again after changing anything here; it rewrites the service and
restarts it. `./install.sh uninstall` stops and removes the service and keeps
`~/.config/agent-usage` and the caches.

The service files are generated per machine and are not tracked. Optional
settings given while running the script are written into them:

| Setting | Default |
| --- | --- |
| `AGENT_USAGE_HOST` | This machine's Tailscale IPv4 address, so only your tailnet can open the page. It waits for Tailscale to come up. Without Tailscale installed: `127.0.0.1`. |
| `AGENT_USAGE_PORT` | `8790` |
| `AGENT_USAGE_NODE` | The newest nvm node, then Homebrew's, then `node` on `PATH` |
| `AGENT_USAGE_CODEX` | `codex` on `PATH`, then `~/.local/bin/codex`, then Homebrew's |
| `AGENT_USAGE_PYTHON` | Linux: `/usr/bin/python3`. macOS: Homebrew's `python3`, then `/usr/bin/python3` |

For example: `AGENT_USAGE_PORT=8791 ~/.cider/agent-usage/install.sh`.

## Open it on a phone

`http://<tailscale-ip>:8790` works from any device on the tailnet. To install
it as an app (PWA), the page needs HTTPS. Put Tailscale's HTTPS in front of it;
`serve` stays inside the tailnet, unlike `funnel`:

```sh
tailscale serve --bg --https=9443 http://<tailscale-ip>:8790
```

Linux needs `sudo` for this unless you are the Tailscale operator. Then open
`https://<machine>.<tailnet>.ts.net:9443` and use the browser's install or
"Add to Home Screen" option.

## Data sources

Each source is read on the machine the service runs on, so the page shows that
machine's most recent view.

| Agent | Source |
| --- | --- |
| Claude Code | `~/.cache/agent-usage/claude/<session>.json`, written by `symlinks/.claude/statusline.sh`. Point Claude Code's `statusLine` at a status line script with that block. |
| Codex | `codex app-server` (`account/rateLimits/read`, what Codex's `/usage` reads), every 5 minutes, including the usage limit resets. Codex keeps handling its own login. Falls back to the last `rate_limits` event in `~/.codex/sessions/**/rollout-*.jsonl` when that is newer or the app server cannot be used. |
| ZCode | Z.ai quota API, every 5 minutes. `zcode-usage.cjs` decrypts the key ZCode is signed in with, in memory only, through the system keyring. If the keyring cannot be read, it uses opencode's Z.ai key. |
| ZCode reset cards | The unused Quota Reset Cards (weekly and 5-hour) and when they expire, every 5 minutes, read with ZCode's login. Personal plans only. |
| MiniMax | MiniMax coding plan API, every 5 minutes, with mcode's login token while it is valid (about two hours after mcode last ran). The token is never refreshed here. |
| Antigravity | `~/.cache/over9k/usage/antigravity.json`, written by the Antigravity CLI status line capture. |

`~/.config/agent-usage/keys` (mode 600) can hold `ZAI_API_KEY` and
`MINIMAX_API_KEY` to use instead of the signed-in credentials. The install
script creates it with both left blank. Keys never go in this repository.

## Resets

The Codex and ZCode cards list the resets left, with a "使用" button for each
kind that has one. The button asks for confirmation, then the server spends one:

- Codex: `account/rateLimitResetCredit/consume` through `codex app-server`. If
  nothing needs resetting, Codex answers `nothingToReset` and nothing is used.
- ZCode: `zcode-usage.cjs use WEEK|FIVE_HOUR`, the request ZCode's own reset
  button sends. A weekly card also refills the 5-hour quota.

A spent reset cannot be undone. Each press carries an idempotency key, so a
retry after a dropped connection does not spend a second one.

`POST /api/reset` only acts when the request comes from the page itself: the
`Host` and `Origin` must be an IP address, a `*.ts.net` name, `localhost` or
this machine's name; `Sec-Fetch-Site`, when sent, must be `same-origin`; and the
body must be JSON. Another web site cannot send that without a CORS preflight,
which this server never answers. Anyone who can open the page can still press
the button, so keep the page on the tailnet. Each attempt is logged to the
service log.

Claude Code also has a limit reset for some accounts, but it only works at a
usage limit, and Claude Code offers it there itself. The page does not show it.

## macOS notes

- The first ZCode read may ask whether `node` can use the "ZCode Credential
  Encryption" Keychain item. Allow it. If you deny it, the opencode key is used.
- If the macOS firewall is on, allow incoming connections for the Python that
  runs the server.

## Files

- `server.py`: the HTTP server and data readers. It serves only a fixed list of files.
- `zcode-usage.cjs`: the ZCode quota and reset card helper; it can also use a card.
- `index.html`, `manifest.webmanifest`, `sw.js`, `icons/`: the page and its PWA files.
  `icons/make-icons.py` redraws the icons.
- `install.sh`: installs the service.
