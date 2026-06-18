---
name: zurdo-hint-debugger
description: "Diagnose a failing Zurdo acceptance criterion by correlating its hint, the iteration logs under .zurdo/<slug>/iterations/, and the current working tree — then propose a corrected hint or a corrected code change."
allowed-tools: [Read, Bash, Edit]
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

The answers map to one of four root causes — pick the one that fits and act on it.

## Root cause taxonomy

### A. Wrong hint type

The hint cannot in principle prove the criterion. Examples:

- Criterion: "API returns 401 for unauthenticated requests." Hint: `[file-exists: src/auth.rs]`. The file existing proves nothing about the response.
- Criterion: "rate limit is 100 req/min." Hint: `[shell: cargo test rate_limit]` — fine *if* the test asserts the threshold; broken if it only asserts that *some* rate limiting exists.

**Fix.** Rewrite the hint to a type that can prove the criterion. Reference the hint table in §3.1:

| If the criterion is about… | Use… |
|---|---|
| code under test                   | `[shell: <test cmd>]` |
| HTTP endpoint status               | `[http: <method> <url> -> <status>]` |
| file or directory presence         | `[file-exists: <path>]` |
| file or directory absence          | `[file-absent: <path>]` |
| specific string in a file          | `[grep: <pattern> in <file>]` |
| specific string absent in a file   | `[no-grep: <pattern> in <file>]` |
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
- If the task is too large, split it (reference [[zurdo-prd-decomposer]]).
- If the agent ran out of attempts, raise `Max-Attempts` for this one task — but only if you believe the next attempt has new information from the prior-iteration tail (§7.4).

### D. Hint and code are both correct; the criterion ran against the wrong state

The hint passed locally but failed under `zurdo run`. Common causes:

- **Working directory.** All `[shell:]` and `[http:]` hints run at repo root (§3.3). A criterion that depends on `cd frontend && npm test` must include the `cd`.
- **Side effects from prior tasks.** Task A mutated a file Task B's criterion now greps; Task B's pre-flight check picks up the mutation. Re-read the dependency edges in [[zurdo-prd-reviewer]] layer 3.
- **Timeout.** Look for `"timed_out": true` in the criterion result. If the criterion legitimately needs more than `timeouts.criterion_seconds` (default 300s), raise the config knob — there is no per-criterion override in v1.
- **Transient HTTP failure.** A `[http:]` against a service that wasn't ready at criterion-time. Recommend wrapping in `[shell:]` with a retry loop, or hardening the service start sequence.

**Fix.** Edit the hint to match the run-time environment, or fix the environment.

## Procedure

1. **Read the criterion.** Open the PRD; locate the failing criterion's source text and surrounding task description.
2. **Read the result.** Either `progress.log` (the `criterion_result` event) or `prd.json` (the `criteria_results` entry on the most recent iteration). Note the `passed: false`, the `exit_code`/`stdout_truncated`/`stderr_truncated`, and the `duration_ms`. **For local hints** (`grep`, `no-grep`, `file-exists`, `file-absent`) `stderr_truncated` now carries a human-readable failure reason — `pattern not matched`, `pattern matched at line <n>`, `cannot read <file>: <io-error>`, `path does not exist`, or `path exists` — so you can often classify without reproducing. Shell/HTTP hints put the real command stderr/stdout there instead.
3. **Read the iteration.** Open `.zurdo/<slug>/iterations/<task-id>-<attempt>.out` and `.err` for the full agent narrative. The truncated fields in `prd.json` are 4KB head+tail captures (first 1KB + last 3KB joined by a `[... <n> bytes omitted ...]` seam); the full files have the rest.
4. **(Optional) Reproduce locally.** Run the hint by hand — `bash -c '<the shell cmd>'` for `[shell:]`, `curl -s -o /dev/null -w "%{http_code}" <url>` for `[http:]`, `test -e <path>` for `[file-exists:]`, `! test -e <path>` for `[file-absent:]`, `grep -q <pattern> <file>` for `[grep:]`, `! grep -q <pattern> <file>` for `[no-grep:]`. Compare to what the run saw.
5. **Classify** as A / B / C / D above.
6. **Recommend** the fix in one of two shapes:
   - **Hint-side fix** (A, B, D): name the file and line, give the new hint text verbatim, optionally apply it with Edit.
   - **PRD-side fix** (C): name the task and the change to the description; do not edit the hint.
7. **Next step.** Tell the user to re-run `zurdo run <prd>` once the fix is committed to the PRD on disk (Zurdo re-reads the PRD on each invocation; `prd_hash` will update accordingly if the change is substantive — §5.5).

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

> The hint is correct and the test asserts the right thing. The agent's iteration 3 ended with the route returning 200 because the password validation was never added. Tighten task-2's description: replace "implement the login endpoint" with "implement the POST /login handler in src/auth/login.rs, returning 401 when the request body has no `password` field and 200 only when the password matches the stored hash." Then `zurdo run <prd>` again — the agent will pick the description change up on the next iteration since `prd_hash` will re-validate.
