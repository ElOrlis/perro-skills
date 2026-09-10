---
name: zurdo-prd-review
description: "Review a finished zurdo run against the PRD's intent — correlate the saved run diff under .zurdo/<slug>/ with what each task meant to achieve, folding in design documents when on hand, then either confirm the implementation landed as intended or scaffold a §2.2 follow-up PRD covering the gaps, distilling lessons/ entries from corrections worth keeping."
allowed-tools: [Read, Grep, Glob, Bash, Write]
disable-model-invocation: true
---

## When to invoke

Invoke this skill after a `zurdo run` has finished walking its tasks and the user wants to know whether the implementation **landed as intended** — not merely whether the criteria passed. Typical entry points:

- A run completed green and the user asks "did it actually do what the PRD meant?"
- A run finished mixed (some `failed` / `blocked-by-dependency`) and the user wants a gap list turned into actionable follow-up work.
- Before merging a branch produced by a zurdo run, as an intent-level second look on top of the mechanical criteria.

This is a different job from the neighboring surfaces — do not duplicate them:

- `zurdo review <prd>` (the CLI TUI) walks recorded evidence and signs off `[manual]` criteria. This skill never signs anything off.
- [[zurdo-state-summary]] tallies run state and recommends resume/reset. If the run is still mid-flight (non-terminal tasks with a live lock, or an in-flight iteration), hand over to it — intent review needs a settled diff.
- [[zurdo-hint-debugger]] diagnoses one failing criterion. This skill works at task-and-PRD altitude; when a single hint needs forensics, point at the debugger rather than re-deriving it.

The core premise: **criteria are necessary, not sufficient.** Every hint can pass while the diff misses the point — a minimal-compliance change that satisfies a `[grep:]` without implementing the behavior, a feature landed in the wrong layer, an invariant from a design doc silently violated. Judging that gap is exactly what a hint cannot do, and exactly what this skill exists for.

## Inputs and where they live

State lives under `<repo-root>/.zurdo/<slug>/` (`slug` = `<basename>-<hash4>`; resolve it with `zurdo state where <prd>`). This skill reads, in order of authority:

1. **The PRD itself** — task descriptions, requirements blocks, dependency edges, and the prose intro. The intro and `### Description` bodies carry the intent; the criteria carry only the mechanical floor.
2. **`.zurdo/<slug>/run-diff.patch`** — the full unified diff of everything the agents changed, captured against the run-start baseline at the end of every run that captured one. This is the primary evidence. If it is absent (baseline capture is warn-only and can be skipped), reconstruct it from the `baseline` record: `run_tree` in `.zurdo/<slug>/baseline` is a git tree hash, so `git diff <run_tree>` yields the same view against the current working tree. If neither exists, say so and fall back to `git diff <merge-base>...HEAD` only with the user's confirmation that the branch contains just this run's work — a polluted diff produces a polluted review, and it is better to review less than to attribute someone else's commits to the run.
3. **`.zurdo/<slug>/prd.json`** — per-task statuses, attempts, and `criteria_results`. Task status separates "the agent never landed it" (`failed`, `blocked-by-dependency`) from "the agent claims it landed" (`passed`, `passed-pending-review`); only the latter needs intent-level scrutiny. Read [references/evidence.md](references/evidence.md) for what each artifact in the run directory — this one, the `iterations/` transcripts, `criteria_results` — actually proves and what it does not.
4. **Design documents, when on hand** — in priority order:
   - The `<prd>.trail.md` sidecar beside the PRD (written by [[zurdo-prd-author]]): recorded rationale for why each task and hint exists. The single best intent source when present. [references/evidence.md](references/evidence.md) also carries the milestone-6 boundary for when a missing trail is a finding versus expected.
   - Documents the PRD links or names in its prose (relative markdown links, "see docs/…" mentions). Follow and read them.
   - Repo-level design/spec directories (`docs/design/`, `docs/specs/`, ADR directories) — only entries plausibly governing the touched area; do not bulk-read a docs tree.
   - `lessons/` at the repo root, if present — a lesson naming a quirk in the touched area is review context.

   Absent all of these, review against the PRD text alone and say so in the output — "no design documents found" is honest scope, not a failure.

## Per-task classification

For each task, read its description (and requirements block when present), locate the diff hunks that plausibly belong to it, and classify:

| Verdict | Meaning |
|---|---|
| **landed** | The hunks realize the task's intent; criteria results corroborate. |
| **landed-with-drift** | The behavior exists but diverges from stated intent or a design document — wrong layer, missing invariant, narrower scope than described, API shape contradicting the docs. |
| **vacuous-pass** | Criteria are green but the hunks don't implement the intent — the hint was satisfiable without the behavior. |
| **missed** | No meaningful hunks; status is typically `failed` or `blocked-by-dependency`. |

The table gives the four meanings; deciding *between* two that both fit the evidence is the harder half. Read [references/classification.md](references/classification.md) before recording any verdict other than **landed** — it carries the decision order, the **landed-with-drift** versus **vacuous-pass** boundary, the vacuous-pass mechanism restated in full, `attempts: 0` as the discriminator for a task no agent was ever dispatched for, and the worked case behind all of it.

Attribution guidance: `run-diff.patch` is run-scoped, not task-scoped, so binding hunks to tasks is a judgment you make and must report as one — read [references/attribution.md](references/attribution.md) for the three binding signals ranked by evidential strength, the residual cases that defeat all three, and the wording to hedge with when they do.

Also collect **unattributed hunks** — diff content no task accounts for. Out-of-scope changes are a finding in their own right (flag them for human review; deciding whether to keep or revert them is the user's call, and reverting is never this skill's job).

## Verdict and output

Every review ends in exactly one of two outcomes:

**A. Landed as intended.** Every task classifies as **landed** and there are no unattributed hunks that alarm you. Output a short report — one line per task with the evidence that convinced you (hunk locations, the corroborating criteria), the design documents consulted, and any nits that don't warrant follow-up work. Then stop. Do not scaffold a PRD nobody needs.

**B. Gaps exist.** Any task classifies as **landed-with-drift**, **vacuous-pass**, or **missed** — or unattributed hunks need remediation. Output the same per-task report, then **scaffold a follow-up PRD**:

- Write a new file beside the original: `<stem>-followup.md` (or the repo's next `milestone-N/` directory when the repo organizes PRDs that way). **Never edit the original PRD** — it is the record of what was asked; the follow-up is the record of what remains.
- Follow the §2.2 grammar exactly (see [[zurdo-prd-author]]'s grammar reference): `# PRD:` title, `## Task: <id> — <title>` with the em-dash U+2014, contiguous metadata block, required `**Effort**` and `**Depends-on**`, `### Description`, `### Acceptance Criteria` with a hint on every criterion.
- One task per confirmed gap, with criteria shaped to the verdict and validated with `zurdo validate --strict` before handing the file back. See [references/followup-prd.md](references/followup-prd.md) for the verdict→remedy table, the placement rule, the `**Depends-on**`/cross-PRD boundary, and the `--strict` gate in full.

## Distill learnings

After a verdict-B scaffold exists, walk the confirmed gaps once more and ask which of them record a **correction that would otherwise be rediscovered** — the same selection bar the `zurdo-lessons` skill sets (call the Skill tool with `zurdo-lessons`; if your runtime exposes no Skill tool, read `zurdo-lessons/SKILL.md` from your skills discovery path; if neither resolves, stop and tell the user to run `zurdo skills install --all`). Each one that qualifies becomes a file in the repository's `lessons/` library. Verdict A produces no corrections and therefore no lessons; **zero is a normal outcome**, and a lesson is never invented to fill the file.

Review-time corrections that qualify:

- **A vacuous pass** — the canonical case. The original hint shape went green while proving nothing; the lesson names the shape and why it lies, so the next author in any part of the repo doesn't write it again.
- **Drift against a repo-wide convention.** The diff violated an invariant a design document states for the whole codebase (headers originate in middleware, all state writes are atomic-rename). The convention transfers; the task doesn't. Cite the convention in the body.
- **A trap the review itself hit** — criteria whose evidence paths made the work unverifiable, a frozen glob that made the task unwinnable, a baseline captured at the wrong moment.

What stays out: the gap itself (the follow-up PRD already records it), task-specific scope and effort calls, and attribution notes. The test, applied one candidate at a time: *would an author working on a different PRD, in a different part of this repository, get this wrong without having read it?*

Before wording the lesson body, call the Skill tool with `zurdo-domain` and use the project's governed nouns — the same vocabulary discipline as the criteria themselves. A lesson is retrieved by a mechanical match surface and then read by a human and an agent; wrong nouns in the body do not stop it matching, they make what it says mean something else on arrival.

For the file format, the filename, and the match-surface floor, call the Skill tool with `zurdo-lessons` (if your runtime exposes no Skill tool, read `zurdo-lessons/SKILL.md` from your skills discovery path; if neither resolves, stop and tell the user to run `zurdo skills install --all`). This skill writes the `IntentReview` source shape.

A worked lesson, distilled from the vacuous-pass gap in the example below — `lessons/lesson-9c5d1977.md`:

````markdown
---
schema: 1
match:
  hint_types:
    - grep
  path_prefixes:
    - README.md
source:
  kind: IntentReview
  prd_slug: rate-limit-9c41
  task_id: task-docs
  followup_path: docs/prds/rate-limit-followup.md
created_at: 2026-08-10T00:00:00Z
---

A `[grep:]` into prose for a phrase the criterion itself names goes green on a
one-line mention — it proves the words exist, not that the section does. When a
criterion wants documentation structure, grep for the heading the description
demands (e.g. `## Configuring rate limits`), not for the topic's name.
````

Lesson files are committed alongside the follow-up PRD; that PR diff is the human review gate the library relies on. Name every lesson file you wrote in the handoff.

## Procedure

1. **Locate and gate.** `zurdo state where <prd>` → confirm `.zurdo/<slug>/prd.json` exists and the run is settled (no live `lock`, no in-flight iteration). Not settled → hand over to [[zurdo-state-summary]].
2. **Load intent.** Read the PRD end to end; read the `.trail.md` sidecar if present; follow PRD-linked docs; pull in governing design docs when on hand.
3. **Load evidence.** Read `run-diff.patch` (or reconstruct per the fallback ladder above) and `prd.json` statuses.
4. **Classify each task** per the table, binding hunks to tasks and noting approximate attributions; collect unattributed hunks.
5. **Deliver verdict A or B.** For B, scaffold the follow-up PRD and validate it.
6. **Distill lessons (B only).** Apply the selection rule to the confirmed gaps; write each qualifying correction as a `lessons/lesson-<hash8>.md` file with an `IntentReview` source pointing at the scaffold. Zero lessons is a normal outcome.
7. **Hand off.** Name the scaffold and every lesson file written, and tell the user the next step: review them together in one commit, then `zurdo run <followup-prd>`.

## What this skill does NOT do

- It does not modify the original PRD, `prd.json`, `progress.log`, or anything else under `.zurdo/` — all of it is audit trail.
- It does not fix code or revert out-of-scope changes; it produces a review and, when warranted, a PRD.
- It does not sign off `[manual]` criteria — that is `zurdo review`'s in-band, tamper-evident log.
- It does not soften a finding to avoid scaffolding. If the diff missed the intent, saying so — with the follow-up PRD to fix it — is the whole job.
- It does not pad the lesson library. A lesson that fails the would-it-be-rediscovered test consumes an injection slot on every future run that matches its surface; when in doubt, leave it in the review report.

## Worked example (abridged)

PRD `docs/prds/rate-limit.md`, three tasks, run finished all-green.

```
Intent review — rate-limit.md (slug rate-limit-9c41)
Design docs consulted: rate-limit.trail.md, docs/design/api-conventions.md

  task-limiter      landed             src/limit/mod.rs +214; token-bucket per
                                       trail rationale; cargo test criterion
                                       exercises the 429 path.
  task-headers      landed-with-drift  Retry-After emitted, but from the handler
                                       (src/api/handler.rs) not the middleware —
                                       api-conventions.md §4 requires response
                                       headers to originate in middleware.
  task-docs         vacuous-pass       [grep: rate limiting in README.md] passed
                                       on a one-line mention; the description
                                       asked for a configuration section.

Unattributed hunks: none.

Verdict: gaps exist → scaffolded docs/prds/rate-limit-followup.md
  task-move-headers — relocate Retry-After emission into the middleware layer
    (depends-on: []), criterion [shell: cargo test --test middleware_headers]
  task-docs-section — write the README configuration section
    (depends-on: []), criterion [grep: '## Configuring rate limits' in README.md]
zurdo validate: clean.

Lessons: wrote lessons/lesson-9c5d1977.md (grep-into-prose proves words, not
structure — from the task-docs vacuous pass). The task-headers drift stays in
the follow-up PRD only: middleware placement is this feature's call, not a
repo-wide correction.

Next: review the scaffold and the lesson in one commit, then
`zurdo run docs/prds/rate-limit-followup.md`.
```

## References

- [references/classification.md](references/classification.md) — deciding between the four verdicts, the **landed-with-drift** versus **vacuous-pass** boundary, the vacuous-pass mechanism, and the `prd-m9-03` case it's drawn from
- [references/attribution.md](references/attribution.md) — binding diff hunks to tasks, the three-rung evidence ladder, and why an unattributed hunk is not a fifth verdict
- [references/followup-prd.md](references/followup-prd.md) — scaffolding the verdict-B follow-up PRD: the verdict→remedy table, placement and `**Depends-on**` rules, and the `--strict` validation gate
- [references/evidence.md](references/evidence.md) — what each run artifact proves and does not (`attempts: 0`, `iterations/*.out`, `criteria_results`), the milestone-6 trail boundary, and the rare-path fallback for a missing `run-diff.patch`
