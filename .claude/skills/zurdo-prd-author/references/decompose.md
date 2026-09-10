# Decomposing intent into tasks

This is the **decompose** phase of the interview-driven authoring flow. The shift
from the old "split the intent" approach: do not start by carving an intent
statement into pieces. Instead, **cluster the evidence** — gather every concrete
fact that must be true when the work is done, then group co-located facts into
cohesive tasks. Tasks emerge from evidence, not from prose structure.

The grammar is rigid; trying to author both the *decomposition* and the *§2.2
grammar* in one pass is what produces malformed PRDs. Decomposition owns the
first half; the grammar authoring step owns the second.

## Evidence Clustering

Before naming a single task, build an evidence inventory:

1. **Enumerate facts.** Walk the intent and extract every verifiable claim: a
   file that must exist, a test that must pass, a string that must appear, a
   route that must respond. Write each as a one-line fact. Alongside each
   capability, also record its negative space — *what must NOT change while
   delivering this* — as candidate frozen paths (see
   [frozen-paths.md](frozen-paths.md)); they bind to tasks as `**Frozen**`
   globs after clustering, never before.
2. **Attach a hint type.** For each fact, assign the cheapest hint type that
   plausibly proves it (see *Mapping criteria to hint types* below). If you
   cannot assign a hint type, the fact is too vague — rewrite it or discard it.
3. **Apply the five forcing questions.** Run each (fact, hint) pair through the
   questions in [forcing-questions.md](forcing-questions.md) before grouping.
   Facts that fail are not grouped into tasks — they are fixed or dropped first.
4. **Cluster by co-location.** Group facts that share a file, a subsystem, or a
   verification surface. A cluster that would produce more than ~5 criteria is
   a signal to split; a cluster with a single `[manual]` fact that nothing else
   shares is a signal to fold it into the closest neighbor or make it a
   `[manual]`-only task.
5. **Name the cluster.** Give the cluster a short imperative title that names
   the deliverable, not the activity. The cluster becomes the task.

This ordering matters: evidence comes first, tasks second. A task boundary
drawn before the evidence is known is a guess that the evidence will later
contradict.

## What the decomposer produces

A markdown draft with one section per proposed task, in this shape:

```markdown
# PRD draft: <title>

<one-paragraph intent summary, sourced from the input doc>

## task-1 — <short title>
- **Effort**: <key> (see notes on effort below)
- **Depends-on**: []
- **Why this is one task**: <one sentence naming the evidence cluster>
- **Frozen candidates**: <globs>       # optional — becomes `**Frozen**` in grammar authoring
- **Criteria sketch**:
  - <plain-english criterion>  → `[shell: ...]` or `[file-exists: ...]` etc.
  - <plain-english criterion>  → `[manual]` (and why no automated check applies)

## task-2 — <short title>
- **Effort**: <key>
- **Depends-on**: [task-1]
- **Why this is one task**: ...
- **Criteria sketch**:
  - ...
```

This is **not** §2.2 grammar yet — that's the grammar reference / the §2.2
authoring step's job. The intermediate form makes review easy and keeps the
decomposition decisions visible before they get compressed into a
parser-friendly skeleton.

## Decomposition heuristics

1. **One task = one evidence cluster that can be verified end-to-end.** If a
   task needs three independent verification checks that target different
   subsystems, it is probably two or three clusters. If a task needs zero
   automated checks, it is probably a `[manual]`-only task — surface that
   explicitly.
2. **Sequence by data, not by feel.** Draw the edge from task A to task B only
   when B literally cannot start until A's artifact exists (a file, an
   endpoint, a schema). "B is harder so do A first" is not a dependency — it's
   an authoring suggestion.
3. **Prefer many small clusters over few large ones.** Smaller tasks ⇒ smaller
   `Max-Attempts` blast radius when one fails. A task that needs more than ~5
   criteria is a smell; re-cluster.
4. **Identify the verification surface for each cluster before deciding the
   boundary.** If you cannot name the hint type for at least one criterion,
   the cluster is too vague — refine the brief or re-cluster.
5. **Keep dependency chains shallow.** A linear chain of seven tasks is a
   worse PRD than two parallel chains of three; `Depends-on: []` clusters
   compose better with future parallelism and with the user manually re-running
   a single task.

## Mapping criteria to hint types

For each fact in your evidence inventory, pick the cheapest hint type that
plausibly proves it:

- **Code is exercised by a test** → `[shell: <test command>]`. The shell hint
  is the workhorse; use it for unit tests, integration tests, builds, lints,
  formatters.
- **An HTTP endpoint behaves correctly** → `[http: <method> <url> -> <status>]`.
  Assertions are **status only** by default; use `contains "<substring>"` to
  assert an exact, case-sensitive match in the response body. Example:
  `[http: GET http://localhost:8080/health -> 200 contains "ok"]`.
- **A file or directory must exist** → `[file-exists: <path>]`. Use for
  migrations, generated artifacts, config files.
- **A file or directory must NOT exist** → `[file-absent: <path>]`. Use for
  cleanup tasks, removal of deprecated files. Safer than
  `[shell: ! test -e ...]` — a wrong path fails explicitly rather than
  silently passing.
- **A specific string must appear in a file** → `[grep: <pattern> in <file>]`.
  Use for marker strings, version bumps. Be specific — `[grep: foo in src]`
  is too loose (directory targets always fail).
- **A specific string must NOT appear in a file** → `[no-grep: <pattern> in <file>]`.
  Use for TODO removal, dead-code cleanup. Safer than `[shell: ! grep -q ...]`
  — a typo'd filename fails rather than silently passing.
- **No machine check applies** → `[manual]`. Use sparingly: visual polish, UX
  feel, design-language conformance, copy review.

Multiple hints on one criterion are AND'd. A criterion like "the new endpoint
is live and stays under 200ms" is two hints on one line:
`[http: GET /v1/foo -> 200] [shell: ./bench.sh /v1/foo --max-ms 200]`.

## Effort assignment

You usually do not know the user's `[effort_map.<provider>]` keys. Default to
writing `Effort: <low|medium|high>` as a placeholder and flag in your handoff
that **the writer should confirm the effort keys against `.zurdo/config.toml`
before finalizing**. If the user has already confirmed the shipped defaults,
use `low|medium|high` directly. Map your intuition to the cheapest key that
plausibly clears the criteria — over-budgeting effort is wasted spend.

## Anti-patterns to refuse

- **Mega-clusters.** A single task with "build the whole auth subsystem" plus
  eight criteria is not a Zurdo task — re-cluster before drafting.
- **Cross-PRD dependencies.** `Depends-on` is local to one PRD. If your
  decomposition needs to point at a task in a *different* PRD, that task
  belongs in this PRD too — or the work needs to be reorganized.
- **Criteria with no plausible hint type.** "Code is well-structured" maps to
  nothing. Either rewrite the criterion as a check that *does* run
  (`[shell: cargo clippy -- -D warnings]`) or drop it from the inventory.
- **Implicit ordering via prose.** Saying "we do A before B" in the intent
  paragraph does not create a dependency. If A must precede B, write
  `Depends-on: [task-A]` on task-B explicitly.
- **Unverified facts entering the grouping step.** Apply the five forcing
  questions *before* clustering. Grouping a tautological or no-op fact just
  buries the defect deeper.

## Worked example

Input (a freeform brief):

> We want a `/healthz` endpoint on the existing axum server that returns 200
> when the DB is reachable and 503 otherwise. It should be exercised by an
> integration test, and the operator runbook should mention it.

Evidence inventory (before clustering):

| Fact | Hint |
|---|---|
| `src/routes/health.rs` exists | `[file-exists: src/routes/health.rs]` |
| server compiles | `[shell: cargo build]` |
| healthy DB path → 200 | `[http: GET http://localhost:8080/healthz -> 200]` |
| integration test passes | `[shell: cargo test --test healthz_integration]` |
| runbook mentions /healthz | `[grep: /healthz in docs/runbook.md]` |
| runbook prose reads sensibly | `[manual]` |

Cluster 1 (route + server): first three facts share `src/routes/health.rs`.
Cluster 2 (test): fourth fact depends on the route existing — separate task.
Cluster 3 (docs): last two facts share `docs/runbook.md` — separate task, no
code dependency on cluster 2.

Decomposed draft:

```markdown
# PRD draft: Add /healthz endpoint

Surface a database-aware health check on the existing axum server and document
it in the runbook.

## task-1 — Wire /healthz route into the server
- **Effort**: low
- **Depends-on**: []
- **Why this is one task**: route handler + DB-probe + status mapping cluster
  around `src/routes/health.rs`; everything downstream needs the route to exist.
- **Criteria sketch**:
  - handler file is present  → `[file-exists: src/routes/health.rs]`
  - server compiles  → `[shell: cargo build]`
  - healthy DB path returns 200  → `[http: GET http://localhost:8080/healthz -> 200]`

## task-2 — Integration test for /healthz
- **Effort**: medium
- **Depends-on**: [task-1]
- **Why this is one task**: test evidence clusters around the test file and
  cannot exist until the route does.
- **Criteria sketch**:
  - integration test passes  → `[shell: cargo test --test healthz_integration]`

## task-3 — Document /healthz in operator runbook
- **Effort**: low
- **Depends-on**: [task-1]
- **Why this is one task**: docs evidence clusters around `docs/runbook.md`;
  no code dependency on the test task.
- **Criteria sketch**:
  - runbook mentions /healthz  → `[grep: /healthz in docs/runbook.md]`
  - the prose reads sensibly  → `[manual]` (no automated check for editorial quality)
```

Hand this off to the §2.2 authoring step to produce a parser-clean
`<filename>.md`, then run `zurdo analyze --static-only <filename>.md` before
committing.
