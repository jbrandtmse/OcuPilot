---
title: 'Story 18.32: Spec-based REST services'
type: 'feature'
created: '2026-10-10'
status: 'done'
review_loop_iteration: 0
baseline_revision: '057f013c3b112916cb262594a49ce3c5d917625c'
baseline_commit: '057f013c3b112916cb262594a49ce3c5d917625c'
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-18-context.md'
warnings: ['oversized']
deferred:
  - summary: >-
      Vendor candidate (decision-pending, on the owner's hold, not reported): %Api.Mgmnt.v2.impl.DeleteApplication discards the status of
      %REST.API.DeleteApplication and always answers 200 {"msg": ...}.
    evidence: |-
      irissys/%Api/Mgmnt/v2/impl.cls DeleteApplication calls %REST.API.DeleteApplication without reading its status and sets 200 ("Always return success"); measured on ocupilot-ci at the first plan: a delete of an absent service answers 200 too.
      MgmntPort.Service cannot see a failed delete in the answer; the read-back (the SERVICE read finding the service gone) is the only check, as AD-58 intends.
    location: >-
      src/OcuPilot/Port/MgmntPort.cls
    severity: low
---

<intent-contract>

## Intent

**Problem:** The REST API explorer (`RestApiList`, type `rest-service`, port `MgmntPort`) can only read. There is no way to create a spec-based REST service from an OpenAPI document, or to delete one.

**Approach:** Add `webapp.restapis.create` (AD-54) and `webapp.restapis.delete` (AD-51, destructive), the port's first writes. The agent proposes the create; ruling Q2 (B) holds it to Story 20.21's rules at mint and at Confirm. Either caller deletes: a person through a row action that asks for the typed name, the agent through its proposal. The person's Create dialog (the Save route, its page, dialog and store) is Story 18.34's, so until it lands the create is agent-only, as Story 20.20's creates were.

## Boundaries & Constraints

**Always:**

- `Name` is a package with no `%`. It generates `<Name>.spec`, `.disp` and `.impl` in the request's namespace.
- The port passes the vendor a parsed `%DynamicObject` and refuses a string (AD-21: a string makes the vendor fetch a URL or read a server file).
- Pairs (AD-8): the screen's own, `%Development:USE`, and WRITE on the namespace's routines database as an argument pair (`ExplorerSave.CodeWritePairs`). The port re-checks the last two before any vendor call.
- The agent's create, at mint and at Confirm, runs `ExplorerSave.AgentProblem(ns, <class>.cls, 1)` on all three names. The person's create (Story 18.34) will skip it.
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
| Create | The agent proposes `OcuProbe1832A` with a valid 2.0 document in USER; confirmed | Three classes exist, the row is listed, read-back `matches` (`Name`) | Present in any case: refused by absence at mint and at Confirm |
| Rules | `Name` not a package, or holds `%`. `Document` not a JSON object, `swagger` not `"2.0"`, or over 1,000,000 characters. Card over 30,000 characters | Agent: 400 `TOOL.ARGUMENTS`; the port refuses the same rules as 422 `RESTSERVICE.NAME` or `.DOCUMENT` | Nothing sent; a string never reaches the vendor |
| Build failure | A 2.0 document the vendor cannot build | 422 `RESTSERVICE.BUILD` on `Document`, no class left | Vendor 404 not logged |
| Delete | A listed service no web application dispatches to | `.spec` and `.disp` gone, `.impl` kept; read-back absent | Not listed exactly: 404 `PORT.NOTFOUND` |
| Delete refused | A web application dispatches to `<Name>.disp`, or the id starts with `/` | 409 `RESTSERVICE.DEPLOYED` | Nothing sent |

</intent-contract>

## Code Map

Under `src/OcuPilot/` unless `ui/`; siblings per Rule 31.

- `Port/MgmntPort.cls`, endpoint `Service`: `STATE` answers `{Name, Namespace}` if `GetRESTApps` lists the name in any case, else 404 unlogged; `SERVICE` answers 409 `RESTSERVICE.DEPLOYED` as the matrix says (an id starting `/` first), else 404 unless listed exactly, else `{Name, Namespace, Implementation}`; `POST` is `CreateApplication(ns, Name, doc)`, answering `{Name, Namespace}` on 201 or 200 and a vendor 400 or 404 as 422 `RESTSERVICE.BUILD`, unlogged (as 18.6's 400); `DELETE` is `DeleteApplication`. Namespace default `Scope.Current()` (`DocDbPort.cls:240`). `WRITEPAIRS` (`%Development:USE`) and WRITE from `AtelierPort.DatabaseResources` (:699) gate the writes. Rules as `DocDbPort.NameProblem` (:142). `Call`, `Outcome` (:481, :533) take the parsed document. `SnippetForm`, `Snippet` (:588): `rest` for the two writes, one curl step on `/api/mgmnt/v2/<ns>/<Name>` (`AdminPort.Step`, `ShellQuoted`, :3820, :3840).
- `Screen/Tool/RestServiceWrite.cls` (abstract): `ExplorerDocDbWrite`'s shape, not its subclass (another port; WRITE is an argument pair here). `IdArgument` `Name`, `IdParam` `application`, `PortQuery` from the payload's `Namespace`; `PrivilegePairs` adds `%Development:USE` (as `DeviceCreate.cls:159`); `ArgumentPairs` is `ExplorerSave.CodeWritePairs` (:93).
- `RestServiceCreate`: `CREATES`, `STATE`, `POST`, `READBACKFIELDS` `Name`, no `SCREENACTIONS`; schema as `ExplorerCreate.InputSchema` (:76) with `Name` and `Document` (an object); `ArgumentProblem` is the port's rules; `AgentProblems(ns, Name)` runs `ExplorerSave.AgentProblem(ns, <Name>.<part>.cls, 1)` for `spec`, `disp`, `impl`, and `ConfirmProblem` reruns it on the stored `Namespace` (as `ExplorerCreate`, :146); `ComposeCreate` is `{Name, Document, Namespace}` with diff `[args.Hunk]` (:112); consequence `RESTSERVICE.CREATE.COMPILES`.
- `RestServiceCreateMint` extends `Kernel/Proposal/Mint` in `ExplorerCreateMint`'s order (that one reads `AtelierPort`): rules, `IsOcuPilotCode` (`ExplorerSaveMint.Forbidden`, :283), `AgentProblems`, `ExplorerSaveMint.Hunk("", <formatted document>)` (:243) within `CHANGEMAXLENGTH`, `##super`.
- `RestServiceDelete`: `SENDSBODY` 0, `SERVICE`, `DELETE`, `DESTRUCTIVE`, `SCREENACTIONS` `delete`, `PRECONDITIONCODES` `RESTSERVICE.DEPLOYED`, `PRECONDITIONFIELD` `Name`, `READANSWERS` and `FINGERPRINTSUBJECT` `Name,Namespace`; no `AgentProblem` (as 19.2's delete). `StateDiff` (`Name` removed) copies `ExplorerDocDbDelete.StateDiff` (:57), which reads its own `REMOVALROWS`; their shared home, `Write.cls`, is off-limits.

## Tasks & Acceptance

**Task 0** (`ocupilot-ci`, after `LOAD-OK`, `STARTPATH-OK`): record S0; halt on a contradiction with Design Notes.

**Execution:**

1. `MgmntPort` per the Code Map; `Api/RestServiceError.cls` (`DocDbAppError`'s shape; the matrix's codes and `RESTSERVICE.VALIDATION`), dispatched in `Api/Error.cls` beside :1239 and :1450.
2. The four `Screen/Tool/` classes; each `DESCRIPTION` states its rules (the delete's: `.impl` stays).
3. `Screen/Descriptor/RestApiList.cls`: `rowActions` `[{"id":"delete","selfProtection":""}]` (a web application's row refused on click, as `PRESERVEDSESSION`), `emptyNextKey` `""`, `emptyAgentKey` `restApiListEmptyAgent`, doc :19-21; no `primaryAction` until 18.34.
4. `Kernel/Proposal/Prohibited.cls`: `TYPERESTSERVICE` beside :645; `rest-service` in `COVEREDTYPES` (:259) and the guard (:1338); after the document-database arm (:1398), an arm calling `..Code(tId, ...)`, then `Quit`.
5. `Kernel/Governance/Baseline.cls` after :179: create `true`, delete `false`.
6. In `ui/src/app/`: `shell/screen-action-handler.ts` `SCREEN_ACTION_DESCRIPTORS` (:67) and `DESTRUCTIVE_CONSEQUENCES` (:462); `core/proposal-view.ts` the code beside :223 and a `consequenceSentence` line (:406); `node tools/screen-mirror.mjs`.
7. `core/strings.ts`: `restServiceCreateEffect`, `restServiceDeleteConsequence`, `restApiListEmptyAgent`, each `/** EXPERIENCE.md:357 */`; EXPERIENCE.md :357 in place (1044 lines), tagged `[ADDED 2026-10-10 - Story 18.32]`; 3043 of 3400 literals today (measured).

**Tests** (`Write`, `Gate` armed by `OCUPILOT_ALLOW_PRINCIPALS`; `OnAfterOneTest` calls `RestServiceProbe.RemoveAll`):

8. `Test/RestServiceProbe.cls`: `RemoveAll(ns)` (services, `.impl` in any case, `/api/ocuprobe1832*`), `Remaining`, `Document`, `Seed`; delegating to `AuthOptionsProbe.SeedPrincipal` (:127), `MftProbe.Mint` (:231), `DocDbAppProbe.RunAs` (:218).
9. `Test/RestServiceDescriptor.cls`: actions, kinds, pairs (`%Development:USE`; `%DB_USER:WRITE` in USER), schema, keys, coverage, `OcuPilot*` on both tools, `SnippetForm`.
10. `Test/RestServiceWrite.cls`: the matrix rows and C1 to C3, the delete also over the wire (`POST /screens/:screen/action`); `ExplorerCreateRules`' `%SYS` and `Ens.*` cases (:94-95) reused.
11. `Test/RestServiceGate.cls`: exactly the screen's pairs, `%Development:USE`, `%DB_USER:RW` and the code database's READ create and delete in USER; without either added pair each write is refused by name before any port call.
12. `Test/MgmntPort.cls`, `MgmntImplFixture.cls` (stub `CreateApplication`, `DeleteApplication`; doc): the create's 201, 200, 400, 404, 403, 500; a build refusal logs nothing (`LogProbe`).
13. Client: a `RestApiList` Delete leg in `screen-action-handler.spec.ts`; the sentence in `proposal-view`'s spec; `ui/browser/rest-services-write.browser-spec.mjs` deletes a seeded service by typed name after the list's answered signal, `RemoveAll` via `runIris` around it.
14. **Rule 30 sweep**, then run each changed class or file:
    - `ReadTool:93` 336 to 338, names; `SurfaceCoverage` two rows after :422; `ToolRoundTrip` `REFUSEEMPTY` :85, both `TOOL.ARGUMENTS`; `ToolWrite:1338` 29 to 31.
    - `Governance` `RESTAPIDELETE` after :70 and in :155; `ToolDispatch` :173; `GovernanceBaseline` :15, :71; `PortGate` :29 `MgmntPort=PAIRS;WRITEPAIRS`.
    - `Test/Prohibited.cls` :220, :235 `log-entry` for `rest-service`; :232 adds `rest-service`.
    - `DraftRegistry` `TYPEDTARGETIDS` :60 `rest-service=OcuDraftRest` (`STRUCTUREDFIELDS` :37 `Document` if needed); `DraftNoForm` doc :1-3; `scripts/ci-throwaway.sh` after :392 `# classes: RestServiceGate, RestServiceWrite`.
    - Unchanged: `EndpointCoverage`, `SaveHoldCoverage`, `ClassicPageGate`, `MappingDescriptor`, `ProhibitedRoute`, `RefusalCopy`, `Descriptor`, `Wire`, `WireSecurityRead`, `field-lists.test.mjs`.

**Acceptance Criteria:**

- **C1.** Given a valid 2.0 document in USER, when the agent's create of `OcuProbe1832A` is confirmed, then the matrix's Create row holds; when the agent's confirmed delete (key enabled for the test) removes it, then its Delete row holds.
- **C2.** Given an agent create in `%SYS`, of `Ens.OcuProbe1832C` or of `OcuPilotProbe1832`, when it is minted, or confirmed with a stored `%SYS`, then it is refused (`AgentProblem`, or 403 `PROHIBITED.OCUPILOTCODE`) before anything is stored or sent.
- **C3.** Given each matrix refusal, when a caller sends it, then it is refused as the matrix says, and no vendor write is sent but the build failure's `POST`.
- **C4.** Given the baseline, when the agent proposes a delete, then dispatch refuses it by governance; the create's key reads `true`.
- **C5.** Given the rosters, when the suites run, then both tools are pinned, `rest-service` is covered and the Fixed strings stay within the bound.
- **Integration.** Given a seeded service on `ocupilot-ci`, when the explorer's Delete runs with its typed name, then `webapp.restapis.delete` removes it via the screen action route and its row leaves the list (the browser spec).

## Spec Change Log

- 2026-10-11, lead: split A on the orchestrator's ruling (feature `7ce024f9`, Rule 5). The person's Create dialog (`RestServiceSave`, `POST /rest-service`, the page, dialog, store, their specs and Fixed strings, the C1 screen-create leg, the `EndpointCoverage` and `SaveHoldCoverage` rows) moved to Story 18.34. The intent's Approach, the person-create line and the Create and Rules rows were narrowed to match; status reset to `draft` for a re-plan in place.
- 2026-10-11, lead, spec gate: AD-53 amended as "For the lead" proposed, with AD-15's twenty-first case and AD-53's named gap twenty-one (the delete records no vendor event); the `StateDiff` copy is DW-2299, routed to Story 23.7.

## Review Triage Log

### 2026-10-11 - Review pass

- verdicts: 19 findings - high 0, medium 1, low 11, false 7, maybe-false 0
- findings:
  - `[medium]` `[patch]` The card's document text was asserted against `FormattedDocument`, the method under test - the expected value moved with the code. Patched: `RestServiceWrite.TestTheAgentsCreateConfirmsAndTheServiceIsListed` also parses the shown text back to the document sent and requires several lines; the compact-text mutation reddens it (run 164).
  - `[low]` `[patch]` The unresolvable-namespace refusal in `MgmntPort.Service` had no test. Patched: a leg in `MgmntPort.TestAWriteIsRefusedByNameUntilTheCallerHoldsTheAddedPairs`; dropping the guard reddens it (run 161).
  - `[low]` `[reject]` `CLASSPARTS` is pinned to its own literal. The three classes share one database, so no input tells them apart; the roster pin is the best available and the spec says so. Any other pin adds machinery for a loop bound.
  - `[low]` `[patch]` `mutation:` lines missed C1's second half, C2's 403 clause and C3's name rules. Patched: lines added to `## Verification`, each with an observed run.
  - `[false]` `[reject]` The spec records no mutation outcome and its Auto Run Result reads `ready-for-dev`. The outcomes are recorded in `## Verification` with run indexes, and the Auto Run Result is written by this step's Finalize.
  - `[false]` `[reject]` `RestServiceGate`'s header claim that an `ArgumentPairs` answering no pair reddens the confirm leg. Applied on `ocupilot-ci`: `TestWithReadButNotWriteOnTheCodeDatabaseEveryWriteIsRefused` went red at "the confirm is refused naming the pair" (run 160).
  - `[low]` `[patch]` The browser spec's C3 mutation comment said the instance would delete the service. Applied: dropping the leading-slash refusal makes the page draw "lists no REST application" and the sentence assertion goes red. The comment now says so.
  - `[low]` `[patch]` `RestServiceDescriptor`'s header said it needs nothing from the environment while its pair legs read the stock `USER` and `HSCUSTOM` mappings. Header corrected.
  - `[low]` `[patch]` The tool text, schema and mint refusal limited the document's formatted text to 30,000 characters while the check measures the card's row, escaped. Reworded to say "formatted and escaped as the card carries it" in all three places (grouped with the intent audit's wording row).
  - `[low]` `[patch]` Boundary legs were missing: a 215-character name and a 1,000,000-character document. Patched in `MgmntPort.TestTheCreatesRulesAreCheckedBeforeTheVendor`; a `>=` at either limit reddens it (runs 162, 163).
  - `[false]` `[reject]` Intent audit: the person's create route does not exist, so "both callers" is proved at the kernel predicate. Story 18.34 owns that route (Spec Change Log, 2026-10-11); nothing in this diff skips it.
  - `[false]` `[reject]` Intent audit: the matrix's observed outcomes are asserted only by classes that need the armed throwaway. That is the project's two-tier convention; the fixture tier pins the port's calls and the throwaway tier pins the instance.
  - `[low]` `[reject]` Intent audit: the agent's delete is never confirmed as a limited principal. Its declared pairs are pinned in `RestServiceDescriptor` and the port re-checks them; the fix is a fourth principal leg for a path the Gate's create and screen-delete legs already exercise.
  - `[low]` `[reject]` Intent audit (inference): the default delete mint stores no `Namespace`, so the tool-level WRITE pair at Confirm follows the confirming request's scope. The port re-checks WRITE on the payload's namespace before any vendor call, so the worst case is a refusal, never a write; the shape is the sibling delete's.
  - `[false]` `[reject]` Intent audit: a service deployed after the mint answers 409 `TARGETCHANGED` at Confirm, not `RESTSERVICE.DEPLOYED`. The kernel's re-read contract (AD-34) owns that code; `TestAServiceDeployedAfterTheMintIsNotDeleted` pins it.
  - `[low]` `[reject]` Intent audit: no test races two spellings of one name under AD-34's hold. The state read and the Confirm re-read are case-blind, which the sequential test pins; a race needs two in-flight confirms the kernel serialises by key.
  - `[low]` `[patch]` Intent audit: wording versus measurement of the card limit. Same root cause as the 30,000-character row above.
  - `[false]` `[reject]` Intent audit: a vendor 400 is unlogged as well as the 404. The Code Map says "a vendor 400 or 404 ... unlogged (as 18.6's 400)".
  - `[false]` `[reject]` Intent audit: additions beyond the contract (empty-state invitation, three strings, the EXPERIENCE.md cell, the `rest` script form, roster and count edits, the `log-entry` swap). Each is a named task or Code Map line; the `ci-timings.json` entry is required by `ci.test.mjs` AC9, which fails without it (checked).

## Design Notes

**Measured at the first plan** (2026-10-10, `ocupilot-ci`): create 201, then 200; `ocuprobe1832a` over `OcuProbe1832A` 404 (#5092: presence is case-blind, so no id rule); an undeclared path parameter 404 (#8711), no class left; delete 200 keeping `.impl`, 200 when absent; a deployed service went 404 once deleted; `AgentProblem` refused `%SYS` and named ENSLIB for `Ens.*`; `IsOcuPilotCode` caught `ocupilotx.spec.cls`. 18.34's seeds: `git show bb49cd147447d4dbade1191a14f16c3c0cb1d490:<this spec>`.

**Governing ADs:** AD-2, 6, 8, 10, 13, 14, 15, 21, 22, 29, 34, 39, 51, 52, 53, 54, 58, 59. **Consumed-by:** 18.34 (the person's create over `Service` `POST`), 18.12. **Consumes:** 6.1, 16.1 (`MgmntPort`); 20.20, 20.21 (`AgentProblem`, `CodeWritePairs`, `Hunk`, `Forbidden`).

**For the lead** (Rule 20):

- **AD-53 (ruling Q2 (B)).** Add the paragraph below (and the Code Map's rows for AD-8, 10, 15, 21, 39, 51, 52, 54 and 59), and "and the REST service create (Story 18.32)" after "the agent authoring code only through these saves" and in the `EXPLORER.SQL.AGENTCODE` clause.

  > "**The spec-based REST service create is the agent's second code path** [AMENDED 2026-10-10, Story 18.32 spec gate, ruling Q2 (B), Rule 20]: `webapp.restapis.create` compiles `<package>.spec`, `.disp` and `.impl` from an OpenAPI 2.0 document the agent sends whole, through `MgmntPort`, held to Story 20.21's rules at the mint and at Confirm (only the namespace's own routines database, never `%SYS` or a `%` name; an `OcuPilot*` package refused `PROHIBITED.OCUPILOTCODE` from either caller). The card shows the whole document, at most 30,000 characters; an existing `.impl` keeps its code (measured). The create's key ships enabled; `webapp.restapis.delete`, destructive, ships `false` and refuses a deployed service."

- **Rule 11.** Pre-authorize these non-add-only edits in the implement prompt: `Test/Prohibited.cls` :220, :235 (one token each; Epic 20 edits only :232) and `Kernel/Proposal/Prohibited.cls` :1338 (a clause, as in 18.30 and 18.31).
- **Vendor candidate** (inference): `DeleteApplication` ignores its own status and always answers 200; the read-back catches a failed delete.

## Verification

**Shared surfaces:** the explorer's row actions, empty state and context `tools`; `MgmntPort`'s read-only pins; Fixed strings; every roster Task 14 names. No new entity type or prohibited code: the count (66) and code pins hold.

**Standing criterion:** every test added or changed passes on a fresh environment, in either order.

**Commands** (each inside one 10-minute foreground call):

- `(loop)` `sh /Users/jbrandt/git/OcuPilot/.worktrees/.coordination/carry-2026-10-08/epic-18-d8/load-ocupilot-ci.sh` -- expected `LOAD-OK`, `STARTPATH-OK`.
- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.<C>`, one at a time, totals checked in `%UnitTest_Result`: the four new classes; `MgmntPort`, `MgmntPortWire`, `DraftRegistry`, `DraftRoute`; each class Task 14 changed.
- `(loop)` `cd ui && npm run test:tools && npm run test:components`; `uv run scripts/check-objectscript.py`; `bash scripts/lint-docs.sh`.
- `(loop)` With `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776`, `OCUPILOT_BROWSER_CONTAINER=ocupilot-ci`: `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`, then `node --test --test-concurrency=1 browser/rest-services-write.browser-spec.mjs browser/rest-apis.browser-spec.mjs`. Re-measure the bundle (3,213,418 bytes at 18.30; warning 3326kB; DW-1166 if crossed).
- Full sweeps: the runner's (ObjectScript), CI's (browser). End at S0.

**Mutations** (Rule 19), applied on `ocupilot-ci` with the mutated class and its descendants recompiled:

- mutation: C1 `MgmntPort.Build` hands the vendor `{}` for the document → `RestServiceWrite.TestTheAgentsCreateConfirmsAndTheServiceIsListed` red.
- mutation: C1 `RestServiceCreateMint.FormattedDocument` answers the compact text → `RestServiceWrite.TestTheAgentsCreateConfirmsAndTheServiceIsListed` red (run 164); `MgmntPort.Service` skips the vendor delete → `RestServiceWrite.TestTheScreensDeleteRemovesTheServiceOverTheWire` red; the `.impl` class deleted after the vendor delete → `RestServiceWrite.TestAnExistingImplementationKeepsItsCode` red.
- mutation: C2 `RestServiceCreate.ConfirmProblem` answers `""` → `RestServiceWrite.TestTheCodeRulesAndOcuPilotsOwnCodeAreRefusedOnBothTools` red (run 165); the `rest-service` arm of `Prohibited.Prohibits` removed → that test and five more in `RestServiceWrite` red (run 166); `CLASSPARTS` drops `impl` → `RestServiceDescriptor.TestTheCreatesRulesAreThePortsAndTheCodeSaves` red.
- mutation: C3 `MgmntPort.DocumentProblem` accepts any `swagger` → `MgmntPort.TestTheCreatesRulesAreCheckedBeforeTheVendor` red; `NameProblem` or `DocumentProblem` refuses at the limit itself (`>=`) → the same test red (runs 162, 163); the unresolved-pairs refusal in `MgmntPort.Service` dropped → `MgmntPort.TestAWriteIsRefusedByNameUntilTheCallerHoldsTheAddedPairs` red (run 161); `MgmntPort.Resolved` drops the deployed check → `RestServiceWrite.TestADeployedServiceAndAWebApplicationPathAreRefused` and `MgmntPort.TestTheServiceReadsAreExactAndRefuseADeployedService` red.
- mutation: C4 the delete key `true` in `Baseline` → `RestServiceWrite.TestTheAgentsDeleteIsGovernedThenConfirmedAndKeepsTheImplementation` and `GovernanceBaseline.TestThePurgeIsTheOneDisabledLine` red (run 167).
- mutation: the pair at Confirm, `RestServiceWrite.ArgumentPairs` answers no pair → `RestServiceGate.TestWithReadButNotWriteOnTheCodeDatabaseEveryWriteIsRefused` red (run 160); `Resolved` without its leading-slash refusal → `rest-services-write.browser-spec.mjs` C3 red.
- mutation: C5 `webapp.restapis.create` removed from `ReadTool`'s names → `ReadTool.TestTheRegistryListsDescriptorReadsAndInheritedKinds` red (run 168); the create's `SurfaceCoverage` row removed → `SurfaceCoverage.TestEveryWriteToolHasACoverageRowAndBack` red (run 169).
- mutation: Integration `DESTRUCTIVE_CONSEQUENCES` drops `RestApiList` → `screen-action-handler.spec.ts` "registers Delete" and the browser spec's Integration test red.

**S0:** no `OcuProbe1832*` class in any case in USER or HSCUSTOM; no `/api/ocuprobe1832*` application; `AuthOptionsProbe.Remaining()` 0.

## Auto Run Result

Status: done
Blocking condition: none

**Change.** `MgmntPort` gains the `Service` endpoint (state and service reads; create and delete behind `%Development:USE` and WRITE on the namespace's routines database, a parsed document only, 422 `RESTSERVICE.BUILD` unlogged, 409 `RESTSERVICE.DEPLOYED`, a `rest` script form). `webapp.restapis.create` (key `true`) and `.delete` (destructive, key `false`) ship as `RestServiceWrite`, `RestServiceCreate`, `RestServiceCreateMint` and `RestServiceDelete`; the create is held to `ExplorerSave.AgentProblem` on all three classes and to `PROHIBITED.OCUPILOTCODE` at mint and Confirm. The explorer gains a Delete row action and an agent invitation; the client registers the Delete, the compile sentence and three Fixed strings.

**Files.** Product: `Port/MgmntPort.cls`, `Api/RestServiceError.cls` (+ `Api/Error.cls`), four `Screen/Tool/RestService*.cls`, `Screen/Descriptor/RestApiList.cls`, `Kernel/Proposal/Prohibited.cls` (type, covered-types entry, guard clause, arm), `Kernel/Governance/Baseline.cls`. Client: `screen-action-handler.ts`, `proposal-view.ts`, `strings.ts`, `screens.generated.ts` (regenerated), `EXPERIENCE.md:357`. Tests: `RestServiceProbe`, `RestServiceDescriptor`, `RestServiceWrite`, `RestServiceGate`, legs in `MgmntPort` and `MgmntImplFixture`, `rest-services-write.browser-spec.mjs`, the specs for the handler and the proposal view, and the Task 14 rosters. `ui/tools/ci-timings.json` gains one estimate because `ci.test.mjs` AC9 fails without it.

**Review.** One pass, 19 findings: 1 medium and 6 low patched, 4 low rejected with a reason, 7 false. Deferred: the vendor `DeleteApplication` candidate, decision-pending. Follow-up review: `false` (one medium patched, no high).

**Verification** on `ocupilot-ci` (source loaded, S0 read after): `RestServiceDescriptor` 8 (run 170), `RestServiceWrite` 11 (run 159), `RestServiceGate` 3 (run 156), `MgmntPort` 17 (run 158), all green; the Task 14 sweep classes were green at the implement pass and the runner runs the full sweep. Mutations: runs 160 to 169, recorded in `## Verification`. Client: `test:tools` 1907 of 1907, `test:components` 2848 of 2848, `rest-services-write` 2 of 2 and `rest-apis` 4 of 4 against the rebuilt bundle (3,267,522 bytes against the 3326 kB warning); Fixed strings 3068 of 3400; `check-objectscript` and `lint-docs` clean.

**Residual risks.** `ci-timings.json` carries a placeholder 12.5 s for the new spec until the lead's refresh. `Prohibited.cls`'s covered-types line and the `ReadTool` and `ToolWrite` count lines are also edited by Epic 20, so a textual merge conflict resolves by union.
