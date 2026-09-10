# The §2.2 PRD grammar

Every Zurdo PRD follows the §2.2 skeleton verbatim:

````markdown
# PRD: <free-form title>

<free-form prose intro — not parsed>

## Task: <task-id> — <task title>
**Effort**: <key from effort_map>
**Depends-on**: [<task-id>, <task-id>, ...]
**Max-Attempts**: <integer>            # optional
**Skills**: <skill-name>, <skill-name> # optional
**Agent-timeout**: <duration>          # optional, e.g. 30m, 1h, 45s
**Category**: <freeform string>        # optional
**Frozen**: <glob>, <glob>             # optional — paths the agent must not modify

### Requirements                         # optional — when present, before Description

- <req-id>: <free-form requirement text>
- <req-id>: ...

### Description

<free-form prose — passed verbatim to the executor>

### Acceptance Criteria

- [ ] <criterion text> [<hint>] [<hint>] ... [proves: <req-id>, ...]   # [proves:] optional
````

Enforcement (every rule below is a parse error if violated):

- Separator between `<task-id>` and `<task title>` is the **em-dash U+2014** (`—`), not U+002D hyphen and not U+2013 en-dash.
- **No blank line** between the H2 task heading and the metadata block; the first `**Key**: value` line is the very next line.
- Metadata lines are exactly `**Key**: value`, one per line, all in one contiguous block (no blank lines between metadata lines).
- Metadata keys are a closed enum: `Effort`, `Depends-on`, `Max-Attempts`, `Skills`, `Agent-timeout`, `Category`, `Frozen`. Unknown keys are errors.
- `Effort` and `Depends-on` are required. `Max-Attempts`, `Skills`, `Agent-timeout`, `Category`, and `Frozen` are optional.
- `Frozen` is a comma-separated list of globs the agent must not modify during this task's iterations (`*` stays within one path segment, `**` crosses directories, patterns are root-anchored, `!` negation is a parse error). Enforced in union with the run-wide `[verification] protected_paths` config globs; a modified frozen path fails the iteration regardless of criteria results. Never freeze a path a criterion's hint requires the agent to edit — `--analyze` warns on that overlap with family id `frozen-overlap`. This bullet is syntax only: when to freeze, the `**Frozen**`-vs-`protected_paths` scope rule, and the commit-before-run baseline caveat live in [frozen-paths.md](frozen-paths.md).
- `Depends-on` uses YAML-style array syntax: `[task-1, task-2]` or `[]`. Cross-PRD deps are not allowed.
- H3 section headings under each task come from the closed enum `### Requirements`, `### Description`, `### Acceptance Criteria`, in that order. `### Requirements` is optional; when present it must sit **before** `### Description`. `### Description` and `### Acceptance Criteria` are required.
- Task ids match `^task-[a-z0-9-]+$` and must be unique within the PRD.

## Requirements and the proves modifier (optional, §2.2 + §9.2)

A task may carry an optional `### Requirements` block — named obligations that acceptance criteria can be traced back to. It is fully back-compatible: a task with no `### Requirements` block parses exactly as before.

- Each entry is a bulleted line `- <req-id>: <free-form text>`. `<req-id>` matches `^req-[a-z0-9-]+$` (lowercase, e.g. `req-1`, `req-auth`) and is unique within the task. Duplicate ids are a validation error.
- A criterion links to one or more requirements with a trailing `[proves: <req-id>, <req-id>]` modifier. `[proves:]` is **non-checking** — it carries no executable check and never gates the criterion; it only records traceability. Multiple `[proves:]` blocks on one line are allowed and their ids accumulate in source order.
- Every `req-id` in a `[proves:]` tag must reference a requirement declared in the **same task's** `### Requirements` block — a dangling reference is a validation **error** (exit 2), the same class as a dangling `Depends-on`.
- A declared requirement that no criterion proves is an **uncovered requirement** — surfaced as a **warning** by `zurdo validate` / `--analyze`, advisory only, no exit-code change. The `--strict` flag promotes uncovered requirements to errors (exit 2), making coverage mandatory.

Zurdo checks this coverage **deterministically** — no LLM logic at verdict time. The `zurdo-prd-author` skill only *drafts* the structure for a human to ratify; see the `proves modifier` section of the criteria reference.

## Acceptance criteria

Every criterion is a GFM task-list item (`- [ ]`) and **must carry at least one trailing hint** from the §3.1 closed enum. Multiple hints on one criterion are AND'd; mixing `[manual]` with automated hints still gates on the automated checks.

One short example per hint type:

- `- [ ] tests pass [shell: cargo test]`
- `- [ ] healthz responds [http: GET http://localhost:8080/healthz -> 200]`
- `- [ ] migration script is present [file-exists: db/migrations/init.sql]`
- `- [ ] legacy config is deleted [file-absent: config/legacy.toml]`
- `- [ ] debug flag has been removed [grep: DEBUG in src/main.rs]`
- `- [ ] TODO marker is gone [no-grep: TODO in src/main.rs]`
- `- [ ] release notes read sensibly [manual]`

Three structural hints (generally available) extend the enum when the user's
config enables `[lumen]` — `[lumen].enabled = true` in `.zurdo/config.toml`
is the sole gate (a structural hint without it is a validation error):

- `- [ ] the retry helper exists [symbol: function retry_with_backoff in src/net/retry.rs]`
- `- [ ] config is read at startup [references: struct Config in src/config.rs within module main in src/main.rs]`
- `- [ ] the client calls the helper [callers: function retry_with_backoff in src/net/retry.rs within method Client::send in src/net/client.rs]`

Prefer `[file-absent:]` over `[shell: ! test -e ...]` and `[no-grep:]` over `[shell: ! grep -q ...]` — the shell negation forms silently pass when the command itself errors (wrong path, missing binary); the dedicated absence hints fail explicitly instead.

Hint sizing and selection are covered in the criteria-authoring reference.

## Effort values

`Effort` is **not** a hardcoded `low | medium | high` enum. Legal values come from `[effort_map.<provider>]` in the user's `.zurdo/config.toml`, where `<provider>` is the configured executor (e.g. `anthropic`, `codex`, or `copilot`). If you do not know which executor is configured, ask — or default to `low | medium | high` only when the user has explicitly confirmed the shipped defaults apply. Pick the cheapest effort key that plausibly clears the criteria.

## Common pitfalls

- **Em-dash separator (U+2014, not U+002D hyphen).** Copy the `—` from this reference or insert it as `U+2014`. A hyphen produces `TaskHeadingHyphenSeparator` and the task is dropped from the parsed PRD.
- **No blank line between the H2 task heading and the metadata block.** The H2 visually invites a blank line for readability — resist it. Metadata starts on the very next line.
- **Every criterion needs a hint.** A bare `- [ ] my criterion` with no trailing `[…]` block is a validation error. If no machine check applies, write `[manual]` explicitly.
- **`Depends-on` ids must resolve.** Each entry must match the id of another task in the same PRD. Dangling references and self-dependencies are errors caught at validation.

## Worked examples

Worked examples live in the parent SKILL.md.

## Verification

Verify your work: run `zurdo analyze --static-only <prd>` and address any errors before handing the PRD back.
