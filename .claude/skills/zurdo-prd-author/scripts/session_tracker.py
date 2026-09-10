#!/usr/bin/env python3
"""Persist a zurdo-prd-author grill session across turns.

A grill spans many turns; this tracker stores the question/answer trail so the
interview can resume and end with a "decisions locked" summary. State lives
repo-local under `<repo>/.zurdo/authoring/<session>.json` (matching zurdo's
repo-local state model), or anywhere via `--session-file`.

Stdlib-only and deterministic: ordering is by an incrementing integer index,
never wall-clock, so output is stable and tests are not time-sensitive.

Usage:
    session_tracker.py --action start  [--session NAME] [--session-file PATH] [--topic TEXT]
    session_tracker.py --action record [--session NAME] [--session-file PATH]
                       --question TEXT --answer TEXT [--kind KIND] [--branch-id ID]
    session_tracker.py --action show   [--session NAME] [--session-file PATH] [--output text|json]
    session_tracker.py --action lock   [--session NAME] [--session-file PATH] [--output text|json]
    session_tracker.py --action list   [--session-file PATH] [--output text|json]
    session_tracker.py --self-check

Exit codes:
    0 success / self-check passed
    1 self-check failed
    2 usage error
    3 state error (missing session for record/show/lock)

On-disk schema (stable):
    {
      "schema": 1,
      "session": "default",
      "topic": "...",
      "locked": false,
      "next_index": 3,
      "decisions": [
        {"index": 1, "branch_id": null, "kind": "intent",
         "question": "...", "answer": "..."}
      ]
    }
"""

import json
import os
import sys

SCHEMA = 1


def _find_repo_root(start):
    cur = os.path.abspath(start)
    while True:
        if os.path.isdir(os.path.join(cur, ".git")) or os.path.isdir(
            os.path.join(cur, ".zurdo")
        ):
            return cur
        parent = os.path.dirname(cur)
        if parent == cur:
            return os.path.abspath(start)
        cur = parent


def _session_path(session, session_file):
    if session_file:
        return os.path.abspath(session_file)
    root = _find_repo_root(os.getcwd())
    return os.path.join(root, ".zurdo", "authoring", f"{session}.json")


def _load(path):
    with open(path, "r", encoding="utf-8") as fh:
        return json.load(fh)


def _save(path, state):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as fh:
        json.dump(state, fh, indent=2, ensure_ascii=False)
        fh.write("\n")
    os.replace(tmp, path)


def _new_state(session, topic):
    return {
        "schema": SCHEMA,
        "session": session,
        "topic": topic or "",
        "locked": False,
        "next_index": 1,
        "decisions": [],
    }


def _render_show(state):
    out = [
        f"session: {state['session']}"
        + (f"  (topic: {state['topic']})" if state.get("topic") else ""),
        f"locked: {state['locked']}   decisions: {len(state['decisions'])}",
    ]
    for d in state["decisions"]:
        out.append(f"  #{d['index']} [{d.get('kind') or '-'}] Q: {d['question']}")
        out.append(f"        A: {d['answer']}")
    return "\n".join(out)


def _render_lock(state):
    out = [f"Decisions locked for session '{state['session']}':"]
    if not state["decisions"]:
        out.append("  (none recorded)")
    for d in state["decisions"]:
        out.append(f"  - {d['question']}  =>  {d['answer']}")
    return "\n".join(out)


def _emit(payload, output, text_renderer):
    if output == "json":
        print(json.dumps(payload, indent=2, ensure_ascii=False))
    else:
        print(text_renderer(payload))


def _opt(args, name):
    if name in args:
        i = args.index(name)
        if i + 1 < len(args):
            val = args[i + 1]
            del args[i : i + 2]
            return val
        del args[i : i + 1]
    return None


def _self_check():
    import tempfile

    with tempfile.TemporaryDirectory() as td:
        path = os.path.join(td, "s.json")
        if main(["--action", "start", "--session-file", path, "--topic", "demo"]) != 0:
            print("self-check FAILED: start", file=sys.stderr)
            return 1
        rc = main(
            [
                "--action", "record", "--session-file", path,
                "--question", "what proves it?", "--answer", "a shell test",
                "--kind", "intent",
            ]
        )
        if rc != 0:
            print("self-check FAILED: record", file=sys.stderr)
            return 1
        state = _load(path)
        if state["next_index"] != 2 or len(state["decisions"]) != 1:
            print("self-check FAILED: record did not advance index", file=sys.stderr)
            return 1
        if main(["--action", "lock", "--session-file", path]) != 0:
            print("self-check FAILED: lock", file=sys.stderr)
            return 1
        if not _load(path)["locked"]:
            print("self-check FAILED: lock flag not set", file=sys.stderr)
            return 1
    print("self-check OK")
    return 0


def main(argv):
    args = list(argv)
    if "--self-check" in args:
        return _self_check()

    action = _opt(args, "--action")
    session = _opt(args, "--session") or "default"
    session_file = _opt(args, "--session-file")
    output = _opt(args, "--output") or "text"
    topic = _opt(args, "--topic")
    question = _opt(args, "--question")
    answer = _opt(args, "--answer")
    kind = _opt(args, "--kind")
    branch_id = _opt(args, "--branch-id")

    if action is None:
        print("error: --action is required (start|record|show|lock|list)", file=sys.stderr)
        return 2
    if output not in ("text", "json"):
        print(f"error: unknown --output {output!r}", file=sys.stderr)
        return 2

    path = _session_path(session, session_file)

    if action == "list":
        directory = (
            os.path.dirname(path)
            if session_file
            else os.path.join(_find_repo_root(os.getcwd()), ".zurdo", "authoring")
        )
        names = []
        if os.path.isdir(directory):
            names = sorted(
                f[:-5] for f in os.listdir(directory) if f.endswith(".json")
            )
        if output == "json":
            print(json.dumps({"sessions": names, "dir": directory}, indent=2))
        else:
            print(f"sessions in {directory}:")
            for n in names:
                print(f"  {n}")
            if not names:
                print("  (none)")
        return 0

    if action == "start":
        state = _new_state(session, topic)
        _save(path, state)
        if output == "json":
            print(json.dumps({"created": path, "session": session}, indent=2))
        else:
            print(f"started session '{session}' at {path}")
        return 0

    # record / show / lock all require an existing session.
    if not os.path.isfile(path):
        print(f"error: no session at {path} (run --action start first)", file=sys.stderr)
        return 3
    state = _load(path)

    if action == "record":
        if not question or answer is None:
            print("error: record needs --question and --answer", file=sys.stderr)
            return 2
        idx = state["next_index"]
        state["decisions"].append(
            {
                "index": idx,
                "branch_id": branch_id,
                "kind": kind,
                "question": question,
                "answer": answer,
            }
        )
        state["next_index"] = idx + 1
        _save(path, state)
        if output == "json":
            print(json.dumps({"recorded": idx, "total": len(state["decisions"])}, indent=2))
        else:
            print(f"recorded decision #{idx} (total {len(state['decisions'])})")
        return 0

    if action == "show":
        _emit(state, output, _render_show)
        return 0

    if action == "lock":
        state["locked"] = True
        _save(path, state)
        if output == "json":
            print(json.dumps(state, indent=2, ensure_ascii=False))
        else:
            print(_render_lock(state))
        return 0

    print(f"error: unknown --action {action!r}", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
