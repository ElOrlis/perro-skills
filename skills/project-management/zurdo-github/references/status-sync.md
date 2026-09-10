# status-sync

How Zurdo run state flows to GitHub: run directory resolution, prd.json field shapes, status mapping, label rules, comment template, epic table refresh, and the one-direction constraint.

---

## Run directory resolution

Each Zurdo run lives at `.zurdo/<slug>/` where `<slug>` is `<prd-basename>-<hash>` — the basename of the PRD file (no extension) concatenated with a short hash derived from its content.

Example: PRD at `docs/golang/prds/prd-01-golang-skill.md` → slug `prd-01-golang-skill-f2c1` → run dir `.zurdo/prd-01-golang-skill-f2c1/`.

**Selecting the run directory:**

1. If `--slug <slug>` is passed, use `.zurdo/<slug>/` directly. Error if it does not exist.
2. Otherwise, scan all `.zurdo/*/prd.json` files, parse `last_updated`, and pick the newest one.

The two authoritative files inside the run dir are `prd.json` (structured state) and `progress.log` (NDJSON event stream). Only `prd.json` is consumed by sync; `progress.log` is for human inspection.

---

## prd.json shape

Top-level fields observed:

```json
{
  "schema_version": 1,
  "prd_path": "docs/golang/prds/prd-01-golang-skill.md",
  "prd_hash": "47f78160ed3d5e3fb632ff7ec8bb94e2a3352ca5",
  "started_at": "2026-06-18T18:30:21.414374Z",
  "last_updated": "2026-06-18T18:40:19.187516Z",
  "tasks": { ... }
}
```

Each entry under `tasks` is keyed by task id (e.g. `"task-skill-scaffold"`):

```json
{
  "status": "passed-pending-review",
  "attempts": 1,
  "passed_at": "2026-06-18T18:31:07.806295Z",
  "iterations": [ ... ]
}
```

Each element of `iterations[]`:

```json
{
  "attempt": 1,
  "started_at": "2026-06-18T18:30:21.431768Z",
  "ended_at": "2026-06-18T18:31:07.806295Z",
  "model": "claude-sonnet-4-6",
  "agent_exit_code": 0,
  "agent_stdout_path": "...",
  "agent_stderr_path": "...",
  "agent_stdout_bytes": 1638,
  "agent_stderr_bytes": 0,
  "tokens_in": 131185,
  "tokens_out": 1599,
  "cost_usd_est": 0.4175,
  "timed_out": false,
  "criteria_results": [ ... ]
}
```

Each element of `criteria_results[]`:

```json
{
  "hint": "file-exists: skills/programing-languages/golang/SKILL.md",
  "passed": true,
  "duration_ms": 0,
  "exit_code": null,
  "stdout_truncated": null,
  "stderr_truncated": null,
  "timed_out": false,
  "stdout_bytes": 0,
  "stderr_bytes": 0
}
```

`hint` is the raw criterion string from the PRD (e.g. `"[manual]"`, `"file-exists: <path>"`, `"grep: <pattern>"`). `passed` is the only field sync acts on; the rest are diagnostic.

---

## Status enum and mapping

Four values appear in `tasks.<id>.status`:

| `status` | GitHub action |
|---|---|
| `passed` | Close the issue; post a sync comment. |
| `passed-pending-review` | Add label `zurdo:pending-review`; post a sync comment; leave open. |
| `failed` | Add label `zurdo:failed`; post a sync comment listing failed hints; leave open. |
| `blocked-by-dependency` | No change to issue state, labels, or comments. |

**`passed`**: the task completed and all criteria held. Close the issue (`gh issue close`) and post a comment. A closed issue is never reopened by a later sync, even if the prd.json changes.

**`passed-pending-review`**: all automated criteria passed, but one or more `[manual]` criteria require human sign-off. The issue stays open with `zurdo:pending-review` until a human runs `zurdo review`, which signs off the manual criteria and causes a later sync to see `passed`.

**`failed`**: the agent ran and at least one criterion did not pass. Label `zurdo:failed` is applied and the comment lists which hints failed.

**`blocked-by-dependency`**: the task cannot run yet because a predecessor is unfinished. Sync skips the issue entirely — no label change, no comment, no close.

### The `attempts: 0` + `passed-pending-review` case

When `attempts` is `0` and `iterations` is `[]`, the task reached `passed-pending-review` without an agent run — its automated criteria were already satisfied when sync evaluated them (e.g. the file already existed from a prior run or a manual commit). The comment reports this explicitly:

```markdown
**Status**: passed-pending-review
**Attempts**: 0 (criteria held without an agent run)
**Model**: —
**Tokens in / out**: — / —
**Estimated cost**: —
```

No per-iteration stats are available; fields that require an iteration are rendered as `—`.

---

## Label swap rule

Status labels (`zurdo:pending-review`, `zurdo:failed`) are mutually exclusive. Before adding a status label, remove the other one if present. Never stack both on the same issue.

Rules:
- Moving to `passed-pending-review`: remove `zurdo:failed` if present, then add `zurdo:pending-review`.
- Moving to `failed`: remove `zurdo:pending-review` if present, then add `zurdo:failed`.
- Moving to `passed` (close): remove both status labels before closing. The closed state is the terminal signal; no status label is left on a closed issue.
- A closed issue is never reopened. If sync sees a task whose issue is already closed, it skips label and state changes and notes the divergence in its summary output.

---

## Comment template

Post one comment per sync run per task (do not stack comments across repeated syncs of the same state). The comment is fenced markdown:

````markdown
**Zurdo sync** · `<iso-timestamp>`

**Status**: <status>
**Attempts**: <n>
**Model**: <model of last iteration, or —>
**Tokens in / out**: <tokens_in> / <tokens_out> (or — / — if no iterations)
**Estimated cost**: $<cost_usd_est> (or —)

<!-- failed hints section, only when status == failed -->
**Failed criteria**:
- `<hint>`
- `<hint>`
````

`<model>` and token/cost fields are drawn from the last entry in `iterations[]` (highest `attempt` number). When `iterations` is empty (`attempts: 0`), render those fields as `—`.

For `passed` and `passed-pending-review`, omit the "Failed criteria" block. For `failed`, list every `criteria_results` entry where `passed == false`, using the `hint` value verbatim.

---

## Epic table refresh

The epic body contains a `## Tasks` table with a `Status` column (see `github-model.md` for the full body template). Sync rewrites the Status column values in place without altering the intro text, the HTML marker comment, or any other sections.

**Status column values:**

| Task `status` | Table cell |
|---|---|
| `passed` | `Done` |
| `passed-pending-review` | `Pending review` |
| `failed` | `Failed` |
| `blocked-by-dependency` | `Blocked` |
| Not yet started (no entry in prd.json) | `Todo` |

**Rewrite procedure:**

1. Fetch the current epic body via `gh issue view <epic-number> --json body`.
2. Locate the `## Tasks` section by finding that heading. The marker `<!-- zurdo-github prd=<path> epic -->` identifies the epic; confirm it before editing.
3. Replace each table row's Status cell by matching on the issue number anchor (`#<number>`) in that row — do not rely on row order.
4. `PATCH` the issue body with the updated string. The intro text, marker comment, and any human edits above or below the table are preserved verbatim.

Never delete and recreate the epic body; edit in place.

---

## Scope phase status

Phase status in `scope.md` (e.g. which phases are in progress or complete) is derived and maintained by the `zurdo-project` skill, not by this script. The `zurdo-project` skill reads `sync-status` outcomes from `prd.json` across all PRDs in the project and updates `scope.md` accordingly. `sync-status` itself reads only `prd.json` and writes only to GitHub issue state — it never reads or modifies the scope issue, `scope.md`, or any ticket file.

---

## Direction rule

Sync is **one-directional**: Zurdo run state → GitHub. GitHub never writes back into `prd.json` or any file under `.zurdo/`.

Consequences:
- If a human closes a task issue by hand (outside of sync), sync leaves it closed on subsequent runs. It does not reopen it, does not update its status label, and does not post a new comment.
- The sync summary printed to stdout notes each such divergence: `DIVERGED: task-<id> is closed in GitHub but status in prd.json is <status>`.
- If a human edits issue body text, adds labels, or changes assignees, sync ignores those changes — it only reads `status`, `attempts`, and `iterations` from prd.json.
- The canonical state of a run is `prd.json`. GitHub is a projection of that state, not a source of truth.
