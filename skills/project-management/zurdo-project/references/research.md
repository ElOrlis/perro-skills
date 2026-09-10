# research

Lifecycle for research tickets: how they are written, run unattended, and consumed by phase PRDs.

---

## Ticket file format

A research ticket is a Markdown file in `docs/<initiative>/tickets/`. Name it after its question, kebab-cased:

```
docs/<initiative>/tickets/<question-slug>.md
```

Full template:

```markdown
---
type: research
question: <one sentence: the specific unknown>
status: open          # open | resolved
blocks: [phase-NN]    # phases that cannot proceed until this resolves; empty if none
blocked-by: []        # other ticket slugs this ticket depends on
---

## Question

<Body paragraph. Explain what is unknown, why it matters, and what shape the answer needs to take. Include enough context that a subagent can run with no further instructions.>

## Findings

<Populated by the subagent when research runs. Leave blank when opening the ticket.>
```

`status: resolved` is written by the subagent after findings are recorded. `blocks` drives phase gating; a phase listed here is set to `researching` until this ticket resolves.

---

## When to open a research ticket

Open one when a decision waits on a fact that cannot be discovered by reading the working directory:

- Third-party API behavior or rate limits not covered by local docs
- Library guarantees or version-specific limits
- Prior art or ecosystem conventions the team has not audited
- Data shapes from an external system the code will consume

Do **not** open a research ticket for a fact a `grep` or file read answers. Look it up inline and state the finding. Research tickets pay for themselves only when the lookup is slow, external, or requires synthesis across multiple sources.

---

## Running research AFK

Spin one subagent per open research ticket. Do not wait for one to finish before launching the next — all open tickets run in parallel.

Each subagent's brief contains three things:
1. The `## Question` body from the ticket file (verbatim).
2. The destination file: `docs/<initiative>/tickets/<slug>.md`.
3. The instruction to write `## Findings` there, flip `status: resolved`, and run `zurdo-github.sh ticket <file>` when done.

The subagent:
- Writes findings directly into the ticket file under `## Findings`.
- Sets `status: resolved` in the frontmatter.
- Runs `zurdo-github.sh ticket <file>` (dry-run first) to push the resolved ticket to GitHub.
- Never edits `scope.md`. Scope is the reviewer's domain.

---

## Findings quality bar

Every `## Findings` section must meet these four standards:

**Cite sources.** Every factual claim names its source: a URL for external material, a repo-relative path for local material. Uncited claims are not findings.

**Separate observed facts from recommendations.** State what is true, then separately state what to do about it. Label each section: "Observed:" and "Recommendation:" or equivalent.

**End with the one line the PRD should carry.** The last paragraph (or a labeled `PRD line:` entry) is the specific statement the phase PRD's intro will quote or paraphrase. One sentence. Actionable.

**List new questions under `## Follow-ups`.** If research surfaces an unknown the ticket did not anticipate, list it there. The reviewer decides whether to open a new ticket or record the question as fog in `scope.md`. Do not resolve follow-ups inline.

---

## Blocking a phase

Set `blocks: [phase-NN]` in the ticket frontmatter. The script reads this field when the epic exists and sets the phase status to `researching`. If the epic does not yet exist (research runs before the PRD is published), the script defers the edge — it records the intent but cannot wire the GitHub relationship until the epic is created during `zurdo-github.sh publish`.

A phase in `researching` status:
- Does not graduate to PRD authoring.
- Does not allow `zurdo-prd-author` to run.
- Remains blocked until every ticket in its `blocks` chain is `resolved`.

When the last blocking ticket resolves, the phase status returns to `planned` and PRD authoring can proceed.

A research ticket whose findings compare approaches and must be decided on measurement, not taste, graduates to a design record: invoke `zurdo-design-author` to write `docs/<initiative>/design/<topic>.md`, and link the record from the ticket's `## Findings` and from the phase PRD's `## Background`.

---

## Consumption: linking research in the PRD

The phase PRD's intro section links every research ticket it relied on by repo-relative path:

```markdown
## Background

This phase was informed by the following research:
- [Webhook retry expectations](../../tickets/webhook-retries.md)
- [Auth scheme survey](../../tickets/webhook-auth.md)
```

`zurdo-prd-author` reads those linked files as context during its evidence-inventory phase and re-reads them in its review phase to verify the PRD's claims are consistent with the findings. The links provide traceability: anyone reading the PRD can follow the citation back to the sources that justified its decisions.

---

## Grilling tickets: the contrast

Grilling tickets share the same file format and directory but differ in every operational respect.

| | Research | Grilling |
|---|---|---|
| `type:` | `research` | `grilling` |
| Resolved by | subagent, AFK | user, live HITL session |
| Agent autonomy | runs and writes findings | surfaces the question, waits, records the answer |
| Parallelism | all open tickets at once | one ticket per session |
| Protocol | this file | references/interview.md |

A grilling ticket is never answered by the agent on the user's behalf. If the user is absent, leave the ticket open and hold dependent work. When the user answers, record the answer in `scope.md` Decisions before closing the ticket.
