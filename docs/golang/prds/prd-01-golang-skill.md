# PRD: Comprehensive `golang` Authoring Skill

Build an authoring-first Go skill at `skills/programing-languages/golang/`. The skill activates when a coding agent writes or modifies Go source, and steers it toward idiomatic, well-named, well-tested, correctly-concurrent Go. Structure is progressive disclosure: a lean, standalone `SKILL.md` spine carrying the high-frequency decision rules inline, plus five on-demand `references/*.md` files for depth.

This PRD pins the distilled substance of 17 authoritative sources (Effective Go, Go Proverbs, Rob Pike and Russ Cox essays, the Go Memory Model, the Google Go Style Guide trio, and the Google Testing Blog series) into each task's Description so the work is reviewable and gradeable. Each task should ALSO `WebFetch` its listed source URLs to enrich and verify the pinned points — but if a fetch fails, the pinned key points are sufficient to complete the task (graceful degradation).

Verification philosophy: artifacts are prose, so each task gates on `file-exists` for the artifact plus one or more `[manual]` criteria that enumerate the required concepts as an explicit rubric for the analyzer. Concept-grep on generated prose is intentionally avoided (brittle exact-string matching). `grep`/`no-grep` are used only on the final integration task, and only against deterministic, author-controlled link-path strings.

Run order is sequential (Zurdo is not parallel); the `Depends-on` edges enforce scaffold → references → integration ordering and gating. Throughout, the executor must follow `superpowers:writing-skills` discipline: correct frontmatter, progressive disclosure, terse imperative voice, no filler.

## Task: task-skill-scaffold — Scaffold the golang SKILL.md standalone spine
**Effort**: medium
**Depends-on**: []
**Skills**: writing-skills

### Description

Create the directory `skills/programing-languages/golang/` and author `skills/programing-languages/golang/SKILL.md` as a **standalone working guide** (not a thin index). Also create the empty `skills/programing-languages/golang/references/` directory so later tasks can populate it.

Frontmatter requirements:
- `name: golang`
- `description:` — tightly scoped to "writing or modifying Go source," phrased so the skill does NOT over-trigger on unrelated mentions of Go. Make clear it covers idioms, naming/style, testing discipline, and concurrency/memory correctness.

Body requirements — `SKILL.md` carries the **high-frequency decision rules inline** so the common case needs no reference load. Each rule is terse: an imperative line plus a one-line "why," then an arrow `→ see references/<file>.md` pointing to depth. The inline rules MUST include at least:
- Run `gofmt`; style is non-negotiable. → references/naming-and-style.md
- Accept interfaces, return concrete types; keep interfaces small ("the bigger the interface, the weaker the abstraction"). → references/idioms.md
- Make the zero value useful; prefer `new` for zeroed pointers, `make` for slices/maps/channels. → references/idioms.md
- Errors are values: return them, wrap with `%w`, handle them — don't just check; don't panic in libraries. → references/idioms.md
- Naming: `MixedCaps` not snake_case; name length proportional to scope; no `Get` prefix on getters; short lowercase package names; uniform-case initialisms (`URL`, `ID`, `HTTP`); error strings lowercase with no trailing punctuation. → references/naming-and-style.md
- Don't communicate by sharing memory; share memory by communicating; a data race is always a bug — run `-race`. → references/concurrency-and-memory.md
- Table-driven tests with `t.Run` subtests are the default; test observable state over interactions; avoid change-detector tests. → references/testing.md
- Treat style rules as guidelines with tradeoffs, not dogma; don't reach for `regexp` to lex/parse structured input. → references/philosophy.md

The body must contain a "References" section that links all five reference files (`references/idioms.md`, `references/naming-and-style.md`, `references/testing.md`, `references/concurrency-and-memory.md`, `references/philosophy.md`) with a one-line description of each, so the spine is wired to its depth files from the start.

Do not write placeholder/TODO markers; every section is real content.

### Acceptance Criteria

- [ ] SKILL.md exists at the skill path [file-exists: skills/programing-languages/golang/SKILL.md]
- [ ] Frontmatter is correct: `name: golang` and a tightly-scoped `description` limited to writing/modifying Go source so it does not over-trigger [manual]
- [ ] SKILL.md is a standalone working guide carrying inline high-frequency decision rules (gofmt, accept-interfaces/return-concrete + small interfaces, useful zero value, new-vs-make, errors-are-values/%w/handle/don't-panic, MixedCaps + scope-proportional naming + no-Get-getters + initialism casing + error-string rules, share-by-communicating + race-is-a-bug, table-driven-tests-default + state-over-interaction, rules-not-dogma + no-regexp-for-parsing), each as a terse rule + one-line why + an arrow to the relevant reference file [manual]
- [ ] SKILL.md has a References section linking all five reference files with a one-line description each [manual]

## Task: task-ref-idioms — Write references/idioms.md
**Effort**: high
**Depends-on**: [task-skill-scaffold]
**Max-Attempts**: 4
**Skills**: writing-skills
**Agent-timeout**: 45m

### Description

Author `skills/programing-languages/golang/references/idioms.md` — the long-form synthesis of Go idioms. Sources to `WebFetch` and faithfully distill: https://go.dev/doc/effective_go , https://go-proverbs.github.io/ , https://commandcenter.blogspot.com/2012/06/less-is-exponentially-more.html .

Pinned required coverage (the distilled spec — the file must cover all of it, with short idiomatic Go examples where they aid understanding):

Effective Go mechanics:
- Formatting/`gofmt` (tabs, braces-on-same-line via semicolon insertion, canonical and non-negotiable); doc comments precede the declaration.
- Naming: short lowercase single-word package names, no stutter (`bufio.Reader`, `ring.New`); getters without `Get`; one-method interfaces named `<method>-er` (`Reader`, `Writer`, `Stringer`); MixedCaps; capitalization controls export.
- Control structures: no parens; if-with-init (`if err := f(); err != nil`); omit `else` after a terminating `return`; `for` is the only loop (3-clause / while / range / infinite); `range` over string yields runes; expression-less `switch`, comma cases, no auto-fallthrough; type switch `switch v := x.(type)`.
- Functions: multiple return values (`(result, err)`); named result parameters + bare return; `defer` (LIFO, args evaluated at defer time, pairs acquire/release).
- Data: `new(T)` (zeroed `*T`) vs `make` (initialized slice/map/channel); composite literals; arrays are values vs slices are references with len/cap (`append`/`copy`, must reassign append's result); maps (comma-ok, `delete`, sets as `map[T]bool`); printing (`fmt` verbs, `Stringer`); constants/`iota`/`init`.
- Methods: pointer vs value receivers and how the method set affects interface satisfaction.
- Interfaces: implicit (structural) satisfaction; small behavioral contracts; implementing on function types (`http.HandlerFunc`); the blank identifier `_` (discard, side-effect imports, compile-time interface checks `var _ Iface = (*T)(nil)`); struct/interface embedding and method promotion.
- Concurrency primitives at an idiom level: goroutines (`go f()`), channels (unbuffered=sync, buffered as semaphore), `select` with `default`; errors as the `error` interface with custom error types; `panic`/`recover` only for the unrecoverable.

Go Proverbs — list ALL 19 VERBATIM:
1. Don't communicate by sharing memory, share memory by communicating.
2. Concurrency is not parallelism.
3. Channels orchestrate; mutexes serialize.
4. The bigger the interface, the weaker the abstraction.
5. Make the zero value useful.
6. interface{} says nothing.
7. Gofmt's style is no one's favorite, yet gofmt is everyone's favorite.
8. A little copying is better than a little dependency.
9. Syscall must always be guarded with build tags.
10. Cgo must always be guarded with build tags.
11. Cgo is not Go.
12. With the unsafe package there are no guarantees.
13. Clear is better than clever.
14. Reflection is never clear.
15. Errors are values.
16. Don't just check errors, handle them gracefully.
17. Design the architecture, name the components, document the details.
18. Documentation is for users.
19. Don't panic.

Pike, "Less is exponentially more": Go's simplicity (no inheritance, no exceptions, no type taxonomy) is the source of its expressive power; composition over inheritance (interfaces + embedding describe capability, not lineage); concurrency is not parallelism; why C++ programmers resist Go ("minimize programmer effort" vs "exquisite control"). Preserve the quote "Less can be more. The better you understand, the pithier you can be."

### Acceptance Criteria

- [ ] idioms.md exists [file-exists: skills/programing-languages/golang/references/idioms.md]
- [ ] Covers Effective Go mechanics: formatting/gofmt, naming/no-stutter, control structures (if-init, omit-else, for-only loop, range-over-runes, type switch), functions (multiple returns, named results, defer), data (new vs make, slices/arrays/maps, append-reassign), methods (pointer vs value receivers and method sets), interfaces (implicit satisfaction, small contracts, function types), the blank identifier (discard, side-effect imports, compile-time interface checks), and embedding/method promotion [manual]
- [ ] Lists all 19 Go Proverbs verbatim [manual]
- [ ] Captures Pike's "Less is exponentially more" thesis: simplicity as expressive power, composition over inheritance, concurrency-not-parallelism, and the minimize-effort-vs-exquisite-control divide [manual]
- [ ] Reads as a coherent reference with terse decision rules and short idiomatic Go examples; no filler, no TODO markers [manual]

## Task: task-ref-naming-style — Write references/naming-and-style.md
**Effort**: medium
**Depends-on**: [task-skill-scaffold]
**Skills**: writing-skills

### Description

Author `skills/programing-languages/golang/references/naming-and-style.md` — the long-form naming and style reference. Sources to `WebFetch` and distill: https://google.github.io/styleguide/go/guide , https://google.github.io/styleguide/go/decisions , https://google.github.io/styleguide/go/best-practices , https://testing.googleblog.com/2017/10/code-health-identifiernamingpostforworl.html .

Note on the identifier-naming blog post: its body may not render via fetch; its thesis — **name length should be proportional to scope size** (long descriptive names for package/global identifiers, short names like `i`/`r` for tight local scopes, omit words the scope already implies) — is also codified in the Style Decisions "variable names" section, so cover it confidently from there if the post is unreachable.

Pinned required coverage:
- The readability priority hierarchy (earlier overrides later when in conflict): **Clarity > Simplicity > Concision > Maintainability > Consistency**, and the principle that code is read far more than written.
- The document relationship: the **Guide** is normative/canonical (principles); **Decisions** records specific rulings (non-canonical elaboration); **Best Practices** documents optional patterns (explicitly non-canonical). Local consistency never overrides a documented principle.
- Naming rulings from Decisions: `MixedCaps`/`mixedCaps` (never snake_case or `ALL_CAPS`); receiver names (1–2 chars, abbreviation of the type, consistent across all methods, `_` if unused); package names (short, lowercase, single word, no underscores, no plurals, never `util`/`common`/`helper`); getters (no `Get` prefix; `Counts()` not `GetCounts()`); initialisms (uniform case: `URL`, `ID`, `DB`, `HTTP`; mixed-case initialisms like `gRPC`/`iOS` follow exportedness); constants name meaning not value, MixedCaps (`MaxPacketSize` not `MAX_PACKET_SIZE`); avoid stutter (`widget.New` not `widget.NewWidget`).
- Error conventions: error strings lowercase with no trailing punctuation; sentinel errors `ErrFoo`, error types `FooError`, `error` is the last return; add only new context, wrap with `%w` internally / `%v` at boundaries with `%w` last; never signal errors in-band (return `(value, ok)` or `error`, never -1/"").
- Control flow & formatting: handle the error path first and keep the happy path unindented (avoid `else`); no fixed line length (refactor rather than wrap); prefer `nil` slices (`var s []int`, test with `len(s) == 0`); `:=` for non-zero init vs `var x T` when the zero value will be used; `%q` for strings in diagnostics.
- Imports & docs: group standard / other / side-effect imports; no dot imports; avoid renaming except collisions/protos; every exported symbol has a doc comment starting with its name as a full sentence; package comment directly above `package` in one file.
- Functions, options, tests: drop redundant words from names (types, receiver, package, params); option-struct vs functional-options patterns; useful test failures (got/want, `cmp.Diff`, `t.Helper()`, `t.Fatal` for setup vs `t.Error` in table rows).
- The identifier-naming rule: name length proportional to scope; encode information scent (units/semantics) — `GetElapsedFrameTimeSecs` over `GetTime`; omit obvious context (`count` not `userCount` inside `UserCount()`).
- Include the instructive bad→good examples: `widget.NewWidget`→`widget.New`, `GetCounts()`→`Counts()`, `Url`/`Id`/`Http`→`URL`/`ID`/`HTTP`, `MAX_PACKET_SIZE`→`MaxPacketSize`, `func (tray Tray)`→`func (t Tray)`.

### Acceptance Criteria

- [ ] naming-and-style.md exists [file-exists: skills/programing-languages/golang/references/naming-and-style.md]
- [ ] Presents the readability hierarchy (Clarity > Simplicity > Concision > Maintainability > Consistency) and the Guide/Decisions/Best-Practices document relationship [manual]
- [ ] Covers the naming rulings: MixedCaps, receiver names, package names, no-Get getters, initialism casing, constant naming, and stutter avoidance — with at least the bad→good examples (widget.New, Counts(), URL/ID/HTTP, MaxPacketSize) [manual]
- [ ] Covers error conventions (lowercase no-punctuation strings, ErrFoo/FooError, %w internal vs %v boundary, no in-band errors), control-flow/formatting rules (error-path-first, no fixed line length, nil slices, := vs var, %q), import grouping, and doc-comment rules [manual]
- [ ] States the scope-proportional naming rule with information-scent examples (GetElapsedFrameTimeSecs vs GetTime; omit obvious context) [manual]
- [ ] Reads as a coherent reference; no filler, no TODO markers [manual]

## Task: task-ref-testing — Write references/testing.md
**Effort**: medium
**Depends-on**: [task-skill-scaffold]
**Skills**: writing-skills

### Description

Author `skills/programing-languages/golang/references/testing.md` — the testing-discipline reference, mapping language-agnostic principles onto Go's table-driven style. Sources to `WebFetch` and distill: https://testing.googleblog.com/2013/03/testing-on-toilet-testing-state-vs.html , https://testing.googleblog.com/2014/05/testing-on-toilet-effective-testing.html , https://testing.googleblog.com/2014/05/testing-on-toilet-risk-driven-testing.html , https://testing.googleblog.com/2015/01/testing-on-toilet-change-detector-tests.html .

Pinned required coverage:
- **State vs. interaction testing** — prefer testing observable state (the results returned) over interactions (which methods were called); a passing interaction test proves a call happened, not correctness. Test interactions only when correctness depends on *how* the output is produced (call count/order/side-effects matter — e.g. a single email side-effect, bounded reads, deadlock-prone ordering; or MVC/MVP view-method assertions).
- **Effective testing = fidelity × resilience × precision** — fidelity (fails when the code is broken; cover all paths, assert all relevant state); resilience (fails ONLY on a breaking change — test the exposed API not internals, favor stubs/fakes over mocks, don't verify interactions unless that's the contract; flaky tests have low resilience); precision (a failure pinpoints the defect — small focused tests, descriptive names). These three are in tension; the empty test is maximally resilient but worthless.
- **Risk-driven testing** — "Tests are a means to an end: to reduce the key risks of a project, and to get the biggest bang for the buck." Brainstorm and write down key risks first; pick the cheapest effective mitigation. Extensive tests can give a false sense of safety while leaving the real risk untested; coverage of trivial code is wasted effort.
- **Change-detector tests considered harmful** — a test that restates the implementation (a "transformation of the same information in the code under test", e.g. a mock-and-verify-in-order echo of the internal call sequence) catches no defects, breaks on every refactor, and provides negative value; rewrite or delete it.
- **Go mapping** — table-driven tests (`[]struct{name, in, want}` iterated with `t.Run(tc.name, ...)`) are the default Go idiom and are state-testing by construction; use subtests via `t.Run`; call `t.Helper()` in shared assertion helpers; prefer real objects then fakes then mocks; test the package's exported API (external `_test` package where practical); `t.Fatal` for setup/blocking failures vs `t.Error`+continue inside table rows; never `t.Fatal` from a goroutine.
- **Anti-patterns** — change-detector/tautological tests, over-mocking / unnecessary interaction verification, testing implementation details, coverage-chasing trivial code, big unfocused end-to-end tests as the default.
- Preserve at least these quotes: "Tests are a means to an end: To reduce the key risks of a project, and to get the biggest bang for the buck." and "A correct or incorrect program is equally likely to pass a test that is a derivative of the code under test."

### Acceptance Criteria

- [ ] testing.md exists [file-exists: skills/programing-languages/golang/references/testing.md]
- [ ] Covers all four principles: state-vs-interaction (prefer state; when interactions are justified), effective testing (fidelity/resilience/precision and their tension), risk-driven testing, and change-detector tests as harmful [manual]
- [ ] Maps the principles to Go: table-driven tests with t.Run as the default, t.Helper, real-over-fakes-over-mocks ordering, testing the exported API, and t.Fatal-vs-t.Error usage [manual]
- [ ] Enumerates the anti-patterns (change-detector tests, over-mocking, testing internals, coverage-chasing, default end-to-end) and preserves the two pinned quotes [manual]
- [ ] Reads as a coherent reference; no filler, no TODO markers [manual]

## Task: task-ref-concurrency-memory — Write references/concurrency-and-memory.md
**Effort**: high
**Depends-on**: [task-skill-scaffold]
**Max-Attempts**: 4
**Skills**: writing-skills
**Agent-timeout**: 45m

### Description

Author `skills/programing-languages/golang/references/concurrency-and-memory.md` — the most technically subtle reference. Accuracy is paramount; do not hand-wave. Sources to `WebFetch` and distill: https://go.dev/ref/mem , https://research.swtch.com/godata , https://research.swtch.com/interfaces .

CRITICAL ACCURACY REQUIREMENT — version drift: Russ Cox's "Go Data Structures" essays date to 2009 and describe a 32-bit reference machine where a word-sized value could be stored DIRECTLY in the interface data word. That direct-storage optimization was REMOVED in Go 1.4 — modern Go always stores a pointer in the interface's data word. Present the 2009 word-size and direct-storage details explicitly as HISTORICAL ILLUSTRATION, and state the CURRENT semantics: the interface data word holds a pointer; the runtime distinguishes `iface` (itable + data pointer) from `eface` (`*_type` + data pointer) for the empty interface. Do not present the historical 32-bit/direct-storage details as current fact.

Pinned required coverage:
- **The Go Memory Model**: happens-before as a partial order (a read observes a write only if that write happens-before the read with no intervening write); the modern formulation as the transitive closure of **sequenced-before** (intra-goroutine) and **synchronized-before** (inter-goroutine) (Go 1.19+ reformalization; older happens-before rules still valid); **data races are undefined behavior** (with limited backstops: word-sized reads observe some real write, no out-of-thin-air values; races on multiword values — maps/slices/interfaces — can corrupt memory); **DRF-SC** (data-race-free programs are sequentially consistent, matching C/C++/Java/Rust/Swift); the advice "If you must read the rest of this document to understand the behavior of your program, you are being too clever. Don't be clever."
- **Synchronization edges** (state them precisely): package init/import ordering; the `go` statement is synchronized-before the new goroutine's start; goroutine EXIT is NOT synchronized-before anything; channel send synchronized-before the corresponding receive's completion; close synchronized-before a receive that returns zero; unbuffered receive synchronized-before the send's completion; the kth receive on a capacity-C channel synchronized-before the (k+C)th send (buffered channel as bounded semaphore); `sync.Mutex`/`RWMutex` (nth Unlock synchronized-before mth Lock for n<m); `sync.Once` (the single f() synchronized-before any Do returns); `sync/atomic` (SC atomics = C++ SC / Java volatile).
- **Memory layout (godata)**: the machine **word**; `int`/`int32`/`float` = one word; `Point{X,Y int}` = two adjacent words; `*Point` = one word; programmer controls what is/ isn't a pointer (inline embedding vs pointer); **string = 2 words** (data pointer + length, immutable, slicing shares bytes); **slice = 3 words** (pointer + len + cap, a reference into a backing array, slicing copies nothing); `new(T)` returns `*T` to zeroed memory vs `make(T,…)` returns `T`.
- **Interfaces (interfaces)**: an interface value is **two words** = itable pointer + data pointer; the **itable** holds type metadata plus an array of function pointers for exactly the interface's methods; itable is computed by matching the interface's methods against the concrete type's method table (often statically at compile/link time, or by the runtime on first assignment and cached); **method dispatch** is an indirect call through the itable (`s.tab->fun[0](s.data)`); type assertions/conversions; cost model (lookup paid at assignment, each call is a couple of fetches + an indirect call); the `iface`/`eface` distinction noted above.
- **Decision rules**: share memory by communicating (pass ownership over a channel); a data race is always a bug — run `-race`; never invent your own synchronization (use `sync` or channels, not bare flags); never busy-wait on an unsynchronized variable (`for !done {}` may never terminate and guarantees nothing); don't rely on goroutine exit ordering; publish data BEFORE the synchronizing send/unlock/atomic-store and read it AFTER the matching receive/lock/load; know that slice/string/map/channel/interface are header/reference-like (a race on a multiword header can corrupt memory).

### Acceptance Criteria

- [ ] concurrency-and-memory.md exists [file-exists: skills/programing-languages/golang/references/concurrency-and-memory.md]
- [ ] Explains the memory model accurately: happens-before, sequenced-before/synchronized-before, data-race-as-undefined-behavior, DRF-SC, and the "don't be clever" advice [manual]
- [ ] States the synchronization edges precisely (go statement, goroutine-exit-is-not-synchronized, channel send/receive/close, buffered-channel-as-semaphore, Mutex, Once, atomic) [manual]
- [ ] Covers memory layout (word, struct, string=2 words, slice=3 words, new vs make) and interface representation (two words = itable + data pointer, itable contents, method dispatch, cost model) [manual]
- [ ] Correctly flags the Russ Cox 2009 essays' 32-bit word-size and direct-data-word storage as HISTORICAL, and states the CURRENT semantics (data word holds a pointer since Go 1.4; iface vs eface) — does not present the historical details as current fact [manual]
- [ ] Gives concrete concurrency decision rules (share-by-communicating, run -race, no ad-hoc synchronization, no busy-wait on unsynchronized vars, publish-before/read-after the synchronizing op) [manual]
- [ ] Reads as a coherent, accurate reference; no filler, no TODO markers [manual]

## Task: task-ref-philosophy — Write references/philosophy.md
**Effort**: medium
**Depends-on**: [task-skill-scaffold]
**Skills**: writing-skills

### Description

Author `skills/programing-languages/golang/references/philosophy.md` — the design-ethos reference that helps an agent make judgment calls in the spirit of Go. Sources to `WebFetch` and distill: https://research.swtch.com/dogma , https://commandcenter.blogspot.com/2011/12/esmereldas-imagination.html , https://commandcenter.blogspot.com/2011/08/regular-expressions-in-lexing-and.html . Summarize what each essay actually argues (verify via fetch; don't infer from the title).

Pinned required coverage:
- **Cox, "Dogma"**: language design is engineering — every decision is a tradeoff made at a moment in time, never an infallible commandment; the tell of dogma is "that's just not how it's done here" (a non-argument); designers remember rejected alternatives had genuine merit; think for yourself and weigh costs/benefits. Preserve: "Remember that none of the decisions in Go are infallible; they're just our best attempts at the time we made them."
- **Pike, "Esmerelda's Imagination"**: the framing anecdote (the actress who "can't imagine being anything except an actress" — "You can't be much of an actress then, can you?"); the analog that "I can't imagine programming without feature X" reveals the limits of the complainer's imagination, not a defect of the language; a language is not a substrate for translating another language into it (Go is not Java-in-Go) — each language demands reorientation to its own idioms; authority comes from "experience and insight, which require practice and imagination. And maybe some programming." Preserve the vituperation quote about "a few extra keystrokes."
- **Pike, "Regular Expressions in Lexing and Parsing"**: regexps are the wrong tool for lexing/parsing compile-time-known grammars in production — prefer a hand-written lexer / simple state machine or a real parser; reasons: performance (hidden regexp-engine overhead, especially capturing submatches), heavyweight ("like using a Mack truck to go to the store for milk"), adaptability (hand lexers absorb Unicode/normalization gracefully), and endemic misuse (most programmers don't understand regexps); reserve regexps for DYNAMIC pattern discovery (editors, search, grep), not static grammars.
- **Decision rules / dispositions**: treat style rules as guidelines with tradeoffs, not dogma; reject "that's how it's done here" as a justification; hold your own decisions as fallible best-attempts and explain both sides; learn a language on its own terms before criticizing it; spend effort solving the problem rather than writing complaint; don't reach for `regexp` to parse structured input — write a state machine or use a real parser; reserve regexp for dynamic patterns; prefer clear, simple, explicit code over clever or heavyweight abstraction.

### Acceptance Criteria

- [ ] philosophy.md exists [file-exists: skills/programing-languages/golang/references/philosophy.md]
- [ ] Faithfully summarizes all three essays: Cox's "Dogma" (rules are engineering tradeoffs, not commandments), Pike's "Esmerelda's Imagination" (the imagination point; learn a language on its own terms), and Pike's regexp essay (don't use regexp to lex/parse static grammars; reserve it for dynamic patterns) [manual]
- [ ] Preserves the key quotes (the "none of the decisions in Go are infallible" line, the Esmerelda framing, and the "Mack truck"/regexp line) [manual]
- [ ] Gives actionable dispositions (rules-not-dogma, learn-the-language-on-its-terms, no-regexp-for-structured-parsing, prefer-clear-simple-code) [manual]
- [ ] Reads as a coherent reference; no filler, no TODO markers [manual]

## Task: task-integrate-verify — Wire SKILL.md to references and run a coherence pass
**Effort**: medium
**Depends-on**: [task-ref-idioms, task-ref-naming-style, task-ref-testing, task-ref-concurrency-memory, task-ref-philosophy]
**Skills**: writing-skills

### Description

Final integration pass over the completed skill. With all five reference files now present, verify and, where needed, repair the cross-wiring and coherence of `skills/programing-languages/golang/SKILL.md` and its `references/` directory:
- Ensure `SKILL.md` links each of the five reference files by their exact relative path (`references/idioms.md`, `references/naming-and-style.md`, `references/testing.md`, `references/concurrency-and-memory.md`, `references/philosophy.md`), and that every inline decision rule's `→ see references/…` arrow points to a file that exists.
- Ensure there are no leftover `TODO`, `TKTK`, `FIXME`, or placeholder markers anywhere under the skill directory.
- Read the whole skill end to end for coherence: the inline SKILL.md rules must be consistent with the depth in the reference files (no contradictions), terminology is consistent, and the voice is terse and imperative throughout. Fix any drift.

Do not introduce new top-level sections or rename files; this is a wiring-and-coherence pass, not a rewrite.

### Acceptance Criteria

- [ ] SKILL.md links references/idioms.md [grep: references/idioms.md in skills/programing-languages/golang/SKILL.md]
- [ ] SKILL.md links references/naming-and-style.md [grep: references/naming-and-style.md in skills/programing-languages/golang/SKILL.md]
- [ ] SKILL.md links references/testing.md [grep: references/testing.md in skills/programing-languages/golang/SKILL.md]
- [ ] SKILL.md links references/concurrency-and-memory.md [grep: references/concurrency-and-memory.md in skills/programing-languages/golang/SKILL.md]
- [ ] SKILL.md links references/philosophy.md [grep: references/philosophy.md in skills/programing-languages/golang/SKILL.md]
- [ ] No TODO placeholder markers remain in SKILL.md [no-grep: TODO in skills/programing-languages/golang/SKILL.md]
- [ ] The skill reads coherently end to end: inline SKILL.md rules are consistent with the reference files, terminology is consistent, and the voice is terse and imperative throughout [manual]
