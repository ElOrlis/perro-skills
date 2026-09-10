# Pre-authored tests — a test committed red, before the run

A pre-authored test is written and committed **before** the run that makes it
pass, with the PRD, as part of the human review gate. It is the strongest
answer this skill has to the tautology problem: a criterion whose hint runs a
test the executing agent also writes is a criterion the agent controls on both
sides. Pre-authoring moves the assertion outside the agent's reach — the agent
can only make it pass.

The test must be **marked non-running at the PRD commit**, or CI is red on the
commit that opens the review gate. Each language has a marker for that, and
each marker has a paired criterion that forces its removal.

Everything needed to author one is below. Deeper rationale — the bench runs
behind each rule, the rejected alternatives — lives in
`docs/design/pre-authored-tests.md`, which does **not** travel with this skill.

## When the rule fires

Forcing question 6 fires whenever a criterion's hint runs a test. Ask whether
the test can be written now, against the API the task will build. Where the
answer is no — a `[manual]` criterion, or a behavior whose test genuinely
cannot precede its API — record the declination as a one-line reason in the
task's `.trail.md`. An unrecorded exemption is indistinguishable from never
having asked.

## The Rust shape

```markdown
## Task: task-03 — <title>
**Effort**: <key>
**Depends-on**: []

### Description

<…the work…>

The tests marked `#[ignore = "pre-authored: task-03"]` in
`shared/zurdo/tests/preauthored_task_03.rs` are evidence, not scratch. Do not
delete them, weaken their assertions, or change what they assert. The only edit
this task may make to that file is removing the `#[ignore …]` attribute once
the behavior is implemented.

### Acceptance Criteria

- [ ] <the behavior> [shell: cargo test --manifest-path shared/Cargo.toml -- --include-ignored <test_name>]
- [ ] no pre-authored test for this task is still marked non-running [no-grep: #\x5bignore in shared/zurdo/tests/preauthored_task_03.rs]
```

Four things are load-bearing.

**The reason string.** `#[ignore = "pre-authored: <task-id>"]`, keyed to the
task id. That string is the whole difference between a pre-authored test and
permanent quarantine — for a human reader and for any future lint. A bare
`#[ignore]` on a perf gate that is *meant* to stay ignored means something
else, and nothing may retrofit it.

**`-- --include-ignored`, never `--ignored`.** `--ignored` runs *only* ignored
tests, so the moment the agent removes the attribute the filter matches
nothing, the runtime's zero-test demotion fires, and the criterion goes red for
doing exactly the right thing. `--include-ignored` runs both sets and is the
only form correct in all four ignored/done states.

**One file per task.** The paired `[no-grep:]` is file-scoped, so every one of
a task's pre-authored tests lives in a single file named for that task. Go's
per-file build tags force this anyway; Rust adopts it so the two read the same.

**The Description paragraph goes in the task Description.** Not in the PRD
preamble — the preamble is never passed to the executor, so a warning written
there does not exist as far as the run is concerned.

### Why `#\x5b` and not the readable escape

The guard has to match the attribute in **both** spellings: the marked
`#[ignore = "pre-authored: task-03"]` and a bare `#[ignore]` left behind if the
agent strips only the reason string. That means matching the prefix `#[ignore`
with no closing bracket — and an *unclosed* bracket group cannot appear in a
hint body. The tokenizer extracts bracket groups before regex semantics apply,
so the readable form runs on through to the criterion's own terminator and
fails validation with an `unknown hint type` error naming the rest of the line.

A **closed** escaped group validates and matches — but it matches only the bare
attribute, which is precisely the spelling this convention does not use. So the
pattern is the hex escape `#\x5b`, which is the literal `[` with nothing for
the tokenizer to open. Hint patterns compile through the `regex` crate with
multi-line on, so it behaves as written. `#.ignore` also works and reads
better, but `.` matches any character; prefer the escape and say what it is in
the criterion text.

**The trap that follows.** A `no-grep` matches prose as readily as code. A
module-level doc comment in the pre-authored file that spells the attribute
keeps the criterion red forever, no matter what the agent does to the code.
The pre-authored file's header comment must describe the convention **without
spelling the attribute** — and the same applies to any constant inside it. A
constant that needs those bytes is assembled from two fragments.

### The stub rule, and its boundary

`#[ignore]` stops a test **running**, not **compiling**. A pre-authored test
that calls a function which does not exist yet fails `cargo test` at compile
time, and CI is red on the PRD commit — the exact thing the marker exists to
prevent. Such a test therefore ships with the signature stub it calls, in the
same commit:

```rust
pub fn parse_budget(raw: &str) -> Result<Budget, BudgetError> { todo!() }
```

The stub panics, the test fails on that panic, and the run turns it into a real
implementation.

The boundary matters as much as the rule: a test that reaches the new thing
through a **runtime** lookup rather than a named symbol compiles fine today and
fails on a `None`, an empty vector, or a panic. It needs no stub. The rule
binds on missing **symbols**, not on new work.

## The Go shape

```markdown
- [ ] <the behavior> [shell: go test -tags=preauthored -run '^TestX$' -count=1 ./...]
- [ ] no pre-authored test for this task is still tagged [no-grep: //go:build preauthored in internal/x/preauthored_task_03_test.go]
```

- **`//go:build preauthored`** on a dedicated `*_test.go` file, one tag word
  repo-wide. Build tags are per-file, which is what makes one-file-per-task
  structural in Go rather than merely conventional.
- **`-count=1` is mandatory.** Go caches passes, and a cached vacuous pass once
  hid regressions across an entire milestone in a real corpus. Omitting it is
  not a style slip.
- **`-run '^TestX$'` anchored.** Unanchored, `-run TestX` also selects
  `TestXAndSomethingElse` and the criterion silently widens.
- Removing the tag does not break the hint: `-tags=preauthored` is harmless
  once nothing carries the tag, and the test then runs in the default CI
  invocation.

**`t.Skip()` is banned.** A skipped test is a passing package: the zero-test
demotion keys on the `[no tests to run]` marker, which is absent because the
test *was* selected — it just declined to run. It produces exactly the failure
this convention exists to prevent.

## The pre-run check: three ways to be red, one that counts

Before the PRD is committed, run the criterion's hint verbatim. It must fail,
and it must fail **on an assertion**. Three failures look identical from the
outside and only one proves the test can see the behavior.

| Failure at the PRD commit | What it means |
| --- | --- |
| assertion failure, or a `todo!()` panic | **Correct.** The test compiles, runs, and disagrees with today's tree. |
| compile error | The stub is missing. CI is red too. Fix before committing. |
| zero-test demotion | The filter matches nothing — wrong test name, wrong target, or the file is not in the build. |

A pre-authored test that is **green** before the run is a tautology and proves
nothing, exactly as a `[grep:]` for a string already in the file proves
nothing. Record the failing exit on the task's `.trail.md` line, next to the
negative-case coverage claim, so the reviewer finds it where they are already
looking.

## What this defends against — at three different strengths

State these in these words. Implying uniform protection is worse than naming
the gap.

| Attack | Coverage | Mechanism |
| --- | --- | --- |
| Agent **deletes** the test | **Prevented** | The zero-test demotion: `running 0 tests` / `[no tests to run]` fails the criterion. |
| Agent **leaves it non-running** and satisfies the criterion another way | **Prevented** | The paired `[no-grep:]` on the attribute. There is no other way — the hint *is* the test. |
| Agent **weakens the assertions** | **Detected, not prevented** | The pre-run commit is the baseline, so any edit to the test file is a hunk in `run-diff.patch`, in a file the reviewer has been told is evidence. |

Weakening is accepted risk with a named detection path. The only mitigation
that acts *during* the run is prose: the fixed Description paragraph above.

**Freezing the test file is not available.** Listing it under `**Frozen**`
while requiring the agent to remove the marker from that same file is the
overlap trap — the task becomes unwinnable, and `zurdo analyze` warns on it
under `frozen-overlap`. Do not reach for it.

## Checklist

1. The test file is named for its task and holds only that task's tests.
2. Every test in it carries the marker with the task id in the reason string.
3. Any symbol the test names but the tree lacks ships as a stub in the same
   commit; a runtime lookup needs none.
4. The behavior criterion uses `--include-ignored` (Rust) or the anchored
   `-run` with `-count=1` (Go).
5. The paired guard criterion greps the marker with `#\x5b` (Rust) or
   `//go:build preauthored` (Go), scoped to that one file.
6. Neither the file's header comment nor any constant in it spells the marker
   contiguously.
7. The hint has been run and failed **on an assertion**.
8. The task Description carries the evidence-not-scratch paragraph.
