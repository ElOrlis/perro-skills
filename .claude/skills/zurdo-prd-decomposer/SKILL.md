---
name: zurdo-prd-decomposer
description: "Turn a design doc, architectural sketch, or freeform brief into a draft Zurdo task list — task ids, edges, effort, and hint-typed criteria stubs — ready for zurdo-prd-writer to crystalize."
allowed-tools: [Read, Write, Edit]
---

## When to invoke

Invoke this skill when the user hands you intent-shaped input — a design doc, an RFC, an architecture diagram, a freeform "here's what I want to build" brief — and the goal is a Zurdo PRD. The §2.2 grammar is rigid; trying to author both the *decomposition* (what are the tasks and how do they depend?) and the *grammar* (em-dash, contiguous metadata, hinted criteria) in one pass is what produces malformed PRDs. This skill owns the first half: read the input, propose a task list with rationale, and hand off a clean draft to [[zurdo-prd-writer]].

Do **not** invoke this skill when the user already has a numbered task list — go straight to the writer. Do not invoke it for single-task PRDs; the decomposition value is in identifying edges.

## What the decomposer produces

A markdown draft with one section per proposed task, in this shape:

```markdown
# PRD draft: <title>

<one-paragraph intent summary, sourced from the input doc>

## task-1 — <short title>
- **Effort**: <key> (see notes on effort below)
- **Depends-on**: []
- **Why this is one task**: <one sentence of rationale>
- **Criteria sketch**:
  - <plain-english criterion>  → `[shell: ...]` or `[file-exists: ...]` etc.
  - <plain-english criterion>  → `[manual]` (and why no automated check applies)

## task-2 — <short title>
- **Effort**: <key>
- **Depends-on**: [task-1]
- **Why this is one task**: ...
- **Criteria sketch**:
  - ...
```

This is **not** §2.2 grammar yet — that's the writer's job. The intermediate form makes review easy and keeps the decomposition decisions visible before they get compressed into a parser-friendly skeleton.

## Decomposition heuristics

1. **One task = one focused deliverable that can be verified end-to-end.** If a task needs three independent verification checks that target different subsystems, it is probably two or three tasks. If a task needs zero automated checks, it is probably a `[manual]`-only task — surface that explicitly.
2. **Sequence by data, not by feel.** Draw the edge from task A to task B only when B literally cannot start until A's artifact exists (a file, an endpoint, a schema). "B is harder so do A first" is not a dependency — it's an authoring suggestion, and the writer can put it later in source order without a `Depends-on`.
3. **Prefer many small tasks over few large ones.** Smaller tasks ⇒ smaller `Max-Attempts` blast radius when one fails. A task that needs more than ~5 criteria is a smell; split it.
4. **Identify the verification surface for each task before deciding the boundary.** If you cannot name the hint type for at least one criterion, the task is too vague — refine the brief or split the work.
5. **Keep dependency chains shallow.** A linear chain of seven tasks is a worse PRD than two parallel chains of three; Zurdo runs sequentially in v1 but `Depends-on: []` tasks compose better with future parallelism and with the user manually re-running a single task.

## Mapping criteria to hint types

For each criterion you sketch, pick the cheapest hint type that plausibly proves the criterion:

- **Code is exercised by a test** → `[shell: <test command>]`. The shell hint is the workhorse; use it for unit tests, integration tests, builds, lints, formatters.
- **An HTTP endpoint behaves correctly** → `[http: <method> <url> -> <status>]`. Status-only matching in v1; richer assertions go through a `[shell: curl ...]` wrapper.
- **A file or directory must exist** → `[file-exists: <path>]`. Use for migrations, generated artifacts, config files.
- **A file or directory must NOT exist** → `[file-absent: <path>]`. Use for cleanup tasks, removal of deprecated files. Safer than `[shell: ! test -e ...]` — a wrong path fails explicitly rather than silently passing.
- **A specific string must appear in a file** → `[grep: <pattern> in <file>]`. Use for marker strings, version bumps. Be specific — `[grep: foo in src]` is too loose.
- **A specific string must NOT appear in a file** → `[no-grep: <pattern> in <file>]`. Use for TODO removal, dead-code cleanup. Safer than `[shell: ! grep -q ...]` — a typo'd filename fails rather than silently passing.
- **No machine check applies** → `[manual]`. Use sparingly: visual polish, UX feel, design-language conformance, copy review.

Multiple hints on one criterion are AND'd. A criterion like "the new endpoint is live and stays under 200ms" is two hints on one line: `[http: GET /v1/foo -> 200] [shell: ./bench.sh /v1/foo --max-ms 200]`.

## Effort assignment

You usually do not know the user's `[effort_map.<provider>]` keys. Default to writing `Effort: <low|medium|high>` as a placeholder and flag in your handoff that **the writer should confirm the effort keys against `.zurdo/config.toml` before finalizing**. If the user has already confirmed the shipped defaults, use `low|medium|high` directly. Map your intuition to the cheapest key that plausibly clears the criteria — over-budgeting effort is wasted spend.

## Anti-patterns to refuse

- **Mega-tasks.** A single task with "build the whole auth subsystem" plus eight criteria is not a Zurdo task — it's a PRD. Split before drafting.
- **Cross-PRD dependencies.** `Depends-on` is local to one PRD. If your decomposition needs to point at a task in a *different* PRD, that task belongs in this PRD too — or the work needs to be reorganized.
- **Criteria with no plausible hint type.** "Code is well-structured" maps to nothing. Either rewrite the criterion as a check that *does* run (`[shell: cargo clippy -- -D warnings]`) or drop it entirely.
- **Implicit ordering via prose.** Saying "we do A before B" in the intent paragraph does not create a dependency. If A must precede B, write `Depends-on: [task-A]` on task-B explicitly.

## Worked example

Input (a freeform brief):

> We want a `/healthz` endpoint on the existing axum server that returns 200 when the DB is reachable and 503 otherwise. It should be exercised by an integration test, and the operator runbook should mention it.

Decomposed draft:

```markdown
# PRD draft: Add /healthz endpoint

Surface a database-aware health check on the existing axum server and document it in the runbook.

## task-1 — Wire /healthz route into the server
- **Effort**: low
- **Depends-on**: []
- **Why this is one task**: route handler + DB-probe + status mapping is one focused change in `src/routes/health.rs`; everything downstream needs the route to exist.
- **Criteria sketch**:
  - handler file is present  → `[file-exists: src/routes/health.rs]`
  - server compiles  → `[shell: cargo build]`
  - healthy DB path returns 200  → `[http: GET http://localhost:8080/healthz -> 200]`

## task-2 — Integration test for /healthz
- **Effort**: medium
- **Depends-on**: [task-1]
- **Why this is one task**: the test cannot exist until the route does; bundling them hides the test failure mode when the route handler is broken.
- **Criteria sketch**:
  - integration test passes  → `[shell: cargo test --test healthz_integration]`

## task-3 — Document /healthz in operator runbook
- **Effort**: low
- **Depends-on**: [task-1]
- **Why this is one task**: pure docs change, no automated check applies beyond presence.
- **Criteria sketch**:
  - runbook mentions /healthz  → `[grep: /healthz in docs/runbook.md]`
  - the prose reads sensibly  → `[manual]` (no automated check for editorial quality)
```

Hand this off with: "draft is ready — please run [[zurdo-prd-writer]] over it to produce a parser-clean `<filename>.md`, then `zurdo --analyze --static-only <filename>.md` before committing."
