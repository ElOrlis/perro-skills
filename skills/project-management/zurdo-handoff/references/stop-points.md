# stop-points

When a handoff is written, what each stop point puts in the record, and the commit that ends the session.

---

## The five stop points

A handoff is written at one of these moments and at no other. Writing one mid-station, with nothing settled, produces a record whose Next action is a guess.

### 1. The runbook's stop

`zurdo-project`'s first session ends after one session's worth: scoped, researched, one PRD authored and published if phase-01 was `ready`, and `zurdo run` **not** started. Every later session ends when its one action from the priority table is complete and its `scope` refresh has run.

What the record carries: Stopped at names the station just completed; Done this session lists the files written and the script modes run with their commit hashes; Next action is the row the priority table would pick now (usually row 5, start `zurdo run`, after a publish); In flight lists any research subagents dispatched.

### 2. Before a blocking wait on a human

The agent has reached a gate only the user can clear:

- A grilling question has been put to the user and not answered in this session.
- Every task is `passed` or `passed-pending-review` and `zurdo review` must sign off `[manual]` criteria.
- A `[manual]` criterion names the author (a live sandbox check, a UI inspection).
- The PRD, trail, and lessons are committed and await the human review gate before publish.

What the record carries: Waiting on a human names the gate, the question with its ➡️ recommendation, or the command and the PRD path; Next action is the row that follows once the gate clears, with "after the human step" as its precondition; Stopped at says what is applied up to the gate.

Tell the user, in the closing message, exactly what Waiting on a human says, in one or two sentences. The file is the record; the message is the notice.

### 3. Before leaving an AFK step running

`zurdo run` has started, or research subagents have been dispatched, and the session will not be present when they finish.

What the record carries: In flight names each process, when it started, and how to check it:

- `zurdo run` — the slug directory (`.zurdo/<slug>/`), the check (`zurdo state list`, or `zurdo-state-summary`), and the rule that `sync-status` must not run while `lock` exists.
- A research subagent — the ticket by title, the dispatch time, and the check (`status:` in the ticket file; the subagent runs `ticket` itself, so the GitHub issue closes on its own).

Next action is row 6 (wait) when only `zurdo run` is in flight, or row 2 (absorb a resolved research ticket) when subagents may have landed. Name both conditions; the receiver checks which holds.

### 4. The user says stop, or the context is near its limit

Stop where you are, but finish the write in progress: never leave a half-edited `scope.md` or ticket file. Then write the handoff.

What the record carries: Stopped at is precise about what is applied and what is not ("`scope.md` phase-02 row flipped to `ready`; `scope` refresh not run"); Uncommitted lists every path if a commit is not possible; Next action is the smallest step that completes the interrupted station, cited as its row.

A context limit is the one stop where Watch out is likely to be long: everything learned this session that has not reached its home. Name each home.

### 5. A station finished and the next belongs to someone else

- A design record is done; `zurdo-prd-author` is the next session's work.
- `zurdo-prd-review` returned a gaps verdict and scaffolded `<stem>-followup.md` plus `lessons/` files; the human must review them in one commit before `publish --scope <n>`.
- A phase review ended by naming the next `ready` phase; authoring it is a fresh session.

What the record carries: Next action names the row and the skill that acts; Waiting on a human names the review gate when one exists; Done this session links the artifacts by path.

---

## Commit is the last act

```bash
git status --short                                   # 1. see what is dirty
# commit real work first, in its own commits
git add docs/<initiative>/handoff.md                 # 2. the handoff alone
git commit -m "handoff: <initiative> — <next action>"
git push                                             # 3. when a remote exists
```

Rules:

- **Real work gets its own commits.** The handoff commit contains only `handoff.md`. A handoff commit that also carries a PRD edit hides the edit under a boundary marker.
- **The message names the next action** so `git log --oneline -- docs/<initiative>/handoff.md` reads as the initiative's session history.
- **Push when a remote exists.** Another machine or another agent reads the remote, not your working tree.
- **When a commit is impossible** (no permission, mid-merge, the user asked for no commits), write the file anyway and put the full `git status --short` under Uncommitted. The next session's first act is to commit or discard, knowingly.

---

## Dirty trees

`Uncommitted` is verbatim `git status --short`, or `Clean.` Never summarize it ("a few doc edits"). Never omit it. If the tree is dirty because a `zurdo run` is in flight and writing, say so in the same section: "dirty from the in-flight run; do not commit `.zurdo/` until it settles."

---

## What to tell the user

The closing message after a handoff is short and names three things:

1. Where it stopped (Stopped at, one line).
2. What is waiting on them, if anything (Waiting on a human, verbatim).
3. The next action, as the row text, and that the handoff is committed at `docs/<initiative>/handoff.md`.

Do not restate Done this session; the commits are the record. Do not restate Watch out; the receiver reads it.

---

## Overwrite, never append

Each stop rewrites the whole file. Do not keep a log of previous stops inside it; `git log -p -- docs/<initiative>/handoff.md` is that log. A Watch out item that is still homeless carries forward by being rewritten into the new file, not by surviving in an old block.
