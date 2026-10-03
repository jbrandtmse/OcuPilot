---
title: 'Story 18.6: Licensing and ECP'
type: 'feature'
created: '2026-10-03'
status: 'blocked'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-18-context.md'
warnings: ['oversized', 'multiple-goals']
deferred: []
---

<intent-contract>

## Intent

**Problem:** The classic portal is still the only place to manage an instance's license and its ECP configuration. That covers the License key page with its activate dialog and print page, License servers, ECP settings, ECP application servers, and ECP data servers with their status dialog. The admin API carries all five through six endpoint classes:

- `License.Key`: `GET`, `PUT` and `VALIDATE`;
- `License.Server`;
- `ECP.Settings`;
- `ECP.AppServerList`;
- `ECP.AppServerSSLConnection`: `AUTHORIZE`, `REJECT` and `DELETE`;
- `ECP.DataServer`, including the async `SERVERACTION`.

**Approach:** Build it in three parts, one per surface group. Each part has its own Task 0 on `ocupilot-b-ci`, its own screens appended to OS management after Journal settings, and its own tools.

- **Part A, Licensing:** License key (view, validate, activate and print) and License servers (list, create, edit and delete). It is planned in full below.
- **Part B, ECP data servers:** the list, create, edit and delete, and the status action.
- **Part C, ECP settings and ECP application servers.**

Every instance here runs a Community license. So no test activates a key or opens an ECP connection, and every success path that would need either runs through a test seam.

**This plan halts for a split, under the dispatch's size rule.** The five surfaces come to eight descriptors, twelve write tools, two new ports and three Task 0s. That is about three times Story 18.16, which alone filled one implement pass. The recommendation:

- Part A stays Story 18.6.
- Part B becomes Story 18.20, and Part C Story 18.21 (Rule 17's `N.<M+1>`).
- They run in the order A, B, C.

Each part's ACs, routes, size and dependencies are under Tasks & Acceptance. The orchestrator decides at the merge gate; this plan splits nothing on its own authority.

## Boundaries & Constraints

**Always (every part):**

- **Task 0 runs first, on `ocupilot-b-ci` only.** It uses probe objects named `OCUPROBE186*`, which it creates and removes, and it halts on any contradiction. Facts Story 18.16's Task 0 measured are not re-run (Design Notes › Measured before this plan).
- **The license stays exactly as found.** `License.Key` `PUT` and `VALIDATE` run only with a malformed key's text. A `PUT` runs only after a `VALIDATE` of the identical text answered `IsValid` false. A measurement that would need a real activation is a halt, not a step.
- **No ECP connection is opened.** That means no `ECP.DataServer` `DBLIST`, no `SERVERACTION` with `Action` 3 against the vendor, and no change to `%Service_ECP`. A probe data server is configuration only, at `127.0.0.1:1972`, as Story 18.16's was.
- **No test needs a restart.** A test restores every setting it changes, and a snapshot compares the before and after.
- **Each test class stands alone.** It arranges and removes its own preconditions on a fresh stock instance, in any order, including any daemon it starts.
- **Placement.** New screens are appended to OS management's side bar after Journal settings (position 14). Part A takes 15 and 16. Parts B and C take the next positions in landing order.
- **Every screen** carries three prompts, and the DW-1337 structural gate holds in both themes.
- **Error codes** go in area error classes: `Api/LicenseError.cls` for Part A, and `Api/EcpError.cls` for Parts B and C. `Api/Error.cls` dispatches each by prefix, edited add-only.
- **Contended files are add-only.** Epic 19 is concurrent on slot A. These files only gain lines or list members, and one-line list members and roster counts are unioned by whichever story reaches the feature branch second:
  - `Api/Router.cls`, `Kernel/Governance/Baseline.cls`, `Kernel/Proposal/Prohibited.cls`, `Screen/Gate.cls`, `Screen/Tool/Classification.cls`;
  - `scripts/ci-throwaway.sh`, `ui/angular.json`;
  - `ui/src/app/core/strings.ts`, `ui/src/app/core/navigation.ts`, `ui/src/app/core/screen-actions.ts`, `ui/src/app/shell/command-box.ts`;
  - EXPERIENCE.md;
  - the rosters `ReadTool`, `SurfaceCoverage`, `Wire`, `PortGate`, `Governance`, `GovernanceBaseline`, `ToolDispatch`, `ToolEmit`, `ToolRoundTrip`, `ClassicPageGate`, `MappingDescriptor` and `Test/Prohibited.cls`.
- **EXPERIENCE.md** is edited in place and keeps 1005 lines. `screens.generated.ts` and `ToolFields.cls` are regenerated, never hand-merged.
- **`strings.ts` holds each value under one key.** A label another screen already publishes reuses that key.
- **Governance:** each write key joins the baseline in the same change. A destructive one joins it `false`.

**Always (Part A):**

- **Screens:**

  | Descriptor | Route | Archetype | Pos | Entity type, id | `classicPage` | `toolIdentifier` |
  | --- | --- | --- | --- | --- | --- | --- |
  | `LicenseKey` | `os-management/license-key` | `detail` | 15 | `license-key`, `{single, []}` | `%CSP.UI.Portal.License.Key` | `osmgmt.licensekey` |
  | `LicenseServerList` | `os-management/license-servers` | `list` | 16 | `license-server`, `[Name]` | `%CSP.UI.Portal.LicenseServers` | `osmgmt.licenseservers` |
  | `LicenseServerForm` | `os-management/license-servers/edit` | `form-page` | 0 | `license-server` | `%CSP.UI.Portal.LicenseServers` | none (no read) |

  All three declare `%Admin_Manage:USE` and `%DB_IRISSYS:READ`, OS management's set, with no own pair. That matches the classic pages' `RESOURCE` `%Admin_Manage`.
- **The License key read** is `{"port":"admin","endpoint":"License.Key","type":"GET"}`. Its fields:
  - `LicenseCapacity`, `CustomerName`, `OrderNumber`, `Product`, `LicenseType`, `Server`, `Platform`;
  - `LicenseUnits`, `CoresLicensed`, `CoresEnforced`, `ExpirationDate`;
  - the arrays `ExtendedFeaturesList` and `AuthorizedApplications`.

  `AuthorizationKey` is in the read's fields and in `context.secretFields`, so neither the screen read nor the tool returns it (Design Notes › Decisions 2).
- **Validate is a screen-only check.** `POST /license/key/validate` takes `{Key}` under the License key screen's gate. It answers `{valid, requiresRestart, reductions}` in OcuPilot's own sentences, and no vendor text ever reaches the caller. It is never a tool, because the model never holds a key.
- **Activate is `osmgmt.licensekey.activate`:**
  - an AD-51 action write with an AD-56 (i) secret-only body, `{Key}`;
  - `DESTRUCTIVE`, unadvertised (`ADVERTISED` 0), with its governance key `false` (Design Notes › Decisions 1);
  - its port, `Port/LicensePort`, first sends `VALIDATE` with the same body. When `IsValid` is false it refuses `LICENSE.KEY.INVALID` and sends no `PUT`.
  - The key's text is a screen action value under the descriptor's `secretArguments`, pasted or loaded from a local file in the browser. It is never a server path. It is never stored or logged, and never kept in the screen store, a proposal or a response.
- **Print belongs to the browser.** Print renders the License key screen's fields and "Printed by <user> on <time>." under a print stylesheet. There is no route and no server file.
- **License server tools:**
  - `osmgmt.licenseservers.create` (AD-54), body `{Address, Port}`;
  - `.update` (AD-4), the complete `{Address, Port}` read fresh;
  - `.delete` (AD-51), subject `Address,Port,KeyDirectory`, `DESTRUCTIVE`.

  `KeyDirectory` is shown and never set (AD-21; Design Notes › Decisions 3).
  - The name must match `^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$`, and the instance stores it in upper case.
  - The port must be from 1 to 65535.
  - The address must be non-empty and at most 256 characters.
- **Pairs.**
  - The license server writes declare `%DB_IRISSYS:WRITE`. That is an inference from every `Config.*` write measured in Epics 16 and 18 (devices, namespaces, databases, remote databases and language servers), and Task 0 confirms or drops it.
  - The activation declares the screen's set, and its success path is never measured (Named limit 1).
  - A missing pair is refused by name before any port call.

**Never:**

- No real license activation on any instance. No ECP connection. No restart. No change to `%Service_ECP`, `Config.ECP`, `Config.config` or `Security.System` in Part A.
- No server file path. The classic activate dialog's server file and the print page's `Filename` are not carried, and `KeyDirectory` is not settable.
- None of these reaches any answer, tool result, screen context, ledger row or log line: `AuthorizationKey`, the key's text, or the vendor's `InvalidReason` and `RestartReason` text.
- No rename of a license server. The classic page renames by deleting and re-creating, which is not atomic.
- No agent path to validate or activate. The activate tool exists, but it is unadvertised.
- No `%Api.Admin.*` name outside `AdminPort` and its subclasses. No direct `Config.*`, `SYS.*` or `%SYSTEM.License` write in product code; test-only `%SYS` seeding is allowed.
- No edit to the spine or to epics.md in the implement stage.
- Parts B and C are built by this story only if the orchestrator rules against the split.

## I/O & Edge-Case Matrix

These rows are Part A's.

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
| --- | --- | --- | --- |
| View | `ocupilot-b-ci`'s Community key | License key shows the thirteen fields: capacity, customer, order 54702, product Server, type Concurrent User, key server Single, platform, units 8, cores 20 and 20, expiration 2027-06-26, eighteen features, no applications. `osmgmt.licensekey.read` answers the same row. Neither carries `AuthorizationKey`. | none |
| Validate, malformed | The text `OCUPROBE186 is not a license key` | The license is unchanged, there is no `iris.key`, and no temporary key file is left | 422 `LICENSE.KEY.INVALID` on Key |
| Validate, empty or oversized | `""`, or more than 16,384 characters | Refused before any vendor call | 422 `LICENSE.KEY.EMPTY` / `LICENSE.KEY.INVALID` |
| Validate, valid (seam) | The seam answers valid, with a restart required and two reductions (cores 20 to 8, the feature `Vector Search`) | The answer gives the restart sentence and each reduction's sentence | none |
| Activate, malformed (real) | The screen's activate action with the malformed text, sent past the dialog's gating | `VALIDATE` is sent once, and no `PUT`. Nothing changes. | 422 `LICENSE.KEY.INVALID` on Key |
| Activate, valid (seam) | The seam answers valid | `VALIDATE` and then `PUT` are sent, once each and in that order. The `license-key` change event fires, and the read-back says no value was compared. | none |
| No agent path | A turn's tool list, dispatch and screen context | `osmgmt.licensekey.activate` is absent from all three; the screen action reaches it | `TOOL.UNKNOWN` on dispatch |
| Key secrecy | After a validate and an activate (seam) on a key text carrying a marker | No log line, ledger row, screen store, screen context, proposal or response body carries the marker | none |
| Print | Print on License key | Print media shows the license fields and "Printed by <user> on <time>." The rail, header, side bar and panel are hidden. | none |
| Create a server | Name `ocuprobe186a`, address `127.0.0.1`, port 4999, through both the screen Save and an agent proposal | `PUT /license/server` `{Address, Port}`. The server is listed as `OCUPROBE186A`, and the read-back reads `matches`. | none |
| Update a server | Port 4998 | The complete `{Address, Port}` read fresh is sent, with one diff row. `KeyDirectory` is as stored. | none |
| Delete a server | The typed-name dialog, or a confirmed proposal | `DELETE /license/server` is sent, and the row leaves the list | none |
| Name, address or port refused | The name `LOCAL` in lower case, or `1 a`; an empty address; port 0, 65536 or `x` | Refused on the field before any vendor write | `LICENSE.SERVER.NAME.TAKEN`, `.NAME.SHAPE`, `.ADDRESS`, `.PORT` |
| Absent target | Update or delete a server deleted since the read | Refused; nothing is sent | 404 `PORT.NOTFOUND` / target changed |
| Missing pair | Any license server write without a pair Task 0 sets | 403 naming the pair, with zero port calls | `AUTH.NOPRIVILEGE` |

</intent-contract>

## Code Map

**Vendor.** These are read-only, exported from `ocupilot-b-ci` to `/tmp/epic-18-d6/186/vendor/` (re-export with `GetTextAsString` if they are gone). Every class's `ResourcesOR()` is `%Admin_Manage`.

- `License.Key`:
  - `RunGet` (:31-55) answers fourteen keys, `AuthorizationKey` among them.
  - `RunPut` (:57-91) does this in order:
    1. copies `Key` to a temporary file, runs `IsValidKey` and deletes the file;
    2. answers 400 when the key is invalid;
    3. otherwise **writes `<mgr>iris.key` before calling `Upgrade()`**, then answers `{Key}` back.
  - `RunValidate` (`TYPEVALIDATE` 10, :93-148) answers `{IsValid, InvalidReason, RequiresRestart, RestartReason, HasReductions, Reductions{Cores,Users,Server,LicenseType,Product: {From,To}, Features:[]}}` through `CheckKeyForUpgrade`.
  - The template is `{Key}`.
- `License.Server`:
  - `LIST` reads `Config.LicenseServers:List`, with `names` as its filter; `GET`, `PUT` and `DELETE` take `name`.
  - `PUT` is an upsert through `MergeJsonAndProperties`, which sets only the keys sent. It answers 201 on a create, and a create requires `Address` and `Port`.
  - The template is `{Address, Port, KeyDirectory}`.
- `ECP.Settings` (:13-123): a nested `{AppServerSettings{MaxServers, ClientReconnectDuration, ClientReconnectInterval}, DataServerSettings{MaxServerConn, ServerTroubleDuration, SSLECPServer}}`. The `PUT` sets only defined keys, across `Config.config`, `Config.ECP` and `Security.System`.
- `ECP.AppServerList`: `SYS.ECP:ClientList`, answering `ClientName, Status, IPAddress, IPPort`.
- `ECP.AppServerSSLConnection`:
  - `LIST` merges `SSLAuthorizedConnections` with `Status` "Authorized" and `SSLPendingConnections` with `Status` "Pending";
  - `AUTHORIZE` (10) and `REJECT` (11) call `RemoveFromPendingList(name, 1|0)`, and `DELETE` calls `RemoveAuthorizedCN`. Each answers OK for any name, because the vendor documents that it "always returned 'OK'".
- `ECP.DataServer` (:5-191):
  - `LIST` reads `StatusListSMPFilter` without `StatusEnglish`; `GET` answers `{Address, BatchMode, MirrorConnection, SSLConfig, Port}`.
  - `PUT` is an upsert through `MergeJsonAndProperties`, and a create requires `Address` and `Port`.
  - `DELETE` maps #423 to 409.
  - `SERVERACTION` (10, `ShouldRunAsync`) takes `{Action}` 1, 2 or 3, and calls `SYS.ECP.ServerAction(name, Action, 1)`, mapping #5026 to 409. Action 1 is Not Connected, 2 is Disabled and 3 is Normal (`irissys/SYS/ECP.cls:76-83`).
- Classic pages, each spelled as its class name. This was checked with `NormalizePage` on the throwaway, and none of them is Hidden:
  - `License.Key`, `.License.Print` and `.Dialog.LicenseActivate`: the key is read from a **server file path**, and Activate runs `IsValidKey`, `CheckKeyForUpgrade`, a confirm, a copy to `iris.key`, then `Upgrade()`. The reduction sentences are at `LicenseActivate.cls:297-361`.
  - `LicenseServers`: an in-page form. A rename deletes and then creates.
  - `ECP`: also checks `%Admin_Secure` for SSL (:264).
  - `ECPAppServers`.
  - `ECPDataServers` and `Dialog.ECPDataServer`: its change status calls `ServerAction(name, s, 0)` and warns that pending replies error and transactions roll back (:362).
- System classes (`irissys/`):
  - `Config/LicenseServers.cls`: `CAPITALNAME` 1 (:56); `Name` at most 64 characters (`CommonProperties.cls:47`); `Address` `Config.Host`, at most 256; `Port` an integer with no range; `KeyDirectory` at most 256.
  - `Config/ECPServers.cls`.
  - `Config/config.cls:345-351`: `MaxServerConn` needs a restart, and `MaxServers` does not when memory allows.
  - `Security/System.cls:428-432`: `SSLECPServer` is 0, 1 or 2.
  - `%SYSTEM/License.cls`: `Upgrade` :47-52 answers `1` or `"0|reason"`, not a status; `IsValidKey` :505; `CheckKeyForUpgrade` :526-548.
  - `%LMF.inc:7-8`: the key file is `iris.key`.

**Ports** (`src/OcuPilot/Port/`):

- `AdminPort.cls` (3,507 lines):
  - `TYPESUFFIXES` :123, which holds reads only;
  - `MUTATINGTYPES` :420, with its doc paragraphs at :125-419, and `BODYLESSTYPES` :436;
  - `CONNECTIONTESTTYPES` :475 and `CONNECTIONREADTYPES` :486, the models for a pair-keyed non-mutating type;
  - `QUEUEDWRITES` :687, `SELFQUEUEDTYPES` :696, `ASYNCTIMEOUT` :870;
  - `Invoke` :1053; the 501 for an unadmitted type :1086-1092; `EndpointType` :2692-2711; `ImplementsRead` :2723; `HttpMethodFor` :2677;
  - `Sequence` :2813 (queued-write refusals :2848 and :2872); `AwaitTask` :2913;
  - `LoggedStatus` :3004 and `SecretValues` :3023, which mask `key`; `Refuse` :3041; `Snippet` :3297; `RestStep` :3331.
- `AdminRoutes.cls` holds every Part's non-GET routes: `License.Key` `PUT` `/license/key` :125 and `VALIDATE` `POST /license/key/validate` :126; `License.Server` :127-128; `ECP.*` :105-111.
- `RemoteDatabasePort.cls`: `NetworkEnabled()` :244 is a public seam, reused by Parts B and C; `Unreachable` :352.
- `Test/PortFixture.cls:21` holds a copy of `MUTATINGTYPES` that `ToolWrite` checks.

**Tool models** (`src/OcuPilot/Screen/Tool/`):

- `UserPassword.cls`: `SCREENACTIONS` :30, `SCREENVALUES` :32 and `SECRETBODY` :41. It is a secret-only body reached by a screen action.
- `LdapPassword.cls`: the same shape, with `READANSWERS` and `FINGERPRINTSUBJECT`.
- `ExplorerSave.cls:23`: `ADVERTISED` 0. `Base.cls:47-50` documents it.
- `DeviceCreate.cls`, `DeviceUpdate.cls` and `DeviceDelete.cls` (:39 `READANSWERS`) model a `Config.*` create, update and delete. So do `RemoteDatabaseCreate.cls` (`CREATES` :26, pairs :41-43), `RemoteDatabaseUpdate.cls` (`PERMITTEDFIELDS` :32) and `RemoteDatabaseDelete.cls` (`DESTRUCTIVE` :38, subject :48).
- `JournalSettingsUpdate.cls`: the "shown, never set" model (`JournalPort.SHOWNONLYKEYS` :80), and `EXTRAPAIRS` :56.
- `Write.cls`:
  - `SECRETBODY` :207, `SCREENVALUES` :217, `CLASSICPAGES` :124, `PRECONDITIONCODES` :483;
  - `SecretBodyNames` :586, `SecretFieldNames` :601.
- `Classification.cls`: grammar :6-28; entries from :145, the latest at :568-626. `License.Key`'s `Key` must be `secret`: it is an exact Conventions › Secrets name, and the generator refuses it otherwise.
- `FieldLists.cls` (generated): `License.Key` :269-271, `License.Server` :272-276, `ECP.DataServer` :76-82, `ECP.Settings` :83-92 (nested). `ToolFields.cls` has no License or ECP entry yet.

**Descriptor models** (`src/OcuPilot/Screen/Descriptor/`):

- `DeviceList.cls` and `DeviceForm.cls`: a `Config.*` list with its paired editor.
- `RemoteDatabaseList.cls` (:24-51) and `RemoteDatabaseForm.cls`.
- `JournalSettings.cls`: the singleton (`{single, []}` :34) with a `GET` read (:48).
- `LicenseSummaryTab.cls`: License usage, at position 8 (:25).
- `LdapConfigList.cls:53`: `secretArguments`.
- `AgentDefinitionForm.cls:55`: `context.secretFields`.
- `Screen/Read.cls:577-592`: the projection drops a `context.secretFields` field for both the screen and the tool.
- `Screen/Area.cls:75`: OS management is rail 3, with `%Admin_Operate:USE`, `%Admin_Manage:USE` and `%DB_IRISSYS:READ`.

**Area handlers** (`src/OcuPilot/Area/OsMgmt/`):

- `DeviceRules.cls` (`/device/form`, `/device/name`) and `DeviceSave.cls` (`HandleCreate` :54, `HandleUpdate` :82, `Gate` :341) are the license server form's model.
- `RemoteDatabaseRules.cls` `HandleDirectories` (:189) and `Gate` (:251) are the screen-only check's model.
- `Api/Router.cls`: the device routes :122-125; the UrlMap tail :225-226; the wrapper tail :1648-1652.
- `Api/JournalError.cls`: `Codes()` :101 and `ReasonFor` :114. `Api/DatabaseError.cls`: `ViolationCodes` :203. `Api/Error.cls`: the prefix dispatch at :1224 and :1411-1421.

**Kernel:**

- `Kernel/EntityType.cls:65` `TYPES` holds 46 types, pinned at `Test/Descriptor.cls:1737`.
- `Kernel/EntityRef.cls:59` `IDRULES` provides `foldcase` and `singleton`.
- `Kernel/Proposal/Prohibited.cls`: `COVEREDTYPES` :250 (35), the type check :1035, arms :1101-1206, `ReviewedFewOnly` :2864, the change and create field lists :811 and :933. No arm concerns licensing or ECP.
- `Kernel/Proposal/Impact.cls` kinds :31-52.
- `Kernel/Governance/Baseline.cls`: the OS management block :21-60, and lines appended out of order :136-159.

**Client** (`ui/src/app/`):

- `shell/screen-outlet.ts`: `ARCHETYPE_PAGES` :106-118, `DESCRIPTOR_PAGES` :136-213 (the last Epic 18 entry is :197, and Epic 19's starts at :198), `DESCRIPTOR_EDIT_PAGES` :225-236.
- `shell/screen-action-handler.ts`: `DESTRUCTIVE_ACTIONS` :341, `DESTRUCTIVE_CONSEQUENCES` :367-396, the descriptor constants :108-219.
- `areas/os-management/remote-database-form.store.ts` and `.page.ts`, and `journal-settings.store.ts` and `.page.ts` (shown-only fields :55-58, :269).
- `areas/security/x509-form.page.ts:118-139` and `:559`: a `<textarea>` with Load from file through `FileReader`.
- `areas/security/wallet-secret-form.page.ts:148-180`: a masked field.
- `shell/dialog.ts`.
- `app.ts`: injects :333-336, sign-out resets :657-659.
- `core/strings.ts`: `} as const` :4983; reuse `licenseUsageLabel`, `languageServerFieldAddress`, `sslTestPort`, `tableColumnName`, `actionSave`, `actionDelete`, `actionCreate`, `actionCancel`, `x509LoadFromFile` and `aboutLicenseServer`.
- `ui/tools/strings.test.mjs:582` sets a literal bound of 2500, and `:612ff` holds one key per value.
- There is no `@media print` and no `window.print` anywhere in `ui/src`.
- `ui/angular.json:54` sets `maximumWarning` to 2638kB; it is pinned at `ui/tools/angular-json.test.mjs:455`, with history rows at :349-442. The last measurement is 2,637,325 bytes.

**EXPERIENCE.md** (`_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md`, 1005 lines):

- :164 is the OS management side bar, with fourteen listed entries.
- :173 is Dialogs.
- :375 is System usage, Dashboard and License usage's Fixed strings (Story 16.7).
- :479 is the delete bodies.
- Every `/** EXPERIENCE.md:n */` citation is in `strings.ts`, checked at `ui/tools/strings.test.mjs:816`. An edit in place shifts none.

**Rosters a listed screen, tool, route, type, key or classic page trips.** Re-derive each from its class's red, never by hand. Each count is the current tree's.

- ObjectScript (`src/OcuPilot/Test/`):
  - `Descriptor.cls`: `ReadShapes` :67-162 (93 rows) and the entity count :1737 (46);
  - `ReadTool.cls` :93, :94, :112 and :368;
  - `SurfaceCoverage.cls` :54-327;
  - `EndpointCoverage.cls` :75-241, one probe per route;
  - `Navigation.cls` :486-488 (37);
  - `Wire.cls` :711-714;
  - `WireSecurityRead.cls` :562, :569 and :572;
  - `WireAreaAnyScreen.cls:271` (14 listed);
  - `PortGate.cls:28` (27 ports);
  - `ClassicPageGate.cls` `OWNPAIRS` :74 and `Roster` :368;
  - `MappingDescriptor.cls:23` `CLASSICROSTER`;
  - `DraftRegistry.cls` :101, :122, :161 and :214;
  - `ToolRoundTrip.cls:65`;
  - `Prohibited.cls` (test) :232;
  - `GovernanceBaseline.cls:14`, `Governance.cls` :17-39, `ToolDispatch.cls:157`;
  - `ToolWrite.cls` :1221-1323.
- Unaffected, because Part A's screens declare no own pair: `LanguageServerWire.cls:279-282` and `ui/browser/language-servers.browser-spec.mjs:343-372` (AC5 keeps a floor of 9 open entries and an exact refused list).
- Client: `ui/tools/navigation.test.mjs` :135-301 and :317-339; `ui/tools/navigation-wire.test.mjs` :90-358 and :664-697; `ui/src/app/shell/rail-wire.spec.ts` :87-362 and :709-770; `ui/src/app/shell/area-verdict.spec.ts` :49-70 and :153-171.
- Browser lists that pin OS management's entries:
  - `license-usage.browser-spec.mjs:128-150` (`deepEqual` of 14);
  - `remote-databases.browser-spec.mjs:299-317` (`deepEqual` of 14);
  - `journals.browser-spec.mjs:276-280` (length 14);
  - `journal-settings.browser-spec.mjs:226-229` (length 14).

  `local-databases` (`slice(0, 11)`) and `namespaces` (`slice(0, 7)`) are unaffected.
- CI: `scripts/ci-throwaway.sh` has seventeen `OCUPILOT_ALLOW_*` variables, each with `# classes:` lines (`PRINCIPALS` :308, `DATABASE_CONFIG` :473). `ui/tools/ci.test.mjs:2096-2200` holds each set equal.

**Test models:**

- `Test/RemoteDatabaseProbe.cls`: `SeedServer` :79, `SeedPrincipal` :247, `RemoveAll` :275, `Run` :428, `RunAs` :461, `Snapshot` :602, `Diff` :730.
- `Test/RemoteDatabaseListingPort.cls`: the seam (`NetworkEnabled` :100, armed by `^||OcuPilotRemoteLicensed`).
- `Test/JournalProbe.cls`: `RemoveProbeTaskRows` :672, for Part B's queued action.
- `ui/browser/remote-databases.browser-spec.mjs` and `journals.browser-spec.mjs`: `iris()`, the throwaway guard and `assertStructure`.

## Tasks & Acceptance

### Part A: Licensing (Story 18.6)

**Task 0, the implement stage's first task, before any descriptor, tool or page.** Run it on `ocupilot-b-ci` only, and load with `/tmp/epic-18-d6/load-throwaway.sh`, with no restart. Record each result under Design Notes › Measured at implement, and each AD sentence in `## Spec Change Log` for the runner.

1. **Plumbing:**
   - `Port/AdminPort.cls`, add-only:
     - `CHECKTYPES = "License.Key/VALIDATE"`: a pair-keyed, non-mutating type that takes a body, runs in process, is never queued and stores nothing. It is admitted in `EndpointType` beside `CONNECTIONREADTYPES`.
     - `License.Key/PUT,License.Server/PUT,License.Server/DELETE` join `MUTATINGTYPES`, with one doc paragraph, and `Test/PortFixture.cls:21`'s copy.
   - Write `src/OcuPilot/Test/LicenseProbe.cls`, on the `RemoteDatabaseProbe` model: `SeedServer`, `SeedPrincipal`, `Run`, `RunAs`, `Snapshot`, `Diff` and `RemoveAll`, over `OCUPROBE186*` license servers and the principal `OcuProbe186T0User`.
2. **Take S0.** It holds:
   - the license facts: `KeyCustomerName`, `KeyOrderNumber`, `KeyLicenseCapacity`, `KeyExpirationDate`, `KeyServer`, `KeyLicenseUnits` and `IsPendingActivation`;
   - `<mgr>iris.key` and `iris_saved.key`: whether each exists, its size and its modification time;
   - the count of `*.key` files in the directory `%File.TempFilename` uses;
   - the `Config.LicenseServers` rows;
   - the process count and job types;
   - the `messages.log` and `alerts.log` line counts, and the monitor state;
   - OcuPilot's own objects.
3. **Reads.**
   - a. `License.Key` `GET`: its keys, their JSON types and its duration.
   - b. `License.Server` `LIST`, and `GET` in lower and upper case, timed.
4. **The license, read-only paths.**
   - c. `VALIDATE` with `{Key:"OCUPROBE186 is not a license key"}`. Record the answer, `InvalidReason` (locally only, never into the spec if it holds a path), the duration, the temporary key-file count, and a `Diff`.
   - d. `VALIDATE` with `{Key:""}` and with `{}`.
   - e. **Only if c answered `IsValid` false:** `PUT` with the identical text. Expect 400, no `iris.key`, every license fact unchanged and `IsPendingActivation` 0.
   - f. With auditing on, record the events c and e wrote.
5. **License servers:**
   - g. `PUT name=ocuprobe186a {Address:"127.0.0.1", Port:4999}`, expecting 201. Then the stored name, `GET` in both cases, and `LIST`.
   - h. `PUT {Port:4998}` alone: are `Address` and `KeyDirectory` kept?
   - i. A `PUT` of the fresh `GET` body unchanged: its answer and event.
   - j. The vendor's answer to a name with a space or a dot, to port 0 and port 70000, and to an empty address on a create.
   - k. `DELETE`, expecting 200; then `DELETE` again, expecting 404.
   - l. After g, h and k: the processes and the `messages.log` lines. A license server entry must start nothing on a Single key.
   - m. With auditing on, the events g, h and k wrote.
6. **Pairs.** Use a principal holding exactly `%Admin_Manage:USE` and `%DB_IRISSYS:READ`, plus the install namespace's code read.
   - Run a, b, c, e (the malformed text only), g, h and k.
   - For each refused step, repeat it with each candidate alone: `%DB_IRISSYS:WRITE`, `%Admin_Secure:USE` and `%Admin_Operate:USE`. Record every answer.
7. **Cleanup proof:** run `RemoveAll`, then take S2. It must equal S0, apart from counters, the declared `messages.log` lines, and the monitor state, which is cleared with `$SYSTEM.Monitor.Clear()` if it moved.
8. **HALT** `blocked`, with blocking condition `intent gap: observation contradicts the plan: <what>` and nothing built, if any of these hold:
   - a route cannot be reached through `AdminPort`, or answers 202;
   - c answers `IsValid` true;
   - any step changes a license fact, creates `iris.key` or `iris_saved.key`, or sets `IsPendingActivation`;
   - a temporary key file outlives a call;
   - a license server entry starts a process, or writes a `messages.log` line above severity 0;
   - a read takes more than 2 s;
   - a write needs a pair outside the screen's set plus `%DB_IRISSYS:WRITE`. Record step 6's evidence first, for the orchestrator's ruling;
   - S2 differs from S0 beyond the declared differences.
9. **Otherwise, set from the record:**
   - the license server tools' pairs (drop `%DB_IRISSYS:WRITE` if step 6 shows it is not needed);
   - `KeyDirectory`'s handling. If h kept it, the update sends `{Address, Port}`. If h erased it, the update also sends the stored `KeyDirectory` unchanged, and it is still never settable;
   - each AD-15/AD-53 named case, where m or f found no vendor event;
   - the canonical name, upper case, if g confirms.

**Execution (server):**

- `src/OcuPilot/Port/LicensePort.cls` (new; it extends `AdminPort` and names no vendor class):
  - **`Validate(pKey, Output pAnswer, Output pHttp, Output pFault)`.** It refuses an empty key as `LICENSE.KEY.EMPTY`, and a key over 16,384 characters as `LICENSE.KEY.INVALID`, before any call. Then it sends `VALIDATE` and maps the answer to `{valid, requiresRestart, reductions:[{kind, from, to}], features:[]}`. `kind` is one of `Cores`, `Users`, `Server`, `LicenseType` or `Product`. The vendor's `InvalidReason` and `RestartReason` text is never returned, and an invalid key answers 422 `LICENSE.KEY.INVALID` on `Key`.
  - **`Invoke` for `License.Key/PUT`** runs `Validate` with the same body first, refuses as above, and only then sends the vendor `PUT`. It answers no `Key` back.
  - **`Snippet`** mirrors both branches (AD-59), with the secret rendered as `"<Key>"`.
- `src/OcuPilot/Screen/Tool/LicenseKeyActivate.cls` (new; descriptor `LicenseKey`; port `LicensePort`):
  - `WRITETYPE` `PUT`, `SENDSBODY` 0, `SECRETBODY` `Key` and `STATEFIELD` `Key`;
  - `SCREENACTIONS` `activate` and `SCREENVALUES` `activate=Key`;
  - `ADVERTISED` 0, `DESTRUCTIVE` 1;
  - `READANSWERS`, `PRECONDITIONFIELD` and `FINGERPRINTSUBJECT` `CustomerName,OrderNumber,ExpirationDate,LicenseCapacity`;
  - `CLASSICPAGES` `%CSP.UI.Portal.Dialog.LicenseActivate`;
  - `Consequence`: "Activating replaces this instance's license key. This cannot be undone here.", plus the restart sentence and the reduction sentences from the screen's last validation.
- `src/OcuPilot/Screen/Tool/LicenseServerCreate.cls`, `LicenseServerUpdate.cls` and `LicenseServerDelete.cls` (new; descriptor `LicenseServerList`; the Device trio's shape). They follow the Boundaries, and the update's `PERMITTEDFIELDS` are `Address,Port`. The delete has `SENDSBODY` 0, `READANSWERS` `Address,Port,KeyDirectory`, `PRECONDITIONFIELD` `Address`, `REMOVALROWS` `Address,Port` and no impact kind.
  - Its consequence, when the License key read answers `Server` `Multi`: "This instance's license key is a multi-server key. Removing a license server it uses can leave it unable to obtain license units." That clause is an inference.
- `src/OcuPilot/Screen/Tool/Classification.cls` (add-only): entries for the four tools. `Key` is secret. `Address` and `Port` are ordinary, with a `compare` only where Task 0's steps g to i show the vendor normalizing a value. Then regenerate `ToolFields.cls` with `cd ui && node tools/field-lists.mjs`.
- `src/OcuPilot/Kernel/EntityType.cls`: `license-key` and `license-server` join `TYPES`, each with its doc line. `src/OcuPilot/Kernel/EntityRef.cls` adds `license-key:singleton` and `license-server:foldcase`.
- `src/OcuPilot/Kernel/Proposal/Prohibited.cls` (add-only): both types join `COVEREDTYPES` and the type check at :1035, through `ReviewedFewOnly`. The create and change lists are `Address,Port` for `license-server`, and none for `license-key`, whose write sends only its secret.
- `src/OcuPilot/Kernel/Governance/Baseline.cls` (add-only): `osmgmt.licensekey.activate` false, `osmgmt.licenseservers.create` true, `.delete` false, `.update` true.
- `src/OcuPilot/Area/OsMgmt/LicenseRules.cls` (new):
  - `HandleValidate()` serves `POST /license/key/validate`. It gates on the `LicenseKey` descriptor (`Screen.Gate.Evaluate`, else `Kernel/Denial.Envelope`, with zero port calls), reads `{Key}`, and calls `LicensePort.Validate`. It answers with `Cache-Control: no-store` and logs nothing of the body.
  - `Problem` covers the name, address and port rules.
  - `HandleForm()` serves `GET /license-server/form?name=`.
  - `HandleName()` serves `GET /license-server/name?name=`, as `DeviceRules` does.
- `src/OcuPilot/Area/OsMgmt/LicenseServerSave.cls` (new, on the `DeviceSave` model): `POST /license-server` and `PUT /license-server/:id` go through the tools (AD-55). A port fault becomes a violation on its field.
- `src/OcuPilot/Api/Router.cls` (add-only): the five routes and their thin wrappers. `/license-server/form` and `/license-server/name` come before `/license-server/:id`.
- `src/OcuPilot/Api/LicenseError.cls` (new): `Codes()`, `ReasonFor` and `ViolationCodes`. `src/OcuPilot/Api/Error.cls` gains one `LICENSE.` dispatch line at each of :1224 and :1421 (add-only). The codes:
  - `LICENSE.KEY.EMPTY` (422, Key): "Paste the license key's text or load it from its file."
  - `LICENSE.KEY.INVALID` (422, Key): "This is not a valid license key for this instance."
  - `LICENSE.SERVER.NAME.SHAPE` (422, Name): "Use up to 64 letters, digits, hyphens and underscores, starting with a letter or digit."
  - `LICENSE.SERVER.NAME.TAKEN` (422, Name): "A license server of that name already exists."
  - `LICENSE.SERVER.ADDRESS` (422, Address): "Enter the license server's host name or IP address."
  - `LICENSE.SERVER.PORT` (422, Port): "Enter a port from 1 to 65535."
- `src/OcuPilot/Screen/Descriptor/LicenseKey.cls`, `LicenseServerList.cls` and `LicenseServerForm.cls` (new), following the Boundaries:
  - `LicenseKey` declares `primaryAction` `activate` and `secretArguments` `["Key"]`, and puts `AuthorizationKey` in `context.secretFields`.
  - `LicenseServerList` declares `primaryAction` `create` and `rowActions` `delete`. Its read is `License.Server` `LIST` over `Name, Address, Port, KeyDirectory`, and its table has those four columns and its two empty-state keys.
  - Each carries three prompts.

**Execution (client):**

- `ui/src/app/areas/os-management/license-key.page.ts` (new, with a spec), registered in `DESCRIPTOR_PAGES`:
  - It reads through the screen read and lists the thirteen fields; each array is joined, and an empty one reads "(none)". It shows the line "The authorization key is not shown here."
  - **Activate new key** opens an `app-dialog`:
    - a monospace `<textarea>` labeled "License key text", with `autocomplete=off` and `spellcheck=false`, and Load from file (`x509-form.page.ts` model, `.key`);
    - **Validate** posts to `/api/ocupilot/license/key/validate` and shows the validity, restart and reduction sentences;
    - **Activate** is the destructive button. It is enabled only while the last validation of the current text answered valid, and it carries the consequence. It sends the screen action `activate` with `values.Key`.
    - The text lives in a page-local signal, cleared on close and after a successful activation. It never enters the store.
  - **Print** calls `window.print()`.
- `ui/src/styles/_print.scss` (new; imported once): under `@media print`, it hides the rail, header, side bar, panel and status bar, and shows `.ocu-print-region` alone. It uses tokens only. The License key page marks its field block and a print-only "Printed by <user> on <time>." line.
- `ui/src/app/areas/os-management/license-server-form.page.ts` and `.store.ts` (new, with specs; the Device form model):
  - Name appears on a create only. Address and Port are editable.
  - `KeyDirectory` is shown read-only on an edit, with the hint "Set on the classic License Servers page."
  - The unsaved-changes guard applies, and a refusal's reason renders on its field.
- `ui/src/app/areas/os-management/license-server-actions.ts`: Create navigates to the form.
- `ui/src/app/shell/screen-outlet.ts` and `ui/src/app/shell/screen-action-handler.ts`: the license server delete is destructive, with its typed name and its body. Its `DESTRUCTIVE_CONSEQUENCES` entry is add-only, after :395.
- `ui/src/app/app.ts`: the form store's injection and its sign-out reset.
- `ui/src/app/core/strings.ts` (add-only, after :4982): each new key under its `/** EXPERIENCE.md:n */` line, reusing the keys the Code Map names. Raise `ui/tools/strings.test.mjs:582`'s bound only if the literals cross 2500.
- Regenerate `ui/src/app/core/screens.generated.ts` with `cd ui && node tools/screen-mirror.mjs`.
- `ui/angular.json`: re-base `maximumWarning` under DW-1166 to the measured initial total, rounded up to the next kB, with its history row in `ui/tools/angular-json.test.mjs`. Stop and ask above 3800kB.
- **EXPERIENCE.md, in place, keeping 1005 lines.** Then run `cd ui && npm run test:tools`.
  - :164 gains "· License key (Stage 2, Story 18.6) · License servers (Stage 2, Story 18.6)", the fifteenth and sixteenth entries.
  - :173 gains "activate a license key (Story 18.6: the key's text, Validate, then Activate at the destructive treatment)", and its delete list gains "license server".
  - :375 gains "; and License key and License servers (Story 18.6): …", tagged `[ADDED <date> - Story 18.6]`, with every new literal:
    - the screen and entity labels, and the field labels ("License capacity", "Customer name", "Order number", "Product", "License type", "Key server", "Platform", "License units", "Cores licensed", "Cores enforced", "Expiration date", "Extended features", "Authorized applications");
    - the authorization-key line, "Activate new key", the dialog's title "Activate a new license key", "License key text", "Validate", "Activate" and "Print";
    - "This key is valid for this instance.", the restart sentence "Activating this key requires restarting the instance.", and "Activating this key will:" with the classic dialog's six reduction lines in plain form;
    - the consequence, and "Printed by <user> on <time>.";
    - "Host name or IP address", "Key directory", the KeyDirectory hint, and the empty state "No license servers on this instance.";
    - each screen's three prompts.
  - :479 gains "then Delete on a license server (Story 18.6): "Deleting this license server removes it from this instance's configuration. This cannot be undone."".

**Rosters and CI:**

- Extend every roster in Code Map › Rosters. The browser lists grow from 14 to 16 entries.
- `scripts/ci-throwaway.sh` (add-only): a new `OCUPILOT_ALLOW_LICENSE_CONFIG` with its `# classes:` line for the classes that write license servers, plus those classes on `OCUPILOT_ALLOW_PRINCIPALS`'s lines. Keep `ui/tools/ci.test.mjs` equal.

**Tests:**

- `src/OcuPilot/Test/LicenseProbe.cls`: Task 0's helper, its seeding and `RemoveAll`, run before all tests, after each and after all.
- `src/OcuPilot/Test/LicenseSeamPort.cls`: a `LicensePort` subclass whose `License.Key` `VALIDATE` and `PUT` answer canned results and count calls, with no vendor call. It is armed per test.
- `src/OcuPilot/Test/LicenseKey.cls`:
  - the read and the tool answer the same thirteen fields, and neither answers `AuthorizationKey`, its key or its value;
  - the real malformed validate, and the empty and oversized refusals;
  - the seam's valid answer and its sentences;
  - the activate through the screen action, real on the malformed key and seamed when valid, asserting the call order;
  - the marker key's absence from `messages.log` (`LinesAfter`), the ledger and the answers;
  - the tool's absence from the provider tool list, from dispatch and from the context's `tools`;
  - the license facts unchanged after the class.
- `src/OcuPilot/Test/LicenseServerWrite.cls`: the matrix's server legs on both callers, with real vendor writes, the read-back, and the canonical name.
- `src/OcuPilot/Test/LicenseWriteGate.cls`, with `LicenseWriteGateProbe.cls`: every declared pair refused by name with zero port calls, and the validate route's gate.
- `src/OcuPilot/Test/LicenseDescriptor.cls`:
  - the three descriptors' routes, positions, pairs, classic pages, prompts, entity types, id rules and `secretFields`;
  - `LicenseError`'s `Codes()` and its sentences;
  - the baseline's four keys.
- Component specs for the License key page, including the dialog's gating and its page-local text, the form page and its store, and the actions.
- `ui/browser/license-key.browser-spec.mjs` (new; it refuses a non-throwaway as `journals.browser-spec.mjs` does):
  - the side bar's fifteenth entry, and the fields;
  - no authorization key anywhere in the DOM;
  - pasting the malformed text and pressing Validate shows the reason on the field, and Activate stays disabled;
  - print emulation (`page.emulateMediaType('print')`) shows only the print region;
  - the DW-1337 gate in both themes, on the page and on the dialog.
- `ui/browser/license-servers.browser-spec.mjs` (new):
  - the sixteenth entry;
  - create, edit and delete a probe server through the UI, the delete through the typed-name dialog;
  - the DW-1337 gate in both themes;
  - cleanup over `docker exec`.

**Acceptance Criteria (Part A):**

- **A0:** Given `ocupilot-b-ci`, when the implement stage starts, then Task 0 records the payloads, durations, effects, pairs and audit events of `License.Key` and `License.Server` before any descriptor, tool or page exists. The license reads exactly as found throughout, and S2 equals S0 apart from the declared differences. A contradiction halts the story.
- **A1:** Given the instance's license, when License key opens and `osmgmt.licensekey.read` runs, then both answer the same thirteen fields through one read, and neither answer, the DOM, screen context nor a tool result carries `AuthorizationKey`.
- **A2:** Given a key's text, when a person validates it, then the screen shows OcuPilot's validity, restart and reduction sentences and never vendor text. A malformed or empty text is refused on the field, and the license, `iris.key` and the temporary directory read as before.
- **A3:** Given a validated key, when a person activates it, then `LicensePort` validates the same text again and sends the `PUT` only when it is valid. A malformed text sends no `PUT`. The key's text never reaches a log, the ledger, the store, context, a proposal or a response, and no agent tool, dispatch or context lists the activation.
- **A4:** Given License key, when a person prints it, then print media shows the fields and the "Printed by" line without the shell chrome.
- **A5:** Given license servers, when a person or a confirmed proposal creates, edits or deletes one, then `License.Server` `PUT` or `DELETE` round-trips. The list shows the change after the change event, the read-back reads `matches` (or absent for a delete), and `KeyDirectory` is never sent from a caller's value.
- **A6:** Given a bad name, address or port, an absent target, or a caller lacking a declared pair, when either caller writes, then it is refused on the field, as not found, or 403 naming the pair, and nothing is sent.
- **A7:** Given the rosters, when the story lands, then License key and License servers are OS management's fifteenth and sixteenth entries with three prompts each, the four keys are in the baseline (activate and delete disabled), every roster and pinned side-bar list includes them, the DW-1337 gate holds in both themes, and EXPERIENCE.md reads 1005 lines.

### Part B: ECP data servers (recommended Story 18.20)

**Scope.** These are classic `%CSP.UI.Portal.ECPDataServers` and `%CSP.UI.Portal.Dialog.ECPDataServer`.

- `EcpDataServerList` is a list at `os-management/ecp-data-servers`, position 17 (the next free one). It has entity `ecp-data-server` with id `[Name]` and rule `foldcase` (`CAPITALNAME` 1). Its read is `ECP.DataServer` `LIST` over `Name, RemoteAddress, RemotePort, Status, MirrorConnection, SSLConfig, BatchMode`. Its primary action is `create`, and its row actions are `changestatus` and `delete`.
- `EcpDataServerForm` is at `os-management/ecp-data-servers/edit`, position 0.
- Both declare `%Admin_Manage:USE` and `%DB_IRISSYS:READ`, and each screen carries the caveat that the harvested ECP status implementation was never identified, so these screens rely on the routes alone.

**Tools and port:**

- `osmgmt.ecpdataservers.create` (AD-54) sends `{Address, Port, MirrorConnection, SSLConfig, BatchMode}`.
- `.update` (AD-4) sends the complete set read fresh. It keeps a stored non-zero `MirrorConnection`, as the classic dialog does.
- `.delete` (AD-51, `DESTRUCTIVE`) has an impact that names the remote databases using the server, through Remote databases' declared read. The vendor's 409 #423 reads `ECP.DATASERVER.INUSE`.
- `.changestatus` is an AD-51 action:
  - Its argument `Status` is one of `notconnected`, `disabled` or `normal`, from which `Port/EcpPort` (new, extends `AdminPort`) builds `{Action}`.
  - `SERVERACTION` joins `QUEUEDWRITES`, and the tool declares `%Admin_Operate:USE` for the poll.
  - Its fresh read is the `LIST` row by name, with `Status` as its subject.
  - Choosing the current status is refused `ECP.STATUS.SAME`.
  - `normal` is refused `ECP.LICENSE` at once, before anything is queued, when `RemoteDatabasePort.NetworkEnabled()` is 0.
  - It is `DESTRUCTIVE`, and its consequence is the classic warning.
  - Past the bound, it answers "started".
- `CLASSICPAGES`: create, update and change status declare `%CSP.UI.Portal.Dialog.ECPDataServer`; the delete declares none.
- Keys: create and update `true`; delete and changestatus `false`.

**Routes:** `GET /ecp-data-server/form`, `GET /ecp-data-server/name`, `POST /ecp-data-server` and `PUT /ecp-data-server/:id`. The status action goes through `POST /screens/:screen/action`.

**Task 0:**

- Measure with probe server `OCUPROBE186SRV` at `127.0.0.1:1972`, configuration only.
- Measure the create, a partial `PUT` (are omitted keys kept?), the name case, and `DELETE`, also while a seeded remote database uses the server (#423).
- Measure `SERVERACTION` 2 and then 1 on the probe server, while it reads Not Connected. Record each answer (expecting 202), the poll, the duration against `ASYNCTIMEOUT`, the status after, the processes and the `messages.log` lines, and the answer to `Action` 4.
- Measure the audit events, and the pairs with the screen's set and each candidate (`%DB_IRISSYS:WRITE`, `%Admin_Operate:USE`, `%Admin_Secure:USE` for `SSLConfig`).
- `SERVERACTION` 3 never reaches the vendor.
- **Halt** if:
  - an ECP client or server job (`ECPCliR`, `ECPCliW`, `ECPSvrR`) starts;
  - a status changes beyond the one requested;
  - a license fact changes;
  - a pair outside the candidates is needed;
  - S2 differs from S0.

**ACs:**

- **B1:** Given probe data servers, when the list opens and its read tool runs, then both answer the same rows.
- **B2:** Given the form, when a person or a confirmed proposal creates or edits a data server, then `ECP.DataServer` `PUT` round-trips with the read-back.
- **B3:** Given a data server a remote database uses, when it is deleted, then the advisory names that remote database first and the delete is refused `ECP.DATASERVER.INUSE`. An unused one is deleted.
- **B4:** Given a data server, when its status is changed to Disabled or Not Connected, then the queued action is polled once and the list shows the new status. Past the bound it answers "started".
- **B5:** Given an unlicensed instance, when Normal is chosen, then it is refused `ECP.LICENSE` at once and nothing is queued. A seam stands in for a licensed instance.
- **B6:** Given pairs, governance, rosters and the side bar, when the story lands, then each holds as in A6 and A7, and the DW-1337 gate holds in both themes.

**Size:** about Story 18.16 plus an async action. That is two descriptors, four tools, one port, about ten test classes, a form page and store, and one browser spec.

**Consumes:** 18.16's `NetworkEnabled` seam and Remote databases' read. **Amendments:**

- AD-8: the pairs;
- AD-13: `ecp-data-server` `foldcase`;
- AD-26: `SERVERACTION` in `QUEUEDWRITES`, the last Stage 2 async path;
- AD-44: `CLASSICPAGES`;
- AD-51: `EcpPort`'s `{Action}`, and `ECP.STATUS.SAME` in `PRECONDITIONCODES` if it applies;
- AD-8: the delete's impact;
- AD-15 and AD-53: a named case if `SERVERACTION` records no event.

### Part C: ECP settings and ECP application servers (recommended Story 18.21)

**Scope:**

- **`EcpSettings`** is a form-page at `os-management/ecp-settings`, position 18. Its entity is `ecp-settings` (singleton), and its classic page is `%CSP.UI.Portal.ECP`.
  - Its read is `ECP.Settings` `GET`, over member fields `AppServerSettings.MaxServers` through `DataServerSettings.SSLECPServer`.
  - When the license enables no ECP, the page shows the classic page's sentence.
- **`EcpAppServerList`** is a tab group at `os-management/ecp-application-servers`, position 19, with classic page `%CSP.UI.Portal.ECPAppServers`:
  - Connections reads `ECP.AppServerList` `LIST`, with entity `ecp-application-server` and id `[ClientName]`. It is read-only.
  - SSL/TLS authorizations is an unlisted tab. It reads `ECP.AppServerSSLConnection` `LIST`, with entity `ecp-ssl-connection` and id `[SSLComputerName]`.
- Every screen declares `%Admin_Manage:USE` and `%DB_IRISSYS:READ`.

**Tools:**

- **`osmgmt.ecpsettings.update`** (AD-4) is the first merge over a nested body. Part C's plan decides between the kernel's merge over dotted fields and a port that flattens them, from Task 0's evidence.
  - It declares the argument pair `%Admin_Secure:USE` when `SSLECPServer` changes, as the classic page requires.
  - It refuses `SSLECPServer` 1 or 2 while the `%ECPServer` SSL/TLS configuration is absent or disabled (`ECP.SSL.NOSERVERCONFIG`).
  - Its consequence says a changed `MaxServerConn` takes effect after a restart.
- **`osmgmt.ecpsslconnections.authorize`** and **`.reject`** are AD-51 actions. Their fresh read must find a `Pending` row, because the vendor answers OK for any name.
- **`.delete`** removes an `Authorized` row, `DESTRUCTIVE`.
- Keys: update, authorize and reject `true`; delete `false`.

**Routes:** `PUT /ecp/settings`, through the tool, and the screen actions.

**Task 0:**

- Settings: `PUT` each field to a probe value and back, restoring the exact values. Check that a partial `PUT` keeps the rest, and whether a restored `MaxServerConn` leaves a pending-restart state; that is a halt. Record `SSLECPServer` 1 with no `%ECPServer` (restored to 0).
- `LIST` on Community, where it is empty.
- SSL/TLS authorizations:
  - seed `CN=OCUPROBE186` with test-only `SYS.ECP.AddAuthorizedCN`;
  - read it through `LIST`, then `DELETE` it;
  - send `AUTHORIZE` and `REJECT` for a name that is not pending, and record whether either changes a list.
- The audit events, and the pairs with each candidate.

**ACs:**

- **C1:** Given ECP settings, when a person or a confirmed proposal changes a setting, then the complete nested set round-trips and the restart consequence is stated for `MaxServerConn`.
- **C2:** Given `SSLECPServer` 1 or 2 without an enabled `%ECPServer`, or a caller without `%Admin_Secure:USE`, when the change is saved, then it is refused and nothing is sent.
- **C3:** Given the application servers, when the tabs open and their read tools run, then each answers its rows.
- **C4:** Given a seeded authorized name, when it is deleted, then it leaves the list. Given a name not pending, when it is authorized or rejected, then it is refused as absent with nothing sent; the success path runs through a seam.
- **C5:** Given the rosters, governance and the side bar, when the story lands, then each holds as in A7, and the DW-1337 gate holds in both themes.

**Size:** about Story 18.18's singleton editor, made larger by the nested body, plus a two-tab list with three action tools.

**Consumes:** Part B's `EcpError` and the license sentence. **Amendments:**

- AD-4: the nested merge;
- AD-8: the pairs and `SSLECPServer`'s argument pair;
- AD-13: two new entity types;
- AD-44: `CLASSICPAGES`;
- AD-15 and AD-53: named cases if `RemoveFromPendingList` or `RemoveAuthorizedCN` records no event.

**Order and dependencies.**

- A first: it depends on nothing outside 18.1-18.19, and it adds the License key and License servers screens that Part B's license sentences do not need.
- B next: it consumes 18.16 directly, and introduces `EcpError`, `EcpPort` and the ECP license refusal.
- C last: it reuses B's license sentence on its own screens.

Each part re-bases the bundle once, and each adds its own entries to the same pinned side-bar lists.

## Spec Change Log

## Review Triage Log

## Design Notes

**Governing ADs (Part A).**

- AD-2, AD-27, AD-52: `LicensePort` extends `AdminPort` and names no vendor class. No AD-27 named case is needed, because every call is an admin API route.
- AD-3: the derived fields, with `Key` classified secret.
- AD-4: the server update's complete `{Address, Port}`.
- AD-5, AD-36, AD-44: one descriptor per screen, one read each, the classic pages and `CLASSICPAGES`.
- AD-6, AD-34, AD-40, AD-53, AD-55: the server tools' two callers, and the activation's screen caller only.
- AD-8, AD-29: the pairs and the validate route's gate.
- AD-10: no new arm (Decisions 4).
- AD-13, AD-14: two new entity types and their events.
- AD-15, AD-53: the vendor's events, or named cases.
- AD-21: no path; `KeyDirectory` is shown, never set.
- AD-22: the baseline.
- AD-24, AD-35, AD-36, AD-48: the key text and the authorization key are never returned.
- AD-39: OcuPilot's own sentences; vendor text is logged, never sent.
- AD-51, AD-56 (i): the activation's secret-only body. AD-54: the create.
- AD-58: the read-back. AD-59: `Snippet` with `"<Key>"`.

**Measured before this plan** (not re-run): `ECP.DataServer` `LIST` takes 0.008 s and `GET` 0.001 s. A data server's configuration starts nothing until a `DBLIST` runs, and a `DBLIST` on Community starts daemons that outlive the call (Story 18.16, Design Notes).

**Measured at plan** (read-only, on `ocupilot-b-ci`, 2026-10-03 UTC):

- `NetworkEnabled()` is 0, `MaxECPServers()` 0, and `KeyServer()` Single.
- There is no `<mgr>iris.key`. `KeyFileType()` ends in `$Char(0)`.
- Through `AdminPort` as `_SYSTEM`:
  - `License.Key` `GET` answered 200 in 0.004 s with the fourteen keys (`ExtendedFeaturesList` holds 18 entries and `AuthorizedApplications` `[]`).
  - `License.Server` `LIST` answered 0.015 s with the one row `LOCAL | 127.0.0.1 | 4002 | ""`. `GET name=local` answered `LOCAL`'s row, and `name=NOSUCH186` 404 `PORT.NOTFOUND`.
  - `ECP.Settings` `GET` answered 0.002 s: `{AppServerSettings{MaxServers 2, ClientReconnectDuration 1200, ClientReconnectInterval 5}, DataServerSettings{MaxServerConn 1, ServerTroubleDuration 60, SSLECPServer 0}}`.
  - `ECP.AppServerList`, `ECP.AppServerSSLConnection` and `ECP.DataServer` `LIST` each answered `[]` in under 0.01 s.
- `%Service_ECP` is disabled, and neither `%ECPServer` nor `%ECPClient` exists.

**Decisions.** Each is applied in this plan unless the orchestrator rules otherwise at the merge gate.

1. **The activation is unadvertised, and its key ships disabled** (AD-53's third unadvertised case, after `security.auditing.purge` and System Explorer's Save).
   - The key's text is the license itself. It is key material that the generator classifies secret (an exact `Key`) and that the model must never see or supply.
   - It is a multi-line file. A masked single-line field on a proposal card cannot carry it.
   - An agent proposal whose card asks a person to paste a license would add nothing that the screen's dialog does not already do.
   - The read tool still answers the license, so the agent can explain it.
2. **`AuthorizationKey` is never returned**, and the screen omits it, narrower than the classic page. With the other fields shown, the authorization key completes the key file's content. The epic context makes key material write-only, so the screen and the agent show everything else, and the classic page remains for it.
3. **`KeyDirectory` is shown, never set**, as AD-21 already does for an SSL/TLS configuration's and an external language server's locations. The directory may name a path on another host (the license server's), which `PathPort`'s roots cannot express.
4. **No new AD-10 arm.** Two writes could cost the instance license units, and with them new sign-ins, OcuPilot's own included (inference):
   - an activation whose key reduces capacity;
   - deleting a license server under a multi-server key.

   Neither can be measured here. Both are destructive with a stated consequence, as the classic pages confirm them, and that follows the owner's "developer tool first" direction.
5. **Placement.** The new screens are appended to OS management in landing order (15 to 19), not inserted beside License usage. Inserting them would move the ordinal prose at EXPERIENCE.md :375-:378 and every pinned list twice.
6. **The print page's custom resource** is not honored separately. Print is the License key screen's own render under its gate, and it shows nothing the screen does not.

**Named limits:**

1. **The activation's success path is never run on any instance.** Its pairs beyond the vendor's gate and `IsValidKey` are unmeasured (inference: `Upgrade()` checks no resource), and so is whether IRIS records an event for it. The vendor writes `iris.key` before `Upgrade()`, so a failed upgrade can leave a key pending until a restart (inference from the vendor source). The screen states the restart and the reductions that `VALIDATE` reports.
2. **On Community, every ECP list is empty** and no ECP status can reach Normal. Parts B and C pin their success paths through seams.

**Proposed spine amendments (Rule 20; the runner writes them at the spec gate for Part A).** Task 0 confirms each `<measured>`.

1. **AD-8, after Story 18.18's paragraph:** "**Story 18.6's licensing screens** [AMENDED <date>, Story 18.6 spec gate, Rule 20]: License key and License servers declare OS management's `%Admin_Manage:USE` and `%DB_IRISSYS:READ`, the classic pages' `RESOURCE`; `osmgmt.licenseservers.create`, `.update` and `.delete` declare `%DB_IRISSYS:WRITE` <measured>, each refused by name before any port call. `osmgmt.licensekey.activate` declares the screen's set; its success path is never run on any instance, so a pair `Upgrade()` might need beyond them is unmeasured."
2. **AD-13, after the `journal-record` sentence:** "`license-key` is a singleton; `license-server` keeps `foldcase`, because the instance stores the name in upper case and resolves any case (read on `ocupilot-b-ci`: `local` reads `LOCAL`) (Story 18.6) [AMENDED <date>, Story 18.6 spec gate, Rule 20]."
3. **AD-21, after the eighth case's journal-settings sentence:** "A license key is activated and validated from its text, which the person pastes or loads from a local file in the browser, never from a server path: the classic dialog's server file and the print page's `Filename` are not carried. A license server's `KeyDirectory` is a location too: shown, never set (Story 18.6) [AMENDED <date>, Story 18.6 spec gate, Rule 20]."
4. **AD-36, after the journal record paragraph:** "**A license's authorization key is never returned** (Story 18.6) [AMENDED <date>, Story 18.6 spec gate, Rule 20]: License key's read declares `AuthorizationKey` secret, so neither the screen nor its tool answers it, because with the fields shown it completes the key file; the key's text a person validates or activates is a secret that reaches no answer, store, context, ledger or log line."
5. **AD-44, after Story 18.19's sentence:** "**Story 18.6's `CLASSICPAGES`**: the license key activation declares `%CSP.UI.Portal.Dialog.LicenseActivate`; the license server create, update and delete, performed on `%CSP.UI.Portal.LicenseServers` itself, declare none [AMENDED <date>, Story 18.6 spec gate, Rule 20]."
6. **AD-51, after Story 18.5's case:** "Story 18.6's case: `LicensePort`, which validates the activation's secret key text with `License.Key` `VALIDATE` and sends the `PUT` only when it is valid [AMENDED <date>, Story 18.6 spec gate, Rule 20]." AD-52 gains the same sequencing in one sentence.
7. **AD-53, the unadvertised named case:** "The third is License key's activation (`osmgmt.licensekey.activate`, Story 18.6): its body is the license key's text, key material the model never sees, supplied only by a person's paste or local file; its key ships disabled [AMENDED <date>, Story 18.6 spec gate, Rule 20]."
8. **AD-15 and AD-53**, only if Task 0 finds no vendor event for a license server write, and in every case for the activation: "Activating a license key (Story 18.6) is unmeasured: no instance here may activate one."

**Integration ACs.** `LicensePort` is new, and its consumers are in this story:

- The activate dialog's Validate consumes `LicensePort.Validate` through `POST /license/key/validate`. The effect is the reason on the field for the malformed key on `ocupilot-b-ci` (A2, the browser spec against the real instance).
- The activation consumes the validate-then-`PUT` sequence: A3, in `LicenseKey`, real on the malformed key and through the seam when valid.
- The license server tools reach `AdminPort` directly (A5, `LicenseServerWrite`, with real vendor writes).

**Consumes:** 18.1-18.19's patterns (the Device trio, the `UserPassword` secret action, `ExplorerSave`'s unadvertised flag, the `RemoteDatabaseRules` check route), 14.1's `Snippet`, 14.2's baseline, and 16.17's read-back. **Consumed-by:** Parts B and C reuse the license facts' snapshot, and 18.12 grows the agent's tool set.

**Ledger inbox (Rule 17):** empty. `ledger.sh slice 18-6-licensing-and-ecp` answered nothing (dispatch). DW-1774's side-bar rule is met by the roster tasks.

**Footprint (Rule 11).** Every contended file is edited add-only (Boundaries). These are new or outside the listed set: `src/OcuPilot/Port/LicensePort.cls`, `Area/OsMgmt/LicenseRules.cls`, `LicenseServerSave.cls`, `Api/LicenseError.cls`, `Api/Error.cls` (two dispatch lines), `ui/src/styles/_print.scss` and the global stylesheet's import. Report any outside Epic 18's `paths_hint` under `footprint_extensions`.

## Verification

**Setup (slot B, Part A):**

- Load with `/tmp/epic-18-d6/load-throwaway.sh`, with no restart, and never through the MCP loader. Every write lands on `ocupilot-b-ci`, on `OCUPROBE186*` objects only.
- Run one test class per call, and send the next only once the previous has landed in `%UnitTest_Result`. Never re-submit after a client-side timeout.
- Arm per call with `docker exec -e OCUPILOT_ALLOW_LICENSE_CONFIG=1 -e OCUPILOT_ALLOW_PRINCIPALS=1`.
- Before any browser run, run `cd ui && npm run build`, then `docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`, with `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777` and `OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci` exported.

**Commands:**

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.<C>`, one call at a time. Expected: 0 failures, with totals checked against `%UnitTest_Result`.
  - The story's own classes: `LicenseKey`, `LicenseServerWrite`, `LicenseWriteGate`, `LicenseDescriptor`.
  - The rosters: `Descriptor`, `ReadTool`, `SurfaceCoverage`, `EndpointCoverage`, `Navigation`, `Wire`, `WireSecurityRead`, `WireAreaAnyScreen`, `PortGate`, `ClassicPageGate`, `MappingDescriptor`, `DraftRegistry`, `ToolRoundTrip`, `ToolWrite`, `Prohibited`, `GovernanceBaseline`, `Governance`, `ToolDispatch`, `ToolEmit`, `EntityRef`, `LanguageServerWire`.
- `(loop)` `cd ui && node --test --test-concurrency=1 browser/license-key.browser-spec.mjs browser/license-servers.browser-spec.mjs browser/license-usage.browser-spec.mjs browser/remote-databases.browser-spec.mjs browser/journals.browser-spec.mjs browser/journal-settings.browser-spec.mjs browser/language-servers.browser-spec.mjs`. Expected: pass.
- `(loop)` `cd ui && npm run test:tools && npm run test:components`, then `uv run scripts/check-objectscript.py <changed .cls>` and `bash scripts/lint-docs.sh`. Expected: clean, and `wc -l` on EXPERIENCE.md reads 1005.
- `(once, before dev_complete)`, each expected green with a non-zero count:
  1. the full ObjectScript sweep, `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci`, one class at a time;
  2. `cd ui && npm test && npm run build`;
  3. `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS`;
  4. afterwards, no `OCUPROBE186*` license server or principal remains, the license facts and `iris.key`'s absence read as at S0, and the monitor state reads as at S0.
- `(CI)` The full browser suite runs in CI's three `browser-shard` jobs (Rule 29).

**Planned pinning mutations (Rule 19).** Apply each on the throwaway, observe red, revert byte-identical, and record a `mutation:` line here:

- A1: `AuthorizationKey` is dropped from `context.secretFields`, and `LicenseKey`'s secrecy leg goes red.
- A2: `Validate` returns the vendor's `InvalidReason`, and the no-vendor-text leg goes red.
- A3: `LicensePort` sends the `PUT` without validating, and the malformed-activation leg goes red on its call count. `ADVERTISED` 1, and the absence-from-tools leg goes red.
- A4: the print stylesheet's chrome rule is removed, and the browser print leg goes red.
- A5: the update sends only the changed field, and the complete-set leg goes red. A caller's `KeyDirectory` is admitted, and the never-set leg goes red.
- A6: `%DB_IRISSYS:WRITE` is dropped from `PrivilegePairs` (if Task 0 keeps it), and `LicenseWriteGate` goes red. The port range check is dropped, and the port leg goes red.
- A7: a baseline key is dropped, and `GovernanceBaseline` goes red. `sideBarPosition` is set to 0, and `Navigation` and `navigation.test.mjs` go red.

## Auto Run Result

Status: blocked
Blocking condition: intent gap: Story 18.6 is too large for one implement pass (five surfaces: eight descriptors, twelve write tools, two new ports, three Task 0s, about three times Story 18.16); recommend splitting by surface group into Part A Licensing (keeps 18-6-licensing-and-ecp), Part B ECP data servers (Story 18.20) and Part C ECP settings and application servers (Story 18.21), in the order A, B, C, with each part's ACs, routes, size and dependencies under Tasks & Acceptance; the orchestrator also rules on Design Notes > Decisions 1-6.

- **Planned:**
  - Part A in full: the Task 0 with its halt conditions, server and client execution, rosters, tests, ACs A0-A7, Verification and eight proposed spine amendments. If the split is approved, the runner removes the Part B and Part C sections and sets `ready-for-dev`.
  - Parts B and C as scope, Task 0 outline, ACs and amendments, for their own plan stages.
- **Measured at plan:** read-only, on `ocupilot-b-ci`, with no write to any instance. Seven `GET` and `LIST` calls through `AdminPort`, the license and ECP facts, the vendor and classic sources, and `NormalizePage` spellings.
- **Decisions for the orchestrator** (Design Notes > Decisions), each already applied in this plan:
  - the activation is unadvertised and its key disabled (AD-53);
  - `AuthorizationKey` is never returned;
  - `KeyDirectory` is shown, never set;
  - no new AD-10 arm, only consequence lines;
  - the new screens are appended to OS management at positions 15-19;
  - the Print page's custom resource is covered by the screen's gate.
- **Working tree:** only this spec is new. `cycle-log-epic-18.md` already held the lead's own uncommitted `stage_spawned` line for this dispatch when the stage started, and it was not touched. Nothing was committed.

