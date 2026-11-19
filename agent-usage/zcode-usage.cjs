#!/usr/bin/env node
// Reads the Z.ai coding plan of the account ZCode is signed in with and prints one JSON line:
//   node zcode-usage.cjs          {"ok":true,"source":"zcode"|"opencode","payload":<quota API response>}
//   node zcode-usage.cjs resets   {"ok":true,"resets":null|{"week":[<expiry ms>...],"five_hour":[...]}}
//   node zcode-usage.cjs use WEEK|FIVE_HOUR <idempotency key>
//                                 uses one reset card: {"ok":true,"used":true}
//   on failure                    {"ok":false,"error":"<short reason, safe to show>"}
// Keys and tokens are decrypted in this process's memory only; they are never printed or written anywhere.
//
// ZCode keeps its secrets in ~/.zcode/v2/credentials.json as "enc:v2:os:<fingerprint>:<iv>.<tag>.<data>"
// (AES-256-GCM). The 32-byte key sits in the system keyring (Secret Service on Linux, Keychain on
// macOS) under the service "ZCode Credential Encryption", account sha256(<absolute path of credentials.json>).
//
// The quota is read with the plan's API key. If the keyring cannot be read (for example it is locked),
// the Z.ai key opencode saved is used instead.
// "resets" lists the unused Quota Reset Cards. Only ZCode's login can see them (the ZCode JWT plus the
// Z.ai OAuth access token, sent the way ZCode sends them). "resets" only reads the status.
// "use" spends one card, the same request ZCode's "reset" button sends; it cannot be undone. Retrying with
// the same idempotency key does not spend a second card.
// resets is null when ZCode is not signed in to a personal Z.ai plan.
'use strict';

const crypto = require('node:crypto');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const ZCODE_DIR = path.join(os.homedir(), '.zcode/v2');
const CREDENTIALS = path.join(ZCODE_DIR, 'credentials.json');
const KEYRING_MODULE = path.join(os.homedir(), '.zcode/runtime/current/agent/node_modules/@napi-rs/keyring');
const OPENCODE_AUTH = path.join(os.homedir(), '.local/share/opencode/auth.json');
const QUOTA_PATH = '/api/monitor/usage/quota/limit';
const RESET_API = 'https://zcode.z.ai/api/v1/coding-plan/reset';
const RESET_TYPES = ['WEEK', 'FIVE_HOUR'];
const IDEMPOTENCY_KEY = /^[A-Za-z0-9-]{8,64}$/;
const TIMEOUT_MS = 15000;
const USER_AGENT = 'agent-usage/1.0';

class Failure extends Error {}

function readJson(file) {
  try {
    return JSON.parse(fs.readFileSync(file, 'utf8'));
  } catch {
    throw new Failure(`讀不到 ${path.basename(file)}`);
  }
}

function sha256(value) {
  return crypto.createHash('sha256').update(value).digest();
}

let keyringKey;   // undefined: not read yet; null: the keyring could not be read

async function readKeyringKey() {
  if (keyringKey !== undefined) return keyringKey;
  let encoded;
  try {
    const { AsyncEntry } = require(KEYRING_MODULE);
    const entry = new AsyncEntry('ZCode Credential Encryption', sha256(path.resolve(CREDENTIALS)).toString('hex'),
      { linux: { store: 'secret-service' } });
    encoded = await entry.getPassword();
  } catch {
    encoded = undefined;
  }
  keyringKey = encoded ? Buffer.from(encoded, 'base64url') : null;
  return keyringKey;
}

// The plain text of one credentials.json value. Throws Failure('keyring') when the keyring cannot be read.
async function reveal(stored) {
  if (typeof stored !== 'string') return null;
  if (!stored.startsWith('enc:')) return stored;
  if (!stored.startsWith('enc:v2:os:')) throw new Failure('ZCode 的金鑰格式不支援');
  const [, fingerprint, payload] = stored.slice('enc:v2:'.length).split(':');
  const key = await readKeyringKey();
  if (!key || sha256(key).toString('hex').slice(0, 24) !== fingerprint) throw new Failure('keyring');
  const [iv, tag, data] = payload.split('.').map((part) => Buffer.from(part, 'base64url'));
  try {
    const decipher = crypto.createDecipheriv('aes-256-gcm', key, iv);
    decipher.setAuthTag(tag);
    return Buffer.concat([decipher.update(data), decipher.final()]).toString('utf8');
  } catch {
    throw new Failure('ZCode 的金鑰解不開');
  }
}

// The Z.ai plan ZCode uses, such as "zai-individual-coding-plan".
function zaiPlan() {
  const providerId = readJson(path.join(ZCODE_DIR, 'provider_config.json'))?.config?.defaultModelSelection?.providerId ?? '';
  if (!providerId.includes('zai-')) throw new Failure('ZCode 目前用的不是 Z.ai Coding Plan');
  return providerId.split(':').find((part) => part.includes('zai-'));
}

async function zcodeKey() {
  const plan = zaiPlan();
  const credentials = readJson(CREDENTIALS);
  const stored = Object.entries(credentials)
    .filter(([name, value]) => name.endsWith(':api-key') && name.includes(plan) && typeof value === 'string')
    .map(([, value]) => value)[0];
  if (!stored) throw new Failure('ZCode 裡沒有 Z.ai 的 API key，先在 ZCode 登入');
  return reveal(stored);
}

function opencodeKey() {
  let auth;
  try {
    auth = JSON.parse(fs.readFileSync(OPENCODE_AUTH, 'utf8'));
  } catch {
    return null;
  }
  for (const name of ['zai-coding-plan', 'zhipuai-coding-plan', 'zai', 'zhipuai']) {
    const key = auth?.[name]?.type === 'api' ? auth[name].key : null;
    if (typeof key === 'string' && key.trim()) return key.trim();
  }
  return null;
}

async function quota(base, key) {
  // The monitor API wants the key as the whole Authorization value; some deployments want "Bearer".
  let last = null;
  for (const authorization of [key, `Bearer ${key}`]) {
    let response;
    try {
      response = await fetch(base + QUOTA_PATH, {
        headers: { Authorization: authorization, Accept: 'application/json', 'User-Agent': USER_AGENT },
        signal: AbortSignal.timeout(TIMEOUT_MS),
      });
    } catch {
      throw new Failure('連不上 Z.ai');
    }
    let payload = null;
    try {
      payload = await response.json();
    } catch {
      payload = null;
    }
    const authFailed = response.status === 401 || response.status === 403 || payload?.code === 401 || payload?.code === 1000 || payload?.code === 1001;
    if (response.ok && payload && !authFailed) return payload;
    last = authFailed ? 'API key 被拒絕' : `HTTP ${response.status}`;
    if (!authFailed) break;
  }
  throw new Failure(last);
}

async function quotaResult() {
  let key;
  let source = 'zcode';
  try {
    key = await zcodeKey();
  } catch (error) {
    if (!(error instanceof Failure) || error.message !== 'keyring') throw error;
    key = opencodeKey();
    source = 'opencode';
    if (!key) throw new Failure('系統 keyring 解不開（可能還沒解鎖），opencode 也沒有 Z.ai key');
  }
  let payload;
  try {
    payload = await quota('https://api.z.ai', key);
  } catch (error) {
    if (source !== 'opencode') throw error;
    payload = await quota('https://open.bigmodel.cn', key);   // opencode's zhipuai key may be a bigmodel.cn one
  }
  return { ok: true, source, payload };
}

// ZCode's login headers for the reset API, or null when ZCode is not signed in to a personal Z.ai plan.
async function resetLogin() {
  // Team plans need organisation and project headers as well; only personal plans are handled here.
  if (zaiPlan().includes('team')) return null;
  const credentials = readJson(CREDENTIALS);
  const provider = (await reveal(credentials['oauth:active_provider']))?.trim();
  if (provider !== 'zai') return null;   // not signed in to ZCode with a Z.ai account
  const jwt = (await reveal(credentials.zcodejwttoken))?.trim();
  const access = (await reveal(credentials['oauth:zai:access_token']))?.trim();
  if (!jwt || !access) return null;
  return {
    Authorization: /^Bearer\s/i.test(jwt) ? jwt : `Bearer ${jwt}`,
    'X-Bigmodel-Authorization': access,
    'Bigmodel-Target-Type': 'PERSONAL',
    Accept: 'application/json',
    'User-Agent': USER_AGENT,
  };
}

async function resetApi(pathname, headers, body) {
  let response;
  try {
    response = await fetch(RESET_API + pathname, {
      method: body ? 'POST' : 'GET',
      headers: body ? { ...headers, 'Content-Type': 'application/json' } : headers,
      body: body ? JSON.stringify(body) : undefined,
      signal: AbortSignal.timeout(TIMEOUT_MS),
    });
  } catch {
    throw new Failure('連不上 ZCode');
  }
  if (response.status === 401 || response.status === 403) throw new Failure('ZCode 的登入失效了，在 ZCode 重新登入就會恢復');
  let payload = null;
  try {
    payload = await response.json();
  } catch {
    payload = null;
  }
  if (payload && typeof payload.code === 'number' && payload.code !== 0) {
    const message = typeof payload.msg === 'string' && payload.msg.trim() ? `：${payload.msg.trim().slice(0, 80)}` : '';
    throw new Failure(`ZCode 回應錯誤 ${payload.code}${message}`);
  }
  if (!response.ok) throw new Failure(`HTTP ${response.status}`);
  if (payload?.code !== 0 || !payload.data || typeof payload.data !== 'object') throw new Failure('ZCode 的回應看不懂');
  return payload.data;
}

// Unused Quota Reset Cards, as expiry times in milliseconds: {week: [...], five_hour: [...]}.
async function resetCards() {
  const headers = await resetLogin();
  if (!headers) return null;
  const data = await resetApi('/status', headers);
  const expiries = (list) => (Array.isArray(list) ? list : [])
    .map((item) => Number(item?.expire_at))
    .filter((value) => Number.isFinite(value) && value > 0);
  return { week: expiries(data.available_week_resets), five_hour: expiries(data.available_five_hour_resets) };
}

async function useResetCard(type, idempotencyKey) {
  if (!RESET_TYPES.includes(type)) throw new Failure('重置類型只能是 WEEK 或 FIVE_HOUR');
  if (!IDEMPOTENCY_KEY.test(idempotencyKey ?? '')) throw new Failure('idempotency key 格式不對');
  const headers = await resetLogin();
  if (!headers) throw new Failure('ZCode 沒有登入 Z.ai 個人方案');
  const data = await resetApi('/use', headers, { idempotency_key: idempotencyKey, reset_type: type });
  if (data.used !== true) throw new Failure('ZCode 沒有確認已重置');
  return { ok: true, used: true };
}

function keyringMessage(error) {
  if (error instanceof Failure && error.message === 'keyring') return new Failure('系統 keyring 解不開（可能還沒解鎖）');
  return error;
}

async function main() {
  const command = process.argv[2] ?? 'quota';
  let result;
  if (command === 'quota') {
    result = await quotaResult();
  } else if (command === 'resets') {
    try {
      result = { ok: true, resets: await resetCards() };
    } catch (error) {
      throw keyringMessage(error);
    }
  } else if (command === 'use') {
    try {
      result = await useResetCard(process.argv[3], process.argv[4]);
    } catch (error) {
      throw keyringMessage(error);
    }
  } else {
    throw new Failure(`不認得的指令：${command}`);
  }
  process.stdout.write(JSON.stringify(result) + '\n');
}

main().catch((error) => {
  const message = error instanceof Failure ? error.message : `讀取失敗（${error?.name ?? 'Error'}）`;
  process.stdout.write(JSON.stringify({ ok: false, error: message }) + '\n');
  process.exitCode = 1;
});
