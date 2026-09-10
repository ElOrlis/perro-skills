# phases

Phase lifecycle: definition, status transitions, PRD authoring, publishing, running, reviewing, and the worked timeline.

---

## What a phase is

A phase is one unit of deliverable work inside an initiative:

- One PRD file at `docs/<initiative>/prds/prd-NN-<phase>.md`.
- One GitHub milestone and one GitHub epic, both inside the initiative's Project.
- One row in the `## Phases` table in `scope.md` with id `phase-NN`, where `NN` matches the PRD number.

Only one phase is `running` at a time. Milestones and epics for later phases are created when those phases' PRDs are published, not when the phases are first charted.

---

## Status transitions

```
planned → researching → ready → running → done
```

| Status | Meaning | Who sets it |
|---|---|---|
| `planned` | Charted in scope; no PRD written; no blocking tickets. | Agent, during breadth interview. |
| `researching` | At least one open ticket has `blocks: [phase-NN]`. | Agent, when the blocking ticket is opened. |
| `ready` | No open blocking tickets; PRD may be written. | Agent, when the last blocking ticket resolves. |
| `running` | PRD published; `zurdo run` is in progress. | Agent, after `publish --scope <n>` succeeds. |
| `done` | Every Zurdo task is `passed`; `sync-status` completed; phase review done. | Agent, after phase review closes. |

**Only one phase may be `running` at a time.** If a phase is `running`, do not advance any other phase to `running` until the current one reaches `done`.

**`researching` requires an open ticket.** A phase with no blocking tickets is never `researching`. When the last blocker resolves, flip the status to `ready` immediately.

**`ready` does not mean the PRD is written.** It means the preconditions for writing it are satisfied. The status moves to `running` only after the PRD is published, not when it is authored.

---

## Writing the phase PRD

### Preconditions

Before invoking `zurdo-prd-author`:

1. The phase row in `scope.md` has `Status: ready`.
2. `zurdo-prd-author` is present (required skill; stop the run if missing).
3. All research tickets whose `blocks:` list includes this phase are `resolved`.

### Sequence

0. **Design record (optional)** — when the phase must choose between approaches on evidence rather than taste, or the decision will outlive its author, invoke `zurdo-design-author` first to write `docs/<initiative>/design/<topic>.md`. Its phase-4 exit criteria become the requirements `zurdo-prd-author` grills into criteria. Skip when the phase's scope row and resolved tickets already settle the approach.
1. **Author** — invoke `zurdo-prd-author`. One interview covers intent, evidence inventory, task grouping, §2.2 grammar, and the four-layer review; there is no separate decomposer or reviewer step. The author reads every research ticket linked in the `## Background` section; confirm those links are present before invoking. Hand it the phase's scope row and resolved tickets as the intent document.
2. **Ready verdict** — the interview stops on `✓ READY TO RUN`. Any other verdict means the PRD is not done; keep grilling, never relax a hint to pass the gate.
3. **Commit** — commit the PRD, its `<prd-name>.trail.md` sidecar, and any `lessons/lesson-*.md` files the author emitted in one commit. That commit is the human review gate before publish.
4. **Validate** — run `zurdo validate` against the authored PRD as a final check before publishing. Fix any schema errors before proceeding.

### Required PRD content

- **Intro / Background**: links every research ticket the PRD relied on (repo-relative paths); names the destination this phase advances.
- **Tasks**: each task that touches a skill-covered area carries a `Skills:` line naming the applicable skill(s).

---

## Publishing a phase

Run these commands in order. Always `--dry-run` first.

```bash
# One-time per repo (skip if already bootstrapped)
zurdo-github.sh bootstrap

# Preview the publish
zurdo-github.sh publish --dry-run --scope <n>

# Live publish: creates milestone, epic, task issues, enrolls them in the Project
zurdo-github.sh publish --scope <n>

# Create or update the Project board (also links it to the repo)
zurdo-github.sh board --project "<initiative title>"

# Refresh the scope issue and the Project description/README to reflect the new running phase
zurdo-github.sh scope --dry-run
zurdo-github.sh scope
```

After `publish --scope <n>` succeeds, flip the phase row to `Status: running` in `scope.md`.

`bootstrap` runs once per repo; it initializes the marker database. Calling it again on an already-bootstrapped repo is safe — it is idempotent.

---

## Running and syncing

```bash
# Execute the phase
zurdo run

# Preview the status sync
zurdo-github.sh sync-status --dry-run

# Mirror outcomes to GitHub issue statuses
zurdo-github.sh sync-status
```

While a run is in flight or just finished, invoke `zurdo-state-summary` for the task tally and the settled/resume/reset call; do not run `sync-status` against a run that still holds a live lock. If any task finished `failed`, invoke `zurdo-hint-debugger` on the failing criterion before touching the hint or the code by hand.

After `zurdo review` (the CLI TUI that signs off `[manual]` criteria), run `sync-status` again to catch any status changes the review step produced.

Then refresh the scope issue:

```bash
zurdo-github.sh scope --dry-run
zurdo-github.sh scope
```

**Do not declare the phase `done` until every task is `passed` and the intent review verdict is landed-as-intended.** If any task is not `passed` after `sync-status`, investigate before closing; do not manually flip the scope row.

---

## Phase review

### Trigger

A phase review begins when every Zurdo task for the running phase is `passed` after `sync-status`.

### Intent review first

Before the interview, invoke `zurdo-prd-review` against the phase PRD. Green criteria are necessary, not sufficient: a hint can pass on a change that misses the task's intent. The skill binds `.zurdo/<slug>/run-diff.patch` to each task, reads the `.trail.md` sidecar as its best intent source, and ends in one of two verdicts:

- **Landed as intended** — proceed to the interview; the per-task report is the input to Round 1.
- **Gaps exist** — the skill scaffolds `<stem>-followup.md` beside the PRD (never editing the original) and may write `lessons/` files. Commit them together, publish the follow-up with `publish --scope <n>`, run it, and `sync-status`. The phase stays `running`; re-run the intent review when the follow-up is green. Do not start the interview on a gaps verdict.

If `zurdo-prd-review` is not installed, run the interview against `prd.json` and the diff alone and record in the review notes that no intent-level review ran.

### Interview agenda

Run the phase review interview from `references/interview.md` (shape 3: Phase review interview). The agenda has three rounds:

- **Round 1** — outcomes vs. plan: what finished, what did not, what changed mid-phase; start from the intent review's per-task report.
- **Round 2** — sharpened knowledge: what was foggy that is now clear; what new fog appeared.
- **Round 3** — scope changes: what is now in scope, what is out, and why.

### What gets written

After the interview, update `scope.md` in this order:

1. **Decisions so far** — add one line per decision the phase produced that was not already recorded.
2. **Phases table** — flip the completed phase to `Status: done`; graduate the next `ready` phase if one exists.
3. **Out of scope** — add any item the review explicitly excluded, with its reason.
4. **Not yet specified** — rewrite any fog entry that the phase sharpened into a tighter question; remove any fog entry that the phase resolved.

Then refresh the scope issue:

```bash
zurdo-github.sh scope --dry-run
zurdo-github.sh scope
```

### End condition

The review ends in one of two ways:

- **Next phase named** — the review identifies a phase in `ready` status (or a phase that can now move to `ready` because its blockers resolved). Name it explicitly as the next phase to run.
- **Initiative done** — the destination is reached and no fog remains in "Not yet specified." Close the scope issue. Do not graduate a next phase.

The review is not complete until one of these two conditions is met.

---

## Specifying ahead

A later phase whose scope is already sharp gets its row in the `## Phases` table with `Status: ready` at the time it is first charted. This signals it is ready to write when the current phase finishes.

Its milestone and epic appear in GitHub **only when its own PRD is published** (via `publish --scope <n>`). Do not create the milestone or epic as placeholders. The row in `scope.md` is the only artifact that exists until then.

---

## Worked timeline

A three-phase initiative: **CSV export** → **Webhook delivery** → **Observability dashboard**.

### After charting (breadth interview complete, no PRDs written yet)

```
| Phase | Title                  | PRD                                        | Status       |
|-------|------------------------|--------------------------------------------|--------------|
| phase-01 | CSV export          |                                            | ready        |
| phase-02 | Webhook delivery    |                                            | researching  |
| phase-03 | Observability dash  |                                            | planned      |
```

- phase-01 has no blockers → `ready`.
- phase-02 is blocked by an open research ticket (`webhook-retries.md`) → `researching`.
- phase-03 scope is not yet sharp → `planned`.

### After phase-01 review

phase-01 PRD was published, run completed, every task passed, review done.
The webhook-retries ticket resolved during phase-01 execution.

```
| Phase | Title                  | PRD                                        | Status       |
|-------|------------------------|--------------------------------------------|--------------|
| phase-01 | CSV export          | docs/example/prds/prd-01-csv-export.md     | done         |
| phase-02 | Webhook delivery    |                                            | ready        |
| phase-03 | Observability dash  |                                            | planned      |
```

- phase-01 review produced one new decision (schema version in manifest); one fog item sharpened into a ticket for phase-02.
- phase-02 blocker resolved; status flipped to `ready`.
- phase-03 still fog; no change.

### After phase-02 review

phase-02 PRD published, run completed, review done.
The review sharpened the observability phase scope sufficiently.

```
| Phase | Title                  | PRD                                        | Status       |
|-------|------------------------|--------------------------------------------|--------------|
| phase-01 | CSV export          | docs/example/prds/prd-01-csv-export.md     | done         |
| phase-02 | Webhook delivery    | docs/example/prds/prd-02-webhook.md        | done         |
| phase-03 | Observability dash  |                                            | ready        |
```

- phase-03 fog resolved by the webhook delivery findings; status promoted to `ready`.
- No remaining fog; if phase-03 completes the destination, the initiative will close after its review.
