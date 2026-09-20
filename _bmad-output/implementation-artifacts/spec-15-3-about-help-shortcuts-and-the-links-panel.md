---
title: 'Story 15.3: About, help, shortcuts and the links panel'
type: 'feature'
created: '2026-09-20'
status: 'done'
baseline_revision: '07958f57e4f0a6350feba7d5b0d5863a5025baa6'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-15-context.md'
warnings: ['multiple-goals', 'oversized']
deferred:
  - summary: >-
      A transient help-read failure removes that screen's Help control for the rest of the session.
    evidence: |-
      `HelpLinks.load` adds the route to `asked` before awaiting and never removes it on failure,
      and `helpHrefFor` collapses a refusal, an unavailable answer and an unreachable instance to
      the same ''. Closing it means giving `helpHrefFor` a third outcome, which changes its contract.
    location: >-
      ui/src/app/core/help.ts (load/asked)
    severity: medium
  - summary: >-
      `.claude/rules/objectscript-testing.md` still documents the dead `dist/ocupilot/browser`
      redeploy path this story corrected everywhere else.
    evidence: |-
      That file is auto-loaded into every agent's context, so the wrong path keeps being handed to
      the next agent. The spec's own change log records the correction; its origin was not fixed.
      Routed to defer because the fix edits an agent-context file.
    location: >-
      .claude/rules/objectscript-testing.md:189
    severity: medium
  - summary: >-
      `stale-bundle-notice.ts` has no component spec, and `app.spec.ts`'s band-order row was not
      extended to it.
    evidence: |-
      The browser tier covers its render, role, copy, never-self-reloads and the Reload click, and
      `isStale` is unit-tested; what has no jsdom host is where the region sits in the frame, which
      `app.spec.ts` pins for its sibling `<app-fault-banner />` with a recorded mutation.
    location: >-
      ui/src/app/shell/stale-bundle-notice.ts
    severity: medium
  - summary: >-
      The About dialog renders thirteen blank values between mount and the read settling.
    evidence: |-
      `unanswered` is false while neither `answered()` nor `failed()` is set, so the first paint is
      a definition list of empty values rather than a pending state. Sub-second, and the values
      arrive in place.
    location: >-
      ui/src/app/shell/about-dialog.ts (unanswered)
    severity: low
  - summary: >-
      The stale-bundle strip can stand above the blocking instance notice.
    evidence: |-
      `app.ts` renders `<app-stale-bundle-notice />` outside the signed-in branch, beside the fault
      banner; the blocking notice is meant to replace the product surface rather than share it.
    location: >-
      ui/src/app/app.ts (template)
    severity: low
  - summary: >-
      The prompt's `role="status"` region is inserted when it becomes true rather than kept mounted
      and populated, which is commonly not announced.
    evidence: |-
      The house idiom elsewhere (`home.page.ts`, `account-menu.ts`) keeps a hidden region mounted
      and sets its text. EXPERIENCE.md now publishes this prompt among the polite status messages,
      so the announcement is a published contract; the browser spec asserts the attribute, not that
      anything was announced.
    location: >-
      ui/src/app/shell/stale-bundle-notice.ts (template)
    severity: low
  - summary: >-
      Nothing in the suite executes the real audit-log call for the new `uiabout` subsystem.
    evidence: |-
      `OcuPilot.Test.UiAboutFixture.LogSourceFailure` overrides the seam without `##super`, so every
      test that drives a refused source records into a process-private global and
      `OcuPilot.Kernel.Audit.Log.Error(..#LOGSUBSYSTEM, ...)` is never run.
    location: >-
      src/OcuPilot/Test/UiAboutFixture.cls (LogSourceFailure)
    severity: low
  - summary: >-
      `Installer.BundleIdentity`'s fallback branch has no test in any tier.
    evidence: |-
      It is `[ Private ]`, so reaching it needs an installer fixture subclass or an install run with
      the shell bundle directory emptied. The happy path is covered on every throwaway install; the
      fallback's failure mode is a Build row reading `dev`, which the client now never compares.
    location: >-
      src/OcuPilot/Install/Installer.cls (BundleIdentity)
    severity: low
  - summary: >-
      Home's Shortcuts empty state is unreachable, so `STRINGS.shortcutsEmpty` is published but
      cannot be displayed.
    evidence: |-
      `shortcutScreens()` filters the shipped mirror, which always resolves some rows, and a
      component spec may not replace the mirror. Removing the string means editing the published
      Fixed strings row as well.
    location: >-
      ui/src/app/areas/home/home.page.ts (Shortcuts @else)
    severity: low
  - summary: >-
      DESIGN.md's polish-week enumeration was not extended with Shortcuts and Links.
    evidence: |-
      `:898` still reads "Polish-week additions (system information, favorites, recents) go above or
      beside the grid" — the line this story's Design Notes cite for placing both new blocks.
    location: >-
      _bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/DESIGN.md:898
    severity: low
---

<intent-contract>

## Intent

**Problem:** Four things the classic portal put in its header have no OcuPilot equivalent: the About page's system overview, per-screen Help, the fixed shortcuts menu and the links panel. Nothing in the client reads the `buildIdentity` the instance already publishes, so a browser holding a bundle from before a container restart is never told (DW-3).

**Approach:** One new caller-own shell-chrome read, `GET /api/ocupilot/ui/about` and `GET /api/ocupilot/ui/help`, extending `Kernel/Shell/Instance.cls`'s in-process per-field-degrade idiom. About becomes a dialog off the account menu; Help becomes a locator-bar control that opens the classic page's own DocBook address, resolved server-side from the descriptor's existing `classicPage`; Shortcuts and Links become two Home blocks beside 15.2's. The installer's build stamp stops being a literal and becomes the deployed bundle's hashed `main-*.js` name, which the running client compares against its own.

## Boundaries & Constraints

**Always:**

- Shell chrome: no screen descriptor, route table entry, tool, proposal or auto-refresh (AD-5, AD-36 exception, AD-43). About is not a screen and is never a read tool, so the catalog's SH-16 "co-pilot tool: read" column does not apply.
- Every field is read in the calling process by a documented `%SYSTEM.*` / `%SYS.*` class method, each in its own `Try` so a refusal degrades that one field to `""` and logs — `Instance.cls:143-155`'s `ReadSource` seam, copied.
- Every entry in Shortcuts and Links is filtered by what the user may reach, and a gated entry **stays listed and focusable naming the resource it needs** — never removed, never natively `disabled` (AD-8, EXPERIENCE.md `:665`).
- Anchors only: nothing on these surfaces fetches from an off-origin host, and no library comes from a CDN (AD-11 rule 4, AD-47). Outbound anchors follow the house pattern `target="_blank" rel="noreferrer"` (`instance-notice.ts:64-70`).
- Every new literal is published in EXPERIENCE.md's Fixed strings table **before** it exists as a `strings.ts` key, appended strictly after the current last row `:382`.
- No inert control: every item ships with its handler.
- One error envelope with a stable dotted code (AD-12, AD-39); a new code needs its arm in `Api/Error.cls` `ReasonForViolation` or its `reason` serializes empty.

**Never:**

- Never add a control to the header band — it is closed at three children (DESIGN.md `:1009`) and `header.spec.ts:130-131` pins the three by tag name. Never make a second status-bar segment interactive (DESIGN.md `:1023`).
- Never add a screen-descriptor key, and never regenerate `ui/src/app/core/screens.generated.ts` — Epic 5 has modified it. `core/navigation.ts` and the mirror are **read only** here.
- Never link out to a classic portal page from these surfaces: the shortcuts name OcuPilot routes, not `%CSP.UI.Portal.*` pages (AD-44, SM-C1).
- Never a second finder: Shortcuts is a fixed roster, not a search (15.2 settled that the command box is the one finder).
- Never a session-language selector — the classic About page's is refused by NFR-14 (`prd.md:1081`, English-only in Release 1).
- Never edit `ui/src/styles/_tokens.scss` and never add a token (Story 15.6 owns it).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| About read | signed-in user; `GET /api/ocupilot/ui/about` | `200` with the thirteen scalars below plus `links{documentation,support,intersystems}` | No error expected |
| One source refuses | a field's call throws or the privilege is absent | That field alone reads `""`; the other twelve answer; the failure is logged | Per-field `Try`, never a 500 |
| DocBook enabled | `Security.Applications` reports `/csp/docbook` present and enabled | `links.documentation` and every help href are the same-origin `/csp/docbook/DocBook.UI.PortalHelpPage.cls?KEY=…` | — |
| DocBook absent, or the check refused | the application is missing/disabled, or reading `Security.Applications` raises `<PROTECT>` | The versioned `https://docs.intersystems.com/<product><major><minor>/csp/docbook/DocBook.UI.PortalHelpPage.cls?KEY=…` form | Degrade, never a fault |
| Help for a screen | `GET /api/ocupilot/ui/help?route=web-apps/applications` | `200` `{"available":true,"href":…}` — the descriptor's `classicPage` class's own `HELPADDRESS`, percent-encoded as the DocBook `KEY` | No error expected |
| Screen with no classic page | a route whose descriptor declares `classicPage` `""` (Home, the agent screens) | `200` `{"available":false,"href":""}`; the client renders no Help control | AD-44 says such a screen declares no classic equivalent — not an error |
| Classic page carries no `HELPADDRESS` | the named class compiles but has no such parameter | `200` `{"available":false,"href":""}` | Absent parameter reads `""`; never a fault |
| Unknown route | `route` is not a built screen's route, or is over `ROUTEMAXLENGTH` (512) | `422`, slug `validation_failed`, code `HELP.ROUTE`, violation on `route` | Validated against `Screen.Registry.Roster` before any lookup; the caller never supplies a class name |
| Malformed query | `route` missing or empty | `422`, code `HELP.ROUTE` | Same ladder |
| Shortcut names no built screen | a roster route with no `built` screen in the mirror (Stage 3's SQL/Classes/Routines/Globals, an unbuilt area) | The row is dropped from the block | AD-37 degrade — never an error, never an empty screen |
| Shortcut the user may not open | `NavigationService.screenVerdict(route).allowed` false | Rendered, focusable, `aria-disabled="true"`, the failed pair's reason inline in the accessible name | Activating it does nothing |
| Stale bundle | `/instance`'s `buildIdentity` differs from the bundle's own hashed `main-*.js` name, both non-empty | A polite `role="status"` prompt offers Reload; the prompt never blocks and never reloads by itself | — |
| Unhashed bundle | either side reads `""` (a dev serve, or an install that deployed no hashed main) | No prompt and no comparison | Absence is not a mismatch |
| About read unreachable | the read fails or the fault classifier reports unreachable | The dialog renders its error state; the status bar and Home are unaffected | `JsonResult` `kind:'error'`; the store keeps its last answer |

</intent-contract>

## Code Map

### Server — reuse, do not re-derive

- `src/OcuPilot/Kernel/Shell/Instance.cls` — **the shape precedent, copy it whole**: `Payload` `:30`, the seven fields `:41-47`, `BuildIdentity()` `:69-79` (reads `Kernel.State.Version.BuildIdentity`), the `ReadSource(pField)` seam `:149-155`, `LogSourceFailure` `:165`, and the header note `:9-10` that neither `%SYS.System` nor `$ZVERSION` needs a namespace switch (AD-16).
- `src/OcuPilot/Api/Instance.cls:14` — `Handle()`, which `Extends OcuPilot.Kernel.Shell.Instance` `:9` and only wraps `..Payload` in `Response.JSON` / `Error.RenderInternal`. Mirror this split exactly.
- `src/OcuPilot/Api/Preferences.cls:47`, `:75` — the caller-own handler with route validation against `Screen.Registry`; `src/OcuPilot/Api/Namespaces.cls:34` — the `%SYS` save/restore precedent (AD-16).
- **Probed on slot B, 2026-09-20 — the eleven carried fields, each callable from `HSCUSTOM` with no namespace switch:** `$ZVersion` → `IRIS for UNIX … 2026.2 (Build 221U)`; `$System.Version.GetISCComponentVersionList($System.Version.GetISCProduct())` → `Health:11.1.0`; `%SYS.System.GetCPFFileName()` → `/durable/iris/iris.cpf` (**this is what classic's `$p($zu(86),"*")` actually returns — a CPF path, not a port**); `%SYS.System.GetGlobalCache()` → `8010`; `GetRoutineCache()` → `800`; `%SYS.Journal.System.GetCurrentFileName()` → `/durable/iris/mgr/journal/20260920.001`; `%SQL.Manager.API.GetPort()` → `1972`; `%Studio.General.GetWebServerPort(.p,.srv,.pre,.u)` → `52773` (**use this, not `%RoutineMgr.GetWebServerPort`, which is `[ Internal ]` and forwards to it**); `$SYSTEM.License.KeyServer()` → `Single`; `KeyCustomerName()` → `InterSystems IRIS Community`; `$System.Security.System.GetDBEncKeyID()` → `""`; `##class(%SYS.NLS.Locale).%New().Name` → `enuw` (verified equal to classic's cross-namespace `^%SYS("LOCALE","CURRENT")` read in the same probe). `%SYS.System.GetGlobalCache`/`GetRoutineCache` are `[ Internal ]` — see Design Notes.
- `src/OcuPilot/Install/Installer.cls:73` `BUILDIDENTITY = "dev"` → written at `:1393` to `Kernel/State/Version.cls:46` `BuildIdentity As %String(MAXLEN = 64)`, saved by `GuardedSave` `:1394`. Live slot B version row today: `SchemaVersion=1, Phase=installed, BuildIdentity="dev"`. `EnsureShellFiles` `:2178` copies the bundle directory; `BundleKey` `:285` resolves the destination application name.
- `src/OcuPilot/Api/StaticHandler.cls` — `RootDirectory()` `:96-105` (bundle root from `$System.Util.DataDirectory()`), `INDEXCACHECONTROL` `:67` (`no-store`), asset cache `:72` (`immutable`). It records no build identity today; nothing reads a manifest.
- `src/OcuPilot/Api/Router.cls` — `<Routes>` `:74-112`, tail `:106-111`, last wrapper `AccountPreferencesUpdate()` `:395`. Append both new routes at the tail; `/ui/*` shares no prefix family with `/instance`, `/account/*` or `/agent/*`, so invariant 3 leaves it unconstrained — still run `check_route_ordering`.
- `src/OcuPilot/Api/Error.cls` — `ReasonForViolation` `:1030` (flat `If` ladder, `Quit ""` at `:1067`); the `PREFERENCES.*` trio `:1231-1248` is the format for a new code. Note `ViolationCodes()` `:1076` sweeps only `AGENT.*`, so a new field code is pinned over the wire, as `AccountPasswordWire` pins the `ACCOUNT.*` pair.
- `src/OcuPilot/Screen/Registry.cls` — `Parameter DECLARATIONKEYS` `:318` (twenty-seven keys; `classicPage` is one, `Descriptor/Base.cls:373` is its accessor and it holds the **class name** of the classic page). `Roster` `:2168`, `DescriptorForRoute` `:2247`. **No help/documentation key exists and none is added.**
- `scripts/check-objectscript.py:1473-1478` — the four `WIRE_MARKERS` a new route's test must all match (`AbsoluteRequest|MakeRequest|RawRequest(`, `AssertEquals( tStatus`, `CONTENT-TYPE|ContentType`, `%FromJSON`), over comment-stripped source.
- `src/OcuPilot/Test/Wire.cls:293-298` — `:297` pins `tObj.buildIdentity` equal to the version row's own value, i.e. passthrough, never the literal `dev`. The installer change therefore keeps it green.

### Client — reuse, do not re-derive

- `ui/src/app/shell/account-menu.ts` — `role="menu"` `:96-97`, `role="menuitem" tabindex="-1"` `:105-106`/`:114-115`, the wrap-around Arrow/Home/End handler `onMenuKeydown` `:212-224`, `menuButtons()` `:278-281` (`querySelectorAll('[role="menuitem"]')`, so the model is already n-item), Escape via `closeAndRefocus()` `:201-206`. The comment at `:210` says "two today, three once Story 15.6 lands" — About makes it three now and 15.6's toggle four; correct that line in place.
- `ui/src/app/shell/dialog.ts` — `Dialog`, `DIALOG_OVERLAY_ID` `:16`, `heading` `:76`, `closeLabel` `:79`, `closed` `:82`, `requestClose()` `:131`, focus return `:98`/`:119-123`, focus trap `:149-165`, `[dialogAction]` slot `:67`. Escape is bound once in `app.ts:143` → `overlays.closeTop()`; never rebind it.
- `ui/src/app/core/instance.ts` — `InstanceIdentity` `:65-73`, the seven parsed fields `:252-258`, `buildIdentity()` **`:174-176`**, whose doc comment already reads "for whatever compares bundles against it later". No consumer reads it today; this story is that consumer. `reset()` `:222`.
- `ui/src/app/core/navigation.ts` — **read only**: `builtScreens()` `:107`, `isListedScreen()` `:123`, `screenForRoute()` `:318`, `withQuery()` `:461`, `NavigationService.screenVerdict(route)` `:615-617`, `Verdict{allowed,failedPair}` `:40-43`, and `formatRequires` `:382` / `formatDeniedScreen` `:394-396` for the gated reason.
- `ui/src/app/core/screens.generated.ts` — **read only**: `ScreenDeclaration` `:325-361`; `classicPage: string` `:348` holds the classic class name (e.g. `:1135` `"%CSP.UI.Portal.DatabaseDetails"`), `labelKey` and `built` give the row its words and its existence.
- `ui/src/app/core/agent-status.ts:229-278` — the instance-backed store variant: a request counter so only the newest read settles, state not cleared on a transport failure. `core/account-preferences.ts` (15.2) is the freshest copy of that shape; `core/shell-state.ts:62`, `:69-74`, `:241-243` is the skeleton.
- `ui/src/app/areas/home/home.page.ts` — the Favorites and Recent items blocks 15.2 added above the tile grid `:113`: each a `role="list"` of `role="listitem"` rows with a navigating button, a per-row control named through `[attr.aria-label]`, and a block-level control. Shortcuts and Links are two more of exactly these.
- `ui/src/app/shell/locator-bar.ts:104-120` — the `<h2 id="ocu-locator-screen">` and 15.2's favorite toggle beside it; the `router.events` bump `:321`. The Help control is its sibling.
- `ui/src/app/shell/instance-notice.ts:64-70` and `shell/classic-link-card.ts:35-37` — the house outbound-anchor pattern (`target="_blank" rel="noreferrer"` plus the external glyph).
- `ui/src/app/core/strings.ts` — **shared-append**: last key `agentComposerCaptionMac` `:1176`, `} as const;` `:1178`; each key preceded by `/** EXPERIENCE.md:N */`; a `//` block names the story and its count (15.2's at `:1118-1121`).
- `ui/tools/strings.test.mjs` — the literal-count band `150..600` at `:462` (512 keys today, so ~23 more fits and the band is **not** widened), forward set equality `:467-471`, the converse `:491-500`, and **unique values** `:504-509` — reuse an existing row rather than repeating a value.
- `ui/tools/client-lint.mjs:274-292`, `:288-293` — a plain `aria-label` must be exactly one interpolation; a composed name uses `[attr.aria-label]` over a published placeholder. Non-ASCII is `\uXXXX`.
- `ui/angular.json:25` `outputHashing: "all"`; `ui/tools/build-output.test.mjs:71`, `:84`, `:88` already pin that a hashed `main-<HASH>.js` and `styles-<HASH>.css` exist. That filename is the build identity; nothing reads it back today.
- `ui/tools/overlay-stack.test.mjs:1-27` — the `node --test` file shape: a header naming what is pinned, an explicit `Mutations (Rule 19)` list, top-level `await import()` of the `.ts` source by absolute path.

### Read-only evidence

- `_bmad-output/planning-artifacts/prds/prd-OcuPilot-2026-09-08/prd.md:999-1003` — FR-73, whose "Done when" is "each listed item is **reachable from the header or Home**". The header is closed, so Home is where Shortcuts and Links land.
- `research/technical-ocupilot-portal-feature-landscape-2026-09-08/feature-catalog.md:63-67` — SH-16, SH-17, SH-18, SH-20. SH-16's "API backing" column proposes `admin-v2 GET /info, /license/key, /journal/settings`; that is a proposal, not what the classic page does, and this story needs no port (see Design Notes). SH-17/18/20 all read `none`.
- `irissys/%CSP/UI/Portal/About.cls:164-177` + `%CSP/UI/Portal/API.cls:14-87` — the fourteen fields and the call behind each. `About.cls:178-196` is the separate session-language selector.
- `irissys/%ZEN/Portal/Application.cls:856-895` — `GetContextLinks`: **seventeen** captioned shortcuts plus three separators, gated on `%DB_IRISSYS:READ,WRITE`, `%DB_IRISSYS:READ`, a namespace test, and `%Admin_Operate:USE` for Background Tasks; `%ZEN/Portal/standardPage.cls:450`/`:466` filters each through `%CSP.Portal.Utils.CheckLinkAccess`.
- `irissys/%CSP/Portal/Home.cls:1807-1816` — `%DrawLinks`: Documentation `/csp/docbook/DocBook.UI.Page.cls` (local, same-origin), Support `http://www.intersystems.com/support/index.html`, InterSystems `http://www.intersystems.com` — three hard-coded literals, `http` not `https`.
- `irissys/%ZEN/Portal/standardPage.cls:1157-1189` — `GetDocURL`: local `/csp/docbook/DocBook.UI.PortalHelpPage.cls?KEY=<HELPADDRESS>` when the `/csp/docbook` application is enabled, otherwise `https://docs.intersystems.com/<product><major><minor>/csp/docbook/DocBook.UI.PortalHelpPage.cls?KEY=…`. Real `HELPADDRESS` values: `%CSP/UI/Portal/Users.cls:14` `"System Administration,Security,Users"`; `TaskInfo.cls:14` `"Home,Task Manager,View Task Schedule,Task Details"`; `MemoryStartup.cls:14` `"Home,Configuration,Memory and Startup"`.
- `ux-designs/.../EXPERIENCE.md:173` — the closed Dialogs enumeration (locate it by the `### Dialogs` heading, not by line number); `:382` the current last Fixed strings row (Story 15.2's); `:663` the polite-`role="status"` and `role="alert"` enumerations; `:665` gated controls stay reachable; `:702` records the classic portal's popup-and-new-window idiom as **rejected** in favour of full-page routes and one-level dialogs. `DESIGN.md:1009` the closed header, `:1023` the read-only status bar, `:898` polish-week additions go above or beside Home's grid.
- `ui/tools/classic-links.mjs` reads ObjectScript descriptors only (`SOURCE_ROOT = src/OcuPilot`), so it never sees a chrome anchor; `client-lint.mjs` checks copy, not `href` origins. `StaticHandler.cls:348-351`'s CSP (`connect-src 'self'`) refuses an off-origin **fetch** and places no restriction on `<a href>` navigation.

## Tasks & Acceptance

**Execution:**

- `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md` — **append** one Fixed strings row immediately after `:382`, publishing the literals below and annotated `[ADDED 2026-09-20 — see the story change log]`. Two further edits **in place and line-neutral**: add About to the `### Dialogs` enumeration (`:173`), and add the reload prompt to the polite `role="status"` enumeration (`:663`). Never insert above `:382`.
- `src/OcuPilot/Kernel/Shell/About.cls` — NEW. `Payload(Output pObject)` emitting `version`, `productComponents`, `configuration`, `databaseCacheMb`, `routineCacheMb`, `journalFile`, `superServerPort`, `webServerPort`, `licenseServer`, `licensedTo`, `encryptionKeyId`, `locale`, `buildIdentity`, and `links{documentation,support,intersystems}`; plus `HelpHref(pRoute, Output pAvailable)`. One overridable `ReadSource(pField)` seam per raw read, each caller wrapping it in its own `Try` and logging through `LogSourceFailure`, exactly as `Instance.cls:143-165` does. `DocBookBase()` reads `Security.Applications` in `%SYS` by explicit save/restore with the restore as the first line of the `Catch` (AD-16) and degrades to the versioned `docs.intersystems.com` form.
- `src/OcuPilot/Api/UiAbout.cls` — NEW. `Extends OcuPilot.Kernel.Shell.About`. `HandleAbout()` and `HandleHelp()`, caller-own (`$Username`, ungated beyond the router), following `Api/Instance.cls` and `Api/Preferences.cls`. `HandleHelp` validates `route` against `Screen.Registry.Roster` and `ROUTEMAXLENGTH` before any lookup and resolves `classicPage` from the descriptor — a class name is never accepted from the caller.
- `src/OcuPilot/Api/Error.cls` — append `HELP.ROUTE`, its reason and its `ReasonForViolation` arm. Append only; touch no existing line.
- `src/OcuPilot/Api/Router.cls` — **shared-append grant**: add `<Route Url="/ui/about" Method="GET" Call="UiAbout"/>` and `<Route Url="/ui/help" Method="GET" Call="UiHelp"/>` as the last lines of `<Routes>`, and their thin wrappers after `AccountPreferencesUpdate()` `:395`. Run `uv run scripts/check-objectscript.py` and quote its result in the commit.
- `src/OcuPilot/Install/Installer.cls` — replace the `BUILDIDENTITY` literal with the identity of the bundle the install deployed: the hashed `main-*.js` filename found under the shell bundle root, `"dev"` when no hashed main exists. Keep the parameter as the fallback so an unhashed deploy still records something; `MAXLEN = 64` already fits a hashed filename. No `SCHEMAVERSION` move — the property's meaning is unchanged.
- `ui/src/app/core/about.ts` — NEW. Framework-free store over `GET /api/ocupilot/ui/about`: `fields()`, `links()`, `load()`, `subscribe()`/`private notify()`, a request counter so a late answer cannot overwrite a newer one, never cleared on a transport failure.
- `ui/src/app/core/help.ts` — NEW. `helpHrefFor(route)` over `GET /api/ocupilot/ui/help`, plus `hasClassicPage(route)` reading the mirror so the control's presence needs no round trip.
- `ui/src/app/core/shortcuts.ts` — NEW. The fixed ordered roster as OcuPilot routes (the classic seventeen mapped to OcuPilot's own screens; an entry naming no `built` screen is dropped). Labels come from each screen's `labelKey` in the mirror, so a shortcut adds no string.
- `ui/src/app/core/build-identity.ts` — NEW. `bundleIdentity()` reads the loaded bundle's hashed `main-*.js` name from the document; `isStale(serverIdentity)` is false whenever either side is empty.
- `ui/src/app/shell/about-dialog.ts` — NEW. `<app-dialog>` over a definition list of the thirteen labeled fields, each label a published string and each value rendered as data. Opens from the account menu; Escape and the shared close both return focus to the trigger.
- `ui/src/app/shell/account-menu.ts` — add **About** as a third `role="menuitem"` above Change password, and correct the `:210` comment. No keyboard work: `menuButtons()` is already n-item.
- `ui/src/app/shell/locator-bar.ts` — add a Help control beside the `screen` segment's `<h2>`, present only for a built screen whose `classicPage` is non-empty, opening the resolved href in a new tab with `rel="noreferrer"`.
- `ui/src/app/shell/stale-bundle-notice.ts` — NEW. A polite `role="status"` region offering Reload, rendered only when `isStale(instance.buildIdentity())`; the comparison runs on every `/instance` settle, so no new timer.
- `ui/src/app/areas/home/home.page.ts` — add a **Shortcuts** block and a **Links** block as siblings of Favorites and Recent items above the tile grid, each a `role="list"` of `role="listitem"` rows reusing Home's own keyboard model. A gated shortcut is rendered `aria-disabled="true"` with its failed pair's reason inline; the three links are anchors.
- `ui/src/app/core/strings.ts` — **shared-append** the new keys at the end in one block with a leading comment naming the story: the dialog title and account-menu item "About"; the thirteen field labels "Version", "Components", "Configuration", "Database cache (MB)", "Routine cache (MB)", "Journal file", "Superserver port", "Web server port", "License server", "Encryption key identifier", "Locale", "Build" (reusing the existing "Licensed to" row rather than repeating its value); "Shortcuts", "No shortcuts available.", "Links", "Documentation", "Support", "InterSystems"; "Help", "Help for this screen"; and DW-3's two — "A newer version of OcuPilot is installed. Reload to use it." and "Reload". Resolve any value that already exists by reusing its key; `strings.test.mjs:504-509` is what refuses a duplicate.
- `ui/src/styles/_components.scss` (**not** `_tokens.scss`, no new token) — rules for the About dialog's definition list, the two new Home blocks and the locator Help control, reusing the metrics 15.2's blocks already use.
- `ui/src/main.ts` and `ui/src/app/app.ts` — construct and provide `About` and the stale-bundle notice, as `AccountPreferences` is provided.
- `src/OcuPilot/Test/UiAboutRead.cls` — NEW. Pins the read: every field present, one source failing degrading that field alone, the DocBook-enabled and degraded href branches, `HelpHref` for a screen with a `classicPage`, for one without, and for a class with no `HELPADDRESS`.
- `src/OcuPilot/Test/UiAboutWire.cls` — NEW. The `check_handler_wire_tests` contract for both routes with all four markers, covering every I/O Matrix row above including the `422 HELP.ROUTE` refusals.
- `ui/tools/about.test.mjs` — NEW. `node --test` over `core/about.ts`, `core/help.ts`, `core/shortcuts.ts` and `core/build-identity.ts`: the late-answer guard, the transport-failure hold, an unbuilt route dropped from the roster, and `isStale` false on either side empty. Carry the `Mutations (Rule 19)` header.
- `ui/src/app/areas/home/home.page.spec.ts`, `ui/src/app/shell/account-menu.spec.ts`, `ui/src/app/shell/locator-bar.spec.ts` — the component legs: Home renders both blocks with their empty states, drops an unbuilt shortcut and keeps a gated one listed and focusable; the account menu has three menuitems and Arrow keys wrap across all three; the Help control is absent for a screen with no classic page.
- `ui/browser/about-help-links.browser-spec.mjs` — NEW. Against the redeployed bundle on the throwaway: open About from the account menu and read one field's value; follow the Help control's href attribute; assert the three link anchors; and drive the stale-bundle prompt by serving a `buildIdentity` the bundle does not match.

**Acceptance Criteria:**

- Given a signed-in user, when they choose About from the account menu, then a one-level dialog shows the carried system-overview fields with the values the instance reports, and Escape returns focus to the account-menu trigger.
- Given any built screen whose descriptor names a classic page, when the user activates its Help control, then a new tab opens that classic page's own documentation address; and given a screen with no classic page, then no Help control is rendered.
- Given Home, when it renders, then the Shortcuts block lists the fixed roster's built screens and the Links block lists Documentation, Support and InterSystems, with a shortcut the user may not open still listed and focusable naming the resource it needs.
- **Integration AC (Rule 1):** Given an instance whose version row carries a bundle-derived build identity, when a browser holds a bundle whose own identity differs, then the shell shows the polite Reload prompt — and when the identities match, or either is empty, no prompt appears. Observable in the browser tier against the deployed bundle; `DW-3`.
- Given the shell, when these four surfaces render, then no request leaves the instance's origin: the only off-origin traffic any of them can cause is a navigation the user clicks.

## Spec Change Log

- 2026-09-20 (lead, spec gate): corrected the redeploy path in `## Verification` from `dist/ocupilot/browser/.` to `dist/ocupilot-ui/browser/.` (`ui/angular.json` sets `outputPath: dist/ocupilot-ui`; the wrong path copies nothing and leaves a stale bundle answering the browser spec), and added the missing `up` action to the `ci-throwaway.sh` invocation.


## Review Triage Log

### 2026-09-20 — Review pass

- verdicts: 49 findings — high 2, medium 12, low 27, false 1, maybe-false 0 (7 intent-alignment rows are descriptive divergences, graded where they carry a claim)
- findings:
  - `[high]` `[patch]` blind-hunter: the installer's `dev` fallback makes `isStale('dev', 'main-X.js')` true, so an instance that deployed no hashed bundle shows every tab a reload prompt no reload can clear — verified by executing `isStale`; the matrix's *Unhashed bundle* row requires the opposite. Fixed in `core/build-identity.ts`: both sides must name a hashed bundle. Test + mutation added; the installer's false doc claim corrected at its origin.
  - `[high]` `[patch]` edge-case: `links.documentation` was `DocBookBase()` — the per-screen help page, which needs a `KEY` and renders nothing without one. Verified live (`.../DocBook.UI.PortalHelpPage.cls`, no KEY). The classic portal's own panel opens `DocBook.UI.Page.cls` (`irissys/%CSP/Portal/Home.cls:1814`, the Code Map's cited source). Added `DOCBOOKHOMEPAGE`/`DocumentationHref`; two existing assertions caught the change and were corrected.
  - `[medium]` `[patch]` blind-hunter: `DocsSiteBase`'s `Catch` still logged per read — the same flood this pass removed from `DocBookEnabled`, on a path that runs on every About and every help read. Log call removed with the same rationale recorded.
  - `[medium]` `[patch]` blind-hunter + edge-case: `HelpLinks` had no generation guard, so an address resolved for a departed principal could land on the next (AD-8). Added `About`'s own `generation` counter.
  - `[medium]` `[patch]` blind-hunter + edge-case: Home's Links block rendered a heading over an empty `role="list"` when the instance answered no address. The block no longer renders at all in that case; a spec row pins it.
  - `[medium]` `[patch]` blind-hunter: the two halves accepted different definitions of "hashed main". Closed by the same fix as the first row — one name shape, applied to both sides.
  - `[medium]` `[patch]` verification-gap: `chooseReload()` had no test host, so an inert Reload button could ship. The browser spec now clicks it and observes a fresh document (a marker, not a navigation counter — `performance` entries reset with the document, which a first attempt got wrong and the run caught).
  - `[medium]` `[patch]` verification-gap: no test activated an *allowed* shortcut; the gated row asserts the URL is unchanged, which a dead handler satisfies. Added a row that clicks one and asserts it navigates.
  - `[medium]` `[patch]` verification-gap + blind-hunter: `App`'s two new sign-out resets were unpinned. Both now asserted in `app.spec.ts` beside their siblings, each with its mutation line.
  - `[medium]` `[patch]` verification-gap: eight of thirteen About members were pinned by key presence only, so swapping the two port accessors stayed green. All thirteen now asserted against their own accessor, plus an explicit "the two ports differ" row.
  - `[medium]` `[patch]` verification-gap: `FIELD_LABELS` was unverified for nine of thirteen rows. The whole label→value map is now asserted.
  - `[medium]` `[defer]` blind-hunter + edge-case: a transient help-read failure suppresses that screen's Help control for the session — `asked` is added before the await and never cleared on failure. Fix needs `helpHrefFor` to distinguish transport failure from unavailable, which changes its contract.
  - `[medium]` `[defer]` blind-hunter: `.claude/rules/objectscript-testing.md:189` still carries the dead `dist/ocupilot/browser` redeploy path this story's change log corrected elsewhere. Agent-context file — deferred by the routing rule, not by judgement.
  - `[medium]` `[defer]` blind-hunter: no component spec for `stale-bundle-notice.ts`, and `app.spec.ts`'s band-order row was not extended to its new sibling. The browser tier covers render, role, copy, no-self-reload and the Reload click; `isStale` is unit-tested.
  - `[low]` `[patch]` blind-hunter: the `!screen.built` filter is unreachable (all 40 mirrored screens are built — measured), so the recorded mutation could not redden. Mutation line corrected to one that does, and demonstrated red.
  - `[low]` `[patch]` blind-hunter: the class header's "every field" claim covered thirteen members where the seam covers twelve. Scoped to `Members()`.
  - `[low]` `[patch]` blind-hunter: `.ocu-about-list`'s comment described wrapping to one column that the rule does not implement. Comment corrected.
  - `[low]` `[patch]` blind-hunter + edge-case: `BundleIdentity`'s `Type = "D"` guard is unreachable (`includedirs = 0`) and `tRS.Close()` was skipped on the three early quits and the catch. Guard removed; the close now runs on every path.
  - `[low]` `[patch]` edge-case: `Test/Instance.cls`'s doc comments still said the row's value and the deployed constant are both `dev`. Corrected at their origin.
  - `[low]` `[patch]` verification-gap (other): `Api/UiAbout.CallerUsername()` was dead, and its doc claimed a per-account check neither route makes. Method removed; the caller-own claim made accurate.
  - `[low]` `[defer]` edge-case: the About dialog renders thirteen blanks for the moment between mount and the read settling — neither answered nor failed. A pending state would close it.
  - `[low]` `[defer]` edge-case: the stale-bundle strip can stand above the blocking instance notice, which is meant to replace the surface.
  - `[low]` `[defer]` blind-hunter: the prompt's `role="status"` region is inserted rather than kept mounted and populated, which is commonly not announced; EXPERIENCE.md now publishes it as a polite status.
  - `[low]` `[defer]` blind-hunter: nothing executes the real `OcuPilot.Kernel.Audit.Log.Error` call for the new `uiabout` subsystem — the fixture overrides the seam without `##super`.
  - `[low]` `[defer]` verification-gap: `Installer.BundleIdentity`'s fallback branch has no test in any tier; reaching it needs an installer fixture subclass or an install with the bundle directory emptied.
  - `[low]` `[defer]` verification-gap (other): Home's Shortcuts empty state is unreachable from the shipped mirror, so `STRINGS.shortcutsEmpty` is published but not displayable. Removing it means editing the published table; left as the harmless branch it is.
  - `[low]` `[defer]` blind-hunter: DESIGN.md `:898`'s polish-week enumeration was not extended with Shortcuts and Links.
  - `[low]` `[reject]` blind-hunter: the seven unresolved `SHORTCUT_ROUTES` are forward declarations for unbuilt screens; no test can tie a route to a screen that does not exist, and the file says so.
  - `[low]` `[reject]` blind-hunter: the deterministic tie-break between two hashed mains is untested on both sides — `EnsureShellFiles` clears the directory before copying, so reaching two costs more than the guard is worth.
  - `[low]` `[reject]` blind-hunter: the browser spec proves three absences with fixed sleeps. It is the repo's own idiom for an absence, and polling for a thing that must not appear is not better.
  - `[low]` `[reject]` blind-hunter: `rewriteBuildIdentity`'s interception handler has no failure path — a rejected fetch surfaces as a navigation timeout, which fails the test visibly.
  - `[low]` `[reject]` blind-hunter: no unauthenticated or wrong-verb wire coverage for the two routes. `OnPreDispatch` authenticates every route and no sibling handler re-tests it.
  - `[low]` `[reject]` blind-hunter: `DOCSSITEFALLBACK` names `irislatest` rather than the for-Health tree. Reachable only if the version read throws, and the fallback is a working docs address.
  - `[low]` `[reject]` blind-hunter: `IsRosterRoute` keeps scanning after it matches — 40 screens, once per screen per session; an early exit inside a `Try` costs more than it saves.
  - `[false]` `[reject]` blind-hunter: `core/help.ts` and `core/shortcuts.ts` import `'./navigation.ts'` with an extension "with no stated reason". It is the established convention in `core/` — ten files there already do it, because `node --test` type-strips and needs the explicit extension.
  - `[low]` `[reject]` edge-case: `Installer.BundleIdentity`'s doc claim that the fallback is never compared — the same defect as the first row, and closed by its fix rather than separately.
  - `[low]` `[reject]` edge-case: "both empty-state paths ship unexercised" — the Links half is fixed above; the Shortcuts half is the deferred row above.
  - `[low]` `[reject]` edge-case: the `^||%FileList` leak — the same finding as the `tRS.Close()` patch above.
  - `[low]` `[reject]` intent-alignment 3.1: three matrix rows are exercised behind a fixture subclass rather than at the endpoint. The classes say so in their headers, and the seam is the only way to make a healthy instance refuse.
  - `[low]` `[reject]` intent-alignment 3.2: the `dev` fallback contradicts the *Unhashed bundle* row — the first row's finding, patched there.
  - `[low]` `[reject]` intent-alignment 3.3: whether the "never removed" clause binds Links entries. The gating clause is about privilege, which an outbound URL does not carry; the empty-heading consequence is patched above.
  - `[low]` `[reject]` intent-alignment 3.4: the matrix's example route `web-apps/applications` names no built screen (the spelling is `web-applications/list`). The fix would edit the frozen intent block.
  - `[low]` `[reject]` intent-alignment 3.5: the gated shortcut's reason is asserted as text content, not as a computed accessible name — jsdom computes no accname, and the content is the accname's input.
  - `[low]` `[reject]` intent-alignment 3.6: `DocBookEnabled` sits outside the `ReadSource` seam and switches namespace. Both are stated in the class header; the matrix asks only that it degrade.
  - `[low]` `[reject]` intent-alignment 3.7: the stale-bundle prompt has no component-level test — the deferred row above.
  - `[low]` `[reject]` intent-alignment 3.8: no divergence found; every Always/Never constraint observed.
  - `[low]` `[reject]` blind-hunter: `buildIdentity` is outside the per-field seam — the doc-scope patch above covers the claim; putting a version-row read behind a source seam would be wrong.
  - `[low]` `[reject]` edge-case: About's pending-state blanks — the deferred row above.
  - `[low]` `[reject]` edge-case: the stale strip over the blocking notice — the deferred row above.


- **Patched (high, in-story): the refused DocBook check wrote an error line per About read.**
  `DocBookEnabled` reads `Security.Applications` in `%SYS`; a caller without read on that database
  -- the ordinary case for the least-privileged operators AD-8 is written for -- raises `<PROTECT>`,
  and the `Catch` logged it through `LogSourceFailure`. Home issues the About read on arrival, so
  that was one error line per Home render into the log OcuPilot renders on its own screens.
  Measured on the throwaway: 55 such lines, 30 of the last 300, which changed the live tail's
  severity mix enough to redden Story 6.14's `messages-log.browser-spec.mjs` AC5 and AC6. Fixed by
  not logging a refusal: it has the same correct answer as an absent application, which is the one
  I/O matrix row both take. Pinned by `TestARefusedDocBookCheckDegradesWithoutLogging` over a new
  `ReadDocBookApplication` seam, which is also what finally drives that row's `<PROTECT>` half.
- **Patched (matrix audit): the *About read unreachable* row had no test for its rendered half.**
  The store's parking was pinned in `ui/tools/about.test.mjs`; nothing asserted that the dialog
  shows its error state, and `stubAbout`'s `unreachable` seed had no caller. Added
  `ui/src/app/shell/about-dialog.spec.ts` (4 rows, 2 mutations below).
- **Patched (low): a component row asserted the opposite of its name.** "Shortcuts shows its empty
  state when the roster resolves nothing" asserted that the list, not the empty state, renders --
  the empty branch is unreachable from a component spec, since `shortcutScreens()` reads the real
  mirror. Renamed to state what it checks; the roster-level branch stays in `about.test.mjs`.
- **Carried, not this story's:** `scripts/smoke.sh --container ocupilot-slot-b` fails `shell` and
  `deeplink` because that instance's `/durable/iris/csp/ocupilot` has been empty since 2026-09-15
  -- slot B is compiled into, never installed into. Green on the throwaway, where the install runs.

## Design Notes

**Governing ADs (Rule 6):** **AD-5** (shell chrome declares no screen descriptor — About, Help, Shortcuts and Links are chrome, as 15.1's account menu and 15.2's Home blocks were), **AD-36** (the shell-chrome exception to the declared read: a caller-own handler, never a declared read, never a tool's view), **AD-44** (the descriptor's `classicPage` is the classic **class name**, which is exactly what a `HELPADDRESS` lookup needs; a list archetype never links out, so the shortcuts name OcuPilot routes), **AD-11 rule 4** and **AD-47** (nothing here fetches off-origin; no CDN; the anchors are user navigations) and **AD-38** (the version row's stamp is what a client compares against). Also binding: AD-8, AD-12, AD-16, AD-19, AD-20, AD-21, AD-39, AD-43. Conventions rows: *REST route ordering*, *Error shape*, *Client asset homes*, *Tests*, *ObjectScript naming*.

**Why a new route rather than widening `/instance`.** `/instance` is read at sign-in and on the connectivity probe and its seven fields are pinned as a set (`session.test.mjs:1986`); About is opened on demand and needs thirteen more reads. A second caller-own chrome route keeps the hot read lean and follows the `/instance`, `/navigation`, `/namespaces`, `/agent/context` precedent. Three of the thirteen are literally the calls the header and status bar already make (`$ZVersion`, `$SYSTEM.License.KeyCustomerName()`, and the version row's stamp), which is AC1's "the same calls" satisfied by extending the idiom rather than by re-reading one payload **(inference** — AC1 read as the identical `/instance` body would reach 2 of the 14 fields; the classic page's own fourteen are all direct in-process system calls, which is the idiom `Instance.cls` uses**)**.

**Eleven of the fourteen carried; three declined, with the reason per field.**

- *Mirroring* — declined. Its classic accessor is the Zen UI class `%CSP.UI.System.Mirror`. A supported replacement does exist (`$SYSTEM.Mirror.GetStatus()`, probed `NOTINIT` on slot B), but mirror state is Story 15.4's System Information panel, read from the dashboard route; About would be a second source for one value.
- *Cluster support* — declined. Its only accessor, `%SYS.ClusterInfo.NodeStatus()`, is `[ Internal ]` and returns an untranslated English sentence rather than data, so carrying it would put unpublished vendor prose on an OcuPilot surface.
- *Time system started* — declined. Classic computes it inside the Zen page itself (`About.cls:221`, `$zh`-based), and uptime is Story 15.4's panel. One source.
- *Session language selector* — out of scope: `prd.md:1081` NFR-14 makes the interface English-only in Release 1, and `prd.md:100` excludes users needing another language.
- Two carried fields use `[ Internal ]` accessors — `%SYS.System.GetGlobalCache()` and `GetRoutineCache()`, the classic page's own calls, on the class `Instance.cls` already calls twice. Accepted deliberately for a display-only integer, because the per-field `Try` makes a vendor change degrade that one field to blank rather than fail the read. `%SQL.Manager.API` is a hidden class (absent from the export) but its `GetPort()` answered on slot B.

**Help without touching the mirror.** A per-screen documentation key would be the AD-5-shaped answer, but it would edit `Screen/Registry.cls` `DECLARATIONKEYS`, `ui/tools/screen-mirror.mjs`'s hand-written `DECLARATION_KEYS`, `Test/DeclarationCorpus.cls` and — because `--check` compares the whole file byte for byte — regenerate `ui/src/app/core/screens.generated.ts`, which **Epic 5 has modified**. The design avoids the collision instead: `classicPage` already crosses to the client, and the classic class's own `HELPADDRESS` is read on the instance at call time, so the descriptor stays the single source and no mirror is regenerated. `core/navigation.ts` and the mirror are consumed read-only. No Clarification is needed.

**Placement, and why it is not a free choice.** The header is closed at three children (DESIGN.md `:1009`, pinned by `header.spec.ts:130-131`) and the status bar is read-only but for the account menu (DESIGN.md `:1023`), so FR-73's "reachable from the header or Home" resolves to Home for Shortcuts and Links, which DESIGN.md `:898` already designates for polish-week additions. About is a dialog joining `EXPERIENCE.md:173`'s enumeration, as Story 15.1's change-password dialog did. SH-18's word "drop-down" describes the classic portal, whose popup idiom `EXPERIENCE.md:702` records as rejected; a Home block reusing 15.2's list model needs no fifth copy of the arrow-key menu model (four exist: `account-menu.ts:212`, `data-table.ts:817`, `command-bar.ts:641`, `:743`).

**Two source corrections.** `feature-catalog.md:65` says sixteen shortcuts; `%ZEN/Portal/Application.cls:856-895` declares seventeen captions plus three separators. Classic's "Configuration" field, `$p($zu(86),"*")`, returns the **CPF file path**, not a port; `%SYS.System.GetCPFFileName()` is its supported equivalent.

**DW-3, addressed in both halves.** The server half was delivered but the stamp is a hand-edited literal and the client reads nothing. One source fixes both: the deployed bundle's hashed `main-*.js` filename, which `outputHashing: all` guarantees and `build-output.test.mjs:71` already pins — the installer records it, the running client reads its own from the document. No generator and no second artifact to drift; either side empty means no comparison. `Wire.cls:297` pins passthrough rather than the literal, so it stays green — grep for any assertion on the literal `dev` before changing the parameter.

**Contended and out-of-footprint paths, declared (Rule 11).** Shared-append, epic-wide grant: `src/OcuPilot/Api/Router.cls`, `ui/src/app/core/strings.ts`, `ui/src/styles/_components.scss`, and EXPERIENCE.md's Fixed strings table after `:382` (tail only; the two in-place edits at `:173` and `:663` are line-neutral, the shape 15.2 used at `:662`). Shared-create: `src/OcuPilot/Test/UiAboutRead.cls`, `UiAboutWire.cls`, and `ui/src/app/core/{about,help,shortcuts,build-identity}.ts`. In Epic 15's own footprint: `ui/src/app/shell/account-menu.ts`, `src/OcuPilot/Api/UiAbout.cls` (`Api/Ui*.cls`), `ui/src/styles/**`. **To be reported under `footprint_extensions:`** — `src/OcuPilot/Kernel/Shell/About.cls` (new), `src/OcuPilot/Api/Error.cls`, `src/OcuPilot/Install/Installer.cls`, `ui/src/app/shell/locator-bar.ts`, `ui/src/app/shell/about-dialog.ts` (new), `ui/src/app/shell/stale-bundle-notice.ts` (new), `ui/src/app/areas/home/home.page.ts` (+ spec), `ui/src/main.ts`, `ui/src/app/app.ts`, `ui/tools/about.test.mjs`, `ui/browser/about-help-links.browser-spec.mjs`. None is on Epic 5's carve list (`shell/panel*`, `proposal-card*`, `reply*`, `tool-call-card*`, `context-chip*`, `core/proposal-view.ts`, `core/turn.ts`); `ui/browser/**` is **shared-create** (orchestrator ruling 2026-09-20, replacing the earlier Clarification-regardless carve): a new uniquely-named spec file there is this epic's and is reported under `footprint_extensions:`; modifying an existing file in that directory stays a Clarification.

**Ledger inbox (Rule 17):** `DW-3` is addressed — the Integration AC above and the *Stale bundle* / *Unhashed bundle* matrix rows are its two halves, and its copy is published in the Fixed strings row.

**Consumes:** `ui/src/app/core/api.ts` and `violations.ts`; `ui/src/app/core/instance.ts` (`buildIdentity()`); `ui/src/app/core/navigation.ts` (`builtScreens`, `screenForRoute`, `isListedScreen`, `NavigationService.screenVerdict`, `formatRequires`) and `core/screens.generated.ts` (`classicPage`, `labelKey`, `built`) — both **read only**; `ui/src/app/shell/dialog.ts` and `core/overlay-stack.ts`; `OcuPilot.Screen.Registry.Roster` / `DescriptorForRoute`; `OcuPilot.Kernel.Shell.Instance`'s `ReadSource` idiom; `OcuPilot.Api.Error`.

**Consumed-by:** Story 15.4 (its System Information panel is a fifth Home block beside these two and owns uptime and mirror state, which About declines); Story 15.6 (the theme toggle becomes the account menu's fourth `role="menuitem"`, with no keyboard work).

## Verification

**Slot B.** Every IRIS MCP call carries `server: "ocupilot-slot-b"`; the dev container is `ocupilot-slot-b`. Anything that mutates shared runtime state — the install-path change, the two new routes' wire tests, the browser spec — runs on the **throwaway** `bash scripts/ci-throwaway.sh up --dir /tmp/ocupilot-b-ci --project ocupilot-b-ci --web 52777 --super 1976`, torn down only by whoever ran its `up`. A browser run exports both `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777` and `OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci`.

**Commands:**

- `uv run scripts/check-objectscript.py` — expected: green, including `check_route_ordering` over the two appended routes and `check_handler_wire_tests` finding `Test/UiAboutWire.cls` for both.
- `cd ui && npm test` — expected: `node --test tools/*.test.mjs` green including the new `about.test.mjs` and a `strings.test.mjs` whose new keys pass inside the unchanged `150..600` band, then the Angular runner green including the Home, account-menu and locator-bar legs.
- `cd ui && npm run build` — expected: all six `prebuild` checkers pass. `screen-mirror.mjs --check` must stay green **with no regeneration**, which is the evidence that no descriptor key was added. `client-lint.mjs` is the one that bites: one interpolation per plain `aria-label`, `[attr.aria-label]` for a composed name, `\uXXXX` for non-ASCII, no hardcoded color.
- `bash scripts/lint-docs.sh` — expected: green over the appended EXPERIENCE.md row and the two in-place edits.
- Compile through the IRIS MCP tools against `ocupilot-slot-b`, then run `OcuPilot.Test.UiAboutRead` and `OcuPilot.Test.UiAboutWire` **one class per call**, waiting for each to land in `%UnitTest_Result` before sending the next.
- `bash scripts/smoke.sh --container ocupilot-slot-b --user _SYSTEM --password SYS` — expected: non-zero executed checks, all passing, after the `BUILDIDENTITY` change.
- `cd ui && npm run build`, `docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`, then `npm run test:browser` — expected: green including `about-help-links.browser-spec.mjs`. A browser result read before the rebuild and redeploy is not evidence.

**Mutations (Rule 19)** — each applied, observed red, reverted, and the file confirmed byte-identical with `cmp` afterwards:

- AC1: `mutation: drop journalFile from Kernel/Shell/About.Members, recompile About and every descendant -> OcuPilot.Test.UiAboutWire` — **red**, `TestTheAboutReadCarriesEveryMemberOverTheWire` failing `AssertTrue: the body carries journalFile` (1 of 7).
- AC2: `mutation: make Kernel/Shell/About.HelpHref set pAvailable=0 for a route whose descriptor names a classic page -> OcuPilot.Test.UiAboutRead` — **red**, `TestAScreenWithAClassicHelpAddressResolvesIt` (1 of 10). Client half, since `locator-bar.spec.ts` drives a stubbed `HelpLinks` and cannot see a server change: `mutation: make LocatorBar.helpControl return false -> locator-bar.spec.ts` — **red**, "a screen whose classic page publishes a help address gets a Help control".
- AC3: `mutation: drop the screenVerdict filter from Home's Shortcuts rows -> home.page.spec.ts` — **red**, "a shortcut the user may not open stays listed and focusable".
- Integration AC (DW-3): `mutation: make core/build-identity.ts isStale() return false unconditionally, rebuild, redeploy -> about-help-links.browser-spec.mjs` — **red**, the mismatch leg timing out on `.ocu-stale-bundle`.
- AC5 (no off-origin request): `mutation: make Home's Links block fetch the support URL as well as linking to it, rebuild, redeploy -> about-help-links.browser-spec.mjs` — **green at first, and that is the finding**: the bundle's own `connect-src 'self'` refuses the fetch in the renderer (AD-47), so no request is issued and a request-list assertion cannot see it. The leg now watches the console for that refusal beside the request list, and the same mutation is **red** on it: `and none of these surfaces was refused for trying: ["Refused to connect to 'https://www.intersystems.com/support/index.html' ... \"connect-src 'self'\""]`.

Three more, from this pass's patches (same discipline; `cmp` byte-identical after each revert):

- Matrix *DocBook absent, or the check refused*: `mutation: log the refusal from Kernel/Shell/About.DocBookEnabled's Catch again, recompile About and its four descendants -> OcuPilot.Test.UiAboutRead` — **red**, `TestARefusedDocBookCheckDegradesWithoutLogging` on `AssertEquals: and writes no log line; AssertEquals: and logs nothing at all` (1 of 11).
- Matrix *About read unreachable*: `mutation: make AboutDialog.unanswered return about.failed() alone -> about-dialog.spec.ts` — **red**, "a failed read after an answer keeps the answer on screen" (1 of 4).
- Matrix *One source refuses*, rendered half: `mutation: filter empty values out of AboutDialog.resolved -> about-dialog.spec.ts` — **red**, "a member the instance could not report keeps its label and renders empty" (1 of 4).

A single-file `npx vitest run` cannot host a mutation here: the Angular `@angular/build:unit-test`
builder supplies the test environment, so a bare vitest invocation fails every spec in the project
on `Cannot read properties of null (reading 'ngModule')`. Both client mutations above were run
through `npx ng test --include <spec>`.

Two more from the review pass's patches:

- Reload is not inert: `mutation: make StaleBundleNotice.chooseReload a no-op, rebuild, redeploy -> about-help-links.browser-spec.mjs` — **red**, the mismatch leg timing out at 32 s on the navigation that never happens. (It also reddens the matching leg, because the mutated build has its own hash while the version row still names the installed one — the redeploy-without-reinstall case, where "stale" is the right verdict.) Reverted, rebuilt to the same `main-PKXZPYYT.js`, redeployed, 6/6 green.
- The shortcuts roster's recorded mutation was corrected and re-demonstrated: `mutation: make shortcutScreens return SHORTCUT_ROUTES.map(screenForRoute) without dropping the nulls -> ui/tools/about.test.mjs` — **red**, 2 rows. The line previously recorded (`drop the !screen.built filter`) could not redden: every one of the 40 screens the shipped mirror declares is built (measured), so the seven unresolved roster routes return null, and null is what the filter's other half rejects.

**Manual checks:**

- Restart the throwaway after a bundle rebuild while a tab stays open, and confirm the Reload prompt appears politely and never reloads by itself. Automated by `about-help-links.browser-spec.mjs`'s mismatched-identity leg; the manual run is what confirms the real restart path.

## Auto Run Result

Status: done
Blocking condition: none

**What this pass built.** Server: `Kernel/Shell/About.cls` (twelve per-field reads behind one
`ReadSource` seam, `HelpHref`, the DocBook decision and the three links), `Api/UiAbout.cls`, two tail
routes in `Api/Router.cls`, `HELP.ROUTE` in `Api/Error.cls`, and `Installer.BundleIdentity` replacing
the `BUILDIDENTITY` literal on the version row. Client: `core/{about,help,shortcuts,build-identity}.ts`,
`shell/{about-dialog,stale-bundle-notice}.ts`, About as the account menu's third item, the locator
bar's Help control, and Home's Shortcuts and Links blocks. Twenty-three strings, published in
EXPERIENCE.md's Fixed strings table first.

**Files changed** (37): `Kernel/Shell/About.cls`, `Api/UiAbout.cls`, `Api/Error.cls` (append),
`Api/Router.cls` (two tail routes + wrappers), `Install/Installer.cls` (`BundleIdentity`),
`Test/UiAbout{Fixture,Read,Wire}.cls`, `Test/Instance.cls` (stale `dev` claims corrected);
`core/{about,help,shortcuts,build-identity}.ts`, `shell/{about-dialog,about-dialog.spec,stale-bundle-notice}.ts`,
`shell/{account-menu,locator-bar}.ts` + specs, `areas/home/home.page.ts` + spec, `app.ts`, `main.ts`,
four DI-provider spec additions, `testing/about.ts`, `core/strings.ts` (tail append),
`styles/_components.scss` (tail append), `tools/about.test.mjs`,
`browser/about-help-links.browser-spec.mjs`, `browser/change-password.browser-spec.mjs` (Story 15.1's
own file: About became the menu's first item, so its keyboard path reaches Change password by
ArrowDown), and EXPERIENCE.md (one row after `:382`, two line-neutral edits).

**Review findings.** 49 findings across four layers: 2 high and 9 medium patched, 8 low patched,
10 deferred to frontmatter, 20 rejected with a recorded reason (one `false`). Every row is in the
`## Review Triage Log` above. The two highs were real defects the tests had not reached: the
installer's `dev` fallback made `isStale` report every such instance permanently stale, and the
links panel's Documentation entry opened the per-screen help page with no `KEY`. A third defect,
found by verification rather than by a layer, is in the triage log's first rows: a refused DocBook
check wrote one error line per About read — one per Home render — into the log OcuPilot renders on
its own screens, which reddened Story 6.14's two `messages-log` browser legs. Both now pass.

**Follow-up review recommended: true.** Named risk: `<app-stale-bundle-notice />`'s placement in the
frame is pinned only by the browser tier — `app.spec.ts`'s band-order row was not extended to it and
there is no component spec — and `Installer.BundleIdentity`'s fallback branch has no test in any
tier. Both are in `deferred:`.

**Verified** (slot B dev + the `ocupilot-b-ci` throwaway, all on the final tree):
`uv run scripts/check-objectscript.py` 0 problems over 513 files and `test_check_objectscript.py`
126 green; `OcuPilot.Test.UiAboutRead` 11/11 and `OcuPilot.Test.UiAboutWire` 7/7, one class per call;
`cd ui && npm test` 1168 `node --test` + 712 component tests over 51 files; `npm run build` green
with `screen-mirror.mjs --check` **up to date and no regeneration**; `lint-docs.sh` green;
`smoke.sh --container ocupilot-b-ci` PASSED, 45 executed, 45 passed, stamp `main-PKXZPYYT.js` equal
to the deployed bundle. Browser: the full suite 197 tests, 195 pass, 2 fail — the inherited DW-1169
`context-chip` flake, and one assertion of this story's own that the run caught and that is fixed;
the story's six legs then ran 6/6 green against the rebuilt and redeployed final bundle.
`smoke.sh --container ocupilot-slot-b` still fails `shell` and `deeplink`: that instance's
`/durable/iris/csp/ocupilot` has been empty since 2026-09-15 because it is compiled into and never
installed into. Unrelated to this story and green wherever the install actually runs.

**Residual risks.** The ten `deferred:` entries, of which three are medium: a transient help-read
failure suppresses that screen's Help control for the session; `.claude/rules/objectscript-testing.md`
still documents the dead `dist/ocupilot/browser` redeploy path; and the stale-bundle prompt has no
component-level host.
