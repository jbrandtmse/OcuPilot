---
title: 'Story 24.16: Purge, suspended messages, export and the archive manager (Batch 2: suspended messages)'
type: 'feature'
created: '2026-11-22'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
owned_ledger: ''
context:
  - '{project-root}/_bmad-output/implementation-artifacts/spec-24-16-purge-suspended-messages-export-and-the-archive-manager.md'
warnings: ['oversized', 'multiple-goals']
deferred: []
---

<intent-contract>

## Intent

**Problem:** Interoperability has no OcuPilot screen or tool for the classic Suspended Messages page (`EnsPortal.SuspendedMsg`), so a suspended message can be neither listed nor resubmitted, edited and resubmitted, discarded or deleted, and nothing round-trips over `Ens.MessageHeader`.

**Approach:** Batch 2 of four (Batch 1's veto item 1): one **Suspended messages** list through `InteropPort`, with four writes, each one operation reached by the screen and by the agent, extending Story 20.31's resend family (AD-62 item 17). "Round-trips" means: a write from either caller leaves each reviewed header as `Ens.MessageHeader` then reads (resubmitted under its own id and processed by the running production, Discarded, or gone), and the list reads the change.

## Boundaries & Constraints

**Always:**

- **One port (AD-62).** `InteropPort` gains `SuspendedMessages`: `LIST` (`SELECT TOP 2000 ... WHERE Status = 5 ORDER BY ID DESC`, `%ExecDirectNoPriv` after the gate, truncation reported, AD-36), rows `{ID, TimeCreated, SessionId, Error, Type, Source, Target, BodyClass}`; the reads `RESUBMIT`, `EDITSUBMIT`, `DISCARD`, `DELETE` and the writes `RESUBMITMESSAGES`, `EDITRESUBMIT`, `DISCARDMESSAGES`, `DELETEMESSAGES`. Switched, no `OcuPilot.*` call while switched.
- **Vendor calls.** Resubmit: `Ens.MessageHeader.ResubmitMessage(id)`; edit-and-resubmit: `ResubmitMessage(id, "", clone)` with the clone Story 20.31's `EditCloneHere` builds; discard: `%OpenId`, `SetStatus(4)`, `%Save`, as the classic `DiscardMessage`; delete: as the classic `DeleteMessage`, the body by `%DeleteId` and `Ens.SearchTableBase.RemoveSearchTableEntries(class, id, 1)` only when no other header names it and its class is persistent or a stream whose `ENSPURGE` is not 0, then the header by a bound `DELETE FROM Ens.MessageHeader WHERE ID = ?`.
- **Selection (AD-21, AD-51).** Ids arrive as `Messages`, checked by `MessageSet` (at most 100, refused beyond, never truncated; ascending; each bound, never composed); edit-and-resubmit takes one id. Each message is judged before any vendor call, first rule wins: `gone`; `notsuspended` (status is no longer Suspended: the vendor checks none); for resubmit and edit only `nobody` and `targetoff` (Story 20.31's rules); else the action's own verdict. A write acts on exactly the reviewed members in ascending id order and continues past a vendor failure; a person's write carries the reviewed digest, refused when the verdicts moved.
- **Gate (AD-29, AD-8), before any vendor call; never cached.** List: `%Ens_Portal:USE`, `%Ens_MessageHeader:USE` (the classic `RESOURCE`), then `Admit`. Resubmit: plus `%Ens_MessageResend:USE`; edit-and-resubmit: plus `%Ens_MessageEditResend:USE` and the pairs Story 20.31's edit composes; discard and delete: plus `%Ens_MessageDiscard:USE` (the classic page gates both by it); every write plus WRITE on the namespace's globals database, and any pair Task 0 (f) measures.
- **Preconditions and refusals by name.** Resubmit and edit refuse a stopped production (`INTEROP.PRODUCTION.NOTRUNNING`); a selection with no actionable member is 409 `INTEROP.SUSPENDED.NONE`; a moved review 409 `INTEROP.SUSPENDED.CHANGED`; edit refusals are Story 20.31's `INTEROP.EDIT.*`.
- **Writes (AD-3, AD-6, AD-10, AD-14, AD-22, AD-34, AD-51, AD-53, AD-56, AD-58, AD-59).** `interop.suspendedmessages.resubmit`, `.editresubmit`, `.discard`, `.delete`; action-style, `DRYRUN`; resubmit, edit-and-resubmit and delete `DESTRUCTIVE` with keys `false`, discard not destructive with key `true` (Design Notes 2). A script form per tool (AD-59), every id shape-checked, rendering nothing when one fails. A screen action mints nothing and is not gated by read-only or the kill switch.
- **Namespace at confirm (AD-52).** Each stored proposal carries `Namespace`; every confirm-time judgment (the fresh read, the verdicts, the production state, the vendor call) runs there, whichever namespace the confirm is sent from.
- **Audit (AD-15).** The agent's marker on every agent write. Resubmit and edit carry the vendor's own resend event (Task 0 (b) names it) and no row of OcuPilot's. Discard and delete record OcuPilot's own `ConfigChange` from either caller through `AuditRuntime`, naming the namespace, the action and the ids done and failed.

**Never:**

- Discard All, Delete All or any background job (`%RunBackgroundMethod`, `JOB`, `%SYSTEM.WorkMgr`); `^IRIS.Temp.PurgeSuspendedMsgs`; any `EnsPortal.*` call; `Ens.Util.Purge.SuspendTransaction` or `Ens.Util.BitmapPurge`; a write on a header that is not Suspended.
- A message body's text in a log line, audit row or the model's context beyond Story 20.31's edit read; a vendor status text in a log.
- Export and the archive manager (Batches 3 and 4); a README or spine edit; a new entity type.
- `src/OcuPilot/Api/Error.cls` (frozen); `ui/angular.json`; `ui/vitest-base.config.mjs`; `scripts/ci-throwaway.sh` beyond one add-only roster block, never its bring-up retry block; `Prohibited.cls` beyond appended terms.

## I/O & Edge-Case Matrix

Route namespace USER, where the probe production (`ProductionProbe`, `InteropResendFixture.Prepare`/`Start`) runs; suspended probes are stored requests to `OcuPilotProbeOp` set to Status 5. HSCUSTOM holds its own Status-5 probes (`InteropPurgeFixture.Header`, marker `OcuProbe2416`), no production.

| Scenario | Input / State | Expected | Error |
|---|---|---|---|
| List | Three suspended probes, one Completed | The three listed, not the Completed one | - |
| Resubmit, both callers | Two suspended probes | Same ids, no longer Suspended, Completed once processed; vendor audit rows | - |
| Edit, both callers | One suspended string request, field changed | Same id, a new body holding the change; the old body unchanged | - |
| Discard, both callers | Two suspended probes | Status Discarded, bodies kept; one `ConfigChange` each | - |
| Delete, both callers | Suspended probes, one sharing its body with a Completed header, one an HL7 body indexed in `EnsLib.HL7.SearchTable` | Headers gone; the unshared body and its search-table rows gone; the shared body kept; `ConfigChange` | - |
| Verdicts | A deleted id, a Completed id, a body gone, a target disabled, beside one actionable | Only the actionable acts; each line names its verdict | - |
| None | Only non-actionable ids | Nothing changes | 409 `INTEROP.SUSPENDED.NONE` |
| Moved | Status changed after the person's review | Nothing changes | 409 `INTEROP.SUSPENDED.CHANGED` |
| Stopped | Resubmit with the probe production stopped | Nothing changes | 409 `INTEROP.PRODUCTION.NOTRUNNING` |
| Over 100 | 101 ids | Refused whole | 400 `PORT.VALIDATION` |
| Gate | Each write without its action resource; without database WRITE | Refused before any vendor call | 403 naming the pair |
| Confirm elsewhere | Each of the four minted in USER, confirmed with `?ns=HSCUSTOM` | Acts in USER only; HSCUSTOM's probes still Suspended | - |
| Script | Each tool's draft | Renders the switch and the vendor calls, runs nothing; a bad id renders no draft | - |

</intent-contract>

## Code Map

Paths under `/Users/jbrandt/git/OcuPilot/.worktrees/epic-24` (HEAD `a4f7a1fec`). **Epic 21 contention** (`git log --no-merges origin/OCU-1-epic21 ^origin/feature/OCU-1_ocupilot-mvp`, at plan): `Baseline.cls`, `EntityType.cls`, `Prohibited.cls`, the client shell and core files below, `strings.ts`, `screens.generated.ts`, `screen-mirror.test.mjs`, `navigation.test.mjs`, `ci-throwaway.sh`, `EXPERIENCE.md` and the test rosters marked (c): add-only edits there. `InteropPort.cls`, `InteropError.cls`, the resend tools and fixtures are uncontended. Re-check before editing.

- **`Port/InteropPort.cls`** (extend Story 20.31's family, Rule 2): types and pairs :620-656, `COMPOSEDTYPES` :323, `IsMessageWrite`/`IsMessageType` :1142/:1148, `IsAnyWrite` :1189, `Pairs` :1278-1279, `Serves` :1309, `Invoke` :3823, `ListMessages` :4601 (the list's sibling), `MessageSet` :5203, `MessageVerdict` :5222 and `JudgeMessages` :5293 (add a type argument; `HeaderFacts` :6149 already reads `Status` :6169), `RunningProduction` :5266, `ResendDigest` :5237, `ReadResend` :5338, `VendorResend` :5364 (seam to generalise into a per-type vendor call), `PerformResend` :5389 (the loop), `ReadEdit` :5597, `EditCloneHere` :5780, `VendorResendWithBody` :5853, `InvokeMessageAction` :5910, `MessageSnippet` :5957, `AuditRuntime` (Batch 1's purge audit, the sibling).
- **`Api/InteropError.cls`:** `SUSPENDEDNONE`, `SUSPENDEDCHANGED`, consequences `SUSPENDEDRESUBMIT`, `SUSPENDEDEDIT`, `SUSPENDEDDISCARD`, `SUSPENDEDDELETE`, verdict and outcome words beside :650-712; a `SuspendedCodes` list joined into `Codes` :715 and `ConsequenceCodes` :721; `ReasonFor` arms; `VerdictSentence` :901.
- **Vendor (read-only, at plan):** `irislib/EnsPortal/SuspendedMsg.cls` (`RESOURCE` :15, flags :18-27, hyper-event resources :747-754, `InitQuery` :85-92, Resubmit :153-174, Discard :248-282, `DeleteMessage` :446-528, the All jobs :318-383, :532-678); `irislib/Ens/MessageHeader.cls` (`ResubmitMessage` :377-389, `PrepareResubmitMessage` :391-421, `SetStatus` :140-177, `OnDelete` :745-751); `irislib/EnsPortal/MessageResendEdit.cls` :190-252 (`SUSP=1` calls `ResubmitMessage`); `irislib/Ens/SearchTableBase.cls` :166. None checks a privilege; resubmit audits through `$$$AuditResendMessage`; discard and delete audit nothing; resubmit keeps the header id and re-enqueues without checking the status (inference, no check found).
- **Tools (new, `Screen/Tool/`):** abstract `InteropSuspendedAction` extending `InteropMessageAction` (:13; shares `PortQuery`, `DryRunReview`, `MergeUpdate`, `MessageLine`, `WriteOutput`, made to take the action's outcome words) with `Endpoint` `SuspendedMessages`; `InteropSuspendedResubmit`, `InteropSuspendedDiscard`, `InteropSuspendedDelete` modeled on `InteropMessageResend` (its `SetProblem`, `MintClass`, `ScreenActionDelta`, `StateDiff`; a shared mint generalising `InteropMessageResendMint`); `InteropSuspendedEditResubmit` extending `InteropMessageEditResend` (overrides `TOOLNAME`, `DESCRIPTORCLASS`, `READTYPE`, `WRITETYPE`, `CLASSICPAGES`, `CONSEQUENCECODE`).
- **Descriptor (new):** `Screen/Descriptor/InteropSuspendedMessageList.cls`, modeled on `InteropMessageList.cls`: route `interoperability/suspended-messages`, side bar 18, `list`, scope `namespace`, entity type `interop-message` (shared), row actions `resubmit`, `editresubmit`, `discard`, `delete` (destructive last), `multiSelect {"action": "resubmit", "max": 100, "extraActions": ["discard", "delete"]}` (as `ExplorerClassList` :93), `classicPage` `EnsPortal.SuspendedMsg`, `toolIdentifier` `interop.suspendedmessages`, `paging` `cap`.
- **Kernel:** `Kernel/Governance/Baseline.cls` (c) four keys after :280. No `EntityType.cls` change; `Prohibited.cls` (c) appended terms only if the `Prohibited` test asks.
- **Client (`ui/src/app/`):** `areas/interoperability/interop-suspended-message-list.page.ts` wrapping `<app-list-page />` as `interop-purge-list.page.ts` does, registering `editresubmit`; the header page's edit flow (`interop-message-header.page.ts` `onEdit` :185, `onReview` :221, `InteropItemTestDialog`) moved into a shared `message-edit-flow.ts` both pages use; `shell/screen-action-handler.ts` (c) (`DRY_RUN_ACTIONS` :491, `CHECKED_SET_DIALOGS` :513, page actions :649, `ACTION_ADDRESS` :709, `DESTRUCTIVE_ACTIONS` :723, consequences :881, `openReview` :1864 generalised from `interopResendVerdictResend` to the action's verdict, `DRY_RUN_SENTENCES` :2162); `core/screen-actions.ts` (c) :157; `core/proposal-view.ts` (c) :561/:799; `shell/screen-outlet.ts` (c) :285; `core/strings.ts` (c) after :7846; regenerate `screens.generated.ts` and `Screen/Titles.cls`.
- **Tests (new, armed by `OCUPILOT_ALLOW_PRINCIPALS`, one `# classes:` block after `scripts/ci-throwaway.sh` :605):** case `Test/InteropSuspendedCase.cls` extending `InteropResendCase` (its high-water sweep, `Prepare`, `Start`, `Settle`, `Remove`, `Gone`) plus HSCUSTOM probe cleanup through `InteropPurgeFixture.DropProbes`; `InteropResendFixture.Suspend(pId)` added (Status 5); classes `InteropSuspendedList`, `InteropSuspendedResubmit` (resubmit and edit), `InteropSuspendedRemove` (discard and delete, audit, search table), `InteropSuspendedRefusals` (verdicts, none, moved, stopped, 101, gate as principals), `InteropSuspendedElsewhere` (the four cross-namespace confirms), each under 500 lines; a seam extending `InteropResendSeam`. Browser `ui/browser/interop-suspended-messages.browser-spec.mjs` modeled on `interop-message-resend.browser-spec.mjs` (`probe()` :62, `before` :225, `after` :238); a component spec for the page.
- **Rosters (Rule 30; re-grep `interop.messages.resend`, `InteropMessageResend`, `interop-purge` across `src/OcuPilot/Test`, `ui/tools`, `ui/browser`, `ui/src`, `scripts/`):** `ConfirmNamespaceRoster` `CHECKEDFLOOR` 120 → 124; `DraftRegistry` `ARGUMENTVALUES` :71 only if its draft leg needs a `Messages` value; `ToolWrite` (c), `Descriptor` (c, screen rows), `SurfaceCoverage` (c) :614, `StageTwoTools` (c), `InteropFloor`, `GovernanceBaseline.DISABLED` (c) :15, `Governance` (c) :66, `ReadTool` (c) :94, `ToolRoundTrip` (c) :116, `ToolEmit` (c) :343, `ClassicPageGate` :76/:100, `MappingDescriptor` :24, `DryRunRoute` :24-26, `InteropDescriptor`, `ui/tools/interop.test.mjs` :155-166 (sentence rows), `ui/tools/screen-mirror.test.mjs` (c). Both writes reach `POST /screens/:screen/action` and `/dryrun`, so no new route.
- **EXPERIENCE.md** (c): one Fixed strings row after the Batch 1 purge row, once the strings are ruled.

## Tasks & Acceptance

**Execution:**

- [ ] **Task 0** (`ocupilot-b-ci`, USER and HSCUSTOM, auditing on; the probe production brought up as the tests do, `ProductionProbe.HighWater()` recorded, `InteropResendFixture.Prepare` and `Start`, and ended with `Settle`, `SweepSince(<mark>)` reading `0|0`, `Remove` and `Gone()`; HSCUSTOM probes dropped by marker; probe roles and users removed; record under Design Notes, Measured): (a) a message the probe production suspends itself (an operation answering an error under `ReplyCodeActions` `E=S`) stores what a fixture Status-5 header stores, with no queue entry, and the running production leaves it alone; (b) resubmit in the running production: the same id, the status path, the body, `Description`, the vendor's audit event name; with the production stopped, the target disabled, a non-suspended header and a suspended response, what the vendor answers and does; (c) edit-and-resubmit: the same id, a new body id, the old body kept; (d) discard: status 4, body kept, no audit row, no queue change, and a later resend from Messages works; (e) delete: the header, the unshared body and an HL7 search-table row gone, a shared body kept, no audit row, and whether `%DeleteId` differs from the bound `DELETE` (the trigger); (f) a principal with `%Ens_Portal:USE`, `%Ens_MessageHeader:USE`, the action's resource and `%DB_USER:RW` does each action, and whether any SQL privilege is needed; (g) `$USERNAME` and `$ROLES` read the same after each vendor call. HALT if a read writes, if (d) or (e) finds a vendor audit row, if a vendor call escalates, or if a consequence sentence measures untrue (`intent gap: new string`).
- [ ] `InteropPort.cls`, `InteropError.cls`: the endpoint, its gate, list, verdicts with a type argument, the four writes through one generalised loop, snippets, codes.
- [ ] The five tool classes, the descriptor, the baseline keys.
- [ ] Client: the page, the shared edit flow, the handler maps, strings, the regenerated mirror and titles, the EXPERIENCE.md row.
- [ ] Tests: the matrix in the five classes, case, fixture method and seam; the browser and component specs; the rosters the sweep names.

**Acceptance Criteria:**

- **AC1 (list).** Given suspended and completed probes in USER, when a person opens Suspended messages and the agent reads it, then each lists exactly the suspended probes, newest first.
- **AC2 (resubmit and edit, both callers).** Given suspended probes and the running probe production, when a person and the agent's confirmed proposal each resubmit, and each edits and resubmits one, then each header keeps its id, leaves Suspended and is processed, an edited one carries a new body with the change and the old body is unchanged, and the vendor's audit rows are written.
- **AC3 (discard and delete, both callers).** Given suspended probes, when each caller discards and deletes, then the discarded read Discarded with bodies kept, the deleted are gone with their unshared bodies and search-table rows, a shared body is kept, and each write has OcuPilot's `ConfigChange`.
- **AC4 (refusals and gate).** Given each refusal row of the matrix, when either caller writes, then the named code or verdict answers before any vendor call and nothing changes.
- **AC5 (the proposal's namespace; Integration, Rule 1).** Given suspended probes in USER and HSCUSTOM, when each of the four agent writes is minted in USER and confirmed from HSCUSTOM, then it acts in USER only and HSCUSTOM's probes stay Suspended.
- **AC6 (browser).** Given a fresh instance with the probe production, when a person resubmits one and deletes another on the screen, then the list drops both and the outcome names each.
- **AC7 (fresh, either order).** Given any new or changed test, run first on a fresh instance in either order, when it ends, then no probe header, body, item or production remains in either namespace.

## Spec Change Log

- 2026-11-22, spec gate (runner, veto item U-147): Design Notes 1 to 6 kept as recommended. The four consequence sentences are provisional until Task 0 measures them true on `ocupilot-b-ci` with the probe production; a sentence measured untrue, or a vendor call that changes `$ROLES`, HALTs `blocked` with an intent gap.

## Review Triage Log

## Design Notes

**Veto items (recommended option first).**

1. **One screen with four writes, three on the checked rows** (`multiSelect` with `extraActions`) and edit-and-resubmit on one row, as the classic ribbon; no Discard All or Delete All (the classic page's background jobs). Alternative: a write per screen.
2. **Resubmit, edit-and-resubmit and delete are destructive with keys `false`; discard is not, key `true`.** Resubmit delivers the message, which no opposite proposal recalls, as Story 20.31's resend keys (AD-22); delete removes records; discard keeps the header and body and the message can still be resent. Alternative: every key `true` behind its confirmation.
3. **Delete and discard need `%Ens_MessageDiscard:USE`**, as the classic page; no stricter pair for delete.
4. **Only a Suspended header is written** (`notsuspended`): stricter than the vendor, which resubmits and deletes any header, equal to the classic page's rows.
5. **The delete keeps journaling on and runs no bitmap purge**, unlike the classic `DeleteMessage`; Purge management data covers bitmap cleanup.
6. **Proposed strings** (reused, each read true here: "Delete" (`actionDelete`), the Messages columns' keys (`interopColumnId`, `journalColumnCreated`, `webSessionColumnSession`, `errorLogColumnText`, `tableColumnType`, `auditEventFieldSource`, `agentLedgerColumnTarget`, `interopColumnBodyClass`), the verdicts `interopResendVerdictGone` "no longer exists", `interopResendVerdictNobody` "its body no longer exists", `interopResendVerdictTargetOff` "its target is not an enabled item of the running production"; the column keys are `InteropMessageList`'s own, and `actionDelete` is `strings.ts` :120):
   - Labels: "Suspended messages" · "Resubmit" · "Edit and resubmit" · "Discard".
   - Verdicts: "is no longer suspended" · "will be resubmitted" · "will be discarded" · "will be deleted". Outcomes: "resubmitted" · "not resubmitted" · "discarded" · "not discarded" · "deleted" · "not deleted".
   - Consequences (provisional until Task 0): `SUSPENDEDRESUBMIT` "Resubmitting puts each message marked to be resubmitted back on its target's queue under its own message id, and the running production processes it. It cannot be undone." · `SUSPENDEDEDIT` "Edit and resubmit saves the edited body as a new copy and puts the message back on its target's queue with it, under its own message id. The original body is kept. It cannot be undone." · `SUSPENDEDDISCARD` "Discarding marks each message marked to be discarded as Discarded, so it is no longer suspended and is not processed. The message and its body are kept, and it can still be resent from Messages." · `SUSPENDEDDELETE` "Deleting removes each message marked to be deleted, its body when no other message uses it, and its search table entries. It cannot be undone."
   - Refusals: `NONE` "None of these messages can be acted on now. Each one's line says why." · `CHANGED` "These messages changed after they were reviewed, so nothing was changed. Review them again."
   - Empty state: "No suspended messages in this namespace." (agent phrase "resubmit or discard suspended messages").
   - Prompts: "Which messages are suspended here, and why?" · "Which target has the most suspended messages?" · "Resubmit the suspended messages whose target is running."

**Proposed spine lines for story end (the orchestrator writes them, add-only; never here).** AD-62 item 20: "**Suspended messages** (Story 24.16). `InteropPort` gains `SuspendedMessages` over `Ens.MessageHeader` rows with Status Suspended (at most 2,000, newest first), behind `%Ens_MessageHeader:USE`, and four action-style writes on at most 100 reviewed ids, each judged before any vendor call and acting only on a header still Suspended: resubmit (`ResubmitMessage`, `%Ens_MessageResend:USE`), edit-and-resubmit (Story 20.31's clone, `%Ens_MessageEditResend:USE`), discard (`SetStatus`) and delete (body, search-table rows and header as the classic page, journaling on), both behind `%Ens_MessageDiscard:USE`. No Discard All or Delete All job." AD-22: "**Story 24.16's Batch 2 keys:** `interop.suspendedmessages.resubmit`, `.editresubmit` and `.delete` ship `false`; `.discard` ships `true`." AD-15, named case: "**Suspended message discard and delete** (Story 24.16), which the vendor does not audit, record OcuPilot's own `ConfigChange` from either caller."

**Decided in-stage (plan).**

1. Epic context reused as committed (dispatch instruction); the spine's AD-62, AD-22, AD-52 and AD-59 and Batch 1's spec were read directly.
2. The entity type is the existing `interop-message`: the ids are message header ids, and `MessageSet` already normalizes them.
3. Newest first (`ORDER BY ID DESC`), as Messages; the classic query orders nothing.
4. Suspended state is `Status = 5` alone: `^Ens.Suspended` holds a stopped production's queues, not suspended messages (vendor read at plan).
5. Tests make suspended probes as stored requests set to Status 5 under a running probe production (USER), and Task 0 (a) checks that equals a genuinely suspended one; HSCUSTOM's probes need no production.
6. Siblings (Rule 31): `InteropMessageAction`/`InteropMessageResend`/`InteropMessageEditResend` and the resend port family (tools, port), `InteropMessageList` (descriptor), `interop-purge-list.page.ts` (page), the header page's edit flow (shared, not copied), `InteropResendCase`/`InteropResendFixture`/`InteropResendSeam` (tests), Batch 1's `AuditRuntime` row (audit).
7. Side-bar position 18, after Purge data settings.

**Governing ADs (Rule 6):** AD-3, AD-6, AD-7, AD-8, AD-10, AD-11, AD-13, AD-14, AD-15, AD-16, AD-21, AD-22, AD-29, AD-34, AD-36, AD-44, AD-51, AD-52, AD-53, AD-56, AD-58, AD-59, AD-60, AD-62 (items 1-5, 15, 17). Not engaged: AD-9 (no `$ROLES` frame unless Task 0 (g) finds an escalation, which HALTs), AD-23, AD-35, AD-54, AD-63, AD-65, AD-66.

**Integration and linkage (Rules 1, 2).** Integration: AC5 (the kernel's confirm consumes each stored proposal in its own namespace) and AC1's agent leg (the derived read tool). Consumes: `InteropPort`'s resend family, `InteropMessageAction`, `InteropMessageEditResend`, Batch 1's `InteropPurgeFixture` probes, `ProductionProbe`, the kernel's proposal, confirm, governance and audit. Consumed-by: Batch 3's export reuses the selection and `MessageSet`; Story 24.20's undo names these writes as not restorable.

**Ledger inbox (Rule 17):** `LEDGER slice 24-16-...` empty at plan; `owned_ledger=0`.

## Verification

**Commands** (one `ci-runner` call per message; `ocupilot-b-ci` only):

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.InteropSuspendedList`, then likewise `InteropSuspendedResubmit`, `InteropSuspendedRemove`, `InteropSuspendedRefusals`, `InteropSuspendedElsewhere`, `InteropResend`, `InteropEditResend`, `ConfirmNamespaceRoster`, `DraftRegistry`, `GovernanceBaseline`, and every class the roster sweep changes. Expected: green; new classes green on their first run.
- `(loop)` `cd ui && npm run test:tools && npm run test:components`. Expected: green.
- `(loop)` `cd ui && npm run build`, `docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`, then `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci node --test --test-concurrency=1 browser/interop-suspended-messages.browser-spec.mjs browser/interop-message-resend.browser-spec.mjs`. Expected: green.
- `(once)` The full ObjectScript sweep, `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --shard k/17` for k = 1 to 17, one call each. Expected: green. The full browser suite is left to CI.
- `uv run scripts/check-objectscript.py` and `bash scripts/lint-docs.sh`. Expected: clean.

**Shared surfaces:** the Interoperability side bar; the governance baseline; the read-tool, coverage, draft, dry-run, classic-page, confirm-namespace and write rosters; `InteropError`'s code lists; `interop.test.mjs`'s sentence rows; `screen-mirror.test.mjs`; the arming roster; the header page's edit flow; USER's probe production and message store; HSCUSTOM's message store.

**Hermeticity:** every test added or changed passes on its first run on a fresh instance, in either order; it makes its own probes, asserts on them by id or marker, and leaves no header, body, item or production behind (the case's high-water sweep in USER, `DropProbes` in HSCUSTOM).

**Mutations** (each AC's pinning test shown red on `ocupilot-b-ci`, `src` reloaded with subclasses and reverted byte-identical; the client one on a rebuilt, redeployed bundle), recorded here by the implement stage as `mutation: <change> -> <test red>`, one per AC. Planned: AC1 the list's `WHERE` without the status -> `InteropSuspendedList` red; AC2 `ResubmitMessage` given the clone's original body -> `InteropSuspendedResubmit` red (the edit leg); AC3 the delete removes a body another header names -> `InteropSuspendedRemove` red (the shared-body leg); AC4 the `notsuspended` rule removed -> `InteropSuspendedRefusals` red; AC5 a tool's `FINGERPRINTSUBJECT` without `Namespace` -> `InteropSuspendedElsewhere` red; AC6 the page sends the discard action for Delete -> the browser spec red; AC7 the case's HSCUSTOM `DropProbes` skipped -> `InteropSuspendedElsewhere`'s after-all check red.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none

**Plan.** Batch 2 of four: Suspended messages through `InteropPort`, four writes (resubmit, edit-and-resubmit, discard, delete) on at most 100 reviewed ids, each reached by the screen and the agent, extending Story 20.31's resend family; every proposal keeps its namespace and every confirm judges there. Veto items: Design Notes 1 to 6. Read-only checks on `ocupilot-b-ci` (port 52777, image `irishealth-community:2026.2`): no production runs in USER or HSCUSTOM and neither holds a suspended message, so the tests bring up `ProductionProbe` in USER and remove it. Nothing was written to the instance.
