---
name: zurdo-criteria-author
description: "Author or enrich the ### Acceptance Criteria block for a single Zurdo task — every line a `- [ ]` GFM checkbox with at least one hint from the §3.1 closed enum, sized to prove the criterion without over-checking."
allowed-tools: [Read, Edit]
---

## When to invoke

Invoke this skill when the task heading, metadata, and `### Description` are already in place but the `### Acceptance Criteria` block is missing, empty, or under-specified. This is a narrower scope than [[zurdo-prd-writer]] (which authors the whole §2.2 skeleton) — use this skill when the surrounding grammar is fine and only the criteria block needs work.

Typical entry points:
- A task with `### Acceptance Criteria` immediately followed by the next task heading.
- A task whose criteria are present but unhinted (`- [ ] feature works` with no trailing `[…]`).
- A task whose criteria are present but the hints don't match the criterion text — pair this skill with [[zurdo-prd-reviewer]].

Do **not** invoke this skill to fix grammar errors elsewhere in the PRD (use the writer), to debug a *failing* criterion at run-time (use [[zurdo-hint-debugger]]), or to rewrite a task description.

## The grammar of one criterion line

Every line in the block is a GFM task-list item:

```
- [ ] <free-form criterion text> [<hint>] [<hint>] ...
```

Rules (every one is a parse error if violated — §2.3):
- The `- [ ]` prefix is exact: hyphen, space, open bracket, space, close bracket, space.
- The line ends with one or more `[hint]` blocks. **A line with no `[hint]` is a validation error.**
- Multiple hints are AND'd: all must pass for the criterion to pass. Hints run in source order.
- The leading checkbox is *never* read or written by Zurdo (§3.2). It is bookkeeping for the human, not machine signal.

## The seven hint types (§3.1)

| Hint syntax | Passes when |
|---|---|
| `[shell: <cmd>]` | shell exits 0 (runs at repo root) |
| `[http: <method> <url> -> <status>]` | HTTP response status equals `<status>` |
| `[file-exists: <path>]` | file exists at `<path>` relative to repo root |
| `[file-absent: <path>]` | no file exists at `<path>` relative to repo root |
| `[grep: <pattern> in <file>]` | `<pattern>` is found in `<file>` |
| `[no-grep: <pattern> in <file>]` | `<pattern>` is NOT found in `<file>` (fails if file is unreadable) |
| `[manual]` | never machine-checked; only affects task status |

The `[manual]` hint co-exists with automated hints on the same line; the automated hints still gate (`[grep: TODO in src/main.rs] [manual]` passes when grep passes; the `[manual]` annotation is informational).

## Sizing the criteria block

Aim for **3–5 criteria per task** as the comfortable range:

- **Fewer than 2** ⇒ the task is probably under-specified; the agent has too little signal that it's done.
- **More than ~6** ⇒ the task is probably too large; consider splitting via [[zurdo-prd-decomposer]].
- **The golden path is non-negotiable.** Every task needs at least one criterion that proves the headline outcome.
- **One or two edge cases** are usually appropriate when the headline outcome has obvious failure modes (auth: unauthenticated + unauthorized + valid; CRUD: create + read + update + delete).
- **One `[manual]`** is fine where automation cannot reach (UX polish, copy, visual hierarchy). Don't pad with `[manual]` to inflate the count.

## Hint-selection heuristics

For each criterion you write, pick the cheapest hint that proves it. In rough order of cost:

1. `[file-exists:]`, `[file-absent:]`, `[grep:]`, and `[no-grep:]` are nearly free — milliseconds, no subprocess. Use for presence/absence checks, marker strings, version bumps.
2. `[shell:]` is the workhorse but pays for itself on every iteration. Narrow the command (`cargo test --test foo` over `cargo test`) so a regression elsewhere doesn't drag this criterion down.
3. `[http:]` requires a running server; pair with a `[shell:]` that brings the server up if needed, or rely on a long-lived dev server the user is responsible for.
4. `[manual]` is the escape hatch; the task short-circuits to `passed-pending-review` if every criterion is manual (§3.2).

When in doubt, prefer **one specific hint** over **two loose hints**. `[shell: cargo test --test login_returns_401_without_password]` is better than `[shell: cargo build] [shell: cargo test]` — the former proves the actual behavior; the latter proves only that things compile and the suite passes.

## Patterns by task shape

- **Implement a function or module.**
  ```
  - [ ] module file exists [file-exists: src/auth/login.rs]
  - [ ] crate compiles [shell: cargo build]
  - [ ] unit tests pass [shell: cargo test --test login]
  ```

- **Add an HTTP endpoint.**
  ```
  - [ ] route is registered [grep: /login in src/router.rs]
  - [ ] unauthenticated request is rejected [http: GET http://localhost:8080/admin -> 401]
  - [ ] authenticated request succeeds [http: GET http://localhost:8080/admin -> 200]
  ```

- **Bump a dependency / version.**
  ```
  - [ ] Cargo.lock updates [grep: ^name = "tokio"$ in Cargo.lock]
  - [ ] build still passes [shell: cargo build]
  - [ ] test suite still passes [shell: cargo test]
  ```

- **Remove a TODO / dead code.**
  ```
  - [ ] TODO is removed [no-grep: TODO in src/main.rs]
  - [ ] crate still compiles [shell: cargo build]
  ```
  Prefer `[no-grep:]` over `[shell: ! grep -q ...]` — a wrong filename makes the shell negation silently pass; `[no-grep:]` fails on an unreadable file instead.

- **Delete a file.**
  ```
  - [ ] legacy config is gone [file-absent: config/legacy.toml]
  - [ ] crate still compiles [shell: cargo build]
  ```

- **Docs-only / editorial.**
  ```
  - [ ] new section is present [grep: ## Health check in docs/runbook.md]
  - [ ] the prose reads sensibly [manual]
  ```

## Anti-patterns to refuse

- **Bare criterion with no hint.** `- [ ] feature works` is a validation error. If automation cannot prove it, write `[manual]` explicitly.
- **Hint that doesn't test the criterion.** `- [ ] rate limit is 100 req/min [shell: cargo build]` — the build passing proves nothing about the threshold. Either find the right test or rewrite the criterion to one you can test.
- **Tautological hint.** `- [ ] README mentions auth [grep: auth in README.md]` against a README that already says "auth" thirty times. Pick a string that the change is supposed to introduce.
- **One mega-criterion bundling many checks.** Multiple hints on one line are AND'd — that's fine for tight semantics ("endpoint is live and fast"). Don't use it to compress "implement the whole feature" into one line; break into separate criteria so failures point at the specific gap.
- **Touching the leading checkbox.** `- [x] ...` is never read by Zurdo. Always emit `- [ ]`.

## Procedure

1. **Read the task heading, metadata, and description.** Understand the deliverable before drafting criteria.
2. **Identify the headline outcome.** What proves the task is *done*? Write that criterion first.
3. **Identify obvious failure modes.** What proves the task is *correct*? One or two edge-case criteria.
4. **Pick the cheapest hint per criterion.** Apply the heuristics above.
5. **Mark unautomatable criteria `[manual]`.** Be explicit; the parser requires the hint.
6. **Sanity-check by reading the block back.** Each line should be testable by a stranger holding only the PRD and the codebase.
7. **Apply with Edit.** Replace the empty / weak `### Acceptance Criteria` block in place; do not touch metadata or description.
8. **Verify.** Suggest the user run `zurdo --analyze --static-only <prd>` — clean output means the criteria block parses; any error gets reported with a line number.
