---
name: zurdo-wayfinder
description: >
  Triggers when the user asks where a Zurdo initiative or PRD stands, what this session should do,
  or to be caught up, and at the start of any session that resumes an existing initiative under
  `docs/<initiative>/scope.md` or a PRD with run state under `.zurdo/`. Does NOT trigger to
  summarize one run in detail (zurdo-state-summary), to start or scope a new initiative
  (zurdo-project), or to take the action it names. Read-only: it never edits a file, never runs a
  `zurdo-github.sh` mode, never starts `zurdo run`.
allowed-tools: [Read, Grep, Glob, Bash]
---

# zurdo-wayfinder

Orient a session inside an initiative and name one next action, without changing anything. Read five inputs in authority order, verify the previous session's handoff against the files, emit a fixed-shape situation report, and end by naming the skill that acts.

## Procedure

1. **Locate the initiative.** `docs/*/scope.md`; if the user named one, that one. None found → PRD-only mode: every `docs/*/prds/*.md` with a matching `.zurdo/<basename>-*/` directory.
2. **Read the map.** `scope.md` (Destination, Phases table, Not yet specified) and every `tickets/*.md` frontmatter (`type`, `status`, `blocks`).
3. **Read run state** for every PRD in the Phases table: `zurdo state list` when `zurdo` is on `PATH`, else glob `.zurdo/*/prd.json`; note `lock` files. Invoke `zurdo-state-summary` when installed for the tally and the run-scoped verb; else tally `tasks.*.status` by hand.
4. **Read git.** `git status --short`; when a handoff exists, `git log --oneline --since=<stopped_at> -- docs/<initiative>/ .zurdo/`.
5. **Read and verify the handoff** at `docs/<initiative>/handoff.md`: `fresh`, `stale`, or `none` (rule below).
6. **Read claims**, optionally: `gh issue view <n> --json assignees` for open tickets and the running epic's tasks; skip with a stated reason when `gh` is absent or unauthenticated.
7. **Compose the report** in the fixed shape. Pick exactly one next action. Name the skill that acts. Stop.

## Decision Rules

**Files outrank run state, run state outranks git, git outranks the handoff, the handoff outranks GitHub; when two disagree the higher wins and the report says so.**
`scope.md` and the ticket files are the source of truth; `prd.json` is Zurdo's; the handoff is one session's claim; GitHub is a projection. A report that averages them hides the disagreement the reader most needs.
→ see references/inputs.md

**Read only. Never write a file, run a script mode, start a run, or edit `scope.md`.**
A read-only skill is the one a human can invoke on a live run without fear. Every action the wayfinder could take already belongs to a named skill; naming it is the handoff between them.
→ see references/inputs.md

**A handoff is `fresh` when no commit touched `docs/<initiative>/` after the handoff commit and no `prd.json` in the Phases table has `last_updated` after `stopped_at`; otherwise `stale`; absent is `none`, not an error.**
A stale handoff still carries In flight and Waiting on a human, both re-checked; its station and Next action are re-derived from the files. Missing is the normal state of every initiative before its first stop.
→ see references/inputs.md

**Re-check every In flight entry before trusting anything downstream of it.**
A dispatched subagent may have resolved its ticket; a run may have finished or crashed. The handoff says what was set running; `status:` in the ticket file and `prd.json` say what happened.
→ see references/inputs.md

**Exactly one next action: a row of `zurdo-project`'s priority table when an initiative exists, one of `zurdo-state-summary`'s six verbs in PRD-only mode; never a third vocabulary.**
Two vocabularies already exist for "what next". Cite the row by number and text, the precondition that was checked, and the first command. When the runbook table and this skill's mapping disagree, the runbook wins and this skill's reference is what changes.
→ see references/next-action.md

**Grilling first: an open grilling ticket is row 1 whenever the user is present, and a `Waiting on a human` line when they are not.**
It is the only branch that needs the user; everything else can wait for them, and nothing else can substitute for them.
→ see references/next-action.md

**Never name `sync-status` while a `lock` exists; never name PRD authoring for a phase with an open blocking ticket; never name a script mode over a dirty tree without a commit first.**
These are the three moves a hurried session makes and regrets. They go under `Do not` in the report, each with the fact that blocks it.
→ see references/next-action.md

**The report has a fixed shape and `zurdo-state-summary`'s density: enough to act on, short enough to read in one sitting.**
The reader keys on the same headings every time; prose that varies by session forces a re-read.
→ see references/situation-report.md

**End by naming the skill that acts, and the human when the first step is theirs.**
`zurdo-project` for any row; `zurdo-prd-author` for row 3; `zurdo-hint-debugger` for row 7; `zurdo-prd-review` for row 8's last step; the user for `zurdo review` and grilling answers. The wayfinder's last line is a handoff, not a plan.
→ see references/next-action.md

**PRD-only repositories get one block per PRD directory and the run-scoped verb as the next action.**
No `scope.md` means no Phases table and no rows; `zurdo-state-summary`'s verbs (resume, fix-then-resume, heal, verify, reset, review) are the vocabulary that fits.
→ see references/next-action.md

## The report

```
Wayfinder — <Initiative title> (docs/<initiative>/)
Destination: <first sentence of ## Destination>

  <phase-NN>  <title>  <status>  <prd basename or —>  <run: settled tally | in flight | no run | blocked by: <ticket title> (open)>

You are here: <Station>, <phase-NN>.
Handoff: fresh | stale — <what changed> | none.
Since the handoff: <commits and prd.json changes, or nothing>   (stale only)

In flight (re-checked)
Waiting on a human
Claimed
Do not

Next action: row <n> — <row text>.
  Checked: <the precondition, as observed>
  First command: <one command>
  Acts: <skill or person>
```

Worked fresh, stale, and no-handoff variants: → see references/situation-report.md.

## Read-only command set

```bash
git status --short
git log --oneline --since=<stopped_at> -- docs/<initiative>/ .zurdo/
zurdo state list                       # or: ls .zurdo/*/prd.json .zurdo/*/lock
gh issue view <n> --json assignees     # optional; skip with a reason when unavailable
```

Nothing else. No `zurdo-github.sh`, no `zurdo run`, no `git commit`, no `gh issue edit`.

## References

- [references/inputs.md](references/inputs.md) — The five inputs, exact commands, what each proves and does not; the freshness test in full; delegation to `zurdo-state-summary`; the PRD-only degradation.
- [references/situation-report.md](references/situation-report.md) — The report shape, with fresh, stale, no-handoff, and PRD-only variants worked.
- [references/next-action.md](references/next-action.md) — Every `zurdo-project` priority row with the check that selects it and the check that blocks it; the six run verbs; the `Do not` catalogue; who acts.
