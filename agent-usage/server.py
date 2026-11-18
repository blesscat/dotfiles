#!/usr/bin/env python3
"""Agent usage page: how much quota Claude, Codex, ZCode, MiniMax and Antigravity have left.

Serves a phone-friendly page at / and the same data as JSON at /api/usage.

Data sources:
  Claude       ~/.cache/agent-usage/claude/<session>.json
               written by ~/.claude/statusline.sh on every status line render
  Codex        the last "rate_limits" event in ~/.codex/sessions/**/rollout-*.jsonl
  ZCode        Z.ai quota API, polled with the key ZCode is signed in with (decrypted in memory by
               zcode-usage.cjs via the system keyring), or ZAI_API_KEY from ~/.config/agent-usage/keys
  MiniMax      MiniMax coding plan API, polled with mcode's signed-in OAuth token while it is still
               valid (never refreshed here), or MINIMAX_API_KEY from the same keys file
  Antigravity  ~/.cache/over9k/usage/antigravity.json
               written by ~/.config/herdr-usage/antigravity-capture.py

Runs on Linux and macOS with Python 3.8 or newer and only the standard library.
install.sh sets it up as a systemd user service (Linux) or a launchd agent (macOS).

Settings (environment, all optional; install.sh writes them into the service when given):
  AGENT_USAGE_HOST  address to listen on. Default: this machine's Tailscale IPv4 address, so only
                    devices on your tailnet can open the page (waits for Tailscale to come up);
                    127.0.0.1 when Tailscale is not installed.
  AGENT_USAGE_PORT  default 8790
  AGENT_USAGE_NODE  node for zcode-usage.cjs. Default: the newest nvm node, then Homebrew's,
                    then node on PATH (services start with a bare PATH, so nvm's is not on it).
"""

from datetime import datetime
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import ipaddress
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import threading
import time
import urllib.error
import urllib.request

HOME = Path.home()
CACHE_DIR = HOME / '.cache/agent-usage'
CLAUDE_DIR = CACHE_DIR / 'claude'
CODEX_SESSIONS = HOME / '.codex/sessions'
ANTIGRAVITY_FILE = HOME / '.cache/over9k/usage/antigravity.json'
KEYS_FILE = HOME / '.config/agent-usage/keys'
ZCODE_HELPER = Path(__file__).with_name('zcode-usage.cjs')
NODE_FALLBACKS = [Path('/opt/homebrew/bin/node'), Path('/usr/local/bin/node')]
TAILSCALE_FALLBACKS = [Path('/Applications/Tailscale.app/Contents/MacOS/Tailscale'),   # macOS app
                       Path('/opt/homebrew/bin/tailscale'), Path('/usr/local/bin/tailscale'),
                       Path('/usr/bin/tailscale')]
LISTEN_RETRY_SECONDS = 10

MAX_AGE = 8 * 86400          # ignore data older than this (longer than a weekly window)
CLAUDE_CLEANUP_AGE = 14 * 86400
CODEX_FILES_TO_SCAN = 20
CODEX_TAIL_BYTES = 512 * 1024
SAME_WINDOW_SLACK = 600      # resets_at values this close belong to the same window
POLL_SECONDS = 300           # how often the API-backed providers are asked
KEYS_CHECK_SECONDS = 10      # how often the keys file is checked for changes
HTTP_TIMEOUT = 15

CLAUDE_LABELS = {'five_hour': '5 小時', 'seven_day': '7 天', 'seven_day_opus': '7 天（Opus）',
                 'seven_day_sonnet': '7 天（Sonnet）'}
ANTIGRAVITY_LABELS = {'gemini-5h': 'Gemini 5 小時', 'gemini-weekly': 'Gemini 每週',
                      '3p-5h': '第三方模型 5 小時', '3p-weekly': '第三方模型 每週'}


def number(value):
    """Return value as a float, or None when it is not a real number."""
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        return None
    return float(value)


def window(label, remaining, resets_at, now, unlimited=False):
    reset_passed = resets_at is not None and now >= resets_at
    if unlimited:
        remaining = 100.0
    return {
        'label': label,
        'remaining': 100.0 if reset_passed else max(0.0, min(100.0, remaining)),
        'resets_at': resets_at,
        'reset_passed': reset_passed,
        'unlimited': unlimited,
    }


# ---- Claude -----------------------------------------------------------------

def claude(now):
    best = {}   # window key -> (resets_at, used, at)
    newest = None
    if CLAUDE_DIR.is_dir():
        for path in CLAUDE_DIR.glob('*.json'):
            try:
                age = now - path.stat().st_mtime
                if age > CLAUDE_CLEANUP_AGE:
                    path.unlink(missing_ok=True)
                    continue
                if age > MAX_AGE:
                    continue
                data = json.loads(path.read_text())
            except (OSError, ValueError):
                continue
            at = number(data.get('at'))
            limits = data.get('rate_limits')
            if at is None or not isinstance(limits, dict):
                continue
            for key, value in limits.items():
                if not isinstance(value, dict):
                    continue
                used = number(value.get('used_percentage'))
                resets_at = number(value.get('resets_at'))
                if used is None:
                    continue
                candidate = (resets_at or 0.0, used, at)
                if key not in best or newer_window(candidate, best[key]):
                    best[key] = candidate
                newest = at if newest is None else max(newest, at)
    if not best:
        return {'name': 'Claude', 'plan': None, 'at': None, 'windows': [],
                'note': '還沒有資料：在這台機器開一次 Claude Code 就會出現'}
    order = list(CLAUDE_LABELS)
    keys = sorted(best, key=lambda k: (order.index(k) if k in order else len(order), k))
    windows = [window(CLAUDE_LABELS.get(k, k), 100.0 - best[k][1], best[k][0] or None, now) for k in keys]
    return {'name': 'Claude', 'plan': None, 'at': newest, 'windows': windows}


def newer_window(candidate, current):
    """Prefer the later window; within one window usage only grows, so prefer the higher value."""
    c_reset, c_used, c_at = candidate
    r_reset, r_used, r_at = current
    if abs(c_reset - r_reset) > SAME_WINDOW_SLACK:
        return c_reset > r_reset
    if c_used != r_used:
        return c_used > r_used
    return c_at > r_at


# ---- Codex ------------------------------------------------------------------

_codex_cache = {}   # path -> (mtime, size, {limit_id: (at, rate_limits)})
RATE_LIMITS_RE = re.compile(rb'"rate_limits":\s*\{')


def codex_events(path, stat):
    cached = _codex_cache.get(path)
    if cached and cached[0] == stat.st_mtime and cached[1] == stat.st_size:
        return cached[2]
    found = {}
    try:
        with open(path, 'rb') as stream:
            start = max(0, stat.st_size - CODEX_TAIL_BYTES)
            stream.seek(start)
            chunk = stream.read()
    except OSError:
        return found
    lines = chunk.split(b'\n')
    if start > 0:
        lines = lines[1:]   # the first line is probably cut off
    for line in reversed(lines):
        if not RATE_LIMITS_RE.search(line):
            continue
        try:
            event = json.loads(line)
        except ValueError:
            continue
        limits = (event.get('payload') or {}).get('rate_limits')
        if not isinstance(limits, dict):
            continue
        limit_id = limits.get('limit_id') or 'codex'
        if limit_id in found:
            continue
        at = iso_to_epoch(event.get('timestamp'))
        found[limit_id] = (stat.st_mtime if at is None else at, limits)
    _codex_cache[path] = (stat.st_mtime, stat.st_size, found)
    return found


def window_label(minutes):
    if minutes is None:
        return '用量'
    if minutes % 1440 == 0:
        return f'{int(minutes // 1440)} 天'
    if minutes % 60 == 0:
        return f'{int(minutes // 60)} 小時'
    return f'{int(minutes)} 分鐘'


def codex(now):
    files = []
    if CODEX_SESSIONS.is_dir():
        for path in CODEX_SESSIONS.rglob('rollout-*.jsonl'):
            try:
                stat = path.stat()
            except OSError:
                continue
            if now - stat.st_mtime <= MAX_AGE:
                files.append((stat.st_mtime, path, stat))
    files.sort(reverse=True)
    latest = {}
    for _, path, stat in files[:CODEX_FILES_TO_SCAN]:
        for limit_id, (at, limits) in codex_events(path, stat).items():
            if limit_id not in latest or at > latest[limit_id][0]:
                latest[limit_id] = (at, limits)
    if not latest:
        return [{'name': 'Codex', 'plan': None, 'at': None, 'windows': [],
                 'note': '還沒有資料：在這台機器跑一次 Codex 就會出現'}]
    agents = []
    for limit_id in sorted(latest, key=lambda k: (k != 'codex', k)):
        at, limits = latest[limit_id]
        windows = []
        for slot in ('primary', 'secondary'):
            value = limits.get(slot)
            if not isinstance(value, dict):
                continue
            used = number(value.get('used_percent'))
            if used is None:
                continue
            windows.append(window(window_label(number(value.get('window_minutes'))), 100.0 - used,
                                  number(value.get('resets_at')), now))
        windows.sort(key=lambda w: w['label'].endswith('天'))
        name = 'Codex' if limit_id == 'codex' else f'Codex（{limits.get("limit_name") or limit_id}）'
        agents.append({'name': name, 'plan': limits.get('plan_type'), 'at': at, 'windows': windows})
    return agents


# ---- Antigravity ------------------------------------------------------------

def antigravity(now):
    try:
        data = json.loads(ANTIGRAVITY_FILE.read_text())
    except (OSError, ValueError):
        data = None
    at = number(data.get('at')) if isinstance(data, dict) else None
    quota = data.get('quota') if isinstance(data, dict) else None
    if at is None or not isinstance(quota, dict) or now - at > MAX_AGE:
        return {'name': 'Antigravity', 'plan': None, 'at': None, 'windows': [],
                'note': '沒有最近的資料：在這台機器開一次 Antigravity CLI 就會更新'}
    windows = []
    for key, label in ANTIGRAVITY_LABELS.items():
        value = quota.get(key)
        if not isinstance(value, dict):
            continue
        fraction = number(value.get('remaining_fraction'))
        if fraction is None:
            continue
        windows.append(window(label, fraction * 100.0, iso_to_epoch(value.get('reset_time')), now))
    plan = data.get('plan') if isinstance(data.get('plan'), str) else None
    return {'name': 'Antigravity', 'plan': plan, 'at': at, 'windows': windows}


ISO_FRACTION_RE = re.compile(r'\.(\d+)')


def iso_to_epoch(value):
    """Parse an ISO 8601 time. Before Python 3.11, fromisoformat takes neither "Z" nor fractions
    that are not exactly 3 or 6 digits, so normalise those first."""
    if not isinstance(value, str):
        return None
    text = value.strip().replace('Z', '+00:00')
    text = ISO_FRACTION_RE.sub(lambda m: '.' + (m.group(1) + '000000')[:6], text, count=1)
    try:
        return datetime.fromisoformat(text).timestamp()
    except ValueError:
        return None


# ---- API-backed providers (ZCode / MiniMax) ---------------------------------

class ProviderError(Exception):
    """A failure whose message is safe to show on the page (never contains a key)."""


def read_keys():
    keys = {}
    try:
        text = KEYS_FILE.read_text()
    except OSError:
        return keys
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith('#') or '=' not in line:
            continue
        name, value = line.split('=', 1)
        value = value.strip().strip('"\'')
        if value:
            keys[name.strip()] = value
    return keys


def keys_signature():
    try:
        stat = KEYS_FILE.stat()
        return (stat.st_mtime_ns, stat.st_size)
    except OSError:
        return None


def get_json(url, headers):
    request = urllib.request.Request(url, headers={
        'Accept': 'application/json', 'User-Agent': 'agent-usage/1.0', **headers})
    try:
        with urllib.request.urlopen(request, timeout=HTTP_TIMEOUT) as response:
            body = response.read(2_000_000)
    except urllib.error.HTTPError as error:
        raise ProviderError(f'HTTP {error.code}') from None
    except (urllib.error.URLError, TimeoutError, OSError):
        raise ProviderError('連不上服務') from None
    try:
        payload = json.loads(body)
    except ValueError:
        raise ProviderError('回應不是 JSON') from None
    if not isinstance(payload, dict):
        raise ProviderError('回應格式看不懂')
    return payload


def zai_label(kind, unit, count):
    if kind == 'TIME_LIMIT':
        return 'MCP 工具（每月）' if unit == 5 else 'MCP 工具'
    if unit == 3:
        return f'{int(count or 5)} 小時'
    if unit == 6:
        return '每週' if count in (None, 1) else f'{int(count)} 週'
    if unit == 5:
        return '每月'
    return kind


def zai_order(kind, unit):
    return {3: 0, 6: 1, 5: 2}.get(unit, 3) + (10 if kind == 'TIME_LIMIT' else 0)


def node_version(path):
    """(24, 14, 0) for ~/.nvm/versions/node/v24.14.0/bin/node."""
    try:
        return tuple(int(part) for part in path.parent.parent.name.lstrip('v').split('.'))
    except ValueError:
        return ()


def find_node():
    configured = os.environ.get('AGENT_USAGE_NODE')
    if configured:
        return configured
    candidates = sorted(HOME.glob('.nvm/versions/node/v*/bin/node'), key=node_version, reverse=True)
    for candidate in candidates + NODE_FALLBACKS:
        if os.access(candidate, os.X_OK):
            return str(candidate)
    return shutil.which('node')


def zcode_helper():
    """Run zcode-usage.cjs, which decrypts ZCode's own key in memory and returns only the quota response."""
    node = find_node()
    if not node:
        raise ProviderError('找不到 node')
    try:
        done = subprocess.run([str(node), str(ZCODE_HELPER)], capture_output=True, text=True, timeout=60)
    except subprocess.TimeoutExpired:
        raise ProviderError('查詢逾時') from None
    try:
        result = json.loads(done.stdout.strip().splitlines()[-1])
    except (IndexError, ValueError):
        raise ProviderError('查詢程式沒有回應') from None
    if not result.get('ok'):
        raise ProviderError(str(result.get('error') or '查詢失敗')[:120])
    return result['payload']


def fetch_zai(keys):
    """Z.ai coding plan quota; same endpoint and fields the ZCode client uses.

    Uses ZAI_API_KEY from the keys file when set, otherwise the key ZCode itself is signed in with.
    """
    key = keys.get('ZAI_API_KEY')
    if key:
        base = keys.get('ZAI_BASE_URL', 'https://api.z.ai').rstrip('/')
        payload = get_json(f'{base}/api/monitor/usage/quota/limit', {'Authorization': f'Bearer {key}'})
    else:
        payload = zcode_helper()
    if not isinstance(payload, dict):
        raise ProviderError('回應格式看不懂')
    if payload.get('success') is False or payload.get('code') not in (None, 0, 200):
        raise ProviderError(str(payload.get('msg') or payload.get('message') or f'錯誤 {payload.get("code")}')[:120])
    data = payload.get('data') if isinstance(payload.get('data'), dict) else {}
    windows = []
    for limit in data.get('limits') or []:
        if not isinstance(limit, dict) or not isinstance(limit.get('type'), str):
            continue
        used = number(limit.get('percentage'))
        if used is None:
            continue
        unit, count = number(limit.get('unit')), number(limit.get('number'))
        reset_ms = number(limit.get('nextResetTime'))
        windows.append({'label': zai_label(limit['type'], unit, count), 'remaining': 100.0 - used,
                        'resets_at': reset_ms / 1000 if reset_ms else None, 'unlimited': False,
                        'order': zai_order(limit['type'], unit)})
    if not windows:
        raise ProviderError('回應裡沒有額度資料')
    windows.sort(key=lambda w: w.pop('order'))
    level = data.get('level')
    return {'plan': level.strip() if isinstance(level, str) and level.strip() else None, 'windows': windows}


MINIMAX_SKIP = re.compile(r'video|image|speech|music|hailuo|audio', re.I)


def minimax_window(entry, period, now, prefix):
    """period is 'interval' (the short rolling window) or 'weekly'; mirrors the mcode client."""
    field = f'current_{period}'
    remains_ms = number(entry.get('remains_time' if period == 'interval' else 'weekly_remains_time'))
    resets_at = now + remains_ms / 1000 if remains_ms is not None and remains_ms >= 0 else None
    if period == 'interval':
        start, end = number(entry.get('start_time')), number(entry.get('end_time'))
        hours = (end - start) / 3_600_000 if start and end and end > start else None
        label = f'{hours:g} 小時' if hours else '短週期'
    else:
        label = '每週'
    label = f'{prefix}{label}'
    if entry.get(f'{field}_status') == 3:
        return {'label': label, 'remaining': 100.0, 'resets_at': resets_at, 'unlimited': True}
    remaining = number(entry.get(f'{field}_remaining_percent'))
    if remaining is None:
        # MiniMax's "usage_count" is the count still available, not the count used.
        total, left = number(entry.get(f'{field}_total_count')), number(entry.get(f'{field}_usage_count'))
        if total is None or total <= 0 or left is None:
            return None
        remaining = left / total * 100
    return {'label': label, 'remaining': remaining, 'resets_at': resets_at, 'unlimited': False}


MINIMAX_BASES = {'en': 'https://platform.minimax.io', 'cn': 'https://www.minimaxi.com'}


def minimax_login():
    """The OAuth access token mcode is signed in with, as (expires_at, token, region).

    Returns None when mcode has never signed in here. The token is only read, never refreshed,
    so mcode's own login is never disturbed; it is valid for about two hours after mcode last ran.
    """
    data_dir = Path(os.environ.get('MINIMAX_DATA_DIR') or os.environ.get('MAVIS_DATA_DIR') or HOME / '.minimax')
    try:
        default_region = json.loads((data_dir / 'preferences/mcode-region.json').read_text())['regions']['prod']
    except (OSError, ValueError, KeyError, TypeError):
        default_region = 'en'
    best = None
    for path in [data_dir / 'auth.json', *data_dir.glob('auth/prod/*/mcode-public/auth.json')]:
        region = path.parts[-3] if path.parent.name == 'mcode-public' else default_region
        try:
            records = json.loads(path.read_text()).get('records') or {}
        except (OSError, ValueError, AttributeError):
            continue
        for record in records.values():
            token = record.get('accessToken') if isinstance(record, dict) else None
            expires = number(record.get('expiresAtMs')) if isinstance(record, dict) else None
            if isinstance(token, str) and token and expires and (best is None or expires > best[0] * 1000):
                best = (expires / 1000, token, region if region in MINIMAX_BASES else 'en')
    return best


def fetch_minimax(keys):
    """MiniMax coding plan quota, with MINIMAX_API_KEY when set, otherwise with mcode's login."""
    key = keys.get('MINIMAX_API_KEY')
    if key:
        base = keys.get('MINIMAX_BASE_URL', MINIMAX_BASES['en']).rstrip('/')
        url = f'{base}/v1/api/openplatform/coding_plan/remains'
    else:
        login = minimax_login()
        if login is None:
            return None
        expires, key, region = login
        if expires <= time.time() + 60:
            raise ProviderError('mcode 的登入 token 已過期，開一次 mcode 就會恢復更新')
        url = f'{MINIMAX_BASES[region]}/v1/api/openplatform/coding_plan/remains?business=Agent&device_platform=desktop'
    payload = get_json(url, {'Authorization': f'Bearer {key}'})
    status = (payload.get('base_resp') or {}).get('status_code') if isinstance(payload.get('base_resp'), dict) else None
    if status not in (None, 0):
        raise ProviderError(str(payload['base_resp'].get('status_msg') or f'錯誤 {status}')[:120])
    data = payload.get('data') if isinstance(payload.get('data'), dict) else payload
    entries = [e for e in data.get('model_remains') or [] if isinstance(e, dict)]
    general = [e for e in entries if str(e.get('model_name', '')).lower() == 'general']
    chosen = general or [e for e in entries if not MINIMAX_SKIP.search(str(e.get('model_name', '')))][:3]
    now = time.time()
    windows = []
    for entry in chosen:
        prefix = '' if len(chosen) == 1 else f'{entry.get("model_name")} '
        for period in ('interval', 'weekly'):
            win = minimax_window(entry, period, now, prefix)
            if win:
                windows.append(win)
    if not windows:
        raise ProviderError('回應裡沒有額度資料')
    return {'plan': None, 'windows': windows}


# (cache name, card title, note shown when the provider is not set up, fetch function).
# A fetch function returns None when it is not set up, and raises ProviderError when it fails.
PROVIDERS = [
    ('zai', 'ZCode', '還沒設定', fetch_zai),
    ('minimax', 'MiniMax', '還沒設定：在這台機器登入 mcode（或在 ~/.config/agent-usage/keys 填 MINIMAX_API_KEY）', fetch_minimax),
]


class Poller(threading.Thread):
    """Asks the API-backed providers every POLL_SECONDS, and right away when the keys file changes."""

    def __init__(self):
        super().__init__(daemon=True)
        self.lock = threading.Lock()
        self.state = {}
        for slug, *_ in PROVIDERS:
            try:
                saved = json.loads((CACHE_DIR / f'{slug}.json').read_text())
                self.state[slug] = {'ok': saved, 'error': None, 'has_key': True}
            except (OSError, ValueError):
                self.state[slug] = {'ok': None, 'error': None, 'has_key': False}

    def run(self):
        last_signature, next_poll = object(), 0.0
        while True:
            signature = keys_signature()
            if signature != last_signature or time.time() >= next_poll:
                last_signature = signature
                self.poll()
                next_poll = time.time() + POLL_SECONDS
            time.sleep(KEYS_CHECK_SECONDS)

    def poll(self):
        keys = read_keys()
        for slug, _name, _hint, fetch in PROVIDERS:
            try:
                result = fetch(keys)
                error = None
            except ProviderError as failure:
                result, error = None, str(failure)
            except Exception as failure:   # keep the poller alive whatever a provider does
                result, error = None, f'讀取失敗（{type(failure).__name__}）'
            with self.lock:
                entry = self.state[slug]
                entry['has_key'] = result is not None or error is not None
                entry['error'] = error
                if result is not None:
                    entry['ok'] = {'at': time.time(), **result}
                    save_cache(slug, entry['ok'])

    def agents(self, now):
        out = []
        with self.lock:
            for slug, name, hint, _ in PROVIDERS:
                entry = self.state[slug]
                ok = entry['ok'] if entry['has_key'] else None
                agent = {'name': name, 'plan': None, 'at': None, 'windows': []}
                if ok and now - ok.get('at', 0) <= MAX_AGE:
                    agent['plan'], agent['at'] = ok.get('plan'), ok.get('at')
                    agent['windows'] = [window(w['label'], w['remaining'], w.get('resets_at'), now,
                                               w.get('unlimited', False)) for w in ok.get('windows', [])]
                if not entry['has_key']:
                    agent['note'] = hint
                elif entry['error']:
                    agent['note'] = f'最近一次更新失敗：{entry["error"]}'
                elif not agent['windows']:
                    agent['note'] = '讀取中…'
                out.append(agent)
        return out


def save_cache(slug, data):
    try:
        CACHE_DIR.mkdir(parents=True, exist_ok=True)
        with tempfile.NamedTemporaryFile('w', dir=CACHE_DIR, delete=False, prefix=f'.{slug}.') as stream:
            json.dump(data, stream, ensure_ascii=False)
        os.replace(stream.name, CACHE_DIR / f'{slug}.json')
    except OSError:
        pass


POLLER = Poller()


def usage():
    now = time.time()
    return {'now': now, 'agents': [claude(now), *codex(now), *POLLER.agents(now), antigravity(now)]}


# ---- HTTP -------------------------------------------------------------------

APP_DIR = Path(__file__).resolve().parent
PNG = 'image/png'
# Fixed list of files the page needs (URL path -> file, content type); nothing else is served.
STATIC = {
    '/': ('index.html', 'text/html; charset=utf-8'),
    '/index.html': ('index.html', 'text/html; charset=utf-8'),
    '/manifest.webmanifest': ('manifest.webmanifest', 'application/manifest+json; charset=utf-8'),
    '/sw.js': ('sw.js', 'text/javascript; charset=utf-8'),
    '/icons/icon-192.png': ('icons/icon-192.png', PNG),
    '/icons/icon-512.png': ('icons/icon-512.png', PNG),
    '/icons/icon-maskable-512.png': ('icons/icon-maskable-512.png', PNG),
    '/icons/apple-touch-icon.png': ('icons/apple-touch-icon.png', PNG),
    '/icons/favicon.svg': ('icons/favicon.svg', 'image/svg+xml'),
    '/apple-touch-icon.png': ('icons/apple-touch-icon.png', PNG),   # iOS asks for these at the root
    '/favicon.ico': ('icons/icon-192.png', PNG),
}


class Handler(BaseHTTPRequestHandler):
    server_version = 'agent-usage'

    def do_GET(self):
        path = self.path.split('?', 1)[0]
        if path == '/api/usage':
            self.reply(200, 'application/json; charset=utf-8',
                       json.dumps(usage(), ensure_ascii=False).encode())
        elif path in STATIC:
            name, content_type = STATIC[path]
            try:
                body = (APP_DIR / name).read_bytes()
            except OSError:
                self.reply(404, 'text/plain; charset=utf-8', b'not found\n')
                return
            self.reply(200, content_type, body, cache='no-cache')
        else:
            self.reply(404, 'text/plain; charset=utf-8', b'not found\n')

    def reply(self, status, content_type, body, cache='no-store'):
        self.send_response(status)
        self.send_header('Content-Type', content_type)
        self.send_header('Content-Length', str(len(body)))
        self.send_header('Cache-Control', cache)
        self.send_header('X-Content-Type-Options', 'nosniff')
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass


def tailscale_cli():
    found = shutil.which('tailscale')
    if found:
        return found
    for candidate in TAILSCALE_FALLBACKS:
        if os.access(candidate, os.X_OK):
            return str(candidate)
    return None


def tailscale_ipv4(cli):
    """This machine's Tailscale IPv4 address, or None while Tailscale is not up."""
    try:
        done = subprocess.run([cli, 'ip', '-4'], capture_output=True, text=True, timeout=10)
    except (OSError, subprocess.TimeoutExpired):
        return None
    if done.returncode != 0:
        return None
    for word in done.stdout.split():
        try:
            return str(ipaddress.IPv4Address(word))
        except ValueError:
            continue
    return None


def listen():
    """Open the listening socket, waiting (rather than exiting) while the address is not available yet,
    for example when the service starts at boot before Tailscale is up."""
    port = int(os.environ.get('AGENT_USAGE_PORT', '8790'))
    configured = os.environ.get('AGENT_USAGE_HOST')
    cli = None if configured else tailscale_cli()
    last_reason = None
    while True:
        host = configured or (tailscale_ipv4(cli) if cli else '127.0.0.1')
        if host:
            try:
                return ThreadingHTTPServer((host, port), Handler), host, port
            except OSError as error:
                reason = f'cannot listen on {host}:{port} ({error.strerror or error})'
        else:
            reason = 'waiting for Tailscale to come up'
        if reason != last_reason:
            print(f'agent-usage: {reason}; retrying every {LISTEN_RETRY_SECONDS}s', flush=True)
            last_reason = reason
        time.sleep(LISTEN_RETRY_SECONDS)


def main():
    server, host, port = listen()
    POLLER.start()
    print(f'agent-usage listening on http://{host}:{port}', flush=True)
    server.serve_forever()


if __name__ == '__main__':
    main()
