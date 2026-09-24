---
title: "Story 15.7: The rail's icons"
type: 'feature'
created: '2026-09-23'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-15-context.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** The rail draws each area's first letter (`rail.ts:112`, `:155`), and Home's area tiles have an empty 24px icon slot (`home.page.ts:370`). UX-DR15 (amended 2026-09-23) needs the icons drawn in the Home mockup. Without them a screenshot looks like a wireframe.

**Approach:** Transcribe the mockup's eight 20×20 rail icons and six 24×24 tile icons verbatim into one framework-free data module. Render them through one small SVG component in `currentColor`, so each rail and tile state keeps the color its existing CSS already sets. Pin the transcription to the mockup with a test. Measure each rail state's rendered stroke against the rail in both themes. Correct DESIGN.md's rail paragraph at its origin.

## Boundaries & Constraints

**Always:**

- The shape data is copied verbatim from `mockups/key-home.html`: every element, every attribute value and the element order. Each root `<svg>` has the mockup's `viewBox`, `fill="none"`, `stroke="currentColor"` and `stroke-width="1.5"`.
  - Rail icons are 20×20. Tile icons are 24×24.
  - The Agent co-pilot's two filled circles keep `fill="currentColor" stroke="none"`.
- Each icon is decorative. The `<svg>` has `aria-hidden="true"` and `focusable="false"`, and no `<title>` or `<desc>`.
  - A rail item's accessible name stays exactly its `aria-label`, which is the area name.
  - A tile's accessible name stays exactly its visible text: the area name, then its caption.
- Every color comes through `currentColor` from the rules that already color `.ocu-rail-glyph` and `.ocu-area-tile-icon`. The story adds no color literal and no theme selector (Conventions › Theme).
- Icons are rendered from data bindings (`[attr.d]` and similar) and never through `innerHTML` or a sanitizer bypass (AD-11 rule 4). Nothing is fetched: no icon font, no CDN, no `<use href>`, no SVG file request (AD-47, NFR-10).
- The icon map is keyed by the registry's area `key` (`screens.generated.ts` `AREAS`). A test derives the roster from `AREAS`, never from a typed list (AD-5).

**Never:**

- No interim Material Symbols glyph anywhere on the rail or the tiles, and no letter or initial in any form.
- Do not touch the other interim-glyph slots (empty states, inline notices, sign-in), `screens.generated.ts`, `structural-baseline.json`, or any existing `_components.scss` rule. The one exception to the last is a comment-only correction noted in the tasks.
- Do not write `deferred-work.md`, `sprint-status.yaml` or the cycle log.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Rail renders | `_SYSTEM`, light | 8 items. Each button's only child is the `aria-hidden` glyph span, holding one 20×20 `<svg>` whose shapes equal the module and the mockup. No text content. | none expected |
| Tiles render | Home | 6 tiles. Each `.ocu-area-tile-icon` holds one 24×24 `<svg>` in `primary`. A gated tile's icon is in `restrained`. | none expected |
| Area without a drawn icon | a key in `AREAS` missing from the map | the slot renders empty, never a letter | `rail-icons.test.mjs` roster check fails and names the key |
| Rail states | rest, hover, active (Home route), attention dot lit (no enabled definition) | The stroke equals the glyph span's computed `color`. Contrast on the rail: rest 6.15/7.31, dot 8.09/10.81, indicator 6.72/8.97 (light/dark). Hover and active are at least 3.0. | none expected |
| Gated item | least-privileged principal (`TurnWireFixture`) | icon at 45% in both themes (3.38/3.70), and **under the pointer as well**, with no hover background | if the pointer raises it, fix it with the appended rule (Tasks) |
| Theme flipped | `THEME_DARK_CLASS` on `<html>` | same shapes, dark-twin colors, figures above | none expected |
| Screen reader | CDP AX tree | rail item name = area label; tile name = its text content; no AX node for any icon `<svg>` | none expected |

</intent-contract>

## Code Map

- `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/mockups/key-home.html`. This is the source and is read-only.
  - Two frames. The rail `.rit` elements are at `:285-292` (light; the gated Security item has no `title`) and `:417-425` (dark). The `.tile` elements are at `:299-327` and `:434-457`, each named by `.nm`.
  - Both frames draw identical shapes (measured). Rail order is `railPosition` 1..8. Tiles cover `logs`, `os-management`, `tasks`, `permissions`, `web-applications` and `security`.
  - The 24px shapes are redrawn, not scaled. Home and Agent co-pilot have no 24px version, and they have no tile.
- `ui/src/app/shell/rail.ts:83-86` — the doc comment about the letter placeholder, which must be replaced. `:112` is the glyph span. `:155` is `initial`, and `:22` declares it.
- `ui/src/app/areas/home/home.page.ts:177-182` — the doc comment calling the glyphs "unpublished". `:370` is the empty `.ocu-area-tile-icon` span. `:470-515` builds the tiles: areas with `!navigates && !pinBottom`, keyed `area.key`.
- `ui/src/styles/_components.scss`. These rules stay as they are and color the icons through `currentColor`:
  - rail: `.ocu-rail-glyph` `:846` (72%), hover `:857`, active `:879`, gated `:890` (45%), `.ocu-rail-dot` `:4449`;
  - tile: `.ocu-area-tile-icon` `:1974` (inline-block 24px, `primary`), gated `:2012`.
  - `.ocu-rail-item:hover .ocu-rail-glyph` (specificity 0,3,0) outranks `.ocu-rail-item-gated .ocu-rail-glyph` (0,2,0), so a hovered gated icon probably turns 100% (inference; the browser check measures it).
- `ui/src/app/core/screens.generated.ts:459+` — `AREAS`, the keys `home, logs, os-management, tasks, permissions, web-applications, security, agent`.
- Tests to extend:
  - `ui/src/app/shell/rail.spec.ts:143-171` (`item.children` length 1 must hold);
  - `ui/src/app/areas/home/home.page.spec.ts:328-337` (icon slot empty, which becomes the svg);
  - `ui/tools/design-tokens.test.mjs:615-618` pins `.ocu-area-tile-icon`'s `display` and `width`. Leave both unchanged.
- Browser precedents:
  - `ui/browser/panel-principal.browser-spec.mjs:40-78` — a least-privileged principal through `OcuPilot.Test.TurnWireFixture` `EnsurePrincipal`/`RemovePrincipals`, which refuses `LIVE_CONTAINER`.
  - `ui/browser/theme.browser-spec.mjs:26-35`, `:243-258` — `parseTokens`, `THEME_DARK_CLASS`, computed-style probes.
  - `ui/browser/rail.browser-spec.mjs` — the dot is lit because the throwaway has no enabled definition.
  - `ui/browser/structural-walk.mjs` — CDP `Accessibility.getPartialAXTree`.
  - `ui/tools/browser-reset.mjs` — each context calls `resetRememberedState()`.
- Contrast figures come from `_tokens.scss` with 8-bit compositing (measured at plan time) and equal DESIGN.md `:813-815`, `:983-986`:
  - rest 6.15 / 7.31;
  - hover 8.32 / 10.44;
  - active 10.35 / 12.85;
  - gated 3.38 / 3.70;
  - dot 8.09 / 10.81;
  - indicator 6.72 / 8.97;
  - tile `primary` on `surface-container-lowest` 9.97 / 10.69;
  - tile `restrained` 6.55 / 9.64.
- DESIGN.md: `:954` is the section intro's interim-glyph sentence, and `:975` is the ``#### `rail` `` paragraph. EXPERIENCE.md `:472` is the rail row, "Placeholder icons until the owner's icon work lands".
- `ui/angular.json:54` has `maximumWarning` `1378kB`, and `ui/tools/angular-json.test.mjs:371` pins it.

## Tasks & Acceptance

**Execution:**

- `ui/src/app/shell/rail-icons.ts` (new, framework-free, no Angular import) — the data module.
  - Exports `AREA_ICON_STROKE_WIDTH = '1.5'`.
  - Exports `AREA_ICONS: Readonly<Record<string, { rail: readonly IconShape[]; tile?: readonly IconShape[] }>>`, where `IconShape = { tag: 'path' | 'circle' | 'rect'; attrs: Readonly<Record<string, string>> }`. Attribute values are the mockup's strings, verbatim and in order.
  - Exports `areaIcon(key, size: 20 | 24)`, which returns the shapes or `null`.
- `ui/src/app/shell/rail-icon.ts` (new) — a standalone `OnPush` component on the `svg[ocuAreaIcon]` selector with inputs for the area key and `size`.
  - Host bindings set `viewBox`, `width`, `height`, `fill="none"`, `stroke="currentColor"`, `stroke-width`, `aria-hidden="true"` and `focusable="false"`.
  - The template loops over the shapes with `@switch` on `tag` and binds each attribute (`[attr.d]`, `[attr.cx]`, and so on). A null lookup renders no children.
- `ui/src/app/shell/rail.ts` — Remove `initial`, and render `<svg [ocuAreaIcon]="item.key" [size]="20">` inside the existing `aria-hidden` `.ocu-rail-glyph` span. Rewrite the `:83-86` comment.
- `ui/src/app/areas/home/home.page.ts` — Render `<svg [ocuAreaIcon]="tile.key" [size]="24">` inside `.ocu-area-tile-icon`, and rewrite the `:177-182` comment.
- `ui/src/styles/_components.scss` — Append one `// --- Area icons (Story 15.7)` block at the file's tail, holding:
  - `.ocu-rail-glyph > svg, .ocu-area-tile-icon > svg { display: block; }`, which removes the inline baseline gap so nothing overflows the 24px slot;
  - only if the gated-hover measurement fails, `.ocu-rail-item-gated:hover .ocu-rail-glyph { color: color-mix(in srgb, var(--ocu-on-shell) 45%, transparent); }`.
  
  Also make a comment-only edit to the `.ocu-area-tile-icon` block's stale "unpublished" sentence.
- `ui/src/app/shell/rail.spec.ts`, `ui/src/app/areas/home/home.page.spec.ts` — Assert, per item and tile:
  - one `<svg>` with the right `viewBox`, `aria-hidden` and `focusable`;
  - no `<title>`;
  - child elements equal to `areaIcon(key, size)`;
  - no text content in the button's glyph.
  - For tiles, also assert the accessible name equals the text content.
- `ui/tools/rail-icons.test.mjs` (new) — Fidelity and roster checks:
  - Parse the mockup's rail and tile SVGs with a regex.
  - Assert both frames agree.
  - Map rail icons by position to `AREAS` in `railPosition` order, checked against `title` where present. Map tiles by `.nm` to `stringFor(labelKey)`.
  - Deep-equal against `AREA_ICONS`, including each root's `viewBox`, `fill`, `stroke` and `stroke-width`.
  - Roster: `AREA_ICONS` keys equal `AREAS` keys, and each tile area (`!navigates && !pinBottom`) has a `tile` entry.
  - Assert DESIGN.md's ``#### `rail` `` paragraph names `mockups/key-home.html` and does not contain "Material Symbols".
- `ui/browser/rail-icons.browser-spec.mjs` (new) — Runs against the deployed bundle, with `resetRememberedState()` before each context and `after` removing the principal.
  - **(a) `_SYSTEM` at 1280.** Every rail item and tile renders the module's shapes, and CDP AX names match the matrix. The page makes no request to another origin.
  - **(b) Rail states.** For rest, hover (`page.hover`), active (Home) and the dot, in light and then with `THEME_DARK_CLASS` added to `<html>`:
    - the svg's computed `stroke` equals the glyph span's `color`;
    - compute the WCAG ratio after compositing over the item background and then the rail background;
    - assert the recorded figures within ±0.05, and at least 3.0 for hover and active.
    - The tile icon `stroke` equals `primary` in both themes.
  - **(c) Least-privileged principal.** Assert that at least one rail item is gated and one tile is gated. Then check the gated icon at 45% at rest and under the pointer in both themes, and the gated tile icon equal to `restrained`.
  
  Expected colors come from `parseTokens`, never retyped.
- `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/DESIGN.md` — Tier-1 amendment:
  - `:975` "The icons are the owner's; the interim set is one Material Symbols glyph per area (see the section intro)." becomes "The icons are the eight drawn in `mockups/key-home.html` (Home's `area-tile`s carry the same six at 24px): inline SVG, 1.5 stroke in `currentColor`, decorative. [AMENDED 2026-09-24, Story 15.7, UX-DR15: was "the interim set is one Material Symbols glyph per area"]".
  - `:954`'s intro sentence is narrowed to "every slot other than the rail and Home's area tiles", with the same marker.
- `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md:472` — Replace "Placeholder icons until the owner's icon work lands" with "The icons drawn in DESIGN.md's `mockups/key-home.html`, decorative (`aria-hidden`)" and the same `[AMENDED 2026-09-24, Story 15.7]` marker.
- `ui/angular.json:54`, `ui/tools/angular-json.test.mjs:371` — **Conditional:** only if the initial bundle exceeds 1378kB. Apply DW-1166: set the budget about 5% above the measured total (1 kB = 1,000 B) and change only those two literals.

**Acceptance Criteria:**

- **AC1.** Given the rail's eight items, when they render, then each shows its area's mockup icon as inline SVG (20×20 view box, 1.5 stroke, `currentColor`), and no letter remains.
- **AC2.** Given Home's six area tiles, when they render, then each carries the 24px version of its area's mockup icon.
- **AC3.** Given each rail state (rest, hover, active, gated at rest and under the pointer, and the attention dot), in light and in dark, when it applies, then the icon's stroke is the state's color through `currentColor`, at the contrast figures in the matrix, and never below 3.0.
- **AC4.** Given a screen reader on a rail item or a tile, when it announces, then it hears the area name (the tile also hears its caption) and nothing from the icon. Nothing loads from outside the bundle.
- **AC5.** Given DESIGN.md's rail paragraph, when this story completes, then it names the mockup's icons with the amendment marker, and the other interim-glyph slots are unchanged.
- **AC6 (gate).** Given `a11y-structural-invariants.browser-spec.mjs`, when it walks the rail and Home in both themes, then it reports zero fresh and zero stale keys. `structural-baseline.json` is not edited.
- **Integration AC (Rule 1).** Given the deployed bundle, when `_SYSTEM` opens Home, then the rail and the tiles, which are both consumers of `rail-icons.ts`, draw the module's shapes for each area key. Each rail item's accessible name is its area name, and each tile's is its visible text.

## Spec Change Log

- 2026-09-24, lead spec gate: smoke runs on the throwaway, not slot B's bundle-less dev instance. No intent change.

## Review Triage Log

## Design Notes

**Governing ADs (Rule 6):**

- AD-11 rule 4: bound attributes, no markup rendering, no host request.
- AD-47 and NFR-10: vendored, nothing fetched.
- AD-19: `rail-icons.ts` is framework-free, so `node --test` imports it, and the component is `OnPush`.
- AD-5: the roster is keyed by the registry's area key.
- Conventions: *Angular naming* (tokens only), *Client asset homes*, *Theme* (bare roles, no theme selector).

No AC contradicts an AD.

**Why a data module plus one component.** A node test can read the data to pin it against the mockup, and two consumers can import one source. The component works on the `svg` host. Its template elements must be written as `svg:path`, `svg:circle` and `svg:rect`, because the template root is not inside a literal `<svg>` and Angular would otherwise create HTML elements that draw nothing. The component test catches this, since jsdom reports `namespaceURI`, so assert `http://www.w3.org/2000/svg`. That URI is on client-lint's allowlist.

**Accessible name on tiles.** The dispatch shorthand says "the area name only". The epics AC says a reader "hears the area name and nothing from the icon". A tile's name was already its area name followed by its caption (`home.page.ts:180-182`), so the invariant tested is "unchanged by the icon".

**Why the gate should stay green.** The svg is not interactive and holds no text, and `display: block` keeps it inside its slot. So no name, min-width, contrast or overflow key is expected (inference; the gate run is the evidence).

**Footprint (Rule 11).**

- **Exclusive:** `shell/rail.ts`, `rail.spec.ts`, and the new `shell/rail-icons.ts` and `shell/rail-icon.ts`; `areas/home/**`.
- **Shared-append:** `_components.scss` (tail block, plus a comment-only edit).
- **AC:** DESIGN.md.
- **`footprint_extensions:`** No contended epic declares these:
  - EXPERIENCE.md `:472` (component table, not Fixed strings);
  - `ui/tools/rail-icons.test.mjs` (new; its name is unique inside Epic 9's `ui/tools/**`);
  - `ui/browser/rail-icons.browser-spec.mjs` (new, shared-create).
- **Conditional (DW-1166):** `ui/angular.json`, `ui/tools/angular-json.test.mjs`.
- No strings are added.

**Consumes:** 15.6's theme (`THEME_DARK_CLASS`, dark scope), the DW-1337 gate and its baseline, `TurnWireFixture`'s principal, `preferences-reset.mjs`.

**Consumed-by:** the rail and Home in this story. No later story is known. The other interim-glyph slots are a separate decision (UX-DR15).

**Ledger inbox (Rule 17):** `LEDGER slice 15-7-the-rail-s-icons` is empty.

## Verification

**Slot B.** Browser runs:

1. `cd ui && npm run build`.
2. `docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/` on the throwaway, started with `bash scripts/ci-throwaway.sh up --dir /tmp/ocupilot-b-ci --project ocupilot-b-ci --web 52777 --super 1976`. It is torn down only by whoever ran its `up`.
3. Export `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777` and `OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci`.

No ObjectScript changes, so there is no class run and no full ObjectScript sweep.

**Commands:**

- `(loop)` `cd ui && npm run test:tools` — green, including `rail-icons`, `design-tokens`, `strings`, `browser-reset` and `angular-json`.
- `(loop)` `cd ui && npm run test:components` — green, including `rail.spec.ts`, `rail-wire.spec.ts` and `home.page.spec.ts`.
- `(loop)` `cd ui && npm run build` — the seven prebuild checkers pass. Quote the initial bundle total.
- `(loop)` `cd ui && node --test --test-concurrency=1 browser/rail-icons.browser-spec.mjs browser/a11y-structural-invariants.browser-spec.mjs browser/theme.browser-spec.mjs browser/rail.browser-spec.mjs` — green. The gate prints 0 fresh and 0 stale.
- `(loop)` `bash scripts/lint-docs.sh` — green over DESIGN.md and EXPERIENCE.md.
- `(once, before dev_complete)` `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS` on the throwaway (slot B's dev instance serves no bundle, so its `shell` and `deeplink` checks fail there by environment) — more than 0 checks, all pass. (lead edit at spec gate) The full browser suite is not run locally (Rule 29); CI discovers the new spec by glob.

**Mutations (Rule 19).** Apply each one, observe red, revert, and confirm the tree is byte-identical. Rebuild and redeploy before any browser read.

- AC1: change one coordinate in `AREA_ICONS.logs.rail` → the `rail-icons.test.mjs` fidelity check goes red. Restore the letter span in `rail.ts` → the `rail.spec.ts` no-text check goes red.
- AC1/AC2 render: drop the `circle` case from `rail-icon.ts` → the `rail.spec.ts` Tasks/Agent shape check goes red. Tiles pass `[size]="20"` → the `home.page.spec.ts` viewBox check goes red.
- AC3: bind the host `stroke` to `var(--ocu-on-shell)` instead of `currentColor` → the browser spec's rest-state `stroke == color` and 6.15 checks go red. Remove the gated-hover rule (if added) → the gated-under-pointer case goes red.
- AC4: add `<svg:title>` holding the area name → the tile AX-name check and the unit no-title check go red. Add `<svg:use href="https://example.invalid/i.svg#x">` → client-lint `no-off-origin-url` fails the build.
- AC5: restore the "Material Symbols" sentence → the `rail-icons.test.mjs` DESIGN check goes red.
- AC6: set the tile svg to `width: 40px` → the gate goes red with a fresh `overflow` key on `/`.
- Integration AC: look up icons by label instead of key → the browser spec's shape check goes red for every item.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none
