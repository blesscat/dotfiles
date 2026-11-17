import { div } from 'gpui-kit'
import { h_flex, v_flex } from 'gpui-base'
import { exec, shared, setShared } from 'herdr'
import {
  RESET_INFO,
  resetChoices,
  attemptKey,
  prepareAttempt,
  resetMessage,
  earliestCoupon,
} from './reset.js'
import { timeLeft } from './format.js'
import { resetRequest } from './reset-source.js'

const PENDING_KEY = 'usage-limits.reset-attempts'
const nonce = () =>
  `${Date.now().toString(36)}-${Math.random().toString(36).slice(2)}-${Math.random().toString(36).slice(2)}`

export class ResetPanel {
  constructor() {
    this.status = {}
    this.loading = false
    this.submitting = false
    this.choice = null
    this.message = null
    this.machine = null
  }

  load(cx, states, review = null) {
    if (this.loading || this.submitting) return
    this.loading = true
    this.machine = states.zcode?.report?.machine ?? states.zcode?.lastGood?.machine ?? null
    const machine = this.machine
    cx.spawn(async (cx) => {
      const zcode = machine
        ? resetRequest('zcode', 'status', {}, machine)
        : Promise.resolve({ state: 'error', code: 'source_pending' })
      const replies = await Promise.all([resetRequest('codex', 'status'), zcode])
      this.status = { codex: replies[0], zcode: replies[1] }
      this.loading = false
      if (review) {
        const choices = resetChoices(
          review.provider,
          this.status[review.provider],
          review.provider === 'zcode' ? machine : 'local',
        )
        const choice = choices.find((item) => item.type === review.type)
        if (choice) this.choose(choice, cx)
      }
      cx.notify()
    })
  }

  choose(choice, cx) {
    if (this.submitting) return
    const saved = shared(PENDING_KEY) ?? {}
    this.attempt = prepareAttempt(choice, saved[attemptKey(choice)], nonce())
    this.choice = this.attempt.choice
    this.message = null
    cx.notify()
  }

  confirm(owner, cx) {
    if (this.submitting || !this.choice) return
    const attempt = this.attempt
    const choice = attempt.choice
    const key = attemptKey(choice)
    // Persist before sending. A timeout or UI restart reuses this idempotency key.
    setShared(PENDING_KEY, { ...(shared(PENDING_KEY) ?? {}), [key]: attempt })
    this.submitting = true
    cx.spawn(async (cx) => {
      const result = await resetRequest(choice.provider, 'consume', attempt.request, choice.machine)
      this.submitting = false
      this.message = resetMessage(result)
      if (result.state === 'complete') {
        const pending = { ...(shared(PENDING_KEY) ?? {}) }
        delete pending[key]
        setShared(PENDING_KEY, pending)
        this.choice = null
        owner.extraSource.startedAt = 0
        owner.tick(cx, true)
        this.load(cx, owner.currentStates())
      } else {
        this.attempt = { ...attempt, request: { ...attempt.request, retry: true } }
      }
      cx.notify()
    })
    cx.notify()
  }

  button(id, label, enabled, action, t) {
    return div()
      .id(id)
      .px(9)
      .py(5)
      .rounded(5)
      .border(1)
      .border_color(t.border)
      .text_size(11)
      .text_color(enabled ? t.accent : t.dim)
      .child(label)
      .on_mouse_down('left', (_e, cx) => cx.stop_propagation())
      .when(enabled, (el) =>
        el
          .cursor_pointer()
          .hover((el) => el.bg(t.hover))
          .on_click((_e, cx) => action(cx)),
      )
  }

  render(owner, t) {
    const body = owner.shell(t)
    const header = h_flex()
      .gap(8)
      .items_center()
      .child(
        this.button(
          'reset-back',
          '←',
          !this.submitting,
          (cx) => {
            this.choice = null
            this.message = null
            owner.show('limits', cx)
          },
          t,
        ),
      )
      .child(
        div()
          .font_semibold()
          .child(this.choice ? '確認額度重置' : '額度重置'),
      )
    body.child(header)
    if (this.message) body.child(div().text_size(11).text_color(t.muted).child(this.message))
    if (this.choice) {
      const choice = this.choice
      body
        .child(
          div()
            .font_semibold()
            .child(choice.title || choice.label),
        )
        .child(
          div()
            .text_size(11)
            .text_color(t.muted)
            .child(
              `來源：${choice.machine && choice.machine !== 'local' ? choice.machine : '本機'}`,
            ),
        )
        .child(div().text_size(12).child('本次會消耗 1 張現有重置券，使用後無法撤回。'))
      if (choice.description)
        body.child(div().text_size(11).text_color(t.muted).child(choice.description))
      if (choice.expiresAt)
        body.child(
          div()
            .text_size(11)
            .text_color(t.dim)
            .child(
              `${choice.provider === 'zcode' ? '此類券最早到期' : '本張券到期'}：${new Date(choice.expiresAt * 1000).toLocaleString()}`,
            ),
        )
      return body.child(
        h_flex()
          .gap(8)
          .justify_end()
          .child(
            this.button(
              'reset-cancel',
              '返回',
              !this.submitting,
              (cx) => {
                this.choice = null
                cx.notify()
              },
              t,
            ),
          )
          .child(
            this.button(
              'reset-confirm',
              this.submitting ? '處理中…' : '確認使用 1 張券',
              !this.submitting,
              (cx) => this.confirm(owner, cx),
              t,
            ),
          ),
      )
    }
    body.child(div().text_size(11).text_color(t.dim).child('各服務依自己的帳戶資格與重置券處理。'))
    const now = Date.now() / 1000
    const first = earliestCoupon(this.status, now)
    if (first) {
      body.child(
        v_flex()
          .p(9)
          .gap(4)
          .rounded(6)
          .bg(t.raised)
          .child(
            div().text_color(t.accent).child(`已查詢券最早到期：${first.provider} ${first.window}`),
          )
          .child(
            div()
              .text_size(11)
              .text_color(t.muted)
              .child(
                `剩 ${timeLeft(first.at - now)} · ${new Date(first.at * 1000).toLocaleString()}`,
              ),
          ),
      )
    }
    for (const info of RESET_INFO) {
      const status = this.status[info.id]
      let summary = info.detail
      if (info.id === 'codex' && status?.state === 'ready')
        summary = `可用重置券：${status.availableCount} 張`
      if (info.id === 'zcode' && status?.state === 'ready')
        summary = `5h：${status.fiveHour.length} 張 · wk：${status.weekly.length} 張`
      if (['codex', 'zcode'].includes(info.id) && !status)
        summary = this.loading ? '讀取重置券…' : '等待讀取重置券'
      if (status?.state === 'error') summary = '暫時無法讀取重置券，可查看官方操作方式。'
      const section = v_flex()
        .gap(5)
        .pt(8)
        .border_t(1)
        .border_color(t.border)
        .child(div().font_semibold().child(info.name))
        .child(div().text_size(11).text_color(t.muted).child(summary))
      const actions = h_flex().gap(6).items_center()
      const expiry = earliestCoupon({ [info.id]: status }, now)
      if (expiry) {
        section.child(
          div()
            .text_size(11)
            .text_color(t.dim)
            .child(
              `最早到期：${new Date(expiry.at * 1000).toLocaleString()}（剩 ${timeLeft(expiry.at - now)}）`,
            ),
        )
      }
      for (const choice of resetChoices(
        info.id,
        status,
        info.id === 'zcode' ? this.machine : 'local',
      )) {
        actions.child(
          this.button(
            `reset-${info.id}-${choice.type}`,
            choice.label,
            !this.loading,
            (cx) => this.choose(choice, cx),
            t,
          ),
        )
      }
      actions.child(
        this.button(
          `reset-link-${info.id}`,
          info.link,
          true,
          (cx) => {
            cx.spawn(async () => {
              await exec('open', [info.url]).catch(() => null)
            })
          },
          t,
        ),
      )
      body.child(section.child(actions))
    }
    return body.child(
      h_flex()
        .justify_end()
        .child(
          this.button(
            'reset-reload',
            this.loading ? '讀取中…' : '重新讀取重置券',
            !this.loading,
            (cx) => this.load(cx, owner.currentStates()),
            t,
          ),
        ),
    )
  }
}
