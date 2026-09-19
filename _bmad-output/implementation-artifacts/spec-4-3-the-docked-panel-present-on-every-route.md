---
title: 'The docked panel, present on every route'
type: 'feature'
created: '2026-09-16'
status: 'done'
baseline_revision: '831861e1e4a995280e26c8eb6d5f280ab26efdbb'
baseline_commit: '831861e1e4a995280e26c8eb6d5f280ab26efdbb'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/DESIGN.md'
  - '{project-root}/_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md'
warnings:
  - multiple-goals
  - oversized
deferred:
  - summary: >-
      At a viewport where the remembered width makes the side bar yield (e.g. 1,280px), narrowing the panel to 352 or less brings the side bar back, panelMax drops to 352, and the panel cannot be widened again without closing the side-bar preference.
    evidence: |-
      resolveLayout decides the side-bar fit from the remembered width and applyWidth clamps to the resulting panelMax; a scratch run showed 400 -> 336 (bar shown, max 352) -> widen stuck at 352. Both published rules hold (the yield is undone "when the width allows"; the handle stops at the 640px content point beside a shown bar), so the fix is a product call on which rule gives way.
    location: >-
      ui/src/app/core/panel-layout.ts resolveLayout / applyWidth
    severity: medium
  - summary: >-
      The first-login gate now leaves the fresh-sign-in flag unspent when a read fails and retries on any later navigation or agent-status notification, with no time or route bound, so a user mid-task can be moved to the Definition form long after sign-in.
    evidence: |-
      App.retryFirstLoginGate runs on every navigation/agentStatus notify while hasFreshSignIn() is true; a map read that fails at sign-in and succeeds minutes later (scope change, connectivity back) triggers the redirect. Bounding it (first route only, time window, FormDirty check) is not settled by the spec or DW-380.
    location: >-
      ui/src/app/app.ts retryFirstLoginGate
    severity: medium
  - summary: >-
      .claude/rules/objectscript-testing.md names the bundle deploy path as dist/ocupilot/browser/; the real path is dist/ocupilot-ui/browser/.
    evidence: |-
      angular.json outputPath is dist/ocupilot-ui and the spec's Code Map records the rule as wrong; the fix edits an agent-context rules file.
    location: >-
      .claude/rules/objectscript-testing.md "A browser spec runs against the deployed bundle"
    severity: low
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
- Bundle deploy: `angular.json` :20 → `ui/dist/ocupilot-ui/browser`; `scripts/ci-throwaway.sh` :124-126 copies `ui/dist` at `up` only, mounted at `/opt/ocupilot/ui` (`container-start.sh` :81); the install copies it to `${dataDir}csp/ocupilot/` (`Install/Roster.cls` :103), i.e. `/durable/iris/csp/ocupilot/` — the `docker cp` target after a rebuild. (`.claude/rules/objectscript-testing.md` names `dist/ocupilot/browser/`, which is wrong.)
- UX assets: `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/imports/robot-avatar-64.png` (header avatar, name "Agent").

## Tasks & Acceptance

**Execution:**

- `ui/src/app/core/panel-layout.ts` (new) + `ui/tools/panel-layout.test.mjs` -- pure `resolveLayout({viewport, sideBarPreferred, sideBarReopened, remembered, fullScreen})` returning side bar shown, panel width, panel max, content width, content scrolls; and a subscribable `PanelState` store (remembered width via `Preferences`, draft text, full-screen, drag/keyboard resize intents clamped to the bounds). Test every Matrix width row and the stored-width edge cases under `node --test`.
- `ui/src/app/core/preferences.ts` -- add `ocupilot.panel.width` to `PREFERENCE_KEYS` with a validated numeric reader.
- `ui/src/main.ts` -- provide `PanelState`; a single viewport listener (`resize` on `window`, read in a shell component, never in `core/`) feeds the viewport width into it.
- `ui/src/app/shell/panel.ts` + `panel.spec.ts` -- always render on the signed-in frame: header (avatar, "Agent co-pilot", full-screen toggle with `aria-expanded`), banner slots in fixed order, empty context-chip slot, transcript `role="log"` `aria-live="polite"` `aria-label="Conversation"` `tabindex="0"` scrolling independently (holds the configuration-empty sentence and example card when unconfigured), footer (read-only line, composer growing to four lines, Send, platform caption). Composer is editable when a definition is enabled and nothing restrains the agent, with its draft in `PanelState`; Send stays `aria-disabled` until Story 4.5. Administrator reminder banner gains its link "Definitions" to the Definitions route (DW-377). Rewrite AC5 and the render-nothing cases for the always-present panel.
- `ui/src/app/shell/panel-resize-handle.ts` (new) + spec -- `role="separator"`, `aria-orientation="vertical"`, focusable, `aria-valuenow/min/max` in px, pointer drag with capture, Left/Right ±16px, Escape ends a drag at its current width; grip `restrained` at either stop (320, and the width that leaves content at 640); `col-resize` cursor; named "Resize the agent co-pilot panel" from `strings.ts`.
- `ui/src/app/app.ts` + `app.spec.ts` -- bind panel width, side-bar shown and `inert` on side bar and content from `PanelState`; Ctrl/Cmd+I handler per the Matrix; `runFirstLoginGate` spends the fresh-sign-in flag only when both reads answered (DW-380).
- `ui/src/app/shell/side-bar.ts` -- shown only when preferred and not yielded; Ctrl/Cmd+B while yielded records the user's reopen (next concession) without changing the stored preference.
- `ui/src/styles/_components.scss` -- `.ocu-shell-content` scroll region with an inner 640px floor; panel header, handle, grip, full-screen layout, composer growth; width transition 120ms honouring reduced motion.
- `ui/src/app/core/session.ts` + `ui/tools/session.test.mjs` -- `runSubmit` skips its second `notify()` on the accepted path only (DW-386).
- `ui/src/app/areas/agent/definition-form.store.ts` + spec -- snapshot the refused values when the request is sent and attribute a refusal to that snapshot (DW-380).
- `ui/src/app/core/strings.ts` -- add "Conversation" and the ⌘I caption variant (EXPERIENCE.md :308, :422-424), and "Definitions", "Full screen", "Resize the agent co-pilot panel" (Fixed strings rows :345-347).
- `ui/src/assets/avatar/robot-avatar-64.png` -- copy from UX imports.
- `ui/browser/panel.browser-spec.mjs` (new) -- geometry, resize, persistence across reload and navigation, full screen, Ctrl/Cmd+I, yield order at each Matrix width via `page.setViewport`, the 640px measurement (below).
- `ui/browser/panel-principal.browser-spec.mjs` (new) -- creates a least-privileged principal through `TurnWireFixture.EnsurePrincipal` with `Resources(0)` and a spec-generated password over `docker exec` on `config.container` (refusing `LIVE_CONTAINER`), signs in, asserts the panel on two routes shows the configuration-empty sentence and no reminder banner, then deletes the principal (DW-378).
- `ui/browser/rail.browser-spec.mjs` (new) -- hover and keyboard-focus a rail item with the attention dot lit; assert the tooltip is rendered visible and the dot does not intercept the pointer (`document.elementFromPoint` at the dot is the button) (DW-381).

**Acceptance Criteria:**

- Given any signed-in route, when it renders, then `aside.ocu-panel` is docked right at the stored width (400 when none, never below 320), content reflows to the remaining width, and no close control exists.
- Given a draft typed in the composer and a resized width, when the user navigates to another route, then the same panel element, draft and width remain; after a reload the width remains.
- Given the handle, when dragged or driven by Left/Right, then width moves only between 320 and the 640px-content point, the grip is `restrained` at either stop, and the stored width updates; the side bar has no sash, grip or `col-resize` cursor.
- Given full screen, when toggled on and off, then side bar and content are `inert` only while on, `aria-expanded` matches, and the width after restore equals the width before.
- Given the panel body, when rendered as an administrator with no enabled definition and the kill switch on, then banner DOM order is kill switch, (read-only if on), reminder; then the chip slot, the log region, then the footer with read-only line, composer labeled "Message to the agent", Send and the caption.
- Given Ctrl/Cmd+I, when pressed from content, side bar or rail, including while a Send is `aria-disabled`, then the composer has focus; with a dialog or the command box open it does not move.
- Given the narrowest supported viewport (1,280px), when the panel is docked and then resized to its maximum, then the rendered content width and whether content scrolls are measured and recorded in `## Verification` against 640px.
- Given a least-privileged principal, when signed in through the real browser, then the panel is present with the non-administrator configuration-empty state (DW-378).

### Review Findings

Code review 2026-09-17 (four layers, full-opus, no model override). 1 high, 4 medium and 6 low patched; 1 decision-pending filed (DW-460); 25 rejected.

- [x] [Review][Patch] `high` The status bar's `overflow: hidden` clipped the upward account menu, so Sign out was unreachable by pointer (probe on `main-YH7EGDGQ.js`: `elementFromPoint` at the menu hit the data-table footer) -- `overflow-x: clip` [ui/src/styles/_components.scss:1689]; sign-out browser leg now clicks and hit-tests for real.
- [x] [Review][Patch] `medium` Enforced read-only made the composer unavailable; DESIGN.md panel Read-only row says only the footer line changes, and EXPERIENCE.md Agent Write Lifecycle 8 reserves `aria-disabled` for the kill switch -- `composerUnavailable` keys on the kill switch; composer no longer described by the read-only banner [ui/src/app/shell/panel.ts:253].
- [x] [Review][Patch] `medium` DW-459: the gate's retry had no bound -- `App.spendSignInOnNavigation` spends the flag on the user's first navigation after sign-in (not the router's first, not a `replaceUrl` correction) [ui/src/app/app.ts:518].
- [x] [Review][Patch] `medium` A width that yields the side bar removed it while an entry held focus -- `SideBar`'s `PanelState` listener hands focus to the rail item first [ui/src/app/shell/side-bar.ts:183].
- [x] [Review][Patch] `medium` The status-read half of DW-380's retry had no test -- `app.spec.ts` status-read case [ui/src/app/app.spec.ts:966].
- [x] [Review][Patch] `low` The footer line never turned `{colors.restrained}` while read-only applies (DESIGN.md panel footer) -- `.ocu-panel-read-only-on` [ui/src/app/shell/panel.ts:121].
- [x] [Review][Patch] `low` A lost pointer capture left the drag armed -- `(lostpointercapture)` ends it [ui/src/app/shell/panel-resize-handle.ts:31].
- [x] [Review][Patch] `low` Composer growth to four lines had no browser evidence -- new `panel.browser-spec.mjs` leg [ui/browser/panel.browser-spec.mjs].
- [x] [Review][Patch] `low` Sign-out leg asserted an unchanged 400 width, and a message said "stays 400" over a `null` check -- assertion removed, message corrected [ui/browser/panel.browser-spec.mjs].
- [x] [Review][Patch] `low` Full-screen browser leg claimed the skip-link mutation goes red; it does not -- comment corrected [ui/browser/panel.browser-spec.mjs:322].
- [x] [Review][Patch] `low` `rail.browser-spec.mjs`'s `~`→`+` mutation claim was unobserved -- observed red, line below.
- [x] [Review][Defer] `medium` DW-460: the rail stays live in full screen and acts on the covered side bar -- decision-pending owner=burndown (ignore, or exit full screen) [ui/src/app/shell/rail.ts:226].
- [x] [Review][Defer] DW-458 re-checked, unchanged: the code matches EXPERIENCE.md :657 ("Reopened by the user: panel 352") and the yield rule's "undone in reverse as width returns"; only `panel-layout.test.mjs` (keyboard 352 cap, 1,920 drag), `PanelResizeHandle.atStop`, the rail/side-bar reopen paths and Story 4.10's `panel-home` input depend on the choice.
- [x] [Review][Defer] `low` DESIGN.md `panel-resize-handle` still names only the minimum stop; the Spec Change Log amended `epics.md` only -- planning-artifact correction for the lead.

Rejected: Send has no reason while configured (Story 4.5 owns Send and its reason string); Ctrl/Cmd+I ignored under the account menu (spec Matrix, by-design); `strings.test.mjs` distinct-literal count (low); sent-value snapshots on Test connection's create and credential posts untested (low, `wontfix-accepted`, reopen_if a refused create or credential post is reported against a field edited in flight); `Resources(1)` vs the Tasks text (fix edits this spec); rail and chord reopen write different preference values (same effective value); probe definition left by a failed setup (`after` removes it); unchecked instance preconditions (low); `MEASURE` output (the AC7 record); no `aria-controls` or Home/End on the separator (not in EXPERIENCE.md); onboarding content inside the `role="log"` (spec Tasks put it there); footer line before status answers (Story 3.7, unchanged); content-column popups clipped (false: the sort menu opens down, left-aligned, inside the full-height region); 4px handle overlap (low); router-event re-renders (low); accepted submit into `install-unreadable` not notified (low, `adopt` path unchanged for that state); duplicated fixture helpers (low); negative `contentWidth` below 368px (theoretical); a reopen surviving a Home visit (low); arrow during a pointer drag (low, rejected before); a step at a yielded width storing the rendered width (by-design, the user chose it); retry pass remounting the page (bounded by DW-459); `signOut` leaving the flag (false: `adopt` raises it and the navigation now spends it); skip link inert in full screen (low); DOM draft divergence (false: `readonly` blocks input); empty `definitionsHref` (false: registry entry always exists).

## Spec Change Log

- 2026-09-17, lead at the plan halt: the narrowest supported viewport is 1,280px (EXPERIENCE.md's Full shell row), and the grip turns restrained at either stop (panel minimum and the 640px content point); Story 4.3's two ACs in `epics.md` amended to match, and 900-1,279px stays yield-order behavior asserted but not the measurement point. The three proposed Fixed strings rows were appended to EXPERIENCE.md.

## Review Triage Log

### 2026-09-17 — Review pass

- verdicts: 40 findings — high 0, medium 12, low 21, false 7, maybe-false 0
- findings:
  - `[medium]` `[defer]` (blind) narrowing at 1,280px brings the side bar back and caps the panel at 352 — product call between two published rules; frontmatter `deferred`.
  - `[medium]` `[patch]` (blind) full screen: Escape collapsed the covered side bar and focused inert content; skip link and Ctrl/Cmd+B acted on covered regions — guarded in `App.onEscape`, `onSkipToContent`, `SideBar.onGlobalKeydown`; app/side-bar specs.
  - `[low]` `[patch]` (blind) browser-spec `after` hooks clean up even when `before` refused the live container — early return on `LIVE_CONTAINER`.
  - `[low]` `[reject]` (blind) specs refuse only `ocupilot`, not slot B — the guard is `browser.config.mjs`'s, shared by every existing spec.
  - `[low]` `[reject]` (blind) principal fixture uses `Resources(1)`/`RemovePrincipals()`, not the Code Map's `Resources(0)` — fix edits this spec; `Resources(0)` is refused `AUTH.NOADMIN` before the panel renders, recorded in Auto Run Result.
  - `[medium]` `[defer]` (blind) first-login gate can redirect long after sign-in — bound not settled by DW-380; frontmatter `deferred`.
  - `[false]` `[reject]` (blind) `signOut()` leaves `freshSignIn` set — the next sign-in's `adopt()` sets it anyway and `start()` resumes only at bootstrap on a new `Session`.
  - `[medium]` `[patch]` (blind) rail click on a reopened bar persisted "closed" unlike Ctrl/Cmd+B; comment wrong on `showArea` — `Rail.activate` releases the reopen; comment corrected; `rail.spec.ts` test.
  - `[low]` `[reject]` (blind) each composer keystroke notifies layout readers — signal bumps under OnPush; splitting listeners adds surface.
  - `[low]` `[patch]` (blind) caption assertion accepts either platform — two platform-pinned cases in `panel.spec.ts`.
  - `[low]` `[reject]` (blind) `isApplePlatform` imported from `command-box.ts` — cosmetic; `core/` may not read `navigator`.
  - `[low]` `[reject]` (blind) composer growth and reduced-motion transition untested — CSS-only, Chromium is the pinned browser.
  - `[low]` `[patch]` (blind) Ctrl/Cmd+I account-menu leg untested — `app.spec.ts` leg added.
  - `[false]` `[reject]` (blind) Story 3.6's "no control clears the state" lost — `panel.spec.ts` AC1 pins the aside's buttons as exactly Full screen and Send.
  - `[low]` `[patch]` (blind) DW-377 no mutation line — line added; test mounts on `?ns=USER`.
  - `[low]` `[patch]` (blind) `Math.min` mutation records disagree — re-run: six tests red; both records corrected.
  - `[false]` `[reject]` (blind) Auto Run Result stale — written at finalize.
  - `[low]` `[defer]` (blind) rule file names the wrong deploy path — agent-context file; frontmatter `deferred`.
  - `[low]` `[reject]` (blind) composer undescribed before both reads answer — transient load window; a reason needs a new string.
  - `[medium]` `[patch]` (edge) rail click on reopened active area persists closed — same entry as the rail row above.
  - `[medium]` `[patch]` (edge) a no-op step at a stop overwrote the remembered width — `applyWidth` returns when the rendered width is unchanged; `panel-layout.test.mjs`.
  - `[false]` `[reject]` (edge) `event.key` undefined on autofill keydown — `ctrlKey || metaKey` short-circuits first.
  - `[low]` `[reject]` (edge) non-Latin layouts miss Ctrl+I — the spec's chord idiom (`isSideBarChord`) uses `event.key` the same way.
  - `[medium]` `[defer]` (edge) late gate redirect / flag not bounded — same entry as the gate row above.
  - `[medium]` `[patch]` (edge) draft and full screen survive sign-out into the next user — `PanelState.endSession()` from `App`; `app.spec.ts`.
  - `[low]` `[patch]` (edge) full-screen toggle mid-drag dropped the stored width — `toggleFullScreen` calls `endDrag()`.
  - `[low]` `[reject]` (edge) arrow key during a pointer drag snaps back — needs a simultaneous pointer and key; fix adds a guard.
  - `[false]` `[reject]` (edge) `definitionsUrl` empty gives `href=""` — `screenForRoute('agent/definitions')` is a generated registry entry, never null.
  - `[medium]` `[patch]` (gap) rail click reopen untested — same entry as the rail row; `rail.spec.ts` at 1,280px.
  - `[low]` `[patch]` (gap) Ctrl/Cmd+B from a closed preference and the shell-close reset untested — `side-bar.spec.ts` and `panel-layout.test.mjs` cases.
  - `[medium]` `[patch]` (gap) DW-380 snapshot tested at Save only — Test connection case added.
  - `[low]` `[patch]` (gap) Definitions link `?ns=` untested — same entry as the DW-377 row.
  - `[low]` `[patch]` (gap) caption assertion unfalsifiable — same entry as the caption row.
  - `[medium]` `[defer]` (gap) panel cannot grow back past 352 at 1,280px — same entry as the first row.
  - `[low]` `[reject]` (gap) `Resources(1)` differs from the spec text — same as the fixture row.
  - `[low]` `[patch]` (intent) 640px measurement did not record the routed screen's own scroll — `main.ocu-content` widths recorded in MEASURE and Verification.
  - `[false]` `[reject]` (intent) DW items, rail reopen and `AgentFixture.SetFlags` exceed the intent — the spec's Tasks carry the DW items; a test fixture call is not server code.
  - `[false]` `[reject]` (intent) the macOS caption is not a quoted string — EXPERIENCE.md :308's row publishes "(⌘I on macOS)" and the spec task names it.
  - `[low]` `[reject]` (intent) some Matrix rows checked below the browser — stored-width parsing and dialog detection carry no geometry.
  - `[medium]` `[patch]` (intent) a resize at a narrow viewport rewrites the remembered width — same entry as the no-op step row.

## Design Notes

**Governing ADs:** AD-19 (core stores mirrored into signals; no component state), AD-20 (no new API call; any added read goes through the one API service), AD-47 (no inline script; width through property bindings, which the CSP permits), AD-5 (the Definitions link resolves from the screen registry, not a literal path).

**Integration ACs.** `PanelState` and `resolveLayout` are consumed in this story by `App` (side bar, content, `inert`), `SideBar` (yield) and `Panel` (width, draft, full screen); the browser spec observes their effects. Consumed-by: Story 4.4 (context chip in the chip slot; reads route and selection beside the panel), Story 4.5 (Send/Stop, lock banner slot, transcript cards, draft cleared on send), Story 4.6 (reply rendering in the log region), Story 4.7 (navigation announcements in the log region), Story 4.10 (`panel-home` target width passed to `resolveLayout` on Home), Epic 5 ("not being marked" banner slot).

**Full screen.** DESIGN.md's Full screen row (rail, header and status bar stay; panel covers side bar and content) is read as the concrete form of EXPERIENCE.md's "app area below the header".

**Measurement point.** The 640px confirmation is taken at 1,280px, the narrowest supported viewport (EXPERIENCE.md Full shell row; `epics.md` Story 4.3 as amended). There the side bar yields, the panel docks at 400 (content 832) and resizes to 592 (content 640). 900-1,279px is asserted as yield order only.

**Ledger inbox.** DW-377 addressed (link "Definitions"). DW-378 addressed (`panel-principal.browser-spec.mjs`). DW-380 addressed (both windows). DW-381 addressed (`rail.browser-spec.mjs`). DW-382 addressed (`resolveLayout` and the content floor). DW-386 addressed (accepted-path notify only).

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

**640px measurement (1,280px viewport, throwaway, `panel.browser-spec.mjs`):** Users list and Definition form measured identically. Docked: side bar yielded (0), panel 400, content region 832, floor 832, content `scrollWidth` 832, routed screen `main.ocu-content` `clientWidth` 832 and `scrollWidth` 832, page `scrollWidth` 1,280. Resized to maximum (592): content region 640, floor 640, content `scrollWidth` 640, `main.ocu-content` `clientWidth` 640 and `scrollWidth` 640, page `scrollWidth` 1,280. The 640px figure held: at the maximum the content is exactly 640, and neither the content region nor the routed screen scrolls inside itself on either route.

**Mutations** (each applied, observed red, reverted; `ui/src` mutations rebuilt and redeployed before the browser run, and the reverted bundle rebuilt and redeployed after):

- mutation: AC1 -- drop `[style.width.px]="panelWidth"` from `app.ts` -> `panel.browser-spec.mjs` AC1 red.
- mutation: AC2 -- make `PreferenceStore.setPanelWidth` write nothing -> `panel.browser-spec.mjs` AC2 red (width after reload).
- mutation: AC3 -- clamp `PanelState.applyWidth` to `Number.MAX_SAFE_INTEGER` instead of `panelMax` -> `panel.browser-spec.mjs` AC3 red.
- mutation: AC4 -- drop `[attr.inert]` from `.ocu-shell-content` -> `panel.browser-spec.mjs` AC4 red.
- mutation: AC5 -- move the reminder banner block above the kill-switch block in `panel.ts` -> `panel.spec.ts` AC5 red.
- mutation: AC6 -- drop `composer.focus()` from `App.onComposerChord` -> `panel.browser-spec.mjs` AC6 red; dropping the overlay-stack check -> `app.spec.ts` Ctrl/Cmd+I red.
- mutation: AC7 -- `panelMax` computed as `available - CONTENT_MIN_WIDTH + 16` -> `panel.browser-spec.mjs` 640px measurement red.
- mutation: AC8 -- `reminder` ignores the map verdict -> `panel-principal.browser-spec.mjs` DW-378 red.
- mutation: yield order -- side bar never collapses in `resolveLayout` -> `panel.browser-spec.mjs` Yield order red; dropping `Math.min(target, panelMax)` -> six `panel-layout.test.mjs` tests red (the 1,280 reopened, 1,024 and 900 rows, the clamped stored width, the reopen that writes no preference, the unchanged step).
- mutation: DW-380 -- `rememberRefusal` snapshots at arrival -> `definition-form.page.spec.ts` DW-380 red; gate spends the flag before its awaits -> `app.spec.ts` DW-380 red.
- mutation: DW-380 -- `testConnection` takes `sentToTest` after the awaited `/test` post -> `definition-form.page.spec.ts` DW-380 Test connection red.
- mutation: DW-377 -- `Panel.definitionsUrl` returns `screen.route` without `withQuery` -> `panel.spec.ts` DW-377 red (href `agent/definitions`, not `agent/definitions?ns=USER`).
- mutation: AC5 caption -- `!isApplePlatform()` -> `panel.spec.ts` caption Mac leg red; always the Mac caption -> non-Mac leg red.
- mutation: AC6 -- the chord ignored only when the top is `command-box` -> `app.spec.ts` Ctrl/Cmd+I account-menu leg red.
- mutation: yield order -- drop the `sideBarReopened()` branch from `Rail.activate` -> `rail.spec.ts` Yield order red; drop the reopen after `shell.toggleOpen()` in `SideBar.toggleFromKeyboard` -> `side-bar.spec.ts` Yield order red; drop `if (!this.shell.open()) this.reopened = false;` from `PanelState` -> `panel-layout.test.mjs` closing-ends-a-reopen red.
- mutation: resize at a stop -- drop the rendered-width early return from `PanelState.applyWidth` -> `panel-layout.test.mjs` unchanged-step red.
- mutation: full screen -- drop the `fullScreen()` branch from `App.onEscape`, or keep it but focus content -> `app.spec.ts` full-screen Escape red; drop the `fullScreen()` return from `App.onSkipToContent` -> same test red on the skip link; drop it from `SideBar.onGlobalKeydown` -> `side-bar.spec.ts` full-screen chord red.
- mutation: sign-out -- delete `this.panel.endSession()` from `App.verifyWhenSignedIn` -> `app.spec.ts` sign-out draft red.
- mutation: DW-381 -- drop `pointer-events: none` from `.ocu-rail-dot` -> `rail.browser-spec.mjs` red.
- mutation: DW-386 -- unconditional `notify()` in `runSubmit` -> `session.test.mjs` DW-386 red.
- mutation: full screen (QA) -- drop the `fullScreen()` branch from `App.onEscape` -> `panel.browser-spec.mjs` "Full screen: Escape, the skip link and Ctrl/Cmd+B" red (the covered side bar does not survive the exit-full-screen check); drop the `fullScreen()` guard from `SideBar.onGlobalKeydown` -> the same browser test red (Ctrl/Cmd+B closes the covered bar). The same test's skip-link assertion stayed green under a corresponding `App.onSkipToContent` mutation: `main#ocu-content` is `inert` while full screen regardless of that guard, and a real browser (unlike the jsdom suite) refuses `.focus()` on an inert element, so the guard's own falsification for that one line remains the existing `app.spec.ts` mutation.
- mutation: yield order (QA) -- drop the `sideBarReopened()` branch from `Rail.activate` -> `rail.browser-spec.mjs` "Yield order: clicking the visible area's rail item" red (the release click persists "false" instead of leaving the stored preference unchanged).
- mutation: sign-out (QA) -- delete `this.panel.endSession()` from `App.verifyWhenSignedIn` -> `panel.browser-spec.mjs` "Signing out clears the panel draft and full screen" red (the draft survives into the next sign-in).
- mutation: DW-459 (CR) -- delete `consumeFreshSignIn()` from `App.spendSignInOnNavigation` -> `app.spec.ts` DW-459 first-navigation red; drop its `replaceUrl` check -> DW-459 `replaceUrl` red.
- mutation: DW-380 status read (CR) -- remove `App`'s `agentStatus.subscribe(() => this.retryFirstLoginGate())` -> `app.spec.ts` "a status read that answers after sign-in" red.
- mutation: read-only composer (CR) -- `composerUnavailable` on `agentStatus.restrained()` -> `panel.spec.ts` "Read-only changes only the footer line" red; `readOnlyOn` returning `false` -> same test red.
- mutation: yield focus (CR) -- drop `yieldFocusToRail()` from `SideBar`'s `PanelState` listener -> `side-bar.spec.ts` "a width that yields the bar moves focus" red.
- mutation: lost capture (CR) -- drop `(lostpointercapture)` -> `panel-resize-handle.spec.ts` lost-capture red.
- mutation: account menu (CR) -- `.ocu-status-bar` back to `overflow: hidden`, rebuilt and redeployed -> `panel.browser-spec.mjs` sign-out leg red at the hit test; `field-sizing: content` removed in the same bundle -> composer-growth leg red (36px to 36px); `.ocu-rail-item:focus-visible ~` changed to `+` -> `rail.browser-spec.mjs` DW-381 keyboard leg red. Final bundle redeployed; `panel` 10/10, `rail` 2/2, `gate` 5/5, `panel-principal` 1/1.

## Auto Run Result

Status: done
Blocking condition: none

**Change.** The panel renders on every signed-in route with header, fixed banner slots, chip slot, `role="log"` transcript and footer; a resize handle (pointer, Left/Right, stops, stored `ocupilot.panel.width`); full screen with `inert`; Ctrl/Cmd+I; the yield order computed once by `resolveLayout`/`PanelState`; DW-377, 378, 380, 381, 382, 386.

**Files.** `core/panel-layout.ts` (new: layout and panel store) · `core/preferences.ts` (width key) · `core/session.ts` (`hasFreshSignIn`, accepted-path notify) · `core/strings.ts` (four strings) · `app.ts` (viewport listener, width/`inert` bindings, chord, gate retry, full-screen Escape, sign-out reset) · `shell/panel.ts` (always-present anatomy) · `shell/panel-resize-handle.ts` (new) · `shell/side-bar.ts`, `shell/rail.ts` (yield and reopen) · `shell/command-box.ts` (export `isApplePlatform`) · `areas/agent/definition-form.store.ts` (refusal snapshot at send) · `_components.scss` (content floor, panel chrome, full screen) · `assets/avatar/robot-avatar-64.png` · specs: `panel-layout.test.mjs`, `panel-resize-handle.spec.ts`, `panel.spec.ts`, `app.spec.ts`, `rail.spec.ts`, `side-bar.spec.ts`, `definition-form.page.spec.ts`, `session.test.mjs`, `strings.test.mjs`, `api.test.mjs`, browser `panel`, `panel-principal`, `rail`, `gate`.

**Review.** 40 findings: 13 entries patched (5 medium, 8 low), 3 deferred (frontmatter), 17 rejected with reasons in the triage log. `panel-principal.browser-spec.mjs` uses `TurnWireFixture.Resources(1)` (adds only `%Admin_Operate:USE`), because a `Resources(0)` principal is refused `AUTH.NOADMIN` and never reaches the panel; the Code Map's `Resources(0)` is stale.

**Follow-up review: true** (patched: medium 5, low 8). The full-screen Escape and Ctrl/Cmd+B guards, the rail release of a reopened bar, and the sign-out reset now each carry a `panel.browser-spec.mjs` or `rail.browser-spec.mjs` leg (QA pass) beside the jsdom pin; the skip-link guard stays jsdom-only because `main#ocu-content` is `inert` while full screen and a real browser already refuses focus into it regardless of the guard.

**Verification.** `npm test`: node 820/820, vitest 398/398. `npm run build`: green (initial-bundle 500 kB warning, 608 kB, under the 1 MB error). Bundle redeployed to `ocupilot-ci`; `npm run test:browser`: 86/86. 640px measurement and mutation lines under `## Verification`. QA pass (2026-09-16): `panel.browser-spec.mjs` 9/9, `rail.browser-spec.mjs` 2/2 after adding the three legs below; four new mutations applied, observed red, reverted, and re-verified green with the bundle rebuilt and redeployed each time; `git status --short` clean against baseline afterward.

**Residual risks.** The two medium deferrals above; composer disabled under enforced read-only follows the spec's "nothing restrains" wording; the avatar is `aria-hidden` beside the title.

**QA pass test files (2026-09-16):**

- `ui/browser/panel.browser-spec.mjs` -- two tests added: full-screen Escape/skip-link/Ctrl-Cmd-B, and the sign-out reset of draft and full screen. (QA)
- `ui/browser/rail.browser-spec.mjs` -- one test added: the rail click reopen/release of a yielded side bar. (QA)
