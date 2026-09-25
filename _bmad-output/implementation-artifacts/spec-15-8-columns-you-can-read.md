---
title: 'Story 15.8: Columns you can read'
type: 'feature'
created: '2026-09-25'
status: 'done'
baseline_revision: '178758eedb7592a5f233dbe5db5bf8b89082970c'
baseline_commit: '178758eedb7592a5f233dbe5db5bf8b89082970c'
review_loop_iteration: 0
followup_review_recommended: true
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

## Spec Change Log

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
- mutation: hit area in flow at `height: 40px` alone → Geometry stays green, because `.ocu-data-table-row` fixes the height; with the row's `height` also turned into `min-height` → Geometry red (heights 41 and 36).
- mutation: link floor removed → harness DW-1586 red; the structural gate red with exactly the 4 `DW-1586` keys fresh.
- mutation: width stored under the column label → `column-widths` Integration AC red (it sizes Full name, whose label is not its field; on Name, label and field coincide and it stayed green).
- mutation: Home's Shortcuts `dl` removed → `home.page.spec.ts` Story 15.8 row red; `SHORTCUT_KEYS` naming an unknown key → `about.test` red.
- mutation: `layout` built over an empty label map → `data-table.spec.ts` "a header label wider than its kind's default floors its column" red.
- mutation: `hideTooltip` removed from `onViewportScroll`, `onWindowResize`, `onGridFocusOut` or `onTooltipLeave` → harness Dismissal red on its scroll, resize, blur or pointer-out case; the document capture listener for chords removed → Dismissal red on "Ctrl in the grid".
- mutation: `placeTooltip` always below the cell → harness Placement red.
- mutation: the sort arrow's `inline-size` removed → harness "Sorted or not" red.
- mutation: `resizeActiveColumn` floor 0 → harness "Keyboard floor" red (stored 85, drawn 101); the drag floor raised to the kind default → harness Drag red (narrowed only to 240).
- mutation: widths keyed by label in `resizeActiveColumn` → `column-widths` Integration AC red now that it sizes Name and Full name.

## Auto Run Result

Status: done
Blocking condition: none

**Change.** Kind-based column widths floored at the measured header label, sideways scroll inside the frame with the header following, a drag edge and Alt/Option+Shift+Arrow resize, widths in 15.5's `view` value, one fixed cut-cell tooltip, the name link's 24x24 floor, and the binding on Home's Shortcuts block.

**Files.** `core/table-model.ts` (layout helpers), `core/screen-store.ts` (widths in `view`), `shell/data-table.ts` (layout, resize, tooltip), `core/shortcuts.ts` and `areas/home/home.page.ts` (the binding), `core/strings.ts`, `styles/_components.scss`, `testing/table-harness/main.ts` (`widths`, `rememberedView`, `sort`), EXPERIENCE.md and DESIGN.md (amended rows), `structural-baseline.json` (4 DW-1586 keys removed), `angular.json` and `angular-json.test.mjs` (DW-1166), `browser/list-spec.mjs` (`clickRowCentre` clicks the visible part), two new browser specs, and tests in `table-model`, `screen-store`, `about`, `data-table.spec.ts` and `home.page.spec.ts`.

**Review.** 23 findings: 9 medium and 9 low. Patched: 6 medium entries and 4 low. Rejected: 4 low and 5 false, with reasons in the triage log. Nothing deferred. The one code change from review moves the chord hide to a document capture listener.

**Verification.** `test:tools` 1418/1418. `test:components` 1227/1227. `npm run build`: the seven checkers pass, initial total 1,590,090 B. `lint-docs` clean. The story's seven browser specs 54/54 on a redeployed bundle. Structural gate: 208 found, 208 in baseline, 0 fresh, 0 stale. Smoke on `ocupilot-ci`: 48 passed, 0 failed, 1 skipped. Full ObjectScript sweep on `ocupilot-ci`: 248 classes, 2041 tests. 14 classes refused at class level because this reused throwaway predates their arming variables (`OCUPILOT_ALLOW_TASK_CONTROL`, `_AUDIT_TOGGLE`, `_PROCESS_CONTROL`, `_ERROR_DELETE`, `_SERVICE_CONFIG`). The known `WireSecurityRead` task-history residue fails. The story has no `.cls` change. Every mutation line under `## Verification` was applied, seen red, and reverted.

**Follow-up review: recommended.** Six medium entries were patched. The chord hide's new document capture listener is proven only in the harness. Ctrl/Cmd+B in the real shell with a pointer tooltip showing is not asserted.

**Residual risks.** Most lists now scroll sideways at 1280 with the side bar and panel open. The full browser suite runs only in CI (Rule 29), and CI is the gate for specs that click far-right cells. The shared data-table CSS also reaches the error drill-down's grids.
