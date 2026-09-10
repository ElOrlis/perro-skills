#!/usr/bin/env python3
"""Turn extracted decision branches into ordered forcing questions.

Consumes the JSON emitted by `branch_extractor.py` and produces one forcing
question per branch, each carrying a recommended-answer template (per the
grill-me rule: never ask a bare "what do you think?"). Questions are ordered
dependency-first so a branch that gates others is resolved before them.

Stdlib-only, deterministic.

Usage:
    question_generator.py [BRANCHES.json] [--output text|json] [--self-check]

    BRANCHES.json  Path to branch_extractor JSON. Reads stdin when omitted and
                   stdin is not a TTY. Falls back to an embedded sample.
    --output       `text` (default) or `json`.
    --self-check   Generate from the embedded sample and assert invariants.

Exit codes:
    0 success / self-check passed
    1 self-check failed
    2 usage error (bad flag, unreadable/invalid input)

JSON contract (stable):
    {
      "questions": [
        {"branch_id": "b1", "order": 1, "kind": "dependency",
         "question": "...", "recommended": "..."}
      ],
      "count": 1
    }
"""

import json
import sys

# Lower number == asked earlier. Dependencies first (they gate other work),
# then intent (scope), then the forks, then loose ends.
_KIND_PRIORITY = {
    "dependency": 0,
    "intent": 1,
    "choice": 2,
    "tradeoff": 3,
    "open": 4,
    "question": 5,
}

_TEMPLATES = {
    "dependency": (
        'This implies an ordering: "{text}". Which task must finish first, '
        "and should that be a hard `Depends-on` edge or just source order?",
        "Make it a `Depends-on` edge only if the later task literally cannot "
        "start until the earlier task's artifact (file/endpoint/schema) exists.",
    ),
    "intent": (
        'Stated goal: "{text}". What observable facts will be true when this is '
        "DONE, and which hint type can verify each one?",
        "List the observable facts as `[ ]` criteria, then attach the cheapest "
        "hint that proves each (file-exists/grep/no-grep < shell < http < manual).",
    ),
    "choice": (
        'There is a fork here: "{text}". Which option, and what does the '
        "criterion look like for the chosen one?",
        "Pick the option you can verify most cheaply; encode the decision as a "
        "criterion so the run proves the choice was honored.",
    ),
    "tradeoff": (
        'Tension noted: "{text}". Is the downside acceptable, or does it need '
        "its own guarding criterion?",
        "If the risk is real, add a criterion that fails when the downside "
        "materializes (e.g. a rate/latency `[shell:]` threshold).",
    ),
    "open": (
        'Unresolved: "{text}". Resolve it now, or split it into its own task '
        "with a `[manual]` criterion and a sharp description?",
        "Resolve before authoring if it changes task boundaries; otherwise "
        "isolate it so it cannot silently weaken another task's criteria.",
    ),
    "question": (
        'Open question: "{text}". What is the answer, and does it become a '
        "criterion or a description detail?",
        "Answer it, then decide: verifiable fact -> criterion; context -> "
        "description prose.",
    ),
}

_SAMPLE = {
    "branches": [
        {"id": "b1", "kind": "intent", "text": "we want an email-on-export service", "source_line": 3},
        {"id": "b2", "kind": "choice", "text": "SES or self-hosted SMTP", "source_line": 6},
        {"id": "b3", "kind": "dependency", "text": "digest depends on the export marker", "source_line": 7},
        {"id": "b4", "kind": "tradeoff", "text": "real-time mode risks hammering the provider", "source_line": 8},
        {"id": "b5", "kind": "open", "text": "TODO decide retention", "source_line": 9},
    ],
    "count": 5,
    "kinds": {"intent": 1, "choice": 1, "dependency": 1, "tradeoff": 1, "open": 1},
}


def generate(branches):
    """Return ordered question dicts for the given branch list."""
    ordered = sorted(
        branches,
        key=lambda b: (_KIND_PRIORITY.get(b.get("kind"), 99), b.get("source_line", 0)),
    )
    questions = []
    for order, b in enumerate(ordered, start=1):
        kind = b.get("kind", "intent")
        q_tmpl, rec = _TEMPLATES.get(kind, _TEMPLATES["intent"])
        text = b.get("text", "")
        questions.append(
            {
                "branch_id": b.get("id", f"b{order}"),
                "order": order,
                "kind": kind,
                "question": q_tmpl.format(text=text),
                "recommended": rec,
            }
        )
    return questions


def _result(branches):
    qs = generate(branches)
    return {"questions": qs, "count": len(qs)}


def _render_text(result):
    out = [f"{result['count']} forcing question(s), dependency-first:"]
    for q in result["questions"]:
        out.append(f"\nQ{q['order']} [{q['kind']}] ({q['branch_id']})")
        out.append(f"  {q['question']}")
        out.append(f"  Recommended: {q['recommended']}")
    return "\n".join(out)


def _load(text, path_label):
    try:
        data = json.loads(text)
    except json.JSONDecodeError as exc:
        print(f"error: {path_label} is not valid JSON: {exc}", file=sys.stderr)
        return None
    if not isinstance(data, dict) or "branches" not in data:
        print(f"error: {path_label} missing 'branches' array", file=sys.stderr)
        return None
    return data["branches"]


def _self_check():
    result = _result(_SAMPLE["branches"])
    if result["count"] != _SAMPLE["count"]:
        print("self-check FAILED: count mismatch", file=sys.stderr)
        return 1
    orders = [q["order"] for q in result["questions"]]
    if orders != sorted(orders) or orders[0] != 1:
        print("self-check FAILED: order not 1..n", file=sys.stderr)
        return 1
    # Dependency must sort ahead of intent/choice.
    first_kind = result["questions"][0]["kind"]
    if first_kind != "dependency":
        print(f"self-check FAILED: expected dependency first, got {first_kind}", file=sys.stderr)
        return 1
    if any(not q["recommended"] for q in result["questions"]):
        print("self-check FAILED: a question lacks a recommended answer", file=sys.stderr)
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
                raw = fh.read()
        except OSError as exc:
            print(f"error: cannot read {positional[0]}: {exc}", file=sys.stderr)
            return 2
        label = positional[0]
    elif not sys.stdin.isatty():
        raw = sys.stdin.read()
        label = "<stdin>"
    else:
        raw = json.dumps(_SAMPLE)
        label = "<sample>"

    branches = _load(raw, label)
    if branches is None:
        return 2

    result = _result(branches)
    if output == "json":
        print(json.dumps(result, indent=2, ensure_ascii=False))
    else:
        print(_render_text(result))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
