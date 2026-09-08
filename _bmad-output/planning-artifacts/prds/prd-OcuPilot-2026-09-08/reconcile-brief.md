---
title: 'Reconciliation: product brief vs PRD'
status: draft
created: '2026-09-08'
input: '../../briefs/brief-OcuPilot-2026-09-08/brief.md'
input-addendum: '../../briefs/brief-OcuPilot-2026-09-08/addendum.md'
prd: 'prd.md'
prd-addendum: 'addendum.md'
---

# Reconciliation: product brief vs PRD

What the product brief and its addendum say that the PRD and PRD addendum failed to carry forward, contradicted, or silently weakened. Read fully on 2026-09-08: `brief.md`, the brief `addendum.md`, `prd.md` (1,017 lines) and the PRD `addendum.md`. Nothing in those files was changed.

Verdict in one line: the brief was carried forward with unusual fidelity. Every decision, risk, open question, judgment call and success signal has a landing spot. The problems are a handful of quiet expansions and softenings that the PRD addendum's decision list (section 1) does not record, one confirmation-gate placement that weakens the brief's write model, and two terminology splits the glossary does not settle.

## 1. Carried forward correctly

| Brief statement | PRD location |
| --- | --- |
| Angular replacement for the SMP, served from the instance | prd §1 Vision |
| Panel docked right "the way VS Code docks its secondary side bar", present on every screen, resizable, never dismissed by navigation (addendum decision 3) | prd §1, §5.2 description, FR-10 |
| Agent knows the current screen; visible toggle turns context off | FR-11, glossary "screen context" |
| Read tool per screen, write tool per action; every write proposed with rationale and confirmed | FR-16, FR-17, §5.3 description |
| Runs strictly as the logged-in user, no added privileges | FR-18, §7.1 |
| Writes marked distinctly in the audit log | FR-22, NFR-7, glossary "agent marker" |
| Progress on multistep turns | FR-12, NFR-2 |
| Read-only mode and administrator kill switch (addendum decision 2) | FR-19, FR-20; PRD addendum §1.2 adds the per-user read-only toggle |
| Screen refreshes and highlights after a confirmed write, or a toast links to it (CP-42); agent can navigate the user (CP-43) | FR-14, FR-15 |
| Six areas, one group each, as list/detail/create/edit/delete/enable-disable wherever a route exists | §5.5 to §5.10, §10.1 |
| Backend = existing REST services (`/api/admin` v2, `/api/monitor`, `/api/mgmnt`); pin v2, check `apiVersion` at startup, OpenAPI under test (addendum decision 5) | FR-3, NFR-8, §8 |
| "Screens and an agent, not a backend" = working system, not demo screens | prd §1 paragraph 2 |
| Silent-first JWT: empty-body `POST /api/admin/login`, form fallback, one Bearer for every JWT-enabled API, `%ISCMgtPortal` group, Group by ID accepted for the contest (addendum decision 6) | FR-1, FR-2, FR-65, NFR-3, PRD addendum §2 |
| Four provider families incl. local OpenAI-compatible; first-login gate; test connection (addendum decision 7) | FR-25, FR-27, FR-28 |
| One IPM module; Docker Compose self-installs; `HSCUSTOM` else `USER`; ObjectScript under `src/OcuPilot` (addendum decision 8) | FR-64, FR-66, FR-67, PRD addendum §6 |
| Runs on IRIS Community and IRIS for Health Community | FR-68, NFR-13 |
| Built on IRIS's own management APIs, satisfies contest wording, rides vendor direction | prd §2 bullet 2 |
| Execute-with-approval; the field drafts or acts without an agent marker | prd §2 bullet 3, PRD addendum §9 |
| Design target developer-administrators; production administrators served by the switches | prd §3.1 |
| First place Experts is the goal, Community placement the floor | SM-1 |
| Six areas demonstrable, one confirmed agent write in each | SM-3 |
| One-minute demo from a README that installs first time | SM-4, UJ-3, UJ-5 |
| In-scope P0 list (shell, agent core, six areas, four log viewers, deliverables), 119 rows | §10.1 |
| Cut line order and its five steps (addendum "Cut line inside P0"); unfinished large editor links to classic page | §10.1 cut line, FR-9 |
| Polish week items: suggested prompts, explain-this-screen, agent audit viewer, OAuth 2.0 editors, secondary log viewers, bonus deliverables | FR-70, FR-71, FR-75, FR-77, FR-79, §10.2 |
| Out before the deadline list | §10.4 |
| Four top risks | §12 rows 1, 2, 7, 10 |
| Post-contest: parity, every iris-session-agent capability, screen per iris-execute-mcp-v2 tool, agent as primary way | prd §1 paragraph 3, §10.3 |
| Post-contest sequence 1 to 5 (addendum) | §10.3 Stages 2 to 6; PRD addendum §14 explains the renumbering |
| Agent growth: single writes, guided workflows, undo, streaming | §10.3, PRD addendum §1.7 |
| Three vendor-attention signals in rising order | SM-6 |
| Parity milestones on a public roadmap, each with a DC article | §10.3 opening paragraph |
| "The line that does not move" | prd §1 "Two lines do not move at any stage", §7.1 |
| Naming rules (agent co-pilot / the agent / the panel) | glossary §4 |
| Harvest map (three rows) | PRD addendum §5, expanded to four sources with reuse/adapt/do-not-inherit |
| Five judgment calls | PRD addendum §11 |
| Contest facts and hard requirements | PRD addendum §13 |
| Five secondary risks (Group by ID, license, Freshmen, durable volume, legacy CSP pages) | §12 rows 3 to 6, OQ 5, 9, 10, PRD addendum §12 |
| Five carried open questions | OQ 1, 2, 3, 4, 12 |

## 2. Gaps

Things the brief says that the PRD and its addendum do not.

### G-1. Server-side confirmation gate is in the brief's harvested governance layer; the PRD defers it to the polish week — **high**

Brief addendum, harvest map: iris-execute-mcp-v2 supplies "server-side confirm gates" as part of "the governance model" that gives OcuPilot its head start. Brief body: "Every write the agent proposes is shown, reviewed, and confirmed before it runs."

PRD addendum §4: "The governance model to copy from iris-execute-mcp-v2 **for the polish week (CP-33)**: ... server-side confirmation gates in ObjectScript ..." FR-17's consequences say the write "runs only when the user presses Confirm on that card; the confirmation is bound to that exact proposal" but never say *where* that binding is enforced. FR-19 and FR-20 do say their refusals are server-side ("turns are refused server-side, not only hidden client-side"). FR-17 is the one place the brief's write model lives and it is silent.

If the gate is client-side in Release 1, SM-5 ("zero writes carrying the agent marker without a matching confirmed proposal") and "the line that does not move" are unenforceable on the instance, and a prompt-injected turn (§12 row 9 acknowledges this risk) could reach a write endpoint. Should land as an FR-17 consequence: "The OcuPilot API refuses any write whose proposal id has no matching, unexpired confirmation; the check is server-side. The client card is presentation only." And PRD addendum §4 should split the confirmation gate (Release 1) from the rest of the governance copy (polish week).

### G-2. "Three custom endpoints" became an open-ended set without a recorded decision — **medium**

Brief: "The only new server code is three custom endpoints: messages.log, the application error log, and the agent runtime." Brief addendum decision 5: "Custom endpoints only where no route exists: `messages.log`, the application error log, and the agent runtime."

PRD §1 still says "a small set of custom endpoints for the **two** logs that have no route and for the agent runtime itself", but FR-60 adds a third log endpoint ("history comes from a bounded tail of the file through the OcuPilot API" for alerts.log), and PRD addendum §3 lists: agent runtime "roughly six", messages.log paging, application error log, **alerts.log history tail**, and **read-only and kill-switch state**. None of this is in PRD addendum §1. The alerts tail satisfies decision 5's rule (no route exists) but not its enumeration, and prd §1 is now internally wrong. Should land as PRD addendum §1 decision 16 ("custom endpoints: the three groups the brief names plus the alerts.log history tail; switch state rides on the agent runtime group") and a one-word fix in prd §1 ("two logs" to "three logs" or "the logs that have no route").

### G-3. Problem statement not carried — **medium**

Brief "The problem": "The six contest areas alone span about 40 classic pages with terse errors and no help beyond a docs link. Nobody ships an assistant inside the IRIS portal." and "An entry that only rebuilds the six areas is the thin interface the rules disqualify."

The PRD has no problem section. "Nobody ships an assistant" survives in §2; "Zen-era menu" survives in §3.1; "thin interface" survives only as a non-user rationale in §3.2. The pain that FR-8 (uniform errors) and FR-70 (explain-this-screen) answer, "terse errors and no help beyond a docs link", is nowhere. Should land as one paragraph at the top of §2 or a short §1.1 "The problem", so the epics for FR-8 and FR-70 can cite it.

### G-4. The contest deliverables as the brief scoped them — **medium**

Brief "Scope", in the P0 paragraph: "The deliverables are a README with install steps and a video, **a Developer Community article, an online demo**, and an Ideas Portal link." The PRD puts the README, video and Ideas Portal link at P0 (FR-69) and moves the DC article and online demo to the polish week (FR-79, P1, after 2026-09-27). The brief's own polish-week line says "and the bonus deliverables", so the brief is ambiguous, and the catalog (PK-16 to PK-24 at P1) supports the PRD, but the PRD does not say it resolved the ambiguity. Because the article and demo are bonus-point items and voting opens 2026-09-28, a voter's first look may or may not find them. Should land as a PRD addendum §1 decision naming the catalog as the tie-breaker, and OQ 8 (demo hosting) should say by which date the demo must be live.

### G-5. "Writes are on by default" — **medium**

Brief: "Writes are on by default. Two switches restrain them." Brief addendum decision 2: "Read-only mode and an administrator kill switch exist as switches, **not defaults**."

The PRD never states writes-on-by-default as a principle. Two places pull the other way: FR-20 "The installer seeds the agent disabled until the first agent definition is enabled" (the kill switch engaged as the install default, conflated with the first-login gate), and FR-72 / PRD addendum §4 "default-disabled destructive writes" and "new write keys are disabled by default" (the harvested governance baseline). The brief's harvest map does list "default-disabled writes" as what iris-execute-mcp-v2 supplies, so the tension is inherited, but the PRD should state which it means: Release 1 write tools are all on unless a switch is thrown; the polish-week governance policy may default *new* or *destructive* keys off. Should land as a sentence in §5.3 description or §7.1, and FR-20's seeding rule should be re-expressed as the first-login gate (FR-28), not the kill switch.

### G-6. Success for developer-administrators leans on a polish-week feature — **low**

Brief "Who this serves": "Success for them is the right screen in one step, **an explanation of what they are looking at**, and the change made without a click tour." Explain-this-screen (CP-23/24) is FR-70, polish week. Release 1 covers it only through free-form questions with screen context (UJ-1). The PRD should say so in §3.1 or SM-4 so nobody reads Release 1 as failing the design target's success definition.

### G-7. "Parity is the credibility ticket, not the measure" — **low**

Brief addendum, brief-time decisions: "Post-contest success is vendor attention. Parity is the credibility ticket, not the measure." SM-6 carries the signals; the sentence that stops parity from becoming the metric is absent. One clause on SM-6 or in §10.3's opening paragraph.

### G-8. The contest "invites extra screens or actions" — **low**

Brief "The problem": the contest "invites extra screens or actions, and rejects thin interfaces." The invitation is what the polish week and the agent answer; the PRD only carries the rejection (§3.2). Low, but it is the sentence that justifies FR-73 to FR-78 to a judge.

### G-9. Post-contest agent growth is not restated as bound by the line that does not move — **low**

Brief closes "After the contest" with the line that does not move, placing it as the constraint on undo, workflows and streaming. prd §1 says "at any stage" which covers it, but §10.3's Stage 4 (guided multistep workflows) and Stage 5 (undo by snapshot and revert) do not say each step of a workflow, and each undo, is itself a confirmed and agent-marked write. One sentence under the §10.3 table.

## 3. Contradictions

### Deliberate PRD-time overrides, recorded in PRD addendum §1

| Brief | PRD | Recorded as |
| --- | --- | --- |
| 22 large P0 rows (body, top risk 2, addendum cut line step 5) | 12 large, 11 distinct (§10.1, §12 row 2, PRD addendum §10) | decision 5, OQ 13 |
| Polish week is 62 rows | 61 rows, CP-28 to Stage 2 | decision 15, §10.2 |
| Two switches, both administrator's | Read-only mode also per user in the panel | decision 2 |
| First-login gate "configures the provider and tests the connection before the portal opens" | Gate is instance-level and fires only for OcuPilot administrators; other users get the panel's empty state | decision 1 (who is gated) |
| Streaming last in agent growth | Stage 5, with OQ 14 to pull it forward | decision 7 |
| No Analytics stage named | Analytics rides Stage 4 | decision 8 |
| Post-contest sequence numbered 1 to 5 | Stages 2 to 6 | PRD addendum §14 |
| Cut line step 5 names "the task wizard" | Adds "edit task" (FR-53) | catalog TM-13; not recorded but consistent |

### Accidental drift, not recorded anywhere

**C-1. Daily-improvement window tripled.** Brief success criterion: "Listed on Open Exchange with a submittable build on 2026-09-14, then a visible improvement **every day of the voting week**" (seven days, 09-28 to 10-04). Brief addendum: "improve visibly through 2026-10-04". PRD SM-2: "each day **from then [09-14] to 2026-10-04** has at least one user-visible change" and §10.1 "every day after that adds something visible" (21 days, across the build's hardest fortnight). Either the brief meant the longer window and should say so, or SM-2 should read "every day of the voting week, and as often as possible before it". Affects SM-2, §10.1, SM-C3.

**C-2. First-login gate softened from hard to bypassable.** Beyond decision 1's scoping of *who* is gated, UJ-2's edge case lets an administrator whose test fails "still browse every screen with the panel in its configuration-empty state", so the gate is a redirect, not a gate, even for the person it targets. The brief says the gate runs "before the portal opens". For a contest judge this matters: a bypassed gate produces exactly the "rebuilt screens only" state §3.2 calls a thin interface. Affects FR-28, UJ-2. Either record the softening as a decision or make FR-28 hard for administrators.

**C-3. Kill switch scope.** Brief: "an administrator kill switch". PRD addendum decision 2: "The kill switch and enforced read-only mode are **instance-wide**." FR-20 and the glossary: "disable the agent globally **or for one user**." The per-user kill is either an unrecorded expansion of decision 2 or a slip in FR-20. Affects FR-20, glossary, PRD addendum §1.2.

**C-4. Kill switch as install default.** Covered in G-5: FR-20 seeds the agent disabled at install, against the brief's "switches, not defaults". FR-20 also cross-references the first-login gate as "(FR-29)"; the gate is FR-28 (FR-29 is the administrator privilege).

**C-5. "Self-installs on start" hedged.** Brief body: "the Docker Compose workspace self-installs **on start**." FR-67: "Whether install runs at image build or at container start is an architecture decision"; PRD addendum §6 proposes build-time load plus start-time idempotent re-check. The hedge is sensible and OQ 5 carries it, but it is not in PRD addendum §1 and the brief addendum's decision 8 wording ("a Docker Compose workspace that self-installs") is the one the PRD should quote, since it does not say "on start". Affects FR-67, OQ 5.

**C-6. Polish-week ordering is a PRD-time decision the addendum does not record.** Brief lists the polish-week items without ordering. §10.2 orders them "FR-70 and FR-71 first because voters see them, then FR-79's bonus deliverables as the bonus post dictates, then the rest", placing bonus deliverables ahead of the OAuth editors and secondary log viewers. Reasonable; should be a decision in PRD addendum §1.

**C-7. Platform floor stated two ways.** NFR-13: "IRIS 2026.2 or later" (decision 13). PRD addendum §6: "`<SystemRequirements>` for IRIS 2022.1+". Internal to the PRD, but it is the brief's "runs on IRIS Community and IRIS for Health Community" claim that the manifest would mis-state. Affects PRD addendum §6.

**C-8. Stage range stated two ways.** §10.3 heading and PRD addendum decision 4 say "Stages 2 through 5"; the §10.3 table, the glossary and PRD addendum §14 say Stages 2 through 6. The brief's five post-contest steps map to Stages 2 to 6. Affects §10.3 heading, decision 4.

**C-9. License wording.** Brief addendum secondary risk: "Read the terms **before choosing** a license." PRD OQ 9: "Is the MIT license **already in the repository** compatible". The repository does contain `LICENSE` (MIT, 2026, jbrandtmse) and README links to it, so the PRD is right and the brief is stale. No PRD change; the brief's line should be corrected at the next brief edit.

## 4. Qualitative ideas the FR structure silently dropped

- **"The agent co-pilot is the product." / "A working rebuild of the six areas is the floor."** The brief's two bold headings are its thesis. prd §1 says "defining feature", and SM-C1 (screen count counter-metric) carries the spirit, but the sentence that tells an epic writer where to spend a contested day is missing. One line in §1 or §9: "The screens are the floor; the agent co-pilot is the entry."
- **"What makes this different"** has no section in the PRD. Three of the five differentiators are folded into §2 "Why Now" (management APIs, execute-with-approval, agent-marked audit). Two are dropped as positioning: **"A local-model option that keeps data on the instance. It turns the data-egress objection into a selling point for regulated shops"** (the mechanism is in §7.2, the selling point is not; this is the line the DC article and README need) and **"A head start"**, the empty field plus the two sibling projects as a competitive advantage (§8 treats them only as harvest sources). §12's last row cites "the differentiators in section 2" as a mitigation, so the PRD believes it has a differentiator list; it has three fifths of one.
- **"Bring your own model."** The brief's one-phrase positioning for FR-25 became "Four provider families including local models". The phrase belongs in FR-25's title or the §5.4 description; it is what a voter remembers.
- **"Screens that answer the agent."** The brief's name for CP-42/CP-43 became FR-14 "Screen synchronisation after agent writes" and FR-15 "Agent-driven navigation". Accurate, and colder. The UX document should get the brief's phrase.
- **How the demo should land** is carried well: UJ-3 is the brief's one-minute demo almost verbatim, UJ-5 is the judge's path, SM-4 makes it measurable. Two additions are new and unrecorded: the "two-minute video" length in UJ-5, and the "screen highlight and audit marker" as part of the one-minute target in SM-4 (the brief asked only for a confirmed change on a real screen). Both are improvements; both should be owned.
- **Voice.** The brief is declarative and short; the PRD matches it. No drift in tone. The one register change is the brief's "the change made without a click tour" becoming, in §3.1, "instead of a click tour through a Zen-era menu", which is fine.
- **Success for the production administrator**: "an audit log that shows exactly what the agent did, and nothing done that they did not approve." Carried in §3.1 and SM-5. Good.

## 5. Terminology drift

The brief addendum's rules: the feature is **agent co-pilot** (never bare "co-pilot"); the software is **the agent**; the panel is **the agent co-pilot panel** or **the panel**.

**Compliance with the three rules:** clean. The glossary states all three exactly (with the "never shortened" clause). No bare "co-pilot" appears in prd.md or the PRD addendum. "Copilot" appears once, in PRD addendum §9, as the product name "Azure Copilot agents", which is correct. "Assistant" appears in §2 and §12 only to describe the field, not OcuPilot. "The panel" and "the agent" are used consistently through the FRs and journeys.

**Two splits the glossary does not settle:**

- **Audit log / audit database / agent audit ledger.** The brief uses "audit log" for the IRIS audit trail throughout ("marks its writes distinctly in the audit log", "visibly marked in the audit log", "an audit log that shows exactly what the agent did"), and its harvest map uses "audit log" for the sibling projects' own logs. The PRD glossary defines **agent audit ledger** (OcuPilot's own) and uses **audit database** in FR-22, FR-47, FR-61, NFR-7 and the glossary's "agent marker" entry for the IRIS one, but never defines "audit database", and the text still says "audit log" for the IRIS trail in §3.1 (twice), §1 ("marked in the audit log"), and FR-75 ("copy and purge the audit log"). Three names for two things. The glossary should add **audit database** (the IRIS audit trail, `%SYS` `Security.Audit`... viewed by FR-61) and either retire "audit log" or state it means the audit database.
- **Conversation / transcript / chat history.** FR-10 and FR-12 say "conversation" ("keep the panel and its conversation", "on the same conversation"); FR-12, §7.2 and decision 14 say "transcript"; FR-72, §7.2, PRD addendum §5 and §8 say "chat history". None is in the glossary. The split also hides a scope question: FR-12 (Release 1) says the transcript "survives a page reload", while FR-72 (polish week) says "Chat history persists by screen with a retention purge task", so persistence is Release 1 and retention is P1, which is fine but should be said once. Add **conversation** (or **transcript**) to the glossary and use one word.

**Minor:**

- The brief addendum says the agent "grows in step with the **phases**"; the PRD says **Stage**. Glossary defines Stage; fine, but a brief edit should adopt "Stage".
- Brief: "an administrator kill switch"; PRD: "OcuPilot administrator" (a defined role holding a resource). A refinement, and the glossary defines it; fine.
- Brief: "the agent runtime"; PRD: "the OcuPilot API ... holding the agent runtime endpoints" and "agent definition" as new vocabulary. Consistent.
- PRD §5.12 and §10.2 say "P1 rows"; the brief says "catalog P1". Same thing; fine.
