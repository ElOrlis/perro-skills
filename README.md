# perro-skills

Opinionated agent SKILLs for development.

A curated collection of [agent skills](https://docs.claude.com/en/docs/claude-code/skills) that steer coding agents toward idiomatic, high-quality work. Each skill is authored with **progressive disclosure**: a lean, standalone `SKILL.md` spine carrying the high-frequency decision rules inline, plus on-demand `references/*.md` files for depth.

## Repository layout

```
skills/                      Published skills, organized by category
  programing-languages/
    golang/                  Go authoring skill
      SKILL.md               Standalone spine — inline decision rules
      references/            On-demand depth files
  project-management/
    zurdo-github/            Publish Zurdo PRDs to GitHub
      SKILL.md               Standalone spine — inline decision rules
      references/            On-demand depth files
      scripts/               zurdo-github.sh — the publishing/sync script
    zurdo-project/           Orchestrate a multi-phase initiative end-to-end
      SKILL.md               Standalone spine — inline decision rules
      references/            On-demand depth files
      examples/              Annotated scope.md and sample ticket files
    zurdo-handoff/           Close a session: write the handoff file
      SKILL.md               Standalone spine — inline decision rules
      references/            On-demand depth files
      examples/              A complete handoff.md
    zurdo-wayfinder/         Open a session: read-only orientation and one next action
      SKILL.md               Standalone spine — inline decision rules
      references/            On-demand depth files
docs/                        Design docs / PRDs, one folder per skill
  golang/prds/
  zurdo-github/prds/
  zurdo-project/prds/
  zurdo-handoff/design/      Design record for zurdo-handoff and zurdo-wayfinder
  zurdo-handoff/prds/
  zurdo-wayfinder/prds/
  guides/                    Cross-skill guides: zurdo-skills-field-guide.md (which skill, when) and zurdo-github-journey.md (every station in depth)
skills-lock.json             Lockfile for vendored external skills
.zurdo/                      Zurdo task-runner state (skill build pipeline)
.claude/, .agents/           Installed authoring tooling (see below)
```

## Skills

| Skill | Path | Triggers on |
|-------|------|-------------|
| `golang` | `skills/programing-languages/golang/` | Writing or modifying Go source — idioms, naming/style, concurrency correctness, testing patterns |
| `zurdo-github` | `skills/project-management/zurdo-github/` | Publishing a Zurdo PRD to GitHub as milestones, epics, issues, labels, or a project board; syncing Zurdo run status back to GitHub issues |
| `zurdo-project` | `skills/project-management/zurdo-project/` | Starting a new initiative from an idea, scoping it into phases, setting up a GitHub Project, asking what the next phase is, or running a phase review after a Zurdo run. Requires the bundled `zurdo-prd-author`, `zurdo-domain`, and `zurdo-lessons` skills (`zurdo skills install --all`) |
| `zurdo-handoff` | `skills/project-management/zurdo-handoff/` | Ending or pausing a session on a Zurdo initiative or PRD: "hand off", "stop here", "pick this up later"; before waiting on a human or leaving `zurdo run` unattended. Writes `docs/<initiative>/handoff.md` as the session's last commit |
| `zurdo-wayfinder` | `skills/project-management/zurdo-wayfinder/` | Asking where an initiative stands, what this session should do, or to be caught up; the start of any session resuming an existing initiative. Read-only: reports and names one next action, never acts |

### `golang`

An authoring-first Go skill. The `SKILL.md` spine carries the high-frequency decision rules inline so the common case needs no reference load; five `references/*.md` files provide depth:

- **idioms.md** — accept-interfaces/return-concrete, zero values, `new` vs `make`, error handling, `%w` wrapping, avoiding `panic` in libraries
- **naming-and-style.md** — `MixedCaps`, scope-proportional names, package naming, initialism casing, getter naming, error strings, `gofmt` enforcement
- **testing.md** — table-driven tests, `t.Run` subtests, testing observable state, avoiding change-detector tests
- **concurrency-and-memory.md** — channel discipline, `sync` primitives, the race detector (`-race`), goroutine lifecycle, context cancellation
- **philosophy.md** — when to break style rules, simplicity over cleverness, avoiding `regexp` for structured input

### `zurdo-github`

A publishing and sync skill. The `SKILL.md` spine carries the high-frequency decision rules for creating and updating GitHub structure from a Zurdo PRD. Three `references/*.md` files provide depth, and a shell script implements the operations:

- **github-model.md** — Data model: how PRD concepts map to GitHub milestones, epics, task issues, labels, markers, and dependency edges
- **status-sync.md** — Status mapping: how each Zurdo task outcome translates to GitHub label swaps, issue state, and comments
- **runbook.md** — Operational runbook: auth prerequisites, invocation examples, re-run safety, rollback, and troubleshooting
- **scripts/zurdo-github.sh** — The publishing/sync script; supports `bootstrap`, `scope`, `ticket`, `publish`, `sync-status`, and `board` modes with `--dry-run` and `--repo` flags. `scope` and `board` create the Projects v2 project and link it to the repo; `scope` also sets the Project description and README from `scope.md`. `sync-status` closes, labels, and comments each task issue from the run's `prd.json`, then rewrites the Status column of the epic's task table in place; its comments stack on re-runs, so sync once per settled run

### `zurdo-project`

An initiative orchestration skill. The `SKILL.md` spine carries the high-frequency decision rules for the full lifecycle — scope, research, PRD authoring, publish, run, phase review — with all mechanics inline. Five `references/*.md` files provide depth, and the shared `zurdo-github.sh` script handles every GitHub write.

It orchestrates Zurdo's bundled skills rather than duplicating them: `zurdo-prd-author` (required; one interview covering decomposition, §2.2 grammar, criteria forcing, and review) with its peers `zurdo-domain` and `zurdo-lessons` (required); `zurdo-design-author` (optional design record before a PRD); `zurdo-prd-review` (intent-level review that opens every phase review); `zurdo-state-summary` and `zurdo-hint-debugger` (run monitoring and criterion forensics). Install them all with `zurdo skills install --all`.

- **scope-map.md** — Source-of-truth model: `scope.md` structure, ticket types, fog vs. sharp questions, out-of-scope handling, and claim discipline
- **interview.md** — Interview mechanics: frontier rounds, recommendation format, what counts as a fact vs. a decision
- **research.md** — Research and grilling ticket lifecycle: AFK vs. HITL, blocking rules, PRD traceability links
- **phases.md** — Phase model: one-at-a-time graduation, scope table columns, milestone + epic relationship, phase review checklist
- **runbook.md** — Operational runbook: required vs. optional zurdo skills with fallbacks, `zurdo-github.sh` invocation patterns, dry-run gate, auth prerequisites, project-to-repo link check
- **examples/scope.md** — Annotated `scope.md` for a sample initiative
- **examples/tickets/** — Sample research and grilling ticket files

### `zurdo-handoff`

A session-closing skill. The `SKILL.md` spine carries the five stop points and the rules for the one file a stopping session leaves behind: `docs/<initiative>/handoff.md`, seven fixed sections, exactly one next action in `zurdo-project`'s priority-row vocabulary, overwritten at every stop and committed alone as the session's last commit. Nothing durable lives only in the handoff; decisions, lessons, and facts are pointed at their homes. Three `references/*.md` files provide depth:

- **record.md** — The template, the per-section table, the graduation rule, what never goes in, placement in a PRD-only repository
- **stop-points.md** — The five stop points in depth, commit-is-the-last-act, the human-wait and AFK stops, what to tell the user
- **receivers.md** — What the next session, the user, and a stopped skill chain each need; why the research subagent brief stays in `zurdo-project`
- **examples/handoff.md** — A complete handoff for the example initiative, stopped at Run and sync with one human wait open

### `zurdo-wayfinder`

A read-only orientation skill. The `SKILL.md` spine carries the authority ladder (files, run state, git, handoff, GitHub), the freshness test that marks the last handoff `fresh`, `stale`, or `none`, and the one-action rule: a row of `zurdo-project`'s priority table when an initiative exists, one of `zurdo-state-summary`'s six verbs in a PRD-only repository, never a third vocabulary. It emits a fixed-shape situation report and ends by naming the skill that acts. Three `references/*.md` files provide depth:

- **inputs.md** — The five inputs with exact commands, what each proves and does not, the freshness test in full, delegation to `zurdo-state-summary`, PRD-only degradation
- **situation-report.md** — The report shape, with fresh, stale, no-handoff, and PRD-only variants worked
- **next-action.md** — Every priority row with the check that selects it and the check that blocks it, the six run verbs, the `Do not` catalogue, who acts

The design record that decided both skills, with the incumbents table, the measured gap, and the rejected alternatives, is at [docs/zurdo-handoff/design/handoff-and-wayfinder.md](docs/zurdo-handoff/design/handoff-and-wayfinder.md).

### Using the four Zurdo skills together

Every session on an initiative has the same shape: open with `zurdo-wayfinder`, act on the one priority row it names through `zurdo-project`, let `zurdo-github` project each file change to GitHub, and close with `zurdo-handoff`. Two guides cover it:

- [docs/guides/zurdo-skills-field-guide.md](docs/guides/zurdo-skills-field-guide.md) is the short version: a one-line-per-skill table of when to reach for each and what it hands to the next, the rules that pick the skill, a short story of six sessions on one initiative with the row each one runs and why, and the mistakes the story avoids. Read it before a session.
- [docs/guides/zurdo-github-journey.md](docs/guides/zurdo-github-journey.md) walks the full lifecycle station by station — scope, tickets, PRD, publish, run, sync, phase review, and the session's open (`zurdo-wayfinder`) and close (`zurdo-handoff`) — with mermaid diagrams of the source-of-truth model, the GitHub object nesting, the phase state machine, the status-sync mapping, and the per-session decision tree, plus a week of worked stories.

## How skills are built

Skills are specified as PRDs under `docs/<skill>/prds/` and executed with [Zurdo](https://github.com/), a task-runner that decomposes a PRD into gated tasks and drives an agent through them. The `.zurdo/` directory holds per-run state and configuration (`.zurdo/config.toml`). Each task gates on explicit acceptance criteria and follows the authoring conventions below.

## Authoring conventions

- **Progressive disclosure** — `SKILL.md` is a standalone working guide, not a thin index. High-frequency rules live inline as a terse imperative + one-line "why" + an arrow to the relevant reference file. Depth goes in `references/`.
- **Tightly-scoped frontmatter** — `name` plus a `description` that states exactly when the skill should (and should not) trigger.
- **Terse, imperative voice** — no filler, no placeholder/TODO markers; every section is real content.

## Vendored skills

External skills are pinned in `skills-lock.json` with their source, source type, and a content hash so updates are deliberate and verifiable.

## License

See [LICENSE](LICENSE).
