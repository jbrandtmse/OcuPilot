---
title: 'Story 23.7: The range-end cleanup, part 6'
type: 'bugfix'
created: '2026-10-21'
status: 'done'
baseline_revision: '1b56201ae2c0aba42a8c12ef6f5a77a32be9f52a'
baseline_commit: '1b56201ae2c0aba42a8c12ef6f5a77a32be9f52a'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
warnings: ['multiple-goals', 'oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** This story owns twelve medium-severity ledger entries. They cover test gaps and contract mismatches in four areas: the proposal and conversation kernel; the gates, ports and agent ledger; the error copy; and the provider test fixtures. Checked at `f0ec693f`, three entries are live defects:

- a bad-body sentence tells the caller to send no body, on routes that refuse an absent body;
- the violation router answers no sentence for two field codes;
- two mints put a raw U+0001 in their refusal text.

The other nine are behaviors that no test can fail on, or a duplicated fixture.

**Approach:** Four area batches, in this order:

1. Proposal and conversation kernel.
2. Gate, port and ledger.
3. Errors and copy.
4. Provider test fixtures.

Each batch is one implement pass and one code commit, with CI green on its own head. Each entry gets a pinning test that reddens under a named mutation of product code, or a fix whose test reddens before it (Rule 19). The verdict and action for each entry are in Design Notes.

## Boundaries & Constraints

**Always:**

- **Where to work.** Work in `/Users/jbrandt/git/OcuPilot/.worktrees/epic-23` on `OCU-1-epic23`, and check `git rev-parse --show-toplevel` first. Every IRIS MCP call carries `server: "ocupilot-slot-a"`.
- **Where tests run.** Tests, probes and mutations run only on `ocupilot-ci` (52776/1975), and only once `docker inspect -f '{{.State.Health.Status}}' ocupilot-ci` reads `healthy`.
  - Keep one test run in flight, and wait for each to appear in `%UnitTest_Result`.
  - Never re-submit after a client-side timeout.
  - Run every command in the foreground with `timeout: 600000`.
- **Batches.** One implement pass per batch. The lead integrates forward from the feature branch, re-opens the spec for each batch and scopes the pass to that batch's unchecked items. A red batch is reopened alone.
- **Locating code.** Find code by method name. The line numbers below are at `f0ec693f`.
- **What may change.** Wire codes and HTTP statuses stay byte-identical. Only the reasons and problem texts in the I/O matrix's CHANGED rows change.
- **Writing code.** Extend the sibling named under Design Notes (Rule 31). Comments state the contract (Rule 14). Write non-ASCII in source as `$Char(n)`.
- **Before editing `src/OcuPilot/Api/Error.cls`.** Re-run the two read-only Epic 20 checks under Design Notes › Contended files. If Epic 20's hunks have moved next to this story's lines, stop and report.

**Never:**

- A 22nd rule in `scripts/check-objectscript.py`. Its count is pinned in `CLAUDE.md` and in its harness.
- Any edit to `CLAUDE.md`, `.claude/**`, `_bmad/**`, `scripts/ci-throwaway.sh` or `.github/workflows/ci.yml`.
- A new or reworded error `code`.
- A write, load or compile on the `ocupilot` dev instance.
- The full ObjectScript sweep (the lead runs it) or the full browser suite (CI runs it).
- Anything inside the epic-20 worktree beyond the two read-only git checks.
- A process-level `$ZTIMEZONE` change used to simulate a time zone. Measured on `ocupilot-ci`: it moves `$H` but not the `-3` conversions.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| CHANGED: absent body where one is required (DW-1170) | `POST /api/ocupilot/license/key/validate`, no body | 400 `AGENT.BADBODY`, reason "The request body is missing or is not the JSON object this request expects." (or the wording the lead rules at the spec gate) | Today the reason ends "Send a JSON object, or no body at all." |
| CHANGED: unreadable body where none is required | `POST /api/ocupilot/agent/definitions`, body `{not json` | 400 `AGENT.BADBODY` with the same new reason | — |
| Unchanged: absent body where none is required | `POST /api/ocupilot/agent/definitions`, no body | 422 `AGENT.VALIDATION`, as today | — |
| CHANGED: DocDB field codes through the router (DW-1377) | `Error.ReasonForViolation("DOCDB.NAME.INVALID")`, `("DOCDB.NAME.MAPPED")` | `DocDbError.ReasonFor`'s sentence for each code | Today both answer `""`. The wire already carries the sentence, because `DocDbPort` and `DocDbSave` pass it themselves. |
| CHANGED: absent composite id (DW-2266) | A `tasks.background.cancel` mint with source `Management Portal` and id `999999999`; an encryption key-file tool on an absent file | 400 `TOOL.ARGUMENTS`. `detail.problem` reads `'Management Portal › 999999999' is not present on this instance`: the parts are joined by ` › ` (U+203A) and there is no `$Char(1)`. | Today the parts are joined by a raw U+0001. |
| Unchanged: mints that are already readable | Superserver, ErrorDelete and WebAppPctAccess presence refusals, and Mapping's (with its subclasses) | Same text as today | — |
| Unchanged: ledger times (DW-1783) | Any conversion between UTC and local time on this instance | `LocalFromUtc` and `LocalToUtc` answer exactly what the `-3` forms of `$ZDateTimeH` and `$ZDateTime` give today | — |
| Pinned, unchanged: retention gap (DW-1233) | Retention has removed a conversation's seq-1 entry; seq 2 and seq 3 each have a proposal | `GET /conversation/:id` answers 200. `turns[0]` (seq 2) carries only its own proposal, and `turns[1]` (seq 3) only its own. | — |
| Pinned, unchanged: unreadable proposal store (DW-1234) | One of the conversation's proposals has a target reference that cannot be parsed | 200 JSON. Every turn's messages are intact and its `proposals` is `[]`. | The read logs the failure. No 500. |

</intent-contract>

## Code Map

### Kernel (batch 1)

- `src/OcuPilot/Api/Conversation.cls` (read-only), `AttachProposals` (:110):
  - store read at :116;
  - degradation `Kill tByTurn` at :119;
  - the seq join `tKeys(+tTurn.%Get("seq"))` at :129.

  `HandleRead` is routed at `Router.cls:1131` (`GET /conversation/:id`).
- `src/OcuPilot/Kernel/State/Entry.cls` (read-only):
  - `GuardedAppend` (:104) sets `Seq` to `MAX(Seq)+1` (:108-112).
  - `GuardedTurnKeys` (:259) subscripts by `Seq` (:265).
  - `GuardedPurge(.pCutoffs, .pRemoved)` (:279): when the top node is undefined, it purges only entries whose `DefinitionId` is subscripted.
- `src/OcuPilot/Kernel/State/Propose.cls` (read-only):
  - `GuardedRowsForConvo` (:772) fails the whole read when `WireRow` cannot parse a row's target (`EntityRef.Parse`, :880).
  - `GuardedMint` only length-checks `targetRef` (:283).
  - Also used: `GuardedCloseLiveForConvo` (:651) and `GuardedDeleteForTurn` (:808).
- `src/OcuPilot/Api/Turn.cls` (read-only): `HandleStart` closes the conversation's live proposals (`REASONMESSAGE`) at :172-176, before `Job.Start`.
- `src/OcuPilot/Test/ConversationRestore.cls` (75 lines, unarmed). Extend it: it owns its conversation as `Test.Http.GetTestUsername()` and reads `GET /conversation/:id` over HTTP. Helpers to use:
  - `Test.Http.AbsoluteRequest` (`Http.cls:207`), which answers `pHeaders("CONTENT-TYPE")`;
  - `Test.ProposalFixture.SeedProposal` (:342) and `.Field` (:413);
  - the value shape in `ProposalClose.Seed` (`ProposalClose.cls:51-68`).
- `src/OcuPilot/Test/TurnConversation.cls` (449 lines; armed by `OCUPILOT_ALLOW_PRINCIPALS` and by the provider variable; on both rosters). Extend it with `NewConversation` (:86), `Start` (:93) and `AwaitEnd` (:100).
- `src/OcuPilot/Test/ProposalClose.cls:145` already drives `Api.Conversation.HandleCreate`'s close at the handler.
- `src/OcuPilot/Test/TurnWire.cls:201-204`: this doc paragraph says `Seq` is `COUNT(*) + 1` and that no fixture can force the two joins apart. Both claims are wrong.
- `src/OcuPilot/Test/ToolWrite.cls:297-307`: `TestNoPathFromAWriteToolsViewReachesTheClaimGate`, the five-file scan. No roster references it.
- `src/OcuPilot/Test/AsTheUser.cls:160`: `SitesNaming(pToken, pPrefixes, pIncludeTests)`.
  - It answers every compiled `OcuPilot.*` class whose stored source names the token, ignoring case. Tests are excluded by default.
  - It reports a source it cannot read; it never counts it as no match.
- **The claim.** The claim symbols are `Kernel/Proposal/Write.cls` `Claim` (:126) and `ClaimById` (:181), and `Kernel/State/Propose.cls` `GuardedClaimAndClose` (:523).
  - Product code names them only at `Kernel/Proposal/Confirm.cls:166` and `:415`.
  - `Kernel.Proposal.Confirm` is called only by `Api/Confirm.cls:43,63` and `Install/Smoke.cls:1488,1624`.

### Gate, port and ledger (batch 2)

- `src/OcuPilot/Port/ProviderPort.cls` (read-only):
  - `Invoke` (:107) gates at :118 through `GateAnyOfForUser` (:535, private). Any one pair admits; an empty or unreadable set admits nobody.
  - The pair set is `InvokePairs()` (:595): the floor pairs, from `Screen.Gate.FloorPairSpec`. Each pair is answered by `HoldsPairForUser` (:564, `CheckUserPermission`).
  - A refusal is `RefusePair` (:578), which answers `Kernel.Denial`'s status, code, reason and detail.
  - `Screen.Gate.EvaluateAnyOf` no longer exists.
- `src/OcuPilot/Test/InteropFloorTurn.cls` (148 lines; armed; on both rosters). Extend it.
  - It creates `TurnWireFixture.USERA` with `Resources(0)` plus `INTEROPGRANT`. That grant includes `%Ens_Portal:U`, the floor's last member.
  - It reads `USERA` back through `InteropFloorFixture`.
  - `TurnWireFixture.EnsurePrincipal` (:77), given no second resources, grants only `ROLE`.
- `src/OcuPilot/Port/AdminPort.cls` (read-only):
  - `MUTATINGTYPES` (:492), `IsMutating` (:2941), `HttpMethodFor` (:3357, private), `EndpointType` (:3373, private) and `EndpointClass` (:1579).
  - **Already pinned.** `ToolWrite.TestEveryWriteToolsRequestTypeAgreesWithThePortsBodylessRoster` pins the roster and the 501 refusals of `Process/DELETE` and `Device.Settings/PUT`. `AdminPortAsync` pins more.
  - **Not pinned.** `HttpMethodFor` has no direct pin.
  - **Test seams of the same kind.** `Test/RoleDeletePort.cls` and `Test/AsTheUserProbe/Port.cls`. `Test/PortFixture.cls` overrides `MUTATINGTYPES`, so it cannot see a mutation of the shipped list.
- `src/OcuPilot/Test/DenialParity.cls` (285 lines; armed).
  - `ToolRefusal` (:211) calls `ToolDispatchProbe.Answer` under the fixed key `"parity"` and never removes its rows.
  - The refused call's row is written along this chain: `Kernel/Agent/Dispatch.cls` `AnswerOne` → `RecordLedger` (:391) → `Kernel/Audit/Ledger.RecordToolCall` (:266) → `Kernel/State/Ledger.GuardedAppend` (:234).
  - The row reads `Kind` `tool`, `Status` `error`, `Code` `AUTH.NOPRIVILEGE`, and `TurnKey` the key.
  - Cleanup: `Kernel/State/Ledger.GuardedDeleteForTurn` (:491).
- `src/OcuPilot/Kernel/Proposal/Mint.cls`: `Mint` (:131) writes "'<id>' is already present" (:180) and "is not present" (:184) through `Refuse` (:973), and exits at `Quit tSC` (:387).
- **The readable-id pass.**
  - It lives in `src/OcuPilot/Screen/Tool/ErrorDeleteMint.cls`: `ReadableId` at :26 and the pass at :73-75.
  - The same three-line pass appears in `SuperserverMint.cls:45-47`, `MappingMint.cls:93-95` and `WebAppPctAccessMint.cls:49-51`.
  - `InteropItemMint`, `InteropSettingMint`, `InteropLookupEntryMint` and `DocDbAppMint` inherit `MappingMint`'s pass.
  - `BackgroundTaskMint.cls:31` and `EncryptionKeyFileMint.cls:51` join a composite id with no pass.
- **Existing pins of the pass.**
  - `Test/WebAppPctAccess.cls:367-405`; its doc's mutation (:370-371) names `ErrorDeleteMint.ReadableId`.
  - `Test/ErrorDeleteScope.cls`.
- **Fixtures.**
  - Background tasks: `Test/BackgroundTaskFixture` (`Clear` and `ArmPortal`, process-private) and `Test/BackgroundTaskMintFixture.Mint`.
  - Encryption: `Test/EncryptionProbe.Mint` (:652) and `.Root` (:65).
  - `Test/BackgroundTasks.cls` is 513 lines. `Test/EncryptionKeyFileRead.cls` is 196 lines, armed by `OCUPILOT_ALLOW_ENCRYPTION_CONFIG`, and on the roster at `ci-throwaway.sh:760`.
- `src/OcuPilot/Kernel/Audit/Ledger.cls`:
  - **The converters.** `LocalToUtc` (:920) uses `$ZDateTime(localH,-3)`; `LocalFromUtc` (:937) uses `$ZDateTimeH(utcH,-3)`.
  - **Callers through `..`.** `ViewForUser` criteria (:646, :653), the `AppliedCriteria` echo (:900, :904, :910) and the `RowObject` row `time` (:989).
  - **Other callers.** `Api/Ledger.cls:126,134` (through `LedgerClass()`) and `Port/InteropPort.cls:3490`.
  - **Probe subclasses of the same kind.** `Test/LedgerGateProbe`, `LedgerFaultProbe`, `LedgerLogProbe` and `LedgerRouteProbe`.
  - **Seeding.** `Test/LedgerSearch.Seed` (:98, `RecordToolCall`).
  - **Today's only pin.** `LedgerSearch.TestTheLocalConversionRoundTripsAndRefusesANonInstant` (:233). On a UTC instance it is an identity.

### Errors and copy (batch 3)

- `src/OcuPilot/Api/Error.cls`:
  - `REASONAGENTBADBODY` (:494) is named at 68 lines in 49 classes (by grep for `#REASONAGENTBADBODY`).
  - `ReasonForViolation` (:1281-1461): its last arm is `WALLETRUNG.` and its final `Quit ""` is at :1460. It has no `DOCDB.` arm, though `ReasonForToolCode` has one.
  - `ViolationCodes()` (:1625). Its doc (:1619-1624) says the `ACCOUNT.*` codes are held by `AccountPasswordWire`.
  - Family lists are class methods named `<Family>ViolationCodes()`. They live in this class (:1467-4265) and in the `OcuPilot.Api.<X>Error` classes.
- **Router arms that no list holds** (probed on `ocupilot-ci`): `ACCOUNTPASSWORDCURRENT`, `ACCOUNTPASSWORDPOLICY`, `HELPROUTE`, `PREFERENCESROUTE`, `PREFERENCESLIMIT`, `PREFERENCESVALUE`, `PREFERENCESNAME` and `PREFERENCESCHOICE`.
- `src/OcuPilot/Api/DocDbError.cls`: `ViolationCodes()` holds `DOCDB.NAME.INVALID` and `DOCDB.NAME.MAPPED`. Its `ReasonFor` answers their sentences.
- `src/OcuPilot/Test/AgentViolation.cls` (240 lines; kept): `TestViolationCodesHoldsEveryDeclaredFieldLevelCode` (:72) filters parameters on the `AGENT` prefix (:85).
- **What pins the bad-body sentence today.**
  - `src/OcuPilot/Test/AgentWire.cls:273` compares the reason with the parameter, so it survives the reword.
  - `Test/RestServiceSave.cls:227` pins only the code.
  - No `ui/` file and no `EXPERIENCE.md` row carries the sentence.

### Provider fixtures (batch 4)

- `src/OcuPilot/Test/ProviderStub.cls`:
  - `IssueHttpsPost` (:292-354) is reached from `Provider/Base.Attempts` (:387).
  - Private helpers: `HeaderNames`, `BodyOf`, `MoveArmedRow`, `Advance` and `ForceErrorLog` (an instance method; `ProviderStubShapeLeak:32` calls it).
  - Subclasses: `AdapterProvider`, `ResidueStub`, `ProviderStubAlt` and `ProviderStubShapeLeak`.
- `src/OcuPilot/Test/ProviderStubTransport.cls`: `Transport` (:40-95), a class method.
  - Callers: `OpenAIStub:41`, `GeminiStub:39` (and so `ProviderOriginProbe`) and `CompatibleStub:40`.
  - It shares 42 of its 48 code lines with the stub's body. The stub differs in four ways:
    - identity and watched headers are parameters there, arguments here;
    - it has an `x-api-key` `keyMatches` line;
    - it answers a minimal Anthropic reply for an empty script;
    - it has a `connectrefused` script kind.

## Tasks & Acceptance

**Execution:**

- One implement pass per batch leaves the tree for one commit: `fix(23.7): batch <n> - <area>`.
- Each task names its pinning test. Its `mutation:` line goes under Verification, with the observed run.
- In the same pass, update every test that asserts a shared surface's old shape (Verification › Shared surfaces).
- The lead writes ledger trailers once the batch's commit is green.

### Batch 1: proposal and conversation kernel

- [x] **DW-1233.** In `src/OcuPilot/Test/ConversationRestore.cls`, add `TestARetentionGapStillAttachesEachTurnsOwnProposals`.
  - **Setup:**
    1. Append three entries with turn keys K1, K2 and K3. Only the first carries a marker `pDefinitionId` of 32 characters or fewer.
    2. Remove that entry with `Entry.GuardedPurge`, given only `tCutoffs(marker) = NowSeconds() + 60`.
    3. Seed one live proposal on K2 and one on K3, for the HTTP account.
    4. Read `GET /api/ocupilot/conversation/:id`.
  - **Assert:** 200; JSON content type; two turns; seq 2 carries exactly the K2 proposal and seq 3 exactly the K3 one.
  - **Header:** widen it to cover the conversation read's restore and its attachment of proposals.
  - **Teardown and markers:** teardown removes the conversation (`Convo.GuardedDelete`) and each marker turn's proposals (`Propose.GuardedDeleteForTurn`). Markers are GUID-suffixed.
- [x] **DW-1233.** In `src/OcuPilot/Test/TurnWire.cls:201-204`, replace the paragraph with one sentence: the seq join is pinned across a retention gap by `ConversationRestore.TestARetentionGapStillAttachesEachTurnsOwnProposals`.
- [x] **DW-1234.** In `src/OcuPilot/Test/ConversationRestore.cls`, add `TestAnUnreadableProposalStoreDegradesToEmptyProposals`.
  - **Setup:** two entries, K1 and K2. Seed a valid proposal on K1, and one on K2 with `targetRef` `"probe-unparseable"`. Then make the HTTP read.
  - **Assert:** 200; JSON content type; both turns with their messages; each turn's `proposals` an array of size 0.
  - **No product seam:** the unparseable row makes the real store refuse.
- [x] **DW-1255.** In `src/OcuPilot/Test/TurnConversation.cls`, add `TestATypedMessageClosesThatConversationsLiveProposalsAtTheHandler`.
  - **Setup:**
    1. Create conversations A and B for `USERA`. Do this before seeding, because `POST /conversation` closes the user's live proposals.
    2. Seed live proposals PA (on A) and PB (on B) for `USERA`, under marker turn keys.
    3. `Start` a turn on A and expect 202.
  - **Assert at once:** PA reads `State` `canceled` and `ClosedReason` `message`, and PB reads `live`. Then `AwaitEnd`.
  - **Teardown:** remove both markers' proposals explicitly.
- [x] **DW-1211.** Create `src/OcuPilot/Test/ClaimReach.cls` (unarmed) with `TestOnlyTheConfirmPathNamesTheClaim`.
  - For each token, `AsTheUser.SitesNaming(token)` must equal its expected site list. Read the expected lists from the instance before writing them in:

    | Token | Expected sites |
    |---|---|
    | `Proposal.Write).Claim` | `OcuPilot.Kernel.Proposal.Confirm` |
    | `"OcuPilot.Kernel.Proposal.Write"` | none |
    | `"GuardedClaimAndClose"` | `OcuPilot.Kernel.Proposal.Confirm` |
    | `).GuardedClaimAndClose(` | none |
    | `Kernel.Proposal.Confirm)` | `OcuPilot.Api.Confirm,OcuPilot.Install.Smoke` |
    | `"OcuPilot.Kernel.Proposal.Confirm"` | none |

  - The header says the rows with a site are the scan's positive control.
  - In the same pass, delete `ToolWrite.TestNoPathFromAWriteToolsViewReachesTheClaimGate` (`ToolWrite.cls:297-307`).

### Review Findings (batch 1)

Code review, 2026-10-21, `full-opus` tier: blind-hunter, edge-case-hunter, verification-gap and acceptance-auditor. 34 raw findings make 11 entries (2 medium, 9 low). All 11 are patched; 7 are rejected. Rule 3 does not apply: batch 1 changes tests only.

- [x] [Review][Patch] (medium) `ClaimReach` missed five static spellings that reach the claim, and its header said only names assembled at run time escape. The five: a shipped subclass of `Confirm`; `##class(Confirm)` by short name; `ClaimById` called through an object; `GuardedClaimAndClose` called through an object or from inside the store; a new `Write` object. The rows were widened or added, and `Confirm` joined the subclass leg [src/OcuPilot/Test/ClaimReach.cls:60]
- [x] [Review][Patch] (medium) The seed value array was copied from `ProposalClose.Seed` into two new helpers (Rule 31). It is now `ProposalFixture.SeedMinimal`, which all three use [src/OcuPilot/Test/ProposalFixture.cls:351]
- [x] [Review][Patch] (low) The subclass leg counted test classes, against its own doc and `Write.StoreClass`'s fixture seam. It now counts shipped classes only [src/OcuPilot/Test/ClaimReach.cls:84]
- [x] [Review][Patch] (low) Both seed helpers discarded `EntityRef.Key`'s status [src/OcuPilot/Test/ConversationRestore.cls:105]
- [x] [Review][Patch] (low) `TestALargeConversationRestoresInOneEnvelope` repeated `NewConversation` inline with its own limits literal, which made `LIMITS`'s doc untrue [src/OcuPilot/Test/ConversationRestore.cls:131]
- [x] [Review][Patch] (low) `ConversationRestore`'s header said the log leg writes nothing, but each unreadable-store read logs one error line [src/OcuPilot/Test/ConversationRestore.cls:1]
- [x] [Review][Patch] (low) `ConversationRestore.Read`'s doc promised `""` for a 200 that is not JSON [src/OcuPilot/Test/ConversationRestore.cls:117]
- [x] [Review][Patch] (low) `TurnConversation`'s header did not mention the new pin or its proposal rows [src/OcuPilot/Test/TurnConversation.cls:1]
- [x] [Review][Patch] (low) The DW-1255 test's doc claimed the close precedes the job spawn. The test asserts state at the 202, and the ordering cannot be observed without a product seam [src/OcuPilot/Test/TurnConversation.cls:188]
- [x] [Review][Patch] (low) `ToolWrite`'s header still cited AD-40 after its only AD-40 test moved to `ClaimReach` [src/OcuPilot/Test/ToolWrite.cls:1]
- [x] [Review][Patch] (low) `TurnConversation` was 511 lines. It is 499 with the shared seed helper [src/OcuPilot/Test/TurnConversation.cls]

Rejected:

- (false) A homonym of `Claim` would trip the `"Claim"` and `).Claim(` rows. No shipped class matches either row today: `Registry`'s own `Claim` is called as `..Claim(`. A red would name its class.
- (low) The reach chain stops one hop past `Confirm`. No shipped class names `Install.Smoke`, `Confirm` refuses a call that comes from a turn (AD-40), and closing the gap adds rows.
- (low, an edit to this spec) The implement pass's Auto Run Result and triage row say the log is not asserted, and they give counts from before QA. They record that pass. QA's `TestAnUnreadableProposalStoreIsLogged` (run 715) closes the residual.
- (low) The log poll would pass a second marker line written after its first read. The product logs once, synchronously, through `WriteToConsoleLog`, and pinning a duplicate would add a branch.
- (low) A `messages.log` rollover inside the poll window would read red. The window is about six seconds, and the fix adds a guard.
- (false) The log loop copies `EcpProbe.CountContaining`. It also keeps the first matching line, which that helper cannot.
- (false) `$ClassMethod(..#LOGPROBE, ...)` hides a dependency. The parameter names the class in the source.

### Batch 2: gate, port and ledger

- [x] **DW-1306.** Edit `src/OcuPilot/Test/InteropFloorTurn.cls`.
  - **Setup.** In `OnBeforeAllTests`, create `TurnWireFixture.USERB` with `Resources(0)` and no second resources. Read back that it holds no member of `Screen.Gate.FloorResources()` at `USE`; otherwise the setup check fails the class.
  - **New test.** Add `TestTheShippedProviderGateAdmitsByTheLastFloorPairAndRefusesNone`. It calls `ProviderPort.Invoke("OcuPilotProbeNoSuchDefinition", ..., pUser)` in process.
    - For `USERA`, the answer is not the gate's: the HTTP status differs from `Kernel.Denial.#STATUS` and the code differs from `Kernel.Denial.Code()`. Record what it does answer.
    - For `USERB`, the answer is `Kernel.Denial.#STATUS`, with `Code()` and `Reason()`.
  - **Header.** Add the class's in-process leg.
- [x] **DW-1258.** Create two classes.
  - **`src/OcuPilot/Test/AdminPortTypeSeam.cls`** (`Extends OcuPilot.Port.AdminPort`, overrides nothing). It holds `MethodFor(e, s)`, which answers `..HttpMethodFor(e, s)`, and `TypeFor(e, s)`, which answers `..EndpointType(e, ..EndpointClass(e), s)`.
  - **`src/OcuPilot/Test/AdminPortMutatingPath.cls`** (unarmed):
    - `MethodFor` answers the suffix for `WebApp.App/PUT`, `WebApp.PctClassAccess/DELETE`, `Security.User/POST` and `Task.CRUD/RESUME`. Read each pair from `MUTATINGTYPES` on the instance first.
    - `MethodFor` answers `GET` for `Process/DELETE`, `Device.Settings/PUT` and `WebApp.App/LIST`.
    - `TypeFor` answers, for each of those four mutating pairs, the non-empty `TYPE<suffix>` parameter of the pair's `EndpointClass`.
    - `TypeFor` answers `""` for `Device.Settings/PUT` and `Process/DELETE`. Control legs show that both classes declare that parameter.
- [x] **DW-1308.** Edit `src/OcuPilot/Test/DenialParity.cls`.
  - **Keys.** `ToolRefusal` takes a fresh turn key for each call and records it. The key is `"ocupilotprobeparity"`, then `$Job`, then an increment, and is at most 64 characters.
  - **Cleanup.** `OnAfterOneTest` deletes each recorded key's rows (`State.Ledger.GuardedDeleteForTurn`).
  - **New test.** Add `TestEachRefusedCallWritesExactlyOneRefusedLedgerRow`. Make two refused calls. For each key, a SQL count on `OcuPilot_Kernel_State.Ledger` by `%EXACT(TurnKey)` reads 1. The row reads `Kind` `tool`, `Status` `error` and `Code` `AUTH.NOPRIVILEGE`, and its `RequiredPairs` names `%Admin_Secure:USE`.
- [x] **DW-2266.** One readable-id pass, in the base mint.
  - **Red first.** Write both tests below and observe them red before the fix.
    - **New `src/OcuPilot/Test/CompositeMintReadable.cls`** (unarmed). Arm with `BackgroundTaskFixture.ArmPortal("[]")`, then mint `tasks.background.cancel` with `BackgroundTaskMintFixture.Mint`, source `Management Portal` and id `999999999`. Assert:
      - 400 `TOOL.ARGUMENTS`;
      - "is not present";
      - no `$Char(1)`;
      - the text `"Management Portal" _ " " _ $Char(8250) _ " " _ "999999999"`.
    - **New method in `src/OcuPilot/Test/EncryptionKeyFileRead.cls`:** `TestAnAbsentKeyFileIsNamedReadably`, the same assertions through `EncryptionProbe.Mint` on an absent file under `Root()`.
  - **The fix, in `src/OcuPilot/Kernel/Proposal/Mint.cls`.**
    - Move `ReadableId` here from `ErrorDeleteMint`, with the same body. Its doc says what a refused composite id reads as.
    - In `Mint`, after the `Try`/`Catch` and before `Quit tSC`, apply the siblings' three-line pass to a string `detail.problem`.
  - **Remove the copies.**
    - Delete the pass from `ErrorDeleteMint`, `SuperserverMint`, `MappingMint` and `WebAppPctAccessMint`, and delete `ErrorDeleteMint.ReadableId`.
    - Repoint each doc to `OcuPilot.Kernel.Proposal.Mint.ReadableId`.
    - `Mint`'s doc says the problem is made readable for every mint.
    - Repoint `WebAppPctAccess.cls:370-371`'s mutation text to the base pass.
- [x] **DW-1783.** Edit `src/OcuPilot/Kernel/Audit/Ledger.cls`, then add a probe and a test class.
  - **New methods.**
    - `OffsetAtUtc(pUtcH)`: the seconds east of UTC the instance applies at that UTC instant, that is `$ZDateTimeH(pUtcH, -3)` minus `pUtcH`.
    - `OffsetAtLocal(pLocalH)`: `pLocalH` minus `$ZDateTime(pLocalH, -3)`.
  - **Converters.** `LocalFromUtc` answers the UTC instant plus `..OffsetAtUtc(...)`, and `LocalToUtc` answers the local instant minus `..OffsetAtLocal(...)`. Formats and refusals are unchanged.
  - **Probe.** New `src/OcuPilot/Test/LedgerClockProbe.cls` extends `Kernel.Audit.Ledger`. Both offset methods answer a fixed `Parameter OFFSET = 7200`.
  - **Tests.** New `src/OcuPilot/Test/LedgerClock.cls` (unarmed):
    - `TestTheConversionsMoveOppositeWays` (probe):
      - `LocalFromUtc("2026-10-21T23:30:00Z")` answers `"2026-10-22 01:30:00"`;
      - `LocalToUtc` of that answers the UTC value;
      - the two round-trip;
      - a value that names no instant answers `""`.
    - `TestTheShippedOffsetIsTheInstancesOwn` (shipped class), over a corpus of instants:
      - `LocalFromUtc` equals `$ZDateTime($ZDateTimeH(utcH, -3), 3, 1)`;
      - `LocalToUtc` equals `State.Turn.Timestamp($ZDateTime(localH, -3))`.

      These are the formulas the change replaces.
    - `TestTheReadConvertsItsCriteriaAndRowsTheOneWay` (probe):
      1. Seed a row with `LedgerSearch.Seed` under a marker.
      2. Call `LedgerClockProbe.ViewForUser($Username, "", "", "", <the read's maximum>, .view, .fault, 0, "", begin, end)`. `begin` and `end` are the probe's local times five minutes either side of now.
      3. Assert that the marker's row is in the view, its `time` is `loggedAt` plus two hours, and `criteria.begin` and `criteria.end` echo the values sent.
      4. Remove the marker's rows afterwards.

### Review Findings (batch 2)

Code review, 2026-10-21, `full-opus` tier: blind-hunter, edge-case-hunter, verification-gap and acceptance-auditor. 37 raw findings make 10 entries (2 medium, 8 low). 9 are patched, 1 is closed `wontfix-theoretical` (DW-2484), and 15 raw findings are rejected. Rule 3 holds: `CompositeMintSweep` runs the shipped mints in process on the instance (AD-1), and `LedgerSearchWire` reads the ledger route over HTTP (run 77).

- [x] [Review][Patch] (medium) `LedgerClock.ReadInZone` copied `InteropHostEdges.ReadInZone` line for line (Rule 31). Both now call the new fixture `ZoneSession.Signalled`; `InteropHostEdges` is green, 9 of 9 (run 775) [src/OcuPilot/Test/ZoneSession.cls:15]
- [x] [Review][Patch] (medium) The DW-1783 residual ("cannot be falsified on a UTC instance") stood beside QA's zone leg, which falsifies both helpers (runs 763, 764). Replaced under Verification. The same claim in Design Notes' DW-1783 row and follow-up, and in the Auto Run Result, is the lead's to correct [spec ## Verification]
- [x] [Review][Patch] (low) `TestTheShippedOffsetIsTheInstancesOwn` compared two identities on UTC and had no mutation line. It now compares the shipped and the vendor's conversions in the zone child, with a control that the zone moved the instants; its mutation is red (run 773) [src/OcuPilot/Test/LedgerClock.cls:84]
- [x] [Review][Patch] (low) No leg put the hour the zone's clock skips or repeats through `LocalToUtc`. Two corpus instants now do, against the vendor [src/OcuPilot/Test/LedgerClock.cls:33]
- [x] [Review][Patch] (low) `AdminPortMutatingPath`'s control legs checked only a parameter every endpoint class inherits, and its docs said the class declares it. The seam exposes `ImplementsFor`, and the unlisted legs assert the class implements the operation [src/OcuPilot/Test/AdminPortTypeSeam.cls:28]
- [x] [Review][Patch] (low) `Mint`'s doc said no composite id reaches the agent, but a minted proposal's `target.id` carries one, and a subclass's refusal before `##super` skips the pass. `Mint`'s doc and `TestNoShippedMintBypassesTheBasePass`'s now say what the pass covers [src/OcuPilot/Kernel/Proposal/Mint.cls:131]
- [x] [Review][Patch] (low) `CompositeMintSweep`'s header said any later mint with no row fails; the derivation finds only mints whose own or inherited `Mint` names the id's builder. The header says so [src/OcuPilot/Test/CompositeMintSweep.cls:6]
- [x] [Review][Patch] (low) Two cleanup calls discarded their status: `EncryptionKeyFileRead.OnAfterOneTest`'s `RemoveSeeded` and `DenialParity.ToolRefusal`'s clear before the call. Both are checked [src/OcuPilot/Test/EncryptionKeyFileRead.cls:52]
- [x] [Review][Patch] (low) The spec named `AuthOptionsDescriptor` as an observer of the base pass; it asserts nothing about it. Shared surfaces now names the two classes that do. The Code Map and Consumed-by lines are the lead's [spec ## Verification]
- [x] [Review][Defer] (low) `Mint.Refuse` builds its `%Status` text from the raw problem [src/OcuPilot/Kernel/Proposal/Mint.cls:986] — closed `wontfix-theoretical` (DW-2484): no consumer shows or logs a 400 mint refusal's status text.

Rejected:

- (low) `ShippedMints` walks `Super` lists rather than one `PrimarySuper` query. No shipped class names a superclass by short name, and the walk also finds a mint whose base is not its primary superclass.
- (low, spec-bound) `...AndRefusesNone` reads as "refuses nobody". The task names the method, and the mutation lines cite it.
- (low) Both converters truncate a negative seconds total toward zero, which only 1840-12-31 can produce. The window bound refuses such a begin first, and no ledger row is that old.
- (low, spec-bound) A superserver mint with no bind address reads `'51999 › '`. The matrix's "Unchanged" row keeps that text.
- (low) A failed `InteropFloorTurn` setup check leaves its principals. The class is already red, and its earlier check has the same shape.
- (low) A child that signals after the 120-second wait lingers. The parent clears its event queue before each launch, and the test is already red.
- (low) A spawn that fails at once still waits 120 seconds before it reads red. `/usr/bin/env` is in the image.
- (false) An empty `EndpointClass` aborts `AdminPortMutatingPath`'s method. Its `AssertNotEquals` has already failed, so the method is red.
- (false) The zone legs should be armed. The arming variables gate writes to the instance, and the child writes nothing.
- (false) `DenialParity`'s key checks and `CompositeMintSweep`'s roster-size check cannot fail under a product mutation. They check the test's own construction; the pinning legs were observed red (runs 21, 22, 756).
- (false) QA's files have not run on CI. The lead commits and pushes them before the batch closes.
- (low, spec-bound) DW-1308's refusals come from `ToolDispatchProbe.DenyPair`, not a purpose-built principal. The task prescribes `ToolRefusal`, and the row count does not depend on how the pair is denied.
- (low, spec-bound) The base-pass criterion says "minted by the agent" while the tests call the mint. The task prescribes the call, and `Write.Invoke`'s path to the mint is unchanged.
- (false) Run 757 applied three mutations at once. Each reddens a different test, naming its own class.

### Batch 3: errors and copy

- [x] **DW-1170.** In `src/OcuPilot/Api/Error.cls:494`, `REASONAGENTBADBODY` becomes "The request body is missing or is not the JSON object this request expects.", or the wording the lead rules under Design Notes › Wording for the lead. The code is unchanged.
  - **Red first:** new `src/OcuPilot/Test/BadBodySentence.cls` (unarmed; HTTP; writes nothing).
    - `POST /api/ocupilot/license/key/validate` with no body answers 400 `AGENT.BADBODY` as JSON. The reason equals the parameter and does not contain "no body".
    - `POST /api/ocupilot/agent/definitions` with `{not json` answers 400 with the same reason.
- [x] **DW-1377.** Create `src/OcuPilot/Test/ViolationSentenceCoverage.cls` (unarmed, in process). Observe both methods red first.
  - **`TestEveryListedCodeHasASentence`.**
    - The population is every class method under `OcuPilot.Api.` whose name ends `ViolationCodes`, read from `%Dictionary.CompiledMethod`.
    - Each list is non-empty.
    - Each code gets a non-empty sentence from `Error.ReasonForViolation`, other than the code itself.
    - It is red today on the two `DOCDB.NAME.*` codes.
  - **`TestEveryCodeTheRouterNamesIsListed`.**
    - Every `pCode = ..#<NAME>` arm in `ReasonForViolation`'s stored implementation resolves to a code in the union of those lists.
    - Floor: at least 100 arms.
    - It is red today on the eight codes listed in the Code Map.
- [x] **DW-1377.** Edit `src/OcuPilot/Api/Error.cls` in three places.
  - Add `If $Extract(pCode, 1, 6) = "DOCDB." Quit ##class(OcuPilot.Api.DocDbError).ReasonFor(pCode)` immediately before `ReasonForViolation`'s final `Quit ""` (:1460).
  - Directly after `ViolationCodes()`, add `AccountViolationCodes()`, `PreferencesViolationCodes()` and `HelpViolationCodes()`. Each is a `%List` of its family's codes, read from the router.
  - In `ViolationCodes()`'s doc, replace the sentence about `AccountPasswordWire` with one that names the three lists and the sweep.

### Review Findings (batch 3)

Code review, 2026-10-21, `full-opus` tier: blind-hunter, edge-case-hunter, verification-gap and acceptance-auditor. 33 raw findings make 11 entries (2 medium, 9 low); 13 raw findings are rejected. Rule 3 holds: `BadBodySentence`, `BadBodyWrongShape` and `DocDbFieldSentenceWire` assert the refusals over HTTP.

- [x] [Review][Patch] (medium) DW-1377's named regression still passed every sweep: a declared `HELP.*`, `ACCOUNT.*` or `PREFERENCES.*` field code with no router arm and no list entry is in neither population. A declared-code leg now holds those three families' field codes to the lists, as `AgentViolation` does for `AGENT.*` [src/OcuPilot/Test/ViolationSentenceCoverage.cls]
- [x] [Review][Patch] (medium) `ViolationPrefixArms.Arms` copied `ViolationSentenceCoverage.RouterArms`'s router read (the same two parameters and the open, rewind, read and match loop) with no stated reason (Rule 31). Both now call `ViolationSentenceCoverage.RouterMatches` [src/OcuPilot/Test/ViolationPrefixArms.cls]
- [x] [Review][Patch] (low) `MINARMS` stayed at 100 against the 147 arms the sweep reads, though the batch's own triage row says the arm floor was raised. Set to the population, 147 [src/OcuPilot/Test/ViolationSentenceCoverage.cls:30]
- [x] [Review][Patch] (low) Both sweep headers overclaimed. `ViolationSentenceCoverage` said every code the router answers is listed and no family is named; codes answered inside `Error`'s own `ReasonForPath`, `ReasonForOAuth` and `ReasonForNamespace` are in no list (`PATH.*` is pinned by `DatabaseRefusals.TestEachPathCodeCarriesThePortsSentence`; the others are envelope or tool-text codes). `ViolationPrefixArms` said it reaches every family without a list. Both now say what they read [src/OcuPilot/Test/ViolationSentenceCoverage.cls:1]
- [x] [Review][Patch] (low) `DocDbFieldSentenceWire`'s header said the agent's tool results re-resolve a violation's code through `ReasonForViolation`; they use `ReasonForToolCode`, and the DocDB tools call neither. The clause is removed [src/OcuPilot/Test/DocDbFieldSentenceWire.cls:6]
- [x] [Review][Patch] (low) `BadBodyWrongShape`'s header said every refusal is answered before anything is read; the right-shape legs reach the license key check, the step check and the entry rules. It now says nothing is written [src/OcuPilot/Test/BadBodyWrongShape.cls:11]
- [x] [Review][Patch] (low) `BadBodySentence`'s second method doc called `/agent/definitions` a route that "accepts no body at all"; it admits an absent body [src/OcuPilot/Test/BadBodySentence.cls:48]
- [x] [Review][Defer] (low) `AGENTBADBODY`'s doc says the body "could not be read or parsed at all", while the code also answers an absent body and a well-formed object of the wrong shape [src/OcuPilot/Api/Error.cls:486] — deferred: outside the four cleared `Error.cls` edits; filed `open`, owner this story (DW-2486).
- [x] [Review][Defer] (low) `BadBodyWrongShape` repeats `BadBodySentence`'s envelope assertions and POST wrapper; its reason (other routes) is weak, but the shared transport is `Http.AbsoluteRequest` and about eight lines repeat [src/OcuPilot/Test/BadBodyWrongShape.cls:36] — deferred: closed `wontfix-accepted` (DW-2487).
- [x] [Review][Defer] (low) `ReasonForViolation` has no `WORKFLOW.` arm, so it answers `WORKFLOW.UNKNOWN` (a field code on `workflow`) with `""` [src/OcuPilot/Api/Error.cls:1462] — deferred: closed `wontfix-theoretical` (DW-2488); `Turn` passes `WorkflowError`'s sentence and tool results use `ReasonForToolCode`, which has the arm.
- [x] [Review][Defer] (low) DW-1993 (`wontfix-accepted`: the license check gave a wrong-shape body the "could not be read as JSON" sentence) is answered by this reword and pinned by `BadBodyWrongShape` — deferred: the lead's trailer at the green commit.

Rejected:

- (false) A list element that is undefined aborts a sweep method with `<NULL VALUE>`. The method is then red (run 7 observed it), so nothing passes unseen.
- (false) `BadBodySentence` aborts on a non-JSON answer before its code and reason legs. Its status leg has already failed, printing the body.
- (low) `DocDbFieldSentenceWire` would create a database in a `USER` that does not map `Ens`. `DocDbWrite` has the same precondition, and the 422 leg reddens first.
- (low) `DocDbFieldSentenceWire` does not count the violations. The count is not its criterion; `DocDbSave.NameRefusal` builds one.
- (low) `TestTheRouterAnswersTheDocDbFamilysOwnSentences` overlaps `ViolationPrefixArms`. It also asserts each code's sentence is non-empty, which the prefix sweep's "at least one" does not.
- (false) `AccountViolationCodes`' doc names one excluded envelope code but not `ACCOUNT.VALIDATION`. The doc says "every field-level code", which excludes it; the name is an example.
- (false) The QA classes have not run on CI. The lead commits them before the batch closes.
- (false) `AssertWrongShape`'s first leg cannot fail. It guards the leg's own input, so an edited body that stopped being an object reads red.
- (low) The `tCode '= ""` router leg cannot fail. Closed in the batch's own triage on the same grounds.
- (false) The unchanged 422 row asserts no envelope code. Its 422 already tells it from `AGENT.BADBODY`'s 400, and `AgentViolation` pins `AGENT.VALIDATION` on that rules path.
- (low, spec edit) The `Batch 3 (loop)` roster, Shared surfaces, the Auto Run Result and triage row 10's residual predate QA's three classes. The QA line records them; the rest is the lead's.
- (low, spec edit) Run numbers repeat between the implement and QA lines. Each stage numbers its own throwaway's runs (inference).
- (low, spec edit) Triage row 10 counts nine prefix families without a list; it is ten, counting `PATH.`. Same root as the header row above.

### Batch 4: provider test fixtures

- [x] **DW-1191.** Consolidate the scripted transport body. Run the batch-4 class list before editing and again after; behavior is unchanged.
  - **`src/OcuPilot/Test/ProviderStubTransport.cls`:** `Transport` gains two optional trailing arguments, one for the empty-script reply and one for the key header that sets `keyMatches`. It also gains the `connectrefused` script kind.
  - **`src/OcuPilot/Test/ProviderStub.cls`:**
    - `IssueHttpsPost` becomes one call to `Transport`, with `..#STUBIDENTITY`, `..#WATCHEDHEADERS`, the minimal Anthropic reply and `"x-api-key"`.
    - Delete the stub's `HeaderNames`, `BodyOf` and `MoveArmedRow`.
    - Keep `ForceErrorLog`, `Advance` and `Wait` while callers remain.
  - **Docs:** update both class docs.
- [x] **DW-2486.** In `src/OcuPilot/Api/Error.cls`, `AGENTBADBODY`'s doc says the body "could not be read or parsed at all"; replace that clause with what `REASONAGENTBADBODY` now covers (missing, unreadable as JSON, or not the object the request expects). Doc only; `Error.cls` is no longer in Epic 20's changes (lead check), but re-run the Rule 11 check before editing.

**Acceptance Criteria:**

- **Every entry.** Given each entry in Design Notes' verdict table, when its batch lands, then:
  - its pinning test was observed red under the named mutation, or before the fix, and green after;
  - the run is recorded on its `mutation:` line;
  - the batch's commit is green on CI on its own head.
- **Base pass (integration, Rule 1).** Given a background-task cancel minted by the agent for an absent task, when the base mint refuses it, then `detail.problem` names `Management Portal › 999999999` with no U+0001. The four mints that were already readable keep the same text.
- **Offset helpers (integration; their consumer is `ViewForUser`).** Given the ledger read run through the probe's fixed two-hour offset, when a seeded row is read inside a local window, then the window, the row's `time` and the criteria echo each move the right way. The shipped converters still equal the vendor formulas.
- **Bad body.** Given a request that reaches `AGENT.BADBODY`, when it is refused, then the reason is the ruled sentence, both on routes that refuse an absent body and on routes that accept one.
- **Violation sentences.** Given every `OcuPilot.Api.*` class method whose name ends `ViolationCodes`, when the sweep runs, then every listed code has a sentence and every code the router names is listed. A later family is then covered by adding its list.
- **Provider stubs.** Given the provider stubs after batch 4, when the batch-4 class list runs, then each class is green before and after the edit, and one copy of the scripted transport body remains.
- **Dispositions.** Given the story completes, then each of the twelve entries has a disposition written by the ledger tool.

### Review Findings (batch 4)

Code review, 2026-10-21, `full-opus` tier: blind-hunter, edge-case-hunter, verification-gap and acceptance-auditor. 25 raw findings make 11 entries, all low; 3 are rejected. Rule 3 does not apply: batch 4 changes test fixtures and one doc comment. AD-35 and AD-48 hold: the canonical stub's forced entry is raised in `Transport` under `IssueHttpsPost`, and the key is compared inline. `ProviderStubSeam` declares no arming variable, so it needs no roster row.

- [x] [Review][Patch] (low) `TestEveryStubServesEveryScriptKindTheSameWay`'s doc said dropping any kind's branch reddens that kind's legs. With no chunk reader, the stream leg reads the same status and body from the answer path. The doc now names the row-move test's stream leg, observed red (run 25) [src/OcuPilot/Test/ProviderStubSeam.cls:100]
- [x] [Review][Patch] (low) The row move's spend rule was misstated: `ArmRowMove` said "the next call and no other", and the seam test said the first answer spends it and a later one finds nothing armed. Only a queued answer spends it. Both docs now say so, and an unscripted leg pins that a 200 with no script leaves it armed [src/OcuPilot/Test/ProviderStub.cls:165]
- [x] [Review][Patch] (low) `ProviderSecret`'s header counted only the sweep's eleven failures, and `REFUSALENTRIES` named the new families alone; QA's canonical test asserts the same counts. Both docs now cover it [src/OcuPilot/Test/ProviderSecret.cls:1]
- [x] [Review][Patch] (low) `ProviderStub.ErrorLogCount` and `ProviderSecret.AssertErrorEntriesAreClean` named the stub's private `ForceErrorLog` as the writer; the transport leg's entries come from `ProviderStubTransport.ForceErrorLog` [src/OcuPilot/Test/ProviderStub.cls:306]
- [x] [Review][Patch] (low) A comment in `Transport` still pointed at the inherited stub's recording, which this batch deleted [src/OcuPilot/Test/ProviderStubTransport.cls:62]
- [x] [Review][Patch] (low) `Transport`'s doc and `ProviderStubSeam`'s header called it the body behind every provider stub; `TurnProvider` keeps its own, instance-wide. The seam header also said every call is on a bare request [src/OcuPilot/Test/ProviderStubTransport.cls:1]
- [x] [Review][Patch] (low) `TestEachStubReportsItsOwnWatchedHeadersAndNoOthers` claimed a leg for a header set without a value, and its "none of the other families'" message cannot fail on the canonical stub, which watches only its own two [src/OcuPilot/Test/ProviderStubSeam.cls:168]
- [x] [Review][Patch] (low) `ProviderStub` kept copies of `ProviderStubTransport`'s `Wait`, `Advance` and `ForceErrorLog` bodies, which the other three stubs reach by delegation (Rule 31). `Wait` and `ForceErrorLog` now delegate; `Advance`, left with no caller, is deleted [src/OcuPilot/Test/ProviderStub.cls:160]
- [x] [Review][Patch] (low) `ProviderStubSeam`'s header said it needs nothing of the environment; its unarmed test can go red only where the error-seed variable reads 1 [src/OcuPilot/Test/ProviderStubSeam.cls:9]
- [x] [Review][Patch] (low) Two doc lines this batch wrote ran to 128 and 133 columns; rewrapped [src/OcuPilot/Api/Error.cls:487]
- [x] [Review][Patch] (low) `Transport.BodyOf`, consolidated from the stub, had no observed mutation, though the commit says each consolidated piece has one. Observed red (run 26) and recorded under Verification [src/OcuPilot/Test/ProviderStubTransport.cls:254]

Rejected:

- (false) The empty `Catch` blocks in the row-move and unarmed tests hide unexpected errors. Each asserts a property (the arm's survival, a zero entry count) that does not depend on whether the call threw, and `TestEveryStubServesEveryScriptKindTheSameWay` pins which kinds throw.
- (low, spec edit) The `Batch 4 (loop)` roster and Shared surfaces lack `ProviderStubSeam` (and `ProviderPort` and `Adapter`, which the review runs used). The Auto Run Result keeps the 13-class count, "Residual: none" and runs 33-45. The QA line says "bare request", though 3 of 7 tests use `ApplyAuth`-built requests, and names an undefined "M8". The new class has no Rule 31 note; it has no sibling at the seam. The lead's.
- (low, spec edit) The frontmatter reads `done` while QA's files are uncommitted. It is build-auto's state, and the lead commits.

## Spec Change Log

## Review Triage Log

### 2026-10-21 - Review pass (batch 1)

- verdicts: 11 findings - high 0, medium 0, low 7, false 4, maybe-false 0
- findings:
  - `[low]` `[patch]` ClaimReach's expected-empty rows 2, 4 and 6 had no observed red - a second mutation in `Kernel.Proposal.Caller.Clear` (a quoted `$ClassMethod` name, a static `GuardedClaimAndClose()` call, a quoted `Confirm` name) reddened exactly those three rows, each naming `Caller` (run 34); the DW-1211 `mutation:` line now records it.
  - `[low]` `[reject]` `Conversation.cls:119` `Kill tByTurn` is redundant with `GuardedRowsForConvo`'s own kill - the spec-named mutation (`Kill` to `Quit`) is observed red, the redundancy is product defense in depth, and no named harm follows; closing it would change product code.
  - `[low]` `[reject]` DW-1234's seeding is unproven inside the test - both rows invisible would be needed, the sibling gap test shares the seed helper and would redden first, and an in-test control is more than a direct correction.
  - `[low]` `[reject]` The matrix's "the read logs the failure" is not asserted - the log goes to the IRIS console log, so no HTTP-visible seam exists, and a regression there loses a diagnostic line, not behavior.
  - `[false]` `[reject]` DW-1234 asserts only `message` for "messages intact" - the attach step sets only `proposals`, so no other turn field can change on that path.
  - `[low]` `[reject]` The recorded DW-1234 mutation replaces the line the Code Map names rather than deleting it - same root cause as the redundancy row above; no new claim.
  - `[low]` `[patch]` ClaimReach's header said it pins who may reach the claim, while it measures which classes' source names it - reworded to "which shipped classes name the proposal claim", with the run-time-name limit stated.
  - `[false]` `[reject]` ClaimReach's tokens are narrower than the deleted scan's (any `Write` member) - AD-40 concerns the claim, `Write.ReasonFor` and `Write.ProhibitedClass` are legitimately called widely, and the token table is the spec's.
  - `[low]` `[patch]` DW-1211 has one recorded mutation, on row 1 only - same root cause as the first row; closed by the same second mutation.
  - `[false]` `[reject]` The retention gap comes from `Entry.GuardedPurge`, not the retention task - the spec names that method, `Kernel.Retention` calls it, and the remaining state (seq 2 and 3 at array positions 0 and 1) is the matrix's.
  - `[false]` `[reject]` The mutation evidence lives only in the spec - Rule 19 records it there by design.

### 2026-10-21 - Review pass (batch 2)

- verdicts: 18 findings - high 0, medium 0, low 14, false 4, maybe-false 0
- findings:
  - `[low]` `[reject]` The shipped `OffsetAtUtc` and `OffsetAtLocal` have no test that can fail on a UTC instance - the recorded Residual, known at plan time; closing it needs a non-UTC throwaway or CI leg, and the lead writes the ledger note.
  - `[low]` `[patch]` `AppliedCriteria`'s default-begin echo was never exercised under the probe's offset - added `LedgerClock.TestTheDefaultWindowsBeginIsEchoedInLocalTime`; its mutation is red alone (run 61).
  - `[low]` `[patch]` `AdminPortMutatingPath`'s `GET` and empty-type legs had no observed mutation - two mutations observed red and recorded (runs 62, 64).
  - `[low]` `[patch]` `HttpMethodFor`'s check-type branch had no leg - added the `License.Key/VALIDATE` leg; dropping the branch is red (run 63).
  - `[low]` `[patch]` `EncryptionKeyFileRead.TestAnAbsentKeyFileIsNamedReadably` left the seeded turn row - `OnAfterOneTest` now calls `ProposalFixture.RemoveSeeded`; the turn count on `ocupilot-ci` is unchanged across a class run.
  - `[low]` `[patch]` `DenialParity`'s per-key row count could read a row an aborted earlier run left under the same job and counter - `ToolRefusal` clears the key before the call.
  - `[low]` `[patch]` `InteropFloorTurn.FloorMemberHeld` read an unset `tResource` for an empty floor - initialized before the loop.
  - `[low]` `[reject]` Intent alignment: the "unchanged" ledger-time claim lives at a real zone and the probe's constant offset ignores the instant - the same Residual as the first row; the call-site wiring is what the probe falsifies.
  - `[low]` `[reject]` Intent alignment: `LogSourcePort.LocalFromUtc` and the route's own converter calls are untested here - the first is the spec's recorded filing candidate; the route calls the same helpers, so the same Residual.
  - `[low]` `[reject]` Intent alignment: the key-file leg asserts the status and substrings, not the code or the full sentence - the code is not reachable without widening a shared fixture (in-stage decision), and removing the base pass reddens it (run 24).
  - `[false]` `[reject]` Intent alignment: nothing asserts across the whole set of composite-id mints - the pass is one method at `Mint`'s exit, so every mint takes it, and the three already-readable families' tests stay green.
  - `[low]` `[reject]` Intent alignment: `AdminPort.Call`'s consuming sites of the two helpers are not exercised by the seam classes - spec-bound: the entry's action is a seam plus direct legs, and `AdminPortAsync` and `ToolWrite` already run the call.
  - `[low]` `[reject]` Intent alignment: `TypeFor`'s read-suffix and connection-test terms are not asserted - the entry names the mutating path; every read tool's test resolves a read type.
  - `[false]` `[reject]` Intent alignment: the provider gate's admit is observed only as the 503 after it - the AND mutation reddens the `USERA` legs (run 16), which a gate that did not admit could not do.
  - `[false]` `[reject]` Intent alignment: the test never reads `InvokePairs()` - `USERA` holds only the last floor pair and `USERB` none, so a port set that dropped the first or added a pair `USERB` holds reddens a leg (inference).
  - `[low]` `[reject]` Intent alignment: the gate leg runs in process, not through a turn job - spec-bound; `TestATurnCallsAHeldToolAndIsRefusedALackedOne` runs the turn path.
  - `[low]` `[reject]` Intent alignment: only the missing-pair refusal is counted - spec-bound by the entry's two refused calls and `RequiredPairs` assertion.
  - `[false]` `[reject]` Intent alignment: the turn key has an `x` the entry does not list - the separator keeps two jobs from making one key; recorded as an in-stage decision, and the key stays under 64 characters.

### 2026-10-21 - Review pass (batch 3)

- verdicts: 17 findings - high 0, medium 0, low 16, false 1, maybe-false 0
- findings:
  - `[low]` `[patch]` The sweep's list floor (38) sat below the population (41), so three lists could drop out unnoticed - floor set to 41; the list read and the arm read each observed red (runs 37, 38).
  - `[low]` `[patch]` `BadBodySentence` compared the reason with the parameter it was editing, so a reworded sentence stayed green - the ruled sentence is asserted verbatim; red on that leg alone (run 36).
  - `[low]` `[patch]` The DocDB equality leg passed when both sides were empty - a non-empty assertion on the family's sentence; red when `DocDbError.ReasonFor` answers `""` (run 39).
  - `[low]` `[reject]` The Account list, four Preferences rows and the `tReason '= tCode` leg have no red of their own - the discipline is one mutation per pinning test, and the `HELPROUTE` and `PREFERENCESCHOICE` reds hold the router leg.
  - `[low]` `[patch]` The sweep's header said a code the router answers cannot escape the first check - it reads only the arms that compare a declared parameter; reworded, with the prefix arms named.
  - `[low]` `[reject]` The `tCode '= ""` leg on a router arm probably cannot fail - it guards the test's own `$Parameter` read, as the batch-2 construction checks do, and removing it adds nothing.
  - `[low]` `[reject]` `RouterArms` reads one arm per line - all 147 arms sit alone on their line, and the fix adds a loop for a form no arm uses.
  - `[low]` `[patch]` `UiAboutWire`'s doc still said `ViolationCodes` sweeps `AGENT.*` alone as the reason for its wire pin - reworded to name `ViolationSentenceCoverage`.
  - `[low]` `[reject]` The DW-1377 task still says "both methods red first" while the class has three - the fix is to edit this spec, and the two named methods were observed red first (runs 1, 2).
  - `[low]` `[reject]` Nine prefix-routed families have no `ViolationCodes` list, so neither leg reaches them - spec-bound ("a later family is covered by adding its list"); the fix is a list in each family. `reopen_if` a prefix arm is deleted from `ReasonForViolation` and no test reddens.
  - `[low]` `[patch]` The ruled sentence is asserted nowhere, only the parameter's equality - same root as the second row; closed by the same assertion.
  - `[low]` `[reject]` The absent-body case is observed on one route - the matrix's first CHANGED row names that route and the second names the other; the wrong-shape path at `LicenseRules.cls:209` is untouched by this diff.
  - `[false]` `[reject]` The unchanged row (absent body on `/agent/definitions` answers 422) has no test - `AgentWire.TestAnAbsentBodyIsAdmittedFallsToTheRulesOnCreateAndChangesNothingOnUpdate` pins it, green in run 43.
  - `[low]` `[reject]` The DocDB fix is not observable over HTTP, and the tests are in process - the matrix row names `ReasonForViolation` in process and says the wire already carries the sentence; no divergence to act on.
  - `[low]` `[reject]` The `DOCDB.` arm answers all five family codes, wider than the matrix row - the task prescribes the prefix arm, as `ReasonForToolCode` has.
  - `[low]` `[reject]` The sweep has two blind spots, the prefix families and the single-line arm form - same root as the prefix-family and one-arm-per-line rows; no new claim.
  - `[low]` `[patch]` The list floor and the arm floor sit below today's counts - same root as the first row; closed by the same floor.

### 2026-10-21 - Review pass (batch 4)

- verdicts: 10 findings - high 0, medium 0, low 9, false 1, maybe-false 0
- findings:
  - `[low]` `[patch]` `Transport`'s `pEmptyReply` and `MoveArmedRow` call and `IssueHttpsPost`'s `..#STUBIDENTITY` argument had no recorded mutation - three mutations observed red and written on the DW-1191 line (runs 58, 59, 60); reverted byte-identical.
  - `[low]` `[reject]` The canonical stub's `IssueHttpsPost` error-log leg is not pinned apart from `Transport`'s - it is the same line `ProviderSecret`'s exact new-family counts pin, and the canonical legs assert `> 0` as before the change.
  - `[false]` `[reject]` `ProviderStubShapeLeak`'s header is stale about the stub's forced entries - `IssueHttpsPost` is still a live frame when `Transport` raises, so "raised from `ApplyAuth` and `IssueHttpsPost`" holds.
  - `[low]` `[reject]` `WATCHEDHEADERS`' doc names `Transport`'s private `HeaderNames` - the sentence is true, and the same class docs already name private methods.
  - `[low]` `[reject]` The other three families gain the `connectrefused` kind - the task names it, and no test queues it there.
  - `[low]` `[reject]` `Transport`'s `HeaderNames` skips an empty name where the deleted copy did not - no watched list holds an empty name, so no recording differs.
  - `[low]` `[reject]` `Advance`, `Wait` and `ForceErrorLog` remain on both classes - the task keeps them while callers remain.
  - `[low]` `[reject]` DW-2486 has no pinning test - the task is a doc-only clause.
  - `[low]` `[reject]` The three-way clause sits beside a two-way reason sentence - the cases are compatible, and the task names the three.
  - `[low]` `[reject]` The Rule 11 check and the before and after runs are not visible in the diff - the runs are on the DW-1191 line (1-26), and the check printed nothing.

## Design Notes

**Verdicts at `f0ec693f`.** Every entry is addressed and none is declined (Ledger inbox: 12 of 12). The intended disposition for all twelve is `resolved-by` 23.7, with the batch's commit. Two follow-ups for the lead:

- DW-1783 has no residual: QA's zone test falsifies both offset helpers (see the DW-1783 row).
- Where the verdict below says an entry's evidence is wrong, correct it in that entry's trailer note.

| Entry | Verdict | Evidence | Action | Batch |
|---|---|---|---|---|
| DW-1233 | Confirmed. The entry's evidence is wrong. | `Seq` is `MAX(Seq)+1` (`Entry.cls:108-112`), not `COUNT(*)+1`. It diverges from the ordinal once retention removes an early entry. `TurnWire`'s only proposal test uses seqs 1 and 2. | Gap fixture plus HTTP read. Correct `TurnWire`'s doc at its origin. | 1 |
| DW-1234 | Confirmed. The entry's location is wrong. | The source scan is `ProposalWire.TestTheConversationHandlerAttachesThemInsideItsOwnerGate` (:468), not in `Convo.cls`. | An executing test, driven by a real store failure. | 1 |
| DW-1255 | Partly fixed. | `HandleCreate`'s close is already driven at its handler (`ProposalClose.cls:145`). The turn-start close in `Api.Turn.HandleStart` (:172) is driven only through the store (`ProposalClose.cls:109-121`, `ProposalConfirm.cls:764`). | A handler test of the turn-start close. | 1 |
| DW-1211 | Confirmed. | The test scans five classes. `Kernel.Proposal.Caller`, which `View` calls, is not one of them. | A tree test. The five-file scan is deleted. | 1 |
| DW-1306 | Partly fixed. The entry's evidence is stale. | `Screen.Gate.EvaluateAnyOf` was deleted (`e27ff3c4`); the OR gate is now `ProviderPort.GateAnyOfForUser`. `DeveloperFloorTurn` and `InteropFloorTurn` admit principals holding a single floor pair through real turns; the AND mutation was not run (inference). `PortGate` and `ProviderPortOwner` substitute the gate. No class-level test has the shipped gate refuse a real principal. | Admit and refuse legs with real principals. | 2 |
| DW-1258 | Partly fixed. | `ToolWrite` and `AdminPortAsync` pin, through `AdminPort.Invoke`, the list, its width and `EndpointType`'s widening. `HttpMethodFor`'s only witness runs through `PortFixture`'s own copy of `MUTATINGTYPES`. | A seam plus direct legs. | 2 |
| DW-1308 | Confirmed. | `DenialParity` never counts rows. Its fixed key `"parity"` also leaves rows behind. | Per-call keys, a row count, and cleanup. | 2 |
| DW-2266 | Confirmed by probe. | On `ocupilot-ci`, `tasks.background.cancel` for an absent id answered a `detail.problem` with a raw U+0001 between the parts. `EncryptionKeyFileMint` has the same shape; that a missing file reaches it is inference until the red test runs. | One base pass; the four copies deleted. | 2 |
| DW-1783 | Confirmed. | On `ocupilot-ci`, `/etc/localtime` points to `Etc/UTC` and `$ZTIMEZONE` is 0. A process-level `$ZTIMEZONE` moves `$H` but not the `-3` conversions. | Explicit offset helpers plus a probe. A zone test (a child session under a real zone, `LedgerClock`) falsifies which `-3` function each helper uses, so no residual remains. | 2 |
| DW-1170 | Confirmed, and wider. The entry's evidence is partly wrong. | 68 lines in 49 classes name it (by grep); most refuse an absent body with this very sentence (probed on `POST /rest-service` and `/license/key/validate`). `PUT /agent/context` answers 422 `AGENT.CONTEXT.SHARE`, not this sentence, and Definitions and Switches accept an absent body. | Reword the reason. | 3 |
| DW-1377 | Confirmed, with one live defect. | 38 lists hold 552 codes. `ReasonForViolation` answers `""` for `DOCDB.NAME.INVALID` and `DOCDB.NAME.MAPPED`. Eight router arms (the ACCOUNT, PREFERENCES and HELP codes) belong to no list. | A derived sweep, a `DOCDB.` arm and three lists. | 3 |
| DW-1191 | Confirmed. The entry's evidence is overstated. | There are 8 stub classes, not ten or more. 42 of 48 code lines are shared. | Consolidate into `Transport`. | 4 |

**Governing ADs:**

- **AD-6, AD-34 and AD-40.** Only confirm reaches the claim, and a proposal belongs to its turn (DW-1211, DW-1233, DW-1234, DW-1255).
- **AD-37.** Retention purges entries; DW-1233's fixture is that purge.
- **AD-12 and AD-39.** There is one envelope. A `code` never changes, a reason is written once in `Error.cls`, and a field code with no published reason is a defect (DW-1170, DW-1377, and DW-1234's 200).
- **AD-13.** Refusal text never carries a raw U+0001 (DW-2266).
- **AD-8 and AD-29.** The gate is evaluated in the calling process at call time, for the named principal, and a denial names the failed pair. A denial test uses a purpose-built principal (DW-1306, DW-1308).
- **AD-2.** `AdminPort` invokes the vendor's endpoint objects, and the request method feeds the vendor's sequence (DW-1258).
- **AD-41 and Conventions › Dates.** A refused call writes one ledger row. A row's `time` and the read's criteria are in instance local time, converted on the instance (DW-1308, DW-1783).
- **AD-35 and AD-48.** The stub's forced error-log leg must survive the consolidation (DW-1191).
- **AD-17.** Probes and test seams live under `OcuPilot.Test`.
- **Conventions › Tests and › ObjectScript naming.**

No acceptance criterion contradicts an AD's Rule, and no NFR is in play.

**Decided in-stage:**

- **Batch order and grouping** follow the epic context's areas.
- **DW-1211.** An ObjectScript tree test reusing `AsTheUser.SitesNaming`, not a 22nd `check-objectscript.py` rule, so the pinned count in `CLAUDE.md` stands. The scan it supersedes is deleted.
- **DW-1783.**
  - Rejected: a non-UTC throwaway. That means editing `ci-throwaway.sh` (contended) or CI, which is large for one entry.
  - Rejected: an explicit offset argument with no probe. It would pin only new arithmetic.
  - Chosen: overridable offset helpers, plus a probe, which make `ViewForUser`'s callers (window, row time, echo) falsifiable on a UTC instance.
- **DW-2266.** `ReadableId` moves into the kernel's `Mint`. This keeps the dependency pointing from `Screen.Tool` to `Kernel`, and replaces four copies of the pass with one instead of adding a fifth and sixth. The pass sits at `Mint`'s exit, not in `Refuse`, so it covers every `detail.problem` the siblings' passes covered.
- **DW-1306.** Extend `InteropFloorTurn`, which already makes a `%Ens_Portal`-only principal, rather than add an armed class. That keeps `scripts/ci-throwaway.sh` (contended) untouched.
- **DW-1233 and DW-1234.** Extend `ConversationRestore` (Rule 31). The store failure comes from data, so no product seam is needed. `ProposalWire`'s scan is left as it is.
- **DW-1255.** Only the turn-start close is added; the New-conversation close is already pinned at its handler.
- **DW-1170.** One sentence fits every site that names it, so no second parameter.
- **DW-1377.** Lists are found by naming convention, so no family is listed by hand. `AgentViolation`'s `AGENT.*` parameter check stays.
- **DW-1191.** Consolidate rather than decline. The change is about 95 lines net, all in test fixtures, and the class list below pins it.
- **Batch 1 teardown.** `ConversationRestore` and `TurnConversation` keep the marker turn keys on the test instance and remove their proposals in `OnAfterOneTest`, so a method that raises still cleans up.
- **Batch 1 header.** `ToolWrite`'s header drops the sentence about the claim-gate scan that moved to `ClaimReach`.
- **Batch 2, DW-1258.** `Device.Settings` and `Process` do not declare `TYPEPUT` and `TYPEDELETE`; both inherit them from `%Api.Admin.Endpoint`, so the control legs read the inherited parameter.
- **Batch 2, DW-1783.** `LedgerClock` seeds and reads as the probe user `LedgerSearch.User("A")` rather than `$Username`, so the five-minute window holds only its own row; its begin and end are formatted without a zone conversion, so they do not ask the code under test.
- **Batch 2, DW-2266.** `EncryptionKeyFileRead.TestAnAbsentKeyFileIsNamedReadably` asserts the status 400 and the problem text, not the code: `EncryptionProbe.Mint` answers the problem text and not the code, and only the mint's own refusal carries that text.
- **Batch 2, DW-1308.** The turn key joins `$Job` and the counter with an `x`, so two jobs cannot make the same key.
- **Batch 2, DW-1258.** A `License.Key/VALIDATE` leg pins `HttpMethodFor`'s check-type branch, the one non-mutating pair that sends its suffix.
- **Batch 3, DW-1377.** The three new lists hold only the codes the router names, which are field-level codes. `ACCOUNT.PASSWORD.BODY` and `PREFERENCES.BODY` are envelope codes with no field and no router arm, so neither is listed.
- **Batch 3, DW-1377.** The sweep's list floor is the population it was written against (41), so a list that drops out of the sweep reads red.
- **Batch 3, DW-1170.** `BadBodySentence` also asserts the ruled sentence verbatim: the acceptance line names it, and equality with the parameter cannot see a reword.
- **Batch 3, DW-1377.** A third method, `TestTheRouterAnswersTheDocDbFamilysOwnSentences`, pins the matrix row's equality: the router answers the family's own sentence, not merely a non-empty one.

**Wording for the lead** (the lead rules at the spec gate):

- **`REASONAGENTBADBODY`.**
  - Now: "The request body could not be read as JSON. Send a JSON object, or no body at all."
  - Proposed: "The request body is missing or is not the JSON object this request expects."
  - Why this wording: it is true on routes that refuse an absent body. It is true on routes that accept one, where the sentence fires only for a body that is not an object. It is also true at the four sites that show it for a well-formed object of the wrong shape: `LicenseRules.cls:209`, `DatabaseRules.cls:476,481` and `PctAccessSave.cls:90`.
  - A shorter alternative: "Send a JSON object as the request body." This one is misleading at those four sites.
- **Composite-id refusal**, the `detail.problem` the model reads:
  - Now: `'Management Portal<U+0001>999999999' is not present on this instance`.
  - Proposed: `'Management Portal › 999999999' is not present on this instance`, as the four sibling mints already answer.
- **DocDB codes.** No new sentence. The router answers with `DocDbError`'s existing sentences.

**Contended files** (Rule 11). Checked against Epic 20's head `6a8fd1f0`. Before editing, re-check with:

- `git -C /Users/jbrandt/git/OcuPilot/.worktrees/epic-20 diff --stat origin/feature/OCU-1_ocupilot-mvp...HEAD -- <path>`
- `git -C /Users/jbrandt/git/OcuPilot/.worktrees/epic-20 status -s --untracked-files=all -- <path>`

| File | Epic 20's change | This story's edit | Add-only |
|---|---|---|---|
| `src/OcuPilot/Api/Error.cls` | One `ANALYTICS.` arm in `ReasonForToolCode` (after :1235), and one in `ReasonForViolation` (after :1452) | (a) `REASONAGENTBADBODY`'s value, :494. (b) A `DOCDB.` arm before `ReasonForViolation`'s final `Quit ""` (:1460), eight lines below Epic 20's arm. (c) Three list methods after `ViolationCodes()` (about :1628). (d) `ViolationCodes()`'s doc, :1619-1624. | **No.** (a) and (d) rewrite existing lines, 740 or more and 160 or more lines away from Epic 20's hunks. (b) and (c) are add-only. A clean textual merge is (inference). |

Epic 20 has not changed any other file in the Code Map. Its working tree holds only `spec-20-11…`, `ui/src/app/core/session.ts` and `ui/tools/session.test.mjs`.

**Consumed-by and Consumes (Rules 1 and 2).** Every consumer is in this story.

- **`Kernel.Proposal.Mint.ReadableId` and the base pass.** Every mint consumes them through `##super`. Observed by `CompositeMintReadable`, `EncryptionKeyFileRead`, `WebAppPctAccess`, `ErrorDeleteScope` and `CompositeMintSweep`.
- **`Kernel.Audit.Ledger.OffsetAtUtc` and `OffsetAtLocal`.** Consumed by `LocalFromUtc` and `LocalToUtc`, and through them by `ViewForUser`, `AppliedCriteria`, `RowObject`, `Api.Ledger` and `InteropPort`. Observed by `LedgerClock`.
- **`Error.AccountViolationCodes`, `PreferencesViolationCodes` and `HelpViolationCodes`.** Consumed by `ViolationSentenceCoverage`.
- **`ProviderStubTransport.Transport`'s new arguments.** Consumed by `ProviderStub.IssueHttpsPost`.
- **Seams.** `AdminPortTypeSeam` is consumed by `AdminPortMutatingPath`, and `LedgerClockProbe` by `LedgerClock`.

**Extend, don't copy (Rule 31).**

- **`ClaimReach`** calls `AsTheUser.SitesNaming`. It is a new class because `ToolWrite` is 1,431 lines.
- **`AdminPortTypeSeam`** follows the `AdminPort` test seams (`RoleDeletePort`). No existing seam exposes these two private methods, and `PortFixture` overrides the very list under test. `AdminPortMutatingPath` is new for the same size reason as `ClaimReach`.
- **`CompositeMintReadable`** uses `BackgroundTasks`' fixtures. It is new because that class is 513 lines.
- **`LedgerClockProbe`** follows `LedgerGateProbe` and `LedgerFaultProbe`. `LedgerClock` uses `LedgerSearch.Seed`, and is new because `LedgerSearch` is 515 lines.
- **`BadBodySentence`** follows `AgentViolation.Call`'s HTTP pattern. It is new because `AgentWire` is 721 lines.
- **`ViolationSentenceCoverage`** generalizes `AgentViolation`'s sweep to every family.

**Filing candidate, not absorbed** (Rule 27 cap). `LogSourcePort.LocalFromUtc` (:1871), used by `Timeline` and `InteropPort`, has the same unfalsifiable direction on a UTC instance.

## Verification

**Shared steps**, run on slot A with `ocupilot-ci` (52776/1975; directory `/Users/jbrandt/.ocupilot-throwaways/ocupilot-ci`):

- **Load (loop).** Run `rsync -a --delete src/ /Users/jbrandt/.ocupilot-throwaways/ocupilot-ci/src/`, then `Do $System.OBJ.LoadDir("/opt/ocupilot/src","ck-d",.e,1)` in `docker exec -i ocupilot-ci iris session iris -U HSCUSTOM`. Expected: 0 errors.
- **Class (loop).** Run `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.<C>`, one class per call. Expected: 0 failed, confirmed in `%UnitTest_Result`.
- **Checks (loop).** Expected: each is clean or green.
  - `uv run scripts/check-objectscript.py <changed .cls>`
  - `cd ui && npm run test:tools`
  - `bash scripts/lint-docs.sh` (only when Markdown changes)

**Commands:** the Class step for each batch's list, after Load. There are no `(once)` lines: the full ObjectScript sweep and Rule 30's fresh check are the lead's, and the full browser suite is CI's.

- **Batch 1 (loop):** ConversationRestore, TurnConversation, TurnWire, ClaimReach, ToolWrite, ProposalClose, ProposalWire.
- **Batch 2 (loop):**
  - Gate, port and denial: InteropFloorTurn, AdminPortMutatingPath, AdminPortAsync, DenialParity.
  - Mints: CompositeMintReadable, EncryptionKeyFileRead, WebAppPctAccess, ErrorDeleteScope, AuthOptionsDescriptor, BackgroundTasks.
  - Ledger: LedgerClock, LedgerSearch, LedgerSearchWire.
- **Batch 3 (loop):**
  - New: BadBodySentence, ViolationSentenceCoverage.
  - Affected: AgentViolation, AgentWire, RestServiceSave, DocDbAppDescriptor, DocDbPort, DocDbWrite, UiAboutWire, PreferencesWire, AccountPasswordWire.
- **Batch 4 (loop, run before the edit and after):**
  - Transport and secrets: ProviderTransportRetry, ProviderSecret, SecretLeak, WalletRungWire, AgentConnection.
  - Streams and retries: ProviderStream, ProviderStreamFamilies, ProviderRetry, ProviderProxy, Provider.
  - Adapters: OpenAIAdapter, GeminiAdapter, CompatibleAdapter.

**Shared surfaces:**

- **The `AGENT.BADBODY` reason.** `AgentWire.cls:273` compares it with the parameter.
- **The base mint's presence text.** `WebAppPctAccess`, `ErrorDeleteScope`, `CompositeMintReadable` and `CompositeMintSweep` assert the readable form. `LockRemoveLive`, `LanguageServerEditorWire` and `RoutineAppWrite` assert presence text for ids that are not composite, which stays unchanged.
- **`ReasonForViolation`'s answers and the violation-code lists.** Asserted by `AgentViolation`, `DocDbAppDescriptor:245`, `DocDbAppWrite`, `UiAboutWire`, `PreferencesWire` and `AccountPasswordWire`.
- **The ObjectScript test-class roster.**
  - New test classes: `ClaimReach`, `AdminPortMutatingPath`, `CompositeMintReadable`, `LedgerClock`, `BadBodySentence` and `ViolationSentenceCoverage`.
  - New classes that are not tests: `AdminPortTypeSeam` and `LedgerClockProbe`.
  - `ToolWrite` loses one method.
  - No arming roster changes.
- **Standing criterion.** Every test added or changed passes on a fresh environment, in either order. Each test creates and removes its own rows, users and markers.

**Mutations (Rule 19).** Implement records the observed run, and the red test, on each line.

- `mutation:` (DW-1233) applied: `Conversation.cls:129` `tKeys(+tTurn.%Get("seq"))` to `tKeys(tI + 1)` → `ConversationRestore.TestARetentionGapStillAttachesEachTurnsOwnProposals` red alone (ocupilot-ci run 14: seq 2 read no proposal, seq 3 read seq 2's); `TurnWire` green, 15 of 15 (run 9). Reverted; tree byte-identical.
- `mutation:` (DW-1234) applied: `Conversation.cls:119` `Kill tByTurn` to `Quit` → `ConversationRestore.TestAnUnreadableProposalStoreDegradesToEmptyProposals` red alone (run 13): neither turn carries a `proposals` array. Reverted; tree byte-identical.
- `mutation:` (DW-1255) applied: deleted the `GuardedCloseLiveForConvo` block in `Turn.HandleStart` (`Turn.cls:172-176`) → `TurnConversation.TestATypedMessageClosesThatConversationsLiveProposalsAtTheHandler` red alone, 10 of 11 green (run 15): conversation A's proposal stayed live. Reverted; tree byte-identical.
- `mutation:` (DW-1211) applied: `If 0 Do ##class(OcuPilot.Kernel.Proposal.Write).ClaimById("", "", .tR, .tC)` as the first line of `Kernel.Proposal.Caller.Clear` → `ClaimReach` red on its first token (run 16: `Caller,Confirm` where `Confirm` was expected). A second mutation put a quoted `$ClassMethod("OcuPilot.Kernel.Proposal.Write", ...)`, a static `Propose.GuardedClaimAndClose()` and a quoted `"OcuPilot.Kernel.Proposal.Confirm"` call in the same method → the three expected-empty rows go red, each naming `Caller` (run 34). Both reverted; tree byte-identical.
- `mutation:` (DW-1234, QA) delete the `Fault.LogRaw` call in `Conversation.AttachProposals`'s proposal-read failure branch → `ConversationRestore.TestAnUnreadableProposalStoreIsLogged` red alone, 3 of 4 green (ocupilot-ci run 715: no new `messages.log` line carries the request's marker). Reverted; tree byte-identical.
- `mutation:` (DW-1211, QA) add a shipped class outside the six rows, `Kernel.Proposal.ReachProbe`:
  - it calls `Write.ClaimById` statically → `ClaimReach.TestOnlyTheConfirmPathNamesTheClaim` red, naming the new class (run 716), and `TestNoOtherSpellingOrSubclassReachesTheClaim` red on its `ClaimById` call row;
  - it calls `$ClassMethod(pClass, "ClaimById", ...)` → only `TestNoOtherSpellingOrSubclassReachesTheClaim` red, on the quoted-name row, while the first test stays green (run 717);
  - it `Extends OcuPilot.Kernel.Proposal.Write` and calls `..ClaimById` → only `TestNoOtherSpellingOrSubclassReachesTheClaim` red, on the subclass query (run 718).
  - Reverted; the class is deleted from the instance and the tree is byte-identical.
- `mutation:` (QA re-observed, batch 1) `tKeys(+tTurn.%Get("seq"))` → `tKeys(tI + 1)`: `ConversationRestore.TestARetentionGapStillAttachesEachTurnsOwnProposals` red alone (run 720). `Kill tByTurn` → `Quit`: `TestAnUnreadableProposalStoreDegradesToEmptyProposals` red alone (run 721). Delete the close block in `Turn.HandleStart`: `TurnConversation.TestATypedMessageClosesThatConversationsLiveProposalsAtTheHandler` red alone, 10 of 11 green (run 722). Each reverted; tree byte-identical.
- (QA) Files extended in place, no new file: `src/OcuPilot/Test/ConversationRestore.cls` (`TestAnUnreadableProposalStoreIsLogged`, four parameters) and `src/OcuPilot/Test/ClaimReach.cls` (`TestNoOtherSpellingOrSubclassReachesTheClaim`, `SubclassesOf`). After the reverts, each batch-1 class is green on `ocupilot-ci`: ConversationRestore 4 (run 725), TurnConversation 11 (run 726), ClaimReach 2 (run 727).
- `mutation:` (DW-1211, review) The mutation has two parts:
  - In `Kernel.Proposal.Caller.Clear`, add `If 0` lines that make a `Write` object and call `tW.ClaimById(...)`, call `tP.GuardedClaimAndClose(...)`, and call `##class(Confirm).Confirm(...)`.
  - Add a shipped `Kernel.Proposal.ReachProbe` that extends `Kernel.Proposal.Confirm`.

  Result: `TestNoOtherSpellingOrSubclassReachesTheClaim` is red on exactly its five review legs: `.ClaimById(`, `.GuardedClaimAndClose(`, `Proposal.Write).%New(`, `(Confirm).` and the `Confirm` subclass. `TestOnlyTheConfirmPathNamesTheClaim` stays green (ocupilot-ci run 729). Reverted, the class deleted from the instance, and the tree byte-identical. After the review patches: ClaimReach 2 (run 730), ConversationRestore 4 (731), TurnConversation 11 (732), ProposalClose 7 (733), ToolWrite 33 (734); `check-objectscript.py` 0 problems; `npm run test:tools` 2072 of 2072.
- `mutation:` (DW-1306) applied: `ProviderPort.GateAnyOfForUser` made to require every pair → `InteropFloorTurn.TestTheShippedProviderGateAdmitsByTheLastFloorPairAndRefusesNone` red on its three `USERA` legs (a 403 `AUTH.NOPRIVILEGE` answers the floor-last holder), and the existing `TestATurnCallsAHeldToolAndIsRefusedALackedOne` red too (the turn fails `AUTH.NOPRIVILEGE`), so the AND mutation the Design Notes left unrun is now observed (ocupilot-ci run 16). `HoldsPairForUser` made to answer 1 → the new test red alone on its three `USERB` legs, the turn test green (run 17). Each reverted; `ProviderPort.cls` byte-identical to HEAD.
- `mutation:` (DW-1258) applied: `AdminPort.HttpMethodFor` answering `"PUT"` for every mutating pair → `AdminPortMutatingPath.TestAMutatingPairSendsItsSuffixAndAnyOtherSendsGet` red on the `WebApp.PctClassAccess/DELETE`, `Security.User/POST` and `Task.CRUD/RESUME` legs (run 18). `'..IsMutating(...)` dropped from `EndpointType`'s admission → `TestAMutatingPairResolvesItsTypeAndAnUnlistedWriteSuffixResolvesNone` red on all four type legs (run 19). `WebApp.PctClassAccess/DELETE` removed from `MUTATINGTYPES` with the tree reloaded and recompiled → that pair's list, method and type legs red in both methods (run 20). `HttpMethodFor` answering its suffix for every pair → `TestAMutatingPairSendsItsSuffixAndAnyOtherSendsGet` red on its `GET` legs (run 62). `HttpMethodFor` without its `IsCheckType` line → the same test red on the `License.Key/VALIDATE` leg (run 63). `EndpointType` without its unlisted-suffix `Quit ""` → `TestAMutatingPairResolvesItsTypeAndAnUnlistedWriteSuffixResolvesNone` red on the unlisted legs (run 64). Each reverted; `AdminPort.cls` byte-identical to HEAD.
- `mutation:` (DW-1308) applied: a second `..RecordLedger(...)` in `AnswerOne`'s `MissingPair` branch → `DenialParity.TestEachRefusedCallWritesExactlyOneRefusedLedgerRow` red alone, on both keys' count legs (run 21). The common-exit `RecordLedger` deleted → red alone, on both keys' count legs and both keys' "has a ledger row to read" legs (run 22). Each reverted; `Dispatch.cls` byte-identical to HEAD. After the class: no ledger row with a `parity` or `ocupilotprobeparity` turn key survives.
- `mutation:` (DW-2266) before the fix: `CompositeMintReadable` red on its three U+0001, breadcrumb and sentence legs (run 1), and `EncryptionKeyFileRead.TestAnAbsentKeyFileIsNamedReadably` red on its U+0001 and breadcrumb legs (run 2), so a missing key file does reach the mint's presence check. After the fix, the base pass removed from `Kernel.Proposal.Mint.Mint` → `CompositeMintReadable` red (run 23), `TestAnAbsentKeyFileIsNamedReadably` red (run 24) and `WebAppPctAccess.TestAPresenceRefusalNamesTheEntryReadably` red on both its legs (run 25). Reverted; `Mint.cls` byte-identical to the pre-mutation copy.
- `mutation:` (DW-1783) applied: the sign swapped in `LocalFromUtc` → `LedgerClock.TestTheConversionsMoveOppositeWays` red on its forward and round-trip legs, and `TestTheReadConvertsItsCriteriaAndRowsTheOneWay` red on its `time` and both echo legs (run 26). `ViewForUser` converting `pBegin` with `LocalFromUtc` → the read test red, the windowed read refused (run 27). The sign swapped in `LocalToUtc` → the read test red on "the seeded row is inside the local window" and both echo legs, and `TestTheConversionsMoveOppositeWays` red on its backward and round-trip legs (run 28). `AppliedCriteria` converting `begin` with `LocalToUtc` → the read test red on the begin echo alone (run 29). `AppliedCriteria`'s default-begin branch converting with `LocalToUtc` → `TestTheDefaultWindowsBeginIsEchoedInLocalTime` red alone (run 61). Each reverted; `Ledger.cls` byte-identical to the pre-mutation copy.
  - Which `-3` form each helper reads is falsified on this UTC instance by `LedgerClock`'s zone legs, which run the shipped helpers in a child session under `TZ=EST5EDT,M3.2.0,M11.1.0` (QA and review lines below).
- (batch 2) After the review patches and a reload, each batch-2 class is green on `ocupilot-ci`: InteropFloorTurn 2 (run 66), AdminPortMutatingPath 2 (67), AdminPortAsync 6 (68), DenialParity 3 (69), CompositeMintReadable 1 (70), EncryptionKeyFileRead 6 (65), WebAppPctAccess 11 (71), ErrorDeleteScope 8 (72), AuthOptionsDescriptor 10 (73), BackgroundTasks 13 (74), LedgerClock 4 (75), LedgerSearch 10 (76), LedgerSearchWire 3 (77). `check-objectscript.py` 0 problems; `npm run test:tools` 2081 of 2081.
- (QA) Batch-2 files: new `src/OcuPilot/Test/CompositeMintSweep.cls` (5 tests, a new test class, unarmed) and `src/OcuPilot/Test/CompositeMintProbe.cls` (the tool class and port every mint is handed, not a test); extended in place `src/OcuPilot/Test/LedgerClock.cls` (`TestTheFormsRefusalsAndCalendarBoundariesAreUnchanged`, `TestTheShippedConversionsFollowTheZoneOfTheProcess`, `ReadInZone`, `ZoneChild`). The batch-2 Class loop also runs `CompositeMintSweep`. No arming roster changes: `CompositeMintSweep` is unarmed, and `LedgerClock`'s child session needs `%System_CallOut:USE` and a password-less sign-in, as `InteropHostEdges`'s zone leg does.
- `mutation:` (DW-2266, QA) The readable-id block deleted from `Kernel.Proposal.Mint.Mint`'s exit → `CompositeMintSweep.TestEveryCompositeMintNamesAnAbsentTargetReadably` red on the text legs of all ten rows, the other four tests green (ocupilot-ci run 756). The separator put back after `##super` in `SuperserverMint` → that test red on the Superserver row's three legs alone (run 757). The pass moved into the absence branch alone → `TestEveryCompositeMintNamesAnAlreadyPresentTargetReadably` and `TestEveryCompositeMintNamesAPortRefusalsTargetReadably` red, the absence test green (run 760). The pass moved into `Refuse` → `TestEveryCompositeMintNamesAPortRefusalsTargetReadably` red alone (run 761). A shipped `QaBypassProbeMint` that declares its own `Mint` and never calls `##super` → `TestNoShippedMintBypassesTheBasePass` red naming it; a shipped `QaRosterProbeMint extends MappingMint` with no row → `TestTheRosterIsEveryCompositeIdMint` red naming it (both in run 757). Each reverted; `Mint.cls` and `SuperserverMint.cls` byte-identical (sha1 equal to before), the two probe classes deleted from the tree and from the instance.
- `mutation:` (DW-1783, QA) The fractional-second group dropped from `LocalFromUtc`'s pattern → `LedgerClock.TestTheFormsRefusalsAndCalendarBoundariesAreUnchanged` red alone (run 758). `OffsetAtUtc` reading `$ZDateTime(pUtcH, -3)` → `TestTheShippedConversionsFollowTheZoneOfTheProcess` red on its six `LocalFromUtc` legs alone, every other `LedgerClock` test green (run 763). `OffsetAtLocal` reading `$ZDateTimeH(pLocalH, -3)` → the same test red on its five `LocalToUtc` legs alone (run 764). The zone leg runs the shipped converters in a child session with `TZ=EST5EDT,M3.2.0,M11.1.0`, which a UTC instance's own process cannot do. Each reverted; `Ledger.cls` byte-identical (sha1 equal to before).
- (QA) After the reverts and a full reload (0 errors), on `ocupilot-ci`: CompositeMintSweep 5 (run 765), LedgerClock 6 (766), CompositeMintReadable 1 (767), WebAppPctAccess 11 (768), LedgerSearch 10 (769), EncryptionKeyFileRead 6 (770), ErrorDeleteScope 8 (771). `check-objectscript.py` 0 problems; `npm run test:tools` 2081 of 2081.
- `mutation:` (DW-1783, review) `TestTheShippedOffsetIsTheInstancesOwn` now compares the shipped and the vendor's conversions over `CORPUS` in the zone child. `OffsetAtUtc` reading `$ZDateTime(pUtcH, -3)` → that test red on all twelve corpus `LocalFromUtc` legs, and the zone test red on its six (ocupilot-ci run 773). Reverted; `Ledger.cls` byte-identical (sha1 equal to before).
- (review) Files: new `src/OcuPilot/Test/ZoneSession.cls` (the child-session launcher, not a test); `InteropHostEdges.ReadInZone` and `LedgerClock.ReadInZone` call it, so `InteropHostEdges` joins the batch-2 Class loop. After the review patches and a reload (0 errors), on `ocupilot-ci`: LedgerClock 6 (run 774), InteropHostEdges 9 (775), AdminPortMutatingPath 2 (776), DenialParity 3 (777), EncryptionKeyFileRead 6 (778), CompositeMintSweep 5 (779), CompositeMintReadable 1 (780). `check-objectscript.py` 0 problems; `npm run test:tools` 2081 of 2081.
- `mutation:` (DW-1170) before the fix: `BadBodySentence` red on both methods, on the "no body" leg (ocupilot-ci run 1). After the fix, `, or no body at all` put back at the end of `REASONAGENTBADBODY` and the tree reloaded → both methods red on the same leg (run 5). Reverted; `Error.cls` byte-identical to the fixed copy. After the review patch added the ruled-wording leg, `REASONAGENTBADBODY` set to "Send a JSON object." → both methods red on that leg alone (run 36); reverted, byte-identical.
- `mutation:` (DW-1377) before the fix: `ViolationSentenceCoverage` red on both methods (run 2). `TestEveryListedCodeHasASentence` names `DOCDB.NAME.INVALID` and `DOCDB.NAME.MAPPED`; `TestEveryCodeTheRouterNamesIsListed` names the eight router codes (`ACCOUNT.PASSWORD.CURRENT`, `ACCOUNT.PASSWORD.POLICY`, `PREFERENCES.ROUTE`, `PREFERENCES.LIMIT`, `HELP.ROUTE`, `PREFERENCES.VALUE`, `PREFERENCES.NAME`, `PREFERENCES.CHOICE`). After the fix:
  - the `DOCDB.` arm deleted → `TestEveryListedCodeHasASentence` red alone, on those two codes (run 6);
  - `HelpViolationCodes()` answering `""` → `TestEveryCodeTheRouterNamesIsListed` red on `HELP.ROUTE`, and `TestEveryListedCodeHasASentence` red on its non-empty leg, because `HELPROUTE` is that list's only code (run 8). A `Quit $ListBuild()` body is a one-element list of a null, not an empty list, and raises `<NULL VALUE>` in both methods (run 7);
  - `PREFERENCESCHOICE` dropped from `PreferencesViolationCodes()` → `TestEveryCodeTheRouterNamesIsListed` red alone, on that code (run 9).
  - the `DOCDB.` arm answering `DocDbError.ReasonFor("DOCDB.NAME.INVALID")` for every code → `TestTheRouterAnswersTheDocDbFamilysOwnSentences` (matrix row 4's equality leg) red alone, the other two green (run 33);
  - `Parameter SUFFIX` set so the list query reads nothing → `TestEveryListedCodeHasASentence` red on its list-floor leg (found 0) and the router test red (run 37);
  - `Parameter ROUTERMETHOD` naming no method → `TestEveryCodeTheRouterNamesIsListed` red alone on its arm-floor leg (found 0) (run 38);
  - `DocDbError.ReasonFor` answering `""` for both field codes → `TestTheRouterAnswersTheDocDbFamilysOwnSentences` red on its non-empty leg, which equality alone would pass, and `TestEveryListedCodeHasASentence` red (run 39).

  Each reverted; `Error.cls`, `DocDbError.cls` and `ViolationSentenceCoverage.cls` byte-identical (sha1 equal).
- (batch 3) After the review patches, the reverts and a reload (0 errors), each batch-3 class is green on `ocupilot-ci`: BadBodySentence 2 (run 40), ViolationSentenceCoverage 3 (41), AgentViolation 8 (42), AgentWire 18 (43), RestServiceSave 8 (44), DocDbAppDescriptor 11 (45), DocDbPort 8 (46), DocDbWrite 8 (47), UiAboutWire 7 (48), PreferencesWire 12 (49), AccountPasswordWire 6 (50). `check-objectscript.py` 0 problems; `npm run test:tools` 2087 of 2087.
- (QA) Batch-3 files: new `src/OcuPilot/Test/BadBodyWrongShape.cls` (3 tests, HTTP, unarmed), `src/OcuPilot/Test/DocDbFieldSentenceWire.cls` (2 tests, HTTP, unarmed) and `src/OcuPilot/Test/ViolationPrefixArms.cls` (1 test, in process, 351 assertions); all three join the batch-3 Class loop. No product file changed and no arming roster changes: every request is a refusal that writes nothing (afterwards `USER` and `HSCUSTOM` hold 0 probe classes and 0 document databases). After the reverts and a reload (0 errors), on `ocupilot-ci`: BadBodyWrongShape 3 (run 21), DocDbFieldSentenceWire 2 (22), ViolationPrefixArms 1 (23), BadBodySentence 2 (24), ViolationSentenceCoverage 3 (25). `check-objectscript.py` 0 problems.
- `mutation:` (DW-1170, QA) `BadBodyWrongShape`, the sentence on the three routes that refuse a well-formed object of the wrong shape:
  - `LicenseRules.HandleValidate`'s shape refusal given `#REASONPORTFIELDUNEXPECTED` → `TestALicenseKeyBodyOfTheWrongShapeIsAnsweredWithTheRuledSentence` red alone, on its six sentence legs (run 5);
  - `DatabaseRules.HandleCheck`'s `values` refusal → the database test red on the `values` legs (run 6); its unknown-step refusal → the same test red on the unknown-step leg alone (run 7);
  - `PctAccessSave.Create`'s refusal → the pct-access test red on both legs (run 8);
  - `If 1 ||` ahead of `HandleValidate`'s shape condition, so every body is refused → the license test red on its right-shape control leg alone, `BadBodySentence` green (runs 9, 10);
  - `REASONAGENTBADBODY` set back to the old sentence → all three red (run 11).
- `mutation:` (DW-1377, QA) `DocDbFieldSentenceWire`: the `DOCDB.` arm deleted → both tests red (run 12). `DocDbSave.NameRefusal`'s and `DocDbPort.Violation`'s reason set to "Use another name." → both red, the invalid-name test on the first and the mapped-name test on the second (run 14); `DocDbWrite` asserts the sentence over the wire for `DOCDB.NAME.INVALID` only, and status, code and field for `DOCDB.NAME.MAPPED`.
- `mutation:` (DW-1377 prefix arms, QA) `ViolationPrefixArms`: `If $Extract(pCode, 1, 8) = "JOURNAL." Quit ""` ahead of the `JOURNAL.` arm → `ViolationSentenceCoverage` green (run 19) and `ViolationPrefixArms` red on each Journal code (run 20). The arm comparing 7 characters → red on its length leg and each Journal code (run 17). The arm deleted → red on the arm floor alone (found 20; run 15), and the `DOCDB.` arm deleted → the same floor (run 13). Every mutation above was reverted from git: `git hash-object` of `Error.cls`, `LicenseRules.cls`, `DatabaseRules.cls`, `PctAccessSave.cls`, `DocDbSave.cls` and `DocDbPort.cls` equals its value before the first mutation, and `git status --short` lists only the three new files.
- `mutation:` (DW-1377, review) `Parameter HELPPROBE = "HELP.PROBE"` added to `Error.cls` and nothing else → `ViolationSentenceCoverage.TestEveryDeclaredFieldCodeOfTheNamedFamiliesIsListed` red alone, naming `HELP.PROBE`, the other three green (ocupilot-ci run 28). With `ViolationPrefixArms` reading the router through `ViolationSentenceCoverage.RouterMatches`, QA's `JOURNAL.` `Quit ""` mutation → red on each Journal code (run 29). Each reverted from git; `Error.cls` byte-identical (`git hash-object` `1dc6bdff`). After a clean reload (0 errors): ViolationSentenceCoverage 4 (run 30), ViolationPrefixArms 1 (31), BadBodySentence 2 (32), BadBodyWrongShape 3 (33), DocDbFieldSentenceWire 2 (34). `check-objectscript.py` 0 problems; `npm run test:tools` 2087 of 2087.
- `mutation:` (DW-1191) applied: the `connectrefused` branch dropped from `Transport` → `ProviderTransportRetry.TestAConnectThatNeverOpenedIsNotRetried` red alone, 8 of 9 green (ocupilot-ci run 27). `IssueHttpsPost` passing no key header → `WalletRungWire.TestAListedHostIsServedAndAnUnlistedOneFaultsTheCall` and `TestTheStoredValueIsTheKeyTheRequestCarries` red, 8 of 10 green (run 28). `Transport`'s `ForceErrorLog` call dropped → `ProviderSecret` red on the two new-family legs' entry counts (run 29). Review: `Transport` answering `""` instead of `pEmptyReply` → `ProviderProxy` red on 2 of 4 (run 58); `Transport`'s `MoveArmedRow` call deleted → `AgentConnection.TestARowMovedDuringTheCallRefusesTheVerification` red alone (run 59); `IssueHttpsPost` passing the literal `"stub"` for `..#STUBIDENTITY` → `ProviderPort.TestTheAdapterComesFromTheRowsOwnColumn` red alone (run 60); after the reverts ProviderProxy, AgentConnection, ProviderPort and Adapter are green (runs 61-64). Each reverted; `ProviderStubTransport.cls` and `ProviderStub.cls` byte-identical (`git hash-object` equal). No test can fail on the duplication itself; the pinning evidence is the batch-4 list, green before (runs 1-13) and after (runs 14-26) with the same totals: ProviderTransportRetry 9, ProviderSecret 1, SecretLeak 2, WalletRungWire 10, AgentConnection 20, ProviderStream 11, ProviderStreamFamilies 5, ProviderRetry 12, ProviderProxy 4, Provider 20, OpenAIAdapter 6, GeminiAdapter 4, CompatibleAdapter 6.
- (QA) Batch-4 files: new `src/OcuPilot/Test/ProviderStubSeam.cls` (7 tests, in process, no socket, unarmed: it calls each stub's `IssueHttpsPost` on a bare request and does not read `OCUPILOT_ALLOW_ERROR_SEED`), extended in place `src/OcuPilot/Test/ProviderSecret.cls` (`TestTheCanonicalFamilyWritesBothForcedEntriesThroughTheSharedTransportAndNoneCarriesTheKey`, one `Reset` line in `OnAfterOneTest`; already armed, no roster change). `ProviderStubSeam` joins the batch-4 Class loop; `ci.test.mjs` 87 of 87 and `ci-shards.test.mjs` 34 of 34 green.
- `mutation:` (DW-1191, QA) each applied to the Transport body on `ocupilot-ci`, reverted from git, `git hash-object` equal to HEAD after every revert:
  - the empty-script reply answers the Anthropic body for every family → `ProviderStubSeam.TestAnEmptyScriptAnswersTheCanonicalFamilyAReplyAndTheOthersNone` red on the three other families (run 4);
  - the `timeout` branch dropped → `TestEveryStubServesEveryScriptKindTheSameWay` red on all four stubs, and `TestAnArmedRowMoveIsKeptThroughACallThatDoesNotAnswerAndSpentByOneThatDoes` red on its timeout leg (run 5);
  - `HeaderNames` without its empty-value skip → `TestEachStubReportsItsOwnWatchedHeadersAndNoOthers` red on the bare-request leg of all four stubs (run 6); the canonical stub's `WATCHEDHEADERS` without `anthropic-version` → the same test red on the canonical leg and its partial-request leg (run 12);
  - `keyMatches` recorded as a constant 1 → `TestTheKeyCompareRecordsAnEqualityAndNeverTheKey` red on its mismatch and no-key legs (run 7); the compared header's value also recorded under `call(n, "key")` → the same test red on its recording walk alone (run 8);
  - `MoveArmedRow` called before the script kind is read → `TestAnArmedRowMoveIsKeptThroughACallThatDoesNotAnswerAndSpentByOneThatDoes` red on all six non-answer legs (run 9); its disarming `Kill` dropped → the same test red on both answer legs (run 10);
  - the literal `"stub"` for `..#STUBIDENTITY` in `ProviderStub.IssueHttpsPost` (full reload) → `TestOneRecordingAndOneClockServeEveryStub` red on the `ProviderStubAlt` call and the last-identity leg (run 11);
  - the armed check dropped from `Transport`'s `ForceErrorLog` → `TestAnUnarmedRunForcesNoErrorLogEntryThroughAnyStub` red on all four stubs (run 17).
- `mutation:` (DW-1191, AD-48, QA) `ProviderSecret`, the canonical family through the shared transport:
  - `Transport` skipping its forced entry for the canonical stub alone (`If pIdentity '= "stub"`) → `TestTheCanonicalFamilyWritesBothForcedEntriesThroughTheSharedTransportAndNoneCarriesTheKey` red on its refusal count (1 of 2), raise count and read-back count, while `TestNoCredentialMaterialReachesTheLogsOrTheEnvelope` stays green on its `> 0` canonical legs (run 14); dropping the call for every stub reddens both tests (run 13);
  - the compared `x-api-key` bound to a local inside the compare's own branch → the new test red on the refusal's entries, "no local at any stack level carries credential material", the sweep above green because it arms no compare (run 15).
- (QA) After the reverts and a full reload (0 errors), on `ocupilot-ci`: ProviderStubSeam 7 (run 18), ProviderSecret 2 (19), SecretLeak 2 (20), WalletRungWire 10 (21), AgentConnection 20 (22), ProviderTransportRetry 9 (23), ProviderProxy 4 (24). `check-objectscript.py` 0 problems on both changed `.cls`; `git hash-object` of `ProviderStubTransport.cls` and `ProviderStub.cls` equals HEAD. The M8 mutation wrote application-error entries into the throwaway's own `^ERRORS`, which cannot be un-logged.
- `mutation:` (DW-1191, review) Each applied to `Transport` at HEAD on `ocupilot-ci`:
  - the stream branch dropped → `ProviderStubSeam.TestAnArmedRowMoveIsKeptThroughACallThatDoesNotAnswerAndSpentByOneThatDoes` red on its stream leg alone, and `TestEveryStubServesEveryScriptKindTheSameWay` green (run 25);
  - `BodyOf` answering `""` → `TestOneRecordingAndOneClockServeEveryStub` red on its five body legs alone (run 26).
  - Each was reverted from git; `ProviderStubTransport.cls` is byte-identical (`cfe6e4bd`).
  - After the review patches and a reload (0 errors), all green: ProviderStubSeam 7 (run 27), ProviderSecret 2 (28), SecretLeak 2 (29), ProviderRetry 12 (30), ProviderTransportRetry 9 (31), Provider 20 (32), AgentConnection 20 (33), WalletRungWire 10 (34), ProviderStream 11 (35), ProviderStreamFamilies 5 (36), ProviderProxy 4 (37), OpenAIAdapter 6 (38), GeminiAdapter 4 (39), CompatibleAdapter 6 (40), ProviderPort 20 (41), Adapter 25 (42).
  - `check-objectscript.py` 0 problems; `npm run test:tools` 2087 of 2087.

## Auto Run Result

Status: done
Blocking condition: none

**This pass (implement, batch 4).** DW-1191 and DW-2486 only. Batches 1 to 3 closed in their own passes.

- **Changed:**
  - `Test/ProviderStubTransport.cls`: `Transport` takes `pEmptyReply` and `pKeyHeader` and answers the `connectrefused` kind; the class doc says it is the one body behind every stub.
  - `Test/ProviderStub.cls`: `IssueHttpsPost` is one call to `Transport`; `HeaderNames`, `BodyOf` and `MoveArmedRow` are deleted (427 to 319 lines); the docs name `Transport`.
  - `Api/Error.cls`: one doc clause on `AGENTBADBODY`.
- **Review:** 10 findings (verification-gap, intent-alignment); 1 patched (low: three mutation lines), 9 rejected with reasons in the triage log, none deferred. Follow-up review recommended: false.
- **Verified on `ocupilot-ci`:** Load with 0 errors; the 13-class `Batch 4` list green before the edit (runs 1-13) and after (14-26, and again 33-45) with the same totals; the mutations on the `mutation:` line each red and reverted byte-identical. `check-objectscript.py` 0 problems, `npm run test:tools` 2087 of 2087, `lint-docs.sh` 0 issues.
- **Residual:** none.
