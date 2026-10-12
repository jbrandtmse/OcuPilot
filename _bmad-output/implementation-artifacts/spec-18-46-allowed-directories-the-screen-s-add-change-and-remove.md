---
title: 'Story 18.46: Allowed directories: the screen''s add, change and remove'
type: 'feature'
created: '2026-10-12'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
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
- `(loop)` With `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776` and `OCUPILOT_BROWSER_CONTAINER=ocupilot-ci`: `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`, then `node --test --test-concurrency=1 browser/allowed-directory-write.browser-spec.mjs browser/allowed-directories.browser-spec.mjs`. Bundle under 3527kB.
- `uv run scripts/check-objectscript.py` and `bash scripts/lint-docs.sh`: 0 problems.

**Shared surfaces:** the descriptor and its mirror; `%GUIFileSelector`; the key's setting; the self-protection vocabulary; `ScreenActions` and its surfaces; `WarningDialog`; the route rosters; the Fixed strings; the arming roster.

every test added or changed passes on a fresh environment, in either order

**Mutations (Rule 19):** tasks 11-14.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none
