// Read ZCode's cached Coding Plan key using its current or legacy storage format.
// No login, key creation, refresh, migration or credential writes.
const crypto = require('node:crypto')
const fs = require('node:fs/promises')
const { createRequire } = require('node:module')
const os = require('node:os')
const path = require('node:path')

const digest = (value) => crypto.createHash('sha256').update(value).digest()

function openCredential(ivText, tagText, dataText, key) {
  const iv = Buffer.from(ivText, 'base64url')
  const tag = Buffer.from(tagText, 'base64url')
  if (iv.length !== 12 || tag.length !== 16) throw new Error('invalid_credential')
  const cipher = crypto.createDecipheriv('aes-256-gcm', key, iv)
  cipher.setAuthTag(tag)
  return Buffer.concat([cipher.update(Buffer.from(dataText, 'base64url')), cipher.final()])
    .toString('utf8')
    .trim()
}

function decryptLegacyCodingPlanKey(value, root) {
  const match = /^enc:v1:([A-Za-z0-9_-]+)\.([A-Za-z0-9_-]+)\.([A-Za-z0-9_-]+)$/.exec(value)
  if (!match) throw new Error('invalid_credential')
  // Match ZCode's built-in legacy fallback for this user's existing cache.
  const key = digest(`zcode-credential-fallback:${os.platform()}:${root}:${os.userInfo().username}`)
  return openCredential(match[1], match[2], match[3], key)
}

async function nativeKeyStore(root, credentialPath) {
  const nativeRequire = createRequire(path.join(root, '.zcode/runtime/current/agent/zcode.cjs'))
  const { AsyncEntry } = nativeRequire('@napi-rs/keyring')
  return new AsyncEntry(
    'ZCode Credential Encryption',
    digest(path.resolve(credentialPath)).toString('hex'),
    {
      linux: { store: 'secret-service' },
    },
  )
}

async function decryptCredential(value, root, credentialPath, keyStoreFactory = nativeKeyStore) {
  if (!value.startsWith('enc:')) return value.trim()
  const match =
    /^enc:v2:os:([a-f0-9]{24}):([A-Za-z0-9_-]+)\.([A-Za-z0-9_-]+)\.([A-Za-z0-9_-]+)$/.exec(value)
  if (!match) throw new Error('unsupported_credential_storage')
  const entry = await keyStoreFactory(root, credentialPath)
  const encoded = await entry.getPassword()
  if (typeof encoded !== 'string') throw new Error('credential_unavailable')
  const key = Buffer.from(encoded, 'base64url')
  if (key.length !== 32 || digest(key).toString('hex').slice(0, 24) !== match[1]) {
    throw new Error('credential_unavailable')
  }
  return openCredential(match[2], match[3], match[4], key)
}

function sanitizeQuota(data) {
  const limits = []
  for (const value of data.data?.limits ?? []) {
    if (!['TOKENS_LIMIT', 'CREDIT_LIMIT'].includes(value.type)) continue
    limits.push({
      type: value.type,
      unit: value.unit,
      number: value.number,
      percentage: value.percentage,
      nextResetTime: value.nextResetTime,
    })
  }
  let level = null
  if (typeof data.data?.level === 'string') level = data.data.level
  return { code: data.code, success: data.success, data: { level, limits } }
}

async function getUsage(root = os.homedir(), options = {}) {
  const credentialPath = path.join(root, '.zcode/v2/credentials.json')
  let token
  try {
    const config = JSON.parse(
      await fs.readFile(path.join(root, '.zcode/v2/provider_config.json'), 'utf8'),
    )
    const provider = config.config?.defaultModelSelection?.providerId
    if (!provider) return { state: 'missing' }
    if (!provider.startsWith('account:zai-')) return { state: 'unsupported_provider' }
    const credentials = JSON.parse(await fs.readFile(credentialPath, 'utf8'))
    const prefix = `account-provider:coding-plan:${provider}:`
    const keys = Object.entries(credentials).filter(
      ([key, value]) =>
        key.startsWith(prefix) && key.endsWith(':api-key') && typeof value === 'string' && value,
    )
    if (!keys.length) return { state: 'quota_credential_unavailable' }
    if (keys.length !== 1) return { state: 'ambiguous_account' }
    const storedKey = keys[0][1]
    if (storedKey.startsWith('enc:v1:')) {
      token = decryptLegacyCodingPlanKey(storedKey, root)
    } else {
      token = await decryptCredential(storedKey, root, credentialPath, options.keyStoreFactory)
    }
    if (!token || token.startsWith('enc:')) return { state: 'quota_credential_unavailable' }
  } catch {
    return { state: 'quota_credential_unavailable' }
  }
  try {
    const fetchQuota = options.fetch ?? fetch
    const response = await fetchQuota('https://api.z.ai/api/monitor/usage/quota/limit', {
      headers: { Authorization: token, Accept: 'application/json' },
      redirect: 'error',
      signal: AbortSignal.timeout(8000),
    })
    if ([401, 403].includes(response.status)) {
      return { state: 'quota_auth_failed', httpStatus: response.status }
    }
    if (!response.ok) return { state: 'unavailable', httpStatus: response.status }
    let size = 0
    const chunks = []
    for await (const chunk of response.body) {
      size += chunk.byteLength
      if (size > 1024 * 1024) throw new Error('oversized_response')
      chunks.push(Buffer.from(chunk))
    }
    const data = JSON.parse(Buffer.concat(chunks).toString('utf8'))
    return sanitizeQuota(data)
  } catch {
    return { state: 'unavailable' }
  }
}

async function resetAccount(root, options) {
  const override = process.env.ZCODE_ENDPOINT_ORIGIN || process.env.ZCODE_BASE_URL
  if (
    process.env.ZCODE_ENV === 'test' ||
    (override && new URL(override).origin !== 'https://zcode.z.ai')
  ) {
    throw new Error('unsupported_endpoint')
  }
  const file = path.join(root, '.zcode/v2/credentials.json')
  const configFile = path.join(root, '.zcode/v2/provider_config.json')
  const [snapshot, configText] = await Promise.all([
    fs.readFile(file, 'utf8'),
    fs.readFile(configFile, 'utf8'),
  ])
  const provider = JSON.parse(configText).config?.defaultModelSelection?.providerId
  if (provider !== 'account:zai-individual-coding-plan') throw new Error('unsupported_account')
  const values = JSON.parse(snapshot)
  const login = await decryptCredential(values.zcodejwttoken, root, file, options.keyStoreFactory)
  const business = await decryptCredential(
    values['oauth:zai:access_token'],
    root,
    file,
    options.keyStoreFactory,
  )
  if (
    (await fs.readFile(file, 'utf8')) !== snapshot ||
    (await fs.readFile(configFile, 'utf8')) !== configText
  ) {
    throw new Error('account_changed')
  }
  return {
    accountKey: digest(snapshot + configText).toString('hex'),
    headers: {
      Authorization: /^Bearer /i.test(login) ? login : `Bearer ${login}`,
      'X-Bigmodel-Authorization': business,
      'Bigmodel-Target-Type': 'PERSONAL',
      Accept: 'application/json',
    },
  }
}

async function resetApi(account, endpoint, body, options) {
  const init = {
    headers: { ...account.headers },
    redirect: 'error',
    signal: AbortSignal.timeout(8000),
  }
  if (body) {
    init.method = 'POST'
    init.headers['Content-Type'] = 'application/json'
    init.body = JSON.stringify(body)
  }
  const response = await (options.fetch ?? fetch)(
    `https://zcode.z.ai/api/v1/coding-plan/reset/${endpoint}`,
    init,
  )
  if (!response.ok) throw new Error('reset_request_failed')
  const reply = await response.json()
  if (![0, 200, '0', '200'].includes(reply.code)) throw new Error('reset_request_failed')
  return reply.data
}

function resetExpiry(value) {
  if (typeof value !== 'number' || !Number.isFinite(value)) return null
  return value > 100000000000 ? value / 1000 : value
}

async function getResetStatus(root = os.homedir(), options = {}) {
  try {
    const account = await resetAccount(root, options)
    const data = await resetApi(account, 'status', null, options)
    const read = (items) =>
      (items ?? [])
        .map((item) => resetExpiry(item.expire_at))
        .filter((expiry) => expiry && expiry > Date.now() / 1000)
        .sort((a, b) => a - b)
    return {
      state: 'ready',
      accountKey: account.accountKey,
      fiveHour: read(data.available_five_hour_resets),
      weekly: read(data.available_week_resets),
    }
  } catch {
    return { state: 'error', code: 'request_failed' }
  }
}

async function useReset(payload, root = os.homedir(), options = {}) {
  try {
    if (
      !['FIVE_HOUR', 'WEEK'].includes(payload.resetType) ||
      typeof payload.idempotencyKey !== 'string' ||
      payload.idempotencyKey.length < 8 ||
      payload.idempotencyKey.length > 64
    )
      return { state: 'error', code: 'invalid_request' }
    const account = await resetAccount(root, options)
    if (account.accountKey !== payload.accountKey)
      return { state: 'error', code: 'account_changed' }
    if (payload.retry !== true) {
      const status = await resetApi(account, 'status', null, options)
      const cards =
        payload.resetType === 'WEEK'
          ? status.available_week_resets
          : status.available_five_hour_resets
      if (!(cards ?? []).some((card) => (resetExpiry(card.expire_at) ?? 0) > Date.now() / 1000)) {
        return { state: 'error', code: 'credit_unavailable' }
      }
    }
    const latest = await resetAccount(root, options)
    if (latest.accountKey !== payload.accountKey) return { state: 'error', code: 'account_changed' }
    const data = await resetApi(
      latest,
      'use',
      { reset_type: payload.resetType, idempotency_key: payload.idempotencyKey },
      options,
    )
    if (data.used !== true) return { state: 'error', code: 'unknown_result' }
    return { state: 'complete', outcome: 'reset' }
  } catch {
    return { state: 'error', code: 'request_failed' }
  }
}

module.exports = { getUsage, decryptCredential, sanitizeQuota, getResetStatus, useReset }
const argMode = require.main === module ? process.argv[2] : process.argv[1]
const payloadIndex = require.main === module ? 3 : 2
if (require.main === module || ['--run-usage', '--reset-status', '--reset-use'].includes(argMode)) {
  let task
  if (argMode === '--reset-status') task = getResetStatus()
  else if (argMode === '--reset-use') {
    try {
      task = useReset(JSON.parse(process.argv[payloadIndex] ?? '{}'))
    } catch {
      task = Promise.resolve({ state: 'error', code: 'invalid_request' })
    }
  } else task = getUsage()
  task
    .then((result) => process.stdout.write(JSON.stringify(result) + '\n'))
    .catch(() => process.stdout.write('{"state":"error","code":"request_failed"}\n'))
}
