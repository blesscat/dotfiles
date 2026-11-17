// Reset capabilities and confirmation requests. No host APIs or credentials.
export const RESET_INFO = [
  {
    id: 'codex',
    name: 'Codex',
    detail: '使用帳戶現有的重置券，恢復券所涵蓋的主要額度。',
    url: 'https://help.openai.com/en/articles/20001498-how-resets-work-in-codex',
    link: '官方重置說明',
  },
  {
    id: 'claude',
    name: 'Claude',
    detail: '符合資格的重置券須在 Claude 官方 Usage 頁確認使用。',
    url: 'https://claude.ai/settings/usage',
    link: '開啟官方重置頁',
  },
  {
    id: 'zcode',
    name: 'ZCode',
    detail: '分別使用 5h 或 wk 重置券；依官方規則使用最早取得的券。',
    url: 'https://zcode.z.ai/en/docs/usage-stats#quota-reset-cards',
    link: '官方重置說明',
  },
  {
    id: 'minimax',
    name: 'MiniMax',
    detail: '目前官方提供等待週期恢復、Credits 或升級，未確認可直接重置。',
    url: 'https://platform.minimax.io/console/usage',
    link: '管理額度',
  },
  {
    id: 'gemini',
    name: 'Gemini',
    detail: 'Antigravity 提供週期恢復與 AI credits，未確認可直接重置。',
    url: 'https://antigravity.google/docs/plans',
    link: '查看額度規則',
  },
]

export function resetChoices(provider, status, machine = null) {
  if (status?.state !== 'ready' || !status.accountKey) return []
  const common = { provider, accountKey: status.accountKey, machine }
  if (provider === 'codex') {
    const credit = status.credits?.[0]
    if (!credit) return []
    return [
      {
        ...common,
        type: 'codexRateLimits',
        creditId: credit.id,
        label: '重置 Codex',
        title: credit.title,
        description: credit.description,
        expiresAt: credit.expiresAt,
      },
    ]
  }
  if (provider !== 'zcode') return []
  const choices = []
  if (status.fiveHour?.length)
    choices.push({
      ...common,
      type: 'FIVE_HOUR',
      label: '重置 5h',
      title: 'ZCode 5 小時額度',
      expiresAt: status.fiveHour[0],
    })
  if (status.weekly?.length)
    choices.push({
      ...common,
      type: 'WEEK',
      label: '重置 wk',
      title: 'ZCode 週額度',
      expiresAt: status.weekly[0],
    })
  return choices
}

export function attemptKey(choice) {
  return `${choice.provider}:${choice.accountKey}:${choice.type}`
}

export function prepareAttempt(choice, existing, nonce) {
  if (existing?.request) return { ...existing, request: { ...existing.request, retry: true } }
  const request = {
    accountKey: choice.accountKey,
    resetType: choice.type,
    idempotencyKey: nonce,
    retry: false,
  }
  if (choice.creditId) request.creditId = choice.creditId
  return {
    choice,
    request,
  }
}

export function resetMessage(result) {
  if (result?.state === 'complete') {
    if (['reset', 'alreadyRedeemed'].includes(result.outcome)) return '重置已完成，正在更新用量。'
    if (result.outcome === 'nothingToReset') return '目前沒有符合重置條件的額度，未使用重置券。'
    if (result.outcome === 'noCredit') return '目前沒有可用的重置券。'
  }
  if (result?.code === 'account_changed') return '登入帳戶已變更，請重新讀取重置資訊。'
  if (result?.code === 'credit_unavailable') return '所選重置券已無法使用，請重新讀取。'
  return '尚未確認重置結果。再次確認會沿用同一次操作，避免重複兌換。'
}

export function earliestCoupon(statuses, now) {
  const candidates = []
  for (const credit of statuses.codex?.credits ?? []) {
    if (Number.isFinite(credit.expiresAt) && credit.expiresAt > now) {
      candidates.push({ provider: 'Codex', window: '重置券', at: credit.expiresAt })
    }
  }
  for (const [field, window] of [
    ['fiveHour', '5h 券'],
    ['weekly', 'wk 券'],
  ]) {
    for (const at of statuses.zcode?.[field] ?? []) {
      if (Number.isFinite(at) && at > now) candidates.push({ provider: 'ZCode', window, at })
    }
  }
  return candidates.sort((a, b) => a.at - b.at)[0] ?? null
}

export function nearestQuotaReset(states, providers, now) {
  const candidates = []
  for (const provider of providers) {
    const state = states[provider.id]
    const report = state?.report?.status === 'ok' ? state.report : state?.lastGood
    for (const window of report?.windows ?? []) {
      if (Number.isFinite(window.resetsAt) && window.resetsAt > now) {
        candidates.push({ provider: provider.name, window: window.short, at: window.resetsAt })
      }
    }
  }
  return candidates.sort((a, b) => a.at - b.at)[0] ?? null
}
