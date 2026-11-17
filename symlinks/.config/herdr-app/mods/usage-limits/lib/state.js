// How one fetch result changes a provider's state. Pure.
// ProviderState: { report: Report|null, lastGood: Report|null, installed: true|false|null }

// report: the parsed Report, or null when the CLI isn't installed (installed=false).
// An error report may carry `fallback` (an older, dated reading, e.g. Codex's
// session log); it only becomes lastGood when nothing fresher is known.
export function nextState(prev, report, installed) {
  const lastGood = prev?.lastGood ?? null;
  if (!installed) return { report: null, lastGood, installed: false };
  if (report.status === "ok") return { report, lastGood: report, installed: true };
  const fb = report.fallback;
  const fresher = fb && fb.observedAt != null && (!lastGood || fb.observedAt > lastGood.observedAt);
  return { report, lastGood: fresher ? fb : lastGood, installed: true };
}

