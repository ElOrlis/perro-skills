---
name: zurdo-handoff
description: >
  Triggers when a session working a Zurdo initiative or PRD is ending or pausing: the user says
  hand off, stop here, pick this up later, or wrap up; the agent is about to wait on a human
  (a grilling question, `zurdo review`, a manual check); the agent is leaving `zurdo run` or
  research subagents unattended; or the context window is near its limit. Does NOT trigger for
  writing a research subagent's brief (zurdo-project), for summarizing one run's state
  (zurdo-state-summary), or for editing `scope.md`.
---

# zurdo-handoff

Leave one file behind when a session stops before the initiative does: `docs/<initiative>/handoff.md`, seven fixed sections, exactly one next action, committed as the session's last act. The next session, the user, or a stopped skill chain picks it up without re-deriving where things stand.

## Stop points

Write the handoff at one of these moments, and only then:

1. **The runbook's stop** — one session's worth is done (`zurdo-project` says "Stop here": scoped, researched, one PRD published, `zurdo run` not started).
2. **Before a blocking wait on a human** — a grilling question is asked and unanswered, `zurdo review` is due, a `[manual]` sandbox check is the author's, a commit awaits review.
3. **Before leaving an AFK step running** — `zurdo run` started, research subagents dispatched.
4. **The user says stop**, pause, hand off, pick this up later; or the context window is near its limit.
5. **A station finished and the next belongs to another actor or skill** — a design record is done and `zurdo-prd-author` is next session's work; `zurdo-prd-review` scaffolded a follow-up that is not yet committed.

## Decision Rules

**The files are truth; the handoff is a hint. Nothing durable lives only in the handoff.**
A decision belongs in `scope.md` Decisions so far, a correction in `lessons/` through `zurdo-lessons`, a fact in `scope.md` Notes, a run outcome in `prd.json`. The handoff names any item that has not reached its home yet and says where it goes; the receiver moves it first.
→ see references/record.md

**One file per initiative at `docs/<initiative>/handoff.md`; overwrite, never append.**
Git holds every version with author and date (`git log -- handoff.md`). A directory of dated files makes the reader pick one, and a stale file that looks current is the failure the receiver exists to catch.
→ see references/record.md

**Seven sections, fixed order, every one present; an empty section says `None.`**
Stopped at, Done this session, In flight, Waiting on a human, Next action, Uncommitted, Watch out. The receiver keys on the headings; a missing heading reads as an unknown, not as an empty set.
→ see references/record.md

**Exactly one next action, as a row of `zurdo-project`'s priority table or one of `zurdo-state-summary`'s six verbs; never a third vocabulary.**
Two vocabularies already exist for "what next"; a third guarantees disagreement. Cite the row number and its text, then the precondition the receiver must re-check before acting.
→ see references/record.md

**Commit is the last act; push when a remote exists.**
A handoff on disk but not in git is invisible to the next machine and to `git log`. The handoff commit is the session's boundary: `handoff: <initiative> — <next action>`.
→ see references/stop-points.md

**Never hand off a dirty tree silently; commit it, or list every path under Uncommitted.**
An uncommitted edit the receiver does not know about is state discovered by accident, usually after it has been overwritten.
→ see references/stop-points.md

**Waiting on a human carries the question and its ➡️ recommendation; it opens no new way to answer.**
The user arrives prepared. A grilling ticket is still resolved live per `zurdo-project`'s interview protocol; the handoff does not let the agent answer it and does not invite an answer by file edit.
→ see references/receivers.md

**In flight names every unattended process and how to check it; the receiver re-checks each before trusting it.**
A dispatched subagent may have resolved its ticket; a `zurdo run` may have finished or crashed. The handoff records what was set running; the files say what happened.
→ see references/receivers.md

**Refer by name: tickets and phases by title, commits by hash, numbers inside links.**
Titles are meaning; numbers are routing. The receiver reads the handoff next to `scope.md`, where the same titles appear.
→ see references/record.md

**Point a stopped skill chain at its resumable state.**
A paused `zurdo-prd-author` interview lives in `.zurdo/authoring/<session>.json`; a `zurdo-prd-review` gaps verdict leaves `<stem>-followup.md` and `lessons/` files awaiting one commit. Name the path and the command that resumes it.
→ see references/receivers.md

## The record

```markdown
---
initiative: <directory name holding scope.md, or prds/>
stopped_at: <UTC ISO-8601>
station: scope | research | phase-prd | publish | run-and-sync | phase-review
phase: phase-NN
by: agent | user
---

# Handoff: <Initiative title>

## Stopped at
## Done this session
## In flight
## Waiting on a human
## Next action
## Uncommitted
## Watch out
```

Full template, per-section rules, and what never goes in: → see references/record.md. A complete example for the initiative that `zurdo-project/examples/scope.md` describes: [examples/handoff.md](examples/handoff.md).

## Files

```
docs/<initiative>/
  scope.md                 # the map; zurdo-project owns it
  handoff.md               # this skill's one file; overwritten at every stop
  tickets/, prds/, design/ # unchanged
```

In a repository without `scope.md`, `<initiative>` is the directory holding the `prds/` folder of the PRD the session stopped on (`docs/zurdo-project/handoff.md`, for example).

## Commit sequence

```bash
git status --short                                  # what goes under Uncommitted, or Clean.
$EDITOR docs/<initiative>/handoff.md                # write the seven sections
git add docs/<initiative>/handoff.md
git commit -m "handoff: <initiative> — <next action, one line>"
git push                                            # when a remote exists
```

## References

- [references/record.md](references/record.md) — The template, the per-section table, the graduation rule, what never goes in, placement in a PRD-only repository.
- [references/stop-points.md](references/stop-points.md) — The five stop points in depth, the commit-is-the-last-act rule, the human-wait stop, the AFK stop, what to tell the user.
- [references/receivers.md](references/receivers.md) — What each receiver needs: the next session (through `zurdo-wayfinder` or by reading), the user, a stopped skill chain; why the subagent brief lives in `zurdo-project` and is cited, not copied.

## Examples

- [examples/handoff.md](examples/handoff.md) — A complete handoff for the example initiative, stopped at Run and sync with one human wait open.
