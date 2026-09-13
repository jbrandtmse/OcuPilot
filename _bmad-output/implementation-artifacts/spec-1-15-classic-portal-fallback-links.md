---
title: 'Story 1.15: Classic portal fallback links'
type: 'feature'
created: '2026-09-12'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-1-context.md'
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** FR-9's promise — anything OcuPilot has not rebuilt is one click away — has no mechanism. The descriptor already carries `classicPage`, `classicLinkExemption.exempt` and `.reason` (`Base.cls:272-291`) and the mirror already carries them to the client, but nothing validates them, nothing renders a card, and no gate asserts that no list screen links out. `archetype` is free text that `Registry.Validate()`, `screen-mirror.mjs` and `check-objectscript.py` all ignore, so "only a detail view may declare an exemption" has no predicate to evaluate against.

**Approach:** Close the archetype vocabulary in one declarative class, add the refusal it makes possible on both sides — `Registry.Validate()` at install and a new build-time check in a gate — ship the `classic-link-card` the reduced forms of Epic 9 will render, and make the check **report its scanned population and every exemption it honors on every run** rather than exiting silently.

## Boundaries & Constraints

**Always:**
- The descriptor is the single source (AD-5). The archetype vocabulary is declared once, in `src/OcuPilot/Screen/Archetype.cls`; every other reader parses that file, never a second copy. A vocabulary that cannot be read is **reported**, never treated as an empty set (`check-objectscript.py:663-668` states the rule).
- `classicPage` stays the classic **class name** (AD-44). It is the AD-8 privilege-union key (`Gate.RequiredPairs():69-78`) and is never a link; no code path derives a URL from it.
- An exemption is permitted only on an archetype the vocabulary classifies `detail`. `list`, `none`, and any archetype absent from the vocabulary are refused. The default is "may not link out", so a mis-classification fails closed.
- The check prints its scanned descriptor count, the per-class tally and one line per honored exemption on **every** run, clean or not, and exits non-zero only on a refusal.
- The check's population is asserted twice: it reads descriptors through `screen-mirror.mjs`'s `readSources()` (`:148`, which throws naming the file rather than skipping — `:174`), and it independently counts `.cls` files under `DESCRIPTOR_DIR` (`:42`) minus `Base.cls`, refusing when the classified set is smaller.
- The check runs in a gate: `ui/package.json`'s `prebuild` and `prestart` chains, and `.githooks/pre-commit`'s existing `OS_TRIGGER` block beside `client-lint` (`:93`).
- Card copy comes from `strings.ts` and colors from the token layer. The title is the published `classicLinkCardTitle` (`strings.ts:232`); no new user-facing literal is authored and `REQUIRED_ALONGSIDE_TABLE` (`strings.test.mjs:195`) does not grow.
- New-tab links follow the shipped house pattern: `target="_blank" rel="noreferrer"` plus `.ocu-external-glyph` (`instance-notice.ts:51-60`, `_components.scss:289`).

**Never:**
- No derivation of a classic URL from a class name — none is verified, and the `/csp/sys/{exp,mgr,op,sec}` sub-application a portal class is served under is not a function of its class name.
- No invented UI copy, no growth of `REQUIRED_ALONGSIDE_TABLE`, no edit to EXPERIENCE.md or DESIGN.md (DW-126 and DW-139 are the owner's, escalated).
- No second archetype list, no second exemption predicate, no per-screen link-out implementation.
- No `window.open` and no popup; the card's anchor is the only new-tab surface this story adds.
- No write to `%SYS.Portal.Resources` — the custom-resource store is empty on this instance and stays empty; the seam is `Test/ScreenGate.cls`'s `ClassicResource()` override (`:49`).
- Not in scope: any reduced form (Story 9.9), the OAuth tabs' exemption (Story 6.4), its removal (Story 12.9), or any list screen or data table (Epic 2).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Sound production roster | Home (`archetype: "home"`, `classicPage: "%CSP.Portal.Home"`, `exempt: false`) | exit 0, printing the scanned count, the per-class tally and `0 exemption(s) honored (SM-C1)` | — |
| A detail view exempts | `archetype: "detail"`, `exempt: true`, non-empty `reason`, `label`, same-origin `href` | honored; one report line naming descriptor, archetype, reason, label and href; honored count 1 | — |
| **A list archetype exempts** | `archetype: "list"`, `exempt: true` | refused, naming the descriptor file and the archetype | exit 1; `Registry.Validate()` returns the same sentence prefixed with the class name |
| An archetype outside the vocabulary | `archetype: "lst"` | refused, naming the value and `Archetype.cls`; `screen-mirror.mjs` throws the same way | exit 1 / build fails |
| The vocabulary cannot be read | `Archetype.cls` missing or its XData unparseable | refused, naming the file | exit 1 — never read as "no archetypes, therefore nothing to check" |
| An exemption missing a required part | `exempt: true` with an empty `reason`, or no `label`, or no `href` | refused, naming the missing part | exit 1 |
| An off-origin or non-root href | `https://elsewhere/x`, `//host/x`, `../x` | refused | exit 1 — a descriptor is not an egress primitive (AD-47) |
| Link parts without an exemption | `exempt: false` with a non-empty `href` or `label` | refused | exit 1 |
| An exemption with no classic equivalent | `classicPage: ""`, `exempt: true` | refused | exit 1 |
| A descriptor the reader did not return | a `.cls` under `DESCRIPTOR_DIR` absent from `readSources()`'s result | refused: the scanned count is below the file count | exit 1 — the check cannot pass by looking at nothing |
| Card over an exempt descriptor | a descriptor with an honored exemption | the published title, and one `button-secondary` anchor labeled with the declared `label`, `href` the declared target, `target="_blank" rel="noreferrer"`, plus the external glyph | — |
| Card over a non-exempt descriptor | Home | nothing renders — no card, no anchor | — |
| **DW-173** — the paused chip in a narrow bar | `.ocu-command-bar-refresh` carrying the 55-character paused literal | the chip truncates with an ellipsis inside its own box and the row does not reflow | asserted as stylesheet text: jsdom computes no layout |

</intent-contract>

## Code Map

- `src/OcuPilot/Screen/Descriptor/Base.cls` — `Archetype()` `:123`; `ClassicPage()` `:272`; `ClassicLinkExempt()` `:279` / `ClassicLinkExemptionReason()` `:286`; `NestedField()` `:333` is the accessor to copy. `:277-278` already states this story's rule.
- `src/OcuPilot/Screen/Descriptor/Home.cls` `:29`, `:44-45` — the classic fields. Unchanged here; Home is the check's entire production population.
- `src/OcuPilot/Screen/Area.cls` — `XData Areas` `:34-46` + `Exists()` `:113` / `PrivilegePairs()` `:121`: the declarative-vocabulary shape to copy.
- `src/OcuPilot/Screen/Registry.cls` — `Validate()` `:124-201`, refusal shape `:183` and its status mirror `:199`; `RefreshProblem()` `:213-243` is the **public, value-driven** helper to copy (`MalformedPair()` `:250` is the private counter-example).
- `src/OcuPilot/Screen/Gate.cls` `:69-78` (the AD-8 union), `:135` `ClassicResource()`. Read-only here.
- `ui/tools/screen-mirror.mjs` — `DESCRIPTOR_DIR` `:42`, `extractXData()` `:69`, `readSources()` `:148` (throws at `:174`), `buildMirror()` `:269` with its refusals `:286/:293/:301/:308`, the `EntityTypeKey` union emission `:337`/`:402`, `ClassicLinkExemption` `:368`, `--check` `:437`.
- `ui/tools/client-lint.mjs` `:309`/`:332`/`:346` — the export/main split, the shape for a new Node check.
- `scripts/check-objectscript.py` `:663-668` — "a vocabulary that cannot be read is reported, not treated as empty", stated verbatim.
- `ui/tools/design-tokens.test.mjs` `:424-470` — the **DW-145** stylesheet-text assertion, its "jsdom computes no layout" rationale and its `doesNotMatch(/display:\s*inline-flex/)` guard.
- `ui/src/styles/_components.scss` — `.ocu-command-bar` `:1290-1298` (no `min-width: 0`), spacer `:1373`, `.ocu-command-bar-refresh` `:1377-1383` (DW-173); the shipped DW-145 fix `:1494-1499` + `:1507-1523`; `.ocu-external-glyph` `:289`; `.ocu-signin-card` `:122-133`; `--ocu-card-padding` `_metrics.scss:56`.
- `ui/src/app/shell/instance-notice.ts` `:7-8`, `:51-60` — the shipped new-tab anchor, and the only classic-portal href in the client.
- `ui/src/app/core/strings.ts` `:232`; `ui/tools/strings.test.mjs` `:48-67` the run-time extractor, `:315-319`/`:321-330` the both-directions tests, `REQUIRED_ALONGSIDE_TABLE` `:195`.
- `ui/src/app/shell/command-bar.ts` `:111-120`/`:213-227`; `command-bar.spec.ts` `:261-279` the paused-literal assertion.
- `ui/src/app/shell/screen-outlet.ts` `:90-108` (`data-archetype` `:94`); `ui/src/app/areas/home/home.page.ts:112-142` + `.ocu-home` `_components.scss:1568-1573` — the column-flow page root a card is the last child of.
- `src/OcuPilot/Test/Screen/` — `Multi.cls` `:21`/`:35` is the tree's only exemption (`form-page`); the other five are `list`, `exempt: false`. **No `detail` fixture and no list-with-exemption fixture exists.**
- `src/OcuPilot/Test/Descriptor.cls` `:111-112` (today's only classic assertions), `:181-196` (fixture-registry refusal pattern), `:265-290` (driving a public helper as values); `src/OcuPilot/Test/RefreshRegistry.cls:1-12` (one fault per registry, and why).
- `.githooks/pre-commit` `:75-78` `OS_TRIGGER`, `:82`/`:93` the two dispatches and their scope comment; `ui/package.json` `:7`/`:9`.

## Tasks & Acceptance

**Execution:**
- `src/OcuPilot/Screen/Archetype.cls` — **new**: one `XData` block declaring every archetype key EXPERIENCE.md `:507-521` publishes with its link-out class (`list` | `detail` | `none`), plus `Exists()` and `LinkOutClass()` modeled on `Area.cls:113`/`:121` — the single source both the instance and the build read.
- `src/OcuPilot/Screen/Descriptor/Base.cls` — add `ClassicLinkHref()` and `ClassicLinkLabel()` over `..NestedField("classicLinkExemption", …)`; document that the target is **declared**, never derived from `classicPage`.
- `src/OcuPilot/Screen/Registry.cls` — add public `ClassicLinkProblem(pArchetype, pClassicPage, pExempt, pReason, pLabel, pHref)` beside `RefreshProblem()` and call it from `Validate()` after the refresh check `:185`, so a malformed exemption fails at install rather than at render.
- `ui/tools/classic-links.mjs` — **new**: `checkClassicLinks()` + `main()` on `client-lint.mjs:346`'s export/main split. Reads the vocabulary from `Archetype.cls` (reporting on a read failure, never defaulting), the population through `readSources()`, and independently counts `DESCRIPTOR_DIR`'s `.cls` files. Prints the scanned count, the per-class tally and one line per honored exemption every run; exits 1 on any refusal.
- `ui/package.json` — add `node tools/classic-links.mjs` to the `prebuild` and `prestart` chains.
- `.githooks/pre-commit` — add the dispatch inside the existing `OS_TRIGGER` block beside `client-lint` `:93`, with the same `command -v node` guard and a scope comment saying the two scopes must agree.
- `ui/tools/screen-mirror.mjs` — carry `classicLinkExemption.href` and `.label` into `ScreenDeclaration`; emit an `ArchetypeKey` union parsed from `Archetype.cls` (the `EntityTypeKey` precedent `:337`/`:402`) and throw on an archetype outside it, in the shape of `:293`.
- `ui/src/app/core/screens.generated.ts` — regenerate with `node tools/screen-mirror.mjs`; **generated, never hand-edited**.
- `ui/src/app/shell/classic-link-card.ts` — **new** standalone `OnPush` component: the published title, and a `button-secondary` anchor labeled with the descriptor's declared `label`, href its declared target, `target="_blank" rel="noreferrer"`, plus `.ocu-external-glyph`. Renders nothing at all when the descriptor declares no honored exemption.
- `ui/src/styles/_components.scss` — add `.ocu-classic-link-card` from DESIGN.md `:662-671` (surface-container-low, 1px **dashed** outline-variant, `rounded.md`, card padding, title type); and fix **DW-173** by the DW-145 recipe — `min-width: 0` on `.ocu-command-bar`, and `flex: 0 1 auto`, `box-sizing: border-box`, `display: inline-block`, `max-width: 100%`, `min-width: 0`, `overflow: hidden`, `text-overflow: ellipsis` and an explicit `line-height` on `.ocu-command-bar-refresh`.
- `ui/tools/classic-links.test.mjs` — **new**: every I/O matrix row above the card rows, over a synthetic descriptor tree; plus the gate-wiring assertions (the check is named in `prebuild`, in `prestart`, and in `.githooks/pre-commit`).
- `ui/tools/design-tokens.test.mjs` — extend: the DW-173 stylesheet-text pin on `.ocu-command-bar-refresh` and the `min-width: 0` on its row (mirroring `:424-470`, `doesNotMatch` on `display: inline-flex` included), and the `.ocu-classic-link-card` token pins.
- `ui/tools/screen-mirror.test.mjs` — extend: the two new sub-fields carry through, and an archetype outside the vocabulary is refused.
- `ui/src/app/shell/classic-link-card.spec.ts` — **new**: the card's DOM, its anchor attributes, and its absence without an exemption.
- `src/OcuPilot/Test/Screen/Detail.cls` — **new** sound fixture: a `detail` archetype carrying an honored exemption, so the honored path is not pinned only by a synthetic tree.
- `src/OcuPilot/Test/ClassicLink/Bad.cls` + `src/OcuPilot/Test/ClassicLinkRegistry.cls` — **new**: a `list` declaring an exemption, on its own registry per `RefreshRegistry.cls:1-5` (one fault per registry, because `Validate()` reports only the first).
- `src/OcuPilot/Test/Descriptor.cls` — extend: `ClassicLinkProblem()` driven as values, the fixture-registry refusal, `Archetype.Exists()` and `LinkOutClass()` over the published vocabulary, and that the sound roster still validates clean.

**Acceptance Criteria:**
- Given the descriptor set, when the build-time check runs, then it names how many descriptors it scanned and how many exemptions it honored — on every run, including one that honors none — so a check that looked at nothing is distinguishable from a check that found nothing wrong.
- Given a descriptor whose archetype the vocabulary does not classify `detail`, when it declares `classicLinkExemption.exempt` true, then both the build-time check and `Registry.Validate()` refuse it, each naming the descriptor and the archetype.
- Given the check, when the repository is committed or the bundle is built, then the check has already run: it is named in `ui/package.json`'s `prebuild` and `prestart` chains and in `.githooks/pre-commit`, and a test asserts all three — a checker wired into no gate is the defect this criterion exists to prevent.
- **Integration AC (Rule 1).** Given `ClassicLinkCard` mounted over a descriptor read from the **real generated mirror**, not a hand-built literal, when it renders for a descriptor with an honored exemption, then the DOM carries the published title and exactly one anchor whose `href` is the declared target, whose visible label is the declared page name, and whose attributes are `target="_blank"` and `rel="noreferrer"`; and mounted over Home it renders no anchor at all.
- Given `classicPage`, when anything in this story reads it, then it serves only as AD-8's privilege-union key and never as a link target — no code path derives a URL from a class name (AD-44).
- **DW-173.** Given the command bar narrower than the paused chip's 55-character literal, when the chip renders, then it truncates with an ellipsis inside its own box and the row does not reflow — pinned as stylesheet text, since jsdom computes no layout.

## Spec Change Log

## Review Triage Log

## Design Notes

**Governing ADs (Rule 6).** AD-44 (the classic key is a class name; the list-versus-detail link-out rule, declared in the descriptor, with the check reporting every exemption it honors), AD-5 (the descriptor is the single source), AD-8 (the privilege union `classicPage` keys), AD-27 (the classic link is the user-visible fallback when a route stops working), AD-19 (standalone, `OnPush`), AD-47 (the origin is a trust boundary — the card's target must be same-origin), AD-11 (nothing rendered issues a request to another host), AD-21 (no caller-supplied path), AD-43 (the chip DW-173 bounds). The Consistency Conventions row at spine `:526` is this story's contract in one line.

**Consumes:** Story 1.9 — the descriptor registry, `Gate.RequiredPairs()`, `screen-mirror.mjs`. Story 1.10 — the command bar's flex row. Story 1.2 — `strings.ts`, the token layer, `client-lint.mjs`. Story 1.12 — the DW-145 truncation recipe and its stylesheet-text assertion. Story 1.14 — the chip this story bounds.

**Consumed-by:** Story 6.4 (`6-4-the-oauth-2-0-screen`) — the first descriptor to declare an honored exemption, and Release 1's count of one against SM-C1. Story 9.9 (`9-9-a-cut-editor-ships-reduced-never-half-working`) — the first reduced form to render the card. Story 12.9 (`12-9-removing-the-classic-link-outs`) — removes the exemption and returns the honored count to zero. Every Epic 2 list descriptor is checked by this gate from the moment it lands.

**Integration ACs (Rule 1) — the card has no consumer in this story.** Home is Epic 1's only screen and it is not a reduced form, so nothing renders the card in shipped chrome. The first consumer is **Story 9.9**; the first honored exemption is **Story 6.4**. The Integration AC above therefore exercises the component against the real generated mirror, which is the strongest crossing available here.

**Decision (overnight) — the archetype vocabulary is closed here, because the criterion's predicate has nothing to evaluate otherwise.** `archetype` is free text today, ignored by `Registry.Validate()`, `screen-mirror.mjs` and `check-objectscript.py` alike, so "only a detail view may declare an exemption" would answer "not a detail view" for a typo and pass. One declarative class holds the keys EXPERIENCE.md `:507-521` publishes and classifies each: `list`, `list (two views)`, `list (server criteria)`, `log-viewer`, `drill-down` → `list`; `detail`, `form-page`, `form-page (tabs)`, `wizard` → `detail`, since a reduced form is a form-page (EXPERIENCE.md `:409`) and epics `:3325` calls the OAuth tabs detail views; `meters`, `viewer (OpenAPI)`, `dialog`, `home`, `panel`, `shell`, `external` → `none`. Everything not `detail` fails closed, so a mis-classification refuses a link rather than permitting one. This constrains every later descriptor and is a Consistency-Conventions-row candidate for the lead under Rule 20; it implements AD-44's Rule and contradicts nothing.

**Decision (overnight) — the card's link target is declared, not derived.** AD-44's "never a URL" is scoped to the **resource key**, and the Rule's own reason clause says so: "the classic portal keys custom page resources by the normalized class name … so a descriptor declares the class it replaces, never a URL" *(inference — the scoping reads off that reason clause)*. `classicPage` stays that key. The card still needs somewhere to go and no derivation exists: `NormalizePage` (`irissys/%SYS/Portal/Resources.cls:97-164`) runs URL → class only, the vendor publishes no inverse, and the `/csp/sys/{exp,mgr,op,sec}` sub-application a portal class is served under is not a function of its class name and carries its own resource (probed read-only on `ocupilot-iris`; `%SYS_Portal.Resources` holds zero rows and was not written). So the target and the page's own name are declared inside the existing `classicLinkExemption` object as `href` and `label`, valid only alongside `exempt: true`, the href refused unless it is a root-relative same-origin path (AD-47). No new top-level field: the four link-out facts stay in one place.

**Decision (overnight) — the card ships without the caption; that is a fresh DW-126 occurrence.** EXPERIENCE.md `:351` and DESIGN.md `:1098` both *describe* a caption ("a caption notes that the classic portal may ask the user to sign in again") and neither publishes its literal; the Fixed-strings table publishes exactly one classic-link row, the title, at `:294`. Authoring the sentence is invented copy, which `strings.test.mjs:321-330`'s converse test fails and which `REQUIRED_ALONGSIDE_TABLE` may not absorb. The card therefore ships title plus action, the caption slot **absent** rather than filled with a placeholder. The action's label is the declared classic page name — descriptor data naming an external page, like `classicPage` itself, not shell copy the Fixed-strings table governs — which also meets the "names the classic page it opens" clause without inventing a button label. The caption clause is unimplementable as worded until the owner publishes the literal; recorded, not resolved.

**Decision (overnight) — "recorded against SM-C1" is met by a stable, parseable count line.** SM-C1 is expanded in no planning artifact; `epics-review-report.md:281` records exactly that, so there is no register to write into. The check emits `classic-links: N exemption(s) honored (SM-C1)` on every run — durable, greppable, consumable by whatever SM-C1 resolves to. Naming the metric is the owner's.

**DW-173 — addressed, by the DW-145 recipe.** The two are the same defect, and `spec-1-12-home.md:151`/`:195` record that four properties were not enough: `text-overflow` does not apply to a flex container (hence `display: inline-block`) and `max-width: 100%` caps the content box with no global reset (hence `box-sizing: border-box`). The chip additionally needs the row able to shrink it — `.ocu-command-bar` carries no `min-width: 0` and the chip is `flex: 0 0 auto` — so both change. **No number is invented:** the bound is `max-width: 100%` against a shrinkable row, so the chip truncates only under real pressure, which keeps the fix inside DW-173's "no published design covers the narrow case". DW-139 does not bite here: DESIGN.md `:662-671`/`:1096-1098` and EXPERIENCE.md `:351`/`:409` agree on the card's surface, dashed border and placement.

**NFR tripwire check (Rule 5) — passes; no intent gap.** No criterion here carries a latency, threshold or numeric target. The one count that matters is emitted by the check and asserted against a synthetic population whose size the test authors. The only clause not implementable as worded is the card's caption — DW-126's missing copy, planned around above rather than met with invented text, and an escalated artifact gap the owner already holds rather than a contradiction in the intent.

## Verification

**What runs live and what runs at a seam.** The ObjectScript half — `Archetype.Exists()` / `LinkOutClass()`, `ClassicLinkProblem()` and the fixture-registry refusal — runs **live** against the `ocupilot` container (`server: "ocupilot-iris"`). The privilege-union path is exercised only through `Test/ScreenGate.cls`'s `ClassicResource()` override (`:49`): **`%SYS.Portal.Resources` is empty on this instance and stays empty**; nothing here reads or writes a real custom resource. Everything else runs at a seam — the check over a synthetic descriptor tree, the card in jsdom, and the DW-173 bound as stylesheet text, because **jsdom computes no layout** and no test in this tree can observe a width (`design-tokens.test.mjs:424-470` records the same).

**Commands:**
- `cd ui && node tools/classic-links.mjs` — expected: exit 0, printing the scanned count, the per-class tally and `0 exemption(s) honored (SM-C1)`.
- `cd ui && npm run test:tools` — expected: green, including the new `classic-links` suite and the amended `design-tokens` and `screen-mirror` suites.
- `cd ui && npm run test:components` — expected: green, including the new `classic-link-card` spec.
- `cd ui && npm run build` — expected: succeeds; `prebuild` now runs `classic-links`, so a malformed exemption fails the build.
- `node tools/screen-mirror.mjs` from `ui/` — expected: regenerates `screens.generated.ts` with the two new sub-fields and the `ArchetypeKey` union; `--check` then reads *up to date*.
- Stage a `.cls` and run `bash .githooks/pre-commit` — expected: the `OS_TRIGGER` block runs the new check. **Do not commit.**
- IRIS: load and compile `src/OcuPilot/` with the `iris-dev` MCP tools, **always `server: "ocupilot-iris"`**. Then `iris_execute_tests` — **one test class per tool call, per message, awaited; never two in one message and never a re-submit on a client-side timeout** (`.claude/rules/objectscript-testing.md`). Run `OcuPilot.Test.Descriptor`, which is where the accessors and every refusal are pinned. Confirm totals with the numeric-run-index SQL probe before reporting green. Never `docker compose up`/`down`/`restart`.
- `bash scripts/lint-docs.sh` — expected: clean.

**Pinning tests (Rule 19).** One mutation per criterion; each to be applied, observed red, reverted, with the tree byte-identical afterwards.
- The check reports its population and its exemptions → `ui/tools/classic-links.test.mjs` "a clean run names the scanned count and the honored count". mutation: _(implement stage)_
- A non-detail archetype may not exempt, on both sides → `ui/tools/classic-links.test.mjs` "a list archetype declaring an exemption is refused" + `OcuPilot.Test.Descriptor` (live) over `OcuPilot.Test.ClassicLinkRegistry`. mutation: _(implement stage)_
- The check cannot pass by looking at nothing → `ui/tools/classic-links.test.mjs` "a descriptor the reader did not return is a refusal, not a shorter population" + "an unreadable vocabulary is reported, not an empty set". mutation: _(implement stage)_
- The check is wired into every gate → `ui/tools/classic-links.test.mjs` "the check is named in prebuild, in prestart and in the pre-commit hook". mutation: _(implement stage)_
- Integration AC: the card renders from the real mirror → `ui/src/app/shell/classic-link-card.spec.ts` "Integration AC: the card renders the published title and one same-origin new-tab anchor". mutation: _(implement stage)_
- No URL is derived from `classicPage` → `ui/tools/classic-links.test.mjs` "an exemption with no declared href is refused" plus the card spec's absence row. mutation: _(implement stage)_
- **DW-173** the paused chip is bounded → `ui/tools/design-tokens.test.mjs` ".ocu-command-bar-refresh is bounded and ellipsizes, and its row can shrink it". mutation: _(implement stage)_

**Ledger (`owned_ledger=DW-173`).** Addressed by the `_components.scss` task, the last I/O matrix row, the DW-173 acceptance criterion and the `design-tokens.test.mjs` pin.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none
