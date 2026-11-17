// What the bar and its hover card show, as plain data. Pure: no Herdr imports.
import { timeLeft, level, pace, ago, tokens } from './format.js'
import { isShown, inPanel, isFolded, spendOnBar, effectivePrefs } from './prefs.js'
import { PROVIDERS } from '../providers/index.js'

const STALE_AFTER = 15 * 60 // s

// text is the full reading; brief is what's left when the bar runs out of room:
// an amber or red window keeps its time, a calm one gives it up.
export function segmentView(w, now, showResetTime = false) {
  if (w.resetsAt != null && w.resetsAt <= now) {
    return {
      id: w.id,
      short: w.short,
      text: '—',
      brief: '—',
      level: 'ok',
      fill: 0,
      tick: null,
      expired: true,
    }
  }
  const lv = level(w.percent)
  const left = w.resetsAt != null ? ` · ${timeLeft(w.resetsAt - now)}` : ''
  const rem = Math.max(0, 100 - w.percent) // shown as remaining; level and fill stay on used
  const brief = `${rem}%${lv !== 'ok' ? left : ''}`
  return {
    id: w.id,
    short: w.short,
    text: showResetTime ? `${rem}%${left}` : brief,
    brief,
    level: lv,
    fill: Math.min(1, Math.max(0, w.percent / 100)),
    tick: pace(w, now)?.elapsed ?? null,
    expired: false,
  }
}

const cap = (s) => s.charAt(0).toUpperCase() + s.slice(1)

const VERDICT = {
  'on pace': "you're on pace",
  ahead: "you're using it up too fast",
  under: 'you have room to spare',
}

// What the tick means, in this limit's own numbers. No tick, nothing to explain.
function tickHint(percent, p) {
  if (!p) return null
  return `Tick: ${Math.round(p.elapsed * 100)}% of the time has passed.\nYou've used ${percent}%, so ${VERDICT[p.verdict]}.`
}

function cardRow(w, now) {
  if (w.resetsAt != null && w.resetsAt <= now) {
    return {
      id: w.id,
      long: w.long,
      percent: '—',
      level: 'ok',
      fill: 0,
      tick: null,
      hint: null,
      left: '',
      detail: 'reset, waiting for a new reading',
    }
  }
  const p = pace(w, now)
  return {
    id: w.id,
    long: w.long,
    percent: `${Math.max(0, 100 - w.percent)}% left`,
    level: level(w.percent),
    fill: Math.min(1, Math.max(0, w.percent / 100)),
    tick: p?.elapsed ?? null,
    hint: tickHint(w.percent, p),
    left: w.resetsAt != null ? timeLeft(w.resetsAt - now) : '',
    detail: '',
  }
}

const isSpend = (p) => p.kind === 'spend'
const passed = (w, now) => w.resetsAt != null && w.resetsAt <= now

// The window closest to running out: highest percent, ties to the sooner reset (an unknown
// reset counts as later). A window whose reset has passed loses unless it's the only one.
export function tightest(windows, now) {
  let best = null
  for (const w of windows ?? []) {
    if (!best) {
      best = w
      continue
    }
    if (passed(w, now) !== passed(best, now)) {
      if (passed(best, now)) best = w
      continue
    }
    const r = (x) => x.resetsAt ?? Infinity
    if (w.percent > best.percent || (w.percent === best.percent && r(w) < r(best))) best = w
  }
  return best
}

// The reading to show: the current one when ok, else the last good one.
const shown = (st) => (st?.report?.status === 'ok' ? st.report : (st?.lastGood ?? null))

// "A provider with limits is installed": some limits provider has a reading with a window,
// its current one or, failing that, its last good one. One that's no longer installed doesn't count.
export function hasLimits(states, providers = PROVIDERS) {
  return providers.some(
    (p) =>
      !isSpend(p) &&
      states[p.id]?.installed !== false &&
      (shown(states[p.id])?.windows.length ?? 0) > 0,
  )
}

// Every limits provider being fetched, and not known to be missing, has answered once.
export function limitsSettled(states, prefs, providers = PROVIDERS) {
  return providers.every(
    (p) =>
      isSpend(p) ||
      !wanted(prefs, p, states, providers) ||
      states[p.id]?.installed === false ||
      states[p.id]?.report != null,
  )
}

const spendDefault = (states, prefs, providers) =>
  limitsSettled(states, prefs, providers) && !hasLimits(states, providers)

// On the bar or in the panel: the provider is fetched.
export function wanted(prefs, p, states, providers = PROVIDERS) {
  if (inPanel(prefs, p.id)) return true
  return isSpend(p)
    ? spendOnBar(prefs, p.id, spendDefault(states, prefs, providers))
    : isShown(prefs, p.id)
}

// A spend provider's panel line: its numbers, from the last good reading when failing.
function spendGroup(p, st, now) {
  const { report = null, lastGood = null } = st ?? {}
  if (!report) return null // nothing known yet: no line rather than an empty one
  const source = shown(st)
  if (source && !(source.spend?.week > 0)) return null // installed, unused
  const g = {
    providerId: p.id,
    name: p.name,
    icon: p.icon,
    kind: 'spend',
    plan: null,
    status: '',
    failed: false,
    dim: false,
    age: null,
    rows: [],
    folded: false,
    summary: null,
    today: null,
    week: null,
  }
  if (report.status === 'ok') {
    g.status = `updated ${ago(report.observedAt, now)}`
    g.dim = now - report.observedAt > STALE_AFTER
  } else {
    g.status = report.message ?? report.status
    g.failed = true
    g.dim = true
    g.age = lastGood ? `Last reading ${ago(lastGood.observedAt, now)}` : null
  }
  if (source) {
    g.today = tokens(source.spend.today)
    g.week = tokens(source.spend.week)
  }
  return g
}

// The hover panel: everything known, less what was taken out of the panel.
// What's hidden from the bar still shows here.
export function cardModel(states, now, providers = PROVIDERS, prefs = effectivePrefs()) {
  const groups = []
  for (const p of providers) {
    if (!inPanel(prefs, p.id)) continue
    const { report = null, lastGood = null, installed = null } = states[p.id] ?? {}
    if (installed === false) continue
    if (isSpend(p)) {
      const g = spendGroup(p, states[p.id], now)
      if (g) groups.push(g)
      continue
    }
    const g = {
      providerId: p.id,
      name: p.name,
      icon: p.icon,
      plan: null,
      status: 'loading…',
      failed: false,
      dim: false,
      age: null,
      rows: [],
    }
    let windows = []
    if (report?.status === 'ok') {
      g.plan = report.plan ? cap(report.plan) : null
      g.status = `updated ${ago(report.observedAt, now)}`
      g.dim = now - report.observedAt > STALE_AFTER
      windows = report.windows
    } else if (report) {
      g.status = report.message ?? report.status
      g.failed = true
      g.dim = true
      g.age = lastGood ? `Last reading ${ago(lastGood.observedAt, now)}` : null
      windows = lastGood?.windows ?? []
    }
    g.rows = windows.map((w) => cardRow(w, now))
    const t = tightest(windows, now)
    groups.push({
      ...g,
      kind: 'limits',
      folded: isFolded(prefs, p.id),
      summary: t ? cardRow(t, now) : null,
    })
  }
  return { groups, empty: groups.length === 0, arrows: groups.length >= 3 }
}

// The panel opens on limits: settings last only until it closes. It closes closeDelay
// after the pointer leaves, and nothing reports that, so it's worked out on the way back.
export function panelOnEnter(panel, leftAt, nowMs, closeDelay) {
  return leftAt != null && nowMs - leftAt > closeDelay ? 'limits' : panel
}

// ProviderState: { report: Report|null, lastGood: Report|null, installed: true|false|null }
export function barModel(states, prefs, now, providers = PROVIDERS) {
  const groups = []
  let spendOn = null // worked out once, only if a spend provider is listed
  for (const p of providers) {
    if (isSpend(p)) {
      const st = states[p.id]
      const source = shown(st)
      if (!st?.report || st.installed === false || !(source?.spend?.week > 0)) continue
      spendOn ??= spendDefault(states, prefs, providers)
      if (!spendOnBar(prefs, p.id, spendOn)) continue
      const failing = st.report.status !== 'ok'
      const dim = failing || now - source.observedAt > STALE_AFTER
      groups.push({
        providerId: p.id,
        name: p.name,
        icon: p.icon,
        mark: failing ? '!' : null,
        dim,
        segments: [],
        spend: tokens(source.spend.today),
      })
      continue
    }
    if (!isShown(prefs, p.id)) continue
    const st = states[p.id] ?? { report: null, lastGood: null, installed: null }
    if (st.installed === false) continue
    let mark = null
    let source = st.report
    if (!st.report) {
      mark = '…'
      source = null
    } else if (st.report.status !== 'ok') {
      mark = '!'
      source = st.lastGood
    }
    const segments = (source?.windows ?? [])
      .filter((w) => isShown(prefs, p.id, w.id))
      .map((w) => segmentView(w, now, prefs.showResetTime))
    const dim = mark === '!' || (source != null && now - source.observedAt > STALE_AFTER)
    groups.push({ providerId: p.id, name: p.name, icon: p.icon, mark, dim, segments })
  }
  return { groups, empty: groups.length === 0 }
}

// Rough text widths at 11.8px (labels 10.5px): enough to pick a density, not to lay out.
const GROUP = 20 // icon + gaps
const spendWidth = (g) => 8 + 6.5 * 'today'.length + 7 * g.spend.length + 12
function segmentWidth(s, density, keepLabels = false) {
  const text = 7 * (density === 3 ? s.brief : s.text).length + 12
  if (density >= 2 && !keepLabels) return text
  const label = 8 + 6.5 * s.short.length
  return density === 0 ? label + 30 + text : label + text
}

// 0 = label + bar + percent, 1 = no bars, 2 = no labels, 3 = no time on calm windows.
export function chooseDensity(model, widthPx, showBars = true, keepLabels = false) {
  for (const d of showBars ? [0, 1, 2, 3] : [1, 2, 3]) {
    const need = model.groups.reduce(
      (sum, g) =>
        sum +
        GROUP +
        (g.spend != null ? spendWidth(g) : 0) +
        g.segments.reduce((a, s) => a + segmentWidth(s, d, keepLabels), 0),
      0,
    )
    if (need <= widthPx) return d
  }
  return 3
}
