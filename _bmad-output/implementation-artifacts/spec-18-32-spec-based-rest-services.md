---
title: 'Story 18.32: Spec-based REST services'
type: 'feature'
created: '2026-10-10'
status: 'blocked'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-18-context.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** The REST API explorer (`RestApiList`, type `rest-service`, port `MgmntPort`) can only read. There is no way to create a spec-based REST service from an OpenAPI document, or to delete one.

**Approach:** Add `webapp.restapis.create` (AD-54) and `webapp.restapis.delete` (AD-51, destructive), the port's first writes. A person creates through a Create dialog (Save route) and deletes through a row action that asks for the typed name. The agent can propose either. Ruling Q2 (B) holds the agent's create to Story 20.21's rules at mint and at Confirm.

## Boundaries & Constraints

**Always:**

- `Name` is a package with no `%`. It generates `<Name>.spec`, `.disp` and `.impl` in the request's namespace.
- The port passes the vendor a parsed `%DynamicObject` and refuses a string (AD-21: a string makes the vendor fetch a URL or read a server file).
- Pairs (AD-8): the screen's own, `%Development:USE`, and WRITE on the namespace's routines database as an argument pair (`ExplorerSave.CodeWritePairs`). The port re-checks the last two before any vendor call.
- The agent's create, at mint and at Confirm, runs `ExplorerSave.AgentProblem(ns, <class>.cls, 1)` on all three names. A person's create skips it.
- An `OcuPilot*` package, in any case, is refused `PROHIBITED.OCUPILOTCODE` on both tools and both callers (AD-10).
- Keys: create `true`, delete `false` (AD-22).
- Each write holds (AD-34), reads back (AD-58) and emits a change event (AD-14).
- Codes live in `Api/RestServiceError.cls`.
- Probes run only on `ocupilot-ci`, prefix `OcuProbe1832`, one test class per call, and never under `/csp/ocuprobe183*` (swept by `DatabaseWriteProbe`).

**Never:**

- Edit `Screen/Tool/Write.cls`, `Api/ScreenAction.cls`, `Kernel/Agent/Dispatch.cls` or `Screen/Read.cls` (Epic 20 is changing them).
- Add an entity type, id rule or prohibited code.
- Copy `AgentProblem`, `ConfirmProblem` or `CodeWritePairs`.
- Delete a deployed service.
- Build on a `decision-pending` entry.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Create | `OcuProbe1832A`, valid 2.0 document, USER | 201. Three classes exist, the row is listed, read-back `matches` (`Name`) | Present in any case: 409 `RESTSERVICE.TAKEN` on screen; agent refused by absence |
| Rules | `Name` not a package, or holds `%`. `Document` not a JSON object, `swagger` not `"2.0"`, or over 1,000,000 characters. Agent only: card over 30,000 characters | 422 `RESTSERVICE.NAME` or `.DOCUMENT` on the field (agent: 400 `TOOL.ARGUMENTS`) | Nothing sent; a string never reaches the vendor |
| Build failure | A 2.0 document the vendor cannot build | 422 `RESTSERVICE.BUILD` on `Document`, no class left | Vendor 404 not logged |
| Delete | A listed service no web application dispatches to | `.spec` and `.disp` gone, `.impl` kept; read-back absent | Not listed exactly: 404 `PORT.NOTFOUND` |
| Delete refused | A web application dispatches to `<Name>.disp`, or the id starts with `/` | 409 `RESTSERVICE.DEPLOYED` | Nothing sent |

</intent-contract>

## Code Map

Paths are under `src/OcuPilot/` unless they begin `ui/`. Each new item names its sibling (Rule 31).

**`Port/MgmntPort.cls`.** `LIST` is unchanged. A new endpoint, `Service`, serves these types:

| Type | Behavior |
|------|----------|
| `STATE` | 404, unlogged, unless `GetRESTApps` lists the name (case ignored). Otherwise `{Name, Namespace}`. |
| `SERVICE` | 404 unless the name is listed exactly. 409 `DEPLOYED` when a `GetWebRESTApps` row has `dispatchClass` `<Name>.disp`, or the id starts with `/`. Otherwise `{Name, Namespace, Implementation}`. |
| `POST` | `CreateApplication(ns, app, doc)`. On 201 or 200, answers `{Name, Namespace}`. A vendor 400 or 404 becomes 422 `BUILD`, unlogged. |
| `DELETE` | `DeleteApplication`. |

Supporting changes:

- A missing namespace becomes `Scope.Current()`, as at `DocDbPort.cls:239`.
- `WRITEPAIRS` holds `%Development:USE`. The WRITE pair comes from `AtelierPort.DatabaseResources`.
- `NameProblem` and `DocumentProblem` follow `DocDbPort.NameProblem`.
- `Call` and `Outcome` (:481, :533) take a third argument.
- `SnippetForm` and `Snippet` (:588-597) answer `rest` for `Service` POST and DELETE: one curl step on `/api/mgmnt/v2/<ns>/<Name>` via `AdminPort.Step` and `ShellQuoted` (:3795, :3815). Every other type answers `""` and `[]`.

**`Screen/Tool/RestServiceWrite.cls`** (abstract) copies `ExplorerDocDbWrite`'s shape. It cannot extend it: the port differs, and WRITE here is an argument pair.

- `IdArgument` `Name`, `IdParam` `application`, `PortQuery` reading the namespace from the payload.
- `PrivilegePairs` adds `%Development:USE` (as `DeviceCreate.cls:159`).
- `ArgumentPairs` is `ExplorerSave.CodeWritePairs`.

**`RestServiceCreate`:**

- `CREATES`, `READTYPE` `STATE`, `WRITETYPE` `POST`, `READBACKFIELDS` `Name`, no `SCREENACTIONS`.
- `InputSchema` as `ExplorerCreate`'s: `Name` a string, `Document` an object.
- `ArgumentProblem` applies the port's rules.
- `AgentProblems(ns, Name)` loops `ExplorerSave.AgentProblem` over the three names. `ConfirmProblem` runs it on the stored `Namespace`.
- `ComposeCreate` builds `{Name, Document, Namespace}` with diff `[args.Hunk]`.
- `MintClass`; consequence `RESTSERVICE.CREATE.COMPILES`.

**`RestServiceCreateMint`** extends `Kernel/Proposal/Mint` and follows `ExplorerCreateMint`, whose `Mint` is bound to AtelierPort. In order:

1. The rules.
2. `IsOcuPilotCode`, refused through `ExplorerSaveMint.Forbidden` (:283).
3. `AgentProblems` in `Scope.Current()`.
4. `ExplorerSaveMint.Hunk("", <%JSON.Formatter text>)` (:243), at most 30,000 characters.
5. `##super`.

**`RestServiceDelete`:**

- `SENDSBODY` 0, `READTYPE` `SERVICE`, `WRITETYPE` `DELETE`, `DESTRUCTIVE`, `SCREENACTIONS` `delete`, `PRECONDITIONCODES` `RESTSERVICE.DEPLOYED`, `FINGERPRINTSUBJECT` `Name,Namespace`.
- Removal row `Name`, via a copy of `ExplorerDocDbDelete.StateDiff` (:57). It is a copy because that method reads its own class's `REMOVALROWS`.

**`Area/WebApp/RestServiceSave.cls`** copies `Area/Explorer/DocDbSave.cls` (:44-205), because a slice never depends on another. `HandleCreate`, in order:

1. The gate: `PrivilegePairs`, then `ArgumentPairs`.
2. The body `{Name, Document}`: text parsed, any other key refused.
3. The hold.
4. The rules.
5. `STATE`: a present name answers 409 `TAKEN`.
6. The prohibited set.
7. `POST`.
8. `ReadBack.ForSave`.
9. 201 `{name, readBack}`.

**`Api/RestServiceError.cls`** (`DocDbAppError`'s shape): `RESTSERVICE.VALIDATION`, `.NAME`, `.DOCUMENT`, `.BUILD`, `.TAKEN`, `.DEPLOYED`.

**Client.** Under `ui/src/app/areas/web-applications/`. Each file copies its Document databases sibling in `system-explorer/`, since there is no shared create dialog.

- `rest-api-list.page.ts` copies `docdb-list.page.ts` (:66, :81).
- `rest-service-create-dialog.ts` copies `docdb-create-dialog.ts` and adds `license-key.page.ts`'s textarea and Load from file (:185-198, :430-442; `.json`; `STRINGS.x509LoadFromFile`).
- `rest-service-create.store.ts` copies `docdb-create.store.ts`, sending `POST /api/ocupilot/rest-service` with `scope: namespace`.

## Tasks & Acceptance

**Task 0** (on `ocupilot-ci`, after `LOAD-OK` and `STARTPATH-OK`): record S0. Halt if it contradicts the Design Notes.

**Execution:**

1. `Port/MgmntPort.cls`, per the Code Map.
2. `Api/RestServiceError.cls`, and `RESTSERVICE.` dispatch in `Api/Error.cls` beside :1232 and :1444.
3. The four tool classes. Each `DESCRIPTION` states its rules. The delete's says `.impl` is kept.
4. `Screen/Descriptor/RestApiList.cls`, as `ExplorerDocDbList.cls:37-38,63-64`: `primaryAction` `create`, `rowActions` `[{"id":"delete","selfProtection":""}]`, `emptyNextKey` `""`, `emptyAgentKey` `restApiListEmptyAgent`. Update the doc at :19-21.
5. `Area/WebApp/RestServiceSave.cls`. In `Api/Router.cls`, add `<Route Url="/rest-service" Method="POST" Call="RestServiceCreate"/>` after :260, and its wrapper beside :1852.
6. `Kernel/Proposal/Prohibited.cls`, add-only:
   - `TYPERESTSERVICE` beside :641.
   - `COVEREDTYPES` :259, and the guard at :1327.
   - After :1395, an arm that refuses `OCUPILOTCODE` when `IsOcuPilotCode(<id>)`.
7. `Kernel/Governance/Baseline.cls`, after :179: `"webapp.restapis.create": true` and `"webapp.restapis.delete": false`.
8. Client:
   - The three new files.
   - `shell/screen-outlet.ts`: `DESCRIPTOR_PAGES` (:266).
   - `shell/screen-action-handler.ts`: `SCREEN_ACTION_DESCRIPTORS` (:64-119) and `DESTRUCTIVE_CONSEQUENCES` (:454-502).
   - `core/proposal-view.ts`: the code (:223) and a `consequenceSentence` line (:397).
   - Run `node tools/screen-mirror.mjs`.
9. Strings. In `strings.ts`, each key cited `/** EXPERIENCE.md:357 */`:
   - `restServiceCreateTitle`, `restServiceNameLabel`, `restServiceNameHint`, `restServiceDocumentLabel`, `restServiceDocumentHint`, `restServiceCreateEffect`, `restServiceDeleteConsequence`, `restApiListEmptyAgent`.
   - Edit EXPERIENCE.md :357 in place: it stays 1044 lines, tagged `[ADDED 2026-10-10 - Story 18.32]`.
   - The count goes from 3000 to about 3008, within the 3400 bound.

**Tests.** `Write` and `Gate` are armed by `OCUPILOT_ALLOW_PRINCIPALS`. `OnAfterOneTest` calls `RestServiceProbe.RemoveAll`.

10. `Test/RestServiceProbe.cls`:
    - `RemoveAll(ns)`: services, `.impl` classes in any case, and `/api/ocuprobe1832*`.
    - `Remaining`, and `Document(title, paths)`.
    - It delegates to `AuthOptionsProbe.SeedPrincipal` (:127) and to `DocDbAppProbe.Mint` and `RunAs` (:195, :205).
11. `Test/RestServiceDescriptor.cls`:
    - Actions, kinds and pairs (`%Development:USE`; `%DB_USER:WRITE` in USER).
    - Schema and keys.
    - `rest-service` is covered, and `OcuPilot*` is refused on both tools.
    - `SnippetForm` answers `rest` for `Service` POST and DELETE, and `""` for `LIST`.
12. `Test/RestServiceWrite.cls`: each matrix row, C1 and C2. Run them through the Save route over the wire and through the agent's mint and confirm. Reuse `ExplorerCreateRules`' `%SYS` and `Ens.*` cases (:94-95).
13. `Test/RestServiceGate.cls`:
    - A principal holding exactly the screen's pairs, `%Development:USE`, `%DB_USER:RW` and the code database's READ creates and deletes in USER.
    - Without `%Development:USE`, or without WRITE, each write is refused by name before any port call.
14. `Test/MgmntPort.cls` and `MgmntImplFixture.cls` (stubs; doc :2-3):
    - The create's 201, 200, 400, 404, 403 and 500 mapping.
    - A build refusal leaves no log line (`LogFault` capture).
15. Client tests:
    - Specs for the three files.
    - A Delete leg in `screen-action-handler.spec.ts` (as at :1676).
    - `ui/browser/rest-services-write.browser-spec.mjs`: a dialog create, a refused document drawn on its field, and a typed-name delete. It waits for the list's answered signal, and runs `RemoveAll` through `runIris` before and after.
16. **Shared-surface sweep (Rule 30).** Update each pin, then run each changed class or file.
    - `Test/ReadTool.cls:93-94`: 327 becomes 329, and add the names.
    - `SurfaceCoverage.cls`: two rows after :412.
    - `ToolRoundTrip.cls:84`: `TOOL.ARGUMENTS` for both tools.
    - `ToolWrite.cls:1338`: 25 becomes 27.
    - `Governance.cls`: `RESTAPIDELETE` after :64 and at :149.
    - `ToolDispatch.cls:172`.
    - `GovernanceBaseline.cls`: :15 and :71.
    - `PortGate.cls:29`: `MgmntPort=PAIRS;WRITEPAIRS`.
    - `EndpointCoverage.cls`: a `POST /rest-service` row (as at :266-268).
    - `SaveHoldCoverage.cls`: a `/rest-service` leg.
    - `Test/Prohibited.cls`: :220 and :235 move `rest-service` to `log-entry`; :232 updates the covered types and their count word.
    - `DraftRegistry.cls`: `TYPEDTARGETIDS` (:60) gets `rest-service=OcuDraftRest`, because the default id begins `OcuPilot`. Add a `Document` entry to `STRUCTUREDFIELDS` (:37) if needed.
    - `DraftNoForm.cls`: the doc at :2-3.
    - `scripts/ci-throwaway.sh`: after :388, `# classes: RestServiceGate, RestServiceWrite`.
    - Unchanged: entity types (64), prohibited codes (34), `ClassicPageGate`, `MappingDescriptor`.

**Acceptance Criteria:**

- **C1.** Given a valid 2.0 document, when a person creates `OcuProbe1832A` and the agent's create of `OcuProbe1832B` is confirmed in USER, then each succeeds: three classes exist, the row is listed, and read-back reads `matches`. When each is deleted (the screen's Delete; the agent's, with its key enabled for the test), then `.spec` and `.disp` are gone, `.impl` is kept, and read-back reads absent.
- **C2.** Given the agent proposes a create in `%SYS`, of `Ens.OcuProbe1832C` (ENSLIB), or of `OcuPilotProbe1832`, when it is minted, then it is refused with the `AgentProblem` sentence or 403 `PROHIBITED.OCUPILOTCODE`, and nothing is stored. A stored proposal whose `Namespace` is `%SYS` is refused at Confirm before any POST.
- **C3.** Given each matrix refusal, when either caller sends it, then it is refused as the matrix says and the vendor is not called.
- **C4.** Given the baseline, when the agent proposes a delete with defaults, then dispatch refuses it by governance, and the create's key reads `true`.
- **C5.** Given the rosters, when the suites run, then the tools and the route are pinned, `rest-service` is covered, and the Fixed strings stay within the bound.
- **Integration.** Given `ocupilot-ci`, when they run, then the page consumes `POST /rest-service` and the delete action, and the agent consumes both tools (C1, the browser spec).

## Spec Change Log

## Review Triage Log

## Design Notes

**Measured at plan.** On `ocupilot-ci` (2026-10-10). The vendor was called in process behind fresh `%request` and `%response` stubs, as the port calls it. 18.10's HTTP baseline holds, pairs included.

- Create answered 201, then 200 on a repeat, and generated the three classes. A `GetRESTApps` row is `{name, dispatchClass, namespace, swaggerSpec}`.
- `ocuprobe1832a` over `OcuProbe1832A` answered 404 (`#5092`). Nothing was created.
- An undeclared path parameter answered 404 (`#8711`). No class was left.
- Delete answered 200. It removed `.spec` and `.disp`, kept `.impl`, and the list dropped the name. An absent name also answered 200.
- A re-create over a kept `.impl` answered 201. The `.impl` kept a hand-added method and gained the new operation's method.
- `/api/ocuprobe1832d` dispatching to the service answered `ping` with 200. After the delete (which answered 200), it answered 404.
- `AgentProblem(…,1)` answered `""` for `OcuProbe1832A.spec.cls` in USER and ENSLIB for `Ens.OcuProbe1832.impl.cls`, and refused `%SYS`. `IsOcuPilotCode("ocupilotx.spec.cls")` is 1.
- S0 held afterwards.

**Decisions:**

- No id rule. Presence ignores case, which `#5092` enforces.
- The delete takes no `AgentProblem`, like 19.2's agent delete.
- The build refusal is unlogged, as 18.6's 400 is.
- Delete stays drawn on web-application rows. The refusal answers the click, as `PRESERVEDSESSION` does.

**Governing ADs:** AD-2, 3, 6, 8, 10, 13, 14, 15, 21, 22, 27, 29, 34, 39, 51, 52, 53, 54, 55, 58, 59.

**Consumed-by:** 18.12, the agent's tools.

**Consumes:** 6.1 and 16.1 (`MgmntPort`); 20.20 and 20.21 (`AgentProblem`, `CodeWritePairs`, `Hunk`); 19.17 (dialog and Save).

**Integration ACs:** the Integration line, `RestServiceWrite`, and the browser spec.

**Ledger:** the inbox is empty. One candidate: a shared create dialog and Save (Rule 31).

**For the lead** (Rule 20):

- **AD-53 (ruling Q2 (B)).** Add the paragraph below. Also add "and the REST service create (Story 18.32)" to "the agent authoring code only through these saves", and to the `EXPLORER.SQL.AGENTCODE` clause.

  > "**The spec-based REST service create is the agent's second code path** [AMENDED 2026-10-10, Story 18.32 spec gate, ruling Q2 (B), Rule 20]: `webapp.restapis.create` generates and compiles `<package>.spec`, `.disp` and `.impl` from an OpenAPI 2.0 document the agent sends whole, through `MgmntPort`, held to Story 20.21's rules at the mint and again at Confirm: each generated class is stored in the namespace's own routines database, never in `%SYS` or under a `%` name, and an `OcuPilot*` package is refused `PROHIBITED.OCUPILOTCODE` from either caller. The card shows the whole document, at most 30,000 characters; an `.impl` already present keeps its code and gains a method per new operation (measured). Its key ships enabled; `webapp.restapis.delete`, destructive, ships `false` and refuses a service a web application dispatches to. A person's create is unchanged."

- **AD-8 and AD-29:** `%Development:USE` and the argument WRITE pair, re-checked by the port.
- **AD-21:** the parsed object.
- **AD-15 and AD-53:** named gaps (no vendor event).
- **AD-51 and AD-52:** `STATE`, `SERVICE` and `DEPLOYED` (measured).
- **AD-54:** a name is absent only if no letter case of it exists.
- **AD-59:** `rest` steps.
- **AD-10:** `rest-service` joins the code arm.
- **AD-39:** the build refusal is unlogged.
- **Vendor candidates:** none new.

## Verification

**Shared surfaces:** explorer actions and context `tools`; tool and route rosters; the baseline; covered types; the draft registry; `MgmntPort`'s read-only pins; Fixed strings.

**Standing criterion:** *existing tests that assert a surface this story changes are updated in this story, and every test the story adds or changes passes on a freshly built instance and in either order.*

**Commands:**

- `(loop)` `sh /Users/jbrandt/git/OcuPilot/.worktrees/.coordination/carry-2026-10-08/epic-18-d8/load-ocupilot-ci.sh`. Expect `LOAD-OK` and `STARTPATH-OK`.
- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.<C>`, one class at a time, with totals checked in `%UnitTest_Result`. Run the four new classes; `MgmntPort`, `DraftRegistry`, `DraftNoForm`, `DraftRoute`, `MgmntPortWire` and `DocDbWrite`; and each class Task 16 touches.
- `(loop)` `cd ui && npm run test:tools && npm run test:components`, then `uv run scripts/check-objectscript.py`, then `bash scripts/lint-docs.sh`.
- `(loop)` With `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776` and `OCUPILOT_BROWSER_CONTAINER=ocupilot-ci`, run `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`, then `node --test --test-concurrency=1 browser/rest-services-write.browser-spec.mjs browser/rest-apis.browser-spec.mjs`.
- `(once, before dev_complete)`:
  - The full ObjectScript sweep, one class at a time.
  - `cd ui && npm test && npm run build`. Re-measure the bundle (about 3.21 MB against 3326kB; re-base under DW-1166 if it crosses).
  - `bash scripts/smoke.sh --container ocupilot-ci --user _SYSTEM --password SYS`.
  - Confirm S0.

**Mutations** (Rule 19; record each as `mutation:`):

- C1: POST ignores `Document`.
- C2: `ConfirmProblem` answers `""`; `AgentProblems` skips `.impl`.
- C3: `DocumentProblem` accepts any `swagger`; `SERVICE` skips the deployed check.
- C4: the delete key reads `true`.
- C5: a roster row is removed.

**S0:**

- No `OcuProbe1832*` class, in any case, in USER or HSCUSTOM.
- No `/api/ocuprobe1832*` application.
- `AuthOptionsProbe.Remaining()` is 0.

## Auto Run Result

Status: blocked
Blocking condition: Size. The complete plan above is about 19.5 KB, over the stage's 16 KB bound for one implement pass. Three compression passes could not bring it under without dropping required content. Apart from size, it meets the READY standard. The lead chooses one of two splits:

- **(A), recommended.** Split the story in two.
  - **18.32 keeps:** `MgmntPort`'s writes, both tools with the agent's mint and Confirm rules, the delete row action, the AD-10 arm, the keys, `RestServiceError`, the AD-53 amendment and the roster sweep. The create is agent-only until the second story lands, as Story 20.20's creates are.
  - **A new story (the lead numbers it) takes:** the person's Create dialog. That is `Area/WebApp/RestServiceSave`, `POST /rest-service`, the page, dialog and store with their specs, their Fixed strings, the browser spec, and the `EndpointCoverage` and `SaveHoldCoverage` rows.
  - The C1 screen-create leg moves to the new story.
- **(B)** Accept this spec over the bound and set `status: ready-for-dev`.

The S0 probes ran on `ocupilot-ci` and S0 held.
