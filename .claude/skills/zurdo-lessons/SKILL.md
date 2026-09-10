---
name: zurdo-lessons
description: "Authoring a Zurdo lesson file — the selection bar a correction must clear, the frontmatter schema and its four `source` variants, the two-component match floor below which a lesson is silently inert, and the content-hash filename."
allowed-tools: [Read, Write, Edit]
---

# Lesson files

`lessons/` at the repository root is Zurdo's cross-PRD memory: one markdown file per
distilled correction, injected into a future run's prompt when its declared match surface
overlaps the task at hand. The files are **source, not state** — git-tracked, reviewed in the
PR that carries them, retired with `git rm`. Nothing in a run edits them.

`zurdo-prd-author` writes them at its **phase 5**, in the same step as the reasoning trail
and out of the same gate-locked decisions. That is the only moment where the correction and
the reason for it are both still in context: a later reader of a `.trail.md` can see *what*
was decided, but has to guess which decisions were corrections and which were scope.

The normative format is spec §4.4, backed by `shared/zurdo/src/reason/library.rs`. This
skill is the authoring view of it — where the two disagree, the spec is right and this
file is wrong.

## The selection rule

**A locked decision becomes a lesson when it records a correction that would otherwise be
rediscovered.** Nothing else does.

Three shapes qualify:

- **A hint that was rejected, and why.** The interview proposed a hint, the forcing questions
  killed it, and a replacement went in. The rejection is the lesson; the replacement alone is
  not, because it does not say what was wrong with the obvious choice.
- **A trap that made a task unwinnable.** A frozen glob overlapping a path the task must
  write, a baseline that is captured before the run rather than before the task, a hint whose
  target cannot exist when the criterion is checked.
- **A shape that passed while proving nothing.** A tautology that was already green on the
  untouched tree, or a `[grep:]` into a doc for a phrase the criterion itself names.

**Scope calls, effort calls, and dependency-edge rationale stay in the trail.** They explain
*this* PRD rather than the next one: why *these* tasks, why `high` and not `medium`, why
task-3 waits on task-1. None of it is a correction, and none of it transfers to a task in
another part of the repository.

Selection is mandatory, not a refinement. The trails already in this repository carry roughly
300 bolded decision bullets against a `max_lessons` default of **200** — promoting decisions
wholesale overflows the library and makes the runtime evict content nobody ranked. A handful
per PRD is the sizing that works; **zero is a normal outcome** for a PRD that hit no traps.

The test to apply to each candidate, one at a time:

> Would an author drafting a *different* PRD, against a different part of this repository, get
> this wrong without having read it?

If the answer needs this PRD's subject matter to be yes, it is trail material, not a lesson.
When in doubt, leave it in the trail — a trail line costs a reader nothing, while a weak
lesson consumes an injection slot on every future run that matches its surface.

Never invent a lesson to fill the file. A lesson that was not locked in the interview has no
`trail_path` to point at, and the `.trail.md` citation is what makes the claim auditable.

## The file format

YAML frontmatter delimited by `---` lines, then a markdown body:

- `schema` — always `1`.
- `created_at` — RFC 3339 timestamp, the date the lesson is written.
- `match` — the four-component surface every future query scores against (see below).
- `source` — a tagged shape; the variant a trail-authored lesson carries is `AuthoringTrail`.
- The **body**, everything after the closing `---`, is the guidance itself: a rule a future
  run can apply, stated in prose. An empty body is a parse failure, not an empty lesson.

`source` carries `kind: AuthoringTrail` plus three fields:

- `prd_slug` — the slug of the PRD being authored (the PRD filename without `.md`, which is
  the same slug `zurdo run` uses for `.zurdo/<slug>/`).
- `task_id` — the task the decision concerns, e.g. `task-3`.
- `trail_path` — repo-relative path of the `.trail.md` sidecar written in this same step.
  This is what makes the lesson auditable back to the reviewed document the claim came from,
  so it must name a file that exists in the same commit.

The other variants — `StallRecovery` and `HealAcceptance` (written by the runtime) and
`IntentReview` (written by the `zurdo-prd-review` skill after a run) — are never written
while authoring a trail lesson. Do not hand-author them; their extra fields
(`recovered_attempt`, `post_hash`, `followup_path`) anchor to artifacts that do not exist at
authoring time, and fabricating one is a lie the library persists.

**Unknown frontmatter keys are rejected.** There is no room for a `notes:` or `tags:` field
of your own — an unrecognized key fails the parse. A file that fails to parse is skipped with
a warning and is simply absent from matching, so a typo'd key silently deletes a reviewed
lesson from the library rather than announcing itself. Re-read the key names before writing.

## The match surface

`match` is how a future run finds the lesson. `select_lessons` only surfaces a lesson once
its query score clears `MIN_MATCH_SCORE`, which is **2** — one point per `match` component
whose values overlap the query's, out of up to four components total
(`shared/zurdo/src/reason/library.rs`). That is a **floor**, not a detail: a lesson declaring
only one component has a maximum possible score of 1 against any query, so it can never be
found. Nothing detects this. The library accepts the file, `zurdo reason status` counts it,
and it sits there permanently inert.

A component left out of `match` is **absent** from the lesson's declared surface, not a
zero-value feature — the matcher skips it rather than scoring it against the query. But that
absence is not free once it drops the declared surface below two components: at that point
every future query scores the lesson at most 1, below the floor, and it never matches
anything.

- `hint_types` — the criterion hint types the correction concerns: `shell`, `grep`,
  `no-grep`, `file-exists`, `file-absent`, `http`, `symbol`, `references`, `callers`.
- `failure_reasons` — failure buckets an actual run observed. **Leave this out of a
  trail-authored lesson**: nothing has failed yet at authoring time, and a prospective query
  carries no failure reasons either, so inventing a bucket adds no reach and asserts a run
  that never happened. Dropping it means a trail-authored lesson has only **three** usable
  components left — `hint_types`, `command_head`, `path_prefixes` — so it must declare **at
  least two of those three** to ever clear the floor. Declaring only one is not a narrower
  lesson; it is one that can never surface.
- `command_head` — the first token of the relevant `shell:` command, e.g. `cargo`, `npm`,
  `pytest`. Omit it when the correction is not about a shell hint.
- `path_prefixes` — repo-relative path prefixes the correction touches, e.g.
  `shared/zurdo/tests/`. Keep these as narrow as the correction actually is; a prefix of
  `shared/` matches nearly every future task and turns a specific lesson into noise.

Both directions of this rule matter. Over-declaring wins matches on unrelated tasks, and each
one displaces a lesson that would have applied — keep each component as narrow as the
correction actually is. Under-declaring is the failure that hides: a lesson below the
two-component floor produces no error, no warning, and no eviction — it is simply never
selected, by any query, for as long as the file exists. When in doubt, declare the second real
component rather than stopping at one.

## The `requires` block

A lesson is advisory by default: rendered beside a match, injected into a future prompt, and
never checked. `requires` is the escape hatch — an optional block that turns a correction into
a **standing requirement on every future PRD** the lesson's `match` surface selects, rather
than a suggestion an agent may or may not act on.

**Write one when the correction is a requirement, not advice.** Most lessons are advice — the
guidance body already carries all the force they need. `requires` is for the rarer case: a
correction that must hold on every future PRD, or the gap that produced the lesson reopens.
Zero `requires` blocks in a library is the normal outcome, not a gap to close.

The question to ask is the `scope` choice itself: **does the whole PRD owe this once, or does
every matching task owe it?** A whole-suite check — "run the full test suite before calling a
run complete" — is owed once, anywhere in the PRD; write `scope: prd` (the default). A
criterion-shaped correction — "every task touching this command must pass `-count=1`" — is
owed by each task the lesson matches; write `scope: task`.

The regex, `criterion_matching`, is tested against a criterion's prose text **and** the
source-grammar payload of each of its hints — not prose alone. That is what makes a
whole-suite obligation expressible, since the criterion that satisfies it is usually a bare
`[shell:]` hint with no prose worth matching:

```yaml
match:
  hint_types: [shell]
  command_head: go
requires:
  scope: prd
  criterion_matching: 'go test (-count=1 )?\./\.\.\.'
```

**A lesson carrying `requires` is never injected into an executor prompt.** It is excluded
from selection entirely, on every surface that previews an injection. A correction that must
both reach the agent *and* bind the author is two files, not one — split the execution
guidance into a plain lesson and the standing requirement into a second, `requires`-only
lesson.

**An obligation is only as good as its regex.** A `criterion_matching` that no reasonable
criterion could satisfy makes every future PRD the lesson matches carry a warning nobody can
clear. Retire a bad obligation the same way you retire a bad lesson: `git rm
lessons/<file>.md`, or a reviewed edit to the regex.

## A worked lesson file

`lessons/lesson-e84ed2c2.md`:

````markdown
---
schema: 1
match:
  hint_types:
    - shell
  command_head: cargo
  path_prefixes:
    - shared/zurdo/tests/
source:
  kind: AuthoringTrail
  prd_slug: prd-m12-03-trail-lessons
  task_id: task-5
  trail_path: docs/prds/milestone-12/prd-m12-03-trail-lessons.trail.md
created_at: 2026-08-07T00:00:00Z
---

`cargo test` takes a single filter. A `[shell: cargo test alpha beta]` hint fails
as an argument-parse error, not a test failure, so the criterion never goes green
and the iteration log blames the code instead of the hint. Write one criterion per
test name, or pass the extra filters after `--`.
````

Note what the example does *not* carry: no `failure_reasons`, because nothing failed; no
`uses` or `last_matched_at`, because reuse metadata is machine-owned and lives in
`.zurdo/reason/usage.json`, keyed by the lesson's content hash. Adding either field to the
frontmatter fails the parse.

## Filename

The runtime names a lesson `lessons/lesson-<hash8>.md`, where `<hash8>` is the first 8 hex
characters of a SHA-256 over the `match` surface and the body text — `source` and
`created_at` are excluded, so the name survives every later stamp. The bytes hashed, in
order:

1. each `hint_types` value, sorted, each followed by a NUL byte, then `|`
2. each `failure_reasons` value, sorted, each followed by a NUL byte, then `|`
3. each `path_prefixes` value, sorted, each followed by a NUL byte, then `|`
4. `command_head` if present, then `|`
5. the body text, trimmed

The reader loads every `*.md` file in `lessons/` regardless of its name, so a stem that does
not match is cosmetic drift rather than a parse failure — but derive it properly, because
that hash is also the deduplication key: a runtime write whose `match` and body hash
identically to a hand-authored file is dropped as a duplicate instead of shadowing it.

## Handing off

Lesson files are committed in the same commit as the PRD and its trail. That commit *is* the
human review gate the library relies on — no lesson enters the library without a reviewer
having seen it in a diff. Say so in the handoff, and name the files you wrote.
