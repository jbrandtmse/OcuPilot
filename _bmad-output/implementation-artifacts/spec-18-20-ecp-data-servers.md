---
title: 'Story 18.20: ECP data servers'
type: 'feature'
created: '2026-10-03'
status: 'done'
review_loop_iteration: 0
baseline_revision: '9acde1e7a17f5eefb529e401d95d4ca519999fc5'
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-18-context.md'
warnings: ['oversized']
deferred:
  - summary: >-
      SSL/TLS over a disabled %ECPClient configuration may be stored, where the classic dialog refuses it.
    evidence: |-
      EcpPort maps only the vendor's #1454, SSLECPClientNotExist (irislib/%occErrors.inc:1041), so a disabled configuration is likely accepted (inference); AD-8 rules out the %ECPClient read, which needs %Admin_Secure:USE.
      Settle it on a throwaway: seed a disabled %ECPClient, create a probe data server with SSLConfig 1 at 192.0.2.10, read whether it is stored, remove both.
    location: >-
      src/OcuPilot/Port/EcpPort.cls:285
    severity: medium (unverified)
---

<intent-contract>

## Intent

**Problem:** The classic ECP Data Servers page and its dialog (`%CSP.UI.Portal.ECPDataServers`, `%CSP.UI.Portal.Dialog.ECPDataServer`) are still the only place to list, define, edit, delete or change the status of the data servers this instance connects to as an ECP application server. The admin API carries all of it through `ECP.DataServer` (`LIST`, `GET`, `PUT`, `DELETE`, and the async `SERVERACTION`).

**Approach:** Add **ECP data servers** to OS management at side-bar position 17, with a form page, four write tools and one new port, `Port/EcpPort`, which builds the status action's `{Action}` and refuses Normal while the license enables no ECP. A Task 0 on `ocupilot-b-ci` measures every route first, including whether a status change starts any ECP process. Every instance here runs a Community license, so no test opens an ECP connection, and the Normal success path runs through a test seam that never reaches the vendor.

## Boundaries & Constraints

**Always:**

- **Task 0 runs first, on `ocupilot-b-ci` only**, before any descriptor, tool or page (Tasks › Task 0). Its probe objects use the prefix `OCUPROBEECP`, which no other probe prefix matches (`NamespaceWriteProbe`'s `OCUPROBE182` would match an `OCUPROBE1820…` name). It restores what it found and halts on any contradiction.
- **Configuration only, never a connection.** A probe data server points at an address in TEST-NET-1 (`192.0.2.0/24`, as other suites use `192.0.2.10`), which can never connect, with an in-range port: each configuration write runs the vendor's `ECPClient` activation, so on a licensed instance a reachable in-range address might really be contacted (orchestrator ruling, 2026-10-03). The product never contacts a data server beyond what the vendor's own configuration write does, as the classic page (inference). Nothing sends `ECP.DataServer` `DBLIST`, sends `SERVERACTION` with `Action` 3 to the vendor, changes `%Service_ECP`, `Config.ECP`, `Config.config` or `Security.System`, activates a license key, or needs a restart.
- **Screens:**

  | Descriptor | Route | Archetype | Pos | Entity type, id | `classicPage` | `toolIdentifier` |
  | --- | --- | --- | --- | --- | --- | --- |
  | `EcpDataServerList` | `os-management/ecp-data-servers` | `list` | 17 | `ecp-data-server`, `[Name]` | `%CSP.UI.Portal.ECPDataServers` | `osmgmt.ecpdataservers` |
  | `EcpDataServerForm` | `os-management/ecp-data-servers/edit` | `form-page` | 0 | `ecp-data-server` | `%CSP.UI.Portal.Dialog.ECPDataServer` | `osmgmt.ecpdataserverform` (no read) |

  - Both declare OS management's `%Admin_Manage:USE` and `%DB_IRISSYS:READ`, the classic pages' `RESOURCE`, with no own pair. Each carries three prompts.
  - The list reads `{"port":"admin","endpoint":"ECP.DataServer","type":"LIST"}` over `Name, RemoteAddress, RemotePort, Status, MirrorConnection, SSLConfig, BatchMode`. Its primary action is `create`, and its row actions are `changestatus` and `delete`.
  - **The caveat.** The list page shows the line "Each status is what the instance reported when this list was read." Both descriptors' doc comments say these screens rely on the admin API's routes alone, because the harvested ECP status implementation was never identified (epics.md Story 18.20).
- **Tools** (`osmgmt.ecpdataservers.*`):
  - **`create`** (AD-54): name absent, body `{Address, Port, MirrorConnection, SSLConfig, BatchMode}`, composed with the defaults 0, 0 and `false` for the last three. The name goes in the query.
  - **`update`** (AD-4): the complete set read fresh by `GET`, with `Address`, `Port`, `MirrorConnection`, `SSLConfig` and `BatchMode` settable. A stored non-zero `MirrorConnection` is kept and never changed (the classic dialog disables it). `-1` is never offered.
  - **`delete`** (AD-51): `DESTRUCTIVE`, subject `Address,Port`. Its impact names the remote databases whose `Server` is the target, read through Remote databases' declared read. The vendor's 409 #423 answers `ECP.DATASERVER.INUSE`.
  - **`changestatus`** (AD-51), on `EcpPort`:
    - Its argument `Status` is one of `notconnected`, `disabled` or `normal`.
    - Its fresh read is the `LIST` row by name (`READTYPE` `LIST`, `READROWKEY` `Name`), and its subject is `Status`.
    - It is `DESTRUCTIVE`. Its consequence is the classic warning for Not connected and Disabled, and a connect sentence for Normal.
- **`EcpPort`**, for `SERVERACTION`, does this in order:
  1. refuses a caller body;
  2. refuses `normal` with `ECP.LICENSE` when `NetworkEnabled()` (delegating to `RemoteDatabasePort.NetworkEnabled()`) is 0, before any vendor call;
  3. refuses a `Status` equal to the fresh `LIST` row's with `ECP.STATUS.SAME`;
  4. sends `{Action}` (1, 2 or 3).

  `SERVERACTION` joins `QUEUEDWRITES`. Past `ASYNCTIMEOUT` the write answers "started" (202), and its read-back is `unchecked`. A task the vendor fails answers `ECP.STATUS.REFUSED`. The agent's mint refuses `normal` and a same status too, so no such proposal is stored.
- **Field rules, before any vendor write:**
  - Name (create only): `^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$`. The instance stores it in upper case, so a name taken in another case is refused.
  - Address: `LicenseRules.IsAddress`, which is `Config.Host`'s own check, at most 255 characters.
  - Port: an integer from 1 to 65535.
  - `MirrorConnection` 0 or 1; `SSLConfig` 0 or 1; `BatchMode` a boolean.
  - `SSLConfig` 1 is refused `ECP.DATASERVER.SSLCLIENT` while the `%ECPClient` SSL/TLS configuration is absent or disabled, as the classic dialog refuses it. Task 0 decides how (Task 0 step 10).
- **Pairs.**
  - The create, update and delete declare `%DB_IRISSYS:WRITE`, an inference from every `Config.*` write measured in Epics 16 and 18. Task 0 confirms or drops it.
  - The change status declares `%Admin_Operate:USE` for the `AsyncResult` poll (AD-8's endpoint clause), plus any pair Task 0 shows `ServerAction` needs.
  - A missing pair is refused by name before any port call.
- **`CLASSICPAGES`:** the create, update and change status declare `%CSP.UI.Portal.Dialog.ECPDataServer`. The delete, which runs on `%CSP.UI.Portal.ECPDataServers` itself, declares none.
- **Governance:** `create` and `update` are `true`; `delete` and `changestatus` are `false`.
- **Errors** go in the new `Api/EcpError.cls`, dispatched by the `ECP.` prefix in `Api/Error.cls` (two lines, add-only). `ECP.LICENSE`'s sentence, "This instance's license does not include ECP.", is published once in EXPERIENCE.md and pinned equal to the kernel copy. Story 18.21 reuses it.
- **Each test class stands alone.** On a fresh stock instance, in any order, it arranges and removes its own data servers, remote databases, principals and async task rows. It also asserts that no ECP process (job types 31 to 35) is running after it.
- **Contended files are add-only** (Epic 19 is concurrent on slot A). One-line list members and roster counts are unioned by whichever story reaches the feature branch second:
  - `Api/Router.cls`, `Kernel/Governance/Baseline.cls`, `Kernel/Proposal/Prohibited.cls`, `Screen/Gate.cls`, `Screen/Tool/Classification.cls`;
  - `scripts/ci-throwaway.sh`, `ui/angular.json`;
  - `ui/src/app/core/strings.ts`, `ui/src/app/core/navigation.ts`, `ui/src/app/core/screen-actions.ts`, `ui/src/app/shell/command-box.ts`;
  - EXPERIENCE.md;
  - the rosters `ReadTool`, `SurfaceCoverage`, `Wire`, `PortGate`, `Governance`, `GovernanceBaseline`, `ToolDispatch`, `ToolEmit`, `ToolRoundTrip`, `ClassicPageGate`, `MappingDescriptor` and `Test/Prohibited.cls`.

  This story needs no edit to `Screen/Gate.cls`, `navigation.ts` or `command-box.ts`. `screens.generated.ts` and `ToolFields.cls` are regenerated, never hand-merged. EXPERIENCE.md is edited in place and keeps 1005 lines.
- **`strings.ts` holds each value under one key.** Reuse `tableColumnName`, `languageServerFieldAddress`, `sslTestPort`, `taskHistoryColumnStatus`, `sslListLabel` ("SSL/TLS"), `agentGovernanceDisabled` ("Disabled"), `taskPriorityNormal` ("Normal"), `licenseServerAddressHint`, `actionCreate`, `actionSave`, `actionDelete`, `actionCancel` and `auditDatabaseStillRunning`.

**Never:**

- No `DBLIST`, no vendor `SERVERACTION` 3, no ECP connection, no `%Service_ECP` change, no license change, no restart, and no test that needs a non-Community license.
- No rename. Neither the admin API nor the classic dialog has one.
- No `%Api.Admin.*` name outside `AdminPort` and its subclasses. No direct `Config.*`, `SYS.*` or `Security.*` call in product code; test-only `%SYS` seeding is allowed.
- No ECP settings or application servers (Story 18.21), and no change to Remote databases beyond what its existing data-server read already shows.
- No spine or epics.md edit in the implement stage. Task 0 records each AD sentence in `## Spec Change Log` for the runner.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
| --- | --- | --- | --- |
| List | Probe data servers `OCUPROBEECPA` and `OCUPROBEECPB` at `192.0.2.10:1972` | The list and `osmgmt.ecpdataservers.read` answer both rows from one read, `Status` "Not Connected". The caveat line shows. | none |
| Create | Name `ocuprobeecpc`, Address `192.0.2.10`, Port 1972, through the form's Save and through a confirmed proposal, with fewer data servers configured than `AppServerSettings.MaxServers` | `PUT /ecp/data-server?name=ocuprobeecpc` with the five keys. Listed as `OCUPROBEECPC`; the read-back reads `matches`; no ECP process starts. | none |
| Update | `OCUPROBEECPA`, Port 1973, BatchMode on | The complete set read fresh is sent, with two diff rows. A stored non-zero `MirrorConnection` is sent unchanged. | none |
| Field refusals | Name `1 a`, `ocuprobeecpa` (taken), 65 characters; Address empty or `my host`; Port 0, 65536 or `x`; `MirrorConnection` 2, or 0 over a stored 1 | Refused on the field before any vendor write, on both callers | `ECP.DATASERVER.NAME.SHAPE`, `.NAME.TAKEN`, `.ADDRESS`, `.PORT`, `.MIRROR` |
| SSL without a client configuration | `SSLConfig` 1, with `%ECPClient` absent (stock) | Refused on `SSLConfig`; nothing is stored | `ECP.DATASERVER.SSLCLIENT` |
| Server limit, caller holds `%Admin_Secure:USE` | The configured data servers reach `AppServerSettings.MaxServers`, read from `ECP.Settings` (2 on a stock instance, never hard-coded) | The create is refused before any vendor write, with a sentence naming the limit; no `PUT`, no audit event, no log line | 409 `ECP.SERVER.LIMIT` |
| Server limit, caller without `%Admin_Secure:USE` | The same, for a caller holding exactly the create's declared pairs | The create reaches the vendor, whose 500 #456 maps to the same refusal and sentence; nothing is stored, and the vendor leaves its "Create section ECPServer" audit event and one severity-2 log line | 409 `ECP.SERVER.LIMIT` |
| Delete, unused | `OCUPROBEECPB`, through the typed-name dialog or a confirmed proposal | `DELETE /ecp/data-server` is sent, and the row leaves the list | none |
| Delete, in use | Remote database `OCUPROBEECPR` (seeded) uses `OCUPROBEECPA` | The advisory names `OCUPROBEECPR` when the dialog opens or the proposal is minted. The vendor refuses the delete, and the server stays. | 409 `ECP.DATASERVER.INUSE` |
| Disable, real | `OCUPROBEECPA` reads Not Connected; choose Disabled in the dialog, or confirm a proposal | `SERVERACTION {Action:2}` is queued and polled within the bound. The list shows Disabled, the read-back reads `nothingSent` (AD-58: the write sends no value), and `messages.log` gains no ERROR #7846. No ECP process starts. | none |
| Back to Not connected, real | From Disabled | `{Action:1}`; the list shows Not Connected | none |
| Same status | Not connected while it reads Not Connected | Refused at once. No `SERVERACTION` is sent, and no task row is written. | 422 `ECP.STATUS.SAME` on Status |
| Normal, unlicensed (real) | `ocupilot-b-ci` (`NetworkEnabled()` 0) | The dialog draws Normal `aria-disabled` with the license sentence. A screen action or a proposal sent anyway is refused at once, with nothing queued. | 422 `ECP.LICENSE` on Status |
| Normal, licensed (seam) | `^||OcuPilotRemoteLicensed` 1, through `Test/EcpSeamPort` | It passes the pre-check, and the seam records one `SERVERACTION {Action:3}` that never reaches the vendor | none |
| Past the bound (seam) | The seam answers `PORT.TIMEOUT` for the poll | The write answers "started" (202); the read-back is `unchecked` (`running`); the screen and the card say it is still running | none |
| Vendor fails the task (seam) | The seam answers the poll's failed task | Nothing is reported as changed | 409 `ECP.STATUS.REFUSED` |
| Absent target | Update, delete or change status of a server deleted since the read | Refused; nothing is sent | 404 `PORT.NOTFOUND` / target changed |
| Missing pair | Any write without a pair Task 0 sets | 403 naming the pair, with zero port calls | `AUTH.NOPRIVILEGE` |

</intent-contract>

## Code Map

**Vendor.** Exported to `/tmp/epic-18-d6/186/vendor/ECP.DataServer.cls`; re-export with `GetTextAsString` if it is gone. `SYS.ECP` and `Config.ECPServers` are deployed, so their bodies cannot be read.

- **`ECP.DataServer`:**
  - The types are LIST 0, GET 1, PUT 2, DELETE 3, `TYPESERVERACTION` 10 and `TYPEDBLIST` 11 (:10-12). It overrides `Run` (:58), so `AdminPort.ImplementsRead` admits any type (:2771-2780).
  - Every type but LIST needs `name` (:25-30). `ValidateSemantics` answers 404 for a missing server, before queueing (:32-41). `ResourcesOR()` is `%Admin_Manage` (:43-46).
  - **`ShouldRunAsync` is true only for `SERVERACTION`** (:53-56). The caller gets 202. An out-of-range `Action` (`RunServerAction` :114-128 refuses outside 1..3 with 400) and #5026 "Invalid ECP client action type" (→409) surface only as the async task's `Failed` state, never as the HTTP status.
  - `RunList` (:69-83) reads `Config.ECPServers:StatusListSMPFilter`, drops `StatusEnglish`, and turns `MirrorConnection`, `SSLConfig` and `BatchMode` into booleans, so 1 and -1 both read `true`.
  - `RunGet` (:92-99) answers `{Address, BatchMode (bool), MirrorConnection (int), SSLConfig (bool), Port}`.
  - `RunDelete` (:101-112) maps #423 "in use by the following databases" to 409, and anything else to 500.
  - `RunPut` (:130-159) sets only the keys sent, then `Modify` (200) or `Create` (201). The template (:161-170) is `{"Address":"localhost","Port":1972,"MirrorConnection":0,"SSLConfig":0,"BatchMode":true}`; a create requires `Address` and `Port`.
- **`irissys/Config/ECPServers.cls`:**
  - `Name`: at most 64 characters, `CAPITALNAME` 1 (:56).
  - `Address`: `Config.Host`, at most 256.
  - `Port`: `%Integer`, initial 1972, no range.
  - `MirrorConnection`: 0, 1 or -1 (:71-95); `SSLConfig`: 0 or 1, meaning `%ECPClient` (:97); `BatchMode`: `%Boolean`, initial 0. An omitted `BatchMode` stores 0.
  - A Create or Delete records `%System/%System/ConfigurationChange` "… section ECPServer <NAME>" (observed on `ocupilot-b-ci`).
- **`irissys/SYS/ECP.cls`:**
  - `ServerAction(name, action, wait)` (:76-85): 1 is Not Connected, 2 Disabled and 3 Normal.
  - `GetServerConnState` (:50-65): 1 Not Connected, 2 Connection in Progress, 3 Connection Failed, 4 Disabled, 5 Normal, 6 Trouble.
  - `irislib/%syPidtab.inc:51,81-85`: the ECP job types are 31 to 35 (`ECPWorker`, `ECPCliR`, `ECPCliW`, `ECPSrvR`, `ECPSrvW`).
- **Classic pages:**
  - `irissys/%CSP/UI/Portal/ECPDataServers.cls`: `RESOURCE` `%Admin_Manage` (:24); its columns are at :65-71.
  - `irissys/%CSP/UI/Portal/Dialog/ECPDataServer.cls`:
    - fields :83-88; a new server's port defaults to 1972 (:282); only required fields are checked (:179-207); the name is upper-cased (:375);
    - a stored -1 is kept and the mirror box is disabled when non-zero (:220-224, :301, :306-308);
    - SSL is refused while `%ECPClient` is absent or not enabled (:194-203);
    - the status choices depend on the current state: Not Connected offers Disabled and Normal, Disabled offers Not Connected and Normal, Normal offers the other two, anything else offers all three (:326-338);
    - the warning is at :362, and the call `ServerAction(serverName, pProxy.Status, 0)` at :387.
  - `irissys/%CSP/UI/Portal/ECP.cls:224-226`: "The InterSystems IRIS license does not support ECP."

**Ports** (`src/OcuPilot/Port/`):

- `AdminPort.cls`:
  - `MUTATINGTYPES` :429 (doc :125-428), `BODYLESSTYPES` :445, `CONNECTIONREADTYPES` :495 (`ECP.DataServer/DBLIST`, untouched), `UNLOGGEDREFUSALS` :568, `QUEUEDWRITES` :718 (doc :695-717), `SELFQUEUEDTYPES` :727, `ASYNCTIMEOUT` :901 (30 s).
  - `InvokeLocated` :1093-1276, with the 202 → `AwaitTask` step at :1209-1213. `PollTask` :1542, `AsyncTimeout()` :1664.
  - `Sequence` :2861-2956: the vendor's `ShouldRunAsync` at :2915, and the refusal of a mutating type that would queue at :2926-2929.
  - `AwaitTask` :2967-3010: past the bound, `Refuse(503, PORT.TIMEOUT)` at :3002-3006; a failed task goes to `Fail` 500.
  - `Snippet` :3351, `RestStep` :3385.
  - `AdminRoutes.cls:108-110` already routes `ECP.DataServer` `DELETE`, `PUT` (`/ecp/data-server`) and `SERVERACTION` (`POST /ecp/data-server/action`).
- `JournalPort.cls` is the model for `EcpPort`: `COMPOSEDTYPES` :91, `STARTEDHTTP` :95, `Call` :99, `Invoke` :107-126, `Integrity` :235-257 (it refuses a caller body and turns a timeout into 202), `IntegrityBody` :262, `Snippet` :441.
- `LicensePort.cls`: `Call` :42-45 (the seam point), `Refused` :187-198 (a 422 with a violation on its field).
- `RemoteDatabasePort.cls`: `NetworkEnabled()` :244-247, a public, overridable class method. The pre-check that uses it is at :193.
- `Test/RemoteDatabaseListingPort.cls:100-104`: the licensed seam, armed by `^||OcuPilotRemoteLicensed`.

**Tools** (`src/OcuPilot/Screen/Tool/`):

- `Write.cls`:
  - `DESTRUCTIVE` :52, `READTYPE` :57, `WRITETYPE` :62, `SENDSBODY` :67, `FINGERPRINTSUBJECT` :97, `PRECONDITIONFIELD` :105, `CLASSICPAGES` :124, `CREATES` :151, `SCREENACTIONS` :167, `READANSWERS` :180, `READROWKEY` :191, `SCREENVALUES` :217, `PRECONDITIONCODES` :483.
  - `Base.cls`: `ADVERTISED` :50, `PrivilegePairs` :92, `ArgumentPairs` :123.
- **Models:**
  - `LicenseServerCreate.cls`, `LicenseServerUpdate.cls` (`READONLYNAMES` :34, `MergeUpdate` :67) and `LicenseServerDelete.cls` (`StateDiff` :85, `PrivilegePairs` :139).
  - `RemoteDatabaseUpdate.cls` `ArgumentPairs` :131, the argument-pair model.
  - `JournalIntegrityCheck.cls`, an action whose argument goes through `PortQuery` and whose port builds the body.
  - `NamespaceCopyMappings.cls`: `POLLRESOURCE` and `POLLPERMISSION` :73-75, `PrivilegePairs` :201.
  - `BackgroundTaskCancel.cls` `InputSchema` :97-110, the enum model; `Registry.cls` `ValueProblem` :808 enforces it.
- `Classification.cls`: grammar :6-29; entries start at :151, the license entries are at :633-647, and the last entry is at :1221.
- `FieldLists.cls:76-82`: `ECP.DataServer` (no `Name` row). `ToolFields.cls` has no ECP entry; regenerate it with `cd ui && node tools/field-lists.mjs`.

**Descriptor models** (`src/OcuPilot/Screen/Descriptor/`):

- `LicenseServerList.cls` (read :47, position 16) and `LicenseServerForm.cls`.
- `RemoteDatabaseList.cls` (read :51, with `query {"remoteOnly":"1"}`).
- There is no screen-wide caveat key (`Screen/Registry.cls:402`). A static line lives in the page, as `license-key.page.ts:172` does.

**Area handlers** (`src/OcuPilot/Area/OsMgmt/`):

- `LicenseRules.cls`: `NAMEPATTERN` :33, `ADDRESSMAXLENGTH` :36, `IsAddress` :103-110, `IsPort` :114-121, `Problem` :126, `HandleForm` :244-286, `HandleName` :291-322, `Gate` :366-373.
- `LicenseServerSave.cls`: `HandleCreate` :49, `HandleUpdate` :77, `Gate` :284-297.
- `Api/Router.cls`: the UrlMap ends at :231, with the license routes at :226-230 and `POST /screens/:screen/action` at :142. The wrappers end at :1688, and the class at :1693.
- `Api/LicenseError.cls` is `EcpError`'s model (`Codes` :54, `ViolationCodes` :61, `FieldOf` :67, `ReasonFor` :78). `Api/Error.cls` dispatches `LICENSE.` at :1225 (`ReasonForToolCode`) and :1423 (`ReasonForViolation`). Error.cls holds 989 of the compiler's 1,000 parameters, so it gets no new parameter.
- `Api/ScreenAction.cls:357-358, 375` and `Kernel/Proposal/Confirm.cls:509-511, 530` turn a 202 into `ReadBack.Running()` (`Kernel/Proposal/ReadBack.cls:196-200`) and `continues: true`.

**Kernel:**

- `EntityType.cls:69` `TYPES` holds 48, pinned at `Test/Descriptor.cls:1739`. `EntityRef.cls:59` `IDRULES` holds 24 pairs.
- `Proposal/Prohibited.cls`:
  - `COVEREDTYPES` :250 holds 37;
  - the type guard is at :1047, and the license branch through `ReviewedFewOnly` at :1220-1224 (defined at :2888);
  - `PermittedChangeFields` :820 (:851) and `PermittedCreateFields` :944 (:966); `LicenseServerFields()` :2287.

  No arm concerns ECP or an address.
- `Proposal/Impact.cls`:
  - kinds :31-52; tool-name parameters such as `REMOTEDATABASEDELETETOOL` :55; `LOCALDATABASEDESCRIPTOR` :103;
  - `Of` :145, `KindOf` :236-243, `Guarded` :366 (it takes a match field and compares case-insensitively), `ListRows` :528.
- `Governance/Baseline.cls`: OS management's block is at :21-64, in name order. `osmgmt.ecpdataservers.*` goes between `devices.update` (:29) and `globalmappings.create` (:30).

**Client** (`ui/src/app/`):

- `shell/screen-outlet.ts`: `DESCRIPTOR_PAGES` :138-219. The last Epic 18 entry is :203; Epic 19's run from :204.
- `shell/screen-action-handler.ts`:
  - `SCREEN_ACTION_DESCRIPTORS` :64-102 and the named constants :104-245;
  - `UNDRAWN_ACTIONS` :276-295, `DESTRUCTIVE_ACTIONS` :343, `IMPACT_ACTIONS` :349-358, `DESTRUCTIVE_CONSEQUENCES` :369-400 (the license entry is at :398-399).
- `areas/os-management/`:
  - `lock-list.page.ts` (it wraps `<app-list-page />`, registers its own row action, and sends through the handler's `sendFor`) and `lock-remove-dialog.ts` (radios at :61-81 with `aria-disabled` reasons at :44-46, :70-78, :245-246): the change status page and dialog's models;
  - `license-server-form.page.ts`/`.store.ts` and `license-server-actions.ts`: the form and Create models;
  - `language-server-form.page.ts:200-217`: a checkbox;
  - `database-operation.ts:17-26`: the running and finished lines.
- `core/impact.ts`: `ImpactKind` :13-20, `ImpactPartName` :22-33, `IMPACT_PARTS` :37-49, `PHRASES` :132ff.
- `core/screen-actions.ts`: `DESCRIPTOR_ACTION_LABELS` :151-224. `core/proposal-view.ts` holds the consequence codes.
- `app.ts`: the injections :339-342 and the sign-out resets :666-667.
- `core/strings.ts`: `} as const` is at :5093. `ui/tools/strings.test.mjs` sets a literal bound of 2500 at :581-584, checks one key per value at :621-629, and checks EXPERIENCE.md citations at :816.
- `ui/angular.json:54` sets `maximumWarning` to 2677kB. It is pinned at `ui/tools/angular-json.test.mjs:458`, whose last history row is :443-445.

**EXPERIENCE.md** (`_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md`, 1005 lines):

- :164: the OS management side bar, sixteen entries ending "License servers (Stage 2, Story 18.6)".
- :173: Dialogs.
- :375: License key and License servers' Fixed strings.
- :479: the delete bodies.
- :577: the impact phrases.

**Rosters.** Each count is the current tree's. Re-derive each change from its class's red, never by hand.

- ObjectScript (`src/OcuPilot/Test/`):
  - `Descriptor.cls`: `ReadShapes` :67-166 (append after :164), entity count :1739 (48);
  - `ReadTool.cls` :93 (245), :94 (alphabetical names), :112;
  - `SurfaceCoverage.cls` :54-335 (screen rows near :184-186, tool rows near :327-330);
  - `EndpointCoverage.cls` :73-247, one probe per route;
  - `Navigation.cls` :488 (40), with the per-index list at :489-491;
  - `Wire.cls`, which peels :711-722, the remainder at :723;
  - `WireSecurityRead.cls`: three literals at :565, :572 and :575;
  - `WireAreaAnyScreen.cls:271` (16 listed);
  - `PortGate.cls:28` `ROSTER` (28);
  - `ClassicPageGate.cls` `OWNPAIRS` :74 (48; the message at :146);
  - `MappingDescriptor.cls:23` `CLASSICROSTER` (the doc at :118);
  - `ToolRoundTrip.cls:66` `REFUSEEMPTY`;
  - `Prohibited.cls` (test) :232 (37);
  - `GovernanceBaseline.cls:15` `DISABLED` (22);
  - `Governance.cls` :36-40 and :126-131;
  - `ToolDispatch.cls:169`;
  - `ToolEmit.cls` :216-240, the per-tool pair exceptions (the poll pair at :220-223);
  - `AdminPortAsync.cls:98`, the exact `QUEUEDWRITES` pin;
  - `PortFixture.cls:21`, a copy of `MUTATINGTYPES`.
- **Position-0 order.** A screen at position 0 sorts by descriptor class name (`Screen/Registry.cls:3436`). `EcpDataServerForm` therefore lands between `DeviceForm` and `GlobalMappingForm` in `Navigation`, `Wire`, `WireSecurityRead` and the client route lists, not at the tail.
- Unaffected, because these screens declare no own pair: `LanguageServerWire.cls:282` and `ui/browser/language-servers.browser-spec.mjs:343-373`.
- Client:
  - `ui/tools/navigation.test.mjs` :152-212 and :320-348;
  - `navigation-wire.test.mjs` :90-379 and :714-718;
  - `shell/rail-wire.spec.ts` :87-384;
  - `shell/area-verdict.spec.ts` :50-73 and :156-176;
  - `ui/tools/impact.test.mjs` (the `remote-database-delete` leg at :197-200 is the model);
  - `proposal-view.test.mjs`;
  - `self-protection.test.mjs` (`.cls` sentences pinned equal to strings keys, :71-131).
- Browser lists pinning sixteen OS management entries:
  - `license-usage.browser-spec.mjs:130-154` and `remote-databases.browser-spec.mjs:300-320` (`deepEqual`);
  - `journals.browser-spec.mjs:278`, `journal-settings.browser-spec.mjs:228` and `license-key.browser-spec.mjs:218` (length);
  - `license-servers.browser-spec.mjs:249-250` (length, then `[15]`).

  `local-databases` (`slice(0, 11)`) and `namespaces` (`slice(0, 7)`) are unaffected.
- CI: `scripts/ci-throwaway.sh`:
  - `OCUPILOT_ALLOW_PRINCIPALS` :312 (its classes at :217-311);
  - `OCUPILOT_ALLOW_DATABASE_CONFIG` :477, which already arms the `OCUPROBE1816*` data servers (:470-473);
  - `OCUPILOT_ALLOW_LICENSE_CONFIG` :498.

  `ui/tools/ci.test.mjs:2096-2206` derives the rosters itself, so it needs no edit.

**Test models** (`src/OcuPilot/Test/`):

- `RemoteDatabaseProbe.cls`: `SeedServer` :79 (`Config.ECPServers.Create` in `%SYS`; nothing is contacted), `SeedPrincipal` :247, `RemoveAll` :275, `Run` :428, `RunAs` :461, `Snapshot` :602 (the ECP status, the process `JobType`s, `Config.ECP`, the license, log counts), `Diff` :730.
- `DatabaseWriteProbe.cls` `AddRemote` :342, which seeds a remote database on a data server.
- `LicenseProbe.cls` `LicenseFacts` :98, reused for the license snapshot.
- `JournalProbe.cls` `RemoveProbeTaskRows` :672, which deletes `%Api.Admin.Util.AsyncTask` rows by the probe user's name.
- `LicenseSeamPort.cls` (`Call` :18, `Arm` :58, `Clear` :64, `Calls` :70), `LicenseActionFixture.cls`, `LicenseRulesFixture.cls`, `LicenseSaveFixture.cls`, `SeamLicense*.cls`: the seam and fixture shape.
- `DatabaseQueuedPort.cls` (`AsyncTimeout` 0 :20, `PollTask` :27, `Polls` :46) and `DatabaseTimeoutPort.cls` (`Call` :11 answers 503 `PORT.TIMEOUT`): the started seams.
- Arming: a class declares `Parameter ARMINGVARIABLE` and checks `$System.Util.GetEnviron` in `OnBeforeAllTests` (`LicenseServerWrite.cls:18, 49-50`; two variables in `LicenseWriteGate.cls:20, 23, 72`).
- `ui/browser/license-servers.browser-spec.mjs` and `remote-databases.browser-spec.mjs`: the throwaway guard (:98-100, :128-131), `iris()` (:65, :95), `removeAll()` (:82, :112) and `assertStructure` (:191, :263).

## Tasks & Acceptance

**Task 0, the implement stage's first task, before any descriptor, tool or page.** Run it on `ocupilot-b-ci` only, loading with `/tmp/epic-18-d6/load-throwaway.sh` (no restart). Keep evidence under `/tmp/epic-18-d6/1820/t0/`. Record each result under Design Notes › Measured at implement, and each AD sentence in `## Spec Change Log` for the runner.

1. **Plumbing:**
   - `Port/AdminPort.cls`, add-only:
     - `ECP.DataServer/PUT`, `ECP.DataServer/DELETE` and `ECP.DataServer/SERVERACTION` join `MUTATINGTYPES`, with one doc paragraph, and also `Test/PortFixture.cls:21`'s copy.
     - `ECP.DataServer/DELETE` joins `BODYLESSTYPES`.
     - `ECP.DataServer/SERVERACTION` joins `QUEUEDWRITES`, with one doc sentence, and `Test/AdminPortAsync.cls:98`'s pin.
   - Write `src/OcuPilot/Test/EcpProbe.cls` on the `RemoteDatabaseProbe` model:
     - `SeedServer`, and `SeedRemote` (a remote database on a probe server, the `AddRemote` model);
     - `SeedPrincipal`, for the user `OCUPROBEECPUSER` and its role;
     - `Run` and `RunAs`;
     - `Snapshot`, which holds `LicenseProbe.LicenseFacts`, the `Config.ECPServers` rows with `StatusList` and `GetServerConnState`, every process's `JobType`, `Config.ECP`, `Config.config`'s ECP values, `%Service_ECP`, `messages.log` and `alerts.log` counts, the monitor state, and the async task rows whose `Username` starts `OCUPROBEECP`;
     - `Diff`;
     - `RemoveAll`, which removes, in order, probe remote databases, probe data servers, the principal, and probe task rows;
     - `EcpJobs()`, the count of processes whose job type is 31 to 35 or whose routine is an ECP daemon's (`ECPWorker`, `ECPCliR`, `ECPCliW`, `ECPSrvR`, `ECPSrvW`).
2. **Take S0.**
3. **Reads.**
   - a. `LIST`, and `GET` in lower and upper case, each timed, on a server seeded through `%SYS`. Record `Status`'s text and every key's JSON type.
4. **Writes, through `AdminPort` as `_SYSTEM`:**
   - b. `PUT name=ocuprobeecpa {Address:"127.0.0.1", Port:1972}`. Record the answer (expect 201), the stored name, `GET` in both cases, the `LIST` row, and what `BatchMode`, `MirrorConnection` and `SSLConfig` stored.
   - c. Three more `PUT`s:
     - `{Port:1973}` alone: are the other keys kept?
     - `{BatchMode:true}` alone.
     - the fresh `GET` body sent back unchanged, with `SSLConfig` as `GET` answers it, a boolean. Record its answer, its event and the stored values.

     Then read the target back as AD-58 does, and record whether a sent `SSLConfig` 1 compares equal to a read `true`.
   - d. The vendor's answer to each of these, deleting anything the probe stored:
     - an empty or absent `Address` on a create, and an absent `Port`;
     - ports 0, 70000 and `"x"`;
     - a name with a space or a dot, and a 65-character name;
     - `MirrorConnection` 2;
     - `SSLConfig` 1 while `%ECPClient` is absent.
   - e. With `SeedRemote` using the server: `DELETE`, expecting 409 #423, timed. Then remove the remote database and `DELETE` again, expecting 200. Then `DELETE` a third time, expecting 404.
5. **The status action.** Use a fresh probe, `OCUPROBEECPS`, reading Not Connected (state 1). Before and after each step, sample `EcpJobs()`, the process list, the probe's `GetServerConnState`, `messages.log` lines and the monitor state.
   - f. `SERVERACTION {Action:2}`: record the answer, the poll, the duration against `ASYNCTIMEOUT`, the status after (expect Disabled, state 4), the task row and `messages.log`.
   - g. `{Action:1}`, back to Not Connected; then `{Action:1}` again, a same-state action. Record the failed task's shape (is it #5026?) and how `AdminPort` answers it.
   - h. `{Action:4}`: the failed task's shape. The vendor refuses it before calling `ServerAction`.
   - i. `{Action:2}`, then `DELETE` while Disabled.
   - j. Wait at least 70 s after the last action (one 5 s reconnect plus a 60 s trouble cycle), then sample again.
   - **`Action` 3 is never sent.**
6. **Audit**, with auditing on: the events b, c, e, f and g wrote. In particular, whether a `PUT` records "Modify section ECPServer" and whether `SERVERACTION` records any event.
7. **Pairs.** Use a principal holding exactly `%Admin_Manage:USE` and `%DB_IRISSYS:READ`, plus the install namespace's code read.
   - Run a, b, the first `PUT` of c, e (unused) and f/g.
   - Repeat each refused step with each candidate alone: `%DB_IRISSYS:WRITE`, `%Admin_Operate:USE` and `%Admin_Secure:USE`. For f/g, also try `%DB_IRISSYS:WRITE` and `%Admin_Operate:USE` together.
   - As the same principal, alone and with `%Admin_Secure:USE`, run `Security.SSLConfig` `GET name=%ECPClient`.
   - Record every answer, and whether a least-privileged caller's finished task row is left behind.
8. **Cleanup proof:** run `RemoveAll`, then take S2. It must equal S0 apart from counters, the declared `messages.log` lines, and the monitor state. If the monitor state moved, clear it with `$SYSTEM.Monitor.Clear()`.
9. **HALT** with status `blocked`, blocking condition `intent gap: observation contradicts the plan: <what>`, and nothing built, if any of these hold. Record the step-7 evidence first for any pair halt.
   - At any step, `EcpJobs()` is above 0, or `messages.log` gains an ECP connection line other than each configuration write's two declared severity-0 lines (`Activating Network`, `ECP-<n> sys <m> - '<NAME>' (address:port)`; no process starts, inference). Step d's port-70000 probe's failure lines are a Task 0 probe artifact (orchestrator ruling, 2026-10-03), and no test sends an out-of-range port to the vendor.
   - A status changes on a server other than the target, or the target lands anywhere but the requested state.
   - A license fact, `%Service_ECP`, `Config.ECP` or `Config.config` changes.
   - A route cannot be reached through `AdminPort`, or `SERVERACTION` does not queue.
   - f or g takes longer than `ASYNCTIMEOUT`.
   - A read takes more than 2 s.
   - The vendor deletes a data server that a remote database uses.
   - A write needs a pair outside these: the screen's set; `%DB_IRISSYS:WRITE` for a `Config` write; `%Admin_Operate:USE` for the poll.
   - A probe task row cannot be removed.
   - S2 differs from S0 beyond the declared differences.
10. **Resume here after the orchestrator's ruling (2026-10-03).** Steps 1 to 9 ran (Design Notes › Measured at implement); the plumbing patch `_bmad-output/implementation-artifacts/spec-18-20-task0-plumbing.patch` is applied first (`git apply`), with `EcpProbe`'s probe addresses moved to `192.0.2.10`. The rulings: the port-70000 line is a probe artifact, and `EcpRules` refuses any port outside 1 to 65535 (0 and 70000 included) with zero vendor calls; the create refuses 409 `ECP.SERVER.LIMIT` before any vendor write once the configured data servers reach `AppServerSettings.MaxServers` (read from the instance), tests hold at most two probe servers, and one test fills to the limit and pins the refusal; each write's two severity-0 lines are declared; the vendor's #1454 (`SSLConfig` 1 without `%ECPClient`) maps to `ECP.DATASERVER.SSLCLIENT`, never a 500, and no tool declares `%Admin_Secure:USE`.
11. **Otherwise, set these from the record:**
    - **Each tool's pairs.** Drop `%DB_IRISSYS:WRITE` where step 7 shows it is not needed. Add to the change status any pair f/g needed.
    - **The SSL rule.**
      - If d's vendor refuses `SSLConfig` 1 without `%ECPClient`, `EcpPort` maps that refusal to `ECP.DATASERVER.SSLCLIENT` and the tools declare no pair for it.
      - Otherwise, `EcpPort` reads `Security.SSLConfig` `GET name=%ECPClient` (404 or `Enabled` false refuses it) whenever a `PUT` sends `SSLConfig` 1. The create and update then declare `%Admin_Secure:USE` as an argument pair while `SSLConfig` is 1, only if step 7 shows the read needs it.
    - **Value types.** If c's comparison fails, `EcpPort` sends `SSLConfig` and `MirrorConnection` as numbers and the update reads them so; declare a `compare` only if that is not enough.
    - **`ECP.STATUS.REFUSED`'s detection**, from g and h's failed-task shape.
    - **`ECP.DataServer` `DELETE`'s 409 log line.** Keep the generic logging; record whether it raised the monitor state.
    - **Each AD-15/AD-53 named case**, wherever step 6 found no vendor event.
    - **The canonical name.** The id rule is `foldcase` if b confirms the upper-case store and the any-case `GET`.

**Execution (server):**

- **`src/OcuPilot/Port/EcpPort.cls`** (new). It extends `AdminPort`, names no vendor class, and follows `JournalPort`'s shape.
  - `COMPOSEDTYPES` `ECP.DataServer/SERVERACTION`; `STARTEDHTTP` 202; `STATUSACTIONS` `notconnected:1,disabled:2,normal:3`.
  - `ClassMethod NetworkEnabled()` answers `##class(OcuPilot.Port.RemoteDatabasePort).NetworkEnabled()`; it is the seam.
  - `Call`: one overridable wrapper over `AdminPort.Invoke`.
  - **`Invoke` for `SERVERACTION`**, in this order:
    - refuse a caller body;
    - map `Status` through `STATUSACTIONS` (else `TOOL.ARGUMENTS`);
    - refuse `normal` with 422 `ECP.LICENSE` on `Status` when `'..NetworkEnabled()`;
    - read the `LIST` row by name (404 when absent) and refuse a matching status with 422 `ECP.STATUS.SAME` on `Status`, comparing "Not Connected", "Disabled" and "Normal" exactly;
    - send `{Action}`;
    - answer `PORT.TIMEOUT` as OK, 202 with no result;
    - answer a failed task as 409 `ECP.STATUS.REFUSED`, logging the vendor reason and returning none.
  - **For `PUT`:** the SSL rule (Task 0 step 10) and the value types.
  - **For `DELETE`:** a 409 becomes 409 `ECP.DATASERVER.INUSE`.
  - **`Snippet`** mirrors every branch (AD-59):
    - a `normal` on an unlicensed instance renders no step, with the license sentence as its comment;
    - otherwise one `POST /ecp/data-server/action?name=<id>` step with `{"Action":n}`;
    - `PUT` and `DELETE` fall to `##super`.
- **Tools** (`src/OcuPilot/Screen/Tool/`, new; descriptor `EcpDataServerList`; port `EcpPort`):
  - `EcpDataServerCreate.cls`: `CREATES` 1, `PERMITTEDFIELDS` and the composed body as in Boundaries, `REQUIREDFIELDS` `Address,Port`, `CLASSICPAGES`, `ArgumentProblem` through `EcpRules.Problem(…, "create")`, `PrivilegePairs` as set by Task 0, and `ArgumentPairs` if Task 0 step 10 says so.
  - `EcpDataServerUpdate.cls`: `MergeUpdate` over the fresh `GET`. `ArgumentProblem` adds `ECP.DATASERVER.MIRROR` when a stored non-zero `MirrorConnection` would change.
  - `EcpDataServerDelete.cls`: `WRITETYPE` `DELETE`, `SENDSBODY` 0, `DESTRUCTIVE` 1, `SCREENACTIONS` `delete`, `READANSWERS` `Address,Port,MirrorConnection,SSLConfig,BatchMode`, `PRECONDITIONFIELD` `Address`, `FINGERPRINTSUBJECT` and `REMOVALROWS` `Address,Port`, and `StateDiff` on the `LicenseServerDelete` model.
  - `EcpDataServerChangeStatus.cls`:
    - `WRITETYPE` `SERVERACTION`, `SENDSBODY` 0, `DESTRUCTIVE` 1;
    - `READTYPE` `LIST` and `READROWKEY` `Name`; `READANSWERS` `Status,RemoteAddress,RemotePort`; `PRECONDITIONFIELD` and `FINGERPRINTSUBJECT` `Status`;
    - `SCREENACTIONS` `changestatus`, `SCREENVALUES` `changestatus=Status`;
    - `InputSchema` with `Status` required, with the enum taken from `EcpPort.STATUSACTIONS`;
    - `PortQuery` passes `Status`;
    - at the mint (`Kernel/Proposal/Mint.cls:200-240`): a `MergeUpdate` override refuses `ECP.STATUS.SAME` when the requested status equals the fresh row's and writes the card's one row `Status: <current> → <requested label>`; `ArgumentProblem` refuses `normal` while `EcpPort.NetworkEnabled()` is 0; `StateDiff` answers no row, as `AuditPurge.StateDiff` (:91) does. The port's own checks at the write are what refuse a screen call;
    - `POLLRESOURCE`/`POLLPERMISSION` `%Admin_Operate:USE`, and `CLASSICPAGES`;
    - `Consequence` answers `ECP.STATUS.DISCONNECT` for `notconnected` and `disabled`, and `ECP.STATUS.CONNECT` for `normal`.
  - `Classification.cls` (add-only): entries for the create and update over `ECP.DataServer`, every field `ordinary`. Add an entry for the delete or the change status only if `field-lists.mjs --check` asks. Then regenerate `ToolFields.cls`.
- `src/OcuPilot/Kernel/EntityType.cls`: `ecp-data-server` joins `TYPES`, with its doc line. `EntityRef.cls` adds `ecp-data-server:foldcase`.
- `src/OcuPilot/Kernel/Proposal/Prohibited.cls` (add-only):
  - `TYPEECPDATASERVER`, `COVEREDTYPES`, the guard at :1047 and a `ReviewedFewOnly` branch;
  - create and change lists `Address,Port,MirrorConnection,SSLConfig,BatchMode`, plus `Status` on the change list only if `Test/Prohibited` requires the action's argument (as `license-key`'s `Key` was);
  - no arm.
- `src/OcuPilot/Kernel/Proposal/Impact.cls`:
  - the kind `ecp-data-server-delete`, its tool-name parameter and a `KindOf` line;
  - a `REMOTEDATABASEDESCRIPTOR` parameter (`OcuPilot.Screen.Descriptor.RemoteDatabaseList`);
  - a branch `Guarded(<that>, "remoteDatabases", "Name", tId, .tPart, "Server")`.
- `src/OcuPilot/Kernel/Governance/Baseline.cls` (add-only, in name order): `osmgmt.ecpdataservers.changestatus` false, `.create` true, `.delete` false, `.update` true.
- `src/OcuPilot/Area/OsMgmt/EcpRules.cls` (new, on the `LicenseRules` model):
  - `NAMEPATTERN`, `Problem` (name shape and taken, `LicenseRules.IsAddress`, `LicenseRules.IsPort`, the enums, `MIRROR`), and `Shape`;
  - `HandleForm()` serves `GET /ecp-data-server/form?name=`. It answers the `GET` fields, the `LIST` row's `Status` and `licensed` (`EcpPort.NetworkEnabled()`), with an empty set and port 1972 for a create.
  - `HandleName()` serves `GET /ecp-data-server/name?name=`.
  - `Gate` covers both routes.
- `src/OcuPilot/Area/OsMgmt/EcpDataServerSave.cls` (new, on the `LicenseServerSave` model): `POST /ecp-data-server` and `PUT /ecp-data-server/:id` go through the tools (AD-55).
- `src/OcuPilot/Api/Router.cls` (add-only): the four routes and their thin wrappers, with `/ecp-data-server/form` and `/name` before `/:id`.
- `src/OcuPilot/Api/EcpError.cls` (new): `Codes()`, `ViolationCodes()`, `FieldOf` and `ReasonFor`. `Api/Error.cls` gains one `ECP.` line at :1225 and one at :1423 (add-only). The codes:
  - `ECP.LICENSE` (422, Status): "This instance's license does not include ECP."
  - `ECP.STATUS.SAME` (422, Status): "The data server already has that status."
  - `ECP.STATUS.REFUSED` (409): "The instance refused that status change."
  - `ECP.DATASERVER.NAME.SHAPE` (422, Name): "Use up to 64 letters, digits, hyphens and underscores, starting with a letter or digit."
  - `ECP.DATASERVER.NAME.TAKEN` (422, Name): "An ECP data server of that name already exists."
  - `ECP.DATASERVER.ADDRESS` (422, Address): "Enter the data server's host name or IP address."
  - `ECP.DATASERVER.PORT` (422, Port): "Enter a port from 1 to 65535."
  - `ECP.DATASERVER.MIRROR` (422, MirrorConnection): "A data server's mirror connection cannot be turned off once it is set."
  - `ECP.DATASERVER.SSLCLIENT` (422, SSLConfig): "Create and enable the %ECPClient SSL/TLS configuration before using SSL/TLS."
  - `ECP.DATASERVER.INUSE` (409): "Remote databases use this data server. Delete them or move them to another data server first."
- `src/OcuPilot/Screen/Descriptor/EcpDataServerList.cls` and `EcpDataServerForm.cls` (new), as in Boundaries:
  - the list's columns are Name (`name`), Address (`RemoteAddress`, `identifier`), Port (`RemotePort`, `number`), and Status, Mirror connection, SSL/TLS and Batch mode (each `status`, the kind a boolean column takes, as `SslConfigList`'s `Enabled` does);
  - its empty-state keys (`ecpDataServerListEmpty`, `ecpDataServerListEmptyAgent`) and three prompts;
  - the caveat in each doc comment.

**Execution (client)** (`ui/src/app/`):

- **`areas/os-management/ecp-data-server-list.page.ts`** (new, with a spec), registered in `DESCRIPTOR_PAGES`, on the `lock-list.page.ts` model:
  - it shows `<app-list-page />` and the caveat line;
  - it registers `changestatus` on the selected row, reads `/api/ocupilot/ecp-data-server/form?name=<id>` for `Status` and `licensed`, and opens the dialog;
  - it sends the choice through the handler's `sendFor` with `values.Status`;
  - a refusal stays in the dialog. While the write runs it shows the running line (`database-operation.ts`), and a `continues` answer shows "Still running on the instance. It finishes in the background." (`auditDatabaseStillRunning`). An applied change closes the dialog, and the change event re-reads the list.
- **`areas/os-management/ecp-data-server-status-dialog.ts`** (new, with a spec), on the `lock-remove-dialog.ts` model:
  - the title is "Change the status of <name>", followed by the current status;
  - a radio fieldset offers Not connected, Disabled and Normal. The current one is `aria-disabled` with "This is its current status.", and Normal is `aria-disabled` with the license sentence when `licensed` is false. A disabled choice stays focusable, and neither a click nor an arrow key selects it;
  - the chosen consequence sentence, and a destructive "Change status" button. There is no typed name, because nothing is removed.
- **`areas/os-management/ecp-data-server-form.page.ts`** and **`.store.ts`** (new, with specs; the license server form model):
  - Name appears on a create only; Address is labeled "Host name or IP address"; Port defaults to 1972 on a create;
  - "Mirror connection" is a checkbox, disabled on an edit when the stored value is non-zero, with the hint "Connects to the mirror's primary. Once set, it cannot be turned off here.";
  - "Use SSL/TLS" is a checkbox with the hint "Uses the %ECPClient SSL/TLS configuration.", and "Batch mode" is a checkbox;
  - the unsaved-changes guard applies, and each refusal renders on its field.
- `areas/os-management/ecp-data-server-actions.ts` (new, with a spec): Create opens the form.
- `shell/screen-outlet.ts`: the two `DESCRIPTOR_PAGES` entries, after :203.
- `shell/screen-action-handler.ts` (add-only):
  - the descriptor constant;
  - `changestatus` in `UNDRAWN_ACTIONS`;
  - `IMPACT_ACTIONS` `[ECP_DATA_SERVER_LIST]: ['delete']`;
  - a `DESTRUCTIVE_CONSEQUENCES` entry for the delete's body.
- `core/screen-actions.ts`: `DESCRIPTOR_ACTION_LABELS` `changestatus: STRINGS.ecpDataServerChangeStatus`.
- `core/proposal-view.ts`: the codes `ECP.STATUS.DISCONNECT` and `ECP.STATUS.CONNECT`.
- `core/impact.ts`: the kind `ecp-data-server-delete`, its part `remoteDatabases`, and its four phrases.
- `app.ts`: the actions and form store injections, and the store's sign-out reset.
- `core/strings.ts` (add-only, after :5092): each new key under its `/** EXPERIENCE.md:n */` line. Raise `strings.test.mjs:581-584`'s bound only if the literals cross it.
- Regenerate `core/screens.generated.ts` with `cd ui && node tools/screen-mirror.mjs`.
- `ui/angular.json`: re-base `maximumWarning` under DW-1166 to the measured initial total, rounded up to the next kB, with its history row in `angular-json.test.mjs`. Stop and ask above 3800kB.
- **EXPERIENCE.md, in place, keeping 1005 lines.** Then run `cd ui && npm run test:tools`.
  - :164 gains "· ECP data servers (Stage 2, Story 18.20)", the seventeenth entry.
  - :173 gains the dialog "change an ECP data server's status (Story 18.20: Not connected, Disabled or Normal, the current one and an unlicensed Normal drawn disabled with their reasons, then the destructive treatment with no typed name)", and its delete list gains "ECP data server".
  - :375 gains "; and ECP data servers (Story 18.20): …", tagged `[ADDED <date> - Story 18.20]`, with every new literal:
    - the screen label "ECP data servers" and the entity label "ECP data server";
    - the empty state "No ECP data servers on this instance." and its agent phrase "create an ECP data server";
    - "Mirror connection", "Use SSL/TLS", "Batch mode", the two form hints, "Change status", "Change the status of <name>", "Current status: <status>", "Not connected" and "This is its current status.";
    - the license sentence;
    - the two consequences: "Setting a data server to Not connected or Disabled sends an error to every application awaiting its replies, purges its cached blocks, releases its locks and rolls back its transactions." and "Setting this data server to Normal connects this instance to it.";
    - the caveat line;
    - each screen's three prompts.
  - :479 gains "; then Delete on an ECP data server (Story 18.20), whose typed name is the server's name and whose advisory is its impact line naming the remote databases that use it", with the body "Deleting this ECP data server removes it from this instance's configuration. This cannot be undone."
  - :577 gains the `remoteDatabases` phrases: "<n> remote databases use it and must be deleted or moved first: <names>", "1 remote database uses it and must be deleted or moved first: <names>", "no remote database uses it", and "which remote databases use it was not checked".

**Rosters and CI:**

- Extend every roster in Code Map › Rosters, with the position-0 order as noted. The six browser lists grow from 16 to 17 entries.
- `scripts/ci-throwaway.sh` (add-only):
  - a new `OCUPILOT_ALLOW_ECP_CONFIG`, with its `# classes:` line naming the classes that write data servers or change their status;
  - those classes on `OCUPILOT_ALLOW_PRINCIPALS` and `OCUPILOT_ALLOW_DATABASE_CONFIG` where they seed a principal or a remote database.

**Tests:**

- `Test/EcpProbe.cls`: Task 0's helper, its seeding and `RemoveAll`, run before all tests, after each and after all.
- `Test/EcpSeamPort.cls`: an `EcpPort` subclass.
  - `NetworkEnabled` answers 1 when `^||OcuPilotRemoteLicensed` is set.
  - `Call` records every pair and body in `^||OcuPilotEcpSeam("calls")`.
  - **A `SERVERACTION` with `Action` 3 never reaches the vendor:** armed, it answers finished; unarmed, it answers 500.
  - Arm modes `started` (answers `PORT.TIMEOUT`) and `failed` (answers a failed task).
  - Every other call goes to `##super`.
  - Add the fixtures and `SeamEcp*` tool classes on the 18.6 pattern.
- `Test/EcpDataServerWrite.cls`, with real vendor writes:
  - the matrix's create, update, refusal, SSL and delete legs, on both callers;
  - the read-back;
  - the canonical name;
  - the in-use delete, whose impact names the remote database first and which is refused;
  - after the class, `EcpJobs()` 0 and the license facts as at S0.
- `Test/EcpDataServerStatus.cls`:
  - the real Disabled and then Not connected, through both the screen action and a confirmed proposal: the list shows each, the read-back matches, and no ERROR #7846 appears (`LinesAfter`);
  - the same status, with zero `SERVERACTION` calls;
  - Normal unlicensed, refused with no call and no task row;
  - Normal licensed through the seam, with one `{Action:3}` recorded;
  - started, with the read-back `unchecked` and `continues`;
  - failed;
  - `EcpJobs()` 0 after each test.
- `Test/EcpWriteGate.cls`, with `EcpWriteGateProbe.cls`: every declared pair is refused by name with zero port calls, and both form routes' gates hold.
- `Test/EcpDescriptor.cls`:
  - the two descriptors' routes, positions, pairs, classic pages, prompts, entity type, id rule and caveat;
  - `EcpError`'s codes and sentences;
  - the four baseline keys;
  - the impact kind;
  - `EcpPort.Snippet`'s branches;
  - `EcpPort.NetworkEnabled` delegating to `RemoteDatabasePort`.
- **Client tests:**
  - component specs for the list page, the status dialog (each choice's disabled reason, the current status, unlicensed Normal, the consequence per choice, refusals), the form page and store, and the actions;
  - `ui/tools/impact.test.mjs`, a leg for the new kind;
  - `proposal-view.test.mjs`, the two codes;
  - `self-protection.test.mjs`, one leg holding `EcpError`'s `ECP.LICENSE` reason equal to its strings key.
- **`ui/browser/ecp-data-servers.browser-spec.mjs`** (new; it refuses a non-throwaway, as `license-servers.browser-spec.mjs` does):
  - the seventeenth entry and the caveat line;
  - create, edit and delete a probe server through the UI, the delete through the typed-name dialog;
  - the in-use advisory naming the seeded remote database;
  - Change status to Disabled and back through the dialog, with Normal drawn disabled with the license sentence;
  - the DW-1337 gate in both themes on the list, the form and the dialog;
  - cleanup over `docker exec`, with no ECP process afterwards.

**Acceptance Criteria:**

- **B0:** Given `ocupilot-b-ci`, when the implement stage starts, then Task 0 records the payloads, durations, effects, pairs and audit events of `ECP.DataServer` `LIST`, `GET`, `PUT`, `DELETE` and `SERVERACTION` (1, 2 and 4) before any descriptor, tool or page exists. No ECP process starts, no `Action` 3 is sent, the license reads as found throughout, and S2 equals S0 apart from the declared differences. A contradiction halts the story.
- **B1:** Given probe data servers, when ECP data servers opens and `osmgmt.ecpdataservers.read` runs, then both answer the same rows through one read, and the page shows the caveat line.
- **B2:** Given the form or a confirmed proposal, when a data server is created or edited, then `ECP.DataServer` `PUT` round-trips: the list shows it after the change event, and the read-back reads `matches`. A bad name, address, port, mirror change or SSL setting is refused on its field with nothing sent.
- **B3:** Given a data server a remote database uses, when its delete opens or is confirmed, then the advisory names that remote database first and the delete is refused `ECP.DATASERVER.INUSE`, with the server kept. An unused one is deleted.
- **B4:** Given a data server, when its status is changed to Disabled or Not connected by either caller, then the queued action is polled within the bound with no ERROR #7846, the list shows the new status, and no ECP process starts. Past the bound it answers "started", with the read-back `unchecked`.
- **B5:** Given the Community license, when Normal is chosen, then the dialog draws it disabled with the license sentence, and a screen action or proposal is refused `ECP.LICENSE` at once with nothing queued. A seam stands in for a licensed instance and records an `Action` 3 that never reaches the vendor. A choice equal to the current status is refused `ECP.STATUS.SAME`.
- **B6:** Given a caller lacking a declared pair, or an absent target, when either caller writes, then it is refused (403 naming the pair, or not found) with zero port calls.
- **B7:** Given the rosters, when the story lands, then:
  - ECP data servers is OS management's seventeenth entry;
  - each screen carries three prompts;
  - the four keys are in the baseline, with the delete and change status disabled;
  - every roster and pinned side-bar list includes the screens;
  - the DW-1337 gate holds in both themes;
  - EXPERIENCE.md reads 1005 lines.

## Spec Change Log

- 2026-10-04, implement (pass 3): measured AD sentence for the runner. AD-52's "one severity-2 log line" is two: at the limit, a caller without `%Admin_Secure:USE` leaves the vendor's "Create section ECPServer" audit event, the vendor's own severity-2 `ERROR #456` line, and the port's severity-2 log of that refusal (AD-2's ordinary logging). Proposed: "... leaves the vendor's misleading 'Create section ECPServer' audit event and two severity-2 log lines, the vendor's and the port's, and nothing is stored." Alternative: name #456 in AD-2 as an unlogged refusal, which keeps the vendor's line alone. That caller's sentence names the configured data server count, the limit unless the limit was lowered below it (inference).

- 2026-10-03, orchestrator (merge gate, second halt): ruling 2 amended to option (b) -- `EcpPort` runs the `MaxServers` pre-check only when the caller holds `%Admin_Secure:USE`, which the `ECP.Settings` read needs; otherwise the create reaches the vendor and its 500 #456 maps to 409 `ECP.SERVER.LIMIT` with the same sentence; the create's declared pairs stay `%DB_IRISSYS:WRITE`; both paths are pinned, each with a fill-to-limit test, and `EcpWriteGate`'s create-pair test passes for a caller holding exactly the declared pairs. The runner amended AD-52 and corrected the "Disable, real" row to `nothingSent` (AD-58). Pass 2's work is the local commit `05af2074`.

- 2026-10-03, orchestrator (merge gate, Task 0 halt): the port-70000 connection line is a Task 0 probe artifact; probe data servers use TEST-NET-1 (`192.0.2.0/24`) with an in-range port; `ECP.SERVER.LIMIT` (409) refuses a create past `AppServerSettings.MaxServers` before any vendor write; each write's two severity-0 `messages.log` lines are declared; the measured pairs stand, Decision 1's `%Admin_Secure:USE` is dropped and #1454 maps to a refusal. The runner wrote AD-8, AD-13, AD-15, AD-52 and AD-53; the spec is re-opened at Task 0 step 10.

- 2026-10-03, runner (spec gate): wrote AD-26, AD-44, AD-51 and AD-52; AD-13's `foldcase`, AD-8's pairs and any AD-15/AD-53 case wait for Task 0. Decisions 2 to 7 confirmed by the runner; Decision 1 (the SSL check's `%Admin_Secure:USE`, narrower than the classic page) asked of the orchestrator before the implement spawn.
- 2026-10-03, orchestrator (merge gate): Decision 1 accepted -- the create and update declare `%Admin_Secure:USE` only while `SSLConfig` is 1, refused by name before any port call; Task 0 measures both paths, and if the `%ECPClient` read needs no pair, the pair is dropped and the measurement recorded. Decisions 2 to 7 confirmed.
- 2026-10-03, implement (Task 0, halted): measured AD sentences for the runner. AD-8: `osmgmt.ecpdataservers.create`, `.update` and `.delete` declare `%DB_IRISSYS:WRITE`; `.changestatus` declares `%Admin_Operate:USE` alone; no SSL argument pair, because the vendor refuses `SSLConfig` 1 without `%ECPClient` (#1454) and `EcpPort` maps that, so Decision 1's `%Admin_Secure:USE` is dropped (the `%ECPClient` read needs it: 403 without, 404 with). AD-13: `ecp-data-server` keeps `foldcase`. AD-15 and AD-53: `SERVERACTION` records no vendor event with auditing on. Step 10: `ECP.STATUS.REFUSED` is a 500 from `SERVERACTION`; no value-type change. Open for the ruling: the port-70000 connection line, and `MaxServers` 2, which caps the probe servers a test may hold at two and answers a third create 500 #456 with no refusal code.

- 2026-10-03, implement (step 10, intent gap): measured for the runner. AD-8 and AD-52: the data server limit's `ECP.Settings` `GET` needs `%Admin_Secure:USE` (`Security.System.Get`), so a create caller holding only its declared pairs is answered 500 `PORT.ACCESSDENIED`; open for the orchestrator's ruling.

## Review Triage Log

### 2026-10-04 — Review pass

- verdicts: 17 findings — high 0, medium 0, low 12, false 4, maybe-false 1
- findings:
  - `[low]` `[patch]` The Save's unexpected-key refusal had no test — added `EcpDataServerWrite.TestAKeyTheToolsDoNotAdmitIsNeverSent` (both Save routes 400 `PORT.FIELD.UNEXPECTED` with nothing sent; the agent's keys refused by the tool's closed schema at dispatch).
  - `[low]` `[patch]` `SSLConfig` and `BatchMode` shape checks had no test — added `SSLConfig` 2 and `BatchMode` "x" to both bad-field tests, on both callers.
  - `[low]` `[reject]` The license-delegation assertions cannot fail on a Community instance — B5's legs carry mutations, the only falsifiable route is a seam the spec places on `NetworkEnabled` (Named limit 1), and a fix needs a new port parameter for a one-line delegation.
  - `[low]` `[patch]` The "no task row" assertions could not see a sent and finished action — removed both; `Writes()` empty is the pin.
  - `[false]` `[reject]` B0 and several clauses lack `mutation:` lines — Rule 19 asks one per AC, B1 to B7 each have one, and B0 is the Task 0 measurement under Design Notes.
  - `[low]` `[reject]` B7 and Verification say EXPERIENCE.md reads 1005 lines — Story 19.6's merge made it 1006 and this story leaves the count unchanged; the fix is a spec edit, for the runner.
  - `[false]` `[reject]` `HandleCreate` does not answer the stored name — the name pattern admits only ASCII letters, digits, `-` and `_`, which the instance stores upper-cased (Task 0 b), and the test pins storage through `Stored` and `ListText`.
  - `[low]` `[patch]` `EcpWriteGate`'s header omitted its auditing need — added.
  - `[low]` `[reject]` The matrix row says one severity-2 line at the limit — the fix edits the intent contract and AD-52; recorded in `## Spec Change Log` for the runner (same root as the next row).
  - `[low]` `[reject]` Two log lines at the limit, not one — AD-2 logs every failure outside `UNLOGGEDREFUSALS`, so the port's line follows; the matrix row counts what the vendor leaves; AD-52's sentence is the runner's.
  - `[low]` `[reject]` The pair-less caller's limit sentence names the listed count, and the confirm leg asserts only the code — the count is the limit at the limit, and differs only if the limit was lowered below it (inference); both legs share one branch.
  - `[low]` `[patch]` The pair holder's limit leg did not assert "no audit event" — added `CreateEvents` 0.
  - `[low]` `[reject]` The agent's taken-name and string-port refusals carry the kernel's sentences — AD-54's absence read and AD-4's typed merge refuse first, before any vendor write, as Story 18.6's model does.
  - `[maybe-false]` `[defer]` SSL/TLS is refused at the vendor write, and a disabled `%ECPClient` is untested — would be medium; settled by the measurement in `deferred:`.
  - `[false]` `[reject]` Past the bound the route answers 200, not 202 — the port answers 202, which the routes render as `continues` with `unchecked`, AD-26's convention since Stories 18.5 and 18.14.
  - `[false]` `[reject]` Every 500 maps to `ECP.STATUS.REFUSED` — that is Task 0 step 10's measured detection, and the vendor's reason is logged.
  - `[low]` `[patch]` `EcpPort`'s caller-body refusal had no test — added `EcpDataServerStatus.TestACallerBodyIsRefusedBeforeAnyCall`.

## Design Notes

**Governing ADs:**

- AD-2, AD-27, AD-52: `EcpPort` extends `AdminPort` and names no vendor class. No AD-27 named case is needed.
- AD-3, AD-4: the derived fields, and the update's complete set.
- AD-5, AD-36, AD-44: one descriptor per screen, one read, the classic pages, and `CLASSICPAGES`.
- AD-6, AD-34, AD-40, AD-53, AD-55: the tools' two callers.
- AD-8, AD-29: the pairs, and the delete's impact through Remote databases' declared read.
- AD-10: no new arm (Decisions 6).
- AD-13, AD-14: the new entity type and its events.
- AD-15, AD-53: the vendor's events, or named cases.
- AD-21: no path. `Address` is a host, held to `Config.Host`'s rule, and no `DBLIST` is sent.
- AD-22: the baseline.
- AD-26: `SERVERACTION` in `QUEUEDWRITES`, one poller, "started" past the bound, and AD-37's sweep for a least-privileged caller's task row.
- AD-39: OcuPilot's own sentences; the vendor's text is logged.
- AD-51: the change status, the delete, `EcpPort`'s port-built body, and the declared subject. AD-54: the create.
- AD-58: the read-back. AD-59: `Snippet`.

**Measured before this plan** (not re-run):

- `ECP.DataServer` `LIST` takes 0.008 s and `GET` 0.001 s, and a configured data server starts nothing (Story 18.16's Task 0).
- A `DBLIST` on Community blocks about 11 s and starts daemons that outlive it (Story 18.16).
- A data server a remote database uses cannot be deleted (409 #423, Story 18.3).
- The audit log shows "Create section ECPServer" and "Delete section ECPServer" for `Config.ECPServers` writes.

**Measured at plan** (read-only, on `ocupilot-b-ci`, 2026-10-03 22:35-22:38 UTC):

- `NetworkEnabled()` 0, `MaxECPServers()` 0, `KeyServer()` Single.
- `%Service_ECP` disabled; no `Config.ECPServers` entry; `Config.ECP` 1200, 5 and 60; the superserver port 1972.
- The monitor state is 0. Auditing is on, with `ConfigurationChange` enabled.
- 77 processes, none of job types 31 to 35 or 2.
- Through `AdminPort`:
  - `ECP.DataServer` `LIST` answered 200 `[]` in 0.004 s;
  - `GET name=NOSUCHPROBE` answered 404 `PORT.NOTFOUND` in 0.001 s.
- `ocupilot-slot-b` reads the same license and service facts.

**Measured at implement** (Task 0 on `ocupilot-b-ci`, 2026-10-03 23:43-23:50 UTC, halted at step d's re-measure; evidence in `/tmp/epic-18-d6/1820/t0/`). Every write ran through `AdminPort` as `irisowner` (`%All`) unless a principal is named. The monitor state read 2 at the start, left by an earlier sweep, and was cleared to 0 before S0.

- Step 1: the three `ECP.DataServer` pairs joined `MUTATINGTYPES` and `PortFixture`'s copy, `DELETE` joined `BODYLESSTYPES`, and `SERVERACTION` joined `QUEUEDWRITES` and `AdminPortAsync`'s pin (run 5018, 6/6). `Test/EcpProbe.cls` is written.
- a. `LIST` took 0.002 s and `GET` 0.001 s in either case. `Status` reads "Not Connected". `LIST` answers `RemotePort` as a number and the three flags as booleans; `GET` answers `Port` and `MirrorConnection` as numbers and `SSLConfig` and `BatchMode` as booleans.
- b. `PUT name=ocuprobeecpa {Address, Port}` answered 201 in 0.144 s. It is stored as `OCUPROBEECPA` and `GET` reads it in either case; `BatchMode`, `MirrorConnection` and `SSLConfig` stored 0. Event: `ConfigurationChange` "Create section ECPServer OCUPROBEECPA".
- c. `{Port:1973}` alone and `{BatchMode:true}` alone each kept the other keys, 200 with "Modify section ECPServer" each. The fresh `GET` body sent back unchanged answered 200 in 0.001 s with no event. `ReadBack.Compare` reads a sent `SSLConfig` 1 equal to a read `true`.
- d. Refused, nothing stored: an empty `Address` 500 #5659; an absent `Address` or `Port` 400 #40301; port `"x"` 500 #7207; a name with a space or a dot 500 #458; 65 characters 500 #7201; `MirrorConnection` 2 500 #476; `my host` 500 #7200; `SSLConfig` 1 or `true` without `%ECPClient` 500 #1454, on a create and on an update, whose `Port` change was not applied. Port 0 is stored (201). Port 70000: the halt below.
- `Config.config` `MaxServers` is 2, and it caps the data servers: with two defined, a third create answers 500 #456 ("MaxServers parameter must be increased to at least 3"), the vendor logs it at severity 2, nothing is stored, and a "Create section ECPServer" event is still written.
- e. With `OCUPROBEECPR` on the server, `DELETE` answered 409 #423 in 0.003 s (`PORT.CONFLICT`); the server stayed, with no event. With the remote database removed it answered 200 in 0.123 s ("Delete section ECPServer"), and again 404 `PORT.NOTFOUND`, logged as a write's 404 is.
- f. `SERVERACTION {Action:2}` was queued and polled: 200 in 0.062 s against the 30 s bound, state 1 to 4, `LIST` "Disabled", no log line, the task row removed by the poller.
- g. `{Action:1}` answered 200 in 0.061 s, back to "Not Connected". Sent again on Not Connected it answered 200 and changed nothing: the vendor accepts a same-state action, with no #5026.
- h. `{Action:4}`'s task failed, and the port answered 500 `INTERNAL`, logging #40303.
- i. `{Action:2}`, then `DELETE` while Disabled: 200, deleted. j. 75 s after the last action: no ECP job and no new line.
- Each configuration write logs `Activating Network` and `ECP-<n> sys <m> - '<NAME>' (<address>:<port>)` at severity 0: configuration activation, with no process started (inference).
- 6. With auditing on, b, c and e wrote the events above; f, g, h and i wrote no vendor event.
- 7. A principal holding `%Admin_Manage:USE`, `%DB_IRISSYS:READ` and the code read: `LIST` and `GET` answered; `PUT` and `DELETE` answered 500 `<PROTECT>` on `^SYS("CONFIG","IRIS","ECPServers",…)`, nothing changed; `SERVERACTION` answered 403 at the `AsyncResult` poll while the queued action ran (state 4). Adding `%DB_IRISSYS:WRITE`: create 201, update 200, delete 200, action still 403 and applied. Adding `%Admin_Operate:USE`: action 200 twice, configuration writes still `<PROTECT>`. Adding `%Admin_Secure:USE`: neither; `Security.SSLConfig GET name=%ECPClient` answers 404 with it and 403 without. `%DB_IRISSYS:WRITE` with `%Admin_Operate:USE`: action 200. The probe user's ten finished task rows stayed until `RemoveAll` deleted them as objects.
- 8. `RemoveAll` left nothing. S2 equals S0 apart from `messages.log` (8,493 to 8,575 lines), `alerts.log` (310 to 319), job type 59's count (84 to 89) and the monitor state (0 to 2, from the severity-2 refusal lines of d, e and 7), cleared with `$SYSTEM.Monitor.Clear()`. After the halt the same held, with the monitor state 0.
- Step 10 (2026-10-04 00:30 UTC): `ECP.Settings` `GET` answers `AppServerSettings.MaxServers` 2. A principal holding the create's declared pairs (`%Admin_Manage:USE`, `%DB_IRISSYS:READ`, `%DB_IRISSYS:WRITE`) is answered 500 `PORT.ACCESSDENIED` on it, because the vendor's `GetECPSettings` calls `Security.System.Get`; with `%Admin_Secure:USE` added it answers 200.
- Pass 3 (2026-10-04 02:40 UTC): with two probe servers defined, a principal holding `%Admin_Manage:USE` and `%DB_IRISSYS:RW` sent a third create through `AdminPort`: 500 #456 in 0.36 s, nothing stored, one `ConfigurationChange` "Create section ECPServer OCUPROBEECPL3" under that principal, and two severity-2 `messages.log` lines, `[Utility.Event] Error: ERROR #456` and the port's `ECP.DataServer failed with HTTP 500`; the monitor state rose later, asynchronously.
- **Halt (step 9, first condition).** Re-measuring d's port 70000 with no other data server defined, because the first run met #456 first: the vendor stored nothing and answered 500 #456, and `messages.log` gained at severity 1 `<WIDE CHAR>Init+20^ECPClient` and `ECP connection OCUPROBEECPG - 127.0.0.1:70000 failed`. `EcpJobs()` stayed 0, and no line recurred. `EcpRules` refuses that port before any vendor write.

**Decisions.** Each is applied in this plan. The runner confirms them at the spec gate.

1. **The SSL rule mirrors the classic dialog.** Task 0 chooses between mapping the vendor's own refusal and `EcpPort`'s `%ECPClient` read.
   - If the read needs `%Admin_Secure:USE`, the create and update declare it only while `SSLConfig` is 1, under AD-8's endpoint clause. That is narrower than the classic page, whose existence check needs no pair.
   - Every other write and the screens keep OS management's set.
2. **The caveat** is a line on the list page and a sentence in both descriptors' doc comments. The form shows no status, so it shows no caveat.
3. **Change status has no typed name.** It removes nothing. It is destructive, with the classic warning as its consequence.
4. **Names follow License servers' rule**, which is stricter than the classic dialog's. An existing name outside it is still listed, edited and deleted by its id.
5. **`MirrorConnection` is offered as 0 or 1.** A stored non-zero value, -1 included, is kept, because the classic dialog disables the box.
6. **No new AD-10 arm.** OcuPilot's databases are local, so no data-server write changes them (inference). `PROHIBITED.OCUPILOTDATABASE` already refuses re-pointing them. The vendor refuses deleting a server any remote database uses.
7. **The mint refuses `normal` while unlicensed and a same status**, as the port does at the write. A proposal that cannot succeed is never minted.

**Named limits:**

1. **On Community no status reaches Normal.** The Normal path is pinned through `Test/EcpSeamPort` alone, and no instance here has run `ServerAction` 3.
2. **`ECP.STATUS.SAME` compares the instance's English labels.** `RunList` drops `StatusEnglish`, so on a localized instance a translated status matches none, every choice is offered as the classic page does, and the vendor's failed task answers `ECP.STATUS.REFUSED` (inference).
3. **The list cannot tell a mirror connection of 1 from -1** (`RunList` answers a boolean). The form reads `GET`'s integer.

**Proposed spine amendments (Rule 20).** The runner writes 1 to 4 at the spec gate. Task 0 confirms each `<measured>`, and the implement stage records 5 and 6 in `## Spec Change Log`.

1. **AD-26, after Story 18.19's paragraph:** "**Story 18.20's queued write** [AMENDED <date>, Story 18.20 spec gate, Rule 20]: `QUEUEDWRITES` also names `ECP.DataServer` `SERVERACTION`, the last Stage 2 async path. It queues through `ShouldRunAsync()` (read in the vendor source), carries a port-built `{Action}` and no secret, and is read once by the port's one poller. The vendor's own refusals (an out-of-range `Action`, #5026) arrive as the task's failure, never as the call's status."
2. **AD-13, after the license sentence:** "An `ecp-data-server` id keeps `foldcase`, because the instance stores a data server's name in upper case <measured> (Story 18.20) [AMENDED <date>, Story 18.20 spec gate, Rule 20]."
3. **AD-44, after Story 18.6's `CLASSICPAGES`:** "**Story 18.20's `CLASSICPAGES`**: the ECP data server create, update and change status declare `%CSP.UI.Portal.Dialog.ECPDataServer`. The delete, performed on `%CSP.UI.Portal.ECPDataServers` itself, declares none [AMENDED <date>, Story 18.20 spec gate, Rule 20]."
4. **AD-51, after Story 18.6's case:** "Story 18.20's case: `EcpPort`, which builds `ECP.DataServer` `SERVERACTION`'s `{Action}` from the change status tool's declared `Status` (`notconnected` 1, `disabled` 2, `normal` 3). Before anything is queued, it refuses `normal` while the license enables no ECP (`ECP.LICENSE`, through `RemoteDatabasePort.NetworkEnabled()`) and a status equal to its fresh `LIST` row's (`ECP.STATUS.SAME`), so no instance whose license lacks ECP is ever sent `Action` 3 [AMENDED <date>, Story 18.20 spec gate, Rule 20]." AD-52 gains: "`EcpPort` (Story 18.20) sequences a status change: the license check, the `LIST` row, then `SERVERACTION`."
5. **AD-8, after Story 18.6's paragraph** (Task 0): "**Story 18.20's ECP data servers** [AMENDED <date>, Story 18.20 Task 0, Rule 20]:
   - The screens declare OS management's `%Admin_Manage:USE` and `%DB_IRISSYS:READ`, the classic pages' `RESOURCE`.
   - `osmgmt.ecpdataservers.create`, `.update` and `.delete` declare `%DB_IRISSYS:WRITE` <measured>. `.changestatus` declares `%Admin_Operate:USE` under the endpoint clause, the `AsyncResult` gate, <and any measured pair>. <The SSL argument pair, if measured.> Each is refused by name before any port call.
   - A data server's delete names its impact: the remote databases whose `Server` it is, read through Remote databases' declared read. The vendor refuses the delete while one remains (409 #423)."
6. **AD-15 and AD-53**, only where Task 0 step 6 finds no vendor event: "Changing an ECP data server's status (`ECP.DataServer` `SERVERACTION`, Story 18.20) records no vendor event with auditing on <measured>."

**Integration ACs.** `EcpPort` and `EcpError` are new.

- The status dialog consumes `EcpPort` through `POST /screens/:screen/action`. The effect is the real Disabled status in the list, and the real `ECP.LICENSE` refusal on `ocupilot-b-ci` (B4, B5; browser spec and `EcpDataServerStatus`).
- The form consumes `GET /ecp-data-server/form` and the Save routes (B2, `EcpDataServerWrite`, with real vendor writes).
- The delete's impact consumes Remote databases' declared read (B3, a real seeded remote database).
- `EcpError`'s `ECP.LICENSE` is consumed by the dialog's disabled Normal (B5), pinned equal to the kernel copy.

**Consumes:**

- 18.16: `RemoteDatabasePort.NetworkEnabled()`, `RemoteDatabaseList`'s read, and the probe and seam models.
- 18.6: `LicenseRules.IsAddress` and `IsPort`, `LicenseProbe.LicenseFacts`, and the seam and fixture shape.
- 18.5 and 18.14: the queued-write and started handling. 16.12: the row-dialog page model.
- Earlier stories: 16.19's impact, 16.17's read-back, 14.1's `Snippet` and 14.2's baseline.

**Consumed-by:**

- 18.21: `EcpError`, the `ECP.LICENSE` sentence and `EcpPort.NetworkEnabled()`.
- 18.12: the agent's grown tool set.

**Ledger inbox (Rule 17):** empty. `ledger.sh slice 18-20-ecp-data-servers` answered nothing (dispatch). DW-1774's side-bar rule is met by the roster tasks.

**Footprint (Rule 11).** Every contended file is edited add-only (Boundaries). These are new and outside the listed set: `Port/EcpPort.cls`, `Area/OsMgmt/EcpRules.cls`, `Area/OsMgmt/EcpDataServerSave.cls`, `Api/EcpError.cls`, `Kernel/Proposal/Impact.cls` (one kind), and `Api/Error.cls` (two dispatch lines). Report them under `footprint_extensions`.

## Verification

**Setup (slot B):**

- Load with `/tmp/epic-18-d6/load-throwaway.sh`, with no restart, and never through the MCP loader. Every write lands on `ocupilot-b-ci`, on `OCUPROBEECP*` objects only.
- Run one test class per call, and send the next only once the previous has landed in `%UnitTest_Result`. Never re-submit after a client-side timeout.
- Arm per call with `docker exec -e OCUPILOT_ALLOW_ECP_CONFIG=1 -e OCUPILOT_ALLOW_PRINCIPALS=1 -e OCUPILOT_ALLOW_DATABASE_CONFIG=1`.
- Before any browser run, run `cd ui && npm run build`, then `docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`, with `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777` and `OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci` exported.

**Commands:**

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.<C>`, one call at a time. Expected: 0 failures, with totals checked against `%UnitTest_Result`.
  - The story's own classes: `EcpDataServerWrite`, `EcpDataServerStatus`, `EcpWriteGate`, `EcpDescriptor`.
  - The rosters: `Descriptor`, `ReadTool`, `SurfaceCoverage`, `EndpointCoverage`, `Navigation`, `Wire`, `WireSecurityRead`, `WireAreaAnyScreen`, `PortGate`, `ClassicPageGate`, `MappingDescriptor`, `DraftRegistry`, `ToolRoundTrip`, `ToolWrite`, `Prohibited`, `GovernanceBaseline`, `Governance`, `ToolDispatch`, `ToolEmit`, `EntityRef`, `AdminPortAsync`, `RemoteDatabaseWrite`, `RemoteDatabaseDescriptor`.
- `(loop)` `cd ui && node --test --test-concurrency=1 browser/ecp-data-servers.browser-spec.mjs browser/license-usage.browser-spec.mjs browser/remote-databases.browser-spec.mjs browser/journals.browser-spec.mjs browser/journal-settings.browser-spec.mjs browser/license-key.browser-spec.mjs browser/license-servers.browser-spec.mjs`. Expected: pass.
- `(loop)` `cd ui && npm run test:tools && npm run test:components`, then `uv run scripts/check-objectscript.py <changed .cls>` and `bash scripts/lint-docs.sh`. Expected: clean, and `wc -l` on EXPERIENCE.md reads 1005.
- `(once, before dev_complete)`, each expected green with a non-zero count:
  1. the full ObjectScript sweep, `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci`, one class at a time;
  2. `cd ui && npm test && npm run build`;
  3. `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS`;
  4. afterwards, no `OCUPROBEECP*` data server, remote database, principal or task row remains; `EcpJobs()` reads 0; and the license facts and the monitor state read as at S0.
- `(CI)` The full browser suite runs in CI's three `browser-shard` jobs (Rule 29).

**Planned pinning mutations (Rule 19).** Apply each on the throwaway, observe red, revert byte-identical, and record a `mutation:` line here.

- B1: the list descriptor's read drops `Status` → `EcpDescriptor`'s read leg red.
- B2:
  - `EcpDataServerUpdate.MergeUpdate` sends only the changed field → `EcpDataServerWrite`'s complete-set leg red.
  - `EcpRules.Problem` admits port 0 → the port leg red.
  - The `MIRROR` check is dropped → the mirror leg red.
- B3: `Impact.KindOf` drops the data server delete → the in-use advisory leg red.
- B4:
  - `EcpPort` builds `{Action}` from the wrong map entry → the real Disabled leg red.
  - The 202 handling is dropped → the started leg red.
- B5:
  - `EcpPort`'s license check is removed → the unlicensed Normal leg red, with the seam showing a `SERVERACTION`.
  - The same-status check is removed → the same-status leg red.
  - The dialog's licensed gating is dropped → its component spec red.
- B6:
  - `EcpDataServerChangeStatus.PrivilegePairs` drops `%Admin_Operate:USE` → `EcpWriteGate` red.
  - The create drops `%DB_IRISSYS:WRITE`, if Task 0 keeps it → `EcpWriteGate` red.
- B7:
  - `osmgmt.ecpdataservers.changestatus` is dropped from the baseline → `GovernanceBaseline` red.
  - `sideBarPosition` is set to 0 → `Navigation` and `navigation.test.mjs` red.

**Mutations applied (Rule 19)**, each reverted byte-identical and reloaded:

- mutation: B1 `EcpDataServerList` read drops `Status` → `EcpDescriptor.TestEcpDataServersIsOsManagementsSeventeenthEntry` red (run 5069)
- mutation: B2 `EcpDataServerUpdate.MergeUpdate` sends only the changed fields → `EcpDataServerWrite.TestAnUpdateSendsTheCompleteSetAndKeepsAStoredMirror` red (run 5070)
- mutation: B2 `EcpRules.Validate` admits port 0 → `EcpDataServerWrite.TestBadCreateFieldsAreRefusedBeforeAnyWrite` and `TestBadUpdateFieldsAreRefusedBeforeAnyWrite` red (run 5071)
- mutation: B2 `EcpRules.Validate`'s `MIRROR` check dropped → `EcpDataServerWrite.TestBadUpdateFieldsAreRefusedBeforeAnyWrite` red (run 5072)
- mutation: B3 `Impact.KindOf` drops `osmgmt.ecpdataservers.delete` → `EcpDataServerWrite.TestADataServerInUseNamesItsRemoteDatabaseAndIsRefused` red (run 5073), `EcpDescriptor.TestTheDeleteHasItsImpactKind` red (run 5074)
- mutation: B4 `EcpPort.STATUSACTIONS` maps `disabled` to 1 → `EcpDataServerStatus.TestDisabledAndBackToNotConnectedOnBothCallers` red (run 5075)
- mutation: B4 `EcpPort`'s `PORT.TIMEOUT` to 202 branch dropped → `EcpDataServerStatus.TestAChangePastTheBoundHasStarted` red (run 5076)
- mutation: B5 `EcpPort`'s license check removed → `EcpDataServerStatus.TestNormalIsRefusedWhileTheLicenseLacksEcp` red, the seam recording the `SERVERACTION` (run 5077)
- mutation: B5 `EcpPort`'s same-status check removed → `EcpDataServerStatus.TestTheSameStatusIsRefusedWithNothingSent` red (run 5078)
- mutation: B5 the status dialog's unlicensed-Normal gating dropped → `ecp-data-server-status-dialog.spec.ts` (B5 legs) and `ecp-data-server-list.page.spec.ts` red (local vitest, 3 failed)
- mutation: B6 `EcpDataServerChangeStatus.PrivilegePairs` drops `%Admin_Operate:USE` → `EcpWriteGate.TestTheMissingToolPairsAreRefusedBeforeAnyPortCall` red (run 5079)
- mutation: B6 `EcpDataServerCreate.PrivilegePairs` drops `%DB_IRISSYS:WRITE` → `EcpWriteGate.TestTheMissingToolPairsAreRefusedBeforeAnyPortCall` red (run 5080)
- mutation: B7 the baseline drops `osmgmt.ecpdataservers.changestatus` → `GovernanceBaseline` red (run 5081), `EcpDescriptor.TestTheBaselineListsTheFourKeys` red (run 5082)
- mutation: B7 `EcpDataServerList` `sideBarPosition` 0 → `Navigation.TestThePayloadCarriesEveryAreaWithAVerdict` red (run 5083); in the regenerated mirror → `navigation.test.mjs` red (local, 2 failed)
- mutation: B2 `EcpPort.Put` drops its #456 branch → `EcpWriteGate.TestACreatePastTheLimitWithoutAdminSecureIsTheVendorsRefusal` red, each create 500 `INTERNAL` (run 5151)
- mutation: B2 `EcpPort.Put` reads the limit whatever the caller holds → `EcpWriteGate.TestExactlyTheDeclaredPairsCreateOnBothCallers` and `TestACreatePastTheLimitWithoutAdminSecureIsTheVendorsRefusal` red, 500 `PORT.ACCESSDENIED` (run 5152)
- mutation: B2 `EcpPort.Put` skips its limit check → `EcpDataServerWrite.TestACreatePastTheLimitIsRefusedBeforeAnyWrite` red, a `PUT` sent and a log line written (run 5153)
- mutation: B2 `EcpDataServerSave` drops its `Unexpected` calls → `EcpDataServerWrite.TestAKeyTheToolsDoNotAdmitIsNeverSent` red, the update written (run 5181)
- mutation: B2 `EcpRules.Validate` drops the `SSLConfig` and `BatchMode` shape checks → `EcpDataServerWrite.TestBadCreateFieldsAreRefusedBeforeAnyWrite` and `TestBadUpdateFieldsAreRefusedBeforeAnyWrite` red (run 5181)
- mutation: `EcpPort` drops its caller-body refusal → `EcpDataServerStatus.TestACallerBodyIsRefusedBeforeAnyCall` red (run 5182; the three applied together, each red on its own legs)
- mutation: B7 `ScreenRead` without the `EcpDataServerList` exemption → `ScreenRead.TestEveryDeclaredReadFieldIsAKeyOfTheLiveRow` red (run 5385, the sweep before the fix)

## Auto Run Result

Status: done
Blocking condition: none

- **Planned:** Story 18.20 from Part B of `spec-18-6-licensing-and-ecp.md` at commit `fe080653`, re-validated against the current tree (18.6 and 18.16 built).
  - It covers: the Task 0 with its halt conditions; the server and client execution; the rosters (with the position-0 order); the tests; ACs B0-B7; Verification; seven decisions; and six proposed spine amendments (1 to 4 at the spec gate, 5 and 6 after Task 0).
  - Size is about Story 18.6 Part A: two descriptors, four write tools, one port, one area error class, a custom list page with one dialog, and one form page.
- **Measured at plan:** read-only, on `ocupilot-b-ci` and `ocupilot-slot-b`, with no write to any instance and no `DBLIST`, `SERVERACTION` or other ECP write (Design Notes › Measured at plan). The vendor and classic sources were read from the export and `irissys/`.
- **Tree state at dispatch:** the only uncommitted change was the runner's own `stage_spawned` line in `cycle-log-epic-18.md`, written at this spawn. This stage did not touch it and leaves this spec uncommitted.
- **Implement (Task 0, halted 2026-10-03 23:49 UTC):** Task 0 step 1 is built (the three `AdminPort` list additions, `PortFixture`'s copy, `AdminPortAsync`'s pin, `Test/EcpProbe.cls`; `AdminPortAsync` run 5018, 6/6). Steps a to j and 6 to 8 are recorded under Design Notes › Measured at implement and the measured AD sentences under `## Spec Change Log`; nothing past step 1 is built.
  - The stage checked the halt on the throwaway: `messages.log:8581` and `:8583` read, at severity 1, `<WIDE CHAR>Init+20^ECPClient` and `ECP connection OCUPROBEECPG - 127.0.0.1:70000 failed`, and `:8578` shows `OCUPROBEECPG` created at port 0 three seconds earlier. Since the #456 answer reads "at least 3", whether other data servers were defined at that moment is unresolved (inference).
  - The throwaway was checked after the halt: no `OCUPROBEECP*` data server, remote database, user, role or task row; 0 ECP jobs; `NetworkEnabled` 0, `%Service_ECP` off, `MaxServers` 2; the monitor state 0. The handoff cleared the monitor state with `$SYSTEM.Monitor.Clear()` three times (2 before S0, left by an earlier sweep; 2 after step 8; 1 after the re-measure). The audit database was not purged.
  - The shim `/tmp/epic-18-d6/1820/sweep-bin/docker` arms `OCUPILOT_ALLOW_ECP_CONFIG` and `OCUPILOT_ALLOW_DATABASE_CONFIG` with the 18.6 shim's three variables. The Task 0 evidence is in `/tmp/epic-18-d6/1820/t0/`.
  - The tree is left uncommitted for the runner: this spec, `src/OcuPilot/Port/AdminPort.cls`, `src/OcuPilot/Test/AdminPortAsync.cls`, `src/OcuPilot/Test/PortFixture.cls` and the new `src/OcuPilot/Test/EcpProbe.cls`. Their diff is saved at `/tmp/epic-18-d6/1820/task0-plumbing.patch`.
- **Implement pass 2 (2026-10-04, halted at Verify):** the plumbing patch applied and every server, client, test and roster task built (handoff report; `## Verification` holds 14 `mutation:` lines). Loop verification on `ocupilot-b-ci`: the story's and roster classes green apart from the create-pair leg above and `WireSecurityRead`'s 1,000-row cap (instance age, inference); the seven browser specs, `test:tools` 1785/1785, `test:components` 2308/2308, `check-objectscript`, `lint-docs` clean; EXPERIENCE.md 1005 lines; `maximumWarning` re-based 2679kB to 2712kB (measured 2,711,418 bytes). Review layers and the `(once)` set did not run.
  - The tree is left uncommitted for the runner; its full diff, untracked files included, is `/tmp/epic-18-d6/1820/implement-pass2.patch`.
  - Throwaway after the halt: no `OCUPROBEECP*` object, `EcpJobs()` 0, 0 policy rows, license and ECP settings as found; `$SYSTEM.Monitor.Clear()` ran three times this pass (twice in the handoff, once by the stage after the confirming `EcpWriteGate` run 5116 raised it to 2).
- **Implement pass 3 (2026-10-04), the second ruling (option b):** `EcpPort.Put` reads `ECP.Settings` and refuses a create at the limit before any vendor write only for a caller holding `%Admin_Secure:USE` (`LIMITPAIR`, through `AdminPort.HoldsPair`); for any other caller the vendor's 500 #456 (`AdminPort.PROPERTYFAULTS` `ECP.DataServer:456:@=ECP.SERVER.LIMIT`) answers 409 `ECP.SERVER.LIMIT` with `EcpError.Limit` over the listed count. `EcpWriteGate`'s create-pair leg is green.
  - Files: `Port/EcpPort.cls` (the conditional check, the #456 branch); `Port/AdminPort.cls` (one `PROPERTYFAULTS` entry and its doc sentence); `Api/EcpError.cls` (doc); `Test/EcpWriteGate.cls` (the pair-less limit test, header); `Test/EcpWriteGateProbe.cls` (a leg's `reason`); `Test/EcpProbe.cls` (`CreateEvents`); `Test/EcpDataServerWrite.cls` (the unexpected-key test, the `SSLConfig` and `BatchMode` shape legs, the pair and no-event assertions on the limit leg); `Test/EcpDataServerStatus.cls` (the caller-body test; two task-row assertions that could not fail removed); `Test/ScreenRead.cls` (`EcpDataServerList` joins the no-row exemptions, add-only, with its comment: a fresh instance holds no data server, which the sweep's run 5385 showed).
  - Review: 17 findings (low 12, false 4, maybe-false 1); 6 low patched, 1 deferred (a disabled `%ECPClient`, `deferred:`), 10 rejected with their reasons in `## Review Triage Log`. `followup_review_recommended` false: no high and no medium patched.
  - Verification on `ocupilot-b-ci`: the story's classes and the 23 rosters green (runs 5154-5180, but `WireSecurityRead`'s cap); after the patches `EcpDataServerWrite` 11/11 (5183) and `EcpDataServerStatus` 8/8 (5184); `ScreenRead` 30/30 (5404). Full ObjectScript sweep, once, six sequential shards (runs 5185-5627): 442 classes, 3,640 tests, 2 failures at each class's latest run, both the instance's age (inference; both pass in CI): `Retention.TestAnEntryAgesByItsOwnDefinitionAndTheLedgerByTheLongest` (expired rows another suite left) and `WireSecurityRead.TestTaskHistoryPairSetsAreEnforcedForARealPrincipal` (the 1,000-row cap). `npm test` 1785/1785 and 2319/2319; `npm run build` clean, initial 2,727,893 bytes under the unchanged 2728kB; `smoke.sh` 50/50; the seven browser specs 25/25 on the redeployed bundle; `check-objectscript` clean; EXPERIENCE.md 1006 lines, untouched.
  - Throwaway afterwards: no `OCUPROBEECP*` data server, remote database, user, role or task row; `EcpJobs()` 0; the license as found (Community, `NetworkEnabled` 0); license servers `LOCAL` alone; `%Service_ECP` off; `Config.ECP` 1200, 5, 60; `MaxServers` 2; journal settings at the stock values; 0 agent definitions, 0 policy rows. `$SYSTEM.Monitor.Clear()` ran three times this pass (2 left by pass 2, 2 after the handoff's runs, 2 after the sweep), and the state read 0. The audit database was not purged.
  - For the runner: AD-52's "one severity-2 log line" is two (`## Spec Change Log`, pass 3 entry); B7 and `## Verification` still say EXPERIENCE.md reads 1005 lines, which Story 19.6's merge made 1006; `Test/ScreenRead.cls` is a footprint extension (not on Epic 19's list).
  - Residual risk: a pair-less caller's limit sentence names the configured count, which is the limit unless the limit was lowered below it (inference); the licensed Normal path and `EcpPort.NetworkEnabled`'s delegation are pinned only through the seam (Named limit 1).
