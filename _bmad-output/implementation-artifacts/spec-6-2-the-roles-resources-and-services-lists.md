---
title: 'The roles, resources and services lists'
type: 'feature'
created: '2026-09-16'
status: 'done'
baseline_revision: 'ed90acea27aa751603d2f2e59214cda678b165bc'
baseline_commit: 'ed90acea27aa751603d2f2e59214cda678b165bc'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-6-context.md'
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
warnings: [oversized]
deferred:
  - summary: >-
      Filtering the Services list on "Unrestricted", the word an empty Allowed IP addresses cell shows, matches no row.
    evidence: |-
      The view rule reads `[]` as empty text in both engines (`ui/src/app/core/screen-read.ts` applyView, `OcuPilot.Screen.Read.ApplyView`), and `AllowedConnections` is a declared filter field. Matching the displayed word needs the server view rule to know a client string, a read-grammar change this story's intent excludes. "(none)" behaves the same everywhere today.
    location: >-
      src/OcuPilot/Screen/Descriptor/ServiceList.cls
    severity: low
  - summary: >-
      The permissions.services.read tool answers a bare `[]` for an unrestricted service, and nothing tells the model that `[]` means any address may connect.
    evidence: |-
      The intent keeps the vendor's `[]` on the read and the tool; only the screen cell reads "Unrestricted". The generic read-tool description and Story 4.4's screen context carry no field meaning, so the model can report a service as allowing no address. The explanation belongs in the tool description or context layer (`Screen/Tool/**`, Stories 4.2 and 4.4), contended for this story.
    location: >-
      src/OcuPilot/Screen/Tool/Read.cls
    severity: medium
  - summary: >-
      An empty `AuthenticationMethods` (7 of 15 stock services, mostly with Public "N/A") reads "(none)", which can read as "no authentication" on services where authentication does not apply.
    evidence: |-
      Observed on the slot B throwaway's services read (DataCheck, DocDB, ECP, Mirror, Monitor, Shadow, Sharding). The spec gate gave only `AllowedConnections` an empty-cell word; a second word is a UX decision (a new EXPERIENCE.md row and string).
    location: >-
      src/OcuPilot/Screen/Descriptor/ServiceList.cls
    severity: low
  - summary: >-
      After the first-login gate, Back returns to the requested list but the side bar stays on the Agent co-pilot area.
    evidence: |-
      Reported by this story's implementation pass as a flake on reading the Permissions side bar (`ShellState.setActiveArea`); `permissions.browser-spec.mjs` opens the side bar by its rail item. Not reproduced deliberately. Settle with a browser repro of Back from the Definition form, and by the flake rate of `ssl.browser-spec.mjs` AC4, which reads the side bar without that step.
    location: >-
      ui/src/app/shell
    severity: medium (unverified)
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

- [x] `src/OcuPilot/Screen/Descriptor/RoleList.cls`, `ResourceList.cls`, `ServiceList.cls`: create them per Boundaries. Filter and sort omit booleans, and sort defaults to `Name` asc. Every descriptor uses area `permissions`, archetype `list`, `emptyNextKey` `tableReadOnlyEmptyNext` and `classicLinkExemption` not exempt. Every `Name` column's labelKey is `tableColumnName`, and every `Description` column's is `tableColumnDescription`.

  | Descriptor | route / pos / tool | labelKey / empty | aliases / classicPage | filter (sort) | table columns (field:kind:labelKey) |
  | --- | --- | --- | --- | --- | --- |
  | RoleList | `permissions/roles` / 2 / `permissions.roles` | `userColumnRoles` / `roleListEmpty` | `["security roles"]` / `%CSP.UI.Portal.Roles` | Name, Description, CreatedBy (same) | Name:name:tableColumnName · Description:text:tableColumnDescription · CreatedBy:text:roleColumnCreatedBy · EscalationOnly:text:roleColumnEscalationOnly |
  | ResourceList | `permissions/resources` / 3 / `permissions.resources` | `resourceListLabel` / `resourceListEmpty` | `["security resources"]` / `%CSP.UI.Portal.Resources` | Name, Description, PublicPermission, ResourceType (same) | Name:name · Description:text · PublicPermission:text:resourceColumnPublicPermission · ResourceType:text:tableColumnType · AllowDelete:text:resourceColumnDeletable |
  | ServiceList | `permissions/services` / 4 / `permissions.services` | `serviceListLabel` / `serviceListEmpty` | `["security services"]` / `%CSP.UI.Portal.Services` | Name, Description, AuthenticationMethods, AllowedConnections (Name, Description) | Name:name · Enabled:status:tableColumnEnabled · AuthenticationMethods:text:serviceColumnAuthentication · AllowedConnections:identifier:serviceColumnAllowedAddresses (emptyKey `serviceAllowedUnrestricted`) · Description:text |

- [x] `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md`: append three Fixed strings rows after `:346`, one per screen, in the existing row style.
  - `:347`: "Created by" · "Escalation only" · "No roles on this instance.". Its entry and title reuse the Users row's "Roles".
  - `:348`: "Resources" · "Public permission" · "Deletable" · "No resources on this instance.".
  - `:349`: "Services" · "Authentication methods" · "Allowed IP addresses" · "Unrestricted" · "No services on this instance.".
- [x] `ui/src/app/core/strings.ts`: add the keys named in the table, with those values and `EXPERIENCE.md:347-349` comments. Raise the band only if the count exceeds it.
- [x] Column `emptyKey` (lead decision at the spec gate): `src/OcuPilot/Screen/Registry.cls` table-column validation and `ui/tools/screen-mirror.mjs` accept an optional non-empty string `emptyKey` (additive to the allowed key list; an empty or non-string value is refused with a sentence naming the column), the mirror's column type carries it, and `ui/src/app/core/table-model.ts` `cellView` (and its data-table caller) renders that key's string for an empty value (`null`, absent, `""`, `[]`). Pin it in `ui/tools/table-model.test.mjs`, `ui/tools/screen-mirror.test.mjs` and the ObjectScript declaration corpus that holds table-column refusals. Regenerate `ui/src/app/core/screens.generated.ts`.
- [x] `src/OcuPilot/Test/PermissionsLists.cls` (new; needs the API application over HTTP):
  - Each descriptor passes `ReadProblem` and `ClassicLinkProblem`, and its route and tool resolve to it.
  - Its classic page compiles under the declared case, its side-bar position, entity type and scope are as declared, and `AreaCoverageProblem("permissions", …)` is empty.
  - The Matrix's Roles, Resources, Services, Cap and Tool rows.
- [x] `src/OcuPilot/Test/WireSecurityRead.cls`:
  - The three Permissions pins list four entries.
  - `AssertReadRefused` covers the three new tools in `:448` and `:465`.
  - `:483` reads each new list as BOTHUSER: 200, with rows equal to the test account's.
  - The header names the new lists.
- [x] `src/OcuPilot/Test/Wire.cls:536`, `ui/tools/navigation-wire.test.mjs`, `ui/src/app/shell/rail-wire.spec.ts`: the Permissions entries become four, each denied on `%Admin_Secure:USE`. The two `LIVE_PAYLOAD` copies equal Wire's string.
- [x] `src/OcuPilot/Test/ReadTool.cls:93-94,100,233`, `ui/tools/screen-mirror.test.mjs:443`, `ui/tools/navigation.test.mjs:125`: add the three tools, classes and routes. Tool names go in sorted order, the count is 13, and the routes follow `permissions/users` in side-bar order.
- [x] `src/OcuPilot/Install/Smoke.cls`: add `ROLELISTTOOL`, `RESOURCELISTTOOL` and `SERVICELISTTOOL`, checks `roles`, `resources` and `services` (10 in all), with one `$Select` arm each. `src/OcuPilot/Test/Smoke.cls`: `:393` and `:422` expect ten, and one live-check test reads the three.
- [x] `ui/browser/permissions.browser-spec.mjs` (new, creates principals, refuses the live container): the browser ACs below.

**Acceptance Criteria:**

- Given `_SYSTEM` on HSCUSTOM, when the Permissions area opens, then its side bar reads Users, Roles, Resources, Services, and each new list renders under its declared headers from exactly one read.
- Given the Roles list, when the filter reads `%Admin`, then the view narrows to a proper subset (`filterToSubset`).
- Given the Resources list, when searched for `%DB_IRISSYS` and for a throwaway resource the spec creates, then their Deletable cells read "No" and "Yes".
- Given the Services list, when it renders, then each row's Enabled, Authentication methods and Allowed IP addresses cells match that row of the read response, and an empty array reads "Unrestricted".
- Given a throwaway principal holding `%Admin_Secure:USE` without `%DB_IRISSYS:READ`, when it deep-links to each new route, then the shell shows the screen-denied message naming `%DB_IRISSYS:READ` and issues no read.
- Integration: given consumer `Screen.Tool.Read.View`, when it reads `permissions.roles.read`, `permissions.resources.read` and `permissions.services.read` live, then it returns the route's fields and rows narrowed by its cap.

### Review Findings

Code review 2026-09-16 (full-opus; blind, edge-case, verification-gap, acceptance): 21 findings, 0 decision-needed, 5 patch, 5 defer, 11 rejected (the list below adds two rejected sub-claims of patched findings).

- [x] [Review][Patch] `before` saves `%Service_Shadow`'s original addresses only after four assertions, so a failed setup skips the restore and a rerun keeps the test addresses as the original [ui/browser/permissions.browser-spec.mjs:135]
- [x] [Review][Patch] `CheckAreaLists`' doc opens "the first live list of each portal area", false since 6.1 and more so with three Permissions lists [src/OcuPilot/Install/Smoke.cls:477]
- [x] [Review][Patch] Test class headers omit what the environment must provide: `PermissionsLists` calls the port in process, and `WireSecurityRead` holds rows to the test account [src/OcuPilot/Test/PermissionsLists.cls:6]
- [x] [Review][Patch] `TestNoCredentialsSkipsRatherThanPasses` does not name the list checks added since 2.10, the three new ones among them [src/OcuPilot/Test/Smoke.cls:554]
- [x] [Review][Patch] (Rule 19) AC6's recorded mutation changes the descriptor, which moves both sides of the tool-versus-route comparison; no consumer-side mutation is recorded [src/OcuPilot/Test/PermissionsLists.cls:287]
- [x] [Review][Defer] Browser specs that `docker exec` refuse only `ocupilot`, never an `ocupilot-slot-*` owner instance [ui/browser.config.mjs:45] — deferred: pre-existing harness guard, out-of-footprint; DW-1015, escalated
- [x] [Review][Defer] A proposal diff-row can show an empty `AllowedConnections` as "(none)" [EXPERIENCE.md:378] — deferred: medium (unverified), real once 9.4's service editor diffs the field; DW-1016, routed to 9.4
- [x] [Review][Defer] Both `LIVE_PAYLOAD` copies are checked only against themselves, never against `Test/Wire.cls`'s pins [ui/tools/navigation-wire.test.mjs:38] — deferred: pre-existing ("neither goes red alone"); DW-1017, wontfix-accepted
- [x] [Review][Defer] DW-1012: filtering Services on "Unrestricted" matches no row [src/OcuPilot/Screen/Descriptor/ServiceList.cls:58] — closed wontfix-accepted: the fix needs both view-rule engines to know a client string (AD-36), and the intent excludes read-grammar changes
- [x] [Review][Defer] The services tool's bare `[]` means nothing to the model [src/OcuPilot/Screen/Tool/Read.cls] — already DW-1013, routed to 7.1; occurrence appended

**Rejected:**

- `low` Leftover addresses from a killed run are saved as the original: unlikely on a disposable throwaway, and the fix is a guard.
- `low` The three smoke checks exceed AD-45's "one live list per area": the Tasks require ten checks, the epic context says one per built list, and AD-45 sets a floor, not a ceiling.
- `false` Bare check names break the naming: the spec names them, as `users`, `ssl` and `tasks` were named.
- `low` Another full smoke run in `Test/Smoke.cls`: the Tasks require a live-check test, and each sibling runs one.
- `low` `PublicPermission` shows `R`/`RW`/`U`: spec-bound, since the fields are the vendor row and a mapping needs a new column kind.
- `false` Services cannot sort on its array columns: the Tasks table declares sort as `Name`, `Description`.
- `low` Entries of the form `ip|role1,role2` blur when joined with ", ": role-qualified entries are rare, and a per-column separator is new grammar.
- `false` The `strings.test.mjs` band note is stale: the band is still 150–300, and 3.6 set the precedent that a story inside the band adds no note.
- `low` `WireSecurityRead` says BOTHUSER holds "only the declared pairs": the header already states every principal's install-DB read.
- `low` `ColumnCorpus` has no case for which of two faults is reported first: theoretical, since both engines check `emptyKey` after `kind`, and it becomes real only if one reorders.
- `false` A non-200 services read raises a TypeError: `waitForRows` runs first, and the error still fails AC4 loudly.
- `low` `AllowedConnections` `[""]`: all 15 stock rows read `[]`, and `[""]` would read "Unrestricted", which is correct.
- `false` AC1's side-bar loop hides a bug: the AC's wording allows it, and the behavior is DW-148's 6.2 occurrence.

## Spec Change Log

- 2026-09-16 (spec gate, lead): an empty `AllowedConnections` reads "Unrestricted" through an optional column `emptyKey`, not "(none)"; Boundaries, Matrix, Tasks, the browser AC, Design Notes and one mutation updated; the spine's Screen archetype convention names the key.

## Review Triage Log

### 2026-09-16 — Review pass

- verdicts: 44 findings — high 0, medium 3, low 30, false 10, maybe-false 1
- findings:
  - `[low]` `[patch]` DESIGN.md `:1043` says every empty cell reads "(none)" — amended the data-table sentence: a column that declares an empty-cell word reads that word in the body style.
  - `[low]` `[defer]` Filtering the Services list on "Unrestricted" finds no row, because the view rule matches `[]` as empty text in both engines — deferred; matching a display word needs the server view rule to know client strings, a read-grammar change the intent excludes.
  - `[medium]` `[defer]` The `permissions.services.read` tool returns a bare `[]` with nothing telling the model it means any address — deferred; the intent keeps `[]` on the tool, and the explanation belongs to the tool description or screen context (`Screen/Tool/**`, Stories 4.2 and 4.4).
  - `[low]` `[defer]` An empty `AuthenticationMethods` (7 of 15 stock services) reads "(none)", which can read as unauthenticated — deferred; a second empty-cell word is a UX decision beyond the lead's spec-gate call.
  - `[low]` `[patch]` Browser AC4's address branch never ran, since every stock service is unrestricted — `before` gives the disabled `%Service_Shadow` two addresses and `after` restores them; AC4 asserts the restricted leg ran and the read carries the array.
  - `[low]` `[patch]` Nothing pinned that the read and the tool still carry `[]` — the Services wire test and the tool test each assert an unrestricted row reads `[]`.
  - `[medium]` `[patch]` `RowShapeProblem`'s key check cannot fail, because `Screen.Read.Project` builds every row from the declared fields, so "the live row's whole key set, in the vendor's order" was pinned nowhere — added `TestEachReadsFieldsAreTheLiveRowsWholeKeySet` over the raw `AdminPort` LIST rows and dropped the vacuous key check.
  - `[false]` `[reject]` The descriptors' "without `%DB_IRISSYS:READ` the port answers 500" is unverified — probed under mutation: all three reads answered 500 `INTERNAL` to a principal holding install-DB read and `%Admin_Secure:USE`.
  - `[low]` `[reject]` `emptyKey` is accepted on any column kind — no reachable harm (a name or boolean status cell is never empty), and the fix adds a guard.
  - `[low]` `[patch]` `AssertReadRefused` never checked "with no rows" — it now asserts the refusal carries no `rows`.
  - `[low]` `[reject]` `AssertSameRowsAsTestAccount` does not prove the reference holds `%All`, and parses outside Try — the Matrix names the test account (`_SYSTEM` by default), and a non-JSON body raises and fails the method loudly.
  - `[low]` `[reject]` The Roles screen borrows `userColumnRoles` — spec-bound: the Tasks name the key, and the string table refuses a second "Roles" value.
  - `[false]` `[reject]` The refusal sentence's second clause reads as if the bad key works — it follows the sibling pattern of fault then rule (`labelKey is empty, and a column header names a string key`).
  - `[low]` `[patch]` Doc-comment slips: history narration and a stale "entry" in `Wire.cls`, a stub line in the `WireSecurityRead.cls` header — rewritten and reflowed.
  - `[low]` `[reject]` The spec's frontmatter and Auto Run Result disagree on status — the fix edits this build's spec; finalize reconciles both.
  - `[maybe-false]` `[defer]` After the first-login gate, Back leaves the side bar on Agent co-pilot (`ShellState.setActiveArea`), and the spec clicks past it — deferred (medium if true); a pre-existing shell behavior, settled by a browser repro of Back from the Definition form and by `ssl.browser-spec.mjs` AC4's flake rate.
  - `[false]` `[reject]` No fast test pins `data-table.ts` passing `emptyKey` — browser AC4 pins it, as the finding itself states.
  - `[low]` `[reject]` "Filter and sort omit booleans" is pinned nowhere — not an AC, and only a future edit could break it.
  - `[low]` `[reject]` `ReadTool.cls` grows past the size guideline — pre-existing size; the corpus tests' established home.
  - `[low]` `[defer]` (edge) Filtering on "Unrestricted" returns zero rows — same root cause and route as the second row.
  - `[low]` `[defer]` (edge) Empty `AuthenticationMethods` reads "(none)" — same root cause and route as the fourth row.
  - `[low]` `[patch]` (edge) `PermissionsLists.Read` swallows a parse failure, so a wire test could exit green without checking rows — `Read` now asserts the body parses.
  - `[false]` `[reject]` (edge) `%FromJSON` outside Try in `AssertSameRowsAsTestAccount` aborts the method — an error fails the method loudly.
  - `[low]` `[reject]` (edge) A role created between the two same-rows reads would flake — theoretical: one test run is in flight at a time, and the reads are milliseconds apart.
  - `[low]` `[patch]` (edge) AC4's restricted branch never runs — same fix as the fifth row.
  - `[false]` `[reject]` (edge) `ReadTool`'s `columns.%Get(3)` breaks on reorder — a reorder fails the assertion loudly.
  - `[low]` `[patch]` (gap) The three new `LIVE_PAYLOAD` entries are read by no assertion — `navigation-wire.test.mjs` asserts each route's verdict; mutation observed.
  - `[low]` `[patch]` (gap) AC5 has no `mutation:` line — observed and recorded.
  - `[low]` `[patch]` (gap) AC2 has no `mutation:` line — observed and recorded.
  - `[low]` `[patch]` (gap) AC3's recorded mutation fails on a TypeError before the Yes/No comparison — a discriminating `cellView` mutation observed and recorded; the old line narrowed to AC1.
  - `[low]` `[reject]` (gap) Several Matrix rows have no `mutation:` line — Rule 19 is one mutation per AC; each row's covering test exists and ran.
  - `[low]` `[defer]` (gap) Filtering on "Unrestricted" finds no service — same root cause and route as the second row.
  - `[medium]` `[patch]` (intent) The key set and order have no live check — same fix as the seventh row.
  - `[false]` `[reject]` (intent) `cellView` treats more than the four listed values as empty — the existing empty rule is text `''`, and all four listed values are covered.
  - `[false]` `[reject]` (intent) The Unrestricted word is drawn in the body face — the intent is silent; EXPERIENCE.md `:349` calls it the word, and DESIGN.md now says so.
  - `[low]` `[defer]` (intent) Filter versus the displayed word — same root cause and route as the second row.
  - `[low]` `[reject]` (intent) The comparison account and its truncation — same as the eleventh row.
  - `[low]` `[reject]` (intent) Design Notes still carry the AD-29 inference — the fix edits this build's spec; the Auto Run Result records the observed outcome.
  - `[low]` `[patch]` (intent) "With no rows" is not asserted — same fix as the tenth row.
  - `[low]` `[patch]` (intent) The tool's `[]` is not observed — same fix as the sixth row.
  - `[false]` `[reject]` (intent) EXPERIENCE.md rows use a literal middle dot — prose is exempt from the escape rule, and the rows follow the existing row style.
  - `[low]` `[reject]` (intent) Roster edits rewrite whole lines in shared files — the spec mandates them; they are additive in content.
  - `[false]` `[reject]` (intent) The tool test sets `Kernel.Scope` — this is the tool-integration pattern the Code Map names.
  - `[false]` `[reject]` (intent) The diff adds smoke checks, a corpus and browser ACs beyond the intent — they come from the spec's Tasks and stay inside the intent.

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

- mutation: `RoleList` endpoint `Security.User`, loaded into `ocupilot-b-ci` -> `PermissionsLists.TestTheRolesListReadsOverTheWire` (the `%All` and row-shape assertions) and `TestTheReadToolAnswersTheRoutesRowsNarrowedByItsCap` (the roles tool's boolean) red (observed, run 8).
- mutation: `ResourceList` drops `AllowDelete` from read, context and table -> `PermissionsLists` Resources, declaration and Tool legs red (run 9); mirror regenerated, bundle rebuilt and redeployed -> browser AC1 (resources headers) red (observed).
- mutation: `cellView` reads a boolean outside a `status` column as No, bundle rebuilt and redeployed -> browser AC3 red on the probe resource's Deletable cell, `No` for `Yes` (observed).
- mutation: `RoleList` `read.filter` `["CreatedBy"]`, mirror regenerated, bundle rebuilt and redeployed -> browser AC2 red, `%Admin` leaving 0 of 70 rows (observed).
- mutation: `RoleList`, `ResourceList` and `ServiceList` privileges without `%DB_IRISSYS:READ`, loaded into `ocupilot-b-ci` -> `WireSecurityRead.TestAdminSecureAloneIsDeniedOnTheSystemDatabaseRead` red on the Permissions pin and all three refusals, each read answering 500 `INTERNAL` to a principal holding install-DB read and `%Admin_Secure:USE`; browser AC5 red, no denial rendered (observed).
- mutation: `cellView` applies a column's `emptyKey` to a non-empty value, bundle rebuilt and redeployed -> browser AC4 red on `%Service_Shadow`'s restricted cell reading `Unrestricted` (observed).
- mutation: `RoleList` read and context fields with `Description` and `CreatedBy` swapped, loaded -> `PermissionsLists.TestEachReadsFieldsAreTheLiveRowsWholeKeySet` red on the raw-row key set (observed, run 9).
- mutation: the `permissions/resources` entry's `failedPair` in `navigation-wire.test.mjs`'s `LIVE_PAYLOAD` set to `%DB_IRISSYS:READ` -> its `screenVerdict` assertion red (observed).
- mutation: `ServiceList` column `AllowedConnections` on `Public`, bundle rebuilt and redeployed -> browser AC4 red, `%Service_Bindings` reading `N/A` (observed).
- mutation: `cellView` ignores its `emptyKey` -> `table-model.test.mjs` emptyKey case red; bundle rebuilt and redeployed -> browser AC4 red, reading `(none)` (observed).
- mutation: `ServiceList` privileges without `%Admin_Secure:USE`, loaded -> `WireSecurityRead.TestSystemReadWithoutAdminSecureIsDenied` red on the Permissions pin and the services refusal's code and pair (observed, run 10).
- mutation: `ResourceList` `sideBarPosition` 5 -> `navigation.test.mjs` built-routes roster red; bundle rebuilt and redeployed -> browser AC1 side-bar order red (observed).
- mutation: `Install.Smoke.SERVICELISTTOOL` `permissions.nosuch`, loaded -> `Smoke.TestThePermissionsListsAreLiveChecks` red (observed, run 12).
- mutation: `Registry.TableProblem`'s `emptyKey` arm disabled, loaded -> `ReadTool.TestEveryColumnCorpusCaseGetsItsSentence` red on exactly the five refusing value cases, the unknown-key case green (observed, run 13).
- mutation: `screen-mirror.mjs` `tableProblem`'s `emptyKey` arm disabled -> `screen-mirror.test.mjs` column-corpus test red on "an empty emptyKey is refused"; `declaredStringKeys` drops column `emptyKey` -> the string-key listing test red (observed).
- mutation: `ResourceList` `classicPage` lower-cased, loaded -> `PermissionsLists.TestEachListIsDeclaredAsThePermissionsAreaEntryItReplaces` red on the classic-page and compiled-class assertions (observed, run 14).

**QA falsification (independent, one mutation per AC, none duplicating the pass above):**

- mutation (AC6): `ServiceList` endpoint `Security.Resource`, loaded into `ocupilot-b-ci` -> `PermissionsLists.TestEachReadsFieldsAreTheLiveRowsWholeKeySet`, `TestTheReadToolAnswersTheRoutesRowsNarrowedByItsCap` and `TestTheServicesListReadsOverTheWire` red, 3 of 7 (observed, QA).
- mutation (AC1): `RoleList`'s `Description` and `CreatedBy` table columns swapped in `screens.generated.ts`, bundle rebuilt and redeployed -> browser AC1 red on the Roles headers' order (observed, QA).
- mutation (AC2): `RoleList`'s client `read.filter` in `screens.generated.ts` narrowed to `["Description","CreatedBy"]` (`Name` alone dropped), bundle rebuilt and redeployed -> browser AC2 red, `%Admin` leaving 0 of 70 rows (observed, QA).
- mutation (AC3): `ResourceList`'s `AllowDelete` table column `field` changed to `ResourceType` in `screens.generated.ts`, bundle rebuilt and redeployed -> browser AC3 red, `%DB_IRISSYS`'s Deletable cell reading "Database" for "No" (observed, QA).
- mutation (AC4): `ServiceList`'s `Enabled` table column `field` changed to `Public` in `screens.generated.ts`, bundle rebuilt and redeployed -> browser AC4 red, `%Service_Bindings`'s Enabled cell reading "N/A" for "Yes" (observed, QA).
- mutation (AC5): `formatDeniedScreen`'s two placeholder replacements swapped in `navigation.ts`, bundle rebuilt and redeployed -> browser AC5 red on the literal denial sentence, `"You need Roles to open %DB_IRISSYS:READ."` for `"You need %DB_IRISSYS:READ to open Roles."` (observed, QA).

**Code review falsification:**

- mutation (AC6, consumer side): `Screen.Tool.Read.View`'s cap loop keeps `pContextCap + 1` rows, loaded into `ocupilot-b-ci` from a scratch copy -> `PermissionsLists.TestTheReadToolAnswersTheRoutesRowsNarrowedByItsCap` red on the roles, resources and services tools' narrowed-rows assertion (observed, run 2; restored, run 3 green).
- probe (browser `before`): the spec's SYSREAD assertion forced to fail in a temporary copy -> before this pass's reorder `%Service_Shadow` kept `127.0.0.1;10.0.0.1`; after it the service read unrestricted (observed; copy deleted, service restored).

Each was reverted, reloaded or rebuilt and redeployed, and the mutated file confirmed byte-identical to its pre-mutation copy (`shasum` or `cmp`); the QA pass's OS mutation never touched the tracked file at all (loaded into the throwaway from a scratch copy), and `git status`/`git diff --stat` confirmed no residual change after each client mutation's revert.

## Auto Run Result

**Change.** Three hand-written `list` descriptors (`RoleList`, `ResourceList`, `ServiceList`) over the `Security.Role`, `Security.Resource` and `Security.Service` LISTs, each read's fields the raw row's whole key set, with derived `permissions.roles/resources/services.read` tools; an optional table-column `emptyKey` in `Screen.Registry`, `screen-mirror.mjs` and `cellView`, so an empty Allowed IP addresses cell reads "Unrestricted"; three smoke checks (ten in all).

**AD-29.** The declared set `%Admin_Secure:USE`, `%DB_IRISSYS:READ` is sufficient. The both-pairs principal reads each list row for row equal to the test account's (`WireSecurityRead`), each one-pair principal is refused by name, and without `%DB_IRISSYS:READ` all three reads answer 500 (probed under mutation). No pair was added, so `Screen/Area.cls`, `AdminPort.QUERYPAIRS` and the area pin in `Test/Descriptor.cls` are unchanged.

**Files.**

- `src/OcuPilot/Screen/Descriptor/RoleList.cls`, `ResourceList.cls`, `ServiceList.cls` (new): the three lists.
- `src/OcuPilot/Screen/Registry.cls`, `ui/tools/screen-mirror.mjs`, `ui/src/app/core/screens.generated.ts`: column `emptyKey` accepted, refused when empty, mirrored.
- `ui/src/app/core/table-model.ts`, `ui/src/app/shell/data-table.ts`: an empty cell in an `emptyKey` column reads that key's word.
- `ui/src/app/core/strings.ts`, EXPERIENCE.md rows 347-349, DESIGN.md data-table sentence: the new strings and the empty-cell word rule.
- `src/OcuPilot/Install/Smoke.cls`: `roles`, `resources`, `services` checks.
- Tests: `Test/PermissionsLists.cls` and `Test/ColumnCorpus.cls` (new); `Test/ReadTool.cls`, `Test/WireSecurityRead.cls`, `Test/Wire.cls`, `Test/Smoke.cls`; `ui/tools/screen-mirror.test.mjs`, `table-model.test.mjs`, `navigation.test.mjs`, `navigation-wire.test.mjs`; `ui/src/app/shell/rail-wire.spec.ts`; `ui/browser/permissions.browser-spec.mjs` (new).

**Review.** 44 findings (high 0, medium 3, low 30, false 10, maybe-false 1); see the triage log.

- Patched: the live raw-row key-set test (medium) replacing a vacuous key check; `[]` pinned on the read and the tool; "with no rows" on refusals; a parse assertion in `PermissionsLists.Read`; a restricted service in browser AC4; `screenVerdict` assertions for the three `LIVE_PAYLOAD` entries; mutation lines for AC2, AC3 (discriminating), AC4's new leg, AC5 and the new tests; doc-comment slips; DESIGN.md's empty-cell rule.
- Deferred (frontmatter): the "Unrestricted" filter, the tool's bare `[]` for the model, empty authentication methods reading "(none)", and the side bar after the first-login gate.
- Rejected: each with its reason in the triage log (emptyKey on any kind, the reference account, the borrowed Roles key, the refusal sentence, spec-status and Design Notes edits, the data-table fast test, boolean filter pinning, `ReadTool` size, the same-rows race, index-based column lookup, Matrix-row mutation lines, and the intent auditor's readings that describe no defect).

**Follow-up review:** `false`. Patched by verdict: medium 1 (the key-set group), low 12; no high.

**Verification.** `check-objectscript` 0 problems; `lint-docs` clean; `npm run build` green (`screen-mirror --check` up to date); `npm test` 800 node and 394 component tests green. Changed classes compiled clean on `ocupilot-slot-b`. On a fresh `ocupilot-b-ci`, one class per call, latest runs from `%UnitTest_Result`: PermissionsLists 7/7, WireSecurityRead 6/6, Wire 20/20, ReadTool 25/25, ScreenRead 22/22, Descriptor 32/32, Smoke 26/26. `smoke.sh` passed with `roles`, `resources` and `services`. The full browser suite passed 86/86 with both slot B variables. Every mutation was reverted to a byte-identical file (`shasum`), reloaded or rebuilt and redeployed; the throwaway was torn down.

**Residual risks.** The build warns that the initial bundle (616 kB) exceeds its 500 kB budget (a warning, not checked against the baseline). The roster edits in `Install/Smoke.cls` and `Test/ReadTool.cls` rewrite lines Epic 4 may also touch.

Status: done
Blocking condition: none
