# Classifying a task: choosing between the four verdicts

`SKILL.md`'s verdict table carries the one-line meaning of each verdict, and a
reviewer should be able to classify a straightforward task from it without
opening this file. What lives here is what a table cannot carry: how to decide
*between* two verdicts when the evidence in front of you fits both.

Every verdict answers one question — **did the task's intent land?** — from three
sources that are allowed to disagree with each other:

- the task's `### Description` and requirements block, which say what was meant;
- the diff hunks attributed to the task, which say what changed;
- `.zurdo/<slug>/prd.json`, which says what the runner observed — per-task
  `status`, `attempts`, and `criteria_results`.

The four verdicts are exactly the four ways those three can line up:

| Do the hunks realize the intent? | Are the criteria green? | Verdict |
|---|---|---|
| Yes | Yes | **landed** |
| Partly, or in a place the intent forbids | Yes | **landed-with-drift** |
| No — there is nothing that could have | Yes | **vacuous-pass** |
| No | No, or nothing ever ran | **missed** |

Read the row order as the decision order: ask whether anything was built before
asking whether it was built correctly. A judgment about quality applied to code
that does not exist is this skill's most common misclassification.

## The order to decide in

1. **Is there a diff to read?** No hunks plausibly belonging to the task, and a
   `status` of `failed` or `blocked-by-dependency` — that is **missed**, and the
   classification is done. Do not go looking for drift in an empty diff.
2. **Do the hunks contain a mechanism?** Not "is it good" — is there code,
   configuration, or content that would change the program's behavior if you ran
   it? A criterion green with no mechanism behind it is **vacuous-pass** (below).
3. **Does the mechanism do what the description said, where the description or a
   design document said to do it?** Yes → **landed**. No → **landed-with-drift**.
4. **Is the mechanism narrower than what was asked?** Scope short of the
   description is drift, not a miss — something was built, just not all of it.

## **landed** versus **landed-with-drift**

Drift is divergence from a *stated* constraint, not from your preference. Before
recording drift, name the sentence it violates — a line in the task description,
a requirement in the requirements block, a rule in a design document the PRD
links or the repository states for the whole codebase. If you cannot cite one,
what you found is a nit: report it in prose and classify the task **landed**.

The four shapes that recur:

- **Wrong layer.** The behavior exists but is emitted from a component the
  documented architecture reserves for something else.
- **Missing invariant.** The happy path works; a stated guarantee — atomicity,
  ordering, idempotence, an enumerated error case — is absent.
- **Narrower scope.** One of the description's three cases is implemented, and
  the criterion only tested that one.
- **Contradicted shape.** The API, schema, or output format works but disagrees
  with what a document already publishes.

Drift always leaves fingerprints: hunks you can point at, a mechanism you can
trace, a criterion that exercised something. That is what distinguishes it from
the next verdict.

## **landed-with-drift** versus **vacuous-pass** — the boundary

This is the skill's core judgment and the one worth slowing down for. Both
verdicts describe a green run that did not deliver the intent, so the criteria
results cannot separate them. One question does:

> If you deleted every hunk attributed to this task, would its criteria still
> be green?

**Yes → vacuous-pass.** The criteria never depended on the work. They were
satisfiable by the tree as it already stood, so their passing says nothing about
the task at all.

**No → landed-with-drift.** The criteria depended on something the task built.
Something was built; it was built wrong.

Run the question as a thought experiment against the diff you already have — this
skill never modifies a repository. When the answer is unclear, two secondary
tells usually settle it. A vacuous pass has **no mechanism**: no function, no
branch, no emitted output a reader could point to and call the feature. And it
frequently has **no cost**: zero attempts, no iteration transcript, a wall-clock
time of milliseconds.

Both misreadings hurt, unequally. Calling a vacuous pass "drift" is the
expensive one: it reports a defect in something that was never written, and
every downstream decision inherits the fiction that a mechanism exists. Calling
drift "vacuous" is the cheaper error, but it discards a working starting point
and understates what the task did achieve. When you are unsure, the tie-breaker
is the mechanism: if you can quote the lines that implement the behavior, it is
drift.

## The vacuous-pass mechanism

A vacuous pass is not a bug in the runner. Every check ran, every check reported
honestly, and the result is still worthless — because of a defect class with one
signature: **the criterion performed a ritual and verified nothing**. A ritual
is an observable event that correlates with the work having been done without
being caused by it. The criterion watches for the event, the event occurs for an
unrelated reason, and the criterion reports success in perfectly good faith.

The class has three known members:

| Member | The ritual performed | What was never verified |
|---|---|---|
| `doc-echo` | a phrase was written into a doc | that the prose is true |
| zero-test run | a test command exited `0` | that any test ran |
| passed-at-pre-flight | a task reached `passed` | that anything happened |

They differ in when they can be caught. `doc-echo` is visible at authoring time,
from the PRD text alone: a criterion whose sole hint greps a documentation file
for a phrase the criterion itself names can be satisfied by writing that phrase,
true or false. The other two are only visible from a run: a test command's exit
code cannot distinguish "every test passed" from "the filter matched no tests,"
and a task's terminal status cannot distinguish "the agent built it" from "it was
already there."

Zurdo since v1.13.0 catches the two run-time members itself — a `[shell:]` hint
whose output reports a runner that ran zero tests is demoted from passed to
failed with an `EmptyTestRun` reason, and the run-end summary names the tasks
that passed at pre-flight. Treat those as corroboration when the run you are
reviewing produced them, and as absent evidence otherwise: older runs, other
runners, and rituals outside those two shapes still reach you unflagged. The
reviewer, not the runner, is the backstop.

## `attempts: 0` is the discriminator

For the passed-at-pre-flight member there is a single field that settles it. A
task in `prd.json` carrying `status: passed` alongside `attempts: 0` means **no
agent was ever dispatched**. Zurdo evaluates every criterion once before the
first attempt; when they are all already green, the task short-circuits to
terminal without an iteration. The corroborating absence is on disk:
`.zurdo/<slug>/iterations/` holds no `<task-id>-*` transcript, because there was
no iteration to record.

What that proves: nothing in the working tree changed on account of this task
during this run. Whatever satisfies its criteria predates the run.

What it does not prove: that the intent is unmet. The same shape is the
*expected* one on a resume, on a re-run of a finished PRD, and on a task whose
work an earlier task in the same PRD legitimately completed. Zurdo draws exactly
this line — its own run-end warning is suppressed when the run is a resume,
because passing at pre-flight is the normal shape there.

So the field is a discriminator only once you know which kind of run you are
looking at, and `prd.json` does not record that: there is no `resumed` flag to
read after the fact. Establish it from `progress.log` and from whether the
`iterations/` directory holds transcripts for the task from an earlier pass.

- **Fresh run, `attempts: 0`** — the vacuous-pass signature. The criteria were
  green before the work began, which means they could not have been measuring
  it. Classify **vacuous-pass** unless a sibling task in the same PRD visibly
  did the work.
- **Resume, `attempts: 0`** — the expected shape, and no finding. The work is
  recorded in the earlier pass; go read that pass's evidence instead.

## The case this is drawn from: `prd-m9-03-ci-ready-surface`

A PRD in this repository named four new command-line flags. Its tasks 6 through
9 carried twenty acceptance criteria, all of one shape:

```
- [ ] validate accepts the strict flag [shell: cargo test --manifest-path shared/Cargo.toml validate_accepts_strict_flag]
```

The hint runs the project's test runner filtered to one named test function.
None of the twenty named test functions existed. The runner treats a filter that
matches nothing as a successful run of an empty set and exits `0` — so every one
of the twenty criteria was already green at run-start pre-flight, and all four
tasks short-circuited to `passed` with `attempts: 0`. No agent was dispatched;
no flag was implemented.

The failure then escaped the run. `CHANGELOG.md` recorded four flags the binary
did not have, and the claim shipped. The correction is the "Fixed" entry in the
`1.12.0` release — a false release claim that took a full release to retract,
and the reason this reference exists.

Three things generalize. The ritual was an exit code, not a phrase, so reading
the PRD's prose would never have caught it. Every individual criterion looked
rigorous — a real test runner, a real named test. And the aggregate shape was
screaming: four consecutive tasks, twenty criteria, zero attempts. When several
adjacent tasks show `attempts: 0` on a fresh run, treat the cluster as one
finding and look for the shared hint shape behind it.

## **vacuous-pass** versus **missed**

Both leave the intent unrealized. The difference is what the record now claims,
and it is the difference between a gap and a lie. A **missed** task is honest:
its status says it did not land, and anyone reading the run state knows. A
**vacuous-pass** task reports success, so the false claim propagates outward —
into changelogs, release notes, and dashboards — long after the run.

That asymmetry is diagnostic, not rhetorical. A missed task means work remains.
A vacuous pass means work remains *and* the criterion meant to detect it is
itself defective, *and* anything downstream that trusted the green result may
now be wrong. Say so: the second finding is the one nobody else is looking for.

## When the evidence will not settle it

Not every task classifies cleanly, and a confident wrong verdict costs more
than a hedged right one.

- Attribution is approximate when a hunk could belong to two tasks. Say so
  rather than presenting a guess as fact.
- A missing `run-diff.patch` narrows what you can claim. Classify what the
  remaining evidence supports and name the gap.
- A suspicion of vacuousness without the artifact — no `attempts: 0`, no
  identifiable ritual, just an unease about a thin diff — is a nit under
  **landed** or **landed-with-drift**, not a **vacuous-pass**. This verdict
  carries the accusation that a criterion is broken; it needs the evidence.

## Going deeper

This file is diagnostic only: it names verdicts, it does not prescribe remedies.
Repositories carrying `docs/design/vacuous-pass-detection.md` will find the full
field study behind the defect class there — measured incidence across a real run
corpus, and the design of the two run-time checks. Nothing here depends on it.
