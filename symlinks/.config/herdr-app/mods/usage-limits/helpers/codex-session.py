"""Read only the identified Codex session. No credentials, prompts or RPC calls.

Exit 0: numeric session line; 1: no reading; 2: JSON session choices.
Optional arguments: explicitly selected thread ID and the terminal's process identity.
An empty identity is reserved for a binding already checked by the calling mod.
"""
import json
import os
from pathlib import Path
import re
import sqlite3
import subprocess
import sys
from datetime import datetime

THREAD_ID = re.compile(r"[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}\Z")


class SessionPending(Exception):
    """An exact writer exists, but its new rollout has not been published yet."""


def command(*args):
    try:
        return subprocess.run(args, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                              timeout=2, env={**os.environ, "LC_ALL": "C"}).stdout
    except (OSError, subprocess.TimeoutExpired):
        return b""


def names(output):
    # lsof under the C locale escapes non-ASCII bytes and literal backslashes.
    for line in output.splitlines():
        if not line.startswith(b"n"):
            continue
        path = re.sub(rb"\\(\\|x[0-9a-fA-F]{2})",
                      lambda m: b"\\" if m[1] == b"\\" else bytes([int(m[1][1:], 16)]), line[1:])
        yield Path(os.fsdecode(path))


def database(home):
    root = Path(os.environ.get("CODEX_SQLITE_HOME") or home)
    files = [p for p in root.glob("state_*.sqlite") if re.fullmatch(r"state_[0-9]+", p.stem)]
    if not files:
        return None
    path = max(files, key=lambda p: int(p.stem.split("_")[-1]))
    return sqlite3.connect(path.resolve().as_uri() + "?mode=ro", uri=True, timeout=1)


def lookup(db, thread_id):
    if db is None or not THREAD_ID.fullmatch(thread_id):
        return None
    row = db.execute("SELECT rollout_path FROM threads WHERE id = ?", (thread_id,)).fetchone()
    if row:
        path = Path(row[0])
        if path.name.endswith(f"-{thread_id}.jsonl") and path.is_file():
            return path
    return None


def is_subagent(db, thread_id, path=None):
    source = None
    if db is not None:
        row = db.execute("SELECT source FROM threads WHERE id = ?", (thread_id,)).fetchone()
        if row:
            source = row[0]
            try:
                source = json.loads(source)
            except (ValueError, TypeError):
                pass  # top-level sources such as cli and vscode are plain strings
    if source is None and path is not None:
        try:
            with path.open(encoding="utf-8") as file:
                record = json.loads(file.readline())
            if isinstance(record, dict) and record.get("type") == "session_meta":
                payload = record.get("payload")
                if isinstance(payload, dict):
                    source = payload.get("source")
        except (OSError, ValueError, UnicodeError):
            pass
    return isinstance(source, dict) and "subagent" in source


def locate(pid, db):
    # Embedded servers live in the TUI itself; older versions used a child server.
    children = command("pgrep", "-P", pid).decode().split()
    for owner in [pid, *filter(str.isdigit, children)]:
        paths = list(names(command("lsof", "-nP", "-Fn", "-p", owner)))
        files = [p for p in paths if p.name.startswith("rollout-") and p.suffix == ".jsonl" and "sessions" in p.parts and p.is_file()]
        files = [p for p in files if not is_subagent(db, p.stem[-36:], p)]
        locks = {p.stem for p in paths if p.parent.name == "thread-writer-locks" and THREAD_ID.fullmatch(p.stem)
                 and not is_subagent(db, p.stem, next((f for f in paths if f.suffix == ".jsonl" and f.stem.endswith(p.stem)), None))}
        if len(locks) == 1:
            thread_id = next(iter(locks))
            file = lookup(db, thread_id)
            if file:
                return file
            # The SQLite row can lag behind creation of the rollout.
            matching = [p for p in paths if p.name.endswith(f"-{thread_id}.jsonl") and p.is_file()]
            if len(matching) == 1:
                return matching[0]
            raise SessionPending
        if len(locks) > 1:
            return None
        if files:
            return files[0] if len(files) == 1 else None
    return None


def read_usage(path):
    tokens = window = calls = compactions = legacy_compactions = 0
    turns = set()
    with path.open(encoding="utf-8") as file:
        for line in file:
            try:
                record = json.loads(line)
            except (ValueError, UnicodeError):
                continue  # includes a last line still being written
            if not isinstance(record, dict):
                continue
            kind = record.get("type")
            if kind == "compacted":
                compactions += 1
                tokens = 0  # old context no longer describes this conversation
            payload = record.get("payload")
            if kind != "event_msg" or not isinstance(payload, dict):
                continue
            event = payload.get("type")
            if event in ("task_started", "turn_started"):
                turn = payload.get("turn_id")
                if not isinstance(turn, str) or turn not in turns:
                    calls += 1
                if isinstance(turn, str):
                    turns.add(turn)
            elif event == "context_compacted":
                legacy_compactions += 1
                tokens = 0
            elif event == "token_count":
                info = payload.get("info")
                if not isinstance(info, dict):
                    continue
                usage = info.get("last_token_usage")
                if not isinstance(usage, dict):
                    continue
                n = usage.get("total_tokens")
                if type(n) is int and n > 0:
                    tokens = n
                    w = info.get("model_context_window")
                    window = w if type(w) is int and w > 0 else 0
    if not tokens:
        return 1
    # Some legacy logs also emit context_compacted for the same canonical record.
    print(f"tokens={tokens} window={window} calls={calls} compactions={compactions or legacy_compactions}")
    return 0


def main():
    pid, selected, expected_identity = sys.argv[1:4]
    if not pid.isdigit():
        return 1
    home = Path(os.environ.get("CODEX_HOME") or Path.home() / ".codex")
    db = database(home)
    try:
        path = locate(pid, db)
        if path:
            return read_usage(path)
        identity = os.environ.get("HERDR_USAGE_PROC_IDENTITY") or command("ps", "-o", "lstart=", "-p", pid).decode().strip()
        matches_identity = not expected_identity or expected_identity == identity
        if expected_identity.startswith("started:") and expected_identity[8:].isdigit():
            try:
                started_ms = int(datetime.strptime(identity, "%a %b %d %H:%M:%S %Y").timestamp() * 1000)
                matches_identity = started_ms == int(expected_identity[8:])
            except ValueError:
                matches_identity = False
        if selected and identity and matches_identity:
            path = lookup(db, selected)
            if path:
                return read_usage(path)
        cwd = os.environ.get("HERDR_USAGE_PROC_CWD")
        if not cwd:
            try:
                cwd = os.readlink(f"/proc/{pid}/cwd")
            except OSError:
                cwd = next((str(p) for p in names(command("lsof", "-w", "-a", "-d", "cwd", "-p", pid, "-Fn"))), "")
        if not identity or not cwd or db is None:
            return 1
        choices = []
        for thread_id, title in db.execute("SELECT id, title FROM threads WHERE cwd = ? AND archived = 0 ORDER BY updated_at DESC LIMIT 12", (cwd,)):
            if not is_subagent(db, thread_id) and lookup(db, thread_id):
                choices.append({"id": thread_id, "title": str(title)[:100]})
        if not choices:
            return 1
        print(json.dumps({"pid": int(pid), "identity": identity, "choices": choices}))
        return 2
    finally:
        if db is not None:
            db.close()


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, sqlite3.Error, ValueError, SessionPending):
        sys.exit(1)

