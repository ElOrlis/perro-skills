# The record format: frontmatter schema and document shape

Two things are fixed about a design record. The frontmatter is **parsed** — the
schema below is the one `shared/zurdo/tests/docs_truth_tier2.rs` actually
enforces over every Tier 2 document, so a record that gets it wrong fails a test
rather than a review. The body shape is **converged**, not parsed: it is the
order this repository's working records settled on, and departing from it costs a
reader more than it saves the author.

## The `implementation:` block

`implementation:` takes one of a closed set of five values. Everything else in
the block is keyed to which one you picked.

| `implementation:` | Required | Forbidden elsewhere |
| --- | --- | --- |
| `shipped` | — (`shipped_in:` when one release carries it) | `shipped_in:` is `shipped`-only |
| `unshipped` | a `probe:` + `scope:` pair, **or** an `unprobeable:` reason | the probe surface is `unshipped`-only at document level |
| `partial` | a `remaining:` list of **at least one** entry | `remaining:` is `partial`-only |
| `declined` | a document-level `decided_by:` | a document-level `decided_by:` is `declined`-only |
| `snapshot` | `as_of_version:` | `as_of_version:` is `snapshot`-only |

`superseded_by:` is orthogonal to all five — never required, never forbidden.

### The probe-or-reason pairing

An unshipped claim has to be falsifiable, and the pairing is how:

- **`probe:` + `scope:`** — a token that must match **zero** times inside its
  scope. A bare `scope:` asserts nothing; a `probe:` without one has nowhere to
  look, so the parser requires the pair.
- **`unprobeable:` `"<reason>"`** — the alternative, for a claim with no
  identifier to probe. The reason must be real prose, not an empty string.

Carrying **both is rejected**. They are alternatives, not belt-and-braces: a
document that names an identifier and *also* pleads that it has none is asserting
two incompatible things, and one of them is not true.

`unprobeable` is kept legal on purpose. It is the honest gap in the schema — the
release valve that stops a vague design from having identifiers invented into it
just to satisfy the parser. Use it when it is true and quote the phase sentence
that says why.

### What makes a probe an assertion

A probe carries two obligations, and only both together mean anything:

1. It matches **zero** times inside its `scope:` — that zero *is* the assertion.
   One hit means the thing is built, or the token is the wrong one; either way
   the record is now lying about its own status.
2. It appears in the **design document's own prose**. A token nobody wrote into
   the record is a token nobody will ever build, so it stays zero-hit forever
   and the row goes green while asserting nothing — the `[no-grep:]` failure mode
   inherited whole.

The `scope:` path must also exist, or the zero is vacuous for a third reason.

Choose a probe that is a name the implementation *would have to introduce* — a
type, a flag, a subcommand. A probe renamed rather than removed goes on passing
while asserting nothing.

### `remaining:` entries, and the one that was decided against

Each `remaining:` entry carries a `what:` naming the item, and then the same
probe-or-reason pairing the document level uses. A per-entry `decided_by:` is a
**different field** from the document-level one, and it means something else:

- an entry **without** `decided_by:` is genuine backlog — unbuilt, still intended;
- an entry **with** `decided_by:` was **decided against**, and the field names the
  record that decided it.

The distinction is load-bearing for counting. Three entries where two are closed
decisions reads as three unbuilt items to anyone skimming the frontmatter, which
overstates the outstanding work every time the record is quoted.

```yaml
---
implementation: partial
remaining:
  - what: "Phase B — widen the heal intake to [shell:] hints"
    scope: shared/zurdo/src/heal/select.rs
    unprobeable: "Phase B widens an existing enum rather than introducing a name"
    decided_by: docs/prds/milestone-12/prd-m12-03-trail-lessons.trail.md
  - what: "Phase D — the bundled skill and its measurement harness"
    scope: skills/
    probe: ZurdoRecordLint
---
```

Two entries: one closed decision, one live backlog item with a falsifiable probe.

## The document shape

In this order. Each section exists because a record missing it got re-litigated.

1. **Motivation** — the problem in one sentence, then what it costs. Not the
   solution.
2. **What already ships** — the incumbent table, before any proposal. Rails,
   surfaces, checks, each with the symbol or file that implements it.
3. **Goals and non-goals** — as lists. Non-goals carry their reason, and the
   strongest ones name what would reopen them.
4. **The decision** — stated as a delta against a named row of §2, with the
   number that supports each claim marked new.
5. **Affected areas** — the files, surfaces, and docs the decision moves, so the
   first PRD's scope is readable off the record.
6. **Phases, with exit criteria** — each phase naming an observable: a symbol
   that exists, a lint family that fires, a flag that parses, a count that moves.
   Note which phases depend on which; independently shippable phases are what let
   the first PRD be small.
7. **Considered and rejected** — every entry carrying the measurement or the
   principle that rejected it. Never a bare sentence.
8. **Open questions** — numbered, each naming what would answer it. This is where
   an unmeasurable claim goes, and it is the only place in the record where a
   claim may stand without a number.

Sections 6 and 8 are the two the frontmatter reads back. A phase with no
observable has no `probe:` to offer and forces an `unprobeable:` reason it may not
deserve; a claim that never made it into Open questions has no status at all.
