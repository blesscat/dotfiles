// Explicit Codex choices. Nothing here infers a session from a shared folder.
import { parseSession } from "./session.js";
const ID = /^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$/;
export const KEY_BINDINGS = "usage-limits.session-bindings";

export function codexBinding(bindings, terminal, pid, patchbay, boot) {
  const b = bindings?.[terminal];
  if (b?.pid === pid && ID.test(b.id ?? "") && typeof b.identity === "string" && b.identity) {
    return { id: b.id, identity: b.identity, manual: true };
  }
  const p = patchbay?.[terminal];
  if (p?.pid === pid && p.manual === true && ID.test(p.id ?? "") && Number.isSafeInteger(p.startedAt) && p.startedAt > 0) {
    // The helper verifies the OS process start time. UI reloads do not end this lease.
    return { id: p.id, identity: `started:${p.startedAt}`, manual: false };
  }
  if (boot && p?.boot === boot && p.pid === pid && p.manual === true && ID.test(p.id ?? "")) {
    return { id: p.id, identity: "", manual: false };
  }
  return null;
}

export function parseSessionChoices(text, pid) {
  try {
    const v = JSON.parse(text);
    if (v?.pid !== pid || typeof v.identity !== "string" || !v.identity || v.identity.length > 100 || !Array.isArray(v.choices)) return null;
    return { pid, identity: v.identity, choices: v.choices.filter((c) => c && ID.test(c.id ?? "") && typeof c.title === "string").slice(0, 12).map((c) => ({ id: c.id, title: c.title.slice(0, 100) })) };
  } catch { return null; }
}

export function sessionReadResult(result, app, binding, pid, title) {
  const data = result.code === 0 ? parseSession(result.stdout, app) : null;
  return {
    session: data ? { data, title } : null,
    choices: app === "codex" && result.code === 2 ? parseSessionChoices(result.stdout, pid) : null,
    manual: Boolean(binding?.manual),
  };
}

