# Installed setup

Based on nozikov/herdr-usage-limits at
`f4e49f2f3dca0f22b0293c87f53abef6e2573511` (MIT).

The author's UI, Claude/Codex helpers, settings and folding remain. The existing
ZCode, MiniMax and Gemini quota collectors are included in this mod's own helpers
and adapted through `providers/extra.js`. Each requested extra provider is queried
in one batch across local and ready connected Herdr machines, every five minutes.
Disabling it in both Bar and Panel excludes it from that batch. A manual refresh
uses the author's 30-second cooldown. No other mod needs to remain mounted.

Those existing collectors read account files and use the official Z.ai and
MiniMax quota APIs. ZCode uses its installed native keyring module on b650,
decrypting only its cached coding-plan key in memory; no login is changed.
Gemini reads the Antigravity quota cache already configured in this session.
Credentials and raw API responses never reach the UI. Missing quota and quota
authentication errors are reported separately; a failed quota query never implies
that ZCode itself is logged out. A source machine is available on the card header.

The standalone upstream only supports local session statistics. Remote terminal
sessions are therefore omitted from the optional This session block to avoid
reading a coincidentally matching local PID. Account quotas are independent of
which terminal is focused. OpenCode and Pi remain available in Settings, initially
disabled in this personal layout because the requested bar contains five services.

The previous `main-over9k-usage` layout and its mod remain available as a rollback.

Window labels such as 5h and wk remain visible at every bar density. Calm windows
omit reset countdowns by default to leave room for labels and bars; the panel
retains every countdown. The panel is widened for the five providers.

## Explicit quota redemption

The 額度重置 button only opens a management panel and reads available coupons.
Selecting a Codex or ZCode reset only opens a second confirmation screen. Only
the separate 確認使用 1 張券 click invokes redemption. There is no automatic reset,
no purchase operation, and no global reset-all operation.

- Codex: the installed official app-server's account/rateLimits/read and
  account/rateLimitResetCredit/consume. The exact selected credit and account are
  checked, and the backend receives an idempotency key.
- ZCode: the official zcode.z.ai/api/v1/coding-plan/reset/status GET and /use POST,
  using the current ZCode and Z.ai login JWTs only in memory on the source machine.
  Only the currently configured Z.ai personal Coding Plan is supported. Account
  snapshots are checked again immediately before redemption.
- Claude: opens https://claude.ai/settings/usage for its official confirmation.
- MiniMax and Gemini/Antigravity: official quota-management/rules pages; their
  public documentation was not found to expose a direct reset operation.

Pending confirmation attempts are saved in usage-limits.reset-attempts before
sending. An uncertain response or UI restart reuses the same idempotency key and
selected credit. It does not retry automatically or switch to another credit.
Read-only live checks and mocked redemption tests were used during installation;
no real reset coupon was redeemed by the installer.

The reset panel shows the earliest expiry among queried Codex/ZCode coupons,
and each provider's earliest expiry, as local date/time plus a countdown. The
usage card separately shows its nearest quota reset. Expired and unknown dates
are excluded. ZCode redeems the oldest-issued coupon according to its own rules;
its earliest-expiry display describes the category, not a selected coupon ID.

Native commands open read-only management/review windows, without redemption:
`usage-limits.resets`, `usage-limits.review-codex`,
`usage-limits.review-zcode-5h`, `usage-limits.review-zcode-wk`.
`usage-limits.close-resets` closes that window. Only the visible confirmation
button in the review window can send a redemption request; there is no command
to redeem a coupon.
