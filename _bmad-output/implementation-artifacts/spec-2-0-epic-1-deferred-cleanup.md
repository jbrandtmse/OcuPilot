---
title: 'Story 2.0: Epic 1 deferred cleanup'
type: 'bugfix'
created: '2026-09-13'
status: 'done'
baseline_revision: 'd3a01022b605ec20519e0a1047883139f1437d6f'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
warnings: ['multiple-goals', 'oversized']
deferred:
  - summary: >-
      The shared secondary and text buttons are content-box with a 1px border outside --ocu-control-height, so they stand 34px beside the primary's 32px.
    evidence: |-
      .ocu-button-secondary / .ocu-button-text set height var(--ocu-control-height) with no box-sizing and a 1px border, while .ocu-button-primary has border none; the comment above them says all three share one height. The classic-link card action compensates with calc(var(--ocu-control-height) + 2px). Pre-existing; this story only matched it.
    location: >-
      ui/src/styles/_components.scss:250
    severity: low
  - summary: >-
      A ScreenActions handler registered from a routed page's lifecycle may notify during change detection (NG0100) or outlive its page if the page does not unregister on destroy.
    evidence: |-
      No test registers from a routed component; the only registrations are in component specs. Settled by Story 8.1's first handler: a spec that registers in the page's constructor or ngOnInit, unregisters through DestroyRef, navigates away and back, and asserts no NG0100 and one run per click.
    location: >-
      ui/src/app/core/screen-actions.ts
    severity: medium (unverified)
  - summary: >-
      After an in-app sign-in or instance recovery swaps the frame in, the first Tab may not land on Skip to content.
    evidence: |-
      The browser spec covers a fresh page load only. Chrome's sequential focus starting point after the focused sign-in control is removed is not established (inference). Settled by a shell.browser-spec.mjs case that signs in through the form, then presses Tab and asserts the skip link holds focus.
    location: >-
      ui/src/app/app.ts
    severity: medium (unverified)
---

<intent-contract>

## Intent

**Problem:** Eight Epic 1 defects sit under the tooling and shell Epic 2 builds on. The XData readers end a block at a brace inside a JSON string, and a malformed descriptor fails with no file name. A built screen whose archetype has no page renders blank. A primary action with no handler is drawn as usable. There is no Skip to content link. The classic-link card's label is unbounded and its hover is invisible. Every component spec hand-builds its own `ScreenDeclaration`.

**Approach:** Close each defect where it originates. Make both readers string-aware and name the file on a parse failure. Refuse a built archetype with no page at compile time. Offer a primary action only once a handler is registered. Add the skip link from the published literal. Bound the card label and move the button hover onto DESIGN.md's state layer. Move every declaration fixture into one builder, pinning geometry and hover in a real browser.

## Boundaries & Constraints

**Always:**
- Copy comes from `ui/src/app/core/strings.ts` only. "Skip to content" is authorized by `EXPERIENCE.md:594` (Accessibility Floor, Landmarks line) through a targeted extractor in `ui/tools/strings.test.mjs`, the way `extractLandmarkNames` authorizes "Breadcrumb", and never by adding to `REQUIRED_ALONGSIDE_TABLE`.
- Visuals are design tokens only. The skip link is `button-primary`, top-left over the header, and visible only while focused (`DESIGN.md:661`). The `button-secondary` and `button-text` state layers are `{colors.secondary}` at 8% on hover and 12% when pressed (`DESIGN.md:554`, `:564`).
- `extractXData` (`ui/tools/screen-mirror.mjs`) and both brace walks in `scripts/check-objectscript.py` share one boundary rule, so the two languages cannot disagree on where a block ends.
- Geometry and hover are asserted by `npm run test:browser` in headless Chrome, because jsdom computes no layout.
- `screens.generated.ts` is regenerated with `node tools/screen-mirror.mjs`, never hand-edited.
- Non-ASCII characters are written as `\uXXXX`.

**Never:**
- New product copy: no reason text for a handler-less action and no message for a blank screen.
- A new dependency, or edits to `EXPERIENCE.md`, `DESIGN.md` or any ObjectScript class.
- A primary-action runner of its own (Epic 8 owns creates). Changing row-action behaviour. Rendering the classic-link card anywhere in the app.
- Fixing the same-line XData form. `DW-129`'s pins stay green.
- `docker compose up` or `down`. Browser specs needing an instance run against `scripts/ci-throwaway.sh`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Braced string (DW-204) | A `Declaration` body line `"reason": "a } brace",` followed by more keys | `extractXData` returns the whole body, which parses. `check-objectscript.py` checks the entity types after that line | An escaped `\"` inside a string does not end the string. String state resets at each line end, so a stray quote in an XML XData cannot swallow the closing brace |
| Malformed JSON (DW-183) | A descriptor whose `Declaration` is valid UDL but invalid JSON | `readSources()` throws a message naming the `.cls` path and the parser's own message. `classic-links.mjs`' refusal carries both | The `XData Areas` parse names `Area.cls` the same way |
| Built archetype with no page (DW-165) | A descriptor with `built: true` and an archetype in the vocabulary but absent from `ARCHETYPE_PAGES` | `npm run build` fails, and the compiler error names that archetype | An archetype outside the vocabulary is already refused by name (`screen-mirror.test.mjs:461`, `classic-links.test.mjs:185`) |
| Primary action, no handler (DW-153) | The screen declares `primaryAction.id: 'create'` and nothing is registered | The command bar draws no primary button, and the command box lists no `create` action row | none |
| Primary action, handler registered (DW-153) | The same screen, with a handler registered for its descriptor and `create` | The button renders. A click runs the handler once. Choosing the box row runs it once and closes the box | Unregistering removes both again |
| Skip link (DW-149) | The signed-in frame renders | The first Tab stop in the document is "Skip to content". It shows while focused, and activating it focuses `main#ocu-content` | The URL is unchanged after activation (`<base href="/ocupilot/">` would resolve a bare fragment link as a navigation). There is no link when there is no frame |
| Long page name (DW-180) | The card's label is 120 characters inside a 320px column | The pill keeps `--ocu-control-height`, stays inside the card, ends the label in an ellipsis, and keeps the glyph visible | none |
| Hover (DW-185) | The pointer is over the card's action | The painted background differs from both the resting state and the card's `surface-container-low` | none |

</intent-contract>

## Code Map

- `ui/tools/screen-mirror.mjs`
  - `extractXData` (`:67`) is the per-line brace count behind DW-204, and `occurrences` (`:53`) is its helper.
  - `readSources` (`:176`) holds the bare `JSON.parse` calls at `:195` and `:205` (DW-183). It reads the module constant `DESCRIPTOR_DIR`, so no test can inject a directory yet.
  - `buildMirror` emits `ArchetypeKey` at `:402`. `BuiltArchetypeKey` goes beside it.
- `ui/tools/ipm-manifest.mjs:47` imports `extractXData` and needs no change.
- `ui/tools/classic-links.mjs` imports these readers at `:41`. `checkClassicLinks` takes an injected `descriptorDir` (`:228`) but still calls `readSources()` with no argument (`:291`), and it turns the throw into a refusal at `:293`.
- `scripts/check-objectscript.py`: `iter_code_lines` (`:431`) skips XData bodies and `iter_named_xdata_blocks` (`:696`) yields them. Both use `raw.count("{") - raw.count("}")` in three places each.
- `scripts/test_check_objectscript.py`: `TestEntityTypeRule` (`:271`) and `TestDW129SingleLineXDataDisagreement` (`:430`), which must stay green, show the fixture-tree pattern.
- `ui/tools/screen-mirror.test.mjs`: `:340-391` pins DW-183's defect at a seam that closing it leaves green. Replace it.
- `ui/src/app/shell/screen-outlet.ts`: `ARCHETYPE_PAGES` (`:34`) is a `Record<string, …>`, so nothing requires a built archetype to be present. `resolveArchetypePage` (`:52`) is pinned in `screen-outlet.spec.ts:252-270`.
- `ui/src/app/shell/command-bar.ts`: the primary button (`:79-83`) has no `(click)`, and `hasPrimaryAction` is at `:169`. The docstring at `:47-58` sets the precedent that a slot nothing can fill is not rendered, as does `EXPERIENCE.md:159` ("no dead entries").
- `ui/src/app/shell/command-box.ts`: `choose()` (`:338`) closes on an action row, and `actionCandidates()` (`:409`) lists the primary unconditionally.
- `ui/src/main.ts:152` holds the providers. `RefreshService` (`core/refresh.ts:139`, `subscribe` at `:185`) is the framework-free subscribable pattern to copy.
- `ui/src/app/app.ts`: the template at `:105` puts the heading and `app-fault-banner` ahead of the frame, and the frame's `@if` is at `:110-111`. `CONTENT_ID` is `'ocu-content'` (`:30`), and `main` already carries `tabindex="-1"`.
- `ui/src/app/core/strings.ts:339` is the `navLocatorLandmark` precedent. `ui/tools/strings.test.mjs` has `extractLandmarkNames` at `:82` and `EXTRACTED_FROM_PROSE` at `:169`.
- `ui/src/app/shell/classic-link-card.ts` renders the label as a bare `<span>` inside the inline-flex anchor.
- `ui/src/styles/_components.scss`
  - The button base is at `:250-266`.
  - The shared hover at `:276-279` is `surface-container-low`, the same token as the card background at `:1800` (DW-185).
  - The card rule is at `:1791`.
- `ui/tools/design-tokens.test.mjs`: the `DW-145` (`:426`) and `DW-173` (`:560`) stylesheet pins are the bounding recipe to follow, and `:608` pins the card.
- `ui/browser/shell.browser-spec.mjs` is the signed-in harness on the throwaway (52776). `ui/browser.config.mjs` holds the launch options. `ui/tools/build-output.test.mjs:240` shows how to read a component's inline template out of its source.
- Hand-built `ScreenDeclaration` literals (DW-174). A `toolIdentifier` grep counts 11, each anchored at its `descriptor:` line:
  - `src/app/app.spec.ts:262`
  - `app.wire.spec.ts:189`
  - `areas/home/home.page.spec.ts:44`
  - `shell/command-bar.spec.ts:70`
  - `command-box.spec.ts:29`
  - `fault-banner.spec.ts:26`
  - `locator-bar.spec.ts:20`
  - `side-bar.spec.ts:40`
  - `status-bar.spec.ts:148`
  - `ui/tools/refresh.test.mjs:61` and `refresh-connectivity.wire.test.mjs:64`, which import `.ts` directly and already lack `label`/`href`
- `command-bar.spec.ts:164-172` and `command-box.spec.ts:283-285` assert today's unconditional primary action and change with DW-153.

## Tasks & Acceptance

**Execution:**
- `ui/tools/screen-mirror.mjs`, for DW-204, DW-183 and DW-165:
  - Count braces only outside double-quoted strings, honouring `\` escapes and resetting string state per line.
  - `readSources({ descriptorDir = DESCRIPTOR_DIR } = {})` wraps the descriptor and area parses so the throw names the source path and the parser message.
  - Emit `export type BuiltArchetypeKey`, the union of archetypes of `built: true` screens, or `never` when there are none.
  - Regenerate `screens.generated.ts`.
- `ui/tools/classic-links.mjs`, for DW-183: when no `screens` are supplied, pass the injected `descriptorDir` to `readSources`, so the gate reads the directory it reports on. Update the population note at `:18-28` to match.
- `scripts/check-objectscript.py`, for DW-204: one string-aware `brace_delta(line)` helper, used at all six count sites.
- `ui/src/app/shell/screen-outlet.ts`, for DW-165: type `ARCHETYPE_PAGES` so every `BuiltArchetypeKey` is a required key and any other `ArchetypeKey` is optional. Widen `resolveArchetypePage`'s parameter type only as far as that needs.
- `ui/src/app/core/screen-actions.ts` (new), for DW-153: a framework-free `ScreenActions`. It offers `register(descriptor, actionId, run)` returning an unregister function, plus `has`, `run` and `subscribe`. Provide it in `ui/src/main.ts`.
- `ui/src/app/shell/command-bar.ts` and `command-box.ts`, for DW-153:
  - Offer the primary action only when `ScreenActions.has(screen.descriptor, primaryAction.id)`.
  - A bar click and a box choice both call `run`.
  - Follow registry changes, and update the docstrings to match.
- `ui/src/app/app.ts`, `ui/src/app/core/strings.ts` and `ui/src/styles/_components.scss`, for DW-149:
  - The skip link is the template's first element, rendered under the frame's condition.
  - Activation focuses `#ocu-content` without changing the URL.
  - Add a new `strings.ts` key.
  - The skip-link style follows `DESIGN.md:661`.
- `ui/src/app/shell/classic-link-card.ts` and `_components.scss`, for DW-180: give the label span its own class and bound it inside the pill. Use the DW-145 recipe (`max-width: 100%`, `min-width: 0`, `overflow: hidden`, `text-overflow: ellipsis`, `white-space: nowrap`), and keep the glyph from shrinking.
- `ui/src/styles/_components.scss`, for DW-185: `.ocu-button-secondary` and `.ocu-button-text` hover at `--ocu-secondary` 8% and press at 12%, composed with `color-mix` over whatever surface is beneath.
- `ui/src/app/testing/screen-declaration.ts` (new), for DW-174:
  - `screenDeclaration(overrides?: Partial<ScreenDeclaration>): ScreenDeclaration`, carrying every mirror field and using only `import type`, so both vitest and `node --test` load it.
  - Replace the eleven literals in the Code Map with calls to it.
- Tests, each with a `mutation:` line in `## Verification`:
  - `ui/tools/screen-mirror.test.mjs`:
    - DW-204: a braced-string descriptor read through `readSources({ descriptorDir })` parses whole.
    - DW-183: a malformed descriptor makes `readSources` throw naming the file. This replaces `:340-391`.
    - DW-165: `BuiltArchetypeKey` emission, from a fixture with one built and one unbuilt archetype.
  - `ui/tools/classic-links.test.mjs`: DW-183 at the gate. `checkClassicLinks({ descriptorDir })` over the malformed descriptor returns a problem naming the `.cls` file.
  - `scripts/test_check_objectscript.py`: a braced string followed by an unknown entity type is still refused, and a `Write` token after a braced string inside XData is not flagged.
  - `command-bar.spec.ts` and `command-box.spec.ts`: both DW-153 matrix rows, through the real `ScreenActions`.
  - `ui/src/app/app.spec.ts` and `ui/browser/shell.browser-spec.mjs`: DW-149. `strings.test.mjs` extracts the literal.
  - `ui/browser/classic-link-card.browser-spec.mjs` (new, needs `npm run build` and no instance) serves DW-180 and DW-185. It renders the card's own inline template, read from `classic-link-card.ts` and never retyped, under the built stylesheet from `dist/ocupilot-ui/browser/`. It measures, then hovers.
  - `ui/tools/design-tokens.test.mjs`: stylesheet pins for the label bound and the 8%/12% state layer.
  - `ui/tools/screen-fixture.test.mjs` (new), for DW-174:
    - It fails when any `src/**/*.spec.ts` or `tools/*.test.mjs` other than the builder contains a `toolIdentifier:` literal.
    - It reports how many files it scanned and requires that count to be non-zero.
    - It asserts that the builder's keys equal the `ScreenDeclaration` field list parsed from `screens.generated.ts`.

**Acceptance Criteria:**
- Given descriptor tooling fed a `Declaration` with a brace inside a JSON string, when `npm run build` and `uv run scripts/check-objectscript.py` run, then both read the whole block and neither truncates nor misreports it.
- Given a descriptor whose XData is valid UDL but invalid JSON, when the prebuild gates read it, then the failure names that `.cls` file.
- Given a `built: true` descriptor whose archetype has no registered page, when `npm run build` runs, then it fails naming the archetype.
- Given a screen whose primary action has no registered handler, when the command bar and command box render, then neither offers the action. Once a handler is registered, both offer it and both run it.
- Given a signed-in keyboard user on any screen, when they press Tab first, then "Skip to content" is focused and visible, and Enter moves focus to `main` without changing the URL.
- Given a classic-link card with a long declared page name, when it lays out in a real browser, then the label stays inside a control-height pill, and hovering the action visibly changes its background.
- Given the client specs, when a field is added to `ScreenDeclaration`, then only `ui/src/app/testing/screen-declaration.ts` changes, and a re-inlined literal fails `npm test`.

## Spec Change Log

## Review Triage Log

### 2026-09-13 — Review pass
- verdicts: 64 findings — high 0, medium 5, low 46, false 11, maybe-false 2
- findings:
  - `[low]` `[reject]` blind: `frameShown` restates the template's nested gate — adjacent in one file, `app.spec.ts` covers the no-frame states; merging the template is more than a correction
  - `[low]` `[reject]` blind: browser spec does not re-assert the clip after Enter — the pre-focus assertion pins the same unfocused rule
  - `[false]` `[reject]` blind: visibility could be hidden under a header painted above z-index 5 — no rule in `_components.scss` exceeds z-index 5
  - `[low]` `[reject]` blind: skip link asserted on Home only — it lives in `App`'s template, independent of route
  - `[low]` `[reject]` blind: `#ocu-content` href misroutes on middle-click or open-in-new-tab — rare for a skip link; fix adds URL tracking
  - `[low]` `[reject]` blind: `.ocu-skip-link` restates `.ocu-button-primary` and has no token pin — the primary class carries `width: 100%`, so reuse needs overrides; declarations equal DESIGN.md's tokens
  - `[low]` `[patch]` blind: 12% pressed layer paints on aria-disabled buttons — added `:active` to the command-bar and fault-banner aria-disabled overrides
  - `[low]` `[defer]` blind: card `+2px` compensates the content-box secondary button — pre-existing shared-rule height mismatch, deferred
  - `[false]` `[reject]` blind: `BuiltArchetypeKey` includes non-page archetypes — the matrix requires failure for any in-vocabulary archetype missing a page
  - `[medium]` `[patch]` blind: no automated pin for the DW-165 compile-time refusal — exported `ARCHETYPE_PAGES`; `screen-outlet.spec.ts` asserts `@ts-expect-error` on a map missing `home` (ng test type-checks specs; mutation recorded)
  - `[low]` `[patch]` blind: `screen-outlet.ts` docstring still says an allowed screen with no page renders nothing — sentence replaced
  - `[low]` `[patch]` blind: `ScreenActions` has no unit test of its own — added `ui/tools/screen-actions.test.mjs`
  - `[maybe-false]` `[defer]` blind: handler registered from a routed page may NG0100 or outlive its page — needs Story 8.1's first routed registration; deferred
  - `[low]` `[reject]` blind: `screen-fixture.test.mjs` forbids a builder override of `toolIdentifier` — the Tasks specify the `toolIdentifier:` literal rule
  - `[low]` `[reject]` blind: guard misses quoted keys, cast partials, browser specs — no such hand-built declaration exists; heuristic is the specified one
  - `[low]` `[patch]` blind: `path !== builderPath` filter never matches — deleted
  - `[low]` `[reject]` blind: builder default `list`/`built: true` conflicts with DW-165 — no spec mounts the outlet with the builder default
  - `[medium]` `[patch]` blind: two brace-rule copies with no parity test — added `test_brace_delta_agrees_with_the_client_mirror_brace_delta`, running the same lines through Node (mutation recorded)
  - `[low]` `[reject]` blind: Python harness does not pin the end-of-line reset — `brace_delta` takes one line, so the reset is structural
  - `[low]` `[patch]` blind: Area-parse test omits the parser message — now asserts the full temp path and the parser message
  - `[low]` `[patch]` blind: `build-output.test.mjs` still says "type role" for app.ts's first class — wording corrected in the name, messages and mutation note
  - `[low]` `[patch]` blind: `command-bar.ts` `generation` comment says router events only — comment corrected
  - `[low]` `[patch]` blind: `shell.browser-spec.mjs` header count and "one real-browser spec" stale — skip link made item 4
  - `[false]` `[reject]` blind: `choose()` returns focus contrary to its docstring — that sentence is scoped to screen navigation; the action path's `close()` predates the story
  - `[low]` `[reject]` blind: hover-vs-card assertion adds nothing to hover-vs-rest — both are the matrix's wording; no harm
  - `[low]` `[reject]` blind: pressed state pinned only by a stylesheet regex — the Tasks put the 8%/12% pin in `design-tokens.test.mjs`
  - `[low]` `[patch]` blind: `dirname` imported on a second line — merged into one import
  - `[false]` `[reject]` blind: spec bookkeeping stale — Auto Run Result is written at finalize; the fix would edit this spec
  - `[false]` `[reject]` blind: `mutation:` lines missing for secondary tests — Rule 19 scopes to one pinning test per AC, and every AC has one
  - `[low]` `[patch]` edge: same function registered twice lets the stale remover delete the newer one — registration token replaces function identity; pinned in `screen-actions.test.mjs`
  - `[low]` `[reject]` edge: handler removed between render and choose closes silently — unregistering bumps and removes the row before a click can reach it
  - `[false]` `[reject]` edge: built `external`/`shell` would force a page — same as the matrix row above; failing is the specified behaviour
  - `[low]` `[patch]` edge: pressed layer on aria-disabled buttons — same fix as the blind row
  - `[low]` `[reject]` edge: middle-click on the skip link — same as the blind row
  - `[low]` `[reject]` edge: skip link overlays a showing fault banner — transient while focused; anchoring to the header is more than a correction
  - `[low]` `[reject]` edge: backslash in an XML attribute is treated as an escape — the spec's rule; needs a brace later on that line
  - `[low]` `[reject]` edge: comment-prefixed XData lines differ between readers — pre-existing; JSON lines cannot start with those prefixes
  - `[low]` `[reject]` edge: Areas JSON with no `areas` array throws unnamed — pre-existing; one project-owned file
  - `[low]` `[reject]` edge: Declaration parsing to null or an array throws unnamed later — pre-existing; no such descriptor
  - `[low]` `[reject]` edge: `buildMirror` refusals name default paths after injection — tests only; production paths are the defaults
  - `[low]` `[reject]` edge: fixture guard flags a builder override — same as the blind row
  - `[low]` `[reject]` edge: shallow spread drops nested fields for untyped callers — no caller passes a partial nested override
  - `[low]` `[reject]` edge: card browser spec reads a stale `dist/` — documented precondition; CI builds first
  - `[maybe-false]` `[defer]` edge: first Tab after in-app sign-in may miss the skip link — needs a browser case that signs in through the form; deferred
  - `[medium]` `[patch]` verification-gap: AC3 refusal survives a weakened annotation — same fix as the blind row
  - `[low]` `[reject]` verification-gap: no browser check of the 12% pressed state — no AC names it; the Tasks pin it in the stylesheet
  - `[low]` `[patch]` verification-gap: disabled row actions show the pressed layer — same fix as the blind row
  - `[low]` `[reject]` verification-gap: `!installUnreadable` in `frameShown` is redundant — mirrors the template's order; no behavioural harm
  - `[low]` `[patch]` verification-gap: Area test cannot tell the temp file from the real `Area.cls` — same fix as the blind row
  - `[medium]` `[patch]` intent: the two brace readers agree by convention only — same fix as the blind row
  - `[low]` `[reject]` intent: Python stray-quote reset not exercised — same as the blind row
  - `[false]` `[reject]` intent: `checkClassicLinks({descriptorDir})` now reads the injected directory — the Tasks require it
  - `[low]` `[patch]` intent: Areas test omits the parser message — same fix as the blind row
  - `[medium]` `[patch]` intent: DW-165 has no automated pin — same fix as the blind row
  - `[false]` `[reject]` intent: uniform reading forces pages for non-page archetypes — the matrix wording is uniform
  - `[false]` `[reject]` intent: no production handler registered — by design; Story 8.1 registers the first
  - `[low]` `[reject]` intent: skip link restates tokens, no hover layer — `.ocu-button-primary` carries no hover layer either
  - `[low]` `[reject]` intent: browser spec does not assert left placement — the header-overlap assertion covers "over the header"
  - `[low]` `[reject]` intent: `frameShown` restates the frame gates — same as the blind row
  - `[false]` `[reject]` intent: card rendered from its template rather than the component — the Tasks and the Never require it
  - `[low]` `[defer]` intent: raw `+ 2px` and 34px outer pill — same root as the deferred shared-rule row
  - `[low]` `[reject]` intent: two hover assertions test one inequality — same as the blind row
  - `[low]` `[reject]` intent: pressed state only as stylesheet text — same as the verification-gap row
  - `[false]` `[reject]` intent: `app.routes.spec.ts` and `classic-link-card.spec.ts` bypass the builder — neither changes when a field is added, which is the AC

## Design Notes

**Governing ADs:**
- AD-5: the archetype picks the page, and adding a screen never edits a router.
- AD-19: `ScreenActions` is framework-free under `core/` and components mirror it. Everything stays `OnPush`.
- AD-44, with the *Screen archetype* convention: archetype rules fail closed.
- Conventions *Angular naming* and *Client asset homes*: tokens only, `strings.ts` canonical, `\uXXXX`.

**Consumes:** the generated mirror (AD-5), EXPERIENCE.md's Landmarks line, and DESIGN.md's button and skip-link tokens.

**Consumed-by:**
- `ScreenActions`: consumed by `command-bar.ts` and `command-box.ts` in this story (Integration AC, the DW-153 matrix rows). Story 2.4's empty state, which "offers the single primary action where one exists", reads the same predicate. Story 8.1 registers the first handler.
- `screenDeclaration()`: consumed by the eleven spec and test files it replaces.
- `BuiltArchetypeKey`: consumed by `screen-outlet.ts`. From Story 2.4 on, a story that sets `built: true` also registers the page.

**Why hide a handler-less action rather than `aria-disabled` it.** `aria-disabled` needs a reason, and no Fixed string publishes one; inventing one is a Never. The shell already leaves a slot it cannot fill unrendered (`command-bar.ts:47-58`, `EXPERIENCE.md:159`). Row actions keep `aria-disabled`, because their reason, "Select a row first", is published.

**Why a compile-time refusal for DW-165.** The prebuild tools run in Node and cannot import an Angular component. So the mirror states which archetypes must have a page, and `tsc` refuses the map, for example `TS2741: Property 'list' is missing`. The misspelling half is already refused by name, and this closes the in-vocabulary half.

**String-aware brace rule.** A `{` or `}` counts only outside a `"…"` span. A backslash inside a span skips the next character, and span state resets at each line end. JSON strings cannot span lines, so the reset cannot miss a JSON brace. The closing brace of a UrlMap or Storage XML block sits on its own line, so a stray quote in XML cannot hide it.

## Verification

**Where each check runs.**
- No instance: `npm run build`, `npm test`, the check-objectscript harness and `classic-link-card.browser-spec.mjs`.
- `shell.browser-spec.mjs` runs on the throwaway: `sh scripts/ci-throwaway.sh up`, then `npm run test:browser`, then `down`. It never runs against the live `ocupilot` container.

**Commands:**
- `cd ui && node tools/screen-mirror.mjs && npm run build` -- expected: prebuild gates green and `ng build` exits 0.
- `cd ui && npm test` -- expected: green, including `screen-fixture.test.mjs`, `strings.test.mjs` and the DW-153 specs.
- `uv run scripts/check-objectscript.py && uv run scripts/test_check_objectscript.py` -- expected: green, with the DW-129 pins unchanged.
- `cd ui && npm run test:browser` after the build and the throwaway `up` -- expected: green, including the skip-link and classic-link-card specs.
- `bash scripts/lint-docs.sh` -- expected: green.

**Planned mutations (Rule 19). Record each `mutation:` line as its pin lands:**
- `extractXData` goes back to a raw brace count, making the DW-204 JS test red. `brace_delta` goes back to `raw.count`, making the Python braced-string test red.
- The `readSources` parse loses its wrapper, making the DW-183 `classic-links.test.mjs` gate test red because no `.cls` appears in the problem.
- `home: HomePage` is removed from `ARCHETYPE_PAGES`, so `npm run build` exits non-zero naming `home`. `BuiltArchetypeKey` includes unbuilt screens, making the emission test red.
- `hasPrimaryAction` ignores `ScreenActions.has`, making the handler-less rows red in both specs. The click no longer calls `run`, making the registered row red.
- The skip link is moved after `app-header`, making the browser first-Tab test red. Its click no longer prevents default, making the unchanged-URL assertion red.
- The label bound is removed, making the browser pill-height and containment assertions red.
- The hover goes back to `surface-container-low`, making the browser hover assertion red.
- A `toolIdentifier:` literal is re-inlined in `command-bar.spec.ts`, making `screen-fixture.test.mjs` red. A builder field is deleted, making its field-list assertion red.

- mutation: both `extractXData` depth sites use a raw `{`/`}` count → `screen-mirror.test.mjs` "a brace inside a JSON string does not end the block" red
- mutation: `brace_delta` returns `line.count("{") - line.count("}")` → `TestStringAwareBraceRule` braced-string, `Write`-token and helper tests red; both `TestDW129SingleLineXDataDisagreement` pins green
- mutation: descriptor parse in `readSources` is a bare `JSON.parse(body)` → `classic-links.test.mjs` "not valid JSON is a refusal naming its .cls file" and `screen-mirror.test.mjs` "valid UDL but invalid JSON" red
- mutation: the `XData Areas` parse in `readSources` is a bare `JSON.parse(areaBody)` → `screen-mirror.test.mjs` "an Area.cls whose XData Areas is ... invalid JSON" red
- mutation: `parseXDataJson` drops `${error.message}` from its throw → `classic-links.test.mjs` "not valid JSON is a refusal naming its .cls file" red at the parser-message assertion
- mutation: `ARCHETYPE_PAGES` is `{}` → `npm run build` exit 1, `TS2322 ... Property 'home' is missing`
- mutation: `ARCHETYPE_PAGES` annotated `Readonly<Record<string, Type<unknown>>>` → `ng test` red on `screen-outlet.spec.ts` "refuses, at compile time, a map with no page for a built archetype" (TS2578 unused `@ts-expect-error`)
- mutation: `braceDelta` stops skipping the character after a backslash → `test_check_objectscript.py` `test_brace_delta_agrees_with_the_client_mirror_brace_delta` red
- mutation: `built === true` dropped from the `BuiltArchetypeKey` filter → `screen-mirror.test.mjs` "BuiltArchetypeKey holds the archetypes of built screens only" red
- mutation: `hasPrimaryAction` returns `true` after the id check and `actionCandidates` lists any non-empty primary id → both handler-less tests and both registered-handler tests red in `command-bar.spec.ts` and `command-box.spec.ts`
- mutation: `run` removed from `onPrimaryAction` and `choose` → the registered-handler test red in each spec, handler-less tests green
- mutation: skip link moved after `<app-header />` (rebuilt, redeployed to the throwaway) → `shell.browser-spec.mjs` skip-link test red, first Tab stop was the header lockup
- mutation: `event.preventDefault()` removed from `onSkipToContent` (rebuilt, redeployed) → same test red on the unchanged-URL assertion, URL gained `#ocu-content`
- mutation: `.ocu-classic-link-card-label` rule removed (rebuilt) → `classic-link-card.browser-spec.mjs` long-page-name test red at the label-inside-pill assertion (label 54.6px tall in a 34px pill, wider than the card)
- mutation: button hover back to `var(--ocu-surface-container-low)` (rebuilt) → `classic-link-card.browser-spec.mjs` hover test red, rest and hover pixels both `243,245,247,255`
- mutation: `const INLINE = { toolIdentifier: 'stub' };` added to `command-bar.spec.ts` → `screen-fixture.test.mjs` "no component spec or tool test builds a ScreenDeclaration by hand" red
- mutation: `emptyStateKey` deleted from the builder → `screen-fixture.test.mjs` field-list test red

## Auto Run Result

Status: done
Blocking condition: none

**Change.** All eight defects closed at their origin: string-aware `braceDelta`/`brace_delta`; `readSources({ descriptorDir, areaSource })` names the `.cls` on a JSON failure; `BuiltArchetypeKey` makes `ARCHETYPE_PAGES` refuse a built archetype with no page; `core/screen-actions.ts` gates and runs the primary action in bar and box; "Skip to content" first in `app.ts`; bounded card label; secondary/text state layer at 8%/12%; `testing/screen-declaration.ts` replaces the eleven literals.

**Files.** Tooling: `ui/tools/screen-mirror.mjs`, `classic-links.mjs`, `scripts/check-objectscript.py`, regenerated `screens.generated.ts`. Client: `app.ts`, `main.ts`, `strings.ts`, `core/screen-actions.ts` (new), `shell/command-bar.ts`, `command-box.ts`, `screen-outlet.ts`, `classic-link-card.ts`, `styles/_components.scss`, `testing/screen-declaration.ts` (new). Tests: `screen-mirror`, `classic-links`, `design-tokens`, `strings`, `build-output`, `refresh`, `refresh-connectivity.wire`, `screen-fixture` (new), `screen-actions` (new) under `ui/tools/`; nine component specs plus `screen-outlet.spec.ts`; `browser/shell.browser-spec.mjs`, `browser/classic-link-card.browser-spec.mjs` (new); `scripts/test_check_objectscript.py`.

**Review.** 64 findings: 12 patched entries (medium 2: DW-165 compile-time pin, JS/Python brace parity; low 10: disabled `:active`, `ScreenActions` registration token and unit test, Area-parse test, four stale comments, dead filter, import), 3 deferred (frontmatter), rest rejected with reasons in the triage log. Lead-side Matrix Test Audit added the `areaSource` seam and the Areas test.

**Follow-up review: true** (2 medium patched). Unverified risk: the new `@ts-expect-error` pin and the Python harness's `node` subprocess have run only on local Node 26.8.1, not on CI's 22.22.3/24.15.0 legs.

**Verification.** `node tools/screen-mirror.mjs && npm run build`: exit 0, all prebuild gates clean. `npm test`: 635/635 tool tests, 199/199 component tests. `check-objectscript.py`: 0 problems over 131 files; harness 49 tests OK. `lint-docs.sh`: 0 issues. `npm run test:browser` on the throwaway: 13/13, throwaway brought down. 17 mutations recorded under `## Verification`, each observed red and reverted.

**Residual risk.** Puppeteer's pinned Chrome fails to launch on this machine, so the browser specs ran with `OCUPILOT_BROWSER_EXECUTABLE` set to the installed Google Chrome.
