---
title: 'Story 1.2 — The design system: tokens, type and the string table'
type: 'feature'
created: '2026-09-09'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/DESIGN.md'
  - '{project-root}/_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md'
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
warnings: ['multiple-goals', 'oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** `ui/` builds but draws nothing: `styles.css` is a two-line placeholder that reserves itself for this story, no font is vendored anywhere in the tree, and no string the product speaks exists in code. Every screen from Story 1.5 onward would otherwise pick its own colors, sizes and wording, and both floors the product promises — WCAG 2.1 AA contrast in two modes, and one canonical voice — would be met by review rather than by the toolchain, after there is content to break them.

**Approach:** Transcribe the Lantern token set, the six-role type ramp and the canonical Fixed strings out of the UX documents into three shipped sources — a color token layer over Angular Material 3, a typography and metrics layer with vendored `woff2` faces, and one keyed string module — and make each floor mechanical: a contrast checker computed from the shipped token values in both modes, a client linter wired into `prebuild` so a hardcoded color or an un-sourced user-facing literal fails `npm run build`, and a product-vocabulary rule in the existing tree checker.

## Boundaries & Constraints

**Always:**

- **Extend the Story 1.1 workspace at `ui/`.** Angular 22.1.5, TypeScript 6.0.3 exactly, `@angular/build:application`, `outputHashing: all`, `baseHref: /ocupilot/`, engine-strict Node `^22.22.3 || ^24.15.0 || ^26.0.0`. Never scaffold a second workspace, never add a webpack builder, never re-float a pin.
- **`@angular/material` and `@angular/cdk` are already direct dependencies at `22.1.5` and installed.** This story *configures* Material 3; it does not install it.
- **`DESIGN.md` is the sole authority for every color, size, weight and measured contrast ratio. `EXPERIENCE.md` › *Fixed strings* is the sole authority for every word**, canonical over `DESIGN.md` and over every inline quotation anywhere else. Transcribe; never recompute a published ratio into a different number, never invent a hex, never respell a string.
- Light values sit on the bare role, dark values under `<role>-dark`, **both complete**, both always present in the shipped stylesheet.
- Material 3's *meaning* is inherited unchanged — surface layering, `on-` pairing, container tints, state-layer opacities (8/10/12%), ripple, scrim, the 38% disabled opacity, and checkbox, radio, switch, form-field and tab anatomy. Only values are overridden.
- Every non-ASCII character in `.ts` and `.scss` source is authored as a `\uXXXX` escape, never as a literal byte (Rule 14). This is load-bearing here, not ceremony: the epic file's own copy of `"done · audit not marked"` was corrupted to `"done - audit not marked"` by exactly this normalization.
- All project ObjectScript stays under `src/OcuPilot/`; the Angular client stays under `ui/`. `irislib/`, `irissys/`, `irisui/`, `irisdocs/` are read-only reference exports and are never read as project source, edited, or scanned by a new checker.
- Python is run through `uv run`; a bare `python3` runs outside the project environment.

**Never:**

- **No request may reach any host but the instance's own origin** — no CDN, no Google Fonts, no `@import url(https://…)`, in source or in built output (NFR-10, AD-47, AD-11 rule 4).
- **No theme toggle.** Both token sets ship; wiring the switch is deferred by the spine to polish week (FR-73). Ship the dark scope so the flip is a class flip; do not build the control.
- **No component, screen, page, store or descriptor.** No `areas/` folder, no shell chrome, no Home. Story 1.9 owns descriptors, 1.10 the chrome, 1.12 Home.
- **No new Angular test runner.** There is no `test` architect target and no Karma/Jest/Vitest/web-test-runner installed; `angular-json.test.mjs` would go red on any non-`@angular/build:*` builder. The two tiers are `%UnitTest` classes under `src/OcuPilot/Test/` and `node --test` files under `ui/tools/`. This story needs no third tier — see Design Notes.
- **No second string source and no second color source.** Exactly one module holds user-facing literals and exactly one stylesheet holds color literals; a slice that adds its own is the failure both linters exist to stop.
- No `git commit`, no `git push`, no CI trigger from any agent working this story.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Token roster is complete | The shipped color token stylesheet | Exactly 64 role names, each declared twice — bare (light) and `-dark` — for 128 color-role custom properties; the 64 names equal `DESIGN.md`'s frontmatter `colors:` key set (30 Material 3 roles + 34 OcuPilot roles) | A missing, extra or misspelled role fails naming the role and which side (light/dark) is absent |
| Token values are faithful | Each declared value vs `DESIGN.md` frontmatter lines 35–162 | Every hex equals the document's value, compared case-insensitively on the hex digits | Fails naming the role, the shipped value and the document value |
| Non-role color literals are quarantined | The logo gradient stop and the elevation shadow values `DESIGN.md` states | Present in the token stylesheet as custom properties, documented as **not** color roles, and excluded from the 64-role count | A non-role literal counted as a role fails the roster assertion |
| Contrast, load-bearing set | Every pair in `DESIGN.md`'s load-bearing table, both modes | Ratio computed from the shipped hexes meets its floor (4.5:1 text, 3:1 non-text) **and** matches the document's published figure to two decimal places | Fails naming pair, mode, computed ratio, published ratio and floor |
| Contrast, the three marginal guards | `secondary`/`secondary-container`; toast link on `inverse-surface`; `restrained`/`secondary-container` | Each carries its own assertion; the `restrained` pair computes **below** 4.5 in dark and the named remedy pair `on-secondary-container`/`secondary-container` computes above it | A guard pair drifting above or below its documented figure fails naming both values |
| Contrast, the four rejected pairs | The measured-and-rejected pairs | Each computes below its floor (proving the rejection stands) and appears only in the never-draw list, never in a drawn list | A rejected pair appearing in a drawn list fails naming it |
| Type ramp | The typography layer | Exactly six text roles with `DESIGN.md`'s size / weight / line-height / tracking; no `font-weight: 700` anywhere under `ui/src`; no `font-size` below 11px; numeric table cells carry tabular figures and right alignment | Fails naming the role and the offending property |
| Scale and metrics | The metrics layer | The 4px scale (4·8·12·16·20·24·32, no 7), radii 4/6/12/9999, and the row/control/input/log-row/shell heights `DESIGN.md` states | Fails naming the token and its expected value |
| Fonts are vendored | The typography layer and `ui/src/assets/fonts/` | An `@font-face` for each shipped face (Inter 400/500/600, JetBrains Mono 400/600), each `src` resolving to a repo-local `woff2`; fallback stacks exactly as `DESIGN.md` writes them | A face whose file is absent, or any `https://` host in a font `src`, fails naming it |
| Fonts reach the bundle | After a real `npm run build` | The emitted browser output contains the `woff2` files, and no **fetch-causing reference** in the emitted CSS or `index.html` (`url(…)`, `@import`, `src=`, `href=` on a `link`) names a host other than the instance's own origin | Fails printing the emitted file list and any offending reference. A bare `https://` string elsewhere is **not** a violation: Angular's own runtime embeds `angular.dev` error URLs, `extractLicenses` emits a `3rdpartylicenses.txt`, and the vendored OFL text carries the licence URL — a blanket host scan would flag all three and is the wrong check |
| Hardcoded color is rejected | A hex, `rgb()`, `hsl()` or CSS named color in any `ui/src` file other than the token stylesheet | `npm run build` exits non-zero **before** `ng build` starts, naming file, line, literal and rule | The token stylesheet itself is exempt by exact path; an exemption by any other means is a defect |
| Un-sourced literal is rejected | A literal text node, or a literal value on a copy-bearing attribute, in any component template under `ui/src/app` | `npm run build` exits non-zero naming file and line; an interpolation of a `STRINGS.*` key passes | Server-supplied text arriving through a binding is out of scope by design (AD-39) |
| String source is complete | Every quoted literal in `EXPERIENCE.md` lines 250–302, plus `"done · audit not marked"` and `"running"` | Each exists verbatim as the value of a uniquely-named key; keys unique, values unique | Fails naming the missing or duplicated literal |
| Voice rules hold over the source | Every value in the string source | No `!`, no `"Oops"`, no emoji, no `"successfully"` (case-insensitive) | Fails naming the key and the violated rule |
| Product vocabulary | Any file under `src/OcuPilot/` or `ui/` | `co-pilot` is permitted only when immediately preceded by `agent`; `uv run scripts/check-objectscript.py` exits non-zero otherwise, naming file, line and rule | `"agent co-pilot"` and `"Agent co-pilot"` pass; a bare `"co-pilot"` fails |
| Reduced motion | The metrics layer | Motion tokens carry `DESIGN.md`'s durations, and a `@media (prefers-reduced-motion: reduce)` block sets each to `0ms` / `none` | A motion value written as a literal outside the tokens fails the color/metrics assertion for that token |
| **Integration (Rule 1)** | `ui/src/app/app.ts` renders a string read from the string source, under the token and type layers | After a real `npm run build`, the emitted JS bundle contains that string's exact value and the emitted CSS bundle contains the shell token declaration — observed in the shipped artifact, not by inspecting the modules | A build that succeeds while emitting neither fails naming which was absent |

</intent-contract>

## Code Map

**What exists today (Story 1.1, `done` — extend, never re-scaffold).**

- `ui/package.json` — scripts are `prebuild` / `pretest` / `prestart` → `node tools/version-guard.mjs`, `build` → `ng build`, `test` → `node --test tools/`. `@angular/material` **and** `@angular/cdk` are already direct dependencies at exactly `22.1.5`; `typescript` `6.0.3`; **no linter of any kind is installed** — this story adds the first. `sass@1.101.0` resolves transitively through `@angular/build@22.1.5`, so `.scss` compiles today with no dependency change.
- `ui/angular.json` — architect targets are **`build` and `serve` only**; no `test`, no `lint`. `options` carries `outputPath: dist/ocupilot-ui`, `baseHref: /ocupilot/`, `outputHashing: all`, `assets: []`, `styles: ["src/styles.css"]`, `scripts: []`. Production budgets warn at 500kB and error at 1MB on the **initial** bundle (font files emitted as separate assets do not count against it).
- `ui/src/styles.css` — two comment lines and nothing else; it explicitly reserves itself for this story.
- `ui/src/app/app.ts` — standalone, `OnPush`, inline template `<p>OcuPilot</p>`. That literal text node is exactly what this story's string lint must reject; it becomes the in-story consumer.
- `ui/src/main.ts` — `bootstrapApplication(App, { providers: [provideZonelessChangeDetection()] })`. No `provideAnimations()`.
- `ui/src/index.html` — `<base href="/ocupilot/">`, no font links, no preconnect. Nothing to remove.
- `ui/tsconfig.json` — full strict set plus `strictTemplates`. `tsconfig.spec.json` and `@types/jasmine` are vestigial `ng new` scaffolding with no runner behind them; leave them alone.
- `ui/tools/version-guard.mjs` — **the house checker pattern to copy**: a pure exported predicate `checkVersions({node, typescript}) → {ok, errors[]}` with shared exported range labels, a thin `main()` doing the impure work and `process.exit(1)`, and a direct-invocation guard written `if (import.meta.url === pathToFileURL(process.argv[1]).href)` (the naive `file://${argv[1]}` form fails open on paths with spaces).
- `ui/tools/*.test.mjs` — **the house test style**: `node:test` + `node:assert/strict`, flat top-level `test('<full sentence naming the claim>', () => …)`, no `describe`/`it`/`beforeEach`, paths resolved from `import.meta.url` never `process.cwd()`, config read once at module top level keeping **both** the raw string and the parsed object, every assertion carrying a third-argument message that interpolates the actual value, and a header comment naming the AC it pins.
- `ui/tools/angular-json.test.mjs` — asserts every builder starts with `@angular/build:`, that no `webpack` substring appears, `outputHashing` at options level, and `baseHref`. It does **not** assert the `styles` entry, so switching to `styles.scss` keeps it green. Adding an `ng lint` architect target with a third-party builder would turn it **red** — do not add one.
- `ui/tools/build-output.test.mjs` — the one test that runs the real build: `rmSync(dist)` first, then `execFileSync('npm', ['run','build'], {stdio:'pipe'})` with stdout/stderr surfaced through `assert.fail`, then reads `dist/ocupilot-ui/browser` and matches `main-<hash>.js` / `styles-<hash>.css`. Its header carries a `Mutation (Rule 19)` note. **Extend this file** rather than adding a second full build to the suite.
- `scripts/check-objectscript.py` — `SCAN_ROOTS = (ROOT/"src"/"OcuPilot", ROOT/"ui")`, so it **already scans `ui/`**. `PRUNE_DIRS = {node_modules, dist, .angular, .git}`; `read_text()` returns `None` on `UnicodeDecodeError`, so binary `woff2` files are skipped without special-casing. Problems accumulate into one list formatted `f"{rel}:{line}: <message>"`, printed to stdout, with a count line on stderr and `return 1 if problems else 0`. It takes no argv and always scans the whole tree. Its four rules are forbidden rename-checklist tokens, ObjectScript naming, write discipline and package placement — **none is color- or string-related**.
- `.githooks/pre-commit` — live in this clone (`core.hooksPath=.githooks`). Runs markdownlint + `check-prose.py` on staged docs, and `uv run scripts/check-objectscript.py` when the staged set matches `src/OcuPilot/**/*.{cls,mac,inc}` or **`ui/**`**. Accumulates `STATUS`, guards each tool with `command -v`, and states its own design rule: *the two scopes must agree — a hook that blocks on a file the full run never looks at is a commit you cannot unblock by running the linter.*
- **There is no CI.** No `.github/`, no workflow file anywhere. "Fails the build" can only mean `npm run build`.
- **No font of any kind exists in the tracked tree**; `ui/src` holds exactly four files and there is no `assets/` or `public/` directory.

**Authorities to transcribe from (read-only planning artifacts).**

- `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/DESIGN.md` — frontmatter `colors:` **lines 35–162** carries all 64 roles with light values (35–98) and dark values (99–162); the same values are restated in the prose tables at 737–747 and 753–768. Typography frontmatter 163–199 and prose 861–877. Spacing 206–234, radii 200–205. Fonts: frontmatter comment 164–167 and prose 859. The **load-bearing contrast table is 772–802**; the derived table 804–836 (which is where the three marginal guard pairs live, at 826, 830 and 835); the **four measured-and-rejected pairs are 838–845**. Seven color rules 847–855. Elevation and shadows 928–933; motion 937. Do's and Don'ts 1249–1270.
- `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md` — **the Fixed strings table is lines 250–302**: a header at 250–251 and **51 data rows**, carrying roughly 100 distinct quoted literals (several rows list many strings separated by `·`, with `/` marking mutually-exclusive alternates — and `·` also occurs *inside* strings, so only the double quotes disambiguate). Line 248 declares the table canonical and states the resolve-but-never-respell rule; line 246 carries the voice rules, the agent-voice rules and the `<user name>` rule. Accessibility floor 575–593; reduced motion 590; privilege-gating mechanism 214; product vocabulary 31 and 623.
- `_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md` — Consistency Conventions "Angular naming" row and Stack table; the `## Deferred` row *Theme toggle wiring → Polish week (FR-73)*. The spine mentions Material's theming API nowhere, pins neither SCSS nor CSS, and names no lint tooling; `design token` and `lint` each appear exactly once, in the Angular-naming row.

**System source consulted (read-only, verified on disk, never modified).**

- `ui/node_modules/@angular/material/_index.scss:21–23` — forwards `theme`, `theme-overrides`, `system-level-colors`, `system-level-typography`, `system-level-elevation`, `system-level-shape`, `system-level-state` from `./core/tokens/system`.
- `ui/node_modules/@angular/material/core/tokens/_system.scss:57` — `@mixin theme($config, $overrides: ())`. Its doc comment (31–56) states the config takes `color`, `typography` and `density`; `color` may be a palette or a map with `primary`, optional `tertiary` and `theme-type` of `light` | `dark` | `color-scheme` (default); `typography` may be a family or a map with `plain-family`, `brand-family`, `bold-weight`, `medium-weight`, `regular-weight`; and — the line that settles the whole mechanism — *"The application variables emitted use the namespace prefix `--mat-sys`. e.g. `--mat-sys-surface: #E5E5E5`"*. `@mixin theme-overrides($overrides, $prefix)` is at `:190`.

## Tasks & Acceptance

**Execution:**

- `ui/src/styles/_tokens.scss` -- declare all 128 color-role custom properties on `:root` (`--ocu-<role>` light, `--ocu-<role>-dark` dark) transcribed from `DESIGN.md` frontmatter 35–162, plus the logo gradient stop and the elevation shadow values that section states, each marked in a comment as **not a color role**; the file header declares it the **one file in `ui/` permitted to contain a literal color value** -- this is the AD-12 "one writer" shape applied to color, and it is what makes the lint's exemption a single exact path rather than a growing list.
- `ui/src/styles/_theme.scss` -- `@use '@angular/material' as mat;`, include `mat.theme(...)` once so Material emits its complete `--mat-sys-*` system (roles Lantern does not value, state layers, ripple, scrim, 38% disabled, shape, density, typography weights), then re-point each `--mat-sys-<role>` at `var(--ocu-<role>)` under `:root` and at `var(--ocu-<role>-dark)` under the dark root scope -- inherits Material's meaning and overrides only values, which is the AC's exact wording.
- `ui/src/assets/fonts/` -- vendor the five `woff2` faces (Inter 400/500/600, JetBrains Mono 400/600) with their OFL licence text alongside -- taken before the typography layer, which declares `@font-face` against these exact files; weights 500 and 600-on-mono are used by `DESIGN.md`'s own component values, so a 400-only vendoring would silently synthesize faux weights in Story 1.12 and Epic 5.
- `ui/src/styles/_typography.scss` -- the `@font-face` block for the five vendored faces with `DESIGN.md`'s two fallback stacks verbatim, and the six text roles as tokens plus utility classes carrying size, weight, line-height and tracking; add the tabular-figures + right-alignment rule for numeric table cells -- six roles and no others is an AC, so the roles must be enumerable by a checker rather than implied.
- `ui/src/styles/_metrics.scss` -- the 4px spacing scale, the four radii, the row/control/input/log-row and shell metrics, and the motion tokens with a `@media (prefers-reduced-motion: reduce)` block zeroing them -- reduced motion has no component to observe in this story, so the tokens *are* the deliverable and the later stories consume them.
- `ui/src/styles.scss` -- new entry point that `@use`s the four partials in order (tokens, theme, typography, metrics); delete `ui/src/styles.css` -- one entry keeps the cascade order explicit and deterministic.
- `ui/angular.json` -- point `styles` at `src/styles.scss` -- the only edit this file needs; do not add a `lint` or `test` target, which would turn `angular-json.test.mjs` red.
- `ui/src/app/core/strings.ts` -- `export const STRINGS = { … } as const;` carrying every quoted literal from `EXPERIENCE.md` 250–302 verbatim, plus `"done · audit not marked"`, `"running"` and the product name; every non-ASCII character as a `\uXXXX` escape (Rule 14); the header names `EXPERIENCE.md` › *Fixed strings* as canonical, states the resolve-but-never-respell rule and the `<user name>` = login-name-as-audited rule -- one keyed source is what lets the lint say "not drawn from the string source" mechanically.
- `ui/src/app/app.ts` -- render the product name through an interpolation of a `STRINGS` key and apply a type-role class -- the in-story consumer (Rule 1); its current literal text node is precisely what the new lint rejects.
- `ui/tools/design-tokens.mjs` -- pure exports: `parseTokens(css)` returning `{light, dark}` role maps, `relativeLuminance(hex)`, `contrastRatio(a, b)`, and the pair inventory `LOAD_BEARING` / `MARGINAL_GUARDED` / `REJECTED`, each entry carrying its floor and the ratio `DESIGN.md` publishes -- the published figures are the expectations, so a mistyped hex fails the *fidelity* assertion rather than quietly redefining the floor.
- `ui/tools/design-tokens.test.mjs` -- roster completeness and value fidelity, then contrast over the load-bearing set in both modes, the three marginal guards including the dark `restrained` failure and its `on-secondary-container` remedy, and the four rejected pairs -- one file because all of it reads the same parsed token map.
- `ui/tools/typography.test.mjs` -- the six roles and their values, no weight 700, no size below 11px, tabular figures, the scale and radii and metrics, the five `@font-face` declarations with local `src` and the exact fallback stacks, no external host in any `url()`, `@import` or `src` reference under `ui/src` (the vendored OFL licence text carries a URL and is not such a reference), and the motion tokens with their reduced-motion override.
- `ui/tools/strings.mjs` -- pure exports: `loadStrings()` reading the string source and returning the key/value map, `checkVoiceRules(values)` returning `{ok, errors[]}`, and `extractPlaceholders(value)` -- the linter and the tests must agree on one parse, not two.
- `ui/tools/strings.test.mjs` -- every canonical literal present verbatim, keys and values unique, the voice rules, and placeholder syntax -- build the expected list by reading the table, not from memory.
- `ui/tools/client-lint.mjs` -- one linter, two rule families, matching `version-guard.mjs`'s shape exactly: pure `checkHardcodedColors({path, text})` and `checkTemplateLiterals({path, text, allowedValues})`, an aggregate `lintClient()` returning `{ok, errors[]}` with each error naming file, line, literal and rule, a `main()` that prints to stderr and `process.exit(1)`, and the `pathToFileURL` direct-invocation guard -- one CLI is what makes both ACs' "fails the build" a single wiring.
- `ui/tools/client-lint.test.mjs` -- both rule families against positive and negative fixtures, including that the token stylesheet is exempt by exact path and that a `STRINGS.*` interpolation passes while a literal text node does not.
- `ui/package.json` -- extend `prebuild` and `prestart` to run `client-lint.mjs` after the version guard -- `prebuild` is the **only** mechanism in this repository by which a check can literally fail a build, and it transitively fails `npm test` too, because `build-output.test.mjs` shells out to `npm run build`.
- `ui/tools/build-output.test.mjs` -- extend with the font-emission, no-external-host and Rule 1 integration assertions, and add their mutation notes to its header -- reuses the one build the suite already runs instead of adding a second.
- `scripts/check-objectscript.py` -- add `check_product_vocabulary(problems)` over both scan roots: `co-pilot` (case-insensitive) is a violation unless immediately preceded by `agent` -- the AC scopes this check to the source tree, and this file already owns the forbidden-token machinery and already scans both roots.
- `.githooks/pre-commit` -- run `node ui/tools/client-lint.mjs` on the existing `ui/**` staged trigger, guarded by `command -v node` like its siblings -- the linter always scans the whole client tree, so the hook's own "the two scopes must agree" rule holds.

**Acceptance Criteria:**

- Given the pinned stack and a clean `ui/`, when `npm run build` runs, then it succeeds and the hashed output carries the token layer, the type layer and the vendored `woff2` faces.
- Given a violation of either client-lint rule family anywhere under `ui/src`, when `npm run build` runs, then it exits non-zero **before** `ng build` starts, naming the file, the line and the rule.
- Given the whole tool suite, when `node --test tools/` runs, then every test passes with zero failures.
- Given the repository tree, when `uv run scripts/check-objectscript.py` runs, then it exits zero; and when `co-pilot` appears without a preceding `agent` anywhere under `src/OcuPilot/` or `ui/`, then it exits non-zero naming file, line and rule.
- Given every stylesheet and template under `ui/src` and the emitted CSS and `index.html`, when their fetch-causing references (`url(…)`, `@import`, `src=`, `link href=`) are inspected, then none names a host other than the instance's own origin — no CDN and no font host.
- Given the authored Markdown, when `bash scripts/lint-docs.sh` runs, then it exits zero.

## Spec Change Log

## Review Triage Log

## Design Notes

**Governing architecture decisions (Rule 6).** `AD-19` (standalone, zoneless, `OnPush`; screen state is a signal store — read broadly here, so the theme scope is shell-owned state rather than a component field, though this story ships no signal because the toggle is deferred), `AD-47` (the static origin is hostile ground; the bundle carries a CSP naming only the instance's own origin, *"achievable precisely because NFR-10 already forbids any CDN"*, and *"development does not relax this"* — this, not a preference, is why fonts are vendored), `AD-11` rule 4 (*"every library is vendored (NFR-10)"*, with rule 5's seeded-injection test asserting **zero outbound requests** as the precedent for making the no-CDN claim testable rather than aspirational), `AD-5` (the screen descriptor carries **empty-state text** and command-box aliases — server-side, hand-written ObjectScript, and therefore deliberately outside this story's string source; see the scoping note below), `AD-12` and `AD-39` (the one error envelope, whose `reason` is *"human text that may be reworded freely"* and is server-minted — also outside the string source, with `code` as the stable join key a later story keys client copy off), `AD-14` (the closed kernel-owned entity-type enum where *"the build fails on an unknown value"* — the house shape for "one canonical vocabulary plus a build-failing gate", which is what both linters here are), and `AD-3` as precedent (*"a classification miss fails the build rather than reaching the model"*).

`AD-20` is **adjacent, not binding**: its `Binds:` is scoped to *"every client call to `/api/ocupilot`"* and this story makes none. But its stated hazard does constrain a test here — the deep-link fallback answers an unresolved path with `index.html`, so a missing font would return **HTTP 200 with HTML**. The font assertions therefore check the emitted files and their references, never a status code.

From the spine's tables: the Consistency Conventions **Angular naming** row — *"One folder per area under `ui/src/app/areas/<area>/`; a screen is `<screen>.page.ts` + `<screen>.store.ts` + `<screen>.descriptor.ts`. Shared shell components under `ui/src/app/shell/`. **Design tokens only — no hardcoded colors, enforced by lint.**"* — and the **Stack** rows for Angular 22.1.x, Angular Material + CDK 22.x, Node, TypeScript 6.0.x pinned exactly, and the `@angular/build` application builder. Note the Conventions row says *no hardcoded colors*; it does not say "no hardcoded spacing or type sizes". This story's lint covers colors, as worded; the metrics tests cover the rest by asserting the tokens exist and carry the documented values, which is the weaker but honestly-scoped claim.

**Consumed-by** (Rule 2 — this story introduces three shared modules: the color token layer, the typography/metrics layer, and the string source, plus two build-failing linters):

- Story 1.5 — serves the built SPA; first story whose deep-link fallback must not swallow a font request.
- Story 1.9 — screen descriptors; their empty-state text is server-side (AD-5) and is the first place the string source's scope line is tested in anger.
- **Story 1.10 — the first real visual consumer**: header, rail, side bar and status bar are the first surfaces that draw `shell` / `on-shell` / `shell-edge`, the chrome focus ring and the 48/48/240/24 metrics, and the first templates the string lint governs at scale.
- Story 1.12 — Home; first consumer of the tile metrics and of `caption` at weight 500.
- Story 1.13 — uniform error handling; first consumer of the `"instance unreachable"` / `"request refused"` strings and the first to render an envelope `reason` beside them.
- Story 1.14 — auto-refresh; consumes the refresh-chip strings and the motion tokens.
- Epic 5 — the agent panel; the only consumer of the `agent-*` roles, `change-highlight`, the proposal-card strings, `code` at weight 600 and the `"running"` reduced-motion word.
- Every later epic — every screen draws from these three sources and passes both linters.

**Consumes:** nothing from Story 1.1's ObjectScript surface. This story extends 1.1's `ui/` workspace (`package.json` scripts, `angular.json`, `app.ts`, the `ui/tools/` test tier) and its `scripts/check-objectscript.py` checker, and adds no ObjectScript.

**Integration ACs (Rule 1).** The token layer and the string source both have a real in-story consumer: `ui/src/app/app.ts` reads a key from the string source and renders it under the token and type layers, and the observable effect is asserted against the **shipped artifact** — after a real `npm run build`, the emitted JS bundle contains the string's exact value and the emitted CSS bundle contains the shell token declaration. That is an assertion on the consumer's output through the project's own tier, not an inspection of the introducing modules' internals. The two linters' consumer is the build itself: `prebuild` runs them, so their observable effect is a non-zero exit of `npm run build`.

**Ledger inbox (Rule 17).** **Empty** — `ledger.sh slice 1-2-the-design-system-tokens-type-and-the-string-table` returns nothing, and Story 1.2 is not among the eleven Epic 1 stories carrying routed `- DW-n:` acceptance bullets. Nothing to address or decline.

**Nine resolved readings, each with the evidence that settles it.**

1. **"Roughly 60 canonical Fixed strings" undercounts.** The canonical table at `EXPERIENCE.md` 250–302 is 51 data rows carrying roughly 100 distinct quoted literals — several rows list many strings separated by `·`, and `·` also appears *inside* strings, so a naive split corrupts them; only the double quotes delimit. "Roughly" is approximate and the table is the referent, so the story ships the whole table. Build the test's expected list by reading those lines, not from memory or from this spec.

2. **One of the AC's own four example strings is not in the table, and the AC misspells it.** `"done - audit not marked"` appears in the epic with a hyphen; the source spelling is `"done · audit not marked"` with a middle dot, and it lives only in prose (`EXPERIENCE.md` 207, 329, 477 and `DESIGN.md` 1167, and in AD-15). `EXPERIENCE.md` is canonical over every other quotation, so the middle-dot form is what ships. This is not an intent gap — the AC requires the string to exist as a named entry, and it now does — but it is exactly the corruption Rule 14's escapes exist to prevent, which is why the string source authors `·` as `·`.

3. **The string source and its lint are scoped to the Angular client**, as the AC itself words it (*"any user-facing literal **in the client**"*). Server-authored copy stays where its own `final` ADs put it: descriptor empty-state text and command-box aliases in ObjectScript (AD-5), and the envelope's `reason` minted at the port boundary (AD-39). Recorded here so review does not reopen it as a contradiction: a tree-wide single string source would contradict two adopted ADs and would be a spine change, not a story decision.

4. **"Every Material 3 role carries its Lantern value" means override where Lantern values a role, inherit where it does not.** Lantern values 30 M3 roles; Material's system also emits `scrim`, `shadow`, `surface-tint`, `inverse-primary`, `background`/`on-background` and the `*-fixed*` family, for which `DESIGN.md` publishes no hex. The document settles it twice: *"Whatever the sections below do not override inherits Material 3 as-is"* (693) and `confirm-dialog.scrim: 'Material default'` (518). **Invent no hex.** Calling `mat.theme(...)` and then re-pointing only the 64 Lantern roles is the mechanism that makes this literally true.

5. **"An automated contrast check over the rendered token pairs" is computed from the shipped token stylesheet, in both modes.** There is no component test tier — no `test` architect target, no runner installed — and this story does not need one: every acceptance criterion here is a property of authored sources or of the built artifact, and the one criterion phrased as a review ("when any component is reviewed") has no component to review in this story. Parsing the shipped stylesheet and computing WCAG 2.1 ratios tests the artifact that ships, and it goes red on a mistyped hex, which is the failure mode that actually threatens a 128-value transcription. What it does **not** cover, stated plainly so no one reads more into it: browser-composited rendering, and the alpha-blended treatments `DESIGN.md` expresses as prose (`on-shell` at 72% / 45% / 80%), which are not tokens and belong to the stories that draw them.

6. **"Fails the build" means `npm run build` exits non-zero before compilation.** There is no CI in this repository — no `.github/`, no workflow file — so the phrase has no server-side meaning to appeal to. `prebuild` is the only mechanism that makes it literally true, and it is already the house pattern (the version guard uses it). Two consequences worth stating: a bare `ng build` or `ng serve` bypasses `prebuild`, which is why `prestart` is wired too; and adding the rules to `check-objectscript.py` instead would have made the AC **false**, because that checker is a commit gate, not a build gate. The pre-commit hook wiring is the second gate, not the primary one.

7. **Five faces, not four.** The ramp declares weights 400 and 600, but `DESIGN.md`'s own component values use `caption` at **500** (`area-tile.label-typography`, 681) and `code` at **600** (`diff-row.after`, 484). Vendoring Inter 400/500/600 and JetBrains Mono 400/600 is what stops a later story silently rendering a synthesized faux weight. This adds a font file; it does not add a text role, so the "six roles and no others" AC is untouched.

8. **`#2090A0` is not a color role and must still not be hardcoded.** `DESIGN.md` rule 2 keeps the logo's vivid teal *"deliberately out of the token set"* because white on it is 3.78:1 — it must never sit under text or fill an area. Both facts are kept: it ships as a custom property in the token stylesheet (so the two gradients Story 1.10 and Epic 5 draw need no literal and the lint stays total) and it is **excluded from the 64-role roster**, has no `on-` partner, and carries a comment saying why. The elevation shadows `DESIGN.md` states are handled the same way — they contain color literals, so they belong in the one file permitted to hold them.

9. **SCSS, and Material's own theming API.** The spine pins neither SCSS nor CSS and names no lint tooling, so both are this story's decisions. Angular Material 22's theming API is Sass — verified on disk, not recalled: `@mixin theme($config, $overrides)` at `ui/node_modules/@angular/material/core/tokens/_system.scss:57`, forwarded from `_index.scss:21–23`, whose doc comment states *"The application variables emitted use the namespace prefix `--mat-sys`"*. `sass@1.101.0` already resolves through `@angular/build@22.1.5`, so `.scss` compiles with **no dependency change**. Using `mat.theme(...)` is what delivers "Material's anatomy inherited unchanged"; hand-writing `--mat-sys-*` without it would leave Material's components unthemed.

**The mechanism, in short** (the one non-obvious shape in the story):

```scss
:root {
  --ocu-shell: #0F3A5F;        /* light, on the bare role */
  --ocu-shell-dark: #0B2440;   /* dark, under <role>-dark — both always present */
}
html { @include mat.theme((color: (...), typography: (...), density: 0)); }
:root { --mat-sys-primary: var(--ocu-primary); /* … 64 roles … */ }
:root.ocu-theme-dark { --mat-sys-primary: var(--ocu-primary-dark); /* … */ }
```

Both sets are declared unconditionally on `:root`, which is what `<role>-dark` naming asks for and what lets the contrast checker read both modes out of one stylesheet. The dark **scope** is a root class so the deferred toggle (spine `## Deferred` → *Theme toggle wiring → Polish week, FR-73*) really is a flag flip. Ship the scope; do not ship a control. Note the specificity ordering — `:root` (0,1,0) beats `html` (0,0,1), and the dark block must follow the light one.

**String keys.** The table gives no identifier to any string — the only naming input is a prose *Where* column, and several rows cover a dozen strings at once, so keys cannot be derived one-per-row. Convention for this story: a flat object, `camelCase`, with a domain prefix taken from the *Where* column (`agent*`, `auth*`, `proposal*`, `table*`, `command*`, `form*`, `status*`, `action*`, `nav*`). Flat keeps the linter's "is this value in the source" question a single lookup.

**What is mechanized and what is not, stated honestly.** The voice rules mechanize cleanly over the shipped source (no `!`, no `"Oops"`, no emoji, no `"successfully"`) and are tested. The seven color rules mechanize in part — rule 1's *"the light focus ring is 1.18:1 on the shell and must never be drawn there"*, rule 3's teal-on-`code-surface` at 2.69:1 and rule 7's 60% expired card all become entries in the never-draw list, so a later story that reaches for one turns the checker red. The remainder of the seven rules, and the agent-voice rules beyond the shared prohibitions, are authoring rules with no component to check in this story; they are recorded in the token and string source headers where the next author will read them, and they become reviewable when Story 1.10 and Epic 5 draw the surfaces. Claiming a test for them here would be the vacuous-assertion failure Rule 19 exists to stop.

**One recommendation for the lead (Rule 20, not this story's write).** The spine fixes `ui/src/app/areas/<area>/`, `shell/` and `core/` but names no home for global stylesheets, vendored fonts or the string source. This story places them at `ui/src/styles/`, `ui/src/assets/fonts/` and `ui/src/app/core/strings.ts`, and adopts SCSS. Those are conventions later stories will drift on, so they belong in a Consistency Conventions row.

## Verification

**Commands:**

- `cd ui && npm run build` -- expected: the version guard and the client lint both pass, `ng build` succeeds, and `dist/ocupilot-ui/browser/` carries hashed `main-<hash>.js`, `styles-<hash>.css` and the `woff2` faces.
- `cd ui && node --test tools/` -- expected: every file passes with zero failures, including the token, contrast, typography, string, lint and build-output suites.
- `cd ui && node tools/client-lint.mjs` -- expected: exit 0 over the real tree; exit 1 naming file, line and rule against each fixture.
- `uv run scripts/check-objectscript.py` -- expected: exit 0 over `src/OcuPilot/**` and `ui/**` (a bare `python3` runs outside the project environment).
- `bash scripts/lint-docs.sh` -- expected: exit 0 over the authored Markdown; British spellings are rejected.
- `grep -rIn -E "url\(\s*['\"]?https?://|@import[^;]*https?://|src=['\"]https?://|<link[^>]+href=['\"]https?://" ui/src ui/dist/ocupilot-ui/browser` -- expected: no matches. Scan the fetch-causing references, not every `https://` byte: Angular's runtime embeds `angular.dev` error URLs, `extractLicenses` emits `3rdpartylicenses.txt`, and the vendored OFL text carries the licence URL, so a blanket scan reports three false positives and proves nothing.

**Mutations (Rule 19 — one per acceptance criterion and per pinning test; after each, revert and confirm `git status --short` and `git diff --stat` are unchanged):**

- mutation: delete one `--ocu-<role>-dark` declaration from the token stylesheet → the roster-completeness test in `design-tokens.test.mjs` goes red naming that role's missing dark side.
- mutation: change one token hex to a neighbouring value (e.g. `--ocu-secondary` from its Lantern value to `#0B7081`) → the value-fidelity test goes red naming the role, the shipped value and the document value.
- mutation: swap the light and dark values of `restrained` → the load-bearing contrast test goes red on the `restrained`/`restrained-container` row, reporting computed against published.
- mutation: raise `on-secondary-container`'s dark value toward `secondary-container` → the marginal-guard test goes red on the `restrained` gated-reason remedy pair.
- mutation: move one of the four rejected pairs into `LOAD_BEARING` → the rejected-pairs test goes red naming the pair that must never be drawn.
- mutation: change the `label` role's weight from 600 to 700 → the type-ramp test and the no-weight-700 assertion in `typography.test.mjs` both go red.
- mutation: add a seventh text role to the typography layer → the "six roles and no others" assertion goes red naming the extra role.
- mutation: point one `@font-face` `src` at `https://fonts.gstatic.com/...` → the no-external-host assertion in `typography.test.mjs` goes red, and the built-output host scan in `build-output.test.mjs` goes red.
- mutation: delete `ui/src/assets/fonts/`'s JetBrains Mono 600 file → the font-emission assertion in `build-output.test.mjs` goes red naming the absent face.
- mutation: add `color: #FF0000` to `ui/src/styles/_typography.scss` → `client-lint.mjs` exits non-zero and `npm run build` aborts before `ng build`; `client-lint.test.mjs`'s hardcoded-color case goes red if the rule is removed instead.
- mutation: remove the token stylesheet from the lint's exemption path → `client-lint.test.mjs`'s exemption case goes red, showing the exemption is by exact path and not by a pattern that would widen.
- mutation: replace the interpolation in `app.ts`'s template with the literal text it renders → `client-lint.mjs` exits non-zero naming that file and line, and `npm run build` aborts.
- mutation: respell one canonical string in the string source (change a `·` to a hyphen) → the string-completeness test goes red naming the literal that no longer matches the table.
- mutation: append `!` to any string value → the voice-rule test goes red naming the key and the rule.
- mutation: write `co-pilot` without a preceding `agent` in any file under `src/OcuPilot/` or `ui/` → `uv run scripts/check-objectscript.py` exits non-zero naming file, line and rule.
- mutation: remove the `@media (prefers-reduced-motion: reduce)` block from the metrics layer → the reduced-motion assertion in `typography.test.mjs` goes red.
- mutation: change `app.ts` to render a literal not present in the string source, or delete the shell token declaration → the Rule 1 integration assertions in `build-output.test.mjs` go red, reporting which of the two the shipped bundle no longer carries.

**Manual checks:**

- Confirm `ui/src/styles.css` is deleted and `angular.json` names `src/styles.scss`, so exactly one stylesheet entry point exists.
- Confirm `ui/angular.json` still declares only the `build` and `serve` targets and only `@angular/build:*` builders — adding an `ng lint` target with a third-party builder turns `angular-json.test.mjs` red.
- Confirm every non-ASCII character in `strings.ts` and the SCSS partials is a `\uXXXX` escape and not a literal byte (Rule 14).

## Auto Run Result

Status: ready-for-dev
Blocking condition: none
