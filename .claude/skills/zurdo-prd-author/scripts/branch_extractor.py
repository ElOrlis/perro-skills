#!/usr/bin/env python3
"""Extract decision branches from a freeform intent/design document.

This is the PRE-PRD half of the zurdo-prd-author interview: before any §2.2
grammar exists, scan an intent doc for the decisions a PRD author must resolve
out loud. Grammar/validation is NEVER done here — once a draft PRD exists, that
job belongs to `zurdo analyze --static-only`. This script only
finds the branches worth grilling.

Stdlib-only, deterministic (no clocks, no randomness, stable ordering).

Usage:
    branch_extractor.py [INPUT.md] [--output text|json] [--self-check]

    INPUT.md       Path to an intent/design doc. Reads stdin when omitted and
                   stdin is not a TTY. Falls back to an embedded sample when no
                   input is available, so the script always produces output.
    --output       `text` (default) or `json`.
    --self-check   Run the embedded sample, assert the extractor still finds the
                   expected branch kinds, and exit 0 (pass) or 1 (fail).

Exit codes:
    0  success (or self-check passed)
    1  self-check failed
    2  usage error (bad flag, unreadable input)

JSON contract (stable):
    {
      "branches": [
        {"id": "b1", "kind": "choice", "text": "...", "source_line": 12}
      ],
      "count": 1,
      "kinds": {"choice": 1, ...}
    }

Branch kinds (closed enum):
    intent      a stated goal / "we want X"
    choice      an either/or, options, "vs", "or"
    tradeoff    a cost/benefit tension ("but", "however", "at the cost of")
    dependency  an ordering / "before", "after", "depends on", "requires"
    open        an unresolved gap ("TBD", "TODO", "?", "not sure", "open question")
    question    an explicit question (line ends with "?")
"""

import json
import re
import sys

KINDS = ("intent", "choice", "tradeoff", "dependency", "open", "question")

# Ordered most-specific-first: the first matching rule wins so a line like
# "should we do A or B before shipping?" classifies as `question`, not `choice`.
_RULES = (
    ("question", re.compile(r"\?\s*$")),
    ("open", re.compile(r"\b(tbd|todo|fixme|open question|not sure|unclear|undecided)\b", re.I)),
    ("dependency", re.compile(r"\b(depends on|requires|blocked by|before|after|once|prerequisite)\b", re.I)),
    ("tradeoff", re.compile(r"\b(but|however|trade-?off|at the cost of|versus|downside|risk)\b", re.I)),
    ("choice", re.compile(r"\b(either|or|vs\.?|option|choose|whether|alternativ)\b", re.I)),
    ("intent", re.compile(r"\b(we want|we need|goal is|should|must|the aim|build|add|implement|support)\b", re.I)),
)

_SAMPLE = """\
# Intent: notification service

We want a service that sends users an email when their export finishes.
It must support both transactional and digest modes.

Should we batch digests hourly or daily?
Either we store the outbox in Postgres or we add a dedicated queue.
We could use SES or a self-hosted SMTP relay - undecided.
The digest job depends on the export pipeline writing a completion marker.
Real-time mode is nice but it risks hammering the mail provider.
TODO: decide retention for delivered-notification records.
"""


def _classify(line):
    for kind, rule in _RULES:
        if rule.search(line):
            return kind
    return None


def extract(text):
    """Return a list of branch dicts in stable source order."""
    branches = []
    bn = 0
    for idx, raw in enumerate(text.splitlines(), start=1):
        line = raw.strip()
        if not line or line.startswith("#") or line.startswith("```"):
            continue
        # Strip leading list markers so "- we want X" classifies like prose.
        stripped = re.sub(r"^([*+-]|\d+[.)])\s+", "", line)
        kind = _classify(stripped)
        if kind is None:
            continue
        bn += 1
        branches.append(
            {"id": f"b{bn}", "kind": kind, "text": stripped, "source_line": idx}
        )
    return branches


def _result(branches):
    kinds = {}
    for b in branches:
        kinds[b["kind"]] = kinds.get(b["kind"], 0) + 1
    return {"branches": branches, "count": len(branches), "kinds": kinds}


def _render_text(result):
    lines = [f"{result['count']} decision branch(es) found:"]
    for b in result["branches"]:
        lines.append(f"  [{b['kind']:<10}] L{b['source_line']}: {b['text']}")
    return "\n".join(lines)


def _self_check():
    result = _result(extract(_SAMPLE))
    found = result["kinds"]
    expected = {"question", "open", "dependency", "tradeoff", "choice", "intent"}
    missing = expected - set(found)
    if missing:
        print(f"self-check FAILED: missing kinds {sorted(missing)}", file=sys.stderr)
        return 1
    if result["count"] < len(expected):
        print(f"self-check FAILED: too few branches ({result['count']})", file=sys.stderr)
        return 1
    print("self-check OK")
    return 0


def main(argv):
    args = list(argv)
    output = "text"
    if "--self-check" in args:
        return _self_check()
    if "--output" in args:
        i = args.index("--output")
        try:
            output = args[i + 1]
        except IndexError:
            print("error: --output needs a value (text|json)", file=sys.stderr)
            return 2
        del args[i : i + 2]
    if output not in ("text", "json"):
        print(f"error: unknown --output {output!r}", file=sys.stderr)
        return 2

    positional = [a for a in args if not a.startswith("--")]
    if positional:
        try:
            with open(positional[0], "r", encoding="utf-8") as fh:
                text = fh.read()
        except OSError as exc:
            print(f"error: cannot read {positional[0]}: {exc}", file=sys.stderr)
            return 2
    elif not sys.stdin.isatty():
        text = sys.stdin.read()
    else:
        text = _SAMPLE

    result = _result(extract(text))
    if output == "json":
        print(json.dumps(result, indent=2, ensure_ascii=False))
    else:
        print(_render_text(result))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
