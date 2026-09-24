---
title: 'Story 15.6: The light and dark theme'
type: 'feature'
created: '2026-09-23'
status: 'done'
baseline_revision: '75be3d16452efc768d87c8321f2e75b6bb1d4c2c'
baseline_commit: '75be3d16452efc768d87c8321f2e75b6bb1d4c2c'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-15-context.md'
warnings: ['oversized']
deferred:
  - summary: >-
      The structural baseline was taken on local Chrome against ocupilot-b-ci; whether its 190 keys reproduce in CI's browser job is unverified.
    evidence: |-
      Overflow keys trip at more than 1px and several recorded overshoots are 4-6px; fonts are vendored, which narrows the gap (inference). Settled by the first CI browser run on this commit: zero fresh and zero stale keys.
    location: >-
      ui/browser/structural-baseline.json
    severity: medium (unverified)
  - summary: >-
      The page ground paints no surface role: the content area shows the browser canvas (#fff in light, Chrome's dark canvas in dark) rather than surface / surface-dark.
    evidence: |-
      No rule sets a background on html, body or the shell content (body carries only margin: 0 in _components.scss); pre-existing in light, visible in dark after the flip. Fixing it is a new component or root rule, outside 15.6's token-substitution charter.
    location: >-
      ui/src/styles/_components.scss:605
    severity: low
---

<intent-contract>

## Intent

**Problem:** The dark scope `:root.ocu-theme-dark` re-points only the 30 `--mat-sys-*` variables, while the component layer reads 447 bare `var(--ocu-<role>)` references and no `--mat-sys-*` one. Adding the class therefore changes almost nothing (DW-39, DW-118). Nothing sets the class, and there is no toggle. Separately, no gate looks at a rendered screen as a whole, so a missing label, a too-narrow control or an overflow fails only if a story happened to pin that exact figure (DW-1337).

**Approach:** Make the dark scope re-point every color role to its `-dark` twin. DESIGN.md already declares all 64 twins and `_tokens.scss` already holds them. The theme becomes a framework-free store that sets one root class. The choice is saved as a `shell` member of 15.5's preference store and toggled from the account menu. Alongside this, ship DW-1337's owner-approved ratchet: one walk over every screen the registry declares, in both themes, that checks accessible names, control minimum widths, overflow and text contrast against a baseline recorded once.

## Boundaries & Constraints

**Always:**

- The toggle is a flag flip. `ocu-theme-dark` is named in exactly two source files: `ui/src/styles/_theme.scss`, which holds the scope, and `ui/src/app/core/theme.ts`, which sets the class. No component rule selects on the theme.
- Every color value comes from DESIGN.md's frontmatter. A literal color may appear only in `_tokens.scss` (client-lint). Re-points go in `_theme.scss`, never in `_tokens.scss`, because `parseTokens` (`ui/tools/design-tokens.mjs:148`) reads that whole file.
- The chrome stays navy in dark mode (DESIGN.md:851, :1275). Chrome rules that already name `focus-ring-dark`, `secondary-dark`, `agent-accent-dark` or `warning-dark` keep doing so in both modes.
- The theme is per user and lives on the instance (AD-50). Its only home is the `shell` kind's new `theme` member, with value `light` or `dark`. Nothing is written to browser storage. Light is the default on first load (EXPERIENCE.md:43).
- The theme write is a self-service account action (AD-49). It creates no proposal, no marker and no tool.
- New strings are published in EXPERIENCE.md's Fixed strings table, appended after its current last row `:423`, before they exist as `strings.ts` keys.
- The gate derives its screens from the registry at run time and never from a hand-written route list. It runs in baseline form: only a violation outside the baseline fails.

**Never:**

- 15.6 fixes nothing the gate finds unless the fix is a token in its own footprint. A dark-only contrast failure is the exception: it is this story's own defect and is fixed by a token (see Design Notes).
- Never regenerate `ui/src/app/core/screens.generated.ts`, and never edit a product file Epic 7 has modified (`panel.ts`, `data-table.ts`, `command-bar.ts`, `list-page.ts`, `Screen/Registry.cls`, `Install/Smoke.cls`, among others). The only exception is the pre-authorized bundle-budget line.
- Never write `deferred-work.md`. The lead files one ledger item per baseline entry after `dev_complete`.
- Do not implement the rail icons; they are 15.7's.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| First load, signed out | fresh browser | sign-in screen renders light; `<html>` has no `ocu-theme-dark` | none expected |
| Signed in, preference read still pending | `loaded()` false | shell renders light (the published default) | a failed read keeps light |
| Read answers `theme=dark` | shell member `theme`=`dark` | class set once; every surface takes its `-dark` twin | no error expected |
| Toggle in the account menu | user activates "Dark theme" | class flips at once; `aria-checked` flips; `setValue('shell','theme',…)` is written without awaiting | a refusal surfaces through the store's existing `fault()` surfaces (DW-1326) |
| Sign out | `endSession()` | class removed, back to light before the next user's read | no error expected |
| Invalid value on the wire | `POST {kind:'shell',name:'theme',value:'purple'}` | `422 PREFERENCES.CHOICE`, nothing written, `reason` not empty | refused before any write |
| Never toggled | nothing stored | nothing is written on adopt or on default; the store holds no `theme` row | none expected |
| Gate: new violation | a key missing from the baseline | CI `browser` job fails and names route, invariant, context and element | none expected |
| Gate: stale baseline entry | a baseline key the walk no longer finds | printed by key with a "remove this entry" instruction; the gate stays green | none expected |
| Gate: an id-requiring screen neither walked nor skipped | new `parentScope` screen with no id resolved | gate fails and names the screen | none expected |

</intent-contract>

## Code Map

### Tokens and theme

- `ui/src/styles/_tokens.scss:33-200` — every role declared twice (light, `-dark`), 64 roles. Non-role tokens: `logo-gradient-stop` (no dark), `elevation-1..3` with dark twins (`:186-199`). This is the only file allowed a literal color.
- `ui/src/styles/_theme.scss:54-102` — the light scope (30 `--mat-sys-*` re-points plus `color-scheme: light`). `:104-146` is the dark scope, which today re-points only those 30. This is where the 64 role re-points and the non-role re-points go.
- `ui/src/styles/_components.scss` — `:1915-1921` holds the only component-level `:root.ocu-theme-dark` rule (`.ocu-server-flag` edge). DESIGN.md:313 names `on-shell` at 20%, and the rule reads `on-shell-dark`. `:1376-1381` already draws the dark 4.497:1 pair's remedy. The chrome's `-dark` rules are at `:523`, `:800`, `:875`, `:899`, `:1124`, `:1182`, `:1294`, `:2608` and `:4467`. Epic 7's only hunk in this file is an append after `:5259`.
- `ui/src/app/shell/toast-host.ts:65` — the inline `.ocu-toast-action` rule, `color: var(--ocu-secondary-dark)`. DESIGN.md:501-502 gives `link-color` = `secondary-dark` and `link-color-dark` = plain `secondary`. This is the one pair whose variant is reversed between modes.
- `ui/tools/design-tokens.mjs` — `COLOR_ROLES` `:52-86`, `NON_ROLE_TOKENS` `:95`, `parseTokens` `:148`, `LOAD_BEARING` `:216-247`, `MARGINAL_GUARDED` `:260-291`. `ui/tools/design-tokens.test.mjs` — roster `:69-112`, fidelity against DESIGN.md `:119`, non-role tokens `:144-160`, load-bearing pairs in both modes `:163`, marginal guards `:184-215`. `ui/tools/build-output.test.mjs:375-395` — the dark scope in the built CSS; the authored re-point count must equal the emitted count.
- `ui/tools/client-lint.mjs:62,101` — `no-hardcoded-color` exempts `_tokens.scss` only.

### Preference and toggle

- `ui/src/app/core/account-preferences.ts` — `SHELL_KIND` `:45`, `SHELL_SIDE_BAR_OPEN` `:48`, `SHELL_PANEL_WIDTH` `:51`, `loaded()` `:268`, `shell()` `:293`, `fault()` `:298`, `setValue` `:349`, `reset()` `:398`.
- `ui/src/app/core/shell-state.ts` — the pattern to copy: subscribe and adopt `:81-102`, `endSession` `:279-284`, fire-and-forget write `:286-292`. `core/build-identity.ts:72` guards `typeof document`.
- `ui/src/main.ts:139-146` builds the stores, and `:236-248` provides them. `ui/src/app/app.ts` sign-out branch: `shell.endSession()` `:547`, `accountPreferences.reset()` `:563`. Load happens at `:600`.
- `ui/src/app/shell/account-menu.ts` — items at `:103-130` (About, Change password, Sign out). Each item is `<button role="menuitem" class="ocu-account-item" tabindex="-1">`. Keyboard handling `onMenuKeydown` is at `:232-244`, and the polite status region at `:133`. `account-menu.spec.ts` — providers `:100-105`, item roster `:136-150`, length check `:152-171`, and the fourth-item case already written for 15.6 at `:173`.
- `src/OcuPilot/Kernel/State/Pref.cls` — `KINDSHELL` `:84`, `SHELLSIDEBAROPEN` `:88`, `SHELLPANELWIDTH` `:92`, `IsShellMember` `:317-322`.
- `src/OcuPilot/Api/Preferences.cls:199-206` — shell name check and value check. No per-member value check exists. `src/OcuPilot/Api/Error.cls` — `PREFERENCESVALUE` `:1451`, arm `:1092` in `ReasonForViolation`.
- `src/OcuPilot/Test/PrefState.cls:408-413` (`TestTheShellMemberSetIsClosed`) and `src/OcuPilot/Test/PreferencesWire.cls:390-406` (refusal sentences).
- `ui/src/app/core/strings.ts:1493-1497` — the last key, its `/** EXPERIENCE.md:423 */` comment, and `} as const;`. `ui/tools/strings.test.mjs` — set equality `:562-581`, line comments must resolve `:726-770`.

### Browser tier

- `ui/package.json:17-18` — `pretest:browser` builds; `test:browser` = `node --test --test-concurrency=1 browser/*.browser-spec.mjs`, which runs files alphabetically. CI job: `.github/workflows/ci.yml:184-233` on a fresh throwaway. No spec roster is kept anywhere.
- `ui/src/app/core/navigation.ts` — `builtScreens()` `:108-110` (the router's own set) and `hasIdRoute` `:495-497`. `ui/src/app/app.routes.ts:63-84` adds `/:id`. Specs import `.ts` at run time (`browser/gate.browser-spec.mjs:53`). Measured today: 47 declared screens, 46 built. Six declare `parentScope`; `web-applications/rest-apis/document` is the one-object viewer.
- `ui/browser/panel-spec.mjs:62-83` `signedInAt(browser, config, url, viewport)`. `browser/shell-entry.mjs:16-19` says never issue a second `page.goto` after sign-in, because the first-login gate returns; `:53-87` has `leaveFirstLoginGate`. `browser/preferences-reset.mjs:54-64` has `resetRememberedState()`, which clears every kind and so also `theme`. `browser.config.mjs` holds the origin and container environment variables and `launchOptions`.
- `ui/tools/browser-reset.mjs:64-92,406-411` — every spec, and every helper it imports, calls `resetRememberedState()` once per context it creates.
- `ui/browser/ui-state-survives-sign-out.browser-spec.mjs` — the template for sign-out and sign-in in a new `BrowserContext` (`:121-134`, `:279-294`). `ALLOWED_SESSION_KEYS` is at `:58`. `:273` expects the shell names to be exactly `['panelWidth','sideBarOpen']`, which holds only if nothing writes `theme` unprompted.
- `ui/browser/home-system-information.browser-spec.mjs:199-222` — the existing `scrollWidth` check at `ZOOM_FLOOR_WIDTH = 720`.
- DW-1388: the panel host `_components.scss:646-651` (`min-width: var(--ocu-panel-min)` 320) and the resize handle `:3203-3212` (`left: -4px; width: 8px`). `core/panel-layout.ts:98-127` computes the panel at 320 and content at 352 when the viewport is 720. These files are Epic 5's and Epic 7's and are read-only here.

## Tasks & Acceptance

**Execution:**

- `ui/src/styles/_tokens.scss` — Add two non-role pairs from DESIGN.md's own component keys (transcribed, not invented):
  - `--ocu-toast-link` (`#6fd3dc`, which is `secondary-dark`) and `--ocu-toast-link-dark` (`#0b7080`, which is `secondary`), from DESIGN.md:501-502.
  - `--ocu-server-flag-edge: transparent` and `--ocu-server-flag-edge-dark: color-mix(in srgb, var(--ocu-on-shell) 20%, transparent)`, from DESIGN.md:313.
  - Update the header count note.
- `ui/src/styles/_theme.scss` — Inside `:root.ocu-theme-dark`, re-point every one of the 64 bare `--ocu-<role>` to `var(--ocu-<role>-dark)`, and do the same for every `NON_ROLE_TOKENS` entry that has a dark side. Keep the 30 `--mat-sys-*` lines and `color-scheme`. Rewrite the header comment so it states the scope is complete. This closes DW-39 and DW-118.
- `ui/src/styles/_components.scss` — Token substitution only. In the base `.ocu-server-flag` rule, change `border: 1px solid transparent` (`:1864`) to `border: 1px solid var(--ocu-server-flag-edge)`, and delete the `:root.ocu-theme-dark .ocu-server-flag` rule at `:1915-1921`. Add no other rule.
- `ui/src/app/shell/toast-host.ts:65` — Token substitution only: `color: var(--ocu-toast-link)`.
- `ui/tools/design-tokens.mjs`, `ui/tools/design-tokens.test.mjs` — Add both new pairs to `NON_ROLE_TOKENS`.
  - Pin `toast-link` and `toast-link-dark` to the hexes of `secondary-dark` and `secondary`, and tie them to `MARGINAL_GUARDED[2]`.
  - Add a test that parses `_theme.scss`'s dark scope. It must hold exactly one `--ocu-X: var(--ocu-X-dark)` for each role and for each non-role token with a dark side, derived from `COLOR_ROLES` and `NON_ROLE_TOKENS` rather than a literal count.
  - Add a test that `ocu-theme-dark` appears under `ui/src` only in `_theme.scss` and `core/theme.ts`.
- `ui/tools/build-output.test.mjs` — Extend `:375-395` to show the built CSS's dark scope re-points `--ocu-shell` and `--ocu-on-surface`.
- `src/OcuPilot/Kernel/State/Pref.cls` — Add `SHELLTHEME = "theme"` and an `IsShellMember` line. Add `THEMELIGHT`/`THEMEDARK` and `IsThemeValue(pValue)`.
- `src/OcuPilot/Api/Preferences.cls:203-206` — When a shell `set` names `theme`, refuse any value other than `light` or `dark` with `PREFERENCES.CHOICE` before any write.
- `src/OcuPilot/Api/Error.cls` — Shared-append: `PREFERENCESCHOICE` and `REASONPREFERENCESCHOICE` ("That preference takes one of a fixed set of values."), plus its arm in `ReasonForViolation` next to `:1092`. Without the arm, `reason` serializes empty.
- `src/OcuPilot/Test/PrefState.cls` — Add `theme` to `TestTheShellMemberSetIsClosed` and add an `IsThemeValue` test. `src/OcuPilot/Test/PreferencesWire.cls` — Add a `theme` `set` round trip, and add the `purple` refusal with a non-empty `reason` to the sentence cases at `:390-406`.
- `ui/src/app/core/account-preferences.ts` — Add `SHELL_THEME = 'theme'`, `THEME_LIGHT` and `THEME_DARK`.
- `ui/tools/account-preferences.test.mjs` — Add a test that the client's `SHELL_*` member values equal `Pref.cls`'s `SHELL*` parameters in both directions. No test pins that roster today.
- `ui/src/app/core/theme.ts` (new) — `ThemeState`, framework-free (AD-19). It takes `{account, root}`, where `root` has a `classList`. It exposes `theme()`, `setTheme()`, `toggle()`, `endSession()`, `subscribe()`.
  - It adopts the remembered value once, only after `loaded()`, the way `ShellState` does. An unknown or absent value reads as light.
  - It writes only from `setTheme` or `toggle`, never on adopt.
  - It exports `THEME_DARK_CLASS = 'ocu-theme-dark'`.
- `ui/tools/theme.test.mjs` (new) — Cover:
  - light before the read settles;
  - dark adopted once;
  - toggle sets the class and writes once;
  - no write on adopt;
  - `endSession` removes the class;
  - an unknown stored value reads as light.
- `ui/src/main.ts`, `ui/src/app/app.ts` — Build and provide `ThemeState` with `root: document.documentElement` beside `ShellState`, and call `theme.endSession()` beside `app.ts:547`.
- `ui/src/app/shell/account-menu.ts`, `account-menu.spec.ts` — Add a `role="menuitemcheckbox"` item "Dark theme" whose `aria-checked` mirrors `ThemeState`, placed next to Change password.
  - Activating it toggles the theme and leaves the menu open with focus on the item.
  - The roving and arrow-key model covers it.
  - Update the spec's providers, roster and length check, and make the `:173` fourth-item case real.
- `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md` — Append one Fixed-strings row after `:423`: `"Dark theme"` (Story 15.6, FR-73), the account menu's theme toggle (`:81`, `:438`). Then add `accountDarkTheme` to `ui/src/app/core/strings.ts` after `:1494`, in a block commented with the story.
- `ui/browser/structural-walk.mjs` (new helper, outside the `*.browser-spec` glob) — the walk described under Design Notes › The gate:
  - screen derivation from `builtScreens()` and id resolution;
  - the in-page detectors for name, min-width, overflow and contrast;
  - key building and `compare(found, baseline) → {fresh, stale}`;
  - a `--write` entry point, guarded by `pathToFileURL(process.argv[1])`, that walks and writes the baseline.
  - It calls `resetRememberedState()` before each context.
- `ui/browser/structural-baseline.json` (new) — Generated once by `node browser/structural-walk.mjs --write` against a freshly started slot-B throwaway. Never hand-written.
- `ui/browser/a11y-structural-invariants.browser-spec.mjs` (new; the name sorts it first, so CI walks the same fresh state the baseline was taken on) — Four parts:
  - the walk;
  - a failure on `fresh`;
  - a report of `stale` and of the walked, skipped, not-built and unmeasurable counts;
  - one detector-liveness test per invariant, which plants a violation in a walked page (an unlabelled `<input>`, a 10px `<button>`, a child 50px wider than a non-clipping parent, `#777` text on `#888`) and asserts the walk reports it.
- `ui/tools/structural-baseline.test.mjs` (new) — Tests `compare` and the key format:
  - a fresh key fails;
  - a stale key is reported and does not fail;
  - `dw`, `tag`, `count` and `measured` are ignored;
  - duplicates collapse.
  - It also checks, over the committed baseline, that every `contrast|dark` entry has a `contrast|light` twin with the same route and element, and that every owner-reported tag is present.
- `ui/browser/theme.browser-spec.mjs` (new) — Five parts:
  - toggle through the real account menu;
  - dark persists across a real sign-out and back in, in a new `BrowserContext`, with `localStorage` empty and `sessionStorage` keys equal to `ALLOWED_SESSION_KEYS`;
  - the sign-in screen is light;
  - chrome figures in both modes: status bar and rail background are `shell`, then `shell-dark`; the rail `:focus-visible` outline is `focus-ring-dark`; the active indicator is `secondary-dark`;
  - `--ocu-toast-link` resolves to `#6fd3dc` in light and `#0b7080` in dark, and the keyboard-active command-box option's caption takes `on-secondary-container` in dark.
- `ui/angular.json`, `ui/tools/angular-json.test.mjs` — **Conditional.** Only if the initial bundle exceeds `maximumWarning` 1261kB, apply DW-1166: set it about 5% above the measured total (1 kB = 1,000 B), changing only that value line and the pinned literal at `angular-json.test.mjs:371`, and cite DW-1166 and the byte count. Epic 7 has changed the same line (`1181kB`), so the merge resolves to the higher measured figure.

**Acceptance Criteria:**

- **AC1.** Given the 64 roles and the non-role pairs, when `:root.ocu-theme-dark` is present, then every `--ocu-*` role and `--mat-sys-*` variable resolves to its `-dark` value, and no rule outside `_theme.scss` selects on the class. The toggle is a flag flip. (DW-39, DW-118)
- **AC2.** Given the account menu, when it opens, then "Dark theme" sits beside Change password as a `menuitemcheckbox` whose state matches the rendered theme. Given a choice of dark, when the user signs out and back in, then dark returns.
- **AC3.** Given dark mode, when the chrome renders, then the status bar and rail are `shell-dark` (navy, deeper), the rail focus ring is `focus-ring-dark`, and the rail indicator is `secondary-dark`, which are the same variants as in light.
- **AC4.** Given every walked screen in dark mode, when text contrast is measured, then it meets 4.5:1, or 3:1 for large text, as in light. The baseline carries no dark-only contrast entry. The three marginal guards still pass their hex-level check in both modes (`design-tokens.test.mjs:184`), and the rendered remedy and toast link hold.
- **AC5 (DW-1337).** Given the registry, when CI's `browser` job runs, then the gate walks every built screen at 1280 and 720 in light and at 1280 in dark. It fails on any violation outside the baseline, reports stale entries without failing, reports walked, skipped and not-built counts, and fails on an id-requiring screen that is neither walked nor skipped.
- **Integration AC (Rule 1): theme.** Given dark chosen in one browser context, when the same user signs in from a brand-new `BrowserContext` against the deployed bundle, then `ThemeState` adopts `dark` from the instance's `shell.theme` row and `<html>` carries the class. Browser storage holds nothing but the token pair.
- **Integration AC (Rule 1): gate.** Given the CI `browser` job, when `npm run test:browser` runs, then the gate is discovered with no roster edit. A planted violation outside the baseline turns it red (a mutation is recorded under Verification).
- **AC6 (DW-1388).** Given the walk at 720px, when the baseline is taken, then the agent panel's overflow is an entry tagged `DW-1388` with the recorded diagnosis (agent panel, not Home). If the walk does not find it, `ownerReported` says so and gives the walk's measurement. The overflow is fixed here only if the cause is a value in 15.6's token files that differs from DESIGN.md.

### Review Findings

Code review 2026-09-23 (full-opus; blind-hunter, edge-case-hunter, verification-gap, acceptance-auditor). 56 rows, 17 entries after grouping: high 2, med 1, low 14.

- [x] [Review][Patch] HIGH: the Dark theme item broke 15.1's arrow-model test (CI 35934116068 red) [ui/browser/change-password.browser-spec.mjs:198] — fix-risk low; the test walks four items.
- [x] [Review][Patch] HIGH: CI's gate found one key the local baseline lacks, `agent/definitions|overflow|720|app-command-bar>span.ocu-command-bar-sort` [ui/browser/structural-baseline.json:102] — fix-risk low; the CI-printed entry was appended (the spec's merge path). CI reproduced the other 190 keys. DW-1580 trailer records it.
- [x] [Review][Patch] MED: the name check passed a field Chrome leaves out of the accessibility tree, or answers nothing for [ui/browser/structural-walk.mjs:497] — fix-risk low; both are reported, with an `aria-hidden` liveness case.
- [x] [Review][Patch] DW-1581: the page ground painted no surface role [ui/src/styles/_components.scss] — fix-risk low; this story's own `body` block, pinned in `theme.browser-spec.mjs` AC3 in both themes.
- [x] [Review][Patch] Liveness gaps: the page-level overflow branch, class minimums and token minimums (a NaN token passed silently) [ui/browser/a11y-structural-invariants.browser-spec.mjs] — fix-risk low.
- [x] [Review][Patch] `--write` overwrote an existing baseline [ui/browser/structural-walk.mjs:699] — it now refuses.
- [x] [Review][Patch] Inaccurate claims: "instance data cannot move a key", "four liveness tests" [structural-walk.mjs:23, a11y spec:10].
- [x] [Review][Patch] The walk's toggle retyped the theme class and clicked any checkbox item [structural-walk.mjs:575] — it now imports `THEME_DARK_CLASS` and scopes to `.ocu-account-panel`.
- [x] [Review][Patch] Tautological not-built count assertion [a11y spec:66] — it now asserts the report line.
- [x] [Review][Patch] The sign-out test could race the fire-and-forget write [theme.browser-spec.mjs:190] — it now waits for the row.
- [x] [Review][Patch] `PreferencesWire`: the stale "three refusals" doc and an unasserted status [src/OcuPilot/Test/PreferencesWire.cls:393,398].
- [x] [Review][Patch] EXPERIENCE.md: `:438` should be `:439`, and `:81` and `:439` still said "polish week" [EXPERIENCE.md:81,424,439].
- [x] [Review][Defer] Refuses only the live container [structural-walk.mjs:680] — DW-1015 occurrence.
- [x] [Review][Defer] No bound on the unmeasurable contrast count [structural-walk.mjs:420] — DW-1582 wontfix-accepted, with `reopen_if`.
- wontfix-theoretical: the walk does not confirm the rendered screen after `pushState`; routes are eager and `_SYSTEM` passes every gate. Real if a CI log shows a key filed under a route that did not render.
- wontfix-theoretical: the dark liveness case uses a stand-in tracker. Real if the light pass renders dark in CI.
- wontfix-theoretical: `visible()` skips controls of 1px or less. Real if a visible control renders at 1px or less.

Rejected:

- by-design (the spec's own definitions):
  - form-field text is not contrast-measured;
  - large text is weight 600;
  - overflow is horizontal only;
  - the resize handle and chrome recur per route;
  - `MARGINAL_GUARDED[2]`;
  - `needsId`;
  - `compare` ignores `count`;
  - the content pane scrolls by design (DESIGN.md's content floor);
  - `Error.cls` is shared-append at its tail.
- false: CI reproduced `-at-stop` and the two data-table link keys.
- low:
  - the `goInApp` throw fails loudly;
  - a toggle before the read settles (earlier triage);
  - the `EXPERIENCE.md:424` citation moves at the Epic 7 merge and `strings.test` catches it;
  - `sessionStorage` is checked as a subset, which matches "nothing but the pair", and importing the constant would run another spec;
  - the Rule 19 cases the earlier triage already covered;
  - mutation lines per assertion (Rule 19 asks for one per AC).
- not code: the lead files one ledger item per baseline entry (owner's ruling). All 191 have `dw: null`.

## Spec Change Log

- 2026-09-24, integrate forward (lead): one-time baseline extension forced by the merge order (orchestrator ruling). Epic 7 merged after this baseline was taken, so its three security/auditing screens' 11 violations were appended from the gate's own print (6 on DW-1583, 5 on DW-1584); 202 entries. The ratchet runs from here.
- 2026-09-23, lead spec gate: (1) the merge path appends printed entries and never re-runs `--write`; (2) a dark-only contrast failure whose fix is not a footprint token substitution HALTs as an intent gap; (3) the AC5 stale-report mutation corrected to a synthetic entry with no defect behind it; (4) a determinism check added before the baseline is committed. No intent change.

## Review Triage Log

### 2026-09-23 — Review pass

- verdicts: 24 findings — high 0, medium 7, low 14, false 2, maybe-false 1
- findings:
  - `[medium]` `[patch]` Toast link consumer never checked, only the root token (VG) — `theme.browser-spec.mjs` AC4 reads `.ocu-toast-action`'s computed color off its own scoped rule in both themes; mutation recorded.
  - `[medium]` `[patch]` Server-flag dark edge not verified as rendered (VG) — AC3 case reads a planted `.ocu-server-flag`'s border in both themes against `on-shell-dark` at 20%; mutation recorded.
  - `[low]` `[patch]` Pointer activation focus assertion pre-focused (VG) — toggle case now opens with focus on About, dispatches mousedown then click; mutation recorded.
  - `[low]` `[patch]` n-item planted-item case removed (VG) — planted fifth-item case restored; mutation recorded.
  - `[medium]` `[patch]` Token-sized minimum widths unpinned (VG) — `structural-baseline.test.mjs` asserts `componentMinimums()` finds `ocu-panel-send` and an icon-button class; mutation recorded.
  - `[medium]` `[patch]` Unsettled visits do not fail the gate (VG) — walked-or-skipped case asserts `unsettled` empty; mutation recorded.
  - `[false]` `[reject]` Gate stale test asserts nothing (VG R19) — stale-never-fails is the spec's decision; `compare`/`staleInstruction` are pinned in `structural-baseline.test.mjs` and the synthetic-stale mutation was observed.
  - `[low]` `[reject]` `theme.test.mjs` unsettled-read seed is decorative (VG R19) — the `loaded()` guard is pinned by "dark is adopted once"; a cosmetic seed.
  - `[low]` `[reject]` "adopted once" cannot catch removal of the `adopted` guard (VG R19) — the refused-write test pins it (re-adoption would flip back to light).
  - `[low]` `[reject]` Sign-in test's dark seed unobservable (VG R19) — the row it asserts (no class, light scene) holds; the seed only documents the case.
  - `[low]` `[patch]` Pointer-focus assertion vacuous (VG R19) — same root cause as the pointer-focus row; fixed there.
  - `[medium]` `[patch]` Contrast detector never observed red in dark (VG R19) — liveness case plants #222 on the dark ground, reported in dark and not in light.
  - `[low]` `[patch]` AC6 has no mutation line (VG) — DW-1388 record mutation applied and recorded.
  - `[low]` `[patch]` AC4 mutations missing for dark-only check, caption remedy, toast consumer (VG) — each applied and recorded.
  - `[low]` `[patch]` AC2 menu half has no mutation line (VG) — `aria-checked` mutation applied and recorded.
  - `[medium]` `[patch]` Baseline test forbids the `dw` the lead fills (VG other) — accepts `null` or `DW-<n>`.
  - `[medium]` `[patch]` Dark completeness proven on source text, not rendered surfaces (IA) — same root cause as the toast-consumer and server-flag rows; the two component-level remedies are now read as rendered.
  - `[low]` `[reject]` Structural invariants run in light only, keys carry no theme (IA) — the dark scope changes color properties and `color-scheme` only; the spec's Viewports note fixes contrast-only in dark.
  - `[false]` `[reject]` Baseline holds no name or contrast entry, 368 unmeasurable (IA) — both arms observed red (liveness plants in both themes, the `aria-label` mutation); unmeasurable is reported as the spec requires.
  - `[maybe-false]` `[defer]` Baseline recorded on local Chrome may not reproduce in CI's browser job (IA) — settled by the first CI `browser` run on this commit.
  - `[low]` `[reject]` Screen list from the working tree, bundle deployed separately (IA) — CI builds and deploys from one commit; locally the redeploy is the documented step.
  - `[low]` `[reject]` `ocu-theme-dark` literal in `structural-walk.mjs` and `design-tokens.mjs` (IA) — outside `ui/src`; a rename fails the walk loudly.
  - `[low]` `[reject]` Theme refusal display tested only below the page (IA) — the `fault()` surfaces are 15.5's and tested there; `theme.test.mjs` pins the path into `fault()`.
  - `[low]` `[reject]` A toggle while the sign-in read is pending can be overridden by adoption (IA, inference) — needs a toggle inside the read's latency; the fix adds a branch.

## Design Notes

**Governing ADs (Rule 6).** AD-50 (one `Kind`-discriminated store; the theme is a `shell` member and never browser storage), AD-49 (self-service write; no proposal), AD-19 (framework-free `core/`), AD-28 and AD-47 (the browser holds only the per-tab token pair), AD-5 (the registry is the single source; the walk reads `builtScreens()`), AD-12 and AD-39 (a published `reason` for the new code), AD-9 (`Kernel/State/Base` guarded save). Conventions rows: *Angular naming* (design tokens only), *Client asset homes*, *Concurrent writes*, *Error shape*, *Tests*.

**The owner's ruling on DW-1337 (2026-09-21), verbatim:**

> ADD THE GATE: registry-driven over every screen the registry declares, asserting the three invariants — an accessible name on every input/select/textarea, no interactive control narrower than its declared minimum, no element overflowing its container. Routed into Story 15.6, on the SHARED WALK with the contrast guard, which is what makes it cheap: one traversal of every declared screen serves both. BOUND: the gate runs in BASELINE form. The baseline is taken ONCE from the current tree; each baseline entry becomes its own ledger item routed to the epic that owns that screen or to range-end-cleanup; and the gate fails CI on any violation OUTSIDE the baseline. So it is a ratchet — it cannot regress, and it does not demand the backlog be cleared first. 15.6 FIXES NOTHING THE GATE FINDS unless the fix is a token in its own footprint. If 15.6 overruns its dispatch window, Epic 12 waits for it and that delay is accepted by the owner.

**Why the flip re-points bare roles.** Every one of the 64 twins already exists and is pinned against DESIGN.md (`design-tokens.test.mjs:119`). No dark value is missing, so none is derived. The only gap was the scope. `:root.ocu-theme-dark { --ocu-X: var(--ocu-X-dark) }` has no cycle, because every `-dark` side is a literal. After the flip, the chrome rules that draw a `-dark` token in both modes are still correct. Two rules could not follow the flip, and each becomes a non-role token pair taken from a DESIGN.md component key:

- the toast link, whose variant is reversed between modes (DESIGN.md:501-502);
- the server flag's dark-only edge (DESIGN.md:313).

This removes the last component-level dark selector.

**First paint and sign-in.** The preference belongs to a user, and the preferences endpoint requires authentication. So the sign-in screen and the shell render light until the read settles, and a dark user sees one light frame. The alternative, caching in browser storage, is exactly what AD-50 and 15.5's AC2 forbid. `endSession()` returns to light before the next user's read.

**The gate.**

- **Screens.** They come from `builtScreens()` (`navigation.ts:108`, imported at run time as `gate.browser-spec.mjs:53` does), so a screen Epic 7 adds is walked at the merge. Declared screens with `built: false` are counted as not built; they have no route. Every built screen is walked at its base route. Form-pages open as Create, and OAuth tabs and lists open without an id.
- **Screens that need an id.** A screen needs an id when it declares `parentScope` (AD-5 sub-resource: six today) or has the one-object archetype `viewer (OpenAPI)`. Each is walked at `<route>/<id>`. The id is taken from the first rendered row of its parent screen, or for the viewer from the `/api/ocupilot` precedent (`rest-apis.browser-spec.mjs:121`). Otherwise the screen goes in an explicit `SKIP` map with a reason. An id-requiring screen in neither place fails the gate.
- **Navigating.** After sign-in the walk navigates inside the app (router navigation without a new document). Without that, `shell-entry.mjs:16-19`'s first-login gate returns.
- **When a screen is settled.** No `/api/ocupilot` request is in flight for 500 ms, no `[aria-busy="true"]` remains, `document.fonts.ready` has resolved, and reduced motion is emulated.
- **Viewports.** No minimum supported width is declared anywhere. The declared floors are 1280px, the full-shell row at EXPERIENCE.md:725, and 720px, the 200%-zoom viewport at DESIGN.md:912. 720px also exercises the under-900 squeeze rule at EXPERIENCE.md:727. Structural invariants run at both widths in light. Contrast runs at 1280 in light and in dark. The dark pass switches through the real account-menu toggle once and switches back at the end.
- **Invariant `name`.** Every visible `input:not([type=hidden])`, `select` and `textarea` has a non-empty accessible name as Chrome computes it (CDP `Accessibility.getPartialAXTree`). The walk does not use its own heuristic.
- **Invariant `min-width`.** Every visible interactive control (`button`, `a[href]`, form fields, `[role=button|link|menuitem|menuitemcheckbox|tab|checkbox|switch]`, `[tabindex]:not([tabindex="-1"])`) has a bounding-box width at least its declared minimum. The sources (lead item 5):
  - the 24 CSS px floor for every control (EXPERIENCE.md:713; no token exists);
  - `.ocu-rail-item` 48 (DESIGN.md:243 `rail-item.size`);
  - the row-overflow trigger 28 (EXPERIENCE.md:713);
  - controls sized by `--ocu-icon-button-size` or `--ocu-panel-send-width`, read from the token at run time (`_metrics.scss:64`, `:43`);
  - the panel resize handle 8 (DESIGN.md:1140, its declared hit area).
  
  The table in `structural-walk.mjs` cites each source. No figure is invented.
- **Invariant `overflow`.** Two parts:
  - The document never scrolls horizontally (DESIGN.md yield order: "the page body never scrolls horizontally"). When it does, the entry is keyed on the outermost element whose right edge passes the viewport.
  - An element overflows when its border box passes its containing block's padding box by more than 1px and no ancestor up to that block clips or scrolls horizontally (`overflow-x` other than `visible`). `position: fixed` elements are skipped.
- **Contrast.** Each visible, active element that directly holds text is measured against its composited background, walking up to the first opaque ancestor background. The floor is 4.5:1, or 3:1 at 24px, or 18.66px at weight 600 or more. Inactive controls (`disabled`, `aria-disabled`) are exempt (WCAG). An element whose background passes through a `background-image`, such as the header gradient, is counted as *unmeasurable*, reported, and never passed silently. A contrast failure that occurs only in dark is this story's own defect (AC4), so it is never baselined; `structural-baseline.test.mjs` checks this. If its fix is a token substitution in the footprint, make it. If the fix would change a DESIGN.md-declared value, or edit a rule outside the token-substitution charter, HALT `blocked` with `intent gap` naming the pair, the measured ratio and the recommended value: the lead amends DESIGN.md (Rule 5) and re-dispatches. Never baseline it, never edit outside the footprint. (lead edit at spec gate)
- **Key.** `<route>|<invariant>|<context>|<element>`. `context` is the viewport for `min-width` and `overflow`, the theme for `contrast`, and empty for `name`. `element` is the nearest `app-*` ancestor tag, then the element's tag, sorted `ocu-*` classes and role. It carries no index and no text, so row counts and instance data cannot change a key, and identical keys on one screen collapse into one entry with a `count`.
- **Baseline file.** `{generated, viewports, entries: [{key, route, invariant, context, element, count, measured, tag, dw}], ownerReported: [...]}`. The comparison reads `key` only. `dw` is left `null` for the lead, who files one ledger item per entry and cites its key. `ownerReported` records:
  - **DW-1335** — not an invariant violation. It is labeled "Filter rows", is 220px wide and does not overflow (ledger measurement). The walk does not find it; it stays routed to 16-15.
  - **DW-1336** — resolved by 5.14. The expected evidence is that the walk finds no composer `min-width` or `overflow` entry at 1280, and the entry states what the walk found.
  - **DW-1388** — the entry for the agent panel (`app-panel`) at 720, marked diagnosed and not Home.
- **Stale entries** are printed with a removal instruction and never fail the gate (lead decision), so an epic that fixes a screen does not turn feature CI red.
- **At a merge.** A screen a concurrent epic adds surfaces its violations as fresh entries and the gate fails. The gate's failure output prints each fresh violation as a ready-to-append baseline entry (same JSON shape as the file). The merger fixes it, or appends exactly those printed entries, each of which then gets its own ledger item. `--write` takes the baseline once, in this story, and is never re-run afterwards: a whole-file regenerate would silently absorb every regression since the take, which is the one thing a ratchet exists to prevent. (lead edit at spec gate)

**Ledger inbox (Rule 17).** DW-39 and DW-118: the dark-scope re-point task and AC1. DW-1337: the gate tasks and AC5. DW-1388: AC6, as a diagnosed baseline entry. None is declined.

**Footprint (Rule 11).**

- **Exclusive:** `_tokens.scss`, `_theme.scss` (`_typography.scss` and `_metrics.scss` untouched), `shell/account-menu.ts` and `.spec.ts`.
- **Shared-append:** `_components.scss` (token substitution at `:1915-1921` only), `core/strings.ts`, EXPERIENCE.md's Fixed strings row, `Api/Error.cls`.
- **New files, this story's:** `core/theme.ts`, `tools/theme.test.mjs`, `tools/structural-baseline.test.mjs`, `browser/structural-walk.mjs`, `browser/structural-baseline.json`, `browser/a11y-structural-invariants.browser-spec.mjs`, `browser/theme.browser-spec.mjs`.
- **`footprint_extensions:`** No contended epic has modified any of these (checked against `git diff --name-only $(git merge-base HEAD origin/OCU-1-epic7) origin/OCU-1-epic7` at `7c2c4a04`): `shell/toast-host.ts`, `core/account-preferences.ts`, `main.ts`, `app.ts`, `Kernel/State/Pref.cls`, `Api/Preferences.cls`, `Test/PrefState.cls`, `Test/PreferencesWire.cls`, `tools/design-tokens.mjs` and `.test.mjs`, `tools/build-output.test.mjs`, `tools/account-preferences.test.mjs`.
- **Epic 7's, read-only:** `screens.generated.ts` (imported only), `panel.ts`.
- **Epic 7's, pre-authorized conditional:** `ui/angular.json` and `tools/angular-json.test.mjs` (DW-1166).

**Consumes:** 15.5's `AccountPreferences` (`shell()`, `setValue`, `loaded()`, `fault()`); `Kernel/State/Base`'s guarded save; `navigation.ts` `builtScreens()` and `screens.generated.ts`; `panel-spec.mjs` `signedInAt`; `preferences-reset.mjs`; `shell-entry.mjs`.

**Consumed-by:**

- **15.7** — the rail icons take their state colors through `currentColor` in both themes, and the gate walks the rail in both themes.
- **15.8** — the column work is held by the gate's `overflow` invariant ("the page body never scrolls sideways").
- **Every later screen** in Epics 7, 9, 11, 12 and 16 is walked by the gate at its merge.

**Spine `## Deferred` row "Theme toggle wiring", for the lead to rewrite.** The premise "the toggle is a flag flip" was false until this story. Both token sets existed, but the dark scope re-pointed only the 30 `--mat-sys-*` roles while components read the bare `--ocu-*` roles (DW-39, DW-118). Suggested row: *Theme toggle wiring (DW-39, DW-118, **decided**) — Story 15.6: the dark scope re-points all 64 roles plus the non-role pairs. The choice is the `shell` kind's `theme` member on AD-50's store. The toggle is now a flag flip over complete token sets. | Done.*

## Verification

**Slot B.** Every IRIS MCP call carries `server: "ocupilot-slot-b"`; the development container is `ocupilot-slot-b`, and it is compile-only. Wire tests and browser specs run on the throwaway: `bash scripts/ci-throwaway.sh up --dir /tmp/ocupilot-b-ci --project ocupilot-b-ci --web 52777 --super 1976`. It is torn down only by whoever ran its `up`. Every browser run exports `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777` and `OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci`, and runs after `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`. Stateful test classes run one per tool call.

**Targeted, marked `(loop)`:**

- `(loop)` `cd ui && npm run test:tools` — green, including `design-tokens`, `build-output`, `theme`, `account-preferences`, `structural-baseline`, `strings` and `browser-reset`.
- `(loop)` `cd ui && npm run test:components` — green, including `account-menu.spec.ts`.
- `(loop)` `cd ui && npm run build` — the seven `prebuild` checkers pass, `screen-mirror.mjs --check` passes with no regeneration, and the bundle-size line is quoted.
- `(loop)` `uv run scripts/check-objectscript.py` — green. Quote the output before any commit that touches `Api/Error.cls`.
- `(loop)` Compile through MCP on `ocupilot-slot-b`, then run `OcuPilot.Test.PrefState` and then `OcuPilot.Test.PreferencesWire`, one per call, on the throwaway.
- `(loop)` `cd ui && node --test --test-concurrency=1 browser/theme.browser-spec.mjs browser/a11y-structural-invariants.browser-spec.mjs`.
- `(loop)` `bash scripts/lint-docs.sh` — green over the EXPERIENCE.md row.
- **Once, to take the baseline:** on a freshly started throwaway (`down` and then `up`, both run by this stage), run `cd ui && node browser/structural-walk.mjs --write`. Commit the output as generated. Then fill in the `ownerReported` findings and quote the walked, skipped, not-built and unmeasurable counts. **Determinism check before committing it:** run `a11y-structural-invariants.browser-spec.mjs` twice more against that same throwaway without restarting it; both runs must be green with zero fresh and zero stale keys. A key set that differs between runs is a settle or key-stability defect in the walk, fixed before the baseline is committed (DW-1447 measured this suite non-idempotent once already). (lead edit at spec gate)

**Full, `(once, before dev_complete)`:**

- `(once)` The full ObjectScript sweep over `OcuPilot.Test.*`, one class per call.
- `(once)` `bash scripts/smoke.sh --container ocupilot-slot-b --user _SYSTEM --password SYS` — more than zero checks executed, and all pass.
- **The full browser suite is not run locally** (Rule 29). CI's `browser` job runs it on a fresh throwaway and discovers both new specs through the `browser/*.browser-spec.mjs` glob (`package.json:18`), with no roster edit (Rule 8).

**Mutations (Rule 19), each to be applied, observed red, reverted, with the tree confirmed byte-identical and the bundle rebuilt and redeployed for any browser read):**

- AC1: delete one role's re-point from the dark scope → the `design-tokens.test.mjs` scope-completeness test goes red. Re-add a `:root.ocu-theme-dark .ocu-server-flag` rule → the single-home test goes red.
- AC2 and the theme Integration AC: `ThemeState` ignores the adopted value → `theme.browser-spec.mjs`'s new-context case goes red.
- AC3: `.ocu-rail-item:focus-visible` reads `--ocu-focus-ring` → the chrome case goes red in light.
- AC4: set `--ocu-toast-link-dark` to `secondary-dark`'s hex → the toast-link case goes red.
- AC5 and the gate Integration AC: remove `aria-label` from `.ocu-command-bar-filter`'s source (a temporary, reverted mutation — the file is Epic 7's) → the gate goes red naming the new key. Delete one real baseline entry → the gate goes red naming that key as fresh (the ratchet holds). Add a synthetic baseline entry whose defect does not exist (the "underlying defect removed" case) → the gate prints it as stale with its removal instruction and stays green. (lead edit at spec gate: the stale case needs an entry with no defect behind it, not a deleted entry)
- Server: drop the new `ReasonForViolation` arm → `PreferencesWire`'s sentence case goes red.

**Recorded at implement (2026-09-23, fresh `ocupilot-b-ci`).** Baseline taken once by `--write`: 47 declared, 46 walked, 0 skipped, 1 not built (`security/auditing`), 0 id-requiring unresolved, 368 text elements unmeasurable, 0 unsettled; 190 entries (overflow 46 at 1280 and 124 at 720, min-width 10 at each width, no name and no contrast entry in either theme). Determinism: two further gate runs on the same throwaway, each 0 fresh and 0 stale. Bundle: initial total 1,256,616 B (main 1,123,760 + styles 132,856), under `maximumWarning` 1261kB, so DW-1166 was not applied.

**Mutations observed (implement stage; each reverted, tree byte-identical, bundle rebuilt and redeployed after each browser one):**

- mutation: deleted `--ocu-shell: var(--ocu-shell-dark)` from the dark scope → `design-tokens.test.mjs` "the dark scope re-points every role…" red ("--ocu-shell … found 0") (AC1).
- mutation: appended a `:root.ocu-theme-dark .ocu-server-flag` rule to `_components.scss` → `design-tokens.test.mjs` "ocu-theme-dark is named under ui/src only…" red naming `styles/_components.scss` (AC1).
- mutation: `ThemeState.adoptRemembered` always adopts light → `theme.browser-spec.mjs` "AC2 and the theme Integration AC…" red (timeout waiting for the class in the new context) (AC2, theme IA).
- mutation: `.ocu-rail-item:focus-visible` outline reads `--ocu-focus-ring` → `theme.browser-spec.mjs` "AC3…" red in light (`focusRing` rgb(18, 69, 111) vs rgb(156, 197, 234)) (AC3).
- mutation: `--ocu-toast-link-dark: #6fd3dc` → `theme.browser-spec.mjs` "AC4…" red (`#6fd3dc` vs `#0b7080`) and `design-tokens.test.mjs` toast-link pin red (AC4).
- mutation: removed `[attr.aria-label]` from `command-bar.ts`'s filter (temporary) → gate "no violation outside the baseline" red naming `…|name||app-command-bar>input.ocu-command-bar-filter` on every list route (AC5, gate IA).
- mutation: deleted the baseline entry `/|overflow|720|app-status-bar>span.ocu-status-bar-connection[role=status]` → gate red naming that key as fresh; in the same run a synthetic `system/about|min-width|1280|app-probe>button.ocu-probe-synthetic` entry was printed as stale with its removal instruction and the stale test stayed green (AC5).
- mutation: `urlFor` resolves no parent-scoped id → gate "every built screen is walked or skipped…" red naming the six `parentScope` screens (AC5, matrix row 10).
- mutation: dropped the `PREFERENCESCHOICE` arm from `ReasonForViolation` (loaded into `ocupilot-b-ci`) → `PreferencesWire.TestTheValueRefusalsCarryTheirPublishedSentences` red on case 5's non-empty reason (server).
- mutation: `[attr.aria-checked]` fixed to `false` → `account-menu.spec.ts` "the Dark theme item says whether the dark theme is on screen" red (AC2, menu half).
- mutation: deleted `item.focus()` from `toggleTheme` → `account-menu.spec.ts` "activating Dark theme … keeps the menu open on the item" red, under a pointer activation (AC2).
- mutation: `menuButtons()` sliced to four → `account-menu.spec.ts` planted-fifth-item case red.
- mutation: `.ocu-toast-action` back to `var(--ocu-secondary-dark)` → `theme.browser-spec.mjs` AC4 red ("dark: the toast host's action link draws it") (AC4, consumer).
- mutation: `.ocu-server-flag` border back to `transparent` → `theme.browser-spec.mjs` AC3 red ("dark: the server-flag pill draws on-shell-dark at 20%") (AC1/AC3 edge).
- mutation: the keyboard-active caption remedy reads `--ocu-restrained` → `theme.browser-spec.mjs` AC4 red ("the remedy for the 4.497:1 dark pair is what renders") (AC4).
- mutation: added a `contrast|dark` baseline entry with no light twin → `structural-baseline.test.mjs` "AC4: every dark contrast entry has a light twin" red (AC4).
- mutation: deleted the DW-1388 `ownerReported` record → `structural-baseline.test.mjs` "every owner-reported finding is recorded" red (AC6).
- mutation: dropped `panel-send-width` from `MIN_WIDTH_SOURCES.tokens` → `structural-baseline.test.mjs` "the token-sized minimum widths are found" red (AC5).
- mutation: `settle` reports a settled visit as unsettled → gate "every built screen is walked or skipped…" red ("every visit settled before it was measured") (AC5).
- mutation: `menuButtons()` kept, test reverted to the three-item walk → `change-password.browser-spec.mjs` AC7 red ('Dark theme' vs 'Sign out'), as in CI 35934116068 (review).
- mutation: the Story 15.6 `body` ground rule emptied → `theme.browser-spec.mjs` AC3 red (`ground` rgba(0, 0, 0, 0) vs rgb(250, 251, 252)) (DW-1581, review).
- mutation (four applied together, each reddening only its own test): the name check reads only `''` → "a field left out of the accessibility tree" red; the page branch compares `<` → "a document that scrolls horizontally" red; `tokenPx` reads `--ocu-x-<token>` → the min-width liveness red on `ocu-reveal-toggle`; `reportLines` prints 0 not built → "every built screen is walked or skipped" red (AC5, review).

## Auto Run Result

Status: done
Blocking condition: none

**Change.** The dark scope re-points all 64 roles plus the non-role pairs with a dark side (`elevation-1..3`, new `toast-link`, new `server-flag-edge`); the last component-level dark selector is gone. `core/theme.ts` (`ThemeState`) sets the one root class from the `shell.theme` member, wired in `main.ts`/`app.ts` and toggled by a "Dark theme" `menuitemcheckbox` in the account menu. Server: `Pref.cls` `SHELLTHEME`/`IsThemeValue`, `Preferences.cls` refuses other values with 422 `PREFERENCES.CHOICE`, `Error.cls` appends the code, sentence and `ReasonForViolation` arm. DW-1337 gate: `structural-walk.mjs`, `structural-baseline.json`, `a11y-structural-invariants.browser-spec.mjs`.

**Files.** Theme: `_tokens.scss`, `_theme.scss`, `_components.scss` (token substitution at `.ocu-server-flag`, dark rule deleted), `toast-host.ts` (token substitution), `core/theme.ts` (new), `core/account-preferences.ts`, `main.ts`, `app.ts`, `shell/account-menu.ts`, `core/strings.ts`, EXPERIENCE.md row `:424`. Server: `Kernel/State/Pref.cls`, `Api/Preferences.cls`, `Api/Error.cls`, `Test/PrefState.cls`, `Test/PreferencesWire.cls`. Tests: `design-tokens.mjs`/`.test.mjs`, `build-output.test.mjs`, `account-preferences.test.mjs`, `theme.test.mjs` (new), `structural-baseline.test.mjs` (new), `browser-reset.test.mjs` (exempt list), `account-menu.spec.ts`, and one `ThemeState` provider line each in `app.spec.ts`, `app.wire.spec.ts`, `app.gate-outlet.wire.spec.ts`, `status-bar.spec.ts`; browser: `theme.browser-spec.mjs`, the gate spec, the walk helper and baseline (new).

**footprint_extensions** (none on Epic 7's list at `7c2c4a04`): the spec's list, plus `app.spec.ts`, `app.wire.spec.ts`, `app.gate-outlet.wire.spec.ts`, `status-bar.spec.ts`, `browser-reset.test.mjs`.

**Review.** 24 findings (verification-gap and intent-alignment; blind-hunter and edge-case-hunter are not enabled here): patched 7 medium and 7 low (toast consumer and server-flag edge read as rendered, pointer-focus and planted-fifth-item cases, token-minimum roster, unsettled visits fail the gate, dark-contrast liveness, `dw` accepts a ledger id, missing mutation lines); 2 deferred to frontmatter (CI reproducibility of the baseline, maybe-false medium; page ground paints no surface role, low, pre-existing); 8 low and 2 false rejected with reasons in the triage log. Follow-up review recommended: **true** (7 medium patched) — the named unverified risk is whether the 190 baseline keys reproduce in CI's `browser` job.

**Verification.**

- Baseline: 190 entries (overflow 46 at 1280 and 124 at 720, min-width 10 at each; no name or contrast entry in either theme); 47 declared, 46 walked, 0 skipped, 1 not built (`security/auditing`), 368 unmeasurable, 0 unsettled. No dark-only contrast failure, so no Rule 5 halt. Determinism: 0 fresh / 0 stale on the two runs after the take and on three later gate runs on the same throwaway.
- Bundle: initial 1,256,616 B, under `maximumWarning` 1261kB; DW-1166 not applied.
- `npm run test:tools` 1353/1353 after patching; `npm run test:components` 931/931; `npm run build` prebuild checkers clean; `check-objectscript.py` 0 problems; `lint-docs.sh` 0 issues.
- Throwaway `ocupilot-b-ci`: `PrefState` 17/17, `PreferencesWire` 10/10; `theme.browser-spec.mjs` + gate spec 13/13 after patches; smoke 47/47.
- Full ObjectScript sweep, once, on `ocupilot-slot-b` after compiling all 696 classes (`ci-runner.mjs`, one class at a time): 206 classes, 1360 tests, 1312 passed, 48 failed — SQL over `%UnitTest_Result` (latest run per class, runs ≥ 452) agrees: 1360 / 1312 / 48. Failures are environmental: `EndpointCoverage` (static 503, known), `AgentConnection`, `AgentCredential`, `AgentViolation`, `AgentWire` (slot B answers `INSTALL.UNREADABLE`) and `TaskHistory` (demo task runs absent); all five non-known classes re-run green on the freshly installed throwaway (71/71). Slot-B smoke 45/47, failing only `shell`/`deeplink` (no bundle on slot B).
- Every mutation listed under `## Verification` was applied, observed red and reverted; tree byte-identical after each.

**Throwaway.** `ocupilot-b-ci` was brought up (down, then up for the baseline take) by this stage's handoff subagent and torn down by this stage before return.

**Residual risks.** 92 of the 190 baseline entries are the panel resize handle's declared 4px straddle (`left: -4px`) and 77 are status-bar segments at 720 px, so the lead's one-ledger-item-per-entry harvest carries heavy duplication. The gate now fails on an unsettled visit (20 s budget), which a slow CI instance could trip. EXPERIENCE.md `:81` still says the theme toggle arrives "in polish week".
