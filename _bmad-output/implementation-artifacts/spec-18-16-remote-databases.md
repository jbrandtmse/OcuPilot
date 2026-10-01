---
title: 'Story 18.16: Remote databases'
type: 'feature'
created: '2026-09-30'
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

**Problem:** OcuPilot manages local database configurations (Story 18.3) but not remote ones, whose file sits on an ECP data server (catalog SA-17). The classic Remote Databases page and its dialog are still the only way to list, create, edit or delete one. Choosing a remote directory lists the data server's databases over ECP. That vendor read takes no timeout, and it blocked about 11 s on the throwaway.

**Approach:**

- Add **Remote databases** to OS management at position 12. It is keyed by configuration name like Local databases (`database-configuration`) and reads `Database.ConfigCRUD` `LIST` with `remoteOnly`.
- A form page creates or re-points one. Its fields are Name (create only), Data server (from the instance's ECP data servers) and Directory. The directory is chosen from the data server's own listing (`ECP.DataServer` `DBLIST`, `GET /ecp/data-server/databases`).
- A new `Port/RemoteDatabasePort` runs that listing in a short-lived child job. The request waits for it against a stated bound, the `Kernel/Provider/TestCall.cls` model. The port re-checks the directory at every write, and the listing never runs in a turn.
- Delete reuses `DatabasePort`'s configuration delete, with the typed-name dialog and a removal impact.
- Task 0 observes every payload, effect, duration and pair on `ocupilot-b-ci` before anything is built.
- **The license (read on `ocupilot-b-ci` at this plan).** The IRIS Community license enables no ECP: `$SYSTEM.License.NetworkEnabled()` is 0 and `MaxECPServers()` is 0. So on every instance this project has, CI included, no data server ever answers a listing. A remote database can be listed, opened and deleted there, but a create or re-point always ends at the bounded "cannot be reached" refusal. A test seam answers the successful listing.

## Boundaries & Constraints

**Always:**

- **Task 0 runs first, on `ocupilot-b-ci` only.** It works on probe objects named `OCUPROBE1816*` that it creates and removes, and it halts on any contradiction (Tasks › Task 0).
- **The probe data server is configuration only.** Task 0 and the tests define `OCUPROBE1816SRV` at `127.0.0.1:1972` through test-only `%SYS` seeding (`Config.ECPServers`), as `Test/DatabaseWriteProbe.cls:342-366` already does. Nothing changes `%Service_ECP`, `Config.ECP`, `Config.config` or the license. Each of those is instance-wide, and the license refuses ECP whatever they hold.
- **Screens.** `RemoteDatabaseList` is a list at side-bar position 12, route `os-management/remote-databases`, `classicPage` `%CSP.UI.Portal.RemoteDatabases`, with columns Name, Server, Directory and Status. `RemoteDatabaseForm` is a form page at position 0, `classicPage` `%CSP.UI.Portal.Dialog.RemoteDatabase`. Both:
  - declare `%Admin_Manage:USE` and `%DB_IRISSYS:READ`;
  - use entity type `database-configuration`; there is no new type;
  - carry at least three suggested prompts.
- **Tools** (`osmgmt.remotedatabases.*`), each declaring `RemoteDatabasePort` (AD-52):
  - `create` (AD-54): it fingerprints the name's absence and sends the body `{Server, Directory}`.
  - `update` (AD-4): it sends the complete `Database.ConfigCRUD` set, read fresh. `Server` and `Directory` are its only settable fields.
  - `delete` (AD-51): subject `Server,Directory`, `DESTRUCTIVE`. It deletes the configuration only, never a file.
- **Pairs.** Each tool declares the screen's two pairs plus `%DB_IRISSYS:WRITE`, which Task 0 confirms. The update adds `%Admin_Operate:USE` whenever its complete set sends `MountRequired` true (`LocalDatabaseUpdateMount.ArgumentPairs`). Each `PrivilegePairs` ends in `Gate.WithClassicPages` over its `CLASSICPAGES`: create and update `%CSP.UI.Portal.Dialog.RemoteDatabase`, delete `%CSP.UI.Portal.Dialog.DatabaseDelete`. A missing pair is refused by name before any port call.
- **The remote directory (proposed AD-21 seventh case).** The caller names a data server the instance defines (`ECP.DataServer` `GET` answers 200) and one directory. The directory is accepted only when it equals, character for character, a `Directory` the data server's listing answers at that write. It is refused when the listing names its row `IRISSYS`. The listing runs when a person chooses a server, at every Save and at every confirm. It never runs at a mint, never in a turn, and is never cached.
- **The owner's database-directory rule, read for a remote directory** (Design Notes). An omitted directory is refused `DATABASE.REMOTEDIRECTORY.NONE` before any vendor call. The data server's manager directory, the directory its own listing names `IRISSYS`, is refused `DATABASE.REMOTEDIRECTORY.MANAGER` before any vendor write.
- **The bound.**
  - `RemoteDatabasePort` runs the listing in a child job on the `TestCall` model: a nonce, `$System.Event`, and an abandoned child's late answer discarded. It waits `LISTSECONDS`, which is 20 s, raised by Task 0's rule to at most 40 s.
  - The form states the bound before the listing starts and shows a running line while it runs. The agent's proposal card states it before the confirm (`Consequence`).
  - Past the bound, or when the listing finds the server not connected, the request answers `DATABASE.SERVER.UNREACHABLE` on Server and sends no write.
- **Local and remote stay apart.** The remote `update` and `delete` refuse a configuration with an empty `Server` (`DATABASE.LOCAL`, 409) before any write. Local databases keeps `DATABASE.REMOTE` and every other 18.3 behavior unchanged.
- **The removal impact (AD-8).** It names the namespaces that use the database (through `Globals`, `Routines`, `TempGlobals` or a mapping) and the web applications running in them, each through its own declared read. It has no shared-file part. The vendor refuses the delete while one remains (409 #429, which Task 0 confirms), answered as `DATABASE.INUSE`.
- **Kernel.** `PROHIBITED.OCUPILOTDATABASE` already refuses deleting OcuPilot's and the instance's own databases, or changing their `Server` or `Directory`, whatever the tool. The reviewed `database-configuration` create and change lists admit `Server` and `Directory` for the remote tools.
- **Governance.** `create` and `update` join the baseline `true`; `delete` joins it `false` (epic preamble).
- **Contended files are edited add-only** (Epic 16): `AdminPort.cls`, `Router.cls`, `Prohibited.cls`, `Baseline.cls`, `strings.ts`, `screen-action-handler.ts`, `screen-outlet.ts`, the rosters, `ci-throwaway.sh` and `ci.test.mjs`. EXPERIENCE.md is edited in place and stays 993 lines. New error codes go in `Api/DatabaseError.cls`, never `Error.cls`. `screens.generated.ts` and `ToolFields.cls` are regenerated.

**Never:**

- No typed remote directory, no `PathPort` or local allow-list for one, and no client copy of the listing rule. The classic dialog's "Enter your own database specification" is not carried.
- No ECP data-server create, edit, delete or status action, and no ECP settings: those are Story 18.6's.
- No listing in a turn, at a mint, or from an escalated frame (AD-9). No write is sent after a failed or timed-out listing, and no write runs in a child job (AD-7).
- No rename (the admin API has none), no `StreamLocation` edit (shown, never set), and no mount fields on the remote form.
- No `%Api.Admin.*` name outside `AdminPort` and its subclasses, and no direct `Config.*` or `SYS.*` write in product code.
- No change to Local databases' tools, screens or tests beyond the rosters.
- No spine edit; the runner writes the amendments.

## I/O & Edge-Case Matrix

The seam listing below answers `[{Name:"OCUPROBE1816X", Directory:"/ocuprobe1816x/"}, {Name:"IRISSYS", Directory:"/durable/iris/mgr/"}]`.

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
| --- | --- | --- | --- |
| List | Probe data server `OCUPROBE1816SRV`; remote configurations `OCUPROBE1816R` and `OCUPROBE1816S` | Remote databases and `osmgmt.remotedatabases.read` answer both rows from one read. Local databases answers neither. | none |
| Choose a server it cannot reach | The form, with Data server `OCUPROBE1816SRV` chosen (the real vendor listing) | Before the listing starts, the form states it can take up to `LISTSECONDS`. A running line shows while it runs. Within the bound plus 5 s the field shows the reason and Directory offers nothing. | `DATABASE.SERVER.UNREACHABLE` |
| Listing past the bound | A seam child that never answers; test bound 1 s | Answered at the bound, nothing sent. The abandoned child's late answer is discarded by the next listing. | `DATABASE.SERVER.UNREACHABLE` |
| Create | Seam listing; Name `OCUPROBE1816C`, Directory `/ocuprobe1816x/` | Lists at the Save or the confirm, then sends `PUT /database?name=OCUPROBE1816C {Server, Directory}`. The row is listed after the change event, and the read-back reads `matches`. | none |
| Owner's rule | Directory empty; or `/durable/iris/mgr/` (the listing's `IRISSYS` row) | Refused on Directory: an empty one before any vendor call, the `IRISSYS` one before any vendor write. Nothing is stored. | `DATABASE.REMOTEDIRECTORY.NONE`, `.MANAGER` |
| Directory not listed | `/elsewhere/` | Refused on Directory; nothing sent | `DATABASE.REMOTEDIRECTORY.ABSENT` |
| Server not defined | `OCUPROBE1816NOSRV` | Refused on Server before any listing | `DATABASE.SERVER.ABSENT` |
| Name taken or bad | A present name in another case; `1AB` | Refused on Name | `DATABASE.NAME.TAKEN`, `DATABASE.NAME.SHAPE` |
| Re-point | `OCUPROBE1816R`, Directory set to a listed one (seam) | The complete set read fresh, one diff row, `PUT`; the read-back reads `matches` | none |
| Agent create | A proposal for `OCUPROBE1816A` | The mint checks the name's absence and the server, and lists nothing. The card states the bound. The confirm lists, then writes. A server it cannot reach at the confirm refuses, and nothing is written. | `DATABASE.SERVER.UNREACHABLE` |
| Local target | The remote `update` or `delete` naming a local configuration | Refused; nothing sent | `DATABASE.LOCAL` |
| Remote target of Local databases | Local `update` naming `OCUPROBE1816R` | The 18.3 refusal, unchanged | `DATABASE.REMOTE` |
| Delete | `OCUPROBE1816R`, unused | Typed-name dialog, then `DELETE /database` only, with no file call. The row leaves the list. | none |
| Delete, in use | Probe namespace `OCUPROBE1816N` maps `OcuProbe1816*` to it | The advisory names the namespace before anything is removed. The confirm is refused, and nothing is deleted. | `DATABASE.INUSE` |
| Protected target | The remote `delete` or `update` naming `IRISSYS` or `OCUPILOT` | Refused on both callers | `PROHIBITED.OCUPILOTDATABASE` |
| Missing pair | Any of the three without `%DB_IRISSYS:WRITE`; an update whose set sends `MountRequired` true without `%Admin_Operate:USE` | 403 naming the pair. Zero port calls, no listing. | `AUTH.NOPRIVILEGE` |
| Integration | The list and its read tool; the form's servers from `ECP.DataServer` `LIST`; the delete's impact through `NamespaceList`, the three mapping lists and `WebAppList` | The same rows (AD-36), and the impact names the dependents | Same gates |

</intent-contract>

## Code Map

**Vendor.** Read-only reads: `iris_doc_get` on `ocupilot-slot-b`, plus `irissys/`. The `%Api.Admin` classes are hidden and absent from the export. Everything below is from source until Task 0 observes it.

- `Database.ConfigCRUD`:
  - `LIST` takes `localOnly` and `remoteOnly`; `remoteOnly` wins. It runs `Config.Databases:ListFilter`, whose columns are `Name, Directory, Server, ClusterMountMode, MountRequired, MountAtStartup, StreamLocation, Status` (`irissys/Config/Databases.cls:338`). What `Status` holds for a remote row is unknown.
  - `GET` answers the template's six keys.
  - `PUT` calls `Modify`, or `Create` (201) for a new name. It never checks `Server`, which `Config.Databases.Server` requires to be configured already (`:109-112`; #425 `CPFDataServerNotDefined` (inference)).
  - `DELETE` maps #427 and #429 to 409.
  - `ResourcesOR` is `%Admin_Manage`, and no type is async. The template is at `Screen/Tool/FieldLists.cls:20-27`.
- `ECP.DataServer`:
  - `LIST` (`/ecp/data-servers`) reads `Config.ECPServers:StatusListSMPFilter`.
  - `GET` (`/ecp/data-server?name=`) answers `{Address, BatchMode, MirrorConnection, SSLConfig, Port}`.
  - `TYPEDBLIST` 11 (`/ecp/data-server/databases?name=`) runs `SYS.Database:RemoteDatabaseListSMP(name)`, whose columns are `Name, Directory` (`irissys/SYS/Database.cls:1144`). It is synchronous, takes no timeout, and answers 404 for a server the instance does not define. What it answers for a server it cannot reach is unknown; `200 []` is likely (inference).
  - Only `SERVERACTION` is async (`Test/AdminInventory.cls:55` records `async="1"`). `ResourcesOR` is `%Admin_Manage`, and its PUT template is at `FieldLists.cls:76-82`.
- Classic pages, every `RESOURCE` `%Admin_Manage`:
  - `%CSP.UI.Portal.RemoteDatabases` lists Name, Directory, Server and Status. Its Delete opens `%CSP.UI.Portal.Dialog.DatabaseDelete` with `Remote=1`, which hides the file option (`irissys/%CSP/UI/Portal/Dialog/DatabaseDelete.cls:383-402`).
  - `%CSP.UI.Portal.Dialog.RemoteDatabase`:
    - Its server combo reads `Config.ECPServers:StatusList` (:78-91).
    - `changeServer` (:157-174) disables the directory list when a server reads Disabled, Invalid or Connection Failed.
    - The list (:98-114) is `remoteDatabaseSelect` over `RemoteDatabaseListSMP`, plus `SYS.ECP.GetServerConnState`, where 5 is Normal (`irissys/%CSP/UI/Component/remoteDatabaseSelect.cls:19-28`).
    - A free-text option (:93-97) is not carried. Save calls `Config.Databases.Create` or `Modify` (:289-314).
  - The data-server pages `%CSP.UI.Portal.ECPDataServers` and `.Dialog.ECPDataServer` are 18.6's.
- License and ECP:
  - `irissys/%SYSTEM/License.cls:316` `MaxECPServers()` and :321 `NetworkEnabled()`. `%CSP.UI.Portal.ECP.cls:224-226` shows "The InterSystems IRIS license does not support ECP."
  - `irissys/Config/ECP.cls:48-58`: `ClientReconnectDuration`, `ClientReconnectInterval`, `ServerTroubleDuration`.

**Ports:**

- `Port/AdminPort.cls`:
  - `TYPESUFFIXES` :123 has no `DBLIST`. `MUTATINGTYPES` :402 already holds `Database.ConfigCRUD/PUT` and `/DELETE`.
  - `CONNECTIONTESTTYPES` :450 is the model for a pair-keyed type that opens a connection and stores nothing. Its admission is at :884-899, and its branch at :1012-1014.
  - `ASYNCTIMEOUT` :735, `Invoke` :918.
- `Port/DatabasePort.cls`:
  - `Call` seam :169-172.
  - `Invoke` :181-235: a `ConfigCRUD/PUT` without `root` goes straight to the vendor (:193), and `DELETE` goes to `Delete` (:194).
  - `Delete` :283-322 deletes only the configuration of a remote entry (:303).
  - `DirectoryOf` :327-346 raises `DATABASE.REMOTE`. `Snippet` :928-973.
- `Kernel/Provider/TestCall.cls` is the child-job model: header :1-24, `Call`, `Spawn`, `Await` (`$System.Event.WaitMsg`), `Child`, the nonce, and the event clear before each spawn. It is read only, never edited.

**Tools** (`Screen/Tool/`):

- `LocalDatabaseCreate.cls` is the create model: `EXCLUDEDFIELDS` :41, `PrivilegePairs` :150-158.
- `LocalDatabaseUpdateMount.cls` is the `ConfigCRUD` merge model: `SENDSBODY` :22-26, `ArgumentPairs` :116-130.
- `LocalDatabaseDelete.cls` is the delete model: parameters :33-72, `PrivilegePairs` :160-167.
- `NamespaceCopyMappings.cls` is the `Consequence` model.
- `Classification.cls` :531-555 holds the local entries (`Server` ordinary, `Directory` `unslashed`). `ToolFields.cls` is regenerated by `cd ui && node tools/field-lists.mjs`.

**Rules, Save and the API:**

- `Area/OsMgmt/DatabaseRules.cls`: `NAMEPATTERN` :51, `NameViolation` :181-188, `Taken` :367, `HandleForm` :396-449.
- `Area/OsMgmt/DatabaseSave.cls`: `HandleCreate` :61, `HandleUpdate` :91, seams `PortClass` :45 and `ProhibitedClass` :52.
- `Api/DatabaseError.cls`: codes :13-163, `ViolationCodes` :166, `ReasonFor` :173-201. `Api/Error.cls:1408-1418` already dispatches the `DATABASE.` prefix, so it is not edited.
- `Api/Router.cls`: the `/database*` routes :127-130, wrappers :653-680.

**Kernel:**

- `Kernel/Proposal/Prohibited.cls`: `TYPEDATABASECONFIG` :367, `OWNDATABASEFIELDS` :395 (`Directory,Server,ResourceName,ReadOnly`), `Database()` :2020-2093, `DatabaseChangeFields` :2140-2143, `DatabaseCreateFields` :2146-2149, `Created` :1208-1253.
- `Kernel/Proposal/Impact.cls`:
  - database kind :29/:39, parts :65-71, branch :190-205;
  - `UsingNamespaces` :393, `RunningIn` :443, `SharedFile` :463-480 (not for a remote database);
  - the kind is keyed by tool name at :230.
- `Kernel/Governance/Baseline.cls:33-38`. `Kernel/EntityRef.cls:59` `database-configuration:foldcase`.

**Screens:** `Screen/Descriptor/LocalDatabaseList.cls` (:29-71) and `LocalDatabaseForm.cls` (:22-50) are the models.

**Client** (`ui/src/app/`):

- `shell/screen-outlet.ts`: list :97, `LocalDatabaseForm` :155 and :197.
- `shell/screen-action-handler.ts`: :63-93, :139, `DESTRUCTIVE_ACTIONS` :309, `IMPACT_ACTIONS` :315-323, `DESTRUCTIVE_CONSEQUENCES` :357.
- `areas/os-management/`: `database-actions.ts` :42-57, and `database-editor.page.ts`/`.store.ts` (the form model).
- `core/impact.ts`; `core/strings.ts` (local keys :3731-3797, running and finished :3943-3945); `app.ts` (injection :323-325, sign-out resets :639-641).

**EXPERIENCE.md** (993 lines): :164 OS management side bar, :377 the Databases and Local databases strings, :479 delete bodies; :173 Dialogs is unchanged.

**Tests to model:**

- `Test/DatabaseWriteProbe.cls`: `SERVERNAME` :30, `AddRemote` :342-366, `RemoveAll` :394-411.
- `Test/DatabaseRefusals.cls` `TestARemoteDatabaseIsRefused` :304-337.
- `Test/DatabaseRecordPort.cls` `Call` :20-39; `Test/DatabaseSaveFixture.cls` :15-18.
- `Test/DatabaseWriteGate.cls` and `NamespaceWriteGate.RunAs` :266.
- The snapshot model is `Snapshot` and `Diff` in `_bmad-output/implementation-artifacts/spec-18-15-task0-interopprobe.patch`. It is a model, never applied.

**CI:** `scripts/ci-throwaway.sh:415-428` is the database arming block; `ui/tools/ci.test.mjs:2096-2177`.

**Rosters.** Re-derive each from its class's red, never by hand:

- ObjectScript:
  - `Test/Descriptor.cls`: `ReadShapes` :67-133, entity count 40 at :1707.
  - `ReadTool.cls:93-112`, `SurfaceCoverage.cls`, `EndpointCoverage.cls:207-210`, `Navigation.cls:480-481`, `Wire.cls:701`.
  - `PortGate.cls:28`, `ClassicPageGate.cls` `Roster()` :306-331, `DraftRegistry.cls:62`, `ToolRoundTrip.cls:50`.
  - `Prohibited.cls` (test) :219, `GovernanceBaseline.cls:11`, `Governance`, `ToolDispatch`, `ToolEmit`, `ToolWrite`.
- Client: `ui/tools/navigation.test.mjs` :125-292, `navigation-wire.test.mjs`, `shell/rail-wire.spec.ts`.
- Browser:
  - `ui/browser/license-usage.browser-spec.mjs:126-142` pins the exact ten.
  - `language-servers.browser-spec.mjs:340-346`.
  - `local-databases.browser-spec.mjs:485-496` pins `slice(0,10)` and is unaffected.

## Tasks & Acceptance

**Task 0: the implement stage's first task.** It runs before any form, tool or descriptor is built, on `ocupilot-b-ci` only. Record the results under Design Notes › Measured at implement, and put every AD sentence in `## Spec Change Log` for the runner.

1. **Plumbing:**
   - Add to `Port/AdminPort.cls`, add-only beside `CONNECTIONTESTTYPES`, a pair-keyed parameter `CONNECTIONREADTYPES = "ECP.DataServer/DBLIST"`. It is a non-mutating type that opens a connection and stores nothing. Add its admission in `Invoke`'s type check, answered as an ordinary read.
   - Write `src/OcuPilot/Test/RemoteDatabaseProbe.cls`, which provides `SeedServer`, `Seed*`, `RemoveAll`, `Snapshot`, `Diff` and a timed `Run(endpoint, type, query, body)` through `AdminPort`.
   - Run `/tmp/epic-18-d4/load-throwaway.sh`.
2. **Read-only checks.** Record:
   - `NetworkEnabled()`, `MaxECPServers()` and `KeyServer()`; the plan read 0, 0 and Single;
   - `%Service_ECP` `Enabled`, `Config.ECP`, and `Config.config` `MaxServers` and `MaxServerConn`;
   - `$SYSTEM.Monitor.State()`;
   - the `messages.log` and `alerts.log` line counts, and the ERROR #7846 count, each compared before and after, never read as an absolute zero.
3. **Seed and snapshot.** `SeedServer` defines `OCUPROBE1816SRV` at `127.0.0.1:1972`. Then take S0, which holds:
   - every `Config.ECPServers` entry with its `StatusList` status;
   - every `Config.Databases` entry with `Server` and `Directory`;
   - `Security.Services` names and `Enabled`;
   - `Config.ECP`, and `Config.config` `MaxServers` and `MaxServerConn`;
   - the monitor state, the log line counts, and the process count;
   - OcuPilot's own objects (its three applications, its roles, `OcuPilotAdmin`, `%DB_OCUPILOT`, the `OCUPILOT` database, and the install namespace's and `%ALL`'s mappings).
4. **Reference runs.** The test process runs each step through `AdminPort`. Record each step's answer and duration, take a snapshot after it, and classify `Diff`:
   - a. `ECP.DataServer` `LIST`, and `GET name=OCUPROBE1816SRV`.
   - b. `Database.ConfigCRUD` `PUT name=OCUPROBE1816R {Server, Directory:"/ocuprobe1816r/"}`, then `GET`, then `LIST remoteOnly=1` (its row and `Status`); `LIST localOnly=1` omits the row.
   - c. `PUT name=OCUPROBE1816D {Server}` with no `Directory`: record the stored directory, then delete the entry.
   - d. `PUT name=OCUPROBE1816U {Server:"OCUPROBE1816NOSRV", Directory}`: record the refusal; nothing is stored.
   - e. `ECP.DataServer` `DBLIST name=OCUPROBE1816SRV`, twice. Record each status and body, each duration, the server's `LIST` status after each, the `messages.log` lines each added (severity and text), and the monitor state.
   - f. A re-point `PUT` of `OCUPROBE1816R` to `/ocuprobe1816r2/`, then a `PUT` of the fresh `GET` body unchanged. Record whether the vendor normalizes `Directory` (case or trailing slash); that fixes the `compare` entry.
   - g. Seed, by test-only `%SYS` seeding: resource `%DB_OCUPROBE1816L`, then database `OCUPROBE1816L` in `<mgr>ocuprobe1816l/`, then namespace `OCUPROBE1816N` over it, with a global mapping `OcuProbe1816*` to `OCUPROBE1816R`. Time `NamespaceList`'s read and the shell's namespaces route. Then send `DELETE name=OCUPROBE1816R`, expecting 409 #429. Remove the mapping and `DELETE` again, expecting 200.
   - h. With auditing on, record the vendor events steps b, f and g's delete wrote.
5. **Pairs.** In a child process logged in as `OcuProbe1816T0User` (the `NamespaceWriteGate.RunAs` idiom), the principal holding only `%Admin_Manage:USE` and `%DB_IRISSYS:READ`:
   - run step a, step b's `GET` and `LIST`, and step e once;
   - then run `PUT` and `DELETE`, with `%DB_IRISSYS:WRITE` added and again without it.
6. **Cleanup proof.** `RemoveAll` removes the remote configurations, the mapping, the namespace, the local probe database with its directory and resource, the principal, and the data server. S2 must equal S0, apart from counters and the declared `messages.log` lines.
7. **HALT** `blocked`, with blocking condition `intent gap: observation contradicts the plan: <what>` and nothing built, if any of these hold:
   - `Database.ConfigCRUD` `LIST`, `GET`, `PUT` or `DELETE`, or `ECP.DataServer` `LIST`, `GET` or `DBLIST`, cannot be reached through `AdminPort`, or answers 202.
   - Any of `LIST`, `GET`, `PUT` or `DELETE` of a remote configuration, or `ECP.DataServer` `LIST` or `GET`, takes more than 2 s, or changes the probe server's status. The plan lets those run in a turn and at a mint.
   - Step e changes anything outside its declared effects. Its declared effects are the probe server's status, and `messages.log` lines below severity 2 about ECP. Outside them, for example:
     - the monitor state rises;
     - an `alerts.log` line appears;
     - any `Config.*` or `Security.*` object other than a probe changes, `%Service_ECP` among them;
     - OcuPilot's objects change;
     - a process outlives the call.
   - Step e answers rows. ECP would then work under this license, and the unreachable legs would be invalid.
   - The vendor deletes a remote configuration that a probe namespace's mapping uses.
   - A step needs a pair outside `%DB_IRISSYS:WRITE` beyond the list's two, such as `%Admin_Operate`, `%Admin_Secure` or `%All`.
   - S2 differs from S0 after `RemoveAll`.
8. **Otherwise:**
   - Set the tools' pairs to the measured set.
   - Set `LISTSECONDS` to 20, or to the ceiling of 1.5 times step e's longer duration when that exceeds 20, at most 40.
   - Fix the port's unreachable decision from step e's answer and status: rows mean connected; anything else, with a status other than the Normal word measured, means unreachable.
   - Set `Directory`'s `compare` from step f.
   - Write the AD-8 sentence into the Spec Change Log, and the AD-15/AD-53 named case if step h found no vendor event.

**Execution: the port and the tools (AC2-AC7):**

- `src/OcuPilot/Port/RemoteDatabasePort.cls` (new, extends `DatabasePort`):
  - **The bounded listing.** `LISTSECONDS`; `Directories(pServer, Output pRows, Output pTruncated, Output pFault)` spawns `ListChild` on the `TestCall` model. The child calls `..Invoke("ECP.DataServer","DBLIST", name=server, maxRows=cap+1)` as the user and signals the rows back as JSON. Past the bound, or when the measured unreachable shape holds, the answer is `DATABASE.SERVER.UNREACHABLE`. The caller contract: no escalated frame on the stack.
  - **`Invoke` for `Database.ConfigCRUD/PUT`**, in this order:
    1. `Server` must be defined (`ECP.DataServer` `GET`), else `SERVER.ABSENT`.
    2. `Directory` must be non-empty, else `REMOTEDIRECTORY.NONE`.
    3. For an update, a fresh read with an empty `Server` refuses `LOCAL`.
    4. The listing runs.
    5. The directory must be in it, else `REMOTEDIRECTORY.ABSENT`, and must not be the row named `IRISSYS`, else `REMOTEDIRECTORY.MANAGER`.
    6. Then the vendor `PUT`: `{Server, Directory}` for a create, the tool's complete set for an update.
  - **`DELETE`** refuses `LOCAL` for an empty `Server`, then calls `##super`.
  - Each refusal is a field-level fault `{field, code}`.
  - **`Snippet`** mirrors every branch (AD-59): the listing's `GET` and the `PUT`, and `##super` for the delete.
- `src/OcuPilot/Port/AdminPort.cls`: Task 0's plumbing stays.
- `src/OcuPilot/Screen/Tool/RemoteDatabaseCreate.cls`, `RemoteDatabaseUpdate.cls`, `RemoteDatabaseDelete.cls` (new; descriptor `RemoteDatabaseList`), per Boundaries:
  - `ArgumentProblem` runs `RemoteDatabaseRules.Problem` (name shape and taken, server defined, directory non-empty) and never lists.
  - `Consequence` on create and update states the bound.
  - The update's `PERMITTEDFIELDS` are `Server,Directory`, with the `UpdateMount` `ArgumentPairs`.
  - The delete: `SENDSBODY` 0, `READANSWERS` `Directory,Server,MountAtStartup,MountRequired`, `PRECONDITIONFIELD` `Server`, `REMOVALROWS` `Server,Directory`, and no screen value.
- `src/OcuPilot/Screen/Tool/Classification.cls`: add entries for the three tools (`Server` and `Directory` ordinary, `Directory`'s `compare` from Task 0). Then regenerate `ToolFields.cls`.
- `src/OcuPilot/Kernel/Proposal/Prohibited.cls` (add-only): admit `Server` and `Directory` in the `database-configuration` create and change field lists, as `Created` and `ReviewedFewOnly` read them. The local tools' derived lists exclude both, so they stay unable to send them.
- `src/OcuPilot/Kernel/Proposal/Impact.cls`: add kind `remote-database-delete`, keyed to `osmgmt.remotedatabases.delete`, with the namespaces and applications parts only.
- `src/OcuPilot/Kernel/Governance/Baseline.cls` (add-only): `osmgmt.remotedatabases.create` true, `.delete` false, `.update` true.

**Execution: rules, Save and routes:**

- `src/OcuPilot/Area/OsMgmt/RemoteDatabaseRules.cls` (new):
  - `Problem`, reusing `DatabaseRules`' name rules.
  - `HandleForm` (`GET /remote-database/form?name=`) answers the configuration as read, the data servers from `ECP.DataServer` `LIST` (name and status), and `listSeconds`.
  - `HandleDirectories` (`GET /remote-database/directories?server=`) runs the bounded listing under the screen's pairs.
- `src/OcuPilot/Area/OsMgmt/RemoteDatabaseSave.cls` (new, on the `DatabaseSave` model): `POST /remote-database` and `PUT /remote-database/:id` through the tools (AD-55). Port faults become violations on their fields.
- `src/OcuPilot/Api/Router.cls` (add-only): the four routes and their thin wrappers, `/form` and `/directories` before `/:id`.
- `src/OcuPilot/Api/DatabaseError.cls`: the codes, their sentences and `ViolationCodes`:
  - `DATABASE.LOCAL` (409): "This database's file is on this instance. Change it on Local databases."
  - `DATABASE.SERVER.ABSENT`: "Choose a data server this instance defines."
  - `DATABASE.SERVER.UNREACHABLE`: "The data server could not be reached in time. Check that it is running and that this instance's license includes ECP."
  - `DATABASE.REMOTEDIRECTORY.NONE`: "Choose the database's directory on the data server."
  - `DATABASE.REMOTEDIRECTORY.ABSENT`: "The data server does not list that directory. Choose one it lists."
  - `DATABASE.REMOTEDIRECTORY.MANAGER`: "That directory is the data server's IRISSYS directory. Choose another."
  - Each 422 code is on its field.

**Execution: screens and client (AC1, AC5, AC8):**

- `src/OcuPilot/Screen/Descriptor/RemoteDatabaseList.cls` and `RemoteDatabaseForm.cls` (new), per Boundaries:
  - The list declares primary `create` and row action `delete`, and its name cell opens the form.
  - Its read is `{"port":"admin","endpoint":"Database.ConfigCRUD","type":"LIST","query":{"remoteOnly":"1"}}`, with fields `Name, Server, Directory, Status`.
- `ui/src/app/areas/os-management/remote-database-form.page.ts` and `.store.ts` (new), with their specs:
  - Name is shown on create only. Data server is a select. Directory is a select fed only by the listing. StreamLocation is shown on edit.
  - The Data server hint states the bound before any choice. While a listing runs, the select is `aria-disabled` with its reason, and the running line shows.
  - The reason renders on its field, and the unsaved-changes guard applies.
- `ui/src/app/areas/os-management/remote-database-actions.ts` (Create navigates to the form).
- `ui/src/app/shell/screen-outlet.ts`, `ui/src/app/shell/screen-action-handler.ts` (the delete is destructive with its impact and no file flag), `ui/src/app/core/impact.ts` (the new kind), `ui/src/app/core/strings.ts` (new keys) and `ui/src/app/app.ts` (store injection and sign-out reset). Regenerate `core/screens.generated.ts`.
- EXPERIENCE.md, in place, keeping 993 lines:
  - :164 gains "Remote databases (Stage 2, Story 18.16)".
  - :377 gains every new label, the hint "Choosing a data server lists its databases over ECP, which can take up to <n> seconds.", the running line "Listing the databases on <server> since <time>", "<server> lists no databases.", the empty state "No remote databases on this instance.", the card consequence "Confirming lists the databases on <server> to check the directory, which can take up to <n> seconds." and the three prompts.
  - :479 gains "Deleting this remote database removes it from this instance's configuration. Its file on the data server stays. This cannot be undone."
  - Then run `cd ui && npm run test:tools`.

**Execution: rosters and CI.** Extend every roster in Code Map › Rosters. The browser lists `license-usage.browser-spec.mjs:126-142` and `language-servers.browser-spec.mjs:340-346` are DW-1774's. Add the new classes to `scripts/ci-throwaway.sh`'s `OCUPILOT_ALLOW_DATABASE_CONFIG` `# classes:` line, plus `OCUPILOT_ALLOW_PRINCIPALS` for the gate class, and keep `ui/tools/ci.test.mjs` equal.

**Tests:**

- `src/OcuPilot/Test/RemoteDatabaseProbe.cls`: Task 0's helper, plus the seeding of `OCUPROBE1816SRV`, the remote configurations, the namespace with its mapping, and the local probe database. `RemoveAll` runs before all tests, after each and after all.
- `src/OcuPilot/Test/RemoteDatabaseListingPort.cls`: the seam. It answers the matrix's listing, or leaves the child unanswered against a 1 s test bound, and counts listings.
- `src/OcuPilot/Test/RemoteDatabaseListing.cls`:
  - The real unreachable listing answers `UNREACHABLE` within `LISTSECONDS` plus 2 s.
  - The seam child is cut at the bound, and its late answer is discarded.
  - A mint lists zero times.
- `src/OcuPilot/Test/RemoteDatabaseWrite.cls`: the matrix's create, re-point, delete, in-use, local-target, owner's-rule, absent, protected and read-back legs, each on both callers, with the vendor writes real and only the listing seamed.
- `src/OcuPilot/Test/RemoteDatabaseWriteGate.cls`, with `RemoteDatabaseWriteGateProbe.cls`: the pairs, refused by name with zero port calls.
- `src/OcuPilot/Test/RemoteDatabaseDescriptor.cls`: the list and its read tool answer one read; `remoteOnly` is set; Local databases omits the rows.
- `ui/browser/remote-databases.browser-spec.mjs`, seeding and cleaning up over `docker exec`:
  - the side bar's twelfth entry;
  - the list;
  - the form's hint before choosing, then the running line, then the reason on Data server within the bound plus 5 s, and the Save refused;
  - the delete through the typed-name dialog with its advisory;
  - the DW-1337 structural gate in both themes.

**Acceptance Criteria:**

- **AC0:** Given SA-17's routes on `ocupilot-b-ci`, when the implement stage starts, then Task 0's payloads, durations, effects and pairs are recorded under Design Notes before any form, tool or descriptor exists, and S2 equals S0. A contradiction halts the story.
- **AC1:** Given probe remote configurations, when Remote databases opens and `osmgmt.remotedatabases.read` runs, then both answer the same rows (Name, Server, Directory, Status), and Local databases answers none of them.
- **AC2:** Given a data server whose listing answers, when a person saves the form and when the agent's proposal is confirmed, then each sends `PUT /database {Server, Directory}` after re-listing. The row appears after the change event, and the read-back reads `matches`.
- **AC3:** Given a remote database, when its directory or server is re-pointed to one the listing answers, then the complete set read fresh is sent with one diff row.
- **AC4:** Given a remote database, when it is deleted through the typed-name dialog or a confirmed proposal, then only `DELETE /database` is sent. If a namespace uses it, the advisory names that namespace first, and the delete is refused `DATABASE.INUSE`.
- **AC5:** Given a data server that cannot be reached:
  - When a person chooses it, then the form has stated the bound before the listing starts and shows the running line while it runs. The reason appears on Data server within the bound plus 5 s, and nothing is written.
  - When the agent proposes against it, then the card states the bound before the confirm, the mint lists nothing, and the confirm answers `DATABASE.SERVER.UNREACHABLE` within the bound plus 5 s.
- **AC6:** Given an omitted directory, an unlisted one, or the one the listing names `IRISSYS`, when either caller saves or confirms, then each is refused on Directory: `NONE` before any vendor call, the other two before any vendor write.
- **AC7:** Given a local configuration named to a remote tool, a protected name, or a caller lacking a declared pair, when the tool runs, then it is refused `DATABASE.LOCAL`, `PROHIBITED.OCUPILOTDATABASE` or `AUTH.NOPRIVILEGE` respectively, and nothing is sent.
- **AC8:** Given the side bar, governance and rosters, when the story lands, then:
  - Remote databases is OS management's twelfth entry, with three prompts;
  - the three keys are in the baseline (the delete disabled);
  - every roster and pinned side-bar list includes the new screens and tools;
  - the DW-1337 gate holds in both themes.

## Spec Change Log

- 2026-10-01, spec gate (runner): Story 18.17 (merged into this branch at `c8dedb69`) listed the Integrity log at OS management position 5 and moved Devices through Local databases to 6-11, so Remote databases takes position 12 and is the twelfth entry (Intent, Boundaries, Tests, AC8 amended). Every Code Map line citation for a side-bar pin (`Navigation.cls`, `navigation.test.mjs`, `navigation-wire.test.mjs`, `rail-wire.spec.ts`, `license-usage`, `local-databases`, `namespaces` and `language-servers` browser specs) predates 18.17: re-derive each from the current tree at implement. Spine amendments 1, 2, 4 and 5 under Design Notes were written at the gate (AD-21 seventh case, AD-42, AD-44, AD-52); amendment 3 (AD-8) and, if needed, 6 (AD-15/AD-53) are written by the runner after Task 0 records them here. The orchestrator agreed (2026-10-01) that on Community the bounded unreachable refusal is the measured path and the listing's success leg is pinned at the port through the seam.

## Review Triage Log

## Design Notes

**Governing ADs:**

- AD-2, AD-27, AD-52: every vendor call goes through `AdminPort` or `RemoteDatabasePort`, which extends `DatabasePort`. No AD-27 vendor-class case is needed.
- AD-3, AD-4: derived fields, and the update's complete set.
- AD-5, AD-36, AD-44: one descriptor per screen, one shared read, the classic pages and `CLASSICPAGES`.
- AD-6, AD-34, AD-40: proposal and confirm. The listing runs inside the per-target lock.
- AD-7, AD-9, AD-42: no listing in a turn; the spawn follows `TestCall` and never comes from an escalated frame.
- AD-8, AD-29: pairs, and the removal impact.
- AD-10: the existing own-database arm.
- AD-13, AD-14: `database-configuration`, `foldcase`, and its events.
- AD-15, AD-53: the marker, and the vendor's own event (Task 0 checks it). AD-16: `%SYS` by explicit save and restore.
- AD-21: the seventh case and the owner's rule.
- AD-22: the baseline. AD-39: violations on their fields.
- AD-51: the delete's subject. AD-54: the create's absence. AD-55: two callers.
- AD-58: the read-back. AD-59: `Snippet`.
- AD-26 is not engaged: `DBLIST` and `ConfigCRUD` are synchronous, and `SERVERACTION` is 18.6's.

**Measured at plan.** Read-only, on `ocupilot-b-ci` (2026-10-01 UTC) with a `docker exec` session that only wrote to stdout:

- IRIS for Health 2026.2 build 221U, license "InterSystems IRIS Community".
- `MaxECPServers()` is 0, `NetworkEnabled()` is 0, and `KeyServer()` is Single.
- `%Service_ECP` `Enabled` is 0.
- `Config.ECP` holds 1200, 5 and 60. `MaxServers` is 2 and `MaxServerConn` is 1.
- No data server and no remote database exist. The monitor state is 0, and the manager directory is `/durable/iris/mgr/`.
- On `ocupilot-slot-b` the reads matched: the license reads Community, `%Service_ECP` is disabled, and ECP is not configured.
- Story 18.3 measured (`spec-18-3-…:708`) that a remote configuration is created without a live link, that `DBLIST` blocked about 11 s and opened a connection attempt, and that a data server a remote database uses cannot be deleted (409 #423).

**Decisions:**

- **The directory comes from the listing.** AD-21 forbids a caller path, and the epic context forbids free-text paths. A directory is an enum value the instance answers, as the sixth case's root is.
- **The listing is screen-only and runs at the confirm.**
  - A turn that opened an ECP connection would be a fourth AD-7 shape; on a licensed instance it would leave a live connection behind (inference). So the mint checks only the name and the server.
  - The card states the wait, and the confirm does the listing. A confirm whose listing fails burns its proposal, because Confirm's port call follows the commit.
- **The bound is OcuPilot's own.** The vendor call takes no timeout, and `ClientReconnectDuration` (1200 s) may govern a dropped connection, past the gateway's 60 s (inference). A child job is the one bound OcuPilot can enforce, and AD-42's Test connection already uses it.
- **There is no license pre-check.** The classic dialog tries and then reports. The unreachable sentence names the license, so Community users learn why.
- **One entity type.** A local and a remote configuration share `Config.Databases`' name space and the AD-34 lock key. Separate tools follow the descriptor (AD-5). The delete inherits `DatabasePort.Delete`, which already skips the file for a remote entry.
- **Not in this story:** data-server management, ECP settings and status (18.6), mount fields, rename, and `StreamLocation`.

**The owner's database-directory rule, read for a remote directory.**

- A remote directory lives on the data server.
- "Always required, never left for the vendor to default": a create and a re-point each require a directory, refused `REMOTEDIRECTORY.NONE` before any vendor call. Task 0 records what the vendor would store without one.
- "Nothing is ever written into IRISSYS's directory, the manager directory": this means the data server's manager directory, which only the data server knows. The directory its own listing names `IRISSYS` is refused `REMOTEDIRECTORY.MANAGER`. The refusal follows the listing, which is a read, and precedes any vendor write. That is the only sense in which "before any vendor call" can hold for a directory the instance cannot see.
- A data server that is this instance would list its own `IRISSYS`, so the instance's own manager directory is covered the same way.

**Named limits:**

1. **On IRIS Community no listing succeeds.** That covers every instance here, CI included. Create and re-point are refused at the bound, while list, open and delete work. The success path is pinned only through `RemoteDatabaseListingPort`, against the vendor query's declared columns `Name, Directory`; it was never observed (inference).
2. **A slow data server keeps a child job alive** until the vendor returns, one child per listing. The form allows one listing at a time.

**Proposed spine amendments (Rule 20; the runner writes them at the spec gate).** Task 0 confirms 3: if the list's two pairs alone pass `PUT` and `DELETE`, 3 drops `%DB_IRISSYS:WRITE` and its reason, and the tools declare none. Task 0 adds 6 through the Spec Change Log.

1. **AD-21, after Story 16.4's consumers:** "**The seventh is a remote database's directory, a location on an ECP data server** [AMENDED <date>, Story 18.16 spec gate, Rule 20]. The caller names a data server the instance defines (`ECP.DataServer` `GET`) and one directory, never a path of its own: the directory is accepted only when it equals, character for character, a `Directory` the data server's own listing answers (`ECP.DataServer` `DBLIST`, `GET /ecp/data-server/databases`, through `AdminPort`), read at the screen's choice and again at every Save and confirm, never at a mint, never in a turn and never cached. Under the owner's database-directory rule an omitted directory is refused before any vendor call, and the directory the listing names `IRISSYS`, the data server's manager directory, before any vendor write. The listing opens an ECP connection and the vendor call takes no timeout (it blocked about 11 s on `ocupilot-b-ci`), so `Port/RemoteDatabasePort` runs it in a short-lived child job the request waits for against `LISTSECONDS`, stated on the screen before the listing starts and on the proposal card before the confirm; past it, or when the data server is not connected, the request answers `DATABASE.SERVER.UNREACHABLE` and sends no write, and the abandoned child's late answer is discarded as AD-42's is. The listing changes no stored configuration (measured at Story 18.16's Task 0). On an instance whose license enables no ECP, IRIS Community among them (`$SYSTEM.License.NetworkEnabled()` 0, read on `ocupilot-b-ci`), no listing succeeds, so a remote database is listed, opened and deleted there but never created or re-pointed."
2. **AD-42, the Test connection paragraph:** replace "(`Kernel.Provider.TestCall`, the only process spawn site beside the turn job of AD-7)" with "(`Kernel.Provider.TestCall`, one of three process spawn sites, with the turn job of AD-7 and AD-21's remote-directory listing in `Port/RemoteDatabasePort`, which follows this model)" [AMENDED <date>, Story 18.16 spec gate, Rule 20].
3. **AD-8, after Story 18.15's paragraph:** "**Story 18.16's remote database tools declare pairs beyond their screen's set** [AMENDED <date>, Story 18.16 spec gate, Rule 20]: `osmgmt.remotedatabases.create`, `.update` and `.delete` declare `%DB_IRISSYS:WRITE`, because a principal holding only the Remote databases screens' `%Admin_Manage:USE` and `%DB_IRISSYS:READ` was refused `PUT` and `DELETE /database` (measured at Story 18.16's Task 0), and the update `%Admin_Operate:USE` whenever its complete set sends `MountRequired` true, each refused by name before any port call. A remote database's delete names the namespaces and applications a local database's does, and no shared file."
4. **AD-44, after Story 18.15's `CLASSICPAGES`:** "**Story 18.16's `CLASSICPAGES`** [AMENDED <date>, Story 18.16 spec gate, Rule 20]: the remote database create and update declare `%CSP.UI.Portal.Dialog.RemoteDatabase`, and the delete `%CSP.UI.Portal.Dialog.DatabaseDelete`, which the classic Remote Databases page opens with `Remote=1`."
5. **AD-52, after the 18.3 sequencing paragraph:** "`RemoteDatabasePort` (Story 18.16) sequences a remote database's create and update: `ECP.DataServer` `GET`, the bounded listing (AD-21's seventh case), then `Database.ConfigCRUD` `PUT`; its delete is `DatabasePort`'s configuration delete, which sends no file delete for a remote configuration [AMENDED <date>, Story 18.16 spec gate, Rule 20]."
6. **AD-15 and AD-53**, only if Task 0 step h finds no vendor event: a named case for a remote configuration's write.

**Integration ACs.** `RemoteDatabasePort` is new, and its consumers are in this story:

- The form consumes the bounded listing through `GET /remote-database/directories`. Its effect is the stated bound, the running line, and the reason on Data server: AC5, in the browser spec against the real vendor listing.
- The Save and the confirm consume the listing and the `PUT`: AC2 and AC6 in `RemoteDatabaseWrite`, with the vendor writes real.
- The delete's impact consumes `NamespaceList`'s, the mapping lists' and `WebAppList`'s declared reads: AC4.

**Consumes:**

- 18.3: `DatabasePort.Delete`, `DatabaseRules`' name rules, `LocalDatabaseUpdateMount`'s `ArgumentPairs`, the impact parts, and `DatabaseWriteProbe`'s remote seeding.
- 18.14: `CLASSICPAGES` and `WithClassicPages`.
- 10.5: the `TestCall` child-job model.
- Earlier stories: 16.17's read-back, 16.19's impact, 14.1's `Snippet`, and 14.2's baseline.

**Consumed-by:**

- 18.6: data servers. Its delete's 409 #423 can name the remote databases through this list's read (AD-5), and it may reuse `RemoteDatabasePort.Directories`.
- 18.12: the agent's grown tool set.
- 18.13: the own-database predicate under a multi-namespace install.

**Ledger inbox (Rule 17):** none. DW-1774's side-bar rule is met by the roster tasks.

**Contended files and footprint.** Epic 16 has uncommitted edits to `AdminPort.cls`, `Router.cls`, `Prohibited.cls` and `Baseline.cls`, and its branch changes `strings.ts`, `screen-action-handler.ts` and `screen-outlet.ts`. Each is edited add-only here. There is no footprint extension: every other file is new or in Epic 18's paths.

## Verification

**Setup (slot B):**

- Load with `/tmp/epic-18-d4/load-throwaway.sh` (no restart), and never through the MCP loader.
- Every write lands on `ocupilot-b-ci`, on `OCUPROBE1816*` objects only.
- Run one test class per call. Send the next only once the previous has landed in `%UnitTest_Result`, and never re-submit after a client-side timeout.
- Arm the new classes per call with `docker exec -e OCUPILOT_ALLOW_DATABASE_CONFIG=1`. Add `-e OCUPILOT_ALLOW_PRINCIPALS=1` for `RemoteDatabaseWriteGate`.
- Before any browser run: `cd ui && npm run build`, then `docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`, with `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777` and `OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci` exported.

**Commands:**

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.<C>`, one call at a time. Expected: 0 failures each, with totals checked against `%UnitTest_Result`.
  - The story's own classes: `RemoteDatabaseListing`, `RemoteDatabaseWrite`, `RemoteDatabaseWriteGate`, `RemoteDatabaseDescriptor`, `DatabaseRefusals`, `ClassicPageGate`.
  - The rosters: `Descriptor`, `ReadTool`, `SurfaceCoverage`, `EndpointCoverage`, `Navigation`, `Wire`, `PortGate`, `DraftRegistry`, `ToolRoundTrip`, `ToolWrite`, `Prohibited`, `GovernanceBaseline`, `Governance`, `ToolDispatch`, `ToolEmit`, `ImpactRoute`, `AdminInventory`.
- `(loop)` `cd ui && node --test --test-concurrency=1 browser/remote-databases.browser-spec.mjs browser/local-databases.browser-spec.mjs browser/license-usage.browser-spec.mjs browser/language-servers.browser-spec.mjs`. Expected: pass.
- `(loop)` `cd ui && npm run test:tools && npm run test:components`, then `uv run scripts/check-objectscript.py <changed .cls>` and `bash scripts/lint-docs.sh`. Expected: clean, and `wc -l` on EXPERIENCE.md reads 993.
- `(once, before dev_complete)`, expected green with a non-zero count:
  1. the full ObjectScript sweep, `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci`, one class at a time;
  2. `cd ui && npm test && npm run build`;
  3. `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS`;
  4. afterwards, no `OCUPROBE1816*` configuration, namespace, directory, resource, principal or data server remains, `%Service_ECP` still reads 0, and the monitor state reads as at S0.
- `(CI)` The full browser suite runs in CI's three `browser-shard` jobs (Rule 29).

**Planned pinning mutations (Rule 19).** Apply each on the throwaway, observe red, revert byte-identical, and record a `mutation:` line:

- AC1: the list's read drops `remoteOnly`, and `RemoteDatabaseDescriptor` goes red.
- AC2: the port skips the membership check, and `RemoteDatabaseWrite`'s unlisted-directory leg goes red.
- AC3: the update sends only the changed fields, and its complete-set leg goes red.
- AC4: the remote delete drops its `LOCAL` refusal, and the local-target leg goes red.
- AC5:
  - the port lists in process instead of in the child, and `RemoteDatabaseListing`'s bound leg goes red;
  - the mint calls the listing, and its zero-listings leg goes red;
  - the form drops the hint, and the page spec goes red.
- AC6: dropping the `IRISSYS` check turns the manager leg red; dropping the empty check turns the none leg red.
- AC7: dropping `%DB_IRISSYS:WRITE` from `PrivilegePairs` turns `RemoteDatabaseWriteGate` red.
- AC8: dropping a baseline key turns `GovernanceBaseline` red.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none

- Planned only; nothing was implemented. The plan stage wrote no IRIS instance: one read-only `docker exec` session on `ocupilot-b-ci` wrote only to stdout, and the slot B dev reads went through MCP.
- **For the spec gate.** The throwaway's IRIS Community license enables no ECP (`NetworkEnabled()` 0, `MaxECPServers()` 0). So no data server can ever answer a directory listing on any instance here, CI included.
  - Under AD-21 (no typed path), create and re-point therefore end at the bounded `DATABASE.SERVER.UNREACHABLE` on Community. List, open and delete work.
  - The successful listing is pinned only through a test seam (Design Notes › Named limits).
  - Proposed amendments 1-2 (AD-21's seventh case, AD-42's spawn sites) carry that decision.
