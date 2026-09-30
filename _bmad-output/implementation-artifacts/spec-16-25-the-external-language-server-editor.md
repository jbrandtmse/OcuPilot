---
title: 'Story 16.25: The external language server editor'
type: 'feature'
created: '2026-09-29'
status: 'in-progress'
baseline_revision: '871b6fa084729193e1bf69cd05ee592911272c98'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-16-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-16-10-external-language-servers.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** OcuPilot lists external language servers and starts and stops them (Story 16.10), but a server's definition can still only be created, changed or deleted in the classic portal (FR-78). The admin API's `LanguageServer` template builds its `Custom` object per server type, and OcuPilot derives it at no type, so no per-type field can reach a tool (DW-253).

**Approach:** Derive one field list per server type (DW-253). Add a form-page editor paired with the list, reached from the name cell and from a Create primary action. Add create, update and delete write tools serving both callers, with delete a typed-name row action. The editor links the server's Activity log. A running server is refused edit and delete, as the classic editor refuses them.

## Boundaries & Constraints

**Always:**

- **Admin API only (AD-2, AD-27).** Create and edit are `LanguageServer` `PUT` (an upsert; 201 on create), delete is `DELETE`, both synchronous (AD-26).
  - Every call goes through a new `Port/LanguageServerPort.cls`, which extends `AdminPort` as `TaskPort` does and names no `%Api.Admin` class.
  - A successful `GET` is completed with the same name's `ACTIVITY` (vendor `maxRows` 1), setting `CurrentlyRunning` on the answer. A failed `ACTIVITY` fails the read.
  - Every other type is `AdminPort`'s own call.
- **DW-253 (AD-3).**
  - `FieldDerive` also derives one list per `Config.Gateways` type, keyed `LanguageServer:<Type>`, from `PutRequestBodySchema(<Type>)`. The nine types are Remote, Java, XSLT, JDBC, ODBC, ML, .NET, Python and R.
  - `AdminPort.Template` gains an optional argument that overrides `TEMPLATEARGUMENTS`, and `field-lists.mjs` keys a typed template list `endpoint:type`.
  - The untyped `LanguageServer` list stays and supplies the top-level fields.
  - `Custom`'s members come from the target type's list, read at runtime by `Area/OsMgmt/LanguageServerRules.cls`, as `OAuthClientRules.Members` reads its list.
- **Settable fields (the semantic half, authored once in `LanguageServerRules`, shared by both callers):**
  - `Name`: create only, 1-50 characters, none a control character. Names are case-sensitive, so there is no `IDRULES` pair.
  - `Type`: create only, one of the nine; read-only on edit.
  - `Port`: an integer 1-65535, required on create.
  - `ConnectionTimeout` and `InitializationTimeout`: integers 2-300.
  - `UseSharedMemory` and `VerifySSLHostName`: booleans.
  - `BindToIPAddress`: text, which the vendor does not validate.
  - `Resource`, `SSLConfigurationServer` and `SSLConfigurationClient`: text of at most 64 characters, not checked against the instance, as the vendor does not check them.
  - `Custom`, one object argument, settable members only:
    - Java, XSLT, JDBC, ML and R: `JVMArgs`;
    - .NET: `DotNetVersion` (one of `N8.0`, `N9.0`, `N10.0`, `Config.Gateways` `VALIDNETVERSIONS`) and `Exec32` (boolean);
    - Python: `PythonOptions`;
    - Remote: `Address`;
    - ODBC: none.
  - A create that omits `Resource` sends the classic editor's default for its type: `%Gateway_SQL` for JDBC and ODBC, `%Gateway_ML` for ML, `%Gateway_Object` otherwise. The card shows it as a row.
- **Paths are shown, never set (AD-21).** `LogFile`, `ClassPath`, `JavaHome`, `FilePath` and `PythonPath` are not settable by either caller. The form shows them read-only with the classic-portal caption. An edit sends them back as the instance holds them (the SSL/TLS precedent). No tool consumes `PathPort`.
- **Update (AD-4, with its named exception).** `LanguageServerUpdate.MergeUpdate`, which the mint, the confirm's re-merge and the screen Save all call:
  - merges top-level arguments over the fresh read, and `Custom` member by member (`TaskUpdate.MergeSettings`' shape);
  - removes `Custom` from the body when no member changes;
  - never sends `CurrentlyRunning`;
  - refuses while the server runs.
- **A running server (classic parity).** While `CurrentlyRunning` is true and `Type` is not `Remote`:
  - the update and the delete refuse with the published sentence "This server is running. Stop it before changing or deleting it.", before any write;
  - the editor opens read-only, stating that sentence;
  - the update refuses in `MergeUpdate`, and so again at confirm; the delete refuses in `StateDiff`;
  - the delete's fingerprint subject is `CurrentlyRunning,Type`.
- **Python.**
  - While the value of a `Custom` member differs from the loaded one on a Python server, the form shows the consequence line: "Saving this also turns the server's virtual environment back on and clears its PYTHONPATH, which only the classic portal shows." The update tool's description says the same.
  - The port refuses a Python server's `DELETE` for a caller without `%System_CallOut:USE`, naming the pair, before the vendor call.
- **Pairs (AD-8, AD-29, AD-44).**
  - The form declares the list's pairs, with the same `ownPrivileges`.
  - All three tools add `%Admin_Manage:USE` and `%DB_IRISSYS:WRITE`, refused by name before any port call.
  - Create and update declare `CLASSICPAGES` `%CSP.UI.Portal.ExternalLanguageServer`. The delete, performed on the list's own classic page, declares none.
- **Tools (AD-51, AD-53, AD-54, AD-55).** `osmgmt.languageservers.create`, `.update` and `.delete`, each declaring `PORTCLASS` `LanguageServerPort`.
  - The create fingerprints the name's absence.
  - The delete is action-style, `DESTRUCTIVE`, with `SCREENACTIONS` `delete`.
  - The three keys join `Baseline.cls`, enabled.
  - The screen caller mints nothing. The read-back, the copy-out and the change event are the generic ones (AD-58, AD-59, AD-14: `created`, `updated`, `deleted`).
- **Entity type `language-server`.** Its `Prohibited` create and change field lists gain the settable fields, with no refusal arm (AD-10: OcuPilot runs no language server).
- **Placement and copy.**
  - The form's route is `os-management/language-servers/edit`, at side-bar position 0, classic page `%CSP.UI.Portal.ExternalLanguageServer`, with three suggested prompts.
  - The list gains primary action `create` and row action `delete`, appended after `start` and `stop`.
  - The name cell opens the editor, and the editor links `os-management/language-servers/activity/<name>`.
  - Copy is taken verbatim from Design Notes. EXPERIENCE.md is edited in place and stays at 993 lines.

**Never:**

- No settable path, and no edit of `Port/PathPort.cls`.
- No `PythonCreateVirtualEnvironment`, `PythonPathVar`, `Name` or `CurrentlyRunning` in a body.
- No new AD-27 case.
- No change to Start, Stop or the Activity log's read.
- No test starts, edits or deletes a vendor `%` server.
- No probe or test runs on `ocupilot`. Probes use uniquely named `OcuPilotProbeELS*` servers; a started probe is stopped before it is deleted, and its activity rows go with it.
- Edits to contended files are add-only (Design Notes › Footprint).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Create Java | Create; Type Java, Name, Port, JVM arguments | server exists with them, Resource `%Gateway_Object`; back on the list, it lists the server's row [AMENDED 2026-09-30, lead: was 'list re-fetches, row "Changed"'] | - |
| Create per type | Type chosen on the form | Custom members per Boundaries: settable ones as inputs, path members read-only with the caption; ODBC shows none | - |
| Create JDBC without Resource | agent or form omits it | sent `%Gateway_SQL`, shown on the card | - |
| Duplicate name | Create with an existing name | name check answers taken; the mint refuses; a name taken between the mint and the confirm is refused at confirm (AD-54) | nothing sent |
| Missing or out-of-range field | no Port; Port 70000; timeout 301 | violation on the field, with its published reason | 400 before any port call |
| Edit a stopped server | change Port | instance holds the new Port; every other field and every `Custom` member kept; `Custom` not in the body | - |
| Edit a Custom member | Java JVM arguments changed | whole `Custom` sent with its path members as held; the other members kept | - |
| Python Custom change | Python options changed | consequence line shown before Save; after Save, the virtual-environment flag reads 1 and PYTHONPATH is cleared (measured) | - |
| Python non-Custom edit | Python server, ConnectionTimeout changed | hidden settings kept | - |
| Path field supplied | agent passes `Custom.JavaHome` or `LogFile` | refused as not settable | 400 before any port call |
| Type change | agent passes `Type` on update | refused as not settable | 400 |
| Running server | running non-Remote server; edit or delete, screen or agent | refused with the running sentence; editor read-only | nothing sent |
| Started since mint | delete minted while stopped; started before Confirm | Confirm refused (fingerprint) | - |
| Running Remote | Remote whose remote answers | editable and deletable | - |
| Delete | stopped server, Delete, typed name, Delete | gone from the instance and the list | Cancel sends nothing |
| Python delete without CallOut | caller lacks `%System_CallOut:USE` | refused naming the pair; the server and its environment untouched | 403 before the vendor call |
| Missing write pair | caller has the screen's pairs only | Save, delete and mint refused naming `%Admin_Manage:USE` or `%DB_IRISSYS:WRITE` | 403 before any port call |
| Exactly the tools' pairs | screen pairs + `%Admin_Manage:USE` + `%DB_IRISSYS:WRITE` | create, update, delete of a Java server succeed | - |

</intent-contract>

## Code Map

Anchors are as of `0fa21806`.

**Derivation (DW-253):**

- `Test/FieldDerive.cls`:
  - `Derive` :96-165;
  - `Template` call :109;
  - `WALLETTYPES` :45-50 and the wallet loop :117-135, which is the per-type precedent;
  - `Header` :224-236; `WalkNode` :327.
- `scripts/field-lists.sh:48-54`: regenerates `Screen/Tool/FieldLists.cls` in the named container. `FieldLists.cls:108-121` holds today's member-less `LanguageServer` list, and :568-594 the wallet lists.
- `Port/AdminPort.cls`: `TEMPLATEARGUMENTS` :648 (doc :642-647); `Template` :1049-1105, which takes one argument per endpoint and keeps the last match.
- `ui/tools/field-lists.mjs`:
  - key rule :180 (`endpoint` or `endpoint:class`); :184 refuses a template list naming a class;
  - `--check` :460-467.
- `ui/tools/field-lists.test.mjs`: :119 (member-less `Custom` stays opaque) and :203 (`checkLists` is `[]`).
- `Test/DerivedFields.cls`:
  - :21 and :258 (fresh derivation and regeneration);
  - :48 (every endpoint keeps its untyped list);
  - :52-80 (`tTemplate` 40, wallet 3 at :75);
  - :162-218 (the wallet paths precedent);
  - :121-123 (a mutation note naming `TEMPLATEARGUMENTS`).
- `Screen/Tool/Classification.cls`: no `LanguageServer` entry today. OAuth `Metadata` is `opaque` with `compare: members` at :527-571.
- `Area/Security/OAuthClientRules.cls`:
  - runtime `FieldLists` read :83-160;
  - `MetadataSchema` :166-197;
  - member validation and expansion :318-399;
  - form members :401.

**Write kernel:**

- `Screen/Tool/Write.cls`: `DerivedFields` :324, `MergeUpdate` :350, `StateDiff` :486, `PermittedFields` :550, `FieldRows` :625-677.
- `Kernel/Proposal/Mint.cls`: `StateDiff` for every non-create at :233; `Merge` :534, whose payload is a copy of the fresh read.
- `Kernel/Proposal/Operation.cls`: `ReadTarget` :267, reached through the tool's `PORTCLASS`.
- `Port/TaskPort.cls`:
  - :1-117, the model for `LanguageServerPort`: a `GET` completed by a second type (`COMPLETEDTYPE` `GET`, `COMPLETINGTYPE` `INFO`, `COMPLETINGFIELD` `Type`);
  - a failed completing read fails the whole read.
- `Screen/Tool/TaskUpdate.cls`: `SettableFields` :84, `MergeUpdate` :132, `MergeSettings` :184. It is the member-by-member object merge, with `Settings.<key>` diff rows.
- `SslCreate.cls:33` and `SslUpdate.cls:39`: `PERMITTEDFIELDS` excludes the file fields; the edit re-sends them as held.

**Editor precedent (Namespaces, Story 18.2):**

- Descriptors and tools:
  - `NamespaceForm.cls:20-48`;
  - `NamespaceList.cls:39-40` (primary `create`, row `delete`);
  - `NamespaceCreate.cls`: `CREATES` :22, fields :34-37, `WRITERESOURCE`/`CLASSICPAGES` :43-48, `DerivedFields` :138, `PrivilegePairs` :146-153;
  - `NamespaceUpdate.cls`: :20-26, :39, :89-96;
  - `NamespaceDelete.cls`: :26-61, `PrivilegePairs` :94-102, `StateDiff` :104-.
- Server routes and handlers:
  - `Area/OsMgmt/NamespaceSave.cls` (`CREATETOOL`/`UPDATETOOL`/`DESCRIPTORCLASS` :22-28, `HandleCreate` :54, `HandleUpdate` :82, `Gate` :349);
  - `NamespaceRules.cls` (`HandleForm`, `HandleName`);
  - `Api/Router.cls:119-122`, with `Call=` wrappers at :554-609.
- Client:
  - `areas/os-management/namespace-form.page.ts` and `.store.ts` (path :12, POST/PUT :360-365, publish :504-508, child links :171-175, :320-336, :403);
  - `namespace-actions.ts:24-40`;
  - `shell/screen-outlet.ts:140-141` `DESCRIPTOR_PAGES`;
  - `app.ts:305-310` and :614-616; `app.spec.ts:1218-1222`.
- Type-driven fields: `task-wizard.store.ts:512-527`, `task-field-group.ts:180-188, 212, 517-527`, and `task-fields.ts:239` `EDIT_FIXED_FIELDS`.
- Captions:
  - the consequence line, `web-applications/create-form.page.ts:327, 341-342, 544-560`;
  - the read-only file caption, `ssl-form.page.ts:330, 342` with `sslFileClassicOnly` (`strings.ts:2052`).
- Navigation:
  - `core/navigation.ts:161-192`: `EDITOR_ROUTE_SUFFIX` :167, `editorScreenFor` :177, `createFormFor` :188;
  - `app.routes.ts:70-78`: create at `<list>/edit`, edit at `<list>/edit/<id>`;
  - `shell/data-table.ts:651-657`: the editor takes precedence over `childListFor`.
- `shell/screen-action-handler.ts`:
  - `SCREEN_ACTION_DESCRIPTORS` :86;
  - `DESTRUCTIVE_ACTIONS` :239;
  - `DESTRUCTIVE_CONSEQUENCES` :260-283 (a delete without one is not registered);
  - `PUBLISHED_PROBLEMS` :352-358.

**Story 16.10's code:**

- `LanguageServerList.cls:30-48` (`primaryAction` empty; `rowActions` start and stop).
- `LanguageServerStart.cls`: :50 `CLASSICPAGES`, :68-74 reasons, :115-120 `PrivilegePairs`, :125-155 `StateDiff`.
- `Test/LanguageServer.cls:68`, which pins `rowActions` exactly.
- `ui/browser/language-servers.browser-spec.mjs`, whose name-cell leg opens the Activity log today.
- `Port/AdminPort.cls`:
  - `TYPESUFFIXES` :117 (`GET` and `ACTIVITY` present);
  - `MUTATINGTYPES` :347 and `BODYLESSTYPES` :363 (START and STOP only);
  - `VERIFIEDDELETES` :397;
  - `TYPEFAULTS` :572.
- `Port/AdminRoutes.cls:121-124` (generated) already carries `PUT` and `DELETE` `/ext-lang-server`.

**Kernel and shared rosters (add-only):**

- `Kernel/Proposal/Prohibited.cls`: permitted change and create lists :710 and :823; the `DeviceFields` :1753 / Device arm :1745 shape; the language-server reviewed-few branch :1060-1065.
- `Api/Error.cls`:
  - the latest pair :4211-4213; violation codes :1463-1475; `ReasonForViolation` :1410;
  - a `LANGUAGESERVER.` prefix must not swallow `LANGUAGESERVER.START`.
- `Kernel/Governance/Baseline.cls`: append after :117.
- Exact rosters:
  - `Test/ReadTool.cls` :93 (165) and :94;
  - `Test/Navigation.cls` :342-343 (25);
  - `Test/Wire.cls:700`;
  - `Test/WireSecurityRead.cls` :554, :561, :564;
  - `Test/ClassicPageGate.cls` :51 and :120 (14);
  - `Test/MappingDescriptor.cls:16` `CLASSICROSTER`;
  - `ui/tools/navigation.test.mjs:150-186`, `navigation-wire.test.mjs` ~:143, `screen-mirror.test.mjs:2213-2230` (`ownPrivileges` owners);
  - `shell/rail-wire.spec.ts` ~:140 and :582.
- Membership rosters:
  - `Test/SurfaceCoverage.cls` (after :144 and :242);
  - `Test/ToolRoundTrip.cls:46` `REFUSEEMPTY`;
  - `Test/EndpointCoverage.cls` after :196;
  - `Test/PortFixture.cls:21` (a superset of `MUTATINGTYPES`; `ToolWrite.cls:1253-1256`).
- `scripts/ci-throwaway.sh:249-250` `# classes:` line and `ui/tools/ci.test.mjs` ~:1823-1846, for a new principal-armed class.

**Vendor (read in source):**

- `%CSP.UI.Portal.ExternalLanguageServer` creates (`PID` empty) and edits in `SaveData` :549, refusing a running server at :564 and a duplicate name at :568-571. It goes read-only while running at :192-194 and defaults `Resource` by type at :368-371.
- `%CSP.UI.Portal.ExternalLanguageServers` deletes in `DeleteItem` :241-254. It has no Hidden delete dialog.

## Tasks & Acceptance

**Execution:**

- `src/OcuPilot/Port/AdminPort.cls` -- `Template` gains an optional argument that takes precedence over `TEMPLATEARGUMENTS`, with its doc updated. `MUTATINGTYPES` gains `LanguageServer/PUT` and `LanguageServer/DELETE`, and `BODYLESSTYPES` gains `LanguageServer/DELETE` -- the per-type derivation, and the writes the port admits.
- `src/OcuPilot/Test/FieldDerive.cls` -- derive the nine `LanguageServer:<Type>` lists (a declared type list, header `type` set), then regenerate `FieldLists.cls` with `bash scripts/field-lists.sh --container ocupilot-ci` -- DW-253.
- `ui/tools/field-lists.mjs` and `field-lists.test.mjs` -- key a typed template list `endpoint:type`; add a case that a typed list keys and checks clean -- DW-253.
- `src/OcuPilot/Test/DerivedFields.cls` -- count the typed lists apart from the 40 template lists, and pin each type's `Custom.*` paths:
  - Java, XSLT, JDBC, ML and R: `{ClassPath, JavaHome, JVMArgs}`;
  - .NET: `{DotNetVersion, Exec32, FilePath}`;
  - Python: `{PythonOptions, PythonPath}`;
  - Remote: `{Address}`;
  - ODBC: none.

  Pin that the declared type list equals the set `Config.Gateways` `TypeSet` accepts (read its source) -- DW-253; a drift reddens.
- `src/OcuPilot/Port/LanguageServerPort.cls` (new) -- the `GET` completion and the Python-delete `%System_CallOut:USE` gate per Boundaries. `Snippet` renders the admin port's forms (its only own branch is a read) -- one fresh read for mint, confirm, Save and screen action (AD-52).
- `src/OcuPilot/Area/OsMgmt/LanguageServerRules.cls` (new):
  - field rules and violations, the per-type settable members and read-only path members from `FieldLists`, the Resource default by type, and `ArgumentProblem`;
  - `HandleForm`, which answers the types, each type's fields, and on edit the server read through the port, with `CurrentlyRunning`;
  - `HandleName`, the availability check.

  It is the semantic half, written once.
- `src/OcuPilot/Area/OsMgmt/LanguageServerSave.cls` (new) -- create and update Save for the person's caller, with `CREATETOOL`, `UPDATETOOL` and `DESCRIPTORCLASS`, on the Namespace shape (AD-55).
- `src/OcuPilot/Api/Router.cls` -- append `GET /language-server/form`, `GET /language-server/name`, `PUT /language-server/:id` and `POST /language-server`, with thin `Call=` wrappers -- add-only.
- `src/OcuPilot/Screen/Tool/LanguageServerCreate.cls`, `LanguageServerUpdate.cls` and `LanguageServerDelete.cls` (new) -- per Boundaries. Pairs follow `NamespaceCreate`'s `PrivilegePairs`.
  - Create: `CREATES` 1; the `Custom` object argument; `ComposeCreate` fills the type's Resource default.
  - Update: `MergeUpdate`; `Type` is not settable; the description carries the Python sentence.
  - Delete: `READANSWERS`, `PRECONDITIONFIELD` `CurrentlyRunning`, `FINGERPRINTSUBJECT` `CurrentlyRunning,Type`, and `StateDiff` refusing running.
  - The two refusal sentences are parameters, pinned.
- `src/OcuPilot/Screen/Tool/Classification.cls` -- create and update entries over `fieldList` `LanguageServer`: `Custom` `opaque` with `compare: members`, and a `compare` for any field the instance normalizes (measured). Then `cd ui && node tools/field-lists.mjs` regenerates `ToolFields.cls`.
- `src/OcuPilot/Screen/Descriptor/LanguageServerForm.cls` (new):
  - `form-page`, the list's pairs and `ownPrivileges`, entity type `language-server`, id `single`;
  - classic page `%CSP.UI.Portal.ExternalLanguageServer`, three prompts, `toolIdentifier` `osmgmt.languageserverform`.
- `src/OcuPilot/Screen/Descriptor/LanguageServerList.cls` -- `primaryAction` `create`; `rowActions` append `delete`.
- `src/OcuPilot/Kernel/Proposal/Prohibited.cls` -- a `LanguageServerFields()` in the permitted create and change lists, replacing the start/stop-only branch with a Device-style pass-through (no arm).
- `src/OcuPilot/Api/Error.cls` -- append the field violation codes and reasons (`LanguageServerViolationCodes()`), without swallowing `LANGUAGESERVER.START`.
- `src/OcuPilot/Kernel/Governance/Baseline.cls` -- append `osmgmt.languageservers.create`, `.update` and `.delete`, `true`.
- **New `src/OcuPilot/Test/LanguageServerEditor.cls`** (unarmed; fixture fresh reads; vendor servers only read). It pins:
  - registration: the form, the three tools, pairs, `CLASSICPAGES` and subject adequacy;
  - the rules' refusals;
  - `MergeUpdate`'s `Custom` merge, the omitted unchanged `Custom`, `CurrentlyRunning` never sent, the running refusal and the Remote exemption;
  - the port's completion observed through a port seam (`maxRows` 1);
  - the Resource defaults;
  - `Prohibited` covers the type.
- **New `src/OcuPilot/Test/LanguageServerEditorWire.cls`**, armed by `OCUPILOT_ALLOW_PRINCIPALS`, over HTTP with probe servers. It covers:
  - the exact-pairs principal creating Java, Python, .NET, Remote and ODBC probes and reading the form per type;
  - the Port edit keeping `Custom`;
  - a Python server's hidden settings (seeded through `Config.Gateways` in `%SYS`) kept on a non-`Custom` edit and reset on a `Custom` edit;
  - delete;
  - 403s naming each missing pair, with the instance unchanged;
  - the Python delete without CallOut refused and the server intact;
  - a started probe refused edit and delete, then stopped;
  - the agent's create minted and confirmed;
  - a create whose name was taken since the mint refused at Confirm;
  - a delete minted while stopped and started out of band, refused at Confirm;
  - teardown: stop, delete, activity rows, principals.

  Add the class to the `# classes:` line and to `ui/tools/ci.test.mjs`.
- `src/OcuPilot/Test/LanguageServer.cls:68` -- `rowActions` now start, stop, delete.
- Rosters -- one form, three tools, two actions in every file under Code Map › Kernel and shared rosters; bump your own additions only.
- `ui/src/app/areas/os-management/language-server-form.page.ts`, `.store.ts` and `language-server-actions.ts` (new), on the Namespace form's shape:
  - a type select on create, read-only Name and Type on edit;
  - per-type `Custom` inputs; read-only path fields with the caption;
  - the Python consequence line;
  - the running notice with every control read-only;
  - the Activity log link.

  Register the page (`DESCRIPTOR_PAGES`), Create (`createFormFor`) and the store reset in `app.ts`.
- `ui/src/app/shell/screen-action-handler.ts` -- `DESTRUCTIVE_CONSEQUENCES` gains the list's delete sentence; `PUBLISHED_PROBLEMS` admits the running sentence.
- `ui/src/app/core/strings.ts`, EXPERIENCE.md (in place, per Design Notes) and the regenerated `core/screens.generated.ts`. `ui/tools/self-protection.test.mjs` pins the running sentence equal to both tools' parameters, and the Python sentence to the update tool's.
- Client tests:
  - a new `language-server-form.page.spec.ts`: fields per type, the fixed Type on edit, the consequence, the running read-only, body composition and the link;
  - `screen-action-handler.spec.ts`: delete typed name;
  - `data-table.spec.ts:281`: the name cell opens the editor;
  - `app.spec.ts`: reset;
  - `rail-wire.spec.ts` and the `ui/tools` rosters.
- **New `ui/browser/language-server-editor.browser-spec.mjs`** (`assertThrowaway`). It:
  - Creates a Java probe through the form, then, back on the list, it lists the server's row;
  - opens the name cell, changes the Port and Saves;
  - follows the Activity log link, then comes back;
  - deletes with the typed name and sees the row gone;
  - shows the Python and .NET create fields;
  - shows a started probe's editor read-only, then stops it;
  - runs the DW-1337 walk of the form at wide light, narrow light and wide dark.

  In `language-servers.browser-spec.mjs`, the Activity log is now reached through the editor.

**Acceptance Criteria:**

- **AC1.** Given `ocupilot-ci`, when the person chooses Create on External language servers, picks a type and Saves a name and port, then the server exists on the instance with those values and the type's Resource default. Back on the list, it lists the server's row [AMENDED 2026-09-30, lead: was "The list shows its row marked 'Changed'"].
  - The form offers exactly the type's settable `Custom` members, shows its path members read-only with "File locations are set on the classic portal's External Language Server page.", and offers no `Custom` for ODBC.
- **AC2.** Given a stopped server, when its name is chosen, then its editor opens with Name and Type fixed and a link to its Activity log. A saved change reaches the instance while every field and `Custom` member it did not change keeps its value.
  - On a Python server, a changed `Custom` member shows the consequence line before Save.
- **AC3.** Given a running server whose type is not Remote, when its editor opens, then every control is read-only and the running sentence is shown. An edit or a delete through the screen or the agent is refused with that sentence and sends nothing.
  - A delete minted while stopped is refused at Confirm once the server has started.
- **AC4.** Given a stopped server, when the person chooses Delete on its row and types its name, then the server is removed from the instance and from the list.
  - A caller without `%System_CallOut:USE` is refused a Python server's delete, naming that pair, and the server is untouched.
- **AC5.** Given the agent, when it proposes `osmgmt.languageservers.create`, `.update` or `.delete` and the person confirms, then the write is the screen's own operation.
  - A create whose name was taken since the mint is refused at Confirm.
  - A path member or `Type` in an update's arguments is refused.
  - The three keys are in `Baseline.cls`, enabled.
- **AC6.** Given a principal holding the screen's two pairs, when they Save, delete or propose, then each is refused naming `%Admin_Manage:USE` or `%DB_IRISSYS:WRITE` before any port call. With both pairs added, a Java server's create, update and delete succeed.
  - A custom resource assigned to `%CSP.UI.Portal.ExternalLanguageServer` gates create and update (AD-44).
- **AC7 (DW-253).** Given the derivation, when `FieldLists.cls` is regenerated from `ocupilot-ci`, then it carries the nine `LanguageServer:<Type>` lists whose `Custom` members equal each type's `PutRequestBodySchema(<Type>)`. `DerivedFields` and `field-lists.test.mjs` fail on any drift.
- **AC8.** Given the new strings, when the story lands, then they are in EXPERIENCE.md's Fixed strings (993 lines, no citation moved) and in `strings.ts`, and the two tool sentences are pinned equal to their server copies.
- **AC9 (Integration).** Given `ocupilot-ci`, when the consumers run, then:
  - `ListPage` (consumer) shows the row that the editor's Save created;
  - the editor (consumer of `GET /language-server/form`) renders the `Custom` members that the derived `LanguageServer:<Type>` list names for the chosen type;
  - the form passes the DW-1337 walk in both themes with no new allowance.

## Spec Change Log

- 2026-09-30, implement halt (intent gap), lead ruling (Rule 5 tier 1, observable restated, intent unchanged): AC1, the I/O matrix row "Create Java" and the browser Tasks bullet no longer require the created row to read "Changed" after the person's form Save; they require that, back on the list, it lists the server's row. A form-page Save publishes its change event while no list is bound (`ListPage` unbinds `RefreshService`; `core/refresh.ts` marks only the bound screen; `ChangeBus` keeps no history), which holds for every editor, and EXPERIENCE.md:726 defines "Changed" for the entity on screen. The agent's create, confirmed with the list open, still marks its row. The framework alternative (a list marking events published while hidden) is not taken.

- 2026-09-29, spec gate (lead): the path-field decision is option A (orchestrator, owner's recommended option): `LogFile`, `ClassPath`, `JavaHome`, `PythonPath` and `FilePath` are shown, never set, with the caption pointing at the classic page; the PathPort-backed setting of the four single-location fields is DW-1856, routed to range-end cleanup. The lead wrote the spine changes (a)-(e) at this gate (AD-3, AD-4, AD-8, AD-21 in option A's form, AD-44). Since planning, Story 16.10 merged with External language servers at OS management position 9 and Local databases (Story 18.3) at 10, and DW-1768 (option B) made an area open when any listed screen is allowed: locate code by symbol and bump rosters from what the tree holds.

## Review Triage Log

## Design Notes

**Measured on `ocupilot-ci`, 2026-09-29.** The transcript is `…/scratchpad/epic-16/16-25/els-16-25-transcript.txt`, and it reuses 16.10's where noted. All probes were removed.

- **Request types.**
  - `GET` is the full-object read: every template key plus the type's `Custom`, and never `Name`, `PythonCreateVirtualEnvironment` or `PythonPathVar`.
  - `ACTIVITY` carries no definition. A bad `BindToIPAddress` slowed it to 10 s.
- **Create.** Every type is created by `{Type, Port}` alone (201; 16.10, re-measured for Java, .NET and Python).
  - `.NET` defaults `DotNetVersion` `N6.0`, which is outside `VALIDNETVERSIONS`, and Remote defaults `Address` `127.0.0.1`.
  - Missing keys answer 400 #40301; an unknown key, 400 #40307; `"Port":"abc"`, 500 #7207; a timeout of 301, 500 #7203.
  - Nothing is checked for `BindToIPAddress`, `Resource`, the TLS names or `DotNetVersion`.
- **Update.**
  - A one-key PUT keeps the rest, and a one-member `Custom` keeps the other members.
  - A `Type` change answers 500 "Cannot modify Type".
  - A PUT carrying `Custom` blanks the stored fields the type's `Custom` does not use. A Python server's virtual-environment flag returned to 1 and its `PythonPathVar` was cleared. A PUT without `Custom` kept both.
- **Running.**
  - Edits while running answer 200 and do not affect the running process.
  - A Port edit while running left Java listening on the old port while `CurrentlyRunning` read false.
  - A DELETE while running answered 200 and the port kept listening. Only re-creating the name and `STOP` cleared it.
- **Pairs.**
  - `%Admin_ExternalLanguageServerEdit:USE` with `%DB_IRISSYS:READ` → #921 "requires %Admin_Manage:USE".
  - Adding `%Admin_Manage:USE` → `<PROTECT>` in `Config.Gateways`.
  - Adding `%DB_IRISSYS:WRITE` as well → 201/200/200.
  - A Python delete also needs `%System_CallOut:USE`. 16.10 recorded that without it the vendor removed the virtual environment before refusing.
- **Audit.** Create, update and delete leave `%System/%System/ConfigurationChange` (AD-15's ordinary case; no new unaudited write).
  - A `<PROTECT>`-refused write still leaves a ConfigurationChange row claiming it happened, which is a candidate IRIS defect report. OcuPilot's pair check refuses before the vendor is reached, so its callers never produce one.

**Decision, for the spec gate: path fields are shown, never set.** It is the SSL/TLS precedent (AD-21).

- A created server uses the instance's default JVM or Python, with no log file. A class path can still be added at run time by the caller's own code (inference) or set in the classic portal.
- The alternative is PathPort's sixth case. It serves `JavaHome` and `FilePath` (directories), `PythonPath` (a `source`) and `LogFile` (a vendor-written file). It cannot serve `ClassPath`, a separator-joined list: PathPort composes one root and one relative name, and `SEGMENTPATTERN` (`PathPort.cls:38, 365-368`) refuses `:` and `;`. Choosing it would therefore be an intent gap on `ClassPath`.

**Decision: a running server is refused, not warned.** The measurements above show the harm is real, not cosmetic: a Port edit or a delete while running orphans a listener that no OcuPilot screen can see or stop. The classic editor refuses both (`:192-194`, `:564`), so OcuPilot refuses too. A Remote server is exempt, as in the classic editor, because nothing local listens.

**Why a port completes the read.** The update and the delete must see `Type` (Remote is exempt) and `CurrentlyRunning` in one fresh read, which the mint, the confirm, the prohibited set and the screen caller share (AD-52). `TaskPort` completes `GET` with `INFO` the same way.

- The running refusal sits in `MergeUpdate`, because the confirm re-merges through it. The delete's refusal sits in `StateDiff`, with the fingerprint catching a start after the mint.
- The Python CallOut gate is in the port because the vendor's harm happens inside that one call.

**Spine changes for the lead (Rule 20).** None contradicts an AD's Rule; each extends a named list.

- (a) **AD-3**, after the wallet sentence: "`LanguageServer` is derived once per `Config.Gateways` type as well (`LanguageServer:<Type>`, its template called with the type), because its `PutRequestBodySchema(type)` builds `Custom` per type. The untyped list keeps the top-level fields, and the editor's tools read the target type's list for `Custom`'s members (Story 16.25, DW-253)."
- (b) **AD-4**:
  - Add `LanguageServer` to the upsert list.
  - Append: "**`LanguageServer` is a named exception to the complete body** [Story 16.25]. It keeps an omitted key and merges `Custom` member by member. A PUT carrying `Custom` blanks the stored fields the type's `Custom` does not use: a Python server's virtual-environment flag and PYTHONPATH, which its `GET` never answers (measured on `ocupilot-ci` 2026-09-29). So its update omits an unchanged `Custom`, and a changed Python `Custom` states that consequence to the person and the agent."
- (c) **AD-8**, append: "**Story 16.25's language server tools declare pairs beyond their screen's set**: create, update and delete declare `%Admin_Manage:USE` and `%DB_IRISSYS:WRITE`. A principal holding the screen's two pairs was answered #921 without the first and `<PROTECT>` in `Config.Gateways` without the second (measured on `ocupilot-ci` 2026-09-29). A Python server's delete also requires `%System_CallOut:USE`, which `LanguageServerPort` checks by name before the vendor call, because the vendor removes the server's virtual environment before refusing. Each is refused by name before any port call."
- (d) **AD-21**, after the SSL/TLS sentence: "An external language server's `LogFile`, `ClassPath`, `JavaHome`, `PythonPath` and `FilePath` are such locations too: shown, never set (Story 16.25)."
- (e) **AD-44**, append: "**Story 16.25's `CLASSICPAGES`**: the language server create and update declare `%CSP.UI.Portal.ExternalLanguageServer`; the delete, performed on the list's own page, declares none."

**Copy** (EXPERIENCE.md in place; 993 lines):

- **Fold into `:584`, tagged `[ADDED 2026-09-29 - Story 16.25]`:**
  - the form's title on create: "New external language server";
  - labels:
    - general: "Resource" · "Bind address" · "Connection timeout (seconds)" · "Initialization timeout (seconds)" · "Use shared memory" · "Server TLS configuration" · "Client TLS configuration" · "Verify the server's host name";
    - paths: "Log file" · "Class path" · "Java home" · "File path" · "Python executable";
    - per type: "JVM arguments" · ".NET version" · "Run as 32-bit" · "Python options" · "Address";
  - the caption "File locations are set on the classic portal's External Language Server page.";
  - the running sentence "This server is running. Stop it before changing or deleting it.";
  - the Python consequence "Saving this also turns the server's virtual environment back on and clears its PYTHONPATH, which only the classic portal shows.";
  - the name check "A server with this name already exists.".

  Reuse the existing "Name", "Type", "Port", "Activity log" and "Create".
- **Fold into `:479`:** the delete consequence "Deleting it removes this server's definition from the instance."
- **Fold into `:585`:** three form prompts, group `promptGroupGettingStarted` (as `NamespaceForm`'s): "What does each setting on this server do?" · "Why might this server fail to start?" · "Which resource should protect this server?"
- **Keys:**
  - `languageServerFormLabel`, `languageServerFormNew`;
  - `languageServerField*` for each label;
  - `languageServerPathClassicOnly`, `languageServerRefusalRunningEdit`, `languageServerPythonConsequence`, `languageServerNameTaken`, `languageServerDeleteConsequence`;
  - `languageServerFormPrompt1-3`.

**Named limits:**

- The classic editor hides the three TLS fields for the Java-based types (its `changeType`, :277-372). OcuPilot offers every field the type's template names.
- Windows `.NET Framework` versions (`VALIDFRAMEWORKVERSIONS`) are not offered.
- An edit keeps a stored `DotNetVersion` outside the list until it is changed.
- Two servers may share a port, as the vendor allows.
- Vendor `%` servers may be edited and deleted, as the classic list's Delete condition (:325) names no exception.
- The list offers Delete on a running row, and the refusal answers the click after the typed name. This follows the `PRESERVEDSESSION` precedent; no self-protection rule is added.
- A `Remote` server's running check pings the remote host, for up to 10 s.

**Governing ADs:**

- writes: AD-3, AD-4, AD-6, AD-8, AD-10, AD-13, AD-14, AD-15, AD-21, AD-22, AD-29, AD-34, AD-39, AD-44, AD-51, AD-52, AD-53, AD-54, AD-55, AD-56, AD-58, AD-59;
- screens: AD-5, AD-11, AD-19, AD-20, AD-24, AD-36;
- AD-2, AD-26 and AD-27 (admin API only, synchronous, contained);
- AD-60 (tool results reach the model through the sanitizer).

**Integration:**

- **Consumes:**
  - 16.10's list, `language-server` type and Activity route;
  - 18.2's form, save and typed-delete shapes;
  - 9.8's `TaskPort` completion and `MergeSettings`;
  - 12.5's `Metadata` object argument;
  - 16.17's read-back; 14.1's copy-out.
- **Consumed-by:** this story's own editor and tools. No later story is planned.

**Ledger.** DW-253 is addressed by the derivation tasks and AC7.

**Footprint.** These are contended with Epic 18 and add-only: `strings.ts`, EXPERIENCE.md Fixed strings, `Error.cls`, `Router.cls` routes, `Baseline.cls`, the exact-count rosters, `ci-throwaway.sh`/`ci.test.mjs`, `screens.generated.ts`, `FieldLists.cls`/`ToolFields.cls` and `Classification.cls` (regenerate the generated ones, never hand-edit), `AdminPort` type lists, and `Prohibited.cls`. `Port/PathPort.cls` is not edited.

## Verification

Slot A only. Everything that creates, starts, stops, edits or deletes a server, or creates a principal, runs on `ocupilot-ci`. Every browser run first rebuilds the bundle and copies it with `docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`, exporting `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776` and `OCUPILOT_BROWSER_CONTAINER=ocupilot-ci`.

**Commands:**

- `bash scripts/field-lists.sh --container ocupilot-ci`, then `cd ui && node tools/field-lists.mjs` (loop) -- expected: `FieldLists.cls` gains exactly the nine typed lists, and `ToolFields.cls` the three tools.
- `cd ui && npm run test:tools` (loop) -- expected: green (`field-lists`, `screen-mirror`, `strings`, `self-protection`, `navigation`, `navigation-wire`, `ci`). Mutation: the key rule drops `:type` → `field-lists.test.mjs` goes red.
- `cd ui && npx ng test --include src/app/areas/os-management/language-server-form.page.spec.ts --include src/app/shell/screen-action-handler.spec.ts --include src/app/shell/data-table.spec.ts --include src/app/shell/list-page.spec.ts --include src/app/shell/rail-wire.spec.ts --include src/app/app.spec.ts` (loop) -- expected: green. Mutations:
  - AC1: the Python type offers `Custom.PythonPath` as an input → the form spec goes red;
  - AC2: `Custom` sent unchanged → the body case goes red.
- `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class <C>` (loop), one class per call. `<C>` is each of: `OcuPilot.Test.LanguageServerEditor`, `LanguageServerEditorWire`, `LanguageServer`, `LanguageServerWire`, `DerivedFields`, `Descriptor`, `Navigation`, `Wire`, `WireSecurityRead`, `ReadTool`, `SurfaceCoverage`, `EndpointCoverage`, `ToolWrite`, `ToolRoundTrip`, `ToolEmit`, `Prohibited`, `GovernanceBaseline`, `PortFixture`, `PromptCorpus`, `ClassicPageGate`, `MappingDescriptor`, `DraftRegistry`, `ReadBack`. Expected: green. Mutations:
  - AC3: the Remote check removed from `MergeUpdate` → the Remote-exemption leg goes red;
  - AC3: the running refusal removed → the wire's started-probe leg goes red;
  - AC4: the port's CallOut gate removed → the Python-delete leg goes red;
  - AC5: the create's absence fingerprint emptied → the taken-since-mint leg goes red;
  - AC6: `%Admin_Manage:USE` dropped from `PrivilegePairs` → the missing-pair leg goes red;
  - AC7: one typed list deleted from `FieldLists.cls` → `DerivedFields` goes red.
- `cd ui && npm run build && docker cp … && node --test --test-concurrency=1 browser/language-server-editor.browser-spec.mjs browser/language-servers.browser-spec.mjs browser/namespaces.browser-spec.mjs browser/a11y-structural-invariants.browser-spec.mjs` (loop) -- expected: green within the structural baseline. Mutation: the Activity link removed, rebuilt and redeployed → the editor spec goes red.
- `cd ui && npm test`, `uv run scripts/check-objectscript.py`, `bash scripts/lint-docs.sh`, `wc -l` on EXPERIENCE.md (once, before `dev_complete`) -- expected: green, and 993.
  - If the bundle crosses `maximumWarning`, re-base it under DW-1166 with the `angular-json.test.mjs` literal. Stop above 3800 kB.
- The full ObjectScript sweep on `ocupilot-ci`, one class at a time (once, before `dev_complete`) -- expected: green apart from the known residue. The full browser suite runs in CI (Rule 29).

Mutations demonstrated (implement stage, each reverted with the tree unchanged after):

- mutation: `field-lists.mjs`'s key rule drops the `:type` arm → `field-lists.test.mjs` "a typed template list keys as endpoint:type and checks clean beside its untyped list" went red.
- mutation: the store's `customMembers()` answers a type's path members too → `language-server-form.page.spec.ts` AC1 (fields per type) and AC2 (edit) went red.
- mutation: `changedBody()` sends every `Custom` member → `language-server-form.page.spec.ts` "AC2: an edit puts only what changed ..." went red.
- mutation: the `Remote` test dropped from `LanguageServerRules.Running` → `OcuPilot.Test.LanguageServerEditor.TestTheUpdateMergesCustomByMember` and `TestTheDeleteRefusesARunningServer` went red (run 20966).
- mutation: the running refusal dropped from `LanguageServerUpdate.MergeUpdate` → `OcuPilot.Test.LanguageServerEditorWire.TestAStartedServerIsRefusedEditAndDelete` went red (run 20967).
- mutation: the call-out gate skipped in `LanguageServerPort.Invoke` (port and seam recompiled) → `LanguageServerEditorWire.TestAPythonDeleteNeedsCallOutAndAStoppedServerIsDeleted` went red (run 20968).
- mutation: `Mint.AbsenceState` answers `{}` (Mint and subclasses recompiled) → `LanguageServerEditorWire.TestTheAgentsWritesConfirmAndATakenNameIsRefusedAtConfirm` went red (run 20969).
- mutation: `%Admin_Manage:USE` dropped from `LanguageServerCreate.PrivilegePairs` → `LanguageServerEditorWire.TestEachMissingPairIsRefusedByName` went red (run 20970).
- mutation: the `LanguageServer:XSLT` list deleted from `FieldLists.cls` → `OcuPilot.Test.DerivedFields.TestTheCommittedListsEqualAFreshDerivation` and `TestTheCommittedClassIsARegeneration` went red (run 20971).
- mutation: one word of `LanguageServerUpdate.RUNNINGREASON` changed → `self-protection.test.mjs` "Story 16.25: the running refusal ..." went red.
- mutation: the editor's Activity link hidden, rebuilt and redeployed → `language-server-editor.browser-spec.mjs` "AC1, AC2, AC4" went red at the link wait.

The browser spec asserts the created row on the list (AC9), not a "Changed" mark: a form-page Save publishes while no list is bound, so the list re-reads without one (measured; reported to the lead as an intent gap).

## Auto Run Result

Status: blocked
Blocking condition: intent gap: AC1's "The list shows its row marked 'Changed'" and the I/O matrix row "Create Java" ("list re-fetches, row 'Changed'") cannot hold for the person's Create. A form-page Save publishes its change event while no list is bound: `ListPage` unbinds `RefreshService` when it leaves, `core/refresh.ts` marks a row only on the bound screen, and `ChangeBus` keeps no history. So no editor marks the row, and EXPERIENCE.md:726 defines "Changed" as a change event for the visible entity. Recommended amendment (restates the observable, intent unchanged): AC1 and the matrix row read "back on the list, it lists the server's row", and the Tasks bullet "then the row reads 'Changed'" is changed the same way. The agent's create, confirmed with the list open, still marks its row. Alternative, not recommended: a framework change so a list marks the events published while it was not shown (`core/refresh.ts`, every editor).

This pass: the handoff subagent implemented every task (58 paths). Its report (73 min): the targeted classes green on `ocupilot-ci` (`LanguageServerEditorWire` armed, run 20972), `npm test`, `test:tools`, the six `ng test` specs and the four browser specs green, the bundle at 2,217.4 KiB, and 12 mutations recorded under Verification. This stage halted at the Matrix Test Audit, so its own Verify commands, the full ObjectScript sweep and the review layers have not run. Checked here: HEAD is unchanged, no commit or push was made, and `ocupilot-ci` holds no probe server, activity row or editor principal.

Paths outside the Code Map: `Api/LanguageServerError.cls`, because `Error.cls` is at the compiler's 1,000-parameter limit (ERROR #5290); `Test/LanguageServerSeamPort.cls`; `Test/LanguageServerEndpoint.cls`; `Test/ToolEmit.cls`. `ToolFields` carries two tools, since the delete sends no body. `ui/tools/ci.test.mjs` is unedited because it derives its roster.

Open for the next pass's audit:

- "Duplicate name": no test yet that the agent's create mint refuses a taken name. The refusal at Confirm is pinned.
- "Missing or out-of-range field": pinned in the rules and at the screen's 422, the project's validation status. No agent dispatch pins the 400.
- The header of `LanguageServerEditorWire.TestAStartedServerIsRefusedEditAndDelete` says the agent's delete is refused at the mint, but the test mints the update.
