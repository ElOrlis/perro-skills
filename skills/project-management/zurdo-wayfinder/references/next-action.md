# next-action

How the wayfinder picks exactly one next action: the ten `zurdo-project` rows with the check that selects each and the check that blocks it, the six run verbs for PRD-only repositories, the `Do not` catalogue, and who acts.

The row text below is `zurdo-project/references/runbook.md`, "Every later session", step 3. That table is canonical. When this file and it disagree, the runbook wins and this file is what changes.

---

## The ten rows

Walk them in order; the first row whose select-check holds and whose block-check does not is the next action. Name the runner-up in the `Checked` line when a second row also holds.

| Row | Runbook condition | Select when (observed in the files) | Blocked when | Acts |
|---|---|---|---|---|
| 1 | An open grilling ticket exists | Any `tickets/*.md` with `type: grilling`, `status: open` | The user is not present: report it under `Waiting on a human` and continue to row 2 | `zurdo-project`, live with the user |
| 2 | A research ticket is `resolved` but `scope.md` does not reflect it | A ticket with `status: resolved` whose `blocks:` phase is still `researching`, or whose question has no line in Decisions so far | Never; this row is always safe | `zurdo-project` |
| 3 | A phase is `ready` and no PRD exists for it | Phases row `ready` with an empty PRD column, or a PRD path that does not exist on disk | A ticket with `blocks: [that phase]` is still `open` (the row is stale; fix it first, row 2 territory); `zurdo-prd-author` not installed (stop message) | `zurdo-prd-author`, invoked by `zurdo-project` |
| 4 | A PRD exists and the phase is `ready` | Phases row `ready` with a PRD path that exists and is committed | The PRD, its `.trail.md`, or `lessons/` are uncommitted; `zurdo validate` would fail | `zurdo-project` → `zurdo-github` modes |
| 5 | A phase is `running` and no `.zurdo/<prd-basename>-*/` exists | Phases row `running`; no matching state directory | Dirty tree with uncommitted PRD edits (the run baselines the tree) | `zurdo run`, started by the user or `zurdo-project` |
| 6 | A phase is `running` and `zurdo run` is in flight | `lock` present, or `progress.log` has an unmatched `iteration_start` | Never; the action is to wait | Nobody; report and stop |
| 7 | The run finished with `failed` or `blocked-by-dependency` tasks | No lock; any task `failed` or `blocked-by-dependency` | Never | `zurdo-hint-debugger`, then `zurdo run --resume`; `sync-status` first so GitHub shows the failure |
| 8 | The run is settled with every task `passed` or `passed-pending-review` | No lock; every task terminal-pass | A `passed-pending-review` task blocks the final `sync-status` until `zurdo review` runs: the human step comes first | `zurdo-state-summary`, the user (`zurdo review`), `zurdo-project` (`sync-status`, `scope`), `zurdo-prd-review` |
| 9 | `zurdo-prd-review` returned a gaps verdict | `<stem>-followup.md` exists beside the PRD and has no state directory | The follow-up and its `lessons/` are uncommitted (human review gate) | `zurdo-project` → `zurdo-github publish --scope <n>`, `zurdo run` |
| 10 | `zurdo-prd-review` returned landed-as-intended | The handoff or the review output records the landed verdict, and the phase row is still `running` | Never | `zurdo-project`, the phase review interview, live with the user |

Two rows the files cannot select alone:

- **Rows 9 and 10** depend on a verdict that lives in the review's output, not in a file `zurdo` writes. Read it from the handoff's Done this session or Waiting on a human when fresh; otherwise, after row 8's `sync-status`, the next action is "invoke `zurdo-prd-review`" and the verdict decides the following session.
- **Row 1 with the user absent** is not skipped silently; it appears under `Waiting on a human` and the wayfinder continues down the table.

---

## When no row selects

- **Every phase `done` and no fog** → the initiative is complete; the next action is `zurdo-project`'s end condition: final `scope` refresh, then close the scope issue with the one permitted direct `gh` write. Name it as "initiative done", not as a row.
- **Every phase `planned` or `done`, none `ready`** → nothing is sharp enough to write; the next action is the breadth or phase-review interview that graduates a phase (`zurdo-project/references/interview.md`). Name it as "graduate a phase", not as a row.
- **A `running` phase whose PRD path is missing on disk** → a parse-level problem; `Do not` says "fix the Phases row before any script mode; `scope --dry-run` exits 2", and the next action is that fix.

---

## The six verbs (PRD-only mode)

Without a Phases table there are no rows. Use `zurdo-state-summary`'s vocabulary, one per PRD, and take it from that skill when installed:

| Verb | When |
|---|---|
| resume | Non-terminal tasks wait on something runnable; no error blocks |
| fix-then-resume | A task `failed` and the failure looks fixable; `zurdo-hint-debugger` for hints, the description for prompt-level fixes |
| heal | Failures are on mis-aimed `[grep:]` or `[no-grep:]` payloads; `zurdo heal <prd>` |
| verify | Everything terminal-pass and unchanged; `zurdo verify <prd>` re-runs criteria token-free |
| reset | `prd_hash` mismatch with no valid heal-log chain, or `schema_version` mismatch |
| review | Everything terminal-pass, `passed-pending-review` tasks exist; `zurdo review <prd>` |

Never invent a seventh.

---

## The `Do not` catalogue

Each entry is a move plus the observed fact that blocks it. List only the ones whose fact is true right now.

| Move | Blocked by |
|---|---|
| `sync-status` | A `lock` under the PRD's state directory; or a `passed-pending-review` task when `zurdo review` has not run and the handoff says review is due |
| Write a phase's PRD | Any `open` ticket with `blocks: [that phase]`; or the phase row not `ready` |
| Any `zurdo-github.sh` live mode | A dirty tree (paths listed); or the dry-run has not been read this session |
| `zurdo run` | Uncommitted PRD or trail edits (the run baselines the tree); or a phase other than the one `running` |
| `zurdo run --reset` | A heal-log chain that would reconcile in place; or the user did not ask for a fresh run |
| Answer a grilling ticket | Always; the user answers, the agent records |
| Edit `scope.md` from GitHub state | Always; files are truth |
| `board` without `--project "<initiative title>"` | Always when an initiative Project exists; a second board is created otherwise |
| Close the scope issue | Fog remains in Not yet specified, or a phase is not `done` |

When nothing applies, the section reads `nothing blocks`.

---

## Who acts

The report's last line names the skill or person whose move is first. The wayfinder never takes it.

| First step | Acts |
|---|---|
| Claim and interview on a grilling ticket; absorb research; publish; sync; refresh `scope`; phase review | `zurdo-project` |
| Author a PRD | `zurdo-prd-author`, invoked by `zurdo-project` |
| Diagnose a failing criterion | `zurdo-hint-debugger` |
| Confirm a run is settled; tally | `zurdo-state-summary` |
| Intent review after a green run | `zurdo-prd-review` |
| `zurdo review`, a grilling answer, a `[manual]` sandbox check, the commit review gate | The user |
| Start `zurdo run` | The user, or `zurdo-project` when the user has said to run |

Name the first actor; when the user's step comes first, say "you" and what follows once they have acted.
