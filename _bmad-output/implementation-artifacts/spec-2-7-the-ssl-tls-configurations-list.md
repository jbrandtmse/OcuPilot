---
title: 'Story 2.7: The SSL/TLS configurations list'
type: 'feature'
created: '2026-09-14'
status: 'done'
baseline_revision: 'ff1d1400308092c62dcdecf80255a8d155dab102'
baseline_commit: 'ff1d1400308092c62dcdecf80255a8d155dab102'
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
  - summary: >-
      The users and web applications browser specs chain `filterTo` with no clear between legs, so each leg can be satisfied by the rows the previous leg left — the vacuity this story found in its own copy and fixed only there.
    evidence: |-
      Story 2.7's AC1 filter mutation stayed green until `clearFilter` was added; `filterTo`'s `waitForFunction` is over the rows rendered now, so a text the surviving row already carries satisfies it before the new filter narrows anything. `ui/browser/users.browser-spec.mjs:214,219,225` and `ui/browser/web-applications.browser-spec.mjs:193-212` chain the same helper, the latter over five declared filter fields. The helpers are duplicated verbatim across all three specs, which is why the fix landed in one copy; `ui/browser.config.mjs` is the shared module they would move to.
    location: >-
      ui/browser/users.browser-spec.mjs:214
    severity: medium
  - summary: >-
      `CREDENTIAL_RE` is suffix-anchored, so the repo-wide build guard matches one of the six key-material names AC3 enumerates.
    evidence: |-
      `ui/tools/field-lists.mjs:59` is `/(password|passwd|pwd|secret|secret64|apikey|privatekey|token)$|^key$/i`: of `PrivateKeyPassword`, `PrivateKeyFile`, `PrivateKeyType`, `CertificateFile`, `CAFile` and `CAPath` it matches the first alone. The other five are pinned by name for this screen in `Test/Descriptor.cls` and `Test/ScreenReadWire.cls`, both hard-coding the class under test, so later admin-port lists inherit no equivalent refusal. Widening the pattern changes the vocabulary `field-lists.mjs` classifies 47 lists and 451 rows with, so it is not an in-story edit.
    location: >-
      ui/tools/field-lists.mjs:59
    severity: low
  - summary: >-
      Five `//`-style `EXPERIENCE.md:<line>` citations in `strings.ts` resolve three lines above their anchors, and `strings.test.mjs` re-resolves only the `/** ... */` form.
    evidence: |-
      `ui/src/app/core/strings.ts:24,351,387,392,398` cite `:606`, `:329`, `:330` and `:333`; the anchors are EXPERIENCE.md `:609`, `:332`, `:333` and `:336`. The offset predates this story — it was three before the Fixed-strings insertion and three after the mechanical +1 — and `strings.test.mjs:481` only re-resolves the doc-comment form, so nothing catches it. A DW-261 occurrence on a surface the client half does not cover.
    location: >-
      ui/src/app/core/strings.ts:24
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

### Review Findings

Code review 2026-09-14, four layers at the Opus tier. 0 decision-needed, 6 patch (all applied), 0 defer, 14 rejected. No high, one medium.

- [x] `[Review][Patch]` `[medium]` Each area-list smoke check now proves **which** screen it read [`src/OcuPilot/Install/Smoke.cls:449`] — a report line carries the check's name and its outcome, never the tool behind it, so transposing two `$Select` arms left every assertion in `Test/Smoke.cls` green while each check read the other's list. `SmokeListFault` records the screen-read paths; `TestEachAreaListCheckReadsItsOwnScreen` pins the three. Epic 2 adds three more arms to this loop.
- [x] `[Review][Patch]` `AreaCoverageProblem`'s "the first of `pPairs`" contract was unpinned [`src/OcuPilot/Test/Descriptor.cls`] — every case used a covered, empty, or one-element uncovered set, so reporting the last uncovered pair instead of the first stayed green.
- [x] `[Review][Patch]` The repo-wide credential guard skipped `context.fields` [`ui/tools/screen-mirror.test.mjs`] — nothing constrains `context.fields` to `read.fields`, so a field name the agent context carries (AD-24) had no repo-wide refusal. `context.secretFields` stays out: naming key material there is what it is for.
- [x] `[Review][Patch]` AC3's browser key-material assertions passed on an empty captured body [`ui/browser/ssl.browser-spec.mjs:209`] — `signedInAtList` resolves `text: ''` when `response.text()` rejects, and all six `includes(...) === false` assertions hold against `''`.
- [x] `[Review][Patch]` Five `//`-form `EXPERIENCE.md` citations corrected at their origin [`ui/src/app/core/strings.ts:24,351,387,392,398`] — `:606`→`:609`, `:329`→`:332`, `:330`→`:333`, `:333`→`:336`, verified line by line against the document. The mechanical `+1` this story applied was right; the three-line offset under it was not.
- [x] `[Review][Patch]` A doc comment narrated the review round [`src/OcuPilot/Test/Smoke.cls`] — "Story 2.7 review fix" and "Observed and reverted" removed (CLAUDE.md, Prose discipline).

**Rejected.**

- `[false]` "`ReadProblem` enforces only half the admin contract — a descriptor declaring `%DB_IRISSYS:READ` alone is reachable by a principal with no `%Admin_*`." `Api/Router.cls:267` refuses such a principal with 403 `AUTH.NOADMIN` before any screen gate. `AdminPairCorpus` pins the shape as sound deliberately; DW-264 names one pair.
- `[low]` The admin arm can pre-empt `MalformedPair`'s sentence for a declaration wrong in two ways (`Validate` runs `ReadProblem` at `:181`, `MalformedPair` at `:189`). Verified reachable, but only when the malformed pair **is** the `%DB_IRISSYS` one — and then the DW-264 sentence is still true, because `Area.PairsFrom` drops a malformed pair, so the declaration genuinely does not declare the requirement. Both shapes are refused; only the wording differs, and the fix reorders `Validate` for every descriptor.
- `[low]` `AreaCoverageProblem` checks area ⊇ screen only, so a surplus area pair gates a rail item no screen needs. `Screen/Area.cls:24-30` already chooses that direction ("a false denial rather than a false promise") for Tasks' `%Admin_Task`.
- `[low]` `AreaCoverageProblem` has no `screen-mirror.mjs` twin while its DW-264 sibling gates `npm run build`. Spec-bound: `## Boundaries & Constraints` › Never chooses `Validate` as the single home and says why.
- `[low]` The `port === 'admin'` predicate is unreachable (an earlier arm refuses every non-admin port). Forward-correct: removing it widens the rule silently the moment a second port lands.
- `[low]` `privileges` shaped as a JSON object diverges between engines (ObjectScript accepts an object of pair objects, JS refuses any non-array). An authoring error that fails `npm run build` loudly; no descriptor can reach it.
- `[low]` `Test/Smoke.cls`'s source-text scrape is brittle against behaviour-preserving edits to `CheckAreaLists` (`$Case`, a wrapped `$Select`, `tI=4` without spaces). It pins the declaration's shape, which is what it is for; the behavioural half is now `TestEachAreaListCheckReadsItsOwnScreen`.
- `[low]` `ScreenReadWire`'s header states the two-configuration precondition but not where the second row comes from. Its siblings state "at least three web applications and three users" the same way.
- `[low]` `SslConfigList.cls`'s header names an unpinned count ("eighteen further fields"). Recorded as a probe in `## Design Notes`; the load-bearing sentence beside it stands without the number.
- `[low]` `commandAliases: ["certificates"]` has no test. Spec-dictated value, and no descriptor's aliases are exercised yet.
- `[low]` No SSL row exercises `Enabled` false, and `read.filter`'s `Type` is not filtered end to end. Both are pinned by declaration equality in `Descriptor.cls` and on `cellView`'s shared path; already dispositioned in-pass.
- `[low]` AC3 calls the credential guard "build-time" while it runs under `npm test`. CI's `gates` job runs `npm test` on every push at three Node versions; the fix edits the spec under review.
- `[low]` `## Auto Run Result`'s counts do not reconcile with the triage log ("twenty-one rejected" against 17 `[reject]` rows), and it says "seven fixture descriptors" then "the six". Real, but the fix edits the spec under review.
- `[low]` The spec frontmatter reads `done` while `sprint-status.yaml` reads `review`. Expected mid-pipeline state — this stage sets the final status.

## Spec Change Log

## Review Triage Log

### 2026-09-14 — Review pass

- verdicts: 35 findings — high 0, medium 4, low 30, false 1, maybe-false 0
- findings:
  - `[low]` `[reject]` Spec's `## Auto Run Result` still reads "Planned only; nothing implemented" — the fix is an edit to this build's spec, and the Finalize step is what writes that section; the reviewer read an in-flight state.
  - `[medium]` `[defer]` `filterTo`'s vacuity was fixed only in `ssl.browser-spec.mjs`, not at its origin — deferred with `web-applications.browser-spec.mjs`, whose five-field leg is the larger exposure.
  - `[low]` `[defer]` `signedInAtList`/`waitForRows`/`filterTo`/`describeRow` now triplicated across three browser specs — same root cause as the row above, grouped and deferred with it.
  - `[low]` `[patch]` `testCorpus()` added beside an inline `extractXData(readFileSync(...))` it generalizes — the RowGetCorpus test at `screen-mirror.test.mjs:363` now calls the helper.
  - `[low]` `[patch]` `CREDENTIAL_RE` matches one of AC3's six names while the assertion message called it "the pattern that matches key material" — message and comment now state the vocabulary's limit; widening the pattern is deferred.
  - `[low]` `[patch]` The forbidden-name loop grepped `read.%ToJSON()` only — widened to the whole declaration, so `context.fields` and `table.columns` are covered too; the JS guard's four surfaces are AC3's own wording and stand.
  - `[low]` `[patch]` `AreaCoverageProblem`'s doc claimed the gate's invariant without naming the classic page's custom resource — the doc now says the declared set is all it can check and why.
  - `[low]` `[patch]` `Test/AreaPair/Bad.cls`'s doc read as if `ReadProblem` produced the refusal — rewritten to say it finds nothing to refuse, which is what lets the coverage refusal surface.
  - `[low]` `[patch]` `CheckAreaLists`'s `$Select` ended in a catch-all, so a fourth list would re-read the third under its name — the third arm is now explicit and the catch-all answers `""`, which fails loudly.
  - `[low]` `[patch]` `Test/Smoke.cls`'s `TestAScreenReadWithoutOneRowFailsTheListCheck` doc still said two checks and "both" — now three and "all three".
  - `[low]` `[patch]` `WireSecurityRead`'s header gained a third list but not the precondition its row assertion introduces — the header now states it.
  - `[low]` `[reject]` `sslListEmpty` names `<NAMESPACE>` on an instance-scoped screen — the copy is EXPERIENCE.md's Fixed strings row dictated verbatim by the spec, and `webAppListEmpty` / `userListEmpty` are instance-scoped with the same shape.
  - `[medium]` `[patch]` `read.filter`'s `Type` and the whole `sort` declaration were unpinned — `Descriptor.cls` now pins both by equality; mutation demonstrated (run 1693).
  - `[low]` `[reject]` `commandAliases: ["certificates"]` is unvalidated and unexercised — the value is spec-dictated, and no alias-collision rule exists for any descriptor, so a rule for this one would be new public surface.
  - `[low]` `[defer]` Five `//`-style `EXPERIENCE.md:<line>` citations in `strings.ts` resolve three lines high — verified pre-existing at the same offset before the insertion, and unguarded by `strings.test.mjs`.
  - `[low]` `[patch]` `AreaCoverageProblem`'s "an area declaring more than a screen requires is sound" had no assertion — a subset case now exercises it.
  - `[low]` `[reject]` `Corpus()` discards `IDKEYOpen`'s status and `DeclarationFor` assumes `privileges` exists — the class compiled, so a missing XData block is unreachable; a key-less case fails loudly in both engines, and defaulting it to `[]` would hide the authoring error.
  - `[low]` `[reject]` The new admin arm can pre-empt the malformed-pair sentence for a descriptor carrying both faults — `Test/Pair/Bad.cls` declares no read so nothing regresses today, and the fix reorders `Validate` for every descriptor, which is not a two-way door.
  - `[low]` `[reject]` `DeclarationFor` on a case with no `privileges` key raises `<INVALID OREF>` — same root cause as the row above's second half, rejected on the same reasoning.
  - `[low]` `[reject]` `AreaCoverageProblem` blames a nonexistent area when handed an unknown key — `Validate` checks area existence at `Registry.cls:145` before it ever calls this, and the guard would add a branch and a new dependency for a direct caller that does not exist.
  - `[medium]` `[defer]` Chained `filterTo` in `users.browser-spec.mjs:214-227` can pass before the filter applies — same root cause as the second row, grouped and deferred with it.
  - `[low]` `[reject]` AC3 calls the credential guard "build-time" but it runs under `npm test`, not `prebuild` or the commit hook — the spec named the file, CI's `gates` job runs `npm test` on every push, and moving a `node --test` assertion into the generator is more than a direct correction.
  - `[medium]` `[patch]` `Type` is a declared filter field with no assertion in either engine — same entry as the `read.filter` pin above; `Descriptor.cls` carries it because a throwaway's configurations share one type.
  - `[low]` `[patch]` The repo-wide key-material guard matches one of the six names AC3 enumerates — same entry as the `CREDENTIAL_RE` row above.
  - `[low]` `[patch]` `AreaCoverageProblem` checks declared privileges while the gate evaluates `Gate.RequiredPairs` — same entry as the doc-comment row above.
  - `[low]` `[reject]` The new arm's `port === 'admin'` guard cannot be false where it sits — removing it would silently widen the rule to every port the moment a second one lands, so the guard is forward-correct rather than dead.
  - `[low]` `[reject]` Nothing asserts the live LIST row carries *only* the four declared keys — `Read.Project` copies only `read.fields`, so a fifth vendor key cannot reach a caller; the claim is a probe recorded in Design Notes whose drift has no user-reachable consequence.
  - `[low]` `[reject]` No SSL row exercises `Enabled` false — the cell is `cellView(value, 'status')`, pinned both ways by `data-table.spec.ts:168,173` and end to end by two sibling browser specs; the declaration's `kind: "status"` is pinned in `Descriptor.cls`, and no disabled configuration exists on a throwaway to render.
  - `[low]` `[reject]` The *Missing admin resource* row is pinned on other routes, not on `security.ssl` — the gate is in `Router.OnPreDispatch`, which every route passes through, and its precedence is pinned by `Wire:TestAdministrativeGateRefusesBeforeTheNamespaceIsValidated`.
  - `[low]` `[reject]` "The port is not called" is not observed directly — a 403 `AUTH.NOPRIVILEGE` is rendered by the gate and short-circuits dispatch; the spec's own mutation showed the alternative is a 500, so the assertion that exists distinguishes them.
  - `[low]` `[reject]` The DW-264 port predicate is inert where written — same entry as the guard row above.
  - `[low]` `[reject]` `Registry.Validate` has no production caller, so the coverage refusal runs only in the instance job while its DW-264 twin gates `npm run build` — the spec's "Never" chooses `Validate` as the single home and says why a second copy would have no second consumer.
  - `[false]` `[reject]` Four route tests gained `ScreenGate.Hold("%DB_IRISSYS","READ")` — that is the necessary consequence of the fixtures now declaring the pair, and those tests still reach 200 through a real gate evaluation rather than around one.
  - `[low]` `[patch]` `CREDENTIAL_RE` covers one of six — same entry as the `CREDENTIAL_RE` row above.
  - `[low]` `[reject]` The demo Description is duplicated as a literal in the browser spec rather than referenced — a browser spec cannot import ObjectScript, and duplication by value detects drift in either direction, which is the existing pattern.

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

**Mutations (Rule 19; each applied, observed red, reverted; `git status --short` and `git diff --stat` unchanged afterwards):**
- mutation: `Description` dropped from `read.filter` (AC1) → `ssl.browser-spec.mjs`'s AC1 description leg goes red. Observed. The first run of this mutation stayed **green**: each `filterTo` was satisfied by the rows the previous `filterTo` had left, so the leg passed whatever `read.filter` declared. The leg now runs each filter from the whole list through a `clearFilter` helper, and the mutation is red.
- mutation: `Type` dropped from `read.filter` (AC1) → `Descriptor:TestTheSslConfigurationsListValidatesAndNamesItsClassicPageInItsOwnCase`'s filter pin goes red (run 1693). Observed. The browser legs cannot reach `Type` — a throwaway's configurations share one type, so no type substring narrows to one row — so the declaration is pinned by equality instead, alongside `read.sort`.
- mutation: the demo fixture's `Description` value changed in `Install/Fixture.cls`, the existing `OcuPilotDemoTLS` deleted so install recreates it (AC2) → `ssl.browser-spec.mjs`'s AC2 description assertion goes red (AC1's description leg with it). Observed.
- mutation: `PrivateKeyFile` added to `read.fields` with a `rowGet` over the same endpoint (AC3) → `ScreenReadWire`'s field-list, key-set and `PrivateKeyFile` assertions go red. Observed. Separately, a production column field renamed to `ApiKey` → `screen-mirror.test.mjs`'s `CREDENTIAL_RE` guard goes red. Observed.
- mutation: `built` set false on `SslConfigList` (AC4) → `navigation.test.mjs`'s built-route list goes red, and every `ssl.browser-spec.mjs` test, the side-bar one included, goes red because the route is no longer built. Observed.
- mutation: the new privilege arm of `ReadProblem` becomes `If 0` (AC5) → `ReadTool`'s `AdminPairCorpus` run goes red on all four refusing cases. Observed. The same change in `readProblem` turns `screen-mirror.test.mjs`'s corpus run red. Observed.
- mutation: `%DB_IRISSYS:READ` removed from `SslConfigList` in the throwaway's scratch copy and reloaded (AC6) → `WireSecurityRead`'s `SECURE` SSL assertions go red (the read answers 500, not 403). Observed.
- mutation: `AreaCoverageProblem`'s comparison returns `""` unconditionally (AC7) → the `AreaPairRegistry` test goes red. Observed. Separately, `%DB_IRISSYS:READ` dropped from the `security` area in `Area.cls` → the same test's production-roster leg and `Descriptor`'s area content pin go red. Observed.
- mutation: `SSLLISTTOOL` becomes `security.nosuch` (AC8) → `Smoke:TestTheSslListIsALiveCheck` goes red on a 404. Observed.
- mutation (code review): the `tI = 2` and `tI = 3` arms of `CheckAreaLists`'s `$Select` transposed (AC8) → `Smoke:TestEachAreaListCheckReadsItsOwnScreen`'s second and third path assertions go red, naming the screen each check read instead (run 1708); the first stays green. Observed and reverted; `Install/Smoke.cls` byte-identical to `HEAD` afterwards, full class 17/17 (run 1709).
- mutation (QA): a fourth name (`extra`) added to `CheckAreaLists`'s comma-separated list and its loop bound raised to 4, with no matching `tI = 4` arm added to the `$Select` → `Smoke:TestCheckAreaListsHasOneSelectArmPerNameAndAnEmptyCatchAll`'s arm-count assertion goes red, because the fourth name would otherwise reach the `$Select` catch-all silently instead of by a checked invariant. Observed and reverted; `git status --short` and `git diff --stat` on `Install/Smoke.cls` were empty afterwards.

**Tests added (QA):**
- `src/OcuPilot/Test/Smoke.cls` — `TestCheckAreaListsHasOneSelectArmPerNameAndAnEmptyCatchAll` (plus the private `LastMarkerAt` helper it uses) closes the one review-flagged gap with no standing test: the `$Select` catch-all patched during review (`CheckAreaLists`'s per-index tool lookup) had no assertion that a future list added to the loop bound and name list without its own arm would be caught rather than silently re-reading an earlier list's result. The test reads `OcuPilot.Install.Smoke`'s own compiled source (`%Compiler.UDL.TextServices.GetTextAsString`) and derives the current name list, loop bound and arm count from it, so it is not pinned to today's three names.
- Confirmed, added nothing: AC3's over-the-wire no-key-material assertion already exists verbatim in `Test/ScreenReadWire.cls:186-190` (asserts the six forbidden field names are absent from the raw response body, not just a key-count check) and at the declaration level in `Test/Descriptor.cls:125-127`.
- Confirmed, added nothing: DW-266's instance-engine refusal (`Test/AreaPair/Bad.cls` + `Test/AreaPairRegistry.cls`, exercised by `Test/Descriptor.cls:147-166`'s `TestAnAreaThatDoesNotCoverItsScreensPairsIsRefused`) is genuinely falsifiable — its mutation is already recorded two lines above this entry and matches the current code shape; re-run live (`ocupilot-iris`, run 1706) 22/22 passed. No JS-engine equivalent exists for `AreaCoverageProblem` by deliberate design (this spec's `## Boundaries & Constraints` › Never, and the review triage log's `Registry.Validate has no production caller` entry, reject a second copy as having no consumer), so none was added.

## Auto Run Result

Status: done
Blocking condition: none

**Change.** `SslConfigList` declares the `Security.SSLConfig` LIST over `security/ssl` with no `rowGet`, and both ledger items close on the same seam: `ReadProblem`/`readProblem` refuse an admin-port read that omits `%DB_IRISSYS:READ` (last arm, one sentence, both engines), and `Registry.AreaCoverageProblem` refuses a screen declaring a pair its area does not. The `security` area gains the pair; seven fixture descriptors, three inline JS declarations and four route-test gate holds follow from the new refusal.

**Files.** New: `Screen/Descriptor/SslConfigList.cls` (the declaration), `Test/AdminPairCorpus.cls` (9 cases, both engines), `Test/AreaPair/Bad.cls` + `Test/AreaPairRegistry.cls` (the DW-266 negative fixture), `ui/browser/ssl.browser-spec.mjs` (AC1-AC4). Changed: `Screen/Registry.cls` (both refusals), `Screen/Area.cls` (`security` pair set), `ui/tools/screen-mirror.mjs` + `screens.generated.ts` (the client engine and the mirror), `Install/Smoke.cls` + `Test/Smoke.cls` + `README.md` (the `ssl` check), `Test/{Descriptor,ReadTool,ScreenRead,ScreenReadWire,Wire,WireSecurityRead,Navigation,RowGetCorpus}.cls` and the six fixture descriptors, `EXPERIENCE.md` + `strings.ts` (three keys), `navigation.test.mjs`, `navigation-wire.test.mjs`, `rail-wire.spec.ts`, `screen-mirror.test.mjs`.

**Review.** 35 findings across four layers — high 0, medium 4, low 30, false 1. Ten entries patched in-pass (1 medium: `read.filter`/`read.sort` unpinned; 9 low: the `CREDENTIAL_RE` overclaim, the `AreaCoverageProblem` doc's missing `Gate.RequiredPairs` caveat, the forbidden-name grep widened to the whole declaration, `AreaPair/Bad.cls`'s inverted sentence, `CheckAreaLists`'s silent `$Select` catch-all, two stale doc comments, `WireSecurityRead`'s unstated precondition, `testCorpus()` reuse, and the unexercised area-superset case). Three items deferred to frontmatter: the `filterTo` vacuity still live in the users and web-applications browser specs with their triplicated helpers (medium), `CREDENTIAL_RE`'s suffix-anchored vocabulary (low), and five `//`-style `EXPERIENCE.md` citations off by three (low, pre-existing). Twenty-one rejected — each with its refutation in the triage log; the recurring reasons are spec-dictated values (`sslListEmpty`, `commandAliases`), behavior already pinned on a shared path (`cellView`'s status cell, `Router.OnPreDispatch`'s admin gate), and fixes that add a guard or reorder `Validate` for every descriptor. Patched counts by verdict: medium 1, low 9, high 0 — so `followup_review_recommended` is false.

**Verification.** `check-objectscript` 0 problems over 183 files; its harness 73 OK; `lint-docs` 0 issues; `ui`: build green through six prebuild checkers, `npm test` 699 node + 238 component, 0 failed. Live `ocupilot` (reads only, one class per call): `Descriptor` 22, `Navigation` 11, `ReadTool` 13, `ScreenRead` 18, `ScreenReadWire` 5, `Smoke` 15, `AdminPortSync` 6 — runs 1694-1700, 90 tests, 0 failed; `smoke.sh` PASSED with `ssl` pass and `arealists` naming only Logs, OS management and Tasks. Throwaway `ocupilot-ci`: full suite 50 classes / 457 tests / 0 failed / 0 overlaps / 0 probe leftovers, `smoke.sh` PASSED 13/13, `npm run test:browser` 35/35; torn down, and `Security.Users`/`Security.Roles` on the live instance carry only the installer's three shipped roles. Nine mutations applied, observed red and reverted; the tree was byte-identical after each.

**Residual risk.** The descriptor's "the four fields are the live LIST row's whole key set" is a probe, not a pinned assertion — `Read.Project` copies only `read.fields`, so a fifth vendor key could not reach a caller, but the sentence could go stale on a vendor upgrade. The `Enabled` false rendering is covered by `cellView`'s shared path rather than by an SSL row, because no disabled configuration exists on a throwaway to render.
