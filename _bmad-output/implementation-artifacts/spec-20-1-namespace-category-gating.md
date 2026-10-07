---
title: 'Story 20.1: Namespace category gating'
type: 'feature'
created: '2026-10-06'
status: 'draft'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md'
warnings: [multiple-goals, oversized]
deferred: []
---

<intent-contract>

## Intent

**Problem:** Stage 4 adds two rail categories, Interoperability and Analytics, that belong only in namespaces whose own features support them. Today the rail has neither category and nothing reads a namespace's features. The Interoperability event log also admits a holder of `%Ens_EventLog:USE` whom the classic page refuses for lacking `%Ens_Portal:USE` (DW-1921).

**Approach:** Declare the two areas with a closed `appliesWhen` feature. On every navigation read, ask the vendor whether the route's namespace reports that feature, and carry the answer as `applies` on every area of the map. Draw no surface of a category that does not apply. The sign-in hand-off is not this story's: the orchestrator's merge gate split it into Story 20.13 on 2026-10-07, and its design awaits the owner (DW-2141).

## Boundaries & Constraints

**Always:**

- Applicability is not a privilege gate. A category that applies but that the caller cannot open stays drawn, unavailable, naming its pair (AD-8; EXPERIENCE.md "Gated controls are never hidden" still holds).
- The map is never partial: every area carries `applies` and its verdict.
- Fail closed: a category declaring `appliesWhen` is not drawn until the map read for the current namespace answers `applies: true`. A vendor check that throws, or a feature outside the vocabulary, answers `false`.
- Feature reads pass the namespace as an argument. They switch no namespace and escalate nothing (AD-16, AD-9). `%SYS` and implied (`^`) namespaces never apply to analytics.
- Edits to files Epic 18 is changing are add-only, except those named under Design Notes, which the orchestrator cleared at its merge gate on 2026-10-07; whichever epic merges second takes the union and regenerates `screens.generated.ts` with `ui/tools/screen-mirror.mjs`.
- The API floor stays as it is (DW-2140 is with the owner). An Interoperability or Analytics surface declares its classic page's gate (for example `%Ens_Portal:USE`) as its own pair from the start, so a later floor change touches only pre-existing surfaces (orchestrator ruling 2026-10-07).

**Never:**

- No vendor frame, link or window in the buildable half.
- No `postMessage`, no vendor storage key written.
- No change to the token store, the shell's CSP, or cross-tab behavior (AD-28, AD-47).
- No change to the API floor (`Screen.Gate` `ADMINRESOURCES`/`FloorResources`).
- No new port, write tool, governance key or error code.
- No applicability computed in the client, and no category hidden for lack of a privilege.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Interop-only namespace | `?ns=HSCUSTOM` on `ocupilot-b-ci` (interop 1, analytics 0, measured) | Interoperability drawn on the rail, Home tile and command box. Analytics drawn nowhere. | No error expected |
| Neither feature | `?ns=%SYS` | Neither category drawn. Every other area unchanged. | No error expected |
| Both features | a namespace both report (HSSYS or HSLIB on IRIS for Health, measured) | Both drawn. | No error expected |
| Before the map answers | first paint, or a switch in flight | Neither category drawn. Other areas drawn ungated, as today. | No error expected |
| Namespace switch | HSCUSTOM → %SYS while the side bar shows Interoperability | Map re-read. Interoperability leaves the rail, Home, command box, locator and side bar, and the open side bar closes. | No error expected |
| Applies, privilege lacking | HSCUSTOM, caller without `%Ens_Portal:USE` | Interoperability drawn, unavailable, naming `%Ens_Portal:USE`. | No error expected |
| Interop enabled meanwhile | Story 18.15's Enable interoperability confirmed on the current namespace | Its `namespace` change event re-reads the map, and the category appears without a reload. | No error expected |
| Vendor check fails | `%IsDeepSeeEnabled` or `IsEnsembleNamespace` throws, or `appliesWhen` holds an unknown value | `applies: false`. | Logged once; never a 500, never a missing area |
| Agent's map | `shell.privileges.read` | Each area carries the same `applies` the route answers. | Closed schema refuses a missing `applies` |
| DW-1921: one pair | holder of `%Ens_EventLog:USE` and the namespace database READ, without `%Ens_Portal:USE` | Event log screen refused, naming `%Ens_Portal:USE`. The hub lists the source not shown with that pair. | 403 per AD-8 |
| DW-1921: both pairs | holder of `%Ens_EventLog:USE` and `%Ens_Portal:USE` | Reads as before. | No error expected |
| DW-1921: neither pair | caller lacking both | Still named `%Ens_EventLog:USE` (listed first). | 403 per AD-8 |

</intent-contract>

## Code Map

### Server

- `src/OcuPilot/Screen/Area.cls:72-84`: XData `Areas`, nine entries; doc comment says "nine" (`:1`, `:69`). Template is Story 19.1's commit `cbf70b07`, which added System Explorer.
- `src/OcuPilot/Screen/Gate.cls`:
  - `:45` `ADMINRESOURCES`, and `:305` `FloorResources()`, which this story does not change.
  - `:119-140` `EvaluateArea`: an area with no listed screen is answered by its declared set alone (`:132-135`).
- `src/OcuPilot/Screen/Registry.cls:3619-3650` `Roster`: copies each area's fields. Nothing validates the area list today.
- `src/OcuPilot/Kernel/Shell/Navigation.cls:20-58` `Payload`: reads no scope today. The "never a partial list" contract is at `:13-15`.
- `src/OcuPilot/Kernel/Scope.cls:36` `Current()`. The router stashes the canonical `?ns=` before any route (`Api/Router.cls:1423-1445`).
- `src/OcuPilot/Kernel/Shell/PrivilegesRead.cls:19-58`: `shell.privileges.read`. Its schema sets `additionalProperties: false` per area (`:48-53`).
- `src/OcuPilot/Kernel/Shell/SystemInfo.cls:237-240`: precedent for a shell read calling `%Library.EnsembleMgr.IsEnsembleNamespace` directly.

### Vendor (read only)

- `irislib/%Library/EnsembleMgr.cls:79-90` `IsEnsembleNamespace`: answers 0 for `%SYS`, and 0 on any error.
- `irislib/%DeepSee/Utils.cls:11052-11079` `%IsDeepSeeEnabled(pNamespace)`:
  - Reads the namespace default app's Analytics flag.
  - Its `%SYS` guard tests the raw argument, so `"%sys"` and an omitted argument answer 1 (measured).
- `irissys/%CSP/Portal/Home.cls`: the classic menus.
  - `:948-965` Analytics: not `%SYS`/`DOCBOOK`/`^^`, plus `%IsDeepSeeEnabled`.
  - `:970-995` Interoperability: `%Ens_Portal`, `IsEnsembleNamespace`, `CheckPrivileges`.
- `irissys/%Api/Atelier/v1.cls:2485-2488`: the per-namespace `features` reports `ENSEMBLE` from `IsEnsembleNamespace` and nothing for analytics.

### Client

- `ui/src/app/core/navigation.ts`:
  - `:87-90` and `:837`: the rail is drawn from the generated `AREAS` mirror.
  - `:939-1000` `runLoad`: reads verdicts only.
  - `:874-875`: a missing verdict falls back to `UNGATED`.
  - `:23-27`: nothing is gated before the map answers.
- `ui/src/main.ts:141-143`: `onScopeChange` calls `navigation.reload()`. The `ChangeBus` is built at `:126`.
- Every surface that draws an area:
  - `ui/src/app/shell/rail.ts:149`
  - `side-bar.ts:68-79`, `:153-185`
  - `ui/src/app/areas/home/home.page.ts:554-571`, the tiles
  - `command-box.ts:464`
  - `locator-bar.ts:298-320`
- `ui/tools/screen-mirror.mjs:47`, `:464-469`: reads `Area.cls` and sorts by `railPosition`. `:3761` is a stale "eight areas" comment.
- `ui/src/app/core/screens.generated.ts:580`: `AREAS` (regenerated).
- `ui/src/app/core/strings.ts:321-337`: the `navArea*` keys.
- `ui/src/app/shell/rail-icons.ts:32-117`, pinned by `ui/tools/rail-icons.test.mjs:83-138` to:
  - `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/mockups/key-home.html`
  - DESIGN.md's rail paragraph

### EXPERIENCE.md

- `:66` the rail line.
- `:214` "Gated controls are never hidden".
- `:310` area-names row, pinned by `ui/tools/strings.test.mjs:446-460`.

### DW-1921

- `src/OcuPilot/Screen/Descriptor/LogEventViewer.cls:25-26` `privileges`/`ownPrivileges`.
- `src/OcuPilot/Port/LogSourcePort.cls:239` `EVENTLOGPAIRS`. `PairsFor` (`:480-498`) appends the namespace database READ.
- `irislib/EnsPortal/Application.cls:234-247` `CheckPrivileges`: `%Ens_Portal:USE` plus READ on the namespace's database resource.
- `src/OcuPilot/Test/LogPairs.cls:40,95-118`: a row's 4th `=` field declares an extra pair.

### Area roster pins

- `Test/Descriptor.cls:1878-1906`
- `Test/Navigation.cls:224,237,431,437`
- `Test/Wire.cls:380-420`
- `Test/WireAreaAnyScreen.cls:269-317`
- `Test/DeveloperFloor.cls:25`
- `ui/tools/navigation.test.mjs:98-110`
- `screen-mirror.test.mjs:113`
- `navigation-wire.test.mjs:46-674` (captured payload)
- `rail.spec.ts:82-95,187,267`
- `rail-wire.spec.ts:725`
- `home.page.spec.ts:390,415,1475`

### Event-log pair pins

- `Test/LogPairs.cls:40`
- `Test/Descriptor.cls:1156`
- `Test/LogSource.cls:867,877`
- `Test/LogSecondary.cls:25,80`
- `Test/LogSourceDenial.cls:85,148,157`

## Tasks & Acceptance

**Execution:**

- `src/OcuPilot/Kernel/Shell/NamespaceFeatures.cls` (new, no storage):
  - `Reports(pFeature, pNamespace) As %Boolean` uses the closed vocabulary `FEATURES = "interoperability,analytics"`:
    - interoperability: `##class(%Library.EnsembleMgr).IsEnsembleNamespace(pNamespace)`.
    - analytics: 0 for empty, any case of `%SYS`, or a `^` prefix; otherwise `##class(%DeepSee.Utils).%IsDeepSeeEnabled($ZConvert(pNamespace,"U"))`.
    - Anything else, or a throw: 0.
  - `Applies(pAreaKey, pNamespace)`: 1 when the area declares no `appliesWhen`, otherwise `Reports`.
- `src/OcuPilot/Screen/Area.cls`:
  - Add `interoperability` (railPosition 9, `navAreaInteroperability`, `appliesWhen: "interoperability"`, privileges `[%Ens_Portal:USE]`, the classic menu's gate).
  - Add `analytics` (10, `navAreaAnalytics`, `appliesWhen: "analytics"`, `[%DeepSee_Portal:USE]`).
  - Move `agent` to 11.
  - Add an `AppliesWhen(pKey)` accessor and fix the counts in the doc comment.
- `src/OcuPilot/Screen/Registry.cls`: `Roster` carries `appliesWhen`. Add a validation that refuses an `appliesWhen` outside `NamespaceFeatures.FEATURES`, run wherever the registry validates descriptors.
- `src/OcuPilot/Kernel/Shell/Navigation.cls`: each area entry gains `"applies"` (boolean, always present) from `NamespaceFeatures.Applies(key, Scope.Current())`, computed on every call.
- `src/OcuPilot/Kernel/Shell/PrivilegesRead.cls`: add `applies` as a required boolean in the area schema.
- `ui/tools/screen-mirror.mjs`:
  - Emit `appliesWhen` into `AREAS`, and refuse the build on a value outside the same vocabulary.
  - Fix the stale comment.
  - Regenerate `screens.generated.ts`.
- `ui/src/app/core/navigation.ts`:
  - Keep `applies` per area from the map, keyed to the namespace the map was read in.
  - Add one predicate, `applies(areaKey)`: true for areas with no `appliesWhen`; for the others, false until that namespace's map answers true.
  - `areas()` returns only areas that apply, and `screensForArea` returns `[]` for one that does not. No surface computes applicability itself.
- `ui/src/app/shell/rail.ts`, `side-bar.ts` (close when its area stops applying), `ui/src/app/areas/home/home.page.ts`, `command-box.ts`, `locator-bar.ts`: read only that predicate and draw nothing of a non-applying area.
- `ui/src/main.ts`: re-read the map when the bus carries a `namespace` change for the current namespace. Read the event shape from `Screen/Tool/NamespaceEnableInterop.cls`.
- Strings and icons:
  - `ui/src/app/core/strings.ts`: add two keys, "Interoperability" and "Analytics". The 2,800 literal bound holds.
  - `ui/src/app/shell/rail-icons.ts`, `mockups/key-home.html` and DESIGN.md's rail paragraph: a rail icon and a tile icon each, pinned as `rail-icons.test.mjs` requires.
- `EXPERIENCE.md`:
  - `:66` adds the two categories before the divider and says they appear only in namespaces that report the feature.
  - `:310` adds the two names in rail order.
  - Add a new line after `:214`: "A category that does not apply to the namespace (Interoperability, Analytics) is not drawn at all; that is applicability, not a privilege gate."
- **DW-1921** (`LogEventViewer.cls`, `LogSourcePort.cls:239`, `Test/LogPairs.cls`, `Test/LogSourceDenial.cls`, `Test/Descriptor.cls:1156`):
  - Add `%Ens_Portal:USE` after `%Ens_EventLog:USE` to `privileges`, `ownPrivileges` and `EVENTLOGPAIRS`.
  - The LogPairs row declares `=%Ens_Portal:USE`.
  - LogSourceDenial grants the event-log principal both pairs, and adds a leg where the principal holds `%Ens_EventLog:U` alone and is refused naming `%Ens_Portal:USE`.
- `src/OcuPilot/Test/NamespaceFeatures.cls` (new; reads only):
  - For every namespace the instance lists, `Reports` equals the vendor's own answer.
  - `%SYS` applies to neither feature.
  - `%sys`, `^` and unknown features answer 0.
  - At least one namespace applies for each feature, and at least one does not (non-vacuous).
  - `Navigation.Payload` with the scope set to `%SYS` and to `HSCUSTOM` carries `applies` per area.
- Area roster pins listed in the Code Map: update them for 11 areas and the `applies` field.
  - `Test/Wire.cls` keeps "nothing is hidden by privilege" and adds the `applies` check.
  - `Test/DeveloperFloor.cls` re-derives its `AREAS` from the real answer.
  - Update the captured navigation payloads.
- `ui/browser/namespace-categories.browser-spec.mjs` (new; reads only):
  - The rail, Home tiles and command box in `%SYS`, in `HSCUSTOM`, and in a namespace that reports both. Which namespace is which is read from the instance, never hard-coded.
  - The switch back and forth.
  - The pre-answer state, with neither drawn.
  - A principal without `%Ens_Portal:USE` sees Interoperability drawn unavailable. The principal is created and removed on `ocupilot-b-ci`.

**Acceptance Criteria:**

- **AC1 (hand-off):** given an embedded vendor editor, when it loads, then it signs in from the browser-level login without a password crossing into the frame, and the `postMessage` auth path is not used. **Blocked**: not planned until the decision in `## Auto Run Result`.
- **AC2 (origin):** given the origin, when the hand-off is implemented, then it is not weakened, and per-tab token storage with no cross-tab broadcast is unchanged. **Blocked** with AC1. The gating half changes neither.
- **AC3:** given a namespace that does not report interoperability or analytics, when the rail renders, then that category does not appear on the rail, Home tile, side bar, command box or locator, gated by the namespace's own reported features (`IsEnsembleNamespace`, `%IsDeepSeeEnabled`).
- **AC3-I (integration):**
  - Given the map read with `?ns=X` on `ocupilot-b-ci`, the rail reads each area's `applies` and draws exactly the categories X reports, while every other area keeps its privilege verdict.
  - `shell.privileges.read` answers the same `applies`.
- **AC-DW1921:** given a holder of `%Ens_EventLog:USE` without `%Ens_Portal:USE`, when they open the Interoperability event log, then it is refused naming `%Ens_Portal:USE`, as the classic `EnsPortal.EventLog` page refuses them.

## Spec Change Log

- 2026-10-07, runner: split by the orchestrator's merge gate (Q2). The hand-off criteria and their analysis moved to Story 20.13 (DW-2141; this spec at `9faa902f`); the contended edits named under Design Notes were cleared (Q3); the floor stays and new surfaces declare their classic gate as an own pair. Retitled to the new key `20-1-namespace-category-gating`; status reset to `draft` for a gating-only re-plan.

## Review Triage Log

## Design Notes

**Governing ADs:**

- AD-5: the area declaration as the one source.
- AD-8: area verdicts, the administrative floor, own pairs, and the DW-1903 precedent for widening.
- AD-9 and AD-16: no escalation or namespace switch in the feature reads.
- AD-14: re-read on a change event.
- AD-19: navigation state stays in the framework-free service.
- AD-28 and AD-47: unchanged here; they block the hand-off.
- AD-29 and AD-36: the event log's port gate.
- AD-44: the namespace is data scope, and a screen's pairs union what its classic page enforces.
- Conventions › Screens that take no side-bar position: every surface reads listed screens.

**Spine decision for the runner (Rule 20), proposed text.** Amend AD-44: "A rail area may declare the namespace feature it applies to (`appliesWhen`, closed vocabulary):

- `interoperability` is `%Library.EnsembleMgr.IsEnsembleNamespace`.
- `analytics` is `%DeepSee.Utils.%IsDeepSeeEnabled`, never `%SYS` or an implied namespace.

It is read in the caller's process for the route's namespace on every navigation read. A non-applying area is drawn nowhere and is still on the wire. This is applicability, not a privilege gate: AD-8's 'never hidden' is unchanged."

**FR-80.** The gating half adds no screen and no port. The feature reads are shell chrome, the same shape as `SystemInfo.ProductionEnabled`, not a backing-system read. No AD-62 port is introduced. Stage 4's first port is 20.2's to name.

**The floor: what this story owns and what it does not.**

- Measured on the slot B roles: no `%EnsRole_*` role holds an `ADMINRESOURCES` member.
  - `%EnsRole_Operator`, `_Administrator` and `_Monitor` are refused before any route runs.
  - `%EnsRole_Developer` and `_InteropEditorsAPI` clear the floor through `%Development`.
- No `%DeepSee_*` role exists, and `%DeepSee_Portal` is public `U`. Admitting it to the floor would admit every user.
- 20.1 changes nothing here. Admitting interoperability-only operators (for instance through `%Ens_Portal:USE`) is an owner decision, as DW-1903 was.
- Recommended: the runner raises it as `decision-pending` before 20.2 ships the first Interoperability screen.

**Integration ACs and Consumed-by/Consumes.**

- In-story consumers: the rail, Home, side bar, command box and locator read `applies` (AC3-I).
- Consumed-by:
  - 20.2: the first Interoperability screens, which inherit the area's applicability on route and namespace switch.
  - 20.11: the Analytics screens and their pair set under `AreaCoverageProblem`.
  - 20.12: the agent's navigation into these categories.
- Consumes:
  - Story 18.15's enable-interop change event.
  - Story 16.8's event log descriptor and port (DW-1921).
- Rule 17: DW-1921 is addressed by the DW-1921 task and AC.

**Contended edits needing the runner's clearance (Rule 11, not add-only).** These are files Epic 18 is changing:

- EXPERIENCE.md `:66` and `:310`. The `:214` line is add-only.
- `Test/Descriptor.cls`: the area vocabulary test and `:1156`.
- `Test/Wire.cls`.
- `Test/WireAreaAnyScreen.cls`.
- `ui/tools/navigation.test.mjs` and `screen-mirror.test.mjs`.
- `ui/src/app/shell/area-verdict.spec.ts`, only if it reddens.
- `screens.generated.ts` (regenerated whole).

The add-only edits are `strings.ts` and `WireSecurityRead.cls`, the latter expected unchanged because `%Ens_EventLog:USE` stays first (inference). Whichever epic merges second rebases these.

**The hand-off half** is not planned. Its candidates, measurements and recommendation are in `## Auto Run Result`.

## Verification

**Setup (slot B):**

- Load the changed classes into `ocupilot-b-ci` with no restart, never through the MCP loader (its profile reaches the dev instance).
- Every principal-creating or configuration-changing step runs on `ocupilot-b-ci` only. Arm per call with `docker exec -e OCUPILOT_ALLOW_PRINCIPALS=1` where a class's header asks for it.
- Stateful ObjectScript test classes run one class per call, the next only once the previous has landed in `%UnitTest_Result`, and never a re-submit on a client timeout.
- Before any browser run: `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`, with `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777` and `OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci` exported.

**Commands:**

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.<C>`, one per call. Expected: 0 failures, totals checked in `%UnitTest_Result`. Classes:
  - `NamespaceFeatures`, `Navigation`, `Descriptor`, `Wire`, `WireAreaAnyScreen`, `DeveloperFloor`
  - `ReadTool`, `ToolRoundTrip`, `ScreenGate`
  - `LogPairs`, `LogSource`, `LogSecondary`, `LogSourceDenial`, `LogHub`, `LogHubWire`, `WireSecurityRead`
- `(loop)` `cd ui && node --test --test-concurrency=1 browser/namespace-categories.browser-spec.mjs browser/rail.browser-spec.mjs browser/rail-icons.browser-spec.mjs browser/log-hub.browser-spec.mjs browser/a11y-structural-invariants.browser-spec.mjs`. Expected: pass; the DW-1337 structural gate holds in both themes.
- `(loop)` Expected clean:
  - `cd ui && npm run test:tools && npm run test:components`
  - `uv run scripts/check-objectscript.py <changed .cls>`
  - `bash scripts/lint-docs.sh`
- `(once, before dev_complete)` The full ObjectScript sweep, `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci`, one class at a time. Then:
  - `cd ui && npm test && npm run build`: bundle under `maximumWarning` 2993 kB; stop and ask above 3800 kB.
  - `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS`
- `(CI)` The full browser suite runs only in CI's browser shards (Rule 29).

**Planned pinning mutations (Rule 19).** Apply on the throwaway, observe red, then revert byte-identical.

- G1: `NamespaceFeatures.Reports` answers 1 always. Expected red: `NamespaceFeatures`' `%SYS` leg, and the browser spec's `%SYS` rail.
- G2: `navigation.ts` treats a missing `applies` as true. Expected red: the browser spec's pre-answer leg.
- G3: the rail filters by privilege instead of `applies`. Expected red: the browser spec's `%Ens_Portal`-lacking leg.
- G4: `EVENTLOGPAIRS` drops `%Ens_Portal:USE`. Expected red: `LogPairs` and `LogSourceDenial`'s new leg.

## Auto Run Result

Status: blocked
Blocking condition: intent gap

**Gating half:** fully planned above and independent of the hand-off. It is ready to build once the runner clears the contended edits.

**Hand-off half:** every design that embeds the editors in place needs an AD-28 and AD-47 amendment. The one design that keeps both ADs as written drops the epic's "in place" scope and the editor messages Story 20.7 needs. Rule 5 puts that change with the owner.

**Measured** on `ocupilot-slot-b` (52775), Chrome 155, in an isolated browser context. Browser sessions only, and the session was signed out afterwards.

- **M1, in-place frame.** OcuPilot's shell stored its pair at `ocupilot.token-pair`.
  - An unsandboxed `<iframe>` of `/ui/interop/rule-editor/index.html?$NAMESPACE=USER` signed itself in: `POST /api/interop-editors/login` answered 200 and the toolbar rendered for `_SYSTEM`.
  - The editor wrote `Rule_Editor-0-*` keys into the tab's own sessionStorage.
  - Script in the frame read `ocupilot.token-pair` and the shell's document.
- **M2, new tab without opener.** `window.open(url, '_blank', 'noopener')`, and `<a target="_blank">` (implicitly noopener), each opened a tab whose sessionStorage held only the editor's keys. `window.opener` was null, and the rule and DTL editors both signed in silently.
- **M3, new tab with opener.** `window.open` without `noopener` gave the new tab a copy of the storage that included `ocupilot.token-pair`.
- **M4, opaque-origin frame.** `<iframe sandbox="allow-scripts">` loaded the document but made no sign-in request within 8 s.
- **M5, sign-out.** After OcuPilot's sign-out, the empty-body editors login answered 401.

**Read** in `irisui/ui/interop/*/main.*.js`:

- Normal mode calls `doLogin()` with no credentials.
- `?VSCODE=1` changes three things:
  - It skips that sign-in.
  - It sets `localStorage.vscodeMode`.
  - It installs `window.onmessage`, which accepts `{type:"auth", username, password}` from any sender.
- The `saved`, `compiled`, `changed`, `bad*` and `userAction` messages go to `window.parent` with target origin `"*"`, and only while `vscodeMode` is set.
- The auth service restores itself from the `<App>-0-refreshToken` key before any login.

**Candidates:**

| | Design | What it needs | Risk |
|---|---|---|---|
| A | In-place same-origin frame, normal mode. The editor signs itself in from `CSPBrowserId`. | An AD-28 named case for "never within an embedded frame's reach", and an AD-47 named case for "a vendor page OcuPilot embeds is inert". Together they settle the spine's Deferred row. | The frame reads OcuPilot's pair and scripts the shell (M1). It gains nothing it cannot already get: it mints its own pair for the same user, any JWT application accepts any token from the instance (spike §4), and sign-out ends both (M5). The residual risk is an injection inside the vendor editor reaching the shell's DOM. 20.7's messages are not available in normal mode. |
| B | Separate top-level tab, noopener, normal mode. | No AD change (M2). A Rule 5 scope change: the preamble's "embedded in place", 20.7 AC1 ("loads in place") and AC2 (messages), and 20.10's exchanged hooks, because there is no parent and so no messages. A guard so that every open is noopener (M3). | Low security risk. The cost is UX: the editor leaves OcuPilot's shell and panel. |
| C | Frame plus `VSCODE=1`, with OcuPilot pre-writing `<App>-0-*` tokens it minted from the cookie. | Everything A needs, plus AD-28's "never posted into an embedded frame". Untested. | Gains 20.7's messages, but OcuPilot hands the frame a token. The frame's `auth` listener has no sender check, though the shell's `frame-ancestors 'none'` narrows who can reach it (inference). |
| D | `VSCODE=1` with a password posted in. | Forbidden by AC1 and AD-28. | Rejected. |
| E | `sandbox=""` (AD-47's frame), or `allow-scripts` without same-origin. | — | Not viable: the editor neither runs nor signs in (M4). |
| F | Credentialless iframe. | — | Not viable (inference, unmeasured): it sends no cookie, so the silent sign-in fails, and it keeps same-origin access to the shell. |

**Recommendation: A.** The runner writes a named case (AD-62, or amendments to AD-28 and AD-47) that pins:

- the frame source to `/ui/interop/<editor>/index.html` on the instance's own origin;
- normal mode only;
- OcuPilot posts nothing into the frame, writes none of its storage keys and reads none of its messages;
- sign-out still ends the editors' sign-in source;
- a stated consequence: the frame can read the tab's storage and the shell's DOM, which adds nothing to what the browser-level login already gives same-origin code.

20.7 then decides its own message channel. Use B instead if the owner prefers no AD change and accepts losing "in place".

**Split.** Yes, the story can be split:

- 20.1 keeps the gating half and DW-1921, retitled.
- The hand-off moves to its own story, or to a Task 0 of 20.7, once the decision lands. Under A it becomes a shell frame component plus a browser spec proving silent sign-in. Under B it becomes a noopener link helper.

Splitting is the runner's decision.
