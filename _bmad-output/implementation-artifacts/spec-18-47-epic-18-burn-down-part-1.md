---
title: 'Story 18.47: Epic 18 burn-down, part 1 (grants, providers, the shell, the monitor)'
type: 'bugfix'
created: '2026-10-14'
status: 'done'
baseline_revision: '59d3a777edc0a64ece89f22c0a616f963be83d50'
baseline_commit: '59d3a777edc0a64ece89f22c0a616f963be83d50'
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
  - summary: 'A turn''s one PROVIDER.TLS sentence names the absent, unverified and unreadable causes but not a TLS floor below 1.2.'
    evidence: 'Story 18.47 implement (code read): TlsReason carries REASONTLSWEAK for the call-time refusal and Test connection; Base.ReasonFor and Error.ReasonForTurnError are unchanged.'
    location: 'src/OcuPilot/Kernel/Provider/Base.cls'
    severity: low
  - summary: 'The page-level selection readers and the checked-set readers outside the table''s three central ones read the view key, which carries an ordinal for a repeated or empty key.'
    evidence: 'Story 18.47 implement and review (inference): no list with these readers repeats or empties its key; recipe is a grep of selection()[0] and checked() under ui/src/app (the checked-set target in screen-action-handler.ts, code-list.page.ts).'
    location: 'ui/src/app/areas/**'
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

### 2026-10-14 - Review pass

- verdicts: 23 findings - high 0, medium 2, low 19, false 2, maybe-false 0
- findings:
  - `[medium]` `[patch]` `ProviderSslCallTime` `Type` leg cannot tell a dropped `Type` check from the new floor check (the leg's server has floor 8, and the weak sentence carries the same three phrases) - the leg now asserts "no longer an enabled client"; mutation recorded (run 771).
  - `[medium]` `[patch]` DW-2328's "actions get the entity key" cell has no test (`entityKeyOf` could be dropped from the three readers with every spec green) - a case in each of `screen-action-handler.spec.ts`, `command-bar.spec.ts`, `command-box.spec.ts`; each mutation red.
  - `[low]` `[patch]` `DeployedAnywhere`'s unreadable-roster and unreadable-dispatch-map paths are untested - `MgmntPort.TestAPartialReadOfTheDeploymentsDeletesNothing` with a `FailNamespaces` seam; both mutations red (runs 772, 773).
  - `[low]` `[reject]` the cycle leg does not isolate the visited set from the depth cap - both guards end the walk with the same answer; only the cost differs, bounded at 8 hops.
  - `[low]` `[patch]` `#5809` is pinned with a synthetic status only - `MftConnectionWrite` asserts `messages.log` gains no `Security.MFT failed` line over the real delete; mutation red (runs 774, 775).
  - `[low]` `[patch]` pinning tests lacking a `mutation:` line (the skip-and-count edge, `TLSMinVersion` in the field list, the installer's `CipherList` repair, the create and read-back arms) - each run and recorded in `## Verification`; the create and read-back arms are unobservable on 2026.2 and recorded so.
  - `[low]` `[reject]` the Dashboard link's `target` substitution is untested - none of the four drill-downs is a tab-group head, so the branch cannot differ from the declared route today (wontfix-theoretical).
  - `[low]` `[patch]` `MftPort`'s class comment still says the vendor's 500 is logged - replaced at its origin.
  - `[low]` `[reject]` the DW-2328 browser leg depends on the instance's metrics - it reads the store's own answer at that moment and fails loudly if no metric repeats three times.
  - `[low]` `[patch]` `ProviderSslCallTime`'s header claimed a mutation outcome this story made false - corrected with the `Type` leg's fix above.
  - `[low]` `[defer]` the checked-set readers (`checkedSetTarget`, `code-list.page.ts`) read view keys - merged into the existing selection-readers entry in `deferred:` (inference: no multi-select list repeats or empties its key).
  - `[low]` `[reject]` DW-2320 confirm-time re-judgment of a moved target is not newly driven - mint and confirm call the one `GrantsPrivilegeByEffect`, which `AssertGrants` pins directly.
  - `[low]` `[reject]` DW-2322 form and kernel answer different questions (a static caption beside a transition judgment) - the spec binds the form to `hasRoutineEffect`'s test ("as `hasRoutineEffect` judges").
  - `[false]` `[reject]` DW-2333 sorts like the sibling DW-2341 reported, so an echoed list reorders - `WebAppUpdate` builds `MatchRoles` as a delta over the fresh read and `ReadBack.Same` compares arrays as multisets, so order cannot report a change.
  - `[low]` `[reject]` DW-2311 confirm-time re-check and the explorer-pairs holder now refused 403 - both follow the orchestrator ruling (an unenterable namespace refuses); `Resolved` is shared by mint and confirm and `RestServiceWrite` drives both.
  - `[low]` `[reject]` DW-2167 pinned through `Fail` with a synthetic status, a write with #822 untested - the real LDAP read is Task 0's record, and the remap is unconditional on type.
  - `[low]` `[reject]` DW-2007 sub-cases at different depths - #5809 now end to end (above), the SQLCODE-mapped branch's removed line is shared by all nine entries, and #5001 stays logged by the Never.
  - `[low]` `[reject]` DW-2400's turn sentence and `CipherList` limit - the turn sentence is the `deferred:` entry already filed, the `CipherList` limit is the contract's Never.
  - `[low]` `[reject]` DW-2328's other `selection()[0]` readers - carried from the `deferred:` entry; the edge cell is patched above.
  - `[low]` `[reject]` DW-2329 answers 200 for every unreadable line, not only the backslash case - the spec's amended AD-36 (owner 2026-10-11) says so.
  - `[low]` `[reject]` DW-2340 stubs the verdict and omits the focus tooltip - the task binds the inline reason "as `side-bar.ts` does", and the verdict source is the side bar's.
  - `[low]` `[reject]` DW-2149 is static - the task is to delete the monitor lines, and `ProbeSnapshots` pins their absence.
  - `[false]` `[reject]` content beyond the contract and Rule 11 lines not determinable from the diff - the installer, floor constant and new classes are the spec's tasks and condition; Epic 20's own changes overlap seven files, all add-only or approved, and `screen-mirror.mjs --check` passes on `screens.generated.ts`.

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
- **Task 0, TLS floor (`ocupilot-ci`, 2026-10-14):** `OcuPilotProvider` holds `TLSMinVersion` 16 and `TLSMaxVersion` 32, created by an installer that sets neither, so it is the vendor default; no release's installer set either (`git log -S TLSMinVersion` finds no commit touching `Installer.cls`). A new configuration on 2026.2 reads `TLSMinVersion` 16, `TLSMaxVersion` 32, `CipherList` `ALL:!aNULL:!eNULL:!EXP:!SSLv2` and `VerifyPeer` 0. The vendor's initial floor is 8 where `$$$IsOpenSSL10` (read in `Security/SSLConfigs.cls`, inference for an older host), so an upgraded or older-host instance is repaired at start.

## Verification

**Commands** (one run per call, `timeout: 600000`):

- `(loop)` `sh /Users/jbrandt/git/OcuPilot/.worktrees/.coordination/carry-2026-10-08/epic-18-d8/load-ocupilot-ci.sh` prints `LOAD-OK` and `STARTPATH-OK`.
- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.<C>`, one at a time, totals from `%UnitTest_Result`: every class tasks 1-12 name or change, plus `AdminPortFault`, `Fault`, `ReadTool`, `SurfaceCoverage`, `StageTwoTools`, `Descriptor`, `ToolRoundTrip`, `Wire`, `WireSecurityRead`.
- `(loop)` `cd ui && npm run test:tools && npm run test:components`.
- `(loop)` With `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776` and `OCUPILOT_BROWSER_CONTAINER=ocupilot-ci`: `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`, then `node --test --test-concurrency=1 browser/prometheus-metrics.browser-spec.mjs`. Initial bundle under 1992 kB, lazy chunks under 88 kB.
- `uv run scripts/check-objectscript.py` and `bash scripts/lint-docs.sh`: 0 problems.

**Shared surfaces:** the read-tool, surface, round-trip, stage-two and route rosters; the screen mirror; the SSL field lists, sentences and installer properties; `UNLOGGEDREFUSALS`; the REST-service calls; list keys and selection; the metrics contract; the Dashboard links; the probes' snapshots.

**Task 0, LDAP (`ocupilot-ci`):** `SeedPrincipal(,, "%Admin_Operate:U,%DB_IRISSYS:R")` then `RunAs` a `Security.LDAP` `GET` answered 403 `PORT.ACCESSDENIED` (18.27: 404 over #822); `RemoveAll` left 0.

**Run on `ocupilot-ci` (`%UnitTest_Result`, each class one at a time):** `RoutineAppGrant` 5, `WebAppWeakening` 7, `WebAppRolesRead` 2, `MgmntPort` 18, `RestServiceWrite` 13, `RestServiceGate` 3, `AdminPortRefusals` 3, `EcpDataServerWrite` 11, `ProviderSsl` 8, `ProviderSslCallTime` 3, `SslSave` 8, `SslUpdate` 7, `ProviderSslNamed` 5, `ProviderSslCallers` 5, `MonitorPort` 15, `MetricsDescriptor` 6, `ProbeSnapshots` 1; Rule 30: `ReadTool` 28, `SurfaceCoverage` 4, `StageTwoTools` 4, `Descriptor` 60, `ToolRoundTrip` 2, `Wire` 20, `WireSecurityRead` 25, `ToolEmit` 11, `Navigation` 14, `Fault` 6, `AdminPortFault` 26, `AdminPortAbsence` 3, `Installer` 27, `IdentityInstall` 6, `SslReadInstall` 4, `Prohibited` 15, `ToolWrite` 34, `MgmntPortDenial` 2, `MgmntPortWire` 8, `PortCapture` 1, `PortGate` 4, `RestServiceSave` 8, `RestServiceDescriptor` 8, `RestServiceReadBack` 1, `Dashboard` 6, `DashboardDrillDown` 6, `MetricsGate` 3, `RoutineAppListsRead` 2, `RoutineAppGate` 6, `RoutineAppRead` 4, `RoutineAppMembers` 7, `RoutineAppWrite` 15, `RoutineAppWebAppGuard` 2, `WebAppSave` 7, `WebAppWire` 6, `EcpSslConnectionWrite` 6, `ScreenRead` 30, `MftConnectionWrite` 9, `SqlPrivilegeWrite` 8, `SqlColumnPrivilegeWrite` 6, `SqlAdminPrivilegeWrite` 5, `LicenseDescriptor` 8, `LockRemoveTools` 13, `SuperserverWrite` 9, `EndpointCoverage` 2: all green, 0 failed. Client: `npm run test:tools` 1990 pass, `npm run test:components` 245 files and 3103 tests pass, `npm run build` clean (initial total 1.92 MB, largest lazy chunk 83.32 kB), browser specs `prometheus-metrics` 5, `dashboard-drill-downs` 5, `data-table` 9, `ssl-editor` 7, `routine-applications` 4 pass; `check-objectscript.py` and `lint-docs.sh` 0 problems.

**Mutations (Rule 19), each applied on `ocupilot-ci` with the class and its descendants recompiled (client: rebuilt and redeployed), observed red, reverted:**

- mutation: DW-2320 `ApplicationRoleNames` keyed by the target alone -> `RoutineAppGrant.TestAHeldPrivilegedTargetMovedToAnotherMatchingRoleIsAGrant` (5 asserts) and `WebAppWeakening.TestAHeldPrivilegedTargetMovedToAnotherMatchingRoleIsAGrant` red.
- mutation: DW-2322 `WidensPrivilegedReach` call dropped -> `RoutineAppGrant.TestClearingTheResourceOrEnablingUnderAPrivilegedRoleIsAGrant` (6 asserts) red; `hasReachEffect` answering false -> `routine-app-form.page.spec.ts` "Story 18.47, DW-2322" red.
- mutation: DW-2333 `read.rows` `Roles` -> `WebAppRolesRead` both tests red.
- mutation: DW-2311 `DeployedAnywhere` reading `pNamespace` alone -> `MgmntPort.TestADeploymentInAnotherNamespaceRefusesTheDelete`, `RestServiceWrite.TestAServiceReachedThroughForwardRoutesIsRefused` and `RestServiceGate.TestTheDeclaredPairsCreateAndDelete` red; `ReachesDispatch` call dropped -> the router legs of `RestServiceWrite` red.
- mutation: DW-2167 `Fail`'s #822 remap dropped -> `AdminPortRefusals.TestAnAccessDeniedUnderA404IsARefusalAndLogged` red.
- mutation: DW-2007 the code ignored in `IsUnloggedRefusal` -> `AdminPortRefusals.TestACodeScopedEntryUnlogsItsCodeAlone` (4 asserts) red; the `#1454` entry deleted -> `EcpDataServerWrite.TestSslWithoutTheClientConfigurationIsRefusedOnItsField` red; the SQLCODE branch's `LogFault` restored -> `AdminPortRefusals.TestASqlCodeMappedRefusalLogsNothing` red.
- mutation: DW-2400 the floor comparison dropped from `SslConfigurationState` -> `ProviderSslCallTime` floor legs red; `CipherList` dropped from `OcuPilotSslFields` -> `SslSave`, `SslUpdate` and `ProviderSslNamed` red; the installer's `TLSMinVersion` repair deleted -> `ProviderSsl.TestInstallRaisesALoweredFloorAndKeepsAHigherOne` and `TestInstallRepairsADriftedConfiguration` red; its `TLSMaxVersion` branch deleted -> the first red (vendor #899); client `OWN_FIELDS` without `CipherList` -> `ssl-form.page.spec.ts` AC3 red.
- mutation: DW-2328 `viewKeys` answering `rowKey` -> `table-model.test.mjs`, `data-table.spec.ts` and `prometheus-metrics.browser-spec.mjs` (rebuilt, redeployed) red.
- mutation: DW-2329 the literal pass dropped -> `MonitorPort.TestAValueEndingInAnUnescapedBackslashReads` red.
- mutation: DW-2340 the verdict dropped from `linksFor` -> `dashboard.page.spec.ts` "Story 18.47, DW-2340" red.
- mutation: DW-2149 one monitor line restored (`LicenseProbe`) -> `ProbeSnapshots.TestNoSnapshotHoldsTheMonitorState` red.
- mutation (review pass): DW-2400 the `Type` condition dropped from `SslConfigurationState` -> `ProviderSslCallTime` (the `Type` leg's "no longer an enabled client" sentence; run 771).
- mutation (review pass): DW-2311 an unreadable namespace roster continued with an empty one -> `MgmntPort.TestAPartialReadOfTheDeploymentsDeletesNothing` first leg (run 772); an unreadable dispatch map continued with no targets -> its second leg (run 773).
- mutation (review pass): DW-2007 `Security.MFT/DELETE/500/#5809` dropped from `UNLOGGEDREFUSALS` -> `MftConnectionWrite.TestADeleteOverAnAbsentClientIsAnsweredAsDeleted` (log leg, run 774) and `AdminPortRefusals` (run 775).
- mutation (review pass): DW-2328 `entityKeyOf` dropped from `screen-action-handler.ts` `selected()`, from `command-bar.ts` and from `command-box.ts` -> the new "Story 18.47, DW-2328" case in each of the three specs.
- mutation (review pass): DW-2329 `pSkipped` left uncounted in `Samples` -> `MonitorPort.TestAnUnreadableSampleIsSkippedAndCounted` and `MetricsDescriptor.TestAMalformedSampleIsSkippedAndAMissingPairFailsTheRead` (runs 776, 777).
- mutation (review pass): DW-2400 `TLSMinVersion` dropped from `OcuPilotSslFields` -> `SslSave`, `SslUpdate` and `ProviderSslNamed` (runs 778-780); the installer's `CipherList` repair arm disabled -> `ProviderSsl.TestInstallRepairsADriftedConfiguration` (run 781).
- Unobservable on 2026.2: the installer's create-time `TLSMinVersion` and `CipherList` lines (the vendor default equals them; `ProviderSsl` stays green without them, run 782, and they matter on a host whose initial floor is 8) and `AssertSslConfiguration`'s two new read-back arms (the vendor refuses or applies a `Modify` before the read, inference).
- After the review patches every class in the Run line above that a patch or mutation touched was rerun green on the restored tree: `ProviderSslCallTime` 3, `MgmntPort` 19, `MftConnectionWrite` 9, `AdminPortRefusals` 3, `MonitorPort` 15, `MetricsDescriptor` 6, `SslSave` 8, `SslUpdate` 7, `ProviderSslNamed` 5, `ProviderSsl` 8, `RestServiceWrite` 13, `RestServiceGate` 3 (runs 783-794); the three shell specs 233 pass.

**Changed behavior pinned in passing:** a REST service delete now reads every namespace the caller can enter, so `RestServiceGate` gives its holder read on each namespace's databases before the delete and asserts the 403 without it; a monitor sample neither reading accepts is skipped, so `MonitorPort` and `MetricsDescriptor` assert 200 with one log line; `ReadTool` counts 380 tools and 61 descriptors with criteria.

every test added or changed passes on a fresh environment, in either order

## Auto Run Result

Status: done
Blocking condition: none

**Change.** Eleven Epic 18 entries fixed, each with a pinning test and a recorded mutation: DW-2320 (grants keyed by matching role and target), DW-2322 (a cleared Resource or enabling is a grant; the form states it), DW-2333 (`webapp.webapproles.read`, the 380th tool), DW-2311 (the deployed check spans every namespace and Forward chains, failing closed), DW-2167 (#822 under a 404 is 403, logged), DW-2007 (code-scoped unlogged refusals; the SQLCODE-mapped branch logs nothing), DW-2400 (`TLSMinVersion` and `CipherList` protected on both SSL arms; the installer creates and repairs both at every start; a floor below TLS 1.2 refuses the call), DW-2328 (unique view keys beside entity keys), DW-2329 (backslash-literal second read; unreadable lines skipped and counted, 200), DW-2340 (gated Dashboard drill-downs), DW-2149 (no monitor line in the five probes' `Snapshot`). DW-2327 changed no `%GetNext` site; its sweep entry is in `deferred:`.

**Files.**

- `src/OcuPilot/Install/Installer.cls`, `Kernel/Provider/Base.cls`, `Kernel/State/Base.cls`, `Port/ProviderPort.cls`, `Kernel/Proposal/Prohibited.cls`, `Screen/Tool/SslUpdate.cls`: DW-2400 and DW-2320/2322.
- `Port/AdminPort.cls`, `Port/MgmntPort.cls`, `Port/MonitorPort.cls`, `Port/MftPort.cls` (comment), `Screen/Descriptor/WebAppRoleList.cls`, `Screen/Tool/WebAppUpdate.cls`: DW-2167/2007, DW-2311, DW-2329, DW-2333.
- `src/OcuPilot/Test/**`: three new classes (`AdminPortRefusals`, `ProbeSnapshots`, `WebAppRolesRead`), changed pinning classes, fixtures, rosters and the five probes' snapshots; `scripts/ci-throwaway.sh`: one `# classes:` line.
- `ui/src/app/**`, `ui/src/styles/_components.scss`, `ui/browser/**`, `ui/tools/**`: DW-2328 (`table-model.ts`, `data-table.ts`, the three readers), DW-2340 (`dashboard.page.ts`), DW-2322 and DW-2400 form lines, `strings.ts` values, the regenerated `screens.generated.ts`, and their specs.
- `EXPERIENCE.md` :484-485: the SSL sentences, in place.

**Review.** Two layers, 23 findings: 2 medium and 5 low patched (the `Type` leg's sentence, the entity-key cell for the three readers, the partial-read and `#5809` log legs, the missing mutation lines, two stale comments), 1 low merged into the existing deferred entry, 13 low and 2 false rejected with reasons in the Review Triage Log. No code under test changed in the patches; each new test went red under its mutation and green again on the restored tree.

**Follow-up review.** Not recommended: the two patched mediums were test additions, each shown red under a mutation, with the touched classes and specs rerun green.

**Verification.** Every class in `## Verification` green on `ocupilot-ci` (the story's run and the lead's rerun of the pinning and sweep classes); `test:tools` 1990, `test:components` 245 files and 3106 tests, `npm run build` clean (initial 1.92 MB, largest lazy chunk 83.32 kB); browser specs `prometheus-metrics` 5, `ssl-editor` 7, `dashboard-drill-downs` 5, plus the story run's `data-table` 9 and `routine-applications` 4; `check-objectscript.py` and `lint-docs.sh` 0 problems; the throwaway reads S0 (no probe-named object, `OcuPilotProvider` at 16 / 32 / the installer cipher list, monitor state 0).

**Residual risks.** A principal holding only the REST explorer's declared pairs is refused 403 on a service delete until it can read every namespace's databases (the ruling for an unenterable namespace). The page-level selection and checked-set readers read view keys (deferred, inference). The turn's one `PROVIDER.TLS` sentence does not name the floor (deferred).
