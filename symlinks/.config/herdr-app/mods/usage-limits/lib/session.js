// The session in the focused terminal, as plain data. Pure: no Herdr imports.
import { level, tokens } from "./format.js";
import { isOnBar } from "./prefs.js";

// Agents whose block names the agent and its model; Claude's and Codex's don't.
export const AGENT_NAMES = { opencode: "OpenCode", pi: "Pi" };
const MODEL_ID = /^[A-Za-z0-9._:/-]+$/;

// Session: { app, tokens, window|null, calls, compactions|null, last: { trigger, pre, post }|null }
// plus, for the agents in AGENT_NAMES only, model: string|null.
// compactions is null where the agent's log isn't known to record them, which is not 0.
export function parseSession(text, app) {
  const f = Object.fromEntries((text ?? "").trim().split(/\s+/).map((kv) => kv.split("=")));
  const n = (k) => (/^\d+$/.test(f[k] ?? "") ? Number(f[k]) : null);
  if (!n("tokens")) return null;
  const model = Object.hasOwn(AGENT_NAMES, app) ? { model: MODEL_ID.test(f.model ?? "") ? f.model : null } : {};
  return {
    app,
    tokens: n("tokens"),
    window: n("window") || null,
    calls: n("calls") ?? 0,
    compactions: n("compactions"),
    last: f.lastTrigger ? { trigger: f.lastTrigger, pre: n("lastPre"), post: n("lastPost") } : null,
    ...model,
  };
}

const percent = (s) => Math.round((s.tokens / s.window) * 100);
const plural = (n, word) => `${n} ${word}${n === 1 ? "" : "s"}`;

function context(s) {
  if (!s.window) return { text: tokens(s.tokens), detail: null, fill: null, level: "ok" };
  const p = percent(s);
  return { text: `${p}%`, detail: `${tokens(s.tokens)} of ${tokens(s.window)}`, fill: Math.min(1, s.tokens / s.window), level: level(p) };
}

// who: "Pi · demo-model", "Pi" without a model, null for Claude and Codex.
function who(s) {
  const name = Object.hasOwn(AGENT_NAMES, s.app) ? AGENT_NAMES[s.app] : null;
  return name && s.model ? `${name} · ${s.model}` : name;
}

export function sessionView(s, title) {
  if (!s) return null;
  return {
    title,
    who: who(s),
    context: context(s),
    calls: plural(s.calls, "call"),
    compactions: s.compactions != null ? plural(s.compactions, "compaction") : null,
    last: s.last ? `last: ${s.last.trigger}, ${tokens(s.last.pre)} → ${tokens(s.last.post)}` : null,
  };
}

export function sessionOnBar(s, prefs) {
  if (!s) return [];
  const c = context(s);
  return [
    { id: "context", text: `ctx ${c.text}`, level: c.level },
    { id: "calls", text: `⇄ ${s.calls}`, level: "ok" },
    s.compactions != null ? { id: "compactions", text: `▼ ${s.compactions}`, level: "ok" } : null,
  ].filter((n) => n && isOnBar(prefs, n.id));
}

