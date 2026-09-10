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
| `zurdo-github` skill and script | Required — stop | Skill present in agent's skill list **and** `scripts/zurdo-github.sh` exists at repo root | None. Run `zurdo skills install zurdo-github`. |
| `zurdo-prd-author` | Required — stop | Skill present in agent's skill list | None. Run `zurdo skills install zurdo-prd-author`. It is the single PRD authoring entry point (decomposition, §2.2 grammar, criteria forcing, and pre-run review in one interview); a phase PRD cannot be written or reviewed without it. |
| `zurdo-lessons` | Required — stop | Skill present in agent's skill list | None. `zurdo-prd-author` calls it by name in its review phase and stops when it cannot resolve. Run `zurdo skills install --all` (installs every bundled skill). |
| `zurdo-domain` | Required — stop | Skill present in agent's skill list | None. `zurdo-prd-author` and `zurdo-prd-review` call it by name to word requirements and lessons in the project's governed nouns. Run `zurdo skills install zurdo-domain`. If the project has no `CONTEXT.md` glossary yet, the skill creates one; note that in `scope.md` Notes. |
| `zurdo-prd-review` | Optional — recommended | Skill present in agent's skill list | Run the phase review interview against `prd.json` statuses and `git diff` alone, and say in the review notes that no intent-level review ran. |
| `zurdo-design-author` | Optional | Skill present in agent's skill list | Record the adjudication as a research ticket's `## Findings` with the measurements inline; skip the `implementation:` frontmatter. |
| `zurdo-state-summary` | Optional | Skill present in agent's skill list | Read `.zurdo/<slug>/prd.json` and `progress.log` by hand to tally task statuses before `sync-status`. |
| `zurdo-hint-debugger` | Optional | Skill present in agent's skill list | Read the failing criterion's `.zurdo/<slug>/iterations/*.out` and `.err` captures by hand. |
| `grilling` or `grill-me` | Optional | Skill present in agent's skill list (either name) | Use the inline interview protocol from `references/interview.md`. |

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

5. **Preview the scope issue**:

   ```bash
   zurdo-github.sh scope --dry-run
   ```

   Read the full plan. Confirm the initiative title, the Phases table, the ticket list, and the `gh project edit` payload (description one-liner, README body) are correct.

6. **Create the scope issue**:

   ```bash
   zurdo-github.sh scope
   ```

7. **Preview ticket issues**:

   ```bash
   zurdo-github.sh ticket --dry-run
   ```

8. **Create ticket issues**:

   ```bash
   zurdo-github.sh ticket
   ```

9. **Fire research subagents** — for each open research ticket, dispatch a subagent to fetch and synthesize. Research tickets may run in parallel. Do not wait for them to finish before stopping the session; they resolve asynchronously and their findings are written into the ticket file.

10. **If phase-01 is `ready`** — invoke `zurdo-prd-author` to author the PRD (its interview ends with the review verdict; stop only on `✓ READY TO RUN`), commit the PRD with its `.trail.md` sidecar and any `lessons/` files, then publish (see the publish sequence in the later-session section). Stop after publishing; do not start Zurdo in this same session.

**Stop here.** One session's worth of work is: scoped, researched, one PRD authored and published (if phase-01 was ready). Do not graduate additional phases in the first session.

---

## Every later session

At the start of each subsequent session, orient before acting.

1. **Read `scope.md`** — check current phase statuses and open tickets.

2. **Preview divergence**:

   ```bash
   zurdo-github.sh scope --dry-run
   ```

   Read the full plan output before picking the next action.

3. **Pick the next action** in this priority order:

   | Priority | Condition | Action |
   |---|---|---|
   | 1 | An open grilling ticket exists | Resolve it: interview the user, write `## Findings`, flip `status: resolved`, run `zurdo-github.sh ticket`, update `scope.md`, run `scope`. |
   | 2 | An open research ticket has new findings from a subagent | Write `## Findings` in the ticket file, flip `status: resolved`, run `zurdo-github.sh ticket`, update `scope.md`. |
   | 3 | A phase is `ready` and no PRD exists for it | Author the PRD (invoke `zurdo-prd-author`; it decomposes, writes, forces criteria, and reviews in one interview), then commit the PRD, its `.trail.md` sidecar, and any `lessons/` files. |
   | 4 | A PRD exists and the phase is `ready` | Publish (see sequence below), flip phase to `running` in `scope.md`. |
   | 5 | A phase is `running` and `zurdo run` finished with `failed` or `blocked-by-dependency` tasks | Invoke `zurdo-hint-debugger` on each failing criterion; fix the hint or the code; `zurdo run --resume`. Run `sync-status` so GitHub shows the failures meanwhile. |
   | 6 | A phase is `running` and `zurdo run` is complete | Invoke `zurdo-state-summary` to confirm the run is settled (no live lock, no in-flight iteration), run `sync-status`, refresh the scope issue, then invoke `zurdo-prd-review`. |
   | 7 | `zurdo-prd-review` returned a gaps verdict | Commit the follow-up PRD and any `lessons/` files, publish it with `--scope <n>`, run it, `sync-status`; the phase stays `running` until the follow-up is green. |
   | 8 | `zurdo-prd-review` returned landed-as-intended | Begin the phase review interview; update `scope.md`; graduate the next phase if one becomes ready. |

### Publish sequence

Run in order; always `--dry-run` first.

```bash
# One-time per repo — safe to repeat; idempotent
zurdo-github.sh bootstrap

zurdo-github.sh publish --dry-run --scope <n>
zurdo-github.sh publish --scope <n>

# Refresh the scope issue to show the new running phase
zurdo-github.sh scope --dry-run
zurdo-github.sh scope
```

After `publish --scope <n>` succeeds, flip the phase row to `Status: running` in `scope.md`.

### Sync-status sequence

```bash
zurdo run

# Confirm the run is settled before syncing (invoke zurdo-state-summary, or read prd.json by hand)

zurdo-github.sh sync-status --dry-run
zurdo-github.sh sync-status

# After sync, also refresh the scope issue
zurdo-github.sh scope --dry-run
zurdo-github.sh scope
```

---

## Reading a scope dry-run plan

Before any live run, read the full dry-run output and check these items:

| Item | What to check |
|---|---|
| Ticket count | The number of ticket issues to create matches the ticket files you expect. A mismatch means a ticket file was added or removed since the last run. |
| Resolved tickets planned to close | Each resolved ticket appears in the "close issue" list. If a resolved ticket is absent, its `status:` frontmatter was not flipped — fix it before the live run. |
| Deferred edges named | Any ticket that `blocks` a phase not yet in the Phases table appears as a warning. Either add the phase row or update the ticket's `blocks` list. |
| Project step present or skipped | If the `project` scope is absent from `gh auth status`, the plan should show the board step as skipped, not attempted. If the step appears in a required position, the scope is missing — re-authenticate. |

Stop and investigate any unexpected line in the plan before proceeding to the live run.

---

## Board step

The board step is optional and runs last in each publish sequence.

```bash
zurdo-github.sh board --project "<initiative title>" --dry-run
zurdo-github.sh board --project "<initiative title>"
```

**Requires the `project` scope** on the `gh` auth token. If the scope is absent, skip the board step and note it in the session summary. The board is a convenience surface; its absence does not block Zurdo execution.

Run the board command after each successful publish, not before. The board enrolls already-published milestones and epics — running it before publish leaves gaps.

**Project-to-repo link.** Projects v2 projects are owned by the user or org, not the repo. Both `scope` and `board` link the project to the target repository immediately after creating it, so it appears under the repo's **Projects** tab and issues can be added from the sidebar. Verify the link in the sandbox check below; if the Projects tab is empty, re-run `scope` (the link call is idempotent).

**Project description and README.** Only `scope` writes them: the description is the Destination paragraph and the README is the scope body. `board` leaves both alone. After any `scope.md` edit that touches the Destination, the phase table, or a decision, re-run `scope` so the board's front page catches up; do not patch the fields in the GitHub UI.

---

## Failure handling

`zurdo-github.sh` exits with one of four codes.

| Exit code | Meaning | What to do |
|---|---|---|
| `0` | Success; plan applied without errors. | Continue to the next step. |
| `1` | User error — bad arguments, missing required flag, unknown subcommand. | Read the error message, correct the invocation, re-run. |
| `2` | Precondition not met — a marker is absent, the repo is not bootstrapped, or an expected issue cannot be found. | Run `zurdo-github.sh bootstrap` if the repo has not been bootstrapped. Otherwise inspect the marker database and the error message; resolve the missing precondition before re-running. |
| `3` | GitHub API error — rate limit, auth failure, network. | Check `gh auth status` for token validity and scope. For rate limits, wait and retry. For auth failure, run `gh auth login` with the required scopes. |

### Divergence lines in dry-run output

A divergence line names a GitHub issue whose state differs from what `scope.md` or the ticket file says. Do not ignore divergence lines. Before the live run:

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
zurdo-github.sh bootstrap
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
