---
title: 'PRD: OcuPilot'
status: final
created: '2026-09-08'
updated: '2026-09-09'
project: OcuPilot
brief: '../../briefs/brief-OcuPilot-2026-09-08/brief.md'
evidence: '../../research/technical-ocupilot-portal-feature-landscape-2026-09-08/research.md'
catalog: '../../research/technical-ocupilot-portal-feature-landscape-2026-09-08/feature-catalog.md'
addendum: 'addendum.md'
---

<p align="center">
  <img src="../../../../logo/OcuPilot-Logo-web.png" alt="OcuPilot logo" width="360">
</p>

# PRD: OcuPilot

*Working title confirmed: OcuPilot.*

## 0. Document Purpose

This PRD is for the people and workflows that turn OcuPilot into software: the architecture, UX and epics work that follows it, and the one developer building it against a contest deadline. It states what OcuPilot must do, for whom, and in what order, without deciding how. It builds on three finished inputs and does not repeat them: the [product brief](../../briefs/brief-OcuPilot-2026-09-08/brief.md), which fixed the eight decisions this document inherits; the [research report](../../research/technical-ocupilot-portal-feature-landscape-2026-09-08/research.md), which is the evidence; and the [feature catalog](../../research/technical-ocupilot-portal-feature-landscape-2026-09-08/feature-catalog.md), whose 538 rows are the inventory. Catalog row IDs such as `CP-13` or `PM-07` appear next to requirements so that epics and stories can trace back to the inventory without re-reading it.

Vocabulary is anchored in the Glossary. Features are grouped by portal area with functional requirements nested and numbered globally. Inferences were tagged and resolved with the owner; see the addendum, section 1. Depth that belongs downstream, in architecture, UX or epics, is in the [addendum](addendum.md).

## 1. Vision

OcuPilot is an Angular replacement for the InterSystems IRIS System Management Portal, served from the IRIS instance it manages. Its defining feature is the agent co-pilot: a panel docked on the right of every screen, present on every route, that knows which screen the user is looking at, answers questions about it, and changes the instance through tools that run strictly as the logged-in user. Every write the agent proposes is shown with its rationale and expected impact, reviewed, and confirmed before it runs. After the write, the affected screen refreshes and highlights what changed, and the IRIS audit database records that the change came through the agent. The agent is the main conduit for editing: every write the six areas offer is reachable through it, and the screens' own editors are the second path.

The problem it addresses is concrete. IRIS administrators still manage security, users and roles, tasks, OS monitoring and logs in a Zen-era portal that InterSystems has deprecated but only partly replaced; the vendor's new interface covers interoperability only. The six contest areas alone span about forty classic pages with terse errors and no help beyond a documentation link, and nobody ships an assistant inside the IRIS portal.

Release 1 exists to win first place in InterSystems' "Build Your Own Management Portal" contest, Open Exchange contest 48, with submissions closing 2026-09-27 23:59 EST. The contest names six portal areas, and OcuPilot rebuilds all six as working screens wired live to the instance's existing REST services. The release is a working system, not demo screens: every list reads live, every editor writes live, and the only new server code is a small set of custom endpoints for the log files that have no route and for the agent runtime itself.

After the contest, OcuPilot grows in stages to full parity with the classic portal, adding every capability of the iris-session-agent project and a screen for every tool in the iris-execute-mcp-v2 suite, with the agent as the primary way changes are made. The destination is to be the administration portal InterSystems has not yet built and can point at. Two lines do not move at any stage: the agent never holds a privilege the user does not, and every agent write stays visibly marked in the audit database.

### 1.1 Release 1 commitment, listing build and floor

In scope: the shell (5.1), the agent co-pilot (5.2, 5.3, 5.4), the six areas as list, detail, create, edit, delete and enable/disable wherever a route exists (5.5 through 5.9), the four log viewers (5.10), and packaging and submission (5.11). That is 119 catalog rows: 70 small, 37 medium, 12 large. The commitment is all of it, with the demo video optional. The feasibility review at finalize estimates the work at about 45 developer-days against 19 (addendum, section 15). The head start is real but bounded: the sibling projects supply the agent core, the governance model and the REST, installer and static-serving patterns, but the runtime port is four to five days of the 19, not zero, and the screens and the panel are new. So the build is incremental: every step of the build order (section 10.1) ends in a publishable build, and any step can become the cut without leaving a half-built one behind.

**The listing build** is steps 0 and 1 plus a README with install steps and a description. The panel is present in read-only question-answering over those lists if step 2 has begun, otherwise in its configuration-empty state. A screens-only build is admissible for the listing but not for the application. It is **no longer dated 2026-09-14**: under the owner's stealth decision of 2026-09-09 (below) nothing is published before the release, so this is a readiness bar the build waits at rather than a calendar gate.

**The stealth release, targeting 2026-09-24.** Owner decision, 2026-09-09. Nothing about OcuPilot is published before the release: the repository stays **private**, the Open Exchange listing is not created early, and no bonus item — Developer Community article, YouTube video or short, Ideas Portal idea — appears before then. The reason is idea protection: the always-on co-pilot is the entry's differentiator and the most copyable thing about it, and a listing live from 2026-09-14 gives a competitor thirteen days to copy it. This reverses the "list early, improve visibly" strategy this document was written around, and the costs are paid deliberately: earlier entries rank higher on the contest page, forfeited outright; and the Community nomination, which depends on exposure the entry will not have accumulated, is substantially conceded in favour of the Experts nomination that SM-1 targets. The target is **2026-09-24 rather than the 2026-09-27 deadline** because Open Exchange approval is discretionary and not instantaneous while the deadline is absolute — three days of buffer for a reviewer's question or an install problem found in review. Releasing later does not move the deadline; it spends the buffer.

**The 2026-09-27 application floor.** The application may not fall below: steps 0 to 4 (section 10.1) complete; at least one create or edit form per area from step 5; no list screen in the six areas linking out to the classic portal; SM-3 met; and the UJ-3 demo reproducible end to end on a clean install. Below that floor the entry is the thin interface the rules reject.

### 1.2 Success Metrics

#### Primary

- **SM-1 Contest placement.** First place in the Experts nomination by the winners' announcement; a Community nomination placement is the floor. Validates the whole of Release 1.
- **SM-2 Released whole, improved daily through voting.** The Open Exchange listing carries a submittable build from the release, targeting 2026-09-24 and no later than the deadline, the application is approved rather than merely submitted, and each day of the voting week, 2026-09-28 to 2026-10-04, has at least one user-visible change. Validates FR-64, FR-67, FR-69. **Revised 2026-09-09**, replacing "Listed early, improved daily", which required a submittable build on the listing on 2026-09-14 and visible improvement from then to the deadline. The stealth decision in section 1.1 deliberately forgoes that, so the old metric would have been failed by design rather than by shortfall; what survives it is the part that still discriminates — that the entry is complete when it appears, gets through review, and visibly improves where voters are actually watching.
- **SM-3 Six areas, six confirmed writes.** In the submitted build, each of the six areas has at least one list backed by live data and at least one write that the agent can propose and the user confirm end to end. Validates FR-16, FR-17, FR-30 through FR-63.
- **SM-4 The one-minute demo.** From a README install that works the first time on a clean machine, a new user reaches a confirmed agent write with screen highlight and audit marker in under one minute of interaction. Validates FR-1, FR-14, FR-17, FR-22, FR-28, FR-67.

#### Secondary

- **SM-5 Nothing unconfirmed, nothing unmarked.** Zero confirmed proposals in the agent audit ledger without a matching marked event in the audit database, and zero marked events without a confirmed proposal, over the whole voting week. This measures the **pairing**, not the absence of failure: a failed audit marker never fails the write (that would be worse), so the metric holds only because every failure is itself recorded on the ledger row and surfaced on the tool-call card as "done, audit not marked" (FR-22). A write whose marker failed is a recorded, visible pair, not a silent gap. Validates FR-17, FR-21, FR-22.
- **SM-6 Vendor attention after the contest.** In rising order: a product-team conversation with InterSystems about OcuPilot or the admin API; a reference to OcuPilot in a Developer Community post, webinar or documentation; a design choice from OcuPilot appearing in the vendor's own product. Validates the staged delivery in 10.3.

#### Counter-metrics (do not optimize)

- **SM-C1 Screen count.** Do not add screens beyond the cut line at the expense of working writes. A screen without its read tool, or an action without its write tool, counts against SM-3, not toward it, and every link-out to the classic portal on a Release 1 screen counts against this metric. Counterbalances SM-3.
- **SM-C2 Confirmation friction.** Do not reduce the write path below one explicit confirmation per proposal to make SM-4 faster. Counterbalances SM-4.
- **SM-C3 Polish before floor.** Do not start a P1 item while any cut-line step 1 or 2 item is unfinished. Counterbalances SM-2.

## 2. Why Now

Timing is load-bearing for three reasons.

- **The contest window.** Registration opens 2026-09-14, submissions close 2026-09-27, and voting runs to 2026-10-04. Improvements are allowed through the voting week, and earlier submissions list higher on the contest page. The field is empty as of 2026-09-08, and prior art is dormant.
- **The vendor is building the API before the UI.** The hidden `/api/admin` v2 service covers namespaces, security, tasks, processes, databases and devices, and its dispatcher already rewrites headers toward a new portal prefix. InterSystems' own Angular modernization has reached only interoperability screens. An administration portal built on that API rides the vendor's direction and satisfies the contest's "powered by InterSystems IRIS management APIs" wording verbatim.
- **Nobody ships an assistant inside the IRIS portal.** Adjacent products either draft and refuse to act, or act without marking the agent in the audit trail. Execute-with-approval and agent-marked audit are open ground, and a local-model option turns the data-egress objection of regulated shops into a selling point.

## 3. Target User

### 3.1 Jobs To Be Done

**Developer-administrators** (the design target) administer their own development and test instances, often Community Edition in Docker, and are also the Developer Community voting audience.

- Get to the right screen in one step instead of a click tour through a Zen-era menu.
- Understand what a screen, a setting or a log entry means without leaving for the documentation.
- Make a routine change, such as enabling a web application, resuming a task or adding a role, by saying what they want and confirming what the agent proposes.
- Trust that nothing changed except what they confirmed, and be able to prove it from the audit database.
- Install the whole thing once, in one step, on a Community image.

**Production IRIS administrators** (served by read-only mode and the kill switch) run live and often regulated instances.

- Use the same portal with the agent restrained: read-only mode, the kill switch, and a model that keeps data on the instance.
- See in the audit database exactly what the agent did and what the human did.
- Never have the agent hold a privilege the operator does not.

**The builder** (the project owner) needs a plan that survives a 19-day solo build: a cut line inside Release 1, and stages after it.

### 3.2 Non-Users (Release 1)

- Operators of instances that must not expose an LLM provider at all and cannot host a local model. OcuPilot without any agent definition is only the rebuilt screens, which is a thin interface by the contest's own rule.
- Interoperability, analytics and SQL developers looking for the System Explorer or the production configuration screens. Those come in later stages.
- Mobile or tablet users. Release 1 targets desktop browsers.
- Anyone needing a language other than English in the user interface.

### 3.3 Key User Journeys

Journeys were drafted from the brief's demo criteria, the auth spike's two arrival paths and the catalog rows, and confirmed by the owner. Persona context is inline.

- **UJ-1. Dana arrives from the classic portal and asks what she is looking at.**
  - **Persona + context:** Dana Okafor, a developer who administers her own IRIS for Health Community container, has the classic portal open in another tab.
  - **Entry state:** Logged into the classic portal in this browser. Opens `/ocupilot` for the first time today.
  - **Path:** OcuPilot performs the silent login and shows Home with no form. Dana navigates to Permissions, then Users. The panel on the right already shows the screen context chip "Users, HSCUSTOM". She types "which of these users can't log in and why?". The agent calls the users read tool, answers with the disabled and expired accounts, and cites the rows it used.
  - **Climax:** The answer names two accounts and the reason for each, and clicking a citation selects the row in the list.
  - **Resolution:** Dana has not left the screen or the tab. Nothing was written.
  - **Edge case:** If the silent login fails because the classic session has ended, OcuPilot shows its own login form once; after login the vendor's editors are signed in again too, and the classic portal tab is expected to be as well (Open Question 15).

- **UJ-2. Dana installs OcuPilot from a clean clone and meets the first-login gate.**
  - **Persona + context:** Same Dana, on a laptop with Docker Desktop and no prior OcuPilot.
  - **Entry state:** Not authenticated. A fresh clone of the repository.
  - **Path:** Dana runs `docker compose up -d` and waits for the log to report startup complete. She opens `/ocupilot`, sees the login form, and signs in as `_SYSTEM`. Because no agent definition is enabled, OcuPilot redirects her to the agent configuration screen. She picks Anthropic, pastes an API key, and presses Test connection.
  - **Climax:** Test connection returns success with the model's reply in under ten seconds, and Save enables the agent. Home opens with the panel live.
  - **Resolution:** The instance has one enabled agent definition, stored on the instance and available to every user.
  - **Edge case:** If Test connection fails, the form shows the provider's error text, the definition stays disabled, and Dana can still browse every screen with the panel in its configuration-empty state and a persistent reminder banner until she comes back and enables one.

- **UJ-3. Dana fixes a disabled web application through the agent in under a minute.**
  - **Persona + context:** Dana is demonstrating OcuPilot on a video call, recording the contest demo.
  - **Entry state:** Authenticated, on the Web Applications list, which shows `/csp/myapp` disabled.
  - **Path:** She types "enable /csp/myapp and give it the %Development resource". The agent calls the web application read tool, then produces one proposal card: the target, the two field changes as a before/after diff, the rationale, and the expected impact ("users holding %Development can reach the application"). Dana presses Confirm.
  - **Climax:** The write runs as Dana. The Web Applications list re-fetches in place and highlights the `/csp/myapp` row, now enabled. The panel shows the tool call card with its result.
  - **Resolution:** She opens the audit database viewer and finds the event under her own user name with the description marked as coming through the OcuPilot agent co-pilot.
  - **Edge case:** If Dana lacks the privilege to modify web applications, the write fails with the same 403 the screen would show, and the agent says so instead of retrying.

- **UJ-4. Marcus runs OcuPilot read-only on a production instance.**
  - **Persona + context:** Marcus Lindqvist, operations administrator at a regional hospital, on an IRIS for Health instance where every change goes through change control.
  - **Entry state:** Authenticated through OcuPilot's own form. The OcuPilot administrator has turned on enforced read-only mode and configured a local model (a step 7 item in Release 1's build order, polish week otherwise), so no screen data leaves the instance.
  - **Path:** Marcus opens the messages.log viewer, finds a repeating warning, and asks the agent to explain it. The agent reads the log entry through its read tool and explains the cause and the usual remedy. Marcus asks it to apply the remedy.
  - **Climax:** The agent declines the write, states that the instance is in read-only mode, and tells him what he would change on which screen.
  - **Resolution:** Marcus raises the change through his normal process. The context chip names the local provider and host, so Marcus can see that the log text never left the instance.
  - **Edge case:** If the OcuPilot administrator later engages the kill switch, Marcus's panel shows a disabled state on his next turn and the screens keep working.

- **UJ-5. Priya evaluates the entry as a judge.**
  - **Persona + context:** Priya, an InterSystems Developer Community member judging or voting, with thirty minutes and a laptop.
  - **Entry state:** On the Open Exchange listing. Not authenticated anywhere.
  - **Path:** She follows the README: clone, `docker compose up -d`, open the URL. The install works the first time. She reads the walkthrough, or watches the video if there is one, then repeats UJ-2 and UJ-3 herself. She opens each of the six areas from the navigation and, in each, sees at least one list backed by live data and at least one action the agent can propose.
  - **Climax:** The README's promised path, install to first confirmed agent write, works without a workaround.
  - **Resolution:** She votes, or scores complexity, clarity of instructions, developer experience, applicability and usability, with the six areas checked off.
  - **Edge case:** If the `_SYSTEM` password is expired on her Community image, the README's install step has already cleared it; if not, the login form explains the expiry and links to the fix.

- **UJ-6. Dana troubleshoots a suspended task and lets the agent take her there.**
  - **Persona + context:** Dana, in Home, notices the Task Manager line in the panel's suggested view.
  - **Entry state:** Authenticated, on Home.
  - **Path:** She asks "why did the nightly purge task stop?". The agent reads the task list and the task's history, finds it suspended after an error, and offers to open it. Dana says yes. The agent navigates the browser to the task details screen with that task selected, then proposes Resume with the last error as context.
  - **Climax:** Dana confirms. The task resumes, the details screen highlights the status field, and a toast links to the row in the task list.
  - **Resolution:** The task's history now shows the manual resume attributed to Dana through the agent.
  - **Edge case:** If the task's error recurs on resume, the next history row shows it, and the agent's follow-up answer cites that row rather than claiming success.

## 4. Glossary

Downstream documents must use these terms exactly.

- **OcuPilot** — the product: the Angular portal, the OcuPilot API, the agent runtime and the installer, delivered as one IPM module.
- **classic portal** — the InterSystems System Management Portal shipped with IRIS, at `/csp/sys/`.
- **instance** — the IRIS instance OcuPilot is installed on and manages. OcuPilot manages exactly one instance, the one serving it.
- **admin API** — the `/api/admin` v2 REST service on the instance: experimental, with a published spec, final in IRIS 2027.1. OcuPilot pins version 2.
- **OcuPilot API** — OcuPilot's own REST application on the instance, holding the agent runtime endpoints and the custom endpoints the admin API lacks.
- **area** — one of the six contest-named groups of screens: Web applications and REST API explorer; Permissions; Security and secrets; Tasks; OS management; Logs.
- **screen** — one route in OcuPilot: a list, a detail, an editor, a wizard or a viewer.
- **agent co-pilot** — the feature: the panel plus the agent plus its tools. Never shortened to "co-pilot" alone.
- **the panel** — the agent co-pilot panel docked on the right of every screen.
- **the agent** — the software inside the panel that runs a turn: an LLM loop with tools.
- **agent definition** — a named, instance-level configuration of provider, model, endpoint, credential reference and limits. Many may exist; one is the default.
- **provider** — an LLM backend: OpenAI, Anthropic, Google Gemini, or any OpenAI-compatible endpoint including local models.
- **turn** — one user message and everything the agent does until it answers: LLM calls, tool calls, and the final reply.
- **conversation** — the sequence of turns the panel holds in one browser tab. It continues across route changes, and each turn records the screen context in force when it was sent. One turn runs at a time per conversation.
- **transcript** — the stored record of a conversation on the instance, kept per user.
- **screen context** — what the panel sends with each turn about the current screen: route, namespace, selected entity and visible rows.
- **read tool** — an agent tool that reads through the same endpoint a screen reads from. Never writes.
- **write tool** — an agent tool that changes the instance through the same endpoint a screen writes to. Always produces a proposal first.
- **proposal** — the agent's card describing one intended write: target, before/after diff, rationale, expected impact.
- **confirmation** — the user's explicit approval of one proposal, bound to that proposal. Nothing writes without it.
- **change event** — the client-side notification a confirmed write emits (entity type, id, action) that screens consume to refresh and highlight.
- **agent marker** — the fixed text in the IRIS audit event description that identifies a write as made through the agent co-pilot.
- **agent audit ledger** — OcuPilot's own record of every LLM call and tool call, with arguments and results.
- **audit database** — the IRIS audit database on the instance, where every audited event lands, including agent writes carrying the agent marker. Distinct from the agent audit ledger.
- **read-only mode** — a state in which every write tool is blocked. Enforced instance-wide by an OcuPilot administrator, or chosen per user in the panel.
- **kill switch** — an OcuPilot administrator setting that disables the agent globally or for one user. The screens keep working.
- **OcuPilot administrator** — a user holding the OcuPilot administrative resource created at install. Manages agent definitions, the kill switch and enforced read-only mode.
- **first-login gate** — the state when no agent definition is enabled: OcuPilot administrators are sent to agent configuration; other users see the panel's configuration-empty state.
- **silent login** — an empty-body login against the admin API that succeeds when the browser already holds an instance login, so no form is shown.
- **form login** — OcuPilot's own user and password form, shown when silent login fails.
- **token pair** — the access and refresh tokens the shell holds per browser tab and sends as a Bearer to every JWT-enabled API on the instance.
- **embedded editor** — an InterSystems Angular editor (Rule, DTL, BPL) loaded in place inside OcuPilot. Not in Release 1.
- **catalog row** — one line of the feature catalog, identified as `XX-nn`. Requirements cite rows for traceability.
- **tier** — the catalog's priority band: P0 contest build, P1 polish week, P2 API-backed parity, P3 custom-REST parity, P4 long tail.
- **size** — the catalog's complexity rating: S list only, M list plus form or dialog, L wizard, editor or console.
- **Release 1** — the contest deliverable: all P0 rows by 2026-09-27, built incrementally in the order of section 10.1 with the demo video optional, plus P1 rows during the voting week to 2026-10-04.
- **Stage** — a post-contest delivery increment toward parity, numbered Stage 2 through Stage 6. Release 1 is the first increment.
- **cut line** — the fixed order in which Release 1 work is dropped if time runs short.

## 5. Features

Each feature names its catalog rows. Every list and detail screen carries a read tool and every action carries a write tool (CP-12, CP-13); those are stated once in 5.3 and not repeated per screen.

Index: 5.1 shell FR-1 to FR-9 · 5.2 panel FR-10 to FR-15 · 5.3 tools and governance FR-16 to FR-23 · 5.4 configuration FR-24 to FR-29 · 5.5 web applications FR-30 to FR-34 · 5.6 permissions FR-35 to FR-41 · 5.7 security and secrets FR-42 to FR-47 · 5.8 tasks FR-48 to FR-53 · 5.9 OS management FR-54 to FR-59 · 5.10 logs FR-60 to FR-63 · 5.11 packaging FR-64 to FR-69 · 5.12 polish week FR-70 to FR-79 · 5.13 staged delivery FR-80.

### 5.1 Portal shell and sign-in

**Description:** The shell is what every screen shares: sign-in, the header strip, navigation for the six areas, page chrome, error handling and auto-refresh. Sign-in is silent-first. A user arriving from the classic portal is never asked to log in; a user arriving cold sees OcuPilot's form once, and afterwards the classic portal and the vendor's editors are signed in too. One token pair serves every JWT-enabled API on the instance. On load, the shell checks that it is talking to the instance and API version it was built for. Realizes UJ-1, UJ-2, UJ-5.

**Functional Requirements:**

#### FR-1: Silent-first sign-in

A user can reach OcuPilot without a login form when the browser already holds an instance login, and with one form login otherwise. Realizes UJ-1, UJ-2. Catalog: SH-01.

**Consequences (testable):**

- On load the shell attempts silent login first; a success shows no form.
- A silent-login failure shows the form login; a correct user and password signs in and also signs the browser into the vendor's editors, as observed in the auth spike, and into the classic portal by the same mechanism. Confirmed by configuration probe on 2026-09-08: `/csp/sys`, `/api/admin` and `/ui/interop` all carry `GroupById = %ISCMgtPortal` and all use cookies, and `/ui/interop` is the application the spike watched share the session (Open Question 15, closed).
- The classic portal shares the browser-level login only. `/csp/sys` is not JWT-enabled, so it rides the CSP session cookie and the browser id, never the token pair, and the token pair is never presented to it.
- The token pair is held per browser tab, never in persistent browser storage, and every call to a JWT-enabled API carries it as a Bearer header.
- The shell refreshes the token pair before the access token expires and once more on any 401; a failed refresh returns the user to the form login with the current route preserved.
- Cookies alone never authorize a data call.

#### FR-2: Sign-out

A user can sign out of OcuPilot and thereby end the browser-level instance login. Catalog: SH-10.

**Consequences (testable):**

- After sign-out, every JWT-enabled application in the vendor's group, including the vendor's editors, stops minting tokens for that browser, and the classic portal's authenticated session ends with it.
- Sign-out does not promise that the classic portal shows a login form. `/csp/sys` permits unauthenticated access alongside password authentication, so a tab left open on it may keep rendering as an unauthenticated session rather than prompting. The testable claim is that the authenticated session has ended, not that a form appears (Open Question 15, closed 2026-09-08).
- Tab storage is cleared and the user lands on the form login.

#### FR-3: Instance identity and API version guard

The shell can verify, on every load, that the admin API is present at version 2 and that the instance identity matches what it last saw. Catalog: SH-11, PK-09.

**Consequences (testable):**

- When the admin API reports a version other than 2, or is absent, the shell shows a blocking notice naming the mismatch and linking to the classic portal, and no area screen loads.
- A signed-in user who holds no `%Admin_*` resource receives the admin API's 403 on that same call; the shell renders it as "no administrative privileges on this instance" with a sign-out link, not as a version mismatch.
- The instance name and version shown in the header come from the same call.
- The generated OpenAPI document for the admin API is kept under an automated test that fails when a route OcuPilot uses disappears.

#### FR-4: Privilege-driven navigation for the six areas

A user can see and open only the screens their IRIS privileges allow, organized by the six areas. Catalog: SH-02, SH-05.

**Consequences (testable):**

- Menu entries and routes are gated by the caller's privilege map from the admin API, which authorizes by `%Admin_*` resources; the classic portal's finer gates, such as `%DB_IRISSYS`, are not reproduced in Release 1.
- A screen the user lacks privilege for is shown disabled with a tooltip naming the required resource, not hidden.
- Navigation offers a category selector and a finder view of each area's screens.

#### FR-5: Header strip and namespace switch

A user can see the server, instance, namespace, user, licensed-to and server flag at all times, and switch namespace. Catalog: SH-03, SH-04, EX-01.

**Consequences (testable):**

- The namespace selector lists only namespaces the user can read and write.
- The chosen namespace is carried on routes and included in screen context.
- The server flag shows Live, Test, Failover or Development as the instance reports it.

#### FR-6: Page chrome

Every screen carries a locator bar and a per-page command bar. Catalog: SH-07, SH-08.

**Consequences (testable):**

- The locator bar shows the area, the screen and the selected entity, and each segment navigates.
- The command bar holds the screen's actions, view options, sort and search.

#### FR-7: Auto-refresh framework

A user can turn auto-refresh on or off on list screens, set the rate, and see the last-update stamp, with sort, filter, page size and maximum rows persisted per screen. Catalog: SH-09.

**Consequences (testable):**

- Processes, Databases, Task details and Task schedule use the framework; refresh does not reset the user's sort, filter or selection.
- Refresh pauses while a proposal is awaiting confirmation on that screen, so the diff under review does not move; the pause ends when the proposal is resolved or expires (FR-17).

#### FR-8: Uniform error handling

Every server failure reaches the user as one consistent message with the action to take. Catalog: SH-06.

**Consequences (testable):**

- The OcuPilot API returns one error envelope; the shell renders admin API and OcuPilot API errors the same way.
- A 401 triggers the refresh-and-retry path in FR-1; a 403 names the missing privilege.
- A failed call runs a connectivity probe and distinguishes "instance unreachable" from "request refused".
- Internal exceptions are logged fully on the instance and reported generically to the browser.

#### FR-9: Classic portal fallback links

Every classic portal page in the six areas that OcuPilot has not rebuilt is reachable from the corresponding OcuPilot screen by a link to the classic page. Catalog: cut line rule.

**Consequences (testable):**

- A cut large editor ships as a reduced form of the fields that daily administration uses plus a link to the classic page for the rest, never as a half-working full form; a list screen never links out. A **detail view** may link out, and only where its descriptor declares a `classicLinkExemption` with a reason; the automated check honors that flag, reports every exemption it honors, and counts them against SM-C1. The OAuth 2.0 tabs (FR-44) are the one such exemption in Release 1.
- The agent's write tool for that editor's action still ships (5.3), so the change can be made through a confirmed proposal even while the form links out.
- The link opens in a new tab where the user is expected to be signed in already (FR-1); if the classic portal does not honor the browser login, its own form appears once.

### 5.2 Agent co-pilot panel

**Description:** The panel is docked on the right of every screen like VS Code's secondary side bar. It is present on every route, is never dismissed by navigation, resizes, and can go full screen. Each turn carries screen context unless the user turns that off. The panel shows progress while the agent works, refuses a second concurrent turn, renders the reply as Markdown, and, after a confirmed write, refreshes and highlights the affected screen. The agent can also take the user to a screen. Realizes UJ-1, UJ-3, UJ-6.

**Functional Requirements:**

#### FR-10: Always-visible docked panel

A user sees the panel on every screen and can resize it or expand it to full screen; it is never closed by navigation. Realizes UJ-1. Catalog: CP-01.

**Consequences (testable):**

- The panel has a minimum width and a remembered width per browser; screen content reflows to the remaining width.
- Route changes keep the panel and its conversation.
- There is no close control in Release 1. Narrow-viewport behavior below about 900 px is a UX decision, not a requirement here.

#### FR-11: Screen context on every turn, with a toggle

The agent receives the current screen context with every turn, and the user can turn context sharing off, a choice remembered per user. Realizes UJ-1. Catalog: CP-09, CP-10.

**Consequences (testable):**

- Screen context includes route, namespace, selected entity and the visible rows of the current list or the current form's values.
- Screen context is assembled fresh on every turn from the screen the user is on at that moment, so navigating between turns changes what the agent sees.
- A context chip in the panel names what is being shared, the provider and endpoint host of the agent definition in use, and says "leaves the instance" when that host is not on a private network; with context off, no screen data is sent on subsequent turns, and the chip says so. This part of the polish week's egress disclosure (CP-31) ships in Release 1.
- Every form field typed as secret (password, private key, secret value, API key, token) is excluded from screen context unconditionally; a screen that carries such fields sends route and entity identity only, never form values.
- On a screen that carries secret fields, the panel warns before sending a message that looks like a password or key.
- The toggle defaults to on; its state is remembered per user, and an OcuPilot administrator can set the instance default to off (FR-19).

#### FR-12: Turn execution with progress and a conversation lock

A user can send a message and watch the agent work until it answers. Catalog: CP-02, CP-17, CP-18.

**Consequences (testable):**

- Each tool call the agent makes during a turn appears as a card with its name, arguments summary and result status, in order, while the turn is still running.
- While a turn is in progress on the same conversation, a second message is refused with a visible lock banner until the turn completes.
- The transcript of the tab's conversation is loaded when the panel opens and survives a page reload; a new tab starts a new conversation.
- A turn that exceeds the provider timeout ends with an error card, not a silent stop.

#### FR-13: Reply rendering

Agent replies render as sanitized Markdown with code highlighting, with no external network dependency. Catalog: CP-20.

**Consequences (testable):**

- Script and unsafe HTML in a reply are stripped before rendering.
- The rendering pipeline is vendored inside the bundle; the page loads with no CDN reachable.
- The renderer loads no remote resource of any kind: images render only from same-origin or inline sources, external links are rendered inert with the full host visible and open only on an explicit click, and the shell's Content-Security-Policy forbids any connection except the instance origin. A test asserts that a reply containing a remote image produces no network request.

#### FR-14: Screen synchronization after agent writes

After a confirmed write, the screen showing the affected entity re-fetches in place and highlights what changed. Realizes UJ-3, UJ-6. Catalog: CP-42.

**Consequences (testable):**

- Every confirmed write emits a change event carrying entity type, id and action.
- The active screen, when it shows that entity type, re-fetches and highlights the changed row or field within two seconds of the write completing.
- When the affected screen is not open, a toast names the change and links to the screen with the entity selected.
- Highlights clear on the next user interaction with that row or field.

#### FR-15: Agent-driven navigation

The agent can open a screen, apply a filter or select an entity in the browser. Realizes UJ-6. Catalog: CP-43.

**Consequences (testable):**

- Navigation tools run client-side and are listed in the agent's tool set as read tools.
- The agent announces where it is taking the user before doing so; the user can undo the navigation with the browser back button.
- Navigation tools accept only allow-listed route identifiers and entity ids, never a URL.

### 5.3 Agent tools, write model and governance

**Description:** The agent has one read tool for every list and detail endpoint in the six areas and one write tool for every action. Read tools only read. Write tools never write directly: they produce a proposal, the user confirms, and only then does the write run, as the user, through the same endpoint the screen uses. The agent holds no privilege the user does not. Read-only mode blocks every write tool, either for the whole instance or for one user's session. The kill switch disables the agent entirely. Every LLM call and tool call is recorded in the agent audit ledger, and every write carries the agent marker into the IRIS audit database. Realizes UJ-3, UJ-4, UJ-6.

**Functional Requirements:**

#### FR-16: One read tool per screen

The agent can read every list and detail that the six areas' screens can read. Realizes UJ-1. Catalog: CP-11, CP-12 and every read row in 5.5 through 5.10, plus the shell's privilege map, namespace list and instance identity (SH-02, SH-03, SH-04).

**Consequences (testable):**

- Tools are discovered by a registry over a common tool base, each declaring its name, input schema and result shape. Read tools, write-tool input schemas and change-event entity types derive from the same endpoint descriptor a screen is built from, so adding a screen adds its tools and its change events without hand-written tool code; the sizing of CP-12 and CP-13 in section 10.1 rests on this.
- For every list or detail screen in the six areas, and for the three shell reads, there is exactly one read tool over the same endpoint, returning the same fields the screen shows.
- Read tools accept the same filters the screen offers and return row identifiers the panel can turn into citations.
- No read tool executes free-form SQL in Release 1; SQL-backed reads use fixed catalog queries only.

#### FR-17: Write tools with propose, review, confirm

The agent can change the instance only through a proposal the user has confirmed. Realizes UJ-3, UJ-6. Catalog: CP-13 and every write action in 5.5 through 5.10, including the deletes on rows the catalog tags as read (SS-04, SS-07, LG-04).

**Consequences (testable):**

- A write tool call creates a proposal on the instance from the tool's structured arguments. The proposal holds a server-issued unguessable id, the user, the conversation, the tool name, the full argument set, and a fingerprint of the target entity as freshly read at proposal time. The client never authors a proposal.
- The proposal card shows the target entity, a before/after diff computed on the instance from the stored arguments and that fresh read, every field the payload will send, the agent's rationale and expected impact labeled as the agent's text, and, where a reversal exists, how to reverse the change.
- The write runs only when the user presses Confirm on that card. The client sends only the proposal id; the executor uses the stored arguments, never client-supplied ones. Confirmation is a separate authenticated request from the user's browser; no tool and no request issued from within a turn can confirm a proposal.
- A confirmation is single-use, expires after a fixed interval, and is refused if the user, the conversation, the agent definition or the user's read-only state has changed since the proposal. Before writing, the executor re-reads the target and refuses with a "target changed, re-propose" result when the fingerprint no longer matches.
- A proposal is canceled, and the agent told, when the user presses Cancel, when a new turn starts in the conversation, or when a sibling proposal touching the same entity is confirmed. A card restored from a reloaded transcript is shown expired, never live.
- Write tools whose payload includes a secret (password, private key, wallet secret value, API key) declare that field as secret in their schema and do not accept it from the model; the card renders a masked input the user fills at confirmation, and the value travels only in the confirmation request.
- Each write tool declares whether it is destructive; a destructive proposal requires the user to type the target's name in the card, matching the screens' own delete confirmations.
- A single turn may produce several proposals; each is confirmed or canceled individually.
- Build step 2; the fingerprint re-read and the typed-name confirmation, step 7 (section 10.1).
- The write uses the same backing operation and field vocabulary as the corresponding screen; the tool path and the screen path are two callers of one operation, whether that operation is reached in-process or over the admin API (Open Question 17).

#### FR-18: Execution strictly as the user

Every tool runs under the caller's IRIS privileges with no service account. Realizes UJ-3. Catalog: CP-14.

**Consequences (testable):**

- A tool the user lacks privilege for fails with the same 403 the screen would, and the agent reports the failure instead of retrying with other credentials.
- No credential other than the user's own token pair is used for any tool call.
- A turn that outlasts the access token's lifetime completes without an authentication failure. Tools run in-process under the user's IRIS session, so no token is needed mid-turn and the question does not arise; the vendor-matching 60/900 token lifetimes are kept unchanged (Open Question 17, closed).
- Any privilege escalation on the instance is confined to named storage and file-read methods of the OcuPilot API, checks an explicit IRIS resource first, and is not in effect while tool code, admin API calls or provider calls run. The log endpoints (FR-60, FR-62, FR-63) require the same resource the classic portal's log pages require.
- Any token the instance holds on the user's behalf during a turn lives in process memory only, is never written to the ledger or a transcript, and is discarded when the turn ends.
- The tool set advertised to the agent is the full set; privilege is checked at call time, not by hiding tools.
- The Release 1 prohibited set is refused on the instance and never advertised as a tool: deleting or disabling the current user, the last user holding `%All`, or the `_SYSTEM` account; disabling the web service that serves OcuPilot; terminating IRIS system processes; deleting OcuPilot's own web applications, resource or role.

#### FR-19: Read-only mode

An OcuPilot administrator can put the whole instance in read-only mode, and any user can put their own session in read-only mode. Realizes UJ-4. Catalog: CP-21.

**Consequences (testable):**

- In either read-only state, every write tool returns a structured "blocked by read-only mode" result, the agent tells the user what it would have changed and on which screen, and no proposal card appears.
- The per-user toggle is in the panel, defaults to off, and cannot override an enforced instance-wide read-only state (build step 7, section 10.1; the enforced state is in the floor).
- A definition's read-only flag (FR-24) has the same effect as read-only mode while that definition is in use.
- Enforced read-only, the per-user toggle, a definition's read-only flag and the user's privileges are evaluated on the instance before every provider call, before every tool call and at confirmation; an in-flight turn stops at its next step when the state changes.
- The per-user toggle is stored on the instance, not in the browser.
- The enforced-state settings also hold the instance default for context sharing (FR-11) and the per-user turn limits: a per-user concurrent-turn limit and a per-user turns-per-hour limit, enforced on the instance (build step 7, section 10.1).
- The enforced state is stored on the instance and visible in the panel of every user.

#### FR-20: Kill switch

An OcuPilot administrator can disable the agent globally or for one user. Realizes UJ-4. Catalog: CP-22.

**Consequences (testable):**

- A disabled agent renders the panel in a disabled state with the reason; turns are refused server-side, not only hidden client-side.
- All screens continue to work with the agent disabled.
- The kill switch is evaluated on the instance before every provider call, tool call and confirmation; an in-flight turn stops at its next step when it is engaged, and a pending proposal can no longer be confirmed.
- The kill switch is off by default. Until the first agent definition is enabled through the first-login gate (FR-28), the agent is in the unconfigured state, which is distinct from the kill switch and is not a switch an administrator has to clear.
- Read-only mode and the kill switch are always reachable by an OcuPilot administrator through a screen that does not depend on the agent.

#### FR-21: Agent audit ledger

Every LLM call and every tool call is recorded on the instance with its arguments and result. Realizes UJ-3. Catalog: CP-15.

**Consequences (testable):**

- Each ledger row carries the user, the timestamp, the screen context route, the tool or provider name, the arguments, the result status and token usage where the provider reports it.
- Secrets, credentials and tokens are redacted from ledger rows. Redaction is schema-driven: every tool schema marks its secret fields and the ledger writer drops them by schema, not by pattern; LLM-call arguments are stored after the same secret exclusion FR-11 applies to screen context.
- Each ledger row for a tool call records the IRIS resource the tool required; FR-72's transcript access rule depends on it.
- OcuPilot's audit event types are registered in `%SYS` at install so that emitted events are not silently dropped.

#### FR-22: Agent marker on every write

Every write made through a confirmed proposal is distinguishable in the IRIS audit database from the same write made through a screen. Realizes UJ-3. Catalog: CP-16.

**Consequences (testable):**

- Every agent write emits an OcuPilot audit event into the audit database carrying the agent marker and naming the user, target and action, alongside the IRIS system event for the same change; a write made by hand emits no such event.
- The audit database viewer (FR-61) can filter on the agent marker.
- The ledger row for a confirmed write is created before the admin API call and finalized after it; the audit emission's return value is checked, and a failure is recorded on the ledger row and shown on the tool-call card.
- When auditing is off, or OcuPilot's own audit events are disabled, the panel shows an "agent writes are not being marked" banner to every user and the executor records the condition on each write.

#### FR-23: Provider retry and timeouts

A slow or rate-limited provider degrades a turn gracefully rather than failing it. Catalog: CP-19, PK-08.

**Consequences (testable):**

- Provider calls retry with exponential backoff on 429 and 5xx, honoring Retry-After, up to a bounded count.
- A provider call has a fixed timeout; the turn reports which step timed out.
- **There is no Web Gateway timeout prerequisite.** The architecture runs a turn in a background job that returns immediately, so no request is ever held open for the length of a turn and no operator has to raise a gateway setting before OcuPilot works. The installer still reports the current value, as information rather than a requirement, and does not change it. A turn longer than the stock 60-second gateway timeout must complete normally, and that is the test.

### 5.4 Agent configuration and the first-login gate

**Description:** Agent definitions live on the instance and are shared. An OcuPilot administrator creates them: provider, model, endpoint, credential reference, limits and system prompt. API keys are referenced, never stored in the definition and never shown back. A Test connection action proves the definition works before it is enabled. When no definition is enabled, OcuPilot administrators are sent to configuration on login and other users see the panel's configuration-empty state. Realizes UJ-2, UJ-4.

**Functional Requirements:**

#### FR-24: Agent definition management

An OcuPilot administrator can create, edit, enable, disable and delete agent definitions. Realizes UJ-2. Catalog: CP-03.

**Consequences (testable):**

- A definition holds a name, provider, model, endpoint URL where the provider needs one, credential type and reference, maximum tokens, temperature, maximum iterations per turn, an optional system prompt override, a read-only flag, a transcript retention period and an enabled flag.
- The eleven server-side validation rules harvested from iris-session-agent apply, and changing provider cascades the provider's canonical defaults into the form.
- Definitions are visible to every user for selection and editable only by OcuPilot administrators.
- Changing a definition's provider, endpoint or credential disables it until Test connection passes again, and every definition change is audited with the old and new endpoint (FR-29).
- One definition is marked default and the panel uses it in Release 1; a picker among enabled definitions is Stage 3 (CP-36).

#### FR-25: Four provider families including local models

The agent can run on OpenAI, Anthropic, Google Gemini, or any OpenAI-compatible endpoint, including a local model over plain HTTP. Realizes UJ-2, UJ-4. Catalog: CP-04, CP-05.

**Consequences (testable):**

- Anthropic first; OpenAI, Google Gemini and OpenAI-compatible, which covers local models, follow (build step 7, section 10.1).
- Each provider family has a working adapter with the same tool-calling contract; the agent's behavior does not depend on which is chosen.
- Provider families are adapters behind one contract; adding a family means adding an adapter and a form entry, with no change to the agent loop, the tools or the screens.
- An OpenAI-compatible endpoint works with no API key when the endpoint requires none.
- Plain HTTP is accepted only when no credential is configured, or with an explicit acknowledgment stored on the definition.
- The write path needs a model that makes reliable multi-field tool calls; the README's primary path names a capable cloud or local model and presents small local models as the privacy option with that caveat. The UJ-3 and UJ-6 demo prompts pass against every shipped provider before the demo freeze (section 10.1).
- Default models per provider are configuration, not fixed in this document, and are shown as suggestions in the form.

#### FR-26: Credential resolution without storage

API keys are resolved at call time from an environment variable or an IRIS credential and are never persisted in the definition or shown in the UI. Catalog: CP-07.

**Consequences (testable):**

- The definition stores only the credential type and the variable or credential name.
- A key entered through the form is written to the chosen credential store once and is never returned by any OcuPilot API call.
- Key shape checks per provider catch obvious paste errors before a call is made.
- The environment-variable rung works in any namespace; the IRIS credentials rung requires an interoperability-enabled namespace and is offered only where the install namespace is interoperability-enabled.

#### FR-27: Test connection

An OcuPilot administrator can test a definition before enabling it. Realizes UJ-2. Catalog: CP-06.

**Consequences (testable):**

- Test connection makes one minimal provider call with a small token budget and reports success with the model's reply, or the provider's error text.
- The test uses the definition as edited, before save.
- The displayed response is truncated to a bounded length, and endpoints in the link-local metadata range are refused; private-network and loopback hosts are allowed because local models are a supported case.

#### FR-28: First-login gate

When no agent definition is enabled, OcuPilot administrators are taken to agent configuration on login, and other users see the configuration-empty state in the panel. Realizes UJ-2. Catalog: CP-08.

**Consequences (testable):**

- On login with no enabled definition, an OcuPilot administrator is taken to agent configuration and may leave it; a persistent banner in the panel reminds them on every screen until one definition is enabled.
- The gate fires on every login until one definition is enabled, and never afterwards.
- Non-administrators can use every screen while the gate is active; only the panel is in its empty state, naming who can configure it.

#### FR-29: OcuPilot administrator privilege

Managing agent definitions, the kill switch and enforced read-only mode requires the OcuPilot administrative resource created at install. Catalog: PK-13.

**Consequences (testable):**

- The installer creates the resource and a role granting it, and documents which users to grant it to.
- Every configuration endpoint checks the resource server-side.
- Every change to the kill switch, enforced read-only mode, the context-sharing default, the turn limits, an agent definition, or (polish week) the governance policy emits an OcuPilot audit event naming the actor, the target and the old and new values.
- OcuPilot's persistent state (agent definitions, switches, the agent audit ledger, transcripts, proposals) is readable and writable only through the OcuPilot API. A user holding read and write on the install namespace's default database but not the OcuPilot administrative resource cannot read or write any of it through SQL or direct global access, and a test proves it.

### 5.5 Web applications and REST API explorer

**Description:** The first area. A list of every web application on the instance with a full editor, create, enable, disable and delete, plus a REST API explorer that lists REST-enabled applications and spec-based services per namespace and renders any service's OpenAPI document. Realizes UJ-3.

**Functional Requirements:**

#### FR-30: Web applications list, detail and edit

A user can list web applications and open a full editor for any of them. Realizes UJ-3. Catalog: WA-01, WA-05.

**Consequences (testable):**

- The list shows name, namespace, type, enabled, dispatch class and resource, with filter.
- The editor covers type, enabled, namespace, default application, dispatch class, resource, group by id, authentication methods, session timeout, JWT settings, CORS, CSP file settings, serve files, Python protocol, and application and matching roles.
- Save writes through the admin API and the list reflects the change without a manual refresh.

#### FR-31: Create web application

A user can create a CSP, REST, WSGI or ASGI web application. Catalog: WA-04.

**Consequences (testable):**

- Create captures type, namespace, dispatch class, resource and authentication methods, validates server-side and opens the new application's editor on success.

#### FR-32: Enable, disable and delete web application

A user can enable, disable or delete a web application from the list or its editor. Realizes UJ-3. Catalog: WA-02, WA-03.

**Consequences (testable):**

- Delete asks for confirmation naming the application; enable and disable act immediately and the row updates.
- Deleting OcuPilot's own web applications is refused with an explanation.

#### FR-33: REST API explorer list

A user can list REST-enabled web applications and spec-based REST services for a namespace. Catalog: WA-06.

**Consequences (testable):**

- The list combines the management API's discovery with the web application list and links each entry to its document view.

#### FR-34: OpenAPI document viewer

A user can view a REST service's OpenAPI 2.0 document as a path-and-verb browser. Catalog: WA-07.

**Consequences (testable):**

- Manually coded services show their generated document; spec-based services show their stored document.
- Services whose document the management API refuses to return show that refusal rather than an empty view.

### 5.6 Permissions

**Description:** The second area: users, roles, resources and services. Lists with filters, full detail editors for users, roles and services, create dialogs, and the small actions that make up most daily administration: enable, disable, delete, password change, role membership. Realizes UJ-1.

**Functional Requirements:**

#### FR-35: Users list, detail and edit

A user can list users with filter and open a full user editor. Realizes UJ-1. Catalog: PM-01, PM-07.

**Consequences (testable):**

- The list shows name, full name, enabled, type and roles.
- The editor covers account settings, comment, expiry, enabled, change-password-on-login, startup namespace and routine, email, mobile, two-factor settings and a roles tab.

#### FR-36: Create user

A user can create a user with name, password, full name, roles, expiry and startup namespace and routine. Catalog: PM-06.

**Consequences (testable):**

- The password is sent once and never returned; the new user opens in the editor.

#### FR-37: User actions

A user can enable, disable and delete a user, set a user's password with a change-on-login flag, and add or remove roles on a user. Catalog: PM-02, PM-03, PM-04, PM-05.

**Consequences (testable):**

- Each action is available from the list row and the editor and updates the row in place.
- Disabling or deleting the current user is refused with an explanation.

#### FR-38: Roles list, detail and edit

A user can list roles and open a role editor. Catalog: PM-08, PM-12.

**Consequences (testable):**

- The editor covers description, escalation-only, the resource grants, members and granted-to.

#### FR-39: Role create, resource grants and delete

A user can create a role, add, edit and remove its resource grants, and delete a role. Catalog: PM-09, PM-10, PM-11.

**Consequences (testable):**

- A resource grant is resource plus permissions; editing shows the current grant and the result.
- Deleting a role that is granted to users warns with the count first.

#### FR-40: Resources list and management

A user can list resources with search, and create, edit and delete resources with name, description and public permission. Catalog: PM-13, PM-14.

**Consequences (testable):**

- System resources are shown but not deletable.

#### FR-41: Services list and edit

A user can list services and edit a service's enabled state, allowed IP addresses, roles and authentication methods. Catalog: PM-15, PM-16.

**Consequences (testable):**

- Disabling the web service that OcuPilot itself depends on warns before proceeding, since it locks the user out of OcuPilot.

### 5.7 Security and secrets

**Description:** The third area, which the contest names most specifically: SSL/TLS, X.509 credentials, OAuth 2.0, LDAP and Kerberos, wallet, and auditing configuration. Release 1 ships lists and read views for everything; full editors for SSL/TLS and LDAP; import, edit and deletion of X.509 credentials; the wallet's collections and secrets; and the auditing controls. The OAuth 2.0 editors follow in the polish week. Realizes UJ-5.

**Functional Requirements:**

#### FR-42: SSL/TLS configurations

A user can list SSL/TLS configurations and create, edit and delete them. Catalog: SS-01, SS-15.

**Consequences (testable):**

- The editor covers certificates, key, CA, CRL, protocol minimum and maximum, ciphers, DH bits, OCSP and peer verification.
- Private key material entered in the form is never returned by any read.

#### FR-43: X.509 credentials

A user can list X.509 credentials and import, edit and delete them. Catalog: SS-02, SS-11.

**Consequences (testable):**

- Import accepts a certificate and optional private key; the list shows subject, issuer and validity.
- The backing class comes from the exported admin API endpoint source (Open Question 4).

#### FR-44: OAuth 2.0 lists and views

A user can list OAuth 2.0 client server descriptions, client configurations, resource servers and server client descriptions, view the authorization server configuration, and delete client configurations and server client descriptions. Catalog: SS-03, SS-04, SS-05, SS-06, SS-07.

**Consequences (testable):**

- The five tabs are **detail views rather than lists** - they administer a configuration entry by entry - and each links to the classic portal editor for the entry under its declared `classicLinkExemption` (FR-9) until the polish-week editors (FR-75) ship. This is the one classic-link exemption in the six areas, and it is counted against SM-C1.
- Delete asks for confirmation naming the entry.

#### FR-45: LDAP and Kerberos configurations

A user can list LDAP and Kerberos configurations and create, edit and delete them. Catalog: SS-08, SS-16.

**Consequences (testable):**

- The editor covers the fields of the classic LDAP page, `%CSP.UI.Portal.LDAP`, whose exported source in the reference folders is the field list for the epic; test authentication is a polish-week item (FR-75).

#### FR-46: Wallet collections and secrets

A user can list wallet collections, and list, create, edit and delete secrets in a collection. Realizes the contest's named wallet area. Catalog: SS-10.

**Consequences (testable):**

- Secret values are write-only: entered on create or edit and never displayed by any read.
- Access requires the wallet administrative resource, named once Open Question 6 identifies it; users without it see the screen disabled (FR-4).
- The write payload shapes come from the exported endpoint schema (Open Question 6).

#### FR-47: Auditing configuration

A user can enable and disable auditing, configure system audit events, and create, configure and delete user audit events. Catalog: SS-09, SS-12, SS-13.

**Consequences (testable):**

- System events can be enabled and disabled and their counters reset, including through the selective SQL auditing wizard; user events can also be created and deleted.
- Disabling auditing warns that agent writes will no longer be marked in the audit database (FR-22), and the agent never proposes disabling auditing or OcuPilot's own audit events without that warning in the proposal card.

### 5.8 Tasks

**Description:** The fourth area: the Task Manager's schedule, on-demand tasks, upcoming tasks, history, task details, the run, suspend, resume and delete actions, control of the Task Manager itself, and the New Task wizard and Edit task form. The wizard and editor are the two largest forms in Release 1 and are the last items in the build order before the stretch step. Realizes UJ-6.

**Functional Requirements:**

#### FR-48: Task schedule, on-demand and upcoming lists

A user can list scheduled tasks with the Task Manager's status, list on-demand tasks with a Run action, and list upcoming tasks for a chosen number of hours ahead or until a date. Realizes UJ-6. Catalog: TM-01, TM-02, TM-03.

**Consequences (testable):**

- The schedule list filters on the fields the admin API returns, at least name and namespace, and shows last and next run.
- Upcoming accepts a horizon and shows tasks in order of next run.

#### FR-49: Task history

A user can view the history of all tasks or of one task, with a filter. Realizes UJ-6. Catalog: TM-04, TM-05.

**Consequences (testable):**

- Each history row shows start, end, status and error text where present, and the running user where the admin API returns it.

#### FR-50: Task details

A user can open a task's details showing properties, schedule, last and next run, with auto-refresh. Realizes UJ-6. Catalog: TM-11.

**Consequences (testable):**

- Details link to the task's history and to Edit task.

#### FR-51: Task actions and Task Manager control

A user can run a task now, suspend it, resume it and delete it, and can start, suspend and resume the Task Manager. Realizes UJ-6. Catalog: TM-06, TM-07, TM-08, TM-09, TM-10.

**Consequences (testable):**

- Each action updates the task row in place; delete asks for confirmation naming the task.
- Suspending the Task Manager warns that no scheduled task will run until it is resumed.

#### FR-52: New task wizard

A user can create a task with the fields the classic wizard offers. Catalog: TM-12.

**Consequences (testable):**

- The wizard captures name, description, namespace, task type from the instance's task definitions, priority, run-as user, output file, suspend-on-error, reschedule-after-restart, a schedule of daily, weekly, monthly, after another task or on demand, expiry and email settings.
- The field list and its legal values come from `%SYS.Task`, whose 66 documented properties are the model the classic wizard edits: `TimePeriod` 0 to 5 for daily, weekly, monthly, monthly-special, run-after and on-demand, with `TimePeriodEvery` and `TimePeriodDay` read per period; `DailyFrequency` 0 for once and 1 for several, with `DailyIncrement`, `DailyStartTime` and `DailyEndTime`; `Expires` with its days, hours and minutes offsets; `EmailOnCompletion`, `EmailOnError`, `EmailOnExpiration` and `EmailOutput`; and `RunAsUser`, which requires `%Admin_Secure:Use` to set to another user. The classic page source is not available (Open Question 7).

#### FR-53: Edit task

A user can edit an existing task's fields. Catalog: TM-13.

**Consequences (testable):**

- Edit shows the same fields as the wizard with current values. Both forms are built from `%SYS.Task` (FR-52), so the field list is the same by construction rather than by assumption, and the classic edit page rendering empty on the research instance no longer matters.

### 5.9 OS management

**Description:** The fifth area: processes with details and control, system usage and dashboard meters for CPU, memory and performance, locks with removal, databases as the contest's "disks", and devices. Realizes UJ-5.

**Functional Requirements:**

#### FR-54: Processes list and details

A user can list processes with filter, page size, maximum rows, persisted sort and auto-refresh, and open a process's details. Catalog: OS-01, OS-08.

**Consequences (testable):**

- Details show the dashboard meters, client executable and address, open devices and, where available, the current SQL statement.

#### FR-55: Process control

A user can terminate, suspend and resume a process. Catalog: OS-02, OS-03, OS-04.

**Consequences (testable):**

- Terminate offers the optional error-to-job flag and asks for confirmation naming the process id.
- Acting on the user's own process is refused with an explanation.

#### FR-56: System usage and dashboard meters

A user can view system usage counters and shared memory, and the CPU, memory and performance meters of the system dashboard, with a refresh interval. Catalog: OS-05, OS-09.

**Consequences (testable):**

- Counters cover global references, routine calls, block reads and writes and journal entries.
- Meter names and values come from the admin API's `Monitor` system-usage and dashboard answers: performance (global references per second, cache efficiency), shared memory as a percentage of allocated, and the database space, journal space, lock table and write daemon status in the vendor's own words. CPU is FR-76's. The classic `UtilSysMonitor` page source is not available and is not needed (Open Question 7). [AMENDED 2026-09-17, Story 6.9: `%CSP.UI.Portal.EnsembleMonitor` is the Interoperability production monitor and defines neither these meters nor thresholds]

#### FR-57: Locks view and removal

A user can view every lock the instance holds, with filter, owner details and each lock's database directory, and remove one lock, all locks of a process, or all locks from a remote client. Catalog: OS-06, OS-07. [AMENDED 2026-09-17, Story 6.10 spec gate (orchestrator-approved): the lock table is instance-wide and a lock's scope marker is a database directory, not a namespace - the same read answers identical rows from two namespaces and the vendor's own page is pinned to `%SYS`; was "view locks by namespace"]

**Consequences (testable):**

- The owner links to the process details.
- Removal warns when the owning process is in a transaction.

#### FR-58: Databases list and details

A user can list local databases in general and free-space views, and open a database's details. Catalog: OS-10, OS-11.

**Consequences (testable):**

- The list shows size, maximum, free space, status, directory and mounted state; free-space figures come from the asynchronous directory call and the screen shows them as they arrive.
- Details show properties, volume files and background tasks running against the database, with auto-refresh.

#### FR-59: Devices

A user can list devices and create, edit and delete a device. Catalog: OS-12.

**Consequences (testable):**

- The editor covers the fields of the classic device page, `%CSP.UI.Portal.Config.Device`, whose exported source in the reference folders is the field list for the epic.

### 5.10 Logs

**Description:** The sixth area, "all the logs": alerts.log, the audit database, messages.log and the application error log. Two of the four have no REST route on the instance and are served by OcuPilot API custom endpoints. Each viewer is a read tool for the agent, so a user can ask the agent what an entry means. Realizes UJ-4.

**Functional Requirements:**

#### FR-60: alerts.log viewer

A user can view alert entries, both those reported since the last monitoring scrape and the file's history. Catalog: LG-01.

**Consequences (testable):**

- Recent entries come from the monitoring API; history comes from a bounded tail of the file through the OcuPilot API.

#### FR-61: Audit database viewer

A user can search the audit database by time range, source, type and name, user, process id, namespace and authentication (the audit API offers no free-text search: its one text-shaped parameter searches captured JSON payloads and forces the event type to SQL), and open an event's detail. Realizes UJ-3. Catalog: LG-02, SS-14.

**Consequences (testable):**

- The viewer can filter to events carrying the agent marker (FR-22).
- Detail shows the full event including its description and any JSON payload.

#### FR-62: messages.log viewer

A user can view messages.log with search, highlight, go to top and bottom, and tail. Realizes UJ-4. Catalog: LG-03.

**Consequences (testable):**

- The OcuPilot API serves the file in bounded pages; the viewer never loads the whole file into the browser at once.
- The file path is fixed to the instance's manager directory and no other path can be requested.
- There is no backing class to read through: messages.log is a plain file, and the classic viewer ships compiled-only. File access behind the custom endpoint is the only route, as this requirement already assumed (Open Question 4, closed 2026-09-08).

#### FR-63: Application error log

A user can drill from namespaces to dates to errors, and delete errors by namespace or individually. Catalog: LG-04.

**Consequences (testable):**

- Each error shows its text and time and, where the instance records them, routine and line; delete asks for confirmation naming the scope.
- Delete is a write tool with a proposal, so the Logs area has a confirmable agent write (SM-3).
- The backing store is the `^ERRORS` global, held per namespace and written by the `^%ETN` error-trap routine; `Config.Startup.ErrorPurge` is the retention setting and the `%SYS.Task.PurgeErrorsAndLogs` task performs the purge, so a suspended task means retention stops.
- Access is through **`SYS.ApplicationError`** in `%SYS`, a supported API whose queries supply the namespace, date and error levels of the drill directly, and which offers three delete scopes: by namespace, by date and by individual error. This requirement names two; the by-date scope is either offered or explicitly refused. Every call takes the namespace as a parameter (Open Question 4, closed 2026-09-08).
- The captured detail of an error holds every local variable at every stack level of the faulting application, plus its roles and user name. It renders on screen for the user but is never sent to the agent: the read tool returns the summary fields only.

### 5.11 Packaging, install and submission

**Description:** OcuPilot ships as one IPM module, and the Docker Compose workspace in the repository installs it on start. The installer is idempotent, avoids every name the sibling projects use, and installs into `HSCUSTOM` if present and otherwise into `USER`. The contest deliverables are requirements, not afterthoughts. Realizes UJ-2, UJ-5.

**Functional Requirements:**

#### FR-64: One IPM module

An operator can install OcuPilot with one IPM command. Realizes UJ-2. Catalog: PK-10, PK-15.

**Consequences (testable):**

- The module declares the two web applications, the file copy of the built Angular bundle, the package resource, the installer invoke and the system requirements.
- The built bundle is inside the module archive, so install needs no Node toolchain.
- Install targets `HSCUSTOM` when present and otherwise `USER`; the installer makes the choice, not the manifest, and the README says how to override it.

#### FR-65: Two web applications created at install

Install creates the static shell application and the OcuPilot API application with the settings the silent-first design needs. Catalog: PK-11, PK-12.

**Consequences (testable):**

- The shell application serves the bundle unauthenticated with a non-root base href and a deep-link fallback so that any client route reloads correctly.
- The OcuPilot API application is password-authenticated with JWT enabled, no server session, and membership in the vendor's portal group, and accepts the same Bearer token as the admin API.
- The OcuPilot API carries no application roles and no matching roles, and the installer asserts this; it carries a resource gate, and the turn endpoint refuses users holding no `%Admin_*` resource with the FR-3 message.

#### FR-66: Idempotent installer and name isolation

Install can be run repeatedly with the same result, and nothing OcuPilot creates collides with the sibling projects. Catalog: PK-07, PK-13.

**Consequences (testable):**

- Running install twice changes nothing the second time.
- The installer creates the web applications, the OcuPilot administrative resource and role, and the audit event types, each guarded by an existence check; seeds no agent definition, so the first-login gate is active on first login; and restores the namespace on any error.
- Install and the automated tests run with the iris-execute-mcp-v2 suite present on the same instance, as it is in this repository's sandbox, and neither install disturbs the other.
- The installer places OcuPilot's persistent state where FR-29's protection holds; the mechanism, with a dedicated database and resource as the candidate, is an architecture decision (addendum, section 6).
- The installer enables auditing and OcuPilot's audit event types, documented in the README as a security-posture change, so the agent marker works on a fresh container.
- A `demo` install option creates the fixtures the README walkthrough names: a disabled web application, a task suspended after an error, and application errors to delete.
- A smoke script runs the UJ-3 path against a fresh container and gates every publish of the listing and every step of the build order.
- A unit-test harness runs in CI against a stock image in Release 1, with at least one test per OcuPilot API endpoint, the confirmation-binding tests (FR-17), the state-protection test (FR-29) and the audit-marker round trip (FR-22); coverage growth is polish week (FR-79).
- No package, web path, role, resource, global, task, credential or audit source name used by iris-session-agent, iris-execute-mcp-v2 or iris-couch is used by OcuPilot.

#### FR-67: Docker self-install

The repository's Docker Compose workspace has OcuPilot installed and reachable after `docker compose up`, including on a durable data volume. Realizes UJ-2, UJ-5. Catalog: PK-14.

**Consequences (testable):**

- From a clean clone, one command brings up an instance with OcuPilot installed, the `_SYSTEM` password unexpired, and the namespace chosen as `HSCUSTOM` if present, otherwise `USER`.
- A second `docker compose up` after `down` reaches the same state without reinstalling by hand, and OcuPilot is reachable at the workspace's published web port, 52774 in this repository.
- Starting a container whose image carries a newer OcuPilot against an existing durable volume upgrades the installed OcuPilot to the image's version without manual steps.
- The Docker path does not need to touch the Web Gateway response timeout: the background-job turn never holds a request open, so the stock container's 60 seconds is sufficient and a clean clone works unmodified (FR-23).
- The compose file pins the exact image tag the release was tested on, re-pinned at each publish, so a judge pulling during the voting week gets the build that was tested.
- Whether install runs at image build or at container start is an architecture decision (Open Question 5); the observable result above is the requirement.

#### FR-68: Community Edition compatibility

OcuPilot runs on IRIS Community Edition and IRIS for Health Community Edition without HealthShare-only dependencies. Realizes UJ-5. Catalog: PK-06.

**Consequences (testable):**

- The automated tests run against both stock images and confirm the admin API is present on each.
- On plain IRIS Community, where no `HSCUSTOM` exists and install falls to `USER`, install and the credential rungs are verified **after the 2026-09-27 application floor is built**, not before the listing (owner decision, 2026-09-08; Open Question 16). Until that check runs, the plain-Community half of this requirement is an untested claim, and the accepted risk is that a failure surfaces with little time to react. Both research containers were IRIS for Health Community.

#### FR-69: Submission deliverables

The contest's hard requirements are met in the repository, not only in the listing. Realizes UJ-5. Catalog: PK-01, PK-02, PK-03, PK-04, PK-05.

**Consequences (testable):**

- The README, in English, has installation steps that work first time on a clean machine, a description of the product with the UJ-2 and UJ-3 walkthroughs, a video if one is recorded (optional by owner decision), a link to the Ideas Portal idea once one exists, and team profile links where applicable. **The rules' actual bar is English, installation steps, and either a video demo or a written description**, so the description alone satisfies it; the video is optional and the Ideas Portal link is a bonus item rather than a gate, the Full Stack 2026 precedent having scored "DC Idea" at 2 points. Neither may hold up the release.
- The repository is public under the MIT license already in it, which the contest terms' nonexclusive promotional license clause permits. It is **private until the release** and made public as the first act of it (section 1.1), so "public" is a release-time state rather than one it holds throughout the build.
- The README carries a "get a key in two minutes" section for each shipped provider, and its walkthrough shows UJ-2 and UJ-3 with screenshots so a judge without a key still sees what an agent write looks like.
- The Open Exchange listing exists before the application is submitted, and the application is submitted by 2026-09-27 23:59 EST.

### 5.12 Polish week capabilities

**Description:** The P1 rows, 61 of them, ship between 2026-09-28 and 2026-10-04, while voting is open. They are grouped here at lower detail; each FR names its rows and the epics work carries the row-level fields (order within the week: section 10.2).

#### FR-70: Screen-aware help from the agent

A user can ask the agent to explain the current screen or a log entry, and sees suggested prompts grouped by task for the screen they are on. Catalog: CP-23, CP-24, CP-25.

**Consequences (testable):**

- "Explain this screen" is a one-click action in the panel on every screen; the reply names the screen's purpose, the data shown and the actions available, and cites the read tool it used.
- Every log viewer and the audit database viewer give each entry an explain entry point that sends that entry, and only that entry, as context.
- Each screen offers at least three suggested prompts grouped by task; choosing one sends it as a turn.

#### FR-71: Agent transparency

A user can see citations to the rows and tools the agent used with click-through, which provider is in use and whether screen data leaves the instance, and an agent audit viewer over the ledger with filters by user and screen. Catalog: CP-26, CP-27, CP-31. Token metering (CP-28) moves to Stage 2 by owner decision.

**Consequences (testable):**

- Every reply that used a read tool carries citation chips; clicking a chip selects the cited row or opens the cited screen.
- On every turn with context sharing on, the panel shows a data-egress line naming the provider in use and stating whether screen data leaves the instance.
- The agent audit viewer lists ledger rows with filters by user, screen and date and opens the arguments and result of any row; OcuPilot administrators see all users' rows, other users see their own.

#### FR-72: Agent restraint and governance

A user can ask for a copy-out draft (ObjectScript, CLI or REST snippet) instead of an execution; an OcuPilot administrator can set a tool governance policy by tool and action with read-only and full presets, and view it. Log and tool content is sanitized before it reaches the model. Transcripts persist with each turn's screen context and a retention purge task, and OcuPilot administrators can open any user's transcripts. Catalog: CP-29, CP-30, CP-32, CP-33.

**Consequences (testable):**

- On any proposal the user can choose the script instead; the agent returns an ObjectScript, CLI or REST snippet that would make the same change, and no write runs.
- An OcuPilot administrator can enable or disable each write tool by tool and action, choose the read-only or full preset, and view the effective policy; a disabled tool returns a structured governance-disabled result and stays advertised to the agent.
- The policy's frozen baseline enables every write tool-and-action key Release 1 ships, so SM-3 holds through 2026-10-04; keys added after Release 1 default to disabled, and the policy names each key it disables.
- Before tool results or log text reach the model they are truncated to a bounded size, stripped of control characters, wrapped in a delimiter that marks them as data, and have secret-shaped strings redacted; a test feeds an injected instruction through a log entry and asserts the agent did not act on it.
- Transcripts are stored per user with each turn's screen context, and a user sees only their own; a purge task removes transcripts older than the agent definition's retention period; an OcuPilot administrator opening another user's transcript is recorded in the agent audit ledger, and sees tool results and screen context only if they hold every resource the transcript's tool calls required, as recorded per ledger row (FR-21).

#### FR-73: Shell conveniences

A user can change their own password, keep favorites and recent items, search the menu, open About and per-screen Help, use the fixed shortcuts menu and the links panel, see the Home system information panel, keep UI state across sessions, and choose a light or dark theme. Catalog: SH-12 through SH-22.

Done when each listed item is reachable from the header or Home, per-user state survives a sign-out, and the theme choice persists.

#### FR-74: Web applications and permissions extras

A user can send a try-it request to a REST endpoint with the current session, list and end web sessions, view a user's effective privileges, and ask the agent whether a user or role holds a resource permission. Catalog: WA-08, WA-09, PM-17, PM-18.

Done when a try-it request round-trips with the current session, a web session can be ended from the list, a user's effective privileges render, and the permission-check tool answers yes or no with the granting role.

#### FR-75: Security and secrets editors and tests

A user can test an SSL/TLS connection, view X.509 certificate details, test LDAP authentication, revoke a user's OAuth 2.0 tokens, copy and purge the audit database, and use full editors for OAuth 2.0 resource servers, client server descriptions, client configurations, the authorization server and server client descriptions. Catalog: SS-17 through SS-27.

Done when each test action reports the instance's result text, and each editor round-trips create, edit and delete through the admin API.

#### FR-76: Tasks and OS extras

A user can export and import tasks, see and control background tasks (the admin API tracks only its own asynchronous tasks, so classic-portal background tasks need a custom endpoint), broadcast a message to processes, view license usage, and read the full System Dashboard meter groups. Catalog: TM-14, TM-15, TM-16, OS-13, OS-14, OS-15.

Done when a task exported from one instance imports on another, background tasks can be canceled, paused and resumed, a broadcast reaches a chosen process, and the dashboard renders every meter group.

#### FR-77: Secondary log viewers and the log hub

A user can view the System Monitor log, the background task error log, the xDBC error log, the SQL diagnostics log, the interoperability event log and the analytics log, and open a unified log hub listing every source with counts, last entry and explain entry points. Catalog: LG-05 through LG-10, IO-01, AN-01.

Done when each viewer renders its source with search, the hub lists every source with a count and last entry, and each explain entry point opens a turn with that entry as context.

#### FR-78: External language servers

A user can list external language servers with status, start and stop them, read their activity log, and create, edit and delete them. Catalog: SA-01, SA-02.

Done when each server can be started and stopped from the list, its activity log renders, and create, edit and delete round-trip through the admin API.

#### FR-79: Bonus deliverables and engineering hygiene

As optional bonus items, the project may publish a Developer Community article and a YouTube video and short; it watches for and re-plans against the technology bonuses post. As engineering hygiene it ships an uninstall hook, grows the Release 1 test suite and CI, and publishes the package to the community registry. Catalog: PK-16 through PK-24.

**No bonus item is published before the release** (section 1.1) — each is a public announcement of the concept, so the stealth decision governs them exactly as it governs the listing. They land after the final submission, into the voting week, on the contest's own rule that an application may be improved throughout the submission and voting periods. **This placement rests on an unconfirmed answer:** that a bonus item published during the voting week still earns its bonus. If bonuses turn out to be scoped to the 2026-09-27 deadline, every item here moves inside the release window, which already carries the collateral pass, the single clean-build rehearsal and the approval buffer — and the honest response is then to cut bonus items rather than crowd that window. Confirm at the kick-off (Open Question 1).

**No online demo instance ships, at any point.** Owner decision, 2026-09-08: a publicly reachable, write-capable IRIS administration portal is the wrong thing to expose, anonymous visitors would spend the owner's provider budget, and the work competes with real screens. The judge-without-a-key path stays FR-69's README walkthrough with screenshots and the per-provider key guidance, which is the mitigation already accepted in section 11. This closes Open Question 8 and removes PK-19 from the deliverable set.

**Freshmen eligibility, closed 2026-09-09 from the announcement post.** Two conditions, both required: no more than five previous InterSystems programming contests, **and** never having placed 1st, 2nd or 3rd in either the Experts or Community nomination. There is no opt-in and nothing to do to qualify, so nothing in this document depends on it; an Experts placing under SM-1 would moot it regardless. Not to be raised at the kick-off (Open Question 10).

Done when the uninstall hook removes everything the installer created, the test suite runs in CI against a stock image, the package is on the registry, and each optional bonus that was published is linked from the README.

### 5.13 Staged delivery to parity

**Description:** Sections 5.1 to 5.12 describe Release 1. Sections 10.3 and 10.4 describe what follows it: Stages 2 through 6, 357 catalog rows, delivered as versioned increments toward parity with the classic portal. Those stages were scoped but never carried a functional requirement, which left the epics that implement them with nothing to trace to. This requirement is that contract. It states no new behavior — every screen a later stage adds behaves like the screens Release 1 already specifies — and exists so that "build it the same way" is a requirement rather than a convention. Added 2026-09-09 from the epics workflow; it is the only requirement in this document that did not originate here.

**Functional Requirements:**

#### FR-80: Staged delivery to parity under one contract

OcuPilot grows toward classic-portal parity in versioned increments, and every screen added after Release 1 is built the same way as the screens before it. Catalog: the 357 P2 to P4 rows.

**Consequences (testable):**

- Each of Stages 2 through 6 ships as an IPM release with a Developer Community article, on a public roadmap (section 10.3).
- **No stage introduces a second way of building a screen.** Every screen added after Release 1 is declared by exactly one screen descriptor; reaches anything outside OcuPilot through exactly one port; derives its read tool and its write tools' field lists from that descriptor rather than by hand; and makes every write through a server-minted proposal, an instance-computed diff, an explicit user confirmation and an agent marker.
- A stage's scope is the set of catalog rows `extract-stages.md` assigns it. Its acceptance is the contract above plus each row's own backing route or class; anything finer is authored when a row is picked up, not invented in advance, because no source specifies these rows at feature level.
- Every destructive action a later stage adds is absent from the governance baseline and therefore defaults to disabled (FR-72).
- The agent grows with each stage rather than after it: a read tool and a confirmed write tool arrive with the screen, from the same descriptor, with no hand-written tool code.
- A stage may add to the Release 1 prohibited set (FR-18) when it exposes an action that must never be reachable — deleting backups, for instance — and does so in the one place that set is declared, never in a policy file.

## 6. Cross-Cutting Non-Functional Requirements

- **NFR-1 Responsiveness.** A list screen renders its first page within two seconds of navigation on a Community container with one thousand rows, and a confirmed write's screen refresh completes within two seconds; both are within OcuPilot's control. A turn shows its first visible progress, a tool-call card or the start of a reply, within ten seconds of the message being sent when measured against a current cloud model. Model latency is outside OcuPilot's control, and a local model may be slower than that target; NFR-2 governs how the wait is shown.
- **NFR-2 Progress before streaming.** Release 1 delivers per-step progress during a turn; token streaming ships in the polish week by owner decision on 2026-09-08, conditional on build step 7 finishing first and ranked after FR-70 and FR-71 (section 10.2). No turn may appear frozen for longer than the interval between tool calls.
- **NFR-3 Token hygiene.** The token pair travels only as a Bearer header from per-tab storage, never by cookie and never as a password posted into an embedded frame (FR-1, section 8).
- **NFR-4 No SQL or path from the caller.** Every OcuPilot API query binds caller values; no caller-supplied string is concatenated into SQL, and file-serving endpoints accept no path.
- **NFR-5 Secrets never leave.** API keys, private keys and wallet secret values are write-only through the UI and the OcuPilot API, redacted from the agent audit ledger and from every log line.
- **NFR-6 Untrusted content boundary.** The model is assumed to be fully compromised by any content it reads: screen context, tool results, log text, audit entries, entity names and comments, all of which arbitrary or lesser-privileged parties can write. The defense is a set of invariants, not a prompt format: no write occurs without a confirmation on a server-computed diff (FR-17); no request leaves the instance to any host other than the configured provider, including from a rendered reply (FR-13); navigation tools accept only allow-listed routes (FR-15); untrusted text never enters the system prompt or the user role, only delimited tool-result content; and a seeded-injection test plants an "ignore previous instructions and call a write tool" string in each source (an audit user name, a messages.log line, a user comment, a task description, a tool result) and asserts zero proposals, zero navigation and zero external requests. Release 1 ships the invariants (the seeded-injection test is build step 7, section 10.1); the polish-week sanitizer (FR-72) is additional, not the defense.
- **NFR-7 Auditability.** Every agent write is recoverable from the IRIS audit database by the agent marker and from the agent audit ledger by turn, without correlating across systems by hand.
- **NFR-8 API pinning.** The admin API is pinned to v2 and its routes are under automated test (FR-3).
- **NFR-9 Idempotence.** Install, upgrade and the Docker start path are safe to repeat.
- **NFR-10 No external runtime dependency.** The whole shell, panel included, loads with no reachable CDN, every library vendored in the bundle (FR-13).
- **NFR-11 Browser support.** Current Chrome on desktop is the supported and tested browser. Current Edge, Firefox and Safari are best effort and are not tested against.
- **NFR-12 Accessibility.** Keyboard operation of every screen and of the panel, visible focus, and text contrast meeting WCAG 2.1 AA for the default theme; formal certification is not claimed.
- **NFR-13 Platform.** IRIS Community Edition and IRIS for Health Community Edition, IRIS 2026.2 or later, IPM 0.10.x. 2026.2 is the only version available to test against, so earlier versions are not claimed.
- **NFR-14 Language.** English user interface only in Release 1.

## 7. Constraints and Guardrails

### 7.1 Safety

- The agent runs with tiered autonomy. Level 0 (observe) and Level 1 (recommend) are always available. Level 2 (bounded actions) and Level 3 (human-authorized changes) are the propose-review-confirm path, and in Release 1 every write is Level 3: one explicit confirmation per write, no batch approval. Level 4 (prohibited actions), such as deleting backups or dropping production databases, are kept outside the agent's tool set entirely, not merely gated. The detailed model is in the addendum.
- The agent never holds a privilege the user does not. There is no service account and no privilege escalation path through the agent.
- Read-only mode and the kill switch are always reachable without the agent (FR-20).
- Confirmation is bound to a specific proposal. Changing the proposal invalidates the confirmation.
- A Release 1 prohibited set is refused on the instance and never advertised as a tool (FR-18).

### 7.2 Privacy and data egress

- Screen context sharing is on by default and toggleable per user; when off, no screen data is sent with a turn (FR-11).
- A local model keeps every prompt on the instance's network; the context chip says whether data leaves the instance, and the polish week adds the egress line (FR-11, FR-71).
- Transcripts are stored on the instance per user and purged by a retention task; an OcuPilot administrator's view of another user's transcript is gated by the resources recorded per ledger row, and the agent audit viewer follows the same rule (FR-72).
- OcuPilot sends nothing to any endpoint other than the instance and the configured provider.

### 7.3 Cost

- Provider cost is the operator's. OcuPilot bounds it with maximum tokens and maximum iterations per turn in the agent definition. Usage analytics, per turn and per user per day, is Stage 2 or later.
- Test connection uses a minimal token budget.
- Per-user turn limits are set in the enforced-state settings and enforced on the instance (FR-19).

## 8. Integration and Dependencies

- **API preference order.** A documented official route first; the admin API second, which is an `%Api` class on the instance but undocumented, chosen by the brief's backend decision; a custom endpoint on the OcuPilot API last, only where neither exists.
- **The admin API** backs five of the six areas and the sign-in. It is experimental — named as the contest's intended API at the 2026-09-14 kick-off, specified in a published OpenAPI document, and subject to change until its final form in IRIS 2027.1 — and its list and get shapes were observed live on two containers. Its write payloads are **no longer unobserved**: the endpoint classes publish a body-template method from which write-tool field names and types are generated, and an endpoint-inventory fixture runs in CI so a vendor change fails the build. Two limits survive and belong to the epics rather than to every story: the templates carry field names and types only, never required-ness, enumerations or descriptions, so the semantic half of each tool is authored once; and sixteen mutating endpoints publish no template at all, five of them in Release 1. Those five are the only rows still built against an unverified contract. "Exercise the payload on the instance" is therefore a CI fixture, not the first task of every write story.
- **The monitoring API** backs alerts and the dashboard metrics and is unauthenticated on the instance.
- **The management API** backs the REST API explorer. It refuses to return the document for one vendor service; the explorer shows the refusal.
- **The Atelier API** is not used in Release 1. It rejects the token pair, and a cookie-only call from a page hangs on the browser's Basic prompt; Stage 3 routes Atelier-backed features through the OcuPilot API or an explicit Basic header. The reason is now confirmed rather than inferred: `/api/atelier` has JWT authentication disabled and sits outside the `%ISCMgtPortal` group. Enabling JWT on it would work mechanically, but that is a change to a vendor web application, which OcuPilot does not make on an operator's instance, so it is at most an operator-run prerequisite and never an install action (Open Question 11, closed 2026-09-08).
- **The vendor's Angular editors** are all interoperability editors; none of the six areas' classic pages is an embeddable bundle, so those screens are rebuilt and FR-9 links to the classic page as the fallback. The editors are not embedded in Release 1. When they are (Stage 4), they sign in silently from the same browser login; the password is never posted into the frame.
- **LLM providers** are reached only from the instance, with retry, timeout and a bounded iteration count.
- **Sibling projects** are harvest sources, never runtime dependencies: iris-session-agent for the agent core, iris-execute-mcp-v2 for the governance model and custom endpoint handler bodies, iris-table-editor for the Stage 3 grid, iris-couch for the REST, static-serving, installer and test-harness patterns (FR-66).
- **The Web Gateway** imposes no prerequisite. An earlier draft required a response timeout long enough for a turn; the architecture's background-job turn removed the reason, since no request is held for a turn's duration. The installer reports the current value as information only (FR-23).

## 9. Non-Goals (Explicit)

- OcuPilot is not a multi-instance console. It manages the instance that serves it, and only that one.
- The agent does not act without confirmation, does not batch-approve, and does not undo in Release 1 (undo: Stage 5, section 10.4).
- OcuPilot does not store API keys, private keys or secret values in any form it can display back.
- OcuPilot does not copy or redistribute the vendor's Angular bundles; when embedded, they are loaded in place from the instance.
- OcuPilot does not depend on any sibling project being installed, and does not reuse their packages, paths, roles, globals, tasks or credentials.
- OcuPilot does not ship embedded Python in any class; any Python is an operator prerequisite, not an install action.
- OcuPilot does not target mobile, does not localize, and does not certify accessibility, in Release 1 or in any planned stage.

## 10. Scope and Staged Delivery

### 10.1 Release 1, contest build: all P0 rows by 2026-09-27, built incrementally

The commitment, the listing build, the stealth release targeting 2026-09-24 and the 2026-09-27 application floor are stated in section 1.1; this section holds the build order they refer to.

**Build order, which is also the cut line.** Keep in this order; a step is complete when its build passes the smoke script (FR-66) on a clean container.

0. Shell and install path: sign-in, navigation, page chrome, error handling, the version guard, the IPM module, the Docker path, the installer and the OcuPilot API skeleton (5.1, 5.11).
1. Shell reads plus one live list per area with its read tool, and the messages.log and application error log endpoints (FR-5, FR-16, one list from each of 5.5 through 5.10).
2. The agent co-pilot core with one confirmed write per area and the demo fixtures: the panel, turns with progress, the proposal lifecycle in its floor form (server-minted, single-use, expiring, executed from stored arguments, secret fields excluded, state checked at confirmation, the prohibited set refused), the agent marker, the Anthropic provider, agent configuration and the first-login gate, enforced read-only and the kill switch, screen synchronization and navigation (5.2, 5.3, 5.4). SM-3 is met at the end of this step.
3. The remaining list and detail screens with their read tools (the rest of the read rows).
4. The remaining small write actions: enable, disable, run, suspend, resume, terminate and delete, including auditing on and off, the OAuth 2.0 deletes, on-demand task run and application error deletes (FR-32, FR-37, FR-44, FR-47, FR-48, FR-51, FR-55, FR-57, FR-63).
5. Medium editors: web application create, user and role create, resource, device and wallet editors, X.509 import and audit event configuration (FR-31, FR-36, FR-39, FR-40, FR-43, FR-46, FR-47, FR-59).
6. Large editors, in this order: user edit and web application edit first (FR-35, FR-30), then role edit, service edit, SSL/TLS, LDAP, the task wizard and edit task (FR-38, FR-41, FR-42, FR-45, FR-52, FR-53).
7. Stretch, in this order: the remaining provider adapters, OpenAI, Google Gemini and OpenAI-compatible including local models (FR-25); the per-user read-only toggle (FR-19); the remaining safety hardening, namely the target fingerprint re-read, the typed-name confirmation for destructive tools, the per-user turn limits and the seeded-injection test (FR-17, FR-19, NFR-6). Anything in this step not reached by the deadline ships first in the polish week.

**Owner deviation, 2026-09-16 - step 7 is split.** The provider adapters stay step 7 and run as soon as the agent core is merged (Epic 10). The plain-Community check closes step 5 (Story 8.9). The per-user read-only toggle, the per-user turn limits, the typed-name confirmation and the seeded-injection test move to the polish week (Epic 14), ranked after the OAuth 2.0 editors, because the kick-off named OAuth setup verbatim. The target fingerprint re-read belongs to step 2 (FR-17's re-read is Stories 5.1 and 5.3). Audit event configuration (FR-47's second half) moves from step 5 to step 4, landing a step earlier as Story 7.11 (parallel-run amendment, 2026-09-16).

**Owner deviation, 2026-09-17 - six stories deferred to the polish week for schedule.** Task Manager control and lock removal (step 4's list never named them), the service editor and the LDAP and Kerberos editor (last in step 6's order; they ship reduced per FR-9 with their agent write tools), the data-egress line and the agent audit viewer move to Epic 16 as Stories 16.11 to 16.16. The OAuth 2.0 editors (Epic 12) run beside step 6 rather than after the polish-week Epic 11. The 2026-09-27 floor is unchanged.

**Owner deviation, 2026-09-19 - the optional bonus items are scratched.** Story 13.4 and FR-79's bonus half (the article, the video and the short, and the re-plan against the technology-bonuses post) are dropped: nothing beyond the entry itself is produced before the deadline. The hygiene half of FR-79 stands.

A cut large editor follows FR-9; its write tool ships in step 2 or step 4 as a get-merge-put over the exported endpoint schema, so the agent remains a conduit for that edit. The sizing of the read and write tools assumes they are generated from the screens' endpoint descriptors (FR-16).

**First-week decisions and checks.** 2026-09-09: decide the tool execution transport (Open Question 17) and export the 82 admin API endpoint classes (Open Question 6). 2026-09-10: prove the install path on the durable volume from a clean clone, including down and up, up with a newer image, and up without an existing volume, and design the protected OcuPilot state into it (FR-29, FR-66). 2026-09-11: read the field lists out of the backing models — `%SYS.Task` for FR-52 and FR-53, `%CSP.UI.Portal.EnsembleMonitor` for FR-56, `%CSP.UI.Portal.Audit.*` for FR-47 — since the legacy CSP page source proved unrecoverable (Open Question 7, closed 2026-09-08). 2026-09-12: Open Question 15 is already closed and Open Question 16 has moved past the floor (FR-68); the listing submission formerly dated here is **withdrawn** by the 2026-09-09 stealth decision (section 1.1). 2026-09-13: a turn longer than the stock 60-second gateway timeout proven to complete on an unmodified container, which is what the background-job design buys and replaces the old "set the gateway timeout" task (FR-23); auditing verified on a fresh container.

**Submission plan. Rewritten 2026-09-09 by the stealth decision (section 1.1);** the previous plan posted the idea by 09-11, submitted the listing by 09-12 and applied in the first hours of 09-14, and is superseded in full. By 2026-09-11: the README with install steps and a description at a tagged preview, held privately. 2026-09-23: demo freeze; anything landing after it that touches UJ-3 forces the description, and any video, to be redone — it now sits immediately before the release, so it gates the collateral pass rather than standing apart from it. **2026-09-24, the release, in one pass:** the repository made public, the Ideas Portal idea posted if it is ready, the Open Exchange listing created, and the application submitted carrying only what the rules require — README with install steps and a written description — because approval, not completeness of collateral, is what the three-day buffer is for. 2026-09-25 to 2026-10-04: the loud items — article, video, short, and the idea if it slipped — and a visible change every day of the voting week. By 2026-09-27 23:59 EST the application must be in and approved-or-pending, that being the absolute bound.

### 10.2 Release 1, polish week: P1 rows 2026-09-28 to 2026-10-04

In scope: 5.12, 61 rows, plus token streaming by the 2026-09-08 owner decision (NFR-2). Order inside the week: anything left from step 7 of the build order first; then FR-70 and FR-71 because voters see them; then token streaming, but only if step 7 finished, since it changes the panel's render path and must not put a Release 1 agent write at risk; then the OAuth 2.0 editors (FR-75), since the task statement names OAuth setup; then FR-79's optional bonus items as the bonus post dictates; then the rest as time allows. Three of the seven days are reserved for reacting to judge and voter feedback. Nothing in the polish week may break a Release 1 screen or a Release 1 agent write; a P1 item that risks either waits for Stage 2.

### 10.3 Stages 2 through 6: staged delivery to parity

Each Stage ships as a versioned IPM release with a Developer Community article, on a public roadmap. The order follows API readiness: what an existing route backs comes before what needs new server code. The agent grows in step with the screens. **FR-80 (section 5.13) is the contract every stage below is built under**, so the tables here state scope and gating while FR-80 states how the work is done.

| Stage | Catalog rows | Sizes S / M / L | New REST endpoints | What gates it |
| --- | --- | --- | --- | --- |
| 2. The rest of the admin API (P2) | 60 | 20 / 32 / 8 | 3 | Admin API write payloads observed; async-result polling; the directory allow-list; the admin API's final form in IRIS 2027.1 |
| 3. System Explorer over the Atelier API (P2) | 36 | 17 / 15 / 4 | 0 | The DML and DDL guard on the query action; ETag-checked saves; the iris-table-editor harvest; the DocDB service where used |
| 4. Interoperability over the interop-editors v7 API, with an Analytics rider (P2) | 41 | 10 / 25 / 6 | 4 partial | The sign-in hand-off to the embedded editors; namespace-category gating; the production-update action vocabulary; an analytics-enabled namespace for the rider |
| 5. Custom-REST parity from the MCP suite's handlers (P3) | 165 | 60 / 79 / 26 | 128 | The OcuPilot API router; the handler harvest; the backing models behind the legacy CSP pages, whose own source is unrecoverable (Open Question 7) |
| 6. The long tail, on demand (P4) | 56 | 11 / 29 / 16 | 32 | Demand, and each group's license, edition, platform or deprecation gate |
| Stages 2 to 6 | 358 | 118 / 180 / 60 | 167 | |

Endpoint counts exclude agent-internal rows that ride on the existing turn endpoint. Row-level tables per stage are in `extract-stages.md` in this folder; the screen inventory per stage is in the addendum, section 12.

- **Stage 2, the rest of the admin API.** Rides on the admin API; the agent gains a read tool and a confirmed single-write tool per screen, plus token usage reporting (CP-28).
- **Stage 3, System Explorer over the Atelier API.** Rides on the Atelier API; the agent gains the free-form SQL tool behind the same guard and a picker among agent definitions.
- **Stage 4, Interoperability over the interop-editors v7 API.** Rides on the interop-editors v7 API, with the Analytics rows as a rider since the brief names no Analytics stage and they can be split out without changing anything else; the agent gains guided multistep workflows and investigate entry points.
- **Stage 5, custom-REST parity.** Rides on new OcuPilot API endpoints harvested from the MCP suite's handler bodies; the agent gains the 28 iris-session-agent tools and undo by snapshot and revert. Streaming replies moved to the polish week (section 10.2).
- **Stage 6, the long tail.** Nothing scheduled; each excluded row is picked up only when demand appears and its gate clears.

### 10.4 Out of scope for Release 1

- Interoperability, analytics and System Explorer, whose vendor screens OcuPilot does not replace in Release 1, plus database operations beyond listing, mirroring, backup and restore: Stages 2 to 5.
- Guided multistep workflows and investigate runs: Stage 4. Undo: Stage 5. Streaming moved into the polish week (NFR-2, section 10.2) and is no longer out of scope for Release 1.
- Free-form SQL for the agent: Stage 3, with its guard.
- Embedded vendor editors: Stage 4.

## 11. Risks and Mitigations

The top risks, each with the mitigation this PRD adopts. The full register is in the addendum.

| Risk | Mitigation in this PRD |
| --- | --- |
| The admin API is experimental until IRIS 2027.1 and its 2026.2 form may change; roughly forty Release 1 write rows and every write tool depend on it | FR-3 and NFR-8 pin v2 and test the generated document; write-tool schemas are generated from the endpoints' own body templates and a CI inventory fixture fails the build on a vendor change (section 8); FR-9 covers any write that cannot be made to work. Residual exposure is narrowed to the five Release 1 endpoints that publish no template |
| One developer, 19 days, about 45 developer-days of specified work by the feasibility review's budget | The owner keeps all P0 as the commitment; the build order in 10.1 makes every step a publishable build so any step can be the cut; the listing-build readiness bar and the 2026-09-27 floor; the dated first-week decisions; FR-9 and the budget in the addendum, section 15 |
| A judge without an LLM key sees no agent | Accepted by the owner: README key guidance per shipped provider and a walkthrough with screenshots (FR-69); no local-model profile, and no hosted demo at any point (FR-79, Open Question 8) |
| "OAuth setup" is lists and deletes only at the deadline | Accepted by the owner: the OAuth 2.0 editors ship early in the polish week (10.2); the agent's OAuth delete tools exist at the deadline |
| Group by ID, which silent login depends on, is documented "do not use" | FR-1's form login is the built-in fallback; the exposure is one extra login for portal-first users |
| The legacy CSP pages behind the task wizard, edit task, the dashboard meters, messages.log and the application error log ship compiled-only and their source cannot be recovered at all | Closed by probe on 2026-09-08, and the mitigation changed: the field lists come from the backing models instead, which are richer than the pages. `%SYS.Task` for FR-52 and FR-53, `%CSP.UI.Portal.EnsembleMonitor` for FR-56, `%CSP.UI.Portal.Audit.*` and the admin API audit-event endpoint for FR-47 |
| Wallet, X.509, messages.log and application errors have no confirmed backing class or payload on the instance | Closed. X.509 is `%SYS.X509Credentials` and the wallet endpoint classes exist (Open Question 6); messages.log has no class and is a plain file, and the application error log is the `^ERRORS` global per namespace (Open Question 4). FR-43, FR-46, FR-62 and FR-63 no longer carry a probe as their first task |
| Whether install runs at build or at start on a durable volume is unverified | Closed by the architecture spine: install runs at container start, because the durable volume's databases supersede the image's on every start and a build-time install would be invisible on upgrade. FR-67 states the observable result (Open Question 5) |
| Technology bonuses are unknown until 2026-09-14, including whether a voting-week item still counts | FR-79 re-plans after the kick-off; if bonuses prove deadline-scoped, bonus items are cut rather than crowded into the release window (5.13). Partial-coverage acceptance is **closed**: all six areas are the baseline, and Release 1 covers all six regardless |
| The entry is unpublished until 2026-09-24, so approval must clear inside three days against an absolute deadline | The release window carries only what the rules require, so review has the least to object to; the demo freeze on 09-23 precedes it; releasing later spends the buffer rather than moving the bound (1.1) |
| Slow, non-streaming turns are the loudest complaint about assistants in the field | FR-12 progress cards and NFR-2 in Release 1; streaming in the polish week by the 2026-09-08 owner decision, conditional on build step 7 finishing (section 10.2, Open Question 14) |
| Prompt injection through log and tool content has no field precedent for a defense | NFR-6's boundary in Release 1; FR-72 sanitization in the polish week |
| The vendor could ship this | Speed, continuous visible improvement, and the differentiators in section 2 |

## 12. Open Questions

Re-triaged on 2026-09-08 after the architecture spine's probes, a further round of instance probes, and four owner decisions; **re-triaged again on 2026-09-09 against the live contest pages**, closing items 2 and 10. **Two questions remain live, both external: item 1 at the 2026-09-14 kick-off, item 3 by private direct message, and item 12 whenever InterSystems says.** Item 16 is not answered but is deferred with an owner and a trigger. Everything else is closed. Numbering is stable — requirements cite these IDs — so closed items keep their number and carry their resolution.

1. **Live.** What technology bonuses apply to contest 48, are AI or Angular among them, and **does a bonus item published during the voting week still count?** Recheck after the 2026-09-14 kick-off; re-plan FR-79. The second half is new on 2026-09-09 and is load-bearing: 5.13 places every bonus item after the final submission, which only works if voting-week publication counts. Nothing in writing commits InterSystems to announcing the bonuses on the call — the Open Exchange page says only "Look forward to the announcement of the technology bonuses" — so if the webinar does not produce them, ask on the announcement post, which answered a participant's question in about seventeen hours on 2026-09-07.
2. **Closed 2026-09-09 by the contest text.** Is an entry covering only some of the six areas accepted? No — all six are the baseline. The task reads "Create a GUI powered by InterSystems IRIS management APIs for the following Management Portal tasks", lists the six, then invites the entrant to "add any *other* screens or actions you frequently use": the invitation is to go beyond the list, not to choose from it. Release 1 ships all six regardless, so nothing changes but the question's status.
3. **Half answered; the rest live, and asked privately.** The support stance was answered at the 2026-09-14 kick-off: `/api/admin` v2 is the contest's intended API, experimental until its final form in IRIS 2027.1, with a published spec. Still open: will InterSystems keep Group by ID and the browser-id cookie across releases? **Not to be asked on a public contest thread** — a public question describes the sign-in design that differentiates the entry, which is the same reasoning as the stealth decision in 1.1. Ask by direct message to Raj Singh, Product Manager of Developer Experience, on the Developer Community. The answer moves risk, not architecture: the JWT-only path needs neither, so the exposure is one extra login for portal-first users. Group by ID now carries more weight than silent login alone: item 15 showed the classic portal's shared session rides on it too.
4. **Closed 2026-09-08 by probe.** X.509 credentials are `%SYS.X509Credentials`, and the wallet's endpoint classes exist on the instance (with item 6). messages.log has no backing class — it is a plain file under the manager directory. The application error log is the `^ERRORS` global, held per namespace, written by the `^%ETN` error-trap routine, with retention governed by `Config.Startup.ErrorPurge`. FR-43, FR-62 and FR-63 no longer carry a probe as their first task.
5. **Closed by the architecture spine.** Install runs at container start, not at image build: the durable volume's copies of `IRISSYS`, `IRISSECURITY`, `HSCUSTOM` and `USER` supersede the image's on every start, so a build-time install is invisible on the upgrade path FR-67 must survive.
6. **Closed during finalize.** The 82 hidden admin API endpoint classes are undeployed and their source reads back from the instance, each with an explicit field schema. Export them on 2026-09-09, tabulate fields and required resources per write endpoint, and probe one PUT, POST and DELETE per family for partial-versus-full body semantics; that replaces per-story probing.
7. **Closed 2026-09-08 by probe, with the method inverted.** The legacy page source cannot be pulled at all: every page is a `%cspapp.*` class marked `[Hidden]`, shipped compiled-only, with no UDL text, no intermediate code, no CSP document and no file on disk. The field lists come from the backing models instead, all of which are present and readable — `%SYS.Task` for the task wizard and editor, `%CSP.UI.Portal.EnsembleMonitor` for the dashboard meters, `%CSP.UI.Portal.Audit.*` and the admin API's audit-event endpoint for the auditing page, and the admin API's task-manager endpoint for the task actions. See FR-52, FR-56 and section 10.1.
8. **Closed 2026-09-08 by owner decision.** No online demo instance ships, at any point. See FR-79 for the reasoning and the mitigation that replaces it.
9. **Closed during finalize.** The contest terms' intellectual-property clause is a nonexclusive promotional license, compatible with the MIT license in the repository.
10. **Closed 2026-09-09 by the announcement post.** Freshmen eligibility has two conditions, both required: no more than five previous InterSystems programming contests, **and** never having placed 1st, 2nd or 3rd in either the Experts or Community nomination. There is no opt-in and nothing to do to qualify, so nothing in this document depends on the answer, and an Experts placing under SM-1 would moot it. Not to be raised at the kick-off.
11. **Closed 2026-09-08 by probe: yes mechanically, no as shipped.** `/api/atelier` has JWT disabled and sits outside the `%ISCMgtPortal` group. Enabling JWT would work, but it means modifying a vendor web application, which OcuPilot does not do on an operator's instance. Stage 3 keeps the OcuPilot API or an explicit Basic header (section 8).
12. **Live.** When are winners announced? Not stated in any source read.
13. **Closed during finalize.** The brief's "22 large P0 rows" was a prose error in the research; the catalog has 12 and this PRD uses that figure.
14. **Closed 2026-09-08 by owner decision.** Streaming (CP-34) ships in the polish week, conditional on build step 7 finishing and ranked after FR-70 and FR-71 — not Stage 5 and not Stage 2. See NFR-2 and section 10.2.
15. **Closed 2026-09-08 by configuration probe.** `/csp/sys`, `/api/admin` and `/ui/interop` all carry `GroupById = %ISCMgtPortal`, and `/ui/interop` is the application the auth spike already watched share the session, so the classic portal shares the browser login by the same mechanism. Two caveats changed FR-1 and FR-2: `/csp/sys` is not JWT-enabled, so it rides the CSP session cookie rather than the token pair; and it permits unauthenticated access, so sign-out ends the authenticated session without guaranteeing a login form appears.
16. **Deferred, not closed.** Do install and the credential rungs work on plain IRIS Community, where install falls to `USER` and the namespace may not be interoperability-enabled? Owner decision on 2026-09-08 moved this test to **after the 2026-09-27 application floor**, rather than before the listing. Until it runs, FR-68's plain-Community claim is untested and the risk of a late failure is accepted.
17. **Closed by the architecture spine.** Tools run in-process under the user's IRIS session. No token is needed for a tool call because the process already runs as the user, which removes the access-token-versus-turn-length mismatch entirely and makes the iris-execute-mcp-v2 handler bodies available as tool bodies.

## 13. Assumptions Index

No open assumptions remain; the fifteen draft assumptions and their resolutions are recorded in the addendum, section 1.
