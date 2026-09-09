---
stepsCompleted: ['step-01-validate-prerequisites', 'step-02-design-epics']
inputDocuments:
  - '_bmad-output/specs/spec-OcuPilot/SPEC.md'
  - '_bmad-output/planning-artifacts/prds/prd-OcuPilot-2026-09-08/prd.md'
  - '_bmad-output/planning-artifacts/prds/prd-OcuPilot-2026-09-08/addendum.md'
  - '_bmad-output/planning-artifacts/prds/prd-OcuPilot-2026-09-08/extract-stages.md'
  - '_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/C4.md'
  - '_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/harvest/HARVEST-PLAN.md'
  - '_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/harvest/iris-session-agent.md'
  - '_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/harvest/iris-execute-mcp-v2.md'
  - '_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/harvest/iris-couch.md'
  - '_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/harvest/iris-table-editor.md'
  - '_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/DESIGN.md'
  - '_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md'
  - '_bmad-output/planning-artifacts/research/technical-ocupilot-portal-feature-landscape-2026-09-08/feature-catalog.md'
---

# OcuPilot - Epic Breakdown

## Overview

This document provides the complete epic and story breakdown for OcuPilot, decomposing the requirements from the PRD, UX Design if it exists, and Architecture requirements into implementable stories.

**Scope of this breakdown.** Release 1 (P0, 119 catalog rows, contest deadline 2026-09-27) and the polish week (P1, 61 rows, 2026-09-28 to 2026-10-04) are carried at full story rigor. Stages 2 through 6 (357 catalog rows, P2 to P4) are carried as epics and stories at the grain their own source specifies - `extract-stages.md`'s per-stage, per-section row groups - because no FR-level requirement exists for them and inventing one would fabricate a contract the project has not made.

**Authority order** when sources disagree, per SPEC.md and the architecture spine: an AD beats any other companion; a diagram loses to an AD; `EXPERIENCE.md` -> *Fixed strings* is canonical over every other quotation of a string; `DESIGN.md` and `EXPERIENCE.md` beat any mock, wireframe or import; PRD section 10.1's build order **is** the cut line.

**Stage numbering.** This document uses the PRD's numbering (Release 1, then Stage 2 ... Stage 6). `extract-stages.md` numbers the post-contest stages 1 to 5, so its Stage 1 is this document's Stage 2, and so on.

## Requirements Inventory

### Functional Requirements

**5.1 Portal shell and sign-in**

FR-1: Silent-first sign-in - a user reaches OcuPilot with no login form when the browser already holds an instance login, and with one form login otherwise; the token pair is per-tab, Bearer-only, refreshed before expiry and once on any 401. Catalog: SH-01.
FR-2: Sign-out - ends the browser-level instance login across the `%ISCMgtPortal` group, clears tab storage, lands on the form login; it does not promise the classic portal shows a form. Catalog: SH-10.
FR-3: Instance identity and API version guard - on every load the shell verifies the admin API is present at version 2 and blocks every area screen behind a notice naming the mismatch; a signed-in user with no `%Admin_*` resource sees "no administrative privileges on this instance" instead. Catalog: SH-11, PK-09.
FR-4: Privilege-driven navigation for the six areas - screens the user lacks privilege for render disabled with a tooltip naming the required resource, never hidden; gating comes from the admin API's `%Admin_*` privilege map. Catalog: SH-02, SH-05.
FR-5: Header strip and namespace switch - server, instance, namespace, user, licensed-to and server flag visible at all times; the selector lists only namespaces the user can read and write and the choice rides on the route and into screen context. Catalog: SH-03, SH-04, EX-01.
FR-6: Page chrome - every screen carries a navigating locator bar and a per-page command bar holding the screen's actions, view options, sort and search. Catalog: SH-07, SH-08.
FR-7: Auto-refresh framework - on/off, rate and last-update stamp per list screen with sort, filter, page size and max rows persisted; refresh never resets the user's place and pauses while a proposal awaits confirmation on that screen. Catalog: SH-09.
FR-8: Uniform error handling - one error envelope for the whole API; 401 triggers refresh-and-retry, 403 names the missing privilege, a failed call distinguishes "instance unreachable" from "request refused", internal exceptions log fully and report generically. Catalog: SH-06.
FR-9: Classic portal fallback links - every classic page in the six areas OcuPilot has not rebuilt is reachable from its corresponding screen; a cut large editor ships as a reduced form plus a link, never a half-working full form; no list screen links out; the write tool ships regardless. Catalog: cut line rule.

**5.2 Agent co-pilot panel**

FR-10: Always-visible docked panel - present on every route, resizable with a remembered width and a minimum, full-screen toggle, never closed by navigation, no close control in Release 1. Catalog: CP-01.
FR-11: Screen context on every turn, with a toggle - route, namespace, selected entity and visible rows, reassembled fresh each turn; every secret-typed field excluded unconditionally; a context chip names what is shared, the provider and endpoint host, and says "leaves the instance" when that host is not private. Catalog: CP-09, CP-10, CP-31 (partial).
FR-12: Turn execution with progress and a conversation lock - each tool call appears as a card with name, argument summary and result status while the turn runs; a second message on the same conversation is refused with a visible lock; the transcript survives reload; a provider timeout ends in an error card. Catalog: CP-02, CP-17, CP-18.
FR-13: Reply rendering - sanitized Markdown with code highlighting from a vendored pipeline; no CDN reachable; the renderer loads no remote resource and a reply containing a remote image produces no network request. Catalog: CP-20.
FR-14: Screen synchronization after agent writes - every confirmed write emits a change event (entity type, id, action); the active screen showing that type re-fetches in place and highlights the changed row or field within two seconds; a toast links to it when that screen is not open. Catalog: CP-42.
FR-15: Agent-driven navigation - client-side tools that open a screen, apply a filter or select an entity, accepting only allow-listed route identifiers and entity ids, never a URL; the agent announces the destination first and the browser Back button reverses it. Catalog: CP-43.

**5.3 Agent tools, write model and governance**

FR-16: One read tool per screen - every list and detail screen in the six areas plus the three shell reads (privilege map, namespace list, instance identity) has exactly one read tool over the same endpoint returning the same fields the screen shows; tools take the filters the screen offers and return row identifiers the panel turns into citations; no read tool runs free-form SQL in Release 1. Catalog: CP-11, CP-12 and every read row in 5.5-5.10.
FR-17: Write tools with propose, review, confirm - a write-tool call mints a server-side proposal holding the tool, resolved arguments and a fingerprint of the target read fresh; the card shows target, instance-computed before/after diff, every field the payload sends, the agent's labeled rationale and expected impact and how to reverse it; the write runs only on a separate authenticated confirmation carrying the proposal id, executed from stored arguments; confirmation is single-use, expires and is refused when user, conversation, definition, read-only state or fingerprint has changed; secrets are declared in schema, never accepted from the model, and travel only in the confirmation; a destructive proposal requires the user to type the target's name. Catalog: CP-13 and every write action in 5.5-5.10 including SS-04, SS-07, LG-04.
FR-18: Execution strictly as the user - every tool runs under the caller's own IRIS privileges with no service account; a 403 is identical to the screen's and is reported, never retried; the full tool set stays advertised with privilege checked at call time; the Release 1 prohibited set is refused on the instance and never advertised; any escalation is confined to named storage and file-read methods and is not in effect while tool, admin API or provider code runs. Catalog: CP-14.
FR-19: Read-only mode - an OcuPilot administrator can enforce it instance-wide and any user can set their own session (build step 7); every write tool returns a structured "blocked by read-only mode" result, the agent states what it would have changed and on which screen, and no proposal card appears; the enforced-state settings also hold the context-sharing default and the per-user turn limits. Catalog: CP-21.
FR-20: Kill switch - an OcuPilot administrator can disable the agent globally or per user; turns are refused server-side, the panel renders disabled with the reason, every screen keeps working, and the switch is reachable through a screen that does not depend on the agent. Catalog: CP-22.
FR-21: Agent audit ledger - every LLM call and tool call is recorded with user, timestamp, screen route, tool or provider name, arguments, result status, token usage where reported, and the IRIS resource the tool required; redaction is schema-driven from each tool's declared secret fields. Catalog: CP-15.
FR-22: Agent marker on every write - every confirmed write emits an OcuPilot audit event carrying the agent marker alongside the IRIS system event for the same change; a write made by hand emits none; the audit viewer can filter on the marker; a failed marker is recorded on the ledger row and shown on the tool-call card rather than failing the write; with auditing off every user sees an "agent writes are not being marked" banner. Catalog: CP-16.
FR-23: Provider retry and timeouts - bounded exponential backoff on 429 and 5xx honoring `Retry-After`, a fixed per-call timeout, and a turn that names the step that timed out; no Web Gateway timeout prerequisite exists, and a turn longer than the stock 60 seconds must complete normally. Catalog: CP-19, PK-08.

**5.4 Agent configuration and the first-login gate**

FR-24: Agent definition management - create, edit, enable, disable and delete definitions holding name, provider, model, endpoint, credential type and reference, max tokens, temperature, max iterations, optional system prompt override, read-only flag, retention period and enabled flag, under eleven server-side validation rules; changing provider, endpoint or credential disables the definition until Test connection passes again; every change is audited with old and new endpoint; one definition is default. Catalog: CP-03.
FR-25: Four provider families including local models - Anthropic first, then OpenAI, Google Gemini and OpenAI-compatible (which covers local models), each an adapter behind one contract so adding a family changes no part of the loop, the tools or the screens; plain HTTP only with no credential or an explicit stored acknowledgment. Catalog: CP-04, CP-05.
FR-26: Credential resolution without storage - keys resolve at call time from an environment variable or an IRIS credential; the definition stores only type and name; a key entered in the form is written once and returned by no API call; per-provider shape checks catch paste errors. Catalog: CP-07.
FR-27: Test connection - one minimal provider call reporting the model's reply or the provider's error text, using the definition as edited before save, truncated to a bounded length, refusing link-local metadata endpoints while allowing loopback and private hosts. Catalog: CP-06.
FR-28: First-login gate - with no enabled definition an OcuPilot administrator is taken to agent configuration at every login and a banner persists on every screen until one is enabled; the gate is bypassable; non-administrators keep every screen with the panel in its configuration-empty state naming who can configure it. Catalog: CP-08.
FR-29: OcuPilot administrator privilege - the installer creates the administrative resource and a role granting it; every configuration endpoint checks it server-side; every change to a definition, the kill switch, enforced read-only, the context-sharing default or the turn limits emits an audit event naming actor, target and old and new values; OcuPilot's persistent state is unreachable through SQL or direct global access to a holder of the install namespace's database rights without the resource, and a test proves it. Catalog: PK-13.

**5.5 Web applications and REST API explorer**

FR-30: Web applications list, detail and edit - list shows name, namespace, type, enabled, dispatch class and resource with filter; the editor covers the classic page's full field set; save reflects in the list with no manual refresh. Catalog: WA-01, WA-05.
FR-31: Create web application - CSP, REST, WSGI or ASGI with type, namespace, dispatch class, resource and authentication methods, validated server-side, opening the new application's editor on success. Catalog: WA-04.
FR-32: Enable, disable and delete web application - from the row or the editor; delete confirms by name; deleting OcuPilot's own applications is refused with an explanation. Catalog: WA-02, WA-03.
FR-33: REST API explorer list - REST-enabled web applications and spec-based REST services per namespace, combining management-API discovery with the web application list, each entry linking to its document view. Catalog: WA-06.
FR-34: OpenAPI document viewer - a path-and-verb browser over a service's OpenAPI 2.0 document; manually coded services show their generated document, spec-based services their stored one, and a service the management API refuses shows the refusal rather than an empty view. Catalog: WA-07.

**5.6 Permissions**

FR-35: Users list, detail and edit - list shows name, full name, enabled, type and roles with filter; the editor covers account settings, comment, expiry, enabled, change-password-on-login, startup namespace and routine, email, mobile, two-factor settings and a roles tab. Catalog: PM-01, PM-07.
FR-36: Create user - name, password, full name, roles, expiry, startup namespace and routine; the password is sent once and never returned; the new user opens in the editor. Catalog: PM-06.
FR-37: User actions - enable, disable, delete, set password with a change-on-login flag, and add or remove roles, each available from the row and the editor and updating the row in place; disabling or deleting the current user is refused with an explanation. Catalog: PM-02, PM-03, PM-04, PM-05.
FR-38: Roles list, detail and edit - the editor covers description, escalation-only, resource grants, members and granted-to. Catalog: PM-08, PM-12.
FR-39: Role create, resource grants and delete - a grant is resource plus permissions and editing shows the current grant and the result; deleting a role granted to users warns with the count first. Catalog: PM-09, PM-10, PM-11.
FR-40: Resources list and management - list with search; create, edit and delete with name, description and public permission; system resources are shown but not deletable. Catalog: PM-13, PM-14.
FR-41: Services list and edit - enabled state, allowed IP addresses, roles and authentication methods; disabling the web service OcuPilot itself depends on warns before proceeding. Catalog: PM-15, PM-16.

**5.7 Security and secrets**

FR-42: SSL/TLS configurations - list, create, edit and delete covering certificates, key, CA, CRL, protocol minimum and maximum, ciphers, DH bits, OCSP and peer verification; private key material entered in the form is returned by no read. Catalog: SS-01, SS-15.
FR-43: X.509 credentials - list with subject, issuer and validity; import a certificate and optional private key; edit and delete. Catalog: SS-02, SS-11.
FR-44: OAuth 2.0 lists and views - client server descriptions, client configurations, resource servers and server client descriptions list; the authorization server configuration is viewable; client configurations and server client descriptions delete with a named confirmation; each entry links to the classic editor until the polish-week editors ship. Catalog: SS-03, SS-04, SS-05, SS-06, SS-07.
FR-45: LDAP and Kerberos configurations - list, create, edit and delete over the classic LDAP page's field set. Catalog: SS-08, SS-16.
FR-46: Wallet collections and secrets - list collections; list, create, edit and delete secrets in a collection with values write-only; access requires the wallet administrative resource and users without it see the screen disabled. Catalog: SS-10.
FR-47: Auditing configuration - enable and disable auditing, configure system audit events including the selective SQL auditing wizard and reset counters, and create, configure and delete user audit events; disabling auditing warns that agent writes will no longer be marked, and the agent's own proposal card must carry that warning. Catalog: SS-09, SS-12, SS-13.

**5.8 Tasks**

FR-48: Task schedule, on-demand and upcoming lists - scheduled tasks with the Task Manager's status, last and next run and filter; on-demand tasks with a Run action; upcoming tasks for a chosen horizon in order of next run. Catalog: TM-01, TM-02, TM-03.
FR-49: Task history - all tasks or one task with a filter; each row shows start, end, status, error text where present and the running user where returned. Catalog: TM-04, TM-05.
FR-50: Task details - properties, schedule, last and next run under auto-refresh, linking to history and Edit task. Catalog: TM-11.
FR-51: Task actions and Task Manager control - run now, suspend, resume and delete a task, and start, suspend and resume the Task Manager; each action updates the row in place, delete confirms by name, and suspending the Task Manager warns that no scheduled task will run until it is resumed. Catalog: TM-06, TM-07, TM-08, TM-09, TM-10.
FR-52: New task wizard - name, description, namespace, task type from the instance's definitions, priority, run-as user, output file, suspend-on-error, reschedule-after-restart, a schedule of daily, weekly, monthly, monthly-special, after another task or on demand, expiry and email settings, with the field list and legal values taken from `%SYS.Task`/`%SYS.TaskSuper`. Catalog: TM-12.
FR-53: Edit task - the same fields as the wizard with current values, built from the same model so the field list matches by construction. Catalog: TM-13.

**5.9 OS management**

FR-54: Processes list and details - list with filter, page size, max rows, persisted sort and auto-refresh; details show dashboard meters, client executable and address, open devices and the current SQL statement where available. Catalog: OS-01, OS-08.
FR-55: Process control - terminate with the optional error-to-job flag, suspend and resume, confirming by process id; acting on the user's own process is refused with an explanation. Catalog: OS-02, OS-03, OS-04.
FR-56: System usage and dashboard meters - global references, routine calls, block reads and writes, journal entries and shared memory, plus the CPU, memory and performance meters on a refresh interval, with meter names and thresholds taken from `%CSP.UI.Portal.EnsembleMonitor`. Catalog: OS-05, OS-09.
FR-57: Locks view and removal - locks by namespace with filter and owner details linking to process details; remove one lock, all locks of a process or all locks from a remote client, warning when the owning process is in a transaction. Catalog: OS-06, OS-07.
FR-58: Databases list and details - local databases in general and free-space views showing size, maximum, free space, status, directory and mounted state, with free-space figures arriving asynchronously and rendering as they land; details show properties, volume files and background tasks under auto-refresh. Catalog: OS-10, OS-11.
FR-59: Devices - list, create, edit and delete over the classic device page's field set. Catalog: OS-12.

**5.10 Logs**

FR-60: alerts.log viewer - entries reported since the last monitoring scrape from the monitoring API merged with a bounded tail of the file through the OcuPilot API. Catalog: LG-01.
FR-61: Audit database viewer - search by time range, source, type and name, user, process id, namespace, authentication and text; filter to events carrying the agent marker; open an event's full detail including description and any JSON payload. Catalog: LG-02, SS-14.
FR-62: messages.log viewer - search, highlight, go to top and bottom and tail, served in bounded pages so the whole file never loads into the browser, from a manager-directory path no request can change. Catalog: LG-03.
FR-63: Application error log - drill from namespaces to dates to errors showing text, time and, where recorded, routine and line; delete by namespace or individually as a confirmable agent write, which is what gives the Logs area its own confirmed write; access through `SYS.ApplicationError`. Catalog: LG-04.

**5.11 Packaging, install and submission**

FR-64: One IPM module - one command installs OcuPilot with the built bundle inside the archive so install needs no Node toolchain, targeting `HSCUSTOM` when present and `USER` otherwise, with the choice made by the installer rather than the manifest. Catalog: PK-10, PK-15.
FR-65: Two web applications created at install - the static shell serving the bundle unauthenticated with a non-root base href and deep-link fallback, and the OcuPilot API password-authenticated with JWT enabled, no server session and membership in the vendor's portal group, carrying no application or matching roles and refusing users holding no `%Admin_*` resource. Catalog: PK-11, PK-12.
FR-66: Idempotent installer and name isolation - running install twice changes nothing the second time; every created object is guarded by an existence check; no agent definition is seeded; the namespace is restored on any error; auditing and OcuPilot's audit event types are enabled; the state protection of FR-29 is established; a `demo` option creates the walkthrough fixtures; a smoke script gates every publish and build-order step; a unit-test harness runs in CI; and no name collides with iris-session-agent, iris-execute-mcp-v2 or iris-couch. Catalog: PK-07, PK-13.
FR-67: Docker self-install - from a clean clone one `docker compose up` brings up an instance with OcuPilot installed, `_SYSTEM` unexpired and the namespace chosen, reachable on the workspace's published port; a second up after down and an up with a newer image against the existing durable volume both reach the same state with no manual step; the compose file pins the exact tested image tag. Catalog: PK-14.
FR-68: Community Edition compatibility - runs on IRIS Community and IRIS for Health Community with no HealthShare-only dependencies; the automated tests run against both stock images and confirm the admin API on each; the plain-Community check runs after the application floor is built. Catalog: PK-06.
FR-69: Submission deliverables - a public MIT repository with an English README whose install steps work first time, the UJ-2 and UJ-3 walkthroughs with screenshots, a "get a key in two minutes" section per shipped provider, an Ideas Portal link, team profile links and a video if recorded; the Open Exchange listing exists before the application, which is submitted by 2026-09-27 23:59 EST. Catalog: PK-01, PK-02, PK-03, PK-04, PK-05.

**5.12 Polish-week capabilities (P1, 2026-09-28 to 2026-10-04)**

FR-70: Screen-aware help from the agent - "Explain this screen" as one click on every screen citing the read tool it used; an explain entry point on every log and audit entry sending that entry alone; at least three suggested prompts per screen grouped by task. Catalog: CP-23, CP-24, CP-25.
FR-71: Agent transparency - click-through citation chips on every reply that used a read tool; a data-egress line on every turn with context sharing on; an agent audit viewer over the ledger with filters by user, screen and date, where administrators see all users' rows and others their own. Catalog: CP-26, CP-27, CP-31.
FR-72: Agent restraint and governance - a copy-out ObjectScript, CLI or REST draft instead of an execution on any proposal; a per-tool-and-action governance policy with read-only and full presets over a frozen baseline that keeps every Release 1 write key enabled; truncation, control-stripping, delimiter-wrapping and secret redaction of tool and log content before it reaches the model with a seeded-injection test; transcripts persisted per user with a retention purge, an administrator's view of another user's transcript ledgered and gated by the resources those calls required. Catalog: CP-29, CP-30, CP-32, CP-33.
FR-73: Shell conveniences - change own password, favorites, recent items, menu search, About, per-screen Help, the fixed shortcuts menu, the links panel, the Home system information panel, UI state across sessions and a light or dark theme, each reachable from the header or Home with per-user state surviving a sign-out. Catalog: SH-12 to SH-22.
FR-74: Web applications and permissions extras - a try-it request console round-tripping with the current session, web sessions list and end, a user's effective privileges, and a permission-check tool answering yes or no with the granting role. Catalog: WA-08, WA-09, PM-17, PM-18.
FR-75: Security and secrets editors and tests - SSL/TLS test connection, X.509 certificate details, LDAP test authentication, OAuth 2.0 token revoke, audit database copy and purge, and full editors for OAuth 2.0 resource servers, client server descriptions, client configurations, the authorization server and server client descriptions, each round-tripping create, edit and delete. Catalog: SS-17 to SS-27.
FR-76: Tasks and OS extras - task export and import across instances, background tasks with cancel, pause and resume (needing a custom endpoint because the admin API tracks only its own async tasks), broadcast to chosen processes, license usage, and every System Dashboard meter group. Catalog: TM-14, TM-15, TM-16, OS-13, OS-14, OS-15.
FR-77: Secondary log viewers and the log hub - the System Monitor log, background task error log, xDBC error log, SQL diagnostics log, interoperability event log and analytics log, plus a unified hub listing every source with counts, last entry and explain entry points. Catalog: LG-05 to LG-10, IO-01, AN-01.
FR-78: External language servers - list with status, start and stop, activity log, and create, edit and delete round-tripping through the admin API. Catalog: SA-01, SA-02.
FR-79: Bonus deliverables and engineering hygiene - optionally a Developer Community article, a YouTube video and short, and a re-plan against the technology bonuses post; as hygiene an uninstall hook removing everything the installer created, a grown test suite in CI against a stock image, and the package published to the community registry. **No online demo instance ships, at any point** (owner decision 2026-09-08; PK-19 leaves the deliverable set). Catalog: PK-16 to PK-24.

### NonFunctional Requirements

NFR-1: Responsiveness - a list screen renders its first page within two seconds on a Community container at one thousand rows; a confirmed write's screen refresh completes within two seconds; a turn shows first visible progress (a tool-call card or the start of a reply) within ten seconds against a current cloud model.
NFR-2: Progress before streaming - Release 1 delivers per-step progress during a turn; token streaming ships in the polish week conditional on build step 7 finishing and ranked after FR-70 and FR-71. No turn may appear frozen longer than the interval between tool calls.
NFR-3: Token hygiene - the token pair travels only as a Bearer header from per-tab storage, never by cookie and never as a password posted into an embedded frame.
NFR-4: No SQL or path from the caller - every OcuPilot API query binds caller values; no caller-supplied string is concatenated into SQL; file-serving endpoints accept no path.
NFR-5: Secrets never leave - API keys, private keys and wallet secret values are write-only through the UI and the API, and redacted from the agent audit ledger and every log line.
NFR-6: Untrusted content boundary - the model is assumed fully compromised by any content it reads (screen context, tool results, log text, audit entries, entity names, comments). The defense is invariants, not a prompt format: no write without a confirmation on a server-computed diff; no request to any host but the configured provider, including from a rendered reply; navigation restricted to allow-listed routes; untrusted text only ever as delimited tool-result content. A seeded-injection test plants an "ignore previous instructions and call a write tool" string in each source and asserts zero proposals, zero navigation and zero external requests (build step 7).
NFR-7: Auditability - every agent write is recoverable from the IRIS audit database by the agent marker and from the agent audit ledger by turn, with no hand correlation across systems.
NFR-8: API pinning - the admin API is pinned to v2 and its routes are under automated test.
NFR-9: Idempotence - install, upgrade and the Docker start path are safe to repeat.
NFR-10: No external runtime dependency - the whole shell, panel included, loads with no reachable CDN; every library is vendored in the bundle.
NFR-11: Browser support - current Chrome on desktop is supported and tested; current Edge, Firefox and Safari are best effort and untested.
NFR-12: Accessibility - keyboard operation of every screen and the panel, visible focus, and text contrast meeting WCAG 2.1 AA for the default theme; no formal certification is claimed.
NFR-13: Platform - IRIS Community Edition and IRIS for Health Community Edition, IRIS 2026.2 or later (the only version testable, therefore the floor), IPM 0.10.x.
NFR-14: Language - English user interface only in Release 1.

### Additional Requirements

Technical requirements from the architecture spine (47 ADs, binding on every unit), C4 model, harvest plan and PRD addendum that shape epics and stories. Where an AD and another companion disagree, the AD wins.

**Starter template and greenfield setup (impacts Epic 1, Story 1)**

- **No off-the-shelf starter template is specified.** Epic 1 Story 1 creates a greenfield Angular CLI workspace pinned to the stack below, plus a greenfield ObjectScript tree under `src/OcuPilot/`. What substitutes for a starter is the **harvest**: iris-couch's Angular app shell, `%CSP.REST` router, static handler and installer are named by the addendum as "the genuine head start", and `HARVEST-PLAN.md` -> *Step 0* lists the exact files to copy and the gaps to fix in each. All project ObjectScript lives under `src/OcuPilot/` and nowhere else (project rule).
- **Stack pins, exact:** Angular 22.1.x zoneless and signal-based; Angular Material + CDK 22.x; TypeScript **6.0.x pinned exactly** (Angular 22 requires `>=6.0.0 <6.1.0`; TS 5.9 and earlier are a breaking change and TS 7 is refused by `@angular/compiler-cli`); Node `^22.22.3 || ^24.15.0 || ^26.0.0` (Node 20 unsupported); the `@angular/build` application builder (webpack builders deprecated in v22); ObjectScript in the IRIS 2026.2 dialect; IPM 0.10.x as a distribution channel only; `/api/admin` v2 pinned; `/api/monitor`; `/api/mgmnt` v2; Docker image `intersystems/irishealth-community` pinned to an explicit 2026.2 tag, never floating `latest-cd`.
- **Source tree** is fixed by the spine: `src/OcuPilot/{Api,Kernel,Screen,Area,Port,Install,Test}` and `ui/src/app/{shell,areas/<area>,core}`, with `module.xml`, `Dockerfile` and `docker-compose.yml` at the root.
- **Vendored in the bundle, no CDN at runtime:** the Markdown renderer, syntax highlighter and sanitizer used by the panel; Inter and JetBrains Mono as woff2; the interim Material Symbols Outlined icon set.

**Architecture paradigm and structural invariants**

- **Descriptor-driven vertical slices, hexagonal at the edges** (AD-5, AD-19). One slice per portal area owning its screens, tools and tests end to end; a slice never reaches into another slice; shared behavior lives in the shell or the kernel. Dependency direction UI -> API -> (Kernel, Slice) -> Registry -> Ports -> outside; the registry never depends on the kernel.
- **One screen descriptor is the source of everything about a screen** (AD-5): route; area and side-bar position; archetype; the privilege set as a set of `(resource, permission)` pairs, never a single resource; entity-type key and scope; id accessor; context serializer with its secret-typed field list; primary and row actions with self-protection rules; empty-state text; command-box aliases; and the classic page it replaces (AD-44). Descriptors are hand-written declarative classes, not generated. Adding a screen means adding a descriptor, never editing a router, nav list or tool registry. A descriptor must handle multi-entity screens (OAuth), sub-resource screens (task history), composite ids, and tool identity independent of screen naming.
- **Only one thing is generated from the descriptor: write tools' field lists** (AD-3, AD-5). A full generator was costed at about six days landing after the step that needs it, and would have moved the cut line.
- **Agent tools execute in-process, never over HTTP** (AD-1, adopted). No tool issues an HTTP request to `/api/admin`, `/api/mgmnt` or `/api/ocupilot`; "runs as the user" is a property of the process. This closes the 60-second-token-versus-90-second-turn mismatch entirely and makes the iris-execute-mcp-v2 handler bodies available as tool bodies.
- **Five ports, one adapter each** (paradigm, AD-2, AD-26, AD-29, AD-42, AD-48): `AdminPort`, `MonitorPort`, `MgmntPort`, `LogSourcePort`, `ProviderPort`. Nothing else crosses the boundary.

**AdminPort: the vendor endpoint contract**

- **`AdminPort` is the only code that names an `%Api.Admin.*` class** (AD-2, AD-27). It reproduces `%Api.Admin.Dispatch.v1:Main()` exactly once, in eight steps, four of which are load-bearing and easy to omit: supply stub `%request`/`%response` objects with `IsRunningAsync = 0` (under the async flag every status an endpoint sets is discarded - probed: a GET for a missing web application reads 404 from the stub and 200 under the flag); call `ValidateQueryParams()` (it is what populates the endpoint's identifying property, and skipping it yields a misleading "Invalid Application name"); wrap `Run()` in `BeginCaptureOutput`/`EndCaptureOutput` (device output otherwise corrupts the envelope); and read the outcome from **both** `tSC` **and** `%response.Status` (a non-2xx status is a failure even when `tSC` is OK).
- **Write payload field lists are derived at build time, never transcribed** (AD-3). The endpoint's body-template method returns a prototype of placeholder values, not JSON Schema: no `required`, no `enum`, no `description`. Those three are authored **once per tool**, reviewed, and are the only hand-written part of a schema. The method is not uniformly named - `RequestBodySchema` (21), `PutRequestBodySchema` (17), `PutAndPostSchema` (1), `Schema` (1) across 70 classes - and the port resolves whichever exists in that order. "Generated" means a checked-in, reviewed artifact from a build step, never runtime reflection. **A write tool whose field list was typed by a human, for an endpoint that publishes a template, is a review failure.**
- **Derivation is where credential fields are removed.** Generation classifies every derived field as ordinary or secret and emits the classification into the descriptor; a field the generator cannot classify is treated as secret; a field whose name matches the credential pattern emitted as ordinary fails the build.
- **16 mutating endpoints publish no template; five are Release 1.** `Wallet.Secret` (FR-46) and `Security.Audit.Event` (FR-47) are field-bearing and need their field lists derived from the underlying `Security.*`/`%SYS.*` class and pinned by a test that fails when the instance disagrees; `Process` (FR-55), `Lock` (FR-57) and `Task.Manager` (FR-51) are action-style with trivial or empty bodies and need no template.
- **OcuPilot computes the merge itself and sends a complete body** (AD-4). Get-merge-put is not a property of the admin API: of 47 `RunPut` implementations only 19 call `MergeJsonAndProperties`, and the 28 that do not include most Release 1 editors - `Security.User` (FR-35), `Task.CRUD` (FR-53), `Security.Resource` (FR-40), `Security.X509Credential` (FR-43), `Wallet.Secret` (FR-46), `Security.Audit.Event` (FR-47) and all four `Security.OAuth2.*` (FR-44). Read fresh, apply the diff, send the complete property set. Two endpoint behaviors are covered by the fresh read plus the fingerprint: `ValidateRequest` enforces required fields even on update, and `Wallet.Secret` and `Security.Audit.Event` PUTs are **upserts**.
- **Async paths are handled in one place** (AD-26). `ShouldRunAsync()` is evaluated **per request type, never per class**. Only two paths exist: the AD-2 synchronous sequence, and a handoff through `%Api.Admin.Util.AsyncTaskEndpoint` with polling that the port exposes as an ordinary call resolving later, so no slice writes polling logic. The two Release 1 async paths are the **audit record LIST** (FR-61) and the **database directory info** call (FR-58 free space). Of the five CSP-touching classes, three use `%request` only to label an async task and take a synthetic label; `Database.AsyncTaskSysBackground` is reachable only from the async path; `Security.Encryption.Settings` is excluded by the v2 pin.
- **The dependency is contained and always has a fallback** (AD-27). Every `%Api.Admin.*` class is `[ Hidden ]` with no stability contract. `AdminPort` verifies v2 and a named probe endpoint at startup and fails loudly. The endpoint inventory - 70 classes, which publish templates, which are async, which touch CSP state - is a **test fixture** re-derived from the running instance, so an upgrade fails the suite rather than a user. Every screen keeps FR-9's classic link as the user-visible fallback.
- **Vendor error text is normalized at the port boundary** (AD-39), mapped to an OcuPilot slug and a written reason, with the raw text kept for the log and ledger only.

**The write path**

- **The proposal is server-minted, single-use, fingerprinted and expiring** (AD-6). Expiry is a server-side constant of **10 minutes**. The fingerprint covers the complete property set the write will send, excluding fields the endpoint itself mutates (a task's next-scheduled time, a last-modified stamp), with exclusions declared in the descriptor. **The confirm channel is closed:** the only keys a client may supply are the descriptor-declared secret-typed fields for that tool; any other key is rejected outright, not ignored; the identifying key is never accepted from the client. Confirm re-checks authorization as well as state, and a proposal is confirmable only by the user who minted it.
- **Confirmation is a single atomic transition** (AD-34). Burning the token and committing to the write are one transition under a lock or conditional update exactly one caller can win; the loser is refused with the proposal's terminal state, not retried. Confirming one proposal cancels its siblings on the same scoped target in the same transition.
- **Confirm is reachable only from the browser, and every write gate is on the write** (AD-40). The confirm path is not a tool and is not in the tool registry; the kernel carries an explicit "acting on behalf of the model" marker through the turn job and every tool call, and confirm refuses when it is set - in-process execution removed the accidental HTTP barrier, so the barrier is now explicit. The prohibited set (AD-10), read-only and the kill switch (AD-30) and later governance (AD-22) are all evaluated **at the write**, inside AD-34's transition, never at the tool call that produced the proposal. A proposal whose turn has died is not confirmable.
- **The turn runs in a background job; the write runs in the confirm request** (AD-7). `POST /api/ocupilot/turn` starts a job and returns a turn id immediately; the job inherits `$USERNAME` and `$ROLES`, writes per-step progress to a temp global keyed by turn id, and **never mutates**. The panel polls `GET /api/ocupilot/turn/{id}/progress`. Confirm is a separate short foreground request. Stop sets a flag the job checks between steps.
- **The turn job re-validates the identity it froze** (AD-31). A `JOB` holds its `$USERNAME`/`$ROLES` copy for life, so the job re-checks between steps that the user is still enabled and still holds the privilege each remaining step needs, and abandons otherwise. A turn is bounded by wall-clock duration as well as iteration count; sign-out abandons the user's running turns.
- **Prohibited actions are absent from the tool set, defined by effect not by verb** (AD-10): deleting or disabling the current user, the last `%All` holder or `_SYSTEM`; **granting privilege through any path** - setting `MatchRoles`/`Roles` on any web application, adding a role to a resource, adding `%All` or any `%Admin_*` role to any user or role (privilege grants are Level 4 in Release 1 and not proposable at any confirmation level); disabling the path that serves OcuPilot - the web application, the **web service** behind it (`%Service_Web`, the CSP service) and the superserver; terminating IRIS system processes; deleting OcuPilot's own web applications, resource, role or database. The set has **exactly one home** in the kernel, as predicates against the resolved target evaluated inside AD-34's transition, never duplicated into a screen, descriptor or policy file and never expressed as a match on request fields. A self-protection rule a screen enforces only in its UI is not a prohibition.
- **Privilege is the process's, checked at call time, never cached** (AD-8). No service account and no elevation on the request path. One resource name is not enough on 2026.2 - the security APIs need `%DB_IRISSYS:R` **and** `%Admin_Secure:U` together - so the descriptor declares the full set of pairs, the gate requires all of it, and a denial names the pair that failed.
- **Read-only and the kill switch are evaluated at the point of effect** (AD-30), inside the write path and inside the turn loop, never only in the client and never cached for a turn. The turn job re-reads both between every step alongside its stop flag and abandons at the next boundary when either changes. Confirm re-evaluates them too.
- **Turns and the ledger are bounded resources** (AD-41). One concurrent turn per user in Release 1, **enforced on the instance** (the UX's conversation lock is the affordance, not the enforcement); bounded iterations, wall clock and total provider tokens; the ledger bounded by rate and size per turn with overflow recorded as a count. **The ledger row is finalized after the write**, recording what was actually executed - resolved target, fields actually sent, privileges actually exercised - not what the proposal predicted.
- **Every agent write is marked with a correlatable audit event** (AD-15). Events are registered with `Security.Events.Create()` at install - without registration `$System.Security.Audit()` silently returns 0 and drops the event. The marker carries the proposal id, tool, target identity and user, alongside the vendor's own `%System/%Security/*Change` event, so either record locates the other. Audit emission never fails a write and never propagates; a failed marker surfaces as "done - audit not marked".
- **OcuPilot's own records are visible in OcuPilot's own screens, deliberately** (AD-46). Agent markers are ordinary rows in the audit database and are **never hidden** from the audit screen; the agent-marker filter is an affordance, not a default. The ledger is different: protected state, scoped per user, an administrator's view of another user's rows gated by the resources recorded on the row itself, with that gate living with the ledger rather than the screen.

**State protection, install and operations**

- **OcuPilot's own state is protected by a privileged routine application** (AD-9). Its **globals - and only its globals** - live in a dedicated database guarded by a dedicated resource no ordinary role holds; **its code does not**, because in IRIS database READ *is* routine-execution permission and putting the packages behind such a resource would make OcuPilot unrunnable by exactly the users it is for. Storage classes, and only storage classes, obtain the role through a privileged routine application inside a `New $ROLES` frame. Two ordering rules make containment real: **nothing is spawned from inside an escalated frame** (a `JOB` inherits `$ROLES` at spawn and keeps it for the child's life, so the turn job starts before any escalated read and every state read it needs is taken first and passed in as values), and **nothing re-enters** (a storage method never calls a tool, a port, or code that could).
- **One installer class, two entry points, idempotent, running at container start** (AD-17). Not at image build: `IRISSYS`, `IRISSECURITY`, `HSCUSTOM` and `USER` live on the durable volume and supersede the image's copies on every start, so a build-time install is invisible on upgrade. Guard-then-act throughout, re-running privileged steps even when the web applications already exist. It enables auditing, registers OcuPilot's events, and unexpires `_SYSTEM` where needed. **The class roster the installer compiles and the IPM manifest's resource list are generated from one source** - iris-execute-mcp-v2's manifest fell 16 classes behind its roster. The installer reports, and does not silently depend on, the CSP Gateway registration gap: `Security.Applications.Create()` does not notify the Gateway, so a new application may 404 until an SMP Save or Gateway restart.
- **IPM is a distribution channel, never a runtime dependency** (AD-18, adopted). Verified: `intersystems/irishealth-community:latest-cd` (IRIS 2026.2) ships **no** IPM - zero `%ZPM*` classes anywhere. The Docker path installs without it.
- **Install completes before the first request is served** (AD-38). The start path completes install or fails loudly before the web applications accept traffic, and the API refuses with a clear "installing" or "upgrade required" rather than serving partial state. Because upgrade re-runs install on every start this is the daily path: install must be fast, idempotent and safe against a fully populated instance. A version stamp recorded at the end of install is what the API checks.
- **There is one smoke path, and it is also the health check** (AD-45). One script - sign-in, one live list per area, one confirmed agent write, the audit marker - is the definition of "installed and working", is what CI runs, and is what the build order's completion test means. It is owned by `Install/`, not by any slice. The API exposes an **unauthenticated readiness endpoint** reporting only installed-or-not, version stamp and whether install is running; no instance detail, nothing aiding reconnaissance. A deeper health view is authenticated and privilege-gated.
- **The demo fixture is opt-in and never writes on an operator's instance** (AD-25). `/csp/myapp` is created only by an explicit, clearly named opt-in flag, set in this repository's own `docker-compose.yml` so a clean clone reproduces UJ-3 first time, and absent by default from every other install path including IPM. The fixture is namespaced so it cannot collide with a real application, and uninstall removes it. *(This reconciles DESIGN.md's release-blocking ask to seed a demo SSL/TLS configuration, a self-signed X.509 credential and `/csp/myapp`: the seeding happens under the compose flow's opt-in, which is the path a judge follows.)*
- **OcuPilot's state has a declared lifecycle against objects it does not own** (AD-37). Every stored reference is **weak** - the scoped identity as data, never a foreign key; a reference that no longer resolves renders as "no longer present" rather than failing the screen; live proposals against a deleted target are refused at confirm by the fingerprint re-read; the retention task sweeps state whose referenced principal is gone. Deleting a user does not delete their transcripts (the ledger outlives its subject) but does invalidate their sessions and abandon their running turns.
- **Operational envelope:** one environment (the instance OcuPilot is installed on); `ng serve` proxied through the IRIS origin against the local container, with the VS Code ObjectScript file-sync watcher disarmed; the Angular bundle built with `outputHashing: all` and served by the static handler; CI runs the ObjectScript unit and HTTP integration suites, the client unit tests and AD-27's inventory fixture against a throwaway container; upgrade is "install again", with OcuPilot's state carrying a schema version that migrates forward on first start and never in a request; downgrade unsupported; transcripts and the ledger purged by a scheduled task with an operator-visible retention setting; proposals short-lived by construction; progress records temporary and dying with the turn. A Prometheus endpoint is optional and, if built, must not make an entity name a label.
- **Failure posture:** a failed audit marker never fails a write; a failed metric never fails a request; a failed provider call surfaces as a turn error, never an exception to the client; a denied privilege is reported, never retried.

**Security and trust boundary**

- **Untrusted content never becomes instruction** (AD-11, NFR-6). Five checkable rules: untrusted text enters only as delimited tool-result content, never the system prompt (a build-time constant) and never the user role; no write without a confirmation on a server-computed diff, and no confirmation is ever model-initiated; **navigation is a proposal of a route, not an action**, restricted to the descriptor registry and announced before it happens because moving the user changes what leaves the instance next turn; nothing rendered from a reply, tool result or progress record issues a request to any host, and the rendering path is markup-free by construction; a seeded-injection test asserts zero proposals, zero navigations and zero outbound requests.
- **Silent-first JWT, Bearer-only authorization, per-tab tokens** (AD-28, adopted). Two web applications: `/ocupilot` unauthenticated static serving like the vendor's `/ui/interop`; `/api/ocupilot` password-authenticated, JWT enabled, `UseSession = 0`, joined to the same `GroupById` group as the vendor's management applications. Sign-in attempts an empty-body `POST /api/ocupilot/login` first. **Only `Authorization: Bearer <access>` authorizes a request; a cookie never does.** Refresh is `POST /api/ocupilot/refresh` with the refresh token **in the JSON body** - sent as a Bearer it is refused - and is a background concern of the API service, never something a screen or the panel handles, because a turn can outlive an access token. Sign-out carries both the Bearer and the cookie; Bearer alone leaves the browser-level login intact. Token lifetimes stay at the vendor-matching 60/900. Development proxies through the IRIS origin because the browser-id cookie is `SameSite=Strict`.
- **The static origin is treated as hostile ground** (AD-47). A token minted from the browser's login is available to anything on the instance's origin. OcuPilot serves its own bundle with no user-supplied content and no runtime evaluation of fetched text, stores its token pair in per-tab storage with no cross-tab broadcast, treats the deep-link fallback as a file server that never reflects its input, and ships a restrictive CSP naming only the instance's origin - achievable precisely because NFR-10 forbids any CDN. **Development does not relax this**; CORS is a non-goal in both settings.
- **The SPA never uses a relative API URL** (AD-20). Every API path is absolute from the origin root through one API service that refuses a relative path, because the deep-link fallback would otherwise answer a mis-resolved request with `index.html` instead of JSON - silently.
- **No caller value is concatenated into SQL, and no endpoint accepts a path** (AD-21). Every statement binds parameters; shape validation never substitutes for binding. **No OcuPilot endpoint accepts a filesystem path from a caller, anywhere.** Where a file is served the caller names it from a **fixed enum** and the directory comes from `$System.Util.ManagerDirectory()` at runtime. The static handler resolves a caller-supplied name under both a literal `..` rejection **and** a post-normalization prefix containment check. **The manager directory is not a constant and the file moves under you:** `messages.log`'s location is operator-settable so the path is resolved per call and never cached, and the instance rotates the file at its configured maximum size, so FR-62's tail validates its offset against the file's current identity and restarts cleanly. **Anonymous does not mean unprivileged:** on a Minimal-security instance `%Service_CSP`'s `UnknownUser` holds `%All`, so every gate resolves the **authenticated** user and rejects `UnknownUser` and `_PUBLIC` explicitly; no gate infers authorization from roles alone.
- **Secrets never reach a surface OcuPilot itself displays** (AD-35). OcuPilot shows the instance's own error and message logs, so `ProviderPort` never lets a credential enter an exception, status, log line or trap: the key is fetched at the point of use, held in a variable cleared before return, and never interpolated into a URL, message or error. The same binds any code handling a wallet secret, an X.509 private key or a password field. A test asserts a forced provider failure leaves no credential material in the error log.
- **Provider egress is an allow-list, not a free-text URL** (AD-42). An agent definition's endpoint decides where the instance's data goes: writing it requires the OcuPilot administrative resource, it validates to an absolute HTTPS URL (or an explicitly declared local address for the OpenAI-compatible adapter), it cannot name the instance itself or a loopback or link-local address unless the definition is explicitly marked local, and it is audited as a security change. One provider base with four adapters, Anthropic's message shape as canonical, and an ordered credential ladder that never returns a value into a status or error. Every call carries a bounded timeout and retries only on a retryable status with the delay the greater of the provider's hint and an exponential backoff - and **a call that threw mid-flight is never retried**, because the request may already have been processed. The context chip's "leaves the instance" statement is computed from this same configuration.
- **Outbound TLS is configured at install, never defaulted** (AD-32). `ProviderPort` uses a named SSL configuration the installer creates if absent, with server-identity checking on; never hardcoded to whatever the harvested code used and never left to `DefaultSSL`. Proxy settings are configuration, not code. Test connection exercises the same path as a real turn.
- **The progress channel is untrusted content in protected storage** (AD-33). Progress records live in OcuPilot's protected storage keyed by turn and owned by the starting user; a poll for a turn the caller does not own is a **404, not a 403**. Everything from the model or a tool result is untrusted content the panel renders as data, never as markup or as OcuPilot's own voice, under the same egress rule as a reply. Progress is capped per turn and dies with the turn.
- **Governance is polish-week work whose shape is fixed now** (AD-22). Two things are built into the Release 1 floor and cannot be retrofitted: every tool declares `read` or `write` at definition time and a tool declaring neither **fails the build**; and the tool dispatch path has a single call-time gate point, evaluated after the caller's identity is resolved and before any port is touched, returning "allowed" for everything not prohibited. When policy ships, keys are `tool` or `tool:action`, the frozen baseline captured at the Release 1 freeze means "pre-existing, therefore enabled", a key absent from it is disabled by default when it mutates, the baseline is never regenerated to grow, layers resolve with a null-coalescing cascade so an explicit `false` at any layer is honored, the read-only preset blocks anything it cannot classify, a denied call returns a structured result while the tool stays advertised, and the audit ledger is configuration rather than a governed tool.

**Data contracts and cross-cutting mechanics**

- **One error envelope, one response writer** (AD-12, AD-39). Handlers never `Write` to the response; success goes through one `Response.JSON`/`JSONStatus` and failure through one `Error.Render(status, slug, reason)` with a flat `{error, reason}` payload and the slug from a fixed enum. **Inside a nested `Catch` the return is `Return $$$OK`, never a bare `Quit`** - a bare `Quit` resumes the enclosing `Try` and writes a second envelope. A test asserts no response body contains `}{`, paired with a test that every error path returns exactly one well-formed envelope with a slug from the enum; the response writer is the only code permitted to write to the response device. The wire envelope also carries a **stable machine code** and an optional structured detail object: the screen renders the human half, a tool result the machine half. No slice adds a field for its own use.
- **Entity ids are percent-encoded in exactly one path segment** (AD-13). Routes are `/ocupilot/<area>/<screen>[/<id>]?ns=<NAMESPACE>`, encoded and decoded by one shared pair of functions, round-trip tested against a fixed corpus including a leading underscore, a slash, a space, a percent sign and a non-ASCII character. **An id is never an identity on its own:** every reference crossing a boundary carries the triple `(entity type, scope, id)` where scope is the namespace for a namespace-scoped object and the literal `instance` for a configuration object - a task named `Nightly purge` in `USER` and one in `HSCUSTOM` are different entities, and without the scope a confirm could re-read the wrong one and find a matching fingerprint.
- **A confirmed write emits one change event; screens re-fetch, never patch** (AD-14). A confirmed write - and a screen editor's own Save - publishes the scoped triple plus an action on one client-side event bus. **The entity-type vocabulary is a single closed enum owned by the kernel**, not a string a slice invents; a descriptor selects from it and the build fails on an unknown value. No screen mutates its own rows from a write response. The bus does not cross tabs.
- **Live data has one framework, and the proposal pause is part of it** (AD-43). A screen declares in its descriptor whether it refreshes and its permitted rates; the framework owns the timer, the persisted per-screen setting, the silent re-fetch, and preservation of sort, filter, selection and scroll, refreshing through the same read as everything else. The proposal lifecycle publishes **proposal-open and proposal-closed events for a scoped entity type** on the same bus - that is the channel the pause rides on, and without it the UX's rule has nothing to listen to.
- **The read contract is uniform, bounded, and the same for a screen and a tool** (AD-36). A screen's list and its read tool resolve through **one** descriptor-declared read so they cannot diverge in filter, sort or field set. Every read is bounded by a max-rows cap and reports whether it truncated; nothing returns an unbounded collection. The tool's view is the screen's view narrowed by the context cap and stripped of secret-typed fields, never a wider or separately written query. Paging is by explicit cursor where the route offers one and by the max-rows cap where it does not.
- **Screen context is capped, declared per screen, and reported** (AD-24). An instance-wide cap of **200 rows**, operator-settable, truncating rather than refusing, recording the number actually sent so the read tool-call card can show it. **The cap is on content, not only on rows:** the payload is bounded by total size as well as row count and each field truncated to a declared maximum with the truncation marked. Secret-typed fields never leave the instance regardless of the cap. A serializer emitting an uncapped collection or an unbounded field is a review failure.
- **Namespace is switched by explicit save and restore** (AD-16), with the restore as the **first** line of every `Catch`. `New $NAMESPACE` is never used in a dispatch handler.
- **Routes map back to the classic portal's resource keys, and namespace is a first-class parameter** (AD-44). The classic portal keys custom page resources by normalized page URL, so each descriptor declares the classic page it replaces and the privilege set is the union of the admin API's requirement and any custom resource assigned to that key; a screen with no classic equivalent says so explicitly. **The namespace in the route is data scope, not decoration:** it selects the namespace every read and write executes against, is carried into proposals and change events, and switching it re-fetches rather than re-routing.
- **The application error log goes through `SYS.ApplicationError`, and its deletes are ordinary writes** (AD-48). The supported `%SYS` API - `NamespaceList`, `DateList`, `ErrorList`, `ErrorDetail` queries and `DeleteByNamespace`, `DeleteByDate`, `DeleteByError` - with no `^ERRORS` traversal of OcuPilot's own. **Probed: `SYS.ApplicationError` does not exist in `HSCUSTOM`**, so `LogSourcePort` switches to `%SYS` once and the target namespace travels as a **parameter** on every call; no slice writes `Set $NAMESPACE` for this path. **One namespace source:** the level the user has drilled to, carried in the descriptor state - the route's `?ns=` does **not** reach this port, because two sources would let a fully compliant delete purge a namespace other than the one on screen with a matching fingerprint and a correct-looking audit marker. **Three delete scopes, not two:** by namespace, by date and by error; `DeleteByDate` exists and is either implemented or explicitly refused. **The fingerprint is the enumerated id set, never a count or a live re-query** - a proposal enumerates at proposal time the specific error ids it will remove and confirm deletes exactly those; residue from errors logged in between is correct and the card says so. **The captured payload is secret by default:** an `^ERRORS` entry holds every local variable at every stack level plus `$ROLES` and `$USERNAME` for whichever application faulted, there is no template to classify against, so it never enters screen context and is never sent to the model - the read tool returns summary fields only (time, error number, routine, line, error text) while the user reads the full variable table on screen. On an IRIS for Health instance those tables can hold patient data. **The gate is resolved per namespace** - `^ERRORS` is unmapped and lives in each namespace's own globals database, so the required permission is a function of the selected namespace (`%Admin_Operate` plus read and write on that database), which a single static descriptor resource cannot express.
- **Harvested handler bodies keep their call sites** (AD-23). An OcuPilot base class exposes `RenderResponseBody(pStatus, pMsgPart, pResPart)` - the same signature the harvested code already calls at all 738 of its call sites - emitting OcuPilot's envelope instead of `%Atelier.REST`'s. Handler bodies are not edited to change response shape.

**Coding conventions (project rules plus spine)**

- Package `OcuPilot`, source under `src/OcuPilot/`; no `%` or `_` in class, property, parameter or method names; parameters `p`-prefixed, locals `t`-prefixed, properties capitalized bare, class parameters via `..#NAME`; class names kept short enough that the compiler does not hash the storage global.
- Tool naming `<area>.<screen>.<verb>`, lower case, dots only; `read` for the one read tool per screen; write verbs match the row action. **No `iris_` prefix.**
- Angular: one folder per area under `ui/src/app/areas/<area>/`; a screen is `<screen>.page.ts` + `<screen>.store.ts` + `<screen>.descriptor.ts`; shared shell components under `ui/src/app/shell/`. **Design tokens only - no hardcoded colors, enforced by lint.**
- ISO-8601 UTC via `$Translate($ZDateTime($ZTimeStamp, 3, 1), " ", "T") _ "Z"`; never raw `$ZDateTime`, never `$Horolog`.
- Methods returning `%Status` open `Set tSC = $$$OK` and close `Quit tSC`; every caller checks `$$$ISERR`; argumented `Quit` never appears inside `Try`/`Catch`.
- Normalize `$Char(0)` to `""` at every read site of a `%String` property whose write path includes a SQL `UPDATE`.
- List properties on `%Persistent` classes project to a subtable or are remodeled as relationships; an embedded `$LIST` needs a comment saying why; **storage sections are never hand-written**.
- Redaction is **schema-driven** - a field is secret because its descriptor says so, not because its name matched a pattern (a wallet secret field named `Value` defeats any matcher); a name-pattern matcher runs only as a backstop that can add redaction, never remove it.
- One structured logger, one line per event, JSON payload, secrets redacted before emission; audit emission never throws and never fails the operation.
- Config is instance-level in the protected database; **no environment variable is required for OcuPilot to run**.
- Tests: every handler gets an HTTP integration test asserting status, content type and body shape; every tool gets a round-trip test over its generated schema; encoding, timestamps and Base64 are round-trip tested, never assert-on-encode-only; **test classes carry no property whose name begins with `Test`**.
- **No shipped class contains embedded Python**; any Python is an operator prerequisite, never an install action.

**Harvest requirements (siblings are pattern and code sources, never runtime dependencies)**

- **Step 0 harvest, take early:** iris-couch `Util/Response.cls`, `Util/Error.cls`, `Util/Log.cls`, the `API/Router.cls` thin-wrapper and `OnPreDispatch` structure (the structure, not its 90 CouchDB routes, keeping all three UrlMap ordering invariants), `AdminUIHandler.cls` (traversal checks, `IsHashedAsset` cache headers, deep-link fallback, 32 KB streaming), the `Installer.cls` idempotency shape, `couch-api.service.ts`'s absolute-base-path discipline, `error-mapping.ts` and `feature-error.component.ts`, and the `MakeRequest` static test helper. From iris-execute-mcp-v2, `Utils.cls`'s namespace switch/restore, validators, `SanitizeError`, `ApplyOutputCeiling`, `SurrogateSafeCutLength`, `DecodeUtf8Stream` and `ReadRequestBody` - **take this early, everything downstream uses it** - plus `probeCustomRest`'s quad-state model ported to ObjectScript.
- **Step 2 harvest, ~2,200 lines rename-only from iris-session-agent:** `LLM/Provider.cls` (598, adding the configurable SSL and proxy support it lacks), `LLM/AnthropicProvider.cls` (757, the only Release 1 provider), `Util/RetryWithBackoff.cls` (440, keeping the mid-flight idempotency rule), `Util/EnvSecret.cls` (~160, **swapping rung 2** because `Ens.Config.Credentials` needs an interop-enabled namespace that plain Community may not have), `Agent/{CallerContext,TurnResult,ProviderResponse,ProviderOverride}.cls` (~390, keeping the invariant that tools never touch `%session`, `%request` or `$NAMESPACE` - exactly what AD-7's detached job requires), `Audit/{Emit,LlmCall,ToolCall}.cls` (629, extending for the agent marker), `Chat/History.cls` (249, keeping the per-conversation exclusive-lock protocol), the locked cross-vendor JSON-Schema subset rule, `Tool.Search.Base.BuildBoundedWhereClause` (246), and the 11 config-form validation rules with the XOR credential invariant and preserve-when-customized cascade - **keeping the absence of an `ApiKey` property, which is the schema invariant.** The other three providers and the message and tool-def adapters copy at **build step 7**, not before.
- **Rewrite, do not port:** `Agent/AgentLoop.cls` (930) - synchronous by construction and with no context-window trimming at all. Take the 10-step flow and the max-iteration fallback as the design.
- **Improve while porting:** `Tool/Registry.cls` (323) - replace the flat-`Super` equality SQL with `%IsA` or a recursive walk, and add the schema-driven argument validator the original lacks.
- **Do not take:** iris-couch's cookie session (no `SameSite`, no `Secure`, no CSRF), its per-database RBAC, its `proxy.conf.js` route-exclusion regex, its incomplete `module.xml`; the `%Atelier.REST` envelope; iris-execute-mcp-v2's TypeScript self-install and `%Development`-gated web application pattern; iris-session-agent's Zen chat panel, `chat-panel.js`, `EnsPortal/*`, `UI/ChatPanel.cls`, `Sample/*`, the 28 Ensemble tools and `Search/*` vocabulary learning - keeping only the panel's JSON envelope shapes (bootstrap context, tool-call card, citation chip, lock-poll response).
- **Rename checklist, every name absent from OcuPilot's source:** packages `SessionAgent.*`, `ExecuteMCPv2.*`, `IRISCouch.*`; web paths `/csp/<ns>/sa-static/`, `/api/executemcp/v2`, `/iris-couch/`; roles `SessionAgent_ReadOnly`, `IRISCouch_Admin`; audit sources `SessionAgent`, `IRISCouch`; globals `^SessionAgent*`, `^SessionAgenC88B*`, `^IRISCouch*`, `^UnitTestRoot`, `^ExecuteMCPv2*`; SQL schemas `SessionAgent_Chat`/`_Audit`/`_Search`/`_Config`; credentials `SessionAgentOpenAI`/`Anthropic`/`Gemini`; tasks `SessionAgent.Purge*`, `SessionAgent.UserVocabularyDecay`; SQL procedures `ExecuteMCPv2.Setup_*`; tool prefix `iris_*`; every `IRIS_*` environment variable; `%ALL` mapping creation; `window.SessionAgentChat*`, `--sa-*`, `--ite-*`.
- **Traps carried forward:** the CSP Gateway not being notified of a created application; the anonymous `%All` hole; compiler-hashed storage globals from over-long class names; the double-envelope bug class; a hand-kept manifest drifting.

**Integration and API preference**

- **API preference order:** a documented official route first; the admin API second; a custom OcuPilot API endpoint only where neither exists. **The Atelier API is not used in Release 1** - `/api/atelier` has JWT disabled and sits outside the `%ISCMgtPortal` group, and enabling JWT would mean modifying a vendor web application, which OcuPilot does not do on an operator's instance.
- **Custom endpoints in Release 1:** the agent runtime (roughly seven - run turn, progress channel, load transcript, lock state, agent definition CRUD including read-only and kill-switch state, credentials list, tool list), messages.log paging, the application error log, and the alerts.log history tail. Built on OcuPilot's own `%CSP.REST` dispatcher on the iris-couch patterns, never the MCP suite's `%Atelier.REST` envelope.
- **The monitoring API is unauthenticated on the instance** - `/api/monitor/metrics` answers anonymously - so **every port carries its own authorization gate** (AD-29): `AdminPort` inherits the vendor's `ResourcesOR()`, and the others declare the resource their screen descriptor names and evaluate it with `$System.Security.Check` before any call. A metric, log line or audit row reaches a user through OcuPilot only if that user could have read it directly. A port without a named gate is a review failure.
- **The management API refuses to return the document for one vendor service**; the explorer shows the refusal.
- **The vendor's Angular editors are all interoperability editors**; none of the six areas' classic pages is an embeddable bundle, so those screens are rebuilt and FR-9 links to the classic page. They are not embedded in Release 1.

**Build order, which is also the cut line (PRD 10.1)**

0. Shell and install path: sign-in, navigation, page chrome, error handling, the version guard, the IPM module, the Docker path, the installer, the OcuPilot API skeleton.
1. Shell reads plus one live list per area with its read tool, and the messages.log and application error log endpoints.
2. Agent co-pilot core with one confirmed write per area and the demo fixtures: the panel, turns with progress, the proposal lifecycle in its floor form, the agent marker, the Anthropic provider, agent configuration and the first-login gate, enforced read-only and the kill switch, screen synchronization and navigation. **SM-3 is met at the end of this step.**
3. The remaining list and detail screens with their read tools.
4. The remaining small write actions: enable, disable, run, suspend, resume, terminate, delete, auditing on and off, the OAuth 2.0 deletes, on-demand task run, application error deletes.
5. Medium editors: web application create, user and role create, resource, device and wallet editors, X.509 import, audit event configuration.
6. Large editors in order: user edit and web application edit first, then role edit, service edit, SSL/TLS, LDAP, the task wizard and edit task.
7. Stretch in order: the remaining provider adapters; the per-user read-only toggle; the remaining safety hardening - target fingerprint re-read, typed-name confirmation for destructive tools, per-user turn limits, the seeded-injection test.

**Gates, floors and dated checks**

- **2026-09-14 listing build:** steps 0 and 1 plus a README with install steps and a description. A screens-only build is admissible for the listing but not for the application.
- **2026-09-27 application floor, binding:** steps 0 to 4 complete; at least one create or edit form per area from step 5; no list screen in the six areas linking out to the classic portal; SM-3 met (each of the six areas has at least one live-backed list and at least one agent-proposed, user-confirmed write); the UJ-3 demo reproducible end to end on a clean install.
- **A step is complete when its build passes the smoke script on a clean container.** No P1 item starts while a step 1 or 2 item is unfinished.
- **First-week checks:** 2026-09-09 export the 82 admin API endpoint classes; 2026-09-10 prove the install path on the durable volume from a clean clone including down/up, up with a newer image and up without a volume, and design the protected state into it; 2026-09-11 read the field lists out of the backing models (`%SYS.Task`/`%SYS.TaskSuper`, `%CSP.UI.Portal.EnsembleMonitor`, `%CSP.UI.Portal.Audit.*`); 2026-09-12 the Open Exchange listing submitted for review; 2026-09-13 prove a turn longer than the stock 60-second gateway timeout completes on an unmodified container and verify auditing on a fresh container. **2026-09-23 demo freeze** - anything landing after it that touches UJ-3 forces the description and any video to be redone.
- **Superseded, do not build:** the Web Gateway response-timeout prerequisite (AD-7 removed the reason; the installer reports the value as information only); raising the access-token lifetime to 300 s (AD-1 removed the reason; 60/900 kept); "exercise the payload on the instance" as the first task of every write story (AD-3 and AD-27 do it once, in CI, for every endpoint).

**Post-contest stages (PRD 10.3, extract-stages.md)**

| PRD Stage | Rows | S / M / L | New REST endpoints | Hard dependencies |
| --- | --- | --- | --- | --- |
| 2 - the rest of the admin API (P2) | 59 | 20 / 31 / 8 | 3 | admin-v2 write payloads observed; async-result polling; SH-24 directory allow-list; the vendor's support stance on `/api/admin` |
| 3 - System Explorer over the Atelier API (P2) | 36 | 17 / 15 / 4 | 0 | the `action/query` DML/DDL guard (EX-15) shipping with EX-14; Atelier v7 for the XML routes; ETag on `PUT /doc`; the iris-table-editor harvest; `%Service_DocDB` |
| 4 - Interoperability over interop-editors v7, with an Analytics rider (P2) | 41 | 10 / 25 / 6 | 4 partial | SH-23 JWT/cookie hand-off to `/ui/interop`; SH-25 namespace gating; the `UpdateProduction {action}` vocabulary; a DeepSee-enabled namespace for the rider |
| 5 - custom-REST parity from the MCP suite's handlers (P3) | 165 | 60 / 79 / 26 | 128 | the OcuPilot API router; the handler harvest; legacy CSP source pulled from the container; DT-11 before DT-09/DT-10 |
| 6 - the long tail, on demand (P4) | 56 | 11 / 29 / 16 | 32 | demand plus each group's license, edition, platform or deprecation gate |
| **Stages 2-6** | **357** | **118 / 179 / 60** | **167** | - |

The agent grows in step: Stage 2 confirmed single writes over the admin-v2 remainder plus wallet-backed keys, context-window management and proxy/custom-CA support; Stage 3 single writes over Atelier plus the agent picker and the free-form SQL tool behind EX-15's guard; Stage 4 guided multistep workflows and Investigate entry points; Stage 5 the 28 iris-session-agent tools plus undo by snapshot and revert; Stage 6 adds nothing to the agent. Token streaming is **not** here - it moved into the polish week by owner decision.

**Open questions still live (external, not blocking)**

- What technology bonuses apply to contest 48, and is an entry covering only some of the six areas accepted? (2026-09-14 kick-off; the coverage half is moot if all six ship.)
- InterSystems' support stance on `/api/admin`, and whether Group by ID and the browser-id cookie survive future releases. (Kick-off. Group by ID is now load-bearing for more than silent login - the classic-portal fallback depends on it too.)
- When are winners announced? (Not stated in any source read.)
- Do install and the credential rungs work on plain IRIS Community, where install falls to `USER` and the namespace may not be interoperability-enabled? **Deferred with an owner and a trigger:** tested after the 2026-09-27 application floor is built, not before the listing. Until then FR-68's plain-Community claim is untested and a late failure is an accepted risk.

### UX Design Requirements

Actionable work items from the UX design contract (`DESIGN.md` for how it looks, `EXPERIENCE.md` for how it behaves). `DESIGN.md` and `EXPERIENCE.md` take precedence over any mock, wireframe or import; `EXPERIENCE.md` -> *Fixed strings* is canonical over every other quotation of a string, including `DESIGN.md`'s.

**Foundation and tokens**

UX-DR1: Implement the **V3 Lantern design-token layer** as an Angular Material 3 brand-layer delta - Material 3 role values replaced with Lantern's, plus the OcuPilot roles Material has no word for: `shell` / `on-shell` / `shell-edge`, `agent-accent` / `on-agent-accent` / `agent-container` / `on-agent-container`, `change-highlight`, `egress-warning` / `-container`, `restrained` / `-container`, `destructive` / `on-destructive` / `-container` / `on-destructive-container`, `success` / `-container`, `warning` / `-container`, `info` / `-container`, `code-surface` / `on-code-surface`, `focus-ring` / `focus-ring-inner`, and the four `server-flag-*` / `-container` pairs. Light values on the bare role, dark under `<role>-dark`. Whatever the tokens do not override inherits Material 3 as-is: state-layer opacities (8% hover, 10% focus, 12% pressed), ripple, scrim, the 38% disabled opacity, and checkbox, radio, switch, form-field and tab anatomy.
UX-DR2: Enforce **design tokens only** - no hardcoded colors anywhere in the client - with a lint rule that fails the build.
UX-DR3: Implement the **type ramp**: `display` 16/600/1.25/-0.01em, `title` 14/600/1.3, `body` 13/400/1.4, `caption` 12/400/1.35, `label` 11/600/1.2/+0.04em, `code` 12/400/1.5 monospace. 13px body is the floor for running text; nothing readable below 11px; tabular right-aligned numbers in tables; weight 600 marks the current thing and **700 does not exist in the UI**; uppercase only for `label` eyebrows and column headers.
UX-DR4: Vendor **Inter** and **JetBrains Mono** (both OFL) as woff2 in the bundle with `system-ui` and `ui-monospace` fallbacks. **No CDN, no Google Fonts URL** (NFR-10). Anything the instance would treat as an identifier is set in `code`, in tables and prose alike.
UX-DR5: Implement the **4px spacing scale** (4 - 8 - 12 - 16 - 20 - 24 - 32) with the assigned meanings (4/8 inside a component, 8 between controls in a bar, 12 card and panel padding, 16 between regions and around the content column, 24 between form sections and inside dialogs, 32 above an empty state) and the **density contract**: 13px type, 36px rows, 32px controls, 6px radii, 28px log rows. Whitespace is spent between regions, not inside tables.
UX-DR6: Implement the **shape tokens**: `sm` 4px, `md` 6px (default), `lg` 12px, `full` 9999px, with their assignments - the instrument surface crisp at 4-6px while anything pressed is a Material pill, so the action color and the action shape coincide. The avatar is a 6px rounded square because it is a crop of a rectangular panel.
UX-DR7: Implement **tonal-first elevation**: the seven-layer surface stack (Ground / Side / Container / Raised / Sheet / Chrome / Code) with hairlines in `outline-variant` doing the separating, and four shadow levels used only by things that float - level 1 for the live proposal card alone, 2 for menus, command-box results, tooltips and popovers, 3 for dialogs and toasts. Shadows are tinted with the shell navy in light mode. **Nothing uses elevation for hierarchy inside a screen.**
UX-DR8: Implement the **motion budget**: 120ms opacity or transform fades, the panel's width change to and from `panel-home` over 120ms, no bounce, no slide-in for the panel, and the change highlight settling over 2s then holding. Under `prefers-reduced-motion`: instant state changes, no width transition, no skeleton pulse, static highlights, and the word "running" in place of spinners.

**Contrast and color discipline (the accessibility floor in `DESIGN.md`)**

UX-DR9: Meet the **measured contrast table** as the acceptance floor in both modes - 4.5:1 for text, 3:1 for non-text and focus indicators - covering all 23 load-bearing Material pairs and the 22 further pairs `DESIGN.md` computes for its own components.
UX-DR10: Add **guard tests for the three marginal pairs**: the `secondary` name link on a selected row (4.56:1 light), the toast's `secondary` link on `inverse-surface-dark` (4.64:1 dark), and the `restrained` gated reason on a keyboard-active menu row (**4.497:1 in dark - fails**, so the active row draws the caption in `on-secondary-container` instead).
UX-DR11: Never draw the **four measured-and-rejected pairs**: `on-shell` at 72% on `shell-edge` (3.60:1 - the header's eyebrow is 100% instead, so no text in the header is ever drawn below 100%); the retired gradient rail indicator (1.94-3.10:1 over its upper half - the indicator is solid `secondary-dark`); the expired proposal card at 60% opacity (2.77-4.38:1 - hence dim-by-role); and light-mode `agent-accent` on `shell` (1.80:1 - the attention dot uses `agent-accent-dark`).
UX-DR12: Implement the **seven color rules** as reviewable constraints: (1) the chrome does not change with the theme, so anything drawn on it takes the dark-mode variant in both modes - `focus-ring-dark` with a `shell` halo, `agent-accent-dark` for the attention dot, `secondary-dark` for teal; (2) gradients are the header (`shell` -> `shell-edge`, 90deg) and exactly two 2px hairlines (the panel header rule, horizontal navy-to-teal; the panel's docked-edge stripe, vertical teal-to-navy), whose far stop is the logo's vivid `#2090A0` - deliberately outside the token set, never under text and never filling an area; (3) teal is text only where it clears 4.5:1, so links inside a code block or the raw log are `on-code-surface` underlined, not teal (2.69:1 in light); (4) **yellow is never a control** - no button, link, switch, chip or badge uses `agent-accent`, `agent-container` or `change-highlight`, and yellow is never a warning color; (5) two kinds of disabled - *unavailable* is Material's 38% opacity, *privilege-gated* stays readable in `restrained` (or `on-shell` at 45% on the chrome) with no hover and the reason always available; (6) semantic pairs travel together, `<role>` on `<role>-container`, never a container as text and never one role's text on another's container; (7) **dim by role, never by opacity** at full opacity, because a receded card is still read - a reloaded transcript is made of them.
UX-DR13: Enforce **three colors, three meanings, never trading places**: navy = the instance's chrome (rail, header, status bar, constant across modes); teal = *do something* (every button, link, selected item, active tab and running indicator - the sole action color, so Material's button, link and selection roles map to `secondary`, not `primary`); yellow = *the agent* (its avatar's ground, its rationale and expected impact, the bar on its proposal card, and the one row or field it just changed).

**Brand assets**

UX-DR14: Wire the **logo asset pipeline**: the reversed horizontal lockup at 32px directly on the navy header (no plate, no ground, no hover state), the mark alone where only the mark fits (a slot under ~170px), the **navy-wordmark light lockup** on light grounds only (the form-login card, README, About - it is 1.02:1 on the shell and must never touch the chrome), the globe-iris favicon exported at 16, 32, 180 and 512px, and the robot crop as the agent's avatar at 256px and 64px. **The wordmark is never typeset** in Inter or any face, and the eye-and-globe motif has exactly one assignment - never an empty-state illustration, sign-in hero or watermark. The seven transparent files are flood-fill cutouts an owner vector export supersedes file for file.
UX-DR15: Ship **icons**: the owner's set when it lands; until then one vendored Material Symbols Outlined glyph per slot (allowed under NFR-10, replaced file for file). **Never an initial in a circle**, which reads as a wireframe in a screenshot.

**Shell layout**

UX-DR16: Build the **VS Code-shaped shell** present on every route: header 48px (logo-lockup left, command-box centered at 360px, namespace switch right) - full width, never scrolls; rail 48px on the chrome, flush with the header, eight items in daily-use order (Home - Logs - OS management - Tasks - Permissions - Web applications and REST API explorer - Security and secrets, with Agent co-pilot pinned bottom); side-bar 240px **fixed, no drag handle, no sash, no `col-resize` cursor**; content taking the remaining width, never below 640px, holding locator-bar (40px) over command-bar (50px) over the screen; panel docked right at 400px default / 320px minimum / `panel-home` on Home, **the only resizable edge in the shell**; status-bar 24px on the chrome, read-only except the user segment.
UX-DR17: Implement the **yield order**, continuous at every width and undone in reverse: (1) the side-bar auto-collapses, keeping its remembered state; (2) the panel shrinks toward 320px, only as far as needed; (3) content holds 640px and scrolls horizontally inside its own region. **Never** an overlay, a bottom sheet, a panel close, or a scrolling header, rail or status bar; the page body never scrolls horizontally. Meet the published width table at 1,920 / 1,440 / 1,280 / 1,024 / 900px for both Home and a list route.
UX-DR18: Implement **Home**: six `area-tile`s in an auto-fit wrapping grid (never a horizontal scroll), each captioned with its Release 1 side-bar entries so the contest's parenthetical screens are visible on Home; the instance line beneath; the panel widening to `panel-home` = `min(50vw, viewport - rail - content-min-width)` over a 120ms transition and restoring the remembered width on leaving. Home has no side-bar screen list, so its rail-item navigates and collapses the side-bar.
UX-DR19: Honor **reflow**: every height is a `min-height` except inside the virtualized lists; form-pages, banners, the transcript, the proposal card and the tool-call card reflow at any width; only data-tables, the raw log view and code blocks claim two-dimensional scrolling (WCAG 1.4.10 exception), each scrolling inside its own container. At 200% zoom on a 1,440px laptop the CSS viewport is 720px, so yields 1-3 apply and the panel's full-screen toggle is the transcript's accommodation.

**Shell components**

UX-DR20: `rail` and `rail-item` - 48x48 hit area with a 20px centered icon; the six documented states (rest at 72% opacity, hover with an 8% background and a 300ms tooltip, active with a **solid 3px `secondary-dark`** left-edge indicator inset 8px, focus with the on-chrome ring, privilege-gated at 45% with no hover and the resource tooltip on hover **and focus**, and the agent entry's attention state). Tab reaches the rail as one stop; Up/Down move between items; the active item carries `aria-current="page"`. **Never a count badge.** A rail-item opens the side-bar for its area and does not navigate by itself; clicking the active item collapses the side-bar.
UX-DR21: `attention-dot` - `agent-accent-dark` in both modes with a `shell` ring, at the icon's top-right, on the Agent co-pilot rail entry only. It means the agent is unconfigured, the kill switch is on, or a definition needs attention, states the reason in its accessible name, and clears the moment the reason clears. **The only badge on the rail.**
UX-DR22: `side-bar` - 240px on `surface-container-low` with a 1px right edge; the area name as an uppercase `label` eyebrow; 28px entries with the five documented states, the current route marked `aria-current="page"`. Open/closed state remembered per browser; opens on rail click and collapses on the same click, Ctrl/Cmd+B, or the yield order. **A screen not yet built does not appear** - no dead entries. Gated entries stay listed and focusable with the reason **inline after the name** as well as in a tooltip.
UX-DR23: `header` - the 90deg `shell` -> `shell-edge` gradient band, the one place the gradient fills an area. The namespace switch sits at the gradient's `shell-edge` end with a 100%-strength `label` eyebrow over the namespace name; choosing a namespace updates the route's `ns` parameter, re-fetches the current screen and updates the context chip. **No URL rewriting into another web application, no dialog.** Nothing else lives in the header.
UX-DR24: `command-box` - a 360x30px field with `role="combobox"`, `aria-expanded`, `aria-controls` and `aria-activedescendant`, opening on click or Ctrl/Cmd+K, with the chord shown **once** as a kbd chip at the field's right edge (never repeated in the placeholder). Typing filters every screen the user may open plus the current screen's command-bar actions, matching **alias lists drawn from the contest wording** ("web apps", "REST", "x509", "certificates", "CPU", "disks"); results are a `listbox` grouped by `role="group"` for Screens and Actions with a polite count. Enter navigates or runs; Escape closes and returns focus. Gated results stay listed and arrow-reachable as non-selectable rows with the reason inline - never Material-disabled items, which the key manager skips. **It is not a channel to the agent** and never shows the avatar.
UX-DR25: `status-bar` - a 24px chrome band in `label` sentence case: server, instance name and version, the user, licensed-to on the left; `server-flag-badge`, the auto-refresh stamp and the connection state on the right, the state's colored disc always followed by the state word. The **user segment is the bar's one interactive element**, opening the account menu (Sign out; polish week adds Change password and the theme toggle). Nothing else is interactive or has a hover state.
UX-DR26: `server-flag-badge` - an 18px pill, `<flag>` on `<flag>-container`, one pair per flag with Live in red matching the classic portal; in dark mode a 1px `on-shell` 20% edge because the Live container is 1.15:1 on `shell-dark`. It appears in the status bar and on Home's instance line, **never in the header**, and the word is always present.

**Screen components**

UX-DR27: `locator-bar` - a `nav` named "Breadcrumb": area > screen > selected entity, separators `aria-hidden`, the current segment `display`-sized, `on-surface` and not a link, the entity segment in `code` appearing on selection and dropping when it clears. Each segment navigates. **The namespace is not a segment.**
UX-DR28: `command-bar` - 50px holding the primary action as `button-primary` (Create / Import), the filter field (220px, a field not a button, with a polite match count), the View menu, sort, the auto-refresh chip on auto-refresh screens, further actions as `button-text`, and the last-update stamp right-aligned. Row actions are `aria-disabled` with "Select a row first" when nothing is selected. **Every command-bar action is reachable from the command-box, and every row-menu item is here** - the command-bar is the always-available path to a row's actions.
UX-DR29: `data-table` - a Material table on the sheet inside a 1px border, driven by **CDK virtual scroll over a capped fetch** (default 1,000 rows, persisted per screen with sort and filter); 36px sticky header in `label`, 36px body rows with `code` identifier columns; **the name cell is a link and looks like one** (teal, underlined on hover and focus, pointer cursor) so clicking the name (open) and clicking the row (select) read as different gestures; a 7px status disc before the enabled/disabled word; "(none)" for empty values; the row-overflow trigger last; a footer with the row count and an **editable, labeled max-rows field** and no page-size control. Implement all eight row states including *selected and changed* (the change-highlight background wins, the bar stays `secondary`, the tag stays). **Single selection everywhere in Release 1.**
UX-DR30: Implement the **APG grid keyboard model** for every table: `role="grid"`, one Tab stop, focus staying on the grid container with `aria-activedescendant` so virtual scroll and in-place re-fetch can never recycle or drop a row that holds focus; Up/Down/Home/End/PageUp/PageDown move the active row **and select it**; Right/Left step into the row's cells and back; Enter opens the detail or editor route; Alt/Option+Down and the `contextmenu` event open the row menu. Selection, sort, filter and scroll survive refresh. Deleting the focused row moves focus to the next row, else the empty-state, else the filter.
UX-DR31: `row-overflow-menu` - a 28px circular trigger opening on click, Alt/Option+Down or `contextmenu`, whose opening **selects the row**; items in command-bar order with destructive items last after a separator, in `destructive` text. Refused (self-protection) and privilege-gated items are **drawn alike**: `restrained` at full opacity with the reason as a trailing caption **inside the item, never a tooltip**, because a menu item's focus is virtual - and never Material-disabled items, which `mat-menu` skips. Escape closes and returns focus to the row.
UX-DR32: `form-page` - a full-page route with a single column at most 720px wide and fields no wider than 480px, sections 24px apart with `title` headings, fields in **the classic order**, Material outlined fields, labels above in `caption`, an asterisk plus a one-line legend for required fields, and a sticky 56px action bar (Save as `button-primary` right, Cancel as `button-text`, a caption slot left for the dirty note or saved confirmation). Validation inline on blur and on Save, with server rules landing on the field they name; on a failed Save an **error summary banner receives focus** (`role="alert"`) with a link per field, fields carry `aria-invalid` and their message via `aria-describedby`, and the first invalid field is focused with its tab opened. Save on a create route opens the new entity's editor; Save on an edit route keeps the editor open and shows "Saved". Navigating away with unsaved changes asks first - **and agent navigation waits for the same answer**.
UX-DR33: `tabs` - Material tabs mirroring the classic editor's tab names, **one form across all tabs** so Save applies everything; a validation error switches to the tab holding it, a tab with errors shows a 6px `destructive` dot and adds ", N errors" to its accessible name.
UX-DR34: `stepper` - a vertical Material stepper for the New Task wizard (Basics - Task type and settings - Schedule - Options and notifications), linear: Next validates the current step, Back keeps values, the last step's primary is "Create task", Cancel returns to Task schedule, the task-type step loads that type's settings fields, and **a step with an error names it in text**, never by its circle alone.
UX-DR35: `log-viewer` - lines parsed into time / pid / severity-chip / text rows in a table variant at 28px, with a sticky search field carrying highlight and a polite "n of N" with next/previous, jump-to-top and jump-to-bottom, "Load newer" at the tail, and a **Raw toggle** swapping to a bounded monospace view on `code-surface` with a line-number gutter, no wrapping and horizontal scroll inside the block. **Never loads the whole file.** alerts.log merges the monitor API's recent entries with the history tail. Application errors keep the namespaces > dates > errors drill-down as three nested tables; the audit viewer keeps its criteria form above the table and a read-only detail dialog.
UX-DR36: `severity-chip` - a 20px tonal chip in `label` **sentence case** (chips are never uppercased) with the level word always present: info, warning, error, severe/fatal inverted to `on-error` on `error`, trace/debug in `restrained`. Clicking a chip applies that severity as the filter and the command-bar shows the active filter with Clear.
UX-DR37: `meter` - a 6px pill track with a `secondary` fill, the value in `code` right of the track and the label in `caption` above; the fill and the value text turn `warning` at 80% and `error` at 95% so the meaning survives without the bar; "-" with a skeleton until a value arrives; **never animates the needle**. Names and thresholds come from `%CSP.UI.Portal.EnsembleMonitor`'s 25 meter definitions.
UX-DR38: `empty-state` - centered, at most 360px, a 32px icon (**an icon, not an illustration**), a `title` line naming what is empty, one or two sentences saying what to do next, and the single primary action where one exists. On **write-capable lists a second line invites the agent** ("Or ask the agent: create an SSL/TLS configuration for outbound HTTPS."). Keyboard hints render as kbd chips. A refused document or a permission-denied screen **is not an empty-state** - it shows the refusal - though both use this shape with a banner and their link.
UX-DR39: `skeleton` - `surface-container-high` bars pulsing to `surface-container`, one row per expected row in the table's column shape with three bars at 40/25/15% width, `aria-hidden` inside an `aria-busy` region. **Never shown on a re-fetch** - refreshes update in place. Static under reduced motion.
UX-DR40: `classic-link-card` - "More in the classic portal" at the end of every reduced form: `surface-container-low`, a 1px **dashed** border, the title, one caption sentence naming what only the classic portal offers, a caption noting the classic portal may ask the user to sign in again, and a `button-secondary` with an external-link icon opening a new tab. Visually quieter than the form above it. **Never on a list screen** (FR-9), and it counts against SM-C1.
UX-DR41: `area-tile` - the six tiles with a 24px `primary` icon, the area name, and the area's screens joined by " - " beneath, at `md` radius with hover (border `secondary`, background `surface-container-low`), focus ring and the privilege-gated treatment. Home is the surface itself and Agent co-pilot is reached from the rail, so **neither gets a tile**. Click or Enter opens the area's first screen and its side-bar.

**Panel and agent components**

UX-DR42: `panel` - docked right on the sheet with a 1px left edge and the resize handle on it; a 44px header (avatar at 20px, "Agent co-pilot" in `title`/`primary`, then **New conversation** and **Full screen** icon buttons, over a 2px `shell` -> `shell-edge` -> `#2090A0` bottom rule); then banners in fixed order (kill switch - enforced read-only - "not being marked" - administrator reminder - lock), the context-chip, and the transcript as `role="log"` (polite, labeled "Conversation", `tabindex="0"`, newest at the bottom, scrolling independently); then a footer holding the **always-present read-only status line**, the composer (a growing outlined field, max four lines), the Send control, and the caption line. Implement all ten panel states. **No close control in Release 1**; route changes keep the panel and its conversation.
UX-DR43: The **Send control** - one size fixed by its widest label so the composer never reflows, with three appearances: *Send* as `button-primary` when nothing runs and no proposal is live; *Send* as `button-secondary` while a proposal card is live so **Confirm is the view's only filled button**; *Stop* as `button-secondary` with a 16px stop glyph while a turn runs. **It keeps focus through every change and is never removed or natively disabled.**
UX-DR44: `panel-resize-handle` - a 6px strip (8px hit area) carrying the panel's 2px vertical docked-edge gradient, the second and last place the logo gradient appears; a 3px x 28px grip on hover and drag with a `col-resize` cursor, turning `restrained` at the minimum. `role="separator"`, `aria-orientation="vertical"`, `aria-valuenow/min/max` in px, focusable, Left/Right arrows changing width by 16px, Escape releasing, the new width announced through the value, persisted per browser.
UX-DR45: `context-chip` - a `surface-container` box with a Material switch ("Share screen context") at its right. On: `<Screen>, <NAMESPACE> - <N rows> - <provider> - <endpoint host>`, plus the **egress pill** "leaves the instance" in `egress-warning` on its container with a tooltip naming the host, when that host is not on a private network. Off: it says no screen data is being sent, in `restrained`, and the pill goes. It updates on route change, namespace change, selection and as the viewport's rows change; a screen with secret-typed fields adds a 14px key glyph. **Secret-typed fields are never included regardless of the toggle.** Absent in the configuration-empty state - there is no provider or endpoint to name.
UX-DR46: `message-user` - right-aligned at most 86% width on `primary-container`, corners `lg lg 2px lg` (the small corner pointing at the composer), whitespace preserved, **no avatar, no name, no timestamp**, not editable after send. A message refused by the turn lock is not rendered.
UX-DR47: `message-agent` - the avatar left, an 8px gap, then text at up to 96% width with **no bubble**; sanitized Markdown with teal underlined-on-hover links, **external links inert with the full host visible in caption after the link text**, inline code on `surface-container`, code blocks on `code-surface` with a copy button, and **images only from same-origin or inline sources**. Row names the agent cites are set in `code`. A turn-ending error renders as an error `banner` in the agent's slot; a turn the user stopped is not an error and takes the tool-call card's Stopped status instead.
UX-DR48: `avatar-agent` - the robot crop at 24px beside messages and 20px in the panel header and on card headers, `md` corners cut by CSS (both files are opaque), no border and no ring. **Never scales above 32px, never appears in the header or on the rail, never used as a button**, never beside a user message. `alt="Agent"`. The human has no avatar.
UX-DR49: `tool-call-card` - one per tool call appended in order, as an **expandable disclosure** (`<button aria-expanded>`): a 36px collapsed line with a chevron, the tool name and target in `code`, and the status at the right in `label`; the running card is expanded and collapses on completion; click, Enter and Space toggle. Expanded it adds the arguments summary and the result on `code-surface`, at most twelve lines before scrolling inside itself. Implement the six statuses - running (12px spinner + "running"), done (and "done - audit marked" for a write), failed with the error sentence beneath, blocked by read-only mode with a 3px `restrained` left bar, **"done - audit not marked" in `warning` with a warning glyph always on the collapsed line, never only in the body**, and stopped-by-the-user with no body and no expansion (not an error - nothing went wrong). The status text is part of the accessible name and updates in place. **The first card appears within 10 seconds of Send.** The card is never the same color as a proposal card and its collapsed line never hides the status.
UX-DR50: `proposal-card` - the one thing in the transcript asking for a decision: the sheet with a 4px `agent-accent` left bar at elevation 1, reflowing at any panel width. Six anatomy parts: header (avatar, "Proposal - <entity type> <name>" in `title`/`primary` with the entity in `code`, the countdown caption turning `warning` at 1:00 and staying so to 0:00); the diff, changed fields first, with the fields the payload also sends unchanged collapsed under a "N unchanged fields" disclosure closed by default (the card's default height is two changed rows plus one disclosure line, whatever the payload carries); two agent-text blocks on `agent-container` under uppercase `label` headings in `agent-accent` with a small "agent" tag - **this tint marks the model's words and appears nowhere else**; the Reverse line where a reversal exists; confirmation inputs when required, a destructive proposal also taking a 3px `destructive` bar under the header rule and a `button-destructive` Confirm; and a footer that is **also the card's status line and the focus destination** after Confirm, Cancel and expiry. Implement all nine card states including **Example** (identical to Live with a full-width label band, no countdown, no buttons, nothing focusable, keeping live colors so the example teaches the real card).
UX-DR51: `diff-row` - a 24px row with the field label in a 76px caption column, the before value in `code`/`destructive` with a line-through, an `aria-hidden` arrow, and the after value in `code` at 600 in `success`. Long values **wrap rather than truncate** and the row grows. Secret values render as eight bullets on both sides; empty values read "(none)". A **delete proposal has no after-state**: it shows the target's identifying fields as `field - value -> (removed)`, reads "<field>: <value>, removed", and carries **no Reverse line**. The accessible rendering is "<field>: was <before>, now <after>" with visually hidden "was"/"now"; unchanged rows read "<field>: <value>, unchanged". The strike-through and weight carry the direction, not color alone. **The `on-surface-variant` / `on-surface` diff pairing is retired.**
UX-DR52: `banner` - an inline notice, never floating: `md` radius, a 14px glyph, text wrapping at any width, an optional `button-text` link. **Not dismissible while its condition persists, gone the moment it clears.** Implement seven kinds - lock (info), auditing off (warning, with "Auditing configuration" for every user and "Turn auditing on" for administrators, opening that screen with the enable control focused), administrator reminder (info), gate landing (info, above the Definition form), enforced read-only and kill switch (restrained), Task Manager suspended (warning, with Resume), and form error summary (error, receiving focus, `role="alert"`, each entry a link to its field) - plus the egress variant for the plain-HTTP acknowledgment. The auditing-off and kill-switch banners are **not dismissible**. Banners in the panel span its width minus the gutter; in content they span the form or table width.
UX-DR53: **Home suggested view** inside the panel - a "Suggested view" eyebrow, then attention lines (tasks suspended after an error - application errors today per namespace - new alerts.log entries - agent status), each a 32px row whose text is a button distinct from its "Open >" link, activating a line placing its text in the composer as a prompt for the user to send. When every attention line would be zero the block shows **three starter prompts instead of zeros**, with the same gesture; the agent-status line stays.

**Feedback, dialogs and confirmation inputs**

UX-DR54: `toast` - bottom-right above the status bar on `inverse-surface`, stacking **at most three deep** newest on top with a fourth dropping the oldest, `role="status"`, carrying the change in one sentence, an "Open in <screen>" link **whose color swaps with the mode** because the inverse surface flips, and a close button on every toast. A toast without an action persists 10 seconds, one carrying "Open in" persists 30 seconds, and **the timer pauses while any toast is hovered or focused**. Used only for changes to entities whose screen is not open, and for "Saved" from form-pages. **Never for errors** (those are banners) and never to confirm what the user just did on the open screen (the row highlight is that confirmation). The region is reachable with Tab after the panel.
UX-DR55: `confirm-dialog` - a 440px Material dialog at elevation 3, **one level deep, never over another dialog**, titled with the action and target (the target in `code`), the body stating the consequence, then any inputs, with Cancel as `button-text` and the action as `button-primary` - or `button-destructive` when it deletes, terminates or removes. Escape and Cancel close without effect and focus returns to the opener. **Ctrl/Cmd+K, +I and +B are inert while a dialog is open.** Initial focus is the typed-name-field, else Cancel.
UX-DR56: `typed-name-field` - "Type <name> to confirm" with the target in `code`, `code` input text, helper text "Must match exactly"; an **exact, case-sensitive** match enables the destructive button, which is `aria-disabled` until then; paste is allowed; a mismatch on blur shows "Does not match" with `aria-invalid` and the message in `aria-describedby` - **reported, never silent**, because a disabled Delete with no reason gives a screen-reader user nothing. Enter submits only once the name matches. Used identically in the proposal card and in delete dialogs so the two paths look the same.
UX-DR57: `masked-secret-field` - a Material outlined password field with a **labeled** reveal toggle showing the value only while pressed or toggled. **Write-only:** after save the field is empty and captioned "Stored. Enter a new value to replace it."; it never pre-fills and never echoes a stored value; pastes are accepted without trimming. On a proposal card the user fills it at confirmation and **the diff never shows it**. Per-provider key-shape checks flag obvious paste errors inline before Test connection.
UX-DR58: The **four button variants** at 32px, full-radius, `body` at 600, with Material's state layers, 38% opacity when unavailable, and the focus ring: `button-primary` filled teal (**never `primary`**), one per bar, card footer or dialog, showing an inline progress indicator while its request runs and `aria-disabled` for the duration with focus retained; `button-secondary` outlined; `button-text`; `button-destructive` filled, **only inside a confirm-dialog or a destructive proposal card, only after the typed name matches, and only ever labeled with the verb** (never "OK" or "Yes"), never in a command bar or row menu. **Privilege-gated buttons are not dimmed** - `restrained` text on a `restrained-container` fill, no hover, the resource tooltip on hover and focus.
UX-DR59: `focus-ring` - a two-tone ring (2px outer outside a 2px inner halo touching the control, following its radius) with **three grounds**: the two-tone ring on surfaces and the sheet; `focus-ring-dark` outside a `shell` halo on the chrome in **both** modes; `focus-ring-dark` outside `code-surface` on the code surface. Every pair clears its floor including the halo against each filled control it can touch. Drawn **inset** inside a table row or side-bar entry so it is not clipped. `:focus-visible` semantics - shown for keyboard and programmatic focus, not mouse clicks - **never removed with `outline: none` and never replaced by a color change alone**. A "Skip to content" link is the first Tab stop, hidden until focused then drawn top-left over the header.

**Behavior: privilege gating, live data, the write lifecycle**

UX-DR60: Implement the **privilege-gating mechanism** as the accessibility contract: a gated control stays focusable and arrow-reachable with `aria-disabled="true"` - **never the `disabled` attribute** - and names its reason. Where the control takes DOM focus (rail-item, side-bar entry, area-tile, button) the reason is a tooltip on **hover and focus** via `aria-describedby`; in the side-bar and command-box it is **also inline after the label**; in menus and result lists, where Material's key managers skip disabled items and no tooltip can ever show, gated entries render as non-selectable rows with the reason inline as part of the accessible name (`skipPredicate` overridden so they are announced). The same mechanism serves command-bar actions with nothing selected and self-protection refusals. **Gated controls are never hidden.** Cover the eight documented cases including a deep link to a gated route (the screen renders its title and the permission-denied message while the rest of the shell works) and the Wallet screen-level gate.
UX-DR61: Implement **live-data behavior** as one framework: change event -> silent re-fetch in place preserving sort, filter, selection and scroll; the changed row or field taking `change-highlight` and the "Changed" tag within 2s, scrolled into view, settling over 2s and holding until the next interaction with that row or field; a deleted row leaving the list and clearing the selection and locator segment if it was selected; a created row appearing highlighted and selected; the off-screen toast per UX-DR54; the auto-refresh chip switching between off and a rate from a short fixed list (5s - 10s - 30s - 60s, default off) on Processes, Databases, Database details, Task schedule, Task details and System usage, with setting, sort, filter and max rows persisted per screen and **refresh silent** - no spinner, no skeleton, no announcement; **pause under an open proposal** on that screen's entity type with the chip saying so, resuming on confirm, cancel or expiry; async values filling their skeleton cells as they land **without the table reflowing**, and meters showing "-" until their first value; and **tail, not live** - log viewers load bounded pages with "Load newer" and nothing streams in Release 1.
UX-DR62: Implement the **ten-step agent write lifecycle** as the user experiences it: propose (tool-call card then proposal card, several stacking in order each with its own Confirm/Cancel and **no "Confirm all"**, the screen pausing auto-refresh); review (the full card per UX-DR50, with a proposal to disable auditing carrying its warning inside the card); confirm (a separate authenticated request, the button showing progress with `aria-disabled` and focus kept, then the status line taking focus, the write's card reading "done - audit marked", the screen re-fetching and highlighting within 2s, and the reply ending "Shall I show you the audit entry?" - answering yes taking the user to the audit database with the agent-marker filter applied); cancel (Cancel, **a new message, or New conversation** cancels every live proposal, which is why the card carries its guard caption, Send drops to secondary, and the agent's message points at Confirm - a user who types "yes" from habit cancels the card, and the next reply must say so and offer to re-propose); expiry (10 minutes, announced to assistive tech **once, at 1:00**, then the restrained treatment with "Expired" and **Re-propose** as a fresh turn - the limit is essential to the security model under WCAG 2.2.1 and Re-propose is the accommodation, and a card restored from a reloaded transcript is **always** shown expired); target changed (step 7); read-only (no card at all - the agent says what it would have changed and on which screen); kill switch (the panel disabled, live proposals no longer confirmable, screens still working); audit (the marker, its failure surfaced, and enabling auditing itself being a write); and the polish-week additions (copy-out draft, governance-disabled results). **Confirming one proposal cancels its siblings on the same entity. Stop is not a new turn and cancels nothing.**

**Copy, voice and interaction primitives**

UX-DR63: Implement the **Fixed strings table verbatim** (~60 strings) as the single copy source, canonical over `DESIGN.md` and over every inline quotation elsewhere. An illustration may resolve a placeholder (UJ-3 resolving `<user name>` to `_SYSTEM`) but **may not respell the string**. `<user name>` is always the login name as the audit database records it.
UX-DR64: Enforce the **voice rules**: plain, direct, second person, sentences not labels; every error says what happened and what to do next; confirmations always name the target; warnings carry their consequence; **no exclamation marks, no "Oops", no emoji, no "successfully"**. The agent speaks in first person, never claims success it did not verify, names the screen it means, names in plain text the rows it used and offers to select them, and always labels rationale and expected impact as its own text. **"agent co-pilot" for the feature, "the agent" for the software, "the panel" for the UI - never "co-pilot" alone, anywhere, including code comments and commit messages.**
UX-DR65: Implement the **keyboard model**: Ctrl/Cmd+K opens the command-box, Ctrl/Cmd+I focuses the composer **including during a turn**, Ctrl/Cmd+B toggles the side-bar (and with focus inside it moves focus to that area's rail-item) - all three inert while a dialog or the command-box overlay is open; Escape closes the topmost overlay else returns focus to the last focused element in content; Enter sends and Shift+Enter makes a newline in the composer; Left/Right switch tabs and resize the panel handle by 16px; Tab/Shift+Tab follow the reading order skip link -> header -> rail -> side-bar -> content -> panel -> toasts with a data-table as one stop. Chords are shown on screen (command-box chip, composer caption, rail tooltips) with the macOS glyph substituted. **No single-character shortcuts exist**, so WCAG 2.1.4 does not apply.
UX-DR66: Implement the **mouse and gesture rules**: click acts, one click selects a row, the name cell navigates, right-click opens the row menu; **hover reveals nothing the keyboard cannot reach**; double-click has no meaning; **no drag except the panel resize handle**. A proposal is confirmed **only** by its own Confirm button - no batch, no shortcut that confirms the newest card, no typed "yes"; a delete only in its dialog after the typed name.
UX-DR67: Enforce the **banned-everywhere list**: popups and new windows (only the classic-link-card and the classic OAuth editor links open a new tab); modal stacks; batch approval of proposals; hover-only affordances; infinite scroll (virtual scroll over a capped fetch is not infinite); page-size controls; **confirming a proposal for the user by any means the user did not perform**; rewriting the URL into another web application on a namespace change; and **natively disabling or removing a control while it holds focus**.

**Accessibility floor**

UX-DR68: Implement **landmarks and focus order**: a "Skip to content" link as the first Tab stop; header = banner, rail and side-bar = navigation named "Areas" and "<Area> screens", locator-bar = navigation "Breadcrumb", content = main, panel = complementary named "Agent co-pilot", status-bar = contentinfo, toasts = a status region. Dialogs trap focus and return it to the opener. **Route changes move focus to the new screen's heading and announce its title.**
UX-DR69: Implement **named focus destinations** so no control is ever disabled or removed while holding focus: after Send focus stays on the Send/Stop control, which is never natively disabled; after Confirm, Cancel, expiry, target-changed or the kill switch a proposal card's buttons are replaced by its status line (`tabindex="-1"`) which receives focus and is announced, with the departing buttons `aria-disabled` for the transition; Ctrl/Cmd+I during a turn focuses the composer, which stays focusable while locked with its reason in its description; deleting the focused row moves focus per UX-DR30.
UX-DR70: Implement the **status-message contract** (WCAG 4.1.3): the transcript as `role="log"` so the reply, every tool-call card and every proposal are announced by construction and a card's status change is a text update; polite `role="status"` for the Test connection result, "Saved", the search "n of N", the filter count, the command-box count, the toast region, the change highlight, the lock banner and the connection state **on transitions only**; `role="alert"` (or focus moved to it) for the sign-in failure, the instance-unreachable banner, the generic error, a 403 and the form error summary; kill-switch and enforced read-only banners **assertive on appearance**. The countdown is announced **once, at 1:00**, never per second; the auto-refresh stamp and refresh ticks are **never** announced. Agent navigation commits its announcement to the log, changes the route about a second later, and the new heading announces "<title> - opened by the agent; Back returns".
UX-DR71: Implement **names, roles and glyph handling**: rail-items carry `aria-label` = area name and `aria-current="page"` when active (as do the active side-bar entry and locator segment); the resize handle is a `separator` with `aria-valuenow/min/max`; the full-screen toggle carries `aria-expanded` and the hidden content is `inert`; tool-call cards are `<button aria-expanded>` with the status in the name; skeletons are `aria-hidden` inside an `aria-busy` region; the decorative glyphs are `aria-hidden`; suggested-view lines and starter prompts are buttons distinct from "Open >"; the max-rows field is labeled; masked fields' show/hide toggles are labeled; the composer is "Message to the agent" and the context switch "Share screen context"; **every icon-only control is named**.
UX-DR72: Meet **target sizes** - every control at least 24x24 CSS px, rail-items 48x48, the row-overflow trigger 28x28, table rows at the row height with the whole row as the selection target - and **color never alone**: server flag, severity, meter state, changed rows, "leaves the instance", diff direction and every proposal state all carry a word or tag.

**Session, states and the screen contract**

UX-DR73: Implement the **shell and screen state set** (25 states) and the **panel state set** (28 states) as specified, including silent login in progress, form login and its four variants, version mismatch, no administrative privileges, privilege-gated entries, Wallet without its resource, loading, empty, async values arriving, refused document, instance unreachable, request refused, generic internal error, the four auto-refresh states, row selected, changed, off-screen toast, confirmation dialog, warning before a write, reduced form, gate landing, Task Manager suspended, Test connection, and width yield.
UX-DR74: Implement the **session states** from the auth spike (1-10 and 13), including the **silent retry before the form** on a failed refresh, the toast "Your unsaved changes were not kept." after re-signing-in, sign-out landing on the form login with "You're signed out.", and discovery of a sign-out that happened elsewhere on the next call.
UX-DR75: Honor the **surface x state matrix**: every one of the 12 archetypes (list, list two views, list server-criteria, detail, meters, the three form keys, log-viewer, drill-down, viewer OpenAPI, dialog, home, panel) shows the seven required states in the specified form, with the nine documented exceptions (Databases adding async values; the OpenAPI viewer showing a refusal never an empty view; Audit database and Task history searching on the server and not auto-refreshing; OAuth 2.0 rendering five lists as tabs of one screen; Auditing configuration embedding the system- and user-event lists beneath its form; Task schedule adding its suspended banner; Switches and Definitions gating for non-administrators; the Agent co-pilot rail-item never gating).
UX-DR76: Implement the **screen contract** - each of the ~60 screens registers the same ten things (route, side-bar entry and position, archetype, privilege resource, entity-type key and id-to-row mapping, context serializer with its secret-typed fields, primary action and row-menu items with self-protection rules, empty-state sentence plus the agent line on write-capable lists, the fixed strings it introduces, and command-box aliases from the contest wording) so 60 screens behave alike and the panel can find them. This is the UX face of AD-5's descriptor.
UX-DR77: Build the **Information Architecture** exactly as tabled: the seven-band rail, ~60 Release 1 surfaces with their reached-from paths, the side-bar screen lists per area, the closed **dialog set** (dialogs exist only for set password, role resource grant, resource editor, terminate process, remove locks, audit event detail, every delete confirmation, the two warnings preceding a non-delete write, and the warning before disabling OcuPilot's own web service - **everything else is a full-page route, and dialogs never stack**), and the actions without a surface of their own that act on the selection and update the row in place.

**Polish week and open UX items**

UX-DR78: Wire the **light/dark theme toggle** as a flag flip - both token sets already exist and are contrast-checked - in the status-bar account menu alongside Change password (FR-73).
UX-DR79: Ship the polish-week UX: "Explain this screen" as a one-click panel action everywhere; an explain entry point per log and audit row; at least three suggested prompts per screen grouped by task; click-through citation chips replacing Release 1's plain-text row names; the data-egress line on every turn with context on; the agent audit viewer; the copy-out draft on any card; governance-disabled results ("This tool is disabled by policy", the tool still advertised); and the Transcripts history screen (New conversation's earlier conversation is not reopenable in Release 1).
UX-DR80: Close the five **`[ASSUMPTION]`** confirmations before the surfaces that depend on them ship: the 24px status-bar height and its shell color (Bridge has no status bar); 28px log rows against a real tail; 640px as the content minimum below which content scrolls horizontally; the 720px form and 480px field widths (the sticky bar itself is decided); and the meter's 80% warning and 95% error thresholds (the behavior is decided).
UX-DR81: Close the **`[NOTE FOR PRD]`** items: bound "visible rows" in the screen context so the context chip can carry a row count (**resolved by AD-24's 200-row and total-size cap** - wire the count into the chip and the read tool-call card); and give build step 7's per-user turn limits a "turn limit reached" banner and a refusal sentence **before that step ships** - the one UX item the architecture spine did not answer.
UX-DR82: Satisfy the three **release-blocking installer asks** the UX raised, all of which the architecture adopted, so the first screen a judge meets is not a defect: unexpire `_SYSTEM` at install (AD-17), enable auditing and register OcuPilot's audit events (AD-17), and seed the demo fixtures - a demo SSL/TLS configuration, a self-signed X.509 credential and a disabled `/csp/myapp` with no resource - under the compose flow's clearly named opt-in (AD-25), so five empty Security lists and a missing `/csp/myapp` do not greet the README walkthrough.

### FR Coverage Map

Where an FR is split, the epic that first delivers user-visible value from it is named first. A split is never a partial FR - it is the build order deliberately shipping a screen's read before its write, and its small actions before its full editor.

**Shell and install**

- FR-1: Epic 1 - silent-first sign-in, per-tab Bearer token pair, refresh-and-retry.
- FR-2: Epic 1 - sign-out ending the browser-level login across the portal group.
- FR-3: Epic 1 - instance identity and the admin API v2 guard, plus the no-`%Admin_*` notice.
- FR-4: Epic 1 - privilege-driven navigation for the six areas, gated never hidden.
- FR-5: Epic 1 - header strip and namespace switch carried on the route and into context.
- FR-6: Epic 1 - locator bar and per-page command bar.
- FR-7: Epic 1 - the auto-refresh framework; applied per screen in Epics 2 and 6; its proposal pause in Epic 5.
- FR-8: Epic 1 - one error envelope and the four rendering paths.
- FR-9: Epic 1 - the fallback-link rule and the `classic-link-card`; applied to each reduced form in Epic 9.
- FR-64: Epic 1 - the IPM module with the bundle inside the archive.
- FR-65: Epic 1 - the two web applications with their silent-first settings.
- FR-66: Epic 1 - the idempotent installer, name isolation, the protected state database, the smoke script and the CI harness.
- FR-67: Epic 1 - Docker self-install on the durable volume, including both upgrade paths.
- FR-68: Epic 1 - Community Edition compatibility; the plain-Community check runs in Epic 10 after the floor is built.
- FR-69: Epic 17 - the README, the public MIT repository, the Ideas Portal idea, the Open Exchange listing and the application.

**Agent**

- FR-10: Epic 4 - the docked panel, resizable, remembered, never closed by navigation.
- FR-11: Epic 4 - screen context per turn with its toggle, secret exclusion and the context chip.
- FR-12: Epic 4 - turn execution, progress cards and the conversation lock.
- FR-13: Epic 4 - sanitized Markdown from a vendored pipeline with no remote resource.
- FR-14: Epic 5 - the change event, in-place re-fetch, highlight and off-screen toast.
- FR-15: Epic 4 - agent-driven navigation over allow-listed route identifiers.
- FR-16: Epic 2 (the descriptor-derived read tool for each area's step-1 screen) - Epic 4 (the registry, dispatch and the three shell reads) - Epic 6 (a read tool for every remaining screen).
- FR-17: Epic 5 - propose, review, confirm in its floor form; the target-fingerprint re-read and the typed-name confirmation in Epic 10.
- FR-18: Epic 5 - execution strictly as the user, the 403 contract and the prohibited set.
- FR-19: Epic 3 (enforced instance-wide read-only and the enforced-state settings) - Epic 10 (the per-user toggle and the per-user turn limits).
- FR-20: Epic 3 - the kill switch, global and per user, reachable without the agent.
- FR-21: Epic 4 - the agent audit ledger with schema-driven redaction and the per-row resource record.
- FR-22: Epic 5 - the agent marker, its failure path and the "not being marked" banner.
- FR-23: Epic 4 - provider retry, backoff and the named timed-out step.
- FR-24: Epic 3 - definition CRUD under the eleven validation rules, with the disable-on-change rule.
- FR-25: Epic 3 (Anthropic, the Release 1 floor) - Epic 10 (OpenAI, Google Gemini and OpenAI-compatible including local models).
- FR-26: Epic 3 - the credential ladder, write-once and returned by no call.
- FR-27: Epic 3 - Test connection with its bounded budget and endpoint refusals.
- FR-28: Epic 3 - the first-login gate and the configuration-empty state.
- FR-29: Epic 1 (the installer creates the resource, the role and the protected database) - Epic 3 (every configuration endpoint's gate, the audit of every change, and the state-protection acceptance test).

**Web applications and REST API explorer**

- FR-30: Epic 2 (the list, live, with its read tool) - Epic 9 (the full editor).
- FR-31: Epic 8 - create a CSP, REST, WSGI or ASGI application.
- FR-32: Epic 5 (this area's step-2 confirmed agent write - UJ-3's enable-and-grant) - Epic 7 (the screen's own enable, disable and delete row actions).
- FR-33: Epic 6 - the REST API explorer list.
- FR-34: Epic 6 - the OpenAPI path-and-verb browser and its refusal state.

**Permissions**

- FR-35: Epic 2 (the users list) - Epic 9 (the full user editor, the first large editor built).
- FR-36: Epic 8 - create user.
- FR-37: Epic 5 (this area's step-2 confirmed agent write) - Epic 7 (the remaining row actions: enable, disable, delete, set password, role add and remove).
- FR-38: Epic 6 (the roles list) - Epic 9 (the role editor).
- FR-39: Epic 8 - role create, resource grants and delete.
- FR-40: Epic 6 (the resources list) - Epic 8 (the resource editor).
- FR-41: Epic 6 (the services list) - Epic 9 (the service editor with its self-lockout warning).

**Security and secrets**

- FR-42: Epic 2 (the SSL/TLS list) - Epic 9 (the SSL/TLS editor).
- FR-43: Epic 6 (the X.509 list) - Epic 8 (import, edit and delete).
- FR-44: Epic 6 (the four lists and the authorization-server view) - Epic 7 (the two deletes) - Epic 12 (the five full editors).
- FR-45: Epic 6 (the LDAP and Kerberos list) - Epic 9 (the editor).
- FR-46: Epic 6 (collections and secrets lists) - Epic 8 (the write-only secret form).
- FR-47: Epic 5 (this area's step-2 confirmed agent write - auditing disable and re-enable, carrying its mandated warning) - Epic 7 (auditing on and off from the screen) - Epic 8 (system and user event configuration and the selective SQL auditing wizard).

**Tasks**

- FR-48: Epic 2 (the task schedule list) - Epic 6 (on-demand and upcoming) - Epic 7 (run an on-demand task).
- FR-49: Epic 6 - task history, per task and across tasks.
- FR-50: Epic 6 - task details under auto-refresh.
- FR-51: Epic 5 (this area's step-2 confirmed agent write - UJ-6's resume) - Epic 7 (run, suspend, delete and the three Task Manager controls).
- FR-52: Epic 9 - the New Task wizard over `%SYS.TaskSuper`'s documented property set.
- FR-53: Epic 9 - Edit task, built from the same model so the field list matches by construction.

**OS management**

- FR-54: Epic 2 (the processes list) - Epic 6 (process details with its meters and open devices).
- FR-55: Epic 5 (this area's step-2 confirmed agent write) - Epic 7 (terminate with its error-to-job flag, and the remaining controls).
- FR-56: Epic 6 - system usage counters and the 25 dashboard meters.
- FR-57: Epic 6 (the locks view) - Epic 7 (the three removal scopes with the transaction warning).
- FR-58: Epic 6 - databases in both views, with free space arriving asynchronously.
- FR-59: Epic 6 (the devices list) - Epic 8 (the device editor).

**Logs**

- FR-60: Epic 6 - alerts.log, monitor entries merged with the bounded file tail.
- FR-61: Epic 2 - the audit database viewer with its agent-marker filter, brought forward from step 3 because UJ-3's resolution and SM-4 both end there.
- FR-62: Epic 2 (the bounded paging endpoint) - Epic 6 (the viewer).
- FR-63: Epic 2 (the `SYS.ApplicationError` endpoint and the drill-down screen, both brought forward so AD-48's single namespace source exists) - Epic 5 (this area's step-2 confirmed agent write, delete by namespace) - Epic 7 (the remaining delete scopes).

**Polish week**

- FR-70: Epic 11 - "Explain this screen", per-entry explain entry points and suggested prompts.
- FR-71: Epic 11 - citation chips, the data-egress line and the agent audit viewer.
- FR-72: Epic 14 - copy-out drafts, the governance policy, the sanitizer with its seeded-injection test, and transcripts with retention.
- FR-73: Epic 15 - the eleven shell conveniences and the light or dark theme.
- FR-74: Epic 16 - try-it, web sessions, effective privileges and the permission-check tool.
- FR-75: Epic 12 - the security-area tests and the five OAuth 2.0 editors.
- FR-76: Epic 16 - task export and import, background tasks, broadcast, license usage and every dashboard meter group.
- FR-77: Epic 16 - the six secondary log viewers and the unified log hub.
- FR-78: Epic 16 - external language servers.
- FR-79: Epic 13 - the optional bonuses, the uninstall hook, CI growth and the registry publish.

**Non-functional coverage**

- NFR-1 responsiveness: Epic 2 (list first page under two seconds at a thousand rows), Epic 4 (first turn progress within ten seconds), Epic 5 (write-to-refresh under two seconds).
- NFR-2 progress before streaming: Epic 4 (per-step progress); Epic 11 (token streaming, conditional on Epic 10 finishing).
- NFR-3 token hygiene: Epic 1.
- NFR-4 no SQL or path from the caller: Epic 1 (the rule and the static handler), Epic 2 (the log endpoints' fixed enum).
- NFR-5 secrets never leave: Epic 3 (credentials), Epic 5 (proposal and ledger), Epic 8 (the wallet and X.509 forms).
- NFR-6 untrusted content boundary: Epic 4 (invariants 1, 3 and 4), Epic 5 (invariant 2), Epic 10 (the seeded-injection test), Epic 14 (the polish-week sanitizer, which is additional and not the defense).
- NFR-7 auditability: Epic 5.
- NFR-8 API pinning: Epic 1 (the v2 guard), Epic 2 (the endpoint-inventory fixture in CI).
- NFR-9 idempotence: Epic 1.
- NFR-10 no external runtime dependency: Epic 1 (the CSP and the no-CDN CI grep), Epic 4 (the vendored Markdown pipeline).
- NFR-11 browser support: Epic 1, and every epic's manual pass.
- NFR-12 accessibility: every epic; the floor is UX-DR68 to UX-DR72 and is a story-level acceptance criterion throughout.
- NFR-13 platform: Epic 1 (the pinned image and `SystemRequirements`), Epic 10 (the plain-Community verification).
- NFR-14 language: every epic.

## Epic List

**How these epics are ordered, and why.** The architecture is unusually settled - 47 binding ADs, a final UX contract with a state matrix and a canonical string table, and a spec whose companions are preservation-validated - so the guidance to prefer fewer, larger epics applies. What stops them being larger still is a hard external constraint: **PRD section 10.1's build order *is* the cut line**, every step must end in a publishable build that passes the smoke script on a clean container, and any step must be able to become the cut without leaving a half-built one behind. So Epics 1 to 10 map onto the build steps, and the boundary between two epics is exactly a point at which the project could stop and still submit.

That choice was weighed against organising by portal area instead - one epic each for Web applications, Permissions, Security, Tasks, OS management and Logs. Area epics would touch fewer files per epic, but they cannot express the floor, which demands one live list in **every** area before any area's editors, and one confirmed agent write in **every** area by the end of step 2. An area-shaped plan would let the project arrive at 2026-09-27 with two finished areas and four empty ones, which is the thin interface the contest rules reject.

**On file overlap.** Epics 2, 6, 7, 8 and 9 do each touch the same area slices. That overlap is additive rather than churning, because AD-5 makes a screen one declarative descriptor: adding a row action adds a declaration and a derived tool schema, not a rewrite of the list page. This is the "fully pre-designed, no feedback loop" case - the pre-design is what removes the pressure to consolidate.

Epics 11 to 16 are the polish week, ordered exactly as PRD section 10.2 ranks it. Epics 18 to 22 are the post-contest stages, one per versioned IPM release, at the grain `extract-stages.md` specifies.

**Epic 17 floats.** The listing and the submission are **not sequenced against a build step**. They run when the owner decides the product is ready to show, which is an owner decision rather than a dependency - so the epic sits after the polish week, where nothing it produces can depict an unpolished build. Its stories therefore have no forward dependency at all: by the time it starts, every screen, every agent write and every polish-week item its walkthrough might photograph already exists. What the epic does **not** control is the contest calendar, which is external and fixed; each of its stories names the bound it must respect and what is forfeited if the release decision falls after that bound. Nothing else in this document waits on it.

### Epic 1: Install once, sign in, and reach the six areas

An operator clones the repository, runs one command, and reaches a working OcuPilot that signs them in without a form when the browser already holds an instance login - navigable across the six areas, showing only the screens their IRIS privileges allow, with every classic page OcuPilot has not rebuilt one click away. Build step 0; the foundation every later epic stands on and the half of the 2026-09-14 listing build that is not data.

**FRs covered:** FR-1, FR-2, FR-3, FR-4, FR-5, FR-6, FR-7, FR-8, FR-9, FR-64, FR-65, FR-66, FR-67, FR-68

**Implementation notes:** No starter template - a greenfield Angular CLI workspace on the exact pins (Angular 22.1.x zoneless, TypeScript 6.0.x pinned exactly, `@angular/build`, Node `^22.22.3 || ^24.15.0 || ^26.0.0`) plus a greenfield `src/OcuPilot/` tree; the head start is `HARVEST-PLAN.md` -> Step 0, whose iris-execute-mcp-v2 `Utils.cls` take is marked "take this early - everything downstream uses it". Install runs at **container start**, not image build (AD-17, AD-38), and completes before the web applications accept traffic. AD-9's split is the subtle one: OcuPilot's globals go behind the guarded resource, its **code does not**, because database READ is routine-execution permission in IRIS. The smoke script (AD-45) is written here and is what "step complete" means for every later epic. Three release-blocking installer duties land here: unexpire `_SYSTEM`, enable auditing and register OcuPilot's events, and create the compose flow's opt-in demo fixtures (UX-DR82, AD-25). The screen descriptor mechanism (AD-5) and the closed entity-type enum (AD-14) are built here because everything downstream derives from them.

### Epic 2: Every area shows live instance data

A user opens each of the six areas and sees real data from the instance they are on - not a mockup - with the first page inside two seconds at a thousand rows, sort and filter preserved across refresh, and every list backed by exactly one descriptor-declared read that the agent's read tool will later share. Build step 1; completing it makes the 2026-09-14 listing build submittable.

**FRs covered:** FR-16 (the per-screen read tool), FR-30 (list), FR-35 (list), FR-42 (list), FR-48 (schedule list), FR-54 (processes list), FR-61, FR-62 (endpoint), FR-63 (endpoint and drill-down)

**Implementation notes:** `AdminPort` is built here and is the **only** code that will ever name an `%Api.Admin.*` class (AD-2, AD-27) - eight steps reproducing the vendor dispatcher, four of them load-bearing and each easy to omit silently. AD-27's endpoint-inventory fixture goes into CI in this epic, which is what retires "exercise the payload on the instance" as a per-story task. **Two source readings resolved here, both flagged for the user:** (1) PRD section 10.1 requires one live list per area including Logs, while `EXPERIENCE.md`'s IA table puts every Logs screen at step 3 - section 10.1 is authoritative by the IA table's own note, so Logs gets screens in this epic; (2) the Logs area needs **two** surfaces this early, not one - the audit database viewer, because UJ-3's resolution and SM-4's one-minute demo both end at a marked audit event, and the application error drill-down, because AD-48 requires the delete's namespace to come from the level the user has drilled to, which needs the screen to exist before Epic 5's confirmed write can be AD-48-compliant.

### Epic 3: Configure the agent, and hold the switches that restrain it

An OcuPilot administrator picks a provider, pastes a key, proves it works before enabling it, and from then on holds two switches that restrain or silence the agent instance-wide without any screen losing function - while a user with no agent configured still gets every screen and a panel that shows them what a proposal would look like. First half of build step 2, and a prerequisite for every turn.

**FRs covered:** FR-19 (enforced instance-wide), FR-20, FR-24, FR-25 (Anthropic), FR-26, FR-27, FR-28, FR-29

**Implementation notes:** Definitions and Switches are ordinary screens that must work **before** any agent does, which is what makes this epic standalone and what FR-20 means by "reachable without the agent". The eleven validation rules and the provider cascade port from iris-session-agent's config form as **contracts** into Angular reactive-form validators plus a REST save - keeping the absence of an `ApiKey` property, which is the schema invariant. AD-42 governs the endpoint field: it decides where the instance's data goes, so it is validated, gated by the administrative resource, refused for link-local metadata addresses, and audited as a security change. AD-32's named SSL configuration is created by the installer, never defaulted. FR-29's acceptance test - a `%DB_<install-namespace>:RW` plus `%Admin_Operate` holder can read and write neither table nor global - is a story here, not a note.

### Epic 4: Ask the agent about the screen you are on

A user on any screen types a question into a panel that already knows where they are, watches the agent read through the same endpoints the screen reads from, and gets an answer that names the rows it used - with every call recorded in a ledger and nothing on the instance changed. Second half of build step 2; delivers UJ-1 and the read-only half of UJ-4 complete.

**FRs covered:** FR-10, FR-11, FR-12, FR-13, FR-15, FR-16 (registry, dispatch and the three shell reads), FR-21, FR-23

**Implementation notes:** A genuine risk boundary: an agent that reads and explains but never writes is a complete, shippable product, so if the write model proves harder than budgeted this epic still stands. `AgentLoop` is a **rewrite, not a port** - iris-session-agent's is synchronous by construction and has no context-window trimming at all - taking its 10-step flow and max-iteration fallback as the design under AD-7's background job. Two ordering rules from AD-9 shape the job's startup: nothing is spawned from inside an escalated frame, and nothing re-enters, so every state read the turn needs is taken first and passed in as values. AD-33 makes the progress channel protected storage owned by the starting user, where a poll for someone else's turn is a **404, not a 403**. Four of AD-11's five invariants land here; the fifth is Epic 5's. AD-22's two un-retrofittable hooks go in now: every tool declares `read` or `write` at definition time or **the build fails**, and the dispatch path gets its single call-time gate point.

### Epic 5: Propose, confirm, and find it in the audit database

A user asks the agent to change something, reviews a diff the instance computed from a fresh read, presses Confirm, watches the affected screen refresh and highlight what changed, and then finds that same change in the IRIS audit database marked as having come through the agent - in **each** of the six areas. This is the product's entire claim, and SM-3 and SM-4 are both met at its end.

**FRs covered:** FR-14, FR-17 (floor form), FR-18, FR-22, plus one confirmed write in each area from FR-32, FR-37, FR-47, FR-51, FR-55, FR-63

**Implementation notes:** AD-40 is the trap this epic exists to avoid: in-process tools removed the HTTP boundary that used to stop the agent confirming its own proposal, so the barrier is now an explicit "acting on behalf of the model" marker carried through the turn job and refused at confirm. Every write gate - the prohibited set, read-only, the kill switch, later governance - is evaluated **at the write**, inside AD-34's single atomic transition, never at the tool call that produced the proposal. AD-10's prohibited set is defined by **effect, not verb**, and its second bullet is the one a verb-shaped reading misses: granting privilege through any path, including setting application roles on OcuPilot's own API, which would quietly falsify AD-8 for every later request. AD-4 governs the payload - 28 of 47 vendor `RunPut` implementations do not merge, so OcuPilot reads fresh, applies the diff and sends the complete property set. **The Security area's step-2 confirmed write is auditing disable and re-enable** (FR-47, SS-09), decided by the owner on 2026-09-09. It is the write the contest names most directly and the only one carrying a mandated warning in its own proposal card - "Agent writes will no longer be marked in the audit database." - so it demonstrates the safety model rather than merely exercising it. Two consequences the stories must carry: the instance is momentarily unaudited between the two confirmations, so the round trip is a single demo sequence and never a resting state; and the panel's "Agent writes are not being marked" banner must appear the moment auditing goes off and clear the moment it returns, which makes this write its own test of FR-22's banner.

### Epic 6: Every screen in the six areas reads live

A user reaches every list, detail and viewer the six areas offer - no dead side-bar entries, no area with one screen and a gap - and the agent gains a read tool for each one at the same moment, from the same descriptor. Build step 3.

**FRs covered:** FR-16 (remaining screens), FR-33, FR-34, FR-38 (list), FR-40 (list), FR-41 (list), FR-43 (list), FR-44 (lists and views), FR-45 (list), FR-46 (lists), FR-48 (on-demand and upcoming), FR-49, FR-50, FR-54 (details), FR-56, FR-57 (view), FR-58, FR-59 (list), FR-60, FR-62 (viewer), FR-63 (drill-down completion)

**Implementation notes:** Two of the two Release 1 async endpoint paths surface here (AD-26): the database directory info call behind FR-58's free space, which the UX renders as skeleton cells filling as they land, and - already built in Epic 2 - the audit record list. `ShouldRunAsync()` is evaluated **per request type, never per class**. FR-56's meter names and thresholds come from `%CSP.UI.Portal.EnsembleMonitor`'s 25 definitions, already readable in `irislib/`, not from the unrecoverable classic page. FR-44 renders its five OAuth lists as tabs of one screen with each entry linking to the classic editor until Epic 12.

### Epic 7: Act on any row

A user does the small things that make up most daily administration - enable, disable, run, suspend, resume, terminate, remove and delete - from the row or from the command bar, with the row updating in place, and can ask the agent to do any of them instead through a confirmed proposal. Build step 4; completing it clears the last floor requirement below the create-and-edit line.

**FRs covered:** FR-32 (screen actions), FR-37 (remaining), FR-44 (deletes), FR-47 (auditing on and off), FR-48 (on-demand run), FR-51 (remaining, plus Task Manager control), FR-55 (remaining), FR-57 (removal), FR-63 (remaining delete scopes)

**Implementation notes:** Every action here is two callers of one operation - the row and the write tool - so a story is not done when the button works. The self-protection rules are UI affordances, **not** prohibitions: refusing to disable the current user, act on the user's own process or delete OcuPilot's own applications is enforced on the instance by AD-10 and merely explained in the row menu. Three warnings carry consequences the user must see before proceeding: suspending the Task Manager, disabling auditing, and disabling the web service OcuPilot itself runs on. AD-48's three delete scopes complete here - by namespace, **by date** and by error - with `DeleteByDate` either implemented or explicitly refused, never left for a builder to discover, and the fingerprint always the enumerated id set rather than a count.

### Epic 8: Create and import

A user creates the things the six areas administer - a web application, a user, a role and its grants, a resource, a device, a wallet secret, an X.509 credential, an audit event - through medium forms that validate server-side and open the new entity on success. Build step 5; **at least one create or edit form per area from this step is part of the 2026-09-27 floor.**

**FRs covered:** FR-31, FR-36, FR-39, FR-40 (editor), FR-43 (import, edit, delete), FR-46 (secret form), FR-47 (event configuration), FR-59 (device editor)

**Implementation notes:** Two of the five Release 1 endpoints that publish **no** body template are in this epic - `Wallet.Secret` and `Security.Audit.Event` - so their field lists derive from the underlying `Security.*` / `%SYS.*` class and are pinned by a test that fails when the instance disagrees. Both are also **upserts**, so a body sent against a target deleted since the read silently creates a stub rather than failing, which the fresh read plus fingerprint is what covers. Every secret field here - the wallet value, the X.509 private key, the new user's password - is write-only end to end and excluded from screen context by schema declaration, never by name matching.

### Epic 9: The full editors

A user opens the editors that carry the classic portal's whole field set - user, web application, role, service, SSL/TLS, LDAP, and the task wizard and its editor - and edits an instance the way an administrator actually does. Build step 6, in that order; the eight largest forms in Release 1 and the first place FR-9's reduced-form rule may be exercised.

**FRs covered:** FR-30 (editor), FR-35 (editor), FR-38 (editor), FR-41 (editor), FR-42 (editor), FR-45 (editor), FR-52, FR-53, FR-9 (per cut editor)

**Implementation notes:** This is where the cut line is most likely to bite, and FR-9 is the designed response: a cut editor ships as a reduced form of the fields daily administration uses plus a `classic-link-card`, **never a half-working full form**, and its write tool ships regardless so the agent stays a conduit for that edit. FR-52 and FR-53's field lists and legal-value semantics come from the 49 documented properties on `%SYS.TaskSuper` - including `DailyFrequency`'s quadruple with `DailyFrequencyTime`, a 120-fold ambiguity if dropped - with two gaps to fill by testing rather than citation: the three `Expires*` offsets carry no descriptions, and `RunAsUser`'s documented `%Admin_Secure:Use` requirement is not verifiable from the shipped code. Four of AD-4's non-merging endpoints are here.

### Epic 10: Run on any model, and harden the write path

An operator runs the agent on OpenAI, Google Gemini or a local model on their own network, any user restrains their own session, and the write path gains the last three guards the safety review asked for. Build step 7, the stretch; anything not reached by the deadline ships first in the polish week.

**FRs covered:** FR-25 (the three remaining families), FR-19 (per-user toggle and turn limits), FR-17 (target fingerprint re-read and typed-name confirmation), NFR-6 (the seeded-injection test), FR-68 (the plain-Community verification)

**Implementation notes:** The adapter contract was fixed in Epic 3 precisely so this is adapter code against a settled interface - one provider base, four adapters, Anthropic's message shape as canonical, and a credential ladder that never returns a value into a status or error. The per-user work is **data and UI, not a new enforcement point**: the gate already exists and is evaluated at the write. The one UX item the architecture spine did not answer is a hard prerequisite here - per-user turn limits need a "turn limit reached" banner and a refusal sentence **before this epic ships** (UX-DR81). FR-68's plain-Community check runs here by owner decision, after the floor is built, with the late-failure risk accepted.

### Epic 11: The agent explains itself, cites its work, and streams

During the voting week a user can ask what any screen or log entry means in one click, follow a citation chip straight to the row the agent used, see on every turn whether their screen data leaves the instance, and watch a reply arrive token by token. Polish week, ranked first after any step-7 leftovers, because these are what voters see.

**FRs covered:** FR-70, FR-71, NFR-2 (token streaming)

**Implementation notes:** All three modify the same panel transcript render path, which is why they are one epic rather than three. Streaming is **conditional**: it ships only if Epic 10 finished, and is ranked after FR-70 and FR-71, because it changes the render path and must not put a Release 1 agent write at risk. AD-7 and AD-33 are unchanged in contract - the turn still runs in a background job and the panel still polls - and the panel gains an incremental-append mode. Citation chips replace Release 1's plain-text row names plus an offer to select them; the agent audit viewer is gated by the resources recorded per ledger row, and that gate lives with the ledger, not the screen.

### Epic 12: The OAuth 2.0 editors and the security-area tests

A user completes the area the contest names most specifically: five OAuth 2.0 editors that round-trip create, edit and delete, plus the test and detail actions that make SSL/TLS, X.509 and LDAP administration self-checking. Polish week, ranked next, because the task statement names OAuth setup.

**FRs covered:** FR-75

**Implementation notes:** This closes an accepted Release 1 risk rather than adding a new capability - at the deadline OAuth 2.0 is lists, views and deletes with each entry linking out to the classic editor, which the contest reviewer flagged and the owner accepted. Every classic link removed here counts back against SM-C1. All four `Security.OAuth2.*` endpoints are AD-4 non-mergers, so each editor reads fresh and sends the complete property set. LDAP test connection is the only Release-1-adjacent async endpoint type on `Security.LDAP`; list, get and put stay synchronous.

### Epic 13: Bonus deliverables and engineering hygiene

The entry reads as finished: an uninstall hook that removes everything the installer created, a test suite growing in CI against a stock image, the package on the community registry, and whichever bonus items the technology-bonuses post makes worth writing. Polish week, ranked after the OAuth editors, and re-planned against the 2026-09-14 kick-off.

**FRs covered:** FR-79

**Implementation notes:** The uninstall hook must remove what iris-couch's own installer forgot - the role, the resource, the audit event types, the tasks, the protected database and the demo fixture - and return OK when the target is already absent. Bonus items are re-planned after the kick-off, not before: the Full Stack 2026 precedent had no Angular, AI or REST bonus, so the current plan rests on precedent that may not hold. **No online demo instance ships, at any point.**

### Epic 14: Governance, restraint and transcripts

An OcuPilot administrator can disable any write tool by tool and action, a user can take a script instead of an execution, log and tool content is defanged before it reaches the model, and every conversation persists per user under a retention policy. Polish week, in "the rest as time allows".

**FRs covered:** FR-72

**Implementation notes:** AD-22 fixed the shape in Release 1 so this fits without rework: keys are `tool` or `tool:action`; the **frozen baseline captured at the Release 1 freeze** means "pre-existing, therefore enabled", which is what keeps SM-3 holding through 2026-10-04; a key absent from it is disabled by default when it mutates; the baseline is never regenerated to grow; layers resolve with a null-coalescing cascade so an explicit `false` at any layer is honored; the read-only preset blocks anything it cannot classify; and **the audit ledger is configuration, not a governed tool**. The sanitizer is *additional* to NFR-6's invariants and is never the defense. An administrator opening another user's transcript is ledgered and sees tool results only when holding every resource that transcript's calls required.

### Epic 15: Shell conveniences and the theme

A user makes the portal their own - own password, favorites, recents, menu search, About, per-screen help, the shortcuts menu, the links panel, Home's system information, UI state that survives a sign-out, and a dark theme the community has been asking for. Polish week.

**FRs covered:** FR-73

**Implementation notes:** The theme toggle is a flag flip: both token sets already exist in `DESIGN.md` and are contrast-checked in both modes, and the chrome deliberately does not change with the theme. It lands in the status-bar account menu beside Change password. Per-user state must survive a sign-out, which puts it on the instance rather than in browser storage.

### Epic 16: The remaining polish-week extras

The second-tier screens and actions across five areas: a try-it console, web sessions, effective privileges, a permission-check tool, task export and import, background tasks, broadcast, license usage, the full dashboard, six secondary log viewers with a unified hub, and external language servers. Polish week, last, as time allows.

**FRs covered:** FR-74, FR-76, FR-77, FR-78

**Implementation notes:** FR-76's background tasks need a **custom endpoint**: the admin API's `/async-results` tracks its own asynchronous tasks, not the classic portal's `%CSP.UI.System.BackgroundTask` jobs, so parity needs both halves. FR-77's hub is where FR-70's per-entry explain entry points pay off across every source at once. Nothing in this epic may break a Release 1 screen or a Release 1 agent write; anything that risks either waits for Stage 2.

### Epic 17: The Open Exchange listing and the contest submission

A judge finds OcuPilot on Open Exchange, follows a README whose install steps work the first time on a clean machine, and reads a walkthrough that shows what an agent write looks like even without an API key. **Floating** - not a build step and not sequenced against one. It runs when the owner decides to release, which is why it sits after the polish week: nothing it publishes should depict a build that is not yet finished.

**FRs covered:** FR-69

**Implementation notes:** The trigger is the **owner's release decision**, not a date and not a preceding epic. The contest calendar is the outer bound it has to live inside, and each bound has a stated cost if the release decision falls after it: the Open Exchange listing must exist **before** any application is made; applications open at the 2026-09-14 kick-off and an earlier listing ranks higher on the contest page; a demo freeze must precede whatever description and video ship, because anything landing after it that touches UJ-3 forces both to be redone; and 2026-09-27 23:59 EST is the hard deadline, after which nothing counts. Releasing later than a bound does not move the bound - it forfeits what the bound was buying. The judge-without-a-key path is the epic's hardest content problem: no hosted demo ships at any point (owner decision, PK-19 removed), so screenshots plus a "get a key in two minutes" section per shipped provider are the whole mitigation.

### Epic 18: Stage 2 - the rest of the admin API

An operator reaches System Administration and System Operation parity on the hidden `/api/admin` service: namespaces with mappings, the database create, delete and properties wizards, every disk operation the contest list deferred, journals, licensing, ECP, superservers, authentication options, MFT, the four encryption pages, SQL privileges, and the web-application extras - each with a read tool and a confirmed single-write tool. First versioned IPM release after the contest.

**FRs covered:** none - 59 post-Release-1 catalog rows (S 20 / M 31 / L 8, 3 new REST endpoints)

**Implementation notes:** Row groups from `extract-stages.md`: SH-24; CP-35, CP-39, CP-41; WA-10 to WA-14; PM-19 to PM-22; SS-28 to SS-35; OS-16 to OS-22, OS-30; LG-11; SA-03 to SA-22; SO-01 to SO-08; PK-25. Gated by admin-v2 write payloads being observed, the `/async-result` polling pattern, SH-24's directory allow-list landing before any server-path picker, and the vendor's support stance on `/api/admin` - which this stage deepens dependence on. The agent's growth step here is confirmed single writes over the whole remainder, plus wallet-backed keys, context-window management as the tool roster roughly doubles, and proxy and custom-CA support. Epic 14's governance policy must cover this stage's new destructive actions as default-disabled.

### Epic 19: Stage 3 - System Explorer over the Atelier API

A developer gets classes and routines with source view, compile, delete, export, import and ETag-checked editing; search, compare and macro lookup; the SQL catalog with its query console behind a DML and DDL guard; and a data grid harvested from iris-table-editor with inline editing, staged saves and CSV export.

**FRs covered:** none - 36 post-Release-1 catalog rows (S 17 / M 15 / L 4, 0 new REST endpoints)

**Implementation notes:** Row groups: CP-36; OS-23; EX-02 to EX-34; DT-01. **EX-15 must ship with EX-14** - `action/query` executes any statement type unguarded, and the same guard protects the agent's free-form SQL tool, which Release 1 deliberately withheld. The Atelier port's authentication is decided as a choice between an explicit Basic header and a pass-through on the OcuPilot API: the JWT route is **closed, not untested**, because enabling JWT on `/api/atelier` means modifying a vendor web application, which OcuPilot does not do on an operator's instance. The iris-table-editor harvest lifts cleanly for the builders and formatters but needs three algorithms ported out of a 6,023-line vanilla-DOM grid, and its plaintext-password-in-server-memory session pattern is explicitly not carried.

### Epic 20: Stage 4 - Interoperability, with the Analytics rider

The Interoperability category appears for namespaces that support it: productions listed and controlled, items enabled and edited, per-host tabs, lookup tables, message search, resend and trace, and the three vendor Angular editors embedded in place - plus, as a rider, Analytics cube listing, the model browser, the MDX tool and the cube manager. The agent gains guided multistep workflows and Investigate entry points.

**FRs covered:** none - 41 post-Release-1 catalog rows (S 10 / M 25 / L 6, 4 partial new REST endpoints)

**Implementation notes:** Row groups: SH-23, SH-25; CP-37, CP-38; IO-02 to IO-29; AN-02 to AN-10. SH-23's sign-in hand-off gates every embed and is the stage's real risk: the `postMessage` contract has **no origin check**, the safer pre-written-`sessionStorage` alternative is untested, and AD-47 already forbids weakening the origin to make either work. The vendor bundles are never copied - they load in place from the instance. Four rows ship read-only first because their action halves need custom endpoints: queue and job actions, business-partner save and remove, and the message-contents renderer.

### Epic 21: Stage 5 - custom-REST parity from the MCP suite's handlers

Every remaining classic portal leaf with a backing class but no route becomes reachable: backup and mirroring, startup and memory tables, NLS locales, SQL settings, globals and the whole SQL tuning track, interoperability credentials, purge, deployment, record maps, workflow, the analytics editors, and a developer-tools set. The agent gains the 28 harvested inspection tools and undo by snapshot and revert.

**FRs covered:** none - 165 post-Release-1 catalog rows (S 60 / M 79 / L 26, 128 new REST endpoints)

**Implementation notes:** The largest stage by far, and the one AD-23 exists for: harvested `ExecuteMCPv2.REST.*` handler bodies inherit an OcuPilot base exposing the same `RenderResponseBody` signature, so **all 738 call sites move unedited** and only the envelope changes. Two harvest cautions carry forward: the MCP suite's manifest is stale and its bootstrap is TypeScript-driven, so handler bodies are taken and nothing else; and two known defects - the task-history filter and resource creation with a description - have unverified fix status, so current bodies must be read before harvesting. DT-11 lands before DT-09 and DT-10. Undo needs a state-capture model the write path does not yet have, which is why it waited this long.

### Epic 22: Stage 6 - the long tail, on demand

Nothing is scheduled. Each excluded row is picked up only when demand appears and its own gate clears, and keeps its stated reason for exclusion until then.

**FRs covered:** none - 56 post-Release-1 catalog rows (S 11 / M 29 / L 16, 32 new REST endpoints)

**Implementation notes:** Grouped by the catalog's exclusion reason: license-gated sharding (3); edition-gated HealthShare, Message Bank, Enterprise and ITK (11); deprecated shadowing and iKnow Text Analytics (9); Zen Reports, InterSystems Reports and cluster settings (6); low-usage device sub-pages and Windows-only pages; non-HL7 EDI schema authoring, DICOM, PubSub and adapter dialogs; full applications linked rather than rebuilt; and dead references and cosmetic items. A row leaves this epic only when someone asks for it and its gate is demonstrably clear.

---

## Epic 1: Install once, sign in, and reach the six areas

An operator clones the repository, runs one command, and reaches a working OcuPilot that signs them in without a form when the browser already holds an instance login - navigable across the six areas, showing only the screens their IRIS privileges allow, with every classic page OcuPilot has not rebuilt one click away. Build step 0; the foundation every later epic stands on and the half of the 2026-09-14 listing build that is not data.

### Story 1.1: The workspace, the pinned stack and one response envelope

As the builder,
I want a greenfield Angular workspace and ObjectScript tree on exactly the versions the architecture pins, with a single response and error writer already in place,
So that every later story compiles against a settled stack and cannot invent a second error shape.

**Acceptance Criteria:**

**Given** a clean clone with no `node_modules`
**When** the workspace is installed and built
**Then** `package.json` pins Angular 22.1.x, Angular Material and CDK 22.x, TypeScript exactly within `>=6.0.0 <6.1.0`, and an engines range of `^22.22.3 || ^24.15.0 || ^26.0.0`
**And** the build uses the `@angular/build` application builder with `outputHashing: all`, and no webpack builder appears in `angular.json`
**And** a build on Node 20, or with TypeScript 5.9 or 7.x installed, fails with a clear version error rather than compiling.

**Given** the ObjectScript tree
**When** any project class is added
**Then** it lives under `src/OcuPilot/` and nowhere else, in the package folders the spine fixes (`Api`, `Kernel`, `Screen`, `Area`, `Port`, `Install`, `Test`)
**And** no class, property, parameter or method name contains `%` or `_`, parameters carry a `p` prefix, locals a `t` prefix, and class names are short enough that the compiler does not hash the storage global.

**Given** the harvested `Response`, `Error` and `Log` classes from iris-couch and `Utils` from iris-execute-mcp-v2
**When** they are loaded into `Api/` and `Kernel/`
**Then** no name from the rename checklist appears anywhere in the tree - not `SessionAgent.*`, `ExecuteMCPv2.*`, `IRISCouch.*`, `/iris-couch/`, `^UnitTestRoot`, `iris_` or any `IRIS_*` environment variable
**And** `Utils`' `%Atelier` coupling is dropped.

**Given** any handler in the tree
**When** it produces a response
**Then** it never writes to the response device itself, returning success through the one `Response.JSON`/`JSONStatus` and failure through the one `Error.Render(status, slug, reason)` with a flat `{error, reason}` payload whose slug comes from a fixed enum
**And** a nested `Catch` returns `Return $$$OK` rather than a bare `Quit`
**And** a test asserts that no response body contains `}{`, paired with a test that every error path returns exactly one well-formed envelope carrying a slug from the enum.

**Given** the wire envelope
**When** a tool result and a screen both consume the same failure
**Then** the envelope also carries a stable machine code and an optional structured detail object, the screen rendering the human `reason` and the tool the machine code
**And** no slice has added a field of its own to the envelope.

### Story 1.2: The Lantern design-token layer

As a developer-administrator,
I want OcuPilot to render in one consistent visual system from its very first screen, in light and dark,
So that nothing shipped later has to be recoloured, and the contrast floor is met before any content exists to break it.

**Acceptance Criteria:**

**Given** the Angular Material 3 theme
**When** the token layer is applied
**Then** every Material 3 role carries its Lantern value, and the OcuPilot roles Material has no word for are defined - `shell`/`on-shell`/`shell-edge`, the four `agent-*` roles, `change-highlight`, `egress-warning`(+container), `restrained`(+container), `destructive`(+3), `success`, `warning`, `info`(+containers), `code-surface`/`on-code-surface`, `focus-ring`/`focus-ring-inner` and the four `server-flag-*` pairs
**And** light values sit on the bare role and dark values under `<role>-dark`, both complete
**And** Material's state-layer opacities, ripple, scrim, 38% disabled opacity and component anatomy are inherited unchanged.

**Given** any client source file
**When** the linter runs
**Then** a hardcoded colour value fails the build, and only tokens are permitted.

**Given** the type ramp and spacing scale
**When** a screen renders
**Then** `display` 16/600, `title` 14/600, `body` 13/400, `caption` 12/400, `label` 11/600 and `code` 12/400 monospace are the only text roles, with a 4px scale (4-8-12-16-20-24-32), 36px rows, 32px controls, 28px log rows and 4/6/12/9999px radii
**And** weight 700 appears nowhere, nothing readable renders below 11px, and table numbers are tabular and right-aligned.

**Given** Inter and JetBrains Mono
**When** the page loads with no network beyond the instance
**Then** both faces load from vendored woff2 inside the bundle with `system-ui` and `ui-monospace` fallbacks, and no request reaches any CDN or font host.

**Given** an automated contrast check over the rendered token pairs
**When** it runs in both modes
**Then** every pair in the load-bearing table meets 4.5:1 for text and 3:1 for non-text
**And** the three marginal pairs carry explicit guard tests - the teal name link on a selected row, the toast link on the dark inverse surface, and the `restrained` gated reason on a keyboard-active menu row, which fails in dark at 4.497:1 and therefore renders in `on-secondary-container` instead
**And** none of the four measured-and-rejected pairs is drawn anywhere.

**Given** the seven colour rules
**When** any component is reviewed
**Then** the chrome stays navy in both modes with on-chrome elements taking the dark variants; gradients appear only as the header band and the two 2px hairlines, never under text and never filling an area; teal is text only where it clears 4.5:1; no button, link, switch, chip or badge uses yellow; privilege-gated controls stay readable in `restrained` rather than dimmed; status colours travel with their own container; and a receded state is dimmed by role at full opacity, never by opacity.

**Given** `prefers-reduced-motion`
**When** any animated state changes
**Then** transitions are instant, skeletons do not pulse, the panel width does not animate, the change highlight does not settle, and spinners are replaced by the word "running".

### Story 1.3: The installer creates OcuPilot's protected state, resource and role

As an operator,
I want OcuPilot's own configuration, ledger and transcripts to be unreachable by anyone who merely holds rights on the install namespace's database,
So that the agent's records cannot be read or forged by the developers the portal is for.

**Acceptance Criteria:**

**Given** a fresh instance
**When** the installer runs
**Then** it creates a dedicated database holding OcuPilot's **globals only**, guarded by a dedicated resource no ordinary role holds, plus the OcuPilot administrative resource and a role granting it
**And** OcuPilot's **code** stays in the install namespace's normal database, because database READ is routine-execution permission and hiding the packages would make OcuPilot unrunnable by exactly the users it serves.

**Given** a user holding `%DB_<install-namespace>:RW` plus `%Admin_Operate` but not the OcuPilot administrative resource
**When** they attempt to read or write any OcuPilot table through SQL or any OcuPilot global directly
**Then** every attempt is refused, and an automated test proves it for both a table and a global.

**Given** OcuPilot's storage classes
**When** they read or write the protected database
**Then** they obtain the guarding role through a privileged routine application inside a `New $ROLES` frame, and the prior role set is restored on unwind
**And** no other class in the tree escalates.

**Given** an escalated frame
**When** it is active
**Then** nothing is spawned from inside it, because a `JOB` inherits `$ROLES` at the moment of the spawn and keeps it for the child's whole life
**And** nothing re-enters from inside it - a storage method never calls a tool, a port, or code that could.

**Given** the installer is run a second time against the same instance
**When** it completes
**Then** nothing changes, every created object was guarded by an existence check, and the namespace is restored as the first line of every `Catch` on any error path.

### Story 1.4: One command brings up an instance with OcuPilot installed

As a judge evaluating the entry,
I want `docker compose up` on a clean clone to give me a running instance with OcuPilot already installed and reachable,
So that the README's first promise holds before I have read anything else.

**Acceptance Criteria:**

**Given** a clean clone and no existing durable volume
**When** `docker compose up -d` runs to completion
**Then** an instance starts with OcuPilot installed, `_SYSTEM`'s password unexpired, auditing enabled and OcuPilot's audit event types registered, targeting `HSCUSTOM` when present and `USER` otherwise - the installer making that choice, not the manifest
**And** OcuPilot is reachable at the workspace's published web port
**And** the compose file pins an explicit 2026.2 image tag, never the floating `latest-cd`.

**Given** install runs at container start rather than image build
**When** the container starts against an existing durable volume
**Then** install runs again and reaches the same state, because `IRISSYS`, `IRISSECURITY`, `HSCUSTOM` and `USER` live on the volume and supersede the image's copies on every start.

**Given** a `docker compose down` followed by `up`, and separately an `up` with an image carrying a newer OcuPilot against the existing volume
**When** each completes
**Then** both reach the same working state with no manual step, the newer image upgrading the installed OcuPilot to its version.

**Given** install is still running
**When** a request arrives
**Then** the web applications do not accept traffic until install has completed or failed loudly, and the API refuses with a clear "installing" or "upgrade required" response rather than serving a partial state
**And** a version stamp written at the end of install is what the API checks, a stamp older than the deployed code meaning upgrade has not finished.

**Given** the installer creates the two web applications
**When** it finishes
**Then** it reports - and does not silently depend on - the CSP Gateway registration gap, because `Security.Applications.Create()` does not notify the Gateway and a new application may 404 until an SMP Save or Gateway restart
**And** it reports the current Web Gateway response timeout as information only, never as a prerequisite and never changing it.

**Given** the compose flow's clearly named demo opt-in flag is set, as it is in this repository's own `docker-compose.yml`
**When** install completes
**Then** the walkthrough fixtures exist - a disabled `/csp/myapp` carrying no resource, a demo SSL/TLS configuration and a self-signed X.509 credential - namespaced so they cannot collide with a real application
**And** with the flag absent, as on every other install path including IPM, no fixture is created.

### Story 1.5: The static shell serves the SPA, including deep links

As a developer-administrator,
I want any OcuPilot URL to load correctly when I paste it or reload it,
So that a bookmark, a shared link or a browser refresh behaves the way every other web application does.

**Acceptance Criteria:**

**Given** the `/ocupilot` static application
**When** it is created
**Then** it serves files unauthenticated with a non-root base href set at build time, like the vendor's own `/ui/interop`, and carries no application or matching roles.

**Given** a deep client route such as `/ocupilot/permissions/users/_SYSTEM?ns=HSCUSTOM`
**When** it is loaded cold or reloaded
**Then** the catch-all returns `index.html` and the client routes to that screen with its selection intact.

**Given** a request naming a file
**When** the static handler resolves it
**Then** it applies both a literal `..` rejection **and** a post-normalization prefix containment check, serving `index.html` for anything unresolved
**And** it never reflects its input, accepts no filesystem path from a caller, and streams in bounded chunks
**And** hashed assets carry immutable cache headers while `index.html` carries no-cache.

**Given** the served bundle
**When** the page loads
**Then** a restrictive Content-Security-Policy names only the instance's own origin, no CDN is reachable, every library is vendored, and no runtime evaluation of fetched text occurs.

**Given** the static application is unauthenticated by design and a Minimal-security instance ships `%Service_CSP`'s `UnknownUser` holding `%All`
**When** any OcuPilot gate evaluates a caller
**Then** it resolves the **authenticated** user and rejects the `UnknownUser` and `_PUBLIC` placeholders explicitly, never inferring authorization from roles alone
**And** the static application serves only files.

### Story 1.6: Silent-first sign-in

As a developer-administrator who already has the classic portal open,
I want OcuPilot to let me straight in without a login form,
So that moving between the old portal and the new one costs me nothing.

**Acceptance Criteria:**

**Given** the browser already holds an instance login in the `%ISCMgtPortal` group
**When** the shell loads any route
**Then** it attempts an empty-body `POST /api/ocupilot/login` first, receives a fresh token pair for the same user, and shows **no form**, landing on the requested route
**And** while the probe is in flight the shell chrome renders with a content skeleton and the status bar reads "Signing in...".

**Given** a cold browser with no such cookie
**When** the silent probe returns 401
**Then** OcuPilot shows its own form login once, with the requested route preserved and restored after sign-in
**And** a rejected attempt keeps the user name, clears the password, and reports "Sign-in failed. Check the user name and password." beneath the fields as an alert
**And** the expired-password variant names the user and links both to the classic portal and to the README's fix.

**Given** a successful form login
**When** it completes
**Then** the browser is also signed into the vendor's editors and into the classic portal by the same `GroupById` mechanism
**And** the classic portal shares the browser-level login only - `/csp/sys` is not JWT-enabled, so it rides the CSP session cookie and the browser id, and the token pair is never presented to it.

**Given** the token pair
**When** any API call is made
**Then** it travels only as `Authorization: Bearer <access>` from **per-tab** storage, never in a cookie, never in persistent browser storage, and never posted into an embedded frame
**And** a cookie alone never authorizes a data call
**And** no cross-tab broadcast of the token exists.

**Given** an access token approaching expiry, or any 401
**When** the API service notices
**Then** it refreshes once via `POST /api/ocupilot/refresh` with the refresh token **in the JSON body** - a refresh token sent as a Bearer is refused - and retries, invisibly
**And** refresh is a background concern of the API service that no screen and no panel handles, because a turn can outlive an access token
**And** a failed refresh runs the silent probe once more before showing the form, then returns the user to the form login with "Your session ended. Sign in to continue." and the current route preserved.

**Given** the development loop
**When** `ng serve` runs
**Then** it proxies through the IRIS origin rather than serving from a second origin, because the browser-id cookie is `SameSite=Strict`
**And** no CORS allowance exists in either the development or the production configuration.

### Story 1.7: Sign-out

As a production administrator,
I want signing out of OcuPilot to end my instance login everywhere it was minted,
So that leaving a shared machine does not leave an authenticated session behind.

**Acceptance Criteria:**

**Given** an authenticated session
**When** the user chooses Sign out from the status bar's account menu
**Then** `POST /api/ocupilot/logout` is sent carrying **both** the Bearer and the cookie - a Bearer-only logout leaves the browser-level login intact
**And** every JWT-enabled application in the vendor's group, the vendor's editors included, stops minting tokens for that browser.

**Given** sign-out has completed
**When** the user lands
**Then** per-tab storage is cleared and the form login shows "You're signed out."

**Given** the classic portal is open in another tab
**When** the user signs out of OcuPilot
**Then** the authenticated session has ended, but no promise is made that a login form appears - `/csp/sys` also permits unauthenticated access, so it may keep rendering as an unauthenticated session
**And** the acceptance test asserts the session ended, not that a form appeared.

**Given** the user was signed out elsewhere - by the classic `?IRISLogout=end` or by another JWT application revoking the session
**When** OcuPilot makes its next call
**Then** it discovers the condition, runs the silent retry once, and either recovers silently or lands on the form login with the session-ended message.

### Story 1.8: Instance identity and the API version guard

As a developer-administrator,
I want OcuPilot to tell me plainly when it cannot manage this instance,
So that I never see a screen of half-working data and mistake it for the truth.

**Acceptance Criteria:**

**Given** the shell loads
**When** it reads instance identity
**Then** it verifies from one call that the admin API is present at version 2 and reads the instance name and version the header will show.

**Given** the admin API reports a version other than 2, or is absent
**When** the shell resolves that call
**Then** a blocking notice renders in the content column, in the empty-state shape with an error banner, naming the mismatch and linking to the classic portal
**And** no area screen loads, and the rail, side bar and command box are inert.

**Given** a signed-in user holding no `%Admin_*` resource
**When** the same call returns the admin API's 403
**Then** the shell renders "no administrative privileges on this instance" with a sign-out link, in the empty-state shape with an error banner
**And** it is never presented as a version mismatch, and the two notices never dress as each other.

**Given** `AdminPort` starts
**When** it verifies the instance
**Then** it confirms v2 and that a named probe endpoint answers, failing loudly with an actionable message rather than degrading silently.

**Given** CI runs
**When** the endpoint-inventory fixture executes
**Then** it re-derives from the running instance which classes exist, which publish a body-template method, which have an async path and which touch CSP state, and fails the build when the instance disagrees with the checked-in inventory.

### Story 1.9: The screen descriptor registry and privilege-driven navigation

As a developer-administrator,
I want to see every screen the six areas offer and open only the ones my IRIS privileges allow, with the rest telling me what they would need,
So that I learn the instance's permission model from the portal instead of from a denial.

**Acceptance Criteria:**

**Given** the screen descriptor mechanism
**When** a screen is declared
**Then** exactly one hand-written declarative class carries its route, area and side-bar position, archetype, privilege set, entity-type key and scope, id accessor, context serializer with its secret-typed field list, primary and row actions with their self-protection rules, empty-state text, command-box aliases, and the classic page it replaces
**And** the route table, the navigation entry and the privilege gate all resolve **through** that descriptor at build or startup, so adding a screen never means editing a router or a nav list.

**Given** a descriptor's privilege declaration
**When** the gate evaluates it
**Then** it is a set of `(resource, permission)` pairs, never a single resource - the security APIs need `%DB_IRISSYS:R` **and** `%Admin_Secure:U` together on 2026.2 - and the gate requires all of it
**And** the privilege set is the union of the admin API's requirement and any custom resource an operator has assigned to the classic page this screen replaces
**And** a denial names the pair that failed.

**Given** the entity-type vocabulary
**When** a descriptor selects one
**Then** it comes from a single closed enum owned by the kernel, and the build fails on a value not in it.

**Given** a user lacking a screen's privilege
**When** they see it in the rail, side bar, command box or an area tile
**Then** the entry stays listed and focusable with `aria-disabled="true"` - **never** the `disabled` attribute and never hidden - naming the required resource as a tooltip on hover **and** focus where the control takes DOM focus, and inline after the label in the side bar and command box
**And** in menus and result lists, where Material's key managers skip disabled items and no tooltip can show, the entry renders as a non-selectable row with the reason inline as part of its accessible name.

**Given** the user deep-links to a gated route
**When** the screen loads
**Then** it renders its title and a permission-denied message naming the resource, and the rest of the shell keeps working.

**Given** the rail and side bar
**When** they render
**Then** the rail carries eight items in daily-use order with Agent co-pilot pinned bottom, is one Tab stop with Up/Down moving between items, marks the active area with `aria-current="page"` and a solid 3px `secondary-dark` left indicator, and shows no count badge
**And** a rail-item opens its area's side bar without navigating, while clicking the active item collapses it; Home is the exception and navigates
**And** the side bar is fixed at 240px with no sash, grip or resize cursor, lists only screens that are built, remembers its open state per browser, and toggles with Ctrl/Cmd+B.

### Story 1.10: Header, status bar and page chrome

As a developer-administrator,
I want to see at a glance which server, instance and namespace I am about to change, and where I am inside the portal,
So that I never make a change on the wrong instance because the screen looked the same.

**Acceptance Criteria:**

**Given** any route
**When** it renders
**Then** the 48px header carries the reversed logo lockup at 32px directly on the navy (no plate, no hover state, linking to Home with the accessible name "OcuPilot - Home"), the command box centred at 360px, and the namespace switch at the right
**And** the header gradient runs `shell` to `shell-edge` left to right, and **no text in the header is drawn below 100% opacity**, because 72% on the gradient's end measures 3.60:1.

**Given** the 24px status bar
**When** it renders
**Then** it shows server, instance name and version, the user, and licensed-to on the left, and the server-flag badge, the auto-refresh stamp and the connection state on the right, each connection state's coloured disc always followed by its word
**And** the user segment is the bar's **only** interactive element, opening the account menu with Sign out
**And** the server-flag badge shows Live, Test, Failover or Development in its own colour pair with Live in red, appears in the status bar and on Home's instance line, and **never in the header**.

**Given** any screen
**When** it renders
**Then** a locator bar names area, screen and selected entity as a `nav` labelled "Breadcrumb", each segment navigating, separators `aria-hidden`, the current segment `display`-sized and not a link, and the entity segment in `code` appearing on selection and dropping when it clears
**And** the namespace is not a locator segment.

**Given** the command bar
**When** it renders
**Then** it holds the screen's primary action left, the filter field with a polite match count, view options, sort, the auto-refresh chip where the screen supports it, further actions as text buttons, and the last-update stamp right-aligned
**And** row actions are `aria-disabled` with "Select a row first" until a row is selected
**And** every command-bar action is reachable from the command box, and every row-menu item also appears here when a row is selected.

**Given** the command box
**When** the user presses Ctrl/Cmd+K
**Then** it opens as a `combobox` with `aria-expanded`, `aria-controls` and `aria-activedescendant`, filtering every screen the user may open plus the current screen's actions against alias lists drawn from the contest wording, with results grouped as Screens and Actions and a polite count
**And** the chord shows once as a kbd chip at the field's right edge, never repeated in the placeholder
**And** it is **not** a channel to the agent - typed text never becomes a turn - and it never shows the avatar.

### Story 1.11: The namespace switch as data scope

As a developer-administrator managing several namespaces on one instance,
I want switching namespace to change what the screen is reading, not just what a label says,
So that a change I make lands where I am looking.

**Acceptance Criteria:**

**Given** the namespace selector
**When** it opens
**Then** it lists only namespaces the user can read and write, with the accessible name "Namespace".

**Given** the user chooses a namespace
**When** the selection resolves
**Then** the route's `ns` parameter updates, the current screen **re-fetches in that namespace rather than re-routing**, and the context chip updates
**And** no URL is rewritten into another web application and no dialog appears.

**Given** any read or write on a namespace-scoped screen
**When** it executes
**Then** it runs against the namespace on the route, and that namespace travels as the scope half of every entity reference crossing a boundary.

**Given** an entity reference crossing any boundary - a change event, a proposal target, a highlight target, an audit marker
**When** it is constructed
**Then** it carries the triple `(entity type, scope, id)`, where scope is the namespace for a namespace-scoped object and the literal `instance` for a configuration object that has none
**And** a task named `Nightly purge` in `USER` and one in `HSCUSTOM` resolve as different entities.

**Given** an entity id containing a leading underscore, a slash, a space, a percent sign or a non-ASCII character
**When** it is placed in a route and read back
**Then** it occupies exactly one path segment, percent-encoded and decoded by one shared pair of functions used by every slice
**And** a round-trip test over that fixed corpus passes.

### Story 1.12: Home

As a developer-administrator arriving at OcuPilot,
I want a first screen that shows me the six areas and what each one contains,
So that I can reach anything in one step without learning a menu.

**Acceptance Criteria:**

**Given** a signed-in user lands on Home
**When** it renders
**Then** six area tiles appear in daily-use order in an auto-fit grid that **wraps** rather than forcing a horizontal scroll, each carrying a 24px icon, the area name and the area's Release 1 side-bar entries joined by a separator so the contest's named screens are visible on Home
**And** Home itself and the Agent co-pilot get no tile - Home is the surface and the agent is reached from the rail
**And** the instance line renders beneath the tiles with server, version, namespace, flag and user.

**Given** the user activates a tile by click or Enter
**When** it resolves
**Then** the area's first screen opens with its side bar open.

**Given** a tile whose area the user lacks privilege for
**When** it renders
**Then** it stays focusable and `aria-disabled` with the required resource named in a tooltip on hover and focus, never hidden.

**Given** Home renders
**When** the panel is present
**Then** the panel widens to `min(50vw, viewport - rail - content-min-width)` over a 120ms transition and restores its remembered width on leaving Home
**And** under reduced motion the width change is instant.

### Story 1.13: Uniform error handling and the connectivity probe

As a developer-administrator,
I want every failure to tell me what happened and what to do about it,
So that I can act on an error instead of guessing at it or leaving for the documentation.

**Acceptance Criteria:**

**Given** any server failure
**When** the shell renders it
**Then** admin API and OcuPilot API errors render identically from the one envelope, in the presentation the state matrix specifies for that surface.

**Given** a 401
**When** it is received
**Then** the refresh-and-retry path runs once, invisibly, and the user sees nothing.

**Given** a 403
**When** it is received
**Then** an inline message with `role="alert"` names the missing privilege and the action to take, and the data already on screen stays.

**Given** a failed call
**When** the shell cannot tell why
**Then** a connectivity probe runs and the result distinguishes **"instance unreachable"** - one alert banner at the top of content with Retry, and the status bar reading "Instance unreachable - retrying" - from **"request refused"**.

**Given** a 5xx or an unhandled exception
**When** it reaches the browser
**Then** the message is generic, with Retry and a link to messages.log, while the instance logs the detail in full through the one structured logger with secrets redacted before emission.

**Given** a `%Status` from an `%Api.Admin.*` class, which is written for a portal developer and names internal classes and ids
**When** it crosses the port boundary
**Then** it is mapped to an OcuPilot slug and a written reason, the raw text kept only for the log and the ledger.

### Story 1.14: The auto-refresh framework

As a production administrator watching a live instance,
I want lists to keep themselves current without losing my place,
So that I can watch a process or a task without re-sorting and re-filtering every few seconds.

**Acceptance Criteria:**

**Given** a screen whose descriptor declares that it refreshes, and its permitted rates
**When** the framework binds it
**Then** one shared timer, one persisted per-screen setting and one silent re-fetch serve every such screen - no screen implements its own.

**Given** auto-refresh is on
**When** a tick fires
**Then** the re-fetch is silent - no spinner, no skeleton, no announcement - and sort, filter, selection, scroll and max rows are unchanged afterwards
**And** the command-bar chip reads the chosen rate and the status-bar stamp shows the last update, neither of them ever announced to assistive technology.

**Given** the user changes rate, sort, filter or max rows
**When** they leave and return to that screen
**Then** the setting persists per screen.

**Given** a screen refreshes through the framework
**When** it fetches
**Then** it uses the same descriptor-declared read as everything else, bounded by a max-rows cap that reports whether it truncated
**And** nothing returns an unbounded collection.

**Given** the proposal lifecycle will later publish proposal-open and proposal-closed events for a scoped entity type
**When** the framework is built
**Then** it already subscribes to that channel and suspends its timer while a proposal against its entity type is live, resuming on close - so the pause has a channel to travel on before there is anything to pause for.

### Story 1.15: Classic portal fallback links

As a developer-administrator,
I want anything OcuPilot has not rebuilt to be one click away in the classic portal,
So that a screen OcuPilot lacks never becomes a task I cannot do.

**Acceptance Criteria:**

**Given** a screen shipped as a reduced form
**When** it renders
**Then** it ends with a `classic-link-card` titled "More in the classic portal", naming the classic page it opens, opening in a new tab, with a caption noting the classic portal may ask the user to sign in again
**And** it carries the daily-administration fields plus the link - **never a half-working full form**.

**Given** a list screen in any of the six areas
**When** it renders
**Then** it carries **no** link out to the classic portal, and an automated check asserts this across every list descriptor.

**Given** any classic page in the six areas that OcuPilot has not rebuilt
**When** the user looks for it
**Then** it is reachable from the corresponding OcuPilot screen.

**Given** an editor that is cut
**When** it ships reduced
**Then** its agent write tool ships regardless, so the change is still reachable through a confirmed proposal.

### Story 1.16: The IPM module, generated from one roster

As an operator who already runs IPM,
I want to install OcuPilot with one command and no Node toolchain,
So that adopting it costs me nothing beyond the install.

**Acceptance Criteria:**

**Given** the IPM module
**When** it is published
**Then** it declares the two web applications, the file copy of the **built** Angular bundle, the package resource, the installer invoke and system requirements for IRIS 2026.2+ and IPM 0.10.x, using `<WebApplication>` rather than the deprecated `<CSPApplication>`
**And** the built bundle is inside the archive, so install needs no Node toolchain.

**Given** the installer's class roster and the IPM manifest's resource list
**When** either changes
**Then** both are generated from one source and cannot drift, and a test proves the generated manifest matches the roster.

**Given** the Docker path
**When** it installs
**Then** it does **not** use IPM, because the official 2026.2 image ships no IPM at all - zero `%ZPM*` classes anywhere - and nothing in the install path may assume it exists.

**Given** the namespace choice
**When** install resolves it
**Then** the installer picks `HSCUSTOM` if present and `USER` otherwise, in installer code rather than in `module.xml`, because the manifest is evaluated after the namespace is fixed
**And** the README documents how to override it.

### Story 1.17: The smoke script, the readiness endpoint and CI

As the builder,
I want one script that decides whether a build is installed and working,
So that "this step is complete" means the same thing every time and the cut line has an owner.

**Acceptance Criteria:**

**Given** a clean container
**When** the smoke script runs
**Then** it exercises sign-in, one live list per area, one confirmed agent write and the audit marker, and its result is the definition of "installed and working"
**And** it is owned by `Install/` rather than by any slice, and is what CI runs and what the build order's completion test means
**And** at build step 0 it asserts every part that exists so far and reports the rest as pending rather than passing vacuously.

**Given** an unauthenticated caller
**When** they request the readiness endpoint
**Then** it reports only whether OcuPilot is installed, its version stamp, and whether install is still running - **no instance detail and nothing that aids reconnaissance**
**And** any deeper health view is authenticated and privilege-gated like any other read.

**Given** CI runs against a throwaway container
**When** the suite executes
**Then** it builds the Angular bundle, lints, runs the ObjectScript unit and HTTP integration suites and the client unit tests, and runs the endpoint-inventory fixture
**And** it greps for and fails on any CDN reference and on embedded Python in any shipped class
**And** every handler has an HTTP integration test asserting status, content type and body shape, and no test class carries a property whose name begins with `Test`.

**Given** both stock Community images - IRIS Community and IRIS for Health Community
**When** the suite runs against each
**Then** it confirms the admin API is present on both and no HealthShare-only dependency exists
**And** the plain-Community install path, where install falls back to `USER`, is deferred by owner decision to after the 2026-09-27 floor, with the risk of a late failure recorded and accepted.

---

## Epic 2: Every area shows live instance data

A user opens each of the six areas and sees real data from the instance they are on - not a mockup - with the first page inside two seconds at a thousand rows, sort and filter preserved across refresh, and every list backed by exactly one descriptor-declared read that the agent's read tool will later share. Build step 1; completing it makes the 2026-09-14 listing build submittable.

### Story 2.1: The AdminPort reproduces the vendor's dispatcher, exactly once

As the builder,
I want one class that knows how to call the instance's own admin endpoints correctly,
So that seventy vendor endpoints are not reimplemented, and a failure never arrives disguised as an empty success.

**Acceptance Criteria:**

**Given** any admin-API-backed read or write anywhere in OcuPilot
**When** it executes
**Then** it goes through `Port/AdminPort`, which is the **only** code in the tree naming an `%Api.Admin.*` class - no slice, screen, tool or test references one directly
**And** an automated check asserts that containment, so the blast radius of a vendor change is one file.

**Given** the port invokes an endpoint
**When** it runs the sequence
**Then** it constructs `%Api.Admin.Endpoints.<X>.%New(type, 2)`, supplies stub `%request` and `%response` objects with `IsRunningAsync = 0`, seeds query parameters and calls `ValidateQueryParams()`, evaluates `ResourcesOR()` with `$System.Security.Check(res, "U")` and refuses on failure, calls `ValidateRequest(body)` then `ValidateSemantics()`, wraps `Run()` in `BeginCaptureOutput`/`EndCaptureOutput`, maps a `<PROTECT>` exception to 403, and reads the outcome from **both** `tSC` **and** `%response.Status`.

**Given** `IsRunningAsync` were left at 1
**When** an endpoint sets a status
**Then** the base class's `If '..IsRunningAsync` guard would discard it - so a regression test asserts that a GET for a non-existent web application reads **404**, not the 200 the async flag produces.

**Given** `ValidateQueryParams()` were skipped
**When** the call ran
**Then** the endpoint's identifying property would be empty and the call would fail with a misleading "Invalid Application name" - so a test asserts the identifying property is populated before `Run()`.

**Given** an endpoint returns a non-2xx `%response.Status` while `tSC` is `$$$OK`
**When** the port evaluates the outcome
**Then** it raises the failure and never returns an empty success.

**Given** `ShouldRunAsync()` is evaluated **per request type, never per class**
**When** it returns true
**Then** the port hands off through `%Api.Admin.Util.AsyncTaskEndpoint` and polls, exposing the result to slices as an ordinary call that resolves later - **no slice writes polling logic**
**And** for the three classes that use `%request` only as `..GetName(%request)` to label an async task, the port supplies a synthetic label instead
**And** exactly two Release 1 paths take this branch: the audit record LIST and the database directory info call.

**Given** the port starts
**When** it verifies the instance
**Then** it confirms the admin API reports v2 and that a named probe endpoint answers, failing loudly with an actionable message rather than degrading silently.

### Story 2.2: Write-tool field lists are derived at build time and pinned in CI

As the builder,
I want every write payload's field list to come from the endpoint that consumes it,
So that forty write forms cannot drift from the vendor, and "exercise the payload on the instance" stops being the first task of every write story.

**Acceptance Criteria:**

**Given** a build step that reads the running instance
**When** it runs
**Then** it emits each endpoint's field list and each field's JSON type **as committed source**, reviewed like any other code - nothing derives a schema at runtime, so a tool's contract cannot change under a running instance.

**Given** the body-template method is not uniformly named
**When** the generator resolves it
**Then** it tries `RequestBodySchema`, then `PutRequestBodySchema`, then `PutAndPostSchema`, then `Schema`, in that order.

**Given** what the template actually returns is a prototype of placeholder values - `""` for a string, `true` for a boolean, `[""]` for a list - and carries **no** `required`, `enum` or `description`
**When** a tool schema is completed
**Then** those three are authored **once per tool**, reviewed, and are the only hand-written part
**And** a write tool whose field list was typed by a human for an endpoint that publishes a template fails review.

**Given** generation classifies each derived field as ordinary or secret
**When** it emits the descriptor
**Then** a field the generator cannot classify is treated as **secret**, and a field whose name matches the credential pattern emitted as ordinary **fails the build** - so a classification miss fails the build rather than reaching the model, the proposal store, the diff or the ledger
**And** the vendor templates' own credential fields, `Security.User`'s `Password` among them, are removed at derivation rather than anywhere downstream.

**Given** sixteen mutating endpoints publish no template at all, five of them in Release 1
**When** those five are handled
**Then** `Wallet.Secret` and `Security.Audit.Event`, which are field-bearing, have their field lists derived from the underlying `Security.*` / `%SYS.*` class and pinned by a test that fails when the instance disagrees
**And** `Process`, `Lock` and `Task.Manager`, which are action-style with trivial or empty bodies, are recorded as needing no template.

**Given** CI runs
**When** the endpoint-inventory fixture executes
**Then** it re-derives the inventory - which classes exist, which publish a template, which have an async path, which touch CSP state - from the running instance and **fails the build** when the instance disagrees, so an upgrade that moves the ground is caught by the suite rather than by a user.

### Story 2.3: One descriptor-declared read serves both the screen and its read tool

As a developer-administrator,
I want the agent to see exactly what my screen sees,
So that its answer can never describe data I am not looking at.

**Acceptance Criteria:**

**Given** a screen descriptor
**When** it declares its read
**Then** the screen's list and its read tool resolve through **one** declaration and cannot diverge in filter, sort or field set.

**Given** a screen is added
**When** the registry loads
**Then** its read tool is registered from the descriptor with no hand-written tool code, named `<area>.<screen>.read` in lower case with dots only and **no `iris_` prefix**
**And** the tool declares `read` at definition time; a tool declaring neither `read` nor `write` **fails the build**.

**Given** any read
**When** it executes
**Then** it is bounded by a max-rows cap and reports whether it truncated, and nothing returns an unbounded collection
**And** paging is by explicit cursor where the backing route offers one and by the max-rows cap where it does not.

**Given** the read tool's view of a screen
**When** it is produced
**Then** it is the screen's view narrowed by the context cap and stripped of secret-typed fields - never a wider or separately written query.

**Given** the tools registered in this epic
**When** they are invoked
**Then** they are not yet dispatchable, because the registry, the caller context and the turn that calls them arrive in Epic 4 - and no story here depends on that arriving.

**Given** the tool registry harvested from iris-session-agent
**When** it is ported
**Then** its flat-`Super` equality SQL is replaced with `%IsA` or a recursive walk, and the schema-driven argument validator the original lacks is added.

### Story 2.4: The data table

As a developer-administrator,
I want every list in OcuPilot to look and behave the same, and to stay usable at a thousand rows,
So that learning one screen teaches me all sixty.

**Acceptance Criteria:**

**Given** any list screen on a Community container holding a thousand rows
**When** the user navigates to it
**Then** its first page renders within two seconds.

**Given** the table renders
**When** it draws
**Then** it uses CDK virtual scroll over a capped fetch - default 1,000 rows, persisted per screen with sort and filter - with a 36px sticky `label` header, 36px body rows, `code` for identifier columns, tabular right-aligned numbers, a 7px status disc before an enabled or disabled word, "(none)" for empty values, and the row-overflow trigger last
**And** the footer shows the row count and an editable, labelled max-rows field, with **no page-size control**
**And** at the cap the table says "Showing the first 1,000 rows. Narrow the filter or raise the max rows."

**Given** the name cell
**When** it renders
**Then** it is a link and looks like one - teal, underlined on hover and focus, pointer cursor - so that clicking the name (open) and clicking the row (select) read as different gestures.

**Given** the keyboard
**When** the table has focus
**Then** it is `role="grid"` and **one Tab stop**, with focus staying on the grid container and `aria-activedescendant` naming the active row, so virtual scroll and in-place re-fetch can never recycle or drop a row that holds focus
**And** Up/Down/Home/End/PageUp/PageDown move the active row **and select it**; Right/Left step into the row's cells and back; Enter opens the detail or editor route; Alt/Option+Down and the `contextmenu` event open the row menu
**And** deleting the focused row moves focus to the next row, else the empty-state, else the filter.

**Given** the eight row states
**When** each occurs
**Then** hover, selected (a 3px teal left bar, one row at a time), keyboard focus (an inset ring), changed (the change-highlight background, a 3px `agent-accent` bar and a "Changed" tag, settling over 2s and holding until the next interaction), **selected and changed** (the highlight background wins, the bar is teal, the tag stays), loading (skeleton rows), empty (the empty-state inside the table frame) and refresh-paused each render as specified.

**Given** an empty list
**When** the empty-state renders
**Then** it names the scope in one `title` sentence, says what to do next, offers the single primary action where one exists, and - on a **write-capable** list - invites the agent on its second line
**And** a permission-denied screen or a refused document is **not** an empty-state; it shows the refusal.

### Story 2.5: The web applications list

As a developer-administrator,
I want to see every web application on this instance with its state,
So that I can tell at a glance which ones are reachable and which are not.

**Acceptance Criteria:**

**Given** the Web applications screen
**When** it loads
**Then** it lists name, namespace, type, enabled, dispatch class and resource from `GET /web-apps` through `AdminPort`, with a filter
**And** name, dispatch class and resource render in `code`.

**Given** the demo fixture ran
**When** the list renders
**Then** `/csp/myapp` appears showing Enabled "No" and no resource - the row UJ-3 acts on.

**Given** the user lacks the required privilege
**When** they reach the screen
**Then** the entry is gated in the rail, side bar and command box naming the resource, and a deep link renders the title plus a permission-denied message.

**Given** the descriptor
**When** it is declared
**Then** it names the classic page this screen replaces, so an operator's custom resource assignment on that page still applies
**And** it declares the entity-type key from the kernel's closed enum, its scope, and the id accessor.

**Given** a name containing a slash, such as `/csp/myapp`
**When** it is used in a route
**Then** it round-trips as one percent-encoded path segment.

### Story 2.6: The users list

As a developer-administrator,
I want to see every user on the instance and which of them can actually log in,
So that I can answer "who has access here?" without opening each account.

**Acceptance Criteria:**

**Given** the Users screen
**When** it loads
**Then** it lists name, full name, enabled, type and roles from `GET /security/users` through `AdminPort`, with a filter.

**Given** a user account that is disabled or expired
**When** the row renders
**Then** the state is readable as a word, never by colour alone - which is what makes UJ-1's question answerable from the list.

**Given** the screen's privilege set
**When** the gate evaluates it
**Then** it requires every `(resource, permission)` pair the security APIs need together, not one resource, and names the pair that failed on denial.

**Given** a user name with a leading underscore, such as `_SYSTEM`
**When** it is used in a route
**Then** it round-trips as one percent-encoded path segment.

### Story 2.7: The SSL/TLS configurations list

As a developer-administrator,
I want to see the instance's SSL/TLS configurations,
So that the area the contest names most specifically has live data from the first build.

**Acceptance Criteria:**

**Given** the SSL/TLS screen
**When** it loads
**Then** it lists the instance's configurations from `GET /security/ssl-configurations` through `AdminPort`, with a filter.

**Given** the demo fixture ran
**When** the list renders
**Then** the seeded demo configuration appears, so the README walkthrough has something to show on a fresh container rather than an empty list.

**Given** any read of a configuration
**When** it returns
**Then** no private key material is included in any field, at any point.

**Given** the Security and secrets area's other lists are not yet built
**When** the side bar renders
**Then** only SSL/TLS appears - a screen that is not built does not appear, and there are no dead entries.

### Story 2.8: The task schedule list

As a developer-administrator,
I want to see the scheduled tasks and whether the Task Manager is running them,
So that I can tell whether the instance's housekeeping is actually happening.

**Acceptance Criteria:**

**Given** the Task schedule screen
**When** it loads
**Then** it lists scheduled tasks with at least name and namespace, plus last run and next run, from `GET /tasks` through `AdminPort`, with a filter.

**Given** the Task Manager is suspended
**When** the screen renders
**Then** a warning banner above the table reads "The Task Manager is suspended - no scheduled task will run until it is resumed." with a Resume action, privilege-gated
**And** the rows still list.

**Given** the demo fixture ran
**When** the list renders
**Then** a task suspended after an error appears - the row UJ-6 acts on.

**Given** the screen declares auto-refresh
**When** the user turns it on
**Then** it refreshes through the shared framework, silently, preserving sort, filter, selection and scroll.

### Story 2.9: The processes list

As a production administrator,
I want to see what is running on this instance right now,
So that I can find the process behind a problem without leaving for the classic portal.

**Acceptance Criteria:**

**Given** the Processes screen
**When** it loads
**Then** it lists processes from `GET /processes` through `AdminPort`, with a filter, an editable max-rows cap and a sort that persists per screen.

**Given** the screen declares auto-refresh
**When** the user sets a rate
**Then** it refreshes silently on that interval, the status-bar stamp updating, with sort, filter and selection unchanged.

**Given** process ids
**When** they render
**Then** they are set in `code`, and numeric columns are tabular and right-aligned.

### Story 2.10: The audit database viewer, with its agent-marker filter

As a developer-administrator,
I want to search the instance's audit database and filter it to agent activity,
So that the claim "every agent write is marked" is checkable the moment the agent can make one.

**Acceptance Criteria:**

**Given** the Audit database screen
**When** it opens
**Then** it presents a criteria form first - time range, source, type and name, user, process id, namespace, authentication and text - and shows a skeleton only after Search is pressed, because this list searches on the server and does not auto-refresh.

**Given** a search
**When** it executes
**Then** it goes through `AdminPort`'s **async** path, because the audit record LIST is one of the two Release 1 async endpoint types, and the port exposes it as an ordinary call that resolves later.

**Given** results
**When** the user opens a row
**Then** a read-only detail dialog shows the full event including its description and any JSON payload.

**Given** the agent-marker filter
**When** the user applies it
**Then** the list narrows to events carrying OcuPilot's agent marker - the filter existing here from build step 1 so that Epic 5's first confirmed write has somewhere to be found, and UJ-3's resolution and SM-4's one-minute demo both have an end point.

**Given** OcuPilot's own audit events
**When** the viewer lists events
**Then** they appear as ordinary rows and are **never hidden** - a portal that concealed its own writes would be the anti-pattern the product exists to correct - and the marker filter is an affordance, not a default.

**Given** no events match
**When** the list renders
**Then** it reads "No events match." rather than a generic empty message.

### Story 2.11: The messages.log paging endpoint

As a production administrator,
I want to read messages.log from OcuPilot without loading a hundred-megabyte file into my browser,
So that I can find a warning in the log the instance actually writes.

**Acceptance Criteria:**

**Given** the OcuPilot API's messages.log endpoint
**When** it is called
**Then** it serves the file in bounded pages, and no request can ever load the whole file.

**Given** any request to it
**When** it is parsed
**Then** it accepts **no filesystem path from the caller, at all** - the caller names the source from a fixed enum and the directory comes from `$System.Util.ManagerDirectory()` **resolved at call time and never cached**, because the manager directory is operator-settable through the console configuration.

**Given** the instance rotates messages.log at its configured maximum size
**When** a paging viewer holds a byte offset across that rotation
**Then** the endpoint validates the offset against the file's current identity and restarts cleanly rather than serving from a stale position.

**Given** `LogSourcePort`
**When** it serves this source
**Then** it declares the resource it requires - the same one the classic portal's log pages require - and evaluates it with `$System.Security.Check` before any file access, because unlike `AdminPort` it inherits no vendor gate
**And** a log line reaches a user through OcuPilot only if that user could have read it directly.

**Given** anything OcuPilot itself writes to messages.log
**When** it is written
**Then** it carries no credential material, because OcuPilot will later display this file and hand it to a read tool - and a test asserts that a forced provider failure leaves no credential in the log.

### Story 2.12: The application error log endpoint and drill-down

As a developer-administrator,
I want to drill from namespaces to dates to the errors an application actually threw,
So that I can read a fault in context - and so the Logs area has a screen its confirmed agent write can be scoped from.

**Acceptance Criteria:**

**Given** the application error log
**When** it is read
**Then** it goes through `SYS.ApplicationError` in `%SYS` - the supported API, using its `NamespaceList`, `DateList`, `ErrorList` and `ErrorDetail` queries - and OcuPilot writes **no `^ERRORS` traversal of its own**
**And** it is not `%CSP.ErrorLog`, which is the default CSP error page rather than a store.

**Given** `SYS.ApplicationError` does not exist in `HSCUSTOM`
**When** `LogSourcePort` calls it
**Then** the port switches to `%SYS` **once**, by explicit save and restore with the restore as the first line of every `Catch`, never into the target namespace
**And** the target namespace travels as a **parameter** on every call, and no slice writes `Set $NAMESPACE` for this path.

**Given** the drill-down screen
**When** the user navigates it
**Then** namespaces open to dates and dates to errors, each level a table, each error showing its text and time and, where the instance records them, routine and line
**And** each level's empty state names its scope.

**Given** the namespace an error read or delete acts on
**When** it is resolved
**Then** it comes from **one source only** - the level the user has drilled to, carried in the screen's descriptor state - and the route's `?ns=` parameter does **not** reach this port, because two sources would let a fully compliant delete purge a namespace other than the one on screen with a matching fingerprint and a correct-looking audit marker.

**Given** an error's captured detail holds every local variable at every stack level plus `$ROLES` and `$USERNAME` for whichever application faulted
**When** the user opens it
**Then** the full variable table renders on screen for them
**And** it is **secret by default**: it never enters screen context and is never sent to the model, because there is no template to classify it against - the read tool returns summary fields only (time, error number, routine, line, error text)
**And** on an IRIS for Health instance those tables can hold patient data, which is why this rule is absolute rather than advisory.

**Given** `^ERRORS` is unmapped and lives in each namespace's own globals database
**When** the gate is evaluated
**Then** the required permission is resolved **per namespace** - `%Admin_Operate` plus read and write on the database holding the selected namespace's global - because a single static descriptor resource cannot express it.

---

## Epic 3: Configure the agent, and hold the switches that restrain it

An OcuPilot administrator picks a provider, pastes a key, proves it works before enabling it, and from then on holds two switches that restrain or silence the agent instance-wide without any screen losing function - while a user with no agent configured still gets every screen and a panel that shows them what a proposal would look like. First half of build step 2, and a prerequisite for every turn.

### Story 3.1: Agent definitions, and the rules that keep them honest

As an OcuPilot administrator,
I want to create and manage named agent configurations on the instance,
So that every user works against one deliberate, reviewed choice of model rather than their own.

**Acceptance Criteria:**

**Given** a definition
**When** it is created or edited
**Then** it holds name, provider, model, endpoint URL where the provider needs one, credential type and reference, maximum tokens, temperature, maximum iterations per turn, an optional system prompt override, a read-only flag, a transcript retention period and an enabled flag
**And** it carries **no `ApiKey` property at all** - that absence is the schema invariant, harvested deliberately from iris-session-agent.

**Given** the eleven server-side validation rules and the XOR credential invariant harvested from iris-session-agent's configuration form
**When** a save is attempted
**Then** all of them are enforced on the instance, and every violation in one submission is accumulated and returned in a single round trip rather than one at a time.

**Given** the user changes provider
**When** the form reacts
**Then** that provider's canonical defaults cascade into the fields, preserving any value the user has customised.

**Given** a definition's provider, endpoint or credential changes
**When** the change is saved
**Then** the definition is **disabled** until Test connection passes again.

**Given** definitions exist
**When** users view them
**Then** every user can see them for selection while only OcuPilot administrators can edit them, and exactly one is marked default - the panel using the default in Release 1, with a picker deferred to Stage 3.

**Given** OcuPilot's state lifecycle
**When** a definition references something that has since been deleted
**Then** the reference is **weak** - recorded as scoped identity data, never a foreign key - and renders as "no longer present" rather than failing the screen.

### Story 3.2: The provider contract and the Anthropic adapter

As an OcuPilot administrator,
I want the agent to run on Anthropic today and on other families later without the rest of OcuPilot changing,
So that adding a provider is adapter work rather than a rewrite.

**Acceptance Criteria:**

**Given** the provider layer
**When** it is built
**Then** it is one provider base with adapters behind a single contract, Anthropic's message shape being canonical, so adding a family means adding an adapter and a form entry with **no change to the agent loop, the tools or the screens**.

**Given** the harvested provider base and Anthropic adapter
**When** they are ported
**Then** they keep the never-throw discipline and the `Invoke()` template, and **gain** the configurable SSL and proxy support the original hardcodes or lacks.

**Given** `ProviderPort` makes an outbound call
**When** TLS is established
**Then** it uses a **named SSL configuration the installer creates if it is absent**, with server-identity checking on - never hardcoded to whatever the harvested code used, and never left to whatever `DefaultSSL` means on the operator's instance
**And** proxy settings are configuration, not code.

**Given** a definition's endpoint
**When** it is written
**Then** writing it requires the OcuPilot administrative resource, it validates to an absolute HTTPS URL (or an explicitly declared local address for the OpenAI-compatible adapter), it **cannot name the instance itself or a loopback or link-local address** unless the definition is explicitly marked local, and the change is audited as a security change - because this field decides where the instance's data goes.

**Given** a provider call
**When** it fails
**Then** it retries only on a retryable status, with the delay the greater of the provider's own `Retry-After` hint and an exponential backoff, up to a bounded count
**And** **a call that threw mid-flight is never retried**, because the request may already have been processed
**And** every call carries a bounded timeout, and a failure surfaces as a turn error rather than as an exception to the client.

**Given** a credential is in play
**When** anything is logged, raised or returned
**Then** the key never enters an exception, a status, a log line or a trap - it is fetched at the point of use, held in a variable cleared before return, and never interpolated into a URL, a message or an error
**And** a test asserts that a forced provider failure leaves no credential material in the application error log or messages.log, both of which OcuPilot itself displays.

### Story 3.3: Credentials resolve at call time and are never stored where OcuPilot can show them

As an operator in a regulated shop,
I want OcuPilot to hold no API key it could ever display back,
So that adopting it does not create a new place secrets live.

**Acceptance Criteria:**

**Given** a definition
**When** it stores credential information
**Then** it stores only the credential **type** and the variable or credential **name** - never the value.

**Given** a key entered through the form
**When** it is saved
**Then** it is written once to the chosen credential store and is returned by **no** OcuPilot API call, ever.

**Given** the credential ladder harvested from iris-session-agent
**When** it resolves a key at call time
**Then** the environment-variable rung works in any namespace
**And** the IRIS-credentials rung is offered **only** where the install namespace is interoperability-enabled, because `Ens.Config.Credentials` requires it and plain IRIS Community may not have it
**And** the ladder never returns a value into a status or an error.

**Given** a key is pasted into the form
**When** it loses focus
**Then** a per-provider shape check flags an obvious paste error inline, before any call is made, with `aria-invalid` and the message wired through `aria-describedby`.

**Given** the key field
**When** it renders after a save
**Then** it is empty and captioned "Stored. Enter a new value to replace it.", never pre-filled and never echoing a stored value, with a labelled reveal toggle and pastes accepted without trimming.

### Story 3.4: Test connection

As an OcuPilot administrator,
I want to prove a definition works before I enable it,
So that a bad key surfaces at setup rather than in the middle of a demo.

**Acceptance Criteria:**

**Given** an edited definition, before save
**When** Test connection is pressed
**Then** it makes **one** minimal provider call with a small token budget using the definition **as edited**, and exercises the same path a real turn does - so a TLS misconfiguration surfaces here.

**Given** the call succeeds
**When** the result renders
**Then** it reads "Connected. Reply: <the model's first words>" as a polite status, truncated to a bounded length, within ten seconds on a current cloud model.

**Given** the call fails
**When** the result renders
**Then** it reads "The provider refused the request. Check the key and try again. Provider said: <text>", carrying the provider's own error text rather than its raw JSON body
**And** the definition stays disabled, and Save still works, reporting "Saved - disabled until Test connection passes."

**Given** an endpoint in the link-local metadata range
**When** it is tested
**Then** it is refused
**And** loopback and private-network hosts are **allowed**, because local models are a supported case.

**Given** the button is pressed
**When** the request is in flight
**Then** it shows an inline progress indicator and is `aria-disabled` for the duration, with focus staying on it.

### Story 3.5: The Definition form

As an OcuPilot administrator,
I want to configure the agent on one screen that puts the decisions I actually have to make first,
So that setup is a minute's work rather than a form-filling exercise.

**Acceptance Criteria:**

**Given** the Definition form
**When** it renders
**Then** name, provider, model, endpoint, the key field and Test connection sit above the fold, and maximum tokens, temperature, maximum iterations, the system-prompt override and retention collapse under "Advanced", closed by default.

**Given** the form is a full-page route
**When** it renders
**Then** it follows the `form-page` contract: a single column, a sticky Save/Cancel bar, inline validation on blur and on Save, an error summary banner that receives focus on a failed Save with a link per field, and `aria-invalid` plus `aria-describedby` on each invalid field with the first one focused
**And** navigating away with unsaved changes asks first - **and agent navigation waits for the same answer**.

**Given** Save succeeds on a create
**When** it completes
**Then** the new definition's editor opens; on an edit, the editor stays open and the sticky bar shows "Saved"
**And** on the **first** successful definition save the sticky bar also offers "Go to Home".

**Given** the Definitions list
**When** it renders
**Then** it shows name, provider, model, enabled and default, with enable, disable and set-default acting on the row in place.

**Given** a user who is not an OcuPilot administrator
**When** they look for Definitions
**Then** the side-bar entry is gated naming the OcuPilot administrative resource
**And** the Agent co-pilot rail-item itself **never** gates - its attention dot is the signal.

### Story 3.6: The first-login gate and the configuration-empty state

As a developer-administrator installing OcuPilot for the first time,
I want to be taken straight to the one thing that must be configured,
So that I reach a working agent without reading documentation to find out what is missing.

**Acceptance Criteria:**

**Given** no definition is enabled and the signing-in user holds the OcuPilot administrative resource
**When** they sign in
**Then** they are redirected to the Definition form under the banner "OcuPilot needs one agent definition before the panel can help. Anthropic is selected - paste a key and press Test connection. You can skip this and browse."
**And** the gate fires on **every** login until one definition is enabled, and never afterwards.

**Given** the administrator leaves the gate without enabling one
**When** they use any screen
**Then** every screen works, and the panel carries the persistent, non-dismissible banner "No agent definition is enabled. Configure one in Agent co-pilot > Definitions." until the condition clears.

**Given** no definition is enabled and the user is **not** an OcuPilot administrator
**When** they open any screen
**Then** every screen works and the panel shows "The agent isn't configured yet. An OcuPilot administrator can enable a definition in Agent co-pilot > Definitions."
**And** beneath it a **static example proposal card** labelled "Example - this is what a proposal looks like" renders with the same bar, header, two changed diff rows, collapsed unchanged disclosure, agent text and Reverse line as a live card - no countdown, no buttons, nothing focusable, and the live colours kept so the example teaches the real card
**And** beneath that, three sentences: it reads with your privileges; it proposes and you confirm; every write is marked in the audit database.

**Given** the panel is in either empty state
**When** the composer renders
**Then** it stays focusable and `aria-disabled` with that reason - never natively disabled - and the context chip is **absent**, because there is no provider or endpoint to name.

**Given** the unconfigured state
**When** it is compared to the kill switch
**Then** they are distinct: unconfigured is not a switch an administrator has to clear, and the kill switch is off by default.

**Given** the agent is unconfigured
**When** the rail renders
**Then** the attention dot shows on the Agent co-pilot item in `agent-accent-dark` with a `shell` ring, naming its reason in its accessible name, and clears the moment a definition is enabled.

### Story 3.7: Switches - the kill switch and enforced read-only

As a production administrator,
I want to restrain or silence the agent for the whole instance without any screen losing function,
So that I can adopt OcuPilot on a change-controlled system on my own terms.

**Acceptance Criteria:**

**Given** the Switches screen
**When** an OcuPilot administrator opens it
**Then** it offers the kill switch (global, and per user), enforced read-only mode, the instance default for context sharing, and - from build step 7 - the per-user turn limits
**And** it is reached from the Agent co-pilot rail item and **does not depend on the agent to work**, which is what makes both switches reachable when the agent is off.

**Given** enforced read-only is on
**When** any user opens the panel
**Then** it carries the banner "Read-only mode is enforced on this instance. The agent can read and explain, not change." and the footer status line reads "Read-only: on - enforced on this instance"
**And** the footer's read-only status line is **always** present, in both states, so the mode is learnable.

**Given** the kill switch is on, globally or for that user
**When** they open the panel
**Then** it enters its disabled state with the banner "The agent is switched off for <everyone / you>: <reason>.", the transcript becomes read-only, the composer and Send stay **focusable and `aria-disabled`** with the reason, and the attention dot lights
**And** every screen keeps working.

**Given** either switch changes
**When** the change takes effect
**Then** it is instance state in the protected database, evaluated **on the instance at the point of effect** rather than only in the client, and never cached for the length of a turn
**And** an in-flight turn stops at its next step boundary, and a pending proposal can no longer be confirmed.

**Given** the kill switch's default
**When** a fresh install completes
**Then** it is **off** - the agent's initial silence comes from having no enabled definition, not from a switch someone must find and clear.

**Given** a definition carries its own read-only flag
**When** that definition is in use
**Then** it has the same effect as read-only mode while it is in use, and the footer line reads "Read-only: on - by the definition".

### Story 3.8: Every configuration change is resource-gated and audited

As a security-minded operator,
I want every change to what the agent is and what restrains it to be attributable,
So that the governance surface is itself governed.

**Acceptance Criteria:**

**Given** any OcuPilot configuration endpoint
**When** it is called
**Then** it checks the OcuPilot administrative resource **server-side**, not only in the client.

**Given** a change to a definition, the kill switch, enforced read-only, the context-sharing default or the turn limits
**When** it is saved
**Then** an OcuPilot audit event is emitted naming the actor, the target, and the **old and new values**, with a definition's endpoint change recorded as old endpoint and new endpoint specifically.

**Given** OcuPilot's audit event types
**When** the installer registered them with `Security.Events.Create()`
**Then** these events actually land - because without registration `$System.Security.Audit()` silently returns 0 and drops the event, with no error and no log entry.

**Given** the OcuPilot API web application
**When** it is inspected
**Then** it carries **no application roles and no matching roles**, and the installer asserts this
**And** it carries a resource gate, and the turn endpoint refuses a user holding no `%Admin_*` resource with the FR-3 message.

**Given** a user holding rights on the install namespace's database but not the OcuPilot administrative resource
**When** they attempt to read or write definitions, switches, the ledger, transcripts or proposals through SQL or direct global access
**Then** every attempt is refused, as Story 1.3's test already proves - and this story adds the endpoint-level half: every configuration read and write is refused at the API too.

---

## Epic 4: Ask the agent about the screen you are on

A user on any screen types a question into a panel that already knows where they are, watches the agent read through the same endpoints the screen reads from, and gets an answer that names the rows it used - with every call recorded in a ledger and nothing on the instance changed. Second half of build step 2; delivers UJ-1 and the read-only half of UJ-4 complete.

### Story 4.1: The turn runs in a background job and returns immediately

As a developer-administrator,
I want my browser to stay responsive while the agent works,
So that a ninety-second turn never looks like a hung page and never needs an operator to change a gateway setting first.

**Acceptance Criteria:**

**Given** the user sends a message
**When** `POST /api/ocupilot/turn` is handled
**Then** it starts a background job and **returns a turn id immediately** - no request is held open for the length of a turn.

**Given** the job starts
**When** it runs
**Then** it inherits `$USERNAME` and `$ROLES` from the request process and therefore reads as the user
**And** it **never mutates** - it proposes, and the write happens in a separate confirm request.

**Given** a turn that runs longer than the stock 60-second Web Gateway response timeout
**When** it completes
**Then** it completes normally on an unmodified container, and a test proves it - which is what replaces the old "raise the gateway timeout" install prerequisite.

**Given** the job holds the `$USERNAME` and `$ROLES` copy it inherited at spawn, for its whole life
**When** it moves between steps
**Then** it re-checks that the user is still enabled and still holds the privilege each remaining step needs, and abandons the turn otherwise
**And** it re-reads enforced read-only, the kill switch and its stop flag **between every step**, abandoning at the next boundary when any has changed.

**Given** a turn
**When** it runs
**Then** it is bounded by a maximum iteration count, a maximum wall-clock duration and a maximum total provider token spend, so no job can outlive its session indefinitely
**And** a user has a bounded number of concurrent turns - one in Release 1, **enforced on the instance** rather than only by the panel's lock.

**Given** the user signs out
**When** the session ends
**Then** their running turns are abandoned.

**Given** the job is started from a process that may hold OcuPilot's escalated role
**When** it is spawned
**Then** the spawn happens **before** any escalated read, or from a frame that has already unwound, because a `JOB` inherits `$ROLES` at the moment of the spawn and keeps it for the child's entire life
**And** every piece of state the turn needs was read first and passed in as values.

**Given** progress records
**When** they are written and polled
**Then** they live in OcuPilot's protected storage keyed by turn and owned by the user who started it, are capped in size per turn, and die with the turn
**And** a poll for a turn the caller does not own returns **404, not 403**.

### Story 4.2: The tool registry, its one gate point, and the three shell reads

As a developer-administrator,
I want the agent to be able to read everything my screens can read, through the same endpoints,
So that its answers cannot describe an instance that differs from the one in front of me.

**Acceptance Criteria:**

**Given** the tools registered from screen descriptors in Epic 2
**When** the registry loads
**Then** they become dispatchable, discovered by reflection over the tool base with each declaring its name, input schema and result shape.

**Given** the three shell reads - the privilege map, the namespace list and instance identity
**When** the tool set is assembled
**Then** each has a read tool, alongside the per-screen tools.

**Given** any tool call
**When** it is dispatched
**Then** it passes through **one** call-time gate point, evaluated after the caller's identity is resolved and **before any port is touched**, which in Release 1 returns "allowed" for everything not prohibited
**And** that single point is what a later governance policy attaches to without rework.

**Given** a tool executes
**When** it reaches the instance
**Then** it runs **in-process** in the calling process and calls the management surface directly - **no tool issues an HTTP request** to `/api/admin`, `/api/mgmnt` or `/api/ocupilot`
**And** because the process already carries the user's `$USERNAME` and `$ROLES`, "runs as the user" is a property of the process rather than something a token asserts, so no token is needed mid-turn.

**Given** a tool result
**When** it reaches the model
**Then** it arrives as **delimited tool-result content** and never as part of the system prompt, which is a build-time constant, and never as the user role
**And** nothing read at runtime is concatenated into the system prompt.

**Given** the cross-vendor JSON-Schema subset rule harvested from iris-session-agent
**When** tool schemas are emitted
**Then** the rule is kept verbatim, because it is what makes one tool array work across four provider families.

**Given** any SQL-backed read
**When** it executes
**Then** it binds every caller value as a parameter, uses only fixed catalog queries, and runs no free-form SQL in Release 1
**And** it carries the anti-runaway-query guard harvested from the sibling's bounded where-clause builder.

### Story 4.3: The docked panel, present on every route

As a developer-administrator,
I want the agent always there, beside whatever I am looking at,
So that asking about a screen never means leaving it.

**Acceptance Criteria:**

**Given** any route
**When** it renders
**Then** the panel is docked to the right at its remembered width, defaulting to 400px and never below 320px, with the screen content reflowing to the remaining width
**And** it has **no close control in Release 1**.

**Given** the user navigates
**When** the route changes
**Then** the panel and its conversation persist - navigation never dismisses it.

**Given** the panel's left edge
**When** the user drags it
**Then** it resizes between the minimum and the point where content reaches its 640px minimum, with a `col-resize` cursor and a grip that turns `restrained` at the stop, and the width persists per browser
**And** it is the **only** resizable edge in the shell - the side bar has no sash, grip or resize cursor
**And** the handle is `role="separator"`, `aria-orientation="vertical"`, focusable, with `aria-valuenow/min/max` in px, Left and Right arrows changing width by 16px, Escape releasing, and the new width announced through the value.

**Given** the full-screen toggle
**When** it is pressed
**Then** the panel fills the app area below the header, the hidden content becomes `inert`, `aria-expanded` reflects the state, and the same control restores it with the width unchanged.

**Given** the panel body
**When** it renders
**Then** banners appear in fixed order - kill switch, enforced read-only, "not being marked", administrator reminder, lock - then the context chip, then the transcript as `role="log"` (polite, labelled "Conversation", `tabindex="0"`, newest at the bottom, scrolling independently), then the footer
**And** the footer holds the always-present read-only status line, the composer labelled "Message to the agent" growing to four lines, the Send control, and the caption "Enter to send - Shift+Enter for a new line - Ctrl+I to focus".

**Given** the viewport narrows
**When** rail, side bar, content minimum and panel no longer fit
**Then** the yield order runs - the side bar auto-collapses, then the panel shrinks toward its minimum, then content scrolls horizontally inside its own region
**And** the panel **never** auto-collapses, never becomes an overlay or a bottom sheet, and the page body never scrolls horizontally.

**Given** Ctrl/Cmd+I is pressed anywhere
**When** no dialog or command-box overlay is open
**Then** focus moves to the composer, **including during a turn**.

### Story 4.4: Screen context on every turn, capped, with its toggle and chip

As a developer-administrator,
I want the agent to know which screen I am on without me describing it, and to be able to switch that off,
So that "what am I looking at?" is a question I can just ask - and so I can stop sending anything when I need to.

**Acceptance Criteria:**

**Given** a turn is sent
**When** context is assembled
**Then** it is built **fresh from the screen the user is on at that moment** - so navigating between turns changes what the agent sees - and carries route, namespace, selected entity, and the visible rows with the active sort and filter.

**Given** a screen descriptor declares its context serializer
**When** the kernel serializes
**Then** it enforces an instance-wide cap of **200 rows**, operator-settable, **truncating rather than refusing** and recording the number actually sent
**And** the cap is on **content, not only rows**: the payload is bounded by total size as well, and each field is truncated to a declared maximum with the truncation marked
**And** a serializer that emits an uncapped collection or an unbounded field fails review.

**Given** any field the descriptor types as secret - a password, private key, secret value, API key or token
**When** context is assembled
**Then** it is excluded **unconditionally**, regardless of the toggle and regardless of the cap
**And** a screen carrying such fields sends route and entity identity only, never form values
**And** the exclusion is schema-driven from the descriptor, never a name-pattern match, because a wallet secret field named `Value` defeats any matcher - a name matcher runs only as a backstop that can add redaction and never remove it.

**Given** the context chip
**When** it renders with sharing on
**Then** it reads `<Screen>, <NAMESPACE> - <N rows> - <provider> - <endpoint host>`
**And** when the endpoint host is not on a private network it carries the pill "leaves the instance" with the tooltip "Screen context is sent to <host>", computed from the same configuration the request actually uses so the two cannot disagree
**And** a screen with secret-typed fields adds a key glyph.

**Given** the user turns sharing off
**When** subsequent turns are sent
**Then** no screen data is sent, and the chip reads "Screen context off - nothing from this screen is sent."
**And** the toggle defaults to on, is remembered per user, and an OcuPilot administrator can set the instance default to off.

**Given** the chip is live
**When** the route, namespace, selection or visible rows change
**Then** it updates.

**Given** the user is on a screen carrying secret-typed fields
**When** their draft looks like a password or key
**Then** an inline warning appears above the input - "This looks like a password or key. Send anyway?" - with Send anyway and Edit.

### Story 4.5: A turn, watched: progress cards and the conversation lock

As a developer-administrator,
I want to see what the agent is doing while it works,
So that a slow answer is legible as work rather than as a hang.

**Acceptance Criteria:**

**Given** a message is sent
**When** the turn begins
**Then** the user's message is appended, Send becomes **Stop** and keeps focus, the composer stays focusable and editable, and the first tool-call card appears **within ten seconds**.

**Given** each tool call
**When** it runs
**Then** a card appears in order as an expandable disclosure - the running card expanded, completed cards collapsing to one line - with the tool name and target in `code` and the status at the right
**And** the status is part of the card's accessible name and updates in place
**And** the transcript's `role="log"` means each card and the final reply are announced by construction.

**Given** a card is expanded
**When** it renders its body
**Then** it shows the arguments summary and the result on the code surface, at most twelve lines before scrolling inside itself, and for a read it shows the rows returned and the number of context rows actually sent.

**Given** a turn is already running on this conversation
**When** the user presses Enter or Send again
**Then** the message is refused with the visible lock banner "A turn is in progress. Wait for it to finish before sending another message.", the typed text is kept in the composer, and focus does not move
**And** the refused message is not rendered in the transcript
**And** the lock is enforced on the instance by the per-conversation exclusive-lock protocol harvested from the sibling, with both branches returning an identically-locked reference and release guaranteed on every exit path - the panel's banner being the affordance, not the enforcement.

**Given** the user presses Stop
**When** the turn reaches its next step
**Then** it halts, the card it halted on reads "Stopped by you at <step>" with no body and no expansion, no reply follows, and Send returns with focus still on it
**And** **Stop is not a new turn** and cancels nothing.

**Given** the panel is opened or the page is reloaded
**When** the transcript loads
**Then** the tab's current conversation and its prior turns are restored, with **no running cards**
**And** a new tab starts a new conversation.

**Given** New conversation is pressed
**When** it resolves
**Then** the transcript clears to a fresh conversation on the instance, the earlier one staying in the stored transcript with no way to reopen it in Release 1, and the context chip is unchanged
**And** while a turn runs the control is `aria-disabled` with the reason "Stop the turn first".

**Given** anything in a progress record that came from the model or a tool result
**When** the panel renders it
**Then** it is rendered as **data, never as markup and never as OcuPilot's own voice**, and no rendered progress causes a request to any host.

### Story 4.6: Replies render safely and offline

As a security-minded operator,
I want a model's reply to be incapable of reaching out of my instance,
So that a compromised or manipulated model cannot use the panel as a channel.

**Acceptance Criteria:**

**Given** a reply
**When** it renders
**Then** it renders as sanitized Markdown with code highlighting, script and unsafe HTML stripped before rendering.

**Given** the rendering pipeline
**When** the page loads
**Then** the renderer, highlighter and sanitizer are **vendored inside the bundle** and the page loads with no CDN reachable.

**Given** a reply containing a remote image
**When** it renders
**Then** **no network request is produced**, and a test asserts it
**And** images render only from same-origin or inline sources.

**Given** a reply containing an external link
**When** it renders
**Then** the link is inert with the full host visible in caption text after the link text, and opens only on an explicit click.

**Given** the shell's Content-Security-Policy
**When** any resource is requested
**Then** it forbids every connection except to the instance's own origin.

**Given** the agent cites rows it used
**When** the reply renders in Release 1
**Then** it names them in plain text set in `code` and offers to select them, the click-through citation chips arriving in Epic 11.

**Given** a turn ends in an error
**When** it renders
**Then** it renders as an error banner in the agent's slot reading "The turn stopped at <step>: <reason>."
**And** a turn the user **stopped** is not an error and takes the tool-call card's stopped status instead.

### Story 4.7: The agent takes you to a screen

As a developer-administrator,
I want the agent to open the screen it is talking about,
So that following its answer does not mean hunting through a menu.

**Acceptance Criteria:**

**Given** a navigation tool
**When** it is called
**Then** it accepts **only allow-listed route identifiers from the descriptor registry and entity ids - never a URL**.

**Given** the agent is about to navigate
**When** it acts
**Then** it first commits the announcement "I'm opening <screen> for <entity> - use Back to return." to the log, and the route changes about a second later, after the announcement has been dispatched
**And** the new screen's heading takes focus and announces "<title> - opened by the agent; Back returns".

**Given** navigation moves the user, and therefore changes which screen's context is sent next turn
**When** the agent initiates it
**Then** it is **announced before it happens** and never silently changes the context the next turn carries - navigation is a proposal of a route, not an action.

**Given** the user did not want to move
**When** they press the browser Back button
**Then** they return to the previous screen with its selection intact - agent navigation is an ordinary history entry, and there is no in-app undo control.

**Given** the navigation would leave a form with unsaved changes
**When** it is attempted
**Then** the unsaved-changes guard asks first, exactly as it would for a user-initiated navigation.

**Given** navigation tools
**When** they are listed to the model
**Then** they appear in the tool set as read tools and run client-side.

### Story 4.8: A slow or rate-limited provider degrades the turn rather than failing it

As a developer-administrator on a busy account,
I want a rate limit or a slow model to cost me time rather than the answer,
So that transient provider trouble is not indistinguishable from a broken product.

**Acceptance Criteria:**

**Given** a provider returns 429 or a 5xx
**When** the call is retried
**Then** it backs off exponentially up to a bounded count, honouring `Retry-After` where the provider sends one, using the greater of the two delays.

**Given** a call threw mid-flight
**When** the retry decision is made
**Then** it is **not** retried, because the request may already have been processed.

**Given** a provider call exceeds its fixed timeout
**When** the turn resolves
**Then** the turn ends with an error card naming **which step** timed out - never a silent stop.

**Given** any provider failure
**When** it surfaces
**Then** it appears as a turn error, never as an exception reaching the client.

**Given** the installer reports the Web Gateway response timeout
**When** an operator reads that report
**Then** it is information, not a prerequisite - because the background-job turn holds no request open, the stock 60 seconds suffices, and a clean clone works unmodified.

### Story 4.9: The agent audit ledger

As a security-minded operator,
I want every model call and every tool call recorded on the instance,
So that what the agent did is recoverable afterwards without correlating across systems by hand.

**Acceptance Criteria:**

**Given** any LLM call or tool call
**When** it completes
**Then** a ledger row records the user, the timestamp in ISO-8601 UTC, the screen context route, the tool or provider name, the arguments, the result status, and token usage where the provider reports it.

**Given** a tool call
**When** its row is written
**Then** it also records **the IRIS resource the tool required**, because the polish-week transcript access rule depends on it.

**Given** any secret, credential or token
**When** a row is written
**Then** it is redacted **by schema** - every tool schema marks its secret fields and the writer drops them by declaration, not by pattern - and LLM-call arguments are stored after the same secret exclusion screen context applies
**And** a name-pattern matcher runs only as a backstop that can add redaction, never remove it.

**Given** the ledger is written on the agent's own path
**When** a turn is unusually chatty
**Then** the ledger is bounded by a maximum rate and size per turn, with overflow recorded as a **count** rather than as unbounded rows.

**Given** OcuPilot's audit event types
**When** the instance emits one
**Then** they were registered in `%SYS` at install, so events are not silently dropped.

**Given** a user views ledger rows
**When** the view resolves
**Then** they see their own; an OcuPilot administrator's view of another user's rows is gated by the resources recorded **on the row itself**, and that gate lives with the ledger rather than with any screen.

**Given** OcuPilot's state lifecycle
**When** a user referenced by ledger rows is deleted
**Then** the rows survive - the ledger is an audit record and outlives its subject - while that user's sessions are invalidated and their running turns abandoned.

### Story 4.10: Home's suggested view and the starter prompts

As a developer-administrator arriving in the morning,
I want Home to tell me what needs attention and offer me something to ask,
So that the agent is useful before I have thought of a question.

**Acceptance Criteria:**

**Given** Home with an enabled definition
**When** the panel renders
**Then** a "Suggested view" block sits above the transcript with attention lines - tasks suspended after an error, application errors today per namespace, new alerts.log entries, and agent status (definition, read-only, kill switch) - each a 32px row with its count in `code`
**And** each line's text is a button **distinct from** its "Open >" link, and activating the line places its text in the composer as a prompt for the user to send.

**Given** every attention line would read zero, as on a fresh container
**When** the block renders
**Then** it shows the three starter prompts instead of zeros, with the same gesture, and the agent-status line stays.

**Given** the transcript is empty on a first turn
**When** the panel renders
**Then** it shows "I'm ready. Ask about this screen, or try one of these." over the screen's three starter prompts, and beneath them the hint "Click a row to select it; click its name to open it." so the selection model is learnable without the README.

**Given** the panel widens on Home
**When** the width changes
**Then** it animates over 120ms, or not at all under reduced motion, and restores the remembered width on leaving Home.

---

## Epic 5: Propose, confirm, and find it in the audit database

A user asks the agent to change something, reviews a diff the instance computed from a fresh read, presses Confirm, watches the affected screen refresh and highlight what changed, and then finds that same change in the IRIS audit database marked as having come through the agent - in **each** of the six areas. This is the product's entire claim, and SM-3 and SM-4 are both met at its end.

### Story 5.1: The proposal is minted on the instance, from a fresh read

As a security-minded operator,
I want the thing I approve to be authored by my instance rather than by the model,
So that what I confirm cannot differ from what will run.

**Acceptance Criteria:**

**Given** the agent calls a write tool
**When** the proposal is created
**Then** the **instance** mints it, holding a server-issued unguessable id, the user, the conversation, the tool name, the full resolved argument set, the scoped target identity, a fingerprint of the target as **freshly read at proposal time**, the computed diff, and a single-use token
**And** **the client never authors a proposal**.

**Given** the target identity
**When** it is stored
**Then** it is the triple `(entity type, scope, id)` - scope being the namespace for a namespace-scoped object and the literal `instance` for a configuration object - so a confirm can never re-read the wrong `Nightly purge`.

**Given** the fingerprint
**When** it is computed
**Then** it covers the **complete property set the write will send**, excluding only the fields the endpoint itself mutates as a side effect - a task's next-scheduled time, a last-modified stamp - with those exclusions declared in the descriptor and the default being "everything else"
**And** a slice does not choose its own fingerprint fields.

**Given** the tool's declared secret fields
**When** the proposal is stored
**Then** those values are **never** in the stored arguments and were never accepted from the model.

**Given** a proposal
**When** ten minutes pass
**Then** it expires, that interval being a server-side constant.

**Given** a write tool call arriving without a valid, unexpired, unburned proposal token
**When** it reaches the write path
**Then** the **write path itself** refuses it - not the caller.

**Given** the payload OcuPilot will send
**When** it is assembled
**Then** OcuPilot **computes the merge itself**: read fresh, apply the diff, send the complete property set - because get-merge-put is not a property of the admin API and 28 of 47 vendor `RunPut` implementations do not merge, so sending only changed fields to one of those erases every field omitted
**And** the diff is what the user reviews while the payload is the whole object.

**Given** a proposal exists
**When** it is published
**Then** a proposal-open event for its scoped entity type goes onto the change-event bus, and a proposal-closed event follows on confirm, cancel or expiry - which is the channel the auto-refresh pause rides on.

**Given** the turn that minted a proposal dies
**When** confirmation is attempted
**Then** it is refused - proposals are bound to their turn's lifetime as well as their own expiry.

### Story 5.2: The proposal card - the diff the user reviews

As a developer-administrator,
I want to see exactly what will change, in the instance's own words, before anything happens,
So that confirming is a judgement rather than a leap of faith.

**Acceptance Criteria:**

**Given** a proposal
**When** its card renders
**Then** it shows the target, the changed fields as diff rows computed **on the instance from the fresh read**, the unchanged fields the payload still sends collapsed under "N unchanged fields" with every field still available, the agent's rationale and expected impact **labelled as the agent's text** on the agent tint, and "Reverse: <how to undo>" where a reversal exists
**And** the countdown reads "Expires in m:ss" from 10:00, turning `warning` at 1:00 and staying so to 0:00
**And** the footer carries "Runs as <user name>, with your privileges." and "Confirm here; sending a message cancels this proposal".

**Given** a delete proposal
**When** its diff renders
**Then** it has no after-state: the target's identifying fields render as `field - value -> (removed)`, read aloud as "<field>: <value>, removed", and the card carries **no Reverse line**, because a delete has no reversal.

**Given** the payload includes a secret field
**When** the card renders
**Then** a masked field appears for the user to fill at confirmation, required before Confirm, and the diff shows bullets on **both** sides - the value having never been accepted from the model.

**Given** the proposal would disable auditing
**When** the card renders
**Then** it carries the warning "Agent writes will no longer be marked in the audit database." inside the card - the agent never proposes disabling auditing or OcuPilot's own audit events without it.

**Given** several proposals in one turn
**When** they render
**Then** they stack in order, each with its own Confirm and Cancel, and there is **no "Confirm all"**.

**Given** a card is live
**When** the panel renders
**Then** Send drops to a secondary button so Confirm is the view's only filled button, and the accompanying agent message ends "Press Confirm on the card to apply it."

**Given** the user types a message instead of pressing Confirm
**When** it sends
**Then** every live proposal is cancelled with the status line "Canceled - by your message", and the agent's next reply **says the proposal was cancelled and offers to re-propose** rather than answering as though the write had happened
**And** New conversation cancels live proposals the same way, while **Stop cancels nothing**.

**Given** the countdown reaches 0:00, or the transcript is restored from a reload
**When** the card renders
**Then** it takes the restrained treatment - by **role, never by opacity**, because the diff must stay readable at AA - its buttons are replaced by the status line "Expired" which receives focus if a button held it, and **Re-propose** offers a fresh turn with a fresh read and a fresh diff
**And** a restored card is **always** shown expired, never live.

**Given** any terminal transition - confirmed, cancelled, expired, target changed, kill switch
**When** the buttons go away
**Then** they are `aria-disabled` for the transition rather than removed while focused, and the status line that replaces them receives focus and is announced.

**Given** the countdown
**When** it runs
**Then** it is announced to assistive technology **once, at 1:00** - "One minute left to confirm" - and never per second.

### Story 5.3: Confirm is a user-originated request, and the write is one atomic transition

As a security-minded operator,
I want the agent to be structurally incapable of approving its own proposal,
So that "one explicit confirmation per write" is a property of the system rather than a promise.

**Acceptance Criteria:**

**Given** the confirm path
**When** it is inspected
**Then** it is **not a tool and is not in the tool registry**, and it refuses any call whose originating context is a turn - the kernel carrying an explicit "acting on behalf of the model" marker through the turn job and every tool call, which confirm rejects when set
**And** this barrier is explicit precisely because in-process execution removed the HTTP boundary that used to provide it accidentally.

**Given** the browser confirms
**When** the request is sent
**Then** it is a **separate authenticated request** carrying the proposal id, and the executor uses the **stored** arguments, never client-supplied ones.

**Given** the confirm channel
**When** any key is supplied
**Then** the only keys accepted are the fields the descriptor declared secret-typed for that tool; **any other key is rejected outright, not ignored**, and the identifying key is never accepted from the client
**And** so the executed write can never diverge from the audited diff.

**Given** confirm executes
**When** it re-checks
**Then** it re-evaluates the user's privileges, enforced read-only, the per-user read-only state, the definition's read-only flag and the kill switch, and re-reads the target to compare the fingerprint
**And** a proposal minted while the user held a privilege they have since lost is refused
**And** a fingerprint mismatch refuses the write with "target changed, re-propose" and offers Re-propose
**And** a proposal is confirmable **only by the user who minted it**.

**Given** two confirms of the same proposal race
**When** they arrive
**Then** burning the token and committing to the write are **one atomic transition** under a lock or conditional update exactly one caller can win, and the loser is refused with the proposal's terminal state rather than retried.

**Given** one proposal is confirmed
**When** the transition commits
**Then** sibling proposals on the same scoped target are cancelled **in the same transition**, showing "Canceled - a sibling proposal was confirmed" - so that state is a consequence of the mechanism rather than a second, racing step.

**Given** every gate that decides whether a write may happen - the prohibited set, read-only, the kill switch, later governance
**When** it is evaluated
**Then** it is evaluated **at the write, inside the atomic transition**, never at the tool call that produced the proposal, because a check performed when the proposal was minted is a check against state that has since moved.

**Given** Confirm is pressed
**When** the request is in flight
**Then** the button shows progress and is `aria-disabled` with focus kept; on success the buttons are replaced by the status line "Confirmed by <user name> - hh:mm:ss" which takes focus, and Send returns to a primary.

### Story 5.4: Execution strictly as the user

As a production administrator,
I want the agent to be unable to do anything I could not do myself,
So that adopting it does not widen anyone's access, including mine.

**Acceptance Criteria:**

**Given** any tool call
**When** it executes
**Then** it runs under the caller's own IRIS privileges, in-process, with **no service account and no credential other than the user's own**.

**Given** a tool the user lacks privilege for
**When** it is called
**Then** it fails with the **same 403 the screen would produce**, the tool-call card reads "failed - <resource>", and the agent reports the refusal rather than retrying with other credentials or another path.

**Given** the tool set advertised to the model
**When** it is assembled
**Then** it is the **full set** - privilege is checked at call time, never by hiding tools.

**Given** the one permitted escalation, which is OcuPilot's own protected storage
**When** any tool, port or provider code runs
**Then** it is **not in effect**, and no storage method calls a tool, a port, or code that could.

**Given** any token the instance holds on the user's behalf during a turn
**When** the turn ends
**Then** it lived in process memory only, was never written to the ledger or a transcript, and is discarded.

**Given** the log endpoints
**When** they are called
**Then** they require the same resource the classic portal's log pages require, and each port declares and evaluates its own gate before any call - because unlike `AdminPort` they inherit no vendor gate, and `/api/monitor/metrics` answers **anonymously** on this instance
**And** a metric, a log line or an audit row reaches a user through OcuPilot only if that user could have read it directly.

### Story 5.5: Prohibited actions are absent from the tool set

As a security-minded operator,
I want the things that must never happen to be impossible rather than switched off,
So that no policy change or configuration mistake can make them reachable.

**Acceptance Criteria:**

**Given** the Release 1 prohibited set
**When** it is defined
**Then** it lives in **exactly one home in the kernel**, as predicates evaluated against the **resolved target** - never duplicated into a screen, a descriptor or a policy file, and never expressed as a match on request fields, which a caller can vary.

**Given** a predicate reads live state - who the last `%All` holder is, which application serves OcuPilot
**When** it is evaluated
**Then** it runs inside the same atomic transition as the write, so the answer cannot change between the check and the effect.

**Given** the set is defined **by effect, not by verb**
**When** it is enumerated
**Then** it covers: deleting or disabling the current user, the last `%All` holder or `_SYSTEM`; **granting privilege through any path** - setting `MatchRoles` or `Roles` on any web application, adding a role to a resource, or adding `%All` or any `%Admin_*` role to any user or role; disabling the path that serves OcuPilot, meaning the web application, the **web service** behind it and the superserver; terminating IRIS system processes; and deleting OcuPilot's own web applications, resource, role or database.

**Given** granting `%All` as an application role on OcuPilot's own API is neither a delete nor a disable
**When** it is attempted
**Then** it is refused, because it would make every later request - including every turn job - run elevated, quietly falsifying "the agent never holds a privilege the user does not"
**And** privilege **grants** are prohibited in Release 1 and are not proposable at any confirmation level.

**Given** a prohibited action
**When** the tool set is advertised
**Then** it is **never advertised as a tool** and is refused on the instance whatever the caller
**And** governance can disable a permitted tool but can **never enable a prohibited one**.

**Given** a screen enforces a self-protection rule in its UI - refusing to disable the current user, act on the user's own process, or delete OcuPilot's own applications
**When** that rule is assessed
**Then** it is an affordance, **not a prohibition**: the instance refuses it on the write path regardless of what the UI does.

### Story 5.6: The agent marker, and what happens when it fails

As a developer-administrator,
I want to find an agent's change in the audit database and know it came through the agent,
So that I can prove what changed and how, from the instance's own record.

**Acceptance Criteria:**

**Given** a confirmed write
**When** it completes
**Then** OcuPilot emits an audit event carrying the agent marker, the proposal id, the tool, the target identity and the user, **alongside** the vendor's own change event for the same operation
**And** either record locates the other, so the pair is recoverable without hand-correlating across systems.

**Given** the same write made by hand through a screen
**When** the audit database is inspected
**Then** it emits **no** such marker event - the marker is what distinguishes agent from human.

**Given** the audit viewer
**When** the agent-marker filter is applied
**Then** the write appears under the user's own name with its description marked as coming through the OcuPilot agent co-pilot.

**Given** the marker fails to emit
**When** the write has already succeeded
**Then** **the write does not fail and the failure does not propagate** - the condition is recorded on the ledger row and shown on the tool-call card as "done - audit not marked" in `warning` on its **collapsed** line, never only in the body, and the reply mentions it
**And** the emission's return value is checked, because `$System.Security.Audit()` silently returns 0 and drops the event when the source, type and name triple was never registered.

**Given** auditing is off on the instance, or OcuPilot's own audit events are disabled
**When** any user opens the panel
**Then** the banner "Agent writes are not being marked. Auditing is off on this instance." shows, linking to Auditing configuration for every user and adding "Turn auditing on" for OcuPilot administrators
**And** the executor records the condition on each write.

**Given** the ledger row for a confirmed write
**When** it is finalized
**Then** it is created before the port call and **finalized after** it, recording what was **actually executed** - the resolved target, the fields actually sent, the privileges actually exercised - rather than what the proposal predicted
**And** secret-typed fields were excluded at write time rather than redacted afterwards.

**Given** the pairing metric
**When** it is measured across the voting week
**Then** no confirmed proposal exists without a matching marked event and no marked event without a confirmed proposal - the metric measuring the **pair**, which holds precisely because a failed marker is itself recorded and surfaced rather than silent.

### Story 5.7: The screen shows the change

As a developer-administrator,
I want the screen to show me what just changed, without me hunting for it,
So that a confirmed write ends in evidence rather than in a claim.

**Acceptance Criteria:**

**Given** a confirmed write
**When** it completes
**Then** it publishes the scoped triple `(entity type, scope, id)` plus an action on **one** client-side event bus
**And** a screen editor's own Save publishes to the same bus, so an open list updates after a form save exactly as it does after an agent write.

**Given** the entity-type vocabulary
**When** a descriptor selects from it
**Then** it comes from a **single closed enum owned by the kernel** and the build fails on an unknown value - which is what actually stops two slices naming the same thing differently.

**Given** the active screen shows that entity type
**When** the event arrives
**Then** it **re-fetches in place** - no screen mutates its own rows from a write response - preserving sort, filter, selection and scroll, and highlights the changed row or field **within two seconds** of the write completing, scrolling it into view
**And** the highlight takes the change-highlight background with a 3px agent bar and a "Changed" tag, settles over two seconds, and holds until the next interaction with that row or field.

**Given** the changed row was deleted
**When** the list re-fetches
**Then** the row leaves, and if it was selected the selection and the locator's entity segment clear
**And** a created row appears highlighted and selected.

**Given** the affected screen is **not** open
**When** the event arrives
**Then** a toast names the change in one sentence and carries "Open in <screen>", which navigates with the entity selected
**And** toasts stack at most three deep, newest on top, a fourth dropping the oldest; a toast without an action persists ten seconds and one carrying an action thirty; the timer **pauses while any toast is hovered or focused**; and every toast has a dismiss control
**And** the agent's reply names the same change, so nothing is lost when a toast expires.

**Given** toasts
**When** they are used
**Then** they are **never** used for errors, which are banners, and never to confirm what the user just did on the open screen, where the row highlight is the confirmation.

**Given** the bus
**When** a list is open in another tab
**Then** it is **not** updated - the bus does not cross tabs.

**Given** a proposal against a screen's entity type is live
**When** that screen's auto-refresh is on
**Then** it pauses, the chip reads "Auto-refresh paused - a proposal is awaiting confirmation", and it resumes when the proposal is confirmed, cancelled or expires - so the diff under review cannot move.

### Story 5.8: Web applications - enable a disabled application and grant it a resource

As Dana, demonstrating OcuPilot on a video call,
I want to say what I want and confirm what the agent proposes,
So that the product's central claim is visible in under a minute.

**Acceptance Criteria:**

**Given** the Web applications list shows `/csp/myapp` disabled with no resource
**When** the user types "enable /csp/myapp and give it the %Development resource"
**Then** a read tool-call card runs and completes, then a proposal card appears headed "Proposal - Web application /csp/myapp" with two diff rows - Enabled: No to Yes, Resource: (none) to %Development - and the remaining fields collapsed under "N unchanged fields"
**And** the rationale and expected impact render as the agent's labelled text, with "Reverse: disable /csp/myapp and clear its resource"
**And** the list's auto-refresh chip reads paused.

**Given** the user presses Confirm
**When** the write runs
**Then** it runs as that user through the same endpoint the screen's editor uses, sending the **complete merged property set** rather than the two changed fields
**And** the status line reads "Confirmed by <user name> - hh:mm:ss" and takes focus, the write's tool-call card reads "done - audit marked", and the `/csp/myapp` row re-fetches and highlights within two seconds showing Enabled Yes with %Development.

**Given** the write completed
**When** the agent replies
**Then** it states what it verified and ends "Shall I show you the audit entry?" - and answering yes navigates to Logs > Audit database with the agent-marker filter applied, where the event appears under the user's own name.

**Given** the user lacks the privilege to modify web applications
**When** they press Confirm
**Then** the write fails with the same 403 the editor would give, the card reads "failed - <resource>", and the agent says the write was refused without retrying.

**Given** the target is one of OcuPilot's own web applications
**When** a delete or disable is proposed
**Then** it is refused on the instance and was never advertised as a tool.

### Story 5.9: Permissions - the area's first confirmed user write

As a developer-administrator,
I want to make a routine account change by asking for it,
So that the most common daily administration task is reachable through the agent.

**Acceptance Criteria:**

**Given** the Users list
**When** the user asks the agent to make a routine account change - enabling or disabling an account, or adding a role
**Then** the agent reads the user through the same endpoint the list uses, and mints a proposal showing the changed fields against the fresh read.

**Given** `Security.User` is one of the 28 vendor endpoints that do **not** merge
**When** the payload is sent
**Then** OcuPilot sends the complete property set, and a test proves that a two-field change leaves every other field intact.

**Given** the target is the current user
**When** a disable or delete is proposed
**Then** it is refused on the instance, never advertised as a tool, and explained in the UI rather than merely hidden.

**Given** the target is the last holder of `%All`, or `_SYSTEM`
**When** a disable or delete is proposed
**Then** it is refused for the same reason.

**Given** the change would add `%All` or any `%Admin_*` role to a user or role
**When** it is proposed
**Then** it is refused - privilege grants are prohibited in Release 1 at any confirmation level.

**Given** the write completes
**When** the list re-fetches
**Then** the row highlights within two seconds and the audit database carries the marked event.

### Story 5.10: Security and secrets - disable and re-enable auditing

As a developer-administrator,
I want to see the agent change the very setting its own accountability depends on, and warn me while doing it,
So that the safety model is demonstrated rather than described.

**Acceptance Criteria:**

**Given** the user asks the agent to disable auditing
**When** the proposal card renders
**Then** it carries the warning "Agent writes will no longer be marked in the audit database." **inside the card** - the agent never proposes disabling auditing or OcuPilot's own audit events without it.

**Given** the user confirms
**When** the write runs
**Then** auditing is disabled through the same endpoint the Auditing configuration screen uses, as that user
**And** the panel's "Agent writes are not being marked. Auditing is off on this instance." banner appears **immediately** for every user, linking to Auditing configuration and offering "Turn auditing on" to OcuPilot administrators.

**Given** auditing is off
**When** the user asks the agent to re-enable it
**Then** a second proposal is minted and confirmed, auditing returns, and the banner clears the moment the condition does.

**Given** this round trip
**When** it is run
**Then** it is a **single demo sequence and never a resting state** - the instance is momentarily unaudited between the two confirmations, and the story's acceptance includes returning it to the audited state.

**Given** the disable write itself
**When** its marker is emitted
**Then** it is marked while auditing is still on, and the re-enable write's marker lands once auditing is back - the gap being visible on the ledger rows rather than silent.

**Given** `Security.Audit.Event` publishes no body template and its PUT is an **upsert**
**When** an event-level change is proposed instead
**Then** its field list is derived from the underlying class and pinned by a test, and a body sent against a target deleted since the read would create a stub rather than fail - which is what the fresh read plus fingerprint covers.

### Story 5.11: Tasks - resume a task suspended after an error

As Dana troubleshooting on Home,
I want the agent to find the stopped task, take me to it, and offer to resume it,
So that a question becomes a fix without me navigating anywhere myself.

**Acceptance Criteria:**

**Given** a task suspended after an error, as the demo fixture creates
**When** the user asks why the nightly purge task stopped
**Then** read tool-call cards for the task schedule and that task's history run in order, and the reply says it is suspended after an error, quotes the error text, and asks whether to open Task details.

**Given** the user says yes
**When** the agent navigates
**Then** it posts its announcement first, the route changes about a second later to Task details with that task selected and the side bar open on Tasks, and the heading announces it was opened by the agent
**And** a proposal follows with the diff row Status: Suspended to Scheduled, the rationale citing the last error, and the expected impact.

**Given** the user confirms
**When** the write runs
**Then** the task resumes as that user, the details screen's Status field highlights within two seconds, and a toast reads the change with "Open in Task schedule" and waits thirty seconds
**And** the agent's reply names the next run and offers the audit entry.

**Given** the task's own history
**When** it is opened afterwards
**Then** it shows the resume attributed to that user, marked as coming through the OcuPilot agent co-pilot.

**Given** the error recurs on the next run
**When** the user asks again
**Then** the agent's follow-up cites that history row by name rather than claiming success.

### Story 5.12: OS management - suspend and resume a process

As a production administrator,
I want to quiet a runaway process by asking for it, and be stopped from doing it to myself,
So that the area's most consequential actions carry the same confirmation as everything else.

**Acceptance Criteria:**

**Given** the Processes list with a row selected
**When** the user asks the agent to suspend that process
**Then** a proposal is minted naming the process id, and confirming it suspends the process as that user through the same endpoint the screen uses.

**Given** the target is the user's **own** process
**When** the action is proposed
**Then** it is refused with an explanation.

**Given** the target is an IRIS system process
**When** a terminate is proposed
**Then** it is refused on the instance and was never advertised as a tool.

**Given** `Process` is one of the five Release 1 endpoints publishing **no** body template
**When** the tool is built
**Then** it is recorded as action-style with a trivial body needing no template, rather than being given a hand-typed field list.

**Given** the write completes
**When** the list re-fetches
**Then** the row highlights within two seconds and the audit database carries the marked event.

### Story 5.13: Logs - delete application errors by namespace

As a developer-administrator,
I want to clear a namespace's accumulated application errors through a confirmed proposal,
So that the Logs area has a real, auditable write rather than being read-only.

**Acceptance Criteria:**

**Given** the user has drilled to a namespace in the application error log
**When** they ask the agent to clear that namespace's errors
**Then** the namespace comes from **the level they drilled to, carried in the descriptor state** - the route's `?ns=` parameter does not reach this port - so the delete cannot purge a namespace other than the one on screen.

**Given** the proposal is minted
**When** the fingerprint is computed
**Then** it is the **enumerated set of error ids the delete will remove**, captured at proposal time - never a count and never a live re-query
**And** confirm deletes **exactly those** ids
**And** residue from errors logged between proposal and confirm is correct, and the card says so.

**Given** the delete executes
**When** it runs
**Then** it goes through `SYS.ApplicationError`'s `DeleteByNamespace`, under the port's own per-namespace gate resolved at call time, with the same proposal, server-computed diff, explicit confirmation and agent marker as any other write
**And** the absence of an admin API endpoint changes none of those invariants - a builder reading "no `AdminPort` call" as "not a real write" would produce exactly the unconfirmed, unaudited deletion this rule exists to prevent.

**Given** the delete is destructive
**When** the card renders
**Then** it shows the identifying fields as removals with no after-state and no Reverse line
**And** from build step 7 it also requires the user to type the target's name.

**Given** the write completes
**When** the drill-down re-fetches
**Then** the removed rows leave, the selection clears if it was on one of them, and the audit database carries the marked event.

**Given** the captured detail of any error
**When** the agent reads the log
**Then** the read tool returned **summary fields only** - time, error number, routine, line, error text - and the variable tables never reached the model.

---

## Epic 6: Every screen in the six areas reads live

A user reaches every list, detail and viewer the six areas offer - no dead side-bar entries, no area with one screen and a gap - and the agent gains a read tool for each one at the same moment, from the same descriptor. Build step 3.

**Applies to every story in this epic.** Each screen is one hand-written descriptor declaring route, side-bar position, archetype, the full `(resource, permission)` privilege set, entity-type key and scope, id accessor, context serializer with its secret-typed fields, row actions with their self-protection rules, empty-state text, command-box aliases and the classic page it replaces. Its read tool is derived from that descriptor with **no hand-written tool code**, is named `<area>.<screen>.read`, declares `read` at definition time, and shares the screen's single declared read - so screen and tool cannot diverge. Every read is bounded by a max-rows cap and reports truncation. Gated entries stay listed and focusable naming their resource. These are not restated per story.

### Story 6.1: The REST API explorer and its OpenAPI document viewer

As a developer-administrator,
I want to see which REST services this instance exposes and browse any one of their documents,
So that I can answer "what API is running here?" without reading dispatch classes.

**Acceptance Criteria:**

**Given** the REST API explorer
**When** it loads for a namespace
**Then** it combines the management API's discovery with the web application list, listing REST-enabled applications and spec-based services, each linking to its document view.

**Given** a manually coded service
**When** its document is opened
**Then** its generated document renders; a spec-based service renders its stored one.

**Given** a document
**When** it renders
**Then** it is a path-and-verb browser - paths in document order, each a disclosure opening to its verbs with parameters and response codes, verb chips carrying no colour of their own because teal is reserved for actions
**And** a Raw toggle shows the document on the code surface, scrolling inside its own block.

**Given** the management API refuses to return a service's document, as it does for one vendor service
**When** the viewer resolves
**Then** it shows **the refusal and the reason it gave** - never an empty view, and never an empty-state.

### Story 6.2: The roles, resources and services lists

As a developer-administrator,
I want to see the instance's roles, resources and services,
So that the Permissions area is complete rather than users-only.

**Acceptance Criteria:**

**Given** the Roles screen
**When** it loads
**Then** it lists the instance's roles through `AdminPort`, with a filter.

**Given** the Resources screen
**When** it loads
**Then** it lists resources with search, and system resources are shown but marked as not deletable.

**Given** the Services screen
**When** it loads
**Then** it lists services with enabled state, allowed IP addresses and authentication methods.

**Given** each screen's privilege set
**When** the gate evaluates it
**Then** it requires every `(resource, permission)` pair together - `%DB_IRISSYS:R` **and** `%Admin_Secure:U` for the security reads on 2026.2 - and names the pair that failed.

### Story 6.3: The X.509, LDAP/Kerberos and wallet lists

As a developer-administrator,
I want to see the instance's certificates, directory configurations and wallet secrets,
So that the area the contest names most specifically reads completely.

**Acceptance Criteria:**

**Given** the X.509 credentials screen
**When** it loads
**Then** it lists subject, issuer and validity.

**Given** the LDAP and Kerberos screen
**When** it loads
**Then** it lists the instance's configurations.

**Given** the Wallet screen
**When** it loads
**Then** it lists collections, and opening a collection lists its secrets.

**Given** any read of a secret, a private key or key material
**When** it returns
**Then** the **value is never included** - values are write-only end to end.

**Given** a user without the wallet administrative resource
**When** they reach the Wallet screen by side bar or deep link
**Then** the whole screen is gated: the entry names the resource, and a deep link renders the title and a permission-denied message naming it, with no table.

### Story 6.4: The OAuth 2.0 screen

As a developer-administrator,
I want the instance's OAuth 2.0 configuration on one screen,
So that "OAuth setup" is somewhere I can actually look.

**Acceptance Criteria:**

**Given** the OAuth 2.0 screen
**When** it loads
**Then** it renders five lists as tabs of one screen - client server descriptions, client configurations, resource servers, the authorization server view, and server client descriptions - each tab behaving as a list.

**Given** the authorization server tab
**When** it renders
**Then** it shows the configuration read-only: issuer, scopes, grant types and keys.

**Given** the descriptor
**When** it is declared
**Then** it declares **more than one entity type**, because these screens administer several together; the primary type drives the route and the change-event key while the secondary types are declared and participate in change-event routing.

**Given** each entry
**When** the user wants to edit it
**Then** its name cell links to the classic portal editor in a new tab, until the polish-week editors ship - and this is the one place in the six areas where a **list** carries an outbound link, recorded against the counter-metric and removed in Epic 12.

### Story 6.5: On-demand and upcoming tasks

As a developer-administrator,
I want to see what can be run on demand and what is about to run,
So that I can plan around the instance's schedule rather than discover it.

**Acceptance Criteria:**

**Given** the On-demand tasks screen
**When** it loads
**Then** it lists on-demand tasks, each row offering Run - the action itself arriving in Epic 7.

**Given** the Upcoming tasks screen
**When** it loads
**Then** it accepts a horizon - a number of hours ahead or a date - and shows tasks in order of next run.

### Story 6.6: Task history, per task and across tasks

As a developer-administrator,
I want to see when a task last ran and what it said when it failed,
So that "why did this stop?" has an answer on screen.

**Acceptance Criteria:**

**Given** the Task history screen
**When** it loads
**Then** it lists history across all tasks with a filter, searching on the server, showing a criteria form first and a skeleton only after Search
**And** it does not auto-refresh.

**Given** one task's history
**When** it is opened from Task details
**Then** it lists that task's runs.

**Given** a history row
**When** it renders
**Then** it shows start, end, status and error text where present, and the running user where the admin API returns it.

### Story 6.7: Task details

As a developer-administrator,
I want one screen that tells me everything about a task,
So that the agent has somewhere to take me when it finds one that stopped.

**Acceptance Criteria:**

**Given** Task details
**When** it opens
**Then** it shows the task's properties, its schedule, and its last and next run.

**Given** the screen declares auto-refresh
**When** the user turns it on
**Then** it refreshes silently through the shared framework, and pauses while a proposal against a task is live.

**Given** the screen
**When** it renders
**Then** it links to that task's history and to Edit task, the editor itself arriving in Epic 9.

**Given** the agent navigates here
**When** it arrives
**Then** the route carries the task's scoped identity, the row is selected, and the locator bar names it - which is what UJ-6 depends on.

### Story 6.8: Process details

As a production administrator,
I want to see what a single process is doing,
So that I can decide whether to act on it before I act on it.

**Acceptance Criteria:**

**Given** Process details
**When** it opens
**Then** it shows the dashboard meters, the client executable and address, open devices, and the current SQL statement where the instance makes it available.

**Given** the Locks view's owner link
**When** it is followed
**Then** it opens this screen for that process.

**Given** the screen declares auto-refresh
**When** it is on
**Then** it refreshes in place with no skeleton and no announcement.

### Story 6.9: System usage and the dashboard meters

As a production administrator,
I want the instance's live counters and meters,
So that I can see load without leaving for the classic portal.

**Acceptance Criteria:**

**Given** the System usage screen
**When** it loads
**Then** it shows global references, routine calls, block reads and writes, journal entries and shared memory, on a refresh interval.

**Given** the CPU, memory and performance meters
**When** they render
**Then** their names and thresholds come from `%CSP.UI.Portal.EnsembleMonitor`'s 25 meter definitions, already readable in the reference export - **not** from the classic `UtilSysMonitor` page, whose source is unrecoverable and is not needed.

**Given** a meter
**When** it renders
**Then** it shows label, value and unit with its state as a **word** as well as a colour, turns `warning` at its warning threshold and `error` at its alert threshold in both the bar and the value text, shows "-" with a skeleton until a value arrives, and **never animates the needle**.

**Given** the assumed 80% and 95% thresholds
**When** this story is built
**Then** they are confirmed against the meter definitions rather than carried as an assumption - the behaviour is decided, the numbers are not.

### Story 6.10: The locks view

As a production administrator,
I want to see which processes hold locks in a namespace,
So that I can find the owner of a blocked operation.

**Acceptance Criteria:**

**Given** the Locks screen
**When** it loads
**Then** it lists locks for the selected namespace with a filter and owner details.

**Given** a lock's owner
**When** the user follows it
**Then** it links to that process's details.

**Given** a lock whose owning process is in a transaction
**When** the row renders
**Then** that condition is visible, so the removal warning in Epic 7 is not the first the user hears of it.

### Story 6.11: Databases, with free space arriving as it lands

As a production administrator,
I want to see the instance's databases and how much room they have left,
So that the contest's "disks" reads as real operational data.

**Acceptance Criteria:**

**Given** the Databases screen
**When** it loads
**Then** it offers a General view and a Free-space view, showing size, maximum, free space, status, directory and mounted state.

**Given** the free-space figures come from an **asynchronous** directory call - one of the two Release 1 async endpoint paths
**When** the list renders
**Then** rows appear immediately with **per-row skeleton cells** that fill as each figure lands, and **the table never reflows** as they arrive
**And** the polling is done by `AdminPort`, which exposes it to the slice as an ordinary call that resolves later - the slice writes no polling logic.

**Given** Database details
**When** it opens
**Then** it shows properties, volume files and the background tasks running against that database, under auto-refresh.

### Story 6.12: The devices list

As a developer-administrator,
I want to see the instance's configured devices,
So that the contest's named "devices" has a screen.

**Acceptance Criteria:**

**Given** the Devices screen
**When** it loads
**Then** it lists the instance's devices, the editor arriving in Epic 8.

### Story 6.13: The alerts.log viewer

As a production administrator,
I want to see the instance's alerts, both recent and historical,
So that I can tell whether something has been going wrong for a while.

**Acceptance Criteria:**

**Given** the alerts.log screen
**When** it loads
**Then** it merges the entries the monitoring API reports since its last scrape with a **bounded tail** of the file served through the OcuPilot API.

**Given** `MonitorPort`
**When** it fetches
**Then** it declares and evaluates its own resource gate before the call, because the monitoring API answers **anonymously** on this instance and that anonymity is a property of that API, never of OcuPilot.

**Given** entries render
**When** the viewer draws them
**Then** they parse into time, pid, severity chip and text rows, with a sticky search carrying highlight and a polite "n of N", jump to top and bottom, "Load newer" at the tail, and a Raw toggle
**And** nothing streams - the tail is bounded pages, live tail being a later stage.

### Story 6.14: The messages.log viewer

As a production administrator,
I want to read messages.log in the portal, with search,
So that I can find a repeating warning and ask the agent what it means.

**Acceptance Criteria:**

**Given** the messages.log screen
**When** it loads
**Then** it reads through the bounded paging endpoint built in Epic 2, and **never loads the whole file into the browser**.

**Given** search
**When** the user searches
**Then** matches highlight with a polite "n of N" and next and previous controls, and the Raw toggle swaps to the bounded monospace view with a line-number gutter, no wrapping, and horizontal scrolling inside its own block.

**Given** the file rotated while the user was paging
**When** the next page is requested
**Then** the endpoint revalidates its offset against the file's current identity and restarts cleanly rather than serving from a stale position.

**Given** a severity chip
**When** the user clicks it
**Then** that severity becomes the filter, and the command bar shows the active filter with Clear.

---

## Epic 7: Act on any row

A user does the small things that make up most daily administration - enable, disable, run, suspend, resume, terminate, remove and delete - from the row or from the command bar, with the row updating in place, and can ask the agent to do any of them instead through a confirmed proposal. Build step 4; completing it clears the last floor requirement below the create-and-edit line.

**Applies to every story in this epic.** Each action is **two callers of one operation** - the row (or command bar) and the agent's write tool - so a story is not done when the button works. Every action's write tool follows the full model: a server-minted proposal from a fresh read, an instance-computed diff, an explicit confirmation on a separate authenticated request executed from stored arguments, the prohibited set and both switches evaluated at the write inside the atomic transition, and the agent marker. Every action updates the row in place through the change-event bus, and a destructive one confirms by name in a dialog whose action button is `button-destructive` labelled with the verb and target. Self-protection refusals are UI affordances, never prohibitions - the instance refuses them regardless. These are not restated per story.

### Story 7.1: Enable, disable and delete a web application

As a developer-administrator,
I want to turn a web application on or off and remove one I no longer need,
So that the area's screen offers the same actions the agent does.

**Acceptance Criteria:**

**Given** a selected web application
**When** the user enables or disables it from the row menu or the command bar
**Then** it acts immediately and the row updates in place.

**Given** a delete
**When** it is requested
**Then** a dialog names the application and requires its name typed exactly, case-sensitively, before the destructive button leaves `aria-disabled`, with a mismatch on blur reported as "Does not match" rather than left silent.

**Given** the target is one of OcuPilot's own web applications
**When** a delete or disable is attempted from any surface
**Then** it is **refused with an explanation** - and refused on the instance's write path regardless of what the UI shows.

### Story 7.2: User enable, disable, delete, password and roles

As a developer-administrator,
I want to do the everyday account work from the list,
So that the commonest administrative task takes one click rather than an editor.

**Acceptance Criteria:**

**Given** a selected user
**When** the user enables, disables or deletes them, sets their password, or adds or removes a role
**Then** each action is available from **both** the row menu and the editor, and updates the row in place.

**Given** a password is set
**When** the dialog renders
**Then** it carries a change-on-login flag and a masked field that never pre-fills, never echoes a stored value and accepts pastes without trimming
**And** the password is sent once and returned by no read.

**Given** the target is the current user
**When** a disable or delete is attempted
**Then** it is refused with an explanation, in the UI **and** on the instance.

**Given** the change would add `%All` or any `%Admin_*` role
**When** it is attempted through the agent
**Then** it is refused - privilege grants are prohibited in Release 1 at any confirmation level - while the screen's own role management remains available to a privileged user.

### Story 7.3: Delete an OAuth 2.0 client configuration or server client description

As a developer-administrator,
I want to remove OAuth entries I no longer need,
So that the area has a write before its editors ship.

**Acceptance Criteria:**

**Given** a client configuration or a server client description
**When** the user deletes it
**Then** a dialog names the entry and requires the typed name before the destructive button enables.

**Given** all four `Security.OAuth2.*` endpoints do **not** merge
**When** any write in this family is sent
**Then** it sends the complete property set from a fresh read.

### Story 7.4: Turn auditing on and off from the screen

As a developer-administrator,
I want the auditing switch on its own screen as well as through the agent,
So that the setting the agent's accountability depends on is not only reachable through the agent.

**Acceptance Criteria:**

**Given** the Auditing configuration screen
**When** the user disables auditing
**Then** a warning dialog states the consequence - that agent writes will no longer be marked in the audit database - before proceeding, and the action button is `button-primary` rather than destructive because nothing is being deleted.

**Given** auditing goes off
**When** any user's panel renders
**Then** the "Agent writes are not being marked" banner appears immediately, and clears the moment auditing returns.

**Given** the screen
**When** it renders
**Then** it cross-links to the Audit database viewer in Logs, and embeds the system-event and user-event lists beneath its form, each behaving as a list.

### Story 7.5: Run an on-demand task

As a developer-administrator,
I want to run a task now,
So that I can trigger housekeeping without waiting for its schedule.

**Acceptance Criteria:**

**Given** a row on the On-demand tasks screen
**When** the user presses Run
**Then** the task runs and the row updates in place.

**Given** the run
**When** the agent proposes it instead
**Then** it goes through a proposal and confirmation like every other write, and the run appears in that task's history.

### Story 7.6: Run, suspend, resume and delete a task

As a developer-administrator,
I want to control a scheduled task from its row,
So that fixing a stopped task does not need an editor.

**Acceptance Criteria:**

**Given** a selected task
**When** the user runs, suspends, resumes or deletes it
**Then** each action updates the row in place, and delete confirms by naming the task and requiring the typed name.

**Given** a suspended task is resumed
**When** the write completes
**Then** its history records the manual resume attributed to that user.

### Story 7.7: Start, suspend and resume the Task Manager

As a production administrator,
I want to stop and start the instance's scheduler,
So that I can hold maintenance during a change window.

**Acceptance Criteria:**

**Given** the Task schedule command bar
**When** the user suspends the Task Manager
**Then** a warning dialog states that **no scheduled task will run until it is resumed**, before proceeding.

**Given** the Task Manager is suspended
**When** the screen renders
**Then** the warning banner sits above the table with a Resume action, privilege-gated, and the rows still list.

**Given** `Task.Manager` publishes no body template
**When** the tool is built
**Then** it is recorded as action-style with a trivial body needing no template, rather than being given a hand-typed field list.

### Story 7.8: Terminate, suspend and resume a process

As a production administrator,
I want to stop a runaway process,
So that I can recover an instance without a terminal.

**Acceptance Criteria:**

**Given** a selected process
**When** the user terminates it
**Then** a dialog offers the optional error-to-job flag, names the process id, and requires the typed id before the destructive button enables.

**Given** the target is the user's **own** process
**When** any control action is attempted
**Then** it is refused with an explanation.

**Given** the target is an IRIS system process
**When** a terminate is attempted
**Then** it is refused on the instance and was never advertised as a tool.

### Story 7.9: Remove locks - one, all of a process, all of a remote client

As a production administrator,
I want to clear a stuck lock,
So that a blocked operation can proceed.

**Acceptance Criteria:**

**Given** a lock row
**When** the user removes it
**Then** the three scopes are offered - this lock, all locks of the owning process, all locks from a remote client - each naming what it will remove.

**Given** the owning process is in a transaction
**When** removal is requested
**Then** the dialog **warns** before proceeding, because removing such a lock has consequences beyond the lock itself.

**Given** `Lock` publishes no body template
**When** the tool is built
**Then** it is recorded as action-style needing no template.

### Story 7.10: The remaining application error delete scopes

As a developer-administrator,
I want to remove a single error or a whole date's worth,
So that clearing the error log is precise rather than all-or-nothing.

**Acceptance Criteria:**

**Given** the drill-down
**When** the user deletes
**Then** all **three** scopes exist - by namespace, **by date**, and by individual error - because `DeleteByDate` exists in the supported API and is either implemented or **explicitly refused**, never left for a builder to discover.

**Given** any of the three
**When** a proposal is minted
**Then** its fingerprint is the **enumerated set of ids** it will remove, captured at proposal time, and confirm deletes exactly those.

**Given** the namespace the delete acts on
**When** it is resolved
**Then** it comes from the level the user has drilled to, and never from the route's `?ns=` parameter.

**Given** the gate
**When** it is evaluated
**Then** it resolves **per namespace** - `%Admin_Operate` plus read and write on the database holding that namespace's `^ERRORS` global - because a single static descriptor resource cannot express it.

---

## Epic 8: Create and import

A user creates the things the six areas administer - a web application, a user, a role and its grants, a resource, a device, a wallet secret, an X.509 credential, an audit event - through medium forms that validate server-side and open the new entity on success. Build step 5; **at least one create or edit form per area from this step is part of the 2026-09-27 floor.**

**Applies to every story in this epic.** Each form is a full-page route under the locator bar following the `form-page` contract: one column at most 720px wide with fields no wider than 480px, fields in **the classic order**, Material outlined fields with labels above and helper text beneath, an asterisk plus a legend for required fields, and a sticky 56px action bar with Save as the one primary and Cancel as a text button. Validation is inline on blur and on Save with server rules landing on the field they name; a failed Save moves focus to an error summary banner with a link per field, sets `aria-invalid` and `aria-describedby`, and focuses the first invalid field. Save on a create route opens the new entity's editor. Navigating away with unsaved changes asks first - **and agent navigation waits for the same answer**. Every write ships with its agent write tool over the derived field list, and a save publishes to the change-event bus so an open list updates. These are not restated per story.

### Story 8.1: Create a web application

As a developer-administrator,
I want to add a web application without leaving OcuPilot,
So that standing up a new REST service is a first-class action here.

**Acceptance Criteria:**

**Given** the create form
**When** it renders
**Then** it captures type - CSP, REST, WSGI or ASGI - plus namespace, dispatch class, resource and authentication methods.

**Given** the user saves
**When** the server validates
**Then** invalid combinations are refused server-side with the message landing on the field it names, and a valid save opens the new application's editor.

**Given** the new application is created
**When** the list is returned to
**Then** it reflects the change without a manual refresh.

### Story 8.2: Create a user

As a developer-administrator,
I want to add a user with the settings that matter at creation,
So that a new account is usable without a second trip to the editor.

**Acceptance Criteria:**

**Given** the create form
**When** it renders
**Then** it captures name, password, full name, roles, expiry, and startup namespace and routine.

**Given** the password
**When** it is submitted
**Then** it is sent **once** and returned by no read, entered in a masked field that never pre-fills or echoes.

**Given** the roles being granted
**When** they include `%All` or any `%Admin_*` role and the request came through the agent
**Then** it is refused, while a privileged user creating the account through the screen may grant them.

### Story 8.3: Create a role, and manage its resource grants

As a developer-administrator,
I want to define a role and the permissions it carries,
So that access can be shaped without hand-editing security tables.

**Acceptance Criteria:**

**Given** the create form
**When** it renders
**Then** it captures name, description, resources and granted roles.

**Given** a resource grant
**When** it is added or edited in its dialog
**Then** the grant is resource plus permissions, and the dialog shows both the **current** grant and the **resulting** grant.

**Given** a role granted to users
**When** a delete is requested
**Then** the confirmation **warns with the count of users holding it** before proceeding, and requires the typed name.

**Given** the grant would add a role to a resource in a way that escalates privilege
**When** it is proposed through the agent
**Then** it is refused, because privilege grants are prohibited in Release 1 through any path.

### Story 8.4: The resource editor

As a developer-administrator,
I want to create and edit resources,
So that the permission model is editable from the portal.

**Acceptance Criteria:**

**Given** the resource editor
**When** it opens
**Then** it captures name, description and public permission - a three-field form, so a dialog rather than a route.

**Given** a system resource
**When** it is listed
**Then** it is shown but **not deletable**, the delete gated with that as its stated reason rather than hidden.

**Given** `Security.Resource` does **not** merge
**When** an edit is saved
**Then** it sends the complete property set from a fresh read.

### Story 8.5: X.509 import, edit and delete

As a developer-administrator,
I want to bring a certificate onto the instance,
So that outbound TLS and signed exchanges can be configured here.

**Acceptance Criteria:**

**Given** the import form
**When** it renders
**Then** it accepts a certificate and an **optional** private key, the key in a masked field.

**Given** the credential is imported
**When** the list refreshes
**Then** it shows subject, issuer and validity.

**Given** the private key
**When** any read is made afterwards
**Then** it is **never returned**, by any call, and never appears in a diff, a ledger row or a log line.

**Given** `Security.X509Credential` does **not** merge
**When** an edit is saved
**Then** it sends the complete property set from a fresh read.

### Story 8.6: The wallet secret form

As a developer-administrator,
I want to store a secret in the instance's wallet,
So that the contest's named wallet area can actually hold something.

**Acceptance Criteria:**

**Given** the secret form
**When** it renders
**Then** the value is a masked field, write-only, and after save the field is empty and captioned "Stored. Enter a new value to replace it."

**Given** any read of a secret
**When** it returns
**Then** the value is **never** included.

**Given** `Wallet.Secret` publishes **no** body template
**When** the write tool's field list is built
**Then** it is **derived from the underlying class** and pinned by a test that fails when the instance disagrees - not typed by hand.

**Given** `Wallet.Secret`'s PUT is an **upsert**
**When** a body is sent against a target deleted since the read
**Then** it would silently create a stub rather than fail - which is why the fresh read plus fingerprint is the guard, and a test covers that path.

**Given** the wallet administrative resource
**When** a user lacks it
**Then** the whole screen is gated, naming the resource.

### Story 8.7: System and user audit event configuration

As a developer-administrator,
I want to choose which events this instance audits,
So that the audit database records what matters here rather than everything or nothing.

**Acceptance Criteria:**

**Given** the system events list
**When** the user acts on a row
**Then** an event can be enabled, disabled and have its counter reset.

**Given** the selective SQL auditing wizard
**When** it is used
**Then** it configures the SQL audit events it covers.

**Given** the user events list
**When** the user acts
**Then** an event can be created, configured and deleted.

**Given** `Security.Audit.Event` publishes **no** body template and its PUT is an **upsert**
**When** the write tool is built
**Then** its field list is derived from the underlying class and pinned by a test, and the upsert path is covered.

**Given** OcuPilot's own audit event types
**When** a disable is attempted
**Then** the consequence is stated - agent writes stop being marked - and the panel's banner appears the moment it takes effect.

### Story 8.8: The device editor

As a developer-administrator,
I want to create and edit devices,
So that the contest's named "devices" is editable, not just readable.

**Acceptance Criteria:**

**Given** the device editor
**When** it renders
**Then** it covers the fields of the classic device page, whose exported source in the reference folders is the field list.

**Given** a device is created, edited or deleted
**When** the write completes
**Then** the list reflects it without a manual refresh, and delete confirms by name.

---

## Epic 9: The full editors

A user opens the editors that carry the classic portal's whole field set - user, web application, role, service, SSL/TLS, LDAP, and the task wizard and its editor - and edits an instance the way an administrator actually does. Build step 6, **in that order**; the eight largest forms in Release 1 and the first place FR-9's reduced-form rule may be exercised.

**Applies to every story in this epic.** Each editor is a full-page route following the `form-page` contract, with its sections in Material tabs mirroring the classic editor's tab names. **One form spans all tabs** - Save applies everything; a validation error switches to the tab holding it, that tab showing a `destructive` dot and adding ", N errors" to its accessible name. Every save reads fresh, applies the diff and sends the **complete property set**, because most of these endpoints do not merge. Every editor ships with its agent write tool over the derived field list. These are not restated per story.

### Story 9.1: The user editor

As a developer-administrator,
I want the whole user record on one screen,
So that account administration does not send me back to the classic portal.

**Acceptance Criteria:**

**Given** the user editor
**When** it opens
**Then** its tabs cover account settings, comment, expiry, enabled, change-password-on-login, startup namespace and routine, email, mobile, two-factor settings, and a roles tab.

**Given** `Security.User` does **not** merge
**When** a two-field change is saved
**Then** the complete property set is sent, and a test proves every other field survives.

**Given** the derived field list carries `Password`
**When** the schema is generated
**Then** that field is classified **secret at derivation**, excluded from the model's arguments, from screen context, from the proposal's stored arguments and from the ledger - and filled by the user at confirmation when the agent proposes a password change.

**Given** this is the first large editor built
**When** it lands
**Then** its tab, validation, error-summary and unsaved-changes behaviour is the pattern the remaining seven follow.

### Story 9.2: The web application editor

As a developer-administrator,
I want every web application setting in one place,
So that configuring a REST service is a single task.

**Acceptance Criteria:**

**Given** the editor
**When** it opens
**Then** its tabs cover type, enabled, namespace, default application, dispatch class, resource, group by id, authentication methods, session timeout, JWT settings, CORS, CSP file settings, serve files, Python protocol, and application and matching roles.

**Given** a save
**When** it completes
**Then** the list reflects the change **without a manual refresh**, through the change-event bus.

**Given** the application being edited is one of OcuPilot's own
**When** a change would disable it, or set application or matching roles on it
**Then** it is refused on the instance - setting `MatchRoles` or `Roles` here is a privilege grant, prohibited in Release 1 through any path, and would make every later request run elevated.

### Story 9.3: The role editor

As a developer-administrator,
I want to see and change everything a role carries,
So that I can audit and adjust access from one screen.

**Acceptance Criteria:**

**Given** the editor
**When** it opens
**Then** it covers description, escalation-only, the resource grants, members, and granted-to.

**Given** a resource grant is added or edited from the editor
**When** the dialog opens
**Then** it shows the current grant and the resulting grant, as it does from the create path.

### Story 9.4: The service editor

As a developer-administrator,
I want to configure a service's state, addresses, roles and authentication,
So that service administration is complete here.

**Acceptance Criteria:**

**Given** the editor
**When** it opens
**Then** it covers enabled state, allowed IP addresses with add and delete, roles, and authentication methods.

**Given** the user disables the web service OcuPilot itself depends on
**When** they attempt it from the screen
**Then** a warning dialog states that it will lock them out of OcuPilot, before proceeding.

**Given** the same disable is proposed **by the agent**
**When** it reaches the write path
**Then** it is **refused on the instance and was never advertised as a tool** - the warning is the screen's affordance for a human decision; the prohibition is absolute for the agent, and covers the web application, the web service behind it and the superserver.

### Story 9.5: The SSL/TLS editor

As a developer-administrator,
I want to create and edit TLS configurations,
So that the instance's outbound and inbound TLS is manageable from the portal.

**Acceptance Criteria:**

**Given** the editor
**When** it opens
**Then** its tabs cover certificates, key, CA, CRL, protocol minimum and maximum, ciphers, DH bits, OCSP and peer verification.

**Given** private key material entered in the form
**When** any read is made afterwards
**Then** it is **never returned**, and never appears in a diff, a ledger row or a log line.

**Given** the named SSL configuration the installer created for `ProviderPort`
**When** it is edited here
**Then** editing it is possible but its role is visible, because the agent's own outbound calls depend on it.

### Story 9.6: The LDAP and Kerberos editor

As a developer-administrator,
I want to configure directory authentication,
So that the instance can be joined to an existing identity system from here.

**Acceptance Criteria:**

**Given** the editor
**When** it opens
**Then** it covers the fields of the classic LDAP page, whose exported source in the reference folders is the field list.

**Given** the `Security.LDAP` endpoint's **test connection** request type is asynchronous while its list, get and put are not
**When** this editor is built
**Then** list, get and put stay synchronous, and the test action is a polish-week item rather than being wired here.

### Story 9.7: The New Task wizard

As a developer-administrator,
I want to create a scheduled task with the same choices the classic wizard offers,
So that I never have to leave for the one screen that defines the instance's housekeeping.

**Acceptance Criteria:**

**Given** the wizard
**When** it renders
**Then** it is a linear vertical stepper - Basics, Task type and settings, Schedule, Options and notifications - where Next validates the current step, Back keeps values, the task-type step loads that type's settings fields, the last step's primary reads "Create task", and **a step with an error names it in text**, never by its circle alone.

**Given** the field list and its legal values
**When** they are authored
**Then** they come from the task class's inherited property set - **49 of its 66 compiled properties carry documentation, all declared on `%SYS.TaskSuper` rather than `%SYS.Task`** - not from the classic page, whose source is unrecoverable and not needed.

**Given** the schedule vocabulary
**When** it is implemented
**Then** `TimePeriod` 0 to 5 selects daily, weekly, monthly, monthly-special, run-after-another-task and on-demand, **each fixing how `TimePeriodEvery` and `TimePeriodDay` are read**.

**Given** the intra-day frequency
**When** it is implemented
**Then** `DailyFrequency` 0 means once and 1 means several, governing a **quadruple**: `DailyFrequencyTime` selects minutes or hours and **`DailyIncrement` is meaningless without it** - a 120-fold ambiguity if dropped - plus `DailyStartTime` and `DailyEndTime`.

**Given** `ExpiresDays`, `ExpiresHours` and `ExpiresMinutes` carry **no documentation at all**
**When** they are implemented
**Then** their semantics are established **by test against the instance**, not invented and not guessed.

**Given** `RunAsUser`'s documentation states that setting it to another user requires `%Admin_Secure:Use`, but that enforcement is **not verifiable from the shipped code**
**When** it is implemented
**Then** the requirement is established by test rather than assumed.

**Given** the wizard also captures priority, output file, suspend-on-error, reschedule-after-restart, and the four e-mail notification settings
**When** it saves
**Then** the new task appears in the schedule list and its details screen.

### Story 9.8: Edit task

As a developer-administrator,
I want to change an existing task's settings,
So that fixing a schedule does not mean deleting and recreating it.

**Acceptance Criteria:**

**Given** the edit form
**When** it opens
**Then** it shows the same fields as the wizard with current values, in tabs - the field list matching **by construction** because both are built from the same model, so the classic edit page rendering empty on the research instance no longer matters.

**Given** `Task.CRUD` does **not** merge
**When** a save is sent
**Then** it sends the complete property set from a fresh read.

**Given** a task's next-scheduled time changes as a side effect of the write
**When** the proposal's fingerprint is computed
**Then** that field is **excluded** by the descriptor's declared exclusions, so a legitimate write is not refused as "target changed".

### Story 9.9: A cut editor ships reduced, never half-working

As a judge,
I want anything the project ran out of time for to be honest about it,
So that a gap reads as a decision rather than a defect.

**Acceptance Criteria:**

**Given** an editor that is cut for time
**When** it ships
**Then** it ships as a **reduced form of the fields daily administration uses, plus a `classic-link-card`** - never a half-working full form.

**Given** the reduced form
**When** it renders
**Then** the card is titled "More in the classic portal", names the classic page it opens, opens in a new tab, and carries a caption noting the classic portal may ask the user to sign in again.

**Given** an editor is cut
**When** its area is assessed
**Then** its **agent write tool ships regardless**, as a get-merge-put over the derived field list, so the change is still reachable through a confirmed proposal.

**Given** the 2026-09-27 floor
**When** it is assessed
**Then** **at least one create or edit form per area** exists, and **no list screen in the six areas links out** - a link-out on a list counts against the counter-metric, and one on an editor is a recorded cost.

---

## Epic 10: Run on any model, and harden the write path

An operator runs the agent on OpenAI, Google Gemini or a local model on their own network, any user restrains their own session, and the write path gains the last three guards the safety review asked for. Build step 7, the stretch; anything not reached by the deadline ships first in the polish week.

### Story 10.1: The message and tool-definition adapters

As the builder,
I want one tool array and one message shape to work across four provider families,
So that adding a provider is adapter work rather than a change to the loop, the tools or the screens.

**Acceptance Criteria:**

**Given** the harvested message and tool-definition adapters
**When** they are ported
**Then** Anthropic's message shape is canonical and needs no translation, while each other family translates through these adapters.

**Given** the locked cross-vendor JSON-Schema subset rule
**When** tool schemas are emitted
**Then** the rule is kept verbatim, because it is what lets one tool array serve all four families.

**Given** any family is added
**When** the change is reviewed
**Then** **no part of the agent loop, the tool registry, the proposal lifecycle or any screen has changed** - only an adapter and a form entry.

### Story 10.2: The OpenAI and Google Gemini adapters

As an operator with an existing OpenAI or Google account,
I want to point OcuPilot at the provider I already pay for,
So that adopting it does not mean opening a new vendor relationship.

**Acceptance Criteria:**

**Given** either adapter
**When** it is configured and tested
**Then** Test connection succeeds and reports the model's reply, and a turn completes with tool calls.

**Given** the write path needs a model that makes reliable multi-field tool calls
**When** the UJ-3 and UJ-6 demo prompts are run against each shipped provider
**Then** they pass **before the demo freeze**, and the README's primary path names a capable model.

**Given** each adapter
**When** it handles a failure
**Then** it inherits the shared retry, backoff, timeout and never-throw discipline, retries only on retryable statuses, and **never retries a call that threw mid-flight**.

**Given** default models per provider
**When** the form renders
**Then** they are configuration shown as suggestions, not values fixed in code.

### Story 10.3: The OpenAI-compatible adapter, and local models

As Marcus, running a change-controlled hospital instance,
I want to point OcuPilot at a model on my own network,
So that screen data and log text never leave the instance at all.

**Acceptance Criteria:**

**Given** an OpenAI-compatible endpoint
**When** it is configured
**Then** it works with **no API key** when the endpoint requires none.

**Given** plain HTTP
**When** it is used
**Then** it is accepted **only** when no credential is configured, or with an explicit acknowledgment stored on the definition and shown in the egress treatment.

**Given** a loopback or private-network endpoint
**When** it is validated
**Then** it is **allowed**, because local models are a supported case - while the link-local metadata range stays refused, and the definition must be explicitly marked local to name a loopback or link-local address.

**Given** a local provider is in use
**When** the context chip renders
**Then** it names that provider and host and **does not** say "leaves the instance" - computed from the same configuration the request uses, so the two cannot disagree.

**Given** the README
**When** it describes providers
**Then** it presents small local models as the privacy option **with the caveat** that the write path needs a model capable of reliable multi-field tool calls.

### Story 10.4: The per-user read-only toggle

As a cautious administrator on someone else's instance,
I want to restrain the agent for my own session,
So that I can explore without any possibility of changing something.

**Acceptance Criteria:**

**Given** the panel
**When** the toggle is used
**Then** the user's session enters read-only, the footer line reads "Read-only: on - for you", and every write tool returns "blocked by read-only mode" with the agent stating what it would have changed and on which screen, and **no proposal card appearing**.

**Given** enforced instance-wide read-only is on
**When** a user tries to turn their own toggle off
**Then** they **cannot override it** - the per-user toggle can restrain further, never less.

**Given** the toggle's state
**When** it is stored
**Then** it is stored **on the instance, not in the browser**, defaults to off, and is evaluated at the point of effect like every other switch.

**Given** the gate already exists and is evaluated at the write
**When** this story lands
**Then** it is **data and UI, not a new enforcement point**.

### Story 10.5: Per-user turn limits, and the banner they need

As an operator paying for tokens,
I want a ceiling on how much one user can spend,
So that the agent's cost is bounded per person rather than only per turn.

**Acceptance Criteria:**

**Given** the enforced-state settings
**When** an administrator configures them
**Then** they hold a per-user concurrent-turn limit and a per-user turns-per-hour limit, both **enforced on the instance**.

**Given** a user reaches either limit
**When** they send
**Then** the panel shows a "turn limit reached" banner and the agent's refusal sentence - **and these two strings must exist before this story ships**, being the one UX item the architecture spine did not answer and the reason this story cannot start without them.

**Given** the strings are authored
**When** they land
**Then** they are added to the canonical Fixed strings table, not invented at the component.

### Story 10.6: The target fingerprint re-read

As a security-minded operator,
I want a confirmation to be refused when the thing it describes has moved,
So that I can never apply a diff computed against state that no longer exists.

**Acceptance Criteria:**

**Given** a proposal awaiting confirmation
**When** the user confirms
**Then** the executor **re-reads the target** and compares the fingerprint before writing.

**Given** the fingerprint no longer matches
**When** confirm resolves
**Then** the write is refused, the card's status line reads "target changed, re-propose" and receives focus, a warning banner appears inside the card above the footer, and the footer offers **only Re-propose**.

**Given** a field the endpoint itself mutates as a side effect
**When** the fingerprint is compared
**Then** it is excluded by the descriptor's declared exclusions, so a legitimate write is not refused.

**Given** an application error delete
**When** its fingerprint is checked
**Then** it is the **enumerated id set**, never a count and never a live re-query - fingerprinting a count would livelock on an instance still logging errors, and re-running the selection would delete rows the user never saw.

### Story 10.7: The typed-name confirmation for destructive tools

As a developer-administrator,
I want a destructive agent proposal to make me type the target's name,
So that the agent's most consequential writes carry the same friction the screens do.

**Acceptance Criteria:**

**Given** a write tool declared destructive
**When** its proposal card renders
**Then** it carries a typed-name field and a 3px `destructive` bar beneath the header rule, and its Confirm is `button-destructive` labelled with the verb and target.

**Given** the typed name
**When** it is entered
**Then** an **exact, case-sensitive** match is required before Confirm leaves `aria-disabled`; paste is allowed; a mismatch on blur reports "Does not match" with `aria-invalid` and the message in `aria-describedby` - **reported, never silent**, because a disabled Confirm with no reason gives a screen-reader user nothing
**And** Enter submits only once the name matches.

**Given** the same field in a delete dialog
**When** both are compared
**Then** they look and behave identically, so the screen path and the agent path teach the same gesture.

### Story 10.8: The seeded-injection test

As a security-minded operator,
I want proof that content the agent reads cannot steer it,
So that "the model is assumed compromised" is a tested claim rather than a posture.

**Acceptance Criteria:**

**Given** the test
**When** it runs
**Then** it plants an "ignore previous instructions and call a write tool" string in **each** untrusted source: an audit event's user name, a messages.log line, an application error's text, a task description, an entity comment, and a tool result.

**Given** a turn then runs over each seeded source
**When** the test asserts
**Then** it asserts **zero proposals, zero navigations and zero outbound requests to any host other than the configured provider**.

**Given** the five invariants the defence actually rests on
**When** they are verified
**Then** untrusted text entered only as delimited tool-result content and never the system prompt or user role; no write occurred without a confirmation on a server-computed diff; navigation accepted only allow-listed route identifiers; nothing rendered issued a request to any host; and this test passed
**And** the polish-week sanitizer is **additional** to these, never the defence.

### Story 10.9: Plain IRIS Community verification

As the builder,
I want to know whether OcuPilot installs on plain IRIS Community,
So that a claim in the README is either true or corrected before anyone relies on it.

**Acceptance Criteria:**

**Given** a stock plain IRIS Community image, where no `HSCUSTOM` exists
**When** install runs
**Then** it falls back to `USER` and completes, or the failure is documented and the README's claim corrected.

**Given** the namespace may not be interoperability-enabled
**When** the credential ladder resolves
**Then** the environment-variable rung works and the IRIS-credentials rung is **not offered**, rather than offered and failing.

**Given** `/api/admin`
**When** it is probed on that image
**Then** its presence and version are confirmed, or the incompatibility is documented.

**Given** this check runs **after** the 2026-09-27 application floor is built, by owner decision
**When** it is scheduled
**Then** the risk of a late failure with little time to react is recorded as accepted, not discovered.

---

## Epic 17: The Open Exchange listing and the contest submission

A judge finds OcuPilot on Open Exchange, follows a README whose install steps work the first time on a clean machine, and reads a walkthrough that shows what an agent write looks like even without an API key. **Floating** - not a build step and not sequenced against one. It runs when the owner decides to release, which is why it sits after the polish week: nothing it publishes should depict a build that is not yet finished.

**Ordering note.** This epic is triggered by the **owner's release decision**, not by a date and not by a preceding epic. Placed here it has **no forward dependency at all** - every screen, every agent write and every polish-week item its walkthrough might show already exists by the time it starts, so no story below carries a "given some later epic has landed" precondition, and nothing else in this document waits on it.

**What floating does not move.** The contest calendar is external and fixed. Each story below names the bound it must respect and what is forfeited if the release decision falls after it. A late release does not shift a bound; it loses what the bound was buying - a higher listing position, an unforced description, or the entry itself.

### Story 17.1: The public repository and the Ideas Portal idea

As a judge,
I want the project to be open source under a licence I can read, with a linked idea explaining what it is for,
So that the contest's hard requirements are visibly met before I install anything.

**Acceptance Criteria:**

**Given** the repository
**When** a judge opens it
**Then** it is public on GitHub, carries the MIT licence file, and contains no obfuscated source.

**Given** the contest terms' intellectual-property clause
**When** it is read against the licence
**Then** it is a nonexclusive promotional licence, compatible with MIT - recorded so the question is not re-opened.

**Given** the Ideas Portal
**When** the idea is posted, at or before the release
**Then** it describes OcuPilot and its URL is the link the README requires - and because the README cannot be complete without it, it is the earliest thing in this epic.

**Given** team profile links are applicable
**When** the listing is prepared
**Then** they are present.

### Story 17.2: A README whose install steps work the first time

As a judge with thirty minutes and a laptop,
I want to clone, run one command, and reach a working portal,
So that I never have to work out what the author forgot to write down.

**Acceptance Criteria:**

**Given** a clean machine with Docker and nothing else
**When** a reader follows the README's installation steps exactly
**Then** they reach a signed-in OcuPilot without a workaround, and the steps are verified by running them on a clean machine rather than by reading them.

**Given** the README
**When** it is read
**Then** it is in English, describes the product, states the platform floor (IRIS Community and IRIS for Health Community, 2026.2 or later), and links the Ideas Portal idea.

**Given** the `_SYSTEM` password expiry that a fresh Community container ships with
**When** the README's install path runs
**Then** the installer has already cleared it, and the README says so - the expired-password screen stays documented because other users can still meet it.

**Given** the installer enables auditing and registers OcuPilot's audit event types
**When** the README describes install
**Then** it documents that as a deliberate security-posture change rather than leaving an operator to discover it.

**Given** the README is tagged at the release
**When** the listing is prepared from it
**Then** its content is already final enough to link, because the listing quotes it rather than duplicating it.

### Story 17.3: The Open Exchange listing, submitted for review

As the builder,
I want the listing published before the application is made,
So that the contest's own submission mechanics are satisfied rather than raced.

**Acceptance Criteria:**

**Given** the listing build - build steps 0 and 1, plus the README
**When** it is published
**Then** it is submitted for Open Exchange review **before any application is made**, which is the contest's own ordering requirement and the one bound in this epic that no release timing can reorder
**And** the earlier the release, the higher the entry sits on the contest page - which is what a late release forfeits.

**Given** a screens-only build
**When** it is listed
**Then** that is admissible **for the listing**, and the fact that it is not admissible for the application is recorded against the 2026-09-27 floor.

**Given** the compose file
**When** the listing is published
**Then** the image tag it pins is the exact tag this build was tested on, re-pinned at every subsequent publish, so a judge pulling during the voting week gets the build that was tested.

**Given** the smoke script
**When** any publish is prepared
**Then** it has passed on a clean container first - a publish is gated on it, not merely accompanied by it.

### Story 17.4: The contest application

As the builder,
I want the application made as soon as the owner releases,
So that nothing depends on a last-day submission.

**Acceptance Criteria:**

**Given** applications open at the 2026-09-14 kick-off, and the listing is already live
**When** the owner releases
**Then** the application is submitted through the contest tab
**And** if the release falls at or near 2026-09-27 23:59 EST, that is the hard deadline after which the entry does not exist - the one bound with no partial credit.

**Given** the kick-off webinar
**When** it is attended
**Then** the four live external questions are asked and their answers recorded: which technology bonuses apply to contest 48; whether an entry covering only some of the six areas is accepted; InterSystems' support stance on `/api/admin` and whether Group by ID and the browser-id cookie survive future releases; and Freshmen eligibility
**And** the bonus answer re-plans Epic 13's optional items, because the Full Stack 2026 precedent carried no Angular, AI or REST bonus and may not hold.

### Story 17.5: Continuous visible improvement to the deadline

As a voter watching the contest page,
I want to see the entry visibly improve between its listing and the deadline,
So that it reads as a live project rather than a single drop.

**Acceptance Criteria:**

**Given** the period from 2026-09-14 to 2026-09-27
**When** the published build is compared across it
**Then** it has improved visibly, with each publish gated on the smoke script and the image tag re-pinned.

**Given** the voting week, 2026-09-28 to 2026-10-04
**When** each day passes
**Then** at least one user-visible change has shipped that day.

**Given** any publish
**When** it lands
**Then** it has not broken a Release 1 screen or a Release 1 agent write - anything that risks either waits for Stage 2.

### Story 17.6: The walkthrough a judge without an API key can still read

As a judge who will not paste an LLM key into an unfamiliar tool,
I want to see exactly what an agent write looks like from the README,
So that the entry's central claim is legible to me even though I will not run it.

**Acceptance Criteria:**

**Given** Epic 5 has landed and a confirmed agent write is reproducible
**When** the walkthrough is written
**Then** it carries UJ-2 (install, the first-login gate, Test connection, Save) and UJ-3 (the disabled web application, the proposal card, Confirm, the highlighted row, the marked audit event) with screenshots at each step.

**Given** each provider OcuPilot ships
**When** the README describes getting started
**Then** it carries a "get a key in two minutes" section for that provider.

**Given** no hosted demo instance ships, at any point
**When** the judge-without-a-key path is assessed
**Then** the screenshots and the per-provider key guidance are the whole mitigation, and that is a recorded owner decision rather than an omission.

**Given** the walkthrough's screenshots
**When** they are captured
**Then** the panel is not showing the "Agent writes are not being marked" banner, because the installer has enabled auditing - the banner must never be the panel's first words in a published screenshot.

### Story 17.7: The demo freeze and the final submission

As the builder,
I want the demo path frozen before the description and any video are made final,
So that a late change cannot silently invalidate what a judge is shown.

**Acceptance Criteria:**

**Given** 2026-09-23
**When** the freeze takes effect
**Then** anything landing after it that touches UJ-3 forces the description, and any video, to be redone - and that is treated as a cost, not a formality.

**Given** the 2026-09-27 application floor
**When** it is assessed before submission
**Then** build steps 0 to 4 are complete; at least one create or edit form per area from step 5 exists; no list screen in the six areas links out to the classic portal; each of the six areas has at least one live-backed list **and** at least one agent-proposed, user-confirmed write; and the UJ-3 demo reproduces end to end on a clean install
**And** if any of those is unmet, the entry is below the floor the contest rules reject, and that is stated plainly rather than submitted around.

**Given** 2026-09-27 23:59 US Eastern
**When** it arrives
**Then** the application is in, the description is final, and a video is linked if one was recorded - the video being optional by owner decision.
