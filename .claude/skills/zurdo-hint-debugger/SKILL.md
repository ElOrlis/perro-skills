---
name: zurdo-hint-debugger
description: "Diagnose a failing Zurdo acceptance criterion by correlating its hint, the iteration logs under .zurdo/<slug>/iterations/, and the current working tree — then propose a corrected hint or a corrected code change."
allowed-tools: [Read, Bash, Edit]
disable-model-invocation: true
---

## When to invoke

Invoke this skill when an acceptance criterion has failed on a `zurdo run` and the user wants to know **why** before re-running. The failure may be in the criterion (the hint is wrong) or in the code (the agent missed the requirement). The job of this skill is to tell those two apart and recommend the cheapest fix.

The signal you start from is one of:
- A line from `progress.log`: `{"event":"criterion_result", "passed":false, "hint":"...", "task_id":"...", "attempt":N, ...}`.
- A failing entry inside `prd.json` under `tasks.<id>.iterations[k].criteria_results`.
- A user paste of the hint plus the most recent stderr.

## The two-question diagnosis

Every diagnosis answers two questions, in order:

1. **Does the hint match the criterion's intent?** Read the criterion text in the PRD and compare to the hint. If the criterion says "rate limiting kicks in" but the hint is `[shell: cargo build]`, the hint is broken regardless of what happened at run-time — fix the hint, the agent never had a chance.
2. **If the hint is correct, what did the iteration actually do?** Read the iteration's `.out` and `.err` files. Look for the agent narrative: did it claim to implement the feature? Did the build fail? Did a test fail with a specific assertion?

The answers map to one of five root causes — pick the one that fits and act on it.

## Root cause taxonomy

### A. Wrong hint type

The hint cannot in principle prove the criterion. Examples:

- Criterion: "API returns 401 for unauthenticated requests." Hint: `[file-exists: src/auth.rs]`. The file existing proves nothing about the response.
- Criterion: "rate limit is 100 req/min." Hint: `[shell: cargo test rate_limit]` — fine *if* the test asserts the threshold; broken if it only asserts that *some* rate limiting exists.

**Fix.** Rewrite the hint to a type that can prove the criterion. Reference the hint table in §3.1:

| If the criterion is about… | Use… |
|---|---|
| code under test                   | `[shell: <test cmd>]` |
| HTTP endpoint status               | `[http: <method> <url> -> <status>]` — append the **`contains "<substring>"` modifier** after the status to additionally require the response body contain that literal, case-sensitive substring: `[http: <method> <url> -> <status> contains "<substring>"]` |
| file or directory presence         | `[file-exists: <path>]` |
| file or directory absence          | `[file-absent: <path>]` |
| specific string in a file          | `[grep: <pattern> in <file>]` |
| specific string absent in a file   | `[no-grep: <pattern> in <file>]` |
| a named symbol exists                    | `[symbol: <kind> <qualified-name> in <file>]` |
| one symbol is referenced within another  | `[references: <kind> <qualified-name> in <file> within <kind> <qualified-name> in <file>]` |
| one symbol calls another                 | `[callers: <kind> <qualified-name> in <file> within <kind> <qualified-name> in <file>]` |
| editorial / visual / UX quality    | `[manual]` |

### B. Hint type is right, hint contents are wrong

The hint *kind* matches but the specifics don't:

- `[shell: cargo test]` runs the whole suite when the criterion is one specific test — narrow to `[shell: cargo test --test <name>]` so an unrelated regression elsewhere doesn't drag this criterion down.
- `[grep: TODO in src]` greps a directory; the hint syntax in v1 is `[grep: <pattern> in <single file>]`. Pick the right file.
- `[http: GET /healthz -> 200]` against a server that runs on `:8080` needs the full URL: `[http: GET http://localhost:8080/healthz -> 200]`.
- `[file-exists: db/migrations]` — file-exists is path-relative-to-repo-root; if the path is wrong, fix the path.

**Fix.** Edit the hint contents. Re-run `zurdo run` and verify in the next iteration's `criterion_result` event.

### C. Hint is correct; the agent did not implement the feature

The hint is well-formed and well-targeted, but the agent's iteration ended without making the necessary code change. Symptoms:

- The `.out` file shows the agent investigating the codebase but never modifying the relevant file.
- The agent's narrative explains why it *can't* do the thing (missing dependency, ambiguous spec) instead of doing it.
- The criterion's `stderr_truncated` shows the same compile error as iteration 1.

**Fix.** The hint is correct — the *task description* probably needs to be sharper, or the task is too big to fit one iteration. Do not edit the hint. Instead:

- Tighten the `### Description` so the agent gets specifics.
- If the task is too large, split it (reference [[zurdo-prd-author]]).
- If the agent ran out of attempts, raise `Max-Attempts` for this one task — but only if you believe the next attempt has new information from the prior-iteration tail (§7.4).

### D. Hint and code are both correct; the criterion ran against the wrong state

The hint passed locally but failed under `zurdo run`. Common causes:

- **Working directory.** All `[shell:]` and `[http:]` hints run at repo root (§3.3). A criterion that depends on `cd frontend && npm test` must include the `cd`.
- **Side effects from prior tasks.** Task A mutated a file Task B's criterion now greps; Task B's pre-flight check picks up the mutation. Re-read the dependency edges in the [[zurdo-prd-author]] review-layers reference.
- **Timeout.** Look for `"timed_out": true` in the criterion result. The per-criterion **timeout modifier is `[shell:]`-only** — append it directly on the hint, `[shell: <cmd> timeout:60s]`, when that one shell criterion legitimately needs more than `timeouts.criterion_seconds` (default 300s), rather than inflating the global default for every hint. `[http:]` has no timeout field: `parse_http_hint` treats a trailing `timeout:` token as `malformed http hint`, a parse error, not a recognized modifier — do not template the shell fix onto an `[http:]` hint. A slow `[http:]` criterion has no per-criterion escape hatch, so raise the global `timeouts.criterion_seconds` in `.zurdo/config.toml` instead.
- **Transient HTTP failure.** A `[http:]` against a service that wasn't ready at criterion-time. Recommend wrapping in `[shell:]` with a retry loop, or hardening the service start sequence.

**Fix.** Edit the hint to match the run-time environment, or fix the environment.

### E. `frozen-overlap`: a satisfied guard is not a defect

A `zurdo validate`/`--analyze` `frozen-overlap` warning names a criterion
whose evidence path matches a frozen glob — but that alone does not make the
criterion broken. The lint only fires when the criterion could not pass
without editing the frozen path; a `[no-grep:]` or `[file-exists:]` guard
that already holds against the working tree needs no such edit, so the
sensible executor never writes to or deletes a frozen path just to satisfy an
already-satisfied guard hint, and `frozen-overlap` will not flag that guard.

**Fix.** None needed. If `frozen-overlap` is silent on a `[no-grep:]` or
`[file-exists:]` hint against a frozen path, that is a guard, not the defect
— do not "fix" a passing guard by loosening or removing the freeze.
Reserve edits for the cases the lint actually flags: a `[grep:]` for content
not yet present, or a `[file-absent:]` for a file that still exists, against
a frozen path (reference [[zurdo-prd-author]]'s frozen-paths guide, "The
validate-rail check").

### F. `[shell:]` failed with `exit_code: 0` — a demoted vacuous test run

Since v1.13.0, a `[shell:]` hint whose combined stdout+stderr matches a
recognized test-runner's **report** marker (e.g. libtest's `running N tests`,
`go test`'s `ok`/`FAIL` line) but no matching **ran** marker — a runner that
reported without proving anything ran, most often a name filter that matched
zero tests — is demoted to `passed: false` even though the command's own exit
code stays `0` (`criteria/shell.rs`'s `zero_test_run`, design
`vacuous-pass-detection.md` §3). The `criteria_results` entry pairs
`"exit_code": 0` with `"failure_reason": "empty_test_run"`
(`FailureReason::EmptyTestRun`) — reading that `0` as "the command succeeded"
and routing toward classification C or D from there is the wrong diagnosis.

Every `criteria_results` entry carries a `failure_reason` field: `null` on a
pass, one of fifteen values on a failure. Check it before trusting
`exit_code` alone. The full set, grouped by what it points to:

- **B** (hint contents wrong): `empty_test_run` — broaden or correct the test
  filter so it actually selects the test(s) the criterion means to run.
- **C** or **D** (code incomplete, or run against the wrong state):
  `non_zero_exit`, `timeout`, `spawn_failed` (`[shell:]`);
  `http_status_mismatch`, `http_body_mismatch`, `http_transport` (`[http:]`);
  `symbol_unresolved`, `binding_unresolved` (structural hints).
- **A** or **B** (hint type or contents wrong): `pattern_not_found`,
  `pattern_found`, `invalid_regex`, `file_unreadable`, `path_missing`,
  `path_present` (`[grep:]`/`[no-grep:]`/`[file-exists:]`/`[file-absent:]` —
  the same failures step 4's `stderr_truncated` text already names in prose).

**Fix.** Read `failure_reason` first. `empty_test_run` is always
classification B — narrow the filter, don't touch the code or the task
description. Anything else, cross-reference the value against A–D above
rather than inferring the cause from `exit_code` alone.

## Procedure

1. **Read the criterion.** Open the PRD; locate the failing criterion's source text and surrounding task description.
2. **Read the reasoning trail, if present.** If a `<prd-name>.trail.md` sidecar sits beside the PRD (written by [[zurdo-prd-author]] at authoring time), read the failing criterion's rationale line — why this hint type and this evidence path were chosen. The recorded intent distinguishes "wrong hint" (the rationale no longer holds) from "wrong code" (the rationale holds and the agent missed it) faster than re-deriving it. Absent sidecar, skip this step.
3. **Read matched lessons.** Run `zurdo reason match <prd-path>` and read any lesson matched to the failing criterion's task. A lesson that names the repo quirk behind the failure — a required test flag, a registration file, an offline-build requirement — is evidence for **classification C**: the hint is right and the code or command is incomplete. A lesson that speaks to something else, or no match at all, leaves the A/B hint analysis unchanged. The command is a pure read and never stamps a lesson's reuse metadata. If `zurdo` predates the `reason` subcommand, the call exits non-zero, or `reason match` reports zero matches, proceed without lessons — the diagnosis continues on the reasoning trail and iteration logs alone.
4. **Read the result.** Either `progress.log` (the `criterion_result` event) or `prd.json` (the `criteria_results` entry on the most recent iteration). Note the `passed: false`, the `exit_code`/`stdout_truncated`/`stderr_truncated`, and the `duration_ms`. **For local hints** (`grep`, `no-grep`, `file-exists`, `file-absent`) `stderr_truncated` now carries a human-readable failure reason — `pattern not matched`, `pattern matched at line <n>`, `cannot read <file>: <io-error>`, `path does not exist`, or `path exists` — so you can often classify without reproducing. Shell/HTTP hints put the real command stderr/stdout there instead.
5. **Read the iteration.** Open `.zurdo/<slug>/iterations/<task-id>-<attempt>.out` and `.err` for the full agent narrative. The truncated fields in `prd.json` are 4KB head+tail captures (first 1KB + last 3KB joined by a `[... <n> bytes omitted ...]` seam); the full files have the rest.
6. **(Optional) Reproduce locally.** Run the hint by hand — `bash -c '<the shell cmd>'` for `[shell:]`, `curl -s -o /dev/null -w "%{http_code}" <url>` for `[http:]`, `test -e <path>` for `[file-exists:]`, `! test -e <path>` for `[file-absent:]`, `grep -q <pattern> <file>` for `[grep:]`, `! grep -q <pattern> <file>` for `[no-grep:]`. Compare to what the run saw.
7. **Classify** as A / B / C / D / F above.
8. **Recommend** the fix in one of two shapes:
   - **Hint-side fix** (A, B, D, F): name the file and line, give the new hint text verbatim, optionally apply it with Edit. If the fix re-aims a `[grep:]`/`[no-grep:]` hint, `zurdo heal` is the shipped verb for exactly that — it is history-driven, so it only helps once a `zurdo run` has already recorded the failure, but it re-aims the criterion and records the edit in a heal-log chain that the next `zurdo run` can reconcile automatically (see step 9).
   - **PRD-side fix** (C): name the task and the change to the description; do not edit the hint.
9. **Next step.** Any edit to the PRD file — hint-side or PRD-side, a single byte or a whole section — changes its SHA-1, and `prd_hash` is a SHA-1 over the **whole PRD file** (`bootstrap.rs`), not a semantic diff: `state/integrity.rs`'s `check_prd_hash` returns `Ok` only on an exact match, so there is no such thing as a change too small to trip it. The next `zurdo run <prd>` hits that mismatch at its start-up integrity gate and — on a TTY, absent `--resume`/`--reset`/`--no-prompt` — offers the interactive resume prompt (`[R]esume` / `[X] Reset` / `[A]bort`); non-interactively, or once past the prompt, it exits **4** (`STATE_MISMATCH`) unless the mismatch reconciles. There are exactly two ways past it:
   - **`--reset`** (or the prompt's `[X]` choice): archives the existing `.zurdo/<slug>/` state to `.zurdo/<slug>/.archive/<timestamp>/` and starts a fresh run. Always works, for either fix shape, at the cost of the task's in-progress iteration history (archived, not deleted).
   - **A valid heal-log chain**: if the edit was made through `zurdo heal` and accepted, `.zurdo/<slug>/heal-log.jsonl` records it; `zurdo run` validates the chain against the stored `prd_hash` and, if it holds, advances `prd_hash` to match, flips the affected task back to `pending`, and proceeds with no `--reset` and no agent tokens spent (spec §9.8.8). This path exists only for `zurdo heal`-made edits — a hand-edited hint, and every PRD-side fix (classification C's task-description edit), has no heal-log entry and always falls through to `--reset`.

## What this skill does NOT do

- It does not modify the agent's prior `.out`/`.err` files or `prd.json` — those are append-only audit trail.
- It does not re-trigger a run. `zurdo run` is the user's call.
- It does not paper over an agent failure by relaxing the hint. If the agent did not implement the feature, relaxing the hint to make it pass is the wrong fix — surface the real failure.

## Worked example

**Input:** failing `criterion_result` event:

```json
{"event":"criterion_result","task_id":"task-2","attempt":3,"hint":"shell: cargo test --test login","passed":false,"duration_ms":2400,"exit_code":101,"stderr_truncated":"...thread 'login_returns_401_when_password_missing' panicked at 'assertion `left == right` failed\n  left: 200\n right: 401..."}
```

**Diagnosis:**

- Layer 1 (hint matches intent?): yes — criterion is "login returns 401 without password," hint is the targeted test. Type and specificity correct. Rules out A and B.
- Layer 2 (what happened?): the test ran, got 200, expected 401. The agent's `.out` shows it added the route but did not add the password check. **Root cause: C** — the agent did not implement the requirement.

**Recommendation:**

> The hint is correct and the test asserts the right thing. The agent's iteration 3 ended with the route returning 200 because the password validation was never added. Tighten task-2's description: replace "implement the login endpoint" with "implement the POST /login handler in src/auth/login.rs, returning 401 when the request body has no `password` field and 200 only when the password matches the stored hash." That edit changes the PRD file's SHA-1, so the next `zurdo run <prd>` will hit a `prd_hash` mismatch and exit 4 — this is a hand-edit to a task description, not a `zurdo heal`-made change, so there is no heal-log chain to reconcile it; run `zurdo run <prd> --reset` (or accept the `[X] Reset` choice at the interactive prompt) to pick the description change up.
