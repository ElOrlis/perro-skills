# Scaffolding a follow-up PRD

`SKILL.md`'s verdict-B path writes a new PRD covering every confirmed gap. This
reference is the remedy manual: what criterion shape each verdict demands,
where the new file goes, and the gate a scaffold must clear before it reaches
the user. It assumes a verdict is already settled for every task — read
[references/classification.md](references/classification.md) first if it
isn't; that file adjudicates verdicts, this one only acts on them.

## The verdict → remedy table

This table is the spine of the whole file. Each gap verdict demands a
different criterion shape from the follow-up task; get the shape wrong and the
scaffold repeats the defect it exists to close.

| Verdict | What went wrong | What the follow-up criterion must do |
|---|---|---|
| **vacuous-pass** | The original hint was too weak — satisfiable without the behavior existing. | Check the behavior, not the artifact: a targeted `[shell:]` test over a `[grep:]`, an `[http:]` body assertion over a `[file-exists:]`. |
| **landed-with-drift** | The hint was right; the code was wrong. | Reuse the original hint verbatim. The `### Description` carries the diagnosis, not the criterion. |
| **missed** | Nothing landed; there is no mechanism to critique. | Restate the task with a criterion that would have caught the miss — strengthen the original hint if the miss revealed it was too weak, otherwise reuse it. |

A task can carry more than one gap. When it does, the criterion follows
whichever row is strictest for that finding — a task that both drifted from a
design doc and passed vacuously gets the strengthened, behavior-checking
criterion, not the reused one.

## One task per confirmed gap

Write one follow-up task per gap, never a bundle. The `### Description` must
name what the first attempt got wrong and where, quoting the violated line from
a design document when there is one — the follow-up agent should not have to
rediscover a drift you already diagnosed. For a **landed-with-drift** gap this
is most of the task's value: the criterion is unchanged, so the description is
what makes the second attempt land somewhere new.

For a **vacuous-pass** gap, say in the description why the old hint was
satisfiable without the work — name the ritual (see
[references/classification.md](references/classification.md)'s vacuous-pass
mechanism section) so the new criterion's author doesn't reach for a stronger
hint of the same shape.

## What a follow-up criterion looks like

Concrete shapes, one per verdict, all satisfying the table above:

- **vacuous-pass** repair — the original was
  `[grep: rate limiting in README.md]`; the follow-up is
  `[grep: '## Configuring rate limits' in README.md]`, because the gap was a
  one-line mention standing in for a section the description asked for. Where
  the artifact can't be told apart from the behavior by a stronger `[grep:]` at
  all, move hint families entirely — a `[file-exists:]` that a migration script
  is present becomes a `[shell: cargo test --test migration_runs]` that it
  actually runs.
- **landed-with-drift** repair — the original criterion,
  `[shell: cargo test --test middleware_headers]`, is copied unchanged into the
  follow-up task; only the `### Description` changes, naming the file the
  behavior landed in versus the file a design document requires.
- **missed** repair — the follow-up task restates the original acceptance
  criteria verbatim when nothing about them was the problem, or strengthens the
  weakest one first when the miss also exposed that a hint would not have
  caught a partial, wrong implementation either.

## Placement and dependency edges

Write the scaffold beside the original PRD as `<stem>-followup.md`, or into the
repo's next `milestone-N/` directory when the repository organizes PRDs that
way (this repo does, from `milestone-2/` onward). Use the `milestone-N/` form
exactly when the original PRD lived in a `milestone-N/` directory itself;
otherwise `<stem>-followup.md` beside the original is the default and requires
no directory decision.

`**Depends-on**` edges between follow-up tasks stay local to the new PRD — the
same rule §2.2 states for every PRD. A dependency reaching back into the
original PRD's task ids is a **cross-PRD** edge, and cross-PRD edges are a
validation error; the original PRD is a closed record once its run ended, and
nothing in the follow-up may depend on a task id defined outside its own file.

## Grammar

Follow the §2.2 skeleton exactly — the `# PRD:` title, `## Task:` heading with
the em-dash separator, the contiguous metadata block, required `**Effort**` and
`**Depends-on**`, `### Description`, `### Acceptance Criteria` with a hint on
every criterion. Do not restate any of that here: reference
[[zurdo-prd-author]]'s grammar guide for the skeleton, the enforcement rules,
and the common pitfalls. A second copy of the metadata block or the em-dash
rule here is a copy that will drift the moment that file is corrected without
this one.

## The `--strict` gate

Run `zurdo validate --strict <new-prd>` and fix every error before handing the
file to the user — not bare `validate`. A scaffold derived from a
**vacuous-pass** finding is the highest-risk input for exactly the shape that
produced it, so it is held to the same promotion a CI gate applies: `--strict`
promotes six of the ten warn-lint families to validation errors —
`grep-target`, `vacuous-shell`, `grep-tautology`, `doc-echo`, `frozen-overlap`,
and `uncovered-requirement`. The other four stay advisory for three different
reasons: `skill-resolution` permanently, because PRD-referenced skills are
user-managed and a checkout can legitimately lack them; `discarded-evidence` and
`cached-verification` only pending corpus data, so read their findings as real
defects the gate does not yet fail on; and `unaddressed-lesson`, which `zurdo
validate` does not emit at all — it comes from `zurdo analyze`, and no `--strict`
run will ever show it. A scaffold that fails `--strict` is not a
deliverable.

## Worked material

Three real verdict-B scaffolds live in this repository, each with its own run
recorded under `.zurdo/`:
`docs/prds/milestone-13/prd-m13-01-cross-tier-claims-followup.md`,
`prd-m13-03-specs-guides-readme-followup.md`, and
`prd-m13-04-providers-split-followup.md`. Read one before writing a
`### Description` for the first time — each opens with what the reviewed run
got right, states the gap in the language of `criteria_results` and hunks
rather than opinion, and records scope decisions the review made ("executed by
hand, not by `zurdo run`", frozen globs, a criterion's shipped name that must
survive) so a later reader does not re-litigate them.

`prd-m13-01`'s task-1 is the clearest **vacuous-pass** repair: the description
names the exact assertion that was satisfiable by the wrong constant, and the
new criterion is a fixture-backed behavior check —
`skills_install_disclosure_fails_when_either_token_is_missing` proves the
*check* fails when either required token is dropped, which is strictly
stronger than the `[grep:]` it replaces. That is the shape every vacuous-pass
row in the table above should produce: not a stronger version of the same
ritual, but a criterion whose failure mode was verified.
