# Grep hint correctness

## The target must be a file, not a directory

`[grep: <pattern> in <path>]` and `[no-grep: <pattern> in <path>]` require `<path>` to be a
regular file. A directory target **always fails** at run time (0 ms, no disk read); `--analyze`
reports it as `GrepTargetIsDirectory`.

**Wrong — directory target silently never passes:**
```
- [ ] handler is present [grep: fn healthz in src/routes]
- [ ] no legacy TODO [no-grep: TODO in src/]
```

**Right — point at the file:**
```
- [ ] handler is present [grep: fn healthz in src/routes/health.rs]
- [ ] no legacy TODO [no-grep: TODO in src/main.rs]
```

If the string could appear in multiple files, either pick the most specific file or use a
`[shell: grep -r ...]` hint instead.

## The pattern is a regex — escape literal characters

The pattern is compiled by Rust's `regex` crate. Characters with special regex meaning
(`(`, `)`, `.`, `*`, `+`, `?`, `[`, `]`, `^`, `$`, `{`, `}`, `|`, `\`) must be escaped with
`\` when you mean them literally.

**Wrong — unescaped dot matches any character:**
```
- [ ] version line present [grep: version = "1.0.0" in Cargo.toml]
```

**Right — dots escaped:**
```
- [ ] version line present [grep: version = "1\.0\.0" in Cargo.toml]
```

Patterns compile in multi-line mode, so anchors (`^`, `$`) match at line
boundaries — like command-line `grep` — and are often useful for exact-line
matching:
```
- [ ] single entry [grep: ^name = "zurdo"$ in Cargo.toml]
```
(On zurdo versions before line-anchored matching, `^`/`$` anchored to the whole
file; prefix the pattern with `(?m)` if the PRD must also run on an older binary.)

## Prefer `[no-grep:]` over `[shell: ! grep …]`

A shell negation — `[shell: ! grep -q <pattern> <file>]` — silently passes when the filename
is wrong (grep exits non-zero, `!` flips it to 0). `[no-grep:]` fails explicitly when the
target file is unreadable or missing.

**Wrong — typo in path passes silently:**
```
- [ ] TODO is removed [shell: ! grep -q TODO src/mian.rs]
```

**Right — typo in path fails loudly:**
```
- [ ] TODO is removed [no-grep: TODO in src/main.rs]
```

Always reach for `[no-grep:]` first; drop to `[shell:]` only when you need multi-file or
recursive search.

## Lint families that cover grep hints

Two lint families govern `[grep:]` and `[no-grep:]` criteria:

- **`grep-tautology`**: Detects criteria that pass before any code change. The
  lint is **inert** in two cases:
  - It never examines `[no-grep:]` hints, only `[grep:]` criteria that assert the
    presence of a string.
  - It skips files that do not exist yet in the current working tree. Since PRDs
    often describe files that will be created by the task, a tautology scan at
    the PRD's authoring moment sees many inert `[grep:]` hints. Use
    `zurdo analyze --authoring-state <prd>` to reconstruct the tree from the
    commit when the PRD was added, so the linter sees the baseline before your
    changes shipped.

- **`grep-target-is-directory`**: Enforces that `[grep:]` and `[no-grep:]` hints
  target a file, never a directory. Paths like `src/` or `tests/` always fail at
  run time (0 ms, no disk read) because grep cannot match in a directory.
