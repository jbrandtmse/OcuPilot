---
title: 'Story 2.6: The users list'
type: 'feature'
created: '2026-09-14'
status: 'done'
baseline_revision: 'ce15562ee545de310164b48b1e5a3bd162faf523'
baseline_commit: 'ce15562ee545de310164b48b1e5a3bd162faf523'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md'
warnings: ['oversized']
deferred:
  - summary: >-
      The Permissions and Web applications area pair sets name %Admin_Secure:USE alone, while every screen in both areas now also needs %DB_IRISSYS:READ, so a holder of %Admin_Secure alone sees both rail areas and their Home tiles allowed and is refused on every screen inside.
    evidence: |-
      Area.cls declares only %Admin_Secure:USE for permissions and web-applications; UserList and WebAppList declare %DB_IRISSYS:READ as well; Area.cls's own header prefers a false denial to a false promise. The set predates this story (Epic 1); DW-262 exposed it.
    location: >-
      src/OcuPilot/Screen/Area.cls:41
    severity: medium
  - summary: >-
      Nothing in the read grammar makes an admin-port read declare %DB_IRISSYS:READ, so a later screen over an endpoint that also needs it would fail with an unnamed 500 instead of a named 403.
    evidence: |-
      Unverified whether the need comes from AdminPort's switch to %SYS (every endpoint) or from the security endpoints only. Settle with a throwaway principal holding code read plus the endpoint's own %Admin_* resource, reading a Process, Lock or Task LIST through the port.
    location: >-
      src/OcuPilot/Port/AdminPort.cls
    severity: medium (unverified)
---

# Story 2.6: The users list

<intent-contract>

## Intent

**Problem:** The Permissions area has no live list, so "who has access here, and who can actually log in?" (UJ-1) cannot be answered in OcuPilot. The vendor `Security.User` LIST carries no roles and no expiry, and the read grammar allows no second call to fetch them.

**Approach:** Add AD-36's per-row detail call, `read.source.rowGet`, to the grammar in both engines and to `Screen.Read.Execute`. Then declare `OcuPilot.Screen.Descriptor.UserList` over the `Security.User` LIST, which fills roles from its GET and derives `Expired` on the instance clock. The same story closes DW-262 (the security reads need `%DB_IRISSYS:READ`) and DW-186 (one link-out corpus shared by both engines).

## Boundaries & Constraints

**Always:**
- **The `rowGet` grammar.** When `read.source.rowGet` is present and not `null`, it is an object carrying exactly these keys:
  - `key`: one of `read.fields`.
  - `param`: matches `^[A-Za-z][A-Za-z0-9]*$`.
  - `fields`: a non-empty array of unique names from `read.fields`, excluding `key`.
  - `derived`: an array whose entries carry exactly `field`, `rule` and `from`.
    - `field` is one of `read.fields`. It is not `key`, not in `rowGet.fields`, and not repeated.
    - `rule` is `beforeToday`.
    - `from` is one of `rowGet.fields`.

  `Registry.ReadProblem` and `screen-mirror.mjs` `readProblem` refuse each violation with the same sentence. Every sentence starts `read.source.rowGet`.
- **Execution.**
  - `Execute` takes the first `maxRows` LIST rows. Only then does it call `AdminPort.Invoke(<same endpoint>, "GET")` once per surviving row, with `param` set to that row's `key` value.
  - It merges the non-secret `rowGet.fields` into the projected row with their JSON types, and sets each derived field.
  - `beforeToday` is `true` exactly when the value is a `YYYY-MM-DD` string earlier than `+$Horolog`. It is `false` for `""` or `null`.
  - `truncated` still means the LIST answered more than `maxRows` rows.
  - A surviving row whose `key` value is not a non-empty string, or whose GET answers something other than an object, fails the read with 500 `INTERNAL`.
- **The descriptor.**
  ```json
  "route": "permissions/users", "area": "permissions", "labelKey": "userListLabel", "sideBarPosition": 1,
  "archetype": "list", "built": true, "refreshes": false, "refreshRates": [],
  "privileges": [{"resource": "%Admin_Secure", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "user", "secondaryEntityTypes": [], "scope": "instance", "parentScope": "",
  "id": {"kind": "single", "parts": []}, "primaryAction": {"id": "", "selfProtection": ""}, "rowActions": [],
  "context": {"fields": ["Name","FullName","Enabled","Type","Roles","ExpirationDate","Expired"], "secretFields": []},
  "emptyStateKey": "userListEmpty", "commandAliases": ["accounts"], "classicPage": "%CSP.UI.Portal.Users",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {"source": {"port": "admin", "endpoint": "Security.User", "type": "LIST",
      "rowGet": {"key": "Name", "param": "name", "fields": ["Roles","ExpirationDate"],
        "derived": [{"field": "Expired", "rule": "beforeToday", "from": "ExpirationDate"}]}},
    "fields": ["Name","FullName","Enabled","Type","Roles","ExpirationDate","Expired"],
    "filter": ["Name","FullName","Type","Roles"],
    "sort": {"fields": ["Name","FullName","Type","Roles"], "default": "Name", "direction": "asc"}, "paging": "cap"},
  "table": {"columns": [
      {"field": "Name", "labelKey": "tableColumnName", "kind": "name"},
      {"field": "FullName", "labelKey": "userColumnFullName", "kind": "text"},
      {"field": "Enabled", "labelKey": "tableColumnEnabled", "kind": "status"},
      {"field": "Expired", "labelKey": "userColumnExpired", "kind": "text"},
      {"field": "Type", "labelKey": "tableColumnType", "kind": "text"},
      {"field": "Roles", "labelKey": "userColumnRoles", "kind": "identifier"}],
    "emptyNextKey": "tableReadOnlyEmptyNext", "emptyAgentKey": ""},
  "toolIdentifier": "permissions.users"
  ```
- **The view rule (both engines and the corpus).** An array's text is its members' texts, each by the same rule, joined by `, `. The Roles cell, the filter and the sort all read that text. Every other value's text is unchanged.
- **DW-262.** `WebAppList` declares `%DB_IRISSYS:READ` after `%Admin_Secure:USE`.
- **DW-186.**
  - `Registry.ClassicLinkProblem` takes the parsed declaration. It and `classic-links.mjs` `classicLinkProblem` return the same sentence for every case in one corpus class, `OcuPilot.Test.ClassicLinkCorpus`.
  - That class holds XData `Cases`: `{name, declaration, expected}`, where `expected` is a sentence or `null`.
  - Quoted values use `"`. The unknown archetype reads `archetype "<a>" is not one OcuPilot.Screen.Archetype declares (AD-44)`. Every other sentence keeps its current wording.
  - Right after the archetype check, both engines refuse a `classicLinkExemption.exempt` that is not a JSON boolean with `classicLinkExemption.exempt is not a JSON boolean; declare true or false (AD-44)`.
- **The rowGet refusals are pinned the same way**, by `OcuPilot.Test.RowGetCorpus`: XData `Cases` holds a sound `declaration` and `{name, rowGet, expected}` cases, each replacing that declaration's `read.source.rowGet`.
- **Strings.** Copy only from EXPERIENCE.md Fixed strings, and write non-ASCII characters in code as `\uXXXX`.
- **Principals.** Security-object mutations and denied-principal checks run on the throwaway `ocupilot-ci` only.

**Never:**
- No per-screen route, handler, tool class, page, store or `areas/` file.
- No primary or row actions (Stories 7.2 and 8.2), no auto-refresh, and no link out.
- No `%DB_IRISSECURITY` pair: IRIS refuses to grant it to a role (probed).
- No detail call before the cap, no partial list on a non-404 row fault, and no client-side expiry computation.
- No `docker compose up`/`down`, and no principal created on live `ocupilot`. Send one `iris_execute_tests` call per message.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Detail merge | LIST row `_SYSTEM` + its GET | The row carries `Roles` `["%All",...]`, `ExpirationDate` `""` and `Expired` false. The Roles cell reads `%All, OcuPilotAdmin` | No error |
| Cap first | 3 LIST rows, `maxRows=2` | Exactly 2 GETs and 2 rows, `truncated` true | No error |
| Deleted between calls | One row's GET answers 404 | That row is dropped and the others stay. `truncated` still follows the LIST | No error |
| Row fault | One row's GET answers a non-404 fault | The whole read fails with that status, HTTP status and fault, and returns no rows | Passed through |
| Expired | `ExpirationDate` `2026-09-01`, instance date `2026-09-14` | `Expired` true, and "Account expired" reads "Yes" | No error |
| Not expired | `ExpirationDate` `""`, today, or a later date | `Expired` false, and the cell reads "No" | No error |
| Malformed date | `ExpirationDate` `09/01/2026` | 500 `INTERNAL` | Read fails |
| Disabled | `Enabled` false | Enabled reads "No" after an outline disc | No error |
| Missing system read | Caller holds `%Admin_Secure:USE`, not `%DB_IRISSYS:READ` | 403 `AUTH.NOPRIVILEGE` naming `%DB_IRISSYS:READ`, and the port is not called | Refused at the gate |
| Bad `rowGet` | For example, `derived[0].rule` `afterToday` | Both engines refuse with one sentence | Build or validate fails |
| Numeric exempt | `classicLinkExemption.exempt` `1` | Both engines refuse with the not-a-JSON-boolean sentence | Refused |

</intent-contract>

## Code Map

- `src/OcuPilot/Screen/Read.cls`
  - `Execute` `:58-112`: the LIST call is at `:79-80` and the projection loop at `:97-101`, which is where the per-row GET goes.
  - `Project` `:116` and `CopyValue` `:128` keep JSON types. `TextOf` `:270` is the view rule's text.
  - `PortClass` `:32` is the test seam.
- `src/OcuPilot/Screen/Registry.cls`
  - `ReadProblem` `:295`, whose source key list is at `:322`. Reusable helpers: `NameArrayProblem` `:529`, `UnknownKeyProblem` `:556`.
  - `ClassicLinkProblem` `:596` has 6 value arguments and one caller, `Validate` `:207`. `ClassicHrefProblem` `:643`.
- `ui/tools/screen-mirror.mjs`
  - `readProblem` `:387`, with its source key list at `:403`, and helpers `:352`, `:361`.
  - The emitted `ReadSource` interface is at `:747` and has no `rowGet` yet.
  - `extractXData` `:94`.
- `ui/tools/classic-links.mjs:100-135` `classicLinkProblem`, which reads `exempt === true`. `hrefProblem` `:75`. In the ObjectScript engine, `Base.cls:326` reads `''..NestedField`, so `1` counts as exempt.
- `ui/src/app/core/screen-read.ts:61` `textOf` answers `''` for an array. `table-model.ts:64` `cellView` uses it, so a Roles array would render "(none)" today.
- The corpus precedent: `Test/ReadViewCorpus.cls` (a case may carry its own `rows`), read by `ui/tools/screen-read.test.mjs:33,121`.
- Fixtures
  - `Test/EndpointFixture.cls`: `SaveQueryParams` `:100` records `name`, and the `list` mode at `:159` answers rows whatever the `Type`.
  - `Test/Read/ReadFixture.cls` routes to `PortFixture`. `Test/Read/Canned.cls` is the descriptor template.
- Tests to replace or extend
  - `Test/Descriptor.cls` is 552 lines. `:182-230` and `:253-294` call the 6-argument form, as does `:68`.
  - `classic-links.test.mjs:149-277`.
  - `Test/ReadTool.cls`: the production tool count `:78-90` and the grammar refusals `:272`.
  - `Test/ScreenRead.cls:176`: the field-presence test checks LIST keys only.
  - `Test/ScreenReadWire.cls:19`.
  - `Test/Wire.cls` (656 lines): `ADMINUSER` holds `%Admin_Operate:U` and code read (`:96-100`), and its navigation-map literal is at `:426`.
- Tripwires
  - `ui/tools/navigation.test.mjs:114` (built routes).
  - `LIVE_PAYLOAD` in `navigation-wire.test.mjs:84` and `rail-wire.spec.ts:85`.
  - `Install/Smoke.cls`: `CheckAreaLists` `:425-467`, `WEBAPPLISTTOOL` `:46`, the `arealists` line `:536`.
  - `Test/Smoke.cls:132-136,199-249`.
- Strings: `EXPERIENCE.md:315` is the web-apps row, and `strings.ts:307-321` holds its keys. `strings.test.mjs:432` requires unique values, so Name, Type, Enabled and the empty-state second line must be shared keys.
  - `webAppColumnName`, `webAppColumnType`, `webAppColumnEnabled` and `webAppListEmptyNext` are used only in `WebAppList.cls:60-67`, the mirror, `strings.ts` and `web-applications.browser-spec.mjs:182-185`.
  - "Expired" is already `proposalStatusExpired`.
- `ui/browser/web-applications.browser-spec.mjs:45-90`: the `irisSession` pattern that creates and deletes principals through `docker exec`, and refuses the live container.
- Vendor behavior, read through `GetTextAsString`: `%Api.Admin.Endpoints.Security.User` `ObjToJson` writes `ExpirationDate` through `%Api.Admin.Endpoint.ZDate3`, which gives `""` or `YYYY-MM-DD`. A missing user's GET answers the port's 404 `PORT.NOTFOUND`.

## Tasks & Acceptance

**Execution:**
- `src/OcuPilot/Screen/Registry.cls`, `ui/tools/screen-mirror.mjs`
  - Admit `rowGet` in `read.source` and refuse every violation in the Always list, with identical sentences.
  - Add `ReadRowGet` and the optional `rowGet` to the emitted `ReadSource`, then regenerate `screens.generated.ts`.
  - `ClassicLinkProblem(pDeclaration)` adds the exempt-type check. `Validate` passes the declaration, and `classic-links.mjs` uses the same sentences.
  - -- AD-36, AD-44, DW-186.
- `src/OcuPilot/Screen/Read.cls`: the rowGet execution and `beforeToday`. `TextOf` joins an array. `ui/src/app/core/screen-read.ts` `textOf` does the same. -- AD-36, NFR-1.
- `src/OcuPilot/Test/ReadViewCorpus.cls`: add cases with their own `rows`: a filter matching one array member, and a sort over an array column.
- `src/OcuPilot/Test/ClassicLinkCorpus.cls` (new): every refusal, one exempt case per archetype key (16), the 12 href values, `exempt: 1`, an absent `exempt`, and the sound shapes.
  - `Test/Descriptor.cls` runs the whole corpus with `AssertEquals` on each sentence and fails when there are zero cases. It replaces `:182-294`.
  - `classic-links.test.mjs` does the same through `extractXData`, replacing `:149-277`.
- `src/OcuPilot/Test/EndpointFixture.cls`
  - `SetDetails(pJson)` holds an object keyed by name. `SetDetailFault(pName, pMode)` takes `notfound` or `errorstatus`.
  - In `list` mode, a `TYPEGET` call answers the detail for its name, 404 for a name that has none, and appends the name to `Recorded("getNames")`.
- `src/OcuPilot/Test/ReadRowGet/Users.cls` (new fixture descriptor) and `src/OcuPilot/Test/ScreenReadRowGet.cls` (new), through `ReadFixture`: every Execution-row scenario in the matrix (AC4). The fixture sits in a package of its own so `Test/Read/Registry`'s three-tool count holds.
- `src/OcuPilot/Test/RowGetCorpus.cls` (new): one case per rowGet rule plus the sound shape.
  - `Test/ReadTool.cls` and `ui/tools/screen-mirror.test.mjs` each run every case with exact equality and fail on zero cases (AC5).
  - `ReadTool`'s production tools are exactly `permissions.users.read` and `webapp.list.read` (AC10).
- `src/OcuPilot/Screen/Descriptor/UserList.cls` (new) holds the declaration, with a doc comment covering the scope, the id, the pair set, rowGet and the instance clock. `WebAppList.cls` gets DW-262's pair and the renamed keys. Run `node ui/tools/screen-mirror.mjs`.
- `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md`: after `:315`, add `| "Users" · "Full name" · "Account expired" · "Roles" · "No users in <NAMESPACE>." | Users list side-bar entry and screen title (`:166`); its column headers beyond the shared Name, Type and Enabled, and its empty state, whose second line is the Web applications row's (`:113`, `epics.md` Story 2.6 AC1-AC2, `:238`) |`.
- `ui/src/app/core/strings.ts`, `ui/tools/strings.test.mjs`
  - Rename the four shared keys to `tableColumnName`, `tableColumnType`, `tableColumnEnabled` and `tableReadOnlyEmptyNext`.
  - Add `userListLabel`, `userColumnFullName`, `userColumnExpired`, `userColumnRoles` and `userListEmpty`.
  - Shift the `EXPERIENCE.md:<line>` comments below the new row.
- `src/OcuPilot/Test/ScreenRead.cls:176`: check rowGet fields against the live GET of the first row's key. Derived fields are exempt, and context fields check against the union.
- `src/OcuPilot/Test/ScreenReadWire.cls` (AC3). `src/OcuPilot/Test/Descriptor.cls`: `UserList` validates, and its classic page resolves in its own case.
- `src/OcuPilot/Test/WireSecurityRead.cls` (new, throwaway): principals `SECURE` (code read + `%Admin_Secure:U`), `SYSREAD` (code read + `%DB_IRISSYS:R`) and `BOTH`. They are created in `OnBeforeAllTests` and deleted and verified in `OnAfterAllTests`, following `Wire.cls:130-186` (AC6).
- `src/OcuPilot/Test/Wire.cls`, `ui/tools/navigation.test.mjs`, `navigation-wire.test.mjs`, `rail-wire.spec.ts`
  - `ADMINUSER`'s permissions area lists `permissions/users` as denied on `%Admin_Secure:USE`, and its read answers 403.
  - Add built routes, and update both `LIVE_PAYLOAD`s to exactly what Wire observes.
- `src/OcuPilot/Install/Smoke.cls`, `src/OcuPilot/Test/Smoke.cls`, `scripts/smoke.sh`, `README.md`
  - Add a `users` check over a new `USERLISTTOOL` parameter (`permissions.users`) at `maxRows=1`, in the pattern of `webapplications`.
  - `arealists` stays pending, names Logs, OS management, Tasks and Security and secrets, and says Epic 2.
- `ui/browser/users.browser-spec.mjs` (new, throwaway)
  - It refuses the live container.
  - Through `irisSession` it creates `OcuPilotDemoDisabled` (Enabled 0), `OcuPilotDemoExpired` and the `SECURE` principal.
    - `OcuPilotDemoExpired` is created enabled, then `%OpenId` on its lower-cased name sets `ExpirationDate` to `+$Horolog-30` and calls `%Save`, because `Modify` refuses a past date. Nothing ever signs in as it.
  - It deletes all three in teardown.
- `ui/browser/web-applications.browser-spec.mjs`: the renamed keys.

**Acceptance Criteria:**
- **AC1 (integration: route, rowGet and table, browser).** Given the throwaway, signed in as `_SYSTEM`, when `/ocupilot/permissions/users?ns=HSCUSTOM` opens:
  - exactly one `GET /api/ocupilot/screens/permissions.users/read` is issued
  - the headers read Name, Full name, Enabled, Account expired, Type, Roles
  - the `_SYSTEM` row's Roles cell contains `%All` in the code font
  - filtering on `%all` keeps `_SYSTEM`
- **AC2 (integration: state as a word, browser).** Given the AC1 list:
  - the `OcuPilotDemoDisabled` row's Enabled reads "No" after an outline disc
  - the `OcuPilotDemoExpired` row's Account expired reads "Yes" with no status disc, and its Enabled reads "Yes"
  - the `_SYSTEM` row's Account expired reads "No"
- **AC3 (route over HTTP, live reads only).** `ScreenReadWire` reads `maxRows=1000`:
  - 200, with `fields` equal to the seven declared fields and every row carrying exactly those keys
  - on every row, `Roles` is an array, `Expired` a boolean and `ExpirationDate` a string
  - `_SYSTEM` has `Roles` containing `%All` and `Expired` false
  - `maxRows=2` answers 2 rows, `truncated` true
- **AC4 (executor).** Given `Test/ReadRowGet/Users` over the fixture, every matrix row from Detail merge through Malformed date holds (with the dates computed relative to `+$Horolog`), and the `getNames` record shows no GET issued for a row beyond the cap.
- **AC5 (grammar).** Given `RowGetCorpus`, `ReadProblem` and `readProblem` each return every case's exact sentence, or none for the sound shape. `UserList` passes both, and the mirror emits its `rowGet`.
- **AC6 (pair set, throwaway).** Given `WireSecurityRead`:
  - `SECURE`: the `permissions/users` and `web-applications/list` entries are denied with `failedPair` `%DB_IRISSYS:READ`, and both reads answer 403 `AUTH.NOPRIVILEGE`.
  - `SYSREAD`: `permissions/users` is denied on `%Admin_Secure:USE`, and its read answers 403.
  - `BOTH`: both reads answer 200, and the users rows carry `Roles` arrays.
  - In the browser, `SECURE`'s deep link shows "You need %DB_IRISSYS:READ to open Users." and issues no read.
- **AC7 (id route).** Given AC1, when the `_SYSTEM` name link is followed, then the path ends `/permissions/users/_SYSTEM` and `data-id` reads `_SYSTEM`.
- **AC8 (DW-186).** Given `ClassicLinkCorpus`, when `Test/Descriptor` and `classic-links.test.mjs` run it, then every case's sentence (or null) matches exactly in both engines, `exempt: 1` included.
- **AC9 (view rule).** Given the corpus's array cases, both `ApplyView` and `applyView` produce their expected orders.
- **AC10 (tool and smoke).** The production tools are exactly the two named above. On the throwaway, `smoke.sh` reports `users` pass, and `arealists` stays pending without Permissions.

## Spec Change Log

- 2026-09-14, lead (owner-delegated decision on the plan's intent gap): amendment A accepted. AD-36 now allows one per-row detail call (`source.rowGet`) after the cap, merging declared detail fields; a 404 drops the row, any other row fault fails the read. epics.md Story 2.6 AC1 names roles from the detail call and AC2 defines expired as `ExpirationDate` set and earlier than today on the instance clock. Privilege pairs `%DB_IRISSYS:READ` + `%Admin_Secure:USE`, proven with a real principal on the throwaway (add `%DB_IRISSECURITY:READ` only if the principal proves it necessary). Re-plan from the amended text and write the intent contract now.
- 2026-09-14, lead (spec gate): the Account expired column is kind `text`, not `status` - a filled `success` disc on "Yes" would signal an expired account as healthy; the word carries the state (AC2). AD-36 now also names derived detail fields from a closed rule set (`beforeToday`).

## Review Triage Log

### 2026-09-14 — Review pass
- verdicts: 56 findings — high 0, medium 3, low 36, false 16, maybe-false 1
- findings:
  - `[medium]` `[defer]` Permissions and Web applications area pair sets name `%Admin_Secure:USE` alone while every screen in them needs `%DB_IRISSYS:READ` — pre-existing `Area.cls` set (Epic 1), exposed by DW-262; deferred.
  - `[maybe-false]` `[defer]` No rule makes other admin-port reads declare `%DB_IRISSYS:READ` — deferred medium (unverified); settle with a throwaway probe of a Process, Lock or Task LIST.
  - `[low]` `[reject]` A 404-dropped row leaves no log line — the drop is the specified behaviour; logging adds surface for a rare race.
  - `[false]` `[reject]` `beforeToday` may read the expiry day wrongly — throwaway probe: an account expiring today signs in, yesterday's does not.
  - `[low]` `[reject]` `EscalationRoles` not merged — the intent's descriptor fixes the detail fields.
  - `[low]` `[reject]` A derived field may read a secret detail field — no descriptor declares one; a new refusal would extend the intent's closed grammar.
  - `[low]` `[reject]` Enabled and Account expired are neither filterable nor sortable — the intent's descriptor fixes both lists.
  - `[low]` `[reject]` "No users in <NAMESPACE>." on an instance list — specified copy, same form as the web applications list.
  - `[low]` `[patch]` EXPERIENCE.md `:113` inventory omits Account expired — added to the Users list row.
  - `[low]` `[patch]` `WireSecurityRead` header claims more than its tests — added the SYSREAD web-apps denial and BOTH allowed-map assertions.
  - `[low]` `[reject]` `WireSecurityRead` has no live-container guard — same as `Wire.cls`; CI and the lead run it on the throwaway only.
  - `[low]` `[patch]` `ScreenReadWire` needs three users, says two — header and assertion now three.
  - `[low]` `[patch]` Field-drift test skips silently on a non-object detail — asserts the detail is an object.
  - `[low]` `[patch]` Corpus lost "no exemption is sound" for every archetype — 16 cases added; both engines require one per key.
  - `[low]` `[reject]` `Base.ClassicLinkExempt()` still coerces with `''` — both validators refuse a non-boolean before a declaration ships.
  - `[low]` `[reject]` Fixture keeps an earlier `maxRows` — `Clear()` runs per test and the LIST is each test's first call.
  - `[low]` `[reject]` Browser spec users carry the demo prefix — the demo fixture removes by recorded rows, not by prefix.
  - `[low]` `[reject]` Rule vocabulary kept in three places — one rule today; maintenance only.
  - `[low]` `[reject]` `CheckAreaLists` pairs lists by position — style only.
  - `[false]` `[reject]` Spec and ledger out of step — finalize writes the result; ledger closure is the lead's adjudication.
  - `[low]` `[reject]` Setup failure in `OnBeforeAllTests` skips teardown — same as `Wire.cls`, throwaway only, rare.
  - `[false]` `[reject]` 1,000 sequential GETs can time out — measured 100 GETs in 30.5 ms; NFR-1 accepts the linear cost.
  - `[low]` `[reject]` `derived.from` or `key` may name a secret — grouped with the secret-derived row above.
  - `[low]` `[patch]` Field-drift skip on non-object detail — grouped with the field-drift patch above.
  - `[low]` `[reject]` Midnight rollover can flake the expiry test — rare; a retry adds complexity.
  - `[low]` `[reject]` A non-object `classicLinkExemption` reads as none — unchanged from before this story in both engines.
  - `[low]` `[patch]` Per-archetype coverage predicate accepts an incomplete exemption — both engines now require reason, label, href and classic page.
  - `[low]` `[patch]` Browser `after()` would exec into the live container — returns early for `LIVE_CONTAINER`.
  - `[low]` `[reject]` Non-string href words differ between engines — outside the corpus; declarations are typed strings.
  - `[low]` `[reject]` SYSREAD also holds `%Admin_Operate:U` — needed to pass the admin gate; the fix would edit the spec; noted for the lead.
  - `[medium]` `[patch]` Secret stripping on the detail path is untested — added `SecretDetail` fixture and `TestASecretDetailFieldIsNotMerged`, mutation observed.
  - `[low]` `[patch]` "No detail call" for an empty key cannot fail — fixture records `getCount`; the assertion reads it, mutation observed.
  - `[medium]` `[patch]` Row-fault pass-through pinned only by a 500 `INTERNAL` fault — fixture `forbidden` mode; the test runs both, mutation observed.
  - `[low]` `[patch]` Shared view corpus lacks null, object and nested array members — two corpus cases added, both engines green.
  - `[false]` `[reject]` AC legs lack mutation lines — Rule 19 asks one per AC; every AC has one.
  - `[false]` `[reject]` Auto Run Result stale — written at finalize.
  - `[false]` `[reject]` Intent R1, empty `derived` accepted — the intent requires an array, not a non-empty one.
  - `[false]` `[reject]` Intent R2, GETs issued in the capped loop — no GET passes the cap and a fault fails the whole read, both tested.
  - `[false]` `[reject]` Intent R3, a dropped row is not refilled — refilling would issue a GET beyond the cap.
  - `[false]` `[reject]` Intent R4, absent date false and impossible date 500 — matches "false for empty or null" and the malformed-date row.
  - `[low]` `[reject]` Intent R5, non-object exemption reads as none — grouped with the non-object exemption row above.
  - `[false]` `[reject]` Intent R6, rowGet sentences quote with `'` — the `"` rule is DW-186's, and rowGet keeps `ReadProblem`'s convention in both engines.
  - `[low]` `[reject]` Intent R7, any non-status boolean cell reads Yes/No — required for Account expired; no screen filters a boolean.
  - `[false]` `[reject]` Intent R8, a strings row added — the Tasks list directs it.
  - `[false]` `[reject]` Intent R9, shared key rename — the intent's descriptor names the renamed keys.
  - `[low]` `[reject]` Intent R10, principal rule not enforced in code — grouped with the live-guard row above.
  - `[false]` `[reject]` Vendor 404 for a deleted user not probed — live probe: GET of a missing name answers 404 `PORT.NOTFOUND`.
  - `[low]` `[reject]` Exact joined roles checked only on fixtures — both engines' corpus and `cellView` pin the join.
  - `[low]` `[reject]` Port-not-called not asserted for this pair set — the generic gate test covers it; a called port would answer 500, not 403.
  - `[false]` `[reject]` `Validate` does not run at install — pre-existing; the matrix says build or validate.
  - `[low]` `[patch]` Grammar accepts `rowGet: null` but the emitted type does not — `rowGet?: ReadRowGet | null`, mirror regenerated.
  - `[low]` `[patch]` Classic-link coverage reduced — grouped with the 16-case corpus patch.
  - `[low]` `[reject]` `_SYSTEM` exercises no percent-encoding — AC7 as specified; the codec has its own corpus.
  - `[false]` `[reject]` Hand-edited captured payloads — `Wire` asserts the same entry over the wire.
  - `[low]` `[reject]` "Exactly 2 GETs" counted only on the fixture — only a fixture can count calls.
  - `[false]` `[reject]` `Execute` trusts the declaration — a malformed rule is caught as 500 `INTERNAL`.

## Design Notes

**Governing ADs:**
- AD-2, AD-27: every call goes through `AdminPort`, and the classic page is declared.
- AD-5: one descriptor, mirrored.
- AD-8, AD-29: the pair set.
- AD-13: `_SYSTEM` is one segment in an instance scope.
- AD-24: context fields, none of them secret.
- AD-36 as amended: `rowGet` after the cap, the 404 drop, and a failed row failing the whole read.
- AD-43: the screen does not refresh.
- AD-44: list archetype, no link-out, and the classic union.
- AD-45: the smoke check.

**Probes, 2026-09-14.**
- Live instance, reads only. LIST honors `maxRows`. The GET gives `ExpirationDate` as `""` or `YYYY-MM-DD` and `Roles` as an array. 100 GETs took 30.5 ms and 10 took 4.1 ms in process.
- Throwaway, principals created, probed and deleted:
  - code read + `%Admin_Secure:U`: `Security.User` LIST and GET, and `WebApp.App` LIST, all answer 500 `INTERNAL`.
  - adding `%DB_IRISSYS:R`: all three answer 200.
  - `%DB_IRISSYS:R` without `%Admin_Secure`: 403 `PORT.ACCESSDENIED`.
  - `Security.Roles.Create` with `%DB_IRISSECURITY` fails with ERROR #1499 "Cannot assign or grant resource".
  - `Security.Users.Modify` refuses a past or same-day `ExpirationDate` (#944), while `%OpenId` + `%Save` accepts one.
  - A sign-in attempt by the expired user left `Enabled` false.

**NFR-1.** GETs run only for the rows that survive the cap. At the default 1,000 rows that is about 0.3 s in process (inference from linear scaling of the measured rate), inside the 2 s first page. Raising the cap costs time linearly, as the existing no-ceiling decision accepts. The end-to-end 1,000-row timing stays with Story 2.10.

**Readings chosen.**
- **`Expired` is a server-derived boolean** rendered under the `text` kind as "Yes"/"No": a `status` disc would draw an expired account in the healthy colour (spec gate decision).
- **"Account expired" is authored copy.** "Expired" is taken by `proposalStatusExpired`, and values must be unique.
- **`derived` lives inside `rowGet`**, because the one rule reads a detail field. AD-36 names `rowGet` but not `derived`. See For the lead.
- **The four shared string keys are renamed** rather than reused under `webApp` names.

**Integration ACs:** AC1, AC2 (browser, throwaway), AC3 (HTTP, live), AC6 (HTTP and browser, throwaway), AC10 (smoke).

**Consumes:**
- 2.1 `AdminPort.Invoke`
- 2.3 `Screen.Read.Execute`, the read route and the tool registry
- 2.4 `ListPage` and `DataTable`
- 2.5 `WebAppList` shape and the field-presence test
- 1.9 gate and navigation map
- 1.15 link-out check
- 1.17 smoke

**Consumed-by:**
- `rowGet`: 4.2 and 4.4 dispatch `permissions.users.read` and its context; 6.2's roles, resources and services lists where their LISTs omit fields (inference); 5.9 re-reads after the first user write.
- The users list: 7.2 row actions, 8.2 Create, 9.1 editor at `permissions/users/:id`.
- `RowGetCorpus`: any later story that extends the rowGet grammar adds its cases there.
- The link-out corpus: `classic-links.mjs` (build), `Registry.Validate` (instance), and 6.4's OAuth 2.0 exemption.

**Ledger inbox:**
- DW-186 is addressed by the corpus task and AC8.
- DW-262 is confirmed by the probe and addressed by `WebAppList`'s pair and AC6.

## Verification

**Commands:**
- `cd ui && npm run build` -- expected: prebuild green, mirror up to date, classic-links clean.
- `cd ui && npm test` -- expected: every node and component test green.
- `uv run scripts/check-objectscript.py` and `uv run scripts/test_check_objectscript.py` -- expected: 0 problems.
- `bash scripts/lint-docs.sh` -- expected: 0 issues.
- Live `ocupilot-iris`, reads only, one call per message:
  - classes: `ScreenReadRowGet`, `ScreenRead`, `ReadTool`, `Descriptor`, `ScreenReadWire`, `Smoke`
  - expected: zero failures, confirmed in `%UnitTest_Result`.
- Throwaway (principal mutations here only):
  - `sh scripts/ci-throwaway.sh up`
  - `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.Wire --class OcuPilot.Test.WireSecurityRead`
  - `sh scripts/smoke.sh --container ocupilot-ci --user _SYSTEM --password SYS`
  - `npm run test:browser`
  - `sh scripts/ci-throwaway.sh down`
  - expected: all green, and `users` passes.

**Planned mutations (Rule 19; apply, observe red, revert, confirm the tree is byte-identical):**
- AC1: `Roles` dropped from `read.filter` -> the users browser spec's `%all` filter leg goes red.
- AC2: the Expired column kind becomes `status` -> the browser "Yes with no status disc" assertion goes red.
- AC3: `rowGet` removed from `UserList` -> the `ScreenReadWire` `Roles` array assertion goes red.
- AC4: the GET loop runs before the cap -> `ScreenReadRowGet`'s `getNames` assertion goes red. A 404 passed through as a fault -> the dropped-row test goes red.
- AC5: `Registry` accepts any `rule` -> `ReadTool`'s `RowGetCorpus` run goes red. The same change in `screen-mirror.mjs` turns `screen-mirror.test.mjs`'s run red.
- AC6: `%DB_IRISSYS:READ` removed from `UserList` -> `WireSecurityRead`'s `SECURE` 403 assertion goes red (the read answers 500). Removed from `WebAppList` -> its web-apps leg goes red.
- AC7: id kind `none` -> the browser path assertion goes red.
- AC8: the exempt-type check removed from `Registry` -> the `Test/Descriptor` corpus case `exempt: 1` goes red. A quote changed in `classic-links.mjs` -> `classic-links.test.mjs` goes red.
- AC9: `TextOf` answers `""` for an array -> the ObjectScript corpus array case goes red, and the same change turns `screen-read.test.mjs` red.
- AC10: `USERLISTTOOL` becomes `permissions.nosuch` -> `Smoke` goes red.

- mutation: `Read.Execute` issues the detail call for every list row and caps only the pushed rows (AC4) → `ScreenReadRowGet:TestTheDetailCallRunsOnlyForRowsThatSurviveTheCap` "exactly the two surviving rows had their detail read" and `TestARowDeletedBetweenTheCallsIsDropped` (run 1570).
- mutation: `DetailRow` drops `If tHttp = 404 Quit` (AC4) → `ScreenReadRowGet:TestARowDeletedBetweenTheCallsIsDropped` "the read succeeds" (run 1571).
- mutation: `rowGet` removed from `UserList` (AC3) → `ScreenReadWire:TestTheUsersListReadsOverTheWire` "every row carries exactly the declared keys, a Roles array..." (run 1572, method run; class re-run green in the live sweep).
- mutation: `RowGetProblem`'s rule check becomes `If 0` (AC5) → `ReadTool:TestEveryRowGetCorpusCaseGetsItsSentence` "a rule outside the closed set" (run 1573); `rowGetProblem`'s rule check becomes `if (false)` → `screen-mirror.test.mjs` "readProblem returns every rowGet sentence...".
- mutation: `ClassicLinkProblem`'s exempt-type check becomes `If 0` (AC8) → `Descriptor:TestEveryClassicLinkCorpusCaseGetsItsSentence` "exempt 1 is not a JSON boolean" and the other three non-boolean cases (run 1574); `classicLinkProblem` quotes the detail-archetype sentence with `'` → `classic-links.test.mjs` "archetype "list" may not declare an exemption".
- mutation: `ValueText` answers `""` for an array (AC9) → `ScreenRead:TestEveryCorpusCaseProducesItsOrder` "a filter matches one member of an array" and both other array cases (run 1575); `textOf` answers `''` for an array → `screen-read.test.mjs` "applyView produces every order..." and the `textOf` test.
- mutation: `cellView` gives a boolean a disc in any column → `table-model.test.mjs` "a boolean outside a status column reads Yes or No with no disc".
- mutation: `USERLISTTOOL` `permissions.nosuch` (AC10) → `Smoke:TestTheUsersListIsALiveCheck` "fail users -- ... answered HTTP 404" (run 1576, method run; class re-run green in the live sweep).
- mutation: `%DB_IRISSYS:READ` removed from `UserList` in the throwaway's scratch copy, reloaded (AC6) → `WireSecurityRead:TestAdminSecureAloneIsDeniedOnTheSystemDatabaseRead` "the users list is denied on %DB_IRISSYS:READ" and "permissions.users: the read is refused" (throwaway run 7); removed from `WebAppList` instead → "and so is the web applications list" and "webapp.list: the read is refused" (run 9); restored, run 10 green.
- mutation: `Roles` dropped from `read.filter`, mirror and bundle rebuilt and installed on the throwaway (AC1) → `users.browser-spec.mjs` AC1 `filterTo(page, '%all', '_SYSTEM')` timed out.
- mutation: the Expired column kind `status`, bundle rebuilt and installed (AC2) → `users.browser-spec.mjs` AC2 "with no status disc" (actual `{kind: 'success', next: 'Yes'}`).
- mutation: id kind `none`, bundle rebuilt and installed (AC7) → `users.browser-spec.mjs` AC7 (no name link to click).
- mutation: `DetailRow` sets `pHttpStatus` to 500 on a detail fault (Row fault) → `ScreenReadRowGet:TestAnyOtherDetailFaultFailsTheWholeRead` "forbidden: its HTTP status 403" (run 1624).
- mutation: `Execute` passes `read.fields` instead of the secret-free fields to `DetailRow` → `ScreenReadRowGet:TestASecretDetailFieldIsNotMerged` "and the row carries neither its name nor its value" (run 1624).
- mutation: `DetailRow`'s key guard drops the empty-string clause (AC4) → `ScreenReadRowGet:TestARowOrDetailTheCallCannotReadFailsTheRead` "and no detail call" (run 1624); restored, run 1625 green.
- mutation: the corpus's "wizard with no exemption" case deleted (AC8) → `Descriptor:TestEveryClassicLinkCorpusCaseGetsItsSentence` and `classic-links.test.mjs` "and a sound declaration with no exemption for archetype wizard" (run 1629, method run; class re-run green, run 1630).

## Auto Run Result

Status: done
Blocking condition: none

**This pass (implement and review).**
- Implemented the intent: `rowGet` in both grammars, the executor's detail call and `beforeToday`, the array view rule in both engines, `UserList`, DW-262's pair on `WebAppList`, the two corpora (DW-186 and rowGet), the users smoke check, renamed shared string keys and the EXPERIENCE.md row.
- New: `Screen/Descriptor/UserList.cls`, `Test/ClassicLinkCorpus.cls`, `Test/RowGetCorpus.cls`, `Test/ScreenReadRowGet.cls`, `Test/ReadRowGet/Users.cls` and `SecretDetail.cls`, `Test/WireSecurityRead.cls`, `ui/browser/users.browser-spec.mjs`. Changed: `Read.cls`, `Registry.cls`, `screen-mirror.mjs`, `classic-links.mjs`, `screen-read.ts`, `table-model.ts` (a boolean outside a `status` column reads Yes/No with no disc), `strings.ts`, `Install/Smoke.cls`, and the tests the Code Map names.
- Review: 56 findings, 12 entries patched (2 medium, 10 low), 2 deferred, the rest rejected or false as logged in the triage log. Follow-up review: false. The two patched mediums are test gaps now closed by mutation-verified tests; no unverified risk remains that can be named.
- Verification: `npm run build` and `npm test` (697 node, 238 component) green; `check-objectscript` 0 problems over 179 files and its harness OK; `lint-docs` 0. Live, one class per call: full sweep runs 1577-1622 green, and after the patches `ScreenReadRowGet` 8/8, `ScreenRead` 18/18, `Descriptor` 20/20, `ScreenReadWire` 4/4, `ReadTool` 12/12, `AdminPortFault` 15/15, `DerivedFields` 9/9, `Smoke` 14/14 (runs 1625-1634); live `smoke.sh` passed with `users` pass. Throwaway: `Wire` 16/16, `WireSecurityRead` 3/3, `smoke.sh` passed with `users` pass, `test:browser` 31/31, zero leftover principals, container down. Zero test principals on live.
- Probe (throwaway): an account whose `ExpirationDate` is today still signs in and one dated yesterday does not, so `beforeToday`'s strict comparison matches IRIS.

**For the lead:**
- `WireSecurityRead`'s `SYSREAD` principal also holds `%Admin_Operate:U`: without an `%Admin_*` resource the API's administrative gate answers `AUTH.NOADMIN` before the screen gate (inference, from the implementation report), so the Tasks line's "code read + `%DB_IRISSYS:R`" could not show the `%Admin_Secure:USE` denial.
- `epic-2-context.md` is stale: this story edits EXPERIENCE.md (a new strings row and the Users list inventory row).
