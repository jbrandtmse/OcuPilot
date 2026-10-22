---
title: 'Story 23.8: The range-end cleanup, part 7'
type: 'bugfix'
created: '2026-10-21'
status: 'done'
baseline_revision: '60bceb233e9d5f5a1d3b7cd39e53cd22e641d8cb'
baseline_commit: '60bceb233e9d5f5a1d3b7cd39e53cd22e641d8cb'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
warnings: ['multiple-goals', 'oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** This story owns twelve ledger entries, seven medium and five low. Each was checked at `06c2f491`; the verdicts are in Design Notes. Eleven are confirmed and one is partly so (DW-2256's reason never reaches the wire). The live defects are:

- `shell.screen.open`'s `entityId` means the parent's id on 37 parent-scoped screens and a row key on 99 others, with nothing in the contract saying which.
- `ci-throwaway.sh`'s scratch-root guard admits any absolute path when `TMPDIR` is `/`, a sibling of `TMPDIR`, a root spelled with `//` or `/./`, and a symbolic link, ahead of a recursive delete.
- Docker kills IRIS about 3 s after the stop signal, mid-shutdown (measured), so every container stop logs "Previous system shutdown was abnormal".
- The explorer save mint names the wrong reason.
- A test fixture loses the keys it failed to sweep.

The rest are an undocumented constraint, an undocumented developer-visible behavior, a missing lint family, and three copies of one Save shape.

**Approach:** Five area batches, in this order:

1. Explorer save and fixture.
2. Scripts, install and container.
3. Client lint.
4. Navigation contract.
5. Shared Save.

Each batch is one implement pass and one code commit, with CI green on its own head. Each fix gets a test that reddens before it, or the entry says why none can (Rule 19). The story's ACs allow only `resolved-by`, `wontfix-accepted` (with `reopen_if`) or `by-design` for each entry.

## Boundaries & Constraints

**Always:**

- **Where to work.** Work in `/Users/jbrandt/git/OcuPilot/.worktrees/epic-23` on `OCU-1-epic23`, and check `git rev-parse --show-toplevel` first. Every IRIS MCP call carries `server: "ocupilot-slot-a"`.
- **Where tests run.** Tests, probes and mutations run only on `ocupilot-ci` (52776/1975, directory `/Users/jbrandt/.ocupilot-throwaways/ocupilot-ci`), once `docker inspect -f '{{.State.Health.Status}}' ocupilot-ci` reads `healthy`.
  - One test run in flight. Wait for each to land in `%UnitTest_Result`, and never re-submit after a client-side timeout.
  - Every command runs in the foreground with `timeout: 600000`.
- **Batches.** One implement pass per batch. The lead integrates forward, re-opens the spec for each batch, and scopes the pass to that batch's unchecked items. Before each batch, re-run the two read-only Epic 20 checks under Design Notes › Contended files.
- **Locating code.** Find code by method name; line numbers are at `06c2f491`.
- **Writing code.**
  - Wire codes and HTTP statuses stay byte-identical, except the rows marked CHANGED below.
  - Extend the sibling named under Design Notes (Rule 31).
  - Comments state the contract (Rule 14), and non-ASCII in source is written as `$Char(n)` or `\uXXXX`.
  - Docs use US spelling (`scripts/check-prose.py`).
- **Pinned rosters stay equal.** The arming rosters in `scripts/ci-throwaway.sh` (`ui/tools/ci.test.mjs`) are untouched.

**Never:**

- Any edit to `CLAUDE.md`, `.claude/**`, `_bmad/**` or `.github/workflows/ci.yml`. The wording they would need goes to the Planner (Design Notes).
- An edit to `README.md` or `docker-compose.yml` unless the lead's spec-gate ruling admits the change written under Design Notes › For the lead.
- A new error `code`, or a 22nd `check-objectscript.py` rule.
- A stored-schema change. No property is added to a `Kernel/State` class.
- A write, load or compile on `ocupilot`, or a stop, restart, recreate or `down` of any container. The DW-1762 restart measurement is the lead's.
- The full ObjectScript sweep (the lead's) or the full browser suite (CI's).
- Anything inside the epic-20 worktree beyond the two read-only git checks.
- `ci-throwaway.sh down`, or any destructive action, in a test of the guard. Use `logs --dir`: the guard runs before dispatch, and `logs` makes no docker call when no compose file exists.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| CHANGED: parent reference (DW-1462) | `shell.screen.open {route: "tasks/schedule/details", parentId: "7"}` | Announced, opens `tasks/schedule/details/7`. The settled result is `{navigated, route, parentId: "7"}`. | — |
| CHANGED: entityId on a parent-scoped screen | `{route: "tasks/schedule/details", entityId: "7"}` | Refused before any announcement: `NAV.ENTITYNOTALLOWED`, `detail.argument` `entityId` | Today it is accepted and read as the parent's id |
| parentId on a screen with no parent | `{route: "tasks/schedule", parentId: "7"}` | `NAV.ENTITYNOTALLOWED`, `detail.argument` `parentId` | — |
| CHANGED: parent with a composite id | `{route: "interoperability/productions/items/jobs", entityId or parentId: "P\|\|N"}` | `NAV.ENTITYNOTALLOWED` | Today `entityId` is accepted: the model composes the parent's two-part id, the second grammar AD-5 forbids |
| CHANGED: newly openable for its parent | `{route: "tasks/schedule/history", parentId: "7"}`, and the other seven screens listed under Design Notes | Accepted | Today refused, because the screen's own id kind is read instead of its parent's |
| Unchanged: own row | `{route: "permissions/users", entityId: "_SYSTEM"}` | Accepted, settled with `entityId`, as today | — |
| CHANGED: agent save of a source-less routine (DW-2256) | `ExplorerSaveMint.Mint` on a routine `USER` keeps only as object code | 404, `PORT.NOTFOUND`, and `pFault.reason` = `AtelierPort.#REASONNOSOURCE` | Today the reason is `REASONNOTFOUND`. The model's content is `{code}` either way. |
| CHANGED: unsafe scratch directory (DW-235) | `ci-throwaway.sh logs --dir X`: `TMPDIR=/` with `/nonexistent-dw235/x`; `TMPDIR=/nonexistent-tmp-dw235` with `/nonexistent-tmp-dw235x`; `/tmp//`; `/tmp/./x`; `$HOME/.ocupilot-throwaways//`; a `--dir` that is a symbolic link | Exit 2 with a refusal line, and no docker call | Today each exits 0 |
| Unchanged: safe scratch directory | `/tmp/ocupilot-ci`; `$HOME/.ocupilot-throwaways/ocupilot-ci` | Admitted | — |
| CHANGED: armed class on a non-throwaway (DW-432) | The runner reads a class-level error whose text names `OCUPILOT_ALLOW_PRINCIPALS` | The failure line also says the class is armed, by which variable, and that only `scripts/ci-throwaway.sh` sets it | Still a failure |
| CHANGED: fixture sweep with a failing key (DW-1267) | Two seeded keys; one key's proposal delete fails | Status is the error. The other key is swept. The failed key is kept, so a later `RemoveSeeded` removes it. `pRemaining` counts proposals and turns, and is -1 when unreadable. | Today every key is forgotten |
| CHANGED: unstyled template class (DW-1188) | `class="ocu-not-styled"` in a template; no selector; not allow-listed | `node tools/client-lint.mjs` exits 1 naming file:line, so `npm run build` stops | — |
| Unchanged: the three Saves (DW-2278) | Every Superserver, MFT connection, Doc DB application and routine application create and update | The same status, code and body as today | — |

</intent-contract>

## Code Map

### Batch 1: explorer save and fixture

- `src/OcuPilot/Screen/Tool/ExplorerSaveMint.cls`, `Mint`:
  - :70-75: an unavailable document is answered with `AtelierPort.#REASONNOTFOUND` (DW-2256).
  - :88-94: the escaped length is measured inline (DW-2257). The surrounding `Try` stays: on 2.2M quotes the measure raises.
- `src/OcuPilot/Screen/Tool/ExplorerSourceRead.cls`:
  - `View` (:122-127) is the sibling that already answers `REASONNOSOURCE`.
  - `Escaped` (:190) is the public measure.
  - `SOURCEMAXLENGTH` is at :22, and `CUTTEXT` (:25) states "60,000" in prose.
- `src/OcuPilot/Port/AtelierPort.cls`:
  - `REASONNOTFOUND` (:585), `REASONNOSOURCE` (:589) and `MAXIMPORTCHARACTERS` (:419).
  - The document read sets `available` 0 and `reason` `objectonly` for a routine the index holds whose `GetDoc` answers 404 with an empty status and an empty ts (:2808-2836).
- **What reaches the model.** `Kernel/Agent/Dispatch.cls` `AnswerOne` (:334-337) sends a mint refusal as `ErrorContent(code, detail)`: code and detail, no reason. The step's reason is `Error.ReasonForToolCode(code)`. So the mint's own `pFault.reason` is its only surface.
- `src/OcuPilot/Test/ExplorerSaveFlow.cls` (431 lines):
  - `TestAnEditPastThePortsBoundIsRefused` (:333) pins the bound.
  - Helpers: `Refused` (:104), `Dispatch` (:63), `PROBE` = `ExplorerSaveAgentProbe`.
- `src/OcuPilot/Test/ExplorerSaveTurn.cls`:
  - `Do ..RemoveKeyed()` at :199, :218 and :237.
  - Its sibling `ExplorerSourceTurn` uses `$$$AssertStatusOK(..RemoveKeyed(), "the probe package is removed")` (:133, :161).
- **The bound's tests** (DW-2261):
  - `src/OcuPilot/Test/ExplorerSource.cls` (:25) and `ExplorerSourceEdges.cls` (:36) declare `Parameter LIMIT = 60000`.
  - Both extend `ExplorerSourceTestCase.cls` (51 lines).
  - Literals derived from the bound: `ExplorerSourceEdges` :146 (`30000`, the bound over two) and :320 (`59999`, the bound less one).
  - The mutation note at `ExplorerSourceEdges` :155 (a subclass declaring 600000) must stay true.
- `src/OcuPilot/Test/ProposalFixture.cls`:
  - `RemoveSeeded` (:477-495): on an `Update` failure the loop quits and `Kill ^||OcuPilotProposalFixtureTurns` drops the unreached keys. `pRemaining` counts proposals only. The doc says "how many of either survive".
  - `Remove` (:458) is the sibling: it counts both, and answers -1 when unreadable.
  - `Update` (:944) is private and overridable.
  - It is called by 242 files; 158 assertions read the remaining count.

### Batch 2: scripts, install and container

- `scripts/ci-throwaway.sh`:
  - The HOME root (:61-68) is already normalized.
  - The guard (:109-115) uses `"${TMPDIR:-…}"?*` raw.
  - `scrub_data` (:147-151) removes with a root-container fallback, and `rm -rf "$DIR"` runs at :168 (`up`) and :1021-1022 (`down`).
  - The generated `iris` service is at :197-; it has no `stop_grace_period`.
- `scripts/ci-ipm-archive.sh`:
  - :108-124 is the hardened `SCRATCH_TMPDIR` block to port. It still admits `/tmp//` and `/tmp/./` (measured).
  - `rm -rf "$DIR"` is at :230.
- `ui/tools/ci.test.mjs`:
  - `runThrowaway` (:1865) and the DW-2034 guard test (:1945) show the `logs --dir` pattern.
  - The compose-key comparison is at :2175.
  - `declaredArmingRosters` is at :2285, and the arming tests at 2275-2445.
  - The `classifyFailureDetail` tests are at :1102-1122.
- `ui/tools/ipm-archive.test.mjs` :365 is the guard test of `ci-ipm-archive.sh`.
- `ui/tools/ci-runner.mjs` `classifyFailureDetail` (:194-213): the class-level message is at :210.
- **The arming family.**
  - 20 `OCUPILOT_ALLOW_*` variables are set only by `ci-throwaway.sh` (:233-781).
  - `PRODUCTION_INSTALL` arms 29 classes at head.
  - An unarmed class returns a class-level error from `OnBeforeAllTests` and runs no method; `Test/Installer.cls` :21-33 is representative.
  - The error text names the variable through `..#ARMINGVARIABLE`. The runner's class-level record carries the hook's name as `action` and this text as `error` (`ci-unit-test.sh`).
- **DW-1762, measured.**
  - Entrypoint `/tini -- /iris-main`. `StopTimeout` is null and `StopSignal` empty on `ocupilot` and `ocupilot-ci`.
  - Every abnormal stop died about 3.0-3.4 s after the first shutdown line, inside "Stopping User Jobs".
  - Clean stops took 4.9-5.0 s, of which "Stopping User Jobs" was 4.5 s.
  - Docker Desktop's log reads "Container failed to exit within 3s of signal 15 - using the force".
  - `iris-main` has no shutdown-timeout option.
  - Where the 3 s default comes from is unknown (inference: the Engine 29.7.2 / Compose v5.5.0 / Desktop default).
- **DW-216.**
  - `src/OcuPilot/Install/Smoke.cls`: `Host()` (:274) is always `localhost`, and its doc refuses other hosts on purpose. `Port()` (:282) is `Config.Startup` `WebServerPort`. `Request()` (:319) is plain HTTP.
  - The class header (:10-11) offers the class to operators, and so does `README.md` :555-557.
  - `docs/DEVELOPMENT.md` "The smoke script" runs 412-450, and "What CI runs" 452-503. The paragraph "The ObjectScript suite runs one class at a time" is at :467.

### Batch 3: client lint

- `ui/tools/client-lint.mjs`:
  - Six families today; the header at :3 says "four".
  - Each is a pure `check*({path, text, …})` answering `{ok, errors}`.
  - `ALLOWED_ABSOLUTE_URLS` (:327-335) is the literal allow-list precedent.
  - `walk` is at :585-597, `lintClient` at :604-660, and `RULE_FAMILIES` at :668-675.
  - `main` exits 1 on any error. It runs in `ui/package.json` `prebuild` (:8) and `prestart` (:10).
- `ui/tools/client-lint.test.mjs`: fixture tests (:39-147), the family roster (:149-151), the real-tree clean run (:327-337), the wiring (:351-360), and CLI scratch trees with `--root` (:548-566, :654-686).
- **Measured at head.**
  - Templates use 962 distinct `ocu-` class names and stylesheets select 837; 138 are used but unstyled.
  - Class sources: `class="…"`, `[class.ocu-x]`, string literals in `[class]`, `host: {class}`, and TypeScript class constants. Style sources: `ui/src/styles/*.scss` and component `styles:`.
  - Two composed names: `list-page.ts:358-359` (`ocu-banner-${severity}`, bound at :88) and `core/reply.ts:302` (`ocu-reply-heading-${depth}`). Both are styled.
  - `ocu-` ids are id contexts only, never class contexts.
  - The 138 split into three groups, listed under Design Notes: 90 test hooks, 4 owed a style, and 44 dead tokens.

### Batch 4: navigation contract

- `src/OcuPilot/Screen/Tool/Navigate.cls`:
  - `DESCRIPTION` is at :58, `InputSchema` at :93-125 (the `entityId` text at :105), and `ResultSchema` at :138-151.
  - `Directive` (:201-254) refuses in this order: `NAV.ROUTEUNKNOWN`, `NAV.ENTITYNOTALLOWED`, `NAV.CRITERIONUNKNOWN`, criteria.
  - `AcceptsEntityId` (:261-276) never reads `ParentScope`.
  - `RefusalFault` is at :315, and the class header's "No second composite grammar" paragraph at :18-23.
- `src/OcuPilot/Screen/Descriptor/Base.cls`: `ParentScope()` (:282, the parent's route), `IdKind()` (:290) and `IdParts()` (:297). `Screen.Registry.DescriptorForRoute` resolves a route.
- `src/OcuPilot/Kernel/Agent/Dispatch.cls`: `ResolveClientCall` (:460) calls `Directive` at :583 and hands the values out at :600-603. `SettleClient` (:631-644) emits `entityId` when the detail has one.
- `src/OcuPilot/Kernel/Agent/Loop.cls`:
  - Call at :900, announce target at :924, dropped detail at :937.
  - `Nav.GuardedRequest` at :952, and the settle detail at :1023 and :1031.
- `src/OcuPilot/Kernel/State/Nav.cls` :30-31: `EntityId`'s doc says `""` for no row. It already holds a parent's id on parent-scoped screens.
- **Unchanged.** `Kernel/State/Turn.cls` :652-680 emits `navigation.entityId`, the route's id. The client navigator (`ui/src/app/shell/agent-navigator.ts:99`) builds the URL from route and id, and `navigation.ts` `ownIdSegment`/`parentIdSegment` read it by descriptor.
- **Citation chips are unaffected.** `Screen/Tool/Registry.cls` `CitationSource` (:675) and `ui/src/app/core/citations.ts` both drop parent-scoped routes.
- `src/OcuPilot/Api/Error.cls`: `REASONNAVENTITYNOTALLOWED` (:1048) reads "This screen does not take a selected row.", and `NavCodes` is at :1132.
- **Tests that pin it.**
  - `src/OcuPilot/Test/ToolNavigate.cls` (499 lines): the registry sweep `TestAC2EntityNotAllowedOnACompositeOfMoreThanOnePart` (:94-138), `TestTheSchemaAdmitsCriterionAndNothingElse` (:208-227, four names) and `TestSettledResultEmitsOnlyDeclaredKeysWithDeclaredTypes` (:428).
  - `Test/TurnNavigate.cls` (636 lines).
  - `ui/browser/task-resume.browser-spec.mjs:228` sends `{route: DETAILS_ROUTE, entityId: id}`, the parent meaning.
  - `navigate.browser-spec.mjs` uses only own-row screens.

### Batch 5: shared Save

- **Server, line counts with code lines in parentheses.**

  | Slice | Save | Rules | Router |
  |---|---|---|---|
  | Superserver | `Area/Security/SuperserverSave.cls` 344 (283) | `SuperserverRules.cls` 339 | :256-258, :1923-1942 |
  | MFT connections | `Area/Security/MftConnectionSave.cls` 332 (273) | `MftConnectionRules.cls` 277 | :259-261, :1945-1964 |
  | Doc DB applications | `Area/WebApp/DocDbAppSave.cls` 390 (320) | `DocDbAppRules.cls` 358 | :262-264, :1967-1986 |

  `RoutineAppSave` (30 lines) and `RoutineAppRules` already extend Doc DB's.
- **Identical in all three Saves:** `PortClass`, `ProhibitedClass`, `Prohibited`, `Send`, `Body`, `Add` and `Gate`. `Unexpected` differs only by Doc DB's `SaveFields()`.
- **What differs.** Identity is a composite `[Port, BindAddress]` (numeric port), `Name`, or a `Namespace`/`Name` pair. Update args are `CallerFields` or, for Doc DB, the raw body. Rules `Check`/`Taken` take different argument lists. Superserver's update uses `MergeRaw` with a full post-merge `Check` and a `WeakensByEffect` consequence. Each `Answer` body differs.
- **Rules.** `RenderRead`, `Gate`, `Add` and `Text` are identical in all three Rules classes. `RenderViolations` differs only by error class; Doc DB already reads `ERRORCLASS` (:29).
- **The closest existing sibling.** `DocDbAppSave`/`DocDbAppRules` already carry hooks: `NAMESPACED`, `ERRORCLASS`, `SaveFields`, `FormRead` and `IdOf`.
- **Kernel pieces.** `Kernel/Proposal/Operation.cls` provides `HoldTool` (:77) and `Release` (:100). Also used: `ReadBack.ForSave`, `Kernel.Proposal.Prohibited`, `Kernel.Denial.Envelope` and `Screen.Gate`.
- **Seams and test fixtures.**
  - `Test/SuperserverSaveFixture` overrides `PortClass`, `ProhibitedClass` and `Parameter RULES`.
  - `Test/MftSaveFixture` overrides `PortClass` and `ProhibitedClass`.
  - `Test/SuperserverRulesSeam` overrides `ServerConfiguration` and `Windows`.
  - `Test/SaveHoldCoverage` finds the handler by `CompiledMethod.Origin` and needs `.HoldTool(` and `.Release(` in its source.
- **Client forms stay as copies** (Design Notes): `ui/src/app/areas/security/superserver-form.*`, `mft-connection-form.*`, and `ui/src/app/areas/web-applications/docdb-app-form.*`.

## Tasks & Acceptance

**Execution:**

- One implement pass per batch leaves the tree for one commit: `fix(23.8): batch <n> - <area>`.
- Each task names its pinning test. Its `mutation:` line goes under Verification, with the observed run.
- In the same pass, update every test that asserts a shared surface's old shape (Verification › Shared surfaces).
- The lead writes the ledger trailers once the batch's commit is green.

### Batch 1: explorer save and fixture

- [x] **Task 0 (DW-2256), measure on `ocupilot-ci`.**
  - In `USER`, make a probe routine `OcuProbe2021Obj.mac`, compile it, then run `##class(%Routine).Delete("OcuProbe2021Obj.mac", 2)` (vendor doc: delete source, keep OBJ).
  - Check that `ExplorerRoutineSave.AgentProblem("USER", name)` is `""`, and that `AtelierPort.Invoke("Routine", "LIST", …)` answers `available` 0 with `reason` `objectonly`.
  - If not, try one deployed `.obj` export and reload.
  - Record the outcome under Verification. If neither path reaches the mint's read, do the code task below, skip the test, and record "no test can redden: measured unreachable".
- [x] **DW-2256.** `src/OcuPilot/Screen/Tool/ExplorerSaveMint.cls` `Mint` :72: answer `AtelierPort.#REASONNOSOURCE`, as `ExplorerSourceRead.View` does.
  - Pin: `ExplorerSaveFlow.TestAnObjectOnlyRoutineIsRefusedAsKeepingNoSource`. It calls `ExplorerSaveMint.Mint` directly with `Kernel.Scope` set to `USER` and a one-edit argument set. Take the descriptor, endpoint, id parameter and argument name from `ExplorerRoutineSave` as `Screen.Tool.Registry.InvokeTool` passes them. The refusal comes before `##super`, so no conversation or turn key is needed.
  - Assert: an error status, 404, `pFault.code` `PORT.NOTFOUND`, `pFault.reason` equal to `REASONNOSOURCE`, and no proposal row added. The probe routine is removed in teardown with `Delete(name, 0)`.
  - It must be red before the fix.
- [x] **DW-2257.** `ExplorerSaveMint.cls` :88-94: replace the inline measure with `##class(OcuPilot.Screen.Tool.ExplorerSourceRead).Escaped(tNew)`, inside the existing `Try`.
  - Pin: `ExplorerSaveFlow.TestAnEditPastThePortsBoundIsRefused`.
  - Record the mutation red after the fix and green before it.
- [x] **DW-2258.** `src/OcuPilot/Test/ExplorerSaveTurn.cls` :199, :218 and :237 become `Do $$$AssertStatusOK(..RemoveKeyed(), "the probe package is removed")`, as in `ExplorerSourceTurn`.
- [x] **DW-2261.** Move the bound into `src/OcuPilot/Test/ExplorerSourceTestCase.cls`.
  - Add `ClassMethod Limit()`, answering `##class(OcuPilot.Screen.Tool.ExplorerSourceRead).#SOURCEMAXLENGTH`.
  - `ExplorerSource.cls` and `ExplorerSourceEdges.cls` drop `Parameter LIMIT` and call `..Limit()`. Every literal in the two classes that restates the bound derives from it, including the two named in the Code Map (`..Limit() \ 2` and `..Limit() - 1`).
  - Add `ExplorerSource.TestTheReadDescriptionStatesTheBoundItCutsTo`: `CUTTEXT` contains `$FNumber(..Limit(), ",")`.
- [x] **DW-1267.** Rewrite `src/OcuPilot/Test/ProposalFixture.cls` `RemoveSeeded` to match its contract, following `Remove`'s count:
  - Attempt every key, and add each failure into the answer.
  - Forget a key only once its removal succeeded and none of its rows remain.
  - `pRemaining` = surviving proposals plus turns, or -1 when a count cannot be read.
  - Reword the doc to state exactly this.
- [x] **DW-1267.** Create `src/OcuPilot/Test/ProposalFixtureFaultProbe.cls`, which is not a test. It extends `ProposalFixture` and overrides `Update`:
  - For the key armed in `^||OcuPilotProposalFixtureFault("key")`, mode `fail` answers an error for the Proposal delete.
  - Mode `keepturn` answers OK without running the Turn delete.
- [x] **DW-1267.** Create `src/OcuPilot/Test/ProposalFixtureSweep.cls` (unarmed). It seeds through `ProposalFixture.SeedTurn` and `SeedProposal` for the running account, and `OnAfterOneTest` calls the real `RemoveSeeded`. Two tests, each red before the fix:
  - `TestAFailedKeyIsKeptAndTheOthersAreSwept`: two keys, `fail` armed on one of them. Through the probe: an error status, and the other key's rows are gone. Then the real `RemoveSeeded` removes the failed key's rows, with `pRemaining` 0.
  - `TestASurvivingTurnIsCounted`: `keepturn` armed. Through the probe: `pRemaining` = 1.

### Batch 2: scripts, install and container

- [x] **DW-235.** `scripts/ci-throwaway.sh` guard (:109-115):
  - Normalize `TMPDIR` into `SCRATCH_TMPDIR` as `ci-ipm-archive.sh` :108-120 does, and use `"$SCRATCH_TMPDIR"/?*` in the case.
  - Strip trailing slashes from `DIR`, then refuse `*//*`, `*/./*` and `*/.`, with the message under Wording.
  - Refuse when `[ -L "$DIR" ]` or `[ -L "$DIR/data" ]`.
  - In `scripts/ci-ipm-archive.sh`, add the same plain-spelling and symbolic-link refusals.
- [x] **DW-235.** Tests, each through `logs --dir` only and each exiting 0 before the fix:
  - `ui/tools/ci.test.mjs`: add `the scratch-root guard refuses a root reached through TMPDIR=/, a sibling, '//', '/./' or a symbolic link (DW-235)` beside :1945, with the six inputs of the matrix row expecting exit 2. Keep the existing admitted cases.
  - `ui/tools/ipm-archive.test.mjs` :365: add `//` and `/./`.
- [x] **DW-1762.** In the `iris` service the `ci-throwaway.sh` here-doc writes, add `stop_grace_period: 60s` after `restart:`.
  - Pin it in `ci.test.mjs`: the generated compose's `iris` service carries `stop_grace_period: 60s`. Red before.
  - Admitted at the spec gate: also apply it to `docker-compose.yml`. Then add `['stop grace period', 'iris', /stop_grace_period:\s*(\S+)/]` to the key list at :2175, add a `ui/tools/compose.test.mjs` assertion on that line, and name the key in `ci-throwaway.sh`'s header list of keys copied from `docker-compose.yml`.
- [x] **DW-432.** In `docs/DEVELOPMENT.md`, after the paragraph at :467, add the "Armed test classes" paragraph under Wording, naming all 20 variables.
  - Pin, in `ui/tools/ci.test.mjs` beside the arming tests: every variable `declaredArmingRosters(ci-throwaway.sh)` reads is named in `docs/DEVELOPMENT.md`, and every `OCUPILOT_ALLOW_[A-Z_]+` the doc names is one of them. Red before.
- [x] **DW-432.** `ui/tools/ci-runner.mjs` `classifyFailureDetail` :210: when a class-level action names `OCUPILOT_ALLOW_[A-Z_]+`, append the hint under Wording, naming the variable.
  - Pin, in `ci.test.mjs` beside :1102: one class-level failure whose action names `OCUPILOT_ALLOW_PRINCIPALS` gets the hint, and one that names none does not. Red before.
- [x] **DW-216.** Document the constraint where the smoke is offered:
  - `src/OcuPilot/Install/Smoke.cls`: the class header, `Host()` and `Port()` docs get the sentence under Wording.
  - `docs/DEVELOPMENT.md` "The smoke script": add the paragraph under Wording, after the "A run that executed nothing is a failure" paragraph.
  - `README.md` :555-557: append the sentence under For the lead to the smoke bullet (admitted at the spec gate).
  - No test (the entry says why).

- [x] [CI] gates (all three Node bands), run 39738366345: `ui/tools/ipm-archive.test.mjs` :379, the DW-235 trailing-slash legs. On Linux `os.tmpdir()` is `/tmp`, so the test's root is itself under the script's fixed `/tmp/?*` arm, and `${scratch}//` (stripped to `${scratch}`) is admitted. Give the test a root that no fixed arm admits (for example `mkdtemp` under `os.homedir()`), so every leg is refused on every platform and a regressed guard still writes only inside it. Check `ci.test.mjs`'s DW-235 legs for the same assumption.

### Batch 3: client lint

- [x] **DW-1188.** In `ui/tools/client-lint.mjs`, add family 7, `checkTemplateClasses({templates, stylesheets, references})`, after :577. Rule names: `no-unstyled-template-class` and `stale-unstyled-class-hook`.
  - **Used names:** the five class sources in the Code Map. **Styled names:** every `.ocu-x` in a selector of `src/**/*.scss` or a component `styles:`.
  - **The violation.** A used name fails unless it is styled, allow-listed, or carries a declared composed prefix. It is reported at each use site.
  - **`UNSTYLED_CLASS_HOOKS`:** a literal, sorted, exported list in two groups, with a one-line reason per group: the 90 test hooks, and the 4 owed a style (both in Design Notes).
  - **`COMPOSED_CLASS_PREFIXES`:** `ocu-banner-` (`list-page.ts`) and `ocu-reply-heading-` (`core/reply.ts`). Each needs at least one styled `prefix*` selector. A non-literal class binding with an `ocu-` fragment in any other file fails.
  - **Stale entries fail.** An allow-listed name fails when it is styled or unused. A hook-group name also fails when no `browser/` or `*.spec.ts` file references it. The unused and unreferenced checks run only when the root has `src/styles/`, so the CLI scratch trees stay quiet.
  - Ids are never read, because only class contexts are parsed.
  - Collect the files during the existing walk, and judge after the loop. Add family 7 to `RULE_FAMILIES`, and correct the header's family count to seven.
- [x] **DW-1188.** `ui/tools/client-lint.test.mjs`, in the existing style:
  - Fixture tests of each extractor and of each rule, including stale and composed.
  - `id="ocu-x"` produces nothing.
  - `RULE_FAMILIES` includes it.
  - A CLI scratch tree with `class="ocu-not-styled"` exits 1 naming the file.
  - The real-tree clean run stays green.
- [x] **DW-1188.** Remove the 44 dead tokens listed under Design Notes from their templates under `ui/src/app/`. Before removing each, grep `ui/src`, `ui/browser` and `ui/tools` for it: a token with any reader is kept and allow-listed instead. No visual change: none of the 44 is in any selector.

### Batch 4: navigation contract

- [x] **DW-1462.** `src/OcuPilot/Screen/Tool/Navigate.cls`:
  - Split `AcceptsEntityId`'s body into `IdShapeAccepted(pDescriptor)` (`single`, or `composite` of one part). `AcceptsEntityId` = `ParentScope() = ""` and `IdShapeAccepted`.
  - New `AcceptsParentId` = `ParentScope() '= ""` and `IdShapeAccepted(DescriptorForRoute(ParentScope()))`.
  - `InputSchema` gains `parentId` (string, `maxLength` 256). `entityId` and `DESCRIPTION` are reworded (Wording).
  - `Directive` reads `parentId` as it reads `entityId`, and refuses `NAV.ENTITYNOTALLOWED` for an argument the screen does not accept. `RefusalFault` gains an optional `detail.argument` naming it.
  - `Directive` gains a trailing `Output pParentId`.
  - `ResultSchema` gains `parentId`.
  - The class header's composite paragraph covers both arguments.
- [x] **DW-1462.** Thread `parentId` through the dispatcher and the turn:
  - `Kernel/Agent/Dispatch.cls`: `ResolveClientCall` gets a trailing `Output pParentId` from `Directive`. `SettleClient` emits `parentId` when the detail carries it.
  - `Kernel/Agent/Loop.cls`: take `tParentId`. The announce target and `Nav.GuardedRequest` get the route's id, `$Select(tEntityId '= "": tEntityId, 1: tParentId)`. The dropped and settled details carry `parentId` instead of `entityId` when it is set.
  - `Kernel/State/Nav.cls`: doc only. `EntityId` holds the route's id: the selected row's, or the parent's on a parent-scoped screen.
- [x] **DW-1462.** `src/OcuPilot/Api/Error.cls` :1048: `REASONNAVENTITYNOTALLOWED` takes the sentence under Wording.
- [x] **DW-1462.** `src/OcuPilot/Test/ToolNavigate.cls`:
  - Rewrite the sweep (:94-138) to the two-way partition, derived from the declarations. For every built route, `entityId` "1" is accepted exactly when `AcceptsEntityId`'s rule says so, and `parentId` "1" exactly when the parent's id shape says so. Each half has a floor above 0.
  - Rewrite the header's parent-scoped paragraph.
  - `TestTheSchemaAdmitsCriterionAndNothingElse` expects five names.
- [x] **DW-1462.** Create `src/OcuPilot/Test/ToolNavigateParent.cls` (unarmed), with literal pins:
  - `tasks/schedule/details` takes `parentId` and refuses `entityId`, with `detail.argument`.
  - `tasks/schedule` refuses `parentId`.
  - `interoperability/productions/items/jobs` refuses both.
  - `tasks/schedule/history` takes `parentId`.
  - `SettleClient` echoes `parentId`.
  - A turn through `TurnLoopProbe`, in `TurnNavigate`'s pattern, whose scripted call names `parentId` stores the route's id on the Nav row and settles with `parentId`.
- [x] **DW-1462.** `ui/browser/task-resume.browser-spec.mjs:228`: `entityId` becomes `parentId`.

### Batch 5: shared Save

- [x] **DW-2278.** Create `src/OcuPilot/Kernel/Proposal/ScreenSave.cls` [Abstract], lifting `DocDbAppSave`'s generalized shape.
  - **Parameters:** `CREATETOOL`, `UPDATETOOL`, `DESCRIPTORCLASS` and `RULES`.
  - **Template methods:** `HandleCreate`, `HandleUpdate`, `Create`, `Update` and `Answer`. `HandleCreate`/`HandleUpdate` keep `.HoldTool(` and `.Release(` in their own source.
  - **The identical helpers:** `PortClass`, `ProhibitedClass`, `Unexpected`, `Prohibited`, `Send`, `Body`, `Add` and `Gate`.
  - **Hooks:**
    - create and update identity;
    - update arguments (default `CallerFields`);
    - `SaveFields` (default the tool's `SettableFields`);
    - the rules' `Check` and `Taken` adapters;
    - the merge (default `MergeUpdate`, then `Check` on a problem);
    - a consequence (default none);
    - the answer body.
  - **Kept in order (AD-53, AD-55):**
    - gate, then body, then identity, then hold;
    - `Unexpected`, then rules, then the state read (`Taken` or the fresh read);
    - compose or merge, then the prohibited set, then the port write, then `ReadBack.ForSave`, with the hold kept through the answer.
  - It mints no proposal and does not read the read-only or kill-switch state.
  - Every call goes through `..#RULES` and `..PortClass()`.
- [x] **DW-2278.** Create `src/OcuPilot/Kernel/Proposal/ScreenSaveRules.cls` [Abstract]: `RenderRead`, `Gate`, `Text`, `Add`, and `RenderViolations` through `ERRORCLASS`.
- [x] **DW-2278.** `SuperserverSave`, `MftConnectionSave` and `DocDbAppSave` extend `ScreenSave` and keep only their hooks and parameters. Their Rules classes extend `ScreenSaveRules`, and Superserver and MFT gain `ERRORCLASS`. `RoutineAppSave` and `RoutineAppRules` inherit through Doc DB unchanged.
  - Keep every behavior the Write tests pin: Doc DB's 400 on an identity key in an update body, Superserver's numeric port, `MergeRaw` with the post-merge `Check` and the consequence, and Superserver's `Taken` endpoint.
  - The client forms are not touched.

**Acceptance Criteria:**

- **Dispositions.** Given the twelve entries, when the story completes, then each is `resolved-by` 23.8 with its batch commit, except as Design Notes › Dispositions allows. Each carries the verdict under Design Notes, and any evidence correction goes in its note.
- **Red first.** Given each fix above, when its pinning test runs before the fix, then it is red, and after the fix green. Three kinds of fix show the defect another way, each recorded under Verification:
  - **Test-hygiene and refactor fixes (DW-2257, DW-2258).** Under the named mutation the pin is green before the fix, which is the defect, and red after.
  - **No test can fail (DW-216, DW-2278).** DW-216 is documentation, with no instance shape to fail on. DW-2278 preserves behavior: green before and after with equal class totals, plus the base mutations. DW-2256 joins them if Task 0 measures it unreachable.
  - Each entry's note says which applies.
- **Navigation.** Given the registry at head, when `ToolNavigate`'s sweep runs, then every built route accepts `entityId` exactly when it has no parent scope and its id is `single` or a one-part `composite`, and accepts `parentId` exactly when it has a parent scope whose screen's id has that shape. Every other case is refused `NAV.ENTITYNOTALLOWED` before any announcement.
- **Lint wiring.** Given a template class with no style and no allow-list entry, when `npm run build` runs, then its prebuild `client-lint.mjs` exits 1 naming the file and line. Given the tree at the batch-3 commit, it exits 0.
- **Integration (Rule 1).** Given the Kernel `ScreenSave` base, when `SuperserverSave`, `MftConnectionSave`, `DocDbAppSave` and `RoutineAppSave` serve their routes over HTTP, then each Save answers exactly as before. Observed by their `*Write` classes over HTTP, with `SaveHoldCoverage` green.
- **Batches.** Given the five batches, when each lands, then it is its own commit with CI green on its own head.

### Review Findings

Code review, batch 1 (2026-10-22; full-opus; four layers): 24 rows, 7 entries (1 medium, 6 low), all patched; 9 rejected.

- [x] [Review][Patch] (medium) DW-2256's pin reached the mint through a guard-lifting test subclass, a hand-copied `Mint` call and the vendor's `EnsJob.mac`: not self-contained, and no product path shown [`src/OcuPilot/Test/ExplorerSaveFlow.cls`] -- a `USER` routine compiled and stripped of its `^rMAC` source reads `200 0 objectonly` and reaches the mint through the real `ExplorerRoutineSave.View`. Both DW-2256 tests call `View`, and the object-only one makes and removes its routine. `ExplorerRoutineSaveUnguarded` is deleted. This supersedes Design Notes › "DW-2256, the pin".
- [x] [Review][Patch] (low) `ExplorerSaveFlow`'s header and the two tests' docs over-claimed the object-only case and misnamed its environment [`ExplorerSaveFlow.cls`] -- rewritten with the patch above.
- [x] [Review][Patch] (low) The bound-figure pin was a substring check, so "160,000" passed for 60,000 [`ExplorerSource.cls` `TestTheReadDescriptionStatesTheBoundItCutsTo`] -- it now matches the whole figure.
- [x] [Review][Patch] (low) `TestAFailedKeyIsKeptAndTheOthersAreSwept` derived its expected count from the rows it read back [`ProposalFixtureSweep.cls`] -- it asserts `1 0` and 1.
- [x] [Review][Patch] (low) The same test repeated `SeedPair` inline [`ProposalFixtureSweep.cls`] -- it calls `SeedPair`.
- [x] [Review][Patch] (low) `TestAnUnreadableCountIsAnErrorAndKeepsTheKey` was wholly covered by the pair test's `unreadable` legs [`ProposalFixtureSweep.cls`] -- removed; its mutation reddens the pair test.
- [x] [Review][Patch] (low) `ProposalCountForTurn`/`TurnCountForTurn` copied `ProposalCount`/`TurnCount`, and the stated reason did not hold, since a private counter changes no caller [`ProposalFixture.cls`] -- all four go through `CountRows`.

Rejected:

- The sweep's pre-clean ignores its count: low -- it needs a delete that succeeds while a row of the same key survives, under one predicate.
- The turn delete's status is unpinned: low -- a failed turn delete leaves a turn, which every caller's remaining-count assertion reports.
- The surrogate test's `..Limit() - 1` holds only for an even bound under 70,001: low -- the task prescribes the form, and a bound change fails it loudly.
- Verification's run numbers span two instance lifetimes: a spec edit outside the mutation lines.
- Auto Run Result's "12 changed classes": a spec edit.
- "No proposal is added" cannot fail: low -- the task asks for it, and the reason assertions are the pins.
- The real count helpers' -1 branch never runs: low -- it needs a delete that succeeds and a count on the same table that fails.
- A read-only probe ran on `ocupilot` during implement: process, already in the cycle log.
- QA's tests are outside the batch commit: the lead's post-smoke commit and its CI carry them.

Code review, batch 2 (2026-10-22; full-opus; four layers): 23 rows, 5 entries (1 medium, 4 low), all patched; 14 rejected.

- [x] [Review][Patch] (medium) The `ci-ipm-archive.sh` DW-235 test spelled every `--dir` under the host's `/tmp`, so a regressed guard would stage into `/tmp/x` or `/tmp/module` (`mkdir` is not stubbed) and its outcome depended on what the host holds there [`ui/tools/ipm-archive.test.mjs`] -- every leg is now under a root the test makes and passes as `TMPDIR`; the whole-guard revert is red and leaves the host's `/tmp` unchanged.
- [x] [Review][Patch] (low) The admitted `/tmp` leg of the `ci-throwaway.sh` DW-235 test named a path it did not make, so the admitted half was unpinned there [`ui/tools/ci.test.mjs`] -- it is a real directory made under `/tmp` and removed; a link test refusing it reddens it.
- [x] [Review][Patch] (low) A class armed by two variables got "it names A, B, an arming variable", untested [`ui/tools/ci-runner.mjs`] -- two or more read "A and B, arming variables"; the one-variable text is unchanged. A two-variable leg pins it.
- [x] [Review][Patch] (low) The link refusals' comments claimed a removal `rm` does not make: a link at `$DIR/data`, or at `--dir` in `ci-ipm-archive.sh` once its slashes are off, is unlinked, not followed [`scripts/ci-throwaway.sh`, `scripts/ci-ipm-archive.sh`] -- the comments say what each link would do.
- [x] [Review][Patch] (low) The hand-written throwaway compose in `docs/DEVELOPMENT.md` lacked the `stop_grace_period` the paragraph below it says to copy [`docs/DEVELOPMENT.md`] -- added.

Rejected:

- "Only `scripts/ci-throwaway.sh` sets them" is false because two browser specs `docker exec -e` the variable: false -- that arms one seeding session of the spec's own on the throwaway; a class the runner runs takes the container's environment, which only that script's compose file arms.
- `scripts/smoke.sh`'s usage omits the own-web-server constraint: low -- the task names the three sites (`Smoke.cls`, `DEVELOPMENT.md`, `README.md`).
- The README sentence lacks the "only" the other two carry: low -- ruled text (U-6); it errs toward a failure that does not happen, and the precise form is in `DEVELOPMENT.md` and `Smoke.cls`.
- The `Smoke.cls` paragraph appears three times: low -- the task places it in the header, `Host()` and `Port()`.
- A `TMPDIR` as shallow as `/Users` admits a home directory: low -- the caller names that root scratch; nothing in the tooling sets it.
- A link in an ancestor of `--dir` is admitted: low -- Design Notes leaves it (filing candidate 4).
- `down` refuses when `$DIR/data` is a link, leaving the container up: false -- a loud refusal of a hand-planted link, naming its path, is the designed outcome.
- An arming refusal at method level gets no hint: low -- the matrix row is class-level, and the runner already prints that method's raised text, which names the variable and the script.
- The "Armed test classes" bold lead departs from the ruled lead, and the ruled hint cites a label the ruled paragraph lacks: low -- kept. The Task and the Wording both call the paragraph "Armed test classes"; with the ruled lead verbatim the ruled hint cites nothing in the document. Every other word is as ruled.
- The link line names `$LINK`, not `$DIR`: low -- for `--dir` it is `$DIR`; for the data link the ruled `$DIR` would name the wrong path (Decided in-stage).
- `docker-compose.yml` carries a comment beside the admitted key: low -- it gives the key's measured reason, in the comment-per-key form the file already uses.
- A failing `OnAfterAllTests` would overwrite the class record and drop the hint: maybe-false -- needs an armed class whose teardown fails unarmed; the line would still say failure.
- "Red by design on `ocupilot`" contradicts AD-17: false -- AD-17 governs what a product start compiles, and the sentence says what such a class does when run there.

Code review, batch 2 CI rework 1 (2026-10-22; full-opus; four layers; `e2459b1e..c323b4c0`): 14 rows, 3 entries (3 low), all patched; 7 rejected. The `[CI]` item holds: with dash as `sh` and `TMPDIR=/tmp`, as on Ubuntu, `ipm-archive.test.mjs` passes 33 of 33. The root under `$HOME` is refused on every platform. The whole-guard revert is red, stages only inside the root, and the `finally` removes it, leaving `$HOME` and `/tmp` unchanged.

- [x] [Review][Patch] (low) The `ci.test.mjs` reason said its link legs take their root from the `TMPDIR` the script reads, but with `TMPDIR` unset (Linux CI) the `/tmp/?*` arm admits them [this spec, Triage Log and Auto Run Result] -- replaced at both sites.
- [x] [Review][Patch] (low) The test's mutation comment said every leg goes through under the whole-guard revert, but the scratch-root case still refuses `${scratch}/` [`ui/tools/ipm-archive.test.mjs`] -- the comment now names that leg.
- [x] [Review][Patch] (low) The whole-guard-revert `mutation:` line cited the `/tmp` listing for a root that now sits under `$HOME` [this spec, Verification] -- re-run on the moved root under both environments and rewritten.

Rejected:

- Triage row 5 is filed `[false]`, and its "only platform difference" is not labeled an inference: low -- this is a closed pass's record, and this review's dash run is the Linux evidence.
- Row 7 is counted twice, the Auto Run Result's mutation and file lists are incomplete, and text repeats in an `oversized` spec: low -- bookkeeping in a closed pass's record.
- An unwritable `$HOME` fails the test for an unrelated reason: low -- it fails loudly, and every runner here has a writable `$HOME` outside `/tmp`.
- `os.homedir()` could be empty or relative: low -- theoretical, since it returns an absolute path.
- A killed run leaves `~/ocupilot-ipm-dw235-*` behind: low -- this happens only on an external kill, and a sweep at the start of the run would delete a concurrent slot run's live root.
- The `[CI]` box and `done` were set before CI ran on `5db54c67`: false -- the lead's CI gate reads that run.

Code review, batch 3 (2026-10-22; full-opus; four layers): 35 rows, 7 entries (1 medium, 6 low), all patched; 13 rejected.

- [x] [Review][Patch] (medium) A literal name under a declared prefix passed unstyled in any file, so a new or mistyped `ocu-banner-*` in any of the 75 files using one would install unstyled [`ui/tools/client-lint.mjs` `checkTemplateClasses`] -- the exemption holds only in the prefix's own file, as the run-time prefix and the `[class]` binding already did. The literal-name test gains an other-file leg. Every literal `ocu-banner-*` in the tree is styled.
- [x] [Review][Patch] (low) `ocu-log-cell-pid` had a reader the whole-token search could not see: `secondary-logs.browser-spec.mjs` builds `.ocu-log-cell-${name}` and called `cell('pid')`, a value no assertion read [`ui/browser/secondary-logs.browser-spec.mjs`] -- the unread `pid` field is removed and the class stays removed. A search of every removed name's stems for a built selector found no other class reader.
- [x] [Review][Patch] (low) A prefix built only by a template interpolation (`class="ocu-x-{{ n }}"`) could never pass: the use check accepts it, the builder check read only `${` and `' +` [`client-lint.mjs`] -- `{{` counts as a builder; the composed-prefix test gains the leg.
- [x] [Review][Patch] (low) Nothing pinned that a `*.spec.ts` or `src/app/testing/` file's `styles:` styles nothing that ships [`client-lint.test.mjs`] -- the collection test gains a second tree.
- [x] [Review][Patch] (low) Nothing pinned that a name owed a style is stale once styled [`client-lint.test.mjs`] -- the styled-stale test gains an owed leg.
- [x] [Review][Patch] (low) The family's scope comment named four class forms it does not read and left out the rest [`client-lint.mjs`] -- it names each.
- [x] [Review][Patch] (low) A `mutation:` line said the whole-tree CLI test reddens when a hook leaves group A; it takes the first hook name, so only the two real-tree tests do [this spec, Verification] -- corrected.

Rejected:

- `class="{{ c }}"`, `class="ocu-a {{ c }}"`, `[class]="'ocu-a ' + c"`, a host `'[class]'` key, `@HostBinding`, `[attr.class]`, `[className]` and `panelClass` go unread: low -- none is in the tree, reading them takes expression parsing, and the scope comment names each.
- `[class]="expr"` with no `ocu-` fragment fails: low -- it fails closed on names the scan cannot see; none outside a declaring file, and Epic 20 has no client change beyond feature.
- A TypeScript comment holding `template:` or a builder is read as code: low -- `templateRegions` is family 2's shared reader; none in the tree.
- A quoted `template:`, `styles:` through a constant, SCSS `&-` nesting, `#{}` selectors and `.css` files are not read: low -- none in the tree, styles are SCSS (spine, Client asset homes), and each fails loudly.
- `blankComments` reads `/*` or ` //` inside a string as a comment: low -- family 1's shared helper; no such string in a styles, host or constant region.
- A prefix's style check is met by any styled name under it: low -- the Task's words.
- Readers are `ui/browser` and `*.spec.ts` only; shipped code, a testing harness and a selector built from a template literal do not count: low -- the Task names the readers, and a miss fails loudly.
- A builder through `.concat` or `.join`: low -- not a form the tree uses.
- The whole-tree gate is a `src/styles/` path: low -- the Task states it.
- A `[class]` object binding comparing an `ocu-` id: low -- none in the tree; it fails loudly.
- `ocu-oauth-client-metadata`'s id is on the inner table, and its twin `ocu-oauth-server-metadata` was removed: low -- the recorded in-stage decision and its `reopen_if`; the class is harmless.
- Auto Run Result's "24 new tests" (22): a spec edit.
- QA's tests are uncommitted: false -- the lead's commit carries them.

Code review, batch 4 (2026-10-22; full-opus; four layers): 25 rows, 7 entries (1 medium, 6 low): 5 patched, 1 decision-pending (DW-2497), 1 wontfix-accepted (DW-2498); 11 rejected. The six points hold: every refusal precedes the announce step and the Nav row and names `detail.argument`, with no new code; the seven two-part-parent screens are genuine (`settings`, `document` and `test` were refused an `entityId` at `5efc7e29` already, so only the four tabs change); nothing under `Kernel/State/` names `OcuPilot.Screen` and `Nav.cls` changes a doc comment only; the ruled texts match byte for byte; the client builds the URL from the route id unchanged.

- [x] [Review][Patch] (medium) `ToolNavigateParent` copied `TurnNavigate`'s turn harness instead of extending the shared `TurnToolsCase`, so each turn left its agent-ledger rows, and its header said it removed everything it wrote [`src/OcuPilot/Test/ToolNavigateParent.cls`] -- it extends `TurnToolsCase` (teardown removes each turn's ledger rows and asserts none survives), keeping only `Begin`/`RunBegun` for the settle job's start. `TurnNavigate`, unchanged here, does the same: occurrence on DW-2403.
- [x] [Review][Patch] (low) `Loop` chose the route id preferring `entityId` and its key preferring `parentId` [`src/OcuPilot/Kernel/Agent/Loop.cls`] -- one condition sets both.
- [x] [Review][Patch] (low) The `Navigate` class header and `Loop`'s settle comment still described the id as a selected row [`Navigate.cls`, `Loop.cls`] -- reworded.
- [x] [Review][Patch] (low) `AcceptsParentId`'s doc said an unbuilt parent is refused; `DescriptorForRoute` answers any descriptor [`Navigate.cls`] -- "no descriptor declares".
- [x] [Review][Patch] (low) The sweep skipped Home, so the Navigation AC's "every built route" was unpinned there and Verification counted 160 own-row screens for 161 [`src/OcuPilot/Test/ToolNavigate.cls`, Verification] -- the skip is gone (62 own-row refusals) and the count is corrected.
- [x] [Review][Decision] (low) The ruled `entityId` text says "send parentId there", which the seven two-part-parent screens refuse too -- DW-2497, the owner's (U-7).
- [x] [Review][Defer] (low) `Prompt.BUILTIN` calls `screen_context.entity` the selected row, the parent's id on a parent-scoped screen -- DW-2498, `wontfix-accepted`: a new model-read text.

Rejected:

- `AcceptsParentId` admits a parent-scoped screen whose own id is `none`: low -- none of the 48 is built, and the guard would change the AC's stated rule.
- A refusal with no `detail`, or a roster route with no descriptor, raises in `ToolNavigate`, `ToolNavigateParent` and `ToolNavigateContract` (5 rows): false -- the method errors, which `%UnitTest` records as its failure (run 16 shows it).
- Two `ToolNavigateParent` pins repeat `ToolNavigateContract`'s rosters, which call `ToolNavigateParent.Ask`: low -- the Task prescribes those literal pins; class-method helpers across test classes are the existing idiom.
- `Registry.CitationSource` checks the parent scope beside `AcceptsEntityId`: false -- its answer is unchanged and both conditions in its doc stay true.
- Verification's commands and Auto Run Result omit `ToolNavigateContract`: a spec edit; QA's line records the class and CI runs every class.
- DW-1462 is still `routed`: false -- the lead writes the trailer once the commit is green.
- The "parentId on a screen with no parent" matrix row is not marked CHANGED (`TOOL.ARGUMENTS` before): a spec edit; the code matches the row's Expected column.

Code review, batch 5 (2026-10-22; full-opus; four layers): 35 rows, 16 entries (2 medium, 14 low): 15 patched, 1 escalated (DW-2499); 11 rejected. The five points hold: every create and update answers as at `60bceb23` (head's `*Write` legs, the review legs included, pass against `60bceb23`'s three Saves and Rules); the order is AD-53/AD-55's, AD-10's set after the state read and before the write, the hold released on every exit; no proposal, read-only or kill-switch read; each extra hook carries a per-Save difference and only `Router` and the fixtures call `Create` and `Update`; `Api.Response` breaks no AD Rule or checker rule; only `ScreenSaveOrder` is a test class.

- [x] [Review][Patch] (medium) `MftConnectionSave` and `SuperserverSave` repeated `RulesTaken` and `RulesCheck`'s edit branch, and the base defaults answered no violations and not taken against their own docs [`ScreenSave.cls`, the three Saves] -- the defaults call the rules' `Check` with the identity's first part and `Taken` with the id; MFT drops both overrides, Superserver's `RulesCheck` is one line, and Doc DB's `TakenField`, the default's value, is gone.
- [x] [Review][Patch] (low) Six doc comments named a code `PORT.FIELDSHAPE` that does not exist [`ScreenSave.cls`, the three Saves, `MftConnectionWrite.cls`, `DocDbAppWrite.cls`] -- `PORT.FIELD.SHAPE`.
- [x] [Review][Patch] (low) `CreateIdentity`'s contract promised a shape violation for any mistyped identifying member, but Superserver reads a port of another type as no port, as at `60bceb23` [`ScreenSave.cls`, `SuperserverSave.cls`] -- the contract says a type the Save refuses; Superserver's doc says how it reads the port.
- [x] [Review][Patch] (low) `ScreenSave`'s header said every edit judges what it would send and left out the unexpected keys [`ScreenSave.cls`] -- it states the code's order.
- [x] [Review][Patch] (low) An exception after the hold, the exit `SaveHoldCoverage`'s scan and run 845 cannot see, was untested [`ScreenSaveOrder.cls`, `ScreenSaveOrderFixture.cls`] -- `TestAnExceptionAfterTheHoldIsAnswered500AndReleasesIt`.
- [x] [Review][Patch] (low) The superserver's rules over the merged payload before AD-10's set were unpinned: no body both breaks a rule and is prohibited [`ScreenSaveOrder.cls`, fixture] -- `TestTheMergedPayloadIsJudgedBeforeTheProhibitedSet`, through a fixture switch on `CheckMerged`.
- [x] [Review][Patch] (low) The template test checked four methods' origin [`ScreenSaveOrder.cls`] -- fourteen.
- [x] [Review][Patch] (low) Nothing pinned that a create tool declares its update tool's port, the one the base writes a create through (AD-52) [`ScreenSaveOrder.cls`] -- the template test asserts it for the four.
- [x] [Review][Patch] (low) The failed-write test's "nothing stored" read the create's target on the edit leg and could fail under no change to `ScreenSave` [`ScreenSaveOrder.cls`] -- removed.
- [x] [Review][Patch] (low) No test asserted Superserver's 422 envelope code [`SuperserverWrite.cls`] -- the rules loop asserts `SUPERSERVER.VALIDATION`, as MFT's and Doc DB's do.
- [x] [Review][Patch] (low) `ScreenSaveTrace` named a class `ScreenSaveBranches` that does not exist [`ScreenSaveTrace.cls`] -- removed.
- [x] [Review][Patch] (low) `ClearSteps`' doc left out the question it clears [`ScreenSaveTrace.cls`] -- added.
- [x] [Review][Patch] (low) The fixture's docs named `Name` `shape-probe` as the trigger [`ScreenSaveOrderFixture.cls`] -- `SHAPEID` is the id it gives a shape violation.
- [x] [Review][Patch] (low) `ScreenSaveRules.Gate`'s mutation was never observed [Verification] -- run and recorded.
- [x] [Review][Patch] (low) The equal-behavior evidence predated the review legs [Verification] -- run against `60bceb23` and recorded.
- [x] [Review][Defer] (medium) The Area screen-editor Rules classes, these three among them, repeat `Problem`'s violation sentence (29 files), `Taken`'s probe (12) and `HandleForm`'s read (30) -- DW-2499, escalated: lifting three of thirty moves the copy, it does not end it.

Rejected:

- A fixed list of four Saves rather than a derived one: low -- a new adopter's handlers are reached through its route by `SaveHoldCoverage`, and a derived set must exclude the seam fixtures.
- Triage rows 568, 571 and 578 read as live: QA's pins close them (runs 834, 844); a closed pass's record.
- Auto Run Result's "four legs" (five) and its signature line: a closed pass's record. `Create` takes `(pId, pParts, pArgs, ...)` and `Update` `(pId, pArgs, ...)`, unchanged for Superserver and MFT.
- The triage log's "every 422 the `*Write` classes assert" (`SUPERSERVER.VALIDATION` was asserted nowhere; now it is) and its "unpinned" routine application `namespace` (`RoutineAppWrite:106` asserts it on the create): spec edits.
- `RoutineAppRules` names `DocDbAppRules.RenderRead`: false -- `DocDbAppRules` answers it by inheritance, and `##super` resolves through it.
- A Superserver or MFT edit naming an identity member drops it silently: by design -- `CallerFields` stripped it at `60bceb23`, the I/O row keeps the answer, and runs 111 and 112 pin it.
- `ScreenSave` and `ScreenSaveRules` repeat `Add`, the gate's screen half and the error answer: low -- `Add` is one private line in each, both gates delegate to `Screen.Gate` and `Denial`, and the Save's error answer must not take `RenderRead`'s 404 branch.
- `MftConnectionSave.CreateIdentity` does not use Doc DB's loop: low -- the three identities differ (a numeric port, the namespace's place and `IdOf`), so a shared loop serves one Save.
- Design Notes' precedent "Kernel already names `Api.Turn`, `Api.Router` and `Api.ScreenAction`": those are doc comments; Kernel code names only the error vocabulary, so `ScreenSave` is the first Kernel code to name a non-error Api class, as the For-the-lead Rule 20 line says. No AD Rule or checker rule forbids it. A spec edit.
- `.github/workflows/ci.yml` changed in `3ac899f1`: out of scope, ruled by the orchestrator.

## Spec Change Log

## Review Triage Log

### 2026-10-21 -- Review pass (batch 1)

- verdicts: 10 findings -- high 0, medium 4, low 6, false 0, maybe-false 0
- findings:
  - `[medium]` `[patch]` DW-2256 changed with no pin, and Task 0's "unreachable" missed a path -- `Mint` takes its tool class as an argument, so a test subclass lifting `AgentProblem` reaches the read over `EnsJob.mac` (`200 0 objectonly`). Patched: `ExplorerRoutineSaveUnguarded` and `ExplorerSaveFlow.TestAnObjectOnlyRoutineIsRefusedAsKeepingNoSource`, red under the old reason (run 38), green with the fix (runs 39, 45).
  - `[medium]` `[patch]` `RemoveSeeded`'s unreadable-count branch (-1, error status, key kept) has no test -- the probe had no mode that unsets a count. Patched: probe mode `unreadable` and `TestAnUnreadableCountIsAnErrorAndKeepsTheKey`, red without the branch (run 41), green with it (run 44).
  - `[low]` `[patch]` `TestTheReadDescriptionStatesTheBoundItCutsTo` pins the `CUTTEXT` parameter only, while `ResultSchema`'s `text` description restates the same bound as its own literal -- the five tool descriptions concatenate `CUTTEXT` at compile time, so only the schema literal can drift. Patched: the test also asserts the schema's description, red when it states another figure (run 42). The "65,536" substring looseness is rejected: it needs a bound of exactly 65,536.
  - `[low]` `[patch]` `ProposalFixtureSweep` counts every key in the process-private global, so a key an earlier test left behind inflates `tRemaining` by run order -- the new `RemoveSeeded` keeps a key whose delete fails. Patched: `OnBeforeOneTest` sweeps first and returns its status.
  - `[medium]` `[patch]` Intent audit: for DW-2256's literal input the port, not the mint, supplies the reason, so the changed branch is not what the matrix row's shape reaches; same root cause as the first row -- the new pin reaches the branch. The mint's header clause also over-claimed ("a document the instance keeps no source for"): reworded to the port's unavailable answer, which is what the branch tests.
  - `[low]` `[reject]` Intent audit: DW-2257's pin sits on `Escaped` and is green before the fix -- the spec's Red-first criterion names this shape for DW-2257 and DW-2258 ("green before the fix, which is the defect, and red after"), so the fix would edit the spec.
  - `[low]` `[reject]` Intent audit: DW-2258's red moves from the class hook to the method, and the two early-`Quit` sites are error paths a green run does not take -- spec-bound in the same way, and the third site is the one every run takes.
  - `[low]` `[patch]` Intent audit: DW-2261 leaves other restatements of the bound -- fixed through the schema row above. The doc-comment figures are prose; the sizing literals (2000 rows, 2003 lines, 35,000 pairs) do not restate the bound and the 600000 mutation already covers them.
  - `[medium]` `[patch]` Intent audit: DW-1267's unreadable-count branch is untested -- same root cause as the second row. The claim that a kept failed key harms `InteropEditorProbe` is false: `ForgetLedger` deletes ledger rows per key and a retained key is deleted again harmlessly.
  - `[low]` `[reject]` Intent audit: the new `ProposalCountForTurn`/`TurnCountForTurn` copy `Remove`'s count pair -- they filter by one turn key where the pair filters by user-name prefix, and 242 files call the pair, so a parameterized helper would touch all of them for no behavior gain. The reason is in Design Notes.

### 2026-10-22 -- Review pass (batch 2)

- verdicts: 14 findings -- high 0, medium 0, low 9, false 5, maybe-false 0
- findings:
  - `[low]` `[patch]` The absolute-`TMPDIR` clause of the scratch-root guard has no test -- relaxed to non-empty, the suite stayed green. Patched: a relative `TMPDIR` leg in the DW-235 test, red under that mutation.
  - `[low]` `[patch]` The recorded no-strip mutation for `ci-ipm-archive.sh` did not reproduce, and the strip itself was unpinned in both scripts: every refused input is refused without it, but a link spelled `link/` slips past `[ -L ]`. Patched: a trailing-slash link leg in both tests, red without the strip; the mutation line is corrected.
  - `[low]` `[patch]` The admitted `/tmp/ocupilot-ci` legs read a compose file the host may hold. Patched: a name made for the run.
  - `[low]` `[reject]` Intent audit: a link in an ancestor of `--dir` is admitted -- Design Notes decides this and files it as a candidate; the fix edits the spec.
  - `[low]` `[reject]` Intent audit: DW-1762's pins read compose text and nothing observes a stop -- the restart measurement is the lead's, as Design Notes assigns it.
  - `[low]` `[reject]` Intent audit: the owner-managed slot compose files outside the repository carry no `stop_grace_period` -- they are the owner's; the change reaches the shipped and throwaway files.
  - `[false]` `[reject]` Intent audit: the compose comment's baseline differs from the spec's measurement -- the comment states the Docker Desktop log's 3 s after signal 15, which is the Code Map's measurement.
  - `[low]` `[reject]` Intent audit: the hint reaches the runner and not the MCP test path -- the matrix row names the runner; a class's own error text already names the variable on the MCP path.
  - `[low]` `[reject]` Intent audit: the hint does not use the word "armed" -- the wording is admitted as written.
  - `[false]` `[reject]` Intent audit: the doc pin does not check the paragraph's claim about the `# classes:` comments -- the arming tests already hold each list equal to the classes that read the variable.
  - `[low]` `[reject]` Intent audit: the DW-216 sentence omits `Port()`'s fallback to `DEFAULTPORT` -- the sentence is admitted as written, and `Port()`'s first paragraph states the fallback.
  - `[false]` `[reject]` Intent audit: "fails every HTTP check" is not shown by a run -- it follows from the checks all going to `localhost` over HTTP; no external web server exists here to run one, as Dispositions says.
  - `[false]` `[reject]` Intent audit: the diff carries no compile result for `Smoke.cls` -- the doc-only class loads with 0 errors and `OcuPilot.Test.Smoke` passes 43 of 43 on `ocupilot-ci`.
  - `[false]` `[reject]` Intent audit: the spec-gate rulings are not in the diff -- they are in Design Notes, outside this batch's diff.

### 2026-10-22 -- Review pass (batch 2, CI rework 1)

- verdicts: 7 findings -- high 0, medium 0, low 6, false 1, maybe-false 0
- findings:
  - `[low]` `[reject]` Verification gap, other: the test needs a writable `$HOME` outside `/tmp` -- the placement assertion fails loudly rather than skipping, the gates job has `HOME=/home/runner`, and a fallback root adds a branch for an environment nobody runs.
  - `[low]` `[reject]` Verification gap, other: the placement assertion hand-copies the script's two fixed arms -- a new arm that covered `$HOME` would also need this regex changed; the test's own comment names the arms, and no such arm is planned.
  - `[low]` `[reject]` Verification gap, other: `## Auto Run Result` carries the earlier pass's figures -- this pass's block is appended at finalize, below.
  - `[low]` `[reject]` Intent audit: the `ci.test.mjs` DW-235 check has no recorded outcome -- recorded in this pass's Auto Run Result: its refusal legs use literal `/nonexistent-*` and `/tmp//` spellings, and its link legs only need admitting, which the `$TMPDIR` arm does where `TMPDIR` is set and the `/tmp/?*` arm where it is not.
  - `[false]` `[reject]` Intent audit: nothing in the diff runs on Linux -- the only platform difference for this test is where `os.tmpdir()` points, and `TMPDIR=/tmp` reproduces it (red before, green after); CI on the new head is the lead's gate.
  - `[low]` `[reject]` Intent audit: the test writes into the real home directory -- a `finally` removes the root; a stray directory remains only if the process is killed mid-test.
  - `[low]` `[reject]` Intent audit: the test depends on `homedir()` -- the same finding as the first row.

### 2026-10-22 -- Review pass (batch 3)

- verdicts: 18 findings -- high 0, medium 0, low 16, false 2, maybe-false 0
- findings:
  - `[low]` `[reject]` Verification gap: the reader check counts an id, a comment or a string as a read, so `ocu-command-box-list` and `ocu-oauth-client-metadata` have no class reader -- the Task says a hook fails when no `browser/` or `*.spec.ts` file "references" it and Design Notes classes both as referenced; reading class contexts out of about 260 spec files is a new extractor with its own misses, and the kept side is the no-visual-change side.
  - `[low]` `[patch]` Verification gap: a template-relative line number would ship, since every fixture starts its template on line 1 -- patched: a fixture with the template on line 4; `lineOf` read from the template is red.
  - `[low]` `[patch]` Verification gap: a `[class]` binding is pinned as covered by a prefix only in its own file, in one direction -- patched: a binding in another file than the declared one is reported; "any prefix declared" is red.
  - `[low]` `[patch]` Verification gap: the literal-name exemption under a declared prefix has no pin -- patched: an unstyled literal under a prefix passes and another unstyled name does not; deleting the clause is red.
  - `[low]` `[patch]` Verification gap: extractor branches with no fixture (single-quoted `class` and `[class]`, a quoted host key, quote skipping in the bracket scan, the `testing/` exclusion) -- patched: one fixture reddened by each of four branch mutations; the `testing/` exclusion is left unpinned, since no template under it carries an unstyled `ocu-` class and no user reaches it.
  - `[low]` `[patch]` Verification gap, other: the whole-tree CLI test hard-codes `ocu-copy-status` -- patched: it takes the first group-A name from `UNSTYLED_CLASS_HOOKS`.
  - `[low]` `[patch]` Verification gap, other: the removal of the 44 tokens has no `mutation:` line -- patched: re-adding `ocu-auditing-page` is red in the CLI and in both real-tree tests; the line is under Verification.
  - `[low]` `[patch]` Verification gap, other: the Verification sentence said "a prefix honored in any file" reddens a test, true only for the built-name variant -- replaced at the sentence, and the missing mutations are listed.
  - `[low]` `[patch]` Verification gap, other: the scope of family 7 is not written down (`className =`, `classList`, `[ngClass]` and `elementNode` lists are not read) -- patched: one sentence in the family's header comment.
  - `[low]` `[patch]` Intent audit: class names set by code (`core/reply.ts` `elementNode` lists, `copy-control.ts` `className`) are outside the family -- same root cause as the row above; the Task names five class sources.
  - `[low]` `[reject]` Intent audit: the `ocu-reply-heading-` prefix is checked by a pattern over `reply.ts`, not by the extractor -- the Task declares the prefix and its file, and `reply.ts` builds the name in code the five sources do not include.
  - `[low]` `[reject]` Intent audit: "styled" is name presence, with no view-encapsulation scope, and `&-suffix` nesting is not resolved -- the Task says "every `.ocu-x` in a selector"; the tree has no `&-` selector, and the miss is a false report, never a hidden defect.
  - `[low]` `[reject]` Intent audit: a comment satisfies the reader check -- same root cause as the first row.
  - `[low]` `[reject]` Intent audit: stale and prefix findings are reported at `tools/client-lint.mjs:1` -- the matrix row is about an unstyled use, which carries its own line; the entry's name is in the message and greps to its line.
  - `[low]` `[reject]` Intent audit: the whole-tree gate is "a `src/styles/` path is present" -- the Task states that gate, so the CLI scratch trees stay quiet.
  - `[false]` `[reject]` Intent audit: the diff has five failure conditions where the matrix row has one -- the Task lists each; no bad outcome is described.
  - `[low]` `[reject]` Intent audit: the 49 template edits have no rendering test -- the Task prescribes the grep proof; the component suite (3338) and the reviewers' own searches show no reader, and no selector can reach the 44.
  - `[false]` `[reject]` Intent audit: the removal and the group of four live in the tasks and Design Notes, not the intent contract -- a description of where the text is, with no bad outcome.

### 2026-10-22 -- Review pass (batch 4)

- verdicts: 14 findings -- high 0, medium 1, low 13, false 0, maybe-false 0
- findings:
  - `[medium]` `[patch]` Verification gap: the announce step's text at append time is unpinned for a `parentId` call -- the settle rewrites it, so the post-turn read cannot tell. Patched: `TestTheAnnouncementCarriesTheParentIdWhileTheBrowserWaits` stops the turn during the wait and reads the append; red under the `tEntityId` append (run 45).
  - `[low]` `[patch]` Verification gap: the dropped (step-cap) detail has no test for a `parentId` call (the intent audit's untested dropped branch is the same root cause) -- patched: `TestADroppedAnnouncementNamesTheParentInTheLapse`, red under the `entityId` key (run 46). Rare: a turn at its step cap.
  - `[low]` `[patch]` Verification gap: `AcceptsParentId`'s no-parent leg, `ResultSchema`'s `parentId` and the `maxLength` had no recorded mutation, and 256 was asserted only as above 0 -- patched: the three mutations run and recorded (runs 40-44), and the bound asserted as 256.
  - `[low]` `[patch]` Verification gap, other: `Error.NAVENTITYNOTALLOWED`'s doc comment still described only `entityId` against a none or composite id -- reworded at the origin.
  - `[low]` `[patch]` Verification gap, other: `ToolNavigateParent`'s header said it writes only its own turn, but it also makes and removes a probe agent definition -- reworded.
  - `[low]` `[reject]` Intent audit: the browser spec and the turn tests exercise one route (`tasks/schedule/details`), the other seven newly openable screens only through `Directive`, and the sweep's floor is above 0 rather than a count -- the spec derives the partition from the declarations with a floor above 0, and every route shares the one dispatch path.
  - `[low]` `[reject]` Intent audit: the stored row, the announce text and the client's `entityId` keep one name for a parent's id -- Design Notes decides this (no stored change, AD-9).
  - `[low]` `[reject]` Intent audit: the advertised contract is class-level, and the model learns the per-route answer from `detail.argument` -- the texts are the owner's ruling (U-7); a per-route list would be a new model-read string.
  - `[low]` `[reject]` Intent audit: the reason sentence is generic and serves both refusals -- ruled text (U-7).
  - `[low]` `[reject]` Intent audit: the reason sentence changed though the matrix is silent -- ruled text (U-7), and the spec-gate ruling lists it.
  - `[low]` `[reject]` Intent audit: the spine's AD-5, AD-13 and AD-11 text is untouched -- the orchestrator's ruling is no spine edit in this run, and Design Notes holds the proposed line for the owner.
  - `[low]` `[reject]` Intent audit: the client mirror keeps the name `acceptsEntityId` beside a comment naming `IdShapeAccepted` -- a naming divergence with no behavior change, and a rename would widen into Epic 20's `ui/src/app/**`.
  - `[low]` `[reject]` Intent audit: the mutation runs appear in the spec and not in code -- Rule 19 puts the `mutation:` lines under Verification, and each test's header carries its own.
  - `[low]` `[reject]` Intent audit: the dropped-announcement branch has no test -- same root cause as the second row.

### 2026-10-22 -- Review pass (batch 5)

- verdicts: 17 findings -- high 0, medium 0, low 9, false 8, maybe-false 0
- findings:
  - `low` `reject` A create's AD-10 call in `ScreenSave.Create` is observed by no test; only an update on a superserver is -- the shipped set judges these four targets by the reviewed-few sweep alone (`Prohibited.cls:649-657`), which `SaveFields` already keeps a create inside, so no arm can refuse a create today and a double would need a new class and a fixture seam (about 35 lines); reopen_if an AD-10 arm refuses a create of a superserver, MFT connection, Doc DB application or routine application.
  - `low` `patch` The numeric-port arm of `SuperserverSave.CreateIdentity` has no test -- a numeric-port create leg is added to `SuperserverWrite`, red under the arm's removal (run 99).
  - `low` `patch` A non-text MFT `Name` and a non-text Doc DB `Namespace` are unpinned -- one leg each in `MftConnectionWrite` and `DocDbAppWrite`, red under the shape violation's removal (runs 100, 101).
  - `low` `reject` `Release` is verified only by `SaveHoldCoverage`'s source scan -- a `Release` present but misplaced is not a failure any current caller can produce, and a lock-introspection leg is more than a direct correction.
  - `low` `patch` The default `UpdateArguments` (strip the identity members) is unpinned for Superserver and MFT -- one leg each repeats the id's members in a change body, red under a pass-through default (runs 111, 112).
  - `low` `patch` Six re-pointed test headers name mutations with no recorded run -- each run against `ScreenSave` and recorded under Verification (runs 102-107).
  - `low` `reject` Acceptance criteria without a `mutation:` line of their own for the MFT and Doc DB hooks and the `ScreenSaveRules` methods -- Rule 19 asks one demonstrated mutation per AC, and the AC has twelve recorded; the one unpinned fact the layer found, the routine application answer's missing `namespace`, was true of the three copies before the lift.
  - `low` `reject` The base's `RulesCheck`, `RulesTaken` and `CreateIdentity` defaults fail open -- all four Saves override each, and an adopter that forgets one fails its own `*Write` rules legs; no current caller reaches it.
  - `false` `reject` The diff adds hooks the spec's list omits (`CheckMerged`, `IdentityMembers`, `TakenField`, `Subject`) -- they carry the spec's "`MergeRaw` with the post-merge `Check`", `CallerFields` and the taken field and status wording that differed per Save; no status, code or body differs.
  - `false` `reject` `Create` and `Update` changed their public signatures -- a search of `src`, `ui` and `scripts` finds no caller beyond `Router`'s `HandleCreate` and `HandleUpdate` and the fixtures.
  - `low` `reject` The prohibited-set step is pinned through one subclass only -- the same root as the first finding above.
  - `false` `reject` Nothing pins the hierarchy, `ERRORCLASS` on Superserver and MFT, or the abstractness -- `ERRORCLASS` is read by every 422 the `*Write` classes assert (`SUPERSERVER.VALIDATION`, `MFT.VALIDATION`), and an abstract class is not instantiable.
  - `false` `reject` The equivalence has no before-and-after wire comparison -- the AC fixes the evidence as equal class totals plus the base mutations, and the 131 tests ran before and after.
  - `false` `reject` `ScreenSaveRules` says a concrete class declares `Check` and `Taken`, though the base declares neither -- the two take different argument lists per class, so a base declaration could not fit them; the doc states the contract.
  - `false` `reject` "Unchanged" for `RoutineAppSave` may mean its behavior -- both readings hold: the file is untouched and its answers are as before (`RoutineAppWrite` 15 of 15).
  - `false` `reject` `HandleUpdate` passes `$Get(tFault)` to `RenderRead` where Superserver and MFT passed `""` -- the 404 branch reads neither the fault nor the status text.
  - `false` `reject` `SuperserverRules.Text` went from private to public -- the spec lifts `Text` into `ScreenSaveRules`, where Doc DB's was already public; it names no harm.

## Design Notes

**Verdicts at `06c2f491`** (Ledger inbox: 12 of 12 addressed, none declined):

| Entry | Verdict | Evidence | Disposition | Batch |
|---|---|---|---|---|
| DW-2256 | Confirmed in code. The surface is the mint's `pFault.reason` alone. | `ExplorerSaveMint.cls:72`. `Dispatch.AnswerOne` sends code and detail, never the reason, and the step reason comes from the code. Whether a namespace-own object-only routine reaches the read is (inference) until Task 0. | resolved-by | 1 |
| DW-2257 | Confirmed | `ExplorerSaveMint.cls:88-94` equals `ExplorerSourceRead.Escaped` byte for byte | resolved-by | 1 |
| DW-2258 | Confirmed | `ExplorerSaveTurn.cls:199,218,237` | resolved-by | 1 |
| DW-2261 | Confirmed, and wider | Two `LIMIT` literals, plus two literals derived from the bound (`30000`, `59999`). Nothing pins `CUTTEXT`'s "60,000" to `SOURCEMAXLENGTH`. | resolved-by | 1 |
| DW-1267 | Confirmed, and wider | The error path drops unreached keys. `pRemaining` also never counts turns, though the doc says "either". | resolved-by | 1 |
| DW-235 | Confirmed, and wider | Measured on the extracted guard: `TMPDIR=/`, a sibling of `TMPDIR`, `//`, `/./` and symbolic links are all admitted. `ci-ipm-archive.sh` admits `//` and `/./` too. | resolved-by | 2 |
| DW-1762 | Confirmed, and the cause is measured. The entry's guess is corrected. | The kill comes about 3 s after signal 15 (Docker Desktop log). IRIS's user-job stop needs about 4.5 s. The stop timeout is 3 s, not the 10 s the evidence guessed. | resolved-by if the lead admits `docker-compose.yml`; otherwise `wontfix-accepted`, see Dispositions | 2 |
| DW-432 | Confirmed. The count is stale. | 20 variables. `PRODUCTION_INSTALL` arms 29 classes, against 11 at filing. No doc names any of them, and `ci-runner.mjs` says nothing. | resolved-by | 2 |
| DW-216 | Confirmed | `Smoke.cls` `Host`/`Port`/`Request`. Plain HTTP. No override. Undocumented. | resolved-by (documented constraint) | 2 |
| DW-1188 | Confirmed. The counts and anchors are stale. | 962 used, 837 styled, 138 unstyled, against 423/406/37 at filing. The cited lines have moved. | resolved-by | 3 |
| DW-1462 | Confirmed, and wider | 37 parent-scoped screens (not 4) read `entityId` as the parent's id, 99 as a row key. The four interop item tabs accept a model-composed two-part parent id. | resolved-by | 4 |
| DW-2278 | Confirmed | 56-74 identical lines per Save, and a shared template differing only at identity, merge and answer | resolved-by (server half; client forms kept, see Extend) | 5 |

**Dispositions.**

- DW-1762: if the lead declines the `docker-compose.yml` change, close it `wontfix-accepted`. Note: "the throwaway compose carries stop_grace_period 60s; the shipped docker-compose.yml is the owner's; reopen_if=`docker compose restart iris` on a container from the shipped compose logs 'Previous system shutdown was abnormal'".
- DW-2256: if Task 0 measures it unreachable, the note says so and names what was tried.
- DW-216: the override was not built. No external Web Gateway exists here to test one against, and `Host()`'s doc refuses another host on purpose.

**Governing ADs:**

- **AD-5, AD-11 rule 3 and AD-13.** The registry is the source. A sub-resource screen's route id is an entity of its parent's primary type, resolved through the parent declaration. Every refusal happens before announcement. There is one segment and no second composite grammar (DW-1462).
- **AD-12 and AD-39.** There is one envelope, a code never changes, and a reason is written once in `Error.cls` (DW-1462, DW-2256).
- **AD-61 and AD-36.** A document with no source is `PORT.NOTFOUND` with `REASONNOSOURCE`. A read is bounded by its declared length (DW-2256, DW-2257, DW-2261).
- **AD-53, AD-55, AD-10, AD-34, AD-52 and AD-58.** These hold for the shared Save (DW-2278): one tool class with two callers, the prohibited set after the state read and before the port write, the lock from the fresh read through the read-back, the declared port, the read-back, no proposal, and no read-only or kill-switch gate.
- **AD-9.** Nothing under `Kernel/State/` names `OcuPilot.Screen`. So the turn view keeps one route id, and the split stays in `Kernel/Agent` and `Screen/Tool`.
- **AD-17, AD-38 and AD-45.** These cover the test-scope arming, the container start and health, and the single smoke path owned by `Install/` (DW-432, DW-1762, DW-216).
- **Conventions:** › Tests and › Dates do not apply. › ObjectScript naming applies.
- **Dependency direction.** The Kernel base names `Api.Response`. No AD's Rule forbids it, and Kernel already names `Api.Error`, `Api.Turn`, `Api.Router` and `Api.ScreenAction`. `check-objectscript.py`'s Rule 20 bars only `Kernel/Shell/` and `Screen/Tool/`.

No AC contradicts an AD's Rule, and no NFR is in play.

**Decided in-stage:**

- **Batch order:** smallest risk first. The shared Save goes last.
- **DW-1462, no stored change.** The split is at the tool's contract: `entityId` versus `parentId` in, and the settled echo out.
  - The Nav row and the turn view keep one route id under `EntityId`/`navigation.entityId`. The client navigator already reads it by route (`ownIdSegment`/`parentIdSegment`).
  - A separate stored `ParentId` would be a `Kernel/State` schema change, a veto-window category, for no behavior gain. `Kernel/State/Turn` cannot name `Screen` either (AD-9).
- **DW-1462, `parentId` acceptance reads the parent's id shape.**
  - As a result, the four `interoperability/productions/items/{jobs,log,messages,queue}` tabs refuse an id. Today they take a model-composed `Production||Name`.
  - Eight screens become openable for their parent: the three mapping lists, `analytics/term-lists/entries`, `lookup-tables/entries`, `interoperability/productions/items`, `web-applications/routine-applications/routines` and `tasks/schedule/history`.
  - Both are visible to a user, through what the agent can open.
- **DW-1462, `detail.argument`.** It names the refused argument, because the model receives a refusal's code and detail but not its reason (`Dispatch.ErrorContent`). This is a detail field, not a code.
- **DW-2256.** One parameter swap, not a shared fault helper: two three-line builds read better than a helper.
- **DW-2261.** The bound derives from the base's `SOURCEMAXLENGTH`, so a subclass override still reddens `ExplorerSourceEdges`. A new pin holds `CUTTEXT`'s published number equal to it.
- **DW-1267.** Count turns as the doc says, matching `Remove`, rather than narrowing the doc.
- **DW-235.**
  - Port `ci-ipm-archive.sh`'s normalization as a short copy: two standalone scripts with no shared shell library.
  - Extend the plain-spelling refusal to that script, since it is the same root cause.
  - A symbolic link in an ancestor of `--dir` is left (filing candidate).
- **DW-1762: 60 s.** Measured clean shutdowns take 0.4-5.0 s, so this gives more than ten times headroom.
- **DW-432.** Add a docs paragraph, a doc-pin test both ways, and a runner hint, so the reds explain themselves where they appear.
- **DW-432, the hint's source.** The framework stores a class-level record's hook name as `action` and the refusal text as `error` (`%SYS.UNITTEST` `LogStateStatusPrivate`), so the hint reads both; the Wording's "action names" is read as "record names".
- **DW-432, the cited heading.** The Wording's hint cites "Armed test classes", so the paragraph's bold lead carries that label.
- **DW-235, the link line.** For a link at `$DIR/data` the line names that path, not `$DIR`; the sentence is the Wording's.
- **DW-216.** A documented constraint. See Dispositions.
- **DW-1188.**
  - Remove the 44 dead tokens rather than allow-list them, because the allow-list is for intentional hooks. This changes nothing visible.
  - Keep the 4 tokens owed a style, with a stale check, and file the styling as a candidate. That is a visible change outside this entry's intent.
- **DW-2256, the pin.** The mint's read is reached through `ExplorerRoutineSaveUnguarded`, a test subclass of the Routines save that lifts `AgentProblem`, over the vendor `EnsJob.mac` that the instance keeps as object code. The probe-routine and `.obj` shapes of Task 0 never reach it.
- **DW-1267.** `RemoveSeeded` still attempts a key's turn delete when its proposal delete fails, counts through two new public helpers (`ProposalCountForTurn`, `TurnCountForTurn`) that `ProposalFixtureSweep` shares, and answers an unreadable count as an error status with `pRemaining` -1, as `Remove` does. The helpers filter by one turn key where `Remove`'s `ProposalCount`/`TurnCount` filter by user-name prefix, so they stay a pair beside it. The probe's `unreadable` mode drives the -1 path.
- **DW-2261.** The two classes' assertion messages that named 60,000 now say "the bound", so a mutated bound does not leave a stale figure in a failure.
- **DW-2278.**
  - Server half only. The 18.31 routine applications ride along through Doc DB.
  - The 18.33 role tabs (client) and the 18.34 `RestServiceSave` belong to other families: the create-dialog family and `Explorer.DocDbSave`. They do not join.

**The 138 unstyled names (DW-1188).**

- **Hooks, 90, allow-listed (group A).**
  - Referenced by `ui/browser`, 67:
    - `ocu-broadcast-{message,send}`
    - `ocu-command-bar-{permission-check,refresh-action,sort-label,task-manager-suspend,view-item,view-trigger}`
    - `ocu-command-box-{group-actions,group-screens,list,option-label}`
    - `ocu-copy-status`
    - `ocu-data-table-{announcement,count,menu-label,refusal-message}`
    - `ocu-details-{group,tasks,tasks-none,tasks-table}`
    - `ocu-ecp-status-{consequence,submit}`
    - `ocu-form-tab`, `ocu-form-tab-invalid`
    - `ocu-guardrails-{kill-switch,limits,read-only,reason,secrets,turns}`
    - `ocu-home-block-fixed`, `ocu-home-status`, `ocu-line-diff-text`
    - `ocu-lock-remove-{consequence,submit,warning}`
    - `ocu-log-cell-{text,time}`, `ocu-log-chip-word`, `ocu-long-block`
    - `ocu-panel-{full-screen,full-screen-toggle,jump,message-streamed,new-conversation}`
    - `ocu-pct-access`, `ocu-pct-access-{add,delete,empty,table}`
    - `ocu-proposal-card-{cancel,confirm,draft-action,repropose,summary-fields}`
    - `ocu-role-member-admin`
    - `ocu-screen-permissions-{add-button,consequence,pair,text}`
    - `ocu-trace-participant`
    - `ocu-transcript-{context-route,context-toggle,withheld}`
    - `ocu-warning-consequence`, `ocu-workflow-chip-end`
  - Referenced by `*.spec.ts` only, 23:
    - `ocu-area-tile-{screen,separator}`, `ocu-broadcast-hint`
    - `ocu-command-bar-{journal-switch-directory,journal-switch-file,task-import,view-menu}`
    - `ocu-guardrails`, `ocu-instance-segment`
    - `ocu-locator-{favorite-glyph,status}`, `ocu-log-chip-count`
    - `ocu-oauth-client-metadata`, `ocu-oauth-resource-server-authenticator-note`, `ocu-oauth-server-privilege`
    - `ocu-proposal-card-{announcement,chevron}`
    - `ocu-screen-permissions-{classic,fixed,refusal,remove}`
    - `ocu-status-bar-user`, `ocu-transcript-context-none`
- **Owed a style, 4 (group B).** `ocu-field-error` (four sites), `ocu-link`, `ocu-routine-app-routines` and `ocu-namespace-switch-caret`.
- **Dead, 44, removed.** A bare element:
  - `ocu-auditing-status`, `ocu-command-box-group`, `ocu-data-browser-tree-item`
  - `ocu-data-table-footer-separator`, `ocu-data-table-max-rows-label`
  - `ocu-ecp-status-choice-label`, `ocu-form-tab-panel`, `ocu-home-block-glyph`, `ocu-locator-help-word`
  - `ocu-log-hub-last-text`, `ocu-log-hub-tr`, `ocu-pct-access-bar`
  - `ocu-screen-permissions-list`, `ocu-test-result`, `ocu-transcript-context`

  Beside a styled base class:
  - `ocu-auditing-page`, `ocu-code-block-step`, `ocu-command-bar-view`
  - `ocu-data-browser-header-cell`, `ocu-data-browser-size`, `ocu-data-table-check-all`
  - `ocu-details-tasks-truncated`, `ocu-details-tasks-unchecked`, `ocu-ecp-settings-ssl`
  - `ocu-field-effect`, `ocu-guardrails-tools`, `ocu-log-cell-pid`, `ocu-log-cell-severity`
  - `ocu-log-hub-clear`, `ocu-log-hub-notice`, `ocu-log-hub-source`, `ocu-log-viewer-raw`
  - `ocu-oauth-server-metadata`, `ocu-openapi-path-toggle`, `ocu-openapi-refusal`
  - `ocu-screen-permissions-add`, `ocu-screen-permissions-pairs`, `ocu-transcript-turn`, `ocu-try-it-toggle`
  - `ocu-typed-name-advisory`, `ocu-typed-name-flag`, `ocu-wallet-key`, `ocu-warning-advisory`, `ocu-warning-flag`

  Family 7's first run on the tree prints every site. That run is the authority over this list.

**Wording for the lead** (the lead rules at the spec gate):

- **`shell.screen.open`** (the model reads this):
  - `DESCRIPTION`: "Open a screen for the user: optionally select one of its rows by the row's id, or open a screen that belongs to one item (such as a task's history) for that item. Announces the move before it happens, then waits about a second before the browser moves; the departing screen may refuse the move (for example, unsaved changes), and the user may always return with Back."
  - `entityId`: "The row to select, once resolved from the row's own identifying value, on a screen of its own rows. Refused on a screen that belongs to an item (send parentId there), and on a screen whose id is none or has more than one part."
  - `parentId`: "The item a screen belongs to, by that item's own identifying value: a task's id for its history or details, a database's directory for its volumes. Accepted only on a screen that belongs to an item, and refused where that item's id is none or has more than one part."
  - `ResultSchema` `parentId`: "The item the screen was opened for, when one was."
- **`REASONNAVENTITYNOTALLOWED`** (a person may read it in the trace):
  - Now: "This screen does not take a selected row."
  - Proposed: "This screen cannot be opened on that item."
- **DW-2256.** No new sentence: the mint answers the viewer's existing `REASONNOSOURCE`.
- **`docs/DEVELOPMENT.md`, Armed test classes:** "**Some test classes refuse to run outside a throwaway.** A class that creates principals, installs OcuPilot's production profile, changes the instance's configuration or calls a provider stub reads an arming variable in `OnBeforeAllTests`, and unless it reads `1` the class records an error and runs no method. Only `scripts/ci-throwaway.sh` sets them, in the compose file it writes, so these classes are red by design on `ocupilot` or a slot instance. The variables are …(the 20 names)…. The `# classes:` comment above each one in `scripts/ci-throwaway.sh` lists the classes it arms, and `ui/tools/ci.test.mjs` holds each list equal to the classes that read the variable."
- **Runner hint**, appended to the class-level line: "; it names OCUPILOT_ALLOW_<X>, an arming variable only scripts/ci-throwaway.sh sets, so this class runs on a throwaway and not on a development instance (docs/DEVELOPMENT.md, Armed test classes)".
- **`Smoke.cls` header, and `docs/DEVELOPMENT.md` "The smoke script":** "**It asks the instance's own web server.** The HTTP checks go to `localhost`, over plain HTTP, on the port `Config.Startup` reports as the instance's web-server port. An instance that serves OcuPilot only through an external web server fails every HTTP check even when it is installed correctly."
- **The guard's refusal lines** (developer-facing):
  - "ci-throwaway: '$DIR' must name its directory plainly, with no '//', '/./' or trailing '/.'; a throwaway's directory is removed recursively"
  - "ci-throwaway: '$DIR' is a symbolic link; a throwaway's directory is removed recursively, so it must be a real directory under its scratch root"
  - The same two lines, prefixed `ci-ipm-archive:`, in that script.

**Spec-gate rulings (lead, 2026-10-22).**

- `docker-compose.yml` `stop_grace_period: 60s` (DW-1762): **admitted** (decide). The conditional Batch 2 task applies. It is a release-upgrade trigger, reported at the batch-2 boundary.
- `README.md` sentence (DW-216): **admitted as written** (veto U-6). The Batch 2 task applies it.
- Wording for the lead: **admitted as written.** `shell.screen.open`'s texts and `REASONNAVENTITYNOTALLOWED` are one veto (U-7). The docs paragraphs, the runner hint, the `Smoke.cls` note and the guard lines are developer-facing (decide).
- The two Rule 20 spine lines: **no spine edit in this run** (orchestrator ruling 2026-10-22, decide). Batches 4 and 5 comply with the ADs as they stand. Both lines below are kept verbatim for the owner's attended bmad-architecture Update after the run. Implement does not edit the spine.

**For the lead** (outside the footprint, or the lead's own steps):

- **`docker-compose.yml` (DW-1762).** Add `stop_grace_period: 60s` to the `iris` service, after `restart: on-failure:3`.
  - The owner's container takes it only when next recreated (`docker compose up -d --wait`), which is the owner's call.
  - `README.md` needs no change. The first restart after the edit is still abnormal, and later ones are clean (inference).
- **`README.md` :555-557 (DW-216),** appended to the smoke bullet: "It asks the instance's own web server at localhost, so behind an external web server its HTTP checks fail even on a correct install."
- **The DW-1762 measurement**, the runner's, after its fresh check brings `ocupilot-ci` up on the batch-2 compose:
  1. `docker inspect -f '{{json .Config.StopTimeout}}' ocupilot-ci` reads `60`.
  2. Run `docker compose -f /Users/jbrandt/.ocupilot-throwaways/ocupilot-ci/compose.yml restart iris`.
  3. Then `/Users/jbrandt/.ocupilot-throwaways/ocupilot-ci/data/iris/mgr/messages.log` gains no "Previous system shutdown was abnormal".
- **Epic 20 and family 7.** Epic 20's runner meets family 7 at its next integrate-forward. A new unstyled class needs a style or an allow-list line.
- **Rule 20, DW-1462** (for the owner's attended bmad-architecture Update after the run). The orchestrator's 2026-09-22 convention is not yet in the spine. Proposed line for AD-11's navigation paragraph: "`shell.screen.open` takes `entityId` for a row of a screen's own and `parentId` for the item a parent-scoped screen belongs to. Each is accepted by the registry's declaration (the screen's id shape, or its parent screen's) and otherwise refused `NAV.ENTITYNOTALLOWED` before any announcement [AMENDED <date>, Story 23.8 spec gate, Rule 20, DW-1462]."
- **Rule 20, DW-2278** (for the owner's attended bmad-architecture Update after the run; inference that it has weight). `Kernel/Proposal/ScreenSave` is the first Kernel class to name `Api.Response`. It may merit one clause in the spine's dependency paragraph.
- **Batch 4's `Kernel/State/Nav.cls` edit is a doc comment only,** with no property and no storage change. The merge's `Kernel/State` release-upgrade trigger reads it as doc-only.
- **The epic context.** Its DW-2256 UX line says the refusal "reads the viewer's sentence". On the agent path the model gets the code alone; the sentence is the mint's `pFault.reason`.

**For the Planner** (owner-only files, DW-432):

- `CLAUDE.md` "Running and verifying", one bullet: "Test classes armed by an `OCUPILOT_ALLOW_*` variable run only on a throwaway, since `scripts/ci-throwaway.sh` is the only thing that sets them. They are red by design on `ocupilot` or a slot instance; see `docs/DEVELOPMENT.md`, Armed test classes."
- `.claude/rules/objectscript-testing.md`: the same sentence, under "Practices".

**Contended files (Rule 11).** Checked against Epic 20's head `3d032313`, with both commands empty for every planned path. Epic 20's working tree edits `ui/src/app/core/strings.ts` and `src/OcuPilot/Area/Analytics/MdxQuery.cls`; this story edits neither. Re-check before each batch with:

- `git -C /Users/jbrandt/git/OcuPilot/.worktrees/epic-20 diff --stat origin/feature/OCU-1_ocupilot-mvp...HEAD -- <path>`
- `git -C /Users/jbrandt/git/OcuPilot/.worktrees/epic-20 status -s --untracked-files=all -- <path>`

| File | Epic 20's change | This story's edit |
|---|---|---|
| (every file in the Code Map and Tasks) | none | as tasked |

**Consumed-by and Consumes (Rules 1 and 2).** Every consumer is in this story.

- `Kernel.Proposal.ScreenSave` and `ScreenSaveRules` are consumed by `SuperserverSave`, `MftConnectionSave` and `DocDbAppSave` (with their Rules), and through Doc DB by `RoutineAppSave`. Observed by their `*Write`, `*Gate`, `*Read` and `SaveHoldCoverage` classes.
- `Navigate`'s `parentId` and `pParentId` are consumed by `Dispatch.ResolveClientCall` and `SettleClient` and by `Loop`. Observed by `ToolNavigateParent` and `task-resume.browser-spec.mjs`.
- Family 7 is consumed by `npm run build`'s prebuild and by `client-lint.test.mjs`.
- `ProposalFixtureFaultProbe` is consumed by `ProposalFixtureSweep`. `ExplorerSourceTestCase.Limit` is consumed by `ExplorerSource` and `ExplorerSourceEdges`.

**Extend, don't copy (Rule 31).**

- **`ScreenSave`** lifts `DocDbAppSave`'s generalized hooks.
  - It is under `Kernel/Proposal/` beside `Operation`, `ReadBack` and `Prohibited`, because a slice never depends on another slice. `Kernel/Shell` is barred from `Api.Response`.
  - **The client forms stay three copies.** The pages diverge: Superserver has 373 lines MFT lacks, and MFT and Doc DB each have 124-152 lines of their own. No client form base exists among the 24 `*form.store.ts`, so a base for three would couple three areas' editors.
- `ToolNavigateParent` is a new class because `ToolNavigate` is 499 lines and `TurnNavigate` 636. It reuses `TurnLoopProbe`.
- `ProposalFixtureFaultProbe` follows `LedgerFaultProbe`'s probe-subclass seam.
- Family 7 follows `ALLOWED_ABSOLUTE_URLS`. `classifyFailureDetail` is extended in place, and `ExplorerSaveTurn` takes `ExplorerSourceTurn`'s form.

**Filing candidates, not absorbed** (Rule 27 cap):

1. About 25-35 other `Area/*Save.cls` copy `Prohibited`, `Body`, `ProhibitedClass`, `Send` or `Gate`, and could extend `ScreenSave`.
2. An agent save refused for a missing document and one refused for a source-less document both reach the model as bare `PORT.NOTFOUND`.
3. Four templates use a class with no style where the sibling's is styled: group B.
4. `ci-throwaway.sh` and `ci-ipm-archive.sh` admit a `--dir` whose ancestor is a symbolic link. Closing it needs canonical roots on both sides.

## Verification

**Shared steps**, on slot A with `ocupilot-ci` (52776/1975, directory `/Users/jbrandt/.ocupilot-throwaways/ocupilot-ci`):

- **Load (loop).** Run `rsync -a --delete src/ /Users/jbrandt/.ocupilot-throwaways/ocupilot-ci/src/`, then `Do $System.OBJ.LoadDir("/opt/ocupilot/src","ck-d",.e,1)` in `docker exec -i ocupilot-ci iris session iris -U HSCUSTOM`. Expected: 0 errors.
- **Class (loop).** Run `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.<C>`, one class per call. Expected: 0 failed, confirmed in `%UnitTest_Result`.
- **Checks (loop).** Expected: each is clean or green.
  - `uv run scripts/check-objectscript.py <changed .cls>`
  - `cd ui && npm run test:tools`
  - `bash scripts/lint-docs.sh` (batch 2)

**Commands** (all `(loop)`). There are no `(once)` lines: the full ObjectScript sweep and Rule 30's fresh check are the lead's, and the full browser suite is CI's.

- **Batch 1:** Load. Then Class for each of:
  - The explorer classes: ExplorerSaveFlow, ExplorerSaveMintUnit, ExplorerSaveTurn, ExplorerSource, ExplorerSourceEdges, ExplorerSourceTurn.
  - The sweep: ProposalFixtureSweep.
  - `RemoveSeeded` callers: ConfirmRoute, ProposalConfirm, EncryptionKeyFileRead, DraftExecute.

  Then Checks.
- **Batch 2:**
  - Checks: `npm run test:tools` covers `ci.test.mjs`, `ipm-archive.test.mjs`, `shell-scripts.test.mjs` and `compose.test.mjs`, then `bash scripts/lint-docs.sh`.
  - Load (`Smoke.cls` docs), and `uv run scripts/check-objectscript.py src/OcuPilot/Install/Smoke.cls`.
- **Batch 3:**
  - `cd ui && node tools/client-lint.mjs`, expected exit 0.
  - `cd ui && npm run test:tools`.
  - `cd ui && npm run test:components`.
  - `cd ui && npm run build`, expected success.
- **Batch 4:**
  - Load. Then Class for each of ToolNavigate, ToolNavigateParent, TurnNavigate and ToolRoundTrip.
  - Redeploy the bundle: `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`.
  - Then `cd ui && OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci node --test --test-concurrency=1 browser/task-resume.browser-spec.mjs`.
  - Then Checks.
- **Batch 5 (run before the edit and after, with equal totals):**
  - Load. Then Class for each of:
    - Superserver: SuperserverWrite, SuperserverGate, SuperserverRead, SuperserverProhibited, SuperserverDescriptor.
    - MFT connections: MftConnectionWrite, MftConnectionGate, MftConnectionRead, MftConnectionDescriptor.
    - Doc DB applications: DocDbAppWrite, DocDbAppGate, DocDbAppRead, DocDbAppDescriptor.
    - Routine applications: RoutineAppWrite, RoutineAppGate, RoutineAppRead, RoutineAppMembers, RoutineAppDescriptor.
    - SaveHoldCoverage.
  - Then Checks, and `cd ui && node tools/ipm-manifest.mjs --check`.

**Shared surfaces:**

- **`shell.screen.open`.**
  - Its input schema goes from 4 properties to 5 (`ToolNavigate`), and its result schema gains `parentId`.
  - The acceptance partition changes for 45 screens. The 37 parent-scoped screens stop taking `entityId`: 33 take `parentId` instead and 4 take no id. Another 8 newly take `parentId`.
  - The `NAV.ENTITYNOTALLOWED` reason changes.
  - `task-resume.browser-spec.mjs`.
- **`ProposalFixture.RemoveSeeded`'s count and error path.** It has 242 caller files, and the success path is unchanged.
- **The explorer source tests' bound.**
- **Client lint.** `RULE_FAMILIES` goes from 6 to 7, and 44 template tokens are removed (none is read by any test).
- **The throwaway compose's keys,** and **`classifyFailureDetail`'s class-level line.**
- **ObjectScript classes.**
  - New test classes: ProposalFixtureSweep and ToolNavigateParent.
  - New classes that are not tests: ProposalFixtureFaultProbe, `Kernel.Proposal.ScreenSave` and `ScreenSaveRules`.
  - No arming roster changes.
- **Standing criterion.** Every test added or changed passes on a fresh environment, in either order. Each test creates and removes its own rows, documents, keys and markers.

**Task 0 (batch 1), measured on `ocupilot-ci`:**

- `OcuProbe2021Obj.mac` made, compiled, then `Delete(name, 2)`: `AgentProblem("USER", name)` is `""`, and `AtelierPort.Invoke("Routine", "LIST", ...)` answers 404 `PORT.NOTFOUND` with `REASONNOTFOUND`, not `available` 0 with `objectonly`. `^rINDEX(name, "MAC")` is gone and `^rOBJ` stays (the index read finds no MAC node, an inference).
- A deployed `.obj` export, `Delete(name, 0)` and reload: `^rINDEX` holds the `OBJ` type only. `.mac` and `.int` answer 404 `REASONNOTFOUND`, `.obj` 400.
- The one object-only shape on the instance is `EnsJob.mac` (`^rINDEX` holds `MAC`, `^rMAC` does not), and `AgentProblem` refuses it as stored in ENSLIB before the read. The mint names `AtelierPort` itself, so `AtelierPortFixture`'s fake routes cannot answer its read.
- Outcome: neither shape reaches the read. A third does, through the real Routines save: a `USER` routine compiled and then stripped of its `^rMAC` source reads `200 0 objectonly` (code review), and `TestAnObjectOnlyRoutineIsRefusedAsKeepingNoSource` makes it, pins it and removes it. The probe routine and export file are removed.

**Mutations (Rule 19)**, each to be applied, observed and recorded with its run:

- `mutation:` (DW-2256, code review, `ocupilot-ci`; both pins call the real `ExplorerRoutineSave.View`):
  - The mint answers `REASONNOTFOUND` for an unavailable document: `TestAnObjectOnlyRoutineIsRefusedAsKeepingNoSource` the one red (run 51, 16 of 17).
  - The mint answers `REASONNOSOURCE` for a read the port refused: `TestAMissingRoutineIsRefusedWithTheReasonOfAnAbsentDocument` the one red (run 52, 16 of 17). Reverted: run 59 green 17 of 17.
- `mutation:` (DW-2257) `ExplorerSourceRead.Escaped` answers `$Length(pText)`. On the unfixed mint `ExplorerSaveFlow` stays green 15 of 15 (run 1). On the fixed mint `TestAnEditPastThePortsBoundIsRefused` is red on both legs, the first included (run 2, 14 of 15). Reverted: run 16 green.
- `mutation:` (DW-2258) `RemoveKeyed` ends with `Quit $$$ERROR($$$GeneralError,"m")`. Unfixed: the test method stays green and only `OnAfterAllTests` reddens the class (run 3, 1 test, 0 failed). Fixed: the method is red on "the probe package is removed" (run 4, 1 failed). Reverted: run 18 green.
- `mutation:` (DW-2261):
  - `SOURCEMAXLENGTH` 50000 with `CUTTEXT` "50,000": before the fix `ExplorerSource` is red 2 of 10 (run 5) and `ExplorerSourceEdges` 2 of 12 (run 6); after it, green 11 of 11 (run 7) and 12 of 12 (run 8).
  - `SOURCEMAXLENGTH` 50000 alone: `TestTheReadDescriptionStatesTheBoundItCutsTo` is the one red (run 9, 1 of 11).
  - `ExplorerSourceRead.ResultSchema`'s `text` description states 50,000: `TestTheReadDescriptionStatesTheBoundItCutsTo` is the one red (run 42). Reverted: run 43 green.
  - `CUTTEXT` states 160,000 (code review, whole-figure match): `TestTheReadDescriptionStatesTheBoundItCutsTo` the one red (run 53, 10 of 11). Reverted: run 54 green.
  - `SOURCEMAXLENGTH` 600000: `ExplorerSourceEdges` red 5 of 12, `TestALongRoutineIsCutAtWholeLines` among them (run 10), so its mutation note holds. Reverted: runs 19 and 20 green.
- `mutation:` (DW-1267):
  - Unfixed `RemoveSeeded`: both tests red (run 12), the other key left unswept when the failed key is reached first.
  - Post-loop `Kill ^||OcuPilotProposalFixtureTurns` restored: both red (run 14).
  - Turn count dropped from `pRemaining`: `TestASurvivingTurnIsCounted` alone red (run 15).
  - `RemoveSeeded` without its unreadable-count branch: `TestAnUnreadableCountKeepsItsKeyAndSweepsTheOtherKey` the one red, on its status assertion in all four legs (code review, run 57, 3 of 4).
  - `RemoveSeeded` skips a key's turn delete once its proposal delete failed: `TestAFailedKeyIsKeptAndTheOthersAreSwept` red on `1 0` and the count of 1, with `TestAKeyWhoseDeleteReportedAFailureIsKeptEvenWithItsRowsGone` (code review, run 56, 2 of 4). Reverted: run 58 green 4 of 4.
  - Fixed: run 22 green 2 of 2. The rows the red runs left were deleted by key.
- `mutation:` (DW-1267, QA, `ocupilot-ci`; each reverted and the class green, run 16):
  - A key is forgotten without asking whether its removal succeeded: the new `TestAKeyWhoseDeleteReportedAFailureIsKeptEvenWithItsRowsGone` the one red (run 10, 1 of 5).
  - A key is forgotten once its removal succeeded, rows or not: `TestASurvivingTurnIsCounted` the one red (run 13).
  - The unreadable branch ends the loop instead of continuing: the new `TestAnUnreadableCountKeepsItsKeyAndSweepsTheOtherKey` the one red (run 11); the single-key test stays green.
  - The turn count is not asked whether it could be read: the same new test the one red (run 12).
  - An unreadable count is clamped to 0: `TestAnUnreadableCountKeepsItsKeyAndSweepsTheOtherKey` red on every assertion (run 14).
- `mutation:` (DW-2257, DW-2258, DW-2261, QA, re-run on `ocupilot-ci`, each reverted): the recorded mutations reproduce. `Escaped` answers `$Length(pText)`: `TestAnEditPastThePortsBoundIsRefused` the one red, on its "says why" assertion, since the card-width limit refuses the edit under the same code (run 19). `RemoveKeyed` ends in an error: the method is red on "the probe package is removed" (run 18). `SOURCEMAXLENGTH` 50000 alone: `TestTheReadDescriptionStatesTheBoundItCutsTo` the one red (run 20). `ExplorerRoutineSource` declaring `SOURCEMAXLENGTH` 600000: `TestALongRoutineIsCutAtWholeLines` the one red (run 22), so the note at `ExplorerSourceEdges` holds.
- (QA) Tests added to existing files, no new file: `src/OcuPilot/Test/ExplorerSaveFlow.cls` (`MintUnguarded`, `TestAMissingRoutineIsRefusedWithTheReasonOfAnAbsentDocument`), `src/OcuPilot/Test/ProposalFixtureFaultProbe.cls` (modes `failafter` and `unreadableturn`) and `src/OcuPilot/Test/ProposalFixtureSweep.cls` (`TestAKeyWhoseDeleteReportedAFailureIsKeptEvenWithItsRowsGone`, `TestAnUnreadableCountKeepsItsKeyAndSweepsTheOtherKey`).
- `mutation:` (DW-235, `node --test`, each reverted and the file byte-identical by `cmp`):
  - `ci-throwaway.sh` guard reverted to the raw `TMPDIR` arm: the new test is red on its first leg, exit 0 with "no compose file" where 2 was expected. Alone: no link check, red on the `--dir` link leg; link check on `$DIR` only, red on the data-link leg; `TMPDIR` arm without its separator, red on the sibling leg; no plain-spelling case, red on `/tmp/./x`; the absolute check on `TMPDIR` relaxed to non-empty, red on the relative `TMPDIR` leg; no trailing-slash strip, red on the trailing-slash link leg.
  - `ci-ipm-archive.sh` guard reverted: the new test is red on `/tmp//x`. Alone: no link check and no plain-spelling case each redden it; no trailing-slash strip reddens it on the trailing-slash link leg only (the other legs are refused without the strip).
  - Reverted: `ci.test.mjs` 91 of 91, `ipm-archive.test.mjs` 33 of 33, `npm run test:tools` 2119 of 2119.
- `mutation:` (DW-1762) `stop_grace_period` dropped from the here-doc: the new pin and the compose-equality test are red. Dropped from `docker-compose.yml`: the equality test and the `compose.test.mjs` pin are red. `docker-compose.yml` reading `30s`: the same two are red. Each reverted.
- `mutation:` (DW-432):
  - `OCUPILOT_ALLOW_JOURNAL` removed from `docs/DEVELOPMENT.md`: the doc pin is red on the missing name. `OCUPILOT_ALLOW_BOGUS` added: red on the unknown name.
  - The hint dropped from `classifyFailureDetail`: the runner test is red on the armed legs. The hint on every class-level line: red on the unarmed leg. Each reverted.
- (QA) Test added to an existing file, no new file: `ui/tools/ci.test.mjs`, `DW-432: the section the runner hint cites is the paragraph of docs/DEVELOPMENT.md that names the arming variables`. The runner-hint test's "named once" assertion now counts the variable, not the phrase "it names", which a deduplicated and an undeduplicated hint both carry once.
- `mutation:` (DW-432, QA, `node --test`, each reverted, `cmp` and `git diff` clean):
  - The cited label renamed to "Armed classes" in `docs/DEVELOPMENT.md`: the two earlier DW-432 tests stay green, and the new test is the one red.
  - A blank line ends the paragraph before its variable list: the new test the one red.
  - The `new Set` deduplication removed from `classifyFailureDetail`: "a variable is named once however many records name it" the one red, and green before the assertion counted the variable.
- `mutation:` (DW-235, DW-1762, DW-432, QA, the recorded mutations re-run, each reverted, `cmp` and `git diff` clean):
  - `ci-throwaway.sh`: the guard reverted, the raw `TMPDIR` arm alone, no link check, the link check on `$DIR` only, no `TMPDIR` separator, no plain-spelling case, each of the three plain arms alone, the absolute check relaxed, no strip of `--dir`, no strip of `TMPDIR`. Each reddens the one DW-235 test on its own leg: `TMPDIR=/`, the link legs, the sibling, `/tmp/./x`, `/tmp//x`, `/tmp/x/.`, the relative `TMPDIR`, the slash-spelled link. Without the `TMPDIR` strip the link legs are the first red, since the host's `TMPDIR` ends in a slash.
  - `ci-ipm-archive.sh`: no link check, no plain-spelling case, each plain arm alone, no strip each redden the one DW-235 test (the strip on the slash-spelled link leg only). A link check that refuses every directory reddens the SIGTERM test and the unbuilt-bundle test, so the admitted half is pinned. The whole-guard revert is recorded under the review line below.
  - DW-1762: the key dropped from the here-doc, set to 30s there, or moved to `durable-init`: the here-doc pin and `the throwaway start path is the one docker-compose.yml ships` red. Dropped from `docker-compose.yml` or set to 30s: the `compose.test.mjs` pin and the same equality test red.
  - DW-432: `OCUPILOT_ALLOW_JOURNAL` removed from the document, or `OCUPILOT_ALLOW_BOGUS` added: the doc pin red. The hint dropped, on every line, read from the action only, or from the error only: the runner-hint test red on its own leg.
- `mutation:` (DW-235, DW-432, code review, `node --test`, each reverted, `cmp`, `git status` and `git diff --stat` unchanged):
  - `ci-throwaway.sh`'s link test also refusing a real directory under `/tmp`: the DW-235 test red on "a directory under /tmp is admitted". As `-e`: red, on the data-link leg first.
  - `ci-ipm-archive.sh`'s guard reverted whole (re-run on the home-directory root, default environment and `TMPDIR=/tmp` with dash as `sh`): its DW-235 test red on its first leg, the regressed guard staging only inside the test's root, and the `$HOME` and `/tmp` listings unchanged.
  - The hint's plural form dropped: the runner-hint test red on its two-variable leg.
- `mutation:` (DW-235, CI rework, `node --test` under the default environment and `TMPDIR=/tmp`, each reverted, `cmp`, `git status` and `git diff --stat` unchanged): the root under `/tmp` is the defect, red before and green after (`TMPDIR=/tmp`, `${scratch}//` leg, exit 1 where 2 was expected). `ci-ipm-archive.sh` without the `$DIR` trailing-slash strip: red on the slash-spelled link leg. Its `$TMPDIR` arm as `"$SCRATCH_TMPDIR"*`: red on the `${scratch}//` leg. `HOME` under `/private/tmp`: red on the root's placement assertion, with nothing left behind.
- **Batch 3, measured at `0c62d06a` (family 7's first run, equal to the Design Notes lists):** 961 used names, 841 styled, 138 used and unstyled = 90 hooks (67 read by `ui/browser`, 23 by `*.spec.ts` only) + 4 owed a style + 44 dead. The 44 (49 sites) are removed: a whole-token search of `ui/src`, `ui/browser` and `ui/tools` found no reader, only three id or name strings that are not class contexts (`ocu-log-hub-source`, `ocu-ecp-settings-ssl`, `ocu-oauth-server-metadata`).
- `mutation:` (DW-1188, `node --test tools/client-lint.test.mjs`, each reverted and `tools/client-lint.mjs` byte-identical by `cmp`):
  - `ocu-copy-status` removed from group A: the CLI exits 1 naming `src/app/shell/copy-control.ts:19`, and the two real-tree tests are red (84 of 86).
  - `ocu-banner`, a styled name, added to group A: `stale-unstyled-class-hook` ("a stylesheet selects it now"), and both real-tree tests are red.
  - Each of these reddens at least one fixture or CLI test: the `src/styles/` gate on the whole-tree checks removed; `id=` read as a class; an unreported dynamic `[class]`; the reader check on a hook removed or matched by substring; a prefix honored for a `[class]` binding in a file other than its own, or for a built name in any file; a composed prefix with no style or no builder; a literal name under a declared prefix no longer exempt; the stale checks for a styled or an unused hook; `styles:` read from the whole `.ts` file; stylesheet comments not blanked; `*_CLASS`, host `class`, `[class.x]` or `[class]` literals not read; an unstyled use not reported; an interpolated prefix read as a name; the family not wired into `lintClient` or `RULE_FAMILIES`. The styled-stale test first stayed green because the hook was also unread, so it now pins the reason; re-run red.
  - Re-added `ocu-auditing-page` to `auditing-config.page.ts` (one of the 44): the CLI exits 1 at `auditing-config.page.ts:120`, and the two real-tree tests are red. Reverted `cmp`-identical.
  - Code review, each on its own: `lineOf` read from the template instead of the file: `a use is reported at its line in the file, not at its line in the template` the one red. A `[class]` binding exempt when any prefix is declared: `a [class] binding with no literal name needs a declared prefix in its file` the one red. The literal-name prefix exemption deleted: `a literal name under a declared prefix needs no style of its own...` the one red. No single-quoted `class`, no single-quoted `[class]`, an unquoted-only host key, or a bracket scan that reads quotes: `single-quoted attributes, a quoted host key and a closing brace inside a host string are read as written` the one red in each of the four.
  - Reverted: `client-lint.test.mjs` 82 of 82, `npm run test:tools` 2142 of 2142.
- (QA) Four tests added to an existing file, no new file: `ui/tools/client-lint.test.mjs` (82 to 86): the composed-prefix roster, the whole-name hook reader, `.html` collection by `lintClient`, and the `*.spec.ts` and `src/app/testing/` exclusion. Each builds its own scratch tree and removes it.
- `mutation:` (DW-1188, QA, `node --test`; run on a scratch mirror of `ui/` with `tools/client-lint.mjs` mutated, so the real tree was never edited and `git status` read the same before and after). 69 mutations of family 7 and its lists, 5 green before the new tests, all red after:
  - `ocu-reply-heading-` dropped from `COMPOSED_CLASS_PREFIXES`: the roster test the one red; `ocu-banner-` dropped: both real-tree tests and the roster test red.
  - `CLASS_REFERENCE_RE` without its lookbehind: the whole-name reader test the one red.
  - `.html` not collected in `lintClient`: the `.html` test the one red. A `*.spec.ts` collected as a template, or `src/app/testing/`: the exclusion test the one red in each.
  - Re-run, recorded: `ocu-copy-status` removed (the CLI names `src/app/shell/copy-control.ts:19`), `ocu-banner` added to group A, `ocu-auditing-page` and `ocu-guardrails-tools` re-added to their templates: both real-tree tests red in each. The four quote variants and the unread `[class]` literals of the code-review line: the one quote test red in each of the four, and three tests red for the literals.
- (QA) Red first, no visual change and the wiring, observed on the scratch mirror (DW-1188):
  - The 27 templates restored to `0c62d06a` under the new family: 49 violations over 44 names, equal to the 44 removed tokens, no stale entry; both real-tree tests red.
  - The 44 tokens as whole tokens in `ui/src`, `ui/browser` and `ui/tools`, and in the rest of the repository: three hits, all an id or a `name` (`ocu-log-hub-source`, `ocu-ecp-settings-ssl`, `ocu-oauth-server-metadata`), none a class context. No `[class*=]` selector, no `&-` nesting, and no `#{}` in a selector builds a class.
  - `npm run build` in the mirror with `ocu-not-styled` added to `typed-name-dialog.ts`: it stops at `client-lint` with `src/app/shell/typed-name-dialog.ts:54: [no-unstyled-template-class]`, exit 1, the later checkers and `ng build` never run. The unmodified mirror runs `npm run prebuild` through all seven checkers, exit 0.
- `mutation:` (DW-1188, code review, `node --test tools/client-lint.test.mjs` on a scratch mirror of `ui/`, each restored, the mirror's `client-lint.mjs` `cmp`-identical to the tree's, 86 of 86 after): a literal name under a declared prefix exempt in any file: the literal-name test the one red, on its other-file leg. The builder check without `{{`: the composed-prefix test the one red. A `*.spec.ts` or `src/app/testing/` file's `styles:` counted as styled: the collection test the one red. The owed group exempt from the styled check: the styled-stale test the one red.
- **Batch 4, measured at `5efc7e29`:** 209 built routes. Of 161 screens of their own rows (Home among them), 99 take `entityId` and 62 do not. Of 48 parent-scoped screens, 41 take `parentId` (33 as before, 8 newly) and 7 do not: the four item tabs and the items' `settings`, `document` and `test`, whose parent id has two parts. Before the change 37 parent-scoped screens took an `entityId`. The spec's four counts reproduce.
- (Shared surfaces, batch 4) The two probes that mirror `Navigate.Directive`'s signature, `Test/LedgerClientTool/Probe` and `Test/ClientCallFault/Probe`, gain the trailing `pParentId`, since `ResolveClientCall` now passes it positionally. No other test asserts the old shape: the other `Directive` callers send no `entityId`, and the roster tests name the tool only. `ui/src/app/core/citations.ts`'s comment now says its function mirrors `IdShapeAccepted`, the id-shape half of `AcceptsEntityId`.
- `mutation:` (DW-1462, `ocupilot-ci`, every mutated class and each descendant recompiled, each reverted byte-identical and the tree re-checked):
  - The four production files at their pre-batch text: `ToolNavigate` red 3 of 23 (the sweep, the none-id `detail.argument`, the schema count; run 10) and `ToolNavigateParent` red 7 of 7 (run 11).
  - `AcceptsEntityId` without its `ParentScope` clause: the sweep the one red in `ToolNavigate` (run 12); `ToolNavigateParent` red 3 of 7 (run 13).
  - `AcceptsParentId` reading the screen's own id shape: the sweep red (run 14); `ToolNavigateParent` red on the composite-parent and task-history pins (run 15).
  - `RefusalFault` without `detail.argument`: `ToolNavigate` red 2 of 23 (run 16); `ToolNavigateParent` red 4 of 7 (run 17).
  - `SettleClient` without the `parentId` echo: `ToolNavigateParent` red on the echo and the turn (run 18).
  - `Loop` handing `GuardedRequest` `tEntityId` in place of the route's id: the turn test the one red (run 19). The settled detail always naming `entityId`: the turn test the one red (run 20). `ResolveClientCall` answering no parent id: the turn test the one red (run 21).
  - `InputSchema` without `parentId`: `ToolNavigate`'s schema test the one red (run 22), and the turn test (run 23), since the argument validation refuses the call.
  - `REASONNAVENTITYNOTALLOWED` at its old sentence: the refused-turn test the one red (run 24).
  - `task-resume.browser-spec.mjs` sending `entityId` in place of `parentId`: its first test red on the 30 s wait for the URL, the other two green. Reverted.
  - Reverted: `ToolNavigate` 23 of 23, `ToolNavigateParent` 9 of 9, `TurnNavigate` 15 of 15, `ToolRoundTrip` 2 of 2, `ToolDispatchClientFault` 3 of 3, `LedgerClientRows` 3 of 3, confirmed in `%UnitTest_Result`; `task-resume.browser-spec.mjs` 3 of 3 and `navigate.browser-spec.mjs` 6 of 6 against the rebuilt bundle; `npm run test:tools` 2146 of 2146; `check-objectscript.py` 0 problems.
- `mutation:` (DW-1462, review pass, `ocupilot-ci`, the mutated class and its subclasses recompiled, each reverted `cmp`-identical):
  - `AcceptsParentId` answering 1 for a screen with no parent scope: `TestAScreenWithNoParentRefusesParentId` the one red in `ToolNavigateParent` (run 40) and the sweep the one red in `ToolNavigate` (run 42).
  - `ResultSchema` without `parentId`: `TestSettledResultEmitsOnlyDeclaredKeysWithDeclaredTypes` the one red (run 43).
  - `InputSchema` `parentId` `maxLength` 255: `TestTheSchemaAdmitsCriterionAndNothingElse` the one red (run 44).
  - `Loop` appending the announce step with `tEntityId` in place of the route's id: the new `TestTheAnnouncementCarriesTheParentIdWhileTheBrowserWaits` the one red, and `TestAParentIdTurnStoresTheRouteIdAndSettlesWithParentId` stays green because the settle rewrites the text (run 45).
  - `Loop`'s dropped detail naming `entityId`: the new `TestADroppedAnnouncementNamesTheParentInTheLapse` the one red (run 46).
  - Reverted: `ToolNavigate` 23 of 23 (run 47), `ToolNavigateParent` 9 of 9 (run 48), `TurnNavigate` 15 of 15, `ToolRoundTrip` 2 of 2.
- (QA) Batch 4, new file `src/OcuPilot/Test/ToolNavigateContract.cls` (3 tests, unarmed, reads only): the eight screens newly openable for their parent and the seven whose parent id is two parts, each as a written-out roster, and the ruled model-read texts and refusal sentence through `Dispatch.Advertise`. In `src/OcuPilot/Test/ToolNavigateParent.cls` (9 to 15 tests): the refused and opened turn bodies became `RefusedTurn` and `OpenedTurn`, and six tests were added: `parentId` on a screen with no parent and a composed two-part id on an item tab as `entityId` and as `parentId`, each refused before any announcement; an own-row turn; a parent call the browser refuses and one whose wait lapses (`SettledTurn`).
- `mutation:` (DW-1462, QA, `ocupilot-ci`, applied to the instance's source mount only so the repo tree was never written, the mutated class and every descendant recompiled, each reverted and the mount `diff -r`-identical to `src/`):
  - Ruled texts (U-7): `DESCRIPTION` reworded by one word: `TestTheModelReadTextsAreTheRuledWording` the one red, on the class and advertised descriptions (run 296). `entityId`'s, `parentId`'s and the result `parentId` text and `REASONNAVENTITYNOTALLOWED`, each reworded: the same test red on seven assertions, one per text (run 297).
  - Rosters: `interoperability/lookup-tables` declared with a two-part id: `ToolNavigate` stays 23 of 23 because its partition is derived (run 299), and `TestTheEightScreensOpenableForTheirParentTakeParentId` is the one red, on `interoperability/lookup-tables/entries` (run 300). `AcceptsEntityId` without its `ParentScope` clause: `TestTheSevenScreensWhoseParentIdIsTwoPartsRefuseBothArguments` the one red in `ToolNavigateContract`, on the four item tabs (run 301); `ToolNavigateParent` red on the composed-`entityId` turn and three more (run 302).
  - Composed `parentId` on an item tab: `AcceptsParentId` reading the screen's own id shape: `ToolNavigateParent` red on the composed-`parentId` turn, the composite-parent pin and the task-history pin (run 303), and the `ToolNavigate` sweep (run 304).
  - Refused before any announcement, for `parentId`: the `parentId` refusal built with argument `entityId`: the two new `parentId` turns red on the argument the model is told, beside the two `Directive` pins (run 305).
  - Own row unchanged: `GuardedRequest` handed `$Get(tParentId)` in place of the route's id: `TurnNavigate` stays 15 of 15 (run 306), and `TestAnOwnRowTurnStillStoresTheRowAndSettlesWithEntityId` is the one red (run 307).
  - Settled and lapsed, for `parentId`: `SettleClient` echoing `parentId` for an opened outcome only: the browser-refused and wait-lapse tests and the dropped test red (run 308). The settle's `GuardedUpdate` given `tEntityId`: the two settle tests and the opened parent turn red, on the announce step's kept id (run 309).
  - Recorded mutations re-run against the refactored tests, each red as recorded: 13 (run 302), 15 (run 303), 14 (run 304), 17 (run 316), 16 (run 317), 19, 20 and 21 (runs 310, 311, 312, the two settle tests now also red), 24 (run 313, the four refused turns), 45 and 46 (runs 314, 315, each the one red). Not re-run: 10, 11, the `ToolNavigate` half of 12, 18, 22, 23 and 40 to 44.
  - End to end: `AcceptsParentId` answering 0, against the rebuilt bundle: `task-resume.browser-spec.mjs` red on its first test (the URL wait, 37.9 s), the other two green.
  - Reverted: `ToolNavigate` 23 of 23 (run 318), `ToolNavigateParent` 15 of 15 (runs 319 and 323), `ToolNavigateContract` 3 of 3 (run 320), `TurnNavigate` 15 of 15 (run 321), `ToolRoundTrip` 2 of 2 (run 322), confirmed in `%UnitTest_Result`; `task-resume.browser-spec.mjs` 3 of 3 and `navigate.browser-spec.mjs` 6 of 6; `npm run test:tools` 2146 of 2146; `check-objectscript.py` 0 problems.
- `mutation:` (DW-1462, code review, `ocupilot-ci`, on the source mount only, every class recompiled by `LoadDir`, reverted `diff -r`-identical to `src/`): `Loop`'s `parentId` branch keying the detail `entityId`: `ToolNavigateParent` red 4 of 15, on the opened, browser-refused, lapsed and dropped `parentId` turns (run 329). Reverted, after the review patches: `ToolNavigateParent` 15 of 15 on `TurnToolsCase` (runs 324, 330), `ToolNavigate` 23 of 23 with Home in the sweep (62 own-row refusals, run 325), `ToolNavigateContract` 3 of 3 (326), `TurnNavigate` 15 of 15 (327), `ToolRoundTrip` 2 of 2 (328), `ToolDispatchClientFault` 3 of 3 (331), `LedgerClientRows` 3 of 3 (332), confirmed in `^UnitTest.Result`; `task-resume.browser-spec.mjs` 3 of 3 and `navigate.browser-spec.mjs` 6 of 6 on the rebuilt bundle; `npm run test:tools` 2146 of 2146; `check-objectscript.py` 0 problems. Ledger rows naming `parentId` read 142 before and after a 15-test `ToolNavigateParent` run.
- **Batch 5, equal totals.** The 19 classes read 131 tests, 0 failed, before the edit (the lead's run) and after it (runs 20-38): SuperserverWrite 9, SuperserverGate 3, SuperserverRead 5, SuperserverProhibited 6, SuperserverDescriptor 7; MftConnectionWrite 9, MftConnectionGate 3, MftConnectionRead 4, MftConnectionDescriptor 8; DocDbAppWrite 11, DocDbAppGate 3, DocDbAppRead 5, DocDbAppDescriptor 11; RoutineAppWrite 15, RoutineAppGate 6, RoutineAppRead 4, RoutineAppMembers 7, RoutineAppDescriptor 13; SaveHoldCoverage 2. `SaveHoldCoverage` resolves each route's handler to `ScreenSave.HandleCreate` and `HandleUpdate` (`CompiledMethod.Origin`). `npm run test:tools` 2146 of 2146, `check-objectscript.py` 0 problems, `ipm-manifest.mjs --check` up to date.
- `mutation:` (DW-2278, `ocupilot-ci`, applied to the instance's source mount only, `ScreenSave` and each Save and fixture descendant recompiled, each reverted `diff -r`-identical to `src/`):
  - `ScreenSave.Prohibited` answers `$$$OK` always: `SuperserverProhibited` red 2 of 6 (run 39). `MftConnectionWrite` 9 of 9, `DocDbAppWrite` 11 of 11 and `RoutineAppWrite` 15 of 15 stay green (runs 40-42): AD-10's set names no refusal for an MFT connection or a Doc DB application, and a routine application's own-application refusal is the port's as well.
  - `HandleUpdate` without `Release`: `SaveHoldCoverage` red 1 of 2, on the four `PUT` routes, each resolved to `ScreenSave.HandleUpdate` (run 43).
  - The default `Merge` skipping the problem `Check`: `MftConnectionWrite.TestEveryRulesRowIsRefusedBeforeAnyPutOnBothCallers` (run 44), `DocDbAppWrite.TestEveryChangeRuleIsRefusedBeforeAnyPutOnBothCallers` (run 45) and `RoutineAppWrite.TestEveryChangeRuleIsRefusedBeforeAnyPutOnBothCallers` (run 46), each the one red.
  - The hooks: `SuperserverSave.Consequence` empty: `SuperserverWrite.TestAProbeOnTheServingPortIsRefusedTheSameFourChanges` the one red (run 47). Its `Merge` calling `MergeUpdate` in place of `MergeRaw`: that test and `TestTheRulesThatReadTheSuperserverRefuseAChange` red (run 48). Its `CheckMerged` 0: `TestTheRulesThatReadTheSuperserverRefuseAChange` the one red (run 49). Its `TakenField` `Name`: `TestATakenNameAMovedTargetAndABusyTargetAreRefused` the one red (run 50). `DocDbAppSave.UpdateArguments` as `CallerFields`: `TestTheWriteRoutesAnswerOverTheWire` the one red in `DocDbAppWrite` and in `RoutineAppWrite` (runs 51, 52). `DocDbAppSave.CreateIdentity` answering the name alone as the id: `SaveHoldCoverage.TestACreateSaveHoldsTheKeyItsMintComputes` red on its `/docdb-application` leg (run 53). `ScreenSave.Gate` passing every caller: the two `TestWithout...` tests red in each of `SuperserverGate`, `MftConnectionGate`, `DocDbAppGate` and `RoutineAppGate` (runs 54-57).
  - Reverted: the 19 classes green, 131 tests, runs 58-76.
- `mutation:` (DW-2278, review pass, `ocupilot-ci`, source mount only, every class recompiled by `LoadDir`, each reverted and the mount `diff -r`-identical to `src/`):
  - `SuperserverSave.CreateIdentity` not reading a numeric port: `SuperserverWrite.TestACreateSendsOnlyTheSuppliedSettingsOnBothCallers` the one red, on its numeric-port leg (run 99).
  - `MftConnectionSave.CreateIdentity` without its shape violation: `MftConnectionWrite.TestEveryRulesRowIsRefusedBeforeAnyPutOnBothCallers` the one red, on the non-text name leg (run 100). `DocDbAppSave.CreateIdentity` likewise: `DocDbAppWrite.TestEveryCreateRuleIsRefusedBeforeAnyPutOnBothCallers` the one red, on the non-text namespace leg (run 101).
  - `ScreenSave.UpdateArguments` passing the body as it is: `SuperserverWrite.TestAChangeSendsTheCompleteSetLessSystemDefaultOnBothCallers` (run 111) and `MftConnectionWrite.TestAChangeSendsTheFreshFiveFieldsOnBothCallers` (run 112), each the one red in its class.
  - The mutations the six re-pointed test headers name, now run against `ScreenSave`: `Gate` refusing every caller reddens `TestTheDeclaredPairsReadAndWrite` in `SuperserverGate`, `MftConnectionGate` and `DocDbAppGate` (runs 102-104). `HandleUpdate` without `HoldTool` reddens `TestATakenNameAMovedTargetAndABusyTargetAreRefused`, the one red in `SuperserverWrite` and in `MftConnectionWrite` (runs 105, 106). `HandleUpdate` not decoding the id reddens `SuperserverWrite.TestTheWriteRoutesAnswerOverTheWire` among six (run 107).
  - Reverted: the 19 classes green, 131 tests, runs 113-131.
- (QA) Batch 5, eight new files under `src/OcuPilot/Test/`, no existing file edited, nothing armed: `ScreenSaveOrder.cls` (14 tests, `%UnitTest.TestCase`) pins the order, the hold lifecycle and the defaults of `ScreenSave` through the MFT Save over an in-memory port, reading a step trace that marks each step held or not from the lock table; its helpers `ScreenSaveOrderFixture`, `ScreenSaveOrderRules`, `ScreenSaveMemoryPort`, `ScreenSaveSet`, `ScreenSaveMftCreate`, `ScreenSaveMftUpdate` and `ScreenSaveTrace` carry no `Test*` method. It creates no instance object and keeps its state in process-private globals. No list leg was added for `RoutineAppSave.SaveFields`: `RoutineAppMembers.TestTheGeneralSaveRefusesAListAndKeepsBoth` already pins it over the wire.
- `mutation:` (DW-2278, QA, `ocupilot-ci`, source mount only so the repo tree was never written, `ScreenSave`, `ScreenSaveRules` and their 13 descendants recompiled, each reverted `diff -r`-identical to `src/`). Gaps the existing classes missed, each green on the named class and red in `ScreenSaveOrder`:
  - A create without AD-10's call (`Create`): `ScreenSaveOrder` red 3 of 14, `TestTheProhibitedSetIsAskedOfACreateAndAnEditBeforeTheWrite` among them (run 834); `MftConnectionWrite`, `SuperserverWrite`, `DocDbAppWrite`, `RoutineAppWrite` and `SuperserverProhibited` green (runs 835-839). The edit's call dropped: that test red among 3 (run 890).
  - The hold taken before a create's shape answer: `TestAnIdentityThatNamesNoTargetIsAnsweredBeforeTheHold` the one red (run 840), `MftConnectionWrite` green (841); the edit's equivalent, the hold taken before the whole-target answer: the same test the one red (run 843).
  - A create's hold released before `Answer`: `TestACreateRunsItsStepsInOrderWithTheHoldKeptThroughTheAnswer` among 6 red (run 845), `SaveHoldCoverage` green (846). An edit's hold released only on the path that reaches `Answer`: `TestAnEditOfAnAbsentTargetIsNotFoundAfterTheFreshRead` among 8 red, the lock left held (run 844).
  - The rules before the unexpected keys, in `Create` and `Update`: `TestAnUnexpectedKeyIsRefusedBeforeTheRulesOnBothRoutes` among 10 red (run 847), `MftConnectionWrite` green (848). The name looked up whatever the rules found: `TestTheRulesAreAskedBeforeAnyStateRead` the one red (849), `MftConnectionWrite` green (850). The fresh read before the edit's rules: that test among 7 red (851), `MftConnectionWrite` green (852).
  - A create read back after a failed write: `TestAFailedWriteAnswers500AndStillReleasesTheHold` the one red (run 857). The effect asked before AD-10's set in `Update`: `TestAnEditRunsItsStepsInOrderWithTheHoldKeptThroughTheAnswer` among 3 red (858). The not-an-object test of the fresh read dropped: green until the `emptyread` leg was added (run 888), then `TestAnEditOfAnAbsentTargetIsNotFoundAfterTheFreshRead` the one red (889).
  - Also red in `ScreenSaveOrder`: the body read before the gate (13 of 14, `TestAGateRefusalIsAnsweredBeforeTheBodyIsRead` among them, run 832) and the identity before the body (12 of 14, `TestABodyThatIsNotAnObjectIsRefusedBeforeTheIdentity` among them, 833), each in both handlers; the taken look-up dropped (887); the no-change exit dropped (886, `TestAnEditThatChangesNothingStopsAfterTheMerge` the one red); the default `Merge` without the rules' second reading (853, `TestAMergeProblemIsA400UnlessARuleExplainsIt` the one red); `ScreenSaveRules.RenderViolations` ignoring `ERRORCLASS` (865, `TestAnIdentityThatNamesNoTargetIsAnsweredBeforeTheHold` the one red); `DocDbAppSave` overriding `ProhibitedClass` (854, `TestTheFourSavesShareTheKernelTemplate` the one red, on `DocDbAppSave` and `RoutineAppSave`).
  - Re-run of the recorded mutations on the refactored tree, each red as recorded: `ScreenSave.Prohibited` permitting always: `SuperserverProhibited` red 2 of 6 (861) and `ScreenSaveOrder` 4 (862); `HandleUpdate` without `Release`: `SaveHoldCoverage` red 1 of 2, on the four `PUT` routes (863); the default `Merge` skipping the problem `Check`: `MftConnectionWrite.TestEveryRulesRowIsRefusedBeforeAnyPutOnBothCallers` the one red (864).
  - Reverted: `ScreenSaveOrder` 14 of 14 (run 891), the 19 classes green, 131 tests (runs 867-885, in `%UnitTest_Result`), `npm run test:tools` 2146 of 2146, `check-objectscript.py` 0 problems.
- `mutation:` (DW-2278, code review, `ocupilot-ci`, source mount only, each class recompiled with its subclasses, each reverted and the mount `diff -r`-identical to `src/`):
  - The base `RulesCheck` and `RulesTaken` answering no violations and not taken: `MftConnectionWrite` red 3 of 9, its rules, taken and look-up legs (run 895); `SuperserverWrite` red 1 of 9, `TestATakenNameAMovedTargetAndABusyTargetAreRefused` (896).
  - The hold released as the last statement inside each handler's `Try`: `ScreenSaveOrder.TestAnExceptionAfterTheHoldIsAnswered500AndReleasesIt` red, and the lock it leaves held reddens the five tests run after it (897); `SaveHoldCoverage` green (898).
  - AD-10's set asked before the rules judge the merged payload: `ScreenSaveOrder.TestTheMergedPayloadIsJudgedBeforeTheProhibitedSet` the one red (899); `SuperserverWrite` green (900).
  - `SuperserverSave` with its own `Body`, and `RoutineAppCreate` on `DocDbAppPort`: `ScreenSaveOrder.TestTheFourSavesShareTheKernelTemplate` the one red, on both (901).
  - `ScreenSaveRules.RenderViolations` under MFT's `VALIDATION`: `SuperserverWrite.TestEveryRulesRowIsRefusedBeforeAnyPutOnBothCallers` the one red, on every leg's envelope code (903; 902 was a mutation that broke the envelope, discarded).
  - `ScreenSaveRules.Gate` passing every caller: the form-read leg red in `SuperserverGate`, `MftConnectionGate` and `DocDbAppGate` (904-906).
  - Equal behavior: head's `SuperserverWrite` 9 of 9, `MftConnectionWrite` 9 of 9 and `DocDbAppWrite` 11 of 11, the review legs and the envelope-code assertion included, against `60bceb23`'s three Saves and Rules (907-909).
  - After the review patches: the 19 classes green, 131 tests, and `ScreenSaveOrder` 16 of 16 (runs 910-929, in `%UnitTest_Result`); `npm run test:tools` 2146 of 2146; `check-objectscript.py` 0 problems; `ipm-manifest.mjs --check` up to date.

## Auto Run Result

Status: done
Blocking condition: none

**Batch 5 (shared Save), this pass only.** Batches 1-4 closed in their own passes.

- **Implemented.** DW-2278: `Kernel/Proposal/ScreenSave` and `ScreenSaveRules` carry the shared Save shape; `SuperserverSave`, `MftConnectionSave` and `DocDbAppSave` (and `RoutineAppSave` through it) keep only their parameters and hooks, and the three Rules classes extend `ScreenSaveRules` (Superserver and MFT gain `ERRORCLASS`). Wire statuses, codes and bodies are unchanged. The client forms are untouched.
- **Decided in-stage.** The base adds four hooks the task list does not name: `IdentityMembers`, `TakenField`, `Subject` (each replaced a per-Save difference) and `CheckMerged` (Superserver's post-merge `Check`). `Create` and `Update` now take `(pId, pParts, ...)`; nothing but `HandleCreate` and `HandleUpdate` calls them.
- **Files.** New `Kernel/Proposal/ScreenSave.cls` (455 lines) and `ScreenSaveRules.cls` (65). The three Saves shrink from 332-390 lines to 58-123; each Rules class loses five methods. Six test headers point at the moved methods, and `SuperserverWrite`, `MftConnectionWrite` and `DocDbAppWrite` gain four legs (numeric port, non-text name, non-text namespace, id members repeated in a change body). This spec.
- **Review.** 17 findings from two layers (low 9, false 8): 4 patched (the four legs above, plus the recorded runs of six header mutations), 13 rejected with their reasons in the Triage Log. Deferred: none.
- **Follow-up review recommended: false.** Only lows were patched, each with its mutation observed red.
- **Verification.** Load 0 errors. The 19 classes read 131 tests, 0 failed, before the edit and after it, and again after the review patches (runs 113-131). `npm run test:tools` 2146 of 2146, `check-objectscript.py` 0 problems, `ipm-manifest.mjs --check` up to date, `lint-docs.sh` clean.
- **Residual risk.** The full ObjectScript sweep and the full browser suite are not run here; they belong to the lead and to CI. The 25-35 other `Area/*Save.cls` copies stay filing candidate 1. The handoff pass read the spine selectively (AD-52 to AD-58); AD-10 and AD-34 were checked in review against the unchanged order and the hold's span.
