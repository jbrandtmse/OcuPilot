---
title: 'The devices list'
type: 'feature'
created: '2026-09-17'
status: 'ready-for-dev'
baseline_revision: 'd2396f844eae4992e328d6878264026358af08e4'
baseline_commit: 'd2396f844eae4992e328d6878264026358af08e4'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-6-context.md'
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** OS management's side bar names Devices as its fifth entry (`EXPERIENCE.md:164`, `:99`) and nothing serves it, so FR-59's list half has no screen (`epics.md` Story 6.12).

**Approach:** One hand-written `list` descriptor over one bounded `admin` `LIST` read on `%Api.Admin.Endpoints.Device.Standard`, six columns, instance-scoped. No new grammar, no page or store file (`ListPage` renders it), no action of any kind — the editor is Story 8.8.

## Boundaries & Constraints

**Always:**

- **`OcuPilot.Screen.Descriptor.DeviceList`** — one `XData Declaration`, no method overrides, key order cloned from `LockList.cls:43-90`:
  - route `os-management/devices`, area `os-management`, `labelKey` `deviceListLabel`, `sideBarPosition` **5** (Processes 1, Locks 2, System usage 3, Databases 4), archetype `list`, `built` true
  - `entityType` `"device"` — **already the 23rd value of the closed vocabulary** (`Kernel/EntityType.cls:28`) and already mirrored (`screens.generated.ts:13`, `:402`): **no `Kernel/` edit, no `EntityType.Count()` change**. `secondaryEntityTypes` `[]`, `scope` `instance`, `parentScope` `""`
  - `id` `{"kind": "single", "parts": []}` — the row key is the `name` column's field, `Name` (`core/table-model.ts:44`), as on every name-keyed list
  - `refreshes` false, `refreshRates` `[]` — not among AD-43's seven
  - `privileges` `%Admin_Manage:USE` then `%DB_IRISSYS:READ`, extended only by what a real least-privileged principal still refuses (AD-29, Execution 7)
  - `primaryAction` `{"id": "", "selfProtection": ""}`, `rowActions` `[]`
  - `emptyStateKey` `deviceListEmpty`; `table.emptyNextKey` `tableReadOnlyEmptyNext` (reused), `table.emptyAgentKey` `""`
  - `commandAliases` `["devices", "device settings"]` (neither collides); `toolIdentifier` `osmgmt.devices`
  - `classicPage` `%CSP.UI.Portal.Config.Devices` — `NormalizePage("/csp/sys/mgr/%CSP.UI.Portal.Config.Devices.zen")` answers that bare class name on slot B, and the page's own `Parameter RESOURCE` is `%Admin_Manage` (`irissys/%CSP/UI/Portal/Config/Devices.cls:22`), which AD-44 unions into the gate. `classicLinkExemption.exempt` false, empty `reason`/`label`/`href`
  - `context.fields` = the six read fields; `context.secretFields` `[]`
  - **no `rowTarget`** — the key is optional and `LockList` is its only declarer, so DW-1078 does not reach this screen
- **Read** — `source` `{"port": "admin", "endpoint": "Device.Standard", "type": "LIST"}`, `paging` `"cap"`; no `criteria`, `rowGet`, `query`, `parts`, `forEach` or `ns`. `fields` exactly six: `Name`, `PhysicalDevice`, `Type`, `SubType`, `Description`, `Alias`. `filter` and `sort.fields` the same six; `sort.default` `"Name"`, `direction` `"asc"`.
- **Table** — six columns, exactly one `name` kind (`Registry.cls:1780`): `Name`/`tableColumnName`/`name` · `PhysicalDevice`/`deviceColumnPhysical`/`identifier` · `Type`/`tableColumnType`/`text` · `SubType`/`deviceColumnSubtype`/`text` · `Description`/`tableColumnDescription`/`text` · `Alias`/`x509ColumnAlias`/`number` (an integer alternate id, as `VolumeNumber` is at `DatabaseVolumeList.cls:95`). No `emptyKey`: an empty `Alias` or `Description` means absent, which "(none)" already says.
- **Four new `strings.ts` keys only** — `deviceListLabel`, `deviceColumnPhysical`, `deviceColumnSubtype`, `deviceListEmpty`, each citing `EXPERIENCE.md:366`, after `:947`. `Name`, `Type`, `Description` and `Alias` **reuse** `tableColumnName`, `tableColumnType`, `tableColumnDescription` and `x509ColumnAlias` (`strings.ts:602`); values are unique table-wide, so a fifth key holding `'Alias'` reddens `strings.test.mjs`.
- **Additive only** on the Epic 4-shared files this story touches: `Install/Smoke.cls`, `Test/Descriptor.cls`, `ui/src/app/core/strings.ts`. `screens.generated.ts` is **regenerated** (`node tools/screen-mirror.mjs` from `ui/`), never hand-merged.

**Never:**

- **No new declaration grammar.** Every key already exists and already validates; a refusal sentence, a corpus case or a `DECLARATION_KEYS` edit in this story means the descriptor drifted from the ten before it.
- **No `Device.Settings`, no `Device.SubType`.** The first answers Telnet and IO settings, not devices; the second is a separate collection. Neither is declared.
- **No `AdminPort` edit.** `ResourcesOR()` returns `$LISTBUILD("%Admin_Manage")` and the backing query `Config.Devices:List` (`irissys/Config/Devices.cls:146`) carries no privilege check of its own, so `QUERYPAIRS` (`AdminPort.cls:134`) gains nothing. `LIST` is in `TYPESUFFIXES` (`:105`) and a dotted endpoint name resolves against `ENDPOINTPACKAGE` (`:51`) as `Database.SysCRUD` does.
- **No `Screen/Area.cls:114` union change** — it already carries both pairs. Only its class comment's false-denial count (`:57-69`) is corrected.
- **No seventh column.** `Prompt`, `OpenParameters` and `AlternateDevice` are Story 8.8's editor fields, and `Prompt` and `AlternateDevice` are empty on every row of a stock instance.
- No auto-refresh, meter, `rowTarget`, `parentScope`, page or store file, `DESCRIPTOR_PAGES` entry; no planning-artifact edit, no `Kernel/**`, `Port/ProviderPort.cls`, `Screen/Tool/**`, `scripts/check-objectscript.py`, `ui/src/app/app.ts`, `ui/src/app/shell/panel/**`, `ui/package.json`, `angular.json` or `README.md`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| List loads | Stock instance, both pairs held | Six columns; one row per device (12 on slot B); real values on `Name`, `PhysicalDevice`, `Type`, `SubType`, `Description`; `Alias` empty on all 12 | None expected |
| Two namespaces, one answer | `ns=HSCUSTOM` then `ns=USER` | Byte-identical rows — the read takes no `ns`, devices are CPF configuration | None expected |
| Pipe-bracketed name | Row `\|TRM\|` | Name cell reads `\|TRM\|` literally and links to the list's own id route, re-rendering with that row active — the `?? screen` fallback Roles, Resources and Services already take (`data-table.spec.ts:178-201`) | None expected |
| Empty `Alias` | Every stock device | "(none)" in the muted treatment, column still right-aligned | Not an error |
| No devices | A CPF with none | "No devices on this instance." + the read-only second line, **no agent invitation** | Not an error state |
| Missing `%Admin_Manage:USE` | Real least-privileged principal | Title plus "You need %Admin_Manage:USE to open Devices."; no table, no read | Gate names the first unheld pair; never 500, never an empty state |
| `%Admin_Manage:USE` only | Principal without `%DB_IRISSYS:READ` | Denial names `%DB_IRISSYS:READ`, or the read is served and the declared set is corrected **at its origin** to what the instance refuses (AD-29) | As above |
| Vendor fault | Non-2xx from the endpoint | `AdminPort` named fault, one envelope; rows already on screen stay | AD-12 / AD-39 |
| Read tool | `osmgmt.devices.read` | Same six fields, filter and sort, narrowed by AD-24's cap, no secret fields | AD-36 |

</intent-contract>

## Code Map

Server:

- `Screen/Descriptor/DeviceList.cls` — **new**; clone `LockList.cls:43-90`, header in the shape of `LockList.cls:1-39`.
- `Screen/Descriptor/DatabaseList.cls:4` — says "between System usage and the unbuilt Devices". Correct that sentence; do not append to it.
- `Screen/Area.cls:57-69` — the false-denial count in the class comment ("5 of 8 …") gains this screen; `:114` unchanged.
- `Install/Smoke.cls` — four literals that move **together** or `Test/Smoke.cls` reddens: `Parameter DEVICELISTTOOL = "osmgmt.devices";` after `:172`; `,devices` appended to the name list at `:621` (264 → 272 chars, against the 300-char read window at `Test/Smoke.cls:630`); `For tI = 1:1:25` at `:620` → `26`; arm `tI = 26: ..#DEVICELISTTOOL` at `:625`. `Test/Smoke.cls:615` derives its counts from that list and needs **no** literal edit.
- `Test/Navigation.cls:331-351` — roster pinned by literal index **and** count: `:334`'s `8` → **9**, plus one route/labelKey pair at index **8**. Indices 0-7 are unchanged (collation is `sideBarPosition` then descriptor class name, so position 5 sorts last).
- `Test/Wire.cls:680` — the fourth literal copy of the os-management `screens` array, one JSON string.
- `Test/ReadTool.cls:94` and `:100` — the two literal `.read` rosters (34 → 35 each); `osmgmt.devices.read` / `OcuPilot.Screen.Descriptor.DeviceList` after `osmgmt.databasevolumes.read`.
- `Test/Descriptor.cls` — one method after `:1432` pinning six fields and six columns exactly (`:1273` is the Locks model).
- `Test/WireSecurityRead.cls` — one method after `:736`, patterned on `:600` and `:710`; if it needs a principal the fixture lacks, the "thirteen principals" setup and its assertion string change with it.
- `Test/ScreenRead.cls:189` — **self-discovering** over `Registry.Descriptors()`; add no exclusion. One live-value method after `:755`.
- Untouched by design: `Port/AdminPort.cls`, `Screen/Read.cls`, `Screen/Registry.cls`, `Screen/Descriptor/Base.cls`, `Kernel/EntityType.cls`, `Install/Installer.cls`.

Client:

- `core/strings.ts` — four keys after `:947`, before the `:949` comment. `core/screens.generated.ts` — regenerated.
- `tools/navigation.test.mjs:138` — append `'os-management/devices'`.
- `tools/navigation-wire.test.mjs:144` and `src/app/shell/rail-wire.spec.ts:140` — append `{route: 'os-management/devices', labelKey: 'deviceListLabel', sideBarPosition: 5, allowed: false, failedPair: '%Admin_Manage:USE'}` to each `LIVE_PAYLOAD`. **Neither reddens alone.**
- `browser/devices.browser-spec.mjs` — **new**, registered by filename alone; `browser/locks.browser-spec.mjs` (138 lines) is the model, helpers in `browser/list-spec.mjs`.
- `browser/screen-height.browser-spec.mjs:54` — append one `SCREENS` line for `/ocupilot/os-management/devices?ns=HSCUSTOM` (`viewport: 'cdk-virtual-scroll-viewport'`, `prepare: null`).
- `tools/strings.test.mjs:346` — the bound is already **520**, raised by Story 6.11 to cover 6.12 through 6.14 (`:340-344`). The table holds 447 literals and `strings.ts` 462 keys; this story spends **4**, reaching 451 and 466. **No band change.**
- Unaffected: `tools/classic-links.mjs`, `tools/field-lists.mjs`, `tools/ipm-manifest.mjs` (regenerate only), `src/app/areas/os-management/`, `src/app/shell/data-table.ts`.

Vendor, read-only reference:

- `%Api.Admin.Endpoints.Device.Standard` — `[ Hidden ]`, so **absent from the `irissys/` export**; read it from slot B with `iris_doc_get`. `ResourcesOR()` = `%Admin_Manage`. `RunList` runs `%Api.Admin.Util.ClassQuery` over `Config.Devices:List`, optionally filtered by a `names` parameter this read does not send. Implements `LIST`, `GET`, `PUT`, `DELETE` — no `INFO` or `CERTINFO`, so no `rowGet` exists to declare. Already inventoried at `Test/AdminInventory.cls:50`, field list already derived at `Screen/Tool/FieldLists.cls:50`.
- `irissys/Config/Devices.cls:146` — the `List` `ROWSPEC`, nine columns: `Name`, `PhysicalDevice`, `Type`, `SubType`, `Prompt`, `OpenParameters`, `AlternateDevice`, `Description`, `Alias`. Storage `DataLocation` is `^|"^^"_$ZU(12)|SYS("CONFIG")` — the manager directory's database — which is the evidence for declaring `%DB_IRISSYS:READ`.
- Slot B, 2026-09-17, through `AdminPort.Invoke("Device.Standard","LIST",…)`: HTTP 200, 12 rows, all nine keys on each. Real on every row: `Name` (`0`, `2`, `47`, `48`, `57`, `58`, `SPOOL`, `TERM`, `|LAT|`, `|PRN|`, `|TNT|`, `|TRM|`), `PhysicalDevice`, `Type` (`TRM`, `SPL`, `MT`, `BT`, `OTH`), `SubType` (`C-IRIS Terminal`, `PK-DEC`, `M/UX`, `C-VT220`, `P-DEC`), `Description`. Empty on every row: `Prompt`, `AlternateDevice`, `Alias`. Real on 6 of 12: `OpenParameters`.

## Tasks & Acceptance

**Execution:**

1. **Fixed strings row, applied by the lead before this spec was dispatched.** `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md:366` carries the Devices row verbatim, after the Databases row. Implement edits no planning artifact; it reads that row as the authority for the four new strings, and `strings.test.mjs` re-derives its authorized set from it.
2. `Screen/Descriptor/DeviceList.cls` — write the declaration per Boundaries. The descriptor is the source of route, gate, read, tool and navigation entry (AD-5), so everything downstream follows from this one file.
3. `core/strings.ts` — the four keys with their citations; then regenerate the mirror.
4. `Install/Smoke.cls` — all four edits in one pass; the three literals cross-check each other.
5. The six roster literals (`Test/Navigation.cls`, `Test/Wire.cls`, `Test/ReadTool.cls`, `tools/navigation.test.mjs`, `tools/navigation-wire.test.mjs`, `shell/rail-wire.spec.ts`). `Navigation.cls` went red in CI on 6.9 and again on 6.10; the two `LIVE_PAYLOAD` copies never redden alone.
6. The new tests: `Test/Descriptor.cls`, `Test/ScreenRead.cls`, `browser/devices.browser-spec.mjs`, `browser/screen-height.browser-spec.mjs`.
7. **Establish the pair set, do not copy it** (AD-29). On the throwaway, run `osmgmt.devices.read` as a real least-privileged principal — never `%Operator`, which carries `%DB_IRISSYS:RW` — and append whatever the instance still refuses beyond the two declared, correcting the declaration at its origin rather than annotating it. Add the `Test/WireSecurityRead.cls` method in the same pass.
8. Correct the two prose claims this screen falsifies: `DatabaseList.cls:4` and `Screen/Area.cls:57-69`.

**Acceptance Criteria:**

- **AC1** — Given the new descriptor, when `Registry.Validate` and `screen-mirror.mjs --check` run, then both accept it with no new refusal rule, and the os-management area answers **nine** built screens with `os-management/devices` / `deviceListLabel` at index 8, position 5. Pinned by `Test/Navigation.cls:334` and the new index assertions.
- **AC2** — Given the throwaway, when the declared read executes, then it answers the six declared fields with **real values** on `Name`, `PhysicalDevice`, `Type`, `SubType` and `Description` — not null-filled keys — and reports no truncation at the default cap. Pinned by the new `Test/ScreenRead.cls` method.
- **AC3** — Given `osmgmt.devices.read`, when it is invoked, then it answers the same six fields, filter and sort as the screen, narrowed by AD-24's context cap, with no field the descriptor did not declare. Pinned by `Test/ReadTool.cls`'s rosters plus its sweep at `:154`.
- **AC4** — Given a real least-privileged principal holding neither declared pair, when it issues the read over HTTP, then the refusal names the first pair it lacks and is neither a 500 nor an empty state; a principal holding the full set is served. Pinned by the new `Test/WireSecurityRead.cls` method.
- **AC5** — Given the descriptor, when the screen renders, then it offers **no primary action, no row action and no outbound classic link**: `primaryAction.id` and `rowActions` empty, `classicLinkExemption.exempt` false, and `classic-links.mjs` reports no exemption for it. Pinned by the new `Test/Descriptor.cls` method and `classic-links.mjs` in `prebuild`.
- **AC6** — Given `EXPERIENCE.md`'s Devices row, when `npm test` runs, then `strings.test.mjs` finds exact set equality with exactly four new keys, all values unique, `Alias` served by `x509ColumnAlias`, and the empty state reading "No devices on this instance." above the read-only second line with **no** agent invitation.
- **AC7** — Given the rebuilt bundle deployed to the throwaway, when a browser opens `/ocupilot/os-management/devices?ns=HSCUSTOM`, then the six declared headers render in declared order, one row per device appears, the `|TRM|` name cell reads that text literally, and the rows fit the viewport without the footer overpainting them. Pinned by `browser/devices.browser-spec.mjs` and the new `screen-height.browser-spec.mjs` entry.

## Spec Change Log

## Review Triage Log

## Design Notes

**Governing ADs:** AD-2, AD-5, AD-13, AD-24, AD-27, AD-29, AD-36, AD-43 (Devices is not on the roster of seven), AD-44.

**Integration ACs (Rule 1):** this story introduces no service, module or shared component — it adds a descriptor to an existing registry. In-story consumers: the derived read tool (AC3) and `Install/Smoke`'s live per-list check (Execution 4). **Consumes:** Epic 2's `AdminPort` synchronous path, declared read, `ListPage`, command bar and gate; Story 6.10's `LockList` as the declaration model. **Consumed-by:** Story 8.8 (device editor — create, edit and delete over `Device.Standard`, pairing `os-management/devices/edit` to this route).

**Why `%CSP.UI.Portal.Config.Devices` and not `%CSP.UI.Portal.Devices`:** the latter does not exist on this build (`%ExistsId` reads 0). The former is the Zen list page whose own `queryClass`/`queryName` is the same `Config.Devices:List` this read calls, and `EXPERIENCE.md:100` names its sibling `%CSP.UI.Portal.Config.Device` as Story 8.8's editor.

## Verification

**Commands:**

- `uv run scripts/check-objectscript.py src/OcuPilot` — 0 problems.
- One `iris_execute_tests` call **per class**, `server: "ocupilot-slot-b"`, never two in one message and never a re-submit after a timeout: `Test.Descriptor`, `Test.Navigation`, `Test.Wire`, `Test.ReadTool`, `Test.ScreenRead`, `Test.WireSecurityRead`, `Test.Smoke`; then the **whole** ObjectScript sweep, not a chosen subset, with totals confirmed against `%UnitTest_Result`. `Test.ScreenRead` and `Test.Smoke` can read red on slot B for an unrelated reason (**DW-1079**, the Wallet demo collection) — reproduce on a fresh throwaway before treating either as this story's.
- From `ui/`: `npm run build` (its `prebuild` runs `screen-mirror.mjs --check`, `classic-links.mjs`, `ipm-manifest.mjs --check`, `field-lists.mjs --check`), then `npm test`.
- `sh scripts/ci-throwaway.sh up --dir /tmp/ocupilot-b-ci --project ocupilot-b-ci --web 52777 --super 1976`, then `npm run test:browser` with **both** `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777` and `OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci`; `down` the same way when finished. `ci-runner.mjs` runs what the throwaway compiled at container start, so a sweep after an edit needs a fresh throwaway or an in-container recompile, and a browser leg needs `npm run build` plus a bundle redeploy first.
- `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS` — executed = passed, 26 area-list checks; zero executed is a failure.

**Mutations (Rule 19), one per AC:**

- AC1 — `mutation:` `sideBarPosition` 5 → **0** → the descriptor sorts into the unlisted group by class name and `Test/Navigation.cls`'s index-3 route assertion goes red, reading `os-management/devices` where it expects `os-management/processes/details`. (5 → 6 is **not** a valid mutation: position 5 and 6 both sort last, so nothing moves.)
- AC2 — `mutation:` drop `SubType` from `read.fields` → the new `Test/ScreenRead.cls` method goes red on a declared field absent from the live row. (It asserts `Type` and `SubType` precisely because `Alias` is empty on every row and would pass vacuously.)
- AC3 — `mutation:` remove `osmgmt.devices.read` from `Test/ReadTool.cls:94` → red on the alphabetical name set; `toolIdentifier` → `osmgmt.device` → both rosters red.
- AC4 — `mutation:` drop `%DB_IRISSYS:READ` from `privileges` → the new `Test/WireSecurityRead.cls` method goes red, the IRISSYS-less principal served instead of refused.
- AC5 — `mutation:` add one `rowActions` entry with no handler → the new `Test/Descriptor.cls` method goes red; set `classicLinkExemption.exempt` true → `classic-links.mjs` fails `prebuild` on a `list` archetype declaring an exemption (AD-44).
- AC6 — `mutation:` add a fifth key `deviceColumnAlias: 'Alias'` → `strings.test.mjs` red on both the key-count equality at `:386` and value uniqueness; delete the `EXPERIENCE.md` row → red on the authorized set.
- AC7 — `mutation:` after `npm run build` and redeploy, reorder two `table.columns` entries → `devices.browser-spec.mjs`'s header-order assertion goes red. A mutation that is not rebuilt and redeployed proves nothing: the spec reads the deployed bundle.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none

Planning pass only; no product code, planning artifact or tracker file was touched. Evidence gathered on `ocupilot-slot-b`: the vendor endpoint class and its `ResourcesOR()`, `Config.Devices:List`'s `ROWSPEC` and storage location, one live `AdminPort.Invoke` LIST (12 rows, 9 keys), and `NormalizePage` for the classic key. Two facts in the dispatch brief were stale and are corrected here: `device` is already in `Kernel/EntityType.cls`'s closed vocabulary, and `strings.test.mjs`'s literal bound is already 520 (Story 6.11 raised it to cover 6.12 through 6.14), so neither needs a change. `warnings: ['oversized']` is honest: the spec is ~5.2K tokens against the template's 1,600, and about half the size of the three specs before it.
