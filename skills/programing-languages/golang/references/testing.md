# Testing Discipline in Go

A reference mapping language-agnostic testing principles onto Go's idioms. Sources: Google Testing Blog — *Testing State vs. Interactions* (2013), *Effective Testing* (2014), *Risk-Driven Testing* (2014), *Change-Detector Tests Considered Harmful* (2015).

---

## 1. State Testing vs. Interaction Testing

**Prefer state testing by default.** State testing asserts on observable output — return values, written state, emitted events — and directly answers "is the code correct?" Interaction testing asserts that a specific method was called, with specific arguments, in a specific order. A passing interaction test proves a call happened; it says nothing about whether the code produced a correct result.

**When interaction testing is justified:**

- Correctness depends on *how* the output is produced, not only *what* is returned.
- Side-effects that must happen exactly once (sending one email, writing one audit record).
- Call count or ordering is semantically significant (bounded reads, deadlock-prone sequences).
- MVC/MVP view-method assertions where the observable behavior *is* a method invocation on a collaborator.

Outside these cases, verifying interactions adds coupling to the implementation without adding confidence in correctness.

---

## 2. Effective Testing: Fidelity × Resilience × Precision

Three properties determine a test suite's value. They are in tension; optimising one costs the others.

| Property | Meaning | Fails when low |
|----------|---------|----------------|
| **Fidelity** | Fails when the code is broken — covers all paths, asserts all relevant state | Bugs slip through; tests pass on broken code |
| **Resilience** | Fails *only* on a breaking change — tests the exposed API, not internals | Every refactor breaks the suite; flaky tests |
| **Precision** | A failure pinpoints the defect — small, focused tests, descriptive names | Green/red tells you little about *where* the bug is |

The empty test is maximally resilient but has zero fidelity. A test that asserts every internal detail has high fidelity but collapses on any refactor. The discipline is to find the right balance — testing what matters at the right level of abstraction.

**Rules of thumb:**

- Test the behaviour described by the function's contract, not the steps inside it.
- One logical assertion per test (use subtests to split cases, not extra `if` branches).
- Flaky tests have low resilience by definition; fix or delete them.

---

## 3. Risk-Driven Testing

> "Tests are a means to an end: To reduce the key risks of a project, and to get the biggest bang for the buck."

Before writing tests, enumerate the key risks:

1. What could go wrong that would matter most?
2. What is the cheapest effective mitigation for each risk?

A test that covers a trivial path reduces no meaningful risk while consuming maintenance budget. Extensive tests on the wrong things create a false sense of safety — the suite is green while the real risk is untested.

**Practical discipline:**

- Write down the top risks *before* writing tests.
- Choose the cheapest test type that actually covers the risk (unit > integration > end-to-end for cost; choose the level that provides fidelity).
- Measure coverage of *risk*, not of lines. Line coverage of trivial getters is wasted effort.

---

## 4. Change-Detector Tests Are Harmful

A change-detector test restates the implementation as a test. It is "a transformation of the same information in the code under test" — typically a mock-and-verify-in-order echo of every internal call. Such a test:

- Catches no defects (correct and incorrect programs are equally likely to pass).
- Breaks on every refactor, including ones that improve correctness.
- Provides *negative* value: the maintenance cost exceeds any benefit.

> "A correct or incorrect program is equally likely to pass a test that is a derivative of the code under test."

**Signs you have a change-detector test:**

- The test's assertion list reads like an execution trace of the production code.
- Renaming a private method or inlining a helper breaks the test with no behaviour change.
- The test verifies call order when order has no semantic meaning.

**Remedy:** rewrite to assert on state or observable behaviour. If no such assertion exists, delete the test.

---

## 5. Go Mapping

### Table-Driven Tests Are State Testing by Construction

The idiomatic Go test is a table-driven loop over `[]struct{name, in, want}`. Each row is a state test: run the function, compare output to `want`. This is the right default.

```go
func TestAdd(t *testing.T) {
    cases := []struct {
        name string
        a, b int
        want int
    }{
        {"positive", 2, 3, 5},
        {"zero", 0, 0, 0},
        {"negative", -1, 1, 0},
    }
    for _, tc := range cases {
        t.Run(tc.name, func(t *testing.T) {
            got := Add(tc.a, tc.b)
            if got != tc.want {
                t.Errorf("Add(%d, %d) = %d, want %d", tc.a, tc.b, got, tc.want)
            }
        })
    }
}
```

### Subtests via `t.Run`

`t.Run(tc.name, func(t *testing.T) {...})` gives each case an isolated failure signal and a name that appears in output. Use it for every table row and for any logically independent scenario within a test function.

### `t.Helper()` in Assertion Helpers

When you extract a shared assertion into a helper, call `t.Helper()` as the first line. This makes failure output point to the call site, not the helper body.

```go
func assertNoError(t *testing.T, err error) {
    t.Helper()
    if err != nil {
        t.Fatalf("unexpected error: %v", err)
    }
}
```

### `t.Fatal` vs. `t.Error`

| Situation | Use |
|-----------|-----|
| Setup failure that makes subsequent assertions meaningless | `t.Fatal` / `t.Fatalf` |
| Inside a table-driven loop (continue to next case) | `t.Error` / `t.Errorf` |
| Inside a goroutine | **Never** `t.Fatal` — it panics; use a channel or `sync.WaitGroup` and `t.Error` from the test goroutine |

### Real Objects → Fakes → Mocks

Prefer collaborators in order:

1. **Real object** — use the actual type if it's fast, deterministic, and has no external I/O.
2. **Fake** — a lightweight, correct alternative implementation (in-memory store, stub HTTP server).
3. **Mock** — a generated or hand-written recorder. Reach for mocks only when fidelity genuinely requires verifying interactions (see §1).

### Test the Exported API

Write tests against the package's public surface. Use an external `_test` package (`package foo_test`) where practical. This enforces that tests only see what callers see, and it makes the test suite resilient to internal refactors.

```
// preferred
package store_test

import "mymodule/store"

func TestGet(t *testing.T) { ... }
```

---

## 6. Anti-Patterns

| Anti-pattern | Why it fails |
|---|---|
| **Change-detector / tautological test** | Restates the implementation; zero defect-catching value; breaks on every refactor |
| **Over-mocking** | Verifies interactions instead of behaviour; high coupling, low resilience |
| **Testing implementation details** | Internal state or private helpers; collapses under refactoring |
| **Coverage-chasing trivial code** | Wastes maintenance budget; reduces no meaningful risk |
| **End-to-end tests as the default** | Slow, flaky, low precision; use as a complement, not a foundation |
| **Interaction verification without a contract reason** | Adds mock setup cost with no correctness signal |
