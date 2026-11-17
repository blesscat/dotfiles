// Pi: tokens spent, added up from its session files (helpers/pi-spend.sh prints
// "<ISO timestamp> <totalTokens>" per reply). Days are local: today starts at local
// midnight, the 7 days at local midnight six days before (today included).
import { spendReport } from "../lib/report.js";

const SOURCE = "Pi session files";
const LINE = /^(\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(?:\.\d+)?Z) (\d+)$/;

export function parse(text, now) {
  const d = new Date(now * 1000);
  const today = new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime();
  const weekStart = new Date(d.getFullYear(), d.getMonth(), d.getDate() - 6).getTime();
  let day = 0;
  let week = 0;
  for (const line of String(text ?? "").split("\n")) {
    const m = LINE.exec(line.trim());
    if (!m) continue;
    const at = Date.parse(m[1]);
    const n = Number(m[2]);
    if (!Number.isFinite(at) || !Number.isSafeInteger(n)) continue;
    if (at >= weekStart) week += n;
    if (at >= today) day += n;
  }
  return spendReport(SOURCE, now, day, week);
}

export default {
  id: "pi",
  name: "Pi",
  icon: "icons/pi.svg",
  kind: "spend",
  tint: true, // a one-color glyph: drawn in the text color, as Herdr does for its own
  helper: "helpers/pi-spend.sh",
  parse,
};

