#!/usr/bin/env node
// Prints the Z.ai coding plan quota of the account ZCode is signed in with, as one JSON line:
//   {"ok":true,"source":"zcode"|"opencode","payload":<quota API response>}
//   {"ok":false,"error":"<short reason, safe to show>"}
// The API key is decrypted in this process's memory only; it is never printed or written anywhere.
//
// ZCode keeps the key in ~/.zcode/v2/credentials.json as "enc:v2:os:<fingerprint>:<iv>.<tag>.<data>"
// (AES-256-GCM). The 32-byte key sits in the system keyring (Secret Service on Linux, Keychain on
// macOS) under the service "ZCode Credential Encryption", account sha256(<absolute path of credentials.json>).
// If the keyring cannot be read (for example it is locked), the Z.ai key opencode saved is used instead.
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
const TIMEOUT_MS = 15000;

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

async function zcodeKey() {
  const providerId = readJson(path.join(ZCODE_DIR, 'provider_config.json'))?.config?.defaultModelSelection?.providerId ?? '';
  if (!providerId.includes('zai-')) throw new Failure('ZCode 目前用的不是 Z.ai Coding Plan');
  const plan = providerId.split(':').find((part) => part.includes('zai-'));
  const credentials = readJson(CREDENTIALS);
  const stored = Object.entries(credentials)
    .filter(([name, value]) => name.endsWith(':api-key') && name.includes(plan) && typeof value === 'string')
    .map(([, value]) => value)[0];
  if (!stored) throw new Failure('ZCode 裡沒有 Z.ai 的 API key，先在 ZCode 登入');
  if (!stored.startsWith('enc:')) return stored;
  if (!stored.startsWith('enc:v2:os:')) throw new Failure('ZCode 的金鑰格式不支援');
  const [, fingerprint, payload] = stored.slice('enc:v2:'.length).split(':');

  let encoded;
  try {
    const { AsyncEntry } = require(KEYRING_MODULE);
    const entry = new AsyncEntry('ZCode Credential Encryption', sha256(path.resolve(CREDENTIALS)).toString('hex'),
      { linux: { store: 'secret-service' } });
    encoded = await entry.getPassword();
  } catch {
    encoded = undefined;
  }
  if (!encoded) throw new Failure('keyring');
  const key = Buffer.from(encoded, 'base64url');
  if (sha256(key).toString('hex').slice(0, 24) !== fingerprint) throw new Failure('keyring');

  const [iv, tag, data] = payload.split('.').map((part) => Buffer.from(part, 'base64url'));
  try {
    const decipher = crypto.createDecipheriv('aes-256-gcm', key, iv);
    decipher.setAuthTag(tag);
    return Buffer.concat([decipher.update(data), decipher.final()]).toString('utf8');
  } catch {
    throw new Failure('ZCode 的金鑰解不開');
  }
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
        headers: { Authorization: authorization, Accept: 'application/json', 'User-Agent': 'agent-usage/1.0' },
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

async function main() {
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
  process.stdout.write(JSON.stringify({ ok: true, source, payload }) + '\n');
}

main().catch((error) => {
  const message = error instanceof Failure ? error.message : `讀取失敗（${error?.name ?? 'Error'}）`;
  process.stdout.write(JSON.stringify({ ok: false, error: message }) + '\n');
  process.exitCode = 1;
});
