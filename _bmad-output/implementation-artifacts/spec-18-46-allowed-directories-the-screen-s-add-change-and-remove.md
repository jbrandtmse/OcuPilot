---
title: 'Story 18.46: Allowed directories: the screen''s add, change and remove'
type: 'feature'
created: '2026-10-12'
status: 'done'
baseline_revision: '2d5a458a925aed1f8d711f94a60f9472d55ece37'
baseline_commit: '2d5a458a925aed1f8d711f94a60f9472d55ece37'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-18-context.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** Story 18.42 adds a person's write to the directory allow-list (`POST /allowed-directories`, governance key `security.alloweddirectories.update` shipped `false`), but the Allowed directories screen is still read-only, so nobody can reach it.

**Approach:** The screen declares Add, Change and Remove; a security-slice service runs them through the shell's confirm dialogs and 18.42's route, and a new `GET /allowed-directories` answers the key's verdict, so the actions are drawn off with the instance's sentence while it is disabled.

## Boundaries & Constraints

**Always:**

- Every sentence an off or refused action shows is the server's: the GET's `reason`, the route's envelope, or a published sentence pinned to its code (AD-39).
- An off or refused action stays focusable, `aria-disabled`, names its reason and runs nothing (EXPERIENCE.md Mechanism).
- The list re-reads through the change event alone (AD-14).
- `strings.ts`, `Router.cls`, `Registry.cls`, `ci-throwaway.sh`: add-only; EXPERIENCE.md: in place, line count unchanged.

**Never:**

- An edit to `shell/screen-outlet.ts` or the routing (Epic 20's 20.29); an area page wrapper.
- `SCREENACTIONS` on 18.42's tool, a screen-action-route path to it, or the tool in screen context `tools` (AD-53).
- An edit to `Api/ScreenAction.cls`, `Screen/Tool/Write.cls`, `Screen/Tool/Registry.cls` or `Kernel/Agent/*`.

## I/O & Edge-Case Matrix

| Scenario | State | Behavior | Error handling |
|---|---|---|---|
| Key off | GET answers `{enabled: false, code: "ALLOWLIST.OFF", reason}` | the three actions `aria-disabled` with `reason` on every surface; a click opens nothing | a refused GET: its envelope `reason` |
| Add | unrestricted (one manager row, `Restricted` false) or restricted | warning dialog with a Directory field, and the restricting or plain consequence; sends `{Action: "add", Directory}` | a refusal: the list's banner, as every warning's; nothing written |
| Change | restricted row selected | warning dialog naming it, a New directory field; sends `{Action: "change", Directory, NewDirectory}` | as above |
| Remove | restricted row selected | typed-name dialog on the directory; sends `{Action: "remove", Directory}` | as above |
| Fallback row | unrestricted row selected | Change and Remove `aria-disabled` with `ALLOWLIST.FALLBACK`'s sentence | the route refuses it too |
| Emptied | restricted, no row | the empty state says no file or directory field can choose a location | -- |
| Answered | 200 `{action, target, readBack}` | one change event for its target; list and verdict re-read | -- |

</intent-contract>

## Code Map

At `a3bb0acd`; client paths in `ui/src/app/`.

- `src/OcuPilot/Screen/Descriptor/AllowedDirectoryList.cls` :38-41, :62-63, header :15-16; `Screen/Registry.cls` `SELFPROTECTIONRULES` :2996; `ui/tools/screen-mirror.mjs` :315 (a mismatch fails the build).
- **18.42, built first (re-anchor):** `Area/Security/AllowedDirectorySave.cls` (pair and `Gate.Decide` steps), `Api/AllowListError.cls`, its route, `Screen/Tool/AllowedDirectoryUpdate.cls`, its `strings.ts` keys for `ALLOWLIST.OFF` and `.FALLBACK`, `Test/AllowedDirectorySave.cls` (arming, key store and restore).
- **Siblings (Rule 31):** `shell/warning-dialog.ts` :50-67, :132, :155; `shell/typed-name-dialog.ts` :94-115; `shell/screen-action-handler.ts` `send` :1377 (path :1398-1400), `sendFor` :1468, `startFor` :1137-1140; `shell/permission-check.ts` in `shell/screen-action-dialogs.ts` :84-86, :153-161; `rest-api-list.page.ts` :51-54.
- **Surfaces:** `core/screen-actions.ts` :157-285, :298, :324; `shell/command-bar.ts` :180-186, :491-496, :637-642, :1106; `shell/data-table.ts` :242-246, :851-859, :906, :1623; `shell/command-box.ts` :534-536, :555-566; `core/self-protection.ts` :86, :184-188 (`system-pct-access`, the row-field rule to follow).
- **Old shape pinned:** `Test/Descriptor.cls` :1158-1159; `Test/SecurityLists.cls` :62; `Test/StageTwoTools.cls` :76, `Load` :447-452, action test :304-332; `ui/browser/allowed-directories.browser-spec.mjs` :135.

## Tasks & Acceptance

**Task 0** (implement, read only, on 18.42 as landed): halt if its route's 200 is not `{action, target, readBack}`, its body keys are not `Action`, `Directory`, `NewDirectory`, or its C2b reading is not "nothing allowed", which this plan assumes (inference: `%CSP.Portal.Utils.IsDirectoryAllowed` refuses all under a restricted, empty `%GUIFileSelector`; `PathPort.Roots` answers no row).

**Execution:**

1. `Area/Security/AllowedDirectorySave.cls`: `HandleState` answers `GET /allowed-directories`: the POST's pair step (403 naming the pair), then its `Gate.Decide` step for the tool's key: 200 `{enabled: true}`, else `{enabled: false, code: "ALLOWLIST.OFF", reason}` with `AllowListError`'s sentence; a gate error is 500 `INTERNAL`. It holds and writes nothing. `Api/Router.cls`: the route and wrapper beside 18.42's.
2. `AllowedDirectoryList.cls`: `primaryAction` `add`; `rowActions` `change` and `remove`, each `selfProtection` `allowed-directory-fallback`; `emptyStateKey` `allowedDirectoriesEmptyNone`; `emptyNextKey` `""`, `emptyAgentKey` `allowedDirectoriesAgentHint`; its header names the actions, route and key. The rule joins `SELFPROTECTIONRULES` and `screen-mirror.mjs` :315; run `node tools/screen-mirror.mjs` once task 10's keys exist.
3. `core/self-protection.ts`: the rule answers 18.42's `ALLOWLIST.FALLBACK` sentence for a row whose `Restricted` reads false, `''` otherwise and with no row.
4. `core/screen-actions.ts`: `register(descriptor, actionId, run, reason?: () => string)`; `reason(descriptor, actionId)`, `''` when none; `run` runs nothing and answers false while it is non-empty; `changed()` notifies listeners. Labels: `add` and `change` the new strings, `remove` `actionRemove`.
5. Each surface draws a registration's reason first, as a self-protection reason: `command-bar.ts` the primary action (`aria-disabled`, tooltip and `aria-describedby` as a row action's) and row actions; `data-table.ts` the empty-state action (labeled through `actionLabel`) and menu items; `command-box.ts` primary and row entries.
6. `shell/warning-dialog.ts`: input `fieldKind`, `'number'` (default) or `'text'`; a text field drops `inputmode` and releases Proceed while non-blank.
7. `shell/screen-action-handler.ts`: `OWN_ROUTES`, keyed by descriptor, one entry: `AllowedDirectoryList` posts `{Action: actionId, Directory: target, ...values}` to `/api/ocupilot/allowed-directories`; `send` uses it and handles the answer as now. The descriptor stays off `SCREEN_ACTION_DESCRIPTORS`.
8. `areas/security/allowed-directory-actions.ts` (new root service, AD-19): the verdict (`load()` clears it, issues the GET, calls `changed()`), the pending dialog, `open(action)`, `confirm(value)`, `cancel()`. `open('add')` notes whether a row reads `Restricted` false (unrestricted); change and remove take the list store's selection; a row the rule refuses puts its sentence on the store's refusal, as `startFor` does. Confirm closes the dialog, calls `sendFor` (add: the typed directory as target; change: `{NewDirectory}`), then `load()`.
9. `areas/security/allowed-directory-dialogs.ts` (new): on construction it registers the three actions with the service's reason and calls `load()`; it unregisters on destroy. Add and Change render as `app-warning-dialog` (`fieldKind` text; Add labeled `lockColumnDirectory` with the unrestricted or restricted consequence; Change labeled New directory with the change consequence naming the row); Remove as `app-typed-name-dialog` on the directory (verb `actionRemove`, the remove consequence). It emits `acting` before a confirm; `screen-action-dialogs.ts` renders it for this descriptor.
10. **Strings** (10, EXPERIENCE.md :364 in place and `strings.ts`): `allowedDirectoryAddAction` "Add directory"; `allowedDirectoryChangeAction` "Change directory"; `allowedDirectoryNewLabel` "New directory"; `allowedDirectoryHint` "An absolute directory on the server that already exists."; `allowedDirectoryAddRestricts` "File dialogs on this instance, the classic portal's included, can then reach only the manager directory and the directories listed here."; `allowedDirectoryAddConsequence` "File and directory fields can then choose locations under this directory."; `allowedDirectoryChangeConsequence` "File and directory fields then choose locations under the new directory instead of <directory>."; `allowedDirectoryRemoveConsequence` "File and directory fields can no longer choose locations under this directory; removing the last one leaves none."; `allowedDirectoriesEmptyNone` "The instance's allow-list names no directory, so no file or directory field can choose a location on the server."; `allowedDirectoriesAgentHint` "explain what the allowed directories control". EXPERIENCE.md :173 in place: the warnings gain "add or change an allowed directory, carrying its directory field (Story 18.46)", the delete confirmations "allowed directory". Literals: 3,306, plus 18.42's 7 and these 10, is 3,323 of 3,400.

**Tests** (each creates and removes what it asserts on):

11. `Test/AllowedDirectoryScreen.cls` (new, armed as `Test/AllowedDirectorySave`, a `ci-throwaway.sh` `# classes:` line): key disabled, the GET answers `enabled` false with its code and `AllowListError`'s sentence; enabled, true; without `%Admin_FileSystemAccess:USE`, 403 naming it; the descriptor's actions and rule, the rule in `SELFPROTECTIONRULES`, and no update tool in `Screen.Context.ScreenTools`. mutation: `HandleState` skips `Gate.Decide` -> the disabled leg red.
12. **Client:** `tools/screen-actions.test.mjs` (mutation: `run` ignores the reason -> red); `tools/self-protection.test.mjs` (`Restricted` false, true, no row; mutation: drop the branch -> red); `command-bar`, `data-table`, `command-box` specs (a registered reason draws primary and row actions `aria-disabled`; a click runs nothing); `warning-dialog.spec.ts` (text kind); `screen-action-handler.spec.ts` (the own route); `areas/security/allowed-directory-actions.spec.ts` (verdict, the three bodies, the fallback refusal, the re-read; mutation: drop `NewDirectory` -> red).
13. **Browser** `ui/browser/allowed-directory-write.browser-spec.mjs` (new, throwaway only; `PathPortFixture.Clear()` before and after; `<mgr>ocuprobe1846a/` and `…b/` made and removed; the key's setting read through `GET /agent/governance` and restored). Key `inherit`: the three actions carry the GET's reason; a click opens nothing. Key `enabled`: the manager row's Change and Remove carry the fallback sentence; Add A (rows: manager and A, restricted); Change A to B; Remove B; Remove the manager row (the empty state). Each step waits for `waitForRows` or the empty state. mutation: drop the `OWN_ROUTES` entry -> the Add leg red; `emptyStateKey` back to `allowedDirectoriesEmpty` -> the empty-state step red.
14. **Rule 30 sweep:** grep `src/OcuPilot/Test`, `ui/tools`, `ui/src` specs and `ui/browser` for `AllowedDirectoryList`, `allowedDirectoriesEmpty`, the rule rosters and 18.42's `/allowed-directories` rows. Expected: `Test/Descriptor.cls` :1158-1159 (`add`; `change,remove`); `Test/SecurityLists.cls` :62 (`"add", "change,remove"`); that browser spec's title; the GET's row beside 18.42's POST in `EndpointCoverage` and any route roster listing it; `StageTwoTools`: the row gains `route="allowed-directories"`, and for such a row each declared action resolves to the one bound tool, unadvertised and declaring no `SCREENACTIONS` (mutation: give the tool `SCREENACTIONS` `add` -> that row red). Run every class changed, plus `AllowedDirectorySave`, `PathPort`, `DeveloperFloorRoutes`, `InteropFloorRoutes`.

**Acceptance Criteria:**

- **C1** (epics.md). Given the key enabled, when a person adds, changes or removes an entry on the screen, then the dialog sends it through `POST /allowed-directories` after its confirmation and the list re-reads with the change (tests 12, 13).
- **C2** (epics.md). Given the key disabled, as shipped, when the screen is shown, then Add, Change and Remove are drawn off with the instance's reason and nothing is written (tests 11-13).
- **C3** (AD-21). Given the unrestricted fallback row selected, when the screen draws its actions, then Change and Remove are drawn off with `ALLOWLIST.FALLBACK`'s sentence (tests 12, 13).
- **C4** (18.42's C2b). Given a list a remove emptied, when the screen shows it, then its empty state says no file or directory field can choose a location on the server (test 13).

## Spec Change Log

- 2026-10-12, lead, spec gate: ready; AD-22 and AD-53 amended as proposed. Rule 11: the literal edits in `Test/Descriptor.cls`, `Test/SecurityLists.cls` and `Test/StageTwoTools.cls` sent to the orchestrator as a union ask. Epic 20's 20.29 (lazy screens) changes `screen-outlet.ts` and the routes: this story stays out of both, and a page it adds becomes a loader line at the forward merge.

## Review Triage Log

### 2026-10-13 — Review pass

- verdicts: 19 findings — high 0, medium 4, low 12, false 3, maybe-false 0
- findings:
  - `[medium]` `[patch]` The `acting` hand-off from `app-screen-action-dialogs` to the list page is pinned by no test — added a `screen-action-dialogs.spec.ts` test that confirms a Remove and expects one `acting`; the dropped binding reddens it.
  - `[medium]` `[patch]` "Ahead of the row's own" is not exercised on the row menu or the command box (their rows had no reason of their own) — both tests now use a row the fallback or `serves-ocupilot` rule also explains, and the swapped order reddens each.
  - `[medium]` `[patch]` Browser C2 read "opens nothing" with no wait, and its `log.posts` and list-as-it-was assertions could not fail — both removed, a two-frame wait added before each absence check (C2 and the fallback leg), and `ScreenActions.run` ignoring the reason now reddens the "opens nothing" step.
  - `[low]` `[patch]` `confirm`'s blank-value guard was exercised for Add only — the blank Change is now confirmed and the Add-only guard reddens it.
  - `[low]` `[reject]` `open()`'s `handler.pending()` guard is not exercised — the handler holds no dialog for this descriptor, so the leg is unreachable here; a test would need a fake handler state for no user-reachable case.
  - `[low]` `[reject]` `HandleState`'s gate-error 500 branch has no test — `Gate.Decide` has no seam to fail, the sibling `HandleSave` branch is equally untested, and an everyday user cannot reach it.
  - `[low]` `[patch]` `self-protection.test.mjs` asserted the rule's literal in `Registry.cls` text, which the new doc comment satisfies on its own — it now reads the parsed `SELFPROTECTIONRULES` value.
  - `[low]` `[reject]` `CheckRouted`'s per-action `Resolving = 0` legs cannot fail apart from its one-tool and empty-`SCREENACTIONS` assertions — redundant, harmless, and the `SCREENACTIONS` mutation is caught by the latter.
  - `[low]` `[patch]` `AllowedDirectoryScreen`'s verdict assertions sat inside `If $IsObject(tBody)` — each now asserts the body is an object first.
  - `[low]` `[patch]` Several tests named a mutation that `## Verification` did not record — each was applied, observed red and reverted, and the lines are recorded above.
  - `[low]` `[patch]` The write browser spec asserted the key reads `inherit` instead of establishing it — `before` now puts the policy back to the default after noting whether a policy was stored.
  - `[low]` `[reject]` C1, C3 and C4 share one browser test, so an early failure hides the later results — the steps are one sequence on one list whose state each step makes for the next, as the matrix orders them.
  - `[low]` `[reject]` The actions are drawn on until the first verdict lands and after a read that did not answer — spec-bound (task 8: `load()` clears the verdict before the read), and the write asks the key again, so a click in the window ends in the server's own refusal on the banner.
  - `[false]` `[reject]` The "opens nothing" guard sits in `ScreenActions.run`, not in `open` — `open` is reachable only through the registered handler `run` gates, so no click reaches it while a reason stands (the browser C2 mutation shows it).
  - `[low]` `[reject]` The browser pins the key-off state on the command bar alone — the row menu, command box and empty-state action are pinned in the component specs, each by a recorded mutation; the real-browser leg covers the screen as a person meets it.
  - `[low]` `[reject]` The verdict is read again after the screen's own write, not on the change event — AD-22 has the write ask the key, and a policy change made elsewhere is read when the screen is next entered, as task 8 says.
  - `[false]` `[reject]` The fallback sentence is chosen client-side from `Restricted` — the spec's rule reads the row ("a published sentence pinned to its code", AD-39) and the route refuses the row too.
  - `[false]` `[reject]` The shell imports `areas/security/allowed-directory-dialogs` and holds an `OWN_ROUTES` entry — tasks 7 and 9 name both, and `panel.ts` and `set-password-dialog.ts` already import from `areas/`.
  - `[medium]` `[patch]` Lead-found: the C1 test read the typed-name button's `aria-disabled` immediately after typing and clicked Proceed and the destructive button without waiting for them to be released, which failed 1 run in about 15 — each now waits two frames or for the release, and 32 consecutive runs are green.

## Design Notes

**Governing ADs:** AD-5, 8, 10, 13, 14, 19, 20, 21, 22, 39, 43, 53, 55, 58, 64.

**Rule 31.** Extended: `WarningDialog` (`fieldKind`), `TypedNameDialog` (as is), `ScreenActionHandler.send` (`OWN_ROUTES`; its answer handling kept) and `ScreenActions` (a registrant's reason); the host is `PermissionCheck`'s pattern, registered page-scoped as `rest-api-list.page.ts` is. Not copied: the person-route create dialogs (`DocDbCreateDialog`, `RestServiceCreateDialog`), each in another slice with its own store.

**No page wrapper:** `DESCRIPTOR_PAGES` is in `screen-outlet.ts`, which 20.29 reworks. **A GET:** `/agent/governance` answers OcuPilot administrators alone, and the registry and ports never ask governance.

**Consumes:** 18.42, 18.1, 14.2. **Consumed-by:** none (no service for another story); C1 runs on a real instance (test 13). **Ledger:** DW-2334's screen half closes here. **Live provider checks:** none.

**For the lead** (Rule 20; tag `[AMENDED 2026-10-12, Story 18.46 spec gate, Rule 20]`):

- **AD-22**, after "One person's write asks its key": `GET /allowed-directories` answers that key's verdict for the screen, which draws Add, Change and Remove off with `ALLOWLIST.OFF`'s sentence while the key is disabled; the POST still asks at the write.
- **AD-53**, after "A refusal is written once, on the server, and published once": a registered screen action may carry its registrant's reason (`ScreenActions`), drawn on every surface as a self-protection reason is.
- **Rule 11:** of these files only `strings.ts`, EXPERIENCE.md and `ci-throwaway.sh` are in Epic 20's diff (2026-10-12). The literal edits in `Test/Descriptor.cls`, `Test/SecurityLists.cls` and `StageTwoTools` are for the lead's union ask, as 18.42's were.

## Verification

**Commands** (one run per call, `timeout: 600000`):

- `(loop)` `sh /Users/jbrandt/git/OcuPilot/.worktrees/.coordination/carry-2026-10-08/epic-18-d8/load-ocupilot-ci.sh` prints `LOAD-OK` and `STARTPATH-OK`.
- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.<C>`, one at a time, totals from `%UnitTest_Result`: tasks 11 and 14.
- `(loop)` `cd ui && npm run test:tools && npm run test:components`.
- `(loop)` With `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776` and `OCUPILOT_BROWSER_CONTAINER=ocupilot-ci`: `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`, then `node --test --test-concurrency=1 browser/allowed-directory-write.browser-spec.mjs browser/allowed-directories.browser-spec.mjs`. Initial bundle under `angular.json`'s 1992kB warning.
- `uv run scripts/check-objectscript.py` and `bash scripts/lint-docs.sh`: 0 problems.

**Shared surfaces:** the descriptor and its mirror; `%GUIFileSelector`; the key's setting; the self-protection vocabulary; `ScreenActions` and its surfaces; `WarningDialog`; the route rosters; the Fixed strings; the arming roster.

every test added or changed passes on a fresh environment, in either order

**Measured (2026-10-13, `npm run build`):** initial total 1.90 MB (1,901,369 bytes, JS and CSS; `maximumWarning` 1992kB), as before the change: the dialog sits in the lazy `chunk-Cn2zXNXY.js` (25.35 kB), the shared `app-screen-action-dialogs` chunk the `list` page's `chunk-Dkwf2bAv.js` (5.63 kB) loads, so no initial file defines `app-allowed-directory-dialogs`; the largest lazy chunk is `data-browser-page` at 83.32 kB under `LAZYCHUNKMAX` 88 kB; `build-output.test.mjs` 16 of 16. Fixed strings: 3,326 literals (3,316 before this story, plus 10) of 3,400, the bound unchanged.

**Runs** (`%UnitTest_Result`, `ocupilot-ci`): `AllowedDirectoryScreen` 4/4 (663, after the review pass's assertions), `Descriptor` 60/60 (642), `SecurityLists` 7/7 (643), `StageTwoTools` 4/4 (653), `EndpointCoverage` 2/2 (655), `AllowedDirectorySave` 9/9 (646), `PathPort` 17/17 (647), `DeveloperFloorRoutes` 1/1 (648), `InteropFloorRoutes` 1/1 (649), `SaveHoldCoverage` 2/2 (658, its handler's source changed). Client, final tree: `test:tools` 1957/1957, `test:components` 242 files and 3024 tests, `build-output.test.mjs` 16/16, `check-objectscript.py` and `lint-docs.sh` 0 problems; the two browser specs 6/6 (`allowed-directory-write` 2, `allowed-directories` 4), and 32 consecutive green runs of `allowed-directory-write` after its waits were added. The throwaway ends at S0: `FSAccess` purpose absent, policy row version 0, no probe directory.

**Rule 30 sweep** (greps of `src/OcuPilot/Test`, `ui/tools`, `ui/src` specs, `ui/browser`): changed in place `Test/Descriptor.cls` (`add`; `change,remove`), `Test/SecurityLists.cls` (`"add", "change,remove"`), `Test/StageTwoTools.cls` (the row's `route="allowed-directories"` and `CheckRouted`), `Test/EndpointCoverage.cls` (the GET probe), `ui/browser/allowed-directories.browser-spec.mjs` (the emptied list's title, and the table's hidden Actions header the row actions add); unchanged and still pinning nothing of the old shape: `ui/tools/screen-mirror.test.mjs` and `navigation.test.mjs` (route and owner rosters), `server-path-picker` (`allowedDirectoriesEmpty` stays the picker's).

**Mutations (Rule 19)**, each applied, observed red, reverted and proven byte-identical (client: sha256 of the file; ObjectScript: the throwaway's mounted copy, recompiled with its descendants, equal to the worktree file, the class green again):

- mutation: `HandleState` skips `Gate.Decide` -> `AllowedDirectoryScreen.TestTheKeyShippedOffAnswersItsVerdictAndChangesNothing` and the switched-off leg of `TestTheKeyEnabledAnswersEnabledAndFollowsTheStoredPolicy` (run 650; green again 651).
- mutation: `AllowedDirectoryUpdate` gains `SCREENACTIONS` `add` -> `StageTwoTools.TestEachDeclaredActionResolvesToExactlyOneWriteTool` (652; 653).
- mutation: the GET probe row removed from `EndpointCoverage` -> `TestEveryRouteHasAProbeAndEveryProbeHasARoute` (654; 655).
- mutation: `allowed-directory-fallback` dropped from `Registry.SELFPROTECTIONRULES` -> `AllowedDirectoryScreen.TestTheDescriptorDeclaresTheActionsAndTheContextListsNoWriteTool` (656; 657).
- mutation: `ScreenActions.run` ignores the reason, or `reason` answers `''` -> `tools/screen-actions.test.mjs`, the 18.46 test.
- mutation: the `allowed-directory-fallback` branch dropped from `selfProtectionReason`, or its sentence answered for a restricted row -> `tools/self-protection.test.mjs`, the 18.46 test.
- mutation: `{NewDirectory: value}` sent as `{}` -> `allowed-directory-actions.spec.ts` (the Change body) and `allowed-directory-dialogs.spec.ts` (Change); the `ask !== this.asked` guard dropped -> the newest-read test; the verdict not read again after a send -> the Add and the refused-write legs; the fallback rule not asked in `open` -> the fallback-refusal leg.
- mutation: the primary action's reason read, or the row actions' reason read, answered `''` in `command-bar.ts` -> `command-bar.spec.ts`, the 18.46 test (each); `data-table.ts`: the menu's reason read dropped, the empty-state label back to the bare id, the empty-state reason read dropped -> `data-table.spec.ts` (each of three legs); `command-box.ts`: the primary's reason read dropped, the row's dropped -> `command-box.spec.ts` (each).
- mutation: a text field judged by the whole-number rule, or kept `inputmode="numeric"`, in `warning-dialog.ts` -> `warning-dialog.spec.ts` (each); `hasAllowedDirectories` answering `false` -> `screen-action-dialogs.spec.ts`; the `OWN_ROUTES` map emptied, or its body dropping `...values` -> `screen-action-handler.spec.ts`.
- mutation: the `OWN_ROUTES` entry dropped, the bundle rebuilt and redeployed -> `allowed-directory-write.browser-spec.mjs`, the Add step (its rows wait, `rowsAre`); `AllowedDirectoryList` `emptyStateKey` back to `allowedDirectoriesEmpty` with the mirror regenerated, rebuilt and redeployed -> the same spec, the empty-state step; the clean bundle rebuilt and redeployed, both browser specs green.

- mutation (review pass): `DataTable.menuItems` reading the registrant's reason after the row's own, or `command-box.ts` likewise -> `data-table.spec.ts` and `command-box.spec.ts`, the 18.46 ordering tests (each, on a row the screen's own rule also explains); the `(acting)` binding dropped on `app-allowed-directory-dialogs` -> `screen-action-dialogs.spec.ts`; `confirm` guarding only an Add against a blank value -> the blank-Change leg of `allowed-directory-actions.spec.ts`; `reasonOf` ignoring `enabled` -> the same spec (3 tests); `register` without its reason, `onDestroy` without the unregistering, the two Add consequences swapped -> `allowed-directory-dialogs.spec.ts` (1, 1, 2 tests); the `DESCRIPTOR_ACTION_LABELS` entry dropped -> `tools/screen-actions.test.mjs`; the fallback sentence answered for every row -> `tools/self-protection.test.mjs`.
- mutation (review pass): `Admit` ignoring the pairs refusal -> `AllowedDirectoryScreen.TestACallerWithoutTheScreensPairIsRefusedByName` (run 660; green again 661); `AllowedDirectoryUpdate` advertised with `SCREENACTIONS` `change` -> `TestTheDescriptorDeclaresTheActionsAndTheContextListsNoWriteTool` (662; 663).
- mutation (review pass, bundle rebuilt and redeployed each time): `register` without its reason -> `allowed-directory-write.browser-spec.mjs`, C2's aria-disabled step; `ScreenActions.run` ignoring the reason -> the same test's "opens nothing" step; the clean bundle redeployed, both browser specs green.
- (QA) test added, no new file: a third test in `ui/browser/allowed-directory-write.browser-spec.mjs` ("C1 on a restricted list"): the plain Add consequence, Cancel sends nothing, and an Add naming a directory that does not exist puts the route's sentence on the list's banner, changes nothing and reads the verdict again. Eight existing browser specs that click a list's primary action or empty-state action or read row-action reasons (`ecp-data-servers`, `license-key`, `interop-item-test`, `database-operations`, `oauth`, `routine-applications`, `license-servers`, `users-actions`) ran green on the final bundle.
- mutation (QA, applied, observed red, reverted byte-identical by sha256): `reasonOf` answering `''` for a refused read -> `allowed-directory-actions.spec.ts`, the refused-read test; `confirm` sending the Remove with `{NewDirectory: value}` -> that spec's Remove body test and `allowed-directory-dialogs.spec.ts`' Remove test; `open` without the `this.waiting() !== null` guard -> "opens no dialog over another"; `unrestricted` always `false` -> the Add-noting test and the unrestricted Add consequence test; `load` not clearing the verdict -> "clears the verdict before it reads"; `open` without the blank-directory guard -> "opens Change and Remove on the selected row"; `confirm` not closing the dialog first -> the Add send test and the Add dialog test; the Change consequence's `<directory>` replaced by `''`, the Remove consequence swapped for Add's, the Remove dialog's `[target]` made the verb, `fieldLabelOf` swapped -> the matching `allowed-directory-dialogs.spec.ts` test (each); `ScreenActionHandler.send` putting `''` on the store after a refusal -> the refused-write test; its change event published with `id: ''` -> the Add send test's event assertion.
- mutation (QA, bundle rebuilt and redeployed): `ScreenActionHandler.send` putting `''` on the store after a refusal -> `allowed-directory-write.browser-spec.mjs`, the new test's banner step; the clean bundle rebuilt and redeployed, both browser specs green (7 of 7), and each of the three write-spec tests green alone, in the reverse order.
- mutation (QA, ObjectScript on `ocupilot-ci`): `AllowedDirectoryList` without its `remove` row action -> `AllowedDirectoryScreen.TestTheDescriptorDeclaresTheActionsAndTheContextListsNoWriteTool` (run 664), `Descriptor.TestTheAllowedDirectoriesListDeclaresThePathSource` (665) and `SecurityLists.TestEachListIsDeclaredAsTheSecurityAreaEntryItReplaces` (666); the file restored byte-identical, the throwaway reloaded with its mounted copy equal to the worktree, the three classes green again (667, 668, 669); the throwaway ends at S0.

Rule 11: Epic 20's working tree (2026-10-13) also edits `core/screen-actions.ts` (one label entry), `screen-action-handler.ts` (two list entries), `screens.generated.ts` and `strings.ts`; this story's hunks in those files do not overlap theirs (`register`, `run`, `reason` and `changed` in `ScreenActions`, which task 4 mandates, the `OWN_ROUTES` block and `send`), and `screens.generated.ts` is regenerated at the forward merge.

## Auto Run Result

Status: done
Blocking condition: none

**Summary.** The Allowed directories screen carries Add, Change and Remove. `GET /allowed-directories` (`AllowedDirectorySave.HandleState`, beside `HandleSave`, which shares its `Admit` step) answers the write key's verdict; a registrant's reason in `ScreenActions` draws the primary action, the row actions, the row menu, the empty state and the command box off with the server's sentence; `AllowedDirectoryActions` and `AllowedDirectoryDialogs` run the three dialogs through `ScreenActionHandler.sendFor`, whose `OWN_ROUTES` entry posts to 18.42's route; the fallback row refuses Change and Remove with `ALLOWLIST.FALLBACK`'s sentence; an emptied list's empty state says no file or directory field can choose a location.

**Files.** New: `Test/AllowedDirectoryScreen.cls`, `areas/security/allowed-directory-actions.ts` and `allowed-directory-dialogs.ts` with their specs, `shell/screen-action-dialogs.spec.ts`, `browser/allowed-directory-write.browser-spec.mjs`, `browser/allow-list-spec.mjs`. Edited: `AllowedDirectorySave.cls`, `Router.cls`, `AllowedDirectoryList.cls`, `Registry.cls`, `screen-mirror.mjs` and the mirror, `ScreenActions`, `self-protection.ts`, `command-bar`, `data-table`, `command-box`, `warning-dialog`, `screen-action-dialogs`, `screen-action-handler`, `strings.ts`, `_components.scss`, EXPERIENCE.md :173 and :364 in place, `ci-throwaway.sh`, the Rule 30 sweep's rosters, `preferences-reset.mjs` (`setGovernanceKey`).

**Review.** One pass, two layers: 19 findings, none high. Patched 4 medium and 5 low (all in tests; the product code needed none); no `defer`; 10 rejected, each on the reason in `## Review Triage Log`. `followup_review_recommended: true` because four mediums were patched; the unverified risk is the timing of `allowed-directory-write.browser-spec.mjs` on a CI shard leg, which ran 32 times in a row green locally after its waits were added and 1 in about 15 before.

**Verification.** See `## Verification`: the runs, the measurements and every mutation.

**Residual risks.** The primary action in the command bar is wrapped in the row actions' `action-slot` span (a descendant selector such as `.ocu-command-bar button.ocu-command-bar-primary` still matches; the other browser specs that click it were not re-run, Rule 29). A list's empty-state action is now labeled through `actionLabel`, so its text changes from the bare id (`create`) to the published word wherever a list has one. The dialog's code sits in the shared `app-screen-action-dialogs` lazy chunk (25.35 kB of the 88 kB cap), which every list page loads. The AD-22 and AD-53 amendments under `## Design Notes` are the lead's (Rule 20).
