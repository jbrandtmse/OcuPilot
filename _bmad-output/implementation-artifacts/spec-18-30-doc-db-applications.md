---
title: 'Story 18.30: Doc DB applications'
type: 'feature'
created: '2026-10-10'
status: 'done'
baseline_revision: '7e2006816d9e0f49327717c5c19294392511581b'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-18-context.md'
warnings: ['oversized']
deferred:
  - summary: >-
      Unify the Superserver, MFT connection and Doc DB application Saves, Rules and editor forms under one base (Rule 31).
    evidence: |-
      DocDbAppSave, DocDbAppRules and the docdb-app-form files repeat the MFT connection ones with the field set changed;
      the copies were planned because a base outside the slices would move two shipped Saves (spec Code Map).
    location: >-
      src/OcuPilot/Area/WebApp/DocDbAppSave.cls
    severity: low
  - summary: >-
      Replace the "mapping" wording in MappingMint's refusals with noun parameters once Story 20.3 has merged.
    evidence: |-
      MappingMint is shared by the Doc DB application tools and still words its refusals for a mapping; Story 20.3 is
      changing the file, so this story did not edit it (DW-2279).
    location: >-
      src/OcuPilot/Screen/Tool/MappingMint.cls
    severity: low
  - summary: >-
      Vendor candidate, decision-pending and never reported upstream: the DocDB PUT answers a Description over 256
      characters with a logged 500 in place of a validation fault.
    evidence: |-
      Measured by the implement stage on ocupilot-ci. DocDbAppRules refuses the value before any PUT, so no user meets
      it through OcuPilot; the owner's hold on IRIS defect candidates applies.
    location: >-
      DocDB PUT /doc-db?name=&namespace=
    severity: low
---

<intent-contract>

## Intent

**Problem:** Doc DB applications, the `Security.DocDBs` records behind the classic `%CSP.UI.Portal.Applications.DocDBList` and `.DocDB` pages (`%Admin_Secure`), are classic-only. The admin API carries them as `DocDB`: `GET /doc-dbs`, and `GET`, `PUT`, `DELETE /doc-db?name=&namespace=`.

**Approach:** A Web applications list at position 4 and an unlisted editor form, with `webapp.docdbapps.read` and create, update and delete tools. A record is keyed `[Namespace, Name]`, both case-insensitive. The story manages these records only.

## Boundaries & Constraints

**Always:**

- One declared read (`DocDB` `LIST`) serves the list and the read tool (AD-36); the form reads through its own route.
- Keys (AD-22): create (AD-54) and update (a merge of all three fields, AD-4) `true`, delete (destructive) `false`. Both callers (AD-53, AD-55) hold the target (AD-34), read back (AD-58) and emit a change event naming the tool (AD-14).
- `Description`, `Enabled`, `Resource` are `ordinary`. `[Namespace, Name]` is the id, never changed by an update; both callers send the name as typed and the namespace upper-cased, so a record stores one spelling.
- Every Rules row is refused before any `PUT` on both callers, as a field violation with OcuPilot's own sentence (AD-39); an update checks only the fields it changes.
- Codes in `Api/DocDbAppError.cls` (`DOCDBAPP.`; `DOCDB.` is 19.17's). Probes write only on `ocupilot-ci`, prefix `OcuProbe1830`, removed by exact name; one test class per call.

**Never:**

- Change Story 19.17's document databases (`DocDbPort`, `DocDbSave`, `ExplorerDocDb*`, `explorer.docdb.*`), create or drop one, or make a record on its behalf.
- Build on DW-2084 or another owner-hold entry. Edit `Screen/Tool/MappingMint.cls` (Epic 20's Story 20.3 is changing it).
- Add an AD-10 arm or prohibited code: OcuPilot owns no Doc DB application.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Read | The list, or `webapp.docdbapps.read` | One read's rows, `Enabled` a boolean | A missing pair: 403 naming it |
| Create | `OcuProbe1830A` in `user` | 201; stored as `OcuProbe1830A` in `USER` by either caller; read-back `matches` | Present in any case: refused by the absence fingerprint |
| Update | A probe's `Description` | The fresh read's three fields with the change | Moved target refused; a held lock: 409 `WRITE.TARGETBUSY` after 10 s |
| Delete | A probe | Gone; the screen's confirmation is typed against `Name` | Absent: 404 `PORT.NOTFOUND` |
| Rules | `Name` failing `%Dictionary.Classname.IsValid`; `Namespace` empty or refused by `AdminPort.NamespaceDefined`; `Description` over 256 characters; `Enabled` not `true`, `false`, `1`, `0`, `"1"`, `"0"`; `Resource` neither empty nor a listed `Service` or `Application` resource; a string field of another type | 422 `DOCDBAPP.*` on the field; nothing sent | The mint refuses identically, an empty `Name` or `Namespace` as 400 `TOOL.ARGUMENTS` |

</intent-contract>

## Code Map

Paths are under `src/OcuPilot/` unless they begin `ui/`. **Analog: Story 18.26** (`git show --stat e2692f10 8b615c91 371c3979`): its new files and edited rosters each have a counterpart here.

New, with the sibling each extends or copies (Rule 31):

- `Port/DocDbAppPort` **extends `NamespacePort`** with `MAPPINGENDPOINTS` `DocDB`: its `MappingQuery` (:198) and `Snippet` (:238) split `[namespace, Name]` under `name` into `namespace`, upper-cased, and `name`, as typed. The list reads through `AdminPort` (`port: admin`).
- Mint: **`Screen/Tool/MappingMint` as it is** (`Namespace`, `Name`; id parameter `name`).
- `Screen/Tool/DocDbAppCreate`, `Update`, `Delete`: the `MftConnection*` tools' declarations (no shared base; declarations only). `Namespace` is declared as in `MappingCreate.InputSchema` (:81).
- `Area/WebApp/DocDbAppRules`, `DocDbAppSave`: `MftConnectionRules` and `MftConnectionSave`'s shape, copied: a slice never depends on another (spine), and a base outside the slices would move two shipped Saves.
- `Api/DocDbAppError`, `Screen/Descriptor/DocDbAppList`, `DocDbAppForm`: their `MftConnection*` siblings' shape.
- `ui/src/app/areas/web-applications/docdb-app-form.page.ts`, `.store.ts`, `docdb-app-actions.ts`: the MFT form's, copied (no form base exists). Pickers: `ScopeService.namespaces()` (`core/scope.ts:152`); `ResourceList`'s read, issued as the MFT store issues `SslConfigList`'s (:386-398): its `Service` and `Application` rows, and none.
- `Test/DocDbAppProbe` (`MftProbe`'s shape). Reused: `AuthOptionsProbe.SeedPrincipal`, `LicenseProbe.Confirm`, `Test/Http`.

Kernel seam: `Screen/Tool/Write.cls` gains `TypedId(pArgs)`, defaulting to `pArgs.%Get(..IdArgument())`, read by `Kernel/Proposal/Confirm.cls:692-695` and `Draft.cls:147-150` (guards kept). Without it a confirmed create sends the folded id and the vendor stores the name lower-cased.

## Tasks & Acceptance

**Task 0** (on `ocupilot-ci`, after `LOAD-OK` and `STARTPATH-OK`): record S0; halt on a contradiction with Design Notes.

**Execution:**

1. `Kernel/EntityType.cls` `TYPES` :100: `docdb-application`, `foldcase` in `Kernel/EntityRef.cls` `IDRULES` :59 and `ui/src/app/core/entity-ref.ts` `ID_RULES` :66.
2. The `TypedId` seam (`Write.cls`, `Confirm.cls`, `Draft.cls`), other tools unchanged; `DocDbAppCreate` overrides it to join `[Namespace, Name]` as typed.
3. `DocDbAppPort`; `DocDB/PUT`, `DocDB/DELETE` in `MUTATINGTYPES` (`Port/AdminPort.cls` :480, `Test/PortFixture.cls` :21), `DocDB/DELETE` in `BODYLESSTYPES` (:496).
4. `DocDbAppList`: `web-applications/docdb-applications`, listed at 4, `list`, `instance`, composite id `[Namespace, Name]`, the area's pairs, create, delete, columns `Name` (name), `Namespace`, `Enabled`, `Resource`, `Description`, `%CSP.UI.Portal.Applications.DocDBList`, three prompts, `webapp.docdbapps`. `DocDbAppForm`: `.../edit`, position 0, `form-page`, `%CSP.UI.Portal.Applications.DocDB`, three prompts, `webapp.docdbappform`.
5. Tools (`DocDbAppList`, `DocDbAppPort`, `MappingMint`, `%Admin_Secure:USE`): create (`CREATES`, `PUT`, three fields, `CLASSICPAGES` `%CSP.UI.Portal.Applications.DocDB`); update (merge, same `CLASSICPAGES`); delete (`SENDSBODY` 0, `DESTRUCTIVE`, `SCREENACTIONS` `delete`, `READANSWERS` and `FINGERPRINTSUBJECT` `Description,Enabled,Resource`, no `CONSEQUENCECODE`, as the classic page). Create and update call `DocDbAppRules.Problem` from `ArgumentProblem`; their `Enabled` description names its six values.
6. `DocDbAppRules`: `Problem`, `Check` (`Resource` against `Security.Resource` `LIST` through the port), `HandleForm` (`GET /docdb-application/form?id=` answers `{row}`), `Gate`, `RenderRead`. `DocDbAppSave`: `HandleCreate`, `HandleUpdate` (hold, rules, prohibited set, `PUT`, read-back).
7. `Api/Error.cls` :1231, :1442; routes beside `Api/Router.cls` :254-256 (form, `:id`, create); `Screen/Tool/Classification.cls` beside :662-672, then `bash scripts/field-lists.sh`; `Kernel/Proposal/Prohibited.cls` add-only (type beside :637, `COVEREDTYPES` :259, fail-closed :1321, fields :1076 and :1211, `ReviewedFewOnly` as :1595-1598); `Kernel/Governance/Baseline.cls` `true`, `true`, `false`.
8. Client: the form (`Name`, `Namespace` editable on create only; pickers; sticky Save; unsaved-changes guard) and `docdb-app-actions.ts`. Wiring: `shell/screen-outlet.ts` (:242); `shell/screen-action-handler.ts` (:112; `TYPED_NAME_ROWS` :532 `{name: 'Name'}`); `app.ts` sign-out reset (:723); `node tools/screen-mirror.mjs`.
9. Strings: `strings.ts` add-only, cited `/** EXPERIENCE.md:NNN */`; EXPERIENCE.md (1044 lines) in place at :167 (side bar) and :357, tagged `[ADDED 2026-10-10 - Story 18.30]`. 2985 of 3000 are used; past 3000 (expected), the bound becomes exactly 3400 with a comment naming ruling Q3 (2026-10-09).

**Tests** (all but the descriptor class armed by `OCUPILOT_ALLOW_PRINCIPALS`; `OnAfterOneTest` calls `DocDbAppProbe.RemoveAll`):

10. `DocDbAppDescriptor`: descriptors, membership (no count literal), `[USER, OcuProbe1830A]` and `[user, ocuprobe1830a]` one key, classification, baseline, tools. `DocDbAppRead`: one set of rows for screen and tool; the form read; absent is 404. `DocDbAppWrite`: the matrix and C3 through both callers, and the routes over the wire. `DocDbAppGate`: a principal holding exactly the area's pairs (and the install code database's READ) does every operation; without `%Admin_Secure:USE` each is refused by name before any port call.
11. The page and store specs; `ui/browser/docdb-applications.browser-spec.mjs`: the list from the side bar; a probe created, its `Description` changed, deleted with the typed name; it waits for the list's answered signal (empty state or the probe's row) before counting or clicking; an after hook calls `RemoveAll`.
12. **Shared-surface sweep (Rule 30).** Update each pin; run each changed class or file:
    - Entity types 63 to 64: `Test/Descriptor.cls:1762`, `SuperserverDescriptor.cls:130`, `MftConnectionDescriptor.cls:141` (20.3 adds one too: the merge sums).
    - Tools: `ReadTool.cls:93-94` (323 to 327, names); `SurfaceCoverage` (two screen, three tool rows); `EndpointCoverage` (three probes, as 18.26's :266-268); `ToolRoundTrip` `REFUSEEMPTY` :84; `ToolWrite` (derived); `Governance` and `ToolDispatch` (`DOCDBAPPDELETE` in each `$Select`, as `PCTACCESSDELETE`); `GovernanceBaseline` `DISABLED` :15.
    - Ports and pages: `PortGate` `ROSTER` :29; `ClassicPageGate` `OWNPAIRS` :75 and message; `MappingDescriptor` `CLASSICROSTER` :24; `Prohibited` `CoveredTypes` :232; `DraftRegistry` `SPLITTARGETS` :46; `SaveHoldCoverage` (a `/docdb-application` leg); `Descriptor` `ReadShapes`; `ScreenRead` :222; `ui/tools/screen-mirror.test.mjs` :230-281.
    - Area: `Wire.cls:534`; `WireSecurityRead.cls:847`, `:998`, `:1027`; `WebSessionsLive.cls:290`; `ui/tools/navigation.test.mjs` :253-260, :595-599; `side-bar-pins.test.mjs`.
    - `scripts/ci-throwaway.sh` `OCUPILOT_ALLOW_PRINCIPALS`: `# classes: DocDbAppGate, DocDbAppRead, DocDbAppWrite` (`ci.test.mjs`).

**Acceptance Criteria:**

- **C1.** Given the list and `webapp.docdbapps.read`, when each reads, then both answer one read's rows, and the form read answers one record's five fields.
- **C2.** Given a probe, when either caller creates, changes and deletes it, then each result and refusal holds as the matrix says, the read-back reading `matches` (absent after the delete).
- **C3.** Given a create of `OcuProbe1830Mixed` in `user`, when either caller performs it, then the record stores `OcuProbe1830Mixed` in `USER`.
- **C4.** Given a Rules row, when either caller sends it, then it is refused before any `PUT`, as the matrix says.
- **C5.** Given Story 19.17's document databases, when this change is applied, then none of its classes or keys differ (`git diff`) and `DocDbWrite` passes in the sweep.
- **C6.** Given the rosters, when the suites run, then the side bar lists Doc DB applications at 4, the keys read `true`, `true`, `false`, `docdb-application` is pinned on both sides with `foldcase`, and the Fixed strings stay within the bound.
- **Integration.** The page consumes `GET /docdb-application/form`, `POST /docdb-application`, `PUT /docdb-application/:id` and the delete action, and the agent the four tools, on `ocupilot-ci` (C1-C4, the browser spec).

## Spec Change Log

## Review Triage Log

### 2026-10-10 — Review pass

- verdicts: 18 findings — high 0, medium 4, low 9, false 5, maybe-false 0
- findings:
  - `[medium]` `[patch]` The shared live-row sweep skips `DocDbAppList` and `DocDbAppRead` pinned neither the list's `Description` and `Resource` nor a form read of a non-empty `Resource` — `DocDbAppRead` now seeds a resource-bound probe, checks every declared field against the raw `DocDB` `LIST` row, compares the screen rows' description and resource, and reads a non-empty `Resource` through the form; mutated (runs 641).
  - `[medium]` `[patch]` The `Keys(...)` assertions in `DocDbAppRead` hold whatever the vendor row carries (same root cause as the row above) — replaced by the live-row check and the value comparison above.
  - `[medium]` `[patch]` `Draft.Render`'s use of the new `TypedId` seam was pinned by no test — `DocDbAppRead.TestTheDraftOfACreateNamesTheRecordAsTyped` drives the copy-out route over a Doc DB create; reverting the seam makes the draft answer an error (641).
  - `[low]` `[patch]` Client specs, the browser spec, the C6 client pins and the new roster rows had no recorded mutation — each mutated, red observed, reverted byte-identical and recorded in `## Verification`; the browser leg ran against a rebuilt and redeployed bundle.
  - `[low]` `[patch]` The C3 mutation line pointed at a batch that holds no `TypedId` mutation — the line cites run 651, where removing the override reddens `DocDbAppDescriptor.TestTheCreateNamesItsTargetAsTyped`.
  - `[medium]` `[patch]` No test sent an update with an admitted non-boolean `Enabled` — `DocDbAppWrite.TestEveryEnabledFormChangesTheFlagOnTheFormsSave` sends each of the six forms through the Save against a record holding the opposite flag; green first time, so no defect, and a mutation of `IsEnabled` reddens it (642).
  - `[low]` `[patch]` `TestTheSideBarListsTheScreenAfterTheAreasOtherEntries` asserted "last listed entry" as a bare tripwire — the assertion is dropped, the position-3 predecessor and `navigation.test.mjs` hold the order.
  - `[low]` `[reject]` Through `Write.View` the schema types `Enabled` boolean, so `1`, `0`, `"1"` and `"0"` reach the rules only at the mint and the Save — the validator has no union type and a refusal names the property and the type, so the model resends a boolean; the fix is beyond a direct correction.
  - `[low]` `[reject]` Read refusals are tested for `%Admin_Secure` on the screen read route alone — the screen and `webapp.docdbapps.read` take the one descriptor's pairs and `DocDbAppGate` holds every write and the read route to them.
  - `[low]` `[reject]` `WRITE.TARGETBUSY` is tested for the form's create and update, not under an agent confirm — the confirm's hold is the kernel's shared path, which this story leaves as it was.
  - `[false]` `[reject]` A create present in any case is refused by `DOCDBAPP.TAKEN` on the Save and by the absence fingerprint on the agent — the Design Notes decide exactly this split.
  - `[false]` `[reject]` The Save judges every field sent before the read and only changed fields after it — a value that breaks a rule can never equal a stored one except `Resource`, which only the post-read pass judges and `TestEveryChangeRuleIsRefusedBeforeAnyPutOnBothCallers` pins.
  - `[low]` `[reject]` No test confirms a stored proposal that has since become invalid — the rules read no state but `Resource`, which a confirm re-checks; unlikely to be met.
  - `[low]` `[reject]` Field refusals appear only in jsdom specs — Task 11 asks the browser spec for create, change and typed-name delete.
  - `[false]` `[reject]` `Write.TypedId`, `Confirm` and `Draft` are touched beyond the named surface — Task 2 prescribes them and the default delegates to the old read.
  - `[false]` `[reject]` The `Prohibited` type branch is an "AD-10 arm" — Task 7 prescribes the `ReviewedFewOnly` branch; no predicate or `PROHIBITED.*` code is added.
  - `[low]` `[reject]` `RemoveAll` clears the monitor and the browser spec accepts any throwaway — five sibling probes clear the monitor, and a browser spec runs against the shard's own throwaway.
  - `[false]` `[reject]` DW-2084 cannot be judged from the diff — `git diff` over `DocDbPort`, `DocDbSave` and `ExplorerDocDb*` is empty and `DocDbWrite` is green.

## Design Notes

**Measured at plan** (2026-10-10, `ocupilot-ci` after `LOAD-OK`; 18.10's first-plan baseline, `git show 622b70eb:<spec>`, holds):

- A `PUT` naming `ocuprobe1830a` in `user` changed `OcuProbe1830A`, keeping its name; a create naming `ocuprobe1830b` in `user` stored `ocuprobe1830b` in `USER`.
- `Enabled` sent `false`, then `"1"`, read `false`, then `true`. A repeated `DELETE` answers 404 #793.
- A principal holding exactly `%Admin_Secure:USE`, `%DB_IRISSYS:READ`, `%DB_HSCUSTOM:READ` listed, created and deleted over HTTP; in process it passed `NamespaceDefined` (`USER`, `user` 1; absent 0) and the `Security.Resource` and `DocDB` reads.
- Only `Security.Resource` `LIST` answers `ResourceType` (`Service`, `Application` and four others); `Security.Resources.Create` makes an `Application` one. The classic page offers service, application and user resources.
- S0 held afterwards; the alert state read 0.

**Decisions** (each for the spine at the gate, Rule 20):

- AD-13: the id is `[Namespace, Name]`, as `MappingMint` and `NamespacePort` expect, `foldcase` since the instance resolves both parts in any case. AD-54: a composite create sends its name as typed through `TypedId`.
- AD-8: the area's set, nothing beyond it (measured). AD-4: `DocDB` keeps omitted keys and is an upsert. AD-44: create and update declare `%CSP.UI.Portal.Applications.DocDB`; the delete, on the list's page, none.
- `Resource` is empty or a listed `Service` or `Application` resource, as the classic page offers (inference: only `%All` holds `USE` on a `%DB_*` resource). `Namespace` must be defined and `Name` pass the record's datatype: an invalid name fails as a logged 500 (inference).
- Codes: `DOCDBAPP.VALIDATION`, `.NAME`, `.NAMESPACE`, `.DESCRIPTION`, `.ENABLED`, `.RESOURCE`, `.TAKEN` (a screen create of a present record).
- Ledger candidates: one base for the Superserver, MFT and Doc DB Saves, Rules and forms (Rule 31); after 20.3 merges, `MappingMint`'s noun parameters for this story's "mapping" wording.

**DW-2084** (owner hold: the REST drop needs a `Security.DocDBs` record): this story manages records only, never makes one for a database, leaves `DocDbPort`'s drop unchanged and reports nothing upstream.

**Governing ADs:** AD-2, 3, 4, 5, 6, 8, 10, 13, 14, 15, 22, 27, 34, 36, 39, 44, 52, 53, 54, 55, 58, 59. **Consumed-by:** 18.12 (the agent's tools). **Consumes:** 18.14 (`NamespacePort`, `MappingMint`), 8.x (`ResourceList`'s read), 18.26 (the shape). **Integration ACs:** the Integration line, `DocDbAppWrite`, the browser spec. **Ledger:** the inbox is empty.

## Verification

Shared surfaces: Web applications side bar and screen lists, entity types, tool and route rosters, governance baseline, classic-page rosters, Fixed strings.

Standing criterion: *existing tests that assert a surface this story changes are updated in this story, and every test the story adds or changes passes on a freshly built instance and in either order.*

**Commands:**

- `(loop)` `sh /Users/jbrandt/git/OcuPilot/.worktrees/.coordination/carry-2026-10-08/epic-18-d8/load-ocupilot-ci.sh` -- expected: `LOAD-OK`, `STARTPATH-OK`.
- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.<C>`, one at a time, totals checked in `%UnitTest_Result`: the four new classes and each class Task 12 changed.
- `(loop)` `cd ui && npm run test:tools`, `npm run test:components`; `uv run scripts/check-objectscript.py`.
- `(loop)` With `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776`, `OCUPILOT_BROWSER_CONTAINER=ocupilot-ci`: `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`, then `node --test --test-concurrency=1 browser/docdb-applications.browser-spec.mjs` and each spec Task 12 changed.
- `(once, before dev_complete)` The full ObjectScript sweep, one class at a time; `cd ui && npm test && npm run build`, re-measuring the bundle (3,190,536 bytes at 18.10; warning 3326kB; re-base if crossed, DW-1166); `bash scripts/smoke.sh --container ocupilot-ci --user _SYSTEM --password SYS`; S0.

**Mutations (Rule 19; the implement stage records each as `mutation:`):** C1 the read tool reads another endpoint; C2 no absence fingerprint; C3 `TypedId` override removed (the agent leg stores the name lower-cased); C4 one rule removed; C6 the delete key `true`. C5 is the diff and needs none.

- mutation: C1 `DocDbAppList` read source `DocDB` pointed at `WebApp.App` → `DocDbAppRead.TestTheScreenAndTheReadToolAnswerTheSameRows` red (run 615).
- mutation: C2 `Mint.AbsenceState` ignores its argument (no absence fingerprint; `Mint` and its 22 descendants recompiled) → `DocDbAppWrite.TestATakenNameAMovedTargetAndABusyTargetAreRefused` red (run 616).
- mutation: C3 `DocDbAppCreate.TypedId` removed → `DocDbAppWrite.TestACreateStoresTheNameAsTypedOnBothCallers` red, the agent leg storing the name lower-cased (run 617); `DocDbAppDescriptor.TestTheCreateNamesItsTargetAsTyped` red (run 651).
- mutation: C4 `DocDbAppRules.Valid` accepts any `Description` (the length rule removed) → `DocDbAppWrite.TestEveryCreateRuleIsRefusedBeforeAnyPutOnBothCallers` and `TestEveryChangeRuleIsRefusedBeforeAnyPutOnBothCallers` red, the vendor answering 500 (run 618).
- mutation: C6 `Baseline` `webapp.docdbapps.delete` set `true` → `DocDbAppDescriptor.TestTheBaselineKeysShipAsTheSpecSays` red (run 619).
- mutation: C5 is the diff: `git diff --stat` over `DocDbPort`, `Area/Explorer`, `ExplorerDocDb*`, `DocDbError` and `ExplorerDocDbList` is empty and `Baseline` gains the three `webapp.docdbapps` lines alone; `DocDbWrite` green (run 630).
- mutation (descriptor batch, each reddening its own test in one run, 621): list `sideBarPosition` 5 → `TestTheListIsDeclaredAsTheSpecPlacesIt`; update `PERMITTEDFIELDS` without `Resource` → `TestTheToolsDeclareTheirKindPortPairsAndFields`; create entry's `Resource` classified secret → `TestTheClassificationIsReviewed`; `docdb-application:foldcase` dropped from `IDRULES` → `TestTheEntityTypeKeepsOneKeyForAnyCase`; delete `READANSWERS` without `Resource` → `TestTheDeleteCardListsWhatTheActionRemoves`; `REASONENABLED` emptied → `TestTheCodesAnswerTheirSentences`.
- mutation (port, run 622): `DocDbAppPort.MAPPINGENDPOINTS` emptied → all four `DocDbAppRead` tests red, the split, form and script legs among them.
- mutation (write batch, 624 and 626): `DocDbAppRules.CreateBody` returns its argument → `TestEveryEnabledFormIsStoredAsABooleanOnBothCallers` and `TestACreateOfTheTwoPartsAloneTakesTheInstancesDefaults` red; `DocDbAppUpdate.MergeUpdate` drops `Resource` from its payload → `TestAChangeKeepsWhatItDoesNotSendOnBothCallers` red; `RESOURCETYPES` `Application` alone → `TestAListedServiceOrApplicationResourceIsAccepted` red; the update's resource guard in `Check` read as true → `TestEveryChangeRuleIsRefusedBeforeAnyPutOnBothCallers` red alone.
- mutation (gate, 627 and 628): `DocDbAppSave.Gate` passes every caller → `DocDbAppGate.TestWithoutTheAreasResourceEveryReadAndWriteIsRefused` and `TestWithoutTheSystemDatabaseReadEveryWriteIsRefused` red; it refuses every caller → `TestTheDeclaredPairsReadAndWrite` red.
- mutation (review pass, `ocupilot-ci`, the mutated classes loaded each time and reverted byte-identical):
  - `Draft.Render` reads the id argument alone in place of `TypedId` → `DocDbAppRead.TestTheDraftOfACreateNamesTheRecordAsTyped` red (641).
  - `DocDbAppRules.HandleForm` answers an empty `Resource` → `DocDbAppRead.TestTheFormReadAnswersTheFiveFields` red (641); the list's read field `Resource` renamed → `TestTheScreenAndTheReadToolAnswerTheSameRows` red on the live-row key leg (641).
  - `DocDbAppRules.IsEnabled` refuses a number → `DocDbAppWrite.TestEveryEnabledFormChangesTheFlagOnTheFormsSave` red (642).
  - `DocDbAppSave.HandleCreate` holds the name alone → `SaveHoldCoverage.TestACreateSaveHoldsTheKeyItsMintComputes` red (643).
  - Roster rows removed, each reddening its own test: `ToolRoundTrip` `REFUSEEMPTY` → `TestEveryToolConformsToItsResultSchemaOrAnswersACode` (645); `ClassicPageGate` `OWNPAIRS` → `TestWithNoAssignmentEachToolsPairsAreItsDeclaredSet` (646); `MappingDescriptor` `CLASSICROSTER` → `TestTheClassicPagesRosterIsTheDeclaringTools` (647); `ReadTool` names → `TestTheRegistryListsDescriptorReadsAndInheritedKinds` (648); `SurfaceCoverage` delete row → `TestEveryWriteToolHasACoverageRowAndBack` (649); `EndpointCoverage` form probe → `TestEveryRouteHasAProbeAndEveryProbeHasARoute` (650).
- mutation (client, Integration and C6):
  - The store drops `readBackOf` → `docdb-app-form.page.spec.ts` create leg red; the page binds Description to the `Resource` field → its create and edit legs red; `DocDbAppActions` drops its `register` → `docdb-app-actions.spec.ts` two tests red; `app.ts` drops `docDbAppForm.reset()` → `app.spec.ts` AD-8 sign-out red.
  - `TYPED_NAME_ROWS` loses the list's entry → `screen-action-handler.spec.ts` Doc DB Delete red and, with the bundle rebuilt and redeployed, the create, change and delete leg of `docdb-applications.browser-spec.mjs` red.
  - The mirror lists the screen at position 0 → `navigation.test.mjs` side-bar order red; `docdb-application:foldcase` dropped from `IDRULES` → `screen-mirror.test.mjs` AD-13 id-rule table red; a Fixed string removed from `strings.ts` → `strings.test.mjs` three legs red.

**S0:** no `Security.DocDBs` record whose name begins `OcuProbe1830`, `AuthOptionsProbe.Remaining()` 0, no probe resource.

## Auto Run Result

Status: done
Blocking condition: none

**Summary.** Doc DB applications (`Security.DocDBs`) have a Web applications list at position 4, an unlisted editor form, `webapp.docdbapps.read` and create, update and delete tools. The id is `[Namespace, Name]` (`foldcase`); a create stores the name as typed in the upper-cased namespace on both callers through a new `Write.TypedId` seam. Governance keys read true, true, false.

**Files.**

- New ObjectScript: `Port/DocDbAppPort`, `Api/DocDbAppError`, `Area/WebApp/DocDbAppRules` and `DocDbAppSave`, `Screen/Descriptor/DocDbAppList` and `DocDbAppForm`, `Screen/Tool/DocDbAppCreate`, `Update`, `Delete`; tests `DocDbAppProbe`, `DocDbAppDescriptor`, `DocDbAppRead`, `DocDbAppWrite`, `DocDbAppGate`.
- Edited ObjectScript: the `TypedId` seam (`Write`, `Confirm`, `Draft`), `EntityType`, `EntityRef`, `Baseline`, `Prohibited`, `AdminPort`, `Error`, `Router`, `Classification`, `ToolFields`, `ci-throwaway.sh`, and the Rule 30 rosters in 21 test classes.
- Client: the form page, store and actions with specs, `screen-outlet`, `screen-action-handler`, `app.ts`, `strings.ts`, the regenerated `screens.generated.ts`, four tools tests, `docdb-applications.browser-spec.mjs`; `EXPERIENCE.md` at :167 and :357.

**Review.** 18 findings: 7 patched (4 medium, 3 low; test additions and comments only), 11 rejected with their reasons in the triage log, 3 items deferred (two ledger candidates and one vendor candidate, decision-pending). Follow-up review recommended: false; the patches changed no production code and each ran green and was mutated.

**Verification.** On `ocupilot-ci`: `DocDbAppDescriptor` 10/10 (654), `DocDbAppRead` 5/5 (652), `DocDbAppWrite` 11/11 (653), `DocDbAppGate` 3/3 (637), every sweep-changed class green; `test:tools` 1904/1904, `test:components` 2786/2786, `check-objectscript.py` 0 problems, `lint-docs.sh` clean, the browser spec 2/2, `smoke.sh` 49 of 49 with one skipped. Initial bundle 3,213,418 bytes (warning 3,326 kB, `angular.json` unchanged). Fixed strings 3000 of a bound raised to 3400 under ruling Q3. S0 held. Mutations are recorded in `## Verification`.

**Residual risks.** The new and changed tests have not yet met a fresh instance in either order (the runner's Rule 30 check). The spine's AD-13 amendment spells the entity type `doc-db-application`, the spec and code `docdb-application`; the spine line wants the one-word correction. The agent's `Enabled` schema is boolean, so `1`, `0`, `"1"` and `"0"` reach the rules through the Save and the mint only.
