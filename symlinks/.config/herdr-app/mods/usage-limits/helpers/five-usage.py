"""Read-only account usage queries; stdout contains sanitized quota data only."""
import concurrent.futures
import datetime
import json
import math
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time
import urllib.error
import urllib.request

ZCODE_HELPER = None


def read_json(path):
    try:
        if path.stat().st_size > 2 * 1024 * 1024:
            return {}
        value = json.loads(path.read_text())
        return value if isinstance(value, dict) else {}
    except (OSError, ValueError):
        return {}


def number(value):
    if isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value):
        return value
    return None


def timestamp(value):
    numeric = number(value)
    if numeric is not None:
        return numeric / 1000 if numeric > 100_000_000_000 else numeric
    if isinstance(value, str):
        try:
            return datetime.datetime.fromisoformat(value.replace('Z', '+00:00')).timestamp()
        except ValueError:
            pass
    return None


def quota(label, used, reset=None, unlimited=False):
    used = number(used)
    if used is None and not unlimited:
        return None
    return {'label': label, 'used': max(0, min(100, used or 0)),
            'reset': timestamp(reset), 'unlimited': unlimited}


def ready(limits, at=None, plan=None):
    limits = [value for value in limits if value is not None]
    if not limits:
        return {'state': 'no_quota'}
    return {'state': 'ready', 'limits': limits, 'updatedAt': at or time.time(),
            'plan': plan if isinstance(plan, str) else None}


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def get_json(url, token, bearer=False):
    # Fixed vendor URLs only. Never forward an Authorization header on redirects.
    headers = {'Accept': 'application/json', 'User-Agent': 'HerdrUsage/1.0',
               'Authorization': ('Bearer ' if bearer else '') + token}
    request = urllib.request.Request(url, headers=headers)
    opener = urllib.request.build_opener(NoRedirect)
    with opener.open(request, timeout=8) as response:
        raw = response.read(1024 * 1024 + 1)
        if len(raw) > 1024 * 1024:
            raise ValueError('oversized quota response')
        return json.loads(raw)


def claude(root):
    data = read_json(root / '.cache/over9k/usage/claude.json')
    if data.get('api') or data.get('bedrock'):
        return {'state': 'api_billing'}
    limits = []
    for key, label in [('five_hour', '5h'), ('seven_day', '7d')]:
        value = data.get(key)
        if isinstance(value, dict):
            limits.append(quota(label, value.get('used_percentage'), value.get('resets_at')))
    if not limits:
        return {'state': 'waiting'}
    account = read_json(root / '.claude.json').get('oauthAccount', {})
    return ready(limits, timestamp(data.get('at')), account.get('planDisplayName'))


def codex(root):
    files = list((root / '.codex/sessions').glob('*/*/*/*.jsonl'))
    files.sort(key=lambda path: path.stat().st_mtime, reverse=True)
    for path in files[:10]:
        with path.open('rb') as stream:
            stream.seek(max(0, path.stat().st_size - 2 * 1024 * 1024))
            lines = stream.read().splitlines()
        for line in reversed(lines):
            if b'"rate_limits"' not in line:
                continue
            try:
                event = json.loads(line)
            except ValueError:
                continue
            payload = event.get('payload', {})
            data = payload.get('rate_limits') or event.get('rate_limits')
            if not isinstance(data, dict):
                continue
            limits = []
            for key in ['primary', 'secondary']:
                window = data.get(key)
                if not isinstance(window, dict):
                    continue
                minutes = number(window.get('window_minutes'))
                label = 'Limit'
                if minutes:
                    label = f'{minutes / 1440:g}d' if minutes % 1440 == 0 else f'{minutes / 60:g}h'
                limits.append(quota(label, window.get('used_percent'), window.get('resets_at')))
            result = ready(limits, timestamp(event.get('timestamp')) or path.stat().st_mtime,
                           data.get('plan_type'))
            if result['state'] == 'ready':
                return result
    return {'state': 'waiting'}


def parse_zcode(data):
    if data.get('code') in (401, 403, '401', '403'):
        return {'state': 'quota_auth_failed', 'httpStatus': int(data['code'])}
    if data.get('success') is False or data.get('code') not in (None, 0, '0', 200):
        return {'state': 'unavailable'}
    body = data.get('data') or {}
    limits = []
    for value in body.get('limits') or []:
        if value.get('type') not in ('TOKENS_LIMIT', 'CREDIT_LIMIT'):
            continue
        label = None
        if value.get('unit') == 3 and value.get('number') == 5:
            label = '5h'
        elif value.get('unit') == 6:
            label = '7d'
        if label:
            limits.append(quota(label, value.get('percentage'), value.get('nextResetTime')))
    return ready(limits, plan=body.get('level'))


def zcode(root):
    config = read_json(root / '.zcode/v2/provider_config.json')
    provider = config.get('config', {}).get('defaultModelSelection', {}).get('providerId', '')
    if not provider:
        return {'state': 'missing'}
    if 'zai-' not in provider:
        return {'state': 'unsupported_provider'}
    helper = ZCODE_HELPER
    if not helper:
        return {'state': 'quota_credential_unavailable'}
    # Prefer the Node used by this machine's existing ZCode launcher.
    pinned = root / '.nvm/versions/node/v24.14.0/bin/node'
    node = str(pinned) if pinned.is_file() else shutil.which('node')
    if not node:
        return {'state': 'quota_credential_unavailable'}
    result = subprocess.run([node, '-e', helper, '--', '--run-usage'],
                            capture_output=True, text=True, timeout=12)
    data = json.loads(result.stdout)
    if data.get('state'):
        allowed = {'missing', 'unsupported_provider', 'quota_credential_unavailable',
                   'ambiguous_account', 'quota_auth_failed', 'unavailable'}
        state = data['state'] if data['state'] in allowed else 'unavailable'
        output = {'state': state}
        if number(data.get('httpStatus')) is not None:
            output['httpStatus'] = data['httpStatus']
        return output
    return parse_zcode(data)


def parse_minimax(data):
    if data.get('base_resp', {}).get('status_code') not in (None, 0):
        return {'state': 'unavailable'}
    values = data.get('model_remains') or []
    if not values:
        return {'state': 'no_quota'}
    value = values[0]
    limits = []
    for kind, label, reset in [('interval', '5h', 'end_time'), ('weekly', '7d', 'weekly_end_time')]:
        prefix = f'current_{kind}'
        unlimited = value.get(f'{prefix}_status') == 3
        remaining = number(value.get(f'{prefix}_remaining_percent'))
        total = number(value.get(f'{prefix}_total_count'))
        legacy_remaining = number(value.get(f'{prefix}_usage_count'))
        if remaining is None and total and legacy_remaining is not None:
            remaining = 100 * legacy_remaining / total
        used = 100 - remaining if remaining is not None else None
        limits.append(quota(label, used, value.get(reset), unlimited))
    return ready(limits)


def minimax(root):
    base = root / '.minimax'
    configured = os.environ.get('MINIMAX_DATA_DIR') or os.environ.get('MAVIS_DATA_DIR')
    if configured:
        base = Path(configured).expanduser()
    candidates = []
    for region in ['en', 'cn']:
        folder = base / f'auth/prod/{region}/mcode-public'
        state = read_json(folder / 'auth-state.json')
        if state.get('status') == 'authenticated':
            candidates.append((folder, state, region))
    if len(candidates) != 1:
        return {'state': 'login' if base.exists() else 'missing'}
    folder, state, region = candidates[0]
    records = read_json(folder / 'auth.json').get('records', {})
    tokens = [record for record in records.values()
              if isinstance(record, dict) and record.get('clientId') == state.get('clientId')
              and record.get('generation') == state.get('generation')
              and record.get('accessToken')]
    if len(tokens) != 1:
        return {'state': 'login'}
    token = tokens[0]
    expiry = timestamp(token.get('expiresAtMs')) or timestamp(state.get('expiresAtMs'))
    if not expiry or expiry <= time.time():
        return {'state': 'login_expired'}
    origin = 'https://platform.minimax.io'
    if region == 'cn':
        origin = 'https://www.minimaxi.com'
    data = get_json(origin + '/v1/api/openplatform/coding_plan/remains', token['accessToken'], True)
    return parse_minimax(data)


def gemini(root):
    data = read_json(root / '.cache/over9k/usage/antigravity.json')
    at = timestamp(data.get('at'))
    limits = []
    for key, label in [('gemini-5h', '5h'), ('gemini-weekly', '7d'),
                       ('3p-5h', '3P 5h'), ('3p-weekly', '3P 7d')]:
        value = (data.get('quota') or {}).get(key)
        if not isinstance(value, dict):
            continue
        remaining = number(value.get('remaining_fraction'))
        reset = timestamp(value.get('reset_time'))
        if not reset and at and number(value.get('reset_in_seconds')) is not None:
            reset = at + value['reset_in_seconds']
        if remaining is not None:
            limits.append(quota(label, (1 - remaining) * 100, reset))
    if not limits:
        return {'state': 'waiting'}
    return ready(limits, at, data.get('plan'))


def collect(root=None):
    root = root or Path.home()
    readers = {'codex': codex, 'claude': claude, 'zcode': zcode,
               'minimax': minimax, 'gemini': gemini}
    if len(sys.argv) > 2:
        requested = set(sys.argv[2].split(','))
        readers = {key: reader for key, reader in readers.items() if key in requested}
    def run(item):
        name, reader = item
        try:
            result = reader(root)
        except urllib.error.HTTPError as error:
            state = 'quota_auth_failed' if error.code in (401, 403) else 'unavailable'
            result = {'state': state, 'httpStatus': error.code}
        except Exception:
            # No exception messages or response bodies: they can contain credentials.
            result = {'state': 'unavailable'}
        return name, result
    with concurrent.futures.ThreadPoolExecutor(max_workers=5) as pool:
        return {'at': time.time(), 'providers': dict(pool.map(run, readers.items()))}


if __name__ == '__main__':
    if len(sys.argv) > 1:
        ZCODE_HELPER = sys.argv[1]
    else:
        helper_path = Path(__file__).with_name('zcode-usage.cjs')
        if helper_path.is_file():
            ZCODE_HELPER = helper_path.read_text()
    print(json.dumps(collect(), separators=(',', ':'), allow_nan=False))
