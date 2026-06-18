---
name: golang
description: Use when writing or modifying Go source code — covers Go idioms, naming conventions, style discipline, concurrency correctness, and testing patterns. Does NOT trigger on incidental mentions of Go in architecture discussions, dependency lists, or non-Go files.
---

# Go

## Overview

Go rewards simplicity and explicitness. The language was designed with a small feature set and strong conventions; fighting them costs readability and correctness. Apply these rules when authoring or reviewing `.go` files.

---

## High-Frequency Decision Rules

### Style

**Run `gofmt` on every file; style is non-negotiable.**
Why: `gofmt` eliminates entire classes of style debate and keeps diffs clean. No manual formatting ever wins.
→ see references/naming-and-style.md

---

### Interfaces & Types

**Accept interfaces, return concrete types; keep interfaces small.**
Why: Small interfaces (one or two methods) are composable and testable. "The bigger the interface, the weaker the abstraction" (Rob Pike). Callers should define the interfaces they need, not packages.
→ see references/idioms.md

---

### Zero Values & Allocation

**Make the zero value useful; prefer `new` for zeroed pointers, `make` for slices/maps/channels.**
Why: Relying on zero values eliminates unnecessary constructors. `make` initialises the internal structure of reference types that would otherwise be nil and panic on first use.
→ see references/idioms.md

---

### Error Handling

**Errors are values: return them, wrap with `%w`, handle them — don't just log-and-continue; don't `panic` in libraries.**
Why: Panics unwind the entire stack and are inappropriate for recoverable conditions. `%w` preserves the error chain for `errors.Is`/`errors.As`. Callers deserve the chance to decide what to do.
→ see references/idioms.md

---

### Naming

**`MixedCaps` not `snake_case`; name length proportional to scope; no `Get` prefix on getters; short lowercase package names; uniform-case initialisms (`URL`, `ID`, `HTTP`); error strings lowercase with no trailing punctuation.**
Why: These are load-bearing Go conventions — violating them triggers `golint`/`staticcheck` warnings and signals unfamiliarity with the ecosystem to reviewers.
→ see references/naming-and-style.md

---

### Concurrency & Memory

**Don't communicate by sharing memory; share memory by communicating. A data race is always a bug — run `-race` in tests.**
Why: Unsynchronised access to shared state produces undefined behaviour that is invisible until production load exposes it. The race detector catches races at runtime; there is no excuse for shipping code that fails `-race`.
→ see references/concurrency-and-memory.md

---

### Testing

**Table-driven tests with `t.Run` subtests are the default; test observable state over interactions; avoid change-detector tests.**
Why: Table-driven tests add coverage with minimal boilerplate and surface regressions at the case level. Testing observable state makes tests resilient to refactors. Change-detector tests (that mirror implementation structure) break on every rename without catching real bugs.
→ see references/testing.md

---

### Philosophy

**Treat style rules as guidelines with tradeoffs, not dogma; don't reach for `regexp` to lex/parse structured input.**
Why: Go's own style guide acknowledges exceptions. Forcing a rule that makes the code worse is wrong. Regular expressions applied to structured grammars (JSON, SQL, HTML) are fragile; use a proper parser.
→ see references/philosophy.md

---

## References

| File | What it covers |
|------|----------------|
| [references/idioms.md](references/idioms.md) | Accept-interfaces/return-concrete, zero values, `new` vs `make`, error handling patterns, `%w` wrapping, avoiding `panic` in libraries |
| [references/naming-and-style.md](references/naming-and-style.md) | `MixedCaps`, scope-proportional name length, package naming, initialism casing, getter naming, error string rules, `gofmt` enforcement |
| [references/testing.md](references/testing.md) | Table-driven tests, `t.Run` subtests, testing observable state, avoiding change-detector tests, `testify` vs stdlib tradeoffs |
| [references/concurrency-and-memory.md](references/concurrency-and-memory.md) | Channel discipline, `sync` primitives, the race detector (`-race`), goroutine lifecycle, context cancellation |
| [references/philosophy.md](references/philosophy.md) | When to break style rules, choosing simplicity over cleverness, avoiding `regexp` for structured input, Go's explicit-over-magic stance |
