---
title: "Story 15.4: Home's System Information panel"
type: 'feature'
created: '2026-09-20'
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

**Acceptance Criteria:**

- Given Home, when the panel renders, then it shows uptime, mirror state, the database, journal, lock and write-daemon state words and production status, each labeled and each carrying its word, so color is never the only signal.
- Given Home with all five blocks present, when the viewport is 1,440 px and again at the 720 px 200%-zoom floor, then the block row wraps rather than widening, Home does not scroll horizontally, and no block is hidden by width.
- **Integration AC (Rule 1):** Given an instance whose dashboard reports a state word for the write daemon, when Home renders against the deployed bundle, then that same word appears in the panel's write-daemon row — the new route, the new store and the panel observed end to end in the browser tier, not by inspecting the handler.
- Given About declines uptime and mirror state to this story, when the panel renders, then both are present on Home, so the product reports each exactly once.
- Given the panel, when Home stays open, then no auto-refresh timer runs: it settles with its own read and Home stays absent from AD-43's roster.

## Spec Change Log

- 2026-09-20 (lead, spec gate): restructured `## Verification` into owner Rule 29's shape (targeted commands marked `(loop)`, the full ObjectScript sweep and full browser suite marked `(once, before dev_complete)`). The rule landed at `686acf4` after this spec was planned; the substance of the verification is unchanged and both full runs are retained.

## Review Triage Log

## Design Notes

**Governing ADs (Rule 6):** **AD-5** (shell chrome declares no descriptor; its "a page may issue another built screen's declared read" clause was weighed and declined, below), **AD-36** (the shell-chrome exception to the declared read; the `parts` mechanism weighed), **AD-43** (the roster is closed at seven and Home is not in it), **AD-16** (the `%SYS` switch for `SYS.Stats.Dashboard`), **AD-8** (privilege is the process's at call time; a refused source degrades one field), **AD-44** and **AD-21** (`?ns=` is the router's validated data scope and the only namespace input), **AD-27** (no `%Api.Admin.*` class is named, so containment is untouched). Also binding: AD-11 rule 4, AD-12, AD-19, AD-20, AD-24, AD-39, AD-47. Conventions rows: *REST route ordering*, *Error shape*, *Client asset homes*, *Tests*, *ObjectScript naming*.

**Why a chrome read rather than issuing System usage's declared read.** The epic context names both shapes; the choice is measured. `SystemUsage.cls:72` declares 18 read fields carrying the four alert words and **not** `Dashboard.Status.UpTime`. Adding it edits a screen descriptor, which regenerates `ui/src/app/core/screens.generated.ts` — a file Epic 5 has modified and that `screen-mirror.mjs --check` must find unchanged. The live `DASHBOARDMAIN` payload also carries no mirror key and no production key, so a second source is needed whatever the first is. Issuing the other screen's read would deliver four of the seven fields and put a second failure mode inside one block.

**Three sources, each with its provenance.** `SYS.Stats.Dashboard` is documented and neither `[Internal]` nor `[Hidden]` — better provenance than the two `[Internal]` accessors 15.3 accepted — and is what the vendor's own dashboard endpoint is a view over. Mirror state uses `GetMemberStatus()` rather than `GetStatus()` because the former answers a state word from a closed vocabulary and the latter the raw token `NOTINIT`; neither that word nor the dashboard's `Normal`/`Warning`/`Troubled` is translated. Production state uses `ProductionStateToText(state, 0)`, the vendor's own mapping, so OcuPilot publishes no state vocabulary of its own — only the row labels are new strings.

**Production status is scoped to the request's namespace, deliberately.** Interoperability is per namespace (`IsEnsembleNamespace()` true for `HSCUSTOM` on slot B — a per-namespace fact, not an instance-wide one), and the router resolves, validates and switches to `?ns=` before a handler runs, so `Ens.Director` in `$NAMESPACE` needs no new plumbing and no new caller input. The classic panel instead enumerates productions across every namespace (`Home.cls:2665-2690`); that is a list, and a list belongs to a declared read under AD-36. *(inference: that the scoped namespace is the one a user reading Home means — the ACs do not say which.)*

**The mirror accessor catches its own errors.** `GetMemberStatus()` returns `$LB("Error", $ZE)` instead of throwing, so the per-field `Try` never fires — the caveat 15.3 measured about vendor accessors that set their own trap. Normalize the leading `Error` element to `""` at the read site, or a failed read renders as a plausible mirror state.

**AC2 pins behavior that already exists.** `.ocu-home-remembered` is already a wrapping flex row and `.ocu-home-block` already carries `min-width: 0`, so a fifth block wraps without a new rule. The risk AC2 guards is a regression, and jsdom computes no layout, so it belongs in the browser tier; no existing browser spec asserts Home's block row wraps.

**Ledger inbox (Rule 17):** `ledger.sh slice 15-4-home-s-system-information-panel` is **empty** — this story owns no ledger entries, so there is nothing to address or decline.

**Contended and out-of-footprint paths, declared (Rule 11).** Shared-append, epic-wide grant: `src/OcuPilot/Api/Router.cls`, `ui/src/app/core/strings.ts`, `ui/src/styles/_components.scss`, and EXPERIENCE.md's Fixed strings table after `:383`. Shared-create: `src/OcuPilot/Test/UiSystemRead.cls`, `UiSystemWire.cls`, `ui/src/app/core/system-info.ts`, `ui/browser/home-system-information.browser-spec.mjs`. In Epic 15's own footprint: `src/OcuPilot/Api/UiSystem.cls` (`Api/Ui*.cls`), `ui/src/styles/**`. **To be reported under `footprint_extensions:`** — `src/OcuPilot/Kernel/Shell/SystemInfo.cls` (new), `src/OcuPilot/Test/EndpointCoverage.cls`, `ui/src/app/areas/home/home.page.ts` (+ spec), `ui/src/main.ts`, `ui/src/app/app.ts`, `ui/tools/system-info.test.mjs`. None is on Epic 5's carve list (`shell/panel*`, `proposal-card*`, `reply*`, `tool-call-card*`, `core/proposal-view.ts`, `core/turn.ts`), and `core/` files Epic 5 has modified (`agent-status.ts`, `navigation.ts`, `proposal-view.ts`, `screens.generated.ts`, `suggested-view.ts`, `turn.ts`) are read-only here.

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

- AC1 — drop one member from `Kernel/Shell/SystemInfo.Members`, recompile the class and every descendant → `OcuPilot.Test.UiSystemWire`.
- AC2 — remove `flex-wrap: wrap` from `.ocu-home-remembered`, rebuild, redeploy → `home-system-information.browser-spec.mjs`.
- Integration AC — make the store's `load()` return a fixed word rather than the instance's, rebuild, redeploy → `home-system-information.browser-spec.mjs`.
- AC4 — make `Kernel/Shell/SystemInfo` answer the mirror field from `GetStatus()` instead → `OcuPilot.Test.UiSystemRead`.
- AC5 — give the panel a timer that re-issues `load()` → `home.page.spec.ts`.

A single-file `npx vitest run` cannot host a client mutation: the Angular `@angular/build:unit-test` builder supplies the test environment, so a bare vitest invocation fails on `Cannot read properties of null (reading 'ngModule')`. Use `npx ng test --include <spec>`.

**Manual checks:**

- Open Home on an instance whose dashboard reports a non-`Normal` state and confirm the word, not only the color, changes.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none
