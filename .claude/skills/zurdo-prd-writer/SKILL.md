---
name: zurdo-prd-writer
description: "Author a Zurdo PRD that satisfies the strict §2.2 grammar on the first try — em-dash separator, contiguous metadata, hinted criteria, effort_map-driven Effort values."
allowed-tools: [Read, Write, Edit]
---

## When to invoke

Invoke this skill when the user asks for a PRD, a task list with dependencies, an acceptance-criteria block, or any artifact destined for `zurdo run`. Zurdo PRDs are markdown but constrained to a closed grammar — anything off-grammar is a parse error with a line number, so authoring blind is a fast way to waste tokens. This skill teaches the grammar exhaustively and points the user at `zurdo --analyze --static-only <path>` for a final self-check before the PRD is handed back.

## The grammar

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

### Description

<free-form prose — passed verbatim to the executor>

### Acceptance Criteria

- [ ] <criterion text> [<hint>] [<hint>] ...
````

Enforcement (every rule below is a parse error if violated):

- Separator between `<task-id>` and `<task title>` is the **em-dash U+2014** (`—`), not U+002D hyphen and not U+2013 en-dash.
- **No blank line** between the H2 task heading and the metadata block; the first `**Key**: value` line is the very next line.
- Metadata lines are exactly `**Key**: value`, one per line, all in one contiguous block (no blank lines between metadata lines).
- Metadata keys are a closed enum: `Effort`, `Depends-on`, `Max-Attempts`, `Skills`, `Agent-timeout`, `Category`. Unknown keys are errors.
- `Effort` and `Depends-on` are required. `Max-Attempts`, `Skills`, `Agent-timeout`, and `Category` are optional.
- `Depends-on` uses YAML-style array syntax: `[task-1, task-2]` or `[]`. Cross-PRD deps are not allowed.
- H3 section headings under each task are exactly `### Description` then `### Acceptance Criteria`, in that order.
- Task ids match `^task-[a-z0-9-]+$` and must be unique within the PRD.

## Acceptance criteria

Every criterion is a GFM task-list item (`- [ ]`) and **must carry at least one trailing hint** from the §3.1 closed enum. Multiple hints on one criterion are AND'd; mixing `[manual]` with automated hints still gates on the automated checks.

One short example per hint type:

- `- [ ] tests pass [shell: cargo test]`
- `- [ ] healthz responds [http: GET http://localhost:8080/healthz -> 200]`
- `- [ ] migration script is present [file-exists: db/migrations/init.sql]`
- `- [ ] legacy config is deleted [file-absent: config/legacy.toml]`
- `- [ ] TODO marker is gone [no-grep: TODO in src/main.rs]`
- `- [ ] release notes read sensibly [manual]`

Prefer `[file-absent:]` over `[shell: ! test -e ...]` and `[no-grep:]` over `[shell: ! grep -q ...]` — the shell negation forms silently pass when the command itself errors (wrong path, missing binary); the dedicated absence hints fail explicitly instead.

## Effort values

`Effort` is **not** a hardcoded `low | medium | high` enum. Legal values come from `[effort_map.<provider>]` in the user's `.zurdo/config.toml`, where `<provider>` is the configured executor (e.g. `anthropic`, `codex`, or `copilot`). If you do not know which executor is configured, ask — or default to `low | medium | high` only when the user has explicitly confirmed the shipped defaults apply. Pick the cheapest effort key that plausibly clears the criteria.

## Common pitfalls

- **Em-dash separator (U+2014, not U+002D hyphen).** Copy the `—` from this skill or insert it as `U+2014`. A hyphen produces `TaskHeadingHyphenSeparator` and the task is dropped from the parsed PRD.
- **No blank line between the H2 task heading and the metadata block.** The H2 visually invites a blank line for readability — resist it. Metadata starts on the very next line.
- **Every criterion needs a hint.** A bare `- [ ] my criterion` with no trailing `[…]` block is a validation error. If no machine check applies, write `[manual]` explicitly.
- **`Depends-on` ids must resolve.** Each entry must match the id of another task in the same PRD. Dangling references and self-dependencies are errors caught at validation.

## Worked example

A complete one-task PRD that parses cleanly:

````markdown
# PRD: Add a Greeting File

Drop a static file into the repo root with a known string.

## Task: task-1 — Create greeting.txt
**Effort**: low
**Depends-on**: []

### Description

Create `greeting.txt` at the repo root containing the word `Hello`.

### Acceptance Criteria

- [ ] greeting.txt exists [file-exists: greeting.txt]
- [ ] greeting.txt contains Hello [grep: Hello in greeting.txt]
````

A two-task PRD with a `Depends-on` arrow:

````markdown
# PRD: Build a Hello-World Binary

Two-step PRD: scaffold a tiny Cargo binary, then build it.

## Task: task-1 — Scaffold the binary
**Effort**: low
**Depends-on**: []

### Description

Create `src/main.rs` with a `fn main()` that prints `hello`.

### Acceptance Criteria

- [ ] src/main.rs exists [file-exists: src/main.rs]
- [ ] main prints hello [grep: hello in src/main.rs]

## Task: task-2 — Build the binary
**Effort**: medium
**Depends-on**: [task-1]

### Description

Compile the crate in release mode.

### Acceptance Criteria

- [ ] release build succeeds [shell: cargo build --release]
````

Verify your work: run `zurdo --analyze --static-only <your-prd.md>` and address any errors before handing the PRD back.
