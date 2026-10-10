---
title: 'Story 18.30: Doc DB applications'
type: 'feature'
created: '2026-10-10'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-18-context.md'
warnings: ['oversized']
deferred: []
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

**S0:** no `Security.DocDBs` record whose name begins `OcuProbe1830`, `AuthOptionsProbe.Remaining()` 0, no probe resource.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none
