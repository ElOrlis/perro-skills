---
name: zurdo-prd-reviewer
description: "Review a draft Zurdo PRD across three layers — grammar conformance, design soundness, and run-time risk — before zurdo run burns tokens on a flawed plan."
allowed-tools: [Read, Bash]
---

## When to invoke

Invoke this skill after a PRD has been authored (by hand or by [[zurdo-prd-writer]]) and before the user runs `zurdo run`. The goal is to catch issues that `zurdo --analyze` will not catch on its own: hints that *parse* but don't actually verify what the criterion claims, tasks sized wrong for their `Effort`, dependency edges that imply an ordering the runtime cannot honor, and criteria that pass trivially without proving anything. The deterministic checks `--analyze --static-only` catches are already in scope — re-run them yourself as part of the review — but a human-style read is the layer above that.

This is a **read-only** review. Do not edit the PRD; report findings and let the user (or the writer skill) apply fixes.

## The three layers, in order

Work top-down. Stop the review at layer 1 if grammar is broken — there's no point reviewing design on a PRD that won't parse.

### Layer 1: grammar conformance

Run `zurdo --analyze --static-only <prd>` and read every finding. Any `[error]` from analyze is a hard blocker — report it verbatim under a **Grammar** heading and stop. Common §2.2 violations to double-check by eye in case analyze missed an edge case:

- The H2 task line uses em-dash U+2014 (`—`), not hyphen U+002D or en-dash U+2013.
- No blank line between the H2 task heading and the metadata block.
- Metadata is contiguous, one `**Key**: value` per line, no blank lines in between.
- `Effort` and `Depends-on` are both present on every task.
- `Depends-on` ids all resolve to other task ids inside the same PRD, no cycles, no self-deps.
- Every criterion is a `- [ ]` line and carries at least one trailing `[hint]` block.
- Task ids match `^task-[a-z0-9-]+$` and are unique within the PRD.

If layer 1 is clean, proceed to layer 2.

### Layer 2: design soundness

For each task, ask the questions a future operator will ask when the task fails. Surface anything that gives a non-obvious answer:

- **Does each hint actually test the criterion text?** A criterion of "rate limiting works" with `[shell: cargo build]` will pass on a successful build that *doesn't* implement rate limiting at all. The hint must exercise the behavior the criterion names.
- **Is `Effort` sized to the work?** If the criteria list implies a multi-file refactor, `Effort: low` is probably wrong — the executor will time out or run out of attempts. Conversely, a one-line file edit at `Effort: high` is over-budgeting.
- **Is `Max-Attempts` reasonable?** The default may be fine; flag explicit overrides that don't fit the work. Three attempts is a lot for a `[grep:]`-only task; one attempt is risky for a `[shell: cargo test]` task on flaky CI.
- **Are the `Depends-on` edges accurate?** A dependency means "B cannot start until A is `passed` or `passed-pending-review`." If B *could* start independently (different files, different layer), drop the edge — it serializes the run for no reason.
- **Are there missing `[manual]` markers?** A criterion like "the UI feels responsive" with `[shell: cargo test]` is dishonest — the test cannot prove UX. Either rewrite to a measurable threshold or add `[manual]` and accept the `passed-pending-review` outcome.
- **Are skills referenced that the PRD will actually need?** A `**Skills**: foo` entry that the executor never invokes is harmless but noisy; a missing reference for a skill the task clearly relies on is a real gap.

### Layer 3: run-time risk

These are the issues that only bite once `zurdo run` is in flight:

- **Trivially-passing criteria.** `[grep: foo in src/lib.rs]` against a file that already contains `foo` will pass before the agent does anything. Verify the criterion actually represents *the change being requested*, not the pre-existing state.
- **Order-of-operations bombs.** A task whose `[shell:]` criterion mutates the working tree (`cargo fmt --write`, schema migrations) interacts with the next task's pre-flight check. Flag any criterion whose side effect could mask a regression on the next task's pre-flight.
- **Network-dependent hints.** `[http:]` against a live external service is a flaky criterion. Recommend mocking, or accept the risk and document it in the task description.
- **Implicit working-directory assumptions.** Every `[shell:]` runs at repo root (§3.3). A criterion like `[shell: npm test]` assumes `package.json` is at repo root; if the project is multi-package, the hint should be `[shell: cd frontend && npm test]`.
- **All-manual tasks.** Tasks where every criterion is `[manual]` short-circuit to `passed-pending-review` with `attempts: 0` (§3.2) — the executor is never invoked. That is correct behavior; just confirm the user expects it.
- **Skills install cost.** Tasks that reference many bundled skills via `**Skills**:` will trigger run-time pre-flight installs. Not a blocker, but worth noting if the user is debugging slow startup.

## Output format

Mirror Zurdo's `--analyze` output shape so the review reads consistently with the analyzer's. Group findings by task, tag with severity, lead with a one-line verdict:

```
== Review: <prd-path> ==

== Layer 1: Grammar ==
(empty when --analyze --static-only is clean — say so explicitly)

== task-1: <title> ==
[error] <finding>
  suggestion: <one line>
[warning] <finding>
  suggestion: <one line>

== task-2: <title> ==
[info] <observation>

═══ Verdict ═══
<one of:>
  ✓ READY TO RUN — no findings.
  ⚠ READY WITH WARNINGS — N warnings to address before running.
  ✗ NOT READY — N errors must be fixed before running.
```

Severity tiers match the analyzer's: `error` blocks the run, `warning` allows the run but is likely wrong, `info` is advisory.

## Common findings cheat sheet

- **Vague criterion.** `- [ ] handles edge cases gracefully [manual]` — fine if intentional, but flag for the user to confirm.
- **Hint type mismatch.** `- [ ] login endpoint returns 200 [shell: cargo build]` — recommend `[http: GET /login -> 200]`.
- **Tautology.** `- [ ] file exists [file-exists: README.md]` on a repo that already has `README.md` — recommend grepping for a marker the task is supposed to introduce.
- **Shell negation instead of absence hint.** `[shell: ! grep -q TODO src/main.rs]` or `[shell: ! test -e tmp/file]` — recommend `[no-grep: TODO in src/main.rs]` or `[file-absent: tmp/file]` instead; the shell negation forms silently pass when the command errors (wrong path, missing binary), which defeats independent verification.
- **Missing `Depends-on`.** task-2 uses an artifact task-1 produces but declares `Depends-on: []`. Recommend adding the edge.
- **Oversized task.** Task with 8+ criteria touching multiple subsystems. Recommend splitting; reference [[zurdo-prd-decomposer]].
- **Effort over-spec.** `Effort: high` on a single-criterion `[file-exists:]` task. Recommend the cheapest key.

## Handoff

If the review is `✓ READY TO RUN`, tell the user they can proceed with `zurdo run <prd>` (or `zurdo --analyze <prd>` first for the LLM-assisted quality pass, which `--static-only` skips). If `⚠` or `✗`, tell them to address the findings and re-run this review — and remind them that the LLM-driven `--analyze --fix` mode (§9.7) can apply structural fixes automatically when the analyzer role is configured.
