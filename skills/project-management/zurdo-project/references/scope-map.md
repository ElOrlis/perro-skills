# scope-map

Wayfinding mechanics: source-of-truth model, ticket discipline, fog vs. sharp questions, and concurrency rules.

---

## The destination

State the destination first — before phases, before tickets. It anchors the entire scope and is the standard against which every later decision is measured. A well-formed destination fixes scope because it names what done looks like, not how to get there.

Three shapes a destination can take:

- **A spec to hand off** — "Produce a webhook delivery library with retry, backoff, and an observable events contract, documented so a separate team can integrate it without consultation."
- **A decision to lock** — "Choose and document the auth scheme for outbound webhook calls so all phases can depend on a single answer."
- **A change made in place** — "Migrate the CSV exporter to streaming output so files larger than 100 MB succeed without buffering the entire payload in memory."

The destination belongs in `docs/<initiative>/scope.md` under `## Destination`. Write it once, refine it when a research or grilling ticket changes your understanding, and treat every other section as downstream of it.

---

## The scope file

`docs/<initiative>/scope.md` is the source of truth. GitHub issues and the scope issue are projections. Never update `scope.md` from GitHub state — edits flow the other way.

### Section order

```markdown
# Scope: <Initiative Title>

## Destination

<One or two sentences: what done looks like, from the outside. No implementation detail.>

## Notes

<Bullet list of domain context, standing preferences, and skills to consult. Not decisions — things that inform decisions.>

## Decisions so far

<One line per resolved ticket: gist + link. Empty until the first ticket resolves.>

## Phases

| Phase | Title | PRD | Status |
|-------|-------|-----|--------|
| phase-01 | <Title> | <path or blank> | <status> |

## Not yet specified

<Bullet list of open questions that are not yet sharp enough to ticket. Fog lives here.>

## Out of scope

<Bullet list of items explicitly excluded. One line each, with the reason.>
```

### What each section holds

**Destination** — the single fixed outcome. Rewrite it only when a fundamental assumption changes.

**Notes** — domain facts, standing preferences, skills to consult. Anything that informs decisions but is not itself a decision. Never use this section to park deferred choices; those belong in "Not yet specified."

**Decisions so far** — one line per resolved ticket: the gist of the answer plus a link to the ticket file. The map is an index, not a store. Full reasoning lives in the ticket's `## Findings`.

**Phases** — a table. The Phases table has five status values:

| Status | Meaning |
|---|---|
| `planned` | Not yet started; no PRD written. |
| `researching` | Blocked by at least one open research or grilling ticket. |
| `running` | PRD written and published; Zurdo is executing tasks. |
| `review` | Zurdo run complete; awaiting phase review before the next phase graduates. |
| `done` | Phase review passed; outcomes absorbed into scope; phase closed. |

**Not yet specified** — fog. Open questions that cannot yet be stated precisely enough to ticket. Items graduate out of here when a research or grilling ticket sharpens them into a decision or a new phase row.

**Out of scope** — explicit exclusions with a one-line reason each. Items land here because they are outside the destination's scope, not because they are hard or deferred.

### The scope issue, Project description, and Project README are projections

`scope.md` is rendered onto three GitHub surfaces, all by the same command:

| Surface | What it shows | Source section |
|---|---|---|
| Scope issue body | All six sections, phases table re-rendered with epic and milestone links | whole file |
| Project description | The first Destination paragraph, one line, capped at 256 characters | `## Destination` |
| Project README | The scope issue body without the marker, under a `# <initiative title>` heading | whole file |

Refresh all three with:

```bash
zurdo-github.sh scope --dry-run   # preview
zurdo-github.sh scope             # live refresh
```

Always run `--dry-run` first and read the plan. Never edit the scope issue body, the Project description, or the Project README directly; the next `scope` run overwrites them. Keep the first Destination paragraph to one or two sentences so the description reads cleanly in the Projects list; the truncation is a safety net, not a formatting tool.

---

## Refer by name

In every surface a human reads — scope.md, ticket files, PRD intros, phase review notes — name tickets and phases by their title. Let the issue number ride inside the link, not in the surrounding prose.

Correct:
> Blocked by [Webhook retry policy](tickets/webhook-retries.md).
> Phase [CSV export](docs/example/prds/prd-01-csv-export.md) is `running`.

Wrong:
> Blocked by ticket #14.
> Phase 1 is running.

The title is the stable identifier. Numbers are routing; titles are meaning.

---

## Fog or ticket

**The test:** can the question be stated precisely right now — not answered, just stated?

- If yes → open a ticket.
- If no → leave it in "Not yet specified" as fog.

**Examples of fog** (leave in "Not yet specified"):

- "Something about CSV schema versioning" — no question formed yet.
- "Performance concerns with large payloads" — unclear what dimension matters or what threshold triggers action.

**Examples of sharp questions** (open a ticket):

- "Should we embed the schema version in the filename or in a separate manifest file?" — two concrete options, one answer needed.
- "What retry and backoff policy do the target webhook endpoints expect?" — answerable by reading their documentation.

**No pre-slicing.** Do not decompose fog into multiple tickets based on guesses about what sub-questions exist. Pre-slicing produces tickets that evaporate or contradict each other when the fog clears. One fog item stays one fog item until a single sharp question emerges from it.

**Graduating fog.** When a research or grilling ticket resolves, move the fog item out of "Not yet specified":

- If the answer locks a decision → remove the fog item; add one line to "Decisions so far" linking the resolved ticket.
- If the answer reveals a new phase is needed → add a row to the Phases table; remove the fog item.
- If the answer narrows the question but does not resolve it → rewrite the fog item with the tighter phrasing; open a new ticket if it is now sharp.

---

## Out of scope

An item lands in "Out of scope" because it is outside the destination's scope — not because it is too hard, too slow, or deferred to later.

- Write one line with the explicit reason: "Streaming large exports (> 1 GB) — the destination targets monthly snapshots under 100 MB."
- Close the corresponding ticket if one exists. One-line comment in the ticket: "Closed as out of scope — outside the destination's target payload size."
- Never put out-of-scope items in "Decisions so far." Decisions record what was chosen; out-of-scope records what was excluded. They are different facts.
- An out-of-scope item returns only as a fresh initiative with its own destination. It does not graduate back into the current scope.

---

## Decisions so far

One line per resolved ticket. Format: gist of the answer, then a link to the ticket file.

```markdown
## Decisions so far

- [Which webhook auth scheme](tickets/webhook-auth.md) — bearer token from env var `WEBHOOK_TOKEN`, refreshed per invocation.
- [Retry policy for webhook delivery](tickets/webhook-retries.md) — exponential backoff, three attempts, 2s/4s/8s delays.
```

The map is an index, not a store. Full reasoning, options considered, and findings live in the ticket file itself under `## Findings`. Keep each decision line to one sentence. If the gist requires more than one sentence, the ticket's Findings section needs to be clearer.

---

## Claim and resolve

**Claim before work.** Assign yourself to the ticket issue before touching the ticket file. Claiming prevents two agents from working the same ticket concurrently.

```bash
gh issue edit <number> --add-assignee @me -R owner/repo
```

**At most one grilling ticket per session.** A grilling ticket requires the user's judgment. Opening more than one per session stacks multiple open questions in the user's attention at once. Open one, wait for it to resolve, then open the next.

**Research tickets may run in parallel.** Research is AFK — a subagent fetches and synthesizes without user input. Multiple research tickets can be in flight simultaneously, provided each blocks a different phase or sub-question.

**Resolve a ticket** in three steps:

1. Write `## Findings` in the ticket file with the answer. For grilling tickets, record the user's answer verbatim; do not paraphrase or reinterpret.
2. Flip `status: resolved` in the frontmatter.
3. Run `zurdo-github.sh ticket` to post the findings as a comment and close the issue.

After resolving, update `scope.md`: add the decision to "Decisions so far" or graduate the fog item, then run `zurdo-github.sh scope` to refresh the scope issue.

---

## Concurrency

Other sessions may be editing `scope.md`, ticket files, or the scope issue simultaneously. Before any live refresh:

```bash
zurdo-github.sh scope --dry-run
```

Read the full dry-run output. Confirm no other session has already applied the same change. Then run the live command. Never skip the dry-run gate.
