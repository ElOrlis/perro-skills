# Binding hunks to tasks, and what to do when they will not bind

`run-diff.patch` is run-scoped, not task-scoped. It is one diff for the whole
run, and nothing in it records which task produced which hunk. Every per-task
verdict therefore rests on an attribution *you* made, and an attribution is a
claim like any other: it can be strong, weak, or unavailable, and saying which
is part of the review.

Three signals bind a hunk to a task, and they are not interchangeable. They are
a ladder ordered by evidential strength — work down it and stop at the first
rung that answers, because every rung below is weaker evidence for the same
conclusion.

| Rung | Signal | Where it lives | Strength |
|---|---|---|---|
| 1 | the file a passing criterion actually read | `criteria_results` in `prd.json` | **near-proof** — the runtime observed it |
| 2 | a file the task names | the task's `### Description` and requirements block | authorial intent — the agent may have ignored it |
| 3 | the agent's account of its own work | `.zurdo/<slug>/iterations/<task-id>-<attempt>.out` | **weakest** — a self-report, and the most confabulation-prone |

## Rung 1 — what the runtime observed

Each entry in a task's `criteria_results` records the criterion's `hint` text,
and a local or structural hint names the file it reads: `[grep: … in <file>]`,
`[file-exists: <file>]`, `[symbol: … in <file>]`. That file is the criterion's
evidence path. Alongside it the entry carries `evidence_modified` — whether
that path appeared in the names-only diff against the run-start baseline.
`Some(true)` is the strongest attribution available anywhere in the run state:
the check read that file, and the runtime saw that file change.

Two limits, both worth knowing before leaning on this rung:

- **Opaque hints have no evidence path.** `[shell:]`, `[http:]`, and `[manual]`
  declare no readable file, so their `evidence_modified` is `None`. A task whose
  criteria are all `cargo test` rows offers no rung-1 signal at all — not a weak
  one, none — and drops straight to rung 2.
- **`None` is also what a run with no baseline records.** Baseline capture is
  warn-only. Absent it, every entry reads `None`, and the absence means "not
  measured," not "not modified."

## Rung 2 — what the task asked for

The `### Description` and requirements block name files the work was meant to
touch. This is intent, and intent is not observation: the agent may have edited
a different file, edited the named file for an unrelated reason, or done
neither. Treat a rung-2 match as a strong prior that the next signal can
overturn.

One artifact sharpens this rung without leaving the runtime's own voice:
`iterations/<task-id>-<attempt>.prompt` is what zurdo *told* the agent,
including the generated `# Evidence Paths` section. It records what the task put
in front of the agent, not what the agent then did — but unlike the `.out`
beside it, no agent wrote a word of it.

## Rung 3 — what the agent says it did

The `.out` capture is the agent's narrative. It is genuinely useful: often it is
the only artifact that explains *why* a hunk exists, and it is the fastest way
to recover the reasoning behind a change rungs 1 and 2 already located. It is
also the one signal produced by the thing under review, and it will describe
work in files it never opened with complete fluency. Never let it carry an
attribution alone. Corroborate what it claims against the diff before repeating
it; where you cannot, attribute the hunk to nothing and hedge.

## When the ladder runs out

Three residual shapes account for most of it, and none is a defect on its own:

- **A hunk two tasks both plausibly claim.** Adjacent tasks touching one module
  produce this constantly. Try to split it by rung 1: if exactly one of the two
  has a criterion whose evidence path is that file, the tie breaks. If neither
  does, or both do, the hunk is genuinely shared — say so, and let both tasks'
  verdicts rest on the rest of their evidence.
- **A hunk in a file no task names.** Sometimes incidental (an import, a
  regenerated lockfile, a rename's other half) and sometimes the finding itself.
  Decide which by asking whether the change is *entailed* by attributed work. If
  it is, note it under the task that entailed it; if it is not, it is
  unattributed — see below.
- **A refactor that moved code an earlier task wrote.** This is the trap. The
  diff shows a large deletion where the earlier task's work stood, and it reads
  exactly like that work being undone — drift, or a regression. It is neither:
  the code exists, relocated by a later task doing what it was asked. Before
  recording drift against a task whose code appears deleted, look for the
  matching addition elsewhere in the same diff. Searching the diff for a
  distinctive identifier from the deleted block settles it in one command.

## Say so, in these words

An attribution that ran out of ladder is still reportable — it just has to be
reported as what it is. Calling one approximate out loud costs the reader
nothing; a guess presented as fact costs them the whole review. Write the hedge
in at the point of use, not as a disclaimer at the end:

```
task-headers      landed-with-drift  Attribution approximate: src/api/handler.rs
                                     is named by both task-headers and
                                     task-limiter, and neither task's criteria
                                     read it. Bound here on the iteration
                                     narrative alone, which is the agent's own
                                     account and uncorroborated by the diff. The
                                     drift finding below holds only if this
                                     binding is right.
```

The load-bearing part is the last sentence: name what the verdict would lose if
the attribution is wrong. A hedge that says "approximate" without saying what
depends on it leaves the reader unable to price it.

## Unattributed hunks are not a fifth verdict

Some diff content binds to no task at all. That is a finding, and it is tempting
to file it as a fifth row on the verdict table. Do not — the table cannot hold
it. The four verdicts are keyed *per task*: every row answers "did this task's
intent land?" An unattributed hunk is by definition the content no task claims,
so there is no task to key a row on, and forcing one in means either inventing a
task or silently reassigning the hunk to a real one that did not produce it.

Report them as their own section of the review instead, beside the per-task
table rather than inside it. For each: what changed, why no task accounts for
it, and which of the residual shapes above you ruled out. Then hand the decision
over — flagging out-of-scope changes for human review is this skill's job;
deciding whether to keep or revert them is the user's, and reverting is never
this skill's. Unattributed hunks needing remediation are one of the two triggers
for verdict **B**, so a review that finds them does not end in **A**.
