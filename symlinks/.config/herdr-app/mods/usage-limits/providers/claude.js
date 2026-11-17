// Claude Code: the CLI's own `get_usage` control request (helpers/claude-usage.sh).
// The CLI authenticates itself; nothing here sees a token.
import { makeWindow, okReport, errorReport, unavailableReport, toEpoch, jsonLines } from "../lib/report.js";

const SOURCE = "claude CLI";
const HOUR = 3600;
const WEEK = 7 * 24 * HOUR;

function scopeName(scope) {
  return scope?.model?.display_name || scope?.surface || null;
}

function windowFromLimit(l) {
  const kind = String(l.kind ?? "limit");
  const scope = scopeName(l.scope);
  const resetsAt = toEpoch(l.resets_at);
  if (kind === "session") return makeWindow({ id: "session", short: "5h", long: "5-hour", percent: l.percent, resetsAt, durationSec: 5 * HOUR });
  if (kind === "weekly_all") return makeWindow({ id: "weekly_all", short: "wk", long: "Weekly", percent: l.percent, resetsAt, durationSec: WEEK });
  if (kind === "weekly_scoped" && scope) {
    return makeWindow({ id: `weekly_scoped:${scope}`, short: scope, long: `Weekly · ${scope}`, percent: l.percent, resetsAt, durationSec: WEEK });
  }
  const name = scope ?? kind.replace(/_/g, " ");
  return makeWindow({ id: scope ? `${kind}:${scope}` : kind, short: name, long: name, percent: l.percent, resetsAt });
}

function legacyWindows(rl) {
  const out = [];
  if (rl.five_hour?.utilization != null) {
    out.push(makeWindow({ id: "session", short: "5h", long: "5-hour", percent: rl.five_hour.utilization, resetsAt: toEpoch(rl.five_hour.resets_at), durationSec: 5 * HOUR }));
  }
  if (rl.seven_day?.utilization != null) {
    out.push(makeWindow({ id: "weekly_all", short: "wk", long: "Weekly", percent: rl.seven_day.utilization, resetsAt: toEpoch(rl.seven_day.resets_at), durationSec: WEEK }));
  }
  return out;
}

export function parse(text, now) {
  const msg = jsonLines(text).find((m) => m.type === "control_response");
  if (!msg) return errorReport(SOURCE, "No reply from the claude CLI", now);
  const res = msg.response ?? {};
  if (res.subtype !== "success") return errorReport(SOURCE, String(res.error ?? "claude CLI could not read usage"), now);
  const body = res.response ?? {};
  const rl = body.rate_limits ?? {};
  const windows = Array.isArray(rl.limits)
    ? rl.limits.filter((l) => l && l.percent != null).map(windowFromLimit)
    : legacyWindows(rl);
  if (windows.length === 0) return unavailableReport(SOURCE, "No subscription limits", now);
  return okReport(SOURCE, now, windows, body.subscription_type ?? null);
}

export default {
  id: "claude",
  name: "Claude",
  icon: "icons/claude.svg",
  helper: "helpers/claude-usage.sh",
  parse,
};

