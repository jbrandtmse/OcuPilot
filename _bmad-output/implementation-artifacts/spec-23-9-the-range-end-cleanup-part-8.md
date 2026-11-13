---
title: 'Story 23.9: The range-end cleanup, part 8'
type: 'bugfix'
created: '2026-11-12'
status: 'done'
baseline_revision: 'df5b1c48c97ff189636782f832ffbf4fad11dfd2'
baseline_commit: 'df5b1c48c97ff189636782f832ffbf4fad11dfd2'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
warnings: ['multiple-goals', 'oversized']
deferred:
  - summary: >-
      The 30,000-node compact in local-databases AC8 might finish before the test pauses it on a loaded CI shard.
    evidence: |-
      Pause took 0.28-0.71 s on an idle throwaway over three probes; the compact's own duration over 30,000 nodes was not measured.
      Settled by CI shard runs of local-databases; the leg errors with "compact reads Completed, not Paused".
    location: >-
      src/OcuPilot/Test/BackgroundSeed.cls PausedCompact; ui/browser/local-databases.browser-spec.mjs AC8
    severity: medium (unverified)
---

<intent-contract>

## Intent

**Problem:** This story owns twelve low-severity ledger entries, each checked at `6cb84d15`; the verdicts are under Design Notes. Two are CI flakes that cost release-path reruns: the a11y structural walk loses 600 s at a time to a page call that never returns (DW-1822), and local-databases loses two tests to a navigation timeout right after a 1.2 GB seed is written and deleted (DW-2512). Two entries are already true at head (DW-446, DW-2060). The rest are a stale doc comment, a stale script docstring and CLAUDE.md line, an own-pair rule the spine states but neither engine enforces, a type check only one engine makes, a test-class floor that misses 19 classes, two duplicated client constants, sixteen copies of one removal-row loop, and two journal inputs with no length limit.

**Approach:** Five area batches, in this order: 1 CI flakes, 2 docs, 3 pair validation, 4 client and runner tooling, 5 the shared removal rows. Each batch is one implement pass and one code commit with CI green on its own head. Each fix gets a test that reddens before it, or the entry says why none can (Rule 19). Every entry ends `resolved-by`, `wontfix-accepted` (with `reopen_if`) or `by-design`, as Design Notes › Dispositions says.

## Boundaries & Constraints

**Always:**

- **Where to work.** `/Users/jbrandt/git/OcuPilot/.worktrees/epic-23` on `OCU-1-epic23`; check `git rev-parse --show-toplevel` first. Every IRIS MCP call carries `server: "ocupilot-slot-a"`.
- **Where tests run.** Tests, probes and mutations run only on `ocupilot-ci` (slot block under Verification), once `docker inspect -f '{{.State.Health.Status}}' ocupilot-ci` reads `healthy`. One test run in flight; wait for each to land in `%UnitTest_Result`; never re-submit after a client-side timeout. Every command runs in the foreground with `timeout: 600000`.
- **Batches.** One implement pass per batch, scoped to that batch's unchecked items. Before each batch, re-run the two read-only Epic 20 checks under Design Notes › Contended.
- **Locating code.** Find code by symbol; line numbers are at `6cb84d15`.
- **Writing code.** Wire codes, HTTP statuses and response bodies stay byte-identical. Extend the sibling named under Design Notes (Rule 31). Comments state the contract (Rule 14); non-ASCII in source is `$Char(n)` or `\uXXXX`. Docs use US spelling.
- **Both engines alike (AD-5).** A pair-validation change lands in `Screen/Registry.cls` and `ui/tools/screen-mirror.mjs` together, with its case in the shared corpus.

**Never:**

- Any edit to `CLAUDE.md`, `.claude/**`, `_bmad/**`, `.github/workflows/ci.yml`, `ui/angular.json` or `ui/tools/ci-timings.json` (generated). Wording CLAUDE.md needs goes to the Planner (Design Notes).
- An edit to `Kernel/Proposal/Prohibited.cls`, `ui/src/app/shell/screen-action-handler.ts`, or any Epic 20 worktree file.
- Replacing `Screen/Tool/Write.cls`'s default `StateDiff`, or any non-add-only edit to `Write.cls`.
- A new error `code`, a stored-schema change, a new on-screen string, or a 22nd `check-objectscript.py` rule.
- A write, load or compile on `ocupilot`; a stop, restart, recreate or `down` of any container; any docker command against a container not named `ocupilot-ci` (and no `docker system prune`).
- Switching `signedInAt` away from `waitUntil: 'networkidle2'`, or raising the 600 s `protocolTimeout`.
- The full browser suite (CI's).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| CHANGED: fonts that never load (DW-1822) | `settle` on a page whose `document.fonts.ready` never resolves and whose `document.fonts.status` turns `loaded` after 1 s | Answers `true` within about 2 s | Today it waits until the protocol limit |
| CHANGED: a walk call that never returns (DW-1822) | A walk-pass `page.evaluate` that never settles | Abandoned after `WALKCALLDEADLINE` (60 s), thrown as an error `isProtocolTimeout` matches, so `retryOnce` re-runs the pass once; the report gains a line naming the pass and route | Today 600 s per try |
| CHANGED: navigation timeout diagnostic (DW-2512) | `signedInAt`'s `goto` rejects with a navigation timeout | Rethrows the same error, its message extended with each request still in flight and its age in ms | Still a failure |
| CHANGED: own pair the area declares (DW-1760) | Area pairs include `%Admin_Operate:USE`; `ownPrivileges: [%Admin_Operate:USE]` | Both engines refuse: `own privilege pair %Admin_Operate:USE is one its area '<key>' already declares, and a screen owns only a pair it requires beyond its area's (AD-8)` | Today accepted |
| Unchanged: screen owning all its pairs | `logs/eventlog`, `logs/analytics` | Accepted | — |
| CHANGED: non-string pair half (DW-1761) | `ownPrivileges: [{resource: 5, permission: "USE"}]`, and the same in `privileges` | The instance answers `declared own privilege pair #1 is missing its resource or its permission` (and `#1` from `MalformedPair` for `privileges`), as the mirror does | Today the instance reads `5` |
| CHANGED: test class through a project base (DW-2259) | `ProviderStream Extends StreamCase`, `StreamCase [Abstract] Extends %UnitTest.TestCase` | `testClassesOnDisk` lists `ProviderStream`, not `StreamCase`; 699 classes at head | Today 680 |
| CHANGED: over-long journal criterion (DW-1981) | Offset and value inputs | `maxlength` 20 and 200, from the declared criteria | Server refusal unchanged |
| Unchanged: delete cards (DW-2299) | Every one of the 16 delete tools' proposal | Same removal rows, field order and values as today | — |

</intent-contract>

## Code Map

### Batch 1: CI flakes

- **DW-1822, measured from the logs** (`scratchpad/e23u/23-9/plan/a11y-*.log`):
  - Normal runs 391-480 s over 25 timing revisions; the slow ones sit about 600 s above (1194.2 on 39992827886 attempt 2, 1912.6 on attempt 1). Run 39922983649 failed all 13 tests in the `before` hook at 1716.0 s, with the stack ending `Frame.evaluate` -> `Runtime.callFunctionOn`.
  - One walk: 190 screens walked, 22 skipped, three passes (570 visits, about 0.73 s each). Per-screen detection is cheap, so the ledger's split would target a cost the data does not show (inference).
- `ui/browser/structural-walk.mjs`:
  - `settle` (:663-676) does `await document.fonts.ready` inside one `page.evaluate`. `SETTLE_TIMEOUT_MS` (20 s) is checked only between loop turns, so it never bounds that call.
  - `trackRequests` (:644-658) counts only `/api/ocupilot` and `.js` requests; the five vendored `.woff2` fonts (`src/styles/_typography.scss:25-49`) are invisible to it.
  - `walkPass` (:745), `detectScreen` (:593), `goInApp` (:683), `firstRowSegment` (:695) and `toggleThemeThroughMenu` (:708) issue the walk's evaluates. `walk` (:782) wraps each pass in `retryOnce` (:796-812). `reportLines` is at :847.
  - Likeliest cause: `fonts.ready` never resolving behind a stuck font request (inference); a hung renderer is not excluded (inference). The deadline covers both.
- `ui/browser/protocol-retry.mjs`: `PROTOCOL_TIMEOUT` (:19), `isProtocolTimeout` (:27), `retryOnce` (:35-48). Tests: `ui/tools/protocol-retry.test.mjs` (fakes, no browser).
- `ui/browser/a11y-structural-invariants.browser-spec.mjs`: `protocolTimeout: 600_000` (:48), the hook at :59. `ui/tools/structural-baseline.test.mjs` already imports `structural-walk.mjs` under `node --test`.
- **DW-2512, measured** (run 40014034409 attempt 1, shard 3):
  - DW-2085 (`local-databases.browser-spec.mjs:821`) and AC7 (`:847`) each failed at 31.9-32.0 s in `panel-spec.mjs:83`'s `page.goto(..., { waitUntil: 'networkidle2' })`, under the 30 s default (`browser.config.mjs:106`, set at `panel-spec.mjs:79`).
  - Just before, AC8 (`:771`) seeded `OcuPilot.Test.BackgroundSeed`'s paused compact: `ocubgseed` grew to 1175 MB in about 10 s, the write-image journal by 152 MB, and `Remove` (`BackgroundSeed.cls:330-400`) deleted it. Page loads stalled from 19:59:38.7 until at least 20:00:42.6; the next spec passed from 20:00:56.
  - `NODES = 300000` x 3,900 bytes is deliberate, "about 1.2 GB" (`BackgroundSeed.cls:25-28`). `background-tasks.browser-spec.mjs` and `Test/BackgroundTasksLive.cls` use the same seed.
  - Frequency: "Navigation timeout of 30000" appears in 2 of the attempt-1 failed logs of 57 failed or re-run runs among the last 200. The other (main 40026736561, `data-table-columns`, its own local server) is not this entry.
  - `signedInAt` has about 664 call sites in 177 spec files; `networkidle2` appears 153 times in `ui/browser/`.
  - Cause: disk pressure from the 1.4 GB write and delete (inference).

### Batch 2: docs

- `src/OcuPilot/Api/Error.cls` :261-262: `PROVIDERTRANSPORT`'s doc ends "<b>Never retried.</b>" (DW-1706). The behavior is `Kernel/Provider/Base.cls` :19-31 (the contract) and :414-433 (`tNeverOpened`, `tTransportRetried`). Pinned by `Test/ProviderTransportRetry.cls`.
- `scripts/check-objectscript.py` :180: the docstring says the hook "runs it on staged `.cls`/`.mac`/`.inc`/`ui` files". `.githooks/pre-commit` :72-101 runs it bare over the whole tree when a staged path matches `OS_TRIGGER`; `main` (:2089) takes no argument.
- `CLAUDE.md` :134-135 says "(21 rules; the `.githooks/pre-commit` hook runs it on staged paths ...)". The count is right and pinned (`scripts/test_check_objectscript.py` :275, DW-1129); the scope half is wrong.

### Batch 3: pair validation

- `src/OcuPilot/Screen/Registry.cls`:
  - `Validate`: `MalformedPair(privileges)` at :270 (refusal :272), `OwnPrivilegesProblem` at :277, `AreaCoverageProblem(tArea, ...)` at :285, where the area key is in scope.
  - `OwnPrivilegesProblem(pDeclaration)` (:831-861): the subset check at :851; it never reads the area. Its sentences are at :845 and :852.
  - `MalformedPair` (:3748, Private): `'$IsObject(tPair) || %Get("resource")="" || %Get("permission")=""`. Two callers, :270 and :843.
  - Area pairs: `##class(OcuPilot.Screen.Area).PrivilegePairs(tArea)`.
- `ui/tools/screen-mirror.mjs`: `malformedPair` (:848) already requires `typeof === 'string'`; `ownPrivilegesProblem` (:872, subset at :882); `buildMirror` calls them at :3391 (areas), :3418 and :3425 (screens). The mirror has no area-coverage check.
- **Shared corpus:** `src/OcuPilot/Test/DeclarationCorpus.cls`, `XData OwnPrivilegeCases` (:23-43): top-level `privileges` and `cases[{name, ownPrivileges?, expected}]`; `OwnPrivilegeDeclarationFor` at :69. Read by `Test/Descriptor.cls` `TestAPairAScreenDeclaresItsOwnIsLeftOutOfItsAreasCoverage` (:1330) and `ui/tools/screen-mirror.test.mjs` :2666 (via `testCorpus`, :73). Inline mirror cases for `malformedPair` at :2253; the instance's `privileges` path is `Test/Navigation.cls` `TestAMalformedPrivilegePairIsRefused` (:194).
- **Measured over 212 screens, 11 areas, 61 own-pair declarations:** (a) an own pair the area declares: 0. (b) own pairs equal to all privileges: 2, `logs/eventlog` and `logs/analytics`, which the spine names as intended. Non-string halves: 0. The owners roster (`screen-mirror.test.mjs` :2681-2770) is unchanged by this batch.

### Batch 4: client and runner tooling

- `ui/tools/ci-runner.mjs` `testClassesOnDisk` (:383; doc :366-382): direct `Extends ... TestCase` text (:395), own `Test*` method (:396), `[ Abstract` as first keyword only (:397). Callers: `main` (:505-517, compares with the instance's list), `ui/tools/ci-shards.mjs` :364 (`assign`; caveat doc :24-27). Tests: `ui/tools/ci.test.mjs` :919 and :3200, `ui/tools/ci-shards.test.mjs` :93. The instance side (`scripts/ci-unit-test.sh` :80) reads `PrimarySuper`, non-abstract, with an inherited-or-own `Test*` method.
  - Measured: 707 classes reach `TestCase` (684 directly, 23 through a project base); 699 runnable, equal to the `objectscript` keys of `ci-timings.json`. The floor returns 680.
  - Bases: seven `[Abstract]` with no tests (`AdapterCacheCase`, `InteropResendCase`, `ExplorerSourceTestCase`, `StreamCase`, `TurnToolsCase`, `UserCopyTestCase`, `WorkflowTurnCase`) and one concrete, `DocDbAppGate` (3 tests), extended by `RoutineAppGate`.
  - Missed today (19): AdapterCache, AdapterScope, DryRunRoute, InteropEditResend, InteropResend, InteropResendGate, InteropResendLimits, InteropResendSweep, ProviderStream, ProviderStreamFamilies, RoutineAppGate, ToolNavigateParent, TurnBudget, TurnScope, TurnScopeFamilies, TurnTools, WorkflowGates, WorkflowLoop, WorkflowTurn.
- `ui/src/app/areas/permissions/user-create-form.store.ts` :10 `USERS_PATH`, :13 `USERS_FORM_PATH`, derived paths :16-22, readers :319, :357, :491. `user-editor.store.ts` :15 and :18 repeat both; readers :440, :513, :550. Specs `user-editor.page.spec.ts` :16, :200, :314 and `user-create-form.store.spec.ts` :15, :103, :381. No shared paths module exists.
- `ui/src/app/areas/os-management/journal-records.page.ts`: the text input (:277-283) has no `maxlength`; `CriterionView` (:75-82) has no `maxLength`; the `criteria` getter (:468-481) drops `field.maxLength`. Sibling: `system-explorer/code-list.page.ts` :165 `[attr.maxlength]="field.maxLength"`, mapped at :382, pinned at `code-list.page.spec.ts` :195. Bounds: `Screen/Descriptor/JournalRecordList.cls` :59-64 (offset 20, value 200), mirrored in `screens.generated.ts` (`maxLength` required, :241). `journal-records.page.spec.ts` uses the real `SCREENS` (:17, :34).
- Budget: journal records is a lazy chunk (`screen-outlet.ts` :166). Lazy cap `LAZYCHUNKMAX` 88,000 (`build-output.test.mjs` :267). Initial total last measured 2.01 MB against the owner's 2500 kB warning.

### Batch 5: shared removal rows

- `src/OcuPilot/Screen/Tool/Write.cls` `StateDiff` (:551, doc :541-550) answers `[]` and `""`; about 90 tools rely on that default. `Write.cls` declares no `REMOVALROWS`.
- 109 classes define `StateDiff`; 16 read `..#REMOVALROWS`, each declaring it:
  - **A** (`pFresh.%Get(f) _ ""`, no guard, a non-object `pFresh` reads `""`): `ExplorerDocDbDelete.cls` :57, `RestServiceDelete.cls` :76.
  - **B** (`Mint.Display(value, %GetTypeOf)` in Try/Catch after the tool's own precondition guard and message): InteropItemRemove, DeviceDelete, EcpDataServerDelete, EcpSslConnectionDelete, InteropLookupEntryRemove, InteropLookupTableDelete, LanguageServerDelete, LicenseServerDelete, LocalDatabaseDelete (:103-125 is representative), NamespaceDelete, RemoteDatabaseDelete, WebSessionEnd, X509Delete.
  - **C** `MftConnectionDelete.cls` :96: B plus `Continue` on an unassigned field.
- Four more declare `REMOVALROWS` for their own diff only (DataElementKeyDeactivate, DatabaseKeyDeactivate, EncryptionKeyFileRemoveAdmin, EncryptionKeyFileRemoveKey). They are untouched.
- `Kernel/Proposal/Mint.cls` `Display` (:930) differs from `_ ""` only for boolean, null, unassigned and object values; A's fields (`Name`, `Class`) are strings.
- Readers of the rows: DocDbWrite, RestServiceDescriptor, InteropItemControl, DeviceDelete, EcpDataServerWrite, EcpSslConnectionWrite, InteropLookupControl, InteropLookupEdges, LanguageServerEditor, LicenseServerWrite, DatabaseWrite, DatabaseWriteDetail, MftConnectionDescriptor (:146 has a `REMOVALROWS` mutation note), NamespaceWrite, RemoteDatabaseDescriptor (:131 reads the parameter), RemoteDatabaseWrite, WebSessions, X509Delete.

## Tasks & Acceptance

**Execution:**

- One implement pass per batch leaves the tree for one commit: `fix(23.9): batch <n> - <area>`.
- Each task names its pinning test; its `mutation:` line goes under Verification with the observed run.
- In the same pass, update every test that asserts a shared surface's old shape (Verification › Shared surfaces).
- The lead writes the ledger trailers once the batch's commit is green.
- **Pass order** (lead rulings): batch 1 (done); batch 4 with DW-1706 (done); batch 5; then batch 3 with DW-1177's docstring, after Story 20.39 (which edits `Screen/Registry.cls` and `screen-mirror.mjs`) has merged and been integrated forward. Four commits. The lead opens one pass at a time; a pass works only the items the lead names and leaves every other item unchecked.
- **Current pass: Batch 3 (DW-1760 (a), DW-1761) and DW-1177's docstring from Batch 2.** DW-1760 (b) closes by-design at adjudication; no other item remains.

### Batch 1: CI flakes

- [x] **Task 0 (DW-2512), measure on `ocupilot-ci`, at most three calls.**
  - (i) Run `local-databases.browser-spec.mjs` alone twice (one call each); record durations and any navigation timeout.
  - (ii) In a temporary probe (removed after), seed `BackgroundSeed`'s paused compact at 30,000 nodes and check that AC8's assertions would hold: a compact task over the seed database listed as paused, then `Remove` answers OK.
  - Record both under Verification.
- [x] **DW-1822.** `ui/browser/structural-walk.mjs` `settle`: replace `await document.fonts.ready` with a synchronous `document.fonts.status === 'loaded'` read inside the existing loop, so `SETTLE_TIMEOUT_MS` bounds it. Export `settle` for the test. Update its doc comment.
- [x] **DW-1822.** `ui/browser/protocol-retry.mjs`: add `export const WALKCALLDEADLINE = 60_000` and `export function withDeadline(promise, ms, label)`, which rejects after `ms` with an error whose message matches `PROTOCOL_TIMEOUT` and names `label`. In `structural-walk.mjs`, every `page.evaluate`/`$eval`/`waitForFunction` the walk issues goes through it, labeled with pass, route and step. `walk` adds one report line per retried pass, naming it.
- [x] **DW-1822 pins**, both red before the fix:
  - New `ui/tools/structural-walk.test.mjs`: `settle` over a fake page whose `evaluate(fn)` runs `fn` against a stubbed `document` (`fonts.ready` never resolves, `status` turns `loaded` after 1 s, no busy node) answers `true` within 5 s. Test timeout 30 s.
  - `ui/tools/protocol-retry.test.mjs`: `withDeadline` over a never-settling promise rejects within `ms` + 1 s with `isProtocolTimeout` true, and `retryOnce` re-runs its `create` once on it. Use a short `ms`.
- [x] **DW-2512.** `ui/browser/panel-spec.mjs` `signedInAt`: track requests from before the `goto`; on a navigation timeout, rethrow the same error with its message extended by each request still in flight and its age in ms. Pin in a new `ui/tools/panel-spec.test.mjs`: a fake page whose `goto` rejects with a `TimeoutError` while one request is in flight gets that URL in the rethrown message. Red before.
- [x] **DW-2512.** If Task 0 (ii) holds: `src/OcuPilot/Test/BackgroundSeed.cls` `PausedCompact` gains a trailing `pNodes` argument defaulting to `..#NODES`, and only `local-databases.browser-spec.mjs`'s AC8 passes 30,000. `background-tasks.browser-spec.mjs` and `BackgroundTasksLive` are unchanged. If it does not hold, skip this task and record why (Dispositions).

### Batch 2: docs

- [x] **DW-1706.** `src/OcuPilot/Api/Error.cls` :262: replace "<b>Never retried.</b>" with "A failure before any status line arrived is retried once, on a new connection, inside the same attempt and delay budget; a call that raised, a connect that never opened (<code>ERROR #6059</code>) and a stream that broke after its status line are not (<class>OcuPilot.Kernel.Provider.Base</class>)." No test (doc comment; the behavior is pinned by `ProviderTransportRetry`).
- [x] **DW-1177.** `scripts/check-objectscript.py` :180: "runs it over the whole tree whenever a commit stages a `.cls`/`.mac`/`.inc`, `ui/`, `module.xml` or `scripts/*.sh` path". No test (docstring). The CLAUDE.md line goes to the Planner (Design Notes › For the Planner).
- [ ] **DW-446, DW-2060.** No edit (already true at head; Design Notes).

### Batch 3: pair validation

- [x] **DW-1761.** `Screen/Registry.cls` `MalformedPair`: an entry is malformed unless it is a `%DynamicObject` whose `resource` and `permission` have `%GetTypeOf` `"string"` and are non-empty. Update its doc.
- [x] **DW-1760.** `OwnPrivilegesProblem` gains a trailing `pAreaPairs As %List = ""`; an own pair `$ListFind`-ed in it is refused with the matrix sentence (area key from the declaration's `area`). `Validate` :277 passes `Area.PrivilegePairs(tArea)`. `screen-mirror.mjs` `ownPrivilegesProblem` takes the same second argument and sentence; `buildMirror` :3425 passes the matching area's privileges.
- [x] **Corpus.** `DeclarationCorpus.cls` `OwnPrivilegeCases`: add top-level `area` and `areaPrivileges` (`%Admin_Operate:USE`); add that pair to `privileges`; move the case at :40 that uses `%Admin_Operate` as "undeclared" to another resource; add the cases `an own pair the area already declares` (refused) and `a resource that is not a string` (`{resource: 5, permission: "USE"}`, expected the `#1` sentence). Both readers (`OwnPrivilegeDeclarationFor`, the node loop at :2666) pass `areaPrivileges`. Add `malformedPair([{resource: 5, permission: 'USE'}]) === '#1'` to the inline cases at :2253, and a `privileges` non-string fixture leg beside `Navigation.TestAMalformedPrivilegePairIsRefused`.
  - Pins: `Descriptor.TestAPairAScreenDeclaresItsOwnIsLeftOutOfItsAreasCoverage` (red before on both new cases) and screen-mirror.test.mjs :2666 (red before on the area case).

### Batch 4: client and runner tooling

- [x] **DW-2259.** `ui/tools/ci-runner.mjs` `testClassesOnDisk`: parse every `.cls` under `src/OcuPilot/Test/` into name, supers (parenthesized list or one name), abstract (`\bAbstract\b` in the class's keyword list) and own `Test*` methods. List a class when it reaches `%UnitTest.TestCase` through any chain, is not abstract, and has a `Test*` method of its own or on a project ancestor. Correct the floor caveat at :366-382 and `ci-shards.mjs` :24-27.
  - Pin in `ui/tools/ci.test.mjs`: (a) a temp tree with abstract `Base`, `Child Extends Base` (tests), `Grand Extends Child`, and concrete `ConcreteBase` (tests) with `Sub`, expecting `[Child, ConcreteBase, Grand, Sub]`; (b) the real tree includes `ProviderStream`, `TurnTools` and `RoutineAppGate` and excludes `StreamCase`. Both red before.
- [x] **DW-2260.** Keep `USERS_PATH` and `USERS_FORM_PATH` exported from `user-create-form.store.ts`; `user-editor.store.ts` imports them (its effective path derives from the import), and `user-editor.page.spec.ts` imports from there. Pin: new `ui/tools/client-paths.test.mjs` walks `ui/src` non-spec `.ts` files and expects exactly one `const USERS_PATH =` and one `const USERS_FORM_PATH =`. Red before.
- [x] **DW-1981.** `journal-records.page.ts`: `CriterionView` gains `maxLength`, the getter maps `field.maxLength`, and the text input binds `[attr.maxlength]="field.maxLength"`, as `code-list.page.ts` does. Pin in `journal-records.page.spec.ts`: the offset and value inputs carry `maxlength` equal to `RECORDS.read.criteria` fields' declared values (20 and 200). Red before. Record the journal records chunk size and the initial total after `npm run build`.

### Batch 5: shared removal rows

- [x] **DW-2299.** `Screen/Tool/Write.cls`, add-only: `Parameter REMOVALROWS = "";` and `ClassMethod RemovalRows(pFresh As %DynamicObject, pSkipUnassigned As %Boolean = 0) As %DynamicArray`, B's loop: one row per `REMOVALROWS` name with `field`, `before` (`Mint.Display` of the value and its type; `""` when `pFresh` is not an object), `after` `""` and `removed` true; with `pSkipUnassigned`, an unassigned field gets no row. The doc states the contract. `StateDiff` is untouched.
- [x] **DW-2299.** The 16 deletes keep their guards, messages and Try/Catch and set `pRows = ..RemovalRows(pFresh)` (`MftConnectionDelete` passes 1). A and C's doc comments point at `RemovalRows`.

**Acceptance Criteria:**

- **Dispositions.** Given the twelve entries, when the story completes, then each is closed as Design Notes › Dispositions says, with its batch commit or the head commit that already fixed it, and any evidence correction in its note.
- **Red first.** Given each fix above, when its pinning test runs before the fix, then it is red, and after the fix green. Three kinds show the defect another way, each recorded under Verification: documentation with nothing to fail on (DW-1706, DW-1177); a behavior-preserving lift (DW-2299: equal per-class totals before and after, plus a mutation of `RemovalRows` reddening all 16 deletes' readers); and DW-2512's seed change, which is shown by Task 0 and a green AC8, not by a red.
- **Flakes, under their condition.** Given a page whose fonts never report ready, when the walk settles, then it answers within `SETTLE_TIMEOUT_MS` instead of the protocol limit; given a walk call that never returns, then the pass is retried after 60 s, not 600 s. Given the tree at the batch-1 commit, when `a11y-structural-invariants.browser-spec.mjs` runs on `ocupilot-ci`, then it passes 13/13 in under 600 s, with no pass retried (record the time beside the 414.8 s recorded at 7dd30507).
- **Both engines.** Given the corpus at the batch-3 commit, when the instance and the mirror read it, then each case answers the same sentence in both, and every shipped descriptor still builds.
- **Integration (Rule 1).** Given `Write.RemovalRows`, when the 16 delete tools mint their proposals through the agent's write path, then each card's removal rows equal today's, observed by the rows' reader classes listed in the Code Map.
- **Batches.** Given the five batches, when each lands, then it is its own commit with CI green on its own head.

### Review Findings

Code review, batch 1 (2026-11-12). Rule 3 exempt: test-harness code, no user-facing surface.

- [x] [Review][Patch] (med) A hung settle named no route, against the matrix's "pass and route" - `settle` takes `where`, `goInApp` passes its path [ui/browser/structural-walk.mjs:settle, goInApp]
- [x] [Review][Patch] (med) The walk's retried-pass bookkeeping was untested - lifted into exported `passRetrier`, pinned over an abandoned call [ui/browser/structural-walk.mjs:passRetrier]
- [x] [Review][Patch] (med) The `fieldNames` deadline had no pin, and the source check missed click, key press and `$$eval` shapes - hung-page row added, check widened [ui/tools/structural-walk.test.mjs]
- [x] [Review][Patch] (low) The theme toggle's clicks and Escape were unbounded - wrapped in `bounded` [ui/browser/structural-walk.mjs:toggleThemeThroughMenu]
- [x] [Review][Patch] (low) The deadline error advised raising `protocolTimeout` - its tail now says that does not change this deadline [ui/browser/protocol-retry.mjs:withDeadline]
- [x] [Review][Patch] (low) `WALKCALLDEADLINE`'s doc said only the walk is bounded; 87 specs call the bounded helpers - doc corrected [ui/browser/protocol-retry.mjs]
- [x] [Review][Patch] (low) Test header understated the file; a 5 s race timer kept the process alive - header rewritten, timer cleared [ui/tools/structural-walk.test.mjs]
- [x] [Review][Patch] (low) Verification said `pNodes` has no pinning test, contradicted by QA's test - line corrected (Rule 19) [this spec, Verification]
- [x] [Review][Defer] The 30,000-node compact may end before AC8 pauses it on a loaded shard [ui/browser/local-databases.browser-spec.mjs:AC8] - deferred: DW-2516 occurrence; settled by CI shard runs of local-databases

Rejected:

- Spec `status: done` with batches open (three layers): build-auto's per-pass machine state; not changed by review.
- QA pins not yet on a green CI head: the lead commits and pushes after review.
- QA's `BackgroundTasksLive` method breaks the task's "unchanged" wording: existing callers keep the default, which is the task's intent; the method is the `pNodes` pin.
- The new ObjectScript test drops `PausedCompact`'s status: a failed seed still reddens the count; the fix adds a branch.
- `pNodes` 0, negative or odd: test-only seed, every caller a test (theoretical).
- A font loading in 20-200 s now records the visit unsettled: Design Notes decided this.
- A bounded `context.close()` that hangs replaces the pass error: needs two hangs at once; the fix adds error chaining.
- A slow but finite walk call over 60 s: about 80 times a normal visit (inference); the a11y run below took no retry.
- `signedInAt`'s own calls unbounded: outside the walk's deadline, and the spec keeps `signedInAt`'s navigation as is.
- The source check's 3-line window and `fieldNames` skip: `fieldNames` is now pinned by behavior; the window only matters for a call next to another bounded one.
- Cycle-log timestamp mismatch: the lead's log, not this change.
- `trackInflightRequests` resembles `trackRequests` (Rule 31): different filters and clocks; two short copies read better than one parameterized tracker.

Code review, batch 4 and DW-1706 (2026-11-12). Rule 3 exempt: test-harness and tooling code, one `maxlength` attribute that follows the declared bounds.

- [x] [Review][Patch] (med) The abstract exclusion in `testClassesOnDisk` and a parenthesized `Extends` list had no pin - third case added with an abstract class that carries tests [ui/tools/ci.test.mjs]
- [x] [Review][Patch] (low) `client-paths.test.mjs` missed `const USERS_PATH: string =` - pattern widened to `\bconst NAME\s*[:=]` [ui/tools/client-paths.test.mjs]

Code review (bmad-code-review), batch 4 and DW-1706 (2026-11-12). Rule 3: DW-1981's `maxlength` is a user-facing attribute; the component spec on the real template with the declared criteria is the accepted tier for an attribute binding (the sibling `code-list.page.ts` binding is pinned the same way, and `journal-records.browser-spec.mjs` renders the screen in CI's browser job). The rest is tooling, exempt.

- [x] [Review][Patch] (med) The checkout list followed every name of an `Extends` list to `TestCase`, while the instance's `PrimarySuper` follows only the first (verified on `ocupilot-slot-a`), and two tests pinned the mismatch - `reachesTestCase` follows the first name; `Mixed`, `Wrapped` and a new `Secondary` case expect the instance's answer [ui/tools/ci-runner.mjs:testClassesOnDisk; ui/tools/ci.test.mjs]
- [x] [Review][Patch] (med) `client-paths.test.mjs` hand-rolled a source walk beside `source-scan.mjs` `walkSource`, the shared walker for static guards (Rule 31) - now uses `walkSource` and `blankComments` [ui/tools/client-paths.test.mjs; ui/tools/source-scan.mjs:walkSource]
- [x] [Review][Patch] (low) `Not Abstract` and `Abstract = 0` read as abstract - the keyword test now matches `check-objectscript.py` `ABSTRACT_KEYWORD_RE`, the Python sibling a node runner cannot import (the copy's reason) [ui/tools/ci-runner.mjs]
- [x] [Review][Patch] (low) Any superclass named `...TestCase` counted as the framework base - now `%UnitTest.TestCase` exactly [ui/tools/ci-runner.mjs:reachesTestCase]
- [x] [Review][Patch] (low) "It matches the instance's query" overclaimed, `main()`'s comment named only the instance for a mismatch, and `ci-shards.mjs` gave no reason the splits differ - comments corrected [ui/tools/ci-runner.mjs; ui/tools/ci-shards.mjs]
- [x] [Review][Patch] (low) A mutation comment still said "both tests below", and the real-tree `StreamCase` message claimed the abstract filter (it has no `Test*` method) - both corrected [ui/tools/ci.test.mjs]
- [x] [Review][Patch] (low) `USERS_FORM_PATH`'s doc covered only the create form's read, not the editor's `?name=` read [ui/src/app/areas/permissions/user-create-form.store.ts]
- [x] [Review][Patch] (low) The `PROVIDERTRANSPORT` sentence was broader than `Provider.Base`: a body that could not be built is not retried, and the retry needs an attempt left - sentence narrowed to Base's contract [src/OcuPilot/Api/Error.cls]
- [x] [Review][Defer] `shell/screen-action-handler.ts` `USER_FORM_READ_PATH` repeats the users form route under another name, which a name-based pin cannot see [ui/src/app/shell/screen-action-handler.ts:409] - deferred: DW-2514 occurrence (Epic 20's file, kept by Design Notes); the test header now says it pins these names only

Rejected:

- A `]` inside a quoted class keyword value: no project header has one; a fix needs a quote-aware scanner.
- A file whose declared class name differs from its path: none does (699 equal to the instance's list both ways).
- A BOM or unparsed header drops a class silently: no file under `src/OcuPilot/Test` starts with a BOM.
- A `TestCase` link or `Test*` method on a class outside `src/OcuPilot/Test`: none today; the doc states the folder limit.
- `Method Test` at column 0 inside a banner or XData: unchanged from the previous matcher; none today.

Code review (bmad-code-review), batch 5 (2026-11-12). Rule 3 exempt: server-side card rows, no new surface; the reader tests below observe each card.

- [x] [Review][Patch] (med) The non-object branch of `RemovalRows`, the only guard `ExplorerDocDbDelete` and `RestServiceDelete` had, was unpinned - `RestServiceDescriptor` gains a non-object leg [src/OcuPilot/Test/RestServiceDescriptor.cls]
- [x] [Review][Patch] (med) `pSkipUnassigned` and `MftConnectionDelete`'s argument were unpinned - `MftConnectionDescriptor` gains a partial-read leg [src/OcuPilot/Test/MftConnectionDescriptor.cls]
- [x] [Review][Patch] (med) No test observed the rows of `InteropItemRemove`, `LicenseServerDelete`, `NamespaceDelete` or `RemoteDatabaseDelete` (the Integration AC) - one method in each tool's descriptor test class [src/OcuPilot/Test/InteropItemDescriptor.cls, LicenseDescriptor.cls, NamespaceDescriptor.cls, RemoteDatabaseDescriptor.cls]
- [x] [Review][Patch] (low) `Mint.Display`'s boolean rendering through a removal row was unpinned - the InteropItemRemove method asserts `true` and `false`

Code review stage (bmad-code-review), batch 5 (2026-11-12). Rule 3: the cards are user-facing, the lift is behavior-preserving inside `StateDiff`, Mint is unchanged and none of the 16 declares `EMPTYKEYS`, so a `StateDiff` reader observes the card's rows; `InteropLookupControl.TestTheAgentsRemoveConfirmsOverHttp` drives one delete over real HTTP, and the browser suite is CI's. Met.

- [x] [Review][Patch] (low) `RemovalRows`'s caller contract said every caller wraps it in its own `Try`; `ExplorerDocDbDelete` and `RestServiceDelete` call it bare [src/OcuPilot/Screen/Tool/Write.cls:RemovalRows] - the contract now says it raises to its caller
- [x] [Review][Patch] (low) The doc said `pSkipUnassigned` drops every unassigned field; a read that is not an object still gets every row (no caller reaches it) [src/OcuPilot/Screen/Tool/Write.cls:RemovalRows] - doc states the case; doc-only, Load 0 errors on `ocupilot-ci`, `RestServiceDescriptor` 8/8 (run 432), `check-objectscript.py` 0 problems
- [x] [Review][Defer] (med) The lifted loop body survives in 16 sibling deletes over `FingerprintSubject()` (11) or `ReadAnswers()` (5, four with the skip), e.g. `TaskDelete.cls` and `MappingDelete.cls` beside `Write.cls` `RemovalRows`, which takes no name list [src/OcuPilot/Screen/Tool/*Delete.cls] - deferred: pre-existing, outside this spec's census of the 16 `REMOVALROWS` readers; DW-2525, routed to 23-10

Rejected:

- A non-dynamic object `pFresh` raises at `%GetTypeOf`: the old loop's `%Get` raised alike, and the mint passes the port's dynamic object.
- Two new tests index a row before checking the count: a short list still errors the method red; the guard adds branches.
- `Parameter REMOVALROWS = ""` on the base lost the compile error a delete got for an undeclared parameter: the spec prescribes the default, and each delete's own reader pins its rows; a roster guard adds a test for a mistake no delete makes today.
- New readers call `StateDiff`, not the mint: Mint is untouched and transforms none of the 16 cards' rows (see Rule 3 above).
- Spec status, baseline, oversized additions, the Auto Run Result's file list and totals, and the review log's audit sentence: edits to the spec under review, outside a review's sanctioned sections.
- "the 4 new-test classes" names three counts: four classes gained a test, and the same line gives `RemoteDatabaseDescriptor`'s 5 to 6.

## Spec Change Log

- 2026-11-12, after batch 1 (lead): pass order changed to 1, 4 + DW-1706, 3 + DW-1177, 5, so no pass edits a file Epic 20's Story 20.34 has changed before it merges.
- 2026-11-12, spec gate (lead): batch 2 lands with batch 4; the full sweep is lead-owned (before batch 1's push and the last `src` batch's push); filing candidates filed as DW-2513 (flake, routed to 23.10), DW-2514 and DW-2515 (wontfix-accepted).

## Review Triage Log

### 2026-11-13 - Contention note (batch 3)

- The batch 3 implement stage made non-add-only edits to `ui/tools/screen-mirror.mjs` and `ui/tools/screen-mirror.test.mjs`, which Epic 20 had also changed (Story 20.36, `f1b9a5a4`), before the lead asked the orchestrator. The orchestrator ruled them kept (decide, 2026-11-13): the regions are separate and neither side changes the other; whichever story merges second keeps both. Stages are reminded that such an edit goes to the orchestrator first.

### 2026-11-12 - Review pass (batch 1)

- verdicts: 8 findings - high 0, medium 3, low 4, false 0, maybe-false 1
- findings:
  - `[medium]` `[patch]` settle test had only upper bounds, so dropping the fonts condition stayed green - added a lower-bound assertion (elapsed >= 900 ms); mutation observed red.
  - `[medium]` `[patch]` the 60 s deadline wiring in the walk was untested - added a source check that every walk `page.evaluate`/`waitForFunction` sits inside `bounded(` (fieldNames runs under its caller's); mutation (unwrap `detectScreen`) observed red.
  - `[medium]` `[patch]` `signedInAt` wiring of the in-flight diagnostic was untested - added a source-order check (tracking before `prepare`, goto through `gotoNamingInflight`, no direct `page.goto`); mutation observed red.
  - `[low]` `[reject]` `pNodes` has no mutation line - no test can observe a seed size as pass or fail; the effect is recorded under Verification (fill and AC8 duration), and a size assertion would be a new probe class for a test-only parameter.
  - `[low]` `[patch]` Verification said the `withDeadline` mutation hung to an 8 s timeout while the tests declare 10 s - wording corrected.
  - `[low]` `[reject]` settle test's red case leaves a 60 s timer pending - slows a failing run only; fix adds a cancel path to `withDeadline` for no user-visible harm.
  - `[low]` `[reject]` a hung `context.close()` in a `finally` replaces the original pass error in the retried-pass line - narrow, and the report still names a hung call; a fix adds error-chaining in `walk`.
  - `[maybe-false]` `[defer]` the 30,000-node compact might end before AC8 pauses it on a loaded CI shard - measured pause 0.28-0.71 s on an idle throwaway over three probes; settled by CI shard runs of `local-databases` (the leg errors with "compact reads Completed, not Paused").
  - Intent-alignment audit (descriptive): the diff implements both approach halves; the new tests run against fakes in Node, not a real Chrome, by the spec's design; unwrapped calls are `click`, `waitForSelector`, `keyboard.press` and `signedInAt`'s own steps, which the intent does not name.

### 2026-11-12 - Review pass (batch 4 and DW-1706)

- verdicts: 7 findings - high 0, medium 1, low 4, false 0, maybe-false 0 (2 descriptive notes folded into rows)
- findings:
  - `[medium]` `[patch]` abstract exclusion unpinned: the test's abstract `Base` has no tests, so dropping the abstract filter stays green - added a case with an abstract class that carries a `Test*` method and a concrete child; both mutations observed red.
  - `[low]` `[patch]` a parenthesized multi-name `Extends` list was not exercised - folded into the same case (`Mixed Extends (Helper, AbstractWithTests)`); mutation observed red.
  - `[low]` `[patch]` `client-paths.test.mjs` pattern missed a typed declaration - widened.
  - `[low]` `[reject]` the real-tree test breaks on renaming `ProviderStream`, `TurnTools` or `RoutineAppGate` - the spec names those three; a rename is a deliberate edit to that line.
  - `[low]` `[reject]` the 699 equality with `ci-timings.json` is not asserted in a test - it is recorded under Verification, and the file is generated and refreshed at every merge.
  - `[low]` `[reject]` the matcher accepts any parent named `...TestCase` where the instance reads `%UnitTest.TestCase` - no project class extends another `TestCase`; the fix adds a name table.
  - `[low]` `[reject]` the ci-runner doc comment lost its em dashes to `--` - comment-only, ASCII, no harm.
  - Intent-alignment audit (descriptive): the diff implements the literal reading of all four items; the editor store does not re-export the constants, as the spec says (imports only); server limits are untouched, as the spec says.

### 2026-11-12 - Review pass (batch 5)

- verdicts: 6 findings - high 0, medium 3, low 3, false 0, maybe-false 0
- findings:
  - `[medium]` `[patch]` non-object `pFresh` branch of `RemovalRows` unpinned; the lift removed the two A tools' only copy of that guard - added a non-object leg to `RestServiceDescriptor`; mutation observed red.
  - `[medium]` `[patch]` `pSkipUnassigned` and `MftConnectionDelete`'s argument unpinned - added a partial-read leg to `MftConnectionDescriptor`; mutation observed red.
  - `[medium]` `[patch]` Integration AC unobserved for four deletes (InteropItemRemove, LicenseServerDelete, NamespaceDelete, RemoteDatabaseDelete) - one method per descriptor test class; the `removed` mutation observed red in each.
  - `[low]` `[patch]` `Mint.Display` boolean rendering through a removal row had no mutation - folded into the InteropItemRemove method; mutation observed red.
  - `[low]` `[reject]` A and C's `before` moves from `value _ ""` to `Mint.Display` (verification-gap other finding, intent audit) - the fields are `Name`, `Class`, both strings, for which the two are identical; the spec prescribes the single rendering.
  - `[low]` `[reject]` `$IsObject(pFresh)` recomputed on each loop turn - negligible, and hoisting it adds a branch for no named harm.
  - Intent-alignment audit (descriptive): the diff implements the full lift (all 16 tools call the helper, A and C included); the tests exercise the card rows through `StateDiff`, the surface the AC names.

### 2026-11-12 - Review pass (batch 3 and DW-1177)

- verdicts: 3 findings - high 0, medium 1, low 1, false 0, maybe-false 1
- findings:
  - `[medium]` `[patch]` `Validate`'s call into `OwnPrivilegesProblem` with the area's pairs had no test: the corpus calls the value function with its own list, and `OwnPair.Bad` is refused on the subset rule first - added `OcuPilot.Test.OwnPairArea.Bad` and `OwnPairAreaRegistry` and a `Validate` leg in `Descriptor.TestAPairAScreenDeclaresItsOwnIsLeftOutOfItsAreasCoverage`; mutation observed red.
  - `[low]` `[patch]` `MalformedPair`'s `permission` type clause and its `%IsA` clause were not isolated by any case - corpus cases `a permission that is not a string` and `an entry that is an array, not a pair`; both clauses mutated alone, each red.
  - `[maybe-false]` `[reject]` `Area.PairsFrom` still reads a non-string half (intent audit) - the validator refuses such a declaration at install, so it never reaches the reader; the spec names `MalformedPair` only.
  - Intent-alignment audit (descriptive): the diff implements the refusal at the value functions and at both build entry points; the instance's `Validate` leg was the one surface without a test, closed by the first finding.

## Design Notes

**Verdicts at `6cb84d15`** (Ledger inbox: 12 of 12 addressed, none declined):

| Entry | Verdict | Evidence | Disposition | Batch |
|---|---|---|---|---|
| DW-1822 | Confirmed; the mechanism is corrected | 600 s steps, not an even slowdown; one evaluate with no bound (`settle`'s `fonts.ready`). The ledger's split targets a cheap step (inference). | resolved-by | 1 |
| DW-2512 | Confirmed once (2 of 57 failed logs, the other a different spec) | Followed a 1.2 GB seed write and delete; cause (inference) | resolved-by, see Dispositions | 1 |
| DW-1706 | Confirmed | `Error.cls:262` vs `Base.cls:19-31` | resolved-by | 2 |
| DW-1177 | Confirmed, and wider: the script docstring says it too | `check-objectscript.py:180`; hook :72-101 | see Dispositions | 2 |
| DW-446 | Already true at head | `5ef1e153d1c4a53e247f83a1128143d8c68a0afc` set "21 rules"; `test_check_objectscript.py:275` pins it; 21 measured | resolved-by (that commit) | none |
| DW-2060 | Already true at head | `ca9b32cf69831ce0b80597980fa8881b57ef52b1` (Story 18.48) reads "thirty-eight in all"; `Codes()` lists 38 | resolved-by (that commit) | none |
| DW-1760 | Half confirmed | (a) no engine refuses an own pair the area declares, and the spine says "An own pair is never one the area already declares"; 0 shipped violators. (b) two shipped screens own all their pairs, as AD-8 intends. | (a) resolved-by; (b) by-design | 3 |
| DW-1761 | Confirmed | `Registry.cls:3753` vs `screen-mirror.mjs:848`; 0 shipped non-strings | resolved-by | 3 |
| DW-2259 | Confirmed, and wider | 19 missed (the entry named 2); a concrete base exists | resolved-by | 4 |
| DW-2260 | Confirmed, and wider | `USERS_FORM_PATH` is duplicated too | resolved-by | 4 |
| DW-1981 | Confirmed; the budget reason is gone | Lazy chunk since Story 20.29; initial 2.01 MB | resolved-by | 4 |
| DW-2299 | Confirmed, and wider; the lift is a helper, not a default | 16 copies in three variants; replacing `StateDiff` would change about 90 tools | resolved-by | 5 |

**Dispositions.**

- DW-446 and DW-2060: `resolved-by:23-9-the-range-end-cleanup-part-8` with note naming the commit that fixed it (already true at head, verified), no code change.
- DW-1760: `resolved-by` for (a). Its note records (b) as by-design: AD-8 names `logs/eventlog` and `logs/analytics` as owning all their pairs since DW-1768 option B. reopen_if an AD-8 amendment requires an area pair on every screen.
- DW-1177: the docstring lands in batch 2. If the Planner's CLAUDE.md change has landed by adjudication, `resolved-by`; otherwise `wontfix-accepted`, note "CLAUDE.md is owner-only; wording sent to the Planner; reopen_if=CLAUDE.md still says the hook runs check-objectscript.py on staged paths".
- DW-2512: `resolved-by` with the diagnostic and, if Task 0 (ii) holds, the smaller seed. Its note says the cause is (inference), and reopen_if a `signedInAt` navigation timeout recurs (the diagnostic then names the request). If Task 0 (ii) fails, the note says so and the seed is unchanged.

**Governing ADs:**

- **AD-5 and AD-8.** One descriptor, both engines refuse alike over one corpus; `ownPrivileges` is a subset of `privileges`, and an own pair is never one the area declares; `AreaCoverageProblem` is unchanged (DW-1760, DW-1761, DW-1981's declared `maxLength`).
- **AD-42.** A transport failure before a status line is retried once on a new connection; a `#6059` connect is not; a write never retries mid-flight (DW-1706, doc only).
- **AD-12, AD-39 and AD-10.** Codes and reasons are unchanged; `Prohibited.cls` is not edited (DW-2060).
- **AD-51, AD-52 and AD-53.** The tool knows which state its action moves: each delete keeps its own guard and declared `REMOVALROWS`; the base supplies only the loop (DW-2299).
- **AD-19.** Store constants stay in the area's stores (DW-2260).
- **AD-17.** Test classes stay where they are; the runner's disk list changes, not what the instance compiles (DW-2259).
- No AC contradicts an AD's Rule, and no NFR is in play.

**Integration ACs (Rule 1).** `Write.RemovalRows` is a shared helper. Consumed-by: the 16 delete tools in this story (batch 5). Consumes: `Kernel.Proposal.Mint.Display`. No other new service or module.

**Extend, don't copy (Rule 31).**

- `RemovalRows` lifts variant B into `Write.cls`, the deletes' shared base; A and C join through a non-object default and a flag. A helper rather than a new `StateDiff` default, because the default serves about 90 tools.
- `withDeadline` joins `protocol-retry.mjs`, the home of `isProtocolTimeout`, so `retryOnce` needs no change.
- `signedInAt`'s diagnostic extends the one helper every spec uses; `settle` keeps its loop.
- `testClassesOnDisk` keeps its name and callers; the instance's query (`ci-unit-test.sh:80`) is the shape it now matches.
- DW-1981 follows `code-list.page.ts`'s binding; there is no shared criterion component to extend.
- DW-2260 keeps the older store's export rather than adding a paths module for one pair of constants.

**Contended.** At plan time Epic 20 (head `fcd01977`) has changed no code file against the feature branch. Re-run before each batch: `git -C /Users/jbrandt/git/OcuPilot/.worktrees/epic-20 diff --stat origin/feature/OCU-1_ocupilot-mvp...HEAD` and `git -C /Users/jbrandt/git/OcuPilot/.worktrees/epic-20 status -s`. Story 20.34 plans add-only edits to `Write.cls` and `Prohibited.cls`, an edit to `shell/screen-action-handler.ts` and an owners-roster row in `screen-mirror.test.mjs`. This story's `Write.cls` change is add-only (orchestrator ruling 2026-10-14) and it edits neither other file nor the roster. Any file on this story's list that Epic 20 has changed by then is listed here as "Contended: <file>" and routed by the lead before the batch.

**Wording needed:** none. No on-screen string changes. The DW-1760 sentence is a build and `Validate` message (no serving path calls `Validate`), and the DW-1822 and DW-2512 lines are test output.

**Release-upgrade triggers:** none (no `Kernel/State`, `Install`, `module.xml`, compose or container start script).

**For the Planner (DW-1177).** CLAUDE.md :134-135 should read: "(21 rules; the `.githooks/pre-commit` hook runs it over the whole tree whenever a commit stages ObjectScript, `ui/`, `module.xml` or `scripts/*.sh`, and it blocks the commit)". The "(21 rules;" form must stay, because `test_check_objectscript.py:275` parses it.

**Decided in-stage:**

- **Batch order:** the flakes first (charter), docs next (smallest), the shared lift last (widest).
- **DW-1822: a 60 s deadline per walk call, not the ledger's split.** The logs show 600 s steps, not slow screens. 60 s is three times `SETTLE_TIMEOUT_MS` and about 80 times a normal visit; the protocol limit stays 600 s for every other call.
- **DW-1822: the `settle` change is a sync status read.** It keeps the fonts condition and puts it under the existing bound. A font that never loads now fails settling at 20 s (the screen is counted unsettled) instead of hanging.
- **DW-1822: tools tests with fakes, not a new browser spec.** The mechanism is reproducible without a browser, the tests run in `npm test` and every CI gates leg, and no browser roster changes.
- **DW-2512: diagnostic plus, if measured safe, a smaller seed for the one leg that needs only a paused task.** `networkidle2` and the 30 s default stay: changing them touches 177 specs for one event.
- **DW-2512: 30,000 nodes** (about 117 MB, a tenth). Task 0 decides whether a compact over it still pauses.
- **DW-1760 sentence:** `own privilege pair R:P is one its area '<key>' already declares, and a screen owns only a pair it requires beyond its area's (AD-8)`, in the existing pattern.
- **DW-1760: area pairs as a value argument,** so the corpus stays independent of the shipped `Area.cls`.
- **DW-2260: `shell/screen-action-handler.ts`'s `USER_FORM_READ_PATH` stays** (Story 20.34 edits that file); filing candidate.
- **The tree at dispatch.** It was clean at the step-01 check; the one changed file afterwards is a `cycle-log-epic-23.md` line the lead appended during this stage.

**Filing candidates (for the lead):**

1. `data-table-columns.browser-spec.mjs` failed 17 of 18 at its own `goto` against its local server on main push run 40026736561 (39f5106e, attempt 1); not in the ledger.
2. Other duplicated client path literals: `'/api/ocupilot/proposal'` (`core/draft.ts:20`, `core/turn.ts:72`), `DATABASE_CHECK_PATH` (`database-integrity.store.ts:30`, `database-wizard.store.ts:16`), and `screen-action-handler.ts:409`'s users form path.
3. Text criteria inputs that may lack `maxlength` in `tasks/history`, `logs/audit`, `logs/log-hub`, `system-explorer/sql-query` and `data-browser.page` (inference, unchecked).

## Verification

**Slot A** (the throwaway is down at plan time; the lead brings it up):

```yaml
  - name: a
    mcp_profile: ocupilot-slot-a
    dev_container: ocupilot
    dev_web_port: 52774
    dev_super_port: 1973
    throwaway:
      dir: /Users/jbrandt/.ocupilot-throwaways/ocupilot-ci
      project: ocupilot-ci
      container: ocupilot-ci
      web: 52776
      super: 1975
      browser_origin: http://localhost:52776
      browser_container: ocupilot-ci
```

**Shared steps:**

- **Load (loop).** `rsync -a --delete src/ /Users/jbrandt/.ocupilot-throwaways/ocupilot-ci/src/`, then `Do $System.OBJ.LoadDir("/opt/ocupilot/src","ck-d",.e,1)` in `docker exec -i ocupilot-ci iris session iris -U HSCUSTOM`. Expected: 0 errors.
- **Class (loop).** `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.<C>`, one class per call. Expected: 0 failed, confirmed in `%UnitTest_Result`.
- **Bundle (loop).** `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`.
- **Spec (loop).** `cd ui && OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci node --test --test-concurrency=1 browser/<spec>`, one file per call.
- **Checks (loop).** `uv run scripts/check-objectscript.py`; `cd ui && npm run test:tools`. Expected: clean, green.

**Commands:**

- **Batch 1 (loop):** Checks (covers `structural-walk.test.mjs`, `protocol-retry.test.mjs`, `panel-spec.test.mjs`). Load (`BackgroundSeed`), Class `BackgroundTasksLive`. Bundle. Spec `local-databases.browser-spec.mjs`, then `background-tasks.browser-spec.mjs`, then `a11y-structural-invariants.browser-spec.mjs` (about 400-480 s; record the time).
- **Batch 2 (loop):** `uv run scripts/check-objectscript.py`, `uv run scripts/test_check_objectscript.py`, `bash scripts/lint-docs.sh`. Load, Class `ProviderTransportRetry`.
- **Batch 3 (loop):** Load. Class `Descriptor`, then `Navigation`. Checks. `cd ui && node tools/screen-mirror.mjs --check`.
- **Batch 4 (loop):** Checks (covers `ci.test.mjs`, `ci-shards.test.mjs`, `client-paths.test.mjs`). `cd ui && npm run test:components`. `cd ui && npm run build` (record the journal records chunk and the initial total).
- **Batch 5 (loop, before the edit and after, equal per-class totals):** Load. Class for each of DocDbWrite, RestServiceDescriptor, InteropItemControl, DeviceDelete, EcpDataServerWrite, EcpSslConnectionWrite, InteropLookupControl, InteropLookupEdges, LanguageServerEditor, LicenseServerWrite, DatabaseWrite, DatabaseWriteDetail, MftConnectionDescriptor, NamespaceWrite, RemoteDatabaseDescriptor, RemoteDatabaseWrite, WebSessions, X509Delete. Then Checks.
- **Full ObjectScript sweep: lead-owned, not an implement-stage line.** The lead runs it on `ocupilot-ci` before batch 1's code push and again before the last `src`-changing batch's code push: `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --timings tools/ci-timings.json --shard k/20` for k = 1..20, one call each. Expected: 0 failed, confirmed in `%UnitTest_Result`. The full browser suite is CI's. The implement stage runs only the `(loop)` lines.

**Mutations (Rule 19), to record with the observed run:**

- DW-1822: restore `await document.fonts.ready` -> `structural-walk.test.mjs` red; make `withDeadline` return the promise unchanged -> `protocol-retry.test.mjs` red.
- DW-2512: drop the in-flight list from the rethrown message -> `panel-spec.test.mjs` red.
- DW-1760: drop the area check from one engine at a time -> the corpus test of that engine red.
- DW-1761: restore `%Get(...) = ""` in `MalformedPair` -> `Descriptor` red on the non-string case.
- DW-2259: restore the direct-`Extends` regex -> both `ci.test.mjs` legs red.
- DW-2260: re-declare `USERS_PATH` in `user-editor.store.ts` -> `client-paths.test.mjs` red.
- DW-1981: remove the binding -> `journal-records.page.spec.ts` red.
- DW-2299: drop `removed` from `RemovalRows`, recompile the whole `OcuPilot.Screen.Tool` package -> the 16 deletes' readers red.

**Shared surfaces:**

- `structural-walk.mjs`'s settle and walk calls, and `protocol-retry.mjs`'s exports (the a11y spec and `structural-baseline.test.mjs`).
- `signedInAt`'s timeout message (every browser spec; success path unchanged).
- `BackgroundSeed.PausedCompact`'s signature (`background-tasks.browser-spec.mjs`, `BackgroundTasksLive`; default unchanged).
- The `OwnPrivilegeCases` corpus shape and the own-pair check's signature in both engines.
- `testClassesOnDisk`'s list, 680 to 699 (`ci.test.mjs` :919 and :3200, `ci-shards.mjs` `assign`, `ci-shards.test.mjs` :93).
- The users stores' path constants and their two specs.
- `Write.cls`'s new parameter and helper (16 deletes; 4 other `REMOVALROWS` declarers unchanged).
- No new ObjectScript test class, no browser spec added, no arming roster change.
- **Standing criterion.** Every test added or changed passes on a fresh environment, in either order. Each creates and removes its own rows, databases, files and markers.

**Batch 1 observed (`ocupilot-ci`).**

- Task 0 (i): `local-databases.browser-spec.mjs` alone twice, 8/8 each, 62.4 s and 58.1 s, no navigation timeout. Task 0 (ii): `PausedCompact` over 30,000 nodes, three probes: task Paused, `Remove` OK, directory gone (0.28-0.71 s to pause, 1.7-1.9 s to remove). AC8 green at 30,000 (11.5 s against 16.1 s).
- Mutations: restoring `await document.fonts.ready` reddens `structural-walk.test.mjs` (5.0 s); dropping the `fonts.status === 'loaded'` term reddens it on its lower bound; an unwrapped walk page call (`detectScreen`'s evaluate) reddens its `bounded(` source check; `withDeadline` returning its promise reddens the two deadline cases in `protocol-retry.test.mjs` (they hung to the test timeout, now 10 s each); an empty in-flight list reddens `panel-spec.test.mjs`, as does a direct `page.goto` in `signedInAt`. Each reverted, confirmed by `cmp` against the pre-mutation copy.
- `pNodes` is pinned by `BackgroundTasksLive.TestThePausedCompactFillsTheNodeCountItIsGiven` (mutation under QA below); AC8's fill and duration (11.5 s against 16.1 s) show its effect.
- QA (batch 1), tests added (QA): `ui/tools/structural-walk.test.mjs` (hung-page cases run `settle`, `detectScreen` and `toggleThemeThroughMenu` against a fake page whose call never settles, with the 60 s deadline advanced by mock timers; a pass retried once through `retryOnce`; the report line), `ui/tools/panel-spec.test.mjs` (`signedInAt` run against a fake browser whose `goto` times out, with a request made by `prepare` and one by the navigation in flight), and `OcuPilot.Test.BackgroundTasksLive.TestThePausedCompactFillsTheNodeCountItIsGiven` (the seed's size argument).
  - mutation: drop `bounded(` from the settle evaluate -> `structural-walk.test.mjs` settle hung-page case red (10 s test timeout).
  - mutation: drop `bounded(` from the `detectScreen` evaluate -> its hung-page case red.
  - mutation: drop `bounded(` from the theme toggle's class wait -> its hung-page case red.
  - mutation: `WALKCALLDEADLINE` 60_000 to 90_000 -> the three hung-page cases red.
  - mutation: drop the retried-pass line from `reportLines` -> "the walk's report names each retried pass" red.
  - mutation: `signedInAt` calls `page.goto` directly -> `panel-spec.test.mjs` `signedInAt` run and source-order case red.
  - mutation: `signedInAt` starts tracking after `prepare` -> the same two red.
  - mutation: `gotoNamingInflight` lists no requests -> the first case and the `signedInAt` run red.
  - mutation: `PausedCompact` calls `..Prepare()` without `pNodes` -> `TestThePausedCompactFillsTheNodeCountItIsGiven` red alone (1 of 9, run 703); reverted, 9/9 (run 704).
  - Each reverted and confirmed by `cmp` against a pre-mutation copy; `git status --short` lists only the three QA files.
- Green: `npm run test:tools` 2164/2164; `check-objectscript.py` 0 problems; `BackgroundTasksLive` 8/8; `background-tasks.browser-spec.mjs` 2/2; `a11y-structural-invariants.browser-spec.mjs` 13/13 in 420.8 s with no retried-pass line (414.8 s at 7dd30507).

- Code review (batch 1), mutations on its pins, each reverted and confirmed by `cmp`:
  - mutation: `fieldNames(page)` without `bounded(` -> the field-name hung-page case red.
  - mutation: settle's label without `where` -> the settle-on-a-path, `goInApp` and retried-pass cases red; `goInApp` calling settle without its path -> the `goInApp` case red.
  - mutation: drop `report.retried.push(...)`, or the `failure` capture, from `passRetrier` -> the retried-pass case red.
  - mutation: the theme toggle's first click without `bounded(` -> the source check red.
  - mutation: the old deadline message tail -> the `protocol-retry.test.mjs` deadline case red.
  - Green after review: `npm run test:tools` 2178/2178; `a11y-structural-invariants.browser-spec.mjs` 13/13 in 397 s on `ocupilot-ci`, no retried-pass line.

**Batch 4 and DW-1706 observed (`ocupilot-ci`).**

- `testClassesOnDisk` lists 699 classes, equal to the `objectscript` keys of `ci-timings.json` both ways (680 before).
  - mutation: restore the direct-`Extends` regex -> both DW-2259 tests in `ci.test.mjs` red.
  - mutation: `USERS_PATH` re-declared in `user-editor.store.ts` -> `client-paths.test.mjs` red.
  - mutation: remove the `[attr.maxlength]` binding -> `journal-records.page.spec.ts` red ("offset: expected null to be '20'").
  - Each reverted and confirmed by `cmp` against a pre-mutation copy.
  - mutation (review): drop the abstract check from `testClassesOnDisk`'s final filter, or keep only the first name of a parenthesized `Extends` list -> the abstract-with-tests case in `ci.test.mjs` red; each reverted, confirmed by `cmp`.
- Green: `npm run test:tools` 2183/2183; `check-objectscript.py` 0 problems; `npm run test:components` 3341/3341; `lint-docs.sh` clean; Load 0 errors and `ProviderTransportRetry` 9/9.
- QA (pass 2), test added (QA): `ui/tools/ci.test.mjs`, "the checkout list survives a wrapped class header, a class with no Extends and an Extends cycle (DW-2259)" (an `Extends` list and a keyword list wrapped over lines, a class with no `Extends`, and two-class cycles with and without a `Test*` method). No test compares `testClassesOnDisk` with the `objectscript` keys of `ci-timings.json`: the file is refreshed only at a merge, so an equality test would redden the story that adds a test class (the two are equal at 699 today).
  - mutation: drop the `seen` guard from `reachesTestCase` -> the wrapped-header/cycle test red.
  - mutation: read the class header on one line only (`\s*` to ` *` before the keyword list) -> the same test red.
  - mutation: drop the `seen` guard from `hasTests` -> the same test red (the cycle with no own `Test*` method).
  - mutation: replace the final filter with a direct-`Extends` test (DW-2259) -> all three DW-2259 tests in `ci.test.mjs` red.
  - mutation: re-declare `USERS_PATH` in `user-editor.store.ts` (DW-2260) -> `client-paths.test.mjs` "USERS_PATH is declared once" red.
  - mutation: delete the `[attr.maxlength]` binding (DW-1981) -> `journal-records.page.spec.ts` "bounds the offset and value inputs" red alone ("offset: expected null to be '20'").
  - DW-1706 is a doc comment: no test, no mutation. Each reverted, confirmed by `cmp` against a pre-mutation copy.
- Build: the journal records chunk is `chunk-BwhbAgfu.js`, 11,658 bytes raw; initial total 2.01 MB (357.88 kB transfer), under the 2500 kB warning.
- Code review (bmad-code-review), mutations on its pins, each reverted and confirmed by `cmp`:
  - mutation: `reachesTestCase` follows every name of an `Extends` list -> the abstract/primary-superclass case in `ci.test.mjs` red (`Secondary` listed).
  - mutation: `hasTests` reads the first superclass only -> the same case red (`Mixed` dropped).
  - mutation: the abstract test back to `\bAbstract\b` -> the same case red (`NotAbstract`, `AbstractZero` dropped).
  - mutation: accept any superclass ending `.TestCase` -> the same case red (`FromLookalike` listed).
  - mutation: a direct-`Extends` filter -> the first, second and real-tree DW-2259 tests red.
  - mutation: `export const USERS_PATH: string =` re-declared in `user-editor.store.ts` -> `client-paths.test.mjs` "USERS_PATH is declared once" red.
  - Green after review: `testClassesOnDisk` 699, equal to the `ci-timings.json` keys both ways; `npm run test:tools` 2184/2184; `npm run test:components` 3341/3341; `client-lint.mjs` clean; `check-objectscript.py` 0 problems; `Error.cls` loaded into `ocupilot-ci` with 0 errors and `ProviderTransportRetry` 9/9.

**Batch 5 observed (`ocupilot-ci`).**

- Before the edit (tree at `38ec7c97`, Load 0 errors), per-class totals, all 0 failed: DocDbWrite 8, RestServiceDescriptor 8, InteropItemControl 6, DeviceDelete 6, EcpDataServerWrite 11, EcpSslConnectionWrite 6, InteropLookupControl 7, InteropLookupEdges 10, LanguageServerEditor 9, LicenseServerWrite 6, DatabaseWrite 16, DatabaseWriteDetail 5, MftConnectionDescriptor 8, NamespaceWrite 10, RemoteDatabaseDescriptor 5, RemoteDatabaseWrite 9, WebSessions 9, X509Delete 4; 143 in all.
- After the edit (Load 0 errors), the same 18 classes one at a time, all 0 failed, totals equal class by class (143 in all): runs 26-43.
  - mutation: drop `removed` from `RemovalRows`, whole `OcuPilot.Screen.Tool` package recompiled -> 9 of the 18 reader classes red: DocDbWrite, RestServiceDescriptor, DeviceDelete, InteropLookupControl, LanguageServerEditor, DatabaseWriteDetail, MftConnectionDescriptor, WebSessions, X509Delete (runs 44-61). Nine stayed green: InteropItemControl, EcpDataServerWrite, EcpSslConnectionWrite, InteropLookupEdges, LicenseServerWrite, DatabaseWrite, NamespaceWrite, RemoteDatabaseDescriptor, RemoteDatabaseWrite.
  - mutation: `RemovalRows` pushes no row -> the same nine red plus EcpDataServerWrite, EcpSslConnectionWrite and InteropLookupEdges (12 red); InteropItemControl, LicenseServerWrite, DatabaseWrite, NamespaceWrite, RemoteDatabaseDescriptor and RemoteDatabaseWrite stay green (runs 62-79). No test among the 18 observes the rows of `InteropItemRemove`, `LicenseServerDelete`, `NamespaceDelete` or `RemoteDatabaseDelete`; the premise "all 16 deletes' readers red" does not hold for those four, as it did not before the lift.
  - Reverted, confirmed by `cmp` against a pre-mutation copy; whole package recompiled; the 12 red classes re-run green (runs 84-95).
- Code review (batch 5), tests added to existing reader classes so every delete's rows are observed: `InteropItemDescriptor.TestTheRemoveCardListsWhatTheItemLeavesWith` (InteropItemRemove, the state as a word), `LicenseDescriptor.TestTheDeleteCardListsTheServerItRemoves`, `NamespaceDescriptor.TestTheDeleteCardListsTheDatabasesItRemoves`, `RemoteDatabaseDescriptor.TestTheDeleteCardListsTheDatabaseItRemoves`, a non-object leg in `RestServiceDescriptor.TestTheDeleteCardNamesWhatTheActionRemoves` and a partial-read leg in `MftConnectionDescriptor.TestTheCardsListWhatTheActionsRemove`. Whole `OcuPilot.Screen.Tool` package recompiled before each read; each reverted, `Write.cls` confirmed by `cmp` against a pre-mutation copy.
  - mutation: drop `removed` from `RemovalRows` -> the four new methods plus the Rest and Mft legs red (runs 102-107).
  - mutation: `RemovalRows` reads a non-object `pFresh` as an object -> `RestServiceDescriptor` red (run 108).
  - mutation: `MftConnectionDelete`'s skip flag ignored -> the Mft partial-read leg red (run 109).
  - mutation: `before` as `pFresh.%Get(tField) _ ""` instead of `Mint.Display` -> `InteropItemDescriptor` red (run 131).
- Green after review: the 18 reader classes and the 4 new-test classes (`InteropItemDescriptor` 10, `LicenseDescriptor` 9, `NamespaceDescriptor` 5), all 0 failed, totals equal to the before figures except `RemoteDatabaseDescriptor` 5 to 6 (its new method); `check-objectscript.py` 0 problems; `npm run test:tools` 2188/2188.

- QA (batch 5), per-delete reader matrix on `ocupilot-ci`: `Write.RemovalRows` mutated per tool (selector `^QAMut`, `$ClassName()`-keyed), whole `OcuPilot.Screen.Tool` package recompiled once, each tool's reader classes run with seven mutations (`removed` dropped, first-row `before`, second-row `before`, last-row `before`, last row dropped, first two fields swapped, `after` set). Before the QA edits, gaps: `removed` for EcpDataServerDelete, EcpSslConnectionDelete, InteropLookupTableDelete; first-row `before` and order for InteropLookupTableDelete; order for InteropLookupEntryRemove and LocalDatabaseDelete; `after` for the two ECP deletes, both lookup deletes, LocalDatabaseDelete, MftConnectionDelete, WebSessionEnd; last-row `before` for LocalDatabaseDelete and X509Delete. After the QA edits every applicable mutation reddens a reader for all 16 deletes (a single-field tool has no second-row or swap mutation).
  - mutation: drop `removed` -> reader per delete: DeviceDelete `DeviceDelete.TestTheCardListsWhatGoesAndAConfirmDeletes`; EcpDataServerDelete and EcpSslConnectionDelete `EcpDescriptor.TestTheEcpDeleteCardsListWhatTheyRemove`; ExplorerDocDbDelete `DocDbWrite.TestTheAgentsDropIsGovernedThenConfirmed`; InteropItemRemove `InteropItemDescriptor.TestTheRemoveCardListsWhatTheItemLeavesWith`; InteropLookupEntryRemove `InteropLookupControl.TestTheAgentsRemoveConfirmsOverHttp`; InteropLookupEntryRemove and InteropLookupTableDelete `InteropLookupDescriptor.TestTheLookupDeleteCardsListWhatTheyRemove`; LanguageServerDelete `LanguageServerEditor.TestTheDeleteRefusesARunningServer`; LicenseServerDelete `LicenseDescriptor.TestTheDeleteCardListsTheServerItRemoves`; LocalDatabaseDelete `DatabaseDescriptor.TestTheDeleteCardListsWhatTheDatabaseKeeps` and `DatabaseWriteDetail.TestTheDeleteCardShowsWhatTheWriteRemoves`; MftConnectionDelete `MftConnectionDescriptor.TestTheCardsListWhatTheActionsRemove`; NamespaceDelete `NamespaceDescriptor.TestTheDeleteCardListsTheDatabasesItRemoves`; RemoteDatabaseDelete `RemoteDatabaseDescriptor.TestTheDeleteCardListsTheDatabaseItRemoves`; RestServiceDelete `RestServiceDescriptor.TestTheDeleteCardNamesWhatTheActionRemoves`; WebSessionEnd `WebSessions.TestTheStateDiffListsTheSessionAsRemoved`; X509Delete `X509Delete.TestTheRemovalRowsAndAReplacedCertificateRefusesTheConfirm`.
  - mutation: `after` set, last-row `before`, second-row `before`, last row dropped, fields swapped -> red for the same tools, the three strengthened readers (`MftConnectionDescriptor.TestTheCardsListWhatTheActionsRemove`, `WebSessions.TestTheStateDiffListsTheSessionAsRemoved`, `X509Delete.TestTheRemovalRowsAndAReplacedCertificateRefusesTheConfirm`) included.
  - Reverted: `Write.cls` byte-identical to the pre-mutation copy (`cmp`), package recompiled, `^QAMut` killed; the 24 reader classes re-run green, 201 tests, 0 failed (runs 408-431).
  - (QA) tests added: `EcpDescriptor.TestTheEcpDeleteCardsListWhatTheyRemove`, `InteropLookupDescriptor.TestTheLookupDeleteCardsListWhatTheyRemove`, `DatabaseDescriptor.TestTheDeleteCardListsWhatTheDatabaseKeeps` (each calls the delete's `StateDiff` with a fixed read and pins the full row list); (QA) strengthened: `MftConnectionDescriptor`, `WebSessions` (row text now carries `after`), `X509Delete` (every field's `before`, in order).
  - Files (QA): `src/OcuPilot/Test/EcpDescriptor.cls`, `src/OcuPilot/Test/InteropLookupDescriptor.cls`, `src/OcuPilot/Test/DatabaseDescriptor.cls`, `src/OcuPilot/Test/MftConnectionDescriptor.cls`, `src/OcuPilot/Test/WebSessions.cls`, `src/OcuPilot/Test/X509Delete.cls`. `check-objectscript.py` 0 problems; `npm run test:tools` 2188/2188.

**Batch 3 and DW-1177 observed (`ocupilot-ci`).**

- Load 0 errors; `Descriptor` 60/60 (run 25) and `Navigation` 14/14 (run 26), confirmed in `%UnitTest_Result` on `ocupilot-ci`; `screen-mirror.test.mjs` 78/78; `check-objectscript.py` 0 problems; `test_check_objectscript.py` 146 OK; `npm run test:tools` 2190/2190; `screen-mirror.mjs --check` up to date (213 descriptors, 11 areas); `lint-docs.sh` clean.
- Red before: with `HEAD`'s `Registry.cls` loaded, `Descriptor` red on `TestAPairAScreenDeclaresItsOwnIsLeftOutOfItsAreasCoverage` (`<PARAMETER>`, the old one-argument signature, run 18) and `Navigation` red on `TestAMalformedPrivilegePairIsRefused` (the `PairType.Bad` fixture refused with the area-coverage sentence, run 19); with `HEAD`'s `screen-mirror.mjs`, the own-privilege corpus test red on "an own pair the area already declares". The mirror's `malformedPair` case for `resource: 5` was already green (its string check is the reference).
  - mutation: `OwnPrivilegesProblem` ignores `pAreaPairs` (recompiled with its dependents) -> `Descriptor` red on "an own pair the area already declares" and "the area's pair is named past an own pair the area does not declare" (run 22).
  - mutation: `MalformedPair` back to the `= ""` comparisons -> `Navigation` red on the non-string fixture leg (run 23) and `Descriptor` red on "a resource that is not a string" (run 24).
  - mutation: `ownPrivilegesProblem` skips the area check -> the corpus test red on "an own pair the area already declares".
  - mutation: `buildMirror` omits the area argument -> the same test red (its build leg).
  - Each reverted and confirmed by `cmp` against a pre-mutation copy; reloaded with 0 errors; the final runs above are post-revert.
  - Review patch: `Validate` leg and corpus cases `a permission that is not a string` and `an entry that is an array, not a pair`; `Descriptor` 60/60 (run 32), `Navigation` 14/14 (run 33), `npm run test:tools` 2190/2190, `check-objectscript.py` 0 problems.
  - mutation: `Validate` calls `OwnPrivilegesProblem(tObject)` without the area's pairs -> `Descriptor` red on `TestAPairAScreenDeclaresItsOwnIsLeftOutOfItsAreasCoverage` (run 29).
  - mutation: `MalformedPair` without its `permission` type clause -> the same test red (run 30).
  - mutation: `MalformedPair` without its `%IsA` clause -> the same test red (run 31).
  - Each reverted and confirmed by `cmp` against a pre-mutation copy; every class reloaded with `LoadDir` before its run.
- New fixtures: `OcuPilot.Test.PairType.Bad` and `OcuPilot.Test.PairTypeRegistry` (descriptor and registry only; no test class, no roster), and `OcuPilot.Test.OwnPairArea.Bad` with `OcuPilot.Test.OwnPairAreaRegistry` (the same).

## Auto Run Result

Status: done
Blocking condition: none

Pass: Batch 3 (DW-1761, DW-1760 (a)) and DW-1177's docstring. DW-1760 (b) closes by-design at adjudication. Earlier passes closed in their own commits.

- Change: `Registry.cls` `MalformedPair` requires string halves; `OwnPrivilegesProblem` takes `pAreaPairs`, refuses an area-declared own pair with the spec sentence, and `Validate` passes `Area.PrivilegePairs`; `screen-mirror.mjs` `ownPrivilegesProblem` takes the area's privileges and `buildMirror` passes them; the `OwnPrivilegeCases` corpus gains `area`, `areaPrivileges` and four cases; `check-objectscript.py` docstring states the hook's whole-tree scope.
- Files: `src/OcuPilot/Screen/Registry.cls`, `src/OcuPilot/Test/DeclarationCorpus.cls`, `src/OcuPilot/Test/Descriptor.cls`, `src/OcuPilot/Test/Navigation.cls`, fixtures `src/OcuPilot/Test/PairType/Bad.cls`, `PairTypeRegistry.cls`, `OwnPairArea/Bad.cls`, `OwnPairAreaRegistry.cls`, `ui/tools/screen-mirror.mjs`, `ui/tools/screen-mirror.test.mjs`, `scripts/check-objectscript.py`; this spec.
- Review: 3 findings - 1 medium and 1 low patched (the `Validate` leg; two `MalformedPair` clauses), 1 maybe-false rejected with its reason; none deferred.
- Verification: `Descriptor` 60/60 and `Navigation` 14/14 on `ocupilot-ci`; `screen-mirror.mjs --check` up to date (213 descriptors); `npm run test:tools` 2190/2190; `check-objectscript.py` 0 problems and its harness 146 OK; `lint-docs.sh` clean; all mutations observed red and reverted (Verification, Batch 3 and DW-1177 observed).
- Follow-up review: not recommended; this pass patched no high.
- Residual risk: `ui/tools/screen-mirror.mjs` and `screen-mirror.test.mjs` also carry uncommitted Story 20.36 edits in the Epic 20 worktree, in other regions (`parseEntryWorkflowIds`, the workflow-ids test); the edits here are in `malformedPair`, `ownPrivilegesProblem`, `buildMirror` and the own-pair tests, so a merge is expected to be clean.
