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
docs/                        Design docs / PRDs, one folder per skill
  golang/prds/
skills-lock.json             Lockfile for vendored external skills
.zurdo/                      Zurdo task-runner state (skill build pipeline)
.claude/, .agents/           Installed authoring tooling (see below)
```

## Skills

| Skill | Path | Triggers on |
|-------|------|-------------|
| `golang` | `skills/programing-languages/golang/` | Writing or modifying Go source — idioms, naming/style, concurrency correctness, testing patterns |

### `golang`

An authoring-first Go skill. The `SKILL.md` spine carries the high-frequency decision rules inline so the common case needs no reference load; five `references/*.md` files provide depth:

- **idioms.md** — accept-interfaces/return-concrete, zero values, `new` vs `make`, error handling, `%w` wrapping, avoiding `panic` in libraries
- **naming-and-style.md** — `MixedCaps`, scope-proportional names, package naming, initialism casing, getter naming, error strings, `gofmt` enforcement
- **testing.md** — table-driven tests, `t.Run` subtests, testing observable state, avoiding change-detector tests
- **concurrency-and-memory.md** — channel discipline, `sync` primitives, the race detector (`-race`), goroutine lifecycle, context cancellation
- **philosophy.md** — when to break style rules, simplicity over cleverness, avoiding `regexp` for structured input

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
