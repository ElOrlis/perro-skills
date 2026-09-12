# PRD: `zurdo-wayfinder` — Orient a session inside an initiative and name one next action, read-only

Build a prose-only skill at `skills/project-management/zurdo-wayfinder/` that opens a session on an existing Zurdo initiative or PRD: it reads five inputs in authority order, verifies the previous session's handoff against the files, emits a fixed-shape situation report, names exactly one next action in an existing vocabulary, and ends by naming the skill that acts. It never writes. The design is settled in [docs/zurdo-handoff/design/handoff-and-wayfinder.md](../../zurdo-handoff/design/handoff-and-wayfinder.md) §5.2, including the verdict that the skill is needed and narrow.

Design decisions, binding on every task:

- **Read-only.** `allowed-tools: [Read, Grep, Glob, Bash]`; Bash limited to `git status`, `git log`, `zurdo state list`, `zurdo state where`, `gh issue view --json assignees`. Never a file write, a `zurdo-github.sh` mode, `zurdo run`, `git commit`, or `gh issue edit`.
- **Authority ladder**: files (`scope.md`, `tickets/*.md`) over run state (`prd.json`, `lock`) over git over the handoff over GitHub claims. The higher wins and the report names the disagreement.
- **Freshness test**: a handoff is `fresh` when no commit touched `docs/<initiative>/` after the handoff commit and no `prd.json` in the Phases table has `last_updated` after `stopped_at`; else `stale`; absent is `none`, not an error. Stale keeps In flight and Waiting on a human (re-checked) and re-derives station and next action from the files.
- **One next action**: a row of `zurdo-project`'s later-session priority table when an initiative exists; one of `zurdo-state-summary`'s six verbs in a PRD-only repository; never a third vocabulary. The runbook table is canonical; on disagreement the wayfinder's reference changes.
- **Grilling first** when the user is present; under Waiting on a human when not.
- **`Do not` block** with the fact that blocks each move: `sync-status` under a live `lock`; PRD authoring for a phase with an open blocking ticket; any live script mode over a dirty tree; and the rest of the catalogue.
- **Fixed-shape report** at `zurdo-state-summary`'s density, ending with `Acts:` naming the skill or the user.
- **Delegation**: invoke `zurdo-state-summary` for the run tally when installed; tally by hand otherwise and say so. Claims are read from GitHub only when `gh` is available; skipped with a reason otherwise.
- **PRD-only degradation**: one block per PRD directory with run state; the six verbs as the vocabulary.
- **Skill shape**: `SKILL.md`, `references/inputs.md`, `references/situation-report.md`, `references/next-action.md`.

Verification: prose gates on `file-exists`, `grep` of author-controlled strings, `[manual]` rubrics against the four authoring rules in `CLAUDE.md`, and a `no-grep` for placeholder markers. Effort values are `low`, `medium`, `high` from `.zurdo/config.toml`.

## Task: task-wayfinder-spine — Write the zurdo-wayfinder SKILL.md
**Effort**: medium
**Depends-on**: []

### Description

Create `skills/project-management/zurdo-wayfinder/SKILL.md`. Frontmatter: `name: zurdo-wayfinder`, a description that triggers on asking where an initiative or PRD stands, what this session should do, or to be caught up, and at the start of any session resuming an existing initiative; explicitly does not trigger to summarize one run in detail, to start or scope a new initiative, or to take the action it names; states the read-only posture; and `allowed-tools: [Read, Grep, Glob, Bash]`.

Body: a seven-step Procedure (locate, read the map, read run state, read git, read and verify the handoff, read claims optionally, compose and stop), Decision Rules each as imperative + why + arrow covering the authority ladder, read-only, the freshness test, re-checking In flight, one next action in two vocabularies, grilling first, the three forbidden moves, the fixed shape, ending by naming who acts, and PRD-only degradation. Then "The report" shape as a fenced block, a "Read-only command set" block, and a References section linking all three references with one-line descriptions.

### Acceptance Criteria

- [ ] SKILL.md exists [file-exists: skills/project-management/zurdo-wayfinder/SKILL.md]
- [ ] Frontmatter declares the skill name [grep: name: zurdo-wayfinder in skills/project-management/zurdo-wayfinder/SKILL.md]
- [ ] Frontmatter declares the read-only tool set [grep: allowed-tools: \[Read, Grep, Glob, Bash\] in skills/project-management/zurdo-wayfinder/SKILL.md]
- [ ] The spine links every reference file [grep: references/next-action.md in skills/project-management/zurdo-wayfinder/SKILL.md]
- [ ] The description triggers on orientation and excludes run summaries, initiative start, and acting; the tool set names neither Write nor Edit; every inline rule is imperative + why + arrow [manual]
- [ ] No placeholder markers remain [no-grep: TODO in skills/project-management/zurdo-wayfinder/SKILL.md]

## Task: task-wayfinder-references — Write the three references
**Effort**: high
**Depends-on**: [task-wayfinder-spine]

### Description

Author `references/inputs.md` (the authority ladder as a table with proves/does-not-prove, each input's exact commands, run-state outcomes mapped to rows, the freshness test with its verdict table, re-check tables for In flight and Waiting on a human, claims read-only, PRD-only mode), `references/situation-report.md` (the shape with filling rules, then fresh, stale, no-handoff, and PRD-only variants worked against the example initiative), and `references/next-action.md` (all ten runbook rows as a table with select-check, block-check, and actor; when no row selects; the six verbs; the `Do not` catalogue; who acts). State in next-action.md that the runbook table is canonical and wins on disagreement.

### Acceptance Criteria

- [ ] inputs.md exists [file-exists: skills/project-management/zurdo-wayfinder/references/inputs.md]
- [ ] situation-report.md exists [file-exists: skills/project-management/zurdo-wayfinder/references/situation-report.md]
- [ ] next-action.md exists [file-exists: skills/project-management/zurdo-wayfinder/references/next-action.md]
- [ ] inputs.md carries the freshness test [grep: Freshness test in skills/project-management/zurdo-wayfinder/references/inputs.md]
- [ ] next-action.md names the runbook as canonical [grep: the runbook wins in skills/project-management/zurdo-wayfinder/references/next-action.md]
- [ ] next-action.md names all six run verbs [grep: fix-then-resume in skills/project-management/zurdo-wayfinder/references/next-action.md]
- [ ] next-action.md carries all ten runbook rows in order with select and block checks, and situation-report.md works all four variants [manual]

## Task: task-wayfinder-catalog — Add the skill to the README
**Effort**: low
**Depends-on**: [task-wayfinder-spine, task-wayfinder-references]

### Description

Add a `zurdo-wayfinder` row to the skills table in `README.md`, a `### zurdo-wayfinder` subsection in the existing style listing the three references, and the skill's directory in the Repository layout tree.

### Acceptance Criteria

- [ ] README lists the skill path [grep: skills/project-management/zurdo-wayfinder/ in README.md]
- [ ] README has the subsection [grep: ### `zurdo-wayfinder` in README.md]
- [ ] The row, subsection, and layout entry match the style of the sibling skills [manual]

## Task: task-integrate — Wire both session skills into zurdo-project and the journey guide
**Effort**: medium
**Depends-on**: [task-wayfinder-catalog]

### Description

Phase C of the design record. In `skills/project-management/zurdo-project/SKILL.md`, add the inline rule "Orient before acting and hand off before stopping; the files are truth and the handoff is a hint" pointing at `references/runbook.md`, name both skills in the optional-skills rule, and add `handoff.md` to the Files tree. In `references/runbook.md`, add `zurdo-wayfinder` and `zurdo-handoff` rows to the dependency table with inline fallbacks, a step 0 "Orient" and a step 4 "Hand off" in "Every later session", a step 10 "Hand off" after the first session's stop, and replace "session summary" with the handoff's Watch out. In `docs/guides/zurdo-github-journey.md`, add both skills to the role table, add the missing "start zurdo run" branch to the station 07 tree, add a "Stop: hand off" subsection, and replace "session notes" with the handoff.

### Acceptance Criteria

- [ ] zurdo-project runbook names the handoff skill [grep: zurdo-handoff in skills/project-management/zurdo-project/references/runbook.md]
- [ ] zurdo-project runbook names the wayfinder skill [grep: zurdo-wayfinder in skills/project-management/zurdo-project/references/runbook.md]
- [ ] zurdo-project SKILL.md carries the new rule [grep: Orient before acting and hand off before stopping in skills/project-management/zurdo-project/SKILL.md]
- [ ] The undefined "session summary" is gone from the runbook [no-grep: session summary in skills/project-management/zurdo-project/references/runbook.md]
- [ ] The undefined "session notes" is gone from the journey guide [no-grep: session notes in docs/guides/zurdo-github-journey.md]
- [ ] The station 07 tree carries the start-run branch [grep: Start zurdo run in docs/guides/zurdo-github-journey.md]
- [ ] The journey guide has the stop station [grep: ### Stop: hand off in docs/guides/zurdo-github-journey.md]
- [ ] Every edit reads in the existing voice and zurdo-project still works with neither skill installed [manual]
