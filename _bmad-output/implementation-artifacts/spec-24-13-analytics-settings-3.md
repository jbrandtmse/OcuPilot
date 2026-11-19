---
title: 'Story 24.13: Analytics settings (Batch 3: the run-time variable and user-defined icon writes)'
type: 'feature'
created: '2026-11-19'
status: 'done'
baseline_revision: 'fe4f45059d4f8d5d7a8b0b73aa25603ea1f74bb1'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/spec-24-13-analytics-settings-2.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-24-12-quality-measures-3.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** Batches 1 and 2 (`spec-24-13-analytics-settings.md`, `-2.md`, both `done`, code head `a365495ce`) read all four tabs of the classic Analytics Settings page and write General and Worklists. Run-time variables and user-defined icons still cannot be added, changed or removed from OcuPilot (Batch 1 Design Notes › Questions 1, veto item U-115). Separately, Batch 2's script forms skip the namespace settings lock that the port takes (DW-2775).

**Approach:** Add six confirmed writes: `analytics.runtimevariables.add`, `.set` and `.remove`, and `analytics.usericons.add`, `.set` and `.remove`. Each has two callers (AD-53), records an audit row, has a script form (AD-59) and reads back (AD-58), in the shape of the term-list entry writes (Story 24.2) and on Batch 2's settings path (`InvokeSetting`, its lock, `AuditWrite`). They write only through the vendor setters that the classic page's `ApplySettingToServer` and `ApplyIconToServer` call (`irislib/%DeepSee/UI/Settings.cls` :911-961). Every settings script form, Batch 2's four included, takes that lock.

## Boundaries & Constraints

**Always:**

- **Vendor calls.** Writes go through `%DeepSee.UserPortal.Utils` `%SetUserSetting(name, value, comment, context)`, `%SetUserIcon(name, path)`, `%RemoveUserSetting(name)` and `%RemoveUserIcon(name)` only, each from its own seam that switches namespace by save and restore (AD-16). Reads use Batch 1's pure list reads (`%GetUserSettingsList`, `%GetUserIconList`).
- **Targets (AD-13).** Each target is single, by `Name`, kept exactly. A name differing only in case is a different name, as the vendor's subscripts and the classic duplicate test (:812, :849) treat it. Names are never changed: a rename is a remove and an add.
- **Fields.** A variable has `Value` (the expression), `Comment` and `Context`. An icon has `Path`. On `set`, a field left out keeps its value (AD-4 merge over the fresh read).
- **Shape.** A name is 1 to 255 characters with no control character and must be storable, probed as `TermListFits` probes (a process-private global of the vendor's shape). Other text is at most `SETTINGTEXTMAX` (2,000) characters with no control character. A violation is 400 `ANALYTICS.SETTING.NAME` or `ANALYTICS.SETTING.TEXT`.
- **The expression is code; it is checked, never run.** A non-empty `Value` must pass `%Library.Routine.CheckSyntax(" Set %out=" _ value)`. That is the exact line the vendor's `%GetUserSetting` executes (`Utils.cls` :552-575), and the check was measured to run nothing and write nothing (Design Notes › Measured). Otherwise the write is refused 400 `ANALYTICS.VARIABLE.EXPRESSION`. An empty `Value` is stored as the classic page stores it. This is a syntax check, not a safety check: what keeps the expression safe is who may write it, namely `SETTINGSPAIRS` (`%DeepSee_Portal:USE` plus `%Development:USE`) and WRITE on the database of `^DeepSee.User.Settings`. The add and set cards carry the consequence `ANALYTICS.VARIABLE.CODE`.
- **Paths are text.** No surface renders a path as an image or a link (AD-11 rule 4).
- **Gate and refusals, before any vendor call, from both callers and the mint (AD-8, AD-29, AD-54, AD-65).** The gate is `SETTINGSPAIRS`, then `AdmitNamespace`, then `AdmitDestination`, which checks the endpoint's own global (`^DeepSee.User.Settings` or `^DeepSee.User.Icons`) and answers 409 `ANALYTICS.SETTING.READONLY`. The refusals are:
  - `add` of a name already held: 409 `ANALYTICS.VARIABLE.TAKEN` or `ANALYTICS.ICON.TAKEN` (the absence is fingerprinted).
  - `set` or `remove` of a missing name: 404 `ANALYTICS.VARIABLE.ABSENT` or `ANALYTICS.ICON.ABSENT`.
- **One writer at a time.** All ten settings writes run their read, judge and write under Batch 2's `^CacheTemp.OcuPilotAnalyticsSettings(namespace)` lock. A lock held past `SETTINGLOCKSECONDS` is 409 `WRITE.TARGETBUSY`.
- **Keys, audit, script, read-back.**
  - Keys: the four `add` and `set` keys ship `true`. The two `remove` keys are `DESTRUCTIVE` and ship `false`; their screen confirm asks for the typed name with the `REMOVE` consequence.
  - Audit: each write from either caller records OcuPilot's own `ConfigChange` through `AuditWrite`, with names only: `{namespace, variable}` or `{namespace, icon}` (measured: there is no vendor event).
  - Script forms: each script, the ten writes', takes the lock in one line, gates on one line with the port's taken or absent rule, calls the setter, releases the lock, and sets the busy sentence when the lock is held (AD-59; DW-2775).
  - Read-back: `READBACKFIELDS` is `Value,Comment,Context` or `Path`. A remove's read-back expects absence.

**Never:**

- `%GetUserSetting`, `%ClearUserSettings`, `%ClearUserIcons`, `ApplySettingToServer` and `ApplyIconToServer`.
- Any `Xecute` or `$Xecute` of a stored expression, or a direct `Set` or `Kill` of either global outside the four seams.
- A rename.
- A spine edit. Edits to `ui/angular.json` or `ui/vitest-base.config.mjs`. Any edit to `scripts/ci-throwaway.sh` beyond add-only roster lines.

## I/O & Edge-Case Matrix

Rows run in USER on `ocupilot-b-ci`, with both callers for each row. Every test restores the three settings globals from `AnalyticsProbe`'s snapshot.

| Scenario | Input / State | Expected | Error |
|---|---|---|---|
| Add | Variable `OcuProbe2413Var`, `Value` `$Increment(^OcuProbe2413Ran)`, `Comment`, `Context`; icon `OcuProbe2413Icon`, `Path` | The row reads as sent; `^OcuProbe2413Ran` stays undefined; read-back `matches`; one `ConfigChange` added | - |
| Set | `Comment` only; then `Value` `1+1`; icon `Path` | The named fields change and the others are kept | - |
| Remove | Typed name; the key turned on by the test for the agent leg | Gone; read-back expects absence | - |
| Case | Add `ocuprobe2413var` beside `OcuProbe2413Var` | Both are held | - |
| Taken, absent | Add an existing name; set or remove a missing one | Nothing written | 409 `*.TAKEN`; 404 `*.ABSENT` |
| Shape | Empty name; a name of 256 characters; a control character; text of 2,001 characters | Nothing written | 400 `ANALYTICS.SETTING.NAME` or `.TEXT` |
| Expression | `1+`; then `""` | Refused; then stored empty | 400 `ANALYTICS.VARIABLE.EXPRESSION` |
| Scripts | Each of the ten script forms run in USER; then with the lock held by another process | Same change as the port; with the lock held, nothing written and `tSC` the busy sentence | - |
| Two writers | A write while the lock is held | Refused | 409 `WRITE.TARGETBUSY` |
| Stale | Changed between mint and confirm; a name taken after an add's mint | Proposal closes target-changed | 409 |
| Gate | No `%Development:USE`; analytics off; database read-only (Batch 2's seam) | Refused before any vendor call | 403 naming the pair; 409 `ANALYTICS.NAMESPACE`; 409 `ANALYTICS.SETTING.READONLY` |
| Key off | The agent's remove at its shipped `false` | Governance refuses | 403 |

</intent-contract>

## Code Map

Paths are under `/Users/jbrandt/git/OcuPilot/.worktrees/epic-24` (HEAD `3d620f2a3`).

**Contention.** `git log --no-merges origin/OCU-1-epic21 ^origin/feature/OCU-1_ocupilot-mvp` was empty at `251088f4b` on 2026-11-19, so nothing is contended now. The implement stage re-runs it and marks any hit "(contended: add-only)". The standing rulings bind regardless: `Prohibited.cls`, `scripts/ci-throwaway.sh` and `Baseline.cls` take add-only edits.

**Extend Batch 2's family and 24.12 Batch 3's part-write wiring file for file (Rule 2).**

- **`src/OcuPilot/Port/AnalyticsPort.cls`** (6,952 lines):
  - **Types:** new single reads `RUNTIMEVARIABLE` and `USERICON` beside :565. The writes reuse `ENTRYADD`, `ENTRYSET` and `ENTRYREMOVE`, as the listing and quality-measure parts do. Verbs and entities sit beside :577-587.
  - **Routing:** widen `Serves` :651, `IsSettingsEndpoint` :669 (to the four endpoints), `IsSettingsWrite` :675 and `ChangesSettings` :682. `Admit` :886 picks the endpoint's global.
  - **Read and write:** `JudgeSetting` :6708 and `SendSetting` :6742 gain the two endpoints, reading the row from Batch 1's `Collect` lists :1205-1207, and judge shape and expression before the setter.
  - **Seams and helpers:** new seams `VendorRuntimeVariableSet`, `VendorRuntimeVariableRemove`, `VendorUserIconSet` and `VendorUserIconRemove`, as `VendorWorklistOption` :6883 is built. New pure helpers: `ExpressionHolds`, and a name probe that generalizes `TermListFits` :2977.
  - **Scripts:** `SettingSnippet` :6902 renders the six new scripts and wraps all ten in the lock, as `InteropPort` :8144 does. `AuditWrite` :2729 is reused.
- **Tools (new, in `src/OcuPilot/Screen/Tool/`):** `AnalyticsRuntimeVariableAction` and `AnalyticsUserIconAction` extend `AnalyticsAction` as `AnalyticsWorklistAction` does (descriptor, `DESTINATIONGLOBAL`, `CLASSICPAGES` `%DeepSee.UI.Settings`, `READTYPE`, `READANSWERS`, `STATEMARKER`). `...{Add,Set,Remove}` follow the shapes of `AnalyticsTermListEntry{Add,Set,Remove}`: `CREATES`, `READBACKTOOL`, `ComposeCreate` and `CreatedId` for add; `SCREENVALUES` and `SCREENOPTIONAL` for set; `DESTRUCTIVE` and `REMOVALROWS` for remove. Use the kernel's default mint, since each target has a single id.
- **Descriptors:** `AnalyticsRuntimeVariableList.cls` and `AnalyticsUserIconList.cls` gain:
  - `primaryAction` `add`;
  - `rowActions` `set` and `remove`;
  - `table.emptyAgentKey` with the ruled phrases in place of `emptyNextKey`;
  - doc comments with the "offers no action" sentence replaced.
- **Saves (AD-55):** new `Area/Analytics/RuntimeVariableSave.cls` and `UserIconSave.cls`, as `TermListSave.cls` is built (no parent). They are routed by `POST /analytics/runtime-variables` and `POST /analytics/user-icons` in `Api/Router.cls` beside :285.
- **Kernel and API:**
  - `Api/AnalyticsError.cls` gets the codes beside :321-343 and the `SettingCodes` roster :421.
  - `Kernel/Governance/Baseline.cls` after :300 gets six keys.
  - `Kernel/Proposal/Prohibited.cls`:
    - `TYPE` parameters beside :813;
    - `COVEREDTYPES` :311;
    - `IsAnalyticsSettingType` :1267 body widened to the two types;
    - change lists beside :1379 and create lists beside :1548.
    - If the create path refuses the payload's `Namespace`, add one `|| ..IsAnalyticsSettingType(tType)` term to the entry-add branch at :1842, and record it.
- **Client (`ui/src/app/`):**
  - New `areas/analytics/analytics-setting-entry-list.page.ts` serves both descriptors over `<app-detail-page />`, modeled on `quality-measure-meta-list.page.ts`, with Add and Change opening the dialog.
  - New `analytics-setting-entry-dialog.ts`, with `kind` `variable` or `icon`, modeled on `term-list-entry-dialog.ts`. The fields reuse Name, Expression, Comment, Context and Path.
  - Maps: `shell/screen-outlet.ts` `DESCRIPTOR_PAGES`; `shell/screen-action-handler.ts` `SCREEN_ACTION_DESCRIPTORS` :70, `UNDRAWN_ACTIONS` :499 (`set`), `DESTRUCTIVE_CONSEQUENCES` :710 and `TYPED_NAME_ROWS` :841 (`Name`); `core/screen-actions.ts` `DESCRIPTOR_ACTION_LABELS` :170.
  - Strings and generated files: `core/strings.ts` (once ruled); `core/screens.generated.ts` and `Screen/Titles.cls`, regenerated.
- **Tests:**
  - New `Test/AnalyticsSettingsEntryWrite.cls` (both callers, read-backs, scripts, never-run) and `Test/AnalyticsSettingsEntryWriteEdge.cls` (refusals, lock, stale, gate as principals, read-only through `AnalyticsSettingsDatabaseSeam`, key off). Both are armed by `OCUPILOT_ALLOW_PRINCIPALS` and rostered in `scripts/ci-throwaway.sh` with `ui/tools/ci.test.mjs`.
  - `Test/AnalyticsSettingsWrite.cls`'s script test gains the held-lock leg for Batch 2's four (DW-2775).
  - Audit counts use `InteropQueueActions.Count` :196 and `Added` :203. The settings fixture is `AnalyticsProbe` :1270-1399.
  - `ui/tools/analytics.test.mjs`'s Story 24.13 guard (:574) admits the four setters only in their seams and still forbids `%GetUserSetting`.
  - Component specs for the page and the dialog; `ui/browser/analytics.browser-spec.mjs`.
- **Rosters (Rule 30):** re-grep `analytics.termlistentries.add`, `AnalyticsTermListEntryAdd` and `analytics.settings.set`. The hits are Batch 2's Code Map › Rosters list plus `navigation.test.mjs` and `structural-walk.mjs`.
- **EXPERIENCE.md:** one Fixed strings row after :618.

## Tasks & Acceptance

**Execution:**

- [x] **Task 0** (`ocupilot-b-ci`, USER, settings restored after): confirm a 255-character name stores through `%SetUserSetting` and `%SetUserIcon` and that the name probe agrees, then record the result under Design Notes › Measured.
- [x] `AnalyticsPort.cls`, `AnalyticsError.cls`: types, routing, gate, judging, seams, audit, the ten script forms.
- [x] The eight tools, two saves and routes, both descriptors, `Baseline.cls`, `Prohibited.cls`, the client, strings (once ruled), the regenerated mirror and titles, and the EXPERIENCE.md row.
- [x] Tests: the matrix in the two new classes, the Batch 2 script leg, component and browser tests, and every roster.
- [x] **Review fixes (tests only, smallest change that does each):**
  - **R1** (`AnalyticsSettingsEntryWrite`): count `ConfigChange` rows before and after (`InteropQueueActions` `Rows`/`Count`/`Added`) for every one of the six writes by both callers wherever the class already runs that leg, including the icon change by both callers, the agent's icon add and remove, and the person's variable remove.
  - **R2** (`AnalyticsSettingsDatabaseSeam`, `AnalyticsSettingsEntryWriteEdge`): let the seam mark one of the three settings globals read-only at a time; the gate test asserts a read-only `^DeepSee.User.Settings` refuses the variable writes (409 `ANALYTICS.SETTING.READONLY`) and not the icon writes, and the reverse for `^DeepSee.User.Icons`. Replace the false mutation sentence in the test's doc comment. Mutation: `SettingsGlobal` answering `SETTINGSGLOBAL` for both endpoints -> the new test red alone; record it under Verification.
  - **R3** (both `RunScript` helpers, in `AnalyticsSettingsEntryWrite` and `AnalyticsSettingsWrite`): on every held-lock leg assert the error text of `tSC` contains `OcuPilot.Api.Error`'s `REASONWRITETARGETBUSY`.
  - **R4** (`AnalyticsSettingsWrite`, `AnalyticsSettingsEntryWrite`/`Edge`): add a held-lock `Worklist 1` script leg (customization off first, lock held: refused, flag stays off); extend the HTTP `409 WRITE.TARGETBUSY` leg to the variable remove and the icon change.
  - **R5**: kill `^OcuProbe2413Ran` in USER and in the test namespace in `AnalyticsSettingsEntryWrite`'s `OnBeforeOneTest` and in the browser test's setup; release the test process's own `^CacheTemp.OcuPilotAnalyticsSettings("USER")` lock (and HSCUSTOM's if a leg takes it) in `OnAfterOneTest`.
  - **R6** (`analytics-setting-entry-list.page.spec.ts`, `ui/browser/analytics.browser-spec.mjs`): assert no `img`, `a` or `iframe` after a path is typed into the Add and the Change dialog (component) and, in the browser, in the dialog as well as the grid.
  - **R7** (`TestAnExpressionIsNeverRun`): scan the journal with `AnalyticsProbe.JournalMark` before and `JournalWrites` after every write, read and script that carries the probe expression, in the namespaces it can reach, and assert no entry names `^OcuProbe2413Ran`; state in the test comment whether the database is journaled. Then remove the `deferred:` entry for AC3 from the frontmatter. Mutation: `VariableExpressionHolds` sets then kills `^OcuProbe2413Ran` before the check -> only the journal assertion red; record it (replace the AC3 mutation line's claim if it changes).
  - After the fixes: record each new or changed pinning test's `mutation:` line (apply, observe red, revert byte-identical, sync and compile into `ocupilot-b-ci` first); run the touched classes one at a time and the two client tiers; rebuild and redeploy the bundle and re-run `browser/analytics.browser-spec.mjs`.

**Acceptance Criteria:**

- **AC1 (round trip, both callers).** Given each of the six writes through the screen action and the confirmed proposal, when the vendor's list read runs, then it holds what was sent and the other variables and icons are unchanged.
- **AC2 (Integration, Rule 1).** Given each write, when `GET /screens/<id>/read` and the agent's read tool run, then both answer the new state, and the read-back is `matches` for an add or set and absence for a remove.
- **AC3 (never run).** Given an expression that increments a probe global, written by both callers and by its script, when the writes and every read run, then the global stays undefined and a journal scan of the process finds no write of it.
- **AC4 (browser).** Given the probe, when a person adds, changes and removes a variable and an icon (typed name for the remove), then each tab shows the change and the path is shown as text.
- **AC5 (governed, audited, declared).** Given the six tools, when the roster tests run, then:
  - each declares `write`, `AnalyticsPort` and `%DeepSee.UI.Settings`;
  - the baseline holds four keys `true` and two `false`;
  - each write adds one `ConfigChange`, counted before and after;
  - removing any one roster row reddens that test alone.
- **AC6 (DW-2775).** Given the lock held by another process, when each of the ten settings script forms runs, then it writes nothing and leaves `tSC` the busy sentence. Unheld, it makes the same change as the port.
- **AC7 (leaves USER as found).** Given any new or changed test, in either order, first on a fresh instance, when it ends, then the three settings globals equal their snapshot.

## Spec Change Log

- 2026-11-19, spec gate (runner): the syntax-only expression check, variable and icon add and set shipping true with removes false and typed-name, the shared settings lock for all ten writes (DW-2775), the proposed strings and the proposed AD-65 line kept (veto item U-117).

## Review Triage Log

### 2026-11-19 — Review pass

- verdicts: 24 findings — high 0, medium 6, low 18, false 0, maybe-false 0
- findings:
  - `[medium]` `[patch]` AC5 audit count unpinned for the icon change (both callers) and several other write and caller pairs — pinned by before/after counts on every pair the tests already run (fix task R1).
  - `[medium]` `[patch]` the gate test cannot tell which global's database is checked, and its doc comment claims a mutation that cannot redden — the seam arms one global at a time (R2).
  - `[medium]` `[patch]` the held-lock script legs assert refused, not the busy sentence (AC6), in both `RunScript` helpers (R3).
  - `[medium]` `[patch]` the same unpinned busy sentence, reported by the intent audit as reading R5 — shared with the row above.
  - `[medium]` `[patch]` AC3 names a journal scan of the process that no test performs, and the `deferred:` entry dropped it — dropping or deferring scope is owner-only, so the scan is added with the probe's `JournalMark` and `JournalWrites` and the entry removed (R7).
  - `[medium]` `[patch]` the same audit-count gap, reported by the intent audit as reading R8 — shared with the first row.
  - `[low]` `[patch]` the held-lock leg never runs the `Worklist 1` script (R4).
  - `[low]` `[patch]` the probe global is not killed in USER by the test hooks and the browser test, though its absence there is asserted (R5).
  - `[low]` `[patch]` a script that throws leaves the lock held for later tests in `AnalyticsSettingsEntryWrite` (R5).
  - `[low]` `[patch]` the component spec's no-image, no-link check runs on an empty Add dialog (R6).
  - `[low]` `[patch]` the intent audit's AC4 divergence: path-as-text is checked on the grid only (R6).
  - `[low]` `[patch]` the HTTP busy refusal is tested for four of the six new writes (R4).
  - `[low]` `[reject]` the name rule runs on add only (reading R1) — a stored name the classic page allowed may exceed it, and a malformed name on set or remove reads 404; a guard there adds complexity for no reachable harm.
  - `[low]` `[reject]` a `Value` equal to the stored one is not re-checked (reading R2) — recorded in-stage; the check guards what is newly stored, and refusing a comment-only change would be the harm.
  - `[low]` `[reject]` the mint refuses with 400 `TOOL.ARGUMENTS` where the port answers the named codes (reading R3) — Batch 2's mint does the same for an absent setting (`AnalyticsSettingsWriteEdge` :112, :337).
  - `[low]` `[reject]` the General and custom-worklist scripts guard several lines (reading R4) — a script is pasted a line at a time, and each line is single.
  - `[low]` `[reject]` the gate order is tested through the port only — the mint and the screen action reach the gate through `Invoke`.
  - `[low]` `[reject]` the shipped 5-second lock line is never run held — the test seam renders the same line with a 0-second wait.
  - `[low]` `[reject]` unheld scripts are compared with expected values, not with a port run — the values are the port's own measured results.
  - `[low]` `[reject]` the tools' `write` declaration is pinned through the rosters, each shown load-bearing by a mutation (AC5).
  - `[low]` `[reject]` AC7's either-order, fresh-instance clause is not run by the tests themselves — the lead's fresh check runs it before the finalize commit.
  - `[low]` `[reject]` two consequence codes for the removals, `Was` in the change payload and a 200 where the save answers 201 — the removal consequences are among the proposed strings, and the others are recorded in-stage.
  - `[low]` `[reject]` the Fixed strings drift bound moved from 4200 to 4600 — the table's earlier moves followed the same protocol; the move is recorded here and in the commit message for the lead's ruling.
  - `[low]` `[reject]` the `IsDefault` precondition of the baseline test — the pattern of six sibling classes.

## Design Notes

**Questions for the runner (veto items).**

1. **The expression check (stricter than classic, which checks nothing).** Recommended: a syntax check only, on the exact line the vendor executes, stated as no safety control. Alternative A: no check, as classic does. Alternative B: wrap the expression in parentheses to refuse multi-command text. B was measured as bypassable: `1)  Kill ^X  Set %out=(1` passes it, so it would promise a safety it does not give.
2. **Variable `add` and `set` ship `true` although they write stored code (developer tool first).** Every write is a confirmed proposal that shows the expression as text, behind `%Development:USE`. The precedents are Explorer's agent save and the listing group's SQL. Alternative: ship them `false`.
3. **Proposed strings.**
   - Actions, which are also the dialog titles: "Add run-time variable" · "Change run-time variable" · "Remove run-time variable" · "Add icon" · "Change icon" · "Remove icon".
   - Refusals:
     - "This namespace already holds a run-time variable with that name."
     - "This namespace already holds a user-defined icon with that name."
     - "This run-time variable no longer exists."
     - "This user-defined icon no longer exists."
     - "A name is 1 to 255 characters with no control character, within the length the instance can store."
     - "An expression, comment, context or path is at most 2,000 characters with no control character."
     - "This expression is not valid ObjectScript. It was checked, not run, and nothing was saved."
   - Consequences:
     - "This expression is code. It runs with the rights of whoever opens a dashboard that uses it."
     - "Removing this run-time variable cannot be undone from OcuPilot. A dashboard that uses it then gets an empty value."
     - "Removing this icon cannot be undone from OcuPilot."
   - Reused: Name, Expression, Comment, Context, Path, the read-only refusal, the busy sentence, and Batch 1's two agent phrases.

**Proposed spine line (the owner's attended update; never written here).** AD-65, after Batch 2's: "Run-time variables and user-defined icons are written only through `%DeepSee.UserPortal.Utils` `%SetUserSetting`, `%SetUserIcon`, `%RemoveUserSetting` and `%RemoveUserIcon` under the namespace settings lock. A variable's expression is checked with `%Library.Routine.CheckSyntax` on the line the vendor executes, which was measured to run and write nothing, and is never evaluated (Story 24.13)."

**Measured (plan, 2026-11-19, `ocupilot-b-ci`, USER; both globals were undefined before and after).**

- **The four setters.** `%SetUserSetting` twice, `%SetUserIcon`, the two removes and a remove of a missing name all answered OK. The journal scan by `$Job` holds nine records, all `SET` or `KILL` of `^DeepSee.User.Settings` or `^DeepSee.User.Icons` in USER's globals database.
- **Never run.** `^OcuProbe2413Ran`, the stored expression's target, stayed undefined.
- **No vendor audit.** With auditing on, the process wrote no `%SYS.Audit` row.
- **Name limit.** A 600-character name answered `<SUBSCRIPT>` as an error status and stored nothing.
- **`CheckSyntax`.** It passed `$Increment(^OcuProbe2413Syn)`, `$H`, a `##class` call and `$$X^Y(1)`. It failed `1+`, and failed `1 Kill ^X` only in the parenthesized form. It ran nothing (the global stayed undefined) and made no journaled write.

**Measured (Task 0, implement, 2026-11-19, `ocupilot-b-ci`, USER, both globals undefined before and after).** Names of 255, 256, 300 and 400 characters stored through `%SetUserSetting` and `%SetUserIcon` and the name probe (a process-private global of the vendor's shape) agreed on each; one of 600 characters raised `<SUBSCRIPT>` in the probe and in both setters. The instance stores past 255, so the 255 limit is the editor's own, as the spec has it.

**Decided in-stage (implement).**

1. A shared abstract `Screen/Tool/AnalyticsSettingEntryAction` sits between `AnalyticsAction` and the two named bases, and an abstract `Area/Analytics/SettingEntrySave` above the two saves, instead of repeating the rules, merge and schema code in both (Rule 2).
2. The new helper is `VariableExpressionHolds`, because `ExpressionHolds` is the quality measures' already. An expression a variable already holds is not checked again on a change (`SettingEntryViolation`'s stored value), so a comment can change on a variable the classic page stored with any text.
3. A violation is 400 from the port, the person's save (`SettingEntrySave.RenderViolations`, the family's save answers 422) and the person's action; the agent's mint refuses with the kernel's 400 `TOOL.ARGUMENTS`, the sentence in `detail.problem`, as for every tool. A change of a name that is not held reads 404 from the port and is 400 `TOOL.ARGUMENTS` at the agent's mint.
4. The change tools add `Was`, the members the target held, to the merged payload, as Batch 2's `AnalyticsSettingSet` does, so a target changed to the value the proposal sets still closes the proposal as moved.
5. The scripts take the lock with `Lock +...:5 Set tLocked = $Test` and gate every write on `tLocked`, with single-line blocks only, because a script is pasted a line at a time. `Test/AnalyticsSettingsLockSeam` renders them with a lock line that waits 0 seconds and holds the lock from a second process.
6. `Prohibited.cls` took the one added condition term the spec allows: `|| ..IsAnalyticsSettingType(tType)` on the entry-add branch, which strips the payload's `Namespace`. Its body, `TYPE` parameters, `COVEREDTYPES`, change and create lists are the other add-only edits.
7. `Test/AnalyticsSettingsDatabaseSeam` answers read-only for the two new globals; `ui/tools/strings.test.mjs`'s drift bound for the Fixed strings literals moves from 4200 to 4600 (4205 with this row), for the lead's ruling.
8. The EXPERIENCE.md row is line 619, so `strings.ts`'s one reference past it (`taskCreate`, 660) is 661.

**Decided in-stage (plan).**

1. Call the `Utils` setters, not `ApplySettingToServer`, whose remove-then-set is the rename this batch does not offer.
2. One lock covers all ten settings writes, so DW-2775 has one fix for both batches.
3. A single page component and a single dialog serve both tabs, as `config-settings.page.ts` serves many descriptors.
4. An empty expression is stored unchecked, as classic does; the text limit of 2,000 reuses `SETTINGTEXTMAX`.
5. A read-only database reuses `ANALYTICS.SETTING.READONLY`: these globals are analytics settings too.
6. Batch 3 fits one pass. It is the size of 24.12 Batch 3 (six part writes, one pass) on a simpler, compile-free path, so no further batch is needed.

**Governing ADs (Rule 6):** AD-53, AD-54, AD-55, AD-56 (ii), AD-58, AD-59, AD-65, AD-4, AD-8, AD-10, AD-11, AD-13, AD-15, AD-16, AD-22, AD-29, AD-34, AD-60.

**Integration and linkage (Rules 1, 2).**

- **Consumes:** Batch 1's two endpoints and rows; Batch 2's `InvokeSetting`, lock, `AuditWrite`, `AnalyticsSettingsDatabaseSeam` and `RunScript`; `AnalyticsProbe`; and `InteropQueueActions` `Count` and `Added`.
- **Consumed-by:** no later story; the screens and the agent are the consumers. AC2 is the Integration AC.
- **Siblings extended:** `AnalyticsWorklistAction`, `AnalyticsTermListEntry{Add,Set,Remove}`, `TermListSave`, `TermListFits`, `SettingSnippet`, `quality-measure-meta-list.page.ts` and `term-list-entry-dialog.ts`.

**Ledger inbox (Rule 17).**

- **DW-2775:** addressed by AC6.
- **DW-2777, DW-2778 and DW-2779:** `decision-pending` for the owner's decision sheet; this plan does not decide them.

## Verification

**Commands** (one `ci-runner` call per message; `ocupilot-b-ci` only):

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.AnalyticsSettingsEntryWrite`, then likewise `AnalyticsSettingsEntryWriteEdge`, `AnalyticsSettingsWrite`, `AnalyticsSettingsWriteEdge`, `AnalyticsSettingsRead`, `PortGate`, every roster class and every class the shared-surface sweep changes. Expected: green, with the new classes green on their first run.
- `(loop)` `cd ui && npm run test:tools && npm run test:components`. Expected: green.
- `(loop)` `cd ui && npm run build`, then `docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`, then `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci node --test --test-concurrency=1 browser/analytics.browser-spec.mjs`. Expected: green.
- `(once)` The full ObjectScript sweep: `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --shard k/17`, for k = 1 to 17, one call each. Expected: green.
- `uv run scripts/check-objectscript.py` and `bash scripts/lint-docs.sh`. Expected: clean. The full browser suite is left to CI.

**Shared surfaces:**

- the two descriptors' actions and empty keys;
- the governance baseline;
- the write-tool rosters;
- `screen-mirror.test.mjs`;
- `DeveloperFloor`'s tools;
- the arming roster;
- Batch 2's script-form test;
- the `analytics.test.mjs` guard.

**Hermeticity:** every test added or changed passes on its first run on a fresh instance, in either order, and restores every analytics setting it changes.

**Mutations:** the implement stage records one per AC here, as `mutation: <change> -> <test red>`.

- mutation: AC1 `AnalyticsPort.SendSetting` sets a variable's comment from the stored row in place of the body -> `AnalyticsSettingsEntryWrite.TestAVariableIsAddedChangedAndRemovedByBothCallers` and `TestAnExpressionIsNeverRun` red (run 59).
- mutation: AC2 `AnalyticsRuntimeVariableAdd.READBACKTOOL` names the add tool itself, whose read is composed for an add -> `TestAVariableIsAddedChangedAndRemovedByBothCallers` red alone, on both read-back legs (run 63).
- mutation: AC3 `AnalyticsPort.VariableExpressionHolds` runs the line with `XECUTE` -> `TestAnExpressionIsNeverRun` red alone, the two `^OcuProbe2413Ran` legs (run 60); `ui/tools/analytics.test.mjs`'s guard also goes red on the `XECUTE`.
- mutation: AC4 `analytics-setting-entry.store.ts` posts the variable add to the icons' route (bundle rebuilt and redeployed) -> the Batch 3 browser test red, the first row never appearing; reverted byte-identical, rebuilt, redeployed and green again.
- mutation: AC5 `analytics.runtimevariables.add` `false` in `Baseline` -> `AnalyticsSettingsEntryWriteEdge.TestTheBaselineShipsFourKeysOnAndTwoOff` red alone (run 64); the `analytics.usericons.set` row removed from `SurfaceCoverage` -> `TestEveryWriteToolHasACoverageRowAndBack` red alone (run 65).
- mutation: AC6 `SettingSnippet`'s lock line sets `tLocked = 1` in place of `$Test` -> `AnalyticsSettingsEntryWrite.TestEachWritesScriptFormMakesTheSameChange` red alone (run 61) and `AnalyticsSettingsWrite.TestEachWritesScriptFormMakesTheSameChange` red alone (run 62), the held-lock legs of the six and of Batch 2's four.
- mutation: AC7 `AnalyticsProbe.RestoreSettings` no longer kills the icons and `AnalyticsSettingsEntryWrite.OnAfterOneTest` no longer clears the settings -> the class's `OnAfterAllTests` red, "left probe state in USER: marker ^DeepSee.User.Icons(...)" (run 66).
- Each reverted byte-identical (`cmp` against the saved copy), synced and reloaded with the port's subclasses recompiled; the sixteen tests of `analytics.browser-spec.mjs` green on the rebuilt, redeployed bundle.
- mutation: AC3 journal scan `AnalyticsPort.VariableExpressionHolds` sets and then kills `^OcuProbe2413Ran` before the check -> `AnalyticsSettingsEntryWrite.TestAnExpressionIsNeverRun` red alone, its journal leg only (the global-undefined legs stay green); the scan covers every process, since the person's and the agent's writes are served by other processes.
- mutation: AC5 audit counts `AnalyticsPort.SendSetting` skips `AuditWrite` for the icon change -> `TestAnIconIsAddedChangedAndRemovedByBothCallers` red alone, on the person's and the agent's change legs.
- mutation: gate `AnalyticsPort.SettingsGlobal` answers `SETTINGSGLOBAL` for every endpoint -> `AnalyticsSettingsEntryWriteEdge.TestTheGateRefusesBeforeAnyVendorCall` red alone, the six one-global-at-a-time legs only.
- mutation: AC6 busy sentence `SettingSnippet`'s busy status carries another sentence -> `AnalyticsSettingsEntryWrite.TestEachWritesScriptFormMakesTheSameChange` red on its six held-lock legs and `AnalyticsSettingsWrite.TestEachWritesScriptFormMakesTheSameChange` on its six; the customize script takes no lock for `Worklist` 1 -> that held leg red alone.
- mutation: HTTP busy `InvokeSetting` takes no lock for the variable removal and the icon change -> `AnalyticsSettingsEntryWriteEdge.TestASecondWriterIsRefusedWhileTheLockIsHeld` red on those two legs and the nothing-written leg.
- mutation: AC3 hygiene `AnalyticsSettingsEntryWrite.KillRan` kills nothing, with `^OcuProbe2413Ran` planted in `HSCUSTOM` -> `TestAnExpressionIsNeverRun` and `TestEachWritesScriptFormMakesTheSameChange` red. The `USER` kill is also done by `AnalyticsProbe.ClearSettings`, so a stale node there is cleared either way; with the hooks as written a planted node in either namespace leaves the class green.
- mutation: AC4 path as text `analytics-setting-entry-dialog.ts` draws a link for the typed path (bundle rebuilt and redeployed) -> the component specs for the Add and the Change icon dialog red, and the browser test red on the Add icon dialog's no-media check; reverted, rebuilt, redeployed, sixteen tests green. The browser setup's `HSCUSTOM` kill dropped, with the node planted there -> the same browser test red at its setup assertion.

## Auto Run Result

Status: done
Blocking condition: none

- **Plan pass:** used the epic-story path on the committed `epic-24-context.md` (valid, not recompiled), planned the spec, checked it against READY-FOR-DEVELOPMENT, and halted after planning as directed. The four setters and `CheckSyntax` were measured on `ocupilot-b-ci` (Design Notes › Measured), and USER was left as found. Contention is clear at `251088f4b`. The veto items are Design Notes › Questions 1 to 3 and the proposed AD-65 line. Batch 3 fits one pass.
- **Implement pass (2026-11-19):** the six writes over `AnalyticsPort` with their eight tool classes, two saves and routes, both descriptors, the baseline keys, the prohibited set, the page, dialog and store, the strings and the EXPERIENCE.md row, DW-2775's lock on all ten script forms, and the two new test classes. Choices are in Design Notes; one mutation per AC is in Verification. Verified on `ocupilot-b-ci`: `AnalyticsSettingsEntryWrite` (6) and `AnalyticsSettingsEntryWriteEdge` (5) green, `AnalyticsSettingsWrite`, `AnalyticsSettingsWriteEdge`, `AnalyticsSettingsRead`, `PortGate` and every roster class named above green; `test:tools` 2336, `test:components` 3645, `analytics.browser-spec.mjs` 16 green; `check-objectscript` 0 problems, `lint-docs` clean, build 2.16 MB initial. Not run: the `(once)` sweep and the full browser suite, which the caller runs. Contention: none.
- **Review-fix pass (tests only; R1 to R7):** per-write `ConfigChange` counts on every pair the two classes run, both script helpers assert the busy sentence, a held-lock `Worklist` 1 leg, the HTTP busy leg for the variable removal and the icon change, the gate seam arms one settings global at a time (`sglobal`), `KillRan` in the hooks and the no-media checks in the component and browser specs, and a journal scan over every process (`AnalyticsProbe.JournalWrites` gained an optional all-processes flag), whose control writes show the `USER` and `HSCUSTOM` databases are journaled here. The AC3 `deferred:` entry is removed. Verified on `ocupilot-b-ci`: the three touched classes, `AnalyticsSettingsWriteEdge` and `AnalyticsSettingsRead` green; `test:components` 3645, `test:tools` 2336, `analytics.browser-spec.mjs` 16 green on the rebuilt bundle; `check-objectscript` 0 problems; mutations in Verification.
- **Finalize (2026-11-19):** review pass 24 findings (high 0, medium 6, low 18): 12 patched in the review-fix pass, 12 rejected with reasons in the Review Triage Log, none deferred. Follow-up review not recommended: no high and fewer than two medium entries beyond one grouped test-pinning root cause. Fresh check on a rebuilt `ocupilot-b-ci`: the new and changed ObjectScript classes (16) passed on their first run, forward then reverse. The `(once)` sweep, 17 shards of `ci-runner`, passed (6,228 tests, 0 failed) after the last patch. `test:tools` 2336, `test:components` 3645, `analytics.browser-spec.mjs` 16 on the rebuilt, redeployed bundle, `check-objectscript` 0 problems, `lint-docs` clean. Residual: the `strings.test.mjs` drift bound moved from 4200 to 4600 (4205 literals), for the lead's ruling; the mint refuses a bad shape or a missing target with the kernel's 400 `TOOL.ARGUMENTS` (Batch 2's does the same); the proposed AD-65 line is not written into the spine (U-117).
