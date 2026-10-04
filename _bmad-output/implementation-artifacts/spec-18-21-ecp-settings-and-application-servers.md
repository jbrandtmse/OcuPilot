---
title: 'Story 18.21: ECP settings and application servers'
type: 'feature'
created: '2026-10-04'
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

**Problem:** The classic ECP Settings page (`%CSP.UI.Portal.ECP`) and ECP Application Servers page (`%CSP.UI.Portal.ECPAppServers`) are still the only place to read or change how this instance acts as an ECP application server and data server, to see the application servers connected to it, and to authorize, reject or delete their SSL/TLS computer names. The admin API carries all of it: `ECP.Settings` (`GET`, `PUT`, a nested body), `ECP.AppServerList` (`LIST`) and `ECP.AppServerSSLConnection` (`LIST`, `AUTHORIZE`, `REJECT`, `DELETE`). Story 18.20 left one ledger item here: DW-2006, a data server's SSL/TLS stored over a disabled `%ECPClient`.

**Approach:** Append **ECP settings** (position 18, a singleton form-page with one merge tool) and **ECP application servers** (position 19, a two-tab group: a read-only Connections list and an SSL/TLS authorizations list with three action tools) to OS management, reusing 18.20's `EcpPort`, `EcpError`, `ECP.LICENSE` sentence, `EcpProbe` and `EcpSeamPort`. A Task 0 on `ocupilot-b-ci` measures every route first, including which settings leave a pending restart and whether DW-2006 is real. Every instance here runs a Community license, so no test opens an ECP connection, and every success path that needs a pending SSL/TLS request or an enabled `%ECPServer` runs through the seam.

## Boundaries & Constraints

**Always:**

- **Task 0 runs first, on `ocupilot-b-ci` only**, before any descriptor, tool or page (Tasks › Task 0). Probe objects use 18.20's prefix `OCUPROBEECP` (an SSL/TLS name is `CN=OCUPROBEECP<suffix>`). It restores everything it changes, ends with S2 equal to S0 and halts on any contradiction.
- **Configuration only, never a connection.** Nothing sends `ECP.DataServer` `DBLIST`, sends `SERVERACTION` 3 to the vendor, changes `%Service_ECP`, activates a license key or restarts any instance. A probe data server is at TEST-NET-1 (`192.0.2.10`, `192.0.2.11`) with an in-range port. A pending SSL/TLS request exists only after a real SSL/TLS ECP connection, so no test makes one: pending rows come from the seam alone.
- **Screens** (all `%Admin_Manage:USE` and `%DB_IRISSYS:READ`, the classic pages' `RESOURCE`; each carries three prompts and, in its doc comment, the caveat that these screens rely on the admin API's routes alone because the harvested ECP status implementation was never identified):

  | Descriptor | Route | Archetype | Pos | Entity type, id | `classicPage` | `toolIdentifier` |
  | --- | --- | --- | --- | --- | --- | --- |
  | `EcpSettings` | `os-management/ecp-settings` | `form-page` | 18 | `ecp-settings`, singleton | `%CSP.UI.Portal.ECP` | `osmgmt.ecpsettings` |
  | `EcpAppServerTab` | `os-management/ecp-application-servers` | `detail`, tab 1 "Connections" | 19 | none (read-only) | `%CSP.UI.Portal.ECPAppServers` | `osmgmt.ecpappservers` |
  | `EcpSslConnectionTab` | `os-management/ecp-application-servers/ssl` | `detail`, tab 2 "SSL/TLS authorizations" | 0 | `ecp-ssl-connection`, `[SSLComputerName]` | `%CSP.UI.Portal.ECPAppServers` | `osmgmt.ecpsslconnections` |

  - `EcpSettings` also declares `%Admin_Secure:USE` as its own pair (`ownPrivileges`), because the vendor's `GET` calls `Security.System.Get` and answers a caller without it 500 `PORT.ACCESSDENIED` (measured, Story 18.20 Task 0 step 10). Its privileges are ordered `%Admin_Manage:USE`, `%Admin_Secure:USE`, `%DB_IRISSYS:READ`. Its read is `ECP.Settings` `GET` over `AppServerSettings.MaxServers`, `.ClientReconnectDuration`, `.ClientReconnectInterval`, `DataServerSettings.MaxServerConn`, `.ServerTroubleDuration`, `.SSLECPServer`.
  - `EcpAppServerTab` reads `ECP.AppServerList` `LIST` over `ClientName, Status, IPAddress, IPPort` and declares `read.note` with `ecpDataServerStatusCaveat` ("Each status is what the instance reported when this list was read."). It has no action.
  - `EcpSslConnectionTab` reads `ECP.AppServerSSLConnection` `LIST` over `SSLComputerName, ClientIP, Status`. Its row actions are `authorize` and `reject` (self-protection rule `ecp-ssl-pending`) and `delete` (rule `ecp-ssl-authorized`).
- **The settings tool, `osmgmt.ecpsettings.update`** (AD-4, merge), on `EcpPort`:
  - Its arguments are the two objects `AppServerSettings` and `DataServerSettings`. `MergeUpdate` merges each member by member over the fresh `GET`, as `LanguageServerUpdate.MergeCustom` merges `Custom`, and the diff rows read `<Object>.<member>`. The body is the complete nested set unless Task 0 measures a side effect of an unchanged member (Task 0 step 11).
  - **Rules, before any vendor call, on both callers** (the classic page's ranges, which equal `Config.config`, `Config.ECP` and `Security.System`'s `MINVAL`/`MAXVAL`): `MaxServers` and `MaxServerConn` whole numbers 0-254; `ClientReconnectDuration` 10-65535; `ClientReconnectInterval` 1-60; `ServerTroubleDuration` 20-65535; `SSLECPServer` 0, 1 or 2 (Disabled, Enabled, Required). An unknown member or top-level key is refused.
  - **SSL/TLS:** a write whose resulting `SSLECPServer` is 1 or 2 while the `%ECPServer` SSL/TLS configuration is absent or disabled is refused `ECP.SETTINGS.SSLSERVER` on `DataServerSettings.SSLECPServer` before any `PUT`, as the classic page refuses it. `EcpPort` reads `%ECPServer` through `Security.SSLConfig` `GET`, which the screen's own pair permits.
  - **Restart:** a write that changes `MaxServerConn` (and any other member Task 0 measures as leaving a pending restart) carries the consequence `ECP.SETTINGS.RESTART`, "A changed maximum number of application servers takes effect only after the instance restarts.", on the card, after the Save, and as the field's hint. Nothing claims such a change applied.
- **The SSL/TLS authorization tools** (`osmgmt.ecpsslconnections.*`, AD-51, on `EcpPort`, `SENDSBODY` 0, `READTYPE` `LIST`, `READROWKEY` `SSLComputerName`, `READROWKEYEXACT` per Task 0, `PRECONDITIONFIELD` and `FINGERPRINTSUBJECT` `Status`):
  - `authorize` and `reject` require a fresh row reading `Pending`, and `delete` one reading `Authorized`. Any other row is refused in `StateDiff`, on both callers, before anything is sent, because the vendor answers OK for any name. The refusals are "This application server is not waiting for authorization." and "This application server is not authorized.", each published once and pinned equal to its self-protection rule's reason.
  - `authorize` and `reject` are not destructive: the screen confirms each with the warning dialog stating its consequence. `delete` is `DESTRUCTIVE`, through the typed-name dialog (the name is the `SSLComputerName`).
- **Pairs.** Each tool declares its screen's set plus what Task 0 measures (the settings update expects `%DB_IRISSYS:WRITE`, inference from every `Config.*` write in Epics 16 and 18). A missing pair is refused by name before any port call.
- **`CLASSICPAGES`:** none for all four tools: `%CSP.UI.Portal.ECP` performs the settings save and `%CSP.UI.Portal.ECPAppServers` the three SSL/TLS actions, each the declaring descriptor's own page.
- **Governance:** `osmgmt.ecpsettings.update`, `.ecpsslconnections.authorize` and `.reject` `true`; `.ecpsslconnections.delete` `false` (Design Notes › Decision 7).
- **DW-2006** is settled by Task 0 step 8 and then refused or named as a gap (Design Notes › Decision 5).
- **Errors** go in `Api/EcpError.cls` (the `ECP.` dispatch in `Api/Error.cls` already reaches them). `ECP.LICENSE`'s sentence is reused, never restated.
- **Each test class stands alone.** On a fresh stock instance, in any order, it reads the settings it starts from and restores them, removes its own `OCUPROBEECP*` data servers, SSL/TLS names, seeded `%ECPClient`/`%ECPServer` configurations and principals, and asserts no ECP process (job types 31 to 35) runs after it.
- **Contended files are add-only** (Epic 19 is concurrent on slot A); one-line list members and roster counts are unioned by whichever story reaches the feature branch second: `Api/Router.cls`, `Kernel/Governance/Baseline.cls`, `Kernel/Proposal/Prohibited.cls`, `Screen/Tool/Classification.cls`, `scripts/ci-throwaway.sh`, `ui/angular.json`, `ui/src/app/core/strings.ts`, `ui/src/app/core/screen-actions.ts`, EXPERIENCE.md, and the rosters `ReadTool`, `SurfaceCoverage`, `Wire`, `PortGate`, `Governance`, `GovernanceBaseline`, `ToolDispatch`, `ToolEmit`, `ToolRoundTrip`, `ClassicPageGate`, `MappingDescriptor`, `Test/Prohibited.cls`. This story needs no edit to `Screen/Gate.cls`, `navigation.ts` or `command-box.ts`. `screens.generated.ts` and `ToolFields.cls` are regenerated, never hand-merged. EXPERIENCE.md is edited in place and keeps 1006 lines.
- **`strings.ts` holds each value under one key.** Reuse `ecpLicenseRefusal`, `ecpDataServerStatusCaveat`, `taskHistoryColumnStatus` ("Status"), `sslTestPort` ("Port"), `agentGovernanceDisabled` ("Disabled"), `tableColumnEnabled` ("Enabled"), `openApiRequired` ("Required"), `actionSave`, `actionCancel`, `actionDelete` and `tableReadOnlyEmptyNext`.

**Never:**

- No `%Service_ECP` control (the classic page's Enable link stays there), no `%ECPServer` or `%ECPClient` editing, no `DBLIST`, no ECP connection, no restart, no license change, and no test that needs a non-Community license or a real pending SSL/TLS request.
- No auto-refresh on either screen (AD-43's roster is unchanged; the classic Application Servers page refreshes).
- No `%Api.Admin.*` name outside `AdminPort` and its subclasses. No direct `Config.*`, `SYS.*` or `Security.*` call in product code; test-only `%SYS` seeding (`SYS.ECP.AddAuthorizedCN`, `Security.SSLConfigs.Create`, restoring settings) is allowed.
- No spine or epics.md edit in the implement stage. Task 0 records each AD sentence in `## Spec Change Log` for the runner.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
| --- | --- | --- | --- |
| Read settings | Stock throwaway (2, 1200, 5 / 1, 60, 0) | ECP settings and `osmgmt.ecpsettings.read` answer the same six members from one read; the license line shows (`NetworkEnabled()` 0); Enabled and Required are drawn `aria-disabled` with the `%ECPServer` sentence | none |
| Change a setting | `ClientReconnectInterval` 5 to 6 by Save, and by a confirmed proposal; then restored | One `PUT` of the nested body with one diff row `AppServerSettings.ClientReconnectInterval`; read-back `matches`; no ECP process | none |
| Restart setting | `MaxServerConn` 1 to 2, then back to 1 | The page after the Save and the proposal card state `ECP.SETTINGS.RESTART`; the field's hint says so; after the restore no restart is pending (Task 0 step 4) | none |
| Bad values | `MaxServers` 255, -1, 1.5 or "x"; `ClientReconnectDuration` 9; `ClientReconnectInterval` 61; `ServerTroubleDuration` 19; `SSLECPServer` 3; an unknown member; a third top-level key | Refused on the field (or as unexpected) before any vendor call, on both callers | `ECP.SETTINGS.COUNT`, `.RECOVERY`, `.INTERVAL`, `.TROUBLE`, `.SSL.SHAPE`; 400 `PORT.FIELD.UNEXPECTED` / `TOOL.ARGUMENTS` |
| SSL/TLS without `%ECPServer` | `SSLECPServer` 1 with `%ECPServer` absent (stock), and seeded disabled where Task 0 can seed it | Refused on `DataServerSettings.SSLECPServer`; no `PUT` | 422 `ECP.SETTINGS.SSLSERVER` |
| SSL/TLS with `%ECPServer` (seam) | The seam answers `%ECPServer` enabled | The `PUT` carries `SSLECPServer` 1 and is recorded by the seam, never the vendor | none |
| Connections | Community | Both callers answer no rows; the note line shows | none |
| SSL/TLS list | `CN=OCUPROBEECPA` seeded authorized | The tab and `osmgmt.ecpsslconnections.read` answer one `Authorized` row; Authorize and Reject are drawn `aria-disabled` on it with the not-waiting sentence | none |
| Delete | That row, through the typed-name dialog or a confirmed proposal | `DELETE /ecp/application-server-ssl-connection?name=…` is sent; the row leaves the list; read-back `matches` (absent) | none |
| Wrong state | Authorize or Reject on an `Authorized` row; Delete on a `Pending` row (seam) | Refused before anything is sent, on both callers; the list shows the published sentence | 400 `TOOL.ARGUMENTS` with that sentence |
| Authorize / Reject (seam) | The seam lists `CN=OCUPROBEECPP` as `Pending` | One `AUTHORIZE` (or `REJECT`) is recorded and never reaches the vendor; the read-back says nothing was sent | none |
| Absent name | Any SSL/TLS action on a name gone since the read | Refused; nothing is sent | 404 `PORT.NOTFOUND` / target changed |
| Missing pair | Each tool, the Save and the form route without a declared pair | 403 naming the pair, zero port calls; ECP settings listed unavailable without `%Admin_Secure:USE` | `AUTH.NOPRIVILEGE` |
| DW-2006 | A disabled `%ECPClient` seeded; a probe data server at `192.0.2.10` with `SSLConfig` 1 | Per Task 0 step 8 and Decision 5: refused `ECP.DATASERVER.SSLCLIENT` with nothing stored, or the gap named | 422 `ECP.DATASERVER.SSLCLIENT` |

</intent-contract>

## Code Map

**Vendor** (exported read-only at `/tmp/epic-18-d6/186/vendor/`; re-export with `GetTextAsString` if gone):

- `ECP.Settings.cls`: `ResourcesOR` `%Admin_Manage` (:8-11). `GetECPSettings` (:13-37) reads `Config.config`, `Config.ECP` and `Security.System.Get` (the `%Admin_Secure` dependency). `RunPut` (:49-93) sets only the members present and calls, in this order, `Security.System.Modify`, `Config.ECP.Modify`, `Config.config.Modify`, accumulating errors with `$$$ADDSC` (one refused `Modify` does not stop the next: a half-apply), then re-reads with `GetECPSettings`. Template :95-109; `ValidateRequest` :111-123 (shape only, nested validators).
- `ECP.AppServerList.cls`: `Run` (:18-26), `SYS.ECP:ClientList` mapped to `ClientName, Status, IPAddress, IPPort` (`IPPort` a number).
- `ECP.AppServerSSLConnection.cls`: `name` required for every type but `LIST` (:10-15); `TYPEAUTHORIZE` 10, `TYPEREJECT` 11 (:27-29), `Run` override (:31-40, so `AdminPort.ImplementsRead` admits both); `RunList` (:42-62) merges `SSLAuthorizedConnections` (`Status` "Authorized", `ClientIP` "") and `SSLPendingConnections` (`Status` "Pending"); `RunDelete` calls `RemoveAuthorizedCN`, `RunAuthorize`/`RunReject` call `RemoveFromPendingList(name, 1|0)`; each answers OK for any name (:72, :79).
- `irissys/SYS/ECP.cls`: `RemoveFromPendingList` :103, `RemoveAuthorizedCN` :115, `AddAuthorizedCN` :127 (pre-authorizes; the only way to seed a row), `ClientList` statuses :197-210 (Normal, Trouble, Recovering, Restart, DeadCleanup, Invalid), `SSLPendingConnections` :250, `SSLAuthorizedConnections` :271. `SSLComputerName` is a certificate's distinguished name.
- `irissys/Config/config.cls:343-351`: `MaxServerConn` (0-254) needs a restart; `MaxServers` (0-254) does not when shared memory allows. `irissys/Config/ECP.cls:48-58`: the three ranges. `irissys/Security/System.cls:429-432`: `SSLECPServer` 0 None, 1 Accept, 2 Require. `irissys/Config/CPF.cls:54-76`: `PendingRestart(.Reasons)`, the pending-restart probe (test-only).
- Classic `irissys/%CSP/UI/Portal/ECP.cls`: `RESOURCE` :19; fields, hints and the SSL radio (Disabled/Enabled/Required) :64-76; ranges :135-139; the `%ECPServer` check :157-165, :424-428; `%Admin_Secure` gate on SSL :264-289; `SaveData` :338-398 (writes `Config.config` only when changed, restart message :389-391); license sentence :224-227. `irissys/%CSP/UI/Portal/ECPAppServers.cls`: `RESOURCE` :24; the three tables :51-109; confirm texts :115-146; auto-refresh :215-219.

**18.20 reuse** (`src/OcuPilot/`):

- `Port/EcpPort.cls`: `SETTINGSENDPOINT` :37, `LIMITPAIR` :79, `Call` :86 (the seam point), `NetworkEnabled` :93, `Invoke` :102 (dispatch :107-115; new branches go before the fall-through at :115), `Row` :196, `MaxServers` :235, `Put` :256-294 (the `SSLConfig` mapping :285-288, the limit's `HoldsPair` model :272), `Refused` :327, `Snippet` :375-394.
- `Api/EcpError.cls`: codes :15-84 (`REASONLICENSE` :17, `SSLCLIENT` :68), `Codes()` :87, `ViolationCodes()` :94, `FieldOf` :100, `ReasonFor` :113. `Api/Error.cls` already dispatches `ECP.` at :1226 and :1425.
- `Area/OsMgmt/EcpRules.cls` (`HandleForm` :208, `licensed` :226-227, `Gate` :335) and `EcpDataServerSave.cls` (`Gate` :277): the form-route and gate models.
- `Test/EcpProbe.cls`: `PREFIX` :18, `SERVERADDRESS` :21, `SeedServer` :56, `ClientConfigured` :147, `CreateEvents` :178, `SeedPrincipal` :240, `RemoveAll` :271, `EcpJobs` :408, `Run` :492, `RunAs` :525, `Snapshot` :576, `Diff` :659, `LinesAfter` :704. `Test/EcpSeamPort.cls`: `NetworkEnabled` :16, `Call` :22, `Arm` :64, `Clear` :70, `Calls` :76, `Writes` :86. `Test/EcpActionFixture.cls` (`ToolFor` :15), `Test/EcpSaveFixture.cls`, `Test/EcpWriteGateProbe.cls`, `Test/SeamEcp*.cls`: fixture models.
- `Test/SecurityDeleteProbe.cls` `CreateSsl` :46-67, `RemoveSsl` :71-92: the SSL/TLS seeding model (marker in the description).

**Ports and routes:**

- `Port/AdminPort.cls`: `MUTATINGTYPES` :435 (doc :125-434), `BODYLESSTYPES` :451, `UNLOGGEDREFUSALS` :574, `QUEUEDWRITES` :727, `PROPERTYFAULTS` :3179 (ECP entries at its tail), `HoldsPair` :1501, `EndpointType` :2743 (a suffix resolves only through `TYPESUFFIXES` or a `MUTATINGTYPES` pair), `ImplementsRead` :2780. None of `ECP.Settings/PUT`, `ECP.AppServerSSLConnection/AUTHORIZE`, `/REJECT`, `/DELETE` is registered yet (501 today). `Test/PortFixture.cls:21` copies `MUTATINGTYPES`. `Test/AdminInventory.cls:53-56`: all three classes `async="0"`, so nothing queues.
- `Port/AdminRoutes.cls:105-107, 111`: `POST /ecp/application-server-ssl-connection/authorize`, `DELETE /ecp/application-server-ssl-connection`, `POST …/reject`, `PUT /ecp/settings` (non-GET routes only).
- `Port/JournalPort.cls` `Settings` :273-282 drops the identifying query on a singleton `GET`: `EcpPort`'s `ECP.Settings` branch does the same.

**Models:**

- Singleton editor (Story 18.18): `Screen/Descriptor/JournalSettings.cls` (privileges :27, `ownPrivileges` :28, id :34, read :47-53); `Screen/Tool/JournalSettingsUpdate.cls` (`EXTRAPAIRS` :56, `SettableFields` :76-79, `InputSchema` :95-124, `MergeUpdate` :130-140, `ArgumentProblem` :144, `Consequence` :189-195, `PrivilegePairs` :201-214); `Area/OsMgmt/JournalSave.cls` (`TargetId` :39-42, `Update` order :91-137, `PortViolations` :146-158, `Gate` :234-255); `Area/OsMgmt/JournalRules.cls` (`Validate` :54-83, `Problem` :89-103).
- Nested member merge (Story 16.25): `Screen/Tool/LanguageServerUpdate.cls` `SettableFields` :95-98, `MergeUpdate` :139-192, `MergeCustom` :199-252 (rows `Custom.<member>` :215, :239-243). Facts it rests on: `Kernel/Proposal/Mint.cls` `Merge` :537-603 is top-level only (a dotted settable name is refused at :556-558); `Screen/Tool/Write.cls` `FieldRows` :727 skips dotted rows, so `AdmittedFields()` is empty for `ECP.Settings`; `Kernel/Proposal/Fingerprint.cls` `Canonical` :106-140 recurses; `Kernel/Proposal/ReadBack.cls` `Compared` :246-289 keys by top name (:564-567) and compares an object under `members` (`Same` :320-351). A port that flattens the body would leave the read-back `unchecked` (:133-135).
- `Screen/Tool/FieldLists.cls:83-92`: `ECP.Settings`' derived rows (two objects, six number members). `Screen/Tool/Classification.cls`: grammar :6-29; only the six member rows are classifiable (`ordinary`), and `compare` `members` is valid on both objects; ECP entries :660-679, the last entry :1246-1263. Regenerate `ToolFields.cls` with `cd ui && node tools/field-lists.mjs`.
- `Screen/Registry.cls`: `EMITTEDKEYWORDS` :62 (no `properties`: an object argument is described in prose), `ObjectProblem` :853, `SELFPROTECTIONRULES` :2825, tab rules `TabProblem` :549-597 and `TabGroupProblem` :671-757, `read.note` `ReadNoteProblem` :1040-1055, `IsWriteCapable` :2571-2584, `ScreensForArea` :3448-3480 (position-0 screens sort by class name).
- Row-state refusals: `Kernel/Proposal/Operation.cls` `ReadTarget` :316-343 (a LIST row by key; no row is 404); `Mint.cls` `StateDiff` :232-241 (refused before storing); `Api/ScreenAction.cls` `Body` :433-460 (`StateDiff` at :445 for a bodyless tool); `Screen/Tool/AuditEventReset.cls` `StateDiff` :143 and `ResourceDelete.cls` :84, :125, :154: the models. `Confirm.cls` `FingerprintMatches` :672-751 closes a row whose `Status` moved as target-changed.
- Tab group, read-only: `Screen/Descriptor/LicenseSummaryTab.cls` (head, `sideBarPosition` 8, tab 1, `emptyNextKey` `tableReadOnlyEmptyNext`) and `LicenseProcessTab.cls` (tab 2, position 0). Client strip: `ui/src/app/shell/detail-page.ts:55-114`; no tab member takes a `DESCRIPTOR_PAGES` override.
- `Kernel/Proposal/Prohibited.cls`: `COVEREDTYPES` :250 (38), type guard :1069, ECP branch :1253-1257, `PermittedChangeFields` :840, `Changed` :3993 (its `Settings.` and `Custom.` folds; a dotted row with no fold is never recorded, so `ReviewedFewOnly` would pass it).
- `Kernel/EntityType.cls:71` (49 types), `Kernel/EntityRef.cls:59` (25 rules; `singleton`, `foldcase`; no rule keeps an id verbatim).
- `Kernel/Governance/Baseline.cls:21-68`, the ECP keys at :30-33; new keys go between :33 and :34.

**Client** (`ui/src/app/`):

- `areas/os-management/journal-settings.store.ts` (`open` :273-295, `save` :354-395, `saveBody` :407-422, change event :472-481) and `.page.ts` (violations :109-121, shown-only hint :269, sticky bar :273-287): the settings page model. `areas/os-management/language-server-form.store.ts` `changedBody` :550-561 sends a nested object of changed members; violations name `Custom.<member>`.
- `core/self-protection.ts` `selfProtectionReason` :131-173 (`system-resource` :140-143 is the row-field model).
- `shell/screen-action-handler.ts`: `SCREEN_ACTION_DESCRIPTORS` :64-105, ECP constants :182-183, `DESTRUCTIVE_ACTIONS` :357, `DESTRUCTIVE_CONSEQUENCES` :385-418, `WARNING_CONSEQUENCES` :472-492, `PUBLISHED_PROBLEMS` :540-558.
- `core/screen-actions.ts` `DESCRIPTOR_ACTION_LABELS` :151 (ECP :224-225); `core/proposal-view.ts` consequence codes :256-271, mapped :340-341; `shell/screen-outlet.ts` `DESCRIPTOR_PAGES` :141-228 (ECP :207-210, the last Epic 18 entry :210); `app.ts` injections :345-348, sign-out resets :674-675.
- `core/strings.ts`: ECP block :5155-5218, `} as const` :5219; `ui/tools/strings.test.mjs` literal bound :582 (2500), one key per value :767-772, citations :816.
- `ui/angular.json:54` `maximumWarning` 2728kB, pinned at `ui/tools/angular-json.test.mjs:474` (last history rows :455-461).

**EXPERIENCE.md** (`_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md`, 1006 lines): :164 OS management's side bar (ends "· ECP data servers (Stage 2, Story 18.20) |"); :173 Dialogs (delete list and "the warnings that precede a non-delete write"); :375 Fixed strings (the ECP clause, `ecpLicenseRefusal`); :479 delete bodies; :858 auto-refresh roster (unchanged).

**Rosters** (current counts; re-derive each change from its class's red, never by hand):

- ObjectScript (`src/OcuPilot/Test/`): `Descriptor.cls` `ReadShapes` :70-165 (96), entity count :1740 (49); `ReadTool.cls` :93 (251), :94, :112; `SurfaceCoverage.cls` screens :57-189, tools :190-338; `EndpointCoverage.cls` :75-252 (the `PUT /journal/settings` `refusal="1"` model :203); `Navigation.cls` :490 (42), list :491-494; `Wire.cls` peels :717-731, remainder :732; `WireSecurityRead.cls` :567, :574, :577 (42 each); `WireAreaAnyScreen.cls:271` (17); `ClassicPageGate.cls` `OWNPAIRS` :74 (51, message :149); `ToolRoundTrip.cls` `REFUSEEMPTY` :68; `Prohibited.cls` :232 (38); `GovernanceBaseline.cls` `DISABLED` :15 (25); `Governance.cls` `ECPDISABLED` :43; `ToolDispatch.cls:172`; `ToolEmit.cls` :208-267; `PortFixture.cls:21` (119); `ToolWrite.cls` :1324-1326; `ScreenRead.cls:212` (empty-read exemptions); `DraftRegistry.cls` :57-68; `LanguageServerWire.cls` :279-282 (the own-pair refused list). `PortGate`, `AdminPortAsync` and `MappingDescriptor` move only if their red names a change.
- Position-0 order: `EcpSslConnectionTab` sorts after `EcpDataServerForm` and before `GlobalMappingForm` in `Navigation`, `Wire`, `WireSecurityRead` and the client route lists.
- Own pair: the AC5 refused list in `ui/browser/language-servers.browser-spec.mjs:359-368`, `LanguageServerWire.cls:282` and `WireSecurityRead`'s PROCESSUSER literal each gain ECP settings refused on `%Admin_Secure:USE`; `ui/tools/screen-mirror.test.mjs:2327-2352` gains `EcpSettings` (between `BackgroundTaskList` and `JournalSettings`).
- Client: `ui/tools/navigation.test.mjs` :152-217, :327-357, :381-388; `navigation-wire.test.mjs` :90-395, :735-739; `shell/rail-wire.spec.ts` :87-400, :811-817; `shell/area-verdict.spec.ts` :50-74, :158-181; `screen-mirror.test.mjs` :223-259 (id rules); `proposal-view.test.mjs`; `self-protection.test.mjs` :583-604.
- Browser side-bar pins (DW-1774), 17 to 19 entries: `license-usage.browser-spec.mjs:130-156` and `remote-databases.browser-spec.mjs:300-322` (`deepEqual`); `journals` :277-281, `journal-settings` :227-230, `license-key` :218-220, `license-servers` :249-251, `ecp-data-servers` :372-373 (length and index). `local-databases` and `namespaces` (`slice`) are unaffected.
- CI: `scripts/ci-throwaway.sh` `OCUPILOT_ALLOW_ECP_CONFIG` :516 (`# classes:` :515), `OCUPILOT_ALLOW_PRINCIPALS` :319 (classes :207-318); `ui/tools/ci.test.mjs:2096-2177` derives both rosters itself.

## Tasks & Acceptance

**Task 0, the implement stage's first task, before any descriptor, tool or page.** Run it on `ocupilot-b-ci` only, loading with `/tmp/epic-18-d6/load-throwaway.sh` (no restart). Keep evidence under `/tmp/epic-18-d6/1821/t0/`. Record each result under Design Notes › Measured at implement, and each AD sentence in `## Spec Change Log` for the runner.

1. **Plumbing:**
   - `Port/AdminPort.cls`, add-only: `ECP.Settings/PUT`, `ECP.AppServerSSLConnection/AUTHORIZE`, `/REJECT` and `/DELETE` join `MUTATINGTYPES` with one doc paragraph; the three SSL/TLS pairs join `BODYLESSTYPES`. `Test/PortFixture.cls:21` follows.
   - `Test/EcpProbe.cls`, add-only: `SeedAuthorized(pName)`, `RemoveAuthorized(pName)` and `AuthorizedNames()` (through `SYS.ECP` in `%SYS`); `SeedSsl(pName, pServer, pEnabled)` and `RemoveSsl(pName)` for `%ECPClient` and `%ECPServer` on the `SecurityDeleteProbe` model (seeds only an absent name, marks it, removes only a marked one); `Settings()` and `RestoreSettings(pSettings)` (`Config.config`, `Config.ECP`, `Security.System`); `PendingRestart(.pReasons)` (`Config.CPF.PendingRestart`). `Snapshot` gains the settings, `PendingRestart`, both SSL/TLS configurations' existence and `Enabled`, the authorized and pending names; `RemoveAll` also removes probe SSL/TLS names (`CN=OCUPROBEECP*`), marked SSL/TLS configurations, and restores settings it was handed.
2. **Take S0.** It must read `PendingRestart` 0; otherwise record the reasons and halt.
3. **Reads, timed, as `_SYSTEM`:** `ECP.Settings` `GET` (each member's JSON type); `ECP.AppServerList` `LIST`; `ECP.AppServerSSLConnection` `LIST` with `CN=OCUPROBEECPA` seeded, and again with a `name` query (ignored?).
4. **Settings writes through `AdminPort`,** each followed by a read of the stored values, `PendingRestart` and its reasons, `messages.log` lines, `EcpJobs()`, audit events (auditing on) and the duration, then restored:
   - a. the fresh `GET` body sent back unchanged;
   - b. each member alone changed by one and restored: `MaxServers` 2→3→2, `ClientReconnectDuration` 1200→1201, `ClientReconnectInterval` 5→6, `ServerTroubleDuration` 60→61, `MaxServerConn` 1→2→1;
   - c. a body carrying one object only: are the other object's members kept?
   - d. the vendor's answer to `MaxServers` 255 and "x", `ClientReconnectInterval` 0, and `SSLECPServer` 3, each alone (is one member's refusal accompanied by another's write when sent together with a valid change? send `{AppServerSettings:{ClientReconnectInterval:6}, DataServerSettings:{SSLECPServer:3}}` once and record what stored);
   - e. `SSLECPServer` 1 with `%ECPServer` absent; then with a `%ECPServer` seeded disabled, if `Security.SSLConfigs.Create` accepts a server configuration with no certificate (record either way); restore 0;
   - f. with two probe data servers at `192.0.2.10` and `192.0.2.11` (port 1972), `MaxServers` 1: the answer and effect; restore; remove the servers.
5. **SSL/TLS authorizations through `AdminPort`:** with `CN=OCUPROBEECPA` seeded, `DELETE` (then `LIST`), `DELETE` again; `AUTHORIZE` and `REJECT` for a name not pending (does either add, remove or change a row?); `REJECT` for the seeded authorized name. Seed `cn=OcuProbeEcpB` and `DELETE` it as `CN=OCUPROBEECPB`: is the name matched exactly or in any case? Record each answer, duration and audit event.
6. **Audit:** which of steps 4 and 5 wrote a vendor event (expected `%System/%System/ConfigurationChange` or a `%Security` change for the settings `PUT`; none known for `SYS.ECP`).
7. **Pairs**, through `RunAs` with the install namespace's code read:
   - the settings `GET` and a `PUT` of `ClientReconnectInterval` 5→6 (restored by `_SYSTEM`) for a principal holding exactly `%Admin_Manage:USE`, `%DB_IRISSYS:READ` and `%Admin_Secure:USE`; then with each candidate alone, `%DB_IRISSYS:WRITE` and `%Admin_Operate:USE`, and both; then the `PUT` without `%Admin_Secure:USE` but with `%DB_IRISSYS:WRITE`. After each, record which of the three vendor `Modify` calls stored (a half-apply).
   - `Security.SSLConfig` `GET name=%ECPServer` for the screen's set with and without `%Admin_Secure:USE`.
   - `ECP.AppServerList` and `ECP.AppServerSSLConnection` `LIST`, and `DELETE`, `AUTHORIZE`, `REJECT` (with a seeded name) for exactly `%Admin_Manage:USE` and `%DB_IRISSYS:READ`, then each candidate alone (`%DB_IRISSYS:WRITE`, `%Admin_Operate:USE`, `%Admin_Secure:USE`).
8. **DW-2006:** seed `%ECPClient` disabled; `PUT name=ocuprobeecpsslc {Address:"192.0.2.10", Port:1972, SSLConfig:1}`; record the answer, `GET`, `messages.log` and `EcpJobs()`; delete the server. Repeat with `%ECPClient` enabled (expected stored). Remove `%ECPClient`.
9. **Cleanup proof:** `RemoveAll`, then S2. It must equal S0 apart from counters, declared `messages.log` lines and the monitor state (clear it with `$SYSTEM.Monitor.Clear()` if it moved).
10. **HALT** with status `blocked`, blocking condition `intent gap: observation contradicts the plan: <what>`, and nothing built past step 1, if any of these hold (record step 7's evidence first for a pair halt):
    - a restored setting leaves `PendingRestart` 1, or any write changes a member it did not send;
    - `EcpJobs()` is above 0, or `messages.log` gains an ECP connection line beyond a configuration write's declared severity-0 lines;
    - a license fact or `%Service_ECP` changes;
    - a route cannot be reached through `AdminPort`, or answers 202;
    - a read takes more than 2 s;
    - a write needs a pair outside the screen's set (with `EcpSettings`' own pair), `%DB_IRISSYS:WRITE` and `%Admin_Operate:USE`, or no measured set avoids a half-apply;
    - `AUTHORIZE` or `REJECT` of a name not pending removes or changes an `Authorized` row;
    - S2 differs from S0 beyond the declared differences.
11. **Otherwise, set from the record:**
    - **Each tool's pairs**, and whether the SSL/TLS tools need `%DB_IRISSYS:WRITE`.
    - **The body.** The complete nested set stands unless step 4a changed anything, set a pending restart, or wrote an audit event step 4b's changes do not; then an unchanged member is omitted (a named AD-4 exception, the `Task.CRUD` model).
    - **The restart consequence** covers `MaxServerConn` and any member step 4b leaves pending until restored.
    - **The vendor's value refusals** (step 4d) are unreachable through the rules; if one member's refusal still stores another, record it as a named limit.
    - **The `%ECPServer` rule** is pinned on the real instance where step 4e could seed a disabled server configuration, and through the seam otherwise.
    - **`READROWKEYEXACT`** and the `ecp-ssl-connection` id rule: exact (no `IDRULES` entry) if step 5 matched exactly; `foldcase` if any case.
    - **DW-2006** per Design Notes › Decision 5.
    - **Each AD-15/AD-53 named case**, wherever step 6 found no vendor event.

**Execution (server)** (`src/OcuPilot/`):

- `Port/EcpPort.cls`, add-only branches before :115:
  - `ClassMethod SslState(pName, Output pState)` answers `absent`, `disabled` or `enabled` for `%ECPServer` or `%ECPClient` from `Security.SSLConfig` `GET` through `Call` (a 404 is `absent`, unlogged as every read's 404 is). The settings `PUT`, DW-2006's check and `EcpSettingsRules.HandleForm` all use it, so the seam answers each.
  - `ECP.Settings` `GET` and `PUT` drop the identifying query (the `JournalPort.Settings` model).
  - `PUT`: when the body's `DataServerSettings.SSLECPServer` is 1 or 2 and `SslState("%ECPServer")` is not `enabled`, refuse 422 `ECP.SETTINGS.VALIDATION` with the violation `ECP.SETTINGS.SSLSERVER` on `DataServerSettings.SSLECPServer` (the `Refused` model), sending nothing. Then the body per Task 0 step 11, then `Call`.
  - `ECP.AppServerSSLConnection` falls to `Call` unchanged (the port exists for the seam).
  - DW-2006, if Decision 5 applies: in `Put`, when the body sends `SSLConfig` 1 or `true` and `HoldsPair(..#LIMITPAIR)`, refuse `ECP.DATASERVER.SSLCLIENT` on `SSLConfig` unless `SslState("%ECPClient")` is `enabled`, before the vendor `PUT`.
  - `Snippet`: the `%ECPServer` refusal (and DW-2006's) renders one comment step with its sentence; otherwise one `PUT /ecp/settings` step with the body; the SSL/TLS actions fall to `##super` (AD-59).
- `Api/EcpError.cls` (add-only, each in `Codes()`, `FieldOf` and `ReasonFor`; violations in `ViolationCodes()`):
  - `ECP.SETTINGS.VALIDATION` (422): "The ECP settings were refused."
  - `ECP.SETTINGS.COUNT` (`AppServerSettings.MaxServers`, `DataServerSettings.MaxServerConn`): "Enter a whole number from 0 to 254."
  - `ECP.SETTINGS.RECOVERY` (`AppServerSettings.ClientReconnectDuration`): "Enter a whole number of seconds from 10 to 65535."
  - `ECP.SETTINGS.INTERVAL` (`AppServerSettings.ClientReconnectInterval`): "Enter a whole number of seconds from 1 to 60."
  - `ECP.SETTINGS.TROUBLE` (`DataServerSettings.ServerTroubleDuration`): "Enter a whole number of seconds from 20 to 65535."
  - `ECP.SETTINGS.SSL.SHAPE` (`DataServerSettings.SSLECPServer`): "Choose Disabled, Enabled or Required."
  - `ECP.SETTINGS.SSLSERVER` (`DataServerSettings.SSLECPServer`): "Create and enable the %ECPServer SSL/TLS configuration before using SSL/TLS."
  - `ECP.SETTINGS.RESTART` (a consequence, no field): "A changed maximum number of application servers takes effect only after the instance restarts."
  - `ECP.SSL.AUTHORIZE` and `ECP.SSL.REJECT` (consequences): "Authorizing lets the application server that presents this certificate connect to this instance over ECP." and "Rejecting refuses this application server's pending connection."
  - The two state refusals, held as parameters `REASONSSLNOTPENDING` and `REASONSSLNOTAUTHORIZED` (no code: each is a tool's `StateDiff` problem, answered as 400 `TOOL.ARGUMENTS` with `detail.problem`): "This application server is not waiting for authorization." and "This application server is not authorized."
  - `SSLCLIENT`'s doc comment states DW-2006's outcome.
- `Area/OsMgmt/EcpSettingsRules.cls` (new, the `JournalRules` shape): `Validate(pArgs, Output pViolations, …)` and `Problem` over both objects (whole numbers, ranges, `SSLECPServer`, unknown members), violations named `<Object>.<member>`; `HandleForm()` serves `GET /ecp-settings/form` with `{licensed, serverSsl}` (`licensed` through `EcpPort.NetworkEnabled()`, `serverSsl` one of `absent`, `disabled`, `enabled`); `Gate` covers it with `EcpSettings`' pairs.
- `Area/OsMgmt/EcpSettingsSave.cls` (new, the `JournalSave` model): `PUT /ecp-settings` through the tool (AD-55), singleton `TargetId()`, top-level keys `AppServerSettings` and `DataServerSettings` only (else 400 `PORT.FIELD.UNEXPECTED`), rules, fresh read, `MergeUpdate`, an empty diff sends nothing, `Prohibited`, `Send`, `PortViolations` (`ECP.SETTINGS.*` rows), `ReadBack.ForSave`. `HandleForm`'s `serverSsl` comes from `EcpPort.SslState`.
- `Api/Router.cls` (add-only): `GET /ecp-settings/form` before `PUT /ecp-settings`, at the UrlMap tail, with thin wrappers.
- `Screen/Tool/` (new):
  - `EcpSettingsUpdate.cls`: `DESCRIPTORCLASS` `EcpSettings`, `PORTCLASS` `EcpPort`, `READTYPE` `GET`, `WRITETYPE` `PUT`, `SENDSBODY` 1; `SettableFields` `AppServerSettings,DataServerSettings`; `InputSchema` with both objects described in prose (members and ranges) and `Name` the literal `SYSTEM`; `MergeUpdate` (two member merges, rows `<Object>.<member>`, the body per Task 0); `ArgumentProblem` through `EcpSettingsRules.Problem`; `Consequence` (`ECP.SETTINGS.RESTART`); `PrivilegePairs` (the screen's three plus `EXTRAPAIRS` per Task 0); no `CLASSICPAGES`.
  - `EcpSslConnectionAuthorize.cls`, `EcpSslConnectionReject.cls`, `EcpSslConnectionDelete.cls`: `DESCRIPTORCLASS` `EcpSslConnectionTab`, `PORTCLASS` `EcpPort`, `WRITETYPE` `AUTHORIZE`/`REJECT`/`DELETE`, `SENDSBODY` 0, `SCREENACTIONS` `authorize`/`reject`/`delete`, the row-read parameters in Boundaries, `READANSWERS` `SSLComputerName,ClientIP,Status`; `StateDiff` answers no row (authorize, reject) or the removal row (delete, the `EcpDataServerDelete.StateDiff` model) and refuses the wrong state with its sentence (the `AuditEventReset` model; `ArgumentProblem` and `ScreenActionDelta` need nothing beyond it, since both callers reach `StateDiff`); `Consequence` `ECP.SSL.AUTHORIZE`/`ECP.SSL.REJECT`; delete `DESTRUCTIVE` 1, `REMOVALROWS` `SSLComputerName`, `CHANGEACTION` `deleted`; `PrivilegePairs` per Task 0.
- `Screen/Descriptor/` (new) `EcpSettings.cls`, `EcpAppServerTab.cls`, `EcpSslConnectionTab.cls`, as in Boundaries: tab group `os-management/ecp-application-servers`; tables Connections (Client name `name`, Status `status`, Client IP `identifier`, Port `number`) and SSL/TLS authorizations (SSL computer name `name`, Client IP `identifier`, Status `status`); empty keys (`ecpAppServerListEmpty` with `tableReadOnlyEmptyNext`; `ecpSslConnectionListEmpty` with `ecpSslConnectionListEmptyAgent`); context fields; three prompts each; the caveat in each doc comment.
- `Screen/Registry.cls` (add-only): `SELFPROTECTIONRULES` gains `ecp-ssl-pending` and `ecp-ssl-authorized`; the mirror (`ui/tools/screen-mirror.mjs`) follows.
- `Screen/Tool/Classification.cls` (add-only): `osmgmt.ecpsettings.update` over `ECP.Settings`, the six members `ordinary`, `compare` `{"AppServerSettings":"members","DataServerSettings":"members"}`; entries for the SSL/TLS tools only if `field-lists.mjs --check` asks. Regenerate `ToolFields.cls`.
- `Kernel/EntityType.cls` gains `ecp-settings` and `ecp-ssl-connection`; `Kernel/EntityRef.cls` gains `ecp-settings:singleton` (and `ecp-ssl-connection:foldcase` only if Task 0 step 5 matched in any case).
- `Kernel/Proposal/Prohibited.cls` (add-only): `TYPEECPSETTINGS`, `TYPEECPSSLCONNECTION`, `COVEREDTYPES`, the guard at :1069 and `ReviewedFewOnly` branches; `PermittedChangeFields` answers `AppServerSettings,DataServerSettings` for `ecp-settings`; `Changed` folds `AppServerSettings.` and `DataServerSettings.` rows into their object, as it folds `Custom.`; no new arm (Decision 6).
- `Kernel/Governance/Baseline.cls` (add-only, between :33 and :34, in name order): `osmgmt.ecpsettings.update` true, `osmgmt.ecpsslconnections.authorize` true, `.delete` false, `.reject` true.

**Execution (client)** (`ui/src/app/`):

- `areas/os-management/ecp-settings.store.ts` and `.page.ts` (new, with specs; the journal-settings model): `open()` issues the declared read and `GET /api/ocupilot/ecp-settings/form`; one form, two fieldsets ("This instance as an ECP application server": Maximum number of data servers, Time to wait for recovery (seconds), Time between reconnections (seconds); "This instance as an ECP data server": Maximum number of application servers with the restart sentence as its hint, Time interval for Troubled state (seconds), ECP SSL/TLS support as a radio of Disabled, Enabled and Required, the last two `aria-disabled` with the `%ECPServer` sentence unless `serverSsl` is `enabled`, focusable, never selectable); the license line (`ecpLicenseRefusal`) while `licensed` is false; `save()` sends `PUT /api/ocupilot/ecp-settings` with a nested object of changed members only; violations on their fields; sticky Save, error summary, unsaved-changes guard; the restart sentence shown after a Save that changed `MaxServerConn`; the change event on success.
- `shell/screen-outlet.ts`: the `EcpSettings` entry after :210. The two tabs take no override (the License usage model).
- `shell/screen-action-handler.ts` (add-only): the `EcpSslConnectionTab` constant, which joins `SCREEN_ACTION_DESCRIPTORS`; `WARNING_CONSEQUENCES` entries for `authorize` and `reject`; `DESTRUCTIVE_CONSEQUENCES` for `delete`; `PUBLISHED_PROBLEMS` gains the two state refusals.
- `core/self-protection.ts`: the two rules read `row['Status']` (`Pending` and `Authorized`), answering `''` with no row.
- `core/screen-actions.ts`: `DESCRIPTOR_ACTION_LABELS` `{ authorize: STRINGS.ecpSslAuthorize, reject: STRINGS.ecpSslReject }`. `core/proposal-view.ts`: the codes `ECP.SETTINGS.RESTART`, `ECP.SSL.AUTHORIZE`, `ECP.SSL.REJECT`.
- `app.ts`: the store's injection and sign-out reset, pinned in `app.spec.ts`.
- `core/strings.ts` (add-only, after :5218), each key under its `/** EXPERIENCE.md:n */` line; raise `strings.test.mjs:582`'s bound only if the literals cross it. Regenerate `core/screens.generated.ts` (`cd ui && node tools/screen-mirror.mjs`).
- `ui/angular.json`: re-base `maximumWarning` under DW-1166 to the measured initial total rounded up to the next kB, with its history row; stop and ask above 3800kB.
- **EXPERIENCE.md, in place, keeping 1006 lines,** then `cd ui && npm run test:tools`:
  - :164 gains "· ECP settings (Stage 2, Story 18.21) · ECP application servers (Stage 2, Story 18.21: Connections and SSL/TLS authorizations tabs)".
  - :173: the delete list gains "ECP SSL/TLS authorization"; the non-delete warnings gain "authorize or reject an ECP application server's SSL/TLS request (Story 18.21)".
  - :375 gains "; and ECP settings and ECP application servers (Story 18.21): …", tagged `[ADDED <date> - Story 18.21]`, with every new literal: the two screen labels and two tab labels, the entity labels "ECP settings" and "ECP SSL/TLS authorization", the two fieldset legends and six field labels, the restart sentence, the `%ECPServer` sentence, the range sentences, the column labels "Client name", "Client IP" and "SSL computer name", the two empty states ("No application servers are connected to this instance.", "No SSL/TLS authorizations on this instance.") and the agent phrase "explain how an ECP application server is authorized", "Authorize" and "Reject", the two warnings and the two state refusals, and the nine prompts.
  - :479 gains "; then Delete on an ECP SSL/TLS authorization (Story 18.21), whose typed name is the SSL computer name and whose dialog carries no advisory", with the body "Deleting this authorization means the application server that presents this certificate must be authorized again the next time it connects. Its current connection is not affected. This cannot be undone."

**Rosters and CI:** extend every roster in Code Map › Rosters (position-0 order and own pair as noted; the six side-bar pins grow to 19). `scripts/ci-throwaway.sh` (add-only): the new armed classes join `OCUPILOT_ALLOW_ECP_CONFIG`'s `# classes:` line, and the gate class joins `OCUPILOT_ALLOW_PRINCIPALS`. `Test/ScreenRead.cls:212` exempts `EcpAppServerTab` and `EcpSslConnectionTab` (empty on a fresh instance).

**Tests:**

- `Test/EcpSeamPort.cls` (add-only arm modes): `ecpserver` answers `Security.SSLConfig` `GET name=%ECPServer` enabled and records an `ECP.Settings` `PUT` without reaching the vendor; `pending` answers `ECP.AppServerSSLConnection` `LIST` with `CN=OCUPROBEECPP` `Pending` and records `AUTHORIZE`/`REJECT`/`DELETE` without reaching the vendor. `SeamEcpSettingsUpdate` and `SeamEcpSslConnection*` tool subclasses and the fixtures' `ToolFor` follow the 18.20 pattern.
- `Test/EcpSettingsWrite.cls` (`OCUPILOT_ALLOW_ECP_CONFIG`; restores S0's settings after each test): the matrix's read, change (both callers, nested body, diff row, read-back), restart (consequence on Save and card; `PendingRestart` 0 after the restore), bad values and unexpected keys (zero `PUT`s), `%ECPServer` absent (real) and disabled (real or seam), and enabled (seam) legs.
- `Test/EcpSslConnectionWrite.cls` (`OCUPILOT_ALLOW_ECP_CONFIG`): both tabs' reads on screen and tool; the delete on both callers with its read-back; wrong-state refusals with zero writes; authorize and reject through the seam; absent names; DW-2006's leg if Decision 5 applies (or in `EcpDataServerWrite`).
- `Test/EcpSettingsGate.cls` (`OCUPILOT_ALLOW_PRINCIPALS`, `OCUPILOT_ALLOW_ECP_CONFIG`, with `EcpWriteGateProbe`): `EcpSettings` refused without its own pair and listed unavailable; each tool's, the Save's and the form route's declared pairs refused by name with zero port calls; exactly the declared pairs write.
- `Test/EcpDescriptor.cls` (add-only): the three descriptors (routes, positions, tab group, pairs, own pair, classic pages, prompts, entity types, id rules, `read.note`, caveat), Connections' declared fields equal to the vendor query's mapped columns (`SYS.ECP:ClientList`'s `ROWSPEC` through the endpoint's mapping: `ClientName, Status, IPAddress, IPPort`), the new `EcpError` codes and sentences, the four baseline keys, the self-protection rules, `EcpPort.Snippet`'s new branches.
- Client: component specs for the settings page and store (the radio's disabled reasons, the license line, changed-members body, violations, the restart sentence); the handler's warning, consequence and published-problem entries; `self-protection.test.mjs` legs pinning each state refusal and `ECP.SETTINGS.SSLSERVER`'s reason equal to their strings keys and the rules' reasons; `proposal-view.test.mjs` the three codes.
- **`ui/browser/ecp-settings.browser-spec.mjs`** (new; refuses a non-throwaway): the eighteenth entry; the six fields; Enabled and Required `aria-disabled` with the sentence; the license line; a Save of `ClientReconnectInterval` and its restore over `docker exec`; a refused value on its field; the DW-1337 gate in both themes.
- **`ui/browser/ecp-application-servers.browser-spec.mjs`** (new; refuses a non-throwaway): the nineteenth entry and both tabs; Connections' empty state and note; a seeded authorized name with Authorize and Reject `aria-disabled` and its reason; Delete through the typed-name dialog; the DW-1337 gate in both themes on each tab and dialog; cleanup with no probe name left.

**Acceptance Criteria:**

- **C0:** Given `ocupilot-b-ci`, when the implement stage starts, then Task 0 records the payloads, durations, effects, pending-restart states, pairs and audit events of `ECP.Settings` `GET`/`PUT`, `ECP.AppServerList` `LIST` and `ECP.AppServerSSLConnection` `LIST`/`AUTHORIZE`/`REJECT`/`DELETE`, and DW-2006's measurement, before any descriptor, tool or page exists; no ECP process starts, the license reads as found, and S2 equals S0 apart from the declared differences. A contradiction halts the story.
- **C1:** Given the instance's ECP settings, when ECP settings opens and `osmgmt.ecpsettings.read` runs, then both answer the same six members from one read, the license line shows while the license lacks ECP, Enabled and Required are drawn `aria-disabled` with the `%ECPServer` sentence while that configuration is absent or disabled, and a caller without `%Admin_Secure:USE` sees the entry listed unavailable naming that pair.
- **C2:** Given a change, when a person saves or the agent's proposal is confirmed, then one `ECP.Settings` `PUT` sends the nested body read fresh with the change applied, the diff names `<Object>.<member>`, the read-back reads `matches`, and a changed `MaxServerConn` states that it takes effect only after a restart and is never claimed applied.
- **C3:** Given an out-of-range or non-integer value, an unknown member or key, or `SSLECPServer` 1 or 2 without an enabled `%ECPServer`, when either caller sends it, then it is refused on its field before any vendor call; with `%ECPServer` enabled (seam) the change is sent.
- **C4:** Given ECP application servers, when each tab and its read tool run, then each answers the same rows; Connections shows its status note and, on Community, no rows.
- **C5:** Given a seeded authorized name, when it is deleted through the typed-name dialog or a confirmed proposal, then it leaves the list; when Authorize or Reject is chosen on it, then the action is drawn `aria-disabled` with its reason and refused on both callers with nothing sent. Given a pending name (seam), Authorize and Reject send one call each and Delete is refused.
- **C6:** Given a caller lacking a declared pair, or an absent name, when either caller writes, then it is refused (403 naming the pair, or not found) with zero port calls.
- **C7 (DW-2006):** Given a disabled `%ECPClient`, when a data server is saved with SSL/TLS, then Task 0's measurement decides: it is refused `ECP.DATASERVER.SSLCLIENT` with nothing stored (for every caller the vendor refuses, or for a caller holding `%Admin_Secure:USE`), and any remaining gap is named in the spec and the spine.
- **C8:** Given the rosters, when the story lands, then ECP settings is OS management's eighteenth entry and ECP application servers its nineteenth; each screen carries three prompts; the four keys are in the baseline with the delete disabled; every roster and pinned side-bar list includes the screens; the DW-1337 gate holds in both themes; EXPERIENCE.md reads 1006 lines.

## Spec Change Log

## Review Triage Log

## Design Notes

**Governing ADs:**

- AD-2, AD-27, AD-52: `EcpPort` extends `AdminPort`, names no vendor class, and sequences the `%ECPServer` read before the settings `PUT`. No AD-27 case.
- AD-3: `ECP.Settings`' derived rows, classified per member with `compare` `members`; the SSL/TLS tools derive no field list.
- AD-4: the first merge over a nested body (Decision 1).
- AD-5, AD-36, AD-44: one descriptor per screen and tab, member fields on a single-object read, `read.note`, the classic pages, no `CLASSICPAGES`.
- AD-6, AD-34, AD-40, AD-53, AD-55: each tool's two callers; the Save through the tool.
- AD-8, AD-29: `EcpSettings`' own pair, each tool's measured pairs, refusal by name before any port call.
- AD-10: no new arm (Decision 6). AD-13, AD-14: two entity types, the singleton, the events.
- AD-15, AD-53: vendor events, or named cases per Task 0. AD-21: no path; the SSL/TLS configuration names are fixed.
- AD-22: the baseline (Decision 7). AD-26: nothing queues (`async="0"`). AD-39: OcuPilot's own sentences.
- AD-43: no auto-refresh. AD-51: the three bodyless actions with a declared `Status` subject. AD-58: read-back. AD-59: `Snippet`.

**Measured before this plan** (not re-run): `ECP.Settings` `GET` needs `%Admin_Secure:USE` beyond OS management's set (500 `PORT.ACCESSDENIED` without it); `Security.SSLConfig` `GET` of an SSL/TLS configuration answers 403 without it (Story 18.20, Task 0 steps 7 and 10). The classic pages are spelled as their class names and none is Hidden (`NormalizePage`, Story 18.6's plan). Each `Config.ECPServers` write logs two severity-0 activation lines (Story 18.20).

**Measured at plan** (read-only, `ocupilot-b-ci`, 2026-10-04): `NetworkEnabled()` 0, `MaxECPServers()` 0, `KeyServer()` Single; `PendingRestart` 0; `MaxServers` 2, `MaxServerConn` 1, `Config.ECP` 1200, 5, 60, `SSLECPServer` 0; neither `%ECPServer` nor `%ECPClient` exists; `%Service_ECP` disabled; monitor state 1 (left by earlier runs); 0 ECP jobs. Through `AdminPort` as `irisowner` (`%All`): `ECP.Settings` `GET` 200 in 0.0035 s (`{"AppServerSettings":{"MaxServers":2,"ClientReconnectDuration":1200,"ClientReconnectInterval":5},"DataServerSettings":{"MaxServerConn":1,"ServerTroubleDuration":60,"SSLECPServer":0}}`, all numbers); `ECP.AppServerList` and `ECP.AppServerSSLConnection` `LIST` 200 `[]` in 0.0013 s and 0.0008 s; `Security.SSLConfig` `GET name=%ECPServer` 404 `PORT.NOTFOUND`.

**Decisions** (each applied in this plan; the runner confirms them at the spec gate):

1. **The nested merge is the tool's, member by member, over two object arguments** (the `LanguageServerUpdate.MergeCustom` model). The kernel merge is top-level only and the field rows skip dotted paths, so dotted settable names would be refused; a port that flattens the body would leave every read-back `unchecked`. `compare` `members` on both objects makes the read-back compare each sent member.
2. **`EcpSettings` declares `%Admin_Secure:USE` as its own pair**, narrower than the classic page (`%Admin_Manage`, with `%Admin_Secure` only for SSL/TLS), because the vendor's `GET` and every `PUT`'s trailing re-read call `Security.System.Get` (the `PUT` part is inference until Task 0 step 7). The same narrower-audience precedent as Stories 18.5, 18.15, 18.16 and 18.18.
3. **`MaxServerConn` is settable and never claimed applied.** The planning sources describe its restart consequence and a restore that leaves nothing pending (epic context; Story 18.6 Part C), and the dispatch says such a setting is "shown, never claimed applied", not "shown, never set". If the runner reads the dispatch's "never plan a write that needs an instance restart" as excluding it, `MaxServerConn` becomes shown-only with the classic page's hint, and C2's restart clause and the restart legs are dropped.
4. **Authorize, reject and delete are gated by row state through two new self-protection rules** (`ecp-ssl-pending`, `ecp-ssl-authorized`, the `system-resource` model), because a declaration has no other per-row withholding key and a tab member takes no page override without losing its strip. Each rule's reason is the tool's own refusal sentence, published once and pinned.
5. **DW-2006.** If Task 0 step 8 shows the vendor refuses `SSLConfig` 1 over a disabled `%ECPClient`, the refusal is mapped (a `PROPERTYFAULTS` entry if its code is not #1454) and DW-2006 is resolved. If it stores it, `EcpPort.Put` reads `%ECPClient` and refuses `ECP.DATASERVER.SSLCLIENT` before the vendor `PUT` for a caller holding `%Admin_Secure:USE` (the read's pair, the 18.20 limit ruling's option-(b) model), and the gap for any other caller is named: a person or proposal without that pair can store SSL/TLS over a disabled `%ECPClient`, as the vendor allows. For such a caller the pre-check also refuses an absent `%ECPClient` before the vendor, so DW-2007's severity-2 line remains only for callers without the pair (inference). The alternative, an argument pair `%Admin_Secure:USE` whenever `SSLConfig` is 1 (airtight, narrower than the classic dialog), is the orchestrator's to choose instead.
6. **No new AD-10 arm.** OcuPilot's own databases are local, so no ECP setting or SSL/TLS authorization reaches its serving path or state (inference, as Story 18.20's Decision 6).
7. **Governance.** Update, authorize and reject enter `true` and delete `false`, Story 18.6 Part C's split; authorize and reject remove nothing and each carries its warning. AD-22 gives the owner the call for keys entering after 2026-10-04, so the runner confirms the three `true` keys with the orchestrator before the commit.
8. **The Connections tab declares no entity type** (the License usage tabs' model): it has no write, so nothing routes a change event to it.

**Named limits:**

1. On Community the Connections list is always empty and no SSL/TLS request can be pending, so Connections' rows and the authorize/reject success paths are pinned through the declared columns and the seam only.
2. The vendor's settings `PUT` does not stop at a refused member (`$$$ADDSC`), so a vendor-side refusal could store the others; the rules and pairs keep every value and privilege refusal before the call.
3. A distinguished name both authorized and pending (a pre-authorized name whose request is still listed) would read as two rows with one id; the tools act on the first (inference: the vendor does not list an authorized name as pending).
4. "Authorized" and "Pending" are the vendor's literal statuses and render as written.

**Proposed spine amendments (Rule 20).** The runner writes 1 to 3 at the spec gate; Task 0 confirms each `<measured>` and the implement stage records 4 to 6 in `## Spec Change Log`.

1. **AD-4, after `Journal.Settings`' exception:** "**`ECP.Settings` is the first nested body** [AMENDED <date>, Story 18.21 spec gate, Rule 20]: its tool merges `AppServerSettings` and `DataServerSettings` member by member over the fresh read, as `LanguageServer`'s `Custom` is merged, and sends both objects <complete / omitting an unchanged member, measured>; the vendor sets only the members it is sent and does not stop at a refused one."
2. **AD-13, after the `ecp-data-server` sentence:** "**`ecp-settings` is a singleton; an `ecp-ssl-connection` id is the certificate's distinguished name, <kept exactly / `foldcase`, measured>** (Story 18.21) [AMENDED <date>, Story 18.21 spec gate, Rule 20]."
3. **AD-44, after Story 18.20's `CLASSICPAGES`:** "**Story 18.21's tools declare no `CLASSICPAGES`**: `%CSP.UI.Portal.ECP` performs the settings update and `%CSP.UI.Portal.ECPAppServers` the SSL/TLS authorize, reject and delete, each its descriptor's own page [AMENDED <date>, Story 18.21 spec gate, Rule 20]."
4. **AD-8, after Story 18.20's paragraph:** "**Story 18.21's ECP settings declares `%Admin_Secure:USE` as its own pair** beside OS management's set, because the vendor's settings `GET` calls `Security.System.Get` (measured); `osmgmt.ecpsettings.update` declares <measured pairs>, and the SSL/TLS authorize, reject and delete declare <measured pairs>, each refused by name before any port call [AMENDED <date>, Story 18.21 Task 0, Rule 20]."
5. **AD-52, after Story 18.20's paragraph:** "`EcpPort` (Story 18.21) refuses a settings write whose `SSLECPServer` is 1 or 2 while `%ECPServer` is absent or disabled, read through `Security.SSLConfig` before the `PUT`<; and, for a caller holding `%Admin_Secure:USE`, a data server write with SSL/TLS while `%ECPClient` is absent or disabled — a caller without that pair reaches the vendor, which stores SSL/TLS over a disabled `%ECPClient` (measured, DW-2006)> [AMENDED <date>, Story 18.21 Task 0, Rule 20]."
6. **AD-15 and AD-53**, only where Task 0 step 6 finds no vendor event: "Authorizing, rejecting or deleting an ECP application server's SSL/TLS name (`ECP.AppServerSSLConnection`, Story 18.21) records no vendor event with auditing on <measured>", and the same for the settings `PUT` if measured unaudited.

**Integration ACs.** New: `EcpSettingsRules`, `EcpSettingsSave`, `EcpPort`'s settings branch, the new `EcpError` codes and the two self-protection rules.

- The settings page consumes `GET /ecp-settings/form` and `PUT /ecp-settings`: the real refusal of Enabled on `ocupilot-b-ci` and a real stored change (C1-C3; `EcpSettingsWrite`, the browser spec).
- The SSL/TLS tab consumes the three tools through `POST /screens/:screen/action`: a real seeded name deleted (C5; `EcpSslConnectionWrite`, the browser spec).
- The rules' reasons are consumed by the tab's disabled row actions, pinned equal to the tools' sentences (C5; `self-protection.test.mjs`).

**Consumes:**

- 18.20: `EcpPort` (`Call`, `NetworkEnabled`, `Refused`, `HoldsPair` use), `EcpError`, the `ECP.LICENSE` sentence, `EcpProbe`, `EcpSeamPort`, the fixtures, `ecpDataServerStatusCaveat`.
- 18.18: the singleton editor (descriptor, tool, Save, rules, page and store). 16.25: the member merge. 19.14: `read.note`. 16.x: the self-protection rules. 16.17's read-back, 14.1's `Snippet`, 14.2's baseline.

**Consumed-by:** 18.12 (the agent's grown tool set); Epic 18's close burn-down (DW-2007 now reads with Decision 5's pre-check).

**Ledger inbox (Rule 17):** DW-2006 is addressed by Task 0 step 8, Decision 5, the matrix row and C7. DW-1774's side-bar rule is met by the roster tasks. `ledger.sh slice 18-21-ecp-settings-and-application-servers` holds DW-2006 alone.

**Footprint (Rule 11).** Every contended file is edited add-only (Boundaries). New or outside the listed set, for `footprint_extensions`: `Area/OsMgmt/EcpSettingsRules.cls`, `EcpSettingsSave.cls`, `Port/EcpPort.cls`, `Api/EcpError.cls`, `Screen/Registry.cls` (two rule names), `ui/tools/screen-mirror.mjs` (if the rule list is not parsed), `ui/src/app/core/self-protection.ts`, `ui/src/app/app.ts`, `Test/ScreenRead.cls`, `Test/LanguageServerWire.cls`, `ui/browser/language-servers.browser-spec.mjs`.

**Size.** Three descriptors (one an unlisted tab with no page override), four write tools, no new port, two area classes, one form page and store. About Story 18.20's size, so one implement pass (inference).

## Verification

**Setup (slot B):**

- Load with `/tmp/epic-18-d6/load-throwaway.sh`, with no restart, never through the MCP loader. Every write lands on `ocupilot-b-ci`, on `OCUPROBEECP*` objects, marked SSL/TLS configurations and restored settings only.
- One test class per call; send the next only once the previous has landed in `%UnitTest_Result`; never re-submit after a client-side timeout.
- Arm per call with `docker exec -e OCUPILOT_ALLOW_ECP_CONFIG=1 -e OCUPILOT_ALLOW_PRINCIPALS=1 -e OCUPILOT_ALLOW_DATABASE_CONFIG=1`.
- Before any browser run: `cd ui && npm run build`, then `docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`, with `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777` and `OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci` exported.

**Commands:**

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.<C>`, one at a time; expected 0 failures, totals checked against `%UnitTest_Result`.
  - The story's classes: `EcpSettingsWrite`, `EcpSslConnectionWrite`, `EcpSettingsGate`, `EcpDescriptor`, and `EcpDataServerWrite`, `EcpWriteGate` if Decision 5 changes `Put`.
  - The rosters: `Descriptor`, `ReadTool`, `SurfaceCoverage`, `EndpointCoverage`, `Navigation`, `Wire`, `WireSecurityRead`, `WireAreaAnyScreen`, `ClassicPageGate`, `DraftRegistry`, `ToolRoundTrip`, `ToolWrite`, `Prohibited`, `GovernanceBaseline`, `Governance`, `ToolDispatch`, `ToolEmit`, `EntityRef`, `ScreenRead`, `LanguageServerWire`, `TabCorpus`.
- `(loop)` `cd ui && node --test --test-concurrency=1 browser/ecp-settings.browser-spec.mjs browser/ecp-application-servers.browser-spec.mjs browser/ecp-data-servers.browser-spec.mjs browser/license-usage.browser-spec.mjs browser/remote-databases.browser-spec.mjs browser/journals.browser-spec.mjs browser/journal-settings.browser-spec.mjs browser/license-key.browser-spec.mjs browser/license-servers.browser-spec.mjs browser/language-servers.browser-spec.mjs`; expected pass.
- `(loop)` `cd ui && npm run test:tools && npm run test:components`, then `uv run scripts/check-objectscript.py <changed .cls>` and `bash scripts/lint-docs.sh`; expected clean, and `wc -l` on EXPERIENCE.md reads 1006.
- `(once, before dev_complete)`, each green with a non-zero count:
  1. the full ObjectScript sweep, `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci`, one class at a time;
  2. `cd ui && npm test && npm run build`;
  3. `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS`;
  4. afterwards no `OCUPROBEECP*` data server, SSL/TLS name, marked SSL/TLS configuration or principal remains; settings, `PendingRestart`, `EcpJobs()`, the license facts and the monitor state read as at S0.
- `(CI)` The full browser suite runs in CI's three `browser-shard` jobs (Rule 29).

**Planned pinning mutations (Rule 19).** Apply each on the throwaway, observe red, revert byte-identical, and record a `mutation:` line here.

- C1: `EcpSettings`' read drops `DataServerSettings.SSLECPServer` → `EcpDescriptor`'s read leg red; the radio's `serverSsl` gating dropped → the page spec red.
- C2: `EcpSettingsUpdate.MergeUpdate` sends only the changed object → `EcpSettingsWrite`'s nested-body leg red; `Consequence` drops `ECP.SETTINGS.RESTART` → the restart leg red.
- C3: `EcpSettingsRules.Problem` admits `ClientReconnectInterval` 61 → the bad-values leg red; `EcpPort`'s `%ECPServer` check removed → the SSL/TLS leg red with a `PUT` recorded.
- C4: `EcpAppServerTab` drops `read.note` → `EcpDescriptor` red.
- C5: `EcpSslConnectionAuthorize.StateDiff` accepts an `Authorized` row → the wrong-state leg red with an `AUTHORIZE` sent; the `ecp-ssl-pending` rule removed from `self-protection.ts` → its spec red.
- C6: `EcpSettingsUpdate.PrivilegePairs` drops `%DB_IRISSYS:WRITE` (if Task 0 keeps it) → `EcpSettingsGate` red.
- C7: the DW-2006 pre-check (if built) removed → its leg red with the server stored.
- C8: `osmgmt.ecpsslconnections.delete` dropped from the baseline → `GovernanceBaseline` red; `EcpSettings` `sideBarPosition` 0 → `Navigation` and `navigation.test.mjs` red.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none

- **Planned:** Story 18.21 from Part C of `spec-18-6-licensing-and-ecp.md` at commit `fe080653`, re-validated against the tree at `60d2305182e57f294de7e01d48a017c995865851` (18.20 built: `EcpPort`, `EcpError`, ECP data servers at 17). Covered: Task 0 with its halt conditions and DW-2006's measurement, server and client execution, rosters (position-0 order, the new own pair's rosters, nineteen side-bar entries), tests, ACs C0-C8, Verification in Rule 29's shape, eight decisions and six proposed spine amendments (1 to 3 at the spec gate, 4 to 6 after Task 0).
- **Measured at plan:** read-only on `ocupilot-b-ci` (Design Notes › Measured at plan); no write to any instance, no ECP connection, no admin API write. Vendor and classic sources read from the export and `irissys/`.
- **For the runner at the spec gate:** confirm Decisions 1-8; in particular Decision 3 (`MaxServerConn` settable, never claimed applied), Decision 5 (DW-2006: the `HoldsPair` pre-check with a named gap, or the airtight argument pair) and Decision 7 (AD-22: the three `true` keys enter after 2026-10-04, so the owner's call). The epics.md 18.21 block carries no `DW-2006` bullet yet (Rule 17 1b).
- **Size:** about Story 18.20's (three descriptors, one an unlisted tab; four tools; no new port), so no split is recommended (inference).
- **Tree state:** clean at dispatch (`git status --short` empty); this stage leaves only this spec, uncommitted.
