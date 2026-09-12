---
name: zurdo-project
description: >
  Triggers when the user wants to start a project or initiative from an idea, scope an initiative
  into phases, set up a GitHub Project for it, ask what the next phase is, or run a phase review
  after a Zurdo run. Does NOT trigger for publishing a single existing PRD to GitHub (that is
  zurdo-github), for authoring one PRD's tasks (that is zurdo-prd-author), or for general issue
  triage.
---

# zurdo-project

Orchestrate a multi-phase initiative from raw idea to shipped phases: scope it, research it, write phase PRDs, publish them to GitHub, run Zurdo, and review before the next phase.

## Lifecycle

1. **Scope** — capture the idea in `docs/<initiative>/scope.md`; open a scope issue as a pointer.
2. **Research** — open grilling and research tickets for any fog; resolve them before writing PRDs.
3. **Phase PRD** — graduate the next phase from the scope table; invoke `zurdo-prd-author` to author and review it in one interview. A phase that must adjudicate approaches on evidence gets a design record first (`zurdo-design-author`).
4. **Publish** — commit the PRD with its `.trail.md` sidecar and any `lessons/` files, then invoke `zurdo-github` to push the PRD to GitHub as milestone + epic + task issues.
5. **Run and sync** — run Zurdo (`zurdo-state-summary` to check a run, `zurdo-hint-debugger` for a failing criterion), then `zurdo-github sync-status` to mirror outcomes back to GitHub.
6. **Phase review** — invoke `zurdo-prd-review` for the intent-level verdict, run the review interview, update `scope.md`, then loop back to Research for the next phase.

## Decision Rules

**`scope.md` is the source of truth; the scope issue, the Project description, and the Project README are projections; never edit the file from GitHub state.**
GitHub issues and Project fields are read-only projections. Editing from them creates drift and breaks the single-source model.
→ see references/scope-map.md

**One initiative = one Project + one scope issue; one phase = one PRD = one milestone + one epic, all inside that Project.**
The Project board is the wayfinding surface; every phase's epic and milestone belong to it. Mixing initiatives into one Project makes status filtering unreliable.
→ see references/phases.md

**The Project's description is the Destination and its README is the scope body; `scope` refreshes both, so re-run it after every `scope.md` edit.**
A newcomer opens the board before the issue list, so the board's front page must state the destination and the phase table without a click-through. Hand-edits to those fields are lost on the next `scope` run.
→ see references/scope-map.md

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

**Phase status is exactly one of `planned`, `researching`, `ready`, `running`, `done`; the `scope` parser rejects any other word.**
The script exits 2 on a row whose Status is outside that set, so a stray `review` or `blocked` halts every projection until it is fixed. `ready` means the PRD may be written; `running` starts only after publish.
→ see references/phases.md

**A dry-run plans the full create path; it does not diff against GitHub.**
Under `--dry-run` every lookup is assumed not-found, so the plan proves the files parse and lists every command that could run. Create-versus-update decisions, `divergence:` lines, and the project-scope skip appear only in the live run's output, so read that too.
→ see references/runbook.md

**Required skills stop the run when missing; optional skills degrade to the inline fallback and say so.**
Required: `zurdo-prd-author` (consolidates decomposition, grammar, criteria, and review) plus the peer skills it calls, `zurdo-domain` and `zurdo-lessons`. Install all three at once with `zurdo skills install --all`. Optional: `zurdo-design-author`, `zurdo-prd-review`, `zurdo-state-summary`, `zurdo-hint-debugger`, `zurdo-wayfinder`, `zurdo-handoff`; each has a stated fallback.
→ see references/runbook.md

**Orient before acting and hand off before stopping; the files are truth and the handoff is a hint.**
Every later session opens with `zurdo-wayfinder` (fallback: steps 1 to 3 of the later-session sequence by hand) and closes with `zurdo-handoff` writing `docs/<initiative>/handoff.md` as the last commit (fallback: the seven headings by hand). The next session re-checks the handoff against `scope.md`, the ticket files, and `prd.json` before trusting its next action.
→ see references/runbook.md

**Green criteria are necessary, not sufficient; the phase review starts with `zurdo-prd-review`, not with the interview.**
A hint can pass while the diff misses the point. The intent review binds the run diff to each task's intent, and a gaps verdict yields a follow-up PRD that runs under the same phase before it can be `done`.
→ see references/phases.md

**Commit the PRD, its `.trail.md` sidecar, and any `lessons/` files in one commit before publishing.**
That commit is the human review gate the lesson library relies on; `zurdo-prd-review` reads the trail as the best intent source when judging the run.
→ see references/phases.md

**Never call `gh` directly; every write goes through `zurdo-github.sh`, dry-run first. The only exceptions are claiming a ticket by assignment and closing the scope issue when the initiative is done.**
Direct `gh` calls bypass the dry-run gate, the marker system, and the idempotency logic. A botched direct call can create duplicate issues with no marker to merge on re-run. Assignment and the final close are the two writes the script never performs.
→ see references/runbook.md

**Claim a ticket by assignment before working it; resolve at most one grilling ticket per session.**
Claiming prevents concurrent edits from two agents. One grilling ticket per session keeps interviews focused; stacking multiple grilling questions in one turn exhausts the user's attention.
→ see references/scope-map.md

## Files

```
docs/<initiative>/
  scope.md                   # source of truth: Destination / Notes / Decisions / Phases table / Not yet specified / Out of scope
  tickets/<name>.md          # frontmatter: type (research|grilling), status, blocks, blocked-by; findings inline
  design/<topic>.md          # optional design record (zurdo-design-author) for a phase that needs evidence-based adjudication
  handoff.md                 # written by zurdo-handoff at every stop; one file, overwritten; read by zurdo-wayfinder
  prds/
    prd-01-<phase>.md        # phase 1 PRD
    prd-01-<phase>.trail.md  # reasoning trail written by zurdo-prd-author; committed with the PRD
    prd-01-<phase>-followup.md  # only if zurdo-prd-review found gaps; runs under the same phase
    prd-02-<phase>.md        # phase 2 PRD, written only after phase 1 review
lessons/                     # repo root: cross-PRD corrections written by zurdo-prd-author and zurdo-prd-review
```

Research findings live in the ticket file itself; there is no separate `research/` directory.

## Script calls

All GitHub writes go through `scripts/zurdo-github.sh`. Every mode takes a file path as its last argument: `scope.md` for `scope`, one ticket file for `ticket`, the phase PRD for everything else; a missing path exits 2. Always pass `--dry-run` first and read the plan before the live run.

| Invocation | Purpose |
|---|---|
| `zurdo-github.sh bootstrap [--dry-run] <prd>` | Once per repo, before the first publish: create the label vocabulary (needs any PRD for its `Effort` values); safe to repeat |
| `zurdo-github.sh scope --dry-run docs/<initiative>/scope.md` | Preview the scope issue, one issue per file under `tickets/`, the edges, and the Project payload |
| `zurdo-github.sh scope docs/<initiative>/scope.md` | Create or update the scope issue, sweep every `tickets/*.md`, wire ticket and epic edges, create the Project, link it to the repo, set its description and README |
| `zurdo-github.sh ticket --dry-run docs/<initiative>/tickets/<name>.md` | Preview one ticket issue |
| `zurdo-github.sh ticket docs/<initiative>/tickets/<name>.md` | Create or update one ticket issue; comment and close it when the file is `resolved`; exits 3 until `scope` has run; wires no edges |
| `zurdo-github.sh publish --dry-run --scope <n> <prd>` | Preview full publish: milestone, epic, task issues, edges, nesting under scope issue `<n>` |
| `zurdo-github.sh publish --scope <n> <prd>` | Publish the phase PRD and nest its epic under the scope issue |
| `zurdo-github.sh board --project "<title>" --dry-run <prd>` | Preview enrollment of the PRD's task issues on the initiative's Project |
| `zurdo-github.sh board --project "<title>" <prd>` | Enroll the task issues and set their Status; pass the initiative title or a second board is created |
| `zurdo-github.sh sync-status --dry-run <prd>` | Preview status sync from the newest `.zurdo/<prd-basename>-*/` run (`--slug` pins one) |
| `zurdo-github.sh sync-status <prd>` | Mirror Zurdo run outcomes back to GitHub issue statuses |

## References

- [references/scope-map.md](references/scope-map.md) — Source-of-truth model: `scope.md` structure, ticket types, fog vs. sharp questions, out-of-scope handling, and claim discipline.
- [references/interview.md](references/interview.md) — Interview mechanics: frontier rounds, recommendation format, what counts as a fact vs. a decision.
- [references/research.md](references/research.md) — Research and grilling ticket lifecycle: AFK vs. HITL, blocking rules, PRD traceability links.
- [references/phases.md](references/phases.md) — Phase model: one-at-a-time graduation, scope table columns, milestone + epic relationship, phase review checklist.
- [references/runbook.md](references/runbook.md) — Operational runbook: required vs. optional skills, `zurdo-github.sh` invocation patterns, dry-run gate, auth prerequisites.

## Examples

- [examples/scope.md](examples/scope.md) — Annotated `scope.md` for a sample initiative.
- [examples/tickets/](examples/tickets/) — Sample research and grilling ticket files.
