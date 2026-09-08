---
title: 'Product Brief: OcuPilot'
status: final
created: '2026-09-08'
updated: '2026-09-08'
project: OcuPilot
evidence: '../../research/technical-ocupilot-portal-feature-landscape-2026-09-08/research.md'
catalog: '../../research/technical-ocupilot-portal-feature-landscape-2026-09-08/feature-catalog.md'
addendum: 'addendum.md'
---

# Product Brief: OcuPilot

Citations such as (research, D2) or (catalog P0) point to the [research report](../../research/technical-ocupilot-portal-feature-landscape-2026-09-08/research.md) and its [feature catalog](../../research/technical-ocupilot-portal-feature-landscape-2026-09-08/feature-catalog.md). Depth for the PRD and architecture is in the [addendum](addendum.md).

## Executive summary

OcuPilot is an Angular replacement for the InterSystems IRIS System Management Portal, served from the IRIS instance itself. Its real feature is an agent co-pilot: a panel docked on the right, the way VS Code docks its secondary side bar, present on every screen. The agent in the panel knows which screen the user is looking at, answers questions about it, and changes settings through tools that run strictly as the logged-in user. Every write the agent proposes is shown, reviewed, and confirmed before it runs, and the affected screen refreshes and highlights what changed.

The immediate goal is first place in InterSystems' "Build Your Own Management Portal" contest (Open Exchange contest 48). Submissions close 2026-09-27 23:59 EST. The contest names six portal areas, and OcuPilot rebuilds all six as working screens wired live to the instance's existing REST services, chiefly a hidden `/api/admin` v2 service. Only three custom endpoints are new server code, so the 19-day build is screens and an agent over an API that already exists (research, insight 2). As of 2026-09-08 the field is empty.

After the contest, OcuPilot grows toward full portal parity in the order the research catalog gives, with one aim: to be the administration portal InterSystems itself points at.

## The problem

IRIS administrators still manage security, users and roles, tasks, OS monitoring, and logs in a Zen-era portal that InterSystems has deprecated but only partly replaced. The vendor's new interface covers interoperability only (research, D2). The six contest areas alone span about 40 classic pages with terse errors and no help beyond a docs link. Nobody ships an assistant inside the IRIS portal.

The contest sharpens this. It asks for "a GUI powered by InterSystems IRIS management APIs" covering six areas, invites extra screens or actions, and rejects thin interfaces over an existing API (research, D1). An entry that only rebuilds the six areas is the thin interface the rules disqualify.

## The solution

Eight decisions were made before this brief and are not reopened here: the contest scope, the agent co-pilot's write model, the always-visible panel, interactive screens, the REST backend, silent-first JWT authentication, the provider set, and the packaging. Full statements are in the [addendum](addendum.md). The five blocks below restate them as the product.

**The agent co-pilot is the product.** The panel receives the current screen as context, and a visible toggle turns that off. The agent has a read tool for every screen and a write tool for every action, and proposes each write with its rationale for the user to confirm. It runs as the user with no added privileges, marks its writes distinctly in the audit log, and shows progress on multistep turns. Writes are on by default. Two switches restrain them: read-only mode and an administrator kill switch.

**Screens that answer the agent.** After a confirmed write, the affected screen refreshes and highlights what changed, or a toast links to it. The agent can take the user to the relevant screen.

**A working rebuild of the six areas is the floor.** One group per area: web applications and a REST API explorer; users, roles, resources, and services; SSL/TLS, X.509, LDAP, OAuth 2.0, wallet secrets, and audit configuration; task scheduling and history; processes, locks, system usage, CPU and memory, databases, and devices; and the logs. Every screen reads and writes live through the instance's existing REST services. The only new server code is three custom endpoints: messages.log, the application error log, and the agent runtime.

**Bring your own model.** It works with OpenAI, Anthropic, Google Gemini, and any OpenAI-compatible endpoint, including local models. A first-login gate configures the provider and tests the connection before the portal opens.

**Installs in one step.** One IPM module installs it, and the Docker Compose workspace self-installs on start. It runs on IRIS Community and IRIS for Health Community.

## What makes this different

- **Built on IRIS's own management APIs.** This satisfies the contest wording verbatim and rides the vendor's direction: the administration API is being built before the administration UI (research, insight 3).
- **Execute-with-approval from the panel.** The field mostly drafts. Where it acts, it logs under the user with no agent marker (research, D8).
- **Distinct audit marking of agent-initiated changes.** No product in the research has it.
- **A local-model option that keeps data on the instance.** It turns the data-egress objection into a selling point for regulated shops.
- **A head start.** The advantage is an empty field and two sibling projects: iris-session-agent supplies the agent core and iris-execute-mcp-v2 the governance layer.

## Who this serves

**Design target: developer-administrators.** They administer their own dev and test instances, often Community Edition in Docker, and they are also the Developer Community voting audience. Success for them is the right screen in one step, an explanation of what they are looking at, and the change made without a click tour.

**Served by the switches: production IRIS administrators.** Ops staff on live and often regulated instances get the same product with the switches turned toward caution: read-only mode, the kill switch, and a local model. Success for them is an audit log that shows exactly what the agent did, and nothing done that they did not approve.

## Contest success criteria

By 2026-09-27, improving through 2026-10-04:

- First place in the Experts nomination is the goal. A Community placement is the floor.
- Listed on Open Exchange with a submittable build on 2026-09-14, then a visible improvement every day of the voting week.
- All six areas demonstrable, with at least one confirmed agent co-pilot write in each.
- A demo where the agent makes a confirmed change on a real screen in under a minute, from a README that installs the first time.

## Scope

**In for the contest (catalog P0, 119 rows):** the shell; the agent co-pilot core; the six areas as list, detail, create, edit, delete, and enable/disable wherever a route exists; the four log viewers; and the submission deliverables. The deliverables are a README with install steps and a video, a Developer Community article, an online demo, and an Ideas Portal link.

**Cut line if the sprint runs short, keeping in this order:** list and detail screens with their read tools, then the agent co-pilot core, then small write actions, then medium editors, then large editors. An unfinished large editor links to the classic portal page rather than shipping half-done.

**Polish week (catalog P1, 62 rows, 2026-09-28 to 2026-10-04):** suggested prompts, explain-this-screen, the agent audit viewer, the OAuth 2.0 editors, secondary log viewers, and the bonus deliverables.

**Out before the deadline:** interoperability, System Explorer, Analytics, database operations, mirroring, streaming beyond progress indication, undo, and everything at P2 to P4.

## Top risks

- **The hidden admin API is unsupported and undocumented.** Only its list and get calls have been observed, never its write payloads. Pin v2, check the API version on load, and keep the OpenAPI document under test (research, Rec 2).
- **One developer, 19 days, 22 catalog rows sized large.** The cut line and the early listing are the mitigation.
- **Technology bonuses and partial-coverage acceptance are unstated until the 2026-09-14 kickoff.** The plan rests on precedent and is rechecked then.
- **No moat.** The vendor could ship this. Speed and continuous visible improvement are the mitigation.

Secondary risks and the open questions carried from the research are in the addendum.

## After the contest

OcuPilot becomes the administration portal InterSystems has not yet built and can point at. That means full parity with the System Management Portal, every iris-session-agent capability, and a screen equivalent for every iris-execute-mcp-v2 tool. The agent co-pilot is the primary way changes are made, and it grows from confirmed single writes to guided multistep workflows, undo, and streaming. The sequence is fixed by API readiness and is laid out in the addendum.

Success is vendor attention. Three signals matter, in rising order: a product-team conversation with InterSystems about OcuPilot or the `/api/admin` service; InterSystems referencing OcuPilot in a Developer Community post, webinar, or documentation; and a design choice from OcuPilot, such as agent-marked audit or execute-with-approval, appearing in the vendor's own product. Parity milestones shipped on a public roadmap, each with a Developer Community article, earn that attention.

The line that does not move: the agent never holds a privilege the user does not, and every agent write stays visibly marked in the audit log.
