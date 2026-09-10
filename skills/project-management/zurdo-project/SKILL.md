---
name: zurdo-project
description: >
  Triggers when the user wants to start a project or initiative from an idea, scope an initiative
  into phases, set up a GitHub Project for it, ask what the next phase is, or run a phase review
  after a Zurdo run. Does NOT trigger for publishing a single existing PRD to GitHub (that is
  zurdo-github), for authoring one PRD's tasks (that is zurdo-prd-writer), or for general issue
  triage.
---

# zurdo-project

Orchestrate a multi-phase initiative from raw idea to shipped phases: scope it, research it, write phase PRDs, publish them to GitHub, run Zurdo, and review before the next phase.

## Lifecycle

1. **Scope** — capture the idea in `docs/<initiative>/scope.md`; open a scope issue as a pointer.
2. **Research** — open grilling and research tickets for any fog; resolve them before writing PRDs.
3. **Phase PRD** — graduate the next phase from the scope table; invoke `zurdo-prd-writer` to author it.
4. **Publish** — invoke `zurdo-github` to push the PRD to GitHub as milestone + epic + task issues.
5. **Run and sync** — run Zurdo, then `zurdo-github sync-status` to mirror outcomes back to GitHub.
6. **Phase review** — review outcomes, update `scope.md`, then loop back to Research for the next phase.

## Decision Rules

**`scope.md` is the source of truth; the scope issue is a projection; never edit the file from GitHub state.**
GitHub issues are read-only projections. Editing from them creates drift and breaks the single-source model.
→ see references/scope-map.md

**One initiative = one Project + one scope issue; one phase = one PRD = one milestone + one epic, all inside that Project.**
The Project board is the wayfinding surface; every phase's epic and milestone belong to it. Mixing initiatives into one Project makes status filtering unreliable.
→ see references/phases.md

**Ticket when the question is sharp, fog when it is not; never pre-slice fog.**
Slicing fog early produces tickets that evaporate or contradict each other. Leave foggy areas in the Notes section until a research or grilling ticket sharpens them.
→ see references/scope-map.md

**Out of scope never graduates; close the ticket and record the why.**
An out-of-scope item that gets re-evaluated later needs its reason on record; closing without a comment loses the decision.
→ see references/scope-map.md

**Two ticket types: research is AFK, grilling is HITL and the agent never answers its own questions.**
Research tickets let a subagent run unattended. Grilling tickets require the user's judgment; the agent surfaces the question, waits, and records the answer — it never fills in the answer itself.
→ see references/research.md

**A phase blocked by an open research ticket is `researching`; do not write its PRD; the PRD intro links the research it used.**
Writing a PRD before research closes embeds assumptions that may be invalidated. The link in the PRD intro provides traceability.
→ see references/research.md

**Interview in frontier rounds, numbered, each with a recommended answer; facts are yours to find, decisions are the user's.**
Facts can be discovered without asking; decisions require the user's values. Numbering rounds lets the user scan prior context. Recommendations reduce cognitive load without removing agency.
→ see references/interview.md

**Phase 1 is charted in the first session; later phases graduate at phase review, one running phase at a time.**
Graduating multiple phases in parallel produces scope pressure and makes the board unreadable. One active phase keeps the milestone signal clean.
→ see references/phases.md

**Required skills stop the run when missing; optional skills degrade to the inline fallback and say so.**
Required: `zurdo-prd-writer`, `zurdo-prd-reviewer`. Optional: `zurdo-domain` (install via `zurdo skills install zurdo-domain`; falls back to inline domain modeling if absent).
→ see references/runbook.md

**Never call `gh` directly; every write goes through `zurdo-github.sh`, dry-run first.**
Direct `gh` calls bypass the dry-run gate, the marker system, and the idempotency logic. A botched direct call can create duplicate issues with no marker to merge on re-run.
→ see references/runbook.md

**Claim a ticket by assignment before working it; resolve at most one grilling ticket per session.**
Claiming prevents concurrent edits from two agents. One grilling ticket per session keeps interviews focused; stacking multiple grilling questions in one turn exhausts the user's attention.
→ see references/scope-map.md

## Files

```
docs/<initiative>/
  scope.md                   # source of truth: Destination / Notes / Decisions / Phases table / Not yet specified / Out of scope
  tickets/<name>.md          # frontmatter: type (research|grilling), status, blocks, blocked-by; findings inline
  prds/
    prd-01-<phase>.md        # phase 1 PRD
    prd-02-<phase>.md        # phase 2 PRD, written only after phase 1 review
```

Research findings live in the ticket file itself; there is no separate `research/` directory.

## Script calls

All GitHub writes go through `scripts/zurdo-github.sh`. Always pass `--dry-run` first and read the plan before the live run.

| Invocation | Purpose |
|---|---|
| `zurdo-github.sh scope --dry-run` | Preview scope issue creation |
| `zurdo-github.sh scope` | Create (or update) the scope issue from `scope.md` |
| `zurdo-github.sh ticket --dry-run` | Preview ticket issue creation |
| `zurdo-github.sh ticket` | Create a research or grilling ticket issue |
| `zurdo-github.sh publish --dry-run --scope <n> <prd>` | Preview full publish: milestone, epic, task issues, board membership |
| `zurdo-github.sh publish --scope <n> <prd>` | Publish the phase PRD into the initiative's Project |
| `zurdo-github.sh board --project "<title>" --dry-run` | Preview Project board creation and issue enrollment |
| `zurdo-github.sh board --project "<title>"` | Create or update the Project board |
| `zurdo-github.sh sync-status --dry-run` | Preview status sync from the latest Zurdo run |
| `zurdo-github.sh sync-status` | Mirror Zurdo run outcomes back to GitHub issue statuses |

## References

- [references/scope-map.md](references/scope-map.md) — Source-of-truth model: `scope.md` structure, ticket types, fog vs. sharp questions, out-of-scope handling, and claim discipline.
- [references/interview.md](references/interview.md) — Interview mechanics: frontier rounds, recommendation format, what counts as a fact vs. a decision.
- [references/research.md](references/research.md) — Research and grilling ticket lifecycle: AFK vs. HITL, blocking rules, PRD traceability links.
- [references/phases.md](references/phases.md) — Phase model: one-at-a-time graduation, scope table columns, milestone + epic relationship, phase review checklist.
- [references/runbook.md](references/runbook.md) — Operational runbook: required vs. optional skills, `zurdo-github.sh` invocation patterns, dry-run gate, auth prerequisites.

## Examples

- [examples/scope.md](examples/scope.md) — Annotated `scope.md` for a sample initiative.
- [examples/tickets/](examples/tickets/) — Sample research and grilling ticket files.
