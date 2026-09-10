# Forcing questions — grilling a criterion until it verifies

The whole point of `zurdo-prd-author` is to leave the user with acceptance
criteria that *actually verify*, not criteria that merely parse. A criterion
parses when it is a `- [ ]` line with a trailing hint. A criterion **verifies**
when the hint passes if and only if the work is genuinely done. The gap between
those two is where wasted `zurdo run` budget lives — and it is what these
forcing questions are designed to close.

Ask one question at a time. For every question, lead with your recommended
answer (per the grill discipline — never a bare "what do you think?"). Explore
the codebase before asking: if a `grep`/`Read` answers it, do that instead of
spending a turn.

## The six forcing questions (ask these of every criterion)

### 1. The tautology test — "does this already pass, before any code change?"

Run the hint against the current working tree *now*. If it passes before the
agent touches anything, the criterion proves nothing about the change. The
`grep-tautology` lint detects many tautology candidates automatically, and you
can use `zurdo analyze --authoring-state <prd>` to reconstruct the baseline
from the authoring window (the commit when the PRD was added) so the linter
sees the tree before your changes shipped.

- `[grep: auth in README.md]` against a README that already says "auth" thirty
  times → tautology. Grep for the string the change is supposed to *introduce*.
- `[file-exists: src/lib.rs]` on a crate that already has `src/lib.rs` →
  tautology. Point at the file the task creates.

**Recommended fix:** rewrite the hint to target the *delta* — a new symbol, a
new file, a bumped version string, a status code that is wrong today.

### 2. The no-op test — "if the agent does literally nothing, does this fail?"

The mirror image of the tautology test. A good criterion fails on an empty
diff. If you cannot convince yourself it would fail when the agent does
nothing, the criterion is not load-bearing.

### 3. The honesty test — "does the hint exercise the behavior the text names?"

Read the criterion text and the hint side by side. The most common defect is a
hint that passes for the wrong reason:

- "rate limit is 100 req/min" verified by `[shell: cargo build]` → the build
  passing says nothing about the threshold. Either find/author the test that
  asserts 100, or rewrite the criterion to something the build *does* prove.
- "login returns 401 without a password" verified by `[file-exists: src/auth.rs]`
  → the file existing proves nothing about the response.

**Recommended fix:** match the hint type to the claim — code-under-test →
`[shell:]`; endpoint status → `[http:]`; presence/absence → `file-exists`/
`file-absent`/`grep`/`no-grep`; editorial/visual → `[manual]`.

### 4. The specificity test — "is this the narrowest hint that proves it?"

A hint that is too broad drags the criterion down on unrelated regressions and
proves less than it appears to.

- `[shell: cargo test]` for one behavior → narrow to a specific test name:
  `[shell: cargo test login_returns_401]` (a unit-test function) or
  `[shell: cargo test --test healthz_integration]` (an integration-test file).
  The `--test` flag selects a *target* (a file under `tests/`), while the name
  alone selects a *test function* within that target or the whole crate. Note that
  `cargo test --test <name>` without `--manifest-path shared/Cargo.toml` fails
  with "no test target named" if the target does not exist yet.
- `[grep: foo in src]` (a directory) → grep always fails on a directory target;
  point at the specific file (see [grep-hints.md](grep-hints.md)).

### 5. The honest-`[manual]` test — "can automation reach this at all?"

If the criterion is about UX feel, copy tone, or visual hierarchy, no automated
hint can prove it. Saying `[shell: cargo test]` there is dishonest — the test
cannot see the thing. Mark it `[manual]` and accept the `passed-pending-review`
outcome, rather than faking a green check.

Do **not** pad with `[manual]` to inflate the criterion count. One honest
`[manual]` where automation genuinely cannot reach is fine.

### 6. The pre-authored test — "if this hint runs a test, does that test exist yet — and if not, are you writing it before the run?"

A sixth peer, not a second barrel on question 3. The honesty test asks whether
the hint *type* fits the claim — `[shell: cargo test login_returns_401]`
genuinely exercises "login returns 401." This question asks something the
honesty test cannot see: whether that test exists yet, and if not, who writes
it. A criterion can pass question 3 cleanly and still fail this one.

Ask it of the author, not of a regex over `[shell:]` commands — a pattern match
misfires on `cargo build` wrappers and misses `make check`. There is no
substitute for asking directly.

The answer has two halves.

**Pre-author it.** Write the test, commit it, and mark it non-running in the
same commit as the PRD, so a human judges its assertions at the commit that is
already the review gate — rather than as one hunk among hundreds in
`run-diff.patch`, read by someone who already knows the criterion went green.

**Decline it, with a reason.** Not every criterion can be pre-authored: the
criterion is `[manual]`, or the behavior's test genuinely cannot precede the
API it exercises. Legitimate exemptions exist. Record the reason on the task's
trail line — an unrecorded exemption is indistinguishable from never having
asked.

**The pre-run check.** Before the ready verdict, run the hint. It must fail,
and it must fail **on an assertion**. A compile error means the stub is
missing. A zero-test demotion means the filter matches nothing. A green run is
a tautology and proves exactly as little as a `[grep:]` for a string already
in the file. See [pre-authored-tests.md](pre-authored-tests.md) for the Rust
and Go shapes.

## Coverage forcing questions (ask these of each task as a whole)

- **Golden path:** "Which single criterion proves the headline outcome?" Every
  task needs at least one. If you cannot name it, the task is under-specified.
- **Failure modes:** "What are the one or two obvious ways this breaks, and does
  a criterion catch each?" (auth → unauthenticated + unauthorized + valid;
  CRUD → create/read/update/delete).
- **Size:** "Is this 3–5 criteria?" Fewer than 2 → probably under-specified.
  More than ~6 → probably two tasks; revisit the decomposition.
- **Side effects:** "Does any `[shell:]` here mutate the tree (`cargo fmt`,
  migrations) in a way that masks the next task's pre-flight?" Flag it.

## How to drive the loop

1. List the task's draft criteria (or generate stubs from the description).
2. Take them one at a time. For each, walk questions 1→6; stop early when one
   forces a rewrite, fix it, then continue.
3. Record the resolved criterion + the reason in the session
   (`session_tracker.py --action record`).
4. After every criterion survives all six, run the task-level coverage
   questions.
5. Only then advance to the review phase. This is a hard gate — see
   [when-to-stop.md](when-to-stop.md).
