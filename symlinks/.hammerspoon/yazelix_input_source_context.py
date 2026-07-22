#!/usr/bin/python3
"""Return the focused Yazelix pane and the real Helix editor mode."""

import json
import os
from pathlib import Path
import re
import socket
import subprocess
import sys
import time


BRIDGE_ROOT = Path.home() / ".local/share/yazelix/helix_bridge"
TERMINALS_BY_BUNDLE_ID = {
    "com.mitchellh.ghostty": {"ghostty"},
    "com.raphaelamorim.rio": {"mars", "rio"},
}


def process_exists(pid):
    try:
        os.kill(pid, 0)
        return True
    except (OSError, ValueError):
        return False


def query_helix(registry):
    try:
        token = Path(registry["auth_token_path"]).read_text().strip()
        socket_path = registry["transport"]["path"]
        request = {
            "schema_version": 2,
            "request_id": "hammerspoon-{}".format(time.time_ns()),
            "auth_token": token,
            "action": "helix.get_context",
            "timeout_ms": 350,
            "payload": {},
        }

        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as connection:
            connection.settimeout(0.5)
            connection.connect(socket_path)
            connection.sendall((json.dumps(request) + "\n").encode())
            response = b""
            while b"\n" not in response:
                chunk = connection.recv(65536)
                if not chunk:
                    break
                response += chunk

        decoded = json.loads(response.split(b"\n", 1)[0])
        if decoded.get("status") == "ok":
            return decoded.get("data") or {}
    except (KeyError, OSError, ValueError, json.JSONDecodeError):
        pass

    return None


def load_candidates(preferred_session=""):
    candidates = []

    if not BRIDGE_ROOT.is_dir():
        return candidates

    registry_paths = []
    if preferred_session:
        registry_paths = list((BRIDGE_ROOT / preferred_session).glob("*.json"))
    if not registry_paths:
        registry_paths = list(BRIDGE_ROOT.glob("*/*.json"))

    for registry_path in registry_paths:
        try:
            registry = json.loads(registry_path.read_text())
            pid = int(registry["pid"])
            session_name = registry["zellij_session_name"]
            pane_id = str(registry["zellij_pane_id"])
        except (KeyError, TypeError, ValueError, OSError, json.JSONDecodeError):
            continue

        if not session_name or not process_exists(pid):
            continue

        registry["_pane_id"] = pane_id
        registry["_registry_path"] = str(registry_path)
        candidates.append(registry)

    if preferred_session:
        preferred = [
            candidate
            for candidate in candidates
            if candidate.get("session_id") == preferred_session
        ]
        if preferred:
            candidates = preferred

    live_candidates = []
    for candidate in candidates:
        context = query_helix(candidate)
        if context is not None:
            candidate["_context"] = context
            live_candidates.append(candidate)

    return live_candidates


def zellij_servers():
    try:
        result = subprocess.run(
            ["/bin/ps", "-axo", "command="],
            capture_output=True,
            check=False,
            text=True,
            timeout=1,
        )
    except (OSError, subprocess.TimeoutExpired):
        return {}
    servers = {}

    for line in result.stdout.splitlines():
        match = re.match(r"^(\S*zellij) --server (\S+)$", line.strip())
        if match:
            servers[Path(match.group(2)).name] = match.group(1)

    return servers


def candidate_terminal(candidate):
    match = re.search(r"-(\d+)$", candidate.get("session_id", ""))
    if not match:
        return None

    try:
        result = subprocess.run(
            ["/bin/ps", "eww", "-p", match.group(1)],
            capture_output=True,
            check=False,
            text=True,
            timeout=0.5,
        )
    except (OSError, subprocess.TimeoutExpired):
        return None

    terminal = re.search(r"\bYAZELIX_SESSION_TERMINAL=([^\s]+)", result.stdout)
    return terminal.group(1).lower() if terminal else None


def query_panes(candidate, servers, pane_cache):
    session_name = candidate["zellij_session_name"]
    if session_name in pane_cache:
        return pane_cache[session_name]

    executable = servers.get(session_name)
    if not executable:
        pane_cache[session_name] = []
        return []

    environment = os.environ.copy()
    environment["ZELLIJ"] = "0"
    environment["ZELLIJ_SESSION_NAME"] = session_name

    try:
        result = subprocess.run(
            [
                executable,
                "action",
                "list-panes",
                "--json",
                "--tab",
                "--state",
                "--command",
            ],
            capture_output=True,
            check=False,
            env=environment,
            text=True,
            timeout=0.7,
        )
        panes = json.loads(result.stdout) if result.returncode == 0 else []
    except (OSError, subprocess.TimeoutExpired, json.JSONDecodeError):
        panes = []

    pane_cache[session_name] = panes
    return panes


def focused_terminal_pane(panes):
    focused = [
        pane
        for pane in panes
        if (
            not pane.get("is_plugin")
            and pane.get("is_focused")
            and not pane.get("exited")
        )
    ]
    floating = [pane for pane in focused if pane.get("is_floating")]

    if floating:
        return floating[-1]

    return focused[-1] if focused else None


def text_matches(title, value):
    if not value:
        return False

    value = str(value).strip().lower()
    if len(value) < 3:
        return False

    return value in title


def match_score(candidate, pane, title):
    context = candidate["_context"]
    current_file = context.get("current_file")
    cwd = context.get("cwd")
    score = 0

    if current_file:
        current_path = Path(current_file)
        if text_matches(title, current_path.name):
            score += 120
        if text_matches(title, current_path.stem):
            score += 80

    if cwd:
        cwd_path = Path(cwd)
        if text_matches(title, cwd_path.name):
            score += 50
        if text_matches(title, cwd_path.parent.name):
            score += 20

    if pane:
        if text_matches(title, pane.get("tab_name")):
            score += 70
        pane_cwd = pane.get("pane_cwd")
        if pane_cwd and text_matches(title, Path(pane_cwd).name):
            score += 40

    return score


def select_candidate(
    candidates, bundle_id, title, active_tab_title, preferred_session, servers
):
    active_session_name = active_tab_title.split("|", 1)[0].strip()
    for candidate in candidates:
        if candidate.get("zellij_session_name") == active_session_name:
            return candidate, query_panes(candidate, servers, {})

    if preferred_session:
        for candidate in candidates:
            if candidate.get("session_id") == preferred_session:
                return candidate, query_panes(candidate, servers, {})

    expected_terminals = TERMINALS_BY_BUNDLE_ID.get(bundle_id, set())
    matching_terminal = []

    for candidate in candidates:
        terminal = candidate_terminal(candidate)
        if terminal is None or terminal in expected_terminals:
            matching_terminal.append(candidate)

    pane_cache = {}
    scored = []
    normalized_title = title.lower()
    for candidate in matching_terminal:
        panes = query_panes(candidate, servers, pane_cache)
        pane = focused_terminal_pane(panes)
        scored.append((match_score(candidate, pane, normalized_title), candidate, panes))

    if not scored:
        return None, []

    scored.sort(
        key=lambda item: (item[0], int(item[1].get("started_at_unix_ms", 0))),
        reverse=True,
    )

    unique_sessions = {item[1]["zellij_session_name"] for item in scored}
    if scored[0][0] == 0 and len(unique_sessions) != 1:
        return None, []

    return scored[0][1], scored[0][2]


def pane_role(candidate, pane):
    if pane is None:
        return "other"

    title = str(pane.get("title", "")).lower()
    command = " ".join(
        str(pane.get(key, "")) for key in ("terminal_command", "pane_command")
    ).lower()

    if title == "sidebar" or "yazi" in command:
        return "sidebar"

    if str(pane.get("id")) == candidate["_pane_id"]:
        return "editor"

    if title == "editor" and ("/hx " in command or "yzx-hx" in command):
        return "editor"

    return "other"


def should_keep_english(role, mode):
    return role == "sidebar" or (role == "editor" and mode in {"normal", "select"})


def active_tab_context(candidates, active_tab_title):
    if "|" not in active_tab_title:
        return None

    session_name, pane_title = (
        part.strip() for part in active_tab_title.split("|", 1)
    )
    candidate = next(
        (
            item
            for item in candidates
            if item.get("zellij_session_name") == session_name
        ),
        None,
    )
    if candidate is None:
        return None

    normalized_pane_title = pane_title.lower()
    if normalized_pane_title == "editor":
        role = "editor"
    elif normalized_pane_title == "sidebar":
        role = "sidebar"
    else:
        role = "other"

    mode = candidate["_context"].get("mode") if role == "editor" else None
    return candidate, role, mode


def print_state(candidate, role, mode):
    print(
        json.dumps(
            {
                "status": "ok",
                "session_id": candidate["session_id"],
                "focus": role,
                "mode": mode,
                "keep_english": should_keep_english(role, mode),
            }
        )
    )


def main():
    bundle_id = sys.argv[1] if len(sys.argv) > 1 else ""
    title = sys.argv[2] if len(sys.argv) > 2 else ""
    active_tab_title = sys.argv[3] if len(sys.argv) > 3 else ""
    preferred_session = sys.argv[4] if len(sys.argv) > 4 else ""
    candidates = load_candidates(preferred_session)
    tab_context = active_tab_context(candidates, active_tab_title)

    if tab_context is not None:
        print_state(*tab_context)
        return 0

    servers = zellij_servers()
    candidate, panes = select_candidate(
        candidates,
        bundle_id,
        title,
        active_tab_title,
        preferred_session,
        servers,
    )

    if candidate is None:
        print(json.dumps({"status": "unavailable"}))
        return 0

    pane = focused_terminal_pane(panes)
    role = pane_role(candidate, pane)
    mode = candidate["_context"].get("mode") if role == "editor" else None
    print_state(candidate, role, mode)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
