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
docs/                        Design docs / PRDs, one folder per skill
  golang/prds/
  zurdo-github/prds/
  zurdo-project/prds/
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
- **scripts/zurdo-github.sh** — The publishing/sync script; supports `bootstrap`, `scope`, `ticket`, `publish`, `sync-status`, and `board` modes with `--dry-run` and `--repo` flags. `scope` and `board` create the Projects v2 project and link it to the repo

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

## How skills are built

Skills are specified as PRDs under `docs/<skill>/prds/` and executed with [Zurdo](https://github.com/), a task-runner that decomposes a PRD into gated tasks and drives an agent through them. The `.zurdo/` directory holds per-run state and configuration (`.zurdo/config.toml`). Each task gates on explicit acceptance criteria, following the `superpowers:writing-skills` authoring discipline.

## Authoring conventions

- **Progressive disclosure** — `SKILL.md` is a standalone working guide, not a thin index. High-frequency rules live inline as a terse imperative + one-line "why" + an arrow to the relevant reference file. Depth goes in `references/`.
- **Tightly-scoped frontmatter** — `name` plus a `description` that states exactly when the skill should (and should not) trigger.
- **Terse, imperative voice** — no filler, no placeholder/TODO markers; every section is real content.

## Vendored skills

External skills are pinned in `skills-lock.json` with their source, source type, and a content hash so updates are deliberate and verifiable.

## License

See [LICENSE](LICENSE).
