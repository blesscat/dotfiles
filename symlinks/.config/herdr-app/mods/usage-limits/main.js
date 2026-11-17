// Usage limits: every Claude Code / Codex limit window in the status bar, and one
// panel on hover: the details, and behind ⚙ the checkboxes to choose what shows.
//
// Data comes from small helpers that run the CLIs themselves (helpers/*.sh);
// Claude/Codex use native CLIs. The three extra providers use the existing account collectors; see LOCAL-SETUP.md.
import { View, div, image, svg } from 'gpui-kit'
import { HoverCard, h_flex, v_flex } from 'gpui-base'
import {
  exec,
  focused,
  theme,
  props,
  shared,
  setShared,
  appHome,
  checking,
  nextCommand,
  openOverlay,
  closeOverlay,
} from 'herdr'
import { PROVIDERS as BUILT_IN_PROVIDERS } from './providers/index.js'
import { EXTRA_PROVIDERS } from './providers/extra.js'
import { ExtraSource } from './lib/extra-source.js'
import { ResetPanel } from './lib/reset-panel.js'
import { nearestQuotaReset } from './lib/reset.js'
import { timeLeft } from './lib/format.js'
const PROVIDERS = [
  BUILT_IN_PROVIDERS[1],
  BUILT_IN_PROVIDERS[0],
  ...EXTRA_PROVIDERS,
  ...BUILT_IN_PROVIDERS.slice(2),
]
import {
  barModel,
  cardModel,
  chooseDensity,
  hasLimits,
  limitsSettled,
  panelOnEnter,
  wanted,
} from './lib/view.js'
import {
  effectivePrefs,
  inPanel,
  isOnBar,
  isShown,
  spendOnBar,
  toggleFolded,
  toggleOnBar,
  togglePanel,
  toggleProvider,
  toggleShowBars,
  toggleShowResetTime,
  toggleSpendOnBar,
  toggleWindow,
} from './lib/prefs.js'
import { sessionOnBar, sessionView } from './lib/session.js'
import { KEY_BINDINGS, codexBinding, sessionReadResult } from './lib/session-binding.js'
import { nextState } from './lib/state.js'
import { errorReport } from './lib/report.js'

const MOD = 'usage-limits'
const KEY_STATE = 'usage-limits.state'
const KEY_PREFS = 'usage-limits.prefs'
const KEY_REFRESH = 'usage-limits.refresh'
const FETCH_EVERY = 5 * 60 // s, installed providers
const MISSING_EVERY = 60 * 60 // s, not-installed providers
const REFRESH_COOLDOWN = 30 // s
const SESSION_EVERY = 10 * 1000 // ms, at most this often on hover
const SPEND_TIMEOUT = 15 * 1000 // ms, a spend helper is killed after this (pi-spend.sh has no deadline of its own)
const SESSION_TIMEOUT = 15 * 1000 // ms, session helpers are bounded even if process inspection hangs
const AGENTS = { 'claude-code': 'claude', codex: 'codex', opencode: 'opencode', pi: 'pi' } // Herdr's app name → session.sh
const BAR_W = 30
const PANEL_W = 420
const PANEL_BAR_W = 110
const SESSION_BAR_W = 60
const LEFT_W = 48 // the time-left column in the panel
const PCT_W = 36 // the percent column in the panel
const FOLDED_BAR_W = 44
const PANEL_BOX_W = 40 // the settings' right-hand column, under "Panel"
const PANEL_OPEN_DELAY = 350 // ms, so passing over the bar doesn't flash it
const PANEL_CLOSE_DELAY = 300 // ms, lets the pointer cross from the bar to the card

const now = () => Math.floor(Date.now() / 1000)

// Windows: Git's installer puts git on PATH but usually not its sh. When "sh" can't
// start, git says where it lives (…/Git/mingw64/libexec/git-core → …/Git/bin/sh.exe).
let SH = 'sh'
const sh = (bin, args, opts) => (opts ? exec(bin, args, opts) : exec(bin, args))
async function runSh(args, opts) {
  try {
    return await sh(SH, args, opts)
  } catch (e) {
    if (SH !== 'sh' || !String(e?.message ?? e).includes('cannot run')) throw e // not a timeout
    const core = (await exec('git', ['--exec-path']).catch(() => null))?.stdout.trim() ?? ''
    const root = core.replace(/\/[^/]+\/libexec\/git-core$/, '')
    if (!root || root === core) throw e
    const r = await sh(`${root}/bin/sh.exe`, args, opts).catch(() => null)
    if (!r) throw e
    SH = `${root}/bin/sh.exe`
    return r
  }
}

// A provider's icon. A tinted one (a one-color glyph) is drawn in the given color, like text,
// so it shows on a dark and a light theme alike; any other is the picture as it is.
const TINTED = new Set(PROVIDERS.filter((p) => p.tint).map((p) => p.id))
const providerIcon = (id, path, color) =>
  TINTED.has(id) ? svg(path).size(13).text_color(color) : image(path).size(13)
const states = () => shared(KEY_STATE) ?? {}

function levelColor(level, t) {
  if (level === 'hot') return t.ansi1 ?? t.blocked
  if (level === 'warn') return t.ansi3 ?? t.done
  return t.ansi2 ?? t.working
}

const textColor = (level, text, t) =>
  level === 'ok' ? (text === '—' ? t.dim : t.foreground) : levelColor(level, t)

// A limit's number always wears its level, green included; session numbers don't.
const limitColor = (level, text, t) => (text === '—' ? t.dim : levelColor(level, t))

function usageBar(width, fill, tick, color, t) {
  return div()
    .relative()
    .w(width)
    .h(4)
    .rounded(2)
    .bg(t.border)
    .flex_none()
    .child(
      div()
        .absolute()
        .left(0)
        .top(0)
        .h(4)
        .rounded(2)
        .w(Math.round(width * fill))
        .bg(color),
    )
    .when(tick != null, (b) =>
      b.child(
        div()
          .absolute()
          .top(-2)
          .left(Math.round(width * tick))
          .w(1)
          .h(8)
          .bg(t.foreground)
          .opacity(0.75),
      ),
    )
}

export default class UsageLimits extends View {
  init(_props, cx) {
    this.extraSource = new ExtraSource()
    this.resetPanel = new ResetPanel()
    this.width = 0
    this.panel = 'limits' // or "settings"
    this.leftAt = null // ms, when the pointer left the bar and the panel
    this.terminal = null // the focused terminal the session below belongs to
    this.session = null // { data: Session, title } or null
    this.sessionAt = 0 // ms, last session read
    this.sessionBusy = false
    this.sessionChoices = null
    this.sessionChoosing = false
    this.sessionManual = false
    this.sessionRevision = 0
    this.lastFetch = {} // providerId → epoch s of last attempt
    this.busy = {} // providerId → fetch in flight
    this.unwanted = {} // providerId → true while on neither the bar nor the panel
    this.hovered = null // the provider whose panel header is under the pointer
    this.foldedHere = new Set() // providers folded by a click since the panel opened: their rows' space is kept
    this.sessionWas = this.sessionWanted(this.prefs())
    this.seenRefresh = shared(KEY_REFRESH) ?? 0
    if (checking()) return
    if (props()?.view === 'reset-manager') {
      this.resetPanel.load(cx, states(), props()?.review ?? null)
      cx.timer.every(60000, (cx) => cx.notify())
      return
    }
    cx.spawn(async (cx) => {
      for (;;) {
        const command = await nextCommand()
        if (command === 'close-resets') {
          if (this.resetOverlayId) closeOverlay(this.resetOverlayId)
          this.resetOverlayId = null
        } else {
          const review = {
            'review-codex': { provider: 'codex', type: 'codexRateLimits' },
            'review-zcode-5h': { provider: 'zcode', type: 'FIVE_HOUR' },
            'review-zcode-wk': { provider: 'zcode', type: 'WEEK' },
          }[command]
          if (command === 'resets' || review) {
            if (this.resetOverlayId) closeOverlay(this.resetOverlayId)
            this.resetOverlayId = openOverlay({
              mod: MOD,
              kind: 'dialog',
              width: 448,
              frame: 'none',
              props: { ...this.prefs(), view: 'reset-manager', review: review ?? null },
            })
          }
        }
        cx.notify()
      }
    })
    this.tick(cx, true)
    cx.timer.every(60 * 1000, (cx) => this.tick(cx, false))
  }

  // Fetch whatever is due and wanted, then redraw (countdowns and pace move every minute).
  // A provider on neither the bar nor the panel isn't fetched; its last state is kept.
  tick(cx, force) {
    const st = states()
    const prefs = this.prefs()
    for (const p of PROVIDERS) {
      if (!wanted(prefs, p, st, PROVIDERS)) continue
      const every = st[p.id]?.installed === false ? MISSING_EVERY : FETCH_EVERY
      if (force || now() - (this.lastFetch[p.id] ?? 0) >= every) this.fetch(p, cx)
    }
    this.readSession(cx)
    cx.notify()
  }

  fetch(p, cx) {
    if (checking()) return
    if (this.busy[p.id]) return
    this.busy[p.id] = true
    this.lastFetch[p.id] = now()
    cx.spawn(async (cx) => {
      if (p.extra) {
        const ids = EXTRA_PROVIDERS.filter((item) =>
          wanted(this.prefs(), item, states(), PROVIDERS),
        ).map((item) => item.id)
        try {
          const reports = await this.extraSource.read(ids)
          setShared(KEY_STATE, {
            ...states(),
            [p.id]: nextState(states()[p.id], reports[p.id], true),
          })
        } catch {
          setShared(KEY_STATE, {
            ...states(),
            [p.id]: nextState(states()[p.id], errorReport(p.id, '暫無用量資料', now()), true),
          })
        } finally {
          this.busy[p.id] = false
          cx.notify()
        }
        return
      }
      let next
      const prev = states()[p.id] ?? { report: null, lastGood: null, installed: null }
      const spend = p.kind === 'spend'
      try {
        const r = spend
          ? await runSh([`${appHome()}/mods/${MOD}/${p.helper}`], { timeout: SPEND_TIMEOUT })
          : await runSh([`${appHome()}/mods/${MOD}/${p.helper}`])
        if (spend && r.code !== 0 && r.code !== 127) {
          // A failed spend helper prints nothing, which would parse as "0 tokens": say it failed.
          next = nextState(
            prev,
            errorReport(p.helper, `Couldn't count ${p.name} tokens`, now()),
            true,
          )
        } else {
          next =
            r.code === 127
              ? nextState(prev, null, false)
              : nextState(prev, p.parse(r.stdout, now()), true)
        }
      } catch (e) {
        next = spend
          ? nextState(prev, errorReport(p.helper, String(e?.message ?? e), now()), true) // e.g. killed at SPEND_TIMEOUT
          : {
              ...prev,
              report: {
                status: 'error',
                message: String(e?.message ?? e),
                plan: null,
                observedAt: now(),
                source: p.helper,
                windows: [],
              },
            }
      }
      this.busy[p.id] = false
      setShared(KEY_STATE, { ...states(), [p.id]: next })
      cx.notify()
    })
  }

  // The session is read only while its block is in the panel or a number of it is on the bar.
  sessionWanted(prefs) {
    return inPanel(prefs, 'session') || prefs.sessionOnBar.length > 0
  }

  // Terminal → its agent's process → that process's session. Any step failing means
  // no block at all: another session's numbers would be worse than none.
  readSession(cx) {
    if (checking()) return
    if (!this.sessionWanted(this.prefs())) {
      this.session = null
      this.sessionChoices = null
      return
    }
    if (this.sessionBusy) return // a hung hc mustn't pile up; it re-reads below if focus moved
    const terminal = this.terminal
    const revision = this.sessionRevision
    this.sessionAt = Date.now()
    if (!terminal || terminal.includes('/')) {
      this.session = null
      this.sessionChoices = null
      return
    }
    this.sessionBusy = true
    cx.spawn(async (cx) => {
      let next = null
      let choices = null
      let manual = false
      try {
        const info = JSON.parse((await exec('hc', ['get', terminal])).stdout)
        const app = AGENTS[info.status?.app]
        const pid = info.foreground?.pid
        if (app && pid) {
          const binding =
            app === 'codex'
              ? codexBinding(
                  shared(KEY_BINDINGS),
                  terminal,
                  pid,
                  shared('patchbay.chat.bindings'),
                  shared('patchbay.sessions')?.boot,
                )
              : null
          const args = [`${appHome()}/mods/${MOD}/helpers/session.sh`, app, String(pid)]
          if (binding) args.push(binding.id, binding.identity)
          const r = await runSh(args, { timeout: SESSION_TIMEOUT })
          const result = sessionReadResult(r, app, binding, pid, (info.cwd ?? '').split('/').pop())
          next = result.session
          choices = result.choices
          manual = result.manual
        }
      } catch {
        next = null
      } finally {
        this.sessionBusy = false
      }
      if (terminal !== this.terminal || revision !== this.sessionRevision) {
        this.readSession(cx) // focus moved on while this was reading
        return
      }
      this.session = this.sessionWanted(this.prefs()) ? next : null // hidden everywhere meanwhile: dropped
      this.sessionChoices = this.sessionWanted(this.prefs()) ? choices : null
      this.sessionManual = manual
      cx.notify()
    })
  }

  chooseSession(row, cx) {
    const choices = this.sessionChoices
    if (!this.terminal || !choices?.choices.includes(row)) return
    setShared(KEY_BINDINGS, {
      ...(shared(KEY_BINDINGS) ?? {}),
      [this.terminal]: { pid: choices.pid, identity: choices.identity, id: row.id },
    })
    this.sessionRevision++
    this.sessionChoices = null
    this.sessionChoosing = false
    this.readSession(cx)
    cx.notify()
  }

  changeSession(cx) {
    const bindings = { ...(shared(KEY_BINDINGS) ?? {}) }
    delete bindings[this.terminal]
    setShared(KEY_BINDINGS, bindings)
    this.sessionRevision++
    this.session = null
    this.sessionManual = false
    this.readSession(cx)
    cx.notify()
  }

  cooling() {
    return now() - Math.floor((shared(KEY_REFRESH) ?? 0) / 1000) < REFRESH_COOLDOWN
  }

  refresh(cx) {
    if (!this.cooling()) setShared(KEY_REFRESH, Date.now())
    cx.notify()
  }

  // Herdr's props come from props(), not init's first argument (shipped mods ignore it too).
  currentStates() {
    return states()
  }

  prefs() {
    return effectivePrefs(shared(KEY_PREFS), props())
  }

  hover(on, cx) {
    if (!on) {
      this.leftAt = Date.now()
      return
    }
    // A panel that closed under the pointer never reported leaving a header.
    if (this.leftAt != null && Date.now() - this.leftAt > PANEL_CLOSE_DELAY) {
      this.hovered = null
      this.foldedHere.clear() // reopened: a kept space goes
    }
    this.panel = panelOnEnter(this.panel, this.leftAt, Date.now(), PANEL_CLOSE_DELAY)
    this.leftAt = null
    if (Date.now() - this.sessionAt >= SESSION_EVERY) this.readSession(cx)
    cx.notify()
  }

  show(panel, cx) {
    if (props()?.view === 'reset-manager' && panel === 'limits') {
      closeOverlay(props().overlay)
      return
    }
    this.panel = panel
    cx.notify()
  }

  // ---------- status bar ----------

  segment(s, density, t) {
    const color = levelColor(s.level, t)
    return h_flex()
      .gap(5)
      .items_center()
      .flex_none()
      .child(div().text_size(10.5).text_color(t.dim).child(s.short))
      .when(density === 0, (e) => e.child(usageBar(BAR_W, s.fill, s.tick, color, t)))
      .child(
        div()
          .whitespace_nowrap()
          .text_color(limitColor(s.level, s.text, t))
          .child(density === 3 ? s.brief : s.text),
      )
  }

  // A spend provider on the bar: today's tokens.
  spendSegment(today, t) {
    return h_flex()
      .gap(5)
      .items_center()
      .flex_none()
      .child(div().text_size(10.5).text_color(t.dim).child('today'))
      .child(div().whitespace_nowrap().text_color(t.foreground).child(today))
  }

  renderBar(cx) {
    const t = theme()
    const st = states()
    const prefs = this.prefs()
    const model = barModel(st, prefs, now(), PROVIDERS)
    const numbers = sessionOnBar(this.session?.data, prefs)
    const numbersWidth = numbers.reduce(
      (w, n) => w + 7 * n.text.length + 14,
      numbers.length ? 14 : 0,
    )
    const density = chooseDensity(
      model,
      this.width
        ? this.width -
            24 -
            numbersWidth -
            model.groups.reduce((sum, group) => sum + group.name.length * 7 + 6, 0)
        : Infinity,
      prefs.showBars,
      true,
    )
    const root = h_flex()
      .id('root')
      .size_full()
      .px(12)
      .items_center()
      .justify_end()
      .overflow_hidden()
      .bg(t.chrome)
      .border_t(1)
      .border_color(t.border)
      .text_size(11.8)
      .text_color(t.muted)
      .on_size_change((size, cx) => {
        this.width = size.width
        cx.notify()
      })
    // Only the limits themselves open the panel, not the empty rest of the block.
    const content = h_flex()
      .id('ul-content')
      .gap(14)
      .items_center()
      .flex_none()
      .on_hover((on, cx) => this.hover(on, cx))
    if (numbers.length) {
      content.child(
        h_flex()
          .gap(10)
          .items_center()
          .flex_none()
          .children(
            numbers.map((n) =>
              div()
                .whitespace_nowrap()
                .text_color(textColor(n.level, n.text, t))
                .child(n.text),
            ),
          ),
      )
      if (!model.empty) content.child(div().w(1).h(14).bg(t.border).flex_none())
    }
    if (model.empty)
      content.child(
        div()
          .id('ul-empty')
          .child(svg(`mods/${MOD}/icons/gauge.svg`).size(14)),
      )
    model.groups.forEach((g, i) => {
      if (i > 0) content.child(div().w(1).h(14).bg(t.border).flex_none())
      content.child(
        h_flex()
          .id(`ul-${g.providerId}`)
          .gap(density === 0 ? 10 : 8)
          .items_center()
          .flex_none()
          .opacity(g.dim ? 0.55 : 1)
          .child(providerIcon(g.providerId, g.icon, t.foreground))
          .child(div().text_size(11).text_color(t.muted).child(g.name))
          .when(g.mark != null, (e) => e.child(div().text_color(t.dim).child(g.mark)))
          .children(g.segments.map((s) => this.segment(s, density, t)))
          .when(g.spend != null, (e) => e.child(this.spendSegment(g.spend, t))),
      )
    })
    const panel = cardModel(st, now(), PROVIDERS, prefs)
    const session = inPanel(prefs, 'session')
      ? sessionView(this.session?.data, this.session?.title)
      : null
    // With nothing to show (no CLI installed, or all of it taken out), settings are all there is.
    const empty =
      panel.empty &&
      !session &&
      !(inPanel(prefs, 'session') && (this.sessionChoices || this.sessionManual))
    if (empty) this.panel = 'settings' // so ticking a Panel box doesn't swap the view under the pointer
    let body =
      this.panel === 'settings' || empty ? this.settings(!empty, t) : this.limits(panel, session, t)
    if (this.panel === 'resets') body = this.resetPanel.render(this, t)
    return root.child(
      HoverCard.new('ul-panel')
        .anchor('bottom_right')
        .open_delay(PANEL_OPEN_DELAY)
        .close_delay(PANEL_CLOSE_DELAY)
        .trigger(content)
        .content(body),
    )
  }

  // ---------- panel: limits ----------

  // ghost: the same row without its id and its hint, for the space a fold keeps.
  cardRow(r, providerId, t, ghost = false) {
    return v_flex()
      .gap(3)
      .child(
        h_flex()
          .when(!ghost, (e) => e.id(`ul-row-${providerId}-${r.id}`))
          .gap(8)
          .items_center()
          .when(!ghost && r.hint != null, (e) => e.tooltip(r.hint))
          .child(div().flex_1().min_w(0).truncate().text_color(t.muted).child(r.long))
          .child(usageBar(PANEL_BAR_W, r.fill, r.tick, levelColor(r.level, t), t))
          .child(
            div()
              .w(36)
              .flex_none()
              .flex()
              .justify_end()
              .whitespace_nowrap()
              .text_color(limitColor(r.level, r.percent, t))
              .child(r.percent),
          )
          .child(
            div()
              .w(LEFT_W)
              .flex_none()
              .flex()
              .justify_end()
              .whitespace_nowrap()
              .text_size(11)
              .text_color(t.dim)
              .child(r.left),
          ),
      )
      .when(r.detail !== '', (e) =>
        e.child(div().text_size(11).text_color(t.dim).truncate().child(r.detail)),
      )
  }

  // A provider with limits. Its header folds it on a click. Open, it is the group as it
  // always was; the arrow joins it only when folded, with three providers or more, or under
  // the pointer. Folded, the header alone carries the tightest window on the rows' columns.
  cardGroup(g, arrows, t) {
    const id = g.providerId
    const folded = g.folded
    const head = h_flex()
      .id(`ul-head-${id}`)
      .tooltip(states()[id]?.report?.source ?? '')
      .gap(6)
      .items_center()
      .cursor_pointer()
      .on_hover((on, cx) => {
        this.hovered = on ? id : this.hovered === id ? null : this.hovered
        cx.notify()
      })
      .on_click((_e, cx) => {
        const next = toggleFolded(this.prefs(), id)
        setShared(KEY_PREFS, next)
        if (next.folded.includes(id)) this.foldedHere.add(id)
        else this.foldedHere.delete(id)
        cx.notify()
      })
      .child(providerIcon(g.providerId, g.icon, t.foreground))
      .child(div().flex_none().font_semibold().child(g.name))
      .when(g.plan != null, (e) =>
        e.child(
          div()
            .flex_none()
            .px(5)
            .rounded(4)
            .bg(t.raised)
            .text_size(10)
            .text_color(t.accent)
            .child(g.plan),
        ),
      )
      .when(folded || arrows || this.hovered === id, (e) =>
        e.child(
          svg(`mods/${MOD}/icons/${folded ? 'chevron-right' : 'chevron-down'}.svg`)
            .size(12)
            .text_color(t.dim),
        ),
      )
    const s = folded ? g.summary : null
    if (!s) {
      if (folded && g.failed)
        return this.kept(
          v_flex()
            .gap(8)
            .child(head.child(this.failure(g.status, t))),
          g,
          t,
        )
      head.child(div().flex_1()).child(
        div()
          .min_w(0)
          .truncate()
          .text_size(11)
          .text_color(g.failed ? levelColor('hot', t) : t.dim)
          .child(g.status),
      )
      if (folded) return this.kept(v_flex().gap(8).child(head), g, t)
      return v_flex().gap(8).child(head).children(this.groupBody(g, t))
    }
    // Failing: the reason where the window's name goes, the last reading dimmed. Stale: dimmed.
    const numbers = g.dim ? 0.55 : 1
    const tail = h_flex()
      .gap(8)
      .items_center()
      .flex_none()
      .when(!g.failed, (e) =>
        e.child(
          div()
            .opacity(numbers)
            .child(usageBar(FOLDED_BAR_W, s.fill, s.tick, levelColor(s.level, t), t)),
        ),
      )
      .child(
        div()
          .w(PCT_W)
          .flex_none()
          .flex()
          .justify_end()
          .whitespace_nowrap()
          .opacity(numbers)
          .text_color(limitColor(s.level, s.percent, t))
          .child(s.percent),
      )
      .child(
        div()
          .w(LEFT_W)
          .flex_none()
          .flex()
          .justify_end()
          .whitespace_nowrap()
          .opacity(numbers)
          .text_size(11)
          .text_color(t.dim)
          .child(s.left),
      )
    return this.kept(
      v_flex()
        .gap(8)
        .child(
          head.child(g.failed ? this.failure(g.status, t) : this.rightLabel(s.long, t)).child(tail),
        ),
      g,
      t,
    )
  }

  // What an open group shows under its header: its age line, if any, and its rows.
  groupBody(g, t, ghost = false) {
    const body = []
    if (g.age != null) body.push(div().text_size(11).text_color(t.dim).child(g.age))
    body.push(
      v_flex()
        .gap(6)
        .opacity(g.dim ? 0.55 : 1)
        .children(g.rows.map((r) => this.cardRow(r, g.providerId, t, ghost))),
    )
    return body
  }

  // A group folded by a click since the panel opened keeps, under its line, the space its
  // rows took, drawn invisible (layout kept, nothing painted), so the card, which grows up
  // from the bar, doesn't slide out from under the pointer. Dropped when the pointer leaves
  // the panel or the panel opens again.
  kept(group, g, t) {
    if (!this.foldedHere.has(g.providerId)) return group
    return group.child(
      v_flex()
        .gap(8)
        .invisible()
        .children(this.groupBody(g, t, true)),
    )
  }

  // A one-line group's failure: its reason, flagged, where the flexible gap starts.
  failure(text, t) {
    return div()
      .flex_1()
      .min_w(0)
      .truncate()
      .text_size(11)
      .text_color(levelColor('hot', t))
      .child(`! ${text}`)
  }

  // The flexible gap with a dim label at its right end.
  rightLabel(text, t) {
    return div()
      .flex_1()
      .min_w(0)
      .flex()
      .justify_end()
      .child(div().min_w(0).truncate().text_size(11).text_color(t.dim).child(text))
  }

  // A provider that only counts tokens: one line on the columns of a limit row.
  spendLine(g, t) {
    const numbers = g.failed ? 0.55 : 1
    return h_flex()
      .gap(6)
      .items_center()
      .opacity(g.dim && !g.failed ? 0.55 : 1)
      .child(providerIcon(g.providerId, g.icon, t.foreground))
      .child(div().flex_none().font_semibold().child(g.name))
      .child(g.failed ? this.failure(g.status, t) : this.rightLabel('Tokens today / 7d', t))
      .child(
        h_flex()
          .gap(8)
          .items_center()
          .flex_none()
          .child(
            div()
              .w(PCT_W)
              .flex_none()
              .flex()
              .justify_end()
              .whitespace_nowrap()
              .opacity(numbers)
              .text_color(g.today == null ? t.dim : t.foreground)
              .child(g.today ?? '—'),
          )
          .child(
            div()
              .w(LEFT_W)
              .flex_none()
              .flex()
              .justify_end()
              .whitespace_nowrap()
              .opacity(numbers)
              .text_color(g.week == null ? t.dim : t.muted)
              .child(g.week ?? '—'),
          ),
      )
  }

  sessionBlock(v, t) {
    const stats = [v.who, v.context.detail, v.calls, v.compactions, v.last]
      .filter(Boolean)
      .join(' · ')
    return v_flex()
      .gap(4)
      .child(
        h_flex()
          .gap(6)
          .items_center()
          .child(div().flex_none().font_semibold().child('This session'))
          .child(div().flex_1().min_w(0).truncate().text_color(t.dim).child(v.title))
          .when(v.context.fill != null, (r) =>
            r.child(
              usageBar(SESSION_BAR_W, v.context.fill, null, levelColor(v.context.level, t), t),
            ),
          )
          .child(
            div()
              .flex_none()
              .whitespace_nowrap()
              .text_color(textColor(v.context.level, v.context.text, t))
              .child(`ctx ${v.context.text}`),
          ),
      )
      .child(div().text_size(11).text_color(t.dim).child(stats))
  }

  sessionPicker(t) {
    return v_flex()
      .gap(5)
      .child(div().font_semibold().child('This session'))
      .child(
        div()
          .id('ul-pick-session')
          .text_size(11)
          .text_color(t.dim)
          .cursor_pointer()
          .on_click((_e, cx) => {
            this.sessionChoosing = !this.sessionChoosing
            cx.notify()
          })
          .child(this.sessionChoosing ? 'Cancel' : 'Choose Codex session…'),
      )
      .when(this.sessionChoosing, (el) =>
        el.children(
          this.sessionChoices.choices.map((row) =>
            div()
              .id(`ul-session-${row.id}`)
              .py(4)
              .px(6)
              .rounded(4)
              .cursor_pointer()
              .hover((s) => s.bg(t.hover))
              .on_click((_e, cx) => this.chooseSession(row, cx))
              .child(
                div()
                  .truncate()
                  .child(row.title || row.id),
              ),
          ),
        ),
      )
  }

  iconButton(id, icon, label, enabled, onClick, t) {
    return div()
      .id(id)
      .size(24)
      .rounded(5)
      .flex()
      .items_center()
      .justify_center()
      .tooltip(label)
      .when(enabled, (e) =>
        e
          .cursor_pointer()
          .hover((s) => s.bg(t.hover))
          .on_click((_e, cx) => onClick(cx)),
      )
      .child(
        svg(`mods/${MOD}/icons/${icon}.svg`)
          .size(14)
          .text_color(enabled ? t.muted : t.dim),
      )
  }

  shell(t) {
    return v_flex()
      .id('ul-panel-body')
      .w(PANEL_W)
      .p(12)
      .gap(10)
      .rounded(8)
      .border(1)
      .border_color(t.border)
      .bg(t.popover)
      .shadow_lg()
      .text_size(12)
      .text_color(t.foreground)
      .on_hover((on, cx) => {
        // Leaving the panel leaves every header in it, whether or not a header said so.
        if (!on && this.hovered != null) {
          this.hovered = null
          cx.notify()
        }
        if (!on && this.foldedHere.size) {
          this.foldedHere.clear()
          cx.notify()
        } // the kept space goes
        this.hover(on, cx)
      })
  }

  // session: the session block's view, or null when there's none or it's out of the panel.
  limits(model, session, t) {
    const rule = () => div().h(1).bg(t.border).flex_none()
    const body = this.shell(t)
    if (session) body.child(this.sessionBlock(session, t)).child(rule())
    if (inPanel(this.prefs(), 'session') && this.sessionManual)
      body.child(
        div()
          .id('ul-change-session')
          .text_size(11)
          .text_color(t.dim)
          .cursor_pointer()
          .on_click((_e, cx) => this.changeSession(cx))
          .child('Change Codex session'),
      )
    if (inPanel(this.prefs(), 'session') && this.sessionChoices)
      body.child(this.sessionPicker(t)).child(rule())
    model.groups.forEach((g, i) => {
      if (i > 0) body.child(rule())
      body.child(g.kind === 'spend' ? this.spendLine(g, t) : this.cardGroup(g, model.arrows, t))
    })
    const nearest = nearestQuotaReset(states(), PROVIDERS, now())
    if (nearest)
      body.child(
        div()
          .text_size(11)
          .text_color(t.dim)
          .tooltip(new Date(nearest.at * 1000).toLocaleString())
          .child(
            `最近重置：${nearest.provider} ${nearest.window} · ${timeLeft(nearest.at - now())}`,
          ),
      )
    const cooling = this.cooling()
    return body.child(rule()).child(
      h_flex()
        .gap(2)
        .justify_end()
        .items_center()
        .child(
          this.resetPanel.button(
            'ul-resets',
            '額度重置',
            true,
            (cx) => {
              this.resetPanel.load(cx, states())
              this.show('resets', cx)
            },
            t,
          ),
        )
        .child(
          this.iconButton(
            'ul-refresh',
            'refresh',
            cooling ? 'Refreshing…' : 'Refresh now',
            !cooling,
            (cx) => this.refresh(cx),
            t,
          ),
        )
        .child(
          this.iconButton(
            'ul-settings',
            'gear',
            'Settings',
            true,
            (cx) => this.show('settings', cx),
            t,
          ),
        ),
    )
  }

  // ---------- panel: settings ----------

  checkBox(on, t) {
    return div()
      .size(13)
      .rounded(3)
      .border(1)
      .border_color(on ? t.accent : t.input)
      .bg(on ? t.accent : t.popover)
      .flex()
      .items_center()
      .justify_center()
      .text_size(9)
      .text_color(t.accent_foreground)
      .child(on ? '✓' : '')
  }

  // A row with a box: a click anywhere on it toggles the box. panel: { on, onToggle } adds a
  // second box at the right end, under "Panel". The bar part and the panel box are then
  // siblings, neither inside the other, so a click reaches exactly one of the two handlers.
  // Both stretch to the row's height and carry its vertical padding, so all of it answers.
  check(id, on, label, onToggle, t, indent = 0, extra = null, panel = null) {
    if (panel == null) {
      return h_flex()
        .id(id)
        .gap(8)
        .items_center()
        .pl(indent)
        .py(3)
        .rounded(4)
        .cursor_pointer()
        .hover((s) => s.bg(t.hover))
        .on_click((_e, cx) => {
          onToggle()
          cx.notify()
        })
        .child(this.checkBox(on, t))
        .children(label)
        .when(extra != null, (e) => e.child(div().text_color(t.dim).truncate().child(extra)))
    }
    return h_flex()
      .id(id)
      .items_stretch()
      .pl(indent)
      .rounded(4)
      .hover((s) => s.bg(t.hover))
      .child(
        h_flex()
          .id(`${id}-bar`)
          .flex_1()
          .min_w(0)
          .gap(8)
          .items_center()
          .py(3)
          .cursor_pointer()
          .on_click((_e, cx) => {
            onToggle()
            cx.notify()
          })
          .child(this.checkBox(on, t))
          .children(label)
          .when(extra != null, (e) => e.child(div().text_color(t.dim).truncate().child(extra))),
      )
      .child(this.panelBox(`${id}-panel`, panel.on, panel.onToggle, t, true))
  }

  // The right-hand box: whether this shows in the panel. Its whole slot is the target.
  // inRow: the slot is a row's right part, centred, with the row's vertical padding.
  panelBox(id, on, onToggle, t, inRow = false) {
    return div()
      .id(id)
      .w(PANEL_BOX_W)
      .flex_none()
      .flex()
      .justify_end()
      .when(inRow, (e) => e.items_center().py(3))
      .cursor_pointer()
      .on_click((_e, cx) => {
        onToggle()
        cx.notify()
      })
      .child(this.checkBox(on, t))
  }

  settings(canGoBack, t) {
    const prefs = this.prefs()
    const st = states()
    const save = (p) => setShared(KEY_PREFS, p)
    const inThePanel = (id) => ({
      on: inPanel(prefs, id),
      onToggle: () => save(togglePanel(this.prefs(), id)),
    })
    // A spend provider's bar box: its explicit choice, else on only when no limits provider answers with limits.
    const spendBar = (pr, s, id) =>
      spendOnBar(pr, id, limitsSettled(s, pr, PROVIDERS) && !hasLimits(s, PROVIDERS))
    const rows = []
    for (const p of PROVIDERS) {
      const s = st[p.id] ?? {}
      const shownReading = s.report?.status === 'ok' ? s.report : s.lastGood
      if (p.kind === 'spend') {
        const missing = s.installed === false
        const idle = !missing && shownReading?.spend?.week === 0
        const reason = missing
          ? 'not installed'
          : idle
            ? 'no use in 7 days'
            : s.report && s.report.status !== 'ok'
              ? s.report.message
              : null
        rows.push(
          this.check(
            `p-${p.id}`,
            spendBar(prefs, st, p.id),
            [
              providerIcon(p.id, p.icon, missing || idle ? t.dim : t.foreground),
              div()
                .text_color(missing || idle ? t.dim : t.foreground)
                .child(p.name),
            ],
            () => {
              const fresh = this.prefs()
              save(toggleSpendOnBar(fresh, p.id, spendBar(fresh, states(), p.id)))
            },
            t,
            0,
            reason,
            inThePanel(p.id),
          ),
        )
        continue
      }
      const on = isShown(prefs, p.id)
      const reason =
        s.installed === false
          ? 'not installed'
          : s.report && s.report.status !== 'ok'
            ? s.report.message
            : null
      rows.push(
        this.check(
          `p-${p.id}`,
          on,
          [
            providerIcon(p.id, p.icon, s.installed === false ? t.dim : t.foreground),
            div()
              .text_color(s.installed === false ? t.dim : t.foreground)
              .child(p.name),
          ],
          () => save(toggleProvider(this.prefs(), p.id)),
          t,
          0,
          reason,
          inThePanel(p.id),
        ),
      )
      const windows = shownReading?.windows ?? []
      for (const w of windows) {
        rows.push(
          this.check(
            `w-${p.id}-${w.id}`,
            on && isShown(prefs, p.id, w.id),
            [
              div()
                .text_color(on ? t.muted : t.dim)
                .child(w.long),
            ],
            () => save(toggleWindow(this.prefs(), p.id, w.id)),
            t,
            21,
          ),
        )
      }
    }
    const session = inThePanel('session')
    return this.shell(t)
      .child(
        h_flex()
          .gap(6)
          .items_center()
          .h(24)
          .when(canGoBack, (e) =>
            e.child(
              this.iconButton(
                'ul-back',
                'back',
                'Back to limits',
                true,
                (cx) => this.show('limits', cx),
                t,
              ),
            ),
          )
          .child(div().font_semibold().child('Settings')),
      )
      .child(
        h_flex()
          .items_center()
          .text_size(11)
          .text_color(t.dim)
          .child(div().child('Bar'))
          .child(div().flex_1())
          .child(div().child('Panel')),
      )
      .child(v_flex().gap(1).children(rows))
      .child(div().h(1).bg(t.border).flex_none())
      .child(
        this.check(
          'opt-reset-time',
          prefs.showResetTime,
          [div().text_color(t.foreground).child('Always show time to reset')],
          () => save(toggleShowResetTime(this.prefs())),
          t,
        ),
      )
      .child(
        this.check(
          'opt-bars',
          prefs.showBars,
          [div().text_color(t.foreground).child('Show bars')],
          () => save(toggleShowBars(this.prefs())),
          t,
        ),
      )
      .child(div().h(1).bg(t.border).flex_none())
      .child(
        v_flex()
          .gap(1)
          .child(
            h_flex()
              .items_center()
              .pb(3)
              .child(div().flex_1().font_semibold().child('This session'))
              .child(this.panelBox('panel-session', session.on, session.onToggle, t)),
          )
          .children(
            ['Context', 'Calls', 'Compactions'].map((name) => {
              const row = name.toLowerCase()
              return this.check(
                `s-${row}`,
                isOnBar(prefs, row),
                [div().text_color(t.foreground).child(name)],
                () => save(toggleOnBar(this.prefs(), row)),
                t,
              )
            }),
          ),
      )
      .child(
        div()
          .text_size(10.5)
          .text_color(t.dim)
          .child('Account quotas from native CLIs and existing connected-machine integrations.'),
      )
  }

  render(cx) {
    if (props()?.view === 'reset-manager') return this.resetPanel.render(this, theme())
    const focus = focused()
    const terminal = focus?.terminal ?? focus?.agent ?? null
    const prefs = this.prefs()
    const sessionWanted = this.sessionWanted(prefs)
    if (terminal !== this.terminal) {
      this.terminal = terminal
      this.session = null
      this.sessionChoices = null
      this.sessionChoosing = false
      this.sessionManual = false
      this.readSession(cx)
    } else if (sessionWanted && !this.sessionWas) {
      this.readSession(cx) // just put back in the panel or on the bar: read at once
    }
    this.sessionWas = sessionWanted
    // A provider just put back on the bar or in the panel is fetched at once.
    const st = states()
    const want = PROVIDERS.filter((p) => wanted(prefs, p, st, PROVIDERS))
    for (const p of want) if (this.unwanted[p.id]) this.fetch(p, cx)
    this.unwanted = Object.fromEntries(
      PROVIDERS.filter((p) => !want.includes(p)).map((p) => [p.id, true]),
    )
    const asked = shared(KEY_REFRESH) ?? 0
    if (asked !== this.seenRefresh) {
      this.seenRefresh = asked
      for (const p of want) this.fetch(p, cx)
    }
    return this.renderBar(cx)
  }
}
