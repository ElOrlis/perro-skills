# When to stop grilling

Grilling is a means, not an end. The interview stops when the PRD is provably
ready to run — not when the user tires, and not before every criterion verifies.
This reference defines the gates between phases and the stop condition.

## The hard gate: forcing inside Evidence inventory

Do **not** advance from **Evidence inventory** (phase 2) to **Group evidence
into tasks** (phase 3) until *every* criterion draft has survived all six
forcing questions in [forcing-questions.md](forcing-questions.md). Forcing is
applied at birth, in phase 2, alongside the hint and the `[proves:]` tag —
there is no separate later phase where criteria are forced, and nothing
resembling a criterion is authored after grammar:

1. tautology test — does not already pass on the current tree
2. no-op test — fails on an empty diff
3. honesty test — the hint exercises the behavior the text names
4. specificity test — the narrowest hint that proves it
5. honest-`[manual]` test — `[manual]` only where automation cannot reach
6. the pre-authored test — if the hint runs a test, that test's fate is
   **declared**: pre-author it, or decline with a reason

A single criterion that fails one of these is enough to keep the gate closed.
Relaxing a hint to make the gate pass is the one move that is never allowed —
it converts a real gap into a green check that lies. Because forcing happens
in Evidence inventory, no broken criterion ever reaches the clustering step
that follows.

### Why question 6 splits across two gates

A literal "the test exists" gate at phase 2 is impossible to satisfy: the
convention's own marker is keyed to a task id
(`#[ignore = "pre-authored: task-03"]`, a file named `preauthored_task_03.rs`),
and task ids are **produced by phase 3** — Evidence inventory has no tasks yet
to name a file for. Demanding the artifact here would demand a file that
cannot yet be named.

So the obligation splits along the seam where the information actually
appears:

- **The phase 2 → 3 gate asks only for the declaration.** For every
  test-running criterion, the author states, right then: pre-author the test,
  or decline with a reason. Declining is allowed; declining *silently* is
  not — the same move question 5 already forbids for `[manual]`. Nothing
  about the artifact — its path, its failure mode — is checked here, because
  nothing about it can be yet.
- **The artifact is checked at the Ready stop condition, below**, once tasks
  and their ids exist and pre-authoring has actually happened. That is where
  "the file exists, its hint was run, and it failed on an assertion" is
  verified — not at this gate.

## Phase gates

Each gate below must be satisfied before the next phase begins, in the same
five-phase order `SKILL.md` defines: Intent, Evidence inventory, Group
evidence into tasks, Author grammar, Review. Gates are listed as typed bullet
items so tooling can scan for them:

- phase-transition (Intent → Evidence inventory): the headline goal is stated
  in one sentence and the user has confirmed scope.
- phase-transition (Evidence inventory → Group evidence into tasks): every
  captured fact has a concrete hint type assigned, has survived all six
  forcing questions from [forcing-questions.md](forcing-questions.md), and is
  linked to a `req-*` requirement via `[proves:]`. For question 6, only the
  **declaration** (pre-author, or decline with a reason) is required here —
  the artifact itself is checked later, at the Ready stop condition, once task
  ids exist to name it. No unverified fact may enter the clustering step. This
  is the hard gate above.
- phase-transition (Group evidence into tasks → Author grammar): every task
  has a name, an `Effort`, a `Depends-on` (possibly `[]`), and a one-line "why
  this is one task". No task implies more than ~5 criteria. Every
  `Depends-on` names a real data dependency between evidence clusters — not an
  authoring preference.
- phase-transition (Author grammar → Review): the draft passes
  `zurdo analyze --static-only` with zero `[error]` findings.
- phase-transition (Review → Done): the four layers (see review-layers.md)
  produce a `✓ READY TO RUN` or a `⚠` the user has explicitly accepted.

### Grouping gate (holds the Group evidence into tasks → Author grammar transition)

Before a cluster becomes a task:

- No task implies more than ~5 criteria. A cluster larger than that is a
  signal to re-cluster around a tighter verification surface.
- Every `Depends-on` edge represents a real data dependency between evidence
  clusters: task B needs a file, endpoint, or schema that task A produces.
  Sequencing by difficulty or familiarity is not a dependency.
- No `**Frozen**` glob bound to a task matches an evidence path of that same
  task's hints — the overlap makes the task unwinnable (see
  [frozen-paths.md](frozen-paths.md)). The `zurdo analyze` run in the
  grammar phase is the deterministic backstop for this check, but its
  frozen-glob-overlap warning is advisory only — catch the overlap here.

## Stop conditions (any one ends the interview)

- **Ready.** The PRD passes `zurdo analyze --static-only` clean, the criteria
  hard gate is satisfied, and the review verdict is `✓ READY TO RUN`. For every
  criterion declared pre-authored under question 6, the artifact half is also
  satisfied: the declared test file exists, its hint has been run, it
  **failed on an assertion** (not a compile error, not a zero-test demotion),
  and the trail sidecar's `## Pre-authored tests` section (below) records it.
  No `✓ READY TO RUN` is issued while any declared file is missing, unrun, or
  green. Hand back the PRD path and the locked-decisions summary from the
  session.
- **Blocked on a real unknown.** A decision genuinely cannot be made without
  information the user does not have yet (an unmade product call, an external
  API contract that does not exist). Stop, record the open item as a `[manual]`
  task or a documented gap, and say so plainly — do not paper over it with a
  vague criterion.
- **Diminishing returns.** Three consecutive questions yield no change to the
  PRD. The remaining branches are preferences, not correctness; surface them as
  a short "you may also want to decide…" list and stop.

## The trail's `## Pre-authored tests` section

Trails are prose everywhere else, but this one section is fixed format,
because a loose mandated line drowns in the rest. The unit is the **task**,
not the criterion — the one-file-per-task and one-guard-per-task rules from
[pre-authored-tests.md](pre-authored-tests.md) already made the task the
natural grain:

```markdown
## Pre-authored tests

- **task-03** — `shared/zurdo/tests/preauthored_task_03.rs`, 3 tests. Negative
  cases: empty input, malformed header, duplicate key. Pre-run:
  `cargo test --manifest-path shared/Cargo.toml -- --include-ignored preauthored_task_03`
  → **failed on assertion** (3 failed, 0 passed).
- **task-05** — **declined.** Sole criterion is `[manual]`; nothing to pre-author.
```

`failed on assertion` is fixed wording, not prose paraphrase: three failures
look identical to a red criterion from the outside, and this phrase is the
only thing in the trail that certifies the pre-run check actually hit an
assertion — not a compile error (the stub is missing) and not a zero-test
demotion (the filter matches nothing). A fixed heading and fixed wording are
what make the claim findable by a reviewer at the commit gate, and by any
future lint that greps trails for it.

## What "done" looks like

When you stop on the **Ready** condition, end with:

1. The PRD file path.
2. A one-paragraph "decisions locked" summary (from
   `session_tracker.py --action lock`).
3. The reasoning-trail sidecar: `<prd-name>.trail.md` written beside the PRD —
   one rationale line per gate-locked decision (hint choices, dependency
   edges, frozen globs, effort calls), distilled from the session record, plus
   the fixed `## Pre-authored tests` section above for every task that
   declared a pre-authored test or declined one.
4. Any lesson files: name each `lessons/lesson-<hash8>.md` written in the
   same Review-phase step as the trail sidecar (call the Skill tool with
   `zurdo-lessons`; if your runtime exposes no Skill tool, read
   `zurdo-lessons/SKILL.md` from your skills discovery path; if neither
   resolves, stop and tell the user to run `zurdo skills install --all`) —
   zero is a normal outcome, but if the session
   wrote any, the handoff names them so the user knows what they are
   committing.
5. The commit reminder: commit the PRD, the trail sidecar, any
   `lessons/lesson-<hash8>.md` files, and every pre-authored test file
   declared under question 6 — including its `todo!()` signature stub where
   one was needed — **before** `zurdo run`. The stub has to land in this same
   commit or CI is red on it.
6. The exact next command: `zurdo run <prd>` (or
   `zurdo analyze <prd>` first for the LLM-assisted quality pass).

Do not keep grilling past a ready PRD. A loop that will not terminate is as
much a defect as a criterion that will not verify.
