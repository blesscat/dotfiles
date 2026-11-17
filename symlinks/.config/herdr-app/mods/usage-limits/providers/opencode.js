// OpenCode: local numeric token statistics from schema adapters, or the CLI fallback.
// Both use today since local midnight and today plus the six previous calendar days.
import { spendReport, errorReport } from "../lib/report.js";

const SOURCE = "OpenCode usage";

const isNum = (v) => typeof v === "number" && Number.isFinite(v);
const isObj = (v) => v !== null && typeof v === "object" && !Array.isArray(v);
const num = (v) => (v > 0 ? v : 0);

// input + output + reasoning + cache read + cache write. null when the reply's format isn't
// the one known, so a change shows as failing rather than as "unused": tokens must be an
// object with numbers for input and output; reasoning, cache, cache.read and cache.write may
// be missing (0), and when present must be a number, or for cache an object.
function total(reply) {
  const t = reply?.tokens;
  if (!isObj(t) || !isNum(t.input) || !isNum(t.output)) return null;
  if (t.reasoning !== undefined && !isNum(t.reasoning)) return null;
  const c = t.cache ?? {};
  if (t.cache !== undefined && !isObj(t.cache)) return null;
  if ((c.read !== undefined && !isNum(c.read)) || (c.write !== undefined && !isNum(c.write))) return null;
  return num(t.input) + num(t.output) + num(t.reasoning) + num(c.read) + num(c.write);
}

export function parse(text, now) {
  let data;
  try {
    data = JSON.parse(String(text ?? ""));
  } catch {
    data = null;
  }
  const today = total(data?.today);
  const week = total(data?.week);
  if (today === null || week === null) return errorReport(SOURCE, "No stats from OpenCode", now);
  return spendReport(SOURCE, now, today, week);
}

export default {
  id: "opencode",
  name: "OpenCode",
  icon: "icons/opencode.svg",
  kind: "spend",
  tint: true, // a one-color glyph: drawn in the text color, as Herdr does for its own
  helper: "helpers/opencode-spend.sh",
  parse,
};

