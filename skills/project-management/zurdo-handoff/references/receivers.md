# receivers

Who picks up the handoff, what each needs from it, and which handoff shapes live elsewhere.

---

## The next session

The primary receiver. It may be the same agent, a different agent, or a different model, on the same machine or another. It reads the handoff through `zurdo-wayfinder` when that skill is installed, or by reading the file beside `scope.md` when it is not.

What it needs:

- **A verifiable claim, not a narrative.** `stopped_at` to the second, commit hashes, paths, and commands to re-check. The wayfinder marks the handoff `fresh` or `stale` by comparing `stopped_at` and the handoff commit against `git log` and every `prd.json` `last_updated`; a handoff without those anchors cannot be verified and is treated as stale.
- **One next action in the row vocabulary**, with its precondition. The receiver re-checks the precondition against the files and acts only when it holds. When it does not, the receiver picks the row that does hold and says the handoff was stale.
- **In flight, re-checkable.** Each entry names how to check. The receiver checks each before trusting anything downstream of it.
- **Watch out, with homes.** The receiver's first act after orienting is to move each homeless item to its home and commit.

What it does not need: a summary of the initiative (it has `scope.md`), a run tally (it has `prd.json` and `zurdo-state-summary`), or the reasoning behind decisions (it has the ticket files and the `.trail.md` sidecars).

---

## The user

The user reads Waiting on a human, and the one- or two-sentence closing message that quotes it.

What they need:

- **The question, with the ➡️ recommendation and its grounding**, in the format `zurdo-project`'s interview protocol uses. They arrive at the next session ready to answer.
- **The command only they can run**, with its path: `zurdo review docs/<initiative>/prds/prd-01-<phase>.md`, or the sandbox check named by its `[manual]` criterion text.
- **What follows once they act** — the Next action row, so they know what the agent will do with their answer.

What the handoff must not do for the user:

- **Answer a grilling question.** The agent never answers on the user's behalf; the recommendation is an input to a live interview, not a default that takes effect if the user stays silent.
- **Invite an answer by file edit.** A grilling ticket is resolved live, per `zurdo-project/references/interview.md`. If the user writes an answer into the ticket file themselves, the next session treats it as the user's recorded answer and runs the resolve steps; but the handoff does not propose that path.
- **Sign anything off.** `zurdo review` is the user's; the handoff only says it is due.

---

## A stopped skill chain

Several bundled skills end with a chat-only handoff: `zurdo-prd-author` reminds the user to commit the PRD, trail, and lessons; `zurdo-prd-review` names the scaffold and lesson files and says to review them in one commit; `zurdo-design-author` refers the human onward to `zurdo-prd-author`. When the session ends there, the chat message dies with it. The handoff gives the pointer a durable home.

| Chain stopped at | What Next action and In flight carry |
|---|---|
| `zurdo-prd-author` interview, mid-way | The session file `.zurdo/authoring/<session>.json`; the phase in `scope.md` by title; the command that reads it back (`scripts/session_tracker.py --action show --session-file <path>`), and the instruction to re-invoke `zurdo-prd-author` naming that file. Row 3. |
| `zurdo-prd-author` finished, `✓ READY TO RUN`, not committed | Under Uncommitted: the PRD, its `.trail.md`, any `lessons/` files. Next action: commit them in one commit, then row 4 (publish). |
| `zurdo-prd-review` gaps verdict | Under Uncommitted or Done: `<stem>-followup.md` and `lessons/` files. Waiting on a human: review them in one commit. Next action: row 9. |
| `zurdo-prd-review` landed verdict | Next action: row 10, the phase review interview; Waiting on a human names it as HITL. |
| `zurdo-design-author` record done | Done this session links `docs/<initiative>/design/<topic>.md`; Next action: row 3 with the record as the intent document. |
| `zurdo-hint-debugger` diagnosis made, fix not applied | Watch out carries the classification (A to F) and the proposed fix verbatim; Next action: row 7. |

Name the path and the command. The receiver should be able to resume without re-reading the skill that stopped.

---

## Who is not a receiver

**Research subagents.** Their brief is defined in `zurdo-project/references/research.md` ("Running research AFK"): the question verbatim, the destination file, the three deliverables. That is the one written handoff shape that predates this skill, and it stays where it is. The handoff records under In flight that a subagent was dispatched and how to check it; it does not carry the brief.

**GitHub readers.** The handoff is not projected. A teammate who reads only GitHub reads the board README, the scope issue, and the ticket issues, all refreshed by `zurdo-github.sh scope`. If a stop leaves something a GitHub-only reader must know, it belongs in `scope.md` (and therefore on the board), not in the handoff.

**Zurdo itself.** `zurdo run` reads the PRD and `.zurdo/<slug>/`; it never reads the handoff. Do not put run configuration or task instructions in it.

---

## When the receiver finds no handoff

A missing handoff is not an error. Every initiative had zero handoffs before its first stop, and any initiative may be resumed by someone who never wrote one. `zurdo-wayfinder` reports `Handoff: none` and orients from the files alone. The first handoff is written at that session's stop.
