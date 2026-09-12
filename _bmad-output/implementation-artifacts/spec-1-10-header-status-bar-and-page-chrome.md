---
title: 'Story 1.10 — Header, status bar and page chrome'
type: 'feature'
created: '2026-09-12'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-1-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-1-9-the-screen-descriptor-registry-and-privilege-driven-navigati.md'
  - '{project-root}/.claude/rules/objectscript-testing.md'
warnings: ['oversized']
deferred:
  - summary: 'DESIGN.md:1017 draws the command-box placeholder at 80% on-shell; epics.md:1351 and DESIGN.md:1007 say no header text is drawn below 100%. Built at 100% per the AC; one ruling wanted.'
    evidence: 'DESIGN.md:1007 (rule + 3.60:1 at the gradient end) against DESIGN.md:1017 (80%, 7.22:1). Same family as DW-127.'
    location: 'ui/src/app/shell/command-box.ts'
    severity: 'medium'
  - summary: 'The status bar carries no per-segment accessible labels: EXPERIENCE.md has no Fixed-strings rows for Server, Instance or Licensed to.'
    evidence: "Segments render as bare values inside the contentinfo landmark. Inventing four labels would be new copy; DW-126's root cause."
    location: 'ui/src/app/shell/status-bar.ts'
    severity: 'low'
  - summary: 'The lockup accessible name diverges: DESIGN.md:287/:1011 say alt="OcuPilot", EXPERIENCE.md:316 says "OcuPilot — Home".'
    evidence: "Built per epics.md:1350, which matches EXPERIENCE.md."
    location: 'ui/src/app/core/strings.ts'
    severity: 'low'
  - summary: 'EXPERIENCE.md:321 lists a command-bar sort control; DESIGN.md:1037 puts sorting in the table header and specifies no such control.'
    evidence: 'No visual spec exists for a command-bar sort; the slot is declared and left unrendered.'
    location: 'ui/src/app/shell/command-bar.ts'
    severity: 'low'
  - summary: 'A last-update stamp is specified in both the command bar (DESIGN.md:1037) and the status bar (DESIGN.md:1021, EXPERIENCE.md:318) with no rule for which renders.'
    evidence: 'Neither document says whether both render at once. Moot until 1.14 supplies a value.'
    location: 'ui/src/app/shell/command-bar.ts'
    severity: 'low'
  - summary: "DW-138's rendered-geometry half is not falsifiable in jsdom, which computes no layout."
    evidence: 'Pinned structurally by app.spec.ts and a source-shape test; the geometry is the lead browser measurement named under Manual checks.'
    location: 'ui/src/styles/_components.scss'
    severity: 'medium'
---

<intent-contract>

## Intent

**Problem:** The shell has a rail, a side bar and a routed outlet, and nothing else — no frame around them. A signed-in user cannot see which server, instance or namespace they are about to change, where they are inside the portal, or what the current screen can do; the account menu floats outside any band; and the rail's own layout is broken because no element in the tree has a height. Six ledger entries of shell residue wait on the bands this story builds.

**Approach:** Build the page frame — header, status bar, locator bar, command bar and command box — as standalone `OnPush` shell components around the existing rail, side bar and outlet, driven by the descriptor mirror and the navigation map rather than by per-screen wiring. Extend `GET /api/ocupilot/instance` with the three status-bar fields no endpoint returns today, and add one overlay stack so Escape has a single authority across the band.

## Boundaries & Constraints

**Always:** Chrome reads the screen descriptor mirror and the navigation map — never a hand-kept list (AD-5). Privilege verdicts come from the server per call and gated entries stay listed, focusable and `aria-disabled="true"`, never `disabled`, never hidden (AD-8). Colours come only from `ui/src/styles/` tokens and user-facing text only from `ui/src/app/core/strings.ts`; both are lint-enforced. Components are standalone, zoneless, `OnPush`, signal-based, with paren-free getters for the control-flow blanker (AD-19). Every API path is absolute through `ApiService` (AD-20). Non-ASCII in source is a `\uXXXX` escape (Rule 14). Sign-out means the instance, not the tab — the account menu must not imply otherwise (AD-28).

**Never:** No namespace list, selection or re-fetch — 1.11 owns the switch's behaviour; this story places its slot. No Home page, no area tiles — 1.12. No connectivity probe and no retry schedule — 1.13. No auto-refresh timer or stamp value — 1.14. No classic-portal link-out — 1.15. No skip link (no AC names it, and it needs a string neither document authorizes). No new colour token: the four server-flag pairs and `--ocu-shell-edge` already exist. No growth of `REQUIRED_ALONGSIDE_TABLE`, which stays at three. No planning-artifact edit to settle DW-126 or DW-127.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Instance reports a flag | `$SYSTEM.Version.SystemMode()` = `TEST` | `/instance` returns `serverFlag:"TEST"`; the badge reads `Test` in the test pair, in the status bar only — never the header | none |
| **DW-10** no flag set | `SystemMode` = `""` (this container's value) | `serverFlag:""`; **no badge renders**; every other segment unchanged | none |
| **DW-10** flag outside the four | `^%SYS("SystemMode")` written directly to e.g. `STANDBY` | the badge renders the value verbatim in the `restrained` pair, never as one of the four | none |
| A status-bar source fails | `KeyCustomerName()` throws or is refused | that field is `""`, its segment is absent, the response is still 200 | per-field `Try`; detail through `Error.LogError`, never a 500 |
| **DW-103** rejected sign-in | `form` → `probing` → `form-rejected` | user name kept, password cleared, focus on the password field, `authSignInFailed` in `role="alert"` | none |
| **DW-103** sign-out | Sign out chosen; menu and trigger unmount together | focus lands on the sign-in card's user-name field | none |
| **DW-109** outside dismissal | menu open; pointerdown or focus moves outside it | menu closes, `aria-expanded="false"`, focus stays where the user put it | none |
| **DW-137** two overlays | command box open over an open side bar | first Escape closes the box and restores focus; second collapses the side bar; a third returns focus to content | none |
| **DW-134** Ctrl+Shift+B | chord with `shiftKey` set | no toggle; the side bar's open state and stored preference are unchanged | none |
| **DW-134** scoped navigation | URL `/logs?ns=USER`; a rail or side-bar entry is activated | the new URL still carries `?ns=USER` | none |
| **DW-134** Home collapse | Home activated with the side bar open | the side bar collapses for Home; `ocupilot.side-bar.open` still reads the user's remembered `true` | none |
| **DW-137** rail tooltip | pointer rests on a rail item | the tooltip reveals after `--ocu-motion-tooltip-delay` (300ms); 0ms under reduced motion | none |
| Command box opens | Ctrl/Cmd+K on any route | `role="combobox"` with `aria-expanded`, `aria-controls`, `aria-activedescendant`; results grouped Screens and Actions; a polite `<n> screens, <m> actions` | typed text never becomes a turn; no avatar |
| Command box, gated screen | user lacks the screen's pair | the row is listed and non-selectable with its failed pair inside the accessible name, no tooltip | none |
| Command box, no match | filter matches nothing | `commandBoxNoMatch` as a polite status; the listbox is empty | none |
| Command bar, nothing selected | any screen, no row selection | row actions are `aria-disabled="true"` with `privilegeSelectRowFirst` on hover and focus | none |
| Locator, no selection | a screen route with no entity id | area and screen segments render and navigate; the `code` entity segment is absent; namespace is never a segment | none |

</intent-contract>

## Code Map

Anchors verified 2026-09-12 against the working tree, the live instance and the vendor source. **Extend, never duplicate.**

- `src/OcuPilot/Api/Instance.cls` — `Payload()` `:26-40` builds the four current fields; the seams to copy are `BuildIdentity()` `:80`, `InstanceName()` `:93`, `InstanceVersion()` `:99`; `LogDetail()` `:107`. `Parameter LOGSUBSYSTEM` `:15`. No privilege gate of its own — `Router.OnPreDispatch` `:152-198` already refused anonymous and non-admin callers.
- `src/OcuPilot/Test/Instance.cls` — 15 methods; the payload-shape tests to extend are `TestThePayloadCarriesTheInstanceNameAndVersion` and `TestThePayloadCarriesTheVersionRowsBuildIdentity`. Fixtures `Test/InstanceFixture.cls`, `Test/PortFixture.cls`.
- `irissys/%SYSTEM/Version.cls:344-374` (read-only reference) — `SystemMode()` doc names exactly `LIVE`, `TEST`, `DEVELOPMENT`, `FAILOVER`, returns `""` when unset; the setter upper-cases and `$MATCH`-normalises anything else to `""`. Live probe on `ocupilot-iris`, sample = this one container: `SystemMode()` = `""`, `KeyCustomerName()` = `InterSystems IRIS Community`, `GetNodeName()` = `B066BA383583`, `GetInstanceName()` = `IRIS`.
- `ui/src/app/app.ts` — template `:49-65`; `:49` is the placeholder header line **read out of the bundle by `ui/tools/build-output.test.mjs:221-230`/`:253-270`** (first `{{ STRINGS.<key> }}` and first `class="…"`); `<app-account-menu />` `:51`; `.ocu-shell` `:53`; getters `:99-105`. `ui/tools/session.test.mjs:1631-1712` brace-matches the `@if` nesting and `:1636` requires the literal to end exactly `` `,\n}) ``.
- `ui/src/app/shell/account-menu.ts` — the exemplar and the DW-109 site: `(keydown.escape)` on the **wrapper div** `:50`, `aria-haspopup`/`aria-expanded` `:56-57`, `role="menu"` `:64`, `id="ocu-account-trigger"` `:53` (DW-111's document-global id — this story is its named reopen trigger), open `effect()` `:108-111`, `toggle()` `:118-124`, `chooseSignOut()` `:141-144`, focus-before-removal `:130-134`.
- `ui/src/app/shell/sign-in.ts` — DW-103 site: `@if (waiting)` `:55` over `isWaiting()` (`core/session.ts:168-169`), form branch `:64-132`, `aria-invalid`/`aria-describedby` already present `:82-83`/`:98-99`, `role="alert"` `:118`, lockup `:68-71`. No `viewChild`, no `effect`, no `.focus()` in the file.
- `ui/src/app/shell/side-bar.ts` — `isSideBarChord()` `:37-39` (**no `shiftKey` test**), host `(document:keydown)` `:70`, `onKeydown` `:179-193` (arrows only, `else return` `:188`), `onGlobalKeydown` `:199-207`, `navigateByUrl('/' + entry.route)` `:176` (**drops the query**).
- `ui/src/app/shell/rail.ts` — `navigateByUrl` `:166` (same drop), `onKeydown` `:173-186`, tooltip ids `:129`, `railItemDomId()` `:33-35`.
- `ui/src/app/shell/instance-notice.ts` — the two blocking-notice variants 1.8 shipped, rendered by `app.ts`'s `@else` of `instanceReady` `:60-62`. Reparented, never re-styled: DW-127 is escalated, not this story's to settle.
- `ui/src/app/core/shell-state.ts` — `activateArea()` `:84-90`, whose `navigates` branch calls `setOpen(false)` `:87` → `preferences.setSideBarOpen()` `:109-112` (**DW-134's persisted Home collapse**). `subscribe/activeArea/visibleArea/open/toggleOpen` `:45-107`.
- `ui/src/app/core/preferences.ts` — `PREFERENCE_KEYS` allow-list `:30`, `assertAllowed` `:115-119`; the only module permitted `localStorage` (`ui/tools/api.test.mjs:525-537` scans for the rest by **exact path** exemption).
- `ui/src/app/core/instance.ts` — `InstanceIdentity`, `InstanceService` (`status/adminApiVersion/instanceName/instanceVersion/buildIdentity/verify`), `isInstanceReady` `:43-45`. `core/session.ts` — `userName()` from the pair's `sub`; `SessionState` union. `core/navigation.ts` — `areas()`, `screensForArea()`, `screenVerdict()`, `areaForUrl`, `screenForRoute`, `formatRequires`. `core/screens.generated.ts` — `ScreenDeclaration` carries `primaryAction`, `rowActions`, `commandAliases`, `labelKey`, `archetype`, `built`.
- `ui/src/app/core/strings.ts` — already present and unused by the shell: `commandBoxPlaceholder` `:234`, `commandBoxNoMatch` `:236`, `commandBoxResultCount` `:238`, `privilegeSelectRowFirst` `:198`, `statusConnection*` `:78-84`, `statusAutoRefresh*` `:186-190`, `statusLastUpdate` `:192`, `actionSignOut` `:112`, `navArea*` `:289-296`, `navRailLandmark`/`navSideBarLandmark` `:303-304`, `productName` `:269`.
- `ui/tools/strings.test.mjs` — `extractFixedStringsTable` `:48-68`, `extractAreaNames` `:86-98`, `extractLandmarkNames` `:105-111` whose comment says it is **deliberately narrow** so it does not authorise `"Breadcrumb"` — this story broadens it; `EXTRACTED_FROM_PROSE` `:121`; `REQUIRED_ALONGSIDE_TABLE` stays at three.
- `ui/src/styles/_metrics.scss` — `--ocu-header-height: 48px` `:30`, `--ocu-status-bar-height: 24px` `:31`, `--ocu-locator-height: 40px` `:32`, `--ocu-command-bar-height: 50px` `:33` — **all four declared, zero consumers anywhere in `ui/`**; rail/side-bar widths `:28-29`; motion `:63-65` and the reduced-motion block `:73-80`.
- `ui/src/styles/_tokens.scss` — `--ocu-shell` `:103`, `--ocu-on-shell` `:105`, `--ocu-shell-edge` `:107`, `--ocu-logo-gradient-stop` `:188` (its own comment names this story as the consumer), the four server-flag quadruples `:166-184` (unconsumed), `--ocu-restrained` `:126`, `--ocu-focus-ring` `:159`. The only file permitted a literal colour. `ui/tools/design-tokens.mjs` `COLOR_ROLES` `:20` pins 64 roles × 2 — adding one is a test-visible change.
- `ui/src/styles/_components.scss` — `.ocu-shell` `:450-454` (`min-height: 0`, **no height**), `.ocu-rail` `:463-470`, `.ocu-rail-slot-bottom { margin-top: auto }` `:478-481` (**DW-138**), `.ocu-side-bar` `:596-602`, rail focus ring `:554-558`, `.ocu-rail-tooltip` `:563-579` and its instant reveal `:581-589` (**no transition, no delay, no `allow-discrete` anywhere in `ui/src/styles`**). `ui/src/index.html:13` `<app-root>` with no style; no `html`/`body`/`app-root` rule exists in the tree — the DW-138 audit is confirmed.
- `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/imports/OcuPilot-Lockup-horizontal-reversed.png` — the reversed lockup the header needs. `ui/src/assets/lockup/` holds only the navy-on-white horizontal PNG; `_components.scss:129` says the sign-in card must never use the reversed one.
- UX anchors: header `DESIGN.md:274-298`, `:1007-1017`; status bar `DESIGN.md:299-317`, `:1021-1025`, `EXPERIENCE.md:54`, `:318-319`; locator `DESIGN.md:321-325`, `:1033`, `EXPERIENCE.md:320`; command bar `DESIGN.md:326-331`, `:1037`, `EXPERIENCE.md:321`; command box `DESIGN.md:288-298`, `:1017`, `EXPERIENCE.md:317`, `:356-360`; Escape and chords `EXPERIENCE.md:528-542`; landmarks and focus order `EXPERIENCE.md:580-583`; yield order `DESIGN.md:898`, `EXPERIENCE.md:600`; rail tooltip delay `DESIGN.md:983` (stated exactly once); reduced motion `DESIGN.md:937`; UX-DR80 `DESIGN.md:958`, `epics.md:491`.

## Tasks & Acceptance

**Execution — server:**

- `src/OcuPilot/Api/Instance.cls` — add `ServerFlag()`, `LicensedTo()`, `ServerName()` in the shape of `InstanceName()` `:93`, each with its own `Try` returning `""` on failure, and emit `serverFlag`, `licensedTo`, `serverName` from `Payload()` `:40`. Sources: `$SYSTEM.Version.SystemMode()`, `$SYSTEM.License.KeyCustomerName()`, `##class(%SYS.System).GetNodeName()`. No namespace switch, no new gate. Do not assert that these reads need no privilege — the per-field `Try` is what makes that question moot.
- `src/OcuPilot/Test/Instance.cls` — extend for the three fields, the empty-`SystemMode` payload, and a throwing source degrading to `""` with a 200.

**Execution — client core:**

- `ui/src/app/core/overlay-stack.ts` *(new, framework-free, no `@angular/*` import)* — `push(id, close)`, `remove(id)`, `closeTop(): boolean`, `top()`, `subscribe()`. The single Escape authority; the side bar is its bottom-most member.
- `ui/src/app/core/instance.ts` — add `serverFlag`/`licensedTo`/`serverName` to `InstanceIdentity` and the service, plus `serverFlagKind(value)` case-folding to `live|test|failover|development|unknown|none`.
- `ui/src/app/core/shell-state.ts` — split the Home branch of `activateArea()` `:84-90` so it collapses the visible side bar **without** writing the preference; `toggleOpen()` keeps persisting (**DW-134**).
- `ui/src/app/core/strings.ts` — add exactly seven keys: `navLocatorLandmark` (`Breadcrumb`), `headerNamespaceLabel` (`Namespace`), `headerHomeLink` (`OcuPilot — Home` — the em dash is `EXPERIENCE.md:316`'s, which `epics.md:1350` renders as a hyphen, and it is authored as an escape per Rule 14), and `serverFlagLive|Test|Failover|Development`.
- `ui/src/main.ts` — construct and provide the overlay stack the `useValue` way.

**Execution — client shell:**

- `ui/src/app/shell/header.ts` *(new)* — `banner` band at `--ocu-header-height`, `linear-gradient(90deg, shell 0%, shell 55%, shell-edge 100%)`, the 32px reversed lockup 8px from the left linking to Home with the accessible name `headerHomeLink` (no plate, no hover), `<app-command-box />` centred at 360px, and the namespace slot right — a `headerNamespaceLabel` eyebrow over the route's current `ns`, rendered, not selectable.
- `ui/src/app/shell/status-bar.ts` *(new)* — `contentinfo` band at `--ocu-status-bar-height`: server, instance name and version, the user, licensed-to left; `<app-server-flag />`, the auto-refresh stamp and the connection-state disc-plus-word right. Mounts `<app-account-menu />` as the user segment, the band's only interactive element. A segment whose value is `""` does not render.
- `ui/src/app/shell/server-flag.ts` *(new)* — `value` input → the pill, using the existing flag pairs; nothing for `""`; an unrecognised value verbatim in `restrained` (**DW-10**). Separate from the status bar because 1.12's Home instance line reuses it.
- `ui/src/app/shell/locator-bar.ts` *(new)* — `nav` labelled `navLocatorLandmark`; area › screen › entity from `core/navigation.ts` and the route; `›` separators `aria-hidden`; the current segment `display`-sized, `aria-current="page"`, not a link; the entity segment `{typography.code}`, present only with an id; namespace never a segment.
- `ui/src/app/shell/command-bar.ts` *(new)* — band at `--ocu-command-bar-height`: the descriptor's primary action left, the 220px filter with a polite match count, view options, the auto-refresh chip where the descriptor declares refresh, further actions as text buttons, the last-update stamp right. Row actions `aria-disabled="true"` with `privilegeSelectRowFirst` until a row is selected. The sort slot is declared and left unrendered (see Design Notes).
- `ui/src/app/shell/command-box.ts` *(new)* — `role="combobox"` with `aria-expanded`/`aria-controls`/`aria-activedescendant` over a `role="listbox"` with `role="group"` Screens and Actions; opens on Ctrl/Cmd+K and click, filters every screen the navigation map says the user may open plus the current screen's declared actions against `commandAliases`; `commandBoxResultCount` / `commandBoxNoMatch` as a polite status; the chord once as a kbd chip at the field's right edge, never in the placeholder; gated rows non-selectable with the failed pair inside the accessible name. Registers with the overlay stack. Never a turn, never the avatar.
- `ui/src/app/shell/account-menu.ts` — register with the overlay stack; close on pointerdown or focus moving outside the wrapper, in addition to Escape, the second trigger click and choosing the item; keep the focus-before-removal order (**DW-109**).
- `ui/src/app/shell/sign-in.ts` — add a `viewChild` per field and an `effect()` that, on a transition into a form state from a non-form state, focuses the password field when the user name is retained and the user-name field otherwise (**DW-103** and its 1-7 occurrence).
- `ui/src/app/shell/side-bar.ts` — add `&& !event.shiftKey` to `isSideBarChord()` `:37`; preserve the query on `:176`; register with the overlay stack so Escape collapses the bar when it is the top overlay (**DW-134**, **DW-137**).
- `ui/src/app/shell/rail.ts` — preserve the query on `:166` (**DW-134**).
- `ui/src/app/app.ts` — reparent into the frame: `<app-header />`, then a row of `<app-rail /> <app-side-bar />` and a content column of `<app-locator-bar /> <app-command-bar /> <main><router-outlet /></main>`, then `<app-status-bar />` which now hosts `<app-account-menu />` (dropping the interim mount at `:51`). The `@else` of `instanceReady` still renders `<app-instance-notice />` unchanged, and the `@else` of `signedIn` still renders `<app-sign-in />` outside the frame. Keep `session.test.mjs:1631-1712`'s `@if` nesting and `:1636`'s terminator, and keep `build-output.test.mjs`'s first-string and first-class reads satisfied.
- `ui/src/assets/lockup/OcuPilot-Lockup-horizontal-reversed.png` *(new)* — vendored from the UX `imports/` folder, the way the horizontal lockup was.

**Execution — styles:**

- `ui/src/styles/_metrics.scss` — add `--ocu-motion-tooltip-delay: 300ms` beside the three durations `:63-65` and zero it in the reduced-motion block `:73-80` (**DW-137**).
- `ui/src/styles/_components.scss` — give the frame its height (`app-root` a full-viewport flex column; `.ocu-shell` `flex: 1 1 auto` with `min-height: 0`; the rail stretching), which is what makes `margin-top: auto` `:481` resolve (**DW-138**); the five bands from the four unconsumed height tokens; the header gradient from `--ocu-shell`/`--ocu-shell-edge`; the server-flag pills from the existing quadruples plus the dark-mode 1px edge; the command box, its kbd chip and its result sheet; the rail tooltip's delayed reveal via `transition-delay` with `transition-behavior: allow-discrete` (**DW-137**). Add no colour token.

**Execution — tooling and tests:**

- `ui/tools/strings.test.mjs` — broaden `extractLandmarkNames` `:105-111` to also take `"Breadcrumb"` from the Landmarks line, add targeted extractors for `Namespace` (`EXPERIENCE.md:315`), the lockup name (`EXPERIENCE.md:316`) and the four flag words (`EXPERIENCE.md:319` / `DESIGN.md:1025`), fold them into `EXTRACTED_FROM_PROSE`, and update the count assertion. `REQUIRED_ALONGSIDE_TABLE` stays at three.
- `ui/tools/overlay-stack.test.mjs` *(new)*, `ui/tools/shell-state.test.mjs` (Home's non-persisting collapse), `ui/tools/session.test.mjs` (the three new identity fields and `serverFlagKind`), `ui/tools/design-tokens.test.mjs` (the new motion token; the colour-role count is unchanged).
- `ui/src/app/shell/header.spec.ts`, `status-bar.spec.ts`, `locator-bar.spec.ts`, `command-bar.spec.ts`, `command-box.spec.ts`, `account-menu.spec.ts`, `sign-in.spec.ts`, `ui/src/app/app.spec.ts` *(all new)*; extend `side-bar.spec.ts` and `rail.spec.ts`. Focus assertions must `document.body.appendChild(fixture.nativeElement)` first, as `side-bar.spec.ts:304-307` does.

**Acceptance Criteria:**

- Given any route, when the shell renders, then a `banner` of `--ocu-header-height` carries the 32px reversed lockup on the `shell`→`shell-edge` gradient with no plate and no hover state, linking to Home with the accessible name `OcuPilot — Home`, the 360px command box centred and the namespace slot at the right; and no text in the header is drawn below 100% opacity.
- Given the status bar, when it renders, then a `contentinfo` band of `--ocu-status-bar-height` shows server, instance name and version, the user and licensed-to on the left and the server-flag badge, auto-refresh stamp and connection state — each state's coloured disc always followed by its word — on the right; the user segment is the band's only interactive element and opens the account menu with Sign out; and the badge never appears in the header.
- Given any screen, when it renders, then a `nav` labelled `Breadcrumb` names area, screen and the selected entity, each earlier segment navigating, separators `aria-hidden`, the current segment `display`-sized with `aria-current="page"` and not a link, the entity segment in `code` appearing on selection and dropping when it clears, and the namespace never a segment.
- Given the command bar, when it renders, then it holds the screen's primary action left, the filter field with a polite match count, view options, the auto-refresh chip where the descriptor declares refresh, further actions as text buttons and the last-update stamp right-aligned; every command-bar action is reachable from the command box.
- Given the command box, when the user presses Ctrl/Cmd+K, then it opens as the combobox above, filtering every screen the navigation map allows plus the current screen's declared actions against their aliases, grouped Screens and Actions with a polite count, the chord shown once as a kbd chip at the field's right edge; it is not a channel to the agent and never shows the avatar.
- **Integration AC** — given the command box open over an open side bar, when Escape is pressed, then the overlay stack closes the command box and restores focus to where it was while the side bar stays open; a second Escape collapses the side bar; and the account menu, registered on the same stack, closes on a pointerdown outside it with `aria-expanded="false"`.
- Given UX-DR80's assumed 24px status bar and its shell colour, when this story is built, then both are confirmed against the frame's own height arithmetic and the contrast floor rather than carried forward, and `--ocu-header-height`, `--ocu-status-bar-height`, `--ocu-locator-height` and `--ocu-command-bar-height` gain their first consumers.

## Spec Change Log

## Review Triage Log

## Design Notes

**Governing architecture decisions (Rule 6).** AD-5 (chrome resolves through the descriptor, never a hand-kept list), AD-8 (privilege per call; gated entries listed and `aria-disabled`), AD-12 / AD-39 (the extended `/instance` keeps one envelope and one writer), AD-13 (the locator's entity segment is the one encoded segment), AD-19 (standalone, zoneless, `OnPush`, signals), AD-20 (absolute API paths through `ApiService`), AD-28 (sign-out is the instance, so the account menu offers no tab-only option), AD-43 (auto-refresh is one framework — this story renders its chip and stamp, 1.14 owns the timer), AD-44 (`?ns=` is data scope and must survive navigation), AD-47 (vendored assets, no CDN). Conventions rows: Angular naming, Client asset homes, ObjectScript naming, Dates. No AC here contradicts an AD's Rule.

**Decision (overnight) — the command-box placeholder is drawn at 100%.** `epics.md:1351` and `DESIGN.md:1007` state the rule absolutely; `DESIGN.md:1017` draws the placeholder at 80%. The AC is the story's contract, and a 100% placeholder still disappears on input, so the rule is followed and the divergence is filed for the lead rather than argued around. Same family as DW-127 — no planning artifact is edited here.

**Decision (overnight) — an unflagged instance gets no badge (DW-10).** `SystemMode()` returns `""` until a mode is set, and the supported setter normalises anything outside the four to `""` (`irissys/%SYSTEM/Version.cls:344-374`), so absence is the common state — this container is exactly that case — and a value outside the four can only arrive by a direct global write. Dressing absence as `Live` is the failure the entry is about. Stored values are upper case, so the badge case-folds rather than string-compares. DW-10's own note suggested a default badge; a defined *absence* is the better answer and is equally observable.

**Decision (overnight) — one overlay stack owns Escape (DW-137, DW-109).** `EXPERIENCE.md:533` has no implementation today. A framework-free `core/overlay-stack.ts` is the single authority the command box, the account menu and the side bar register with; that is what lets Escape reach the side bar without taking Escape away from an open menu, and it is why DW-137's Escape row was not a one-line side-bar edit.

**Decision (overnight) — focus follows the field the user must act on (DW-103).** Neither document names a destination — `EXPERIENCE.md:583` offers `role="alert"` *or* focus moved to it, while `:582` forbids removing a focused control without one. One rule covers both sightings: entering a form state from a non-form state focuses the password field when the user name was retained (a rejection) and the user-name field otherwise (sign-out, session ended).

**Decision (overnight) — the namespace switch is a slot here and a control in 1.11.** Story 1.11 owns the list, the selection and the re-fetch; this story places the eyebrow, the current `ns` and the focus treatment so 1.11 wires a control rather than inventing a band.

**Decision (overnight) — the locator and command bars render their absent states.** Only Home declares a screen, so with no selection and no refresh declaration the row actions are `aria-disabled` with `Select a row first`, the entity segment is absent, and the chip and stamp do not render. Those are the states this story can pin; 1.12 and 1.14 fill them. The command-bar sort slot is declared and left unrendered because `EXPERIENCE.md:321` names a control `DESIGN.md:1037` does not specify (filed).

**Decision (overnight) — the status bar carries no per-segment accessible labels.** `Server`, `Instance` and `Licensed to` have no Fixed-strings rows; inventing them is new copy. The band is a `contentinfo` landmark whose segments render in the documented order, and the naming gap is filed against DW-126's root cause.

**Decision (overnight) — reduced motion zeroes the tooltip delay**, alongside the three existing duration tokens, per `DESIGN.md:937`'s "instant state changes". *(inference: the delay is a state change rather than motion; nothing in either document says either way.)*

**Strings.** Seven new keys, every one re-derived from a UX document by a targeted extractor, the mechanism 1.9 established for the eight area names — never by growing `REQUIRED_ALONGSIDE_TABLE`, which stays at three.

**Ledger inbox (Rule 17).** DW-10, DW-103, DW-109, DW-134, DW-137 and DW-138 each have a matrix row, a task and a named pinning test. None is declined.

**Consumes:** 1.1 (`Api.Response`, `Api.Error`), 1.5 (`Api.Router` ordering invariants, `Test.Http`), 1.6 (`Session`, `sign-in.ts`), 1.7 (`account-menu.ts`, `actionSignOut`), 1.8 (`Api.Instance`, `core/instance.ts`, `isInstanceReady`, `instance-notice.ts`), 1.9 (`core/screens.generated.ts`, `core/navigation.ts`, `core/preferences.ts`, `core/shell-state.ts`, `rail.ts`, `side-bar.ts`, the component test runner).

**Consumed-by:** 1.11 — the header's namespace slot becomes the switch, and `?ns=` now survives navigation; 1.12 — `server-flag.ts` and the extended identity fields render Home's instance line, and the command bar hosts Home's actions; 1.13 — the status bar's connection segment is where the probe's verdict lands; 1.14 — the command bar's chip and the status bar's stamp are the surfaces the refresh framework drives; 1.15 — the command bar is where the classic link-out sits; Epic 5 — the panel registers on the same overlay stack.

**Not resolved here.** DW-127 (whether the two blocking notices carry a banner) stays escalated: this story only reparents `instance-notice.ts` inside the new frame and changes neither variant.

## Verification

**Environments.** The live `ocupilot` container (web 52774, SuperServer 1973) must **not** be recreated — no `docker compose up`/`down`/`restart` against this repository's compose file (`ps`, `logs`, `exec` are safe). Every check here is read-only or idempotent and runs against it through the IRIS MCP tools with **`server: "ocupilot-iris"`** on every call. Nothing in this story is install-path or destructive, so **no throwaway container is required**; if one becomes necessary it is a separate scratch compose project with its own project name, container name, host ports (never 52774/1973) and scratch volume, torn down with `down -v`. No real account is created, modified, locked or expired, and no browser session this story did not mint is ended — `_SYSTEM` is the owner's working account. `$SYSTEM.Version.SystemMode()` is **read** only; the out-of-enum badge case is exercised by a test seam, never by writing `^%SYS("SystemMode")` on the live instance.

**One test class per tool call.** Send **one** `iris_execute_tests` call per message, wait for it to land in `%UnitTest_Result`, and never re-submit on a client-side timeout — a returned call is not a finished run, and these classes share one instance.

**Commands:**

- `npm --prefix ui test` — expected: green; the Node tool suite and the component suite both run.
- `npm --prefix ui run build` — expected: exit 0, `client-lint: clean`, `initial` under the 1MB budget.
- `uv run scripts/check-objectscript.py` — expected: no findings.
- `bash scripts/lint-docs.sh` — expected: clean.
- `iris_doc_load` then `iris_doc_compile` on `src/OcuPilot/` (`server: "ocupilot-iris"`) — expected: clean compile.
- `iris_execute_tests` on `OcuPilot.Test.Instance` — expected: all green; one class per message, totals confirmed by the `%UnitTest_Result` SQL probe in `.claude/rules/objectscript-testing.md`.

**Pinning tests (Rule 19) — one per acceptance criterion:**

- Header band, lockup, gradient and the 100% rule → `header.spec.ts`.
  `mutation: _(implement stage)_`
- Status-bar segments, the single interactive element, and the badge absent from the header → `status-bar.spec.ts`, with `OcuPilot.Test.Instance` for the payload behind it.
  `mutation: _(implement stage)_`
- Locator bar: labelled `nav`, navigating segments, `aria-hidden` separators, current segment not a link, entity segment appearing and dropping → `locator-bar.spec.ts`.
  `mutation: _(implement stage)_`
- Command bar contents and `Select a row first` on row actions → `command-bar.spec.ts`.
  `mutation: _(implement stage)_`
- Command box combobox contract, grouping, polite count, kbd chip, gated rows → `command-box.spec.ts`.
  `mutation: _(implement stage)_`
- **Integration AC** (two overlays, Escape order, outside dismissal) → `command-box.spec.ts` and `account-menu.spec.ts`, over `ui/tools/overlay-stack.test.mjs`.
  `mutation: _(implement stage)_`
- UX-DR80: the four chrome-height tokens gain consumers and the frame's arithmetic closes → `ui/src/app/app.spec.ts` with `ui/tools/design-tokens.test.mjs`.
  `mutation: _(implement stage)_`
- **DW-10** (no flag → no badge; out-of-enum → verbatim in `restrained`) → `OcuPilot.Test.Instance` for the payload and `status-bar.spec.ts` for the badge.
  `mutation: _(implement stage)_`
- **DW-103** (rejection focuses the password field; sign-out focuses the user-name field) → `sign-in.spec.ts`.
  `mutation: _(implement stage)_`
- **DW-109** (pointerdown and focus-out close the menu, `aria-expanded="false"`) → `account-menu.spec.ts`.
  `mutation: _(implement stage)_`
- **DW-134** (Ctrl+Shift+B does not toggle; `?ns=` survives rail and side-bar navigation; Home's collapse is not persisted) → `side-bar.spec.ts`, `rail.spec.ts`, `ui/tools/shell-state.test.mjs`.
  `mutation: _(implement stage)_`
- **DW-137** (Escape collapses the side bar when it is the top overlay; the tooltip delay token exists, is consumed and is zeroed under reduced motion) → `side-bar.spec.ts` and `ui/tools/design-tokens.test.mjs`.
  `mutation: _(implement stage)_`
- **DW-138** (the frame's height chain and the rail's bottom slot as its last child) → `ui/src/app/app.spec.ts`. jsdom computes no layout, so this pins structure; the rendered geometry is the browser measurement below and not a claim this test makes.
  `mutation: _(implement stage)_`

Whoever adds or materially changes a pinning test writes its `mutation:` line in the same pass: name the smallest change that violates the AC, apply it, observe red, revert, and confirm `git status --short` and `git diff --stat` are unchanged.

**Manual checks:**

- Desktop Chrome against the live instance at `http://localhost:52774/ocupilot/`: the five bands at their token heights; the header gradient and the lockup at 32px; the status bar's segments and the flag badge's absence on this unflagged container; Ctrl/Cmd+K, Escape order across command box → side bar, Ctrl+Shift+B doing nothing, and the rail tooltip's 300ms reveal.
- **DW-138 geometry (lead, browser MCP per Rule 7):** measure `getBoundingClientRect()` on `.ocu-rail` and on the Agent co-pilot slot — the rail's height equals the viewport minus the header and status bar, and Agent co-pilot's top is below Security's bottom with free space between them.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none
