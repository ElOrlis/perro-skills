# Frozen paths — protecting what the agent must not touch

Frozen paths are the enforcement tier of evidence integrity (milestone-4): a
set of globs the executing agent must not modify. After each iteration's
verification step, the runtime diffs the working tree against the owning
task's per-task baseline (names only, captured at that task's first attempt
and held across retries) and matches every changed path against the union of
the active globs. A match **fails the iteration regardless of criteria results**,
records `frozen path modified: <path>` in the iteration record, and the next
attempt's prompt opens with a `# Frozen Path Violation` section instructing
revert-only. Exhausting `Max-Attempts` with a standing violation is the
standard `failed` / exit-5 path.

Two authoring surfaces feed that one check:

- **`**Frozen**`** — an optional per-task metadata key in the PRD (syntax in
  [grammar-2.2.md](grammar-2.2.md)). This is the surface this skill writes.
- **`[verification] protected_paths`** — a run-wide glob list in
  `.zurdo/config.toml`. This skill **never edits config**; when a run-wide
  protection is warranted, surface it as an advisory note to the user.

## The interview questions

**Phase 2 (evidence inventory) — the negative-space question.** For each
capability, alongside "when this is done, what observable facts will be
true?", ask: *"what must NOT change while delivering this?"* Record each
answer as a candidate protection next to the positive evidence. Do not bind
globs yet — no tasks exist to carry them.

**Phase 3 (grouping) — binding.** Once clusters become tasks, translate each
candidate protection into globs on the owning task's `**Frozen**` key, using
the scope rule below, and run the overlap check before the phase gate closes.

## The scope rule

- A path that must stay untouched **during one task's work** (and may
  legitimately change in another task) → that task's `**Frozen**` key.
- A path **no task in the PRD may ever touch** → recommend the user add it to
  `[verification] protected_paths` in `.zurdo/config.toml`. Duplicating it
  onto every task's `**Frozen**` key is noisy and drifts when tasks are added.
- Enforcement is the **union** of both surfaces — a task-level key never
  weakens a config-level protection.
- The per-task baseline means a path an *earlier* task legitimately writes
  can still be frozen on a *later* task: task A writing `F` and task B
  freezing `F` is a winnable shape, not a trap — each task's check diffs
  from that task's own first-attempt baseline, so B never sees A's write as
  a violation — a guarantee that has been reliable only since **v1.13.1**, tied to the baseline-symmetry fix
  (pre-1.13.1 builds diffed the run-start tree against the real index instead
  of tree-to-tree, and could misread A's write as a violation).

## When to freeze — and when not to

Good candidates:

- Specs, golden files, and fixtures the task must conform to but not edit
  (freezing the spec forecloses "make the test pass by editing the spec").
- Artifacts owned by a *different* task in the same PRD, when this task could
  plausibly clobber them.
- Migration or schema files that are already applied and must stay
  byte-identical.

Do not freeze:

- **Any path a same-task criterion's evidence requires the agent to edit** —
  this is the overlap trap below.
- Broad globs (`src/**`) on a task that edits source — the agent cannot do
  the work. Freeze the narrowest set of paths that captures the intent.

## The overlap trap (phase-3 gate check)

A frozen glob that matches an evidence path of a criterion **in the same
task** makes the task unwinnable: the criteria can never legitimately pass if
the work requires editing that evidence. Before the grouping gate closes,
check every bound glob against every evidence path of the same task's hints
(dialect below — remember `*` does not cross `/`). Any overlap blocks the
gate: narrow the glob or move the protection elsewhere.
`zurdo analyze` warns on this overlap under the `frozen-overlap` lint family in
the grammar phase — treat it as the deterministic backstop, not the primary
catch: `zurdo analyze` itself never changes the exit code on this warning, and
it is easy to skate past.

## The validate-rail check (`frozen-overlap`)

`zurdo validate` and `--analyze` both run this warning as the lint family
`frozen-overlap`, and it draws a **guard distinction** the overlap trap above
does not spell out: matching a frozen glob is not itself the problem — only
needing to *edit* the frozen path to make the criterion pass is.

`zurdo validate --strict` promotes `frozen-overlap`, alongside five of the
other eight lint families, to a validation error — a PRD that would otherwise
pass with this warning now exits 2. Three families are never promoted:
`skill-resolution` permanently (PRD-referenced skills are user-managed, so a CI
checkout legitimately lacks them), and `discarded-evidence` and
`cached-verification` pending corpus data. `frozen-overlap` carries no such
exemption.

- A `[no-grep:]` or `[file-exists:]` hint whose target already holds is a guard,
  not a defect: it is asserting the frozen path stays as it already is against
  the working tree, so `frozen-overlap` does not fire on it. This is
  legitimate authoring, and a normal way to pin a frozen file's shape.
- A `[grep:]` for a pattern that is not present yet, or a `[file-absent:]`
  for a file that still exists, fires the family — the criterion can only go
  green by writing to (or deleting) a path this task is not allowed to
  touch, which is the overlap trap made concrete.

Only the four local hint flavors (`[grep:]`, `[no-grep:]`, `[file-exists:]`,
`[file-absent:]`) are evaluated; structural hints never participate.

## Glob dialect (locked)

`glob`-crate semantics with literal separators: patterns are **root-anchored**
at the repo root; `*` stays within one path segment; `**` crosses
directories; the list is comma-separated; a leading `!` (negation) is a parse
error. `zurdo validate` rejects invalid glob syntax with a line-numbered
error.

## The baseline caveat — the run-start tree, and the review skill's diff

Enforcement diffs against a **per-task baseline**, captured the first time
that task is attempted and held across its retries — so a path an earlier
task legitimately wrote can still be frozen on a later task without making
that later task unwinnable. The tree captured at the start of the run is also
retained, alongside the per-task tree, in the same `.zurdo/<slug>/baseline`
file; the frozen check itself never reads it. What does read it is
`baseline.run_tree`'s own diff: at the end of every run that captured a
baseline, the runner writes the full unified diff against it to
`.zurdo/<slug>/run-diff.patch`. That file is not only a review-TUI
convenience — it is the **primary evidence** the `zurdo-prd-review` skill
reads to judge whether a run landed its PRD's intent, ahead of `prd.json`'s
per-criterion results.

Both the run-start tree and every per-task baseline are captured, and later
compared, through the same scratch-index → `git diff-tree` pipeline, so a
file untracked when a baseline is captured is handled exactly like a tracked
one: left alone, it never reads as changed; edited, it always does. There is
no separate "untracked" case and no commit ritual to work around one — a
fresh PRD or a freshly created file needs no `git add` or commit before
`zurdo run` for frozen-path enforcement to read it correctly. When no
baseline exists at all — no git on `PATH`, not a git repository, or the
capture itself fails; capture is warn-only, never a gate — enforcement
reports itself unavailable with a warning and does not fail iterations.

## Honesty note

The baseline lives under `.zurdo/`, inside the agent's writable scope. The
guard is **tamper-evident, not tamper-proof**, backstopped by criteria being
independently re-run. Do not oversell frozen paths in PRD prose as a hard
security boundary.

Related, same milestone: the *warning* tier of evidence integrity —
evidence-modified warnings — flags when evidence behind an already-passed
criterion changes later in the run. That surfaces at review time; see
[review-layers.md](review-layers.md).
