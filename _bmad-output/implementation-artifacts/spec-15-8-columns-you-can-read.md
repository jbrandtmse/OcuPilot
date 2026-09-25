---
title: 'Story 15.8: Columns you can read'
type: 'feature'
created: '2026-09-25'
status: 'done'
baseline_revision: '178758eedb7592a5f233dbe5db5bf8b89082970c'
baseline_commit: '54df59d3b7948ab415f3ed8f095fe63243863ea7'
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

**Problem:** Every list draws its columns as `minmax(0, 1fr)` or `minmax(0, 2fr)` (`data-table.ts:705-711`), so a path or class name is cut by an ellipsis nobody can read past. Columns cannot be resized, and a cut value cannot be recovered. DW-1586: a short name link renders under the 24px control floor.

**Approach:** Give each column a default width from its declared kind, floored at its header label's width. When the columns exceed the frame, scroll them sideways inside it, with the header following the body. Add a drag edge per header cell and a keyboard binding on the active cell. Remember the user's widths in 15.5's `view` value. Show a cut cell's whole value in a tooltip. Floor the name link at 24×24.

## Boundaries & Constraints

**Always:**

- **Default widths come from the column's `kind` alone, never from cell content** (AD-5; Story 6.11's no-reflow property). `name` and `identifier` 240px, `text` 160px, `number` and `status` 112px.
  - A column without a user width takes `minmax(<max(labelMin, default)>px, <default>fr)`, so a wide frame still fills.
  - A column with a user width takes `<max(labelMin, userWidth)>px`.
  - The trigger track is unchanged.
  - The header row and every body row carry the same template and a `min-width` equal to the sum of the track minimums.
- **`labelMin`** is the header label's natural width, plus the sort arrow's slot, the cell gap and the horizontal padding. It is measured in the header after render and again once `document.fonts.ready` settles. The arrow slot is reserved on every column, so sorting never cuts a label.
- **Horizontal scroll lives in the table's frame.** The viewport scrolls in both directions. `.ocu-data-table-head` is `overflow-x: hidden`, and its `scrollLeft` follows the viewport's on every scroll. The document never scrolls sideways (UX-DR19). Row and header heights stay `--ocu-row-height`.
- **Resizing never goes below `labelMin`.**
  - **Pointer:** a 24px-wide, full-height hit area centred on each data column's right edge. It is `aria-hidden`, not focusable, has a `col-resize` cursor, and shows a 3px × 20px `--ocu-outline` grip on hover and drag. It starts from the column's rendered width, and a drag neither selects a row nor selects text.
  - **Keyboard:** Alt/Option+Shift+Right and Alt/Option+Shift+Left resize the active cell's column by 16px. With no active data cell (row level, or the ⋮ column) they change nothing and announce nothing. A new width is announced in the table's existing polite status.
- **Widths are screen state in `ScreenStore`** (AD-19).
  - They are serialized into the existing `view` value as `widths: {<field>: <px>}`, holding only user-set columns. With none set, the value stays byte-identical to today's.
  - A stored width is a positive safe integer ≤ 2000, and an entry of any other shape is dropped on its own. Render ignores a field the table does not declare.
  - A value over `PREFERENCE_VALUE_MAX` is still not sent (the existing rule). Nothing is ever put in browser storage (AD-50).
- **The tooltip**, one per table:
  - **Shows** only on a cell whose text or link element is cut (`scrollWidth > clientWidth`, read when it would show). It shows after `--ocu-motion-tooltip-delay` when the pointer rests on the cell, and at once when the active cell moves onto the cell while the grid has focus.
  - **Placement:** `position: fixed` at the cell, flipped above when there is no room below, and clamped to the viewport. It is rendered outside the CDK viewport, beside the row menu, because the viewport's `transform` would re-anchor a fixed element.
  - **Text** is bound (no `innerHTML`, AD-11 rule 4).
  - **Accessibility:** it is `aria-hidden`, because the cell's full text is already what the active descendant announces. It meets WCAG 1.4.13: the pointer can move onto it, and it stays until the pointer or the active cell leaves.
  - **Escape** dismisses it through `OverlayStack`, as the row menu does.
  - **Hides** on scroll, on resize and on grid blur.
  - **Style:** DESIGN.md's tooltip recipe in bare roles (`--ocu-inverse-surface`, caption, `rounded.sm`, 5px 8px, elevation 2).
- `.ocu-data-table-link` is at least 24×24 CSS px, and its text still cuts with an ellipsis.
- The keyboard binding is listed in Home's Shortcuts block (Story 15.3's "shortcuts menu"), as text after the screen rows. It is not a control.
- New strings go into EXPERIENCE.md Fixed strings first, then into `strings.ts`, and are appended at both tails.

**Never:**

- No `title` attribute anywhere in `app-data-table` (DW-146).
- No component field holding user widths.
- No second preference kind or class, and no ObjectScript change.
- Do not edit `ui/src/app/app.ts` (contended with Epic 12).
- Do not touch the application error drill-down's own grids (`error-log.page.ts`, the `drill-down` archetype). They are not `app-data-table`.
- Do not touch the log viewers.
- Do not reorder the shared-append files.
- Do not write `deferred-work.md`, `sprint-status.yaml` or the cycle log.
- Never stop, `down` or recreate `ocupilot`, `ocupilot-ci` or any `ocupilot-slot-*` container.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Defaults | harness, no stored widths, 1280 wide | Tracks follow the kind rules above. No header label has `scrollWidth > clientWidth`, including on the sorted column. | none |
| Overflow | harness page 480 wide; Users at 720 | The viewport's `scrollWidth` is greater than its `clientWidth`. After scrolling, header cell *i* and body cell *i* have equal `left` (±0.5). The document's `scrollWidth` equals its `clientWidth`. | none |
| Drag | drag Name's edge +80, then −600 | Width is start+80, then stops at `labelMin`. The account write carries `widths.Name`. | none |
| Keyboard | active cell in column 2, Alt+Shift+Right ×2, then Left | +32, then −16. Status reads "<LABEL> column, <n> px wide". The active cell is unchanged. | row-level or ⋮: no change, no announcement |
| Reveal | Right into a column past the right edge | The viewport scrolls horizontally until the active cell is fully visible, and the header follows. | none |
| Restore | set a width, leave and return; sign out, sign in in a new context | The same px width, both times. Browser storage holds only the two token keys. | a failed write is the existing DW-1326 fault |
| Bad stored widths | `widths` is `[]`, `{"Name":-4}`, `{"Name":1.5}`, `{"Name":9999}` or `{"Gone":200}` | That entry is dropped. Sort, filter and max rows are adopted as before. | none |
| Cut cell | hover a 300-char Note; move onto the tooltip; press Escape | Shows after the delay with the whole value, stays while the pointer is on it, and hides on Escape. | none |
| Keyboard tooltip | the active cell moves onto a cut cell, then onto an uncut one | Shows at once, then hides. | none |
| Not cut | a short value, a skeleton cell, or "(none)" | No tooltip. | none |
| Geometry | after drag, keyboard resize, horizontal and vertical scroll | Every row and the header are 36px. | none |
| DW-1586 | a 1-character name (Devices, Users) | The link box is at least 24×24. | none |

</intent-contract>

## Code Map

- `ui/src/app/shell/data-table.ts`:
  - `:161-378` template: the header row `:208-234` and the body row `:243-322` bind `columnTemplate`;
  - `:705-711` `columnTemplate`;
  - `:778-821` `onGridKeydown` (Right/Left have no modifier check, so the new binding must come first);
  - `:984-987` and `:455` the polite announcement slot, reused for widths;
  - `:1150-1163` `scrollIntoRange` (vertical only);
  - `:1165-1203` the menu and `OverlayStack` pattern for Escape;
  - `:385-394` the `pendingFields` doc comment on the no-reflow property, which must stay true.
- `ui/src/app/core/screen-store.ts`:
  - `:47-53` `ScreenViewPreference`;
  - `:129-173` `adoptRemembered` and `storedView`;
  - `:453-463` `rememberView`;
  - `:62` `PREFERENCE_VALUE_MAX` 256, which equals `Pref.VALUEMAXLENGTH` and stays.
- `ui/src/app/core/account-preferences.ts` — the value is opaque, so there is no change. `VIEW_KIND` is at `:39`.
- `ui/src/app/core/table-model.ts` — framework-free table helpers such as `cellView` (`:86-120`). The new pure helpers go here (see Tasks). The kinds are `name | identifier | text | number | status` (`screens.generated.ts:302`).
- `ui/src/styles/_components.scss`:
  - `:2233-2360` the data-table rules: the frame `overflow: hidden`, the head `overflow-y: hidden`, the body `width: 100%`, and the link `min-width: 0`;
  - `:907-935` the rail tooltip recipe and `--ocu-motion-tooltip-delay`.
  - Append a tail block. The existing rules are edited only where a data-table declaration must change, and the task says which.
- `ui/src/app/core/shortcuts.ts` — Story 15.3's navigation roster. `ui/src/app/areas/home/home.page.ts:296-320` renders the Shortcuts block, and `:103-113` holds `ShortcutRow`.
- `ui/src/app/testing/table-harness/main.ts` and `testing/table-declaration.ts:30-37` — the harness has five columns, one per kind, and `window.ocuHarness.reread(rows)`. It is built by `ng build --configuration production,harness`.
- Browser precedents:
  - `browser/data-table.browser-spec.mjs:170-196` pins the 36px heights;
  - `browser/databases.browser-spec.mjs:92-129`, `:199` pin header/body alignment across the skeleton fill;
  - `browser/ui-state-survives-sign-out.browser-spec.mjs:178+` covers a fresh context after sign-out and the browser-storage check;
  - `browser/structural-walk.mjs:259-360`: the min-width and overflow checks skip anything under a clipping ancestor.
- `ui/browser/structural-baseline.json` holds 212 entries. The four `DW-1586` keys are `os-management/devices` and `permissions/users` × `min-width` × 1280 and 720, on `app-data-table>a.ocu-data-table-link`.
- `ui/tools/strings.test.mjs:744+` resolves every `/** EXPERIENCE.md:n */`. Appending a row at the Fixed strings tail (after `:512`) moves the one reference to `:553`, which becomes `:554`.
- Docs. The EXPERIENCE.md line numbers are as they stand before the Fixed strings append, which moves every line after `:512` down by one:
  - EXPERIENCE.md: `:573` (the data-table subsection's opening line, which holds "persisted per screen with sort and filter"); `:749` (the keyboard model's last data-table row); `:754` "No drag except the panel-resize-handle".
  - DESIGN.md: `:1042`, the data-table paragraph.
- `ui/angular.json:54` and `ui/tools/angular-json.test.mjs:377` hold `maximumWarning` `1577kB`. It measured 1,576,591 B at the Epic 9 merge, so any growth crosses it.

## Tasks & Acceptance

**Execution:**

- `ui/src/app/core/table-model.ts`, and its test `ui/tools/table-model.test.mjs` — add pure helpers and test each of them:
  - `COLUMN_DEFAULT_PX` (by kind);
  - `COLUMN_WIDTH_MAX = 2000`;
  - `COLUMN_RESIZE_STEP_PX = 16`;
  - `columnLayout(columns, userWidths, labelMins, hasTrigger)`, which returns `{ template, minWidthPx }` per the Always rules;
  - `resizedWidth(current, delta, min)`;
  - `formatColumnWidth(template, label, px)`.
- `ui/src/app/core/screen-store.ts`, with `ui/tools/screen-store.test.mjs`:
  - add `widths` to `ScreenViewPreference`, `columnWidths(): ReadonlyMap<string, number>`, and `setColumnWidth(field, px): boolean` (refusal as `setMaxRows`);
  - parse and serialize per the Always rules;
  - test the round trip, the byte-identical value with no widths, each bad-entry drop, the refusal, and the ">256 not sent" rule.
- `ui/src/app/shell/data-table.ts` — the layout, reading `store.columnWidths()` and measured `labelMin`s:
  - bind `columnLayout`'s template and `min-width` on the header and body rows;
  - sync the head's scroll to the viewport's;
  - reveal the active cell horizontally.
- `ui/src/app/shell/data-table.ts` — the input:
  - add the header resize hit areas with pointer capture;
  - add the Alt+Shift+Arrow branch ahead of the plain arrows, with its announcement;
  - add the one tooltip (show/hide rules, `OverlayStack` entry for Escape).
  - Label mins, the drag state and the tooltip are component-local layout, not screen state.
- `ui/src/app/testing/table-harness/main.ts` — optionally expose `widths()` for the spec.
- `ui/src/styles/_components.scss`:
  - in place: `.ocu-data-table-head` gets `overflow-x: hidden`; `.ocu-data-table-body` changes from `width: 100%` to `min-width: 100%`; `.ocu-data-table-header-cell` gets `position: relative`;
  - one tail block, `// --- Column widths (Story 15.8)`, holding: the link's 24×24 floor, the arrow slot, the resize hit area and grip, the tooltip, and the Home key entry.
- EXPERIENCE.md. Every edit carries `[AMENDED 2026-09-25, Story 15.8]`:
  - **Fixed strings:** append one row after `:512`, carrying `"Resize the active column" · "Alt/Option+Shift+Left or Right" · "<column> column, <n> px wide"`, with its Where column.
  - **`:573`:** "persisted per screen with sort and filter" becomes "persisted per screen with sort, filter and column widths". Then append the widths, resize, in-frame scroll and tooltip rules to that line, keeping it one line.
  - **Keyboard model:** insert a row after `:749`.
  - **`:754`:** now reads "No drag except the panel-resize-handle and a data-table header edge".
- `ui/src/app/core/strings.ts` — append `tableColumnResizeShortcut`, `tableColumnResizeKeys` and `tableColumnWidthAnnouncement` with `/** EXPERIENCE.md:n */` references, and update the `:553` reference.
- DESIGN.md `:1042` — append the kind widths, the grip and the tooltip recipe, line-neutral, with the same marker.
- `ui/src/app/core/shortcuts.ts` — export `SHORTCUT_KEYS` (one entry: the label key and the keys key), and pin it in `ui/tools/about.test.mjs`.
- `home.page.ts` and `home.page.spec.ts` — render `SHORTCUT_KEYS` as a `dl` with `kbd` after the screen rows or their empty state.
- `ui/src/app/shell/data-table.spec.ts` (jsdom):
  - the binding writes the store and announces;
  - with no active cell it does nothing;
  - plain Right still steps;
  - no `[title]` under the host.
- `ui/browser/data-table-columns.browser-spec.mjs` (new; harness; calls `resetRememberedState`) — matrix rows Defaults, Overflow (harness), Drag, Keyboard, Reveal, Cut cell, Keyboard tooltip, Not cut, Geometry, and the link floor.
- `ui/browser/column-widths.browser-spec.mjs` (new; throwaway; refuses `LIVE_CONTAINER`; clears its own preferences before and after, either through `resetRememberedState` or by declaring `preferences-reset-exempt` as `ui-state-survives-sign-out` does):
  - on `permissions/users` at 720: the Overflow row, and the DW-1586 name link at least 24×24;
  - the Restore row across a real sign-out.
- `ui/browser/structural-baseline.json` — delete the four `DW-1586` entries by hand.
- `ui/angular.json:54` and `ui/tools/angular-json.test.mjs:377` — **conditional:** only if the initial total exceeds 1577kB, apply DW-1166: set the warning about 5% above the measured total (1kB = 1,000 B). **HALT `blocked` before the total crosses 1900kB.**

**Acceptance Criteria:**

- **AC1.** Given a list, when it first renders, then each column is at least its kind's default (identifier and code wide, status and number narrow), and no header label is cut, sorted or not.
- **AC2.** Given columns wider than the content area, when the table renders, then it scrolls horizontally inside its frame, the header stays aligned to the body, and the page never scrolls sideways.
- **AC3.** Given a header edge, when the user drags it, then the column resizes and never goes below its label. Given an active data cell, when the user presses Alt/Option+Shift+Right or Left, then the column changes by 16px, the new width is announced, and Home's Shortcuts block lists the binding.
- **AC4.** Given a width the user set, when they return to the screen, or sign out and back in, then it is restored from the `view` row beside sort, filter and max rows. Nothing is in browser storage.
- **AC5.** Given a cut cell, when the pointer rests on it, or when the active cell moves onto it, then a tooltip shows its whole value. An uncut cell shows none, and no `title` attribute exists in the table.
- **AC6.** Given the fixed row height, when columns resize or the table scrolls either way, then the row and header heights stay 36px, and `data-table`, `databases` and `screen-height` browser specs stay green.
- **AC7 (DW-1586).** Given a short name, when its link renders, then it is at least 24×24. `a11y-structural-invariants.browser-spec.mjs` then reports 0 fresh and 0 stale keys, and the baseline holds 208 entries.
- **Integration AC (Rule 1).** Given the deployed bundle on `ocupilot-ci`, when `_SYSTEM` resizes Users' Name column, signs out and signs in in a new context, then `ListPage`'s table, which consumes `ScreenStore` → `AccountPreferences`, draws Name at the stored width.

### Rework 2 (CI)

- [x] [CI] browser: `data-table-columns.browser-spec.mjs:341` "Trigger reach" fails on CI's Linux Chrome at `:366`: `a sideways wheel over the frame brings the trigger inside it: {"inside":false,"hit":true,"x":437,"y":70.5,"box":[423,451],"frame":[17,448],"scrolled":470}` — run 36106266031 on 6bb8fb7f, https://github.com/jbrandtmse/OcuPilot/actions/runs/36106266031 (every other job and every other browser test green). The trigger's right edge (451) sits past the frame's (448) after the scroll settles. It passes on macOS, whose scrollbars are overlay (zero width); CI's are classic. Find whether the product clips the last column at maximum horizontal scroll when the frame has a classic vertical scrollbar (then fix the product) or whether the test measures the wrong box (then fix the measurement without weakening what it proves). Reproduce the classic-scrollbar geometry locally before concluding. Story 15.9 will pin the trigger column (DW-1648, decided); do not do that here.

### Rework 1 (CI)

- [x] [CI] browser: `resources-editor.browser-spec.mjs:339` ("Story 9.3: a probe is deleted from the row menu once its name is typed...") and `roles-editor.browser-spec.mjs:425` ("AC3: the Roles list's Delete states the holders...") both time out on `[role="row"][aria-selected="true"] .ocu-data-table-trigger` (visible) after `selectRow` — run 36100540000 on 0b7e3b69, https://github.com/jbrandtmse/OcuPilot/actions/runs/36100540000 — the row's action trigger is no longer reached once rows are wider than the frame. Reproduce both files on `ocupilot-ci` against a redeployed bundle, find the root cause, and make them green without weakening any assertion. Fix a test helper only if the product behavior is correct as shipped (the trigger reachable by a user through the frame's own horizontal scroll and by keyboard); if the product leaves the trigger unreachable, fix the product. Do not decide DW-1648 (the owner's call on column floors and on pinning the trigger column). Then grep every other browser spec that clicks the row trigger or a row by its center (`.ocu-data-table-trigger`, `clickRowCentre`, own `selectRow` helpers) and run each spec file whose path could be hit the same way (one file at a time is fine; never the full suite).

### Review Findings

Code review 2026-09-25 (four layers, full-opus). Patches applied in the review pass.

- [x] [Review][Patch] Widths past the 256-character view cap stopped the whole view being remembered, sort and filter included (med) — `rememberView` now leaves out widths earliest-set first until the value fits [ui/src/app/core/screen-store.ts:482]
- [x] [Review][Patch] The tail block's link, arrow and header-cell rules reached the error drill-down's grids, against the Never list (med) — scoped to `app-data-table`; the in-place head and body edits are the Tasks' own [ui/src/styles/_components.scss:5799]
- [x] [Review][Patch] The chord hide was proven only by the tooltip vanishing, never by the shell's bubble listener finding the stack empty (med) — jsdom case with a shell-side listener registered first [ui/src/app/shell/data-table.spec.ts:1050]
- [x] [Review][Patch] A press on a header edge with no width change stored a px width (low) — only a width-changing move counts [ui/src/app/shell/data-table.ts:1077]
- [x] [Review][Patch] A scroll of the page or an ancestor left the fixed tooltip detached (low) — document capture listener for ancestor scrolls; Dismissal case added [ui/src/app/shell/data-table.ts:697]
- [x] [Review][Patch] A vertical key move hiding the focus tooltip was untested (low) — Dismissal "vertical key" case [ui/browser/data-table-columns.browser-spec.mjs:487]
- [x] [Review][Patch] Geometry could not see content leaving a fixed-height row (low) — hit areas and name links asserted inside their rows [ui/browser/data-table-columns.browser-spec.mjs:385]
- [x] [Review][Defer] Kind-based floors make most lists scroll sideways at 1280 with the panel open, the ⋮ trigger off-screen until scrolled [ui/src/app/core/table-model.ts:280] — deferred: AC1 fixes the floors; DW-1648 decision-pending for the owner
- [x] [Review][Close] No way to return a sized column to its default, and widths past the cap hold for the session only (low) — wontfix-accepted, reopen_if a user or judge asks to reset a column width or reports one lost on a screen with more than five sized columns

Rejected:

- by-design: keyboard resize inert on an empty grid (Always: no active data cell changes nothing); the harness spec calling `resetRememberedState` (Tasks); tail-block overrides far from the table section (shared-append tail rule); the Home binding's wording (Fixed strings).
- false: `hideTooltip` leaving `hoverCellId` set (a dismissed tooltip re-arms on the next hover, WCAG 1.4.13); EXPERIENCE.md/DESIGN.md "the only resizable edge" (they scope to the shell's layout edges).
- low: no feedback on a keypress at the floor; `document.fonts.ready` already settled; `renderedWidth` fallbacks for undrawn or unknown-kind columns; all columns sized leaves no `fr` track; `TRIGGER_TRACK_PX` copies a token; tooltip `z-index` and literal `kbd` sizes; a partly scrolled cell's tooltip clamped to the window, not the frame; no Escape to cancel a drag; the Shortcuts `dl` with more entries; per-resize host listener; `pointercancel` commits the drawn width; a handle removed mid-drag; a tick changing a hovered cell's text; a tooltip stacked over an open menu; a header measured while hidden; a label wider than 2000px; `overflow-clip-margin` outside Chrome; undeclared widths never pruned.

Code review 2026-09-25, rework 1 re-review (four layers, full-opus, diff `11feffa4..HEAD`). 23 findings: high 0, medium 1, low 12, false 5 (grouped into 17 entries). The `[CI]` item is judged honest: only the helper changed, no assertion was weakened, and "Trigger reach" is falsifiable (the overflow mutation was re-observed red in this pass).

- [x] [Review][Patch] "Trigger reach" measured the wheel's result after a fixed 400 ms, but a wheel scroll starts asynchronously and can animate (low) — waits for the frame's scroll to reach its end [ui/browser/data-table-columns.browser-spec.mjs:353]
- [x] [Review][Patch] "Trigger reach"'s two "past the frame" assertions break if DW-1648 pins the trigger column, and nothing said so (low) — comment names DW-1648 and which assertions go [ui/browser/data-table-columns.browser-spec.mjs:340]
- [x] [Review][Patch] `clickRowCentre`'s doc comment stated the one-frame re-render as a rule of every filter and scroll (low) — now "can re-render" [ui/browser/list-spec.mjs:163]
- [x] [Review][Defer] `clickRowCentre` never checks where its click lands, so a render between its measurement and `page.mouse.click` still misclicks, and the caller then times out on the trigger (medium) [ui/browser/list-spec.mjs:311] — deferred: DW-1649, routed to 15-9. A post-click check reaches all 25 caller files.

Rejected (rework 1 re-review):

- low: the two-frame settle is a heuristic, and the callers' filter waits accept a prefix view. After `page.type` returns, the filter (not debounced, `command-bar.ts:864`) has one render pending, and the mutation reddens 339. reopen_if a `browser` job shows `clickRowCentre`'s "kept moving" error, or a trigger timeout after a filter-then-`clickRowCentre`.
- low: `roles-editor:425` was never reproduced, and the item was closed before CI. It runs the same filter, `clickRowCentre`, trigger path (`roles-editor.browser-spec.mjs:228-231`), and the lead resolves run 36105267145 before the next implement spawn (Rule 28).
- low: neither settle wait is pinned alone. The target wait covers a re-render after `scrollIntoView`, which 339's one-row path cannot produce.
- low: `triggerPlace` dereferences without a null check (the harness always renders row 1); `reduced-editors` and `tasks` never reached the click (residue, disclosed; CI's fresh container runs them); the cycle log's count of 24 specs (lead-owned); the Auto Run Result heading names every trigger clicker (the fix would edit the spec, and the triage above covers them).
- false: the harness is not the real screens (it mounts the same `app-data-table`, and reach is component behavior); the wheel half never checks `scrollLeft` (`inside` flips only through the frame's scroll); the keyboard half does no hit-test (reveal is asserted by `inside`); the final tree is unverified (`npm test` loads no `ui/browser` file, and this pass re-ran `client-lint`, `browser-reset` and `data-table-columns` 15/15); `status: done` against the tracker's `review` (the build-auto contract writes `done`).

Code review 2026-09-25, rework 2 re-review (four layers, full-opus, diff `54df59d3..HEAD`). 22 findings: high 0, medium 1, low 16, false 5 (grouped into 12 entries). The `[CI]` item is judged honest: the case measured the wrong box, and the product does not clip. A code-review probe with scrollbars painted (`--hide-scrollbars` removed, 15px classic style) scrolled to 485 with the trigger at `[408,436]`, inside the client edge at 448, and a point over the painted scrollbar hit-tested to the viewport.

- [x] [Review][Patch] No run painted a scrollbar, so a reveal that parks the trigger under a painted classic scrollbar stayed green in both runs and in Reveal on macOS; the product claim rested on an unrecorded probe (medium) — third run `painted`, a browser launched without `--hide-scrollbars`, asserting that its scrollbar is drawn; the reveal-to-frame-edge mutation reddens it alone [ui/browser/data-table-columns.browser-spec.mjs:375]
- [x] [Review][Patch] `placeInFrame` measured against the document's first viewport, not the element's own (low) — `element.closest` [ui/browser/data-table-columns.browser-spec.mjs:330]
- [x] [Review][Patch] The doc comments claimed an empty gutter shows content "with a list that fits", recorded history, and ran past 100 columns; the mutation block called an ancestor "the frame" and was split (low) — comments rewritten [ui/browser/data-table-columns.browser-spec.mjs:103]
- [x] [Review][Patch] The spec stated CI's 15px gutter as fact, quoted one run's box for both runs, called the new `within` "as in rework 1", and its residual risk no longer holds (low) — corrected at each origin in this file
- [x] [Review][Patch] The gutter-assertion mutation line did not say it reddens only on macOS (low) — line amended under Verification

Rejected (rework 2 re-review):

- by-design: on CI the platform and classic runs share one geometry (the classic run exists to give macOS CI's geometry).
- low: the left-edge hit-test has no mutation of its own (Rule 19 asks one per AC); the wheel wait checks stillness, not the end (timing gate only, reach is asserted by `inside`); `ocuLastScrollLeft`/`ocuStillFrames` page globals (one fresh page per run); a missing `aria-activedescendant` fails as a `TypeError`, not a named assertion (still red); reliance on Puppeteer's default `--hide-scrollbars` (the classic run now asserts `painted: false`, so a changed default reddens by name).
- false: `review_loop_iteration` and "patched no high" wording (the build-auto contract's fields).

## Spec Change Log

- 2026-09-25 rework 2 (runner, trigger=ci): re-opened for the red `browser` job of run 36106266031; item under Tasks › Rework 2.

- 2026-09-25 rework 1 (runner, trigger=ci): re-opened for the red `browser` job of run 36100540000; items under Tasks › Rework 1.

- 2026-09-25 spec gate (runner): `## Verification` gains the full ObjectScript sweep once before `dev_complete` (orchestrator ruling; Rule 29).
- 2026-09-25 implement: DW-1166 applied. The initial total measured 1,589,950 B (1kB = 1,000 B), past the 1577kB warning, so `maximumWarning` moves to 1670kB (5% above) in `ui/angular.json` and `ui/tools/angular-json.test.mjs`.
- 2026-09-25 implement: footprint extension `ui/browser/list-spec.mjs`. `clickRowCentre` now aims at the middle of the part of the target its scroll viewport shows and clicks that point, because a row wider than its frame put its middle outside the frame and reddened `screen-height` (AC6) on Audit and Locks.

## Review Triage Log

### 2026-09-25 — Review pass

- verdicts: 23 findings — high 0, medium 9, low 9, false 5, maybe-false 0
- findings:
  - `[medium]` `[patch]` Tooltip hides on scroll, resize, blur and pointer-out are unpinned — harness Dismissal case added, one mutation red per path.
  - `[medium]` `[patch]` The chord hide is unpinned and grid-only, so a pointer tooltip blocks Ctrl/Cmd+B and +I with focus elsewhere (shared root with the intent-alignment chord row) — the hide moved to a document capture listener; Dismissal covers Ctrl in the grid and Cmd outside it.
  - `[medium]` `[patch]` "Sorted or not" is never exercised at a label floor — harness `sort()` hook and "Sorted or not" case; arrow-slot mutation red.
  - `[medium]` `[patch]` The keyboard resize's label floor is pinned only in `resizedWidth` — harness "Keyboard floor" case; floor-0 mutation red.
  - `[medium]` `[patch]` The flip-above placement never runs — harness Placement case at 420px high; mutation red.
  - `[low]` `[patch]` Geometry's in-file mutation comment claims a result the spec records as false — comment now names the compound mutation.
  - `[low]` `[reject]` The Drag case's `selection: []` half cannot plausibly fail — it guards a stated clause at no cost; no user harm.
  - `[false]` `[reject]` Sub-clauses of AC1, AC2 and AC4 lack their own mutation lines — Rule 19 asks one per AC, and every AC has one.
  - `[low]` `[patch]` `template.split(' ')[2]` depends on Name's track shape — the assertion now matches both leading px tracks.
  - `[medium]` `[patch]` Measured label widths never reach an unsized track under test — jsdom case with 300px labels; empty-map mutation red.
  - `[low]` `[reject]` The `document.fonts.ready` re-measure is unexercised — needs font-load control; the Design Notes risk line covers it.
  - `[medium]` `[patch]` The Drag case cannot tell a label floor from a kind-default floor — Drag asserts below 240; default-floor mutation red.
  - `[low]` `[reject]` `{"Gone":200}` stays in the store and is re-saved — the Always rule has render ignore it; harm needs a field rename, and pruning needs the store to learn the declaration.
  - `[medium]` `[patch]` No hide path and no flip is asserted on any surface — same entry as the Dismissal and Placement rows above.
  - `[low]` `[reject]` No hide on an ancestor scroll, a panel resize or another column's keyboard resize — the spec names viewport scroll, window resize and blur, and a pointer tooltip already hides when the pointer leaves its cell.
  - `[medium]` `[patch]` Shell chords are inert while a pointer tooltip is stacked and focus is outside the grid — fixed with the chord row above; Escape reaching the tooltip first is the spec's rule.
  - `[false]` `[reject]` The drag's live width sits in a component signal — the spec's Tasks make drag state component-local; the committed width lives in the store.
  - `[low]` `[patch]` Geometry does not observe the hit area's own geometry — same entry as the Geometry comment row.
  - `[false]` `[reject]` `clickRowCentre` changes every list spec — it still hit-tests the exact point it clicks, and `screen-height` is green.
  - `[false]` `[reject]` The budget moved to 1670kB — DW-1166, measured 1,590,090 B.
  - `[false]` `[reject]` EXPERIENCE.md and DESIGN.md gain rows beyond the strings — the Tasks require them.
  - `[low]` `[patch]` The Integration case sized Full name, not the AC's Name — it now sizes both.
  - `[low]` `[patch]` Reveal and the keyboard tooltip are never combined — Reveal asserts the tooltip after its scroll.

### 2026-09-25 — Review pass (rework 1, CI)

- verdicts: 10 findings — high 0, medium 2, low 5, false 3, maybe-false 0
- findings:
  - `[low]` `[reject]` `roles-editor:425` never reddened locally, before the fix or under the mutation — its timing did not reproduce here; it runs the same filter-then-`clickRowCentre` path the pinning mutation reddens on `resources-editor:339`, and CI's `browser` job is its confirmation. Forcing it red needs CPU-throttling fault injection.
  - `[low]` `[patch]` The rework's mutation line is missing, and it does not isolate the two settle waits — lines added under Verification; each wait was disabled alone and 339 stayed green, so the two are redundant and the pinning mutation disables both.
  - `[low]` `[reject]` The rows wait keys on row boxes, so a late `document.fonts.ready` re-measure that moves cells is invisible to it — the fonts settle long before a signed-in list is filtered, and the target wait re-reads the target's own box after `scrollIntoView`.
  - `[low]` `[reject]` A stalled `requestAnimationFrame` leaves the 2000 ms limit unenforced — a foreground headless page always runs rAF, and a stall would still fail red on Puppeteer's protocol timeout, only with a less specific message.
  - `[false]` `[reject]` The helper's doc comment states a root cause nobody observed — the implement probe saw the pointerdown land on `%DB_IRISSYS`'s pre-filter position with the stale rows still drawn. The old in-evaluate hit-test passed because the re-render lands after it.
  - `[low]` `[reject]` The sweep never reached `reduced-editors:150` or `tasks:644` — this reused container's residue (no `OCUPILOT_ALLOW_SERVICE_CONFIG`; DW-1425/DW-1468) stops both before the click. CI's fresh container runs them.
  - `[medium]` `[patch]` The helper-only fix rests on an uncommitted probe that the trigger can be reached. Every committed trigger click scrolls the trigger into view by script — harness "Trigger reach" case added. At 480 the trigger starts outside the frame. A sideways wheel brings it inside, hit-testable, and a click opens the menu. Right into its column reveals it, and Enter opens the menu. Two mutations reddened it.
  - `[medium]` `[patch]` (intent alignment) The diff fixes a stale click point, not the trigger's reach, and has no artifact for the "product correct as shipped" gate — same entry as the row above.
  - `[false]` `[reject]` (intent alignment) Specs that open the trigger without `clickRowCentre` (`data-table:565`, `gate`, `ssl`, `structural-walk`, `error-log-actions`) are untouched — they click through `ElementHandle.click`, which measures at click time. The stale point exists only in `clickRowCentre`'s `mouse.click(x, y)`, and all of them were green in run 36100540000.
  - `[false]` `[reject]` (intent alignment) The reproduction and sweep leave no trace — they are recorded under Auto Run Result › Rework 1.

### 2026-09-25 — Review pass (rework 2, CI)

- verdicts: 11 findings — high 0, medium 0, low 8, false 3, maybe-false 0
- findings:
  - `[low]` `[patch]` The classic run never asserts that its injected gutter exists, so a later `scrollbar-width` rule could turn it into a copy of the platform run — the classic run now asserts `gutter >= 14` first; dropping the injected style reddens it (`gutter: 0`).
  - `[low]` `[patch]` The two "past the frame" assertions got weaker once `inside` also needed edge hit-tests — they now assert the geometric `within` alone, against the gutter-inclusive frame.
  - `[low]` `[patch, code review]` No run paints a classic scrollbar, so "no clip under a painted scrollbar" is unobserved — code review added the painted run.
  - `[low]` `[patch, code review]` (intent alignment) Same root cause as the row above: the painted case, the product question, is not exercised — same patch.
  - `[low]` `[reject]` (intent alignment) The keyboard half's frame includes the gutter while `revealActiveCell` reveals to `clientWidth` — under this launch the strict bound is unreachable (maximum scroll 470 leaves the trigger's right edge at 451, past `clientWidth`'s 448), and the edge hit-tests still require both edges to show.
  - `[false]` `[reject]` (intent alignment) The wheel wait proves less — the wait is only a timing gate; reach is asserted by `wheeled.inside`, and the `overflow-x: hidden` mutation still reddens it (`scrolled: 0`).
  - `[low]` `[patch, code review]` (intent alignment) The `margin-right: -24px` mutation proves clipping by an ancestor, not by a scrollbar — the painted run's reveal mutation proves the scrollbar case.
  - `[low]` `[patch]` (intent alignment) "15px, the width CI's Linux Chrome reserves" states an inference as fact — the comment now says the injected 15px reproduces CI's failure numbers exactly.
  - `[low]` `[patch]` (intent alignment) The DW-1648 comment still reads "if DW-1648 is decided" — it now says Story 15.9 pins the column and rewrites the two assertions.
  - `[false]` `[reject]` (intent alignment) The CI-reported "Trigger reach" is now two tests — a rename, not a defect; both names start with "Trigger reach".
  - `[false]` `[reject]` (intent alignment) No rework-2 entry under Auto Run Result — it is written at finalize.

## Design Notes

**Governing ADs (Rule 6):**

- **AD-19** — widths are store state, and `core/` stays framework-free.
- **AD-50** — the same `view` row. A new kind was considered and rejected: the AC says "beside".
- **AD-5 and the Conventions archetype row** — columns and kinds come only from the declaration.
- **AD-14 and AD-43** — a tick never touches the view.
- **AD-11 rule 4 and AD-47** — bound text, and no runtime evaluation.
- **AD-28 and AD-47** — no browser storage.
- **Conventions:** *Theme* (bare roles), *Angular naming* (tokens only), *Client asset homes* (`strings.ts`, `\uXXXX`).

No AC contradicts an AD.

**Why `fr` over a floor.** Fixed pixels would leave a wide frame half empty. `minmax(floor, weight fr)` fills the frame and overflows it only when the floors exceed the frame. A user-set column is plain pixels, so a drag lands where the pointer is.

**Why one tooltip, fixed.** The frame clips (`overflow: hidden`), and rows are recycled. A per-table `position: fixed` element is never clipped, and the gate skips `position: fixed`.

**"The shortcuts menu"** is Story 15.3's Home Shortcuts block (FR-73, `EXPERIENCE.md` Fixed strings "Shortcuts"). It lists screens, so the binding joins it as a separate text entry and does not become a fake route. The block's empty state keeps its condition, which is no screen row.

**Binding choice.**

- Plain Left/Right already step cells, and Alt+Left/Right is browser Back/Forward on Windows and Linux.
- Alt/Option+Shift+arrow is unbound in Chrome and matches the table's existing Alt/Option+Down family (inference: checked against Chrome's published shortcut list, not measured).
- The 16px step matches the panel handle.

**WCAG floor.** The project floor is WCAG 2.1 AA (NFR-12), so the keyboard path is the non-pointer alternative. 1.4.13 (content on hover or focus) applies to the tooltip, and the Always rules meet it.

**Ledger inbox (Rule 17):** DW-1586 is addressed by AC7 and by the baseline task.

**Footprint (Rule 11):**

- **Declared:** `shell/data-table*`, `core/account-preferences*` (unchanged), and the two new browser specs.
- **Shared-append:** `strings.ts`, `_components.scss` (a tail block plus three in-place data-table declarations), and the EXPERIENCE.md Fixed strings tail.
- **`footprint_extensions:`**
  - `core/screen-store.ts` and its test (the `view` value lives there);
  - `core/table-model.ts` and its test;
  - `core/shortcuts.ts`, `ui/tools/about.test.mjs`, and `areas/home/home.page.ts` with its spec (15.3's, this epic's own);
  - `testing/table-harness/main.ts`;
  - `ui/browser/structural-baseline.json`;
  - EXPERIENCE.md outside Fixed strings (`:573`, the keyboard row, `:754`), and DESIGN.md `:1042`;
  - conditionally, `ui/angular.json` and `angular-json.test.mjs`.
- `app.ts` is not touched.

**Consumes:** 15.5's `ScreenStore` and `AccountPreferences` `view` row; 15.3's Shortcuts block; the DW-1337 gate and baseline; `OverlayStack`; `preferences-reset.mjs`.

**Consumed-by:** every `app-data-table` host in this story (`ListPage`, and the Databases, Upcoming, History and Audit pages). No later story is known.

**Risk (inference):** `labelMin` is re-measured after `document.fonts.ready`, so a table could reflow once if a label outgrows its kind's default before the font loads. `databases.browser-spec.mjs`'s no-reflow check is the evidence.

## Verification

**Environment.** Slot A. The throwaway `ocupilot-ci` (52776/1975) is up and shared: never tear it down, and never touch `ocupilot`.

Browser runs:

1. `cd ui && npm run build && npx ng build --configuration production,harness`.
2. `docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`.
3. Export `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776` and `OCUPILOT_BROWSER_CONTAINER=ocupilot-ci`.

Run one test command at a time.

**Commands:**

- `(loop)` `cd ui && npm run test:tools` — green, including `table-model`, `screen-store`, `about`, `strings`, `browser-reset` and `angular-json`.
- `(loop)` `cd ui && npm run test:components` — green, including `data-table.spec.ts` and `home.page.spec.ts`.
- `(loop)` `cd ui && npm run build` — the seven prebuild checkers pass. Quote the initial bundle total.
- `(loop)` `cd ui && node --test --test-concurrency=1 browser/data-table-columns.browser-spec.mjs browser/column-widths.browser-spec.mjs browser/data-table.browser-spec.mjs browser/databases.browser-spec.mjs browser/screen-height.browser-spec.mjs browser/ui-state-survives-sign-out.browser-spec.mjs browser/a11y-structural-invariants.browser-spec.mjs` — green. The gate prints 0 fresh and 0 stale.
- `(loop)` `bash scripts/lint-docs.sh` — green over EXPERIENCE.md and DESIGN.md.
- `(once, before dev_complete)` `bash scripts/smoke.sh --container ocupilot-ci --user _SYSTEM --password SYS` — more than 0 checks, all passing.
- `(once, before dev_complete)` the full ObjectScript sweep on `ocupilot-ci`, even with no `.cls` change (orchestrator ruling, 2026-09-25): `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --package OcuPilot.Test` (it runs one class at a time). The runner recompiled the whole tree onto `ocupilot-ci` at 15.8's spec gate (0 errors); if `src/OcuPilot/**` is touched, re-sync `src/` into `/tmp/ocupilot-ci/src` and recompile before the sweep. `WireSecurityRead`'s task-history test is a known residue failure on this reused throwaway (DW-1425/DW-1468) and is not chased.
  - The full browser suite is not run locally (Rule 29).

**Mutations (Rule 19).** For each one: apply it, observe red, revert, and confirm the tree is byte-identical. Rebuild and redeploy before every browser read.

- AC1: `COLUMN_DEFAULT_PX.name` 240 → 40 → `table-model.test` red, and harness Defaults red (the label is cut).
- AC2: drop the head's scroll sync → harness Overflow red (header/body `left` differs).
- AC3: remove the `labelMin` clamp in `resizedWidth` → Drag red. Remove the announcement → the `data-table.spec.ts` keyboard test red.
- AC4: drop `widths` from `rememberView` → `screen-store.test` red, and `column-widths` Restore red.
- AC5: tooltip shown regardless of cut → Not cut red. Add `[title]` to the text span → the jsdom no-title test red.
- AC6: set the header resize hit area to `height: 40px` in flow → Geometry red.
- AC7: remove the link floor → the gate is red with 4 fresh keys.
- Integration AC: key widths by label instead of field → `column-widths` Restore red.

Results (2026-09-25, `ocupilot-ci`; each reverted, tree byte-identical by `shasum`; bundle or harness rebuilt and redeployed before every browser read):

- mutation: `COLUMN_DEFAULT_PX.name` 240 → 40 → `table-model.test` "each kind takes its default" red; harness Defaults red.
- mutation: head scroll sync removed from `onViewportScroll` → harness Overflow red.
- mutation: `resizedWidth` floor 1 instead of the label → `table-model.test` "a resize never goes below the label" red; harness Drag red.
- mutation: width announcement removed → `data-table.spec.ts` "resize … announce the width" red.
- mutation: `COLUMN_RESIZE_STEP_PX` 8 → harness Keyboard red.
- mutation: `widths` dropped from `rememberView` → `screen-store.test` "a width set on one store is restored" red; `column-widths` Integration AC red.
- mutation: `widths: {}` written with none set → `screen-store.test` "byte-identical" red.
- mutation: `storedWidths` accepts any number → `screen-store.test` "each bad entry is dropped" red; `setColumnWidth` without `isColumnWidth` → "refused" red.
- mutation: `cutText` ignores `scrollWidth > clientWidth` → harness Not cut red.
- mutation: the pointer timer shows the tooltip without `cutText`'s answer (`cutText(target) || 'x'`) → `data-table.spec.ts` "on a skeleton cell shows none" red.
- mutation: `[title]="cell.view.text"` on the text span → `data-table.spec.ts` no-title test red.
- mutation: pointer-out onto the tooltip hides it → harness Cut cell red; the tooltip's `OverlayStack` entry removed → Cut cell red (Escape).
- mutation: `revealActiveCell` skipped → harness Reveal red; `updateFocusTooltip`'s show removed → harness Keyboard tooltip red.
- mutation: hit area in flow at `height: 40px` → Geometry red ("every hit area and name link sits inside its row"; code review).
- mutation: link floor removed → harness DW-1586 red; the structural gate red with exactly the 4 `DW-1586` keys fresh.
- mutation: width stored under the column label → `column-widths` Integration AC red (it sizes Full name, whose label is not its field; on Name, label and field coincide and it stayed green).
- mutation: Home's Shortcuts `dl` removed → `home.page.spec.ts` Story 15.8 row red; `SHORTCUT_KEYS` naming an unknown key → `about.test` red.
- mutation: `layout` built over an empty label map → `data-table.spec.ts` "a header label wider than its kind's default floors its column" red.
- mutation: `hideTooltip` removed from `onViewportScroll`, `onWindowResize`, `onGridFocusOut` or `onTooltipLeave` → harness Dismissal red on its scroll, resize, blur or pointer-out case; the document capture listener for chords removed → Dismissal red on "Ctrl in the grid".
- mutation: `placeTooltip` always below the cell → harness Placement red.
- mutation: the sort arrow's `inline-size` removed → harness "Sorted or not" red.
- mutation: `resizeActiveColumn` floor 0 → harness "Keyboard floor" red (stored 85, drawn 101); the drag floor raised to the kind default → harness Drag red (narrowed only to 240).
- mutation: widths keyed by label in `resizeActiveColumn` → `column-widths` Integration AC red now that it sizes Name and Full name.
- mutation: `rememberView` sends nothing once widths pass the cap → `screen-store.test` "widths that would take the view past the instance's limit" red (code review).
- mutation: the chord listener registered in the bubble phase → `data-table.spec.ts` "a Ctrl/Cmd chord takes a showing tooltip off the overlay stack" red (code review).
- mutation: any pointermove counts as a drag → `data-table.spec.ts` "a press on a header edge … stores nothing" red (code review).
- mutation: the ancestor-scroll listener removed, or `afterActiveCellMoved` removed from the vertical move keys → harness Dismissal red on "ancestor scroll" or "vertical key" (code review).
- mutation (rework 1): both settle waits in `clickRowCentre` disabled → `resources-editor.browser-spec.mjs:339` red, with CI's signature (`TimeoutError` on `[role="row"][aria-selected="true"] .ocu-data-table-trigger`). Either wait disabled alone → 339 green: the two are redundant. `roles-editor:425` stayed green under the mutation (timing; CI confirms it).
- mutation (rework 1): `.ocu-data-table-viewport` given `overflow-x: hidden` → harness "Trigger reach" red (the wheel leaves the trigger outside the frame; re-observed after code review's scroll-end wait, with `!important`, `scrolled: 0`). `revealActiveCell` returning early on the trigger column → "Trigger reach" red (keyboard half). Harness rebuilt before each read.
- mutation (rework 2): "Trigger reach" now runs twice, with the platform's scrollbars and with injected classic 15px ones. Each rework-1 mutation was re-observed red in both runs: `overflow-x: hidden` on the viewport (`scrolled: 0`), and `revealActiveCell` returning early on the trigger column (keyboard half). The viewport given `margin-right: -24px`, so an ancestor clips it, is red in both runs through the edge hit-test alone: the box sits inside the geometric frame and its center hit-tests. Before the fix, the classic run was red locally with CI's exact signature (`box [423,451]`, `frame [17,448]`, `scrolled 470`). Harness rebuilt before each read.
- mutation (rework 2, review): the injected classic style dropped from the classic run → "Trigger reach (classic scrollbars)" red on its gutter assertion (`gutter: 0`) on macOS; platform run green. On CI's Linux Chrome the platform scrollbar keeps a gutter (inference), so this mutation reddens only on macOS. Reverted, `shasum` identical.
- mutation (rework 2, code review): `revealActiveCell` reveals to the frame's edge (`view.right - clientLeft`) instead of `clientWidth` → "Trigger reach (painted scrollbars)" red (`box [411,463]`, `painted: true`, the trigger cell under the scrollbar); the platform and classic runs and Reveal stayed green on macOS. `--hide-scrollbars` kept for the painted run → its `painted` assertion red. Harness rebuilt before each read; reverted, `shasum` identical.

## Auto Run Result

Status: done
Blocking condition: none

**Change.** Kind-based column widths floored at the measured header label, sideways scroll inside the frame with the header following, a drag edge and Alt/Option+Shift+Arrow resize, widths in 15.5's `view` value, one fixed cut-cell tooltip, the name link's 24x24 floor, and the binding on Home's Shortcuts block.

**Files.** `core/table-model.ts` (layout helpers), `core/screen-store.ts` (widths in `view`), `shell/data-table.ts` (layout, resize, tooltip), `core/shortcuts.ts` and `areas/home/home.page.ts` (the binding), `core/strings.ts`, `styles/_components.scss`, `testing/table-harness/main.ts` (`widths`, `rememberedView`, `sort`), EXPERIENCE.md and DESIGN.md (amended rows), `structural-baseline.json` (4 DW-1586 keys removed), `angular.json` and `angular-json.test.mjs` (DW-1166), `browser/list-spec.mjs` (`clickRowCentre` clicks the visible part), two new browser specs, and tests in `table-model`, `screen-store`, `about`, `data-table.spec.ts` and `home.page.spec.ts`.

**Review.** 23 findings: 9 medium and 9 low. Patched: 6 medium entries and 4 low. Rejected: 4 low and 5 false, with reasons in the triage log. Nothing deferred. The one code change from review moves the chord hide to a document capture listener.

**Verification.** `test:tools` 1418/1418. `test:components` 1227/1227. `npm run build`: the seven checkers pass, initial total 1,590,090 B. `lint-docs` clean. The story's seven browser specs 54/54 on a redeployed bundle. Structural gate: 208 found, 208 in baseline, 0 fresh, 0 stale. Smoke on `ocupilot-ci`: 48 passed, 0 failed, 1 skipped. Full ObjectScript sweep on `ocupilot-ci`: 248 classes, 2041 tests. 14 classes refused at class level because this reused throwaway predates their arming variables (`OCUPILOT_ALLOW_TASK_CONTROL`, `_AUDIT_TOGGLE`, `_PROCESS_CONTROL`, `_ERROR_DELETE`, `_SERVICE_CONFIG`). The known `WireSecurityRead` task-history residue fails. The story has no `.cls` change. Every mutation line under `## Verification` was applied, seen red, and reverted.

**Follow-up review: recommended.** Six medium entries were patched. The chord hide's new document capture listener is proven only in the harness. Ctrl/Cmd+B in the real shell with a pointer tooltip showing is not asserted.

**Residual risks.** Most lists now scroll sideways at 1280 with the side bar and panel open. The full browser suite runs only in CI (Rule 29), and CI is the gate for specs that click far-right cells. The shared data-table CSS also reaches the error drill-down's grids.

### Rework 1 (CI run 36100540000)

Status: done
Blocking condition: none

**Diff base** `11feffa40473a842a5fe76278ce246f15cf2445a`. Frontmatter `baseline_revision` is still the story's.

**Root cause.** Story 15.8 changed `clickRowCentre` from `page.click(selector)` to `page.mouse.click(x, y)`. The old call measured the target again at click time; the new one clicks a point measured a frame too early. The two specs type into the filter and then click. The list re-renders a frame later, so the click landed where `%DB_IRISSYS` used to be. No row became selected, and the trigger selector matched nothing. The product works: the trigger is 28x28 and visible, reachable by the frame's sideways scroll and by Right+Enter.

**Change.**

- `ui/browser/list-spec.mjs`: `clickRowCentre` measures only after the rows, and then the scrolled-in target, have held still for two animation frames. Either wait throws a named error after 2000 ms. No assertion was weakened.
- `ui/browser/data-table-columns.browser-spec.mjs`: new harness case "Trigger reach", from the review.

Column floors and the trigger column are untouched (DW-1648 is still the owner's).

**Review.** 10 findings. Patched: 1 medium entry (two rows) and 1 low. Rejected: 4 low and 3 false, with reasons in the triage log. Nothing deferred. Follow-up review: not recommended; this was a follow-up pass and patched no high.

**Verification** (`ocupilot-ci`; bundle and harness rebuilt and redeployed; one spec file per call).

- `npm run build`: the seven checkers pass. Initial total 1,590,556 B; no product code changed. `client-lint` clean after the review patch.
- The two red specs: `resources-editor` 6/6 (reproduced red before the fix) and `roles-editor` 8/8.
- `data-table-columns` 15/15.
- Every spec that clicks the trigger or uses `clickRowCentre`:
  - green: `oauth-delete` 2/2, `security-deletes` 4/4, `users-actions` 2/2, `web-applications-actions` 3/3, `task-schedule-actions` 4/4, `task-run` 2/2, `process-actions` 3/3, `processes` 8/8, `screen-height` 15/15, `audit` 7/7, `locks` 2/2, `users` 4/4, `web-applications` 4/4, `security` 4/4, `audit-events` 4/4, `audit-event-editor` 3/3, `error-log` 5/5, `oauth` 4/4, `rest-apis` 4/4, `ssl-editor` 7/7, `screen-grounding` 1/1;
  - `tasks` 13/15: the two Task history cases fail on residue (DW-1425/DW-1468) before any click;
  - `reduced-editors` 0/6: refused in setup, because `OCUPILOT_ALLOW_SERVICE_CONFIG` is not set on this container.
- No `src/OcuPilot/**` change, so no ObjectScript sweep.

**Residual risks.** `roles-editor:425` failed on timing and never reproduced locally, so the CI re-run is its proof. A list whose rows move for 2 s without pause now fails with a named error instead of clicking.

### Rework 2 (CI run 36106266031)

Status: done
Blocking condition: none

**Diff base** `54df59d3b7948ab415f3ed8f095fe63243863ea7`. Frontmatter `baseline_revision` is still the story's.

**Root cause (test).** The case measured the frame with `clientWidth`. That leaves out the `scrollbar-gutter: stable` gutter, which under Puppeteer's default `--hide-scrollbars` launch is reserved (15px on CI's Linux Chrome, inference) but never painted, and Chrome still draws and hit-tests content in it. The trigger was fully visible at maximum scroll (470), with its right edge 3px into the empty gutter. The scroll-end wait could never be met either. The product does not clip. In a probe with a painted classic scrollbar (flag removed, 200 rows), the scroll range reached 485 and the last column ended at the client edge.

**Reproduction.** On macOS, `openHarness` injects `::-webkit-scrollbar { width: 15px; height: 15px; }` through `page.addStyleTag`. Before the fix this reproduced CI's exact failure: `box [423,451]`, `frame [17,448]`, `scrolled 470`.

**Change** (`ui/browser/data-table-columns.browser-spec.mjs` only; no product code):

- "Trigger reach" runs twice, with platform scrollbars and with classic ones. The classic run first asserts that its gutter exists.
- `placeInFrame` measures the frame as the viewport's box inside its borders. `inside` also requires both edge columns of the element to hit-test to it. The negative assertions use the geometric `within`.
- The wheel wait now ends once `scrollLeft` is non-zero and has held still for three frames.
- The DW-1648 assertions are kept; Story 15.9 rewrites them.

**Review.** 11 findings. Patched 4 low: the gutter assertion, `within` on the negative assertions, and two comments. Rejected 4 low and 3 false, with reasons in the triage log. Nothing deferred. Follow-up review: not recommended. This was a follow-up pass and patched no high.

**Verification** (`ocupilot-ci`; harness rebuilt; bundle rebuilt and redeployed; one spec file per call):

- `npm run build`: the seven checkers pass, and the initial total is 1.59 MB.
- `data-table-columns` 16/16, green again after the review patches.
- `column-widths` 2/2.
- `client-lint`, `browser-reset` and `lint-docs` are clean.
- No product TS or CSS changed, so `a11y-structural-invariants` and `test:components` were not run.
- Mutations under `## Verification` were each red and reverted.

**Residual risks.** CI is the confirmation on Linux. The painted-scrollbar run, added by code review, has run on macOS only.
