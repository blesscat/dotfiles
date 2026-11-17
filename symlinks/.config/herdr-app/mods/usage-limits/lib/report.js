// Shapes shared by every provider.
//
// Window: { id, short, long, percent (0–100), resetsAt (epoch s | null), durationSec (s | null) }
// Report: { status: "ok" | "unavailable" | "error", message, plan, observedAt (epoch s), source, windows }
// A spend provider's ok report has no windows and carries spend: { today, week } (token counts;
// week is the last 7 days, today included).

export function makeWindow({ id, short, long, percent, resetsAt = null, durationSec = null }) {
  return {
    id,
    short,
    long: long ?? short,
    percent: Math.round(Number(percent)),
    resetsAt: resetsAt == null ? null : Math.floor(Number(resetsAt)),
    durationSec,
  };
}

export function okReport(source, now, windows, plan = null, observedAt = now) {
  return { status: "ok", message: null, plan, observedAt, source, windows };
}

export function spendReport(source, now, today, week, observedAt = now) {
  return { status: "ok", message: null, plan: null, observedAt, source, windows: [], spend: { today, week } };
}

export function errorReport(source, message, now) {
  return { status: "error", message, plan: null, observedAt: now, source, windows: [] };
}

export function unavailableReport(source, message, now) {
  return { status: "unavailable", message, plan: null, observedAt: now, source, windows: [] };
}

// ISO 8601 or epoch seconds → epoch seconds; anything else → null.
export function toEpoch(value) {
  if (value == null) return null;
  if (typeof value === "number") return Number.isFinite(value) ? Math.floor(value) : null;
  const ms = Date.parse(value);
  return Number.isNaN(ms) ? null : Math.floor(ms / 1000);
}

// Every line of `text` that parses as a JSON object.
export function jsonLines(text) {
  const out = [];
  for (const line of String(text ?? "").split("\n")) {
    const s = line.trim();
    if (!s.startsWith("{")) continue;
    try {
      out.push(JSON.parse(s));
    } catch {
      // not JSON: skip (banners, partial lines)
    }
  }
  return out;
}

