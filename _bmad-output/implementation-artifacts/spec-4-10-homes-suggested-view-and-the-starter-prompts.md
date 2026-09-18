---
title: 'Story 4.10 - Home''s suggested view and the starter prompts'
type: 'feature'
created: '2026-09-18'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
warnings: ['oversized']
owned_ledger: ['DW-160', 'DW-269', 'DW-379']
deferred: []
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
  `mutation: HOME_PANEL_FRACTION 0.5 -> 0.4 -> panel-layout.test.mjs's 1,920 and 1,440 Home cases go red`.
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

**Manual checks:** none. Every criterion above has a command.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none

Planning only; no implementation was performed. Decisions taken are recorded in `## Spec Change Log`
and `## Design Notes`; the three routed ledger entries are answered there (DW-160 addressed, DW-379
addressed, DW-269 declined with a reason and a recommended re-own).
