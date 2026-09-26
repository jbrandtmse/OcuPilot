---
title: 'Story 15.10: The header logo on a white tile'
type: 'feature'
created: '2026-09-25'
status: 'done'
baseline_revision: '04fbb667e8103126549047457cdedf1c0fcc1431'
baseline_commit: '04fbb667e8103126549047457cdedf1c0fcc1431'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-15-context.md'
warnings: ['oversized']
deferred:
  - summary: >-
      The DW-1337 structural gate reports a varying set of stale 720px status-bar stamp entries run to run.
    evidence: |-
      Three runs on ocupilot-b-ci with an unchanged bundle: 223/223 0 stale, then 219 found 4 stale, then 222 found 1 stale; every stale key is overflow|720|...ocu-status-bar-stamp on a different screen. The stamp's presence is timing-dependent (inference); the status bar is outside this story. 0 fresh in every run.
    location: >-
      ui/browser/structural-baseline.json (ocu-status-bar-stamp rows)
    severity: low
---

<intent-contract>

## Intent

**Problem:** The header draws the reversed lockup, a white wordmark on a transparent cut-out whose anti-aliased edges fringe against the navy chrome. It is the first thing a judge sees, and it looks unfinished.

**Approach:** Draw the navy-wordmark lockup `OcuPilot-Lockup-horizontal.png`, the file the sign-in card already uses, on a white rounded tile with even padding inside the 48px band. The tile is identical in both themes, and the link, its focus ring and its accessible name keep working. Then correct DESIGN.md, EXPERIENCE.md and `header.ts` at origin, and delete the vendored reversed file, which nothing in the shipped client draws any more.

## Boundaries & Constraints

**Always:**

- **The tile is the anchor itself.** `.ocu-header-lockup` (the existing empty `<a>`) carries the tile: `box-sizing: border-box`, 144×36px, `padding: var(--ocu-space-1)` (4px) on all four sides, `border-radius: var(--ocu-radius-md)`, `background-color: var(--ocu-logo-tile)`, and the navy file as `background-image` with `background-origin: content-box`, `background-size: contain`, `background-position: center`, no repeat. The lockup is drawn 28px tall in the 136×28 content box (the source is 623×128; the ink reaches every edge of the file, so the CSS padding is the whole margin). The tile is centered vertically in the band (6px above and below) and stays 8px from the left edge. At 720px the header's left column is 154px wide (inference, from the grid arithmetic `(720 - 20 - 360 - 32) / 2`), so the 144px tile fits; the browser spec measures it.
- **The tile color is a fixed non-role token.** Add `--ocu-logo-tile: #ffffff;` to `_tokens.scss`'s non-role block with **no `-dark` side**. Register it in `NON_ROLE_TOKENS` as `'logo-tile': { hasDark: false }`, so `_theme.scss` never re-points it and it stays out of the 64-role count. It is not `surface-container-lowest`, which turns `#0B0E10` in dark, and it is not `on-primary` or any other role that `ocu-theme-dark` re-points. Its hex is transcribed from DESIGN.md's `logo-lockup` frontmatter `plate` value (below). No literal color appears outside `_tokens.scss` (client-lint).
- **Focus and link are unchanged in behavior.** The existing `.ocu-header-lockup:focus-visible` rule stays: a 2px `focus-ring-dark` outline at offset 2px outside a 2px `shell` halo. It is on the tile's own element, so the ring surrounds the tile and reaches no closer than 2px to the band's edges. The `href` (Home plus `?ns=`), the click handler and `aria-label="{{ STRINGS.headerHomeLink }}"` do not change, and neither does the value `'OcuPilot — Home'`.
- **Asset.** The CSS `url()` is what brings a file into the bundle; `angular.json`'s `assets` copies only the font licences. Once the header rule stops naming the reversed file, delete `ui/src/assets/lockup/OcuPilot-Lockup-horizontal-reversed.png`. The UX folder's `imports/` original stays as the design record. After the change, `grep -rn "Lockup-horizontal-reversed" ui/ src/ scripts/ module.xml` returns nothing except the new test's own negative assertions.
- **Docs are corrected at origin, in place, with no change in line count.** Each edited line keeps its position, and a wrong sentence is replaced, never appended to. Each edited prose line or table row carries `[AMENDED 2026-09-26, Story 15.10]` (Story 15.9's format). In the frontmatter the marker goes inside the quoted `plate:` value only, as DESIGN.md `:305-307` do.
  - EXPERIENCE.md: edit **only** line 534 (the `logo-lockup` row). Leave the frontmatter asset list (`:24-25`) as it is. `strings.ts` carries `/** EXPERIENCE.md:n */` citations, and Epic 11 edits this file concurrently.
  - The row keeps the exact text `Click navigates to Home. Accessible name "OcuPilot — Home".`, which `ui/tools/strings.test.mjs:113` resolves.
- **Shared-append files** (`_components.scss`, `strings.ts` and EXPERIENCE.md, which Epic 11's branch also edits):
  - `_components.scss`: only the `.ocu-header-lockup` rule and the comment above it (`:1106-1120`).
  - `strings.ts`: only the comment at `:1064`.
  - EXPERIENCE.md: only `:534`.
  - Nothing else is reordered or reflowed.

**Never:**

- No change to the sign-in card's `.ocu-signin-lockup` rule or its comment (`_components.scss:134-148`), the header grid, the command box, `.ocu-header-end`, or the account menu.
- No new user-facing string, no `<img>`, and no hover state on the tile.
- No ObjectScript change, no `angular.json` change, no DW-1337 baseline entry added.
- Do not re-point the tile in `_theme.scss`, and never select on `ocu-theme-dark` in a component.
- Do not write `deferred-work.md`, `sprint-status.yaml` or the cycle log.
- Never stop, `down` or recreate `ocupilot`, `ocupilot-slot-b`, `ocupilot-slot-c` or `ocupilot-ci`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Light, 1280 | signed in, Home | `.ocu-header-lockup`: `background-color` `rgb(255, 255, 255)`. Its `background-image` URL equals the sign-in card's `.ocu-signin-lockup` URL (read before sign-in), contains no `reversed`, and answers 200 `image/png`. Padding is 4px on all four sides, `border-radius` is above 0, and the box is 144×36, inside the header's box. | none |
| Dark, 1280 | `THEME_DARK_CLASS` on `<html>` | same computed tile color, padding, radius and box. The tile's pixels (a screenshot clipped to its box inset by the radius) equal the light ones. | none |
| Narrow, 720 | light | the tile is inside the header's box and does not intersect `app-command-box`'s box | none |
| Keyboard focus | Shift, then focus the lockup | `:focus-visible`; outline solid 2px in `rgb(focus-ring-dark)`, `outline-offset` ≥ 0 on the tile element; the ring's outer box (tile ± 4px) is inside the header's box | none |
| Link | click the tile from `permissions/users?ns=HSCUSTOM` | lands on Home with `?ns=HSCUSTOM`; the accessible name is `STRINGS.headerHomeLink` | none |

</intent-contract>

## Code Map

- `ui/src/styles/_components.scss`:
  - `:1106-1120`: the comment ("The reversed lockup at 32px, directly on the shell: no plate") and the `.ocu-header-lockup` rule to rewrite.
  - `:1122-1126`: the focus rule, unchanged.
  - `:134-148`: `.ocu-signin-lockup`, the reference treatment. Read only.
  - `:1089-1104`: the header grid is `minmax(0, 1fr) auto minmax(0, 1fr)` with padding `0 space-3 0 space-2`.
- `ui/src/styles/_tokens.scss`:
  - `:18-35`: the header comment says "Four more families". Add the tile token and make it five.
  - `:190-192`: the non-role block. Put `--ocu-logo-tile` beside `--ocu-logo-gradient-stop`.
- `ui/tools/design-tokens.mjs:89-108`: `NON_ROLE_TOKENS` and its doc comment.
- `ui/tools/design-tokens.test.mjs`:
  - `:77-110`: the declared-set test. It picks up the new key automatically.
  - `:145-149`: the `logo-gradient-stop` test, the precedent for a tile-token test.
  - `:509-524`: "the lockup on the chrome is the reversed file", which is inverted.
- `ui/src/app/shell/header.ts`: the doc comment at `:22` and `:34-39` says "reversed lockup … No plate". The template (`:59-64`) is unchanged.
- `ui/src/app/shell/header.spec.ts:25`: a comment says "the 32px lockup". The jsdom cases at `:227-290` (link, name, `?ns=`) stay green unchanged.
- `ui/src/app/core/strings.ts:1064`: the comment cites the phrase EXPERIENCE.md "`imports/OcuPilot-Lockup-horizontal-reversed.png` — the mark". `ui/tools/citations.test.mjs` fails once row 534 changes, so re-cite a phrase copied verbatim from the new row.
- `ui/tools/build-output.test.mjs:260-285`: asserts that a hashed `OcuPilot-Lockup-horizontal-<HASH>.png` is emitted and referenced by the CSS. It stays green; the header and the card now share that one file.
- `ui/angular.json:26-32`: `assets` holds only `*-OFL.txt`. `module.xml:55` copies the built `dist` tree, so deleting the PNG removes it from the package.
- Browser patterns to reuse:
  - `ui/browser/account-and-filter.browser-spec.mjs:47-80`: the `before` refusal of `LIVE_CONTAINER`, readiness, and `signedInAt` with `resetRememberedState`.
  - `ui/browser/theme.browser-spec.mjs:17-37`: `THEME_DARK_CLASS` from `core/theme.ts`, and expected colors from `parseTokens(_tokens.scss)`, never retyped.
  - `:243-258` there: focus-visible through Shift plus `page.focus`.
  - `ui/browser/structural-walk.mjs:62-65`: `VIEWPORTS` wide 1280, narrow 720.
- DESIGN.md (`_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/`). The lines that name the reversed file as the header's:
  - frontmatter `logo-lockup`: `:280` `asset`, `:282` `asset-light-ground`, `:284` `height: 32px`, `:286` `plate: none`;
  - `:709` the brand paragraph;
  - `:721` the preview row ("as the header renders it");
  - `:722-723` the two lockup rows;
  - `:1012` the `logo-lockup` prose;
  - `:1014` Variants ("the light file never appears on the chrome");
  - `:1265` the Do's and Don'ts row, which forbids a white plate and the navy file on the chrome.
- EXPERIENCE.md `:534`: the `logo-lockup` row.
- `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/.memlog.md:75`: the decision that the header uses the reversed file. Supersede it by appending; never edit a memlog line.

## Tasks & Acceptance

**Execution:**

- `ui/src/styles/_tokens.scss`, `ui/tools/design-tokens.mjs`: add `--ocu-logo-tile` per Always and register it (`hasDark: false`). Update both header comments with one line each: a fixed white that the dark scope never re-points.
- `ui/src/styles/_components.scss`: rewrite the `.ocu-header-lockup` rule and its comment per Always. The comment covers the navy file on a white tile, the same in both modes, and why the `url()` (not `<img>`) keeps the file a build input. Report this as a `footprint_extensions:` in-place edit.
- `ui/src/assets/lockup/OcuPilot-Lockup-horizontal-reversed.png`: delete it (`git rm`), after the grep in Always shows the header rule was its last reference.
- `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/DESIGN.md`: correct each Code Map line in place, one line for one line (a `wc -l` before and after must be equal). The new wording:
  - `asset`: the navy file.
  - `asset-light-ground` becomes `asset-reversed`: the reversed file, "a design asset, not drawn in the product".
  - `height: 28px`.
  - `plate: '#FFFFFF tile in both modes, {rounded.md}, {spacing.1} padding on every side, 36px tall'`.
  - The prose: the navy lockup on a white rounded tile with even padding, identical in light and dark, and the focus ring around the tile. The mark-only variant goes on the same tile at 28px. The reversed file is not drawn in the product.
  - The Do and Don't cells: do use the navy lockup on its white tile in the header; don't put the navy file on the chrome without its tile, draw the reversed file, or let the tile follow the theme.
- `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md:534`: rewrite the row on its one line.
  - Name `imports/OcuPilot-Lockup-horizontal.png` on a white rounded tile with even padding, the same in light and dark, with the focus ring around the tile.
  - Keep "Click navigates to Home. Accessible name "OcuPilot — Home"." verbatim.
  - End with `→ imports/OcuPilot-Lockup-horizontal.png — the header lockup`.
  - `wc -l` must be unchanged.
- UX `.memlog.md`: `uv run --no-cache _bmad/scripts/memlog.py append --workspace _bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08 --type decision --text "Story 15.10: header lockup is the navy-wordmark file on a fixed white rounded tile (both themes); supersedes the reversed-file-on-the-shell decision"`.
- `ui/src/app/core/strings.ts:1064`: re-cite a phrase from the new row 534. This is a one-line comment edit; the value does not change.
- `ui/src/app/shell/header.ts`: correct the doc comment at `:22` and `:34-39` to state the tile. `ui/src/app/shell/header.spec.ts:25`: one comment word.
- `ui/tools/design-tokens.test.mjs`:
  - Replace the `:509` test with "the header lockup is the navy-wordmark file on the white tile". The rule names `OcuPilot-Lockup-horizontal.png` and not `reversed`. It draws `background-color: var(--ocu-logo-tile)`, `border-radius: var(--ocu-radius-`, one `padding: var(--ocu-space-1)` value and `background-origin: content-box`. `ui/src/assets/lockup/` holds no reversed file. Keep the sign-in half.
  - Add a tile-token test: `tokens.light['logo-tile']` is `#ffffff`, it has no dark side, it is not a role, and it equals the hex in DESIGN.md's `logo-lockup` `plate:` frontmatter line. The same block's `asset:` names `imports/OcuPilot-Lockup-horizontal.png`.
- `ui/browser/header-lockup.browser-spec.mjs` (new):
  - The header says what it pins and that it refuses `LIVE_CONTAINER`.
  - One context via `signedInAt`, with `resetRememberedState` before it. Read `.ocu-signin-lockup`'s computed `background-image` URL while signed out.
  - It covers every Matrix row: light and dark at 1280 (dark toggled by adding and removing `THEME_DARK_CLASS`, then blurring focus before any screenshot), light at 720, Keyboard focus, and Link.
  - Tile equality: compare the `page.screenshot({clip})` buffers of the tile inset by 6px on every side, light against dark.

**Acceptance Criteria:**

- **AC1.** Given the header, when it renders, then the lockup is the navy-wordmark file `OcuPilot-Lockup-horizontal.png`, the same file the sign-in card draws, on a white tile with rounded corners and even padding that sits inside the header band at 1280 and 720px. The reversed file is not drawn in the header and is no longer in the bundle.
- **AC2.** Given the light and the dark theme, when the header renders in each, then the tile's computed color, box, padding and radius are identical, and its pixels inside the radius are identical.
- **AC3.** Given keyboard focus on the logo link, when it is focused, then the on-chrome focus ring surrounds the tile inside the band, and the link still goes Home with `?ns=` under the accessible name `STRINGS.headerHomeLink`.
- **AC4.** Given DESIGN.md's `logo-lockup` frontmatter, prose, references rows and Do's and Don'ts row, EXPERIENCE.md's `logo-lockup` row and `header.ts`'s doc comment, when this story completes, then each states the navy lockup on the white tile at origin with the `[AMENDED 2026-09-26, Story 15.10]` marker, and both documents keep their line counts. `lint-docs`, `citations.test`, `strings.test` and `design-tokens.test` are green, and `header-lockup.browser-spec.mjs` pins AC1-AC3.

### Review Findings

Code review 2026-09-26, four layers (blind, edge-case, verification-gap, acceptance), 28 rows, 10 entries after grouping, 0 decision-needed.

- [x] [Review][Patch] (med, fix-risk low, in-story) AC2's "the dark theme is on screen" read back the class the test had just set, so it could not fail [ui/browser/header-lockup.browser-spec.mjs:213] — now asserts the page ground is `surface-dark`; mutation recorded.
- [x] [Review][Patch] (med, fix-risk low, in-story) DESIGN.md's Reference-only row still said `Logo-web.png` is "superseded in the header by the reversed lockup", an AC4 references row [DESIGN.md:727] — corrected in place with the marker; line count unchanged.
- [x] [Review][Patch] (low, fix-risk low, in-story) the "no longer vendored" assertion was never seen red on its own [ui/tools/design-tokens.test.mjs:543] — mutation recorded.
- [x] [Review][Patch] (low, fix-risk low, in-story) the mark-only threshold "about 170px" contradicted "none at supported widths" (the 720px column is 154px) [DESIGN.md:1014] — now "narrower than the tile's 144px".
- [x] [Review][Patch] (low, fix-risk low, in-story) row 534 said the navy file "serves ... the README"; `README.md:4` draws `logo/OcuPilot-Logo-web.png` [EXPERIENCE.md:534] — "and the README" deleted; citation phrase unaffected.
- [x] [Review][Patch] (low, fix-risk low, in-story) `header.spec.ts` header comment did not name the new browser spec [ui/src/app/shell/header.spec.ts:27] — names it.
- [x] [Review][Defer] (low, maybe-false) forced-colors now forces the tile to Canvas while the `url()` image may survive, putting the navy wordmark on a dark Canvas [ui/src/styles/_components.scss:1113] — occurrence appended to DW-151 (terminal, same root cause); settle with a forced-colors render.
- [x] [Review][Defer] (low, out-of-footprint) `epics.md` UX-DR14 (:395) and Story 1.10's AC (:1384) still name the reversed lockup at 32px — DW-1683 `wontfix-accepted`, reopen_if a plan stage cites that wording; a Rule 5 tier-1 amendment for the lead (contended file).
- [x] [Review][Defer] (low, spec-bound) `_components.scss:22`'s file-header list still says "the lockup's 32x156px" — `by-design`: the spec confines this shared-append file to the lockup rule and its comment; correct after Epic 11 merges.
- [x] [Review][Defer] (low) below 720px (e.g. 1280 at 200% zoom) the 144px tile overflows its column into the command box — `wontfix-accepted`, pre-existing (the old 156px lockup was wider) and below the tested 720 floor; reopen_if a sub-720 viewport joins `structural-walk.mjs` `VIEWPORTS`.

Rejected:

- Auto Run Result tally differs from the Triage Log — the fix edits the spec's build-auto record, not code.
- DW-1337 stale variance called pre-existing — already filed as an occurrence on DW-1584.
- `browser.config.mjs` falls back to slot A silently — already logged by the lead as a protocol violation.
- The spec header "refuses the live container" overclaims — `false`: it refuses `LIVE_CONTAINER`, exactly as stated.
- The frontmatter omits the tile width; the stylesheet test drops size and exact radius; padding longhands escape the regex — the `plate:` wording and the stylesheet assertions are spec-prescribed, and the browser spec pins the computed 144×36 box and all four paddings.
- Focus ring, 720 leg and drawn size are checked in light only — the matrix prescribes light, the focus rule is theme-independent, and AC2's pixel comparison covers a dark-only drawing change.
- The `build-output` assertion sits under the sign-in test's title — cosmetic; its message names the reversed file.
- `[AMENDED 2026-09-26]` postdates the memlog — `false`: the spec prescribes it and it is the UTC date.
- The mark-only variant's tile size is unstated — no Release 1 surface draws it.

## Spec Change Log

## Review Triage Log

### 2026-09-26 — Review pass

- verdicts: 16 findings — high 0, medium 3, low 7, false 6, maybe-false 0
- findings:
  - `[medium]` `[patch]` verification-gap: `background-size`/`-position`/`-origin` unasserted, so a cropped or offset lockup stays green — `tileFigures` now reads them and AC1 asserts `contain`, `50% 50%`, `content-box`, `no-repeat`; mutation recorded.
  - `[medium]` `[patch]` verification-gap: AC2's pixel equality never seen red and true for two blank tiles — AC2 now asserts the light tile differs from the same tile with its image switched off (CSSOM override; the CSP refuses a `<style>` tag); dark-only `filter` mutation reddens the pixel assertion alone.
  - `[low]` `[patch]` verification-gap: the 720 leg has no mutation line — `width: 200px` mutation demonstrated and recorded.
  - `[low]` `[patch]` verification-gap: "no longer in the bundle" checked only in the source folder — `build-output.test.mjs` now asserts no `reversed` file in `media/`; mutation recorded.
  - `[low]` `[patch]` verification-gap (other): `header.spec.ts:234` comment still says "No plate, no ground" — rewritten to name the tile.
  - `[false]` `[reject]` verification-gap (other): the new browser spec is untracked — finalize stages it by path; not a defect in the change.
  - `[medium]` `[patch]` intent-alignment: no test shows the navy lockup is actually painted — same root as the AC2 ink row; the ink assertion closes it.
  - `[low]` `[patch]` intent-alignment: "8px from the left edge" and the drawn size unmeasured — AC1 now asserts the 8px offset; the drawn size is pinned by `contain` in the content box (the width-limited 27.94px against the stated 28px is sub-pixel).
  - `[false]` `[reject]` intent-alignment: the 154px column is not measured — the intent's claim is that the tile fits, which the 720 leg measures (containment and no intersection).
  - `[low]` `[reject]` intent-alignment: the halo and exact 2px offset are not pinned — the focus rule is unchanged by this story and the matrix asks for offset ≥ 0; adding assertions on untouched CSS is not worth it.
  - `[false]` `[reject]` intent-alignment: the name is read from `aria-label`, not the computed name — on an anchor with no content and no `aria-labelledby` the attribute is the computed name.
  - `[low]` `[reject]` intent-alignment: `PIXEL_INSET` 6 is hard-coded rather than read from `--ocu-radius-md` — a radius change only widens what is compared; not worth a token read in the spec.
  - `[false]` `[reject]` intent-alignment: DESIGN.md adds rules (mark-only variant on the tile, new Do/Don't cells) — the spec's Tasks prescribe exactly these wordings.
  - `[false]` `[reject]` intent-alignment: `asset-light-ground` reused as `asset-reversed` — the spec's Tasks prescribe the rename.
  - `[false]` `[reject]` intent-alignment: DESIGN.md frontmatter asset list still lists the reversed files — they remain design assets in `imports/`, so the list is accurate.
  - `[low]` `[patch]` intent-alignment: EXPERIENCE.md row 534 lost its closing full stop — restored (line count unchanged); the mid-row marker follows Story 15.9's rows.

## Design Notes

**Governing ADs and conventions (Rule 6):**

- AD-47 and NFR-10: the file is vendored and same-origin, never a CDN.
- AD-19: no component state or code change beyond a doc comment.
- Conventions › Theme: bare roles, never select on the theme. A value that does not follow the roles is a non-role token in `_tokens.scss`. The tile is fixed rather than reversed between modes, so it takes one token with no `-dark` twin, as `logo-gradient-stop` does.
- Conventions › Client asset homes and › Angular naming ("design tokens only, enforced by lint").

No AC contradicts an AD, and no NFR is at issue.

**Why 28px on a 36px tile, not 32px on 40px.** A 40px tile leaves the 4px focus ring flush with the band's edges. At 720px its 164px width also exceeds the 154px left column. The 36px tile keeps a 6px margin inside the band, room for the ring, and fits at both tested widths.

**Why the anchor is the tile.** One element keeps the focus ring around the tile by construction, keeps `header.ts`'s template and its jsdom tests unchanged, and adds no wrapper for Epic 11's concurrent edits to meet.

**Integration ACs (Rule 1/2):** this story introduces no service, module or shared component, so there are no consumers. **Consumes:** Story 15.6's theme scope and token layer, Story 15.9's header layout, and the sign-in card's vendored navy file. **Consumed-by:** none.

**Ledger inbox (Rule 17):** none.

**Amendments (Rule 5, tier 1, required by AC4):** the DESIGN.md and EXPERIENCE.md lines in the Code Map, listed under `amendments:` for the lead. The spine is unchanged.

**Footprint (Rule 11):**

- **Story-owned:** `shell/header*`, `_tokens.scss`, `design-tokens.mjs` and `design-tokens.test.mjs`, the deleted PNG, and the new browser spec.
- **`footprint_extensions:`** the in-place edits to the shared-append files (the `_components.scss` header-lockup rule, the `strings.ts:1064` comment and EXPERIENCE.md `:534`), plus DESIGN.md and the UX memlog.

**DW-151** (the lockup is a background and forced-colors mode drops it) is unchanged by this story, so it is not reopened.

## Verification

**Environment (slot B, Rule 21).** Every IRIS MCP call carries `server: "ocupilot-slot-b"`, and `ocupilot-iris` does not exist.

- The throwaway is `ocupilot-b-ci`. If it is not running, start it with `sh scripts/ci-throwaway.sh up --dir /tmp/ocupilot-b-ci --project ocupilot-b-ci --web 52777 --super 1976`.
- Leave it running for the lead's smoke. Tear down only a throwaway whose `up` this stage ran.
- Never stop, `down` or recreate `ocupilot`, `ocupilot-slot-b`, `ocupilot-slot-c` or `ocupilot-ci`.
- Helper scripts live under the worktree, never in a shared scratchpad filename.
- Run one test command at a time.
- No live provider keys are needed; do not read `.env.local`.

Before any browser read:

1. `cd ui && npm run build`.
2. `docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`.
3. `export OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci`.

**Commands:**

- `(loop)` `cd ui && node --test --test-concurrency=1 browser/header-lockup.browser-spec.mjs browser/a11y-structural-invariants.browser-spec.mjs`: green. The DW-1337 gate prints 0 fresh and 0 stale in light and dark.
- `(loop)` `cd ui && npm run test:tools`: green, including `design-tokens`, `citations`, `strings` and `build-output`.
- `(loop)` `cd ui && npm run test:components`: green, including `header.spec.ts`.
- `(loop)` `cd ui && npm run build`: the seven checkers pass, and the initial total stays under the 1854kB warning (quote it); the PNG is an asset, not initial JS. Also `ls dist/ocupilot-ui/browser/media | grep -c Lockup` prints 1.
- `(loop)` `bash scripts/lint-docs.sh`: green. `git diff --numstat` shows equal added and removed counts for DESIGN.md and EXPERIENCE.md.
- `(loop)` `grep -rn "Lockup-horizontal-reversed" ui/src ui/tools ui/browser src scripts module.xml`: only the new tests' negative assertions.
- `(once, before dev_complete)` `cd ui && node --test --test-concurrency=1 browser/theme.browser-spec.mjs browser/account-and-filter.browser-spec.mjs`: the header's theme and 720px neighbours, green.
- `(once, before dev_complete)` `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS`: more than 0 checks, all passing.
- `(once, before dev_complete)` the full ObjectScript sweep on the throwaway, although no `.cls` changes: `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --package OcuPilot.Test`.
- The full browser suite is not run locally (Rule 29). It runs in CI's `browser` job.

**Mutations (Rule 19).** For each one: apply it, rebuild and redeploy where a bundle is read, observe red, revert, and confirm `git status --short` and `git diff --stat` are unchanged. Record each as `mutation: … → …` below.

- AC1: restore the reversed PNG and point the header `url()` back at it → `header-lockup` AC1 red (URL differs from the card's), and `design-tokens.test` red.
- AC2: set the tile's `background-color` to `var(--ocu-surface-container-lowest)` → `header-lockup` dark leg and pixel equality red.
- AC3:
  - `outline-offset: -8px` on the focus rule → the Keyboard focus leg red;
  - bind `aria-label` to another key in `header.ts` → the Link leg red.
- AC4:
  - DESIGN.md `asset:` back to the reversed file, or the `plate:` hex changed → `design-tokens.test` red;
  - one word of the cited row-534 phrase changed → `citations.test` red.

Recorded (each reverted; `git status --short` and `git diff --stat` unchanged after each):

- mutation: reversed PNG restored and the header `url()` pointed at it (rebuilt, redeployed) → `header-lockup` "AC1: at 1280 px" red ("the header and the sign-in card draw the same file") and `design-tokens.test` "the header lockup is the navy-wordmark file on the white tile" red.
- mutation: tile `background-color: var(--ocu-surface-container-lowest)` (rebuilt, redeployed) → `header-lockup` "AC2" red ("the tile does not follow the theme"); light AC1 stays green because that role is white in light.
- mutation: `outline-offset: -8px` on `.ocu-header-lockup:focus-visible` (rebuilt, redeployed) → `header-lockup` "AC3: keyboard focus" red ("offset -8px").
- mutation: `aria-label` bound to `STRINGS.headerNamespaceLabel` in `header.ts` (rebuilt, redeployed) → `header-lockup` "AC3: clicking the tile" red.
- mutation: DESIGN.md `asset:` back to the reversed file → `design-tokens.test` "the logo tile is #ffffff … logo-lockup plate" red; `plate:` hex `#FFFFFE` → the same test red.
- mutation: "tile" → "plate" in the row-534 phrase `strings.ts:1064` cites → `citations.test` "every anchored EXPERIENCE.md citation quotes a phrase …" red.
- mutation: `background-size: contain` removed from `.ocu-header-lockup` (rebuilt, redeployed) → `header-lockup` "AC1: at 1280 px" red (drawn size `auto`, expected `contain`).
- mutation: `:root.ocu-theme-dark .ocu-header-lockup { filter: invert(1); }` appended to `_theme.scss` (rebuilt, redeployed) → `header-lockup` "AC2" red on the pixel comparison alone; every computed value still matched.
- mutation: tile `width: 200px` (rebuilt, redeployed) → `header-lockup` "AC1: at 720 px" red (the tile intersects the command box), and "AC1: at 1280 px" red (200, expected 144).
- mutation: reversed PNG restored and the header `url()` pointed at it, rebuilt → `build-output.test` "the sign-in lockup reaches the bundle as a hashed asset …" red (`OcuPilot-Lockup-horizontal-reversed-<HASH>.png` in `media/`).
- mutation (code review): reversed PNG restored in `ui/src/assets/lockup/` only, no CSS change → `design-tokens.test` "the header lockup is the navy-wordmark file on the white tile" red ("the reversed file is no longer vendored").
- mutation (code review): `THEME_DARK_CLASS` in `core/theme.ts` renamed so toggling it no longer applies the dark scope (bundle redeployed first) → `header-lockup` "AC2" red ("the dark theme is on screen: the page ground is surface-dark"); the other four tests stayed green.

## Auto Run Result

Status: done
Blocking condition: none

**Change.** The header lockup is now the navy-wordmark file the sign-in card draws, on a 144×36 white rounded tile with 4px padding: the anchor itself, the same in light and dark through the fixed non-role token `--ocu-logo-tile`. The reversed PNG is deleted from the client. DESIGN.md (11 lines), EXPERIENCE.md row 534, `header.ts` and the `strings.ts:1064` citation are corrected in place; both documents keep their line counts.

**Files.**

- `ui/src/styles/_components.scss`: the `.ocu-header-lockup` rule and its comment (footprint extension, in place).
- `ui/src/styles/_tokens.scss`, `ui/tools/design-tokens.mjs`: `--ocu-logo-tile` registered `hasDark: false`.
- `ui/src/assets/lockup/OcuPilot-Lockup-horizontal-reversed.png`: deleted.
- `ui/src/app/shell/header.ts`, `header.spec.ts`: doc comments only.
- `ui/src/app/core/strings.ts:1064`: citation re-pointed (footprint extension).
- `ui/tools/design-tokens.test.mjs`: the header-lockup test inverted, a tile-token test added.
- `ui/tools/build-output.test.mjs`: asserts no reversed file in the built `media/`.
- `ui/browser/header-lockup.browser-spec.mjs` (new): all five Matrix rows.
- DESIGN.md, EXPERIENCE.md `:534`, UX `.memlog.md` (decision appended): the tier-1 amendments for the lead.

**Review.** Two layers (verification-gap, intent-alignment), 16 findings: 6 patched (2 medium, 4 low), 1 deferred (the gate's stale-stamp variance, pre-existing), 9 rejected with reasons in the Triage Log. Follow-up review: `false` — two mediums were patched, but each patch's assertion was seen red under a recorded mutation, so no unverified risk can be named.

**Verification** (slot B, `ocupilot-b-ci`, bundle rebuilt and redeployed before every browser read).

- `npm run build`: seven checkers pass; initial total 1.80 MB (under 1854kB); one `Lockup` file in `media/`.
- `header-lockup.browser-spec.mjs` 5/5; `a11y-structural-invariants` 10/10. DW-1337: 0 fresh in every run. Stale counts varied with an unchanged bundle: 0, then 4, then 1, all 720px status-bar stamp rows (deferred).
- `test:tools` 1426/1426; `test:components` 1377/1377 (106 files); `lint-docs` 0 issues; `--numstat` 11/11 and 1/1; the `Lockup-horizontal-reversed` grep is empty.
- Once: `theme` + `account-and-filter` browser specs 9/9; `smoke.sh --container ocupilot-b-ci` 49/49; ObjectScript sweep 286 classes, 2394 tests, 0 failed.
- Ten mutations recorded under Verification, each reverted with the tree byte-identical.

**Residual risk.** The handoff's two ad-hoc screenshot runs lacked the origin variables and signed `_SYSTEM` in on `ocupilot-ci` (slot A's throwaway), resetting that account's remembered state there once each; no container was touched.
