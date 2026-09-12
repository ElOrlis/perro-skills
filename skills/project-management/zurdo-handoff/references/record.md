# record

The handoff file: template, per-section rules, the graduation rule, what never goes in, and where the file lives.

---

## Template

```markdown
---
initiative: observability-export
stopped_at: 2026-09-12T18:40:00Z
station: run-and-sync        # scope | research | phase-prd | publish | run-and-sync | phase-review
phase: phase-01
by: agent                    # agent | user
---

# Handoff: Observability export

## Stopped at

<One line: the station and the phase by title, then what is applied and what is not.>

## Done this session

- <One bullet per artifact changed or script mode run, with the commit hash.>

## In flight

- <One bullet per unattended process: what, when dispatched, how to check.>

## Waiting on a human

- <One bullet per open HITL gate: the question with its ➡️ recommendation, or the command only the user can run.>

## Next action

Row <n> — <row text from zurdo-project's priority table>. Re-check before acting: <the precondition>.

## Uncommitted

Clean.

## Watch out

- <A gotcha with no home yet, naming the home it should reach.>
```

Frontmatter keys are lowercase; `stopped_at` is UTC ISO-8601 to the second; `station` is one of the six lifecycle stations in `zurdo-project`'s spelling, kebab-cased; `phase` is the `phase-NN` id from the `scope.md` Phases table, or the PRD basename in a repository without `scope.md`; `by` says who stopped.

---

## The seven sections

| Section | Holds | Rule |
|---|---|---|
| **Stopped at** | The station and the phase, one line, then what is applied and what is not ("`sync-status` applied; `zurdo review` has not run") | Name the station in `zurdo-project`'s words so the receiver and the runbook agree on where "here" is. |
| **Done this session** | One bullet per artifact changed or script mode run, each with its commit hash | Refer by name: tickets and phases by title, numbers inside links. Commits by short hash. |
| **In flight** | Work continuing with nobody watching: dispatched research subagents, a `zurdo run` holding its lock, a pushed branch awaiting review; each with when it started and how to check it | The receiver must know what may have changed underneath the handoff since the stop. |
| **Waiting on a human** | Every HITL gate open at the stop: a grilling question with its ➡️ recommendation, `zurdo review` on a named PRD, a `[manual]` sandbox check, a commit awaiting review | Carries the question so the user arrives prepared. Opens no new resolution path: a grilling ticket is still resolved live. |
| **Next action** | Exactly one: a row number and its text from `zurdo-project`'s priority table, then the precondition to re-check | One action, one existing vocabulary. The receiver verifies the precondition; it never trusts the row. |
| **Uncommitted** | `git status --short` output at the stop, verbatim, or `Clean.` | Commit before handing off. When you cannot, list every path so nothing is discovered by accident. |
| **Watch out** | Gotchas learned this session with no home yet, each naming the home | The only place a durable item may sit temporarily, and only while it says where it belongs. |

Every section is present. An empty one says `None.` on its own line. The receiver keys on the headings, and a missing heading reads as unknown, not as empty.

---

## The graduation rule

Nothing in the handoff is the only copy of something durable.

| Item | Home | Who moves it |
|---|---|---|
| A decision the session made | `scope.md` → Decisions so far | The stopping session, before the handoff commit; else the receiver, first thing |
| A correction that would otherwise be rediscovered | `lessons/lesson-<hash8>.md` through `zurdo-lessons` | Same |
| A domain fact or standing preference | `scope.md` → Notes | Same |
| A new sharp question | A ticket file under `tickets/` | Same |
| New fog | `scope.md` → Not yet specified | Same |
| A run outcome | Already in `.zurdo/<slug>/prd.json`; mirrored by `sync-status` | Nobody; cite it |

Watch out lists any item that has not reached its home, with the home named: "`board` needs `--project "Observability export"`. Belongs in `scope.md` Notes; not written there yet." When the receiver moves it, the next handoff no longer carries it. A Watch out entry that survives three handoffs is a sign the home is wrong or the item is not durable.

---

## What never goes in

- **Decisions, as decisions.** The handoff may say a decision was made and link the ticket; the decision text lives in `scope.md`.
- **Run tallies.** `prd.json` has them; `zurdo-state-summary` renders them. Say "settled: 4 passed, 1 pending-review" at most, as a pointer.
- **Findings.** They live in the ticket file's `## Findings`.
- **A plan.** Next action is one row. A list of future steps is the Phases table's job, and the receiver derives it from the files.
- **Speculation about what happened while you were gone.** In flight says what was set running and how to check it; the receiver checks.
- **Anything for GitHub.** The handoff is not projected. A teammate who reads only GitHub reads the board README that `scope` refreshes.

---

## Refer by name

In every section, name tickets and phases by their title with the path in the link, and name commits by short hash:

Correct:
> Resolved [Which webhook auth scheme](tickets/webhook-auth.md); `ticket` live, issue closed. Commit `3f2a9c1`.

Wrong:
> Resolved #14. Committed.

The receiver reads the handoff beside `scope.md`, where the same titles appear. Numbers route; titles mean.

---

## Placement

`docs/<initiative>/handoff.md`, where `<initiative>` is the directory that holds `scope.md`. One file per initiative, overwritten at every stop.

**Without `scope.md`** (a PRD-only repository), `<initiative>` is the directory that holds the `prds/` folder of the PRD the session stopped on. In this repository that is `docs/zurdo-project/handoff.md` for work on the `zurdo-project` PRD. The frontmatter's `phase` then carries the PRD basename, and `station` is one of `phase-prd`, `publish`, `run-and-sync`, or `phase-review`.

**Never** under `.zurdo/` (run state, slug-scoped, partly gitignored), never as a section of `scope.md` (the `scope` parser drops unknown H2s, and the known ones are rendered onto the board on every run), never as a GitHub comment (the receiving agent reads the repository).

---

## Freshness, from the receiver's side

The handoff is a claim about the past. `zurdo-wayfinder` marks it `fresh` when no commit touched `docs/<initiative>/` after the handoff commit and no `prd.json` in the Phases table has `last_updated` after `stopped_at`. Otherwise it is `stale`, and the receiver re-derives station and next action from the files, using the handoff only for In flight and Waiting on a human, both re-checked. Write the handoff so that a stale reading still helps: absolute timestamps, paths, commands to re-check.
