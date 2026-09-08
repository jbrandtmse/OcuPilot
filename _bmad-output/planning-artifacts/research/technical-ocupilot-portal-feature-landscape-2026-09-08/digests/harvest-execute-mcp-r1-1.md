# Harvest: iris-execute-mcp-v2 — round 1 — 2026-09-08

Sources consulted: 112 files under `/Users/jbrandt/git/iris-execute-mcp-v2/` (full reads: README.md, tool_support.md, CHANGELOG.md top 200 lines, ipm/module.xml, src/ExecuteMCPv2/{Setup,REST/Dispatch,REST/Base}.cls, packages/shared/src/{tool-types,governance,baseline-classifications,health,bootstrap}.ts, governance-baseline.ts head, scripts/lib/tool-catalog.mjs, docs/{tool-annotation-audit,known-bugs-2026-04-20,known-bugs-2026-05-29-mapping-subscript,bugs-2026-08-14,bugs-2026-08-17}.md; grep/partial reads: all 64 `packages/*/src/tools/*.ts`, the 16 non-test `src/ExecuteMCPv2/**/*.cls`, scripts/gen-bootstrap.mjs, packages/shared/src/bootstrap-classes.ts, packages/shared/src/server-base.ts, packages/iris-dev-mcp/README.md §Known Limitations, docs/epic-summary.md, docs/migration-v1-v2.md, all package.json files). Publisher: project author (jbrandtmse). Pub date: last commit `9cfa7af` 2026-08-19 (`git log -1`); working-tree files dated 2026-08-31; npm packages `@iris-mcp/*` at 0.0.2, IPM module 0.1.0, embedded `BOOTSTRAP_VERSION` `e1168c1ebe56`. Accessed: 2026-09-08.

Conventions in this digest: **R** = read, **W** = write (governance `mutates`/baseline classification), **W-dd** = write that is *default-disabled* under governance (non-baseline write), **W-de** = write that is default-enabled via `defaultEnabled`. "Custom" = the `ExecuteMCPv2` REST app at `/api/executemcp/v2`. Evidence paths are absolute under `/Users/jbrandt/git/iris-execute-mcp-v2/` unless stated; `T=packages/<pkg>/src/tools/`, `C=src/ExecuteMCPv2/REST/`.

---

## Tool catalog

Confirmed count: **104 package tools + 1 framework tool (`iris_server_profiles`) = 105 distinct tool names** (109 advertised, since the framework tool is registered on each of the 5 servers). Confirmed against `name: "iris_…"` registrations in `packages/*/src/tools/*.ts` (28 + 26 + 22 + 21 + 7) and `scripts/lib/tool-catalog.mjs` (`loadAllToolNames` adds `iris_server_profiles`). Backend split per code + `tool_support.md`: **19 Atelier-only, 80 custom REST (incl. 2 that also use Atelier), 5 other IRIS APIs (4 DocDB + 1 Management API which also uses custom REST for `legacy` scope)**.

### `@iris-mcp/dev` (28) — `T=packages/iris-dev-mcp/src/tools/`

| server | tool | purpose | R/W | backend | key params | evidence |
|---|---|---|---|---|---|---|
| dev | `iris_server_info` | Instance version/features (`GET /api/atelier/`) | R | Atelier | `server` | `T/server.ts` |
| dev | `iris_server_namespace` | Namespace details (databases, features) | R | Atelier | `namespace` | `T/server.ts` |
| dev | `iris_doc_get` | Fetch a document (UDL or XML) | R | Atelier `GET/HEAD /doc/{name}` | `name`, `format` (udl\|xml) | `T/doc.ts` |
| dev | `iris_doc_put` | Create/update a document | W | Atelier `PUT /doc/{name}` | `name`, `content` | `T/doc.ts` |
| dev | `iris_doc_delete` | Delete a document | W (destructive) | Atelier `DELETE /doc/{name}` | `name` | `T/doc.ts` |
| dev | `iris_doc_list` | List documents by category | R | Atelier `docnames` + `modified` | `category` (CLS\|RTN\|CSP\|OTH\|*), `filter`, `cursor` | `T/doc.ts` |
| dev | `iris_doc_load` | Upload local files by glob, optional compile; refuses when path-derived name disagrees with `Class`/`ROUTINE` header | W | Atelier PUT + `action/compile` | `path` (glob), `baseDir`, `compile`, `flags`, `namespace` | `T/load.ts`; `tool_support.md` §Epic 35 |
| dev | `iris_doc_compile` | Compile documents | W | Atelier `action/compile` | `names`, `flags` | `T/compile.ts` |
| dev | `iris_doc_index` | Class structure (methods/props/params) | R | Atelier `action/index` | `names` | `T/intelligence.ts` |
| dev | `iris_doc_search` | Text search across docs | R | Atelier `action/search` | `query`, `files` (default `*.cls,*.mac,*.int,*.inc`) | `T/intelligence.ts` |
| dev | `iris_macro_info` | Macro definition + location | R | Atelier `getmacrodefinition/location` | `macro` | `T/intelligence.ts` |
| dev | `iris_doc_convert` | UDL <-> XML view | R | Atelier `GET /doc?format=` | `name`, `targetFormat` | `T/format.ts` |
| dev | `iris_doc_xml_export` | XML export / import / list | export R, import W, list R | Atelier `action/xml/{export\|load\|list}` (`?flags=` when compiling) | `action`, `compile`, `flags` | `T/format.ts` |
| dev | `iris_sql_execute` | Run arbitrary SQL | W (DML/DDL possible; `readOnlyHint:false`) | Atelier `action/query` | `sql`, `params`, `maxRows` (+ env `IRIS_SQL_MAX_ROWS`, `IRIS_SQL_TIMEOUT`) | `T/sql.ts`; `baseline-classifications.ts` |
| dev | `iris_execute_tests` | Run `%UnitTest` via async work queue | W (code exec; `readOnlyHint:true` is contradicted by governance class) | Atelier `POST /work` + `GET /work/{id}` | `target`, `level` (package\|class\|method) | `T/execute.ts`; `baseline-classifications.ts` |
| dev | `iris_execute_command` | Execute arbitrary ObjectScript with output capture (32768-char cap) | W | Custom `POST /command` | `command`, `namespace` | `T/execute.ts`; `C/Command.cls` |
| dev | `iris_execute_classmethod` | Call a class method; ByRef/Output markers; ≤20 args; shared 32768 budget | W | Custom `POST /classmethod` | `className`, `methodName`, `args` (`{byRef:true,value?}`) | `T/execute.ts`; `C/Command.cls`; `src/ExecuteMCPv2/Utils.cls` |
| dev | `iris_global_get` | Read global node | R | Custom `GET /global` | `global`, `subscripts` | `T/global.ts`; `C/Global.cls` |
| dev | `iris_global_set` | Set global node | W | Custom `/global` (**Dispatch.cls route is `PUT`; tool_support.md says `POST`** — code wins, TS side not read) | `global`, `subscripts`, `value` | `C/Dispatch.cls` L76; `tool_support.md` L47 |
| dev | `iris_global_kill` | Kill global node/tree | W (destructive) | Custom `DELETE /global` | `global`, `subscripts` | `T/global.ts` |
| dev | `iris_global_list` | List globals | R | Custom `GET /global/list` | `filter`, `caseSensitive` | `T/global.ts` |
| dev | `iris_package_list` | Package rollup of class names | R | Atelier `docnames` (client rollup) | `filter` | `T/packages.ts` |
| dev | `iris_doc_export` | Bulk export documents to local dir | W (local-disk write; no IRIS mutation) | Atelier `docnames` + `GET /doc` | `generated` (true\|false\|both), `system` (true\|false\|only), `overwrite` (never\|ifDifferent\|always) | `T/export.ts` |
| dev | `iris_routine_intermediate` | Fetch macro-expanded `.int` | R | Atelier `GET /doc` | `name` | `T/routine.ts` |
| dev | `iris_sql_analyze` | explain / stats / indexUsage / running / advise | R (all 5) | Atelier `action/query` (+ Custom `POST /dev/sql/advise-data` for `advise`) | `action`, `query`, `workload`, `topN`, `filter` | `T/sqlAnalyze.ts`; `C/SqlAdvisor.cls` |
| dev | `iris_loc_count` | Namespace lines-of-code metrics | R | Custom `GET /dev/loc` (`ExecuteMCPv2.Loc.*`) | `spec` (required), `includeGenerated`, `format` (summary\|csv), `topN` | `T/loc.ts`; `C/Loc.cls` |
| dev | `iris_env_diff` | Cross-profile drift detection (documents, mappings, defaultSettings, webapps, config) | R | Custom `POST /dev/doc/hashes`, `GET /config/mapping/{type}`, `GET /interop/defaultsettings`, `GET /security/webapp`, `POST /system/config` on two profiles | `source`, `target`, `domains`, `spec`, `allowWide` | `T/env-diff.ts`; `C/EnvSync.cls` |
| dev | `iris_env_promote` | plan (pure transform) / execute (promotion writes; no deletions) | plan R; execute **W-dd** | Custom write endpoints + Atelier `PUT /doc` + compile | `action`, `plan`, `steps` allowlist, `confirm` | `T/env-promote.ts`; `README.md` §iris_env_promote safety model |

### `@iris-mcp/admin` (26) — all Custom REST, scope `SYS` (handler switches to `%SYS`)

| server | tool | purpose | R/W | backend | key params | evidence |
|---|---|---|---|---|---|---|
| admin | `iris_namespace_manage` | create / modify / delete namespace | W | Custom `POST /config/namespace` | `action`, `name`, `globalsDatabase`, `routinesDatabase` | `T/namespace.ts`; `C/Config.cls` |
| admin | `iris_namespace_list` | List namespaces | R | Custom `GET /config/namespace` | `cursor` | `T/namespace.ts` |
| admin | `iris_database_manage` | create / modify / delete database (creates directory + `SYS.Database.CreateDatabase`) | W | Custom `POST /config/database` | `action`, `name`, `directory`, size/journal props | `T/database.ts`; `C/Config.cls` |
| admin | `iris_database_list` | List databases with runtime sizes | R | Custom `GET /config/database` | `cursor` | `T/database.ts`; `tool_support.md` L143 |
| admin | `iris_mapping_manage` | create / delete global\|routine\|package mapping (subscript-level via name; `force` guard for `%`-globals) | W | Custom `POST /config/mapping/{type}` | `action`, `type`, `namespace`, `name`, `subscript`, `database`, `collation`, `force` | `T/mapping.ts`; `C/Config.cls` `BuildMappingName`/`IsGuardedBaseMapping` |
| admin | `iris_mapping_list` | List mappings by type | R | Custom `GET /config/mapping/{type}` | `type`, `namespace` | `T/mapping.ts` |
| admin | `iris_user_manage` | create / modify / delete user | W | Custom `POST /security/user` | `action`, `name`, `password`, `roles`, `enabled`, … | `T/user.ts`; `C/Security.cls` |
| admin | `iris_user_get` | List users or get one (backfills via `Security.Users.Get`) | R | Custom `GET /security/user[/{name}]` | `name`, `cursor` | `T/user.ts` |
| admin | `iris_user_roles` | add / remove roles on user | W | Custom `POST /security/user/roles` | `action`, `name`, `roles` | `T/user.ts` |
| admin | `iris_user_password` | change (W) / validate against policy (R) | change W; validate R | Custom `POST /security/user/password` | `action`, `name`, `password` | `T/user.ts`; `baseline-classifications.ts` |
| admin | `iris_role_manage` | create / modify / delete role | W | Custom `POST /security/role` | `action`, `name`, `description`, `resources`, `grantedRoles` | `T/role.ts` |
| admin | `iris_role_list` | List roles (`Security.Roles:ListAll`) | R | Custom `GET /security/role` | `cursor` | `T/role.ts` |
| admin | `iris_resource_manage` | create/modify/delete resource (baseline W); grant/revoke SQL privileges (**W-dd**); listPrivileges (R, capped) | mixed | Custom `POST /security/resource` + `GET/POST /security/sqlprivilege` | `action`, `name`, `publicPermission`; `grantee`, `objectType`, `privileges`, `maxRows`, `cursor` | `T/resource.ts`; `C/Security.cls` |
| admin | `iris_resource_list` | List resources | R | Custom `GET /security/resource` | `cursor` | `T/resource.ts` |
| admin | `iris_permission_check` | Does user/role hold resource:permission (`%All` short-circuit) | R | Custom `POST /security/permission` | `target`, `targetType`, `resource`, `permission` | `T/permission.ts` |
| admin | `iris_webapp_manage` | create / modify / delete web application | W | Custom `POST /security/webapp` | `action`, `name`, `namespace`, `dispatchClass`, `resource`, … | `T/webapp.ts` |
| admin | `iris_webapp_get` | Get one web app (path in POST body) | R | Custom `POST /security/webapp/get` | `name` | `T/webapp.ts` |
| admin | `iris_webapp_list` | List web apps | R (scope BOTH) | Custom `GET /security/webapp` | `namespace`, `cursor` | `T/webapp.ts` |
| admin | `iris_ssl_manage` | create / modify / delete SSL/TLS config | W | Custom `POST /security/ssl` | `action`, `name`, cert/key/CA paths, `tlsMinVersion`/`tlsMaxVersion` | `T/ssl.ts` |
| admin | `iris_ssl_list` | List SSL configs | R | Custom `GET /security/ssl` | `cursor` | `T/ssl.ts` |
| admin | `iris_oauth_manage` | create / delete / discover OAuth2 server or client (`discover` persists metadata → W) | W (all; baseline → enabled) | Custom `POST /security/oauth` | `action`, `entity` (server\|client), `name`, `issuerEndpoint`, `sslConfiguration` | `T/oauth.ts`; `baseline-classifications.ts` L1196–1206 |
| admin | `iris_oauth_list` | List OAuth2 servers/clients | R | Custom `GET /security/oauth` | `entity`, `cursor` | `T/oauth.ts` |
| admin | `iris_service_manage` | list/get (R); enable/disable/set (**W-dd**) | mixed | Custom `/security/service` | `action`, `name`, `settings` | `T/service.ts` |
| admin | `iris_ldap_manage` | list/get/test (R); create/modify/delete (**W-dd**) | mixed | Custom `/security/ldap` | `action`, `name`, `settings` | `T/ldap.ts` |
| admin | `iris_x509_manage` | list/get (R); import/delete (**W-dd**) | mixed | Custom `/security/x509` | `action`, `alias`, `certificate`, `privateKey`, `privateKeyPassword` | `T/x509.ts` |
| admin | `iris_audit_manage` | status/view (R); enable/disable/configureEvent/purge/export (**W-dd**; `purge` requires `confirm`) | mixed | Custom `/security/audit` | `action`, `maxRows`, `confirm` | `T/audit.ts` L298; `C/Security.cls` `AuditManage` |

### `@iris-mcp/interop` (22) — all Custom REST, scope `NS` (`iris_production_summary` is `NONE`)

| server | tool | purpose | R/W | backend | key params | evidence |
|---|---|---|---|---|---|---|
| interop | `iris_production_manage` | create / delete production class | W | Custom `POST /interop/production` | `action`, `name` | `T/production.ts`; `C/Interop.cls` |
| interop | `iris_production_control` | start/stop/restart/update/recover (baseline W); **clean** (`Ens.Director.CleanProduction`, **W-de**; `killAppData` wipe requires `confirm:true`) | W | Custom `POST /interop/production/control` | `action`, `name`, `timeout`, `force`, `killAppData`, `confirm` | `T/production.ts` L176–197; `C/Interop.cls` L141–145, L256–259 |
| interop | `iris_production_status` | Production + item status | R | Custom `GET /interop/production/status` | `namespace` | `T/production.ts` |
| interop | `iris_production_summary` | All-namespace production summary | R | Custom `GET /interop/production/summary` | — | `T/production.ts` |
| interop | `iris_production_item` | get (R); set/enable/disable (baseline W); add/remove (**W-dd**); composite `(production,name)` key; arbitrary `@`-suffixed settings | mixed | Custom `POST /interop/production/item` | `action`, `itemName`, `className`, `production`, `settings` | `T/item.ts`; `tool_support.md` §Epic 35 |
| interop | `iris_production_autostart` | get / set autostart production (`^Ens.AutoStart`, `Ens.Director.SetAutoStart`) | get R; set W | Custom `POST /interop/production/autostart` | `action`, `productionName` | `T/item.ts`; `C/Interop.cls` `AutoStart` |
| interop | `iris_production_logs` | Event log (`Ens_Util.Log`) | R | Custom `GET /interop/production/logs` | `type` (Info\|Warning\|Error\|Trace\|Assert\|Alert), `maxRows`, `since` | `T/monitor.ts` |
| interop | `iris_production_queues` | Queue depths (`Ens.Queue:Enumerate`) | R | Custom `GET /interop/production/queues` | `namespace` | `T/monitor.ts` |
| interop | `iris_production_messages` | Message trace rows by header/session | R | Custom `GET /interop/production/messages` | `headerId`, `sessionId`, `maxRows` | `T/monitor.ts` |
| interop | `iris_production_adapters` | Inbound/outbound adapter classes | R | Custom `GET /interop/production/adapters` | `category` (inbound\|outbound) | `T/monitor.ts` |
| interop | `iris_credential_manage` | create / update / delete `Ens.Config.Credentials` | W | Custom `POST /interop/credential` | `action`, `id`, `username`, `password` | `T/credential.ts` |
| interop | `iris_credential_list` | List credentials (no secrets) | R | Custom `GET /interop/credential` | `cursor` | `T/credential.ts` |
| interop | `iris_lookup_manage` | get (R) / set / delete (W) lookup entries (direct `^Ens.LookupTable`) | mixed | Custom `POST /interop/lookup` | `action`, `tableName`, `key`, `value` | `T/lookup.ts`; `C/Interop.cls` `LookupManage` |
| interop | `iris_lookup_transfer` | export (R) / import (W) lookup table XML | mixed | Custom `POST /interop/lookup/transfer` | `action`, `tableName`, `xml` | `T/lookup.ts` |
| interop | `iris_rule_list` | List business rules | R | Custom `GET /interop/rule` | `prefix`, `filter`, `cursor`, `pageSize` | `T/rule.ts` |
| interop | `iris_rule_get` | Rule definition | R | Custom `GET /interop/rule/get` | `name` | `T/rule.ts` |
| interop | `iris_transform_list` | List DTLs | R | Custom `GET /interop/transform` | `prefix`, `filter`, `cursor`, `pageSize` | `T/transform.ts` |
| interop | `iris_transform_test` | Execute a DTL `Transform()` on input | W (code exec) | Custom `POST /interop/transform/test` | `name`, `input` | `T/transform.ts`; `baseline-classifications.ts` L1264–1273 |
| interop | `iris_interop_rest` | create / delete / get REST app via `%REST.API` (`name` is a package name; delete preserves `.impl`) | create/delete W; get R | Custom `POST /interop/rest` | `action`, `name`, `spec` | `T/rest.ts`; `tool_support.md` §Epic 35 |
| interop | `iris_default_settings_manage` | list/get (R); set/delete (**W-dd**) `Ens.Config.DefaultSettings` | mixed | Custom `/interop/defaultsettings` | `action`, `production`, `item`, `hostClass`, `setting`, `value`, `deployable` | `T/defaultSettings.ts` |
| interop | `iris_message_diagram` | Mermaid sequence diagram from message-trace sessions | R | Custom `GET /interop/production/messages/diagram` (`ExecuteMCPv2.Diagram.*`) | `sessionIds`, `labelMode` (full\|short), `dedup` | `T/diagram.ts`; `C/Interop.cls` `MessageDiagram` |
| interop | `iris_message_resend` | preview (R); resend by header IDs / resendFiltered (**W-dd**; `dryRun` default true + `confirm:true` double gate; hard cap 500) | mixed | Custom `POST /interop/message/resend[/preview]` (`Ens.MessageHeader:ResendDuplicatedMessage`) | `action`, `headerIds`, `item`, `status`, `from`/`to`, `headOfQueue`, `dryRun`, `confirm` | `T/message-resend.ts`; `C/MessageResend.cls` L504–513 |

### `@iris-mcp/ops` (21) — all Custom REST, scope `NONE` (handler switches to `%SYS`)

| server | tool | purpose | R/W | backend | key params | evidence |
|---|---|---|---|---|---|---|
| ops | `iris_metrics_system` | Instance-wide counters (`SYS.Stats.Global/Routine`), process count, DB sizes | R | Custom `GET /monitor/system` | — | `T/metrics.ts`; `C/Monitor.cls` `SystemMetrics` |
| ops | `iris_metrics_alerts` | `$SYSTEM.Monitor.State/Alerts/GetAlerts` | R | Custom `GET /monitor/alerts` | — | `C/Monitor.cls` `SystemAlerts` |
| ops | `iris_metrics_interop` | Per-namespace production/queue/error counts | R | Custom `GET /monitor/interop` | `namespace` | `C/Monitor.cls` `CollectInteropMetrics` |
| ops | `iris_alerts_manage` | reset system alerts | W | Custom `POST /monitor/alerts/manage` | `action` (reset) | `T/alerts.ts` |
| ops | `iris_jobs_list` | Running jobs (`%SYS.ProcessQuery` SQL) | R | Custom `GET /monitor/jobs` | `cursor` | `T/jobs.ts` |
| ops | `iris_locks_list` | Lock table (`%SYS.LockQuery:List`) | R | Custom `GET /monitor/locks` | `cursor` | `T/jobs.ts` |
| ops | `iris_journal_info` | Journal state/dirs/free space (`%SYS.Journal.System`) | R | Custom `GET /monitor/journal` | — | `T/system.ts` |
| ops | `iris_mirror_status` | `$SYSTEM.Mirror` membership/role/status | R | Custom `GET /monitor/mirror` | — | `T/system.ts`; `C/Monitor.cls` `MirrorStatus` |
| ops | `iris_audit_events` | Read IRIS audit log (`%SYS.Audit:List`) | R | Custom `GET /monitor/audit` | `maxRows`, filters | `T/system.ts` |
| ops | `iris_database_check` | Database integrity/size overview (`SYS.Database`) | R | Custom `GET /monitor/database` | — | `T/infrastructure.ts` |
| ops | `iris_license_info` | `$SYSTEM.License` key facts | R | Custom `GET /monitor/license` | — | `T/infrastructure.ts` |
| ops | `iris_ecp_status` | ECP status | R | Custom `GET /monitor/ecp` | — | `T/infrastructure.ts` (API not verified) |
| ops | `iris_task_manage` | create / modify / delete `%SYS.Task` | W | Custom `POST /task/manage` | `action`, `taskId`, `name`, `taskClass`, schedule | `T/task.ts`; `C/Task.cls` |
| ops | `iris_task_list` | List tasks | R | Custom `GET /task/list` | `cursor` | `T/task.ts` |
| ops | `iris_task_run` | `%SYS.Task.RunNow` | W | Custom `POST /task/run` | `taskId` | `T/task.ts` |
| ops | `iris_task_history` | Task history (`taskId` filter was a known no-op, 2026-04-20) | R | Custom `GET /task/history` | `taskId`, `maxRows` | `T/task.ts`; `docs/known-bugs-2026-04-20.md` |
| ops | `iris_config_manage` | get/export (R) / set (W) `Config.config`, `Config.Startup`, locale | mixed | Custom `POST /system/config` | `action`, `section` (config\|startup\|locale), `properties` | `T/config.ts`; `C/SystemConfig.cls` |
| ops | `iris_process_manage` | get (R); terminate/suspend/resume (**W-dd**) | mixed | Custom `GET /monitor/process`, `POST /monitor/process/manage` (`SYS.Process`) | `action`, `pid` | `T/process.ts` |
| ops | `iris_database_action` | mount/dismount/compact/defragment/truncate/expandVolume (**all W-dd**) | W-dd | Custom `POST /monitor/database/action` (`SYS.Database.*`) | `action`, `directory`, size args | `T/database.ts`; `C/Monitor.cls` `DatabaseAction` |
| ops | `iris_backup_manage` | run/freeze/thaw (**W-dd**); listHistory (R) (`Backup.General`, `^SYS("BUHISTORY")`) | mixed | Custom `POST /monitor/backup/manage` | `action`, `backupType` (full\|incremental\|cumulative) | `T/backup.ts`; `C/Monitor.cls` `BackupManage` |
| ops | `iris_health_check` | Composite verdict over 9 areas; thresholds applied client-side | R | Custom `GET/POST /monitor/health` | `areas`, `thresholds` | `T/health.ts`; `C/Health.cls` |

### `@iris-mcp/data` (7)

| server | tool | purpose | R/W | backend | key params | evidence |
|---|---|---|---|---|---|---|
| data | `iris_docdb_manage` | list (R) / create / drop (W) DocDB databases | mixed | DocDB `/api/docdb/v1/{ns}` (needs `%Service_DocDB`, off by default) | `action`, `name` | `T/docdb.ts`; `tool_support.md` L277 |
| data | `iris_docdb_document` | insert/get/update/delete documents | get R; others W | DocDB `/doc/{db}` | `action`, `db`, `id`, `document` | `T/docdb.ts` |
| data | `iris_docdb_find` | Query documents | R | DocDB `/find/{db}` | `db`, `restriction`, `projection` | `T/docdb.ts` |
| data | `iris_docdb_property` | create/drop/index properties | W | DocDB `/prop/{db}/{prop}` | `action`, `db`, `property`, `type` | `T/docdb.ts` |
| data | `iris_analytics_mdx` | Run MDX (`%DeepSee.ResultSet`) | R | Custom `POST /analytics/mdx` | `mdx`, `namespace` | `T/analytics.ts`; `C/Analytics.cls` |
| data | `iris_analytics_cubes` | list (R) / build / sync (W) cubes (`%DeepSee.Utils`) | mixed | Custom `GET/POST /analytics/cubes` | `action`, `cube` | `T/analytics.ts` |
| data | `iris_rest_manage` | list/get (R) / delete (W) REST apps; `scope` spec-first\|legacy\|all | mixed | Mgmnt `/api/mgmnt/v2/{ns}` + Custom `GET /security/webapp` (legacy) | `action`, `name`, `scope`, `fullSpec` | `T/rest.ts`; `tool_support.md` L298–322 |

### Framework (every server)

| server | tool | purpose | R/W | backend | key params | evidence |
|---|---|---|---|---|---|---|
| all | `iris_server_profiles` | Profile roster (no password) + effective governance policy + `toolVisibility` counts; does not connect to IRIS | R | in-memory | `profile`, `allProfiles` | `packages/shared/src/server-base.ts` L496–582; `README.md` L464–473 |

MCP prompts (not tools, 11): `check-system-health`, `run-external-backup`, `diagnose-slow-query`, `objectscript-review`, `deploy-and-test-class`, `promote-environment-change`, `trace-message-flow`, `recover-stuck-production`, `resend-failed-messages`, `provision-project-environment`, `audit-security-posture` (`README.md` L659–675; `packages/*/src/prompts/`). These are workflow candidates for co-pilot "guided" flows.

Placeholder: `iris_debug_session` / `iris_debug_terminal` are PRD-only; `packages/iris-data-mcp/src/tools/debug.ts` is a 14-line no-export placeholder (`tool_support.md` L347).

---

## Custom REST API

### Package / classes (`src/ExecuteMCPv2/`, 29 classes embedded by `scripts/gen-bootstrap.mjs` L15–43)

- `ExecuteMCPv2.Utils` (1163 lines) — namespace switch/restore, validation, `SanitizeError`, UTF-8 request-body decoding, output ceiling, ByRef arg marshalling.
- `ExecuteMCPv2.Setup` — web-app registration, `%ALL` package mapping, `^UnitTestRoot`, version stamp (`Parameter BOOTSTRAPVERSION = "dev"`, hash injected at embed time).
- `ExecuteMCPv2.REST.Dispatch Extends %Atelier.REST` — `UrlMap` only.
- `ExecuteMCPv2.REST.Base Extends %Atelier.REST` — `RenderResponseBody` pre-flight override; every handler extends it.
- Handlers: `REST.Command`, `REST.Global`, `REST.UnitTest`, `REST.Config` (700), `REST.Security` (3494), `REST.Interop` (2728), `REST.MessageResend` (619), `REST.Monitor` (1427), `REST.Health` (532), `REST.Task` (332), `REST.SystemConfig` (291), `REST.Analytics` (364), `REST.Loc`, `REST.EnvSync` (261), `REST.SqlAdvisor` (323).
- Libraries: `ExecuteMCPv2.Diagram.{Event,RenderEvent,Loader,Correlator,Compressor,Writer,Generate}`, `ExecuteMCPv2.Loc.{Classifier,Scanner,Generate}`.
- Tests (not embedded): `ExecuteMCPv2.Tests.*` (44 classes).
- Response envelope: `%Atelier.REST` three-part `{status, console, result}` (`Dispatch.cls` L42–45).

### Web application (`Setup.cls` `Configure`, L263–317)

| property | value |
|---|---|
| Name | `/api/executemcp/v2` (`Parameter WEBAPP`) |
| DispatchClass | `ExecuteMCPv2.REST.Dispatch` |
| NameSpace | the namespace the MCP server was configured with (`IRIS_NAMESPACE`, default `USER`) |
| AutheEnabled | `32` (password) |
| Resource | `%Development` |
| Type | `2`; `CSPZENEnabled=1`; `InbndWebServicesEnabled=0`; `CookiePath=/api/executemcp/v2/` |

Auth model: HTTP Basic Auth from the TypeScript client with session-cookie reuse and CSRF handling (`README.md` L686–692); web app requires `%Development`; `Configure`/`ConfigureMapping` need `%Admin_Manage` (`Setup.cls` L234–235; `bootstrap.ts` L1442–1459). Each handler that needs `%SYS` does an explicit `Set $NAMESPACE="%SYS"` save/restore (never `New $NAMESPACE` — `Security.cls` L13, `Config.cls` L8).

### Endpoint table (`src/ExecuteMCPv2/REST/Dispatch.cls` `UrlMap`, L64–221)

| method | route | handler | purpose |
|---|---|---|---|
| POST | `/command` | `Command:Execute` | run ObjectScript |
| POST | `/classmethod` | `Command:ClassMethod` | call class method |
| POST | `/tests` | `UnitTest:RunTests` | run unit tests (not used by any tool per tool_support; tool uses Atelier `/work`) |
| GET / PUT / DELETE | `/global` | `Global:GetGlobal/SetGlobal/KillGlobal` | global node ops |
| GET | `/global/list` | `Global:ListGlobals` | list globals |
| GET / POST | `/config/namespace` | `Config:NamespaceList/NamespaceManage` | namespaces |
| GET / POST | `/config/database` | `Config:DatabaseList/DatabaseManage` | databases |
| GET / POST | `/config/mapping/:type` | `Config:MappingList/MappingManage` | global/routine/package mappings |
| GET / POST | `/security/user` | `Security:UserList/UserManage` | users |
| GET | `/security/user/:name` | `Security:UserGet` | one user |
| POST | `/security/user/roles` | `Security:UserRoles` | add/remove roles |
| POST | `/security/user/password` | `Security:UserPassword` | change/validate |
| GET / POST | `/security/role` | `Security:RoleList/RoleManage` | roles |
| GET / POST | `/security/resource` | `Security:ResourceList/ResourceManage` | resources |
| GET / POST | `/security/sqlprivilege` | `Security:SqlPrivilegeList/SqlPrivilegeManage` | SQL object privileges |
| POST | `/security/permission` | `Security:PermissionCheck` | permission check |
| GET / POST | `/security/webapp` | `Security:WebAppList/WebAppManage` | web apps |
| POST | `/security/webapp/get` | `Security:WebAppGetByPost` | get by path in body |
| GET | `/security/webapp/:name` | `Security:WebAppGet` | get by name |
| GET / POST | `/security/ssl` | `Security:SSLList/SSLManage` | SSL configs |
| GET / POST | `/security/oauth` | `Security:OAuthList/OAuthManage` | OAuth2 |
| GET / POST | `/security/service` | `Security:ServiceList/ServiceManage` | services |
| GET / POST | `/security/ldap` | `Security:LdapList/LdapManage` | LDAP configs |
| GET / POST | `/security/x509` | `Security:X509List/X509Manage` | X.509 credentials |
| GET / POST | `/security/audit` | `Security:AuditStatus/AuditManage` | auditing config |
| GET | `/interop/production/status` | `Interop:ProductionStatus` | production status |
| GET | `/interop/production/summary` | `Interop:ProductionSummary` | all namespaces |
| POST | `/interop/production` | `Interop:ProductionManage` | create/delete |
| POST | `/interop/production/control` | `Interop:ProductionControl` | start/stop/…/clean |
| POST | `/interop/production/item` | `Interop:ItemManage` | item CRUD/settings |
| POST | `/interop/production/autostart` | `Interop:AutoStart` | autostart |
| GET / POST | `/interop/defaultsettings` | `Interop:DefaultSettingsList/Manage` | system default settings |
| GET | `/interop/production/logs` | `Interop:EventLog` | event log |
| GET | `/interop/production/queues` | `Interop:QueueStatus` | queues |
| GET | `/interop/production/messages` | `Interop:MessageTrace` | message trace |
| GET | `/interop/production/messages/diagram` | `Interop:MessageDiagram` | Mermaid |
| GET | `/interop/production/adapters` | `Interop:AdapterList` | adapters |
| POST | `/interop/message/resend` | `MessageResend:MessageResend` | resend |
| POST | `/interop/message/resend/preview` | `MessageResend:MessageResendPreview` | preview |
| GET / POST | `/interop/credential` | `Interop:CredentialList/CredentialManage` | credentials |
| POST | `/interop/lookup` | `Interop:LookupManage` | lookup entries |
| POST | `/interop/lookup/transfer` | `Interop:LookupTransfer` | export/import |
| GET | `/interop/rule` , `/interop/rule/get` | `Interop:RuleList/RuleGet` | rules |
| GET / POST | `/interop/transform` , `/interop/transform/test` | `Interop:TransformList/TransformTest` | DTLs |
| POST | `/interop/rest` | `Interop:RestManage` | REST app via `%REST.API` |
| GET | `/monitor/system` `/alerts` `/interop` `/jobs` `/process` `/locks` `/journal` `/mirror` `/audit` `/database` `/license` `/ecp` | `Monitor:*` | monitoring reads |
| POST | `/monitor/alerts/manage` `/monitor/process/manage` `/monitor/database/action` `/monitor/backup/manage` | `Monitor:AlertsManage/ProcessManage/DatabaseAction/BackupManage` | ops writes |
| GET / POST | `/monitor/health` | `Health:HealthCheck` | composite health |
| GET / POST / POST / GET | `/task/list` `/task/manage` `/task/run` `/task/history` | `Task:*` | tasks |
| POST | `/system/config` | `SystemConfig:ConfigManage` | get/set/export config |
| POST / GET / POST | `/analytics/mdx` `/analytics/cubes` | `Analytics:ExecuteMDX/CubeList/CubeAction` | DeepSee |
| GET | `/dev/loc` | `Loc:LocCount` | LOC metrics |
| GET / POST | `/dev/doc/hashes` | `EnvSync:DocHashes` | document hashes for diff |
| POST | `/dev/sql/advise-data` | `SqlAdvisor:AdviseData` | plan/index evidence |

Plus SQL-callable procs on `ExecuteMCPv2.Setup` (all `[ SqlProc ]`): `Configure(ns)`, `ConfigureMapping(ns)`, `IsConfigured()`, `EnsureUnitTestRoot()`, `GetBootstrapVersion()` — these are how the TS bootstrap drives installation through Atelier `action/query` (`bootstrap.ts` L1511, L1576, L1647, L1679, L1703).

### Install mechanics (self-install)

1. **Embedding** — `scripts/gen-bootstrap.mjs` concatenates the 29 classes (ordered: Utils, Setup, Diagram.*, Loc.*, REST.Base, handlers, Dispatch last), computes a 12-hex SHA-256 (`BOOTSTRAP_VERSION`), replaces `Parameter BOOTSTRAPVERSION = "dev"` in the in-memory Setup.cls, and writes `packages/shared/src/bootstrap-classes.ts` (current value `e1168c1ebe56`).
2. **Probe** (every server start, per profile) — `SELECT ExecuteMCPv2.Setup_GetBootstrapVersion()` via Atelier `action/query` in `config.namespace`; quad-state `missing` / `current` / `unconfigured` (version matches but `Setup_IsConfigured()` says web app absent) / `stale` (`bootstrap.ts` L1411–1551).
3. **Deploy** — Atelier `PUT /doc/{name}?ignoreConflict=1` per class, then `POST action/compile` (`bootstrap.ts` L1607–1634).
4. **Privileged steps** — `Setup_Configure(ns)` (web app create/modify in `%SYS`), `Setup_ConfigureMapping(ns)` (creates `%ALL` namespace if absent, maps package `ExecuteMCPv2` to the namespace's routines DB), `Setup_EnsureUnitTestRoot()`; failures are recorded with `MANUAL_INSTRUCTIONS` and self-heal on the next privileged launch (`bootstrap.ts` L1720–1783, L1809–1956).
5. **Namespace selection** — deployment/web-app namespace = the profile's `namespace` (`IRIS_NAMESPACE`, default `USER`); per-call `namespace` argument is honored via `Utils.SwitchNamespace`; the `%ALL` mapping makes the package callable from any namespace.
6. **Fallback** — none functional: if bootstrap fails, 80 of 104 tools error (`tool_support.md` L392–394); `iris_server_profiles` still works.
7. **IPM path** — `ipm/module.xml` (`iris-execute-mcp-v2` v0.1.0) lists only 13 core classes + 5 tests and invokes `Setup.Configure` + `Setup.ConfigureMapping`; it **omits** `REST.Base`, `REST.EnvSync`, `REST.Health`, `REST.Loc`, `REST.MessageResend`, `REST.SqlAdvisor`, all `Diagram.*` and `Loc.*` — stale relative to `gen-bootstrap.mjs`; since every handler now `Extends ExecuteMCPv2.REST.Base`, an IPM install from this manifest would likely not compile (inference from `Base.cls` L507 + module.xml L13–25).
8. **No docker / `iris.script` hooks** exist in the repository (file tree scan; none matched).
9. **Versioning** — class-content hash only; no semantic version on the REST API path beyond the literal `/v2`.
10. **Known gateway caveat** — `Security.Applications.Create()` does not notify the CSP Gateway; new app may 404 until saved in SMP or gateway restart (`README.md` L757–762).

---

## Governance and safety patterns

- **Key model**: `tool` or `tool:action` (`governance.ts` L15–18). Frozen baseline of 141 pre-governance keys (`governance-baseline.ts`, hash `1e62c5ad5bf7`); baseline keys are enabled; new keys need `mutates` (`read` → enabled, `write` → disabled unless `defaultEnabled`) and registration throws on an unclassified key (`assertGovernanceClassification`, `governance.ts` L651–672).
- **Cascade**: `env.profile ?? env.global ?? file.profile ?? file.global ?? presetSeed ?? defaultSeed` (`governance.ts` L828–849). Env: `IRIS_GOVERNANCE` JSON `{"global":{...},"profiles":{"<name>":{...}}}`; file: `IRIS_GOVERNANCE_FILE` (explicit path, read once at startup, fail-fast on missing/invalid, inert when unset — `governance.ts` L411–429); preset: `IRIS_GOVERNANCE_PRESET=read-only|full` blocks every write-classified key including `defaultEnabled` ones (`presetSeed`, L756–779).
- **Enforcement**: call-time gate in `McpServerBase.handleToolCall`/`dispatchToolCall` after profile resolution; denial returns `isError` + `structuredContent {code:"GOVERNANCE_DISABLED", action, server, presetApplied?}` (`README.md` L389–402, L434). All tools stay advertised.
- **Attribution**: `configSource` per key = env|file|preset|default (`governance.ts` L895–938), surfaced by `iris_server_profiles` and resource `iris-governance://{profile}`.
- **Visibility (orthogonal)**: `IRIS_TOOLS_PRESET=full|core|developer`, `IRIS_TOOLS_DISABLE`, `IRIS_TOOLS_ENABLE`; per-tool, registration-time; `iris_server_profiles` cannot be hidden (`README.md` L541–611; `packages/*/src/tools/presets.ts`). Rosters: core = 12/12/9/9/7, developer = 28/10/22/9/7.
- **Default-disabled writes today**: `iris_service_manage:{enable,disable,set}`, `iris_ldap_manage:{create,modify,delete}`, `iris_x509_manage:{import,delete}`, `iris_audit_manage:{enable,disable,configureEvent,purge,export}`, `iris_resource_manage:{grant,revoke}`, `iris_process_manage:{terminate,suspend,resume}`, all six `iris_database_action` actions, `iris_backup_manage:{run,freeze,thaw}`, `iris_default_settings_manage:{set,delete}`, `iris_production_item:{add,remove}`, `iris_message_resend:{resend,resendFiltered}`, `iris_env_promote:execute` (`README.md` L488–505).
- **Write-default-enabled**: only `iris_production_control:clean` (`production.ts` L176–179).
- **Recover-before-clean**: guidance is `recover` first, `clean` last resort, `killAppData` only with accepted data loss; `clean` = `Ens.Director.CleanProduction`, `killAppData` wipes persistent `^Ens.AppData` and is refused unless `confirm:true` (`Interop.cls` L141–145, L256–259; `tool_support.md` L184; prompt `recover-stuck-production`, `README.md` L670).
- **Dry-run + confirm double gate**: `iris_message_resend:resendFiltered` defaults `dryRun=1`; executing needs `dryRun:false` AND `confirm:true`, enforced server-side in ObjectScript (`MessageResend.cls` L504–513) — not only in TypeScript.
- **Four-gate promote**: `iris_env_promote:execute` requires `confirm`, non-empty `steps` allowlist, plan-hash freshness, and the *target* profile's governance to allow each underlying write family; never deletes target-only items; redacts credential-ish default-setting values (`README.md` L519–526).
- **Other confirm gates**: `iris_audit_manage:purge` refuses without `confirm` (`audit.ts` L298); `iris_mapping_manage` refuses to overwrite a `%`-prefixed base global mapping without `force` (`Config.cls` `IsGuardedBaseMapping`).
- **Audit trail**: `IRIS_AUDIT_LOG` JSONL, secrets-redacted, cannot be disabled by governance; entries carry `outcome ok|error|denied`, `denyReason`, `presetApplied`, `profileSource` (`README.md` L629–647).
- **Response caps**: execution output/returnValue/byRefValues share one 32768-raw-char budget with `[IRIS-MCP-TRUNCATED ceiling=N chars]` marker and `truncated`/`returnValueTruncated`/`byRefTruncated` flags (`README.md` L747–755; `Utils.cls` `OUTPUTCEILING`).
- **Annotations**: every tool sets all four MCP hints; `readOnlyHint` and governance class disagree for `iris_execute_tests` (hint true, class write) and `iris_doc_export` (hint false, class write for local disk) (`docs/tool-annotation-audit.md`; `baseline-classifications.ts` L1124–1128, L1156–1159).

---

## Names to avoid

| kind | name |
|---|---|
| ObjectScript package | `ExecuteMCPv2` (and `ExecuteMCPv2.REST`, `ExecuteMCPv2.Diagram`, `ExecuteMCPv2.Loc`, `ExecuteMCPv2.Tests`, transient `ExecuteMCPv2.Temp`) |
| Web application | `/api/executemcp/v2` (cookie path `/api/executemcp/v2/`) |
| Package mapping | `ExecuteMCPv2` → `%ALL` (creates namespace `%ALL` if absent, `Setup.cls` L364–383) |
| Namespace | `%ALL` (created by the suite when missing) |
| SQL procedures | `ExecuteMCPv2.Setup_GetBootstrapVersion`, `_IsConfigured`, `_Configure`, `_ConfigureMapping`, `_EnsureUnitTestRoot` |
| Global | `^UnitTestRoot` (set to manager dir when empty; standard IRIS global, not suite-private). No suite-private globals were found in non-test source; handlers read/write IRIS-owned `^Ens.LookupTable`, `^Ens.AutoStart`, `^Ens.AppData`, `^Ens.Config.ProductionD`, `^SYS("BUHISTORY")` |
| Resource / role | none created by install; relies on existing `%Development` (web app) and `%Admin_Manage` (install). Tools may create user-named resources/roles at runtime |
| IPM module | `iris-execute-mcp-v2` |
| npm | `iris-mcp-suite` (root), `@iris-mcp/{dev,admin,interop,ops,data,all,shared,client-config}` |
| MCP server names | `iris-dev-mcp`, `iris-admin-mcp`, `iris-interop-mcp`, `iris-ops-mcp`, `iris-data-mcp` |
| MCP tool prefix | `iris_*` (105 names above) |
| MCP resource scheme | `iris-governance://{profile}` |
| Env var prefix | `IRIS_*` (`IRIS_HOST`…`IRIS_CREDENTIAL_HELPER`, `IRIS_GOVERNANCE*`, `IRIS_TOOLS_*`, `IRIS_AUDIT_LOG*`, `IRIS_SQL_*`, `IRIS_SERVER_MANAGER`, `IRIS_SM_*`, `IRIS_ACCEPT_LANGUAGE`) |
| OS keychain service | `iris-mcp` |
| State dir | `~/.iris-mcp/client-manager/state.json` |
| CLIs | `iris-mcp-credentials`, `iris-mcp-governance`, `iris-mcp-clients` |
| VS Code extension | `iris-mcp-launcher` (settings `irisMcpLauncher.*`) |
| Prompt / skill names | the 11 kebab-case prompt names listed above |
| Response marker | `[IRIS-MCP-TRUNCATED ceiling=…chars]` |

---

## Reusable backend code

All handlers follow one shape: `ReadRequestBody` → validate → optional `SwitchNamespace` / `Set $NAMESPACE="%SYS"` → system-class call → `RenderResponseBody`. The system-class calls are the harvestable part; the envelope is `%Atelier.REST`-specific.

| capability | class(es) / method(s) | needs %SYS? | notes |
|---|---|---|---|
| Namespaces | `REST.Config:NamespaceList/NamespaceManage` → `Config.Namespaces` Get/Create/Modify/Delete, `Config.Namespaces:List` | yes | 700-line class; also creates DB directories |
| Databases | `REST.Config:DatabaseList/DatabaseManage` → `Config.Databases` Create/Modify/Delete/Get + `SYS.Database.CreateDatabase`, `%OpenId` for runtime size | yes | splits config props vs runtime props (`BuildDatabaseConfigProps/RuntimeProps`) |
| Mappings | `REST.Config:MappingList/MappingManage`, `BuildMappingName`, `IsGuardedBaseMapping` → `$ClassMethod("Config.Map{Globals,Routines,Packages}", …)`, `Config.MapGlobals.IsValidSubscript` | yes | subscript encoded in name; `%`-global guard |
| Users | `REST.Security:UserList/UserGet/UserManage/UserRoles/UserPassword` → `Security.Users` (List query + Get backfill), `$SYSTEM.Security.ValidatePassword` | yes | 3494-line class |
| Roles / resources / SQL privileges | `RoleList/RoleManage` → `Security.Roles:ListAll`; `ResourceList/ResourceManage` → `Security.Resources`; `SqlPrivilegeList/Manage` → `%SQL.Manager.API` | yes | 2026-04-20 doc reports `Create` with description crashed (positional vs ByRef signature); fix status unverified |
| Permission check | `PermissionCheck` → `Security.Users`/`Security.Roles`, `%All` short-circuit | yes | |
| Web apps | `WebAppList/WebAppGet/WebAppGetByPost/WebAppManage`, `BuildWebAppProps` → `Security.Applications` | yes | list is `scope BOTH` |
| SSL/TLS | `SSLList/SSLManage` → `Security.SSLConfigs` | yes | tlsMin/Max mapping |
| OAuth2 | `OAuthList/OAuthManage` → `OAuth2.Client`, `OAuth2.ServerDefinition`, `OAuth2.Server.Configuration`, `%SYS.OAuth2.Registration.Discover(issuer, sslConfig, .server)` | yes | pre-validation added 2026-08-18 |
| Services / LDAP / X.509 / auditing | `ServiceList/Manage` → `Security.Services`; `LdapList/Manage` → `Security.LDAPConfigs`; `X509List/Manage` → `%SYS.X509Credentials`; `AuditStatus/AuditManage` → `Security.System`, `Security.Events`, `%SYS.Audit` | yes | |
| Tasks | `REST.Task:TaskList/TaskManage/TaskRun/TaskHistory` → `%SYS.Task` `%New/%OpenId/%DeleteId/RunNow`, `%SYS.Task.History` queries | yes | `TaskHistoryDetail` ignores taskId (use `TaskHistoryForTask`) per 2026-04-20 doc |
| Jobs / processes / locks | `REST.Monitor:JobsList` (SQL over `%SYS.ProcessQuery`), `ProcessGet/ProcessManage` → `%SYS.ProcessQuery`, `SYS.Process`; `LocksList` → `%SYS.LockQuery:List` | yes | |
| Journal / mirror / license / ECP | `JournalInfo` → `%SYS.Journal.System` getters; `MirrorStatus` → `$SYSTEM.Mirror.*`; `LicenseInfo` → `$SYSTEM.License.*`; `ECPStatus` (API not verified) | yes | |
| Alerts / system metrics | `SystemAlerts` → `$SYSTEM.Monitor.State/Alerts/GetAlerts`; `SystemMetrics` → `SYS.Stats.Global/Routine.Sample()`, `Config.Databases:List` + `SYS.Database` | yes | instance-wide, matches SMP dashboard |
| Database maintenance / backup | `DatabaseCheck`, `DatabaseAction` → `SYS.Database` Mount/Dismount/Compact/Defragment/ReturnUnusedSpace/NewVolume; `BackupManage` → `Backup.General`, `^SYS("BUHISTORY")` | yes | no restore (interactive only) |
| System config | `REST.SystemConfig:GetConfig/SetConfig/ExportConfig` → `Config.config` Open/Modify, `Config.Startup.Get`, `%SYS.NLS.Locale` | yes | |
| Composite health | `REST.Health:HealthCheck*` → journal/db/lock/license/mirror/ECP/alerts/interop raw values; thresholds live in TS `health.ts` | yes | port thresholds if reusing |
| Productions | `REST.Interop:ProductionManage/Control/Status/Summary/ItemManage/AutoStart` → `Ens.Director` (incl. `CleanProduction`, `RecoverProduction`, `SetAutoStart`, `GetProductionStatus`), `Ens.Config.Production/Item/Setting`, `%Dictionary.*` for class validation, `SaveToClass` dual-write | no (per-namespace) | 2728-line class; composite-key handling |
| Event log / queues / messages / adapters | `EventLog` (SQL `Ens_Util.Log`), `QueueStatus` (`Ens.Queue:Enumerate`), `MessageTrace` (SQL `Ens.MessageHeader`), `AdapterList` (SQL over class dictionary) | no | |
| Message diagram | `ExecuteMCPv2.Diagram.Generate.Run(sessionIds, options, .result)` + Loader/Correlator/Compressor/Writer | no | clean-room Mermaid generator, self-contained |
| Message resend | `REST.MessageResend:PreviewOne/ResendOne/ResendBatch` → `Ens.MessageHeader:ResendDuplicatedMessage` | no | dry-run/confirm gate implemented server-side |
| Credentials / lookups / default settings | `CredentialManage/List` → `Ens.Config.Credentials`; `LookupManage` → direct `^Ens.LookupTable`; `LookupTransfer`; `DefaultSettingsList/Manage` → `Ens.Config.DefaultSettings` | no | |
| Rules / transforms / REST apps | `RuleList/RuleGet`, `TransformList/TransformTest` (`$ClassMethod(class,"Transform",…)`), `RestManage` → `%REST.API` | no | |
| Analytics | `REST.Analytics:ExecuteMDX/CubeList/CubeAction` → `%DeepSee.ResultSet.%ExecuteDirect`, `%DeepSee.Utils.%BuildCube/%SynchronizeCube/%GetCubeList/…` under null-device redirect | no | |
| Code execution | `REST.Command:Execute/ClassMethod` + `Utils.InvokeWithArgs`, `ApplyOutputCeiling`, `BuildByRefNode`, `%Library.Device.ReDirectIO` mnemonic labels | no (needs `%ALL` mapping for cross-namespace) | |
| Globals | `REST.Global` + `BuildGlobalRef/ValidateGlobalName` | no | |
| Unit tests | `REST.UnitTest:RunTests/BuildTestSpec/ParseTestResults` (`:`-prefixed spec with `/noload/nodelete/norecursive`) | no | tool itself uses Atelier `/work`, not this route |
| LOC / doc hashes / SQL advisor | `ExecuteMCPv2.Loc.*` (`StudioOpenDialog` + `GetTextAsArray`), `REST.EnvSync:ComputeHashes/HashDoc` (`%Atelier.v1.Utils.TextServices`), `REST.SqlAdvisor:RunExplain/IndexRowsForClass` | no | |
| Shared plumbing | `Utils.SwitchNamespace/RestoreNamespace`, `SanitizeError` (strips localized `ERROR #` prefixes, hides globals), `ReadRequestBody` (UTF-8 chunk-safe), `Validate*` | no | portable to any REST base |
| Install | `Setup.Configure/Uninstall/ConfigureMapping/IsConfigured/EnsureUnitTestRoot/GetBootstrapVersion` | yes | template for OcuPilot's own web-app registration |

---

## Findings

- **Claim:** The suite ships exactly 104 package tools (dev 28, admin 26, interop 22, ops 21, data 7) plus one framework tool `iris_server_profiles`. | **Source:** `/Users/jbrandt/git/iris-execute-mcp-v2/packages/*/src/tools/*.ts` (grep of `name: "iris_…"`), `/Users/jbrandt/git/iris-execute-mcp-v2/scripts/lib/tool-catalog.mjs`, `/Users/jbrandt/git/iris-execute-mcp-v2/tool_support.md` L375–382 | **Publisher:** project author | **Pub date:** 2026-08-19 (commit 9cfa7af) | **Accessed:** 2026-09-08 | **Confidence:** high | **Class:** harvest
- **Claim:** 80 of the 104 tools depend on the custom `ExecuteMCPv2` REST app; admin, interop and ops are 100% custom; only 19 dev tools are Atelier-only; 5 data tools use DocDB/Management API. | **Source:** `tool_support.md` L58, L105, L180, L220, L279, L390–394 cross-checked with `src/ExecuteMCPv2/REST/Dispatch.cls` UrlMap | **Publisher:** project author | **Pub date:** 2026-08-19 | **Accessed:** 2026-09-08 | **Confidence:** high | **Class:** harvest
- **Claim:** The custom REST app is `/api/executemcp/v2`, dispatch class `ExecuteMCPv2.REST.Dispatch Extends %Atelier.REST`, password auth (`AutheEnabled=32`), resource `%Development`, namespace = the MCP profile's namespace. | **Source:** `src/ExecuteMCPv2/Setup.cls` L240, L263–312; `src/ExecuteMCPv2/REST/Dispatch.cls` L48 | **Publisher:** project author | **Pub date:** 2026-08-19 | **Accessed:** 2026-09-08 | **Confidence:** high | **Class:** harvest
- **Claim:** Self-install is driven entirely from the TypeScript side through the standard Atelier API (SQL `action/query` calling `SqlProc` methods on `ExecuteMCPv2.Setup`, `PUT /doc?ignoreConflict=1`, `action/compile`), with a content-hash version stamp and a quad-state probe (`missing/current/unconfigured/stale`) that self-heals a lost web-app registration. | **Source:** `packages/shared/src/bootstrap.ts` L1411–1956; `scripts/gen-bootstrap.mjs` L15–92 | **Publisher:** project author | **Pub date:** 2026-08-19 | **Accessed:** 2026-09-08 | **Confidence:** high | **Class:** harvest
- **Claim:** `ipm/module.xml` is stale: it lists 13 core + 5 test classes and omits `REST.Base`, `REST.EnvSync`, `REST.Health`, `REST.Loc`, `REST.MessageResend`, `REST.SqlAdvisor`, `Diagram.*`, `Loc.*` (29 classes are embedded by the bootstrap); every handler now extends `REST.Base`, so an IPM install from this manifest would likely fail to compile. | **Source:** `ipm/module.xml` L13–36 vs `scripts/gen-bootstrap.mjs` L15–43 and `src/ExecuteMCPv2/REST/Base.cls` L507 | **Publisher:** project author | **Pub date:** 2026-08-19 | **Accessed:** 2026-09-08 | **Confidence:** high for the omission; medium for the compile-failure inference | **Class:** harvest
- **Claim:** `tool_support.md` says `BOOTSTRAP_VERSION` ships at `01dc15bb27df`; the code embeds `e1168c1ebe56` — the doc lags the code. | **Source:** `tool_support.md` L68 vs `packages/shared/src/bootstrap-classes.ts` L25 | **Publisher:** project author | **Pub date:** 2026-08-19 | **Accessed:** 2026-09-08 | **Confidence:** high | **Class:** harvest
- **Claim:** `Dispatch.cls` routes global set as `PUT /global` while `tool_support.md` documents `POST /global`. | **Source:** `src/ExecuteMCPv2/REST/Dispatch.cls` L76; `tool_support.md` L47 | **Publisher:** project author | **Pub date:** 2026-08-19 | **Accessed:** 2026-09-08 | **Confidence:** high (TS side `global.ts` handler body not read) | **Class:** harvest
- **Claim:** Governance keys are `tool` / `tool:action`; 141 frozen baseline keys are enabled; new writes default-disabled unless `defaultEnabled`; cascade is env.profile → env.global → file.profile → file.global → preset → default seed; enforcement is a call-time gate returning `GOVERNANCE_DISABLED`. | **Source:** `packages/shared/src/governance.ts` L15–48, L704–720, L828–849; `packages/shared/src/governance-baseline.ts` L1994; `README.md` L373–402 | **Publisher:** project author | **Pub date:** 2026-08-19 | **Accessed:** 2026-09-08 | **Confidence:** high | **Class:** harvest
- **Claim:** Hazardous operations use layered gates implemented server-side in ObjectScript, not only in TypeScript: `resendFiltered` requires `dryRun:false` AND `confirm:true`; `clean` + `killAppData` requires `confirm`; `iris_audit_manage:purge` requires `confirm`; `iris_mapping_manage` requires `force` to overwrite a `%`-global base mapping. | **Source:** `src/ExecuteMCPv2/REST/MessageResend.cls` L504–513; `src/ExecuteMCPv2/REST/Interop.cls` L141–145, L256–259; `packages/iris-admin-mcp/src/tools/audit.ts` L298; `src/ExecuteMCPv2/REST/Config.cls` L557 | **Publisher:** project author | **Pub date:** 2026-08-19 | **Accessed:** 2026-09-08 | **Confidence:** high | **Class:** harvest
- **Claim:** The only write enabled by default via `defaultEnabled` is `iris_production_control:clean`; the documented operating guidance is recover first, clean last, `killAppData` only with accepted data loss. | **Source:** `packages/iris-interop-mcp/src/tools/production.ts` L176–179; `tool_support.md` L184; `README.md` L513–516, L670 | **Publisher:** project author | **Pub date:** 2026-08-19 | **Accessed:** 2026-09-08 | **Confidence:** high | **Class:** harvest
- **Claim:** The suite creates no custom resources, roles or private globals; it does create the `%ALL` namespace when absent and a package mapping `ExecuteMCPv2`→`%ALL`, and sets `^UnitTestRoot` when empty. | **Source:** `src/ExecuteMCPv2/Setup.cls` L340–388, L426–432; grep of `\^[A-Za-z%]…` across non-test `src/ExecuteMCPv2/**/*.cls` | **Publisher:** project author | **Pub date:** 2026-08-19 | **Accessed:** 2026-09-08 | **Confidence:** high | **Class:** harvest
- **Claim:** Admin/ops handlers depend on `%SYS`-only classes (`Security.*`, `Config.*`, `SYS.Database`, `%SYS.Task`, `%SYS.ProcessQuery`, `%SYS.Journal.System`, `%SYS.Audit`, `%SYS.X509Credentials`, `OAuth2.*`, `Backup.General`) and switch namespace with explicit save/restore; interop/data/dev handlers are namespace-local (`Ens.*`, `%DeepSee.*`, `%REST.API`). | **Source:** grep of `##class(...)` and `Set $NAMESPACE = "%SYS"` across `src/ExecuteMCPv2/REST/*.cls` (Security.cls 33 switches, Monitor.cls 13, Config.cls 6, Task.cls 4, SystemConfig.cls 2, Health.cls 1, Interop.cls 1) | **Publisher:** project author | **Pub date:** 2026-08-19 | **Accessed:** 2026-09-08 | **Confidence:** high | **Class:** harvest
- **Claim:** Recorded defects: (a) `iris_task_history` `taskId` silently ignored (`TaskHistoryDetail(NULL)` query), (b) resource/role `create` with `description` threw `<UNDEFINED>` (positional `Create` signature) — both dated 2026-04-20 and marked deferred; (c) global-mapping subscript bug — RESOLVED 2026-05-29; (d) classmethod `Write` output — RESOLVED by Epic 34; (e) `iris_doc_load` package-prefix drop — fixed by Story 35.9 per `tool_support.md` though `docs/bugs-2026-08-17.md` still says "Pending triage". | **Source:** `docs/known-bugs-2026-04-20.md`; `docs/known-bugs-2026-05-29-mapping-subscript.md` L652; `docs/bugs-2026-08-14.md` L761; `docs/bugs-2026-08-17.md` L1034; `tool_support.md` L70 | **Publisher:** project author | **Pub date:** 2026-04-20 → 2026-08-19 | **Accessed:** 2026-09-08 | **Confidence:** high for what is recorded; fix status of (a)/(b) unverified | **Class:** harvest
- **Claim:** Known limitations recorded in README: 32768-raw-char execution response ceiling (serialized body can be ~6x larger); `Security.Applications.Create()` does not notify the CSP Gateway (404 until SMP save/gateway restart); lenient UTF-8 decoder accepts overlong encodings (filter-bypass note) and pre-fix corrupted data is not repaired; `%Service_DocDB` disabled by default breaks 4 data tools; `iris_backup_manage` has no restore; no hot-reload of the governance file; per-profile visibility impossible; `iris_execute_tests` needs `^UnitTestRoot`. | **Source:** `README.md` L745–788, L415, L572; `tool_support.md` L224, L277, L404; `src/ExecuteMCPv2/Setup.cls` L405–418 | **Publisher:** project author | **Pub date:** 2026-08-19 | **Accessed:** 2026-09-08 | **Confidence:** high | **Class:** harvest
- **Claim:** MCP annotations and governance classification disagree for two tools: `iris_execute_tests` (`readOnlyHint:true`, governance `write`) and `iris_doc_export` (`readOnlyHint:false`, governance `write` for local disk). | **Source:** `packages/iris-dev-mcp/src/tools/execute.ts` L267; `packages/shared/src/baseline-classifications.ts` L1124–1128, L1156–1159 | **Publisher:** project author | **Pub date:** 2026-08-19 | **Accessed:** 2026-09-08 | **Confidence:** high | **Class:** harvest

---

## Leads — open questions

1. Are the two 2026-04-20 defects (`iris_task_history` taskId filter; resource/role create with description) fixed in current `Task.cls`/`Security.cls`? Only the 200-line CHANGELOG head was read; the handler bodies were not.
2. `iris_global_set` HTTP method: read `packages/iris-dev-mcp/src/tools/global.ts` handler to confirm it sends `PUT` (matching `Dispatch.cls`).
3. How `REST.Monitor:ECPStatus` obtains ECP data (no `##class`/`$SYSTEM` call matched in the scan).
4. `iris_server_profiles` exact handler and output schema in `packages/shared/src/server-base.ts` (only grep'd).
5. CSRF/session handling details in `packages/shared/src/http-client.ts` (not read) — relevant if OcuPilot's Angular front end wants to call `/api/executemcp/v2` directly with a browser session.
6. Whether `%Atelier.REST`'s envelope/ETag behaviour is acceptable for an Angular client, or whether OcuPilot should wrap the harvested handler bodies in a `%CSP.REST` dispatcher of its own.
7. `docs/epic-summary.md` and `docs/migration-v1-v2.md` were only grep'd for limitation keywords (two hits, none substantive); a full read may surface more deferred items; `_bmad-output/implementation-artifacts/deferred-work.md` (out of granted scope) is referenced repeatedly as the deferred-work ledger.
8. Live verification against `ocupilot-iris` (e.g., `iris_server_profiles`, `IsConfigured`) was outside this brief's granted sources.

## Gaps — looked for and could not find

- **Docker / `iris.script` install hooks**: none exist in the repository tree (searched for `docker*`, `Dockerfile`, `iris.script`); install is only bootstrap-over-Atelier or the (stale) IPM manifest.
- **Package READMEs' Known Limitations**: only `packages/iris-dev-mcp/README.md` has such a section (heading scan); it restates the UTF-8 item.
- **Suite-created roles/resources**: none found in `Setup.cls` or install flow.
- **A semantic version for the REST API**: none beyond the literal `/v2` path and the content hash; `ipm/module.xml` says 0.1.0 while npm packages say 0.0.2.
- **`ECPStatus` implementation API**: not identified (see Lead 3).
- **Runtime confirmation that the TS `confirm`/`killAppData` gates exist client-side**: `production.ts` only forwards the flags (L196–197); the gate is server-side in `Interop.cls`.
