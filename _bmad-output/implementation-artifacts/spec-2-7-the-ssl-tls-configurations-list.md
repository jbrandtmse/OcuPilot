---
title: 'Story 2.7: The SSL/TLS configurations list'
type: 'feature'
created: '2026-09-14'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md'
warnings: ['oversized']
deferred:
  - summary: >-
      Inserting a Fixed strings row after EXPERIENCE.md `:316` shifts that file's own `:317`+ citations one line, the same drift DW-261 already records.
    evidence: |-
      Story 2.6's review deferred the identical shift as a DW-261 occurrence. `strings.test.mjs` re-resolves every `EXPERIENCE.md:<line>` comment, so the client half is caught; EXPERIENCE.md's internal cross-references are not.
    location: >-
      _bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md:317
    severity: low
---

# Story 2.7: The SSL/TLS configurations list

<intent-contract>

## Intent

**Problem:** The Security and secrets area — the one the contest names most specifically — has no built screen, so its rail entry gates on a set that nothing inside it exercises. Two ledger items sit on the same seam: nothing makes an admin-port read declare `%DB_IRISSYS:READ` (DW-264), and nothing checks that an area's declared pair set covers its screens' (DW-266), which is the defect DW-263 was.

**Approach:** Declare `OcuPilot.Screen.Descriptor.SslConfigList` over the `Security.SSLConfig` LIST, following `WebAppList`/`UserList` with no `rowGet`. Then close both ledger items by making the two declarations that must agree refuse each other: `ReadProblem` (both engines) refuses an admin-port read whose privileges omit `%DB_IRISSYS:READ`, and `Registry.Validate` refuses a screen declaring a pair its area does not.

## Boundaries & Constraints

**Always:**
- **The descriptor** (`Screen/Descriptor/SslConfigList.cls`, new):
  ```json
  "route": "security/ssl", "area": "security", "labelKey": "sslListLabel", "sideBarPosition": 1,
  "archetype": "list", "built": true, "refreshes": false, "refreshRates": [],
  "privileges": [{"resource": "%Admin_Secure", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "ssl-configuration", "secondaryEntityTypes": [], "scope": "instance", "parentScope": "",
  "id": {"kind": "single", "parts": []}, "primaryAction": {"id": "", "selfProtection": ""}, "rowActions": [],
  "context": {"fields": ["Name","Description","Enabled","Type"], "secretFields": []},
  "emptyStateKey": "sslListEmpty", "commandAliases": ["certificates"], "classicPage": "%CSP.UI.Portal.SSLList",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {"source": {"port": "admin", "endpoint": "Security.SSLConfig", "type": "LIST"},
    "fields": ["Name","Description","Enabled","Type"],
    "filter": ["Name","Description","Type"],
    "sort": {"fields": ["Name","Description","Type"], "default": "Name", "direction": "asc"}, "paging": "cap"},
  "table": {"columns": [
      {"field": "Name", "labelKey": "tableColumnName", "kind": "name"},
      {"field": "Description", "labelKey": "tableColumnDescription", "kind": "text"},
      {"field": "Enabled", "labelKey": "tableColumnEnabled", "kind": "status"},
      {"field": "Type", "labelKey": "tableColumnType", "kind": "text"}],
    "emptyNextKey": "tableReadOnlyEmptyNext", "emptyAgentKey": ""},
  "toolIdentifier": "security.ssl"
  ```
  The four fields are the live LIST row's whole key set, in the vendor's order (probed).
- **AC3 is met by omission and by the projection, and is pinned both ways.** The vendor LIST answers only those four keys — no `PrivateKeyPassword`, no `PrivateKeyFile`, no certificate or CA path — and `Read.Project` copies only `read.fields`, so nothing else can reach a caller. No `rowGet` is declared, so no `GET` is ever issued and the GET's `PrivateKeyFile`/`PrivateKeyType` never enter a read. `context.secretFields` stays empty because the read carries no secret to strip.
- **DW-264, in the grammar.** `Registry.ReadProblem` and `screen-mirror.mjs` `readProblem` each refuse, as their **last** check, a declaration whose `read.source.port` is `admin` and whose `privileges` omit the pair `%DB_IRISSYS` / `READ`, with one identical sentence: `read.source.port 'admin' requires the declared privileges to include %DB_IRISSYS:READ, because the port runs every endpoint in %SYS (AD-2, AD-8)`. Last, so no existing refusal changes which sentence a declaration gets.
- **DW-266, in `Validate`.** A public value-driven `Registry.AreaCoverageProblem(pAreaKey, pPairs)` returns, for the first declared pair the area does not declare, `area '<key>' does not declare <resource>:<permission>, which this screen requires, so the area would read allowed while the screen is refused (AD-8)`. `Validate` calls it per descriptor, **after** `MalformedPair`, and prefixes `<class>: `. Per-descriptor containment is the union check: every screen's set inside the area's set is exactly the area's set covering the union.
- **`Screen/Area.cls`** `security` gains `%DB_IRISSYS:READ` after `%Admin_Secure:USE`, and the class header's "Permissions and Web applications also name `%DB_IRISSYS:READ`" paragraph names three areas.
- **Strings.** Copy comes only from EXPERIENCE.md's Fixed strings table, and this story adds its row there first. Non-ASCII in code as `\uXXXX`.
- **Principals.** Security-object mutations and denied-principal checks run on the throwaway `ocupilot-ci` only.

**Never:**
- No per-screen route, handler, tool class, page, store or `areas/` file; no `rowGet`; no primary or row actions; no auto-refresh; no link-out (a `list` archetype never declares one, AD-44).
- No detail (`GET`) call from this screen at all — that is what keeps `PrivateKeyFile` out of AC3's reach.
- No `INFO`, `TEST` or `CHANGEPWD` type: the port reaches `GET`, `LIST`, `INFO` only, and this endpoint declares no `TYPEINFO`, so a "Test connection" affordance needs a port change and is not this story's.
- No area-coverage check in `screen-mirror.mjs`: the invariant is about the instance's gate and `Validate` is the roster check CI runs; a second copy would have no second consumer.
- No `docker compose up`/`down` against the live `ocupilot` container, and no principal created on it. One `iris_execute_tests` call per message.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Live read | `GET /api/ocupilot/screens/security.ssl/read?maxRows=1000` as a principal holding both pairs | 200; `fields` exactly the four declared; every row carries exactly those keys, `Enabled` a boolean, `Name`/`Description`/`Type` strings | No error |
| Vendor row shape | The live LIST row | No key named `PrivateKeyPassword`, `PrivateKeyFile`, `PrivateKeyType`, `CertificateFile`, `CAFile` or `CAPath` reaches `fields` or any row (AC3) | No error |
| Cap | `maxRows=1` against an instance carrying two or more configurations | 1 row, `truncated` true | No error |
| Demo row | `OCUPILOT_DEMO=1` container | `OcuPilotDemoTLS` is a row, its Description reads the fixture's sentence | No error |
| Disabled | A configuration with `Enabled` false | Enabled reads "No" after an outline disc | No error |
| Type verbatim | Vendor `Type` `"Client"` | The cell reads `Client`, the vendor's own word | No error |
| Missing system read | Caller holds `%Admin_Secure:USE`, not `%DB_IRISSYS:READ` | 403 `AUTH.NOPRIVILEGE` naming `%DB_IRISSYS:READ`; the port is not called | Refused at the gate |
| Missing admin resource | Caller holds `%DB_IRISSYS:READ` and no `%Admin_*` at all | 403 `AUTH.NOADMIN` before the screen gate | Refused at the router |
| Admin read without the pair (DW-264) | A descriptor declaring `port: admin` and `privileges` `[{%Admin_Secure,USE}]` | Both engines refuse with the one sentence | Build or validate fails |
| No read declared | A descriptor with no `read` and no privileges (Home) | No sentence — the rule is scoped to admin reads | No error |
| Area under-covers (DW-266) | A descriptor in `logs` declaring `%Admin_Secure:USE` | `Validate` refuses, naming the class, the area and the pair | Validate fails |

</intent-contract>

## Code Map

- `src/OcuPilot/Screen/Descriptor/WebAppList.cls` (76 lines) — the template: doc comment `:1-25`, `XData Declaration` `:29-74`. `UserList.cls` `:1-23`/`:27-82` is the same shape with `rowGet`.
- `src/OcuPilot/Screen/Descriptor/Base.cls` — discovery is `Registry.Descriptors()`, an SQL package scan (`Registry.cls:83`) filtered by `%Extends` (`:102`); adding a screen is adding one `.cls` under `Screen/Descriptor/`. `IsBuilt()` `:180-183`; `PrivilegePairs()` `:189-198`; `ContextSecretFields()` `:263-266`.
- `src/OcuPilot/Screen/Area.cls:47` — the `security` row, `%Admin_Secure:USE` alone today. Header `:18-21` is the paragraph to widen. `PairsFrom` `:137-150`, `PrivilegePairs` `:125-131`.
- `src/OcuPilot/Screen/Registry.cls` (913) — `Validate` `:128-227` (area existence `:144`, `MalformedPair` `:187-191`, `ReadProblem` `:179-183`, first-problem-only semantics); `RefreshProblem` `:239-269` is the public value-driven precedent and `:235-238` states why; `ReadProblem` `:296-414` (early-returns at `:304-308` when no `read` — the new check goes at the tail, after the `toolIdentifier` pattern); `SecretOverlap` `:660-670`; sentence style examples `:145`, `:175`, `:189`, `:214`.
- `src/OcuPilot/Screen/Gate.cls:69-85` — `RequiredPairs` unions the descriptor's own pairs and the classic page's custom resource only, never the area's (`:76-78`). `ClassicResource` `:135-139`; probed: `%CSP.UI.Portal.SSLList` carries no custom resource on this instance.
- `src/OcuPilot/Screen/Read.cls` — `Execute` `:72-137`; secret stripping is one place, `:104-109`, over `fields`; `Project` `:233-241` copies only `pFields`, which is the allowlist AC3 rests on.
- `src/OcuPilot/Port/AdminPort.cls` — `Invoke` `:268-320`; `RunSequence` `:521-564` with `Set $NAMESPACE = "%SYS"` at `:549`, unconditional, no predicate on endpoint, type or current namespace. `TYPESUFFIXES` `:84` is `GET,LIST,INFO`; this endpoint declares no `TYPEINFO`. `TEMPLATEARGUMENTS "Security.SSLConfig:1"` `:95` is the write-template path, not a read.
- `src/OcuPilot/Screen/Tool/FieldLists.cls:323-348` — the `Security.SSLConfig` **write** template (24 rows, `PrivateKeyPassword` at `:347`). Not the LIST shape; read-side secrecy is `context.secretFields`.
- `ui/tools/field-lists.mjs:59` `CREDENTIAL_RE` — the project's own credential vocabulary, reused by AC3's build-time guard.
- `ui/tools/screen-mirror.mjs` — `DESCRIPTOR_DIR` `:45`, `readSources` `:220-252`, `readProblem` `:387` with `read.source` keys at `:403`, `buildMirror`'s per-screen `readProblem` `:713-716`, `--check` `:960-967`. Regenerate with `node tools/screen-mirror.mjs` from `ui/`.
- `ui/src/app/core/navigation.ts:99-108` — `builtScreens()` orders by area rail position then `sideBarPosition`; `security` is rail 7, so the new route lands **last**.
- Fixtures that refusal (A) newly breaks — every one adds `%DB_IRISSYS:READ`: `Test/Read/Canned.cls:21`, `Test/Read/WebApps.cls:17`, `Test/ReadTwin/One.cls:20`, `Test/ReadTwin/Two.cls:20`, `Test/ReadBad/Cursor.cls:19`, `Test/ReadRowGet/SecretDetail.cls:20`, and `Test/RowGetCorpus.cls:16` (one edit, all 28 cases, both engines). `ui/tools/screen-mirror.test.mjs:281-293` and `:384-396` `sound()` bodies carry no `privileges` key at all.
- Corpus precedent: `src/OcuPilot/Test/RowGetCorpus.cls` — `XData Cases` `:10` holds `{declaration, cases}`, 28 cases `:36-63`, `Corpus()` `:69`, `DeclarationFor()` `:90`; run at `Test/ReadTool.cls:110-125` and `ui/tools/screen-mirror.test.mjs:353-375`.
- Negative-fixture precedent for a `Validate` refusal: `Test/Pair/Bad.cls` + `OcuPilot.Test.PairRegistry`, asserted at `Test/Navigation.cls:196`. `Install/Roster.cls:95` declares top-level `Test`, so a new `OcuPilot.Test.AreaPair` package needs no roster edit.
- Tripwires that move: `Test/ReadTool.cls:92-93` (2 → 3 tools, alphabetical) and its fixture count `:55` (unchanged — keep new fixtures out of `OcuPilot.Test.Read.`); `Test/Descriptor.cls:482` (`security` pair-set content pin), `:48-53` (production roster validates), `:84-100` (the per-descriptor case template); `Test/Navigation.cls:219` loop and doc `:206-211`; `Test/Wire.cls:391-392` (unchanged — `%Admin_Secure:USE` still fails first for `ADMINUSER`), `:443-467` (the per-screen denial template); `Test/WireSecurityRead.cls:18-33` principals, `:156-195` helpers, `:205-256` the three tests; `Test/ScreenReadWire.cls:77-133`; `Test/ScreenRead.cls:179-239` (auto-enrols the new descriptor — every declared field must be a live LIST key); `Install/Smoke.cls:46`, `:50`, `:436-473`, `:544`; `Test/Smoke.cls:133-137`, `:220-226`, `:234-244`, `:261-268`; `ui/tools/navigation.test.mjs:112-116`; `LIVE_PAYLOAD` `ui/tools/navigation-wire.test.mjs:100-109` and `ui/src/app/shell/rail-wire.spec.ts:101-110` (screen-entry shape at `navigation-wire.test.mjs:72-79`); `README.md:436-440`, `:444`.
- Strings: `ui/src/app/core/strings.ts` — shared `tableColumnName` `:309`, `tableColumnType` `:311`, `tableColumnEnabled` `:313`, `tableReadOnlyEmptyNext` `:321`; users block `:322-331` is the layout to copy; `navAreaSecurity` `:283` already exists. `'Description'` and `'SSL/TLS'` are not yet values anywhere (checked). `ui/tools/strings.test.mjs:297-302` caps the table at 154 literals and it holds 146 today, so three new literals fit.
- `ui/browser/users.browser-spec.mjs` — reuse verbatim: the `LIVE_CONTAINER` refusal `:73`, readiness gate `:74-75`, `signedInAtList` `:117-132` (which counts `/api/ocupilot/screens/` requests), `waitForRows` `:134-136`, `filterTo` `:142-159`, `describeRow` `:162-180`.
- Probed live, read-only, 2026-09-14 — `Security.SSLConfig` LIST row keys are exactly `Name` (string), `Description` (string), `Enabled` (boolean), `Type` (display string, e.g. `Client`); the endpoint's `ResourcesOR()` answers `%Admin_Secure`; its LIST is synchronous (`ShouldRunAsync()` is not overridden on this class); a GET of an absent name answers 404 `PORT.NOTFOUND`; `%SYS`'s default globals database is `IRISSYS`, resource `%DB_IRISSYS`.
- `src/OcuPilot/Install/Fixture.cls:308-335` `CreateSslConfig` — seeds `OcuPilotDemoTLS` (prefix `:68`, resolved `:98-101`) with `Description` only, guard-then-act `:312-322`, recorded `:330`, removed `:917-924`. The X.509 credential (`:348-382`) is a separate `%SYS.X509Credentials` object and is not this list's subject.

## Tasks & Acceptance

**Execution:**
- `src/OcuPilot/Screen/Registry.cls` — add the admin-read privilege check as the **last** arm of `ReadProblem`, and the public `AreaCoverageProblem(pAreaKey, pPairs)`; call it from `Validate` immediately after `MalformedPair`, prefixed with the class name. Doc-comment both with the sentence they own and why they are public. — DW-264, DW-266, AD-8.
- `ui/tools/screen-mirror.mjs` — the same last-arm check in `readProblem`, same sentence, then regenerate `ui/src/app/core/screens.generated.ts`. — DW-264.
- `src/OcuPilot/Screen/Area.cls` — `security` gains `%DB_IRISSYS:READ`; widen the header paragraph at `:18-21` to name Permissions, Web applications and Security and secrets. — DW-266, AD-8.
- `src/OcuPilot/Screen/Descriptor/SslConfigList.cls` (new) — the declaration above, with a doc comment covering the scope, the id, the pair set, why there is no `rowGet`, and that the four fields are the live LIST row's whole key set. Run `node ui/tools/screen-mirror.mjs`. — AD-2, AD-5, AD-13, AD-36, AD-44.
- `src/OcuPilot/Test/AdminPairCorpus.cls` (new) — `XData Cases` in `RowGetCorpus`'s shape: one sound declaration plus cases replacing `privileges` — both pairs (null), `%Admin_Secure:USE` alone, `[]`, `%DB_IRISSYS:WRITE`, `%DB_IRISSYS:READ` alone (null), and one case whose declaration carries no `read` (null). `Corpus()` and `DeclarationFor()` accessors.
  - `src/OcuPilot/Test/ReadTool.cls` and `ui/tools/screen-mirror.test.mjs` each run every case with exact equality and fail on zero cases (AC5).
- `src/OcuPilot/Test/AreaPair/Bad.cls` and `src/OcuPilot/Test/AreaPairRegistry.cls` (new) — a descriptor in area `logs` declaring `%Admin_Secure:USE` and **no read**, in a package of its own so no other registry enumerates it; the registry points `DescriptorPackage()` at it. Pattern: `Test/Pair/Bad.cls` + `PairRegistry`.
- Fixtures the new refusal reaches — add `%DB_IRISSYS:READ`: `Test/Read/Canned.cls`, `Test/Read/WebApps.cls`, `Test/ReadTwin/One.cls`, `Test/ReadTwin/Two.cls`, `Test/ReadBad/Cursor.cls`, `Test/ReadRowGet/SecretDetail.cls`, `Test/RowGetCorpus.cls`; add a `privileges` key to both `sound()` bodies in `ui/tools/screen-mirror.test.mjs`.
- `src/OcuPilot/Test/Descriptor.cls` — the `security` row at `:482` becomes `%Admin_Secure:USE, %DB_IRISSYS:READ`; add `TestTheSslConfigurationsListValidatesAndNamesItsClassicPageInItsOwnCase` in the shape of `:84-100`; add the DW-266 test: `AreaPairRegistry` refuses naming class, area and pair, the value-driven helper answers for a covered and an uncovered set, and the production roster still validates (AC7).
- `src/OcuPilot/Test/ReadTool.cls` — production tools become exactly `permissions.users.read,security.ssl.read,webapp.list.read`, count 3 (AC8); rename the `"security.ssl.detail"` mutation literals at `:328` and `:395` to `"security.nosuch.detail"` so they do not read as a real screen's tool.
- `src/OcuPilot/Test/ScreenReadWire.cls` — `TestTheSslConfigurationsListReadsOverTheWire`: `maxRows=1000` answers 200 with the four declared fields and per-row types; every row's key set is exactly those four and carries none of the six key-material names; `maxRows=1` answers 1 row with `truncated` true. Header states the precondition: at least two SSL/TLS configurations (AC1, AC3).
- `ui/tools/screen-mirror.test.mjs` — a build-time guard over every production descriptor: no `read.fields`, `read.filter`, `read.sort.fields` or `table.columns[].field` name matches `CREDENTIAL_RE` imported from `field-lists.mjs` (AC3).
- `src/OcuPilot/Test/WireSecurityRead.cls` — extend all three principals to the SSL list: `SECURE` is denied on `%DB_IRISSYS:READ` for the `security/ssl` screen, the `security` area and the read; `SYSREAD` is denied on `%Admin_Secure:USE`; `BOTH` reads 200 with rows carrying the four fields. Update the class header, which today names two lists (AC6).
- `src/OcuPilot/Test/Wire.cls` — add `TestTheSslConfigurationsListIsDeniedToAPrincipalWithoutAdminSecure` in the shape of `:443-467`, with the `security` area's whole-entry literal and a 403 on `security.ssl`. `:391-392` is unchanged and a comment says why.
- `src/OcuPilot/Test/Navigation.cls` — add `"security"` to the `:219` loop and name it in the doc at `:206-211`.
- `src/OcuPilot/Install/Smoke.cls`, `src/OcuPilot/Test/Smoke.cls`, `README.md` — add `Parameter SSLLISTTOOL = "security.ssl"`, widen `CheckAreaLists` to three checks named `webapplications,users,ssl`, drop "Security and secrets" from the `arealists` pending line at `:544`; move it to the absent list in `Test/Smoke.cls:133-137`, add `"ssl"` to `:264` and the fail leg at `:234-244`, and add `TestTheSslListIsALiveCheck`; update `README.md:436-440` and `:444` (AC8).
- `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md` — give `:135`'s Needs cell the column list (`name, description, enabled, type; filter (FR-42)`), then after `:316` add: ``| "SSL/TLS" · "Description" · "No SSL/TLS configurations in <NAMESPACE>." | SSL/TLS configurations list side-bar entry and screen title (`:168`); its column header beyond the shared Name, Type and Enabled, and its empty state, whose second line is the Web applications row's (`:135`, `epics.md` Story 2.7, `:238`) |``
- `ui/src/app/core/strings.ts`, `ui/tools/strings.test.mjs` — add `sslListLabel`, `tableColumnDescription` and `sslListEmpty` with `/** EXPERIENCE.md:317 */` comments, and shift every comment citing a line below the insertion.
- `ui/tools/navigation.test.mjs`, `ui/tools/navigation-wire.test.mjs`, `ui/src/app/shell/rail-wire.spec.ts` — built routes gain `'security/ssl'` **last**; both `LIVE_PAYLOAD`s gain the `security` area's screen entry, set to exactly what `Wire` observes.
- `ui/browser/ssl.browser-spec.mjs` (new, throwaway, `OCUPILOT_DEMO=1`) — reuses `users.browser-spec.mjs`'s helpers verbatim and refuses the live container. Covers AC1, AC2, AC3's response half and AC4. No principal is created: the denial is proven over HTTP by `WireSecurityRead`.

**Acceptance Criteria:**
- **AC1 (integration: route, table and filter, browser).** Given the throwaway signed in as `_SYSTEM`, when `/ocupilot/security/ssl?ns=HSCUSTOM` opens, then exactly one `GET /api/ocupilot/screens/security.ssl/read` is issued, the headers read Name, Description, Enabled, Type, at least two rows render, and the Name cell is a link in the code font; and when a substring of one configuration's name is typed into the filter, then that row stays and the others go.
- **AC2 (integration: the demo row, browser).** Given an `OCUPILOT_DEMO=1` throwaway, when the AC1 list renders, then the `OcuPilotDemoTLS` row is present and its Description cell reads the fixture's sentence, so the README walkthrough has something to show.
- **AC3 (no key material).** Given the AC1 read, when its response body is inspected, then `fields` is exactly the four declared fields and no row carries a key named `PrivateKeyPassword`, `PrivateKeyFile`, `PrivateKeyType`, `CertificateFile`, `CAFile` or `CAPath`. Given the live endpoint, when `ScreenReadWire` reads it over HTTP, then the same holds. Given every production descriptor, when the build runs, then none names a read, filter, sort or column field matching `CREDENTIAL_RE`.
- **AC4 (only built screens appear, browser).** Given the AC1 list, when the side bar renders, then the Security and secrets area lists exactly one entry, SSL/TLS, it is the current item, and no other entry or dead link appears for that area.
- **AC5 (DW-264, grammar).** Given `AdminPairCorpus`, when `ReadProblem` and `readProblem` each run every case, then each returns that case's exact sentence, or none for the sound and read-less shapes; and when each runs over `SslConfigList`, `UserList` and `WebAppList`, then all three pass in both engines.
- **AC6 (DW-264, pair set proven on the throwaway).** Given `WireSecurityRead`'s three principals, when each reads the navigation map and `security.ssl`, then `SECURE` is denied on `%DB_IRISSYS:READ` for the `security/ssl` screen, the `security` area and the read (403 `AUTH.NOPRIVILEGE`); `SYSREAD` is denied on `%Admin_Secure:USE`; and `BOTH` reads 200 with rows carrying the four declared fields.
- **AC7 (DW-266, coverage refused).** Given `AreaPairRegistry`, when `Registry.Validate` runs over it, then it answers a not-OK status whose problem names the class, the area `logs` and the pair `%Admin_Secure:USE`. Given a covered and an uncovered pair set, when `AreaCoverageProblem` runs over each, then it answers `""` and that sentence respectively. Given the production roster, when `Validate` runs over it, then it validates.
- **AC8 (tool roster and smoke).** Given the production registries, when the read tools are listed, then they are exactly `permissions.users.read`, `security.ssl.read` and `webapp.list.read`. Given the throwaway, when `smoke.sh` runs, then it reports `ssl` pass and its `arealists` pending note names Logs, OS management and Tasks, no longer Security and secrets.

## Spec Change Log

## Review Triage Log

## Design Notes

**Governing ADs:**
- AD-2, AD-27: the read goes through `AdminPort`, which is the only caller of `%Api.Admin.*`.
- AD-5: one descriptor, mirrored; adding a screen edits no router or nav list.
- AD-8, AD-29: the pair set, checked per call, never cached, the failing pair named.
- AD-13: a name-keyed configuration is a `single` id in an `instance` scope.
- AD-16: the port's `%SYS` switch by explicit save and restore is the mechanism DW-264 turns on.
- AD-24: context fields, none secret.
- AD-35, Conventions › Secrets: no key material on a surface OcuPilot displays; redaction is schema-driven, and here the schema is `read.fields`.
- AD-36: one bounded read serves screen and tool; no `rowGet` is declared.
- AD-43: the screen does not refresh (it is not on EXPERIENCE.md `:561`'s roster of six).
- AD-44: `list` archetype, no link-out, and the classic union — `%CSP.UI.Portal.SSLList` is the page this screen replaces (probed: compiled, parented to Portal Home, and carrying no custom resource on this instance, so the union adds nothing today).
- AD-45: the smoke check.

**Probes, 2026-09-14, live instance, reads only.** Recorded above in the Code Map. Two are load-bearing and neither is a generalization from a sample:
- The LIST row's four keys were read from every row of the live answer, and the vendor builds them by excluding two columns from `Security.SSLConfigs`' `List` query — so `PrivateKeyPassword`, which that class's separate `Detail` query does carry, is absent by the endpoint's construction, not by luck.
- **DW-264's population claim is settled from the code path, not from a probe.** `AdminPort.RunSequence:549` sets `$NAMESPACE` to `%SYS` with no predicate on endpoint, type or current namespace, and every request type reaches it (`Invoke:299`, and the async poll at `:444`). IRIS requires READ on a namespace's default globals database to make it current; `%SYS`'s is `IRISSYS`, resource `%DB_IRISSYS` (read off this instance). So the requirement belongs to the port and therefore to every admin-port read — one code path, not five endpoints extrapolated. AC6 proves the consequence for this endpoint with a real principal, which is what the ledger asked for.

**Readings chosen.**
- **No `rowGet`.** The GET carries 18 fields the LIST omits, including `PrivateKeyFile` and `PrivateKeyType`, and this story's ACs need none of them. Declining the detail call is what makes AC3 true by construction rather than by filtering, and `Type` would otherwise have to hold two JSON types at once (a display string in LIST, a logical integer in GET).
- **The check lands in `ReadProblem`, not in a new validator**, because it already receives the whole declaration and both engines already hold its sentences identically; a new refusal would otherwise be a third place to keep in step.
- **`AreaCoverageProblem` is per-descriptor.** "Every screen's set inside its area's set" and "the area covers the union of its screens' sets" are the same statement, and the per-descriptor form reports the offending class, which is the sentence style `Validate` already uses.
- **`security.ssl`, not `security.ssl-configurations`.** The tool-identifier grammar is two lower-case segments; `security.ssl.detail` appears today only as a value a refusal test expects to reject, and this story renames it so the two cannot be confused.
- **`tableColumnDescription`, not `sslColumnDescription`.** "Description" is a column the X.509, LDAP and task lists will each want, and `strings.test.mjs` requires every value to be unique, so the second list to need it would have to rename this one — the rename Story 2.6 had to do for Name, Type and Enabled. Naming it shared at its first use avoids that.

**Integration ACs:** AC1, AC2, AC4 (browser, throwaway), AC3 and AC6 (HTTP, live and throwaway), AC8 (smoke).

**Consumes:** 2.1 `AdminPort.Invoke`; 2.3 `Screen.Read.Execute`, the read route and the tool registry; 2.4 `ListPage` and `DataTable`; 2.5/2.6 the list-screen shape, the shared string keys and `Test/ScreenRead`'s field-presence guard; 1.4 the demo fixture's `CreateSslConfig`; 1.9 the gate and navigation map; 1.15 the link-out check; 1.17 the smoke script.

**Consumed-by:**
- The `%DB_IRISSYS:READ` refusal: every later admin-port list — 2.8 tasks, 2.9 processes, 2.10 audit — inherits it at build time, and 6.x's roles, resources and services lists after them.
- `AreaCoverageProblem`: 2.8 and 2.9 are the first screens in Tasks and OS management, so each is the first to have its area's set checked against a real screen.
- `AdminPairCorpus`: any later story that changes the admin-read privilege rule adds its cases there.
- The SSL/TLS list: 9.x's SSL/TLS editor at `security/ssl/:id`, 12.x's OAuth work in the same area, and Epic 4, which dispatches `security.ssl.read`.

**Ledger inbox:** DW-264 is addressed by the grammar refusal (AC5) and the throwaway proof (AC6). DW-266 is addressed by `AreaCoverageProblem` and the `security` area's widened set (AC7).

## Verification

**Commands:**
- `cd ui && npm run build` — expected: prebuild green (six checkers), mirror up to date, classic-links clean.
- `cd ui && npm test` — expected: every node and component test green.
- `uv run scripts/check-objectscript.py` and `uv run scripts/test_check_objectscript.py` — expected: 0 problems.
- `bash scripts/lint-docs.sh` — expected: 0 issues.
- Live `ocupilot-iris`, reads only, **one class per message**: `Descriptor`, `Navigation`, `ReadTool`, `ScreenRead`, `ScreenReadWire`, `Smoke`, `AdminPortSync` — expected: zero failures, confirmed in `%UnitTest_Result`.
- Throwaway (every principal mutation here, none on live):
  - `sh scripts/ci-throwaway.sh up`
  - `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.Wire --class OcuPilot.Test.WireSecurityRead --class OcuPilot.Test.Descriptor --class OcuPilot.Test.Navigation`
  - `sh scripts/smoke.sh --container ocupilot-ci --user _SYSTEM --password SYS` — expected: `ssl` pass.
  - `OCUPILOT_BROWSER_EXECUTABLE="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" npm run test:browser`
  - `sh scripts/ci-throwaway.sh down` — expected: all green, zero principals left on either instance.

**Planned mutations (Rule 19; apply, observe red, revert, confirm `git status --short` and `git diff --stat` are unchanged):**
- mutation: `Description` dropped from `read.filter` (AC1) → `ssl.browser-spec.mjs`'s filter leg goes red.
- mutation: the demo fixture's `Description` value changed in `Install/Fixture.cls` (AC2) → `ssl.browser-spec.mjs`'s `OcuPilotDemoTLS` description assertion goes red.
- mutation: `PrivateKeyFile` added to `read.fields` with a `rowGet` over the same endpoint (AC3) → `ScreenReadWire`'s key-set assertion goes red; separately, a production column field renamed to `ApiKey` → `screen-mirror.test.mjs`'s `CREDENTIAL_RE` guard goes red.
- mutation: `built` set false on `SslConfigList` (AC4) → `ssl.browser-spec.mjs`'s side-bar assertion goes red and `navigation.test.mjs:112-116` goes red.
- mutation: the new privilege arm of `ReadProblem` becomes `If 0` (AC5) → `ReadTool`'s `AdminPairCorpus` run goes red; the same change in `readProblem` turns `screen-mirror.test.mjs`'s corpus run red.
- mutation: `%DB_IRISSYS:READ` removed from `SslConfigList` in the throwaway's scratch copy and reloaded (AC6) → `WireSecurityRead`'s `SECURE` SSL assertions go red (the read answers 500, not 403).
- mutation: `AreaCoverageProblem`'s comparison returns `""` unconditionally (AC7) → the `AreaPairRegistry` test goes red; separately, `%DB_IRISSYS:READ` dropped from the `security` area in `Area.cls` → the same test's production-roster leg and `Descriptor`'s area content pin go red.
- mutation: `SSLLISTTOOL` becomes `security.nosuch` (AC8) → `Smoke:TestTheSslListIsALiveCheck` goes red.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none

Planned only; nothing implemented. The spec records the live read-only probes that settled the LIST key set, the endpoint's resource, the demo fixture's `CreateSslConfig`, and the classic page, plus the code-path argument that generalizes DW-264 to every admin-port read. The throwaway proof of the pair set and every mutation above are the implement stage's work.
