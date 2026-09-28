# Extract: OcuPilot feature catalog (2026-09-08)

Source: `_bmad-output/planning-artifacts/research/technical-ocupilot-portal-feature-landscape-2026-09-08/feature-catalog.md` (707 lines, 538 rows). Extracted for the PRD author; row IDs and feature names are reproduced verbatim from the catalog. Nothing in this file is new analysis except where a paragraph is labelled *extractor's note* or *judgment*.

## 1. Schema and tier rules

### Columns (every section table has the same ten)

| # | Column | Meaning (catalog's own definition) |
|---|---|---|
| 1 | ID | `<PREFIX>-<nn>`; see row-ID conventions below |
| 2 | Feature | The screen or action; one row per distinct write action on P0/P1/P2 pages, one row per page or group on P4 pages |
| 3 | SMP source | The System Management Portal page class the feature comes from, or `new` when no SMP page exists; legacy CSP pages are given by `.csp` path; `(nnn)` after a class is its line count |
| 4 | API backing | Which route or class backs it, using the vocabulary below |
| 5 | Harvest source | Which sibling project or digest supplies reusable code or pattern (`iris-couch`, `session-agent`, `execute-mcp`, `table-editor`, `irisui-embed`, `agent-patterns`, `packaging`) |
| 6 | MCP tool | The iris-execute-mcp-v2 tool name; `tool:action` where only some actions apply; `—` when none |
| 7 | Tier | P0 … P4 (below) |
| 8 | Complexity | S / M / L (below) |
| 9 | Co-pilot tool | `read` / `write-confirm` / `none` — what kind of agent tool the row implies |
| 10 | Evidence | Digest file and the row or claim it came from |

### Tiers

- **P0 Contest MVP** — must be submittable by 2026-09-27: portal shell minimum, co-pilot core (four providers, test connection, screen context, read tools for every P0 screen, write tools with propose-review-confirm, audit, progress), list/detail/create/edit/delete/enable-disable screens for the six contest areas *where a REST route already exists* (official `%Api.*` or hidden `/api/admin` v2), the area-6 log viewers (messages.log and application error log are P0 despite needing custom endpoints), and the submission deliverables.
- **P1 Contest polish** — 2026-09-28 to 2026-10-04: precedent bonus items, per-screen suggested prompts, explain-this-screen / explain-this-log-entry, agent audit viewer, secondary log viewers, task import/export, OAuth 2.0 full editors, external language servers, read-only Dashboard main panel.
- **P2 Post-contest parity, API-backed** — an official `%Api.*` route or a hidden `/api/admin` route exists, or an InterSystems Angular editor can be embedded.
- **P3 Post-contest parity, custom REST required** — no route anywhere; a backing ObjectScript class exists (often already wrapped by iris-execute-mcp-v2 handlers or iris-session-agent tools).
- **P4 Long tail, excluded by default** — deprecated, license/edition-gated, low-usage, dead references, or full applications to link rather than rebuild; the reason is stated in the Evidence column. Rows are never dropped.

Tie-break rule used throughout the judgment calls: when two tier rules conflict, "choose the earlier tier".

### Sizes (the catalog calls the column "Complexity")

- **S** — list only
- **M** — list plus form or dialog
- **L** — wizard, editor or console

### Row-ID conventions

Each section has a two-letter prefix and rows are numbered within the section. Numbering is by section order, not by tier, with two exceptions noted.

| Prefix | Section | Rows |
|---|---|---|
| SH | 0. Portal shell and platform | SH-01..SH-29 |
| CP | 1. Co-pilot agent | CP-01..CP-43 (CP-42 and CP-43 were added later at the owner's direction and sit out of numeric order, placed between CP-22 and CP-23 in the table because they are P0) |
| WA | 2. Contest area 1: Web apps and REST APIs | WA-01..WA-17 |
| PM | 3. Contest area 2: Permission management | PM-01..PM-24 |
| SS | 4. Contest area 3: Security and secrets | SS-01..SS-40 |
| TM | 5. Contest area 4: Task management | TM-01..TM-19 |
| OS | 6. Contest area 5: OS management | OS-01..OS-34 |
| LG | 7. Contest area 6: All the logs | LG-01..LG-13 |
| SA | 8. System Administration, remainder | SA-01..SA-62 |
| SO | 9. System Operation, remainder | SO-01..SO-19 |
| EX | 10. System Explorer and data browser | EX-01..EX-58 |
| IO | 11. Interoperability | IO-01..IO-118 (IO-91..IO-118 are the 28 iris-session-agent co-pilot tools, one row each) |
| AN | 12. Analytics | AN-01..AN-24 |
| DT | 13. Developer tools and sibling-tool equivalents | DT-01..DT-12 |
| PK | 14. Packaging, deployment and contest submission deliverables | PK-01..PK-26 |

Deliberate duplicates (counted twice in the catalog's totals): **LG-02 = SS-14** (audit viewer), **LG-09 = IO-01** (interop event log), **EX-01 = SH-03** (namespace listing).

### API-backing vocabulary

| Token | Meaning |
|---|---|
| `admin-v2` | hidden `/api/admin/v2` route (`%Api.Admin.Dispatch.v2`) — **instance-verified, undocumented** |
| `official-REST` | documented `%Api.*` service other than those below |
| `atelier` | `/api/atelier/v1..v8` |
| `interop-v7` | `/api/interop-editors/v7` |
| `embed` | InterSystems Angular bundle loaded in place from `/ui/interop/<app>/index.html` |
| `monitor` | `/api/monitor` |
| `deepsee` | `/api/deepsee` |
| `mgmnt` | `/api/mgmnt` |
| `custom(<backing class>)` | OcuPilot must add a REST endpoint over the named class |
| `none` | no server call, or nothing found |

### Coverage statements the catalog makes about itself

- SMP leaf coverage: System Administration 90/90, System Operation 36/36, System Explorer 11/11, Analytics 18/18, Interoperability 68/68 live and 76/76 in source.
- MCP-tool mapping: all 104 iris-execute-mcp-v2 tools plus `iris_server_profiles` appear in an MCP tool column (88 on SMP-derived rows, 17 on new rows). The 28 iris-session-agent tools are IO-91..IO-118. Every iris-table-editor feature is a row in section 10.
- Granularity: action granularity everywhere except P4 rows and the 28 session-agent tools (one row per tool).

## 2. P0 rows by area

**Mapping of catalog sections onto the nine PRD areas.** The catalog's sections 0–7 and 14 map one-to-one onto areas (a)–(i): SH→(a), CP→(b), WA→(c), PM→(d), SS→(e), TM→(f), OS→(g), LG→(h), PK→(i). Two placements needed judgment:

- *Judgment:* **EX-01** (section 10, the only P0 row outside sections 0–7 and 14) is the namespace listing for the data browser, stated by the catalog to be "same source as SH-03". It is placed under (a) shell and navigation.
- *Judgment:* the P1 log viewers **IO-01** (section 11) and **AN-01** (section 12) are secondary log viewers by the catalog's own tier reasoning; they are listed under (h) in section 3 with a cross-reference. No P0 row was affected.
- SA-01 / SA-02 (P1, external language servers) fit none of the nine areas and are listed separately at the end of section 3.

**How the "observed-live?" column was derived** (the catalog has no such column; this is the extractor reading the API-backing token, the Evidence column and the Gaps section together):

- **yes** — the backing is an `admin-v2` GET, an official/`atelier`/`mgmnt` GET, or one of the auth-spike POSTs (`/login`, `/refresh`, `/logout`), all of which the catalog states were exercised on the ocupilot instance (`admin-v2` is defined as "instance-verified"; the Gaps section says list/get shapes were observed). Rows whose Evidence cites `api-coverage-verify C3/C4` are the strongest.
- **no — write payload untested** — an `admin-v2` PUT/POST/DELETE. The route is in the UrlMap, but the Gaps section states "write payloads for every admin-v2 row are untested, and the v1 UrlMap was read only partially (PATCH/DELETE variants)".
- **no — custom** — backing is `custom(...)`: nothing exists to observe; OcuPilot must build the endpoint.
- **no — no server call** — backing is `none`.
- **unknown** — the backing class is unresolved on the instance, or the route is named but no verification evidence is cited (e.g. a POST search route, the wallet routes).

Mixed rows (GET + write) are shown as "GET yes / write no".

### (a) Shell and navigation — SH P0 rows plus EX-01

| ID | Name | Kind | Backing API route or class | Observed-live? | Size | Notes |
|---|---|---|---|---|---|---|
| SH-01 | Login: silent empty-body POST /api/admin/login with credentials first (users arriving from the classic portal are never prompted), then a form posting user and password; one access and refresh pair in sessionStorage; Bearer on every JWT-enabled API; refresh at exp minus iat minus 10 s and on any 401; a failed refresh returns to the form | other (auth) | admin-v2 POST /api/admin/login and /refresh (JWT endpoints on the application root) | yes (auth spike §6–§7) | M | SMP source: new (SMP has the CSP login form). Harvest: iris-couch auth service pattern. Co-pilot tool: none |
| SH-02 | Access model: route and menu gating from the caller's %Admin_* privilege map and page resources (mirrors %CheckResources / CheckLinkAccess) | other (gating) | admin-v2 GET /api/admin/info (privileges map) | yes (api-coverage-verify C3) | M | SMP: %CSP.Portal.Home.%CheckResources; %CSP.Portal.Utils.CheckLinkAccess. MCP: iris_permission_check. Co-pilot: read |
| SH-03 | Namespace switch (selector of namespaces the user can read/write; $NAMESPACE carried on routes) | other (selector) | official-REST GET /api/atelier/ (namespaces) or admin-v2 GET /v2/namespaces | yes | S | SMP: %ZEN.Portal.standardPage.switchNamespace. MCP: iris_server_namespace. Co-pilot: read. Duplicated as EX-01 |
| SH-04 | Header strip: server, instance, namespace, user, licensed-to, server flag (Live/Test/Failover/Development) | other (read display) | admin-v2 GET /info and GET /license/key; official-REST GET /api/atelier/ | yes (api-coverage-verify C3) | S | MCP: iris_server_info. Co-pilot: read |
| SH-05 | Navigation for the six contest areas (category selector, finder columns/list view, Go) | other (navigation) | none | no — no server call | M | SMP: %CSP.Portal.Home.DrawSelector / drawDetails |
| SH-06 | Error handling: uniform error envelope, 401/403 handling, no-privilege tooltips, connectivity probe on failed server calls | other (platform) | custom(OcuPilot REST envelope) | no — custom | M | Harvest: iris-couch Util.Error envelope and ReportHttpStatusCode override |
| SH-07 | Locator bar / breadcrumbs per page | other (navigation) | none | no — no server call | S | SMP: standardPage.DrawLocator; PARENTPAGE |
| SH-08 | Per-page command bar (ribbon commands, view icons, sort options, search box) | other (navigation) | none | no — no server call | S | SMP: standardPage.DrawRibbon; OnGetRibbonInfo |
| SH-09 | Auto-refresh framework for list pages (on/off, rate, last-update stamp, persisted sort/filter/page size/max rows) | other (platform) | none | no — no server call | M | Judgment call: P0 because Processes, Databases and Task pages depend on it |
| SH-10 | Logout: POST /api/admin/logout with the Bearer and credentials (ends the browser-level login for every in-group application, including embedded editors and the classic portal), clear sessionStorage, redirect to login | action | admin-v2 POST /api/admin/logout | yes (auth spike §6 step 5) | S | Harvest: iris-couch AuthService.logout |
| SH-11 | Instance identity and API-version guard on load (serverVersion, namespaces, apiVersion=2 from /info) | other (platform) | admin-v2 GET /info | yes | S | SMP: new |
| EX-01 | Namespace listing for the data browser (same source as SH-03) | list | official-REST GET /api/atelier/ | yes | S | Catalog section 10; placed here by judgment (duplicate of SH-03). MCP: iris_server_namespace. Co-pilot: read |

### (b) Agent co-pilot core — CP P0 rows

| ID | Name | Kind | Backing API route or class | Observed-live? | Size | Notes |
|---|---|---|---|---|---|---|
| CP-01 | Always-visible right-hand panel docked like VS Code's secondary side bar: present on every route, never dismissed by navigation, resizable with a remembered width and a minimum width, full-screen toggle; the screen content reflows to the remaining width (no collapse or close control in P0) | other (UI) | none | no — no server call | M | Reworded at owner's direction 2026-09-08 (judgment call). Harvest: agent-patterns pattern 1 |
| CP-02 | Chat turn endpoint (POST wraps AgentLoop.RunTurn returning TurnResult JSON) plus transcript bootstrap GET and lock-state GET (Bearer-authenticated like every OcuPilot REST call) | other (REST endpoint) | custom(SessionAgent.Agent.AgentLoop, Chat.History) | no — custom | M | Harvest: session-agent AgentLoop.RunTurn |
| CP-03 | Agent configuration screen and CRUD REST (provider, model, endpoint URL, credential type env/creds, env-var name, credential name, max tokens, temperature, max iterations, system prompt, enabled) with the 11 server-side validation rules | create / edit (config) | custom(SessionAgent.Config.Agent, AgentDefaults) | no — custom | M | Harvest: session-agent UI.AgentConfig (Zen form) |
| CP-04 | Provider adapters openai, anthropic, gemini, openai-compatible (canonical Anthropic wire shape; adapters) | other (server component) | custom(SessionAgent.LLM.*Provider, Util.MessageAdapter, Util.ToolDefAdapter) | no — custom | S | Harvest: session-agent LLM package "reusable as-is" |
| CP-05 | Local model support (openai-compatible endpoint: Ollama/vLLM/LM Studio, optional key, http allowed) | other (server component) | custom(SessionAgent.LLM.OpenAICompatProvider) | no — custom | S | |
| CP-06 | Test-connection action on the agent-config form (minimal CallMessages ping with small max tokens) | action | custom(new provider-side method) | no — custom (no ping exists in any harvest source) | S | Flagged in section 6 |
| CP-07 | API-key resolution ladder (env var, Ens.Config.Credentials password, never persisted in config) with prefix shape checks | other (server component) | custom(SessionAgent.Util.EnvSecret) | no — custom | S | Wallet rung is CP-35 (P2) |
| CP-08 | First-login / unconfigured gate (no enabled agent: panel shows config-empty state, admins redirected to agent config) | other (UI) | custom | no — custom | S | No gate exists in session-agent |
| CP-09 | Screen-context injection (route, namespace, selected entity, visible rows) into contextHints each turn | other (cross-cutting) | none (client assembles) | no — no server call | M | Harvest: session-agent pContextHints; agent-patterns pattern 2 |
| CP-10 | Context-sharing toggle (on by default, user can disable per session) | enable-disable | none | no — no server call | S | |
| CP-11 | Tool registry and dispatch (reflection over Tool.Base subclasses; JSON-schema subset; MCP-shaped result envelope) | other (server component) | custom(SessionAgent.Tool.Registry, Tool.Base) | no — custom | M | |
| CP-12 | Read tools for every P0 screen (one tool per list/detail endpoint: web apps, users, roles, resources, services, SSL, X.509, OAuth, LDAP, audit, tasks, processes, locks, databases, logs) | agent tool (read) | admin-v2 / official-REST / custom (same endpoints as the screens) | yes for the admin-v2 GET and official routes; no for the custom log endpoints | L | MCP column: "(admin/ops read tools listed per screen)". Co-pilot: read |
| CP-13 | Write tools with propose → review → confirm (diff of proposed change, rationale, expected impact, explicit confirm before any write) | agent tool (write) | same write endpoints as the screens | no — write payloads untested | L | MCP column: "(admin/ops write tools listed per screen)". Co-pilot: write-confirm. Harvest: execute-mcp dryRun+confirm gate |
| CP-14 | Runs-as-user permission model (tools execute under the caller's IRIS privileges; no service account; MutatesState gate replaced by per-tool permission check) | other (security) | custom(SessionAgent.Tool.Registry.Dispatch) | no — custom | M | MCP: iris_permission_check |
| CP-15 | Audit of agent actions (Audit.LlmCall / Audit.ToolCall rows with args and results; %SYS audit events registered at install) | other (audit) | custom(SessionAgent.Audit.Emit, LlmCall, ToolCall) | no — custom | M | Installer must register events (PK-13) |
| CP-16 | Audit marking of agent-initiated writes (description tag "via OcuPilot co-pilot" so IRIS audit distinguishes agent from human) | other (audit) | custom($System.Security.Audit description) | no — custom | S | |
| CP-17 | Progress indication during a turn (per-iteration tool-call cards, spinner, "concurrent turn" lock banner polling) | other (UI) | custom | no — custom | M | |
| CP-18 | Conversation lock (exclusive per-history lock; concurrent turn refused) | other (server component) | custom(SessionAgent.Chat.History.LoadOrCreate) | no — custom | S | |
| CP-19 | Retry / backoff on 429 and 5xx with Retry-After; 90 s provider timeout; Web Gateway timeout prerequisite | other (server component) | custom(SessionAgent.Util.RetryWithBackoff) | no — custom | S | Gateway prerequisite is PK-08 |
| CP-20 | Markdown rendering pipeline (marked → DOMPurify → Prism, vendored, no CDN) | other (UI) | none | no — no server call | S | |
| CP-21 | Read-only mode (an administrator or per-user switch that blocks every mutating tool; the co-pilot is read/write by default, with every write going through propose-review-confirm) | enable-disable | custom | no — custom | S | |
| CP-22 | Kill switch (admin disables the agent globally or per user; Enabled=0 hides panel actions) | enable-disable | custom(SessionAgent.Config.Agent.Enabled) | no — custom | S | Installer seeds Enabled=0 (PK-13) |
| CP-42 | Screen synchronisation after agent writes: every confirmed write emits a change event (entity type, id, action) that the active screen consumes to re-fetch in place and highlight the changed row or field; a change toast with a link covers screens not currently open | other (cross-cutting) | none (client event bus over the same read endpoints as the screens) | no — no server call | M | Owner requirement 2026-09-08; no harvest equivalent |
| CP-43 | Agent-driven navigation: browser-side tools the agent can call to open a screen, apply a filter or select an entity, so it can take the user to what it changed or is explaining | agent tool (client-side) | none (client-side tool executed by the panel) | no — no server call | S | Owner requirement 2026-09-08. Co-pilot: read |

### (c) Web applications and REST API explorer — WA P0 rows

| ID | Name | Kind | Backing API route or class | Observed-live? | Size | Notes |
|---|---|---|---|---|---|---|
| WA-01 | Web applications list (name, namespace, type, enabled, dispatch class, resource) | list | admin-v2 GET /web-apps | yes | S | SMP: %CSP.UI.Portal.Applications.WebList. MCP: iris_webapp_list. Co-pilot: read |
| WA-02 | Delete web application | delete | admin-v2 DELETE /web-app | no — write payload untested | S | MCP: iris_webapp_manage:delete. Co-pilot: write-confirm |
| WA-03 | Enable / disable web application | enable-disable | admin-v2 PUT /web-app (Enabled) | no — write payload untested | S | MCP: iris_webapp_manage:modify |
| WA-04 | Create web application (type CSP/REST/WSGI/ASGI, namespace, dispatch class, resource, auth methods) | create | admin-v2 PUT /web-app | no — write payload untested | M | MCP: iris_webapp_manage:create (BuildWebAppProps) |
| WA-05 | Web application detail / edit (full editor: type, enable, namespace, default app, dispatch class, resource, group-by-ID, auth methods, session timeout, JWT, CORS origins/headers, CSP file settings, serve files, Python protocol, application and matching roles) | detail / edit | admin-v2 GET/PUT /web-app | GET yes / PUT no | L | SMP: %CSP.UI.Portal.Applications.Web (1423 lines). MCP: iris_webapp_get; iris_webapp_manage |
| WA-06 | REST API explorer: list REST-enabled web apps and spec-based REST services per namespace | list | mgmnt GET /api/mgmnt/ and GET /api/mgmnt/v2/[:ns/] | yes (api-coverage Mgmnt live results) | S | SMP: new. MCP: iris_rest_manage:list. Co-pilot: read |
| WA-07 | REST API explorer: view the OpenAPI 2.0 document of a service (rendered path/verb browser; auto-generated spec for manually-coded services) | detail | mgmnt GET /api/mgmnt/v2/:ns/:app and GET /api/mgmnt/v1/:ns/spec/:webapp | yes | M | MCP: iris_rest_manage:get. Co-pilot: read |

### (d) Permissions: users, roles, resources, services — PM P0 rows

| ID | Name | Kind | Backing API route or class | Observed-live? | Size | Notes |
|---|---|---|---|---|---|---|
| PM-01 | Users list with filter (name, full name, enabled, type, roles) | list | admin-v2 GET /security/users | yes (api-coverage-verify C4) | S | SMP: %CSP.UI.Portal.Users. MCP: iris_user_get. Co-pilot: read |
| PM-02 | Delete user | delete | admin-v2 DELETE /security/user | no — write payload untested | S | MCP: iris_user_manage:delete |
| PM-03 | Enable / disable user | enable-disable | admin-v2 PUT /security/user | no — write payload untested | S | MCP: iris_user_manage:modify |
| PM-04 | Change user password (admin-set; change-on-login flag) | action | admin-v2 POST /security/user/password | no — write payload untested | S | MCP: iris_user_password:change |
| PM-05 | Add / remove roles on a user | edit | admin-v2 PUT /security/user (Roles) | no — write payload untested | S | MCP: iris_user_roles |
| PM-06 | Create user (name, password, full name, roles, expiry, startup namespace/routine) | create | admin-v2 POST /security/user | no — write payload untested | M | MCP: iris_user_manage:create |
| PM-07 | User detail / edit (account, comment, expiry, enabled, change-on-login, startup ns/routine, email, mobile, TOTP, roles tab) | detail / edit | admin-v2 GET/PUT /security/user | GET yes / PUT no | L | SMP: %CSP.UI.Portal.User (961 lines). MCP: iris_user_get; iris_user_manage |
| PM-08 | Roles list | list | admin-v2 GET /security/roles | yes | S | MCP: iris_role_list. Co-pilot: read |
| PM-09 | Delete role | delete | admin-v2 DELETE /security/role | no — write payload untested | S | MCP: iris_role_manage:delete |
| PM-10 | Create role (name, description, resources, granted roles) | create | admin-v2 PUT /security/role | no — write payload untested | M | MCP: iris_role_manage:create |
| PM-11 | Role resource add / edit / delete (resource:permissions) | edit | admin-v2 PUT /security/role | no — write payload untested | M | SMP: Dialog.RoleResourceNew / RoleResourceEdit. MCP: iris_role_manage:modify |
| PM-12 | Role detail / edit (description, escalation-only, resources, members, granted-to) | detail / edit | admin-v2 GET/PUT /security/role | GET yes / PUT no | L | SMP: %CSP.UI.Portal.Role (725 lines) |
| PM-13 | Resources list with search | list | admin-v2 GET /security/resources | yes | S | MCP: iris_resource_list. Co-pilot: read |
| PM-14 | Resource create / edit / delete (name, description, public permission) | create / edit / delete | admin-v2 GET/PUT/DELETE /security/resource | GET yes / writes no | M | MCP: iris_resource_manage:create/modify/delete |
| PM-15 | Services list (enabled, auth methods, allowed IPs) | list | admin-v2 GET /security/services | yes | S | MCP: iris_service_manage:list/get. Co-pilot: read |
| PM-16 | Service edit (enable/disable, allowed IPs add/delete, roles, authentication methods) | edit / enable-disable | admin-v2 GET/PUT /security/service | GET yes / PUT no | L | SMP: Dialog.Service (676 lines). MCP: iris_service_manage:enable/disable/set |

### (e) Security and secrets — SS P0 rows

| ID | Name | Kind | Backing API route or class | Observed-live? | Size | Notes |
|---|---|---|---|---|---|---|
| SS-01 | SSL/TLS configurations list | list | admin-v2 GET /security/ssl-configurations | yes | S | MCP: iris_ssl_list. Co-pilot: read |
| SS-02 | X.509 credentials list | list | admin-v2 GET /security/x509-credentials | yes (route); backing class open | S | Gaps: `Security.X509Credentials` does not exist on the instance; execute-mcp uses `%SYS.X509Credentials`. MCP: iris_x509_manage:list/get |
| SS-03 | OAuth 2.0 client: server descriptions list | list | admin-v2 GET /security/oauth2/client/server-definitions | yes | S | MCP: iris_oauth_list:server |
| SS-04 | OAuth 2.0 client configurations list / delete | list / delete | admin-v2 /security/oauth2/client/client-configurations | list yes / delete no | S | MCP: iris_oauth_list:client; iris_oauth_manage:delete. Co-pilot column says read |
| SS-05 | OAuth 2.0 resource server list | list | admin-v2 GET /security/oauth2/resource-servers | yes | S | No MCP tool |
| SS-06 | OAuth 2.0 authorization server: view configuration (issuer, scopes, grant types, keys) | detail (view) | admin-v2 GET /security/oauth2/server | yes | S | Editor is SS-26 (P1) |
| SS-07 | OAuth 2.0 server client descriptions list / delete | list / delete | admin-v2 GET /security/oauth2/server/clients, DELETE /client | list yes / delete no | S | Editor is SS-27 (P1) |
| SS-08 | LDAP / Kerberos configurations list | list | admin-v2 GET /security/ldap/configurations | yes | S | MCP: iris_ldap_manage:list/get |
| SS-09 | Enable / disable auditing (two SMP leaves) | enable-disable | admin-v2 GET/PUT /security/audit/enabled | GET yes / PUT no | S | SMP source is legacy CSP `/csp/sys/sec/UtilSecAction.csp` (never exported). MCP: iris_audit_manage:enable/disable |
| SS-10 | Wallet: collections list and secrets list / create / edit / delete (contest-named; no SMP page) | list / create / edit / delete | admin-v2 /wallet/collections, /wallet/collection, /wallet/secrets, /wallet/secret (%Admin_Wallet) | unknown (route named in UrlMap; undocumented; no SMP page to compare) | M | Judgment call: P0 on the hidden route alone because the contest names wallet. No MCP tool |
| SS-11 | X.509 credential create (import cert/key) / edit / delete | create / edit / delete | admin-v2 POST/PUT/DELETE /security/x509-credential | no — write payload untested | M | Backing class open (see SS-02). MCP: iris_x509_manage:import/delete |
| SS-12 | Configure system audit events (change status, reset counters; Selective SQL Auditing wizard) | edit / enable-disable | admin-v2 GET/PUT /security/audit/events, /event, /clear-count | GET yes / PUT no | M | SMP: Audit.SystemEvents; Audit.SelectiveWizard. MCP: iris_audit_manage:configureEvent |
| SS-13 | Configure user audit events (create, change status, reset, delete) | create / edit / delete | admin-v2 /security/audit/event GET/PUT/DELETE | GET yes / writes no | M | MCP: iris_audit_manage:configureEvent |
| SS-14 | View audit database (search by time, source/type/name, user, PID, namespace, auth, JSON text; detail dialog) | list / detail | admin-v2 POST /security/audit/records, GET /record | unknown (POST search; Evidence cites api-coverage only, no verify) | L | SMP: Audit.View (555); Audit.Detail. MCP: iris_audit_events. Duplicated as LG-02 |
| SS-15 | SSL/TLS configuration create / edit / delete (certs, key, CA, CRL, protocol min/max, ciphers, DH bits, OCSP, peer verification) | create / edit / delete | admin-v2 GET/PUT/DELETE /security/ssl-configuration | GET yes / writes no | L | SMP: %CSP.UI.Portal.SSL (831). MCP: iris_ssl_manage. Test connection is SS-17 (P1) |
| SS-16 | LDAP / Kerberos configuration create / edit / delete | create / edit / delete | admin-v2 GET/PUT/DELETE /security/ldap/configuration | GET yes / writes no | L | SMP: %CSP.UI.Portal.LDAP (797). MCP: iris_ldap_manage:create/modify/delete |

### (f) Tasks: scheduling and history — TM P0 rows

| ID | Name | Kind | Backing API route or class | Observed-live? | Size | Notes |
|---|---|---|---|---|---|---|
| TM-01 | Task schedule list (all scheduled tasks; filter; Task Manager status) | list | admin-v2 GET /tasks, GET /task/manager | yes (api-coverage-verify C4) | S | MCP: iris_task_list. Co-pilot: read |
| TM-02 | On-demand tasks list with Run | list / action | admin-v2 GET /tasks (client filter on-demand), POST /task/run | GET yes / POST no | S | MCP: iris_task_list; iris_task_run. Co-pilot: write-confirm |
| TM-03 | Upcoming tasks (next N hours / until date) | list | admin-v2 GET /task/upcoming | yes | S | No MCP tool |
| TM-04 | Task history (all tasks; user-defined filter) | list | admin-v2 GET /task/history | yes | S | MCP: iris_task_history |
| TM-05 | Task history for one task | list | admin-v2 GET /task/history (task filter) | yes | S | MCP: iris_task_history |
| TM-06 | Run task now | action | admin-v2 POST /task/run | no — write payload untested | S | SMP: legacy `UtilSysTaskAction.csp?Type=Run`. MCP: iris_task_run |
| TM-07 | Suspend task | action | admin-v2 POST /task/suspend | no — write payload untested | S | Legacy CSP source |
| TM-08 | Resume task | action | admin-v2 POST /task/resume | no — write payload untested | S | Legacy CSP source |
| TM-09 | Delete task | delete | admin-v2 DELETE /task | no — write payload untested | S | Legacy CSP source. MCP: iris_task_manage:delete |
| TM-10 | Start / suspend / resume the Task Manager | action | admin-v2 POST /task/manager/run, /resume, /suspend | no — write payload untested | S | SMP: TaskSchedule ribbon |
| TM-11 | Task details (properties, schedule, last run, next run; auto-refresh) | detail | admin-v2 GET /task/info, GET /task | yes | M | SMP: %CSP.UI.Portal.TaskInfo. Depends on SH-09 |
| TM-12 | New task wizard (name, description, namespace, task type from %SYS.Task.Definition list, priority, run-as, output file, suspend-on-error, reschedule-after-restart, schedule daily/weekly/monthly/after-task/on-demand, expiry, email) | create (wizard) | admin-v2 POST /task | no — write payload untested | L | SMP: legacy `UtilSysTaskBuilder.csp` frameset (never exported). MCP: iris_task_manage:create |
| TM-13 | Edit task | edit | admin-v2 PUT /task | no — write payload untested | L | SMP: legacy `UtilSysTaskOption.csp` — rendered empty; field list taken from the New Task wizard (Gap). MCP: iris_task_manage:modify |

### (g) OS management — OS P0 rows

| ID | Name | Kind | Backing API route or class | Observed-live? | Size | Notes |
|---|---|---|---|---|---|---|
| OS-01 | Processes list (filter, page size, max rows, persisted sort, auto-refresh; Details link) | list | admin-v2 GET /processes | yes (api-coverage-verify C4) | S | MCP: iris_jobs_list; iris_process_manage:get. Depends on SH-09 |
| OS-02 | Terminate process (with optional RESJOB error) | action | admin-v2 POST /process/terminate | no — write payload untested | S | MCP: iris_process_manage:terminate |
| OS-03 | Suspend process | action | admin-v2 POST /process/suspend | no — write payload untested | S | MCP: iris_process_manage:suspend |
| OS-04 | Resume process | action | admin-v2 POST /process/resume | no — write payload untested | S | MCP: iris_process_manage:resume |
| OS-05 | System usage counters (global refs, routine calls, block reads/writes, journal entries; refresh interval) and shared-memory usage | list (counters) | admin-v2 GET /monitor/system-usage, /system-usage/shared-memory | yes | S | SMP: legacy `UtilSysMonitor.csp` (never exported). MCP: iris_metrics_system |
| OS-06 | Locks view (namespace selector, filter, owner routine info, SQL table name; owner links to process) | list | admin-v2 GET /locks | yes | S | Judgment call: P0 (tier rules said P2). MCP: iris_locks_list |
| OS-07 | Remove one lock / all locks for a process / all locks from a remote client (transaction warning) | delete | admin-v2 DELETE /lock | no — write payload untested | S | Judgment call: P0. No MCP tool |
| OS-08 | Process details (dashboard meters, client EXE/IP, open devices, optional SQL statement info; auto-refresh) | detail | admin-v2 GET /process | yes | M | MCP: iris_process_manage:get |
| OS-09 | CPU, memory and performance meters (System Performance / System Usage / System Status groups of the dashboard; Prometheus gauges) | list (meters) | admin-v2 GET /monitor/dashboard/main; monitor GET /api/monitor/metrics | yes | M | SMP: legacy `UtilDashboard.csp` (never exported; meter names not captured). MCP: iris_metrics_system; iris_health_check |
| OS-10 | Disks: local databases list with General and Free-space views (size, max, free, status, directory, mounted) | list | admin-v2 GET /databases, /database-dirs; POST /database-dir/info (async) | GET yes / async POST unknown | M | MCP: iris_database_list; iris_database_check. Satisfies contest "disks" |
| OS-11 | Database details (properties, volume files, background tasks running against the DB; auto-refresh) | detail | admin-v2 GET /database-dir, /database-dir/volumes | yes | M | MCP: iris_database_check |
| OS-12 | Devices list / create / edit / delete (contest-named "devices") | list / create / edit / delete | admin-v2 GET /devices, GET/PUT/DELETE /device | GET yes / writes no | M | SMP: %CSP.UI.Portal.Config.Devices / Config.Device. Judgment call: P0 because the contest names devices. No MCP tool |

### (h) Logs: the four viewers — LG P0 rows

| ID | Name | Kind | Backing API route or class | Observed-live? | Size | Notes |
|---|---|---|---|---|---|---|
| LG-01 | alerts.log viewer (entries since last scrape from the official route plus custom tail of the file for history) | list | monitor GET /api/monitor/alerts; custom(file tail) | official route yes / custom tail no | S | SMP: new. Judgment call: P0 though not an SMP page. MCP: iris_metrics_alerts |
| LG-02 | Audit database viewer (contest "all the logs"; inventoried at SS-14) | list / detail | admin-v2 POST /security/audit/records | unknown (see SS-14) | L | Deliberate duplicate of SS-14. MCP: iris_audit_events |
| LG-03 | messages.log viewer (full text, search and highlight, goto top/bottom, tail) | other (text-file viewer) | custom(read <mgr>/messages.log via %Stream.FileCharacter; backing class unresolved) | no — custom; backing class unresolved | M | SMP: legacy `UtilSysConsoleLog.csp` (%CSP.UI.System.ViewTextFilePane) never exported. P0 despite needing a custom endpoint (legend) |
| LG-04 | Application error log: namespaces → dates → errors drill-down; delete by namespace / by error | list (drill-down) / delete | custom(^ERRORS / SYS.ApplicationError; class unresolved on instance) | no — custom; backing class unresolved | M | SMP: legacy `UtilSysAppErrorNamespaces/Dates/Errors.csp` never exported. P0 despite needing a custom endpoint (legend) |

### (i) Submission deliverables — PK P0 rows

| ID | Name | Kind | Backing API route or class | Observed-live? | Size | Notes |
|---|---|---|---|---|---|---|
| PK-01 | README in English: installation steps, video demo or detailed description, link to the Ideas Portal idea, team profile links | other (deliverable) | none | no — no server call | S | contest-rules General Requirements |
| PK-02 | Public GitHub (or GitLab) repository with an open-source license file | other (deliverable) | none | no — no server call | S | |
| PK-03 | Open Exchange listing published before applying; apply through the contest page after 2026-09-14 | other (deliverable) | none | no — no server call | S | |
| PK-04 | Contest application submitted by 2026-09-27 23:59 US Eastern; keep improving during voting to 2026-10-04 | other (deliverable) | none | no — no server call | S | |
| PK-05 | Ideas Portal idea for OcuPilot (satisfies the README "link to the idea" and the precedent 2-point bonus) | other (deliverable) | none | no — no server call | S | Judgment call: P0 (earlier tier wins over the P1 bonus rule) |
| PK-06 | Community Edition compatibility (IRIS CE and IRIS for Health CE; no HealthShare-only dependencies; hidden /api/admin verified on both) | other (constraint) | admin-v2 GET /info on stock image | yes (api-coverage-verify C8) | S | |
| PK-07 | Name-collision avoidance: package OcuPilot, web apps /ocupilot and /ocupilot/api; never SessionAgent.*, ExecuteMCPv2, IRISCouch, %ALL creation, /csp/<ns>/sa-static | other (constraint) | none | no — no server call | S | Harvest: names-to-avoid lists from all three sibling projects |
| PK-08 | Web Gateway response timeout ≥ 300 s documented as an install prerequisite for agent turns | other (constraint) | none | no — no server call | S | Pairs with CP-19 |
| PK-09 | Pin /api/admin to v2, guard on GET /info apiVersion, and keep the auto-generated spec (GET /api/mgmnt/v1/%25SYS/spec/api/admin) under test | other (constraint) | admin-v2; mgmnt | yes (api-coverage Mgmnt live results) | S | Pairs with SH-11 |
| PK-10 | IPM module.xml: WebApplication (not deprecated CSPApplication), FileCopy of the Angular dist, Resource OcuPilot.PKG, Invoke installer, SystemRequirements (IRIS 2022.1+, IPM 0.10.x), ${globalsDbRole} | other (packaging) | none | no — no server call | M | |
| PK-11 | Angular bundle served from an IRIS web app: ServeFiles, AutheEnabled 64 (unauthenticated static like /ui/interop; the shell logs in itself), non-root base href, deep-link fallback through a %CSP.REST catch-all; no Group by ID needed on the static app | other (packaging) | custom(%CSP.StreamServer.Page catch-all) | no — custom | M | Harvest: iris-couch AdminUIHandler |
| PK-12 | OcuPilot REST web app (/api/ocupilot: AutheEnabled 32, JWTAuthEnabled 1, UseSession 0, GroupById %ISCMgtPortal per the silent-first design; %CSP.REST router with per-area handler classes; accepts the same Bearer as /api/admin) | other (packaging) | custom(OcuPilot.API.Router) | no — custom | M | Harvest: iris-couch Router / Util.Error / Util.Request |
| PK-13 | Idempotent installer class (web apps, role/resource, %SYS audit events guarded by Exists, seed agent config Enabled=0, tasks; %SYS save/restore; uninstall) | other (packaging) | custom(OcuPilot.Installer) | no — custom | M | Uninstall hook proper is PK-21 (P1) |
| PK-14 | Docker self-install: Dockerfile FROM intersystemsdc/irishealth-community (build-time RUN iris start, iris session < iris.script, iris stop), iris.script unexpires passwords, picks HSCUSTOM else USER, zpm load; docker-compose with ports offset as in this repo | other (packaging) | none | no — no server call | M | |
| PK-15 | Angular build committed or produced before zpm package (dist must be inside the IPM archive) | other (packaging) | none | no — no server call | S | |

## 3. P1 rows by area (compact)

### (a) Shell and navigation — SH P1

| ID | Name | Kind | Size | Note |
|---|---|---|---|---|
| SH-12 | Change own password | action | S | admin-v2 POST /security/user/password; judgment call kept it P1 though it is a header link with a route |
| SH-13 | Favorites (add from finder, remove, clear; per user) | other | S | custom(%CSP.Portal.Utils) or OcuPilot per-user store |
| SH-14 | Recent items (auto-registered pages; remove, clear) | other | S | custom or local |
| SH-15 | Menu search typeahead (name/title/tags of entitled menu items) | other | S | client-side only |
| SH-16 | About page (14 system-overview fields; session language selector) | detail | S | admin-v2 GET /info, /license/key, /journal/settings; custom for cache sizes |
| SH-17 | Help link per screen (DocBook HELPADDRESS) | other | S | no server call |
| SH-18 | Menu drop-down of 16 fixed shortcuts filtered by access | other | S | no server call |
| SH-19 | Home "System Information" panel (uptime, mirror, DB/journal/lock/write-daemon alerts, production status) | detail | M | admin-v2 GET /monitor/dashboard/main; interop-v7 /productions/status; MCP iris_health_check |
| SH-20 | Links panel (Documentation, Support, InterSystems home) | other | S | no server call |
| SH-21 | UI state persistence (selected category, view mode, panel widths) | other | S | localStorage |
| SH-22 | Light/dark theme (community-requested dark mode) | other | S | table-editor --ite-* theme tokens |

### (b) Agent co-pilot core — CP P1

| ID | Name | Kind | Size | Note |
|---|---|---|---|---|
| CP-23 | Suggested prompts per screen (grouped by task) | other (cross-cutting) | S | agent-patterns pattern 9 |
| CP-24 | "Explain this screen" action (summarise current page data and available actions) | agent tool (read) | S | agent-patterns pattern 10 |
| CP-25 | "Explain this log entry" / explain error code action | agent tool (read) | S | custom(SessionAgent.Tool.Inspection.ExplainError) |
| CP-26 | Agent audit viewer (LlmCall / ToolCall ledger with filters, per-user and per-screen) | list | M | custom(SQL over SessionAgent_Audit tables) |
| CP-27 | Citations back to rows and tools used (citation chips with click-through) | other | M | custom(RecordClickThrough) |
| CP-28 | Token metering (UsageRollup per turn; per-user/day totals shown in panel and audit viewer) | other | M | custom(LlmCall usage columns) |
| CP-29 | Log-content sanitisation / untrusted-content boundary for tool results and log text (prompt-injection defence) | other | M | no source found in any harvest (gap) |
| CP-30 | Copy-out drafts (agent offers ObjectScript / CLI / REST snippet instead of executing when the user prefers) | other | S | agent-patterns pattern 3 |
| CP-31 | Data-egress disclosure in the panel (which provider, that screen data leaves the instance) | other | S | no server call |
| CP-32 | Chat history persistence keyed by screen/route with retention purge task | other | M | custom(SessionAgent.Chat.History; Task.PurgeStaleSearchChat) |
| CP-33 | Tool governance policy (per tool:action enable/disable, read-only/full presets, default-disabled destructive writes, GOVERNANCE_DISABLED denial) with a policy viewer | enable-disable / list | M | execute-mcp governance.ts model; MCP iris_server_profiles |

### (c) Web applications and REST API explorer — WA P1

| ID | Name | Kind | Size | Note |
|---|---|---|---|---|
| WA-08 | Try-it request console against a REST endpoint (send request with current session, show status/body) | other (console) | M | none (browser fetch same-origin); depends on session cookie per CookiePath |
| WA-09 | Web sessions list (user, app, PID link) and End Session | list / delete | M | admin-v2 GET /web-sessions, DELETE /web-session; judgment call kept it P1 |

### (d) Permissions — PM P1

| ID | Name | Kind | Size | Note |
|---|---|---|---|---|
| PM-17 | User profile: effective privileges (roles, resources, applications, databases, services) | detail | M | admin-v2 composed from /security/user, /roles, /resources, /web-apps, /databases |
| PM-18 | Permission check tool (does user/role hold resource:permission; %All short-circuit) | agent tool (read) | S | custom(Security.Users / Security.Roles); MCP iris_permission_check |

### (e) Security and secrets — SS P1

| ID | Name | Kind | Size | Note |
|---|---|---|---|---|
| SS-17 | SSL/TLS test connection | action | S | admin-v2 POST /security/ssl-configuration/test |
| SS-18 | X.509 view certificate details | detail | S | admin-v2 GET /security/x509-credential/certificate |
| SS-19 | LDAP test authentication | action | S | admin-v2 POST /security/ldap/test, /search-password; MCP iris_ldap_manage:test |
| SS-20 | OAuth 2.0 administration: revoke a user's tokens | action | S | admin-v2 POST /security/oauth2/server/revoke |
| SS-21 | Copy audit log to namespace (background) | action | S | admin-v2 POST /security/audit/record/copy |
| SS-22 | Purge audit log older than N days | action | S | admin-v2 POST /security/audit/record/purge; execute-mcp confirm gate |
| SS-23 | OAuth 2.0 resource server editor (definition, service mappings, audiences) | create / edit | M | admin-v2 /security/oauth2/resource-server, /mappings |
| SS-24 | OAuth 2.0 client server-description editor (Discover and Save, Update JWKS) | create / edit | L | admin-v2 /client/server-definition CRUD; MCP iris_oauth_manage:create/discover |
| SS-25 | OAuth 2.0 client configuration editor (Rotate Keys, secrets, register-client, initial access token) | create / edit | L | admin-v2 /client-configuration CRUD, /secrets, /rotate-keys, /register-client, /initial-access-token |
| SS-26 | OAuth 2.0 authorization server editor (Save, Delete, Rotate Keys, scopes add/remove) | create / edit / delete | L | admin-v2 PUT /security/oauth2/server, /password, /rotate |
| SS-27 | OAuth 2.0 server client description editor (Update JWKS, redirect URLs, secret) | create / edit | L | admin-v2 /server/client CRUD, /secret |

### (f) Tasks — TM P1

| ID | Name | Kind | Size | Note |
|---|---|---|---|---|
| TM-14 | Export task to file | action | S | custom(%SYS.Task export); legacy `UtilSysTaskAction.csp?Type=Export` |
| TM-15 | Import tasks from file | action | M | custom(%SYS.Task import); legacy CSP |
| TM-16 | Portal background tasks list (status, namespace, details, error count; Cancel / Pause / Resume; Purge) | list / action | M | admin-v2 /async-results (tracks %Api.Admin async tasks only) plus custom(%CSP.UI.System.BackgroundTask) for SMP tasks — judgment call |

### (g) OS management — OS P1

| ID | Name | Kind | Size | Note |
|---|---|---|---|---|
| OS-13 | Broadcast a message to selected processes | action | M | admin-v2 POST /process/broadcast |
| OS-14 | License usage (summary, by process, by user, distributed) | list | S | admin-v2 GET /monitor/license-usage; MCP iris_license_info |
| OS-15 | Read-only System Dashboard main panel (7 meter groups: performance, ECP/shadowing, status, usage, errors and alerts, licensing, task manager) | list (meters) | M | admin-v2 GET /monitor/dashboard/main; legacy `UtilDashboard.csp`; meter names not captured (Gap) |

### (h) Logs — LG P1 plus the two cross-listed secondary log viewers

| ID | Name | Kind | Size | Note |
|---|---|---|---|---|
| LG-05 | System Monitor log viewer (SystemMonitor.log or chosen file; search, highlight) | other (text-file viewer) | S | custom(file read; directory allow-list) |
| LG-06 | Background task error log | list | S | custom(%CSP.UI.System.BackgroundTask:ErrorLog) |
| LG-07 | xDBC error log (namespaces with errors → errors; delete selected / all) | list / delete | M | atelier POST /:ns/action/query CALL %SQL.Manager.Catalog queries |
| LG-08 | SQL diagnostics log (%SQL_Diag.Result per namespace; detail panel; delete) | list / detail / delete | M | atelier POST /:ns/action/query on %SQL_Diag.Result |
| LG-09 | Interoperability event log (secondary log viewer; leaf inventoried at IO-34) | list | M | custom(Ens_Util.Log SQL); interop-v7 per-host /log; duplicate of IO-01 (note the catalog text says "IO-34" but the duplicate row is IO-01) |
| LG-10 | Unified log hub (one screen listing every log source with counts, last entry and "explain" entry points) | list (hub) | M | composes the rows above; agent-patterns pattern 5 |
| IO-01 (section 11) | Event log (search/filter by type, time, source item, session, text; auto-refresh; purge) — P1 as a secondary log viewer (see LG-09) | list / action | M | custom(Ens_Util.Log SQL via atelier action/query; interop-v7 per-host /log only); MCP iris_production_logs. *Judgment:* cross-listed here |
| AN-01 (section 12) | Analytics log viewer (DeepSee log file; refresh, delete) | other (text-file viewer) / delete | S | custom(%DeepSee.Utils.%GetLogFileName / %KillLogFile); judgment call: P1 by analogy. *Judgment:* cross-listed here |

### (i) Submission deliverables — PK P1

| ID | Name | Kind | Size | Note |
|---|---|---|---|---|
| PK-16 | Online demo instance (precedent 2-point bonus) | other (deliverable) | M | contest-rules Bonus table |
| PK-17 | Developer Community article (first 2 points, second 1 point precedent) | other (deliverable) | S | |
| PK-18 | YouTube video (3) and YouTube Short (1) precedent bonuses | other (deliverable) | S | |
| PK-19 | Watch for the Technology Bonuses post (expected around the 2026-09-14 kick-off webinar) and re-plan bonus items | other (process) | S | bonuses for contest 48 unpublished (Gap) |
| PK-20 | Freshmen nomination eligibility check (≤5 prior contests, no prior top-3) | other (process) | S | |
| PK-21 | Uninstall hook removing web apps, role, tasks, audit events, globals | other (packaging) | S | custom(OcuPilot.Installer.Uninstall) |
| PK-22 | %UnitTest suite with HTTP integration harness (MakeRequest helper, single-envelope assertion, per-test web-app path) | other (test) | M | iris-couch HttpIntegrationTest; session-agent ProviderOverride mocks |
| PK-23 | CI: build Angular, lint, no-CDN and no-embedded-Python greps, self-hosted IRIS smoke | other (CI) | M | session-agent ci.yml; iris-couch ui-smoke.yml |
| PK-24 | Publish the package to pm.community.intersystems.com (or GHCR via ORAS) | other (deliverable) | S | packaging Publishing |

### Unmapped P1 rows (fit none of the nine areas)

| ID | Name | Kind | Size | Note |
|---|---|---|---|---|
| SA-01 | External language servers list with status; Start / Stop / Status / Activity log per server | list / action | M | admin-v2 GET /ext-lang-servers, POST /ext-lang-server/start, /stop, GET /activity; P1 per the tier rule ("external language servers") |
| SA-02 | External language server create / edit / delete (Java, .NET, Python, R, XSLT; advanced settings) | create / edit / delete | L | admin-v2 GET/PUT/DELETE /ext-lang-server |

## 4. Judgment calls (verbatim from the catalog; 28 bullets)

- **CP-01 reworded at the project owner's direction (2026-09-08)**: the panel is always visible in the VS Code secondary-side-bar sense; the earlier "collapse" wording is withdrawn. Narrow-viewport behaviour (a bottom sheet or overlay under about 900 px) is a UX decision, not a catalog row.
- **CP-42 / CP-43 added at the project owner's direction (2026-09-08)**: screens must reflect agent changes immediately. CP-42 (screen synchronisation) is the stated requirement; CP-43 (agent-driven navigation) is placed at P0 with it because synchronisation alone only helps when the user is already on the affected screen.
- **OS-06 / OS-07 Locks view and remove at P0.** The tier rules list "locks view and remove" under P2, but locks are process-adjacent OS management, the admin-v2 routes exist and both are S complexity; "choose the earlier tier" was applied.
- **OS-16..OS-22 database mount / dismount / truncate / compact / defragment / integrity / expand at P2, not P0.** The contest says "disks", which the database list with free space (OS-10, OS-11) satisfies; the explicit P2 list names these operations, so they stay P2.
- **OS-12 Devices at P0 while IO settings, subtypes, magnetic tapes and Telnet are P4.** The contest names "devices"; the P4 rule names only the low-usage device sub-pages.
- **SS-10 Wallet at P0** with only the hidden admin-v2 route as backing (no SMP page exists). The contest names wallet explicitly; the route is instance-verified but undocumented.
- **LG-01 alerts.log at P0.** Not an SMP page, but an official route exists and the contest asks for "all the logs".
- **SS-14 / LG-02 audit viewer counted in area 3 and repeated in area 6**; LG-09 likewise repeats IO-01 (interop event log). Both duplicates are deliberate so each contest area reads complete; the summary counts include them twice.
- **WA-09 Web sessions at P1, not P0.** It is a System Operation leaf with an admin-v2 route, but not a web-application list/detail/CRUD screen; P0 was kept lean.
- **OAuth 2.0 lists and read views at P0, editors at P1** (SS-03..SS-07 vs SS-23..SS-27), following the tier rule "OAuth 2.0 full editors if only list/view made P0".
- **OS-26 Memory and startup configuration at P3** while memory monitoring (OS-05, OS-09) is P0: the contest's "memory" is read as monitoring; configuration has no route.
- **IO-01 Interop event log at P1** because the tier rules name it a secondary log viewer, even though it needs a custom endpoint (the P2/P3 definitions would put it at P3).
- **AN-01 Analytics log at P1** as a secondary log viewer by analogy; it is not in the explicit P1 list.
- **PK-05 Ideas Portal idea at P0.** The README requirement includes "a link to the idea" (P0) while the tier rules list the idea under P1 bonuses; the earlier tier wins.
- **SH-09 Auto-refresh framework at P0** because the Processes, Databases and Task pages depend on it; it could be argued P1.
- **SH-12 Change own password at P1**, although it is a header link with an admin-v2 route.
- **IO-20 / IO-21 X12 and ASTM schema browsing at P2 via the read-only schema-viewer embed** while their import/export/delete authoring is P4 per the non-HL7 EDI rule; the shared EDIDocumentView document viewers for X12/ASTM/EDIFACT/XML (IO-67..IO-70) are P3 because one class serves all five families with a `NAME=` parameter.
- **IO-45 / IO-46 service registries at P3** rather than P4: they are on the menu, but the classes are hidden and their action sets are estimated.
- **EX-51 / EX-52 SQL troubleshooting report generate/import at P3** (WRC support workflow; not in the P4 list).
- **EX-55 FileMan wizard at P4** although FileMan is not in the explicit P4 list (VA-specific legacy wizard).
- **CP-34 streaming at P2 and CP-40 undo/rollback at P3.** The P2/P3 definitions are written for SMP parity; for co-pilot features P2 was read as "API exists or is a bounded extension" and P3 as "new server-side path".
- **TM-16 portal Background Tasks at P1** mapped onto admin-v2 `/async-results`, which tracks `%Api.Admin` async tasks, not `%CSP.UI.System.BackgroundTask` jobs; full parity needs the custom part too.
- **SO-06 journal record browser kept in System Operation (P2)** rather than area 6, because the journal is a transaction record, not an operator log.
- **IO-31 delete production at P3**: interop-v7 exposes GET/POST on `/productions/{class}` but no delete, so it falls to custom even though the other lifecycle actions are P2.
- **EX-15 SQL DML/DDL guard at P2** although the agent SQL tool it protects is P0: the P0 read tools use catalog SELECTs only; the free-form SQL console is P2.
- **SS-29 Superservers at P2** per the explicit list, although it sits under Security in the SMP.
- **SA-01 / SA-02 External language servers at P1** per the tier rule, ahead of all other System Administration remainder rows.
- **DT-11 remote instance profiles at P3** (single-instance product) rather than P4, because DT-09/DT-10 depend on it.

## 5. Count summary

### Rows per catalog section per tier (matches the catalog's own summary table; re-tallied by script from the 538 rows)

| Catalog section | Prefix | PRD area | P0 | P1 | P2 | P3 | P4 | Total |
|---|---|---|---|---|---|---|---|---|
| 0. Portal shell and platform | SH | (a) | 11 | 11 | 3 | 3 | 1 | 29 |
| 1. Co-pilot agent | CP | (b) | 24 | 11 | 7 | 1 | 0 | 43 |
| 2. Area 1: Web apps and REST APIs | WA | (c) | 7 | 2 | 5 | 2 | 1 | 17 |
| 3. Area 2: Permission management | PM | (d) | 16 | 2 | 4 | 2 | 0 | 24 |
| 4. Area 3: Security and secrets | SS | (e) | 16 | 11 | 8 | 4 | 1 | 40 |
| 5. Area 4: Task management | TM | (f) | 13 | 3 | 0 | 3 | 0 | 19 |
| 6. Area 5: OS management | OS | (g) | 12 | 3 | 9 | 6 | 4 | 34 |
| 7. Area 6: All the logs | LG | (h) | 4 | 6 | 1 | 1 | 1 | 13 |
| 8. System Administration, remainder | SA | — (SA-01/02 unmapped) | 0 | 2 | 20 | 27 | 13 | 62 |
| 9. System Operation, remainder | SO | — | 0 | 0 | 8 | 9 | 2 | 19 |
| 10. System Explorer and data browser | EX | — (EX-01 → (a)) | 1 | 0 | 33 | 20 | 4 | 58 |
| 11. Interoperability | IO | — (IO-01 → (h)) | 0 | 1 | 28 | 69 | 20 | 118 |
| 12. Analytics | AN | — (AN-01 → (h)) | 0 | 1 | 9 | 7 | 7 | 24 |
| 13. Developer tools and sibling-tool equivalents | DT | — | 0 | 0 | 1 | 10 | 1 | 12 |
| 14. Packaging, deployment and submission | PK | (i) | 15 | 9 | 1 | 0 | 1 | 26 |
| **All sections** | | | **119** | **62** | **137** | **164** | **56** | **538** |

### Rows per PRD area per tier (after the mapping in section 2)

| PRD area | P0 | P1 | P2 | P3 | P4 |
|---|---|---|---|---|---|
| (a) Shell and navigation (SH + EX-01) | 12 | 11 | 3 | 3 | 1 |
| (b) Agent co-pilot core (CP) | 24 | 11 | 7 | 1 | 0 |
| (c) Web apps and REST API explorer (WA) | 7 | 2 | 5 | 2 | 1 |
| (d) Permissions (PM) | 16 | 2 | 4 | 2 | 0 |
| (e) Security and secrets (SS) | 16 | 11 | 8 | 4 | 1 |
| (f) Tasks (TM) | 13 | 3 | 0 | 3 | 0 |
| (g) OS management (OS) | 12 | 3 | 9 | 6 | 4 |
| (h) Logs (LG + IO-01 + AN-01) | 4 | 8 | 1 | 1 | 1 |
| (i) Submission deliverables (PK) | 15 | 9 | 1 | 0 | 1 |
| Unmapped P1 (SA-01, SA-02) | 0 | 2 | — | — | — |
| **Nine areas + unmapped** | **119** | **62** | | | |

P2–P4 columns for the areas count only the mapped prefix; the remaining P2–P4 rows (SA, SO, EX, IO, AN, DT) are outside the nine areas and are not repeated here.

### P0 rows per area per size

| PRD area | S | M | L | P0 total |
|---|---|---|---|---|
| (a) Shell and navigation | 7 (6 SH + EX-01) | 5 | 0 | 12 |
| (b) Agent co-pilot core | 13 | 9 | 2 | 24 |
| (c) Web apps and REST API explorer | 4 | 2 | 1 | 7 |
| (d) Permissions | 9 | 4 | 3 | 16 |
| (e) Security and secrets | 9 | 4 | 3 | 16 |
| (f) Tasks | 10 | 1 | 2 | 13 |
| (g) OS management | 7 | 5 | 0 | 12 |
| (h) Logs | 1 | 2 | 1 | 4 |
| (i) Submission deliverables | 10 | 5 | 0 | 15 |
| **Total P0** | **70** | **37** | **12** | **119** |

**The twelve P0 rows sized L** (eleven distinct, because LG-02 duplicates SS-14): CP-12, CP-13, WA-05, PM-07, PM-12, PM-16, SS-14, SS-15, SS-16, TM-12, TM-13, LG-02. *Extractor's note:* the product brief's figure of 22 large P0 rows is not supported by the catalog; adding the five P1 L rows (SS-24, SS-25, SS-26, SS-27, SA-02) gives 17, and no other combination of the catalog's counts produces 22.

### P0 and P1 rows by co-pilot tool column

| Tier | read | write-confirm | none |
|---|---|---|---|
| P0 | 38 | 37 | 44 |
| P1 | 22 | 15 | 25 |

## 6. Flags

Every P0 or P1 row that (i) depends on an admin-v2 write payload that has never been observed, (ii) rests on an undocumented route, (iii) comes from a legacy CSP page whose source was never exported, or (iv) carries a backing marked uncertain. Sources: the API-backing column, the SMP-source column, the Evidence column and the catalog's Gaps section.

### (i) Rows depending on an unobserved admin-v2 write payload

Gaps: "/api/admin request and response schemas were observed only for list/get shapes; write payloads for every admin-v2 row are untested, and the v1 UrlMap was read only partially (PATCH/DELETE variants)." Every row below is therefore build-against-an-unverified-contract.

| Tier | Rows |
|---|---|
| P0 | WA-02, WA-03, WA-04, WA-05 (PUT half); PM-02, PM-03, PM-04, PM-05, PM-06, PM-07 (PUT), PM-09, PM-10, PM-11, PM-12 (PUT), PM-14 (PUT/DELETE), PM-16 (PUT); SS-04 (delete), SS-07 (delete), SS-09 (PUT), SS-10 (all wallet writes), SS-11, SS-12 (PUT), SS-13 (PUT/DELETE), SS-15 (PUT/DELETE), SS-16 (PUT/DELETE); TM-02 (POST /task/run), TM-06, TM-07, TM-08, TM-09, TM-10, TM-12, TM-13; OS-02, OS-03, OS-04, OS-07, OS-10 (POST /database-dir/info async), OS-12 (PUT/DELETE); CP-13 (write tools inherit every one of the above) |
| P1 | SH-12; WA-09 (DELETE /web-session); SS-17, SS-19, SS-20, SS-21, SS-22, SS-23, SS-24, SS-25, SS-26, SS-27; TM-16 (POST cancel/pause/resume); OS-13; SA-01 (POST start/stop), SA-02 |

Observed exceptions among admin-v2 POSTs: SH-01 (`/login`, `/refresh`) and SH-10 (`/logout`) were exercised in the auth spike.

### (ii) Rows whose only backing is an undocumented route

`admin-v2` is by definition "instance-verified, undocumented"; **every admin-v2 row in sections 2 and 3 is on a hidden API** that InterSystems does not document and could change. The rows with no documented fallback at all (no official route, no custom class named) are the sharpest exposure:

- **SS-10 Wallet** — the judgment calls single this out: P0 "with only the hidden admin-v2 route as backing (no SMP page exists) … the route is instance-verified but undocumented". No MCP tool wraps it.
- **SS-05, SS-07, TM-03, TM-07, TM-08, TM-10, OS-07, OS-12** (P0) and **SS-17, SS-18, SS-20, SS-21, SS-23, SS-27, WA-09, OS-13, SA-01, SA-02** (P1) — admin-v2 only, no MCP tool (`—` in the MCP column), so no sibling handler exists to consult for payload shape.
- **PK-09** exists precisely to contain this risk (pin v2, guard on `/info` apiVersion, keep the auto-generated spec under test); **SH-11** is the runtime guard.

### (iii) Rows whose SMP source is a legacy CSP page that was never exported

Gaps: "Legacy CSP pages were never exported … Their actions are inferred from rendered HTML and pane classes."

| Tier | Row | Legacy page |
|---|---|---|
| P0 | SS-09 | `/csp/sys/sec/UtilSecAction.csp?Action=Enable` / `Disable` |
| P0 | TM-06, TM-07, TM-08, TM-09 | `UtilSysTaskAction.csp?Type=Run` / `Suspend` / `Resume` / `Delete` |
| P0 | TM-12 | `UtilSysTaskBuilder.csp` frameset (New Task wizard) |
| P0 | TM-13 | `UtilSysTaskOption.csp` — **rendered empty** on the instance; field list assumed from TM-12 |
| P0 | OS-05 | `UtilSysMonitor.csp` |
| P0 | OS-09 | `UtilDashboard.csp` — meter names and thresholds not captured |
| P0 | LG-03 | `UtilSysConsoleLog.csp` (%CSP.UI.System.ViewTextFilePane) |
| P0 | LG-04 | `UtilSysAppErrorNamespaces/Dates/Errors.csp` (%CSP.UI.System.ExpResultPane) |
| P1 | TM-14, TM-15 | `UtilSysTaskAction.csp?Type=Export` / `Import` |
| P1 | OS-15 | `UtilDashboard.csp` |

### (iv) Rows whose backing is marked uncertain

| Tier | Row | What the catalog says |
|---|---|---|
| P0 | LG-03 | "backing class unresolved" — `SYS.MessageLog`, `%SYS.LogFile` missing on the instance; assumes a `%Stream.FileCharacter` read of `<mgr>/messages.log` |
| P0 | LG-04 | "class unresolved on instance" — `%SYS.ApplicationError` missing; assumes `^ERRORS` |
| P0 | SS-02, SS-11 | "backing class open" — `Security.X509Credentials` does not exist although `/api/admin` has an X509 endpoint; execute-mcp uses `%SYS.X509Credentials` |
| P0 | SS-14 / LG-02 | POST search route; only list/get shapes were observed, and no verify reference is cited |
| P0 | SS-10 | undocumented route, no SMP page, no MCP tool |
| P0 | CP-06 | "custom(new provider-side method)" — no test-connection ping exists in any harvest source |
| P0 | SH-06 | custom envelope; ReportHttpStatusCode override is a harvest pattern, not a verified behaviour |
| P0 | LG-01 | half custom: `/api/monitor/alerts` returns only entries since the last scrape; the history tail is a custom file read |
| P0 | OS-10 | `POST /database-dir/info` is async; async-result polling semantics not verified |
| P0 | PK-06 | "hidden /api/admin verified on both" editions is cited to api-coverage-verify C8; keep as a test, not an assumption |
| P1 | TM-16 | admin-v2 `/async-results` tracks `%Api.Admin` async tasks, not `%CSP.UI.System.BackgroundTask` jobs; "full parity needs the custom part too" |
| P1 | SH-13, SH-14 | *extractor's note, resolved 2026-09-20:* per user, on the instance (AD-50; epics.md Story 15.2) |
| P1 | SH-16 | "custom for cache sizes" |
| P1 | WA-08 | backing `none` (browser fetch same-origin); rests on the session-cookie-per-CookiePath auth model, which the catalog cites as an analysis, not a live test |
| P1 | IO-01 / LG-09 | custom SQL over `Ens_Util.Log`; interop-v7 exposes only the per-host `/log` |
| P1 | CP-29 | "none found in any source (gap)" — prompt-injection defence has no harvest precedent |
| P1 | OS-15 | meter names and thresholds not captured (Gaps) |
| P1 | PK-16..PK-19 | rest on Full Stack 2026 precedent; "Technology bonuses for contest 48 are unpublished" and may shift after 2026-09-14 |

## 7. Co-pilot read tools vs write tools per screen, and cross-cutting rows

### What the catalog states as the rule

- **Legend (P0 definition):** the co-pilot core includes "read tools for every P0 screen, write tools with propose-review-confirm".
- **CP-12** — "Read tools for every P0 screen (one tool per list/detail endpoint: web apps, users, roles, resources, services, SSL, X.509, OAuth, LDAP, audit, tasks, processes, locks, databases, logs)". API backing: "admin-v2 / official-REST / custom (same endpoints as the screens)". MCP column: "(admin/ops read tools listed per screen)". Tier P0, size L, co-pilot tool `read`.
- **CP-13** — "Write tools with propose → review → confirm (diff of proposed change, rationale, expected impact, explicit confirm before any write)". API backing: "same write endpoints as the screens". MCP column: "(admin/ops write tools listed per screen)". Tier P0, size L, co-pilot tool `write-confirm`. Harvest: agent-patterns pattern 4 and execute-mcp's dry-run + confirm double gate.
- **The per-row "Co-pilot tool" column** is how the rule is applied screen by screen: every list/detail row carries `read`, every create/edit/delete/enable-disable/action row carries `write-confirm`, and platform/UI/deliverable rows carry `none`. Across P0 that is 38 read, 37 write-confirm, 44 none (see section 5). The MCP-tool column on each screen row names the iris-execute-mcp-v2 handler whose read or write logic can be harvested for that tool (`tool:action` where only some actions apply).
- **CP-21 Read-only mode** — "the co-pilot is read/write by default, with every write going through propose-review-confirm"; an admin or per-user switch blocks every mutating tool.
- **CP-14 Runs-as-user** — tools execute under the caller's IRIS privileges; the session-agent `MutatesState` gate is replaced by a per-tool permission check.
- **CP-16** — every agent-initiated write is tagged "via OcuPilot co-pilot" in the IRIS audit description.
- **EX-15 judgment call** narrows the read tools: "the P0 read tools use catalog SELECTs only; the free-form SQL console is P2" — so P0 read tools do not include an arbitrary-SQL tool.
- **CP-33 (P1)** adds a governance policy (per `tool:action` enable/disable, read-only/full presets, default-disabled destructive writes, `GOVERNANCE_DISABLED` denial) with a policy viewer; MCP `iris_server_profiles` exposes the equivalent roster.

### Cross-cutting rows

| Concern | Row | Tier | Size | Catalog wording |
|---|---|---|---|---|
| Refresh-and-highlight after agent writes | **CP-42** | P0 | M | "Screen synchronisation after agent writes: every confirmed write emits a change event (entity type, id, action) that the active screen consumes to re-fetch in place and highlight the changed row or field; a change toast with a link covers screens not currently open." Backing: none (client event bus over the same read endpoints as the screens). Owner requirement 2026-09-08 |
| Navigate-to-screen | **CP-43** | P0 | S | "Agent-driven navigation: browser-side tools the agent can call to open a screen, apply a filter or select an entity, so it can take the user to what it changed or is explaining." Client-side tool executed by the panel; co-pilot tool `read`. Placed at P0 with CP-42 "because synchronisation alone only helps when the user is already on the affected screen" |
| Screen context into every turn | **CP-09** | P0 | M | "Screen-context injection (route, namespace, selected entity, visible rows) into contextHints each turn" — client assembles |
| Context-sharing toggle | **CP-10** | P0 | S | on by default, user can disable per session |
| Explain-this-screen | **CP-24** | P1 | S | "summarise current page data and available actions" — agent-patterns pattern 10 (Elastic contextual insights) |
| Explain-this-log-entry / error code | **CP-25** | P1 | S | custom(SessionAgent.Tool.Inspection.ExplainError); pairs with LG-10's "explain" entry points |
| Suggested prompts | **CP-23** | P1 | S | "Suggested prompts per screen (grouped by task)" — agent-patterns pattern 9 |
| Agent audit viewer | **CP-26** | P1 | M | "Agent audit viewer (LlmCall / ToolCall ledger with filters, per-user and per-screen)" — SQL over SessionAgent_Audit tables; the ledger itself is CP-15 (P0) |
| Citations back to rows/tools | **CP-27** | P1 | M | citation chips with click-through; custom(RecordClickThrough) |
| Copy-out drafts instead of executing | **CP-30** | P1 | S | agent offers ObjectScript / CLI / REST snippet |
| Data-egress disclosure | **CP-31** | P1 | S | which provider; that screen data leaves the instance |
| Unified log hub with explain entry points | **LG-10** | P1 | M | one screen listing every log source with counts, last entry and "explain" entry points |
| Investigate entry points (multi-step run) | CP-37 | P2 | L | on alerts and log entries; agent-patterns pattern 5 |
| Guided workflows from MCP prompts | CP-38 | P2 | M | check-system-health, audit-security-posture, recover-stuck-production, … |
| Undo / rollback of an agent change | CP-40 | P3 | L | snapshot before write, one-click revert — not evidenced in any harvest |

### Which screens get a read tool and which get a write tool (P0, from the Co-pilot tool column)

- **Read tools (P0 screens):** SH-02, SH-03, SH-04, EX-01; WA-01, WA-06, WA-07; PM-01, PM-08, PM-13, PM-15; SS-01..SS-08, SS-14; TM-01, TM-03, TM-04, TM-05, TM-11; OS-01, OS-05, OS-06, OS-08, OS-09, OS-10, OS-11; LG-01..LG-04; plus CP-12 itself and CP-43.
- **Write-confirm tools (P0 actions):** WA-02..WA-05; PM-02..PM-07, PM-09..PM-12, PM-14, PM-16; SS-09..SS-13, SS-15, SS-16; TM-02, TM-06..TM-10, TM-12, TM-13; OS-02..OS-04, OS-07, OS-12; plus CP-13 itself.
- **No tool (P0):** all of SH except SH-02/03/04; CP-01..CP-11, CP-14..CP-22, CP-42; every PK row.
