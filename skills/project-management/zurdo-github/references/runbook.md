# runbook

Operator's sequence for publishing a Zurdo PRD to a real repository, keeping status in sync, and handling failure.

---

## Preconditions

Check these before any live run; partial runs caused by missing auth are tedious to roll back.

**Auth scopes**

```bash
gh auth status
```

The `repo` scope is required for all modes. Confirm it appears in the "Token scopes" line. The `project` scope is required only for `board`; without it `board` exits 3 and names the fix, while `bootstrap`, `publish`, and `sync-status` are unaffected.

Add `project` scope when needed:

```bash
gh auth refresh -s project
```

**`jq` present**

```bash
jq --version
```

`jq` is used by the script to parse JSON from every `gh api` response. Its absence causes silent failures, not helpful errors — confirm it before running.

**Valid PRD**

```bash
zurdo validate docs/<skill>/prds/prd-NN-<name>.md
```

Must exit 0. A Zurdo-parse error at validate time means the same error will surface at publish time. Fix the PRD before continuing — a partial publish from a malformed PRD leaves milestone and label debris that requires manual cleanup.

---

## Order of operations

Run every step in sequence; do not skip `--dry-run` passes.

```
1. zurdo validate <prd>                                                   # exit 0 required
2. ./scripts/zurdo-github.sh bootstrap --dry-run <prd>                   # review label plan and About/doc actions
3. ./scripts/zurdo-github.sh bootstrap <prd>                             # live: labels, optional About, conventions doc
4. ./scripts/zurdo-github.sh scope --dry-run <prd>                       # review scope issue + project creation plan
5. ./scripts/zurdo-github.sh scope <prd>                                 # live: scope issue, Projects v2 project
6. ./scripts/zurdo-github.sh ticket --dry-run <prd>                      # review ticket issues + blocked-by edges
7. ./scripts/zurdo-github.sh ticket <prd>                                # live: ticket issues, sub-issue links, edges
8. ./scripts/zurdo-github.sh publish --dry-run --scope <n> <prd>         # read the plan: counts, edges, labels, repo
9. ./scripts/zurdo-github.sh publish --scope <n> <prd>                   # live: milestone, epic, tasks, wiring; epic nested under scope
10. ./scripts/zurdo-github.sh board --project "<title>" <prd>            # optional: Projects v2 mirror
```

After `zurdo run` completes on any tasks:

```
11. ./scripts/zurdo-github.sh sync-status --dry-run <prd>  # preview label swaps + closes
12. ./scripts/zurdo-github.sh sync-status <prd>            # live: apply sync
```

After `zurdo review` signs off pending tasks:

```
13. ./scripts/zurdo-github.sh sync-status <prd>            # close tasks now recorded as passed
```

Step 3 is idempotent. Step 9 (`publish`) repeats the label step of `bootstrap` but not the About or conventions-doc actions, so run `bootstrap` once per repo and `publish` once per PRD. Steps 4–7 (`scope` and `ticket`) are per-project, not per-PRD; run them once when setting up a new project scope, then re-run `publish --scope <n>` for each PRD in that project.

---

## Scope and ticket prerequisite checks

**`scope.md` absent — `scope` exits 3**

When `scope.md` is not present in the repository root, `scope` prints:

```
skip: scope.md not found — create scope.md before running the scope mode
```

and exits 3. Create `scope.md` with at minimum a title heading before retrying.

**`run scope first` — `publish --scope` exits 3**

When `publish --scope <n>` is given but the scope issue marker (`<!-- zurdo-github scope=... -->`) is not found in issue `<n>`, the script prints:

```
error: scope issue #<n> has no zurdo-github scope marker — run scope first
```

and exits 3. Run `./scripts/zurdo-github.sh scope <prd>` (or confirm the correct issue number) before retrying `publish --scope`.

**`--project` title for `board`**

`board` uses `--project <project-title>` to find or create the Projects v2 project. When `--project` is omitted, the project title defaults to the PRD title. Pass `--project` explicitly when the project was created by `scope` under a different title, so `board` attaches task issues to the same project.

**Hand-closed tickets**

If a ticket issue is closed by hand outside of sync, `ticket` re-runs leave it closed and print:

```
DIVERGED: ticket-<phase>-<name> is closed in GitHub; body and labels updated, state unchanged
```

The ticket body and labels are updated in place; the closed state is never changed by the tool.

---

## Reading a dry-run plan

Dry-run output is the only verification gate before mutations. Confirm all four things before running live:

**Task count matches the PRD.** Count the `CREATE issue` lines in the plan. The number must equal the number of `## Task:` blocks in the PRD. A mismatch means a malformed task header was silently skipped — fix the PRD before continuing.

**Every Depends-on appears as an edge.** Each `Depends-on` in the PRD must produce a `WIRE blocked-by: #<blocker> → #<task>` line. A missing edge means the dependency was not resolved (the referenced task-id is misspelled or absent) — fix before continuing.

**No unexpected label creations.** The plan lists `CREATE label` for each new label. Verify that unfamiliar labels (e.g. unexpected `effort:` values) match the PRD, not a typo. Labels created live cannot be automatically removed.

**Repo owner/name is correct.** The first block of the plan prints `repo: owner/name`. Confirm it matches the target repository before going live. Override if wrong: `--repo owner/correct-name`.

---

## Re-running publish after editing the PRD

Re-running `publish` (or `bootstrap`) on an already-published PRD is safe. The marker is the identity — existing issues are matched and updated, not duplicated.

**What changes in place:**
- Issue title (if the task heading changed)
- Issue body (description, acceptance criteria, metadata table)
- Labels (effort labels reflect the new `**Effort**` value)
- Milestone membership
- New dependency edges added for new `Depends-on` entries

**What does not change:**
- Closed issues — sync or human-closed issues are left as-is; the body and labels are updated, but state is never changed from closed to open
- Assignees — publish never clears or overwrites assignees; contributors who self-assigned retain their claim
- Comments — existing comments from prior syncs or humans are preserved

**Removed tasks:** If a task block is deleted from the PRD, its issue is not deleted from GitHub. The publish summary lists such orphaned issues:

```
ORPHAN: #42 "task-old-name" — no matching task in PRD; close manually if no longer needed
```

Close orphaned issues by hand after verifying they are not in progress.

---

## Description touch rules

| Target | Touch rule |
|---|---|
| Milestone description | Always overwrite on every run |
| Repo About field | Only when currently empty; only when `--about` flag is passed |
| README | Never |
| Board readme | Always mirrors the milestone description |

Milestone descriptions are safe to overwrite — they are owned by the tool. The repo About field is owned by the maintainer once set; the tool reads it, skips the write if non-empty, and prints a note. The README is user-controlled content and is never touched regardless of flags.

---

## Assignment

`publish` assigns the epic issue to `@me` (the authenticated user). No other assignment is made at publish time.

Task issues are created unassigned. An unassigned task with `ready-for-agent` signals that the task is available. Assignment is the claim — whoever picks up a task self-assigns it:

```bash
gh issue edit <number> --add-assignee @me -R owner/repo
```

Do not pre-assign tasks at publish time. Pre-assigning removes the signal that work is available and skips contributors who might claim it.

---

## Conventions doc

`bootstrap` appends a `## Zurdo operations` section to `docs/agents/issue-tracker.md` when that file exists and does not already contain the heading; a second run leaves the file untouched. If the file does not exist the script prints:

```
skip: docs/agents/issue-tracker.md not present
```

and continues without creating it. The appended block is:

```markdown
## Zurdo operations

Zurdo turns a PRD into GitHub issues. Label groups: type (`zurdo:epic`, `zurdo:task`), state (`zurdo:pending-review`, `zurdo:failed`), effort (`effort:<value>`), triage (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`).

Marker format: `<!-- zurdo-github prd=<path> task=<id> -->` (and `epic` variant) — an invisible identity that makes re-runs idempotent.

Epic layout: the PRD becomes a milestone plus an epic issue holding the intro, a task table, and (fallback) a task checklist. Task issues are sub-issues of the epic.

Modes: `bootstrap` (labels + docs), `scope` (scope issue + project), `ticket` (ticket issues + edges), `publish` (milestone + epic + tasks + wiring), `sync-status` (label/close from a Zurdo run), `board` (Projects v2 mirror).
```

---

## Failure handling

**4xx from GitHub API**

Sub-issue and blocked-by endpoints degrade gracefully (see `github-model.md` for the full fallback spec). All other 4xx responses are terminal for the affected operation:

- `401 Unauthorized` — missing or expired token; re-authenticate with `gh auth login`.
- `403 Forbidden` — insufficient scope; add the missing scope with `gh auth refresh -s <scope>`.
- `404 Not Found` on milestones or issues — the repo may not exist or the token lacks `repo`; confirm both.
- `422 Unprocessable Entity` on already-existing edges — silently ignored; no action needed.

**Timeouts**

Every network call is wrapped with `timeout 90`. A call that exceeds 90 seconds is killed and the run fails with exit code 3 (see exit-code table below). Network flakiness on GitHub's side is the common cause; retry the full run — idempotency makes it safe.

**Rate limits**

Check remaining quota before a large publish (many tasks):

```bash
gh api rate_limit --jq '.resources.core | {limit, remaining, reset}'
```

`reset` is a Unix timestamp. If `remaining` is below the estimated call count (roughly 3 per task plus 10 fixed), wait until reset. The script does not auto-wait on rate limit responses; it exits 2.

**Exit-code table**

| Code | Meaning |
|---|---|
| `0` | All operations completed successfully |
| `1` | Validation or configuration error (bad PRD, missing `jq`, wrong repo) — fix the input and re-run |
| `2` | GitHub API rate limit hit — wait for quota reset, then re-run |
| `3` | Network timeout or transient API failure — retry; idempotency makes re-runs safe |

---

## Sandbox verification

Run once against a throwaway repository before using the tool on a real project.

**Setup**

```bash
gh repo create sandbox-zurdo-test --private --confirm
```

Run the full sequence against the throwaway repo:

```bash
zurdo validate docs/<skill>/prds/prd-NN-test.md
./scripts/zurdo-github.sh bootstrap --dry-run --repo <you>/sandbox-zurdo-test docs/<skill>/prds/prd-NN-test.md
./scripts/zurdo-github.sh publish --repo <you>/sandbox-zurdo-test docs/<skill>/prds/prd-NN-test.md
./scripts/zurdo-github.sh sync-status --dry-run --repo <you>/sandbox-zurdo-test docs/<skill>/prds/prd-NN-test.md
```

**What to inspect in the GitHub UI**

Open the repository and confirm each item:

- **Milestone progress bar** — the milestone must show all task issues as members, progress starts at 0%.
- **Sub-issue tree on the epic** — every task issue must appear as a sub-issue under the epic; confirm the count equals the PRD task count.
- **Blocked-by badges on task issues** — issues with `Depends-on` must show a "blocked by #N" badge; issues without must show no badge.
- **`ready-for-agent` on frontier tasks only** — the `ready-for-agent` label must appear only on tasks that have no `Depends-on` entries; blocked tasks must not carry it at creation time.

After the sandbox passes all four checks, delete it:

```bash
gh repo delete <you>/sandbox-zurdo-test --confirm
```
