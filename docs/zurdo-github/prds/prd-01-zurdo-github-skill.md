# PRD: `zurdo-github` — Publish a Zurdo PRD to GitHub as milestone, epic, issues, labels

Build a skill at `skills/project-management/zurdo-github/` that projects a Zurdo PRD onto a GitHub repository and keeps the two in sync. The PRD is the single source of truth: one PRD becomes one **milestone** plus one **epic issue**; each `## Task:` becomes a **task issue** that is a sub-issue of the epic and a member of the milestone; each `Depends-on` edge becomes a native GitHub **blocked-by** dependency. A second mode reads `.zurdo/<slug>/prd.json` and pushes run status back to the issues. The skill never writes into the PRD from GitHub.

The skill is prose plus one script. `SKILL.md` is the standalone spine carrying the decision rules inline; `references/*.md` hold depth; `scripts/zurdo-github.sh` does the deterministic work (parse, look up, create-or-update, wire, sync) so the agent never improvises database-id lookups or second-pass wiring. The script has a `--dry-run` flag that prints every `gh` command instead of running it, which is how this PRD gates the script without touching GitHub.

Design decisions, settled with the author and binding on every task:

- **Input** is an existing Zurdo PRD path. Idea-to-PRD is owned by `zurdo-prd-writer` / `zurdo-prd-decomposer`; this skill does not decompose.
- **Epic** = milestone (title from the PRD H1 title minus the `PRD:` prefix; description = the PRD's intro prose before the first `## Task:`) **plus** an epic issue labelled `zurdo:epic`, in that milestone, assigned to the invoking user (`@me`), whose body is an index: the intro, a task table (title linked, effort, status), and links. Task issues are sub-issues of the epic issue.
- **Labels**, three groups, created idempotently with color and description: type `zurdo:epic`, `zurdo:task`; effort `effort:low`, `effort:medium`, `effort:high` (the effort group mirrors the PRD's `Effort` key verbatim, so it must be derived from the PRD's values, not hardcoded); status `zurdo:pending-review`, `zurdo:failed`; plus the triage five `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`, created only if absent. Frontier tasks (no open blocker) get `ready-for-agent`.
- **Task issue body**, verbatim from the PRD, in this order: a `Part of #<epic>` line; a hidden marker `<!-- zurdo-github prd=<prd-path> task=<task-id> -->`; a one-line metadata table (Effort, Skills, Max-Attempts, Agent-timeout when present); a `Blocked by:` line naming each blocker issue by title with a link (present even when native dependencies succeed; it is the fallback and the human-readable view); `## Description` verbatim; `## Acceptance Criteria` as unchecked GFM checkboxes with the hint kept in a code span.
- **Idempotency**: the marker is the identity. Publish searches issues for the marker (`gh issue list --search` on the marker string, then confirms by reading the body) and updates title, body, labels, milestone in place; it never creates a duplicate. Milestone and labels are looked up by name before creation.
- **Wiring is a second pass**: create every issue first (issues need numbers), then add sub-issue links and blocked-by edges. Blocked-by uses the blocker's numeric **database id** (`gh api repos/<o>/<r>/issues/<n> --jq .id`), never the `#number` or `node_id`.
- **Fallbacks are automatic**: on a 4xx from the sub-issues endpoint, add the task to a checklist in the epic body; on a 4xx from the dependencies endpoint, rely on the `Blocked by:` line. The script prints which mode it used.
- **Status sync mapping** from prd.json: `passed` closes the issue with a comment (attempts, model, tokens, estimated cost); `passed-pending-review` stays open, gets `zurdo:pending-review`, same comment; `failed` gets `zurdo:failed` and a comment listing the failed criteria hints from the last attempt; `blocked-by-dependency` changes nothing. Any status change removes the other status label first so labels never stack.
- **Project description**: milestone description always gets the intro prose; repo About description and topics are set only when currently empty and only from a one-line summary the user confirmed; the README is never touched.
- **Projects v2 board** is optional, a separate `board` mode: adds every task issue to one repo-level project and sets a `Status` single-select from prd.json. Publish must succeed without it.
- **Assignment on publish**: task issues are left unassigned (assignment is the claim convention used by wayfinder); only the epic issue is assigned to `@me`.
- **Conventions doc**: bootstrap appends a `## Zurdo operations` section to `docs/agents/issue-tracker.md` when that file exists, and skips with a message when it does not.
- **Dry-run never calls `gh`**: the repo is derived from `git remote get-url origin` (overridable with `--repo owner/name`), lookups are printed and assumed not-found, so output is the full create path.

Verification philosophy: prose artifacts gate on `file-exists` plus `[manual]` rubrics; the script gates on `bash -n`, on `--dry-run` runs against the existing golang PRD at `docs/golang/prds/prd-01-golang-skill.md` (seven tasks, a known dependency graph, effort values `medium` and `high`), and on greps of that output for deterministic command shapes. The one live run against a sandbox repository is a `[manual]` criterion on the final task and is performed by the author, not the executor. `grep`/`no-grep` on prose is limited to author-controlled link paths and frontmatter strings.

Run order is sequential: scaffold → script and references (independent of one another) → integration. Throughout, follow `superpowers:writing-skills` discipline: correct frontmatter, progressive disclosure, terse imperative voice, no filler, no TODO markers.

## Task: task-skill-scaffold — Scaffold the zurdo-github SKILL.md standalone spine
**Effort**: medium
**Depends-on**: []
**Skills**: writing-skills

### Description

Create `skills/project-management/zurdo-github/` with `SKILL.md`, an empty `references/` directory, and an empty `scripts/` directory so later tasks can populate them.

Frontmatter:
- `name: zurdo-github`
- `description:` — triggers when the user asks to publish, mirror, or set up a Zurdo PRD on GitHub as milestones, epics, issues, labels, or a project board, or to sync a Zurdo run's status back to GitHub. State explicitly that it does **not** trigger for general issue triage, pull-request work, or authoring the PRD itself.

Body — a standalone working guide, not an index. Carry these decision rules inline, each as a terse imperative + one-line why + `→ see references/<file>.md`:
- The PRD is the source of truth; never edit the PRD from GitHub state. → references/github-model.md
- One PRD = one milestone + one epic issue; tasks are sub-issues of the epic and members of the milestone. → references/github-model.md
- Labels come in three groups (type, effort, status) plus the triage five; create idempotently with color and description; effort labels mirror the PRD's `Effort` values. → references/github-model.md
- The hidden marker `<!-- zurdo-github prd=… task=… -->` is the issue's identity; re-runs update in place, never duplicate. → references/github-model.md
- Create every issue first, wire sub-issues and blocked-by edges in a second pass; blocked-by takes the blocker's database id, not its number. → references/github-model.md
- Fallbacks are automatic: checklist in the epic body when sub-issues are unavailable, the `Blocked by:` line when dependencies are unavailable; report which mode ran. → references/github-model.md
- `passed` closes; `passed-pending-review` labels and stays open until `zurdo review`; `failed` labels and comments the failed hints; swap status labels, never stack. → references/status-sync.md
- Leave task issues unassigned; assignment is the claim. Assign only the epic to `@me`. → references/runbook.md
- Always run `--dry-run` first and read the plan; live runs need `gh auth status` showing `repo` (and `project` for the board). → references/runbook.md
- Board is optional and last; publish must succeed without it. → references/runbook.md
- Touch the milestone description always, repo About only when empty, the README never. → references/runbook.md

Include a short "Modes" section naming the four script modes (`bootstrap`, `publish`, `sync-status`, `board`), the `--dry-run` and `--repo` flags, and the one-line invocation shape `scripts/zurdo-github.sh <mode> [--dry-run] [--repo owner/name] <prd-path>`.

Include a "References" section linking `references/github-model.md`, `references/status-sync.md`, and `references/runbook.md`, each with a one-line description.

### Acceptance Criteria

- [ ] SKILL.md exists [file-exists: skills/project-management/zurdo-github/SKILL.md]
- [ ] Frontmatter declares the skill name [grep: name: zurdo-github in skills/project-management/zurdo-github/SKILL.md]
- [ ] The description is tightly scoped to publishing or syncing a Zurdo PRD to GitHub and explicitly excludes general triage, PR work, and PRD authoring [manual]
- [ ] SKILL.md carries the inline decision rules listed in the Description (source-of-truth, milestone+epic shape, three label groups + triage five, marker identity, second-pass wiring with database ids, automatic fallbacks, status mapping with label swap, no task assignment, dry-run first, board optional and last, description-touch rules), each as imperative + why + arrow to a reference file [manual]
- [ ] SKILL.md has a Modes section naming bootstrap, publish, sync-status, board, the --dry-run and --repo flags, and the invocation shape [manual]
- [ ] SKILL.md has a References section linking all three reference files with a one-line description each [manual]
- [ ] No placeholder markers remain [no-grep: TODO in skills/project-management/zurdo-github/SKILL.md]

## Task: task-script — Write scripts/zurdo-github.sh
**Effort**: high
**Depends-on**: [task-skill-scaffold]
**Max-Attempts**: 4
**Agent-timeout**: 45m

### Description

Author `skills/project-management/zurdo-github/scripts/zurdo-github.sh`: a single POSIX-compatible bash script (`#!/usr/bin/env bash`, `set -euo pipefail`) that depends only on `bash`, `awk`, `jq`, `git`, and `gh`. Make it executable.

Invocation: `zurdo-github.sh <mode> [--dry-run] [--repo owner/name] [--slug <zurdo-slug>] <prd-path>`. Modes: `bootstrap`, `publish`, `sync-status`, `board`. Unknown mode or missing PRD path prints usage to stderr and exits 2.

**Repo resolution.** `--repo` wins; else parse `git remote get-url origin` for both `https://github.com/o/r(.git)` and `git@github.com:o/r(.git)` forms. Never call `gh repo view` for this.

**Dry-run.** Every `gh` invocation goes through one function `run_gh` that, under `--dry-run`, prints the exact command line prefixed with `DRY: ` to stdout and returns a stub. Lookups under dry-run return "not found", so dry-run output is the complete create path. Dry-run must exit 0 on a valid PRD and must not perform any network call.

**PRD parser** (awk). Honor the Zurdo §2.2 grammar exactly: the H1 `# PRD: <title>`; intro prose = everything between the H1 and the first `## Task:`; a task heading is `## Task: <task-id> — <title>` where the separator is U+2014 em-dash; the metadata block starts on the very next line with one `**Key**: value` per line (keys `Effort`, `Depends-on`, `Max-Attempts`, `Skills`, `Agent-timeout`, `Category`); `Depends-on` is `[a, b]` or `[]`; then `### Description` and `### Acceptance Criteria`; criteria lines are `- [ ] <text> [<hint>]…`. Emit the parsed PRD as one JSON document to jq: `{title, intro, tasks:[{id,title,effort,depends_on:[],skills,max_attempts,agent_timeout,description,criteria:[{text,hints:[]}]}]}`. Validate: unique ids matching `^task-[a-z0-9-]+$`, every `Depends-on` resolving; on violation print the offending line and exit 2.

**bootstrap.** Ensure labels exist (look up with `gh label list --json name`, create only missing ones with `gh label create <name> --color <hex> --description <text>`): `zurdo:epic`, `zurdo:task`, `zurdo:pending-review`, `zurdo:failed`, one `effort:<value>` per distinct `Effort` value in the PRD, and the triage five (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). Pick stable, distinct colors per group. Set the repo About description and topics only when `gh repo view --json description,repositoryTopics` shows them empty, and only when `--about "<text>"` was passed (never invent one). If `docs/agents/issue-tracker.md` exists and lacks a `## Zurdo operations` heading, append a section describing the label groups, the marker format, the epic layout, and the four modes; if the file does not exist, print `skip: docs/agents/issue-tracker.md not present` and continue.

**publish.** Runs bootstrap's label step first. Then: (1) milestone — look up by title via `gh api repos/<o>/<r>/milestones?state=all --jq`, create with `gh api --method POST repos/<o>/<r>/milestones -f title=… -f description=…` or PATCH the description if it changed. (2) epic issue — identity marker `<!-- zurdo-github prd=<path> epic -->`; find via `gh issue list --state all --search '"<marker>"' --json number,body` and confirm the body contains the marker; create with `gh issue create --title "<PRD title>" --label zurdo:epic --milestone "<title>" --assignee @me --body-file <tmp>` or `gh issue edit` in place. (3) task issues — for each task in PRD order, identity marker `<!-- zurdo-github prd=<path> task=<id> -->`; body exactly as the PRD's binding decisions specify (Part-of line, marker, metadata table, `Blocked by:` line with blocker titles linked once numbers are known, `## Description` verbatim, `## Acceptance Criteria` checkboxes with hints in code spans); labels `zurdo:task`, `effort:<value>`, plus `ready-for-agent` when the task has no dependencies; milestone set; no assignee; create or edit in place. Because blocker numbers are only known after creation, write bodies twice when needed: create with a placeholder-free body omitting the `Blocked by:` line, then after all numbers exist, edit bodies to add it. (4) wiring pass — for each task: sub-issue link `gh api --method POST repos/<o>/<r>/issues/<epic>/sub_issues -F sub_issue_id=<task-db-id>`; for each dependency: `gh api --method POST repos/<o>/<r>/issues/<task>/dependencies/blocked_by -F issue_id=<blocker-db-id>` where db ids come from `gh api repos/<o>/<r>/issues/<n> --jq .id`. Treat an HTTP 4xx on the sub-issues endpoint as "sub-issues unavailable": fall back to a `## Tasks` checklist of `- [ ] #<n>` in the epic body. Treat a 4xx on the dependencies endpoint as "dependencies unavailable": the `Blocked by:` line already carries the edge. Skip edges that already exist (a 422 with "already" in the message is not an error). (5) epic body — the intro, a task table (`| Task | Effort | Status |` with the title linked to the issue), the fallback checklist if used. (6) Print a summary: milestone number, epic number, each task's number, and which wiring mode ran (`native` or `fallback`) for sub-issues and dependencies.

**sync-status.** Resolve the run directory: `--slug` if given, else the newest `.zurdo/<prd-basename-without-.md>-*/prd.json` under the repo root. For each task in prd.json, find its issue by marker and apply: `passed` → remove `zurdo:pending-review`/`zurdo:failed`, comment with attempts, last model, tokens in/out, `cost_usd_est`, then `gh issue close`; `passed-pending-review` → remove `zurdo:failed`, add `zurdo:pending-review`, same comment, leave open; `failed` → remove `zurdo:pending-review`, add `zurdo:failed`, comment listing each `criteria_results[].hint` with `passed:false` from the last iteration; `blocked-by-dependency` → no change. Also refresh the Status column of the epic's task table. Never reopen a closed issue.

**board.** Find or create one repo-level Projects v2 project titled after the repo (`gh project list --owner <o> --format json`, `gh project create --owner <o> --title …`), ensure a `Status` single-select field with options `Todo`, `In Progress`, `Pending Review`, `Done`, `Failed` (`gh project field-list`/`field-create`), add every task issue (`gh project item-add`), and set Status from prd.json when a run directory exists, else `Todo` (`gh project item-edit`). Missing `project` scope is reported as a clear error naming `gh auth refresh -s project`, exit 3.

**General.** Wrap every network `gh` call in `timeout 90`. Write multi-line bodies to a temp file under `mktemp -d` and pass `--body-file`. Refer to issues by title in human-facing summary lines, with the number in parentheses. Exit codes: 0 ok, 2 usage/parse error, 3 auth or capability error, 1 anything else.

### Acceptance Criteria

- [ ] Script exists [file-exists: skills/project-management/zurdo-github/scripts/zurdo-github.sh]
- [ ] Script parses as bash [shell: bash -n skills/project-management/zurdo-github/scripts/zurdo-github.sh]
- [ ] Script is executable [shell: ls -l skills/project-management/zurdo-github/scripts/zurdo-github.sh | grep -q "^-..x"]
- [ ] Usage error exits 2 on a missing mode [shell: skills/project-management/zurdo-github/scripts/zurdo-github.sh >/dev/null 2>&1; test $? -eq 2]
- [ ] Dry-run publish against the golang PRD exits 0 [shell: skills/project-management/zurdo-github/scripts/zurdo-github.sh publish --dry-run --repo ElOrlis/perro-skills docs/golang/prds/prd-01-golang-skill.md > /dev/null]
- [ ] Dry-run publish plans a milestone creation [shell: skills/project-management/zurdo-github/scripts/zurdo-github.sh publish --dry-run --repo ElOrlis/perro-skills docs/golang/prds/prd-01-golang-skill.md | grep -E 'DRY: .*gh api --method POST repos/ElOrlis/perro-skills/milestones']
- [ ] Dry-run publish plans an epic issue with the zurdo:epic label and @me assignee [shell: skills/project-management/zurdo-github/scripts/zurdo-github.sh publish --dry-run --repo ElOrlis/perro-skills docs/golang/prds/prd-01-golang-skill.md | grep -E 'DRY: .*gh issue create .*zurdo:epic' | grep -q -- '--assignee @me']
- [ ] Dry-run publish plans exactly seven task issue creations for the seven golang tasks [shell: test "$(skills/project-management/zurdo-github/scripts/zurdo-github.sh publish --dry-run --repo ElOrlis/perro-skills docs/golang/prds/prd-01-golang-skill.md | grep -E 'DRY: .*gh issue create .*zurdo:task' | wc -l | tr -d ' ')" = "7"]
- [ ] Dry-run publish derives effort labels from the PRD (medium and high present, low absent) [shell: OUT="$(skills/project-management/zurdo-github/scripts/zurdo-github.sh publish --dry-run --repo ElOrlis/perro-skills docs/golang/prds/prd-01-golang-skill.md)"; echo "$OUT" | grep -q 'effort:medium' && echo "$OUT" | grep -q 'effort:high' && ! echo "$OUT" | grep -q 'effort:low']
- [ ] Dry-run publish plans blocked-by wiring through the dependencies endpoint [shell: skills/project-management/zurdo-github/scripts/zurdo-github.sh publish --dry-run --repo ElOrlis/perro-skills docs/golang/prds/prd-01-golang-skill.md | grep -q 'dependencies/blocked_by']
- [ ] Dry-run publish plans sub-issue wiring [shell: skills/project-management/zurdo-github/scripts/zurdo-github.sh publish --dry-run --repo ElOrlis/perro-skills docs/golang/prds/prd-01-golang-skill.md | grep -q '/sub_issues']
- [ ] Dry-run bootstrap plans the triage five and the type labels [shell: OUT="$(skills/project-management/zurdo-github/scripts/zurdo-github.sh bootstrap --dry-run --repo ElOrlis/perro-skills docs/golang/prds/prd-01-golang-skill.md)"; for l in zurdo:epic zurdo:task zurdo:pending-review zurdo:failed needs-triage needs-info ready-for-agent ready-for-human wontfix; do echo "$OUT" | grep -q "gh label create $l " || exit 1; done]
- [ ] Dry-run sync-status against the golang run plans closes or labels and exits 0 [shell: skills/project-management/zurdo-github/scripts/zurdo-github.sh sync-status --dry-run --repo ElOrlis/perro-skills --slug prd-01-golang-skill-f2c1 docs/golang/prds/prd-01-golang-skill.md | grep -q 'zurdo:pending-review']
- [ ] Dry-run never invokes gh: the script contains a single gh call site behind the dry-run guard, and dry-run output contains no line lacking the DRY prefix that names a live API result [manual]
- [ ] Parser rejects a PRD with a hyphen task separator or a dangling Depends-on with exit 2 and an offending-line message [manual]
- [ ] Issue body layout, marker format, second-pass wiring, database-id usage, automatic fallbacks, status mapping with label swap, and board behavior match the PRD's binding decisions [manual]

## Task: task-ref-github-model — Write references/github-model.md
**Effort**: medium
**Depends-on**: [task-skill-scaffold]
**Skills**: writing-skills

### Description

Author `skills/project-management/zurdo-github/references/github-model.md`: the mapping from Zurdo PRD grammar to GitHub objects, with exact command shapes.

Required coverage:
- **Mapping table**: PRD → milestone + epic issue; `## Task:` → task issue (sub-issue of epic, member of milestone); `Effort` → `effort:<value>` label; `Depends-on` → native blocked-by edge + `Blocked by:` line; `Skills`, `Max-Attempts`, `Agent-timeout` → metadata table row; `### Description` → `## Description` verbatim; `### Acceptance Criteria` → unchecked checkboxes with hints in code spans.
- **Label vocabulary** with the three groups, the triage five, one hex color and description per label, and the rule that effort labels are derived from the PRD's values.
- **Issue body templates** for the epic (intro, task table, optional fallback checklist) and for a task (Part-of line, marker, metadata table, Blocked-by line, Description, Acceptance Criteria), shown as fenced markdown.
- **The marker**: exact format `<!-- zurdo-github prd=<path> task=<id> -->` and `<!-- zurdo-github prd=<path> epic -->`; why an HTML comment (invisible, searchable, survives edits); how to find an issue by it (`gh issue list --state all --search` then body confirmation) and why the confirmation step exists (search is fuzzy).
- **Second-pass wiring** and the **database id** rule: `gh api repos/<o>/<r>/issues/<n> --jq .id` is the value the sub-issues and dependencies endpoints take; `#number` and `node_id` are rejected. Show both POST commands. Show how to read the live gate `issue_dependencies_summary.blocked_by`.
- **Fallbacks**: what a 4xx from each endpoint means, the checklist and Blocked-by-line fallbacks, and how to tell which mode ran.
- **Frontier**: an open task with `issue_dependencies_summary.blocked_by == 0` and no assignee; the `gh` one-liner that lists it.
- **Idempotency rules**: look up before create for milestone, labels, epic, tasks; edit in place; never reopen; never delete.

### Acceptance Criteria

- [ ] github-model.md exists [file-exists: skills/project-management/zurdo-github/references/github-model.md]
- [ ] Contains the PRD-to-GitHub mapping table, the full label vocabulary with colors, and both body templates as fenced markdown [manual]
- [ ] Specifies the marker format for epic and task, the search-then-confirm lookup, the second-pass wiring rule, and the database-id rule with both POST commands and the blocked_by summary read [manual]
- [ ] Specifies both fallbacks, the frontier definition with a gh one-liner, and the idempotency rules [manual]
- [ ] Reads as a coherent reference in terse imperative voice; no filler, no TODO markers [manual]

## Task: task-ref-status-sync — Write references/status-sync.md
**Effort**: medium
**Depends-on**: [task-skill-scaffold]
**Skills**: writing-skills

### Description

Author `skills/project-management/zurdo-github/references/status-sync.md`: how Zurdo run state flows to GitHub. Read `.zurdo/prd-01-golang-skill-f2c1/prd.json` and `.zurdo/prd-01-golang-skill-f2c1/progress.log` in this repo as the ground truth for shapes.

Required coverage:
- **Run directory resolution**: `.zurdo/<slug>/` where slug is `<prd-basename>-<hash>`; pick by `--slug` or newest `last_updated`.
- **prd.json shape** as observed: `tasks.<id>.status`, `attempts`, `passed_at`, `iterations[]` with `model`, `tokens_in`, `tokens_out`, `cost_usd_est`, `timed_out`, `criteria_results[]` with `hint` and `passed`.
- **Status enum and mapping**: `passed` → close + comment; `passed-pending-review` → `zurdo:pending-review` + comment, stays open until `zurdo review` signs off and a later sync sees `passed`; `failed` → `zurdo:failed` + comment listing failed hints; `blocked-by-dependency` → no change. Also what a task with `attempts: 0` and `passed-pending-review` means (criteria already held; no agent ran) and how the comment reports that.
- **Label swap rule**: remove the other status label before adding one; never stack; a closed issue is never reopened by sync.
- **Comment template** as fenced markdown: status, attempts, last model, tokens in/out, estimated cost, and for failures the failed hints.
- **Epic table refresh**: the Status column values and how the epic body is rewritten in place without disturbing the intro or the marker.
- **Direction rule**: GitHub never writes back into the PRD or prd.json; if an issue was closed by hand, sync leaves it closed and notes the divergence in its summary.

### Acceptance Criteria

- [ ] status-sync.md exists [file-exists: skills/project-management/zurdo-github/references/status-sync.md]
- [ ] Documents run-directory resolution and the observed prd.json field shapes including iterations, tokens, cost, and criteria_results [manual]
- [ ] Documents the four-status mapping, the attempts-zero case, the label swap rule, the never-reopen rule, and the comment template [manual]
- [ ] Documents the epic table refresh and the one-direction rule with the hand-closed divergence case [manual]
- [ ] Reads as a coherent reference in terse imperative voice; no filler, no TODO markers [manual]

## Task: task-ref-runbook — Write references/runbook.md
**Effort**: medium
**Depends-on**: [task-skill-scaffold]
**Skills**: writing-skills

### Description

Author `skills/project-management/zurdo-github/references/runbook.md`: the operator's sequence for a real repository.

Required coverage:
- **Preconditions**: `gh auth status` must show `repo`; `project` only for `board`; `gh auth refresh -s project` to add it; `jq` present; a clean PRD (`zurdo validate <prd>` exits 0) before publishing, because a parse error at publish time means the PRD is not Zurdo-valid either.
- **Order of operations**: `zurdo validate` → `bootstrap --dry-run` → `bootstrap` → `publish --dry-run` (read the plan: count of issues, edges, labels) → `publish` → optional `board` → after `zurdo run`, `sync-status --dry-run` → `sync-status`; after `zurdo review`, `sync-status` again to close signed-off tasks.
- **Reading a dry-run plan**: what to check before going live (task count equals PRD task count, every Depends-on appears as an edge, no unexpected label creations, repo owner/name correct).
- **Re-running publish** after editing the PRD: what changes in place (title, body, labels, milestone, new edges) and what does not (existing closed issues, assignees, comments); removed tasks are not deleted, the summary lists them as orphans for the human to close.
- **Description touch rules**: milestone description always; repo About only when empty and only with `--about`; README never; board readme mirrors the milestone description.
- **Assignment**: publish assigns only the epic to `@me`; task assignment is the claim and belongs to whoever picks the task up.
- **Conventions doc**: what bootstrap appends to `docs/agents/issue-tracker.md` under `## Zurdo operations`, shown as the exact fenced block, and the skip message when the file is absent.
- **Failure handling**: 4xx fallbacks, `timeout 90` on every network call, rate limits (`gh api rate_limit`), and the exit-code table (0, 1, 2, 3).
- **Sandbox run**: how to do the one live verification against a throwaway repository, and what to inspect in the GitHub UI (milestone progress bar, sub-issue tree on the epic, blocked-by badges on task issues, `ready-for-agent` on frontier tasks only).

### Acceptance Criteria

- [ ] runbook.md exists [file-exists: skills/project-management/zurdo-github/references/runbook.md]
- [ ] Documents preconditions including scopes and zurdo validate, and the full order of operations from validate through the post-review sync [manual]
- [ ] Documents how to read a dry-run plan, re-run semantics including orphaned tasks, the description touch rules, and the assignment rule [manual]
- [ ] Documents the conventions-doc append block, failure handling with the exit-code table, and the sandbox verification checklist [manual]
- [ ] Reads as a coherent reference in terse imperative voice; no filler, no TODO markers [manual]

## Task: task-integrate-verify — Wire the spine, update the catalog, and verify end to end
**Effort**: medium
**Depends-on**: [task-script, task-ref-github-model, task-ref-status-sync, task-ref-runbook]
**Skills**: writing-skills

### Description

Integration pass over the finished skill.

1. Re-read `skills/project-management/zurdo-github/SKILL.md` against the three reference files and the script. Every inline rule must point at the reference that actually holds its depth; every mode and flag named in SKILL.md must exist in the script's usage text; fix drift in SKILL.md, not by weakening the references.
2. Add a `zurdo-github` row to the skills table in `README.md` (path `skills/project-management/zurdo-github/`, trigger summary) and a short `### zurdo-github` subsection in the same style as the golang one, listing the three references and the script. Update the "Repository layout" tree in `README.md` to show the new category directory.
3. Confirm `zurdo validate docs/zurdo-github/prds/prd-01-zurdo-github-skill.md` still exits 0.
4. Run the full dry-run sequence from the runbook against `docs/golang/prds/prd-01-golang-skill.md` and confirm the plan matches: seven task creations, the golang dependency edges (each reference task blocked by the scaffold, the integration task blocked by all five references plus scaffold), `ready-for-agent` on the scaffold task only.

The final `[manual]` criterion is performed by the author, not the executor: one live publish and sync against a throwaway sandbox repository, inspected in the GitHub UI.

### Acceptance Criteria

- [ ] SKILL.md links the github-model reference [grep: references/github-model.md in skills/project-management/zurdo-github/SKILL.md]
- [ ] SKILL.md links the status-sync reference [grep: references/status-sync.md in skills/project-management/zurdo-github/SKILL.md]
- [ ] SKILL.md links the runbook reference [grep: references/runbook.md in skills/project-management/zurdo-github/SKILL.md]
- [ ] SKILL.md names the script [grep: scripts/zurdo-github.sh in skills/project-management/zurdo-github/SKILL.md]
- [ ] README lists the new skill [grep: skills/project-management/zurdo-github/ in README.md]
- [ ] The zurdo-github PRD validates [shell: zurdo validate docs/zurdo-github/prds/prd-01-zurdo-github-skill.md]
- [ ] Dry-run publish marks only the scaffold task ready-for-agent [shell: test "$(skills/project-management/zurdo-github/scripts/zurdo-github.sh publish --dry-run --repo ElOrlis/perro-skills docs/golang/prds/prd-01-golang-skill.md | grep -E 'DRY: .*gh issue create .*zurdo:task' | grep -c 'ready-for-agent' | tr -d ' ')" = "1"]
- [ ] Every inline rule in SKILL.md points at the reference that holds its depth, and every mode and flag named in SKILL.md exists in the script's usage output [manual]
- [ ] Live sandbox verification by the author: milestone with progress bar, epic with sub-issue tree, blocked-by badges on dependent tasks, ready-for-agent on frontier tasks only, and a sync-status run that labels or closes correctly [manual]
