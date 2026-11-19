#!/usr/bin/env python3
"""Agent usage page: how much quota Claude, Codex, ZCode, MiniMax and Antigravity have left.

Serves a phone-friendly page at / and the same data as JSON at /api/usage.

Data sources:
  Claude       ~/.cache/agent-usage/claude/<session>.json
               written by ~/.claude/statusline.sh on every status line render
  Codex        `codex app-server` (account/rateLimits/read, the same read Codex's /usage does), every
               5 minutes, including the usage limit resets; the last "rate_limits" event in
               ~/.codex/sessions/**/rollout-*.jsonl when that is newer or the app server cannot be used
  ZCode        Z.ai quota API, polled with the key ZCode is signed in with (decrypted in memory by
               zcode-usage.cjs via the system keyring), or ZAI_API_KEY from ~/.config/agent-usage/keys.
               Also the unused Quota Reset Cards, read with ZCode's login
  MiniMax      MiniMax coding plan API, polled with mcode's signed-in OAuth token while it is still
               valid (never refreshed here), or MINIMAX_API_KEY from the same keys file
  Antigravity  ~/.cache/over9k/usage/antigravity.json
               written by ~/.config/herdr-usage/antigravity-capture.py

POST /api/reset uses one Codex usage limit reset or one ZCode reset card, when the page asks
(after the viewer confirms). It cannot be undone. See handle_reset for the request checks.

Runs on Linux and macOS with Python 3.8 or newer and only the standard library.
install.sh sets it up as a systemd user service (Linux) or a launchd agent (macOS).

Settings (environment, all optional; install.sh writes them into the service when given):
  AGENT_USAGE_HOST  address to listen on. Default: this machine's Tailscale IPv4 address, so only
                    devices on your tailnet can open the page (waits for Tailscale to come up);
                    127.0.0.1 when Tailscale is not installed.
  AGENT_USAGE_PORT  default 8790
  AGENT_USAGE_NODE  node for zcode-usage.cjs. Default: the newest nvm node, then Homebrew's,
                    then node on PATH (services start with a bare PATH, so nvm's is not on it).
  AGENT_USAGE_CODEX codex for the app server. Default: codex on PATH, then ~/.local/bin/codex,
                    then Homebrew's.
"""

from datetime import datetime
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import ipaddress
import json
import os
from pathlib import Path
import re
import select
import shutil
import socket
import subprocess
import tempfile
import threading
import time
import urllib.error
import urllib.request
from urllib.parse import urlsplit

HOME = Path.home()
CACHE_DIR = HOME / '.cache/agent-usage'
CLAUDE_DIR = CACHE_DIR / 'claude'
CODEX_SESSIONS = HOME / '.codex/sessions'
ANTIGRAVITY_FILE = HOME / '.cache/over9k/usage/antigravity.json'
KEYS_FILE = HOME / '.config/agent-usage/keys'
ZCODE_HELPER = Path(__file__).with_name('zcode-usage.cjs')
NODE_FALLBACKS = [Path('/opt/homebrew/bin/node'), Path('/usr/local/bin/node')]
CODEX_FALLBACKS = [HOME / '.local/bin/codex', Path('/opt/homebrew/bin/codex'), Path('/usr/local/bin/codex')]
CODEX_TIMEOUT = 45           # seconds for one short-lived `codex app-server` run
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


def codex(now, live=None):
    """Codex cards. live is Poller.codex_live(): limits read from `codex app-server`, used when newer."""
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
    if live and live.get('limits'):
        for limit_id, limits in live['limits'].items():
            if limit_id not in latest or live['at'] > latest[limit_id][0]:
                latest[limit_id] = (live['at'], limits)
    resets = codex_resets_view(live, now)
    if not latest:
        if resets:
            return [{'name': 'Codex', 'plan': None, 'at': None, 'windows': [], 'resets': resets,
                     'note': '還沒有額度資料'}]
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
    if resets:
        agents[0]['resets'] = resets   # resets belong to the account; show them on the main card
    return agents


def find_codex():
    configured = os.environ.get('AGENT_USAGE_CODEX')
    if configured:
        return configured
    found = shutil.which('codex')
    if found:
        return found
    for candidate in CODEX_FALLBACKS:
        if os.access(candidate, os.X_OK):
            return str(candidate)
    return None


def codex_rpc(calls):
    """Start a short-lived `codex app-server`, send the JSON-RPC calls [(method, params)] in order and
    return their results. Codex handles its own login and token refresh. Raises ProviderError."""
    codex_bin = find_codex()
    if not codex_bin:
        raise ProviderError('找不到 codex')
    try:
        proc = subprocess.Popen([codex_bin, 'app-server'], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                stderr=subprocess.DEVNULL)
    except OSError:
        raise ProviderError('codex 開不起來') from None
    deadline = time.monotonic() + CODEX_TIMEOUT
    pending = b''

    def send(message):
        proc.stdin.write(json.dumps(message).encode() + b'\n')
        proc.stdin.flush()

    def receive(request_id):
        # Read raw bytes so select() never waits on data already sitting in a Python buffer.
        nonlocal pending
        while True:
            while b'\n' in pending:
                line, pending = pending.split(b'\n', 1)
                try:
                    message = json.loads(line)
                except ValueError:
                    continue
                # Requests and notifications from the server carry "method"; only replies matter here.
                if isinstance(message, dict) and message.get('id') == request_id and 'method' not in message:
                    return message
            left = deadline - time.monotonic()
            if left <= 0:
                raise ProviderError('codex 沒有回應')
            if not select.select([proc.stdout], [], [], left)[0]:
                continue
            chunk = os.read(proc.stdout.fileno(), 65536)
            if not chunk:
                raise ProviderError('codex 意外結束')
            pending += chunk

    try:
        send({'jsonrpc': '2.0', 'id': 0, 'method': 'initialize',
              'params': {'clientInfo': {'name': 'agent-usage', 'version': '1.0'}}})
        receive(0)
        send({'jsonrpc': '2.0', 'method': 'initialized'})
        results = []
        for request_id, (method, params) in enumerate(calls, 1):
            send({'jsonrpc': '2.0', 'id': request_id, 'method': method, 'params': params})
            reply = receive(request_id)
            if 'error' in reply:
                error = reply['error'] if isinstance(reply['error'], dict) else {}
                raise ProviderError(str(error.get('message') or 'codex 回報錯誤')[:160])
            results.append(reply.get('result'))
        return results
    except OSError:
        raise ProviderError('codex 意外結束') from None
    finally:
        proc.kill()
        proc.wait()
        for stream in (proc.stdin, proc.stdout):
            try:
                stream.close()
            except OSError:
                pass


def codex_live_limits(snapshot):
    """An app-server RateLimitSnapshot in the shape of a rollout "rate_limits" event."""
    limits = {'plan_type': snapshot.get('planType'), 'limit_name': snapshot.get('limitName')}
    for slot in ('primary', 'secondary'):
        value = snapshot.get(slot)
        if isinstance(value, dict) and number(value.get('usedPercent')) is not None:
            limits[slot] = {'used_percent': value['usedPercent'], 'window_minutes': value.get('windowDurationMins'),
                            'resets_at': value.get('resetsAt')}
    return limits


def fetch_codex_live():
    """Codex limits and usage limit resets, or None when codex is not installed here."""
    if not find_codex():
        return None
    result = codex_rpc([('account/rateLimits/read', {})])[0]
    if not isinstance(result, dict):
        raise ProviderError('codex 的回應看不懂')
    snapshots = result.get('rateLimitsByLimitId')
    if not isinstance(snapshots, dict) or not snapshots:
        single = result.get('rateLimits')
        snapshots = {(single or {}).get('limitId') or 'codex': single} if isinstance(single, dict) else {}
    limits = {limit_id: codex_live_limits(snapshot) for limit_id, snapshot in snapshots.items()
              if isinstance(snapshot, dict)}
    credits = result.get('rateLimitResetCredits')
    resets = None
    if isinstance(credits, dict) and number(credits.get('availableCount')) is not None:
        expiries = [number(item.get('expiresAt')) for item in credits.get('credits') or []
                    if isinstance(item, dict) and item.get('status') in (None, 'available')]
        resets = {'count': int(credits['availableCount']), 'expires': sorted(e for e in expiries if e)}
    return {'limits': limits, 'resets': resets}


def codex_resets_view(live, now):
    if not live:
        return None
    if live.get('error'):
        return {'title': '重置', 'items': [], 'error': live['error']}
    resets = live.get('resets')
    if not resets:
        return None
    upcoming = [at for at in resets['expires'] if at > now]
    return {'title': '重置', 'error': None, 'items': [
        {'agent': 'codex', 'kind': 'FULL', 'label': '全部額度', 'count': resets['count'],
         'expires_at': upcoming[0] if upcoming else None}]}


CODEX_OUTCOMES = {
    'reset': (True, '已重置，Codex 的額度補滿了'),
    'alreadyRedeemed': (True, '這次重置已經完成了'),
    'nothingToReset': (False, '目前沒有需要重置的額度，沒有用掉'),
    'noCredit': (False, '沒有可用的重置了'),
}


def use_codex_reset(key):
    result = codex_rpc([('account/rateLimitResetCredit/consume', {'idempotencyKey': key})])[0]
    outcome = result.get('outcome') if isinstance(result, dict) else None
    return CODEX_OUTCOMES.get(outcome, (False, f'codex 回應看不懂（{outcome}）'))


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


def zcode_helper(*args):
    """Run zcode-usage.cjs, which decrypts ZCode's own secrets in memory and prints only the result."""
    node = find_node()
    if not node:
        raise ProviderError('找不到 node')
    try:
        done = subprocess.run([str(node), str(ZCODE_HELPER), *args], capture_output=True, text=True, timeout=60)
    except subprocess.TimeoutExpired:
        raise ProviderError('查詢逾時') from None
    try:
        result = json.loads(done.stdout.strip().splitlines()[-1])
    except (IndexError, ValueError):
        raise ProviderError('查詢程式沒有回應') from None
    if not result.get('ok'):
        raise ProviderError(str(result.get('error') or '查詢失敗')[:120])
    return result


RESET_CARD_KINDS = (('week', 'WEEK', '每週'), ('five_hour', 'FIVE_HOUR', '5 小時'))


def zcode_reset_cards():
    """Expiry times (epoch seconds) of the unused Quota Reset Cards, as {'week': [...], 'five_hour': [...]},
    or None when ZCode is not signed in to a personal Z.ai plan."""
    found = zcode_helper('resets').get('resets')
    if not isinstance(found, dict):
        return None
    cards = {}
    for kind, _type, _label in RESET_CARD_KINDS:
        expiries = found.get(kind) if isinstance(found.get(kind), list) else []
        cards[kind] = sorted(value / 1000 for value in map(number, expiries) if value)
    return cards


def use_zcode_reset(kind, key):
    zcode_helper('use', kind, key)   # raises ProviderError with Z.ai's reason when it is refused
    return True, '已重置，ZCode 的額度補滿了'


def fetch_zai(keys):
    """Z.ai coding plan quota; same endpoint and fields the ZCode client uses.

    Uses ZAI_API_KEY from the keys file when set, otherwise the key ZCode itself is signed in with.
    """
    key = keys.get('ZAI_API_KEY')
    if key:
        base = keys.get('ZAI_BASE_URL', 'https://api.z.ai').rstrip('/')
        payload = get_json(f'{base}/api/monitor/usage/quota/limit', {'Authorization': f'Bearer {key}'})
    else:
        payload = zcode_helper()['payload']
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
    try:
        reset_cards, reset_cards_error = zcode_reset_cards(), None
    except ProviderError as failure:
        reset_cards, reset_cards_error = None, str(failure)
    return {'plan': level.strip() if isinstance(level, str) and level.strip() else None, 'windows': windows,
            'reset_cards': reset_cards, 'reset_cards_error': reset_cards_error}


def reset_cards_view(ok, now):
    """The reset card section of the ZCode card on the page, or None when there is nothing to show."""
    if ok.get('reset_cards_error'):
        return {'title': '重置卡', 'items': [], 'error': ok['reset_cards_error']}
    cards = ok.get('reset_cards')
    if not isinstance(cards, dict):
        return None
    items = []
    for kind, reset_type, label in RESET_CARD_KINDS:
        left = [at for at in cards.get(kind) or [] if at > now]
        items.append({'agent': 'zcode', 'kind': reset_type, 'label': label, 'count': len(left),
                      'expires_at': left[0] if left else None})
    return {'title': '重置卡', 'items': items, 'error': None}


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
        self.wake = threading.Event()
        self.state = {}
        self.codex = {'ok': None, 'error': None}
        try:
            self.codex['ok'] = json.loads((CACHE_DIR / 'codex-live.json').read_text())
        except (OSError, ValueError):
            pass
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
            if self.wake.wait(KEYS_CHECK_SECONDS):
                self.wake.clear()
                next_poll = 0.0

    def poll_soon(self):
        """Ask everything again now, for example right after a reset."""
        self.wake.set()

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
        self.poll_codex()

    def poll_codex(self):
        try:
            result, error = fetch_codex_live(), None
        except ProviderError as failure:
            result, error = None, str(failure)
        except Exception as failure:
            result, error = None, f'讀取失敗（{type(failure).__name__}）'
        with self.lock:
            self.codex['error'] = error
            if result is not None:
                self.codex['ok'] = {'at': time.time(), **result}
                save_cache('codex-live', self.codex['ok'])
            elif error is None:
                self.codex['ok'] = None   # codex is not installed here

    def codex_live(self, now):
        with self.lock:
            ok, error = self.codex['ok'], self.codex['error']
        if error:
            fresh = ok and now - ok.get('at', 0) <= MAX_AGE
            return {'error': error, **({'at': ok['at'], 'limits': ok['limits']} if fresh else {})}
        if ok and now - ok.get('at', 0) <= MAX_AGE:
            return ok
        return None

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
                    resets = reset_cards_view(ok, now)
                    if resets:
                        agent['resets'] = resets
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
    return {'now': now, 'agents': [claude(now), *codex(now, POLLER.codex_live(now)), *POLLER.agents(now),
                                   antigravity(now)]}


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


RESET_LOCK = threading.Lock()
RESET_KEY_RE = re.compile(r'^[A-Za-z0-9-]{8,64}$')
RESET_BODY_LIMIT = 4096
# (agent, kind) the page may ask for -> function(key) returning (ok, message)
RESET_ACTIONS = {
    ('codex', 'FULL'): use_codex_reset,
    ('zcode', 'WEEK'): lambda key: use_zcode_reset('WEEK', key),
    ('zcode', 'FIVE_HOUR'): lambda key: use_zcode_reset('FIVE_HOUR', key),
}


def split_host(value):
    """'name:port' or '[v6]:port' -> lower-case name without the port."""
    value = (value or '').strip().lower()
    if value.startswith('['):
        return value[1:value.find(']')] if ']' in value else ''
    return value.rsplit(':', 1)[0] if value.count(':') == 1 else value


def trusted_host(name):
    """Names this page is really reached by. An IP address or a Tailscale name cannot be pointed at
    this machine by someone else's DNS, which is what a DNS rebinding attack needs."""
    if not name:
        return False
    try:
        ipaddress.ip_address(name)
        return True
    except ValueError:
        pass
    machine = socket.gethostname().lower()
    return name in ('localhost', machine, machine.split('.')[0]) or name.endswith('.ts.net')


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

    def do_POST(self):
        if self.path.split('?', 1)[0] != '/api/reset':
            self.reply(404, 'text/plain; charset=utf-8', b'not found\n')
            return
        status, message = self.handle_reset()
        self.reply(status, 'application/json; charset=utf-8',
                   json.dumps({'ok': status == 200, 'message': message}, ensure_ascii=False).encode())

    def handle_reset(self):
        """Use one reset, after checks that keep other web pages from doing it:
        - Host must be an address or name this machine is really reached by (no DNS rebinding).
        - Origin must be present and one of those too, and Sec-Fetch-Site, when sent, same-origin.
        - The body must be JSON, so a cross-site page needs a CORS preflight, which this server never
          answers; a plain HTML form cannot send it.
        One reset at a time; the page's idempotency key makes a retried request use nothing more."""
        origin = self.headers.get('Origin')
        if not trusted_host(split_host(self.headers.get('Host'))):
            return 403, '不接受這個 Host'
        if not origin or not trusted_host(split_host(urlsplit(origin).netloc)):
            return 403, '不接受這個來源'
        if self.headers.get('Sec-Fetch-Site') not in (None, 'same-origin'):
            return 403, '不接受跨站請求'
        if not (self.headers.get('Content-Type') or '').lower().startswith('application/json'):
            return 415, '要用 JSON'
        try:
            length = int(self.headers.get('Content-Length') or 0)
        except ValueError:
            length = -1
        if not 0 < length <= RESET_BODY_LIMIT:
            return 400, '請求大小不對'
        try:
            body = json.loads(self.rfile.read(length))
        except ValueError:
            return 400, '請求不是 JSON'
        if not isinstance(body, dict):
            return 400, '請求格式不對'
        action = RESET_ACTIONS.get((body.get('agent'), body.get('kind')))
        key = body.get('key')
        if action is None:
            return 400, '不認得這個重置'
        if not isinstance(key, str) or not RESET_KEY_RE.match(key):
            return 400, 'idempotency key 格式不對'
        if not RESET_LOCK.acquire(blocking=False):
            return 409, '另一個重置正在進行，稍等一下'
        try:
            label = f'{body["agent"]} {body["kind"]}'
            print(f'agent-usage: reset {label} requested from {self.client_address[0]}', flush=True)
            try:
                ok, message = action(key)
            except ProviderError as failure:
                ok, message = False, str(failure)
            except Exception as failure:   # answer the page whatever happens
                ok, message = False, f'重置失敗（{type(failure).__name__}）'
            print(f'agent-usage: reset {label}: {"done" if ok else "not used"} ({message})', flush=True)
        finally:
            RESET_LOCK.release()
        POLLER.poll_soon()
        return (200 if ok else 422), message

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
