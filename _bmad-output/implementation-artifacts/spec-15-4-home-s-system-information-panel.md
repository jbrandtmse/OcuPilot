---
title: "Story 15.4: Home's System Information panel"
type: 'feature'
created: '2026-09-20'
status: 'done'
baseline_revision: '3a3acf5789513ec0a6e6c93cf5dd03748037a31c'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-15-context.md'
warnings: ['oversized']
deferred:
  - summary: >-
      Running the full browser suite twice against one throwaway reddens two messages-log
      tests, because that spec's own seeded entries fall out of the rendered tail window and
      its before-hook refuses to re-seed while the markers are still in the file.
    evidence: |-
      Measured twice on ocupilot-b-ci. On a fresh container the suite is 198/199; the seed
      lands at lines 768-773 and both rows pass. The suite's own other specs then write ~460
      further console lines, and the second run reads 197/199 with "the measured window
      carries a debug row; saw info,severe,warning" and "the filter narrows the list: 283 -> 0".
      The before-hook at browser/messages-log.browser-spec.mjs:77-83 re-seeds only when
      `grep -c` finds fewer than five markers, and they are still there.
    location: >-
      ui/browser/messages-log.browser-spec.mjs:77
    severity: medium
  - summary: >-
      Resizing a tab from 1,440 px to 720 px leaves the document scrolling horizontally by
      about 22 px; the overflowing element is app-panel / .ocu-panel, not Home.
    evidence: |-
      Measured by the implement pass with and without this story's block, identical either
      way, so the panel's remembered width is not re-clamped on resize. Out of footprint:
      ui/src/app/shell/panel* is Epic 5's by decision. Story 15.4's AC2 is asserted with the
      viewport set before the document loads, which is what "Home at a supported width" means.
    location: >-
      ui/src/app/shell/panel.ts
    severity: medium
  - summary: >-
      scripts/ci-throwaway.sh writes its compose file from an unquoted heredoc whose body
      contains a backticked word, so the shell command-substitutes it away.
    evidence: |-
      `cat > "$COMPOSE_FILE" <<EOF` at :155 with "`classes:`" at :172 prints
      "classes:: command not found" on stderr and the generated /tmp/<dir>/compose.yml reads
      "one or more  lines" with the word gone. Harmless today because the loss is inside a
      YAML comment, but any $ or backtick meant literally in that body expands too.
    location: >-
      scripts/ci-throwaway.sh:172
    severity: low
  - summary: >-
      EndpointCoverage.TestEveryProbeDispatchesToItsRoute fails on the slot B dev instance
      because that container serves no client bundle, so its two Api.StaticHandler probes
      answer 503 STATIC.NOBUNDLE.
    evidence: |-
      /durable/iris/csp/ocupilot/ is empty on ocupilot-slot-b. The method passed at run 434
      and has failed since run 454, both before this story's implement pass began. Environmental,
      not a code defect: the same class's TestEveryRouteHasAProbeAndEveryProbeHasARoute, which is
      what a new route needs, passes, and the whole class passes on the throwaway.
    location: >-
      src/OcuPilot/Test/EndpointCoverage.cls
    severity: low
  - summary: >-
      Api/UiSystem.HandleSystem's two Error.RenderInternal paths are never exercised, because
      Payload() only answers an error if %Set itself raises.
    evidence: |-
      The same gap exists for Api/UiAbout, landed by Story 15.3, so it is the pair's shape
      rather than this story's. Closing it needs a seam on Payload that neither class has.
    location: >-
      src/OcuPilot/Api/UiSystem.cls
    severity: low
  - summary: >-
      .ocu-home-system-row sets a hard height where DESIGN.md says every height outside the
      virtualized lists is a minimum, so a text-only resize clips the row.
    evidence: |-
      DESIGN.md:912 states the rule; _components.scss uses `height: var(--ocu-control-height)`
      in 13 places and `min-height: var(--ocu-control-height)` in none, so this story followed
      the codebase rather than the design document. Fixing it here alone would make one row
      behave unlike every other control-height row.
    location: >-
      ui/src/styles/_components.scss:5020
    severity: low
---

<intent-contract>

## Intent

**Problem:** Home answers "where do I go?" but not "is anything wrong?". The classic portal's System Information panel reported uptime, mirror state, the four dashboard alerts and production status; OcuPilot reports none of them, and Story 15.3's About deliberately declined uptime and mirror state to this story, so the product currently shows neither anywhere.

**Approach:** One caller-own shell-chrome read, `GET /api/ocupilot/ui/system`, extending Story 15.3's landed `Kernel/Shell/About.cls` + `Api/UiAbout.cls` pair, answering seven scalars from three in-process sources with a per-field degrade. Home renders them as a fifth block of the same shape as the four already above the tile grid.

## Boundaries & Constraints

**Always:**

- Shell chrome: no screen descriptor, no tool, no proposal, no auto-refresh timer (AD-5, AD-36's chrome exception, AD-43). Home stays absent from AD-43's seven-screen roster; the panel settles with its own read.
- Every field is read in the calling process, each in its own `Try`, so a refused or absent source degrades that one field to `""` and logs — `Kernel/Shell/About.cls:90-100`'s `Field`/`ReadSource`/`LogSourceFailure` seam, copied.
- A state word is rendered **as the source reports it**, never translated (`Normal`/`Warning`/`Troubled`; `Not initialized`/`Primary`/…). Color is never the only signal — each row carries its word.
- `%SYS` is reached only by explicit save and restore, with the restore as the first line of the `Catch` (AD-16).
- Every new literal is published in EXPERIENCE.md's Fixed strings table **before** it exists as a `strings.ts` key, appended strictly after the current last row `:383`.
- Nothing is hidden by viewport width. The classic portal's "hide the panel below 1,100 px" (`irissys/%CSP/Portal/Home.cls:1633`) is recorded as rejected at `EXPERIENCE.md:703`.

**Never:**

- Never edit a screen descriptor and never regenerate `ui/src/app/core/screens.generated.ts` — Epic 5 has modified it and `screen-mirror.mjs --check` must stay green **with no regeneration**. That includes `Screen/Descriptor/SystemUsage.cls` and `Home.cls`.
- Never name an `%Api.Admin.*` class: only `Port/AdminPort` may (AD-27). This story adds no port and touches none.
- Never a second source for a value About already carries, and never resurrect cluster support — 15.3 declined it on its own ground.
- Never accept a namespace, path or class name from the caller; the route takes no caller input at all beyond the router's own validated `?ns=` (AD-21, AD-44).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Panel read | signed-in user; `GET /api/ocupilot/ui/system?ns=<scope>` | `200` with seven scalars: `uptime`, `mirror`, `databaseSpace`, `journalSpace`, `lockTable`, `writeDaemon`, `production` | No error expected |
| One source refuses | a field's call throws, or its privilege is absent | That field alone reads `""`; the other six answer; the failure is logged | Per-field `Try`, never a 500 |
| A metric was never sampled | the Application Monitor has not collected it (`SYS/Stats/Dashboard.cls:12-14`; measured on slot B, `LastBackup` reads `""`) | That field reads `""`; its row keeps its label and shows the not-reported word | Absence is not a fault |
| Not a mirror member | `$SYSTEM.Mirror.GetMemberStatus()` → `$LB("Not initialized")` (measured, slot B) | `mirror` reads `Not initialized` | — |
| Mirror read failed | the accessor catches its own error and returns `$LB("Error", <text>)`, so the per-field `Try` never fires | `mirror` reads `""` and the failure is logged | The leading `Error` element is normalized to `""`, never rendered as a state |
| Interop namespace | `%EnsembleMgr.IsEnsembleNamespace()` true; `Ens.Director.GetProductionStatus(.name,.state)` answers | `production` reads the vendor's own English state word, with the production's name where it has one | — |
| No production ever run | state `2`, name `""` (measured, slot B HSCUSTOM) | `production` reads `Stopped` with no name | Not an error |
| Non-interop namespace | `IsEnsembleNamespace()` false, or `Ens.Director` does not resolve | `production` reads `""`; the row shows the not-reported word | Never a fault, never a 500 |
| Read unreachable | the read fails, or the fault classifier reports unreachable | The panel renders its error state; the other four Home blocks and the tile grid are unaffected | `JsonResult` `kind:'error'`; the store keeps its last answer |
| Home at a supported width | all five blocks present, 1,440 px and the 720 px 200%-zoom floor (`DESIGN.md:912`) | The block row **wraps**; the document never scrolls horizontally; no block is hidden by width | — |

</intent-contract>

## Code Map

### Server — reuse, do not re-derive

- `src/OcuPilot/Kernel/Shell/About.cls` — **the shape to copy whole**: `Members()` `:56`, `Payload(Output pObject)` `:67`, the per-field `Try` in `Field(pField)` `:90-100`, the `ReadSource(pField)` seam `:115-130`, `LogSourceFailure` `:303`, `Parameter LOGSUBSYSTEM` `:23`. Its header `:16-18` is where uptime, mirror and cluster were deferred to this story.
- `src/OcuPilot/Api/UiAbout.cls:13` — `Extends OcuPilot.Kernel.Shell.About`; `HandleAbout()` `:21` calls `..Payload(.tObject)` `:25` then `Response.JSON` `:30`, `Error.RenderInternal` `:27`/`:32`. Mirror this split exactly.
- `src/OcuPilot/Api/Namespaces.cls:34` — the `%SYS` explicit save/restore precedent (AD-16).
- `src/OcuPilot/Api/Router.cls` — `<Routes>` tail `:112` `/ui/about`, `:113` `/ui/help`, `:114` `</Routes>`; last wrappers `UiAbout()` `:408` and `UiHelp()` `:415` (ends `:418`). `OnPreDispatch` resolves and switches to the `?ns=` namespace once, validated by `CanonicalNamespace` `:497` and `MayEnterNamespace` `:474` (`:596-604`), so a handler already runs in the scoped namespace.
- `src/OcuPilot/Test/EndpointCoverage.cls` — `XData Probes` `:72`, 43 rows, `/ui/help` last at `:117`, `</probes>` `:121`. Row format verbatim (`:112`): `<probe class="Api.Router" method="GET" url="/ui/about" path="/api/ocupilot/ui/about" disposition="envelope"/>`. `TestEveryRouteHasAProbeAndEveryProbeHasARoute()` `:326` is what reddens CI without it.
- `scripts/check-objectscript.py:1473-1478` — the four `WIRE_MARKERS`; `:1558` `names_key` requires the route path to appear **in code**, not in a comment (`:1483-1491` strips comments). `src/OcuPilot/Test/UiAboutWire.cls` satisfies all five at `:27`, `:39`, `:49`, `:51` and `Parameter ABOUTPATH` `:15`.
- `src/OcuPilot/Test/UiAboutRead.cls` — the read-test shape: `Parameter WIREMEMBERS` `:17`, `OnBeforeOneTest`/`OnAfterOneTest` `:27`/`:33` clearing the seam fixture.

### Vendor sources — measured on slot B, 2026-09-20

- `irissys/SYS/Stats/Dashboard.cls:25` — `[ System = 4 ]` only, **not** `[Internal]`, **not** `[Hidden]`; documented `ClassMethod Sample()` `:130`. `SystemUpTime` `:71` is a **preformatted string** (`"4d  4h 27m"`, two spaces — do not compute or reformat a duration). `DatabaseSpace` `:77`, `JournalSpace` `:85`, `LockTable` `:92` are `Normal|Warning|Troubled`; `WriteDaemon` `:96` is `Normal|Troubled` only. The class is **not mapped to `HSCUSTOM`** — a direct call raises `<CLASS DOES NOT EXIST>`; it answers after a switch to `%SYS`. Privileges observed sufficient in `HSCUSTOM`: `%Admin_Operate:USE`, `%DB_IRISSYS:READ`.
- `irislib/%SYSTEM/Mirror.cls:218` — `GetMemberStatus()`, **not** `[Internal]`, answers from `HSCUSTOM` with no switch, `$LB("Not initialized")` here. It has its **own** try/catch and returns `$LB("Error", $ZE)` rather than throwing. `GetStatus()` `:165` returns the raw token `NOTINIT` — a code, not a word — and is not what a user reads. `MemberStatusLogicalToDisplay` `:239` **is** `[Internal]`; do not call it.
- `irislib/Ens/Director.cls:532` — `GetProductionStatus(Output pProductionName, Output pState)`; answered `$$$OK`, name `""`, state `2` in `HSCUSTOM`. `irislib/Ens/Config/Production.cls:263` — `ProductionStateToText(pState, pLocalize)`, documented as an API and not `[Internal]`; **call it with `pLocalize = 0`** so the English word is returned irrespective of session language (NFR-14). State codes: `irislib/%syInterop.inc:36-49`.
- `irissys/%CSP/Portal/Home.cls:2525` `DrawMessagePanel` — the classic origin (catalog SH-19). It computes its own uptime `:2560`, gates mirror on `IsMember()` `:2566`, and enumerates productions across namespaces `:2665-2690`.

### Client — reuse, do not re-derive

- `ui/src/app/core/about.ts` — the store shape: private state `:88-111`, `generation` `:102`, the `request` counter `:109`, `answered()` `:118`, `failed()` `:123`, `subscribe()` `:135-140`, `load()` `:143-170` with the two guards `:147-148` and the **never-cleared-on-transport-failure** branch `:149-156`, `reset()` `:177-185`, `notify()` `:187-189`.
- `ui/src/app/areas/home/home.page.ts` — the block row is `<div class="ocu-home-remembered">` `:199-276`; the two fixed blocks (Shortcuts `:237-260`, Links `:261-275`) are the shape to copy, backed by `resolvedShortcuts` `:463-476` / `resolvedLinks` `:487-495` and their getters `:564-570`. **The fifth block slots in at `:275`**, before `</div>` `:276`. Stores injected `:328-335`; constructor subscriptions and chrome loads `:516-554` (`this.about.load()` `:545`), unsubscribes `:546-553`.
- `ui/src/styles/_components.scss:4752-4756` — `.ocu-home-remembered` is already `display:flex; flex-wrap: wrap`, and `.ocu-home-block` `:4758-4764` is `flex: 1 1 var(--ocu-side-bar-width); min-width: 0`. **A fifth block therefore wraps by construction**; AC2 pins that behavior rather than creating it. Row rules `:4766-4886`; file ends `:5014`.
- `ui/src/main.ts:198` `new About({ api })` and `:246` `{ provide: About, useValue: about }`; `ui/src/app/app.ts:195` injection and `:489-492` the sign-out `reset()`.
- `ui/src/app/core/strings.ts` — last table-sourced key `actionReload` `:1204` (`/** EXPERIENCE.md:383 */` `:1203`), `} as const;` `:1231`; per-story comment block, 15.3's at `:1153-1159`. `ui/tools/strings.test.mjs` — count band `150..600` at `:462-465` (**not** widened by this story), set equality `:467-471` and `:491-510`, **unique values `:604-611`**.
- `ui/browser/about-help-links.browser-spec.mjs` — the browser-spec file shape (header, `node:test`, puppeteer, `browserConfig()`); `ui/package.json:17` `test:browser` is a bare glob over `browser/*.browser-spec.mjs`, so a new file needs no registration. `ui/browser.config.mjs:85` default viewport `1440x900`; `:83-84` warns that below the side bar's breakpoint a spec asserts the collapse rather than the layout. Geometry precedent: `preferences-integration.browser-spec.mjs:170-198` (a Home block label ellipsizes rather than widening) and the whole-page scroll assertions at `messages-log.browser-spec.mjs:243-245`.

### Read-only evidence

- `prd.md:999-1003` FR-73; `feature-catalog.md:66` SH-19, whose `interop-v7 /productions/status` has **no** backing port — `src/OcuPilot/Port/` holds exactly `AdminPort`, `LogSourcePort`, `MgmntPort`, `ProviderPort`.
- `src/OcuPilot/Screen/Descriptor/SystemUsage.cls:72` — the declared read's 18 fields: `Dashboard.SystemUsage.{DatabaseSpace,JournalSpace,LockTable,WriteDaemon}` and **not** `Dashboard.Status.UpTime`. The live `GET /api/admin/v2/monitor/dashboard/main` names uptime `Status.UpTime` and carries **no** mirror key and **no** production key.
- `EXPERIENCE.md:83` places the panel above or beside the tile row; `:642` is the Auto-refresh roster, Home absent; `:383` the last Fixed strings row; `:703` the rejected hide-below-1,100-px rule.

## Tasks & Acceptance

**Execution:**

- `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md` — **append** one Fixed strings row immediately after `:383`, annotated `[ADDED 2026-09-20 — see the story change log]`, publishing nine literals: the block heading "System information"; the seven row labels "Uptime", "Mirror", "Database", "Journal", "Locks", "Write daemon", "Production"; and "Not reported", the word a row shows when the instance reports no value. Never insert above `:383`.
- `src/OcuPilot/Kernel/Shell/SystemInfo.cls` — NEW. `Payload(Output pObject)` emitting the seven scalars, over one overridable `ReadSource(pField)` seam with a per-field `Try` and `LogSourceFailure`, copying `Kernel/Shell/About.cls:67-130`. One `SYS.Stats.Dashboard.Sample()` per payload inside a single `%SYS` save/restore serves the five dashboard fields; mirror and production need no switch. Normalize the mirror accessor's `$LB("Error", …)` answer to `""`.
- `src/OcuPilot/Api/UiSystem.cls` — NEW. `Extends OcuPilot.Kernel.Shell.SystemInfo`; one `HandleSystem()`, caller-own, following `Api/UiAbout.cls:21-33`. It accepts no argument, so there is no validation ladder and **no new error code** — `Api/Error.cls` is not touched.
- `src/OcuPilot/Api/Router.cls` — **shared-append grant**: `<Route Url="/ui/system" Method="GET" Call="UiSystem"/>` as the last line of `<Routes>` (after `:113`), and one thin wrapper after `UiHelp()` `:418`. Run `uv run scripts/check-objectscript.py` before the commit and quote its result.
- `src/OcuPilot/Test/EndpointCoverage.cls` — append one probe row after `:117`, in the verbatim format above. A plain GET needs no `BADBODY` and no `refusal`.
- `src/OcuPilot/Test/UiSystemRead.cls` — NEW. Pins the read: all seven members present; one source failing degrading that field alone; an unsampled metric reading `""`; the mirror `Error` normalization; the interop and non-interop production branches.
- `src/OcuPilot/Test/UiSystemWire.cls` — NEW. The `check_handler_wire_tests` contract with all four markers and the route path named in code.
- `ui/src/app/core/system-info.ts` — NEW. Framework-free store over `GET /api/ocupilot/ui/system`, carrying `?ns=` as scope; `fields()`, `answered()`, `failed()`, `load()`, `subscribe()`/`notify()`, the request counter, never cleared on a transport failure — `core/about.ts` copied, not re-derived.
- `ui/src/app/areas/home/home.page.ts` — add the **System information** block at `:275` as a fifth `ocu-home-block ocu-home-block-fixed`, a `role="list"` of `role="listitem"` rows, each row a label and the value the instance reported, a field the instance did not report showing the not-reported word. Subscribe and `load()` beside `this.about.load()` `:545`; unsubscribe beside `:546-553`.
- `ui/src/app/core/strings.ts` — **shared-append** the new keys in one block with a leading comment naming the story. Reuse an existing key wherever its value already exists rather than repeating the value; `strings.test.mjs:604-611` is what refuses a duplicate.
- `ui/src/styles/_components.scss` — append only what the panel's label/value rows need, reusing the metrics `.ocu-home-block-*` already sets. No new token, and `_tokens.scss` is untouched (15.6 owns it).
- `ui/src/main.ts`, `ui/src/app/app.ts` — construct and provide the store as `About` is (`main.ts:198`, `:246`), and reset it on sign-out beside `app.ts:489-492`.
- `ui/tools/system-info.test.mjs` — NEW. `node --test` over `core/system-info.ts`: the late-answer guard, the transport-failure hold, the scope parameter, and an unreported field surfacing as empty rather than absent. Carry the `Mutations (Rule 19)` header.
- `ui/src/app/areas/home/home.page.spec.ts` — the component leg: the fifth block renders with its seven labeled rows; a field the instance did not report keeps its label and shows the not-reported word; a failed read after an answer keeps the answer on screen.
- `ui/browser/home-system-information.browser-spec.mjs` — NEW, against the redeployed bundle on the throwaway: read one state word from the panel and assert it equals what the instance reports; and, at 1,440 px and again at 720 px with all five blocks present, assert the block row wraps (the last block's `offsetTop` exceeds the first's) and `document.documentElement.scrollWidth <= clientWidth`.

**Review patch set (2026-09-20, first review pass) — apply each with the smallest change that does the job:**

- **P1 (HIGH) `src/OcuPilot/Kernel/Shell/SystemInfo.cls` — the `production` member ignores `?ns=`.** Measured on `ocupilot-b-ci`: `GET /api/ocupilot/ui/system?ns=%SYS` answers `production` `"Stopped"` while `##class(%Library.EnsembleMgr).IsEnsembleNamespace("%SYS")` is `0`, so the matrix's *Non-interop namespace* row (which requires `""`) is violated. Cause: `Api/Router.cls` never assigns `$NAMESPACE` — `OnPreDispatch` stashes the resolved scope with `##class(OcuPilot.Kernel.Scope).Set(tNs)` at `:628`, and `Kernel/Scope.cls`'s own header states every handler reads `Current()` rather than `$Namespace`. Fix: resolve the namespace from `##class(OcuPilot.Kernel.Scope).Current()`, falling back to `$NAMESPACE` when the stash is empty (an in-process caller, which the read tests are); evaluate `ProductionEnabled()` against it and run the `Ens.Director` call in it under AD-16 explicit save/restore with the restore as the first line of the `Catch` and before any rethrow. Replace the false sentence in `ProductionState()`'s doc comment, and the same claim where it is repeated in `ui/src/app/core/system-info.ts`'s header and `ui/tools/system-info.test.mjs`'s rationale comment, with what the router actually does. Pin it: a `UiSystemRead` row for a scoped non-interop namespace, and a `UiSystemWire` row asserting `?ns=%SYS` answers 200 with `production` `""` while the request's own namespace answers a word. Record the mutation.
- **P2 (MED) `ui/src/app/areas/home/home.page.ts` — the panel has no error state.** `SystemInfo.failed()` and `answered()` have no production consumer, so an unreachable instance renders seven confident "Not reported" rows — which the store's own header says it avoids and which the matrix's *Read unreachable* row forbids. Fix on the house precedent `ui/src/app/shell/about-dialog.ts:130` (`!answered() && failed()`), rendering the existing `STRINGS.connectivityServerFault` in place of the rows. No new string, so EXPERIENCE.md is untouched. Pin it with a `home.page.spec.ts` row mounting `stubSystemInfo({ unreachable: true })`.
- **P3 (MED) `ui/src/app/areas/home/home.page.spec.ts` — the AD-43 no-timer test cannot fail against a realistic timer.** Its 60 ms real-clock wait passes untouched against any auto-refresh period the product actually uses. Rewrite it on this project's own idiom at `ui/src/app/areas/logs/log-viewer.spec.ts:196`: `vi.useFakeTimers()`, `await vi.advanceTimersByTimeAsync(10 * 60 * 1000)`, assert both the call count unchanged and `vi.getTimerCount() === 0`, restoring real timers in a `finally`. Re-record AC5's `mutation:` line against a 10 s interval.
- **P4 (MED) `src/OcuPilot/Test/UiSystemRead.cls` — the four alert-word assertions test the code against itself.** `TestTheCarriedValuesAreTheInstancesOwn` compares `Payload()`'s values against a second `SystemInfo.Dashboard()` call, so swapping two property-to-member mappings inside `SampleDashboard` moves both sides together and stays green. Assert the four against the vendor object's own properties instead, from one `SYS.Stats.Dashboard.Sample()` the test takes in `%SYS` itself.
- **P5 (MED) `src/OcuPilot/Kernel/Shell/SystemInfo.cls` — an unrecognized production state reaches the panel as a diagnostic token.** `Ens.Config.Production.ProductionStateToText` has no arm for `eProductionStateNetworkStopped` (5), `eProductionStateShardWorkerProhibited` (6) or `eProductionStateBackupNetworkStopped` (-5) and falls through to `"Unrecognized:"_pState`; `Ens.Director.GetProductionStatus` reaches 5 on its `$$$EnsRuntime("System")` branch. Degrade such an answer to `""` so the row shows its not-reported word rather than publishing a token, and say so at the method. This needs a `ProductionStatus()` seam mirroring `MirrorStatus()` (production never overrides it) so both this branch and the `$$$ISERR` degrade branch are reachable from `OcuPilot.Test.UiSystemFixture`; add the fixture override and one `UiSystemRead` row for each.
- **P6 (LOW) `src/OcuPilot/Test/UiSystemRead.cls` — the production `LogSourceFailure` body never executes.** Every case goes through the fixture's override, so the `Try`/`Catch` that keeps a degraded member from becoming a 500 is unrun. Add one row calling `##class(OcuPilot.Kernel.Shell.SystemInfo).LogSourceFailure(...)` directly, modeled on `src/OcuPilot/Test/Instance.cls:356`.
- **P7 (LOW) `src/OcuPilot/Test/UiSystemRead.cls` — `TestARefusedDashboardSampleDegradesItsFiveMembersAndLogsOnce` asserts the log count but not the name.** Changing the logged argument to a member name keeps the count at 1 and stays green; assert `SourceLogged()` is `"dashboard"`.
- **P8 (LOW) `src/OcuPilot/Test/UiSystemRead.cls` — a doc comment records a mutation that cannot redden its test.** `UiSystemFixture.SampleDashboard` calls `##super` and then overwrites `uptime`, so a transformation applied inside `SampleDashboard` is discarded before the armed assertion runs. Replace the wrong sentence with the right one; do not append a correction to it.
- **P9 (LOW) `ui/browser/about-help-links.browser-spec.mjs` — the repaired selector dereferences a possibly-undefined block.** A renamed heading surfaces as an in-page TypeError rather than naming the missing block; assert the block was found first.
- **P10 (LOW) `ui/src/app/areas/home/home.page.spec.ts` — the new rows select the panel as `fixedBlocks()[2]`,** reintroducing the positional idiom this same change had to repair in the browser spec. Select by heading, as `ui/browser/preferences-integration.browser-spec.mjs:114` does.

**Acceptance Criteria:**

- Given Home, when the panel renders, then it shows uptime, mirror state, the database, journal, lock and write-daemon state words and production status, each labeled and each carrying its word, so color is never the only signal.
- Given Home with all five blocks present, when the viewport is 1,440 px and again at the 720 px 200%-zoom floor, then the block row wraps rather than widening, Home does not scroll horizontally, and no block is hidden by width.
- **Integration AC (Rule 1):** Given an instance whose dashboard reports a state word for the write daemon, when Home renders against the deployed bundle, then that same word appears in the panel's write-daemon row — the new route, the new store and the panel observed end to end in the browser tier, not by inspecting the handler.
- Given About declines uptime and mirror state to this story, when the panel renders, then both are present on Home, so the product reports each exactly once.
- Given the panel, when Home stays open, then no auto-refresh timer runs: it settles with its own read and Home stays absent from AD-43's roster.

## Spec Change Log

- 2026-09-20 (lead, spec gate): restructured `## Verification` into owner Rule 29's shape (targeted commands marked `(loop)`, the full ObjectScript sweep and full browser suite marked `(once, before dev_complete)`). The rule landed at `686acf4` after this spec was planned; the substance of the verification is unchanged and both full runs are retained.

## Review Triage Log

### 2026-09-20 — Review pass

- verdicts: 40 findings — high 1, medium 13, low 25, false 1, maybe-false 0
- findings:
  - `[medium]` `[patch]` Blind Hunter: the panel has no error state though the matrix's *Read unreachable* row requires one — verified: `failed()`/`answered()` had no production consumer, so an unreachable instance rendered seven "Not reported" rows. P2 adopted `about-dialog.ts:130`'s `!answered() && failed()` shape over the existing `connectivityServerFault`.
  - `[medium]` `[patch]` Blind Hunter: a failed read and "the instance reported nothing" are indistinguishable, and no component case covers a first read that fails — same root cause; P2 plus a new `home.page.spec.ts` row.
  - `[medium]` `[patch]` Blind Hunter: the AD-43 no-timer test's 60 ms real-clock wait cannot fail against a realistic timer — verified; P3 rewrote it on `log-viewer.spec.ts:196`'s fake-timer idiom, and it reddens at a 10 s interval.
  - `[low]` `[patch]` Blind Hunter: a doc comment records an uptime mutation the fixture discards — verified: `UiSystemFixture.SampleDashboard` overwrites after `##super`. P8 replaced the sentence.
  - `[medium]` `[patch]` Blind Hunter: the four alert-word assertions compare `Payload()` against `Dashboard()`, the same path — verified; P4 asserts against `SYS.Stats.Dashboard`'s own properties.
  - `[medium]` `[patch]` Blind Hunter: `ProductionStateToText` has no arm for states 5, 6 and -5 and falls through to `Unrecognized:<n>` — verified against `irislib/%syInterop.inc:13` and `Ens/Config/Production.cls:263`. P5 degrades such an answer to `""`.
  - `[low]` `[reject]` Blind Hunter: the mirror vocabulary is not closed — the code renders whatever word the accessor returns, which is the intent; the overstatement is in this build's spec, and a finding whose fix edits it is rejected.
  - `[false]` Blind Hunter: hard `##class()` references to `Ens.Director` in a namespace that may not carry it — `ProductionEnabled()` returns before either reference is evaluated, and a compiled reference resolves only when its line runs.
  - `[low]` `[reject]` Blind Hunter: the production read's lock parameters differ between code and test — P5's `ProductionStatus()` seam now owns them in one place; asserting the literals would pin an implementation detail, not behavior.
  - `[low]` `[reject]` Blind Hunter: "Database" and "Journal" drop the vendor property's "space" — the labels are ratified in EXPERIENCE.md's Fixed strings table; changing them is a product call, and the fix edits this build's published row.
  - `[low]` `[reject]` Blind Hunter: `title` is a mouse-only affordance and is set unconditionally — it mirrors Home's existing block idiom; a second affordance is more than a direct correction.
  - `[low]` `[reject]` Blind Hunter: the row's fixed height clips on a text-only resize — `_components.scss` uses `height: var(--ocu-control-height)` in 13 places and `min-height` in none, so this story followed the codebase; recorded as deferred rather than changed here alone.
  - `[low]` `[patch]` Blind Hunter: `home.page.spec.ts` selects the panel positionally — P10 selects by heading.
  - `[low]` `[patch]` Blind Hunter: the repaired browser spec dereferences a possibly-undefined block — P9 asserts it was found first.
  - `[low]` `[patch]` Blind Hunter: AC4's "exactly once" half is untested — a new `UiSystemRead` row pins that About still declines both members; mutation applied and observed red.
  - `[low]` `[defer]` Blind Hunter: the handler's two `Error.RenderInternal` paths are unexercised — the same gap as Story 15.3's `UiAbout`; closing it needs a seam neither class has.
  - `[low]` `[patch]` Blind Hunter: the production `LogSourceFailure` body never runs — P6 calls it directly, on `Test/Instance.cls:357`'s shape.
  - `[low]` `[reject]` Blind Hunter: AC2's 1,440 px leg over-constrains the layout — the AC names both widths; a change that fits five blocks on one line is a deliberate design change that should update the test.
  - `[low]` `[patch]` Blind Hunter: files touched but not declared under the spec's Rule 11 block — the declaration now names every one, including the modified shared-create browser spec.
  - `[low]` `[patch]` Blind Hunter: `UiSystemFixture.cls` is absent from the Execution list — same root cause; named in the declaration.
  - `[low]` `[reject]` Blind Hunter: no refresh affordance or "as of" stamp — spec-bound: AD-43 closes the auto-refresh roster and the ACs name no control.
  - `[low]` `[reject]` Blind Hunter: the panel's name is spelled two ways — the rendered string is ratified as "System information"; capitalizing it as a proper noun in prose is not a defect.
  - `[low]` `[reject]` Blind Hunter: `stubSystemInfo.setFields` accepts unknown field names — a typo'd member fails the assertion it was arranging; a guard is added complexity for no reachable harm.
  - `[low]` `[reject]` Edge Case Hunter: `Sample()` answering a non-object blanks five members without logging — no path was shown by which the vendor returns a non-object instead of raising.
  - `[medium]` `[patch]` Edge Case Hunter: unrecognized production states reach the panel as a token — grouped with the Blind Hunter row; P5.
  - `[low]` `[patch]` Edge Case Hunter: `about-help-links`'s `find()` is dereferenced unguarded — grouped; P9.
  - `[medium]` `[patch]` Edge Case Hunter: the panel has no error state (claim, high confidence) — grouped; P2.
  - `[medium]` `[patch]` Verification Gap: AC5's no-timer test proves nothing against a realistic period — grouped; P3.
  - `[medium]` `[patch]` Verification Gap: `failed()` has no consumer and nothing asserts an error state — grouped; P2.
  - `[low]` `[patch]` Verification Gap: the production `LogSourceFailure` body never executes — grouped; P6.
  - `[medium]` `[patch]` Verification Gap: the production member's failure branch is unreachable, the fixture having no seam for it — verified; P5 added `ProductionStatus()` and a row for each branch.
  - `[low]` `[patch]` Verification Gap: AC1's recorded mutation does not exercise its client half — a second mutation is now recorded: swapping two `SYSTEM_INFO_LABELS` entries reddens the label row (1 failed, 40 passed).
  - `[low]` `[reject]` Verification Gap: the browser spec's `row.value !== ''` is near-tautological — it does catch a missing value element, and the row's real guard is the write-daemon equality above it.
  - `[low]` `[patch]` Verification Gap: the dashboard sample's log name is unasserted — P7 asserts `SourceLogged()` is `"dashboard"`.
  - `[medium]` `[patch]` Verification Gap: `system-info.ts`'s error-state sentence is false as shipped — P2 makes it true.
  - `[medium]` `[patch]` Intent Alignment (A): the unreachable-read expectation lives at the template while the change and its tests live at the store — grouped; P2.
  - `[high]` `[patch]` Intent Alignment (B): the `production` member ignored `?ns=` — **verified independently**: `Api/Router.cls` never assigns `$NAMESPACE` (it stashes the scope at `:628`, and `Kernel/Scope.cls`'s header states handlers read `Current()`), and `GET /ui/system?ns=%SYS` answered `"Stopped"` while `IsEnsembleNamespace("%SYS")` is 0, where the matrix requires `""`. P1 resolves the scope from `Kernel.Scope.Current()` and enters it under AD-16 save/restore; measured after: `?ns=%SYS` → `""`, `?ns=USER` and `?ns=HSCUSTOM` → `Stopped`.
  - `[low]` `[reject]` Intent Alignment (C): the matrix's "the other six answer" against a per-source dashboard degrade — the spec's own Execution bullet chooses one sample per payload for the five; the single-source case is pinned separately.
  - `[medium]` `[defer]` Intent Alignment (D): the 720 px floor holds on load but a live resize leaves ~22 px of horizontal scroll — the overflowing element is `app-panel`, which Epic 5 owns by decision.
  - `[low]` `[patch]` Intent Alignment (E): "same shape" turned out positional, and the repair moved a shared file — grouped with the Blind Hunter rows; P9, P10 and the corrected footprint declaration.


## Design Notes

**Governing ADs (Rule 6):** **AD-5** (shell chrome declares no descriptor; its "a page may issue another built screen's declared read" clause was weighed and declined, below), **AD-36** (the shell-chrome exception to the declared read; the `parts` mechanism weighed), **AD-43** (the roster is closed at seven and Home is not in it), **AD-16** (the `%SYS` switch for `SYS.Stats.Dashboard`), **AD-8** (privilege is the process's at call time; a refused source degrades one field), **AD-44** and **AD-21** (`?ns=` is the router's validated data scope and the only namespace input), **AD-27** (no `%Api.Admin.*` class is named, so containment is untouched). Also binding: AD-11 rule 4, AD-12, AD-19, AD-20, AD-24, AD-39, AD-47. Conventions rows: *REST route ordering*, *Error shape*, *Client asset homes*, *Tests*, *ObjectScript naming*.

**Why a chrome read rather than issuing System usage's declared read.** The epic context names both shapes; the choice is measured. `SystemUsage.cls:72` declares 18 read fields carrying the four alert words and **not** `Dashboard.Status.UpTime`. Adding it edits a screen descriptor, which regenerates `ui/src/app/core/screens.generated.ts` — a file Epic 5 has modified and that `screen-mirror.mjs --check` must find unchanged. The live `DASHBOARDMAIN` payload also carries no mirror key and no production key, so a second source is needed whatever the first is. Issuing the other screen's read would deliver four of the seven fields and put a second failure mode inside one block.

**Three sources, each with its provenance.** `SYS.Stats.Dashboard` is documented and neither `[Internal]` nor `[Hidden]` — better provenance than the two `[Internal]` accessors 15.3 accepted — and is what the vendor's own dashboard endpoint is a view over. Mirror state uses `GetMemberStatus()` rather than `GetStatus()` because the former answers a state word from a closed vocabulary and the latter the raw token `NOTINIT`; neither that word nor the dashboard's `Normal`/`Warning`/`Troubled` is translated. Production state uses `ProductionStateToText(state, 0)`, the vendor's own mapping, so OcuPilot publishes no state vocabulary of its own — only the row labels are new strings.

**Production status is scoped to the request's namespace, deliberately.** Interoperability is per namespace (`IsEnsembleNamespace()` true for `HSCUSTOM` on slot B — a per-namespace fact, not an instance-wide one), and the router resolves and validates `?ns=` and stashes it as the request's scope (`Kernel/Scope.cls`), which this read enters by explicit save and restore, so it needs no new caller input. The classic panel instead enumerates productions across every namespace (`Home.cls:2665-2690`); that is a list, and a list belongs to a declared read under AD-36. *(inference: that the scoped namespace is the one a user reading Home means — the ACs do not say which.)*

**The mirror accessor catches its own errors.** `GetMemberStatus()` returns `$LB("Error", $ZE)` instead of throwing, so the per-field `Try` never fires — the caveat 15.3 measured about vendor accessors that set their own trap. Normalize the leading `Error` element to `""` at the read site, or a failed read renders as a plausible mirror state.

**AC2 pins behavior that already exists.** `.ocu-home-remembered` is already a wrapping flex row and `.ocu-home-block` already carries `min-width: 0`, so a fifth block wraps without a new rule. The risk AC2 guards is a regression, and jsdom computes no layout, so it belongs in the browser tier; no existing browser spec asserts Home's block row wraps.

**Ledger inbox (Rule 17):** `ledger.sh slice 15-4-home-s-system-information-panel` is **empty** — this story owns no ledger entries, so there is nothing to address or decline.

**Contended and out-of-footprint paths, declared (Rule 11).** Shared-append, epic-wide grant: `src/OcuPilot/Api/Router.cls`, `ui/src/app/core/strings.ts`, `ui/src/styles/_components.scss`, and EXPERIENCE.md's Fixed strings table after `:383`. Shared-create: `src/OcuPilot/Test/UiSystemRead.cls`, `UiSystemWire.cls`, `ui/src/app/core/system-info.ts`, `ui/browser/home-system-information.browser-spec.mjs`. In Epic 15's own footprint: `src/OcuPilot/Api/UiSystem.cls` (`Api/Ui*.cls`), `ui/src/styles/**`. **To be reported under `footprint_extensions:`** — `src/OcuPilot/Kernel/Shell/SystemInfo.cls` (new), `src/OcuPilot/Test/UiSystemFixture.cls` (new, the seam the two test classes share), `src/OcuPilot/Test/EndpointCoverage.cls`, `ui/src/app/areas/home/home.page.ts` (+ spec), `ui/src/main.ts`, `ui/src/app/app.ts` (+ `app.spec.ts`, `app.wire.spec.ts`, `app.gate-outlet.wire.spec.ts`), `ui/src/app/shell/screen-outlet.spec.ts`, `ui/src/app/testing/system-info.ts` (new), `ui/tools/system-info.test.mjs`. The four `*.spec.ts` files and `screen-outlet.spec.ts` are touched only to provide the new store to a `TestBed` that injects it; none is on a contended path. **One existing shared-create file was modified** — `ui/browser/about-help-links.browser-spec.mjs`, which selected Home's Links block as the last `.ocu-home-block-fixed` and stopped finding it once a fifth block landed; it now selects by heading, as `ui/browser/preferences-integration.browser-spec.mjs:114` does. It was created by this epic's own Story 15.3 and Epic 5 has never touched it (`git log`, and Epic 5's branch diff), so it is this epic's file rather than a contended one — reported for the lead to ratify. None is on Epic 5's carve list (`shell/panel*`, `proposal-card*`, `reply*`, `tool-call-card*`, `core/proposal-view.ts`, `core/turn.ts`), and `core/` files Epic 5 has modified (`agent-status.ts`, `navigation.ts`, `proposal-view.ts`, `screens.generated.ts`, `suggested-view.ts`, `turn.ts`) are read-only here.

**Consumes:** `ui/src/app/core/api.ts` (`requestJson`, its scope parameter `:407-415`); `OcuPilot.Kernel.Shell.About`'s `ReadSource` idiom; `OcuPilot.Api.Response` / `Error.RenderInternal`; `Api/Router.cls`'s resolved namespace.

**Consumed-by:** No further consumer in this epic — Story 15.5 extends the `Pref` store and `/account/preferences`, not this route, and 15.6 is deferred. The panel itself is this read's first and only consumer, which is what the Integration AC exercises.

## Verification

**Slot B.** Every IRIS MCP call carries `server: "ocupilot-slot-b"`; the dev container is `ocupilot-slot-b`. Anything that mutates shared runtime state — the new route's wire test, the browser spec — runs on the **throwaway** `bash scripts/ci-throwaway.sh up --dir /tmp/ocupilot-b-ci --project ocupilot-b-ci --web 52777 --super 1976`, torn down only by whoever ran its `up`. A browser run exports both `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777` and `OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci`. Stateful tests run **one class or suite per tool call**, waiting for each to land in `%UnitTest_Result` before the next.

**Commands.** Rule 29 shape: the targeted commands run in the implement loop; the two full runs happen **once**, at the end of the implement stage before `dev_complete`, and again at the lead's smoke gate and in CI.

**Targeted `(loop)`** — run these while implementing, patching and on every rework pass:

- `uv run scripts/check-objectscript.py` — expected: green, including `check_route_ordering` over the appended route and `check_handler_wire_tests` finding `Test/UiSystemWire.cls`.
- `cd ui && npm test` — expected: `node --test tools/*.test.mjs` green including the new `system-info.test.mjs`, and `strings.test.mjs` passing inside the unchanged `150..600` band; then the Angular runner green including the Home leg.
- `cd ui && npm run build` — expected: all six `prebuild` checkers pass. **`screen-mirror.mjs --check` must be green with no regeneration**, which is the evidence that no descriptor was touched. `client-lint.mjs` is the one that bites: one interpolation per plain `aria-label`, `[attr.aria-label]` for a composed name, `\uXXXX` for non-ASCII, no hardcoded color.
- `bash scripts/lint-docs.sh` — expected: green over the appended EXPERIENCE.md row.
- `(loop)` Compile through the IRIS MCP tools against `ocupilot-slot-b`, then run `OcuPilot.Test.UiSystemRead` and `OcuPilot.Test.UiSystemWire` **by name, one class per call** — the two classes this story adds.
- `(loop)` `cd ui && node --test --test-concurrency=1 browser/home-system-information.browser-spec.mjs` with `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777` and `OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci`, after a rebuild and redeploy — the one browser spec this story adds.
- `bash scripts/smoke.sh --container ocupilot-slot-b --user _SYSTEM --password SYS` — expected: non-zero executed checks, all passing.

**Full `(once, before dev_complete)`** — both run once at the end of the implement stage, and again at the lead's smoke gate and in CI, which is where a regression outside this story's own files is caught. Omitting them is a misreading of Rule 29:

- `(once)` the **full ObjectScript sweep** over `OcuPilot.Test.*`, one class per call.
- `(once)` `cd ui && npm run build`, `docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`, then the **full** `npm run test:browser` — expected green including `home-system-information.browser-spec.mjs`. **Expect the inherited DW-1169 flake to appear here for the first time**, because it lives in `context-chip.browser-spec.mjs` and `switches.browser-spec.mjs`, which no Epic 15 story touches and which targeted mode therefore never runs: a failure confined to those two is inherited, not this story's. **The output directory is `dist/ocupilot-ui`** (`ui/angular.json`); a browser result read before the rebuild and redeploy is not evidence.

**Mutations (Rule 19)** — one per AC, each applied, observed red, reverted, and the tree confirmed byte-identical; record each as `mutation: <change> -> <test that went red>` here:

- AC1 — `mutation: drop "writeDaemon" from Kernel/Shell/SystemInfo.Members, recompile the package -> OcuPilot.Test.UiSystemWire 2/3 red ("the body carries writeDaemon", "the write daemon publishes only two")`. The client half is a second mutation, because `ui/src/app/core/system-info.ts`'s `SYSTEM_INFO_FIELDS` is an independent list: `mutation: swap the uptime and mirror entries in home.page.ts SYSTEM_INFO_LABELS -> home.page.spec.ts "the System Information panel is a fifth block of seven labeled rows" red at the label list (1 failed, 40 passed)`.
- AC2 — `mutation: remove flex-wrap: wrap from .ocu-home-remembered, rebuild, redeploy -> home-system-information.browser-spec.mjs red at 1440px (firstTop 203 = lastTop 203, so the row widened instead of wrapping)`.
- Integration AC — `mutation: make SystemInfo.load() store the fixed word "Troubled" rather than the answered body, rebuild, redeploy -> home-system-information.browser-spec.mjs red on the write-daemon row`. Measured: a first attempt with `'Normal'` reddened only the uptime assertion, because `Normal` is what this instance's write daemon actually reports — the mutation has to name a word the instance does not.
- AC4 — `mutation: answer the mirror member from %SYSTEM.Mirror.GetStatus() instead of GetMemberStatus() -> OcuPilot.Test.UiSystemRead red (the raw token is not a $List and carries no word, so the mirror assertions fail)`. The AC's "exactly once" half is a second mutation: `mutation: add "uptime" to Kernel/Shell/About.Members, recompile -> UiSystemRead.TestUptimeAndMirrorAreReportedOnceAcrossTheTwoChromeReads red ("About declines the uptime")`.
- AC5 — `mutation: give the panel a setInterval(load, 10s) -> home.page.spec.ts "the panel settles with its own read and starts no timer" red (62 reads against 1 over ten minutes of fake time)`. The row installs the fake clock **before** the component is constructed; installed afterwards it cannot see a timer the constructor registered, which is what the 60 ms real-clock form could not catch.

**Review patch set mutations (2026-09-20)** — each applied, observed red, reverted, the tree confirmed byte-identical:

- P1 — `mutation: answer SystemInfo.ProductionEnabled from $NAMESPACE instead of OcuPilot.Kernel.Scope.Current, recompile the class and every descendant -> UiSystemRead.TestTheProductionMemberFollowsTheRequestsScope red (<CLASS DOES NOT EXIST> *Ens.Director, the scoped read entering %SYS)`. Measured over the wire on `ocupilot-b-ci`: `?ns=%25SYS` now answers `production` `""` while the unscoped call answers `Stopped`.
- P2 — `mutation: drop the @if (systemUnanswered) branch from the panel -> home.page.spec.ts "a panel whose read has never answered shows the fault" red`.
- P4 — `mutation: answer "databaseSpace" from the literal "Warning" in SystemInfo.SampleDashboard -> UiSystemRead.TestTheCarriedValuesAreTheInstancesOwn red`. The old self-comparing form stayed green under it, which is the finding. (Swapping the journal and lock mappings cannot redden anything on a healthy container: both report `Normal`.)
- P5 — `mutation: remove the PRODUCTIONUNRECOGNIZED degrade from SystemInfo.ProductionState -> UiSystemRead.TestAnUnrecognizedProductionStateIsNotPublishedAsAToken red`.
- P6 — `mutation: delete the Try from SystemInfo.LogSourceFailure -> UiSystemRead.TestTheProductionLogSeamRunsAndSwallowsItsOwnFailure red`.
- P7 — `mutation: log "uptime" rather than DASHBOARDSOURCE in SystemInfo.Dashboard's Catch -> UiSystemRead.TestARefusedDashboardSampleDegradesItsFiveMembersAndLogsOnce red on the name (the count stays 1)`.
- P8 — the doc comment now names the mutation that can redden it: `reformat the uptime in SystemInfo.ReadSource ($ZStrip(<value>, "*W")) -> UiSystemRead.TestTheCarriedValuesAreTheInstancesOwn red at the armed assertion`. Applied and observed; the sentence it replaced named `SampleDashboard`, whose result the fixture overwrites.
- P3, P9, P10 are the tests' own shape rather than new coverage: P3's is AC5's line above, and P9 and P10 replace a positional or unguarded selector with a by-heading one.

A single-file `npx vitest run` cannot host a client mutation: the Angular `@angular/build:unit-test` builder supplies the test environment, so a bare vitest invocation fails on `Cannot read properties of null (reading 'ngModule')`. Use `npx ng test --include <spec>`.

**Manual checks:**

- Open Home on an instance whose dashboard reports a non-`Normal` state and confirm the word, not only the color, changes.

## Auto Run Result

Status: done
Blocking condition: none

**What this pass built.** `GET /api/ocupilot/ui/system` as `Kernel/Shell/SystemInfo` (payload) plus `Api/UiSystem` (thin handler), copying Story 15.3's `About` seam: seven scalars from three in-process sources, each member behind its own `Try` so a refused source degrades that member to `""` and logs. One `SYS.Stats.Dashboard.Sample()` per payload serves five of them inside a single `%SYS` save/restore (AD-16); the mirror accessor's `$LB("Error", ...)` answer is normalized to `""`; production answers the vendor's own English word for the **request's scoped namespace**. Home renders a fifth `ocu-home-block-fixed` of seven labeled rows, each carrying its word, with no timer (AD-43). New: one route, one probe row, three test classes, a framework-free `core/system-info.ts` store, one browser spec, one EXPERIENCE.md Fixed-strings row and seven `strings.ts` keys.

**Files changed.** `Kernel/Shell/SystemInfo.cls`, `Api/UiSystem.cls`, `Api/Router.cls` (tail route + wrapper), `Test/EndpointCoverage.cls` (one probe row), `Test/UiSystemRead.cls`, `Test/UiSystemWire.cls`, `Test/UiSystemFixture.cls`; `ui/src/app/core/system-info.ts`, `ui/src/app/testing/system-info.ts`, `ui/src/app/areas/home/home.page.ts` (+ spec), `ui/src/app/core/strings.ts`, `ui/src/styles/_components.scss`, `ui/src/main.ts`, `ui/src/app/app.ts` (+ three wire specs), `ui/src/app/shell/screen-outlet.spec.ts`, `ui/tools/system-info.test.mjs`, `ui/browser/home-system-information.browser-spec.mjs`, `ui/browser/about-help-links.browser-spec.mjs`, EXPERIENCE.md `:384`.

**Review.** 40 findings over four layers: 1 high, 13 medium, 25 low, 1 false. Twelve entries patched in-pass (1 high, 5 medium, 6 low), one medium and five low deferred to frontmatter, the rest rejected with their reasons in the triage log. The high: the `production` member read `$NAMESPACE` on a premise that does not hold — the router stashes the resolved scope rather than switching — so it answered for the install namespace whatever `?ns=` asked for; it now resolves `Kernel.Scope.Current()` and enters it under AD-16.

**Verification.** `check-objectscript` 518 files / 21 rules / 0 problems; `lint-docs` 98 files / 0 issues; `npm run build` with all six prebuild checkers and **`screen-mirror --check` up to date with no regeneration**; `npm test` 1,182 `node --test` + 723 component. Instance (`ocupilot-slot-b`): `UiSystemRead` 15/15 and `UiSystemWire` 4/4 by name, and the **full sweep** at run 477 — 1,023 tests over 101 classes, 1,022 passed, confirmed against `%UnitTest_Result`. The one failure is environmental and predates this story: `EndpointCoverage.TestEveryProbeDispatchesToItsRoute`'s two `Api.StaticHandler` rows answer 503 because slot B's dev container serves no client bundle; the gate a new route needs, `TestEveryRouteHasAProbeAndEveryProbeHasARoute`, passes. **Full browser suite** against a freshly recreated `ocupilot-b-ci` serving this tree's bundle: **198/199**, the sole failure DW-1169's `context-chip.browser-spec.mjs` "Cap follows agent-switch", whose repair is unmerged on Epic 5's branch and which passed on the next run. All twelve Rule 19 mutations applied, observed red, reverted, tree confirmed byte-identical.

**Residual risk.** The scoped production read is measured across three namespace shapes — non-interop, the install namespace and a second interop namespace — but on a throwaway where no namespace runs a production, so all three answer `Stopped` or `""`. That the read reports *a different namespace's running* production is inferred from the switch, not observed. `followup_review_recommended` is `true` on that ground alone.
