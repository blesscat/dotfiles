"""Read or redeem an existing free reset credit through Codex's native RPC.

Only explicit 'consume' performs a redemption. No purchase or model request.
"""
import hashlib
import json
import os
import selectors
import shutil
import subprocess
import sys
import time


class Rpc:
    def __init__(self, binary):
        self.process = subprocess.Popen([binary, 'app-server'], stdin=subprocess.PIPE,
                                        stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
        self.selector = selectors.DefaultSelector()
        self.selector.register(self.process.stdout, selectors.EVENT_READ)
        self.buffer = b''

    def send(self, value):
        self.process.stdin.write((json.dumps(value) + '\n').encode())
        self.process.stdin.flush()

    def request(self, identifier, method, params):
        self.send({'jsonrpc': '2.0', 'id': identifier, 'method': method, 'params': params})
        deadline = time.monotonic() + 10
        while time.monotonic() < deadline:
            while b'\n' in self.buffer:
                line, self.buffer = self.buffer.split(b'\n', 1)
                try:
                    value = json.loads(line)
                except ValueError:
                    continue
                if value.get('id') == identifier:
                    if 'error' in value:
                        raise ValueError('rpc_failed')
                    return value.get('result', {})
            if not self.selector.select(max(0, deadline - time.monotonic())):
                break
            data = os.read(self.process.stdout.fileno(), 65536)
            if not data or len(self.buffer) + len(data) > 2 * 1024 * 1024:
                break
            self.buffer += data
        raise TimeoutError('rpc_timeout')

    def close(self):
        self.selector.close()
        self.process.stdin.close()
        try:
            self.process.wait(timeout=1)
        except subprocess.TimeoutExpired:
            self.process.terminate()
            try:
                self.process.wait(timeout=1)
            except subprocess.TimeoutExpired:
                self.process.kill()
                self.process.wait()


def account_key(result):
    identity = result.get('accountId')
    if not isinstance(identity, str) or not identity:
        return None
    return hashlib.sha256(identity.encode()).hexdigest()


def status_from(result):
    summary = result.get('rateLimitResetCredits') or {}
    credits = []
    for credit in summary.get('credits') or []:
        if credit.get('status') != 'available' or credit.get('resetType') != 'codexRateLimits':
            continue
        expiry = credit.get('expiresAt')
        if expiry is not None and expiry <= time.time():
            continue
        identifier = credit.get('id')
        if not isinstance(identifier, str) or not identifier:
            continue
        credits.append({'id': identifier, 'expiresAt': expiry,
                        'title': str(credit.get('title') or 'Codex 重置券')[:100],
                        'description': str(credit.get('description') or '')[:240]})
    credits.sort(key=lambda item: item['expiresAt'] or float('inf'))
    return {'state': 'ready', 'accountKey': account_key(result),
            'availableCount': summary.get('availableCount', 0), 'credits': credits}


def perform(mode, payload, rpc):
    rpc.request(1, 'initialize', {'clientInfo': {'name': 'herdr-usage-limits', 'version': '1.0'},
                                  'capabilities': {'experimentalApi': True}})
    rpc.send({'jsonrpc': '2.0', 'method': 'initialized'})
    current = rpc.request(2, 'account/rateLimits/read', {})
    status = status_from(current)
    if mode == 'status':
        return status
    if mode != 'consume':
        return {'state': 'error', 'code': 'invalid_action'}
    if not status['accountKey'] or status['accountKey'] != payload.get('accountKey'):
        return {'state': 'error', 'code': 'account_changed'}
    nonce, credit_id = payload.get('idempotencyKey'), payload.get('creditId')
    if not isinstance(nonce, str) or not 8 <= len(nonce) <= 64 or not isinstance(credit_id, str):
        return {'state': 'error', 'code': 'invalid_request'}
    available = any(credit['id'] == credit_id for credit in status['credits'])
    if not available and payload.get('retry') is not True:
        return {'state': 'error', 'code': 'credit_unavailable'}
    reply = rpc.request(3, 'account/rateLimitResetCredit/consume',
                        {'creditId': credit_id, 'idempotencyKey': nonce})
    outcome = reply.get('outcome')
    if outcome not in {'reset', 'alreadyRedeemed', 'noCredit', 'nothingToReset'}:
        return {'state': 'error', 'code': 'unknown_result'}
    return {'state': 'complete', 'outcome': outcome}


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else 'status'
    payload = json.loads(sys.argv[2]) if len(sys.argv) > 2 else {}
    binary = os.environ.get('HERDR_USAGE_CODEX_BIN') or shutil.which('codex')
    if not binary:
        return {'state': 'error', 'code': 'not_installed'}
    rpc = Rpc(binary)
    try:
        return perform(mode, payload, rpc)
    finally:
        rpc.close()


if __name__ == '__main__':
    try:
        result = main()
    except Exception:
        # Never forward RPC error bodies, logs or credentials.
        result = {'state': 'error', 'code': 'request_failed'}
    print(json.dumps(result, separators=(',', ':')))
