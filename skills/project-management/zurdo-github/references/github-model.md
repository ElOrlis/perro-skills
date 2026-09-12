# github-model

Data model: how Zurdo PRD concepts map to GitHub milestones, epic issues, task issues, labels, markers, and dependency edges.

---

## PRD → GitHub mapping

| PRD concept | GitHub object |
|---|---|
| `scope.md` (project scope file) | Scope issue (top-level container; all PRD epics nest under it as sub-issues when `--scope` is given) |
| `## Destination` first paragraph in `scope.md` | Projects v2 project short description (capped at 256 chars; rewritten on every `scope` run) |
| Whole `scope.md` body | Projects v2 project README, under a `# <initiative title>` heading (rewritten on every `scope` run) |
| Ticket file (`tickets/<name>.md`) | Ticket issue (research or grilling question; sub-issue of the scope issue; the epics it `blocks` are blocked by it) |
| `# PRD: <title>` | Milestone title + epic issue title |
| Intro text (after H1, before first `## Task:`) | Milestone description + epic issue body intro |
| `## Task: <id> — <title>` | Task issue (sub-issue of epic, member of milestone) |
| `**Effort**: <value>` | Label `effort:<value>` on the task issue |
| `**Depends-on**: [<id>, …]` | Native blocked-by edge (POST) + `Blocked by:` line in issue body |
| `**Skills**: <value>` | Metadata table row in task body |
| `**Max-Attempts**: <n>` | Metadata table row in task body |
| `**Agent-timeout**: <value>` | Metadata table row in task body |
| `### Description` | `## Description` section in task body (content verbatim) |
| `### Acceptance Criteria` `- [ ] <text> [hint]` | `## Acceptance Criteria` section; each criterion becomes `- [ ] <text>` with hints in inline code spans |

One PRD maps to exactly one milestone and one epic issue. Every task issue is a member of the milestone and a sub-issue of the epic. When `--scope <n>` is passed to `publish`, the epic is additionally linked as a sub-issue of scope issue `<n>`.

---

## Label vocabulary

Labels belong to three groups plus the five triage labels.

### Group 1 — type

| Name | Hex | Description |
|---|---|---|
| `zurdo:scope` | `#0052CC` | Zurdo initiative scope issue |
| `zurdo:research` | `#006B75` | Zurdo research ticket |
| `zurdo:grilling` | `#EE0701` | Zurdo grilling ticket |
| `zurdo:epic` | `#5319E7` | Zurdo PRD epic issue |
| `zurdo:task` | `#1D76DB` | Zurdo PRD task issue |

### Group 2 — state

| Name | Hex | Description |
|---|---|---|
| `zurdo:pending-review` | `#FBCA04` | Awaiting human review |
| `zurdo:failed` | `#B60205` | Zurdo run failed this task |

### Group 3 — effort

| Name | Hex | Description |
|---|---|---|
| `effort:<value>` | `#BFD4F2` | Effort tier: `<value>` |

Effort labels are derived from the PRD: each unique `**Effort**` value becomes one `effort:<value>` label. The set is not fixed in the skill — it mirrors whatever values appear in the PRD.

### Triage five

| Name | Hex | Description |
|---|---|---|
| `needs-triage` | `#C5DEF5` | Needs human triage |
| `needs-info` | `#CCCCCC` | Needs more info to proceed |
| `ready-for-agent` | `#0E8A16` | Ready for an agent to pick up |
| `ready-for-human` | `#D4C5F9` | Ready for a human to review |
| `wontfix` | `#FFFFFF` | Will not fix |

`ready-for-agent` is applied at creation time to task issues that have no `Depends-on` entries. It is not applied retroactively by the wiring pass.

---

## Issue body templates

### Epic body

```markdown
<!-- zurdo-github prd=<prd-path> epic -->

<intro text from PRD>

## Tasks

| Task | Effort | Status |
|---|---|---|
| [<task-title>](#<number>) | <effort> | Todo |
| [<task-title>](#<number>) | <effort> | Todo |
```

When sub-issues are unavailable (fallback mode), append:

```markdown
### Checklist (sub-issues unavailable)

- [ ] #<number>
- [ ] #<number>
```

### Task body

```markdown
Part of #<epic-number>

<!-- zurdo-github prd=<prd-path> task=<task-id> -->

| Effort | Skills | Max-Attempts | Agent-timeout |
|---|---|---|---|
| <value> | <value> | <value> | <value> |

Blocked by: [<blocker-title>](#<blocker-number>) [<blocker-title>](#<blocker-number>)

## Description

<content from ### Description, verbatim>

## Acceptance Criteria

- [ ] <criterion text> `<hint>` `<hint>`
- [ ] <criterion text>
```

Notes:
- `Part of #<epic-number>` is a plain text line, not a GitHub "tracked-in" relationship — the sub-issue API handles the structural parent.
- Omit `Skills`, `Max-Attempts`, and `Agent-timeout` columns when the PRD task has no value for them.
- Omit the `Blocked by:` line entirely on the first-pass body; it is written in the second pass once all issue numbers are known.
- Hints from `[hint text]` suffixes on criteria lines appear as `` `hint text` `` after the criterion.

### Scope body

```markdown
<!-- zurdo-github scope=<project-slug> -->

<intro text from scope.md>

## Phases

| Phase | Ticket | Status |
|---|---|---|
| <phase-name> | [<ticket-title>](#<number>) | Todo |
```

When sub-issues are unavailable (fallback mode), append:

```markdown
### Checklist (sub-issues unavailable)

- [ ] #<ticket-number>
- [ ] #<ticket-number>
```

### Ticket body

```markdown
Part of #<scope-number>

<!-- zurdo-github scope=<initiative-slug> ticket=<name> -->

## Question

<## Question body from the ticket file, verbatim>

## Findings

<## Findings body; present only when the file is status: resolved>
```

The issue title is the ticket's `question:` line; the label is `zurdo:research` or `zurdo:grilling` from `type:`; no assignee. `ticket` projects one file, links it as a sub-issue of the scope issue, and, when the file is `resolved` and the issue is open, posts the Findings as a comment and closes it. The `scope` sweep does the same for every file under `tickets/` and then wires edges in a second pass: ticket-to-ticket `blocked-by`, and a blocked-by edge from each phase epic to every ticket that `blocks` it, so the epic cannot start until the ticket resolves. When the epic does not exist yet the sweep prints `defer: phase-NN has no epic yet`. The summary's `edges: mode=` reports `native` or `fallback`.

---

## The marker

### Format

```
<!-- zurdo-github prd=<path> task=<task-id> -->
<!-- zurdo-github prd=<path> epic -->
<!-- zurdo-github scope=<initiative-slug> -->
<!-- zurdo-github scope=<initiative-slug> ticket=<name> -->
```

`<path>` is the PRD file path as passed to the script (e.g. `docs/my-feature/prds/prd-01-setup.md`). `<initiative-slug>` is the basename of the directory holding `scope.md` (`my-feature` for `docs/my-feature/scope.md`), not the title. `<name>` is the ticket file's basename without `.md` (e.g. `webhook-retries`).

### Why an HTML comment

HTML comments are invisible in rendered GitHub Markdown but remain in the raw body string. They survive any edits a human makes to the visible content (title, description, acceptance criteria rewording). They are grep-able via the GitHub search API and via `gh issue list --search`.

### Search-then-confirm lookup

```bash
# Step 1 — search (fuzzy; may return false positives)
gh issue list --state all \
  --search "<!-- zurdo-github prd=<path> task=<id> -->" \
  --json number,body --limit 50 \
  -R owner/repo

# Step 2 — confirm (exact substring match in body)
# Filter the JSON with jq:
jq -r --arg m "<!-- zurdo-github prd=<path> task=<id> -->" \
  'map(select(.body | contains($m))) | (.[0].number // empty)'
```

The confirmation step is mandatory. GitHub's issue search is full-text and fuzzy — it can match issues that merely contain fragments of the query. Confirming with `contains()` on the raw body ensures the marker is present verbatim before treating an issue as the canonical one.

---

## Second-pass wiring and the database id rule

### Why two passes

All task issues must exist before sub-issue and blocked-by edges can be created: the API requires the child/blocker to already have an issue number. Create all issues in the first pass, then wire relationships in the second pass.

### Database id rule

GitHub's sub-issues endpoint and the dependency endpoint both take the **database id** (a large integer, e.g. `2847391047`), not the issue number (`#42`) and not the node id (a base64 string starting with `I_`). Issue numbers change on transfer; database ids do not.

Fetch the database id:

```bash
gh api repos/<owner>/<repo>/issues/<number> --jq .id
```

### Sub-issue POST

```bash
gh api --method POST \
  repos/<owner>/<repo>/issues/<epic-number>/sub_issues \
  -F "sub_issue_id=<task-db-id>"
```

### Blocked-by POST

```bash
gh api --method POST \
  repos/<owner>/<repo>/issues/<task-number>/dependencies/blocked_by \
  -F "issue_id=<blocker-db-id>"
```

### `--scope` sub-issue link

When `publish --scope <n>` is given, the epic is linked as a sub-issue of issue `<n>` in the second pass using the same Sub-issue POST above (epic as child, scope issue as parent). If the sub-issues endpoint returns a 4xx, append a `Blocked by: #<n>` line to the epic body as the checklist fallback.

### Phase-epic-to-ticket blocked-by edge

`ticket` wires a blocked-by edge from each phase epic to the ticket in the second pass: the epic cannot start until the ticket is complete. This edge is wired with the standard Blocked-by POST using the ticket's database id as the blocker. If the dependency endpoint is unavailable, the fallback `Blocked by: #<ticket-number>` line is written into the epic body instead.

### Reading the live blocked-by summary

```bash
gh api repos/<owner>/<repo>/issues/<number>/dependencies/blocked_by
```

The response is an array of blocking issue objects. An issue is unblocked when this array is empty — equivalently when `issue_dependencies_summary.blocked_by == 0` (the REST summary field). This is the gate the frontier query relies on.

---

## Fallbacks

### Sub-issues unavailable (4xx from sub_issues endpoint)

Any HTTP 4xx from `POST .../sub_issues` — including 404 Not Found, 403 Forbidden, or 422 with "unavailable" or "disabled" in the body — signals that the sub-issues beta is not enabled for the repo or plan.

**Fallback**: append a `### Checklist (sub-issues unavailable)` section to the epic body containing `- [ ] #<number>` lines for each task. This provides a manual tracking surface without structural parent-child relationships.

### Dependencies unavailable (4xx from blocked_by endpoint)

Any HTTP 4xx from `POST .../dependencies/blocked_by` signals that the dependency graph feature is not available.

**Fallback**: the `Blocked by: [<title>](#<number>)` line written into the task body in the second pass. This is always written regardless of native dependency availability; when native edges are also wired it is redundant but harmless.

### Detecting which mode ran

The `bootstrap`/`publish` run prints a summary line:

```
wiring: sub-issues=native dependencies=native
wiring: sub-issues=fallback dependencies=fallback
```

`native` means at least one API call succeeded. `fallback` means every attempt returned a 4xx. Check this line to know which mode is active.

---

## Frontier

A **frontier task** is an open task issue with no assignee and no blocking dependencies. It is ready for an agent or contributor to claim by self-assigning.

Conditions:
- Label `ready-for-agent` present (applied at creation to tasks with `depends_on` empty)
- No assignee
- `issue_dependencies_summary.blocked_by == 0` (all native blockers resolved, or no native edges exist)

List frontier tasks:

```bash
gh issue list \
  -R owner/repo \
  --label ready-for-agent \
  --json number,title,assignees \
  --jq '.[] | select(.assignees | length == 0) | "#\(.number) \(.title)"'
```

Claim a task: `gh issue edit <number> --add-assignee @me -R owner/repo`

---

## Idempotency rules

Re-running any mode must be safe. The rules:

| Object | Lookup before create | On match | Never |
|---|---|---|---|
| Milestone | `GET repos/<o>/<r>/milestones?state=all` — match on title | PATCH description; reuse number | Delete or renumber |
| Labels | `gh label list --json name` — match on name | Skip create | Delete or rename |
| Scope issue | Search marker `<!-- zurdo-github scope=<slug> -->` + body confirm | Edit body in place | Reopen if closed; create duplicate |
| Ticket issue | Search marker `<!-- zurdo-github scope=<slug> ticket=<name> -->` + body confirm | Edit title, body, labels | Reopen if closed; create duplicate |
| Epic issue | Search marker `<!-- zurdo-github prd=<path> epic -->` + body confirm | Edit body in place | Reopen if closed; create duplicate |
| Task issue | Search marker `<!-- zurdo-github prd=<path> task=<id> -->` + body confirm | Edit title, body, labels, milestone | Reopen if closed; create duplicate |
| Sub-issue edge | 422 "already" response is silently ignored | No action needed | — |
| Blocked-by edge | 422 "already" response is silently ignored | No action needed | — |

**Edit in place, never duplicate.** The marker is the identity; if the marker is found, update — do not create a second issue. If the marker is not found, create fresh.

**Never reopen.** If a task or epic issue is closed (e.g. by a prior `sync-status` run), leave it closed. Re-running `publish` updates the body and labels without touching state.

**Never delete.** Labels, milestones, and issues are append-only. Removing a label definition or milestone mid-run would break existing filtered views. Remove operations require explicit human action outside this tool.
