# interview

The inline protocol for eliciting scope, decisions, and phase outcomes when `grilling` or `grill-me` is absent. When either skill is installed, call it instead and use this file's three shapes as the agenda.

---

## The design tree and the frontier

Every decision branches: answering one question opens new ones; unresolved answers block others. The **frontier** is the set of questions that can be asked right now — questions whose premises are already known. Ask the entire frontier in one round; a question that depends on an open answer waits for the next round.

Rules:
- Number rounds (`Round 1`, `Round 2`, …) so the user can reference prior context.
- Never ask a question whose premise is still open; let it surface in a later round once the premise resolves.
- Close a round only when every question in it has been answered; do not carry unanswered questions forward.

---

## Facts versus decisions

**Facts** are discoverable without asking. Look them up before opening a round.
- Check the filesystem (`scope.md`, PRD files, existing issues).
- Read docs, previous ticket decisions, tooling config.
- Dispatch a subagent for a slow lookup and continue asking the rest of the frontier in parallel; fold the fact in before the next round.

**Decisions** require the user's values. Surface them as questions; never fill in the answer yourself.

If a question looks like a decision but is actually determinable from existing artifacts, look it up and state the finding instead of asking.

---

## Question format

Each question is a fenced block:

```
❓ **Q<n>** - **<title>**: <body>

➡️ <recommended answer> — grounded in <what was looked up or observed>.
```

- `<n>` is sequential within the round.
- `<title>` is a two-to-four-word label the user can scan.
- `<body>` is one sentence: the specific choice the user must make.
- The `➡️` line states a concrete recommendation and names its source. "Recommended" with no rationale is not a recommendation.

The user may answer **"all recommended"** to accept every `➡️` answer in the round at once.

---

## Three interview shapes

### 1. Destination interview

**Purpose:** Converge depth-first until the destination is one or two sentences.

**Opening question:**
> What are we trying to produce or change, and how will we know it's done?

**Protocol:**
- Each answer narrows the space; the next round tests the narrowed answer.
- Continue until the destination statement can be written as a spec to hand off, a decision to lock, or a change made in place (→ see references/scope-map.md).
- Do not fan out to phases or tickets until the destination is locked.

**Stop condition:** The destination fits in one or two sentences and names what done looks like from the outside, with no implementation detail required to understand it.

---

### 2. Breadth interview

**Purpose:** Fan out across the whole initiative in a single session to list phases, open tickets, and fog. Do not attempt to resolve fog here.

**Opening question:**
> Starting from the destination, what are the major phases of work, and what do you already know is unclear or risky?

**Protocol:**
- Ask one frontier round to surface all areas of known unknowing.
- For each area: is it sharp enough to write a ticket, or is it fog that needs research first?
- Sharp → open a grilling or research ticket. Fog → record in `scope.md` Notes.
- Do not recurse into any single phase; record it and move on.

**Stop condition:** Every area the user can name has been classified as a phase, a ticket, or fog. No further threads are dangling. Stop; do not resolve any open ticket in this session.

---

### 3. Phase review interview

**Purpose:** Close the completed phase by recording what was learned, what surprised, what is now sharp, and what is out.

**Opening question:**
> Now that this phase is done, what actually happened — what did you learn, and what would you do differently?

**Protocol:**
- Round 1: outcomes vs. plan (what finished, what did not, what changed mid-phase).
- Round 2: sharpened knowledge (what was foggy that is now clear; what new fog appeared).
- Round 3: scope changes (what is now in scope that was not, what is out, and why).
- Do not open tickets for the next phase here; record decisions and fog in `scope.md` first; graduate the next phase separately.

**Stop condition:** `scope.md` reflects the phase's outcomes, the Decisions so far section is current, and the Notes section records any new fog. No unresolved surprise is left without a ticket or a fog entry.

---

## When grilling or grill-me is installed

Call the installed skill instead of running this protocol inline. Pass the three shapes above as the agenda:
1. Which shape applies? (destination / breadth / phase review)
2. Hand the opening question for that shape to the skill as the first prompt.
3. Let the skill drive; record the outcome using the write-file-first rule below.

Do not run this protocol in parallel with the installed skill; hand off completely.

---

## Grilling tickets

A **grilling ticket** records a question that requires the user's live judgment. It is resolved only by running this protocol (or the installed skill) live with the user in a session. Rules:

- The agent never answers a grilling ticket on the user's behalf.
- The agent never marks a grilling ticket resolved without a recorded user answer.
- If the user is absent, leave the ticket open and block dependent work.
- When the user answers, record the answer in `scope.md` Decisions before closing the ticket.

---

## Recording

At the end of any interview — regardless of shape — write in this order:

1. **Write `scope.md` first.** Add the new decision(s) to `## Decisions so far`, update `## Notes` for any new fog, and revise `## Destination` if the session sharpened it.
2. **Refresh the scope issue.** Update the issue body to reflect the current `scope.md` state. The issue is a projection; `scope.md` is the source.

Never update the GitHub issue before the file. Drift originates from reversing this order.
