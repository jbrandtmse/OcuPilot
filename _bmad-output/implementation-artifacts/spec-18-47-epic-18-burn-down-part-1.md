---
title: 'Story 18.47: Epic 18 burn-down, part 1 (grants, providers, the shell, the monitor)'
type: 'bugfix'
created: '2026-10-14'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-18-context.md'
warnings: ['multiple-goals', 'oversized']
deferred:
  - summary: 'Sweep (DW-2327): two-argument %GetNext over caller JSON answers 500 past MAXSTRING/MAXNUMBER; route key loops through one typed helper beside Kernel.Utils.ReadRequestBody, add .tType at nested loops, check untyped %Get.'
    evidence: 'Story 18.47 plan audit 2026-10-14 (code read): 109 sites in 54 Area files; Screen/Tool about 14, Api 11, Kernel 20-25 (inference).'
    location: 'src/OcuPilot/Area/**/*.cls'
    severity: low
---

<intent-contract>

## Intent

**Problem:** Epic 18 routed twelve defects here: DW-2007, 2149, 2167, 2311, 2320, 2322, 2327, 2328, 2329, 2333, 2340 and 2400. Each one's `ledger.sh show` rulings set its fix.

**Approach:** Fix each where its ruling places it, extending the named sibling, with one pinning test and one mutation per entry. DW-2327's audit found 109 sites, so it fixes none and charters one sweep entry (`deferred`).

## Boundaries & Constraints

**Always:**

- A refusal's sentence is the server's (AD-39).
- No new Fixed-strings key and no new `Api/Error` code. The literal count is the tree's union total, 3,388 at plan.
- Rule 11: Epic 20's files take add-only edits, except the pre-authorized `Kernel/Proposal/Prohibited.cls` (DW-2320/2322), `table-model.ts` and `data-table.ts`, and the union asks under For the lead.
- A test creates and removes what it asserts on, and restores `OcuPilotProvider` on every path.

**Never:**

- The `%GetNext` sweep, `MgmntPort.Applications`, a call-time `CipherList` judgment, or a hand edit of `screens.generated.ts`.
- `Security.Superserver` #5001 unlogged: it is `$$$GeneralError`, so unlogging it would silence every unmapped fault.

## I/O & Edge-Case Matrix

| Entry | State | Behavior | Edge |
|---|---|---|---|
| DW-2320 | app holds `{MatchRole: %Developer, TargetRoles: [%All]}` | moving `%All` to another MatchRole (`''` included) mints destructive, naming the grant | the same pairs re-sent: ordinary |
| DW-2322 | routine app granting a privileged role | clearing its Resource or enabling it mints `GRANT.PRIVILEGED`; the form shows the line | unprivileged roles: ordinary |
| DW-2333 | web app with MatchRoles | `webapp.webapproles.read` answers a row per entry; the list less one, sent by `webapp.list.update`, removes only that entry | empty or absent: no rows; no name: 400 `READ.CRITERION` |
| DW-2311 | service reached by a Forward chain or another namespace's app | delete refused 409 `RESTSERVICE.DEPLOYED` at mint and confirm; kept | unenterable namespace: 403; undeployed: deleted |
| DW-2167 | read answered 404 with #822 | 403 `PORT.ACCESSDENIED`, logged | 404 without it: `PORT.NOTFOUND`, unlogged |
| DW-2007 | #1454 data-server Save; #5809 MFT delete; SQLCODE-mapped refusal | answered, no log line | another code, same endpoint/type/status: logged |
| DW-2400 | `OcuPilotProvider` or the egress-named configuration | a `CipherList` or `TLSMinVersion` change refused with the arm's sentence | floor below TLS 1.2 set in `%SYS`: the call sends nothing |
| DW-2328 | keys repeat or are empty | a click selects one row; ArrowDown walks every row | actions get the entity key |
| DW-2329 | label ending in an unescaped backslash | the row reads | a line no form reads: skipped, counted, 200 |
| DW-2340 | drill-down to a refused screen | listed, `aria-disabled`, names its reason, goes nowhere (EXPERIENCE.md :214-216) | -- |
| DW-2149 | the five probes | `Snapshot` holds no monitor state | -- |
| DW-2327 | 109 caller-JSON sites | unchanged; sweep entry chartered | -- |

</intent-contract>

## Code Map

At `45c6bbc0`; paths under `src/OcuPilot/` or `ui/src/app/`.

- **2320, 2322:** `Kernel/Proposal/Prohibited.cls` `GrantsPrivilegeByEffect` :4574 (routine :4634, web :4641, held-skip :4648), `ApplicationRoleNames` :4668, `ClearsResource` :5540, loop :5954-5965, `RoleEscalates` :4390; `Area/WebApp/DocDbAppRules.cls:112`; `areas/web-applications/routine-app-form.page.ts:180`, `routine-app-member-tabs.ts:527`.
- **2333:** `Screen/Descriptor/RoutineAppRoleList.cls`; `Screen/Tool/WebAppUpdate.cls:33`; rosters `Test/StageTwoTools.cls:96`, `SurfaceCoverage.cls:219`, `Descriptor.cls:185`, `ReadTool.cls:93-94`, `ToolRoundTrip.cls:93`, `Wire.cls:534`, `WireSecurityRead.cls:851,1002,1031`, `ui/tools/screen-mirror.test.mjs:1425`, `navigation.test.mjs:273`.
- **2311:** `Port/MgmntPort.cls:473`; `Kernel/Shell/Namespaces.cls:50`; `Port/AdminPort.cls:3732`; `Test/MgmntPort.cls:499,664`, `RestServiceWrite.cls:226`, `RestServiceProbe.cls:168`.
- **2167, 2007:** `Port/AdminPort.cls` :635, :1487, :2810, :3505-3531; `Test/EndpointFixture.cls:174`, `EcpProbe.cls:1004`.
- **2400:** `Prohibited.cls:239-262`, :5662; `Screen/Tool/SslUpdate.cls:154`; `Install/Installer.cls:3225-3296`; `Kernel/State/Base.cls:873`; `Port/ProviderPort.cls:647`; `Kernel/Provider/Base.cls:809`; `areas/security/ssl-form.store.ts:92`.
- **2328:** `core/table-model.ts:40`; `shell/data-table.ts` :681-695, :1089, :1663-1671, :1848-1862, :1888; readers `shell/screen-action-handler.ts:1550`, `command-bar.ts:478`, `command-box.ts:543`.
- **2329:** `Port/MonitorPort.cls` :205, :395-502; `Test/MonitorPort.cls` :216, :233, :342.
- **2340:** `areas/os-management/dashboard.page.ts` :109, :329-344; `shell/side-bar.ts:165-182`.
- **2149:** `Test/EcpProbe.cls:952`, `EncryptionProbe.cls:520`, `JournalProbe.cls:796`, `LicenseProbe.cls:539`, `RemoteDatabaseProbe.cls:683` (as `beffc29d`).

## Tasks & Acceptance

**Task 0** (implement, `ocupilot-ci`, after task 5): with `LicenseProbe.SeedPrincipal(, , "%Admin_Operate:U,%DB_IRISSYS:R")`, `RunAs` a `Security.LDAP` `GET`: expect 403 `PORT.ACCESSDENIED` (18.27: 404); `RemoveAll`; record it in Verification.

**Execution** (each: change; pinning test; mutation for Verification):

1. **DW-2320.** `ApplicationRoleNames` keys both legs `UPPER(MatchRole)_$C(1)_UPPER(target)`. Test: `RoutineAppGrant` `AssertGrants` legs, a web leg via `WebAppWeakening`'s `Mint` seam. Mutation: key by target alone.
2. **DW-2322.** Routine branch: a cleared `Resource` (`ClearsResource`) or `Enabled` turned on (`IsEnabled`'s forms) while a wanted target `RoleEscalates` is a grant; :5954-5965 becomes one shared helper; `routine-app-form.page.ts` shows `privilegedGrantEffect` at either field while a granted role is `privileged()` (as `hasRoutineEffect` judges). Test: `RoutineAppGrant` legs; `routine-app-form.page.spec.ts`. Mutation: drop the arm.
3. **DW-2333.** New `Screen/Descriptor/WebAppRoleList.cls`, `RoutineAppRoleList`'s shape: source `{port: admin, endpoint: "WebApp.App", type: "GET", rows: "MatchRoles"}`, route `web-applications/list/roles`, parentScope `web-applications/list`, id composite `[MatchRole]`, criterion `name` (maxLength 256), `WebAppList`'s pairs and classic page, toolIdentifier `webapp.webapproles`, the `routineAppRoles*` keys. `WebAppUpdate` `DESCRIPTION` adds "Read the current list first with webapp.webapproles.read and send it whole with only your change." Roster rows; `node tools/screen-mirror.mjs`. Test: new `Test/WebAppRolesRead.cls` (`OCUPILOT_ALLOW_PRINCIPALS`, a `ci-throwaway.sh` `# classes:` line): its row, and an integration leg that reads, mints, confirms. Mutation: rows member `Roles`.
4. **DW-2311.** `Resolved` reads `GetWebRESTApps` per `NamespaceNames` name (`^` names skipped): deployed when an app's `dispatchClass` is `<Name>.disp` (any case) or its compiled UrlMap, read in its namespace (AD-16), forwards there through a chain (private `Forwards`, visited set, depth 8). Any namespace's refusal refuses; no UrlMap forwards nowhere. Test: `MgmntPort` CallText pins plus fixture legs (another namespace; a refused one); `RestServiceWrite` with a `RestServiceProbe` router forwarding to the probe service. Mutation: drop the walk, or `pNamespace` only.
5. **DW-2167.** `AdminPort.Fail`: a 404 carrying #822 becomes 403, so `PORT.ACCESSDENIED`, logged. Test: new `Test/AdminPortRefusals.cls`. Mutation: drop the remap.
6. **DW-2007.** An `UNLOGGEDREFUSALS` entry may end `/#<code>`, matched against `$System.Status.GetErrorCodes(pVendorSC)`, which `IsUnloggedRefusal` takes; add `ECP.DataServer/PUT/500/#1454`, `Security.MFT/DELETE/500/#5809`; the SQLCODE-mapped branch (:1487) logs nothing: its codes (#5540, #5035, #516) are named refusals. Test: `AdminPortRefusals` legs; `EcpDataServerWrite.cls:259` writes no `ECP.DataServer failed` line. Mutation: ignore the code.
7. **DW-2400.** `OcuPilotSslFields` and `OWN_FIELDS` add `TLSMinVersion` and `CipherList`; `PROVIDERSSLREASON`, `sslRefusalProviderNamed`, `sslOwnRole` and EXPERIENCE.md :484-485 name them. The installer creates and repairs `TLSMinVersion` 16 and `CipherList` `ALL:!aNULL:!eNULL:!EXP:!SSLv2` and asserts all six. `GuardedSslConfigRead` outputs `TLSMinVersion`; `SslConfigurationState` answers `TLSWEAK` below 16; `TlsReason`: `REASONTLSWEAK` "The TLS configuration <name> allows a protocol older than TLS 1.2, so no request was sent. Clear the name on Switches, or set its minimum TLS version to 1.2 in the classic portal." and `REASONTLSWEAKOWN` "OcuPilot's TLS configuration <name> allows a protocol older than TLS 1.2, so no request was sent. Restart the instance to restore it." Test: `SslSave.cls:281`'s TLSMinVersion-8 leg refused; `SslUpdate.cls:163`, `ProviderSslNamed.cls:142` both fields; `ProviderSslCallTime.cls:62` a floor-8 leg; `ProviderSsl.cls:146,239`; `self-protection.test.mjs`. Mutation: drop the floor check, or `CipherList`.
8. **DW-2328.** `table-model.ts` `viewKeys(rows, declaration)`: the first non-empty key stays `rowKey`; a repeat or empty key gets a private separator and its ordinal, stripped by `entityKeyOf`. `data-table.ts` keys by view key; links keep `rowKey`; the three readers apply `entityKeyOf`. Test: `tools/table-model.test.mjs`; `data-table.spec.ts` (:410 fixture, repeated names: one row selected, ArrowDown walks all, `''` included); a `prometheus-metrics.browser-spec.mjs` leg. Mutation: `viewKeys` returns `rowKey`.
9. **DW-2329.** `LabelsEnd` gains `pLiteral` (a backslash is plain); `Samples` reads strict, then literal; a line neither reads, or with no name or value, is skipped and counted; `Invoke` answers the rest 200 and logs one line naming the count; docs updated. Test: `Test/MonitorPort.cls`: `dir="C:\InterSystems\mgr\"` alone and before another label, the escaped form, the malformed test now 200 with `LogCalls()` 1. Mutation: drop the literal pass.
10. **DW-2340.** `linksFor` judges `openableEntry(screen, r => navigation.screenVerdict(r))` as `side-bar.ts` does; a gated link has no `href`, `tabindex="0"`, `aria-disabled="true"`, `aria-describedby` and an inline `formatRequires` reason; `onDrillDown` returns on it. Test: `dashboard.page.spec.ts`, `mount` taking a verdict map. Mutation: drop the verdict.
11. **DW-2149.** Delete each `Snapshot`'s monitor line and doc mention. Test: new read-only `Test/ProbeSnapshots.cls`. Mutation: restore one line.
12. **Rule 30 sweep.** Grep `src/OcuPilot/Test`, `ui/tools`, `ui/src` specs, `ui/browser` for `OcuPilotSslFields`, `PROVIDERSSLREASON`, `sslRefusalProviderNamed`, `sslOwnRole`, `UNLOGGEDREFUSALS`, `IsUnloggedRefusal`, `GetWebRESTApps(`, `ApplicationRoleNames`, `GuardedSslConfigRead`, `Monitor.State`, `label set is not closed`, `rowKey`, `linksFor`, `webapp.routineapproles`; update each old-shape assertion; every file changed joins `(loop)`.

**Acceptance Criteria:**

- Given each matrix row, when the story is done, then its task's pinning test shows it holding, and its recorded mutation reddens that test.
- Given DW-2327, when the story is done, then its audit and the `deferred` sweep entry close it on evidence, with no `%GetNext` site changed.

- **DW-2400 TLS floor, orchestrator condition (2026-10-14)** [AMENDED 2026-10-14 - see the Spec Change Log]: Task 0 measures `OcuPilotProvider`'s `TLSMinVersion` on `ocupilot-ci` as today's installer creates it (and as an older release's installer did, if the code shows a different create) and the vendor default for a new configuration on 2026.2, recorded under For the lead. The installer's ensure and repair of `OcuPilotProvider` set `TLSMinVersion` to 16 or more at every start, as they repair `VerifyPeer`, so an upgraded instance with a lower stored floor is repaired at start, never refused. An egress-named configuration below 16 (operator-owned, never repaired) is refused with a code whose sentence names what to raise in the classic portal. A test pins the start repair: lower the floor, run the ensure, read 16 or higher (`mutation:` line).

## Spec Change Log

- 2026-10-14, lead: the orchestrator approved the Rule 11 asks and added a condition on DW-2400's TLS floor (the item above `## Spec Change Log`): the installer raises `OcuPilotProvider`'s floor at every start; a named configuration below it is refused with a remedy.

- 2026-10-14, lead spec gate: "For the lead" applied in the spine (AD-2, AD-10, AD-32, AD-36, AD-53); DW-2327 closed `dropped`, superseded by the harvested sweep entry DW-2417 (owner 23.9); the `strings.ts` value edits, `Prohibited.cls`' DW-2400 hunks and the `ReadTool` count went to the orchestrator as the Rule 11 ask.

## Review Triage Log

## Design Notes

**Governing ADs:** AD-2, 5, 8, 10, 16, 27, 29, 32, 36, 39, 44, 53, 64.

**Rule 31.** Extended: tasks 1, 2, 4, 6, 7, 9's symbols. Reused: `NamespaceNames`, `openableEntry`, `LicenseProbe.RunAs`. Copied: `WebAppRoleList` (one descriptor per screen, AD-5); `Forwards` after `DeriveRoutes` (private to another port; sharing would couple two vendor APIs).

**DW-2327 audit** (code read): 190 two-argument sites in 66 Area files; 109 in 54 files read caller JSON ("48" counted files holding the literal `%GetNext(.tKey, .tValue)`). `ReadRequestBody` has no size cap. 109 > about 10.

**Consumes:** 18.11, 18.12, 18.32, 18.34, 18.36, 18.40. **Consumed-by:** none. Integration AC: task 3's leg.

**Measured at plan** (`ocupilot-ci`, after `LOAD-OK`/`STARTPATH-OK`): `WebApp.App` `GET` answers `MatchRoles` as an array (`/csp/user` one entry, `/csp/sys` `[]`), an absent name 404; `%Api.InteropEditors||UrlMap` opens from HSCUSTOM with 8 forwards; `OcuPilotProvider` holds `TLSMinVersion` 16 and the `CipherList` above; a severity-2 line moved `$SYSTEM.Monitor.State()` 0 to 1 in 25-30 s; no test calls the probes' `Snapshot` (code read).

**For the lead** (Rule 20; `[AMENDED 2026-10-14, Story 18.47 spec gate, Rule 20]`):

- **AD-2:** #822 under a 404 is 403, logged; an unlogged entry may name a code; #5809 (MFT `DELETE`) and the SQLCODE-mapped branch unlogged; #5001 stays logged.
- **AD-10:** both SSL arms gain the two fields; roles compare per (MatchRole, target), so narrowing every caller to one MatchRole counts too; a privileged routine app's cleared Resource or enabling is a grant.
- **AD-32:** the installer sets both fields; the call-time check refuses a floor below 16. Named limit: `CipherList` is not judged at call time (no vendor API expands it; TLS 1.3 suites are AEAD only (inference)).
- **AD-36** :812: a sample neither form parses is skipped and counted (owner 2026-10-11). **AD-53** :1169: "deployed" spans every namespace and Forward chains; an unenterable namespace refuses.
- **Rule 11 union asks:** `strings.ts` values `sslOwnRole`, `sslRefusalProviderNamed` (Epic 20 only adds there); `Prohibited.cls`' DW-2400 hunks; the `ReadTool` count 379 to 380. Add-only: the roster rows, the `ci-throwaway.sh` line; EXPERIENCE.md in place.
- **Ledger:** each entry `resolved-by:18-47-epic-18-burn-down-part-1`; DW-2327 `dropped`, superseded by the harvested sweep entry, owned by the standing cleanup story (Rule 27).

## Verification

**Commands** (one run per call, `timeout: 600000`):

- `(loop)` `sh /Users/jbrandt/git/OcuPilot/.worktrees/.coordination/carry-2026-10-08/epic-18-d8/load-ocupilot-ci.sh` prints `LOAD-OK` and `STARTPATH-OK`.
- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.<C>`, one at a time, totals from `%UnitTest_Result`: every class tasks 1-12 name or change, plus `AdminPortFault`, `Fault`, `ReadTool`, `SurfaceCoverage`, `StageTwoTools`, `Descriptor`, `ToolRoundTrip`, `Wire`, `WireSecurityRead`.
- `(loop)` `cd ui && npm run test:tools && npm run test:components`.
- `(loop)` With `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776` and `OCUPILOT_BROWSER_CONTAINER=ocupilot-ci`: `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`, then `node --test --test-concurrency=1 browser/prometheus-metrics.browser-spec.mjs`. Initial bundle under 1992 kB, lazy chunks under 88 kB.
- `uv run scripts/check-objectscript.py` and `bash scripts/lint-docs.sh`: 0 problems.

**Shared surfaces:** the read-tool, surface, round-trip, stage-two and route rosters; the screen mirror; the SSL field lists, sentences and installer properties; `UNLOGGEDREFUSALS`; the REST-service calls; list keys and selection; the metrics contract; the Dashboard links; the probes' snapshots.

every test added or changed passes on a fresh environment, in either order

## Auto Run Result

Status: ready-for-dev
Blocking condition: none
