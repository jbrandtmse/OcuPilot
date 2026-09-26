# Outline: the second Developer Community article (the BMAD Method)

<!-- Outline for the owner's second contest article, worth the contest's second-article point. Draft
it after the release; publish early in the voting week. Every number below was counted from the
repository's own record on 2026-09-25/26; the source is named beside it. Re-count the story and
commit totals on the day of publishing. -->

## Working titles

1. *Human in the loop, twice: building an AI co-pilot for IRIS with the BMAD Method*
2. *The afterthought that isn't: how the BMAD Method made an AI agent safe enough to switch on*
3. *Agentic engineering, not vibe coding: 19 days, 145 stories and the BMAD Method*

Recommended: 1. It carries the thesis - the human-in-the-loop design of the product and of the
process that built it - and it is findable by people searching for BMAD.

**Length:** 2,000-2,400 words. **Visuals:** the story pipeline as a diagram, stories per day as a
small chart, one screenshot of a real story spec and one of the deferred-work ledger.

## 1. The hook (about 150 words)

- Open on Aleksandr Tsvetkov (Banksia Global), writing after InterSystems READY 2026 Asia: *"We'd
  put a human-in-the-loop approval step into our agent project almost as an afterthought. ... in
  agentic AI the hard, interesting engineering isn't getting a model to call tools, it's making that
  safe and observable enough that a regulated [organization] would actually switch it on."*
  (His spelling is British; the published article keeps it, and the bracket here only satisfies
  the repository's spelling check.)
  Confirm the attribution on the post before publishing.
- Turn: in OcuPilot that step was never an afterthought, because it was decided in the
  architecture on day one, before a line of code. That is what the BMAD Method is for.
- Thesis: human in the loop at two levels - in the product (every agent write is a proposal you
  confirm, executed as you, marked in the audit database) and in the process that built it (AI
  agents working under a spec, a review and a human who decides).

## 2. Who is telling this, and why OcuPilot is a fair test (about 200 words)

- A BMAD advocate who spoke at READY 2026 - *"Agentic Engineering
  Live on Stage"*, Tuesday 28 April - and built a loan-broker application live from a single
  product brief ([READY-2026-LoanDemo](https://openexchange.intersystems.com/package/READY-2026-LoanDemo)).
  The slide that summarized the talk: **"BMAD Method = Context Engineering."**
- Also the author of the [IRIS MCP Server
  Suite](https://openexchange.intersystems.com/package/IRIS-MCP-Server-Suite-2), which the agents
  used to drive IRIS throughout.
- Why OcuPilot is a harder test than the live demo: a contest deadline, a management portal with
  six areas, and a product whose core feature is an AI agent allowed to change an IRIS instance.
  First commit 7 September; submission 26 September.

## 3. Agentic engineering is not vibe coding (about 150 words)

- The distinction from the talk: vibe coding asks a model for code and hopes; agentic engineering
  gives agents durable context - a brief, requirements, a UX contract, an architecture - and holds
  every change to it.
- BMAD in one line, in its own words: "Breakthrough Method for Agile AI-Driven Development" -
  *"turn an idea or change request into working software without giving up the thinking."*
  ([bmad-code-org/BMAD-METHOD](https://github.com/bmad-code-org/BMAD-METHOD); OcuPilot used v6.12.0.)

## 4. Planning in 28 hours (about 450 words)

From the BMAD install to the first line of code took about 28 hours of clock time (08 Sep 05:56 to
09 Sep 10:16, from git) - and, per the owner, a couple of hours of their own effort. In that time:

- **Analysis.** A 503-word idea became a research report (17,000 words, 46 sources) and a feature
  catalog of **538 portal features in five priority bands** - rows are never deleted, only moved to
  the long tail. A time-boxed spike (about two hours) settled authentication before anyone designed
  a screen.
- **Planning.** A brief with eight decisions "not reopened here"; a PRD with 80 functional and 14
  non-functional requirements. The feasibility review costed the scope at **about 45 developer-days
  against 19**. The decision: keep the scope and make the build order the cut line - *"The boundary
  between two epics is exactly a point at which the project could stop and still submit."*
- **UX.** A design system (128 color roles across light and dark, 42 components) and an experience
  contract with every screen's states and a canonical table of every user-facing string (268 rows
  today).
- **Solutioning.** An architecture spine of 47 binding decisions at finalize - 56 today, each later
  one added in the open. Quote the spine on itself: *"An AD skimmed is an AD violated."*
- **The safety decisions were made here, on paper.** Quote them verbatim:
  - AD-40: *"Confirm is reachable only from the browser, and the write gate is on the write."*
  - AD-10: *"Prohibited actions are absent from the tool set, not gated within it."*
  - AD-11: *"The model is assumed compromised by anything it reads. The defense is these five
    checkable rules, not a posture."*
  - Every agent write marked in the IRIS audit database.
- **Epics and stories.** 22 epics and 206 stories at finalize (229 today), ordered so the six
  contest areas and the ask-review-confirm-audit path landed first.

Point to make: this is Tsvetkov's "hard, interesting engineering", and BMAD put it in the
architecture before any code existed to get it wrong.

## 5. Implementation as a loop, not a chat (about 400 words)

- **The story cycle** (the `/epic-cycle` command, [public kit](https://github.com/jbrandtmse/bmad-epic-cycle-command)):
  plan, spec gate, implement, mutation checks against the architecture's decisions, QA,
  adversarial code review, ledger adjudication, smoke test, CI. Per epic: a burn-down gate, a
  decision sheet, a merge gate. Diagram this.
- **Two epics at a time.** Each runner had its own IRIS instance and its own throwaway containers
  for tests; an owner-approved dependency graph decided what could run beside what (*"take the
  more conservative graph"*).
- **The numbers** (cycle logs and git):
  - 144 stories done by the submission build; median **3.0 hours** from plan to commit.
  - About 6 stories a day sequentially, about 10.7 a day with two runners, 16 a day over the last
    three days.
  - 1,956 commits, 68% of them bookkeeping - the process recording itself.
- **Real IRIS in the loop.** Every story compiled and tested against a live instance through the
  IRIS MCP Server Suite; CI ran the suite against a fresh IRIS container on every push. Provider
  behavior was checked with live keys separately, because CI stubs them.
- **Positioning:** BMAD's own v6.11 made "Build" the official implementation loop and a new BMad
  Loop module runs a whole epic unattended; `/epic-cycle` is one practitioner's version of the same
  idea, with a parallel orchestrator and a ledger. Say this plainly rather than claim novelty.

## 6. Nothing a reviewer finds is allowed to disappear (about 350 words)

- **The deferred-work ledger:** 1,136 entries. Final status: 47% resolved, 22% accepted as won't
  fix with a reason, 21% routed to a named later story, the rest by design, theoretical or
  dropped - and 3 still open.
- Why it matters: the kit's own field report from an earlier project - *"0 → 1,588 entries in 114
  days, never once shrinking."* Rule 17's answer: *"The drain is a stage, not a sentence."* Every
  entry is born with an owner; every epic runs a burn-down gate.
- **Code review:** 63 HIGH, 679 MEDIUM and 1,461 LOW findings reported across 131 stories; mean
  HIGH+MEDIUM findings per review fell from 9.1 in Epic 1 to 3.9 in the parallel run, as the rules
  accumulated. Mark the causal reading as an inference.
- **Observed reds:** *"a test whose red has not been observed is not evidence."* QA recorded 322
  demonstrated mutations - a deliberate break that must turn a test red.
- **Rework:** 22% of stories needed at least one rework; CI caused 20 of 36 rework events.

## 7. What went wrong, and what each taught (about 450 words)

Pick four or five; each is one short paragraph of what happened, what it taught and the rule it
left behind.

- **Gates that could not fail** (9 Sep, stories 1.1-1.3): a claimed fix re-applied as a mutation
  left all 27 tests green; a regex cut every line at the `//` in `https://`; tests ran as `_SYSTEM`,
  whose `%All` bypassed the very resource under test. Lesson: an agent's report of its own
  verification is not verification.
- **The 43-hour story** (Story 1.4): nine implement iterations and five review rounds treating a
  Task Manager "latency" with longer waits. The real cause was `%OpenId` handing back an object the
  poll loop still held. The spec reached 664 KB. Lessons: an exit for the rework loop, the rule on
  stale object references, and prose discipline - *"Every sentence a reviewer can file a finding
  against is surface area; keep the surface small."*
- **Eighteen test runs at once** (11 Sep): one message launched 18 test classes against one
  instance and left a database mounted with no file behind it. Rule: one test run at a time, at any
  depth.
- **Green suites over broken paths:** *"A suite that runs as %All cannot see a privilege-shaped
  defect."* And: *"A three-character needle in random material is a coin flip, which is exactly why
  it passed locally and reddened CI."*
- **A shared machine:** `git add -A` swept a document into an unrelated commit; an agent removed a
  container it had not started. Rules: stage by path; tear down only what you started.
- **Models and money:** 92.8% of spend was on the top model tier; moving implementation to a
  cheaper model made stories no faster and raised reworks and CI failures, so it moved back.
  *"Opus buys fewer reworks and reds."*

## 8. The human in the loop, in the build (about 300 words)

- What I kept: priorities, scope, security posture, merges to `main`, publishing. What I delegated
  after the first week: routine clarifications, answered by the orchestrator under a standing grant
  and logged for review.
- Decisions that changed the product: ranking the OAuth 2.0 editors ahead of the agent refinements
  because the contest named OAuth; reversing a ban on privileged grants in four minutes -
  *"remember this is a developer tool first"*; making new agent definitions read/write so a judge
  succeeds the first time.
- **Using the product is part of the loop.** Nine findings from using a nightly build; eight
  became stories and shipped - two provider defects went from report to merge in about seven
  hours, a dropped-connection fix in under six. CI could not have found them: it stubs the
  providers.
- The point: the same pattern as the product - the agents propose, a human confirms.

## 9. What I would tell a team starting BMAD on IRIS (about 200 words)

- Plan until the architecture can say no. Make it a contract, not a backlog.
- Make safety an architecture decision, not a feature.
- Give every review finding an owner and a stage that drains it.
- Demand observed reds; distrust any green that no mutation has tested.
- Keep specs and comments small; narration becomes review surface.
- Put a real IRIS in the loop: throwaway containers, CI against a fresh instance, MCP tools for
  the agents.
- Keep humans on what cannot be undone: merges to production, publishing, security posture.

## 10. Close and links (about 100 words)

- OcuPilot: [ocupilot.org](https://ocupilot.org) (demo), the repository with every planning
  document under `_bmad-output/`, the first article, the Open Exchange listing.
- The BMAD Method; the `/epic-cycle` kits; READY-2026-LoanDemo; the IRIS MCP Server Suite.
- Ask readers what they would never let an agent do on their instance - and for their vote.

## Before drafting

- Confirm the Tsvetkov attribution on the LinkedIn post itself.
- Re-count stories done and commits on the day.
- Positioning: the only Developer Community article found that covers BMAD is Henry Pereira's
  *The Sorting Hat of Vector ReOrdering* (11 Sep 2026), which has one BMAD section; none walks a
  whole BMAD project on IRIS.
- Separately: the LoanDemo README expands BMAD as "Brian Madison Agentic Development"; the
  official expansion is "Breakthrough Method for Agile AI-Driven Development".
