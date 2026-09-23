---
title: 'Story 8.8: The device editor'
type: 'feature'
created: '2026-09-23'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-8-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-8-5-x-509-import-edit-and-delete.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** The Devices list (Story 6.12) is read-only. No tool writes `Device.Standard`, so a device cannot be created, edited or deleted from OcuPilot. The contest names "devices" as an area to administer.

**Approach:**

- Ship a form page at `os-management/devices/edit`. It carries the classic device page's nine fields (`%CSP.UI.Portal.Config.Device`). The Devices list's Create opens it, and so does the list's name cell.
- Its Save goes through `osmgmt.devices.create` (a create, AD-54) and `osmgmt.devices.update` (a merge, AD-4). The screen and the agent are two callers of one tool (AD-55).
- Ship the agent's `osmgmt.devices.delete` too. It is action-style (AD-51), destructive and verified.
- Where the screen's delete lives is for the lead to rule (Design Notes).

## Boundaries & Constraints

### Always

- **Field list.** Name plus the template's eight fields, in classic order: Name, PhysicalDevice, Type, SubType, OpenParameters, Description, Alias, AlternateDevice, Prompt.
  - The eight come from `FieldLists` `Device.Standard` (AD-3). Nothing is typed by hand.
  - Name is the id (`IdArgument "Name"`, `IdParam "name"`). It is read-only on edit, as on the classic page, so a device is never renamed.
- **Value shapes.** Every value is sent as the vendor's `GET` answers it: `Alias` and `Prompt` as integers, and `""` when empty (an empty value clears the field, measured). Every other field is a string.
- **Complete set (AD-4).** An update sends the fresh read's eight fields with the caller's changes applied, even though the vendor merges (measured).
- **Case.** Names are exact-case. `OcuPilotProbe88A` and `OcuPilotProbe88a` coexisted, and a case-variant `GET` answered 404. So `device` gets no `IDRULES` entry.
  - Every existence check uses the single `GET`, because the `LIST` `names` filter ignores case.
- **Field rules.** The rules in the matrix run in `DeviceRules.Validate`. The tool's `ArgumentProblem` and the screen routes both call it, so both callers refuse alike.
  - On an update, the rules check only the fields the caller changes. A stored value outside the rules does not block an unrelated edit.
- **Wording.** Every field sentence is authored once in `Api/Error.cls`. Every visible word is a `STRINGS.<key>` with a Fixed strings row, and a key is reused wherever its value and meaning match.

### Never

- Never edit these: `Kernel/Proposal/Confirm.cls`, `Kernel/Restraint.cls`, `Port/LogSourcePort.cls`, `Install/{Smoke,Fixture}.cls`, `Screen/Tool/UserUpdate.cls`, `Screen/Tool/Write.cls`, `Kernel/Proposal/Mint.cls`, or `ui/src/app/areas/{tasks,logs}/**`.
- No rename, and no `Device.SubType` or `Device.Settings` write.
- No screen-side delete until the lead rules on it.
- No AD-27 port completion: the admin API carries everything this story needs.
- Never modify or delete a device the test did not create. Tests use the prefix `OcuPilotProbe88` and remove each device by exact name.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Create, screen | `POST /api/ocupilot/device` `{Name:"OcuPilotProbe88A", PhysicalDevice:"/tmp/p88.txt", Type:"OTH", SubType:"P-DEC", Alias:9988, Prompt:1, ...}`, name free | 201 `{name}`. The port's `PUT ?name=` receives the eight fields. A `device` `created` event follows, the route becomes `os-management/devices/edit/OcuPilotProbe88A`, and the bar shows `formSaved` | No error expected |
| Edit, screen | `PUT /device/<id>` `{Description:"x"}` | The port body is the fresh read plus the change. 200 and an `updated` event | Any key outside the eight answers 400, and nothing is sent |
| Agent create / update | `osmgmt.devices.create` `{Name, PhysicalDevice, Type, SubType, ...}` / `.update` `{Name, ...changes}` | Create: a diff row per supplied field and the absence fingerprint. Update: a merge diff over the fresh read | A rule failure answers 400 `TOOL.ARGUMENTS` at mint |
| Agent delete | `osmgmt.devices.delete` `{Name}` | A destructive proposal whose card shows the eight removed fields. Confirm issues `DELETE`, re-reads, and expects 404 (`VERIFIEDDELETES`), then a `deleted` event | Absent at mint: 400 `TOOL.ARGUMENTS`. Changed or deleted since: 409 `PROPOSAL.TARGETCHANGED` |
| Deleted since the read | The target is deleted between the read and the write | Screen: 404 `DEVICE.NAME.ABSENT`, nothing sent. Agent update: 409 `TARGETCHANGED` | The vendor `PUT` would have re-created it (201, measured). This row is the guard |
| Name taken | The exact-case name exists | `DEVICE.NAME.TAKEN` on Save and on blur (`GET /device/name`). Taken after the mint: 409 | Nothing is written |
| Field rules | Name empty, over 64, or holding `^`, `=` or a control character. PhysicalDevice, Type or SubType missing on create. Type not one of TRM, SPL, MT, BT, IPC, OTH. SubType not in the subtype list. PhysicalDevice, OpenParameters or AlternateDevice over 128; Description over 256; any of these four holding `^` or a control character. Alias not a whole number of at least 1, held by another device, or equal to PhysicalDevice. Prompt not `""`, 1 or 2 | One `DEVICE.<FIELD>.<RULE>` row per failing field | Screen: 422. Agent: 400 at mint |
| Open parameters the vendor cannot parse | `OpenParameters:"((("` | Screen: 422 `DEVICE.OPENPARAMETERS.SHAPE` on the field, mapped from the port's vendor error 644 | Agent: confirm fails with the port's normalized failure, and nothing is written |
| No `%Admin_Manage` | Caller lacks `%Admin_Manage:USE` | The form route renders the screen-level denial naming the pair | Every device route answers 403 `AUTH.NOPRIVILEGE` |
| Leave dirty | Any navigation away from a changed form, the agent's included | The shared leave question | Nothing is lost silently |

</intent-contract>

## Code Map

### Contention (Epic 7 head `b35d39c04b27a01a7dceddb9c4622c6a29e19f94`; merge base `dbc0c347`)

Before editing a ⚠ file, run `git fetch origin && git show origin/OCU-1-epic7:<path>`, since the head moves.

- `e7 :n` is a line in Epic 7's file; `HEAD :n` is a line in this branch's.
- Stay off Epic 7's hunks and restructure nothing it added.
- A shared roster takes this story's own members only.
- A single line both branches extend merges as a union. "Certain" below marks where that conflict will happen.

| File | This story's edit | Epic 7 hunk |
|---|---|---|
| ⚠ `Kernel/Proposal/Prohibited.cls` | `COVEREDTYPES` HEAD :138 | e7 :157 (certain) |
| | TYPE parameter after HEAD :151 | e7 :172-175 |
| | type-gate chain HEAD :469 | e7 :399 (certain) |
| | dispatch branch beside `wallet-secret` HEAD :522 | e7 :424, :443-446 |
| | `PermittedChangeFields` HEAD :330 and `PermittedCreateFields` HEAD :398 | e7 :324 (user row only) |
| ⚠ `Port/AdminPort.cls` (shared-append) | `MUTATINGTYPES` HEAD :195 | e7 :208 (certain) |
| | `BODYLESSTYPES` HEAD :211 | e7 :224 (certain) |
| | `VERIFIEDDELETES` HEAD :222 | not in Epic 7 |
| | doc lines near HEAD :182-194 | e7 :131-161 |
| ⚠ `Screen/Tool/Classification.cls` | tail append after HEAD :305 | e7 appends at HEAD :304 (likely) |
| ⚠ `Screen/Tool/ToolFields.cls` | regenerate only | |
| ⚠ `Api/Router.cls` | four routes after HEAD :114 | e7 :95 inserts `/screens/:screen/action` at the same anchor, HEAD :115 |
| | handlers after HEAD :431 | e7 :253-263 |
| ⚠ `ui/src/app/shell/screen-outlet.ts` (append-only) | import after :33; `DESCRIPTOR_PAGES` entry after :105 | e7 :20, :89 |
| ⚠ `ui/src/app/core/strings.ts` (shared-append) | append before `} as const;` :1466 | e7 :1317-1437 (certain) |
| ⚠ EXPERIENCE.md (shared-append) | Fixed strings rows after :416 | e7 :395-425 |
| ⚠ `Test/SurfaceCoverage.cls` | own rows | e7 :103-116 ↔ HEAD :119-123 |
| ⚠ `Test/EndpointCoverage.cls` | own rows | e7 :95 ↔ HEAD :102 |
| ⚠ `Test/ReadTool.cls` :93-94 | own roster and count | e7 :93-94 (count 62 there, 60 here) |
| ⚠ `Test/ToolRoundTrip.cls` :29-30 | own rows | e7 :29-34 |
| ⚠ `Test/PortFixture.cls` :21 | own entries | e7 :21 |
| ⚠ `Test/Prohibited.cls` :193 | own entry | e7 :181 |
| ⚠ `Test/Descriptor.cls` | flip the no-primary-action leg in the Devices-list test :1743 | e7 :56-231 (a `ReadShapes` DeviceList row; the read is unchanged here) and :1995-2021 (right after it) |

### Needs the lead

These files are in Epic 7's diff and not on the contended list:

- `src/OcuPilot/Test/Wire.cls` :680 and `WireSecurityRead.cls` :547/:554/:557: the os-management screen rosters gain the form route (`sideBarPosition 0`).
- `ui/src/app/core/screens.generated.ts`: regenerate only.
- `ui/tools/navigation.test.mjs`: only if a route row is needed.
- `ui/angular.json` :54 and `ui/tools/angular-json.test.mjs` :371: only on a DW-1166 re-base.

### Server

- **Tool base:** `Screen/Tool/Write.cls` (no edit), anchored in its own file:
  - parameters: `DESTRUCTIVE` :52, `READTYPE` :57, `WRITETYPE` :62, `SENDSBODY` :67, `FINGERPRINTSUBJECT` :97, `PRECONDITIONFIELD` :105, `PORTCLASS` :114, `CHANGEACTION` :124, `CREATES` :141, `READANSWERS` :154;
  - methods: `IdArgument` :331, `IdParam` :338, `PermittedFields` :358, `ArgumentProblem` :568.
  - `Registry.FingerprintSubjectProblem` checks the delete's subject.
- **Templates:**
  - create: `ResourceCreate.cls` (94 lines);
  - update: `ResourceUpdate.cls` and `X509Update.cls`;
  - delete: `ResourceDelete.cls` (`WRITERESOURCE`/`WRITEPERMISSION` :50-52, `ArgumentProblem` :81, `StateDiff` :122) and `X509Delete.cls` (`REMOVALROWS` :46, `StateDiff` :110).
- **Field list:** `FieldLists.cls` :50-59 already holds `Device.Standard`: the same eight fields as the live `RequestBodySchema`.
- **Identity:** `Kernel/EntityRef.cls` :59 `IDRULES` gets no entry (`device` is already in `Kernel/EntityType.cls` :34).
- **Prohibited set:** `Prohibited.cls` `ReviewedFewOnly` :1147. `X509` :1043 is the model for killing `pChanged` on a `DELETE`. Unknown types are refused at `Created` :627.
- **Screen-route templates:** `Area/Security/X509Rules.cls` (`Validate` :56, `HandleForm` :199, `HandleName` :251, `Gate` :376) and `X509Save.cls` (`HandleCreate` :59, `HandleUpdate` :89, `Create` :120, `Update` :172, `Prohibited` :231, `Send` :247, `CallerFields` :284). `Area/Security/WalletRules.cls` reads a collection through the port. `Area/OsMgmt/` does not exist yet.
- **Errors:** `Api/Error.cls`: `ReasonForViolation` :1048, `*ViolationCodes` :1194-1219, the WALLET block from :2023, `VENDORFIELDCODES` :2117.
- **Descriptors:** `Screen/Descriptor/DeviceList.cls`: `primaryAction` :58, `emptyAgentKey` in `table`, doc :1-35. `X509Form.cls` is the form descriptor template.
- **Port failure:** `AdminPort.Fail` (called at :618) is where a vendor error number reaches the fault. Read it before mapping error 644.

### Client

- Templates: `ui/src/app/areas/security/x509-form.page.ts` (`open` :333, summary :74, sticky bar :276, leave dialog :291 and `answerLeave` :584, save and route replacement :563-572, `routeId` :591); `x509-form.store.ts` (`retainAcrossRouteReplacement` :300, `reset` :308, `save` :413, `publish` :607); `x509-actions.ts` for the Create handler.
- `core/navigation.ts` (no edit): `editorScreenFor` :177 and `createFormFor` :188 find a built, unlisted `<list>/edit`, and `shell/data-table.ts` :475 links the name cell there.
- `app.ts` (not in Epic 7): injections :231-253, sign-out resets :496-530.
- `strings.ts` device keys :993-999. EXPERIENCE.md :100 is the Device editor row.
- `ui/browser/x509-import.browser-spec.mjs` is the browser template; `ui/browser/devices.browser-spec.mjs` (not in Epic 7) holds the list spec.

## Tasks & Acceptance

### Execution

#### Port and prohibited set

- `src/OcuPilot/Port/AdminPort.cls` (shared-append):
  - ⚠ `MUTATINGTYPES` gains `Device.Standard/PUT,Device.Standard/DELETE`.
  - ⚠ `BODYLESSTYPES` gains `Device.Standard/DELETE`.
  - `VERIFIEDDELETES` gains `Device.Standard/DELETE`. `Config.Devices.Delete`'s body is stripped from the export, so a 200 is not trusted unread.
  - One doc line for each.
  - No `VERIFIEDWRITES` entry: every probed 2xx applied, and every failure answered 400 or 500.
- ⚠ `src/OcuPilot/Kernel/Proposal/Prohibited.cls` (off Epic 7's hunks):
  - Add `TYPEDEVICE "device"` to `COVEREDTYPES`, the type-gate chain and the dispatch (`ReviewedFewOnly`, killing `pChanged` on a `DELETE` as `X509` does).
  - The permitted create and change fields are the eight template fields.
  - No own-object predicate: OcuPilot creates and relies on no device (the installer was read).

#### Tools

- `src/OcuPilot/Screen/Tool/DeviceCreate.cls` (new, on `ResourceCreate`):
  - `TOOLNAME "osmgmt.devices.create"`, `DESCRIPTORCLASS DeviceList`, `CREATES 1`, `READTYPE "GET"`, `WRITETYPE "PUT"`, `CHANGEACTION "created"`, `Endpoint() "Device.Standard"`;
  - the eight fields permitted, and `WRITERESOURCE "%Admin_Manage"` `USE`;
  - `ArgumentProblem` runs `DeviceRules.Validate` (create mode).
- `src/OcuPilot/Screen/Tool/DeviceUpdate.cls` (new, on `ResourceUpdate`):
  - `TOOLNAME "osmgmt.devices.update"`, `SENDSBODY 1`, `CHANGEACTION "updated"`;
  - the same endpoint, fields and resource;
  - `ArgumentProblem` runs the rules over the changed fields. The default fingerprint covers the merged payload.
- `src/OcuPilot/Screen/Tool/DeviceDelete.cls` (new, on `ResourceDelete`/`X509Delete`):
  - `TOOLNAME "osmgmt.devices.delete"`, `READTYPE "GET"`, `WRITETYPE "DELETE"`, `SENDSBODY 0`, `CHANGEACTION "deleted"`, `DESTRUCTIVE 1`;
  - `READANSWERS` and `FINGERPRINTSUBJECT` are the eight fields, and `PRECONDITIONFIELD "PhysicalDevice"`;
  - `StateDiff` and `REMOVALROWS` follow `X509Delete`, so the card lists what is removed;
  - the same resource. There is no `LISTTYPE`: existence is the exact `GET`.
- ⚠ `Classification.cls` (tail append): the create and update tools over `fieldList "Device.Standard"`, every field `ordinary`. The delete has no entry, since it sends no body. Regenerate `ToolFields.cls` with `cd ui && node tools/field-lists.mjs`.
- `Screen/Descriptor/DeviceList.cls`: `primaryAction {"id":"create","selfProtection":""}`, `emptyAgentKey "deviceListEmptyAgent"`, and a doc update (the editor is this story's). Its read, table and privileges are unchanged.
- `Screen/Descriptor/DeviceForm.cls` (new, on `X509Form`):
  - `route "os-management/devices/edit"`, `area "os-management"`, `labelKey "deviceFormLabel"`, `sideBarPosition 0`, `archetype "form-page"`, `entityType "device"`, `scope "instance"`, `parentScope ""`, `id single`;
  - the list's privileges (`%Admin_Manage:USE`, `%DB_IRISSYS:READ`), established per AD-29 by `DeviceWire`;
  - `classicPage "%CSP.UI.Portal.Config.Device"`, `toolIdentifier "osmgmt.deviceform"`.

#### Screen routes

- `src/OcuPilot/Area/OsMgmt/DeviceRules.cls` (new, on `X509Rules`):
  - `Validate(pName, pArgs, Output pViolations, pMode, pCheckTaken)` holds the matrix rules.
    - The subtypes are `Device.SubType` `LIST` through the port.
    - The alias check reads `Device.Standard` `LIST` and excludes the device itself.
  - `HandleForm` (`GET /device/form[?name=]`) answers `{requiredFields, maxLengths, rules, typeValues, subTypes}`. With a name it adds `device:{Name, ...eight}` from the fresh `GET`, or 404 `DEVICE.NAME.ABSENT`.
  - `HandleName` (`GET /device/name?name=`) answers `{taken}` from the exact `GET`.
- `src/OcuPilot/Area/OsMgmt/DeviceSave.cls` (new, on `X509Save`):
  - `HandleCreate`: gate, the verdict over the caller's fields, `Validate`, `Compose`, then the port `PUT`.
  - `HandleUpdate`: gate, fresh `GET` (404 `ABSENT`), the key-set check, `Validate` over the changed fields, `Mint.Merge`, the verdict, then the `PUT`.
  - `PROHIBITED.*` answers 403. A port failure carrying vendor error 644 answers 422 `DEVICE.OPENPARAMETERS.SHAPE`.
- ⚠ `Api/Router.cls`: `GET /device/form`, `GET /device/name`, `PUT /device/:id`, `POST /device`, with thin handlers. Sub-resource routes go before `:id`.
- `Api/Error.cls`, in its own block:
  - `DEVICE.VALIDATION` (422);
  - `DEVICE.NAME.{REQUIRED,LENGTH,SHAPE,TAKEN,ABSENT}`, `DEVICE.PHYSICALDEVICE.{REQUIRED,LENGTH,SHAPE}`, `DEVICE.TYPE.{REQUIRED,VALUE}`, `DEVICE.SUBTYPE.{REQUIRED,ABSENT}`;
  - `DEVICE.OPENPARAMETERS.{LENGTH,SHAPE}`, `DEVICE.DESCRIPTION.{LENGTH,SHAPE}`, `DEVICE.ALTERNATEDEVICE.{LENGTH,SHAPE}`, `DEVICE.ALIAS.{SHAPE,TAKEN,SAME}`, `DEVICE.PROMPT.VALUE`;
  - each with its sentence, plus the `ReasonForViolation` branches and `DeviceViolationCodes`.

#### Client

- New files, ids `ocu-device-`: `ui/src/app/areas/os-management/device-actions.ts`, `device-form.store.ts` and `device-form.page.ts`.
- The fields, in classic order:
  1. Name: required on create, read-only on edit.
  2. Physical device name: required.
  3. Type: select, TRM/SPL/MT/BT/IPC/OTH, `OTH` by default.
  4. Subtype: select from the form read, `P-DEC` by default, not narrowed by Type (as classic).
  5. Open parameters.
  6. Description.
  7. Alias: a number input.
  8. Alternate device.
  9. Prompt: a radio group with `""`, 1 and 2, default `""`.
- An edit sends `changedFields()` after the fresh read, and an unchanged edit writes nothing.
- Save publishes `{kind:'changed', type:'device', scope:'instance', id, action}`. A create replaces the route with `os-management/devices/edit/<encodeEntityId(name)>` and shows `formSaved`.
- ⚠ `screen-outlet.ts` gets the `DeviceForm` entry. `app.ts` injects `DeviceActions` and resets the form store at sign-out.
- ⚠ `strings.ts` and EXPERIENCE.md Fixed strings, append only, reusing any key whose value and meaning match (`deviceColumnPhysical`, `deviceColumnSubtype`, `tableColumnName`, `tableColumnType`, `tableColumnDescription`, `x509ColumnAlias`). New keys:
  - `deviceFormLabel` "Device", `deviceListEmptyAgent` "create a device";
  - `deviceFieldOpenParameters` "Open parameters", `deviceFieldAlternate` "Alternate device", `deviceFieldPrompt` "Prompt";
  - the six type labels: `deviceTypeTerminal` "Terminal", `deviceTypeSpool` "Spooling device", `deviceTypeMagTape` "Magnetic tape drive", `deviceTypeCartridge` "Cartridge tape drive", `deviceTypeIpc` "Interprocess communication", `deviceTypeOther` "Other";
  - the three prompt labels: `devicePromptShow` "Show device prompt", `devicePromptAuto` "Use this device automatically when it is the current device", `devicePromptPredefined` "Use this device automatically with predefined settings".
- **Bundle.** If the initial total exceeds 1,261,000 B, re-base under DW-1166 (pre-approved): about 5% above the measured total, in `angular.json` and the `angular-json.test.mjs` pin together, citing the byte count in the commit.

#### Tests and rosters

- `Test/DeviceProbe.cls` (new helper): creates and removes `OcuPilotProbe88*` devices by exact name in `%SYS`, and asserts they are gone.
- `Test/DeviceCreate.cls`, `Test/DeviceUpdate.cls`, `Test/DeviceDelete.cls` (new, each under 500 lines, with a body-recording port subclass). They cover:
  - every matrix row on both callers, and one body from both callers;
  - the complete set on an update, and Alias and Prompt as integers or `""`;
  - the delete's fingerprint refusal after a change, its removal rows, and `VERIFIEDDELETES` refusing a 2xx that left the device (`PORT.NOTAPPLIED`).
- `Test/DeviceWire.cls` (new), armed on `OCUPILOT_ALLOW_PRINCIPALS` (add it to the arming roster in `scripts/ci-throwaway.sh` :206-226), through the real port:
  - The upsert fact: a raw `PUT` against a deleted name answers 201. The screen's edit and the agent's confirm both refuse first and create nothing.
  - A `^` in Description is refused and `iris.cpf` holds no probe line.
  - A purpose-built role holding exactly `DeviceForm`'s pairs creates, edits and deletes (AD-29: add any pair the instance still refuses to both descriptors' privileges).
  - A role lacking `%Admin_Manage` gets 403 on every device route.
  - Cleanup is by exact name.
- `device-form.store.spec.ts` and `device-form.page.spec.ts` (new).
- `ui/browser/device-editor.browser-spec.mjs` (new):
  - AC1: the nine fields in order.
  - AC2: a create shows on the list without a refresh, and an edit updates the row. The name cell opens the form.
  - AC5: a deep link without the resource.
  - AC6: the leave question.
- Rosters, own rows only:
  - ⚠ `Test/SurfaceCoverage`: the form and the three tools.
  - ⚠ `Test/EndpointCoverage`: four probe rows.
  - ⚠ `Test/ReadTool` :94: three tools and the count.
  - ⚠ `Test/ToolRoundTrip` :30: `REFUSEEMPTY`, three tools.
  - ⚠ `Test/PortFixture` :21 and ⚠ `Test/Prohibited` :193.
  - ⚠ `Test/Descriptor` :1743: DeviceList now declares Create.
  - The Needs-the-lead files.
  - `screen-mirror.test.mjs`, `app.routes.spec.ts` and `devices.browser-spec.mjs`, if they redden.

### Acceptance Criteria

- **AC1.** Given the device editor, when it renders, then it shows the classic device page's nine fields in classic order. The eight settable ones are derived from `FieldLists` `Device.Standard`, so `field-lists.mjs --check` and `DerivedFields` fail when the instance's template disagrees.
- **AC2 (Integration).** Given the Devices list is open (the change bus's consumer), when a device is created or edited by either caller, or deleted through the agent's confirmed `osmgmt.devices.delete`, then the list shows the change without a manual refresh.
  - The delete is declared destructive and names its target, which is what the proposal card's typed-name confirmation (Story 14.7) reads.
  - The screen's delete is ruled by the lead (Design Notes).
- **AC3.** Given a value breaks a matrix rule, when either caller saves, then the server refuses it on the field it names, and nothing reaches the vendor. The `^` and control-character rules are what keep `iris.cpf` valid.
- **AC4.** Given the `PUT` is an upsert, when a body is sent against a device deleted since the read, then both callers refuse first and no device is created.
- **AC5.** Given a user without `%Admin_Manage:USE`, when they open the form by any route, then the whole screen is the denial naming the pair, and every device route answers 403.
- **AC6.** Given the form holds a change, when any navigation leaves, the agent's included, then the shared leave question asks first.

## Spec Change Log

## Review Triage Log

## Design Notes

**Governing ADs:** AD-2, AD-3, AD-4, AD-5, AD-6, AD-8, AD-10, AD-13, AD-14, AD-29, AD-34, AD-36, AD-39, AD-44, AD-51, AD-52, AD-54, AD-55.

### What the instance settled

Sources:

- `%Api.Admin.Endpoints.Device.Standard`, read on `ocupilot-slot-b` with `GetTextAsString` (132 lines);
- `Config.Devices` in `irissys/`;
- the classic pages in `irislib/`;
- HTTP probes on `ocupilot-b-ci`. Nine probe devices were each removed by exact name; the list is back to its 12 stock devices, and `iris.cpf` holds no probe line.

Findings:

- **Endpoint.**
  - `ResourcesOR` is `%Admin_Manage`, and the query parameter is `name`.
  - It offers `LIST`, `GET`, `PUT` and `DELETE`. `POST` answers 405.
  - `GET` answers the eight fields with no `Name`, or 404 (#420) when the device is absent.
- **`PUT` is an upsert.** It answers 201 on a create and 200 on a modify, and it merges: a partial body keeps omitted fields, and `""` clears one.
  - On a create, `Type`, `PhysicalDevice` and `SubType` are required (#40301, 400).
  - An unknown key answers 400 (#40307).
  - `Config.Devices` datatype errors answer 500.
- **`DELETE`.** It answers 200 `{}`, or 404 when the device is absent. It does not refuse a device that another device names as its AlternateDevice.
- **The vendor accepts what the rules refuse.**
  - Type accepts any 2 to 3 characters (`ZZZ`, `trm`).
  - Alias 1.5 is silently stored as 1, and a duplicate Alias is accepted, although `Config.Devices` :57 says "All aliases must be unique".
  - A `^` in any field is written raw into `iris.cpf`'s `[Devices]` line, and `Config.CPF.Validate` then fails with #410. A name holding `=` produced `Name=H=...` (a re-read splitting it is (inference)).
  - These are field rules on the tool (AD-55: both callers inherit the write's own validation), not prohibitions.
- **The vendor enforces these.** The SubType must exist, Prompt is 1 to 2, Alias is at least 1, and the lengths hold (Name 64, Description 256, others 128). Alias must differ from PhysicalDevice (#424; the pair compared is (inference) from two cases). OpenParameters is parsed (#644).
- **The classic page.** Name is disabled on edit, SubType lists every subtype, and the defaults are OTH and P-DEC. The list page's delete asks "Are you sure you want to delete definition '%1'?".

### Decisions

- **The delete's fingerprint subject is all eight fields.** Configuration does not drift by itself, so any movement is somebody's edit. The card shows what is removed.
- **No AD-10 refusal applies.** OcuPilot creates and relies on no device; only `Install/Smoke.cls` :185 reads the list and expects it to be non-empty. Deleting a stock device such as `0`, `TERM` or `SPOOL` is permitted, as on the classic page, behind the destructive treatment.

### Pending the lead: the device delete on the screen

The 8.3 to 8.6 precedent put every list row action in a later story, because AD-53's row-action route and typed-name dialog exist only on Epic 7's branch. On this branch, `shell/` has no typed-name component, only its two strings (`strings.ts` :240/:242). The only dialog is `Dialog` (`dialog.ts`, which Epic 7 modifies). Epic 7 adds `typed-name-dialog.ts` and routes screen actions through `POST /screens/:screen/action` with the tool's `SCREENACTIONS`.

- **(a) A later story, as a ledger entry.** Recommended. Owner: the first story that runs after Epic 7 merges (the range-end cleanup unless a device story appears). It would add `rowActions [{"id":"delete"}]` on DeviceList, `SCREENACTIONS "delete"` on `DeviceDelete`, and entries in `SCREEN_ACTION_DESCRIPTORS` and `DESTRUCTIVE_CONSEQUENCES` (`screen-action-handler.ts`), with a consequence sentence published once (DW-1502 applies). This matches the classic page, where Delete is on the list.
- **(b) A Delete action inside the editor page.** A new AD-55 screen route (`DELETE /api/ocupilot/device/:id`) would resolve `DeviceDelete`, with a typed-name field inside the page's own `Dialog` using the two existing strings.
  - It needs no edit to Epic 7's files.
  - It builds a second typed-name implementation and a second screen-action route shape beside AD-53's, both of which the merge leaves to reconcile, and AD-53 is not on this branch to follow.
- **(c) Wait for Epic 7's merge and ship (a)'s work in this story.** This holds 8.8's commit, and so Epic 8's floor, behind Epic 7.

### Consumes and consumed-by

**Consumes:** 8.1's create kind, 8.5's action-style delete and removal rows, 8.3's `VERIFIEDDELETES`, Story 6.12's Devices list, Story 3.5's `FormDirty`, and the Epic 1 field-list derivation.

**Consumed-by:** the screen's device delete (pending the lead), and Story 14.7's typed-name field, which reads `DESTRUCTIVE`.

**Integration ACs:** AC2.

## Verification

Stateful checks run on slot B's throwaway `ocupilot-b-ci` (web 52777, super 1976). Nothing stateful runs on `ocupilot-slot-b`, and every IRIS MCP call carries `server: "ocupilot-slot-b"`. Run one test class per call, and wait until each run lands in `%UnitTest_Result` before sending the next.

### Targeted (loop)

- `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/` -- expected: the bundle under test is the one just built.
- `cd ui && OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci node --test --test-concurrency=1 browser/device-editor.browser-spec.mjs browser/devices.browser-spec.mjs` -- expected: all pass.
- `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class <C>`, one class per call -- expected: 0 failures each. Run it for:
  - `DeviceCreate`, `DeviceUpdate`, `DeviceDelete`, `DeviceWire`;
  - `Prohibited`, `ProhibitedRoute`, `ToolWrite`;
  - `SurfaceCoverage`, `EndpointCoverage`, `ReadTool`, `ToolRoundTrip`, `PortFixture`;
  - `Descriptor`, `DerivedFields`, `Wire`, `WireSecurityRead`.
- `cd ui && npm run test:tools && npm run test:components` -- expected: 0 failures.
- `cd ui && node tools/field-lists.mjs --check && node tools/screen-mirror.mjs --check && node tools/client-lint.mjs && node tools/browser-reset.mjs` -- expected: no drift.
- `uv run scripts/check-objectscript.py <changed paths>` and `bash scripts/lint-docs.sh` -- expected: clean.

### Once, before `dev_complete`

- The full ObjectScript sweep on a throwaway brought up after the last edit, one class at a time, with the totals checked against `%UnitTest_Result` -- expected: 0 failures and a non-zero count.
- `cd ui && npm run build && npm test` -- expected: green, with the initial total recorded.
- `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS` -- expected: all pass, with a non-zero count.
- The full browser suite is **not** run locally. CI's `browser` job runs it on a fresh throwaway (Rule 29; DW-1447).

### Pinning tests (Rule 19; the implementer records `mutation: <change> → <red test>` for each)

| AC | Pinning test | Mutation to demonstrate |
|---|---|---|
| AC1 | page spec field-order leg; `DerivedFields`; `field-lists.mjs --check` | the `Prompt` row dropped from `FieldLists` `Device.Standard` |
| AC2 | store spec publish legs; `DeviceDelete` change-event leg; browser list leg | `publish` dropped from the store's `save()` |
| AC3 | `DeviceCreate` rule cases; `DeviceWire` CPF leg | the `^` check removed from `DeviceRules.Validate` |
| AC4 | `DeviceUpdate` deleted-since leg; `DeviceWire` upsert leg | `HandleUpdate`'s fresh-read 404 check removed |
| AC5 | `DeviceWire` 403 leg; browser deep-link leg | `%Admin_Manage` dropped from `DeviceForm`'s privileges |
| AC6 | page spec dirty-leave leg | `change` not setting `FormDirty` |
| Verified delete | `DeviceDelete` not-applied leg | `Device.Standard/DELETE` removed from `VERIFIEDDELETES` |

## Auto Run Result

Status: ready-for-dev
Blocking condition: none

For the lead's ruling:

- The screen's device delete: options (a), (b) and (c) under Design Notes. (a) is recommended.
- The Needs-the-lead files in the Code Map.
