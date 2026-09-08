---
title: 'Reconciliation: feature catalog vs PRD and addendum'
status: working
created: '2026-09-08'
inputs:
  catalog: '../../research/technical-ocupilot-portal-feature-landscape-2026-09-08/feature-catalog.md'
  prd: 'prd.md'
  addendum: 'addendum.md'
  digests: ['extract-catalog.md', 'extract-stages.md']
---

# Reconciliation: feature catalog vs PRD and addendum

What the user-supplied feature catalog (538 rows) says that the PRD and its addendum did not carry forward, contradicted, or weakened. The catalog was parsed mechanically (all 538 rows, no duplicate IDs, section counts identical to the catalog's own summary table); every `Catalog:` line in the PRD was expanded, ranges included ("SH-12 through SH-22" and the like); the stage tables in `extract-stages.md` were parsed and compared to catalog tiers; then every P0 and P1 row's feature text was read against the FR that cites it. The PRD and addendum were re-read after the owner's 2026-09-08 revision (decision 16), so FR-17's server-side confirmation, FR-20's off-by-default kill switch and the glossary's new terms are already reflected here. Nothing in the inputs was modified.

**Headline verdicts**

- **Row coverage: complete.** Every one of the 119 P0 and 62 P1 rows is cited by at least one FR. One citation is hollow (SH-20, cited only by FR-73's range and never described). Eighteen rows are materially narrowed, one is contradicted (PK-10 vs NFR-13), nine are widened by owner-confirmed additions. See §1.
- **Counts: all match** — 119 P0, 61 polish-week rows, 70/37/12, 38/37/44, stage rows 60/36/41/165/56 (Stage 2 = the extract's 59 + CP-28), sizes and endpoint counts included. See §4.
- **Placement: no undisclosed cross-stage moves.** Every P2–P4 row sits in exactly one stage matching its tier; CP-34 is the sole exception and is the recorded decision. The placement problems are all inside Release 1: the cut line leaves eight P0 write rows unplaced, and FR-12 pulls part of CP-32 (P1) into P0. See §3.
- **The most consequential finding is a metric the catalog cannot satisfy as the PRD applies it:** SM-3 demands one confirmable agent write per area, but area 6 (Logs) has no `write-confirm` row at any Release 1 tier, and FR-17 assigns write tools by that column. See G-3.

## 1. Row coverage (P0 and P1)

### 1.1 Legend

- **covered** — the FR's text carries the row's stated capability; a note records any detail that lives only in the addendum or the catalog.
- **narrowed** — the FR carries less than the row states (a named element, action or tool is dropped), or another PRD statement removes part of it.
- **widened** — the FR adds behaviour the row does not state. All nine are owner-confirmed assumptions (addendum decision 10); listed so epics know they have no catalog evidence and, for three, no verified API field.
- **HOLLOW** — the row is cited but the FR never describes its capability.
- **CONTRADICTED** — the PRD or addendum states the opposite of the row.

The "Cited by" column is the FR whose `Catalog:` line names the row (ranges expanded). FR-16 and FR-17 additionally cover "every read row" and "every write row" in 5.5–5.10 by rule; that rule is tested in G-1 and G-3 rather than credited per row.

### 1.2 Row → FR table

| Row | Tier | Size | Tool | Cited by | Verdict | Note |
|---|---|---|---|---|---|---|
| SH-01 | P0 | M | none | FR-1 | covered | Login: silent empty-body POST /api/admin/login with credentials fir… — Exact refresh timing (exp − iat − 10 s) survives only as "a cushion" in addendum §2. |
| SH-02 | P0 | M | read | FR-4 | narrowed | Access model: route and menu gating from the caller's %Admin_* priv… — FR-4 carries the gating. The row's `read` tool (privilege map) falls outside FR-16, which defines read tools as "every list and detail in the six areas" — gap G-1. |
| SH-03 | P0 | S | read | FR-5 | narrowed | Namespace switch (selector of namespaces the user can read/write; $… — FR-5 carries the switch. Its `read` tool is outside FR-16 (G-1). PRD §8 "Atelier not used in Release 1" forces the admin-v2 `/namespaces` alternative the row also lists. |
| SH-04 | P0 | S | read | FR-5 | narrowed | Header strip: server, instance, namespace, user, licensed-to, serve… — FR-5 carries all six header fields. Its `read` tool (server/instance/license info) is outside FR-16 (G-1). |
| SH-05 | P0 | M | none | FR-4 | covered | Navigation for the six contest areas (category selector, finder col… — Finder "columns/list view" toggle and "Go" not named; low. |
| SH-06 | P0 | M | none | FR-8 | covered | Error handling: uniform error envelope, 401/403 handling, no-privil… — No-privilege tooltips carried by FR-4 rather than FR-8. |
| SH-07 | P0 | S | none | FR-6 | covered | Locator bar / breadcrumbs per page |
| SH-08 | P0 | S | none | FR-6 | covered | Per-page command bar (ribbon commands, view icons, sort options, se… |
| SH-09 | P0 | M | none | FR-7 | widened | Auto-refresh framework for list pages (on/off, rate, last-update st… — FR-7 adds Task schedule (TM-01 has no auto-refresh in the catalog) and the pause-under-proposal rule (owner-confirmed); omits Process details (OS-08), which the catalog marks auto-refresh. |
| SH-10 | P0 | S | none | FR-2 | covered | Logout: POST /api/admin/logout with the Bearer and credentials (end… |
| SH-11 | P0 | S | none | FR-3 | covered | Instance identity and API-version guard on load (serverVersion, nam… |
| SH-12 | P1 | S | none | FR-73 | covered | Change own password |
| SH-13 | P1 | S | none | FR-73 | covered | Favorites (add from finder, remove, clear; per user) |
| SH-14 | P1 | S | none | FR-73 | covered | Recent items (auto-registered pages; remove, clear) |
| SH-15 | P1 | S | none | FR-73 | covered | Menu search typeahead (name/title/tags of entitled menu items) |
| SH-16 | P1 | S | read | FR-73 | narrowed | About page (14 system-overview fields; session language selector) — FR-73 "open About"; the 14 fields are enumerated nowhere; the session language selector is dropped — consistent with NFR-14 but unstated (G-12). |
| SH-17 | P1 | S | none | FR-73 | covered | Help link per screen (DocBook HELPADDRESS) |
| SH-18 | P1 | S | none | FR-73 | covered | Menu drop-down of 16 fixed shortcuts filtered by access |
| SH-19 | P1 | M | read | FR-73 | covered | Home "System Information" panel (uptime, mirror, DB/journal/lock/wr… — Panel contents (uptime, mirror, DB/journal/lock/write-daemon alerts, production status) only in the catalog row. |
| SH-20 | P1 | S | none | FR-73 | HOLLOW | Links panel (Documentation, Support, InterSystems home) — Cited only through the range "SH-12 through SH-22"; FR-73's sentence never mentions the Links panel (Documentation, Support, InterSystems home). |
| SH-21 | P1 | S | none | FR-73 | covered | UI state persistence (selected category, view mode, panel widths) |
| SH-22 | P1 | S | none | FR-73 | covered | Light/dark theme (community-requested dark mode) |
| CP-01 | P0 | M | none | FR-10 | covered | Always-visible right-hand panel docked like VS Code's secondary sid… |
| CP-02 | P0 | M | none | FR-12 | covered | Chat turn endpoint (POST wraps AgentLoop.RunTurn returning TurnResu… — The three endpoints (turn POST, transcript GET, lock-state GET) are in addendum §3, not the FR. |
| CP-03 | P0 | M | none | FR-24 | covered | Agent configuration screen and CRUD REST (provider, model, endpoint… — The eleven validation rules are named in FR-24, addendum §5 and §8 and the catalog but listed in none of them (G-8). |
| CP-04 | P0 | S | none | FR-25 | covered | Provider adapters openai, anthropic, gemini, openai-compatible (can… |
| CP-05 | P0 | S | none | FR-25 | covered | Local model support (openai-compatible endpoint: Ollama/vLLM/LM Stu… |
| CP-06 | P0 | S | none | FR-27 | covered | Test-connection action on the agent-config form (minimal CallMessag… |
| CP-07 | P0 | S | none | FR-26 | covered | API-key resolution ladder (env var, Ens.Config.Credentials password… — FR-26 "written to the chosen credential store" is only possible for the credentials rung; Ens.Config.Credentials needs an interop-enabled namespace (G-9). |
| CP-08 | P0 | S | none | FR-28 | covered | First-login / unconfigured gate (no enabled agent: panel shows conf… |
| CP-09 | P0 | M | none | FR-11 | widened | Screen-context injection (route, namespace, selected entity, visibl… — FR-11 adds "the current form's values" to the context; harmless. |
| CP-10 | P0 | S | none | FR-11 | covered | Context-sharing toggle (on by default, user can disable per session) |
| CP-11 | P0 | M | none | FR-16 | covered | Tool registry and dispatch (reflection over Tool.Base subclasses; J… |
| CP-12 | P0 | L | read | FR-16 | covered | Read tools for every P0 screen (one tool per list/detail endpoint:… |
| CP-13 | P0 | L | write-confirm | FR-17 | covered | Write tools with propose → review → confirm (diff of proposed chang… |
| CP-14 | P0 | M | none | FR-18 | covered | Runs-as-user permission model (tools execute under the caller's IRI… |
| CP-15 | P0 | M | none | FR-21 | covered | Audit of agent actions (Audit.LlmCall / Audit.ToolCall rows with ar… |
| CP-16 | P0 | S | none | FR-22 | covered | Audit marking of agent-initiated writes (description tag "via OcuPi… — Literal marker text ("via OcuPilot co-pilot" in the catalog) is not fixed by the PRD, and the glossary forbids "co-pilot" alone (G-7). |
| CP-17 | P0 | M | none | FR-12 | covered | Progress indication during a turn (per-iteration tool-call cards, s… |
| CP-18 | P0 | S | none | FR-12 | covered | Conversation lock (exclusive per-history lock; concurrent turn refu… |
| CP-19 | P0 | S | none | FR-23 | covered | Retry / backoff on 429 and 5xx with Retry-After; 90 s provider time… — The 90 s provider timeout value is in addendum §6 only. |
| CP-20 | P0 | S | none | FR-13 | covered | Markdown rendering pipeline (marked → DOMPurify → Prism, vendored,… |
| CP-21 | P0 | S | none | FR-19 | covered | Read-only mode (an administrator or per-user switch that blocks eve… |
| CP-22 | P0 | S | none | FR-20 | widened | Kill switch (admin disables the agent globally or per user; Enabled… — FR-20 adds server-side refusal of turns; owner-confirmed. |
| CP-23 | P1 | S | none | FR-70 | covered | Suggested prompts per screen (grouped by task) |
| CP-24 | P1 | S | read | FR-70 | covered | "Explain this screen" action (summarise current page data and avail… |
| CP-25 | P1 | S | read | FR-70 | covered | "Explain this log entry" / explain error code action |
| CP-26 | P1 | M | read | FR-71 | covered | Agent audit viewer (LlmCall / ToolCall ledger with filters, per-use… |
| CP-27 | P1 | M | none | FR-71 | covered | Citations back to rows and tools used (citation chips with click-th… |
| CP-28 | P1 | M | read | FR-71 | covered | Token metering (UsageRollup per turn; per-user/day totals shown in… — FR-71 cites it and records the owner's move to Stage 2. |
| CP-29 | P1 | M | none | FR-72 | covered | Log-content sanitisation / untrusted-content boundary for tool resu… |
| CP-30 | P1 | S | none | FR-72 | covered | Copy-out drafts (agent offers ObjectScript / CLI / REST snippet ins… |
| CP-31 | P1 | S | none | FR-71 | covered | Data-egress disclosure in the panel (which provider, that screen da… |
| CP-32 | P1 | M | none | FR-72 | covered | Chat history persistence keyed by screen/route with retention purge… — FR-12 (P0) already requires the transcript "for the current screen context" to survive reload — part of this P1 row pulled forward; see §3(b). |
| CP-33 | P1 | M | read | FR-72 | covered | Tool governance policy (per tool:action enable/disable, read-only/f… — GOVERNANCE_DISABLED structured result and the cascade are in addendum §4. |
| CP-42 | P0 | M | none | FR-14 | covered | Screen synchronisation after agent writes: every confirmed write em… |
| CP-43 | P0 | S | read | FR-15 | covered | Agent-driven navigation: browser-side tools the agent can call to o… |
| WA-01 | P0 | S | read | FR-30 | covered | Web applications list (name, namespace, type, enabled, dispatch cla… |
| WA-02 | P0 | S | write-confirm | FR-32 | covered | Delete web application |
| WA-03 | P0 | S | write-confirm | FR-32 | covered | Enable / disable web application |
| WA-04 | P0 | M | write-confirm | FR-31 | covered | Create web application (type CSP/REST/WSGI/ASGI, namespace, dispatc… |
| WA-05 | P0 | L | write-confirm | FR-30 | covered | Web application detail / edit (full editor: type, enable, namespace… — All fifteen editor fields carried by FR-30. |
| WA-06 | P0 | S | read | FR-33 | covered | REST API explorer: list REST-enabled web apps and spec-based REST s… — Scope selector (spec-first / legacy / all) not named; low. |
| WA-07 | P0 | M | read | FR-34 | covered | REST API explorer: view the OpenAPI 2.0 document of a service (rend… |
| WA-08 | P1 | M | none | FR-74 | covered | Try-it request console against a REST endpoint (send request with c… |
| WA-09 | P1 | M | write-confirm | FR-74 | covered | Web sessions list (user, app, PID link) and End Session |
| PM-01 | P0 | S | read | FR-35 | covered | Users list with filter (name, full name, enabled, type, roles) |
| PM-02 | P0 | S | write-confirm | FR-37 | widened | Delete user — FR-37 adds refusal to disable/delete the current user; owner-confirmed. |
| PM-03 | P0 | S | write-confirm | FR-37 | widened | Enable / disable user — Same as PM-02. |
| PM-04 | P0 | S | write-confirm | FR-37 | covered | Change user password (admin-set; change-on-login flag) |
| PM-05 | P0 | S | write-confirm | FR-37 | covered | Add / remove roles on a user |
| PM-06 | P0 | M | write-confirm | FR-36 | covered | Create user (name, password, full name, roles, expiry, startup name… |
| PM-07 | P0 | L | write-confirm | FR-35 | covered | User detail / edit (account, comment, expiry, enabled, change-on-lo… — All editor fields carried by FR-35. |
| PM-08 | P0 | S | read | FR-38 | covered | Roles list |
| PM-09 | P0 | S | write-confirm | FR-39 | covered | Delete role |
| PM-10 | P0 | M | write-confirm | FR-39 | covered | Create role (name, description, resources, granted roles) — Create fields (name, description, resources, granted roles) not listed in FR-39; inferable from FR-38. |
| PM-11 | P0 | M | write-confirm | FR-39 | covered | Role resource add / edit / delete (resource:permissions) |
| PM-12 | P0 | L | write-confirm | FR-38 | covered | Role detail / edit (description, escalation-only, resources, member… |
| PM-13 | P0 | S | read | FR-40 | covered | Resources list with search |
| PM-14 | P0 | M | write-confirm | FR-40 | covered | Resource create / edit / delete (name, description, public permission) |
| PM-15 | P0 | S | read | FR-41 | covered | Services list (enabled, auth methods, allowed IPs) |
| PM-16 | P0 | L | write-confirm | FR-41 | covered | Service edit (enable/disable, allowed IPs add/delete, roles, authen… — FR-41 adds the self-lockout warning; owner-confirmed. |
| PM-17 | P1 | M | read | FR-74 | covered | User profile: effective privileges (roles, resources, applications,… |
| PM-18 | P1 | S | read | FR-74 | covered | Permission check tool (does user/role hold resource:permission; %Al… |
| SS-01 | P0 | S | read | FR-42 | covered | SSL/TLS configurations list |
| SS-02 | P0 | S | read | FR-43 | covered | X.509 credentials list |
| SS-03 | P0 | S | read | FR-44 | covered | OAuth 2.0 client: server descriptions list |
| SS-04 | P0 | S | read | FR-44 | narrowed | OAuth 2.0 client configurations list / delete — Delete is in FR-44, but the row's tool column is `read`, so FR-17's "every write row" rule gives the delete no write tool (G-3). |
| SS-05 | P0 | S | read | FR-44 | covered | OAuth 2.0 resource server list |
| SS-06 | P0 | S | read | FR-44 | covered | OAuth 2.0 authorization server: view configuration (issuer, scopes,… — View fields (issuer, scopes, grant types, keys) not named; low. |
| SS-07 | P0 | S | read | FR-44 | narrowed | OAuth 2.0 server client descriptions list / delete — Same as SS-04 (G-3). |
| SS-08 | P0 | S | read | FR-45 | covered | LDAP / Kerberos configurations list |
| SS-09 | P0 | S | write-confirm | FR-47 | widened | Enable / disable auditing (two SMP leaves) — FR-47 adds the warning that agent writes stop being marked; owner-confirmed. |
| SS-10 | P0 | M | write-confirm | FR-46 | covered | Wallet: collections list and secrets list / create / edit / delete… |
| SS-11 | P0 | M | write-confirm | FR-43 | covered | X.509 credential create (import cert/key) / edit / delete — §5.7 description says "creation and deletion" while FR-43 says import, edit and delete; editorial. |
| SS-12 | P0 | M | write-confirm | FR-47 | narrowed | Configure system audit events (change status, reset counters; Selec… — FR-47 omits the Selective SQL Auditing wizard the row names (G-4). |
| SS-13 | P0 | M | write-confirm | FR-47 | covered | Configure user audit events (create, change status, reset, delete) |
| SS-14 | P0 | L | read | FR-61 | covered | View audit database (search by time, source/type/name, user, PID, n… — All search fields carried by FR-61. |
| SS-15 | P0 | L | write-confirm | FR-42 | covered | SSL/TLS configuration create / edit / delete (certs, key, CA, CRL,… — All nine editor fields carried by FR-42. |
| SS-16 | P0 | L | write-confirm | FR-45 | narrowed | LDAP / Kerberos configuration create / edit / delete — FR-45 defers to "the full configuration the classic page offers"; no field list exists in PRD, addendum or catalog (G-5). |
| SS-17 | P1 | S | read | FR-75 | covered | SSL/TLS test connection |
| SS-18 | P1 | S | read | FR-75 | covered | X.509 view certificate details |
| SS-19 | P1 | S | read | FR-75 | covered | LDAP test authentication |
| SS-20 | P1 | S | write-confirm | FR-75 | covered | OAuth 2.0 administration: revoke a user's tokens |
| SS-21 | P1 | S | write-confirm | FR-75 | covered | Copy audit log to namespace (background) |
| SS-22 | P1 | S | write-confirm | FR-75 | covered | Purge audit log older than N days |
| SS-23 | P1 | M | write-confirm | FR-75 | covered | OAuth 2.0 resource server editor (definition, service mappings, aud… |
| SS-24 | P1 | L | write-confirm | FR-75 | covered | OAuth 2.0 client server-description editor (Discover and Save, Upda… — Sub-actions (Discover and Save, Update JWKS) only in the catalog row; §5.12 delegates row fields to epics by design. |
| SS-25 | P1 | L | write-confirm | FR-75 | covered | OAuth 2.0 client configuration editor (Rotate Keys, secrets, regist… — Sub-actions (Rotate Keys, secrets, register-client, initial access token) only in the catalog row. |
| SS-26 | P1 | L | write-confirm | FR-75 | covered | OAuth 2.0 authorization server editor (Save, Delete, Rotate Keys, s… — Sub-actions (Rotate Keys, scopes add/remove) only in the catalog row. |
| SS-27 | P1 | L | write-confirm | FR-75 | covered | OAuth 2.0 server client description editor (Update JWKS, redirect U… — Sub-actions (Update JWKS, redirect URLs, secret) only in the catalog row. |
| TM-01 | P0 | S | read | FR-48 | widened | Task schedule list (all scheduled tasks; filter; Task Manager status) — FR-48 adds filter by name, namespace, status and last/next run columns the catalog does not name; unverified against the admin API list shape. |
| TM-02 | P0 | S | write-confirm | FR-48 | covered | On-demand tasks list with Run |
| TM-03 | P0 | S | read | FR-48 | covered | Upcoming tasks (next N hours / until date) |
| TM-04 | P0 | S | read | FR-49 | widened | Task history (all tasks; user-defined filter) — FR-49 adds "the user who ran it"; unverified against `/task/history`. |
| TM-05 | P0 | S | read | FR-49 | covered | Task history for one task |
| TM-06 | P0 | S | write-confirm | FR-51 | covered | Run task now |
| TM-07 | P0 | S | write-confirm | FR-51 | covered | Suspend task |
| TM-08 | P0 | S | write-confirm | FR-51 | covered | Resume task |
| TM-09 | P0 | S | write-confirm | FR-51 | covered | Delete task |
| TM-10 | P0 | S | write-confirm | FR-51 | covered | Start / suspend / resume the Task Manager |
| TM-11 | P0 | M | read | FR-50 | covered | Task details (properties, schedule, last run, next run; auto-refresh) |
| TM-12 | P0 | L | write-confirm | FR-52 | covered | New task wizard (name, description, namespace, task type from %SYS.… — All thirteen wizard fields carried by FR-52. |
| TM-13 | P0 | L | write-confirm | FR-53 | covered | Edit task — FR-53 carries the "rendered empty" caveat. |
| TM-14 | P1 | S | write-confirm | FR-76 | covered | Export task to file |
| TM-15 | P1 | M | write-confirm | FR-76 | covered | Import tasks from file |
| TM-16 | P1 | M | write-confirm | FR-76 | narrowed | Portal background tasks list (status, namespace, details, error cou… — FR-76 "the portal's background tasks" conflates admin-API async results with SMP background tasks; the catalog's judgment call says full parity needs a custom part (G-6). |
| OS-01 | P0 | S | read | FR-54 | covered | Processes list (filter, page size, max rows, persisted sort, auto-r… — All list controls carried by FR-54. |
| OS-02 | P0 | S | write-confirm | FR-55 | widened | Terminate process (with optional RESJOB error) — FR-55 adds refusal to act on the user's own process; owner-confirmed. |
| OS-03 | P0 | S | write-confirm | FR-55 | covered | Suspend process |
| OS-04 | P0 | S | write-confirm | FR-55 | covered | Resume process |
| OS-05 | P0 | S | read | FR-56 | covered | System usage counters (global refs, routine calls, block reads/writ… |
| OS-06 | P0 | S | read | FR-57 | covered | Locks view (namespace selector, filter, owner routine info, SQL tab… — "SQL table name" column not named in FR-57; low. |
| OS-07 | P0 | S | write-confirm | FR-57 | covered | Remove one lock / all locks for a process / all locks from a remote… |
| OS-08 | P0 | M | read | FR-54 | covered | Process details (dashboard meters, client EXE/IP, open devices, opt… — Auto-refresh on process details not stated in FR-54; low. |
| OS-09 | P0 | M | read | FR-56 | covered | CPU, memory and performance meters (System Performance / System Usa… |
| OS-10 | P0 | M | read | FR-58 | covered | Disks: local databases list with General and Free-space views (size… |
| OS-11 | P0 | M | read | FR-58 | covered | Database details (properties, volume files, background tasks runnin… |
| OS-12 | P0 | M | write-confirm | FR-59 | narrowed | Devices list / create / edit / delete (contest-named "devices") — FR-59 "the fields of the classic device page"; no field list anywhere (G-5). |
| OS-13 | P1 | M | write-confirm | FR-76 | covered | Broadcast a message to selected processes |
| OS-14 | P1 | S | read | FR-76 | covered | License usage (summary, by process, by user, distributed) |
| OS-15 | P1 | M | read | FR-76 | covered | Read-only System Dashboard main panel (7 meter groups: performance,… |
| LG-01 | P0 | S | read | FR-60 | covered | alerts.log viewer (entries since last scrape from the official rout… |
| LG-02 | P0 | L | read | FR-61 | covered | Audit database viewer (contest "all the logs"; inventoried at SS-14) |
| LG-03 | P0 | M | read | FR-62 | covered | messages.log viewer (full text, search and highlight, goto top/bott… |
| LG-04 | P0 | M | read | FR-63 | narrowed | Application error log: namespaces → dates → errors drill-down; dele… — Delete actions are in FR-63 but the row's tool column is `read`; no write tool by FR-17's rule (G-3). FR-63 adds "routine, line" columns. |
| LG-05 | P1 | S | read | FR-77 | narrowed | System Monitor log viewer (SystemMonitor.log or chosen file; search… — NFR-4 "file-serving endpoints accept no path" removes the row's "or chosen file"; consistent with SH-24 at Stage 2 but unstated (G-11). |
| LG-06 | P1 | S | read | FR-77 | covered | Background task error log |
| LG-07 | P1 | M | read | FR-77 | narrowed | xDBC error log (namespaces with errors → errors; delete selected /… — FR-77 says "view"; the row's delete selected / all is dropped (G-11). |
| LG-08 | P1 | M | read | FR-77 | narrowed | SQL diagnostics log (%SQL_Diag.Result per namespace; detail panel;… — FR-77 drops the row's delete (G-11). |
| LG-09 | P1 | M | read | FR-77 | narrowed | Interoperability event log (secondary log viewer; leaf inventoried… — FR-77 drops the row's purge (G-11). |
| LG-10 | P1 | M | read | FR-77 | covered | Unified log hub (one screen listing every log source with counts, l… |
| SA-01 | P1 | M | write-confirm | FR-78 | covered | External language servers list with status; Start / Stop / Status /… |
| SA-02 | P1 | L | write-confirm | FR-78 | covered | External language server create / edit / delete (Java, .NET, Python… — Server types (Java, .NET, Python, R, XSLT) not named; low. |
| EX-01 | P0 | S | read | FR-5 | narrowed | Namespace listing for the data browser (same source as SH-03) — Duplicate of SH-03; only listed backing is `/api/atelier/`, which §8 excludes from Release 1 — resolved by SH-03's admin-v2 alternative. |
| IO-01 | P1 | M | read | FR-77 | narrowed | Event log (search/filter by type, time, source item, session, text;… — Same as LG-09. |
| AN-01 | P1 | S | read | FR-77 | narrowed | Analytics log viewer (DeepSee log file; refresh, delete) — FR-77 drops the row's delete (G-11). |
| PK-01 | P0 | S | none | FR-69 | covered | README in English: installation steps, video demo or detailed descr… |
| PK-02 | P0 | S | none | FR-69 | covered | Public GitHub (or GitLab) repository with an open-source license file |
| PK-03 | P0 | S | none | FR-69 | covered | Open Exchange listing published before applying; apply through the… |
| PK-04 | P0 | S | none | FR-69 | covered | Contest application submitted by 2026-09-27 23:59 US Eastern; keep… |
| PK-05 | P0 | S | none | FR-69 | covered | Ideas Portal idea for OcuPilot (satisfies the README "link to the i… |
| PK-06 | P0 | S | none | FR-68 | covered | Community Edition compatibility (IRIS CE and IRIS for Health CE; no… |
| PK-07 | P0 | S | none | FR-66 | covered | Name-collision avoidance: package OcuPilot, web apps /ocupilot and… — Catalog says web app `/ocupilot/api`; PK-12 and addendum §6 say `/api/ocupilot`. Catalog-internal inconsistency; PRD resolved to `/api/ocupilot`. |
| PK-08 | P0 | S | none | FR-23 | covered | Web Gateway response timeout ≥ 300 s documented as an install prere… |
| PK-09 | P0 | S | none | FR-3 | covered | Pin /api/admin to v2, guard on GET /info apiVersion, and keep the a… |
| PK-10 | P0 | M | none | FR-64 | CONTRADICTED | IPM module.xml: WebApplication (not deprecated CSPApplication), Fil… — Addendum §6 carries `<SystemRequirements>` IRIS 2022.1+ (the catalog's wording) against NFR-13 and decision 13 (2026.2 or later) (G-2). |
| PK-11 | P0 | M | none | FR-65 | covered | Angular bundle served from an IRIS web app: ServeFiles, AutheEnable… |
| PK-12 | P0 | M | none | FR-65 | covered | OcuPilot REST web app (/api/ocupilot: AutheEnabled 32, JWTAuthEnabl… |
| PK-13 | P0 | M | none | FR-29, FR-66 | covered | Idempotent installer class (web apps, role/resource, %SYS audit eve… — Cited by FR-29 and FR-66; "tasks" the installer creates are unnamed (the only task in Release 1 is CP-32's P1 purge task). |
| PK-14 | P0 | M | none | FR-67 | covered | Docker self-install: Dockerfile FROM intersystemsdc/irishealth-comm… — Ports offset and build-vs-start are Open Question 5. |
| PK-15 | P0 | S | none | FR-64 | covered | Angular build committed or produced before zpm package (dist must b… |
| PK-16 | P1 | M | none | FR-79 | covered | Online demo instance (precedent 2-point bonus) |
| PK-17 | P1 | S | none | FR-79 | covered | Developer Community article (first 2 points, second 1 point precedent) |
| PK-18 | P1 | S | none | FR-79 | covered | YouTube video (3) and YouTube Short (1) precedent bonuses |
| PK-19 | P1 | S | none | FR-79 | covered | Watch for the Technology Bonuses post (expected around the 2026-09-… |
| PK-20 | P1 | S | none | FR-79 | covered | Freshmen nomination eligibility check (≤5 prior contests, no prior… |
| PK-21 | P1 | S | none | FR-79 | covered | Uninstall hook removing web apps, role, tasks, audit events, globals |
| PK-22 | P1 | M | none | FR-79 | covered | %UnitTest suite with HTTP integration harness (MakeRequest helper,… |
| PK-23 | P1 | M | none | FR-79 | covered | CI: build Angular, lint, no-CDN and no-embedded-Python greps, self-… |
| PK-24 | P1 | S | none | FR-79 | covered | Publish the package to pm.community.intersystems.com (or GHCR via O… |

### 1.3 Hollow citations

- **SH-20 Links panel** (P1, FR-73). The range "SH-12 through SH-22" cites it; FR-73's sentence lists every other row in the range by name and omits this one. Three static links; trivial to build, but a story writer reading FR-73 would not know it is in scope.

No P0 row is hollow. The two thinnest P0 citations, SS-16 (FR-45) and OS-12 (FR-59), do state the capability (create/edit/delete) and are recorded as narrowed for the missing field list (G-5).

### 1.4 Material narrowings

Grouped; each is expanded in §2.

| Narrowing | Rows | FR | Gap |
|---|---|---|---|
| Shell read tools fall outside FR-16's "six areas" definition | SH-02, SH-03, SH-04, EX-01 | FR-16 | G-1 |
| Deletes/purges on rows whose tool column is `read` get no write tool under FR-17's rule | SS-04, SS-07, LG-04; P1 LG-07, LG-08, IO-01/LG-09, AN-01 | FR-17, FR-44, FR-63, FR-77 | G-3 |
| Selective SQL Auditing wizard dropped | SS-12 | FR-47 | G-4 |
| No field list for two P0 editors | SS-16, OS-12 | FR-45, FR-59 | G-5 |
| Admin-API async results conflated with SMP background tasks | TM-16 | FR-76 | G-6 |
| Delete/purge actions dropped from the secondary log viewers; "chosen file" removed by NFR-4 | LG-05, LG-07, LG-08, IO-01, AN-01 | FR-77, NFR-4 | G-11 |
| Session language selector dropped; About fields unenumerated | SH-16 | FR-73 | G-12 |

### 1.5 Widenings (owner-confirmed, no catalog evidence)

- Self-protection refusals: deleting OcuPilot's own web applications (FR-32), disabling or deleting the current user (FR-37), acting on the user's own process (FR-55); warnings on disabling the web service (FR-41) and on disabling auditing (FR-47). Addendum decision 10.
- Refresh pauses under an open proposal (FR-7); Task schedule added to the auto-refresh users (FR-7) although TM-01 does not list auto-refresh.
- Server-side refusal of turns under the kill switch (FR-20); form values added to screen context (FR-11).
- **Three widenings name fields the admin API may not return and should be verified with the payload probe:** FR-48's schedule filter by name, namespace and status with last/next run; FR-49's "the user who ran it"; FR-63's "routine, line". The catalog rows (TM-01, TM-04, LG-04) name none of these.

## 2. Field-level gaps

Only what a story writer could not infer from the PRD plus addendum. Ratings: **high** — a story built from the PRD would be wrong or unbuildable; **medium** — a story would be incomplete and the writer would not know it; **low** — recoverable from the catalog row itself.

| ID | Rating | Rows | FR affected | What the catalog names and the PRD omits | Why it cannot be inferred |
|---|---|---|---|---|---|
| G-2 | **high** | PK-10 | FR-64, NFR-13; addendum §6 | The catalog (and addendum §6, verbatim) put `<SystemRequirements>` at "IRIS 2022.1+, IPM 0.10.x". NFR-13 and decision 13 set the floor at IRIS 2026.2 or later. | The module manifest is exactly where a story writer copies the version from, and addendum §6 is the manifest checklist. Two planning documents disagree; one must change. |
| G-3 | **high** | SS-04, SS-07, LG-04 (P0); LG-07, LG-08, IO-01/LG-09, AN-01 (P1) | FR-17, FR-44, FR-63, FR-77, **SM-3** | Each row's feature text includes a delete or purge, but its Co-pilot-tool column is `read`. FR-17 defines write tools as "every write row in 5.5 through 5.10", i.e. by that column, so none of these deletes gets a proposal card or a write tool. Area 6 (Logs) has **no** `write-confirm` row at P0 or P1 (LG-01..LG-10 are all `read`; the first Logs write row is LG-12 at P3). SM-3 requires "each of the six areas has ... at least one write that the agent can propose and the user confirm". | SM-3 is unsatisfiable for Logs unless FR-63's delete (or the deletes in FR-44 for area 3) is explicitly declared a write tool. A story writer following FR-17's rule would build no Logs write tool and fail the metric without knowing. |
| G-1 | medium | SH-02, SH-03, SH-04, EX-01 | FR-16 (also FR-4, FR-5) | Four of the catalog's 38 P0 `read` tools are shell rows: the privilege map (SH-02, `iris_permission_check`), the namespace list (SH-03/EX-01), and server/instance/license identity (SH-04). FR-16 restricts read tools to "every list and detail that the six areas' screens can read" and cites "every read row in 5.5 through 5.10". | The PRD's 38-read-tool count includes these four, but the FR that defines read tools excludes them. Whether the agent can answer "which namespaces exist", "what instance is this", "what can I do here" in Release 1 is undecidable from the PRD. UJ-1 assumes it can. |
| G-4 | medium | SS-12 | FR-47 | "Configure system audit events (change status, reset counters; **Selective SQL Auditing wizard**)". FR-47 carries status and counters only. The digest carried the wizard; the PRD dropped it. | The wizard is a distinct classic page (`Audit.SelectiveWizard`) with no obvious admin-v2 route among those the row lists (`/security/audit/events`, `/event`, `/clear-count`). It needs either an explicit deferral or a probe; silence reads as "in scope". |
| G-5 | medium | SS-16 (L), OS-12 (M) | FR-45, FR-59 | LDAP/Kerberos editor and Device editor. FR-45 says "the full configuration the classic page offers", FR-59 "the fields of the classic device page". Neither the catalog, the PRD nor the addendum names a single field for either; the catalog only gives the class and line count (`%CSP.UI.Portal.LDAP`, 797 lines). | Open Question 7 instructs pulling page source for five legacy CSP pages; these two are Zen classes already in the `irissys/` export, so they are not on that list and get no instruction at all. A story writer has no field list and no pointer. The same applies less sharply to SS-06's view fields, WA-04/WA-05 and PM-06/PM-07, which the catalog does enumerate. |
| G-6 | medium | TM-16 | FR-76 | The catalog's judgment call: TM-16 "mapped onto admin-v2 `/async-results`, which tracks `%Api.Admin` async tasks, not `%CSP.UI.System.BackgroundTask` jobs; full parity needs the custom part too". FR-76 says "see and control the portal's background tasks". Addendum §7 states the distinction but does not tie it to FR-76. | "The portal's background tasks" reads as the classic Background Tasks page; the P1 row only delivers the admin-API half. A story writer would scope the wrong thing. Related: FR-58 (P0) already depends on `/async-result` polling for free-space figures, while the PRD lists "async-result polling" as a Stage 2 gate. |
| G-7 | low | CP-16 | FR-22, FR-61 | The catalog fixes the marker text: description tag "via OcuPilot co-pilot". The PRD glossary makes the marker "fixed text" but never fixes it, and forbids "co-pilot" alone. | The literal must be chosen before FR-22, FR-61's filter and SM-5's query can be written; the catalog's literal violates the glossary. |
| G-8 | low | CP-03 | FR-24 | "the 11 server-side validation rules" are cited by FR-24, addendum §5 and §8, and the catalog, and listed by none of them. | They live only in the harvest digest (`harvest-session-agent`, "Agent-config screen table"). FR-24 should name that file. |
| G-9 | low | CP-07 | FR-26, FR-67 | Catalog: "env var, Ens.Config.Credentials password". FR-26: "A key entered through the form is written to the chosen credential store once" — only possible for the credentials rung; an environment variable cannot be written from a form. `Ens.Config.Credentials` exists only in interoperability-enabled namespaces; FR-67's fallback namespace is `USER`. | Two consequences a story writer would not see: the form's key field must be disabled for the env-var rung, and the credentials rung may be unavailable in the install namespace. |
| G-10 | low | SS-09, OS-05, TM-06..TM-09 (P0); TM-14, TM-15 (P1) | OQ 7, §12 risk row, FR-47, FR-56, FR-51 | The catalog's Gaps list of never-exported legacy CSP pages includes Enable/Disable Auditing (`UtilSecAction.csp`), System Usage (`UtilSysMonitor.csp`) and the task actions/export/import (`UtilSysTaskAction.csp`). OQ 7 and the risk row name only the wizard, edit task, dashboard meters, messages.log and the application error log. | All have admin-v2 routes, so the omission is survivable; OS-05's counter set and refresh interval, and SS-09's two-leaf behaviour, are nonetheless inferred from unexported pages. |
| G-11 | low | LG-05, LG-07, LG-08, IO-01, AN-01 | FR-77, NFR-4 | LG-05 "SystemMonitor.log **or chosen file**; directory allow-list"; LG-07 "delete selected / all"; LG-08 "delete"; IO-01 "purge"; AN-01 "refresh, delete". FR-77 is "view" throughout; NFR-4 "file-serving endpoints accept no path". | The narrowing is right (SH-24's allow-list is Stage 2) but unstated; the deletes also fall under G-3. |
| G-12 | low | SH-16 | FR-73, NFR-14 | "About page (14 system-overview fields; session language selector)". FR-73 says "open About"; the 14 fields are not enumerated anywhere (addendum §7 only says "About with 14 fields"); the selector is silently dropped, consistent with NFR-14. | Low value, but the drop should be stated so it is not reported as a defect against the classic page. |
| G-13 | low | WA-06, SS-06, OS-06, OS-08, PM-10, SA-02, SH-19 | FR-33, FR-44, FR-57, FR-54, FR-39, FR-78, FR-73 | Scope selector (spec-first / legacy / all); authorization-server view fields (issuer, scopes, grant types, keys); locks "SQL table name" column; process-details auto-refresh; role-create fields; server types (Java, .NET, Python, R, XSLT); Home panel contents. | Each is one clause in the catalog row; the story writer recovers it by reading the row, which the PRD's traceability rule expects. |

## 3. Tier and placement contradictions

### 3.1 Stages 2 through 6

Verified by parsing the five stage tables in `extract-stages.md` §2 against the catalog's Tier column:

- Every P2, P3 and P4 row (357) appears in exactly one stage; no row is missing, none is duplicated, no P0/P1 row is placed in a stage.
- Stages 2, 3, 4 and 6 contain only rows of the expected tier (P2, P2, P2, P4). Stage 5 contains 164 P3 rows plus CP-34 (P2) — the recorded decision 7.
- The four moves the addendum records (streaming to Stage 5, Analytics rider on Stage 4, agent picker CP-36 at Stage 3, CP-28 to Stage 2) are the only cross-tier placements. **No undisclosed move exists.**
- The PRD's §10.3 bullets name rows consistently with the extract: CP-35/39/41 and CP-28 in Stage 2; EX-15 and CP-36 in Stage 3; CP-37/38 in Stage 4; IO-91..118, CP-40, CP-34 in Stage 5; §9 and §10.4 agree.

### 3.2 Inside Release 1

| Item | What the catalog says | What the PRD does | Rating |
|---|---|---|---|
| Cut line leaves eight P0 write rows unplaced | P0 writes sized S: SS-09 enable/disable auditing, SS-04/SS-07 OAuth deletes, TM-02 run on-demand; sized M: SS-11 X.509 import, SS-12/SS-13 audit-event configuration. | §10.1 step 3 names FR-32, FR-37, FR-51, FR-55, FR-57; step 4 names FR-31, FR-36, FR-39, FR-40, FR-46, FR-59. FR-43, FR-44's deletes, FR-47 and FR-48's run appear in no step. Step 3's label "Permissions, Tasks and OS management" mislabels FR-32 (web applications). | medium — the cut line is Release 1's only ordering instrument, and it silently omits the whole auditing sub-area of the contest's area 3. |
| CP-32 partly pulled from P1 into P0 | CP-32 (P1): "Chat history persistence keyed by screen/route with retention purge task". CP-02 (P0) supplies only a transcript bootstrap GET. | FR-12 (P0): "The transcript for the current screen context is loaded when the panel opens and survives a page reload" — screen-keyed persistence is the P1 row's substance. | low — state which half is P0 (a per-user transcript that survives reload) and which is P1 (keying by screen and the purge task). |
| SS-14 / LG-02 duplicate | Counted in area 3 and area 6. | Placed only in 5.10 (FR-61); 5.7's description does not mention the audit viewer. Fine, but area-3 completeness in SM-3 terms relies on FR-61. | low |
| EX-01 backing | Only listed backing is `official-REST GET /api/atelier/`. | §8: "The Atelier API is not used in Release 1." Resolved only because EX-01 duplicates SH-03, which also lists admin-v2 `/namespaces`. | low — say so in FR-5. |
| FR-9 has no catalog row | — | "Catalog: cut line rule". The only FR without a row; acceptable, noted for traceability. | none |

## 4. Counts

Every figure recomputed from the catalog tables (538 rows) and the extract's stage tables.

| Claim | Where stated | Recomputed | Verdict |
|---|---|---|---|
| 538 rows | PRD §0 | 538 (no duplicate IDs; section totals identical to the catalog's summary table) | matches |
| 119 P0 | PRD §10.1, addendum §10 | 119 | matches |
| 62 P1, 61 in the polish week after CP-28 moved | PRD §5.12, §10.2; addendum §10 | 62; 61 | matches |
| P0 sizes 70 S / 37 M / 12 L, "11 distinct" | PRD §10.1; addendum §10 | 70 / 37 / 12; the twelve are CP-12, CP-13, WA-05, PM-07, PM-12, PM-16, SS-14, SS-15, SS-16, TM-12, TM-13, LG-02 (LG-02 = SS-14) | matches |
| P0 tools 38 read / 37 write-confirm / 44 none | addendum §10 | 38 / 37 / 44 | matches (but see G-1 and G-3 on how FR-16/FR-17 apply the column) |
| P1 tools 22 / 15 / 25 | extract-catalog §5 | 22 / 15 / 25 | matches |
| P2 137, P3 164, P4 56 | addendum §10 | 137 / 164 / 56 | matches |
| Addendum §10 area table (Shell 12, Logs 4/8, Outside 99/142/47, totals 119/62/137/164/56) | addendum §10 | Reconciles to the catalog's section table once EX-01 is counted with the shell, IO-01 and AN-01 with Logs, and SA-01/02 as unmapped; 99/142/47 = SA+SO+EX+IO+AN+DT per tier | matches |
| Stage rows 60 / 36 / 41 / 165 / 56 = 358 | PRD §10.3 | Extract: 59 / 36 / 41 / 165 / 56 = 357; PRD's Stage 2 = 59 + CP-28 = 60; total 358 | matches |
| Stage sizes 20/32/8, 17/15/4, 10/25/6, 60/79/26, 11/29/16; total 118/180/60 | PRD §10.3 | Extract 20/31/8 + CP-28 (M) = 20/32/8; others identical; total 118/179/60 + M = 118/180/60 | matches |
| New REST endpoints 3 / 0 / 4 partial / 128 / 32 = 167 | PRD §10.3 | Extract §4 gives the same five figures | matches |
| "roughly forty Release 1 write rows" on unobserved payloads | PRD §12 | Addendum §3's list is 39 rows plus CP-13 | matches |
| Addendum §3 write-payload row list | addendum §3 | Identical to the digest's flag (i); every P0 admin-v2 write row is present | matches |

One consequence of the CP-28 move for readers: PRD §10.3 says "Row-level tables per stage are in `extract-stages.md`", but that file still shows Stage 1 with 59 rows and no CP-28 (its roll-up says 357). A reader following the pointer will find one fewer row than the PRD claims. Low; a one-line note in §10.3 or the extract fixes it.

## 5. Catalog "Gaps" and judgment calls not carried

### 5.1 Gaps section

| Catalog gap | Carried by | Not carried |
|---|---|---|
| Legacy CSP pages never exported (14 named) | OQ 7 and the §12 risk row name five | SS-09, OS-05, TM-06..09, TM-14/15 are Release 1 rows on that list and are unnamed (G-10) |
| messages.log / application-error backing classes unresolved | OQ 4, FR-62, FR-63 | — |
| X.509 backing class: `Security.X509Credentials` absent; execute-mcp uses `%SYS.X509Credentials` | OQ 4, FR-43 | The `%SYS.X509Credentials` lead — the one concrete class name the research found — is dropped from OQ 4 |
| Admin API write payloads untested; v1 UrlMap read partially (PATCH/DELETE variants) | OQ 6, §12, addendum §3 | — |
| UpdateProduction action vocabulary | Stage 4 gate | — |
| Task edit page rendered empty | FR-53 | — |
| Dashboard meter names and thresholds not captured | FR-56, OQ 7 | OS-15 (P1, FR-76) inherits the same unknown and is not flagged |
| Embedding: cookie not isolated, VSCODE mode not exercised live, schema-viewer document-selection parameter unproven | Addendum §2 (the auth spike resolved the first two) | The schema-viewer parameter (IO-19..21) is absent from the Stage 4 gate list |
| Technology bonuses unpublished | OQ 1, FR-79 | — |
| Globals via Atelier untested: if `CALL %SYS.GlobalQuery_NameSpaceList` works through `action/query`, EX-37 moves P3 → P2 | — | Not carried; it would move EX-37 from Stage 5 to Stage 3 |
| `iris_ecp_status` implementation not identified; SA-08/SA-09 rely on admin-v2 routes alone | — | Not carried into the Stage 2 gate list |
| Hidden EnsPortal classes and Angular per-component behaviour estimated | — | Not carried; Stage 4/5 only |
| Judging rubric weights single-sourced and unweighted; tiering assumes equal weight | — | Not carried. §5.12 orders the polish week "by the judging criteria" on the same equal-weight assumption; OQ 1 could ask for weights at the kick-off |
| Row granularity, duplicated rows, budget note | Addendum §10 | — |

### 5.2 Judgment calls

Addendum §11 revisits five (locks, wallet, interop/analytics logs, web sessions, memory configuration) and says "the remaining 23 stand as the catalog states them". Of those 23, the ones with a Release 1 consequence and their status:

| Judgment call | Status in the PRD |
|---|---|
| CP-01 always-visible panel; narrow viewport is a UX decision | FR-10 verbatim |
| CP-42 / CP-43 added at P0 | FR-14, FR-15 |
| OS-12 devices P0 while sub-pages P4 | FR-59; Stage 6 |
| LG-01 alerts.log P0 | FR-60; addendum §3 now records the fourth custom endpoint |
| OAuth lists P0, editors P1 | FR-44, FR-75 |
| PK-05 idea at P0 | FR-69 |
| SH-09 auto-refresh at P0 "could be argued P1" | FR-7; the cut line never places any shell row, so the fallback is implicit |
| SH-12 change password at P1 | FR-73 |
| EX-15: P0 read tools use catalog SELECTs only; free-form SQL is P2 | FR-16 last consequence; §9 |
| TM-16 mapped onto `/async-results`; full parity needs the custom part | **Not carried** (G-6) |
| CP-34 P2 / CP-40 P3 reading of the tiers | Decision 7; Stage 5 |
| SA-01/SA-02 external language servers at P1 | FR-78 |
| DT-11 must precede DT-09/DT-10 | Extract's Stage 4 gate; absent from the PRD's Stage 5 gate text (low) |

### 5.3 Catalog-internal inconsistency the PRD resolved silently

PK-07 names the REST application `/ocupilot/api`; PK-12 and the addendum name `/api/ocupilot`. The PRD and addendum use `/api/ocupilot` throughout. Correct choice; worth one line in addendum §6 so the catalog's PK-07 wording is not mistaken for a second application.

## 6. Editorial nits (not gaps)

- §5.7's description says "creation and deletion of X.509 credentials"; FR-43 and SS-11 say import, edit and delete.
- FR-24: "Definitions are visible to every user for selection" sits beside decision 9 (no picker in Release 1) and FR-24's own last consequence.
- §12: "12 large forms" — nine of the twelve L rows are forms; CP-12 and CP-13 are tool sets and SS-14/LG-02 is a viewer.
- §10.1 step 3's area label (see §3.2).
- FR-16's count of read tools (38) and FR-17's of write tools (37) are never stated in the PRD body; they appear only in addendum §10, which is where G-1 and G-3 become visible.
