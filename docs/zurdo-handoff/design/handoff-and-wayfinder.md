---
implementation: shipped
---

# Design: `zurdo-handoff` and `zurdo-wayfinder` — stop an initiative and resume it without re-deriving it

Two prose-only skills for `skills/project-management/`. `zurdo-handoff` defines what a session leaves behind when it stops before the initiative does: one file, fixed shape, one next action, committed as the session's last act. `zurdo-wayfinder` is the read-only reader that orients a new session from the files, verifies the handoff against them, and names one next action without changing anything. The verdict the user asked for is in §5.2: the wayfinder is needed, and it is narrow.

Placement: this record lives at `docs/zurdo-handoff/design/`; the phase PRDs are at `docs/zurdo-handoff/prds/` and `docs/zurdo-wayfinder/prds/`, one folder per skill as `CLAUDE.md` requires. Nothing in this repository parses the frontmatter above; it is carried for the reader and for the amend discipline. See the amendment at the end for how the phases were shipped.

---

## 1. Motivation

Both project-management skills say when a session stops and how the next one orients, but neither defines what a stopping session leaves behind. So every later session re-derives its position from six inputs, two artifacts that would carry it ("session summary", "session notes") are named but never specified, and the closing "handoff" every bundled `zurdo-*` skill emits is a chat message that dies with the session.

What it costs: the first ten minutes of every session are spent reading `scope.md`, every ticket, the newest `prd.json`, `git log`, and the GitHub sidebar to answer "where are we and what is one thing to do". A grilling question the agent stopped on is not written anywhere the user can read before the next session. A mid-interview `zurdo-prd-author` stop has a resumable session file that nothing points at. And a teammate arriving cold, or a different agent, has no artifact to trust, so they trust the newest-looking thing.

---

## 2. What already ships

Every proposal in §5 is stated as a delta against a row of this table.

| Row | Surface | What it does | Where | What it does not do |
|---|---|---|---|---|
| 1 | Runbook, "First session — charting" | Defines the stop point: "Stop here" after one session's worth | `zurdo-project/references/runbook.md:43,75` | Writes nothing at the stop |
| 2 | Runbook, "Every later session" | Orient: read `scope.md`, `scope --dry-run`, then a 10-row priority table picks one action | `runbook.md:79-106` | Reads run state only as "a `.zurdo/<prd-basename>-*/` directory exists"; reads no git, no claims, no prior session |
| 3 | Journey guide, station 07 | The same priority table as a mermaid decision tree | `docs/guides/zurdo-github-journey.md:370-398` | Second copy of row 2; carries 9 of its 10 rows (§3) |
| 4 | `zurdo-state-summary` | One run's tally plus exactly one next action from six verbs (resume, fix-then-resume, heal, verify, reset, review) | `.claude/skills/zurdo-state-summary/SKILL.md:72-78` | Run-scoped by its own text (`:10,17`); bundled with Zurdo, not this repo's to edit |
| 5 | Scope map, "Claim and resolve" and "Concurrency" | Claim is assignment on the GitHub issue; pull before editing, commit right after; read the live summary | `zurdo-project/references/scope-map.md:173-203` | Claims are invisible from the repository; no record of who holds what |
| 6 | Research, "Running research AFK" | The one written handoff shape that exists: the subagent brief (question verbatim, destination file, three deliverables) | `zurdo-project/references/research.md:62-74` | Covers agent → subagent only |
| 7 | Interview, "Grilling tickets" | User absent → leave the ticket open, block dependent work | `zurdo-project/references/interview.md:113-120` | No artifact tells the user what is waiting for them |
| 8 | Bundled skills' closing handoff | `zurdo-prd-author:155`, `zurdo-prd-review:118`, `zurdo-design-author:167`, `zurdo-lessons:227` each end with "the handoff": name the files written, say the next step | `.claude/skills/*/SKILL.md` | Chat only; lost when the session ends mid-chain |
| 9 | `zurdo-prd-author` session tracker | Persists the interview to `.zurdo/authoring/<session>.json`, resumable | `zurdo-prd-author/SKILL.md:222` | Nothing outside the interview points a later session at it |
| 10 | Two dangling names | "note it in the session summary"; "Mara adds the initiative title to the session notes" | `runbook.md:181`; `zurdo-github-journey.md:520` | Neither artifact is defined anywhere |

The single thing none of these does: leave a durable, fixed-shape record at the stop point, and read it back with a check against the files before trusting it. Rows 2 and 3 orient from files but forget the previous session existed. Rows 6 and 8 hand off but only to a subagent or a chat window. Row 4 answers "what next" for one run, not for the initiative.

---

## 3. Measured

Numbers taken at commit `294494b` on 2026-09-12, by grep over this repository.

| Claim | Number | How measured |
|---|---|---|
| Files under `skills/` that define an end-of-session artifact | 0 (3 mentions of "hand off", none defines a file) | `grep -rni "handoff\|hand off" skills/` |
| Session-end artifacts named but never defined | 2 ("session summary", "session notes") | `grep -rn "session summary\|session notes" skills docs` |
| Copies of the later-session orientation procedure | 2 initiative-scoped (rows 2, 3) + 1 run-scoped (row 4) | headings at `runbook.md:79`, `journey.md:370`, `zurdo-state-summary/SKILL.md:72` |
| Rows in the runbook priority table | 10 | `grep -c "^   | [0-9]" runbook.md` |
| Of those, rows with a branch in the journey tree | 9; missing row 5, "phase `running`, no run directory → start `zurdo run`" | read `journey.md:374-396`; the tree has "zurdo run is in flight" and no "start zurdo run" |
| Chat-only handoffs in bundled skills | 4 | `grep -rn -i handoff .claude/skills/*/SKILL.md` |
| Inputs a later session reads to orient | 6: `scope.md`, `tickets/*.md`, `.zurdo/<slug>/{prd.json,lock}`, `git status` and `git log`, GitHub assignees, `.zurdo/authoring/*.json` | rows 2, 4, 5, 9 of §2; no single row reads all six |
| Occurrences of `zurdo-handoff` or `zurdo-wayfinder` in the repository | 0 | `grep -rn "zurdo-handoff\|zurdo-wayfinder" . --exclude-dir=.git` — the frontmatter probe |

The two copies in rows 2 and 3 already disagree by one row. That is the measured cost of orientation logic with two owners, and the reason §5.2 gives orientation exactly one.

---

## 4. Goals and non-goals

### Goals

- A stopping session leaves one file, in a fixed shape, that names exactly one next action in a vocabulary that already exists.
- A starting session can orient from the files alone, verify the handoff against them, and name one next action without mutating anything.
- Nothing durable lives only in the handoff. Decisions, corrections, facts, and run outcomes each already have a home; the handoff points at the home and says whether the item has reached it.
- Both skills work with the `zurdo-project` layout (`docs/<initiative>/scope.md`) and without it (a PRD-only repository like this one).
- Both skills work without each other, and `zurdo-project` works without both.

### Non-goals

- **No change to `zurdo-github.sh` and no GitHub projection of the handoff.** The receiving agent reads the repository, not GitHub; a GitHub-only teammate already gets the phase table from the board README that `scope` refreshes. Reopened by open question 1 if a sandbox week shows that teammate needs "Waiting on a human" or "Claimed" on the board.
- **No edits to the bundled `zurdo-*` skills.** They are installed by `zurdo skills install`, not authored here. Their chat handoffs stay; the new skill gives them a durable landing when the session ends mid-chain.
- **No handoff history directory.** Git is the history; `git log -- docs/<initiative>/handoff.md` lists every baton ever passed. A directory of dated files makes a reader pick one and consumes nothing.
- **No replacement for `zurdo-state-summary`.** It is run-scoped by design and says so. The wayfinder delegates to it for the run tally when installed.
- **No new section in `scope.md` and no new ticket type.** The `scope` parser keys on six exact H2 names and silently buckets any other as `other_<name>` (`zurdo-github.sh:932`), so a seventh section would never reach the scope issue or the board. The six it does know are re-rendered onto the board README on every run, so making the stop record one of them would put a transient note in front of the wrong audience every time.
- **The wayfinder never acts.** It names the skill that acts. A read-only skill is the only one a human can invoke on a live run without fear; acting is `zurdo-project`'s job and stays there.

---

## 5. The decision

### 5.1 `zurdo-handoff`

Delta against §2: gives row 1's stop point an artifact, replaces both names in row 10, gives row 7's waiting user something to read, and gives rows 8 and 9 a pointer that survives the session. Row 6's subagent brief is not duplicated; the skill cites it as the one handoff shape already written.

**The artifact.** `docs/<initiative>/handoff.md`, where `<initiative>` is the directory holding `scope.md`. In a PRD-only repository it is the directory holding `prds/` for the PRD the session stopped on (`docs/zurdo-project/handoff.md` in this repository). One file per initiative. Overwritten at every stop, never appended. Committed as the session's last commit; pushed when a remote exists.

**The shape.** YAML frontmatter the wayfinder keys on, then seven H2 sections in this order. Every section is present; an empty one says `None.`

```markdown
---
initiative: observability-export
stopped_at: 2026-09-12T18:40:00Z
station: run-and-sync        # scope | research | phase-prd | publish | run-and-sync | phase-review
phase: phase-01
by: agent                    # agent | user
---

# Handoff: Observability export

## Stopped at

Run and sync, phase-01 [CSV export](prds/prd-01-csv-export.md). `zurdo run` finished and `sync-status` is applied; `zurdo review` has not run.

## Done this session

- Fixed the manifest heading, ran `zurdo run --resume`; every task is now `passed` or `passed-pending-review` (`.zurdo/prd-01-csv-export-a91c/prd.json`).
- `sync-status` live: closed four task issues, labelled one pending-review. Commit `3f2a9c1`.

## In flight

- Research subagent on [Webhook retry policy](tickets/webhook-retries.md), dispatched 17:55Z. Check `status:` in the ticket file; the subagent runs `ticket` itself.

## Waiting on a human

- `zurdo review docs/observability-export/prds/prd-01-csv-export.md` — one `[manual]` criterion on task-manifest ("schema version present and documented"). Then `sync-status` again.

## Next action

Row 8 — the run is settled with every task `passed` or `passed-pending-review`: `zurdo review`, `sync-status`, `scope`, then `zurdo-prd-review`. Re-check before acting: no `lock` in `.zurdo/prd-01-csv-export-a91c/`.

## Uncommitted

Clean.

## Watch out

- `board` needs `--project "Observability export"`; without it a second board appears. Belongs in `scope.md` Notes; not written there yet.
```

**What each section holds, and the rule behind it.**

| Section | Holds | Rule |
|---|---|---|
| Stopped at | The lifecycle station (one of the six in `zurdo-project`'s Lifecycle) and the phase, one line, then what is and is not applied | Name the station in the skill's own words so the wayfinder and the runbook agree on where "here" is |
| Done this session | One bullet per artifact changed or script mode run, with the commit hash | Refer by name (scope-map.md "Refer by name"): tickets and phases by title, numbers inside the link |
| In flight | Work that continues with nobody watching: dispatched research subagents, a `zurdo run` still holding its lock, a pushed branch awaiting review; each with how to check it | The next session must know what may have changed underneath it since the stop |
| Waiting on a human | Every HITL gate open at the stop: a grilling question (with its ➡️ recommendation), `zurdo review`, a `[manual]` sandbox check, the commit review gate | Carries the question so the user arrives prepared; opens no new resolution path — a grilling ticket is still resolved live per `interview.md` |
| Next action | Exactly one, as a row number and its text from `zurdo-project`'s priority table, plus the precondition the receiver must re-check | One action, one existing vocabulary (§5.3); the receiver verifies the precondition, never trusts the row |
| Uncommitted | `git status --short` at the stop, or `Clean.` | Commit before handing off; when you cannot, list every path so nothing is discovered by accident |
| Watch out | Gotchas learned this session that have no home yet, each naming the home it should reach | The handoff is the only place a durable item may sit temporarily, and only if it says where it belongs |

**Graduation rule.** Nothing in the handoff is the only copy of something durable. A decision goes to `scope.md` Decisions so far. A correction that would otherwise be rediscovered goes to `lessons/` through `zurdo-lessons`. A domain fact or preference goes to `scope.md` Notes. A run outcome is already in `prd.json`. The handoff lists any of these that has not reached its home yet, under Watch out, with the home named. The receiver's first act after orienting is to move them.

**Stop points.** Write the handoff at any of these, and only then:

1. The runbook's stop ("Stop here" after one session's worth; after publish, before `zurdo run`).
2. Before a blocking wait on a human: a grilling question has been asked and not answered, `zurdo review` is due, a `[manual]` sandbox check is the author's.
3. Before leaving an AFK step running: `zurdo run` started, research subagents dispatched.
4. The user says stop, pause, hand off, pick this up later; or the context window is near its limit.
5. A lifecycle station finished and the next belongs to another actor or another skill (design record done → `zurdo-prd-author` next session; intent review scaffolded a follow-up that is not yet committed).

**Receivers.** The next session, through the wayfinder or by reading the file. The user, through Waiting on a human. A skill chain, through pointers: the `.zurdo/authoring/<session>.json` a stopped `zurdo-prd-author` interview left, the uncommitted `<stem>-followup.md` and `lessons/` files a `zurdo-prd-review` verdict wrote. Subagents are not receivers of this file; their brief is `research.md`'s, and the handoff only records that they were dispatched.

**Skill shape.** `skills/project-management/zurdo-handoff/`:

- `SKILL.md` — the stop points, the seven sections, the graduation rule, the commit-is-the-last-act rule, the one-vocabulary rule, each as imperative + why + arrow.
- `references/record.md` — the template, the per-section table, what never goes in, the PRD-only placement rule.
- `references/stop-points.md` — the five triggers in depth; what to say to the user at a human wait; the AFK stop (`zurdo run`, subagents) and how In flight is checked later.
- `references/receivers.md` — what each receiver needs; the skill-chain pointers; why the subagent brief lives in `research.md` and is cited, not copied.
- `examples/handoff.md` — the record above, for the example initiative that `zurdo-project/examples/scope.md` already describes; doubles as the grep fixture for the PRD.

Frontmatter description: triggers when a session on a Zurdo initiative or PRD is ending or pausing, when the user says hand off, stop here, pick this up later, or when the agent is about to wait on a human or leave a run unattended. Does not trigger for writing a research subagent's brief (`zurdo-project`), for summarizing one run (`zurdo-state-summary`), or for editing `scope.md`.

### 5.2 `zurdo-wayfinder` — needed, and narrow

The user asked for the wayfinder only if needed. It is, for three measured reasons, and the alternatives are in §8.

1. **Orientation has two owners and they already disagree** (§3: two copies, one row missing). A read-only skill that owns the orientation algorithm gives it one home; `zurdo-project`'s table stays the action vocabulary, and the journey tree becomes a rendering of it.
2. **Nothing reads all six inputs** (§3). Rows 2 and 3 read files; row 4 reads one run; row 5 says claims live on GitHub. The wayfinder is the only surface whose job is to read all six and reconcile them.
3. **The handoff needs a reader that distrusts it.** A handoff is a claim about the past; the files are the truth. Putting the verification rules in `zurdo-project`'s runbook makes a doer skill depend on the handoff format and lengthens a skill whose `SKILL.md` already carries 16 inline rules. Putting them in the handoff skill makes a writer verify its own output. Neither is the reader's job.

And the wayfinder must work with zero handoffs present, which is the count in every repository today. It is not the handoff's reader; it is the initiative's reader, and the handoff is one of its inputs.

Delta against §2: absorbs rows 2 and 3 as the single owner of orientation, delegates to row 4 for the run tally, reads row 5's claims, and adds the handoff as a verified input.

**Posture.** Read-only. `allowed-tools: [Read, Grep, Glob, Bash]`, with Bash limited to reads: `git status`, `git log`, `zurdo state list`, `zurdo state where`, `gh issue view --json assignees`. It never writes a file, never runs a `zurdo-github.sh` mode, never starts or resumes `zurdo run`, never edits `scope.md`. It ends by naming the skill that acts.

**Inputs, in authority order.** When two disagree, the higher wins and the report says so.

| Rank | Input | Read how | Yields |
|---|---|---|---|
| 1 | `docs/<initiative>/scope.md` and `tickets/*.md` | Read | Destination, phase table, open and resolved tickets, blockers |
| 2 | `.zurdo/<slug>/prd.json` and `lock` for every PRD in the phase table | `zurdo state list`; invoke `zurdo-state-summary` when installed, else read `prd.json` by hand | Settled or in flight; task tally; the run-scoped next verb |
| 3 | Git | `git status --short`; `git log --since=<stopped_at> -- docs/<initiative>/ .zurdo/` | Dirty tree; every change since the handoff |
| 4 | `docs/<initiative>/handoff.md` | Read; verify (below) | The previous session's claim: station, in flight, waiting, next action |
| 5 | GitHub, read-only, optional | `gh issue view <n> --json assignees` for open tickets and the running epic's tasks | Who has claimed what; skipped with a stated reason when `gh` is absent or unauthenticated |

**Verifying the handoff.** The handoff is `fresh` when no commit touched `docs/<initiative>/` after the handoff commit and no `prd.json` in the phase table has `last_updated` after `stopped_at`. Otherwise it is `stale`; the report names what changed and re-derives station and next action from ranks 1 to 3, using the handoff only for In flight and Waiting on a human, both re-checked. A missing handoff is reported as `none`, not as an error.

**The situation report.** Fixed shape, matching `zurdo-state-summary`'s density:

```
Wayfinder — Observability export (docs/observability-export/)
Destination: CLI exports monitoring data to CSV and posts it to a configured webhook.

  phase-01  CSV export        running      prd-01-csv-export.md   settled: 4 passed · 1 pending-review
  phase-02  Webhook delivery  researching  —                      blocked by: Webhook retry policy (open)

You are here: Run and sync, phase-01.
Handoff: fresh — committed 3f2a9c1 at 2026-09-12T18:40Z; nothing under docs/observability-export/ or prd.json changed since.

In flight (re-checked)
  Webhook retry policy — still open; no ## Findings yet.

Waiting on a human
  zurdo review — one [manual] criterion on task-manifest.

Claimed
  none — gh read skipped: gh not on PATH.

Do not
  run sync-status until zurdo review closes the pending task.

Next action: row 8 — zurdo review, sync-status, scope, then zurdo-prd-review.
  Checked: no lock in .zurdo/prd-01-csv-export-a91c/; every task terminal-pass.
  First command: zurdo review docs/observability-export/prds/prd-01-csv-export.md
  Acts: you, in the zurdo review TUI; then zurdo-project.
```

A stale handoff changes two lines: `Handoff: stale — scope.md changed in 9a1b2c3 after the handoff; phase-02 is now ready` and a `Since the handoff` block listing the changes. A repository with no `scope.md` gets one block per PRD directory, and the next action is one of `zurdo-state-summary`'s six verbs instead of a row.

**Next action.** Exactly one. With an initiative present, it is a row of `zurdo-project`'s priority table (`references/runbook.md`, "Every later session"), cited by number and text, with the precondition that was checked and the first command. Without an initiative, it is one of `zurdo-state-summary`'s six verbs. Never a third vocabulary. The `Do not` block carries the checks that block the obvious move: a live `lock` forbids `sync-status`; an open grilling ticket forbids writing that phase's PRD; a dirty tree asks for a commit before any script mode; an open `Waiting on a human` item that only the user can clear is named as such.

When the runbook table and the wayfinder's mapping disagree, the runbook wins and the wayfinder's reference is what changes, the same rule `zurdo-domain` applies between glossary and code.

**Skill shape.** `skills/project-management/zurdo-wayfinder/`:

- `SKILL.md` — the authority ladder, the read-only posture, the freshness test, the one-action rule, the two vocabularies, the hand-to-the-acting-skill close, each as imperative + why + arrow.
- `references/inputs.md` — the five inputs, exact commands, what each proves and does not; the freshness test in full; the PRD-only degradation.
- `references/situation-report.md` — the shape above with the fresh, stale, and no-handoff variants worked.
- `references/next-action.md` — every runbook row with the check that selects it and the check that blocks it; the six run verbs for the PRD-only case; the `Do not` catalogue.

Frontmatter description: triggers when the user asks where an initiative or PRD stands, what this session should do, or to be caught up, and at the start of any session on an existing Zurdo initiative. Does not trigger to summarize one run in detail (`zurdo-state-summary`), to start or scope an initiative (`zurdo-project`), or to take the action it names.

### 5.3 How the two meet `zurdo-project`

A session becomes: orient with the wayfinder, act with `zurdo-project` and the skills it drives, stop with the handoff. The handoff's Next action is written in the row vocabulary the wayfinder reads back, so the loop closes on one table.

`zurdo-project` gains two optional rows in its dependency table, each with the inline fallback its policy requires: without `zurdo-wayfinder`, run steps 1 to 3 of "Every later session" by hand; without `zurdo-handoff`, write the seven headings by hand. Its "Stop here" and its later-session step 0 name the two skills. `runbook.md:181` says "note it in the handoff's Watch out". The journey guide's station 07 becomes a rendering of the ten rows, gaining the missing row 5 branch, and a station for the stop is added after it. `zurdo-project`'s `SKILL.md` gains one rule: **Orient before acting and hand off before stopping; the files are truth and the handoff is a hint.**

**Vocabulary.** New nouns this design sets, in `zurdo-domain`'s spirit; no `CONTEXT.md` exists in this repository yet (open question 3).

| Term | Means | Avoid |
|---|---|---|
| handoff | The file `docs/<initiative>/handoff.md`: a stopping session's claim about where it stopped and what one thing comes next | session notes, session summary, baton, checkpoint |
| stop point | One of the five moments a handoff is written | pause, break |
| next action | Exactly one row of `zurdo-project`'s priority table, or one of `zurdo-state-summary`'s six verbs | next steps, todo, plan |
| fresh, stale | A handoff no file has outrun; a handoff at least one file has outrun | valid, outdated, expired |
| wayfinder | The read-only skill that orients within an initiative; `scope.md` is the map it reads | navigator, status, orient |
| situation report | The wayfinder's fixed-shape output | summary, dashboard, status report |

`scope-map.md:3` already calls the scope model "wayfinding mechanics". That stays: the map's mechanics are what the wayfinder walks. The reader is the skill; the map is the file.

---

## 6. Affected areas

**New.**

```
skills/project-management/zurdo-handoff/
  SKILL.md
  references/record.md
  references/stop-points.md
  references/receivers.md
  examples/handoff.md
skills/project-management/zurdo-wayfinder/
  SKILL.md
  references/inputs.md
  references/situation-report.md
  references/next-action.md
docs/zurdo-handoff/prds/prd-01-zurdo-handoff-skill.md
docs/zurdo-wayfinder/prds/prd-01-zurdo-wayfinder-skill.md
```

**Edited.**

- `skills/project-management/zurdo-project/SKILL.md` — one inline rule (§5.3); the optional-skills line names both.
- `skills/project-management/zurdo-project/references/runbook.md` — two dependency rows; "Stop here" names `zurdo-handoff`; "Every later session" gains step 0 naming `zurdo-wayfinder`; line 181's "session summary" becomes the handoff's Watch out.
- `docs/guides/zurdo-github-journey.md` — station 07 tree gains row 5; a stop station follows it; line 520's "session notes" becomes the handoff.
- `README.md` — two skills-table rows, two subsections in the existing style, the layout tree.

**Untouched.** `zurdo-github` skill and `scripts/zurdo-github.sh`; every bundled skill under `.claude/skills/`; the `scope.md` and ticket formats; `skills-lock.json`.

---

## 7. Phases, with exit criteria

Each phase is one PRD authored with `zurdo-prd-author` and gated the way the sibling PRDs are: `file-exists`, `grep` of author-controlled strings, `[manual]` rubrics against the four authoring rules in `CLAUDE.md`, and a `no-grep` for placeholder markers. Phases A and B are independent and may run in either order; C depends on both.

| Phase | Ships | Exit criterion, observable | Depends on |
|---|---|---|---|
| A | `zurdo-handoff`: `SKILL.md`, three references, `examples/handoff.md`, README row | `grep: name: zurdo-handoff in skills/project-management/zurdo-handoff/SKILL.md`; the example carries all seven H2s (`grep: ## Waiting on a human`, `grep: ## Watch out`); every reference linked from SKILL.md | — |
| B | `zurdo-wayfinder`: `SKILL.md`, three references, README row | `grep: name: zurdo-wayfinder in skills/project-management/zurdo-wayfinder/SKILL.md`; `references/next-action.md` names all ten runbook rows and the six run verbs (`[manual]`); `allowed-tools` lists no Write or Edit (`no-grep: Write in …/SKILL.md` frontmatter, `[manual]`) | — |
| C | Integration: `zurdo-project` runbook and SKILL.md, journey guide, README layout | `grep: zurdo-handoff in skills/project-management/zurdo-project/references/runbook.md`; `grep: zurdo-wayfinder` in the same; `no-grep: session summary` in that runbook; `no-grep: session notes in docs/guides/zurdo-github-journey.md`; the station 07 tree carries a "start zurdo run" node (`grep`) | A, B |

Phase C's observable is the one that moves a measured number in §3: undefined session-end artifacts from 2 to 0, and journey-tree coverage of the runbook table from 9 rows to 10.

---

## 8. Considered and rejected

| Alternative | Rejected because |
|---|---|
| Fold orientation into `zurdo-project`'s runbook and ship no wayfinder | The runbook already shares orientation with the journey guide and the two copies differ by one row (§3). `zurdo-project` triggers on doing (start, scope, publish, review); "where are we" is a read, and a reader with Write in its toolset is one a human will not invoke on a live run. |
| Fold the wayfinder into `zurdo-handoff` as its "pick up" half | Different trigger (start vs. stop), different posture (read-only vs. writes and commits), and the wayfinder must work with zero handoffs, which is today's count everywhere. A skill that is half writer and half reader cannot promise read-only. |
| Extend `zurdo-state-summary` to initiative scope | Bundled with Zurdo, installed by `zurdo skills install`, not this repository's to edit. Run-scoped by its own text (`SKILL.md:10,17`), and that scoping is what makes it safe to delegate to. |
| `docs/<initiative>/handoffs/<timestamp>.md`, append-only | `git log -- handoff.md` already lists every version with author and date. A directory makes the reader choose, nothing consumes old entries, and a stale file that looks current is the failure the wayfinder exists to catch. |
| Project the handoff to GitHub (scope-issue comment or a README section) | Needs a new `zurdo-github.sh` mode and marker. The receiving agent reads the repository; the GitHub-only teammate already reads the board README that `scope` refreshes. Deferred with its instrument in open question 1. |
| Keep the handoff under `.zurdo/` | Slug-scoped, run state, partly gitignored. The handoff is initiative-scoped and must travel with the repository. |
| Add `## Handoff` as a seventh section of `scope.md` | The `scope` parser drops any H2 outside its six names (`sec = "other_" name`, `zurdo-github.sh:932`), so the section would sit in the file and never appear on GitHub; a reader of the projection would not know it exists. Promoting it to a known section instead renders a transient note onto the Project README on every run. Either way the map is the wrong home for a stop record. |
| Let the handoff write its own next-action wording | Two vocabularies exist (ten rows, six verbs). A third guarantees the wayfinder and the runbook disagree the way rows 2 and 3 already do. |
| A wayfinder that orients and then acts | Loses the read-only guarantee, and every action it would take already belongs to a named skill. Naming that skill is the handoff between them. |
| Make both skills required by `zurdo-project` | Violates its stated policy: required skills stop the run, optional ones degrade to an inline fallback and say so. Each must be installable alone. |

---

## 9. Open questions

1. **Should the handoff be projected to GitHub?** Answered by one sandbox week with a GitHub-only teammate: do they need Waiting on a human or Claimed beyond the board README? If yes, a `handoff` mode of `zurdo-github.sh` posting the record as an edited-in-place comment under marker `<!-- zurdo-github scope=<slug> handoff -->`. Not in v1.
2. **Is git-based freshness enough?** Another session's uncommitted edits on another machine are invisible until pushed, so a `fresh` verdict can be wrong. Answered by a two-session sandbox; the remedy would be an age ceiling in the wayfinder (a handoff older than N hours is reported `unverified`, not `fresh`), and N is the number to measure.
3. **Does this repository get a `CONTEXT.md`?** The table in §5.3 would seed it. Answered by `zurdo-domain`'s "every term must be used" test against `README.md` once phases A and B ship the surface that uses the terms.
4. **Should the wayfinder read GitHub at all?** Claims live only there, but the environments the skill runs in may lack `gh` or its auth. The design says optional with a stated skip; answered by whether the skip is the common case, in which case Claimed leaves the report.
5. **Where does the handoff live in a repository with several PRD directories and no `scope.md`?** The design says beside the `prds/` directory of the PRD the session stopped on, so this repository could hold one per `docs/<skill>/`. Answered by running the wayfinder against this repository during phase B: if one per directory reads badly, a single `docs/handoff.md` for the no-initiative case is the alternative.

---

## Amendment 2026-09-12

**Strikes** the sentence in §7 "Each phase is one PRD authored with `zurdo-prd-author`" and the frontmatter's `implementation: unshipped` with its `probe`/`scope` pair. **Restates**: the author asked for direct implementation, so phases A, B, and C were built by hand in one change, and the PRDs at `docs/zurdo-handoff/prds/prd-01-zurdo-handoff-skill.md` and `docs/zurdo-wayfinder/prds/prd-01-zurdo-wayfinder-skill.md` were written as the specification records the repository convention requires, not as run inputs; their criteria were checked by grep, not by `zurdo run`. The frontmatter moves to `shipped` in the same commit as the work, per the amend discipline. **Does not reopen**: any decision in §5, the rejected alternatives in §8, or the open questions in §9. The measurements in §3 stand as taken; phase C's observable moved as predicted (undefined session-end artifacts 2 → 0; journey-tree coverage of the runbook table 9 → 10 rows).
