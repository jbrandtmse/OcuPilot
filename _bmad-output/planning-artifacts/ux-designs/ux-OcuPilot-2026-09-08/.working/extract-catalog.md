# Extract: feature-catalog.md (UX digest)

Source: `_bmad-output/planning-artifacts/research/technical-ocupilot-portal-feature-landscape-2026-09-08/feature-catalog.md` (708 lines, 538 rows, dated 2026-09-08). Captures only what the source states; nothing designed or proposed.

## 1. Catalog shape

**Purpose (as stated)**: one prioritized, exhaustive list of everything OcuPilot could build — every SMP menu leaf, every co-pilot capability, every harvestable sibling-tool feature, every contest deliverable. "The contest MVP (due 2026-09-27) can be cut from the P0 rows alone." Rows are never dropped; excluded items are kept at P4 with the reason stated.

**Row prefixes / areas (15 sections)**:

| Prefix | Section | Meaning |
|---|---|---|
| SH | 0. Portal shell and platform | login, access model, namespace switch, header, navigation, errors, breadcrumbs, command bar, auto-refresh, logout, theme, favorites |
| CP | 1. Co-pilot agent | panel, chat endpoint, agent config, providers, tools, permissions, audit, progress, safety switches, screen sync, agent navigation |
| WA | 2. Contest area 1: Web apps and REST APIs | web application list/CRUD, REST API explorer |
| PM | 3. Contest area 2: Permission management | users, roles, resources, services |
| SS | 4. Contest area 3: Security and secrets | SSL/TLS, X.509, OAuth 2.0, LDAP, auditing config, audit viewer, wallet |
| TM | 5. Contest area 4: Task management | task schedule, on-demand, upcoming, history, details, wizard, task manager |
| OS | 6. Contest area 5: OS management | processes, locks, system usage, meters, databases ("disks"), devices |
| LG | 7. Contest area 6: All the logs | alerts.log, audit DB, messages.log, application error log, secondary logs |
| SA | 8. System Administration, remainder | namespaces, databases config, journal, license, ECP, mappings, NLS, mirror, sharding, reports |
| SO | 9. System Operation, remainder | journals, backup, mirror monitor, shadowing |
| EX | 10. System Explorer and data browser | classes, routines, SQL, data browser (table-editor harvest), globals |
| IO | 11. Interoperability | productions, rules, DTL, BPL, message viewer, event log, Angular editor embeds, 28 session-agent co-pilot tools (IO-91..IO-118) |
| AN | 12. Analytics | DeepSee cubes, MDX, folder manager, text analytics |
| DT | 13. Developer tools and sibling-tool equivalents | DocDB browser, unit tests, terminal, execute command, env diff/promote |
| PK | 14. Packaging, deployment and submission | README, repo, Open Exchange, IPM module, Docker, web apps, installer, bonuses |

**Columns (verbatim)**: ID · Feature (screen or action) · SMP source (page class, or "new") · API backing · Harvest source · MCP tool (iris-execute-mcp-v2 tool name, `tool:action` where only some actions apply) · Tier · Complexity (S list only / M list plus form or dialog / L wizard, editor or console) · Co-pilot tool (read / write-confirm / none) · Evidence (digest file and the row or claim it came from).

There is no "backed by /api/admin" or "classic portal only" column. The equivalent signal is the **API backing** vocabulary: `admin-v2` = hidden `/api/admin/v2` route (`%Api.Admin.Dispatch.v2`, instance-verified, undocumented) · `official-REST` = documented `%Api.*` · `atelier` · `interop-v7` · `embed` = InterSystems Angular bundle loaded in place from `/ui/interop/<app>/index.html` · `monitor` · `deepsee` · `mgmnt` · `custom(<backing class>)` = OcuPilot must add a REST endpoint · `none`. The **SMP source** column marks a row as `new` (no SMP page), a Zen page class, or `legacy …csp` (legacy CSP pages, never exported).

**Tier definitions (verbatim)**:
- **P0 Contest MVP** — must be submittable by 2026-09-27: portal shell minimum, co-pilot core (four providers, test connection, screen context, read tools for every P0 screen, write tools with propose-review-confirm, audit, progress), list/detail/create/edit/delete/enable-disable screens for the six contest areas where a REST route already exists (official %Api.* or hidden /api/admin v2), the area-6 log viewers (messages.log and application error log are P0 despite needing custom endpoints), and the submission deliverables.
- **P1 Contest polish** — 2026-09-28 to 2026-10-04: precedent bonus items, per-screen suggested prompts, explain-this-screen / explain-this-log-entry, agent audit viewer, secondary log viewers, task import/export, OAuth 2.0 full editors, external language servers, read-only Dashboard main panel.
- **P2 Post-contest parity, API-backed** — an official %Api.* route or a hidden /api/admin route exists, or an InterSystems Angular editor can be embedded.
- **P3 Post-contest parity, custom REST required** — no route anywhere; a backing ObjectScript class exists (often already wrapped by iris-execute-mcp-v2 handlers or iris-session-agent tools).
- **P4 Long tail, excluded by default** — deprecated, license/edition-gated, low-usage, dead references, or full applications to link rather than rebuild; the reason is in the Evidence column.

**Totals**: 538 rows — P0 119 · P1 62 · P2 137 · P3 164 · P4 56.

**Per-section counts (P0/P1/P2/P3/P4/total)**: SH 11/11/3/3/1/29 · CP 24/11/7/1/0/43 · WA 7/2/5/2/1/17 · PM 16/2/4/2/0/24 · SS 16/11/8/4/1/40 · TM 13/3/0/3/0/19 · OS 12/3/9/6/4/34 · LG 4/6/1/1/1/13 · SA 0/2/20/27/13/62 · SO 0/0/8/9/2/19 · EX 1/0/33/20/4/58 · IO 0/1/28/69/20/118 · AN 0/1/9/7/7/24 · DT 0/0/1/10/1/12 · PK 15/9/1/0/1/26.

**Stated duplicates**: LG-02 = SS-14 (audit viewer), LG-09 = IO-01 (interop event log), EX-01 = SH-03 (namespace list). Counted twice deliberately "so each contest area reads complete".

## 2. P0 surface inventory (119 rows)

Screen key: list / detail / edit / create / wizard / dialog / action / viewer / panel / component / platform (no screen).

### SH — Portal shell (11)

| Row | Feature (as written) | Screen | Backing API | UI notes |
|---|---|---|---|---|
| SH-01 | Login: silent empty-body POST /api/admin/login with credentials first (users arriving from the classic portal are never prompted), then a form posting user and password; one access and refresh pair in sessionStorage; Bearer on every JWT-enabled API; refresh at exp minus iat minus 10 s and on any 401; a failed refresh returns to the form | login form (route) | admin-v2 POST /api/admin/login, /refresh | Silent attempt precedes the form; failed refresh returns to the form |
| SH-02 | Access model: route and menu gating from the caller's %Admin_* privilege map and page resources (mirrors %CheckResources / CheckLinkAccess) | platform (cross-cutting) | admin-v2 GET /api/admin/info (privileges map) | Gates routes and menu entries |
| SH-03 | Namespace switch (selector of namespaces the user can read/write; $NAMESPACE carried on routes) | selector component | atelier GET /api/atelier/ or admin-v2 GET /v2/namespaces | $NAMESPACE on routes |
| SH-04 | Header strip: server, instance, namespace, user, licensed-to, server flag (Live/Test/Failover/Development) | header component | admin-v2 GET /info, /license/key; atelier GET /api/atelier/ | Six fields |
| SH-05 | Navigation for the six contest areas (category selector, finder columns/list view, Go) | home / navigation | none | Category selector; finder has columns and list views; Go |
| SH-06 | Error handling: uniform error envelope, 401/403 handling, no-privilege tooltips, connectivity probe on failed server calls | platform (cross-cutting) | custom(OcuPilot REST envelope) | No-privilege tooltips; connectivity probe on failure |
| SH-07 | Locator bar / breadcrumbs per page | component | none | Every page |
| SH-08 | Per-page command bar (ribbon commands, view icons, sort options, search box) | component | none | Every page |
| SH-09 | Auto-refresh framework for list pages (on/off, rate, last-update stamp, persisted sort/filter/page size/max rows) | component (list pages) | none | Judgment call: Processes, Databases and Task pages depend on it |
| SH-10 | Logout: POST /api/admin/logout with the Bearer and credentials (ends the browser-level login for every in-group application, including embedded editors and the classic portal), clear sessionStorage, redirect to login | action | admin-v2 POST /api/admin/logout | Ends classic-portal login too; redirect to login |
| SH-11 | Instance identity and API-version guard on load (serverVersion, namespaces, apiVersion=2 from /info) | platform (startup) | admin-v2 GET /info | Guard on load |

### CP — Co-pilot agent (24)

| Row | Feature (as written) | Screen | Backing API | UI notes |
|---|---|---|---|---|
| CP-01 | Always-visible right-hand panel docked like VS Code's secondary side bar: present on every route, never dismissed by navigation, resizable with a remembered width and a minimum width, full-screen toggle; the screen content reflows to the remaining width (no collapse or close control in P0) | panel (shell-level) | none | No collapse/close in P0; narrow-viewport behaviour (<~900 px bottom sheet or overlay) stated as a UX decision, not a row |
| CP-02 | Chat turn endpoint (POST wraps AgentLoop.RunTurn returning TurnResult JSON) plus transcript bootstrap GET and lock-state GET | platform | custom(SessionAgent.Agent.AgentLoop, Chat.History) | Transcript bootstrap on load |
| CP-03 | Agent configuration screen and CRUD REST (provider, model, endpoint URL, credential type env/creds, env-var name, credential name, max tokens, temperature, max iterations, system prompt, enabled) with the 11 server-side validation rules | edit form (route) | custom(SessionAgent.Config.Agent, AgentDefaults) | 11 fields; 11 server-side validation rules; provider defaults load |
| CP-04 | Provider adapters openai, anthropic, gemini, openai-compatible | platform | custom | Provider choice on CP-03 |
| CP-05 | Local model support (openai-compatible endpoint: Ollama/vLLM/LM Studio, optional key, http allowed) | platform | custom | Optional key; http allowed |
| CP-06 | Test-connection action on the agent-config form (minimal CallMessages ping with small max tokens) | action (on CP-03) | custom(new provider-side method) | Result feedback on form |
| CP-07 | API-key resolution ladder (env var, Ens.Config.Credentials password, never persisted in config) with prefix shape checks | platform | custom(SessionAgent.Util.EnvSecret) | Key never shown/persisted in config |
| CP-08 | First-login / unconfigured gate (no enabled agent: panel shows config-empty state, admins redirected to agent config) | panel empty state + redirect | custom | Admins redirected to CP-03 |
| CP-09 | Screen-context injection (route, namespace, selected entity, visible rows) into contextHints each turn | platform (every screen) | none (client assembles) | Screens expose selected entity and visible rows |
| CP-10 | Context-sharing toggle (on by default, user can disable per session) | panel control | none | Per session |
| CP-11 | Tool registry and dispatch | platform | custom | — |
| CP-12 | Read tools for every P0 screen (one tool per list/detail endpoint: web apps, users, roles, resources, services, SSL, X.509, OAuth, LDAP, audit, tasks, processes, locks, databases, logs) | platform | same endpoints as the screens | Complexity L |
| CP-13 | Write tools with propose → review → confirm (diff of proposed change, rationale, expected impact, explicit confirm before any write) | dialog / card in panel | same write endpoints as the screens | Diff + rationale + expected impact + explicit confirm |
| CP-14 | Runs-as-user permission model (tools execute under the caller's IRIS privileges; no service account) | platform | custom | — |
| CP-15 | Audit of agent actions (Audit.LlmCall / Audit.ToolCall rows with args and results; %SYS audit events registered at install) | platform | custom | Viewer is P1 (CP-26) |
| CP-16 | Audit marking of agent-initiated writes (description tag "via OcuPilot co-pilot") | platform | custom | Visible in audit viewer text |
| CP-17 | Progress indication during a turn (per-iteration tool-call cards, spinner, "concurrent turn" lock banner polling) | panel states | custom | Tool-call cards; spinner; lock banner |
| CP-18 | Conversation lock (exclusive per-history lock; concurrent turn refused) | platform | custom | Surfaces as CP-17 banner |
| CP-19 | Retry / backoff on 429 and 5xx with Retry-After; 90 s provider timeout | platform | custom | Turns can take up to 90 s |
| CP-20 | Markdown rendering pipeline (marked → DOMPurify → Prism, vendored, no CDN) | panel rendering | none | Code highlighting in replies |
| CP-21 | Read-only mode (an administrator or per-user switch that blocks every mutating tool; the co-pilot is read/write by default) | setting / switch | custom | Admin or per-user |
| CP-22 | Kill switch (admin disables the agent globally or per user; Enabled=0 hides panel actions) | setting / switch | custom(SessionAgent.Config.Agent.Enabled) | Enabled=0 hides panel actions |
| CP-42 | Screen synchronisation after agent writes: every confirmed write emits a change event (entity type, id, action) that the active screen consumes to re-fetch in place and highlight the changed row or field; a change toast with a link covers screens not currently open | platform + toast | none (client event bus) | Re-fetch in place; highlight changed row/field; toast with link |
| CP-43 | Agent-driven navigation: browser-side tools the agent can call to open a screen, apply a filter or select an entity | platform | none (client-side tool) | Agent can open screens, apply filters, select entities |

### WA — Web apps and REST APIs (7)

| Row | Feature (as written) | Screen | Backing API | UI notes |
|---|---|---|---|---|
| WA-01 | Web applications list (name, namespace, type, enabled, dispatch class, resource) | list | admin-v2 GET /web-apps | 6 columns |
| WA-02 | Delete web application | action (row) | admin-v2 DELETE /web-app | write-confirm |
| WA-03 | Enable / disable web application | action | admin-v2 PUT /web-app (Enabled) | write-confirm |
| WA-04 | Create web application (type CSP/REST/WSGI/ASGI, namespace, dispatch class, resource, auth methods) | create form (M) | admin-v2 PUT /web-app | Ribbon Create |
| WA-05 | Web application detail / edit (full editor: type, enable, namespace, default app, dispatch class, resource, group-by-ID, auth methods, session timeout, JWT, CORS origins/headers, CSP file settings, serve files, Python protocol, application and matching roles) | detail/edit (L) | admin-v2 GET/PUT /web-app | SMP page is 1423 lines |
| WA-06 | REST API explorer: list REST-enabled web apps and spec-based REST services per namespace | list | mgmnt GET /api/mgmnt/, /v2/[:ns/] | Per namespace |
| WA-07 | REST API explorer: view the OpenAPI 2.0 document of a service (rendered path/verb browser; auto-generated spec for manually-coded services) | viewer (M) | mgmnt GET /v2/:ns/:app, /v1/:ns/spec/:webapp | Path/verb browser |

### PM — Permission management (16)

| Row | Feature (as written) | Screen | Backing API | UI notes |
|---|---|---|---|---|
| PM-01 | Users list with filter (name, full name, enabled, type, roles) | list | admin-v2 GET /security/users | Filter; 5 columns |
| PM-02 | Delete user | action (row) | admin-v2 DELETE /security/user | write-confirm |
| PM-03 | Enable / disable user | action | admin-v2 PUT /security/user | write-confirm |
| PM-04 | Change user password (admin-set; change-on-login flag) | dialog | admin-v2 POST /security/user/password | write-confirm |
| PM-05 | Add / remove roles on a user | edit (roles tab) | admin-v2 PUT /security/user (Roles) | write-confirm |
| PM-06 | Create user (name, password, full name, roles, expiry, startup namespace/routine) | create form (M) | admin-v2 POST /security/user | Ribbon Create New User |
| PM-07 | User detail / edit (account, comment, expiry, enabled, change-on-login, startup ns/routine, email, mobile, TOTP, roles tab) | detail/edit (L) | admin-v2 GET/PUT /security/user | SMP 961 lines; roles tab |
| PM-08 | Roles list | list | admin-v2 GET /security/roles | — |
| PM-09 | Delete role | action (row) | admin-v2 DELETE /security/role | write-confirm |
| PM-10 | Create role (name, description, resources, granted roles) | create form (M) | admin-v2 PUT /security/role | Ribbon Create New Role |
| PM-11 | Role resource add / edit / delete (resource:permissions) | dialog (M) | admin-v2 PUT /security/role | SMP Dialog.RoleResourceNew / Edit |
| PM-12 | Role detail / edit (description, escalation-only, resources, members, granted-to) | detail/edit (L) | admin-v2 GET/PUT /security/role | SMP 725 lines |
| PM-13 | Resources list with search | list | admin-v2 GET /security/resources | Search |
| PM-14 | Resource create / edit / delete (name, description, public permission) | dialog (M) | admin-v2 GET/PUT/DELETE /security/resource | Row Edit/Delete |
| PM-15 | Services list (enabled, auth methods, allowed IPs) | list | admin-v2 GET /security/services | 3 columns |
| PM-16 | Service edit (enable/disable, allowed IPs add/delete, roles, authentication methods) | edit (L) | admin-v2 GET/PUT /security/service | SMP Dialog.Service 676 lines |

### SS — Security and secrets (16)

| Row | Feature (as written) | Screen | Backing API | UI notes |
|---|---|---|---|---|
| SS-01 | SSL/TLS configurations list | list | admin-v2 GET /security/ssl-configurations | — |
| SS-02 | X.509 credentials list | list | admin-v2 GET /security/x509-credentials | Backing class open (Gaps) |
| SS-03 | OAuth 2.0 client: server descriptions list | list | admin-v2 GET /security/oauth2/client/server-definitions | Read only at P0 |
| SS-04 | OAuth 2.0 client configurations list / delete | list + delete | admin-v2 /security/oauth2/client/client-configurations | Delete; editor is P1 |
| SS-05 | OAuth 2.0 resource server list | list | admin-v2 GET /security/oauth2/resource-servers | Read only at P0 |
| SS-06 | OAuth 2.0 authorization server: view configuration (issuer, scopes, grant types, keys) | detail (read) | admin-v2 GET /security/oauth2/server | Single-object view |
| SS-07 | OAuth 2.0 server client descriptions list / delete | list + delete | admin-v2 GET /server/clients, DELETE /client | Delete |
| SS-08 | LDAP / Kerberos configurations list | list | admin-v2 GET /security/ldap/configurations | — |
| SS-09 | Enable / disable auditing (two SMP leaves) | action / toggle | admin-v2 GET/PUT /security/audit/enabled | write-confirm |
| SS-10 | Wallet: collections list and secrets list / create / edit / delete (contest-named; no SMP page) | list (collections) + list (secrets) + form | admin-v2 /wallet/collections, /collection, /secrets, /secret (%Admin_Wallet) | No SMP precedent; write-confirm |
| SS-11 | X.509 credential create (import cert/key) / edit / delete | create/edit (M) | admin-v2 POST/PUT/DELETE /security/x509-credential | Import cert/key |
| SS-12 | Configure system audit events (change status, reset counters; Selective SQL Auditing wizard) | list + actions + wizard | admin-v2 GET/PUT /audit/events, /event, /clear-count | Reset counters; wizard |
| SS-13 | Configure user audit events (create, change status, reset, delete) | list + form + actions | admin-v2 /security/audit/event GET/PUT/DELETE | Create/delete |
| SS-14 | View audit database (search by time, source/type/name, user, PID, namespace, auth, JSON text; detail dialog) | viewer (L) + detail dialog | admin-v2 POST /security/audit/records, GET /record | 8 search criteria; detail dialog |
| SS-15 | SSL/TLS configuration create / edit / delete (certs, key, CA, CRL, protocol min/max, ciphers, DH bits, OCSP, peer verification) | create/edit (L) | admin-v2 GET/PUT/DELETE /security/ssl-configuration | SMP 831 lines; Test is P1 (SS-17) |
| SS-16 | LDAP / Kerberos configuration create / edit / delete | create/edit (L) | admin-v2 GET/PUT/DELETE /security/ldap/configuration | SMP 797 lines; Test is P1 (SS-19) |

### TM — Task management (13)

| Row | Feature (as written) | Screen | Backing API | UI notes |
|---|---|---|---|---|
| TM-01 | Task schedule list (all scheduled tasks; filter; Task Manager status) | list | admin-v2 GET /tasks, GET /task/manager | Filter; Task Manager status shown |
| TM-02 | On-demand tasks list with Run | list + action | admin-v2 GET /tasks (client filter on-demand), POST /task/run | Client-side filter; write-confirm |
| TM-03 | Upcoming tasks (next N hours / until date) | list | admin-v2 GET /task/upcoming | Horizon input (N hours / date) |
| TM-04 | Task history (all tasks; user-defined filter) | list | admin-v2 GET /task/history | User-defined filter |
| TM-05 | Task history for one task | list (scoped) | admin-v2 GET /task/history (task filter) | — |
| TM-06 | Run task now | action | admin-v2 POST /task/run | write-confirm |
| TM-07 | Suspend task | action | admin-v2 POST /task/suspend | write-confirm |
| TM-08 | Resume task | action | admin-v2 POST /task/resume | write-confirm |
| TM-09 | Delete task | action | admin-v2 DELETE /task | write-confirm |
| TM-10 | Start / suspend / resume the Task Manager | actions (ribbon) | admin-v2 POST /task/manager/run, /resume, /suspend | write-confirm |
| TM-11 | Task details (properties, schedule, last run, next run; auto-refresh) | detail (M) | admin-v2 GET /task/info, GET /task | Auto-refresh |
| TM-12 | New task wizard (name, description, namespace, task type from %SYS.Task.Definition list, priority, run-as, output file, suspend-on-error, reschedule-after-restart, schedule daily/weekly/monthly/after-task/on-demand, expiry, email) | wizard (L) | admin-v2 POST /task | Multi-step; 5 schedule kinds |
| TM-13 | Edit task | edit (L) | admin-v2 PUT /task | SMP edit page rendered empty (Gap); fields taken from wizard |

### OS — OS management (12)

| Row | Feature (as written) | Screen | Backing API | UI notes |
|---|---|---|---|---|
| OS-01 | Processes list (filter, page size, max rows, persisted sort, auto-refresh; Details link) | list | admin-v2 GET /processes | Filter, page size, max rows, persisted sort, auto-refresh |
| OS-02 | Terminate process (with optional RESJOB error) | dialog | admin-v2 POST /process/terminate | Option flag; write-confirm |
| OS-03 | Suspend process | action | admin-v2 POST /process/suspend | write-confirm |
| OS-04 | Resume process | action | admin-v2 POST /process/resume | write-confirm |
| OS-05 | System usage counters (global refs, routine calls, block reads/writes, journal entries; refresh interval) and shared-memory usage | viewer / meters | admin-v2 GET /monitor/system-usage, /shared-memory | Refresh interval |
| OS-06 | Locks view (namespace selector, filter, owner routine info, SQL table name; owner links to process) | list | admin-v2 GET /locks | Namespace selector; links to process |
| OS-07 | Remove one lock / all locks for a process / all locks from a remote client (transaction warning) | action (3 scopes) | admin-v2 DELETE /lock | Transaction warning; write-confirm |
| OS-08 | Process details (dashboard meters, client EXE/IP, open devices, optional SQL statement info; auto-refresh) | detail (M) | admin-v2 GET /process | Auto-refresh; meters |
| OS-09 | CPU, memory and performance meters (System Performance / System Usage / System Status groups of the dashboard; Prometheus gauges) | dashboard / meters (M) | admin-v2 GET /monitor/dashboard/main; monitor /metrics | Meter names not captured (Gap) |
| OS-10 | Disks: local databases list with General and Free-space views (size, max, free, status, directory, mounted) | list (2 views) | admin-v2 GET /databases, /database-dirs; POST /database-dir/info (async) | Two view modes; async free-space info |
| OS-11 | Database details (properties, volume files, background tasks running against the DB; auto-refresh) | detail (M) | admin-v2 GET /database-dir, /volumes | Auto-refresh |
| OS-12 | Devices list / create / edit / delete (contest-named "devices") | list + form (M) | admin-v2 GET /devices, GET/PUT/DELETE /device | write-confirm; no field list stated |

### LG — All the logs (4)

| Row | Feature (as written) | Screen | Backing API | UI notes |
|---|---|---|---|---|
| LG-01 | alerts.log viewer (entries since last scrape from the official route plus custom tail of the file for history) | log viewer | monitor GET /api/monitor/alerts; custom(file tail) | Two sources merged |
| LG-02 | Audit database viewer (= SS-14) | viewer (L) | admin-v2 POST /security/audit/records | Duplicate of SS-14 |
| LG-03 | messages.log viewer (full text, search and highlight, goto top/bottom, tail) | log viewer (M) | custom(read <mgr>/messages.log; backing class unresolved) | Search + highlight; goto top/bottom; tail |
| LG-04 | Application error log: namespaces → dates → errors drill-down; delete by namespace / by error | drill-down (3 levels) + delete | custom(^ERRORS; class unresolved) | Co-pilot tool marked read although screen has delete |

### EX — System Explorer (1)

| Row | Feature (as written) | Screen | Backing API | UI notes |
|---|---|---|---|---|
| EX-01 | Namespace listing for the data browser (same source as SH-03) | component | atelier GET /api/atelier/ | Duplicate of SH-03 |

### PK — Packaging and submission (15) — no user screens

PK-01 README · PK-02 public repo + license · PK-03 Open Exchange listing (apply after 2026-09-14) · PK-04 application by 2026-09-27 23:59 US Eastern, improve to 2026-10-04 · PK-05 Ideas Portal idea · PK-06 Community Edition compatibility · PK-07 name-collision avoidance (package OcuPilot, web apps /ocupilot and /ocupilot/api) · PK-08 Web Gateway timeout ≥ 300 s prerequisite · PK-09 pin /api/admin v2 + spec under test · PK-10 IPM module.xml · PK-11 Angular bundle served from IRIS web app (unauthenticated static like /ui/interop; the shell logs in itself; non-root base href; deep-link fallback catch-all) · PK-12 OcuPilot REST web app /api/ocupilot (Bearer, JWT) · PK-13 idempotent installer (seed agent config Enabled=0) · PK-14 Docker self-install · PK-15 Angular build inside the IPM archive.

UI-relevant: PK-11 (non-root base href, deep-link fallback), PK-13 (agent seeded disabled → CP-08 gate fires on first login), PK-08 (long agent turns).

## 3. P1 rows (62) — polish week 2026-09-28 to 2026-10-04

| Row | Feature (as written, compact) | Screen | Backing API | UI notes |
|---|---|---|---|---|
| SH-12 | Change own password | dialog | admin-v2 POST /security/user/password | Header link |
| SH-13 | Favorites (add from finder, remove, clear; per user) | home component | custom or per-user store | — |
| SH-14 | Recent items (auto-registered pages; remove, clear) | home component | custom or local | — |
| SH-15 | Menu search typeahead (name/title/tags of entitled menu items) | shell component | none (client-side) | — |
| SH-16 | About page (14 system-overview fields; session language selector) | detail | admin-v2 /info, /license/key, /journal/settings | — |
| SH-17 | Help link per screen (DocBook HELPADDRESS) | component | none | Every screen |
| SH-18 | Menu drop-down of 16 fixed shortcuts filtered by access | shell component | none | — |
| SH-19 | Home "System Information" panel (uptime, mirror, DB/journal/lock/write-daemon alerts, production status) | home panel | admin-v2 /monitor/dashboard/main; interop-v7 /productions/status | — |
| SH-20 | Links panel (Documentation, Support, InterSystems home) | home component | none | — |
| SH-21 | UI state persistence (selected category, view mode, panel widths) | platform | localStorage | — |
| SH-22 | Light/dark theme (community-requested dark mode) | platform | none | — |
| CP-23 | Suggested prompts per screen (grouped by task) | panel | none | Per screen |
| CP-24 | "Explain this screen" action | panel action | none | — |
| CP-25 | "Explain this log entry" / explain error code action | action on log rows | custom(ExplainError) | — |
| CP-26 | Agent audit viewer (LlmCall / ToolCall ledger with filters, per-user and per-screen) | list/viewer (M) | custom(SQL) | Filters |
| CP-27 | Citations back to rows and tools used (citation chips with click-through) | panel | custom(RecordClickThrough) | — |
| CP-28 | Token metering (per-user/day totals shown in panel and audit viewer) | panel + viewer | custom | — |
| CP-29 | Log-content sanitisation / untrusted-content boundary | platform | custom | — |
| CP-30 | Copy-out drafts (ObjectScript / CLI / REST snippet instead of executing) | panel | none | — |
| CP-31 | Data-egress disclosure in the panel (which provider, that screen data leaves the instance) | panel notice | none | — |
| CP-32 | Chat history persistence keyed by screen/route with retention purge task | platform | custom | Per-route history |
| CP-33 | Tool governance policy (per tool:action enable/disable, presets, default-disabled destructive writes) with a policy viewer | settings + viewer (M) | custom | — |
| WA-08 | Try-it request console against a REST endpoint (send request with current session, show status/body) | console (M) | none (browser fetch) | — |
| WA-09 | Web sessions list (user, app, PID link) and End Session | list + action | admin-v2 GET /web-sessions, DELETE /web-session | write-confirm |
| PM-17 | User profile: effective privileges (roles, resources, applications, databases, services) | detail (M) | admin-v2 composed | — |
| PM-18 | Permission check tool (does user/role hold resource:permission) | tool/dialog | custom | — |
| SS-17 | SSL/TLS test connection | action on editor | admin-v2 POST /ssl-configuration/test | — |
| SS-18 | X.509 view certificate details | detail | admin-v2 GET /x509-credential/certificate | — |
| SS-19 | LDAP test authentication | action/dialog | admin-v2 POST /ldap/test | — |
| SS-20 | OAuth 2.0 administration: revoke a user's tokens | action | admin-v2 POST /oauth2/server/revoke | write-confirm |
| SS-21 | Copy audit log to namespace (background) | dialog | admin-v2 POST /audit/record/copy | write-confirm |
| SS-22 | Purge audit log older than N days | dialog | admin-v2 POST /audit/record/purge | write-confirm; confirm gate |
| SS-23 | OAuth 2.0 resource server editor | edit (M) | admin-v2 | write-confirm |
| SS-24 | OAuth 2.0 client server-description editor (Discover and Save, Update JWKS) | edit (L) | admin-v2 | SMP 731 lines |
| SS-25 | OAuth 2.0 client configuration editor (Rotate Keys, secrets, register-client, initial access token) | edit (L) | admin-v2 | SMP 1149 lines |
| SS-26 | OAuth 2.0 authorization server editor (Save, Delete, Rotate Keys, scopes add/remove) | edit (L) | admin-v2 | SMP 1051 lines |
| SS-27 | OAuth 2.0 server client description editor (Update JWKS, redirect URLs, secret) | edit (L) | admin-v2 | SMP 1014 lines |
| TM-14 | Export task to file | action | custom | write-confirm |
| TM-15 | Import tasks from file | dialog (M) | custom | write-confirm |
| TM-16 | Portal background tasks list (status, namespace, details, error count; Cancel / Pause / Resume; Purge) | list + actions (M) | admin-v2 /async-results (+custom) | write-confirm |
| OS-13 | Broadcast a message to selected processes | dialog (M) | admin-v2 POST /process/broadcast | Multi-select on Processes |
| OS-14 | License usage (summary, by process, by user, distributed) | viewer | admin-v2 GET /monitor/license-usage | 4 views |
| OS-15 | Read-only System Dashboard main panel (7 meter groups) | dashboard (M) | admin-v2 /monitor/dashboard/main | Meter names not captured |
| LG-05 | System Monitor log viewer (SystemMonitor.log or chosen file; search, highlight) | log viewer | custom(file read; directory allow-list) | — |
| LG-06 | Background task error log | log viewer | custom | — |
| LG-07 | xDBC error log (namespaces with errors → errors; delete selected / all) | drill-down + delete (M) | atelier action/query | Delete |
| LG-08 | SQL diagnostics log (per namespace; detail panel; delete) | list + detail panel (M) | atelier action/query | Delete |
| LG-09 | Interoperability event log (= IO-01) | log viewer (M) | custom | Duplicate |
| LG-10 | Unified log hub (one screen listing every log source with counts, last entry and "explain" entry points) | hub (M) | composes rows above | New hub screen |
| SA-01 | External language servers list with status; Start / Stop / Status / Activity log per server | list + actions (M) | admin-v2 /ext-lang-servers | write-confirm |
| SA-02 | External language server create / edit / delete | edit (L) | admin-v2 | write-confirm |
| IO-01 | Event log (search/filter by type, time, source item, session, text; auto-refresh; purge) | log viewer (M) | custom(Ens_Util.Log SQL) | Auto-refresh; purge |
| AN-01 | Analytics log viewer (DeepSee log file; refresh, delete) | log viewer | custom | Delete |
| PK-16..24 | Online demo, DC article, YouTube video/Short, bonus watch, Freshmen check, uninstall hook, %UnitTest HTTP harness, CI, publish package | none | — | No screens |

## 4. P2–P4 rows — counts and IA-shaping items

Counts (P2 / P3 / P4): SH 3/3/1 · CP 7/1/0 · WA 5/2/1 · PM 4/2/0 · SS 8/4/1 · TM 0/3/0 · OS 9/6/4 · LG 1/1/1 · SA 20/27/13 · SO 8/9/2 · EX 33/20/4 · IO 28/69/20 · AN 9/7/7 · DT 1/10/1 · PK 1/0/1.

Rows that would add a whole area, hub or top-level mode later (leave IA room):
- **Entire sections with zero P0/P1 screens**: SA System Administration remainder (namespaces SA-03/12/13/15, databases config SA-16..21, journal SA-04, license SA-06/07, ECP SA-08..10, mappings SA-11, NLS, mirror SA-43..49), SO System Operation remainder (journals SO-01..06, backup SO-09..12, mirror monitor SO-16/17), EX System Explorer (classes EX-02, routines EX-03, source view EX-04, SQL catalog EX-13, query console EX-14, data browser EX-18..33 with multi-table tabs EX-33, globals EX-37..41), IO Interoperability (productions IO-02, production monitor IO-10, queues IO-11, jobs IO-12, message viewer IO-25, visual trace IO-27, embedded rule/BPL/DTL/production editors IO-18/22/23/24), AN Analytics (cube list AN-02, MDX tool AN-07, links to Architect/Analyzer/User Portal AN-04..06), DT developer tools (DocDB browser DT-01, terminal DT-04, execute console DT-05/06, env diff/promote DT-09/10, remote instance profiles DT-11).
- **Shell-level**: SH-23 session hand-off for embedded InterSystems Angular editors (P2), SH-24 directory allow-list for file-browse dialogs (P2), SH-25 product-category gating by namespace with namespace picker when unsupported (P2), SH-26 security escalation (P3), SH-27 assign custom resource to menu item (P3).
- **Co-pilot**: CP-34 streaming (P2), CP-36 agent picker with multiple named agents per area (P2), CP-37 "Investigate" entry points on alerts and log entries launching multi-step runs (P2), CP-38 guided workflows from 11 MCP prompts (P2), CP-40 undo/rollback of an agent change (P3).
- **Within contest areas**: WA-11 Doc DB applications, WA-13/14 create/delete spec-based REST service, WA-10 %-class access; PM-22 SQL privileges tabs (schema/table/column grants) on User and Role; SS-29 superservers, SS-30 authentication/web session options, SS-31 MFT, SS-32..35 encryption group; OS-16..22 database mount/dismount/truncate/compact/defragment/expand/integrity wizard, OS-23 SQL activity, OS-28 full System Dashboard with drill-downs, OS-30 Prometheus metrics viewer; LG-11 live tail of text logs (long-poll), LG-12 alerts state/reset; TM-17 task output file viewer.

## 5. Cross-cutting rows

| Row | Applies to | Tier |
|---|---|---|
| SH-02 route and menu gating from privilege map | every route/menu | P0 |
| SH-03 namespace switch; $NAMESPACE carried on routes | shell + namespace-scoped screens | P0 |
| SH-04 header strip (6 fields) | shell | P0 |
| SH-06 uniform error envelope, 401/403, no-privilege tooltips, connectivity probe | every server call | P0 |
| SH-07 locator bar / breadcrumbs | every page | P0 |
| SH-08 command bar (ribbon commands, view icons, sort options, search box) | every page | P0 |
| SH-09 auto-refresh (on/off, rate, last-update stamp; persisted sort/filter/page size/max rows) | list pages | P0 |
| SH-11 instance/API-version guard on load | startup | P0 |
| CP-01 always-visible resizable right panel; content reflows | every route | P0 |
| CP-09 screen-context injection (route, namespace, selected entity, visible rows) | every screen | P0 |
| CP-10 context-sharing toggle | panel | P0 |
| CP-13 propose → review → confirm for every agent write | every write | P0 |
| CP-17 progress cards / spinner / lock banner | panel | P0 |
| CP-21 read-only mode, CP-22 kill switch | agent-wide | P0 |
| CP-42 screen sync after agent writes (re-fetch, highlight, toast with link) | every screen | P0 |
| CP-43 agent-driven navigation (open screen, apply filter, select entity) | every screen | P0 |
| SH-15 menu search typeahead | shell | P1 |
| SH-17 help link per screen | every screen | P1 |
| SH-13/14/18/20 favorites, recent items, 16-shortcut menu, links panel | home/shell | P1 |
| SH-21 UI state persistence (category, view mode, panel widths) | shell | P1 |
| SH-22 light/dark theme | shell | P1 |
| CP-23 suggested prompts per screen; CP-24 explain this screen; CP-25 explain log entry | every screen / log rows | P1 |
| CP-27 citation chips; CP-31 data-egress disclosure; CP-30 copy-out drafts | panel | P1 |
| CP-33 tool governance policy viewer | agent-wide | P1 |
| SH-24 directory allow-list for file-browse dialogs; SH-25 namespace-based category gating | shell | P2 |
| EX-29 CSV export, EX-30 keyboard shortcuts + help dialog, EX-31 ARIA/live announcements, EX-32 theme tokens | data browser only (not portal-wide) | P2 |
| EX-54 print catalog / query results | SQL screens only | P3 |

No row defines portal-wide export, column choosing, or keyboard shortcuts; sorting/filtering/paging appear only as attributes of SH-08/SH-09 and of individual list rows.

## 6. Actions that need confirmation or are destructive

All rows with Co-pilot tool = write-confirm route through CP-13 propose → review → confirm when agent-initiated. P0 write-confirm rows: WA-02..05; PM-02..07, PM-09..12, PM-14, PM-16; SS-09..13, SS-15, SS-16; TM-02, TM-06..10, TM-12, TM-13; OS-02..04, OS-07, OS-12 (36 rows) plus CP-13 itself.

Destructive / disable / kill / remove / reset / terminate / stop / suspend rows:

| Row | Action | Tier |
|---|---|---|
| WA-02 | Delete web application | P0 |
| WA-03 | Disable web application | P0 |
| PM-02 | Delete user | P0 |
| PM-03 | Disable user | P0 |
| PM-09 | Delete role | P0 |
| PM-11 | Delete resource from role | P0 |
| PM-14 | Delete resource | P0 |
| PM-16 | Disable service; delete allowed IPs | P0 |
| SS-04 | Delete OAuth client configuration | P0 |
| SS-07 | Delete OAuth server client description | P0 |
| SS-09 | Disable auditing | P0 |
| SS-10 | Delete wallet secret | P0 |
| SS-11 | Delete X.509 credential | P0 |
| SS-12 | Reset system audit event counters | P0 |
| SS-13 | Delete / reset user audit events | P0 |
| SS-15 | Delete SSL/TLS configuration | P0 |
| SS-16 | Delete LDAP/Kerberos configuration | P0 |
| TM-07 | Suspend task | P0 |
| TM-09 | Delete task | P0 |
| TM-10 | Suspend Task Manager | P0 |
| OS-02 | Terminate process (optional RESJOB error) | P0 |
| OS-03 | Suspend process | P0 |
| OS-07 | Remove one lock / all for a process / all from a remote client ("transaction warning") | P0 |
| OS-12 | Delete device | P0 |
| LG-04 | Delete application errors by namespace / by error | P0 |
| CP-22 | Kill switch (disable agent globally or per user) | P0 |
| WA-09 | End web session | P1 |
| SS-20 | Revoke a user's tokens | P1 |
| SS-22 | Purge audit log older than N days ("confirm gate") | P1 |
| SS-26 | Delete authorization server; Rotate Keys | P1 |
| SS-25 | Rotate Keys (client configuration) | P1 |
| TM-16 | Cancel / Purge background tasks | P1 |
| SA-01 / SA-02 | Stop / delete external language server | P1 |
| LG-07, LG-08, AN-01, IO-01 | Delete / purge log entries | P1 |
| OS-17..20 | Dismount, truncate, compact, defragment database | P2 |
| SA-15, SA-21 | Delete namespace wizard, delete database wizard | P2 |
| EX-06, EX-28 | Delete classes/routines; delete rows (delete confirm) | P2 |
| IO-06, IO-11, IO-12 | Stop production; Abort/Abort All/Suspend queues; Abort/Stop jobs | P2 |
| IO-26 | Resend messages (dry-run and confirm gate, cap 500) | P2 |

26 destructive rows at P0.

## 7. Data-heavy screens

| Row | Screen | Stated volume / paging / filtering / tailing |
|---|---|---|
| OS-01 | Processes list | filter, page size, max rows, persisted sort, auto-refresh; Details link (P0) |
| SS-14 / LG-02 | Audit database viewer | search by time, source/type/name, user, PID, namespace, auth, JSON text; detail dialog; POST /audit/records (P0) — no page size stated |
| LG-03 | messages.log | full text, search and highlight, goto top/bottom, tail (P0); file read via %Stream.FileCharacter |
| LG-04 | Application error log | three-level drill-down namespaces → dates → errors (P0) |
| LG-01 | alerts.log | entries since last scrape (official route) + custom file tail for history (P0) |
| TM-04 / TM-05 | Task history (all / one task) | user-defined filter (P0) |
| TM-01 / TM-02 / TM-03 | Task lists | filter; client-side on-demand filter; upcoming "next N hours / until date" (P0) |
| OS-06 | Locks view | namespace selector, filter (P0) |
| OS-10 / OS-11 | Databases list / details | two views (General, Free-space); free-space via async POST; auto-refresh on details (P0) |
| OS-05 / OS-09 | System usage counters / meters | refresh interval; Prometheus gauges (P0) |
| PM-01, PM-13, WA-01 | Users (filter), Resources (search), Web apps | list filters only (P0) |
| CP-26 | Agent audit viewer | filters, per-user and per-screen (P1) |
| IO-01 / LG-09 | Interop event log | search/filter by type, time, source item, session, text; auto-refresh; purge (P1) |
| TM-16 | Background tasks | status, namespace, details, error count (P1) |
| LG-10 | Unified log hub | counts and last entry per log source (P1) |
| LG-11 | Live tail of text logs | long-poll with heartbeat (P2) — P0 "tail" is not live |
| SO-06 | Journal record browser | search by time/process/type/global/database with operators, offset, page size, colour-by (P2) |
| EX-20 / EX-24 | Data browser grid | TOP / %VID offset paging plus COUNT(*); first/prev/next/last, go-to page, page size (P2) |
| IO-25 | Message viewer | basic/extended criteria, saved searches; header/body/contents panes (P2) |
| DT-05 | Execute command console | 32768-char output ceiling (P3) |

No row states absolute row counts or default page sizes. Stated caps: resend 500 (IO-26), command output 32768 chars (DT-05). Auto-refresh explicitly attached to: OS-01, OS-08, OS-11, TM-11, IO-01, SO-01, OS-28.

## 8. Gaps for UX (stated or implied; no proposals)

- **Paging model** for admin-v2 lists is unstated; only OS-01 names page size / max rows; audit viewer (SS-14) is a POST search with no page size mentioned; catalog Gaps note write payloads and list shapes were "observed only for list/get shapes".
- **Column sets** are given only for WA-01 (6), PM-01 (5), PM-15 (3), OS-10 (6), SH-04 (6); other lists have no columns stated.
- **Detail vs dialog vs route** is inherited from SMP page classes (Dialog.* for PM-04, PM-11, PM-14, OS-02, SS-14 detail) but never decided for OcuPilot.
- **Create vs edit**: create and detail/edit are separate rows with different complexity (WA-04 M vs WA-05 L; PM-06 M vs PM-07 L; PM-10 M vs PM-12 L); whether one editor serves both is not stated.
- **Field lists absent** for SS-10 wallet (no SMP page), OS-12 devices, TM-13 edit task (SMP page rendered empty; fields taken from wizard), OS-09 meters (meter names and thresholds not captured; only group labels confirmed).
- **Home screen body at P0** is only SH-05 navigation; the System Information panel (SH-19), favorites, recent, links are all P1.
- **Co-pilot panel** narrow-viewport behaviour (bottom sheet or overlay under about 900 px) is explicitly deferred to UX; panel minimum width and remembered width values unstated; where CP-13 propose/review/confirm renders (panel vs modal) unstated; highlight style and toast duration for CP-42 unstated.
- **Agent turn latency**: 90 s provider timeout, retry/backoff, Web Gateway ≥ 300 s — no row describes the waiting/timeout UI beyond CP-17 spinner and cards.
- **Access gating presentation**: SH-02 gates routes/menus; SH-06 mentions "no-privilege tooltips" — hidden vs disabled is not resolved per control.
- **Namespace scope per screen** is not stated row by row; only OS-06 (selector), WA-06 (per namespace), WA-01 (namespace column) and SH-03 ($NAMESPACE on routes) mention it.
- **Filter execution** (client vs server) is stated only for TM-02 (client filter).
- **Log viewers**: LG-03 "tail" semantics vs LG-11 live tail (P2) leaves P0 tailing as non-live; LG-04 delete exists on-screen while the co-pilot tool is read-only; no row for log-level or time-window filtering on messages.log.
- **OAuth 2.0 at P0** is five separate list/view screens with delete on two (SS-04, SS-07) and no editors until P1 (SS-23..27).
- **Audit configuration** (SS-12, SS-13) list/toggle/reset shapes are inferred from SMP; Selective SQL Auditing wizard steps unstated.
- **Devices (OS-12) and wallet (SS-10)** are contest-named rows with thin evidence (wallet route "instance-verified but undocumented").
- **Sizing** is only the S/M/L complexity code; no line counts beyond the SMP page sizes quoted (e.g. WA-05 1423, PM-07 961, PM-12 725, PM-16 676, SS-15 831, SS-16 797, SS-14 555).
- **Judgment calls that shape scope**: OS-06/07 locks pulled to P0; OS-16..22 database actions kept at P2; WA-09 web sessions kept at P1; SS-29 superservers at P2 although under Security in SMP; SH-12 change own password at P1 despite being a header link.
- **Backing-class gaps** that could change screens: messages.log and application-error classes unresolved (LG-03, LG-04); X.509 backing class mismatch (SS-02, SS-11); legacy CSP pages never exported so their action sets are inferred.
