---
title: 'Story 23.8: The range-end cleanup, part 7'
type: 'bugfix'
created: '2026-10-21'
status: 'done'
baseline_revision: 'e2459b1e6fdb05d1c54ec8fcffb3dcefeae4c004'
baseline_commit: 'e2459b1e6fdb05d1c54ec8fcffb3dcefeae4c004'
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

- [ ] **DW-1188.** In `ui/tools/client-lint.mjs`, add family 7, `checkTemplateClasses({templates, stylesheets, references})`, after :577. Rule names: `no-unstyled-template-class` and `stale-unstyled-class-hook`.
  - **Used names:** the five class sources in the Code Map. **Styled names:** every `.ocu-x` in a selector of `src/**/*.scss` or a component `styles:`.
  - **The violation.** A used name fails unless it is styled, allow-listed, or carries a declared composed prefix. It is reported at each use site.
  - **`UNSTYLED_CLASS_HOOKS`:** a literal, sorted, exported list in two groups, with a one-line reason per group: the 90 test hooks, and the 4 owed a style (both in Design Notes).
  - **`COMPOSED_CLASS_PREFIXES`:** `ocu-banner-` (`list-page.ts`) and `ocu-reply-heading-` (`core/reply.ts`). Each needs at least one styled `prefix*` selector. A non-literal class binding with an `ocu-` fragment in any other file fails.
  - **Stale entries fail.** An allow-listed name fails when it is styled or unused. A hook-group name also fails when no `browser/` or `*.spec.ts` file references it. The unused and unreferenced checks run only when the root has `src/styles/`, so the CLI scratch trees stay quiet.
  - Ids are never read, because only class contexts are parsed.
  - Collect the files during the existing walk, and judge after the loop. Add family 7 to `RULE_FAMILIES`, and correct the header's family count to seven.
- [ ] **DW-1188.** `ui/tools/client-lint.test.mjs`, in the existing style:
  - Fixture tests of each extractor and of each rule, including stale and composed.
  - `id="ocu-x"` produces nothing.
  - `RULE_FAMILIES` includes it.
  - A CLI scratch tree with `class="ocu-not-styled"` exits 1 naming the file.
  - The real-tree clean run stays green.
- [ ] **DW-1188.** Remove the 44 dead tokens listed under Design Notes from their templates under `ui/src/app/`. Before removing each, grep `ui/src`, `ui/browser` and `ui/tools` for it: a token with any reader is kept and allow-listed instead. No visual change: none of the 44 is in any selector.

### Batch 4: navigation contract

- [ ] **DW-1462.** `src/OcuPilot/Screen/Tool/Navigate.cls`:
  - Split `AcceptsEntityId`'s body into `IdShapeAccepted(pDescriptor)` (`single`, or `composite` of one part). `AcceptsEntityId` = `ParentScope() = ""` and `IdShapeAccepted`.
  - New `AcceptsParentId` = `ParentScope() '= ""` and `IdShapeAccepted(DescriptorForRoute(ParentScope()))`.
  - `InputSchema` gains `parentId` (string, `maxLength` 256). `entityId` and `DESCRIPTION` are reworded (Wording).
  - `Directive` reads `parentId` as it reads `entityId`, and refuses `NAV.ENTITYNOTALLOWED` for an argument the screen does not accept. `RefusalFault` gains an optional `detail.argument` naming it.
  - `Directive` gains a trailing `Output pParentId`.
  - `ResultSchema` gains `parentId`.
  - The class header's composite paragraph covers both arguments.
- [ ] **DW-1462.** Thread `parentId` through the dispatcher and the turn:
  - `Kernel/Agent/Dispatch.cls`: `ResolveClientCall` gets a trailing `Output pParentId` from `Directive`. `SettleClient` emits `parentId` when the detail carries it.
  - `Kernel/Agent/Loop.cls`: take `tParentId`. The announce target and `Nav.GuardedRequest` get the route's id, `$Select(tEntityId '= "": tEntityId, 1: tParentId)`. The dropped and settled details carry `parentId` instead of `entityId` when it is set.
  - `Kernel/State/Nav.cls`: doc only. `EntityId` holds the route's id: the selected row's, or the parent's on a parent-scoped screen.
- [ ] **DW-1462.** `src/OcuPilot/Api/Error.cls` :1048: `REASONNAVENTITYNOTALLOWED` takes the sentence under Wording.
- [ ] **DW-1462.** `src/OcuPilot/Test/ToolNavigate.cls`:
  - Rewrite the sweep (:94-138) to the two-way partition, derived from the declarations. For every built route, `entityId` "1" is accepted exactly when `AcceptsEntityId`'s rule says so, and `parentId` "1" exactly when the parent's id shape says so. Each half has a floor above 0.
  - Rewrite the header's parent-scoped paragraph.
  - `TestTheSchemaAdmitsCriterionAndNothingElse` expects five names.
- [ ] **DW-1462.** Create `src/OcuPilot/Test/ToolNavigateParent.cls` (unarmed), with literal pins:
  - `tasks/schedule/details` takes `parentId` and refuses `entityId`, with `detail.argument`.
  - `tasks/schedule` refuses `parentId`.
  - `interoperability/productions/items/jobs` refuses both.
  - `tasks/schedule/history` takes `parentId`.
  - `SettleClient` echoes `parentId`.
  - A turn through `TurnLoopProbe`, in `TurnNavigate`'s pattern, whose scripted call names `parentId` stores the route's id on the Nav row and settles with `parentId`.
- [ ] **DW-1462.** `ui/browser/task-resume.browser-spec.mjs:228`: `entityId` becomes `parentId`.

### Batch 5: shared Save

- [ ] **DW-2278.** Create `src/OcuPilot/Kernel/Proposal/ScreenSave.cls` [Abstract], lifting `DocDbAppSave`'s generalized shape.
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
- [ ] **DW-2278.** Create `src/OcuPilot/Kernel/Proposal/ScreenSaveRules.cls` [Abstract]: `RenderRead`, `Gate`, `Text`, `Add`, and `RenderViolations` through `ERRORCLASS`.
- [ ] **DW-2278.** `SuperserverSave`, `MftConnectionSave` and `DocDbAppSave` extend `ScreenSave` and keep only their hooks and parameters. Their Rules classes extend `ScreenSaveRules`, and Superserver and MFT gain `ERRORCLASS`. `RoutineAppSave` and `RoutineAppRules` inherit through Doc DB unchanged.
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
- `mutation:` (DW-1188):
  - Remove one group-A name from `UNSTYLED_CLASS_HOOKS` → the real-tree clean run red, naming its sites.
  - Add a styled name to the list → the stale rule red.
- `mutation:` (DW-1462):
  - `AcceptsEntityId` without its `ParentScope` clause → the sweep red on the 37 parent-scoped routes.
  - `AcceptsParentId` reading the screen's own id shape → red on the 4 item tabs and the 8 newly openable.
  - `SettleClient` without the `parentId` echo → `ToolNavigateParent` red.
- `mutation:` (DW-2278):
  - `ScreenSave.Prohibited` answers `$$$OK` always → the prohibited legs of SuperserverProhibited, MftConnectionWrite and DocDbAppWrite red.
  - `HandleUpdate` without `Release` → SaveHoldCoverage red.
  - The default merge skipping the problem `Check` → MftConnectionWrite and DocDbAppWrite red.

## Auto Run Result

Status: done
Blocking condition: none

**Batch 2 (scripts, install and container), this pass only.** Batches 3 to 5 are untouched and unchecked; batch 1 closed in its own pass.

- **Implemented.**
  - DW-235: both throwaway scripts normalize `--dir` (trailing slashes off), refuse `//`, `/./` and a trailing `/.`, and refuse a symbolic link; `ci-throwaway.sh` also refuses a link at `$DIR/data` and reads `TMPDIR` as an absolute, slash-stripped root.
  - DW-1762: `stop_grace_period: 60s` on the `iris` service in the throwaway here-doc and in `docker-compose.yml`.
  - DW-432: the runner's class-level line names an arming variable it finds in the record and says only `scripts/ci-throwaway.sh` sets it; `docs/DEVELOPMENT.md` carries the Armed test classes paragraph.
  - DW-216: the own-web-server constraint is documented in `Smoke.cls` (header, `Host()`, `Port()`), `docs/DEVELOPMENT.md` and the `README.md` smoke bullet.
- **Files.**
  - `scripts/ci-throwaway.sh`, `scripts/ci-ipm-archive.sh`, `docker-compose.yml`, `src/OcuPilot/Install/Smoke.cls` (doc comments only), `docs/DEVELOPMENT.md`, `README.md`, `ui/tools/ci-runner.mjs`.
  - Tests: `ui/tools/ci.test.mjs`, `ui/tools/ipm-archive.test.mjs`, `ui/tools/compose.test.mjs`. No new file.
- **Review.** 14 findings from two layers (low 9, false 5): 3 low patched, 11 rejected (see the Triage Log). Patched: the relative-`TMPDIR` leg, the trailing-slash link legs that pin the strip (the recorded no-strip mutation for `ci-ipm-archive.sh` had not reproduced), and a run-made name for the admitted `/tmp` legs. Deferred: none.
- **In-stage decisions (Design Notes).** The hint reads the record's `error` as well as its `action`; the link line names the path it found; the paragraph's lead carries the "Armed test classes" label the hint cites.
- **Follow-up review recommended: false.** Only low entries were patched, and each patch has its mutation observed red.
- **Verification.**
  - `ocupilot-ci`: `Smoke.cls` loaded with 0 errors, `OcuPilot.Test.Smoke` 43 of 43 (handoff run 1).
  - `npm run test:tools` 2119 of 2119 with neither browser variable set; `ci.test.mjs` 91 of 91, `ipm-archive.test.mjs` 33 of 33.
  - `bash scripts/lint-docs.sh`: 0 issues. `check-objectscript.py` on `Smoke.cls`: 0 problems.
  - Every mutation under Verification was reverted and the tree re-checked byte-identical.
- **For the lead.** `docker-compose.yml` is a release-upgrade trigger. The DW-1762 restart measurement waits for the next `up` of `ocupilot-ci`; the slot instances' own compose files, outside this repository, take the key only when the owner adds it.

**Batch 2 CI rework 1 (run 39738366345), this pass only.**

- **Implemented.** The DW-235 test in `ui/tools/ipm-archive.test.mjs` makes its root with `mkdtempSync` under `os.homedir()`, which no fixed `/tmp/?*` or `/private/tmp/?*` arm admits; it is still passed as `TMPDIR` and removed in a `finally`, and an assertion fails if the root lands under those arms. Both scripts are unchanged. `ci.test.mjs` is unchanged: its refusal legs use literal `/nonexistent-*` and `/tmp//` spellings, and its link legs only need admitting, which the `$TMPDIR` arm does where `TMPDIR` is set and the `/tmp/?*` arm where it is not.
- **Files.** `ui/tools/ipm-archive.test.mjs`; this spec (the `[CI]` box, the baseline, one `mutation:` line).
- **Review.** 7 findings from two layers (low 6, false 1): none patched, none deferred (see the Triage Log).
- **Follow-up review recommended: false.** Nothing was patched.
- **Verification.**
  - Red before: the previous test under `TMPDIR=/tmp` fails at the `${scratch}//` leg ("was not refused"). Green after: `ipm-archive.test.mjs` 33 of 33 under the default environment and under `TMPDIR=/tmp`; with `ci.test.mjs`, 125 of 125 under both.
  - `npm run test:tools` 2120 of 2120 with neither browser variable set; `bash scripts/lint-docs.sh` 0 issues.
  - Mutations (the two on `scripts/ci-ipm-archive.sh` re-run here under both environments): the `$TMPDIR` arm without its separator and the `$DIR` strip deleted each went red, and each was reverted byte-identical.
  - `/tmp` and `$HOME` listings equal before and after.
