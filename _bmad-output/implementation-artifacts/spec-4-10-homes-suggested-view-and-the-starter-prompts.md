---
title: 'Story 4.10 - Home''s suggested view and the starter prompts'
type: 'feature'
created: '2026-09-18'
status: 'done'
review_loop_iteration: 0
baseline_revision: '78ae4a84e475b4f9269e7a9ae4e283f724210a77'
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
warnings: ['oversized']
owned_ledger: ['DW-160', 'DW-269', 'DW-379']
deferred:
  - summary: >-
      The block's all-zero fallback also fires when the counted read was refused or faulted, so a
      caller who simply may not read the error log is shown "nothing needs attention".
    evidence: |-
      `showPrompts()` tests `every(line => !line.counted || line.count === 0)` over the lines that
      are PRESENT, and a refused or faulted source is absent, so the test is vacuously true. Task 4
      specifies exactly that wording; the I/O matrix keeps the 403 row and the zero-rows row
      separate and settles neither against the other. Whether "unknown" may present as "zero" is a
      product call, not a code call.
    location: >-
      ui/src/app/core/suggested-view.ts, showPrompts()
    severity: medium
  - summary: >-
      DESIGN.md's Home row at 1,920 px (side bar 240, content 672) is unreachable on the ordinary
      arrival at Home, because Home declares no screen list.
    evidence: |-
      `areaHasSideBar('home')` is false, so `sideBarPreferred()` is false and the real content
      column at 1,920 is 912, not 672. The published triple is reachable only when the bar is
      already open on another area's list, since `sideBarPreferred()` reads `visibleArea()` while
      the Home target reads `activeArea()`. Pre-existing: this story is the first consumer of that
      row. Either DESIGN.md's Home row or Home's side-bar declaration is wrong.
    location: >-
      DESIGN.md Home viewport table, against ui/src/app/core/panel-layout.ts areaHasSideBar
    severity: low
  - summary: >-
      `ERROR_LOG_DATES_PATH` duplicates `areas/logs/error-log.store.ts`'s `ERROR_LOG_PATH_PREFIX`
      with no test pinning the two equal.
    evidence: |-
      A path change updates one and leaves the other answering 404, which this block renders as
      "no line" -- the same shape as a refusal, so it fails silently. A shared constant would have
      `core/` import from `areas/`, a dependency direction `core/` does not take, so the clean fix
      is to move the prefix into `core/` and re-point the drill store.
    location: >-
      ui/src/app/core/suggested-view.ts:35 and ui/src/app/areas/logs/error-log.store.ts:59
    severity: low
  - summary: >-
      The agent-status line re-implements the panel's own kill-switch / read-only sentence
      precedence, and no test pins the two equal.
    evidence: |-
      `SuggestedView.agentStatusLine()` selects the kill-switch banner sentence or
      `stringFor(footerKey)`; `panel.ts`'s `killSwitchMessage` and `readOnlyLine` select the same
      two independently. The spec's rationale ("the line can never disagree with the banner")
      depends on the two staying in step, and a precedence change in either diverges them. The
      browser leg compares them only while the kill switch is off, the one state where they agree.
    location: >-
      ui/src/app/core/suggested-view.ts agentStatusLine, against ui/src/app/shell/panel.ts
    severity: low
  - summary: >-
      `browser/suggested-view.browser-spec.mjs` re-implements `signedInAt`, `geometry` and
      `panelSettlesAt` from `browser/panel.browser-spec.mjs` instead of sharing them.
    evidence: |-
      About sixty copied lines, beside the tree's existing shared helper modules
      (`browser/shell-entry.mjs`, `browser/list-spec.mjs`). Lifting them is a refactor across two
      specs rather than a change to this story's diff.
    location: >-
      ui/browser/suggested-view.browser-spec.mjs
    severity: low
  - summary: >-
      A re-read parked on `retryWhenReachable` can fire after the tab has left Home, issuing one
      HTTP read nothing renders.
    evidence: |-
      `reset()` bumps the generation but cancels nothing parked, so a connection that recovers
      after the user navigated off Home settles the state the panel just reset, and the next Home
      entry reads again. One wasted request; nothing wrong is rendered, because the panel's own
      `onHome` conjunct hides the block. Canceling it needs an armed flag the store does not have.
    location: >-
      ui/src/app/core/suggested-view.ts readApplicationErrors
    severity: low
---

<intent-contract>

## Intent

**Problem:** Home opens with an empty transcript and a 400 px panel: the agent offers nothing before
the user has thought of a question, and DESIGN.md's wider Home panel, its 120 ms transition and the
`--ocu-panel-home` token have no runtime consumer (DW-160, DW-379).

**Approach:** A "Suggested view" block above the transcript on Home, built from a declared line table
so a later read joins by appending a source; an all-zero fallback and an empty-transcript greeting that
both place a prompt in the composer; and Home's panel width resolved inside `resolveLayout` so it
participates in the existing yield order and the existing 120 ms CSS width transition.

## Boundaries & Constraints

**Always:**

- Every user-visible literal comes from `core/strings.ts` and appears verbatim in EXPERIENCE.md's
  **Fixed strings** table (`strings.test.mjs:422`/`:446`; the key count is an exact equality).
- A line renders only when its read has answered **and** the caller may perform it. A read in flight,
  a fault and a 403 all render *no line* - never a zero, never a skeleton row, never a retry on 403
  (AD-8). The whole block renders nothing until every declared source has answered or settled.
- The block renders only on Home and only with an enabled definition (AC1's precondition;
  `AgentStatus.answered() && configured()`).
- Activating a line's text calls `PanelState.setDraft(text)` and focuses the composer. It never calls
  `TurnStore.send`. `Open` is a separate control that navigates.
- `resolveLayout` stays the one layout computation (AD-19); Home's width is an input to it, never a
  media query, never a second CSS path, never the Web Animations API.
- The remembered width is never overwritten by the Home target; leaving Home restores it.
- Stores are framework-free under `core/`, mirrored into the component by subscription (AD-19).
- Reads are bounded: one HTTP call per line per Home entry. No fan-out over namespaces or rows.

**Never:**

- No ObjectScript change. `Port/LogSourcePort.cls` and `Api/ErrorLog.cls` are outside Epic 4's
  `paths_hint` and inside Epic 6's, which neither depends on nor is depended on by Epic 4 - a
  contended path, so Rule 11 (c) forbids the judgment call.
- No `Screen/Registry.cls` `DECLARATIONKEYS` change and no new descriptor key: `Screen/Descriptor/**`
  is Epic 6's footprint, and the starter prompts are already published as client strings.
- No per-namespace fan-out of `/logs/errors/dates`, no browser-computed "today", no timer on the block
  (Home is not in AD-43's six-screen auto-refresh roster).
- No tasks-suspended line (declined; see Design Notes › DW-269).
- No `--ocu-panel-home` runtime CSS consumer: an inline `[style.width.px]` already wins, and CSS
  cannot see the side bar, so it cannot express the yield order.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Both lines answer, non-zero | `restraint` answered; `dates` returns rows | eyebrow + agent-status line + application-errors line, counts in `<code>` | none |
| Application-errors read in flight | `dates` not yet answered | no block at all (not a partial block, not prompts) | none |
| Application-errors read faults 5xx/unreachable | `classifyFault` → `server-fault`/`unreachable` | that line absent; block renders the rest; one parked re-read via `ConnectivityService.retryWhenReachable` keyed by the path | existing fault banner speaks for the instance |
| Application-errors read refused 403 | caller lacks `%Admin_Operate:USE` or `%DB_IRISSYS:READ` | that line absent for the session, never retried (AD-8) | no inline refusal in the panel |
| `dates` returns zero rows | clean log in this namespace | counted lines all zero → three starter prompts; agent-status line stays | none |
| Kill switch on | `restraint.killSwitch` true | agent-status line text is the kill-switch sentence | none |
| Caller is not an OcuPilot administrator | `agent/switches` verdict denied | the agent-status line's `Open` stays listed and focusable, `aria-disabled`, reason `formatRequires(privilegeRequiresResource, 'OcuPilotAdmin:USE')` | Privilege Gating, not removal |
| Namespace scope changes on Home | `ScopeService` notifies | the application-errors read re-issues for the new namespace; the line's text re-resolves | as above |
| Empty transcript, definition enabled | `TurnStore.entries()` empty and `restored()` | greeting, three prompt rows, selection hint, in that DOM order | none |
| Transcript not yet restored | `restored()` false | no greeting block (it must not flash before the conversation loads) | none |
| Unconfigured panel | `answered() && !configured()` | no suggested view, no greeting block; the existing empty state owns the transcript | none |
| Enter Home at 1,920 px, side bar open | remembered 400 | panel settles at 960, content 672, over the existing 120 ms width transition | none |
| Enter Home at 900 px | any remembered | panel 320 (`PANEL_MIN_WIDTH` floor), content scrolls | none |
| Drag or arrow the handle while on Home | user width gesture | the Home target is released for this visit, the drag lands where the pointer is, and the width is stored as the remembered width | none |
| Leave Home | `activeArea` ≠ `home` | panel returns to the remembered width over the same transition | none |
| `prefers-reduced-motion: reduce` | media query | width changes instantly (`--ocu-motion-panel-width-duration` is already `0ms` in that block) | none |

</intent-contract>

## Code Map

Client only. All paths absolute from the worktree root `/Users/jbrandt/git/OcuPilot/.worktrees/epic-4`.

- `ui/src/app/core/panel-layout.ts` -- `RAIL_WIDTH` 48 (`:21`), `SIDE_BAR_WIDTH` 240, `CONTENT_MIN_WIDTH` 640 (`:27`), `PANEL_MIN_WIDTH` 320, `PANEL_DEFAULT_WIDTH` 400, `PANEL_KEYBOARD_STEP` 16. `LayoutInput` (`:38`), `Layout` (`:50`), `resolveLayout` (`:66`, `target` at `:67`), `areaHasSideBar` (`:96`), `PanelState` (`:107`): `layout()` `:140`, `remembered()` `:151`, `setViewport` `:160`, `setDraft` `:173`, `beginDrag` `:231`, `dragTo` `:237`, `endDrag` `:243`, `resizeBy` `:251`, `applyWidth` `:256`, `sideBarPreferred` `:266`, `sideBarFitsUnaided` `:270`. Constructor already subscribes to `ShellState` and notifies (`:127`).
- `ui/src/app/core/shell-state.ts` -- `activeArea()` `:76` ("follows the router and nothing else"), `setActiveArea` `:159`, called from `ui/src/app/shell/screen-outlet.ts:236` on every route url change. This is how `PanelState` learns it is on Home; no router wiring is needed.
- `ui/src/app/app.ts` -- `<app-panel [style.width.px]="panelWidth" />` `:169`; `panelWidth` getter `:308-311` (null in full screen); `measureViewport()` `:316-319`. Unchanged by this story.
- `ui/src/styles/_metrics.scss` -- `--ocu-panel-home` `:39-43` (`min(50vw, calc(100vw - var(--ocu-rail-width) - var(--ocu-content-min-width)))`), `--ocu-panel-min`/`--ocu-panel-default` `:36-38`, `--ocu-control-height: 32px`, `--ocu-motion-panel-width-duration: 120ms` `:65-73`, `@media (prefers-reduced-motion: reduce)` zeroing every duration `:81-92`.
- `ui/src/styles/_components.scss` -- `app-panel { transition: width var(--ocu-motion-panel-width-duration) ease }` `:618`, drag override `:623`, full-screen override `:672`; `.ocu-panel-body` `:3145`, `.ocu-panel-chip-slot` `:3145-3169` (the `:empty { display: none }` precedent), `.ocu-panel-transcript` `:3171`, `.ocu-banner` flex row `:3193-3199`.
- `ui/src/app/shell/panel.ts` -- `COMPOSER_ID` `:30`; template `:100-274`; insertion point for the block is **between** `.ocu-panel-chip-slot` (closes `:177`) and `.ocu-panel-transcript` (opens `:179`); the greeting block goes inside the transcript's `@else` branch before the `@for` (`:179-225`). Reuse: `draft` getter `:454`, `onDraft` `:636`, `onEditDraft` `:631` (the `composerEl()?.nativeElement.focus()` pattern), `composerEl` viewChild `:286`, `unconfigured` `:368`, `reminder` `:379`, `killSwitch` `:389`, `killSwitchMessage`, `readOnlyLine`, `turns` `:516`, `openDefinitions` `:584-589` (the canonical real-`href`-intercepted-for-the-router handler), `bump()` `:750`. **Template lint:** every `@if` condition must be a paren-free member reference (`:92-95`; `ui/tools/client-lint.mjs`).
- `ui/src/app/core/agent-status.ts` -- `Restraint` `:68-77` (`blocked`, `code`, `reason`, `footerKey`, `killSwitch`, `killSwitchAudience`, `killSwitchReason`, `enforcedReadOnly`), `FOOTER_KEYS` `:88-92`, `answered()` `:281`, `configured()` `:286`, `restraint()`, `subscribe()`, `read()` `:330` (keeps the previous answer on failure, parks `retryWhenReachable` `:352`), `AGENT_RESTRAINT_PATH` `:44` (ungated by design; a verdict that cannot be read is a 500, never a permissive body).
- `ui/src/app/core/turn.ts` -- `entries()` `:419`, `restored()` `:413`, `subscribe()` `:402`. `send()` `:494` is **not** called by this story.
- `ui/src/app/core/scope.ts` -- `namespace()` `:201`, `namespaces()` `:187` (only namespaces the user can read *and* write, per EXPERIENCE.md `:364` "listing only namespaces the user can read and write"), `subscribe()` `:309`.
- `ui/src/app/core/fault.ts` -- `classifyFault` `:69` (403 → `refused`, never retried; `status === 0` → `unreachable`), `isBannerFault` `:102`. `ui/src/app/core/connectivity.ts` -- `retryWhenReachable(key, run)` `:250`.
- `ui/src/app/areas/logs/error-log.store.ts` -- `ERROR_LOG_PATH_PREFIX = '/api/ocupilot/logs/errors/'` `:59`; `ErrorLogDateRow` `:15` is `{date, count}`. `ErrorLogDrill` is a one-level-at-a-time drill store that clears rows before each read (`:272`) - **not reusable** for a one-shot count; this story reads the same path with its own small reader.
- `ui/src/app/core/navigation.ts` -- `SCREENS`/`areaByKey` `:90`, `screenForRoute` `:182`, `SCREEN_PLACEHOLDER` `:217`, `formatRequires` `:212`, `NavigationService` `:344` (the privilege map and `Verdict`/`failedPair`). `ui/src/app/areas/home/home.page.ts:231` is the existing `formatRequires` call site for a gated Home control, and `:74-79`/`:116-135` state the accessible-name convention (a text-bearing control's name is its own text).
- `ui/src/app/core/screens.generated.ts` -- generated, do not edit. Targets: `OcuPilot.Screen.Descriptor.LogErrorList` route `logs/errors`, labelKey `errorLogListLabel`; `OcuPilot.Screen.Descriptor.AgentSwitches` route `agent/switches`, labelKey `agentSwitchesLabel`, privileges `[{resource: OcuPilotAdmin, permission: USE}]`; `OcuPilot.Screen.Descriptor.Home` route `''`, area key `home`.
- `ui/src/app/core/strings.ts` -- flat `key: 'value',` one per line, `\uXXXX` escapes only. **Already declared and never rendered:** `agentIdleGreeting` `:166`, `agentIdleSelectionHint` `:168`, `homeStarterPromptExplainScreen`/`ExplainLog`/`ChangeOneThing` `:467-472`. Reused: `tableChangeToastLink: 'Open in <screen>'` `:214`, `privilegeRequiresResource`, the kill-switch and read-only keys the panel footer already selects.
- `ui/tools/strings.test.mjs` -- `extractFixedStringsTable` `:48-68` (anchor `**Fixed strings**`, header `| String | Where |`, literals are the double-quoted runs in column 1); `:422` every table literal exists as a value; `:446` the converse **and the exact key count**; `:395` literal count must stay in 150..260 (~246 today); `:569` voice rules; `:608` every `EXPERIENCE.md:<line>` comment resolves.
- `ui/tools/panel-layout.test.mjs` -- `layoutAt(viewport, overrides)` `:34` is the input builder every case uses; adding a required `LayoutInput` field is one edit there.
- `ui/tools/typography.test.mjs` -- `:330-335` already asserts `--ocu-panel-home` implements DESIGN.md's formula (shape only); `:347-349` asserts every duration inside the reduced-motion block is `0ms`.
- `ui/browser/panel.browser-spec.mjs` -- `signedInAt(url, viewport)` `:100`, `geometry(page)` `:118-147`, `panelSettlesAt(page, width)` `:149-156`, `enabledProbeDefinition()` `:75-95`, `removeProbeDefinitions()` `:64-73`, focus helper `const active = () => page.evaluate(...)` `:468-493`. Its yield-order case `:495+` runs at `USERS_URL`, a list route, so `homeTarget` is 0 there and its numbers are unaffected.
- `ui/browser/turnprobe-spec.mjs` -- `armProbeDefinition(options)` `:171` → `{prior, preparedId}`, `disarmProbeDefinition(options, prior)` `:179` (asserts its own `%Status`), `runIris` `:52`, `markerValue` `:67`.
- `ui/browser/data-table.browser-spec.mjs` -- `:120` is the only `prefers-reduced-motion` emulation in the tree (`page.emulateMediaFeatures([{name:'prefers-reduced-motion', value:'reduce'}])` on a fresh context page *before* `goto`); `:486`/`:540` are the `transitionProperty`/`transitionDuration` assertion pattern.
- `ui/angular.json` -- `budgets` `:51-57`, `maximumWarning: "780kB"`, `maximumError: "1MB"`; `ui/tools/build-output.test.mjs:168-201` sums the emitted `main-*.js` + `styles-*.css` at 1000 bytes/kB and has an unmeasured-file tripwire; `:397-403` asserts the reduced-motion block reaches the bundle. Last measured initial total 767.61 kB (`cycle-log-epic-4.md:258`) - about 12.4 kB of headroom.

## Tasks & Acceptance

**Execution:**

1. `ui/src/app/core/panel-layout.ts` -- add `export const HOME_PANEL_FRACTION = 0.5;` and
   `export function panelHomeTarget(viewport: number): number` returning
   `viewport > 0 ? Math.min(Math.floor(viewport * HOME_PANEL_FRACTION), viewport - RAIL_WIDTH - CONTENT_MIN_WIDTH) : 0`.
   Add a **required** `readonly homeTarget: number` to `LayoutInput` (`0` means "not on Home") and change
   `resolveLayout`'s `:67` to
   `const target = Math.max(PANEL_MIN_WIDTH, input.homeTarget > 0 ? input.homeTarget : input.remembered);`.
   Required, not optional: a silently-defaulting layout input is the class of bug this module exists to
   prevent, and the compiler then names every call site.
2. `ui/src/app/core/panel-layout.ts` -- `PanelState`: add `HOME_AREA_KEY` (import from `navigation.ts`,
   task 3) awareness via `private homeWidthReleased = false` and `private lastActiveArea = ''`; in the
   existing `shell.subscribe` handler (`:127`), reset `homeWidthReleased` when `shell.activeArea()`
   changes. Add `private homeTargetWidth(): number` returning `0` unless
   `this.shell.activeArea() === HOME_AREA_KEY && !this.homeWidthReleased`, else
   `panelHomeTarget(this.viewportWidth)`. Pass it from `layout()` (`:140`) and `sideBarFitsUnaided()`
   (`:270`). In `applyWidth` (`:256`), set `this.homeWidthReleased = true` **before** reading
   `this.layout()`, so a drag or an arrow step on Home takes effect and is stored as the remembered
   width. Rationale: with the Home target unconditional the resize handle would be dead on Home and its
   `aria-valuenow` would lie.
3. `ui/src/app/core/navigation.ts` -- add `export const HOME_AREA_KEY = 'home';` with a doc comment
   citing the descriptor. No other change.
4. `ui/src/app/core/suggested-view.ts` (new) -- framework-free store, no `@angular/core` import.
   Export `interface SuggestedLine { readonly key: string; readonly counted: boolean; readonly text: string;
   readonly count: number; readonly descriptor: string; }` and
   `class SuggestedView` with `subscribe(listener)`, `answered(): boolean`, `lines(): readonly SuggestedLine[]`,
   `starterPrompts(): readonly string[]`, `showPrompts(): boolean`, `load(): Promise<void>`, `reset(): void`.
   Lines come from an exported ordered **source array** - one entry per line, each a function of the
   injected `AgentStatus` / errors reader - so a new line is one appended source and one string key
   (AC1's "takes lines rather than being rewritten"). `showPrompts()` is true only when `answered()` and
   every `counted` line resolved to `0`; the `agent-status` source is `counted: false`, which is what
   keeps it out of the zero test and present in the fallback. `answered()` is false until every source
   has answered or settled to absent, so the block renders nothing rather than a partial block or a
   flash of prompts. `starterPrompts()` returns the three `homeStarterPrompt*` values in declaration
   order. Constructor options take `api`, `agentStatus`, `scope`, `connectivity?`, mirroring
   `agent-status.ts`'s own options shape.
5. `ui/src/app/core/suggested-view.ts` -- the **application-errors** source: one
   `GET /api/ocupilot/logs/errors/dates?namespace=<encodeURIComponent(scope.namespace())>` through
   `ApiService`, no `scope` on the request (AD-48: the route's `?ns=` never reaches that port). Rows are
   newest-date-first; take `rows[0]` and render `{count, date, namespace}`. `classifyFault` decides:
   `null` → the line; `refused` → no line, no retry; anything else → no line plus one
   `retryWhenReachable` keyed by the path. Zero rows → `count: 0`. Re-issue on `scope.subscribe`.
6. `ui/src/app/core/suggested-view.ts` -- the **agent-status** source: no HTTP of its own. Text is the
   restraint sentence the panel already selects, in this precedence: kill switch on → the kill-switch
   sentence; otherwise the footer read-only line for `restraint().footerKey`. `counted: false`,
   `count: 0`, descriptor `OcuPilot.Screen.Descriptor.AgentSwitches`. Zero new strings, so the line can
   never disagree with the banners above it.
7. `ui/src/app/core/strings.ts` -- add exactly three keys, each on one line, each with a
   `/** EXPERIENCE.md:<line> */` comment resolving to its new table row:
   `homeSuggestedView: 'Suggested view'`, `homeSuggestedOpen: 'Open'`,
   `homeSuggestedApplicationErrors: 'Application errors in <NAMESPACE>: <n> on <DATE>'`.
8. `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md` -- add three rows to
   the **Fixed strings** table (after `:330`, the Home starter-prompts row) carrying those three literals
   in double quotes with a `Where` cell each, and extend the existing `:289` row's `Where` cell to name
   the suggested view's `Open` accessible name. Record it in `## Spec Change Log` as a Rule 5
   apply-and-report amendment and report it under `amendments:` / `footprint_extensions:`.
9. `ui/src/app/shell/panel.ts` -- render the block between the chip slot and the transcript:
   `<section class="ocu-suggested" [attr.aria-labelledby]="suggestedLabelId">` wrapping
   `<p class="ocu-suggested-eyebrow" [id]="suggestedLabelId">{{ STRINGS.homeSuggestedView }}</p>` and a
   `<ul role="list">` of `<li class="ocu-suggested-line">` rows, each holding
   `<button type="button" class="ocu-suggested-prompt">` (the resolved line text, the count wrapped in
   `<code>`; its accessible name is its own text) and the `Open` control: an
   `<a class="ocu-button-text ocu-suggested-open" [href]>` with an `aria-hidden` `›` glyph and
   `[attr.aria-label]` = `tableChangeToastLink` with `SCREEN_PLACEHOLDER` replaced by the target screen's
   title, using `openDefinitions`'s modified-click bail + `preventDefault` + `navigateByUrl` handler
   (`:584-589`). When the target's `Verdict` is denied the anchor is `[attr.aria-disabled]="true"` with
   `aria-describedby` pointing at a hidden `formatRequires` sentence and the handler refuses - never
   removed, never natively `disabled`. When `showPrompts` is true the counted rows are replaced by three
   `<button class="ocu-suggested-starter">` rows and the `agent-status` line stays. Line text and prompt
   text are one resolved string with two renderings. Each `@if` condition is a paren-free member
   reference.
10. `ui/src/app/shell/panel.ts` -- render the empty-transcript block inside the transcript's `@else`
    branch, before the `@for`: `{{ STRINGS.agentIdleGreeting }}`, the three starter-prompt buttons, then
    `{{ STRINGS.agentIdleSelectionHint }}`, gated on `transcriptEmpty` (a getter: `turn.restored()` and
    `turn.entries().length === 0`).
11. `ui/src/app/shell/panel.ts` -- one handler for both gestures: `onSuggestion(text)` →
    `this.panel.setDraft(text)` then `this.composerEl()?.nativeElement.focus()`. It must not call
    `this.turn.send`. Mirror `SuggestedView` into the component by `subscribe` + `bump()` as the other
    stores are; call `load()` when the panel enters Home and `reset()` on `endSession`.
12. `ui/src/main.ts` -- provide `SuggestedView` as a value beside the other `core/` stores, wired to the
    same `api`, `agentStatus`, `scope` and `connectivity` instances.
13. `ui/src/styles/_components.scss` -- `.ocu-suggested` block: `flex: 0 0 auto`, `:empty { display: none }`
    following the chip slot's precedent; `.ocu-suggested-eyebrow` at `{typography.label}` in
    `--ocu-on-surface-variant`; `.ocu-suggested-line` **`min-height: 32px`** (DESIGN.md `:1137`; a
    minimum, not a fixed height, per DESIGN.md › Reflow) as a flex row with
    `align-items: baseline; gap: var(--ocu-space-2)`, hover `--ocu-surface-container-low`,
    `border-radius: var(--ocu-rounded-sm)`; `.ocu-suggested-starter` full-width rows on
    `--ocu-surface-container-low` with a 1px `--ocu-outline-variant`, `{rounded.md}`, `{typography.body}`
    in `--ocu-secondary` and a 16 px `aria-hidden` send glyph at the right. Design tokens only - no
    hardcoded colours (`client-lint.mjs`).
14. `ui/tools/panel-layout.test.mjs` -- add `homeTarget: 0` to `layoutAt`'s input builder (`:34`) and add
    the Home cases in task 17.
15. `ui/tools/suggested-view.test.mjs` (new) and `ui/src/app/shell/panel.spec.ts` (extend) and
    `ui/browser/suggested-view.browser-spec.mjs` (new) -- the legs in **Verification** below. The browser
    spec's definition-bearing case uses `armProbeDefinition` / `disarmProbeDefinition` from
    `ui/browser/turnprobe-spec.mjs`, asserts the teardown's own `%Status`, and asserts in `after` that
    `GET /api/ocupilot/agent/definitions` answers an empty list. Its geometry and transition cases need
    no definition and arm none.
16. Before running the browser suite, confirm no existing spec measures the panel on Home
    (`grep -n "signedInAt('/'" ui/browser/*.browser-spec.mjs` and check
    `ui/browser/screen-height.browser-spec.mjs`); a Home-route geometry assertion written against the
    400 px panel must move to a list route or take the Home numbers.

**Acceptance Criteria:**

- Given Home with an enabled definition and both reads answered, when the panel renders, then the
  "Suggested view" block precedes `.ocu-panel-transcript` in DOM order, each line is at least 32 px
  high, and each counted line's count is inside a `<code>` element.
- Given a line whose read has not answered, has faulted, or answered 403, when the block renders, then
  that line is absent - no zero, no skeleton row - and a 403 is never retried.
- Given a rendered line, when its text control is activated, then the composer holds exactly that line's
  text, the composer has focus, and no turn was started; and when its `Open` control is activated, then
  the router navigates to that line's screen.
- Given a line whose target screen the caller may not open, when the block renders, then that line's
  `Open` control is present, focusable, `aria-disabled="true"`, and describes the missing pair.
- Given a fourth source appended to the declared source array, when the block renders, then a fourth line
  appears in declared order with no change to the block's render path (Rule 1 integration AC: *Story 6.13
  adds its alerts.log line by appending one source and one string key, and the block produces a fourth
  line*).
- Given every counted line resolves to zero, when the block renders, then the three published starter
  prompts render instead of the zeros, each with the same gesture, and the agent-status line is still
  present.
- Given an enabled definition, a restored conversation and an empty transcript, when the panel renders,
  then the greeting, the three starter prompts and the selection hint render in that DOM order with texts
  byte-equal to their `core/strings.ts` values.
- Given Home at each of DESIGN.md's five published viewports, when the layout resolves, then the panel and
  content take the published Home widths (1,920 → 960/672 with the side bar open; 1,440 → 720/672
  collapsed; 1,280 → 592/640; 1,024 → 336/640; 900 → 320 with the content scrolling).
- Given the route leaves Home, when the layout resolves, then the panel width equals the remembered width,
  which the Home target never wrote.
- Given the panel is on Home, when the width changes, then `app-panel`'s computed `transition-property`
  includes `width` and its `transition-duration` is `0.12s`; and under
  `prefers-reduced-motion: reduce` that duration is `0s`.
- Given a drag or an arrow step on the resize handle while on Home, when it completes, then the panel
  holds the dragged width and that width is the stored remembered width.
- Given the built bundle, when `build-output.test.mjs` runs, then the initial total is still inside
  `angular.json`'s `maximumWarning`.

## Spec Change Log

- 2026-09-18, planning: AC1's parenthetical "tasks suspended after an error … available now" is
  contradicted by DW-269's own evidence (`Task.CRUD` LIST coerces every task's `Suspended` to `false`).
  The line is declined under AC1's own gate - "a line appears only when the read behind it exists" - and
  the lead is asked to move that clause in `epics.md` Story 4.10 from the available-now list to the
  joins-later list beside the 6.13 alerts line (Rule 5 apply-and-report; its own epic's block, Rule 11).
- 2026-09-18, planning: AC1's "application errors **today** per namespace" is restated as the count on the
  newest date the instance's own log names, in the current namespace scope. The instance's local calendar
  date is on no client-visible wire (`GET /api/ocupilot/instance` answers seven fields, none a timestamp),
  a browser-computed "today" is a documented wrong answer (spec 2-12: the container reported `09/15/2026`
  while the host read `2026-09-14`), and putting it on the wire means `Port/LogSourcePort.cls` /
  `Api/ErrorLog.cls`, both outside Epic 4's `paths_hint` and inside Epic 6's - a contended path Rule 11 (c)
  forbids deciding. Rule 5 apply-and-report: the observable is restated so it is reachable; the intent
  (Home names what needs attention) is unchanged. The missing instance-local date is filed as **DW-1135**
  (`routed owner=burndown`), because Story 6.13's "new alerts.log entries" line meets the same wall.
- 2026-09-18, planning: EXPERIENCE.md's **Fixed strings** table gains three rows (task 8). The table is the
  only authorized source for a `core/strings.ts` value and it publishes none of this block's own copy.

## Review Triage Log

### 2026-09-18 - Review pass

- verdicts: 60 findings - high 4, medium 11, low 42, false 3, maybe-false 0 (blind-hunter 30, edge-case 14, verification-gap 9, intent-alignment 7; routed patch 37, defer 9, reject 11 - grouped root causes share a route and keep their own rows)
- findings:
  - `[high]` `[patch]` blind-hunter: the three starter prompts render twice on Home - fixed: `suggestedPrompts` yields while `transcriptEmpty`; EXPERIENCE.md settles the precedence (Home shows "its suggested view or, when nothing needs attention, three starter prompts"; the panel's Idle row publishes the greeting's own order); new pinning case + mutation M1.
  - `[high]` `[patch]` edge-case: greeting and fallback both render, six identical rows - same root cause; same fix.
  - `[high]` `[patch]` verification-gap: the six-row state is constructed by no test - same root cause; the new case constructs it.
  - `[high]` `[patch]` intent-alignment: both prompt sets render and each test arranges the co-occurrence away - same root cause; same fix.
  - `[medium]` `[defer]` blind-hunter: the all-zero fallback fires on a refused or faulted read - real and reachable; task 4 specifies the wording and the matrix settles neither row against the other, so it is a product call. Deferred (item 1).
  - `[medium]` `[patch]` blind-hunter: the in-flight case mounts off Home, where the block is hidden anyway - re-arranged onto Home with the gated transport and a store-notification settle point; mutation M2.
  - `[medium]` `[patch]` edge-case: same in-flight case - same root cause; same fix.
  - `[medium]` `[patch]` verification-gap: `suggested.answered()` in the visibility gate is unpinned - same root cause; same fix.
  - `[medium]` `[patch]` intent-alignment: expectation at the rendered surface, coverage at the store surface - same root cause; same fix.
  - `[medium]` `[patch]` blind-hunter: `HOME_AREA_KEY` is a hand-copied literal with no drift test - pinned against the Home descriptor's own declared area; mutation M4b.
  - `[medium]` `[patch]` blind-hunter: a browser case reports green having asserted nothing - `t.skip` replaces the bare `return`; the suite reports 0 skipped, so the asserting branch ran.
  - `[medium]` `[patch]` blind-hunter: AC5 is never asserted over the render path - component-level appended-source case added; mutation M3.
  - `[medium]` `[patch]` verification-gap: same AC5 gap - same root cause; same fix.
  - `[medium]` `[patch]` verification-gap: `SWITCHES_DESCRIPTOR` is asserted only against itself - both exported descriptors pinned as resolvable, plus the agent-status row's own `href`; mutation M4a.
  - `[medium]` `[patch]` edge-case: a suggestion writes a draft into a composer the kill switch has made read-only - guard added, matching the four existing `composerUnavailable` call sites; mutation M5.
  - `[low]` `[patch]` blind-hunter: `applyWidth` can move the panel without notifying - the pre-release width is captured first; mutation M8.
  - `[low]` `[patch]` edge-case: same arrow-step case - same root cause; same fix.
  - `[low]` `[defer]` blind-hunter: the five-Home-widths case asserts a configuration Home does not reach - the pure-function leg is the right surface for the published table; the DESIGN.md/shell tension is pre-existing. Deferred (item 2); the browser leg's over-general message reworded.
  - `[low]` `[defer]` edge-case: DESIGN.md's Home content figure is unreachable - same root cause.
  - `[low]` `[defer]` intent-alignment: two legs assert contradictory side-bar values for one viewport - same root cause; they describe two reachable states, and both messages now say which.
  - `[low]` `[patch]` blind-hunter: a namespace switch leaves the previous namespace's sentence rendered - the previous answers are dropped before the new read; mutation M7.
  - `[low]` `[patch]` edge-case: same switch interval - same root cause; same fix.
  - `[low]` `[patch]` intent-alignment: the stale-render interval is asserted nowhere - same root cause; the new case asserts the interval itself.
  - `[low]` `[patch]` edge-case: a modifier click on an `aria-disabled` Open follows the href - the gate now precedes the modifier bail; mutation M6. The first assertion written for it was unfalsifiable in jsdom (following an href moves no router), so it asserts `defaultPrevented` instead.
  - `[low]` `[patch]` intent-alignment: the greeting's precondition is "not known-unconfigured", not "definition enabled" - gated on `greetingVisible` (answered and configured); mutation M14.
  - `[low]` `[patch]` blind-hunter: the always-rendered section carries a dangling IDREF when hidden - the binding is conditional; mutation M10.
  - `[low]` `[patch]` blind-hunter: `panelHomeTarget` returns a negative below a 688 px viewport - floored at 0, which is the value its own doc comment promises; mutation M9.
  - `[low]` `[patch]` blind-hunter: `:empty` is asserted nowhere - a browser assertion off Home measures the collapse; mutation demonstrated against the deployed bundle.
  - `[low]` `[patch]` verification-gap: same `:empty` gap - same root cause; same fix.
  - `[low]` `[patch]` blind-hunter: `expect(block.querySelector('section, [aria-labelledby]'))` searches descendants for the block itself, so it cannot fail - deleted; the `aria-labelledby === eyebrow.id` assertion beside it is the real one.
  - `[low]` `[patch]` blind-hunter: `.ocu-suggested-starter` has no `:hover` while its sibling has one - added, on the outline rather than a second fill.
  - `[low]` `[patch]` blind-hunter: `stubSuggestedView`'s doc comment claims a caller it does not have - corrected.
  - `[low]` `[patch]` blind-hunter: the store header describes a `ScopeService` subscription it does not have - corrected to say the panel owns the trigger.
  - `[low]` `[patch]` verification-gap: `reset()`'s doc comment misstates its callers - corrected.
  - `[low]` `[patch]` verification-gap: a test name pins neither half of what it says - renamed to what it asserts.
  - `[low]` `[patch]` verification-gap: the browser side-bar assertion message generalizes one entry path - reworded to name the path it measures.
  - `[low]` `[patch]` blind-hunter: `main.ts` import out of the file's own path order - moved.
  - `[low]` `[patch]` intent-alignment: AC4 is asserted on the application-errors row, not the agent-status row the matrix names - AC4 now asserts both rows.
  - `[low]` `[patch]` intent-alignment: nothing records that the mutations were run, and the `HOME_PANEL_FRACTION` line undercounts which rows redden - the `## Verification` line is corrected (Rule 19's sanctioned spec edit), the new pinning tests' mutation lines are added, and `## Auto Run Result` records the run.
  - `[low]` `[patch]` blind-hunter: an unresolvable descriptor renders an inert, enabled-looking Open, and `verdict !== null` is unreachable when a screen exists - both exported descriptors are now pinned resolvable, which is what makes the branch unreachable rather than merely untaken; the omit-the-control guard itself is rejected below.
  - `[low]` `[patch]` edge-case: an appended source naming an unbuilt descriptor - same root cause; same fix.
  - `[low]` `[defer]` blind-hunter: the endpoint path duplicates `error-log.store.ts`'s prefix - the clean fix crosses the `core/`-to-`areas/` boundary. Deferred (item 3).
  - `[low]` `[defer]` blind-hunter: the agent-status sentence selection is a third copy of the panel's precedence - spec-specified today, but nothing pins the copies equal. Deferred (item 4).
  - `[low]` `[defer]` blind-hunter: the browser spec re-implements three helpers verbatim - about sixty copied lines; lifting them is a refactor across two specs. Deferred (item 5).
  - `[low]` `[defer]` blind-hunter: a parked re-read outlives leaving Home - one wasted request, nothing wrongly rendered; canceling it needs state the store does not have. Deferred (item 6).
  - `[low]` `[defer]` edge-case: same parked re-read - same root cause.
  - `[low]` `[reject]` blind-hunter: `SuggestedView.answered()` is true before `AgentStatus` has answered - by-design: the Design Notes state that the switches read is ungated by construction and always answers, and the panel's own `answered` conjunct gates the render. Making the projection pending changes a specified behavior and the type of `agentStatusLine()`.
  - `[low]` `[reject]` blind-hunter: every `Open` has the identical accessible name - by-design: EXPERIENCE.md publishes "Open" as *the accessible name of a suggested-view line's open control, whose > is decorative*, which supersedes task 9's `tableChangeToastLink` instruction; reported to the lead as a task-9 deviation rather than changed here.
  - `[low]` `[reject]` edge-case: same `aria-label` deviation - same reason.
  - `[low]` `[reject]` blind-hunter: a row with a count and no date renders a dangling preposition - the endpoint's own row type always carries both, so the fix guards state not shown reachable.
  - `[low]` `[reject]` blind-hunter: `label`/`tail` and `text` diverge if the template carries two `<n>` slots - the published template carries exactly one, pinned verbatim by `strings.test.mjs`.
  - `[low]` `[reject]` edge-case: same two-slot hypothetical - same reason.
  - `[low]` `[reject]` blind-hunter: `SOURCES` is exported mutable module state a test mutates - the integration AC is about appending a source, the `finally` restores it, and threading the list through the options adds public surface for a test's sake.
  - `[low]` `[reject]` blind-hunter: `mount()` can put the component and `PanelState` on different `ShellState`s - no call site supplies both; the fix is a harness guard against a combination nothing uses.
  - `[low]` `[reject]` edge-case: the block could squeeze the transcript at 200% zoom - the proposed `max-height` plus `overflow-y` adds a second scrolling region, against the block's own "the transcript is the one scrolling region in the body"; the state stacks a short viewport on wrapped lines at the panel minimum.
  - `[low]` `[reject]` edge-case: `--ocu-panel-home` is still unconsumed at runtime - by-design: the intent's Never list forbids a runtime CSS consumer, and DW-379 was answered with the operand-drift test.
  - `[low]` `[reject]` verification-gap: AC3's navigate clause carries no `mutation:` line - bookkeeping only, and its test is falsifiable; the clause is now covered by the switches-descriptor mutation line added to `## Verification`.
  - `[false]` blind-hunter: `.ocu-suggested`'s padding aligns with neither neighbour - refuted: its left and right are `var(--ocu-space-4)` and `var(--ocu-panel-gutter)`, byte-identical to `.ocu-panel-transcript`'s own, so its rows align with the transcript exactly.
  - `[false]` blind-hunter: the browser spec loosens the settle tolerance from 0.01 to 0.51 px, letting a transition satisfy the wait early - refuted: the wait is followed by `Math.round(panelWidth) === row.panel`, and a value more than 0.5 px away does not round to the target, so the tolerance cannot produce a false pass.
  - `[false]` edge-case: the navigation map answering late leaves the block unloaded for that Home visit - refuted: `syncSuggested`'s preconditions are `ShellState.activeArea()`, `ScopeService.namespace()` and `AgentStatus`, none of them the navigation map; the map only decides the Open control's verdict, and `navigation.subscribe(() => this.bump())` re-renders on it.

## Design Notes

**Governing ADs.** AD-36 (the read contract and its `rowGet`/`INFO` clause), AD-24 (bounded reads),
AD-19 (framework-free stores mirrored into signals; `resolveLayout` the one layout computation), AD-8
(privilege at call time, a 403 reported and never retried), AD-13/AD-39 (the error envelope the client
maps through `classifyFault`), AD-43 (Home is *not* in the six-screen auto-refresh roster, so the block
has no timer), AD-48 (the route's `?ns=` never reaches `LogSourcePort`; the namespace travels as its own
parameter), AD-33/AD-11 (nothing here renders model-authored text; every literal is a published string).

**Consumes:** `AgentStatus` (3.7), `GET /api/ocupilot/logs/errors/dates` (2.12), `ScopeService` (1.11),
`NavigationService`'s privilege map (1.9), `PanelState` (4.3), `TurnStore` (4.5), `core/strings.ts` (1.2).

**Consumed-by:** Story 6.13 - appends the alerts.log source and its string key to
`core/suggested-view.ts`'s source array; a later Tasks-area story if DW-269's `INFO` `rowGet` is built.

**DW-160 - Home's panel widening.** Addressed. The criterion is now surface-anchored: `resolveLayout`
takes a `homeTarget` and the five published Home widths are pinned in `panel-layout.test.mjs`, the
settled widths and the transition in the browser spec.

**DW-379 - `--ocu-panel-home` has no consumer.** Addressed, with the token kept and given exactly one
consumer: a drift test that parses the three operands out of `--ocu-panel-home` in `_metrics.scss`
(`50vw`, `--ocu-rail-width`, `--ocu-content-min-width`) and asserts `panelHomeTarget` is built from the
same three numbers, so changing either side alone is red. A *runtime* CSS consumer was rejected: the
inline `[style.width.px]` `app.ts:169` already wins, and CSS cannot see the side bar, so a CSS width
cannot express the yield order (at 1,440 px with the side bar open the token says 720 and the yield order
says 512). Deleting the token was also rejected - DESIGN.md publishes `spacing.panel-home` and
`typography.test.mjs:330` asserts the formula.

**DW-269 - the suspended-tasks line. Declined, with the reason.** The read does not exist and cannot be
built here. AD-36's Rule admits an `INFO` `rowGet` (it was amended on 2026-09-14 for exactly this), but
nothing implements it: `Screen/Registry.cls`'s `RowGetProblem` closes the `rowGet` key set to
`key`/`param`/`fields`/`derived` (`:1013-1020`), its byte-for-byte mirror in `ui/tools/screen-mirror.mjs`
does the same, `Screen/Read.cls:46` hard-codes `Parameter DETAILTYPE = "GET"` and `:418` passes it
unconditionally, and `:411-414` refuses a `rowGet` whose key is not a JSON string against the task
list's numeric `Id`. Delivering the line therefore means: a grammar key in both engines plus corpus cases
in `Test/RowGetCorpus.cls`; a declared detail type in `Screen/Read.cls`; `Suspended` added to
`Descriptor/TaskScheduleList.cls`'s `read.fields`, which reddens three assertions written to keep it out
(`Test/Descriptor.cls:190`, `Test/Descriptor.cls:166-172`, `Test/WireSecurityRead.cls:336`) and changes
what Story 2.8's *screen and tool* both show, since AD-36 makes them one read. The runtime cost is one
`INFO` call per surviving row after the cap - an unbounded per-row fan-out on every Home entry, against
AD-24's whole posture - and `Screen/Descriptor/**` is Epic 6's footprint. This is a Tasks-area change,
not a Home change. **Recommended re-own: a Tasks story in Epic 7 (which already declares
`Screen/Descriptor/**`, `Screen/Tool/**` and the task write tools), else this epic's burn-down.** The
block takes lines, so the later line is an appended source, not a rewrite.

**Why the agent-status line is always present and never counted.** Its read is ungated by construction
(`Api/Switches.cls:2-12`, `:268-271`: "the audience for the kill-switch banner is precisely the people
who cannot change it"), so it always answers; it reports a state rather than a count, so it takes no part
in the zero test; and AC2 requires it to survive the fallback. Its text is the sentence the panel's own
banner and footer already render, selected by the same `footerKey`, so the block cannot contradict the
banner two rows above it. Its `Open` target, Switches, is `OcuPilotAdmin:USE`-gated, which is why the
`Open` control needs the Privilege Gating treatment rather than removal.

**Where the starter prompts come from: `core/strings.ts`, not the descriptor registry.** EXPERIENCE.md
publishes exactly three, as Home's, in the Fixed strings table (`:330`), and `strings.test.mjs` pins them
verbatim; the three keys already exist and are unrendered. A per-screen `starterPrompts` descriptor field
would need `Screen/Registry.cls`'s `DECLARATIONKEYS`, its byte-for-byte mirror in `screen-mirror.mjs`,
every class under `Screen/Descriptor/**` (Epic 6's footprint) and a regenerated
`screens.generated.ts` - and no second prompt set is published anywhere to put in it. **A screen with no
prompts therefore does not exist:** the set is a constant, not a lookup, and all three published prompts
are screen-agnostic by construction ("What's on this screen…", "…messages.log", "…this instance"), which
is what keeps the greeting's "or try one of these" true on every route. If a later story introduces
per-screen sets, a screen with none must render the greeting and the hint with no prompt rows, and that
story owns the greeting's wording.

**Where the counts come from, in one line each.** *Agent status:* `GET /api/ocupilot/agent/restraint`,
already loaded by the panel, ungated, eight fields; in flight → `answered()` false and nothing renders;
a failure keeps the previous answer and parks a re-read; no 403 is possible. *Application errors:* one
`GET /api/ocupilot/logs/errors/dates?namespace=<current scope>` → `{namespace, rows:[{date, count}], truncated}`,
newest date first, so `rows[0]` is the answer and no rows means zero; the per-date `count` costs no rows;
the privilege set is `%Admin_Operate:USE` + `%DB_IRISSYS:READ` + that namespace's `%DB_<res>:READ,WRITE`,
and the read+write half is satisfied by construction because the namespace switch offers only namespaces
the user can read and write.

**Why one namespace and not a fan-out.** "Per namespace" as "one line per namespace" needs
`/logs/errors/namespaces` plus one `/dates` per namespace, each able to 403 for its own reason - 1 + N
calls of unbounded N on every Home entry, which AD-24's and AD-36's bounded-read posture and NFR-1's
two-second budget select against. The `{date, count}` row *is* the per-namespace count, and Home already
names a namespace in its instance line and its context chip.

**Who owns the animation, and what a browser spec can assert.** The existing CSS transition on
`app-panel` (`_components.scss:618`, `transition: width var(--ocu-motion-panel-width-duration) ease`),
driven by the inline width changing; not the Web Animations API, which would need a second motion
authority and would not be zeroed by `_metrics.scss:81-92`'s reduced-motion block. A browser spec can
assert the **computed declaration** (`transitionProperty` contains `width`, `transitionDuration` is
`0.12s`, and `0s` under `emulateMediaFeatures`) and the **settled start and end widths**
(`panelSettlesAt`). It cannot reliably assert an intermediate width partway through a 120 ms transition -
a CDP round trip is the same order as the transition - so no mid-flight sample is asserted; the 120 ms
figure is carried by the computed duration plus `typography.test.mjs:347-349`.

**Bundle size.** Expect about 3-5 kB added (one small `core/` store, template and getters in `panel.ts`,
about 60 lines of SCSS, three strings) against about 12.4 kB of headroom, so **no budget change is
expected**. If the build lands over 780 kB, raising `maximumWarning` in `ui/angular.json` *and* the
pinned literal in `ui/tools/angular-json.test.mjs` is a named decision for the lead, never a silent edit.

**Merge risk to report.** Story 6.13 is likely to add its own Fixed-strings row for the alerts line
concurrently; the table is not union-merge safe, so Rule 22's integrate-forward before completion is
where that conflict is resolved.

## Verification

**Commands** (all from `ui/` unless stated; no ObjectScript changes, so no `check-objectscript.py` run
and no `%UnitTest` class is required):

- `npm test` -- expected: `node --test tools/*.test.mjs` green (including the new
  `tools/suggested-view.test.mjs` and the extended `tools/panel-layout.test.mjs`), then the vitest
  component runner green including the extended `src/app/shell/panel.spec.ts`.
- `npm run build` -- expected: the six `prebuild` checkers pass (in particular `client-lint.mjs` on the
  new template and `screen-mirror.mjs --check`, which must stay green because no descriptor changed), and
  `build-output.test.mjs`'s budget leg reports the initial total under 780 kB.
- `docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/` then
  `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci npm run test:browser`
  -- expected: the suite green at its new total (120 before this story, plus this story's cases); the new
  spec leaves `GET /api/ocupilot/agent/definitions` empty and asserts so.
- `bash scripts/smoke.sh --container ocupilot-ci --user _SYSTEM --password SYS` (from the worktree root)
  -- expected: a non-zero number of executed checks, all passing.
- `bash scripts/lint-docs.sh` (from the worktree root) -- expected: clean, including the amended
  EXPERIENCE.md.

**Which leg proves what.** `node --test tools/*.test.mjs` is the only leg that can execute `core/`
directly; vitest+jsdom is the only leg that can assert DOM shape, roles, names and order; the browser
runner is the only leg that can assert geometry, computed transitions, reduced motion and real focus
traversal (jsdom computes no layout and `.click()` moves no focus -
`ui/src/app/shell/command-bar.spec.ts:528`).

**Rule 19 - one demonstrated mutation per acceptance criterion.** Apply, observe red, revert, confirm
`git status --short` and `git diff --stat` unchanged, and record the result beside each line.

- Block precedes the transcript, 32 px rows, count in `<code>`:
  `mutation: move the <section class="ocu-suggested"> below .ocu-panel-transcript in panel.ts -> panel.spec.ts's DOM-order assertion goes red`;
  `mutation: .ocu-suggested-line min-height 32px -> 20px in _components.scss -> the browser spec's row-height assertion goes red`.
- A line appears only when its read exists:
  `mutation: make the application-errors source emit a zero-count line on a 403 -> suggested-view.test.mjs's refused-read case goes red`.
- The two gestures:
  `mutation: wire the line's text button to TurnStore.send instead of PanelState.setDraft -> panel.spec.ts's "no turn was started" assertion goes red`;
  `mutation: render the row as one button wrapping the Open label -> panel.spec.ts's two-distinct-controls assertion goes red`.
- A gated `Open` stays reachable:
  `mutation: replace [attr.aria-disabled] with the native disabled attribute -> panel.spec.ts's focusable-and-described assertion goes red`.
- The block takes lines:
  `mutation: hard-code the two line keys in the render path instead of iterating the source array -> suggested-view.test.mjs's appended-fourth-source case goes red`.
- The all-zero fallback:
  `mutation: include the agent-status line in the zero test -> suggested-view.test.mjs's "agent-status stays" assertion goes red`.
- The empty transcript:
  `mutation: swap the greeting and the selection hint in panel.ts -> panel.spec.ts's DOM-order assertion goes red`;
  `mutation: respell homeStarterPromptExplainLog in strings.ts -> tools/strings.test.mjs:422 goes red`.
- The five Home widths:
  `mutation: HOME_PANEL_FRACTION 0.5 -> 0.4 -> panel-layout.test.mjs's published-Home-widths test goes red on the 1,920, 1,440 and 1,280 rows`.
- Leaving Home restores the remembered width:
  `mutation: write the Home target into rememberedWidth inside homeTargetWidth() -> panel-layout.test.mjs's leave-Home case goes red`.
- The transition and reduced motion:
  `mutation: delete transition: width from app-panel in _components.scss -> the browser spec's transitionDuration assertion goes red`;
  `mutation: delete --ocu-motion-panel-width-duration from the prefers-reduced-motion block in _metrics.scss -> the browser spec's emulated-media assertion and tools/typography.test.mjs:347 both go red`.
- A width gesture on Home sticks:
  `mutation: set homeWidthReleased after reading this.layout() in applyWidth instead of before -> panel-layout.test.mjs's drag-on-Home case goes red`.
- The token drift test (DW-379's consumer):
  `mutation: change --ocu-content-min-width in _metrics.scss without changing CONTENT_MIN_WIDTH -> panel-layout.test.mjs's panel-home operand test goes red`.
- The bundle budget:
  `mutation: lower angular.json's maximumWarning to 700kB -> build-output.test.mjs:168 goes red`.

The review pass added eight pinning tests; their mutations, demonstrated the same way:

- One prompt set on screen (AC6 with AC7):
  `mutation: drop the transcriptEmpty guard from suggestedPrompts in panel.ts -> panel.spec.ts's fresh-container case goes red with six prompt rows`.
- The in-flight gate, on Home rather than off it (AC2):
  `mutation: delete && this.suggested.answered() from suggestedVisible -> panel.spec.ts's in-flight case and its namespace-switch case both go red`.
- The block takes lines at the render path (AC5):
  `mutation: slice suggestedRows to the two known keys in panel.ts -> panel.spec.ts's appended-fourth-source case goes red`.
- The agent-status line's own Open target (AC3):
  `mutation: respell SWITCHES_DESCRIPTOR -> tools/suggested-view.test.mjs's descriptor-resolves test and panel.spec.ts's switches-href case go red`.
- Home's area key (AC8, AC9):
  `mutation: change HOME_AREA_KEY -> tools/suggested-view.test.mjs's area-key test and four panel-layout.test.mjs Home cases go red`.
- A suggestion into an unavailable composer (AC3):
  `mutation: drop the composerUnavailable guard from onSuggestion -> panel.spec.ts's kill-switch case goes red`.
- A gated Open under a modifier click (AC4):
  `mutation: bail on the modifiers before the gate in onSuggestionOpen -> panel.spec.ts's AC4 defaultPrevented assertion goes red`.
- The namespace switch drops the previous answer (matrix: scope changes on Home):
  `mutation: drop the reset from syncSuggested's different-namespace branch -> panel.spec.ts's namespace-switch case goes red`.
- A width gesture that lands on the remembered width (AC11):
  `mutation: read the rendered width after the release in applyWidth -> panel-layout.test.mjs's arrow-step-at-the-remembered-width case goes red`.
- The Home target's 0 floor (AC8):
  `mutation: drop Math.max(0, ...) from panelHomeTarget -> panel-layout.test.mjs's floor test goes red`.
- The hidden block's label reference (AC1):
  `mutation: bind aria-labelledby unconditionally -> panel.spec.ts's dangling-IDREF case goes red`.
- The hidden block reserves no height (AC1):
  `mutation: delete .ocu-suggested:empty { display: none } from _components.scss -> the browser spec's off-Home height assertion goes red`.
- The greeting's published trigger (AC7):
  `mutation: gate the greeting on transcriptEmpty instead of greetingVisible -> panel.spec.ts's withheld-until-answered case goes red`.

The code-review pass added seven pinning tests and one assertion; their mutations, demonstrated the
same way:

- The map answering last (AC1):
  `mutation: drop this.syncSuggested() from panel.ts's navigation.subscribe handler -> panel.spec.ts's map-answers-last case goes red`.
- The all-zero fallback in the state production rests in (AC6):
  `mutation: make suggestedPrompts return [] unconditionally -> panel.spec.ts's restored-with-a-turn case and its fresh-container case both go red`.
- A refused `Open` reads as refused and states its reason (AC4):
  `mutation: delete the .ocu-suggested-open[aria-disabled='true'] colour rule, or the :focus-visible half of the reason reveal, from _components.scss -> tools/design-tokens.test.mjs's gated-Open test goes red`.
- The two decorative glyphs (AC1, AC3):
  `mutation: drop aria-hidden from either glyph span in panel.ts -> panel.spec.ts's accessible-name case goes red`.
- An appended source whose descriptor the mirror does not carry (AC5):
  `mutation: drop the row.url === '' half of onSuggestionOpen's guard -> panel.spec.ts's unbuilt-descriptor case goes red`.
- The parked re-read's own callback (matrix: the faulted read):
  `mutation: replace () => void this.load() with a callback that reads nothing -> tools/suggested-view.test.mjs's parked-re-read case goes red on its 2 s timer`.
- The Home target in whole pixels (AC8):
  `mutation: drop Math.floor from panelHomeTarget -> tools/panel-layout.test.mjs's DW-379 operand test goes red on its odd-viewport assertion`.
- Signing out ends the Home visit (AC9):
  `mutation: drop this.homeWidthReleased = false from endSession -> tools/panel-layout.test.mjs's sign-out case goes red`.

**Manual checks:** none. Every criterion above has a command.

## Auto Run Result

Status: done
Blocking condition: none

Home's suggested view ships as a framework-free `core/suggested-view.ts` store whose exported
`SOURCES` array is the extension point: one entry projects the agent-status sentence live from
`AgentStatus`, the other reads `GET /api/ocupilot/logs/errors/dates?namespace=<scope>` once per Home
visit per namespace. The panel renders the block between the chip slot and the transcript, the
greeting block inside the transcript's empty branch, and one gesture for both; Home's width resolves
through `resolveLayout` from a required `homeTarget`, so the existing yield order and the existing
120 ms CSS transition carry it.

**Files changed.**

- `ui/src/app/core/suggested-view.ts` (new) - the store, its two declared sources, and the
  `label`/`count`/`tail` split the row renders.
- `ui/src/app/core/panel-layout.ts` - `HOME_PANEL_FRACTION`, `panelHomeTarget`, a required
  `LayoutInput.homeTarget`, and `PanelState`'s per-visit Home release.
- `ui/src/app/core/navigation.ts` - `HOME_AREA_KEY` and `screenForDescriptor`.
- `ui/src/app/shell/panel.ts` - the block, the greeting, `onSuggestion`, `onSuggestionOpen`,
  `syncSuggested`.
- `ui/src/main.ts`, `ui/src/app/app.ts` - the store is provided and reset at sign-out.
- `ui/src/styles/_components.scss` - the `.ocu-suggested*` rules. **Also restores five rule blocks
  the first implementation pass deleted** (`.ocu-panel-transcript`, its `:focus-visible`,
  `.ocu-panel-empty`, `.ocu-panel-banner`, `.ocu-panel-banner-link`) - see residual risks.
- `ui/tools/suggested-view.test.mjs` (new), `ui/tools/panel-layout.test.mjs`,
  `ui/src/app/shell/panel.spec.ts`, `ui/src/app/testing/suggested-view.ts` (new),
  `ui/src/app/app*.spec.ts`, `ui/browser/suggested-view.browser-spec.mjs` (new) - the three legs.

Tasks 7 and 8 were already done in the baseline commit; they were verified, not redone, and no
literal and no Fixed-strings row was added.

**Review findings** - 60 findings across four layers. 37 patched, 9 deferred to frontmatter
`deferred:` (6 root causes), 11 rejected, 3 refuted. Patched by verdict: high 1 root cause (4
members), medium 6 root causes, low 12 root causes. Rejections, each with its recorded reason, are
in the triage log above; the load-bearing ones are the `Open` control's accessible name (by-design:
EXPERIENCE.md publishes "Open" as that control's name, superseding task 9's `tableChangeToastLink`
instruction) and `--ocu-panel-home` having no runtime CSS consumer (by-design: the intent forbids
one).

**Verification** - all from `ui/` unless stated. `npm test`: 976 `node --test` and 497 vitest across
36 files, 0 failures. `npm run build`: six prebuild checkers clean; initial total **778.37 kB**
against `angular.json`'s 780 kB `maximumWarning`, so no budget change was made or needed.
`docker cp dist/ocupilot-ui/browser/.` into `ocupilot-ci` then `npm run test:browser` at
`http://localhost:52776`: **126/126, 0 skipped** (120 before this story).
`GET /api/ocupilot/agent/definitions` answers `{"definitions":[]}` after the suite.
`bash scripts/smoke.sh --container ocupilot-ci`: `executed=18 passed=18 failed=0 pending=2
skipped=1`, PASSED. `bash scripts/lint-docs.sh`: 0 issues, 0 prose problems. No ObjectScript
changed, so no `check-objectscript.py` run and no `%UnitTest` class. Every mutation above was
applied, observed red on the named test, reverted, and the tree confirmed byte-identical.

**Follow-up review recommended: true.** The named unverified risk is the composition decision this
pass took: which of the two published prompt sets yields on Home. It is settled from EXPERIENCE.md
rather than from the spec, and it is observable only in jsdom - the throwaway's error log is seeded,
so the browser leg never reaches the all-zero fallback and no browser assertion has seen the
fresh-container Home a first user meets.

**Residual risks.**

- **A silent deletion that every gate passed.** The first implementation pass's SCSS insertion
  removed five existing `.ocu-panel-*` rule blocks, and `npm test`, six prebuild checkers, the
  126-case browser suite and the smoke run were all green without them - the transcript would not
  have scrolled and its focus ring was gone. They are restored and the stylesheet's diff is now a
  pure addition, but nothing in the suite would have caught it, and nothing does now.
- **Bundle headroom is 1.63 kB**, not the ~12.4 kB the spec's estimate assumed. Story 6.13's
  appended line and Epic 4's burn-down have very little room before `maximumWarning` needs a
  decision.
- The all-zero fallback's treatment of an unreadable count as a zero (deferred item 1) is a product
  call the block ships one answer to today.
