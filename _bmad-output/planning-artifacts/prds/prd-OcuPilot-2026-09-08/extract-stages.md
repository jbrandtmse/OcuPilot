# OcuPilot PRD extract — post-release stages to full portal parity (P2, P3, P4)

Source: `_bmad-output/planning-artifacts/research/technical-ocupilot-portal-feature-landscape-2026-09-08/feature-catalog.md` (all P2, P3 and P4 rows) and the "Post-contest sequence" and "Judgment calls" sections of `_bmad-output/planning-artifacts/briefs/brief-OcuPilot-2026-09-08/addendum.md`. Row IDs, sizes, backings and MCP-tool names are the catalog's; stage assignment and notes are this extract's. Extracted 2026-09-08.

The first release covers the P0 and P1 rows. After it, the addendum sequences delivery as: "(1) The rest of the hidden `/api/admin` service (P2). (2) System Explorer over the Atelier API, with the grid harvested from iris-table-editor (P2). (3) Interoperability over the interop-editors v7 API, with the three vendor document editors for BPL, DTL, and rules embedded (P2). (4) Custom-REST parity harvested from the MCP suite's handlers (P3). (5) The long tail, as demand shows (P4)." And: "The agent grows in step with the phases: confirmed single writes, then guided multistep workflows, undo, and streaming."

## 1. Tier definitions (catalog legend, verbatim)

- **P2 Post-contest parity, API-backed** — "an official %Api.* route or a hidden /api/admin route exists, or an InterSystems Angular editor can be embedded."
- **P3 Post-contest parity, custom REST required** — "no route anywhere; a backing ObjectScript class exists (often already wrapped by iris-execute-mcp-v2 handlers or iris-session-agent tools)."
- **P4 Long tail, excluded by default** — "deprecated, license/edition-gated, low-usage, dead references, or full applications to link rather than rebuild; the reason is in the Evidence column."

Complexity, as the catalog's legend defines it: **S** list only · **M** list plus form or dialog · **L** wizard, editor or console. Co-pilot tool: read / write-confirm / none.

The catalog's own reading of the tiers for co-pilot rows (Judgment calls): "for co-pilot features P2 was read as 'API exists or is a bounded extension' and P3 as 'new server-side path'" — which is why CP-34 streaming sits at P2 and CP-40 undo at P3.

Catalog totals for the three tiers: **P2 137 · P3 164 · P4 56 = 357 rows** (the parse of the catalog tables reproduces the summary table exactly). Three duplicates the catalog keeps deliberately are all P0/P1 (LG-02 = SS-14, LG-09 = IO-01, EX-01 = SH-03), so no duplicate inflates these tiers.

## 2. Stage outline

### Mapping rules

The addendum orders the stages by API readiness, so rows are assigned by the API they need, with the exceptions stated below. Every P2, P3 and P4 row lands in exactly one stage; nothing is left unmapped, but the rows placed by extension rather than by the addendum's wording are flagged.

1. **Stage 1** takes every P2 row backed by `admin-v2`, plus the P2 rows on the two official routes the first release already wires (`mgmnt` for WA-06/07, `monitor` for OS-09/LG-01): WA-13, WA-14, OS-30, SO-08. Three P2 rows with custom backing whose screen family is already shipped go here too, flagged as custom endpoints: PM-19, LG-11, PK-25.
2. **Stage 2** takes every P2 row backed by `atelier` or by the Explorer section, plus the Documatic embed (EX-34) and, **by extension**, DT-01 (the DocDB data browser on the official `/api/docdb` route — a sibling of the SQL data browser; the addendum does not name it). OS-23 (SQL activity) is an OS-section row but needs the Stage 2 action/query plumbing, so it sits here.
3. **Stage 3** takes every P2 row backed by `interop-v7` or an `embed`, the two shell rows that gate embedding and namespace categories (SH-23, SH-25), and, **by extension and flagged**, the nine Analytics P2 rows on `/api/deepsee` (AN-02..AN-10) plus IO-17 (also deepsee). The addendum names no Analytics stage; Analytics is attached here as a rider because both categories are namespace-gated by the same SH-25 mechanism and are official-route work with no custom endpoints. The PRD author may split it out as a stage of its own.
4. **Stage 4** takes all 164 P3 rows, sub-grouped by catalog section so the Explorer, Interoperability, Analytics, Operations and Developer-tools sub-tracks are visible. CP-34 (streaming, P2) is placed here because the addendum sequences streaming last in the agent's growth.
5. **Stage 5** takes all 56 P4 rows, grouped by the catalog's exclusion reason.
6. **CP rows follow the agent-growth sequence, not their API.** The addendum names four steps — "confirmed single writes, then guided multistep workflows, undo, and streaming" — laid across Stages 1–4 in that order: Stage 1 confirmed single writes over the admin-v2 remainder (CP-35, CP-39, CP-41 as hardening); Stage 2 single writes over Atelier plus the agent picker (CP-36); Stage 3 guided multistep workflows (CP-37, CP-38); Stage 4 undo (CP-40) and streaming (CP-34), plus the 28 session-agent tools (IO-91..IO-118). Stage 5 adds nothing to the agent.

"Custom endpoint" below means the catalog's API-backing column names `custom(...)`. For CP rows and the IO-91..118 tools this is server-side agent code that rides on the existing chat endpoint (CP-02) rather than a new REST route; they are counted but footnoted.

### Stage 1 — The rest of the hidden `/api/admin` service (P2)

**59 rows** · S 20 / M 31 / L 8 · custom endpoints 5

**What the user can do at the end.** The portal reaches System Administration and System Operation parity on the hidden `/api/admin` service. An operator creates, edits and deletes namespaces (with mappings and copy-mappings), runs the create/delete database wizards and edits database properties, volumes and remote (ECP) databases, and performs every disk operation the contest list deferred — mount, dismount, truncate, compact, defragment, expand, integrity check — with async progress polling. Journal settings, journal files (summary, integrity, switch file and directory) and a journal record browser are available; so are license key and license servers, ECP settings and servers, WQM categories, superservers, authentication and web-session options, MFT connections, and the four encryption pages. Permission management completes with SQL privileges (schema, column and admin grants), role owners, user copy-from and password validation; web-app management gains %-class access, DocDB and privileged-routine application lists, and spec-based REST service create/delete. Monitoring gains the raw Prometheus table, interop usage metrics and the dashboard drill-down statistics; text-log viewers gain a live tail. The co-pilot has a read tool and a confirmed single-write tool for every one of these screens, can keep its API key in the IRIS wallet, works behind a proxy or custom CA, and manages its own context window.

**Rows in this stage, grouped by catalog section.**

**0. Portal shell and platform (SH)** — 1 row (S 0 / M 1 / L 0)

| ID | Name | Kind | Backing (API or class) | Size | Note |
|---|---|---|---|---|---|
| SH-24 | Directory allow-list for file-browse dialogs | platform | admin-v2 /fs-access-purposes, /fs-access-purpose/paths | M | Prerequisite for every server-file path picker (export/import/backup) in later stages. |

**1. Co-pilot agent (CP)** — 3 rows (S 2 / M 1 / L 0)

| ID | Name | Kind | Backing (API or class) | Size | Note |
|---|---|---|---|---|---|
| CP-35 | Wallet-backed API key storage | agent | admin-v2 /wallet/secret | S | Third rung of the CP-07 secret ladder; the wallet route is already wired for SS-10. |
| CP-39 | Context-window management | agent | custom | M | Nothing to harvest (session-agent gap); needed as the tool roster doubles with this stage. |
| CP-41 | Proxy / custom CA support for outbound LLM HTTPS | agent | custom(%Net.HttpRequest proxy properties; SSL config selectable) | S | session-agent hard-codes DefaultSSL; expose %Net.HttpRequest proxy and SSL-config choice. |

**2. Contest area 1: Web apps and REST APIs (WA)** — 5 rows (S 1 / M 4 / L 0)

| ID | Name | Kind | Backing (API or class) | Size | Note |
|---|---|---|---|---|---|
| WA-10 | %-class web access list per web application | list | admin-v2 GET/PUT /web-app/pct-accesses, /pct-access | M | Dialog off the P0 web-app editor (WA-05). |
| WA-11 | Doc DB applications list / create / edit / delete | list+CRUD | admin-v2 GET /doc-dbs, GET/PUT/DELETE /doc-db | M | Security list only; the DocDB data browser is DT-01 (Stage 2). |
| WA-12 | Privileged routine applications list / create / edit / delete | list+CRUD | admin-v2 /security/privileged-routines | M | co-pilot write-confirm. |
| WA-13 | Create spec-based REST service from an OpenAPI document | action | mgmnt POST /api/mgmnt/v2/:ns/:app | M | mgmnt route already wired for WA-06/07; creates a %REST.API service from an OpenAPI doc. |
| WA-14 | Delete spec-based REST service | action | mgmnt DELETE /api/mgmnt/v2/:ns/:app | S | Pairs with WA-13. |

**3. Contest area 2: Permission management (PM)** — 4 rows (S 3 / M 0 / L 1)

| ID | Name | Kind | Backing (API or class) | Size | Note |
|---|---|---|---|---|---|
| PM-19 | Validate a candidate password against policy | settings | custom($SYSTEM.Security.ValidatePassword) | S | Custom wrapper over $SYSTEM.Security.ValidatePassword; SMP validates inline. |
| PM-20 | Role owners view / edit | form | admin-v2 /security/role/owners | S | No SMP twin (SMP shows role members). |
| PM-21 | User "Copy from" existing user | action | admin-v2 GET + POST /security/user | S | GET then POST; composed client-side. |
| PM-22 | SQL privileges: schema/table/view/procedure and column grants | form | admin-v2 /security/sql-privileges, /sql-column-privileges, /sql-admin-privileges (list, gran… | L | Two SMP dialogs (621 + 861 lines) over three admin-v2 route families. |

**4. Contest area 3: Security and secrets (SS)** — 8 rows (S 1 / M 6 / L 1)

| ID | Name | Kind | Backing (API or class) | Size | Note |
|---|---|---|---|---|---|
| SS-28 | LDAP configurations read-only view | viewer | admin-v2 GET /security/ldap/configurations | S | System Operation twin of SS-08; same route. |
| SS-29 | Superservers list / create / edit / delete | list+CRUD | admin-v2 /security/superservers | M | Under Security in the SMP; P2 per the explicit list (judgment call). |
| SS-30 | Authentication / web session options | settings | admin-v2 GET/PUT /security/web-auth, /smtp-password | M | Includes Reset Key Store; touches the JWT issuer OcuPilot itself depends on. |
| SS-31 | Managed File Transfer connections list / create / edit / delete | list+CRUD | admin-v2 /security/mft/connections | M | co-pilot write-confirm. |
| SS-32 | Encryption: create new key file | action | admin-v2 /security/encryption/file | M | co-pilot write-confirm. |
| SS-33 | Encryption: manage key file | action | admin-v2 /security/encryption/admins, /keys | M | co-pilot write-confirm. |
| SS-34 | Data element encryption activate / deactivate | action | admin-v2 /security/encryption/keys | M | co-pilot write-confirm. |
| SS-35 | Database encryption: activate/deactivate key, startup settings | settings | admin-v2 /security/encryption/settings | L | 634-line SMP page; interactive / unattended / KMIP startup options. |

**6. Contest area 5: OS management (OS)** — 8 rows (S 3 / M 4 / L 1)

| ID | Name | Kind | Backing (API or class) | Size | Note |
|---|---|---|---|---|---|
| OS-16 | Mount database | action | admin-v2 POST /database-dir/mount | S | Judgment call: disks parity stays at P2 while the list/details are P0. |
| OS-17 | Dismount database | action | admin-v2 POST /database-dir/dismount | S | MCP iris_database_action:dismount; co-pilot write-confirm. |
| OS-18 | Truncate database to target size | action | admin-v2 POST /database-dir/truncate | M | MCP iris_database_action:truncate; co-pilot write-confirm. |
| OS-19 | Compact database free space | action | admin-v2 POST /database-dir/compact (async) | M | Async: needs /async-result polling (the TM-16 pattern). |
| OS-20 | Defragment database | action | admin-v2 POST /database-dir/defragment (async) | M | Async with pre-check; /async-result polling. |
| OS-21 | Expand volume / modify database size | action | admin-v2 POST /database-dir/expand-volume, /modify-size | M | MCP iris_database_action:expandVolume; co-pilot write-confirm. |
| OS-22 | Integrity check wizard and integrity log viewer | wizard | admin-v2 POST /database-dir/integrity-check (async), async-result polling | L | Async wizard plus integrity log viewer; four SMP dialogs collapse into one flow. |
| OS-30 | Prometheus metrics viewer | viewer | monitor GET /api/monitor/metrics | S | Route already wired for OS-09; raw exposition rendered as a table. |

**7. Contest area 6: All the logs (LG)** — 1 row (S 0 / M 1 / L 0)

| ID | Name | Kind | Backing (API or class) | Size | Note |
|---|---|---|---|---|---|
| LG-11 | Live tail of text logs | viewer | custom(%SYSTEM.Event long-poll) | M | iris-couch ChangesHandler long-poll pattern; enhances the P0/P1 text-log viewers. |

**8. System Administration, remainder (SA)** — 20 rows (S 4 / M 12 / L 4)

| ID | Name | Kind | Backing (API or class) | Size | Note |
|---|---|---|---|---|---|
| SA-03 | Namespaces list | list | admin-v2 GET /namespaces | S | The P0 namespace switch (SH-03) already reads this list. |
| SA-04 | Journal settings | settings | admin-v2 GET/PUT /journal/settings | M | MCP iris_journal_info; co-pilot write-confirm. |
| SA-05 | WQM categories list / create / edit / delete | list+CRUD | admin-v2 /wqm-categories, /wqm-category | M | co-pilot write-confirm. |
| SA-06 | License key view / activate new key / validate / print | form | admin-v2 GET/PUT /license/key, POST /license/key/validate | M | MCP iris_license_info; co-pilot write-confirm. |
| SA-07 | License servers list / create / edit / delete | list+CRUD | admin-v2 GET /license/servers, GET/PUT/DELETE /license/server | M | co-pilot write-confirm. |
| SA-08 | ECP settings | settings | admin-v2 GET/PUT /ecp/settings | M | iris_ecp_status implementation not identified; relies on the route alone (Gaps). |
| SA-09 | ECP application servers | list+CRUD | admin-v2 /ecp/application-servers, /application-server-ssl-connections (+reject/authorize/de… | M | Same caveat as SA-08. |
| SA-10 | ECP data servers | list+CRUD | admin-v2 /ecp/data-servers, /ecp/data-server (+/action, /databases) | M | co-pilot write-confirm. |
| SA-11 | Namespace global / routine / package mappings | list+CRUD | admin-v2 mapping GET list, GET/PUT/DELETE one | M | Carry the %-global guard from execute-mcp MappingManage. |
| SA-12 | Edit namespace | action | admin-v2 PUT /namespace | M | MCP iris_namespace_manage:modify; co-pilot write-confirm. |
| SA-13 | Create namespace | action | admin-v2 PUT /namespace, POST /namespace/enable-interop | M | Inline create-database reuses SA-20. |
| SA-14 | Copy namespace mappings | settings | admin-v2 POST /namespace/copy-mappings (async) | S | Async; no SMP page (background task only). |
| SA-15 | Delete namespace wizard | wizard | admin-v2 DELETE /namespace | L | Wizard optionally deletes dependent DBs and web apps. |
| SA-16 | Local databases configuration list | list | admin-v2 GET /databases | S | MCP iris_database_list; co-pilot read. |
| SA-17 | Remote databases list / create / edit / delete | list+CRUD | admin-v2 GET/PUT/DELETE /database (config), /ecp/data-server/databases | M | co-pilot write-confirm. |
| SA-18 | Multi-volume properties | settings | admin-v2 GET /database-dir/volumes, POST /expand-volume | M | MCP iris_database_action:expandVolume; co-pilot write-confirm. |
| SA-19 | Database properties edit | settings | admin-v2 GET/PUT /database, PUT /database-dir | L | 748-line SMP page. |
| SA-20 | Create database wizard | wizard | admin-v2 POST /database-dir + PUT /database | L | 1058-line SMP wizard; SYS.Database.CreateDatabase. |
| SA-21 | Delete database wizard | wizard | admin-v2 DELETE /database, DELETE /database-dir | L | 436-line wizard listing dependent namespaces and apps. |
| SA-22 | Enable mirror service | action | admin-v2 PUT /security/service | S | Reuses the P0 service editor (PM-16); the mirror pages themselves are Stage 4. |

**9. System Operation, remainder (SO)** — 8 rows (S 6 / M 1 / L 1)

| ID | Name | Kind | Backing (API or class) | Size | Note |
|---|---|---|---|---|---|
| SO-01 | Journal files list | list | admin-v2 GET /journal/files | S | MCP iris_journal_info; co-pilot read. |
| SO-02 | Journal file summary | viewer | admin-v2 GET /journal/file | S | legacy CSP page, source not exported; co-pilot read. |
| SO-03 | Journal integrity check | action | admin-v2 POST /journal/file/integrity-check | S | legacy CSP page, source not exported; co-pilot write-confirm. |
| SO-04 | Switch journal file | action | admin-v2 POST /journal/switch-file | S | legacy CSP page, source not exported; co-pilot write-confirm. |
| SO-05 | Switch journal directory | action | admin-v2 POST /journal/switch-dir | S | legacy CSP page, source not exported; co-pilot write-confirm. |
| SO-06 | Journal record browser | viewer | admin-v2 POST /journal/file/records, GET /journal/file/record | L | Legacy CSP page (%CSP.UI.System.OpenJournalPane); kept out of area 6 by judgment call. |
| SO-07 | Dashboard drill-down statistics: global and routine statistics, ECP statistics, system re… | viewer | admin-v2 GET /monitor/dashboard/globals-and-routines, /ecp, /system-resources | S | Meter names and thresholds not captured (Gaps). |
| SO-08 | Interoperability usage | viewer | monitor GET /api/monitor/interop/v1/current and /historical interfaces, volume, databaseimpa… | M | Official InteropMetrics v1 (class marked deprecated, documented under GCM_rest). |

**14. Packaging, deployment and contest submission deliverables (PK)** — 1 row (S 0 / M 1 / L 0)

| ID | Name | Kind | Backing (API or class) | Size | Note |
|---|---|---|---|---|---|
| PK-25 | Multi-namespace install | platform | custom(OcuPilot.Installer.InstallIntoNamespace) | M | Validation: not %SYS, exists, interop-enabled where needed, package mapping. |

**Agent co-pilot capabilities in this stage.**

- Extend CP-12 (read tools) and CP-13 (propose-review-confirm write tools) to every screen in this stage — the "confirmed single writes" step of the addendum. No new CP row is needed for that; it is the same registry (CP-11) and the same runs-as-user gate (CP-14).
- CP-35 wallet-backed API key storage (S, admin-v2 `/wallet/secret`).
- CP-39 context-window management (M, custom) — the tool roster roughly doubles here.
- CP-41 proxy / custom CA for outbound LLM HTTPS (S, custom).
- CP-33 governance policy (P1) must cover the new destructive actions (delete namespace, delete database, dismount, truncate, encryption changes) as default-disabled.

**API readiness that gates the stage.**

- **Write payload shapes.** `/api/admin` request and response schemas were observed only for list/get shapes; "write payloads for every admin-v2 row are untested, and the v1 UrlMap was read only partially (PATCH/DELETE variants)" (Gaps). Every write in this stage needs the payload observed against the instance before the form is built; keep the auto-generated spec (`GET /api/mgmnt/v1/%25SYS/spec/api/admin`) under test per PK-09.
- **Async results.** Compact, defragment, integrity check, copy-mappings and database-dir info are async; the `/async-results` polling built for TM-16 (P1) is the pattern, noting that it tracks `%Api.Admin` async tasks, not `%CSP.UI.System.BackgroundTask` jobs.
- **Directory allow-list (SH-24)** must land before any server-path picker.
- **ECP.** `iris_ecp_status` implementation was not identified in the harvest, so SA-08/SA-09 rely on the admin-v2 routes alone.
- **Support stance.** InterSystems' support position on `/api/admin` is an open question carried from the research; this stage deepens the dependency on an undocumented service.

**Counts per size.**

| Section | S | M | L | Total |
|---|---|---|---|---|
| SH | 0 | 1 | 0 | 1 |
| CP | 2 | 1 | 0 | 3 |
| WA | 1 | 4 | 0 | 5 |
| PM | 3 | 0 | 1 | 4 |
| SS | 1 | 6 | 1 | 8 |
| OS | 3 | 4 | 1 | 8 |
| LG | 0 | 1 | 0 | 1 |
| SA | 4 | 12 | 4 | 20 |
| SO | 6 | 1 | 1 | 8 |
| PK | 0 | 1 | 0 | 1 |
| **Stage 1** | **20** | **31** | **8** | **59** |

### Stage 2 — System Explorer over the Atelier API, grid harvested from iris-table-editor (P2)

**36 rows** · S 17 / M 15 / L 4 · custom endpoints 1

**What the user can do at the end.** OcuPilot has a System Explorer for developers. Classes and routines are listed with the SMP's filters, viewed as source (Documatic quick view, class index, UDL/XML, macro-expanded .int), compiled, deleted, exported and imported as XML, edited and saved with ETag conflict detection, searched across the namespace, compared side by side, and looked up by macro. The SQL page has the catalog browser with its seven detail tabs, an execute-query console with parameter prompts, plan/explain, create-view, and the mandatory DML/DDL guard; SQL activity shows running statements. The data browser harvested from iris-table-editor gives a schema tree, a paged grid with type-aware cells, wildcard filters, sorting, pagination, inline editing with type-specific editors and undo, row insert/duplicate/delete with staged saves, CSV export, keyboard shortcuts, ARIA announcements, theme tokens and multi-table tabs. The Documatic class reference is embedded and a DocDB browser covers document databases. The co-pilot gets read tools over documents and catalog, confirmed writes for compile/delete/put and guarded SQL, and a picker so an Explorer agent can differ from the operations agent.

**Rows in this stage, grouped by catalog section.**

**1. Co-pilot agent (CP)** — 1 row (S 0 / M 1 / L 0)

| ID | Name | Kind | Backing (API or class) | Size | Note |
|---|---|---|---|---|---|
| CP-36 | Agent picker | agent | custom(agent registry replacing two literals) | M | With Explorer as a second domain, a developer agent and an ops agent can differ per area. |

**6. Contest area 5: OS management (OS)** — 1 row (S 0 / M 1 / L 0)

| ID | Name | Kind | Backing (API or class) | Size | Note |
|---|---|---|---|---|---|
| OS-23 | SQL activity: currently executing statements | viewer | atelier POST /:ns/action/query on INFORMATION_SCHEMA.CURRENT_STATEMENTS | M | Atelier action/query over INFORMATION_SCHEMA.CURRENT_STATEMENTS; cancel is OS-24 (Stage 4). |

**10. System Explorer and data browser (EX)** — 33 rows (S 17 / M 12 / L 4)

| ID | Name | Kind | Backing (API or class) | Size | Note |
|---|---|---|---|---|---|
| EX-02 | Classes list | list | atelier GET /:ns/docnames/CLS, POST /modified | M | MCP iris_doc_list; iris_package_list; co-pilot read. |
| EX-03 | Routines list | list | atelier GET /:ns/docnames/RTN | M | MCP iris_doc_list; co-pilot read. |
| EX-04 | Source view: class / routine source, Documatic quick view, class structure index, UDL↔XML… | viewer | atelier GET /:ns/doc/:name, POST /action/index, GET ?format=, GET .int | M | MCP iris_doc_get; iris_doc_index; iris_doc_convert; iris_routine_intermediate; co-pilot read. |
| EX-05 | Compile selected classes / routines | action | atelier POST /:ns/action/compile | S | Streamed compile output; flags k, b, u. |
| EX-06 | Delete classes / routines | action | atelier DELETE /:ns/doc/:name, DELETE /:ns/docs | S | MCP iris_doc_delete; co-pilot write-confirm. |
| EX-07 | Export classes / routines to XML | action | atelier v7 POST /:ns/action/xml/export | M | Atelier v7 route: IRIS-version gate. |
| EX-08 | Import XML or source from server/local file | action | atelier v7 POST /:ns/action/xml/load, /xml/list; PUT /:ns/doc/:name | L | Atelier v7 xml/load and xml/list plus PUT doc; IRIS-version gate. |
| EX-09 | Source editor | editor | atelier PUT /:ns/doc/:name (ETag) | L | ETag conflict check; SMP has no editor (links out to Studio/VS Code). |
| EX-10 | Find text across routines / classes | viewer | atelier v2 GET /:ns/action/search | S | MCP iris_doc_search; co-pilot read. |
| EX-11 | Macro definition / location lookup | viewer | atelier v2 POST /:ns/action/getmacrodefinition, getmacrolocation | S | MCP iris_macro_info; co-pilot read. |
| EX-12 | Routine compare | viewer | atelier GET /:ns/doc/:name ×2 with client-side diff (SMP uses %Routine:Compare) | M | Client-side diff; SMP calls %Routine:Compare. |
| EX-13 | SQL catalog browser: schemas, tables, views, procedures with Fields / Indices / Triggers… | viewer | atelier POST /:ns/action/query on INFORMATION_SCHEMA and CALL %SQL_Manager.Catalog queries | L | 3909-line SMP page; INFORMATION_SCHEMA plus CALL %SQL_Manager.Catalog queries. |
| EX-14 | Execute query tab | console | atelier POST /:ns/action/query ({query, parameters}) | L | action/query runs any statement type; ship with EX-15. |
| EX-15 | SQL DML/DDL guard for query console and agent SQL tool | console | atelier POST /:ns/action/query (client-side statement-type check plus confirm) | S | Client-side statement-type check plus confirm; also guards the agent SQL tool (verify C6). |
| EX-16 | Show plan / explain for a statement | viewer | atelier POST /:ns/action/query EXPLAIN | M | MCP iris_sql_analyze:explain; co-pilot read. |
| EX-17 | Create / edit SQL view | action | atelier POST /:ns/action/query (CREATE VIEW) | M | CREATE VIEW through action/query. |
| EX-18 | Data browser: table tree grouped by schema | grid | atelier action/query INFORMATION_SCHEMA.TABLES | S | harvest table-editor main.js parseTablesBySchema / renderSchemaTree; co-pilot read. |
| EX-19 | Data browser: column metadata and primary-key detection | grid | atelier action/query INFORMATION_SCHEMA.COLUMNS | S | harvest table-editor TableMetadataService.getTableSchema; co-pilot read. |
| EX-20 | Data browser: paged grid | grid | atelier action/query | M | harvest table-editor QueryExecutor.getTableData; co-pilot read. |
| EX-21 | Data browser: type-aware cell formatting | grid | none | S | harvest table-editor DataTypeFormatter.ts (wrap). |
| EX-22 | Data browser: filtering with wildcards and AND, plus filter panel | grid | atelier action/query (LIKE ? ESCAPE) | S | harvest table-editor SqlBuilder.buildFilterWhereClause; co-pilot read. |
| EX-23 | Data browser: single-column sorting | grid | atelier action/query ORDER BY | S | harvest table-editor SqlBuilder.buildOrderByClause; co-pilot read. |
| EX-24 | Data browser: pagination controls | grid | none | S | harvest table-editor grid.js updatePaginationUI. |
| EX-25 | Data browser: inline cell editing with type-specific editors | grid | none | M | harvest table-editor grid.js enterEditMode / createDatePicker / setCellToNull. |
| EX-26 | Data browser: cell save with optimistic UI and rollback | grid | atelier action/query UPDATE | M | MCP iris_sql_execute; co-pilot write-confirm. |
| EX-27 | Data browser: edit-mode undo | grid | none | S | harvest table-editor grid.js l.3060-3075. |
| EX-28 | Data browser: row insert / duplicate / delete | grid | atelier action/query INSERT / DELETE | M | MCP iris_sql_execute; co-pilot write-confirm. |
| EX-29 | Data browser: CSV export of current page | grid | none | S | harvest table-editor grid.js generateCsvContent / downloadCsv. |
| EX-30 | Data browser: keyboard shortcuts, shortcuts help dialog, go-to-row dialog | grid | none | S | harvest table-editor grid.js handleCellKeydown / showKeyboardShortcutsHelp / showGoToRowDialog. |
| EX-31 | Data browser: accessibility | grid | none | S | harvest table-editor grid.js announce. |
| EX-32 | Data browser: theming tokens | grid | none | S | harvest table-editor theme.css --ite-* / --ite-theme-*. |
| EX-33 | Data browser: multi-table tabs | grid | none | M | harvest table-editor desktop tab-bar.js pattern. |
| EX-34 | Documatic class reference embedded | embed | embed /csp/documatic/%25CSP.Documatic.cls?LIBRARY=&CLASSNAME= | S | Iframe over /csp/documatic; needs the browser-level session (see SH-23). |

**13. Developer tools and sibling-tool equivalents not covered above (DT)** — 1 row (S 0 / M 1 / L 0)

| ID | Name | Kind | Backing (API or class) | Size | Note |
|---|---|---|---|---|---|
| DT-01 | DocDB data browser: databases list / create / drop | list+CRUD | official /api/docdb/v1/:ns (needs %Service_DocDB) | M | Rider on Explorer: needs %Service_DocDB enabled; four MCP handlers to harvest. |

**Agent co-pilot capabilities in this stage.**

- Read tools over Atelier documents and the SQL catalog (doc list/get/index/search, macro lookup, catalog queries); confirmed single writes for compile (EX-05), delete (EX-06), put (EX-09), import (EX-08).
- EX-15 SQL DML/DDL guard is itself the agent-facing item: the P0 SQL tool used catalog SELECTs only; the free-form console and agent SQL tool need the statement-type check plus confirm (api-coverage-verify C6).
- CP-36 agent picker (M, custom) — multiple named agents per area with an About bubble.

**API readiness that gates the stage.**

- **`action/query` semantics.** It executes any statement type unguarded (api-coverage-verify C6); EX-15 must ship with EX-14 and the agent SQL tool.
- **Atelier version.** XML export/load are v7 routes (EX-07, EX-08); the web terminal (DT-04, Stage 4) also needs v7. The ETag conflict path for `PUT /doc` (EX-09) must be observed.
- **Harvest.** The iris-table-editor grid, SqlBuilder, DataTypeFormatter, theme tokens and keyboard handling are the harvest for EX-18..EX-33; its export/import is VS Code-only (EX-35 stays P3).
- **Same-origin session for the Documatic iframe (EX-34)** — the browser-level login that SH-23 formalises in Stage 3.
- **DocDB** requires `%Service_DocDB` enabled (DT-01).
- **Globals via Atelier** is untested: if `CALL %SYS.GlobalQuery_NameSpaceList` works through `action/query`, EX-37 moves from Stage 4 into this stage (Gaps).

**Counts per size.**

| Section | S | M | L | Total |
|---|---|---|---|---|
| CP | 0 | 1 | 0 | 1 |
| OS | 0 | 1 | 0 | 1 |
| EX | 17 | 12 | 4 | 33 |
| DT | 0 | 1 | 0 | 1 |
| **Stage 2** | **17** | **15** | **4** | **36** |

### Stage 3 — Interoperability over the interop-editors v7 API with the three vendor editors embedded (P2), plus the Analytics rider

**41 rows** · S 10 / M 25 / L 6 · custom endpoints 6

**What the user can do at the end.** The Interoperability category appears for namespaces that support it. Productions are listed with status and started, stopped, restarted, updated and recovered; items are enabled, disabled, added, removed and their settings edited; each host exposes queue, log, messages, jobs and actions tabs; the production monitor, queues and jobs pages (reads on v7; abort/suspend actions flagged custom), lookup tables with full CRUD and import/export, business partners (read), test-a-business-host and test-a-transformation, and activity charts are all present. The three vendor Angular editors — rules, BPL and DTL — and the production-configuration diagram are embedded through the JWT session hand-off, with the schema viewer for HL7, X12 and ASTM read-only browsing; messages are searched, viewed, resent (dry-run then confirm), traced visually or as a Mermaid diagram, and their contents rendered; source-control hooks serve the embedded editors. As a rider, Analytics gains cube list, model browser, MDX query tool, term-list and folder browsing, the cube manager, and links to Architect, Analyzer and User Portal. The co-pilot runs guided multistep workflows harvested from the eleven MCP prompts and offers an "Investigate" entry point on alerts and log entries that returns a recap and ranked hypotheses.

**Rows in this stage, grouped by catalog section.**

**0. Portal shell and platform (SH)** — 2 rows (S 0 / M 2 / L 0)

| ID | Name | Kind | Backing (API or class) | Size | Note |
|---|---|---|---|---|---|
| SH-23 | Session sharing / JWT hand-off for embedded InterSystems Angular editors | platform | interop-v7 login and /%SYS/session endpoints | M | Gate for every embed here; the cookie carrying the silent JWT login was not isolated (Gaps). |
| SH-25 | Product-category gating by namespace | platform | official GET /api/atelier/v1/:ns (features) | M | Atelier-backed; only meaningful once the Interop and Analytics categories exist. |

**1. Co-pilot agent (CP)** — 2 rows (S 0 / M 1 / L 1)

| ID | Name | Kind | Backing (API or class) | Size | Note |
|---|---|---|---|---|---|
| CP-37 | "Investigate" entry points on alerts and log entries launching a multi-step run with reca… | agent | custom | L | Multi-step run with recap and ranked hypotheses; entry points on alerts and log entries (LG-10). |
| CP-38 | Guided workflows harvested from the 11 MCP prompts | agent | custom | M | The 11 MCP prompts (check-system-health, audit-security-posture, recover-stuck-production, resend-failed-messages, diagnose-slow-query, run-external-backup, …). |

**11. Interoperability (IO)** — 28 rows (S 4 / M 20 / L 4)

| ID | Name | Kind | Backing (API or class) | Size | Note |
|---|---|---|---|---|---|
| IO-02 | Productions list with status | list+CRUD | interop-v7 GET /{ns}/productions, /productions/status | S | MCP iris_production_status; iris_production_summary; iris_production_manage:delete; co-pilot read. |
| IO-03 | Business rules list | list+CRUD | interop-v7 GET /{ns}/rules | S | MCP iris_rule_list; co-pilot read. |
| IO-04 | Data transformations list | list+CRUD | interop-v7 GET /{ns}/transforms | M | MCP iris_transform_list; co-pilot read. |
| IO-05 | Business processes list | list+CRUD | interop-v7 /{ns}/business-classes/{type}; atelier docnames | M | Mixed: interop-v7 business-classes plus atelier docnames. |
| IO-06 | Start / stop / restart / update / recover production | action | interop-v7 /productions/{class}/{hostName}/{action} (UpdateProduction), /productions/product… | M | UpdateProduction {action} vocabulary not read (Gaps); recover-before-clean guidance. |
| IO-07 | Enable / disable a production item | action | interop-v7 PUT /{hostID}/settings, /{hostName} POST/PUT, /settings-options | M | MCP iris_production_item:get/set/enable/disable; co-pilot write-confirm. |
| IO-08 | Add / remove production items | action | interop-v7 POST /productions/{class}/{hostName}, PUT /{hostName} (PutHostClass), /business-c… | M | MCP iris_production_item:add/remove; iris_production_adapters; iris_production_manage:create; co-pilot write-confirm. |
| IO-09 | Per-host Queue / Log / Messages / Jobs / Actions tabs | viewer | interop-v7 /productions/{class}/{hostName}/queue, /log, /jobs, /messages | M | MCP iris_production_queues; iris_production_logs; iris_production_messages; co-pilot read. |
| IO-10 | Production monitor | viewer | interop-v7 /productions/status plus per-host queue/log | M | MCP iris_production_status; iris_metrics_interop; co-pilot read. |
| IO-11 | Queues | list+actions | interop-v7 per-host /queue; custom(Ens.Queue AbortItem / AbortQueue) for actions | M | Read via v7; Abort / Abort All / Suspend need custom (Ens.Queue). |
| IO-12 | Jobs | list+actions | interop-v7 per-host /jobs, GET /{ns}/processes; custom(Ens.Job) for actions | M | Read via v7; Abort / Stop / Suspend need custom (Ens.Job). |
| IO-13 | Data lookup tables | list+CRUD | interop-v7 /{ns}/lookup-tables, /lookup-table/{name} GET/POST/PUT/DELETE, /lookup-table/expo… | M | Full CRUD plus import/export on v7. |
| IO-14 | Business partners view | viewer | interop-v7 GET /{ns}/business-partners; custom(Ens.Config.BusinessPartner) for save/remove | M | View via v7; save/remove need custom (Ens.Config.BusinessPartner). |
| IO-15 | Test business hosts | action | interop-v7 /productions/production/test/{class}/{target} (TestProductionTarget, GetTargetReq… | M | co-pilot write-confirm. |
| IO-16 | Test data transformation on pasted input | action | interop-v7 GET/POST /dtl/test/{dtlClass} | M | MCP iris_transform_test; co-pilot write-confirm. |
| IO-17 | Activity volume and duration charts | viewer | deepsee POST /api/deepsee/v1/:ns/Data/KPIExecute | M | DeepSee KPI iframe in the SMP; deepsee route here. |
| IO-18 | Rule editor | embed | embed + interop-v7 /rules/* | M | Embed verdict High; VSCODE-mode messages (saved/compiled/badrule) not exercised live. |
| IO-19 | HL7 v2.x schema structures browser | embed | embed /ui/interop/schema-viewer (read-only) + interop-v7 /{ns}/schemas/* | M | Embed verdict Medium-Low; document-selection parameter unproven. |
| IO-20 | ASC X12 schema structures browser | embed | embed schema-viewer + interop-v7 /schemas | S | Read-only browse; X12 authoring is P4 (IO-86). |
| IO-21 | ASTM schema structures browser | embed | embed schema-viewer + interop-v7 /schemas | S | Read-only browse; ASTM authoring is P4 (IO-87). |
| IO-22 | Production configuration diagram | embed | embed + interop-v7 productions routes | L | Embed verdict Medium; sibling editors open in new tabs. |
| IO-23 | BPL editor | embed | embed + interop-v7 /bpl/* (compile, validate, context) | L | Embed verdict High. |
| IO-24 | DTL editor | embed | embed + interop-v7 /dtl/* | L | Embed verdict High; app-dtl-test, function wizard, explain. |
| IO-25 | Message viewer | embed | embed + interop-v7 /{ns}/messages POST/GET/DELETE, /messages/message/{id}, /search/saved, /h… | L | Embed message-viewer or rebuild on the v7 search API. |
| IO-26 | Resend / edit-and-resend messages | action | interop-v7 POST /messages/resend | M | dryRun + confirm, cap 500, from execute-mcp. |
| IO-27 | Visual trace of a session and Mermaid sequence diagram | embed | embed message-viewer?SESSIONID=; interop-v7 /messages/trace/{sessionid} | M | Mermaid alternative from execute-mcp Diagram.Generate. |
| IO-28 | Message contents renderer | viewer | custom(Ens.Util.MessageBodyMethods) or embed message-viewer | M | Must be rebuilt for a non-Zen viewer, or use the embed. |
| IO-29 | Source-control hooks for editors | platform | interop-v7 /{ns}/sourcecontrol/enabled, /menus, /useraction, /status | M | Needed by the embedded editors when source control is on. |

**12. Analytics (AN)** — 9 rows (S 6 / M 2 / L 1)

| ID | Name | Kind | Backing (API or class) | Size | Note |
|---|---|---|---|---|---|
| AN-02 | Cube list | list | deepsee GET /api/deepsee/v1/:ns/Info/Cubes | S | Analytics rider: the addendum names no Analytics stage. |
| AN-03 | Model browser | viewer | deepsee /Info/Cubes, /Info/Measures/:cube, /Info/Filters | S | Analytics rider. |
| AN-04 | Architect | link | link _DeepSee.UI.Architect.zen (rebuild excluded, P4) | S | Link to the namespace Zen app; rebuild excluded (AN-23). |
| AN-05 | Analyzer | link | link _DeepSee.UI.Analyzer.zen (rebuild excluded) | S | Link; rebuild excluded (AN-23). |
| AN-06 | User Portal | link | link _DeepSee.UserPortal.Home.zen (rebuild excluded) | S | Link; rebuild excluded (AN-23). |
| AN-07 | MDX query tool | console | deepsee POST /Data/MDXExecute, /Data/MDXDrillthrough, /MDXCancelQuery | M | Analytics rider. |
| AN-08 | Term list viewer | list | deepsee GET /Data/GetTermList, /Info/TermLists | S | Read only; the editor is AN-11 (Stage 4). |
| AN-09 | Folder manager: browse folder items | viewer | deepsee /Info/Pivots, /Info/Dashboards, /Data/Favorites | M | Browse only; export/import/delete is AN-14 (Stage 4). |
| AN-10 | Cube manager: register, group, schedule, build / synchronize cubes | editor | deepsee /Command/BuildCube, /SynchronizeCube, /BuildAllRegisteredGroups, /RepairBuild, /*Reg… | L | 3288-line SMP page; the one Analytics write at P2. |

**Agent co-pilot capabilities in this stage.**

- CP-38 guided workflows harvested from the 11 MCP prompts (M, custom, read) — the "guided multistep workflows" step of the addendum. recover-stuck-production and resend-failed-messages need this stage's screens; check-system-health, audit-security-posture and diagnose-slow-query can run on Stage 1–2 screens.
- CP-37 "Investigate" entry points on alerts and log entries launching a multi-step run with recap and ranked hypotheses (L, custom, read); pairs with the P1 unified log hub (LG-10).
- Read tools over interop-v7 (production status/summary, queues, logs, messages, rule list, transform list, lookup tables) and confirmed writes for production control (recover before clean), item enable/disable/settings, lookup-table CRUD, resend with dry-run + confirm (cap 500), and transform test.
- Analytics rider: cube list and MDX execute as read tools; cube build/sync as confirmed writes.

**API readiness that gates the stage.**

- **SH-23 session hand-off** is the gate for IO-18..IO-25 and IO-27: the cookie that carries the silent JWT login for `/ui/interop` was not isolated, VSCODE mode was not exercised live, and the schema-viewer document-selection parameter is unproven (Gaps). Group-by-ID (`%ISCMgtPortal`) is deprecated in the docs while the vendor portal depends on it; the JWT-only path is the fallback (addendum, Secondary risks).
- **SH-25 category gating** by namespace features from `GET /api/atelier/v1/:ns`.
- **UpdateProduction `{action}` vocabulary** (IO-06) and the semantics of `/productions/production/state/{class}` were not read.
- **Angular per-component behaviour** (interop-editor `HOST=`, `NEW=1`, `app-explain-label`, file-explorer) is inferred from selector names without source maps.
- **Custom halves.** Queue and job actions (IO-11, IO-12), business-partner save/remove (IO-14) and the message-contents renderer (IO-28) need custom endpoints or the embed; they can ship read-only first.
- **Analytics rider** needs a DeepSee-enabled namespace for anything beyond the links (AN-04..06).

**Counts per size.**

| Section | S | M | L | Total |
|---|---|---|---|---|
| SH | 0 | 2 | 0 | 2 |
| CP | 0 | 1 | 1 | 2 |
| IO | 4 | 20 | 4 | 28 |
| AN | 6 | 2 | 1 | 9 |
| **Stage 3** | **10** | **25** | **6** | **41** |

### Stage 4 — Custom-REST parity harvested from the MCP suite's handlers (P3)

**165 rows** · S 60 / M 79 / L 26 · custom endpoints 158

**What the user can do at the end.** Every remaining SMP leaf with a backing class but no route is reachable through OcuPilot's own REST router, with handlers harvested from the MCP suite where one exists. System Administration completes with backup (list, run, status, history, freeze/thaw), the whole mirroring set (create, edit failover and async members, join, monitor, member and database actions), startup/memory/compatibility tables, NLS locales, SQL/TSQL/ISQL settings, DDL mappings, monitor/OpenTelemetry, source control, log daemon, archive targets, ML configurations and SQL Gateway. Explorer completes with globals (list, view, edit, kill, export/import), replace, query history, the SQL statement index with frozen plans, tune table, cached-query purge, runtime statistics, index analyzer, alternate plans, troubleshooting reports, the SQL wizards, CSV/Excel round-trip and composite keys. Interoperability completes with credentials, default settings, purge, auto-start, managed alerts, rule and BP logs, suspended messages, export, schedules, PEX, registries, record maps, interface maps and references, port authority, system monitor, archive, workflow, deployment, shutdown groups, settings, HL7 custom-schema authoring and the EDI document viewers. Analytics gains its editors; developer tools add a unit-test runner, work-queue viewer, web terminal, execute-command and class-method consoles, LOC metrics, drift hashes, environment diff/promote and remote profiles. The remaining shell, permission, security, task, OS and log leaves close. The co-pilot gains the 28 session-agent inspection and search tools for interop sessions, undo/rollback of an agent-applied change, and streamed responses.

**Rows in this stage, grouped by catalog section.**

**0. Portal shell and platform (SH)** — 3 rows (S 0 / M 3 / L 0)

| ID | Name | Kind | Backing (API or class) | Size | Note |
|---|---|---|---|---|---|
| SH-26 | Security escalation | platform | custom(%session.EscalateLogin) | M | Escalate login to role; %session.EscalateLogin. |
| SH-27 | Assign custom resource to a menu item | platform | custom(%CSP.Portal.Utils.%SetCustomResource) | M | Resource mode for %Admin_Secure; no harvest, write from the backing class. |
| SH-28 | Contact / open WRC issue form | platform | custom(SMTP send) | M | Sends email to the WRC; needs SMTP configuration; no harvest. |

**1. Co-pilot agent (CP)** — 2 rows (S 0 / M 0 / L 2)

| ID | Name | Kind | Backing (API or class) | Size | Note |
|---|---|---|---|---|---|
| CP-34 | Streaming responses | agent | custom(new provider-side path) | L | P2 by tier, sequenced last by the addendum; new provider-side SSE path; PK-08 gateway timeout. |
| CP-40 | Undo / rollback of an agent-applied change | agent | custom | L | Not evidenced in any source; iris-copilot version-snapshot rollback is the nearest idea. |

**2. Contest area 1: Web apps and REST APIs (WA)** — 2 rows (S 0 / M 2 / L 0)

| ID | Name | Kind | Backing (API or class) | Size | Note |
|---|---|---|---|---|---|
| WA-15 | Web application copy / export / import | action | custom(Security.Applications.Export/Import) | M | co-pilot write-confirm. |
| WA-16 | Web Gateway Management | settings | custom(backing class not inventoried) | M | Legacy CSP; backing class not inventoried (Gaps). |

**3. Contest area 2: Permission management (PM)** — 2 rows (S 1 / M 1 / L 0)

| ID | Name | Kind | Backing (API or class) | Size | Note |
|---|---|---|---|---|---|
| PM-23 | TOTP / QR code generation for user two-factor | action | custom($$GenerateQRCode^%SYS.SECURITY) | S | QR generation routine $$GenerateQRCode^%SYS.SECURITY. |
| PM-24 | Resource export / import to XML | action | custom(Security.Resources export/import) | M | co-pilot write-confirm. |

**4. Contest area 3: Security and secrets (SS)** — 4 rows (S 2 / M 2 / L 0)

| ID | Name | Kind | Backing (API or class) | Size | Note |
|---|---|---|---|---|---|
| SS-36 | Export audit log to file | action | custom(%SYS.Audit.Export) | S | Audit routes have no export (api-coverage). |
| SS-37 | Mobile phone providers list / create / delete | list+CRUD | custom(%SYS.PhoneProviders) | S | co-pilot write-confirm. |
| SS-38 | System-wide security parameters | settings | custom(Security.System) | M | co-pilot write-confirm. |
| SS-39 | Security Advisor recommendations | viewer | custom(%CSP.UI.System.SecurityAdvisorPane) | M | Legacy CSP; pairs with the audit-security-posture prompt (CP-38). |

**5. Contest area 4: Task management (TM)** — 3 rows (S 1 / M 2 / L 0)

| ID | Name | Kind | Backing (API or class) | Size | Note |
|---|---|---|---|---|---|
| TM-17 | Task output file viewer | viewer | custom(file read) | S | co-pilot read. |
| TM-18 | Task Manager email settings | settings | custom(backing not inventoried) | M | Legacy CSP; backing not inventoried (Gaps). |
| TM-19 | Diagnostic Reports | form | custom(%SYS.Task DiagnosticReport) | M | legacy CSP page, source not exported; co-pilot write-confirm. |

**6. Contest area 5: OS management (OS)** — 6 rows (S 2 / M 3 / L 1)

| ID | Name | Kind | Backing (API or class) | Size | Note |
|---|---|---|---|---|---|
| OS-24 | Cancel a running SQL query | action | custom(%SYSTEM.SQL.CancelQuery) | S | co-pilot write-confirm. |
| OS-25 | Process variables tab | viewer | custom(SYS.Process:VariableByPid) | M | co-pilot read. |
| OS-26 | Memory and startup configuration | settings | custom(Config.config, Config.Startup) | M | Judgment call: memory monitoring is P0, configuration has no route. |
| OS-27 | Transactions | viewer | custom(SYS.Metrics.SystemMonitorStatus, ^IRIS.Temp.SysMetrics) | S | co-pilot read. |
| OS-28 | Full System Dashboard | viewer | admin-v2 dashboard routes plus custom(meter semantics from %CSP.Util.HTMLDashboardPane) | L | Meter names and thresholds not captured (Gaps). |
| OS-29 | Composite health check verdict | viewer | custom(ExecuteMCPv2.REST.Health pattern) | M | health.ts thresholds; pattern ExecuteMCPv2.REST.Health. |

**7. Contest area 6: All the logs (LG)** — 1 row (S 1 / M 0 / L 0)

| ID | Name | Kind | Backing (API or class) | Size | Note |
|---|---|---|---|---|---|
| LG-12 | System alerts state and reset | action | custom(ExecuteMCPv2 Monitor:SystemAlerts / AlertsManage) | S | MCP iris_metrics_alerts; iris_alerts_manage:reset; co-pilot write-confirm. |

**8. System Administration, remainder (SA)** — 27 rows (S 1 / M 19 / L 7)

| ID | Name | Kind | Backing (API or class) | Size | Note |
|---|---|---|---|---|---|
| SA-23 | Startup settings table | settings | custom(Config.Startup) | M | MCP iris_config_manage:get/set startup; co-pilot write-confirm. |
| SA-24 | Advanced memory settings table | settings | custom(Config.config) | M | MCP iris_config_manage:get/set/export config; co-pilot write-confirm. |
| SA-25 | Compatibility settings table | settings | custom(Config.Miscellaneous) | M | co-pilot write-confirm. |
| SA-26 | NLS configured defaults | settings | custom(%SYS.NLS.Table, Config.NLS.Locales) | S | MCP iris_config_manage:get locale; co-pilot read. |
| SA-27 | Locale definitions | editor | custom(Config.NLS.Locales, Config.NLS.Tables) | L | MCP iris_config_manage:set locale; co-pilot write-confirm. |
| SA-28 | Import locales or tables from file | list+CRUD | custom(Config.NLS.Locales.Import) | M | co-pilot write-confirm. |
| SA-29 | SQL system settings | settings | custom(Config.SQL) | M | co-pilot write-confirm. |
| SA-30 | Object settings | settings | custom(backing resolved dynamically; not captured) | M | Backing class not captured by the extraction (Gaps). |
| SA-31 | TSQL compatibility settings | settings | custom(Config.SQL) | M | co-pilot write-confirm. |
| SA-32 | ISQL compatibility settings | settings | custom(Config.SQL) | M | co-pilot write-confirm. |
| SA-33 | System DDL mappings | settings | custom(Config.SqlSysDatatypes) | M | co-pilot write-confirm. |
| SA-34 | User DDL mappings | settings | custom(Config.SqlUserDatatypes) | M | co-pilot write-confirm. |
| SA-35 | Monitor settings | settings | custom(SYS.Monitor.OTel); admin-v2 PUT /security/service for the service | M | MCP iris_service_manage; co-pilot write-confirm. |
| SA-36 | Source control class per namespace | settings | custom(%Studio.SourceControl.Interface) | M | co-pilot write-confirm. |
| SA-37 | Log daemon configuration | settings | custom(Config.LogDaemon, SYS.LogDmn) | M | co-pilot write-confirm. |
| SA-38 | Archive targets list / create / edit / delete | list+CRUD | custom(Config.Archives) | M | co-pilot write-confirm. |
| SA-39 | Machine learning configurations | list+CRUD | custom(%SYS.ML.Configuration) | M | co-pilot write-confirm. |
| SA-40 | SQL Gateway connections | list | custom(backing not inventoried) | M | Legacy CSP; backing not inventoried (Gaps). |
| SA-41 | Backup database list | list+CRUD | custom(Backup.General.AddDatabaseToList / RemoveDatabaseFromList; query DatabaseList) | M | Legacy CSP page never exported (Gaps). |
| SA-42 | Run backup: Full all databases / Full list / Incremental / Cumulative | list+actions | custom(Backup.General.StartTask) | M | Four leaves in one row; same four in SO-09. |
| SA-43 | Add local databases to mirror | action | custom(SYS.MirrorConfiguration; background task MirrorAddDatabases) | M | co-pilot write-confirm. |
| SA-44 | Mirror database properties | settings | custom(SYS.Database, SYS.MirrorConfiguration) | L | MCP iris_mirror_status; co-pilot write-confirm. |
| SA-45 | Create a mirror | action | custom(SYS.Mirror, SYS.MirrorConfiguration) | L | MCP iris_mirror_status; co-pilot write-confirm. |
| SA-46 | Edit mirror | action | custom(Config.Mirrors, Config.MirrorMember, SYS.Mirror) | L | MCP iris_mirror_status; co-pilot write-confirm. |
| SA-47 | Edit async member | action | custom(Config.MapMirrors, SYS.Mirror) | L | co-pilot write-confirm. |
| SA-48 | Join as failover member | action | custom(SYS.Agent, SYS.Mirror) | L | co-pilot write-confirm. |
| SA-49 | Join as async member | action | custom(SYS.Mirror, Config.Mirrors) | L | co-pilot write-confirm. |

**9. System Operation, remainder (SO)** — 9 rows (S 5 / M 2 / L 2)

| ID | Name | Kind | Backing (API or class) | Size | Note |
|---|---|---|---|---|---|
| SO-09 | Run backup now: Full all databases / Full list / Incremental / Cumulative | list+actions | custom(Backup.General.StartTask) | M | Four leaves in one row; same four in SA-42. |
| SO-10 | Backup status per backup task | viewer | custom(Backup.Task:List) | S | legacy CSP page, source not exported; co-pilot read. |
| SO-11 | Backup history | viewer | custom(Backup.Task:History, ^SYS("BUHISTORY")) | S | MCP iris_backup_manage:listHistory; co-pilot read. |
| SO-12 | Database freeze / thaw | action | custom(Backup.General ExternalFreeze / ExternalThaw; IsWDSuspended) | S | MCP iris_backup_manage:freeze/thaw; co-pilot write-confirm. |
| SO-13 | Journal purge | action | custom(%SYS.Journal.File:Purgeable; purge method unresolved) | S | Purge method unresolved (Gaps). |
| SO-14 | Journal profile | viewer | custom(JOB ComputeJournalProfile, ^IRIS.Temp.JournalProfile) | M | legacy CSP page, source not exported; co-pilot read. |
| SO-15 | Mirror journal files | list | custom(%SYS.Journal.File:MirrorByTimeReverseOrder) | S | legacy CSP page, source not exported; co-pilot read. |
| SO-16 | Mirror monitor | viewer | custom(SYS.Mirror MemberStatusList, MirroredDatabaseDisplay; %SYSTEM.Mirror) | L | 1546-line SMP page. |
| SO-17 | Mirror actions: start/stop mirror on this member, set/clear no-failover, promote to failo… | action | custom(SYS.Mirror, SYS.MirrorConfiguration; background tasks MirrorMountDB etc.) | L | Largest single write surface in this stage. |

**10. System Explorer and data browser (EX)** — 20 rows (S 4 / M 11 / L 5)

| ID | Name | Kind | Backing (API or class) | Size | Note |
|---|---|---|---|---|---|
| EX-35 | Data browser: CSV / Excel export of all or filtered rows | grid | atelier action/query (page loops) | M | Atelier action/query page loops; table-editor export/import is VS Code-only, port to browser ExcelJS. |
| EX-36 | Data browser: composite primary-key support | grid | custom(%Dictionary / atelier action/index) | M | Lifts the table-editor single-column-PK limitation. |
| EX-37 | Globals list | list | custom(%SYS.GlobalQuery:NameSpaceList; possibly CALL via action/query) | M | Could move to Stage 2 if CALL %SYS.GlobalQuery_NameSpaceList works through action/query (Gaps). |
| EX-38 | Global view | viewer | custom(ExecuteMCPv2 REST.Global pattern) | M | Legacy CSP page; pattern ExecuteMCPv2 REST.Global. |
| EX-39 | Global edit / drill | action | custom(%Studio.Global.Set / Kill) | M | Legacy CSP page; %Studio.Global.Set / Kill. |
| EX-40 | Delete global from list | list+CRUD | custom | S | MCP iris_global_kill; co-pilot write-confirm. |
| EX-41 | Global export / import | action | custom(background task Export / Import) | M | co-pilot write-confirm. |
| EX-42 | Replace text across routines / globals | action | custom | M | Legacy CSP; %Development:USE is not in %SYS. |
| EX-43 | Query history | viewer | custom(%SQL.Manager.Catalog:QueryHistory) | S | co-pilot read. |
| EX-44 | SQL statement index and statement details | viewer | custom(%SQL.Manager.Catalog StatementIndex / GetStatementInfo; %SYSTEM.SQL) | L | MCP iris_sql_analyze:stats; co-pilot write-confirm. |
| EX-45 | Export / import SQL statements to XML | action | custom(%SYSTEM.SQL.ExportSQLStatement / ExportAllSQLStatements) | M | co-pilot write-confirm. |
| EX-46 | Tune table and tune all tables in schema | list+CRUD | custom(%SYSTEM.SQL.Stats.Table; background TuneTables) | M | co-pilot write-confirm. |
| EX-47 | Purge cached queries, rebuild indices, drop item | action | custom(%SYSTEM.SQL PurgeAllCachedQueries; background RebuildIndices) | S | co-pilot write-confirm. |
| EX-48 | SQL runtime statistics | viewer | custom(%SYS.PTools.StatsSQL) | L | MCP iris_sql_analyze:stats; co-pilot read. |
| EX-49 | Index analyzer and index advice | viewer | custom(%SYS.PTools.UtilSQLAnalysis; ExecuteMCPv2 SqlAdvisor) | L | MCP iris_sql_analyze:indexUsage/advise; co-pilot read. |
| EX-50 | Alternate show plans | viewer | custom(%SYS.PTools.StatsSQL:possiblePlansStats) | L | MCP iris_sql_analyze:explain; co-pilot read. |
| EX-51 | Generate SQL troubleshooting report for WRC | action | custom(%SQL.Manager.QButtons.Base) | M | co-pilot read. |
| EX-52 | Import SQL troubleshooting report | action | custom | M | co-pilot write-confirm. |
| EX-53 | Data import / export wizards, data migration, link table / link procedure | wizard | custom(background SQLImport / SQLExport / DataMigration / LinkTable) | L | Legacy CSP wizards never exported (Gaps). |
| EX-54 | Print catalog / print query results | action | none (browser print) | S | Browser print; no server call. |

**11. Interoperability (IO)** — 69 rows (S 40 / M 25 / L 4)

| ID | Name | Kind | Backing (API or class) | Size | Note |
|---|---|---|---|---|---|
| IO-30 | Production documentation generation | action | custom(Ens.Util.Documentation) | M | co-pilot write-confirm. |
| IO-31 | Delete production | action | custom(Ens.Director / Ens.Config.Production) | S | v7 exposes no delete on /productions/{class}; the other lifecycle actions are Stage 3. |
| IO-32 | Credentials | list+CRUD | custom(Ens.Config.Credentials; not in v7 spec) | M | Not in the v7 spec. |
| IO-33 | System default settings | settings | custom(Ens.Config.DefaultSettings) | M | MCP iris_default_settings_manage; co-pilot write-confirm. |
| IO-34 | Purge data settings | settings | custom(settings globals) | S | co-pilot write-confirm. |
| IO-35 | Purge management data | action | custom(Ens.Purge) | M | co-pilot write-confirm. |
| IO-36 | Auto-start production | action | custom(Ens.Director.SetAutoStart) | S | MCP iris_production_autostart; co-pilot write-confirm. |
| IO-37 | Managed alerts viewer | viewer | custom(Ens.Alerting.ManagedAlert) | M | co-pilot write-confirm. |
| IO-38 | Alerts summary | viewer | custom(Ens_Alerting.ManagedAlert SQL) | S | co-pilot read. |
| IO-39 | Business rule log | viewer | custom(Ens_Rule.Log SQL) | M | harvest session-agent; co-pilot read. |
| IO-40 | Business process log | viewer | custom(Ens.BusinessProcess SQL) | M | harvest session-agent; co-pilot read. |
| IO-41 | Suspended messages | list+CRUD | custom(Ens.MessageHeader, Ens.Util.Purge.SuspendTransaction) | M | MCP iris_message_resend; co-pilot write-confirm. |
| IO-42 | Export messages | action | custom | M | co-pilot write-confirm. |
| IO-43 | Schedule specs editor | editor | custom(Ens.Util.Schedule) | M | co-pilot write-confirm. |
| IO-44 | PEX components | list+CRUD | custom(EnsLib.PEX.Utils) | M | co-pilot write-confirm. |
| IO-45 | Public-service registry | list | custom(Ens.ServiceRegistry.Public.API) | M | Hidden class; action set estimated (Gaps). |
| IO-46 | External-service registry | list | custom(Ens.ServiceRegistry.External.*) | M | Hidden class; action set estimated (Gaps). |
| IO-47 | Record maps designer | editor | custom(EnsLib.RecordMap.*) | L | co-pilot write-confirm. |
| IO-48 | CSV record wizard | wizard | custom(EnsLib.RecordMap.Generator) | M | co-pilot write-confirm. |
| IO-49 | Complex record maps designer | editor | custom(EnsLib.RecordMap.Model.ComplexBatch) | L | co-pilot write-confirm. |
| IO-50 | Record maps list | list+CRUD | custom(query EnsPortal.RecordMaps:Enumerate) | M | co-pilot read. |
| IO-51 | Interface maps | viewer | custom(Ens.InterfaceMaps.*) | M | Hidden class; action set estimated (Gaps). |
| IO-52 | Interface references | viewer | custom | M | Hidden class; action set estimated (Gaps). |
| IO-53 | Port authority report | viewer | custom(Ens.Setting.Report.Port; DocDB) | M | co-pilot write-confirm. |
| IO-54 | Interoperability system monitor | viewer | custom(not read) | M | Backing not read (Gaps). |
| IO-55 | Local archive manager | settings | custom(Ens.Archive.Manager) | M | co-pilot write-confirm. |
| IO-56 | Workflow roles | list+CRUD | custom(EnsLib.Workflow.RoleDefinition / Engine) | M | co-pilot write-confirm. |
| IO-57 | Workflow users | list | custom(EnsLib.Workflow.UserDefinition) | M | co-pilot write-confirm. |
| IO-58 | Workflow tasks | list+actions | custom(EnsLib.Workflow.Engine:Tasklist) | M | co-pilot write-confirm. |
| IO-59 | Workflow worklist | viewer | custom(query EnsPortal.WFWorklist:Enumerate) | S | co-pilot read. |
| IO-60 | Deployment: deploy production changes | action | custom(Ens.Deployment.Deploy / Utils) | L | execute-mcp env-promote four-gate model; produces log and rollback files. |
| IO-61 | Deployment history | viewer | custom(Ens_Deployment.Invocations) | M | Rollback of a deployment. |
| IO-62 | Production shutdown groups | list | custom(%Library.EnsembleMgr) | S | co-pilot write-confirm. |
| IO-63 | Setting report application configuration | settings | custom | S | co-pilot write-confirm. |
| IO-64 | Interoperability settings | settings | custom(Ens.Util.Production) | S | co-pilot write-confirm. |
| IO-65 | HL7 custom schema authoring | editor | custom(EnsLib.HL7.Schema, SchemaXML, EnsLib.HL7.Util.Generator) | L | co-pilot write-confirm. |
| IO-66 | HL7 v2.x message viewer: load from file / header ID / body ID / text | viewer | custom(Ens.MessageHeader, EnsLib.Testing.Service) | M | One EDIDocumentView class serves five families by NAME=. |
| IO-67 | ASC X12 document viewer | viewer | custom | S | Same page as IO-66 (NAME=X12 Document). |
| IO-68 | ASTM document viewer | viewer | custom | S | Same page as IO-66. |
| IO-69 | UN/EDIFACT document viewer | viewer | custom | S | Same page as IO-66. |
| IO-70 | XML document viewer | viewer | custom | S | Same page as IO-66. |
| IO-91 | tool session_summary | agent tool | custom(SessionAgent.Tool.Inspection.SessionSummary) | S | harvest session-agent; co-pilot read. |
| IO-92 | tool session_timeline | agent tool | custom(Tool.Inspection.SessionTimeline) | S | harvest session-agent; co-pilot read. |
| IO-93 | tool message_headers | agent tool | custom(Tool.Inspection.MessageHeaders) | S | harvest session-agent; co-pilot read. |
| IO-94 | tool event_log | agent tool | custom(Tool.Inspection.EventLog) | S | harvest session-agent; co-pilot read. |
| IO-95 | tool rule_log | agent tool | custom(Tool.Inspection.RuleLog) | S | harvest session-agent; co-pilot read. |
| IO-96 | tool explain_error | agent tool | custom(Tool.Inspection.ExplainError) | S | harvest session-agent; co-pilot read. |
| IO-97 | tool get_message_detail | agent tool | custom(Tool.Inspection.GetMessageDetail) | S | harvest session-agent; co-pilot read. |
| IO-98 | tool get_message_body | agent tool | custom(Tool.Inspection.GetMessageBody) | S | harvest session-agent; co-pilot read. |
| IO-99 | tool get_business_process_instance | agent tool | custom(Tool.Inspection.GetBusinessProcessInstance) | S | harvest session-agent; co-pilot read. |
| IO-100 | tool get_business_process_source | agent tool | custom(Tool.Inspection.GetBusinessProcessSource) | S | harvest session-agent; co-pilot read. |
| IO-101 | tool list_business_process_methods | agent tool | custom(Tool.Inspection.ListBusinessProcessMethods) | S | harvest session-agent; co-pilot read. |
| IO-102 | tool find_related_sessions | agent tool | custom(Tool.Inspection.FindRelatedSessions) | S | harvest session-agent; co-pilot read. |
| IO-103 | tool find_sessions_by_body | agent tool | custom(Tool.Inspection.FindSessionsByBody) | S | harvest session-agent; co-pilot read. |
| IO-104 | tool get_rule_source | agent tool | custom(Tool.Inspection.GetRuleSource) | S | harvest session-agent; co-pilot read. |
| IO-105 | tool get_class_source | agent tool | custom(Tool.Inspection.GetClassSource) | S | harvest session-agent; co-pilot read. |
| IO-106 | tool get_queue_state | agent tool | custom(Tool.Inspection.GetQueueState) | S | harvest session-agent; co-pilot read. |
| IO-107 | tool get_production_config_item | agent tool | custom(Tool.Inspection.GetProductionConfigItem) | S | harvest session-agent; co-pilot read. |
| IO-108 | tool search_by_session | agent tool | custom(Tool.Search.SearchBySession) | S | harvest session-agent; co-pilot read. |
| IO-109 | tool search_by_status | agent tool | custom(Tool.Search.SearchByStatus) | S | harvest session-agent; co-pilot read. |
| IO-110 | tool search_by_time | agent tool | custom(Tool.Search.SearchByTime) | S | harvest session-agent; co-pilot read. |
| IO-111 | tool search_by_source | agent tool | custom(Tool.Search.SearchBySource) | S | harvest session-agent; co-pilot read. |
| IO-112 | tool search_by_target | agent tool | custom(Tool.Search.SearchByTarget) | S | harvest session-agent; co-pilot read. |
| IO-113 | tool search_by_message_class | agent tool | custom(Tool.Search.SearchByMessageClass) | S | harvest session-agent; co-pilot read. |
| IO-114 | tool search_by_super_session | agent tool | custom(Tool.Search.SearchBySuperSession) | S | harvest session-agent; co-pilot read. |
| IO-115 | tool search_by_body_field | agent tool | custom(Tool.Search.SearchByBodyField) | S | harvest session-agent; co-pilot read. |
| IO-116 | tool inspect_body_candidates | agent tool | custom(Tool.Search.InspectBodyCandidates) | S | harvest session-agent; co-pilot read. |
| IO-117 | tool vocab_lookup | agent tool | custom(Tool.Search.VocabLookup) | S | Save mode writes UserVocabulary; mutation scope is an open question. |
| IO-118 | tool find_sessions_using_class | agent tool | custom(Tool.Search.FindSessionsUsingClass) | S | harvest session-agent; co-pilot read. |

**12. Analytics (AN)** — 7 rows (S 0 / M 5 / L 2)

| ID | Name | Kind | Backing (API or class) | Size | Note |
|---|---|---|---|---|---|
| AN-11 | Term list editor | editor | custom(%DeepSee.TermList API) | M | co-pilot write-confirm. |
| AN-12 | Listing group manager | editor | custom(%DeepSee.ListingGroup) | M | co-pilot write-confirm. |
| AN-13 | Quality measures editor | editor | deepsee /Info/QualityMeasures (read); custom(%DeepSee.QualityMeasure.Utils) for edit | L | Read via deepsee /Info/QualityMeasures; edit is custom. |
| AN-14 | Folder manager: export / import / delete folder items | action | custom(%DeepSee.UserLibrary.Utils %Export / %Import / %DeleteFolderItem) | M | co-pilot write-confirm. |
| AN-15 | Analytics settings | settings | custom(%DeepSee.UserPortal.Utils settings API) | M | co-pilot write-confirm. |
| AN-16 | PMML model tester | console | custom(not read) | M | Backing not read. |
| AN-17 | Dashboard / pivot viewer inside OcuPilot | viewer | deepsee /Data/GetDashboard/:name, /Data/GetPivot/:name, /Data/PivotExecute | L | Official deepsee routes; P3 only because it is a new L-size viewer. |

**13. Developer tools and sibling-tool equivalents not covered above (DT)** — 10 rows (S 3 / M 4 / L 3)

| ID | Name | Kind | Backing (API or class) | Size | Note |
|---|---|---|---|---|---|
| DT-02 | Unit test runner | console | official atelier POST /:ns/work + GET /work/:id (async) | M | Official Atelier async work routes; replaces the excluded UnitTest Portal (EX-57). |
| DT-03 | Async work queue viewer | viewer | official atelier GET/DELETE /:ns/work/:id | S | Official Atelier work routes. |
| DT-04 | Web terminal | console | official atelier GET /%SYS/terminal | L | Atelier v7 WebSocket; community WebTerminal prior art. |
| DT-05 | Execute ObjectScript command console | console | custom(ExecuteMCPv2.REST.Command pattern) | M | 32768-char output ceiling. |
| DT-06 | Execute class method | console | custom(ExecuteMCPv2.REST.Command ClassMethod) | M | MCP iris_execute_classmethod; co-pilot write-confirm. |
| DT-07 | Lines-of-code metrics per namespace / package | viewer | custom(ExecuteMCPv2.Loc.*) | S | MCP iris_loc_count; co-pilot read. |
| DT-08 | Document hashes for drift detection | viewer | custom(ExecuteMCPv2.REST.EnvSync DocHashes) | S | MCP iris_env_diff; co-pilot read. |
| DT-09 | Environment diff | viewer | custom(EnvSync + admin endpoints on both profiles) | L | Depends on DT-11 (second profile). |
| DT-10 | Environment promote | console | custom(write endpoints + atelier PUT /doc + compile) | L | Four gates: plan, execute-with-confirm, steps allowlist, plan-hash freshness; depends on DT-11. |
| DT-11 | Remote instance profiles | settings | none (OcuPilot is single-instance; profile stored server-side) | M | Single-instance product; kept at P3 because DT-09/DT-10 depend on it. |

**Agent co-pilot capabilities in this stage.**

- CP-40 undo / rollback of an agent-applied change (L, custom, write-confirm) — the "undo" step; snapshot before write, one-click revert. Not evidenced in any harvested source.
- CP-34 streaming responses over SSE (L, custom) — the "streaming" step; a new provider-side path (session-agent has none) and the Web Gateway timeout prerequisite (PK-08).
- IO-91..IO-118: the 28 iris-session-agent inspection and search tools (all S, custom, read): session summary/timeline, message headers/detail/body, event and rule logs, explain error, BP instance/source/methods, related sessions, queue state, config item, and the search_by_* family with body-field and body-candidate search and vocab lookup. Candidate to pull forward into Stage 3: the harvested code exists and these are pure reads over Ens tables; the only gate is registering them through CP-11.
- Read tools for every new custom endpoint and confirmed writes for the destructive ones (backup run, mirror actions, global kill, purge, deployment) with governance defaults off.

**API readiness that gates the stage.**

- **OcuPilot REST router (PK-12)** with per-area handler classes is the substrate; handlers are harvested from the MCP suite's `ExecuteMCPv2.REST.*` classes where the MCP-tool column is filled (the catalog maps 88 tools to SMP rows and 17 to new rows), and from iris-session-agent for the 28 tools. Names to avoid: `SessionAgent.*`, `ExecuteMCPv2`, `IRISCouch` (PK-07).
- **Legacy CSP pages were never exported** (Backup ×6, Task Manager Email, Web Gateway Management, SQL Gateway Connections, Security Advisor, Journals, Global View/Edit, Find/Replace, SQL wizards): actions are inferred from rendered HTML; pull the source from the container before writing those screens (addendum, Secondary risks).
- **Backing not inventoried or not captured:** SA-40, SA-41, TM-18, WA-16, SA-30 (ObjectSettings), IO-54, AN-16; SO-13 purge method unresolved.
- **Hidden EnsPortal classes** (IO-45, IO-46, IO-51, IO-52) have estimated action sets.
- **DT-11 remote profiles** must exist before DT-09/DT-10; DT-04 needs the Atelier v7 WebSocket proxied through the Web Gateway.
- **CP-40 undo** needs a snapshot model per entity type with no harvest to lean on; **CP-34 streaming** needs the provider path and the ≥300 s gateway timeout (PK-08).

**Counts per size.**

| Section | S | M | L | Total |
|---|---|---|---|---|
| SH | 0 | 3 | 0 | 3 |
| CP | 0 | 0 | 2 | 2 |
| WA | 0 | 2 | 0 | 2 |
| PM | 1 | 1 | 0 | 2 |
| SS | 2 | 2 | 0 | 4 |
| TM | 1 | 2 | 0 | 3 |
| OS | 2 | 3 | 1 | 6 |
| LG | 1 | 0 | 0 | 1 |
| SA | 1 | 19 | 7 | 27 |
| SO | 5 | 2 | 2 | 9 |
| EX | 4 | 11 | 5 | 20 |
| IO | 40 | 25 | 4 | 69 |
| AN | 0 | 5 | 2 | 7 |
| DT | 3 | 4 | 3 | 10 |
| **Stage 4** | **60** | **79** | **26** | **165** |

### Stage 5 — The long tail, as demand shows (P4)

**56 rows** · S 11 / M 29 / L 16 · custom endpoints 32

**What the user can do at the end.** Nothing is scheduled; each row is picked up only when demand shows and its gate (license, edition, deprecation status, platform) clears. The groups are: license-gated sharding; edition-gated HealthShare, Message Bank, Enterprise and ITK pages; deprecated shadowing and iKnow Text Analytics; Zen Reports, InterSystems Reports and cluster settings; low-usage device sub-pages and Windows-only pages; non-HL7 EDI schema authoring, DICOM, PubSub and adapter-specific dialogs; full applications linked instead of rebuilt (Architect, Analyzer, User Portal); and dead references, dead placeholders and cosmetic items.

**Rows in this stage, grouped by the catalog's exclusion reason** (section in the ID prefix).

**License-gated (sharding)** — 3 rows

| ID | Name | Kind | Backing (API or class) | Size | Note |
|---|---|---|---|---|---|
| SA-50 | Enable sharding | action | admin-v2 PUT /security/service | S | Excluded: license-gated ($$Sharding^%SYS.LICENSE=0 on Community). |
| SA-51 | Configure node-level sharding | action | custom(%SQL.Manager.Catalog ListShards) | L | Excluded: license-gated. |
| SA-52 | Configure namespace-level sharding | action | custom | L | Excluded: license-gated. |

**Edition-gated (HealthShare, Message Bank, Enterprise, ITK)** — 11 rows

| ID | Name | Kind | Backing (API or class) | Size | Note |
|---|---|---|---|---|---|
| SS-40 | HealthShare isc-security Angular module embed or MFE | embed | embed | M | Excluded: HealthShare-only, not on any SMP menu. |
| IO-71 | Agents page | list | custom(EnsLib.Agent.Interface) | M | Excluded: Hub/IMT extension only. |
| IO-74 | Generate DTL | action | custom | L | Excluded: HealthShare-only. |
| IO-75 | Enterprise systems list | list | custom | M | Excluded: Enterprise systems. |
| IO-76 | Message Bank link | link | custom | S | Excluded: Message-Bank-only feature. |
| IO-77 | Enterprise Message Bank | link | custom | S | Excluded: Message-Bank-only. |
| IO-78 | Banked messages | viewer | custom | L | Excluded: Message-Bank-only. |
| IO-79 | Banked events | viewer | custom | M | Excluded: Message-Bank-only (with IO-78). |
| IO-80 | Enterprise messages | viewer | custom | L | Excluded: Enterprise systems. |
| IO-81 | Enterprise monitor | viewer | custom | M | Excluded: Enterprise systems (with IO-80). |
| IO-90 | ITK Setup: service definitions, registry viewer, fault codes, fault map | list | none | M | Excluded: ITK, absent from instance. |

**Deprecated (shadowing, iKnow Text Analytics)** — 9 rows

| ID | Name | Kind | Backing (API or class) | Size | Note |
|---|---|---|---|---|---|
| LG-13 | Shadow data-source error log | viewer | none | S | Excluded: shadowing deprecated. |
| SA-59 | Shadow server settings | settings | custom(Config.Shadows, SYS.Shadowing.Shadow) | M | Excluded: deprecated on IRIS. |
| SO-18 | System as shadow server | screen | none | S | Excluded: shadowing deprecated. |
| SO-19 | System as data source | screen | none | S | Excluded: deprecated. |
| AN-18 | Text Analytics: Domain Architect | screen | none | L | Excluded: iKnow deprecated. |
| AN-19 | Text Analytics: Domain Explorer | screen | none | L | Excluded: deprecated. |
| AN-20 | Text Analytics: Indexing Results | screen | none | M | Excluded: deprecated. |
| AN-21 | Text Analytics: Model Builder | screen | none | L | Excluded: deprecated. |
| AN-22 | Text Analytics: Model Tester | screen | none | M | Excluded: deprecated. |

**Reporting servers and cluster (Zen Reports, InterSystems Reports, Cluster)** — 6 rows

| ID | Name | Kind | Backing (API or class) | Size | Note |
|---|---|---|---|---|---|
| SA-53 | Cluster settings | settings | custom(Config.Cluster) | M | Excluded: cluster. |
| SA-54 | InterSystems Reports server definitions | screen | custom(%Report.ServerDefinition) | M | Excluded: reports servers. |
| SA-55 | Zen Reports render servers | list | custom(%ZEN.Report.RenderServer) | L | Excluded: Zen Reports. |
| SA-56 | Zen Reports print servers | list+CRUD | custom(%ZEN.Report.PrintServer) | L | Excluded: Zen Reports (with SA-55). |
| SA-57 | Zen Reports Excel servers | list+CRUD | custom(%ZEN.Report.ExcelServer) | L | Excluded: Zen Reports (with SA-55). |
| SA-58 | Zen Reports settings | settings | custom(%ZEN.Report.reportPage) | M | Excluded: Zen Reports (with SA-55). |

**Low-usage or platform-specific (device sub-pages, Windows-only)** — 5 rows

| ID | Name | Kind | Backing (API or class) | Size | Note |
|---|---|---|---|---|---|
| WA-17 | Client applications | screen | none | M | Excluded: Windows-only menu. |
| OS-31 | IO settings | settings | admin-v2 GET/PUT /device/settings | M | Excluded: low-usage device settings. |
| OS-32 | Device subtypes list / edit | list+CRUD | admin-v2 /device/subtypes, /device/subtype | M | Excluded: low-usage. |
| OS-33 | Magnetic tape devices | screen | none | M | Excluded: low-usage. |
| OS-34 | Telnet settings | settings | none | M | Excluded: low-usage (Windows branch). |

**Non-HL7 EDI authoring, DICOM, PubSub, adapter dialogs, legacy interop** — 10 rows

| ID | Name | Kind | Backing (API or class) | Size | Note |
|---|---|---|---|---|---|
| IO-72 | Legacy rule log | viewer | custom | M | Excluded: legacy, not on menu. |
| IO-73 | SAP JCo configuration dialog and SFTP append test dialog | settings | custom | M | Excluded: adapter-specific dialogs. |
| IO-82 | Publish and Subscribe | screen | custom(EnsLib.PubSub.*) | M | Excluded: PubSub. |
| IO-83 | DICOM settings | settings | custom(EnsLib.DICOM.Util.*) | M | Excluded: DICOM. |
| IO-84 | DICOM abstract syntax list | list | custom | S | Excluded: DICOM. |
| IO-85 | DICOM dictionary | screen | custom | S | Excluded: DICOM. |
| IO-86 | ASC X12 schema import / export / delete | action | custom(EnsLib.EDI.X12.SchemaXML, SEF compiler) | M | Excluded: non-HL7 EDI authoring. |
| IO-87 | ASTM schema import / export / delete | action | custom | M | Excluded: non-HL7 EDI authoring. |
| IO-88 | UN/EDIFACT schema structures | viewer | custom(EnsLib.EDI.SEF.Compiler) | M | Excluded: non-HL7 EDI authoring. |
| IO-89 | XML schema structures | viewer | custom(EnsLib.EDI.XML.SchemaXSD) | M | Excluded: non-HL7 EDI authoring. |

**Full applications linked rather than rebuilt** — 4 rows

| ID | Name | Kind | Backing (API or class) | Size | Note |
|---|---|---|---|---|---|
| AN-23 | Architect / Analyzer / User Portal rebuilt as OcuPilot screens | viewer | deepsee (partial) | L | Excluded: full applications, link instead (AN-04..06). |
| EX-55 | FileMan mapping wizard | wizard | custom(%FileMan.File, background FileMan) | L | Excluded: VA-specific legacy wizard. |
| EX-56 | WebStress tool | screen | none | L | Excluded: WebStress. |
| EX-57 | UnitTest Portal | screen | none (see DT-03 runner) | M | Excluded: UnitTest Portal. |

**Dead references, placeholders, cosmetic, not applicable** — 8 rows

| ID | Name | Kind | Backing (API or class) | Size | Note |
|---|---|---|---|---|---|
| SH-29 | "Did you know?" tips panel | platform | none | S | Excluded: cosmetic, no operator value. |
| SA-60 | Provider pages | screen | custom(Provider.*) | M | Excluded: not on any menu; dead InstallInfo reference. |
| SA-61 | FileMan conversion settings | settings | custom | M | Excluded: commented-out menu item. |
| SA-62 | Dead references | screen | none | S | Excluded: dead references. |
| AN-24 | Worksheet builder, caption editor, Visual Reporting, other %DeepSee.UI pages not on the S… | editor | none | M | Excluded: not on menu / dead code. |
| DT-12 | Debugger session / terminal tools | console | official atelier GET /%SYS/debug | L | Excluded: dead placeholder, no implementation. |
| EX-58 | Data browser: connection status / disconnect | grid | none | S | Excluded: not applicable when served from the same IRIS instance. |
| PK-26 | Optional IRIS AI Hub / Interoperability workflow integration for the confirm step | platform | custom | L | Excluded: EAP dependency, not on Community Edition. |

**Agent co-pilot capabilities in this stage.**

- None. If a P4 row is promoted, it takes the read/write-confirm tool pattern of the stage its API belongs to.

**API readiness that gates the stage.**

- A demand signal, then the specific gate per group: a sharding license (SA-50..52); a HealthShare, Message Bank or Enterprise edition (SS-40, IO-71, IO-74..IO-81); ITK present on the instance (IO-90); Windows (WA-17, OS-34); a decision to support deprecated shadowing or iKnow at all (LG-13, SA-59, SO-18, SO-19, AN-18..22); a debugger implementation (DT-12); the AI Hub EAP (PK-26). The three admin-v2-backed rows here (OS-31, OS-32, SA-50) need no new API and are the cheapest to promote.

**Counts per size.**

| Section | S | M | L | Total |
|---|---|---|---|---|
| SH | 1 | 0 | 0 | 1 |
| WA | 0 | 1 | 0 | 1 |
| SS | 0 | 1 | 0 | 1 |
| OS | 0 | 4 | 0 | 4 |
| LG | 1 | 0 | 0 | 1 |
| SA | 2 | 6 | 5 | 13 |
| SO | 2 | 0 | 0 | 2 |
| EX | 1 | 1 | 2 | 4 |
| IO | 4 | 13 | 3 | 20 |
| AN | 0 | 3 | 4 | 7 |
| DT | 0 | 0 | 1 | 1 |
| PK | 0 | 0 | 1 | 1 |
| **Stage 5** | **11** | **29** | **16** | **56** |

## 3. Rows with no route at all (custom endpoints), per stage

Rows whose API backing names `custom(...)`. Where the catalog shows a route for the read half and custom for the write half, the row is listed with that split. Agent-internal rows (CP-*, IO-91..118) ride on the existing chat endpoint (CP-02) and the tool registry (CP-11); they need server-side code, not a new REST route, and are marked "agent".

### Stage 1 — 5 rows

| ID | Name | Custom part | Backing class | Note |
|---|---|---|---|---|
| CP-39 | Context-window management | agent | custom | Nothing to harvest (session-agent gap); needed as the tool roster doubles with this stage. |
| CP-41 | Proxy / custom CA support for outbound LLM HTTPS | agent | custom(%Net.HttpRequest proxy properties; SSL config selectable) | session-agent hard-codes DefaultSSL; expose %Net.HttpRequest proxy and SSL-config choice. |
| PM-19 | Validate a candidate password against policy | whole row | custom($SYSTEM.Security.ValidatePassword) | Custom wrapper over $SYSTEM.Security.ValidatePassword; SMP validates inline. |
| LG-11 | Live tail of text logs | whole row | custom(%SYSTEM.Event long-poll) | iris-couch ChangesHandler long-poll pattern; enhances the P0/P1 text-log viewers. |
| PK-25 | Multi-namespace install | whole row | custom(OcuPilot.Installer.InstallIntoNamespace) | Validation: not %SYS, exists, interop-enabled where needed, package mapping. |

### Stage 2 — 1 row

| ID | Name | Custom part | Backing class | Note |
|---|---|---|---|---|
| CP-36 | Agent picker | agent | custom(agent registry replacing two literals) | With Explorer as a second domain, a developer agent and an ops agent can differ per area. |

### Stage 3 — 6 rows

| ID | Name | Custom part | Backing class | Note |
|---|---|---|---|---|
| CP-37 | "Investigate" entry points on alerts and log entries launching a multi-step run with reca… | agent | custom | Multi-step run with recap and ranked hypotheses; entry points on alerts and log entries (LG-10). |
| CP-38 | Guided workflows harvested from the 11 MCP prompts | agent | custom | The 11 MCP prompts (check-system-health, audit-security-posture, recover-stuck-production, resend-failed-messages, diagnose-slow-query, run-external-backup, …). |
| IO-11 | Queues | write/action half | interop-v7 per-host /queue; custom(Ens.Queue AbortItem / AbortQueue) for actions | Read via v7; Abort / Abort All / Suspend need custom (Ens.Queue). |
| IO-12 | Jobs | write/action half | interop-v7 per-host /jobs, GET /{ns}/processes; custom(Ens.Job) for actions | Read via v7; Abort / Stop / Suspend need custom (Ens.Job). |
| IO-14 | Business partners view | write/action half | interop-v7 GET /{ns}/business-partners; custom(Ens.Config.BusinessPartner) for save/remove | View via v7; save/remove need custom (Ens.Config.BusinessPartner). |
| IO-28 | Message contents renderer | whole row, or the embed | custom(Ens.Util.MessageBodyMethods) or embed message-viewer | Must be rebuilt for a non-Zen viewer, or use the embed. |

### Stage 4 — 158 rows

| Section | Rows | With an MCP-suite or session-agent handler to harvest | Without any harvest (write from the backing class) |
|---|---|---|---|
| SH | 3 | 0: — | 3: SH-26, SH-27, SH-28 |
| CP | 2 | 0: — | 2: CP-34, CP-40 |
| WA | 2 | 0: — | 2: WA-15, WA-16 |
| PM | 2 | 0: — | 2: PM-23, PM-24 |
| SS | 4 | 2: SS-36, SS-39 | 2: SS-37, SS-38 |
| TM | 3 | 0: — | 3: TM-17, TM-18, TM-19 |
| OS | 6 | 3: OS-26, OS-28, OS-29 | 3: OS-24, OS-25, OS-27 |
| LG | 1 | 1: LG-12 | 0: — |
| SA | 27 | 9: SA-23, SA-24, SA-26, SA-27, SA-35, SA-42, SA-44, SA-45, SA-46 | 18: SA-25, SA-28, SA-29, SA-30, SA-31, SA-32, SA-33, SA-34, SA-36, SA-37, SA-38, SA-39, SA-40, SA-41, SA-43, SA-47, SA-48, SA-49 |
| SO | 9 | 4: SO-09, SO-11, SO-12, SO-16 | 5: SO-10, SO-13, SO-14, SO-15, SO-17 |
| EX | 18 | 9: EX-36, EX-37, EX-38, EX-39, EX-40, EX-44, EX-48, EX-49, EX-50 | 9: EX-41, EX-42, EX-43, EX-45, EX-46, EX-47, EX-51, EX-52, EX-53 |
| IO | 69 | 37: IO-31, IO-32, IO-33, IO-36, IO-39, IO-40, IO-41, IO-54, IO-60, IO-91, IO-92, IO-93, IO-94, IO-95, IO-96, IO-97, IO-98, IO-99, IO-100, IO-101, IO-102, IO-103, IO-104, IO-105, IO-106, IO-107, IO-108, IO-109, IO-110, IO-111, IO-112, IO-113, IO-114, IO-115, IO-116, IO-117, IO-118 | 32: IO-30, IO-34, IO-35, IO-37, IO-38, IO-42, IO-43, IO-44, IO-45, IO-46, IO-47, IO-48, IO-49, IO-50, IO-51, IO-52, IO-53, IO-55, IO-56, IO-57, IO-58, IO-59, IO-61, IO-62, IO-63, IO-64, IO-65, IO-66, IO-67, IO-68, IO-69, IO-70 |
| AN | 6 | 0: — | 6: AN-11, AN-12, AN-13, AN-14, AN-15, AN-16 |
| DT | 6 | 6: DT-05, DT-06, DT-07, DT-08, DT-09, DT-10 | 0: — |

Totals: 158 custom rows, 71 with a handler or tool to harvest, 87 to be written from the backing class alone. The seven Stage 4 rows that are **not** custom (official routes, kept at P3 by size or dependency): EX-35 (atelier page loops), EX-54 (browser print), AN-17 (deepsee), DT-02, DT-03, DT-04 (Atelier work and terminal routes), DT-11 (no server call).

Backing class for each custom row without a harvest (from the catalog's API-backing column):

| ID | Backing class |
|---|---|
| SH-26 | custom(%session.EscalateLogin) |
| SH-27 | custom(%CSP.Portal.Utils.%SetCustomResource) |
| SH-28 | custom(SMTP send) |
| CP-34 | custom(new provider-side path) |
| CP-40 | custom |
| WA-15 | custom(Security.Applications.Export/Import) |
| WA-16 | custom(backing class not inventoried) |
| PM-23 | custom($$GenerateQRCode^%SYS.SECURITY) |
| PM-24 | custom(Security.Resources export/import) |
| SS-37 | custom(%SYS.PhoneProviders) |
| SS-38 | custom(Security.System) |
| TM-17 | custom(file read) |
| TM-18 | custom(backing not inventoried) |
| TM-19 | custom(%SYS.Task DiagnosticReport) |
| OS-24 | custom(%SYSTEM.SQL.CancelQuery) |
| OS-25 | custom(SYS.Process:VariableByPid) |
| OS-27 | custom(SYS.Metrics.SystemMonitorStatus, ^IRIS.Temp.SysMetrics) |
| SA-25 | custom(Config.Miscellaneous) |
| SA-28 | custom(Config.NLS.Locales.Import) |
| SA-29 | custom(Config.SQL) |
| SA-30 | custom(backing resolved dynamically; not captured) |
| SA-31 | custom(Config.SQL) |
| SA-32 | custom(Config.SQL) |
| SA-33 | custom(Config.SqlSysDatatypes) |
| SA-34 | custom(Config.SqlUserDatatypes) |
| SA-36 | custom(%Studio.SourceControl.Interface) |
| SA-37 | custom(Config.LogDaemon, SYS.LogDmn) |
| SA-38 | custom(Config.Archives) |
| SA-39 | custom(%SYS.ML.Configuration) |
| SA-40 | custom(backing not inventoried) |
| SA-41 | custom(Backup.General.AddDatabaseToList / RemoveDatabaseFromList; query DatabaseList) |
| SA-43 | custom(SYS.MirrorConfiguration; background task MirrorAddDatabases) |
| SA-47 | custom(Config.MapMirrors, SYS.Mirror) |
| SA-48 | custom(SYS.Agent, SYS.Mirror) |
| SA-49 | custom(SYS.Mirror, Config.Mirrors) |
| SO-10 | custom(Backup.Task:List) |
| SO-13 | custom(%SYS.Journal.File:Purgeable; purge method unresolved) |
| SO-14 | custom(JOB ComputeJournalProfile, ^IRIS.Temp.JournalProfile) |
| SO-15 | custom(%SYS.Journal.File:MirrorByTimeReverseOrder) |
| SO-17 | custom(SYS.Mirror, SYS.MirrorConfiguration; background tasks MirrorMountDB etc.) |
| EX-41 | custom(background task Export / Import) |
| EX-42 | custom |
| EX-43 | custom(%SQL.Manager.Catalog:QueryHistory) |
| EX-45 | custom(%SYSTEM.SQL.ExportSQLStatement / ExportAllSQLStatements) |
| EX-46 | custom(%SYSTEM.SQL.Stats.Table; background TuneTables) |
| EX-47 | custom(%SYSTEM.SQL PurgeAllCachedQueries; background RebuildIndices) |
| EX-51 | custom(%SQL.Manager.QButtons.Base) |
| EX-52 | custom |
| EX-53 | custom(background SQLImport / SQLExport / DataMigration / LinkTable) |
| IO-30 | custom(Ens.Util.Documentation) |
| IO-34 | custom(settings globals) |
| IO-35 | custom(Ens.Purge) |
| IO-37 | custom(Ens.Alerting.ManagedAlert) |
| IO-38 | custom(Ens_Alerting.ManagedAlert SQL) |
| IO-42 | custom |
| IO-43 | custom(Ens.Util.Schedule) |
| IO-44 | custom(EnsLib.PEX.Utils) |
| IO-45 | custom(Ens.ServiceRegistry.Public.API) |
| IO-46 | custom(Ens.ServiceRegistry.External.*) |
| IO-47 | custom(EnsLib.RecordMap.*) |
| IO-48 | custom(EnsLib.RecordMap.Generator) |
| IO-49 | custom(EnsLib.RecordMap.Model.ComplexBatch) |
| IO-50 | custom(query EnsPortal.RecordMaps:Enumerate) |
| IO-51 | custom(Ens.InterfaceMaps.*) |
| IO-52 | custom |
| IO-53 | custom(Ens.Setting.Report.Port; DocDB) |
| IO-55 | custom(Ens.Archive.Manager) |
| IO-56 | custom(EnsLib.Workflow.RoleDefinition / Engine) |
| IO-57 | custom(EnsLib.Workflow.UserDefinition) |
| IO-58 | custom(EnsLib.Workflow.Engine:Tasklist) |
| IO-59 | custom(query EnsPortal.WFWorklist:Enumerate) |
| IO-61 | custom(Ens_Deployment.Invocations) |
| IO-62 | custom(%Library.EnsembleMgr) |
| IO-63 | custom |
| IO-64 | custom(Ens.Util.Production) |
| IO-65 | custom(EnsLib.HL7.Schema, SchemaXML, EnsLib.HL7.Util.Generator) |
| IO-66 | custom(Ens.MessageHeader, EnsLib.Testing.Service) |
| IO-67 | custom |
| IO-68 | custom |
| IO-69 | custom |
| IO-70 | custom |
| AN-11 | custom(%DeepSee.TermList API) |
| AN-12 | custom(%DeepSee.ListingGroup) |
| AN-13 | deepsee /Info/QualityMeasures (read); custom(%DeepSee.QualityMeasure.Utils) for edit |
| AN-14 | custom(%DeepSee.UserLibrary.Utils %Export / %Import / %DeleteFolderItem) |
| AN-15 | custom(%DeepSee.UserPortal.Utils settings API) |
| AN-16 | custom(not read) |

### Stage 5 — 32 rows

| ID | Name | Custom part | Backing class | Note |
|---|---|---|---|---|
| SA-51 | Configure node-level sharding | whole row | custom(%SQL.Manager.Catalog ListShards) | Excluded: license-gated. |
| SA-52 | Configure namespace-level sharding | whole row | custom | Excluded: license-gated. |
| SA-53 | Cluster settings | whole row | custom(Config.Cluster) | Excluded: cluster. |
| SA-54 | InterSystems Reports server definitions | whole row | custom(%Report.ServerDefinition) | Excluded: reports servers. |
| SA-55 | Zen Reports render servers | whole row | custom(%ZEN.Report.RenderServer) | Excluded: Zen Reports. |
| SA-56 | Zen Reports print servers | whole row | custom(%ZEN.Report.PrintServer) | Excluded: Zen Reports (with SA-55). |
| SA-57 | Zen Reports Excel servers | whole row | custom(%ZEN.Report.ExcelServer) | Excluded: Zen Reports (with SA-55). |
| SA-58 | Zen Reports settings | whole row | custom(%ZEN.Report.reportPage) | Excluded: Zen Reports (with SA-55). |
| SA-59 | Shadow server settings | whole row | custom(Config.Shadows, SYS.Shadowing.Shadow) | Excluded: deprecated on IRIS. |
| SA-60 | Provider pages | whole row | custom(Provider.*) | Excluded: not on any menu; dead InstallInfo reference. |
| SA-61 | FileMan conversion settings | whole row | custom | Excluded: commented-out menu item. |
| EX-55 | FileMan mapping wizard | whole row | custom(%FileMan.File, background FileMan) | Excluded: VA-specific legacy wizard. |
| IO-71 | Agents page | whole row | custom(EnsLib.Agent.Interface) | Excluded: Hub/IMT extension only. |
| IO-72 | Legacy rule log | whole row | custom | Excluded: legacy, not on menu. |
| IO-73 | SAP JCo configuration dialog and SFTP append test dialog | whole row | custom | Excluded: adapter-specific dialogs. |
| IO-74 | Generate DTL | whole row | custom | Excluded: HealthShare-only. |
| IO-75 | Enterprise systems list | whole row | custom | Excluded: Enterprise systems. |
| IO-76 | Message Bank link | whole row | custom | Excluded: Message-Bank-only feature. |
| IO-77 | Enterprise Message Bank | whole row | custom | Excluded: Message-Bank-only. |
| IO-78 | Banked messages | whole row | custom | Excluded: Message-Bank-only. |
| IO-79 | Banked events | whole row | custom | Excluded: Message-Bank-only (with IO-78). |
| IO-80 | Enterprise messages | whole row | custom | Excluded: Enterprise systems. |
| IO-81 | Enterprise monitor | whole row | custom | Excluded: Enterprise systems (with IO-80). |
| IO-82 | Publish and Subscribe | whole row | custom(EnsLib.PubSub.*) | Excluded: PubSub. |
| IO-83 | DICOM settings | whole row | custom(EnsLib.DICOM.Util.*) | Excluded: DICOM. |
| IO-84 | DICOM abstract syntax list | whole row | custom | Excluded: DICOM. |
| IO-85 | DICOM dictionary | whole row | custom | Excluded: DICOM. |
| IO-86 | ASC X12 schema import / export / delete | whole row | custom(EnsLib.EDI.X12.SchemaXML, SEF compiler) | Excluded: non-HL7 EDI authoring. |
| IO-87 | ASTM schema import / export / delete | whole row | custom | Excluded: non-HL7 EDI authoring. |
| IO-88 | UN/EDIFACT schema structures | whole row | custom(EnsLib.EDI.SEF.Compiler) | Excluded: non-HL7 EDI authoring. |
| IO-89 | XML schema structures | whole row | custom(EnsLib.EDI.XML.SchemaXSD) | Excluded: non-HL7 EDI authoring. |
| PK-26 | Optional IRIS AI Hub / Interoperability workflow integration for the confirm step | whole row | custom | Excluded: EAP dependency, not on Community Edition. |

The 18 P4 rows with backing `none` (no server call or nothing found) and the 6 with a route (OS-31, OS-32, SA-50 admin-v2; SS-40 embed; AN-23 deepsee partial; DT-12 atelier) are not counted here.

## 4. Roll-up

| Stage | Rows | S / M / L | Custom endpoints | Hard dependencies |
|---|---|---|---|---|
| 1 — The rest of the hidden `/api/admin` service (P2) | 59 | 20 / 31 / 8 | 5 | admin-v2 write payloads observed; async-result polling (TM-16); SH-24 allow-list; /api/admin support stance |
| 2 — System Explorer over the Atelier API, grid harvested from iris-table-editor (P2) | 36 | 17 / 15 / 4 | 1 | action/query DML guard (EX-15); Atelier v7 for xml routes; ETag on PUT; table-editor harvest; %Service_DocDB |
| 3 — Interoperability over the interop-editors v7 API with the three vendor editors embedded (P2), plus the Analytics rider | 41 | 10 / 25 / 6 | 6 | SH-23 JWT/cookie hand-off to /ui/interop; SH-25 namespace gating; UpdateProduction action vocabulary; DeepSee-enabled namespace for the rider |
| 4 — Custom-REST parity harvested from the MCP suite's handlers (P3) | 165 | 60 / 79 / 26 | 158 | OcuPilot REST router (PK-12); MCP-suite handler harvest; legacy CSP source pulled from the container; DT-11 before DT-09/10 |
| 5 — The long tail, as demand shows (P4) | 56 | 11 / 29 / 16 | 32 | Demand plus the per-group gate (license, edition, platform, deprecation decision) |
| **All five** | **357** | **118 / 179 / 60** | **202** | — |

Custom-endpoint counts include agent-internal rows (Stage 1: CP-39, CP-41; Stage 2: CP-36; Stage 3: CP-37, CP-38; Stage 4: CP-34, CP-40 and IO-91..IO-118). Excluding those, the counts of new REST endpoints are Stage 1: 3, Stage 2: 0, Stage 3: 4 (all partial: the action or write half of IO-11, IO-12, IO-14, IO-28), Stage 4: 128, Stage 5: 32.

## 5. Cross-cutting items in the catalog (undo, streaming, multistep, theming, dark mode, mobile, accessibility, localization, performance)

Everything the catalog says on these topics, with the stage it lands in. Items already in the first release (P0/P1) are listed where they constrain a later stage.

**Undo / rollback**
- CP-40 undo / rollback of an agent-applied change — snapshot before write, one-click revert (P3, L) → Stage 4. "Not evidenced" in any harvested source; iris-copilot's rollback by version snapshot is the nearest idea.
- EX-27 data-browser edit-mode undo — Ctrl/Cmd+Z restores the original value while editing (P2, S, harvested from table-editor grid.js) → Stage 2. This is editor-local undo, not a server rollback.
- EX-26 cell save with optimistic UI and rollback on failure (P2, M) → Stage 2.
- IO-60 deployment of production changes produces log and rollback files; IO-61 deployment history offers rollback and delete (P3) → Stage 4.
- DT-10 environment promote uses a four-gate model (plan, execute-with-confirm, steps allowlist, plan-hash freshness) but no rollback (P3) → Stage 4.

**Streaming and live data**
- CP-34 streaming responses, SSE token stream (P2, L; "no streaming exists" in session-agent) → Stage 4 by the addendum's order; its tier would allow earlier. Prerequisite already in P0: PK-08 Web Gateway response timeout ≥ 300 s for agent turns, and CP-19's 90 s provider timeout.
- LG-11 live tail of text logs by long-poll with heartbeat (P2, M; iris-couch ChangesHandler pattern; custom %SYSTEM.Event endpoint) → Stage 1.
- EX-05 compile with streamed output (P2, S) → Stage 2.
- CP-17 progress indication per iteration (P0) is the non-streaming baseline the SSE path replaces.
- SH-09 auto-refresh framework (P0) is what the Stage 1 list pages (journal files, ECP servers, database operations) and TM-11/OS-08-style detail pages reuse; the async operations in Stage 1 need /async-result polling rather than push.

**Multistep workflows**
- CP-38 guided workflows from the 11 MCP prompts: check-system-health, audit-security-posture, recover-stuck-production, resend-failed-messages, diagnose-slow-query, run-external-backup (named at SO-12), and others (P2, M) → Stage 3.
- CP-37 "Investigate" entry points on alerts and log entries: multi-step run with recap and ranked hypotheses (P2, L) → Stage 3; pairs with LG-10 unified log hub (P1) and its "explain" entry points.
- DT-10 environment promote plan/execute (P3, L) and IO-60 deployment (P3, L) are the two server-side multistep flows with explicit gates → Stage 4.
- IO-26 resend and SS-22 purge use the execute-mcp dry-run + confirm double gate; the P0 propose-review-confirm (CP-13) is the single-step precursor of every multistep flow.
- SS-39 Security Advisor (P3) is the screen twin of the audit-security-posture prompt.

**Theming and dark mode**
- SH-22 light/dark theme, "community-requested dark mode", using the table-editor `--ite-*` theme tokens (P1, S) — in the first release; the contest-field digest records dark-mode workarounds as a community pain point.
- EX-32 data-browser theming tokens: dark / light / high-contrast bridge file (`theme.css --ite-* / --ite-theme-*`) (P2, S) → Stage 2. The harvested grid must consume the SH-22 tokens rather than carry its own palette.
- Embedded vendor editors (IO-18, IO-22..IO-25, IO-27; EX-34 Documatic; AN-04..06 links) render in InterSystems' own styling; the catalog has no row for theming them.

**Mobile and narrow viewports**
- The only statement is a judgment call on CP-01: "Narrow-viewport behaviour (a bottom sheet or overlay under about 900 px) is a UX decision, not a catalog row." No P2–P4 row addresses mobile.

**Accessibility**
- EX-31 data-browser accessibility: ARIA roles and live announcements (`grid.js announce`) (P2, S) → Stage 2.
- EX-30 keyboard shortcuts, shortcuts help dialog, go-to-row dialog (P2, S) → Stage 2.
- SH-06 no-privilege tooltips (P0) is the only shell-level accessibility-adjacent item. No other row mentions accessibility; the Stage 2 grid is the only harvested source with an accessibility pattern.

**Localization**
- SH-16 About page with a session language selector (P1, S) — first release.
- SA-26 NLS configured defaults (P3, S, read), SA-27 locale definitions editor (P3, L), SA-28 import locales or tables (P3, M) → Stage 4. These configure the server's locales and collation tables, not the OcuPilot UI language.
- No row covers translating OcuPilot's own UI strings; the Zen `PAGENAME` / `$$$Text` localisation trap is a project rule, not a catalog item.

**Performance**
- SH-09 auto-refresh with persisted sort/filter/page size/max rows (P0) and SH-21 UI state persistence (P1) are the list-page baseline every later stage reuses.
- EX-20 paged grid using TOP / %VID offset paging plus COUNT(*) (P2, M) and EX-14 max rows, run-in-background and show-plan on the query console (P2, L) → Stage 2. EX-02 max-rows filter on the classes list.
- CP-39 context-window management: history trimming / summarisation, token budgeting (P2, M) → Stage 1; CP-28 token metering (P1) is the measurement side.
- OS-23 SQL activity (P2) → Stage 2; OS-24 cancel running query (P3) → Stage 4.
- OS-30 Prometheus metrics table, SO-07 dashboard drill-down statistics, SO-08 interoperability usage (P2) → Stage 1.
- EX-46 tune table, EX-47 purge cached queries / rebuild indices, EX-48 SQL runtime statistics, EX-49 index analyzer and advice (harvest: execute-mcp SqlAdvisor.cls), EX-50 alternate show plans, EX-44 statement index with frozen plans (all P3) → Stage 4; together with the diagnose-slow-query prompt (CP-38, Stage 3) they are the performance-tuning track.
- OS-26 memory and startup configuration (P3) → Stage 4; the judgment call keeps memory *monitoring* at P0 and *configuration* at P3.
- DT-05 execute-command output capture has a 32768-character ceiling (P3) → Stage 4.
- Interop: IO-35 purge management data, IO-34 purge settings, IO-55 archive manager (P3) → Stage 4; IO-10 production monitor and IO-106 queue-state tool (depth and oldest-message age).
