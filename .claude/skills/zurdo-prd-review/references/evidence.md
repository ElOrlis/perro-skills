# Reading the run's artifacts: what each one proves

This reference used to exist to help you *load* evidence — a fallback ladder
for reconstructing `run-diff.patch` when the run-start capture was skipped.
Measured on 2026-08-22, that failure has never occurred in this repository:
every one of the 36 finished run directories under `.zurdo/` that carries a
`prd.json` also carries a `run-diff.patch`, none missing. A file whose subject
is a failure the corpus has never produced teaches nothing, so this file is
repointed to what actually varies from run to run: what each artifact you do
have is allowed to prove, and what it is not.

## `prd.json`: read `attempts` before you read `status`

A task record of `status: passed` alongside `attempts: 0` means **no agent was ever dispatched** for it.
Zurdo evaluates every criterion once before the first attempt; when they are
all already green, the task short-circuits to terminal without spending an
iteration. Nothing in the working tree changed on this task's account during
this run — whatever satisfies its criteria predates it.

On a fresh run this is the `prd-m9-03` signature —
[references/classification.md](references/classification.md) tells the full
story of the run it names, and `attempts: 0` clustered across several
adjacent tasks is the tell to look for. On a resume it is the expected shape:
the work is recorded in an earlier pass, not absent. `prd.json` does not
record which case you are in; establish it from `progress.log` before
treating a zero as a finding.

## `iterations/<task-id>-<attempt>.out`: the weakest artifact in the directory

This is the agent's narrative about its own work, and it is the artifact in
the run directory most likely to claim work that is not in the diff. It
explains *why* a hunk exists faster than anything else on disk, which makes
it genuinely useful — and it will describe edits to files it never opened
with the same fluent confidence it describes real ones. Never cite an `.out`
transcript as proof that something landed. Cite the diff it should
correspond to, and treat the transcript as a lead to corroborate, not a
source to repeat.

## `criteria_results`: the strongest binding signal the run produces

An entry in a task's `criteria_results` records the hint text a criterion
checked and, for hints with a readable target, the file it read. When that
file also appears in the names-only diff against the run's `baseline`, the
entry's `evidence_modified` is `Some(true)` — the runtime observed that file
at verification time, and observed it change. That is why
[references/attribution.md](references/attribution.md) puts this signal on
rung 1: it is not an inference from stated intent and not a self-report, it
is what the run itself watched happen.

## The trail boundary: a missing `<prd>.trail.md` means two different things

"No `<prd>.trail.md` found" is not one fact — it is two, and which one
applies flips at milestone-6. Measured on 2026-08-22: `docs/prds/milestone-1`
through `milestone-5` hold 55 PRDs and zero trail sidecars, because the
sidecar convention did not exist yet when they were authored. From
`milestone-6` onward every authored PRD carries one — the count is deliberately
not transcribed here, because it grows with every PRD and a stale number is
worse than none. The only milestone-6-onward PRDs without a trail are the
`*-followup.md` scaffolds this skill itself writes, which have no authoring
interview behind them by construction — there is nothing a trail could record.

So a missing trail on an authored PRD from milestone-6 onward is a finding:
either the sidecar was lost, or the PRD was hand-edited outside
[[zurdo-prd-author]]. A missing trail on a milestone-1 through milestone-5 PRD
is nothing at all — review against the PRD text alone and say so, per
`SKILL.md`'s fallback.

## Putting the three together

The three artifacts above rank the same way `references/attribution.md`
ranks its three binding signals, and for the same reason: strength tracks how
directly the runtime, rather than a participant in the run, produced the
record. `criteria_results` is the runtime's own observation. `prd.json`'s
`attempts` field is the runtime's own count. The `.out` transcript is the one
artifact the thing under review wrote about itself. When a task's evidence
disagrees across the three — the transcript claims a change the diff does not
show, or `attempts: 0` sits beside an `.out` file that describes work — trust
the artifact higher on this list, and say in the report which one you
trusted and why.

## The rare path: reconstructing a missing `run-diff.patch`

Kept only because the capture that produces it is warn-only and can
genuinely be skipped, not because this repository has ever hit it. If
`run-diff.patch` is absent, `baseline`'s `run_tree` is a git tree hash: `git
diff <run_tree>` against the current working tree reproduces the same view.
If `baseline` is also absent, fall back to `git diff <merge-base>...HEAD`
only with the user's explicit confirmation that the branch holds just this
run's work — a polluted diff produces a polluted review. It is better to
review less than to attribute someone else's commits to the run.

Say which rung of the ladder you landed on; a reconstructed diff is weaker
evidence than a captured one, and the report should not hide that.
