# CLAUDE.md

Guidance for agents working in **perro-skills** — a collection of opinionated agent SKILLs for development.

## What this repo is

This is a *skills* repository, not an application. There is no build, no runtime, no test suite for production code. The deliverables are prose: `SKILL.md` files and their `references/*.md` depth files that steer coding agents toward high-quality work.

## Layout

- `skills/<category>/<skill>/` — published skills. Category folders group by domain (e.g. `programing-languages/golang/`).
  - `SKILL.md` — the standalone spine.
  - `references/*.md` — on-demand depth files.
- `docs/<skill>/prds/` — design docs / PRDs that specify each skill before it is built.
- `.zurdo/` — Zurdo task-runner state and config (`config.toml`). Skills are built by running their PRD through Zurdo.
- `skills-lock.json` — lockfile pinning vendored external skills (source, sourceType, computedHash).
- `.claude/skills/`, `.agents/skills/` — installed authoring tooling (the `zurdo-*` skills and `grill-me`); not part of the published catalog.

## Authoring a skill — the rules

Follow `superpowers:writing-skills` discipline. When creating or editing a skill, invoke that skill first.

1. **Progressive disclosure.** `SKILL.md` is a standalone working guide carrying the high-frequency decision rules **inline**, not a thin index that just links out. Each inline rule is: a terse imperative line + a one-line "why" + an arrow `→ see references/<file>.md` pointing to depth.
2. **Depth lives in `references/`.** Long-form synthesis, examples, and edge cases go in `references/*.md`. `SKILL.md` must have a "References" section linking every reference file with a one-line description.
3. **Frontmatter.** Every `SKILL.md` needs `name` and a tightly-scoped `description` that says exactly when the skill should trigger — and is phrased so it does **not** over-trigger on incidental mentions.
4. **Voice.** Terse, imperative, no filler. No placeholder or TODO markers — every section is real content.

## Build pipeline (Zurdo)

Skills are specified as PRDs (`docs/<skill>/prds/prd-NN-<name>.md`) and executed with Zurdo, which decomposes the PRD into gated tasks with explicit acceptance criteria and drives an agent through them sequentially.

- Executor/analyzer providers and the effort→model mapping live in `.zurdo/config.toml`.
- Per-run state lives under `.zurdo/<run>/`; `progress.log` and `iterations/` are gitignored.
- PRD tasks gate on `file-exists`, `[manual]` rubric criteria, and (sparingly) `grep`/`no-grep` against deterministic strings.

## Conventions & gotchas

- The category path is spelled `programing-languages` (single "m"). Match the existing path; don't "fix" it in references or links.
- Vendored external skills must be added to `skills-lock.json` with a content hash — never copy an external skill in untracked.
- When adding a new skill, create both the `skills/<category>/<skill>/` artifact tree and a corresponding PRD under `docs/<skill>/prds/`, then update `README.md`'s skills table.
- `.zurdo/**/progress.log` and `.zurdo/**/iterations/` are gitignored; commit `prd.json` and config, not run logs.
