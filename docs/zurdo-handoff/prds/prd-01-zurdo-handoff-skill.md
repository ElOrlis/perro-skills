# PRD: `zurdo-handoff` — Leave one file behind when a session stops before the initiative does

Build a prose-only skill at `skills/project-management/zurdo-handoff/` that defines what a session working a Zurdo initiative or PRD leaves behind when it stops: `docs/<initiative>/handoff.md`, seven fixed sections, exactly one next action, committed alone as the session's last commit. The design is settled in [docs/zurdo-handoff/design/handoff-and-wayfinder.md](../design/handoff-and-wayfinder.md); every decision below is binding on every task and traceable to §5.1 of that record.

Design decisions, binding on every task:

- **One file per initiative** at `docs/<initiative>/handoff.md`, where `<initiative>` holds `scope.md`; in a PRD-only repository, the directory holding the `prds/` folder of the PRD the session stopped on. Overwritten at every stop, never appended; git is the history.
- **Frontmatter** `initiative`, `stopped_at` (UTC ISO-8601), `station` (one of `scope | research | phase-prd | publish | run-and-sync | phase-review`), `phase` (`phase-NN`, or the PRD basename), `by` (`agent | user`).
- **Seven H2 sections in fixed order**: Stopped at, Done this session, In flight, Waiting on a human, Next action, Uncommitted, Watch out. Every section present; an empty one says `None.`
- **Exactly one next action**, as a row number and text from `zurdo-project`'s later-session priority table, or one of `zurdo-state-summary`'s six verbs in PRD-only mode. Never a third vocabulary.
- **Graduation rule.** Nothing durable lives only in the handoff: decisions go to `scope.md` Decisions so far, corrections to `lessons/` through `zurdo-lessons`, facts to Notes, sharp questions to tickets. Watch out lists any item not yet at its home, naming the home.
- **Five stop points**: the runbook's stop; before a blocking wait on a human; before leaving an AFK step running; the user says stop or the context nears its limit; a station finished and the next belongs to another actor or skill.
- **Commit is the last act**: `git commit -m "handoff: <initiative> — <next action>"` containing only the handoff; push when a remote exists. A dirty tree is committed first or listed verbatim under Uncommitted.
- **Waiting on a human** carries the question with its ➡️ recommendation or the command only the user can run; it opens no new resolution path. The agent never answers a grilling ticket.
- **Receivers** are the next session (through `zurdo-wayfinder` or by reading), the user, and a stopped skill chain (pointers to `.zurdo/authoring/<session>.json`, an uncommitted follow-up PRD, lesson files). Research subagents are not receivers; their brief stays in `zurdo-project/references/research.md` and is cited, not copied. GitHub is not a receiver; the handoff is not projected.
- **Skill shape**: `SKILL.md`, `references/record.md`, `references/stop-points.md`, `references/receivers.md`, `examples/handoff.md`. The example describes the initiative in `zurdo-project/examples/scope.md` and doubles as the grep fixture.

Verification: prose gates on `file-exists`, `grep` of author-controlled strings, `[manual]` rubrics against the four authoring rules in `CLAUDE.md`, and a `no-grep` for placeholder markers. Effort values are `low`, `medium`, `high` from `.zurdo/config.toml`.

## Task: task-handoff-spine — Write the zurdo-handoff SKILL.md
**Effort**: medium
**Depends-on**: []

### Description

Create `skills/project-management/zurdo-handoff/SKILL.md`. Frontmatter: `name: zurdo-handoff` and a description that triggers on ending or pausing a session on a Zurdo initiative or PRD (hand off, stop here, pick this up later; before waiting on a human; before leaving `zurdo run` or subagents unattended; context near its limit) and explicitly does not trigger for a research subagent's brief, for summarizing one run, or for editing `scope.md`.

Body: a Stop points list (the five), Decision Rules each as imperative + one-line why + `→ see references/<file>.md` covering the graduation rule, one-file-overwrite, seven sections, one next action in an existing vocabulary, commit-is-the-last-act, no silent dirty tree, Waiting on a human opens no new path, In flight is re-checked, refer by name, and pointing a stopped skill chain at its state. Then a "The record" block showing the frontmatter keys and seven headings, a Files section, a Commit sequence, a References section linking all three references with one-line descriptions, and an Examples line.

### Acceptance Criteria

- [ ] SKILL.md exists [file-exists: skills/project-management/zurdo-handoff/SKILL.md]
- [ ] Frontmatter declares the skill name [grep: name: zurdo-handoff in skills/project-management/zurdo-handoff/SKILL.md]
- [ ] The spine names the seventh section [grep: ## Watch out in skills/project-management/zurdo-handoff/SKILL.md]
- [ ] The spine links every reference file [grep: references/receivers.md in skills/project-management/zurdo-handoff/SKILL.md]
- [ ] The description triggers on session end or pause and excludes subagent briefs, run summaries, and scope.md edits; every inline rule is imperative + why + arrow [manual]
- [ ] No placeholder markers remain [no-grep: TODO in skills/project-management/zurdo-handoff/SKILL.md]

## Task: task-handoff-references — Write the three references
**Effort**: medium
**Depends-on**: [task-handoff-spine]

### Description

Author `references/record.md` (the full template, the per-section table, the graduation rule as a table of item → home → who moves it, what never goes in, refer-by-name, placement including PRD-only, freshness from the receiver's side), `references/stop-points.md` (each of the five stop points with what the record carries, the commit sequence and its rules, dirty trees, what to tell the user, overwrite-never-append), and `references/receivers.md` (the next session, the user, a stopped skill chain as a table of chain → what Next action and In flight carry, who is not a receiver, the no-handoff case). Terse imperative voice, no filler.

### Acceptance Criteria

- [ ] record.md exists [file-exists: skills/project-management/zurdo-handoff/references/record.md]
- [ ] stop-points.md exists [file-exists: skills/project-management/zurdo-handoff/references/stop-points.md]
- [ ] receivers.md exists [file-exists: skills/project-management/zurdo-handoff/references/receivers.md]
- [ ] record.md carries the graduation rule [grep: graduation rule in skills/project-management/zurdo-handoff/references/record.md]
- [ ] receivers.md points a stopped authoring interview at its session file [grep: .zurdo/authoring/ in skills/project-management/zurdo-handoff/references/receivers.md]
- [ ] Each reference covers its required content in the existing voice, and none copies the research subagent brief [manual]

## Task: task-handoff-example — Write examples/handoff.md
**Effort**: low
**Depends-on**: [task-handoff-spine]

### Description

Write `examples/handoff.md` for the initiative described by `zurdo-project/examples/scope.md`: stopped at Run and sync on phase-01, frontmatter complete, all seven sections filled, one research subagent under In flight, `zurdo review` under Waiting on a human, row 8 under Next action with its precondition, `Clean.` under Uncommitted, and two Watch out items each naming its home.

### Acceptance Criteria

- [ ] Example exists [file-exists: skills/project-management/zurdo-handoff/examples/handoff.md]
- [ ] Example carries the frontmatter station key [grep: station: run-and-sync in skills/project-management/zurdo-handoff/examples/handoff.md]
- [ ] Example carries every one of the seven headings [grep: ## Waiting on a human in skills/project-management/zurdo-handoff/examples/handoff.md]
- [ ] Example names one next action as a row [grep: Row 8 in skills/project-management/zurdo-handoff/examples/handoff.md]
- [ ] Example reads as a record a user would copy, with Watch out items naming their homes [manual]

## Task: task-handoff-catalog — Add the skill to the README
**Effort**: low
**Depends-on**: [task-handoff-spine, task-handoff-references, task-handoff-example]

### Description

Add a `zurdo-handoff` row to the skills table in `README.md`, a `### zurdo-handoff` subsection in the existing style listing the three references and the example, and the skill's directory in the Repository layout tree.

### Acceptance Criteria

- [ ] README lists the skill path [grep: skills/project-management/zurdo-handoff/ in README.md]
- [ ] README has the subsection [grep: ### `zurdo-handoff` in README.md]
- [ ] The row, subsection, and layout entry match the style of the sibling skills [manual]
