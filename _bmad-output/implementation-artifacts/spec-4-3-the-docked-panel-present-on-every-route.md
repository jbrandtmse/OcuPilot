---
title: 'The docked panel, present on every route'
type: 'feature'
created: '2026-09-16'
status: 'draft'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/DESIGN.md'
  - '{project-root}/_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md'
warnings:
  - multiple-goals
  - oversized
deferred: []
---

<intent-contract>

## Intent

**Problem:** The panel renders only while the agent is unconfigured or restrained, has no header, resize handle, full-screen toggle or transcript region, and nothing in the shell yields width: the side bar never auto-collapses, `.ocu-shell-content` has `min-width: 0`, and the 640px content minimum is an unconfirmed `[ASSUMPTION]`.

**Approach:** Render the panel on every signed-in route with its published anatomy (header, banners in fixed order, transcript log, footer), a keyboard- and pointer-driven resize handle whose width persists per browser, a full-screen toggle, the Ctrl/Cmd+I chord, and the yield order computed by one framework-free layout store; then measure the 640px figure in a real browser.

## Boundaries & Constraints

**Always:**

- Panel, draft, full-screen and layout state live in framework-free `core/` stores mirrored into signals; components hold no state of their own (AD-19). `core/` imports no `@angular/core`.
- Only `core/preferences.ts` touches `localStorage`; the panel width is a new allow-listed key `ocupilot.panel.width`. Full-screen is not persisted.
- Controls are never natively `disabled` or removed while focusable; unavailable controls use `aria-disabled` (EXPERIENCE.md Accessibility Floor).
- Every user-visible string comes from `core/strings.ts`; every string new to `strings.ts` is a row in EXPERIENCE.md's Fixed strings table or quoted in its `panel` / `panel-resize-handle` rules.
- Banner slots render in the order kill switch, enforced read-only, "not being marked", administrator reminder, lock. Only kill switch, enforced read-only and administrator reminder have a condition in this story; the other two slots stay empty until Epic 5 (FR-22) and Story 4.5.
- The page body never scrolls horizontally at any viewport; the panel never overlays, never becomes a bottom sheet and never auto-collapses.

**Never:**

- No close control, and no New conversation control (Story 4.5), context chip (4.4), turn wiring or Send action (4.5), `panel-home` width (4.10).
- No width media query breakpoints standing in for the yield computation; one store computes all three concessions from the measured viewport.
- No resize affordance on the side bar.
- No change to AD-7, no server code beyond the browser-spec principal fixture's reuse of `OcuPilot.Test.TurnWireFixture`.

## I/O & Edge-Case Matrix

Widths: rail 48, side bar 240, content minimum 640, panel minimum 320, remembered panel 400 (DESIGN.md Yield order, list-route columns).

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Wide | 1,920px, side bar open | side bar 240, panel 400, content 1,232, no yield | none |
| Side bar yields | 1,280px, side bar open by preference | side bar hidden (preference still open), panel 400, content 832 | none |
| User reopens while yielded | 1,280px, Ctrl/Cmd+B | side bar 240, panel 352, content 640; stored panel width stays 400 | none |
| Panel shrinks | 1,024px | side bar hidden, panel 336, content 640 | none |
| Content scrolls | 900px | panel 320, content region 532 wide scrolling a 640 floor; `document.scrollingElement.scrollWidth === clientWidth` | none |
| Drag bounds | drag past either stop | width clamps to [320, viewport − rail − side bar shown − 640], never below 320; grip restrained at either stop | none |
| Keyboard resize | handle focused, Left / Right | width ±16px within the bounds; `aria-valuenow` updates; `aria-valuemin/max` in px | none |
| Stored width unusable | `ocupilot.panel.width` absent, non-numeric, or < 320 | 400 used; out-of-range numbers clamped on read | preference read never throws into the shell |
| Full screen | toggle pressed | panel covers side bar and content; rail, header, status bar stay; side bar and content `inert`; `aria-expanded="true"`; pressing again restores the same width | none |
| Ctrl/Cmd+I | anywhere, no `[role="dialog"]`, overlay top is empty or the side bar | focus to `#ocu-panel-composer`; default prevented | chord ignored while a dialog, command box or account menu is open |

</intent-contract>

## Code Map

- `ui/src/app/shell/panel.ts` -- today renders only while `!configured() || restrained()` (`shown`, :184-188); banners :80-99, configuration-empty example and trust list :100-111, footer :114-136, `describedBy` :246-250, `generation` re-render from `navigation`/`agentStatus` subscriptions :164-173. Its doc comment :57-65 defers header, toggle and handle to this story.
- `ui/src/app/shell/panel.spec.ts` -- AC4 :136 (no chip, no New conversation; keep) and AC5 :177 (focusables exactly composer and Send; host text `''` after Enable) must be rewritten for an always-present panel; AC2 :92-106 already admits a link in the reminder banner.
- `ui/src/app/app.ts` -- frame template :120-152 mounts `<app-panel/>` as a sibling of `.ocu-shell-content`, outside the router outlet (persistence already structural); `onEscape` :256; `runFirstLoginGate` :391-426 consumes the fresh-sign-in flag before its awaits (DW-380 second half).
- `ui/src/app/core/session.ts` -- `runSubmit` :478-487 calls `notify()` after `formLogin` → `adopt` (:897) already notified via `setState('signed-in')` (DW-386); on the rejected path that notify publishes the cleared password and must stay.
- `ui/src/app/core/agent-status.ts` -- `load` :324 (not single-flight); `DEFINITIONS_ROUTE = 'agent/definitions'` :147.
- `ui/src/app/areas/agent/definition-form.store.ts` -- `refusedValues` :183, set by `rememberRefusal` :816 / `rememberRefusedValues` :834 from `snapshotValues()` after the awaited save (:558, :629, :785) and Test connection (:861) (DW-380 first half).
- `ui/src/app/core/shell-state.ts` -- side bar `open`, `collapse()` (unpersisted), `toggleOpen()` (persisted); pattern for a subscribable core store provided in `src/main.ts` :131-132, :180.
- `ui/src/app/core/preferences.ts` -- `PREFERENCE_KEYS` :48 closed allow-list; `tools/api.test.mjs` :694-708 bans `localStorage` elsewhere.
- `ui/src/app/core/overlay-stack.ts` -- `top()`; ids `command-box` (`command-box.ts:27`), `account-menu`, `dialog` (`dialog.ts:16`), side bar at bottom. Chord idiom to copy: `side-bar.ts:249-257`, `command-box.ts:30,276`.
- `ui/src/app/shell/side-bar.ts` -- `showing` :168-175; fixed 240px; nothing collapses it by width.
- `ui/src/app/shell/rail.ts` :94-124 and `_components.scss` rail tooltip rules (~:870-885, dot :3245-3257) -- DW-381's reveal (`~` combinator, `pointer-events: none`), asserted today only by `tools/design-tokens.test.mjs` :700-733 reading SCSS text.
- `ui/src/styles/_metrics.scss` -- `--ocu-panel-header-height` 44px, `--ocu-panel-default` 400px, `--ocu-panel-min` 320px :36-38, `--ocu-content-min-width` 640px :57, panel width motion token zeroed under reduced motion :84. `_components.scss` -- `app-panel` :619-626, `.ocu-shell-content { min-width: 0 }` :641-647, `.ocu-panel` :2968 onward.
- `ui/src/app/core/strings.ts` -- present: `navAreaAgent`, `agentComposerLabel`, `agentComposerCaption` :275, `agentGateReminderBanner` :183, `agentDefinitionListLabel` :465. Absent: "Conversation", the macOS caption, full-screen and handle names, the reminder link label.
- `ui/browser.config.mjs` -- fixed 1440x900 viewport; `OCUPILOT_BROWSER_USER/PASSWORD` default `_SYSTEM`/`SYS`; container `ocupilot-ci`. `ui/browser/gate.browser-spec.mjs` :150-190 -- sign-in steps and the `docker exec … iris session` fixture idiom; `browser/shell-entry.mjs` `leaveFirstLoginGate`.
- `src/OcuPilot/Test/TurnWireFixture.cls` -- `EnsurePrincipal(user, pw, resources)` :64, `Resources(0)` :42 (no admin resource), `DeletePrincipal` :140; armed by `OCUPILOT_ALLOW_PRINCIPALS=1`, set only by `scripts/ci-throwaway.sh` :161.
- Bundle deploy: `angular.json` :20 → `ui/dist/ocupilot-ui/browser`; `scripts/container-start.sh` :81; throwaway target `/durable/iris/csp/ocupilot/`. (`.claude/rules/objectscript-testing.md` names `dist/ocupilot/browser/`, which is wrong.)
- UX assets: `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/imports/robot-avatar-64.png` (header avatar, name "Agent").

## Tasks & Acceptance

**Execution:**

- `ui/src/app/core/panel-layout.ts` (new) + `ui/tools/panel-layout.test.mjs` -- pure `resolveLayout({viewport, sideBarPreferred, sideBarReopened, remembered, fullScreen})` returning side bar shown, panel width, panel max, content width, content scrolls; and a subscribable `PanelState` store (remembered width via `Preferences`, draft text, full-screen, drag/keyboard resize intents clamped to the bounds). Test every Matrix width row and the stored-width edge cases under `node --test`.
- `ui/src/app/core/preferences.ts` -- add `ocupilot.panel.width` to `PREFERENCE_KEYS` with a validated numeric reader.
- `ui/src/main.ts` -- provide `PanelState`; a single viewport listener (`resize` on `window`, read in a shell component, never in `core/`) feeds the viewport width into it.
- `ui/src/app/shell/panel.ts` + `panel.spec.ts` -- always render on the signed-in frame: header (avatar, "Agent co-pilot", full-screen toggle with `aria-expanded`), banner slots in fixed order, empty context-chip slot, transcript `role="log"` `aria-live="polite"` `aria-label="Conversation"` `tabindex="0"` scrolling independently (holds the configuration-empty sentence and example card when unconfigured), footer (read-only line, composer growing to four lines, Send, platform caption). Composer is editable when a definition is enabled and nothing restrains the agent, with its draft in `PanelState`; Send stays `aria-disabled` until Story 4.5. Administrator reminder banner gains its link to the Definitions route (DW-377, label per the lead's UX row). Rewrite AC5 and the render-nothing cases for the always-present panel.
- `ui/src/app/shell/panel-resize-handle.ts` (new) + spec -- `role="separator"`, `aria-orientation="vertical"`, focusable, `aria-valuenow/min/max` in px, pointer drag with capture, Left/Right ±16px, Escape ends a drag at its current width; grip `restrained` at a stop; `col-resize` cursor; named from `strings.ts`.
- `ui/src/app/app.ts` + `app.spec.ts` -- bind panel width, side-bar shown and `inert` on side bar and content from `PanelState`; Ctrl/Cmd+I handler per the Matrix; `runFirstLoginGate` spends the fresh-sign-in flag only when both reads answered (DW-380).
- `ui/src/app/shell/side-bar.ts` -- shown only when preferred and not yielded; Ctrl/Cmd+B while yielded records the user's reopen (next concession) without changing the stored preference.
- `ui/src/styles/_components.scss` -- `.ocu-shell-content` scroll region with an inner 640px floor; panel header, handle, grip, full-screen layout, composer growth; width transition 120ms honouring reduced motion.
- `ui/src/app/core/session.ts` + `ui/tools/session.test.mjs` -- `runSubmit` skips its second `notify()` on the accepted path only (DW-386).
- `ui/src/app/areas/agent/definition-form.store.ts` + spec -- snapshot the refused values when the request is sent and attribute a refusal to that snapshot (DW-380).
- `ui/src/app/core/strings.ts` -- add "Conversation", the macOS caption variant, and the strings named in Design Notes' UX rows once the lead has applied them.
- `ui/src/assets/avatar/robot-avatar-64.png` -- copy from UX imports.
- `ui/browser/panel.browser-spec.mjs` (new) -- geometry, resize, persistence across reload and navigation, full screen, Ctrl/Cmd+I, yield order at each Matrix width via `page.setViewport`, the 640px measurement (below).
- `ui/browser/panel-principal.browser-spec.mjs` (new) -- creates a least-privileged principal through `TurnWireFixture.EnsurePrincipal` with `Resources(0)` and a spec-generated password over `docker exec` on `config.container` (refusing `LIVE_CONTAINER`), signs in, asserts the panel on two routes shows the configuration-empty sentence and no reminder banner, then deletes the principal (DW-378).
- `ui/browser/rail.browser-spec.mjs` (new) -- hover and keyboard-focus a rail item with the attention dot lit; assert the tooltip is rendered visible and the dot does not intercept the pointer (`document.elementFromPoint` at the dot is the button) (DW-381).

**Acceptance Criteria:**

- Given any signed-in route, when it renders, then `aside.ocu-panel` is docked right at the stored width (400 when none, never below 320), content reflows to the remaining width, and no close control exists.
- Given a draft typed in the composer and a resized width, when the user navigates to another route, then the same panel element, draft and width remain; after a reload the width remains.
- Given the handle, when dragged or driven by Left/Right, then width moves only between 320 and the 640px-content point, the grip is `restrained` at a stop, and the stored width updates; the side bar has no sash, grip or `col-resize` cursor.
- Given full screen, when toggled on and off, then side bar and content are `inert` only while on, `aria-expanded` matches, and the width after restore equals the width before.
- Given the panel body, when rendered as an administrator with no enabled definition and the kill switch on, then banner DOM order is kill switch, (read-only if on), reminder; then the chip slot, the log region, then the footer with read-only line, composer labeled "Message to the agent", Send and the caption.
- Given Ctrl/Cmd+I, when pressed from content, side bar or rail, including while a Send is `aria-disabled`, then the composer has focus; with a dialog or the command box open it does not move.
- Given the narrowest supported viewport (1,280px), when the panel is docked and then resized to its maximum, then the rendered content width and whether content scrolls are measured and recorded in `## Verification` against 640px.
- Given a least-privileged principal, when signed in through the real browser, then the panel is present with the non-administrator configuration-empty state (DW-378).

## Spec Change Log

- 2026-09-17, lead at the plan halt: the narrowest supported viewport is 1,280px (EXPERIENCE.md's Full shell row), and the grip turns restrained at either stop (panel minimum and the 640px content point); Story 4.3's two ACs in `epics.md` amended to match, and 900-1,279px stays yield-order behavior asserted but not the measurement point. The three proposed Fixed strings rows were appended to EXPERIENCE.md.

## Review Triage Log

## Design Notes

**Governing ADs:** AD-19 (core stores mirrored into signals; no component state), AD-20 (no new API call; any added read goes through the one API service), AD-47 (no inline script; width through property bindings, which the CSP permits), AD-5 (the Definitions link resolves from the screen registry, not a literal path).

**Integration ACs.** `PanelState` and `resolveLayout` are consumed in this story by `App` (side bar, content, `inert`), `SideBar` (yield) and `Panel` (width, draft, full screen); the browser spec observes their effects. Consumed-by: Story 4.4 (context chip in the chip slot; reads route and selection beside the panel), Story 4.5 (Send/Stop, lock banner slot, transcript cards, draft cleared on send), Story 4.6 (reply rendering in the log region), Story 4.7 (navigation announcements in the log region), Story 4.10 (`panel-home` target width passed to `resolveLayout` on Home), Epic 5 ("not being marked" banner slot).

**Full screen.** DESIGN.md's Full screen row (rail, header and status bar stay; panel covers side bar and content) is read as the concrete form of EXPERIENCE.md's "app area below the header".

**Ledger inbox.** DW-377 addressed (link, pending the lead's UX row). DW-378 addressed (`panel-principal.browser-spec.mjs`). DW-380 addressed (both windows). DW-381 addressed (`rail.browser-spec.mjs`). DW-382 addressed (`resolveLayout` and the content floor). DW-386 addressed (accepted-path notify only).

**UX rows for the lead** (append after the Fixed strings table's last row, EXPERIENCE.md :344, as Story 3.9 did):

- `| "Definitions" | the administrator reminder banner's link, to Agent co-pilot › Definitions (DW-377) |`
- `| "Full screen" | the panel header's full-screen toggle name; its state is \`aria-expanded\` (UX-DR42) |`
- `| "Resize the agent co-pilot panel" | panel-resize-handle accessible name; its value is the width in px |`

## Verification

**Commands:**

- `cd ui && npm test` -- expected: all `node --test` suites (including `panel-layout.test.mjs`) and the vitest component suite green. Local.
- `cd ui && npm run build` -- expected: prebuild checkers and build succeed. Local.
- `bash scripts/ci-throwaway.sh up --dir /tmp/ocupilot-ci --project ocupilot-ci --web 52776 --super 1975` -- throwaway for browser specs; tear down only if this run brought it up.
- `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/` -- redeploy before any browser result counts.
- `cd ui && OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci npm run test:browser` -- expected: `panel`, `panel-principal`, `rail` and every existing browser spec green. Needs the slot-A throwaway.

**Manual checks (if no CLI):**

- The 640px measurement: at the narrowest supported viewport (1,280px), record panel width, content region width, inner content width and `scrollWidth` for the panel docked at 400 and resized to maximum, on the Users list and the Definition form; record whether 640 held or needs amendment.
- One `mutation:` line per AC, written by the implement stage.

## Auto Run Result

Status: blocked
Blocking condition: intent gap -- "the narrowest supported viewport" (Story 4.3's UX-DR80 AC) is not defined in any planning artifact. EXPERIENCE.md › Responsive & Platform tables 1,280 / 1,440 / 1,920px and a "< ~900 px" squeeze band; DESIGN.md's Yield order table's narrowest row is 900px, where the panel is pinned at 320 and has no resized width; PRD NFR-11 names desktop Chrome only. The readings measure different things (900: docked 320, no resize range, content 532 of 640; 1,024: docked 336, range 320-336; 1,280: docked 400, resizable to 592 at content 640). Recommended amendment: state the narrowest supported viewport as 1,280px (EXPERIENCE.md's "≥ 1,280 px Full shell" row and worked table; reconcile-vscode-reference.md's "1,280 px laptop"), keeping 900-1,279px as yield-order behavior asserted but not the measurement point. Secondary, with a recommendation, for the same amendment: the AC's "a grip that turns restrained at the stop" versus DESIGN.md's "At panel-min the grip turns restrained" -- recommend both stops (320 and the 640px-content maximum). The spec is otherwise planned; three Fixed strings rows for the lead are under Design Notes.
