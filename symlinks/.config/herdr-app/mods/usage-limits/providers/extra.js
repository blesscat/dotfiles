// The three existing quota integrations, adapted to the author's Report format.
import { makeWindow, okReport, unavailableReport } from '../lib/report.js'

const MESSAGES = {
  waiting: '等待用量資料',
  missing: '尚無用量來源',
  login: '用量來源需授權',
  login_expired: '用量來源授權已過期',
  quota_auth_failed: '用量驗證失敗',
  quota_credential_unavailable: '用量憑證暫不可讀',
  ambiguous_account: '需選擇用量帳號',
  unsupported_provider: '此供應商無用量介面',
  no_quota: '未提供額度',
  unavailable: '暫無用量資料',
}

export function selectSample(samples, id) {
  const candidates = Object.entries(samples)
    .filter(([, sample]) => sample?.providers?.[id])
    .map(([machine, sample]) => ({ ...sample.providers[id], machine }))
  const available = candidates.filter((sample) => sample.state === 'ready')
  const local = available.find((sample) => sample.machine === 'local')
  if (local) return local
  if (available.length) {
    return available.sort((a, b) => (b.updatedAt ?? 0) - (a.updatedAt ?? 0))[0]
  }
  const configured = candidates.find((sample) => !['missing', 'waiting'].includes(sample.state))
  return configured ?? candidates.find((sample) => sample.machine !== 'local') ?? candidates[0]
}

function windowInfo(label) {
  if (label === '5h') return { short: '5h', long: '5-hour', durationSec: 5 * 3600 }
  if (label === '7d') return { short: 'wk', long: 'Weekly', durationSec: 7 * 86400 }
  if (label === '3P 5h')
    return { short: '3P 5h', long: 'Third-party · 5-hour', durationSec: 5 * 3600 }
  if (label === '3P 7d')
    return { short: '3P wk', long: 'Third-party · Weekly', durationSec: 7 * 86400 }
  return { short: label, long: label, durationSec: null }
}

export function sampleReport(sample, now) {
  const machine = sample?.machine === 'local' ? '本機' : sample?.machine
  const source = machine ? `帳戶用量 · ${machine}` : '帳戶用量'
  if (!sample || sample.state !== 'ready') {
    const message = MESSAGES[sample?.state] ?? MESSAGES.unavailable
    return unavailableReport(source, message, now)
  }
  const windows = []
  const unlimited = []
  for (const limit of sample.limits ?? []) {
    if (limit.unlimited) {
      unlimited.push(limit.label)
      continue
    }
    if (typeof limit.used !== 'number' || !Number.isFinite(limit.used)) continue
    windows.push(
      makeWindow({
        id: limit.label,
        ...windowInfo(limit.label),
        percent: Math.max(0, Math.min(100, limit.used)),
        resetsAt: limit.reset,
      }),
    )
  }
  if (!windows.length) {
    const message = unlimited.length ? `${unlimited.join(' / ')}：無上限` : MESSAGES.no_quota
    return unavailableReport(source, message, now)
  }
  let plan = sample.plan || null
  if (unlimited.length) plan = [plan, `${unlimited.join(' / ')} 無上限`].filter(Boolean).join(' · ')
  return {
    ...okReport(source, now, windows, plan, sample.updatedAt ?? now),
    machine: sample.machine,
  }
}

export const EXTRA_PROVIDERS = [
  { id: 'zcode', name: 'ZCode', icon: 'my-icons/zcode.png', extra: true },
  { id: 'minimax', name: 'MiniMax', icon: 'mods/usage-limits/icons/minimax.svg', extra: true },
  { id: 'gemini', name: 'Gemini', icon: 'mods/usage-limits/icons/gemini.svg', extra: true },
]
