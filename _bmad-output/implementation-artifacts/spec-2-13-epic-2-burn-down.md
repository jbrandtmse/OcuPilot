---
title: 'Story 2.13: Epic 2 burn-down'
type: 'bugfix'
created: '2026-09-15'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-2-12-the-application-error-log-endpoint-and-drill-down.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** Eleven Epic 2 findings mislead a user, hide a refusal, or let a misdeclaration ship: a
list's rows cannot be clicked, a privilege refusal arrives as a 500, a misspelled descriptor key
installs a screen whose strip never raises, a truncated list presents as complete, a stopped
scheduler is silent, no list offers Refresh, focus falls to the document, an over-long criterion
faults instead of being refused, destructive test classes are held off a live instance by a doc
comment, an area's gating is about to be inherited by accident, and ~149 EXPERIENCE.md citations
point at wrong-but-plausible lines.

**Approach:** Eleven bounded fixes, each with one pinning test whose red has been observed, ordered
so the shared surfaces with the widest blast radius land first. No new feature, no new screen, no
new endpoint.

## Boundaries & Constraints

**Always:**
- Every grammar rule is held identically by `Screen/Registry.cls` and `ui/tools/screen-mirror.mjs`,
  and pinned by one shared `Test/*Corpus.cls` `Cases` XData that both engines read off disk.
- Every new or changed sentence adds its EXPERIENCE.md **Fixed strings row** and its `strings.ts`
  key **in the same pass** — `strings.test.mjs` derives closed-world key equality from that table,
  so a row without a key, or a key without a row, fails the build. Values stay unique; non-ASCII is
  `\uXXXX`.
- Refresh is silent: no skeleton, no announcement, and sort, filter, selection and scroll survive it
  (EXPERIENCE.md, "Refresh never resets sort, filter, selection or scroll" / "Refresh is silent").
- Anything that creates a principal, rotates a log, seeds an error, or deletes one runs on the
  throwaway (`scripts/ci-throwaway.sh`, container `ocupilot-ci`) behind its arming variable. Never on
  live `ocupilot`; never `docker compose up`/`down` against it.
- ObjectScript lives under `src/OcuPilot/` and passes `uv run scripts/check-objectscript.py`. Only
  `Port/AdminPort.cls` names an `%Api.Admin.*` class (AD-27).
- One `iris_execute_tests` call per message, and the next only once the previous run has landed in
  `%UnitTest_Result`.

**Never:**
- No change widens what the read tool returns, and no error-log captured detail enters screen
  context or the model (AD-48).
- No descriptor loses a declared pair to make a screen easier to reach; no gate is relaxed to
  per-screen coverage (declined — see Design Notes, DW-275).
- No EXPERIENCE.md citation is repaired by hand-bumping a line number; repair is mechanical.
- No new dead branch: a destination, case, or engine arm with no reachable input is not written.
- No `rowActions` or `primaryAction` is added to any Epic 2 screen; `AdminPort.TYPESUFFIXES` stays
  `"GET,LIST,INFO"`.

## I/O & Edge-Case Matrix

| # | Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|---|
| 1 | **DW-273** list rows are clickable | Any list route in the shell, viewport 1440x900 | The table frame has a definite height; `cdk-virtual-scroll-viewport.clientHeight > 0`; `document.elementFromPoint` at a row's centre is inside that row | Viewport height 0, or the hit landing on `.ocu-data-table-footer`, fails the browser check |
| 2 | **DW-274** a refused backing query | An admin read whose backing query refuses on its own privilege check, reaching `AdminPort` (a screen that under-declares) | `403` + `PORT.ACCESSDENIED` + `detail.failedPair` naming the pair the query requires | A caller who **holds** the declared query pairs keeps today's `500`/`INTERNAL`; an endpoint with no declared query pairs also keeps it |
| 3 | **DW-271** top-level key set is closed | A descriptor declaring `banners` or `Banner` | Both engines refuse by name: `the declaration declares the unknown key 'banners'`; the screen does not install and the mirror does not emit | A declaration missing an **optional** key is still sound — the check is unknown-key only, never presence |
| 4 | **DW-279** an over-long criterion | `pids` = 83 characters on `logs/audit` | `400` + `READ.CRITERION` naming `pids` and its limit, refused in `SeedCriteria` **before** `AdminPort.Invoke` | A value within `maxLength` seeds and reads as today; a criterion declaring no `maxLength` is refused by the grammar at install |
| 5 | **DW-272** a citation that no longer resolves | A Fixed strings row inserted above an `EXPERIENCE.md` citation in source | The citation is anchored to a quoted phrase, not a line number, so insertion cannot move it; the gate fails any citation whose phrase is absent from EXPERIENCE.md | A bare `EXPERIENCE.md:<n>` outside `strings.ts`'s gated `/** */` form fails the gate by file and line |
| 6 | **DW-270** the Task Manager is stopped | `Task.Manager` GET answers `Status` `"Not running"` | The task schedule raises its own stopped sentence (its own Fixed strings row and key), not the suspended one | `"Suspended"` raises the suspended sentence unchanged; `"Running"` raises none; any banner fault still answers `""` so rows still list |
| 7 | **DW-293** a level cut at its cap | Any error-log level whose payload carries `truncated: true` | That level renders a cap notice saying the list is cut; the detail level's own `truncated` renders one notice too | `truncated: false` renders no notice; a faulted or denied level is never "empty" and never "complete" |
| 8 | **DW-260** manual Refresh | Any list: the five list screens, the audit viewer, the error-log drill | A Refresh action re-reads the current view in place — the audit viewer re-runs the same search, the drill re-reads the current level — silently, preserving sort, filter, selection and scroll | Home declares no read and offers no Refresh; the audit viewer offers none before the first Search; a refused read is reported, never retried |
| 9 | **DW-248** focus after the frame arrives | Sign-in completes, or a recovering instance answers, replacing the focused instance notice | Focus moves to `main#ocu-content` (the route-arrival destination; no screen heading exists yet — see Design Notes) | Focus is **not** moved if it already sits outside the removed notice; the skip link consequence is restated in the two DW-247 pins |
| 10 | **DW-289** destructive test classes | `node ui/tools/ci-runner.mjs --container ocupilot` discovers a class that creates principals or rotates a log | `OnBeforeAllTests` fails before any `Test*` method is enumerated, naming the arming variable and `scripts/ci-throwaway.sh` | A structural check fails the build for any `Test/` class that mutates principals or rotates a log without the guard |
| 11 | **DW-275** os-management gating | An operator holding only `%Admin_Operate:USE` opens the rail once a narrower os-management screen exists | The area declares the union, the false denial is deliberate and recorded, and a narrower screen still passes `AreaCoverageProblem` | Dropping `%Admin_Manage:USE` from the area makes `ProcessList` fail coverage — the pin that stops the decision being reversed by accident |

</intent-contract>

## Code Map

**DW-273 — the height chain.** Measured live on `ocupilot` (52774), `web-applications/list`, 1440x900,
2026-09-15: `main.ocu-content` `display:block` **clientHeight 737** (the last definite height) ->
`app-screen-outlet` **`display:inline`, `height:auto`, clientHeight 0** -> `div.ocu-screen-outlet` 94
-> `app-list-page` 94 (its `height:100%` resolved against `auto`) -> ... -> `cdk-virtual-scroll-viewport`
**clientHeight 0, scrollHeight 1620**; `.ocu-data-table-footer` rect top 177 h 40; row 2 rect top 176
h 36, centre (865,194), `document.elementFromPoint` -> `div.ocu-data-table-footer`, `insideRow false`.
- `ui/src/styles/_components.scss` -- the whole cascade. `.ocu-content` `:633-637`; `app-list-page`/
  `app-data-table` `:2002-2015`; frame `:2037-2048`; grid `:2050-2055`; head `:2065-2069`; viewport
  `:2071-2075`; footer `:2358-2368`. **No rule anywhere for `app-screen-outlet` or `.ocu-screen-outlet`**
  (verified in the served bundle `styles-SJ2LBCP4.css` as well as in source). Every flex item in the
  chain already carries `min-height: 0` -- the nested-flex cause is **not** this defect.
- `ui/src/app/shell/screen-outlet.ts:107-114` -- the unstyled `div.ocu-screen-outlet`; `:46-51`
  `ARCHETYPE_PAGES`. `app-audit-page`, `app-error-log-page`, `app-home-page` have no rule either, so
  a fix at the outlet covers all four archetypes.
- `ui/browser/list-spec.mjs:40-47` `viewCount()` off `aria-rowcount`, `:74-107` `filterToSubset`.
  The synthetic-click workarounds to replace: `tasks.browser-spec.mjs:305-317`,
  `processes.browser-spec.mjs:385-389`, `users.browser-spec.mjs:224-228`,
  `web-applications.browser-spec.mjs:228-232`, `audit.browser-spec.mjs:494-498`,
  `error-log.browser-spec.mjs:186,197`. `page.click()` is a hit-tested pointer click and is already
  used against rows in the harness (`data-table.browser-spec.mjs:515`).

**DW-274 — the port's fault mapping.**
- `src/OcuPilot/Port/AdminPort.cls` -- `Invoke:268`; `RunSequence:521-564`; **`:560-562` is the 500
  site** (an error `tSC` with no or a 2xx HTTP status); `Sequence:568-630`; `ResourcesOR` gate
  `:574-581`; `HoldsResource:423-426`; `<PROTECT>`->403 `:619-623`; `Refuse:686-691` (**takes no
  detail today**).
- `src/OcuPilot/Kernel/Fault.cls` -- `Outcome:120` maps HTTP 403 -> `PORTACCESSDENIED`; `Normalize:47`
  matches **domain and message id, never rendered text** (`:34-37`), which closes matching the
  `<INVALID OREF>...ClassQuery.1` text.
- `src/OcuPilot/Port/LogSourcePort.cls:1229-1235` + `DeniedRefusal:639-647` -- the `Refuse(..., pDetail)`
  shape to copy. `src/OcuPilot/Api/Error.cls:160` `PORT.ACCESSDENIED`; `Render:301,322-324` writes
  `detail`; `Api/ScreenRead.cls:56-62` is the `detail.failedPair` convention.
- Vendor: `%Api.Admin.Util.ClassQuery.RunQuery` assigns `stmt.%Execute()` to a **method-local** and
  never checks it; `%SQLCODE`/`%Message` are never read and are unreachable from the port. Refusal
  reaches the port only as an error `%Status` carrying `<INVALID OREF>AppendStatementResult+5^...`.
  49 of 67 endpoint classes use `ClassQuery`; `Task.Manager` and `Security.Audit.Record` do not.
- `irislib/%SYS/ProcessQuery.cls:992-994` -- `CONTROLPANELExecute` returns
  `$$$ERROR($$$OperationRequires, "%Admin_Manage:USE")` unless `%Admin_Manage:USE` **or** IRISSYS
  write is held. The OR is why the declaration is any-of, not all-of.
- `src/OcuPilot/Test/WireSecurityRead.cls:337-347` -- the recorded real-principal observation
  ("without `%Admin_Manage:USE` the read answers **500**") and its mutation paragraph, which this
  story updates.

**DW-271 / DW-279 — the grammar, two engines.**
- `src/OcuPilot/Screen/Registry.cls` -- `Validate:133`; `DeclarationJson` read `:143-147`;
  **insertion point `:148`**, before the first accessor. `UnknownKeyProblem:1020` and its thirteen
  call sites (`:378,386,471,479,511,532,655,702,774,810,833,897,912`) -- none on the declaration
  object. Criteria: `CriteriaProblem:638`, `CriteriaFieldsProblem:682` (allowed keys `:700-702`),
  **`CriteriaOptionsProblem:741`** (the precedent), `CRITERIONKINDS:593`.
- `ui/tools/screen-mirror.mjs` -- `buildMirror:870`, per-screen loop **`:885`** (insertion point
  `:886`); `unknownKeyProblem:354`; `criteriaFieldsProblem:613` (allowed `:623`, call site `:643`);
  `ReadCriterion` interface `:1097-1102`; `ScreenDeclaration` `:1180-1226`; emit `:966-968` is an
  unconstrained spread, which is why a typo mirrors verbatim.
- Top-level vocabulary (derived from every `Base.cls` accessor, every `Registry.cls` `%Get`, and the
  union of all 34 in-tree declarations): `route, area, labelKey, sideBarPosition, archetype, built,
  refreshes, refreshRates, privileges, entityType, secondaryEntityTypes, scope, parentScope, id,
  context, primaryAction, rowActions, emptyStateKey, commandAliases, classicPage,
  classicLinkExemption, read, table, banner, toolIdentifier` = **25**. Optional: `refreshes`,
  `refreshRates`, `read`, `table`, `banner`. `Test/Bad/Unknown.cls:17` and `Test/Pair/Bad.cls:15`
  build 20-key declarations in ObjectScript -- an unknown-key check passes them, a presence check
  would not.
- Corpora: `src/OcuPilot/Test/{Banner,Criteria,AdminPair,RowGet}Corpus.cls` -- `XData Cases` =
  `{declaration, cases[{name, <one sub-object>, expected}]}`; `Corpus()`/`DeclarationFor()` on the
  ObjectScript side, `ui/tools/screen-mirror.test.mjs:34 testCorpus` off disk on the client side;
  run by `src/OcuPilot/Test/ReadTool.cls:120,143,175,354`.
- `src/OcuPilot/Screen/Read.cls` -- `SeedCriteria:217`, choice refusal `:235-237`, datetime `:240-242`,
  nothing seeded until every value reads `:248-250`, refusal -> 400 at `:126-129`, `Refuse:586`.
  **Insertion point for a length refusal: `:233`**, before `Set tKind = ...`, since length binds every
  kind. Both callers cross it: `Api/ScreenRead.cls:44` and `Screen/Tool/Read.cls:129`.
- `src/OcuPilot/Screen/Descriptor/AuditList.cls:131-146` -- the only shipped criteria block, nine
  params. Vendor limits, read live from `%Dictionary.CompiledProperty` on
  `%Api.Admin.Endpoints.Security.Audit.RecordListTask`: `BeginDateTime` **50**, `EndDateTime` **50**,
  `Pids` **50**, `Authentication` **50**; `EventSources`, `EventTypes`, `Events`, `Usernames`,
  `Namespaces` **1000**.
- `src/OcuPilot/Screen/Tool/Read.cls:79 AddCriteria` (`enum` at `:96`) -- where `maxLength` joins the
  tool schema; `ValidateArguments:129`.

**DW-270 — the banner.**
- `src/OcuPilot/Screen/Read.cls:271-289 BannerKey`; the whole rule is the single equality at **`:283`**.
  Any banner fault answers `""` (`:263-270`).
- `src/OcuPilot/Screen/Descriptor/TaskScheduleList.cls:93-99` -- `field "Status"`, `equals "Suspended"`,
  `messageKey "taskManagerSuspendedBanner"`, `severity "warning"`.
- Vendor (read live): `%Api.Admin.Endpoints.Task.Manager.RunGet` answers one field `Status` from
  `%SYS.Task.TASKMGRStatus()`, a closed set of three -- `0 "Not running"`, `1 "Running"`,
  `2 "Suspended"`. **Stopped is `"Not running"`**; the classic portal offers `Start` at 0 and
  `Resume` at 2.
- The grammar is singular in six places: `TaskScheduleList.cls:93-99`; `Registry.cls:378` (five
  allowed banner keys); `Read.cls:283`; `screen-mirror.mjs:522` (`bannerProblem:518-551`);
  `ui/src/app/core/screens.generated.ts:194-200` (`BannerDeclaration`); `ui/src/app/shell/list-page.ts:104`
  (one `messageKey`). `src/OcuPilot/Test/BannerCorpus.cls:43-64` holds 22 cases on the single-pair
  shape; `Test/ReadBanner/{Matching,Faulting}.cls` are the read fixtures.

**DW-293 — truncation in the drill.**
- `ui/src/app/areas/logs/error-log.store.ts` -- `absorb:305-348`; `rowsOf:61-65` returns `body.rows`
  only, so `truncated` is dropped at `:306-309` (namespaces), `:311` (dates), `:318` (list); kept but
  unrendered at `:343-347` (detail, `ErrorLogDetail.truncated:55`). The store sends no `maxRows`
  (`:224,243,253,265-269`).
- `ui/src/app/areas/logs/error-log.page.ts` -- the token `truncated` does not occur; `grid:285-342`,
  `detail:345-382`, empty state `:79-84` / `showEmpty:267-271`. There is **no footer element at all**.
- Server: `src/OcuPilot/Port/LogSourcePort.cls` sets `truncated` at `:674, :699, :717, :975`, computed
  in `NamespaceRows:744`, `DateRows:801`, `ErrorRows:868`, `DetailPayload:960`; contract documented
  `:537-541`; `DEFAULTMAXROWS = 1000` `:172`; handler `src/OcuPilot/Api/ErrorLog.cls:55-56`. Detail's
  flag is one boolean over three tables (`:975`), so it cannot name which section was cut.
- Precedent to match: `ui/src/app/shell/data-table.ts:321-323` (notice), `:618-621` (`showCapNotice`),
  `:623-625`; `ui/src/app/core/table-model.ts:104-106 formatCapNotice`; `ui/src/app/core/strings.ts:295`
  `tableRowCapNotice`. **That sentence names a max-rows control the drill does not have**, so the
  drill needs its own sentence rather than a reuse.

**DW-260 — Refresh.**
- `ui/src/app/shell/command-bar.ts` -- inline template `:126-231`; no inputs/outputs, mounted once at
  `ui/src/app/app.ts:129`; `hasRefreshChip:431-433`; spacer `:220`; chip `:221-230`; every control-flow
  condition must be a paren-free member reference (`:120-122`, enforced by `ui/tools/client-lint.mjs`).
  The control's shape already exists at `ui/src/app/shell/data-table.ts:151` + `onRetry:765-767`.
- `ui/src/app/core/refresh.ts` -- `readNow:404-431` takes no arguments and gates on `bound.read !== null`,
  **not** on `refreshes`, so a non-refreshing list can already call it; `bind:227-272`; `suspend:571-578`.
  There is **no public "a read is bound" accessor** -- `descriptor()` is non-empty even after
  `bind(screen, null)`.
- `ui/src/app/core/screen-actions.ts:27` -- the registry the primary action already resolves through
  (`command-bar.ts:363-368`); the routing that lets four pages answer Refresh differently.
- Pages: `ui/src/app/shell/list-page.ts:55` (binds and reads at `:83-84`);
  `ui/src/app/areas/logs/audit.page.ts:136` (binds with `null` at `:175`, reads at `:182,:280`;
  `audit.store.ts:167 readFor` carries the criteria, so Refresh re-runs the same search);
  `ui/src/app/areas/logs/error-log.page.ts:195` (never injects `RefreshService`; re-read is
  `error-log.store.ts` `openNamespaces:217` / `openDates:236` / `openList:247` / `openDetail:261`
  on `drill.level()`); `ui/src/app/areas/home/home.page.ts:162` (no read).
- **`ui/src/app/shell/command-bar.spec.ts:817` asserts every command-bar action is reachable from the
  command box** -- a Refresh button in the bar alone fails there.
- EXPERIENCE.md: the requirement is the Refresh row of Interaction Primitives ("Refresh action on
  every list"), the command-bar row already lists Refresh, and "Refresh is silent -- no spinner, no
  skeleton, no announcement". The Fixed strings table is rows 254-331 (78 rows, 198 literals);
  **append `· "Refresh"` to the existing action-names row rather than inserting a new row**, so no
  line shifts.

**DW-248 — focus.**
- `ui/src/app/shell/instance-notice.ts:61` (`<section #surface role="alert" tabindex="-1">`), `:129`
  (`afterNextRender(() => this.surface().nativeElement.focus())` on every non-ready render).
- `ui/src/app/app.ts` -- `CONTENT_ID:32`; the swap `:111-142` (frame at `:122`, notice at `:137`,
  outer unreadable branch at `:118`); `main#ocu-content` `:130`; `focusContent:235-237` (already the
  skip-link and Escape destination); `frameShown:211-213`; `sessionState:172`, `instanceStatus:174`.
- **No route-arrival focus mechanism exists, and no screen heading exists**: the only `h1`/`h2` are
  the clipped product heading (`app.ts:116`), `screen-denied.ts:28`, `error-log.page.ts:146`,
  `instance-notice.ts`, `dialog.ts`. The screen title is a `<span>` in
  `ui/src/app/shell/locator-bar.ts:117-121`. The deferred-focus convention is `tabindex="-1"` plus
  `afterNextRender(..., { injector })` (`data-table.ts:821`).
- Recovery differs from sign-in only in what settles `instanceStatus` -- the connectivity park at
  `ui/src/app/core/instance.ts:281-283` or the unreadable Retry at `instance-notice.ts:155-157`; both
  reach the same `app.ts` swap. `ui/browser/unreadable.browser-spec.mjs` already has the machinery
  (`noticeShown:188`, `repair:232`, activeElement assertion `:200-203`).
- **Two existing pins will go red and must be restated:** `ui/browser/shell.browser-spec.mjs:210`
  and `:261` (the DW-247 case) both press Tab straight after sign-in and assert the skip link holds
  focus -- which only holds while focus is on `document.body`.

**DW-289 — throwaway guards.**
- The template, verbatim, `src/OcuPilot/Test/LogSourceDenial.cls:73-77` with
  `Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";` at `:29`:
  `If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 { Quit $$$ERROR($$$GeneralError, "...") }`.
  `irislib/%UnitTest/Manager.cls:1193-1204` throws on that status **before** `getTestMethods`, so no
  `Test*` method is enumerated.
- `scripts/ci-throwaway.sh:133,137,141` set `OCUPILOT_ALLOW_LOG_ROTATION`, `OCUPILOT_ALLOW_PRINCIPALS`,
  `OCUPILOT_ALLOW_ERROR_SEED` as container env on the throwaway only; `:45-52` refuses ports
  52774/1973 and the project name `ocupilot`.
- **The ledger's "last unguarded class" line is wrong.** Guarded today: `LogSourceDenial.cls:75`,
  `ErrorLogDenial.cls:129`, `LogSourceRotation.cls:56`, `ErrorLogSeed.cls:43,:65`. **Unguarded and
  principal-creating:** `Test/WireSecurityRead.cls:145-162,:223-240` (9 users + 9 roles; the doc
  comment at `:29` is the only barrier, and `EnsurePrincipal:235-238` **deletes a pre-existing account
  of the same name**), `Test/Wire.cls:98-100,:176-185`, `Test/Token.cls:153-162`,
  `Test/State.cls:84-95`, `Test/Version.cls:26-50,:96,:671-672`, `Test/UnexpireScope.cls:180`.
  Denominator: 161 `.cls` under `Test/`, 60 extending `%UnitTest.TestCase`, 59 discoverable.
- `ui/tools/ci-runner.mjs:60` `DEFAULT_PACKAGE = 'OcuPilot.Test'`, `:355-357` lists via
  `scripts/ci-unit-test.sh:80`, whose query returns every compiled `%UnitTest.TestCase` subclass under
  the package with a `Test*` method; `--container` is only a Docker name -- there is no live-container
  refusal. `scripts/smoke.sh:157` cannot reach these classes.
- `scripts/check-objectscript.py` (14 rules; harness `scripts/test_check_objectscript.py`) is where a
  structural guard-presence rule belongs.

**DW-275 — area coverage.**
- `src/OcuPilot/Screen/Registry.cls:318-338 AreaCoverageProblem`, called from `Validate:209`; refusal
  sentence at `:331`; the loop `:323-333` walks the **screen's** pairs only, so a surplus area pair
  stands (doc `:306-307`). **There is no mirror** -- `screen-mirror.mjs:875-882` checks only
  `malformedPair`, so the rule is server-only.
- `src/OcuPilot/Screen/Area.cls:64` -- os-management declares `%Admin_Operate:USE`, `%Admin_Manage:USE`,
  `%DB_IRISSYS:READ` (rationale `:34-40`). `Screen/Descriptor/ProcessList.cls:89` declares the same
  three, in that order, and is the **only** descriptor in that area today.
- `Screen/Gate.cls:39-58` evaluates area and screen sets **separately, never unioned** (`:308-309`);
  `EvaluatePairs:89` names the first unheld pair; `Api/Navigation.cls:68` serializes `failedPair`;
  the client renders it through `ui/src/app/core/navigation.ts:162 formatRequires` into
  `rail.ts:127` and `side-bar.ts:156`.
- Pins that cost: `Test/Descriptor.cls:266-267,:497-520,:900`; `Test/AreaPair/Bad.cls:30` +
  `Test/AreaPairRegistry.cls`; `Test/Wire.cls:391-396,:562-607`; `Test/WireSecurityRead.cls:357-412`;
  `Test/Navigation.cls:214,246,255,260`; `Install/Smoke.cls:469`; `ui/src/app/core/screens.generated.ts:317-336`;
  `ui/tools/navigation-wire.test.mjs:27-29,:74-89`; `ui/src/app/shell/rail-wire.spec.ts:26,:72-81`.
- Charter correction: `epics.md:3611` is **Story 6.8 Process details**, `:3655` is **Story 6.10 The
  locks view** (not 7.8), and `:3903` **Story 7.8** is process *actions* on the existing screen.
  Neither 6.8 nor 6.10 names a privilege in its acceptance criteria.

**DW-272 — citations.** Measured 2026-09-15: **120** `EXPERIENCE.md:<n>` citations in `ui/src/**/*.ts`
outside `strings.ts` (44 files), of which **111 are already stale** by `git blame` + `git show` of the
cited line at the citing commit; 95 of those still have their authored sentence verbatim, shifted +2
to +30. Plus **14** in `ui/tools/*.mjs`, **5** in `ui/src/styles/_components.scss`, **1** in
`src/OcuPilot/Test/Token.cls:558`, and **9** ungated prose citations inside `strings.ts` itself
(`:23,24,27,33,450,451,487,492,498`) -- **149 to convert**. Only 60 of the 120 carry any adjacent
quote and only 2 of those land on the cited line.
- `ui/tools/strings.test.mjs:493-530` -- the only citation gate in the repository. It resolves the
  `/** EXPERIENCE.md:n */` comments in `strings.ts` **by value**, not by line (`:523-524`), and names
  the correct line on failure (`:525-526`). Those 197 stay as they are. Its neighbours:
  table parse `:48-69`, closed-world key equality `:336-350`, uniqueness `:444-450`,
  `REQUIRED_ALONGSIDE_TABLE` frozen at 3 `:330-334`, literal band 150-220 `:306-309`, namespace-key
  roster `:376-383`, footer row exactly 5 literals `:412-429`, area row 8 `:282-295`.
- `scripts/lint-docs.sh` and `scripts/check-prose.py` look at no code-to-doc reference.
  `DESIGN.md` carries **106** ungated line citations -- out of this entry's scope (Design Notes).

## Tasks & Acceptance

**Execution** (in order; each item is one bounded fix with one pinning test):

1. `ui/src/styles/_components.scss` -- give the routed outlet a definite height so the chain from
   `main.ocu-content` (definite, 737px) reaches the viewport: rules for `app-screen-outlet` **and**
   `div.ocu-screen-outlet`, and whatever `.ocu-content` needs to pass its height down. Keep every
   existing `min-height: 0`. -- the chain is the cause; the viewport reads 0 because an inline host
   sits in the middle of it.
2. `ui/browser/list-spec.mjs`, `ui/browser/{tasks,processes,users,web-applications,audit,error-log}.browser-spec.mjs`
   -- add a shared "click a row at its centre" helper using `page.click()` and
   `document.elementFromPoint`, and replace every synthetic `dispatchEvent`/`HTMLElement.click()`
   row workaround with it. -- the workarounds are why no spec caught this.
3. `src/OcuPilot/Port/AdminPort.cls` -- declare, per admin endpoint and request type, the pair set the
   **backing query** requires (any-of, because the vendor check is an OR), established by AD-29's
   discipline and not read off `ResourcesOR()`; on the error path at `:560-562`, before answering 500,
   evaluate it with `$System.Security.Check` and, when none is held, answer `403` + `PORT.ACCESSDENIED`
   with `detail.failedPair`. Give `Refuse:686` the optional `pDetail` argument
   `LogSourcePort.cls:1229-1235` already has. An endpoint with no entry, or a caller who holds the
   set, keeps today's 500. -- the vendor status is unreachable; the port must detect the refusal itself.
4. `src/OcuPilot/Test/WireSecurityRead.cls:337-347` -- restate the recorded observation and its
   mutation paragraph: the under-declared read now answers 403 naming `%Admin_Manage:USE`, not 500.
   -- correct the claim at its origin.
5. `src/OcuPilot/Screen/Registry.cls:148` and `ui/tools/screen-mirror.mjs:886` -- refuse an unknown
   **top-level** declaration key by name, against the closed 25-key set, before any accessor runs.
   Unknown-key only, never presence. -- `banners` currently installs a screen whose strip never raises.
6. `src/OcuPilot/Test/DeclarationCorpus.cls` (new, following the four templates) + `ui/tools/screen-mirror.test.mjs`
   + `src/OcuPilot/Test/ReadTool.cls` -- one corpus driving both engines, with `banners`, `Banner` and a
   sound declaration among its cases.
7. `src/OcuPilot/Screen/Registry.cls:700-702,:729` and `ui/tools/screen-mirror.mjs:623,:643` -- add
   `maxLength` to the criterion grammar (a whole number > 0, required on every criterion) with its own
   `*Problem`; extend `ReadCriterion` at `screen-mirror.mjs:1097-1102`; add the cases to
   `src/OcuPilot/Test/CriteriaCorpus.cls`. -- the choice-options check is the shape.
8. `src/OcuPilot/Screen/Descriptor/AuditList.cls:133-141` -- declare each criterion's `maxLength` from
   its vendor property's `MAXLEN` (50 for `beginDateTime`, `endDateTime`, `pids`, `authentication`;
   1000 for the other five), and pin those against the live `%Dictionary.CompiledProperty` in
   `src/OcuPilot/Test/Descriptor.cls` so a vendor narrowing goes red.
9. `src/OcuPilot/Screen/Read.cls:233` -- refuse an over-long criterion value with `400` +
   `READ.CRITERION` naming the param and its limit, before anything is seeded and before the port is
   called; publish `maxLength` in the read tool's schema at `src/OcuPilot/Screen/Tool/Read.cls:79`.
10. `ui/src/**/*.ts`, `ui/tools/*.mjs`, `ui/src/styles/_components.scss`,
    `src/OcuPilot/Test/Token.cls:558` -- convert all 149 prose `EXPERIENCE.md:<n>` citations to an
    anchored form carrying a quoted phrase from EXPERIENCE.md, resolving each mechanically (find the
    authored sentence, do not bump the number by hand). Where the sentence is gone (14 cases), cite the
    nearest surviving sentence or drop the citation. Leave the 197 gated `/** EXPERIENCE.md:n */`
    comments in `strings.ts` alone. -- a number is a claim that rots; a phrase is one that resolves.
11. `ui/tools/strings.test.mjs` (or a sibling `ui/tools/citations.test.mjs` it imports) -- gate every
    anchored citation's phrase against EXPERIENCE.md, and fail any bare `EXPERIENCE.md:<n>` outside
    `strings.ts`'s gated form, naming file and line.
12. `src/OcuPilot/Screen/Registry.cls:378`, `ui/tools/screen-mirror.mjs:522`,
    `src/OcuPilot/Screen/Read.cls:283`, `ui/src/app/shell/list-page.ts:104`,
    `ui/src/app/core/screens.generated.ts` -- let one `banner` express more than one
    (value -> sentence) case over one field, refused identically by both engines, **keeping one read
    per banner**; update `src/OcuPilot/Test/BannerCorpus.cls`.
13. `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md` +
    `ui/src/app/core/strings.ts` + `src/OcuPilot/Screen/Descriptor/TaskScheduleList.cls:93-99` -- author
    the stopped sentence, add its Fixed strings row **and** its key in the same pass, and declare the
    `"Not running"` case. -- a row with no key breaks `strings.test.mjs`'s cardinality.
14. `ui/src/app/areas/logs/error-log.store.ts:305-348` -- carry `truncated` into every level's model;
    `ui/src/app/areas/logs/error-log.page.ts` -- render a cap notice on a level that was cut, and one
    on a truncated detail. Author the sentence and add its EXPERIENCE.md row + key in the same pass;
    it must not promise a max-rows control the drill does not have.
15. `ui/src/app/core/screen-actions.ts`, `ui/src/app/shell/command-bar.ts` (before the chip at `:221`),
    `ui/src/app/shell/command-box.ts`, `ui/src/app/shell/list-page.ts`,
    `ui/src/app/areas/logs/audit.page.ts`, `ui/src/app/areas/logs/error-log.page.ts` -- register a
    `refresh` action per page and draw it in the bar while a page offers one; Home offers none, and the
    audit viewer offers none before its first Search. Append `· "Refresh"` to the existing
    action-names Fixed strings row (an in-place edit shifts no lines) and add `actionRefresh` to
    `strings.ts`.
16. `ui/src/app/app.ts` -- on the frame's arrival (the `instanceReady` swap), move focus to
    `main#ocu-content` via `afterNextRender(..., { injector })`, but only when focus is on the document
    body or inside the removed notice. Do not write a screen-heading branch: no screen heading exists.
17. `ui/browser/shell.browser-spec.mjs:210,:261` -- restate the two DW-247 Tab-order pins against the
    new arrival destination, saying in the header why the skip link no longer holds the first Tab after
    a frame arrival.
18. `src/OcuPilot/Test/{WireSecurityRead,Wire,Token,State,Version,UnexpireScope}.cls` -- add the
    `OCUPILOT_ALLOW_PRINCIPALS` guard from `LogSourceDenial.cls:73-77` to each `OnBeforeAllTests`,
    deleting the doc comment that stood in for it.
19. `scripts/check-objectscript.py` + `scripts/test_check_objectscript.py` -- add a rule that fails a
    `src/OcuPilot/Test/` class which calls a principal-creating/deleting or log-rotating API without the
    arming guard in `OnBeforeAllTests`. -- six edits fix six classes; a rule fixes the population.
20. `src/OcuPilot/Screen/Area.cls:34-40,:64` -- record the decision at the declaration: os-management
    declares the union, the false denial for a narrower screen is accepted, and coverage is **not**
    relaxed. Add a narrow os-management fixture descriptor (`%Admin_Operate:USE` + `%DB_IRISSYS:READ`
    only) under `src/OcuPilot/Test/` and pin both halves.

**Acceptance Criteria** (system-level; the I/O matrix rows are not repeated here):

- **AC-A (DW-273, integration).** Given every built list route plus the audit viewer and the error-log
  drill, when a browser opens each at 1440x900, then `cdk-virtual-scroll-viewport.clientHeight` is
  greater than zero on each and a hit-tested click at the centre of a row reaches that row.
- **AC-B (DW-274, integration).** Given `Screen/Read.cls` and `Screen/Tool/Read.cls` calling
  `AdminPort.Invoke` for an endpoint whose declared query pairs the caller does not hold, when the
  port answers, then it answers 403 / `PORT.ACCESSDENIED` with `detail.failedPair`, and every read
  whose caller holds the pairs answers exactly as it does today.
- **AC-C (DW-271/DW-279, integration).** Given the production descriptor roster, when `Registry.Validate`
  and `screen-mirror.mjs --check` run, then both pass unchanged, both refuse the new corpus cases with
  byte-identical sentences, and `ui/src/app/core/screens.generated.ts` is regenerated and checked in.
- **AC-D (DW-270/DW-293/DW-260).** Given every new or changed user-facing sentence, when `npm test`
  runs, then `strings.test.mjs` passes with its key count equal to its literal count, no value
  duplicated, and every gated citation resolving.
- **AC-E (DW-272).** Given the citation gate, when a Fixed strings row is inserted anywhere in
  EXPERIENCE.md, then no anchored citation in source changes meaning and the gate stays green; and
  when a cited phrase is altered, the gate fails naming the file, the line and the phrase.
- **AC-F (DW-289).** Given `node ui/tools/ci-runner.mjs --container ocupilot --package OcuPilot.Test`,
  when the listing query returns a class that creates principals or rotates a log, then that class
  fails in `OnBeforeAllTests` before any `Test*` method is enumerated, and no principal, role or
  rotated log is left on the instance.
- **AC-G (DW-275).** Given a narrow os-management screen declaring only `%Admin_Operate:USE` and
  `%DB_IRISSYS:READ`, when the registry validates and an `%Admin_Operate`-only principal reads the
  navigation payload, then coverage passes and the area is denied by name on `%Admin_Manage:USE` --
  the accepted false denial, observed rather than asserted.
- **AC-H (regression).** Given the whole suite, when `npm run build`, `npm test`,
  `npm run test:browser`, `uv run scripts/check-objectscript.py`, `bash scripts/lint-docs.sh` and the
  ObjectScript classes run, then all pass, and `bash scripts/smoke.sh` executes a non-zero number of
  checks with none failing.

## Spec Change Log

## Review Triage Log

## Design Notes

**Governing architecture decisions (Rule 6).** AD-5 and AD-36 (one descriptor, one bounded read that
reports truncation) bind DW-271, DW-279, DW-270 and DW-293. AD-8, AD-29 and AD-39 bind DW-274 and
DW-275: a gate is a set of pairs, a denial names the failing pair, a pair set is *established* and not
read off `ResourcesOR()`, and vendor error text is normalized at the port boundary. AD-27 keeps every
`%Api.Admin.*` name inside `AdminPort`, which is why the query-pair declaration lives there. AD-12 and
AD-39 bind the 403's envelope and its `detail`. AD-19 binds DW-260 (state in a store, `core/` stays
framework-free) and DW-248. AD-43 binds DW-260's silent refresh. AD-21 and AD-48 bind DW-293 (the drill
reads through `LogSourcePort`; the detail payload stays out of context and out of the model). AD-2's
sequence is the one DW-274 extends without reordering.

**Consumes** (shared surfaces this story changes, and the story that owns each): the descriptor grammar
and its two engines (2.3); `Screen/Read.cls`'s criteria and banner paths (2.3, 2.8); `AdminPort`'s fault
mapping (2.1); the data table, its height chain and its cap notice (2.4); the command bar and
`RefreshService` (2.4, 1.14); the error-log drill store (2.12); `Screen/Area.cls` (2.3, 2.9); the Fixed
strings table and `strings.test.mjs` (1.2).

**Consumed-by:** Story 4.10 reads the task strip's suspended/stopped signal for its Home line, so
DW-270's second case is what makes a stopped scheduler visible there. Stories 6.8 and 6.10 add the
narrower os-management screens whose gating DW-275 decides in advance. Story 6.14 owns DW-278 and
inherits DW-275's precedent. Every later story that adds a screen inherits DW-271's closed key set and
DW-279's `maxLength` requirement, and every later sentence inherits DW-272's anchored citation form.

**DW-274 -- how the port detects a refused query, and what proves it.** The ledger's correction is
half right: the vendor status genuinely never reaches OcuPilot, but the port does **not** see an empty
result set. `%Api.Admin.Util.ClassQuery.RunQuery` assigns `stmt.%Execute()` to a method-local and never
checks it, so the refusal surfaces as an error `%Status` carrying
`<INVALID OREF>AppendStatementResult+5^%Api.Admin.Util.ClassQuery.1`, which `Fault.Normalize` has no
row for and `RunSequence:560-562` turns into 500. Three detection routes are closed: reading
`%SQLCODE`/`%Message` off the result set (method-local, no seam, and the endpoint hard-codes the vendor
class); matching the status text (`Fault.cls:34-37` matches domain and message id precisely so the
mapping is not a string match on English, and matching the message id instead would map every internal
fault to 403); and re-checking the descriptor's pair set (the screen gate already does that before the
port, so it detects nothing new). What remains, and what this story builds, is a **per-endpoint
declaration of the backing query's own pair requirement, probed on the error path only**: no cost on
the happy path, and no false 403 for a caller who holds the set. The declaration is any-of because
`%SYS.ProcessQuery.CONTROLPANELExecute` accepts `%Admin_Manage:USE` **or** IRISSYS write; a flat
all-of check would refuse a caller the vendor would serve.

*Evidence, and its limit.* No production descriptor under-declares -- AD-29's discipline is what
removed the last one -- so the 403 is defense in depth for a mis-declared screen, and there is no
production path that reaches it. The **standing** assertion is therefore at the port: a call that
genuinely errors, with the query-pair probe reporting the pair unheld through an overridable seam,
must answer 403 / `PORT.ACCESSDENIED` / `detail.failedPair`, and must answer 500 when the pair is held.
The **end-to-end** evidence is the story's own Rule 19 mutation, run on the throwaway with a real
least-privileged principal: removing `%Admin_Manage:USE` from `ProcessList` and the os-management area
turns the read from 500 into a named 403. That is the mutation `WireSecurityRead.cls:344-347` already
documents, with its outcome corrected.

**DW-273 -- the cause, measured.** `app-screen-outlet` carries no CSS rule at all: it is `display:inline`
with `clientHeight 0`, and it sits between `main.ocu-content` (definite, 737px) and everything below,
so `div.ocu-screen-outlet` has no definite height either and `app-list-page { height: 100% }` computes
to `auto`. Every `flex: 1 1 auto` below it then sizes to content, leaving the 36px header row as the
only content height inside a frame whose `overflow:hidden` and whose viewport's `contain:strict` clip
the rows out of paint -- while the rows' layout boxes still occupy the coordinates the footer paints.
Every flex item in the chain already carries `min-height: 0`, so the usual nested-flex cause is ruled
out. The same gap hits the audit, error-log and home archetypes, which have no rule either; fixing it
at the outlet covers all four.

**DW-248 -- the destination, and the consequence.** The AC calls the screen heading "the destination a
route arrival already uses". Neither exists: there is no route-arrival focus mechanism anywhere in the
client, and there is no screen heading -- the screen title is a `<span>` in the locator bar. The ledger
decision's own fallback governs, so the destination is `main#ocu-content`, and the heading branch is
**not** written rather than written unreachable. The consequence is deliberate and must be restated,
not absorbed: focusing `main` means the next Tab walks forward into the screen, so the skip link stops
holding the first Tab after a frame arrival -- which is the behaviour `shell.browser-spec.mjs:210`
and `:261` (DW-247, itself dropped into DW-248) pin today. Those two cases are rewritten as part of the
fix. Focus is moved only when it still sits on the body or inside the removed notice, so the fix never
steals focus a user has already placed.

**DW-289 -- the entry's evidence line is wrong, and the AC is a population.** DW-289 says
`WireSecurityRead` is "the last unguarded destructive class". It is not: `Wire`, `Token`, `State`,
`Version` and `UnexpireScope` also create and delete IRIS principals on whatever instance
`ci-runner.mjs --container <name>` points at, and `WireSecurityRead.EnsurePrincipal` deletes a
pre-existing account of the same name before creating its own. The acceptance criterion is phrased over
a population ("a test class that creates principals or rotates a log"), so this story guards all six
and adds the structural rule that keeps the seventh from repeating it. Sixteen further classes run a
real `Installer.Install("")`, and `Test/Demo.cls` and `Test/WebApp.cls` create and modify web
applications and roles; those are real instance mutation but are outside this AC's wording, and are
left for the lead to ledger rather than silently widened here.

**DW-275 -- the decision was already taken, and this records it.** DW-278's owner-delegated decision of
2026-09-14 declined relaxing `AreaCoverageProblem` in general terms -- relaxing it trades a false
denial for the false admission AD-8 names -- and `Registry.cls:306-309` and `Gate.cls:308-309` say the
same. So DW-275's second option is closed, and the remaining work is to apply the first deliberately:
the area declares the union, the false denial is recorded at the declaration, and a narrow fixture
screen observes it. The union does not grow when 6.8 and 6.10 land -- both read a single object rather
than `SYS.Process:CONTROLPANEL`, so both plausibly need only `%Admin_Operate:USE` and
`%DB_IRISSYS:READ` **(inference** -- derived from the endpoints' `ResourcesOR()` probe recorded at
`Area.cls:10-15`, not from those stories' acceptance criteria, which name no privilege; it is settled
by running each new read as a least-privileged principal on a throwaway when the screen lands**)**.
What changes is the count of screens falsely denied: 0 of 1 today, 2 of 3 then. Splitting the area is
not available -- `Area.cls` and `Test/Descriptor.cls:890-905` pin the area vocabulary as closed at
eight.

**DW-272 -- why the anchor, not the number.** Widening the existing resolver to prose citations cannot
assert what it asserts in `strings.ts`, because a prose citation has no key/value pair to resolve by:
the only line-based check available is "the cited line is non-blank", which 101 of the 111 stale
citations would still pass. Dropping the numbers outright leaves nothing to check. Anchoring each
citation to a quoted phrase gives a gate with teeth that is also immune to row insertion, which is
exactly the failure the AC names. `DESIGN.md`'s 106 ungated citations are out of this entry's scope;
the same mechanism is available to whichever story next touches them.

**Declined, with reasons.** Nothing in the inbox is declined -- all eleven entries are addressed by a
matrix row and a task above (DW-273 row 1, DW-274 row 2, DW-271 row 3, DW-279 row 4, DW-272 row 5,
DW-270 row 6, DW-293 row 7, DW-260 row 8, DW-248 row 9, DW-289 row 10, DW-275 row 11).

## Verification

**Commands** (from `ui/` unless stated; throwaway legs need `sh scripts/ci-throwaway.sh up` first --
container `ocupilot-ci`, which is what sets `OCUPILOT_ALLOW_PRINCIPALS`, `OCUPILOT_ALLOW_LOG_ROTATION`
and `OCUPILOT_ALLOW_ERROR_SEED`):

- `npm run build` -- expected: the five prebuild checkers pass, `screen-mirror.mjs --check` reports the
  census and no staleness, the bundle builds.
- `npm test` -- expected: `node --test tools/*.test.mjs` green (including `strings.test.mjs` and the new
  citation gate) and the Angular component runner green.
- `OCUPILOT_BROWSER_EXECUTABLE="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
  OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 npm run test:browser` -- expected: every spec green
  against `ocupilot-ci`, including the new centre-of-row hit tests and the restated Tab-order cases.
- `uv run scripts/check-objectscript.py` and `uv run scripts/test_check_objectscript.py` (repo root) --
  expected: both green, the new guard-presence rule covered by its own harness case.
- `bash scripts/lint-docs.sh` (repo root) -- expected: green after the EXPERIENCE.md rows are added.
- `node ui/tools/ci-runner.mjs --container ocupilot-ci --class <one class>` -- **one class per
  invocation, and the next only once the previous run has landed in `%UnitTest_Result`**; verify totals
  with the SQL probe over `%UnitTest_Result.TestMethod` rather than trusting the envelope.
- `bash scripts/smoke.sh --container ocupilot-ci --user _SYSTEM --password SYS` -- expected: a non-zero
  number of executed checks, none failed.

**Pinning tests and their mutations (Rule 19 -- one demonstrated mutation per AC; apply, observe red,
revert, confirm `git status --short` and `git diff --stat` unchanged):**

- **DW-273** -- browser case asserting `clientHeight > 0` and `elementFromPoint(row centre)` inside the
  row, on all four list routes plus the audit and error-log screens.
  `mutation: delete the app-screen-outlet height rule from _components.scss -> the viewport measures 0
  and the hit test returns .ocu-data-table-footer, on every list route.`
- **DW-274** -- port-level standing assertion: an erroring call whose declared query pair the seam
  reports unheld answers 403 / `PORT.ACCESSDENIED` / `detail.failedPair`, and answers 500 when it is
  held. `mutation: remove %Admin_Manage:USE from ProcessList and the os-management area on the
  throwaway and read the processes list as OcuPilotWireOperate -> the read answers 403 naming
  %Admin_Manage:USE (500 before this story); removing the error-path probe restores the 500 and turns
  the port assertion red.`
- **DW-271** -- `DeclarationCorpus` cases run by both `screen-mirror.test.mjs` and `Test/ReadTool`.
  `mutation: rename the descriptor's banner key to banners -> both engines refuse by name and the
  screen does not install; removing the Registry.cls:148 check makes the corpus case red on the
  ObjectScript side alone, and the screen-mirror.mjs:886 check likewise on the client side alone.`
- **DW-279** -- a live leg reading `logs/audit` with an 83-character `pids`.
  `mutation: raise pids' maxLength above 83 -> the read reaches the port and answers 500 again, and the
  400 READ.CRITERION assertion goes red; narrowing the vendor MAXLEN in the pin's expectation turns the
  %Dictionary.CompiledProperty assertion red.`
- **DW-272** -- the citation gate over every anchored citation.
  `mutation: change one word inside one cited phrase in EXPERIENCE.md -> the gate fails naming that
  file, line and phrase; inserting a Fixed strings row above it leaves the gate green, which is the
  point.`
- **DW-270** -- a read test over the banner fixtures for all three `Status` values.
  `mutation: delete the "Not running" case from TaskScheduleList -> BannerKey answers "" for a stopped
  manager and the stopped assertion goes red, while the Suspended and Running assertions stay green.`
- **DW-293** -- store and page specs per level, plus a browser leg on a truncated level.
  `mutation: drop truncated from one level's branch of absorb() -> that level renders no cap notice and
  its assertion goes red, while the other levels stay green.`
- **DW-260** -- per page, a test counting reads through the transport and asserting sort, filter and
  selection survive, plus a browser leg for scroll.
  `mutation: unregister the refresh action on the audit viewer -> the bar draws no Refresh there and
  that page's assertion goes red, while the list screens stay green.`
- **DW-248** -- a jsdom case in `app.spec.ts` (activeElement after `instanceReady` flips) and browser
  cases for the sign-in and recovery paths.
  `mutation: remove the focus move from app.ts -> document.activeElement is BODY after the frame
  arrives, on both paths.`
- **DW-289** -- run each newly guarded class on the **live** `ocupilot` container and confirm it
  refuses, then on `ocupilot-ci` and confirm it runs; plus the checker's own harness case.
  `mutation: delete the guard from Test/State.cls -> check-objectscript.py fails naming that class, and
  the class would run on a live container.`
- **DW-275** -- registry validation of the narrow fixture plus a real-principal navigation read.
  `mutation: drop %Admin_Manage:USE from the os-management area -> AreaCoverageProblem refuses
  ProcessList and the observed false denial flips to allowed.`

**Manual checks:**

- Confirm `ui/src/app/core/screens.generated.ts` was regenerated by the tool and not hand-edited --
  `screen-mirror.test.mjs` compares it byte for byte.
- Confirm no principal, role, rotated log or seeded error is left on live `ocupilot` after the story:
  `docker compose exec` a listing of `OcuPilot*` users and roles and expect none.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none
