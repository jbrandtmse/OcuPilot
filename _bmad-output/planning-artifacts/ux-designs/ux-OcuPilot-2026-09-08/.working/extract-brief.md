# Extract: brief, addendum, initial idea, README (UX digest)

Sources read in full: `briefs/brief-OcuPilot-2026-09-08/brief.md`, `.../addendum.md`, `docs/initial-idea.md`, `README.md` (overview sections only). Quotes are verbatim; `[UI]` marks a decision that binds the interface.

## 1. The eight decisions

Addendum: "The owner set all of these on 2026-09-08. The inherited ones came before the brief and are inputs to it, not outputs of it." Brief: "Eight decisions were made before this brief and are not reopened here."

1. **Contest scope** `[UI: screen inventory]` — "The six areas the contest names verbatim, plus the agent co-pilot as the differentiator." The six: "manage web apps and explore REST APIs; permission management; security and secrets, including wallet, X.509, and OAuth; task management; OS management, meaning processes, disks, CPU, memory, and devices; and all the logs. Nothing else ships before 2026-09-27."
2. **Agent co-pilot write model** `[UI: propose-review-confirm surface; mode switches]` — "Read/write. Every write is proposed, reviewed, and confirmed, then executes strictly as the logged-in user. Read-only mode and an administrator kill switch exist as switches, not defaults." Brief adds: "Writes are on by default."
3. **Panel** `[UI: direct]` — "Always visible on every route, resizable, never dismissed by navigation. Docked like VS Code's secondary side bar."
4. **Interactive screens** `[UI: direct]` — "A confirmed agent write refreshes and highlights the affected screen (catalog CP-42). The agent can navigate the user to the relevant screen (CP-43)."
5. **Backend** `[UI: every screen is live; data shapes come from the API]` — "Build on the instance's existing REST services: the hidden `/api/admin` v2 service, `/api/monitor`, and `/api/mgmnt`. Custom endpoints only where no route exists: `messages.log`, the application error log, and the agent runtime." Owner's gloss: "'screens and an agent, not a backend' means every screen is wired live to these services. It is a working system, not demo screens."
6. **Authentication** `[UI: login form is a fallback only]` — "Silent-first JWT. ... The shell tries an empty-body `POST /api/admin/login` first, falls back to its own login form, and sends one Bearer token to every JWT-enabled API. Embedded vendor editors log in silently."
7. **Providers** `[UI: first-login gate screen]` — "OpenAI, Anthropic, Gemini, and OpenAI-compatible local models, harvested from iris-session-agent, with a first-login configuration gate and a test-connection action."
8. **Packaging** (no UI binding) — "One IPM module plus a Docker Compose workspace that self-installs. ObjectScript lives under `src/OcuPilot`. Install into `HSCUSTOM` if present, otherwise into `USER`."

Scale (brief): "In for the contest (catalog P0, 119 rows)"; "Polish week (catalog P1, 62 rows, 2026-09-28 to 2026-10-04)". Judgment calls that shape the screen inventory (addendum): "Locks view and removal at P0, although the tier rules put locks at P2." "Wallet at P0 on an undocumented route, because the contest names it." "The interoperability and analytics logs at P1, although both need custom endpoints." "Web sessions at P1 rather than P0." "The memory configuration page at P3, while memory monitoring is P0."

Three further decisions made while writing the brief: "Post-contest success is vendor attention"; "List early, cut cleanly" — "link an unfinished large editor to the classic portal page rather than ship it half-done" `[UI]`; "Developer-administrators are the design target. Production administrators get read-only mode, the kill switch, and a local model" `[UX]`.

## 2. Positioning and personality

- One-line identity (brief): "OcuPilot is an Angular replacement for the InterSystems IRIS System Management Portal, served from the IRIS instance itself. Its real feature is an agent co-pilot: a panel docked on the right, the way VS Code docks its secondary side bar, present on every screen."
- "**The agent co-pilot is the product.**" (brief, bold in source). Initial idea: the agent is "Always visible and the main conduit for editing within the portal."
- Initial idea's own label: "a Agentic System Management Portal for InterSystems IRIS"; README: "**OcuPilot is an agentic System Management Portal for InterSystems IRIS**".
- **Naming rule** (addendum): "The feature is the **agent co-pilot** in every document, never plain 'co-pilot', so it is not confused with Microsoft Copilot. The software inside the panel is 'the agent'. The panel is 'the agent co-pilot panel' or 'the panel'."
- **Name meaning:** none of the four sources explains "OcuPilot" (no Ocu = eye / Pilot gloss anywhere).
- **Logo:** embedded at the top of the brief (`logo/OcuPilot-Logo-web.png`) and centered at the top of the README at `width="360"`. README table: "`logo/` — The OcuPilot logo, full-size and web-optimized." No description of the mark, colors, or usage rules appears in any source.
- **Comparisons, "like X":** VS Code secondary side bar (brief, addendum, README — the only positive UI reference). iris-session-agent's configuration screen ("similar to what is avaliable in ./iris-session-agent").
- **Comparisons, "not like Y":** the classic portal — "a Zen-era portal that InterSystems has deprecated but only partly replaced"; "about 40 classic pages with terse errors and no help beyond a docs link". Microsoft Copilot (name avoidance). The field: "The field mostly drafts. Where it acts, it logs under the user with no agent marker." Thin interfaces: "An entry that only rebuilds the six areas is the thin interface the rules disqualify."
- **Adjectives / tone words found (verbatim):** "working", "live", "a working system, not demo screens", "visible" (toggle, improvement, marked), "distinctly" (audit marks), "strictly as the logged-in user", "silent-first", "comprehensive" (initial idea), "context aware", "one step", "without a click tour".
- **Differentiators the brief names:** built on IRIS's own management APIs; "Execute-with-approval from the panel"; "Distinct audit marking of agent-initiated changes. No product in the research has it."; "A local-model option that keeps data on the instance."
- **Invariant:** "The line that does not move: the agent never holds a privilege the user does not, and every agent write stays visibly marked in the audit log."
- **Aspiration:** "to be the administration portal InterSystems itself points at." Also: "Nobody ships an assistant inside the IRIS portal."
- **Growth path the UI must leave room for** (brief): "The agent co-pilot is the primary way changes are made, and it grows from confirmed single writes to guided multistep workflows, undo, and streaming." Post-contest order (addendum): rest of `/api/admin` (P2), System Explorer (P2), Interoperability with embedded vendor editors (P2), custom-REST parity (P3), long tail (P4).

## 3. Users and their situations

No named personas. Two user groups, one build-side actor, and the voting audience:

- **Design target — developer-administrators** (brief): "They administer their own dev and test instances, often Community Edition in Docker, and they are also the Developer Community voting audience. Success for them is the right screen in one step, an explanation of what they are looking at, and the change made without a click tour."
- **Served by the switches — production IRIS administrators**: "Ops staff on live and often regulated instances get the same product with the switches turned toward caution: read-only mode, the kill switch, and a local model. Success for them is an audit log that shows exactly what the agent did, and nothing done that they did not approve."
- **"Administrator"** as a distinct role is implied only by "an administrator kill switch"; who sets read-only mode is not stated.
- **Builder:** "One developer, 19 days, 22 catalog rows sized large."
- **Voters/judges:** Developer Community members (Community nomination) and the Experts nomination panel.

Situations the sources describe the user in: first login with no agent configured → provider gate → test connection → portal opens (initial idea: "If an agent isn't configured, once the user is logged in an agent configuration screen ... will be presented"); looking at a screen and asking the agent about it; the agent proposing a write "with its rationale"; confirming; watching "progress on multistep turns"; being taken to a screen by the agent; a production admin reviewing the audit log; Community Edition first-run expired-password prompt (README: "the default password is expired on first login. The Portal will prompt you to change it.").

## 4. Reference projects

- **iris-session-agent** — initial idea: "base this on preliminary work done in my ../iris-session-agent project"; "an agent configuration screen (similar to what is avaliable in ./iris-session-agent) will be presented to the user. All of the agent model options in ../iris-session-agent should be supported and the framework should be extendable like ../iris-session-agent." Addendum harvest map: supplies "Providers, the tool contract, the registry, an audit log, and chat history". Post-contest: "every iris-session-agent capability". **UI pattern to reuse: the agent configuration screen** (the only UI explicitly pointed at as a model).
- **iris-execute-mcp-v2** — supplies "The governance model: tool and action keys, default-disabled writes, a read-only preset, server-side confirm gates, and a redacted audit log"; the self-installing custom API pattern; post-contest "a screen equivalent for every iris-execute-mcp-v2 tool" / "ui equivalents of the functions supported in ../iris-execute-mcp-v2"; "Custom-REST parity harvested from the MCP suite's handlers (P3)". No UI of its own is referenced.
- **iris-table-editor** — initial idea lists it as a harvest source for "additional tools and screens". Addendum: "System Explorer over the Atelier API, with the grid harvested from iris-table-editor (P2)" — **post-contest only**. Nothing else is said about its grid editing.
- **iris-couch** — **not named in any of the four sources.**
- **Vendor editors (irisui/)** — initial idea: "Where possible, we should use the pre-built editors and by embedding them. A copy of these are in ./irisui/". Addendum: "the three vendor document editors for BPL, DTL, and rules embedded (P2)" — post-contest. Decision 6: "Embedded vendor editors log in silently."
- **Classic System Management Portal** — a harvest source ("the orginal System Management Portal"); "review the existing System Management Portal ObjectScript code in ./irislib/EnsPortal"; the link-out target for unfinished large editors; legacy CSP pages (task wizard, application error log, messages.log) "have no exported source. Pull their source from the container before writing those screens."
- New for OcuPilot (not harvestable): "Progress reporting and streaming, propose-review-confirm for writes, execution as the logged-in user, a test-connection action, a first-login gate, and sanitization of log content before it reaches the model".

## 5. Explicit look-and-feel or UX statements (verbatim)

- Brief: "a panel docked on the right, the way VS Code docks its secondary side bar, present on every screen."
- Brief: "The panel receives the current screen as context, and a visible toggle turns that off."
- Brief: "proposes each write with its rationale for the user to confirm."
- Brief: "marks its writes distinctly in the audit log, and shows progress on multistep turns."
- Brief (block heading): "**Screens that answer the agent.**"
- Brief: "Writes are on by default. Two switches restrain them: read-only mode and an administrator kill switch."
- Brief: "It runs as the user with no added privileges".
- Brief: "After a confirmed write, the affected screen refreshes and highlights what changed, or a toast links to it. The agent can take the user to the relevant screen."
- Brief: "A first-login gate configures the provider and tests the connection before the portal opens."
- Brief (scope): "the shell; the agent co-pilot core; the six areas as list, detail, create, edit, delete, and enable/disable wherever a route exists; the four log viewers".
- Brief: "An unfinished large editor links to the classic portal page rather than shipping half-done."
- Brief (P1): "suggested prompts, explain-this-screen, the agent audit viewer, the OAuth 2.0 editors, secondary log viewers".
- Brief (out): "streaming beyond progress indication, undo".
- Addendum: "Always visible on every route, resizable, never dismissed by navigation. Docked like VS Code's secondary side bar."
- Addendum: "falls back to its own login form"; "Embedded vendor editors log in silently."
- Addendum cut line: small writes "enable, disable, run, suspend, resume, terminate, and delete"; medium editors "web application create, user and role create, and the resource, device, and wallet editors"; large editors "web application edit, user and role edit, service edit, SSL, LDAP, and the task wizard".
- Initial idea: "a co-pilot like agent on the right hand side. Always visible and the main conduit for editing within the portal."; "The agent should be context aware of what is on the screen at all times."; "The portal will be built in Angular and served from IRIS."
- README: "a panel docked on the right of every screen, the way VS Code docks its secondary side bar."
- README logo: `<p align="center"><img ... width="360">`.

**Absent entirely:** density, color, typography, dark mode, accessibility, keyboard, responsive or narrow-viewport behavior, primary navigation structure, iconography, empty/loading/error state styling. The only error-related statement is the negative reference to the classic portal's "terse errors and no help beyond a docs link."

## 6. Contest and demo expectations

- Hard requirements (pass/fail): "Fully functional. Not a thin interface over an existing library or app. Open source on GitHub or GitLab. English README with install steps and a video or description. Runs on IRIS Community or IRIS for Health Community. The Open Exchange listing exists before applying. At most three submissions per developer."
- Contest ask (brief): "It asks for 'a GUI powered by InterSystems IRIS management APIs' covering six areas, invites extra screens or actions, and rejects thin interfaces over an existing API".
- Judging criteria: "Complexity, Clarity of Instructions, Developer Experience, Applicability, Usability."
- Open questions carried (addendum): "Whether partial coverage of the six areas is accepted."
- Bonus precedent (Full Stack 2026): "Vector Search, Embedded Python, DC Idea, Docker, IPM, Online Demo, Find a Bug, DC Article, YouTube Video and Short, First-Time Contribution". Technology bonuses "are unstated until the 2026-09-14 kickoff."
- Deliverables: "a README with install steps and a video, a Developer Community article, an online demo, and an Ideas Portal link."
- Success criteria: "All six areas demonstrable, with at least one confirmed agent co-pilot write in each." "A demo where the agent makes a confirmed change on a real screen in under a minute, from a README that installs the first time." "Listed on Open Exchange with a submittable build on 2026-09-14, then a visible improvement every day of the voting week."
- Dates: kickoff 2026-09-14; deadline 2026-09-27 23:59 EST; voting 2026-09-28 to 2026-10-04; polish week = voting week.
- What voters are: the developer-administrator design target ("they are also the Developer Community voting audience"). Field "Empty as of 2026-09-08. Prior contests drew 16 to 17 entries."
- Nothing is said about screenshots, thumbnail, or the first frame of the video beyond the confirmed-change-under-a-minute demo. "Online demo" is listed but its hosting and login are not described.

## 7. Gaps for UX

- Name meaning and logo: no etymology, no mark description, no palette, no typography, no usage rules.
- Primary navigation: how the six areas and ~40 screens are reached (sidebar, top bar, breadcrumbs, search) is unstated.
- Panel: default and minimum width; whether "never dismissed" permits collapse to a strip; behavior on narrow viewports; whether chat history persists across routes/sessions and per user.
- Context toggle: placement; what "the current screen" includes (selection, filters, visible rows); how the agent's awareness is shown to the user.
- Propose-review-confirm: where the proposal renders (panel, inline on the screen, modal); what "reviewed" displays (payload, diff, plain-language summary); one-by-one vs. batch confirmation on multistep turns; cancel/deny path.
- Post-write feedback: highlight style and duration; when a toast is used instead of an in-place highlight; toast content and link target.
- Agent-driven navigation: whether it asks first or just goes; how a navigation is announced.
- Progress on multistep turns: form unspecified; streaming is out for the contest.
- Read-only mode and kill switch: who sets each, where they live, how the panel presents itself when writes are off or the agent is killed.
- First-login gate: fields per provider; "similar to" iris-session-agent is the only guidance; per-user vs. per-instance configuration; what a failed test-connection shows; re-entry path after first login.
- Fallback login form: appearance, error states, relation to the expired-password first-run on Community Edition.
- Audit marking: how an agent-initiated entry looks in the audit viewer (P1) and in the log viewers.
- REST API explorer: named in area one ("web applications and a REST API explorer" / "manage web apps and explore REST APIs") with no statement of what exploring shows or does.
- Screen archetypes: list/detail/create/edit/delete/enable-disable patterns, table density, filtering, bulk actions, the task wizard's shape.
- Log viewers (four for contest): tail/search/filter/refresh behavior unspecified; sanitization before the model has no stated UI implication.
- Link-out to classic portal for unfinished editors: new tab vs. embedded; how the hand-off is labeled.
- Embedded vendor editors: post-contest only; framing inside the shell unspecified.
- Namespace: portal is %SYS-centric while the sandbox defaults to HSCUSTOM; no statement on namespace selection in the UI.
- Suggested prompts and explain-this-screen (P1): content and placement unspecified.
- Dark mode, accessibility, keyboard shortcuts, responsive layout, empty/loading/error states: absent.
- "Usability" and "Developer Experience" as judged: no definition or rubric beyond the criterion names.
- Online demo: hosting, credentials, and what a voter sees first are unstated.
