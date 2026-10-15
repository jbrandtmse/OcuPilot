---
title: 'Story 23.5: The range-end cleanup, part 5'
type: 'bugfix'
created: '2026-10-14'
status: 'in-progress'
baseline_revision: '2ed942779c87893d73d565c764d0b4a1cfdcd176'
baseline_commit: '2ed942779c87893d73d565c764d0b4a1cfdcd176'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
warnings: ['multiple-goals', 'oversized']
deferred:
  - summary: >-
      Count strings outside Batch a's table still read the plural at 1, for example "Stopped after 1 seconds."
    evidence: |-
      `explorerSqlStopped` and `explorerSqlStoppedUndone` fill `<s>` from the server-recorded `seconds` (`core/sql-answer.ts:78,107`), so 1 is reachable. A heuristic pass over `strings.ts` (a `<n>`-style placeholder before a plural noun, no `One` sibling) also lists `agentDefinitionTestTimeout`, `agentDefinitionTestTimeoutLocal`, `processBroadcastHint`, `tableCheckAtMost`, `remoteDatabaseListHint`, `remoteDatabaseListConsequence` and `explorerSqlDataTabCap` (inference: reachability at 1 not checked). Fix is a census plus a singular per reachable string, which is a sweep rather than a patch.
    location: >-
      ui/src/app/core/strings.ts
    severity: low
  - summary: >-
      Home's System Information block and findings panel are not re-read when the shell's banner clears after a connectivity fault, so each stays a heading with no rows until a scope change, a change event or a revisit.
    evidence: |-
      `about.ts`, `system-info.ts` and `findings.ts` register no `retryWhenReachable`, so the banner's Retry (`connectivity.retry()`) re-runs none of them; the only in-place Retry is for a non-banner fault. Before this pass the same block stood on its plain fault sentence under the same conditions, so the gap is not new.
    location: >-
      ui/src/app/areas/home/home.page.ts:789-804
    severity: low
---

<intent-contract>

## Intent

**Problem:** Twenty-four ledger entries are owned by this story: seventeen from the owner's visible-polish batch (c) and seven routed since. Counts read "1 rows"; a classified container is shown as a secret; a narrowed panel traps the side bar; the rail stays live under a full-screen panel; the picker's label is cut in half; a Home row clips; two alerts lack their role and actions; one failed read hides Help for the session; a long view text cannot be read whole; tabs are paged out of view. Three browser specs also flake.

**Approach:** Four area batches, in this order: (a) count copy through one shared rule, plus the proposal card; (b) shell state, Home and About; (c) shell geometry and the panel; (d) list and detail pages. Each batch is one implement pass and one code commit, with CI green on its own head. A copy or state fix gets a red-first component or tools test. A geometry fix gets a red-first browser spec in both themes. DW-1951 is already fixed. Four later routings are proposed for Story 23.11.

## Boundaries & Constraints

**Always:**

- Work in `/Users/jbrandt/git/OcuPilot/.worktrees/epic-23` on `OCU-1-epic23`. Check `git rev-parse --show-toplevel` first. Every IRIS MCP call carries `server: "ocupilot-slot-a"`, which reaches the dev instance `ocupilot`, never the throwaway.
- Run tests, probes and mutations only on the throwaway `ocupilot-ci` (52776/1975), and only once `docker inspect -f '{{.State.Health.Status}}' ocupilot-ci` reads `healthy`. Keep one test run in flight, whatever the runner. Await each in `%UnitTest_Result` or at the browser run's exit; a client timeout is not a finished run. Run every command in the foreground with `timeout: 600000`.
- One implement pass per batch. The lead re-opens the spec for each batch and scopes the pass to that batch's unchecked items. A red batch is reopened alone.
- Red first (Rule 19). Show each task's pinning test red on the defect before the fix, and record its `mutation:` line in the batch's Verification. Before reading any result, rebuild and redeploy the bundle, or reload `src` and recompile the mutated class and its descendants.
- Strings:
  - A new value is a new key beside its plural in `strings.ts`, carrying its `/** EXPERIENCE.md:NNN */` row. Never reword an existing value.
  - Append each literal to that row's String column of the Fixed strings table, in place, so EXPERIENCE.md's line count and every citation stay unchanged.
  - No exclamation marks and no "successfully". Write non-ASCII in source as `\uXXXX` (Rule 14).
- Edit DESIGN.md in place too, with its line count unchanged: code cites it by line.
- Extend the sibling named under Design Notes (Rule 31). Comments state the contract.
- Epic 20 runs on slot B. In files it changed, only the edits under Design Notes › Contended edits change existing lines; everything else there is add-only. Forward-merge feature before each batch, and find anchors by symbol, not by line.

**Never:**

- Implement passes never edit the spine, `CLAUDE.md`, `_bmad/custom/*`, `epics.md`, `deferred-work.md` or another story's spec. The lead applies Design Notes › Lead edits.
- Never edit `ui/browser/structural-walk.mjs` or `ui/browser.config.mjs`. Never change a read bound, a field's disclosure class (`ToolFields`, `Classification`), or what a secret-classified field renders.
- Absorb nothing proposed for 23.11 and nothing under Design Notes › Named for filing.
- Never stop, remove, recreate or `down` `ocupilot`, any `ocupilot-slot-*` container, `ocupilot-ci`, `ocupilot-b-ci` or `iris-community-edition`.
- No commits; pushing is the lead's job. Never put `[skip ci]` on code.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| One row (DW-1985, DW-2101) | A list whose read answers 1 row | The footer, the filter count and the context chip read "1 row". 0 reads "0 rows"; 1,000 reads "1,000 rows". | No error expected |
| One document (DW-2101) | The code list exports, imports, compiles or deletes 1 document | "Saved 1 document as <file>.", and the singular of each sentence in Batch a's table | No error expected |
| Opaque on the card (DW-1436) | A users update proposal; the stored `EscalationRoles` holds 2 roles, `Roles` 1 | The unchanged rows read "2 items" and "1 item". No role name reaches the wire. | A secret or unclassified field still reads the mask |
| Back after sign-out (DW-1341) | Signed out on the sign-in card, Back to a listed screen | No `POST /account/preferences` | No error expected |
| Double star (DW-1342) | Two activations of the favorite toggle inside one round trip | One request. The star is `aria-disabled="true"` until it settles. | A refused write announces as today |
| Help after an outage (DW-1368) | The help read answers status 0, then ok on the next visit | The Help control appears on the next visit | A refusal or `available: false` hides it and is not asked again |
| Stale bundle and a notice (DW-1371, DW-1372) | Stale identity while the instance notice blocks | No strip. On the sign-in card a stale bundle still shows it. The mounted `role="status"` node receives the sentence when the strip appears. | No error expected |
| About fails (DW-1401) | The About read answers status 0, then 5xx | An in-dialog `role="alert"`: the unreachable sentence with Retry, then the generic sentence with Retry and Open messages.log. Retry re-reads. | No error expected |
| Home block fails (DW-1401) | System Information or findings: status 0 or 5xx, then a 404 | Banner fault: the block adds nothing; the shell's banner is the one alert. A 404: the in-place alert in the block. | No error expected |
| Text-only resize (DW-1392) | Caption and body type doubled on Home | Each System Information row grows; none clips | No error expected |
| Narrow, then widen (DW-458) | 1,280 px, panel 400 → 336 (the bar returns) → drag wider | The panel reaches 400 and the bar yields again; `panelMax` is 592 | A bar the user reopened still caps the panel at 352 |
| Rail in full screen (DW-460) | Full screen on; click any rail item | Nothing changes: no route, no side bar, no preference write | No error expected |
| Picker label (DW-2107) | A two-definition panel header with room for the name | The whole name shows; at most half the header is the cap | No error expected |
| Long view text (DW-1976) | A SQL view tab with a 5,856-character text | The selected (or only) row's text shows whole beneath the rows in a long block (Show more past eight lines) | Several rows, none selected: no block |
| Nine tabs (DW-1978) | A SQL table's detail at 1,024 to 1,600 px | Every tab is visible: the strip wraps onto 40 px rows and shows no pagination arrows | No error expected |

</intent-contract>

## Code Map

**Batch a: count copy and the proposal card.**

- The count rule:
  - The singular choosers today: `ui/src/app/core/data-browser-model.ts:243` `pickCount` (private), `ui/src/app/core/sql-answer.ts:21` `pick` (a copy of it).
  - Inline choices: `core/impact.ts:241`, `core/form-tabs.ts:62`, `explorer-export-dialog.ts:108`, `explorer-compile-dialog.ts:69`, `shell/broadcast-dialog.ts:129`, `shell/proposal-card.ts:791`. `areas/tasks/details.store.ts:95-140` (`every > 1`) is schedule wording.
  - `core/table-model.ts:185` `formatRowCount` groups the digits.
  - `explorerSqlRowCountOne: '1 row'` (`strings.ts:5389`, row 597). `strings.test.mjs` holds every value unique, so "1 row" cannot be a second key.
- Strings tests:
  - The Fixed strings table is EXPERIENCE.md `:250-604`.
  - `strings.test.mjs:613` is the 3,800 bound; it measures 3,408 today. `:766-776` pins row 314. `citations.test.mjs:136` guards anchored quotations.
  - Story 19.18 (`b4f015d4`) set the precedent: a singular is appended to its plural's own row.
- DW-1436:
  - `src/OcuPilot/Kernel/Proposal/Disclosure.cls`: `Rows` `:60-80` (value or `Mask()`); `OrdinaryPaths` `:180-205`; `Mask` `:207-210`.
  - `Screen/Tool/ToolFields.cls:229-230,248`: the users tools' `Roles` and `EscalationRoles` are `opaque`. `MatchRoles` members are `secret` (`:994-995`).
  - Client: `ui/src/app/core/turn.ts:660-672` (parses `field`, `value`, `emptyKey`); `core/proposal-view.ts:52-57` (row type), `:733` `MASKED_VALUE`; `shell/proposal-card.ts:215`.
  - Tests:
    - `src/OcuPilot/Test/ProposalWire.cls:277-304` (`TestTheUserToolsDisclosureMasksBothRoleArrays`) and `:216` (the unclassified field is masked).
    - `ui/browser/users-write.browser-spec.mjs:290-322` (`escalationMasked`).
    - `ui/browser/proposal-demo.browser-spec.mjs:414-416` (`MatchRoles` stays masked).
  - DESIGN.md:1198 (diff-row recipe), EXPERIENCE.md:633 (diff-row), and row 276.
- DW-2227: `ui/browser/proposal-confirm.browser-spec.mjs:209-218`.

**Batch b: shell state, Home and About.**

- DW-1341:
  - `ui/src/app/shell/recents-recorder.ts:42-45` (the subscription), `:59-64` (`record`).
  - The sibling predicate is at `app.ts:877`. `Session` is provided from `main.ts`, so the spec stubs it.
- DW-1342:
  - `shell/locator-bar.ts:507-523` (`toggleFavorite`); the template is at `:161-171`.
  - The sibling is `shell/read-only-toggle.ts:36`. Existing legs: `locator-bar.spec.ts:601-632`.
- DW-1368:
  - `core/help.ts:47-55` (`helpHrefFor`), `:104-114` (`load`).
  - Siblings: `classifyFault` and `isBannerFault` in `core/fault.ts:69,102`, as used at `panel.ts:980-985`. Tests are in `ui/tools/about.test.mjs:201-232`.
- DW-1371 and DW-1372:
  - `shell/stale-bundle-notice.ts:33-34,63-65`; `app.ts:229`; `frameShown` `:503`.
  - The live-region idiom is at `account-menu.ts:155`, `home.page.ts:426` and `locator-bar.ts:213`.
  - Tests: `stale-bundle-notice.spec.ts:126`, `app.spec.ts:1068-1094`, `ui/browser/about-help-links.browser-spec.mjs:366,381-388,430,446`.
- DW-1401:
  - `shell/fault-banner.ts:60-81` (template), `:144-160` (`kind`, `serverFault`, `message`), `retry`.
  - Stores: `core/about.ts:149-155`, `core/system-info.ts:120-140`, and the findings store behind `areas/home/findings-panel.ts` `faultShown`.
  - Surfaces: `shell/about-dialog.ts:83` (the dialog is `aria-modal`, `dialog.ts:57`), `areas/home/home.page.ts:406-408` and `:959` (`systemUnanswered`), `areas/home/findings-panel.ts:53-55`.
  - Every `requestJson` reports to the shell's banner (`core/api.ts:425`).
  - EXPERIENCE.md:769 (unreachable, "one banner"), `:771` (generic error).
  - Tests: `about-dialog.spec.ts:110-113`, `home.page.spec.ts:1222-1235,1688`, `fault-banner.spec.ts`, `fault-banner.wire.spec.ts`.
- DW-1392:
  - `ui/src/styles/_components.scss:5795-5799` (`.ocu-home-system-row`), against DESIGN.md:912.
  - The spec is `ui/browser/home-system-information.browser-spec.mjs`.

**Batch c: shell geometry and the panel.**

- DW-458:
  - `ui/src/app/core/panel-layout.ts`: `resolveLayout` `:112-120` (`panelMax` `:117`), doc `:86`, `applyWidth` `:361`.
  - The resize handle reads `panelMax` (`panel-resize-handle.ts:62,74`).
  - Tests: `ui/tools/panel-layout.test.mjs:197,218-219`; `ui/browser/panel.browser-spec.mjs:325-328` (AC3), `pressOnHandle`.
  - The dark toggle pattern is at `header-lockup.browser-spec.mjs:105`.
- DW-460:
  - `shell/rail.ts:238-258` (`activate`).
  - The guards it should match: `side-bar.ts:280`, `app.ts:567,580`.
  - The spec pattern is at `rail.spec.ts:353`.
- DW-1148:
  - DESIGN.md:904 (the 1,920 row), against EXPERIENCE.md:53 (no side bar on Home) and `:949`.
  - Code: `shell-state.ts:216-218` (Home closes the bar), `panel-layout.ts:131-135`.
  - Tests: `panel-layout.test.mjs:296-299`, `ui/browser/suggested-view.browser-spec.mjs:171-180`.
- DW-2107:
  - `_components.scss:8671-8677` (`.ocu-agent-picker`, `max-width: 50%`).
  - The header is `:3302-3323`. `app-agent-picker` has no rule of its own.
  - The spec is `ui/browser/agent-picker.browser-spec.mjs` (Legs 1 and 2; `NAME_A` is 26 characters).
- DW-2163 and DW-2282:
  - `agent-picker.browser-spec.mjs:124-140` (`openMenuViolations`, `setViewport` `:134`).
  - `ui/browser/impact.browser-spec.mjs:368-382`.
  - Both import `signedInAt` from `ui/browser/panel-spec.mjs`.
  - The settle model is the local copy at `panel.browser-spec.mjs:728-730`.
  - The spinner is `_components.scss:4355-4385` (16×16, rotating; reduced motion hides it). The walk's overflow allowance is 1 px (`structural-walk.mjs:443-447`, read only).

**Batch d: list and detail pages.**

- DW-1976:
  - The descriptor column keys:
    - `src/OcuPilot/Screen/Registry.cls` `TableProblem` `:2643-2690` (key list `:2662`, doc `:2637`).
    - `ui/tools/screen-mirror.mjs` `:3027` (doc), `:3050` (key list), `:3066` (the `emptyKey` check to copy), `:3770` (the emitted `TableColumn`).
    - The generated mirror is `ui/src/app/core/screens.generated.ts:352-363`.
  - Descriptors: `Screen/Descriptor/ExplorerSqlView.cls:71` (`Text`), `ExplorerSqlProcedure.cls` (`Description` column), `ExplorerSqlTriggers.cls:63` (`Code`).
  - Grid and tooltip:
    - `shell/data-table.ts:437` (the end of the grid), `:468-478` (the tooltip, `aria-hidden`), `:1427-1446` (`placeTooltip`).
    - `_components.scss:2388-2409` (cell), `:6441-6456` (tooltip).
  - The long block: `shell/long-block.ts` (Story 20.17).
  - Tests: `src/OcuPilot/Test/ColumnCorpus.cls` (read by `ui/tools/screen-mirror.test.mjs:1266`), `ExplorerDescriptor.cls`. The browser spec is `ui/browser/system-explorer-sql.browser-spec.mjs` (probe `Test/ExplorerSqlProbe.cls:57` `LONGVIEW`, with `LONGVIEWMARK`). `data-table-columns.browser-spec.mjs` covers the tooltip legs.
  - Docs: DESIGN.md:1042 (data-table), EXPERIENCE.md:665 (cut cell).
- DW-1978:
  - `shell/detail-page.ts:46-48` (doc), `:64-70` (`mat-tab-nav-bar`, which paginates: no `disablePagination` anywhere in `src`).
  - Tabs CSS ends near `_components.scss:2256`. DESIGN.md:1071 is the tabs row.
  - Tests: `system-explorer-sql.browser-spec.mjs:136-142,190`; `detail-page.spec.ts`. Epic 20's hunks there are `:1`, `:24-25`, `:70`, `:80`, `:135`.

## Tasks & Acceptance

**Execution:**

- One implement pass per batch leaves the tree for one commit: `fix(23.5): batch <x> - <area>`.
- Each task names its fix and its pinning test. Its `mutation:` line is under Verification.
- Update every test that asserts a shared surface's old shape, listed in Verification's `Shared surfaces:`, in the same pass.
- The lead writes ledger trailers once the batch's commit is green.

### Batch a: count copy and the proposal card

- [x] **DW-1985, DW-2101: one count rule.**
  - **The module.** New framework-free `ui/src/app/core/count-phrase.ts`:
    - `pickCount(count: number, one: string, many: string): string` returns `one` at exactly 1 and `many` otherwise.
    - `rowCountPhrase(count: number): string` is `formatRowCount(pickCount(count, STRINGS.explorerSqlRowCountOne, STRINGS.tableRowCount), count)`.
    - `data-browser-model.ts` and `sql-answer.ts` import `pickCount` in place of their private choosers. The inline choices listed in the Code Map call it too.
    - A string with two counts chooses nested.
  - **The strings.** Every count below goes through it. Each new key is `<plural key>One` (the three-way forms are `…OneFirst`, `…OneSecond`, `…OneBoth`), placed beside its plural, with its literal appended to the row:

    | Plural key | Singular literal(s) | Row | Consumer |
    | --- | --- | --- | --- |
    | `tableRowCount` | none new: `rowCountPhrase` reuses `explorerSqlRowCountOne` | 597 | `data-table.ts:1080`, `command-bar.ts:742`, `context-chip.ts:162`, `ledger.page.ts:428` |
    | `toolCallReadResultLine` | "1 row returned · <m> sent" | 352 | `tool-call-card.ts:200` |
    | `commandBoxResultCount` | "1 screen, <m> actions" · "<n> screens, 1 action" · "1 screen, 1 action" | 307 | `command-box.ts:327` |
    | `agentLedgerWithheld` | "1 row withheld: it records a privilege you do not hold." | 336 | `ledger.page.ts:440` |
    | `agentLedgerDropped` | "1 call was counted and not stored." | 336 | `ledger.page.ts:446` |
    | `explorerExportSaved` | "Saved 1 document as <file>." | 591 | `code-list.page.ts:579` |
    | `explorerExportDone` | "Exported 1 document to <path>." | 591 | `code-list.page.ts:575` |
    | `explorerImportDone` | "Imported 1 document." | 591 | `code-list.store.ts:423` |
    | `explorerImportDoneErrors` | "Imported 1 document, with compile errors." | 591 | `code-list.store.ts:423` |
    | `explorerCompileSummary` | "Compiled <done> of 1 document, <errors> with errors." | 589 | `code-list.store.ts:373` |
    | `explorerCompileStopped` | "Stopped after <done> of 1 document." | 589 | `code-list.store.ts:372` |
    | `explorerDeleteRunning` | "Deleting 1 document" | 589 | `code-list.store.ts:338` |
    | `explorerDeleteSummary` | "Deleted <done> of 1 document." | 589 | `code-list.store.ts:394` |
    | `explorerCompareSummary` | "1 line removed · <m> lines added" · "<n> lines removed · 1 line added" · "1 line removed · 1 line added" | 594 | `code-compare.page.ts:253` |
    | `proposalResidue` | "Removes exactly the error listed here. Any logged since the proposal will remain." | 260 | `proposal-card.ts:845` |
    | `proposalUnchangedFieldsDisclosure` | "1 unchanged field" | 276 | `proposal-card.ts:683` |
    | `oauthResourceServerMappingsRefused` | "Saved. 1 service mapping was not changed: <reason>" | 519 | `oauth-resource-server-form.page.ts:683` |
    | `tryItBinary` | "1 byte, not shown as text." | 574 | `openapi-viewer.page.ts:622` |
    | `tableRowCapNotice` | "Showing the first row. Narrow the filter or raise the max rows." | 313 | `data-table.ts:1094`, `ledger.page.ts:434`, `code-search.page.ts:306` |
    | `tableDownloadCsvCapped` | "The file holds the first row only." | 313 | `command-bar.ts:907` |
    | `agentTurnLimitBanner` | "You have reached this instance's limit of 1 agent turn an hour. You can send again at <hh:mm>." | 281 | `core/turn-limit.ts:45` |
    | `agentTurnLimitLine` | "This turn was not started: you have used your 1 turn for this hour." | 281 | `core/turn-limit.ts:50` |
    | `agentGuardrailsTurnsLimit` | "Each user may start at most 1 agent turn an hour." | 583 | `core/guardrails.ts:213` |
    | `agentGuardrailsContextLimits` | "Each turn carries at most 1 row of the screen you are on, <total> characters in all and <field> characters a field." | 583 | `core/guardrails.ts:202` (only `<rows>` can be 1) |
    | `agentDefinitionRetentionCaption` | "Transcripts are kept for 1 day." | 336 | `definition-form.page.ts:820` (the typed value, read as a number) |
    | `interopTestMaxLength` | "At most 1 character." | 604 | `interop-item-test-dialog.ts:272` |

  - **Escapes.** In `strings.ts`, write `·` as `·` and the apostrophe as `\'`. In EXPERIENCE.md, write both literally.
  - **Tests:**
    - `ui/tools/count-phrase.test.mjs`:
      - `rowCountPhrase` at 0, 1, 2 and 1,000 reads "0 rows", "1 row", "2 rows" and "1,000 rows";
      - `pickCount` at 0, 1 and 2;
      - a scan of `ui/src/app/**/*.ts` (not specs) finds no expression choosing between two `STRINGS` values on `=== 1` or `!== 1` outside `count-phrase.ts`; `tasks/details.store.ts` is allow-listed.
    - In each consumer's component spec, a singular case for its string.
    - `data-table.spec.ts`: one row reads `.ocu-data-table-count` "1 row".
- [x] **DW-1436: a classified-opaque value reads its member count.** The owner decided on 2026-09-21 that opaque gets a rendering of its own.
  - **Server.** In `Disclosure.cls`, `OrdinaryPaths` also collects top-level paths whose entry reads `class` `opaque`. `Rows` then writes such an unchanged field as `value` `""` plus `count`: a number, the stored value's `%Size()`. A secret or unclassified field keeps `Mask()`.
  - **Client:**
    - `turn.ts` parses `count`.
    - `proposal-view.ts`'s unchanged row gains `count?: number`.
    - `proposal-card.ts:215` renders `pickCount(count, STRINGS.proposalOpaqueCountOne, STRINGS.proposalOpaqueCount)`, filled. The new keys are "1 item" and "<n> items", row 276.
  - **Docs.** Append in place to DESIGN.md:1198 and EXPERIENCE.md:633: "A classified-opaque value (an array or object no reviewed entry describes member by member) reads its member count, "<n> items", never the mask."
  - **Tests:**
    - `ProposalWire.cls:277` becomes `TestTheUserToolsDisclosureCountsBothRoleArrays`. `Roles` and `EscalationRoles` carry `count` equal to the minted payload's array sizes, read from the proposal and never written as a literal. Each value is not `Mask()`, and the JSON still holds no role name.
    - `proposal-card.spec.ts`: an unchanged row with `count` 2 reads "2 items", with `count` 1 reads "1 item", and neither shows bullets.
    - `users-write.browser-spec.mjs:290-322`: the `EscalationRoles` row reads its member count, taken from the stored user, in place of the mask.
- [x] **DW-2227.** In `proposal-confirm.browser-spec.mjs:209-218`, after the status-line wait, `waitForFunction` until `.ocu-proposal-card-confirm` is gone and Send's class has settled, then read focus. The assertions are unchanged.

**Acceptance criteria:**

- Given any count the client renders, when it is exactly 1, then it reads the singular; 0 and 2 or more read as before.
- Given the source tree, when `count-phrase.test.mjs` scans it, then no module but `count-phrase.ts` chooses a count's singular.
- Integration AC: given a list on the throwaway that `context-chip.browser-spec.mjs` narrows to one row, by a filter value taken from that read's own rows that no other row contains, when the footer and the context chip render, then both read "1 row".
- Given a users update proposal on the throwaway, when its unchanged rows render, then `Roles` and `EscalationRoles` read their member counts and no role name reaches the wire.

### Review Findings

Code review of Batch a, 2026-10-14 (four layers, full-opus; 24 layer rows plus DW-2441 from the stage prompt, 16 entries after grouping).

- [x] [Review][Patch] (medium; fix-risk low, test-only; in-story) AC2's source scan cannot see a re-introduced chooser helper (`pick(n, STRINGS.aOne, STRINGS.a)`), a condition holding a call (`if (this.count() === 1)`), or a parenthesized or reversed condition [ui/tools/count-phrase.test.mjs:88-112] -- fixed: a second scan finds any singular key reached other than through `pickCount` or a phrase table's `one`, and the inline scan reads both forms; self-test cases for each shape.
- [x] [Review][Patch] (medium; fix-risk low, copy only; in-story) DW-2441: four count sentences still read the plural at 1 where their bound can be 1 (`TestCall.BoundSeconds` floors at 1, at a gateway timeout of 1 or 2 s): `explorerSqlStopped`, `explorerSqlStoppedUndone`, `agentDefinitionTestTimeout`, `agentDefinitionTestTimeoutLocal` [ui/src/app/core/sql-answer.ts:107] -- fixed: four `…One` keys beside their plurals (rows 466 and 597, appended in place), chosen through `pickCount` in `sql-answer.ts`, `data-browser.page.ts`, `data-browser.store.ts` and `testTimeoutText`; a one-second case in `sql-answer.test.mjs`, `data-browser.page.spec.ts` (page line and row outcome) and `definition-form.page.spec.ts`.
- [x] [Review][Patch] (low; fix-risk low; in-story) `count-phrase.ts`'s doc says every module that renders a count picks through `pickCount`, wider than the contract that holds [ui/src/app/core/count-phrase.ts:4-6] -- fixed: a sentence that can be filled with 1 has a singular chosen through `pickCount`; a count fixed above 1 has none.
- [x] [Review][Patch] (low; fix-risk low, test-only; in-story) The tests' plural-only scan misses a plural key filled with `'1'`, the nouns `calls` and `errors`, and `\s+` or `[\d,]` spellings, while its header claims every expected count pattern [ui/tools/count-phrase.test.mjs:4-5,175-191] -- fixed: a fill scan (`replace`, `split`/`join` or a formatter filling a plural that has a singular with 1), the two nouns and spellings, and a header naming what each scan reads. A count filled from a computed value is not scanned; the 48 such fills today are each a literal other than 1 or a fixed fixture.
- [x] [Review][Patch] (low; fix-risk low; in-story) QA's Compare leg hand-writes the English sentence instead of choosing among the four `explorerCompareSummary` templates [ui/browser/system-explorer-find.browser-spec.mjs:155-158] -- fixed: the expected sentence is the template the two drawn counts choose.
- [x] [Review][Patch] (low; fix-risk low, comment; in-story) `users-write` comment says "the two arrays" read their count; only `EscalationRoles` is unchanged there [ui/browser/users-write.browser-spec.mjs:292-293] -- fixed.
- [x] [Review][Patch] (low; fix-risk low, doc; in-story origin) `Propose.GuardedRowsForTurn`'s doc says every non-ordinary path carries the mask; an opaque array or object now carries `count` [src/OcuPilot/Kernel/State/Propose.cls:659-662] -- fixed at the origin; the class loads and compiles on `ocupilot-ci`.

DW-2441 census (each candidate's count at runtime):

- Reachable at 1, patched: the four above. `seconds` and `waitedSeconds` are `TestCall.BoundSeconds` of the gateway's `Server_Response_Timeout`, which answers 1 for a timeout of 1 or 2 (inference: the gateway accepts such a value).
- Unreachable: `processBroadcastHint` (the one broadcast screen, ProcessList, declares `multiSelect.max` 20); `tableCheckAtMost` (declared maxima 100, 100, 20); `remoteDatabaseListHint` and `remoteDatabaseListConsequence` (`LISTSECONDS` and `REMOTE_DATABASE_LIST_SECONDS`, 20); `explorerSqlDataTabCap` (`MAX_TABS` 8). The same census found three more, also unreachable: `pathPickerTruncated` (shown only at the `ROOTSMAX` 1,000 cap), `databaseTasksTruncated` (`TASKS_MAX_ROWS` 1,000), `explorerCompareUnchanged` (`hunks` collapses at least 2 lines unless the whole script is unchanged, which Compare answers as identical).
- Follow-up check: no test in `ui/browser`, `ui/tools` or the component specs fills a plural that has a singular with a count that can be 1 (48 such fills, each a literal other than 1 or a fixed fixture).

Rejected:

- (false) `OrdinaryPaths` is misnamed now that it also answers opaque paths: its signature carries `Output pOpaque`, its doc names both outputs, and its one caller binds `.tOrdinary, .tOpaque`.
- (false) A typed retention of "01" reads "kept for 1 day.": that is the value the field holds, not a wrong count.
- (low, theoretical) An opaque row and a secret row on one top-level path, or a secret row beneath an opaque one, would disclose a count. Of the 26 opaque top-level rows in `ToolFields` (86 tools), none shares its path or has a row beneath it. A count also releases no member.
- (low, theoretical) A wire `count` that is negative or fractional drops to "(none)". `Disclosure.Rows` writes only `%Size()`.
- (low) The Auto Run Result miscounts the new keys (31, not 26), the consumers and browser specs, and the triage tally. The fix would edit this spec's own record.
- (low) The scan excuses `ssl-form.page.ts`, which the spec does not list. The excuse is a boolean flag, not a count, and the scan's own test pins it as still present.
- (low) The `angular-json.test.mjs` budget comment is a dated history. `c7edabf5` is reviewed for its pin, which is exact (`'2500kB'`, under `'4000kB'`).
- (low) The context-chip format leg's `\d+ rows?` would accept "1 rows". The throwaway's Users list holds several rows, and the same file's Integration AC pins "1 row".
- (low) Rendered on the throwaway, AC4 covers `EscalationRoles` at 0 only. The task names that row; counts of 1 and 2 are pinned by `ProposalWire` and the component specs (the Review Triage Log closed this once).

### Batch b: shell state, Home and About

- [x] **DW-1341.** In `recents-recorder.ts`, `record()` returns unless `isSignedIn(session.state())`. Test: `recents-recorder.spec.ts`, with a stubbed `Session` in state `'form'`, navigates to a listed screen; nothing is written.
- [x] **DW-1342.** In `locator-bar.ts`, `toggleFavorite()` sets a `favoritePendingRoute` signal before the write and clears it once the write settles. A second activation on that route returns early. While a write is pending, `.ocu-locator-favorite` carries `aria-disabled="true"`, never `disabled`. Test: in `locator-bar.spec.ts`, two clicks with no await between give one POST; `aria-disabled` is set before the write settles and gone after.
- [x] **DW-1368.** In `help.ts`, `helpHrefFor` answers `null` for a banner fault or `not-installed`, and `load()` then deletes the route from `asked`. A refusal or `available: false` still answers `''` and is not asked again. Test: in `about.test.mjs`, a status-0 answer and then an ok one across two `load`s give two calls and the href.
- [x] **DW-1371 and DW-1372.**
  - `stale-bundle-notice.ts` takes a `shown` input, default `true`. `app.ts:229` binds it `false` while a blocking instance notice renders: `installUnreadable`, or signed in while not `instanceReady`. The strip still shows on the sign-in card.
  - The `role="status"` region sits outside the `@if`. It is always mounted, `ocu-visually-hidden`, and holds `STRINGS.staleBundleNotice` only while the strip is drawn. The visible strip carries no role.
  - Tests:
    - `app.spec.ts`: a version-mismatch instance stub with a stale identity gives no `.ocu-stale-bundle` while `app-instance-notice` renders. `:1068-1094` stays green.
    - `stale-bundle-notice.spec.ts`: the same `[role=status]` node, mounted empty, holds the sentence once the identity flips; retarget `:126`.
    - Retarget `about-help-links.browser-spec.mjs:381-388` to the region.
- [x] **DW-1401.** About, Home's System Information, and Home's findings panel. The findings panel is a third surface with the same root cause, found at plan.
  - **Stores.** `about.ts`, `system-info.ts` and the findings store keep the classified `Fault`: `fault(): Fault | null`, from `classifyFault`. `failed()` stays as `fault() !== null`.
  - **`fault-banner.ts`** gains an optional `fault` input and a `retried` output.
    - Given a fault, it renders that fault in place, as `role="alert"`: `unreachable` gives `connectivityBannerUnreachable` with Retry; any other kind gives `connectivityServerFault` with Retry and Open messages.log.
    - Retry emits `retried`.
    - Without the input, it follows `ConnectivityService` as today.
  - **About dialog.** It shows the in-place banner, because the dialog is `aria-modal`. Retry re-reads About. Open messages.log closes the dialog first.
  - **Home blocks.** On `home.page.ts:406-408` and `findings-panel.ts:53-55`, a banner fault renders nothing of its own: the shell's banner is the one alert. Any other fault renders the in-place banner, and Retry re-reads that store.
  - No new strings.
  - **Tests:**
    - `about-dialog.spec.ts`: a status-0 stub gives `.ocu-fault-banner[role=alert]` with the unreachable sentence, and Retry re-reads; a 500 stub gives the generic sentence and Open messages.log.
    - `home.page.spec.ts:1222-1235` and `:1688`: status 0 gives no sentence and no alert inside the block; a 404 stub gives the in-place banner.
    - `about-help-links.browser-spec.mjs`: with the About read aborted by request interception, the dialog's alert reads the unreachable sentence; Retry with interception off shows the rows.
- [x] **DW-1392.** In `_components.scss:5798`, change `height:` to `min-height:` on `.ocu-home-system-row`. Test: in `home-system-information.browser-spec.mjs`, double `--ocu-type-{caption,body}-{size,line-height}` on `documentElement` and wait two frames. Every `.ocu-home-system-row` then has `scrollHeight <= clientHeight + 1`, with its children inside its box, in light and in dark.

**Acceptance criteria:**

- Given a signed-out tab, when it navigates, then no preference write leaves it.
- Given any of the three surfaces, when its read fails, then the published alert, sentence and actions render exactly once, with the shell's banner counted.
- Given Home at doubled text size, when the System Information rows render, then none clips.

### Review Findings

Code review of Batch b, 2026-10-15 (four layers, full-opus; 32 layer rows plus DW-2448 and `.ocu-about-fault` from the stage prompt, 23 entries after grouping).

- [x] [Review][Patch] (medium; fix-risk low; in-story) DW-2448: after a banner fault, Home's System Information block and findings panel stay a bare heading once the shell's banner clears, with no re-read, sentence or Retry; this batch removed the block's own sentence for that fault [ui/src/app/core/system-info.ts:154] -- fixed: both stores park a banner-fault read with `retryWhenReachable` (DW-135's shape), wired in `main.ts`; a 404 keeps its in-place Retry and is not parked. Tools cases in `system-info.test.mjs` and `findings.test.mjs`; the status-0 browser legs now wait for the rows once the read can answer.
- [x] [Review][Patch] (medium; fix-risk low; in-story) The two status-0 legs in `home-system-information` wait for the shell's banner after `leaveFirstLoginGate`, which waits 5 s when the gate does not fire (an enabled definition on the instance), while the banner clears 1.5 s after the next success [ui/browser/home-system-information.browser-spec.mjs:396] -- fixed by the park above: the banner stands while the read keeps failing. A 5 s wait inserted before the banner wait stayed green on the patched bundle and went red on a bundle without the park.
- [x] [Review][Patch] (medium; test-only; in-story) `About.load`'s notify on a change of fault kind is pinned by no test that can see it [ui/src/app/core/about.ts:160] -- fixed: a tools case in `about.test.mjs`.
- [x] [Review][Patch] (medium; test-only; in-story) A refused favorite write releasing the star is pinned by no test [ui/src/app/shell/locator-bar.ts:539] -- fixed: the DW-1326 case asserts no `aria-disabled` and a second write after the refusal.
- [x] [Review][Patch] (medium; test-only; in-story) The pending-state case asserts no `.ocu-home-block-empty`, which the System Information block no longer renders in any state [ui/src/app/areas/home/home.page.spec.ts:1322] -- fixed: it asserts no `app-fault-banner`.
- [x] [Review][Patch] (low; test-only; in-story) `AboutDialog`'s `gone` guard is pinned by no test [ui/src/app/shell/about-dialog.ts:157] -- fixed: a case that destroys the dialog during a Retry read and expects no rejection.
- [x] [Review][Patch] (low; comment) `FaultBanner`'s class doc said two of six kinds render and the rest deliberately do not, `retry()`'s doc named the probe alone, and `serverFault`'s doc said no other kind has a published sentence, which EXPERIENCE.md:770 contradicts for a 403 [ui/src/app/shell/fault-banner.ts:45] -- fixed.
- [x] [Review][Patch] (low; comment) `helpHrefFor`, `HelpLinks` and the locator bar said a released route is asked again "on the next visit"; `syncHelp` runs on every router event [ui/src/app/core/help.ts:49] -- fixed.
- [x] [Review][Patch] (low; comment) `toggleFavorite`'s doc said one write at a time per route; one route is tracked, so a write on another screen takes the guard over [ui/src/app/shell/locator-bar.ts:519] -- fixed.
- [x] [Review][Patch] (low; deletion) `.ocu-about-fault` has no reference left in `ui/src`, `ui/tools` or `ui/browser` [ui/src/styles/_components.scss:5810] -- deleted.
- [x] [Review][Patch] (low; comment) `.ocu-home-system-row`'s comment said the row takes a 32px height; it is now a minimum [ui/src/styles/_components.scss:5828] -- fixed.
- [x] [Review][Patch] (low; test-only) Two browser specs faked error bodies the instance never sends (`internal`/`INTERNAL.ERROR`, `not-found`/`NOT.FOUND`, `detail: null`) [ui/browser/about-help-links.browser-spec.mjs:377] -- fixed: `server_error`/`INTERNAL` and `not_found`/`ROUTE.NOTFOUND`, no `detail`.
- [x] [Review][Defer] (medium; out-of-footprint) The Guardrails page and a web application's class-access tab draw the generic sentence as `role="alert"` for any failed read, status 0 included [ui/src/app/areas/agent/guardrails.page.ts:60] -- deferred: pre-existing; DW-2449, escalated owner=burndown.

Rejected:

- (by-design) A 403 drawn in place reads as the generic sentence with Retry. The task says any kind other than `unreachable` does, and the three reads drawn in place are caller-own and ungated beyond the router. The comment now says so.
- (by-design) A failed About read leaves the shell's banner behind the modal beside the dialog's alert. The Design Notes decide that About shows its own alert because the dialog is `aria-modal`.
- (low) Home's in-place Retry drops focus to the body when it answers. Home is not modal, so no trap is lost, and its in-place banner shows only for a non-banner fault, which these reads do not produce in normal operation (inference).
- (low) A screen reached before the session is signed in is not registered. The only change from before is a reload with an expired access token, and that screen was registered on its first visit. The spec prescribes the guard.
- (false) The favorite toggle's rejection arm rethrows into a voided chain. `add` and `remove` resolve through `settle` and never reject, and the old chain was equally unhandled.
- (low, theoretical) A favorite write that never settles holds the star. It needs a request that neither answers nor fails.
- (low) A stale strip on the sign-in card hides while the signed-in instance reads `checking`, then is announced again. That binding is the task's own.
- (low) `fault.ts`'s kind docs say `rejected` and `absent` have no surface. The in-place banner draws them as the generic sentence, not as a surface of their own, and the "Epic 1/Epic 2" wording predates this batch.
- (low) The `.ocu-fault-banner` stylesheet comment describes the shell's strip. What it says about that strip is still true.
- (low) The Auto Run Result's counts are off by one or two. Fixing them would edit this spec's own record.

- [ ] [CI] DW-1341's guard drops a deep-link arrival: `preferences-integration.browser-spec.mjs` DW-1329 failed on CI run 38688234353 (`Recent items lists the visited screen before sign-out: ["Users"]`). A `page.goto` to a listed screen is a fresh bootstrap whose first `NavigationEnd` arrives while the session is still `probing` (or `installing`), so `record()` returns and the visit is lost. Fix in `recents-recorder.ts`: a listed-screen arrival while `isWaiting(state)` is held as the one pending visit and registered when the session reaches `signed-in`; it is dropped if the session settles in any other state; an arrival in a settled non-signed-in state (`form`, `signed-out`, `session-ended`, ...) is still never registered (DW-1341). Pin both halves in `recents-recorder.spec.ts` (a pending arrival registered once the stub session turns `signed-in`; a pending arrival dropped when it turns `form`), each with a `mutation:` line, and keep `preferences-integration.browser-spec.mjs` green on a rebuilt bundle, run three times.

### Batch c: shell geometry and the panel

- [ ] **DW-458.**
  - **The fix.** In `panel-layout.ts:117`, `panelMax` subtracts the side bar only when the user reopened it: `sideBarShown && input.sideBarReopened`. Update the doc at `:86`. A drag that needs the room now collapses the bar (yield 1) instead of stopping at it.
  - **Tests:**
    - New in `panel-layout.test.mjs`, at 1,280: 400, then four `resizeBy(-16)` to 336 with the bar shown, then four `resizeBy(16)` to 400 with the bar hidden and `panelMax` 592.
    - Flip `:197` (352 becomes 592) and `:218-219` (the bar yields).
    - New in `panel.browser-spec.mjs`, at 1,280 through `pressOnHandle`: side bar, panel and content read `[0, 400, 832]` and `aria-valuemax` reads 592, in light and in dark. Flip AC3 at `:325-328`.
- [ ] **DW-460.** `rail.ts` `activate` returns while `panel.fullScreen()`, for every item, Home included. Test: in `rail.spec.ts`, in full screen a side-bar item's click leaves `shell.open()`, `visibleArea()` and `account.calls` unchanged, and the Home item's click leaves `router.url` unchanged.
- [ ] **DW-1148: a doc correction, no code.**
  - DESIGN.md:904 becomes `| 1,920px | Home: collapsed · list: open (240) | 960 | 912 closed · 672 open | 400 | 1,232 | none [AMENDED 2026-10-14, Story 23.5, DW-1148] |`.
  - **Tests:**
    - `panel-layout.test.mjs` reads DESIGN.md's 1,920 row and asserts its "Content on Home" cell's first figure equals the test's `panelOnHome({}, 1920)` content width, with the side bar hidden. It is red on today's row.
    - Relabel `:296-299` as the open case.
    - `suggested-view.browser-spec.mjs:171-180`: at 1,920, content equals viewport − 48 − panel, in light and in dark.
- [ ] **DW-2107.** Add `app-agent-picker { display: contents; }` beside `.ocu-agent-picker` in `_components.scss:8671`, so its `max-width: 50%` resolves against the header. Test: new Leg 3 in `agent-picker.browser-spec.mjs`. With full screen on, `.ocu-agent-picker-name` has `scrollWidth <= clientWidth + 1`, in light and in dark.
- [ ] **DW-2163 and DW-2282.**
  - Add `settleViewport(page, viewport)` to `ui/browser/panel-spec.mjs`: `setViewport`, then wait for `documentElement.clientWidth === width`, then two animation frames.
  - Call it at `agent-picker.browser-spec.mjs:134` and `impact.browser-spec.mjs:378`.
  - `impact.browser-spec.mjs` also waits, after `:368`, until `.ocu-tool-call-spinner` is gone before its structural passes.

**Acceptance criteria:**

- Given a viewport where the bar returned because the panel narrowed, when the person drags wider, then the bar yields and the panel takes the width.
- Given full screen, when any rail item is activated, then nothing behind the cover changes.
- Given DESIGN.md's yield table, when compared with the shipped layout at 1,920, then its Home content figure matches.
- Given the panel header with room for the name, when it renders, then the picker shows the whole name.

### Batch d: list and detail pages

- [ ] **DW-1976.**
  - **Descriptor key.** A column may declare `long` (boolean, optional), validated alike by `Registry.cls` `TableProblem` and `screen-mirror.mjs`. The mirror's `TableColumn` gains `readonly long?: boolean;`. Regenerate `screens.generated.ts`, then declare `long: true` on `ExplorerSqlView` `Text`, `ExplorerSqlProcedure` `Description` and `ExplorerSqlTriggers` `Code`.
  - **`data-table.ts`.** After the grid, for each `long` column, render the selected row's value whole in an `app-long-block`, labeled by the column's header. When there is exactly one row, use that row's value. With several rows and none selected, render no block.
  - **CSS.** An added rule beside `.ocu-data-table-tooltip` gives the text `white-space: pre-wrap` and `overflow-wrap: anywhere`. The cell and its tooltip are unchanged.
  - **Docs.** Append the block's recipe to DESIGN.md:1042 and its behavior to EXPERIENCE.md:665, in place.
  - **Tests:**
    - `ColumnCorpus.cls`: a `long` that is not a boolean is refused, and `screen-mirror.test.mjs:1266` reads it alike.
    - `data-table.spec.ts`: one row with a 5,000-character `long` value gives a block holding the whole value. Two rows with none selected give no block; selecting row 2 shows its value.
    - `system-explorer-sql.browser-spec.mjs`: open `LONGVIEW`'s view tab at 720×450 and press Show more. The block holds `LONGVIEWMARK` and the whole text, and its region is not clipped (`scrollHeight <= clientHeight + 1`), in light and in dark.
- [ ] **DW-1978.**
  - **Template and CSS.** Add `[disablePagination]="true"` to `detail-page.ts`'s `mat-tab-nav-bar`. Add a rule after `_components.scss:2256`: `.ocu-detail-tabs .mat-mdc-tab-links { flex: 1 1 auto; flex-wrap: wrap; min-width: 0; }`.
  - **Docs.** The doc at `:46-48` now says a strip wider than its column wraps onto further rows. Append to DESIGN.md:1071: "A strip wider than its column wraps onto further 40px rows, each filling the column; no tab is paged or scrolled out of view."
  - **Tests:**
    - `system-explorer-sql.browser-spec.mjs`, after `:190`, at 1,024 and 1,280, in light and in dark: every `.ocu-detail-tab` lies inside the tab-link container, `.mat-mdc-tab-header-pagination` is not displayed, and each tab is 40px tall. Correct the comment at `:136-137`.
    - `detail-page.spec.ts`: a new `it` after the describe's first test reads the `MatTabNav` instance's `disablePagination` as `true`.

**Acceptance criteria:**

- Integration AC: given a SQL view's text longer than the window on the throwaway, when its tab renders with the row, then a person can read the whole text on the screen, by keyboard or pointer.
- Given a nine-tab strip at 1,024 to 1,600 px, when it renders, then every tab is visible without paging.

## Spec Change Log

- 2026-10-14, lead, spec gate: DW-1951 closed `resolved-by` Story 18.46 (`0220d1e4`). The two Named-for-filing items are DW-2439 (routed to the burn-down, proposed for 23.11) and DW-2440 (`wontfix-theoretical`). The story block in `epics.md` names the three kept later routings (Rule 5 tier 1). The 23.11 proposal and the Contended edits go to the orchestrator before Batch a's implement pass.

- 2026-10-15, lead: Batch a closed green (code head `69da7a5e`, CI run 38674536770). Re-opened for Batch b.

- 2026-10-15, lead: Batch b re-opened for one `[CI]` item (CI run 38688234353, DW-1329's recents leg).

## Review Triage Log

### 2026-10-14 - Review pass (Batch a)

- verdicts: 18 findings - high 0, medium 5, low 12, false 1, maybe-false 0
- findings:
  - `[medium]` `[patch]` `turn-limit.browser-spec.mjs:199,208` still expects the plural at a limit of 1 - read the spec: AC3 runs `setLimit(1)`; switched both expectations to `agentTurnLimitBannerOne` and `agentTurnLimitLineOne`; spec green.
  - `[medium]` `[patch]` `system-explorer-transfer.browser-spec.mjs:248` still expects "Imported 1 documents." - one class imported; switched to `explorerImportDoneOne`; spec green.
  - `[medium]` `[patch]` `error-log-delete.browser-spec.mjs:252` still expects the plural residue sentence - `seeded` is 1 (a green run on the singular proves it); the expectation now follows `seeded`; spec green.
  - `[medium]` `[patch]` `Disclosure.Rows` object arm and non-container fallback pinned by no test - added `ProposalWire.TestAnOpaqueObjectReadsItsMemberCountAndAScalarReadsTheMask` (an object counts 2, a string and `null` read the mask); dropping the `"object"` arm and dropping the type test each reddened it alone; 17 of 17 green after revert, tree byte-identical.
  - `[low]` `[reject]` AC1's per-consumer singular cases have no recorded `mutation:` line - Rule 19 asks one demonstrated mutation per AC; AC1 has four recorded lines (rule, data table, scan, code list), and a line per assertion site would be per-assertion.
  - `[low]` `[defer]` count strings outside Batch a's table read the plural at 1 ("Stopped after 1 seconds.") - `explorerSqlStopped` takes a server-recorded count; the census is a sweep, so it is in the frontmatter `deferred:` list (low).
  - `[low]` `[reject]` `explorerCompileStoppedOne` is unreachable (a stop with one document always ends in the summary) - Batch a's table lists it; implemented as specified and pinned by the key-pairing check.
  - `[low]` `[patch]` `ProposalWire.cls` doc says the users tool is the only classified entry with an `opaque` row - `ToolFields.cls` carries 26 `opaque` rows across other tools; the sentence is replaced.
  - `[low]` `[reject]` the DW-2227 wait repeats the predicate of the later `settled` assertions - the spec prescribes the wait and leaves the assertions unchanged; a failure now shows as a wait timeout.
  - `[low]` `[reject]` `users-write.browser-spec.mjs` pins "0 items" for `EscalationRoles` - the task reads the count from the stored user and `EnsureUser` creates the account with no escalation roles; non-zero counts are pinned by `ProposalWire` (1 and 2, and the object case), `proposal-card.spec.ts` and `proposal-view.test.mjs`.
  - `[low]` `[patch]` `screen-grounding.browser-spec.mjs:153,177` match `/(\d+) rows/` - would miss a one-row chip; both now match `rows?\b`; spec green.
  - `[low]` `[reject]` (intent-alignment) users update card: 1 and 2 appear only in synthetic places - same row as the `users-write` finding above.
  - `[medium]` `[patch]` (intent-alignment) other opaque tools untested - same root cause as the `Disclosure.Rows` finding above; closed by the same test.
  - `[low]` `[defer]` (intent-alignment) "any count" in AC1 is wider than Batch a's table - same root cause as the deferred census above.
  - `[low]` `[reject]` (intent-alignment) a singular is pinned in jsdom or tools tests only, `explorerCompileStoppedOne` by existence, the panel turn-limit spec uses 3 - the spec asks for a singular case per consumer spec plus the named Integration ACs; `turn-limit.test.mjs` and the patched `turn-limit.browser-spec.mjs` pin a limit of 1.
  - `[low]` `[reject]` (intent-alignment) `Api/Error.cls` `REASONTURNLIMITHOUR` still reads the plural - the client builds both turn-limit sentences from `detail`, and `turn-limit.test.mjs:176` pins the server sentence equal to the plural string.
  - `[low]` `[reject]` (intent-alignment) red-before-fix order is not visible and DW-2227 has no recorded red - the spec's mutation line allows "no red reproduces"; the order is not checkable from a diff.
  - `[false]` `[reject]` (intent-alignment) Batches b, c and d are not in the diff - they are scheduled passes, not a divergence of reading.

### 2026-10-14 - Review pass (Batch b)

- verdicts: 16 findings - high 0, medium 4, low 12, false 0, maybe-false 0
- findings:
  - `[medium]` `[patch]` the `app.spec.ts` sign-out case no longer pins `recentsRecorder.reset()`: signing in reloads the instance's recents - asserted the list, so the reload satisfied it; now asserts the visit's POST after the sign-in, and deleting the reset reddens it (mutation recorded).
  - `[medium]` `[patch]` the unreadable-ok-answer branch of `Findings.load` (`rejected`) is run by no test - added a tools case and a `home.page.spec.ts` case; recording it as a banner kind reddens both.
  - `[medium]` `[patch]` a change of fault kind between two failed reads is untested for `SystemInfo` and `Findings` - added tools cases and two `home.page.spec.ts` cases; holding the first fault reddens all four.
  - `[medium]` `[patch]` "closes the dialog first" is not observable in either test that claims it - both now spy on `navigateByUrl` and assert the order; moving the emit, or dropping the binding, reddens them.
  - `[low]` `[patch]` Batch b lacks mutation lines for the 404 half, the Retry wiring, the `(logOpened)` binding and the `reset()` re-run - all demonstrated and recorded under Verification as `(CR)` lines.
  - `[low]` `[reject]` AC 2's "with the shell's banner counted" has no page-level test - the spec prescribes the block-level tests (Tasks, DW-1401); a page-level count needs the shell and a Home block mounted together, which no existing spec does.
  - `[low]` `[reject]` `rejected` for an unreadable ok answer reads oddly beside the kind's definition - the comment at `findings.ts` states why; a new kind adds surface for no user-visible gain.
  - `[low]` `[reject]` the `about-help-links` "shipped bundle matches the stamp" leg is red after any `docker cp` of a changed bundle - environmental, not changed by this diff; the throwaway keeps the stamp recorded at container start (a fresh throwaway matches, inference).
  - `[low]` `[reject]` DW-1341's gate is wider than the matrix row (the `probing` state registers nothing) - the spec text prescribes `isSignedIn(session.state())`; `preferences-integration.browser-spec.mjs` ran green on the redeployed bundle.
  - `[low]` `[patch]` DW-1368 releases a 5xx and an install-in-flight answer too, and the locator bar's comment still says a router event costs at most one request per screen - the width is spec-prescribed; the comment now says "once the instance has answered".
  - `[low]` `[reject]` the stale-bundle announcement cannot be observed and the blocking case is jsdom-only - inherent to a live region; the spec prescribes these tests.
  - `[low]` `[reject]` the page-level picture (the shell's banner behind the modal plus the dialog's alert) is asserted nowhere - the Design Notes decide that About shows its own alert because the dialog is `aria-modal`.
  - `[low]` `[reject]` `.ocu-about-fault` is unreferenced - `_components.scss` is Epic 20's file and add-only here; `reopen_if` a later pass may edit that file's existing lines (delete the rule, six lines).
  - `[low]` `[defer]` Home's two blocks are not re-read when the shell's banner clears - pre-existing, in the frontmatter `deferred:` list (low).
  - `[low]` `[reject]` findings at a 5xx is untested, and the in-place banner is wider than "a 404" - a 5xx and status 0 share `isBannerFault`, tested at status 0 and for System Information at 503; "any other fault" is the spec's wording.
  - `[low]` `[reject]` DW-1392's test asserts no clip, not growth, and sibling rows keep a fixed height - restoring `height:` reddens it (scrollHeight 52, clientHeight 32); the siblings are under Named for filing.
- also, not from a layer:
  - `[medium]` `[patch]` (implement report) a Retry that answers removes the focused button, so focus falls to the body and the dialog's trap no longer hears Tab - `Dialog.keepFocusInside`, called after the render that follows the read; a focus case in `about-dialog.spec.ts`, red with the call dropped.
  - `[low]` `[patch]` (lead read) `home.page.ts`'s class doc still said an unanswered read renders the connectivity fault in place - replaced.

## Design Notes

**Verdicts at head `6c58e1c9`** (Rule 17 inbox; each row's evidence was read at the current head):

| Entry | Verdict | Evidence | Batch |
| --- | --- | --- | --- |
| DW-458 | confirmed | `panel-layout.ts:114-117`: `panelMax` subtracts a bar that showed because the panel narrowed; `applyWidth` clamps at `:361` | c |
| DW-460 | confirmed | `rail.ts:238-239` has no full-screen guard, while `side-bar.ts:280` ignores Ctrl/Cmd+B | c |
| DW-1148 | confirmed (doc) | DESIGN.md:904 says 672. Home closes the bar (`shell-state.ts:216-218`), so content is 1,920 − 48 − 960 = 912, as EXPERIENCE.md:949 says | c |
| DW-1341 | confirmed | `recents-recorder.ts:42-45,59-64` records with no signed-in check | b |
| DW-1342 | confirmed | `locator-bar.ts:507-523` has no in-flight guard | b |
| DW-1368 | confirmed | `help.ts:108` adds to `asked` before the await; `:49` answers `''` for every non-ok result | b |
| DW-1371 | confirmed | `app.ts:229` mounts the strip outside every gate | b |
| DW-1372 | confirmed | `stale-bundle-notice.ts:33-34` puts `role="status"` inside the `@if` | b |
| DW-1392 | confirmed | `_components.scss:5798` sets `height` on `.ocu-home-system-row` | b |
| DW-1401 | confirmed | `about-dialog.ts:83`, `home.page.ts:407` and `findings-panel.ts:54` render a plain `<p>`; `about.ts:149-155` and `system-info.ts:128-134` keep a boolean | b |
| DW-1436 | confirmed | `Disclosure.cls:71-78` has two outcomes and `:186-187` admits ordinary only; `ToolFields.cls:229-230` classifies the arrays opaque | a |
| DW-1951 | already fixed | `data-table.ts:868-871` answers `actionLabel` (0220d1e4, Story 18.46); all 44 primary ids resolve to a label | none |
| DW-1976 | confirmed | `_components.scss:2388-2409` (nowrap, ellipsis), `:6441-6456` (no max-height); the tooltip is `aria-hidden` (`data-table.ts:468-478`) | d |
| DW-1978 | confirmed | `detail-page.ts:64-70` paginates with mouse-only arrows; nine tabs are about 1,150px (inference, from the labels and 48px padding) | d |
| DW-1985 | confirmed | `data-table.ts:1080` and three more fill `'<n> rows'` (`strings.ts:373`) at any count | a |
| DW-2101 | confirmed | 26 count strings have no singular (Batch a's table); `code-list.page.ts:579` | a |
| DW-2107 | confirmed | `_components.scss:8676` `max-width: 50%` resolves against the unstyled host, which is sized to its content (inference; Leg 3 measures it) | c |
| DW-2163 | confirmed | `agent-picker.browser-spec.mjs:134` measures after `setViewport` with no settle; the layout re-resolves on `(window:resize)` (`app.ts:220`) | c |
| DW-2182 | confirmed | `WireSecurityRead.cls:498` reads the unscoped history, and the helper asserts `truncated` 0 (`:1099`) | 23.11 |
| DW-2202 | confirmed | an area count of 11 is written out in 7 files (`screen-mirror.test.mjs:116`, `Descriptor.cls:1925`, …), and the entity-type count of 73 at `Descriptor.cls:1793` | 23.11 |
| DW-2221 | confirmed | `browser.config.mjs:73,99` defaults both; `browser-config.test.mjs:11-15` allows both unset | 23.11 |
| DW-2227 | confirmed | `proposal-confirm.browser-spec.mjs:209-218` reads focus in one evaluate after the status-line wait | a |
| DW-2246 | confirmed (inference) | red in runs 158 and 535 at fe8e3832. `Bound.cls:126-150` measures the base with `rowsSent` 0 but writes the kept count, so a kept set within two characters of the cap is refused | 23.11 |
| DW-2282 | confirmed | a 16×16 rotating spinner (`_components.scss:4355-4368`) has a bounding box up to 22.6px, 3.3px past each side, against the walk's 1px | c |

Counts: 23 confirmed (DW-1148 in the doc only, DW-2246 by inference), 0 refuted, 1 already fixed.

**Proposed for Story 23.11.** None of these gets a task here, and each stays owned by this key until 23.11 is chartered.

- Proposed for Story 23.11: DW-2182 -- an ObjectScript test-scoping fix, in no area batch the 17 entries open.
- Proposed for Story 23.11: DW-2202 -- a sweep of about 15 to 18 literal sites in about 9 files (estimate), most in Epic-20-contended tests; too big for the size bound.
- Proposed for Story 23.11: DW-2221 -- browser-harness tooling (`browser.config.mjs`, its test, `preferences-reset.mjs:51`'s module-scope call, DEVELOPMENT.md:483 and `CLAUDE.md:129`), in no area batch the 17 open.
- Proposed for Story 23.11: DW-2246 -- a kernel bound fix in `Kernel/Agent/Bound.cls`, which is agent reads, in no area batch the 17 open. Reproduce it on `AdminPort` first.

DW-2163, DW-2227 and DW-2282 stay: each is about 3 to 5 test lines in a batch these entries already open.

**Declined:** none.

**Decisions:**

- **DW-460: ignore the click.** EXPERIENCE.md:703 and `:816` make the toggle the one way to restore, and every full-screen guard already ignores input: Ctrl/Cmd+B, Escape and the skip link.
- **DW-458: the drag wins.** DESIGN.md's yield order collapses the bar before the panel shrinks. This was the ledger's recommendation, routed by the merge gate.
- **DW-1148: correct the doc, not the code.** EXPERIENCE.md:53 and `:949` describe the shipped arrival; changing the code to fit the row would contradict both. It is a Rule 5 tier-1 amendment (apply and report), listed under `amendments:`.
- **DW-1976: a declared long column shown in a long block.** A scrolling tooltip is pointer-only, and wrapping rows breaks the virtualized row height (DESIGN.md:912).
- **DW-1978: wrap the strip.** The pagination arrows are mouse-only, and an overflow menu would be a new control.
- **DW-1401: the Home blocks add no alert for a banner fault.** `api.ts:425` already raises the shell's one banner, as `panel.ts:976-986` relies on. About shows its own because the dialog is `aria-modal`.
- **DW-1436: a count is safe.** It releases no member, and a changed opaque value already shows in clear in the diff (AD-3, AD-35).

**Governing ADs (Rule 6):**

| Batch | ADs and conventions |
| --- | --- |
| a | AD-19, AD-3, AD-35, AD-6, AD-36; Conventions › Client asset homes, Tests |
| b | AD-19, AD-50, AD-28, AD-12, AD-39; Conventions › Error shape, Theme |
| c | AD-19, AD-50; Conventions › Theme, Angular naming |
| d | AD-5, AD-36, AD-19; Conventions › Screen archetype, Theme |

No AC contradicts an AD. No read bound or envelope changes.

**Integration ACs (Rule 1).** Each shared piece has its consumer, and an Integration AC against the throwaway, in this story:

- `core/count-phrase.ts`: Batch a, `context-chip.browser-spec.mjs`.
- `FaultBanner`'s in-place mode: Batch b, `about-help-links.browser-spec.mjs`.
- Column key `long`: Batch d, `system-explorer-sql.browser-spec.mjs`.
- Disclosure `count`: Batch a, `users-write.browser-spec.mjs`.

Consumed-by (all Story 23.5):

- `core/count-phrase.ts`: the data table, the command bar, the context chip, the ledger page, the tool-call card, the command box, the code list, store and compare, the proposal card, the OAuth resource server form, the try-it viewer, the turn limit, guardrails, the definition form, the interop test dialog, the data browser, the SQL answer, impact, form tabs, and the export, compile and broadcast dialogs.
- `FaultBanner` in place: the About dialog, and Home's System Information and findings blocks.
- `long`: `DataTable` on `ExplorerSqlView`, `ExplorerSqlProcedure` and `ExplorerSqlTriggers`.
- Disclosure `count`: the proposal card's unchanged rows.
- `settleViewport` (`panel-spec.mjs`): `agent-picker.browser-spec.mjs`, `impact.browser-spec.mjs`.

Consumes: `app-long-block` (Story 20.17), in DW-1976's block.

**Siblings (Rule 31):**

- `count-phrase.ts` promotes `data-browser-model.ts:243`'s `pickCount` and replaces the copy in `sql-answer.ts:21`.
- `FaultBanner` is extended, not copied.
- `help.ts` reuses `classifyFault` and `isBannerFault`, as `panel.ts:980-985` does.
- The favorite guard follows `read-only-toggle.ts:36`.
- The status region follows `account-menu.ts:155`.
- `long` follows `emptyKey`'s validation path and reuses `long-block.ts`.
- `settleViewport` promotes `panel.browser-spec.mjs:728-730`'s local copy.

**Contended edits** (Epic 20's files; each of these modifies existing lines, so each needs the orchestrator's approval):

- `ui/src/styles/_components.scss:5798`: `height:` becomes `min-height:` (DW-1392). The other SCSS changes are added rules, clear of Epic 20's hunks at `:2167`, `:2178` and `:2599-2638`.
- `ui/src/app/shell/detail-page.ts:46-48`: "A strip wider than the content column pages, and the focused tab is scrolled into view." becomes the wrap contract (DW-1978). The attribute is an added line. Epic 20's hunks are `:1`, `:55` and `:90-104`.
- `src/OcuPilot/Screen/Registry.cls:2662` (and the doc at `:2637`): `"long"` joins the column key list (DW-1976). Epic 20's hunk is `:1707`.
- `ui/tools/screen-mirror.mjs:3050` (and the doc at `:3027`): `'long'` joins the column key list. Epic 20's hunks are `:1107-1135` and `:1930-1950`.
- `ui/src/app/core/screens.generated.ts`: regenerated. Regenerate again after every forward merge; never hand-merge it.
- EXPERIENCE.md, in place (every edit there modifies a line):
  - Fixed strings rows 260, 276, 281, 307, 313, 336, 352, 519, 574, 583, 589, 591, 594 and 604 gain singulars.
  - Rows 633 and 665 gain one clause each.
  - Row 604 is also Epic 20's, so it is a same-line merge.

Add-only in contended files:

- `strings.ts`: new keys beside their plurals, never at the end, where Epic 20 appends.
- `detail-page.spec.ts`: a new `it` after the first test, and a new import line after `:12`.

**Lead edits (Rule 20, at Batch d's boundary).** In the spine's Conventions › Screen archetype row, after the `emptyKey` parenthesis, add: "and `long`, `true` where a column's value can run past its cell, whose selected or only row's value then shows whole beneath the rows [AMENDED 2026-10-14, Story 23.5, DW-1976, Rule 20]". Then the memlog append, `lint_spine.py`, and `updated:`. DW-1148's DESIGN.md row is the implement pass's; the lead records the original and amended wording in the Spec Change Log.

**Planned dispositions:**

- DW-1951: `resolved-by:18-46-allowed-directories-the-screen-s-add-change-and-remove` (0220d1e4), at the spec gate.
- Every tasked entry: `resolved-by:23-5-the-range-end-cleanup-part-5`, with its batch's commit.

**Named for filing:**

- About twenty fixed heights on text-bearing controls and rows against DESIGN.md:912, for example `_components.scss:1001`, `:1548` (DESIGN.md:327 says min-height) and `:5571`.
- `.ocu-proposal-card-confirm-spinner` (`:4794`) has the rotating spinner's shape (inference).

## Verification

**Slot A.**

- The MCP profile is `ocupilot-slot-a`: the dev instance, never the throwaway.
- The throwaway is `ocupilot-ci` (dir `/Users/jbrandt/.ocupilot-throwaways/ocupilot-ci`, web 52776, super 1975). Use it only once it reads `healthy`, and never down it.
- Keep one test run in flight. Every command is `(loop)`; the lead runs the full ObjectScript sweep and the fresh browser run.

**Shared steps:**

- Load (loop): `rsync -a --delete src/ /Users/jbrandt/.ocupilot-throwaways/ocupilot-ci/src/`, then run `Do $System.OBJ.LoadDir("/opt/ocupilot/src","ck-d",.e,1)` in `docker exec -i ocupilot-ci iris session iris -U HSCUSTOM`. Expected: 0 errors.
- Class (loop): `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.<C>`. Expected: 0 failed, confirmed in `%UnitTest_Result`.
- Deploy (loop): `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`. Expected: the prebuild checkers and the bundle budgets pass.
- Spec (loop): `cd ui && OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci node --test --test-concurrency=1 browser/<name>.browser-spec.mjs`, after Deploy. Expected: green.
- Checks (loop):
  - `cd ui && npm run test:tools` and `cd ui && npm run test:components` are green.
  - `uv run scripts/check-objectscript.py <changed .cls>` is clean.
  - `bash scripts/lint-docs.sh` is clean when Markdown changes.

**Shared surfaces:**

- Count copy:
  - `code-list.page.spec.ts:540,614`, `panel.spec.ts:1716,1757` (also assert `not.toContain('1 rows')`), `command-box.spec.ts:242,643,692,1114`;
  - `context-chip.browser-spec.mjs:318,415,448,525,529`, `account-and-filter.browser-spec.mjs:262`;
  - `ledger.page.spec.ts:148`, `sql-query.page.spec.ts:223`, `table-model.test.mjs:123-126`, `strings.test.mjs:613,766-776`.
- Unchanged disclosure rows: `ProposalWire.cls:277-304`, `users-write.browser-spec.mjs:290-322`. `proposal-demo.browser-spec.mjs:414-416` stays masked.
- Panel layout: `panel-layout.test.mjs:197,218-219,296-299`, `panel.browser-spec.mjs:325-328`, `suggested-view.browser-spec.mjs:171-180`.
- Stale region: `stale-bundle-notice.spec.ts:126`, `about-help-links.browser-spec.mjs:381-388`, `app.spec.ts:1068-1094`.
- Fault copy: `about-dialog.spec.ts:110-113`, `home.page.spec.ts:1222-1235,1688`, `fault-banner*.spec.ts`.
- Column keys: `ColumnCorpus`, `screen-mirror.test.mjs:1266`, `screens.generated.ts`.
- Tab strip: `system-explorer-sql.browser-spec.mjs:136-142`. Tooltip legs: `data-table-columns.browser-spec.mjs`.

Every test added or changed passes on a fresh environment, in either order.

**Batch a (loop):**

- Run Checks; Load; Class `ProposalWire`, then each class the `Mask()` sweep of `src/OcuPilot/Test` changes, one per call. Then Deploy, and run Spec for `context-chip`, `account-and-filter`, `users-write` and `proposal-confirm`.
- `mutation:` `=== 1` became `<= 1` in `pickCount` -> `count-phrase.test.mjs` red: the `pickCount` case and the `rowCountPhrase` 0 case.
- `mutation:` `data-table.ts` filled `formatRowCount(STRINGS.tableRowCount, …)` again -> `data-table.spec.ts`'s one-row case red ("1 rows"), and `context-chip.browser-spec.mjs`'s one-row Integration AC red (footer "1 rows"; bundle rebuilt and redeployed).
- `mutation:` `impact.ts` chose `part.count === 1 ? phrases.one : …` inline again -> `count-phrase.test.mjs`'s scan red.
- `mutation:` the code list's two export summaries filled their plural strings alone -> `code-list.page.spec.ts` red: the browser-export case and the one-exported-document case.
- `mutation:` `Disclosure.Rows` skipped its opaque branch (`ElseIf 0 && …`) and wrote `Mask()` -> `ProposalWire.TestTheUserToolsDisclosureCountsBothRoleArrays` red (1 of 16), and `users-write.browser-spec.mjs`'s AC1 red (the `EscalationRoles` row read the mask).
- `mutation:` the `count` line dropped from `parseProposalUnchanged` in `turn.ts` -> `proposal-card.spec.ts`'s classified-opaque case red ("(none)"), and `proposal-view.test.mjs`'s parse case red.
- `mutation:` `Disclosure.Rows` dropped the `"object"` arm of its type test, then the whole type test -> `ProposalWire.TestAnOpaqueObjectReadsItsMemberCountAndAScalarReadsTheMask` red in both (1 of 17).
- `mutation:` DW-2227: the added wait dropped, with `Emulation.setCPUThrottlingRate` 20 set before Confirm -> no red in 3 runs of AC10; the wait stands on its mechanism.
- (QA) Tests changed: `ui/browser/system-explorer-find.browser-spec.mjs` (AC4 derives the Compare sentence from the drawn rows), `ui/browser/turn.browser-spec.mjs` (the rows line follows its count), `ui/tools/count-phrase.test.mjs` (a scan of the tests' own count patterns). Run Spec for `system-explorer-find` and `turn` after Deploy; the scan runs with Checks.
- (QA) `mutation:` `code-compare.page.ts` filled `STRINGS.explorerCompareSummary` alone (bundle rebuilt and redeployed) -> `system-explorer-find.browser-spec.mjs` AC4 red ("12 lines removed · 1 lines added").
- (QA) `mutation:` the old `/^\d+ lines removed · \d+ lines added$/` back in `system-explorer-find.browser-spec.mjs` -> `count-phrase.test.mjs`'s test scan red.
- (CR) Tests changed: `ui/tools/count-phrase.test.mjs` (the singular-key and fill scans), `ui/tools/sql-answer.test.mjs`, `data-browser.page.spec.ts`, `definition-form.page.spec.ts`, `ui/browser/system-explorer-find.browser-spec.mjs` (the expected sentence from the four templates). Shared surfaces for DW-2441's strings (`sql-query.page.spec.ts:338,353,541`, `data-browser.page.spec.ts:604,851`, `definitions.browser-spec.mjs:690,699`, `turn.test.mjs:2425`) fill counts other than 1 and are unchanged.
- (CR) `mutation:` a private `pick(count, one, many)` restored in `core/sql-answer.ts` and called for the stopped line -> `count-phrase.test.mjs`'s singular-key scan red (`core/sql-answer.ts:114`).
- (CR) `mutation:` `system-explorer-transfer.browser-spec.mjs:226` filled `explorerImportDone` with `'1'` -> `count-phrase.test.mjs`'s fill scan red.
- (CR) `mutation:` `statusLineFor` filled `explorerSqlStopped` and `explorerSqlStoppedUndone` alone -> `sql-answer.test.mjs`'s one-second case red ("Stopped after 1 seconds."); `data-browser.page.ts`, `data-browser.store.ts` and `testTimeoutText` filled their plurals alone -> `data-browser.page.spec.ts`'s two one-second legs and `definition-form.page.spec.ts`'s Story 10.5 case red.
- (CR) `mutation:` QA's Compare mutation re-run against the template-chosen expectation (bundle rebuilt and redeployed) -> AC4 red ("12 lines removed · 1 lines added"); clean bundle redeployed, 6 of 6 green.

**Batch b (loop):**

- Run Checks and Deploy, then Spec for `about-help-links` and `home-system-information` (light and dark).
- `mutation:` the session guard dropped from `RecentsRecorder.record` -> `recents-recorder.spec.ts`'s signed-out case red (one `POST /account/preferences` from a tab in state `form`).
- `mutation:` the `favoritePendingRoute() === route` guard dropped from `toggleFavorite` -> `locator-bar.spec.ts`'s double-star case red (2 writes for 1 star).
- `mutation:` `this.asked.delete(route)` dropped from `HelpLinks.load` -> `about.test.mjs`'s "asked for again" case red.
- `mutation:` the `[shown]` binding dropped from `app.ts` -> `app.spec.ts`'s stale-bundle case red (`.ocu-stale-bundle` standing over `app-instance-notice`).
- `mutation:` the `role="status"` span moved back inside the `@if` -> `stale-bundle-notice.spec.ts` red: the same-node case and the held-back case (2 of 10).
- `mutation:` `FaultBanner.message` drew the generic sentence whatever the kind -> `about-dialog.spec.ts` red (the unreachable case and the Retry case, 2 of 7), and `about-help-links.browser-spec.mjs`'s status-0 Integration AC red (bundle rebuilt and redeployed; the status-500 leg stayed green).
- `mutation:` Home returned the unfiltered fault from `systemFault` and `findingsFault` -> `home.page.spec.ts` red: the System Information and Findings banner-fault cases (2 of 69).
- `mutation:` `.ocu-home-system-row` back to `height:` (bundle rebuilt and redeployed) -> `home-system-information.browser-spec.mjs`'s doubled-type case red in light and in dark (the Uptime row: `scrollHeight` 52, `clientHeight` 32).
- (implement) Tests changed: `recents-recorder.spec.ts`, `locator-bar.spec.ts`, `app.spec.ts` (a stale-bundle case, and the sign-out case signs in again before the resumed arrival), `stale-bundle-notice.spec.ts`, `fault-banner.spec.ts` (in-place cases), `about-dialog.spec.ts`, `home.page.spec.ts`, `ui/tools/about.test.mjs`, `ui/browser/about-help-links.browser-spec.mjs` (two About-fault legs; the status region retargeted), `ui/browser/home-system-information.browser-spec.mjs` (doubled type, light and dark); `testing/about.ts`, `testing/system-info.ts` and `testing/findings.ts` gain `setStatus`.
- (implement) Run Spec for `about-help-links` after Deploy: its "shipped bundle matches the stamp the installer recorded" leg reads red after any `docker cp` of a changed bundle (the version row keeps the stamp recorded at container start, `main-AIHA3XSZ.js` against the deployed `main-M7KNPJ2F.js`); the other eight legs are green.
- (CR) Tests changed: `app.spec.ts` (the sign-out case asserts the visit's write, not the reloaded list), `fault-banner.spec.ts` and `about-dialog.spec.ts` (navigation order through a `navigateByUrl` spy; focus after Retry), `ui/tools/system-info.test.mjs` and `ui/tools/findings.test.mjs` (fault kind, change of kind, an unreadable ok answer), `home.page.spec.ts` (change of kind, unreadable findings). `dialog.ts` gains `keepFocusInside`, called from `AboutDialog.reread`.
- (CR) `mutation:` `this.recentsRecorder.reset()` deleted from `app.ts` -> `app.spec.ts`'s sign-out case red (no recents write after the sign-in).
- (CR) `mutation:` `this.logOpened.emit()` moved below the navigation in `fault-banner.ts` -> `fault-banner.spec.ts`'s order case and `about-dialog.spec.ts`'s close-before-navigate case red; `(logOpened)="closed.emit()"` dropped from `about-dialog.ts` -> the latter red.
- (CR) `mutation:` the `afterNextRender` call dropped from `AboutDialog.reread` -> `about-dialog.spec.ts`'s focus case red (focus on the body).
- (CR) `mutation:` `AboutDialog.reread` no longer reads, then `onSystemRetry` and `onFindingsRetry` no longer read -> `about-dialog.spec.ts` red (2 of 8) and `home.page.spec.ts` red (the two Retry cases).
- (CR) `mutation:` `systemFault` and `findingsFault` always answer `null` -> 5 `home.page.spec.ts` cases red (the 404 cases, the change-of-kind cases, the unreadable-answer case).
- (CR) `mutation:` `SystemInfo.load` and `Findings.load` keep the first fault they hold (`??=`) -> both tools tests red and the two change-of-kind `home.page.spec.ts` cases red.
- (CR) `mutation:` `Findings.load` records an unreadable ok answer as `server-fault` -> its tools test and `home.page.spec.ts`'s unreadable-answer case red.
- (QA) Tests changed: `ui/browser/home-system-information.browser-spec.mjs` (a System Information and a Findings read failed with status 0 and with a 404, counting every alert in the document), `ui/browser/preferences-integration.browser-spec.mjs` (DW-1342 double activation; DW-1341 Back while signed out), `ui/browser/about-help-links.browser-spec.mjs` (DW-1371 stale identity under a version-mismatch notice; `rewriteBuildIdentity` takes `overrides`). Run Spec for `home-system-information`, `preferences-integration` and `about-help-links` after Deploy; the last still reads 9 of 10 locally, its stamp leg being the environmental red above.
- (QA) `mutation:` the `isSignedIn(this.session.state())` guard dropped from `RecentsRecorder.record` (bundle rebuilt and redeployed) -> `preferences-integration.browser-spec.mjs`'s DW-1341 leg red (a `recent` write for `permissions/users` left the signed-out tab).
- (QA) `mutation:` the `favoritePendingRoute() === route` guard dropped from `toggleFavorite` -> the DW-1342 leg red (two favorite writes while the first is open).
- (QA) `mutation:` the `[shown]="staleNoticeShown"` binding dropped from `app.ts` -> `about-help-links.browser-spec.mjs`'s DW-1371 leg red (the strip stood over the version-mismatch notice).
- (QA) `mutation:` Home returned the unfiltered fault from `systemFault` and `findingsFault` -> `home-system-information.browser-spec.mjs`'s two status-0 legs red (a second alert inside the block beside the shell's).
- (QA) `mutation:` `systemFault` and `findingsFault` answered `null` for every fault -> the two 404 legs red (no in-place banner).
- (QA) `mutation:` `FaultBanner.serverFault` true for `server-fault` alone -> the two 404 legs red (the unreachable sentence and Retry alone); the About status-500 leg stayed green, since a 500 is that kind.
- (QA) `mutation:` `(logOpened)="closed.emit()"` dropped from `about-dialog.ts` -> `about-help-links.browser-spec.mjs`'s status-500 leg red (the dialog stayed over the navigation); `AboutDialog.reread` no longer reading -> its status-0 leg red (no rows after Retry); `FaultBanner.message` always the unreachable sentence -> the status-500 leg red.
- (code review) Tests changed: `ui/tools/system-info.test.mjs`, `ui/tools/findings.test.mjs` (a banner fault parked and read again; a 404 not parked), `ui/tools/about.test.mjs` (change of fault kind), `locator-bar.spec.ts` (release after a refusal), `about-dialog.spec.ts` (Retry read settling after the close), `home.page.spec.ts` (pending case retargeted), `ui/browser/home-system-information.browser-spec.mjs` (the status-0 legs wait for the rows once the read answers; real 404 envelope), `ui/browser/about-help-links.browser-spec.mjs` (real 500 envelope). `npm run test:tools` 2023 of 2023; `npm run test:components` 3184 of 3184; `npm run build` passes; on the redeployed bundle `home-system-information` 8 of 8 and `about-help-links` 9 of 10 (the stamp leg, environmental).
- (code review) `mutation:` the `retryWhenReachable` park dropped from `SystemInfo.load`, then from `Findings.load` -> each store's park case red (one call, not two); with both dropped (bundle rebuilt and redeployed) -> both status-0 legs of `home-system-information.browser-spec.mjs` red at the rows wait. With a 5 s wait before the banner wait, the same legs were green on the patched bundle and red on the bundle without the park.
- (code review) `mutation:` `About.load` returns whenever a fault is held -> `about.test.mjs`'s change-of-kind case red (notified 1, not 2).
- (code review) `mutation:` `settleFavorite` moved below the early return in `toggleFavorite`'s fulfilled arm -> `locator-bar.spec.ts`'s DW-1326 case red (`aria-disabled` still set).
- (code review) `mutation:` `if (this.gone) return;` dropped from `AboutDialog.reread` -> `about-dialog.spec.ts`'s closed-during-Retry case red (NG0911).
- (code review) `mutation:` the System Information banner mounted on `!systemAnswered` -> `home.page.spec.ts` red (the pending case and the banner-fault case, 2 of 72). Every source mutation reverted, tree byte-identical, clean bundle redeployed.

**Batch c (loop):**

- Run Checks and Deploy, then Spec for `panel`, `suggested-view`, `agent-picker` and `impact`; each geometry leg runs in light and dark.
- `mutation:` restore `available - CONTENT_MIN_WIDTH`. Expected red: the new tools case and the 1,280 browser leg.
- `mutation:` drop the full-screen guard. Expected red: `rail.spec.ts`.
- `mutation:` DW-1148 is red on today's row before the correction. After it, `areaHasSideBar('home')` answering `true` turns the row pin and `suggested-view` red.
- `mutation:` delete the host rule. Expected red: Leg 3.
- `mutation:` drop `settleViewport` under 20× CPU throttle, and drop the spinner wait with the scripted reply held. Expected red: the 720px gates. If no red reproduces, record that.

**Batch d (loop):**

- Run Load, then Class `ColumnCorpus` and Class `ExplorerDescriptor`, then Checks, then Deploy. Then run Spec for `system-explorer-sql` (light and dark) and `data-table-columns`.
- `mutation:` drop the `long` arm in `Registry.cls`, then in `screen-mirror.mjs`. Expected red: `ColumnCorpus`, then `screen-mirror.test.mjs`.
- `mutation:` the block renders `''`. Expected red: `data-table.spec.ts`.
- `mutation:` remove `long` from `ExplorerSqlView`. Expected red: the browser leg.
- `mutation:` drop `flex-wrap`. Expected red: the strip leg.
- `mutation:` drop `disablePagination`. Expected red: `detail-page.spec.ts`.

## Auto Run Result

**Pass: Batch b (shell state, Home and About). Batches c and d are untouched and unchecked.**

Status: done
Blocking condition: none

- **Change.** `RecentsRecorder` registers nothing off a signed-in session; the favorite star holds a per-route pending signal and `aria-disabled`; `helpHrefFor` answers `null` where the instance could not say and `HelpLinks.load` asks again; the stale-bundle strip waits behind a blocking instance notice and its `role="status"` region is always mounted; `About`, `SystemInfo` and `Findings` keep a classified `Fault`, and `FaultBanner` draws one in place (`fault` input, `retried` and `logOpened` outputs) in the About dialog and in Home's two blocks for a non-banner fault; `.ocu-home-system-row` takes `min-height`. `Dialog.keepFocusInside` returns focus after About's Retry answers.
- **Files.** Source: `ui/src/app/{app,core,shell,areas/home,testing}` (recents-recorder, locator-bar, help, stale-bundle-notice, fault-banner, about-dialog, dialog, about, system-info, findings, fault, home.page, findings-panel, three testing stubs), `ui/src/styles/_components.scss` (one line). Tests: 8 component specs, `about`, `system-info` and `findings` tools tests, 2 browser specs.
- **Review.** 16 findings: 0 high, 4 medium, 12 low. Patched 9 entries (5 medium including the focus fix from the implement report, 4 low): the recents pin, the unreadable-answer and change-of-kind cases, the close-before-navigate order, the mutation lines, two stale comments. Deferred 1 (low): Home's blocks are not re-read when the banner clears. Rejected 8, each with its reason in the Review Triage Log.
- **Follow-up review: false.** No patched entry was high.
- **Verification.** `npm run test:tools` 2020 of 2020; `npm run test:components` 3183 of 3183; `npm run build` passes its checkers; browser specs on the rebuilt and redeployed bundle: `home-system-information` 4 of 4 (light and dark), `preferences-integration` 1 of 1, `about-help-links` 8 of 9. Mutations: eight in Batch b's Verification plus seven `(CR)` lines, each observed red and reverted with the tree byte-identical.
- **Residual risk.** `about-help-links`' "shipped bundle matches the stamp" leg reads red on a throwaway after any `docker cp` of a changed bundle, so the loop's Spec step cannot read fully green locally; CI's fresh throwaway is where it passes (inference). About's Retry focus restore is pinned in jsdom only. On a failed About read the shell's banner stands behind the modal beside the dialog's own alert, as the Design Notes decide.
