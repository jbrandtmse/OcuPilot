---
title: 'Story 21.38: Shared Rules helpers, the source-control follow-up and escalated wording'
type: 'refactor'
created: '2026-11-21'
status: 'in-progress'
baseline_revision: 'd76f1c5165459a203247353baa4288a88a0a1b87'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-21-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-21-37-page-resources.md'
warnings: ['multiple-goals', 'oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** Six ledger entries are routed here. Four change what a person reads: a page that fails to load is reported to the agent as refused for unsaved changes (DW-2369), a trace arrow's accessible name leaves out its visible label (DW-2442), the cube screens say "no cube" when cubes are hidden from the caller (DW-2474), and Page resources says a resource gates opening a screen when it gates one of its writes (DW-2823). DW-2405: OcuPilot's create and delete of a class or routine drop the source-control class's follow-up question. DW-2499: the Area screen-editor Rules classes repeat the violation sentence and the name-taken probe.

**Approach:** Ten ordered batches, each verified and committed alone: the four wording entries first (Batches 1-3), the source-control follow-up (Batches 4-6), then DW-2499 in four slices (Batches 7-10). Every new or changed sentence is in one escalated batch under Design Notes, and none is used until the orchestrator rules it. The refactor changes no answer, sentence or status any Rules class gives today.

## Boundaries & Constraints

**Always:**

- Use only ruled text, verbatim. A batch whose strings are not yet ruled does not start.
- New codes go in a per-area sibling of `Api/Error.cls` (as `Api/AccessError.cls`, `Api/AtelierError.cls`).
- Add-only edits in `strings.ts`, `EXPERIENCE.md` and every shared roster, apart from the ruled string values Batches 1 and 3 replace.
- `AtelierPort` stays the only class that names `%Api.Atelier.*`. The source-control answer goes through `Route("Query")` as one port-fixed statement with every value bound, behind the port's read pairs plus WRITE on the namespace's routines database (AD-61 rules 1, 3, 7).
- The source-control class's own text reaches the screen and the proposal card only, as text. It never reaches the model, a tool result, a ledger row, an audit payload, a log line or screen context (AD-39, the proposed ninth exception).
- DW-2499's helpers return byte-identical sentences and the same `pTaken` and status for every input the copies handle today. Existing Rules method names and signatures stay, since tools call them through `#RULES`.
- Measurements and armed tests run on `ocupilot-ci` only, and remove what they create. `ocupilot-slot-a` is read-only.

**Never:**

- No new AD, and no AD amendment except the AD-39 ninth exception (extension, add-only, written by the runner).
- No edit to `Api/Error.cls` unless the orchestrator rules Escalated item E1 (DW-2369's dispatch line).
- No change to `Screen.Gate.RequiredPairs`, the `PROHIBITED.OCUPILOTSCREEN` arm, Page resources' destructive effect, or the list's `Screen` column.
- The agent never answers a source-control question, and no question text reaches the model.
- No change to HandleForm's bodies, the `Screen/Tool` copies of the violation loop, or any interoperability file.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Page code fails to load | The agent navigates and the lazy chunk rejects `navigateByUrl` | Settled `refused` with the new load-failure code; the stale-bundle notice still shows | A guard's `false` still settles `NAV.REFUSEDUNSAVED` |
| Trace arrow | Message 13, body class empty, error flag | The name contains the visible "13" and "(no body) [ERROR]" | none |
| Hidden cubes | A namespace whose cubes the caller cannot read | Cubes, Cube manager and the three tabs show the ruled "visible to you" sentences | none |
| Page declared only by a tool | `%CSP.UI.Portal.Dialog.ExportResource` | Dialog and card show the action line naming Export on Resources, never the screen-open line | A tool with no screen action is named by the ruled unnamed item |
| Page declared both ways | `%CSP.UI.Portal.User` | The screen-open line plus the action line | none |
| Create or delete with source control, action 1 | The probe class answers action 1 | The screen or card shows the class's question with Yes, No and Cancel; the answer runs `AfterUserAction` as the person | An answer with `errorText` shows the ruled refusal, and the text is logged only |
| Action 6 | Alert | Text with Close; no `AfterUserAction` | none |
| Actions 2-5, 7 | Any other step | The ruled "cannot show" line; nothing is sent | none |
| No source control, or action 0 | default namespace | No question, output unchanged | none |

</intent-contract>

## Code Map

DW-2474 and DW-2442 (Batch 1):

- `ui/src/app/core/strings.ts:7904-7910` holds `analyticsCubesEmpty` and `analyticsCube{Measures,Dimensions,Relationships}Empty`. The siblings are `:7916` `analyticsFolderItemsEmpty` and `:8192` `analyticsListingGroupsEmpty`. Consumers are `Descriptor/AnalyticsCubeList.cls:31`, `AnalyticsCubeManager.cls:38` and `AnalyticsCube*Tab.cls:29`. `Port/AnalyticsPort.cls:1133,1151` hides a guarded cube.
- `strings.ts:7777` holds `interopTraceArrow`, plus `:7779` `interopTraceNoBody` and `:7781` `interopTraceErrorMark`.
- `ui/src/app/areas/interoperability/session-trace.ts:50-52` `labelOf` and `:104-114` `arrowName`. `interop-message-trace.ts:129-146,186` binds the name.
- `EXPERIENCE.md:604` is the Fixed-strings row holding both. `ui/tools/strings.test.mjs` holds it equal to `strings.ts`.
- Pins: `session-trace.spec.ts:89-102`, `interop-message-trace.spec.ts:264-326`, `ui/browser/interop-message-trace.browser-spec.mjs:174,305,324-332`, and `ui/browser/analytics.browser-spec.mjs:355-372`.

DW-2369 (Batch 2):

- `ui/src/app/shell/agent-navigator.ts:35-40` (class comment), `:106` (`.catch(() => false)`) and `:107-118`.
- `ui/src/app/core/turn.ts:84` `NAV_REFUSED_UNSAVED_CODE` and `:1745` `settleNavigation`.
- `src/OcuPilot/Api/Turn.cls:303-312` (doc) and `:367-407` `NavigationViolation`, with the code check at `:401`.
- `Api/Error.cls`: NAV codes `:926-966`, reasons `:1052-1070`, `NavCodes` `:1139`, `ReasonForNav` `:1146`, `ReasonForToolCode` `:1222`, whose prefix chain falls through to `REASONTOOLUNAVAILABLE`, and `TURNNAVIGATIONINVALID`'s doc `:966-975`. The class holds 991 of the compiler's 1,000 parameters.
- `Screen/Tool/Navigate.cls:68` is the tool description.
- `ui/src/app/shell/stale-bundle-notice.ts:27-31,67-68` rechecks the build on `NavigationError`.
- Pins: `Test/TurnNavigate.cls:225-306`, `Test/ToolNavigate.cls:429-443` (the 7-code count) and `:464`, `ui/tools/turn.test.mjs:1107-1137`, `agent-navigator.spec.ts:147,183-191`, and `panel.spec.ts:1446`.

DW-2823 (Batch 3):

- `Screen/Registry.cls:4146-4178` `ScreensDeclaringPage` folds write tools' `CLASSICPAGES` (`:4159-4164`) into the descriptor pages (`:4169`).
- `Screen/Gate.cls:238-258` `RequiredPairs` unions only descriptor pages. A tool's pages gate its write through `WithClassicPages` (`:383-396`, `Write.cls:116-124`).
- Callers:
  - `Port/PortalResourcePort.cls:326-344` (`TitleList`, `Declaring`; the list's `Screen` column)
  - `Kernel/Proposal/Prohibited.cls:3188-3220` (arm and effect, unchanged)
  - `Screen/Tool/PageResourceAction.cls:105-138` (`ScreenRows`, `DryRunReview`)
- Client:
  - `ui/src/app/areas/permissions/page-resources-dialog.ts:45-57,220-229`
  - `ui/src/app/core/proposal-view.ts:219-237,544`
  - `ui/src/app/core/screen-actions.ts:104` `actionLabel(descriptor, id)`. It is the only home of action labels; the server holds none.
- Of about 115 tools declaring `CLASSICPAGES`, 63 declare no `SCREENACTIONS`. 50 pages are declared only by a tool and 37 both ways.
- Ruled strings at `strings.ts:9325-9335` and `EXPERIENCE.md:613`.
- Pins: `Test/PageResourceRead.cls:35,251-275` (its `:272` assertion stays: the column is unchanged), `PageResourceProhibited.cls:151,210`, `proposal-view.test.mjs:365-393`, `page-resources-dialog.spec.ts:193-329`, and `ui/browser/page-resources.browser-spec.mjs`.

DW-2405 (Batches 4-6):

- `Port/AtelierPort.cls:2666` `SaveSet` (`PutDoc` `:2712`, `pResult` `:2714`) and `:1952` `DeleteSet` (`DeleteDocs` `:1964`, items read `:1972-1980`). Both drop `ext`.
- `CatalogQuery` → `Route("Query")` is at `:1405`. The fixed `CALL` statements are at `:184-213`.
- Vendor:
  - `irissys/%Api/Atelier/v1.cls:1139-1154` (new-document `PutDoc` runs `UserAction` 1,1 and 1,7; `ext` is an array). `:1320,1472,1486-1488` (`DeleteDocs` puts one `ext` object per item).
  - `%Atelier/v1/Utils/Extension.cls:162-172` gives the keys `{action, target, message, reload, doc?, errorText}`. `:205` is `Query AfterUserAction(pSystem, pAction, pInternalName, pAnswer, pMessage) [SqlProc]`, SQL name `%Atelier_v1_Utils.Extension_AfterUserAction`.
  - `irislib/%Studio/Extension/Base.cls:277-334` (action codes 0-7; answer 0 No, 1 Yes, 2 Cancel; "not called" without interaction).
- Tools:
  - `Screen/Tool/ExplorerDelete.cls` (`ExplorerClassDelete`, `ExplorerRoutineDelete`, `SCREENACTIONS="delete"`)
  - `ExplorerCreate.cls` (agent-only `explorer.{classes,routines}.create`, `WriteOutput` `:144` → `ExplorerSave.WriteOutput` `:258`)
  - `ExplorerWrite.cls:140`
  - `Kernel/Proposal/Operation.cls:224-235` `OutputOf` keeps output to the screen and the card.
  - Person-only unadvertised sibling: `ExplorerGlobalNodeSave.cls` (Story 21.5).
- Client:
  - `areas/system-explorer/code-list.page.ts:536-545` `onDelete` and `code-list.store.ts:259-273` `deletedDocumentsOf`
  - `shell/proposal-card.ts:377-379,1120-1126`
  - `core/turn.ts:517` `outputLinesOf`
- Probe: `Test/SourceControlProbe.cls` (`Enable`, `Action`, `Disable`). `Test/SourceControlSave.cls` is armed `OCUPILOT_ALLOW_NAMESPACE_CONFIG`.

DW-2499 (Batches 7-10; paths under `src/OcuPilot/Area/`):

- The violation loop, canonically at `Security/MftConnectionRules.cls:172`:
  - Identical copies: `PhoneProviderRules:104`, `SuperserverRules:173`, `DocDbAppRules:202`, `AuthOptionsRules:84`, `EcpSettingsRules:120`, `JournalRules:98`.
  - The ByRef function form: `SslRules:194`, `LdapRules:505`, `OAuthAuthorizationServerRules:763`, `OAuthRegisteredClientRules:707`, `OAuthResourceServerRules:576`, `ServiceRules:357`, `TaskRules:1391`, `LanguageServerRules:491` (`+$Get`) and `AuditEventRules:178` (`ProblemText`).
  - The `tField` form: `DatabaseRules:169` (also `ActionProblem:363`), `EcpRules:126`, `LicenseRules:126`, `RemoteDatabaseRules:92`.
  - Not copies: `EncryptionRules:62`.
- The Taken probe, canonically at `OsMgmt/EcpRules.cls:158`:
  - Identical copies: `LicenseRules:149`, `Permissions/ResourceRules:252`, `SslRules:441`, `WalletRules:288`.
  - Same 404 tail with a different read: `X509Rules:287`, `DeviceRules:329`, `MappingRules:324`, `NamespaceRules:241`, `LanguageServerRules:415`, `OAuthServerRules:260`, `MftConnectionRules:150`, `PhoneProviderRules:82`, `DocDbAppRules:180`, `SuperserverRules:151`.
- `MftConnectionRules.ClientConfiguration:131` and `SuperserverRules.ServerConfiguration:132` differ only in the type test. `Test/SuperserverRulesSeam.cls:14` overrides `ServerConfiguration`.
- Siblings to extend:
  - `Kernel/AgentRules.cls:430` `ViolationsJson`. It reads list element 3 when set; the loops always read the code.
  - `Kernel/Proposal/ScreenSaveRules.cls`: `RenderViolations` `:20`, `RenderRead` `:29`, `Gate` `:43`. Its adopters are Mft, PhoneProvider, Superserver and DocDbApp (and RoutineApp through DocDbApp).

## Tasks & Acceptance

**Execution:** ten batches in order, each verified, committed and recorded under Design Notes alone. A batch with user-facing text starts only once its strings are ruled. A ruling that declines an entry turns that batch into a recorded close. Edit only with Edit and Write, one step per Bash call, each bounded with `timeout 600`. Before each batch, re-run the Epic 24 contention check for its files (stage-common.md). An edit beyond add-only in a file Epic 24 changed is a `## Clarification Needed`.

Batch 1 (DW-2474, DW-2442):

- Task 0 (E2's AD-53 measurement, `ocupilot-ci` only): with auditing on and `SourceControlProbe` enabled in a namespace, raise a question, answer it through `action/query`'s `AfterUserAction`, and read `%SYS.Audit` for every event in that window. Record the rows (or none) under Design Notes. A vendor event stops the story with `## Clarification Needed`. Remove the probe and read it back absent.
- `ui/src/app/core/strings.ts`, `EXPERIENCE.md:604` -- replace the four cube sentences and `interopTraceArrow` with S1-S5, and the row's gloss "names one arrow's message, type, source, target and status" with "... message, label, type, ...".
- `ui/src/app/areas/interoperability/session-trace.ts` `arrowName` -- add `label` (`labelOf`'s value) to the placeholder values.
- `session-trace.spec.ts`, `interop-message-trace.spec.ts` -- the expected names gain the label. Add a case where the name contains `item.arrow.id` and `item.arrow.label` for a `(no body) [ERROR]` arrow.
- `ui/browser/interop-message-trace.browser-spec.mjs` -- add-only: each drawn arrow's accessible name contains its two visible `<text>` contents.

Batch 2 (DW-2369; needs E1):

- `src/OcuPilot/Api/NavError.cls` (new, on `AccessError`'s shape) -- `NAVLOADFAILED = "NAV.LOADFAILED"` with S6, plus `ReasonFor` and `Codes()`.
- `Api/Error.cls` (as ruled in E1) -- in `ReasonForToolCode`, one `NAV.` prefix line delegating to `NavError.ReasonFor`, and `TURNNAVIGATIONINVALID`'s doc naming both codes. No parameter is added.
- `Api/Turn.cls` `NavigationViolation` -- `refused` accepts `NAV.REFUSEDUNSAVED` or `NavError.NAVLOADFAILED`, and nothing else. Update the doc at `:303-312,367-372`.
- `Screen/Tool/Navigate.cls:68` -- the description per S7.
- `ui/src/app/core/turn.ts` -- `NAV_LOAD_FAILED_CODE`, and `settleNavigation`'s code type.
- `ui/src/app/shell/agent-navigator.ts` -- a rejected `navigateByUrl` settles `refused` with `NAV_LOAD_FAILED_CODE`, and a resolved `false` keeps `NAV_REFUSED_UNSAVED_CODE`. Correct the class comment.
- Tests:
  - `Test/TurnNavigate.cls`: the settle accepts the new code and refuses a third.
  - `Test/ToolNavigate.cls`: `TestEveryNavCodeHasAWrittenSentence` iterates `NavCodes()` and `NavError.Codes()`, through `ReasonForToolCode`.
  - `ui/tools/turn.test.mjs`: the two client-authored codes.
  - `agent-navigator.spec.ts`: a rejecting router settles the load-failure code, and a `false` router the unsaved code.

Batch 3 (DW-2823):

- `Screen/Registry.cls` -- add `PageDeclarations(pPage, Output pOpens As %List, Output pActions As %List)`:
  - `pOpens` holds the built descriptors whose own `ClassicPage()` or `CLASSICPAGES` name the page, which is what `RequiredPairs` unions.
  - `pActions` holds one `$ListBuild(descriptor class, screen-action id)` per write tool `CLASSICPAGES` entry, with id `""` for a tool with no screen action.
  - `ScreensDeclaringPage` answers the union through it, unchanged.
- `Screen/Tool/PageResourceAction.cls`:
  - `DryRunReview` adds `Opens` (titles) and `Actions` (`[{screen, action}]`).
  - `ScreenRows` adds an `Action` row carrying the same entries as `<descriptor>#<id>` joined by `,`, only when any exist.
- `ui/src/app/areas/permissions/page-resources-dialog.ts` -- the replaces and consequence lines:
  - The screen-open line comes from `Opens` only.
  - The action line (S8, S9/S10 with S11/S12, capped as `pageResourcesLineMany` is, through `pageResourcesMore`) is added when `Actions` is non-empty.
  - `LineNone` shows only when both are empty.
- `ui/src/app/core/proposal-view.ts` -- `pageResourceSentence`:
  - It joins the screen-open sentence (from the `Screen` row, filtered to the opening screens if E3 rules so) with the action sentence from the `Action` row. Action phrases resolve through `actionLabel` and the `SCREENS` mirror's title.
  - Wherever the card prints the `Action` row's value, it prints the phrases, never a descriptor class or an id. If the card has no formatting point, stop with `## Clarification Needed`.
- `strings.ts`, `EXPERIENCE.md:613` -- add-only: S8-S12.
- Tests:
  - `page-resources-dialog.spec.ts`: tool-only, both-ways, and one page with a labeled tool beside an unlabeled tool (S11 and S12 in one line).
  - `proposal-view.test.mjs`: the same three.
  - `Test/PageResourceProhibited.cls`: `PageDeclarations` splits `%CSP.UI.Portal.Dialog.ExportResource` (tool-only) and a both-ways page, and `ScreensDeclaringPage` is unchanged.
  - `ui/browser/page-resources.browser-spec.mjs` (add-only): the change dialog on the export page shows the action line and not the screen-open line.

Batch 4 (DW-2405, the port):

- `Port/AtelierPort.cls`:
  - `SaveSet` (create only) and `DeleteSet` read `ext` into `questions: [{document, step, action, target}]`. The step is 1 or 7 for a create and 2 for a delete.
  - Action 0 is dropped. Actions 1 and 6 keep `target`. Any other action becomes `{document, step, action, unsupported: true}` with no target.
  - `errorText` is logged at information severity and never sent.
  - A new `ANSWER` write type takes the read pairs plus routines-database WRITE, with `Query`'s minimum version. It validates the document as the delete does, the step in {1,2,7} and the answer in {0,1,2}. It sends the fixed `USERACTIONANSWERQUERY` (`SELECT * FROM %Atelier_v1_Utils.Extension_AfterUserAction(?,?,?,?,?)`, values `1, step, document, answer, ""`).
  - A non-empty answer `errorText` is 422 `EXPLORER.SOURCECONTROL.ANSWER` (S19).
- `Api/AtelierError.cls` -- `SOURCECONTROLANSWER` and its reason. Confirm that the `EXPLORER.` dispatch reaches it.
- `Screen/Tool/ExplorerWrite.cls`, `ExplorerDelete.cls`, `ExplorerSave.cls`, `ExplorerCreate.cls` -- `WriteOutput` passes `questions` through. Nothing reaches a tool result (`Operation.OutputOf`).
- `Test/SourceControlFollowUp.cls` (new, armed `OCUPILOT_ALLOW_NAMESPACE_CONFIG`, on `SourceControlSave`'s fixture) covers:
  - a create and a delete with action 1 return the question, and with 0 return none;
  - action 3 is unsupported with no target;
  - an answer runs `AfterUserAction` as the caller (from the probe log);
  - a bad step or answer is refused before any call;
  - every probe and class is removed and read back absent;
  - AD-39's ninth exception: a question's text is absent from the tool result, the ledger, the audit payload and the screen context.

Batch 5 (DW-2405, the answer action):

- `Screen/Tool/ExplorerSourceControlAnswer.cls` (abstract), `ExplorerClassAnswer.cls` and `ExplorerRoutineAnswer.cls` (new) -- unadvertised, person-only, `SCREENACTIONS="answer"` and `WRITETYPE` `ANSWER`, on `ExplorerGlobalNodeSave`'s shape:
  - no mint, no card, no draft;
  - keys `explorer.{classes,routines}.answer` ship `false`, and a person's action asks none.
- `Screen/Descriptor/ExplorerClassList.cls`, `ExplorerRoutineList.cls` -- declare the `answer` row action, sent only by the question dialog, as `ExplorerGlobalView` declares `save` for its own editor. If the shared row menu would draw it, stop with `## Clarification Needed` rather than add a hiding mechanism. Then regenerate `screens.generated.ts`.
- `Kernel/Governance/Baseline.cls` -- add-only: both keys.
- Rosters, with names read from the instance: `SurfaceCoverage`, `ToolWrite`, `ReadTool`, `DraftRegistry`, `ToolEmit`, `ToolRoundTrip`, `StageTwoTools`, `RemovalRowsSweep` and `EndpointCoverage` (21.37's four reds are the checklist).
- `Test/SourceControlFollowUp.cls` -- the answer through `POST /screens/:screen/action` as a principal holding `%Development:USE` and READ only is refused, and with WRITE it is accepted.

Batch 6 (DW-2405, the client):

- `areas/system-explorer/source-control-question-dialog.ts` (+`.spec.ts`, new) -- shows the questions in order.
  - Action 1: S13 title, S14 lead, the class's text, then Yes (S16), No (S17) and Cancel. Each sends `answer` and shows S19 on a refusal.
  - Action 6: S15 lead and Close (S18).
  - Unsupported: S20.
- AD-39's ninth exception, in the dialog spec and `proposal-card` spec: a question carrying markup and a newline renders as inert plain text on the screen and on the card.
- `code-list.store.ts`, `code-list.page.ts` (+spec) -- after a delete, open the dialog when the output carries `questions`.
- `core/turn.ts`, `shell/proposal-card.ts` (+spec) -- a confirmed create or delete whose output carries `questions` opens the same dialog from the card. The answer goes to the tool's own list screen.
- `strings.ts`, `EXPERIENCE.md` -- add-only: S13-S20.
- `ui/browser/system-explorer-source-control.browser-spec.mjs` (new; refuses live and slot containers) -- with the probe enabled, delete a probe class, answer Yes, then confirm `AfterUserAction ...|1` in the probe log. Remove the probe.

Batches 7-10 (DW-2499). Each adopter's methods keep their names and signatures and delegate.

- Batch 7:
  - `Kernel/AgentRules.cls`: `ViolationsSentence(ByRef pViolations) As %String`, the loop's join, looking the sentence up by code.
  - `Kernel/Proposal/ScreenSaveRules.cls`: two static class methods. `ReadTaken(pSC, pHttp, pFresh, Output pTaken) As %Status` is the 404 tail. `SslConfiguration(pName, pAccept, Output pValid)` is the twin, where `pAccept` is the list of accepted type values.
  - The four adopters (`MftConnectionRules`, `PhoneProviderRules`, `SuperserverRules`, `DocDbAppRules`) use them. `ServerConfiguration` stays overridable.
- Batch 8: the ByRef family (9 files) returns `ViolationsSentence`. `LanguageServerRules` keeps its `+$Get` guard.
- Batch 9: the `Check`/`tField` family (7 files: AuthOptions, EcpSettings, Journal, Database, Ecp, License, RemoteDatabase). Each keeps its own prelude (unexpected field, fault reason).
- Batch 10: the Taken probe (11 files: Ecp, License, Resource, Ssl, Wallet, X509, Mapping, Device, Namespace, LanguageServer, OAuthServer). Each keeps its read line and calls `ReadTaken`.
- Tests: Batch 7 adds `Test/AgentRules` cases for `ViolationsSentence` (none, one, three) and `ReadTaken` (404, other error, object, non-object). Every other batch runs its loop set unchanged.

**Acceptance Criteria:**

- AC1 (DW-2369): Given an agent navigation whose page code fails to load, when the navigator settles it, then the turn records `refused` with `NAV.LOADFAILED`, the tool step carries the ruled S6, and a guard's decline still records `NAV.REFUSEDUNSAVED`.
- AC2 (DW-2442): Given a drawn trace arrow, when its accessible name is read in the browser, then it contains the arrow's visible id and label, error flag included.
- AC3 (DW-2474): Given the cube screens and tabs, when they answer empty, then each shows its ruled sentence.
- AC4 (DW-2823): Given a page only a write tool declares, when a change or clear is reviewed in the dialog or shown on the agent's card, then it names that action (or the ruled unnamed form) and never says the screen can no longer be opened. Given a page declared both ways, then both lines show. The prohibited arm, the destructive effect and the list's `Screen` column answer as before.
- AC5 (DW-2405, the integration AC): Given a namespace whose source-control class asks after a create or a delete, when the person deletes from the Classes list, or confirms the agent's create or delete, then the class's question shows on that screen or card. The person's answer runs `AfterUserAction` as the person. The model, tool results and logs never carry the question.
- AC6 (DW-2405): Given action 6, or an action OcuPilot cannot show, when it is returned, then the alert shows with Close and nothing is sent, or the ruled line shows.
- AC7 (DW-2405): Given an answer from a principal without WRITE on the namespace's routines database, or with a bad step or answer, when it is sent, then it is refused before any vendor call.
- AC9 (AD-39's ninth exception): Given a source-control question carrying markup or a newline, when it shows on the screen or the card, then it renders as plain text, and its text never reaches the tool result, the ledger, the audit payload or the screen context.
- AC8 (DW-2499): Given every adopter, when its existing tests run, then each is green with unchanged sentences, statuses and taken verdicts, and the loop and probe exist once, in the helpers.

## Spec Change Log

## Review Triage Log

## Design Notes

**Governing ADs:** AD-39 (one envelope; vendor text normalized; a proposed ninth exception), AD-61 (rules 1, 3, 6, 7, 8), AD-53 (two callers; the agent never answers; a person-only action), AD-22 (keys), AD-10, AD-44 and AD-64 rule 2 (DW-2823's arm, effect and gate are unchanged), AD-11 (no question text reaches the model), AD-5 and AD-36 (the descriptor and read are unchanged), AD-19, AD-43 (the navigation settle), AD-12, AD-16 and AD-29. The spine stays add-only. The only extension is the AD-39 ninth exception below, which the runner writes (Rule 20).

**Ledger inbox:** all six are addressed. DW-2499 is closed in part:

- HandleForm stays per class. The shared part is a five-line gate prelude around bodies that differ, so a template would read worse than the copies (Rule 2's stated reason).
- The `Screen/Tool` copies of the loop (14, and nine interoperability one-liners) are outside the entry's "Area screen-editor Rules classes". The 23 identical `Gate` methods are a shape the entry does not name. Both are for the runner to ledger.
- The measured counts are 20 Area files holding the loop (the ledger says 29) and 15 holding the probe (12).

**Measured at plan** (`ocupilot-ci`, 2026-11-21, through the vendor routes over HTTP with `SourceControlProbe` in `USER`; everything removed and read back absent):

- A new-document `PUT` answered `ext` with two `{action:1, target, message, reload:0, errorText:""}` entries. A second `PUT` answered `ext: []`.
- `DELETE docs` put one `ext` object on the item.
- `action/query` with the `SELECT` and the `CALL` forms both answered 200. The probe log recorded `UserAction 1|1`, `1|7` and `1|2`, then `AfterUserAction 1|7|1`, `1|2|0` and `1|2|2`, all as the caller.
- That the in-process port call behaves the same is (inference), as Story 20.10 recorded for the hooks.

**Task 0, the AD-53 audit measurement** (`ocupilot-ci`, 2026-11-22, auditing on, probe enabled in `USER` with action 1): a new-document `PUT`, then `action/query` `AfterUserAction` (`1|1|OcuProbe2138.New.cls|1`), then the class's delete and the probe's removal. `%SYS.Audit` held 230,527 rows before and after, and a read of every row from the window's start returned none. No vendor event, so the answer adds no gap beyond ten and twelve. The probe, the class, the hooks class, the log and the setting were read back absent.

**Batch records** (pass 1):

- Batch 1 (DW-2474, DW-2442): S1-S5 in place, `arrowName` carries `label`. The `strings.ts` keys carry no other copy of the cube sentences. Mutations observed red and reverted: `arrowName` drops `label` -> `interop-message-trace.browser-spec.mjs` AC4 label-in-name; `analyticsCubeDimensionsEmpty` reverted -> `strings.test.mjs` (3 tests). Loop green: `strings.test.mjs`, interoperability component specs, browser `interop-message-trace` and `analytics`, `test:tools`, `test:components`.
- Batch 2 (DW-2369): `Api/NavError.cls` (S6), one `NAV.` line and one doc line in `Error.cls` (0 removed words, 991 parameters, placed after the `ReasonForNav` early return so existing `NAV.*` codes are answered before it), `NavigationViolation` admits both codes, S7 in `Navigate`, the navigator settles a rejection as `NAV.LOADFAILED`. `ToolNavigateContract`'s literal copy of the description was updated. `TURNNAVIGATIONINVALID`'s existing doc line still lists one code, since correcting it would remove words from the frozen file; the added line names both. Mutations observed red and reverted: the navigator's `catch` -> `agent-navigator.spec.ts` load-failure case; `NavigationViolation` accepting any code -> `TurnNavigate.TestAC10NavigationBodyVocabulary`; the `NAV.` line removed -> `ToolNavigate.TestEveryNavCodeHasAWrittenSentence`. Loop green: `TurnNavigate`, `ToolNavigate`, `ToolNavigateParent`, `ToolNavigateContract`, `LedgerClientRows`, `turn.test.mjs`, navigator and panel specs, `test:tools`, `test:components`.
- Batch 3 (DW-2823): `Registry.PageDeclarations` answers `pOpens` and `pActions` (a fourth output, `pResolved`, carries what `ScreensDeclaringPage` needs) and `ScreensDeclaringPage` answers through it; `DryRunReview` adds `Opens` and `Actions` beside `Screens`; `ScreenRows` adds the `Action` row. S8-S12 are in `strings.ts` and the `EXPERIENCE.md:613` row. The words live in the new `core/page-resource-actions.ts` (`actionLabel` and the `SCREENS` title; S12 names a tool with no label), shared by the dialog and the card. Measured over the 87 pages a write tool names: 37 both ways, 50 tool-only, 62 tool entries on a screen that also opens the page. Mutations observed red and reverted (md5 equal, source reloaded): `PageDeclarations` puts tool pages in `pOpens` -> `PageResourceProhibited.TestPageDeclarationsSplitOpeningFromActions` and the browser `page-resources` AC4 case; the dialog draws the action line only beside a screen-open line -> 4 cases of `page-resources-dialog.spec.ts`; the card reads the `Screen` row while an `Action` row names writes -> `proposal-view.test.mjs`. Loop green: `PageResourceRead`, `PageResourceProhibited`, `PageResourceWrite`, `ToolRoundTrip`, `ToolEmit`, `SurfaceCoverage`, `RemovalRowsSweep`, `proposal-view.test.mjs`, the permissions and `proposal-card` specs, browser `page-resources`, `test:tools`, `test:components`.
- Decided in-stage (Batch 3), each reversible inside the story:
  - The card has the `Screen` row (every declaring title) and the `Action` row, so it cannot tell a screen that opens the page from one that only carries a tool, and 62 tool entries are on a screen that also opens the page. The `Action` row therefore also lists each opening screen as a bare `<descriptor>` entry whenever it names any write; the card reads the opening screens from those, and from the `Screen` row when no write is named. The person never sees a descriptor: `shownChangedRows` and `shownUnchangedRows` in `proposal-view.ts`, which the card's row getters call, print the row as the writes' phrases.
  - `pActions` lists a tool's first `SCREENACTIONS` id and lists one pair once, so two unlabeled tools on a screen read one S12 phrase; the client also lists a phrase once.
  - The dialog's review reads `Opens` as its screen titles and `Actions` as the writes; `Screens` stays in the answer.

**AD-61, read as written:** the answer is a port-fixed statement through `Route("Query")` with bound values (rules 3 and 7), and a write the port carries takes routines-database WRITE (rule 1). Rule 6's "vendor text is logged and never sent" is read as the outcome's error text. So no AD-61 record is planned; see E2.

**Proposed AD-39 ninth exception (for the runner, add-only):**

> **The ninth exception** [Story 21.38]: a source-control class's question or alert after OcuPilot creates or deletes a class or routine (`UserAction`'s `Target`, actions 1 and 6) reaches the screen and the proposal card only, as text, and never the model, a tool result, a ledger row, an audit payload, a log line or screen context.

**Rule 2 (extends):**

- `ViolationsSentence` sits beside `ViolationsJson` (the ledger's note).
- `ReadTaken` and `SslConfiguration` are static methods on `ScreenSaveRules`, because most adopters do not extend it and their `Add`, `Text` and `RenderViolations` clash with its own.
- `NavError` follows `AccessError`.
- The answer tools follow `ExplorerGlobalNodeSave`, and the dialog follows Page resources' dialog.
- `PageDeclarations` is the one home that `ScreensDeclaringPage` now answers through.

**Integration (Rules 1-2):**

- Consumed-by: the Classes and Routines lists and the proposal card consume `AtelierPort`'s `questions` (AC5, browser spec on `ocupilot-ci`). The Batch 7-10 adopters consume the helpers (AC8).
- Consumes: `AtelierPort`, `SourceControlProbe`, `Screen.Registry`, `actionLabel`, the `SCREENS` mirror, and `Kernel.AgentRules`.

**Decided in-stage:**

- DW-2369 settles a load failure as `refused` with a new code rather than letting it lapse to `NAV.UNAVAILABLE`, which would be wrong and late.
- DW-2823 keeps the list's `Screen` column, the arm and the destructive effect, and changes only the two sentences' derivation. Labels resolve in the client, the only home of action labels.
- DW-2405:
  - Only actions 1 and 6 are shown; 7 needs a textbox and is the cheapest to add later.
  - The agent learns nothing new.
  - The answer keys ship `false`, because a person's action asks no governance key (Story 21.5).
  - `ImportSet`'s new-document put is outside the entry.
- The batch order follows the ruling: the wording first, DW-2499 last.

**Escalated (structural; the runner rules with the strings):**

- **E1 (DW-2369).** A `NAV.*` code reaches a reason only through `Api/Error.cls`: `ReasonForToolCode` has no `NAV.` dispatch, and an unknown code falls through to "tool unavailable". The options:
  - (A, recommended) one method line and one doc comment in the frozen file, with no parameter added;
  - (B) close DW-2369 `wontfix-accepted note=reopen_if=Error.cls is unfrozen`.
- **E2 (DW-2405).** Confirm the AD-61 reading above. If rule 3 is read as reads-only, the answer needs an AD-61 record, which this story may not write: close DW-2405 or allow the record. Also confirm that a person's answer, the follow-up of System Explorer's Delete and Save, is AD-53's named gaps ten and twelve, so it adds no gap (inference: `AfterUserAction` records no vendor event).
- **E3 (DW-2823).** The action "named from the tool's own label" has no server home, and 63 of about 115 page-declaring tools have no screen action and so no label. Options:
  - (A, recommended, planned) the client resolves `actionLabel`, and a tool with no screen action is named by S12;
  - (B) only the dialog names actions, and the card says S12 for all.

  Also rule whether the card's `Screen` row keeps every declaring title (planned: yes) while the screen-open sentence names `Opens` only.
- **E4 (DW-2474, DW-2442).** Applying S1-S5 replaces five ruled string values in place. Every other edit is add-only.

**Strings, escalated** (one batch; none is used until ruled). Each has the proposed exact text and the sibling it is modeled on:

- DW-2474 (decision sheet U-35's recommendation for S1, on `analyticsFolderItemsEmpty`):
  - S1 `analyticsCubesEmpty`: "No cube in this namespace is visible to you."
  - S2 `analyticsCubeMeasuresEmpty`: "This cube no longer exists, you cannot read it, or it has no measures." (on `analyticsRefusalPmmlCube`'s "or you cannot read it")
  - S3 `analyticsCubeDimensionsEmpty`: "This cube no longer exists, you cannot read it, or it has no dimensions."
  - S4 `analyticsCubeRelationshipsEmpty`: "This cube no longer exists, you cannot read it, or it has no relationships."
- DW-2442 (U-35's `<label>` placeholder):
  - S5 `interopTraceArrow`: "Message <id> <label>: <type> from <source> to <target>, <status>", for example "Message 13 (no body) [ERROR]: Response from Op to Proc, Error".
- DW-2369 (on `NAV.REFUSEDUNSAVED`'s "…, so the move was not made."):
  - S6 `NAV.LOADFAILED` reason: "The browser could not load that screen, so the move was not made."
  - S7 the Navigate description's clause: "the departing screen may refuse the move (for example, unsaved changes), the browser may fail to load the new screen, and the user may always return with Back."
- DW-2823 (on `pageResourcesLineOne` and the two consequences; the list is capped as `pageResourcesLineMany`, through `pageResourcesMore`):
  - S8 `pageResourcesActionLine`: "This page's resource will be required from the next request for: <actions>."
  - S9 `pageResourcesActionConsequenceChanged`: "Accounts that hold only the old resource can no longer use: <actions>."
  - S10 `pageResourcesActionConsequenceCleared`: "More accounts may use: <actions>. The instance still checks what they do there."
  - S11 `pageResourcesActionItem`: "<action> on <screen>".
  - S12 `pageResourcesActionItemUnnamed`: "changes on <screen>".
- DW-2405 (on the dialog titles "Change the resource of <page>", and the provider test's "Provider said: <text>" for labeling another party's text):
  - S13 dialog title: "Source control asks about <document>"
  - S14 lead before a question: "This namespace's source-control class asks:"
  - S15 lead before an alert: "This namespace's source-control class says:"
  - S16 "Yes" and S17 "No" (new action keys; Cancel reuses `actionCancel`)
  - S18 "Close"
  - S19 `EXPLORER.SOURCECONTROL.ANSWER`: "The source-control class reported an error for this answer, so its step may not have finished."
  - S20 the unsupported line: "This namespace's source-control class asked for a step OcuPilot cannot show for <document>. Open the document in an editor that supports server-side source control to finish it."
- EXPERIENCE.md glosses: the `:604` gloss change in Batch 1, and new rows beside `:613` (S8-S12) and System Explorer's (S13-S20).

**Rulings (orchestrator, spec gate, 2026-11-22; these bind every batch):**

- **Strings:** S1-S20 are approved as written and filed as one veto item, U-138. S1-S5 replace earlier ruled values in place (E4). S5 stays as ruled even where `<label>`'s `[ERROR]` flag and an Error status both print; the veto item names that.
- **E1 (A):** `Api/Error.cls` gets exactly one `NAV.` prefix dispatch line in `ReasonForToolCode` and one add-only doc-comment line. No parameter is added: the count stays 991, and `git diff --word-diff` of the file shows 0 removed words.
- **E2:** the answer is allowed, and AD-61 records it add-only (the runner writes it under Rule 20). AD-53: the answer falls under gaps ten and twelve. **Batch 1 Task 0** measures that on `ocupilot-ci`: with auditing on and the probe enabled, answer a question through the vendor's `AfterUserAction` and read the audit for any vendor event in the window. If one appears, stop with `## Clarification Needed`.
- **AD-39's ninth exception** is accepted with "as plain text, never as markup"; the runner writes it. It is pinned by two tests:
  - a question carrying markup or a newline renders inert on the screen and on the card (Batch 6);
  - its text is absent from the tool result, the ledger, the audit payload and the screen context (Batch 4/5, `Test/SourceControlFollowUp.cls`).
- **E3 (A):** the client resolves `actionLabel` from `screen-actions.ts`, and S12 names a tool with no label (63 are expected). The card's `Screen` row keeps every declaring title, and the screen-open sentence names only the `Opens` screens. Batch 3 adds a component test with one labeled tool and one unlabeled tool.
- DW-2499's measured counts, DW-2829 and DW-2830 are accepted.

**Contended paths** (2026-11-21): `origin/OCU-1-epic24 ^origin/feature` is empty, and the epic-24 worktree holds uncommitted edits only in `InteropLookup*`, `InteropPartnerRemove`, `InteropItemControl`, `InteropLookup{Descriptor,Fixture}`, two new `Test/*ConfirmNamespace*` and `scripts/ci-throwaway.sh`. None is in this plan except `ci-throwaway.sh`, if `SourceControlFollowUp` joins its arming roster (add-only, held by `ci.test.mjs`). Epic 24's Story 24.14 is on this branch.

**Size.** The batches touch about 7, 10, 11, 8, 14, 11, 6, 9, 7 and 11 files. Each is under the 15-file cap and committable alone, so the plan keeps one story.

## Verification

**Shared surfaces:**

- The Fixed-strings table (`strings.test.mjs`)
- The NAV vocabulary (`ToolNavigate`, `turn.test.mjs`)
- Page resources' review and card sentences
- The Classes and Routines lists' actions and `screens.generated.ts`
- The tool rosters (`SurfaceCoverage`, `ToolWrite`, `ReadTool`, `DraftRegistry`, `ToolEmit`, `ToolRoundTrip`, `StageTwoTools`, `RemovalRowsSweep`, `EndpointCoverage`)
- The governance baseline
- `ci-throwaway.sh`'s arming roster
- `AtelierPort`'s save and delete outputs

The implement stage greps `ui/browser`, `ui/tools`, the `ui/src` specs and `src/OcuPilot/Test` for each, and each test it changes joins `(loop)`. *Every test added or changed passes on a fresh environment, in either order.*

**Commands.** One per foreground call with `timeout: 600000`, never two test calls in one message. Before each browser run: `cd ui && npm run build`, then `docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`, with `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci`.

- `(loop)` `sh /private/tmp/claude-501/-Users-jbrandt-git-OcuPilot/b708a79b-b765-42ec-adea-dbc87acf6251/scratchpad/e21u/lead/reload.sh /Users/jbrandt/git/OcuPilot/.worktrees/epic-21 ocupilot-ci` -- `LOADERRORS=0`.
- `(loop)` Every ObjectScript class below runs as `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.<Class>`, one per call -- green.
- Batch 1:
  - `(loop)` `cd ui && npx ng test --include 'src/app/areas/interoperability/**/*.spec.ts'` -- green.
  - `(loop)` `cd ui && node --test tools/strings.test.mjs` -- green.
  - `(loop)` browser `interop-message-trace` and `analytics` -- green.
- Batch 2:
  - `(loop)` `TurnNavigate`, `ToolNavigate`, `ToolNavigateParent`, `ToolNavigateContract` and `LedgerClientRows`.
  - `(loop)` `cd ui && node --test tools/turn.test.mjs` -- green.
  - `(loop)` `npx ng test --include 'src/app/shell/agent-navigator.spec.ts' --include 'src/app/shell/panel.spec.ts'` -- green.
- Batch 3:
  - `(loop)` `PageResourceRead`, `PageResourceProhibited` and `PageResourceWrite`.
  - `(loop)` `node --test tools/proposal-view.test.mjs` and `npx ng test --include 'src/app/areas/permissions/**/*.spec.ts'`.
  - `(loop)` browser `page-resources`.
- Batch 4: `(loop)` `SourceControlFollowUp`, `SourceControlSave` and the `Explorer*` classes the grep names.
- Batch 5:
  - `(loop)` `SourceControlFollowUp`, `SurfaceCoverage`, `EndpointCoverage`, `ToolWrite`, `ReadTool`, `DraftRegistry`, `ToolEmit`, `ToolRoundTrip`, `StageTwoTools`, `RemovalRowsSweep` and `GovernanceBaseline`.
  - `(loop)` `node tools/screen-mirror.mjs --check`.
- Batch 6:
  - `(loop)` `npx ng test --include 'src/app/areas/system-explorer/**/*.spec.ts' --include 'src/app/shell/proposal-card.spec.ts'`.
  - `(loop)` browser `system-explorer-source-control` and `system-explorer-write`.
- Batches 7-10:
  - `(loop)` `AgentRules`, then each slice's write, read and gate classes from the Code Map's adopters.
  - Slice 7: Mft, PhoneProvider, Superserver, DocDbApp, RoutineApp and `ScreenSaveOrder`.
  - Slice 8: SslSave, Ldap*, OAuth*, Service*, TaskCreate, TaskRules, LanguageServer* and AuditEvent*.
  - Slice 9: AuthOptionsWrite, EcpSettingsWrite, Journal*, Database*, Ecp*, LicenseServerWrite and RemoteDatabaseWrite.
  - Slice 10: ResourceCreate, Wallet*, X509*, MappingWrite, Device*, Namespace* and OAuthServer*.
- Every batch:
  - `(loop)` `uv run scripts/check-objectscript.py` and `bash scripts/lint-docs.sh` -- clean.
  - `(once)` `cd ui && npm run test:tools` and `npm run test:components` -- green.
  - `(once)`, runner-owned: the ObjectScript sweep, one class per call; `smoke.sh --container ocupilot-ci`; Rule 30's fresh check. The full browser suite is CI's.

**Mutations (Rule 19), one per AC.** Each is applied, observed red and reverted, and the tree is confirmed identical. Reverted ObjectScript is reloaded, and the bundle is rebuilt before a browser read.

- AC1: the navigator's `catch` returns `false` → `agent-navigator.spec.ts` load-failure case red. `Turn.cls` accepts any code → `TurnNavigate` red.
- AC2: `arrowName` drops `label` → the browser label-in-name assertion red.
- AC3: one cube key's value reverted → `strings.test.mjs` red.
- AC4: `PageDeclarations` puts tool pages in `pOpens` → `PageResourceProhibited`, the dialog spec and the browser export-page case red.
- AC5: `DeleteSet` drops `questions` → `SourceControlFollowUp` and the browser spec red.
- AC6: action 6 sends an answer → the dialog spec red.
- AC7: the answer's WRITE pair removed → `SourceControlFollowUp`'s WRITE-less leg red.
- AC8: `ViolationsSentence` joins with `"; "` → the slice's write tests red. `ReadTaken` treats 404 as taken → `ResourceCreate` red.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none

Plan stage, 2026-11-21: three read-only research subagents, plus one measurement on `ocupilot-ci`. That measurement covered the source-control `ext` answers and `AfterUserAction` through `action/query`, using `SourceControlProbe` in `USER`. The probe, its class, the setting and `OcuProbe2138.New` were all removed and read back absent. Escalated for the spec gate: the strings batch S1-S20 and the structural items E1-E4. Implementation waits on them, batch by batch.

Protocol notes: the three subagents ran in the background although each call passed `run_in_background: false`. This stage polled them with bounded waits until each one reported. One subagent ran `git fetch` from the main checkout, which updated only two remote-tracking refs.
