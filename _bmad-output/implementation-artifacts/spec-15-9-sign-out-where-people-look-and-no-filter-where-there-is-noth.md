---
title: 'Story 15.9: Sign-out where people look, and no filter where there is nothing to filter'
type: 'feature'
created: '2026-09-25'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-15-context.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** Sign out sits behind the user name in the status bar, where a first-time judge did not find it, and the command search has no Sign out command. Home, the form pages and the application-error drill-down show a filter that filters nothing. Three routed items close here:

- DW-1597: an editor's own Save raises a change toast.
- DW-1648: the ⋮ trigger scrolls off-screen on wide tables.
- DW-1649: `clickRowCentre` never checks where its click landed.

**Approach:** Move the account menu's trigger to the header's right end. Add a Sign out command to the command box that calls the same `Session.signOut()`. Hide the filter and its count on screens whose descriptor declares no read, and draw no command bar when it has nothing to show. Suppress the toast for a screen's own write. Pin the trigger column to the frame's right edge. Add a landing check to `clickRowCentre`.

## Boundaries & Constraints

**Always:**

- **One trigger, one sign-out path.** `app-account-menu` (id `ocu-account-trigger`, its classes and its four items unchanged) mounts in `app-header`, after the namespace slot, at the header's right end. The status bar keeps the user name as a plain segment, in the same position, with no button, caret or hover. The command box's Sign out row and the menu's item both call `Session.signOut()` (AD-28, AD-31). There is no copy of the sign-out logic.
- **The command box's Sign out row** has the label `STRINGS.actionSignOut`. It sits last in the Actions group on every screen, and is listed only while the typed needle is non-empty and the label contains it. With an empty query the list and the count sentence are unchanged. Choosing it closes the box and signs out. It is absent when no `Session` is injected.
- **"Declares no read" is `screen.read === null`** on `screenForUrl`'s declaration from the generated mirror (AD-5). Today that covers 14 built screens: Home, 12 form pages and `logs/errors`. No list of screens is written anywhere. On those screens the filter input and its `role="status"` count are not in the DOM.
- **The command bar draws nothing** (no `.ocu-command-bar` element) when every slot is empty: no primary action, no filter, no row actions, no View control, no Sort control, no Refresh action, no chip. List screens keep their filter exactly as before.
- **DW-1597 toast rule.** An agent's `changed` event carries its proposal's id: `turn.ts` passes `proposalId: id` on the confirm's publish.
  - A `changed` event with an empty `proposalId` raises no toast while the open screen shows the entity (`screenShowsEntity`). That is a screen's own write, on the screen that made it.
  - A screen write that lands after the user has moved to a screen of another entity type still toasts.
  - An agent write keeps DW-1546's rule unchanged, so UJ-6's toast on Task details stays.
- **DW-1648.** The body trigger cell and the header's trigger column cell are `position: sticky; right: 0`. Both have an opaque background that follows the row state: default, hover, selected and changed. Bare `--ocu-*` roles only (Conventions › Theme).
  - Column widths are exactly as Story 15.8 set them.
  - `revealActiveCell` and `clickRowCentre` treat the pinned cell's box as outside a data cell's visible range.
  - The active row's focus ring stays visible across the pinned cell.
- **DW-1649.** `clickRowCentre` records the wanted row's first-cell text, whichever way the row was chosen, and arms a one-shot capture-phase `pointerdown` probe. After the click it throws with a message naming the miss in three cases: no pointerdown arrived, the row it landed in has other first-cell text, or it landed outside the requested target kind (link or cell *n*).
- **Documentation.** DESIGN.md and EXPERIENCE.md are corrected in place. Each edit replaces a sentence on its own line, so no `:n` citation moves, and carries `[AMENDED 2026-09-25, Story 15.9]`. Every `EXPERIENCE.md "…"` citation in `ui/src` and `src/OcuPilot` still resolves (`tools/citations.test.mjs`).
- No new user-facing string is expected. If one is needed, it is appended to EXPERIENCE.md Fixed strings first and then to the tail of `strings.ts`.

**Never:**

- Do not edit `ui/src/app/app.ts`, `shell/panel*` or `shell/proposal-card*`.
- In `core/turn.ts`, change only the `bus?.publish({...})` object at `:1097-1102`. Epic 12's hunks are after `:1072` and `:1109`, and 10.6 promises not to touch `:1078-1103`.
- No `origin` field, no change to the 19 screen publishers, no change to AD-14's re-fetch or highlight.
- No change to column widths, kinds or floors (not DW-1648's option (c)), and no ObjectScript change.
- Do not reorder or reflow other stories' rules in the shared-append files. In-place `_components.scss` edits are limited to the `.ocu-account*` and `.ocu-header*` declarations, whose components this story owns; everything new goes in one tail block.
- Do not write `deferred-work.md`, `sprint-status.yaml` or the cycle log. Never stop, `down` or recreate `ocupilot`, `ocupilot-ci`, `ocupilot-b-ci` or any `ocupilot-slot-*` container.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Header menu | any signed-in screen; click `#ocu-account-trigger` in `app-header` | opens downward. It shows About, Change password, Dark theme and Sign out in that order, and the Sign out item is under its own center point (`elementFromPoint`). Clicking it lands on the sign-in form. | none |
| Status bar | same | `app-status-bar` shows the user name and contains no `button` | none |
| Narrow header | 720 px | the account button lies inside the header and does not intersect the command box. A long name ellipsizes, and the button's text content stays whole. | none |
| Command Sign out | open the box, type "sign out", Enter | an Actions row "Sign out" is active; the sign-in form appears | empty query: no Sign out row; count unchanged |
| No read | `/` (Home) | no `.ocu-command-bar`, no `#ocu-command-bar-filter` | none |
| No read with actions | `logs/errors`; `permissions/users/edit` | no filter or count; the bar still draws what `logs/errors` registers (Refresh, row action) | none |
| List | `permissions/users`, type into the filter | the rows narrow and the count reads the new number | none |
| Own Save | web-application editor Save | no `.ocu-toast-region`; the list, when opened, shows the saved row | none |
| Agent write, same entity | confirm on Task details (UJ-6) | the toast "Open in Task schedule" is raised | none |
| Screen write, elsewhere | `changed` with empty `proposalId` while the open screen shows another entity type | the toast is raised | none |
| Pinned trigger | harness at 480, scroll 0 and scrolled to the end | trigger inside the frame and hit-testable at both; the cell's background alpha is 1 on a plain and a selected row | none |

</intent-contract>

## Code Map

- `ui/src/app/shell/header.ts:55-67` is the template. `:17-50` is the doc comment ("Three things and nothing else"), which gets corrected.
- `ui/src/app/shell/status-bar.ts:90` holds `<app-account-menu />`. Replace it with the user segment, mirroring `Session.userName()` as `account-menu.ts:195-203` does. `:26-28` is the doc sentence.
- `ui/src/app/shell/account-menu.ts:22-38`: the doc comment says "status bar", and it cites `EXPERIENCE.md "status-bar user segment"`, which must resolve after the `:81` edit. `:355-359` is `chooseSignOut`.
- `ui/src/styles/_components.scss`:
  - `:480-571`, the account block: `:508` height is the status-bar height, and `:533-545` the panel opens upward (`bottom: 100%`). Change it in place to a 32px control opening downward, right-aligned, keeping `z-index: 4`.
  - `:1090-1145`, the header grid: `1fr auto 1fr`, with the namespace slot at `justify-self: end`.
  - `:2395-2440`, the row states and `.ocu-data-table-cell-trigger`.
- `ui/src/app/shell/command-bar.ts`:
  - `:154-173`: the filter input and the count `<p>`, rendered unconditionally.
  - `:566-600`: `matchCount` and `filterValue` already answer `''` on `screen.read === null`.
  - `:376-379`: the `screen` computed.
  - Other slot getters: `hasPrimaryAction`, `rowActions`, `hasViewControl`, `hasSortControl`, `hasRefreshAction`, `hasRefreshChip`.
- `ui/src/app/shell/command-box.ts:377-389` is `choose`. `:466-521` is `actionCandidates`, the place to add the row (kind `'account'`, id `ocu-command-box-account-sign-out`). `Session` is optional at `:220`.
- `ui/src/app/core/toasts.ts:194-218` is `publish`. `:288-293` is `targetIsOpen`. `screenShowsEntity` is at `core/navigation.ts:474-482`.
- `ui/src/app/core/change-bus.ts:58-59`: the `proposalId` doc says `''` for `changed`. Restate it: the confirmed proposal on an agent's `changed`, `''` on a screen's. `publish` already passes it through (`:136`). `core/refresh.ts:612-628` keys on `kind`, so it is unaffected.
- `ui/src/app/core/turn.ts:1097-1102` is the confirm's `changed` publish, where `id` is the proposal id.
- `ui/src/app/shell/data-table.ts`:
  - `:278-284`, the header trigger `columnheader`: add class `ocu-data-table-header-cell-trigger`.
  - `:355-374`, the body trigger cell.
  - `:1130-1141`, `revealActiveCell`: `right` is `viewport.clientWidth`.
- `ui/browser/data-table-columns.browser-spec.mjs`:
  - `:336-386`, "Trigger reach": its two "past the frame" assertions are at `:345` and `:376`, and `:339-340` says to delete them.
  - `:287`, Reveal.
- `ui/browser/list-spec.mjs:174-319` is `clickRowCentre`. `ROW_SELECTOR` is at `:28`. It has 25 caller files (`grep -l clickRowCentre ui/browser`).
- Tests to change:
  - `ui/tools/toasts.test.mjs:156-170`: the Task details leg must carry `proposalId`, and the final "Save on the user editor raises its Users toast" leg inverts under DW-1597.
  - `ui/browser/web-applications-editor.browser-spec.mjs:231-262` (AC2) waits for and clicks the Save toast.
  - `ui/browser/task-resume.browser-spec.mjs:506-520` is the agent leg on Task details. It is unchanged, and it pins `turn.ts`.
  - `ui/browser/panel.browser-spec.mjs:511-513`: its comment names the status bar.
- jsdom specs pinning the old placement: `status-bar.spec.ts:310-320`, `header.spec.ts:128-135` and `:221`, `account-menu.spec.ts`, and `command-bar.spec.ts` cases that expect a filter on a screen with no read.
- Docs. All line numbers are current.
  - EXPERIENCE.md: `:51` (header region), `:56` (status-bar region), `:81` (Sign out row: status-bar entry and the `[ASSUMPTION]`), `:464` ("Dark theme": "in the status bar's account menu"), `:525`, `:528`, `:531` (command-bar), `:544` (toast), `:772` (Off-screen toast), and `:832` ("the user segment as the account home").
  - DESIGN.md: `:306` (`user-segment-glyph`), `:1008` ("Nothing else lives in the header; … user …"), `:1022` ("The user is the bar's one interactive segment"), `:1038` (command-bar) and `:1042` ("The last column is the `row-overflow-menu` trigger").

## Tasks & Acceptance

**Execution:**

- `ui/src/app/shell/header.ts`, `ui/src/app/shell/header.spec.ts`: add a right-end wrapper, `.ocu-header-end`, holding the namespace slot and then `<app-account-menu />`. Correct the doc comment and the band-order test.
- `ui/src/app/shell/status-bar.ts`, `ui/src/app/shell/status-bar.spec.ts`: replace the menu with a plain `ocu-status-bar-segment` showing the user name. The test asserts the band has no interactive element.
- `ui/src/app/shell/account-menu.ts`, `ui/src/app/shell/account-menu.spec.ts`: correct the doc comment's placement and citation. The behavior does not change.
- `ui/src/styles/_components.scss`:
  - In place, the `.ocu-account*` trigger height and panel direction, the stale "Story 1.10 moved … status bar" comment sentence, and `.ocu-header` grid side tracks to `minmax(0, 1fr)`.
  - Tail block `// --- Header account button, pinned row trigger (Story 15.9)`: `.ocu-header-end` (flex, end-aligned, `--ocu-space-2` gap, `min-width: 0`); the account name's ellipsis; the sticky trigger cells with a row-state background, opaque in both themes; and the focus ring kept visible across the pinned cell.
- `ui/src/app/shell/command-box.ts`, `ui/src/app/shell/command-box.spec.ts`: add the Sign out row per Always. Pin these: a typed needle lists it; an empty query has no row and the same count; choosing it calls `Session.signOut` once and closes the box.
- `ui/src/app/shell/command-bar.ts`, `ui/src/app/shell/command-bar.spec.ts`:
  - `@if` on the filter and count when `screen.read !== null`;
  - an outer `@if (hasContent)` over the bar, with a paren-free condition (`client-lint`);
  - the doc comment;
  - jsdom cases for Home (no bar), `logs/errors` (bar with no filter) and a list (filter present).
- `ui/src/app/core/turn.ts`: add `proposalId: id` to the `changed` publish, one line.
- `ui/src/app/core/change-bus.ts`: correct the `proposalId` doc comment. There is no behavior change.
- `ui/src/app/core/toasts.ts`, `ui/tools/toasts.test.mjs`: the DW-1597 rule in `publish`, with the header comment corrected. Tests:
  - an own Save on the user editor raises nothing;
  - the same event with `proposalId: 'p-1'` raises;
  - Task details with `proposalId` raises;
  - an empty-`proposalId` write on an unrelated screen raises;
  - the list still raises nothing.
- `ui/src/app/shell/data-table.ts`, `ui/src/app/shell/data-table.spec.ts`: the header trigger cell class. `revealActiveCell` subtracts the row's trigger cell (`left`) from `right` for a data cell.
- `ui/browser/data-table-columns.browser-spec.mjs`:
  - **Trigger reach:** delete the two "past the frame" assertions. The trigger is inside the frame and hit-testable at scroll 0 and after the wheel. A click opens the menu there, and Right+Enter opens it too. The pinned cell's background alpha is 1 on a plain and on a selected row.
  - **Reveal:** also asserts that the revealed cell's right edge is at or left of the trigger cell's left edge (+0.5).
- `ui/browser/list-spec.mjs`: the DW-1649 probe per Always, plus the visible range excluding the pinned cell. Update the doc comment.
- `ui/browser/account-and-filter.browser-spec.mjs`: new file. It uses `signedInAt`, runs on the throwaway and refuses `LIVE_CONTAINER`. It covers the matrix rows Header menu, Status bar, Narrow header, Command Sign out, No read, No read with actions and List. Each sign-out uses its own context.
- `ui/browser/web-applications-editor.browser-spec.mjs` AC2: after Save, no `.ocu-toast-region` stands (wait 1 s). The list opened at `web-applications/list/<encoded probe>` shows the saved values. This is the Own Save row.
- `ui/browser/panel.browser-spec.mjs:511-513`: correct the comment. The menu opens down from the header, and the mutation named is `overflow: hidden` on `.ocu-header`.
- `ui/browser/structural-baseline.json`: delete by hand any key the gate prints as stale. The gate must print 0 fresh.
- EXPERIENCE.md and DESIGN.md: correct each line in the Code Map list in place.
  - Header: the account button at the right end, beside the namespace switch.
  - Status bar: the user as information only; "Read-only"; no ▾.
  - Sign out: the header account button · command-box "Sign out"; drop the `[ASSUMPTION]`.
  - Command-bar: no filter or count on a screen that declares no read, and a bar with nothing to show is not drawn.
  - Toast rows: never for the open screen's own write; an agent's change still toasts on the entity's own details or editor.
  - DESIGN.md `:1042`: the trigger column pinned to the frame's right edge on the row's own state color.
  - Update the `account-menu.ts` citation to a phrase on the new `:81`.

**Acceptance Criteria:**

- **AC1.** Given any signed-in screen, when it renders, then the header's right end, beside the namespace switch, carries a button naming the user that opens About, Change password, Dark theme and Sign out, each with today's action; and the status bar shows the user name with no control.
- **AC2.** Given the command box, when the user types "sign out" and chooses the row, then they are signed out through the same `Session.signOut()` as the menu, and the sign-in form shows.
- **AC3.** Given a screen whose descriptor declares no read, when it renders, then there is no filter field and no match count, and a command bar with nothing left to show is absent. A list still filters.
- **AC4.** Given EXPERIENCE.md's status-bar and Sign out rows (and the DESIGN.md header, status-bar, command-bar and data-table lines), when this story completes, then they state the new behavior at origin. `lint-docs`, `citations.test` and `strings.test` are green.
- **AC5 (DW-1597).** Given a screen's own Save or action, when its change event lands while that screen shows the entity, then no toast is raised. An agent write, and a screen write landing after the user moved to another entity's screen, still raise one.
- **AC6 (DW-1648).** Given a table wider than its frame, when it renders or scrolls either way, then the ⋮ trigger stays at the frame's right edge, clickable and opaque over the row state. `a11y-structural-invariants` reports 0 fresh keys in light and dark, and the baseline holds no stale key.
- **AC7 (DW-1649).** Given a caller of `clickRowCentre`, when the click lands in a different row or outside the target, then the helper throws naming the row it landed in, instead of the caller timing out later. Every one of the 25 caller files that reaches its click passes.
- **Integration AC (Rule 1/2).** Given the deployed bundle on `ocupilot-ci`, when `_SYSTEM` signs out from the header menu and, in a second context, from the command box, then `Session.signOut()` posts `/logout` with Bearer and cookie (AD-28). The sign-in form shows and the context is not silently signed back in on reload.

## Spec Change Log

## Review Triage Log

## Design Notes

**Governing ADs (Rule 6):**

- AD-28 and AD-31: one sign-out, "of the instance", which abandons turns first. `Session.signOut()` already does both.
- AD-5: derived from `read`, never enumerated.
- AD-14 and AD-43: the re-fetch and highlight are unchanged. The `proposal-*` pause is keyed by kind.
- AD-19: `core/` stays framework-free.
- AD-53 and AD-55: a screen's own write publishes `changed`, and only its toast changes.
- Conventions: *Theme* (bare roles; the sticky cell is opaque in both modes), *Screens that take no side-bar position* (form pages are among the no-read set by their `read`, not their position), *Angular naming* and *Client asset homes*.

No AC contradicts an AD.

**Why `proposalId` and not the entity type.** UJ-6 (EXPERIENCE.md `:918`) has the agent resume a task on Task details and expects "Open in Task schedule". A rule keyed only on "the open screen shows the entity" would suppress that. The bus already carries `proposalId` through on `changed`. Setting it at the one agent publisher separates the two callers with a one-line change, instead of an `origin` field across 19 screen stores.

**Ledger inbox (Rule 17):** DW-1597 → AC5; DW-1648 → AC6 (decided (b)); DW-1649 → AC7. Pinning the trigger does not remove DW-1649's cause, which is the re-render between measuring and clicking, so it is addressed rather than declined.

**Footprint (Rule 11).**

- **Declared:** `shell/status-bar*`, `shell/account-menu*`, `shell/header*`, `shell/command-bar*`, `shell/command-box*`, `core/navigation.ts` (read only), `shell/data-table*`, and the story's browser specs.
- **Shared-append:** `_components.scss` (tail block plus the in-place `.ocu-account*` and `.ocu-header*` declarations) and EXPERIENCE.md (no Fixed-strings row is expected).
- **`footprint_extensions:`**
  - `core/toasts.ts`, contended with 10.6, whose spec leaves it unedited: read `git show origin/OCU-1-epic10:ui/src/app/core/toasts.ts` before editing.
  - `core/turn.ts`, one line inside `:1097-1102`, clear of Epic 12's hunks (after `:1072` and `:1109`) and of 10.6's.
  - `core/change-bus.ts` (a comment only) and `ui/tools/toasts.test.mjs`.
  - `ui/browser/list-spec.mjs`, `web-applications-editor.browser-spec.mjs`, `panel.browser-spec.mjs` (a comment only), `data-table-columns.browser-spec.mjs` and `structural-baseline.json`.
  - EXPERIENCE.md outside Fixed strings, and DESIGN.md.
- `app.ts` is not touched.
- Merge note (inference): Epic 12 inserts five EXPERIENCE.md lines after `:467`. The `:464` edit stays three lines clear of them.

**Consumes:** `Session.signOut()` (AD-28, AD-31); the generated screen mirror (`read`); `ChangeBus` and `ToastStore`; Story 15.8's `data-table` layout and "Trigger reach" harness; the DW-1337 gate and baseline.

**Consumed-by:** no service is introduced. The 25 `clickRowCentre` callers consume the helper change.

**Risk (inference):** the sticky cell's background may cover the active row's inset `box-shadow` ring at the right edge. The implementer checks this and, if it is covered, draws the ring's right segment on the pinned cell.

## Verification

**Environment.** Slot A, throwaway `ocupilot-ci` (52776/1975). It is shared and reused: never tear it down, never touch `ocupilot`, and run one test command at a time. Before any browser read:

1. `cd ui && npm run build && npx ng build --configuration production,harness`.
2. `docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`.
3. `export OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci`.

**Commands:**

- `(loop)` `cd ui && npm run test:tools`: green, including `toasts`, `citations`, `strings`, `change-bus` and `browser-reset`.
- `(loop)` `cd ui && npm run test:components`: green, including the header, status-bar, account-menu, command-bar, command-box and data-table specs.
- `(loop)` `cd ui && npm run build`: the seven checkers pass. Quote the initial total. The warning limit is 1670kB; re-base per DW-1166 if the total crosses it, and HALT `blocked` above 1900kB.
- `(loop)` `cd ui && node --test --test-concurrency=1 browser/account-and-filter.browser-spec.mjs browser/data-table-columns.browser-spec.mjs browser/web-applications-editor.browser-spec.mjs browser/task-resume.browser-spec.mjs browser/a11y-structural-invariants.browser-spec.mjs`: green. The gate prints 0 fresh and 0 stale. If a test is refused because of residue on `ocupilot-ci` (for example `task-resume`), record it as residue and leave it to CI.
- `(loop)` `bash scripts/lint-docs.sh`: green.
- `(once, before dev_complete)` the specs whose account-menu or command-box path moved, run as one `node --test --test-concurrency=1` call: `change-password`, `theme`, `about-help-links`, `panel`, `column-widths`, `preferences-integration`, `toast` and `definitions`.
- `(once, before dev_complete)` the 25 `clickRowCentre` caller files (`grep -l clickRowCentre browser/*.browser-spec.mjs`), one `node --test --test-concurrency=1` call. `reduced-editors` and `tasks` stop before the click on this reused container (DW-1425/DW-1468); that is residue, not a failure of this story.
- `(once, before dev_complete)` `bash scripts/smoke.sh --container ocupilot-ci --user _SYSTEM --password SYS`: more than 0 checks, all passing.
- `(once, before dev_complete)` the full ObjectScript sweep on `ocupilot-ci`, although no `.cls` changes: `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --package OcuPilot.Test`. The 14 unarmed classes and `WireSecurityRead`'s task-history test are known residue.
- The full browser suite is not run locally (Rule 29).

**Mutations (Rule 19).** For each one: apply it, observe red, revert, and confirm the tree is byte-identical. Rebuild and redeploy before every browser read.

- AC1: mount `<app-account-menu />` back in the status bar → `account-and-filter` Header menu and Status bar red, and `status-bar.spec.ts` red.
- AC2: drop the Sign out row → Command Sign out red, and `command-box.spec.ts` red.
- AC3:
  - render the filter unconditionally → No read red;
  - force `hasContent` true → the Home no-bar assertion red;
  - hide the filter on every screen → List red.
- AC5:
  - drop the empty-`proposalId` suppression → `toasts.test` own-Save red, and `web-applications-editor` AC2 red;
  - drop `proposalId: id` from `turn.ts` → `task-resume`'s toast wait red (CI if residue blocks it here).
- AC6: remove `position: sticky` → "Trigger reach" red. `background: transparent` on the pinned cell → its alpha assertion red.
- AC7: offset `clickRowCentre`'s click `y` by one row height → `users.browser-spec.mjs` fails with the helper's named miss, not a trigger timeout.
- Integration AC: replace the command row's `Session.signOut()` with a local token clear → the reload assertion red.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none

Planned only (halt after planning). The ledger inbox is addressed: DW-1597 by AC5, DW-1648 by AC6 (decided (b)), and DW-1649 by AC7. `oversized`: seven ACs across the shell, the toast rule, the table and a shared test helper.
