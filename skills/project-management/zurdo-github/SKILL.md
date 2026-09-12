---
name: zurdo-github
description: >
  Triggers when the user asks to publish, mirror, or set up a Zurdo PRD or its scope and tickets
  on GitHub as milestones, epics, issues, labels, or a project board, or to sync a Zurdo run's
  status back to GitHub.
  Does NOT trigger for general issue triage, pull-request work, or authoring the PRD itself.
---

# zurdo-github

Publish a Zurdo PRD to GitHub as a structured set of milestones, issues, and labels, and keep GitHub issue status in sync with Zurdo run outcomes.

## Decision Rules

**The PRD is the source of truth; never edit the PRD from GitHub state.**
Edits flow one direction: PRD → GitHub. Pulling GitHub state back into the PRD creates drift and breaks the task gate model.
→ see references/github-model.md

**One PRD = one milestone + one epic issue; tasks are sub-issues of the epic and members of the milestone.**
The milestone groups all work for a PRD run; the epic issue is the parent that owns the task tree. Tasks belong to both.
→ see references/github-model.md

**Labels come in three groups (type, effort, status) plus the triage five; create idempotently with color and description; effort labels mirror the PRD's `Effort` values.**
Idempotent creation (look up by name, create only what is missing) lets re-runs be safe. The triage five are `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`; frontier tasks (no dependencies) get `ready-for-agent`.
→ see references/github-model.md

**The hidden marker `<!-- zurdo-github prd=… task=… -->` is the issue's identity; re-runs update in place, never duplicate.**
Matching on the marker — not the title — means renamed tasks still resolve to the same issue and avoid ghost duplicates.
→ see references/github-model.md

**Create every issue first, wire sub-issues and blocked-by edges in a second pass; blocked-by takes the blocker's database id, not its number.**
GitHub's sub-issue and dependency APIs require the parent/blocker to already exist. Database ids survive issue renaming; numbers do not.
→ see references/github-model.md

**Fallbacks are automatic: checklist in the epic body when sub-issues are unavailable, the `Blocked by:` line when dependencies are unavailable; report which mode ran.**
Older GitHub plans lack the sub-issues beta and the dependency graph; graceful degradation keeps the tool usable everywhere.
→ see references/github-model.md

**`scope.md` and ticket files are sources of truth projected to GitHub issues; the script never writes back.**
Edits flow one direction: `scope.md` and ticket files → GitHub issues. Pulling GitHub state into these source files creates drift.
→ see references/github-model.md

**`scope` creates the Project, links it to the repo, sets its description and README from `scope.md`, and skips with a hint when `scope.md` is absent; `publish --scope <n>` nests the epic as a sub-issue of issue `<n>`.**
The Project description is the Destination paragraph and the Project README is the rendered scope body, both overwritten on every `scope` run so the board's front page never drifts from the file. The scope issue must exist before `publish --scope` runs. `publish --scope` exits 3 with `run scope first` when the scope marker is not found.
→ see references/runbook.md

**`passed` closes; `passed-pending-review` labels and stays open until `zurdo review`; `failed` labels and comments the failed hints; swap status labels, never stack.**
Stacking status labels makes filtering unreliable. One status label per issue at all times.
→ see references/status-sync.md

**Leave task issues unassigned; assignment is the claim. Assign only the epic to `@me`.**
Unassigned tasks signal that work is available to pick up. Self-assigning a task is how contributors claim it; the tool must not pre-empt that.
→ see references/runbook.md

**Always run `--dry-run` first and read the plan; live runs need `gh auth status` showing `repo` (and `project` for the board).**
Dry-run output is the only way to verify scope before mutations. Missing scopes cause partial runs that are hard to roll back.
→ see references/runbook.md

**Board is optional and last; publish must succeed without it.**
Project boards require the `project` scope and an org that has enabled Projects v2. Core publishing must not depend on either.
→ see references/runbook.md

**Touch the milestone description always, repo About only when empty and `--about` is passed, the repo README never; the Project README is the script's to overwrite.**
Milestone descriptions are safe to overwrite on every sync. The About field is owned by the repo maintainer once set and requires the `--about` flag to write. The repo README is user-controlled content. The Projects v2 README is a projection of `scope.md`, so `scope` rewrites it every run.
→ see references/runbook.md

## Modes

One script, six modes, one invocation shape:

```
scripts/zurdo-github.sh <mode> [--dry-run] [--repo owner/name] [--slug <zurdo-slug>] [--about "<text>"] [--scope <issue-number>] [--project <project-title>] <prd-path>
```

| Mode | What it does |
|---|---|
| `bootstrap` | Ensures the labels exist (type, effort from the PRD's `Effort` values, status, triage five); sets repo About only when empty and `--about` is given; appends `## Zurdo operations` to `docs/agents/issue-tracker.md` when that file exists and lacks the heading. |
| `scope` | Reads `scope.md` and creates or updates the scope issue with the `zurdo:scope` label; creates the Projects v2 project (title from `--project` or `scope.md` title), links it to the repository so it shows under the repo's Projects tab, and sets the Project's description (Destination paragraph, capped at 256 chars) and README (rendered scope body) on every run; exits 3 with a hint when `scope.md` is absent. |
| `ticket` | Reads one ticket file (`tickets/<name>.md` beside `scope.md`) and projects it to a GitHub issue titled with its `question:`, labeled `zurdo:research` or `zurdo:grilling`, linked as a sub-issue of the scope issue; comments the Findings and closes when the file is `resolved`; exits 3 with `run scope first` when the scope issue is missing. Edges are wired by the `scope` sweep, not here. |
| `publish` | Runs the label step, then milestone → epic issue → task issues → second-pass wiring (sub-issues, blocked-by edges, `Blocked by:` lines) → epic body. When `--scope <n>` is given, nests the epic as a sub-issue of issue `<n>`. Re-runs update in place by marker. |
| `sync-status` | Reads `.zurdo/<slug>/prd.json` (`--slug`, else newest) and applies the status mapping: close, label swap, comment. Refreshes the epic's task table. |
| `board` | Finds or creates one repo-level Projects v2 project (title from `--project` or the PRD title), links it to the repository, adds a `Status` field, adds every task issue, sets Status from prd.json. Exits 3 with a `gh auth refresh -s project` hint when the scope is missing. |

**Flags**

- `--dry-run` — print every `gh` command prefixed `DRY:` and make no network call; lookups are assumed not-found so the plan is the full create path. Always run this first.
- `--repo owner/name` — override the repository; otherwise parsed from `git remote get-url origin` (https and ssh forms), never from a network call.
- `--slug` — pick a specific `.zurdo/<slug>/` run directory for `sync-status` and `board`.
- `--about "<text>"` — the one-line repo description `bootstrap` may set when About is empty; never invented.
- `--scope <issue-number>` — link the published epic as a sub-issue of the given scope issue number; `publish` only. Exits 3 with `run scope first` when the scope issue marker is not found.
- `--project <project-title>` — override the Projects v2 project title used by `scope` and `board` when finding or creating the project.

Exit codes: 0 ok, 2 usage or PRD parse error, 3 auth or capability error, 1 anything else.

## References

- [references/github-model.md](references/github-model.md) — Data model: how PRD concepts map to GitHub milestones, epics, task issues, labels, markers, and dependency edges.
- [references/status-sync.md](references/status-sync.md) — Status mapping: how each Zurdo task outcome translates to GitHub label swaps, issue state, and comments.
- [references/runbook.md](references/runbook.md) — Operational runbook: auth prerequisites, invocation examples, re-run safety, rollback, and troubleshooting.
