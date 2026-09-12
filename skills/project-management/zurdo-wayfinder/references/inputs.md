# inputs

The five inputs the wayfinder reads, in authority order, with the exact commands, what each proves, and the freshness test for the handoff.

---

## The authority ladder

| Rank | Input | Owner | Proves | Does not prove |
|---|---|---|---|---|
| 1 | `docs/<initiative>/scope.md`, `tickets/*.md` | `zurdo-project` | Destination, phase statuses, which tickets are open and what they block | That the statuses are current: the agent flips them by hand |
| 2 | `.zurdo/<slug>/prd.json`, `.zurdo/<slug>/lock` | `zurdo` | Per-task terminal state, attempts, `last_updated`; whether a run is live | Intent (that is `zurdo-prd-review`'s question) |
| 3 | `git status`, `git log` | git | What is uncommitted; what changed since a point in time; the handoff commit | Changes another machine has not pushed |
| 4 | `docs/<initiative>/handoff.md` | `zurdo-handoff` | One session's claim: station, In flight, Waiting on a human, one next action | Anything after `stopped_at` |
| 5 | GitHub assignees, read-only | `zurdo-github` projection | Who has claimed which ticket or task | Anything about state; GitHub is a projection |

When two inputs disagree, the higher rank wins and the report names the disagreement in the line where it matters: "`scope.md` says phase-02 `researching`; its only blocker `webhook-retries.md` is `resolved` — the row is stale, phase-02 is `ready`." The wayfinder does not fix the file; it names the fix as part of the next action's first step.

---

## 1. The map

```bash
ls docs/*/scope.md
```

One match, or the one the user named. Read:

- `## Destination` — the first sentence becomes the report's second line.
- `## Phases` — every row: `phase`, `title`, `prd`, `status`. A status outside `planned|researching|ready|running|done` is a parse error the `scope` run would reject; report it under `Do not` ("run `scope --dry-run`; it will exit 2 on this row").
- `## Not yet specified` — count only; fog is not the wayfinder's to sharpen.
- Every `tickets/*.md` frontmatter: `type`, `question`, `status`, `blocks`. Open grilling tickets go to `Waiting on a human` or row 1; open research tickets with `blocks:` explain a `researching` row; a `resolved` ticket whose blocked phase is still `researching` is a stale row.

---

## 2. Run state

```bash
zurdo state list                      # slug | prd_path | last_run | status
zurdo state where <prd>               # resolve one PRD to its slug directory
ls .zurdo/*/lock 2>/dev/null          # a live run
```

Without `zurdo` on `PATH`: `ls .zurdo/*/prd.json` and read `prd_path`, `last_updated`, and `tasks.*.status` with `jq`.

For each PRD in the Phases table:

- **No run directory** → `no run`. With the phase `running`, that is row 5.
- **`lock` present** → `in flight`. Row 6; `sync-status` is forbidden (`Do not`).
- **No lock, every task `passed` or `passed-pending-review`** → `settled: <tally>`. Row 8.
- **No lock, any task `failed` or `blocked-by-dependency`** → `settled with failures: <tally>`. Row 7.
- **`progress.log` has an `iteration_start` with no matching `task_status` and no lock** → a crashed iteration; say so, still row 7 or 8 by the tally.

**Delegate when `zurdo-state-summary` is installed.** Invoke it for the running phase's PRD and quote its headline and recommended verb in the phase row. It is run-scoped by design and says so; the wayfinder adds the initiative frame around it. Without it, tally by hand and say "tally by hand; `zurdo-state-summary` not installed."

---

## 3. Git

```bash
git status --short
git log --oneline -1 -- docs/<initiative>/handoff.md              # the handoff commit
git log --oneline --since=<stopped_at> -- docs/<initiative>/ .zurdo/   # what moved after it
```

- A dirty tree goes under `Do not` as "commit or discard before any script mode" and the paths are listed. Dirty `.zurdo/` from a live run is named as such and excluded from that advice.
- The log since `stopped_at` feeds the freshness test and the `Since the handoff` block.

Git cannot see another machine's unpushed work. Say so once in the report when the initiative is known to be worked from more than one machine (a `Notes` line, or more than one author in `git log -- docs/<initiative>/`).

---

## 4. The handoff

```bash
cat docs/<initiative>/handoff.md
```

Read the frontmatter (`stopped_at`, `station`, `phase`, `by`) and the seven sections. Then verify:

### Freshness test

The handoff is **fresh** when both hold:

1. No commit touched `docs/<initiative>/` after the handoff commit (`git log --oneline <handoff-commit>..HEAD -- docs/<initiative>/` is empty).
2. No `prd.json` for a PRD in the Phases table has `last_updated` later than `stopped_at`.

Otherwise it is **stale**. Absent, it is **none**.

| Verdict | Use the handoff for | Re-derive from ranks 1 to 3 |
|---|---|---|
| fresh | Station, In flight (re-checked), Waiting on a human (re-checked), Next action (precondition re-checked), Watch out | Nothing, but every re-check still runs |
| stale | In flight (re-checked), Waiting on a human (re-checked), Watch out | Station and Next action; list what changed under `Since the handoff` |
| none | Nothing | Everything; `Handoff: none` in the report, no other remark |

A fresh handoff whose Next action precondition fails on re-check is reported as fresh with a corrected next action: "handoff named row 8; `lock` now present, so row 6."

### Re-checking In flight

| Entry | Check |
|---|---|
| Research subagent on a ticket | `status:` in the ticket file; `## Findings` present. `resolved` → row 2 precedes whatever the handoff named. |
| `zurdo run` | `lock` present → still in flight. Absent → settled; tally decides row 7 or 8. |
| A pushed branch awaiting review | `git log origin/<branch>` if fetched; otherwise say "not checked: no fetch in a read-only pass." |

### Re-checking Waiting on a human

| Entry | Check |
|---|---|
| Grilling question | Ticket still `open` → still waiting. `resolved` with `## Findings` → the user answered; row 2 absorbs it. |
| `zurdo review` due | Any task still `passed-pending-review` → still due. All `passed` → done; row 8 continues at `sync-status`. |
| Commit awaiting review | The named files still uncommitted or unpublished → still waiting. |

---

## 5. Claims

```bash
gh auth status
gh issue view <n> --json assignees --jq '.assignees[].login'
```

Read-only. For each open ticket issue and each open task issue of the running epic (numbers from the scope issue's Phases table or from the `zurdo-github` markers), list the assignee. Skip the whole section with a one-line reason when `gh` is absent, unauthenticated, or the repository has no scope issue yet: "Claimed: not read — gh not on PATH." Never call `gh issue edit`; claiming is the acting session's job, by assignment, as `zurdo-project` prescribes.

---

## PRD-only mode

No `docs/*/scope.md`. Locate PRDs with run state:

```bash
ls docs/*/prds/*.md
zurdo state list            # or ls .zurdo/*/prd.json
```

One report block per PRD directory that has a run: the PRD title, the tally, `lock` or not, the handoff at `docs/<dir>/handoff.md` if any. The next action is one of `zurdo-state-summary`'s six verbs (resume, fix-then-resume, heal, verify, reset, review), taken from that skill when installed and derived by its own rules when not. There are no rows because there is no Phases table; say so once.
