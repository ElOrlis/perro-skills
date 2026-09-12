# situation-report

The wayfinder's output: one fixed shape, four worked variants.

---

## The shape

```
Wayfinder — <Initiative title> (docs/<initiative>/)
Destination: <first sentence of ## Destination>

  <phase>  <title>  <status>  <prd basename or —>  <run column>

You are here: <Station>, <phase>.
Handoff: fresh | stale — <what changed> | none.
Since the handoff: <one line per commit or prd.json change>      (stale only)

In flight (re-checked)
  <entry — current state>

Waiting on a human
  <entry>

Claimed
  <ticket or task title — login>  |  none  |  not read — <reason>

Do not
  <move — the fact that blocks it>

Next action: row <n> — <row text>.
  Checked: <precondition, as observed>
  First command: <one command>
  Acts: <skill, or the user>
```

Rules for filling it:

- **Phase rows** come from the Phases table in file order. The run column is `settled: <tally>`, `in flight`, `no run`, `blocked by: <ticket title> (open)`, or `—` for `planned` and `done`.
- **You are here** is the running phase's station. With no running phase, it is the station the next action starts: `research` when tickets are open, `phase-prd` when a phase is `ready`, `phase-review` when the last run settled green.
- **Sections that are empty say `none`** on one line. `Do not` says `nothing blocks` when nothing does.
- **Next action is one row.** When two rows both apply, the lower number wins, per the runbook's priority order, and the second is named in the `Checked` line as what follows.
- **Density.** Match `zurdo-state-summary`: a headline, a short table, one block per section, one recommendation. Skip nothing; pad nothing.

---

## Variant 1 — fresh handoff

The example initiative, one session after the handoff in `zurdo-handoff/examples/handoff.md` was written. Nothing changed overnight.

```
Wayfinder — Example Initiative (docs/example/)
Destination: Build a CLI tool that exports observability data from the monitoring system to CSV, then posts the report to a configured webhook endpoint.

  phase-01  CSV export        running      prd-01-csv-export.md   settled: 4 passed · 1 pending-review
  phase-02  Webhook delivery  researching  —                      blocked by: What retry and backoff policy do the target webhooks expect? (open)

You are here: Run and sync, phase-01.
Handoff: fresh — committed 3f2a9c1 at 2026-09-12T18:40Z; nothing under docs/example/ or prd.json changed since.

In flight (re-checked)
  Research subagent on the retry ticket — still open; no ## Findings yet.

Waiting on a human
  zurdo review docs/example/prds/prd-01-csv-export.md — one [manual] criterion on task-manifest.

Claimed
  not read — gh not on PATH.

Do not
  run sync-status before zurdo review closes the pending task — it would re-label the same issue.

Next action: row 8 — the run is settled with every task passed or passed-pending-review: zurdo review, sync-status, scope, then zurdo-prd-review.
  Checked: no lock in .zurdo/prd-01-csv-export-a91c/; 4 passed, 1 passed-pending-review; retry ticket still open so row 2 does not precede.
  First command: zurdo review docs/example/prds/prd-01-csv-export.md
  Acts: you, in the zurdo review TUI; then zurdo-project for sync-status and scope; then zurdo-prd-review.
```

---

## Variant 2 — stale handoff

Same initiative; overnight the research subagent resolved the retry ticket and a teammate pushed a `scope.md` edit.

```
Wayfinder — Example Initiative (docs/example/)
Destination: Build a CLI tool that exports observability data from the monitoring system to CSV, then posts the report to a configured webhook endpoint.

  phase-01  CSV export        running      prd-01-csv-export.md   settled: 4 passed · 1 pending-review
  phase-02  Webhook delivery  researching  —                      blocker resolved: What retry and backoff policy do the target webhooks expect? — row is stale, phase-02 is ready

You are here: Run and sync, phase-01.
Handoff: stale — 9a1b2c3 "scope: note the --project flag" touched docs/example/scope.md after the handoff; tickets/webhook-retries.md is now resolved.
Since the handoff:
  9a1b2c3  scope: note the --project flag            docs/example/scope.md
  c4d5e6f  ticket: resolve webhook-retries            docs/example/tickets/webhook-retries.md

In flight (re-checked)
  Research subagent on the retry ticket — resolved; ## Findings present; issue closed by the subagent's ticket run.

Waiting on a human
  zurdo review docs/example/prds/prd-01-csv-export.md — still one [manual] criterion on task-manifest.

Claimed
  none — all open issues unassigned.

Do not
  write the phase-02 PRD yet — scope.md still says researching; flip the row first, then scope.
  run sync-status before zurdo review — same reason as before.

Next action: row 2 — a research ticket is resolved but scope.md does not reflect it: read its ## Findings and ## Follow-ups, add the Decisions line, flip phase-02 to ready, ticket any sharp follow-up, run scope.
  Checked: tickets/webhook-retries.md status: resolved; scope.md phase-02 row still researching; no other open blocker for phase-02.
  First command: zurdo-github.sh scope --dry-run docs/example/scope.md   (after the scope.md edit)
  Acts: zurdo-project. Row 8 follows once the human step clears.
```

The handoff named row 8. The files say row 2 comes first. The report says both and picks the lower.

---

## Variant 3 — no handoff

A repository charted last week by someone who never wrote a handoff.

```
Wayfinder — Example Initiative (docs/example/)
Destination: Build a CLI tool that exports observability data from the monitoring system to CSV, then posts the report to a configured webhook endpoint.

  phase-01  CSV export        ready   —   no run
  phase-02  Webhook delivery  researching  —   blocked by: What retry and backoff policy do the target webhooks expect? (open)

You are here: Phase PRD, phase-01.
Handoff: none.

In flight (re-checked)
  none — no handoff to name any; no lock under .zurdo/.

Waiting on a human
  Which auth scheme should the webhook use? — open grilling ticket; needs you, not the agent.

Claimed
  not read — gh authenticated but no scope issue found; run scope first.

Do not
  answer the grilling ticket on the user's behalf.
  write the phase-01 PRD before the grilling ticket is either resolved or confirmed not to block phase-01 (its blocks: is empty; confirm with the user).

Next action: row 1 — an open grilling ticket exists: claim it, interview the user, record the answer verbatim under ## Findings, flip status: resolved, run ticket, update scope.md, run scope.
  Checked: tickets/webhook-auth.md type: grilling, status: open; user present in this session.
  First command: gh issue edit <n> --add-assignee @me   (the claim; number from the scope issue once scope has run)
  Acts: zurdo-project, live with you.
```

Missing handoff, no remark beyond the one line. Grilling first because the user is here.

---

## Variant 4 — PRD-only repository

This repository, as of the design record: three PRDs, no `scope.md`, run state for each.

```
Wayfinder — PRD-only repository (no docs/*/scope.md); one block per PRD directory with run state.

docs/golang/prds/prd-01-golang-skill.md            .zurdo/prd-01-golang-skill-f2c1/
  settled: 7 passed · 0 pending-review            handoff: none
  Next action: verify — every task terminal-pass and nothing changed since; zurdo verify re-runs the criteria token-free.

docs/zurdo-github/prds/prd-01-zurdo-github-skill.md   .zurdo/prd-01-zurdo-github-skill-49bd/
  settled: <tally>                                  handoff: none
  Next action: <verb from zurdo-state-summary>

docs/zurdo-project/prds/prd-01-zurdo-project-skill.md  .zurdo/prd-01-zurdo-project-skill-1809/
  settled: <tally, includes passed-pending-review>  handoff: none
  Next action: review — passed-pending-review tasks exist; zurdo review signs off [manual] criteria.

Do not
  run zurdo run --reset on any of these to "clean up"; state is the audit trail.

Acts: you, for zurdo review; zurdo-state-summary for the per-run detail.
```

No rows, because no Phases table. The verbs are `zurdo-state-summary`'s.
