---
title: 'Story 19.16: The data browser - export, shortcuts, go-to-row and tabs'
type: 'feature'
created: '2026-10-04'
status: 'done'
review_loop_iteration: 0
baseline_revision: '3f87f99543658f640a6e5cc3b881b7b1be5c1315'
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-19-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-19-7-the-data-browser-tree-grid-filter-and-sort.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-19-8-the-data-browser-editing-staging-and-export.md'
warnings: ['oversized', 'multiple-goals']
deferred: []
---

<intent-contract>

## Intent

**Problem:** Data browser (Stories 19.7 and 19.8) shows and edits one table at a time, reaches its actions only by pointer or Tab, moves only by page, and cannot hand a page to a spreadsheet. The classic Open Table page's remaining conveniences, which iris-table-editor also offers, are still missing: CSV export, keyboard shortcuts with a help dialog, go-to-row and several open tables.

**Approach:** All of it is client-side. No route, port, tool or server file changes.

- **Download CSV** writes the page on screen, as the instance read it, to a file built in the browser through `core/csv.ts`. It sends no request and reads nothing new.
- **Shortcuts** come from one declared table. The page handles them, and the help dialog lists them, so the dialog cannot name a chord that is not bound.
- **Go to row** takes an absolute row number and computes the offset to read.
- **Tabs** hold each open table's own state, including its staged changes, in a tab strip that follows the APG tabs pattern.

## Boundaries & Constraints

**Always:**

- **Export is the page as read** (AD-36, AD-39 drafts below).
  - Rows: the open tab's last `rows` answer, in page order, with at most the page size (500) rows and the answer's bound of 1,000,000 characters.
  - Header: the column names in ordinal order.
  - Each cell as the grid shows it (`cellView`): BIT as the yes and no words, binary in its `0x` form, and a cut cell as cut, ending U+2026. NULL is written empty, as the data table writes "(none)".
  - Staged values and new rows are left out. A row marked deleted is written as read.
  - `csvText` and `csvField` supply the byte-order mark, CRLF, RFC 4180 quoting and the `'` formula prefix. `csvFileName("<schema>.<table>", now)` names the file, and `saveCsv` saves it.
  - The export issues no read and sends nothing anywhere. No row value reaches a request, a log line, the ledger, an audit payload, screen context or a tool.
- **Shortcuts:** one table, `DATA_BROWSER_SHORTCUTS` in `core/data-browser-model.ts`, lists each chord's action, label key, keys key and matcher (Design Notes › Shortcuts). The page and the help dialog both read it.
  - **Where they act:**
    - Only while focus is inside Data browser's section. One capture-phase handler on that section reads them and stops the propagation of each chord it handles, so the grid never also acts on it (Alt/Option+Shift+Delete never reaches the grid's Delete).
    - Inert while a `[role="dialog"]` is in the document.
    - Inert while an editor is open, except Ctrl/Cmd+S, which first commits the editor.
    - Alt/Option chords are inert in a text field, so they still type characters there. Ctrl/Cmd chords act anywhere in the section.
  - **What a chord does:**
    - It performs exactly what its control does when that control is available, and nothing when it is not.
    - Every chord the page handles is kept from the browser (`preventDefault`), whether or not its control is available.
  - **What no chord may be:**
    - one of the twelve commands Chromium reserves (Design Notes › Shortcuts);
    - a zoom chord (Ctrl/Cmd with `=`, `-` or `0`);
    - reload (F5, Ctrl/Cmd+R);
    - the shell's Ctrl/Cmd+K, I or B;
    - Chrome's Alt+Shift A, B, R or T;
    - a single character key.
- **Go to row:**
  - Row `n` counts the rows the filters match, in the current sort. It is read at offset `floor((n−1)/size)·size`, which must not exceed the route's `MAX_OFFSET`.
  - With the total known, `n` runs from 1 to the total. With it unknown, `n` runs from 1 to `MAX_OFFSET + 1`, the furthest row an allowed offset reaches.
  - The active cell moves to that row, in the column it was in. Staged changes survive the move, since it is a page change.
- **Tabs** (`MAX_TABS` 8):
  - Each tab holds its own open object, filters and drafts, sort, offset, page size, last answer, refusal, announcement, `StagedChanges`, request and staging generations, saving flag and active cell. A read or save that answers for a tab, shown or not, changes only that tab, and changes nothing once the tab is closed.
  - The tree, the namespace and the tab list are the screen's.
  - The strip is Material's tab nav bar, as the detail page's (`MatTabNav`, already bundled). It is not AD-5's tab group: the tabs carry no route, and the URL never changes.
  - `FormDirty` reads dirty while **any** tab holds a staged row. `StagedChanges.count()` is unchanged, so DW-2053's counting is not touched.
- **Self-protection, bounds and writes** stay exactly as Stories 19.7 and 19.8 shipped them. A save is still one `explorer.sqldata.save` screen action for the active tab's table.
- **Accessibility:**
  - The tabs follow APG.
  - The help and go-to-row dialogs are the shell's `app-dialog`: they trap focus, return it to the opener, and never stack.
  - Every announcement goes to the polite status line.
  - Styling uses `--ocu-*` tokens only.
- **Harvest** (iris-table-editor, MIT, read-only; 19.7 shipped its notice): the chords, the go-to-row dialog and the desktop tab bar are re-checked, not copied (Design Notes › Harvest).

**Never:**

- A new route, port method, tool, governance key, error code, descriptor or `src/` file; a read beyond the page for export; an export carrying staged values or new rows.
- Any of these chords: a browser-reserved one (Ctrl/Cmd+N, Ctrl+Shift+N, Ctrl+T, Ctrl+Shift+T, Ctrl+W, Ctrl+F4, Ctrl+Shift+W, Ctrl+Tab, Ctrl+Shift+Tab, Ctrl+PageDown or Ctrl+PageUp), a zoom or reload chord, a single-character shortcut, or one overriding the browser while focus is outside Data browser.
- A tab past the eighth; a route or query parameter per tab; a second "are you sure" store beside `FormDirty`; a dialog stacked over another.
- A new third-party library; an edit to `core/csv.ts`, `shell/dialog.ts`, `core/form-dirty.ts`, `app.ts`, `screen-outlet.ts` or Home's Shortcuts block; `setTimeout` or `setInterval` in an area file (`ui/tools/refresh.test.mjs`).

## I/O & Edge-Case Matrix

The counts are the jsdom page specs' fixtures. The browser spec runs on `OcuPilot.Test.SqlSaveProbe`'s tables in `USER` on `ocupilot-a2-ci`, plus a 120-row table it creates in `OcuProbe198` and drops. "Chord" means the matcher in `DATA_BROWSER_SHORTCUTS`.

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Export | Rows 1–100 of 340. A NULL cell, a BIT 1, a cut stream cell and a value `=1+1`; one update and one new row staged | `ocuprobe198-edit-<YYYYMMDD>-<HHMMSS>.csv`: BOM, a header of the column names, 100 CRLF lines in page order, cells as read (NULL empty, `Yes`, the cut text ending U+2026, `'=1+1`), neither staged value present. Status: "Saved rows 1–100 to <file>, as the instance read them." | No request is issued |
| Export unavailable | Loading, no tab open, a `stopped`/`error` answer, or zero rows | Download CSV is `aria-disabled`; Ctrl/Cmd+E is kept from the browser and does nothing | None |
| Go to row | Total 340, size 100, `237` | Offset 200 is read, and row 237 is active (`aria-rowindex` 238) in the same column, with focus on the grid | None |
| Go to row refused | `0`, `341`, `1e3`, empty | The dialog stays open, the field `aria-invalid`, reading "Enter a row from 1 to 340." | In the dialog |
| Go to row, total unknown | Total `null`, size 100; `5000` while 120 rows exist | Offset 4900 is read and answers no row. Status: "No row 5000 here." | Status line |
| Open a second table | `Edit` open with staged rows; `Pair` opened from the tree | A tab for `Pair` opens, is selected and reads its first page. `Edit` keeps its page, filters, sort, staging and active cell. No dialog | None |
| Open an open table | `Edit` chosen again in the tree | `Edit`'s tab is selected, with no read | None |
| Cap | 8 tabs open; a ninth table chosen | Nothing opens. Status: "At most 8 tables can be open; close one first." | Status line |
| Close a clean tab | Delete on a focused tab, its ×, Alt/Option+Shift+W or Close tab | The tab closes at once and the tab to its right (else its left) is selected. Status: "<schema>.<table> closed." | None |
| Close a staged tab | The tab holds 3 staged rows | "Leave without saving?": Cancel keeps the tab and its rows; Confirm drops them and closes the tab | Dialog |
| Namespace switch | 3 tabs, one with staged rows | Every tab closes. Status: "Changes were discarded because the namespace changed." | None |
| Leave the route | Staged rows in two tabs | One "Leave without saving?". On leaving, every tab's staging is dropped; on return the tabs are open and nothing is staged | Dialog |
| Save chord | In the grid with staged rows; again with none | The save dialog opens; with nothing staged nothing opens. The browser's Save page never opens | None |
| Save chord in an editor | A valid value; a refused value | Commit, then the save dialog; the refused value keeps the editor open with nothing else opened | Editor hint |
| Inert | Alt/Option+Shift+N in a filter input; any chord with a dialog open; Ctrl+Tab | Nothing handled or prevented by the page | None |

</intent-contract>

## Code Map

- **Store** (`ui/src/app/areas/system-explorer/data-browser.store.ts`, 851 lines; this epic's own file):
  - one table's state is `DataBrowserState`'s fields :283-315, which move into a per-tab object;
  - the tree :275-281, :307 and the namespace :318 stay on the screen;
  - `openObject` :668-680 (discards staged rows today); `forget` :819-840; `save` :531-562 (its `stagingGeneration` guard :549);
  - `afterStaging` :583-588 and `discard` :516-523 (each calls `formDirty.setDirty`); `read` :789-813 with its `generation` :303; `writable` :409; `rows` :418-454.
- **Page** (`data-browser.page.ts`, 668 lines):
  - template :84-200; head actions :109-121; status line :178 and `statusLine` :480-495; the leave dialog :193-199;
  - `HELD` :47 keeps one state per screen store across visits;
  - the constructor's scope and destroy wiring :249-265; `onOpen` asks `FormDirty` today :517-522; `onPageKeydown` :642-652;
  - `activeRowId` :231.
- **Grid** (`data-browser-grid.ts`, 1007 lines):
  - outputs :374-396 (`paged`, `activeRow`); `activate` :625-630 (focuses the grid); `onGridKeydown` :668-696 (`pageKey` :677);
  - the editor's own keys `onEditorKeydown` :705 (it calls `stopPropagation`); `commit` :816; `focusGrid` :846;
  - the document-level `onChord` tooltip hide :454-465.
- **Model** (`ui/src/app/core/data-browser-model.ts`, 700 lines): `MAX_OFFSET` :35, `pageKey` :106-111, `pageCount` :131, `goToPageOffset` :145-154 (the template for row parsing), `cellView` :169-176, `StagedChanges` :480 (`count` :497).
- **CSV** (`ui/src/app/core/csv.ts`, reused unedited): `csvText` :34, `csvField` :27, `csvFileName` :62, `saveCsv` :76; tested by `ui/tools/csv.test.mjs`.
- **Dialog** (`ui/src/app/shell/dialog.ts`): `heading`, `closeLabel`, `closed` and the `dialogAction` slot :55-73. Initial focus goes to the first field, else Close; focus returns to the opener unless the parent has already moved it. `side-bar.ts:57` and `command-box.ts:49` show the "inert while `[role=dialog]`" check.
- **Tab strip to copy:** `shell/detail-page.ts:55-82` (`mat-tab-nav-bar`, `mat-tab-link`, `mat-tab-nav-panel`, `[disableRipple]`, `aria-label`) and `shell/form-tabs.ts:57-82` (a dot with `tabAccessibleName`). Styles: `_components.scss` `.ocu-detail-tabs` :2191-2240 and `.ocu-form-tab*` :5865-5910.
- **Unsaved work:** `core/form-dirty.ts`: `setDirty` :60, `requestLeave` :78 (a second question answers `false`), `answer` :101 (accepting clears the flag). The route guard is `app.routes.ts:78`.
- **Chords to stay clear of:** `app.ts:110` (Ctrl/Cmd+I), `side-bar.ts:57` (B) and `command-box.ts:49` (K).
- **Strings:** `core/strings.ts`. Data browser keys run to :5372 and `} as const` is at :5461. Reuse `tableDownloadCsv` :3248, `explorerSqlDataAddRow` :5312, `explorerSqlDataDuplicateRow` :5314, the "Delete row" key, `explorerSqlDataWaiting` :5334, `explorerSqlDataScopeDiscarded` :5346, `formLeaveWithoutSaving` :285, `actionConfirm` :107, `actionCancel` :109, `auditDialogClose` :470 (the shared "Close") and `explorerSqlDataNextPage`/`PreviousPage` :5193-5195.
- **Specs to follow and amend:**
  - `data-browser.page.spec.ts` (`mount` :110-175). Its cases at :567 (an older answer dropped) and :944 (opening another table asks) describe single-table behavior and are rewritten for tabs. :391 and :985 (namespace) become every-tab cases.
  - `data-browser-grid.spec.ts` (`mount` :34-54, `press` :60).
  - `ui/tools/data-browser-model.test.mjs`.
  - `ui/browser/system-explorer-data-browser-edit.browser-spec.mjs` (`structural` :91-115, `statusReads`, `clickNode`, the SqlSaveProbe `before`/`after`). Template for the new spec.
- **EXPERIENCE.md** (`_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/`):
  - the side-bar line :159; the closed dialog set :173; the Fixed strings table ends at :599 (the 19.8 row);
  - `### data-browser` :668-688: the Grid's page keys :674, Staging's "or opening another table from the tree, asks" :684;
  - the Keyboard shortcuts bullet :907.
- **Budgets:**
  - `ui/tools/strings.test.mjs:584` bounds the Fixed strings at 2,600. This branch holds 2,520 (measured with the test's extractor), and Story 18.7's working tree adds 58 more.
  - `ui/angular.json:54` `maximumWarning` is 2838kB, pinned at `ui/tools/angular-json.test.mjs:494`; the measured 2,837,977 bytes leave no headroom.

## Tasks & Acceptance

**Execution:**

- [ ] `ui/src/app/core/data-browser-model.ts`, add-only:
  - `MAX_TABS = 8`.
  - `goToRow(text, size, total)` → `{offset, index}` or `null`: 1 to 9 digits; `n` from 1 to the total, or to `MAX_OFFSET + 1` when it is unknown; offset at most `MAX_OFFSET`.
  - `rowRangeMax(total, size)`.
  - `pageCsvRows(columns, rows)`: each cell's `cellView` text, NULL empty.
  - `DATA_BROWSER_SHORTCUTS`, with `shortcutFor(event, place)` → the action or `null`:
    - `place` is `grid`, `tab`, `text` or `editor`; Delete closes only in `tab`, so the grid's Delete still stages NULL;
    - the event is a plain `{key, code, ctrlKey, metaKey, altKey, shiftKey}`, so the matcher runs under `node --test`;
    - a letter matches by `key`, case-insensitively, or under Alt/Option by `code` (macOS answers Option+Shift+letter with another character);
    - `/` ignores Shift, for layouts that type it with Shift.
- [ ] `ui/src/app/areas/system-explorer/data-browser.store.ts`:
  - A framework-free `DataTab` holds the per-tab state (Boundaries). `DataBrowserState` keeps the tree, the namespace and the tab list, and delegates the existing members (`open`, `answer`, `rows`, `edit`, `save`, `goTo`, filters, sort, paging) to the active tab, so the page's getters keep their names.
  - New members:
    - `tabs()`: id, label `<schema>.<name>`, staged count, active.
    - `selectTab(id)`.
    - `nextTab(step)`, which wraps.
    - `closeTab(deps, id)`, which announces "<label> closed." and selects the right neighbour, else the left.
    - `anyStaged()`.
    - `exportPage(now)` → `{text, fileName, first, last}` or `null`.
    - `goToRowNumber(deps, text)`, answering the row index to activate or a problem.
  - `openObject` selects an open table's tab, refuses past `MAX_TABS` with the cap line, or opens a tab with the active tab's page size. It no longer discards anything.
  - Every staging change, discard, save answer and close sets `FormDirty` to `anyStaged()`.
  - `forget` closes every tab and announces the namespace discard once when any tab held staged rows.
- [ ] `ui/src/app/areas/system-explorer/data-browser-grid.ts`:
  - `editorOpen()` and `commitInPlace(): boolean`, which commits without moving and answers whether the editor closed. A refused value stays open and answers `false`.
  - `place(id, column)`: set the active cell without moving focus, for a tab switch.
  - An `activeCell` output carrying the row id and the data column. `activeRow` is unchanged.
- [ ] `ui/src/app/areas/system-explorer/data-browser.page.ts`:
  - **The tab strip** above the head: `mat-tab-nav-bar` named "Open tables", each `mat-tab-link` holding:
    - the label;
    - while staged, a dot (`aria-hidden`), with ", <n> changes waiting to be saved." in the tab's accessible name;
    - a × (`aria-hidden`, pointer only, a 24 px target), whose click closes that tab without selecting it.
    - Delete on a focused tab closes it.
  - The head adds Download CSV, Go to row, Keyboard shortcuts and Close tab.
  - **The two dialogs:**
    - Keyboard shortcuts: a `<dl>` from `DATA_BROWSER_SHORTCUTS` with a one-line scope note, closed by "Close".
    - Go to row: a "Row number" field described by its range line, Go as `dialogAction`, Enter submitting, and Cancel.
  - **The capture-phase keydown handler** on the section: attached in the constructor through the section's `ElementRef` and removed on destroy. It reads `shortcutFor` with the place from the event target and the grid's `editorOpen()`.
  - **The close flow:** a tab with staged rows asks `formDirty.requestLeave()`. Confirm closes it; Cancel keeps it.
  - **Focus after a close:**
    - to the newly selected tab when focus was in the strip;
    - staying on Close tab when the close came from there;
    - to the tree when no tab is left.
    - Use `afterNextRender`, never a timer.
  - **Per tab:** each tab's active cell is restored through `place`, and switching resets the Page field draft.
  - **Export** calls `saveCsv(document, …)` with `exportPage(new Date())` and announces the export line.
- [ ] `ui/src/app/core/strings.ts` (end) and `ui/src/styles/_components.scss` (end): add-only. The keys are listed in Design Notes › Strings. The `ocu-data-browser-tab*` and `ocu-data-browser-shortcuts` rules use tokens only.
- [ ] EXPERIENCE.md:
  - :159 in place: add 19.16, and "in tabs".
  - :173 in place: add "keyboard shortcuts (Data browser, Story 19.16) · go to row (Data browser, Story 19.16)" with an `[ADDED 2026-10-04 - Story 19.16]` marker.
  - :674 in place: Alt/Option+PageDown and PageUp also change page.
  - :684 in place: "or closing a tab that holds staged changes" replaces "or opening another table from the tree".
  - New paragraphs after Saving: **Tabs**, **Go to row**, **Download CSV**, **Keyboard shortcuts**.
  - :907 in place: one sentence. Data browser captures its own chords only while focus is inside it, and lists them in its Keyboard shortcuts dialog.
  - One Fixed-strings row after :599.
  - Move every citation the suites hold (`npm run test:tools`).
- [ ] `ui/tools/strings.test.mjs:584`: unchanged in this story (lead, spec gate): 2,545 stays under 2,600, and whichever of Story 19.16 and Story 18.7 lands second raises the bound at the merge under the standing rule.
- [ ] `ui/angular.json` and `ui/tools/angular-json.test.mjs`: re-base `maximumWarning` to the measured build (DW-1166). Stop and ask above 3,800 kB.
- [ ] **Client tests:**
  - `ui/tools/data-browser-model.test.mjs`:
    - `goToRow`: bounds, a total of `null`, and `MAX_OFFSET`;
    - `pageCsvRows`, with `csvText` over it;
    - every `DATA_BROWSER_SHORTCUTS` row matching its chord in each place it acts;
    - no row matching any chord in the Never list or the shell's;
    - Alt rows inert in `text`;
    - each action appearing exactly once.
  - `data-browser-grid.spec.ts`: `commitInPlace` with a valid value and with a refused one; `place` moves no focus; `activeCell`.
  - `data-browser.page.spec.ts`: rewrite :567, :944, :391 and :985 for tabs.
  - A new `data-browser-tabs.page.spec.ts` for the matrix rows other than Export and Go to row, in jsdom:
    - each chord and its inert cases;
    - the strip's roles and names;
    - the close flow and its focus;
    - `FormDirty` aggregation;
    - a late answer landing in its own tab.
  - A new `data-browser-export.page.spec.ts` for Export, Go to row and the two dialogs.
    - It spies on `saveCsv` and asserts the file text.
    - It asserts that the export issues no request: the `ApiService` stub's call count is unchanged.
  - `ui/browser/system-explorer-data-browser-tabs.browser-spec.mjs` (new; SqlSaveProbe's `Make`/`Remove`):
    - AC12;
    - the CSV captured by wrapping `URL.createObjectURL` through `evaluateOnNewDocument`;
    - go-to-row across a page on a real total;
    - Delete closing a staged tab through the dialog;
    - the structural walk with two tabs open, and again with each dialog open;
    - a 120-row table created through `inUser` in `before` and dropped with the probe, for go-to-row across pages.

**Acceptance Criteria:**

- **AC1 (export, the page as read):** Given an open table showing a page with a NULL, a BIT, a cut cell and a value starting `=`, with an update and a new row staged, when Download CSV or Ctrl/Cmd+E is pressed, then:
  - one file is saved, named by `csvFileName` from `<schema>.<table>` (`ocuprobe198-edit-<YYYYMMDD>-<HHMMSS>.csv`);
  - it holds the BOM, the column names and one CRLF line per page row in page order;
  - each cell is as the grid shows it as read: NULL empty, the yes and no words, the cut text with its ellipsis, and `'` before `=`;
  - no staged value and no new row is in it;
  - the status line reads "Saved rows <first>–<last> to <file>, as the instance read them.";
  - with no rows to write, the control is `aria-disabled` and nothing is saved.
- **AC2 (bound, screen-only):** Given any page on screen, when it is exported, then the export issues no request and no read. The file holds at most the page's rows (at most 500), and no row value reaches a log line, the ledger, an audit payload, screen context or a tool.
- **AC3 (shortcuts):** Given focus inside Data browser with no dialog or editor open, when each chord in `DATA_BROWSER_SHORTCUTS` is pressed, then:
  - it does what its control does when the control is available, and nothing otherwise;
  - it is kept from the browser either way;
  - Alt/Option chords do nothing in a text field;
  - every chord does nothing while a dialog is open;
  - with an editor open, Ctrl/Cmd+S commits it and opens Save, while a refused value keeps the editor open and opens nothing;
  - no chord matches a browser-reserved, zoom, reload or shell chord, or a single character.
- **AC4 (help dialog):** Given Data browser, when Ctrl/Cmd+/ or Keyboard shortcuts is pressed, then the dialog lists every row of `DATA_BROWSER_SHORTCUTS` as its label and its keys. Escape or Close closes it, focus returns to the opener, and the dialog is one of EXPERIENCE.md's closed set.
- **AC5 (go to row):** Given a total of N rows at page size S, when Ctrl/Cmd+G or Go to row is used with `n`, then:
  - the page at offset `floor((n−1)/S)·S` is read, the filters and sort applying;
  - the active cell is on row `n` in its column, with focus on the grid;
  - staged changes survive;
  - an `n` outside the range keeps the dialog open, `aria-invalid`, with "Enter a row from 1 to <n>.";
  - a page holding no row `n` reads "No row <n> here.".
- **AC6 (tabs keep their state):** Given a table open in a tab, when another table is opened from the tree, then it opens in a new selected tab, and an open table's tab is selected instead, with no read. Each tab keeps its filters, sort, offset, page size, page, staged changes and active cell across switches, and an answer for a tab lands only in that tab.
- **AC7 (cap):** Given eight open tabs, when a ninth table is opened, then nothing opens and the status line reads "At most 8 tables can be open; close one first.".
- **AC8 (closing):**
  - Given a tab, when it is closed by its ×, by Delete on the tab, by Alt/Option+Shift+W or by Close tab, then:
    - a tab with nothing staged closes at once;
    - one with staged rows asks "Leave without saving?", where Cancel keeps it and its rows and Confirm drops them and closes it;
    - the right neighbour, else the left, is selected;
    - "<schema>.<table> closed." is announced.
  - Focus moves to the selected tab when it was in the strip, stays on Close tab when it was there, and moves to the tree when no tab is left.
- **AC9 (unsaved work across tabs):** Given staged rows in any tab, when the person stages, leaves the route or switches the namespace, then:
  - `FormDirty` reads dirty;
  - leaving the route asks once and drops every tab's staging, the tabs staying open for a return;
  - a namespace switch closes every tab and says "Changes were discarded because the namespace changed." when any held staged rows;
  - Save changes (n) and the save dialog count as Story 19.8's do.
- **AC10 (accessibility, as the portal):**
  - Given the strip, when it is used from the keyboard and read by assistive technology, then:
    - the tablist is named "Open tables";
    - each tab is named by its table, plus ", <n> changes waiting to be saved." while staged;
    - one tab is `aria-selected`;
    - Left and Right move, Enter or Space selects, and Delete closes;
    - the panel is labeled by the selected tab.
  - Both dialogs trap focus and return it.
  - The announcements are polite.
  - The structural walk adds no entry at 1280 light, 720 light and 1280 dark, with two tabs open and with each dialog open.
- **AC11 (page keys, DW-2031):** Given the grid, when Alt/Option+PageDown or PageUp is pressed, then the next or previous page is read, as Ctrl/Cmd+PageDown and PageUp still do where the browser passes them. The help dialog lists the Alt/Option form.
- **AC12 (Integration, Rule 1):** Given two probe tables open in tabs on the real instance, when a value is staged in the first, the second tab is selected and then the first again, and Ctrl/Cmd+S and Proceed are pressed, then SQL query's (Story 19.6) SELECT on that table returns the new value.

### Review Findings

Code review 2026-10-04 (full-opus; blind-hunter, edge-case-hunter, verification-gap, acceptance-auditor). 54 rows, 37 entries: 13 patched, 3 deferred, 21 rejected. No high. The patches grew the bundle to 2,859,344 bytes, so `maximumWarning` moves to 2860kB (DW-1166).

- [x] [Review][Patch] (med) The tab chord pressed in the grid dropped focus to the body with the old grid, so a second press did nothing [ui/src/app/areas/system-explorer/data-browser.page.ts:runShortcut]
- [x] [Review][Patch] (med) On a return to the route the tab's stored active cell was not drawn, so Delete and Duplicate row acted on a row the grid did not show active; a cell whose row is gone is now let go [data-browser.page.ts:afterTabChange]
- [x] [Review][Patch] (med) Ctrl/Cmd+S from an editor: the grid's deferred focus landed after the save dialog's, leaving focus behind the modal [data-browser-grid.ts:commitInPlace]
- [x] [Review][Patch] (med) Go to row and a tab switch never scrolled the active cell into view [data-browser-grid.ts:activate, place]
- [x] [Review][Patch] (med) Go's continuation acted on whichever tab and dialog were current when its page landed, or on a destroyed page [data-browser.page.ts:onGoToRow]
- [x] [Review][Patch] (med) A late save answer for a tab still open after a return was unpinned: the namespace-switch test now reaches the closed check first [data-browser.page.spec.ts]
- [x] [Review][Patch] (med) The export's row numbers were pinned only at offset 0, and a row staged for delete before an export not at all [data-browser-export.page.spec.ts]
- [x] [Review][Patch] (med) The chords browser spec's `includes('101')` failed on any date or time holding 101 in the exported file name [ui/browser/system-explorer-data-browser-chords.browser-spec.mjs:263]
- [x] [Review][Patch] (low) A namespace switch with only clean tabs had no assertion that no discard line shows [data-browser.page.spec.ts:392]
- [x] [Review][Patch] (low) Opening an open table with eight tabs open was unpinned [data-browser-tabs.page.spec.ts:198]
- [x] [Review][Patch] (low) A Go refused from the Go button left focus on Go and announced nothing [data-browser.page.ts:onGoToRow]
- [x] [Review][Patch] (low) A chords spec mutation comment named a Delete case the test never presses [system-explorer-data-browser-chords.browser-spec.mjs:242]
- [x] [Review][Patch] (low) Two test titles read "what any staged" [data-browser.page.spec.ts:36, :1042]
- [x] [Review][Defer] (low) "<table> closed." after the last tab lands in a newly inserted status region (inference) [data-browser.page.ts:272]. Deferred: DW-2063, wontfix-accepted.
- [x] [Review][Defer] (low) A negative number is written with the formula guard (`'-12.5`) [core/csv.ts]. Deferred: DW-2061, by-design (csv.ts is reused unedited).
- [x] [Review][Defer] (low) Ctrl/Cmd letter chords match by key only, so they miss on a non-Latin layout [core/data-browser-model.ts:controlLetter]. Deferred: DW-2062, by-design (the Tasks' matcher).

Rejected:

- false:
  - Head controls carry no chord: EXPERIENCE.md :916 says Data browser lists its chords in its dialog.
  - Chords inside a dialog are not prevented: the spec makes them inert, with nothing prevented.
  - The chords spec is untracked: the lead commits QA's file with the story.
- low, spec-literal:
  - "No row <n> here." is ungrouped (the matrix reads "No row 5000 here.").
  - Delete on a tab ignores Backspace.
  - The scope note's "no editor" wording.
  - A grouped "1,234" row number is refused (the spec allows 1 to 9 digits).
  - The grid's `activeRow` output is unconsumed (the Tasks keep it).
  - No tab shows no Download CSV, rather than an `aria-disabled` one.
  - The structural walk runs at two tabs only (the AC; DW-1978 holds the strip).
- low, not worth the change:
  - "No row <n> here." on a page cut short by the character bound (a fallback read departs from the offset formula).
  - Cancel during an in-flight Go still lets its read land.
  - A tree click at the cap clears a refused Page draft.
  - Auto-repeat of a held chord.
  - A newer read superseding Go's read during a save.
  - Closing a tab during its save (the shape 19.8 accepted for leaving the route).
  - Redundant assertions: Save changes (0) after a reopen, dirty after destroy, model :331.
  - `rowRangeMax`'s `?? MAX_OFFSET + size` and `goToRow`'s offset guard never bind.
  - EXPERIENCE.md :671, Go to row's unavailable state, and the dialog's own row.
  - The duplicated mount harness.
- spec edits, for the lead:
  - Boundaries :60 and Tasks :148 say `MAX_OFFSET + size`. The build's "1 to 100,000,000" is right: every row past it reads at an offset past `MAX_OFFSET`.
  - Design Notes' "26 literals" and 2,546 against 25 keys and 2,545.

## Spec Change Log

- 2026-10-04, lead (after code review): with the total unknown, go to row runs to `MAX_OFFSET + 1` (Boundaries and Tasks), as built; the string count is 25 literals, 2,545 of 2,600.
- 2026-10-04, lead (spec gate): the spine carries the drafted AD-36 and AD-39 clarifications (a CSV of the page built in the browser); EXPERIENCE.md :159, :173, :674, :684 and :907 in place are approved (:173 unioned by hand with Epic 18's at merge); the bundle re-base is pre-authorized under DW-1166; the Fixed-strings bound is not raised here (2,545 of 2,600), the second to land raises it; opening a table opens a tab, replacing 19.8's ask on opening, accepted.

## Review Triage Log

### 2026-10-04 — Review pass

- verdicts: 27 findings — high 0, medium 2, low 15, false 10, maybe-false 0
- findings:
  - `[medium]` `[patch]` FormDirty after closing, discarding or saving one of two staged tabs is untested (verification-gap) — added the tabs spec's two-staged-tabs case; each of the three regressions turns it red.
  - `[low]` `[patch]` Go to row's unavailable state and Ctrl/Cmd+G there are untested (verification-gap) — added the export spec's unavailable Go to row case.
  - `[medium]` `[patch]` Per-tab page size, and a new tab taking the selected tab's, is untested (verification-gap) — added the tabs spec's page-size case.
  - `[low]` `[patch]` A staged tab's close mark could select that tab unseen (verification-gap) — the staged-close case asserts Pair stays selected after Cancel.
  - `[low]` `[patch]` The Page field's reset on a tab switch is untested (verification-gap) — the page-size case types a refused page, then asserts Pair's field starts over.
  - `[low]` `[patch]` Both "late answer to a closed tab" checks could not fail, since a closed tab is never drawn (verification-gap) — added a direct `DataBrowserState` case reading the closed tab's own state after a late page and a late save; grouped with the closed-tab save row below.
  - `[low]` `[patch]` The leaving-the-route case clicked through the destroyed fixture (verification-gap) — it now clicks and settles the remounted page and asserts the tab selected.
  - `[false]` `[reject]` The grid keeps Ctrl/Cmd+PageDown and PageUp, which Chromium reserves (intent-alignment) — AC11 keeps them "where the browser passes them" in the intent itself.
  - `[low]` `[patch]` A keys string agrees with its matcher only through the hand-kept fixture (intent-alignment) — each `CHORDS` row now names its keys, and the model test holds every `keysKey` string equal to it.
  - `[false]` `[reject]` The unknown-total range reads 100,000,000, not `MAX_OFFSET + size` (intent-alignment) — `MAX_OFFSET` is 99,999,999, so every row past 100,000,000 lands on an offset the same Boundaries bullet forbids; the line names the furthest reachable row, and a fix would edit this spec.
  - `[false]` `[reject]` Status lines are tested with `startsWith` (intent-alignment) — the polite line joins the announcement and the rows line, as Stories 19.7 and 19.8 already do.
  - `[false]` `[reject]` Ctrl or Cmd is accepted on any platform (intent-alignment) — the shell's own chords follow the same convention.
  - `[low]` `[patch]` A select counted as a text field, so Alt/Option chords were inert on Rows per page (intent-alignment) — `shortcutPlace` reads only `input`, `textarea` and `[contenteditable]` as text; the Alt/Option chords case adds a row from the select.
  - `[low]` `[patch]` On a layout such as Dvorak the physical-key fallback made Alt+Shift+B (Chrome's) add a row (intent-alignment, inference on Chrome's accelerator reading) — `optionShiftLetter` falls back to `code` only when the key is no ASCII letter; the model's reserved-chord case adds each forbidden letter on the three physical keys.
  - `[false]` `[reject]` Alt/Option+Shift+W closes the selected tab, Delete the focused one (intent-alignment) — the chord stands for Close tab, which closes the selected tab; Delete is APG's key on the focused tab.
  - `[low]` `[patch]` Ctrl/Cmd+E with no tab open is untested (intent-alignment) — the export unavailable case presses it on the tree first.
  - `[false]` `[reject]` The strip sets Material's tab properties with literal sizes (intent-alignment) — the detail page's `.ocu-detail-tabs` carries the same literals, and every custom property the rules read is an `--ocu-*` token.
  - `[false]` `[reject]` Three new files sit under `ui/src` (intent-alignment) — the Never list's `src/` is the server tree, beside "no route, port, tool or server file".
  - `[low]` `[reject]` No Alt/Option chord runs in the real-browser spec (intent-alignment) — the matchers are pure functions of the event's fields, run under `node --test` with macOS and other-layout values; a browser leg would add runtime for no new input.
  - `[low]` `[patch]` No test presses a chord with focus outside Data browser (intent-alignment) — the inert case presses Ctrl/Cmd+/ on a button outside the page and asserts nothing prevented and no dialog.
  - `[low]` `[reject]` "The URL never changes" has no router assertion (intent-alignment) — the diff adds no router call for tabs.
  - `[low]` `[patch]` A save answering a closed tab is untested (intent-alignment) — covered by the direct closed-tab case above.
  - `[low]` `[reject]` APG Space, Home and End in the strip are untested (intent-alignment) — a native button's Space and Material's key manager carry them unchanged.
  - `[low]` `[reject]` Leaving the route is driven through `FormDirty`, not a router navigation (intent-alignment) — the route guard is Story 19.8's unchanged wiring, and this story's surface is the `FormDirty` question and the destroy path.
  - `[false]` `[reject]` A return after leaving shows "<n> changes discarded." (intent-alignment) — Story 19.8's discard on leaving reads the same line.
  - `[false]` `[reject]` "<table> closed." and the cap line land on the selected tab's status line (intent-alignment) — that line is the page's one polite status line.
  - `[false]` `[reject]` The export's absence from logs, the ledger and screen context is not asserted directly (intent-alignment) — `exportPage` reads only the held answer, and its announcement carries row numbers and the file name.

## Design Notes

**Decisions (for the spec gate):**

- **Export writes the page as read and excludes what is staged.** A file mixing unsaved values with saved ones would be read as the table's data. So the file is what the instance answered for the page, and the status line says so.
  - Building from the page already held keeps AD-36's bound with no new read.
  - The file is the person's own copy, made in the browser as Story 16.23's Download CSV is, and nothing crosses the server.
  - The spine's "reach the screen only" wording for these rows predates any export, so it is amended to say so (below).
- **Opening a table opens a tab.** Story 19.8's "opening another table from the tree asks" (its AC11 leg, EXPERIENCE.md :684) existed only because opening a table replaced the open one. With tabs, nothing is replaced, so the question moves to closing a tab that holds staged rows, through the same `FormDirty` question (AD-11 rule 3).
- **Cap of 8 tabs.** Each tab holds at most one page of up to 1,000,000 characters (AD-36), so the cap bounds the browser at about 8,000,000. Eight `<schema>.<table>` labels are about as many as the paged strip keeps reachable at 1280 px (inference; DW-1978's nine-tab strip hid three to five tabs below 1600 px). The harvest has no cap.
- **A namespace switch closes every tab.** A table belongs to its namespace, AD-44 makes the namespace data scope, and Story 19.7 already forgets the open table on a switch.
- **Tabs are a screen's in-page state, not AD-5 tab groups.** They carry no route, and the screen keeps one descriptor, no read and no context field.
- **No server change, so no ObjectScript.** The full sweep in Verification confirms the merged tree only.

**Shortcuts.** Chromium never delivers twelve commands to a page (`BrowserCommandController::IsReservedCommandOrKey`, main branch, read 2026-10-04): close tab, close window, new incognito, new isolated, new tab, new window, restore tab, select next and previous tab, cycle to next and previous tab, and exit. On Windows and Linux these are Ctrl+W, Ctrl+F4, Ctrl+Shift+W, Ctrl+Shift+N, Ctrl+T, Ctrl+N, Ctrl+Shift+T, Ctrl+PageDown, Ctrl+PageUp, Ctrl+Tab and Ctrl+Shift+Tab (`chrome/browser/ui/accelerator_table.cc`). The same table binds Alt+Shift A, B, R and T. Firefox and Safari are best effort (NFR-11; inference).

| Action (label) | Keys | Acts when | Why this chord |
|---|---|---|---|
| Keyboard shortcuts | Ctrl/Cmd+/ | always | Chrome binds Ctrl+/ to its help page, which is not reserved; the harvest's desktop opens its shortcuts with it |
| Save changes | Ctrl/Cmd+S | Save changes is available | Save page is not reserved; an open editor commits first |
| Go to row | Ctrl/Cmd+G | the tab answered rows | Chrome's find next, not reserved; the harvest's go-to chord |
| Download CSV | Ctrl/Cmd+E | the page holds a row | bound to no reserved command (Chrome focuses its search box, inference); the harvest's export chord |
| Add row | Alt/Option+Shift+N | Add row is available | the harvest's Ctrl+N is reserved; Alt/Option+Shift is the product's chord family (the data table's resize) |
| Duplicate row | Alt/Option+Shift+D | Duplicate row is available | the harvest's Ctrl+D is the bookmark chord |
| Delete row | Alt/Option+Shift+Delete or Backspace | Delete row or Restore row is available | the harvest's Ctrl+- is zoom out; Backspace covers macOS's delete key |
| Next or previous page | Alt/Option+PageDown or PageUp | Next or Previous is available | Ctrl+PageDown and Ctrl+PageUp are reserved tab switches (DW-2031); the grid keeps them for where they arrive |
| Next or previous tab | Alt/Option+Shift+PageDown or PageUp | two or more tabs (wraps) | Ctrl+Tab and Ctrl+PageDown are reserved; the arrows still move inside the strip (APG) |
| Close tab | Alt/Option+Shift+W, or Delete on a tab | a tab is open | Ctrl+W and Ctrl+F4 are reserved; Delete on a focused tab is the APG deletable-tab key |

Not bound:

- Discard changes, which drops work with no question.
- Refresh, because the browser's reload is never intercepted (EXPERIENCE.md, Refresh), and Chrome's Alt+Shift+R is its reading mode.
- Clear filters.
- A single-character `?`, because no single-character shortcut exists (EXPERIENCE.md :907).

**Harvest** (iris-table-editor 29971a9, read through a subagent):

- **Re-checked, not copied:**
  - its chords: `grid.js:5894-6015`; Ctrl+N, Ctrl+- and Ctrl+Shift+N reach no page or zoom; Ctrl+PageDown checks Ctrl only;
  - its go-to-row, which is page-relative: `grid.js:2334-2434`, a range of `rows.length + newRows.length`;
  - its desktop tab bar: `desktop/src/ui/tabs/tab-bar.js`, with no cap, a native `confirm()` on close and right-then-left focus;
  - its CSV, which writes raw values with no formula prefix: `grid.js:5294-5310`.
- **Lifted:** reselecting an open table's tab, and the right-then-left neighbour on close.
- **Not carried:** global `document` key handling; dialogs that leave chords live behind them; `announce` without clearing; the server-side all-rows export.

**Strings.** 25 literals in one Fixed-strings row after :599:

- **Labels:** "Open tables", "Close tab", "Go to row", "Row number", "Go", "Keyboard shortcuts", "Save changes", "Next or previous page", "Next or previous tab".
- **Lines:**
  - "<table> closed." and "At most <n> tables can be open; close one first.";
  - "Enter a row from 1 to <n>." and "No row <n> here.";
  - "Saved rows <first>–<last> to <file>, as the instance read them.";
  - "These work while focus is in Data browser and no dialog or editor is open."
- **Keys:** "Ctrl/Cmd+/", "Ctrl/Cmd+S", "Ctrl/Cmd+G", "Ctrl/Cmd+E", "Alt/Option+Shift+N", "Alt/Option+Shift+D", "Alt/Option+Shift+Delete or Backspace", "Alt/Option+PageDown or PageUp", "Alt/Option+Shift+PageDown or PageUp", "Alt/Option+Shift+W, or Delete on a tab".
- **Reused:** "Download CSV", "Add row", "Duplicate row", "Delete row", "<n> changes waiting to be saved.", "Leave without saving?", "Confirm", "Cancel", "Close", and "Changes were discarded because the namespace changed.".
- **Budget:** 2,520 + 25 = 2,545 on this branch. With Story 18.7's 58 in flight, the union reaches about 2,603, above 2,600. Raising the bound to 2,700 is recommended; it is a contended edit, so the lead decides (or the second to land raises it).

**Spine amendments (draft, for the lead's gate; clarifications, apply-and-report):**

- **AD-36**, after "A data browser page (Story 19.7) is a screen-only payload too …":

  > A person may save the page on screen to a CSV file built in the browser (Story 19.16): the rows the page read, cells as the grid shows them, never a staged value, with no new read and no request, so the page's bound is the file's [AMENDED 2026-10-04, Story 19.16 spec gate, Rule 20].

- **AD-39**, the sixth exception, after "A data browser page's rows, SQLCODE and message reach the screen only too (Story 19.7)":

  > and a CSV file of that page the person saves in the browser (Story 19.16), which no request carries [AMENDED 2026-10-04, Story 19.16 spec gate, Rule 20].

**Integration ACs:** AC12.

**Consumes:**

- Story 19.7's grid, paging, `MAX_OFFSET` and tree;
- Story 19.8's `StagedChanges`, save path, leave dialog and `FormDirty` handling;
- Story 16.23's `core/csv.ts`;
- the shell's `app-dialog`, and the detail page's `MatTabNav` strip;
- SQL query (Story 19.6) for AC12.

**Consumed-by:** none planned. Story 19.11 decides whether page rows ever reach the model, and that decision does not touch the export, which reaches only the person.

**ADs:** AD-3, AD-5, AD-10, AD-11, AD-19, AD-20, AD-24, AD-36, AD-39, AD-43, AD-44, AD-47, AD-53, AD-61.

**Footprint (Rule 11).** Checked 2026-10-04 against `.worktrees/epic-18` at `71c38bb69f86ec6148484f3ad172233119a92b3c`, both committed and `status -s` (18.7 implementing).

- **Contended, add-only:**
  - `ui/src/app/core/strings.ts` (end; Epic 18 adds 123 lines);
  - EXPERIENCE.md's new row and paragraphs;
  - `_components.scss` (end; not in Epic 18's tree today).
- **Contended, not add-only (lead approval):**
  - EXPERIENCE.md :173 (Epic 18 edits it in place; union by hand);
  - `ui/tools/strings.test.mjs` (Epic 18 raises the same bound);
  - `ui/angular.json` with `angular-json.test.mjs`;
  - the spine (AD-36 and AD-39 sentences appended).
- **Not add-only, not contended:** EXPERIENCE.md :159, :674, :684 and :907.
- **Not contended:** the data browser's store, page, grid, model and their specs (this epic's); `data-browser-model.test.mjs`; every new file.
- **Not edited:** `core/csv.ts`, `shell/dialog.ts`, `core/form-dirty.ts`, `app.ts`, `screen-outlet.ts`, `screens.generated.ts`, every roster test and every `src/` file.

**Ledger inbox:** this story owns no entry.

- DW-2053 stays closed, because the staged count is unchanged.
- DW-2031's limit is met by AC11 (the Alt/Option page chord) and the help dialog. Its entry is terminal, so the lead may append an `occurrence` or leave it as it is.

## Verification

Build and deploy before any browser result: `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-a2-ci:/durable/iris/csp/ocupilot/`. Run one test-runner call at a time, wait for it, and never re-submit after a client-side timeout. Never restart `ocupilot-a2-ci`, and never touch `ocupilot-ci` or `ocupilot`. The browser specs make and remove SqlSaveProbe's `OcuProbe198*` objects themselves.

**Commands:**

- `cd ui && npm run test:tools` (loop): expected green. It covers the model, csv, strings and EXPERIENCE.md citations.
- `cd ui && npx ng test --include 'src/app/areas/system-explorer/data-browser*.spec.ts'` (loop): expected green.
- Browser (loop), each file alone as `OCUPILOT_BROWSER_ORIGIN=http://localhost:52780 OCUPILOT_BROWSER_CONTAINER=ocupilot-a2-ci node --test --test-concurrency=1 browser/<file>`, for:
  - `system-explorer-data-browser-tabs.browser-spec.mjs` (new);
  - `system-explorer-data-browser.browser-spec.mjs`;
  - `system-explorer-data-browser-edit.browser-spec.mjs`;
  - `a11y-structural-invariants.browser-spec.mjs`.
  - Expected green. The full browser suite is CI's.
- `bash scripts/lint-docs.sh && cd ui && npm run test:tools` (loop, after each EXPERIENCE.md edit): expected green.
- `cd ui && npm test && npm run build` (once, before dev_complete): expected green, with the budget re-based.
- `cd ui && node tools/ci-runner.mjs --container ocupilot-a2-ci`, the full ObjectScript sweep, one class at a time (once, before dev_complete). Expected green apart from the known residue. The story changes no ObjectScript, so a red here is not this story's code.

**Planned mutations (Rule 19)**, one per AC:

- mutation: AC1, `DataTab.exportPage` writes the overlaid rows (`this.rows()`) -> `data-browser-export.page.spec.ts` "writes the page as read..." red, and, rebuilt and copied in, the tabs browser spec's AC1, AC2 leg red ("b is written as read, not as staged"); `pageCsvRows` writes NULL as its word -> `data-browser-model.test.mjs` "a page writes as the grid shows it..." and the export spec's file case red. The page ignores chords while no tab is open -> the export spec's no-row case red on its no-tab Ctrl/Cmd+E.
- mutation: AC2, the page's export reads the page again before it saves -> the export spec's file case red on the request count (5, not 4).
- mutation: AC3, `shortcutFor` drops the Alt-in-text exclusion -> `data-browser-model.test.mjs` "an Alt/Option chord does nothing in a text field..." and "every shortcut row matches its chords..." red, and `data-browser-tabs.page.spec.ts` "inert: ..." red; the page's Ctrl/Cmd+S skips the editor's commit -> the tabs spec's "Ctrl/Cmd+S in an editor commits it..." red; `commitInPlace` answers `true` without committing -> `data-browser-grid.spec.ts` "commitInPlace commits a value..." and the same tabs case red. `optionShiftLetter` matches the physical key whatever the key reads -> the model's reserved-chord case red (Dvorak's KeyN as Alt+Shift+B); a select counts as a text field -> the tabs spec's Alt/Option chords case red; the handler listens on the document -> the tabs spec's inert case red; `onOpenGoToRow` drops its `goToRowBlocked` guard -> the export spec's unavailable Go to row case red.
- mutation: AC4, the Keyboard shortcuts dialog lists a copy one row short of `DATA_BROWSER_SHORTCUTS` -> the export spec's "lists every DATA_BROWSER_SHORTCUTS row..." red. A keys string drifts from the chord its matcher binds (Add row's to `Alt/Option+Shift+A`) -> the model's one-row-per-action case red.
- mutation: AC5, `goToRow` reads offset `n * size` -> the model's go-to-row case, the export spec's two Go to row cases, and, rebuilt and copied in, the tabs browser spec's AC5 leg red.
- mutation: AC6, a new table replaces the selected tab -> the tabs spec's "a second table opens in its own selected tab..." red, with seven other tabs cases; the per-tab request generation check dropped -> the tabs spec's "a page answers only the tab that asked..." and `data-browser.page.spec.ts` "a slow first table's answer fills its own tab..." red; `place` focuses the grid -> the grid spec's "place makes a cell active without moving focus..." red. A new tab takes `DEFAULT_PAGE_SIZE` -> the tabs spec's page-size case red; `afterTabChange` keeps the Page field's draft -> the same case red; `DataTab.read` drops its closed checks and `close` its generation bump -> the tabs spec's closed-tab state case red.
- mutation: AC7, `openObject` checks the cap one tab late (`>`) -> the tabs spec's cap case red.
- mutation: AC8, the page's close skips `requestLeave` for a staged tab -> the tabs spec's staged-close case and the page spec's rewritten opening-another-table case red, and, rebuilt and copied in, the tabs browser spec's AC8 leg red. The close mark's click reaches its tab (`stopPropagation` dropped) -> the tabs spec's staged-close case red.
- mutation: AC9, `afterStaging` sets `FormDirty` from the selected tab alone -> the tabs spec's `FormDirty` case red; the page drops its `onScopeChange` subscription -> the page spec's two rewritten namespace cases and the tabs spec's namespace case red; `forget` counts no discarded row -> the page spec's namespace-discard case and the tabs spec's namespace case red. `closeTab` drops `stagingChanged`, `discard` sets `FormDirty` clean, or `save` sets it from its own tab -> the tabs spec's two-staged-tabs case red, each alone.
- mutation: AC10, a tab's name drops the staged suffix -> the tabs spec's strip case and staged-close case red.
- mutation: AC11, the page's handler drops the Alt/Option page row -> the tabs spec's Alt/Option chords case red.
- mutation: AC12, `DataBrowserState.save` saves the tab opened last rather than the selected one, rebuilt and copied in -> the tabs browser spec's AC12 leg red.
- (QA) `ui/browser/system-explorer-data-browser-chords.browser-spec.mjs`, 4/4 on `ocupilot-a2-ci` (AC1, AC2, AC3): the CSV's bytes (BOM, CRLF, the `'` guard on `=`, `+`, `-`, `@`, quoting, NULL empty, a cut cell, no staged value) with no http request under interception; the chords from an editor, a text field, the Rows per page select and the tab strip; reserved chords not prevented.
- mutation: AC1, `csvField` drops the formula guard -> chords spec "the CSV guards a formula cell..." red.
- mutation: AC3, `shortcutFor` drops the editor exclusion -> chords spec "in an editor only Ctrl/Cmd+S acts..." red.
- mutation: AC3, `shortcutPlace` counts a select as a text field -> chords spec "from the tab strip, the Rows per page select and a filter field..." red.
- mutation: AC3, the export row also binds Ctrl+T -> chords spec "a browser-reserved, zoom, reload or tab chord..." red. Each was applied to a rebuilt, redeployed bundle, reverted, rebuilt and redeployed, and the four specs read green; the sources were `cmp`-identical after the revert.
- (CR) Each new pinning test went red against the code before its patch, or against the mutation named, reverted `cmp`-identical. After the patches: data-browser component specs 83/83; `npm run test:tools` 1,814/1,814; and on `ocupilot-a2-ci`, bundle rebuilt and copied in, each run alone: tabs 4/4, chords 4/4, edit 3/3, data browser 2/2.
- mutation: AC3, `commitInPlace` leaves the grid's focus to after the next render -> tabs spec "Ctrl/Cmd+S in an editor commits it..." red (focus behind the save dialog).
- mutation: AC5:
  - `activate` scrolls nothing into view -> export spec "reads the page holding row n..." red;
  - a refused Go leaves focus on Go -> export spec "a number outside 1 to the total..." red.
- mutation: AC6:
  - the page restores no tab's active cell on mount -> tabs spec "on a return to the route..." red;
  - the tab chord leaves focus where it was -> tabs spec "each Alt/Option chord..." red;
  - `onGoToRow` ignores a change of tab -> export spec "a Go whose page lands after..." red;
  - `openObject` checks the cap before an open table -> tabs spec cap case red;
  - `DataTab.save` drops its staging-generation check -> page spec "a save answering after the route was left..." red.
- mutation: AC1, `exportPage` numbers rows from 1, or leaves out a row staged for delete -> export spec "a page past the first names its own rows..." red, each alone.
- mutation: AC9, `forget` counts a clean tab as discarded -> page spec "a namespace switch closes every tab, drops an answer..." red.

## Auto Run Result

Status: done
Blocking condition: none

**Plan pass.**

- **Read:** the spine, the epic context, specs 19.7 and 19.8, and the data browser's client code. The harvest was read through one read-only subagent. Chromium's reserved-command list and accelerator table were read from source on 2026-10-04.
- **Measured:** the Fixed-strings count, with the test's extractor, and Epic 18's in-flight additions.
- **Instance:** no probe was needed, because the story changes no server code. No IRIS object was created.
- **Tree:** it held only the lead's write-ahead line for this spawn (`cycle-log-epic-19.md`). This pass wrote only this spec and committed nothing.
- **Size:** one pass, client-only. It carries `multiple-goals`, since the criterion names four features.
- **For the gate:**
  - the two spine clarifications (AD-36, AD-39);
  - the Fixed-strings bound raised to 2,700, a contended edit;
  - the bundle re-base;
  - EXPERIENCE.md :173 edited in place beside Epic 18's edit there;
  - the cap of 8;
  - the export excluding staged values;
  - opening a table now opening a tab rather than asking (Design Notes › Decisions).

**Implement pass.**

- **Change:** Data browser opens each table or view in a tab of its own (cap 8, per-tab state, `FormDirty` over every tab, close through 19.8's leave dialog), saves the page on screen as a CSV built in the browser from the held answer, goes to an absolute row, and handles one table of chords that its Keyboard shortcuts dialog lists. Client only: no `src/` file changed, so the ObjectScript sweep was waived (CI runs it).
- **Files:**
  - `ui/src/app/core/data-browser-model.ts`: `MAX_TABS`, `goToRow`, `rowRangeMax`, `pageCsvRows`, `DATA_BROWSER_SHORTCUTS`, `shortcutFor`, `shortcutStep`.
  - `ui/src/app/areas/system-explorer/data-browser.store.ts`: `DataTab` per tab; `DataBrowserState` keeps the tree, namespace and tab list and delegates to the selected tab.
  - `ui/src/app/areas/system-explorer/data-browser-grid.ts`: `editorOpen`, `commitInPlace`, `place`, the `activeCell` output.
  - `ui/src/app/areas/system-explorer/data-browser.page.ts`: the strip, the four head actions, the two dialogs, the capture-phase handler, the close flow and focus.
  - `ui/src/app/core/strings.ts`, `ui/src/styles/_components.scss`: 25 keys and the strip, list and field rules (tokens only); one forced citation move (`taskCreate` :640 to :641).
  - `ui/angular.json`, `ui/tools/angular-json.test.mjs`: `maximumWarning` 2859kB (measured 2,858,653 bytes, DW-1166).
  - EXPERIENCE.md: :159, :173, the Grid and Staging paragraphs and :916 in place; the Fixed-strings row at :600; the Tabs, Go to row, Download CSV and Keyboard shortcuts paragraphs.
  - Tests: `data-browser-tabs.page.spec.ts`, `data-browser-export.page.spec.ts` and their harness `ui/src/app/testing/data-browser-page.ts` (new); `data-browser-grid.spec.ts`, `data-browser.page.spec.ts`, `ui/tools/data-browser-model.test.mjs` (amended); `ui/browser/system-explorer-data-browser-tabs.browser-spec.mjs` (new).
- **Review:** two layers ran (verification-gap, intent-alignment); Blind Hunter and Edge Case Hunter are disabled by the project's customization. 27 findings: 13 patched (medium 2, low 11), 4 low rejected, 10 false, none deferred (Review Triage Log). Code patches: `optionShiftLetter` reads the physical key only when the key is no ASCII letter, and a select is no longer a text field. The rest add pinning tests, each with a demonstrated mutation in Verification.
- **Follow-up review:** `false`. Two medium entries were patched, both test additions whose mutations each turned red, so no unverified risk can be named.
- **Verified:** `npm run test:tools` 1,814 pass; the data-browser component specs 79 pass; `npm test` (1,814 tools, 2,431 components) and `npm run build` green, no budget warning; on `ocupilot-a2-ci`, after rebuilding and copying the bundle in, each run alone: tabs 4/4, data browser 2/2, edit 3/3, structural walk 12/12; `bash scripts/lint-docs.sh` clean. Thirteen review-pass mutations each turned their test red, and every revert left the tree byte-identical.
- **Residual risks:**
  - While the total is unknown the range line reads 100,000,000, the furthest row the route reads, not the literal `MAX_OFFSET + size`.
  - Merge contention: EXPERIENCE.md :173 and the `angular.json` budget (Epic 18 edits both), and `strings.ts`'s `taskCreate` citation.
  - Fixed strings 2,545 of 2,600.
  - Option chords on a non-US macOS layout match by physical key (inference).
  - DW-2053 stays closed: `StagedChanges.count()` is unchanged.
