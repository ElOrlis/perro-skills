---
name: zurdo-domain
description: "Building and sharpening a project's ubiquitous language — the admission test a term must clear, the definition-and-`_Avoid_` format, the rule that the spec and the code win over the glossary, and the disciplines that keep a glossary from becoming a spec."
allowed-tools: [Read, Write, Edit, Grep]
---

# Ubiquitous language

A project's glossary is the short list of words the project has actually **decided** about.
It lives in a `CONTEXT.md` at the root of the context it governs, and it is a **glossary and
nothing else** — the canonical definition of the project's vocabulary, carrying no
implementation detail, no decisions, and no specification. The specification says how things
behave; the glossary names them.

This skill is the *active* discipline — challenging a term, sharpening it, stress-testing
what it relates to, and writing the entry down the moment the meaning settles. Reading the
glossary before naming something new is **not** this skill; that is a one-line habit any
skill can carry. Reach for this one when you are changing the model rather than consuming it.

Every rule below holds in any repository. What a *particular* repository knows about its own
glossary — which terms are in it, where its decision records live, what its status headers
oblige — belongs in that repository's own contributor guide, not here.

## The admission test

**A term belongs in the glossary when its meaning in this project cannot be guessed from the
word's ordinary use.**

That admits two kinds of word and excludes a third:

- **Coinages** — a word the project invented, which a reader has no prior meaning for at all.
- **Ordinary words the project bends** — a common word carrying a narrower or simply
  different meaning here than the one a reader arrives with.
- **Excluded: words the project uses in their common sense** — an entry for one of these adds
  a line a reader must maintain and teaches nothing.

**The test is not coinage.** That is the mistake worth naming, because it admits the wrong
half of the vocabulary: coinages are the *easy* case. A term nobody misreads needs no entry;
a term everybody *half*-reads needs one most — the guessable-but-wrong reading is precisely
the trap the entry exists to close, and the bent ordinary word is where that trap lives.

Applied honestly the test keeps the glossary small, and small is what makes it readable in
one sitting, which is the only way it gets read at all.

## The spec and the code win

**Where the glossary and the shipped surface disagree on a name, the spec and the code win.**

The glossary *describes* the project's vocabulary; it does not legislate it. A glossary that
renames the surface it documents is a second source of truth, and it is the one that loses —
nobody runs a glossary. So when you find the disagreement, the entry is what changes.

The exception is real but narrow: if the surface name is itself the defect, fix the surface
first — rename it in the code and the spec, in a change a reviewer sees — and let the entry
follow in that same commit. What is never acceptable is leaving the two disagreeing and
treating the glossary as the aspiration.

## A glossary and nothing else

Four things a glossary is not, in the order they tend to creep in:

- **Not a spec.** The moment you are writing *how* something works — the algorithm, the
  ordering, the flags — you are writing spec. Define what the noun means and stop.
- **Not a scratch pad.** A half-settled meaning does not get a provisional entry. Settle it
  or leave it out.
- **Not a home for decisions.** A decision has a *why*, alternatives, and a date; an entry
  has none of those. Decisions go where the repository already records decisions.
- **Not an index.** It does not enumerate the surface, list the commands, or mirror a table
  that lives somewhere else. Two copies of a list diverge, and the glossary is the copy
  nothing checks.

## The entry format

An entry is three parts: a bolded term line, a definition, and an `_Avoid_` line.

```markdown
**Backorder**:
A line item accepted for fulfilment with no stock reserved against it. It is
part of the order from the moment it is accepted; what it lacks is a
reservation, not a commitment.
_Avoid_: Pending item, out-of-stock order, waitlist
```

Entries may be grouped under `##` headings; the headings are free-form and mean nothing to a
parser. What a parser does key on is the shape, and the shape has sharp edges worth stating
exactly, because every one of them fails quietly:

- **The term line is `**Term**:` followed by a newline.** The definition begins on the *next*
  line. Writing `**Term**: a definition on the same line` does not produce a malformed entry —
  it produces **no entry**. The term is invisible to every check that walks the parsed list,
  including the ones that would have told you something was wrong.
- **The `_Avoid_: ` line is required, with the space after the colon.** An entry that omits it
  does not fail a "missing `_Avoid_` line" check. It does something worse: the parse runs past
  the blank line and swallows the *following* entry, taking that entry's `_Avoid_` line as its
  own. Two entries silently become one, the second term disappears from the glossary as far as
  any check can see, and both checks still pass. This is the single most expensive way to get
  the format wrong.
- **A blank line ends the entry**, so entries are separated by blank lines and nothing but the
  definition sits between the term line and its `_Avoid_` line.
- **The term carries no `*` and no newline** — it is one line, between the two bold markers.

The definition is a sentence or three of prose. It says what the thing *is*, and it may say
what makes it distinct from the neighbor a reader would confuse it with. It does not say how
it is implemented.

### `_Avoid_` is the load-bearing half

The `_Avoid_` line names the near-synonyms a reader would otherwise reach for — the words that
mean something *close* to the canonical term and are therefore the ones that get typed instead
of it.

It carries the weight because the failure it exists to catch is silent. An `_Avoid_` word used
as the canonical name in a task title, a commit message, a symbol, or a doc heading produces
no error, no warning, and no failing check anywhere. The wrong noun ships, it is read, and it
is copied. Write the `_Avoid_` list as the actual words you have watched people use, not as a
thesaurus entry.

## Every term must be used

A term is defined so that the surface can use it. The check that follows from that is
mechanical: **every glossary term appears somewhere on the project's primary surface** — its
specification or its README — matched case-insensitively, at word boundaries, in the singular
or its regular plural.

Two disciplines fall out of it:

- **A glossary term nothing else uses is cruft.** Either the surface should be using the word
  and is not — fix the surface — or the project does not actually have that concept and the
  entry goes. An unused entry is not harmless: it is a name a reader will adopt, believing it
  is the governed one.
- **Regular plurals only.** The pluralization is the ordinary English rule — consonant + `y`
  becomes `ies`, everything else takes a plain `s`. A term whose only appearance on the surface
  is an irregular plural reads as unused even though the prose is correct, so define the term
  in the form the surface actually uses.

The same standard applies in the other direction: **an entry that describes behavior must
agree with the runtime.** When it does not, the entry is wrong by definition — see *The spec
and the code win* — and it is corrected in the change that discovers the disagreement, not
filed as a follow-up.

## The active discipline

Four moves, all of them made *during* the conversation rather than after it. Batching them is
how a glossary rots: the meaning is sharpest at the moment it is being argued about.

### Challenge a term against the glossary

When someone uses a term that conflicts with what the glossary already says, call it out
immediately, and quote the entry. *"The glossary defines cancellation as X, but you seem to
mean Y — which is it?"* One of the two has to move, and deciding which is the whole point.

### Sharpen fuzzy or overloaded language

When a term is vague or carries two meanings in the same conversation, propose a precise
canonical name for each. *"You are saying account — do you mean the Customer or the User?
Those are different things."* An overloaded word is not a small problem; it is two concepts
sharing one name, and every downstream sentence inherits the ambiguity.

### Stress-test relationships with concrete scenarios

When domain relationships are on the table, invent specific scenarios that probe the edges and
force a precise answer about where one concept ends and the next begins. *"An order with three
line items, one of them refunded — is that one Order or two?"* Abstract agreement about a
relationship survives right up until a scenario splits it.

### Cross-reference a stated behavior against the code

When someone states how something works, go read whether the code agrees, and surface any
contradiction rather than recording the claim. *"The code cancels whole Orders, but you just
said partial cancellation is possible — which is right?"* This is the move that keeps the
glossary describing the shipped surface instead of the remembered one.

## Where things go

Two placement rules, both of them about not creating a second copy of something the
repository already has.

- **Record decisions where the repository already records them.** Before creating a directory
  for decision records, look for the practice that already exists — a design-record directory,
  an ADR tree, a decision log — and add to it. A second decision directory does not sit
  quietly beside the first: it emits the same structure, attracts half the writes, and drifts
  against the original, which is exactly the divergence a single source of truth exists to
  prevent. The glossary itself is never that home; an entry names a thing, a decision explains
  a choice.
- **Update the glossary in the same commit as the naming change.** When a term is settled or
  sharpened, the entry lands with the change that settled it — not batched, not deferred to a
  cleanup pass. A commit that renames the surface and leaves the glossary behind has created
  the disagreement this skill's central rule then has to resolve, and it has hidden the moment
  where the reasoning was still in hand.
