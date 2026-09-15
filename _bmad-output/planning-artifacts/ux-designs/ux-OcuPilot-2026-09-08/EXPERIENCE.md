---
name: OcuPilot Experience
title: OcuPilot Experience
description: Information architecture, behavior, states, interactions, accessibility and key flows for OcuPilot
status: final
created: '2026-09-08'
updated: '2026-09-08'
project: OcuPilot
design: DESIGN.md
sources:
  - ../../prds/prd-OcuPilot-2026-09-08/prd.md
  - ../../prds/prd-OcuPilot-2026-09-08/addendum.md
  - ../../research/technical-ocupilot-portal-feature-landscape-2026-09-08/research.md
  - ../../research/technical-ocupilot-portal-feature-landscape-2026-09-08/feature-catalog.md
  - ../../research/technical-ocupilot-portal-feature-landscape-2026-09-08/spike-auth-handoff.md
  - ../../briefs/brief-OcuPilot-2026-09-08/brief.md
  - ../../briefs/brief-OcuPilot-2026-09-08/addendum.md
imports:
  - imports/OcuPilot-Logo-web.png
  - imports/OcuPilot-Logo-full.png
  - imports/OcuPilot-Logo.jpeg
  - imports/robot-avatar.png
  - imports/robot-avatar-64.png
  - imports/OcuPilot-Lockup-horizontal-reversed.png
  - imports/OcuPilot-Lockup-horizontal.png
  - imports/OcuPilot-Favicon-source.png
---

# OcuPilot — Experience Spine

How OcuPilot behaves. Paired with `DESIGN.md` (how it looks). Requirements, personas and the feature catalog are inherited by reference from the sources above; `FR-n`, `UJ-n` and `NFR-n` cite the PRD; `XX-nn` — a two-letter area code and a number, such as `LG-02` or `CP-16` — cites the feature catalog. Terms follow the PRD glossary (§4) exactly: *agent co-pilot* is the feature (never "co-pilot"), *the agent* is the software in *the panel*, a *screen* is one route inside an *area*, a *write tool* always produces a *proposal* that needs a *confirmation*.

**Contents.** Foundation · Information Architecture · Agent Write Lifecycle · Privilege Gating · Voice and Tone · Component Patterns · State Patterns · Interaction Primitives · Screen Synchronization and Live Data · Session and Sign-in · Accessibility Floor · Responsive & Platform · Inspiration & Anti-patterns · Open items · Key Flows.

**Where each kind of fact lives.** The *Fixed strings* table in Voice and Tone owns strings; Agent Write Lifecycle owns the proposal contract; Privilege Gating owns gated-control behavior; the Session table in State Patterns owns sign-in states; Responsive & Platform owns the size numbers; Screen Synchronization and Live Data owns live-data behavior; Component Patterns owns everything else. Where a section other than the owner states one of those facts, it states the trigger and points at the owner.

**When this document and `DESIGN.md` disagree.** This document wins on behavior and copy — what happens, in what order, and the words on screen, the accessible name among them. `DESIGN.md` wins on visual treatment — color, type, spacing, radius, elevation, and placement within a region. A fact that is both is split along that seam rather than decided wholesale: this document says a notice appears and what it reads, `DESIGN.md` says what it looks like and where it sits. Where one document contradicts itself, the other resolves it. Neither document states the other's kind of fact without pointing at it.

## Foundation

Single-surface desktop web. An Angular SPA at `/ocupilot`, served from the one IRIS instance it manages, talking to `/api/admin` v2, `/api/monitor`, `/api/mgmnt` and its own `/api/ocupilot`. Current Chrome on desktop is the supported browser; Edge, Firefox and Safari are best effort (NFR-11). English only. No CDN — every library is vendored (NFR-10).

**UI system:** Angular Material (Material 3) with Angular CDK. Material supplies ARIA-complete components; CDK supplies overlay, table and virtual scroll. `DESIGN.md` is the visual identity reference and specifies the brand-layer delta over Material tokens; this spine specifies the behavioral delta. Light is the default on first load; light and dark token sets are both defined in `DESIGN.md`, and the polish-week theme toggle (FR-73) is a flag flip.

**Primary navigation is the agent.** The user tells the agent what they want; the agent answers, proposes, and — after announcing it — takes the user to the screen it means. Everything else follows VS Code conventions.

**The VS Code-shaped shell** — present on every route:

| Region | Size token | Holds | Behavior |
|---|---|---|---|
| header | `{spacing.header-height}` on `{colors.shell}` | logo-lockup (left) · command-box (center) · namespace switch (right) | Fixed. Never scrolls. |
| rail | `{spacing.rail-width}` (48 px) on `{colors.shell}` | rail-items in daily-use order: Home · Logs · OS management · Tasks · Permissions · Web applications and REST API explorer · Security and secrets; Agent co-pilot pinned bottom | Click opens the side-bar for that area; click again collapses it. Agent co-pilot behaves the same way. Home is the exception: it has no screen list, so its rail-item navigates to Home and collapses the side-bar. |
| side-bar | `{spacing.side-bar-width}` (240 px, fixed — no drag) | the current area's screens; absent on Home, which has no screen list | Open/closed state remembered per browser; stays open across routes until collapsed by its rail-item, Ctrl/Cmd+B or the yield order (Responsive & Platform). |
| content | remaining width, never below `{spacing.content-min-width}` | locator-bar · command-bar · the screen | Reflows to the width left by the panel. |
| panel | `{spacing.panel-default}` (400 px) default · `{spacing.panel-min}` (320 px) minimum · `{spacing.panel-home}` on Home (min(50vw, viewport − rail − content-min-width); Responsive & Platform) | the agent co-pilot: New conversation control, context-chip, transcript, cards, composer with Send/Stop | Docked right of every screen. Resizable (the only resizable edge), remembered per browser, full-screen toggle. **No close control in Release 1.** Route changes keep the panel and its conversation. |
| status-bar | `{spacing.status-bar-height}` | server · instance · user ▾ · licensed-to · server-flag-badge · auto-refresh stamp · connection state | Fixed. Read-only except the user segment, which is the account menu. |

→ Composition reference: `mockups/key-webapps-proposal.html` — this document and `DESIGN.md` rendered at 1,440px (rail, side bar, header, status bar, table with a changed row, panel with a confirmed proposal card). Superseded direction study: `mockups/direction-bridge.html` — the UJ-3 hero (Web applications list, `/csp/myapp` row highlighted after the confirmed write, the proposal card in its confirmed state) and the panel-forward Home with the "not being marked" and lock banners. That direction study predates the header/status-bar split and shows the instance fields in the header; they live in the status-bar. **DESIGN.md and this document take precedence over any mock, wireframe or import.**

**Install prerequisite — auditing.** `[NOTE FOR ARCHITECTURE]` a Normal-security Community container ships with auditing off, so the installer should enable auditing and register OcuPilot's audit events (owner-consented, itself audited) — otherwise the "Agent writes are not being marked" banner is the panel's first words on every fresh container and UJ-3 ends with no marked event.

## Information Architecture

→ Map: `wireframes/ia-2026-09-08.excalidraw` — the auth stack, the rail with its eight bands (Home plus the seven areas), every Release 1 screen (solid), polish-week screen (dashed) and dialog (rounded), the cross-cutting affordances, and the panel column with its context and navigation arrows. Confirmed complete by the owner: every stated need has a surface and every surface has a way in.

**The rail, top to bottom (daily-use order):** Home · Logs · OS management · Tasks · Permissions · Web applications and REST API explorer · Security and secrets · — · Agent co-pilot (pinned bottom, the seventh area; satisfies FR-20's "reachable without the agent"). The only rail badge is the attention-dot on Agent co-pilot.

**Routes** carry the namespace as a query parameter and the selected entity in the path (mock: `/ocupilot/web-applications/csp-myapp?ns=HSCUSTOM`). Deep links are honored after sign-in. A screen's *screen context* (FR-11) is its route, namespace, selected entity, and the rows currently in the viewport together with the active sort and filter (so the read tool can reproduce the set); the context-chip shows the row count. `[NOTE FOR ARCHITECTURE]` cap the rows that travel with a turn (a viewport holds about 16; 50 is a safe ceiling) and show the count on the read tool-call card — a 1,000-row fetch must never be sent to the provider.

### Surfaces

Step = PRD §10.1 build step ("1/3" = the area's one step-1 list, otherwise step 3; "1 (endpoint) / 3" = the endpoint lands in step 1 and the screen in step 3); the step number is inherited from PRD §10.1, which is authoritative if the sequencing changes. Tier is **P0** for Release 1; rows marked **P1** are polish week (2026-09-28 to 2026-10-04). Archetype is one of the 12 state-matrix keys in State Patterns, or `shell`, whose states live in the Shell and Session tables, or `external`, which opens a new tab and has no states here; a P1 row listing several surfaces lists their keys.

| Surface | Area | Reached from | Purpose | Archetype | Step / tier |
|---|---|---|---|---|---|
| Silent login | shell | any route on load | mint the token pair with no form; the requested route is honored | shell | 0 · P0 |
| Form login | shell | silent login 401 · failed refresh · Sign out | centered card with the light lockup (`imports/OcuPilot-Lockup-horizontal.png`), user name, password, Sign in; the expired-password variant names the user and links to the fix (UJ-5) | shell | 0 · P0 |
| Version-mismatch notice | shell | `/api/admin/info` absent or not v2 | blocking; names the mismatch; links to the classic portal; no area screen loads (FR-3) | shell | 0 · P0 |
| No-administrative-privileges notice | shell | privilege map holds no `%Admin_*` | "no administrative privileges on this instance" with a sign-out link (FR-3, FR-65) | shell | 0 · P0 |
| First-login gate | shell → Agent co-pilot › Definitions | sign-in by an OcuPilot administrator while no definition is enabled | redirect (dashed arrow) onto the Definition form under the gate landing banner; bypassable; reminder banner in the panel until one definition is enabled (FR-28) | shell | 2 · P0 |
| Sign out | shell | status-bar user segment (the account menu: Sign out now; Change password and the theme toggle in polish week) · command-box "Sign out" `[ASSUMPTION: the account home is the memlog's working answer, not an owner decision]` | ends the browser-level login (classic portal and embedded editors too, OQ15); clears tab storage; lands on Form login (FR-2) | shell | 0 · P0 |
| Home | shell | rail › Home · logo-lockup · after sign-in (→ `mockups/key-home.html`, both variants) | area-tiles in daily-use order (a wrapping grid, each tile captioned with its screens), instance line; the panel widens to `{spacing.panel-home}` and shows its suggested view or, when nothing needs attention, three starter prompts; with no enabled definition it keeps the same Home width and the configuration-empty state's example card fills it, so a visitor without a key still sees what a proposal looks like | home | 0 · P0 (suggested view 2) |
| Home — System Information panel · favorites · recents | shell | Home | fit above/beside the tile row (FR-73, SH-13/14/19) | home | **P1** |
| alerts.log viewer | Logs | side-bar › alerts.log | recent entries (monitor API) merged with a bounded history tail (FR-60) | log-viewer | 3 · P0 |
| messages.log viewer | Logs | side-bar › messages.log | bounded pages; search with highlight; jump top/bottom; Load newer; never the whole file (FR-62) | log-viewer | 1 (endpoint) / 3 · P0 |
| Application error log | Logs | side-bar › Application errors | namespaces → dates → errors; text, time, routine, line (FR-63) | drill-down | 1 (endpoint) / 3 · P0 |
| Delete application errors | Logs | row-overflow-menu / command-bar on any drill-down level | by namespace or one error; names the scope — the Logs area's SM-3 write | dialog | 4 · P0 |
| Audit database viewer | Logs | side-bar › Audit database · cross-link (dashed) from Auditing configuration | criteria form: time range, source, type, name, user, pid, namespace, authentication - the eight the audit API filters on, it having no free-text search; agent-marker filter (FR-61, LG-02 = SS-14) | list (server criteria) | 3 · P0 |
| Audit event detail | Logs | row click in the Audit database viewer | full event: description and JSON payload | dialog | 3 · P0 |
| System Monitor log · Background task error log · xDBC error log · SQL diagnostics log · Interoperability event log · Analytics log · Unified log hub | Logs | side-bar | secondary viewers and the hub with counts, last entry and explain entry points (FR-77) | log-viewer · list | **P1** |
| Processes list | OS management | side-bar › Processes | process id, user, namespace, routine, state, commands, globals; filter; max rows; persisted sort; auto-refresh (FR-54) | list | 1/3 · P0 |
| Process details | OS management | Processes name cell · Locks owner link | dashboard meters, client executable and address, open devices, current SQL statement; control actions | detail | 3 · P0 |
| Terminate process | OS management | row-overflow-menu / command-bar / Process details | optional error-to-job flag; names the pid; own process refused (FR-55) | dialog | 4 · P0 |
| Locks view | OS management | side-bar › Locks | by namespace; filter; owner details, owner links to Process details (FR-57) | list | 3 · P0 |
| Remove locks | OS management | row-overflow-menu on Locks | one lock · all of a process · all of a remote client; warns when the owner is in a transaction | dialog | 4 · P0 |
| System usage + dashboard meters | OS management | side-bar › System usage | global refs, routine calls, block reads/writes, journal entries, shared memory; CPU, memory, performance meters; refresh interval (FR-56) | meters | 3 · P0 |
| Databases list | OS management | side-bar › Databases | General / Free-space views; free-space figures arrive asynchronously (FR-58) | list (two views) | 3 · P0 |
| Database details | OS management | Databases name cell | properties, volume files, background tasks; auto-refresh | detail | 3 · P0 |
| Devices list | OS management | side-bar › Devices | list (FR-59) | list | 3 · P0 |
| Device editor | OS management | Devices name cell · command-bar › Create | fields of `%CSP.UI.Portal.Config.Device` | form-page | 5 · P0 |
| Broadcast · License usage · Dashboard main panel · External language servers list → editor | OS management | Processes multi-select (Broadcast) · side-bar | FR-76, FR-78 | dialog · meters · list · form-page | **P1** |
| Task schedule | Tasks | side-bar › Task schedule | name, namespace, type, last run, next run; Task Manager status (a warning banner while it is suspended; its Resume control arrives with Epic 7's Task Manager controls, FR-51); filter; auto-refresh (FR-48) | list | 1/3 · P0 (control 4) |
| Task details | Tasks | Task schedule name cell · agent navigation (UJ-6) | properties, schedule, last/next run; auto-refresh; links to history and Edit (FR-50) | detail | 3 · P0 |
| Task history (one task) | Tasks | Task details › History | start, end, status, error text, running user | list (server criteria) | 3 · P0 |
| On-demand tasks | Tasks | side-bar › On-demand tasks | Run per row | list | 3 / 4 · P0 |
| Upcoming tasks | Tasks | side-bar › Upcoming tasks | horizon (hours or date); ordered by next run | list | 3 · P0 |
| Task history (all) | Tasks | side-bar › Task history | filter | list (server criteria) | 3 · P0 |
| New task wizard | Tasks | Task schedule command-bar › Create | stepper: Basics · Task type and settings · Schedule · Options and notifications `[ASSUMPTION until OQ7 delivers the field lists]` (FR-52) | wizard | 6 · P0 |
| Edit task | Tasks | Task details › Edit · row-overflow-menu | wizard fields in tabs with current values (FR-53) | form-page (tabs) | 6 · P0 |
| Delete task | Tasks | row-overflow-menu · Task details | names the task | dialog | 4 · P0 |
| Suspend Task Manager | Tasks | Task schedule command-bar | warns: no scheduled task will run until it is resumed | dialog | 4 · P0 |
| Export / Import tasks · Background tasks | Tasks | command-bar · side-bar | FR-76 | dialog · list | **P1** |
| Users list | Permissions | side-bar › Users | name, full name, enabled, account expired, type, roles; filter (FR-35) | list | 1/3 · P0 |
| User editor | Permissions | Users name cell · Create user success | tabs mirroring the classic tabs incl. Roles; first large editor built | form-page (tabs) | 6 · P0 |
| Create user | Permissions | Users command-bar › Create | name, password, full name, roles, expiry, startup namespace/routine; opens the editor on success (FR-36) | form-page | 5 · P0 |
| Set password | Permissions | row-overflow-menu · User editor | change-on-login flag (FR-37) | dialog | 4 · P0 |
| Delete user | Permissions | row-overflow-menu · User editor | names the user; the current user is refused with an explanation | dialog | 4 · P0 |
| Roles list | Permissions | side-bar › Roles | list (FR-38) | list | 3 · P0 |
| Role editor | Permissions | Roles name cell · Create role success | description, escalation-only, resource grants, members, granted-to | form-page (tabs) | 6 · P0 |
| Create role | Permissions | Roles command-bar › Create | name, description, resources, granted roles (FR-39) | form-page | 5 · P0 |
| Role resource grant | Permissions | Role editor grants section | resource + permissions; shows the current grant and the result | dialog | 5 · P0 |
| Delete role | Permissions | row-overflow-menu | warns with the count of users holding it | dialog | 4 · P0 |
| Resources list | Permissions | side-bar › Resources | search; system resources shown, not deletable (FR-40) | list | 3 · P0 |
| Resource editor | Permissions | Resources name cell · command-bar › Create | name, description, public permission `[ASSUMPTION: a small three-field form, so a dialog rather than a route]` | dialog | 5 · P0 |
| Services list | Permissions | side-bar › Services | enabled, allowed IPs, auth methods (FR-41) | list | 3 · P0 |
| Service editor | Permissions | Services name cell | tabs; disabling OcuPilot's own web service warns that it locks the user out | form-page (tabs) | 6 · P0 |
| Effective privileges · Permission check | Permissions | User editor · command-bar | FR-74 | detail · dialog | **P1** |
| Web applications list | Web applications and REST API explorer | side-bar › Web applications | name, namespace, type, enabled, dispatch class, resource; filter (FR-30) | list | 1/3 · P0 |
| Web application editor | Web applications and REST API explorer | name cell · Create success | tabs mirroring the classic editor (FR-30) | form-page (tabs) | 6 · P0 |
| Create web application | Web applications and REST API explorer | command-bar › Create | type (CSP/REST/WSGI/ASGI), namespace, dispatch class, resource, auth methods; opens the editor (FR-31) | form-page | 5 · P0 |
| Delete web application | Web applications and REST API explorer | row-overflow-menu · editor | names the application; OcuPilot's own refused with an explanation (FR-32) | dialog | 4 · P0 |
| REST API explorer list | Web applications and REST API explorer | side-bar › REST API explorer | REST-enabled applications and spec-based services in the current namespace (FR-33) | list | 3 · P0 |
| OpenAPI document viewer | Web applications and REST API explorer | explorer name cell | path-and-verb browser: paths in document order, each a disclosure opening to its verbs with parameters and response codes; a Raw toggle shows the document on the code surface; a refused document shows the refusal (FR-34) | viewer (OpenAPI) | 3 · P0 |
| Try-it request console · Web sessions | Web applications and REST API explorer | OpenAPI viewer · side-bar | FR-74 | viewer (OpenAPI) · list | **P1** |
| SSL/TLS configurations list | Security and secrets | side-bar › SSL/TLS | name, description, enabled, type; filter (FR-42) | list | 3 · P0 |
| SSL/TLS editor | Security and secrets | name cell · command-bar › Create | certificates, key, CA, CRL, protocol min/max, ciphers, DH bits, OCSP, peer verification; tabs | form-page (tabs) | 6 · P0 |
| X.509 credentials list | Security and secrets | side-bar › X.509 | subject, issuer, validity (FR-43) | list | 3 · P0 |
| X.509 import / edit | Security and secrets | name cell · command-bar › Import | certificate + optional key; private keys never returned | form-page | 5 · P0 |
| LDAP / Kerberos configurations list | Security and secrets | side-bar › LDAP / Kerberos | list (FR-45) | list | 3 · P0 |
| LDAP / Kerberos editor | Security and secrets | name cell · command-bar › Create | fields of `%CSP.UI.Portal.LDAP`; tabs | form-page (tabs) | 6 · P0 |
| Wallet collections | Security and secrets | side-bar › Wallet | collections; the whole screen is disabled without the wallet resource (FR-46) | list | 3 · P0 |
| Secrets list | Security and secrets | collection name cell | secrets of one collection; values write-only | list | 3 · P0 |
| Secret form | Security and secrets | Secrets name cell · command-bar › Create | masked value, never echoed back | form-page | 5 · P0 |
| OAuth 2.0 | Security and secrets | side-bar › OAuth 2.0 | one screen, five tabs: Client server descriptions · Client configurations · Resource servers · Authorization server (view) · Server client descriptions `[ASSUMPTION: five lists as tabs of one screen rather than five side-bar entries]` (FR-44) | detail | 3 · P0 |
| Delete OAuth client configuration / server client description | Security and secrets | row-overflow-menu | names the entry | dialog | 4 · P0 |
| Classic OAuth editor | external (new tab) | OAuth 2.0 row name cell | each entry links to the classic editor until the P1 editors exist | external | — |
| Auditing configuration | Security and secrets | side-bar › Auditing | enable/disable auditing (warns that agent writes will no longer be marked); system events; user events; selective SQL auditing wizard; cross-link to the Audit database viewer in Logs (FR-47) | form-page | 4 / 5 · P0 |
| SSL test · X.509 details · LDAP test · OAuth token revoke · Audit copy / purge · OAuth 2.0 editors (five) | Security and secrets | editors · row-overflow-menu | FR-75 | dialog · form-page | **P1** |
| Definitions list | Agent co-pilot | rail › Agent co-pilot › Definitions · First-login gate | name, provider, model, enabled, default (FR-24) | list | 2 · P0 |
| Definition form | Agent co-pilot | Definitions name cell · command-bar › Create · gate | provider cascade, suggested models, write-once key, Test connection, read-only flag, retention (FR-24..27); name, provider, model, endpoint, key and Test connection sit above the fold, and max tokens, temperature, max iterations, the system-prompt override and retention collapse under "Advanced", closed by default | form-page | 2 · P0 (other providers 7) |
| Switches | Agent co-pilot | side-bar › Switches | kill switch (global / per user) · enforced read-only · context-sharing default · per-user turn limits (step 7); every change audited; never depends on the agent (FR-19, FR-20, FR-29) | form-page | 2 · P0 |
| Governance policy · Agent audit ledger · Transcripts | Agent co-pilot | side-bar | FR-71, FR-72 | form-page · list (server criteria) | **P1** |
| The panel | every route | always present | New conversation, context-chip, transcript, tool-call cards, proposal cards, banners, composer with Send/Stop; full-screen toggle, resize handle | panel | 2 · P0 |

**Actions without a surface of their own** (row-overflow-menu and command-bar, acting on the selection, updating the row in place): enable/disable web application · enable/disable user · add/remove roles (User editor) · run/suspend/resume task · start/resume the Task Manager · run an on-demand task · suspend/resume process · enable/disable audit events, reset counters · enable/disable a definition, set default · the kill switch and enforced read-only toggles (Switches). Delete, terminate, remove-locks, set-password and grant actions open the dialogs above.

### Side-bar screen lists

Entries in daily-use order. A screen that is not yet built does not appear in the side-bar — no dead entries `[ASSUMPTION: P1 entries appear only once shipped]`.

| Area | Release 1 entries | Polish-week entries |
|---|---|---|
| Logs | alerts.log · messages.log · Application errors · Audit database | System Monitor log · Background task error log · xDBC error log · SQL diagnostics log · Interoperability event log · Analytics log · Unified log hub |
| OS management | Processes · Locks · System usage · Databases · Devices | License usage · Dashboard · External language servers |
| Tasks | Task schedule · On-demand tasks · Upcoming tasks · Task history | Background tasks |
| Permissions | Users · Roles · Resources · Services | — (Effective privileges is a User editor view; Permission check is a command-bar action) |
| Web applications and REST API explorer | Web applications · REST API explorer | Web sessions |
| Security and secrets | SSL/TLS · X.509 · LDAP / Kerberos · Wallet · OAuth 2.0 · Auditing | — (tests, details, revoke, copy/purge and the OAuth editors attach to existing screens) |
| Agent co-pilot | Definitions · Switches | Governance policy · Agent audit ledger · Transcripts |

### Dialogs

Dialogs exist only for: set password · role resource grant · resource editor · terminate process · remove locks · audit event detail · every delete confirmation (web application, user, role, task, device, secret, X.509 credential, SSL/TLS configuration, LDAP configuration, OAuth entries, application errors) · the two warnings that precede a non-delete write (Suspend Task Manager; disable auditing) · the warning before disabling OcuPilot's own web service. Everything else is a full-page route. Dialogs never stack.

### Adding a screen (the screen contract)

Every screen registers the same 10 things, so 60 screens behave alike and the panel can find them:

1. **Route** — `/ocupilot/<area>/<screen>[/<entity id>]?ns=<NAMESPACE>`; the entity id is a reversible encoding of the API's id as one path segment `[NOTE FOR ARCHITECTURE]` (percent-encoding by default; the mock's `csp-myapp` is illustrative — names with spaces, slashes and leading `_` such as `_SYSTEM` must round-trip).
2. **Side-bar entry** and its daily-use position.
3. **Archetype** — one matrix key, which fixes the states it must show.
4. **Privilege resource** — the `%Admin_*` (or OcuPilot administrator) resource that gates the entry, the route and each action.
5. **Entity-type key** — the change-event type the screen re-fetches on, and the id → row mapping for the highlight target.
6. **Context serializer** — how the viewport's rows, sort and filter become screen context, and which fields are secret-typed (never sent).
7. **Primary action** (Create / Import, or none) and the **row-menu items** in command-bar order, destructive last, with their self-protection rules.
8. **Empty-state sentence** and, on write-capable lists, the "Or ask the agent: …" line.
9. **Fixed strings** it introduces (confirmations always name the target).
10. **Command-box aliases** drawn from the contest wording ("web apps", "REST", "x509", "certificates", "CPU", "disks").

## Agent Write Lifecycle

→ State sheet: `mockups/key-proposal-states.html` — the card live, confirmed, canceled by a message, expired with Re-propose, destructive with the typed-name field, and blocked by read-only; the hero at `mockups/key-webapps-proposal.html` shows the confirmed card in the shell.

Propose → review → confirm, as the user experiences it. Server-minted, single-use, expiring proposals; exactly one explicit confirmation per proposal, never zero and never batched (SM-C2, §7.1).

1. **Propose.** The agent calls a write tool. A tool-call card appears ("propose update web application /csp/myapp"), followed immediately by a proposal-card in the transcript. Several proposals in one turn stack in order, each with its own Confirm/Cancel; there is no "Confirm all". The screen showing that entity type pauses auto-refresh.
2. **Review.** The card shows the target, the changed fields as diff-rows (before/after computed on the instance from a fresh read), the unchanged fields that the payload still sends, collapsed under "N unchanged fields" (every field stays available, FR-17), "Agent's rationale" and "Expected impact" as the agent's labeled text, and "Reverse:" where a reversal exists. A secret in the payload is a masked-secret-field the user fills now, required before Confirm, and the diff shows "••••••••" on both sides. A destructive write carries a typed-name-field (step 7), and its Confirm is button-destructive and `aria-disabled` until the name matches. A proposal to disable auditing carries the warning "Agent writes will no longer be marked in the audit database." in the card. The footer reads "Runs as <user name>, with your privileges." and "Confirm here; sending a message cancels this proposal"; the countdown "Expires in m:ss" runs from 10:00, and the agent's accompanying message ends "Press Confirm on the card to apply it." `[NOTE FOR ARCHITECTURE]` where the API accepts a partial update, the write tool should send only the changed fields so the list is what the user asked for.
3. **Confirm.** Confirm sends a separate authenticated request from the browser, as the user. The button shows progress (`aria-disabled`, focus kept). On success the buttons are replaced by the status line "Confirmed by <user name> · hh:mm:ss", which receives focus, and Send is a primary again. The write's tool-call card reads "done · audit marked"; the screen re-fetches in place and highlights the row or field within 2 s. The agent's reply states what it verified and ends "Shall I show you the audit entry?" — answering yes takes the user to Logs › Audit database with the agent-marker filter applied. A 403 on confirm shows "failed — <resource>" on the tool-call card, and the agent says so instead of retrying.
4. **Cancel.** Cancel replaces the buttons with the status line "Canceled — by you"; the card takes the restrained treatment, and focus moves to the status line when a button held it. Sending a new message — or starting a new conversation — cancels every live proposal (the PRD's rule). Three things follow from that rule:
    - the card carries the caption "Confirm here; sending a message cancels this proposal";
    - Send drops to a secondary button while a card is live;
    - the agent's message points at Confirm, because a user who types "yes" from habit cancels the card ("Canceled — by your message"), and the agent's next reply must say the proposal was canceled and offer to re-propose.

    Confirming one proposal cancels its siblings on the same entity ("Canceled — a sibling proposal was confirmed"). Stop is not a new turn and cancels nothing.
5. **Expiry.** Proposals live 10 minutes. The countdown is announced to assistive tech once, at 1:00 ("One minute left to confirm"). At 0:00 the card takes the restrained treatment (roles, never opacity — the diff stays readable at AA), its buttons are replaced by the status line "Expired" (which receives focus if a button held it) and **Re-propose** (button-secondary), which asks the agent for a fresh proposal as a new turn (fresh read, fresh diff). The limit is essential to the server-minted, single-use proposal's safety (Accessibility Floor, WCAG 2.2.1); Re-propose is the accommodation. A card restored from a reloaded transcript is always shown expired.
6. **Target changed** (step 7). A fingerprint mismatch on Confirm refuses the write; the status line reads "target changed, re-propose" and receives focus, with the same Re-propose action.
7. **Read-only.** Under enforced, per-user or definition read-only, no card appears: the agent's message says the write was "blocked by read-only mode", what it would have changed and on which screen. Enforced read-only also puts the banner "Read-only mode is enforced on this instance. The agent can read and explain, not change." in every user's panel (`{colors.restrained}`), and the panel's footer line reads "Read-only: on — enforced on this instance". An in-flight turn stops at its next step when the state changes.
8. **Kill switch.** The panel enters its disabled state with the banner "The agent is switched off for <everyone / you>: <reason>." The transcript becomes read-only; the composer and Send stay focusable and `aria-disabled` with the banner's reason. Live proposals can no longer be confirmed: their buttons are replaced by the status line "The agent is switched off", which takes focus when a button held it. Screens keep working.
9. **Audit.** Every confirmed write is marked in the IRIS audit database as coming through the OcuPilot agent co-pilot. If the marker fails to emit, the tool-call card's collapsed line reads "done · audit not marked" and the reply mentions it; if auditing is off, the "Agent writes are not being marked" banner is already showing with its link to Auditing configuration and, for OcuPilot administrators, "Turn auditing on" — enabling auditing is itself a write: through the screen's own toggle and warning, or through propose → review → confirm when asked of the agent.
10. **Polish week.** Adds the copy-out draft ("Give me the script instead" on any card, FR-72) and governance-disabled results ("This tool is disabled by policy", still advertised).

## Privilege Gating

The agent never holds a privilege the user does not (FR-18). The screens gate on the admin API's `%Admin_*` privilege map (FR-4); finer classic gates are not reproduced. Gated controls are never hidden.

**Mechanism** (the accessibility contract; component rows point here). A gated control stays focusable and arrow-reachable with `aria-disabled="true"` — never the `disabled` attribute — and names its reason. Where the control receives DOM focus (rail-item, side-bar entry, area-tile, button), the reason is a tooltip shown on hover and on focus (`aria-describedby`); in the side-bar and the command-box the reason is also visible inline after the label ("Requires %Admin_Secure:USE"). In menus and result lists (row-overflow-menu items, command-box results) Material's key managers skip disabled items and no tooltip can ever show, so gated entries render as non-selectable rows with the reason inline as part of the accessible name (`skipPredicate` overridden so they are announced). The same mechanism serves command-bar actions with nothing selected ("Select a row first") and self-protection refusals.

| Where | Rule |
|---|---|
| Self-protection refusals | The current user, the user's own process, OcuPilot's own web applications, service, resource and role, IRIS system processes and system resources: the action is gated with the explanation as its reason ("This is OcuPilot's own web application."). |
| Wallet | Screen-level: gated entry, and a permission-denied message naming the wallet resource on a deep link. |
| Deep link to a gated route | The screen renders its title and the permission-denied message; the rest of the shell works. |
| 403 on a call | Inline error presentation (`role="alert"`) naming the missing privilege; data already on screen stays. |
| No `%Admin_*` at all | No-administrative-privileges notice with a sign-out link. |
| Agent write tools | The full tool set is advertised; privilege is checked at call time; a 403 is identical to the screen's and the agent reports it without retrying. |
| Agent co-pilot › Definitions and Switches | OcuPilot administrators only (the install-created resource); others see the entries gated with that resource named. The rail-item itself never gates — its attention-dot is the signal. |
| Polish week | Governance policy can disable a tool by policy; it stays advertised and the agent reports "disabled by policy". |

## Voice and Tone

Microcopy. Brand voice and aesthetic posture live in `DESIGN.md`.

| Do | Don't |
|---|---|
| "The instance is unreachable. Check that IRIS is running, then retry." | "Error: connection failed" |
| "You need %Admin_Secure:USE to open Security and secrets." | "Access denied" |
| "Delete /csp/myapp? Type its name to confirm." | "Are you sure?" |
| "No web applications in HSCUSTOM." | "No data" |
| "Showing the first 1,000 rows. Narrow the filter or raise the max rows." | "Results truncated" |
| Second person, sentences not labels, one action per error. | Exclamation marks, "Oops", emoji, "successfully". |
| Agent, first person: "I'm opening Task details for Nightly purge — use Back to return." | "Navigating…" / "The system will now redirect you." / "Taking you to…" |
| Agent, on a 403: "The write was refused: you don't hold %Admin_Secure. I won't retry with other credentials." | "Something went wrong, let me try again." |
| Agent, after a write it verified: "Done. /csp/myapp is enabled with %Development. The list has been refreshed and the row is highlighted. Shall I show you the audit entry?" | "Success! Everything is configured." (unverified) |
| Agent, with a proposal: "I've proposed enabling /csp/myapp with %Development — the card above shows the exact change. Press Confirm on the card to apply it." | "Reply yes to apply." (a typed answer cancels the card) |
| Agent, after a message canceled a live proposal: "Your message canceled the proposal for /csp/myapp. Shall I propose it again?" | Answering "yes" as if the write had happened |
| Test connection failure: "The provider refused the request. Check the key and try again. Provider said: <text>" | The provider's JSON body alone |

**Rules.** UI copy is plain and direct, second person, sentences not labels. Every error says what happened and what to do next (FR-8). Confirmations always name the target. Warnings carry their consequence. The agent speaks in first person, never claims success it did not verify, names the screen it means, and — in Release 1 — names the rows it used in plain text and offers to select them (the navigation tool does the selecting; polish week turns names into click-through chips, FR-71). Rationale and expected impact are always labeled as the agent's text. The message that accompanies a proposal ends "Press Confirm on the card to apply it."; when a message cancels a live proposal, the next reply says so and offers to re-propose. `<user name>` in any string is the login name, as the audit database records it.

**Fixed strings** (verbatim from the PRD and the memlog; do not paraphrase). This table is canonical over `DESIGN.md` and over every inline quotation elsewhere in this document: strings quoted in Component Patterns, State Patterns and Key Flows are illustrations, not second sources. An illustration may resolve a placeholder — as UJ-3 resolves `<user name>` to `_SYSTEM` — but may not respell the string.

| String | Where |
|---|---|
| "no administrative privileges on this instance" | No-administrative-privileges notice (FR-3) |
| "This instance's admin API is version <n>; OcuPilot needs version 2." | Version-mismatch notice (FR-3); `<n>` resolves to the version the instance reports |
| "OcuPilot can't read its own state on this instance, so waiting won't help. An administrator needs to run the install again." | install-state-unreadable notice |
| "blocked by read-only mode" | agent's reply and the write's tool-call card when a write tool is blocked (FR-19) |
| "Agent writes are not being marked. Auditing is off on this instance." · "Auditing configuration" · "Turn auditing on" | panel banner when auditing or OcuPilot's events are off (FR-22); its link (every user); its action (OcuPilot administrators) |
| "target changed, re-propose" | proposal card status line after a fingerprint mismatch (FR-17, step 7) |
| "leaves the instance" · "Screen context is sent to <host>" | context-chip pill when the endpoint host is not private (FR-11); its tooltip |
| "Users, HSCUSTOM · 6 rows" | context-chip screen segment pattern: `<Screen>, <NAMESPACE> · <N rows>` (UJ-1) |
| "Screen context off — nothing from this screen is sent." | context-chip with sharing off |
| "instance unreachable" / "request refused" | error presentation, the two connectivity outcomes (FR-8) |
| "<name> is no longer present on this instance. Return to the list to see what is there now." | a detail view whose target no longer resolves (AD-37) |
| "Signing in…" · "Connected" · "Instance unreachable — retrying" · "Signing in again…" | status-bar connection state |
| "Server" · "Instance" · "Licensed to" | accessible names of the status-bar segments |
| "Explain this screen" | panel one-click action (FR-70, P1) |
| "Test connection" · "Confirm" · "Cancel" · "Save" · "Resume" · "Run" · "Suspend" · "Delete" · "Send" · "Stop" · "New conversation" · "Re-propose" · "Sign out" · "Sign in" · "Retry" · "Open messages.log" · "Refresh" | action names |
| "Agent's rationale" · "Expected impact" | proposal card headings on `{colors.agent-container}` |
| "Reverse:" | proposal card reversal line |
| "Expires in m:ss" · "Proposals expire so a stale diff is never applied." · "One minute left to confirm" | proposal card countdown, from 10:00; its tooltip; the single assistive-tech announcement at 1:00 |
| "Confirm here; sending a message cancels this proposal" · "Runs as <user name>, with your privileges." | live proposal card footer captions |
| "Press Confirm on the card to apply it." | last sentence of the agent's message that accompanies a proposal |
| "Confirmed by <user name> · hh:mm:ss" · "Canceled — by you" / "Canceled — by your message" / "Canceled — a sibling proposal was confirmed" · "Expired" · "The agent is switched off" | proposal card status line, which replaces the buttons and receives focus |
| "N unchanged fields" | proposal card disclosure over the unchanged payload fields |
| "Example — this is what a proposal looks like" | configuration-empty state's static example card |
| "I'm ready. Ask about this screen, or try one of these." · "Click a row to select it; click its name to open it." | panel, Idle with no messages yet — the greeting and the selection hint on a first turn |
| "Stopped by you at <step>" | tool-call card the turn halted on after Stop |
| "The turn stopped at <step>: <reason>." | error banner ending a turn (FR-23) |
| "A turn is in progress. Wait for it to finish before sending another message." | lock banner |
| "I'm opening <screen> for <entity> — use Back to return." · "<title> — opened by the agent; Back returns" | the agent's navigation announcement (FR-16), the one phrasing; the new screen's heading announcement |
| "Shall I show you the audit entry?" | last sentence of the agent's reply after a confirmed write |
| "No agent definition is enabled. Configure one in Agent co-pilot › Definitions." | administrator reminder banner |
| "OcuPilot needs one agent definition before the panel can help. Anthropic is selected — paste a key and press Test connection. You can skip this and browse." | gate landing banner above the Definition form |
| "The agent isn't configured yet. An OcuPilot administrator can enable a definition in Agent co-pilot › Definitions." | configuration-empty state |
| "Read-only mode is enforced on this instance. The agent can read and explain, not change." | enforced read-only banner |
| "The agent is switched off for <everyone / you>: <reason>." | kill-switch banner |
| "Read-only: off" · "Read-only: on — enforced on this instance" / "Read-only: on — for you" / "Read-only: on — by the definition" | panel footer status line, always shown |
| "Open in <screen>" | off-screen change toast link |
| "Auto-refresh: off" · "Auto-refresh: every <n> s" · "Auto-refresh paused — a proposal is awaiting confirmation" · "Last update hh:mm:ss" | command-bar chip states; status-bar stamp; `<n>` resolves to the screen's rate in seconds |
| "Filter rows" | command-bar filter field label |
| "Changed" | tag on a changed row or field (letter case per `DESIGN.md`'s label style) |
| "Requires <resource>" · "Select a row first" | privilege-gated controls (tooltip or inline reason); command-bar actions with no selection |
| "You need <resource> to open <screen>." | permission-denied screen |
| "You need <resource> to <action>." | request-refused inline message (403) |
| "Your privileges couldn't be read, so screens you can't open may be listed. Retry to check again." | shell, after a failed privilege-map read |
| "Type <name> to confirm" · "Does not match" | typed-name-field label; its mismatch message |
| "Stored. Enter a new value to replace it." | masked-secret-field after save |
| "Connected. Reply: <the model's first words>" · "The provider refused the request. Check the key and try again. Provider said: <text>" · "Saved — disabled until Test connection passes." | Test connection result; its failure; Save before a passing test |
| "Saved" · "Go to Home" · "Leave without saving?" | form-page sticky bar; the offer after the first successful definition Save; the unsaved-changes guard |
| "Sign-in failed. Check the user name and password." · "The password for <user> has expired. Change it in the classic portal, or run the command in the README to clear the expiry." · "Your session ended. Sign in to continue." · "You're signed out." · "User name" · "Password" | Form login |
| "Sign-in couldn't reach the instance. Check that IRIS is running, then sign in again." | Form login, when a submit meets an unreachable instance |
| "The Task Manager is suspended — no scheduled task will run until it is resumed." · "The Task Manager is not running — no scheduled task will run until it is started." | Task schedule banner, one sentence per state the Task Manager reports: suspended, and stopped. `Running` raises none |
| "More in the classic portal" | classic-link-card title on reduced forms |
| "The classic portal may ask you to sign in again." | classic-link-card caption (OQ15) |
| "Search screens and commands" · "No screen or action matches." · "<n> screens, <m> actions" | command-box placeholder — the chord is the kbd chip at the field's right edge (`DESIGN.md` › `command-box`), never repeated in the placeholder text; empty result; the polite count |
| "Screens" · "Actions" | command-box result-group labels |
| "Enter to send · Shift+Enter for a new line · Ctrl+I to focus" | composer caption (⌘I on macOS) |
| "Home" · "Logs" · "OS management" · "Tasks" · "Permissions" · "Web applications and REST API explorer" · "Security and secrets" · "Agent co-pilot" | area names on the rail, the rail-item tooltip, the side-bar landmark, the locator-bar eyebrow and the area tiles |
| "<Area> · Ctrl+B toggles the side bar" | rail-item tooltip (⌘B on macOS) |
| "Message to the agent" · "Share screen context" | composer label; context-sharing switch label |
| "Showing the first <n> rows. Narrow the filter or raise the max rows." | data-table at the cap; `<n>` resolves to the max-rows cap (`:389`) |
| "<n> rows" · "Max rows" · "(none)" · "Yes" · "No" | data-table footer row count, which is also the command-bar filter's polite match count (`:389`, `:342`); footer max-rows field label (`:389`, `:610`); empty cell (`:353`, `DESIGN.md:1043`); boolean status cell (`DESIGN.md:1043`, `epics.md` Story 2.5) |
| "Or ask the agent: <a write it could propose here>." | second line of the empty-state on write-capable lists (e.g. "Or ask the agent: create an SSL/TLS configuration for outbound HTTPS.") |
| "Web applications" · "Name" · "Type" · "Enabled" · "Dispatch class" · "Resource" · "No web applications in <NAMESPACE>." · "Open another screen from the command box." | Web applications list side-bar entry and screen title (`:167`); its column headers (`:128`, `epics.md` Story 2.5), with Namespace reusing the namespace switch's accessible name (`:336`); its empty-state title (`:238`) and read-only second line (`:369`) |
| "Users" · "Full name" · "Account expired" · "Roles" · "No users in <NAMESPACE>." | Users list side-bar entry and screen title (`:166`); its column headers beyond the shared Name, Type and Enabled, and its empty state, whose second line is the Web applications row's (`:113`, `epics.md` Story 2.6 AC1-AC2, `:238`) |
| "SSL/TLS" · "Description" · "No SSL/TLS configurations in <NAMESPACE>." | SSL/TLS configurations list side-bar entry and screen title (`:168`); its column header beyond the shared Name, Type and Enabled, and its empty state, whose second line is the Web applications row's (`:135`, `epics.md` Story 2.7, `:238`) |
| "Task schedule" · "Last run" · "Next run" · "No scheduled tasks on this instance." | Task schedule list side-bar entry and screen title (`:165`, `:102`); its column headers beyond the shared Name and Type, with Namespace reusing the namespace switch's accessible name (`:339`); and its empty state, which names the instance because the read is instance-scoped and its rows span namespaces, and whose second line is the Web applications row's (`:238`) |
| "Processes" · "Process ID" · "User" · "Routine" · "State" · "Commands" · "Globals" · "No processes on this instance." | Processes list side-bar entry and screen title (`:164`, `:91`); its column headers, with Namespace reusing the namespace switch's accessible name (`:339`); and its empty state, which names the instance because the read is instance-scoped and its rows span namespaces, and whose second line is the Web applications row's (`:238`) |
| "Sort" · "Ascending" · "Descending" | command-bar sort control's accessible name and its two direction options (`:345`); its field options are the current screen's own column headers, so the control adds no per-column copy, and the chosen state is what the table's `aria-sort` announces (`:610`) |
| "Audit database" · "Time" · "Event source" · "Event type" · "Event name" · "No events match." | Audit database viewer side-bar entry and screen title (`:163`, `:88`); its column headers beyond the shared Description, with User and Process ID reusing the Processes row (`:319`) and Namespace the namespace switch's accessible name (`:339`); and its empty state, which the `list (server criteria)` archetype row names (`:536`) |
| "Begin date and time" · "End date and time" · "Authentication" · "Search" · "Any" · "Comma-separated. * matches any name." · "Instance local time, as YYYY-MM-DD HH:MM:SS." | Audit database viewer criteria form (`:88`, `:536`): the two time-range labels; the authentication label and its unset option; the Search control; and the two helper lines. Its six other field labels are reused keys, the three event ones from the row above |
| "Agent-marked events only" | Audit database viewer agent-marker filter (`:88`) - an affordance, never a default (AD-46) |
| "Audit event" · "Event data" · "Close" | Audit event detail dialog title, its payload label and its sole action (`:89`, `:173`, `:359`); its description label is the shared Description |
| "Application errors" · "Date" · "Errors" · "Error number" · "Error" · "Code line" | Application error log side-bar entry and screen title (`:86`, `:163`); its date level's two column headers; and its error level's column headers beyond Time, Routine, User and Process ID, which reuse the Audit database and Processes rows (`:321`, `:319`), with Namespace reusing the namespace switch's accessible name (`:344`) |
| "No application errors on this instance." · "No application errors in <NAMESPACE>." · "No application errors in <NAMESPACE> on <DATE>." | Application error log empty states, one per drill level: the instance, then the namespace, then the namespace and date; each second line is the Web applications row's (`:315`) |
| "Expressions" · "Stack" · "Variables" · "Expression" · "Value" · "Level" · "Frame" | Application error detail (`:86`): its three section headings and the column headers beneath them, with Name reusing the shared Name (`:315`) |
| "Back" · "This list was cut at the row cap — older entries are not shown." · "This capture was cut at the row cap — some values are not shown." | Application error log control returning from a drill level to the one above it (`:86`); and the two cap notices, one for a drill level whose read was truncated and one for a captured detail that was, neither naming a max-rows control this screen does not carry |
| "That namespace is no longer present in this log. Use Back to see which namespaces are." · "That date is no longer present in this log. Use Back to see which dates are." · "That application error is no longer present in this log. Use Back to see which errors are." · "read this log" | Application error log named refusals (`:86`), one published sentence per refusal the drill read can name: the three drill levels the log no longer carries, each sending the reader to this screen's own Back control (`:328`) rather than to a list; and the action slot the request-refused pattern resolves when the refusal is a privilege denial (`:295`) |
| "What's on this screen, and what should I look at first?" · "Explain the most recent entries in messages.log." · "If you could change one thing on this instance, what would it be, and why?" | Home starter prompts, shown when nothing needs attention |
| "users holding %Development can reach the application" | expected-impact example (UJ-3) |
| "marked as coming through the OcuPilot agent co-pilot" | audit description marker (UJ-3) — the catalog's "via OcuPilot co-pilot" (CP-16) is superseded by the PRD's naming rule |
| "Definitions" · "Provider" · "Model" · "Default" · "No agent definitions yet." · "create a definition for Claude and test the connection" · "Enable" · "Disable" · "Set default" | Definitions list (`:149`): its side-bar entry and screen title (`:169`); its column headers beyond the shared Name and Enabled; its empty state, whose second line is the agent invitation at `:314` resolved by the phrase given here; and its three row actions, the first write-capable row actions in the product |
| "Definition" · "Endpoint" · "API key" · "Advanced" · "Maximum tokens" · "Temperature" · "Maximum iterations" · "System prompt override" · "Retention" · "Create" | Definition form (`:150`): its screen name, the fields above the fold beyond the reused Name, Provider and Model, the collapsed section's own label, the five fields inside it, and the primary action on a create. "Advanced" is the disclosure's accessible name as well as its visible text. **This screen is built and routable but is not a side-bar entry** — it is reached from the Definitions name cell and that list's Create, and `:169` gives Agent co-pilot two entries, not three; a form-page reached from its own list declares that rather than taking a side-bar position, and every later editor does the same |
| "Show key" · "Hide key" · "Transcripts are kept for <n> days." | Definition form: the reveal toggle's two accessible names, which is what makes it labeled rather than an unnamed icon (`:366`); and the retention field's caption, `<n>` resolving to the value in the field |

## Component Patterns

Behavioral. Visual specs live in `DESIGN.md.Components`; Material defaults apply where a rule is silent. Sizes are cited as tokens; the pixel values are in Responsive & Platform. Six components carry more rule than a table cell holds and follow the table as `####` subsections: `command-box` · `data-table` · `panel` · `proposal-card` · `banner` · `form-page`.

| Component | Use | Behavioral rules |
|---|---|---|
| rail | shell, left | `{spacing.rail-width}` icon stack on `{colors.shell}`, eight rail-items in daily-use order, Agent co-pilot pinned to the bottom. Placeholder icons until the owner's icon work lands; every item carries `aria-label` = the area name and the tooltip "<Area> · Ctrl+B toggles the side bar" (⌘B on macOS), shown on hover and on focus. Tab reaches the rail as one stop; Up/Down move between items; Enter or Space activates; the active item carries `aria-current="page"`. Never shows counts. |
| rail-item | one per area | Click opens the side-bar listing the area's screens and does not navigate by itself; clicking the active item collapses the side-bar. States: default · hover · active (current area; indicator per `DESIGN.md`; `aria-current="page"`) · privilege-gated (Privilege Gating: focusable, `aria-disabled="true"`, tooltip "Requires %Admin_Secure:USE" on hover and focus) · attention (Agent co-pilot only). Home is a rail-item too: click navigates to Home. |
| attention-dot | Agent co-pilot rail-item only | `{colors.agent-accent-dark}` dot in both modes (it sits on the chrome). Shown when the agent is unconfigured, the kill switch is on, or a definition needs attention (Test connection failed since the last save). Tooltip and accessible name state the reason. Clears the moment the reason clears. The only badge on the rail. |
| side-bar | primary side bar | Fixed at `{spacing.side-bar-width}`, no drag handle — the panel is the only resizable edge. Lists the area's screens (table above); the current screen is marked selected with `aria-current="page"`. Opens on rail click; collapses on the same click, Ctrl/Cmd+B, or the yield order (Responsive & Platform); stays open across routes until collapsed; open/closed state remembered per browser. Entries the user lacks privilege for stay listed and focusable with the reason inline after the name ("Requires %Admin_Secure:USE") and as a tooltip on focus (Privilege Gating). Arrow keys move; Enter opens; Ctrl/Cmd+B with focus inside the side-bar moves focus to that area's rail-item. |
| header | shell, top | `{spacing.header-height}` band on `{colors.shell}`: logo-lockup left, command-box center, namespace switch right. The namespace switch (accessible name "Namespace") is a select listing only namespaces the user can read and write; choosing one updates the route's `ns` parameter, re-fetches the current screen in that namespace, and updates the context-chip. No URL rewriting into another web application, no dialog. |
| logo-lockup | header, left | `imports/OcuPilot-Lockup-horizontal-reversed.png` — the mark plus the reversed wordmark at 32 px on the navy header; the mark alone where only the mark fits. Click navigates to Home. Accessible name "OcuPilot — Home". The browser favicon is cut from `imports/OcuPilot-Favicon-source.png`; the light-ground lockup `imports/OcuPilot-Lockup-horizontal.png` serves the Form login card and the README. → `imports/OcuPilot-Lockup-horizontal-reversed.png` — the header lockup. |
| command-box | header, center | Opens on click or Ctrl/Cmd+K; typing filters every screen the user may open plus the current screen's command-bar actions; Enter navigates or runs. Not a channel to the agent. → `command-box` below. |
| status-bar | shell, bottom | `{spacing.status-bar-height}` band: server · instance (name and version from `/info`) · user ▾ · licensed-to · server-flag-badge · auto-refresh stamp ("Last update hh:mm:ss" for the current screen when auto-refresh applies; a readout, not a control — the command-bar chip is the control) · connection state ("Connected" / "Instance unreachable — retrying" / "Signing in again…", a polite status on transitions only). The user segment is the account home: a menu behind a ▾ glyph with Sign out (polish week adds Change password and the theme toggle, FR-73). Nothing else in the bar is interactive. |
| server-flag-badge | status-bar; Home instance line | Live / Test / Failover / Development, colored `{colors.server-flag-live}` / `{colors.server-flag-test}` / `{colors.server-flag-failover}` / `{colors.server-flag-development}`; the word is always present, never color alone. Read from `/info`; never editable here. |
| locator-bar | top of content | `nav` named "Breadcrumb": `area › screen › selected entity`, separators `aria-hidden`, the current segment `aria-current="page"`. Each segment navigates: area opens the area's first screen and its side-bar, screen opens the list, entity opens the detail or editor route. The entity segment appears when a row is selected and drops when the selection clears. The namespace is not a segment (it lives in the header). |
| command-bar | below the locator-bar | Holds the screen's actions, view options, sort and search (FR-6): the primary action (Create / Import) left as button-primary; the filter field (a field, not a button; its match count is a polite status); View (General / Free-space, columns or list); sort; the auto-refresh chip on auto-refresh screens; Refresh. Actions act on the selected row; with nothing selected they are `aria-disabled` with the reason "Select a row first" on hover and focus; privilege-gated and self-protected actions per Privilege Gating. Every action here is also reachable from the command-box, and every row-overflow-menu item is here — the command-bar is the always-available path to a row's actions. |
| data-table | every list | CDK virtual scroll over a capped fetch; one click selects the row, the name cell navigates, the whole grid is one Tab stop on the APG grid pattern. → `data-table` below. |
| row-overflow-menu | last cell of every row | "⋮" button (size per `DESIGN.md`). Opens on click, Alt/Option+Down or the `contextmenu` event on the focused row; opening selects the row. Lists the row's actions in command-bar order, destructive actions last. Refused actions (self-protection: current user, own process, OcuPilot's own applications, service, resource and role, system resources) and privilege-gated actions stay listed and arrow-reachable as non-selectable rows with the reason inline after the label — never Material-disabled items, which `mat-menu` skips (Privilege Gating). Escape closes and returns focus to the row (the grid's active descendant). |
| panel | right of every route | Docked right at `{spacing.panel-default}`, resizable and remembered; header with New conversation and the full-screen toggle, then banners, context-chip, transcript and the composer with Send/Stop. No close control. → `panel` below. |
| panel-resize-handle | panel's left edge | Grab strip on the panel's left edge (visuals per `DESIGN.md`), `col-resize` cursor. Drag between `{spacing.panel-min}` and the point where content reaches `{spacing.content-min-width}`. `role="separator"`, `aria-orientation="vertical"`, `aria-valuenow/min/max` in px: focusable, Left/Right arrows change the width by 16 px, Escape releases; the new width is announced through the value. Width persists per browser. |
| context-chip | top of the transcript, whenever a definition is enabled (absent in the configuration-empty state — there is no provider or endpoint to name) | Text: `<Screen>, <NAMESPACE> · <N rows> · <provider> · <endpoint host>`, plus "leaves the instance" in `{colors.egress-warning}` on `{colors.egress-warning-container}` when the host is not on a private network, with the tooltip "Screen context is sent to <host>". Updates on route change, namespace change, selection, and as the viewport's rows change. A switch beside it ("Share screen context") toggles context sharing (default on, remembered per user; an OcuPilot administrator can set the instance default off). Off: the chip reads "Screen context off — nothing from this screen is sent." Secret-typed fields are never included regardless of the toggle. |
| message-user | transcript, right-aligned | The user's text, whitespace preserved, no avatar, no name. Not editable after send. |
| message-agent | transcript, left | avatar-agent beside the text. Sanitized Markdown with code highlighting on `{colors.code-surface}`; images only same-origin or inline; external links are not auto-activated — the full host stays visible and the link opens only on an explicit click (FR-13). First person. Offers ("Shall I select them?" / "Shall I open Task details?" / "Shall I show you the audit entry?") are questions the user answers with the next message — except while a proposal is live, when the message ends "Press Confirm on the card to apply it." and a typed answer cancels the card (Agent Write Lifecycle). A turn-ending error is rendered as a `banner` (error) beside the avatar: "The turn stopped at <step>: <reason>." |
| avatar-agent | beside agent messages, on proposal cards, in the panel header | `imports/robot-avatar.png` (the robot cropped from the logo's docked panel; `imports/robot-avatar-64.png` at small sizes). Accessible name "Agent". Never beside a user message, never decorative elsewhere. → `imports/robot-avatar.png` — the agent mark. |
| tool-call-card | transcript, during and after a turn | One per tool call, appended in order while the turn runs. An expandable disclosure (`<button aria-expanded>`): the running card is expanded, completed cards collapse; click, Enter and Space toggle. Collapsed line: `<tool name and target>` in `{typography.code}` + status: "running" (spinner) · "done" · "done · audit marked" · "done · audit not marked" (`{colors.warning}`, FR-22 — always on the collapsed line, never only in the body) · "failed — <reason>" · "blocked by read-only mode" · "Stopped by you at <step>" (the card the turn halted on after Stop). The status text is part of the accessible name and updates in place. Expanded content: the arguments summary and the result (for a read, the rows returned). The first card appears within 10 seconds of Send (NFR-1). Cards appear in order whether the channel is polling or server-sent events `[ASSUMPTION: OQ17, due 2026-09-09, decides the channel; card behavior is fixed here]`. |
| proposal-card | transcript, after a write tool call | Header with the countdown, diff-rows, rationale and impact, reversal, footer with Confirm/Cancel and its captions; the buttons give way to a status line that takes focus. → `proposal-card` below. |
| diff-row | inside proposal-card | `field · before → after`, computed on the instance from a fresh read (FR-17), never from the agent's text. A delete proposal has no after-state: it shows the target's identifying fields as `field · value → (removed)`, reads "<field>: <value>, removed", and carries no "Reverse:" line, since a delete has no reversal. Accessible rendering "<field>: was <before>, now <after>" (visually hidden "was" / "now"; the arrow `aria-hidden`); unchanged rows read "<field>: <value>, unchanged" and sit under the "N unchanged fields" disclosure. Secret values render as "••••••••" on both sides; empty values read "(none)". Colors and weights per `DESIGN.md`. |
| banner | panel (top), form-pages, Task schedule | Full-width strip with an icon and one sentence, optional link or action; not dismissible while the condition persists, gone the moment it clears. Seven kinds → `banner` below. |
| toast | bottom-right, above the status-bar | Names the change and carries "Open in <screen>" (navigates with the entity selected). Dismiss button on every toast; the region is reachable with Tab after the panel. `role="status"`. Used only for changes to entities whose screen is not open, and for "Saved" from form-pages. Stacking, timings and pausing: Screen Synchronization and Live Data. |
| confirm-dialog | the dialogs listed in Information Architecture › Dialogs | Material dialog, one level deep, never over another dialog. Title names the action and target ("Delete /csp/myapp"); body states the consequence; destructive dialogs carry a typed-name-field and the action button is button-destructive labeled with the verb and target; non-destructive warnings (Suspend Task Manager, disable auditing, disable OcuPilot's web service) use button-primary. Escape and Cancel (button-text) close without effect; focus returns to the opener; Ctrl/Cmd+K, +I and +B are inert while a dialog is open. Initial focus: the typed-name-field, else Cancel. |
| typed-name-field | destructive dialogs; destructive proposal cards (step 7) | Label "Type <name> to confirm". Exact, case-sensitive match enables the destructive button, which is `aria-disabled` until then; paste allowed; a mismatch on blur shows "Does not match" (`aria-invalid`, the message in `aria-describedby`). Enter submits only once the name matches. |
| masked-secret-field | Definition form (API key), Secret form, Set password, proposal cards sending a secret | Password input with a labeled show/hide toggle. Write-only: after save the field is empty and captioned "Stored. Enter a new value to replace it."; the value is never returned. On a proposal card the user fills it at confirmation and the diff never shows it. Key-shape checks per provider flag obvious paste errors inline before Test connection (`aria-invalid` + `aria-describedby`, as `mat-form-field` wires them). |
| button-primary | one per view | Filled `{colors.secondary}`: Save, Create, Confirm, Send, Sign in, Test connection. Shows an inline progress indicator while its request runs and is `aria-disabled` for the duration (focus stays on it); never two primaries in one view — while a proposal card is live, Send drops to button-secondary so Confirm is the view's one primary, and while a turn runs Send reads Stop. |
| button-secondary | alongside a primary | Outlined: View, Back, Re-propose, Load newer, Raw, the classic-link-card action, and Send while a proposal is live. |
| button-text | tertiary and inline | Text button: Cancel beside a primary (proposal card, sticky bar, dialogs), Open in <screen>, Jump to top / bottom, Clear filter, New conversation, "Open ›" in the suggested view, links inside banners. |
| button-destructive | inside confirm-dialog and destructive proposal cards only | Filled `{colors.destructive}`, labeled verb + target ("Delete Nightly purge", "Terminate 4127"). `aria-disabled` until the typed-name-field matches. Never placed in a command-bar or row menu. |
| form-page | every create and edit route | Full-page route, fields in the classic order, sticky Save/Cancel bar; inline and server validation, an error summary that takes focus, an unsaved-changes guard. → `form-page` below. |
| tabs | large editors: user, web application, role, service, SSL/TLS, LDAP; Edit task | Material tabs mirroring the classic tab names. One form across all tabs — Save applies everything; a validation error switches to the tab holding it; a tab holding errors adds ", N errors" to its accessible name (`DESIGN.md` shows the dot). Left/Right move between tabs. |
| stepper | New task wizard | Vertical Material stepper: Basics · Task type and settings · Schedule · Options and notifications `[ASSUMPTION until OQ7]`. Linear: Next validates the current step; Back keeps values; the last step's primary is "Create task"; Cancel returns to Task schedule. The task-type step loads that type's settings fields. A step with an error names it in text (Material's `errorMessage`), never by its circle alone. |
| log-viewer | alerts.log, messages.log; P1 secondary logs | Lines parsed into time · pid · severity-chip · text rows in a data-table. Sticky search field with highlight and "n of N" (a polite status) with next/previous; Jump to top / Jump to bottom; "Load newer" (button-secondary) at the tail; a Raw toggle (button-secondary) swaps to the bounded monospace file view on `{colors.code-surface}` for the loaded range. Never loads the whole file. alerts.log merges the monitor API's recent entries with the history tail. P1 adds an explain entry point per row. Bounded paging and the non-live tail: Screen Synchronization and Live Data. |
| severity-chip | log-viewer rows; Application error log | Tonal chip with the level word (Info / Warning / Severe / Fatal as the source reports it) colored `{colors.info}` / `{colors.warning}` / `{colors.error}`; text always present. Clicking a chip applies that severity as the filter; the command-bar shows the active filter with Clear. |
| meter | System usage, Process details, Database details | Label · value · unit, with the dashboard's own state (normal / warning / alert) shown as a word and colored `{colors.success}` / `{colors.warning}` / `{colors.error}`. Refreshes on the screen's interval; shows "—" with a skeleton until a value arrives; never animates the needle. |
| empty-state | lists, viewers | One `{typography.title}` sentence naming the scope ("No locks in HSCUSTOM."), a second line saying what to do next, and, where one exists, the single primary action ("Create web application"). On write-capable lists the second line invites the agent: "Or ask the agent: create an SSL/TLS configuration for outbound HTTPS." Keyboard hints render as kbd chips (Ctrl/Cmd+K to find a screen; Alt/Option+Down for a row's menu). A 32 px icon per `DESIGN.md`, no illustration. A refused document or a permission-denied screen is not an empty-state — it shows the refusal. Version-mismatch and no-administrative-privileges notices use this shape in the error treatment — `DESIGN.md`'s `banner` error colors applied to the empty state, not a second component stacked above it (`DESIGN.md` `:1066`) — with their link, and announce per Accessibility Floor. |
| skeleton | first load of any screen | Rows at `{spacing.row-height}` in the table's column shape (or field shapes on a form) until the first page arrives (target ≤ 2 s, NFR-1); `aria-hidden` inside a region marked `aria-busy`. Never shown on a re-fetch — refreshes update in place. Static under reduced motion. |
| focus-ring | every interactive element | `{colors.focus-ring}` two-tone ring with `:focus-visible` semantics — shown for keyboard and programmatic focus, never removed with `outline: none`, never replaced by a color change alone; on rail-items, side-bar entries, table rows, cells, chips, cards and buttons. |
| classic-link-card | end of every reduced form | Title "More in the classic portal"; names the classic page it opens; opens in a new tab; a caption notes that the classic portal may ask the user to sign in again (OQ15). Never on a list screen (FR-9). Counts against SM-C1. |
| area-tile | Home | Six tiles in daily-use order in a wrapping grid (Responsive & Platform) — one per contest area; Home is the surface itself and Agent co-pilot is reached from the rail, so neither gets a tile — each captioned with its Release 1 side-bar entries ("Processes · Locks · System usage · Databases · Devices") so the contents are visible on Home. Click or Enter opens the area's first screen and its side-bar. Privilege-gated per Privilege Gating (focusable, `aria-disabled`, tooltip naming the resource on hover and focus). `{rounded.md}`. |

### command-box

*Header, center.* Opens on click or Ctrl/Cmd+K; placeholder "Search screens and commands", with the chord shown once as the kbd chip at the field's right edge (Ctrl+K, ⌘K on macOS). `role="combobox"` input with `aria-expanded`, `aria-controls` and `aria-activedescendant`; results a `role="listbox"` with `role="group"` + `aria-label` for Screens and Actions.

Typing filters every screen the user may open plus the current screen's command-bar actions, matching against each screen's alias list drawn from the contest wording ("web apps", "REST", "x509", "certificates", "CPU", "disks"); a polite status reads "<n> screens, <m> actions" as the filter changes. Enter navigates to the highlighted screen or runs the action; Escape closes and returns focus to where it was. Empty result: "No screen or action matches." (status).

Gated entries stay listed and arrow-reachable as non-selectable rows with the reason inline ("Requires %Admin_Secure:USE") — never Material-disabled items, which the key manager would skip (Privilege Gating). It is **not** a channel to the agent — text never becomes a turn.

### data-table

*Every list.* CDK virtual scroll over rows fetched up to the max-rows cap (default 1,000; persisted per screen with sort and filter). Client-side sort and filter; server-side criteria only where the API searches (Audit database viewer, Task history). Rows `{spacing.row-height}`.

**Selection.** Single selection everywhere in Release 1 (Broadcast's multi-select is P1). One click selects the row, and that row becomes the screen context's selected entity; the name cell is a link to the detail or editor route.

**Keyboard** (APG grid). `role="grid"`, one Tab stop; focus stays on the grid container with `aria-activedescendant` naming the active row or cell, so virtual scroll can never recycle a row that holds focus. The bindings themselves are in Interaction Primitives › *Keyboard model*; moving the active row also selects it.

Selection, sort, filter and scroll survive refresh; deleting the focused row moves focus to the next row, else the empty-state, else the filter. Footer: "N rows · Max rows 1,000", where the cap is an editable, labeled field; at the cap: "Showing the first 1,000 rows. Narrow the filter or raise the max rows." A changed row carries `{colors.change-highlight}` and the "Changed" tag until the next interaction. No page-size control.

### panel

*Right of every route.* `{spacing.panel-default}` default, `{spacing.panel-min}` minimum, remembered per browser; `{spacing.panel-home}` on Home (Responsive & Platform), restoring the remembered width on leaving Home; the width change animates over 120 ms, none under reduced motion. Docked right of every screen; the only resizable edge; **no close control in Release 1**. Route changes keep the panel and its conversation.

**Header row.** avatar-agent · "Agent co-pilot" · **New conversation** · full-screen toggle. New conversation (button-text) starts a fresh conversation on the instance in this tab; the earlier conversation stays in the stored transcript (FR-72) and cannot be reopened in Release 1 — the polish-week Transcripts screen is the history view; like a new turn it cancels every live proposal; while a turn runs it is `aria-disabled` with the reason "Stop the turn first" `[ASSUMPTION]`. The full-screen toggle carries `aria-expanded`; content collapses behind it and is `inert`; the same control restores.

**Body.** Banners, in order: kill switch · enforced read-only · "Agent writes are not being marked" · administrator reminder · lock. Then the context-chip and the transcript (`role="log"`, polite, `aria-label="Conversation"`, `tabindex="0"`; newest at the bottom, scrolls independently).

**Footer.** The read-only status line, always shown ("Read-only: off" or "Read-only: on — …"; the per-user toggle joins it at step 7), the composer (label "Message to the agent"), Send — which mirrors Enter, reads **Stop** while a turn runs and drops to button-secondary while a proposal is live — and the caption "Enter to send · Shift+Enter for a new line · Ctrl+I to focus" (⌘I on macOS). Ctrl/Cmd+I focuses the composer from anywhere, including during a turn.

### proposal-card

*Transcript, after a write tool call.* Anatomy, top to bottom:

- **header row** — avatar-agent · "Proposal · <entity type> <name>" · the countdown "Expires in m:ss" from 10:00, with the tooltip "Proposals expire so a stale diff is never applied.";
- **diff-rows** — changed fields first, then the unchanged fields that the payload still sends, collapsed under the disclosure "N unchanged fields" (every field stays available, FR-17);
- **"Agent's rationale"** and **"Expected impact"** — headings with their text on `{colors.agent-container}`;
- **"Reverse: <how to undo>"** — where a reversal exists;
- **masked-secret-field** where a secret is sent; **typed-name-field** for destructive writes (step 7);
- **footer** — the caption "Runs as <user name>, with your privileges.", **Confirm** (button-primary; button-destructive on a destructive card) and **Cancel** (button-text), and the caption "Confirm here; sending a message cancels this proposal".

While a card is live the composer's Send is demoted to button-secondary. After Confirm, Cancel, expiry, target-changed or the kill switch, the buttons and the countdown are replaced by a status line that receives focus (Accessibility Floor); expired and canceled cards take the restrained treatment, never an opacity fade. Visuals per `DESIGN.md`; lifecycle in Agent Write Lifecycle. → `mockups/direction-bridge.html` — the card in its confirmed state at the UJ-3 climax.

### banner

*Panel (top), form-pages, Task schedule.* Full-width strip with an icon and one sentence, optional link or action. Not dismissible while the condition persists; gone the moment it clears. Seven kinds:

- **lock** (info) — while a turn runs.
- **auditing off** (warning) — "Agent writes are not being marked. Auditing is off on this instance." Every user gets the link "Auditing configuration" (Security and secrets › Auditing); OcuPilot administrators also get the action "Turn auditing on", which opens that screen with the enable control focused. The screen's own toggle and its warning dialog do the write, or the agent does it through propose → review → confirm.
- **administrator reminder** (info) — "No agent definition is enabled. Configure one in Agent co-pilot › Definitions."
- **gate landing** (info, above the Definition form) — "OcuPilot needs one agent definition before the panel can help. Anthropic is selected — paste a key and press Test connection. You can skip this and browse."
- **enforced read-only** and **kill switch** (restrained).
- **Task Manager suspended** (warning, with Resume).
- **form error summary** (error) — receives focus on a failed Save, `role="alert"`, each entry a link to its field.

### form-page

*Every create and edit route.* Full-page route under the locator-bar; fields in the classic order (the Definition form, which has no classic counterpart, puts provider, model, key and Test connection first); a sticky Save/Cancel bar at the bottom (Save = button-primary, Cancel = button-text returns to the list). A reduced form ends with a classic-link-card. Reflows at any width.

**Validation.** Inline on blur and on Save; server rules land on the field they name. On a failed Save the error summary banner receives focus (`role="alert"`) with a link per field; fields carry `aria-invalid` and their message via `aria-describedby`; the first invalid field is then focused and its tab opened; required fields carry `aria-required` and the asterisk has a legend.

**Save destinations.** Save on a create route opens the new entity's editor; Save on an edit route keeps the editor open, shows "Saved" (`role="status"`) in the sticky bar and the list reflects the change on return `[ASSUMPTION: save destination]`; the first successful definition Save adds "Go to Home" beside it.

**Leaving.** Navigating away with unsaved changes asks "Leave without saving?" `[ASSUMPTION: unsaved-changes guard]`; agent navigation waits for the same answer.

## State Patterns

Trigger · what the user sees · exit. Every state in PRD §5 and every user-facing session state from the auth spike appears once; the Session table is the authority for sign-in, and the Shell table keeps only the sign-in states with a distinct visual.

### Shell and screens

| State | Surface | Trigger | What the user sees | Exit |
|---|---|---|---|---|
| Silent login in progress | shell | any route load with no token in the tab | shell chrome on `{colors.shell}`, content skeleton, status-bar "Signing in…"; nothing else on screen is authoritative until the probe resolves | 200 → the requested route; 401 → Form login |
| Form login | shell | silent login 401 · failed refresh · after Sign out | centered card with the light lockup (`imports/OcuPilot-Lockup-horizontal.png`), user name, password, Sign in (button-primary); a rejected attempt keeps the user name, clears the password and reports "Sign-in failed. Check the user name and password." under the fields (`role="alert"`); the intended route is preserved and restored after sign-in | 200 → intended route |
| Expired password | Form login | the server's expiry error | "The password for <user> has expired. Change it in the classic portal, or run the command in the README to clear the expiry." with the classic-portal link (UJ-5). "The README" renders as words rather than a link until the repository is public on 2026-09-24: before then the URL answers 404 for every reader but its owner, and hard-coding it puts the owner's account name in every shipped bundle (decided 2026-09-13, DW-166). The link returns on release day. `[NOTE FOR ARCHITECTURE]` a fresh Community container expires `_SYSTEM`'s password on first login, so a user following the README meets this state first; consider unexpiring it at install (the project's own CLAUDE.md carries the one-liner) so the first screen never sends the user to the classic portal | password changed → sign in |
| Version mismatch | shell | `/info` absent or `apiVersion` ≠ 2 | blocking notice (empty-state shape in the error treatment — see `empty-state` in Component Patterns) naming the mismatch ("This instance's admin API is version 1; OcuPilot needs version 2.") and a link to the classic portal; the rail, side-bar and command-box are inert; no area screen loads | none in-app |
| No administrative privileges | shell | privilege map holds no `%Admin_*` | "no administrative privileges on this instance" (empty-state shape in the error treatment — see `empty-state` in Component Patterns) and a sign-out link; never presented as a version mismatch | Sign out |
| Install state unreadable | shell | any call answers 503 `INSTALL.UNREADABLE` | blocking notice (empty-state shape in the error treatment — see `empty-state` in Component Patterns) reading "OcuPilot can't read its own state on this instance, so waiting won't help. An administrator needs to run the install again." (`role="alert"`) with Retry and Sign out; no "Signing in…" and no automatic retry | Retry re-checks once |
| Privilege-gated entry | rail, side-bar, area-tile, command-box, command-bar, row menu | route or action outside the privilege map | the control stays listed and focusable with `aria-disabled="true"` and the reason "Requires <resource>" as a tooltip on hover and focus, or inline where a tooltip cannot show (Privilege Gating) | privilege granted → next load |
| Wallet without its resource | Wallet collections | deep link or side-bar with no wallet resource | the screen renders its title and a permission-denied message naming the resource; no table | — |
| Loading first page | every list, detail, viewer | route entered | skeleton (≤ 2 s target) | data → table; error → error presentation |
| Empty | lists | zero rows in scope | empty-state | rows appear / filter cleared |
| Async values arriving | Databases list, Free-space view | rows shown before `/database-dir/info` returns | per-row skeleton cells filling as each figure lands → Screen Synchronization and Live Data | all figures in |
| Refused document | OpenAPI document viewer | `/api/mgmnt` refuses the spec | the refusal text in place of the browser, with the resource or reason it gave | — |
| Instance unreachable | any call | connectivity probe fails | one banner (`role="alert"`) at the top of content: "The instance is unreachable. Check that IRIS is running, then retry." with Retry; status-bar "Instance unreachable — retrying" | probe succeeds |
| Request refused | any call | 403 | inline message (`role="alert"`) naming the missing resource with the action ("You need %Admin_Manage:USE to terminate processes."); the screen's data stays | — |
| Generic internal error | any call | 5xx / exception | "Something failed on the instance. Retry; if it keeps failing, check messages.log." (`role="alert"`) with Retry and Open messages.log | Retry |
| Auto-refresh off | auto-refresh screens | default | chip "Auto-refresh: off"; stamp shows the last manual load | user turns it on |
| Auto-refresh on | auto-refresh screens | user sets a rate | chip "Auto-refresh: every 10 s"; status-bar stamp ticks silently (never announced); sort, filter, selection unchanged by each tick | off / route change keeps the persisted setting |
| Auto-refresh paused | auto-refresh screens | a proposal on this screen's entity type is live | chip "Auto-refresh paused — a proposal is awaiting confirmation" → Screen Synchronization and Live Data | proposal resolved or expired |
| Row selected | lists | click / arrow keys / agent selection | row in the selected treatment; locator-bar gains the entity segment; context-chip updates; command-bar actions enable | click elsewhere, Escape, deletion |
| Changed (highlighted) | lists, details | change event for the visible entity | the row or field on `{colors.change-highlight}` with the "Changed" tag, settling to its resting tint `[ASSUMPTION: settle timing]` → Screen Synchronization and Live Data | next interaction with that row or field |
| Off-screen change toast | shell | change event for an entity whose screen is not open | a toast naming the change ("Enabled /csp/myapp") with "Open in Web applications" → Screen Synchronization and Live Data | dismiss / timeout `[ASSUMPTION]` / click |
| Confirmation dialog | area screens | delete, terminate, remove locks, set password, grant | confirm-dialog naming the target; destructive ones with the typed-name-field | Confirm / Cancel / Escape |
| Warning before a write | Task schedule, Auditing configuration, Service editor | Suspend Task Manager · disable auditing · disable OcuPilot's web service | confirm-dialog carrying the consequence sentence | Proceed / Cancel |
| Reduced form | cut large editors | editor shipped reduced (FR-9) | the daily-administration fields, then a classic-link-card | — |
| Gate landing | Definition form | opened by the first-login gate | the gate landing banner above the form; provider, model, key and Test connection first; on the first successful Save the sticky bar offers "Go to Home" | Save · leaving |
| Task Manager suspended | Task schedule | the Task Manager is suspended | warning banner above the table "The Task Manager is suspended — no scheduled task will run until it is resumed."; rows still list. The Resume control (privilege-gated per Privilege Gating) ships with Epic 7 (FR-51), because Epic 2 has read tools only | Resume (Epic 7) |
| Test connection | Definition form | Test connection pressed | button in progress → "Connected. Reply: <the model's first words>" (`role="status"`) or "The provider refused the request. Check the key and try again. Provider said: <text>"; the definition stays disabled until a test passes after any provider, endpoint or credential change; Save before a passing test shows "Saved — disabled until Test connection passes." in the sticky bar | Save |
| Width yield | shell | rail + side-bar + content-min-width + panel exceed the viewport | the yield order (Responsive & Platform): the side-bar auto-collapses, then the panel shrinks toward `{spacing.panel-min}`, then content scrolls horizontally inside the content region; below ~900 px this is the squeeze rule | width restored (undone in reverse) |

### Panel

| State | Trigger | What the user sees | Exit |
|---|---|---|---|
| Configuration-empty | no enabled definition; user is not an OcuPilot administrator | transcript area shows "The agent isn't configured yet. An OcuPilot administrator can enable a definition in Agent co-pilot › Definitions." and, beneath it, a static example proposal card labeled "Example — this is what a proposal looks like" (the UJ-3 card in its live state with no buttons and no countdown) above three sentences: it reads with your privileges; it proposes and you confirm; every write is marked in the audit database. The composer stays focusable, `aria-disabled` with that reason; attention-dot on | a definition is enabled |
| Administrator reminder | no enabled definition; user is an OcuPilot administrator who left the gate | banner "No agent definition is enabled. Configure one in Agent co-pilot › Definitions." on every screen, plus the same example card; the composer focusable and `aria-disabled` with the banner's reason | a definition is enabled |
| Idle, no messages yet | definition enabled, transcript empty (first turn in this conversation) | the context-chip, then "I'm ready. Ask about this screen, or try one of these." over the screen's three starter prompts, and beneath them the hint "Click a row to select it; click its name to open it." so the selection model is learnable without the README | Send · a starter prompt · New conversation |
| Idle with context | definition enabled, no turn running | context-chip (on / off / with "leaves the instance"), transcript, input focused on Ctrl/Cmd+I | Send |
| Home suggested view | on Home | "Suggested view" block above the transcript: attention lines — tasks suspended after an error · application errors today per namespace · new alerts.log entries · agent status (definition, read-only, kill switch) — each a button distinct from its "Open ›" link; activating a line places its text in the composer as a prompt for the user to send `[ASSUMPTION: suggested-view content and gesture]`. When every attention line would be zero the block shows three starter prompts instead (the three Home starter prompts in *Fixed strings*), with the same gesture; the agent-status line stays | leaving Home |
| Busy | Send | message-user appended; tool-call cards appear in order, the first within 10 seconds of Send (NFR-1), the running card expanded; Send reads **Stop** and keeps focus; the composer stays focusable and editable (`aria-disabled`, reason "A turn is in progress"); New conversation `aria-disabled` | final reply / error banner / Stop |
| Locked | Enter (or a queued Send) while a turn runs | lock banner "A turn is in progress. Wait for it to finish before sending another message."; the typed text is kept in the composer; focus does not move | turn completes |
| Stopped by you | Stop pressed while Busy | the turn halts at its next step; the card it halted on reads "Stopped by you at <step>"; no reply follows; Send returns, focus still on it; a proposal already posted in that turn stays live — Stop is not a new turn `[ASSUMPTION]` | next Send |
| New conversation | the panel-header control | the transcript clears to a fresh conversation on the instance; every live proposal is canceled ("Canceled — by you") exactly as a new turn would; the context-chip is unchanged; the earlier conversation stays in the stored transcript (FR-72) with no way to reopen it in Release 1 | Send |
| Error banner | provider timeout / unreachable / rate-limited after retries | banner (error) beside the avatar "The turn stopped at <step>: <reason>." naming which step timed out (FR-23); Send returns and keeps focus | next Send |
| Proposal live | write tool called | proposal-card with Confirm/Cancel, the countdown and its captions → Agent Write Lifecycle 1–2 | Confirm / Cancel / expiry / new turn / New conversation |
| Proposal confirmed | Confirm succeeded | the status line "Confirmed by <user name> · hh:mm:ss" in place of the buttons → Agent Write Lifecycle 3 | — |
| Proposal canceled | Cancel · new turn or New conversation · sibling on the same entity confirmed | the restrained card with a "Canceled — …" status line → Agent Write Lifecycle 4 | — |
| Proposal expired | countdown reaches 0:00 · transcript restored from reload | the restrained card with the status line "Expired" and Re-propose → Agent Write Lifecycle 5 | Re-propose |
| Target changed (step 7) | fingerprint mismatch on Confirm | the status line "target changed, re-propose" with Re-propose → Agent Write Lifecycle 6 | Re-propose |
| Destructive proposal (step 7) | write tool is destructive | a typed-name-field inside the card, Confirm button-destructive → Agent Write Lifecycle 2 | match → Confirm |
| Secret in proposal | payload contains a secret field | a masked-secret-field inside the card, the diff masked → Agent Write Lifecycle 2 | filled → Confirm |
| Read-only blocked result | write tool under enforced, per-user or definition read-only | no card; the agent's message says the write was blocked and where → Agent Write Lifecycle 7 | read-only lifted |
| Enforced read-only indicator | Switches › enforced read-only on | the enforced read-only banner in every user's panel and the matching footer line → Agent Write Lifecycle 7 | switch off |
| Kill switch (disabled) | Switches › kill switch on, global or for this user | the kill-switch banner; the panel in its disabled state; screens keep working → Agent Write Lifecycle 8 | switch off (next turn) |
| "Agent writes are not being marked" | auditing or OcuPilot's events off | banner "Agent writes are not being marked. Auditing is off on this instance." to every user, linking to Auditing configuration; OcuPilot administrators also get "Turn auditing on" | auditing on |
| Audit-emission failure | ledger row records the failure | the write's tool-call card reads "done · audit not marked" in `{colors.warning}` on its collapsed line; the agent's reply mentions it | — |
| Secret-like message warning | on a screen with secret-typed fields, the draft looks like a password or key | inline warning above the input "This looks like a password or key. Send anyway?" with Send anyway / Edit | either |
| Agent announcing navigation | navigation tool called | message-agent "I'm opening <screen> for <entity> — use Back to return." is committed to the log first; the route changes after the announcement has been dispatched (about 1 s); the new screen's heading takes focus and its announcement reads "<title> — opened by the agent; Back returns" | browser Back |
| Transcript restored | panel opened / page reloaded | the current conversation's prior turns loaded; every proposal card shown expired; no running cards | Send |
| Token expired mid-turn | access token lapses during a 60–90 s turn | nothing — the turn must complete without an authentication failure (FR-18, OQ17) | — |
| Full screen | full-screen toggle | the panel fills the app area below the header (the hidden content is `inert`); the same control restores; width unchanged on restore | toggle |

`[NOTE FOR PRD]` step 7's per-user turn limits have no user-facing state or string yet — the panel needs a "turn limit reached" banner and the refusal sentence before that step ships.

### Session (auth spike states 1–10 and 13; 11, 12 and 14 have no user-facing state in Release 1)

| # | State | Trigger | What the user sees | Exit |
|---|---|---|---|---|
| 1 | Cold start, silent probe in flight | load | shell chrome, skeleton, "Signing in…" | 2 or 3 |
| 2 | Silently signed in | probe 200 (classic-portal user, returning tab) | no form; the route | — |
| 3 | Sign-in form shown | probe 401 | Form login, route preserved | 5 |
| 4 | Form rejected | 401 on credentials | "Sign-in failed. Check the user name and password." under the fields (`role="alert"`); the expired-password variant | 5 |
| 5 | Signed in, token fresh | pair stored per tab | normal operation; one Bearer for every JWT-enabled API | 6 |
| 6 | Access token expiring (60 s) | timer at exp − iat − 10 s, or any 401 | nothing; refresh-and-retry once, invisible | 5 or 7 |
| 7 | Refresh failed (900 s idle or revoked) | refresh 401 | the shell runs the silent probe once more before showing the form `[ASSUMPTION: silent retry before the form]`; then Form login with "Your session ended. Sign in to continue." and the route preserved | 2 or 3 |
| 8 | Signed out by OcuPilot | Sign out | Form login with "You're signed out."; tab storage cleared; classic portal and embedded editors signed out too | 3 |
| 9 | Signed out elsewhere | classic `?IRISLogout=end` in another tab | discovered on the next call: same as 7 | 7 |
| 10 | Bearer-only logout elsewhere | another JWT app revoked this sid | same as 7; the silent retry usually succeeds because the session cookie can still mint a fresh pair | 2 |
| 13 | Privilege-denied | no `%Admin_*` · route outside the map · 403 on a call | notice · disabled-with-tooltip · inline 403 naming the resource | — |

### Surface × state matrix

Which states each archetype (the IA table's Archetype column; each key appears in exactly one row below, and one row covers the three form keys together) must show. `shell` takes its states from the Shell and Session tables; `external` opens a new tab and has none here. Exceptions follow.

| Archetype | cold-load | empty | error | permission-denied | refreshing | selected | changed |
|---|---|---|---|---|---|---|---|
| list | skeleton | empty-state | inline error presentation, data kept | screen-level message (Wallet) or disabled entry | in place, no skeleton; chip + stamp | row selected, locator segment | row highlight |
| list (two views) | per view | per view | as list | as list | as list | as list | as list |
| list (server criteria) | criteria form first, skeleton on Search | "No events match." | as list | as list | manual Search only | row → detail dialog | — (read-only data) |
| detail | skeleton fields | — (always an entity) | error presentation, last values kept | 403 message | auto-refresh in place | — | field highlight |
| meters | skeleton per meter | — | per meter "—" with the error in its tooltip | 403 message | interval | — | — |
| form-page · form-page (tabs) · wizard | skeleton fields | — | field-level and sticky-bar errors | 403 on Save names the resource | — | — | "Saved" then highlight on return |
| log-viewer | skeleton rows | "No entries." / "No matches." | error presentation | 403 message | Load newer only | row | — |
| drill-down | skeleton at each level | "No errors in <scope>." | error presentation | 403 message | manual | row | row removed after delete |
| viewer (OpenAPI) | skeleton | refused-document state | error presentation | refused-document state | manual | path row | — |
| dialog | — | — | inline error, dialog stays open | action disabled with tooltip before opening | — | — | — |
| home | skeleton tiles | starter prompts in the panel when nothing needs attention | error presentation in the instance line | tiles gated | suggested view refreshes with the panel | — | — |
| panel | transcript skeleton | configuration-empty with the example card | error banner | kill switch / read-only banners | cards in order | — | — |

Exceptions: Databases list adds *async values arriving*; OpenAPI document viewer shows a refusal, never an empty view; Audit database viewer and Task history search on the server and do not auto-refresh; OAuth 2.0 renders its five lists as tabs of one screen whose archetype is `detail` — `epics.md` `:3325` and `prd.md` `:698` (FR-44) both call the tabs detail views, and AD-44's single Release 1 classic-link exemption is declarable only on a detail view, so a `list` archetype here would refuse the exemption the spine says exists (decided 2026-09-13, DW-179); Auditing configuration embeds the system- and user-event lists (each a `list`) beneath its form and, with Service editor, adds the warning dialogs; Task schedule adds the *Task Manager suspended* banner; Switches and Definitions render for non-administrators as gated side-bar entries naming the OcuPilot administrator resource; the Agent co-pilot rail-item never gates (its attention-dot is the signal).

## Interaction Primitives

**Keyboard model — VS Code-shaped.**

| Keys | Where | Effect |
|---|---|---|
| Ctrl/Cmd+K | anywhere (inert while a dialog or the command-box overlay is open) | open the command-box |
| Ctrl/Cmd+I | anywhere (same) | focus the composer, including during a turn |
| Ctrl/Cmd+B | anywhere (same) | toggle the side-bar; with focus inside it, focus moves to the area's rail-item |
| Escape | panel, command-box, side-bar, menus, dialogs | close the topmost overlay, else return focus to the screen (the last focused element in content) |
| Enter | composer | send the turn; while a turn runs, show the lock banner (the draft is kept) |
| Shift+Enter | composer | newline |
| Up / Down · Home / End · PageUp / PageDown | data-table | move the active row (the selection, and the screen context's entity) |
| Right / Left | data-table row | step into the row's cells (name link, chips, ⋮) and back |
| Enter | data-table row | open the detail or editor route |
| Alt/Option+Down · the `contextmenu` event (Shift+F10, the menu key, VO+Shift+M, right-click) | data-table row | open the row-overflow-menu |
| Enter / Space | tool-call-card | expand or collapse |
| Left / Right | tabs; panel-resize-handle | switch tab; resize by 16 px |
| Tab / Shift+Tab | everywhere | reading order: skip link → header → rail → side-bar → content → panel → toasts; a data-table is one stop |

**Mouse.** Click acts. One click selects a row; the name cell navigates; right-click on a row opens the row-overflow-menu. Hover reveals nothing that the keyboard cannot reach. Double-click has no meaning. No drag except the panel-resize-handle — the side-bar is fixed.

**Refresh.** Auto-refresh chip (off / rate) on the screens that support it; Refresh action on every list; the browser's own reload is never intercepted. Refresh never resets sort, filter, selection or scroll.

**Undo by Back.** Agent navigation is a normal history entry: the browser Back button returns to the previous screen with its selection. No in-app undo control.

**Confirmation gestures.** A proposal is confirmed only by its own Confirm button (no batch, no keyboard shortcut that confirms the newest card, no typed "yes" — a message cancels the card). A delete is confirmed only in its dialog after the typed name. Enter inside a typed-name-field submits only once the name matches.

**Banned everywhere:** popups and new windows (the classic-link-card and OAuth classic editor links open a new tab, nothing else does) · modal stacks · batch approval of proposals · hover-only affordances · infinite scroll (virtual scroll over a capped fetch is not infinite) · page-size controls · confirming a proposal for the user, whether by auto-confirmation or by any confirmation the user did not make · rewriting the URL into another web application on namespace change · natively disabling or removing a control while it holds focus.

## Screen Synchronization and Live Data

This section is authoritative for live-data behavior — change events, highlights, off-screen toasts, auto-refresh, asynchronous values and log paging. State Patterns rows and Component Patterns cells that touch it state the trigger and point here.

- **Change event → re-fetch in place.** A confirmed write emits `(entity type, id, action)`. The active screen, if it shows that entity type, re-fetches without a skeleton and keeps sort, filter, selection and scroll (FR-14).
- **Highlight.** The changed row or field takes `{colors.change-highlight}` and the "Changed" tag within 2 s of the write completing and is scrolled into view; the highlight settles to its resting tint over 2 s and holds until the next interaction with that row or field `[ASSUMPTION: settle timing]`. A deleted row leaves the list; if it was selected, the selection and the locator segment clear. A created row appears highlighted and selected.
- **Off-screen toast.** When the affected screen is not open, a toast names the change ("Resumed Nightly purge") with "Open in <screen>", which navigates with the entity selected. Toasts stack at most three deep, newest on top, and a fourth drops the oldest (the row highlight and the transcript keep the record). A toast without an action persists for 10 seconds, or until it is dismissed; a toast carrying "Open in" persists for 30 seconds `[ASSUMPTION: timings]`; the timer pauses while any toast is hovered or focused. The agent's reply names the same change, so nothing is lost when a toast expires. A screen editor's own Save publishes to the same event bus, so the open screen updates as it does after an agent write; the bus does not cross tabs, so a list open in another tab is not updated.
- **Auto-refresh controls.** On Processes, Databases, Database details, Task schedule, Task details, System usage: the command-bar chip switches between off and a rate from a short fixed list `[ASSUMPTION: 5 s · 10 s · 30 s · 60 s; default off, the classic precedent]`; the status-bar stamp shows the last update. Setting, sort, filter and max rows persist per screen. Refresh is silent — no spinner, no skeleton, no announcement.
- **Pause under an open proposal.** While a proposal on that screen's entity type is live, auto-refresh pauses and the chip says so, so the diff under review does not move; it resumes when the proposal is confirmed, canceled or expires.
- **Async values.** Database free-space figures arrive per row from the asynchronous directory call and fill their skeleton cells as they land, and the table never reflows; meters show "—" until their first value.
- **Tail, not live.** Log viewers load bounded pages and offer "Load newer"; nothing streams in Release 1 (live tail is P2).

## Session and Sign-in

→ Screens: `mockups/key-signin-gate.html` — form login, the expired-password state with both links, and the first-login gate's Definition form with Test connection passing and refusing.

Silent-first (Design A of the auth spike). The Session table in State Patterns is the authority for the states; this section adds only what it does not carry.

- **Silent retry before the form.** When a refresh fails, the shell runs the silent probe once more before showing the form `[ASSUMPTION: silent retry before the form]`.
- **Values lost on a failed refresh.** An in-progress form's values are lost (the unsaved-changes guard cannot help here); after re-sign-in the toast "Your unsaved changes were not kept." is shown `[ASSUMPTION]`.
- **First-login gate.** An OcuPilot administrator signing in while no definition is enabled is redirected to Agent co-pilot › Definitions with the Definition form open under the gate landing banner; provider, model, key and Test connection come first. They may leave: the administrator reminder banner stays in the panel on every screen until one definition is enabled; it carries a link, cannot be dismissed, and goes the moment the condition clears. On the first successful Save the sticky bar offers "Go to Home". Non-administrators see the configuration-empty state naming who can configure it.

## Accessibility Floor

Behavioral. WCAG 2.1 AA and keyboard are the floor (NFR-12, D10); contrast values live in `DESIGN.md`.

- **Landmarks.** A "Skip to content" link is the first Tab stop. header = banner; rail and side-bar = navigation (named "Areas" and "<Area> screens"); locator-bar = navigation "Breadcrumb"; content = main; panel = complementary named "Agent co-pilot"; status-bar = contentinfo; toasts = a status region.
- **Focus order.** skip link → header → rail → side-bar → content (locator-bar, command-bar, the table as one stop) → panel → toasts. Ctrl/Cmd+I focuses the composer; Escape returns to the last focused element in content; Ctrl/Cmd+K moves focus to the command-box and Escape returns it. Dialogs trap focus and return it to the opener. Route changes move focus to the new screen's heading and announce its title.
- **Focus destinations.** No control is disabled or removed while it holds focus without a named destination. After Send, focus stays on the Send/Stop control, which is never natively disabled (`aria-disabled` semantics apply wherever a control cannot act); when the reply arrives a status message announces it and focus stays put. After Confirm, Cancel, expiry, target-changed or the kill switch, a proposal card's buttons are replaced by its status line (`tabindex="-1"`), which receives focus and is announced; buttons that go away are `aria-disabled` for the transition, never removed while focused. Ctrl/Cmd+I during a turn focuses the composer, which stays focusable while locked (`aria-disabled="true"`, the reason "A turn is in progress" in its description). Ctrl/Cmd+B with focus inside the side-bar moves focus to that area's rail-item. Deleting the focused row moves focus to the next row, else the table's empty-state, else the filter. Ctrl/Cmd+K, +I and +B are ignored while a dialog or the command-box overlay is open — close it with Escape first.
- **Status messages (WCAG 4.1.3).** The transcript is `role="log"` (polite, `aria-label="Conversation"`, `tabindex="0"`), so the agent's reply, each tool-call card and each proposal are announced by construction and a card's status change is a text update. Polite `role="status"`: the Test connection result, "Saved", the search "n of N", the filter count, the command-box count, the toast region, the change highlight ("Updated: <entity> <action>"), the lock banner, the signed-out and session-ended banners on the Form login card, and the connection-state segment on transitions only. `role="alert"` (or focus moved to it): the sign-in failure, the instance-unreachable banner, the generic error, a 403, the form error summary, and the blocking instance notice — which, because it replaces the whole product surface rather than carrying a message within one, additionally opens with the page heading and takes focus on appearance. The countdown is announced once, at 1:00 ("One minute left to confirm"), never per second, and is otherwise not live; the auto-refresh stamp and refresh ticks are never announced. Kill-switch and enforced read-only banners are assertive on appearance. Agent navigation: the announcement is committed to the log, the route changes after it has been dispatched (about 1 s), and the new heading's announcement reads "<title> — opened by the agent; Back returns".
- **Gated controls stay reachable.** Privilege Gating › *Mechanism* is the full statement: `aria-disabled="true"` in the Tab and arrow-key order, never the `disabled` attribute, with the reason always announced.
- **Tables.** `role="grid"`, one Tab stop; focus stays on the grid container with `aria-activedescendant`, so virtual scroll and in-place re-fetch never drop it; the bindings are in Interaction Primitives › *Keyboard model*. Selection and sort state are announced. The command-bar carries every row action for the selection — the always-available path.
- **Command box.** `role="combobox"` with `aria-expanded`, `aria-controls` and `aria-activedescendant`; results `role="listbox"` grouped by `role="group"` + `aria-label`; the count and "No screen or action matches." as a polite status.
- **Forms.** On a failed Save the error summary banner receives focus (`role="alert"`) with a link per field; server errors set `aria-invalid` and the message via `aria-describedby`, then the first invalid field is focused (its tab opened); custom fields (typed-name, masked-secret, the filter, max rows) replicate `mat-form-field`'s wiring; required fields carry `aria-required` and the asterisk has a legend; a tab with errors adds ", N errors" to its name; a stepper error step names the error in text.
- **Names, roles, glyphs.** Rail-items carry `aria-label` = area name and `aria-current="page"` when active (so do the active side-bar entry and locator segment); panel-resize-handle is `role="separator"` `aria-orientation="vertical"` with `aria-valuenow/min/max`; the full-screen toggle has `aria-expanded` and the hidden content is `inert`; tool-call cards are `<button aria-expanded>` with the status in the name; skeletons are `aria-hidden` inside an `aria-busy` region; "●", "→", "›" and "·" are `aria-hidden`; suggested-view lines and starter prompts are buttons distinct from "Open ›"; the max-rows field is labeled; masked fields' show/hide toggles are labeled; the composer is "Message to the agent", the context switch "Share screen context"; every icon-only control is named.
- **Time limits (WCAG 2.2.1).** The 10-minute proposal expiry is essential to the security model: a proposal is server-minted, single-use and fingerprinted, and extending it would confirm a stale diff. Re-propose (a fresh read and diff) is the accommodation; the countdown and the running spinner are auto-updating content under the same essential exception (2.2.2). Toasts pause while hovered or focused and action toasts last 30 s; the agent's reply names the same change. `[NOTE FOR ARCHITECTURE]` the interval is a server-side constant; a per-instance setting for it is a Switches candidate for polish week.
- **Keyboard shortcuts.** No single-character shortcuts exist, so 2.1.4 does not apply. The app captures Ctrl/Cmd+K, +I and +B (`preventDefault`) only while it has focus — on macOS ⌘K and ⌘I have no Chrome default and ⌘B none either, and on Windows/Linux Chrome's Ctrl+K is overridable; Firefox binds all three (search, page info, bookmarks) and is best effort (NFR-11). The conflict is acceptable only because the app captures the chords while focused and shows them on screen (command-box placeholder, composer caption, rail tooltips).
- **Reduced motion.** The highlight appears and disappears with no settle; skeletons are static; spinners are replaced by the word "running"; the panel width does not animate.
- **Target sizes.** Every control at least 24 × 24 CSS px; rail-items 48 × 48; the row-overflow-menu trigger 28 × 28 CSS px (per `DESIGN.md`); table rows `{spacing.row-height}` with the whole row as the selection target.
- **Zoom and reflow.** Form-pages, banners, the transcript and the proposal card reflow at any width; only data-tables, the raw log and code blocks claim the two-dimensional exception (1.4.10). The panel's full-screen toggle is the zoom accommodation for the transcript. Row heights are minimums outside virtualized lists (`DESIGN.md`).
- **Color never alone.** Server flag, severity, meter state, changed rows, "leaves the instance", diff direction ("was" / "now") and proposal states all carry a word or tag.

## Responsive & Platform

Header `{spacing.header-height}` (48 px) · status-bar `{spacing.status-bar-height}` (24 px) · rail `{spacing.rail-width}` (48 px) · side-bar `{spacing.side-bar-width}` (240 px when open, fixed) · content never below `{spacing.content-min-width}` (640 px) · panel `{spacing.panel-default}` (400 px) remembered, `{spacing.panel-min}` (320 px) minimum · on Home `{spacing.panel-home}` = min(50vw, viewport − rail − content-min-width).

**Yield order.** Whenever rail + side-bar + content-min-width + panel exceed the viewport, concessions are taken in this order and undone in reverse as width returns: (1) the side-bar auto-collapses (its remembered state is kept; the user may reopen it, which takes the next concession); (2) the panel shrinks toward `{spacing.panel-min}`, only as far as needed; (3) content scrolls horizontally inside its region. The header, rail and status-bar never scroll; nothing overlays, nothing becomes a bottom sheet, the panel never auto-collapses.

| Viewport | Behavior |
|---|---|
| ≥ 1,280 px | Full shell: rail, side-bar (if open), content, panel at its remembered width. The yield order applies only when the side-bar is open and the panel is wider than the space allows (at 1,280 px, any panel over 352 px). |
| 900–1,279 px | The yield order, continuously. |
| < ~900 px | The squeeze rule, like VS Code: the panel holds `{spacing.panel-min}`, content shrinks to `{spacing.content-min-width}` and then scrolls horizontally inside the content region. |

**Home.** The six area-tiles are a wrapping grid, not a fixed row, so Home needs no width beyond content-min-width; the panel takes `{spacing.panel-home}`, the change animated over 120 ms (none under reduced motion).

| Viewport | Screen (panel remembered at 400) | Home (`{spacing.panel-home}`) |
|---|---|---|
| 1,280 px | Side-bar open would leave 592 → it auto-collapses: panel 400 · content 832. Reopened by the user: panel 352 · content 640. | Panel 592 · content 640 with the side-bar collapsed (open would leave 400, so it auto-collapses; reopened: panel 352 · content 640). |
| 1,440 px | Open: panel 400 · content 752. Closed: content 992. | Panel 720 · content 672 closed; open would leave 432, so the side-bar auto-collapses (reopened: panel 512 · content 640). |
| 1,920 px | Open: panel 400 · content 1,232. Closed: content 1,472. | Panel 960 · content 912 closed, 672 open — the side-bar stays. |

Desktop Chrome is the platform. No touch or mobile promises (§3.2), no offline mode, no i18n, no CDN. Tables, the raw log and code blocks scroll inside their own container; the page never scrolls horizontally.

## Inspiration & Anti-patterns

**Borrowed from VS Code** (the shell reference the owner named): the activity bar → rail with the Agent co-pilot entry pinned bottom; the primary side bar → side-bar (click to open, click again to collapse, remembered); the command center → command-box (top center, Ctrl/Cmd+K, screens and commands); the secondary side bar → the panel (docked right, resizable, full screen); the status bar → status-bar (instance facts and connection state, the user segment as the account home); the empty-editor shortcut hints → the chords shown in the command-box placeholder, the composer caption and the rail tooltips, plus Home's tile row and starter prompts; the input's stop button → Send becomes Stop while a turn runs; the panel's add icon → New conversation. Not borrowed: badge counts on rail entries (only the attention-dot), a close control on the panel, tabs across the panel header, back/forward arrows (the browser's Back is the undo), the notifications bell (toasts, the held row highlight and the audit ledger cover it), a history icon (the polish-week Transcripts screen is the history).

**Rejected — the classic portal** (research §2): popup dialogs and new windows (500 × 500, 700 × 600) → full-page routes and Material dialogs one level deep; namespace-switch URL rewriting into another CSP application → a header select that re-fetches in place; menu-only search with a 220 ms typeahead → the command-box over screens and actions; raw log dumps (a 90 KB text render) → parsed rows with severity, search and a Raw toggle; the System Information panel hidden under 1,100 px → the squeeze rule, nothing hidden by width; no theming → light and dark tokens from day one; terse errors with a docs link → one message with the action to take; "You do not have privilege to view this page." → the resource named in the tooltip.

**Rejected — the field's agent patterns:** drafting-only assistants that never act, and assistants that act without a marker in the audit trail; batch approval; hallucinated success ("many hallucinations, it often ignores instructions") → the agent verifies before it claims. **Rejected — naming:** "co-pilot" alone (Microsoft Copilot confusion); the feature is always the agent co-pilot.

## Open items

The nine `[NOTE FOR ARCHITECTURE]` / `[NOTE FOR PRD]` markers in this document, indexed. Each stays inline at its point of use; this table is the way to find them. The 21 `[ASSUMPTION]` markers are not indexed here — they are working answers, not open asks, and stay where they are used.

| Marker | Section | Ask |
|---|---|---|
| `[NOTE FOR ARCHITECTURE]` | Foundation › Install prerequisite | Enable auditing and register OcuPilot's audit events at install, so the "not being marked" banner is not the panel's first words on a fresh container. |
| `[NOTE FOR ARCHITECTURE]` | Information Architecture › Routes | Cap the rows that travel with a turn and show the count on the read tool-call card. |
| `[NOTE FOR ARCHITECTURE]` | Information Architecture › Adding a screen (1) | Fix the reversible entity-id encoding, so names with spaces, slashes and a leading `_` round-trip as one path segment. |
| `[NOTE FOR ARCHITECTURE]` | Agent Write Lifecycle (2) | Where the API accepts a partial update, have the write tool send only the changed fields. |
| `[NOTE FOR ARCHITECTURE]` | State Patterns › Shell and screens (Expired password) | Unexpire `_SYSTEM` at install, so the first screen never sends the user to the classic portal. |
| `[NOTE FOR PRD]` | State Patterns › Panel | Step 7's per-user turn limits need a "turn limit reached" banner and a refusal sentence before that step ships. |
| `[NOTE FOR ARCHITECTURE]` | Accessibility Floor › Time limits | The proposal interval is a server-side constant; a per-instance setting is a Switches candidate for polish week. |
| `[NOTE FOR ARCHITECTURE]` | Key Flows › UJ-3 (1) | Decide whether the FR-69 demo fixture that creates `/csp/myapp` is on by default in the Compose flow. |
| `[NOTE FOR ARCHITECTURE]` | Key Flows › UJ-5 (edge) | Cross-reference to the expired-password ask above: the installer should make that edge disappear. |

## Key Flows

The six PRD journeys (§3.3), protagonists as written. Every flow is written in its Release 1 form.

### UJ-1 — Dana arrives from the classic portal and asks what she is looking at (Dana Okafor, developer, her own IRIS for Health Community container, classic portal open in another tab)

1. Dana opens `/ocupilot` for the first time today. The silent login succeeds on the classic portal's cookie; Home appears with no form, the panel at `{spacing.panel-home}` showing its suggested view.
2. She clicks the Permissions rail-item; the side-bar opens; she clicks Users. The Users list loads within 2 s.
3. The context-chip already reads "Users, HSCUSTOM · 6 rows · Anthropic · api.anthropic.com · leaves the instance".
4. She presses Ctrl/Cmd+I and types "which of these users can't log in and why?", Enter. Focus stays on Send, now reading Stop; a tool-call card "read users" appears expanded, then collapses as the reply arrives.
5. **Climax:** the reply names two accounts and the reason for each — one disabled, one expired — in plain text, and ends "Shall I select them in the list?" Dana types "yes"; the agent's navigation tool selects the first account: the row takes the selected treatment, the locator-bar reads "Permissions › Users › <account>", and the reply cites the second by name for her to pick next. (Polish week turns the names into click-through chips, FR-71.)
6. Resolution: she never left the screen or the tab; nothing was written; the audit database has no new entry.

Edge: the silent login fails → the form login appears once with the Users route preserved; after sign-in she lands on Users. Whether that sign-in also signs the classic portal in is OQ15.

### UJ-2 — Dana installs OcuPilot from a clean clone and meets the first-login gate (Dana Okafor, fresh clone, not authenticated)

1. `docker compose up -d`; she waits for the startup log line.
2. She opens `/ocupilot`; the silent probe returns 401; the form login appears. She signs in as `_SYSTEM`.
3. No definition is enabled and she holds the OcuPilot administrator resource, so the shell redirects to Agent co-pilot › Definitions with the Definition form open under the gate landing banner ("OcuPilot needs one agent definition before the panel can help…"); the attention-dot is lit.
4. She picks Anthropic; the provider's defaults cascade into the form and the suggested model list fills. She pastes the API key into the masked-secret-field (the key-shape check passes) and presses Test connection.
5. **Climax:** within 10 seconds the button settles and the form reads "Connected. Reply: <the model's first words>". She presses Save; the definition is enabled and default; the attention-dot and the reminder banner clear; the sticky bar reads "Saved" and offers "Go to Home". She takes it: Home opens with the panel live at `{spacing.panel-home}`, the context-chip naming Home, HSCUSTOM and the provider, and — nothing needs attention on a fresh container — the suggested view offering the three starter prompts.
6. Resolution: the key field is empty and captioned "Stored. Enter a new value to replace it."

Edge: Test connection fails → the form shows "The provider refused the request. Check the key and try again. Provider said: <text>" under the button, the definition stays disabled, and Save still works ("Saved — disabled until Test connection passes."). Dana can leave: every screen browses normally, the panel shows the administrator reminder banner and the example proposal card on each, and the attention-dot stays lit until she returns and a test passes.

### UJ-3 — Dana fixes a disabled web application through the agent in under a minute (Dana Okafor, recording the contest demo on a video call)

1. The Web applications list is open, `/csp/myapp` showing Enabled "No" and no resource. The context-chip reads "Web applications, HSCUSTOM · 6 rows · …". `[NOTE FOR ARCHITECTURE]` `/csp/myapp` exists only if the PRD's FR-69 demo fixture ran; the open question is whether that option is on by default in the Compose flow.
2. She types "enable /csp/myapp and give it the %Development resource", Enter.
3. A tool-call card "read web applications" turns to "done" and collapses; a proposal-card follows, its anatomy per Component Patterns › `proposal-card`. The values that make this demo concrete: the header "Proposal · Web application /csp/myapp"; two diff-rows — Enabled: No → Yes, Resource: (none) → %Development — with "38 unchanged fields" collapsed beneath them; "Agent's rationale" reading "The application is disabled and carries no resource, so nobody can reach it."; "Expected impact" reading "users holding %Development can reach the application"; "Reverse: disable /csp/myapp and clear its resource"; the countdown at "Expires in 9:59". The agent's message ends "Press Confirm on the card to apply it."; Send has dropped to a secondary button; the list's auto-refresh chip reads paused.
4. Dana presses Confirm. The button shows progress.
5. **Climax:** the write runs as Dana. The card's buttons give way to the status line "Confirmed by _SYSTEM · 10:42:07", which takes focus; the tool-call card "update web application /csp/myapp" reads "done · audit marked"; the Web applications list re-fetches in place and the `/csp/myapp` row, now Enabled "Yes" with %Development, lights up in `{colors.change-highlight}` with its "Changed" tag; the agent replies "Done. /csp/myapp is enabled with %Development. The list has been refreshed and the row is highlighted. Shall I show you the audit entry?" Under a minute from the first keystroke.
6. Resolution: she answers yes; the agent announces "I'm opening Audit database for the agent marker — use Back to return." and Logs › Audit database opens with the agent-marker filter applied; the event is there under her own user name, its description marked as coming through the OcuPilot agent co-pilot.

Edge: Dana lacks the privilege → Confirm returns the same 403 the editor would; the tool-call card reads "failed — requires %Admin_Secure"; the agent says the write was refused and does not retry. Edge: she types "yes" instead of pressing Confirm → the message cancels the card ("Canceled — by your message"); the agent replies that the proposal was canceled and asks whether to propose it again; "yes" now yields a fresh card. Edge: she mistypes the prompt → she presses Stop; the running card reads "Stopped by you at read web applications"; she sends the corrected prompt.

### UJ-4 — Marcus runs OcuPilot read-only on a production instance (Marcus Lindqvist, operations administrator, regional hospital, change-controlled IRIS for Health)

Not reproducible at the Anthropic-only floor: the local model is a step 7 provider. The read-only behavior itself ships in Release 1.

1. Marcus signs in through the form. His administrator has turned on enforced read-only in Switches and configured a local model, so his panel carries the enforced read-only banner and the context-chip names the local provider and its host with no "leaves the instance".
2. He opens Logs › messages.log, searches for the repeating warning (the search highlights 14 matches), and asks the agent to explain it. A "read messages.log" card runs; the reply explains cause and remedy.
3. He asks it to apply the remedy.
4. **Climax:** no proposal card appears. The agent replies that the write was blocked by read-only mode, states what it would have changed, and names the screen — "on Permissions › Services, the %Service_Console setting" — so Marcus can raise it through change control.
5. Resolution: the context-chip shows the local provider and host, so Marcus can see the log text never left the instance.

Edge: the kill switch is engaged for him → on his next turn the panel enters its disabled state with the administrator's reason; the composer stays focusable but cannot send (`aria-disabled`, the reason read out); every screen keeps working.

### UJ-5 — Priya evaluates the entry as a judge (Priya, Developer Community member, 30 minutes and a laptop, starting from the Open Exchange listing)

1. She follows the README: clone, `docker compose up -d`, open the URL. The form login appears (no cookie yet).
2. Before she pastes a key the panel already shows her what a proposal looks like — the labeled example card under the who-can-configure line. She reads the walkthrough and repeats UJ-2 (the gate, Test connection, Save) and UJ-3 (the confirmed write, the highlighted row).
3. She clicks each of the six area-tiles on Home in turn. In each, the side-bar opens, the first screen shows a list backed by live data, and the panel proposes at least one write when asked.
4. **Climax:** the README's promised path — install to first confirmed agent write — works without a workaround, and every screen she opened answered in one step.

Edge: the `_SYSTEM` password is expired → the form login's expired-password state ("The password for _SYSTEM has expired…") explains the expiry and links to the fix; she clears it and signs in (the `[NOTE FOR ARCHITECTURE]` on that state asks the installer to make this edge disappear).

### UJ-6 — Dana troubleshoots a suspended task and lets the agent take her there (Dana Okafor, on Home)

1. The panel's suggested view shows "Task Manager: 1 task suspended after error · Nightly purge". She clicks the line; it lands in the composer; she edits it to "why did the nightly purge task stop?" and presses Enter. Cards "read task schedule" and "read task history · Nightly purge" run in order; the reply says the task is suspended after an error, quotes the error text, and asks "Shall I open Task details for it?"
2. Dana types "yes".
3. The agent posts "I'm opening Task details for Nightly purge — use Back to return."; about a second later the route changes: Tasks › Task details with Nightly purge selected, the side-bar open on Tasks, the heading announced as "Task details — opened by the agent; Back returns". A proposal-card follows: "Proposal · Task Nightly purge", diff-row Status: Suspended → Scheduled, rationale citing the last error, expected impact, Confirm/Cancel with the countdown and captions, and the message ending "Press Confirm on the card to apply it."
4. Dana presses Confirm.
5. **Climax:** the task resumes as Dana; the status line "Confirmed by _SYSTEM · 09:14:22" takes focus; the details screen's Status field highlights in `{colors.change-highlight}`; a toast reads "Resumed Nightly purge · Open in Task schedule" and waits 30 s. The agent replies that the task is scheduled again, names the next run, and asks whether to show the audit entry.
6. Resolution: Task history for Nightly purge shows the manual resume attributed to Dana, marked as coming through the OcuPilot agent co-pilot.

Edge: the error recurs on the next run → Dana asks again; the agent's follow-up cites that history row by name rather than claiming success. Edge: she did not want to leave Home → the browser Back button returns her to Home with the panel and conversation intact.
