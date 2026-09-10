---
name: zurdo-prd-author
description: "Interview-driven authoring of a Zurdo PRD — grill intent into tasks, dependency edges, and §2.2 grammar, then pressure-test every acceptance criterion until its hint actually verifies, before zurdo run burns tokens."
allowed-tools: [Read, Write, Edit, Bash]
disable-model-invocation: true
---

## When to invoke

Invoke this skill when the user wants to turn an idea into a runnable Zurdo PRD
and cares that the result actually *verifies* — not just parses. It is the
single authoring entry point: it runs a grill-style interview from vague intent
all the way to a parser-clean PRD, and its defining job is the criteria phase,
where every acceptance criterion is interrogated until its hint passes if and
only if the work is genuinely done.

This skill consolidates what used to be four separate skills — decomposition,
grammar authoring, criteria authoring, and review — into one interview, with
their guidance carried as `references/` (the single source of truth). The
post-run skills `zurdo-hint-debugger` (diagnose a failed criterion) and
`zurdo-state-summary` (summarize run state) remain separate; reach for those
*after* `zurdo run`, not during authoring.

Do not invoke it to debug a *failing* run (use `zurdo-hint-debugger`) or to
summarize an in-flight run (use `zurdo-state-summary`).

## How the interview works

Run it as a relentless, one-question-at-a-time grill. For every question, lead
with your recommended answer and a one-sentence rationale — never a bare "what
do you think?". Before asking anything that the codebase can answer, `grep`/
`Read` the codebase instead; it saves a turn. Walk the decision tree
depth-first: finish a branch before opening the next, and resolve a dependency
before the decisions that hang off it.

The grammar is rigid and unforgiving (em-dash separators, contiguous metadata,
mandatory hints), so authoring blind wastes tokens. Defer every grammar
question to the real parser: `zurdo analyze --static-only <prd>`
is the source of truth — never re-derive the grammar by hand.

## The five phases

Each phase has a gate it must clear before the next begins (see
[references/when-to-stop.md](references/when-to-stop.md)).

1. **Intent.** Pin the headline goal in one sentence and confirm scope. Run
   `scripts/branch_extractor.py <intent-doc> --output json` to surface the
   decision branches worth grilling, then
   `scripts/question_generator.py --output json` to order them
   dependency-first with recommended answers. Start a session with
   `scripts/session_tracker.py --action start`. Run `zurdo reason status` once,
   at session start: if the repository carries a lesson library, the
   interviewer knows repo-specific failure knowledge is available to draw on
   during the **Review** phase.

2. **Evidence inventory.** Ask, for each capability the PRD claims to deliver:
   *"when this is done, what observable facts will be true?"* — and its
   negative-space twin: *"what must NOT change while delivering this?"*
   Negative-space answers are recorded as candidate frozen paths beside the
   positive evidence (see
   [references/frozen-paths.md](references/frozen-paths.md)); they are bound
   to globs later, in phase 3, once tasks exist to carry them. Each positive
   answer becomes a numbered requirement (`req-1`, `req-2`, …) in a
   `### Requirements` block, paired immediately with a criterion draft that
   carries a concrete hint
   (select from the hint catalog in
   [references/criteria.md](references/criteria.md) — seven core types plus
   the structural hints `[symbol:]`, `[references:]`, and `[callers:]`, which
   are only available when the user's config enables `[lumen]`). Before
   wording a `req-*` line or its paired criterion, call the Skill tool with
   `zurdo-domain` and use the project's governed nouns — a criterion worded
   with the wrong noun is one whose `[proves:]` tag binds before anyone
   notices. Walk the
   six forcing questions from
   [references/forcing-questions.md](references/forcing-questions.md)
   — tautology, no-op, honesty, specificity, honest-`[manual]`,
   pre-authored test — on every criterion draft before moving on, with
   forcing applied at birth so no criterion arrives at the grammar phase
   already broken. For the sixth question, this gate asks only for a
   **declaration** — pre-author the test, or decline with a reason — since
   the pre-authored test's marker is keyed to a task id and phase 2 has no
   tasks yet to name one for; the artifact itself (the file exists, its hint
   ran, it failed on an assertion) is checked later, at the Ready stop
   condition (see
   [references/when-to-stop.md](references/when-to-stop.md)). A
   `[proves: req-N]` tag is written on the criterion at the same time as the
   hint — traceability is applied at birth, not retrofitted later. Record
   each resolved criterion with `scripts/session_tracker.py --action record`.
   Gate: every criterion carries a concrete hint, survives all six forcing
   questions (question 6 at the declaration level), and is linked to a
   `req-*` via `[proves:]`.

3. **Group evidence into tasks.** A task is *the unit of work that flips one
   cluster of criteria from red to green*. Inspect the criteria produced in
   phase 2 and group related ones; each cluster becomes one task. Apply
   [references/decompose.md](references/decompose.md). Dependency edges fall out
   of evidence ordering: if criterion B needs the artifact that criterion A
   verifies, its task depends on A's task. The ~5-criteria bound is the
   grouping rule — if a cluster would exceed it, split it. Bind the phase-2
   negative-space answers here: each candidate protection becomes globs on the
   owning task's `**Frozen**` key per the scope rule in
   [references/frozen-paths.md](references/frozen-paths.md) — task-scoped
   protection goes on `**Frozen**`; a path no task may ever touch is surfaced
   as an advisory note to add `[verification] protected_paths` in
   `.zurdo/config.toml` (this skill writes only the PRD, never config). Gate:
   no task implies more than ~5 criteria; every `Depends-on` is a real data
   dependency; and no bound `**Frozen**` glob matches an evidence path of a
   hint in the same task — that overlap makes the task unwinnable
   (`zurdo analyze` warns on it in phase 4, but only advisorily).

4. **Author grammar.** Crystalize the task list into the strict §2.2 skeleton.
   Apply [references/grammar-2.2.md](references/grammar-2.2.md). Gate:
   `zurdo analyze --static-only <prd>` returns zero `[error]`.

5. **Review.** Read the whole PRD across the four layers in
   [references/review-layers.md](references/review-layers.md): grammar, design
   soundness, run-time risk, vocabulary. Run `zurdo reason match <prd-path>` on the drafted
   PRD and fold each matched lesson into the run-time-risk layer of the
   verdict — e.g. a lesson recording that this repo's integration tests need a
   serial flag reshapes a `[shell:]` criterion before the run pays for the
   discovery again. Matched lessons are advisory input to the verdict, never a
   gate; the command is a pure read and never stamps a lesson's reuse
   metadata. If `zurdo` predates the `reason` subcommand, either call exits
   non-zero, or `reason status`/`reason match` reports zero lessons or zero
   matches, proceed without lessons — the interview continues exactly as it
   does today. Note the asymmetry this fallback does not cover: `reason
   status` and `reason match` are pure reads of the git-tracked library and
   never consult `[reason].enabled` — they report real counts regardless of
   that gate. Lesson **injection** at run-time is the opposite: `[reason].enabled`
   defaults to `false`, and turning it on also requires a `[roles.reasoner]`
   or `[roles.analyzer]` role in the same config; `zurdo init`'s generated
   config does not turn `[reason].enabled` on, so injection stays off until
   the user opts in explicitly, no matter how many lessons this phase writes
   below. Produce a verdict and stop on `✓ READY TO RUN`.
   On a ready verdict, emit the **reasoning trail**: distill the session's
   locked decisions into a `<prd-name>.trail.md` sidecar beside the PRD — one
   rationale line per gate-locked decision (each criterion's hint choice, each
   dependency edge, each frozen glob, each effort call), sourced from the
   answers the session tracker already holds, so it costs no extra interview
   turns. The sidecar is committed in the same commit as the PRD; zurdo never
   parses it, and `zurdo-hint-debugger` reads it when diagnosing a failing
   criterion.
   In the same step, emit **lesson files** alongside the trail sidecar: for each
   locked decision that qualifies under the rule in the `zurdo-lessons` skill
   (call the Skill tool with `zurdo-lessons`; if your runtime exposes no Skill
   tool, read `zurdo-lessons/SKILL.md` from your skills discovery path; if
   neither resolves, stop and tell the user to run `zurdo skills install
   --all`), write one
   `lessons/lesson-<hash8>.md` into the git-tracked `lessons/` directory at the
   repository root, with `source.kind` set to `AuthoringTrail` and `trail_path`
   pointing at the `.trail.md` sidecar written in this same step. Apply the
   selection rule strictly — only a correction that would otherwise be
   rediscovered qualifies, and scope calls, effort calls, and dependency-edge
   rationale stay in the trail — so a PRD yields a handful of lessons at most,
   and zero is a normal outcome. Close the handoff by reminding the user to
   commit the PRD, the trail, and the lessons before `zurdo run`; that commit is
   the human review gate the lesson library relies on.

## Requirement traceability

Requirement traceability is the backbone of this skill, not an optional add-on.
Because every criterion is born from a `req-*` requirement during **Evidence
inventory** (phase 2), `[proves:]` tags are trivially complete: they are applied
at birth alongside the hint, so there is no separate "retrofit" step.

The `### Requirements` block is therefore always present, placed **before**
`### Description` (between the task's metadata block and the description, per
the §2.2 H3 ordering). During phase 2, for each *observable fact* the author
names, write the matching `req-N` entry immediately, then draft its paired
criterion with hint and `[proves: req-N]` in the same breath.

The author remains the final authority on the wording of every requirement and
on whether a proposed link is accurate. If the author wants to adjust or reject
a `[proves:]` assignment, do so before the criterion is locked. Never silently
change a ratified link.

Zurdo checks coverage deterministically at run-time: if a requirement in
`### Requirements` carries no criterion tagged `[proves: its-id]`, it is flagged
as untraced. The LLM only drafts the structure — the runtime stays free of any
LLM coverage logic.

See [references/criteria.md](references/criteria.md) for the `proves modifier`
grammar and rules.

## The hard gate

Do not advance from phase 2 (**Evidence inventory**) to phase 3 (**Group
evidence into tasks**) until *every* criterion draft survives all six
forcing questions. A single criterion that already passes on the
untouched tree (tautology), or that would not fail on an empty diff (no-op), or
whose hint does not exercise the behavior its text names (honesty), keeps the
gate closed. **Relaxing a hint just to make the gate pass is never allowed** —
it turns a real gap into a green check that lies. When a criterion genuinely
cannot be automated, mark it `[manual]` honestly rather than faking a check.

The sixth question, the pre-authored test, holds this gate to a
**declaration** only — pre-author the test, or decline with a reason — never
to the artifact. A pre-authored test's marker names a task id
(`#[ignore = "pre-authored: task-03"]`), and phase 2 has no task ids yet to
name one for, so demanding the file here would demand something that cannot
exist. The file existing, its hint having run, and it having failed **on an
assertion** are checked later, at the Ready stop condition in
[references/when-to-stop.md](references/when-to-stop.md) — once phase 3 has
produced the task ids the file is named for.

Because forcing is applied in phase 2 — with forcing applied at birth, before
any grouping or grammar work — no broken criterion survives to pollute the task
structure in phase 3.

## Tooling

Three stdlib-only Python scripts ship beside this skill. Each accepts
`--output text|json` and a `--self-check` smoke mode; grammar/validation is
never done in Python — it is delegated to the `zurdo` binary.

| Script | Role |
|---|---|
| `scripts/branch_extractor.py` | intent doc → decision branches (intent / choice / tradeoff / dependency / open / question) |
| `scripts/question_generator.py` | branches → forcing questions + recommended answers, ordered dependency-first |
| `scripts/session_tracker.py` | persist the Q/A trail, resume across turns, emit a "decisions locked" summary |

The session persists repo-local to `<repo>/.zurdo/authoring/<session>.json`
(matching Zurdo's repo-local state model), overridable with `--session-file`.

## References

- [references/grammar-2.2.md](references/grammar-2.2.md) — the §2.2 PRD grammar and its enforcement rules
- [references/decompose.md](references/decompose.md) — turning intent into a task list with edges and effort
- [references/criteria.md](references/criteria.md) — the seven core hint types, the structural hints, sizing, and hint-selection
- [references/frozen-paths.md](references/frozen-paths.md) — the negative-space question, the `**Frozen**`-vs-`protected_paths` scope rule, the overlap trap, and the commit-before-run baseline caveat
- [references/forcing-questions.md](references/forcing-questions.md) — the criterion-grilling patterns (the skill's core)
- [references/review-layers.md](references/review-layers.md) — the four-layer pre-run review
- [references/grep-hints.md](references/grep-hints.md) — file-vs-directory targets, regex escaping, `[no-grep:]` over negated shell grep
- [references/when-to-stop.md](references/when-to-stop.md) — phase gates and stop conditions
- [references/pre-authored-tests.md](references/pre-authored-tests.md) — committing a test red before the run: the Rust and Go markers, their paired guards, and what the convention does and does not prevent
- `zurdo-domain` — the project's governed nouns and the `_Avoid_` list a `req-*` line or criterion must not use; call the Skill tool with `zurdo-domain` (this is a peer skill, named rather than addressed by path)

## Worked example

A finished interview hands back a parser-clean PRD. A single-task PRD that
validates cleanly:

````markdown
# PRD: Add a Greeting File

Drop a static file into the repo root with a known string.

## Task: task-1 — Create greeting.txt
**Effort**: low
**Depends-on**: []

### Description

Create `greeting.txt` at the repo root containing the word `Hello`.

### Acceptance Criteria

- [ ] greeting.txt exists [file-exists: greeting.txt]
- [ ] greeting.txt contains Hello [grep: Hello in greeting.txt]
````

A two-task PRD with a `Depends-on` edge, the shape phase 2 produces and phase 4
hardens:

````markdown
# PRD: Build a Hello-World Binary

Two-step PRD: scaffold a tiny Cargo binary, then build it.

## Task: task-1 — Scaffold the binary
**Effort**: low
**Depends-on**: []

### Description

Create `src/main.rs` with a `fn main()` that prints `hello`.

### Acceptance Criteria

- [ ] src/main.rs exists [file-exists: src/main.rs]
- [ ] main prints hello [grep: hello in src/main.rs]

## Task: task-2 — Build the binary
**Effort**: medium
**Depends-on**: [task-1]

### Description

Compile the crate in release mode.

### Acceptance Criteria

- [ ] release build succeeds [shell: cargo build --release]
````

Before handing the PRD back, run `zurdo analyze --static-only <prd>` and
resolve any findings — clean output means the grammar parses; the criteria
hard gate above is what makes it worth running.
