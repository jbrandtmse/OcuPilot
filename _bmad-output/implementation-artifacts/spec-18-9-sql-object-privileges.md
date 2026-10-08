---
title: 'Story 18.9: SQL object privileges'
type: 'feature'
created: '2026-10-07'
status: 'done'
baseline_revision: '6bda2c494e5977e23b427b3509b6ac409b062400'
baseline_commit: '6bda2c494e5977e23b427b3509b6ac409b062400'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-18-context.md'
warnings: ['oversized']
deferred:
  - summary: >-
      The four tools get no Classification or ToolFields entry: their arguments are authored in SqlPrivilegeWrite.InputSchema.
    evidence: |-
      The spec asked for the five arguments classified ordinary and ToolFields regenerated. The tools send no body (SENDSBODY 0), so Write.FieldRows derives no row and the Standard endpoint publishes no body template to classify; a Classification entry would name a field list that does not exist (field-lists.mjs --check stays green without one, as for the MFT revoke and the production actions).
    location: >-
      src/OcuPilot/Screen/Tool/Classification.cls
    severity: low
  - summary: >-
      A grant on an absent FOREIGN SERVER answers 500 #5002 (<SUBSCRIPT>), not an SQLCODE, so the port answers INTERNAL where it answers SQLPRIV.NOOBJECT for every other type. IRIS defect candidate, decision pending, not reported upstream.
    evidence: |-
      ocupilot-ci, 2026-10-08, Standard GRANT type FOREIGN SERVER object NoSrv: ERROR #5002 <SUBSCRIPT>GrantPrivilege+64^%SYSTEM.SQL.Security.1 ^rINDEXSQL("SERVER","NOSRV",""). Table, view, procedure, ML configuration and schema all answered #5540 with -30, -428, -187 and -473.
    location: >-
      src/OcuPilot/Port/AdminPort.cls SQLCODEFAULTS
    severity: low
  - summary: >-
      ML CONFIGURATION and FOREIGN SERVER privileges are pinned by their Rules and the vendor's refusals only, never granted against a live object.
    evidence: |-
      A Community instance cannot create a foreign server or an ML configuration without an external provider, so no test grants or revokes one. The Rules take a foreign server as schema.name (the spec's "the rest") and an ML configuration as one name; the first is unconfirmed against the instance.
    location: >-
      src/OcuPilot/Port/SqlPrivilegePort.cls ObjectValid
    severity: low
  - summary: >-
      Sub-claims of C2-C4 (the -112 grantor mapping, Violations' namespace check, the role-row Direct count, the gate pair sets) carry doc-comment mutations that no recorded run has reddened.
    evidence: |-
      The verification-gap layer found the eight recorded mutation lines cover each criterion's main path only. Each named sub-claim has a test asserting it (SqlPrivilegeGate 403 SQLPRIV.GRANTOR, SqlPrivilegeRead guard legs, sql-privileges-tab.spec.ts Revoke legs); a recorded red run would settle it.
    location: >-
      src/OcuPilot/Test/SqlPrivilegeGate.cls
    severity: low
  - summary: >-
      WireSecurityRead TestTaskHistoryPairSetsAreEnforcedForARealPrincipal reads a truncated task history on the 27-hour-old ocupilot-ci after a 511-class sweep.
    evidence: |-
      Failed once at the sweep end and again on a solo rerun with "nothing is cut at 1,000"; the story changes only three roster lines in that class and no task-history code. A fresh throwaway (CI) has no such history; recreating ocupilot-ci is the owner's call and would settle it.
    location: >-
      src/OcuPilot/Test/WireSecurityRead.cls AssertSameRowsAsTestAccount
    severity: low (unverified)
  - summary: >-
      A GRANT of EXECUTE on a TABLE returns an OK status and stores a privilege row (code `e`) that the Standard LIST never shows and that survives the grantee's and the table's removal. IRIS defect candidate, decision pending, owner's hold, not reported upstream.
    evidence: |-
      ocupilot-ci, 2026-10-08, `$SYSTEM.SQL.Security.GrantPrivilege("EXECUTE", "OcuSqlPrivProbe.T1", "TABLE", "OcuSqlPrivProbeU")` returned OK; `Rows` listed only the SELECT grant; after RemoveAll `Security.SQLPrivileges` still held `USER||1,OcuSqlPrivProbe.T1||e||OcuSqlPrivProbeU||irisowner`. The cleanup test now grants it on purpose; the orphan row came from Task 0's raw `GRANT` through `AdminPort.Invoke` (inference), since no product path can send it.
    location: >-
      src/OcuPilot/Test/SqlPrivilegeProbe.cls RemoveAll
    severity: low
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

- [x] [CI] browser shards 1/3 and 3/3 (run 37741029438 on 0a7a868d): `roles-editor.browser-spec.mjs` ("a row's name opens the editor on General, Members and Assigned to") and `users-editor.browser-spec.mjs` ("... General, Roles and Effective privileges tabs") assert each editor's exact tab list, which now ends with `SQL privileges` -- <https://github.com/jbrandtmse/OcuPilot/actions/runs/37741029438> -- update both expectations (and any other spec that lists an editor's tabs, e.g. `unreadable.browser-spec.mjs`), and run each touched spec against a rebuilt and redeployed bundle.
- [x] [Smoke] `SqlPrivilegeProbe.RemoveAll` leaves `Security.SQLPrivileges` rows for its probe grantees: deleting the user and dropping the table does not remove them, and `ocupilot-ci` holds `USER||1,OcuSqlPrivProbe.T1||e||OcuSqlPrivProbeU||irisowner` (EXECUTE on the probe table, grantee deleted) -- `RemoveAll` revokes every row whose grantee is a probe principal, in every namespace the tests use, before deleting the principals; every SQL privilege teardown asserts none remains; remove the existing row; and find which call stored EXECUTE on a table (the Rules refuse it before the vendor) -- a vendor quirk goes in `deferred:` under the owner's hold.

### Review Findings

Code review 2026-10-08 (four layers, full-opus): 49 rows: 13 kept entries (high 0, med 3, low 10), of which 10 patched and 3 deferred; 28 rows rejected (25 entries). No AD violation. Rule 3 holds: the browser spec and the wire legs. The `ScreenAction.Run` early gate changes nothing for the other `READSVALUES` tools, because only `SqlPrivilegeWrite` derives pairs from its values.

- [x] [Review][Patch] (med) The `Object` schema called a foreign server one name. The Rules and the vendor take `schema.name` [src/OcuPilot/Screen/Tool/SqlPrivilegeWrite.cls:100]
- [x] [Review][Patch] (med) A revoke of a privilege the grantee granted on answered 500 `INTERNAL` (#5035 -126, measured on `ocupilot-ci`). It now answers 409 `SQLPRIV.DEPENDENT` [src/OcuPilot/Port/AdminPort.cls:2858]
- [x] [Review][Patch] (med) A namespace change left the old namespace's rows and their Revoke drawn until the new read landed. The rows are now dropped at once [ui/src/app/areas/permissions/sql-privileges-tab.store.ts:105]
- [x] [Review][Patch] (low) The schema test's mutation note could not redden; it is replaced with one that does [src/OcuPilot/Test/SqlPrivilegeWrite.cls:188]
- [x] [Review][Patch] (low) DW-2186: the `Violations` namespace check and `PrivilegePairs` had no recorded red, and the `PrivilegePairs` note sat on the wrong method [src/OcuPilot/Test/SqlPrivilegeGate.cls:164]
- [x] [Review][Patch] (low) Nothing pinned `includeSystem` 1 on the state read; the seam now records it [src/OcuPilot/Test/SqlPrivilegeSeamPort.cls:56]
- [x] [Review][Patch] (low) No test covered a dialog refusal that names no field (close onto the banner) [ui/src/app/areas/permissions/sql-privileges-tab.spec.ts:165]
- [x] [Review][Patch] (low) The `DESTRUCTIVE` doc comment said "nothing is lost" [src/OcuPilot/Screen/Tool/SqlPrivilegeWrite.cls:34]
- [x] [Review][Patch] (low) Two `AdminPort` doc comments described an override hook that nothing uses [src/OcuPilot/Port/AdminPort.cls:2874]
- [x] [Review][Patch] (low) Test hygiene: a hard-coded `_SYSTEM` grantor, and `GiveAll` statuses that were never checked [src/OcuPilot/Test/SqlPrivilegeWrite.cls:103]
- [x] [Review][Defer] (low) A refused tab read shows "Request refused" and never names the missing pair [ui/src/app/areas/permissions/sql-privileges-tab.ts:38] — deferred: DW-2188 wontfix-accepted
- [x] [Review][Defer] (low) Revoke buttons carry no aria-label naming their row [ui/src/app/areas/permissions/sql-privileges-tab.ts:83] — deferred: DW-2189 wontfix-accepted
- [x] [Review][Defer] (low) The dialog's type, action and length lists repeat the port's with no parity test [ui/src/app/areas/permissions/sql-privilege-dialog.ts:8] — deferred: DW-2190 wontfix-accepted

Rejected:

- false: an OcuPilot role name on a user grantee. IRIS refuses such a user (#942, probed).
- false: -99 is unmeasured. The matrix maps it, and Epic 18's context records it.
- false: the tab draws with an empty grantee. The editor draws its tabs only once loaded, and an id change resets them.
- by-design: schema `NOTAPPLIED` for an action no object takes (Decision 3).
- by-design: SQLCODE refusals log at severity 2 (Decision 5, DW-2007; occurrence appended).
- by-design: the read's `includeSystem` 0 (Boundaries).
- by-design: the revokes' `CLASSICPAGES` (AD-44 amendment).
- by-design: a type outside the six answers `TOOL.ARGUMENTS` (the closed enum).
- by-design: preconditions answer before AD-10 (AD-53's order; nothing is sent either way).
- theoretical: a revoke loop that fails partway (one grantor per privilege).
- theoretical: `IsSqlPrivilegeTool`'s exact `PORTCLASS` match. It becomes real only if a port subclass ships; `Prohibited.cls` is contended.
- theoretical: `<MAXSTRING>` in the early gate's value copy.
- not reachable through the shipped code: DW-2184's one-part foreign server, which the Rules refuse. It stays on the owner's hold.
- low: a truncation note on the tab.
- low: the "Action" legend.
- low: OcuPilot's own rows offer Revoke (the refusal reaches the banner).
- low: the gate's delta computed twice.
- low: lower-cased types in card text.
- low: the tab is unsorted.
- low: the browser seed is unasserted.
- low: Revoke drawn on a direct CUBES row.
- low: the split-database branch has no test.
- low: the revoke script names a placeholder grantor.
- spec edits: the Auto Run Result tally, and the fifth deferral's severity label.

Code review 2026-10-08, rework 1 (four layers, full-opus, scope `6bda2c49..HEAD`): 43 rows, 11 entries (high 0, med 0, low 11), 7 patched, 4 rejected. Both open items hold. `[CI]`: only the users and roles editor specs assert an exact tab list (`unreadable.browser-spec.mjs` lists none). `[Smoke]`: no probe privilege row survives a class run, and the sweep deletes only rows whose grantee carries the probe prefix. The unpinned revoke pass was a finding and is now pinned.

- [x] [Review][Patch] (low) `RevokeAll` sent the list's `%ALTER` to `RevokePrivilege`, which takes `ALTER` (-60, swallowed; probed on `ocupilot-ci`), and no test depended on it; the sweep runs before the count, so a failed revoke never showed. Translated, and the cleanup test asserts the revoke leaves only the unlisted row [src/OcuPilot/Test/SqlPrivilegeProbe.cls:91]
- [x] [Review][Patch] (low) `SqlPrivilegeGate`'s grant to `OcuProbe188H` on the probe table was outside every count; `RemainingPrivileges` also counts rows on the probe schema's objects, whoever the grantee (probed: 1 with such a row, 0 after cleanup) [src/OcuPilot/Test/SqlPrivilegeProbe.cls:105]
- [x] [Review][Patch] (low) The probe's and `SqlPrivilegeRead`'s doc comments said "removed by exact name" and "revokes every privilege", generalized the one orphan row, and did not say why the sweep deletes from `Security.SQLPrivileges` directly [src/OcuPilot/Test/SqlPrivilegeProbe.cls:7]
- [x] [Review][Patch] (low) The cleanup test relies on the vendor storing `EXECUTE` on a table and did not say what to do if a later build stops [src/OcuPilot/Test/SqlPrivilegeRead.cls:239]
- [x] [Review][Patch] (low) The two editor specs' titles and headers named three tabs [ui/browser/users-editor.browser-spec.mjs:192]
- [x] [Review][Patch] (low) The latest `SqlPrivilegeRead` run on `ocupilot-ci` was the red mutation run 2400; runs 2401 and 2403 are green [src/OcuPilot/Test/SqlPrivilegeRead.cls:239]
- [x] [Review][Patch] (low) "Every teardown asserts none remains" had no recorded red; run 2400's is now under Verification [src/OcuPilot/Test/SqlPrivilegeRead.cls:48]

Rejected (rework 1):

- low: a failed count or sweep query reads as zero. It needs `Security.SQLPrivileges` unreadable to an `%All` process, and the fix is a guard.
- low: the `[CI]` mutation changes the expectation, not the product. These are tab-list pins, not an AC's pinning test, and the comparison fails both ways (CI run 37741029438 and the rework's run).
- false: the sweep's prefix match ignores case. IRIS user and role names are case-insensitive, so a case variant is the same principal.
- low, spec text for the lead: the `[Smoke]` source. No product path stores `EXECUTE` on a table (the Rules and `SqlPrivilegePort.Violations` refuse it; `SqlPrivilegeDescriptor` pins it). Task 0's raw `GRANT` through `AdminPort.Invoke` is the only such grant recorded before the rework (inference), so Task 0's "stored nothing" and the deferral's "caller unidentified" and "No suite grants it" are stale. Also stale: the rework triage's `[false]` label and its revoke rationale, and the deferral's "answers 200" (a `%Status`, not HTTP).
- out of scope, not high: the editors' visual gates never open the SQL privileges tab.

## Spec Change Log

- 2026-10-08, rework iteration 1 (trigger ci, smoke): the two editor specs' tab lists, and the probe cleanup's orphan privilege rows; the open items are the `[CI]` and `[Smoke]` tasks under Tasks & Acceptance.

- 2026-10-07, spec gate (lead): Decisions 1-5 confirmed. Spine amendments written (AD-8, AD-10, AD-52, AD-2, AD-44). DW-2007 gains this endpoint's #5540 and #5035 codes. Vendor candidates DW-2176, DW-2177, DW-2178 under the owner's hold. The Fixed-strings bound may rise to 3000 (`strings.test.mjs` is not contended).

## Review Triage Log

### 2026-10-07 - Review pass

- verdicts: 10 findings - high 0, medium 1, low 6, false 1, maybe-false 2
- findings:
  - `[medium]` `[patch]` The SQL privilege arm in Prohibits keyed on WriteType also caught permissions.users.revokesql's neighbour, the token revoke, for an account named like an OcuPilot role - verified at Prohibited.cls (UserTokenRevoke WRITETYPE REVOKE); patched: the arm is keyed on the tool's PORTCLASS (IsSqlPrivilegeTool), TokenRevoke gains TestTheSqlPrivilegeArmDoesNotJudgeATokenRevoke, mutation red (run 2367)
  - `[low]` `[patch]` The early READSVALUES gate in ScreenAction.Run had no mutation line - mutation `If 0 && $IsObject(pValues)` -> SqlPrivilegeGate TestWithoutTheNamespaceDatabaseReadEveryCallIsRefused red (run 2365)
  - `[low]` `[patch]` The store's superseded-read guard was not pinned - overlap spec added to sql-privileges-tab.store.spec.ts; removing the generation check reddens it
  - `[low]` `[patch]` The OCUPILOTROLE branch of SqlPrivilege had no mutation - `If 0 ||` on the own-role test -> SqlPrivilegeWrite TestOcuPilotsOwnSchemaAndRolesAreRefusedOnBothCallers red (run 2366)
  - `[low]` `[defer]` Doc-comment-only mutations for the GRANTOR mapping, Violations, role-row Direct count and gate pair sets - each has an asserting test; a recorded red run would settle it
  - `[low]` `[reject]` TestTheRoutesAnswerAndKeepTheirBodiesClosed asserts Rows(tUser) = "" which holds whatever the role grant did - the preceding 200 assertion carries the weight; a guard here adds nothing a developer would meet
  - `[low]` `[reject]` TestTheScriptsMirrorTheBranches first withGrant check is weak - the next assertion pins withGrant=1, so the member must exist
  - `[false]` `[reject]` sql-privileges-tab.spec.ts refusal test calls setRefusal directly - the dialog path test covers the handler-to-alert route, and the sink is the component's own contract
  - `[maybe-false]` `[defer]` Intent-alignment: write-path assertions run through SqlPrivilegeSeamPort subclasses - the seam inherits the shipped tools unchanged and the wire legs run the shipped classes; settled by the wire legs in SqlPrivilegeWrite
  - `[maybe-false]` `[defer]` Intent-alignment: ScreenAction.Run edited beyond the spec's named files - the early gate is needed for AD-8 (a caller lacking READ reached the port); the full sweep (511 classes) covers the other READSVALUES tools
- sweep: 511 classes, 4090 tests, 7 failures before this pass's patches; six were pins on the code count, roster and pair expectations the new code legitimately changed (updated: code count 31 to 32 in four classes, MappingDescriptor classic roster, ToolEmit pair expectation) and one (WireSecurityRead) is environmental, deferred above.

### 2026-10-08 -- Review pass (rework 1)

- verdicts: 4 findings -- high 0, medium 0, low 3, false 1, maybe-false 0
- findings:
  - `[low]` `reject` `RevokeAll` has no test that depends on it (the `%DeleteId` sweep removes the rows anyway) -- test-only helper; the sweep is the load-bearing half and carries the recorded mutation; a revoke-only leg is added complexity for no user-reachable harm.
  - `[low]` `reject` `RevokeAll` swallows errors and always returns OK -- same helper; a failed revoke shows in the final privilege count that every teardown asserts.
  - `[false]` `reject` revoke reads the product's LIST, not `Security.SQLPrivileges`, so it cannot see the table EXECUTE row -- the sweep reads `Security.SQLPrivileges` in `%SYS` and clears it; `TestTheProbeCleanupLeavesNoPrivilegeRow` proves it.
  - `[low]` `reject` assertions only in one new test -- `Remaining()` now counts privilege rows and SqlPrivilegeRead, Write and Gate teardowns assert it is 0.

## Design Notes

**Governing ADs:** AD-2, AD-3, AD-5, AD-8, AD-10, AD-13, AD-14, AD-22, AD-27, AD-29, AD-34, AD-36, AD-39, AD-44, AD-51, AD-52, AD-58, AD-59; AD-15/AD-53 need no named case (the vendor audits grants and revokes, `UserChange`/`RoleChange`).

**Measured at plan** (`ocupilot-ci`, 2026-10-07, `/api/admin/v2` as `_SYSTEM`; extends `split-18-9-sql-privileges-2026-10-07.md`):

- Rows: `GrantOption` boolean; `Object` canonical in any case sent; `%ALTER` as sent; a `withGrant` re-grant upgrades `GrantOption`; a role's grant lists on its holder as `Role:<role>`.
- Schemas: a grant lists `Schema Privilege` rows per table and view (`SELECT`) or procedure (`EXECUTE`); schema `USE` listed a foreign server with action `l`; a privilege held directly and through a role lists twice; `HEAD` answered 404 for a held schema grant (unused).
- An `%All` holder lists only `SuperUser` rows (126 in USER); a direct grant to one was stored, not listed, so it cannot be read back (hence `.SUPERUSER`).
- A principal with `%Admin_Secure:U`, `%DB_USER:R` and no SQL privilege: a revoke without `asGrantor` answered 200 and left the row; with `asGrantor=_SYSTEM` it removed `_SYSTEM`'s table and schema grants; its grant answered 500 #5035 `[..,"-112",..]`. Validation faults are 500 #5540 `[SQLCODE, message]`.
- No namespace here has distinct routines and globals databases. End state S0, after `$SYSTEM.SQL.Statement.Clean()` in USER.

**Task 0 record** (`ocupilot-ci`, 2026-10-08, S0 first: no `OcuSqlPrivProbe*` or `OcuProbe189*` object or principal, monitor 0; through `AdminPort.Invoke`, the vendor status read by a capturing subclass):

- A `GRANT` naming an absent table answered 500; the vendor status is #5540 with parameters `-30`, `Table or view not found`; the fault `INTERNAL`; one severity-2 line (`adminport`, "failed with HTTP 500").
- The same `GRANT` as `OcuProbe188H` (`%Admin_Secure:U`, `%DB_IRISSYS:R`, `%DB_USER:R`, no SQL privilege) answered 500; the status is #5035 with parameters `GrantObjPriv Error`, `-112`, `SQL Error Code`; one severity-2 line.
- The other refusals, all 500 at #5540 with the SQLCODE first: `-118` an unknown grantee, `-473` an absent schema, `-428` an absent procedure, `-187` an absent ML configuration, `-30` an absent view or a one-part table name, `-60` an unknown action. An absent foreign server answers #5002 `<SUBSCRIPT>` (deferred above), and an unknown namespace #5002 `<NAMESPACE>`. A grant of `EXECUTE` on a table answered 200 and stored a row the list never shows (DW-2201).
- The monitor read 2 after these; `$SYSTEM.Monitor.Clear()` returned it to 0, and the end state is S0. No contradiction with Measured at plan.

**Found while building:**

- A privilege has one grantor: a second account's grant of the same privilege on the same object replaces the row's `GrantedBy`, so the per-grantor revoke loop is exercised against a seam that lists several (`SqlPrivilegeSeamPort.ArmRows`), and against the real instance for a row another account granted.
- The screen route read the fresh state before it checked the tool's argument pairs, so a caller without READ on the namespace's database reached the port first. `Api/ScreenAction.cls` `Run` now gates a `READSVALUES` tool on the values it takes, using the early delta, before the fresh read; a value set the tool refuses is still refused after the gate, as before.
- User ids are lower-cased (AD-13), so the grantee the port sends is the lower-case name; the instance matches it in any case.
- The tools declare `COMPOSEDTYPES` on the port for the four pairs, which `Test.Prohibited` reads to admit the arguments a composed write carries.

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

Observed on `ocupilot-ci`, each applied one at a time, the tree recompiled, then reverted byte-identical (`cmp`):

- mutation: the read drops `GrantedVia` from the descriptor's fields -> `SqlPrivilegeRead` four-kinds and same-rows legs red (run 1839)
- mutation: the port's revoke sends no `asGrantor` -> `SqlPrivilegeWrite` `TestARevokeNamesEveryGrantor` red: the wire revoke of a row another account granted answers `SQLPRIV.NOTAPPLIED` (run 1834)
- mutation: `Grant` judges `tApplied` 1 with no second read -> `SqlPrivilegeWrite` `TestAWriteThatMovedNothingIsRefusedAsNotApplied` red (run 1835)
- mutation: the guard's namespace check is `If 0` -> `SqlPrivilegeRead` guard leg (404 `SQLPRIV.NAMESPACE`) and no-namespace read leg red (run 1836)
- mutation: `Prohibited.SqlPrivilege` skips `IsOcuPilotCode` -> `SqlPrivilegeWrite` own-schema leg red on the route and the confirm (run 1837)
- mutation: `permissions.users.revokesql` `false` in the baseline -> `SqlPrivilegeDescriptor` baseline leg red (run 1838)
- mutation: `revoke-sql` out of `UserSqlRevoke.SCREENVALUES` -> `SqlPrivilegeWrite` round-trip legs red, the wire answering 400 `TOOL.ARGUMENTS` (run 1840)
- mutation: `ScreenAction.Run`'s early gate `If 0 &&` -> `SqlPrivilegeGate` TestWithoutTheNamespaceDatabaseReadEveryCallIsRefused red (run 2365)
- mutation: `SqlPrivilege` own-role test `If 0 ||` -> `SqlPrivilegeWrite` TestOcuPilotsOwnSchemaAndRolesAreRefusedOnBothCallers red (run 2366)
- mutation: `IsSqlPrivilegeTool` keyed on the write type -> `TokenRevoke` TestTheSqlPrivilegeArmDoesNotJudgeATokenRevoke red (run 2367)
- mutation: store drops the `generation` check -> `sql-privileges-tab.store.spec.ts` overlap leg red
- mutation: Revoke drawn on a non-`Direct` row, and `onRevoke` sending `grant-sql` -> `sql-privileges-tab.spec.ts` red; the Direct-row Revoke removed (bundle rebuilt and redeployed) -> `permissions-sql-privileges.browser-spec.mjs` red, then green again on the reverted bundle
- mutation: `-112` removed from `AdminPort.SQLCODEFAULTS` -> `SqlPrivilegeDescriptor` TestTheAdminPortAdmitsTheWritesAndMapsTheCodes red (run 2374) (QA)
- mutation: the role-row count drops its `Direct` filter (`tVia '= tViaWanted` line removed in `SqlPrivilegePort`) -> `SqlPrivilegeRead` TestTheStateReadComposesTheDirectRows red (run 2375) (QA)
- mutation: `SqlPrivilegeWrite.ArgumentPairs` returns no pairs -> `SqlPrivilegeGate` TestWithoutTheNamespaceDatabaseReadEveryCallIsRefused red (run 2376) (QA)
- the guard's namespace check is covered by the recorded run 1836 (`SqlPrivilegeRead` guard leg); each mutation above reverted with `git checkout`, tree clean, `ocupilot-ci` reloaded (QA)
- mutation: `SqlPrivilegePort.Violations` namespace check `If 0 &&` -> `SqlPrivilegeWrite` TestTheRulesAreRefusedOnBothCallersBeforeAnythingIsSent red, the route answering the guard's 404 (run 2377) (CR)
- mutation: `Facts` counts a schema's `Direct` rows -> `SqlPrivilegeWrite` TestASchemaGrantIsJudgedByItsRows red, the wire grant `NOTAPPLIED` (run 2378) (CR)
- mutation: `Facts` lists with `includeSystem` 0 -> `SqlPrivilegeWrite` TestAWriteThatMovedNothingIsRefusedAsNotApplied red (run 2379) (CR)
- mutation: `SqlPrivilegeWrite.PrivilegePairs` answers none -> `SqlPrivilegeGate` TestWithoutSecuritysResourceEveryCallIsRefused red (run 2380) (CR)
- mutation: `-126` out of `AdminPort.SQLCODEFAULTS` -> `SqlPrivilegeDescriptor` TestTheAdminPortAdmitsTheWritesAndMapsTheCodes red (run 2381) (CR)
- mutation: `setNamespace` keeps the rows -> `sql-privileges-tab.store.spec.ts` namespace-change leg red; `onSubmit` keeps the dialog open on a refusal naming no field -> `sql-privileges-tab.spec.ts` banner leg red (CR)
- each reverted byte-identical (`cmp`); after loading the patched tree, `SqlPrivilegeDescriptor` 10/10, `SqlPrivilegeRead` 4/4, `SqlPrivilegeGate` 3/3 and `SqlPrivilegeWrite` 8/8 passed (runs 2382-2385, `%UnitTest_Result`); the two client specs passed 15/15 (CR)
- mutation: `SqlPrivilegeProbe.RemoveAll`'s privilege-row sweep selects nothing (`While 0 &&`) -> `SqlPrivilegeRead` TestTheProbeCleanupLeavesNoPrivilegeRow red (run 2400, `ocupilot-ci`); reverted byte-identical (`cmp`), throwaway reloaded and at zero probe rows (rework 1)
- mutation: the two editor specs' expected tab lists lose `SQL privileges` -> `users-editor` and `roles-editor` browser specs red against the redeployed bundle (rework 1)
- mutation: `SqlPrivilegeProbe.RevokeAll` sends `%ALTER` unchanged -> `SqlPrivilegeRead` TestTheProbeCleanupLeavesNoPrivilegeRow red at "and takes the two listed rows" (run 2402); reverted byte-identical (`cmp`), reloaded, green (run 2403) (CR rework 1)
- the sweep mutation of run 2400 also reddened `SqlPrivilegeRead` `OnAfterOneTest` "and none is left" in three tests (`%UnitTest_Result`): the teardown count is load-bearing (CR rework 1)
- after the review patches: `SqlPrivilegeRead` 5/5 (run 2403), `SqlPrivilegeGate` 3/3 (2404), `SqlPrivilegeWrite` 8/8 (2405); `users-editor` 8/8, `roles-editor` 8/8, `permissions-sql-privileges` 2/2 on a rebuilt, redeployed bundle; `ocupilot-ci` at S0 (CR rework 1)

## Auto Run Result

Status: done
Blocking condition: none

**Change.** SQL privileges for users and roles: an unlisted `SqlPrivilegeList` read, a "SQL privileges" tab and dialog on both editors, four grant and revoke tools on a new `SqlPrivilegePort` (state read, one action, re-read, `NOTAPPLIED`), the `AdminPort` guard, and the AD-10 arm (`OCUPILOTSQLPRIVILEGE`, `OCUPILOTROLE` for SQL grantees). `ScreenAction.Run` gains an early pair gate for `READSVALUES` tools.

**Review.** 10 findings: 1 medium patched (the arm was keyed on the write type and caught the token revoke; now keyed on the port class), 3 low patched (mutation lines, an overlap spec), 2 deferred, 3 rejected. Follow-up review recommended: false.

**Verification.** Full ObjectScript sweep on `ocupilot-ci`: 511 classes, 4090 tests; 7 failed before patches. Six were pins the new code legitimately moved (code count 32, classic roster, ToolEmit pairs) and are updated and green; `WireSecurityRead` TestTaskHistoryPairSetsAreEnforcedForARealPrincipal still reads a truncated task history on the 27-hour-old throwaway (environmental, deferred). Story classes, `ProhibitedRoute`, `TokenRevoke` green after patches (runs 2368-2373). Client: store spec 6 pass, tools 1884 pass, components 2649 pass, three browser specs pass (subagent pass). Smoke 50/50. Bundle initial 3.13 MB (under the 3165 kB warning). Throwaway at S0 (no probes, monitor cleared to 0).

**Residual risk.** `Api/ScreenAction.cls` edit touches every `READSVALUES` tool; the sweep covers them.

### Rework 1 (2026-10-08, triggers ci, smoke)

**Change.** The users and roles editor browser specs expect `SQL privileges` as the last tab; `SqlPrivilegeProbe.RemoveAll` revokes the probe principals' direct privileges in `USER` and the install namespace, then sweeps any `Security.SQLPrivileges` row of a probe grantee; `Remaining` counts those rows; new `SqlPrivilegeRead.TestTheProbeCleanupLeavesNoPrivilegeRow`. The orphan row on `ocupilot-ci` is removed; the EXECUTE-on-table vendor quirk is in `deferred:` (decision pending).

**Verification.** `users-editor` 8/8, `roles-editor` 8/8, `permissions-sql-privileges` 2/2 on a rebuilt bundle; each SQL privilege class run twice, green, zero probe rows after each; tools 1884, build, lint-docs, check-objectscript green. Review: 4 findings, 3 low and 1 false rejected, 0 patched. Follow-up review recommended: false.
