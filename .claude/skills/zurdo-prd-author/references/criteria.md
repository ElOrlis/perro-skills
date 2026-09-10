# Authoring acceptance criteria

The `### Acceptance Criteria` block for a single Zurdo task — every line a `- [ ]` GFM checkbox with at least one hint from the §3.1 closed enum, sized to prove the criterion without over-checking.

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

## The seven core hint types (§3.1)

| Hint syntax | Passes when |
|---|---|
| `[shell: <cmd>]` | shell exits 0 (runs at repo root) |
| `[http: <method> <url> -> <status>]` | HTTP response status equals `<status>` — see "HTTP body assertion" below for the `contains` modifier |
| `[file-exists: <path>]` | file exists at `<path>` relative to repo root |
| `[file-absent: <path>]` | no file exists at `<path>` relative to repo root |
| `[grep: <pattern> in <file>]` | `<pattern>` is found in `<file>` |
| `[no-grep: <pattern> in <file>]` | `<pattern>` is NOT found in `<file>` (fails if file is unreadable) |
| `[manual]` | never machine-checked; only affects task status |

The `[manual]` hint co-exists with automated hints on the same line; the automated hints still gate (`[grep: TODO in src/main.rs] [manual]` passes when grep passes; the `[manual]` annotation is informational).

## Structural hints (§3.4)

Three additional hints verify facts about **named code symbols** — existence,
references, and call relationships — via Lumen, Zurdo's tree-sitter structural
index (Rust, Python, Go, TypeScript/JavaScript including TSX/JSX):

```
[symbol: <kind> <qualified-name> in <file>]
[references: <kind> <qualified-name> in <file> within <kind> <qualified-name> in <file>]
[callers: <kind> <qualified-name> in <file> within <kind> <qualified-name> in <file>]
```

**Gate check before authoring any of these.** They require
`[lumen].enabled = true` in `.zurdo/config.toml`. A PRD containing a
structural hint while the gate is off is a **validation error** in every
command that reaches it: `validate`, `analyze` (including the `run --analyze`
sugar), and `run` itself — `run --resume` included, since it funnels through
the same preflight gate. Confirm the user's gate is on — or get their
explicit buy-in to flip it — before writing the first structural criterion.

Grammar rules:

- `<kind>` is one of the closed normalized kinds: `function`, `method`,
  `type`, `class`, `struct`, `enum`, `interface`, `trait`, `module`,
  `constant`, `variable`. `type` means a **type alias only** — Go's
  `type Foo struct { … }` is a `struct`, never a `type`. A wrong kind fails
  with a diagnostic naming the actual kind ("found `struct Config`, not
  `type Config`").
- `<qualified-name>` uses `::` as the lexical-owner separator in every
  language (`Config::load`); top-level names are unqualified.
- `<file>` is an **exact, repository-relative file path**. No globs, no
  directories, no inferring the file from a module name.
- The `within` context on `[references:]`/`[callers:]` is **mandatory** —
  there is no "referenced anywhere in the file" form. Top-level occurrences
  have the file's `module` symbol as their enclosing symbol, e.g.
  `within module main in src/main.rs` (module names derive from the file stem;
  `mod.rs` / `__init__.py` / `index.*` take the parent directory's name; Go
  uses the `package` clause identifier, never the filename).

Semantics — what each one actually proves:

- `[symbol:]` passes only for a **definition** of that kind and name in that
  exact file — a use site or an import never satisfies it.
- `[references:]` passes only when the occurrence inside the `within` symbol
  **deterministically binds** to the target through lexical scope and static
  imports. A same-named identifier from another module is insufficient.
- `[callers:]` additionally requires the bound target in the **callee
  position** of a call expression — a reference passed as a value does not
  count.
- Both the target and the `within` context must each resolve to **exactly
  one** definition; zero or multiple candidates fail with a diagnostic
  listing them.
- Verification favors **false negatives over false greens**: dynamic
  dispatch, trait-object calls, and macro-generated names fail as unresolved
  rather than pass on a text match. Do not author a `[callers:]` hint against
  a call site that only exists behind dynamic dispatch — it will never bind.

When to reach for a structural hint instead of `[grep:]`: when the criterion
is about a *symbol fact* a text match cannot prove — "this function exists
with this kind", "this helper is actually called from this function" — and a
grep would pass on a comment, a string literal, or a same-named import.
When a marker string is all you need, keep using `[grep:]`; it is cheaper and
not gated.

```
- [ ] the retry helper exists [symbol: function retry_with_backoff in src/net/retry.rs]
- [ ] the client uses the helper [callers: function retry_with_backoff in src/net/retry.rs within method Client::send in src/net/client.rs]
- [ ] config is read at startup [references: struct Config in src/config.rs within module main in src/main.rs]
```

## HTTP body assertion

Append `contains "<substring>"` after the status code to add a **body assertion** — the criterion passes only when the response status matches *and* the response body contains the literal, case-sensitive substring:

```
- [ ] health endpoint reports service name [http: GET http://localhost:8080/health -> 200 contains "zurdo"]
- [ ] login returns a token field [http: POST http://localhost:8080/login -> 200 contains "\"token\""]
```

Rules:
- The substring must be double-quoted. Unquoted text after the status is a parse error.
- Matching is byte-exact and case-sensitive.
- A `HEAD` request returns no body — a non-empty `contains` clause against `HEAD` always fails.
- The `contains` clause is checked only when the status already matches; a status mismatch is reported without reading the body.

## Timeout modifier

A `[shell:]` hint — and only a `[shell:]` hint — may carry a per-criterion **timeout modifier** that overrides the global `timeouts.criterion_seconds` for that one hint:

```
[shell: <cmd> timeout:<duration>]
```

Duration units: `s`, `m`, `h` — same rules as `**Agent-timeout**`. A bare integer is a parse error. Use the timeout modifier when a single shell criterion legitimately needs more (or less) time than the repo default; raising the global `timeouts.criterion_seconds` for one slow test at the cost of all others is the wrong tradeoff.

**The modifier is shell-only.** `[http:]` accepts no trailing `timeout:` token — `strip_shell_timeout_modifier` runs on the `shell:` payload alone, and `parse_http_hint` recognizes no trailing token but `contains "<substring>"`. Appending `timeout:<duration>` to an `[http:]` hint is a parse error (`malformed http hint`), not a hint with a per-criterion timeout. A slow `[http:]` criterion has no per-criterion escape hatch: raise the global `timeouts.criterion_seconds` in `.zurdo/config.toml` instead, or bring the check under the current default.

The two modifiers never combine on one hint — `contains` is `[http:]`-only, `timeout:` is `[shell:]`-only:

```
- [ ] slow health check returns ok body [http: GET http://localhost:8080/health -> 200 contains "ok"]
- [ ] slow migration completes [shell: cargo run -- migrate timeout:10s]
```

## Sizing the criteria block

Aim for **3–5 criteria per task** as the comfortable range:

- **Fewer than 2** ⇒ the task is probably under-specified; the agent has too little signal that it's done.
- **More than ~6** ⇒ the task is probably too large; consider splitting the task (see the decomposition reference).
- **The golden path is non-negotiable.** Every task needs at least one criterion that proves the headline outcome.
- **One or two edge cases** are usually appropriate when the headline outcome has obvious failure modes (auth: unauthenticated + unauthorized + valid; CRUD: create + read + update + delete).
- **One `[manual]`** is fine where automation cannot reach (UX polish, copy, visual hierarchy). Don't pad with `[manual]` to inflate the count.

## Hint-selection heuristics

For each criterion you write, pick the cheapest hint that proves it. In rough order of cost:

1. `[file-exists:]`, `[file-absent:]`, `[grep:]`, and `[no-grep:]` are nearly free — milliseconds, no subprocess. Use for presence/absence checks, marker strings, version bumps.
2. `[symbol:]`, `[references:]`, and `[callers:]` cost one Lumen index read, with an in-process repair of changed files on first use — heavier than grep, still no subprocess. Use them only for symbol facts a text match cannot prove.
3. `[shell:]` is the workhorse but pays for itself on every iteration. Narrow the command (`cargo test --test foo` over `cargo test`) so a regression elsewhere doesn't drag this criterion down. Narrowing to a filter that matches nothing is not a silent pass: a test runner that exits 0 but reports zero tests run is demoted to failed with `FailureReason::EmptyTestRun`, not treated as green. `criteria/shell.rs` computes this from the untruncated output — libtest's `running 0 tests` and a `go test` package line ending `[no tests to run]` are both recognized — so verify the filter actually matches before locking the hint.
4. `[http:]` requires a running server; pair with a `[shell:]` that brings the server up if needed, or rely on a long-lived dev server the user is responsible for.
5. `[manual]` is the escape hatch; the task short-circuits to `passed-pending-review` if every criterion is manual (§3.2).

When in doubt, prefer **one specific hint** over **two loose hints**. `[shell: cargo test --test login_returns_401_without_password]` is better than `[shell: cargo build] [shell: cargo test]` — the former proves the actual behavior; the latter proves only that things compile and the suite passes.

## Evidence paths feed the executor prompt too

Naming a file in a hint's target — `[grep:]`, `[no-grep:]`, `[file-exists:]`,
`[file-absent:]` — has two consumers now, not one. It still verifies the
criterion at check time. And the same file target also feeds the executor
prompt, as the deduplicated union of every criterion's evidence paths on the
task, rendered in the executor prompt's literal section:

`# Evidence Paths`

That section sits between the criteria and skills sections, and lists each
path annotated present, absent, or frozen. Pick the target path with both
consumers in mind — a vague or wrong path no longer only weakens the check,
it also mis-primes the agent before it writes a single line.

## Patterns by task shape

- **Implement a function or module.**
  ```
  - [ ] module file exists [file-exists: src/auth/login.rs]
  - [ ] crate compiles [shell: cargo build]
  - [ ] login rejects a missing password [shell: cargo test --manifest-path shared/Cargo.toml -- --include-ignored preauthored_task_03]
  - [ ] no pre-authored test for this task is still ignored [no-grep: #\x5bignore in shared/zurdo/tests/preauthored_task_03.rs]
  ```
  The last two criteria are the pre-authored-test convention's shape. A bare
  `cargo test --test login` shell hint, with no marker and no paired guard,
  names no test — a copy of it passes vacuously against a suite that does not
  exist yet. Question 6 (`forcing-questions.md`) forces the same choice on
  every hint that runs a test: pre-author the test now, or decline with a
  reason. See `pre-authored-tests.md` for the full marker-and-guard shape in
  both Rust and Go.

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
- **Hint that doesn't test the criterion.** `- [ ] rate limit is 100 req/min [shell: cargo build]` — the build passing proves nothing about the threshold. Find the right test, pre-author it if it doesn't exist yet (question 6), or rewrite the criterion to one you can test.
- **Tautological hint.** `- [ ] README mentions auth [grep: auth in README.md]` against a README that already says "auth" thirty times. Pick a string that the change is supposed to introduce.
- **Doc-echo hint.** `- [ ] the changelog records the grep-target lint [grep: grep-target lint in CHANGELOG.md]` — the task's own job is to write that phrase into the doc, so the criterion cannot fail; it proves the phrase was typed, not that the claim is true. Remedy: pin a constant the change introduces — a flag, a path, an exit code, a version, or an identifier — rather than a phrase the criterion names, or keep the prose check and add a second hint that verifies the underlying behavior.
- **One mega-criterion bundling many checks.** Multiple hints on one line are AND'd — that's fine for tight semantics ("endpoint is live and fast"). Don't use it to compress "implement the whole feature" into one line; break into separate criteria so failures point at the specific gap.
- **Touching the leading checkbox.** `- [x] ...` is never read by Zurdo. Always emit `- [ ]`.

## The proves modifier

The `proves modifier` links a criterion to a named requirement in the task's
`### Requirements` block. It is a traceability annotation appended after the last
automated hint on the line:

```
- [ ] <criterion text> [<hint>] [proves: <req-id>]
```

A criterion may carry more than one `[proves:]` modifier when it satisfies multiple
requirements:

```
- [ ] health endpoint is live and returns the expected body [http: GET http://localhost:8080/health -> 200 contains "ok"] [proves: req-1] [proves: req-3]
```

Rules:
- `<req-id>` must match a requirement id defined in the task's `### Requirements`
  block (e.g. `req-1`, `req-2`).
- `[proves:]` is never the *only* annotation on a line — at least one automated
  hint or `[manual]` must precede it. It does not replace verification.
- Zurdo flags any requirement that carries no `[proves:]` back-link as the
  **`uncovered-requirement`** lint — one of the same warn-lint families both
  `zurdo validate` and `zurdo analyze` report (see "Anti-patterns to refuse"
  below), not a report-time-only coverage note. `zurdo validate --strict`
  promotes it to a validation error like five of the other six families. It is
  a coverage gap, not a parse error, and an unpromoted run still proceeds.
- The modifier is a **proposal target**: the `zurdo-prd-author` skill drafts
  `[proves:]` assignments from the `### Description` during the interview; the
  author ratifies them before they enter the PRD. Zurdo checks coverage
  deterministically — no LLM logic is involved at run-time.

## Dotfile paths and repository anchoring

Task descriptions often reference dotfiles — `.claude/skills/`, `.agents/config/`,
etc. — meaning either home-directory configs or repo-root configs depending on context.
**An executor resolves a bare dotfile path as `$HOME`, not as the repository root.**

The prevention rule:

- Never write a bare repo-relative dotfile path; always spell out the full path
  explicitly: `<repo-root>/.claude/skills/<name>`.
- Pair every dotfile-editing task with a criterion that can only pass in-tree —
  e.g., `[shell: git diff HEAD --quiet -- .claude/skills/<name> && git diff --quiet HEAD^ HEAD -- .claude/skills/<name> 2>/dev/null && exit 1 || exit 0]`.

**Do not compare against the index with a bare `git diff --quiet` (no
revision argument).** That form passes while the edit is unstaged, but goes
falsely quiet — and the criterion fails — the moment an agent runs `git add`
on the file, and stays quiet after a commit too; agents routinely stage or
commit their own work. The pattern above compares against `HEAD` twice
instead: `git diff HEAD --quiet` catches an edit that is staged or merely
unstaged, and `git diff HEAD^ HEAD` (guarded by `2>/dev/null` for a repo with
no prior commit) catches an edit the agent already committed. The criterion
passes — reports "changed" — if *either* check finds a difference; it only
fails when neither does, i.e. the file is genuinely untouched or does not
exist.

```markdown
- [ ] changes are in-tree, not home [shell: git diff HEAD --quiet -- .claude/skills/auth/SKILL.md && git diff --quiet HEAD^ HEAD -- .claude/skills/auth/SKILL.md 2>/dev/null && exit 1 || exit 0]
```

Generalize this principle to any path that could ambiguously resolve: pair the
task with a verification step that confirms the intended resolution.

## References

- [grep-hints.md](grep-hints.md) — file-vs-directory targets, regex escaping, and why `[no-grep:]` beats `[shell: ! grep …]`
- Spec §3.4 — the full structural-hint grammar, per-language kind-mapping matrices, and module-name derivation tables.
- To debug a *failing* criterion at run-time, use the hint-debugger skill.
