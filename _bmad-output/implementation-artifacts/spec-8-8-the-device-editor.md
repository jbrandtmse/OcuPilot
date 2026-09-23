---
title: 'Story 8.8: The device editor'
type: 'feature'
created: '2026-09-23'
status: 'done'
baseline_revision: 'd3c75c3b598b9c31982c853ec86441a7a6ad100f'
baseline_commit: '25147b1e2f01150ee9c52c4f8af998c6da690fde'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-8-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-8-5-x-509-import-edit-and-delete.md'
warnings: ['oversized']
deferred:
  - summary: >-
      The agent's osmgmt.devices.update cannot clear an alias or prompt the device holds: the mint's
      merge refuses an empty value against the fresh read's number. The screen's edit clears either.
    evidence: |-
      Kernel/Proposal/Mint.cls Merge types a scalar by the fresh read (SettableType, Representable);
      GET answers a set Alias/Prompt as a number. DeviceSave.Update reads them as text first. Mint.cls
      is never-edit for this story.
    location: >-
      src/OcuPilot/Kernel/Proposal/Mint.cls
    severity: low
  - summary: >-
      The browser AC2 list leg cannot see the device form store's change event: while the form is the
      open screen no list is bound to the bus, so the list reads on arrival whether or not Save published.
    evidence: |-
      RefreshService binds list-page alone and unbinds on its destroy; the toast store skips a change the open screen (the form, type device) shows.
      Mutation: the store's publish short-circuited, deployed main-LENNPPQ4.js -> device-editor browser spec 4 of 4 green.
      The publish is pinned by device-form.store.spec.ts's create and edit legs (observed red).
    location: >-
      ui/browser/device-editor.browser-spec.mjs
    severity: low
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

### Orchestrator ruling at the spec gate, 2026-09-23

- [ ] [Lead] **Screen delete, option (a).** Ship `osmgmt.devices.delete` (agent-only, destructive, verified) with a test that fails when its refusal of an unknown alias is removed. The Devices-list Delete row action is DW-1562 (range-end cleanup; it needs AD-53's route and typed-name dialog from Epic 7's merge); build no row action and no in-editor Delete here. `epics.md` 8.8 AC2 carries the `[AMENDED]` marker. The roster-rule files (`Test/Wire.cls`, `Test/WireSecurityRead.cls`, `navigation.test.mjs`, regenerated `screens.generated.ts`) are covered; the DW-1166 re-base is pre-approved if the bundle passes 1261kB.

### Orchestrator ruling on the implement halt, 2026-09-23 (work these first)

- [x] [Lead] **AD-8, option 1 (AD-8 amended by the lead; the one named case).** Keep the built design: the three device tools declare `%DB_IRISSYS:WRITE` beyond the screen's read-only set, refused by name before any port call. This supersedes the Tasks line that said to add the pair to both descriptors -- the descriptors keep their two read pairs and `Test/WireSecurityRead.cls` takes no principal change. Tests that fail when it is wrong: a principal holding only the screen's declared set gets 403 naming the pair on the screen's Save AND on the agent's confirm, with **no port call made** (assert on the port, not only the status); a principal that also holds `%DB_IRISSYS:WRITE` succeeds; the read-only Devices list still opens for a principal without it.
- [x] [Lead] **The two browser mutations that stayed green** (the deep-link leg; the list leg with the change-bus publish dropped). For each, rebuild and redeploy the bundle into `ocupilot-b-ci` with the mutation applied, and confirm the deployed bundle carries it before running the spec. Then either it reddens (the leg is load-bearing; record the row), or the leg truly cannot see that failure -- strengthen it until it can, or record in `## Verification` exactly why it is not load-bearing and put a `deferred:` entry for the lead. Never delete either leg.

### Acceptance Criteria

- **AC1.** Given the device editor, when it renders, then it shows the classic device page's nine fields in classic order. The eight settable ones are derived from `FieldLists` `Device.Standard`, so `field-lists.mjs --check` and `DerivedFields` fail when the instance's template disagrees.
- **AC2 (Integration).** Given the Devices list is open (the change bus's consumer), when a device is created or edited by either caller, or deleted through the agent's confirmed `osmgmt.devices.delete`, then the list shows the change without a manual refresh.
  - The delete is declared destructive and names its target, which is what the proposal card's typed-name confirmation (Story 14.7) reads.
  - The screen's delete is ruled by the lead (Design Notes).
- **AC3.** Given a value breaks a matrix rule, when either caller saves, then the server refuses it on the field it names, and nothing reaches the vendor. The `^` and control-character rules are what keep `iris.cpf` valid.
- **AC4.** Given the `PUT` is an upsert, when a body is sent against a device deleted since the read, then both callers refuse first and no device is created.
- **AC5.** Given a user without `%Admin_Manage:USE`, when they open the form by any route, then the whole screen is the denial naming the pair, and every device route answers 403.
- **AC6.** Given the form holds a change, when any navigation leaves, the agent's included, then the shared leave question asks first.

### Review Findings

Code review 2026-09-23 (review_tier full-opus; blind-hunter, edge-case-hunter, verification-gap, acceptance-auditor).

- [x] [Review][Patch] [medium] Alias is `type="number"`: text the browser cannot parse reads `""`, so an edit's Save silently clears the stored alias [ui/src/app/areas/os-management/device-form.page.ts:253]
- [x] [Review][Patch] [medium] The screen's refusal of an emptied PhysicalDevice/Type/SubType (`""`, what the screen's create sends) has no test; only the absent key is tested [src/OcuPilot/Test/DeviceCreate.cls:154]
- [x] [Review][Patch] [medium] No test holds the saved confirmation across the create's route replacement (`if (arriving) this.savedValue = true`) [ui/src/app/areas/os-management/device-form.store.ts:326]
- [x] [Review][Patch] [medium] AD-8 create leg: the recording port cannot see the rules' and the prohibited set's reads, so a write gate moved after them stays green [src/OcuPilot/Test/DeviceWriteGate.cls:117]
- [x] [Review][Patch] [medium] The edit route admits keys from `DeviceRules.FIELDS`, a hand-typed list no test ties to the tool's settable set (AD-55) [src/OcuPilot/Area/OsMgmt/DeviceSave.cls:176]
- [x] [Review][Patch] [low] `DeviceSave.Gate` requires `DeviceCreate`'s write pair for an edit too [src/OcuPilot/Area/OsMgmt/DeviceSave.cls:340]
- [x] [Review][Patch] [low] `wireValue` sends `"007"` as 7, which the server's rule refuses from the agent [ui/src/app/areas/os-management/device-form.store.ts:109]
- [x] [Review][Patch] [low] The edit's mapping of vendor error 644 to `DEVICE.OPENPARAMETERS.SHAPE` has no test [src/OcuPilot/Area/OsMgmt/DeviceSave.cls:214]
- [x] [Review][Patch] [low] A screen create carrying a key outside the eight has no test [src/OcuPilot/Area/OsMgmt/DeviceSave.cls:128]
- [x] [Review][Patch] [low] Doc claims that are false: agent "cannot propose what the screen would refuse"; Save refused "as the agent's create is at its mint"; DeviceList "the only descriptor that names this entity type"; delete "over the list's own pairs"; test environments naming `%Admin_Manage` alone [src/OcuPilot/Screen/Tool/DeviceCreate.cls:8]
- [x] [Review][Patch] [low] DeviceWire's writer principal read-back never checks `%DB_IRISSYS:WRITE`, and its delete confirm hard-codes `/api/ocupilot` [src/OcuPilot/Test/DeviceWire.cls:398]

Rejected:

- `low` Alias taken between mint and confirm is not re-checked: the confirm re-runs no rules, `Confirm.cls` is never-edit, and the window needs a concurrent alias edit.
- `low` A create with an unknown key answers 403 `UNCOVEREDFIELD`, an edit 400: the client never sends one; the test gap is the patch above.
- `low` A JSON-number `Name` reads as absent: the client sends text; the refusal is safe.
- `low` Alias and PhysicalDevice compared numerically (inference; the vendor's check is stripped from the export).
- `low` `HandleName` looks a name up without its shape rules: the same as `X509Rules.HandleName`; the client ignores a failed look-up and Save names the rule.
- `low` Create and the agent invitation show to a user without the write pair: AD-8's ruling keeps the screen's set read-only; the refusal names the pair and is rendered.
- `low` Stale roster messages in `Test/WireSecurityRead.cls` and `Test/Wire.cls`: Epic 7-modified assertion text, the settled `Descriptor.cls` precedent.
- `false` The refused create's banner reuses `deviceListEmptyAgent`: the project reuses a key whose value and meaning match.
- `low` The agent's update cannot clear an alias or prompt: DW-1571.
- `low` The screen's edit or create racing a delete or create inside one request: a millisecond window, no user-reachable repro.
- `low` A bad name returns only the name's violation: the prohibited set's reference needs a valid name, and blur shows it first.
- `low` Edits typed during an in-flight Save are marked clean: a sub-second window; the fix adds a branch.
- `low` A JSON boolean Alias or Prompt is accepted as 1: no caller sends one.
- `false` A vendor read that answers OK with no object reads as free: the port answers an object or an error.
- `low` `P-DEC` as the default subtype when an instance lacks it: the classic page's default.
- `low` Names with surrounding whitespace (inference).
- `low` `Prohibited.Device` clearing `pChanged` on a `DELETE` cannot redden: defensive, as `X509`.

## Spec Change Log

- 2026-09-23, lead (orchestrator ruling on the implement halt): AD-8 option 1 -- the device tools' extra `%DB_IRISSYS:WRITE` pair, written into AD-8 as its one named case; the two green browser mutations are to be re-run on a redeployed bundle. Status reset to `in-progress` with the implementation still uncommitted.

- 2026-09-23, spec gate: the screen's device delete went to DW-1562 (orchestrator ruling (a)); the agent delete ships here.

## Review Triage Log

### 2026-09-23 — Review pass

- verdicts: 16 findings — high 0, medium 6, low 7, false 3, maybe-false 0
- findings:
  - `[medium]` `[patch]` The sign-out test did not assert `DeviceForm`'s reset, as it does every sibling form's — seed and assertion added to `app.spec.ts` with its mutation row.
  - `[medium]` `[patch]` A Save refused 403 `AUTH.NOPRIVILEGE` naming `%DB_IRISSYS:WRITE` was never rendered in a client test — page spec leg added in both modes, with its mutation row.
  - `[low]` `[patch]` AC2's and AC4's agent halves had no `mutation:` row — `CHANGEACTION` blanked and the confirm's fingerprint refusal disabled (container only), each observed red, rows added.
  - `[medium]` `[patch]` The agent half of the unparsable-open-parameters row had no test — `DeviceCreate.TestUnparsableOpenParametersFailTheAgentsConfirm` added: the confirm fails with no vendor text, one refused PUT, no device.
  - `[low]` `[patch]` An edit's refused Save read "to create a device" — `deviceFormRefusedAction` "change this device" added (strings and Fixed strings row) and used in edit mode.
  - `[medium]` `[patch]` Agent side of the unparsable open parameters untested (same root as the row above) — covered by the same new test.
  - `[medium]` `[patch]` The agent delete's "deleted since" 409 was untested — `DeviceDelete.TestADeviceDeletedSinceTheMintRefusesTheConfirm` added, asserting no `DELETE` reaches the port.
  - `[low]` `[patch]` The list's reaction to the agent's confirms is checked only through the change action (same root as the missing agent-half mutation rows) — rows added; the browser list leg's limit was already in `deferred:`.
  - `[low]` `[patch]` The server's one-body test sent seven fields, not the matrix's eight — `AlternateDevice` added and all eight asserted at the port from both callers.
  - `[false]` `[reject]` The screen and agent keep separate code paths — the spec's Tasks prescribe `DeviceSave` on the `X509Save` template; the one-body test pins the shared result.
  - `[low]` `[reject]` No test drives an agent navigation against a dirty device form — the shared `FormDirty` leave guard answers agent navigation for every form; the page spec pins that `change` sets it.
  - `[false]` `[reject]` An object or array value is refused `PORT.FIELD.SHAPE`, not `DEVICE.*` — the matrix's field rules cover scalar values only; non-scalar shapes are the shared port refusal.
  - `[low]` `[reject]` Rule text repeated in the agent schema descriptions, and an inline delete problem sentence — the descriptions are model-facing input docs, not refusal sentences; the inline one fires only if the vendor omits `PhysicalDevice`, as in `X509Delete`.
  - `[medium]` `[patch]` Client rendering of the write-pair refusal untested (same root as the second row) — covered by the same page spec leg.
  - `[false]` `[reject]` `PROPERTYFAULTS` is a general port mechanism beyond the lists — the spec's Code Map names `AdminPort.Fail` as where vendor error 644 is mapped; not AD-27 completion.
  - `[low]` `[reject]` `Test/Descriptor.cls`'s DeviceList message "no other screen names this entity type" is stale now that `DeviceForm` declares `device` — message text in an Epic 7-modified contended file, where the roster rule forbids changing an assertion.

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

Observed. Each ObjectScript mutation was loaded into `ocupilot-b-ci` from a scratch copy with `cbk-d` and reverted by reloading the working file; each client mutation was reverted from a byte copy, and `git diff` was empty afterwards.

- mutation: the `Prompt` row dropped from `FieldLists` `Device.Standard` → `DerivedFields` red on both regeneration tests (run 259), and `field-lists.mjs --check` refuses both device entries (AC1)
- mutation: the Alias block moved above Description in the page template → `device-form.page.spec.ts` AC1 red (AC1)
- mutation: `publish` dropped from the store's `save()` → `device-form.store.spec.ts` create and edit legs red (AC2); not observed on the browser list leg, which reads the list on arrival
- mutation: the `^` test dropped from `DeviceRules.Writable` → `DeviceCreate.TestEveryFieldRuleRefusesOnBothCallers` red on every `^` case (run 243) and `DeviceWire.TestACaretIsRefusedAndTheConfigurationFileStaysValid` red, `Config.CPF.Validate` failing (run 244); the file validated again after cleanup (AC3)
- mutation: the type-value rule disabled → `DeviceCreate` red on `ZZZ` and `trm` (run 245); the alias-taken rule disabled → red on the duplicate (run 246); a fraction admitted by `WholeNumber` → red on `1.5` (run 247) (AD-55 rules)
- mutation: `DeviceSave.Update` ignoring a fresh read that finds no device → `DeviceUpdate.TestADeletedDeviceIsRefusedAndNotRecreated` red (run 248) and `DeviceWire`'s envelope and upsert legs red (run 249) (AC4)
- mutation: `%Admin_Manage` dropped from `DeviceForm`'s privileges → `DeviceWire.TestACallerWithoutTheManageResourceIsRefusedOnEveryRoute` red (run 250) (AC5)
- mutation: the store's `change` clearing `FormDirty` → `device-form.page.spec.ts` AC6 red (AC6)
- mutation: `Device.Standard/DELETE` removed from `VERIFIEDDELETES` → `DeviceDelete.TestAReportedDeleteThatLeftTheDeviceIsNotApplied` red (run 251) (verified delete)
- mutation: `Mint.Mint`'s refusal of an absent target removed, in the container only → `DeviceDelete.TestAnUnknownNameIsRefusedAtTheMint` red (run 252) (the delete's unknown-name refusal)
- mutation: `DeviceRules.Shape` a no-op → `DeviceCreate.TestACreateSendsOneBodyFromBothCallers` red on the JSON types (run 253) (value shapes)
- mutation: `AdminPort.PROPERTYFAULTS` emptied → `DeviceCreate.TestUnparsableOpenParametersAreRefusedOnTheirField` red (run 254) (open parameters row)
- mutation: `DeviceDelete.FINGERPRINTSUBJECT` narrowed to `PhysicalDevice` → `TestADeviceChangedSinceTheMintRefusesTheConfirm` red (run 255)
- mutation: `DeviceSave.Update` validating the whole body → `DeviceUpdate.TestTheRulesReadOnlyTheFieldsAnEditChanges` red (run 256); composing instead of `Mint.Merge` → `TestAnEditSendsTheCompleteSetOnBothCallers` red (run 257) (Always: changed fields only; complete set)
- mutation: `DeviceSave.Gate` skipping the write pair → `DeviceWire.TestTheFormsPairsAloneReadButCannotSave` red, the Save answering 500 (run 258) (AD-29)
- mutation (one rebuilt, redeployed bundle): the route replacement dropped and `change` clearing `FormDirty` → browser AC2 and AC6 red, AC1 and AC5 green; the restored bundle 6 of 6 green
- mutation: `DeviceSave.Gate` skipping the write pair → `DeviceWriteGate.TestTheScreensPairsAloneAreRefusedTheWriteBeforeAnyPortCall` red on the screen's create and edit legs alone, each reaching the recording port (run 206) (AD-8, screen Save)
- mutation: the write pair dropped from `PrivilegePairs` in `DeviceCreate`, `DeviceUpdate` and `DeviceDelete` → the same test red on the three confirm legs alone (run 207) (AD-8, agent confirm)
- mutation: `%DB_IRISSYS:WRITE` added to `DeviceList`'s privileges → `DeviceWriteGate.TestTheDevicesListStillOpensWithoutTheWritePair` red, the list read 403 naming the pair (run 208) (AD-8, read-only list)
- mutation: the three tools' `WRITERESOURCE`/`WRITEPERMISSION` set to `%Admin_Secure`/`USE` → `DeviceWriteGate.TestTheWritePairAddedLetsBothCallersWrite` red on all five legs (run 209); restored green (run 210) (AD-8, write pair suffices)
- mutation (redeployed `main-MSPPWKHD.js`, whose deployed device-form mirror entry reads `privileges:[{resource:"%DB_IRISSYS",permission:"READ"}]`; `DeviceForm.cls` loaded with the same change): `%Admin_Manage` dropped from `DeviceForm`'s privileges → browser AC5 red, the screen-wide denial never rendering, AC1, AC2 and AC6 green; the restored bundle (`main-AT5FVDOS.js`) 4 of 4 green (AC5)
- mutation (redeployed `main-LENNPPQ4.js`, whose deployed device store reads `publish(t,e){t===""||t!==""||...}`): `publish` short-circuited in the store's `save()` → browser AC2 green, 4 of 4, not load-bearing for the event (ledgered in `deferred:`); the restored bundle 4 of 4 green (AC2)
- mutation: `this.deviceForm.reset()` deleted from `App.verifyWhenSignedIn` → `app.spec.ts` sign-out test red on the device form's typed name (sign-out teardown)
- mutation: `rememberRefusal` reading `detail.missingPair` → `device-form.page.spec.ts` write-pair refusal leg red, the banner reading the envelope's reason; the create's action resolved in both modes → the same leg red on the edit's banner (AD-8, client)
- mutation (container only): `DeviceRules.Shape` dropping `AlternateDevice` → `DeviceCreate.TestACreateSendsOneBodyFromBothCallers` red on both callers' bodies and the stored alternate (run 216) (eight fields)
- mutation (container only): `AdminPort.Fail` answering the vendor's error text as the fault code → `DeviceCreate.TestUnparsableOpenParametersFailTheAgentsConfirm` red alone (run 217) (open parameters row, agent)
- mutation (container only): `Confirm`'s `If 'tMatches` refusal disabled → `DeviceDelete.TestADeviceDeletedSinceTheMintRefusesTheConfirm` red, a `DELETE` reaching the port, and `TestADeviceChangedSinceTheMintRefusesTheConfirm` red (run 218); `DeviceUpdate.TestADeletedDeviceIsRefusedAndNotRecreated` red, the upsert re-creating the device (run 219) (AC4 agent half; agent delete deleted-since)
- mutation (container only): `CHANGEACTION` blanked in the three device tools → `DeviceDelete.TestTheCardListsWhatGoesAndAConfirmDeletes` red on `deleted` (run 220), `DeviceCreate.TestACreateSendsOneBodyFromBothCallers` red on `created` (run 221), `DeviceUpdate.TestAnEditSendsTheCompleteSetOnBothCallers` red on `updated` (run 222); restored green (runs 223-225) (AC2 agent half)
- mutation (QA gap check, container only): the orchestrator's three named gaps re-verified live rather than trusted from the rows above. `DeviceRules.Validate`'s `Type` value check removed → `DeviceCreate.TestEveryFieldRuleRefusesOnBothCallers` red on cases 10 (`ZZZ`) and 11 (`trm`), each failing both the screen assertion ("the screen refuses it on Type") and the agent-mint assertion ("with the field's own sentence") in the same run (run 210); restored green (run 211, `git diff` empty). This is the same shared loop and the same `DeviceRules.Validate` call the `^`, duplicate-`Alias` (case 24) and fractional-`Alias` (case 21) cases run through, so all four rules the orchestrator named are confirmed refused on both callers, not just one. `DeviceDelete.TestAnUnknownNameIsRefusedAtTheMint` (the agent delete's refusal of a name the instance does not hold) and every Device* class's `OnAfterOneTest` `CpfValid` assertion (`DeviceCreate`, `DeviceUpdate`, `DeviceDelete`, `DeviceWire`) were re-run fresh (runs 208, 209, 212, 213, all green) and `Config.CPF.Validate()` confirmed clean directly against `ocupilot-b-ci` with no probe line. No gap found in the three items named at the QA gate; no new test needed.
- mutation (code review): the Alias input made `type="number"` again → `device-form.page.spec.ts` alias leg red, `12e` read as `''`; `wireValue` admitting a leading zero → the store spec's value-shapes leg red on `007`; `if (arriving) this.savedValue = true` dropped → the store spec's create-lands-saved leg red
- mutation (code review, container only): the PhysicalDevice `""` REQUIRED arm disabled → `DeviceCreate.TestEveryFieldRuleRefusesOnBothCallers` red on case 7 on both callers (run 219); `DeviceSave.Create` asking the set over `{}` → `TestAScreenCreateCarryingAnotherKeyIsRefused` red alone (run 221); `DeviceSave.Update`'s `PortViolations` dropped → `DeviceUpdate.TestUnparsableOpenParametersAreRefusedOnTheirFieldOnAnEdit` red alone (run 222); the name's rule run before the gate in `HandleCreate` → `DeviceWriteGate`'s bad-name leg red alone (run 223); `Prompt` dropped from `DeviceRules.FIELDS` → `TestTheSchemaAndTheSettableSetAreTheSets` red on the rules-set assertion (run 224); restored green (runs 225-227)

## Auto Run Result

Status: done
Blocking condition: none

- **Change.** The device editor (Story 8.8): `DeviceRules` and `DeviceSave` screen routes, `osmgmt.devices.create`/`.update`/`.delete`, `DeviceForm` and the list's Create, the `DEVICE.*` codes, the port lists and `PROPERTYFAULTS`, the prohibited-set `device` type, the client store, page and Create handler, and their tests. Implemented in the first pass; this pass worked the two halt-ruling items, the review layers and finalize.
- **Halt-ruling items.** AD-8: `Test/DeviceWriteGate.cls` (with `DeviceWriteGateProbe`) runs the screen's Save and the agent's confirm as real principals in a child process; with the screen's pairs alone every leg answers 403 naming `%DB_IRISSYS:WRITE` and the recording port sees no call, reads included; with the pair every leg writes; the Devices list opens without it. Browser: the deep-link leg reddened on a redeployed mutated bundle; the list leg cannot see the store's publish (recorded in `## Verification` and `deferred:`).
- **Review.** 16 findings: 10 patched in 6 entries (4 medium, 2 low), 6 rejected with reasons in the triage log, none deferred. Patches: the device form's sign-out reset asserted; the write-pair refusal rendered in both modes with a new `deviceFormRefusedAction`; agent legs for unparsable open parameters and delete-after-delete; all eight fields in the one-body test; the missing agent-half mutation rows. Follow-up review: `false` (every patch is a test or a string choice, each observed red under its mutation, and the sweep ran after the last edit).
- **Verification**, after the last edit, on a throwaway brought up fresh: the full ObjectScript sweep 205 classes, 1809 tests, 0 failed (`%UnitTest_Result`: 1809 passed, 0 failed, 205 classes); `npm run build` green, initial total 1,248,521 B (under 1,261,000; no re-base); `npm test` 1326 tools tests and 919 component tests green; `scripts/smoke.sh` 47 of 47; the two device browser specs 6 of 6 on the deployed build; `lint-docs` clean; `iris.cpf` validates and names no probe device.
- **Residual risk.** The agent's update cannot clear a set Alias or Prompt, and the browser list leg cannot observe the store's change event (both in `deferred:`).

footprint_extensions: contended `src/OcuPilot/Kernel/Proposal/Prohibited.cls`, `src/OcuPilot/Api/Router.cls`, `src/OcuPilot/Screen/Tool/Classification.cls` (tail append), `src/OcuPilot/Screen/Tool/ToolFields.cls` (regenerated), `src/OcuPilot/Test/{SurfaceCoverage,EndpointCoverage,ReadTool,ToolRoundTrip,PortFixture,Prohibited,Descriptor}.cls`, `ui/src/app/shell/screen-outlet.ts` (one entry, one import); shared-append `src/OcuPilot/Port/AdminPort.cls` (three list lines, `PROPERTYFAULTS` and its method, and one call line in `Fail`), `ui/src/app/core/strings.ts`, EXPERIENCE.md Fixed strings rows 417-421; in Epic 7's diff, roster rule: `src/OcuPilot/Test/Wire.cls` and `src/OcuPilot/Test/WireSecurityRead.cls` (the form route in the os-management rosters), `ui/tools/navigation.test.mjs` (one route), `ui/src/app/core/screens.generated.ts` (regenerated); outside both: `ui/src/app/app.ts` (one injection pair, one reset), `ui/src/app/app.spec.ts` (the device form's sign-out reset), `scripts/ci-throwaway.sh` (arming roster), `src/OcuPilot/Test/Navigation.cls` (the os-management payload roster); this story's own new tests `src/OcuPilot/Test/DeviceWriteGate.cls` and `DeviceWriteGateProbe.cls`.
