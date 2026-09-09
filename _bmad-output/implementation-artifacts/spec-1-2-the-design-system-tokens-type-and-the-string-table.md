---
title: 'Story 1.2 — The design system: tokens, type and the string table'
type: 'feature'
created: '2026-09-09'
status: 'done'
baseline_revision: '9ea8554bd441a1b0b58f8623df2e52b39ef4c065'
baseline_commit: '9ea8554bd441a1b0b58f8623df2e52b39ef4c065'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/DESIGN.md'
  - '{project-root}/_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md'
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
warnings: ['multiple-goals', 'oversized']
deferred:
  - summary: >-
      check-objectscript.py (including the new check_product_vocabulary rule this
      story adds) has no persisted automated test of its own -- only a one-time
      manual mutation check was run during implementation and review.
    evidence: |-
      A repo-wide search finds no test file for scripts/check-objectscript.py.
      deferred-work.md's DW-35 already tracks this gap for the script's original
      four checks, routed to Story 1.17 (which owns CI/Python test tooling);
      check_product_vocabulary is new code landing in that same untested script,
      not a fresh gap. During review, constructed fixtures (bare "co-pilot",
      "agent co-pilot", "Agent co-pilot", "reagent co-pilot", double-spaced and
      line-wrapped "agent"/"co-pilot") were run against the real script by hand
      and all detected correctly after the regex fix below -- so this is a missing
      regression-safety net, not a current defect.
    location: >-
      scripts/check-objectscript.py:323 (check_product_vocabulary)
    severity: low
  - summary: >-
      Two I/O & Edge-Case Matrix rows -- "Non-role color literals are quarantined"
      and "Scale and metrics" -- have real, passing pinning tests but no
      corresponding `mutation:` line in this spec's own `## Verification` section,
      unlike every other matrix row.
    evidence: |-
      The Mutations list under `## Verification` predates this implementation
      (unchanged by this diff) and never covered either row. Both rows are still
      covered by a real, passing test (design-tokens.test.mjs's non-role-literal
      tests; typography.test.mjs's scale/radii/heights/metrics tests), so the
      Matrix Test Audit itself is unaffected -- this is a documentation-completeness
      gap in the spec's own Verification section that predates this story's
      implementation.
    location: >-
      spec `## Verification` (Mutations list)
    severity: low
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

### 2026-09-09 — Review pass
- verdicts: 27 findings — high 0, medium 10, low 17, false 0, maybe-false 0
- findings:
  - `[low]` `[patch]` scripts/check-objectscript.py's module docstring undercounts its own checks ("four ACs") after a fifth was added — confirmed the header still said "four" once `check_product_vocabulary` was wired into `main()`; updated the docstring to "five" and added item 5.
  - `[low]` `[patch]` The product-vocabulary regex's fixed-width lookbehind lacks a word boundary, so a compound word ending in "agent" (e.g. "reagent co-pilot") wrongly passes — verified in Python that `(?<!agent )co-pilot` misses this; replaced the lookbehind with a whole-preceding-word check (one fix, shared with the next row) that catches it.
  - `[low]` `[reject]` strings.test.mjs hardcodes EXPERIENCE.md's table row range (252–302) instead of an anchor-derived range like `parseDesignDocColors` uses for DESIGN.md — real robustness gap, but the spec's own Design Notes direct exactly this literal-line-number approach throughout, and a correct anchor-based rewrite needs new markdown-table-boundary detection, not a direct correction.
  - `[medium]` `[patch]` client-lint.mjs's header claims `{{ STRINGS.<key> }}` passes uniformly, but a copy-bearing attribute (`aria-label="{{ STRINGS.productName }}"`) holding exactly that shape was still flagged `no-literal-copy-attribute` — verified directly; fixed by exempting an attribute value that is exactly one allowed STRINGS interpolation (shared fix with the EC row below), plus a regression test for the mixed literal+interpolation case that must still fail.
  - `[medium]` `[patch]` typography.test.mjs's "no font-size below 11px" regex matches any custom property ending in "-size", not only font sizes — verified a non-typographic metric like `--ocu-icon-button-size` would false-positive; narrowed the regex to `font-size:` and `--ocu-type-*-size` only, plus a regression test.
  - `[low]` `[patch]` _theme.scss's comment asserts the dark block "must follow" the light one for the override to work — false: `:root.ocu-theme-dark` is (0,2,0) vs `:root`'s (0,1,0), so specificity decides it regardless of order; corrected the comment.
  - `[low]` `[patch]` strings.ts's header enumerates domain prefixes but omits "tool*" (used by `toolCallStoppedByYou`) — confirmed, and while fixing it also found three more undocumented prefixes in actual use (`accessibility*`, `audit*`, `product*`); added all four.
  - `[low]` `[patch]` 13 metrics tokens declared in _metrics.scss (panel/locator/command-bar/content/icon/avatar measures) have no test tying them to DESIGN.md's published values, unlike every color role and type-ramp value — manually cross-checked all 13 against DESIGN.md lines 217–234 (all correct as shipped) and added the missing assertions, including a regex-based check for the `panel-home` calc() formula (shared fix with the Intent-Alignment row below).
  - `[low]` `[patch]` .githooks/pre-commit's closing failure summary names markdownlint and check-objectscript.py but never client-lint.mjs, so a client-lint-only failure gets a wrong-attribution remediation hint — confirmed; added a client-lint line to the summary block.
  - `[low]` `[patch]` Same defect as the lookbehind row above (word-boundary missing before "agent") — fixed together with it.
  - `[medium]` `[patch]` The same lookbehind also has the opposite failure: a legitimate "agent co-pilot" split by a double space or a line-wrapped comment is wrongly flagged as a bare "co-pilot" violation — verified in Python (`"the agent  co-pilot"` and `"agent"`/`"co-pilot"` split across a newline both false-positive); fixed by the same whole-preceding-word rewrite, tolerant of any whitespace run.
  - `[low]` `[reject]` build-output.test.mjs reads `distMediaDir` with `readdirSync` before confirming it exists, so a build that emits no fonts throws a raw ENOENT instead of a hand-crafted assertion — confirmed; rejected as a cosmetic error-message-quality gap, not a functional defect (the test still fails correctly).
  - `[low]` `[reject]` Same gap, for `index.html` in the same file — confirmed; rejected for the same reason.
  - `[low]` `[reject]` client-lint.mjs's `FUNCTIONAL_COLOR_RE` truncates at the first `)`, so `rgba(var(--x), 0.5)` reports a truncated literal ("rgba(var(--x)") — confirmed; the violation is still correctly detected and the build still fails, only the reported text is imprecise. Rejected: a correct fix needs a balanced-paren scanner, disproportionate to a purely cosmetic diagnostic issue with zero current occurrences in this tree.
  - `[medium]` `[patch]` client-lint.mjs's `findLiteralTextNodes` only scans content strictly between `>` and `<`, so a template with no tags at all (or literal text before the first tag / after the last tag) is entirely unreported — verified `` template: `Hello there` `` produces zero errors; rewrote the function to also scan the leading/trailing runs and the whole template when it has no markup at all, plus two regression tests.
  - `[medium]` `[patch]` client-lint.mjs's `COPY_ATTRIBUTE_RE` matches double-quoted attribute values only, so `aria-label='Close this dialog'` (single-quoted) is entirely unreported — verified directly; widened the regex to match either quote character via a backreference, plus a regression test.
  - `[medium]` `[patch]` Same defect as the "header claims interpolations pass uniformly" row above (sourced attribute interpolations wrongly rejected) — fixed together with it.
  - `[medium]` `[patch]` typography.test.mjs's "no font-size below 11px" test does not strip `//` comments before matching, unlike its sibling no-weight-700 test — verified a prose comment mentioning "font-size: 8px" would false-positive; added the same comment-stripping guard, plus a regression test.
  - `[medium]` `[patch]` typography.test.mjs's "no external host" test likewise does not strip comments — verified a prose comment mentioning `url("https://...")` would false-positive; added the same guard, plus a regression test.
  - `[medium]` `[patch]` Same defect and fix as the "no tags at all" row above (restated as a claim).
  - `[low]` `[reject]` The spec's Task list names `checkTemplateLiterals`'s parameter `allowedValues`; the shipped code and tests consistently use `allowedKeys` — confirmed, and `allowedKeys` is the functionally accurate name (it holds key names, not values); the only fix is to edit the spec's prose, which the classify rules bar outright ("reject any finding whose fix is to edit this build's spec").
  - `[low]` `[defer]` check-objectscript.py (including the new `check_product_vocabulary` rule) has no persisted automated test of its own, only a one-time manual check — arrives pre-verified from the verification-gap layer; matches the pre-existing DW-35 pattern for this same untested script, routed to Story 1.17 (owns CI/Python tooling); recorded in this spec's frontmatter `deferred:` list rather than building an inconsistent one-off Python harness ahead of that story.
  - `[medium]` `[patch]` client-lint.mjs's `prebuild`/`prestart` wiring in package.json is never exercised end-to-end — no test tells "client-lint ran during prebuild and passed" apart from "client-lint never ran" — arrives pre-verified from the verification-gap layer; added a test asserting both scripts invoke `tools/client-lint.mjs` after `tools/version-guard.mjs`, per the layer's own suggested fix.
  - `[low]` `[defer]` Two I/O & Edge-Case Matrix rows ("Non-role color literals are quarantined", "Scale and metrics") have real passing pinning tests but no `mutation:` line in this spec's own Verification section — confirmed the Mutations list predates this implementation diff and never covered either row; both rows are still covered by a real, passing test, so the Matrix Test Audit is unaffected. Recorded in frontmatter `deferred:` as a pre-existing spec-authoring gap.
  - `[low]` `[reject]` Two of the four REJECTED contrast pairs (`tokenPair: false`) assert `published.light/dark < floor` using literals declared on the same object, never against the shipped tokens — confirmed; rejected as by-design per the spec's own Design Notes #5, which explicitly authorizes not recomputing alpha-blended contrast from hex, and the AC's core "never drawn" guarantee is still fully tested for all four rejected pairs.
  - `[low]` `[reject]` Contrast-ratio "published" figures across LOAD_BEARING/MARGINAL_GUARDED/REJECTED are hand-transcribed literals checked only for self-consistency against the shipped hex, never live-parsed against DESIGN.md's text the way the hex color values are — confirmed; rejected because the intent-contract's own "Always" bullet directs "transcribe... never recompute a published ratio", matching what shipped, and a live parser for DESIGN.md's markdown-prose contrast tables is materially harder than the clean-YAML color parser, making the fix disproportionate to the risk.
  - `[low]` `[patch]` Same 13-untested-metrics-tokens gap as the row above (independently surfaced by the intent-alignment layer) — same fix applied there.

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

**Summary of implemented change.** Shipped the three sources the intent names — a
128-property Lantern color token layer wired through `mat.theme(...)` into Material
3's `--mat-sys-*` system, a typography/metrics layer with five vendored `woff2`
faces, and a 104-key canonical string source — plus the two build-failing linters
(`design-tokens.mjs`'s contrast math, `client-lint.mjs`'s hardcoded-color and
un-sourced-literal rules) and the `check-objectscript.py` product-vocabulary rule,
wired into `prebuild`/`prestart` and `.githooks/pre-commit`. `ui/src/app/app.ts`
renders `STRINGS.productName` under the `display` type role as the in-story
consumer (Rule 1). Review (blind-hunter, edge-case-hunter, verification-gap,
intent-alignment) surfaced 27 findings across 23 root causes; 0 were `high`, 10
`medium`, 17 `low`; 0 `intent_gap`, 0 `bad_spec`. 14 entries were patched directly
(re-engaging the step-03 subagent is not possible on this harness per Rule 18), 2
were deferred to the spec's frontmatter `deferred:` list, and 7 were rejected with
a recorded reason (by-design, cosmetic-only, non-trivial-fix-for-low-risk, or
fix-would-edit-the-spec). All patches were re-verified: the full `npm run build`,
`node --test tools/` (80/80, up from 70), `uv run scripts/check-objectscript.py`,
`bash scripts/lint-docs.sh` and the external-host `grep` were all re-run clean
after patching.

**Files changed:**

- `ui/src/styles/_tokens.scss` — new; 128 color-role custom properties (64 roles ×
  light/dark) plus the logo-gradient-stop and three elevation-shadow non-role
  literals, transcribed from `DESIGN.md`.
- `ui/src/styles/_theme.scss` — new; calls `mat.theme(...)` once and re-points the
  30 Lantern-valued `--mat-sys-*` roles at `--ocu-*`, light on `:root` and dark on
  `:root.ocu-theme-dark`. Patched: corrected a comment that wrongly claimed source
  order (not specificity) decides which block wins.
- `ui/src/styles/_typography.scss` — new; five `@font-face` blocks and the six-role
  type ramp with utility classes and a tabular-numeric cell rule.
- `ui/src/styles/_metrics.scss` — new; the 4px spacing scale, four radii, shell/
  row/control/panel/etc. metrics, and motion tokens with a reduced-motion override.
- `ui/src/styles.scss` — new entry point; `ui/src/styles.css` deleted.
- `ui/src/assets/fonts/` — new; five vendored `woff2` faces plus two OFL license
  texts.
- `ui/src/app/core/strings.ts` — new; 104-key canonical string source. Patched: the
  domain-prefix convention comment omitted `tool*` and, once checked, three more
  in-use prefixes (`accessibility*`, `audit*`, `product*`); added all four.
- `ui/src/app/app.ts` — renders `STRINGS.productName` under `ocu-type-display` (the
  in-story consumer, Rule 1).
- `ui/angular.json` — `styles` repointed to `src/styles.scss`.
- `ui/package.json` — `prebuild`/`prestart` now run `client-lint.mjs` after
  `version-guard.mjs`.
- `ui/tools/design-tokens.mjs` + `.test.mjs` — new; the color roster, WCAG contrast
  math, and the load-bearing/marginal-guard/rejected pair inventories, with a live
  parse of `DESIGN.md`'s color frontmatter for hex fidelity.
- `ui/tools/strings.mjs` + `.test.mjs` — new; the string-source parser, voice-rule
  checker and placeholder extractor, with the expected literal list re-derived from
  `EXPERIENCE.md` at test time.
- `ui/tools/client-lint.mjs` + `.test.mjs` — new. Patched three real detection gaps
  found in review: (1) a copy-bearing attribute holding exactly a sourced
  `{{ STRINGS.<key> }}` interpolation was wrongly rejected; (2) a single-quoted
  copy attribute (`aria-label='...'`) was entirely unreported; (3) a template with
  no surrounding tags at all, or literal text before the first tag/after the last
  one, was entirely unreported. Added 6 regression tests (5 for these gaps, 1
  asserting `package.json`'s `prebuild`/`prestart` wiring).
- `ui/tools/typography.test.mjs` — new. Patched: the "no font-size below 11px"
  check matched any `-size`-suffixed custom property, not only font sizes, and
  neither it nor the "no external host" check stripped `//` comments first
  (unlike their no-weight-700 sibling), so a prose comment could false-positive
  the whole build; added 13 previously-missing assertions for `_metrics.scss`
  tokens outside the AC's named subset, plus 4 regression tests.
- `ui/tools/build-output.test.mjs` — extended with font-emission, no-external-host
  and Rule 1 integration assertions against the real build output.
- `scripts/check-objectscript.py` — added `check_product_vocabulary` (a 5th
  check). Patched: the docstring still said "four ACs"; and the lookbehind regex
  (fixed-width, so it could only test for exactly one literal space) both missed a
  compound word ending in "agent" and falsely flagged legitimate "agent co-pilot"
  text split by extra whitespace or a line wrap — replaced with a whole-preceding-
  word comparison that fixes both directions (one narrow, very-low-likelihood
  residual gap accepted: a hyphenated compound like "non-agent" still reads as
  "agent" since the hyphen is not a word character).
- `.githooks/pre-commit` — runs `client-lint.mjs` on the existing `ui/**` trigger.
  Patched: the closing failure summary never named client-lint.mjs; added a line
  for it.
- `_bmad-output/implementation-artifacts/spec-1-2-....md` — this spec:
  `baseline_revision`, `status`, `deferred:` (2 entries), Review Triage Log, this
  section.

**Review findings breakdown** (see `## Review Triage Log` above for the full,
per-finding table; this summarizes disposition):

- Patched (14 entries, 20 of the 27 raw findings): the three client-lint.mjs
  detection gaps, the typography.test.mjs over-broad-regex and missing-comment-
  stripping gaps, the 13 missing metrics-token assertions, the product-vocabulary
  regex's two-directional bug, the untested prebuild/prestart wiring, and four
  documentation-accuracy fixes (check-objectscript.py's docstring, `_theme.scss`'s
  comment, `strings.ts`'s prefix list, `.githooks/pre-commit`'s summary message).
- Deferred (2 entries, frontmatter `deferred:`): `check-objectscript.py` (including
  the new rule) has no persisted automated test of its own — matches the
  pre-existing DW-35 pattern, routed to Story 1.17 which owns CI/Python tooling.
  Two matrix rows lack a `mutation:` line in this spec's own Verification
  section — pre-existing at `ready-for-dev`, and both rows are still covered by a
  real, passing test.
- Rejected (7 entries, with reason): a truncated-literal report on nested-paren
  color functions and two missing `existsSync` guards in `build-output.test.mjs`
  (cosmetic diagnostics only, detection/failure still correct); the two
  alpha-blended `REJECTED` contrast entries' self-consistency check (by-design,
  spec's Design Notes #5); the hand-transcribed (not live-parsed) contrast
  "published" figures (intent directs transcription; a markdown-table live parser
  is disproportionate to the risk); `strings.test.mjs`'s hardcoded EXPERIENCE.md
  line range (spec directs literal line numbers; an anchor-based rewrite is
  non-trivial); the spec's Task list naming `checkTemplateLiterals`'s parameter
  `allowedValues` where the code uses the more accurate `allowedKeys` (the only
  fix is a spec edit, barred outright by the classify rules).

**Follow-up review recommendation: true.** Two or more `medium`-verdict entries
were patched this pass (8: the two client-lint.mjs copy-attribute/text-node
detection fixes, the product-vocabulary whitespace false-positive, the
over-broad font-size regex, the two missing comment-stripping guards, and the
untested prebuild/prestart wiring). Specific unverified risk: these are eight
independent behavior changes to `ui/tools/client-lint.mjs` and
`ui/tools/typography.test.mjs` — a build-gating linter and its test suite — each
individually verified against a targeted fixture and against the real, unchanged
shipped tree (still clean), but not against a combined fixture exercising several
of the new edge-case rules at once (e.g., a single template mixing a single-quoted
sourced attribute, a leading text run, and a nested-paren color function). A
follow-up pass should specifically probe interaction effects across these
simultaneous client-lint.mjs changes before the many later stories that draw real
templates (1.9, 1.10, 1.12, Epic 5) start depending on this linter's exact
boundaries.

**Verification performed:**

- `cd ui && npm run build` — pass (version guard + client-lint clean; hashed
  `main`/`styles`/5 `woff2` files emitted).
- `cd ui && node --test tools/` — 80/80 pass (70 from implementation + 10 new
  regression tests from review patches).
- `cd ui && node tools/client-lint.mjs` — exit 0 over the real tree.
- `uv run scripts/check-objectscript.py` — exit 0 over `src/OcuPilot/**` and
  `ui/**`; independently re-verified the product-vocabulary fix with constructed
  fixtures (bare `co-pilot`, `agent co-pilot`, `Agent co-pilot`, `reagent
  co-pilot`, double-spaced and newline-split `agent`/`co-pilot`) before and after
  the patch, confirming the exact behavior change.
- `bash scripts/lint-docs.sh` — exit 0.
- The spec's external-host `grep` over `ui/src` and `ui/dist/ocupilot-ui/browser`
  — no matches.
- Matrix Test Audit: every one of the 17 I/O & Edge-Case Matrix rows (16 scenarios
  + the Integration row) has a covering test that ran and passed in the
  verification output above; none is covered only by a test that did not run.
- Manual checks (spec's own list): `ui/src/styles.css` deleted and `angular.json`
  names `src/styles.scss`; `angular.json` still declares only `build`/`serve` with
  only `@angular/build:*` builders; every non-ASCII character in `strings.ts` and
  the SCSS partials is a `\uXXXX` escape (confirmed by a byte-level scan — the one
  literal non-ASCII byte found anywhere in `ui/src/**/*.ts`/`*.scss` is a
  pre-existing em-dash in `main.ts`'s comment from Story 1.1, out of this story's
  footprint).

**Residual risks:**

- The follow-up-review risk named above (combined-edge-case interaction coverage
  in `client-lint.mjs`).
- One accepted, extremely-low-likelihood residual gap in the product-vocabulary
  check: a hyphenated compound word ending in "agent" (e.g. "non-agent co-pilot")
  still reads as a bare "agent" and would incorrectly pass, since a hyphen is not
  a word-boundary character for the whole-preceding-word extraction.
- Two deferred items (see frontmatter `deferred:` and the Review Triage Log above)
  carry no code risk to this story but should reach the epic's ledger per Rule 17.
- Pre-existing, out-of-footprint: `ui/src/main.ts` (Story 1.1) has one literal
  em-dash in a comment, a Rule 14 violation this story's footprint does not cover
  (noted by the implementation subagent, not re-verified or fixed here).

Status: done
Blocking condition: none
