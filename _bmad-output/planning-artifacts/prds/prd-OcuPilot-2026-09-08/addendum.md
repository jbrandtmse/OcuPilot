---
title: 'OcuPilot PRD addendum'
status: final
created: '2026-09-08'
updated: '2026-09-08'
---

# OcuPilot PRD addendum

Depth that belongs downstream, in architecture, UX and epics, or that earned a place but does not fit the [PRD](prd.md). Citations refer to `research.md`, `feature-catalog.md` and the digests under `_bmad-output/planning-artifacts/research/technical-ocupilot-portal-feature-landscape-2026-09-08/`, and to the [brief addendum](../../briefs/brief-OcuPilot-2026-09-08/addendum.md), which holds the eight inherited decisions and the naming rules.

**Routing.** Architecture: sections 2, 3, 4, 6, 7 and 13. UX: 7 (header strip) and 8. Stories and build: 3 (the write-payload directive), 5, 10, 11, 12 and 15. Contest: 9 and 14.

## 1. Decisions made during the PRD

Read first: decision 22 (the build order is the cut line), decision 21 (the safety invariants), decisions 1 and 2 (instance-level agent definitions and switches) and decision 20 (the first-login gate is bypassable). The rest are recorded in the order they were made.

The decisions below were set by the owner on 2026-09-08 while the PRD was drafted.

1. **Agent configuration is instance-level and shared.** Named agent definitions are stored on the instance and managed by users holding the OcuPilot administrative resource; every user can select among enabled definitions. The first-login gate fires when no definition is enabled. One key per provider, referenced by the definition, never shown back. Rejected: per-user definitions (every new user hits the gate, keys multiply) and instance defaults with per-user override (more screens than 19 days allow).
2. **Switches: administrator plus user.** The kill switch and enforced read-only mode are instance-wide and require the OcuPilot administrative resource. Read-only mode is also a per-user toggle in the panel (the per-user toggle is deferred to step 7, decision 22). Rejected: instance-only (a cautious administrator cannot restrain their own session) and per-user-only (no enforcement for production shops).
3. **User journeys are drafted, not narrated.** Six named-protagonist journeys were written from the demo criteria, the two arrival paths in the auth spike and the catalog rows, and tagged for the owner's correction.
4. **The PRD plans through parity.** Release 1 is P0 plus the P1 polish week for the contest; Stages 2 through 6 outline the path to full parity for incremental delivery, following the catalog's tiers and the brief's post-contest sequence.
5. **The catalog's sizing is authoritative.** The brief and the research summary say 22 large P0 rows; the catalog rates 12 (11 distinct). The PRD uses the catalog's figure and carries the discrepancy as an open question (closed at finalize, decision 18).
6. **Logo.** The web-optimized PNG at 360 px wide, the same convention as the README, at the top of the PRD.
7. **Streaming stays last in the agent's growth.** The brief orders single writes, guided workflows, undo, then streaming; the PRD places streaming in Stage 5 accordingly and carries the research's case for Stage 2 as Open Question 14. Rejected for now: reordering the owner's sequence on the research's insight alone. **Superseded 2026-09-08:** the owner moved streaming into the polish week, conditional on build step 7 finishing and ranked after FR-70 and FR-71. It is neither Stage 5 nor Stage 2. The brief's growth order now diverges from the PRD on this one item.
8. **Analytics rides on Stage 4.** The brief names no Analytics stage; the nine P2 analytics rows share the interoperability stage's namespace gating and official routes, so they ride there and can be split out later.
9. **No agent picker in Release 1.** The catalog places the picker at P2 (Stage 3); Release 1 uses the default enabled definition.
10. **Assumption review.** The owner confirmed as written: the drafted journeys; the egress line being polish-week; disabled-with-tooltip gating; refresh pausing under an open proposal; advertising all tools and gating at call time; the installer reporting the gateway timeout; self-protection of OcuPilot's web applications; the warnings on disabling the web service and on disabling auditing; the untrusted-content boundary in Release 1; WCAG 2.1 AA and keyboard as the accessibility floor.
11. **Responsiveness.** The agent's first visible progress target is 10 seconds against a current cloud model, not one second; model latency is outside OcuPilot's control and local models may be slower. Screen-side targets stay at two seconds.
12. **Browsers.** Chrome is supported and tested; Edge, Firefox and Safari are best effort and untested.
13. **Platform floor.** IRIS 2026.2 or later, because it is the only version available to test against. The harvested agent core's 2024.1 floor is moot.
14. **Transcript visibility.** Users see their own transcripts; OcuPilot administrators see every user's.
15. **Usage analytics is Stage 2 or later.** Token metering (CP-28) leaves the polish week; the ledger still captures usage per call from Release 1 so the later report has data.

    **Assumptions review record.** No open assumptions remain. The fifteen assumptions in the reviewed PRD draft were resolved by the owner on 2026-09-08: eleven confirmed as written (decision 10), and four replaced by the decisions now stated in PRD NFR-1 (ten-second first-progress target, model latency outside OcuPilot's control; decision 11), NFR-11 (Chrome supported, other browsers best effort; decision 12), NFR-13 (IRIS 2026.2 or later; decision 13) and FR-72 with section 7.2 (administrators see every transcript; decision 14). The same review moved usage analytics out of the polish week (decision 15). The safety review at finalize later moved the provider and host disclosure into Release 1's context chip (FR-11; decision 21), superseding the UJ-4 confirmation that it was polish-week. An earlier assumption about an agent picker in Release 1 was withdrawn when the catalog placed it at Stage 3 (decision 9).
16. **Reconciliation with the brief (finalize).** Outcomes (`reconcile-brief.md`): server-side confirmation in Release 1, not deferred to the polish-week governance policy; kill switch off by default; the unconfigured state before the first agent definition is a separate state, not a switch; daily improvement measured over the voting week, with visible improvement between listing and deadline, not a daily quota; a fourth custom endpoint, the alerts.log tail, kept (section 3); the glossary separates the audit database from the agent audit ledger and defines conversation and transcript.
17. **Reconciliation with the idea document and README (finalize).** Outcomes (`reconcile-idea-readme.md`): the agent is the main editing conduit in Release 1, every write has a write tool, and the write tool of a large editor that is cut still ships with the agent core (FR-9, PRD section 10.1); the API preference order (PRD section 8) lets the admin API override the idea document's preference for documented APIs; embedding does not apply to the six areas, since the vendor's embeddable editors are all interoperability editors; agent definitions carry the harvested core's per-definition read-only flag and transcript retention period; provider families are extensible; install targets `HSCUSTOM` if present, else `USER`, on the IPM path too; a newer image upgrades an existing durable volume; install and tests coexist with the iris-execute-mcp-v2 suite on one instance; license MIT, subject to Open Question 9.
18. **Reconciliation with the research (finalize).** Outcomes (`reconcile-research.md`): FR-18 requires long turns to survive the 60-second access token, mechanism left to architecture (section 2); FR-3 and FR-4 acknowledge that the admin API authorizes by `%Admin_*` only, so users without such a resource are told so and the classic portal's finer gates are not reproduced; FR-1, FR-2, FR-9 and UJ-1 no longer assert that OcuPilot's login signs in the classic portal (Open Question 15) — **reversed 2026-09-08**, when a configuration probe showed `/csp/sys` shares `GroupById = %ISCMgtPortal` with `/api/admin` and `/ui/interop`, so those requirements now do assert it, with the two caveats recorded at FR-1 and FR-2; the agent marker (FR-22) is OcuPilot's own audit event beside the IRIS system event, since the admin API's events cannot be altered; the proposal card shows how to reverse a change where a reversal exists; plain IRIS Community is Open Question 16; the "22 large rows" figure is closed as a research prose error; the system-requirements floor in section 6 matches NFR-13.
19. **Reconciliation with the catalog (finalize).** Outcomes (`reconcile-catalog.md`): write tools cover every write action, including deletes on rows the catalog tags as read (SS-04, SS-07, LG-04); the application error log delete is the Logs area's confirmable write for SM-3; read tools include the three shell reads; the build order (PRD section 10.1) places every P0 write row: auditing on and off, the OAuth 2.0 deletes, on-demand run and error deletes in step 4, X.509 import and audit event configuration in step 5; the selective SQL auditing wizard is named in FR-47; the LDAP and device editors use the exported Zen classes as field lists; FR-76 carries the catalog's caveat about the admin API's asynchronous tasks; the catalog's REST-path inconsistency is resolved to `/api/ocupilot` (section 6).
20. **Two held reconciliation questions, answered by the owner.** The first-login gate is bypassable: an OcuPilot administrator may leave configuration and use the screens, with a persistent reminder banner in the panel until a definition is enabled (softer than the brief's "before the portal opens"). The Developer Community article and the online demo stay optional polish-week bonus items, as the catalog places them; the brief's scope sentence listing them among deliverables is read as optional. **Superseded 2026-09-08 for the demo:** no online demo instance ships at any point, so PK-19 leaves the deliverable set entirely rather than remaining an optional bonus. The article stays optional.
21. **Agent-safety review (finalize).** Fifteen critical and high findings (`review-agent-safety.md`) were folded into the requirements as added precision, now in PRD 5.3, 7.1, 7.3 and NFR-6: proposals server-minted, single-use, expiring, user- and conversation-bound, executed from stored arguments, diffed on the instance and re-checked against the target before writing; secret fields excluded from screen context and model arguments, entered masked at confirmation; typed target name for destructive tools; no remote resource in the reply renderer; allow-listed routes only for navigation tools; NFR-6 restated as assumed model compromise plus invariants and a seeded-injection test; switches and privileges evaluated before every provider call, tool call and confirmation, every switch or definition change audited; agent marker emission checked, absence surfaced; OcuPilot's persistent state protected from ordinary database access; the OcuPilot API carries no application or matching roles and gates the turn endpoint; per-user turn limits in Release 1; a named Release 1 prohibited set. Three facilitator judgments within those findings: the provider and host disclosure moved into Release 1's context chip; administrators see tool results in another user's transcript only with the privileges those tools required; loopback and private-network endpoints stay allowed because local models are a supported case.
22. **Feasibility review and contest scope (finalize).** The reviewer costs the specified work at about 45 developer-days against 19 (section 15). The owner keeps all P0 rows as the commitment, demo video optional, and makes the build incremental: PRD section 10.1 is the build order and the cut line (dated first-week decisions, demo freeze 2026-09-23), and PRD section 1.1 states the commitment, the listing build 2026-09-14 and the application floor 2026-09-27. Step 7 trims: the per-user read-only toggle (amending decision 2; the enforced instance-wide state stays in the floor); the OpenAI, Google Gemini and OpenAI-compatible adapters, so Release 1 starts with Anthropic while the brief's four-provider set holds for Release 1 as a whole; the remaining hardening from decision 21 (fingerprint re-read, typed-name confirmation, per-user turn limits, seeded-injection test). Navigation tools stay in the floor. The OAuth 2.0 editors stay in the polish week; the contest reviewer's "OAuth setup absent at the deadline" risk is accepted and recorded. Judge path: key guidance in the README and a walkthrough with screenshots; no local-model Compose profile, no hosted demo; article and video optional. Tool transport is Open Question 17, due 2026-09-09; Open Question 6 is closed because the endpoint classes read back from the instance.

## 2. Authentication mechanism, for architecture

The PRD states the behavior (FR-1, FR-2, NFR-3). The one open decision comes first; the transport facts below it are from the auth spike (`digests/auth-spike-r2-1.md`, rows cited):

- **Token lifetime versus turn duration (open for architecture; Open Question 17, due 2026-09-09).** Tokens minted by `/api/admin` live 60 s; a turn may run to the 90 s provider timeout and the 300 s gateway timeout, and FR-18 requires tools to call the admin API with the user's own token. Candidate resolutions: mint the shell's token pair from `/api/ocupilot/login` with a longer access timeout, since any JWT-enabled application accepts it; refresh the pair on the instance during the turn; or execute tools in-process under the user's session so no HTTP hop needs a token. FR-18 states the requirement; this is the decision to make. **Closed by the architecture spine:** the third option was taken. Tools run in-process, so no HTTP hop inside a turn needs a token and the mismatch disappears rather than being managed. The proposal to raise the access timeout to 300 s is dropped and the vendor-matching 60/900 is kept; token refresh becomes a background concern of the API service.
- **Carrier.** A `CSPBrowserId` cookie (`path=/`, httpOnly, SameSite=Strict, no expiry) is issued by any JWT login on a JWT-enabled application and by a classic portal login that goes through the CSRF-token path (a form POST without the hidden `IRISSessionToken` field logs in but is not issued a browser ID; rows 24 to 26).
- **Minting.** An empty-body `POST <jwt-app-root>/login` with that cookie returns a fresh token pair for the same user, but only if the JWT application carries the same `GroupById` as the application that issued the cookie (rows 17 to 19, 27). Members of `%ISCMgtPortal` on the research instance: the classic portal, `/ui/interop`, `/api/admin`, `/api/interop-editors`, `/api/security-config`, the FHIR management API and the two OAuth2 API applications.
- **Authorization.** Only `Authorization: Bearer <access>` authorizes a data call; cookies alone never do (`UseSession=0`). Any JWT-enabled application accepts any valid unrevoked token from the instance regardless of group or `app` claim (rows 5, 13, 15). `/api/atelier` and `/api/mgmnt` accept only Basic or their own session (row 6).
- **Tokens.** ES256. Access lifetime 60 s, refresh 900 s, set by the issuing application's timeouts. Refresh is `POST <root>/refresh` with JSON `{"refresh_token"}`; a refresh token sent as a Bearer is refused (rows 7, 8). The vendor's bundles refresh at `exp − iat` minus a cushion and retry once on 401.
- **Ending.** `POST <root>/logout` with the Bearer and the cookie ends the browser-level login for every in-group application (row 23); Bearer-only logout leaves the cookie valid (row 22). The classic `?IRISLogout=end` ends it too (row 28).
- **Embedded editors.** Loaded same-origin in an iframe in normal mode, they mint from the cookie with no host involvement and keep their tokens in the frame's `sessionStorage` (rows 31, 38, 41). `VSCODE=1` mode suppresses their login and expects an `auth` postMessage carrying the password, which then crosses into the frame and onto the wire (row 33); the postMessage contract has no origin check. Untested alternative: pre-write the frame's `sessionStorage` keys before loading `?VSCODE=1`.
- **Development.** `CSPBrowserId` is SameSite=Strict, so an `ng serve` on another port will not carry it; local development must proxy through the IRIS origin.
- **Unobserved direction.** The spike observed that a JWT login issues the browser ID and that the vendor's editors then sign in silently. It did not observe the classic portal picking up that browser login, nor the classic portal's session ending on OcuPilot's sign-out. This is Open Question 15, which is not on the critical path: the form login covers the judge's arrival. **Closed 2026-09-08 without a browser test:** `/csp/sys` shares the `%ISCMgtPortal` group with `/api/admin` and with `/ui/interop`, the very application the spike watched sign in silently, so the same mechanism reaches the classic portal. The sign-out direction carries a caveat — `/csp/sys` also permits unauthenticated access, so the authenticated session ends without a login form necessarily appearing.

**Recommended web application settings** (spike §7, Rec 3):

| Setting | `/ocupilot` static shell | `/api/ocupilot` REST |
| --- | --- | --- |
| Type | CSP, `ServeFiles=1`, path = built bundle | REST, `DispatchClass` = the `%CSP.REST` subclass |
| Namespace | `HSCUSTOM` if present, else `USER` | same |
| `AutheEnabled` | 64 (unauthenticated static, like `/ui/interop`) | 32 (password) |
| `JWTAuthEnabled` | n/a | 1 |
| Token timeouts | n/a | 60 / 900 to match the vendor — decided; the "raise access to 300" alternative is dropped, since in-process tools need no token mid-turn |
| `GroupById` | not needed | `%ISCMgtPortal` (silent-first design) |
| `UseSession` | n/a | 0 |
| `CSRFToken` | 0 | 0 |

**Rejected alternative: Design B, JWT-only.** The shell always shows its own form and OcuPilot's REST application does not join the group. It costs one extra login for portal-first users and removes OcuPilot's own dependency on Group by ID; the embedded editors still sign in silently because their API is in the vendor's group. Kept as the fallback the PRD's FR-1 already provides.

## 3. API backing per area, and what is unverified

| Area | Backed by | Unverified or custom |
| --- | --- | --- |
| Web applications and REST explorer | admin API web-apps; management API discovery and documents | web-apps routes are UrlMap-only, not confirmed by the OpenAPI scan; management API refuses one vendor spec |
| Permissions | admin API users, roles, resources, services | SQL privileges UrlMap-only (Stage 2, not Release 1) |
| Security and secrets | admin API SSL, X.509, OAuth 2.0 server/client/resource server, wallet, LDAP, audit | X.509 backing class not identified; wallet has no SMP page, no MCP tool, no observed payloads |
| Tasks | admin API tasks, run, suspend, resume, history, upcoming, manager | task wizard and edit-task fields come from `%SYS.Task`, the model the classic pages edit; their own source is unrecoverable (Open Question 7) |
| OS management | admin API processes, system usage, dashboards, locks, databases, devices; monitoring API metrics | `POST /database-dir/info` is asynchronous with unverified polling semantics; dashboard meter names not captured |
| Logs | monitoring API alerts; admin API audit records | messages.log and application errors have no route and no confirmed backing class; alerts history is a custom file tail |

**Every admin API write payload is unobserved.** The epics should make "exercise the payload on the instance" the first task of every write story. **Superseded by the architecture spine:** the endpoint classes publish a body-template method, so write-tool field names and types are generated from it and an endpoint-inventory fixture verifies the set once, in CI, for every endpoint. Per-story probing is dropped. Two residues remain for the epics: the templates give no required-ness, enumerations or descriptions, so each tool's semantic half is authored once; and sixteen mutating endpoints publish no template, five of them in Release 1, which are the only rows below still genuinely unverified. Release 1 rows built against an unverified write contract: WA-02 to WA-05; PM-02 to PM-07, PM-09 to PM-12, PM-14, PM-16; SS-04, SS-07, SS-09 to SS-13, SS-15, SS-16; TM-02, TM-06 to TM-10, TM-12, TM-13; OS-02 to OS-04, OS-07, OS-10, OS-12; and CP-13 wholesale. Observed exceptions: the login, refresh and logout POSTs.

**Custom endpoints in Release 1** (OcuPilot API): the agent runtime (roughly seven: run turn, progress channel, load transcript, lock state, agent definition CRUD including the read-only and kill-switch state, credentials list, tool list; the progress channel is polling or server-sent events so the panel can render tool-call cards while a turn runs), messages.log paging and the application error log. Those are the brief's three. The catalog adds a fourth, the alerts.log history tail (LG-01), because the monitoring route returns only entries since the last scrape; it is small and is kept. Build them into OcuPilot's own `%CSP.REST` dispatcher on the iris-couch patterns, not the MCP suite's `%Atelier.REST` envelope.

## 4. Tiered autonomy, in detail

From the practitioner framework the research cites (D8 [43]) and the sibling governance model (D6b):

| Level | Meaning | Release 1 |
| --- | --- | --- |
| L0 Observe | read tools, screen context, explain | always on |
| L1 Recommend | the agent proposes and explains; no execution | always on; copy-out drafts in the polish week |
| L2 Bounded action | machine-checkable preconditions, resource limits, abort criteria | folded into L3: every write needs confirmation |
| L3 Human authorization | propose, review, confirm; one confirmation per proposal | the only write path |
| L4 Prohibited | outside the agent's credentials entirely, never advertised as a tool | Release 1 set, refused on the instance: deleting or disabling the current user, the last `%All` holder or `_SYSTEM`; disabling the web service serving OcuPilot; terminating IRIS system processes; deleting OcuPilot's own web applications, resource or role. Later stages add deleting backups, dropping databases, purging journals, wiping production data |

Server-side enforcement of the confirmation is Release 1 (FR-17): the write path on the instance refuses a write tool call that does not carry a confirmation bound to its proposal, in the manner of iris-execute-mcp-v2's `dryRun:false` plus `confirm:true` double gate. The rest of the governance model to copy for the polish week (CP-33): `tool` or `tool:action` keys with a frozen baseline where new write keys are disabled by default; a cascade of environment, file, preset and default; a read-only preset; a call-time gate returning a structured `GOVERNANCE_DISABLED` result while tools stay advertised; "recover before clean"; a secrets-redacted audit log that governance cannot disable.

## 5. Harvest map

| Source | Reuse as-is | Adapt | Do not inherit |
| --- | --- | --- | --- |
| iris-session-agent | provider base and the four adapters; message and tool-definition adapters; secret resolution; retry with backoff; tool base classes and reflection registry; the 28 read-only interoperability tools (Stage 4) | agent loop, caller context and turn result (add progress, key on screen context, remove hard-coded agent names); agent config, history with per-conversation locking, sweep tasks, audit ledger; the config form's 11 validation rules and provider cascade; citation chips, lock banner, config-empty state, vendored Markdown pipeline | its synchronous loop as the final shape; its Zen chat panel; its `%Ens_Portal`-only view gate; its hard-blocking of every mutating tool; its hard-coded `DefaultSSL` and lack of proxy support |
| iris-execute-mcp-v2 | the governance model; handler bodies for security, interop, monitor, config, task and system-config (the custom-REST list, handler for handler) | the composite health check and message-trace generator (Stage 4 and 5) | the `%Atelier.REST` envelope; the TypeScript-driven self-install; the stale IPM manifest; the `%Development`-gated web application pattern |
| iris-table-editor | SQL builder, type formatter, URL builder, models (Stage 3) | Atelier service, query executor and metadata service (need an explicit Basic header or a route through the OcuPilot API); the `--ite-*` theme tokens as a theme bridge; export and import | the VS Code, Electron and Express hosts; the 7,600-line vanilla DOM grid (harvest the keyboard model, filters and staging logic only) |
| iris-couch | error and response envelope; `Audit.Emit` with the structured logger; the HTTP unit-test harness and no-double-envelope assertion | the `%CSP.REST` router with thin wrappers; the `OnPreDispatch` seam; the static SPA handler with deep-link fallback, path-traversal checks and cache headers; the idempotent installer; the Prometheus collector | its cookie session (no CSRF, SameSite or Secure flag, no CORS); its per-database RBAC; the mount path baked into four places |

**New for OcuPilot:**

- **Shell.** The Angular shell and every screen; silent-first sign-in and the group membership; the admin API version guard; screen synchronization and agent-driven navigation; screen context with toggle; the first-login gate.
- **Agent surface.** The agent REST surface; the rename of the harvested core away from every sibling name (about 26,000 lines of sibling tests are bound to those names and are not reusable); the two log endpoints; progress delivery; test connection; one read tool per screen and write tools per action; context-window trimming; the untrusted-content boundary; proxy and custom-CA support.
- **Write model.** The proposal store and confirmation lifecycle; the write model (propose, review, confirm; run as user; read-only mode; kill switch; L4 outside reach); the agent marker.
- **Install.** The IPM module, Dockerfile and idempotent installer; the deep-link static handler; an uninstall hook.

## 6. Install and packaging mechanics

- **IPM module.** `<WebApplication>` plus `<FileCopy>` for the built bundle, a second `<WebApplication>` with a dispatch class, `<SourcesRoot>src</SourcesRoot>`, `<Resource>` for the package, an `<Invoke>` for the installer, `<SystemRequirements>` for IRIS 2026.2+ per NFR-13 (IPM's own floor is 2022.1) and for IPM 0.10.x, and `${globalsDbRole}`. Avoid `<CSPApplication>` (deprecated since IPM 0.9.0 though both InterSystems templates still use it) and `${dbrole}`.
- **IPM state.** 0.10.x line; since 0.9.0 IPM is per-namespace, so `zpm` may not exist in `HSCUSTOM` on a Community image. Install it there or map it globally. Whether the `intersystemsdc` images still ship IPM preinstalled is unverified.
- **Namespace choice** ("HSCUSTOM if present, else USER") belongs in `iris.script` or an installer method, not in `module.xml`, because the manifest is evaluated after the namespace is fixed.
- **Docker (open for architecture; Open Question 5).** Both vendor templates install during `docker build` (start IRIS, pipe `iris.script`, stop IRIS); the 2026 template adds a CPF merge. This repository uses durable `%SYS` (`./iris-data` to `/durable`, `ISC_DATA_DIRECTORY=/durable/iris`) and the idea document wants install on container start. No source shows the build-time pattern working against a durable volume. Proposed reconciliation: the IPM module as the single source of truth, loaded at build time, re-checked by an idempotent installer at start. The architecture settles this before the Dockerfile is written.
- **Serving the SPA.** Static bundle in a CSP directory with `ServeFiles`; separate password-authenticated REST application; deep links for client-side routes through a `%CSP.REST` catch-all GET that rewrites non-asset paths to `index.html` on a web application with both a physical path and a dispatch class; base href set at build time; "Serve Files Always" in development to defeat gateway caching; immutable cache headers for hashed assets, no-cache for `index.html`.
- **Pitfalls.** Gateway serving stale files; deep links returning 404 on a serve-files-only application; the portal hiding the physical-path field once a dispatch class is set; the expired `_SYSTEM` password on Community images surfacing as HTTP 401; the Web Gateway possibly returning 404 for a newly created application until saved once or restarted (did not occur in the spike).
- **Web Gateway timeout.** The harvested agent loop has a 90 s provider timeout and calls for a 300 s gateway timeout. The installer reports the current value. **Superseded by the architecture spine:** the turn runs in a background job and the request returns immediately, so nothing holds a connection for a turn's length and the 300 s figure is no longer needed. The stock 60 s suffices, the installer's report becomes information rather than a prerequisite, and the Docker image no longer sets it (FR-23, FR-67).
- **Protecting OcuPilot's state (FR-29, FR-66; open for architecture).** The install namespace's default database is writable by every developer on the target instances, so definitions, switches, the ledger, transcripts and proposals cannot live there unprotected. Candidate: a dedicated OcuPilot database guarded by a dedicated resource no ordinary role holds, with OcuPilot's globals and packages mapped into it; the OcuPilot API reaches it through an escalation confined to its storage methods and never in effect while tool, admin API or provider code runs. The FR-29 test (a `%DB_HSCUSTOM:RW` plus `%Admin_Operate` holder without the OcuPilot resource can neither read nor write any OcuPilot table or global) is the acceptance criterion, whatever the mechanism.
- **Names to avoid.** Sibling names OcuPilot must not inherit, by kind; the last row is what OcuPilot uses instead.

| Kind | Avoid |
| --- | --- |
| Packages | `SessionAgent.*`, `ExecuteMCPv2.*`, `IRISCouch.*` |
| Web paths | `/csp/<ns>/sa-static/`, `/api/executemcp/v2`, `/iris-couch/` |
| Roles | `SessionAgent_ReadOnly`, `IRISCouch_Admin` |
| Audit sources | `SessionAgent`, `IRISCouch` |
| Globals | `^SessionAgent.*`, `^IRISCouch.*`, `^UnitTestRoot` |
| Credentials | `SessionAgentOpenAI/Anthropic/Gemini` |
| Tasks | `SessionAgent.Purge*`, `SessionAgent.UserVocabularyDecay` |
| Mappings | `%ALL` mapping creation |
| SQL procedures | `ExecuteMCPv2.Setup_*` |
| Tool prefix | `iris_*` |
| Environment variables | `IRIS_*` |
| **OcuPilot uses** | package `OcuPilot`; web applications `/ocupilot` and `/api/ocupilot`; ObjectScript under `src/OcuPilot` |

The catalog is inconsistent on the REST path (PK-07 says `/ocupilot/api`, PK-12 says `/api/ocupilot`); the PRD uses `/api/ocupilot`, which matches the auth spike's recommendation and the vendor's `/api/*` convention.

## 7. Portal mechanics a replacement must reproduce

- **Resource gates.** Configuration and Licensing need `%Admin_Manage:USE` plus READ and WRITE on `%DB_IRISSYS`; Security needs `%DB_IRISSYS:READ`; Encryption `%Admin_Secure:USE`; Journal Settings `%Admin_Journal`; OAuth 2.0 pages `%Admin_OAuth2_*`; System Operation is invisible without `%Admin_Operate:USE`; Task Manager and Diagnostic Reports need `%Admin_Task:USE`; Explorer `%Development`; Interoperability `%Ens_Portal`; Analytics `%DeepSee_Portal`. The classic portal infers resources from the URL path prefix plus a per-page custom resource overlay assignable by `%Admin_Secure` holders.
- **Custom resource keys.** Custom portal resources are keyed by normalized classic page URL. OcuPilot's routes must map back to those keys, or existing assignments are lost. Relevant to FR-4.
- **Edition and feature gating** is runtime: sharding disabled unless licensed (not on Community); mirror menu leaves depend on service state; Windows-only and VMS-hidden items.
- **Long-running work** in the classic portal goes through `%CSP.UI.System.BackgroundTask.RunTask` with a 44-entry allow-list and progress in `^IRIS.Temp.MgtPortalTask`; the admin API's `/async-results` tracks its own async tasks, not the portal's. Truncate, mount, dismount, lock removal, process control, session end and deletes are synchronous.
- **Auto-refresh** is a shared feature with a persisted rate, state and sort column, used by Databases, Database Details, Processes, Process Details, Transactions, Mirror Monitor, Task Details, License Usage, Web Sessions and Background Tasks.
- **Namespace switching** lists namespaces the user can read and write; visiting `%SYS` without a parameter redirects to the startup namespace.
- **Directory allow-list** restricts server file paths for every browse, export and import feature.
- **Header strip conventions** users expect: server, namespace with switch link, user with change-password link, escalation role, licensed-to, instance, a Live / Test / Failover / Development badge; a small menu of Home, About, Help, Contact, Logout; a fixed 16-link menu filtered by access; breadcrumbs; per-page ribbon; favorites and recents; "Did you know"; menu-only search; About with 14 fields; Help opening DocBook per page.

## 8. Interaction vocabulary, for UX

From the field survey (D8 patterns 1 to 12) and the session-agent harvest:

- Persistent side panel with full-screen toggle; page-context sharing on by default and toggleable; draft-first copy-out artifacts; propose, review, confirm with rationale and expected impact; "Investigate" entry points on alerts and log entries; pre-populated hand-off forms; an agent picker inside the chat; citations back to the rows used; suggested prompts grouped by task; inline contextual insights beside errors; chat history with a retention policy.
- Not evidenced anywhere in the field, therefore open ground: undo and rollback UI, visual diffs before apply, slash commands, streaming.
- Users praise page context, follow-up memory and precise investigations; the loudest complaints are irrelevance, unreliability, hallucination and "too many steps".
- Harvestable UI details: the 11 validation rules and the provider-change cascade; the config-empty state; the per-conversation lock banner; citation chips; the vendored Markdown pipeline; the 8,192-character system-prompt counter.
- Theming: vendor bundles have fixed theming (Tailwind and Material tokens, Noto Sans) and no license text; reference in place, never copy. iris-table-editor's `--ite-*` token layer is the theme bridge candidate. Dark mode is a repeated community request and a polish-week row.
- Narrow-viewport behavior of the panel below about 900 px (bottom sheet or overlay) is a UX decision.

## 9. Competitive summary

| Product | Acts or drafts | Confirmation | Agent marker in audit |
| --- | --- | --- | --- |
| Azure Copilot agents | acts | approval required; cannot exceed the user's rights | no (acknowledged gap) |
| Amazon Q Developer in the console | drafts only | n/a | not found |
| Google Gemini Cloud Assist | drafts; investigations | IAM role for investigations | n/a |
| Google Database agents | acts with approval, preview | rationale and expected impact before commit | not specified |
| Elastic AI Assistant | executes queries | user's permissions | not specified |
| IBM Db2 Console | assistant | admin-configured provider | meters tokens per user |
| InterSystems | no assistant in the Management Portal; AI Hub in early access | n/a | n/a |

Nearest prior art on Open Exchange: bg-iris-agent (reads portal data, modifies non-critical settings, dormant since 2025-06) and irislab (explicit portal replacement, dormant since 2024-08). Nothing covers the six areas coherently.

## 10. Sizing data

| Area | P0 | P1 | P2 | P3 | P4 |
| --- | --- | --- | --- | --- | --- |
| Shell and navigation | 12 | 11 | 3 | 3 | 1 |
| Agent co-pilot | 24 | 11 | 7 | 1 | 0 |
| Web applications and REST explorer | 7 | 2 | 5 | 2 | 1 |
| Permissions | 16 | 2 | 4 | 2 | 0 |
| Security and secrets | 16 | 11 | 8 | 4 | 1 |
| Tasks | 13 | 3 | 0 | 3 | 0 |
| OS management | 12 | 3 | 9 | 6 | 4 |
| Logs | 4 | 8 | 1 | 1 | 1 |
| Packaging and submission | 15 | 9 | 1 | 0 | 1 |
| External language servers (P1, unmapped) | 0 | 2 | | | |
| Outside the six areas (SA, SO, EX, IO, AN, DT) | 0 | 0 | 99 | 142 | 47 |
| Total | 119 | 62 | 137 | 164 | 56 |

The table shows catalog tiers. After decision 15 (CP-28 to Stage 2), the polish week carries 61 rows and Stage 2 carries 60.

P0 by size: 70 small, 37 medium, 12 large (11 distinct). The twelve (SS-14 and LG-02 are one row): CP-12, CP-13, WA-05, PM-07, PM-12, PM-16, SS-14 (= LG-02), SS-15, SS-16, TM-12, TM-13. P0 tools: 38 read, 37 write-confirm, 44 none. Three deliberate duplicate rows: LG-02 = SS-14, LG-09 = IO-01, EX-01 = SH-03.

## 11. Catalog judgment calls the PRD revisited

- **Locks at P0** although the tier rules put them at P2: kept; both rows are small and process-adjacent.
- **Wallet at P0** on an undocumented route: kept because the contest names it; FR-46 requires the payload probe first.
- **Interoperability and analytics logs at P1** although both need custom endpoints: kept as secondary log viewers.
- **Web sessions at P1** rather than P0: kept; not a web-application list or editor.
- **Memory configuration at P3** while memory monitoring is P0: kept; the contest's "memory" is read as monitoring.

The remaining 23 judgment calls stand as the catalog states them.

## 12. Stages 2 through 6, row detail

The row-level tables for the post-contest stages are in `extract-stages.md` in this folder, produced from the catalog's 357 P2 to P4 rows and the brief's post-contest sequence. The extract numbers the post-contest stages 1 to 5; the PRD numbers them 2 to 6 because Release 1 is the first increment, so extract Stage 1 is PRD Stage 2, and so on. Two placements were made by extension and are flagged there: streaming with undo in the custom-REST stage (decision 7) and the Analytics rows on the interoperability stage (decision 8), both recorded in section 1. The PRD's section 10.3 carries the roll-up; the screen inventory per stage, moved out of it at polish, follows.

**Stage 2, the rest of the admin API.** Every remaining screen the admin API backs: namespaces, databases and every deferred database operation, journals, license, ECP, encryption, SQL privileges, superservers, authentication options and managed file transfer. The agent gains a read tool and a confirmed single-write tool for each, a wallet-backed API key rung, context-window management, proxy and custom-CA support for provider calls, and token usage reporting per turn and per user (CP-28, decision 15).

**Stage 3, System Explorer over the Atelier API.** Classes and routines with source view, compile, delete, export and import and ETag-checked editing; search, compare and macro lookup; the SQL catalog, the guarded query console and plans; the data grid harvested from iris-table-editor; Documatic and DocDB. The agent gains the free-form SQL tool behind the same guard, and a picker among agent definitions so a developer agent and an operations agent can differ by area.

**Stage 4, Interoperability over the interop-editors v7 API.** Production lifecycle and item management, per-host tabs, monitor, queues and jobs, lookup tables, testing, activity charts, the three vendor document editors for rules, BPL and DTL and the production-configuration diagram embedded in place with silent sign-in, schema viewers, and message search, resend and trace. As a rider, Analytics gains cube list, model browser, MDX query tool, term lists, folders and the cube manager. The agent gains guided multistep workflows harvested from the MCP suite's prompts and investigate entry points on alerts and log entries that return a recap and ranked hypotheses.

**Stage 5, custom-REST parity.** Every remaining leaf with a backing class but no route, harvested from the MCP suite's handler bodies into the OcuPilot API: backup and restore, mirroring, locale and SQL and startup settings, globals, statement index and tuning, interoperability credentials, purge, alerts, logs, workflow, deployment, record maps and HL7 authoring, analytics editors, and developer tools. The agent gains the 28 iris-session-agent tools on the interoperability screens, and undo by snapshot and revert. Streaming replies moved to the polish week (decision 7).

**Stage 6, the long tail.** Nothing scheduled. Each excluded row, such as sharding, HealthShare-only screens, shadowing, iKnow, Zen Reports and the device sub-pages, is picked up only when demand appears and its gate clears, and keeps its reason for exclusion until then.

## 13. Full risk register

Condensed from the research's risk table; the PRD's section 11 carries the top 10.

| Risk | Mitigation |
| --- | --- |
| Five admin API sub-areas are UrlMap-only (web applications, external language servers, DocDB, SQL privileges, web-authentication settings) | Treat as unverified until exercised |
| Atelier query executes any SQL under the caller's privileges | DML and DDL guard in OcuPilot for agent and console use (Stage 3) |
| `VSCODE=1` auth message sends the password into the frame; postMessage has no origin check | Normal mode or the untested sessionStorage pre-write; never the auth message |
| Normal-mode editor chrome escapes the frame | Accept, or `VSCODE=1`, which hides the top bar |
| Vendor bundles have no license text and must load from `/ui/interop/...` | Reference in place; never copy |
| Contest terms include an IP grant | Read at finalize: a nonexclusive promotional license, compatible with MIT |
| Cross-origin dev server drops the browser-ID cookie | Proxy development through the IRIS origin |
| Web Gateway may 404 a new web application until saved or restarted | Keep the workaround documented |
| MCP suite manifest is stale; its bootstrap is TypeScript-driven | Harvest handler bodies only |
| Two MCP-suite defects (task-history filter, resource creation with description) have unverified fix status | Read current handler bodies before harvesting |
| Secret handling in the session agent: AES store is a stub, hard-coded SSL configuration, no proxy | Keep the environment-variable and credentials rungs; add proxy and custom-CA |
| iris-couch cookie gaps | Do not inherit; Bearer only |
| Table-editor limits: single-column primary key, identifier regex, `rowsAffected` always 1, `%VID` paging cost | Carry knowingly into Stage 3 |
| Custom portal resources keyed by page URL | Map OcuPilot routes back to classic keys |
| A project rule file claims the interop-editors spec is available from `/api/mgmnt/v2`; it is not | Correct the rule file |
| Community voting favored a recurring cohort in 2026 | Go-to-market in the voting week |
| Classic logout may or may not revoke frame tokens (row 42) | Treat logout-with-cookie as authoritative |
| Reference exports drift from the instance; hidden classes are absent | The instance is authoritative; fetch hidden classes live |
| The research's red-team pass was off | Known limitation; the reviewer gate on this PRD is the compensating check |

## 14. Contest facts

| Item | Value |
| --- | --- |
| Registration and kick-off webinar | 2026-09-14 (webinar 12:00 EDT) |
| Submission deadline | 2026-09-27 23:59 EST |
| Voting | 2026-09-28 to 2026-10-04 23:59 EST |
| Winners announced | not stated |
| Experts prizes | $5,000 / $2,500 / $1,000 / $500 / $300, then $100 for places 6 to 10 |
| Community prizes | $600 / $400 / $100 |
| Freshmen prizes | $600 / $400 / $100; at most five prior contests and no prior top-three finish |
| Judging criteria | Complexity, Clarity of Instructions, Developer Experience, Applicability, Usability |
| Bonus precedent (Full Stack 2026) | Vector Search 3, Embedded Python 3, DC Idea 2, Docker 2, IPM 2, Online Demo 2, Find a Bug 2, First DC Article 2, Second Article 1, YouTube Video 3, YouTube Short 1, First-Time Contribution 3; no Angular, AI or REST bonus |
| Hard requirements | Fully functional; not a thin interface; new or significantly improved; runs on IRIS Community or IRIS for Health Community; open source on GitHub or GitLab; English README with install steps and a video or description plus a link to the idea; at most three submissions; listed on Open Exchange before applying; no obfuscated source; team profile links |
| Field | Empty as of 2026-09-08; prior contests drew 16 to 17 entries |

## 15. Feasibility budget (finalize)

The feasibility reviewer's day budget for one developer, AI-assisted, working every calendar day. The owner kept all P0 rows as the commitment and made the build incremental (PRD, section 10.1); this table is the warning that sits behind that choice. Full review: `review-feasibility.md`.

| Work item | Days | Confidence |
| --- | --- | --- |
| Foundation: Angular workspace, dev proxy, shell, sign-in with refresh, error envelope, header, namespace switch, navigation with gating, chrome, version guard | 3.0 | medium |
| Packaging and install: Dockerfile with the durable-volume decision, IPM module, idempotent installer, SPA serving, REST router, upgrade path, clean-clone smoke | 2.5 | low |
| Admin API contract: export the 82 endpoint classes, tabulate schemas and resources, probe one write per family | 1.0 | high |
| Agent runtime, server: port and rename the core, REST surface, progress channel, lock, proposal store with server-side confirmation, execute-on-confirm, marker, runs-as-user, test connection, switches, provider re-verification | 4.5 | medium |
| Agent panel, Angular: dock, transcript, Markdown, tool-call and proposal cards, lock banner, context chip, states, change-event bus, navigation tools | 3.0 | medium-low |
| Agent configuration screen, first-login gate, switches screen | 1.5 | medium |
| Plain list screens (about 22) with generated read tools | 3.0 | medium |
| Detail and complex reads (about 10, two custom endpoints) | 4.5 | low |
| Small write actions (about 20) end to end | 3.0 | medium |
| Medium editors (10 forms) | 4.0 | low |
| Large editors (8 forms, about 5,400 lines of Zen source to re-express, two from unexported CSP) | 8.0 | low |
| Submission deliverables | 2.0 | high |
| Agent-safety additions from the finalize review | 3.5 | medium |
| Integration, regression and unknowns reserve | 3.0 | |
| **Total as specified** | **46 to 47** | against 19 |
| Steps 0 to 4 of the build order | about 34 | against 19 |
| Application floor (steps 0 to 4 plus one form per area) with the owner's trims | 24 to 26 | closes only with the reserve spent |

The reviewer's costing caveats: about 20 of the 70 "small" rows are write actions needing the whole propose-confirm-audit-refresh path; about 25 are platform or deliverable rows that are not small; CP-12 and CP-13 stand for 75 tools, which is why FR-16 requires them to be generated from endpoint descriptors. "Reuse as-is" from iris-session-agent is about 9,300 reusable lines of a 50,800-line project; iris-couch's Angular app, router, installer and static handler are the genuine head start.
