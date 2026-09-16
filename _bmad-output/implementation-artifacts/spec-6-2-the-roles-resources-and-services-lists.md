---
title: 'The roles, resources and services lists'
type: 'feature'
created: '2026-09-16'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-6-context.md'
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
warnings: [oversized]
deferred: []
---

<intent-contract>

## Intent

**Problem:** The Permissions area lists users only. Its Roles, Resources and Services entries do not exist, and the agent has no read tool for any of the three.

**Approach:** Add three hand-written `list` descriptors over the audited `Security.Role`, `Security.Resource` and `Security.Service` LIST endpoints, read through `AdminPort`. `ListPage` renders them from the regenerated mirror, and each read tool is derived. Establish each pair set with real principals on the throwaway, and extend the rosters those screens trip.

## Boundaries & Constraints

**Always:**

- **One read each.** An `admin` LIST with `paging: cap` and no `rowGet`: each LIST row already carries every field an AC names. The read fields are the live row's whole key set, in the vendor's order. `context.fields` equals the read fields, and `secretFields` is empty.
- **Scope and id.** Scope `instance`, id `single` (the row's `Name`). Entity types `role`, `resource` and `service`.
- **No actions.** No primary or row action, so the empty state's second line is `tableReadOnlyEmptyNext`. `refreshes` is false. The descriptor names its classic page and links out to nothing.
- **Pairs.** The declared set is `%Admin_Secure:USE` then `%DB_IRISSYS:READ`, the Users list's set and order. If the throwaway's both-pairs principal is refused a list, or reads fewer rows than `_SYSTEM`, find the pair that restores it and append it to:
  - that descriptor;
  - the `permissions` area in `Screen/Area.cls`;
  - `AdminPort.QUERYPAIRS`, as an additive entry;
  - `Test/Descriptor.cls:1065`'s area pin;
  - a `WireSecurityRead` principal.

  Record the pair under Design Notes.
- **Unrestricted.** A table column may declare an optional `emptyKey`: an empty value in that column (`null`, absent, `""` or `[]`) reads that key's string instead of "(none)". `ServiceList`'s `AllowedConnections` column declares `emptyKey` `serviceAllowedUnrestricted` ("Unrestricted"), because an empty list is the vendor's encoding of unrestricted and "(none)" would read as no address allowed. `Screen.Registry` and `screen-mirror.mjs` both accept the key and refuse an empty one; the read and the tool still carry `[]`.
- **Shared files.** Edits to Epic 4's shared files are additive. The new EXPERIENCE.md Fixed strings rows go after `:346`. Non-ASCII is written as `\uXXXX`.

**Never:**

- No new port, endpoint call, read grammar, column kind or client page; the one table-grammar addition is the optional column `emptyKey` above. No edit under `Kernel/**`, `Screen/Tool/**`, `scripts/check-objectscript.py`, `app.ts` or `shell/panel/**`.
- No classic link out, no auto-refresh, no write or row action (those are Stories 8.3, 8.4, 9.3 and 9.4).
- A denial is never an empty state and never a 500.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Roles | `GET /screens/permissions.roles/read?maxRows=1000` as the test account | 200, `fields` `[Name,Description,CreatedBy,EscalationOnly]`. Rows include `%All`, and `EscalationOnly` is boolean on every row. `truncated` false. | No error expected |
| Resources | `permissions.resources` | `fields` `[Name,Description,PublicPermission,ResourceType,AllowDelete]`. The `%DB_IRISSYS` row reads `AllowDelete` false. At least one row reads true. | No error expected |
| Services | `permissions.services` | `fields` `[Name,Enabled,Public,AuthenticationMethods,AllowedConnections,Description,HttpOnlyCookies,TwoFactorEnabled]`. Both list fields are arrays on every row. `Enabled` is boolean. | No error expected |
| Cap | any of the three, `maxRows=1` | One row, `truncated` true | — |
| Both pairs | throwaway principal holding install-DB READ, `%Admin_Secure:USE`, `%DB_IRISSYS:READ` | Each read: 200, rows equal to the test account's read at `maxRows=1000`. The navigation map lists all four Permissions entries allowed. | — |
| No system DB read | holds `%Admin_Secure:USE` only | Each navigation entry is denied with `failedPair` `%DB_IRISSYS:READ`. Each read: 403 `AUTH.NOPRIVILEGE` naming that pair, with no rows. | Never 500 |
| No admin resource | holds `%DB_IRISSYS:READ` + `%Admin_Operate:USE` | The same, naming `%Admin_Secure:USE` | — |
| Tool | `Screen.Tool.Read.View(<descriptor>, {}, 3)` for each | `fields,rows,truncated` only. The rows equal the first 3 of `ApplyView` over the route's rows, and `truncated` is true. | — |
| Unrestricted service | `AllowedConnections` `[]` | The "Allowed IP addresses" cell reads "Unrestricted"; the read and the tool still return `[]` | — |

</intent-contract>

## Code Map

- `src/OcuPilot/Screen/Descriptor/UserList.cls` is the template for instance scope, pair order, the doc-comment shape and `tableReadOnlyEmptyNext`. `SslConfigList.cls` is the no-`rowGet`, whole-key-set precedent.
- The vendor endpoints are hidden, so read them with `iris_doc_get` in `%SYS`. None of their backing query bodies is shipped.
  - **`Security.Role` LIST:** `%SQL.Manager.CatalogPriv:RolesFilter`, which maps `CreatedBy` and `EscalationOnly`.
  - **`Security.Resource` LIST:** `Security.Resources:List("*",-1,-1,1)`, minus `PublicPermissionLong` and `Type`, with `AllowDelete` as a boolean.
  - **`Security.Service` LIST:** `Security.Services:Detail`, which maps "Unrestricted" to `[]` and splits the methods into an array.
  - **Gate:** each class's `ResourcesOR()` is `%Admin_Secure`.
- `src/OcuPilot/Test/AdminInventory.cls:93,94,99`: all three are in the inventory, synchronous, with no CSP state.
- Live on slot B (2026-09-16): 69 roles, 185 resources and 15 services. `AllowDelete` is 0 for every name the classic `%CSP.UI.Portal.Resources` hard-codes as undeletable.
- Classic pages, each with `RESOURCE` `%Admin_Secure`: `irissys/%CSP/UI/Portal/Roles.cls`, `Resources.cls`, `Services.cls`.
- `src/OcuPilot/Screen/Area.cls:88` is the Permissions pair set. `Kernel/EntityType.cls` already holds `role`, `resource` and `service`.
- `src/OcuPilot/Port/AdminPort.cls:121` is `QUERYPAIRS`, used only under the Always pair rule.
- Rosters these screens trip:
  - `Test/ReadTool.cls:93-94,100` (10 tools) and `:233` (shipped reads).
  - `ui/tools/screen-mirror.test.mjs:443`.
  - `ui/tools/navigation.test.mjs:107-135`.
  - `Test/Wire.cls:536` (ADMINUSER's Permissions entries).
  - `Test/WireSecurityRead.cls:448,465,483` (the three principals' Permissions pins and reads; `AssertReadRefused` `:285`).
  - `ui/tools/navigation-wire.test.mjs:111` and `ui/src/app/shell/rail-wire.spec.ts:110` (`LIVE_PAYLOAD`, copied from Wire's pin).
  - `Install/Smoke.cls:44-70,480` (seven checks) and `Test/Smoke.cls:393,422` (seven names and paths).
- `Test/ScreenRead.cls:179` already holds every admin LIST descriptor's fields to the live row, so it needs no edit.
- `Test/MgmntPortWire.cls:255` is the tool-integration pattern. `Test/ScreenReadWire.cls:173` is the wire read pattern.
- `ui/browser/users.browser-spec.mjs` is the pattern for the throwaway principal, `signedInAtList` and deep-link denial. `ui/browser/list-spec.mjs` has `filterToSubset` and `viewCount`.
- `ui/src/app/core/strings.ts:327-343`: Fixed strings keys, commented `EXPERIENCE.md:<line>`. Values must be unique ("Roles" is `userColumnRoles`). `ui/tools/strings.test.mjs:321` is the literal band.
- DESIGN.md `:1043`: an empty cell reads "(none)", and only enabled/disabled gets a status disc. EXPERIENCE.md `:118,:123,:125` are the screen rows, and `:166` fixes the Permissions side-bar order.

## Tasks & Acceptance

**Execution:**

- [ ] `src/OcuPilot/Screen/Descriptor/RoleList.cls`, `ResourceList.cls`, `ServiceList.cls`: create them per Boundaries. Filter and sort omit booleans, and sort defaults to `Name` asc. Every descriptor uses area `permissions`, archetype `list`, `emptyNextKey` `tableReadOnlyEmptyNext` and `classicLinkExemption` not exempt. Every `Name` column's labelKey is `tableColumnName`, and every `Description` column's is `tableColumnDescription`.

  | Descriptor | route / pos / tool | labelKey / empty | aliases / classicPage | filter (sort) | table columns (field:kind:labelKey) |
  | --- | --- | --- | --- | --- | --- |
  | RoleList | `permissions/roles` / 2 / `permissions.roles` | `userColumnRoles` / `roleListEmpty` | `["security roles"]` / `%CSP.UI.Portal.Roles` | Name, Description, CreatedBy (same) | Name:name:tableColumnName · Description:text:tableColumnDescription · CreatedBy:text:roleColumnCreatedBy · EscalationOnly:text:roleColumnEscalationOnly |
  | ResourceList | `permissions/resources` / 3 / `permissions.resources` | `resourceListLabel` / `resourceListEmpty` | `["security resources"]` / `%CSP.UI.Portal.Resources` | Name, Description, PublicPermission, ResourceType (same) | Name:name · Description:text · PublicPermission:text:resourceColumnPublicPermission · ResourceType:text:tableColumnType · AllowDelete:text:resourceColumnDeletable |
  | ServiceList | `permissions/services` / 4 / `permissions.services` | `serviceListLabel` / `serviceListEmpty` | `["security services"]` / `%CSP.UI.Portal.Services` | Name, Description, AuthenticationMethods, AllowedConnections (Name, Description) | Name:name · Enabled:status:tableColumnEnabled · AuthenticationMethods:text:serviceColumnAuthentication · AllowedConnections:identifier:serviceColumnAllowedAddresses (emptyKey `serviceAllowedUnrestricted`) · Description:text |

- [ ] `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md`: append three Fixed strings rows after `:346`, one per screen, in the existing row style.
  - `:347`: "Created by" · "Escalation only" · "No roles on this instance.". Its entry and title reuse the Users row's "Roles".
  - `:348`: "Resources" · "Public permission" · "Deletable" · "No resources on this instance.".
  - `:349`: "Services" · "Authentication methods" · "Allowed IP addresses" · "Unrestricted" · "No services on this instance.".
- [ ] `ui/src/app/core/strings.ts`: add the keys named in the table, with those values and `EXPERIENCE.md:347-349` comments. Raise the band only if the count exceeds it.
- [ ] Column `emptyKey` (lead decision at the spec gate): `src/OcuPilot/Screen/Registry.cls` table-column validation and `ui/tools/screen-mirror.mjs` accept an optional non-empty string `emptyKey` (additive to the allowed key list; an empty or non-string value is refused with a sentence naming the column), the mirror's column type carries it, and `ui/src/app/core/table-model.ts` `cellView` (and its data-table caller) renders that key's string for an empty value (`null`, absent, `""`, `[]`). Pin it in `ui/tools/table-model.test.mjs`, `ui/tools/screen-mirror.test.mjs` and the ObjectScript declaration corpus that holds table-column refusals. Regenerate `ui/src/app/core/screens.generated.ts`.
- [ ] `src/OcuPilot/Test/PermissionsLists.cls` (new; needs the API application over HTTP):
  - Each descriptor passes `ReadProblem` and `ClassicLinkProblem`, and its route and tool resolve to it.
  - Its classic page compiles under the declared case, its side-bar position, entity type and scope are as declared, and `AreaCoverageProblem("permissions", …)` is empty.
  - The Matrix's Roles, Resources, Services, Cap and Tool rows.
- [ ] `src/OcuPilot/Test/WireSecurityRead.cls`:
  - The three Permissions pins list four entries.
  - `AssertReadRefused` covers the three new tools in `:448` and `:465`.
  - `:483` reads each new list as BOTHUSER: 200, with rows equal to the test account's.
  - The header names the new lists.
- [ ] `src/OcuPilot/Test/Wire.cls:536`, `ui/tools/navigation-wire.test.mjs`, `ui/src/app/shell/rail-wire.spec.ts`: the Permissions entries become four, each denied on `%Admin_Secure:USE`. The two `LIVE_PAYLOAD` copies equal Wire's string.
- [ ] `src/OcuPilot/Test/ReadTool.cls:93-94,100,233`, `ui/tools/screen-mirror.test.mjs:443`, `ui/tools/navigation.test.mjs:125`: add the three tools, classes and routes. Tool names go in sorted order, the count is 13, and the routes follow `permissions/users` in side-bar order.
- [ ] `src/OcuPilot/Install/Smoke.cls`: add `ROLELISTTOOL`, `RESOURCELISTTOOL` and `SERVICELISTTOOL`, checks `roles`, `resources` and `services` (10 in all), with one `$Select` arm each. `src/OcuPilot/Test/Smoke.cls`: `:393` and `:422` expect ten, and one live-check test reads the three.
- [ ] `ui/browser/permissions.browser-spec.mjs` (new, creates principals, refuses the live container): the browser ACs below.

**Acceptance Criteria:**

- Given `_SYSTEM` on HSCUSTOM, when the Permissions area opens, then its side bar reads Users, Roles, Resources, Services, and each new list renders under its declared headers from exactly one read.
- Given the Roles list, when the filter reads `%Admin`, then the view narrows to a proper subset (`filterToSubset`).
- Given the Resources list, when searched for `%DB_IRISSYS` and for a throwaway resource the spec creates, then their Deletable cells read "No" and "Yes".
- Given the Services list, when it renders, then each row's Enabled, Authentication methods and Allowed IP addresses cells match that row of the read response, and an empty array reads "Unrestricted".
- Given a throwaway principal holding `%Admin_Secure:USE` without `%DB_IRISSYS:READ`, when it deep-links to each new route, then the shell shows the screen-denied message naming `%DB_IRISSYS:READ` and issues no read.
- Integration: given consumer `Screen.Tool.Read.View`, when it reads `permissions.roles.read`, `permissions.resources.read` and `permissions.services.read` live, then it returns the route's fields and rows narrowed by its cap.

## Spec Change Log

- 2026-09-16 (spec gate, lead): an empty `AllowedConnections` reads "Unrestricted" through an optional column `emptyKey`, not "(none)"; Boundaries, Matrix, Tasks, the browser AC, Design Notes and one mutation updated; the spine's Screen archetype convention names the key.

## Review Triage Log

## Design Notes

**Architecture decisions:**

- **AD-2 / AD-27:** `AdminPort` alone reaches the endpoints, and all three are already in the audited inventory.
- **AD-5:** one hand-written descriptor per screen, with the tools derived.
- **AD-8 / AD-29:** `ResourcesOR()` gives `%Admin_Secure`, and the port's `%SYS` sequence needs `%DB_IRISSYS:READ`. The backing query bodies are not shipped, so no further pair is needed (inference). The throwaway principals settle it, and they must also read the same rows as `_SYSTEM`.
- **AD-13 / AD-14:** instance scope, and closed entity types.
- **AD-24 / AD-36:** one capped read shared by the screen and the tool, with no secret field.
- **AD-26:** synchronous path only.
- **AD-43:** no refresh.
- **AD-44:** each descriptor declares the classic page it replaces, and a list links out to nothing.

**Choices:**

- **Deletable** is the vendor's own `AllowDelete`, as a `text` column. A success disc would draw "deletable" as healthy, which is why Users' "Account expired" is text too.
- **Unrestricted services (lead, spec gate).** An empty `AllowedConnections` is the vendor's encoding of "Unrestricted" (`Security.Service.RunList`). "(none)" (DESIGN.md `:1043`) would tell a security administrator that no address may connect, the opposite of the truth, so the column declares `emptyKey` and reads "Unrestricted" as the classic page does. The spine's Screen archetype convention names the optional key; the tool keeps the vendor's `[]`.
- **Empty states** name the instance, because the scope is `instance` (the Task schedule row's precedent).

**Integration ACs:** the tool AC above, the smoke checks, and the browser ACs.

**Consumes:**

- `AdminPort` (Story 2.1).
- `Screen.Read` and `ScreenRead` (2.3).
- `ListPage` and the data table (2.4).
- `Screen.Gate` and navigation (1.9).

**Consumed-by:**

- 4.2, whose tool registry advertises the three read tools.
- 4.4, screen context.
- 8.3, Create role on Roles.
- 8.4, whose resource delete is gated on `AllowDelete`.
- 9.3, the role editor from its name cell.
- 9.4, the service editor from its name cell.

**Ledger inbox:** none owned by `6-2-the-roles-resources-and-services-lists`.

## Verification

**Commands:**

- `uv run scripts/check-objectscript.py` -- expected: 0 findings.
- Load and compile `src/OcuPilot/` through the IRIS MCP tools with `server: "ocupilot-slot-b"`, namespace HSCUSTOM -- expected: a clean compile.
- `sh scripts/ci-throwaway.sh up --dir /tmp/ocupilot-b-ci --project ocupilot-b-ci --web 52777 --super 1976` -- expected: healthy. Every principal and resource these tests create lives on this throwaway only. Teardown: `sh scripts/ci-throwaway.sh down --dir /tmp/ocupilot-b-ci --project ocupilot-b-ci`.
- From `ui/`, run `node tools/ci-runner.mjs --container ocupilot-b-ci --class <Class>` one class per call, for PermissionsLists, WireSecurityRead, Wire, ReadTool, ScreenRead, Descriptor and Smoke -- expected: all green, with totals confirmed from `%UnitTest_Result`.
- `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS` -- expected: `roles`, `resources` and `services` pass, with no failures.
- `cd ui && npm run build && npm test` -- expected: green, and `screen-mirror --check` clean.
- From `ui/`, redeploy the bundle with `docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`, then run `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci npm run test:browser` -- expected: `permissions.browser-spec.mjs` green.
- `bash scripts/lint-docs.sh` -- expected: clean.

**Mutations (Rule 19; record each as `mutation:` once observed, then revert and confirm the tree byte-identical):**

- `RoleList` endpoint `Security.User` -> PermissionsLists Roles field-set and Tool legs red.
- `ResourceList` drops `AllowDelete` from read and table -> PermissionsLists Resources leg and the browser Deletable leg red.
- `ServiceList` column `AllowedConnections` on `Public` -> the browser Services leg red.
- `cellView` ignores a column's `emptyKey` -> `table-model.test.mjs` emptyKey case and the browser Unrestricted leg red.
- `ServiceList` privileges without `%Admin_Secure:USE` -> the WireSecurityRead SYSREADUSER leg red.
- `ResourceList` `sideBarPosition` 5 -> `navigation.test.mjs` and the browser order leg red.
- `Install.Smoke.SERVICELISTTOOL` `permissions.nosuch` -> the Test/Smoke live check red.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none
