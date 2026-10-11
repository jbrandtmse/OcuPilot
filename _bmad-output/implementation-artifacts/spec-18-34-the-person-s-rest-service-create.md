---
title: 'Story 18.34: The person''s REST service create'
type: 'feature'
created: '2026-10-11'
status: 'done'
baseline_revision: '24dba4ad46979d0bfbe1931f82e6301624bf4aa3'
baseline_commit: '24dba4ad46979d0bfbe1931f82e6301624bf4aa3'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-18-context.md'
warnings: ['oversized']
deferred:
  - summary: >-
      A create answered after the dialog was dismissed publishes no change event, so a service built in that window leaves the list stale until it is next read.
    evidence: |-
      RestServiceCreateStore.create drops a result whose generation moved (reset() runs when the dialog is destroyed); Escape, Cancel and the scrim dismiss the dialog while the post is pending. The Document databases store (docdb-create.store.ts) has the same pattern, so the fix belongs to both, under DW-2278's unification.
    location: >-
      ui/src/app/areas/web-applications/rest-service-create.store.ts:139
    severity: low
---

<intent-contract>

## Intent

**Problem:** The REST API explorer's create is agent-only (Story 18.32): a person cannot build a spec-based REST service from an OpenAPI document on the screen.

**Approach:** Add the explorer's Create dialog and its Save, `POST /rest-service` (`Area/WebApp/RestServiceSave`), resolved through 18.32's `webapp.restapis.create` and `MgmntPort`'s `Service` endpoint (AD-55), under the per-target hold (AD-34). "The same rules the agent's create meets" (epics.md) means **the port's rules; `AgentProblem` stays agent-only, per AD-53** (orchestrator ruling, 2026-10-11): a person's Save is unchanged, so a person may build where the agent may not, such as `%SYS`.

## Boundaries & Constraints

**Always:**

- The Save runs, in order: the screen's pairs and the tool's (`%Development:USE`, WRITE on the request namespace's routines database), refused by name before anything is read; a body naming only `Name` and `Document`; the hold; the text parsed on the instance into an object; the port's name and document rules; the taken-name check (`STATE`: listed in any case, or an unlisted `.spec` or `.disp` class held); AD-10; the port's `POST`; the read-back (AD-58).
- The port and the vendor get only the parsed object, never the text (AD-21). The write runs in the request's namespace (`Scope.Current()`), stored as the payload's `Namespace`.
- Every sentence is the server's (AD-39); the one new code lives in `Api/RestServiceError.cls`.
- Probes run on `ocupilot-ci` only, through `RestServiceProbe` (names `OcuProbe1832...`), one test class per call.

**Never:**

- Run `RestServiceCreate.AgentProblems` (`ExplorerSave.AgentProblem`) or the agent card's 30,000-character width on the person's Save; its bound is the port's 1,000,000.
- Ask governance (AD-22), mint a proposal, or add a write key, entity type, id rule or prohibited code.
- Take a namespace, a URL or a server path from the body.
- Edit `Screen/Tool/Write.cls`, `Api/ScreenAction.cls`, `Kernel/Agent/Dispatch.cls`, `Screen/Read.cls`, `Kernel/Proposal/Prohibited.cls`, `Kernel/Governance/Baseline.cls` or `Port/MgmntPort.cls`.
- Build on a `decision-pending` entry.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Create | `POST /rest-service?ns=USER` `{Name: "OcuProbe1832P", Document: <2.0 text>}` | 201 `{name, readBack}`, verdict `matches`; three classes; listed | No error expected |
| Rules | Name not a package, holding `%`, or over 215; Document not a string, not JSON, not an object (a quoted URL), `swagger` not `"2.0"`, or over 1,000,000 | 422 `RESTSERVICE.NAME` on `Name`, or `.DOCUMENT` on `Document` | Nothing sent |
| Body | Not a JSON object; a key besides `Name` and `Document` (such as `Namespace`) | 400 `AGENT.BADBODY`; 400 `PORT.FIELD.UNEXPECTED` | Nothing read or sent |
| Taken | Listed in another case (`OcuProbe1832T`), or a `.disp` class held unlisted (`OcuProbe1832Q`, `RestServiceProbe.SeedClass`) | 422 `RESTSERVICE.TAKEN` on `Name` | Nothing sent |
| Build failure | `RestServiceProbe.Unbuildable()` | 422 `RESTSERVICE.BUILD` on `Document`, no class left | The port's |
| Own code | `OcuPilotProbe1834` with the unbuildable document | 403 `PROHIBITED.OCUPILOTCODE` | Nothing sent |
| Agent-only rule | `OcuProbe1832Sys` in `%SYS` | Person 201; agent refused at the mint by `AgentProblem` | — |
| Pairs | Without `%Development:USE`, or READ without WRITE on the routines database | 403 naming the pair | Before the taken read |
| Busy | Target held by another write | 409 `WRITE.TARGETBUSY` | Nothing sent |

</intent-contract>

## Code Map

Under `src/OcuPilot/` unless `ui/`; siblings per Rule 31.

- `Area/WebApp/RestServiceSave.cls` (new): copies `Area/Explorer/DocDbSave.cls` (:44-205, seams `PortClass` and `ProhibitedClass` included), because a slice never depends on another (one base is DW-2278's, Story 23.7). `Gate` unions `ArgumentPairs({})` as `Area/OsMgmt/DatabaseSave.Gate` (:420). Rules `MgmntPort.NameProblem` and `DocumentProblem` (:387, :398) on `{Name, Document: <parsed>}`; taken is `Service` `STATE` answering 200 (as `DocDbAppRules.Taken`, :180); payload `RestServiceCreate.ComposeCreate` (:141) from `{Name, Document, Namespace}`; query `Operation.Query` (:258); write `Service` `POST`; `ReadBack.ForSave` (:185); hold `Operation.HoldTool` (:77) on `Name`.
- `Api/RestServiceError.cls`: `TAKEN` (`RESTSERVICE.TAKEN`, field `Name`, "This namespace already has a REST service of that name, or its specification or dispatch class, in some letter case.") in `Codes`, `ViolationCodes`, `FieldOf`, `ReasonFor`. `Api/Error.cls` dispatches by prefix (:1240, :1452), unchanged.
- `Api/Router.cls`: `<Route Url="/rest-service" Method="POST" Call="RestServiceCreate"/>` after :264, and the thin wrapper at the class end, as `ExplorerDocDbCreate` (:1858).
- `Screen/Descriptor/RestApiList.cls`: `primaryAction` `{"id": "create", "selfProtection": ""}` (as `ExplorerDocDbList.cls:37`); doc :19-24. `Screen.Context.ScreenTools` (:209) then lists `webapp.restapis.create` in the explorer's context `tools`.
- `Screen/Tool/RestServiceCreate.cls` doc :1-4: the person's caller is `RestServiceSave`.
- Client, `ui/src/app/areas/web-applications/`, copies of System Explorer's Document databases files (another area slice; DW-2278): `rest-api-list.page.ts` (`docdb-list.page.ts` without the service strip), `rest-service-create-dialog.ts` (`docdb-create-dialog.ts` plus a Document textarea and Load from file as `license-key.page.ts` :185-198 and :425-442, `accept=".json"`, global classes `ocu-field-textarea ocu-x509-pem` and `ocu-x509-file`; Create `aria-disabled` while either field is blank or a create is in flight), `rest-service-create.store.ts` (`docdb-create.store.ts`: `POST /api/ocupilot/rest-service`, `{Name, Document}` as typed, `scope: namespace`, violations on `Name` and `Document`, change event `rest-service` `created`).
- `ui/src/app/shell/screen-outlet.ts` `DESCRIPTOR_PAGES` (:271): `RestApiList` to `RestApiListPage`.

## Tasks & Acceptance

**Task 0** (`ocupilot-ci`, after `LOAD-OK` and `STARTPATH-OK`): record S0; confirm `RestServiceProbe.Seed("%SYS","OcuProbe1832Sys")` builds a service `%SYS` lists with three classes; `RemoveAll("%SYS")` then leaves none. A contradiction halts.

**Execution:**

1. `Api/RestServiceError.cls` `TAKEN`; `Area/WebApp/RestServiceSave.cls` per the Code Map.
2. `Api/Router.cls` route and wrapper; `RestApiList.cls` primary action and doc; `RestServiceCreate.cls` doc.
3. Client: the three files; `screen-outlet.ts`; `cd ui && node tools/screen-mirror.mjs`.
4. `ui/src/app/core/strings.ts`, each cited `/** EXPERIENCE.md:357 */`: `restServiceCreateTitle` "Create REST service", `restServiceNameHint` "The package, such as My.Api: it creates My.Api.spec, My.Api.disp and My.Api.impl.", `restServiceDocumentLabel` "OpenAPI 2.0 document", `restServiceDocumentHint` "The whole document as JSON, pasted or loaded from a file. Nothing is fetched." Reuse `tableColumnName` and `x509LoadFromFile`. EXPERIENCE.md :357 in place (1044 lines), tagged `[ADDED 2026-10-11 - Story 18.34]`; 3068 to 3072 of 3400.

**Tests:**

5. `src/OcuPilot/Test/RestServiceSave.cls` (new; armed by `OCUPILOT_ALLOW_PRINCIPALS`; `RestServiceProbe.RemoveAll` in `USER` and `%SYS` before and after each test, then `Remaining` 0 in both): C1, C2 and C3 over `POST /rest-service` (`Test.Http.MakeRequest`), each refusal leg asserting `RestServiceProbe.Facts` unchanged; C2's agent half through `RestServiceProbe.Mint` under `Scope.Set("%SYS")`.
6. `src/OcuPilot/Test/RestServiceGate.cls`: `TestTheDeclaredPairsCreateAndDelete` adds the holder's `POST /rest-service` of `OcuProbe1832M`, answering `201 ` with three classes; `AssertRefused` adds `POST /rest-service` naming the seeded `OcuProbe1832B`, answering `403 <pair>`.
7. In `ui/src/app/areas/web-applications/`: `rest-api-list.page.spec.ts`, `rest-service-create-dialog.spec.ts`, `rest-service-create.store.spec.ts`, as the three Document databases specs.
8. `ui/browser/rest-services-write.browser-spec.mjs`, two tests, each waiting for the list's answered signal: Integration (the command bar's Create opens the dialog; a name and a 2.0 text create `OcuProbe1832Dialog`; one `POST /api/ocupilot/rest-service` carries `{Name, Document}`; the row appears; the instance lists it with three classes), and a `{"swagger": "3.0"}` text refused on the Document field with the instance's `#REASONDOCUMENT`, nothing built.
9. **Rule 30 sweep**, then run each changed class or file:
   - `Test/EndpointCoverage.cls` (the router's route roster, derived from the `UrlMap`) after :276: `<probe class="Api.Router" method="POST" url="/rest-service" path="/api/ocupilot/rest-service" disposition="envelope" refusal="1"/>`.
   - `Test/SaveHoldCoverage.cls` `TestACreateSaveHoldsTheKeyItsMintComputes`: under `Scope.Set("USER")`, `HeldLeg("/rest-service?ns=USER", "OcuPilot.Screen.Tool.RestServiceCreate", "OcuProbe1832Hold", {"Name": "OcuProbe1832Hold", "Document": "not json"}.%ToJSON())`, with its mutation sentence; the derived `TestEveryWriteRouteTakesTheHoldOrIsExempt` needs no edit.
   - `Test/RestServiceDescriptor.cls` :35-47: the explorer's primary action is `create`.
   - `scripts/ci-throwaway.sh` after :398: `# classes: RestServiceSave` (add-only; `ui/tools/ci.test.mjs` holds it).
   - Grep `src/OcuPilot/Test`, `ui/tools`, `ui/src` and `ui/browser` for `RestApiList`, `restapis` and `rest-apis`, and update any assertion of no primary action or of the explorer's context `tools`.
   - Checked unchanged: `ProhibitedRoute` (web applications only), `RefusalCopy` (no prohibited code), `Wire` and `WireSecurityRead` (no screen added), `PortGate` (no port change), `field-lists.test.mjs` (no tool added), entity types (67).

**Acceptance Criteria:**

- **C1.** Given a valid 2.0 document text, when a person's Save creates `OcuProbe1832P` in USER, then the matrix's Create row holds; when the explorer's Delete then removes it, then `.spec` and `.disp` are gone and `.impl` stays.
- **C2.** Given `OcuProbe1832Sys` and `%SYS`, when the agent's create is minted there, then it is refused with `AgentProblem`'s sentence and nothing is stored; when a person's Save creates it there, then it answers 201 and `%SYS` holds and lists it.
- **C3.** Given each refusal in the matrix's Rules, Body, Taken, Build failure and Own code rows, when a person sends it, then it is refused as the matrix says, and no vendor write is sent but the build failure's `POST`.
- **C4.** Given a principal without `%Development:USE`, or with READ but not WRITE on USER's routines database, when it saves, then it is refused 403 naming the pair before the taken read; a holder of every pair creates.
- **C5.** Given the target held, when the Save runs, then it answers 409 `WRITE.TARGETBUSY` and writes nothing.
- **Integration.** Given `ocupilot-ci`, when a person uses the explorer's Create, then `RestApiListPage` posts `POST /rest-service` and the new service's row appears.

## Spec Change Log

## Review Triage Log

### 2026-10-11 -- Review pass

- verdicts: 12 findings -- high 0, medium 2, low 9, false 1, maybe-false 0
- findings:
  - `[medium]` `[patch]` In-flight guard on Create (`confirmDisabled`, store) pinned by no spec -- added `Create is unavailable while a create is in flight` to `rest-service-create-dialog.spec.ts` (a held answer, two clicks, one post) with its mutation line.
  - `[low]` `[reject]` A non-404 failure of the taken-name read is not pinned -- the code returns the port's refusal and sends no `POST` (fail-closed); no Save in this family has a seam test and one needs a fake port class.
  - `[low]` `[reject]` `handler.pending()` guard on the page is not pinned -- copies `docdb-list.page.ts`; the command bar sits behind the Delete scrim.
  - `[low]` `[reject]` Legs without their own mutation line (C2 agent half and wide document, C3 BADBODY and build failure, C4 holder, client refusal tests) -- Rule 19 asks one mutation per AC, and each AC has one recorded.
  - `[low]` `[patch]` Browser test 1 named a mutation (no Document from the store) never observed -- the clause is removed; the swagger 3.0 test's template mutation was observed red and recorded.
  - `[medium]` `[patch]` `actionLabel(...)` assertion in `rest-api-list.page.spec.ts` falls back to the shared `create` label whether or not the page registers Create -- deleted with its two unused imports; the `actions.has` assertion stays load-bearing.
  - `[low]` `[defer]` A create answered after the dialog is dismissed publishes no change event -- same pattern as the Document databases store; entered in `deferred:`.
  - `[low]` `[reject]` `## Auto Run Result` read `ready-for-dev` during review -- rewritten at Finalize in this pass.
  - `[false]` `[reject]` Create is declared with no pair gate on the descriptor -- by design: the Save refuses naming the pair (C4), as the explorer's Delete does.
  - `[low]` `[reject]` Real `Name`, 403, 409 and `PROHIBITED.OCUPILOTCODE` sentences are not drawn from a live response in the browser -- Task 8 names two browser tests; the server tests pin each response and the unit specs pin the drawing.
  - `[low]` `[reject]` The `%SYS` routines-database pair is not exercised for a non-superuser -- C4 is stated for USER's routines database; C2 builds in `%SYS` as the privileged account.
  - `[low]` `[reject]` "Nothing read or sent" is checked as unchanged probe state, not by observing reads -- the taken read changes nothing; the vendor-write half is what the state check pins.

## Design Notes

**Governing ADs:** AD-5, 8, 10, 12, 13, 14, 19, 20, 21, 22, 29, 34, 39, 44, 52, 53, 54, 55, 58. **Consumes:** 18.32 (`MgmntPort` `Service`, `webapp.restapis.create`, `RestServiceError`, `RestServiceProbe`), 19.17 (page, dialog, store), 18.6 (Load from file), 23.4 (`Operation.HoldTool`). **Consumed-by:** this story's page alone (Integration). **Ledger inbox:** empty.

**Text parsed on the instance:** browser parsing would re-serialize numbers past double precision and need a client sentence. A JSON string, a quoted URL included, never parses to an object, so the port's AD-21 rule holds.

**Why `%SYS` pins C2:** the port refuses a `%` name from both callers (`NAMEPATTERN`), and a package another database holds needs a mapping of the test's own or a read-only library (inference), so `%SYS` is the target the test builds and removes (`RemoveAll("%SYS")`).

**For the lead** (Rule 20):

- AD-53: replace "The person's create is Story 18.34's." with "The person's create (Story 18.34, `POST /rest-service`) meets the port's rules -- the name and document rules, a parsed document only, the taken-name check including an unlisted `.spec` or `.disp` class, and AD-10's `OcuPilot*` refusal -- with `%Development:USE` and WRITE on the namespace's routines database, under AD-34's hold; it never runs the agent's routines-database check, and the card's 30,000-character width is the agent's alone." Add named gap twenty-two: REST services' Create (Story 18.34), for the same reason as AD-15's twenty-first.
- DW-2278: append `occurrence=18-34-the-person-s-rest-service-create` (the Save and the three client files copy the Document databases slice).
- Rule 11: edits outside new files are add-only (Router, EndpointCoverage, SaveHoldCoverage, `ci-throwaway.sh`, `screen-outlet.ts`, `strings.ts`) or in this epic's own files.

## Verification

**Shared surfaces:** the explorer's primary action and context `tools`; the route map (`EndpointCoverage`, `SaveHoldCoverage`); `RestServiceError`'s code lists; `screens.generated.ts`; Fixed strings; `ci-throwaway.sh`'s arming roster.

**Standing criterion:** every test added or changed passes on a fresh environment, in either order.

**Commands** (each inside one 10-minute foreground call):

- `(loop)` `sh /Users/jbrandt/git/OcuPilot/.worktrees/.coordination/carry-2026-10-08/epic-18-d8/load-ocupilot-ci.sh` -- expected `LOAD-OK`, `STARTPATH-OK`.
- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.<C>`, one at a time, totals checked in `%UnitTest_Result`: `RestServiceSave`, `RestServiceGate`, `RestServiceDescriptor`, `EndpointCoverage`, `SaveHoldCoverage`, and each class the sweep changes.
- `(loop)` `cd ui && npm run test:tools && npm run test:components`; `uv run scripts/check-objectscript.py`; `bash scripts/lint-docs.sh`.
- `(loop)` With `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776` and `OCUPILOT_BROWSER_CONTAINER=ocupilot-ci`: `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`, then `node --test --test-concurrency=1 browser/rest-services-write.browser-spec.mjs browser/rest-apis.browser-spec.mjs`. Re-measure the bundle (3,267,522 bytes after 18.32; warning 3326kB; re-base under DW-1166 if crossed; stop and ask above 3800kB).
- Full sweeps: the runner's (ObjectScript) and CI's (browser).

**Mutations** (Rule 19; record each `mutation:` line when observed, after recompiling descendants or redeploying the bundle):

- C1: `RestServiceSave` hands the port `{}` as the document -> `RestServiceSave`'s C1 test red.
- C2: `RestServiceSave` refuses with `RestServiceCreate.AgentProblems` -> C2's person leg red.
- C3: drop the unexpected-key refusal -> the `Namespace` key leg builds and goes red; the taken check answers free -> the held-class leg builds and goes red; drop the `Prohibited` call -> the `OcuPilotProbe1834` leg answers 422 `RESTSERVICE.BUILD`, leaves nothing, and goes red.
- C4: drop `ArgumentPairs` from `RestServiceSave.Gate` -> `RestServiceGate`'s READ-only Save leg answers 422 `RESTSERVICE.TAKEN` and goes red.
- C5: drop the hold from `RestServiceSave.HandleCreate` -> `SaveHoldCoverage`'s derived test and the `/rest-service` held leg red.
- Integration: the page registers no Create -> the browser spec's dialog test red.

Observed on `ocupilot-ci` (each reverted, tree byte-identical, reloaded):

- mutation: C1, `RestServiceSave.Create` hands the port `{}` as the document -> `RestServiceSave` `TestTheSaveBuildsTheServiceAndTheExplorersDeleteRemovesIt` red (run 595).
- mutation: C2, `Create` refuses with `RestServiceCreate.AgentProblems` -> `TestThePersonBuildsWhereTheAgentIsRefused` red on the `%SYS` person leg (run 596).
- mutation: C3, drop the unexpected-key refusal from `HandleCreate` -> `TestABodyThatIsNotNameAndDocumentAloneIsRefused` red, the `Namespace` leg builds (run 597); the taken check answers free -> `TestATakenNameIsRefusedInAnyLetterCase` red, the held `.disp` and `.spec` legs build (run 598); drop the `Prohibited` call -> `TestABuildFailureLeavesNothingAndOcuPilotsOwnCodeIsNeverSent` red, both own-code legs answer 422 `RESTSERVICE.BUILD` and no `OcuPilotProbe1834` class exists in USER, HSCUSTOM or `%SYS` afterwards (run 599); drop the document rule -> `TestTheRulesAreTheMgmntPortsAndNothingIsBuilt` red on the taken-name order leg (run 600); drop the name rule -> the same test red on the package legs (run 601).
- mutation: C4, drop `ArgumentPairs` from `RestServiceSave.Gate` -> `RestServiceGate` `TestWithReadButNotWriteOnTheCodeDatabaseEveryWriteIsRefused` red on the Save leg (run 602).
- mutation: C5, drop the hold from `HandleCreate` -> `SaveHoldCoverage` `TestACreateSaveHoldsTheKeyItsMintComputes` and `TestEveryWriteRouteTakesTheHoldOrIsExempt` red (run 603).
- mutation: shared surfaces, remove the `/rest-service` probe row -> `EndpointCoverage` red (run 604); `RestApiList` primary action `""` -> `RestServiceDescriptor` `TestTheExplorerDeclaresItsDeleteAndItsInvitation` red (run 605); empty `REASONTAKEN` -> `TestTheCodesAnswerTheirSentences` red (run 606).
- mutation: client, `RestApiListPage` registers no Create -> `rest-api-list.page.spec.ts` red; the store drops `scope: namespace` -> `rest-service-create.store.spec.ts` red; the dialog drops the document check from `confirmDisabled` -> `rest-service-create-dialog.spec.ts` red.
- mutation: client in-flight, drop `this.store.busy() ||` from `RestServiceCreateDialog.confirmDisabled` -> `rest-service-create-dialog.spec.ts` "Create is unavailable while a create is in flight" red (`aria-disabled` reads null).
- mutation: browser refusal, drop the document violation paragraph from the dialog template, bundle rebuilt and redeployed -> `rest-services-write.browser-spec.mjs` swagger 3.0 test red (the sentence never draws; 90 s wait); reverted, rebuilt and redeployed -> green.
- mutation: Integration, `RestApiListPage` registers no Create, bundle rebuilt and redeployed -> `rest-services-write.browser-spec.mjs` Create and Document-refusal tests red (the command bar draws no Create); reverted, rebuilt and redeployed -> green.

**S0:** no `OcuProbe1832*` class in any case in USER, HSCUSTOM or `%SYS`; no `/api/ocuprobe1832*` application; `AuthOptionsProbe.Remaining()` 0.

## Auto Run Result

Status: done
Blocking condition: none

**Change:** the REST API explorer's Create. `POST /rest-service` (`Area/WebApp/RestServiceSave`) parses the pasted OpenAPI 2.0 text on the instance and builds the three classes in the request's namespace through the agent's tool class and `MgmntPort`, under the per-target hold; it meets the port's rules and never `AgentProblems`, so a person builds in `%SYS`. The explorer declares Create as its primary action and its page opens a dialog (package, document, Load from file).

**Files:**

- Server: `Area/WebApp/RestServiceSave.cls` (new), `Api/RestServiceError.cls` (`TAKEN`), `Api/Router.cls` (route, wrapper), `Screen/Descriptor/RestApiList.cls` (primary action), `Screen/Tool/RestServiceCreate.cls` (doc).
- Tests: `Test/RestServiceSave.cls` (new, 6), `Test/RestServiceGate.cls`, `Test/RestServiceDescriptor.cls`, `Test/EndpointCoverage.cls`, `Test/SaveHoldCoverage.cls`, `scripts/ci-throwaway.sh` (arming roster).
- Client: `rest-api-list.page.ts`, `rest-service-create-dialog.ts`, `rest-service-create.store.ts` and their three specs, `screen-outlet.ts`, `strings.ts` (4 keys), `screens.generated.ts` (regenerated), `browser/rest-services-write.browser-spec.mjs` (2 tests), `EXPERIENCE.md` :357.

**Review:** 12 findings, no high. Patched: two medium (an in-flight Create test with its mutation, an unfalsifiable label assertion deleted) and one low (an unobserved mutation clause removed). Deferred: one low (a create answered after the dialog is dismissed publishes no change event; the Document databases store shares it). Rejected: eight, with their reasons in the triage log. Follow-up review: `false`; no risk the patches leave unverified (patched counts: medium 2, low 1, all test-side).

**Verified on `ocupilot-ci`** after a fresh `src` load: `RestServiceSave` 6 (run 616), `RestServiceGate` 3 (617), `RestServiceDescriptor` 8 (618), `EndpointCoverage` 2 (619), `SaveHoldCoverage` 2 (620), `ToolEmit` 11 (621), `Descriptor` 60 (622), `SurfaceCoverage` 4 (623), `ClassicPageGate` 8 (624), all green. `check-objectscript` 0 problems, `lint-docs` 0 issues, `screen-mirror --check` and `client-lint` clean, `test:tools` 1908 passed, `test:components` 230 files and 2878 tests passed before the patches and the three REST specs (11 tests) after them. Browser: `rest-services-write` 4 and `rest-apis` 4 passed on the rebuilt, redeployed bundle. Bundle initial total 3,320,456 bytes against the 3326kB warning (no re-base); Fixed strings 3134 of 3400. The throwaway reads S0.

**Residual risk:** about 5.5 kB of bundle headroom under the warning. The full ObjectScript sweep and the full browser suite are the runner's and CI's.
