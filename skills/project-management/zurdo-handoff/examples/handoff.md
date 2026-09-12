---
initiative: example
stopped_at: 2026-09-12T18:40:00Z
station: run-and-sync
phase: phase-01
by: agent
---

# Handoff: Example Initiative

## Stopped at

Run and sync, phase-01 [CSV export](prds/prd-01-csv-export.md). `zurdo run` finished and `sync-status` is applied; `zurdo review` has not run, so one task issue is still open with `zurdo:pending-review`.

## Done this session

- Diagnosed the failing manifest criterion with `zurdo-hint-debugger` (classification C: the writer never emitted the heading the hint greps for), fixed the writer, ran `zurdo run --resume`. Every task is now `passed` or `passed-pending-review` in `.zurdo/prd-01-csv-export-a91c/prd.json`. Commit `3f2a9c1`.
- `sync-status` live against [CSV export](prds/prd-01-csv-export.md): closed four task issues, labelled task-manifest `zurdo:pending-review`, refreshed the epic's task table.
- `scope` live: Phases table on the scope issue shows the epic and milestone for phase-01.

## In flight

- Research subagent on [What retry and backoff policy do the target webhooks expect?](tickets/webhook-retries.md), dispatched 17:55Z. Check `status:` in the ticket file; the subagent runs `ticket` itself, so the issue closes without us.

## Waiting on a human

- `zurdo review docs/example/prds/prd-01-csv-export.md` — one `[manual]` criterion on task-manifest: "manifest documents the schema version". Sign it off in the TUI; then `sync-status` closes the last issue.

## Next action

Row 8 — the run is settled with every task `passed` or `passed-pending-review`: `zurdo-state-summary` to confirm, `zurdo review`, `sync-status`, `scope`, then `zurdo-prd-review`. Re-check before acting: no `lock` file in `.zurdo/prd-01-csv-export-a91c/`, and the retry ticket's `status:` (if `resolved`, row 2 comes first: absorb its findings into `scope.md` and flip phase-02 to `ready`).

## Uncommitted

Clean.

## Watch out

- `board` needs `--project "Example Initiative"`; without the flag it creates a second board named after the PRD. Belongs in `scope.md` Notes as a standing preference; not written there yet.
- The manifest fix is a repo quirk worth a lesson (a `[grep:]` for a heading the writer builds from a constant must target the constant's file, not the rendered output). Belongs in `lessons/` through `zurdo-lessons`; not written yet.
