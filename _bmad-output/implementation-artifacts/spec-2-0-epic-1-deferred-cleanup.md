---
title: 'Story 2.0: Epic 1 deferred cleanup'
type: 'bugfix'
created: '2026-09-13'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
warnings: ['multiple-goals', 'oversized']
deferred: []
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

## Auto Run Result

Status: ready-for-dev
Blocking condition: none
