---
title: 'Story 1.10 — Header, status bar and page chrome'
type: 'feature'
created: '2026-09-12'
status: 'done'
baseline_revision: '798731f1b9166e31f425d2999fd6c17d0af8683a'
baseline_commit: '798731f1b9166e31f425d2999fd6c17d0af8683a'
review_loop_iteration: 0
followup_review_recommended: true
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
  - summary: "The command bar's filter field has no accessible name: EXPERIENCE.md publishes no filter label, and REQUIRED_ALONGSIDE_TABLE stays at three."
    evidence: 'EXPERIENCE.md:321 names the field and its polite count but spells neither. It ships as type="search" described by its own count region. One table row settles it.'
    location: 'ui/src/app/shell/command-bar.ts'
    severity: 'medium'
  - summary: "The command box's two result groups carry role=group with no aria-label; EXPERIENCE.md:356 asks for one and publishes no words for it."
    evidence: 'The grouping is real and the polite count already reads "<n> screens, <m> actions", which names both groups aloud. Same family as the filter label above.'
    location: 'ui/src/app/shell/command-box.ts'
    severity: 'low'
  - summary: >-
      The command bar's filter field has neither an accessible name nor a non-empty description:
      matchCount is a constant '' until a screen has rows, so its aria-describedby target is an
      empty region.
    evidence: |-
      Corrects the mitigation claimed by the filter-label entry above: the field does not ship
      "described by its own count region" while that region is empty. A genuine WCAG 4.1.2 gap
      until a Fixed-strings row lands; this story may not add one.
    location: 'ui/src/app/shell/command-bar.ts'
    severity: medium
  - summary: >-
      With an entity selected the locator marks the screen segment aria-current="page" and leaves
      it unlinked, so there is no route back from an entity view to its list.
    evidence: |-
      The AC supports both readings: "each earlier segment navigating" makes the screen a link
      once an entity follows it, while "the entity segment in code" reads as a trailing segment
      after the current one. Built on the second reading; one ruling wanted.
    location: 'ui/src/app/shell/locator-bar.ts'
    severity: medium
  - summary: >-
      Escape collapses the side bar through toggleOpen(), so a transient dismissal is written to
      the stored preference and every later area starts collapsed.
    evidence: |-
      Ctrl/Cmd+B persisting is right (the user asked); Escape is a dismissal gesture and
      arguably is not. Neither document says. A non-persisting close needs new public surface on
      ShellState, which is why it is filed rather than patched.
    location: 'ui/src/app/core/shell-state.ts'
    severity: low
  - summary: >-
      An unrecognised system mode is drawn verbatim, uncapped and nowrap, so a long value written
      directly to ^%SYS("SystemMode") would stretch the 24px status bar.
    evidence: |-
      serverFlagKind trims for classification but the rendered word is the raw value. Only a
      direct global write can produce one, which is why it is low rather than fixed here.
    location: 'ui/src/app/shell/server-flag.ts'
    severity: low
  - summary: >-
      The truncated instance-version segment is recoverable only through a title attribute, which
      is unreachable by keyboard and unreliable on touch.
    evidence: |-
      It is the one segment documented as allowed to run out of room, so the escape hatch is
      load-bearing. A reachable disclosure needs a pattern neither UX document specifies.
    location: 'ui/src/app/shell/status-bar.ts'
    severity: low
  - summary: >-
      The command bar's view-options control is named by the AC and by DESIGN.md:1037 but is not
      rendered, and until now had no deferred entry despite a doc comment calling it filed.
    evidence: |-
      DESIGN.md:1037 specifies a View menu; EXPERIENCE.md publishes no label for it and
      REQUIRED_ALONGSIDE_TABLE stays at three. Same family as the sort slot already filed.
    location: 'ui/src/app/shell/command-bar.ts'
    severity: low
  - summary: >-
      The locator's area segment navigates into that area's first built screen without checking
      its privilege verdict, where the rail and the side bar both refuse.
    evidence: |-
      screensForArea does not filter by verdict, so the first built screen may be gated. It
      degrades to Story 1.9's screen-denied surface rather than failing, which is why it is low.
    location: 'ui/src/app/shell/locator-bar.ts'
    severity: low
---

<intent-contract>

## Intent

**Problem:** The shell has a rail, a side bar and a routed outlet, and nothing else — no frame around them. A signed-in user cannot see which server, instance or namespace they are about to change, where they are inside the portal, or what the current screen can do; the account menu floats outside any band; and the rail's own layout is broken because no element in the tree has a height. Six ledger entries of shell residue wait on the bands this story builds.

**Approach:** Build the page frame — header, status bar, locator bar, command bar and command box — as standalone `OnPush` shell components around the existing rail, side bar and outlet, driven by the descriptor mirror and the navigation map rather than by per-screen wiring. Extend `GET /api/ocupilot/instance` with the three status-bar fields no endpoint returns today, and add one overlay stack so Escape has a single authority across the band.

## Boundaries & Constraints

**Always:** Chrome reads the screen descriptor mirror and the navigation map — never a hand-kept list (AD-5). Privilege verdicts come from the server per call and gated entries stay listed, focusable and `aria-disabled="true"`, never `disabled`, never hidden (AD-8). Colours come only from `ui/src/styles/` tokens and user-facing text only from `ui/src/app/core/strings.ts`; both are lint-enforced. Components are standalone, zoneless, `OnPush`, signal-based, with paren-free getters for the control-flow blanker (AD-19). Every API path is absolute through `ApiService` (AD-20). Non-ASCII in source is a `\uXXXX` escape (Rule 14). Sign-out means the instance, not the tab — the account menu must not imply otherwise (AD-28).

**Never:** No namespace list, selection or re-fetch — 1.11 owns the switch's behavior; this story places its slot. No Home page, no area tiles — 1.12. No connectivity probe and no retry schedule — 1.13. No auto-refresh timer or stamp value — 1.14. No classic-portal link-out — 1.15. No skip link (no AC names it, and it needs a string neither document authorizes). No new color token: the four server-flag pairs and `--ocu-shell-edge` already exist. No growth of `REQUIRED_ALONGSIDE_TABLE`, which stays at three. No planning-artifact edit to settle DW-126 or DW-127.

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
- `ui/tools/strings.test.mjs` — `extractFixedStringsTable` `:48-68`, `extractAreaNames` `:86-98`, `extractLandmarkNames` `:105-111` whose comment says it is **deliberately narrow** so it does not authorize `"Breadcrumb"` — this story broadens it; `EXTRACTED_FROM_PROSE` `:121`; `REQUIRED_ALONGSIDE_TABLE` stays at three.
- `ui/src/styles/_metrics.scss` — `--ocu-header-height: 48px` `:30`, `--ocu-status-bar-height: 24px` `:31`, `--ocu-locator-height: 40px` `:32`, `--ocu-command-bar-height: 50px` `:33` — **all four declared, zero consumers anywhere in `ui/`**; rail/side-bar widths `:28-29`; motion `:63-65` and the reduced-motion block `:73-80`.
- `ui/src/styles/_tokens.scss` — `--ocu-shell` `:103`, `--ocu-on-shell` `:105`, `--ocu-shell-edge` `:107`, `--ocu-logo-gradient-stop` `:188` (its own comment names this story as the consumer), the four server-flag quadruples `:166-184` (unconsumed), `--ocu-restrained` `:126`, `--ocu-focus-ring` `:159`. The only file permitted a literal color. `ui/tools/design-tokens.mjs` `COLOR_ROLES` `:20` pins 64 roles × 2 — adding one is a test-visible change.
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
- `ui/src/app/shell/locator-bar.ts` *(new)* — `nav` labeled `navLocatorLandmark`; area › screen › entity from `core/navigation.ts` and the route; `›` separators `aria-hidden`; the current segment `display`-sized, `aria-current="page"`, not a link; the entity segment `{typography.code}`, present only with an id; namespace never a segment.
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
- `ui/src/styles/_components.scss` — give the frame its height (`app-root` a full-viewport flex column; `.ocu-shell` `flex: 1 1 auto` with `min-height: 0`; the rail stretching), which is what makes `margin-top: auto` `:481` resolve (**DW-138**); the five bands from the four unconsumed height tokens; the header gradient from `--ocu-shell`/`--ocu-shell-edge`; the server-flag pills from the existing quadruples plus the dark-mode 1px edge; the command box, its kbd chip and its result sheet; the rail tooltip's delayed reveal via `transition-delay` with `transition-behavior: allow-discrete` (**DW-137**). Add no color token.

**Execution — tooling and tests:**

- `ui/tools/strings.test.mjs` — broaden `extractLandmarkNames` `:105-111` to also take `"Breadcrumb"` from the Landmarks line, add targeted extractors for `Namespace` (`EXPERIENCE.md:315`), the lockup name (`EXPERIENCE.md:316`) and the four flag words (`EXPERIENCE.md:319` / `DESIGN.md:1025`), fold them into `EXTRACTED_FROM_PROSE`, and update the count assertion. `REQUIRED_ALONGSIDE_TABLE` stays at three.
- `ui/tools/overlay-stack.test.mjs` *(new)*, `ui/tools/shell-state.test.mjs` (Home's non-persisting collapse), `ui/tools/session.test.mjs` (the three new identity fields and `serverFlagKind`), `ui/tools/design-tokens.test.mjs` (the new motion token; the color-role count is unchanged).
- `ui/src/app/shell/header.spec.ts`, `status-bar.spec.ts`, `locator-bar.spec.ts`, `command-bar.spec.ts`, `command-box.spec.ts`, `account-menu.spec.ts`, `sign-in.spec.ts`, `ui/src/app/app.spec.ts` *(all new)*; extend `side-bar.spec.ts` and `rail.spec.ts`. Focus assertions must `document.body.appendChild(fixture.nativeElement)` first, as `side-bar.spec.ts:304-307` does.

**Acceptance Criteria:**

- Given any route, when the shell renders, then a `banner` of `--ocu-header-height` carries the 32px reversed lockup on the `shell`→`shell-edge` gradient with no plate and no hover state, linking to Home with the accessible name `OcuPilot — Home`, the 360px command box centred and the namespace slot at the right; and no text in the header is drawn below 100% opacity.
- Given the status bar, when it renders, then a `contentinfo` band of `--ocu-status-bar-height` shows server, instance name and version, the user and licensed-to on the left and the server-flag badge, auto-refresh stamp and connection state — each state's coloured disc always followed by its word — on the right; the user segment is the band's only interactive element and opens the account menu with Sign out; and the badge never appears in the header.
- Given any screen, when it renders, then a `nav` labeled `Breadcrumb` names area, screen and the selected entity, each earlier segment navigating, separators `aria-hidden`, the current segment `display`-sized with `aria-current="page"` and not a link, the entity segment in `code` appearing on selection and dropping when it clears, and the namespace never a segment.
- Given the command bar, when it renders, then it holds the screen's primary action left, the filter field with a polite match count, view options, the auto-refresh chip where the descriptor declares refresh, further actions as text buttons and the last-update stamp right-aligned; every command-bar action is reachable from the command box.
- Given the command box, when the user presses Ctrl/Cmd+K, then it opens as the combobox above, filtering every screen the navigation map allows plus the current screen's declared actions against their aliases, grouped Screens and Actions with a polite count, the chord shown once as a kbd chip at the field's right edge; it is not a channel to the agent and never shows the avatar.
- **Integration AC** — given the command box open over an open side bar, when Escape is pressed, then the overlay stack closes the command box and restores focus to where it was while the side bar stays open; a second Escape collapses the side bar; and the account menu, registered on the same stack, closes on a pointerdown outside it with `aria-expanded="false"`.
- Given UX-DR80's assumed 24px status bar and its shell color, when this story is built, then both are confirmed against the frame's own height arithmetic and the contrast floor rather than carried forward, and `--ocu-header-height`, `--ocu-status-bar-height`, `--ocu-locator-height` and `--ocu-command-bar-height` gain their first consumers.

### Review Findings

**2026-09-12 — code review (round 1, `full-opus`, four layers).** 54 raw rows → 21 root-cause
entries: high 3, med 8, low 10. Unresolved high/med: 0 — the three routed mediums carry a ledger
owner. 16 mutations applied, observed red and reverted in this pass; suite green either side
(305 Node + 112 component, `OcuPilot.Test.Instance` 21/21).

`[high]` `[patched]` **Sign out is unreachable and the page is blank in the `checking` instance
state.** `app.ts` mounts the account menu only through the `ready`-only status bar; the baseline
mounted it above both instance branches. `instance-notice.ts` gated its whole section on
`mismatch || noPrivileges`, so the third non-ready state rendered nothing — and `checking` is not
only the opening flicker: `InstanceService.runVerify`'s final branch settles nothing for any failure
the shell cannot explain and nothing retries (DW-119). The same AD-28 break the implement review
closed for `version-mismatch`, one state over. Fixed: the section renders for every non-ready state,
the variants' sentences stay conditional.

`[high]` `[patched]` **The header lockup's `href="/"` left the application.** `index.html` declares
`<base href="/ocupilot/">`, and a root-relative href ignores it, so middle-click, open-in-new-tab and
copy-link-address reached the IRIS instance root and dropped `?ns=` (AD-44) — the one Home affordance
the rail carries it on. `goHome()` also `preventDefault`ed every modifier click, so open-in-new-tab
navigated in place instead. Fixed: `Location.prepareExternalUrl(withQuery(...))` for the href, and
`RouterLink`'s own modifier guard on the handler. `header.spec.ts` had pinned `'/'` as correct.

`[high]` `[patched]` **`app-root { height: 100vh }` with no `body` margin reset.** Nothing in
`ui/src/styles/` resets the user agent's 8px body margin — confirmed in the shipped
`styles-*.css` — so the frame overflowed by 16px: both scrollbars, and the status bar 8px below the
fold, against DESIGN.md's yield order. Fixed, and pinned in `design-tokens.test.mjs` beside the
existing `100vh` assertion.

`[med]` `[patched]` QA's DW-143 row asserted the URL it had already loaded, so an inert area link
would have passed. Rewritten to start from the entity route.
`[med]` `[patched]` The command box had no outside dismissal — the gap DW-109 closed for the account
menu in the same story — so a click elsewhere left the sheet open with `aria-expanded="true"`.
`[med]` `[patched]` Enter in the collapsed command-box field navigated to the first screen in the
roster: `onKeydown` had no open guard and the empty query matches everything.
`[med]` `[patched]` The status bar's documented left/right split and left-hand order were unasserted;
moving the badge or the account menu left every row green.
`[med]` `[patched]` A swapped server-flag word shipped with nothing red: `strings.test.mjs` was
set-based in both directions and `status-bar.spec.ts` compares the rendered word against the same
symbol the component reads. The key-to-word mapping is now pinned.
`[med]` `[routed DW-148]` The command box and the locator's area segment navigate without
`ShellState.activateArea`, so a cross-area jump leaves the side bar listing the previous area and
never opens it (EXPERIENCE.md `:320`). Needs `ShellState` surface that does not exist; the locator's
doc comment, which claimed the opposite, is corrected.
`[med]` `[routed DW-149]` No skip link, and no ledger entry recorded the gap. The Boundaries decline
it as needing an unauthorized string; EXPERIENCE.md `:580` publishes the literal on the line
`Breadcrumb` was extracted from.
`[med]` `[routed DW-153]` A primary action renders as a fully enabled button with no handler, and the
command box offers the same row as selectable and then silently closes — the defect row actions were
given `aria-disabled` and a reason to avoid. Not reachable in Epic 1: Home declares neither.

`[low]` `[patched]` `CONTENT_ID` had two sources of truth — renaming it alone would compile and
silently break Escape's focus return. `[low]` `[patched]` `TestTheProductionLogSeamRunsAndSwallows
ItsOwnFailure`'s doc comment claimed to close a gap it does not (an emptied body still passes);
corrected at its origin and filed as DW-150. `[low]` `[patched]` Two `mutation:` lines carried
totals from a 19-method class against the 21 the file now has; the ratios are replaced by the test
names. `[low]` `[closed in pass]` QA's eight pinning rows had no `mutation:` line — each is now
named, applied, observed red and reverted. `[low]` `[wontfix-accepted]` DW-151 forced-colors lockup,
DW-152 the unreachable `connecting` arm, DW-154 the count region inserted already populated.
`[low]` `[occurrence]` DW-118 gains the dark-mode `.ocu-server-flag` rule, the one component rule
naming a `-dark` token; DW-141 gains the wider gap — nothing reads the filter signal.

**Rejected:** breadcrumb segments as `<button>` rather than `<a>` (no named harm, and the anchor form
is what produced the `href` HIGH); the four components' duplicated router-generation signal (no named
divergence); `withQuery` propagating an empty `?ns=` (unreachable without a hand-written URL);
`aria-controls` as a dangling IDREF while the box is shut (spec-bound — AC5 names it, and
`command-box.spec.ts` pins it); no per-screen document title (no AC, out of footprint); the spec's
`status: done` against `sprint-status: review` (build-auto's machine state, synced by the lead's
script at `cr_complete`).

**For the lead's adjudication:** DW-142 reads `status=open` while QA's `locator-bar.ts` change fixes
it and `locator-bar.spec.ts` pins the fix — the spec's `deferred:` list and Review Triage Log both
still describe the old behavior. `deferred:` also carries the superseded filter-label entry
alongside the entry correcting it. Neither is a reviewer edit.

**Rule 3.** The server half is satisfied — `OcuPilot.Test.Wire` exercises `/api/ocupilot/instance`
over real HTTP against the live instance. The client half is not: every geometric and cascade claim
is asserted as stylesheet text, and there is no browser-MCP or Playwright test in `ui/`. Rule 7
places that verification on the lead, and the spec's Manual checks name it. The `body` margin HIGH
above is exactly the class of defect that tier gap lets through.

## Spec Change Log

**Decision (overnight) — a refused status-bar read names itself in the log.** The Matrix row "A status-bar source fails" specifies `detail through Error.LogError, never a 500`; the three per-field `Catch` blocks swallowed silently, so a missing segment was unrecoverable. `Api.Instance.LogSourceFailure(pField, pException)` is the seam, called from each `Catch` and swallowing its own failure so the log call cannot become the 500 the per-field `Try` prevents.

## Review Triage Log

### 2026-09-12 — Review pass

- verdicts: 45 findings — high 3, medium 9, low 26, false 7, maybe-false 0
- findings:
  - `[high]` `[patch]` Sign out is unreachable in `version-mismatch`: the status bar that now hosts the account menu renders only inside `@if (instanceReady)`, and `instance-notice.ts` offered Sign out under `@if (noPrivileges)` alone — verified by reading the template; Story 1.7's stated invariant. Fixed: the button moved to the section, so both variants carry it.
  - `[high]` `[patch]` `CommandBox.choose()` navigated with `'/' + row.route`, dropping `?ns=` — an AD-44 violation on the one surface that reaches every screen. Fixed with `withQuery`, pinned by a new `command-box.spec.ts` row.
  - `[high]` `[patch]` The header lockup used `routerLink="/"` and dropped `?ns=`, so the header's Home and the rail's Home were different destinations from one URL. Fixed with `goHome()` over `withQuery`, pinned by a new `header.spec.ts` row.
  - `[medium]` `[patch]` `.ocu-account-trigger` is 24px tall plus a 1px border with no `box-sizing` and no global `border-box` — 26px inside a 24px band. Fixed with `box-sizing: border-box`.
  - `[medium]` `[patch]` `choose()` restored focus to the pre-open element, sending a keyboard user backwards after every palette navigation (and to a destroyed element). Fixed: focus is not handed back when the choice navigates.
  - `[medium]` `[patch]` Row actions were `aria-disabled` in the command bar and selectable-then-silently-inert in the command box. Fixed: the box draws them as the bar does, with the same reason inside the row.
  - `[medium]` `[patch]` `main.ts`'s `OverlayStack` provider was the one bootstrap provider no test pinned; deleting it builds clean, keeps the suite green and blanks every signed-in browser. Fixed: a clause beside the `ShellState` and `PreferenceStore` ones.
  - `[medium]` `[patch]` Both `locator-bar.spec.ts` navigation rows asserted the URL already loaded, so an inert link would pass. Fixed: both now start from the entity route.
  - `[medium]` `[patch]` `LogSourceFailure`'s production body had no test host — the fixture overrides it wholesale. Fixed: a test calling the real method, including the argument its inner `Catch` exists for.
  - `[medium]` `[patch]` `withQuery` carried the whole query string, so one screen's page/filter/sort would be applied to an unrelated screen. Fixed: only `ns` travels, pinned in `navigation.test.mjs`.
  - `[medium]` `[defer]` The command-bar filter has no accessible name and its `aria-describedby` count region is always empty, so the existing deferred entry's stated mitigation does not hold. Deferred — the fix is a Fixed-strings row, which this story may not add.
  - `[medium]` `[defer]` With an entity selected the locator marks the *screen* `aria-current="page"` and leaves it unlinked, so there is no route back to the list. The AC supports both readings; kept as built and filed.
  - `[low]` `[patch]` `Test/Wire.cls`'s doc said "four system reads" for five. Corrected.
  - `[low]` `[patch]` `.ocu-status-bar-version` could never ellipsize — a flex item needs `min-width: 0`. Added.
  - `[low]` `[patch]` The command box kept its query text and active row across close/reopen. Fixed: `close()` clears both.
  - `[low]` `[patch]` `TestAnUnflaggedInstanceReportsAnEmptyFlagAndStillCarriesTheKey` asserted against the live license key. Fixed: the licensee source is armed.
  - `[low]` `[patch]` `design-tokens.test.mjs` matched `transition-behavior: allow-discrete` against the whole file, so it passed on the base rule. Anchored to the hover rule.
  - `[low]` `[patch]` The `ServerFlag` word switch was exercised for two of four arms. Fixed: `status-bar.spec.ts` covers all four.
  - `[low]` `[patch]` A screen declaring a primary and a row action under one id would have produced two rows sharing a DOM id. Fixed by separate id prefixes.
  - `[low]` `[patch]` "Five bands" was used three incompatible ways across `app.ts`, `app.spec.ts` and the run result. Corrected to four bands around one row.
  - `[low]` `[patch]` The reported `OcuPilot.Test.Instance` totals disagreed (19/19, 19/20, 17/19) and named no source. Corrected in `## Auto Run Result`, with the source named.
  - `[low]` `[patch]` "Seven strings with a targeted extractor each" overstates: four extractors cover the seven. Corrected in `## Auto Run Result`.
  - `[low]` `[defer]` Escape now persists the side bar's collapse, because it routes through `toggleOpen()`. Real, and a product call neither document settles; a non-persisting close needs new public surface on `ShellState`.
  - `[low]` `[defer]` An unrecognised system mode is drawn verbatim, uncapped, with `nowrap`, so a long direct write to `^%SYS("SystemMode")` would stretch the 24px band.
  - `[low]` `[defer]` The truncated instance version is recoverable only through a `title` attribute, which is unreachable by keyboard and unreliable on touch.
  - `[low]` `[defer]` The command bar's "view options" control is named by the AC and by a doc comment that calls it filed, but no deferred entry existed for it. Filed now.
  - `[low]` `[defer]` The locator's area segment navigates into that area's first built screen without checking its verdict, where the rail and side bar both refuse.
  - `[low]` `[reject]` Ctrl/Cmd+B is inert whenever any overlay is stacked, not only a dialog — a deliberate broadening with no user-reachable harm; narrowing it adds a branch.
  - `[low]` `[reject]` Two `<h1>` elements on a denied screen — valid HTML5, no named harm, and the second belongs to another story's component.
  - `[low]` `[reject]` `OverlayStack.subscribe()`/`notify()` have no production caller — spec-bound: the Tasks list names `subscribe()` as part of the module's API. Closed by-design.
  - `[low]` `[reject]` `ReadSource` returns `""` for an unknown field name — no caller can reach it without a code change that would be caught at the same time. Theoretical.
  - `[low]` `[reject]` The two stylesheet regexes requiring literal newlines between selectors are reflow-fragile — a formatting change would be caught and corrected in the same pass; adding tolerance buys nothing.
  - `[low]` `[reject]` The command box renders two empty `role="group"` wrappers when a group has no rows — no announced content, no user-reachable harm.
  - `[low]` `[reject]` `command-box.spec.ts` pins `'1 screens, 0 actions'` — the template is EXPERIENCE.md's own; the grammar is a copy ruling, not a code defect.
  - `[low]` `[reject]` `_metrics.scss` inlines the inference's rationale rather than the bare `(inference)` label — the comment is one line and the recipe is not repeated elsewhere.
  - `[low]` `[reject]` `header.ts` parses `?ns=` to read it while `withQuery` parses to join — different operations, not a duplicated source of truth.
  - `[low]` `[reject]` `app-server-flag:empty { display: none }` is untested — a flex gap is cosmetic and the badge's absence is already pinned in the DOM.
  - `[false]` `[reject]` "`command-bar.spec.ts`'s chip/stamp row cannot fail" — it is a negative regression guard, falsifiable by exactly the change it guards against (drawing an empty stamp), the same shape `status-bar.spec.ts` uses.
  - `[false]` `[reject]` "The frame's height chain is unverified" — `design-tokens.test.mjs` pins each declaration against the shipped stylesheet, and the spec already assigns the rendered geometry to the lead under Manual checks.
  - `[false]` `[reject]` "DW-138's wrapper rule is untested" — `design-tokens.test.mjs`'s DW-138 row asserts the `app-rail, app-side-bar` display rule explicitly.
  - `[false]` `[reject]` "The command box is reachable while signed out" — it renders only inside `app.ts`'s `@if (instanceReady)` branch, which is inside `@if (signedIn)`; `app.spec.ts` pins both.
  - `[false]` `[reject]` "`serverFlagKind` does not trim" — it trims before folding; `session.test.mjs` asserts `' DEVELOPMENT '` and `'   '`.
  - `[false]` `[reject]` "The status bar renders an empty segment for a field the instance could not report" — each segment sits behind its own `has*` getter, pinned by `status-bar.spec.ts`.
  - `[false]` `[reject]` "Escape is handled in two places" — no component carries a `keydown.escape` binding; `session.test.mjs` asserts its absence in `account-menu.ts`.
  - `[low]` `[reject]` Intent-alignment audit: reports readings and surfaces, no defect beyond the sign-out reachability trade already patched above. Its R1-a/R1-b gap (contract surface vs rendered surface) is the spec's own Manual checks, already assigned to the lead.

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

- Header band, lockup, gradient and the 100% rule → `header.spec.ts`, with the stylesheet half in `ui/tools/design-tokens.test.mjs` (jsdom computes no layout and no cascade).
  `mutation: deleted href="/" from the lockup → header.spec.ts "the lockup links to Home and says so" red, alone among the component suite; observed and reverted`
- Status-bar segments, the single interactive element, and the badge absent from the header → `status-bar.spec.ts`, with `OcuPilot.Test.Instance` for the payload behind it.
  `mutation: made hasLicensedTo return true → status-bar.spec.ts "a segment whose value the instance could not report does not render" red; and, for the row's log clause, deleted LogSourceFailure from Api.Instance.LicensedTo's Catch → OcuPilot.Test.Instance red on TestAThrowingStatusBarSourceDegradesToAnEmptyField alone; both observed and reverted`
  `mutation (cr): moved <app-server-flag> into the left status-bar group → status-bar.spec.ts "the band is two groups, and DESIGN.md's order is which segment sits in which" red, alone among 112; observed and reverted`
- Locator bar: labeled `nav`, navigating segments, `aria-hidden` separators, current segment not a link, entity segment appearing and dropping → `locator-bar.spec.ts`.
  `mutation: set navigates: true on the screen segment → locator-bar.spec.ts's "nav named Breadcrumb" and "the area segment opens" rows red; observed and reverted`
- Command bar contents and `Select a row first` on row actions → `command-bar.spec.ts`.
  `mutation: set a row action's ariaDisabled to null → command-bar.spec.ts "row actions are aria-disabled with Select a row first" red; and, for the reveal jsdom cannot see, dropped the ":focus-visible +" selector from the reason's reveal rule → design-tokens.test.mjs "revealed on hover AND on focus" red; both observed and reverted`
- Command box combobox contract, grouping, polite count, kbd chip, gated rows → `command-box.spec.ts`.
  `mutation: dropped the gated guard from CommandBox.choose() → command-box.spec.ts "a gated screen stays listed and non-selectable" red; observed and reverted`
- **Integration AC** (two overlays, Escape order, outside dismissal) → `command-box.spec.ts` and `account-menu.spec.ts`, over `ui/tools/overlay-stack.test.mjs`.
  `mutation: made OverlayStack.push ignore the 'bottom' position → overlay-stack.test.mjs "the side bar stays the bottom-most member" red; and separately, deleted the focus restore from CommandBox.close() → command-box.spec.ts's Integration AC red; both observed and reverted`
- UX-DR80: the four chrome-height tokens gain consumers and the frame's arithmetic closes → `ui/src/app/app.spec.ts` with `ui/tools/design-tokens.test.mjs`.
  `mutation: replaced height: var(--ocu-header-height) with height: 48px in .ocu-header → design-tokens.test.mjs's consumer row and gradient row red; observed and reverted`
- **DW-10** (no flag → no badge; out-of-enum → verbatim in `restrained`) → `OcuPilot.Test.Instance` for the payload and `status-bar.spec.ts` for the badge.
  `mutation: defaulted an empty read to "LIVE" in Api.Instance.ServerFlag → OcuPilot.Test.Instance red on TestAnUnflaggedInstanceReportsAnEmptyFlagAndStillCarriesTheKey and TestThePayloadCarriesTheFlagLicenseeAndServerName; the same default in serverFlagKind → session.test.mjs's DW-10 row and status-bar.spec.ts "an unflagged instance gets no badge at all" red; observed and reverted`
  `mutation (cr): swapped the values of serverFlagLive and serverFlagDevelopment in strings.ts → strings.test.mjs "the header's two accessible names and the four flag words are EXPERIENCE.md's own" red; observed and reverted. The key-to-word mapping was set-based everywhere until this row, and status-bar.spec.ts compares the rendered word against the same STRINGS symbol the component reads`
- **DW-103** (rejection focuses the password field; sign-out focuses the user-name field) → `sign-in.spec.ts`.
  `mutation: always focused the user-name field → three sign-in.spec.ts rows red, including "a rejected attempt ... puts focus on the password field"; observed and reverted`
- **DW-109** (pointerdown and focus-out close the menu, `aria-expanded="false"`) → `account-menu.spec.ts`.
  `mutation: deleted the (document:pointerdown) host binding → account-menu.spec.ts "a pointerdown outside closes it without taking focus back" red; deleted (document:focusin) instead → the focus-out row red; both observed and reverted. The first mutation is why the pointerdown row asserts "focus did not come back to the trigger" rather than naming the outside element: the earlier assertion passed on the focus listener alone.`
- **DW-134** (Ctrl+Shift+B does not toggle; `?ns=` survives rail and side-bar navigation; Home's collapse is not persisted) → `side-bar.spec.ts`, `rail.spec.ts`, `ui/tools/shell-state.test.mjs`.
  `mutation: dropped !event.shiftKey from isSideBarChord → side-bar.spec.ts's Ctrl+Shift+B row red; navigated with '/' + route instead of withQuery in side-bar.ts and in rail.ts → each file's namespace row red; restored setOpen in ShellState's Home branch → shell-state.test.mjs's DW-134 row red; and at review, called withQuery(row.route, '/') in CommandBox.choose → command-box.spec.ts "opening a screen from the box keeps the namespace" red, alone among the component suite; all observed and reverted`
- **DW-137** (Escape collapses the side bar when it is the top overlay; the tooltip delay token exists, is consumed and is zeroed under reduced motion) → `side-bar.spec.ts` and `ui/tools/design-tokens.test.mjs`.
  `mutation: deleted the side bar's overlays.push → side-bar.spec.ts's two DW-137 rows red; dropped var(--ocu-motion-tooltip-delay) from the hover reveal → design-tokens.test.mjs's tooltip row red; both observed and reverted`
- **DW-138** (the frame's height chain and the rail's bottom slot as its last child) → `ui/src/app/app.spec.ts`. jsdom computes no layout, so this pins structure; the rendered geometry is the browser measurement below and not a claim this test makes.
  `mutation: bound [class.ocu-rail-slot-bottom] to false → app.spec.ts's DW-138 row and rail.spec.ts's roster row red; deleted flex: 1 1 auto from .ocu-shell, and separately display: flex from the app-rail/app-side-bar wrapper rule → design-tokens.test.mjs's DW-138 row red each time; all observed and reverted`

- **Review patch** (sign-out is reachable from both blocking notices, not only the no-privileges one) → `ui/tools/session.test.mjs`'s AC3 row and `ui/src/app/app.spec.ts`'s version-mismatch row.
  `mutation: moved the Sign out button back inside instance-notice.ts's @if (noPrivileges) → session.test.mjs AC3 red and app.spec.ts "an unverified instance renders the blocking notice" red; observed and reverted`

**QA-stage pinning rows (mutations demonstrated at code review, one per row):**

- **DW-142** (the screen segment links back once an entity follows it) → `locator-bar.spec.ts`.
  `mutation: set navigates: false and ariaCurrent: 'page' on the screen segment and ariaCurrent: null on the entity → locator-bar.spec.ts "DW-142: once an entity is selected, the screen segment becomes a link back to the list" and "the entity segment appears on selection, in code, and drops when it clears" red; observed and reverted`
- **DW-143** (the area segment navigates without consulting the verdict) → `locator-bar.spec.ts`.
  `mutation: added a screenVerdict(...).allowed guard to LocatorBar.open() → locator-bar.spec.ts's DW-143 row red; observed and reverted. The row was rewritten at review to start from the entity route: begun on the list it asserted the URL it had already loaded and could not fail either way`
- **DW-141** (the filter has no accessible name and an empty description) → `command-bar.spec.ts`.
  `mutation: made CommandBar.matchCount return a non-empty string → command-bar.spec.ts's DW-141 row red; observed and reverted. For a pinned-not-fixed row the falsifying change is the fix`
- **DW-147** (no view-options control renders) → `command-bar.spec.ts`.
  `mutation: rendered a button with aria-haspopup="menu" in the command bar → command-bar.spec.ts's DW-147 row red; observed and reverted`
- **DW-144** (Escape persists the side bar's collapse) → `side-bar.spec.ts`.
  `mutation: made ShellState.toggleOpen() set currentOpen directly instead of through setOpen() → side-bar.spec.ts's DW-144 row red, together with both "Ctrl/Cmd+B remembers the answer" rows; observed and reverted`
- **DW-145** (an unrecognised mode is drawn verbatim and uncapped) → `status-bar.spec.ts` and `ui/tools/design-tokens.test.mjs`.
  `mutation: truncated the default arm of ServerFlag.word to 12 characters → status-bar.spec.ts's DW-145 row red; separately, added max-width to .ocu-server-flag → design-tokens.test.mjs's DW-145 row red; both observed and reverted`
- **DW-146** (the truncated version is recoverable only through `title`) → `status-bar.spec.ts`.
  `mutation: deleted [title]="instanceVersion()" from the version segment → status-bar.spec.ts's DW-146 row red; observed and reverted`

**Review patches (this pass):**

- **Sign out is reachable in `checking` too**, not only in the two variants that have a sentence → `ui/src/app/app.spec.ts` and `ui/tools/session.test.mjs`.
  `mutation: restored the @if (hasNotice) gate over instance-notice.ts's section → app.spec.ts "an instance check that never settles still offers Sign out" and session.test.mjs "an unsettled check still reaches Sign out" red; observed and reverted`
- **The header lockup's own `href` is the application's Home**, and a modified click is left to the browser → `header.spec.ts`.
  `mutation: wrote href="/" raw instead of prepareExternalUrl(withQuery(...)) → header.spec.ts "the lockup's own href carries the namespace" red on the href assertion; separately, deleted goHome's modifier guard → the same row red on its cancelled-by assertions; both observed and reverted`
- **The frame is exactly the viewport**, because `body` carries no margin → `ui/tools/design-tokens.test.mjs`.
  `mutation: deleted body { margin: 0 } from _components.scss → design-tokens.test.mjs's UX-DR80 row red; observed and reverted`
- **The command box dismisses on an outside gesture, and binds nothing while it is shut** → `command-box.spec.ts`.
  `mutation: deleted the (document:pointerdown)/(document:focusin) host bindings → command-box.spec.ts's two dismissal rows red; separately, deleted the openFlag guard from onKeydown → "Enter in the collapsed field navigates nowhere" red; both observed and reverted`

Whoever adds or materially changes a pinning test writes its `mutation:` line in the same pass: name the smallest change that violates the AC, apply it, observe red, revert, and confirm `git status --short` and `git diff --stat` are unchanged.

**Manual checks:**

- Desktop Chrome against the live instance at `http://localhost:52774/ocupilot/`: the five bands at their token heights; the header gradient and the lockup at 32px; the status bar's segments and the flag badge's absence on this unflagged container; Ctrl/Cmd+K, Escape order across command box → side bar, Ctrl+Shift+B doing nothing, and the rail tooltip's 300ms reveal.
- **DW-138 geometry (lead, browser MCP per Rule 7):** measure `getBoundingClientRect()` on `.ocu-rail` and on the Agent co-pilot slot — the rail's height equals the viewport minus the header and status bar, and Agent co-pilot's top is below Security's bottom with free space between them.

## Auto Run Result

Status: done
Blocking condition: none

**What this pass built.** Four bands around one row -- `header` and `status-bar` outside,
`locator-bar` and `command-bar` in the content column -- plus `command-box` and `server-flag`;
`core/overlay-stack.ts`; the three status-bar fields on `GET /api/ocupilot/instance` and their
client mirror; seven new strings, each re-derived from a UX document by one of four targeted
extractors; the frame's height chain in `_components.scss`; and the six routed ledger items.
`app.ts` reparents into the frame and owns the one Escape handler; `account-menu.ts` moved into
the status bar and gained outside dismissal; `sign-in.ts` gained the DW-103 focus effect;
`side-bar.ts` and `rail.ts` took the chord, query and overlay fixes.

**Files changed.** Server: `Api/Instance.cls` (three fields, one `ReadSource` seam, one
`LogSourceFailure` log seam), `Test/InstanceFixture.cls` (source and log capture),
`Test/Instance.cls` (+6 methods), `Test/Wire.cls` (the three fields over the real wire). Client
core: `overlay-stack.ts` *(new)*, `instance.ts`, `navigation.ts` (`withQuery`, `builtScreens`,
`screenForUrl`), `shell-state.ts`, `strings.ts`, `main.ts`. Shell: `header.ts`, `status-bar.ts`,
`server-flag.ts`, `locator-bar.ts`, `command-bar.ts`, `command-box.ts` *(all new)*,
`account-menu.ts`, `sign-in.ts`, `side-bar.ts`, `rail.ts`, `screen-outlet.ts`,
`instance-notice.ts`, `app.ts`. Styles: `_metrics.scss` (the tooltip-delay token),
`_components.scss` (the frame, the five bands, the pills, the box). Tests: eight new `.spec.ts`,
`overlay-stack.test.mjs` *(new)*, and `session/shell-state/strings/design-tokens/navigation`
extended. Asset: the reversed lockup, vendored.

**Review findings.** 45 findings across four layers. 21 patched (3 high, 7 medium, 11 low),
9 deferred to the frontmatter list, 15 rejected -- 8 with a named reason (deliberate broadening,
valid HTML5, spec-bound API, theoretical, reflow fragility, empty groups, a copy ruling, an
inference label) and 7 as `false` on their refutation. The three high findings were all real
regressions or AD violations: Sign out unreachable behind the version-mismatch notice once the
account menu moved into the `ready`-only status bar, and `?ns=` dropped by the command box and
by the header lockup (AD-44) while the rail, side bar and locator all carried it.

**How it was verified.** `npm --prefix ui test` 305 Node + 112 component, green.
`npm --prefix ui run build` exit 0, `client-lint: clean`, initial 325.25 kB (under the 1 MB
budget). `uv run scripts/check-objectscript.py` and `bash scripts/lint-docs.sh` clean.
`iris_doc_load` + `iris_doc_compile` on `src/OcuPilot/` clean. `OcuPilot.Test.Instance` 21/21 and
`OcuPilot.Test.Wire` 11/11 -- counts from the MCP runner envelope and confirmed against
`%UnitTest_Result` by the SQL probe in `.claude/rules/objectscript-testing.md`, one class per
call. Every `mutation:` line above was applied, observed red and reverted, with `git status
--short` and `git diff --stat` unchanged by the exercise.

**Three decisions taken in the build, each recorded where it was made.**

1. `app.ts` keeps `productName` as a clipped `h1` rather than the drawn placeholder line the
   header replaces. It is what gives the document a heading and what keeps
   `build-output.test.mjs`'s first-string and first-class reads pointed at `app.ts`, which the
   task list requires; the name is never typeset as the wordmark, which is DESIGN.md's rule.
2. `session.test.mjs`'s two account-menu location assertions and its Escape assertion were
   rewritten, not deleted: the menu is mounted by `status-bar.ts` now, and Escape belongs to
   the overlay stack, so a local `(keydown.escape)` binding would close two surfaces on one key
   press. The new assertions pin both facts.
3. The locator bar decodes the route's `id` parameter for its own segment.
   `screen-outlet.ts`'s claim to be "the client's single decode point" was corrected at its
   origin: decode-once is per value, and neither call is chained onto the other's result.

**DW-138 has a second link, one level down from the one it was filed for.** A custom element is
`display: inline` until something says otherwise, so a stretched `app-rail` whose own box is not
a flex container still leaves `.ocu-rail` at content height and the bottom slot with nothing to
push into. The wrapper rule closes it, and `design-tokens.test.mjs`'s DW-138 row now names it --
which is also the one thing the lead's browser measurement should confirm first.

**Follow-up review recommended: true.** Not for patch volume -- for one named risk. The
rendered-browser surface is still unobserved: the four band heights, the header gradient, the
32px lockup, the flag pill's color pairs and the tooltip's 300ms reveal are pinned as
stylesheet text and token values, never as computed layout, and this pass then changed three
things that only a browser settles -- `box-sizing` on the account trigger inside the 24px band,
`min-width: 0` on the version segment, and a Sign out button added to the version-mismatch
notice. The running container also still serves the pre-1.10 bundle, so that check needs a
redeploy, which is the owner's call.

**Residual risks.** (1) The rendered surface above. (2) Two accessibility gaps that cannot close
without a Fixed-strings row -- the command-bar filter has no accessible name and its count region
is empty, and the command box's groups carry no label; both are in `deferred`. (3) `withQuery`
now carries only `ns`, which is right for AD-44 today and is a decision Epic 2 will meet the
first time a screen wants a second parameter to survive a navigation.

**Left for the lead:** the DW-138 browser measurement and the desktop-Chrome pass over the
bands, both assigned to the lead under Rule 7, plus the harvest of the 15 `deferred:` items.
