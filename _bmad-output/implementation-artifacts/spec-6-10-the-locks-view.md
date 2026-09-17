---
title: 'The locks view'
type: 'feature'
created: '2026-09-17'
status: 'in-progress'
baseline_revision: 'e581cd8ea51ec04009a18a8cd3499964d7bb0919'
baseline_commit: 'e581cd8ea51ec04009a18a8cd3499964d7bb0919'
review_loop_iteration: 1
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-6-context.md'
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
warnings: [oversized]
deferred: []
---

<intent-contract>

## Intent

**Problem:** OS management's side bar names Locks (`EXPERIENCE.md:164`) and nothing serves it, so finding the owner of a blocked operation means leaving for the classic View Locks page (FR-57, `epics.md` Story 6.10). The row's most useful cell — its owning process — has no way to reach Story 6.8's Process details: no descriptor grammar links a row to a screen other than its own paired surfaces.

**Approach:** One hand-written `list` descriptor under OS management declares one bounded `admin` `LIST` read on `%Api.Admin.Endpoints.Lock` through `AdminPort`, instance-scoped, seven columns. The owner cell reaches Process details through **new declared grammar** — `rowTarget`, one cross-screen row target per list (AD-5's own bullet, added for this story) — validated identically in `Screen/Registry.cls` and `ui/tools/screen-mirror.mjs` from one corpus, and resolved in `ui/src/app/shell/data-table.ts` ahead of the existing paired-surface chain. No page or store file: `ListPage` renders it.

## Boundaries & Constraints

**Always:**

- **Descriptor `OcuPilot.Screen.Descriptor.LockList`** — one `XData Declaration`, no method overrides (`Descriptor/Base.cls:62`):
  - route `os-management/locks`, area `os-management`, `labelKey` `lockListLabel`, `sideBarPosition` 2 (Processes 1, System usage 3), archetype `list`, `built` true
  - `entityType` `"lock"` — already the 21st value of the closed vocabulary (`Kernel/EntityType.cls:28`), so **no `Kernel/` edit**; `secondaryEntityTypes` `[]`; scope `instance`; `parentScope` `""`
  - `id` `{"kind": "composite", "parts": ["DeleteID"]}` — a process commonly holds several locks, so the removal id is the row key, not the pid (`TaskDetails.cls:68` is the one-part precedent)
  - `refreshes` false, `refreshRates` `[]` — Locks is not among AD-43's seven
  - `privileges` `%Admin_Operate:USE` then `%DB_IRISSYS:READ`, in that order, extended only by what a real least-privileged principal on the throwaway still refuses (AD-29)
  - `primaryAction` `{"id": "", "selfProtection": ""}`, `rowActions` `[]` — removal is Story 16.12
  - `emptyStateKey` `lockListEmpty`; `table.emptyNextKey` `tableReadOnlyEmptyNext` (reused), `table.emptyAgentKey` `""` (not write-capable)
  - `commandAliases` `["locks", "lock table"]`; `toolIdentifier` `osmgmt.locks`
  - `classicPage` `%CSP.UI.Portal.LocksView` — the key `##class(%SYS.Portal.Resources).NormalizePage("/csp/sys/op/%CSP.UI.Portal.LocksView.zen")` answers on slot B; a `.zen` page normalizes to its bare class name, unlike Story 6.9's `%cspapp.*` key. `classicLinkExemption.exempt` false with empty `reason`/`label`/`href` — a list links out to nothing (AD-44), and Manage Locks is Story 16.12's page
  - `context.fields` = the eight read fields (the seven columns plus `DeleteID`, as every other composite-id list carries its own id parts); `context.secretFields` `[]`
  - **`rowTarget`** `{"route": "os-management/processes/details", "field": "Pid"}`
- **Read** — `source` `{"port": "admin", "endpoint": "Lock", "type": "LIST"}`, `paging` `"cap"`, no `criteria`, no `rowGet`, no `query`, no `parts`, no `forEach`:
  - `fields` exactly these eight: `Pid`, `OSUserName`, `RoutineInfo`, `ModeCount`, `Reference`, `Directory`, `System`, `DeleteID`
  - `filter` `["Pid", "OSUserName", "RoutineInfo", "ModeCount", "Reference", "Directory", "System"]` — the shared client-side filter; the vendor's own `filter` parameter is **not** declared
  - `sort.fields` the same seven, `default` `"Pid"`, `direction` `"asc"`
- **Table** — seven columns, exactly one `name` kind (`Registry.cls:1780`):
  `Pid`/`processColumnPid`/`name` · `OSUserName`/`processColumnUser`/`text` · `RoutineInfo`/`processColumnRoutine`/`identifier` · `ModeCount`/`lockColumnMode`/`text` · `Reference`/`lockColumnReference`/`identifier` · `Directory`/`lockColumnDirectory`/`identifier` · `System`/`lockColumnSystem`/`text` with `"emptyKey": "lockSystemLocal"`.
  `System` is empty on every local lock, so its empty cell reads "This instance" rather than "(none)" — the `emptyKey` rule's purpose (`ServiceList.cls:67` is the precedent).
- **`rowTarget` grammar**, the same sentences from both engines, one corpus (`Registry.cls` § `RowTargetProblem` shape + `RowTargetResolutionProblem` roster; `screen-mirror.mjs` § `rowTargetProblem` + `rowTargetResolutionProblem`). Optional key: absence is sound, since the top-level check is unknown-key only (`Registry.cls:305` doc). Refusals, twelve:
  - **shape** — not an object; an unknown key inside it (through the shared `UnknownKeyProblem`); declared on a non-`list` archetype; declared on a screen with no `table`; `route` empty or not a string; `route` equal to this screen's own route; `field` empty or not a string; `field` not one of `read.fields`
  - **roster** — `route` names no declared screen; names a screen that is not `built`; names a screen whose `id.kind` is `none`; is declared on a screen that already pairs its own surface (editor, document viewer, detail screen or child list), because a row's name cell links to one place
- **Client resolution** — `data-table.ts` resolves `rowTarget` **ahead of** `editorScreenFor ?? documentScreenFor ?? detailScreenFor ?? childListFor ?? own-id-route` (`data-table.ts:431-438`), after the `classicLinkExemption.rowLink` branch. Its encoded value is `fieldOf(row, rowTarget.field)`, **not** `rowKey(row, screen)` — the pid, not the removal id — through `encodeEntityId` (AD-13, `core/entity-id.ts:56`). One cell-rendering path: no screen-specific branch in `cellView`.
- **Additive only** where Epic 4 shares a file: `Screen/Registry.cls`, `Descriptor/Base.cls`, `Install/Smoke.cls`, `Test/Descriptor.cls`, `ui/tools/screen-mirror.mjs`, `ui/src/app/core/strings.ts`. Add methods, parameters, keys, cases and test methods; change no existing signature, sentence or declared key. (`Base.cls` took `ContextMaxLengths()` as +20/−0 on the epic-4 branch — the same discipline.)
- **`screens.generated.ts` is regenerated**, never hand-merged: `node tools/screen-mirror.mjs` from `ui/`, then `--check` in `prebuild` proves no drift.

**Never:**

- **No transaction column, and no `$zu(67,19,…)` anywhere in the read path.** The in-transaction condition is a removal concern: the endpoint's own delete path answers HTTP 409 "is currently in a transaction", and Story 16.12 warns from that refusal — **DW-1073**, already routed there. Do not add AD-36 derived-field grammar for it.
- No `AdminPort` edit. `%Api.Admin.Endpoints.Lock.ResourcesOR()` returns `$LISTBUILD("%Admin_Operate")` and the backing query's own check (`irissys/%SYS/LockQuery.cls:871`) demands the same `%Admin_Operate:USE`, so the backing query is **not stricter** and `QUERYPAIRS` (`AdminPort.cls:130`) gains no `Lock/LIST` entry. `LIST` is already in `TYPESUFFIXES` (`:101`) and the endpoint resolves by name against `ENDPOINTPACKAGE` (`:51`) — there is no allow-list to join.
- No `ns` in the read. The lock table is instance-wide; the screen ignores the namespace switch like every other instance-scoped screen.
- No conditional row-link grammar. A `RemoteOwner` row has no local pid and its link lands on Process details' "This process no longer exists." — accepted as **DW-1074** (escalated, burndown).
- No `Removable`, `CanBeExamined` or `RemoteOwner` field or column — removal fields belong to Story 16.12. No page or store file, no `DESCRIPTOR_PAGES` entry (`screen-outlet.ts:81`): `ARCHETYPE_PAGES['list']` already serves it.
- No planning-artifact edit, no `Kernel/**`, no `Port/ProviderPort.cls`, no `Screen/Tool/**`, no `scripts/check-objectscript.py`, no `ui/src/app/app.ts`, no `ui/src/app/shell/panel/**`, no `ui/package.json` / `angular.json` / `README.md`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Locks list loads | Instance holds locks; caller holds both pairs | Seven columns; one row per lock; `Pid` cell linked; truncation reported at the cap | No error expected |
| Two namespaces, one answer | Same read issued with `ns=HSCUSTOM` and `ns=USER` | Byte-identical row sets — the read takes no `ns` | No error expected |
| Owner cell followed | Row with `Pid` 905, `DeleteID` `313131776,39,P905,` | Opens `os-management/processes/details/905` — the pid, encoded once | No error expected |
| Remote-owner row | `RemoteOwner` true, no local pid | Link still renders; Process details answers "This process no longer exists." | Accepted, DW-1074 |
| Empty `System` cell | Local lock, `System` `""` | Cell reads "This instance" | No error expected |
| No locks | Instance holds none | Empty state "No locks on this instance." + the read-only second line; no agent invitation | Not an error state |
| Caller lacks `%Admin_Operate:USE` | Real least-privileged principal | Title plus "You need %Admin_Operate:USE to open Locks."; no table, no read | Gate names the first unheld pair; never 500, never an empty state |
| Caller holds `%Admin_Operate:USE` only | Principal without `%DB_IRISSYS:READ` | Denial names `%DB_IRISSYS:READ` (or the read is served and the pair set is corrected to what the instance actually refuses, AD-29) | As above |
| Vendor fault | Endpoint answers non-2xx | `AdminPort` named fault, one error envelope; data already on screen stays | AD-12 / AD-39 |
| `rowTarget` typo | `route` `os-management/process/details` | `screen-mirror.mjs --check` and `Registry.Validate` both refuse with the same sentence; `prebuild` fails | Build refuses; nothing ships |

</intent-contract>

## Code Map

Server:

- `src/OcuPilot/Screen/Descriptor/LockList.cls` — **new**. Clone the shape of `ProcessList.cls:74-125` (same area, same archetype, same instance scope, reuses three of its string keys).
- `src/OcuPilot/Screen/Registry.cls` — `DECLARATIONKEYS` `:305` (append `rowTarget`); `Validate` `:135` dispatches the shape rule; `ParentScopeResolutionProblem` `:2236` is the precedent for a roster-wide rule and the call site to sit beside; `TableProblem` `:1729` holds the one-`name`-column rule `:1780` and the `id.parts ⊂ read.fields` rule `:1784`; `UnknownKeyProblem` `:332` is the shared unknown-key helper.
- `src/OcuPilot/Screen/Descriptor/Base.cls` — one new accessor `RowTarget()` beside `ContextSecretFields()` (~`:286`). Additive.
- `src/OcuPilot/Test/RowTargetCorpus.cls` — **new**. `XData Cases` + `XData Rosters`, modeled on `Test/TabCorpus.cls` (the only corpus with a roster half) and `Test/ReadSourceCorpus.cls:109-121` (Story 6.9's `parts` cases).
- `src/OcuPilot/Test/Descriptor.cls` — new `TestThe…` methods: one runs `RowTargetCorpus` through both `Registry` methods; one pins the Locks read field set and column set exactly. The `EntityType.Count()` pin at `:1046-1054` stays `28` — `lock` was already counted.
- `src/OcuPilot/Test/WireSecurityRead.cls` — new `TestTheLocksListPairSetIsEnforcedForARealPrincipal`, patterned on `:506` (Processes) and `:599` (System usage).
- `src/OcuPilot/Test/ScreenRead.cls:187-251` — **self-discovering**; it walks `Registry.Descriptors()` and picks the new LIST screen up with no edit. Add no exclusion.
- `src/OcuPilot/Install/Smoke.cls` — `CheckAreaLists` `:577`: add `Parameter LOCKLISTTOOL = "osmgmt.locks";` (pattern `:62`, `:138`), append it to the name list `:582`, bump `For tI = 1:1:22` to `23`, add the `$Select` arm `:586`. Request/assert shape `:595-599`.
- Untouched by design: `Port/AdminPort.cls`, `Screen/Read.cls` (`Project` `:851` emits declared field values only — a resolved link is never a field), `Screen/Area.cls:102` (the OS-management union already carries both pairs; its own doc `:34-58` names this story and says the union is not narrowed), `Install/Installer.cls` (no screen roster), `Kernel/EntityType.cls`.

Client:

- `ui/tools/screen-mirror.mjs` — `DECLARATION_KEYS` `:378-405` (append `rowTarget`); `buildMirror` `:1639-1647` is where the new problem functions are called; `partsProblem` `:1174-1220` is the shape to copy; the emitted TS types are at `:1961-1975` (add `ScreenRowTarget`, and `readonly rowTarget: ScreenRowTarget | null` — `null` where undeclared, mirroring `rowLink ?? null`).
- `ui/tools/screen-mirror.test.mjs:442-460` — the corpus-driven test shape; `testCorpus` helper `:40-44`. Add one test per corpus half.
- `ui/src/app/shell/data-table.ts:427-448` — insert the `rowTarget` branch into the chain and use `fieldOf(row, …)` for the encoded value. Comment at `:417-431` documents the chain and must gain the new first case.
- `ui/src/app/shell/data-table.spec.ts` — the component leg that pins the computed `url`.
- `ui/src/app/core/screens.generated.ts` — **regenerated**; `EntityTypeKey` `:13` already carries `'lock'`.
- `ui/src/app/core/strings.ts` — five new keys after the Processes block `:352-367`, each with its `/** EXPERIENCE.md:<line> */` citation.
- `ui/tools/strings.test.mjs:30-70`, `:350-382` — set equality against EXPERIENCE.md's Fixed strings table plus two named sets; **it cannot pass until the lead's EXPERIENCE.md row lands** (see Execution 1).
- `ui/tools/navigation.test.mjs:115-161` — insert `os-management/locks` into the hand-ordered route roster and update its describing message.
- `ui/browser/locks.browser-spec.mjs` — **new**; registered by filename alone (`package.json` `test:browser` glob; cross-checked by `ui/tools/angular-json.test.mjs` DW-159). Helpers in `ui/browser/list-spec.mjs`; `ui/browser/processes.browser-spec.mjs:255-268` is the header/row-assertion model.
- `ui/tools/navigation-wire.test.mjs:38` and `ui/src/app/shell/rail-wire.spec.ts:37` — the two `LIVE_PAYLOAD` literals; add the Locks entry to the `os-management` screens array in both, copied from the corresponding `Test/Wire` assertion string. Neither reddens alone.
- Unaffected: `ui/tools/classic-links.mjs` (a `list` with a bare `classicPage` and no exemption), `ui/tools/field-lists.mjs` (no write tool), `ui/tools/ipm-manifest.mjs` (regenerate only), `ui/src/app/areas/os-management/` (no page/store file).

Vendor, read-only reference:

- `%Api.Admin.Endpoints.Lock` — **not in the `irissys/` export** (it is `[ Hidden ]`); read it from slot B with `iris_doc_get`. Implements `LIST` and `DELETE` only — no `GET`, `INFO` or `CERTINFO`, so no `rowGet` is available. `RunList` calls `ExcludeColumn("PidInternal")`.
- `irissys/%SYS/LockQuery.cls:865` — `WebListFilter` `ROWSPEC`, 12 columns; `:871` the `%Admin_Operate:USE` check; `:876-886` `WebListFilterFetch`, which opens `%SYS.ProcessQuery` per row for `OSUserName` and tolerates failure at `:882` — so it cannot refuse the read.
- Slot B, 2026-09-17: 7 rows, all `ModeCount` `Exclusive`, all `OSUserName` `irisowner`, `System` empty on every row. Sample: `Pid` 905, `Reference` `^ISC.LMFMON("License Monitor")`, `Directory` `/durable/iris/mgr/`, `DeleteID` `313131776,39,P905,`.

## Tasks & Acceptance

**Execution:**

1. **Precondition, applied by the lead before this spec was dispatched.** `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md:364` carries the Locks view's Fixed strings row, after the System usage row. Implement does not edit any planning artifact; it reads that row as the authority for the seven new strings, and `strings.test.mjs` re-derives its authorized set from it.
2. `src/OcuPilot/Screen/Registry.cls` — append `rowTarget` to `DECLARATIONKEYS`; add `RowTargetProblem` (shape) called from `Validate`, and `RowTargetResolutionProblem` (roster) called beside `ParentScopeResolutionProblem`. Twelve refusal sentences per Boundaries. Rationale: the declaration grammar fails closed on an unknown key, so the key must be admitted before any descriptor can carry it.
3. `src/OcuPilot/Screen/Descriptor/Base.cls` — add `RowTarget()`. Additive only.
4. `src/OcuPilot/Test/RowTargetCorpus.cls` — one sound `list` case carrying the Locks shape, one sound case with no `rowTarget`, the eight shape refusals in `Cases`, the four roster refusals in `Rosters`. Rationale: one corpus is what keeps the two engines' sentences identical.
5. `ui/tools/screen-mirror.mjs` — `rowTargetProblem` / `rowTargetResolutionProblem` returning those same sentences; append `rowTarget` to `DECLARATION_KEYS`; emit `ScreenRowTarget` and `rowTarget: ScreenRowTarget | null`.
6. `ui/tools/screen-mirror.test.mjs` — two corpus-driven tests, one per corpus half, asserting per case against `RowTargetCorpus`.
7. `src/OcuPilot/Screen/Descriptor/LockList.cls` — the declaration in Boundaries. Compile through the IRIS MCP tools on `ocupilot-slot-b`; read the error text.
8. `ui/src/app/shell/data-table.ts` — resolve `rowTarget` ahead of the paired-surface chain, encode `fieldOf(row, rowTarget.field)`, extend the chain comment. Rationale: the Locks row key is its removal id, so the row's own id route would name the wrong thing.
9. `ui/src/app/core/strings.ts` — `lockListLabel`, `lockColumnMode`, `lockColumnReference`, `lockColumnDirectory`, `lockColumnSystem`, `lockSystemLocal`, `lockListEmpty`, each citing its EXPERIENCE.md line. Reuse `processColumnPid`, `processColumnUser`, `processColumnRoutine`, `tableReadOnlyEmptyNext`.
10. Regenerate the mirror: `cd ui && node tools/screen-mirror.mjs`. Never hand-merge `screens.generated.ts`.
11. `ui/tools/navigation.test.mjs` — insert `os-management/locks` at its side-bar-ordered slot; update the message.
12. `ui/tools/navigation-wire.test.mjs` and `ui/src/app/shell/rail-wire.spec.ts` — add the Locks entry to both `LIVE_PAYLOAD` literals.
13. `src/OcuPilot/Test/Descriptor.cls` — the corpus-driven grammar test and the exact field/column-set pin.
14. `src/OcuPilot/Test/WireSecurityRead.cls` — the least-privileged-principal test. Create the principal on the throwaway with exactly `%Admin_Operate:USE` and `%DB_IRISSYS:READ`, never `%Operator`; then drop each pair in turn and assert the named denial. **Append to the declared pair set whatever the instance still refuses, and correct the descriptor and this spec's Boundaries at their origin** (AD-29 — `ResourcesOR()` plus the backing query's check is a lower bound).
15. `ui/src/app/shell/data-table.spec.ts` — the computed-`url` leg.
16. `ui/browser/locks.browser-spec.mjs` — headers, rows, the owner link's navigation, and the empty `System` cell. Both `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777` and `OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci` on every browser and `ci-runner` call. Rebuild and redeploy the bundle before believing any result.
17. `src/OcuPilot/Install/Smoke.cls` — the `osmgmt.locks` live-read check, per Code Map.
18. Verification pass: the commands in `## Verification`, then the throwaway teardown.

- [ ] [CI] instance: `OcuPilot.Test.Navigation.TestThePayloadCarriesEveryAreaWithAVerdict` -- the os-management roster this test pins by index is stale for the second story running: Locks is a fourth built screen at `sideBarPosition` 2, so the area's screens are Process details, Processes, Locks, System usage. Correct the count, the roster assertions and the comment, demonstrate a mutation on the corrected assertion (Rule 19), and sweep for any other test that pins a per-area roster by index and was missed -- run 35282177175.

**Acceptance Criteria:**

- **AC1** — Given the compiled descriptor, when `OcuPilot.Screen.Registry.Validate` runs over the roster, then `LockList` validates, appears in the OS-management side bar at position 2 between Processes and System usage, and `screens.generated.ts` carries it with `rowTarget` `{route: 'os-management/processes/details', field: 'Pid'}`. Pinned by `Test/Descriptor.cls` (validation) and `ui/tools/navigation.test.mjs:115` (order).
- **AC2** — Given the read runs against slot B, when `/screens/osmgmt.locks/read` answers, then every one of the eight declared fields is a key of the live first row and the seven column fields hold real values, not null-filled keys. Pinned by `Test/ScreenRead.cls:187` (self-discovering) plus `Install/Smoke.cls` `CheckAreaLists`.
- **AC3** — Given the same read issued twice, when it is issued once with `ns=HSCUSTOM` and once with `ns=USER`, then the two row sets are identical, because the read declares no `ns` criterion and the lock table is instance-wide. Pinned by `Test/ScreenRead.TestTheLocksReadDeclaresNoCriteriaAtAll`, which pins the structural fact; a two-read comparison across namespaces is green by construction and was removed at code review.
- **AC4** — Given a row whose `Pid` is 905 and whose `DeleteID` is `313131776,39,P905,`, when the owner cell's link is computed, then its route is `os-management/processes/details/905` — the pid encoded once by `encodeEntityId`, not the removal id — and following it in a browser opens Process details for pid 905. Pinned by `ui/src/app/shell/data-table.spec.ts` (the computed `url`) and `ui/browser/locks.browser-spec.mjs` (the navigation).
- **AC5** — Given `Test/RowTargetCorpus`'s `Cases`, when each is run through `Registry.RowTargetProblem` and through `screen-mirror.mjs`'s `rowTargetProblem`, then both return the corpus's `expected` sentence for every refusal, character for character, and `null` for both sound cases. Pinned by `Test/Descriptor.cls` and `ui/tools/screen-mirror.test.mjs`.
- **AC6** — Given `Test/RowTargetCorpus`'s `Rosters`, when each roster is run through `Registry.RowTargetResolutionProblem` and through `rowTargetResolutionProblem`, then both refuse an undeclared route, an unbuilt target, an `id.kind: none` target and a declaring screen that already pairs its own surface, with identical sentences. Pinned by the same two tests.
- **AC7** — Given a real principal on the throwaway holding exactly the declared pairs, when the Locks read is issued, then it is served; and when each pair is withheld in turn, then the gate refuses naming the first pair not held, never a 500 and never an empty state. Pinned by `Test/WireSecurityRead.cls` `TestTheLocksListPairSetIsEnforcedForARealPrincipal`.
- **AC8** — Given the derived read tool `osmgmt.locks`, when it is invoked, then it returns the screen's own declared read — same fields, filter and sort — narrowed by the context cap with no secret fields, and never issues a second query. Pinned by `Test/ReadTool.cls`.
- **AC9** — Given the descriptor, when its read and table are inspected, then `read.fields` is exactly the eight named fields and `table.columns` is exactly the seven named columns: no transaction column, no `Removable`, `CanBeExamined` or `RemoteOwner`, no derived field, and no `$zu(67,19` anywhere in the read path. Pinned by the exact-set test in `Test/Descriptor.cls`.
- **AC10** — Given an instance with no locks, when the screen loads, then the empty state reads "No locks on this instance." with the shared read-only second line and no agent invitation; and given a local lock, its `System` cell reads "This instance". Pinned by `ui/browser/locks.browser-spec.mjs`, with the string set pinned by `ui/tools/strings.test.mjs`.

### Review Findings

Code review 2026-09-17 (Tier 1, full-opus; layers: blind-hunter, edge-case-hunter, verification-gap,
acceptance-auditor). Every patch below is applied; every mutation cited was observed red and reverted.

- [x] [Review][Patch] Neither engine's roster wiring was pinned: no `RowTarget*` fixture registry, and `screen-mirror.test.mjs` had only a shape-rule `assert.throws` while its own comment claimed the roster call site was covered [src/OcuPilot/Screen/Registry.cls:277, ui/tools/screen-mirror.test.mjs:536] — added `OcuPilot.Test.RowTargetShape.Bad` + `RowTargetShapeRegistry`, `OcuPilot.Test.RowTargetRoster.A` + `RowTargetRosterRegistry`, `Test/Descriptor.TestARowTargetOutsideTheGrammarIsRefusedByTheRoster`, and the roster `assert.throws` over the I/O matrix's own mistyped-route scenario
- [x] [Review][Patch] AC3's two pinning assertions could not fail — QA's note called the `pCriteria("ns")` comparison vacuous and the `Kernel.Scope` variant says so in its own header — and both compared two live reads of a volatile instance-wide table byte-for-byte [src/OcuPilot/Test/ScreenRead.cls:262,316] — both removed; `TestTheLocksReadDeclaresNoCriteriaAtAll` is the falsifiable pin and AC3's `Pinned by` now names it
- [x] [Review][Patch] AC2's "hold real values, not null-filled keys" was asserted nowhere, and the vendor makes a null-filled row reachable (`%SYS.LockQuery.WebListFilterFetch` appends `OSUserName` only when `%SYS.ProcessQuery.%OpenId` succeeds) [src/OcuPilot/Test/ScreenRead.cls:239] — added `TestTheLocksReadAnswersValuesNotEmptyKeys` over six of the eight fields
- [x] [Review][Patch] AC8's recorded mutation could not redden the test AC8 names; no assertion in `Test/ReadTool` reads this screen's `read.fields` [_bmad-output/implementation-artifacts/spec-6-10-the-locks-view.md:189] — mutation line replaced with the `toolIdentifier` rename, observed red
- [x] [Review][Patch] `Base.RowTarget()` had no caller and no assertion — the only one of thirty accessors outside `TestEveryAccessorReadsTheDeclarationOnce`'s roster [src/OcuPilot/Screen/Descriptor/Base.cls:296] — added to that roster, plus both arms asserted in `Test/Descriptor`
- [x] [Review][Patch] `ROWTARGETKEYS` / `ROW_TARGET_KEYS` had no parity assertion, unlike `DECLARATION_KEYS` [src/OcuPilot/Screen/Registry.cls:2337, ui/tools/screen-mirror.mjs:1347] — the corpus's sound `rowTarget` is now pinned against each engine's vocabulary
- [x] [Review][Patch] The mirror corpus test counted both halves' refusals in one variable, so a `Rosters` block that lost every refusing entry still satisfied it [ui/tools/screen-mirror.test.mjs:545] — one counter per half, as the ObjectScript twin has
- [x] [Review][Patch] Both `pairsOwnSurface` doc comments claimed to resolve "the same four surfaces" as `navigation.ts`, which additionally require the candidate to be unlisted and id-keyed [src/OcuPilot/Screen/Registry.cls:2413, ui/tools/screen-mirror.mjs:1396] — comments now state the rule is deliberately broader and fails closed
- [x] [Review][Patch] `Install/Smoke.cls` asserted "a real instance always holds at least one lock" from one probe [src/OcuPilot/Install/Smoke.cls:140] — replaced with what was observed (seven rows, all daemon-held, slot B 2026-09-17) and how to read a failure; the exactly-one-row check is kept
- [x] [Review][Patch] `LockList.cls` named the backing query `SYS.LockQuery`; it is `%SYS.LockQuery` [src/OcuPilot/Screen/Descriptor/LockList.cls:28]
- [x] [Review][Patch] Boundaries said `context.fields` is the seven column fields; the descriptor declares eight, which is what every other composite-id list does [src/OcuPilot/Screen/Descriptor/LockList.cls:33] — Boundaries corrected
- [x] [Review][Patch] The `$zu(67,19` assertion claimed "anywhere in the read path" but reads one class's source [src/OcuPilot/Test/Descriptor.cls:1259]; `screen-mirror.test.mjs:1635` still said "twenty-six keys"; `WireSecurityRead`'s `OPERATEUSER` message had lost the reason the assertion exists — all three corrected
- [x] [Review][Defer] DW-1078 `rowTarget` admits a target screen whose composite id has several parts, and one field value is encoded as that whole id [src/OcuPilot/Screen/Registry.cls:2427] — deferred: `escalated owner=burndown`; a thirteenth refusal edits AD-5's `rowTarget` bullet, Boundaries' "Refusals, twelve" and AC6, which is spine work (Rule 20), not a reviewer patch. Four shipped screens are keyed by a multi-part composite id; today's only `rowTarget` targets `ProcessDetails`, which has one part, so nothing is wrong now

**Rejected.**

- `false` — "a remote-owner row renders no link": `%SYS.LockQuery.WebListFilter`'s ROWSPEC takes `Pid` from the lock table and `WebListFilterFetch` numeric-coerces it (`+$listget(Row)`), so `Pid` is populated for a remote owner too. The descriptor's "the link still renders" is consistent with the vendor; DW-1074 stands.
- `false` — "AC7's mutation is unfalsifiable because `Validate`/`buildMirror` refuse it": `Validate` is called from no production path (its own class comment says so; the only callers are tests), so the denial-order assertions do run and do redden.
- `false` — "the two engines diverge for a `rowTarget` with a `table` and no `read`": `ReadProblem` refuses "table is declared while read is not" at `Registry.cls:813`, dispatched before `RowTargetProblem`, and `readProblem` likewise precedes `rowTargetProblem` in `buildMirror`. Both fail closed and the shape is unreachable.
- `low`, not worth a guard — the `rowLinked ||` disjunct in `rowTargetScreen` is unreachable (AD-44 forbids an exemption on a `list`; `rowTarget` is list-only).
- `low`, `wontfix-accepted` `reopen_if=` the User column reads "(none)" on a real instance — `OSUserName` declares no `emptyKey`; adding one needs a new EXPERIENCE.md string, which this story may not edit.
- `low`, `wontfix-accepted` `reopen_if=` two surfaces claim the phrase — the `"lock table"` alias overlaps System usage's meter label; no alias-uniqueness rule exists in either engine, and adding one is not this story's grammar.
- `by-design` — the vendor `filter` parameter left undeclared with its per-row `%SYS.ProcessQuery` cost at the cap; `secondaryEntityTypes` `[]`; `DeleteID` in `context.fields`; a remote-owner row landing on "This process no longer exists." (DW-1074). All settled in Boundaries or by the orchestrator.
- `low` — Execution 6 asked for two mirror tests and one was written covering both halves; AC5 and AC6 are each asserted per case inside it.

## Spec Change Log

- 2026-09-17, lead: `EXPERIENCE.md:364` Fixed strings row applied before dispatch (Execution item 1).
- 2026-09-17, code review: AC3's two comparisons removed and its `Pinned by` corrected; the `context.fields` sentence corrected; five `mutation:` lines recorded.

## Review Triage Log

- 2026-09-17 full review (four layers): 0 high, 12 patched in pass, 1 escalated (DW-1078), 8 rejected at emission. Two layer claims were rejected on evidence: a remote-owner row does render a link, and AC7's mutation is falsifiable because `Validate` runs from no production path.

## Design Notes

**Consumes:** Epic 2 (`AdminPort` sync, the declared read, `ListPage`, the command bar and its filter, the gate), 6.2 (column `emptyKey`), 6.8 (Process details, the route the owner cell opens, and its pair set), 6.9 (the corpus-per-grammar shape the `parts` rule established).

**Consumed-by:** Story 16.12 (lock removal — it reuses this descriptor's read and row key, adds the row actions, and carries DW-1073's transaction warning); Story 6.11 Databases (the next OS-management list, and the next candidate for `rowTarget`); any later list whose row owner is another screen's entity.

**Integration AC:** AC4 — `data-table.ts`, the consumer of the new `rowTarget` grammar, resolves it and produces an observable link into Process details, asserted at the DOM by the browser leg rather than by inspecting the descriptor.

**Why `rowTarget` is descriptor-level and not a column key.** Exactly one column is the row's `name` kind (`Registry.cls:1780`) and it carries the row's single link; a per-column link would be a second cell-rendering path. AD-5's bullet therefore declares one target per list and the shared table keeps its one path.

**Why the pair set may move.** `ResourcesOR()` and `WebListFilterExecute` agree on `%Admin_Operate:USE`, and `%DB_IRISSYS:READ` is AD-29's standing requirement for an `admin` read; neither establishes the set. Execution 14 is where it is established, and a correction goes into the descriptor and into Boundaries above — not appended as a note.

## Verification

**Commands** (from the worktree root unless noted; every IRIS MCP call carries `server: "ocupilot-slot-b"`):

- `uv run scripts/check-objectscript.py src/OcuPilot/Screen/Descriptor/LockList.cls src/OcuPilot/Screen/Registry.cls src/OcuPilot/Screen/Descriptor/Base.cls src/OcuPilot/Test/RowTargetCorpus.cls src/OcuPilot/Test/Descriptor.cls src/OcuPilot/Test/WireSecurityRead.cls src/OcuPilot/Install/Smoke.cls` -- expected: no findings
- Compile the changed classes through `iris_doc_load` + `iris_doc_compile` -- expected: clean compile, error text read on any failure
- `iris_execute_tests` on `OcuPilot.Test.Descriptor`, then `OcuPilot.Test.ScreenRead`, then `OcuPilot.Test.ReadTool`, then `OcuPilot.Test.WireSecurityRead` -- **one class per tool call**, each awaited and confirmed landed in `%UnitTest_Result` before the next; never re-submit on a client-side timeout
- `cd ui && node tools/screen-mirror.mjs && npm run build` -- expected: mirror regenerated, then `prebuild`'s six checkers pass including `screen-mirror.mjs --check`
- `cd ui && npm test` -- expected: green, including `screen-mirror.test.mjs`, `strings.test.mjs`, `navigation.test.mjs`, `navigation-wire.test.mjs`, `angular-json.test.mjs` and `data-table.spec.ts`
- `sh scripts/ci-throwaway.sh up --dir /tmp/ocupilot-b-ci --project ocupilot-b-ci --web 52777 --super 1976`, then `cd ui && OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci npm run test:browser` -- expected: green, `locks.browser-spec.mjs` included. Rebuild and `docker cp dist/ocupilot/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/` before reading any result. `down` the throwaway the same way before returning; tear down nothing else
- `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS` -- expected: the `osmgmt.locks` check executes and passes; zero executed checks is a failure
- `bash scripts/lint-docs.sh` -- expected: clean

**Mutations** (Rule 19 — one per AC; apply, observe red, revert, confirm `git status --short` and `git diff --stat` unchanged):

- AC1 — mutation: change `sideBarPosition` to 4 in `LockList.cls` → `navigation.test.mjs`'s route-roster assertion goes red
- AC2 — mutation: add `"Removable"` to `read.fields` without adding it to the projection → `Test/ScreenRead.TestEveryDeclaredReadFieldIsAKeyOfTheLiveRow` goes red (and revert: the field is not shipped)
- AC2 — mutation: make `Screen/Read.Project` emit every declared field as JSON `null` → `Test/ScreenRead.TestTheLocksReadAnswersValuesNotEmptyKeys` goes red naming the null-filled row (observed 2026-09-17, code review)
- AC3 — mutation: add a `criteria` block naming `ns` to the read → `Test/ScreenRead.TestTheLocksReadDeclaresNoCriteriaAtAll` goes red on its type check
- AC4 — mutation: in `data-table.ts`, encode `rowKey(row, screen)` instead of `fieldOf(row, rowTarget.field)` → `data-table.spec.ts`'s URL assertion goes red (the URL becomes the removal id); rebuild and redeploy before re-running the browser leg
- AC5 — mutation: drop one word from `RowTargetProblem`'s "route is this screen's own route" sentence → `Test/Descriptor`'s corpus test goes red; do the mirror half by dropping the same word from `rowTargetProblem` → `screen-mirror.test.mjs` goes red
- AC6 — mutation: make `RowTargetResolutionProblem` return `""` for an unbuilt target → the roster test goes red in both engines
- AC5, AC6 — mutation: delete the `RowTargetProblem` call from `Registry.Validate` → `Test/Descriptor.TestARowTargetOutsideTheGrammarIsRefusedByTheRoster`'s shape-sentence assertion goes red; delete the `RowTargetResolutionProblem` call → its roster assertions go red; delete the `rowTargetResolutionProblem` call from `buildMirror` → `screen-mirror.test.mjs`'s roster `assert.throws` goes red (all three observed 2026-09-17, code review)
- AC7 — mutation: remove `%DB_IRISSYS:READ` from `privileges` → `WireSecurityRead`'s denial-order assertion goes red
- AC8 — mutation: rename `LockList`'s `toolIdentifier` to `osmgmt.lock` → `Test/ReadTool.TestTheRegistryListsDescriptorReadsAndInheritedKinds` goes red on its tool-name roster (observed 2026-09-17, code review; the six-field mutation recorded here before reddened nothing in that class, which reads no screen's `read.fields`)
- AC9 — mutation: add an eighth column to `table.columns` → the exact-set test in `Test/Descriptor` goes red
- AC10 — mutation: drop `"emptyKey": "lockSystemLocal"` from the `System` column → the browser leg's "This instance" assertion goes red (the cell reads "(none)")

Recompile the whole `OcuPilot` package after any mutation to an inherited method before reading a result, and confirm which compiled copy ran.

**QA falsification pass (2026-09-17), one different mutation per AC from the row above, against `ocupilot-b-ci`:**

- AC2 — mutation: append `"NotARealField"` to `read.fields` in `LockList.cls` (a field the vendor genuinely never answers, unlike `PidInternal`, which the endpoint merely excludes) → `Test/ScreenRead.TestEveryDeclaredReadFieldIsAKeyOfTheLiveRow` goes red naming `OcuPilot.Screen.Descriptor.LockList` and the field (observed, reverted)
- AC3 — **Rule 19 finding, not a redder mutation.** The recorded mutation (an `ns` criterion) stays green because the vendor's `WebListFilterFetch` reads only `filter`; probed further by forwarding `pCriteria("ns")` straight onto the vendor query inside `Read.Execute`'s admin branch, bypassing `SeedCriteria` entirely — still green (observed, reverted). Structurally, the admin-LIST branch never reads `OcuPilot.Kernel.Scope.Current()` (only the `mgmnt` branch does), and `OcuPilot.Api.Router.OnPreDispatch` never switches real `$NAMESPACE` for any request. **The existing `TestTheLocksReadIsTheSameFromEveryNamespace` is vacuous by construction**: its `pCriteria("ns")` value is read by nothing on either call, so the two calls are byte-identical regardless of what "ns" it carries — it cannot fail through this path for any reachable reason, not merely the one already tried. Closed by two additive tests in `Test/ScreenRead.cls`: `TestTheLocksReadDeclaresNoCriteriaAtAll` pins the structural fact ("No `ns` in the read" literally means no `criteria` block at all) and reddens on the very regression the original test could not catch — verified live: adding `{"criteria": {"fields": [{"param": "ns", "kind": "text"}]}}` to the read reddens the new test while `TestTheLocksReadIsTheSameFromEveryNamespace` stays green (observed, reverted); `TestTheLocksReadIgnoresTheResolvedNamespaceScope` replaces the inert `pCriteria` key with the real per-request mechanism (`OcuPilot.Kernel.Scope.Set`), documented as unfalsifiable today for the same architectural reason, rather than left as a silent assumption
- AC7 — mutation: remove `%Admin_Operate:USE` (the first pair, not the second) from `privileges` → `WireSecurityRead.TestTheLocksListPairSetIsEnforcedForARealPrincipal` goes red on `..#BOTHUSER`'s refusal, and `TestTheProcessesListsPairSetIsEnforcedForARealPrincipal`'s screen-roster assertion goes red too (observed, reverted)
- AC10 — mutation: point the `System` column's `emptyKey` at a different declared string (`lockListEmpty`) instead of dropping it → the browser leg's every row reads "No locks on this instance." instead of "This instance" (observed against a rebuilt, redeployed bundle; reverted)

No new gap: both AC2's and AC7's fresh mutations reddened for the right reason on the first try; AC3's did not, and is closed by the two tests above rather than filed to the ledger.

## Auto Run Result

Status: done
Blocking condition: none

Implemented on Sonnet, falsified by an independent QA pass, then reviewed on Opus with four layers. The review added the two roster fixture registries that pin each engine's wiring, an assertion that the read answers values rather than null-filled keys, and removed AC3's two comparisons, which could not fail and compared two live reads of a volatile table; `TestTheLocksReadDeclaresNoCriteriaAtAll` is the pin. DW-1078 is escalated to the burn-down gate: the grammar still admits a target screen whose composite id has more than one part.
