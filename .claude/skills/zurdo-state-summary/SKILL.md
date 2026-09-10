---
name: zurdo-state-summary
description: "Read .zurdo/<slug>/prd.json and progress.log to produce a short human summary of run state — task tallies, what's stuck, what's pending review, and the recommended next action (resume, reset, or fix-then-resume)."
allowed-tools: [Read, Bash]
disable-model-invocation: true
---

## When to invoke

Invoke this skill when the user wants to know **what state a Zurdo run is in** without reading the raw JSON themselves. Typical entry points:

- After a `zurdo run` exits non-zero and the user asks "what happened?"
- Before a resume — the user wants to decide between `--resume`, `--reset`, or fixing the PRD first.
- After several iterations, to spot which tasks are eating budget on retries.
- When jumping back into a project after time away.

You are summarizing, not executing. Do not run `zurdo run`, do not modify state files, do not delete `.zurdo/<slug>/`. Read-only with one allowed mutation: `Bash` may invoke `zurdo state list` and `zurdo report` for richer output where useful.

## Where state lives

State lives under the user's repo root, not beside the PRD (§5.2, §2.4):

```
<repo-root>/.zurdo/<slug>/
├── prd.json               # terminal-state source of truth (atomic writes)
├── progress.log           # append-only JSONL event stream
├── iterations/
│   ├── <task-id>-<attempt>.out      # full agent stdout
│   ├── <task-id>-<attempt>.err      # full agent stderr
│   └── <task-id>-<attempt>.prompt   # prompt sent on stdin
├── reports/<timestamp>.<json|md>
├── reason/                 # per-run reason-block diagnoses, when enabled
├── .archive/                # prior state, preserved by `--reset`
├── lock                    # pid + start time of any active run
├── analyze-iterations/      # the `--analyze --fix` loop's audit trail
├── baseline                # run-start baseline-tree record
├── baseline.index          # scratch git index the baseline capture builds
├── baseline-diff.index     # scratch git index a baseline comparison builds
├── run-diff.patch          # full unified diff written at the end of a run
└── review-log.jsonl        # tamper-evident append-only `zurdo review` log
```

`<slug>` is `<basename>-<hash4>` where `hash4 = sha1(repo-relative-prd-path)[0..4]`. If you do not know the slug, run `zurdo state list` (shows every state dir with `slug | prd_path | last_run | status`) or `zurdo state where <prd>` (resolves a PRD to its state dir without requiring it to exist).

Two reason-and-lessons paths are slug-independent and live outside any `.zurdo/<slug>/` directory: `lessons/lesson-<hash8>.md` — the repository-scoped lesson library at the **repo root**, git-tracked source, not run state — and `.zurdo/reason/usage.json` — the reuse-metadata sidecar, shared across every PRD's runs rather than scoped to one slug directory.

## The two files

**`prd.json`** is the source of truth for terminal-state. Schema highlights (§5.2):

- `schema_version`, `prd_path`, `prd_hash`, `started_at`, `last_updated`.
- `tasks.<task-id>.status` — one of: `pending`, `blocked`, `in-progress`, `passed`, `passed-pending-review`, `failed`, `blocked-by-dependency`.
- `tasks.<task-id>.attempts` — running total of completed attempts.
- `tasks.<task-id>.iterations[]` — append-only per-attempt detail: model, exit code, agent stdout/stderr paths and byte counts, tokens in/out, cost USD estimate, per-criterion results.
- `tasks.<task-id>.iterations[].criteria_results[]` — per-hint pass/fail with `duration_ms`, `exit_code`, and 4KB truncated stdout/stderr tails.

**`progress.log`** is append-only JSONL, one event per line (§6.1). The event types form a closed enum: `run_start`, `run_complete`, `iteration_start`, `agent_invoked`, `agent_completed`, `criterion_result`, `task_status`, `transient_retry`, `lock_stale`, `out_of_tree_refs`, `task_stalled`, `diagnosis_outcome`. Pair `task_id` + `attempt` to match `iteration_start` with the eventual `task_status`. An `iteration_start` with no matching `task_status` is an in-flight (or crashed) iteration. `out_of_tree_refs` (a capture named a path outside the repo root), `task_stalled` (the same failure fingerprint repeated across consecutive attempts), and `diagnosis_outcome` (a reason-block diagnosis call concluded, accepted or discarded) are the reason subsystem's observable output — surface them when a task is stuck and `[reason]` is enabled.

## What to surface

A good summary covers these in order:

1. **One-line headline.** `Run <last_updated>: <N> passed, <M> pending-review, <K> failed, <J> blocked, <L> pending.` Match the tone of `zurdo state list`.
2. **Per-task table** for non-terminal-pass tasks (`failed`, `blocked-by-dependency`, `in-progress`, `blocked`, `pending`). Columns: task id, status, attempts/max, last failing hint (if `failed`). Skip the body of the table when every task is `passed` / `passed-pending-review` — say "all tasks reached a terminal-pass state" instead.
3. **For each `failed` task**, surface:
   - The most recent iteration's `agent_exit_code` and `duration_ms`.
   - The failing criteria from the last attempt with their hint + truncated stderr (4KB tail from `prd.json`, or the full `.err` file if the user wants more).
   - The path to the iteration files for deep-dive: `.zurdo/<slug>/iterations/<task-id>-<attempt>.{out,err}`.
4. **For `passed-pending-review` tasks**, name the `[manual]` criteria that still need eyes — the run will not auto-revisit them, the human review is out-of-band (§4.1, §4.2).
5. **In-flight detection.** If `progress.log` contains an `iteration_start` event with no matching `task_status` and no active `lock`, surface it: an iteration crashed mid-run. On resume that attempt is discarded (§6.2 step 4) and re-entered without consuming budget.
6. **Token / cost rollup** (when present). Sum `tokens_in`, `tokens_out`, `cost_usd_est` across all iterations. Use `—` when fields are `null` (some adapters don't extract them; pricing table covers a subset of models — §7.7, §7.8).
7. **Recommended next action.** Pick exactly one of:
   - **resume** — there are non-terminal tasks (`pending`, `blocked`) waiting on something runnable; no errors block resumption. Suggest `zurdo run <prd>` (resume is the default when state exists; interactive prompt offers `[R/X/A]` — §6.2).
   - **fix-then-resume** — at least one task is `failed` and the failure looks fixable. Point at [[zurdo-hint-debugger]] for hint-level fixes and at the PRD description for prompt-level fixes. `prd_hash` is a SHA-1 over the whole PRD file (`state/integrity.rs`), so any byte change to the file mismatches it on the next `zurdo run <prd>` — not just a change to task structure. That mismatch is not itself a reason to `--reset`: if the edit was made through `zurdo heal` (see the **heal** entry below), the run reconciles it in place.
   - **heal** — one or more `failed` tasks are failing specifically on `[grep:]`/`[no-grep:]` criteria whose payload looks mis-aimed, not on an implementation gap. `zurdo heal <prd>` uses the analyzer role to propose re-aimed hint payloads, verifies each proposal, and applies verified heals — interactively on a TTY, or to a sibling `<prd>.proposed.md` on non-TTY/`--no-prompt` — writing a tamper-evident `heal-log.jsonl` hash chain as it goes. The next `zurdo run <prd>` sees the resulting `prd_hash` mismatch, validates that chain against the stored hash and the live file, and — on a valid chain — reconciles in place: advances the stored `prd_hash`, flips the healed tasks from `failed` back to `pending` with `attempts` reset to 0 while retaining `iterations[]` for the forensic record, and archives the consumed log (`bootstrap.rs`, `state/reconcile.rs`). Requires `[roles.analyzer]` (exit 3 otherwise).
   - **verify** — every task the user cares about is already terminal-pass and nothing has changed since the last run finished, but the user wants to confirm the results still hold (e.g. after further manual edits). `zurdo verify <prd>` re-runs every terminal-passing task's acceptance criteria against the current working tree without invoking the executor — fast and token-free.
   - **reset** — the PRD's `prd_hash` no longer matches and there is no `heal-log.jsonl` chain that validates against it (tamper, or an edit made outside `zurdo heal`), a `schema_version` mismatch is logged (fatal — v1 has no migration path, §16), or the user explicitly wants a fresh run. `zurdo run <prd> --reset` archives `.zurdo/<slug>/` under `.zurdo/<slug>/.archive/<UTC-timestamp>/` and starts over (§5.5). State is preserved indefinitely; users can clean `.archive/` themselves.
   - **review** — every task is in a terminal-pass state, but `passed-pending-review` tasks exist. Point the user at `zurdo review <prd>` — the interactive walker that signs off `[manual]` criteria: each sign-off appends a tamper-evident record to `.zurdo/<slug>/review-log.jsonl`, and signing off a task's last unsigned `[manual]` criterion flips that task's status from `passed-pending-review` to `passed`. Sign-offs are irrevocable.

## Procedure

1. **Locate the state dir.**
   - If the user names a PRD path, `Bash`-invoke `zurdo state where <prd>`.
   - If the user names nothing, `Bash`-invoke `zurdo state list` and ask which slug to summarize (or pick the most recent `last_run` if it is unambiguous).
2. **Read `prd.json`.** Note `schema_version` first — a mismatch is fatal (v1 has no migration path, §16) and requires `--reset`. A `prd_hash` mismatch is different: it does not by itself mean the state is unusable — check `.zurdo/<slug>/heal-log.jsonl` before recommending `--reset` (see the **heal** and **reset** next actions above). If schema is current, walk `tasks` and tally statuses.
3. **Read `progress.log`.** Optional but recommended for in-flight detection (item 5 above) and to surface `transient_retry` storms (frequent transient retries indicate provider rate-limit pressure, not user error).
4. **(Optional) Run `zurdo report <prd> --format md`** for a richer rendered view — useful when the failing-criteria detail in `prd.json` is too dense to paraphrase. The report command is read-only; it builds output from `prd.json` and emits to stdout.
5. **Compose the summary** in the order above. Keep it tight — a paragraph for the headline, a short table for non-pass tasks, one block per `failed` task, one block of recommendations. Skip sections that are empty.

## Output shape

A worked example for a partial run with one failure and one pending-review task:

```
Run last updated 2026-05-26T18:42:11Z
  3 passed · 1 passed-pending-review · 1 failed · 0 blocked · 2 pending

Non-terminal tasks
  task-rate-limit       failed                  3/3 attempts
  task-docs-update      pending                 0/3 attempts
  task-release-notes    pending                 0/3 attempts

task-rate-limit — failed after 3 attempts
  Last iteration: exit 0, duration 184s, model claude-sonnet-4-6
  Failing criterion: [shell: cargo test --test rate_limit]
    stderr (tail): assertion `left == right` failed
                     left: 200
                    right: 429
  Deep-dive: .zurdo/auth-a1b2/iterations/task-rate-limit-3.{out,err}

task-acceptance-copy — passed-pending-review
  Manual criterion outstanding: "tone matches house style [manual]"

Rollup
  Tokens in:  41,800 · out: 27,209
  Cost est:   $0.87

Recommended next action: fix-then-resume
  task-rate-limit's hint is correct (targets the right test) but the agent
  hasn't implemented the threshold check. Tighten task-rate-limit's
  Description to specify the 100 req/min threshold and the 429 status, then
  `zurdo run <prd>`. See [[zurdo-hint-debugger]] for the full diagnosis flow.
```

Match this density: enough to act on, short enough to read in one sitting.

## Common diagnostic shortcuts

- **Lots of `transient_retry` events in `progress.log`** ⇒ provider rate-limit pressure or network flakiness, not user error. Transient retries do not consume `Max-Attempts` (§5.4); recommend the user re-run later rather than reset.
- **`lock_stale` events** ⇒ a prior run crashed without releasing the lock; Zurdo recovered and overwrote it. Informational; no action needed.
- **`prd_hash` mismatch on resume** ⇒ `prd_hash` is a SHA-1 over the whole PRD file, so *any* byte change trips it, not only a structural one. Check `.zurdo/<slug>/heal-log.jsonl` first: if its hash chain validates against the stored `prd_hash` and the live file, `zurdo run <prd>` reconciles in place — advances the hash, flips the healed tasks back to `pending`, retains `iterations[]`, and archives the consumed log — with no `--reset` needed. Only recommend `--reset` (or `[X]` in the interactive prompt) when no such log exists or it fails to validate; v1 has no surgical preservation of unchanged tasks otherwise (§16).
- **All tasks `passed-pending-review`** ⇒ likely an all-`[manual]` PRD (§3.2); the executor was never invoked. That's by design — confirm the user expected it.
- **One task at `Max-Attempts` with the same failing criterion every iteration** ⇒ classic case for [[zurdo-hint-debugger]]; either the hint is wrong or the description doesn't give the agent enough specifics.
