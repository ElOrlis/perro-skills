# Measurement: the instrument, and why the obvious number is wrong

Phase 2's gate is *every claim marked new carries a number*. This file is the
instrument that produces the number, the reason the easy number is not one, and
what to do with a claim that has no instrument at all.

## The instrument

```sh
zurdo validate <prd.md> --authoring-state --format json
```

`--authoring-state` validates the PRD's **authoring baseline** instead of the
working tree: it reads the PRD's text as of the commit that added it, and checks
that text against the tree at **that commit's first parent**. Both sides of the
comparison come from the same point in history, which is the whole invariant —
`PRD-as-of-C` against `tree-at-C^`.

`--at <rev>` is the escape hatch. It overrides the resolved add commit with an
explicit revision, still validated against that revision's first parent. The two
flags are **mutually exclusive** — clap rejects them together
(`cli.rs`, `#[arg(long = "authoring-state", conflicts_with = "at")]`) — because
they answer the same question two different ways and a run that took both would
not know which state it measured.

`--format json` carries the resolved `revision` object (its `commit` and its
`baseline`) alongside the errors and warnings, and the human format emits the
same pair on stderr. That is what lets a measurement **name the state it was
taken at**. A number quoted in a design record without its revision is not
reproducible, and the flag exists so that the revision is never something the
author has to remember.

**Aggregating across PRDs is a shell loop over that JSON.** There is no corpus
subcommand and there is not going to be one:
`prd-m12-04-authoring-state-reconstruction.md` considered adding one and rejected
it — `validate` is already per-PRD and already emits `--format json`, so a
`corpus` subcommand would duplicate its entire rendering path to add nothing.
The instability the work was chartered to fix was never in the summing.

```sh
for prd in docs/prds/milestone-*/prd-*.md; do
  zurdo validate "$prd" --authoring-state --format json
done | jq -s '...'
```

Build the binary from the tree being measured. A release on `PATH` predates the
lints you are measuring with, and a lint that has not shipped there measures as
zero findings rather than as an error.

## Why a `HEAD` number is not a measurement

**Measured 2026-08-08 against `zurdo 1.14.0`** (installed binary equal to the
repo version, so no lint was silently skipped):

| At | Result |
| --- | --- |
| `HEAD`, whole corpus | **924 warnings across 55 of 80 PRDs** — **922** of them `grep-tautology` |
| Authoring state, ten highest-warning PRDs | **334 warnings drop to 11** |

That is an **artifact rate of 96.7%**.

The mechanism is not subtle, which is exactly why it is easy to miss. `zurdo
validate` evaluates `[grep:]`, `[no-grep:]`, `[file-exists:]`, and
`[file-absent:]` against a tree. Run against a PRD whose work has already
shipped, every hint that was honestly red at authoring time is now green, and
`grep-tautology` fires on all of them at once. The lint is correct; the tree is
wrong. A corpus count taken at `HEAD` is therefore dominated by the work having
succeeded, and it moves when unrelated PRDs ship. It measures nothing an author
would act on.

## Carry the residual caveat with the headline

The 96.7% is the easy half. The hard half is that **the residual is unstable**.
Baseline choice is not obvious — 40 of the 80 PRDs were modified after they were
added — and re-running those same ten PRDs against the **last modifying commit's
parent** instead of the add commit's parent moves the survivors from **11 to 16,
a 45% swing**. One PRD alone reads 0 or 5 depending on which parent is chosen.

The residual is the only part anyone acts on. A robust 96% headline paired with a
signal that swings 45% on an undocumented methodological choice is not a
measurement; it is an anecdote with a number attached. Reproducing an unstable
number reproduces nothing.

That is the argument that put the baseline rule **in the binary rather than in
the session**. The default resolves the add commit by one documented rule that is
testable, instead of a shell loop reconstructed from memory each time — and
add-parent is the conservative choice, being the earliest tree and the one that
reads lowest (11 versus 16). `--at` remains for everything else, deliberately
narrow: if the command only took an arbitrary revision, the 45% swing would leak
straight back out to the caller and the methodology would be unpinned again.

When you quote the artifact rate in a record, quote the swing with it. The pair
is the finding; the headline alone is the half that flatters the method.

## When a claim cannot be measured

Some claims have no instrument. A property of run state under gitignored
`.zurdo/`, a behavior that only exists once the thing is built, a ratio with one
data point and no second — none of these have a command that returns a number
today.

**Demote the claim to an open question, in the record's own `## Open questions`
section, and name what would measure it.** The naming is the requirement, not a
courtesy: "no instrument" is a status a later reader can clear, and only if they
know what instrument was missing.

Do not refuse the document over an unmeasurable claim — refusing costs the whole
record to quarantine one paragraph. And do not let the claim stand in the body
unmarked, because an unmarked claim reads as one that was checked, which is the
failure this gate exists to prevent. A claim in the body has a number; a claim in
Open questions has a named missing instrument; nothing is allowed to be neither.
