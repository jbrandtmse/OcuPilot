---
title: 'Story 18.9: SQL object privileges'
type: 'feature'
created: '2026-10-07'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-18-context.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** SQL privileges on tables, views, procedures, schemas, ML configurations and foreign servers are classic-only (the User and Role pages' SQL tabs). The admin API's `Security.SQLPrivilege.Standard` expands wildcards and lists, answers some refusals with a 200 that changed nothing, and fails an unknown namespace with a 500.

**Approach:** A "SQL privileges" tab on both editors over one unlisted declared read, and grant and revoke tools for users and roles on a new `SqlPrivilegePort` that reads the state, sends one action, names the grantor and re-reads, so a write that moved nothing answers refused. A new AD-10 arm refuses grants and revokes on OcuPilot's own schemas (DW-236).

## Boundaries & Constraints

**Always:**

- **Read.** `SqlPrivilegeList` (`permissions/sql-privileges`, unlisted, scope `instance`) declares `Security.SQLPrivilege.Standard` `LIST` with criteria `grantee` and `namespace`, and a fixed `includeSystem=0` (the classic default; the tools still reach system schemas). Both tabs and `permissions.sqlprivileges.read` share it (AD-36).
- **Tools** (keys `true`, two callers each, AD-53, AD-55): `permissions.users.grantsql`, `.revokesql` (`UserList`) and `permissions.roles.grantsql`, `.revokesql` (`RoleList`); action-style (AD-51), no body, targeting the grantee; arguments `Namespace`, `Type`, `Object`, `Action` (+ `WithGrant` on a grant), one each per write so the re-read is exact.
- **Before any vendor call**, both callers: the Rules row (422 `SQLPRIV.*`); the pairs, Permissions' set plus READ on the namespace's routines and globals databases resolved at the call, refused by name (AD-8); the prohibited set (AD-10).
- **`AdminPort`** refuses, on every `Security.SQLPrivilege.Standard` call (the read included), a missing or undefined `namespace` (404 `SQLPRIV.NAMESPACE`), a missing `grantee` (400 `SQLPRIV.GRANTEE`), a missing READ pair on the namespace's databases (403 naming it), and a `*` or `,` in `grantee`, `object` or `action` (400 `SQLPRIV.LIST`).
- **The port re-reads after the vendor answers**: a state the write did not move is 409 `SQLPRIV.NOTAPPLIED`. AD-58's read-back still runs.
- Codes in `Api/SqlPrivilegeError.cls` (`Api/Error.cls` gains its two dispatch lines only). Probes: prefix `OcuSqlPrivProbe`, `ocupilot-ci` only, removed by exact name. One test class per call.

**Never:** column or admin privileges (18.28); role members, Copy from or password checks (18.29); `CUBES`; a grant or revoke on an OcuPilot schema's object or for an OcuPilot role, from either caller; `$SYSTEM.Monitor.State()` in a before/after snapshot; a change to `SqlPort.MaskCredentials` (DW-2096: no statement text crosses these surfaces).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected | Error handling |
|---|---|---|---|
| Read | A tab or the read tool, with a grantee and a namespace | One set of rows `{Type, Object, Action, GrantedBy, GrantOption, GrantedVia}`; only `Direct` rows offer Revoke | Boundaries' refusals |
| Grant | Probe user in USER, `TABLE` `OcuSqlPrivProbe.T1`, `SELECT` | A `Direct` row granted by the caller; `WithGrant` sets or upgrades `GrantOption` | -112/-99: 403 `SQLPRIV.GRANTOR`; -30/-187/-428/-473: 404 `.NOOBJECT`; -118: 404 `.NOGRANTEE` |
| Revoke | A `Direct` row another account granted | One `REVOKE` per grantor the fresh read names, each with `asGrantor`; the row is gone | — |
| Preconditions | Already held with that grant option or more; no matching row (a non-SCHEMA revoke finding only role, schema or ownership rows); any `SuperUser` row | 409 `SQLPRIV.HELD` (grant); `.NOTHELD` (revoke); `.SUPERUSER` (both). Nothing sent | A confirm closes as target-changed (`PRECONDITIONCODES`) |
| Schema | `SCHEMA` `OcuSqlPrivProbe` | Judged by the count of the schema's `Schema Privilege` rows for the action | Unmoved: 409 `.NOTAPPLIED` |
| No-op | Vendor 200, state unmoved | 409 `SQLPRIV.NOTAPPLIED` | — |
| OcuPilot's own | `IsOcuPilotCode(Object)`, any namespace; grantee in `OcuPilotRoles`, or `%DB_OCUPILOT` | `PROHIBITED.OCUPILOTSQLPRIVILEGE`; `PROHIBITED.OCUPILOTROLE` | No vendor call |
| Rules | See below | 422 `SQLPRIV.*` on the field; nothing sent | The mint refuses identically |

The Rules row refuses:

- a missing or undefined `Namespace`;
- a `Type` outside the six types;
- an `Action` outside its type's set (`ALTER` reads `%ALTER`): TABLE `%ALTER`, `SELECT`, `INSERT`, `UPDATE`, `DELETE`, `REFERENCES`; VIEW the same less `REFERENCES`; SCHEMA TABLE's plus `EXECUTE`; STORED PROCEDURE `EXECUTE`; ML CONFIGURATION and FOREIGN SERVER `USE`;
- an `Object` that is not one name (SCHEMA, ML CONFIGURATION) or `schema.name` (the rest), with each part matching `^[%A-Za-z][A-Za-z0-9_@#$]{0,127}$`;
- a grantee that is empty, over 160 characters, or carries `*` or `,`;
- a `WithGrant` that is not boolean.

</intent-contract>

## Code Map

- **Analogs:** `Port/MftPort.cls` `State` :67; `Port/OAuthResourceServerPort.cls` `AddMapping` :420; `Screen/Tool/UserUpdate.cls` `SCREENVALUES` :59; `database-editor.store.ts:463-482`.
- `Port/AdminPort.cls`: type lists :461, :477; `InvokeLocated` :1197 (its journal guards model the new guard); `Fail` logs every 500. `Port/AtelierPort.cls` `DatabaseResources` :668.
- Vendor endpoint (Hidden; `GetTextAsString`): `LIST` runs `%SQL.Manager.CatalogPriv:UserPrivs`; `GRANT`/`REVOKE` call `irislib/%SYSTEM/SQL/Security.cls` :130, :566.
- `Screen/Tool/Write.cls` (`READSVALUES` :176, `PRECONDITIONCODES` :502, `PortQuery` :459, `StateDiff` :525, `ArgumentProblem` :896), `Base.cls` `ArgumentPairs` :123, `Api/ScreenAction.cls` `Run` :249-348.
- `Kernel/Proposal/Prohibited.cls`: `Prohibits` :1252 (`SqlRun`'s branch :1299 precedes the target read), `Codes()` :897, `ReasonFor` :905, `OcuPilotRoles` :1993, `IsOcuPilotCode` :2411.
- `Api/Error.cls` :1230-1231, :1436-1437; model `Api/MftConnectionError.cls`. `UserList.cls` :63, `RoleList.cls` :46; model `DatabaseVolumeList.cls`.
- Client: `user-editor.page.ts` :717 (tabs), :1038 (`startFor`); `role-editor.page.ts` :522, :900.

## Tasks & Acceptance

**Task 0** (`ocupilot-ci`): record S0; through `AdminPort.Invoke`, send a `GRANT` naming an absent table and one from a principal lacking the privilege, recording each status, fault, status parameters and severity-2 line; clear the monitor. Record in Design Notes; halt on a contradiction with Measured at plan; restore S0.

**Execution (server):**

- `Api/SqlPrivilegeError.cls` (new): the Design Notes codes; `Error.cls` its two lines.
- `Port/AdminPort.cls`: `Security.SQLPrivilege.Standard/GRANT` and `/REVOKE` in both type lists; `SQLPRIVILEGETYPES` and `SqlPrivilegeGuard`, the Boundaries refusals on each of the endpoint's types.
- `Port/SqlPrivilegePort.cls` (new, extends `AdminPort`, vendor calls through an overridable `Call`):
  - `GRANTSTATE`, `REVOKESTATE` (`COMPOSEDTYPES`): one `LIST` (`includeSystem=1`, `maxRows` 100,000, a full answer a fault) answering `{Held, GrantOption, GrantedBy, Rows}`: non-SCHEMA counts `Direct` rows matching `Object` (ignoring case; TABLE and VIEW alike) and `Action`; SCHEMA counts the schema's `Schema Privilege` rows; `GrantedBy` is the distinct sorted grantors. They refuse as the matrix's Preconditions row.
  - `GRANT` sends one vendor `GRANT`; `REVOKE` one per grantor (`asGrantor` that grantor, `cascade` 0). A re-read then judges: a grant applied holds the asked grant option or raised a schema count; a revoke lowered `Rows` (to 0 outside SCHEMA); else 409 `.NOTAPPLIED`.
  - The SQLCODE is #5540's first or #5035's second parameter, mapped as the matrix. `Snippet` mirrors each branch (AD-59).
- `Screen/Tool/SqlPrivilegeWrite.cls` (new, abstract): `PORTCLASS` `SqlPrivilegePort`, `SENDSBODY` 0, `READSVALUES` 1, `IdParam` `grantee`, `FINGERPRINTSUBJECT` `Held,GrantOption,GrantedBy,Rows`; `ArgumentProblem` the Rules row; `ArgumentPairs` READ on `Namespace`'s databases; `PortQuery` the arguments; `StateDiff` the card rows, each grantor on a revoke. Subclasses `UserSqlGrant`, `UserSqlRevoke`, `RoleSqlGrant`, `RoleSqlRevoke`; `CLASSICPAGES` is the editor's page (`%CSP.UI.Portal.User` or `.Role`), the grants adding `%CSP.UI.Portal.Dialog.SchemaPriv,%CSP.UI.Portal.Dialog.MLConfigurationPriv`:

  | Parameter | Grant | Revoke |
  |---|---|---|
  | `READTYPE` / `WRITETYPE` | `GRANTSTATE` / `GRANT` | `REVOKESTATE` / `REVOKE` |
  | `PRECONDITIONCODES` | `.HELD,.SUPERUSER` | `.NOTHELD,.SUPERUSER` |
  | `SCREENVALUES` | `grant-sql=Namespace:Type:Object:Action:WithGrant` | `revoke-sql=Namespace:Type:Object:Action` |

- `UserList.cls`, `RoleList.cls`: the two row actions.
- `Screen/Descriptor/SqlPrivilegeList.cls` (new): Boundaries' read; `permissions`, `list`, `sideBarPosition` 0, entity type `""`, Permissions' pairs, no actions; the six fields (`Object` the name); id composite over `Type`, `Object`, `Action`, `GrantedVia`, `GrantedBy`; criteria `grantee` (text, 160) and `namespace` (text, 64), each with a `hint`; classic `%CSP.UI.Portal.User`; three prompts; empty state; `toolIdentifier` `permissions.sqlprivileges`.
- `Screen/Tool/Classification.cls`: the five arguments `ordinary`; regenerate `ToolFields.cls`.
- `Kernel/Proposal/Prohibited.cls` (add-only): `OCUPILOTSQLPRIVILEGE` with its reason, `Codes()` and `ReasonFor` lines; a `Prohibits` branch for the four tools before the target read, calling `SqlPrivilege`: `OCUPILOTROLE` for a grantee in `OcuPilotRoles` or `%DB_OCUPILOT`, then `OCUPILOTSQLPRIVILEGE` when `IsOcuPilotCode(Object)`.
- `Kernel/Governance/Baseline.cls`: the four keys `true`.

**Execution (client):**

- `areas/permissions/sql-privileges-tab.ts`, `.store.ts` (new; a grantee and `USER_LIST` or `ROLE_LIST`): a namespace select (default the route's); rows via `createScreenRead`, identical rows once; Revoke on `Direct` rows only, others hinting where granted; "Grant or revoke…" opens `sql-privilege-dialog.ts` (new: mode, type, object, an action of the type, grant option). Both send through `startFor` with values, Revoke at once as Remove role does; the tab re-reads on apply and on its grantee's change event.
- `user-editor.page.ts`, `role-editor.page.ts` and their stores: a "SQL privileges" tab, read when selected; `shell/screen-action-handler.ts` `UNDRAWN_ACTIONS`; `core/screen-actions.ts`; `core/strings.ts`.
- EXPERIENCE.md in place: the Permissions Fixed strings row, the refusal sentence included; fix shifted `EXPERIENCE.md:n` comments. Regenerate `screens.generated.ts`; `ui/tools/strings.test.mjs`'s bound to 3000; re-base `angular.json` if crossed (DW-1166).

**Tests:**

- `Test/SqlPrivilegeDescriptor.cls`: declarations, keys, the new code.
- `Test/SqlPrivilegeRead.cls` (fixture `Test/SqlPrivilegeProbe.cls` makes and removes the probe schema, objects and principals, cleans USER's statement index and clears the monitor): one set for screen and tool; the four `GrantedVia` kinds; the guard's three refusals.
- `Test/SqlPrivilegeWrite.cls` (armed by `OCUPILOT_ALLOW_PRINCIPALS`): each matrix row, both callers, user and role; another grantor's row revoked over the wire by the gate principal; `NOTAPPLIED` via `Test/SqlPrivilegeSeamPort.cls`; AD-10 on `OcuPilot_Kernel_State.Turn` and `OcuPilotAdmin` (the `%DB_OCUPILOT` grant reads back unchanged); the Rules legs; the routes over the wire.
- `Test/SqlPrivilegeGate.cls` (armed): Security's two pairs plus `%DB_USER:READ` list, grant and revoke in USER; lacking `%DB_USER:READ` or `%Admin_Secure:USE`, each is refused by name before any port call.
- Rosters (add-only): those Story 18.26's Tasks › Tests extended (bar `EndpointCoverage`, which gains no route), with `ReadTool` 304 to 309, `Prohibited` 31 to 32 codes, `RefusalCopy`, `ui/tools/self-protection.test.mjs`, the permissions wire literals (`Wire.cls:565`, `WireSecurityRead.cls`) and `navigation.test.mjs`'s unlisted permissions routes; `ScreenRead` if needed.
- `sql-privileges-tab.spec.ts`, `sql-privilege-dialog.spec.ts`.
- `ui/browser/permissions-sql-privileges.browser-spec.mjs` (new): a probe user's tab in USER grants `SELECT` in the dialog, shows the `Direct` row and revokes it; a probe role's schema rows offer no Revoke; an after hook removes the probes.

**Acceptance Criteria:**

- **C0.** Given Task 0, when it runs, then each result is recorded and the throwaway reads as S0.
- **C1.** Given a probe user and role in USER, when their privileges are listed, granted and revoked from each tab and by a confirmed proposal, then each round-trips through `Security.SQLPrivilege.Standard` and reads back, tab and read tool answering one set.
- **C2.** Given a `Direct` privilege another account granted, when either caller revokes it, then the revoke names that grantor and removes it; role, schema and ownership rows are shown with no Revoke.
- **C3.** Given a grant the grantor rule refuses, or a vendor 200 that moved nothing, when either caller sends it, then it is answered refused by its code, never applied.
- **C4.** Given a Rules case, a wildcard or list, or an undefined namespace, when either caller sends it (the read included), then it is refused before any vendor call.
- **C5.** Given a grant or revoke on an OcuPilot schema's object or for an OcuPilot role, when either caller sends it, then AD-10 refuses it by code and `OcuPilot_Kernel_State`'s grant to `%DB_OCUPILOT` holds (DW-236).
- **C6.** Given the rosters, when the suites run, then the descriptor, tools, keys, code and sentence are pinned on both sides.
- **Integration.** Given `ocupilot-ci`, when the tabs and the agent act, then the tabs go through `GET /screens/:screen/read` and `POST /screens/:screen/action` (`grant-sql`, `revoke-sql`) and the agent through the five tools (C1-C5, the browser spec).

## Spec Change Log

- 2026-10-07, spec gate (lead): Decisions 1-5 confirmed. Spine amendments written (AD-8, AD-10, AD-52, AD-2, AD-44). DW-2007 gains this endpoint's #5540 and #5035 codes. Vendor candidates DW-2176, DW-2177, DW-2178 under the owner's hold. The Fixed-strings bound may rise to 3000 (`strings.test.mjs` is not contended).

## Review Triage Log

## Design Notes

**Governing ADs:** AD-2, AD-3, AD-5, AD-8, AD-10, AD-13, AD-14, AD-22, AD-27, AD-29, AD-34, AD-36, AD-39, AD-44, AD-51, AD-52, AD-58, AD-59; AD-15/AD-53 need no named case (the vendor audits grants and revokes, `UserChange`/`RoleChange`).

**Measured at plan** (`ocupilot-ci`, 2026-10-07, `/api/admin/v2` as `_SYSTEM`; extends `split-18-9-sql-privileges-2026-10-07.md`):

- Rows: `GrantOption` boolean; `Object` canonical in any case sent; `%ALTER` as sent; a `withGrant` re-grant upgrades `GrantOption`; a role's grant lists on its holder as `Role:<role>`.
- Schemas: a grant lists `Schema Privilege` rows per table and view (`SELECT`) or procedure (`EXECUTE`); schema `USE` listed a foreign server with action `l`; a privilege held directly and through a role lists twice; `HEAD` answered 404 for a held schema grant (unused).
- An `%All` holder lists only `SuperUser` rows (126 in USER); a direct grant to one was stored, not listed, so it cannot be read back (hence `.SUPERUSER`).
- A principal with `%Admin_Secure:U`, `%DB_USER:R` and no SQL privilege: a revoke without `asGrantor` answered 200 and left the row; with `asGrantor=_SYSTEM` it removed `_SYSTEM`'s table and schema grants; its grant answered 500 #5035 `[..,"-112",..]`. Validation faults are 500 #5540 `[SQLCODE, message]`.
- No namespace here has distinct routines and globals databases. End state S0, after `$SYSTEM.SQL.Statement.Clean()` in USER.

**Decisions** (spec gate):

1. **The target is the grantee, through `UserList` and `RoleList`** (7.2's shape), with no new entity type; the namespace is an argument like the object, since a principal's SQL privileges are one set reached per namespace (AD-13 scope `instance`).
2. **A revoke removes every grantor's direct grant**, each named, as the classic Revoke passes the grantor; any `%Admin_Secure` holder may (measured).
3. **Schemas are judged by row count**: a schema whose objects take none of the action lists nothing, so its grant reads `NOTAPPLIED` though stored and cannot be revoked here (named limit; inference).
4. **READ on both databases**: which one the switch needs where they differ is unmeasured; a narrower audience, as AD-8 accepts.
5. **No grantor pre-check**: the vendor's -112 500 logs at severity 2 until DW-2007 takes it, as 18.26's #5809.

**Codes:** field codes `SQLPRIV.NAMESPACE`, `.GRANTEE`, `.TYPE`, `.OBJECT`, `.ACTION`, `.WITHGRANT` under the `.VALIDATION` envelope; the rest as the matrix and Boundaries. Kernel `PROHIBITED.OCUPILOTSQLPRIVILEGE`: "OcuPilot's own SQL tables keep the privileges its installer grants, so a grant or revoke on them is not offered."

**Criterion 5.** No SQL route confers a role; the `%All`/`%Admin_*` destructive treatment is 18.29's Copy from. The prohibited set applies, plus the new arm.

**Integration ACs.** In-story consumers: both tabs and the agent. Consumes: 9.1, 9.3, 16.3, 7.2, 18.26, 23.4, 16.17. Consumed-by: 18.28 (extends list, port, guard, arm), 18.12.

**Ledger (Rule 17).** DW-236's refusal half: C5. Its detection half is DW-2172 (18.13).

**For the lead** (Rule 20): AD-8 the tools' pairs (measured: `<PROTECT>` without READ; no WRITE or `%DB_IRISSYS:READ` needed); AD-10 the arm (a revoke of `Install/Installer.cls:3432`'s grant leaves OcuPilot `unreadable`) and `OCUPILOTROLE` for SQL grantees; AD-51/AD-52 the port's case, per-grantor revoke and re-read; AD-2 the guard; AD-44 `CLASSICPAGES`; DW-2007 gains this endpoint's #5540 (-30, -118, -187, -428, -473) and #5035 (-112, -99); the Fixed strings bound 2900 to 3000 (inference: about 13 left); vendor candidates (owner hold): schema `HEAD` 404, doubled schema rows, schema `USE` as `l`.

**Footprint (Rule 11).** Add-only edits to contended files (kernel, `Error.cls`, `Classification.cls`, rosters, wire pins, `strings.ts`, EXPERIENCE.md, `ci-throwaway.sh`); `footprint_extensions` `AdminPort.cls` and the new port and error class.

**Size (inference).** One implement pass, as 18.26.

## Verification

**Setup.** Load with `sh /private/tmp/claude-501/-Users-jbrandt-git-OcuPilot/1518373f-040c-4be6-a814-a27bfbff2961/scratchpad/epic-18-d8/load-ocupilot-ci.sh` (`LOAD-OK`, `STARTPATH-OK`); one test class per call, landed in `%UnitTest_Result` before the next; before a browser run, rebuild and `docker cp` the bundle to `ocupilot-ci`, with `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776` and `OCUPILOT_BROWSER_CONTAINER=ocupilot-ci`.

**S0 (`ocupilot-ci`):** no `OcuSqlPrivProbe*` or `OcuProbe189*` principal, schema, table, statement-index node or `Security.SQLPrivileges` row; monitor 0.

**Commands:**

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.<C>`, the four story classes then the rosters: 0 failures, totals checked in `%UnitTest_Result`.
- `(loop)` `cd ui && node --test --test-concurrency=1 browser/permissions-sql-privileges.browser-spec.mjs browser/permissions.browser-spec.mjs browser/permissions-effective.browser-spec.mjs`: pass.
- `(loop)` `cd ui && npm run test:tools && npm run test:components`; `uv run scripts/check-objectscript.py <changed .cls>`; `bash scripts/lint-docs.sh`: clean.
- `(once, before dev_complete)`: the full ObjectScript sweep, one class at a time; `cd ui && npm test && npm run build`; `bash scripts/smoke.sh --container ocupilot-ci --user _SYSTEM --password SYS`; S0.
- `(CI)` the full browser suite (Rule 29).

**Planned mutations (Rule 19)**, each recorded as `mutation: <change> -> <test> red (run n)`: C1 the read drops `GrantedVia`; C2 no `asGrantor`; C3 no re-read (seam leg); C4 no namespace check in the guard; C5 `SqlPrivilege` skips `IsOcuPilotCode`; C6 a key `false`; Integration `revoke-sql` out of `SCREENVALUES` (wire leg), and Revoke on a non-`Direct` row (`sql-privileges-tab.spec.ts`).

## Auto Run Result

Status: ready-for-dev
Blocking condition: none
