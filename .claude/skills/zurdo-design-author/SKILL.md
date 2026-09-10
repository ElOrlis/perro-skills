---
name: zurdo-design-author
description: "Authoring a Zurdo design record — the tier above PRD authoring: the empirical gate that every claim marked new carries a number measured at the corpus's authoring state, the `implementation:` frontmatter that states what is built and what is only proposed, and the amendment discipline that corrects a record without rewriting it."
allowed-tools: [Read, Write, Edit, Bash]
disable-model-invocation: true
---

## When to invoke

Invoke this skill when the work needs a **design record** before any PRD exists — a
`docs/design/<topic>.md` that decides what will be built, on evidence, and that a later
reader can hold against what shipped. It is the tier above `zurdo-prd-author`: intent →
design record → PRDs → `zurdo run`.

Reach for it when the change is large enough that the first honest question is *"does
something already do this?"*, when two plausible approaches need adjudicating on evidence
rather than taste, or when a decision will outlive the person who made it and the reasoning
has to survive with it.

Do not invoke it to turn a settled decision into tasks and criteria — that is
`zurdo-prd-author`, and phase 5 hands off to it. Do not invoke it to write a specification:
a design record says *what was decided and why*, with the alternatives and the numbers; the
spec says how the shipped surface behaves. A record that has become a spec has stopped being
evidence of a decision.

The method below is not invented here. It is extracted from the design records in this
repository that worked — `contract-intelligence.md` §2.1 tabulating incumbent rails before
proposing anything, `loop-optimization.md` §5.1 scoping, measuring, and dropping a proposed
lint inside one session, `compound-loop.md` §13 recording what it rejected and on what
number.

## The gate

`zurdo-prd-author` has a hard machine gate: it runs `zurdo analyze --static-only` and
requires zero `[error]`. A design record has no parser, so its gate is empirical instead:

> Every claim marked **new** carries a number, measured by running the current binary over
> the corpus at the corpus's authoring state.
>
> **No number, no claim.**

A claim is "new" whenever the record says the thing does not exist yet, is not covered, or
would be added — headline capabilities most of all, because those are the ones nobody
re-checks. The gate is cheap to clear and expensive to skip: the measurement usually takes
one command, and the claim it kills would otherwise have become a PRD.

**The evidence that this gate works is a record that failed it.**
`contract-intelligence.md` §6.3 claimed authoring-time tautology detection as its headline
capability. Running the shipped lint showed `grep-tautology` already did it — surfaced on
both rails, `--strict`-promotable, a build-breaking error rather than an advisory note — and
the claim was withdrawn, leaving a narrow residual delta that the design was then rescoped
to. No amount of reading the prose produced that catch; running the binary produced it in
one command.

### When a claim cannot be measured

Some claims have no instrument — a property of run state under gitignored `.zurdo/`, a
behavior that only exists once the thing is built. Demote the claim to the record's **Open
questions** section and name what *would* measure it. Do not refuse the document over it,
and do not let the claim stand in the body unmarked as though it had been checked.

### Two gates that are rejected, and why

- **A structural lint on the record itself.** Checking that the document contains a rails
  table and a delta table is cheap, deterministic, and proves nothing: a record with an empty
  delta table and fabricated numbers passes it. It asserts that a heading was typed — the
  `doc-echo` failure mode applied to design review (`compound-loop.md` §13.1). The gate is
  the measurement, not the heading.
- **A second LLM critic as the gate.** Measured on three `--fix` runs at reconstructed
  authoring state (`compound-loop.md` §13.4): the incumbent critic resolved criteria and
  re-raised them verbatim one iteration later, on both `claude-haiku-4-5` (5 → 6 → 6, ending
  in a parse failure) and `claude-sonnet-5` (6 → 3 → 3 → 2 → 1, ending at the iteration cap).
  Convergence tracked analyzer strength, not rubric quality. A second critic adds churn, not
  ground truth.

## The five phases

Each phase has a gate. Do not open the next one until it clears.

### 1. Intent and incumbents

Pin the problem in **one sentence** — the thing that is wrong today, not the solution. Then,
before proposing anything, tabulate what already ships that touches it: the rails, the
surfaces, the checks, each with the symbol or file that implements it.
`contract-intelligence.md` §2.1 is the worked example — three incumbent rails in a table,
followed by one paragraph naming the single thing none of them can do. That paragraph is the
design's whole contribution, and it is only writable because the table came first.

Ordering matters here and nowhere else so much. A proposal written before the inventory
describes a gap that may not exist; an inventory written after it gets read as confirmation.

**Gate:** the incumbent table is written, and every proposed capability is stated as a delta
against a named row of it.

### 2. Measure

Every claim marked new gets a number from the current binary over the corpus.

Take the number at the corpus's **authoring state**, not at `HEAD`. `zurdo validate
--authoring-state` reads each PRD's text as of the commit that added it and checks it against
that commit's first parent; `--format json` carries the resolved revision, so a measurement
names the state it was taken at, and aggregation across PRDs is a shell loop over that JSON.
A number taken at `HEAD` is not a measurement of anything the author cares about: every hint
that was honestly red when the PRD was written is green once the work ships, so a corpus
lint fires on all of them at once, and the resulting count is dominated by artifacts.

Build the binary from the tree being measured. A release on `PATH` predates the lints, and a
lint that has not shipped there measures as zero findings rather than as an error.

**Gate:** every "new" claim in the draft carries a number and the state it was measured at,
or it has been demoted to an open question naming its missing instrument.

### 3. Decide, and record what was rejected

Write goals and non-goals as lists, then write a **Considered and rejected** section — and
give every entry the measurement or the principle that rejected it.

This is the section that pays for itself. An alternative recorded without its reason is not a
closed decision; it is an open one that will be re-proposed by the next reader, argued again
from scratch, and possibly decided the other way. `loop-optimization.md` §5.1 is the shape:
the proposed cross-task frozen-overlap lint would have fired 68 times on the corpus and been
right approximately once, retroactively, about a defect that had already been fixed
elsewhere. Nobody re-litigates that, because the number is sitting in the entry.

Non-goals carry their reason too, and the strongest ones name what would reopen them.

**Gate:** no entry in Considered and rejected is a bare sentence — each carries a number, or
a stated principle with the record that owns it.

### 4. Phase the work

Split the decision into phases that ship independently, and give **each phase an exit
criterion naming an observable** — the thing that is true when the phase is done. A symbol
that exists, a lint family that fires, a flag that parses, a count that moves.

A phase without an observable cannot be reported on later. It cannot be marked shipped
honestly, it cannot be marked outstanding honestly, and when the record's frontmatter is
asked which phases remain, that phase has no answer to give. Where a phase genuinely has no
observable token, say so in the phase itself and say why — that sentence is what the
frontmatter's `unprobeable` reason will quote.

Note which phases depend on which. Independently shippable phases are what let the first PRD
be small.

**Gate:** every phase names an observable, or names the reason it has none.

### 5. Frontmatter and handoff

The record opens with an `implementation:` block that states what is built and what is only
proposed, so a reader knows within one line whether they are reading history or intent. The
schema is a closed set, and it is the one `shared/zurdo/tests/docs_truth_tier2.rs` actually
parses:

| `implementation:` | What it also requires |
| --- | --- |
| `shipped` | `shipped_in:` — and only `shipped` may carry it |
| `unshipped` | a `probe:` paired with a `scope:`, **or** an `unprobeable:` reason — never both |
| `partial` | a `remaining:` list of at least one entry, each carrying the same probe-or-reason pairing |
| `declined` | a document-level `decided_by:` |
| `snapshot` | `as_of_version:` |

A `probe:` is a token that appears in the design record and must match **zero** times inside
its `scope:`. That zero is the whole assertion — it is what makes an unshipped claim
falsifiable, and it is why a probe is chosen as a name the implementation would have to
introduce. A probe renamed rather than removed goes on passing while asserting nothing.

Then hand off. Refer the human onward to `zurdo-prd-author` to turn the record into PRDs —
one PRD per shippable phase, the exit criteria of phase 4 becoming the requirements it
grills into acceptance criteria. This is a referral to the person driving the session, not a
call: the design record is the input to that skill, and the human decides when the record is
settled enough to be one.

**Gate:** the frontmatter parses under the table above, and the phase-4 observables are
stated plainly enough that the next skill can read requirements out of them.

## Amend, never rewrite

Once a record has shipped, correct it by **adding an amendment**, and leave the original text
unedited.

A record rewritten to read as though it always knew stops being evidence of what was believed
when it was written — and that evidence is the only thing a design record has that a spec
does not. An amendment carries its date, names the clause it strikes, and says what replaced
it. `engineering-skills-verdict.md`'s Amendment 2026-08-24 is the worked example: it strikes
one sentence of one subsection, restates it, says explicitly what it does *not* reopen, and
leaves every measurement in the original record undisturbed.

Status moves the same way. `unshipped` → `partial` → `shipped` is moved by a PRD task, in the
same commit as the work — never by the record's own author on the strength of intending to
build it.

## Naming

When the record introduces a name — a new noun, a concept the codebase will carry, a term a
reader could half-guess and get wrong — call the Skill tool with `zurdo-domain` before the
name sets. It owns the admission test a term must clear, the entry format, and the rule that
the spec and the code win wherever a glossary disagrees with the shipped surface. Reach it by
name; it is a peer skill, not a directory to read.

Names are cheapest to fix in the design record and most expensive to fix after the PRDs
quote them.

## References

- [references/measurement.md](references/measurement.md) — the instrument (`zurdo validate --authoring-state`, `--at`, the JSON `revision`), why a `HEAD` number is dominated by artifacts, the 96.7% artifact rate and the 45% residual swing that pinned the baseline rule in the binary, and what to do with a claim that cannot be measured
- [references/record-format.md](references/record-format.md) — the `implementation:` schema `docs_truth_tier2.rs` parses, the probe-or-reason pairing and what makes a probe an assertion, the per-entry `decided_by:` that marks a `remaining:` item decided against, and the document shape this repository's records converge on
- [references/amendments.md](references/amendments.md) — amending a shipped record without rewriting it: the three parts an amendment carries, and the status transitions a PRD task owns rather than the record's author
- `zurdo-domain` — the admission test a new name must clear before the record sets it; call the Skill tool with `zurdo-domain` (this is a peer skill, named rather than addressed by path)
