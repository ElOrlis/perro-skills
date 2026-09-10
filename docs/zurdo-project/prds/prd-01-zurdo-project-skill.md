# PRD: `zurdo-project` — Run an initiative from idea to phased Zurdo PRDs on a GitHub Project

Build a skill at `skills/project-management/zurdo-project/` that owns the life of an **initiative**: interview the user until the design scope is sharp, record it as a scope document, create one GitHub **Project** for the initiative, create the initial issues (the scope issue, research and grilling tickets, and the first phase's milestone, epic, and tasks), and then loop — run the phase with Zurdo, sync status, review what was learned, graduate the next phase out of the fog, write its PRD, publish it. The skill is prose only. Every deterministic GitHub write goes through `skills/project-management/zurdo-github/scripts/zurdo-github.sh`, which this PRD extends with two modes (`scope`, `ticket`) and two flags (`--scope`, `--project`). `zurdo-github` stays the publisher of a single PRD; `zurdo-project` is the orchestrator above it.

The skill carries its own wayfinding and interview capability. It must work on a machine where the `wayfinder`, `grilling`, `grill-me`, and `domain-modeling` skills are absent: the map mechanics (destination, decisions so far, fog of war, out of scope, claim by assignment, one ticket per session) and the interview mechanics (frontier rounds, numbered questions with a recommended answer, facts are the agent's job) are written inline in this skill's references, in this repo's voice, with no runtime dependency on any personal skill.

Design decisions, settled with the author and binding on every task:

- **Skill boundary.** `zurdo-project` owns scope, research, phase discovery, phase review, and orchestration. `zurdo-github` owns publishing one PRD and syncing one run. `zurdo-project` never calls `gh` directly; it invokes `zurdo-github.sh`.
- **One Project per initiative.** A GitHub Projects v2 project titled after the initiative holds every issue of every phase. Each phase is one Zurdo PRD, which `zurdo-github` publishes as one milestone plus one epic. The board is grouped by milestone; there is no custom Phase field. `board` gains `--project "<title>"` to attach to that Project instead of creating one named after the repository.
- **The scope artifact is a file first, an issue second.** `docs/<initiative>/scope.md` is the source of truth. Its H1 is `# Scope: <initiative title>`; its sections, in order, are `## Destination`, `## Notes`, `## Decisions so far`, `## Phases`, `## Not yet specified`, `## Out of scope`. `## Phases` is a table `| Phase | Title | PRD | Status |` where Phase is `phase-NN`, PRD is a repo-relative path or empty, and Status is one of `planned`, `researching`, `ready`, `running`, `done`. The `scope` mode of the script projects this file onto a single issue labelled `zurdo:scope`, assigned to `@me`, pinned, with the marker `<!-- zurdo-github scope=<initiative> -->` where `<initiative>` is the name of the directory holding `scope.md`. The script enriches the Phases table on the issue with the epic link and milestone it finds by marker; it never writes back into `scope.md`.
- **Tickets are files too.** `docs/<initiative>/tickets/<name>.md` with YAML frontmatter `type: research | grilling`, `question: <one line>`, `status: open | resolved`, optional `blocks: [phase-NN, …]`, optional `blocked-by: [<ticket-name>, …]`; body `## Question` and, once resolved, `## Findings`. The `ticket` mode projects one file onto an issue labelled `zurdo:research` or `zurdo:grilling`, a sub-issue of the scope issue, with the marker `<!-- zurdo-github scope=<initiative> ticket=<name> -->`. `blocked-by` becomes native blocked-by edges between ticket issues; `blocks` becomes a blocked-by edge from the named phase's epic issue to the ticket when that epic exists. A resolved ticket gets a resolution comment holding `## Findings` and is closed; a hand-closed open ticket stays closed and is reported as divergence. The `scope` mode sweeps every file under `tickets/` after processing `scope.md`, so one invocation is a full idempotent refresh.
- **Ticket types are two.** `research` (AFK, resolved by a subagent that reads docs, APIs, or the codebase and writes `## Findings`) and `grilling` (HITL, resolved only by a live exchange with the user; the agent never answers its own questions). No prototype or task tickets: execution belongs to phases.
- **Research feeds the PRD by link.** A phase whose id appears in any open ticket's `blocks` list is `researching` and its PRD must not be written. Once every blocker is resolved, the phase is `ready`, and the PRD's intro prose must link each research ticket file it relied on.
- **Phase discovery cadence.** Phase 1 is specified in the charting session. Later phases stay in `## Not yet specified` until they are sharp. A phase review runs after `sync-status` shows every task of the running phase `passed`: it interviews the user on what was learned, appends to `## Decisions so far`, graduates what is now sharp into new phase rows or new tickets, rules out what falls past the destination, and re-runs `scope`. Only one phase is in `zurdo run` at a time. A later phase that is already sharp may get its milestone and an empty epic ahead of its PRD by adding the row with Status `ready`; the script does not create milestones from rows, the phase's own `publish` does.
- **Fog or ticket test.** Ticket when the question can be stated precisely now, even if it cannot be answered yet. Fog (`## Not yet specified`) when it cannot. Never pre-slice fog into ticket-sized pieces.
- **Out of scope never graduates.** Work ruled past the destination is closed if it was ticketed and listed under `## Out of scope` with a one-line why. It does not appear in `## Decisions so far`.
- **Dependency policy.** Required: `gh`, `jq`, `zurdo`, the `zurdo-github` skill, and the `zurdo-prd-writer` and `zurdo-prd-reviewer` skills (the §2.2 grammar is unforgiving; if either is absent, stop and tell the user to install them, never improvise a PRD). Optional with fallback: `zurdo-prd-decomposer` (fallback: decompose by hand following the writer's heuristics), `zurdo-domain` (a Zurdo bundled skill, install with `zurdo skills install zurdo-domain`; fallback: skip glossary work and say so), `grilling` or `grill-me` (fallback: the inline interview protocol in `references/interview.md`). Detection is by name in the skill list available to the agent at invocation; the runbook carries the table.
- **Interview protocol, inline.** Work a design tree in rounds. The frontier is every question whose prerequisites are settled. Ask the whole frontier in one numbered round, each question with a ➡️ recommended answer, then wait. Facts are the agent's job, decisions are the user's; look up anything that can be looked up before asking. Done when the frontier is empty. Three interview shapes: the destination interview (depth-first, names what reaching the end looks like), the breadth interview (fan out across the space to surface phases, tickets, and fog), and the phase review interview (what was learned, what changed, what is now sharp).
- **Labels** added to the vocabulary: `zurdo:scope`, `zurdo:research`, `zurdo:grilling`, each with a stable color and description, created idempotently by `bootstrap`, `scope`, and `ticket`.
- **Publish learns about scope.** `publish --scope <issue-number>` wires the epic as a sub-issue of the scope issue after the existing wiring pass, and the epic body gets a `Part of #<scope>` first line. `sync-status` is unchanged. `board --project "<title>"` attaches to the named Project, creating it only when absent; without the flag, current behavior stands.
- **Project creation lives in `scope`.** The `scope` mode ensures a Projects v2 project titled after the initiative exists, ensures a `Status` single-select field, and adds the scope issue and every ticket issue to it. When the `project` scope is missing, `scope` prints `skip: project scope missing, run gh auth refresh -s project` and continues with exit 0: the Project is desirable but never blocks scope publishing.
- **Dry-run discipline holds.** Every new code path goes through `run_gh`; under `--dry-run`, lookups are not-found and the output is the full create path. The existing usage contract (exit 2 on a missing mode) and the four existing modes must not regress.
- **Examples double as templates.** `skills/project-management/zurdo-project/examples/` holds a complete `scope.md` and two tickets, one open research ticket that blocks `phase-02` and one resolved grilling ticket, used both as copy-me templates and as the dry-run fixtures this PRD gates on.

Verification philosophy: prose artifacts gate on `file-exists`, `grep` of author-controlled strings, and `[manual]` rubrics; the script gates on `bash -n`, on `--dry-run` runs against the example scope and tickets and against the existing golang PRD at `docs/golang/prds/prd-01-golang-skill.md`, and on greps of that output for deterministic command shapes. The one live run against a sandbox repository is a `[manual]` criterion on the final task performed by the author.

Run order: scaffold and examples first (independent), then the script extension and the five references (independent of one another), then the `zurdo-github` documentation update, then integration. Throughout, follow `superpowers:writing-skills` discipline: correct frontmatter, progressive disclosure, terse imperative voice, no filler, no TODO markers. Effort values are `low`, `medium`, `high` from `.zurdo/config.toml`.

## Task: task-skill-scaffold — Scaffold the zurdo-project SKILL.md standalone spine
**Effort**: medium
**Depends-on**: []
**Skills**: writing-skills

### Description

Create `skills/project-management/zurdo-project/` with `SKILL.md`, an empty `references/` directory, and an empty `examples/` directory.

Frontmatter:
- `name: zurdo-project`
- `description:` — triggers when the user wants to start a project or initiative from an idea, scope an initiative into phases, set up a GitHub Project for it, ask what the next phase is, or run a phase review after a Zurdo run. State explicitly that it does **not** trigger for publishing a single existing PRD (that is `zurdo-github`), for authoring one PRD's tasks (that is `zurdo-prd-writer`), or for general issue triage.

Body — a standalone working guide. Open with a six-stage lifecycle, one line each: Scope, Research, Phase PRD, Publish, Run and sync, Phase review, with the loop from Research back around after each review. Then carry these decision rules inline, each as a terse imperative + one-line why + `→ see references/<file>.md`:
- `scope.md` is the source of truth; the scope issue is a projection; never edit the file from GitHub state. → references/scope-map.md
- One initiative = one Project + one scope issue; one phase = one PRD = one milestone + one epic, all inside that Project. → references/phases.md
- Ticket when the question is sharp, fog when it is not; never pre-slice fog. → references/scope-map.md
- Out of scope never graduates; close the ticket and record the why. → references/scope-map.md
- Two ticket types: research is AFK, grilling is HITL and the agent never answers its own questions. → references/research.md
- A phase blocked by an open research ticket is `researching`; do not write its PRD; the PRD intro links the research it used. → references/research.md
- Interview in frontier rounds, numbered, each with a recommended answer; facts are yours to find, decisions are the user's. → references/interview.md
- Phase 1 is charted in the first session; later phases graduate at phase review, one running phase at a time. → references/phases.md
- Required skills stop the run when missing; optional skills degrade to the inline fallback and say so. → references/runbook.md
- Never call `gh` directly; every write goes through `zurdo-github.sh`, dry-run first. → references/runbook.md
- Claim a ticket by assignment before working it; resolve at most one grilling ticket per session. → references/scope-map.md

Include a "Files" section showing the `docs/<initiative>/` layout: `scope.md`, `tickets/<name>.md`, `research/` is not a separate directory (findings live in the ticket), `prds/prd-NN-<phase>.md`.

Include a "Script calls" section listing the exact `zurdo-github.sh` invocations the lifecycle uses: `scope`, `ticket`, `publish --scope`, `board --project`, `sync-status`, each with `--dry-run` first.

Include a "References" section linking `references/scope-map.md`, `references/interview.md`, `references/research.md`, `references/phases.md`, `references/runbook.md`, each with a one-line description, and an "Examples" line pointing at `examples/scope.md` and `examples/tickets/`.

### Acceptance Criteria

- [ ] SKILL.md exists [file-exists: skills/project-management/zurdo-project/SKILL.md]
- [ ] Frontmatter declares the skill name [grep: name: zurdo-project in skills/project-management/zurdo-project/SKILL.md]
- [ ] The description triggers on starting or scoping an initiative, setting up its GitHub Project, asking for the next phase, or running a phase review, and explicitly excludes single-PRD publishing, single-PRD authoring, and triage [manual]
- [ ] SKILL.md opens with the six-stage lifecycle and carries every inline rule listed in the Description as imperative + why + arrow to a reference file [manual]
- [ ] SKILL.md has Files, Script calls, References, and Examples sections as specified [manual]
- [ ] SKILL.md links every reference file [grep: references/runbook.md in skills/project-management/zurdo-project/SKILL.md]
- [ ] No placeholder markers remain [no-grep: TODO in skills/project-management/zurdo-project/SKILL.md]

## Task: task-examples — Write the example scope and ticket files
**Effort**: low
**Depends-on**: []

### Description

Create the copy-me templates that also serve as dry-run fixtures.

`skills/project-management/zurdo-project/examples/scope.md`:
- H1 `# Scope: Example Initiative`.
- `## Destination`: two lines describing a finished state for a small fictional feature (a CLI that exports a report to CSV and posts it to a webhook).
- `## Notes`: domain, skills to consult, standing preferences (three bullets).
- `## Decisions so far`: one bullet linking a resolved ticket by name, `[Which webhook auth scheme](tickets/webhook-auth.md) — bearer token from env`.
- `## Phases`: the table `| Phase | Title | PRD | Status |` with two rows: `phase-01 | CSV export | docs/example/prds/prd-01-csv-export.md | running` and `phase-02 | Webhook delivery |  | researching`.
- `## Not yet specified`: two loose bullets.
- `## Out of scope`: one bullet with a why.

`skills/project-management/zurdo-project/examples/tickets/webhook-retries.md`: frontmatter `type: research`, `question: What retry and backoff policy do the target webhooks expect?`, `status: open`, `blocks: [phase-02]`; body `## Question` with two sentences.

`skills/project-management/zurdo-project/examples/tickets/webhook-auth.md`: frontmatter `type: grilling`, `question: Which auth scheme should the webhook use?`, `status: resolved`, `blocked-by: []`; body `## Question` then `## Findings` with the decision in three lines.

Frontmatter is fenced by `---` lines; keys are lowercase; list values use `[a, b]` syntax.

### Acceptance Criteria

- [ ] Example scope exists [file-exists: skills/project-management/zurdo-project/examples/scope.md]
- [ ] Example scope has the phases table header [grep: | Phase | Title | PRD | Status | in skills/project-management/zurdo-project/examples/scope.md]
- [ ] Example scope names a researching phase [grep: phase-02 in skills/project-management/zurdo-project/examples/scope.md]
- [ ] Open research ticket exists and blocks phase-02 [file-exists: skills/project-management/zurdo-project/examples/tickets/webhook-retries.md] [grep: phase-02 in skills/project-management/zurdo-project/examples/tickets/webhook-retries.md]
- [ ] Resolved grilling ticket exists with findings [file-exists: skills/project-management/zurdo-project/examples/tickets/webhook-auth.md] [grep: status: resolved in skills/project-management/zurdo-project/examples/tickets/webhook-auth.md] [grep: ## Findings in skills/project-management/zurdo-project/examples/tickets/webhook-auth.md]
- [ ] Both files parse as frontmatter plus body and read as realistic templates a user would copy [manual]

## Task: task-script-modes — Extend zurdo-github.sh with scope and ticket modes and the --scope and --project flags
**Effort**: high
**Depends-on**: [task-examples]
**Max-Attempts**: 4
**Agent-timeout**: 45m

### Description

Extend `skills/project-management/zurdo-github/scripts/zurdo-github.sh` in place. Keep `#!/usr/bin/env bash`, `set -euo pipefail`, the dependency set (`bash`, `awk`, `jq`, `git`, `gh`), the single `run_gh` call site, the dry-run stubs, the exit-code table, and every existing mode's behavior.

**Usage.** `zurdo-github.sh <mode> [--dry-run] [--repo owner/name] [--slug <zurdo-slug>] [--about "<text>"] [--scope <issue-number>] [--project "<title>"] <path>`. Modes: `bootstrap`, `publish`, `sync-status`, `board`, `scope`, `ticket`. For `scope` the path is a `scope.md`; for `ticket` the path is one ticket file; for the other four it is a PRD as today. Unknown mode or missing path still exits 2. The PRD parser must not run for `scope` and `ticket`.

**Scope file parser** (awk to JSON). H1 `# Scope: <title>`; sections by exact H2 names `Destination`, `Notes`, `Decisions so far`, `Phases`, `Not yet specified`, `Out of scope`; the Phases table parsed into `[{phase, title, prd, status}]`. Initiative slug = basename of the directory containing the file. Missing H1 or a Status outside `planned|researching|ready|running|done` prints the offending line and exits 2.

**Ticket file parser.** Frontmatter between the first two `---` lines with keys `type`, `question`, `status`, `blocks`, `blocked-by`; list values in `[a, b]` form; body after the closing fence; `## Findings` section extracted when present. Ticket name = file basename without `.md`. `type` outside `research|grilling` or `status` outside `open|resolved` exits 2.

**Labels.** Add `zurdo:scope`, `zurdo:research`, `zurdo:grilling` with distinct stable colors and descriptions to `ensure_all_labels` so `bootstrap` creates them, and ensure the same three at the start of `scope` and `ticket` without needing a PRD.

**scope mode.** (1) Ensure labels. (2) Scope issue: marker `<!-- zurdo-github scope=<slug> -->`; find by search-then-confirm; title `Scope: <title>`; label `zurdo:scope`; `--assignee @me`; body = marker, then each section verbatim in order, with the Phases table re-rendered as `| Phase | Title | PRD | Epic | Milestone | Status |` where Epic is `#<n>` when an issue with marker `<!-- zurdo-github prd=<prd-path> epic -->` exists and Milestone is the milestone title of that epic, else both empty; create or edit in place; `gh issue pin` after create (ignore failure). (3) For every epic found in step 2, POST it as a sub-issue of the scope issue (skip already-linked 422s). (4) Sweep `tickets/*.md` in the same directory, applying the ticket procedure below to each, then wire ticket-to-ticket `blocked-by` edges and phase-epic-to-ticket `blocks` edges in a second pass. (5) Project: unless `gh auth status` lacks `project` (print `skip: project scope missing, run gh auth refresh -s project` and continue), find or create a Projects v2 project titled `<title>` (or `--project` when given), ensure the `Status` single-select field with options `Todo`, `In Progress`, `Pending Review`, `Done`, `Failed`, add the scope issue and every ticket issue. (6) Summary: scope issue number, tickets created/updated/closed, edges wired with mode `native` or `fallback`, project number or skip.

**ticket procedure** (used by `ticket` mode for one file and by `scope` for the sweep). Marker `<!-- zurdo-github scope=<slug> ticket=<name> -->`; title = `question`; label `zurdo:research` or `zurdo:grilling`; body = `Part of #<scope>` line, marker, `## Question` verbatim, and when resolved `## Findings` verbatim; no assignee; create or edit in place; sub-issue of the scope issue (fallback: `Part of` line already present, plus a `## Tickets` checklist appended to the scope body). When `status: resolved` and the issue is open: comment with the Findings section and close. When `status: open` and the issue is closed: leave closed, print `divergence: <name> closed on GitHub but open in file`. `ticket` mode requires the scope issue to exist; if not found, exit 3 with `run scope first`. Edges: each `blocked-by` name resolves to the ticket issue by marker; each `blocks` phase resolves to the phase row's PRD path in `scope.md`, then to the epic by marker; when the epic exists, POST blocked_by on the epic with the ticket's database id; when it does not, print `defer: phase-NN has no epic yet`.

**publish `--scope <n>`.** After the existing wiring pass, POST the epic as a sub-issue of issue `<n>` (skip 422 already-linked; on 4xx fallback, append `- [ ] #<epic>` to a `## Phases` checklist in issue `<n>`), and prepend `Part of #<n>` to the epic body. Print the mode in the summary.

**board `--project "<title>"`.** Use the given title for lookup and creation instead of the repository name. Everything else unchanged.

**Dry-run stubs.** Add stubs so `scope` and `ticket` complete under `--dry-run`: `issue pin` returns empty, `project list` returns no projects, `auth status` is not called under dry-run (treat the project scope as present so the plan shows the Project path).

**General.** `timeout 90` on network calls, bodies through `--body-file`, human-facing lines name issues by title with the number in parentheses.

### Acceptance Criteria

- [ ] Script parses as bash [shell: bash -n skills/project-management/zurdo-github/scripts/zurdo-github.sh]
- [ ] Usage still exits 2 on a missing mode [shell: skills/project-management/zurdo-github/scripts/zurdo-github.sh >/dev/null 2>&1; test $? -eq 2]
- [ ] Usage names the new modes [shell: skills/project-management/zurdo-github/scripts/zurdo-github.sh --help 2>&1 | grep -q 'scope | ticket']
- [ ] Existing publish dry-run still plans seven golang task issues [shell: test "$(skills/project-management/zurdo-github/scripts/zurdo-github.sh publish --dry-run --repo ElOrlis/perro-skills docs/golang/prds/prd-01-golang-skill.md | grep -E 'DRY: .*gh issue create .*zurdo:task' | wc -l | tr -d ' ')" = "7"]
- [ ] Dry-run scope against the example exits 0 [shell: skills/project-management/zurdo-github/scripts/zurdo-github.sh scope --dry-run --repo ElOrlis/perro-skills skills/project-management/zurdo-project/examples/scope.md > /dev/null]
- [ ] Dry-run scope plans the scope issue with label, assignee, and pin [shell: OUT="$(skills/project-management/zurdo-github/scripts/zurdo-github.sh scope --dry-run --repo ElOrlis/perro-skills skills/project-management/zurdo-project/examples/scope.md)"; echo "$OUT" | grep -E 'DRY: .*gh issue create .*zurdo:scope' | grep -q -- '--assignee @me' && echo "$OUT" | grep -q 'gh issue pin']
- [ ] Dry-run scope plans one research and one grilling ticket [shell: OUT="$(skills/project-management/zurdo-github/scripts/zurdo-github.sh scope --dry-run --repo ElOrlis/perro-skills skills/project-management/zurdo-project/examples/scope.md)"; test "$(echo "$OUT" | grep -E 'DRY: .*gh issue create .*zurdo:research' | wc -l | tr -d ' ')" = "1" && test "$(echo "$OUT" | grep -E 'DRY: .*gh issue create .*zurdo:grilling' | wc -l | tr -d ' ')" = "1"]
- [ ] Dry-run scope closes the resolved ticket with a findings comment [shell: OUT="$(skills/project-management/zurdo-github/scripts/zurdo-github.sh scope --dry-run --repo ElOrlis/perro-skills skills/project-management/zurdo-project/examples/scope.md)"; echo "$OUT" | grep -q 'gh issue comment' && echo "$OUT" | grep -q 'gh issue close']
- [ ] Dry-run scope wires tickets as sub-issues and defers the phase-02 edge [shell: OUT="$(skills/project-management/zurdo-github/scripts/zurdo-github.sh scope --dry-run --repo ElOrlis/perro-skills skills/project-management/zurdo-project/examples/scope.md)"; echo "$OUT" | grep -q '/sub_issues' && echo "$OUT" | grep -q 'defer: phase-02']
- [ ] Dry-run scope plans the Project titled after the initiative and adds items [shell: OUT="$(skills/project-management/zurdo-github/scripts/zurdo-github.sh scope --dry-run --repo ElOrlis/perro-skills skills/project-management/zurdo-project/examples/scope.md)"; echo "$OUT" | grep 'gh project create' | grep -q 'Example Initiative' && echo "$OUT" | grep -q 'gh project item-add']
- [ ] Dry-run scope re-renders the phases table with Epic and Milestone columns [shell: skills/project-management/zurdo-github/scripts/zurdo-github.sh scope --dry-run --repo ElOrlis/perro-skills skills/project-management/zurdo-project/examples/scope.md | grep -q 'Epic | Milestone']
- [ ] Dry-run ticket on the open research ticket exits 3 when no scope issue exists [shell: skills/project-management/zurdo-github/scripts/zurdo-github.sh ticket --dry-run --repo ElOrlis/perro-skills skills/project-management/zurdo-project/examples/tickets/webhook-retries.md >/dev/null 2>&1; test $? -eq 3]
- [ ] Dry-run publish with --scope wires the epic under the scope issue [shell: skills/project-management/zurdo-github/scripts/zurdo-github.sh publish --dry-run --repo ElOrlis/perro-skills --scope 12 docs/golang/prds/prd-01-golang-skill.md | grep -q 'issues/12/sub_issues']
- [ ] Dry-run board with --project uses the given title [shell: skills/project-management/zurdo-github/scripts/zurdo-github.sh board --dry-run --repo ElOrlis/perro-skills --project "Example Initiative" docs/golang/prds/prd-01-golang-skill.md | grep 'gh project create' | grep -q 'Example Initiative']
- [ ] Dry-run bootstrap plans the three new labels [shell: OUT="$(skills/project-management/zurdo-github/scripts/zurdo-github.sh bootstrap --dry-run --repo ElOrlis/perro-skills docs/golang/prds/prd-01-golang-skill.md)"; for l in zurdo:scope zurdo:research zurdo:grilling; do echo "$OUT" | grep -q "gh label create $l " || exit 1; done]
- [ ] Scope parser rejects a bad phase Status and ticket parser rejects a bad type with exit 2 and an offending-line message [manual]
- [ ] Scope body layout, ticket body layout, markers, resolved-ticket close, divergence report, edge wiring with database ids, project skip message, and the `--scope` and `--project` semantics match the PRD's binding decisions [manual]

## Task: task-ref-scope-map — Write references/scope-map.md
**Effort**: medium
**Depends-on**: [task-skill-scaffold]
**Skills**: writing-skills

### Description

Author `skills/project-management/zurdo-project/references/scope-map.md`: the wayfinding mechanics, self-contained.

Required coverage:
- **The destination**: what it is, why it is named first, how it fixes scope; two or three example destinations of different shapes (a spec to hand off, a decision to lock, a change made in place).
- **The scope file** `docs/<initiative>/scope.md`: the exact section order as a fenced template, what each section holds, the Phases table with its five Status values and their meaning, and the rule that the scope issue is a projection refreshed by `zurdo-github.sh scope`.
- **Refer by name**: in everything the human reads, name tickets and phases by title, with the number riding inside the link.
- **Fog or ticket**: the test (can the question be stated precisely now, not answered), examples of each, the no-pre-slicing rule, and how a resolution graduates fog into tickets or phases.
- **Out of scope**: scope not sharpness lands it there; close the ticket, one line with the why; never in Decisions so far; returns only as a fresh initiative.
- **Decisions so far**: one line per resolved ticket, gist plus link; the map is an index, not a store.
- **Claim and resolve**: claim by assignment before work; resolve by writing `## Findings`, flipping `status: resolved`, and running `ticket` so the issue gets its comment and close; at most one grilling ticket per session; research tickets may run in parallel.
- **Concurrency**: other sessions may be editing; always re-run `scope --dry-run` before a live refresh.

### Acceptance Criteria

- [ ] scope-map.md exists [file-exists: skills/project-management/zurdo-project/references/scope-map.md]
- [ ] Carries the scope.md template with all six sections in order [grep: ## Not yet specified in skills/project-management/zurdo-project/references/scope-map.md]
- [ ] Covers destination, refer-by-name, fog-or-ticket with examples, out-of-scope, decisions-so-far, claim-and-resolve, and concurrency as specified [manual]
- [ ] Makes no reference to an external wayfinder skill being required [no-grep: /wayfinder in skills/project-management/zurdo-project/references/scope-map.md]
- [ ] Reads as a coherent reference in terse imperative voice; no filler, no TODO markers [manual]

## Task: task-ref-interview — Write references/interview.md
**Effort**: medium
**Depends-on**: [task-skill-scaffold]
**Skills**: writing-skills

### Description

Author `skills/project-management/zurdo-project/references/interview.md`: the inline interview protocol that replaces an absent `grilling` skill.

Required coverage:
- **The design tree and the frontier**: every decision branches; the frontier is what can be asked now without guessing at unheard answers; ask the whole frontier per round; a question that depends on an open question waits.
- **Question format** as a fenced block: `❓ **Q<n>** - **<title>**: <body>` followed by `➡️ <recommended answer>`; recommendations must be grounded in something looked up and say what; the user may answer "all recommended".
- **Facts versus decisions**: look up facts (filesystem, docs, tools, past tickets) before asking; dispatch a subagent for a fact and ask the rest of the frontier meanwhile; decisions are the user's.
- **Three shapes**: the destination interview (depth-first until the destination is one or two lines), the breadth interview (fan out across the whole space to list phases, tickets, and fog, then stop), the phase review interview (what was learned, what surprised, what is now sharp, what is out). For each, the opening question and the stop condition.
- **When grilling or grill-me is installed**: call it instead, but keep this file's three shapes as the agenda.
- **Grilling tickets**: a grilling ticket is resolved only by this protocol run live with the user; the agent never answers on the user's behalf.
- **Recording**: at the end of any interview, write to `scope.md` first, then refresh the issue.

### Acceptance Criteria

- [ ] interview.md exists [file-exists: skills/project-management/zurdo-project/references/interview.md]
- [ ] Carries the question format with the recommended-answer arrow [grep: ➡️ in skills/project-management/zurdo-project/references/interview.md]
- [ ] Covers frontier rounds, facts versus decisions, the three interview shapes with opening question and stop condition, the installed-skill handoff, the grilling-ticket rule, and the write-file-first recording rule [manual]
- [ ] Reads as a coherent reference in terse imperative voice; no filler, no TODO markers [manual]

## Task: task-ref-research — Write references/research.md
**Effort**: medium
**Depends-on**: [task-skill-scaffold]
**Skills**: writing-skills

### Description

Author `skills/project-management/zurdo-project/references/research.md`: how research tickets are written, run, and consumed.

Required coverage:
- **Ticket file format** as a fenced template: frontmatter keys `type`, `question`, `status`, `blocks`, `blocked-by`; body `## Question` then `## Findings`; naming rule for the file; where it lives.
- **When to open a research ticket**: a decision waits on a fact outside the working directory (third-party API behavior, library limits, prior art, data shapes); not for facts a grep answers.
- **Running research AFK**: spin one subagent per open research ticket; the subagent's brief is the question, the destination, and the notes; it writes `## Findings` with sources, flips `status: resolved`, and runs `zurdo-github.sh ticket <file>`; multiple research tickets run in parallel; a research subagent never edits `scope.md`.
- **Findings quality bar**: cite sources by URL or path; separate observed facts from recommendations; end with the one line the PRD should carry; findings that raise new questions list them under `## Follow-ups` for the reviewer to ticket or fog.
- **Blocking a phase**: `blocks: [phase-NN]` sets the phase to `researching`; the PRD is not written until every blocker is resolved; the script wires the edge when the epic exists and defers otherwise.
- **Consumption**: the phase PRD's intro links each research file it relied on by repo-relative path; `zurdo-prd-writer` and `zurdo-prd-reviewer` read those files as context.
- **Grilling tickets** for contrast: HITL, no subagent, resolved through `references/interview.md`.

### Acceptance Criteria

- [ ] research.md exists [file-exists: skills/project-management/zurdo-project/references/research.md]
- [ ] Carries the ticket template with the blocks key [grep: blocks: in skills/project-management/zurdo-project/references/research.md]
- [ ] Covers when to open, AFK running with subagents, the findings quality bar, phase blocking, PRD consumption by link, and the grilling contrast [manual]
- [ ] Reads as a coherent reference in terse imperative voice; no filler, no TODO markers [manual]

## Task: task-ref-phases — Write references/phases.md
**Effort**: medium
**Depends-on**: [task-skill-scaffold]
**Skills**: writing-skills

### Description

Author `skills/project-management/zurdo-project/references/phases.md`: the phase lifecycle and the phase review.

Required coverage:
- **What a phase is**: one Zurdo PRD at `docs/<initiative>/prds/prd-NN-<phase>.md`, one milestone, one epic, inside the initiative's Project; phase ids `phase-NN` match the PRD number.
- **Status transitions**: `planned` → `researching` (an open ticket blocks it) → `ready` (no open blockers, PRD may be written) → `running` (published and in `zurdo run`) → `done` (every task `passed` after `sync-status`); who flips each, and that only one phase is `running`.
- **Writing the phase PRD**: preconditions (status `ready`, required skills present), the sequence decomposer (optional) → writer → reviewer → `zurdo validate`, the intro must link the research it used and name the destination, tasks carry `Skills:` where a repo skill applies.
- **Publishing a phase**: `bootstrap` once per repo, then `publish --dry-run --scope <n>`, `publish --scope <n>`, `board --project "<title>"`, then `scope` to refresh the Phases table.
- **Running and syncing**: `zurdo run`, then `sync-status --dry-run`, `sync-status`; after `zurdo review`, `sync-status` again; then `scope`.
- **Phase review**: trigger (every task `passed`), the interview agenda from `references/interview.md`, what gets written: Decisions so far entries, graduated phases or tickets, out-of-scope lines, fog rewritten; then `scope --dry-run` and `scope`; the review ends by naming the next `ready` phase or by declaring the initiative done when the destination is reached and no fog remains.
- **Specifying ahead**: a later phase that is already sharp gets its row with Status `ready`; its milestone and epic appear only when its own PRD is published.
- **Worked timeline**: a fenced example of a three-phase initiative showing the scope table after charting, after phase 1 review, and after phase 2 review.

### Acceptance Criteria

- [ ] phases.md exists [file-exists: skills/project-management/zurdo-project/references/phases.md]
- [ ] Names all five statuses in the transition section [grep: researching in skills/project-management/zurdo-project/references/phases.md]
- [ ] Covers phase definition, transitions with owners, PRD writing preconditions and sequence, publishing, running and syncing, the phase review with its outputs and end condition, specifying ahead, and the worked timeline [manual]
- [ ] Reads as a coherent reference in terse imperative voice; no filler, no TODO markers [manual]

## Task: task-ref-runbook — Write references/runbook.md
**Effort**: medium
**Depends-on**: [task-skill-scaffold]
**Skills**: writing-skills

### Description

Author `skills/project-management/zurdo-project/references/runbook.md`: preconditions, dependency detection, and the operator's sequence.

Required coverage:
- **Dependency table** with columns Skill or tool, Required or Optional, How detected, Fallback: `gh` with `repo` (and `project` for the board) scope, `jq`, `zurdo`, `zurdo-github` skill and its script path, `zurdo-prd-writer` (required, stop), `zurdo-prd-reviewer` (required, stop), `zurdo-prd-decomposer` (optional, decompose by hand), `zurdo-domain` (optional, `zurdo skills install zurdo-domain`, else skip glossary work and say so), `grilling` or `grill-me` (optional, inline protocol). Detection is by name in the agent's available skill list and by `command -v` for binaries. The stop message for a missing required skill names what to install and where from.
- **First session, charting**: destination interview → breadth interview → write `scope.md` with phase-01 and tickets → `scope --dry-run` → `scope` → fire research subagents → if phase-01 is `ready`, write its PRD and publish; stop after one session's worth.
- **Every later session**: read `scope.md`, run `scope --dry-run` to see divergence, pick the next action from the Phases table and open tickets in this order: resolve a grilling ticket, run research, write a ready PRD, publish, sync, phase review.
- **Reading a scope dry-run plan**: what to check (ticket count, resolved tickets planned to close, deferred edges named, project step present or skipped).
- **Board**: optional and last; `board --project "<initiative title>"` after each publish; the `project` scope hint.
- **Failure handling**: exit codes 0, 1, 2, 3 and what each means for the operator; divergence lines; what to do when a required skill is missing mid-lifecycle.
- **Sandbox verification**: how to run the whole first session against a throwaway repository, and what to inspect in the GitHub UI: pinned scope issue, ticket sub-issues under it, epic sub-issue under it after publish, blocked-by badge on the epic of a researching phase, the Project grouped by milestone.

### Acceptance Criteria

- [ ] runbook.md exists [file-exists: skills/project-management/zurdo-project/references/runbook.md]
- [ ] Names the required writer and reviewer skills [grep: zurdo-prd-reviewer in skills/project-management/zurdo-project/references/runbook.md]
- [ ] Names the bundled domain skill install command [grep: zurdo skills install zurdo-domain in skills/project-management/zurdo-project/references/runbook.md]
- [ ] Carries the dependency table with detection and fallback per row, the first-session and later-session sequences, the dry-run reading checklist, the board step, failure handling, and the sandbox checklist [manual]
- [ ] Reads as a coherent reference in terse imperative voice; no filler, no TODO markers [manual]

## Task: task-github-docs-update — Document the new modes, flags, and labels in the zurdo-github skill
**Effort**: medium
**Depends-on**: [task-script-modes]
**Skills**: writing-skills

### Description

Bring `skills/project-management/zurdo-github/` prose in line with the extended script, without changing its trigger scope.

1. `SKILL.md`: extend the Modes table with `scope` and `ticket` rows and the invocation shape with `--scope` and `--project`; add two inline rules: `scope.md` and ticket files are sources of truth projected to issues, the script never writes back (→ references/github-model.md); `scope` creates the Project and skips with a hint when the scope is missing, `publish --scope` nests the epic under the scope issue (→ references/runbook.md). Keep the description's exclusions; add "or its scope and tickets" to the trigger sentence so the description still reads as one tight sentence.
2. `references/github-model.md`: add the scope-to-issue and ticket-to-issue mapping rows, the two new markers, the three new labels with colors, the scope and ticket body templates as fenced markdown, the phase-epic-to-ticket blocked-by edge, and the `--scope` sub-issue link with its checklist fallback.
3. `references/runbook.md`: add `scope` and `ticket` to the order of operations, the `--project` step for `board`, the project-scope skip message, the `run scope first` exit-3 case, and the divergence line for hand-closed tickets.
4. `references/status-sync.md`: one paragraph stating that phase status in `scope.md` is derived by the `zurdo-project` skill from `sync-status` outcomes and that `sync-status` itself does not touch the scope issue.

### Acceptance Criteria

- [ ] SKILL.md names the scope mode [grep: `scope` in skills/project-management/zurdo-github/SKILL.md]
- [ ] SKILL.md names the ticket mode [grep: `ticket` in skills/project-management/zurdo-github/SKILL.md]
- [ ] SKILL.md names the --project flag [grep: --project in skills/project-management/zurdo-github/SKILL.md]
- [ ] github-model.md documents the scope marker [grep: zurdo-github scope= in skills/project-management/zurdo-github/references/github-model.md]
- [ ] github-model.md documents the new labels [grep: zurdo:grilling in skills/project-management/zurdo-github/references/github-model.md]
- [ ] runbook.md documents the ticket-before-scope exit case [grep: run scope first in skills/project-management/zurdo-github/references/runbook.md]
- [ ] The description remains one tightly scoped sentence that still excludes triage, PR work, and PRD authoring [manual]
- [ ] Every new mode, flag, marker, label, and fallback in the script is documented in the reference that holds that concern, in the existing voice [manual]

## Task: task-integrate-verify — Wire both skills, update the catalog, and verify end to end
**Effort**: medium
**Depends-on**: [task-script-modes, task-ref-scope-map, task-ref-interview, task-ref-research, task-ref-phases, task-ref-runbook, task-github-docs-update]
**Skills**: writing-skills

### Description

Integration pass over both skills.

1. Re-read `skills/project-management/zurdo-project/SKILL.md` against its five references and the examples. Every inline rule must point at the reference that holds its depth; every script invocation named in SKILL.md must exist in the script's usage text; the Files section must match the examples layout. Fix drift in SKILL.md, not by weakening the references.
2. Confirm no file under `skills/project-management/zurdo-project/` requires an external `wayfinder` skill; the word may appear only as a credit in prose that says the mechanics are inline.
3. Add a `zurdo-project` row to the skills table in `README.md` (path `skills/project-management/zurdo-project/`, trigger summary) and a `### zurdo-project` subsection in the same style as the others, listing the five references and the examples. Update the "Repository layout" tree to show the new skill and `docs/zurdo-project/`.
4. Confirm `zurdo validate docs/zurdo-project/prds/prd-01-zurdo-project-skill.md` and `zurdo validate docs/zurdo-github/prds/prd-01-zurdo-github-skill.md` both exit 0.
5. Run the full first-session dry-run sequence from the runbook against the examples and the golang PRD: `scope --dry-run`, `publish --dry-run --scope 12`, `board --dry-run --project "Example Initiative"`, and confirm the plans match the runbook's reading checklist.

The final `[manual]` criterion is performed by the author, not the executor: one live charting session against a throwaway sandbox repository, inspected in the GitHub UI.

### Acceptance Criteria

- [ ] SKILL.md links the scope-map reference [grep: references/scope-map.md in skills/project-management/zurdo-project/SKILL.md]
- [ ] SKILL.md links the interview reference [grep: references/interview.md in skills/project-management/zurdo-project/SKILL.md]
- [ ] SKILL.md links the research reference [grep: references/research.md in skills/project-management/zurdo-project/SKILL.md]
- [ ] SKILL.md links the phases reference [grep: references/phases.md in skills/project-management/zurdo-project/SKILL.md]
- [ ] SKILL.md names the script it drives [grep: scripts/zurdo-github.sh in skills/project-management/zurdo-project/SKILL.md]
- [ ] README lists the new skill [grep: skills/project-management/zurdo-project/ in README.md]
- [ ] The zurdo-project PRD validates [shell: zurdo validate docs/zurdo-project/prds/prd-01-zurdo-project-skill.md]
- [ ] The zurdo-github PRD still validates [shell: zurdo validate docs/zurdo-github/prds/prd-01-zurdo-github-skill.md]
- [ ] Full first-session dry-run sequence exits 0 [shell: S=skills/project-management/zurdo-github/scripts/zurdo-github.sh; $S scope --dry-run --repo ElOrlis/perro-skills skills/project-management/zurdo-project/examples/scope.md >/dev/null && $S publish --dry-run --repo ElOrlis/perro-skills --scope 12 docs/golang/prds/prd-01-golang-skill.md >/dev/null && $S board --dry-run --repo ElOrlis/perro-skills --project "Example Initiative" docs/golang/prds/prd-01-golang-skill.md >/dev/null]
- [ ] Every inline rule in SKILL.md points at the reference that holds its depth, every invocation named exists in the script usage, and the Files section matches the examples [manual]
- [ ] Live sandbox verification by the author: pinned scope issue with ticket sub-issues, Project created and populated, epic nested under the scope issue after publish, blocked-by badge on a researching phase's epic once it exists, resolved ticket closed with its findings comment [manual]
