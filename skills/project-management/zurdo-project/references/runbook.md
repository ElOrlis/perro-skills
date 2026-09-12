# runbook

Preconditions, dependency detection, and the operator's sequence for running a zurdo-project lifecycle end-to-end.

---

## Dependency table

Verify every row before the first command. Required dependencies that are missing stop the run immediately with the error described below. Optional dependencies degrade gracefully.

| Skill or tool | Required or optional | How detected | Fallback |
|---|---|---|---|
| `gh` (GitHub CLI) with `repo` scope | Required — stop | `command -v gh` + `gh auth status` | None. Install from <https://cli.github.com> and run `gh auth login --scopes repo`. |
| `gh` with `project` scope | Optional — needed for board commands | `gh auth status` output lists `project` | Skip `board` commands; track milestones by label instead. |
| `jq` | Required — stop | `command -v jq` | None. Install via the system package manager. |
| `zurdo` | Required — stop | `command -v zurdo` | None. See the Zurdo install docs for your environment. |
| `zurdo-github` skill and script | Required — stop | Skill present in agent's skill list **and** `scripts/zurdo-github.sh` exists inside that skill's directory | None. Install the `zurdo-github` skill from perro-skills next to this one; it is not a Zurdo-bundled skill. |
| `zurdo-prd-author` | Required — stop | Skill present in agent's skill list | None. Run `zurdo skills install zurdo-prd-author`. It is the single PRD authoring entry point (decomposition, §2.2 grammar, criteria forcing, and pre-run review in one interview); a phase PRD cannot be written or reviewed without it. |
| `zurdo-lessons` | Required — stop | Skill present in agent's skill list | None. `zurdo-prd-author` calls it by name in its review phase and stops when it cannot resolve. Run `zurdo skills install --all` (installs every bundled skill). |
| `zurdo-domain` | Required — stop | Skill present in agent's skill list | None. `zurdo-prd-author` and `zurdo-prd-review` call it by name to word requirements and lessons in the project's governed nouns. Run `zurdo skills install zurdo-domain`. If the project has no `CONTEXT.md` glossary yet, the skill creates one; note that in `scope.md` Notes. |
| `zurdo-prd-review` | Optional — recommended | Skill present in agent's skill list | Run the phase review interview against `prd.json` statuses and `git diff` alone, and say in the review notes that no intent-level review ran. |
| `zurdo-design-author` | Optional | Skill present in agent's skill list | Record the adjudication as a research ticket's `## Findings` with the measurements inline; skip the `implementation:` frontmatter. |
| `zurdo-state-summary` | Optional | Skill present in agent's skill list | Read `.zurdo/<slug>/prd.json` and `progress.log` by hand to tally task statuses before `sync-status`. |
| `zurdo-hint-debugger` | Optional | Skill present in agent's skill list | Read the failing criterion's `.zurdo/<slug>/iterations/*.out` and `.err` captures by hand. |
| `grilling` or `grill-me` | Optional | Skill present in agent's skill list (either name) | Use the inline interview protocol from `references/interview.md`. |
| `zurdo-wayfinder` | Optional — recommended | Skill present in agent's skill list | Run steps 1 to 3 of "Every later session" by hand: read `scope.md`, `scope --dry-run`, pick the row; read `docs/<initiative>/handoff.md` if present and check its `stopped_at` against `git log` and `prd.json` before trusting its next action. |
| `zurdo-handoff` | Optional — recommended | Skill present in agent's skill list | At every stop, write `docs/<initiative>/handoff.md` by hand with its seven headings (Stopped at, Done this session, In flight, Waiting on a human, Next action, Uncommitted, Watch out) and commit it as the session's last commit. |

### Stop message for a missing required skill

When a required skill is missing, output exactly this (substituting the skill name) and exit:

```
Required skill `zurdo-prd-author` is not installed. Run:
  zurdo skills install zurdo-prd-author
Then restart this session.
```

Do not proceed past the dependency check when any required item is absent. `zurdo skills install --all` installs every bundled skill in one shot and is the simplest way to satisfy every `zurdo-*` row.

---

## First session — charting

Run these steps once, at initiative start. Stop after step 9 even if more work is visible.

1. **Destination interview** — ask the opening question: "What are we trying to produce or change, and how will we know it's done?" Run frontier rounds until the destination fits in one or two sentences naming what done looks like from the outside. Write nothing to disk until the destination is locked.

2. **Breadth interview** — ask: "Starting from the destination, what are the major phases of work, and what do you already know is unclear or risky?" Classify every named area as a phase, a sharp ticket, or fog. Do not recurse into any single phase. Do not resolve any open ticket in this session.

3. **Write `scope.md`** — create `docs/<initiative>/scope.md` with all six sections: Destination, Notes, Decisions so far (empty), Phases table (phase-01 and any sharply-scoped later phases), Not yet specified (fog items), Out of scope. Set each phase status: `ready` if no blockers, `researching` if a ticket blocks it, `planned` if scope is still foggy.

4. **Open tickets** — for each sharp question, create the ticket file at `docs/<initiative>/tickets/<name>.md` with frontmatter `type`, `status: open`, and `blocks` list. Open one grilling ticket maximum per session.

5. **Preview the scope projection**:

   ```bash
   zurdo-github.sh scope --dry-run docs/<initiative>/scope.md
   ```

   Read the full plan against the checklist in "Reading a scope dry-run plan": the initiative title, the Phases table, one `gh issue create` per ticket file with its `zurdo:research` or `zurdo:grilling` label, a comment-and-close pair for every resolved ticket, a `defer:` line for every `blocks` entry whose phase has no epic yet, and the `gh project edit` payload (description one-liner, README body).

6. **Create the scope issue, the ticket issues, and the Project**:

   ```bash
   zurdo-github.sh scope docs/<initiative>/scope.md
   ```

   One run does all of it: `scope` sweeps every file under `tickets/` after the scope issue exists. Read the summary: `tickets: created=` must equal the number of ticket files, `edges: mode=` says whether native edges were wired, and `project:` names the board or says `skipped`.

7. **Refresh one ticket later** with `zurdo-github.sh ticket --dry-run docs/<initiative>/tickets/<name>.md`, then the live call. Use it when a single ticket resolves between `scope` runs. It needs the scope issue to exist (exit 3 with `run scope first` otherwise) and wires no edges; the next `scope` run does that.

8. **Fire research subagents** — for each open research ticket, dispatch a subagent to fetch and synthesize. Research tickets may run in parallel. Do not wait for them to finish before stopping the session; they resolve asynchronously and their findings are written into the ticket file.

9. **If phase-01 is `ready`** — invoke `zurdo-prd-author` to author the PRD (its interview ends with the review verdict; stop only on `✓ READY TO RUN`), commit the PRD with its `.trail.md` sidecar and any `lessons/` files, then publish (see the publish sequence in the later-session section). Stop after publishing; do not start Zurdo in this same session.

**Stop here.** One session's worth of work is: scoped, researched, one PRD authored and published (if phase-01 was ready). Do not graduate additional phases in the first session.

10. **Hand off** — invoke `zurdo-handoff` (fallback: the seven headings by hand) to write `docs/<initiative>/handoff.md` naming the station, the dispatched research subagents under In flight, and the next action as its row from the later-session table (row 5, start `zurdo run`, after a publish). Commit it alone as the session's last commit.

---

## Every later session

At the start of each subsequent session, orient before acting.

0. **Orient** — invoke `zurdo-wayfinder` when installed. It reads `scope.md`, the tickets, every `prd.json`, git, and `docs/<initiative>/handoff.md`, marks the handoff `fresh`, `stale`, or `none`, and names one row from the table in step 3 with the precondition it checked. Read its report, then continue from the row it names. Without it, run steps 1 to 3 by hand and treat the handoff's Next action as a hint to re-check, never as an instruction.

1. **Read `scope.md`** — check current phase statuses and open tickets.

2. **Preview the projection**:

   ```bash
   zurdo-github.sh scope --dry-run docs/<initiative>/scope.md
   ```

   Read the plan: it confirms the files parse and shows the ticket set and the deferred edges. It does not show divergence; that appears only in a live run's summary (see "Reading a scope dry-run plan").

3. **Pick the next action** in this priority order:

   | Priority | Condition | Action |
   |---|---|---|
   | 1 | An open grilling ticket exists | Claim it, interview the user, record the answer verbatim under `## Findings`, flip `status: resolved`, run `ticket <file>`, update `scope.md`, run `scope`. |
   | 2 | A research ticket file is `resolved` but `scope.md` does not reflect it yet | Read its `## Findings` and `## Follow-ups`; add the Decisions line or graduate the fog; flip the blocked phase to `ready` when no blocker remains; ticket any follow-up that is sharp, fog the rest; run `scope`. The subagent already ran `ticket`; do not re-resolve. |
   | 3 | A phase is `ready` and no PRD exists for it | Author the PRD (invoke `zurdo-prd-author`; it decomposes, writes, forces criteria, and reviews in one interview), then commit the PRD, its `.trail.md` sidecar, and any `lessons/` files. |
   | 4 | A PRD exists and the phase is `ready` | Publish (see sequence below), flip phase to `running` in `scope.md`, run `scope`. |
   | 5 | A phase is `running` and no `.zurdo/<prd-basename>-*/` directory exists | Start `zurdo run` on the phase PRD. Nothing else this session; sync only after the run settles. |
   | 6 | A phase is `running` and `zurdo run` is in flight (live lock or in-flight iteration per `zurdo-state-summary`) | Wait. Do not run `sync-status` against a live run. |
   | 7 | A phase is `running` and `zurdo run` finished with `failed` or `blocked-by-dependency` tasks | Invoke `zurdo-hint-debugger` on each failing criterion; fix the hint or the code; `zurdo run --resume`. Run `sync-status` first so GitHub shows the failures meanwhile. |
   | 8 | A phase is `running` and the run is settled with every task `passed` or `passed-pending-review` | Invoke `zurdo-state-summary` to confirm it is settled, run `sync-status`, run `zurdo review` for any `[manual]` criteria and `sync-status` again, refresh `scope`, then invoke `zurdo-prd-review`. |
   | 9 | `zurdo-prd-review` returned a gaps verdict | Commit the follow-up PRD and any `lessons/` files, publish it with `--scope <n>`, run it, `sync-status`; the phase stays `running` until the follow-up is green. |
   | 10 | `zurdo-prd-review` returned landed-as-intended | Begin the phase review interview; update `scope.md`; graduate the next phase if one becomes ready; run `scope`. |

4. **Hand off** — when the row's action is complete, or before waiting on the user or leaving `zurdo run` unattended, invoke `zurdo-handoff` to write `docs/<initiative>/handoff.md` and commit it as the session's last commit. Its Next action is the row this table would pick now.

### Publish sequence

Run in order; always `--dry-run` first.

```bash
PRD=docs/<initiative>/prds/prd-NN-<phase>.md

# Once per repo, before the first publish; safe to repeat
zurdo-github.sh bootstrap --dry-run $PRD
zurdo-github.sh bootstrap $PRD

zurdo-github.sh publish --dry-run --scope <n> $PRD
zurdo-github.sh publish --scope <n> $PRD

# Board enrollment (optional, needs the project scope); pass the initiative title
zurdo-github.sh board --project "<initiative title>" --dry-run $PRD
zurdo-github.sh board --project "<initiative title>" $PRD

# Flip the phase row to running in scope.md, then refresh the projections
zurdo-github.sh scope --dry-run docs/<initiative>/scope.md
zurdo-github.sh scope docs/<initiative>/scope.md
```

Flip the phase row to `Status: running` in `scope.md` after `publish --scope <n>` succeeds and before the `scope` refresh.

### Sync-status sequence

```bash
PRD=docs/<initiative>/prds/prd-NN-<phase>.md

zurdo run

# Confirm the run is settled before syncing (invoke zurdo-state-summary, or read prd.json by hand)

zurdo-github.sh sync-status --dry-run $PRD
zurdo-github.sh sync-status $PRD

# Sign off [manual] criteria, then sync again so pending tasks close
zurdo review
zurdo-github.sh sync-status $PRD

# After sync, also refresh the scope issue
zurdo-github.sh scope --dry-run docs/<initiative>/scope.md
zurdo-github.sh scope docs/<initiative>/scope.md
```

---

## Reading a scope dry-run plan

Before any live run, read the full dry-run output and check these items:

| Item | What to check |
|---|---|
| Parse | A plan printed at all. A `PARSE ERROR:` line with exit 2 means a bad H1, a phase Status outside `planned\|researching\|ready\|running\|done`, or a ticket `type` or `status` outside its enum; fix the file first. |
| Ticket count | One `gh issue create` carrying `zurdo:research` or `zurdo:grilling` per file under `tickets/`. A mismatch means a file was added, removed, or failed to parse. |
| Resolved tickets planned to close | Each `status: resolved` ticket shows a `gh issue comment` followed by a `gh issue close`. If one is missing, its frontmatter was not flipped. |
| Deferred edges named | A `defer: phase-NN has no epic yet` line for every `blocks` entry whose phase is unpublished. A `blocks` entry naming a phase absent from the Phases table also defers; add the row or fix the ticket. |
| Project payload | The `gh project edit` line carries a one-line description and the README body. The dry-run always shows the Project step because it assumes the `project` scope is present; a live run prints `skip: project scope missing, run gh auth refresh -s project` instead when it is not. |

What the dry-run cannot show: every lookup is assumed not-found, so every issue appears as a create, never an update, and no `divergence:` line is possible. Those appear only in the live run's summary. Stop and investigate any unexpected line in either output before proceeding.

---

## Board step

The board step is optional and runs last in each publish sequence.

```bash
zurdo-github.sh board --project "<initiative title>" --dry-run docs/<initiative>/prds/prd-NN-<phase>.md
zurdo-github.sh board --project "<initiative title>" docs/<initiative>/prds/prd-NN-<phase>.md
```

**Requires the `project` scope** on the `gh` auth token. If the scope is absent, skip the board step and note it under Watch out in the handoff (`zurdo-handoff`), naming `scope.md` Notes as its home. The board is a convenience surface; its absence does not block Zurdo execution.

Run the board command after each successful publish, not before. The board enrolls already-published milestones and epics — running it before publish leaves gaps.

**Project-to-repo link.** Projects v2 projects are owned by the user or org, not the repo. Both `scope` and `board` link the project to the target repository immediately after creating it, so it appears under the repo's **Projects** tab and issues can be added from the sidebar. Verify the link in the sandbox check below; if the Projects tab is empty, re-run `scope` (the link call is idempotent).

**Project description and README.** Only `scope` writes them: the description is the Destination paragraph and the README is the scope body. `board` leaves both alone. After any `scope.md` edit that touches the Destination, the phase table, or a decision, re-run `scope` so the board's front page catches up; do not patch the fields in the GitHub UI.

---

## Failure handling

`zurdo-github.sh` exits with one of four codes.

| Exit code | Meaning | What to do |
|---|---|---|
| `0` | Success; plan applied without errors. | Continue to the next step. |
| `2` | Usage or parse error: unknown mode, missing path, unknown flag, or a `PARSE ERROR:` from the scope, ticket, or PRD parser naming the offending line. | Fix the invocation or the line; re-run. |
| `3` | Auth or capability error: no origin remote and no `--repo`, `project` scope missing for `board`, or `run scope first` because the scope issue does not exist yet. | Run the named fix: `--repo owner/name`, `gh auth refresh -s project`, or `scope` before `ticket` and `publish --scope`. |
| `1` | Anything else: a `gh` call failed, or `sync-status` found no `.zurdo/<prd-basename>-*/` directory or no `prd.json` in it. | Check `gh auth status` and the network; for `sync-status`, confirm the PRD path matches the run or pass `--slug`. |

The table is the script's own usage text; there is no marker database and no separate precondition code. Markers live in issue bodies, and `bootstrap` only creates labels.

### Divergence lines in live output

A `divergence: <name> closed on GitHub but open in file` line names a ticket issue someone closed by hand while its file still says `status: open`. It appears only in live runs; the dry-run assumes every issue is new. Do not ignore it. Before the next run:

- If the divergence is expected (another session already applied the change), update `scope.md` to match and re-run `--dry-run` until the line disappears.
- If the divergence is unexpected, investigate the GitHub issue history before proceeding; do not overwrite state you did not create.

### Missing required skill discovered mid-lifecycle

If a required skill disappears after the lifecycle has started (e.g. `zurdo-prd-author` is uninstalled between sessions):

1. Stop all in-progress work immediately.
2. Do not write any PRD file or run any publish command.
3. Output the stop message (see Dependency table) naming the missing skill and its install command.
4. Reinstall the skill, verify it appears in the skill list, and re-enter the session from step 1 of the current session's sequence.

---

## Sandbox verification

Use a throwaway repository to rehearse the full first-session sequence before running against a real initiative.

### Setup

```bash
# Create a scratch repo
gh repo create <username>/zurdo-project-sandbox --private --clone
cd zurdo-project-sandbox
# scope and ticket create their own labels; bootstrap runs before the first publish and needs a PRD
```

### Run the first session

Follow the first-session sequence verbatim. Use a minimal initiative: one destination, two phases (phase-01 ready, phase-02 researching), one grilling ticket, one research ticket.

### What to inspect in the GitHub UI

| Surface | What to verify |
|---|---|
| Scope issue | Pinned to the repository (or top of the Issues list). Body renders all six sections. Phases table shows correct statuses. |
| Ticket sub-issues | Each ticket issue appears as a sub-issue under the scope issue, labeled `research` or `grilling`. |
| Epic sub-issue | After publishing phase-01, its epic issue appears as a sub-issue under the scope issue, labeled with the phase title. |
| Blocked-by badge | On the phase-02 epic (after it is published), a `blocked-by` relationship points to the open research ticket. The badge is visible in the issue sidebar. |
| Project board | Listed under the repository's **Projects** tab (linked, not just owner-level). Grouped by milestone. Phase-01 milestone contains the epic and its task issues. Phase-02 milestone is absent until its PRD is published. |
| Project description and README | The project's short description reads as the Destination one-liner. The README (project settings, or the README panel on the board) shows the initiative title, all six scope sections, and the phases table with the same statuses as `scope.md`. Edit the Destination in `scope.md`, re-run `scope`, and confirm both fields change. |

### Teardown

```bash
gh repo delete <username>/zurdo-project-sandbox --yes
```

Delete the scratch repo immediately after verification. Never leave sandbox repos open; they appear in search results and can confuse future sessions.
