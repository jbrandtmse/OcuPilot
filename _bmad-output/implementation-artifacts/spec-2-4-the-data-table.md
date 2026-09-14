---
title: 'Story 2.4: The data table'
type: 'feature'
created: '2026-09-14'
status: 'done'
baseline_revision: '1ef51e57d017c51d99db714bff24a6d1cda7017d'
baseline_commit: '1ef51e57d017c51d99db714bff24a6d1cda7017d'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md'
  - '{project-root}/_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/DESIGN.md'
warnings: ['oversized']
deferred:
  - summary: >-
      A table column over a read field that `context.secretFields` names is not refused, and the screen read returns that field's value unmasked, so a later list could draw a secret in a cell.
    evidence: |-
      Neither `Registry.TableProblem` nor `screen-mirror.mjs` `tableProblem` checks columns against `context.secretFields`, and `OcuPilot.Screen.Read` does not mask secret fields; DESIGN.md renders secret values as a mask. No descriptor declares a table before Story 2.5.
    location: >-
      src/OcuPilot/Screen/Registry.cls TableProblem; ui/tools/screen-mirror.mjs tableProblem
    severity: medium
---

<intent-contract>

## Intent

**Problem:** Every list screen (Stories 2.5-2.10) needs one table that looks and behaves the same and stays usable at 1,000 rows, and nothing renders rows yet: no list archetype page, no "read now" (a screen whose rate is off never loads), a command-bar filter wired to nothing, and five ledger entries (DW-17, DW-18, DW-141, DW-162, DW-172) waiting for the first screen with rows.

**Approach:** A framework-free table model in `core/`, a shared `DataTable` on CDK virtual scroll with the APG grid keyboard model, and a `ListPage` registered for the `list` archetype that binds the declared read through `RefreshService`. The descriptor gains a `table` declaration (columns and empty-state keys) in both grammar engines. The real-browser proof, including NFR-1's 1,000-row timing, runs against a harness build that ships nowhere.

## Boundaries & Constraints

**Always:**
- **The `table` grammar**, refused in both `OcuPilot.Screen.Registry.ReadProblem` and `ui/tools/screen-mirror.mjs` `readProblem`, naming the class. Example, with illustrative keys: `"table": {"columns": [{"field": "Name", "labelKey": "exampleNameColumn", "kind": "name"}, {"field": "Enabled", "labelKey": "exampleEnabledColumn", "kind": "status"}], "emptyNextKey": "exampleEmptyNext", "emptyAgentKey": ""}`.
  - `table` is an object exactly when `read` is non-null, and `null` or absent otherwise. Its only keys are `columns`, `emptyNextKey` and `emptyAgentKey`.
  - `columns` is non-empty. Each column has only `field`, `labelKey` and `kind`. `field` is in `read.fields` and unique across columns, `labelKey` is non-empty, and `kind` is one of `name`, `identifier`, `text`, `number`, `status`. Exactly one column is `name`.
  - A read-declaring descriptor has a non-empty `emptyStateKey`. When its id is `composite`, every part is in `read.fields`.
  - A descriptor is **write-capable** when it declares a primary action or at least one row action. A write-capable descriptor declares `emptyAgentKey` and leaves `emptyNextKey` empty; any other declares `emptyNextKey` and leaves `emptyAgentKey` empty.
  - The mirror test also checks that every `labelKey`, `emptyStateKey`, `emptyNextKey` and `emptyAgentKey` names a `STRINGS` key.
- **Row key.** `composite` joins the parts' `textOf` texts with `joinCompositeId`. Any other id kind uses the `textOf` text of the `name` column's field. The key drives selection, the active row, the changed set and the link. The link is `<route>/<encodeEntityId(key)>` with the current `?ns=`, and exists only when `hasIdRoute` holds.
- **Cells.**
  - `null`, absent and `""` all read "(none)".
  - `name` renders in `code` as a link.
  - `identifier` renders in `code`.
  - `number` is tabular and right-aligned.
  - `status` renders a 7px disc (`success` when true, `outline` when false) followed by "Yes" or "No". A non-boolean status value renders as text with no disc.
  - `text` renders in body type.
  - The row-overflow trigger is the last column, only when the declaration has row actions. Its name is "Actions".
- **View.** Rows are `applyView(store.data(), read, {filter, sort, direction})`. The store holds `sort`, `direction`, `filter` and `maxRows`, persists them per descriptor through one new allow-listed `PreferenceStore` map key, and restores them when the store is created. `setMaxRows` accepts only a positive safe integer and ignores anything else (DW-17).
- **Footer.** `"<n> rows"`, where `<n>` is the view's length with thousands separators, then the labeled "Max rows" field. The field commits on Enter or blur and reads now. When a read answered `truncated`, the footer also shows the cap notice with `<n>` set to the store's cap. There is no page-size control.
- **Grid keyboard** (`EXPERIENCE.md:381`, `:550-553`).
  - The grid is `role="grid"` with one Tab stop. DOM focus stays on the grid, and `aria-activedescendant` names the active row, or the active cell after Right/Left. Before setting it, the viewport scrolls that element into the rendered range.
  - Up/Down, Home/End and PageUp/PageDown move the active row and select it. Right/Left step through the row's cells and back to the row.
  - Enter navigates the link. On the trigger cell, Enter opens the menu.
  - Alt/Option+Down and `contextmenu` select the row and open the menu. The menu lists the row actions labeled as the command bar labels them, runs one through `ScreenActions.run`, and Escape closes it and returns focus to the grid.
  - A click selects the row, and a click on the name link navigates only.
  - Rows carry `aria-selected` and `aria-rowindex`, the grid carries `aria-rowcount`, and the sorted column header carries `aria-sort`.
- **Reconcile** (a delete, a re-fetch, a filter change; DW-18).
  - If the active row's key is still in the view, it stays active.
  - Otherwise the active row becomes the row now at its index, or the new last row, and a removed selection clears.
  - If the grid held focus and no row remains, focus goes to the empty state when it renders, else to the filter field.
- **Row states** (DESIGN.md `:1045-1054`, tokens only):
  - hover
  - selected: a 3px `secondary` bar, one row at a time
  - active row while the grid is focused: an inset `ocu-focus-ring`
  - changed: `change-highlight` background, a 3px `agent-accent` bar and the "Changed" tag, transitioning over `--ocu-motion-change-highlight-duration`
  - selected and changed: the highlight background, a `secondary` bar, and the tag
  - loading: skeleton rows in an `aria-busy` region, until the first successful read since bind or since the scope changed
  - empty
  - refresh-paused: the table does not change, and the command-bar chip and status-bar stamp take `warning`
- **Empty state.** It renders inside the frame only after a successful read answered zero rows. Its content:
  - the title from `stringFor(emptyStateKey)`, with `<NAMESPACE>` resolved to `ScopeService.namespace()`
  - a second line: on a write-capable descriptor, `tableWriteCapableEmptyState` with its placeholder resolved from `emptyAgentKey`; otherwise `emptyNextKey`'s string
  - the primary action as `button-primary` when `ScreenActions.has` it
  - A faulted read never renders it.
- **`RefreshService.readNow()`** runs the bound read under the same superseded-read guard as a tick, whether or not the screen refreshes. On success it applies the rows, notifies, lifts a fault suspension and re-arms through `canArm()`. It serves four cases: first load, Retry, a max-rows commit, and the scope change (`noteScopeChanged` now reads whatever the rate).
  - A `changed` bus event for the bound entity type and scope marks its id changed and reads now. The row stays changed until it is clicked or becomes active, and it is scrolled into view when it lands.
- **Faults (DW-172).**
  - A tick never retries by itself (AD-8).
  - A banner kind (`isBannerFault`) keeps today's banner and probe.
  - Any other kind keeps the rows and shows "request refused" with a "Retry" `button-text` in the frame. On the first load, that message replaces the skeleton.
- **Copy.** Every client string comes from `EXPERIENCE.md`'s Fixed strings table. The cap row becomes `<n>`, and one row adds `"<n> rows"`, `"Max rows"`, `"(none)"`, `"Yes"` and `"No"`, each citing its source. Non-ASCII characters are written as `\uXXXX`.

**Never:**
- No production descriptor declares `read` or `table`: that starts with Story 2.5.
- None of these controls: header-click sort or a sort control, column resize or drag, a Refresh action, a locator-bar entity segment or context-chip update from selection, enabling command-bar row actions, self-protection or gating inside the row menu.
- No "Updated:" announcement and no selecting a created row, because `ChangeEvent` carries no action yet.
- No empty-state sentence for a filter that matches nothing.
- No max-rows ceiling.
- No new color role (`design-tokens.test.mjs` holds 64).
- No harness code reachable from `src/main.ts`.
- No `docker compose up`/`down`. Browser runs go through `sh scripts/ci-throwaway.sh`, and `iris_execute_tests` runs one class per message.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| DW-17 bad cap | Max rows `0`, `-5`, `2.5`, `abc`, `""` | Store and preference unchanged; field shows the stored cap again; no read | No error |
| Cap raised | Max rows `5000` committed | Stored and persisted; exactly one read with `maxRows=5000` | No error |
| At the cap | Read of 500 rows, `truncated: true`, cap 500 | Footer "500 rows"; notice "Showing the first 500 rows. Narrow the filter or raise the max rows." | No error |
| DW-18 re-fetch | Active and selected row B of A,B,C; tick answers A,C | C active, no selection, grid keeps DOM focus | No error |
| DW-18 last row | Active C of A,B,C; filter removes C | B active | No error |
| Emptied | Grid focused; re-fetch answers zero rows | Empty state renders and holds focus | No error |
| Filtered to zero | Grid focused, filter set; a re-fetch leaves no row matching it | No empty state; focus to the filter field; "0 rows" | No error |
| DW-18 scope switch | Rows, selection, active, changed, scroll; rate off | All cleared; skeleton; one read in the new namespace | No error |
| DW-172 refusal | Tick answers `rejected`, `absent`, `not-installed` or `refused`, and the navigation map still allows the screen | Rows kept; "request refused" with Retry in the frame; no read until Retry | Retry reads now; success removes the message and re-arms at the rate |
| Banner fault | Tick answers `unreachable` | Rows kept; banner; no in-frame message | Probe or banner Retry lifts it |
| First-load refusal | First read answers `absent` | No skeleton, no empty state; the refusal with Retry | As above |
| DW-141/DW-162 | Before a page; then 6 rows, filter `a` keeps 2 | Field named "Filter rows", no `aria-describedby`; then the count reads "2 rows" and describes the field, and the table shows 2 rows | No error |
| Grammar | Table missing on a read; column field outside `fields`; two `name` columns; unknown kind; `emptyNextKey` on a write-capable descriptor; composite part outside `fields` | Both engines refuse naming the class | Mirror exits 1 |

</intent-contract>

## Code Map

- `ui/src/app/core/screen-store.ts`
  - Slots `:61-69`: `sortBy` is one string, and there is no direction, active-row or changed slot.
  - `clearAnswers` `:125-130` keeps selection and scroll across a scope change (DW-18).
  - `setMaxRows` `:172-179` stores any number (DW-17).
  - `ScreenStores.for` `:214-239`.
- `ui/src/app/core/preferences.ts`: `PREFERENCE_KEYS` `:41`; the rate-map parse and fallback pattern `:137-165`. `tools/api.test.mjs:788-830` pins the key list.
- `ui/src/app/core/refresh.ts`
  - `bind` `:209-228`.
  - `noteScopeChanged` `:349-357` reads only through `canArm` (rate > 0).
  - `canArm` `:377-383`.
  - The private `tick` `:459-485` with its superseded guard `:462`/`:474`.
  - `suspend`/`resume` `:494-510`.
  - `onBusEvent` ignores `changed` `:521-526`.
  - `tools/refresh.test.mjs:368-385` pins that every fault kind suspends; keep it.
- `ui/src/app/core/screen-read.ts`: `textOf` `:61-66`, `applyView` `:101-135`, `createScreenRead` `:152-167`, which ignores the server's `fields`.
- `ui/src/app/core/fault.ts`: `FaultKind` `:41-47`, `isBannerFault` `:102-104`. `connectivity.ts`: `note(null)` drains parks on any success `:183-186`, drain `:313-320`.
- `ui/src/app/core/change-bus.ts`: `ChangeEvent` `:30-50`. `entity-ref.ts:89` `scopeFor`; `refresh.ts:521-526` shows the type-and-scope match.
- `ui/src/app/core/entity-id.ts`: `joinCompositeId` `:41`, `encodeEntityId` `:56`. `navigation.ts`: `hasIdRoute` `:135`, `withQuery` `:194`, `screenForUrl` `:222`.
- `ui/src/app/core/screen-actions.ts`: `has`/`run` `:47-59`, handlers take no arguments. `overlay-stack.ts:35` handles Escape order.
- `ui/src/app/core/strings.ts`
  - `connectivityRequestRefused` `:77`, `actionRetry` `:125`, `commandBarFilterLabel` `:207`, `tableChangedTag` `:209`, `commandBoxGroupActions` `:267`, `tableRowCapNotice` `:293` (hard-codes 1,000), `tableWriteCapableEmptyState` `:295`, `stringFor` `:393`.
  - Placeholder formatters follow `formatAutoRefreshOn` (`refresh.ts:82-91`).
- `ui/tools/strings.test.mjs`
  - The table-to-source count is exact (`:328-343`).
  - Sanity window 113-138 (`:297-301`).
  - A tripwire on key names containing "namespace" (`:345-372`).
  - Each `EXPERIENCE.md:<line>` comment must match its line.
- `ui/src/app/shell/command-bar.ts`
  - The filter is a local signal nobody reads (`:142`, `:252`).
  - `matchCount` is always `''` (`:208-210`).
  - `filterDescribedBy` `:224-226`; chip `:121-129`.
  - The spec pins the name gap at `command-bar.spec.ts:333-342`, and that test flips.
- `ui/src/app/shell/screen-outlet.ts`: `ARCHETYPE_PAGES` `:42-44`. The page gets no inputs and resolves its own declaration through `screenForUrl`. Pattern test: `screen-outlet.spec.ts:137`.
- `ui/src/app/shell/status-bar.ts`: stamp `:184-188`. `ui/src/app/areas/home/home.page.ts` is the store-to-signal mirror and paren-free template precedent (`:183-191`, `:259-276`).
- `ui/tools/client-lint.mjs`
  - Template literals `:212-289`: `@if`/`@for` take paren-free members.
  - Colors `:90-117`.
  - Non-ASCII characters `:379-392`.
- `ui/src/styles/_components.scss`: focus-ring mixin `:42-46`, skeleton `:77-120`, empty state `:321-340`, link model `.ocu-locator-link` `:1258-1274`. `_metrics.scss`: `--ocu-row-height` `:47`, change-highlight duration `:65-67`.
- `ui/tools/screen-mirror.mjs`: `unknownKeyProblem` `:352`, `readProblem` `:386`, `buildMirror` `:454`, `ScreenDeclaration` template. `screen-mirror.test.mjs:70-84` checks labels against `STRINGS`. `src/OcuPilot/Screen/Registry.cls`: `ReadProblem` `:293`, `UnknownKeyProblem` `:435`.
- Read-declaring fixtures, every one of which gains a sound `table`: `src/OcuPilot/Test/Read/Canned.cls`, `Read/WebApps.cls`, `ReadTwin/One.cls`, `ReadTwin/Two.cls`, and `ReadBad/Cursor.cls` (so its refusal stays the cursor one). Also the inline read declarations at `ui/tools/screen-mirror.test.mjs:263` and `:330`. Builder: `ui/src/app/testing/screen-declaration.ts`, keys pinned by `ui/tools/screen-fixture.test.mjs:56-69`.
- Browser harness
  - `ui/browser.config.mjs` holds the settings.
  - `ui/browser/classic-link-card.browser-spec.mjs:101-133` serves `dist/` from its own Node server, with no instance.
  - `ui/package.json:16` runs the glob one file at a time.
  - `ui/angular.json:15-18` sets `outputPath`, `index`, `browser` and `tsConfig`.
  - `ui/tools/angular-json.test.mjs:32-45` forbids per-configuration `outputHashing`, and `:155-165` lists the spec files.
  - CI's `instance` job runs `npm run test:browser` (`.github/workflows/ci.yml:130-134`).
- `@angular/cdk@22.1.5` is already pinned and imported nowhere. MIT; the licence checks list no package names (`tools/licenses.mjs`, `build-output.test.mjs:127-138`).

## Tasks & Acceptance

**Execution:**
- `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md`
  - In the Fixed strings table, change the cap row to "Showing the first <n> rows. Narrow the filter or raise the max rows.", with `<n>` as the max-rows cap (`:383`).
  - After it, add `| "<n> rows" · "Max rows" · "(none)" · "Yes" · "No" |`. Its Where cell: data-table footer row count, which is also the command-bar filter's polite match count (`:383`, `:334`); footer max-rows field label (`:383`, `:602`); empty cell (`:345`, `DESIGN.md:1043`); boolean status cell (`DESIGN.md:1043`, `epics.md` Story 2.5).
  - This edit makes `epic-2-context.md` stale for the lead's pre-warm.
- `ui/src/app/core/strings.ts`, `ui/tools/strings.test.mjs`: add the five keys (`tableRowCount`, `tableMaxRowsLabel`, `tableEmptyValue`, `tableStatusYes`, `tableStatusNo`) and the `<n>` cap. Update the shifted `EXPERIENCE.md:<line>` citations, and widen the sanity window only if the count leaves it.
- `src/OcuPilot/Screen/Registry.cls`, `ui/tools/screen-mirror.mjs`: the `table` grammar in Always. Add `TableDeclaration`/`TableColumn` and `ScreenDeclaration.table` to the generated template, then regenerate `ui/src/app/core/screens.generated.ts`. Add `table` to the fixtures above, and `table: null` to the builder -- AD-5, AD-36.
- `src/OcuPilot/Test/ReadTool.cls`, `ui/tools/screen-mirror.test.mjs`: one refusal per grammar matrix row in each engine. The mirror checks the string keys.
- `ui/src/app/core/table-model.ts` (new), `ui/tools/table-model.test.mjs`: pure functions for `rowKey`, `cellView`, `formatRowCount`, `formatCapNotice`, `parseMaxRows`, `moveActive` (keys, page size), `reconcile` (previous keys, next keys, active, selected, grid focused → active, selected, focus target), `isWriteCapable` and `emptyStateView`. One case per matrix row.
- `ui/src/app/core/screen-store.ts`, `ui/src/app/core/preferences.ts`: add `direction`, `active`, `changed` (`markChanged`/`clearChanged`) and persisted view choices; validate `setMaxRows`. `clearAnswers` also clears selection, active, changed and scroll (DW-17, DW-18, AD-19). Tests go in `tools/refresh.test.mjs` or a new `tools/screen-store.test.mjs`, plus `tools/api.test.mjs` for the key list.
- `ui/src/app/core/refresh.ts`, `ui/tools/refresh.test.mjs`
  - `readNow()` and `fault()`, the read's last fault or `null`.
  - `noteScopeChanged` reads.
  - `changed` events mark the row and read.
  - A successful read lifts the suspension.
  - Rationale: AD-43, AD-14, AD-44, DW-172.
- `ui/src/app/shell/data-table.ts` (new), `data-table.spec.ts`
  - Inputs: the declaration and the store. An output asks for focus on the filter, and `ListPage` answers it by focusing `#ocu-command-bar-filter`.
  - `cdk-virtual-scroll-viewport` over a div grid with a sticky header, the cells, footer, row menu, skeleton, empty state and refusal from Always.
  - Styles go in `ui/src/styles/_components.scss`, tokens only.
- `ui/src/app/shell/list-page.ts` (new), `list-page.spec.ts`, `screen-outlet.ts`
  - The page resolves the declaration through `screenForUrl`, takes `stores.for`, calls `refresh.bind(screen, createScreenRead(api, screen))` then `readNow()`, and unbinds on destroy. A list declaration with no read renders no table.
  - It registers `list: ListPage` in `ARCHETYPE_PAGES`.
- `ui/src/app/shell/command-bar.ts`, `command-bar.spec.ts`
  - The filter is named "Filter rows".
  - It reads and writes the current screen's store.
  - `matchCount` is `formatRowCount` of the view once a page has loaded, else `''`.
  - The chip takes `warning` while paused. `status-bar.ts` does the same for the stamp.
  - Replace the pinned-absence test with name and right-state tests (DW-141, DW-162).
- `ui/src/app/testing/table-harness/main.ts`, `index.html` (new), `ui/tsconfig.harness.json`, `ui/angular.json`, `ui/package.json`
  - A `harness` build configuration with its own `browser`, `index`, `tsConfig` and `outputPath: dist/table-harness`. If the builder refuses those per configuration, use a second project on the same builder.
  - The harness mounts `DataTable` over real `ScreenStores`, `RefreshService` (stub connectivity) and `createScreenRead`, using a fetch-backed `requestJson` against its own origin.
  - It provides a router, so link navigation shows in `location`.
  - It exposes `window.ocuHarness`, which can re-read with a row set, mark a key changed and pause.
  - Add `"pretest:browser": "ng build --configuration production,harness"`.
- `ui/tools/angular-json.test.mjs`, `ui/tools/client-lint.mjs`, `client-lint.test.mjs`
  - Assert the harness output path is not `dist/ocupilot-ui`.
  - Refuse any non-spec file under `src/app/` outside `testing/` that imports from `testing/`.
- `ui/browser/data-table.browser-spec.mjs` (new): serve `dist/table-harness/browser` and answer `GET /api/ocupilot/screens/<id>/read` with generated rows. It needs no instance.

**Acceptance Criteria:**
- **AC1 (NFR-1).** Given the harness answering 1,000 rows in the pinned headless Chrome, when the spec navigates to it, then a body row is in the grid within 2,000 ms of `page.goto` starting, and fewer than 100 row elements exist.
- **AC2 (layout).** Given 1,000 rows, when the spec measures, then:
  - header and body rows are 36px, and the header stays at the viewport top after scrolling 500 rows
  - the name cell uses the `secondary` color with pointer cursor and is underlined on hover and focus
  - `identifier` cells use the code font family
  - `number` cells are right-aligned with `tabular-nums`
  - the status disc is 7px, followed by "Yes"/"No"
  - an empty cell reads "(none)"
  - the trigger is 28px and in the last column
  - the footer reads "1,000 rows" beside a field whose accessible name is "Max rows"
  - a truncated read shows the cap notice
- **AC3 (keyboard).** Given the grid:
  - When Tab reaches it and then End is pressed, `document.activeElement` is still the grid, `aria-activedescendant` names a rendered row with `aria-rowindex` 1001 (row 1 is the header row), and that row has `aria-selected` true. A second Tab leaves the grid.
  - When Right is pressed, the active descendant is a cell. Enter on a row navigates to the encoded link.
  - When Alt+Down or `contextmenu` fires, the menu opens, and Escape returns focus to the grid.
- **AC4 (row states).** Given the harness, when rows are hovered, selected, active, changed, and selected and changed, then the computed background, bar, ring and tag match Always. The skeleton shows only before the first read. Pausing leaves the table's computed styles unchanged, and `command-bar.spec.ts` and `status-bar.spec.ts` assert that the chip and stamp carry the paused `warning` treatment.
- **AC5 (empty and refused).** Given the component spec, when a read answers zero rows, then the frame renders the title with `<NAMESPACE>` resolved, the second line (the agent line for a write-capable declaration, the `emptyNextKey` line for a read-only one), and the primary action when `ScreenActions.has` it. When the read faults instead, there is no empty state.
- **AC6 (integration: screen-read, refresh and table).** Given `ListPage` bound through `RefreshService` with `createScreenRead` over a stub `requestJson`, when the first read and then a tick land, then rows render and update in place, the active row is kept by key, and the grid keeps DOM focus. In the browser spec, a re-read dropping the active row moves it to the next row.
- **AC7 (integration: command bar and table, DW-141/DW-162).** Given the command bar and `ListPage` on one screen, when the filter is typed, then the table shows the view and the bar's count describes the field.
- **AC8 (integration: change bus and table).** Given a bound list, when a `changed` event for its entity type and scope is published, then exactly one read is issued and the row with that key renders changed.
- **AC9 (persistence).** Given sort, direction, filter and max rows set on one descriptor's store, when a new `ScreenStores` over the same storage creates it, then all four are restored and another descriptor's defaults are untouched.
- **AC10 (harness ships nowhere).** Given a file under `src/app/shell/` importing `../testing/`, when `client-lint.mjs` runs, then it exits 1 naming the file.

## Spec Change Log

## Review Triage Log

### 2026-09-14 — Review pass
- verdicts: 67 findings — high 1, medium 16, low 42, false 8, maybe-false 0
- findings:
  - `medium` `patch` BH1 rate-off list whose first read met a banner fault never loads after reconnect — `resume` reads now when not yet loaded.
  - `low` `reject` BH2 a thrown read leaves the skeleton — `createScreenRead` reports faults as results and does not throw; the guard would add a branch for an unreachable case.
  - `low` `reject` BH3 `changed` events and max-rows commits read during a suspension or pause — the spec directs both to read now; AD-8 bars retrying the refused tick, which these are not; no Epic 2 producer publishes `changed`.
  - `low` `patch` BH4 AC4 pause check could pass with no pause engaged — harness exposes `paused()` and AC4 asserts it is true.
  - `medium` `patch` BH5 second-Tab check passes for focus inside the grid — containment assertion; it went red on the real tree (the viewport was a Tab stop), fixed with `tabindex="-1"` on the viewport.
  - `medium` `patch` BH6 row menu clipped near the frame bottom, stale position — `placeMenu` computes from the viewport offset after render and flips above the row; browser row added.
  - `medium` `patch` BH7 menu closes on mousedown where buttons are not focused on click — menu `mousedown` prevents default; component row asserts it.
  - `low` `patch` BH8 menu accessibility wiring — trigger `aria-expanded`/`aria-controls`, menu `aria-label` "Actions".
  - `low` `patch` BH9 header and body tracks drift under a classic scrollbar — `scrollbar-gutter: stable` on the head and the viewport.
  - `false` `reject` BH10 scroll not restored across navigation — EXPERIENCE `:384`/`:561` require scroll to survive refresh, which the kept viewport does; restoring on return is not specified.
  - `low` `reject` BH11 changed row scrolled before the re-fetch lands — a re-fetch rarely moves a row; fixing needs read-landing tracking.
  - `low` `patch` BH12 opening the menu keeps the changed mark — `select` clears it; marks for keys never in view are not worth expiry logic.
  - `low` `reject` BH13 cap notice uses the current cap — spec: `<n>` is the store's cap.
  - `low` `reject` BH14 view recomputed per store notification — measured first page 435 ms at 1,000 rows; memoization adds complexity.
  - `low` `reject` BH15 command-bar count and filter persistence per keystroke — negligible at the spec's row counts.
  - `false` `reject` BH16 `ROW_HEIGHT_PX` untied to the token — AC2 asserts 36px header and body rows in the browser.
  - `low` `reject` BH17 empty or duplicate row keys — names are entity ids, unique and present in admin LIST rows.
  - `low` `patch` BH18 stale grid-focus flag — reconcile reads DOM focus within the grid or menu; the signal and its handlers are gone.
  - `medium` `defer` BH19 secret-field column not refused — pre-existing unmasked read path; deferred in frontmatter.
  - `low` `patch` BH20 ObjectScript refusal rows thinner than the mirror's — five rows added to `ReadTool`, one to the mirror test; the non-string-id disagreement is not worth a guard.
  - `medium` `patch` BH21 focus hand-off to the filter untested, id duplicated — `COMMAND_BAR_FILTER_ID` exported from `command-bar.ts` and bound; `command-bar.spec.ts` asserts focus lands in the field.
  - `medium` `patch` BH22 Always interactions untested — `data-table.spec.ts` rows for click, link click, contextmenu, trigger Enter, move-clears-changed.
  - `low` `reject` BH23 "1 rows" — the Fixed strings row publishes only `<n> rows`.
  - `low` `patch` BH24 footer lacks the `·` separator — an `aria-hidden` `\u00b7` between count and field once loaded.
  - `low` `reject` BH25 typed filter text kept on a screen with no read — pre-existing field behaviour.
  - `low` `reject` BH26 paused treatment keyed on the chip label — the label is the framework's own paused state; no divergent caller named.
  - `low` `reject` BH27 Auto Run Result stale — finalize rewrites it; fixing edits this spec.
  - `low` `patch` BH28 test-comment mutation claims not run — ran the angular-json, screen-mirror, refresh and table-model mutations (red, recorded); removed the unrun build-output claim.
  - `false` `reject` BH29 `:346` cited for "(none)" — `:346` is where EXPERIENCE publishes "(none)".
  - `medium` `patch` ECH1 banner-fault resume at rate off — same fix as BH1.
  - `low` `reject` ECH2 thrown read — as BH2.
  - `low` `reject` ECH3 duplicate or empty keys — as BH17.
  - `low` `reject` ECH4 composite id with empty parts — pre-existing id grammar gap; no descriptor declares one.
  - `low` `reject` ECH5 unregistered row action still listed — spec Never: no gating inside the row menu.
  - `medium` `patch` ECH6 menu clipped or stale — as BH6.
  - `low` `patch` ECH7 menu stays open when its row leaves the view — `sync` closes it; component row added.
  - `medium` `patch` ECH8 menu closes before the click lands — as BH7.
  - `low` `patch` ECH9 scrollbar drift — as BH9.
  - `low` `reject` ECH10 cap notice cap — as BH13.
  - `low` `reject` ECH11 stale changed marks — as BH12's rejected half.
  - `low` `reject` ECH12 singular row count — as BH23.
  - `low` `reject` ECH13 filter text on a readless screen — as BH25.
  - `low` `reject` ECH14 `--root` with no value — a test-only flag; falls back to the workspace.
  - `medium` `patch` ECH15 rate-off list never loads after a banner fault — as BH1.
  - `low` `reject` ECH16 template-literal import evades the lint — the bundle-marker test backstops it.
  - `medium` `patch` VG1 second-Tab assertion — as BH5.
  - `low` `patch` VG2 paused warning colour unchecked — `design-tokens.test.mjs` pins both rules (mutation recorded).
  - `medium` `patch` VG3 focus to the filter unverified — as BH21.
  - `medium` `patch` VG4 mouse and trigger-Enter untested — as BH22.
  - `low` `patch` VG5 changed-mark clearing and scroll-into-view untested — component move-clears row and browser off-screen row.
  - `low` `patch` VG6 successful tick after a park never shown clearing the fault — banner-resume test added.
  - `low` `patch` VG7 grammar refusals missing in one or both engines — as BH20.
  - `low` `patch` VG8 restored filter not shown in the field — `command-bar.spec.ts` row added.
  - `low` `patch` VG9 transition never read — AC4 asserts `transition-property` and the zeroed duration on the changed row.
  - `false` `reject` VG-other-1 mutation lines per AC clause — Rule 19 asks one per AC; each AC has one.
  - `low` `patch` VG-other-2 `0ms` token check unfalsifiable — replaced by the row's computed transition (VG9).
  - `high` `patch` IA1 a refused tick re-read without Retry once connectivity drained its park — `resume` keeps a non-banner suspension; test added (AD-8).
  - `false` `reject` IA2 harness mounts `DataTable`, not `ListPage` — the spec's harness task names `DataTable`.
  - `medium` `patch` IA3 focus to the filter field not exercised — as BH21; the scope-switch emission is low and not acted on.
  - `low` `reject` IA4 scope switch untested at the component — covered in `refresh.test.mjs` and `screen-store.test.mjs`.
  - `low` `reject` IA5 changed-row scroll timing — as BH11.
  - `low` `patch` IA6 Right/Left do not scroll the active row into range — both call `scrollIntoRange`.
  - `low` `patch` IA7 menu opening keeps the changed mark — as BH12.
  - `false` `reject` IA8 active-row ring only on `:focus-visible` — the project's focus rings are `:focus-visible` throughout `_components.scss`.
  - `medium` `patch` IA9 interactions untested — as BH22.
  - `false` `reject` IA10 class naming exercised only in the mirror — `Registry.Validate` prefixes the class for every problem.
  - `false` `reject` IA11 glyphs not from Fixed strings — they are `aria-hidden` glyphs EXPERIENCE `:603` lists, not copy.

## Design Notes

**Governing ADs:**
- AD-19: the store and signal mirror; view choices live in the store.
- AD-5: the `table` declaration lives in the descriptor, in both engines.
- AD-36: the one read.
- AD-43: `readNow` and the timer in one framework.
- AD-14: `changed` means re-fetch, never patch.
- AD-13: the one encoder for the link.
- AD-44: scope switch means re-fetch and clear.
- AD-8: a refused tick is never retried automatically.
- AD-20: the read path goes through `createScreenRead`.
- AD-11 rule 3: a delete-driven move never changes the selected entity silently.
- AD-47 and NFR-10: the harness is outside the bundle.
- Conventions: Angular naming, Client asset homes.

**Why the harness, and what it proves.** No list route exists until a production descriptor declares one (Story 2.5), and no stock admin LIST holds 1,000 rows on a fresh container (46 web applications on the live one). The harness is the only place to observe geometry, focus under recycling, and 1,000-row timing in this story, and Rule 3 needs real-runtime evidence here. It is real Chrome, the real builder output and a real HTTP read path, but not IRIS.

Recommended apply-and-report restatement of `epics.md` Story 2.4 AC1 (Rule 5), for the lead:
- "Given the data table over a read answering a thousand rows, When the user navigates to it, Then its first page renders within two seconds in the pinned browser."
- The over-the-wire read cost at 1,000 rows first becomes observable in Story 2.5. Whether 2.5 carries it is the lead's call.

**Readings chosen where the documents leave room.**
- A delete-driven move does not select, because `EXPERIENCE.md:573` clears a removed selection and `:381`'s "moving selects" describes user moves.
- "Next row, else the empty state, else the filter" (`:596`) resolves as: the row taking the removed row's place or the new last row; then the empty state when zero rows came back; then the filter when the view is filtered to zero.
- Write-capable means the descriptor declares actions. The spine's Tool naming ties write verbs to row actions.
- The trigger reuses "Actions", and the match count reuses "<n> rows", the same reuse precedent `screen-outlet.ts` records.
- Row-menu labels are the declared ids, as in the command bar. No Epic 2 list declares row actions.

**Integration ACs:** AC6, AC7 and AC8. Before Story 2.5 no production read exists, so the consumer runs against a stub and the harness rather than an instance.

**Consumed-by:**
- `2-5-the-web-applications-list` … `2-9-the-processes-list`: `table` declarations, `ListPage`, first over-the-wire use.
- `2-10-the-audit-database-viewer-with-its-agent-marker-filter`: `DataTable` under server criteria.
- The first write-capable list (Epic 5): the agent line, the row menu, and the change highlight from confirm.

**Consumes:**
- `applyView`, `createScreenRead` and `truncated` (2.3)
- `RefreshService` and `ScreenStore` (1.14)
- the mirror and `ARCHETYPE_PAGES` (1.9, 1.15)
- the command bar (1.10)
- `classifyFault` and connectivity (1.13)
- `ScreenActions` and the builder (2.0)
- `change-bus` and `entity-id`

**Ledger inbox:**
- DW-17: invalid values are addressed (the "DW-17 bad cap" and "Cap raised" matrix rows). Declined DW-17 (ceiling half): no artifact publishes a ceiling, a numeric cap is the owner's (Rule 5), and Story 2.3 closed the same finding by design.
- DW-18: matrix rows and AC6.
- DW-141 and DW-162: matrix row and AC7.
- DW-172: the refusal matrix row.

## Verification

**Commands:**
- `cd ui && npm run build` -- expected: prebuild green, mirror up to date.
- `cd ui && npm test` -- expected: all node and component suites green.
- `uv run scripts/check-objectscript.py` and `uv run scripts/test_check_objectscript.py` -- expected: zero problems.
- `bash scripts/lint-docs.sh` -- expected: the EXPERIENCE.md edit lints clean.
- On `ocupilot-iris`, one `iris_execute_tests` call per class: `OcuPilot.Test.ReadTool`, `OcuPilot.Test.ScreenRead`, `OcuPilot.Test.Descriptor` -- expected: zero failures, confirmed in `%UnitTest_Result`.
- `cd ui && npm run build`, `sh scripts/ci-throwaway.sh up`, then `cd ui && OCUPILOT_BROWSER_EXECUTABLE="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" npm run test:browser`, then `sh scripts/ci-throwaway.sh down` -- expected: every spec green, including `data-table.browser-spec.mjs`.

**Planned mutations (Rule 19; apply, observe red, revert, confirm the tree is byte-identical):**
- AC1: render every row (`itemSize` removed, plain `@for`) -> the row-count assertion goes red.
- AC2: a `number` column stops right-aligning -> the alignment assertion goes red.
- AC3: move DOM focus to the row element instead of the active descendant -> the `activeElement` assertion goes red after End.
- AC4: selected-and-changed uses the `agent-accent` bar -> the bar-color assertion goes red.
- AC5: render the empty state on a faulted read -> the fault case goes red.
- AC6: `reconcile` keeps the active index instead of the key -> the in-place tick test goes red.
- AC7: `matchCount` returns `''` -> the describedby test goes red.
- AC8: `onBusEvent` ignores `changed` -> the one-read test goes red.
- AC9: stop restoring the view map -> the restore test goes red.
- AC10: drop the `testing/` import rule -> the lint harness case goes red.
- DW-17: `setMaxRows` accepts 0 -> the bad-cap row goes red.
- DW-172: a non-banner fault skips the in-frame refusal -> the refusal row goes red.
- Grammar: remove the exactly-one-`name` check in each engine in turn -> that engine's refusal test goes red.

**Observed (implementation pass, 2026-09-14):**
- `npm run build`: prebuild green, mirror up to date. `npm test`: 692 node tests and 220 component tests green.
- `check-objectscript.py`: 0 problems over 170 files; `test_check_objectscript.py`: 73 OK; `lint-docs.sh`: 0 issues.
- `%UnitTest_Result` runs 1478-1480: ReadTool 11/11, ScreenRead 17/17, Descriptor 19/19.
- Throwaway `ocupilot-ci`: `npm run test:browser` 19/19, including the five `data-table.browser-spec.mjs` cases; torn down after.
- `dist/ocupilot-ui` carries no `ocuHarness`, `app-table-harness` or `TableProbe`.

Mutations, each reverted with the tree confirmed identical to the pre-mutation `git status`/`git diff` snapshot:
- mutation: plain `@for` in place of `*cdkVirtualFor` → AC1 "row elements in the DOM: 1001".
- mutation: `.ocu-data-table-cell-numeric` loses `justify-content`/`text-align` → AC2 "numbers are right-aligned".
- mutation: `moveTo` focuses the row element → AC3 "DOM focus is still the grid".
- mutation: selected-and-changed `::before` uses `--ocu-agent-accent` → AC4 "the bar stays secondary".
- mutation: `showEmpty` ignores the fault → `data-table.spec.ts` "AC5: a faulted read never renders the empty state".
- mutation: `reconcile` keeps nothing by key → `list-page.spec.ts` AC6 and `table-model.test.mjs` "an active key still in the view stays active".
- mutation: `matchCount` answers `''` → `command-bar.spec.ts` AC7.
- mutation: `onBusEvent` returns on `changed` → `refresh.test.mjs` AC8.
- mutation: the `ScreenStore` constructor skips the view map → `screen-store.test.mjs` AC9.
- mutation: `lintClient` drops `checkTestingImports` → `client-lint.test.mjs` AC10.
- mutation: `setMaxRows` accepts 0 → `screen-store.test.mjs` DW-17; `parseMaxRows` accepts 0 → `table-model.test.mjs` DW-17.
- mutation: `showRefusal` never true → `data-table.spec.ts` both DW-172 cases.
- mutation: `Registry.TableProblem` drops the name count → `ReadTool:TestATableOutsideTheGrammarIsRefused` (two and zero name columns); `tableProblem` drops it → `screen-mirror.test.mjs` "AD-5: the generator refuses a table outside the declared grammar".

**Observed (review pass, 2026-09-14):** build and prebuild green; `npm test` 696 node and 227 component tests green; `check-objectscript.py` 0 problems, its harness OK, `lint-docs.sh` clean; `%UnitTest_Result` runs 1484-1486: ReadTool 11/11, ScreenRead 17/17, Descriptor 19/19; throwaway `npm run test:browser` 21/21, torn down; no harness marker in `dist/ocupilot-ui`.
- mutation: `resume` lifts a non-banner suspension → `refresh.test.mjs` "DW-172: a refused tick stays suspended when the connectivity park drains".
- mutation: `resume` skips the not-yet-loaded `readNow` → `refresh.test.mjs` "a screen whose rate is off and whose first read met a banner fault reads".
- mutation: the tick's fault path stops recording `lastFault` → `refresh.test.mjs` both DW-172 tick tests and the banner-resume test.
- mutation: the viewport without `tabindex="-1"` (the pre-patch tree) → AC3 "a second Tab leaves the grid and everything inside it".
- mutation: `placeMenu` always places below → `data-table.browser-spec.mjs` "the row menu opened on the last visible row stays inside the frame".
- mutation: `ListPage` drops its `(focusFilter)` binding → `command-bar.spec.ts` "Filtered to zero".
- mutation: `onRowClick` a no-op → `data-table.spec.ts` "a click selects its row".
- mutation: Enter ignores the trigger cell → `data-table.spec.ts` "Enter on the trigger cell opens the menu".
- mutation: the paused chip rule reads `--ocu-on-surface` → `design-tokens.test.mjs` "refresh paused" (AC4 chip and stamp).
- mutation: harness `outputPath` is `dist/ocupilot-ui` → `angular-json.test.mjs` harness row; `declaredStringKeys` drops column labels → `screen-mirror.test.mjs` key-listing row; `reconcile` falls back to the index → `table-model.test.mjs` "stays active wherever it moved".

## Auto Run Result

Status: done
Blocking condition: none

**Implemented.** The `table` grammar in both engines; `core/table-model.ts`; store view persistence, active and changed slots, DW-17 cap validation; `RefreshService.readNow`/`fault`/`hasLoaded`, scope switch and `changed` reading now; `DataTable` on CDK virtual scroll with the APG grid, row menu, skeleton, empty state and refusal; `ListPage` as the `list` archetype; the command-bar filter bound to the store (DW-141, DW-162); paused chip and stamp; the harness build, its lint rule and the browser spec.

**Files:** `EXPERIENCE.md` (cap row, footer row); `Registry.cls`, `Descriptor/Base.cls`, five read fixtures, `ReadTool.cls` (grammar and refusals); `strings.ts`, `strings.test.mjs`; `screen-mirror.mjs`, `screens.generated.ts`, `screen-mirror.test.mjs`; `table-model.ts` (+test); `screen-store.ts`, `preferences.ts`, `screen-store.test.mjs`, `api.test.mjs`; `refresh.ts`, `refresh.test.mjs`; `data-table.ts` (+spec), `list-page.ts` (+spec), `screen-outlet.ts` (+spec); `command-bar.ts`, `status-bar.ts` (+specs); `app.spec.ts`, `app.wire.spec.ts`; `_components.scss`, `design-tokens.test.mjs`; `testing/table-declaration.ts`, `testing/screen-declaration.ts`, `testing/table-harness/`, `tsconfig.harness.json`, `angular.json`, `package.json`, `angular-json.test.mjs`, `build-output.test.mjs`, `client-lint.mjs` (+test); `browser/data-table.browser-spec.mjs`.

**Review:** 67 findings. Patched entries by verdict: high 1 (a refused tick re-armed when the connectivity park drained), medium 6 (rate-off first-load banner fault, the viewport as a second Tab stop, menu clipping, menu mousedown, focus hand-off to the filter, untested interactions), low 15. Deferred 1 (secret-field column). Rejected 23 low and 8 false, each with its reason in the Review Triage Log.

**Follow-up review: recommended.** The high patch changes when a fault suspension lifts (`resume` now reads the fault kind and reads when not yet loaded); the connectivity drain against a real `ConnectivityService` is exercised only through the parks stub.

**Verification:** see Verification › Observed (review pass).

**Residual risks:** a `changed` event or max-rows commit still reads while a refusal or proposal pause holds (spec-directed); the menu mousedown fix follows documented WebKit focus behaviour, and only Chrome runs here.
