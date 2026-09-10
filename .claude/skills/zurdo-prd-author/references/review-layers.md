# Reviewing a draft PRD — the four layers

Review a draft PRD after it has been authored and before running `zurdo run`. The goal is to catch issues that `zurdo analyze` will not catch on its own: hints that *parse* but don't actually verify what the criterion claims, tasks sized wrong for their `Effort`, dependency edges that imply an ordering the runtime cannot honor, and criteria that pass trivially without proving anything. The deterministic checks `--analyze --static-only` catches are already in scope — re-run them yourself as part of the review — but a human-style read is the layer above that.

This is a **read-only** review. Do not edit the PRD; report findings and let the author apply fixes.

## The four layers, in order

Work top-down. Stop the review at layer 1 if grammar is broken — there's no point reviewing design on a PRD that won't parse.

### Layer 1: grammar conformance

Run `zurdo analyze --static-only <prd>` and read every finding. Any `[error]` from analyze is a hard blocker — report it verbatim under a **Grammar** heading and stop. Common §2.2 violations to double-check by eye in case analyze missed an edge case:

- The H2 task line uses em-dash U+2014 (`—`), not hyphen U+002D or en-dash U+2013.
- No blank line between the H2 task heading and the metadata block.
- Metadata is contiguous, one `**Key**: value` per line, no blank lines in between.
- `Effort` and `Depends-on` are both present on every task.
- `Depends-on` ids all resolve to other task ids inside the same PRD, no cycles, no self-deps.
- Every criterion is a `- [ ]` line and carries at least one trailing `[hint]` block.
- Task ids match `^task-[a-z0-9-]+$` and are unique within the PRD.
- Every `[proves: req-id]` modifier names a requirement id declared in that
  same task's `### Requirements` block — a dangling reference is a hard
  `[error]` (`DanglingProves`), not a warning.
- Every `[symbol:]`, `[references:]`, or `[callers:]` hint requires
  `[lumen].enabled = true` in `.zurdo/config.toml` — using one while the gate
  is off is a hard `[error]` (`StructuralHintLumenDisabled`), not merely an
  unavailable feature.

If layer 1 is clean, proceed to layer 2.

### Layer 2: design soundness

For each task, ask the questions a future operator will ask when the task fails. Surface anything that gives a non-obvious answer:

- **Does each hint actually test the criterion text?** A criterion of "rate limiting works" with `[shell: cargo build]` will pass on a successful build that *doesn't* implement rate limiting at all. The hint must exercise the behavior the criterion names.
- **Is `Effort` sized to the work?** If the criteria list implies a multi-file refactor, `Effort: low` is probably wrong — the executor will time out or run out of attempts. Conversely, a one-line file edit at `Effort: high` is over-budgeting.
- **Is `Max-Attempts` reasonable?** The default may be fine; flag explicit overrides that don't fit the work. Three attempts is a lot for a `[grep:]`-only task; one attempt is risky for a `[shell: cargo test]` task on flaky CI.
- **Are the `Depends-on` edges accurate?** A dependency means "B cannot start until A is `passed` or `passed-pending-review`." If B *could* start independently (different files, different layer), drop the edge — it serializes the run for no reason.
- **Are there missing `[manual]` markers?** A criterion like "the UI feels responsive" with `[shell: cargo test]` is dishonest — the test cannot prove UX. Either rewrite to a measurable threshold or add `[manual]` and accept the `passed-pending-review` outcome.
- **Are skills referenced that the PRD will actually need?** A `**Skills**: foo` entry that the executor never invokes is harmless but noisy; a missing reference for a skill the task clearly relies on is a real gap.
- **Does any `**Frozen**` glob overlap a same-task evidence path?** A frozen path a criterion's hint requires the agent to edit makes the task unwinnable — the union with run-wide `[verification] protected_paths` counts too. `--analyze` warns on this but only advisorily; treat any overlap as an `[error]` in this review. See [frozen-paths.md](frozen-paths.md) for the scope rule and glob dialect.
- **Should anything here be frozen that isn't?** A task that must conform to a spec, golden file, or fixture without touching it is a candidate for a `**Frozen**` entry — freezing forecloses "make the check pass by editing the spec."

### Layer 3: run-time risk

These are the issues that only bite once `zurdo run` is in flight:

- **Trivially-passing criteria.** `[grep: foo in src/lib.rs]` against a file that already contains `foo` will pass before the agent does anything. Verify the criterion actually represents *the change being requested*, not the pre-existing state.
- **Order-of-operations bombs.** A task whose `[shell:]` criterion mutates the working tree (`cargo fmt --write`, schema migrations) interacts with the next task's pre-flight check. Flag any criterion whose side effect could mask a regression on the next task's pre-flight.
- **Network-dependent hints.** `[http:]` against a live external service is a flaky criterion. Recommend mocking, or accept the risk and document it in the task description.
- **Implicit working-directory assumptions.** Every `[shell:]` runs at repo root (§3.3). A criterion like `[shell: npm test]` assumes `package.json` is at repo root; if the project is multi-package, the hint should be `[shell: cd frontend && npm test]`.
- **All-manual tasks.** Tasks where every criterion is `[manual]` short-circuit to `passed-pending-review` with `attempts: 0` (§3.2) — the executor is never invoked. That is correct behavior; just confirm the user expects it.
- **Skills resolution warnings, not installs.** PRD-referenced skills are user-managed — Zurdo never installs, copies, or stages a `**Skills**:` entry at run-time; pre-flight only resolves the reference against the provider's discovery paths and `[skills].search_paths`. A skill that does not resolve anywhere emits an advisory `tracing::warn!` naming every location searched and does not fail pre-flight. Not a blocker, but worth reading if the user is debugging why an agent didn't pick up a skill it expected.
- **Evidence-modified warnings.** The runtime warns when evidence behind an already-passed criterion changes later in the run — the warning tier of evidence integrity, next to frozen paths' enforcement tier. Advisory only, but tell the user to *read* these warnings rather than dismiss them: a later task silently rewriting earlier evidence is exactly the failure they exist to surface.

### Layer 4: vocabulary

Does every task title and criterion use the project's governed nouns, and does any use a
word the project's glossary lists under `_Avoid_`? Call the Skill tool with `zurdo-domain`
for the admission test and the definition-and-`_Avoid_` format before judging this layer.

This layer is a **judgment call, and it must stay one** — do not turn it into a mechanical
grep for `_Avoid_` words. A word on that list is only a defect when it stands in for the
governed noun; the same word survives constantly as a command name, a file name, or a piece
of prose that isn't naming the project's concept at all. `test` is the clearest case: it is
also the name of the `cargo test` / `go test` commands and of test-file paths that fill
`[shell:]` and `[grep:]` hints throughout a normal PRD, so a plain string match on `test`
flags nearly every criterion in a corpus and teaches nothing. Read each hit in context and
flag only the ones where the criterion or title actually means the glossary's governed
concept — *Criterion* — and reached for the common word instead.

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
- **Oversized task.** Task with 8+ criteria touching multiple subsystems. Recommend splitting into smaller, single-subsystem tasks.
- **Effort over-spec.** `Effort: high` on a single-criterion `[file-exists:]` task. Recommend the cheapest key.
- **Frozen glob overlaps evidence.** `**Frozen**: src/**` on a task whose criterion is `[grep: retry in src/client.rs]` — the agent must edit a path it may not touch. Recommend narrowing the glob or dropping the freeze.
