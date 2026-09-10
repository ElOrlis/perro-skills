# Correcting a record after it ships

## Amend, never rewrite

An amendment is **added**. The original text is left unedited — including the
sentence the amendment strikes, including the number that turned out to be
measured wrong, including the paragraph that now reads as naive.

The reason is not politeness toward the earlier author. A record rewritten to
read as though it always knew stops being evidence of what was believed when it
was written, and **that evidence is the only thing a design record has that a
spec does not**. The spec already says how the shipped surface behaves, and says
it better, because it is maintained against the code. What the spec cannot say is
which alternative was live at the time, what number closed it, and what the
author did not yet know. Edit the original and the record collapses into a worse
spec: still wrong about the code, and no longer a witness.

There is a second, more practical cost. A rewritten record cannot be trusted
retroactively. If one clause silently changed, every other clause becomes a
question — was that measured, or was it patched in later? The append-only rule is
what lets a reader quote a two-year-old paragraph without first auditing the
file's history.

## The mechanics

An amendment goes at the point in the document where a reader will meet it —
under a heading of its own, at the end of the section it corrects, or at the end
of the record when it corrects the whole thing. It carries three parts, and all
three are required:

1. **Its date.** `Amendment 2026-08-24`. A correction without a date cannot be
   ordered against the other corrections, and ordering is the whole point of an
   append-only record.
2. **The clause it strikes**, named precisely enough to find — the subsection, the
   sentence, the table row. "This section is out of date" is not an amendment; it
   is a complaint.
3. **What replaced it**, and on what evidence. The same gate applies here as
   anywhere else in the record: a claim marked new in an amendment carries a
   number measured at the corpus's authoring state, or it goes to Open questions.

Two things worth stating explicitly when they are true:

- **What the amendment does *not* reopen.** An amendment that strikes one
  sentence of one subsection should say that the rest of the section stands, or
  the next reader will treat the whole section as unsettled and re-argue it.
- **What survives untouched.** Measurements in the original record are still
  measurements of the state they were taken at. An amendment supersedes a
  conclusion; it does not retroactively unmeasure a number.

`engineering-skills-verdict.md`'s Amendment 2026-08-24 is the worked example in
this repository: it strikes one sentence of one subsection, restates it, says
explicitly what it does not reopen, and leaves every measurement in the original
record undisturbed.

## Status transitions, and who owns them

The `implementation:` frontmatter moves along one path:

```
unshipped  →  partial  →  shipped
```

Each move is made **by a PRD task, in the same commit as the work**. That is the
whole rule, and it puts the transition in the hands of the only party that can
observe it: the change that made the claim true.

The author of the record does **not** move it. Not on the strength of intending
to build the thing, not on the strength of having written the PRD, not on the
strength of a phase being "basically done". A status moved on intent is a claim
with no measurement behind it — the same defect the empirical gate exists to
catch, arriving through the frontmatter instead of the prose. And it is worse
than a wrong sentence in the body, because the frontmatter is the field a reader
checks *instead of* reading the body.

Two transitions sit outside that path and are worth naming:

- **`declined`** is not reached by shipping. It is a decision, and it requires a
  document-level `decided_by:` naming the record that made it. Write the
  amendment in the same commit that sets it, so the value has its reasoning
  attached rather than pointing at a file the reader must go find.
- **`snapshot`** freezes the record against `as_of_version:` and takes it out of
  the transition path entirely. It is the right value for a record whose subject
  is a moment — a review, a verdict, a state-of-the-world at one release — and
  the wrong value for a design that is merely stalled. A stalled design is
  `unshipped` with an honest probe, or `partial` with the built part named.

When a phase of a `partial` record is decided against rather than built, its
`remaining:` entry gains a per-entry `decided_by:` and stays in the list. It does
not get deleted. Deleting it makes the record read as though that phase was never
proposed, which is the same erasure as rewriting a clause, applied to the
frontmatter.
