---
title: 'Story 20.1: Namespace category gating'
type: 'feature'
created: '2026-10-06'
status: 'in-progress'
baseline_revision: '9153a593de3492b37fc4feadf6a4b4fd45309977'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md'
warnings: [oversized]
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

- `src/OcuPilot/Screen/Area.cls:72-84`: XData `Areas`, nine entries. The doc comment says "nine" (`:1`, `:69`), and `:36-38` names the event log's own pair. Template: Story 19.1's commit `cbf70b07`, which added System Explorer.
- `src/OcuPilot/Screen/Gate.cls`:
  - `:45` `ADMINRESOURCES` and `:305` `FloorResources()`. This story does not change them.
  - `:119-155` `EvaluateArea`: an area that lists no screen is answered by its declared set alone (`:132-135`).
- `src/OcuPilot/Screen/Registry.cls`:
  - `:139` `Validate`: checks descriptors only. Nothing validates the area list today.
  - `:3619-3660` `Roster`: copies each area's fields.
- `src/OcuPilot/Kernel/Shell/Navigation.cls:20-58` `Payload`: reads no scope today. The "never a partial list" contract is at `:13-15`.
- `src/OcuPilot/Kernel/Scope.cls:36` `Current()`. Two callers set the scope before any read:
  - the router stashes the canonical `?ns=` (`Api/Router.cls:1424-1445`);
  - the turn job sets its own scope (`Kernel/Agent/Job.cls:94`).
- `src/OcuPilot/Kernel/Shell/PrivilegesRead.cls:18-60`: `shell.privileges.read`'s schema. Each area sets `additionalProperties: false` (`:52-53`).
- Precedents for calling `IsEnsembleNamespace` directly:
  - `src/OcuPilot/Kernel/Shell/SystemInfo.cls:237-240`, a shell read;
  - `Port/LogSourcePort.cls:1434`.
- `src/OcuPilot/Kernel/Audit/Log.cls:22` `Warn(subsystem, message, data)`. Error severity would raise the instance's alert state (AD-2), so a failed feature check logs at Warn.

### Vendor (read only)

- `irislib/%Library/EnsembleMgr.cls:79-90` `IsEnsembleNamespace(pNamespace)`: answers 0 for the raw string `%SYS`, and 0 on any error, an unreadable `^oddCOM` included.
- `irislib/%DeepSee/Utils.cls:11052-11079` `%IsDeepSeeEnabled(pNamespace)`:
  - It reads the Analytics flag of the namespace's default application.
  - Its `%SYS` guard tests the raw argument, so `"%sys"`, and an omitted argument in `%SYS`, answer 1 (measured).
- The classic menus in `irissys/%CSP/Portal/Home.cls`:
  - `:948-965` Analytics: not `%SYS`, `DOCBOOK` or `^^`, plus `%IsDeepSeeEnabled`. It is enabled when any branch of `%DeepSee.UI.Application.GetDeepSeeArray` opens. The User Portal branch checks `%DeepSee_Portal` or `%DeepSee_PortalEdit` at USE.
  - `:970-995` Interoperability: `CheckSecurity("%Ens_Portal")`, `IsEnsembleNamespace`, then `EnsPortal.Application.CheckPrivileges`.

### Client

- `ui/src/app/core/navigation.ts`:
  - `:87-110`: the module-level registry functions read the generated mirror.
  - `:829-860`: the seams `areas()`, `screensForArea()` and `builtScreens()`. Production never overrides them, and component specs stub them.
  - `:874-880`: a missing verdict falls back to `UNGATED`.
  - `:23-27`: nothing is gated before the map answers.
  - `:930-939` `reset()`.
  - `:951-1000` `runLoad`: reads verdicts only. A failed read fails open (DW-135).
- `ui/src/app/app.routes.ts:56`: the route table is built from the module function `builtScreens()`, not the service seam, so filtering the seam leaves routing alone.
- Surfaces:
  - `rail.ts:149` and `home.page.ts:554-571` read `areas()`.
  - `side-bar.ts:153-185` reads `screensForArea()` and draws its eyebrow from the visible area. `showing` is at `:186-194`.
  - `command-box.ts:464` reads `builtScreens()`, screens only, never areas.
  - `locator-bar.ts:298-320` uses the module function `areaByKey` for its area segment.
- `ui/src/app/core/shell-state.ts:258` `collapse()`: closes the bar without writing the preference (DW-144).
- `ui/src/main.ts`:
  - `:117-121` builds the navigation service before the bus (`:126`).
  - `:141-145`: `onScopeChange` calls `navigation.reload()`.
- `ui/src/app/core/scope.ts`:
  - `:40` `NAMESPACE_ENTITY`.
  - `:339-344`: the model for a bus subscriber.
- `ui/tools/screen-mirror.mjs`:
  - `:465-469` copies `Area.cls`'s areas verbatim.
  - `:3329-3341`: the `AreaDeclaration` interface.
  - `:3761` is a stale "eight areas" comment.
  - `:454-457` (`parseScopeWords`): the model for reading a parameter off a `.cls`.
- `ui/src/app/core/screens.generated.ts:580`: `AREAS` (regenerated).
- `ui/src/app/core/strings.ts:321-337`: the `navArea*` keys. Each carries `/** EXPERIENCE.md:310 */`, which `strings.test.mjs:822-866` resolves by line, so EXPERIENCE.md gets no inserted line.
- `ui/src/app/shell/rail-icons.ts:32-117` is pinned by `ui/tools/rail-icons.test.mjs` to two sources:
  - both frames of `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/mockups/key-home.html`;
  - DESIGN.md's `rail` paragraph (`DESIGN.md:975`, which says "Nine `rail-item`s" and "the same seven areas").

### EXPERIENCE.md

- `:66` the rail line. It also calls Agent co-pilot "the eighth area", which is stale.
- `:214` "Gated controls are never hidden". Unchanged.
- `:310` the area-names row, pinned by `ui/tools/strings.test.mjs:446-460`.

### DW-1921

- `src/OcuPilot/Screen/Descriptor/LogEventViewer.cls:25-26`: `privileges` and `ownPrivileges`.
- `src/OcuPilot/Port/LogSourcePort.cls`:
  - `:239` `EVENTLOGPAIRS`, a comma-separated spec (`ParsePairs:544`).
  - `PairsFor` (`:480-498`) appends the namespace database READ.
- `irislib/EnsPortal/Application.cls:234-247` `CheckPrivileges`: `%Ens_Portal:USE` plus READ on the namespace's database resource.
- Pins:
  - `Test/LogPairs.cls`: the row at `:40`. Its 4th `=` field declares an extra pair (`:95-118`).
  - `Test/Descriptor.cls:1156`.
  - `Test/LogSource.cls:867,877`.
  - `Test/LogSecondary.cls`: `:25` names the first failed pair and stays unchanged; `HoldAll` is at `:76-84`.
  - `Test/LogSourceDenial.cls:69-72,85,148,157`.
  - `Test/LogHubWire.cls:208-222`: its `%Manager` principal lacks both pairs and stays `%Ens_EventLog:USE`.

### Area roster pins

- Server tests:
  - `Test/Descriptor.cls:1878-1906`
  - `Test/ExplorerDescriptor.cls:36-38`, where Agent co-pilot is at 9
  - `Test/Navigation.cls:224,237,431,437`
  - `Test/Wire.cls:380-420`
  - `Test/WireAreaAnyScreen.cls:269-317`
  - `Test/DeveloperFloor.cls:25`
- Client tools tests:
  - `ui/tools/navigation.test.mjs:98-110`
  - `ui/tools/screen-mirror.test.mjs:113`
  - `ui/tools/strings.test.mjs:446-460`
  - `ui/tools/navigation-wire.test.mjs:46-674`, the captured payload, which `rail-wire.spec.ts:725` carries a second time
- Component specs:
  - `rail.spec.ts:82-95,187,267`
  - `home.page.spec.ts:390,415,1475`
  - `app.spec.ts:114-117`, `side-bar.spec.ts:44` and `locator-bar.spec.ts:42` (their stubs)
- Browser specs: `ui/browser/rail-icons.browser-spec.mjs:63-64,198-219,376-378` iterate every `AREAS` entry.

### Reuse

- `Test/DeveloperFloorFixture` `EnsurePrincipal`/`RemovePrincipals`, called the way `ui/browser/developer-floor.browser-spec.mjs:44-80` calls it. `%Developer` lacks `%Ens_Portal` (measured).
- `Test/ScreenGate.cls:89` holds only the pairs a test names; it models no public permission.

### Measured on `ocupilot-b-ci`, 2026-10-06

- Features by namespace (interoperability / analytics):

  | Namespace | Interoperability | Analytics |
  |---|---|---|
  | `%SYS` | 0 | 0 |
  | `HSCUSTOM` | 1 | 0 |
  | `HSLIB` | 1 | 1 |
  | `HSSYS` | 1 | 1 |
  | `HSSYSLOCALTEMP` | 0 | 0 |
  | `USER` | 1 | 0 |

- Public permissions: `%Ens_Portal` and `%Ens_EventLog` have none; `%DeepSee_Portal` is public `U`.
- Roles:
  - `%Developer`, `%Operator` and `%Manager` hold neither Ens resource.
  - `%EnsRole_Operator` holds both.

## Tasks & Acceptance

**Execution:**

- `src/OcuPilot/Kernel/Shell/NamespaceFeatures.cls` (new, no storage):
  - `Parameter FEATURES = "interoperability,analytics";` is the closed vocabulary. The registry and the mirror both read it.
  - `Reports(pFeature, pNamespace) As %Boolean`, with the namespace upper-cased first:
    - It answers 0 for an empty namespace or one beginning with `^`.
    - interoperability: `##class(%Library.EnsembleMgr).IsEnsembleNamespace(ns)`.
    - analytics: 0 for `%SYS`, otherwise `##class(%DeepSee.Utils).%IsDeepSeeEnabled(ns)`.
    - A feature outside `FEATURES`, or a throw, answers 0 and writes one `Log.Warn` line for that check.
  - `Applies(pFeature, pNamespace)`: 1 when `pFeature` is empty, otherwise `Reports`.
- `src/OcuPilot/Screen/Area.cls`:
  - Add `interoperability`: railPosition 9, `navAreaInteroperability`, `appliesWhen: "interoperability"`, privileges `[%Ens_Portal:USE]`.
  - Add `analytics`: railPosition 10, `navAreaAnalytics`, `appliesWhen: "analytics"`, privileges `[%DeepSee_Portal:USE]`.
  - Move `agent` to 11.
  - Fix the doc comment: the counts, a paragraph on what each new set names (Design Notes), and `:36-38` for DW-1921.
- `src/OcuPilot/Screen/Registry.cls`:
  - `Roster` carries `appliesWhen`, `""` when undeclared.
  - Add `AreaProblem(pAreas)`, which names an area whose `appliesWhen` is outside `NamespaceFeatures.FEATURES`.
  - `Validate` calls it first, on `Area.List`.
- `src/OcuPilot/Kernel/Shell/Navigation.cls`: each area entry gains `"applies"`. It is a boolean, always present, equal to `NamespaceFeatures.Applies(appliesWhen, Scope.Current())`, and computed on every call. Update the doc comment.
- `src/OcuPilot/Kernel/Shell/PrivilegesRead.cls`: add `applies` (boolean) to the area properties and to `required`.
- `ui/tools/screen-mirror.mjs`:
  - Read `FEATURES` off `NamespaceFeatures.cls`.
  - Emit `export type NamespaceFeature = ...`, and add `readonly appliesWhen?: NamespaceFeature` to `AreaDeclaration`. The key is emitted only where it is declared, so the stubs' fixtures stay valid.
  - Throw naming the area for a value outside the vocabulary.
  - Fix the stale comment, then regenerate `screens.generated.ts` whole.
- `ui/src/app/core/navigation.ts`:
  - Export the pure `areasThatApply(areas, applies)` and `screensThatApply(screens, applies)`.
  - `NavigationService` keeps `applies` per area and the namespace key its map was read under.
  - `applies(areaKey)` is true for an area with no `appliesWhen`. Otherwise it is true only when the stored key equals `namespace()` and that area's wire `applies === true`.
  - `areas()`, `screensForArea()` and `builtScreens()` return only what applies.
  - `reset()` clears the stored answer.
  - A failed read leaves the stored answer as it was.
  - New option `bus?: ChangeBus`: on a `changed` event of type `namespace` whose id equals `namespace()` (case-insensitively), call `reload()`.
- `ui/src/main.ts`: build the `ChangeBus` before the navigation service and pass it in.
- `ui/src/app/shell/side-bar.ts`: when the visible area is no longer in `navigation.areas()`, it is not shown. If it was open, it closes through `shell.collapse()`. Focus inside it moves to Home's rail item first.
- `ui/src/app/shell/locator-bar.ts`: draw no area segment for an area missing from `navigation.areas()`.
- No change expected to `rail.ts`, `home.page.ts` or `command-box.ts`: they read the filtered seams. No surface calls `applies()`.
- Strings and icons:
  - `ui/src/app/core/strings.ts` (add-only): `navAreaInteroperability: 'Interoperability'` and `navAreaAnalytics: 'Analytics'`, each `/** EXPERIENCE.md:310 */`. Fixed strings go from 2,754 to 2,756, under the 2,800 bound.
  - `ui/src/app/shell/rail-icons.ts` and both frames of `mockups/key-home.html`: a 20px rail icon and a 24px tile icon for each new area, in the module's stroke style.
  - `DESIGN.md:975`, edited in place: eleven rail items, the nine tile areas, and that the two appear only in a namespace that reports the feature.
- `EXPERIENCE.md`, edited in place with no line inserted, because `strings.ts`'s line references would shift:
  - `:66` lists Interoperability · Analytics before the divider and drops the stale ordinal. It also says: "Interoperability and Analytics appear only in a namespace that reports the feature (`IsEnsembleNamespace`, `%IsDeepSeeEnabled`); a category that does not apply is not drawn at all, which is applicability, not a privilege gate."
  - `:310` adds the two names in rail order.
- **DW-1921:**
  - Add `%Ens_Portal:USE` after `%Ens_EventLog:USE`:
    - in `LogEventViewer.cls` `privileges` and `ownPrivileges`;
    - in `LogSourcePort.cls:239` `EVENTLOGPAIRS`, which becomes `%Ens_EventLog:USE,%Ens_Portal:USE`.
  - Pins:
    - `Test/LogPairs.cls`: the row gains `=%Ens_Portal:USE`.
    - `Test/Descriptor.cls:1156`: the event log row.
    - `Test/LogSource.cls:867,877`: the pair strings, in `PairsToString` order.
    - `Test/LogSecondary.cls` `HoldAll`: also holds `%Ens_Portal:USE`.
  - `Test/LogSourceDenial.cls`:
    - The event-log principal holds both pairs.
    - A new leg uses a principal holding `%Ens_EventLog:U`, the code read and `%Admin_Secure:U`, without `%Ens_Portal:U`. Its route and read tool are each refused 403 naming `%Ens_Portal:USE`.
  - `Test/LogHubWire.cls`: a new leg with a `%Manager`, `%DB_HSCUSTOM:R` and `%Ens_EventLog:U` principal. The hub answers the event log `0|%Ens_Portal:USE`.
- `src/OcuPilot/Test/NamespaceFeatures.cls` (new; reads only, arms nothing):
  - For every namespace `Config.Namespaces:List` returns, `Reports` equals the vendor's own answer for that namespace upper-cased.
  - `%SYS` applies to neither feature.
  - `%sys`, a `^` namespace and an unknown feature each answer 0.
  - At least one namespace reports each feature, and at least one does not.
  - `AreaProblem` refuses a synthetic `appliesWhen: "bogus"`, naming the area.
  - `Navigation.Payload` with `Scope.Set("%SYS")` answers `applies` false for both new areas and true for every other area. With `Scope.Set("HSCUSTOM")`, it answers the measured values.
  - Clear the scope afterwards.
  - The agent's half is pinned by `ToolShell:39`, which validates `shell.privileges.read`'s result against its closed schema.
- Area roster pins listed in the Code Map, updated for 11 areas and the `applies` field:
  - `Test/Descriptor.cls`'s area vocabulary test also asserts each area's `appliesWhen`: empty for the nine, and its own feature for each new area.
  - `Test/Wire.cls` keeps "nothing is hidden by privilege". For its `%Admin_Operate`-only principal in HSCUSTOM, it adds interoperability `allowed false`, `failedPair %Ens_Portal:USE`, `applies true`, and analytics `allowed true`, `applies false`.
  - `Test/DeveloperFloor.cls` `AREAS` becomes `home,logs,system-explorer,analytics,agent`, because `%DeepSee_Portal` is public `U`.
  - `Test/Navigation.cls`: with nothing held, the new areas name `%Ens_Portal:USE` and `%DeepSee_Portal:USE`.
  - `Test/ExplorerDescriptor.cls:38`: Agent co-pilot is at 11.
  - The captured payload (`navigation-wire.test.mjs`, `rail-wire.spec.ts`), moved together.
- Client tests:
  - `ui/tools/navigation.test.mjs`. The `applies` legs:
    - before an answer;
    - an answer of true, of false, and with `applies` missing or non-boolean;
    - a namespace moved after the read;
    - a failed read;
    - `reset()`;
    - the two pure filters over a synthetic interoperability screen;
    - a bus `namespace` event for the current namespace re-reads the map, and one for another namespace does not.
  - `ui/tools/screen-mirror.test.mjs`: 11 areas, plus a synthetic area source with a bad `appliesWhen` that throws.
  - `ui/tools/strings.test.mjs:446-460`: the eleven keys.
  - `rail-icons.test.mjs`: passes once the mockup and module carry the two icons.
  - `side-bar.spec.ts`: the bar closes, unpersisted, when `areas()` drops the visible area.
  - `locator-bar.spec.ts`: the stub gains `areas()`, and no area segment is drawn for an area it omits.
  - `rail.spec.ts` and `home.page.spec.ts`: update their rosters and counts. `app.spec.ts` changes only if it reddens, because its three-area fixture stays valid with an optional `appliesWhen`.
- `ui/browser/rail-icons.browser-spec.mjs`:
  - It opens the shell in a namespace that reports both features. It finds that namespace by reading `/api/ocupilot/navigation?ns=` for each namespace `/api/ocupilot/namespaces` lists.
  - Its rail and tile rosters are the `AREAS` that apply there.
- `ui/browser/namespace-categories.browser-spec.mjs` (new). It never reads `.ocu-side-bar-label`, so `side-bar-pins.test.mjs` is untouched. Each namespace's role is read from the instance as above. It covers:
  - the rail and Home tiles in `%SYS`, in an interop-only namespace, and in one that reports both;
  - the pre-answer state, with `/api/ocupilot/navigation` held through request interception: neither category is drawn while Logs is;
  - opening Interoperability's side bar, then switching to `%SYS`: the rail item and the bar are gone, and switching back restores the rail item;
  - the `DeveloperFloorFixture` principal, created in `before` and removed in `after` on `ocupilot-b-ci` only. In the interop-only namespace it sees Interoperability drawn `aria-disabled`, naming `%Ens_Portal:USE`.

- [ ] [Halt] Re-base the initial bundle budget under DW-1166 (runner-authorized 2026-10-07; the spawn prompt's re-base clause, so `ui/angular.json` and `ui/tools/angular-json.test.mjs` are cleared for this edit): `maximumWarning` `3012kB` -> `3165kB`, 5% above the measured 3,013,646-byte initial total, in `ui/angular.json` and in the DW-371 test's pinned literal and its comment (one line `// Story 20.1 raised it to 3165kB, 5% above a measured 3,013,646 bytes (namespace category gating), under the 4000kB hard stop.`). `maximumError` stays `4000kB`. Epic 18's own re-base (3191kB) meets this at the merge; the second epic to merge takes the larger figure. Then finish what the halt left: the tools tier, the full ObjectScript sweep, the review layers and finalize.

**Acceptance Criteria:**

- **AC1:** given a namespace that does not report interoperability or analytics, when the rail renders, then that category does not appear on the rail, Home tile, side bar, command box or locator, gated by the namespace's own reported features (`IsEnsembleNamespace`, `%IsDeepSeeEnabled`).
- **AC2 (integration):** given the map read with `?ns=X` on `ocupilot-b-ci`, when the rail renders, then it reads each area's `applies` and draws exactly the categories X reports, while every other area keeps its privilege verdict; and `shell.privileges.read` answers the same `applies`.
- **AC3 (DW-1921):** given a holder of `%Ens_EventLog:USE` without `%Ens_Portal:USE`, when they open the Interoperability event log, then it is refused naming `%Ens_Portal:USE`, as the classic `EnsPortal.EventLog` page refuses them.

## Spec Change Log

- 2026-10-07, runner: implement pass 1 halted `implementation verification failed` on the DW-371 bundle budget (3,013,646 B against 3012kB). The runner authorized the re-base above under DW-1166 and reset the spec to `in-progress`; the pass-1 implementation stays in the working tree and inside the next diff.
- 2026-10-07, runner: split by the orchestrator's merge gate (Q2). The hand-off criteria and their analysis moved to Story 20.13 (DW-2141; this spec at `9faa902f`); the contended edits named under Design Notes were cleared (Q3); the floor stays and new surfaces declare their classic gate as an own pair. Retitled to the new key `20-1-namespace-category-gating`; status reset to `draft` for a gating-only re-plan.

## Review Triage Log

## Design Notes

**Governing ADs:**

- AD-5: the area declaration is the one source, and the mirror is generated.
- AD-8: area verdicts, own pairs, never hidden for privilege, and the floor left unchanged.
- AD-9 and AD-16: no escalation and no namespace switch in the feature reads.
- AD-14: the map is re-read on a `namespace` change event.
- AD-19: navigation state stays in the framework-free service.
- AD-29: the event log's port gate.
- AD-36: the hub names the pair of a member it leaves out.
- AD-39: vendor text is logged, never sent.
- AD-44: the namespace is data scope, and a screen's pairs union what its classic page enforces.
- Conventions › Screens that take no side-bar position.

**Spine decisions for the runner (Rule 20), proposed text:**

1. Amend AD-44: "A rail area may declare the namespace feature it applies to (`appliesWhen`, from the closed vocabulary `Kernel/Shell/NamespaceFeatures.FEATURES`):
   - `interoperability` is `%Library.EnsembleMgr.IsEnsembleNamespace`.
   - `analytics` is `%DeepSee.Utils.%IsDeepSeeEnabled`, never `%SYS` or an implied namespace.

   Each is read in the caller's process for the route's namespace on every navigation read, and answered on the map as `applies`. A non-applying area is drawn nowhere and stays on the wire with its verdict. This is applicability, not a privilege gate, and AD-8's 'never hidden' is unchanged."
2. In AD-8's own-pair paragraph, "Story 16.8's interoperability event log declares `%Ens_EventLog:USE`" becomes "declares `%Ens_EventLog:USE` and `%Ens_Portal:USE` (`EnsPortal.Application.CheckPrivileges`, DW-1921)".
3. The Capability map's Stage 4 row adds AD-44.

**Each new area's declared pair set (the floor ruling):**

- **Interoperability: `%Ens_Portal:USE`.** The classic Interoperability menu checks it with `CheckSecurity("%Ens_Portal")`. Its other check, READ on the namespace's database (`CheckPrivileges`), depends on the namespace, so each 20.2+ screen and port resolves it at call time, as System Explorer's area does.
- **Analytics: `%DeepSee_Portal:USE`.** The classic User Portal branch checks it, and that check enables the classic Analytics menu. It is public `U` on a stock instance (measured), so the area opens for every caller past the floor, as the classic menu does. Each 20.11 screen declares its classic page's own resource as its own pair (DW-1853).
- The floor is unchanged (DW-2140), and neither set touches `ADMINRESOURCES`.

**Client shape:**

- One predicate in `NavigationService`. Every surface reads the filtered seams it already reads, so no component computes applicability. The only component stub that needs a new method is `locator-bar.spec.ts`'s, which gains `areas()`.
- Verdicts fail open (DW-135), because the server gates every read. Applicability fails closed: a category that does not apply has nothing behind it for a server gate to protect, so drawing it on an unanswered question would be wrong.
- The command box lists screens, and the locator names the area of the routed screen. 20.1 builds no screen in either category, so neither leg has a subject yet. The shared filters are pinned by the tools tier now, and 20.2's browser spec pins those two surfaces (Consumed-by).

**Integration ACs, Consumed-by and Consumes:**

- In-story consumers: the rail, Home, side bar, command box and locator read the map's `applies` (AC2).
- Consumed-by:
  - 20.2: the first Interoperability screens inherit the area's applicability on route and on namespace switch.
  - 20.11: the Analytics screens and their pair set under `AreaCoverageProblem`.
  - 20.12: the agent's navigation into these categories reads `shell.privileges.read`'s `applies`.
- Consumes:
  - Story 18.15's enable-interop change event (`type namespace`, `action updated`).
  - Story 16.8's event log descriptor and port (DW-1921).
  - Story 19.12's `DeveloperFloorFixture`.
- Rule 17: DW-1921 is addressed by the DW-1921 task and AC3.

**FR-80.** This story adds no screen and no port. The feature reads are shell chrome, shaped like `SystemInfo.ProductionEnabled`.

**Contended files (Rule 11), re-checked against `.worktrees/epic-18` on 2026-10-06:**

- Cleared by the orchestrator on 2026-10-07: EXPERIENCE.md `:66` and `:310`; `Test/Descriptor.cls`; `Test/Wire.cls`; `Test/WireAreaAnyScreen.cls`; `ui/tools/navigation.test.mjs`; `screen-mirror.test.mjs`; `area-verdict.spec.ts`, only if it reddens; and `screens.generated.ts`, regenerated whole.
- Epic 18 also has these files changing in its tree:
  - `strings.ts`: this story adds to it only.
  - `ReadTool.cls`, `ToolRoundTrip.cls` and `WireSecurityRead.cls`: run, never edited. `WireSecurityRead` is expected unchanged because `%Ens_EventLog:USE` stays first (inference). If any of the three reddens, stop and ask the runner.
- No other file on Epic 18's list is touched.
- Story 18.13 (per-namespace state) overlaps `navigation.ts`. The second epic to merge rebases.
- Editing EXPERIENCE.md, DESIGN.md and `key-home.html` makes `epic-20-context.md` stale, so the runner re-runs the pre-warm before 20.2's plan.

## Verification

**Setup (slot B):**

- Load the changed classes into `ocupilot-b-ci` without a restart, and never through the MCP loader: its profile reaches the dev instance.
- Every principal-creating step runs on `ocupilot-b-ci` only. Where a class's header asks for it, arm the call with `docker exec -e OCUPILOT_ALLOW_PRINCIPALS=1`; `LogHubWire` also asks for its seed variable.
- Run stateful ObjectScript test classes one class per call. Send the next only once the previous run has landed in `%UnitTest_Result`, and never re-submit after a client timeout.
- Before any browser run:
  - `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`
  - export `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777` and `OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci`

**Commands:**

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.<C>`, one class per call. Expected: 0 failures, with the totals checked in `%UnitTest_Result`. Classes:
  - `NamespaceFeatures`, `Navigation`, `Descriptor`, `ExplorerDescriptor`, `Wire`, `WireAreaAnyScreen`, `DeveloperFloor`, `Gate`
  - `ToolShell`, `ReadTool`, `ToolRoundTrip`
  - `LogPairs`, `LogSource`, `LogSecondary`, `LogSourceDenial`, `LogHub`, `LogHubWire`, `WireSecurityRead`
- `(loop)` `cd ui && node --test --test-concurrency=1 browser/namespace-categories.browser-spec.mjs browser/rail-icons.browser-spec.mjs browser/rail.browser-spec.mjs browser/log-hub.browser-spec.mjs browser/developer-floor.browser-spec.mjs browser/a11y-structural-invariants.browser-spec.mjs`. Expected: pass, with the DW-1337 structural gate holding in both themes.
- `(loop)` Expected clean:
  - `cd ui && npm run test:tools && npm run test:components`
  - `uv run scripts/check-objectscript.py <changed .cls>`
  - `bash scripts/lint-docs.sh`
- `(once, before dev_complete)` The full ObjectScript sweep, `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci`, one class at a time. Then:
  - `cd ui && npm test && npm run build`: the bundle stays under `maximumWarning` 2993 kB; stop and ask above 3800 kB.
  - `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS`
- `(CI)` The full browser suite runs only in CI's browser shards (Rule 29).

**Planned pinning mutations (Rule 19).** Apply each on the throwaway, observe red, then revert byte-identical.

- AC1, server: make `NamespaceFeatures.Reports` answer 1 always. Expected red: `NamespaceFeatures`' `%SYS` legs, and the browser spec's `%SYS` rail.
- AC1, client fail-closed: make `applies()` treat a missing answer as true. Expected red: the pre-answer legs in `navigation.test.mjs` and the browser spec.
- AC1, side bar: make `side-bar.ts` ignore membership in `areas()`. Expected red: `side-bar.spec.ts`, and the browser spec's switch leg.
- AC2: make `areas()` filter by `areaVerdict().allowed` instead of `applies()`. Expected red: the browser spec's developer leg.
- AC2, agent: make `Navigation.Payload` omit `applies` on one area. Expected red: `NamespaceFeatures`' payload leg, and `ToolShell`, through the closed schema.
- Matrix, interop enabled meanwhile: drop the bus subscription. Expected red: the bus leg in `navigation.test.mjs`.
- AC3: make `EVENTLOGPAIRS` drop `%Ens_Portal:USE`. Expected red: `LogPairs`, `LogSourceDenial`'s new leg, and `LogHubWire`'s new leg.

**Rule 19 results (ocupilot-b-ci, 2026-10-07; each reverted byte-identical).**

- mutation: AC1 server, `NamespaceFeatures.Reports` answers 1 always -> red: `NamespaceFeatures` (3 of 4 methods) and all four `namespace-categories` browser tests (the rail never settles on the expected roster).
- mutation: AC1 client fail-closed, `applies()` answers true before any answer -> red: three `navigation.test.mjs` legs and the browser pre-answer test.
- mutation: AC1 side bar, `offered()` answers true -> red: the `side-bar.spec.ts` leg and the browser switch test.
- mutation: AC2, `areas()` filters by `areaVerdict().allowed` -> red: four `navigation.test.mjs` legs and all four browser tests, the developer leg included.
- mutation: AC2 agent, `Navigation.Payload` omits `applies` on the agent area -> red: `NamespaceFeatures` payload leg and `ToolShell`.
- mutation: matrix bus row, drop the bus subscription -> red: the bus leg of `navigation.test.mjs`.
- mutation: AC3, `EVENTLOGPAIRS` without `%Ens_Portal:USE` -> red: `LogPairs` and `LogSourceDenial`'s new leg; `LogHubWire`'s new leg stays green, because the hub gates on the descriptor's `privileges`, so it reddens only when `LogEventViewer`'s `privileges` drop the pair too (then red; the descriptor mutation alone is green on `LogHubWire` and `LogSourceDenial`).

## Auto Run Result

Status: blocked
Blocking condition: bundle budget needs a non-add-only edit to a file Epic 18 is changing. The initial bundle is 3,013,646 bytes against `maximumWarning` 3012kB, so DW-371 in `ui/tools/build-output.test.mjs` fails by 1,646 bytes (HEAD is 3,011,584). Clearing it means raising the literal in `ui/angular.json` and `ui/tools/angular-json.test.mjs`; Epic 18 edits the same lines (3012kB to 3191kB). Recommended: the runner or orchestrator raises the figure to 3191kB (the union value) or lets Epic 18's merge supply it; no other code change is needed.

Implementation is complete and uncommitted in the worktree. Server classes (18 run one at a time on ocupilot-b-ci), the component runner (2,554 tests), the tools tier (1,873 of 1,874; the one failure is DW-371), the six browser specs, `check-objectscript.py`, `lint-docs.sh` and smoke (50/50) are green. The full ObjectScript sweep, review layers and finalize have not run.
