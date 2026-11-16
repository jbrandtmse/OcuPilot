---
title: 'Story 24.9: Environment promote (between two namespaces of this instance, documents only)'
type: 'feature'
created: '2026-11-16'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** Story 24.8 shows which classes and routines differ between this namespace and another one on this instance, but nothing moves them. The sibling suite's promote is a four-gate write (plan, execute with confirmation, a steps allow-list, plan-hash freshness) with no rollback. OcuPilot has no promote, and owner answer U-45 limits it to namespaces of this instance.

**Approach:** Extend 24.8's `DevToolPort` `NamespaceDiff` endpoint with two port-composed types. `PLAN` derives the ordered plan from the full diff and its hash. `PROMOTE` re-derives the plan, checks it, and writes each chosen document into the other namespace through `AtelierPort`'s own save, create and compile, stopping at the first failure. A new destructive write tool, `explorer.namespacediff.promote`, has two callers on the Compare namespaces screen: checked rows, a dry-run review and a typed-name confirmation; and the agent's confirmed proposal. Its governance key ships `false`. The screen and the proposal both say there is no rollback.

## Boundaries & Constraints

**Always:**

- **Direction.** The source is the route's namespace (the screen's scope). The target is the read's `target`. Nothing is ever written to the source.
- **The four gates, all on the instance, all before any write:**
  1. **Plan.** The plan is derived from 24.8's `DiffRows` over the whole spec, with no row cap:
     - Steps are every `Only in this namespace` and `Content differs` row, in `Document` order. An `Only in this namespace` step is a create; a `Content differs` step is a save.
     - Every `Only in the other namespace` row is a warning. It is never a step, never deleted, and only counted.
     - `PlanHash` is the SHA-256 hex of the plan's rows (steps and warnings), each `Document|Change|Hash|OtherHash` on its own line, in `Document` order. Times are left out.
  2. **Execute with confirmation.** A person confirms through the dry-run review and the typed-name dialog. The agent confirms through its proposal (AD-6, AD-40).
  3. **Steps allow-list.** The tool's id is the set of 1 to `AtelierPort.MAXDOCUMENTS` (100) document names. Every name must be a step of the fresh plan; any other name refuses the whole request.
  4. **Freshness.** A person's action carries the dry run's digest as `Reviewed`. The agent's proposal fingerprints `PlanHash`. The port re-derives the plan inside the write and refuses on any difference.
- **`DevToolPort` gate order for `PLAN` and `PROMOTE`:**
  1. 24.8's steps 1 to 9, unchanged. Both namespaces must pass their read gates, and the count cap applies to each.
  2. `%SYS` as either namespace is refused, and so is a step name beginning with `%`.
  3. The allow-list and the cap.
  4. For `PROMOTE` only:
     - `AtelierPort.WritePairs(target)`, evaluated.
     - The `Reviewed` comparison.
     - A preflight that reads every chosen document's source text and, for a save, the target's text and version.
     - The storage guard: a class whose target copy has a `Storage <name>` definition that its source copy lacks refuses the whole promote.
  Only after all of that does it write anything.
- **Writes go through `AtelierPort.Invoke` only:**
  - a save is `SAVE` with the version the preflight read, and never `ignoreConflict` (AD-61 rule 3);
  - a create is `CREATE`;
  - both are sent with `Compile` 0;
  - then one `COMPILE` per kind (classes, then routines) with the constant flags `cuk` (`AtelierPort.IMPORTCOMPILEFLAGS`, the sibling's).
  - A save or create that fails stops the promote. No compile runs, and every later step reads `Not attempted`.
  - A compile's errors are reported, not rolled back.
- **Answer.** The answer is 200 with `{documents: [{Document, Outcome, Reason}], lines, errors, stopped}`. It reaches the screen and the card only (AD-39). The write records OcuPilot's own `ConfigChange` from either caller (`Kernel.Audit.Event.Record`), because the vendor records none for `PUT doc` or compile.
- **Self-protection is the kernel's, unedited.** The tool's target type is `class` and its id is the document set, so `Prohibited.Prohibits` reaches `Code(tId)`. A document whose name begins with `OcuPilot`, in any case, is refused `PROHIBITED.OCUPILOTCODE` at the mint, at the Confirm and at the person's action. The dry run evaluates no prohibited set (`ScreenAction.DryRun`), so it may show such a step and the action refuses it. Only `.cls`, `.mac`, `.int` and `.inc` documents exist in a plan, so no global, mapping or package is ever written.
- **Agent fence.** The agent's mint and its Confirm ask `ExplorerSave.AgentProblem(target, name, create)` for each step, unchanged. A person's action does not ask it.
- **Governance and copy.** The governance key `explorer.namespacediff.promote` is destructive and ships `false` (AD-22). A person's action never asks it (AD-53). The proposal card and the dialog state the absence of a rollback in one sentence, and the card carries no "Reverse:" line.

**Never:**

- No HTTP request and no `%Net.*` (NFR-6). No remote profile.
- No delete of anything, in either namespace.
- No mappings, default settings, web applications or configuration are promoted (U-45, DW-2635, DW-2636).
- No edit to `Port/Harvest/*`, `Port/HarvestPort.cls` or `Kernel/Proposal/Prohibited.cls`. No `%Api.Atelier` name outside `AtelierPort`. No sibling name in a comment.
- No `work` routes. No caller value in SQL. No path (AD-21, AD-61 rule 7).
- No workflow catalog entry (AD-66 named limit stays true). No new AD or spine edit by this run.
- DW-2634 is never touched or worked around: promote runs as the signed-in user, with no escalated frame.

## I/O & Edge-Case Matrix

**Fixture.** `Test/DevToolProbe.MakePair("USER", "HSCUSTOM")`, reused unchanged from 24.8 (short names below stand for `OcuProbe248.<Name>.cls`, and `Mac` for `OcuProbe248Mac.mac`):

- `Same` is identical in both namespaces.
- `Changed` differs.
- `OnlyHere` and `OcuProbe248Mac.mac` are in USER only.
- `OnlyThere` is in HSCUSTOM only.

**Request shape.** The source is USER, `target` is HSCUSTOM, and the spec is `OcuProbe248.*.cls,OcuProbe248*.mac`. Each row is observed on `ocupilot-b-ci` through the operation the route runs (`Api.ScreenAction`). The rows Promote, Stale and Agent are also observed in the browser or through tool dispatch.

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Plan | `PLAN` read, id `Changed,OnlyHere,Mac` | The three steps, one warning (`OnlyThere`), and a 64-hex `PlanHash`. It is equal across two reads and differs after `Changed` is re-saved in HSCUSTOM. | none |
| Promote | dry run, then action with its `Reviewed` | HSCUSTOM's `Changed`, `OnlyHere` and the `.mac` hash equal USER's, and the classes are compiled. `OnlyThere` and `Same` are untouched. A fresh diff lists only `OnlyThere`. The outcomes read `Replaced`, `Added`, `Added`. One `ConfigChange` row. | none |
| Allow-list subset | id `Changed` only | Only `Changed` is written; `OnlyHere` stays absent in HSCUSTOM | none |
| Not a step | id holds `OcuProbe248.Same.cls` or `OcuProbe248.OnlyThere.cls` | 400 `EXPLORER.PROMOTE.NOTASTEP`, `detail.document` naming it | nothing written, not logged |
| Stale | `Reviewed` taken, then `Changed` re-saved in HSCUSTOM | 409 `EXPLORER.PROMOTE.STALE` | nothing written; HSCUSTOM keeps the re-saved text |
| Own code | source HSCUSTOM, target USER, an `OcuPilot.*` document (Task 0 picks it) | `PROHIBITED.OCUPILOTCODE`, with the kernel's own status, at the action and at the mint | USER gains nothing |
| System | `target` `%SYS`; or a `%`-named step | 400 `EXPLORER.PROMOTE.SYSTEM` | nothing written |
| Write gate | `HSCUSTOM`'s routines resource `:WRITE` denied through the `ScreenGate` seam | 403 `AUTH.NOPRIVILEGE`, `detail.failedPair` naming it | nothing written |
| Storage | `DevToolProbe.MakeStoragePair` (new): a persistent probe class saved uncompiled, with no `Storage`, in USER, and compiled, with its `Storage`, in HSCUSTOM; `RemoveStoragePair` removes both | 409 `EXPLORER.PROMOTE.STORAGE`, `detail.document` | nothing written |
| Stop | the fixture seam fails the second save | the first is `Replaced`, the second `Failed` with its reason, the third `Not attempted`; no compile ran; `stopped` is true | 200; no rollback |
| Too many | 101 names | 400 `PORT.VALIDATION` | nothing written |
| Agent | `explorer.namespacediff.promote` dispatched with the Promote id, its key enabled by the test | The proposal card lists the steps, the warning count and the no-rollback consequence. Confirm writes as in Promote. A re-save of `Changed` in HSCUSTOM between mint and confirm refuses the confirm as target-changed. With the key at its shipped `false`, it is refused by governance. | per AD-6 |

</intent-contract>

## Code Map

### Port

- `src/OcuPilot/Port/DevToolPort.cls` (509 lines) is the class to extend:
  - the header's ordered gate list (:6-30) and answers paragraph (:31-35);
  - `TYPELIST` (:68);
  - `Invoke` (:181-269); its endpoint/type check (:206) admits only `LIST` today;
  - `DiffRows` (:425-460, pure, takes `pMax`; call it with 0 for the plan);
  - `SnippetForm` and `Snippet` (:462-472) answer nothing today;
  - `Refuse` (:482), `Deny`, `Fail`.
  - Seams: `GateClass`, `HarvestPortClass`, `MaxDocuments`, `LogFault`. Add an `AtelierPortClass()` seam so a fixture can fail a chosen save.
- `src/OcuPilot/Port/AtelierPort.cls` is the write path, called only through `Invoke` (:874):
  - Types: `TYPESAVE` (:364), `TYPECREATE` (:373), `TYPECOMPILE` (:337).
  - Keys: `content`, `version` (:411), `Compile` (:422), `names` (:458), `namespace` (:491).
  - The document read is the `Class` and `Routine` endpoints' `LIST`. `Document` (:2779) answers `pDocument {content, modified, ...}`; `modified` is the save's version. `ExplorerSaveMint.cls:65` is the model call, and `ExplorerSaveMint.JoinLines` (:205) joins lines into the save's text.
  - `SaveSet` (:2545) refuses a header that does not name the document (422 `EXPLORER.SAVE.HEADER`), a conflict (409) and a lock.
  - `CompileSet` (:1896) answers `{lines, errors}`.
  - `IMPORTCOMPILEFLAGS="cuk"` (:439), `MAXDOCUMENTS=100` (:471), `WritePairs` (:788), `DatabaseResources` (:719).
  - Read-only for this story.

### Kernel (read-only)

- `src/OcuPilot/Kernel/Proposal/Prohibited.cls`: dispatch :1546 (class or routine type, then `Code(tId)`), `Code` :2742, `IsOcuPilotCode` :2909. It needs no edit, provided `WRITETYPE` is not `EXPORT` or `RUN`.
- `src/OcuPilot/Kernel/EntityRef.cls`: `class:documentset` (:59, `DocumentSet` :394) sorts and uniques any names. `ScopeFor` (:253) is the request's namespace, so the target ref and the lock are keyed on the source namespace's set.
- `src/OcuPilot/Kernel/Audit/Event.cls`: `EVENTCONFIG` and `Record`. Model call: `AnalyticsPort.cls:2040`.

### Tool

- `src/OcuPilot/Screen/Tool/Write.cls` is the base. The parameters used here are `DRYRUN` (:188), `READSVALUES` (:182), `SCREENVALUES` (:238), `SCREENOPTIONAL` (:244), `FINGERPRINTSUBJECT` (:97) and `PRECONDITIONFIELD` (:105). The methods used are `DryRunReview` (:405), `PortQuery` (:485), `StateDiff` (:551), `ScreenActionDelta` (:795), `ConfirmProblem` (:1012) and `MintClass` (:606).
- Model tools:
  - `Screen/Tool/InteropItemChangeClass.cls` (DRYRUN and `Reviewed`/`Digest`, :32-112);
  - `Screen/Tool/InteropMessageResend.cls` (a checked set with a dry run);
  - `Screen/Tool/ExplorerImport.cls` (destructive, `CONSEQUENCE`, `WriteOutput`);
  - `Screen/Tool/ExplorerImportMint.cls` (mint subclass).
- `Screen/Tool/ExplorerSave.cls`: `AgentProblem` (:186) and `ConfirmProblem` (:244).
- `Screen/Descriptor/ExplorerNamespaceDiff.cls`:
  - `"id": {"kind": "none"}` becomes `single`;
  - `rowActions` gains `promote`;
  - add `"multiSelect": {"action": "promote", "eligible": "Promotable", "max": 100, "ineligibleKey": ...}` (model: `ProcessList.cls:142`);
  - the read and context fields gain `Promotable`, so `DiffRows` answers it: true unless the row's `Change` is `Only in the other namespace`;
  - the header sentence "It declares no action" changes.
- `Api/ScreenAction.cls`: `DryRun` (:142), `Run` (:258), answer `output` (:445-457).

### Client

- `ui/src/app/areas/system-explorer/dev-tool.page.ts` (327 lines) draws `DataTable` and registers only refresh (:159-162). `dev-tool.store.ts` (97 lines).
- `ui/src/app/shell/screen-action-handler.ts`:
  - `DRY_RUN_ACTIONS` (:415) and `CHECKED_SET_DIALOGS` (:427);
  - `startDryRun`, `openReview` and `confirmReviewed` (:1605-1659), which draw the handler's own `TypedNameDialog` with review lines;
  - `lastOutput` (:1815).
- `ui/src/app/core/screen-actions.ts`: `DESCRIPTOR_ACTION_LABELS` (:104-110, :292-296).
- `ui/src/app/shell/data-table.ts`: checkboxes when `multiSelect` is set (:685-743).
- `ui/src/app/core/multi-select.ts`: `isCheckable` (:31) reads `eligible`.
- `ui/src/app/areas/system-explorer/code-list.page.ts` (:192-205) is the model for the output pane: `data-explorer-write="status"` and `"output"`.
- `ui/src/app/core/proposal-view.ts:222` maps a consequence code to its sentence.
- `ui/src/app/core/strings.ts`: 24.8's block is at :4940-4968, and every key cites `EXPERIENCE.md:<line>`. EXPERIENCE.md's Fixed strings row for 24.8 is :594.

### Tests and rosters

- `src/OcuPilot/Test/DevToolProbe.cls` (`MakePair` :151, `RemovePair` :184), `DevToolPortFixture.cls` and `NamespaceDiffRead.cls` (389 lines; it gains `Promotable` in its row-shape assertions).
- Rosters a new write tool joins (append, or re-derive a count):
  - `ExplorerDescriptor` :161 (fifteen writes become sixteen), :162 (writer signature), :171 (baseline key order), :176 (NamespaceDiff's `||`).
  - `SurfaceCoverage` XData (:437-447).
  - `ToolRoundTrip` `REFUSEEMPTY` :104.
  - `ReadTool` :94-95 (count and names).
  - `DeveloperFloor` :45 and :52.
  - `DraftRegistry` :143 and :235.
  - `ToolEmit` :158 and :207-219.
  - `Prohibited` test :458, if a composed-type count is needed.
  - `GovernanceBaseline.DISABLED` :15, `Governance.EXPLORERDISABLED` :33, and `Kernel/Governance/Baseline.cls` (the `explorer.*` block :204-219).
  - `ui/tools/screen-mirror.test.mjs` :1085-1100 (the multiSelect roster and its compile-shape exceptions).
- Browser model: `ui/browser/system-explorer-write.browser-spec.mjs`:
  - assert the throwaway (:46-48);
  - `check()` (:120-131);
  - `commandBar()` (:134-144);
  - the typed-name dialog (:210-216).
  `ui/browser/namespace-diff.browser-spec.mjs` is 24.8's.

### Sibling (read-only)

`/Users/jbrandt/git/iris-execute-mcp-v2/packages/iris-dev-mcp/src/tools/env-promote.ts` at `c6aad31`. Take only its rules, never its code or names:

- `buildDocumentsSteps` (:256-280): target-only rows are warnings.
- `buildPlan` (:389-425): sorted by subject.
- the four gates (:1108-1256);
- `runDocumentsBatch` (:912-1011): saves in order, stop at the first failure, then one compile, `cuk`;
- the storage guard (:861-897, :1301-1310).

Its plan hash is over the caller's diff. Here the hash is re-derived on the instance, so its gate 3b (steps consistent with the diff) holds by construction.

## Tasks & Acceptance

### Task 0, before code, on `ocupilot-b-ci`

Record each answer under Design Notes:

- (a) Does `EntityRef.Key("class", ..., "OcuProbe248.Changed.cls,OcuProbe248Mac.mac")` succeed? Does `Prohibited.Prohibits` refuse a set holding an `OcuPilot*` name under this tool?
- (b) Pick an `OcuPilot.*` document that HSCUSTOM holds and USER does not, for the Own code row. If USER sees every one, the row instead drives `Prohibits` with this tool's name and a set holding that name, and the spec records which was used.
- (c) Does a class text read through `Class` `LIST` in USER save into HSCUSTOM through `SAVE` with the target's `modified`? Does a `.mac` create through `CREATE`?

### Execution, batch 1 (server; commit when its loop commands are green)

- `src/OcuPilot/Port/DevToolPort.cls`:
  - Add `TYPEPLAN="PLAN"`, `TYPEPROMOTE="PROMOTE"`, and the keys `documents`, `reviewed` and `planHash`.
  - Add the reasons and codes from Design Notes, and the outcome words.
  - Admit both types for `ENDPOINTNAMESPACEDIFF` only.
  - Implement the gate order from Always.
  - Add a pure `Plan(pHere, pThere)` that answers steps, warnings and `PlanHash`, beside `DiffRows`.
  - Add `Promote`, which holds the preflight, the storage guard, the ordered writes, the stop and the compiles.
  - Add the `ConfigChange` record.
  - `DiffRows` answers `Promotable`.
  - `SnippetForm` answers `objectscript` for `NamespaceDiff`/`PROMOTE`. `Snippet` renders one line per step that copies the document's text from the source to the target with the vendor's class or routine text API, closing every block on its line, then one `$System.OBJ.CompileList` per kind with `cuk` (AD-59).
  - Update the header.
- `src/OcuPilot/Screen/Tool/ExplorerNamespacePromote.cls` (new):
  - The base is `Write`. It extends no Explorer tool, because their port is `AtelierPort`.
  - `TOOLNAME` `explorer.namespacediff.promote`; `DESCRIPTORCLASS` `ExplorerNamespaceDiff`; `PORTCLASS` `DevToolPort`.
  - `READTYPE` `PLAN`, `WRITETYPE` `PROMOTE`, `SENDSBODY` 0, `READSVALUES` 1, `DRYRUN` 1, `DESTRUCTIVE` 1, `CHANGEACTION` `updated`.
  - `SCREENACTIONS` `promote`; `SCREENVALUES` `promote=target:spec:generated:Reviewed`; `SCREENOPTIONAL` `promote=Reviewed`.
  - `READANSWERS` `Namespace,Target,Spec,Generated,Steps,Warnings,PlanHash,Reviewed`; `FINGERPRINTSUBJECT` `Steps,Namespace,Target,Spec,Generated,PlanHash,Reviewed`; `PRECONDITIONFIELD` `Steps`.
  - `CONSEQUENCE` `EXPLORER.PROMOTE.NOROLLBACK`.
  - Methods:
    - `IdArgument` is `Documents`;
    - `ArgumentPairs` is WRITE on the target's routines database, through `AtelierPort.DatabaseResources`;
    - `ScreenActionDelta`, `PortQuery` and `DryRunReview` return `{Digest: PlanHash}`;
    - `StateDiff` gives one row: the steps, as `<Document> -- <Change>` lines, then the warning count line;
    - `ConfirmProblem` asks `AgentProblem` for each step;
    - `WriteOutput`, `Consequence` and `InputSchema` (`target`, `spec`, `generated`, `Documents`, rationale, expectedImpact; no `reverse`).
  - `DESCRIPTION` is in Design Notes.
- `src/OcuPilot/Screen/Tool/ExplorerNamespacePromoteMint.cls` (new; `Kernel.Proposal.Mint` subclass, on `ExplorerImportMint`'s model): the set's shape, `%` and `%SYS`, and `AgentProblem` for each step (a create for `Only in this namespace`), then `##super`.
- `src/OcuPilot/Screen/Descriptor/ExplorerNamespaceDiff.cls`: the Code Map's edits, then regenerate `Screen/Titles.cls` if it changes.
- `src/OcuPilot/Kernel/Governance/Baseline.cls`: `"explorer.namespacediff.promote": false,`.
- `src/OcuPilot/Test/DevToolProbe.cls`: add `MakeStoragePair` and `RemoveStoragePair` for the Storage row; `MakePair` and `RemovePair` stay unchanged.
- `src/OcuPilot/Test/DevToolPortFixture.cls`: the `AtelierPortClass` seam. Add a small recorder class that fails the save of one named document and passes everything else on to `AtelierPort`.
- `src/OcuPilot/Test/NamespacePromote.cls` (new, under 500 lines; its header says what it pins and that it needs USER and HSCUSTOM):
  - every matrix row except Agent;
  - each refusal asserts HSCUSTOM unchanged (hashes read through `DocumentHashes`);
  - `OnBeforeOneTest` and `OnAfterOneTest` reset the fixtures and call `RemovePair`.
- `src/OcuPilot/Test/NamespacePromoteAgent.cls` (new): the Agent row, through tool dispatch, mint and Confirm. It enables the key through the stored per-key setting (the `GovernanceFixture` pattern) and restores it.
- Rosters: every pin in the Code Map. Counts are re-derived. `NamespaceDiffRead` gains `Promotable`.

### Execution, batch 2 (client)

- `ui/src/app/areas/system-explorer/dev-tool.page.ts`. When the descriptor declares `promote`:
  - register it with `ScreenActions`, its label "Promote";
  - its run sends the checked set (`checkedSetTarget`) with the sent target, spec and generated values through `ScreenActionHandler.startDryRun`, typed name = the target namespace;
  - draw the status line and output pane from `lastOutput()` (code-list's markup and attributes);
  - clear the checked rows after an applied promote;
  - the list re-reads by its own change event (scope = this namespace).
  - Add `.spec.ts` cases for the registration, the values sent and the output.
- `dev-tool.store.ts`: the sent criteria the action needs, if the store does not already expose them.
- `ui/src/app/shell/screen-action-handler.ts`: append `ExplorerNamespaceDiff: ['promote']` to `DRY_RUN_ACTIONS` and `{promote: 'dry-run'}` to `CHECKED_SET_DIALOGS`, if the page uses the checked-set path.
- `ui/src/app/core/screen-actions.ts`: append the label.
- `ui/src/app/core/proposal-view.ts`: the consequence code.
- `strings.ts`, `screens.generated.ts` (`node tools/screen-mirror.mjs`) and EXPERIENCE.md's Fixed strings: add-only, each with its line citation, as 24.8 did.
- `ui/tools/screen-mirror.test.mjs`: the multiSelect roster and exception.
- `ui/browser/namespace-promote.browser-spec.mjs` (new):
  1. Assert the throwaway, then `MakePair` through `runIris`, with `RemovePair` in `after`.
  2. In USER, choose HSCUSTOM, enter the Diff spec and wait for the answered signal.
  3. `OnlyThere`'s checkbox is ineligible. Check `Changed` and `OnlyHere`, and run Promote.
  4. The dialog's review lists both steps and the one-warning line, and its consequence is the no-rollback sentence. Type `HSCUSTOM` and confirm.
  5. The status reads the success sentence, and the list re-reads to `OnlyThere` and the `.mac`.
  6. `runIris` confirms HSCUSTOM's hashes equal USER's for the two.

### Acceptance Criteria

- **AC1.** Given environment promote between USER and HSCUSTOM on `ocupilot-b-ci`, when the matrix's Promote row runs, then it round-trips over its backing class: each promoted document's hash in the target equals its source hash (`EnvSync.DocHashes`), it is compiled, and a fresh diff no longer lists it. Allow-list subset holds as its row says.
- **AC2.** Given each refusal row (Not a step, Stale, Own code, System, Write gate, Storage, Too many), when it runs, then it answers its status and code, and the target's hashes are unchanged.
- **AC3.** Given a save that fails mid-promote, when the promote stops, then the answer reports each document's outcome, no compile ran, and nothing earlier is undone. The dialog, the card and the agent tool's description each state that there is no rollback.
- **AC4 (Integration).** Given the Compare namespaces screen on the redeployed bundle, when a person checks two rows and confirms Promote, then the browser shows the review, the typed-name confirmation and the outcome, and the target holds the source's text.
- **AC5 (Integration).** Given `explorer.namespacediff.promote` through tool dispatch with its key enabled, when the person confirms its proposal, then the target holds the source's text. With the key at its shipped value, governance refuses the call.

## Spec Change Log

## Review Triage Log

## Design Notes

**Governing ADs (Rule 6):**

- AD-6, AD-34, AD-40: proposal, fingerprint and Confirm.
- AD-10: `OCUPILOTCODE` by name, in any namespace, unedited.
- AD-13: the `class:documentset` id.
- AD-14: one change event.
- AD-15: own `ConfigChange`.
- AD-16: switches.
- AD-21: no path, no SQL.
- AD-22: key `false`.
- AD-23: no body edited.
- AD-29 and AD-61 rules 1, 3 and 7: per-namespace gates, WRITE on the target, version-seeded saves, no `work` routes.
- AD-36: one card.
- AD-39: output to the screen and card only.
- AD-51: action-style, with a port-composed fresh read.
- AD-52: the declared port is `DevToolPort`.
- AD-53: two callers, the dry run, the agent's fence.
- AD-58: action-style read-back says nothing was sent.
- AD-59: `Snippet`.

Checked and not engaged: AD-62 and AD-65 (no interoperability or analytics), and AD-64.

The governing spine is unchanged. AD-66's "promote, Story 24.1" line and `DevToolPort` in AD-29's Binds still wait for the owner's attended update.

**The four gates in OcuPilot's write model.**

| Gate | Person | Agent | Where it holds |
|---|---|---|---|
| Plan | the dry run (`DryRunReview`) | the mint's fresh `PLAN` read | the port re-derives it at the write |
| Execute with confirmation | the typed-name dialog | Confirm | AD-40 |
| Steps allow-list | the checked rows | the `Documents` argument | a name outside the fresh plan refuses the whole request |
| Plan-hash freshness | `Reviewed` | the fingerprint | both compared again inside the write |

The sibling also has a fourth gate on the target profile's governance. It has no subject on one instance: AD-22's single key governs the agent, and a person is never governed (AD-53).

**Decided in-stage:**

- **Compile is part of a promote.** The sibling compiles every batch, and promoting uncompiled code would leave the target running old code. It compiles once per kind, with `cuk`, after every save has succeeded.
- **The hash covers the whole plan,** warnings included, as the sibling's covers the whole diff. A change to any document the pattern matches makes the plan stale.
- **The storage guard is taken without its override.** The sibling's `allowStorageRegeneration` is not offered. This is stricter, and safe.
- **`%SYS` and `%` names are refused** on both callers. This is stricter than the agent-only `AgentProblem`, and there is no classic promote to compare with.
- **A person's promote is not fenced to the target's own routines database.** A person's Save is not either (AD-53). The agent's is.
- **The answer is 200 with per-document outcomes,** following `DeleteSet`'s per-item results. Refusals before any write are faults.
- **The typed name is the target namespace.** The confirmation is about where the writes land.
- **`Promotable` is a read field**, so the table's existing `eligible` mechanism draws a target-only row ineligible. Own-code and `%` rows stay checkable and are refused by the server, with the kernel's sentence.
- **The audit record is OcuPilot's own `ConfigChange`,** following the interoperability writes' AD-15 named cases, rather than a named gap like 19.2's. Recording more is the safe side.

**Named limits:**

- Documents only: no mappings, default settings, web applications or configuration.
- No rollback; the replaced text is not kept.
- The lock key is the source namespace's set (`EntityRef.ScopeFor`). Two promotes from different namespaces into one target are ordered by the vendor's version check (409), not by OcuPilot's lock.
- The target's own Classes list does not re-read until it is opened again.
- A promote past the Web Gateway's timeout loses its answer, while its writes continue (AD-7, inference).
- There is no promote workflow (AD-66).

**Proposed spine clauses** (for the runner's spec gate; a veto item, never written by this run):

- AD-51: a named case, `DevToolPort`, which composes `PLAN` and `PROMOTE` from the declared target, spec, generated and document set.
- AD-52: `DevToolPort` sequences `AtelierPort` saves, creates and compiles for one write.
- AD-15: a named case, promote records OcuPilot's own `ConfigChange`.
- AD-22: the key `explorer.namespacediff.promote` ships `false`.

**Contended or more-than-appending edits** (check `origin/OCU-1-epic21` before implement):

- `DevToolPort.cls` (gate and types)
- `ExplorerNamespaceDiff.cls` (id kind, actions, field)
- `dev-tool.page.ts` and `dev-tool.store.ts`
- `NamespaceDiffRead.cls` (row shape)
- `ExplorerDescriptor` :161, :162, :176
- `ReadTool` :94 (count; Epic 21 also edits it)
- `ToolEmit` (a new branch)
- `screen-mirror.test.mjs` :1098-1100 (the exception condition)
- `GovernanceBaseline.DISABLED` and `Governance.EXPLORERDISABLED` (sorted inserts)

Add-only:

- `Baseline.cls`
- `SurfaceCoverage`
- `ToolRoundTrip`
- `DeveloperFloor`
- `strings.ts`
- EXPERIENCE.md
- `screen-action-handler.ts`'s two maps
- `screen-actions.ts`
- `proposal-view.ts`

`Prohibited.cls` is not edited, although Epic 21 edits it.

**Extend, don't copy (Rules 2, 31):**

- The port, the diff (`DiffRows` and its `Plan`), the descriptor, the page, the store, the dry-run handler, the probe and the fixture are all extended.
- The tool is new, because AD-5 gives one tool per write. It is modeled on `InteropItemChangeClass` and `ExplorerImport`.
- Its mint follows `ExplorerImportMint`.
- `NamespacePromote` is a new class because `NamespaceDiffRead` is 389 lines and holds the read.

**Integration ACs:** AC4 and AC5.

- **Consumes:**
  - `DevToolPort` `NamespaceDiff` (24.8);
  - `AtelierPort` `Class`/`Routine` `LIST`, `SAVE`, `CREATE` and `COMPILE` (19.1, 19.3, 20.20);
  - `ExplorerSave.AgentProblem`;
  - `Prohibited.Code`;
  - `Api.ScreenAction` `DryRun` and `Run` (20.31);
  - `ScreenActionHandler.startDryRun`;
  - `Kernel.Audit.Event`.
- **Consumed-by:** no later story consumes promote. Story 24.19's deployment follows the same four-gate pattern, not this code.

**Governance keys:** `explorer.namespacediff.promote`, destructive, default `false`.

**Proposed strings (veto item):**

- Action: "Promote".
- Ineligible row: "A document only in the other namespace is never promoted or deleted."
- Consequence (dialog and card, code `EXPLORER.PROMOTE.NOROLLBACK`): "Each listed document is written into the other namespace, replacing its copy there, and compiled. Nothing there is deleted. There is no rollback: a document written before a failure stays written, and the text it replaced is not kept."
- Review warning line: "<n> documents only in the other namespace stay as they are." · "1 document only in the other namespace stays as it is."
- Outcomes: "Replaced" · "Added" · "Failed" · "Not attempted".
- Status:
  - "Promoted <n> documents to the other namespace and compiled them."
  - "Promoted <n> documents to the other namespace; the compile reported errors."
  - "Promote stopped at <document>. The documents written before it stay written."
- Refusals:
  - `NOTASTEP`: "Choose documents the plan lists as only in this namespace or as differing."
  - `STALE`: "The namespaces changed after this plan was shown, so nothing was written. Compare them again and review the new plan."
  - `SYSTEM`: "Promote works between two namespaces other than %SYS and never writes a document whose name begins with %."
  - `STORAGE`: "A class here lacks a storage definition its copy in the other namespace has, so nothing was written: compiling it there would change how its stored data is read."
  - Count: "Choose 1 to 100 documents to promote."
- Tool `DESCRIPTION` (agent-facing): "Propose promoting classes and routines from the route's namespace into `target`, another namespace of this instance. It changes nothing by itself: it answers a proposal the user reviews and confirms. Read `explorer.namespacediff.read` first with the same `target`, `spec` and `generated`. Name in `Documents` only rows whose Change is 'Only in this namespace' or 'Content differs', at most 100. Each is written into the target, replacing its copy, then compiled. Nothing is deleted. There is no rollback, so say so in the rationale. A document whose name begins with OcuPilot or %, and %SYS, are refused. If either namespace changes before the user confirms, the proposal is refused."

## Verification

**Shared surfaces:**

- the Compare namespaces descriptor (its id kind, actions, multiSelect and `Promotable` field), `screens.generated.ts` and `Titles`;
- the read tool's row shape;
- the write-tool rosters (`ExplorerDescriptor`, `SurfaceCoverage`, `ToolRoundTrip`, `ReadTool`, `DeveloperFloor`, `DraftRegistry`, `ToolEmit`);
- the governance baseline and its disabled rosters;
- the multiSelect roster;
- the dry-run allow-list.

The implement stage greps `ui/browser`, `ui/tools`, `ui/src` specs and `src/OcuPilot/Test` for each of these, and every test it changes joins `(loop)`.

*Every test added or changed passes on a fresh environment, in either order.* Each test makes its own `OcuProbe248` documents in USER and HSCUSTOM, removes them, and asserts only on them and on what it promoted.

**Commands.** Each runs in the foreground with `timeout: 600000`, one call at a time, against `ocupilot-b-ci` only. Never put two test calls in one message.

- `(loop)` `sh /private/tmp/claude-501/-Users-jbrandt-git-OcuPilot/4667058b-f052-49c9-b08a-221f7f41dfab/scratchpad/e24u/24-9/reload.sh /Users/jbrandt/git/OcuPilot/.worktrees/epic-24 ocupilot-b-ci` -- expected: `LOADERRORS=0`.
- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.NamespacePromote`, then the same command for `NamespacePromoteAgent`, `NamespaceDiffRead`, `DevToolRead`, `ExplorerDescriptor`, `SurfaceCoverage`, `ToolRoundTrip`, `ReadTool`, `DeveloperFloor`, `DraftRegistry`, `ToolEmit`, `Prohibited`, `GovernanceBaseline`, `Governance`, `Descriptor` and `Navigation`, one class per call or several `--class` flags under about 170 s -- expected: green.
- `(loop)` `uv run scripts/check-objectscript.py`, `uv run scripts/test_check_objectscript.py` and `bash scripts/lint-docs.sh` -- expected: clean.
- `(loop)` `grep -nE '%Net\.|HttpRequest|ignoreConflict' src/OcuPilot/Port/DevToolPort.cls` -- expected: no match.
- `(loop)` `cd ui && npm run build && npm run test:components`, then `docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`, then `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci node --test --test-concurrency=1 browser/namespace-promote.browser-spec.mjs browser/namespace-diff.browser-spec.mjs` -- expected: green.
- `(loop)` `cd ui && npm run test:tools` -- expected: green.
- `(once)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --shard k/17` for k = 1 to 17, one per call -- expected: green. The full browser suite is left to CI.

**Mutations (Rule 19), one per AC.** Each is applied on `ocupilot-b-ci`, the tree recompiled, the red observed, and the file restored byte for byte:

- AC1: `Promote` skips `CREATE` steps. Expected red: the Promote test.
- AC2: the `Reviewed` comparison is made inert. Expected red: the Stale test, and the Agent test's target-changed leg stays green, which is the fingerprint's.
- AC3: the stop is removed, so the loop continues past a failure. Expected red: the Stop test.
- AC4: the descriptor's `multiSelect.action` is renamed. Expected red: the browser spec.
- AC5: the baseline line is set to `true`. Expected red: the Agent test's governance leg and `GovernanceBaseline`.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none

Planned in one pass (halt after planning). Veto items for the runner's spec gate: the proposed strings, the proposed spine clauses (AD-51, AD-52, AD-15, AD-22), the own `ConfigChange` audit choice, and the storage guard taken without its override. The ledger inbox for this story was empty.
