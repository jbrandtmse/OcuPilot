---
title: 'Story 1.15: Classic portal fallback links'
type: 'feature'
created: '2026-09-12'
status: 'done'
baseline_revision: 'b9b7e12ad794610574b7e4f7eaa4d7a36a2a4e7b'
baseline_commit: 'b9b7e12ad794610574b7e4f7eaa4d7a36a2a4e7b'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-1-context.md'
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
warnings: ['oversized']
deferred:
  - summary: >-
      EXPERIENCE.md and epics.md disagree about the OAuth 2.0 screen's archetype, and Story
      1.15's closed vocabulary makes the disagreement decide whether Story 6.4's exemption is
      honored or refused.
    evidence: |-
      EXPERIENCE.md :142 gives the OAuth 2.0 screen Archetype `list`, and its Exceptions line
      :522 says "each tab a `list`". epics.md :3325 says the five tabs "are declared as detail
      views, not lists ... so each declares `classicLinkExemption` with its reason and Story
      1.15's check honors it". `Archetype.cls` classifies `list` as never-link-out, so a 6.4
      descriptor declaring the EXPERIENCE.md value is refused by the build check and by
      `Registry.Validate`. Pre-existing conflict; this story did not cause it and resolved it
      for its own classification by following epics.md. The owner picks the published archetype.
    location: >-
      _bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md:142
    severity: medium
  - summary: >-
      The classic-link card's action label has no width bound, so a long declared classic page
      name wraps or overruns the fixed-height pill - the DW-145 defect one card over.
    evidence: |-
      `.ocu-button-secondary` (_components.scss:250-265) sets `height: var(--ocu-control-height)`
      and no `white-space`, `max-width`, `overflow` or `text-overflow`; the label is descriptor
      data of unbounded length. Not reachable in Release 1 - nothing renders the card until
      Story 9.9, which is the first consumer and the right owner for the six-property DW-145
      recipe plus its own stylesheet-text pin.
    location: >-
      ui/src/styles/_components.scss (.ocu-classic-link-card .ocu-button-secondary)
    severity: medium
  - summary: >-
      The classic-link card duplicates instance-notice.ts's new-tab anchor, glyph escape
      included, with nothing keeping the copies in step.
    evidence: |-
      The markup is byte-identical apart from the label expression: `class="ocu-button-secondary"`,
      `[href]`, `target="_blank"`, `rel="noreferrer"`, a label span and an `aria-hidden`
      `.ocu-external-glyph` span carrying its own `'↗'` escape. Extracting a shared anchor
      is out of this story's footprint; Story 9.9 makes it a third copy, which is when to do it.
    location: >-
      ui/src/app/shell/classic-link-card.ts
    severity: low
  - summary: >-
      A new-tab anchor gives assistive technology no indication that it opens a new tab, in the
      card and in the already-shipped instance notice.
    evidence: |-
      `classic-link-card.ts` sets `target="_blank"` with the glyph that carries that meaning
      marked `aria-hidden="true"`, and the spec pins `aria-label` absent, so the accessible name
      is the bare page name. `instance-notice.ts:51-60` has the same shape already shipped. The
      fix needs a visually-hidden qualifier, which is user-facing copy no planning document
      publishes - the same DW-126 gap this story's caption slot is left empty for.
    location: >-
      ui/src/app/shell/classic-link-card.ts
    severity: low
  - summary: >-
      screen-mirror.mjs's readSources() throws without naming the file when a descriptor's XData
      is valid UDL but invalid JSON, so "throws naming the file" holds only for the missing-block
      case.
    evidence: |-
      The missing-`XData Declaration` branch throws with the path; the `JSON.parse(body)` call on
      the next line is unguarded, so a typo in a declaration surfaces as a bare SyntaxError and
      the author bisects the tree by hand. Pre-existing in screen-mirror.mjs, not introduced by
      this story, and this story's check turns the throw into a named refusal without the path.
    location: >-
      ui/tools/screen-mirror.mjs (readSources, the descriptor walk)
    severity: low
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

### 2026-09-12 — Review pass

- verdicts: 43 findings — high 0, medium 29, low 14, false 0, maybe-false 0
- findings:
  - `[low]` `[reject]` `check-objectscript.py` still ignores `archetype`, so the vocabulary has two build-time readers, not three — the same `OS_TRIGGER` block runs `classic-links.mjs`, so the gate is covered; only the `command -v node` miss is uncovered, and closing it is new checker code, not a correction.
  - `[medium]` `[patch]` `buildMirror` waved through `archetype: ""` and emitted it into a field typed `ArchetypeKey` — reproduced: not refused, emitted `"archetype": ""`. Dropped the `archetype !== ''` escape, so it is refused by name as on the instance.
  - `[low]` `[reject]` percent-encoded traversal passes both href predicates and `/a..b.csp` is a false positive — both reproduced. A root-relative path cannot leave the origin whatever its dot segments, so no bad outcome follows; decoding first is complexity for a path shape nothing serves.
  - `[medium]` `[patch]` `Test/Descriptor.cls` claims both engines are pinned on the same href corpus; the JS corpus is a strict superset both ways — added the three JS-only refusals and the `/` acceptance, and rewrote the sentence to say the two are kept in step by hand.
  - `[medium]` `[patch]` the check printed no report on its early-return paths, contradicting the AC's "every run, clean or not" — reproduced: both paths returned `report: []`. Added `refusedBeforeClassifying()`, pinned by a new test over both paths.
  - `[medium]` `[patch]` the two population sources are uncoupled and an over-count is never refused — reproduced: `{descriptorDir:'/tmp'}` gave `ok:true, scanned:1, fileCount:0`. The guard is now `scanned !== fileCount`, with a test for the over-count direction.
  - `[medium]` `[patch]` `Archetype.cls`'s ObjectScript readers report a read failure as "this archetype is not declared", which the class doc says they never do — the verdict is safe (fail-closed), the attribution is not. Corrected the claim to say which side names the file and which fails closed.
  - `[low]` `[patch]` `Archetype.Declaration()` discarded `tOpenSC` and reported every open failure as "missing" — it now returns the real status. Grouped with the finding above.
  - `[low]` `[patch]` the classification paragraph miscounted twice ("fourteen table keys" for sixteen, "four list shapes and the two" for five) — corrected to "sixteen keys" and "three list shapes and the two".
  - `[medium]` `[reject]` the eight-refusal predicate is implemented twice with nothing pinning the copies — real, and spec-bound: the Approach asks for the refusal "on both sides". Closed by-design; the corpus patch above is what addresses the drift.
  - `[low]` `[reject]` `Registry.Validate` re-parses the archetype XData per descriptor — `Validate` has no production caller and the roster is one descriptor, so no cost is reachable.
  - `[medium]` `[patch]` `box-sizing: border-box` on the chip alone left it 2px shorter than the pill beside it — confirmed no global reset and a content-box sibling. Restated the height as the control height plus 2px and the line-height as the control height, with a new assertion on both.
  - `[medium]` `[patch]` `classic-link-card.spec.ts` casts `HOME` with `as`, so the "real generated mirror" clause cannot fail — the spec now throws if the mirror carries no Home, and the absence loop asserts a non-empty roster first.
  - `[low]` `[defer]` the new-tab anchor gives assistive technology no indication it opens a new tab — the qualifier is copy no planning document publishes (DW-126), and `instance-notice.ts` already ships the same shape.
  - `[low]` `[defer]` the card re-implements `instance-notice.ts`'s anchor, glyph escape included — extracting a shared anchor is out of footprint; Story 9.9 is the third copy.
  - `[medium]` `[patch]` `screen-outlet.ts` and its spec still say `archetype` is free-form text, which this change invalidates — both sentences corrected at their origin; the parameter stays `string` because the function is pinned against a fixture map and `ARCHETYPE_PAGES` is partial.
  - `[low]` `[patch]` `classic-links.test.mjs`'s header duplicated the Rule 19 mutation list this spec owns — replaced with a one-line pointer to `## Verification`.
  - `[low]` `[patch]` the Auto Run Result generalized a two-class probe into "the one other class reading the descriptor tree" — corrected when this pass rewrote that section.
  - `[medium]` `[patch]` (edge-case) the early returns print no report — same root cause as the report finding above; closed by the same patch.
  - `[low]` `[defer]` `readSources()`'s `JSON.parse` throws without naming the file — pre-existing in `screen-mirror.mjs`, not introduced here.
  - `[medium]` `[patch]` a descriptor in a sub-package is invisible to both population sources at once while `Registry.Descriptors` enumerates it — confirmed the registry's `%STARTSWITH` select against two one-level readers. A sub-directory under `DESCRIPTOR_DIR` is now a refusal naming what it found and why, with a test.
  - `[medium]` `[patch]` (edge-case) `descriptorDir` injected without `screens` compares two directories — same root cause as the population finding above; closed by the equality guard.
  - `[medium]` `[patch]` (edge-case) `Archetype.Find` swallows `List()`'s status — same root cause as the vocabulary-read finding above; closed by the same patch.
  - `[medium]` `[patch]` `.ocu-command-bar` is a block child of `app-command-bar`, not a flex item, so its `min-width: 0` is not DW-173's bound and the comment asserting it is, is wrong — confirmed in the shell rules. Corrected the comment and moved the assertion to `.ocu-shell-content`'s `min-width: 0`, which is the bound that works.
  - `[medium]` `[defer]` the card's action label has no width bound — the DW-145 defect one card over. No consumer renders the card until Story 9.9, and the fix is the six-property recipe plus its own pin.
  - `[medium]` `[patch]` (edge-case) `screen-outlet.ts`/`.spec.ts` retired-contract comments — same root cause as the stale-claim finding above; closed by the same patch.
  - `[medium]` `[defer]` EXPERIENCE.md gives OAuth 2.0 the archetype `list` while epics.md calls its five tabs detail views — both confirmed. A pre-existing planning conflict this story did not cause, now load-bearing for Story 6.4.
  - `[medium]` `[patch]` the gate-wiring test matches the invocation text, not the gate's ability to fail — reproduced: `|| true` leaves every assertion green. The test now pins `|| STATUS=1` in the hook and that neither script chain swallows or follows the check.
  - `[medium]` `[patch]` (verification-gap) the Integration AC's mirror subject is unobserved — same root cause as the `HOME` cast above; closed by the same patch.
  - `[medium]` `[patch]` (verification-gap) the instance href corpus is a strict subset of the build one — same root cause as the corpus claim above; closed by the same patch.
  - `[medium]` `[patch]` `Registry.cls`'s new comment says refusing here "means install stops" and `classic-link-card.ts` says the ObjectScript half has already refused — `Validate` has no production caller, as `Registry.cls:27-31` already states. Both new comments corrected to name the build check as the refusal that stands today.
  - `[medium]` `[patch]` `screen-mirror.test.mjs`'s "the shipped mirror carries the four fields on every screen" iterates the parsed source declarations and checks one field — the loop now reads `buildMirror`'s own output and checks all four.
  - `[medium]` `[patch]` (verification-gap) the chip's box-sizing height mismatch — same root cause as the box-sizing finding above; closed by the same patch.
  - `[medium]` `[patch]` (verification-gap) the stale `screen-outlet` claims — same root cause as the stale-claim finding above; closed by the same patch.
  - `[medium]` `[patch]` the matrix states six rows as exit codes while `main()` is executed by no test — reproduced: no `spawn` in the suite. Added a test that spawns the check and asserts exit 0, the three report lines on stdout, and an empty stderr.
  - `[medium]` `[patch]` the population guard is unreachable on the production path, since both counts come from one directory with one filter — same root cause as the population finding; the equality guard and the sub-directory refusal are what now make the two sources capable of disagreeing.
  - `[low]` `[reject]` no artifact carries an honored exemption from declaration to rendered anchor — spec-bound: `## Design Notes` records that Home is Epic 1's only screen and Story 6.4 lands the first honored exemption.
  - `[medium]` `[patch]` "the same sentence" is claimed in comments, not pinned by a test — same root cause as the corpus claim; closed by the same patch.
  - `[low]` `[reject]` the DW-173 `doesNotMatch` window cannot see the source-order fact the cascade depends on — the stylesheet is section-ordered and the shipped DW-145 pin has the same shape; an order assertion is complexity for a move nobody makes.
  - `[medium]` `[patch]` "prints on every run" holds for classified runs only — same root cause as the report finding; closed by the same patch.
  - `[low]` `[reject]` the card's `present` guard restates three validator conditions and one test pins states the validator forbids — a render guard is not a refusal predicate, and rendering nothing rather than a dead control is the safer behavior to pin.
  - `[low]` `[reject]` changing the vocabulary is now a four-file edit — the two test-side literals are deliberate and their comments say why; comparing a parse with itself would restate the parser.
  - `[medium]` `[defer]` the EXPERIENCE.md / epics.md OAuth conflict, restated by the intent layer — same root cause as the conflict deferred above; one ledger item, not two.


## Design Notes` records that Home is Epic 1's only screen and Story 6.4 lands the first honored exemption.
  - `[low]` `[reject]` `readSources()` is not called with `descriptorDir`, so the injection seam is only coherent when both are supplied — verified. Rejected: subsumed by the equality guard patched above, which now refuses the mismatch that seam produces.
  - `[low]` `[reject]` the matrix rows speak in exit codes while the refusal tests speak in return values — verified. Rejected: the process-level test patched above covers the clean run; asserting each refusal through a spawned process would need injection on `main()`, which is public surface.
  - `[low]` `[reject]` `Archetype.cls` is roughly 137 comment lines against 48 of code — verified. Rejected: the content is contract and classification rationale, which is what a single-source vocabulary owes its readers; the one part that was review history is patched above.
  - `[low]` `[reject]` `hrefProblem`'s message for an empty href reads as a fragment once prefixed — verified cosmetic. Rejected: the assembled sentence is correct and the tests pin it.
  - `[low]` `[reject]` the `Bad.cls` fixture's `classicPage` names no real class — verified deliberate, and `Multi.cls` records why. Rejected: the fixture must not depend on a real operator assignment.
  - `[low]` `[reject]` the honored-exemption report line is one long line rather than a block — verified cosmetic. Rejected: one line per exemption is what makes the report greppable.
  - `[low]` `[reject]` `shortPath` falls back to the absolute path for a directory outside the repository — verified intentional and commented. Rejected: the alternative is a run of `..` segments.
  - `[low]` `[reject]` `descriptorFileNames` sorts but nothing depends on the order — verified. Rejected: a stable order is what makes the report reproducible.
  - `[low]` `[reject]` `Test/Screen/Detail.cls` duplicates much of `Multi.cls`'s declaration — verified. Rejected: the two pin different archetypes, which is the point of having both.

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
- The check reports its population and its exemptions → `ui/tools/classic-links.test.mjs` "a clean run names the scanned count, the per-class tally and the honored count". mutation: deleted the honored-count `report.push` in `classic-links.mjs` → that test went red on `/^classic-links: 0 exemption\(s\) honored \(SM-C1\)$/m`, and two more with it.
- A non-detail archetype may not exempt, on both sides → `ui/tools/classic-links.test.mjs` "a list archetype declaring an exemption is refused, naming the archetype" + `OcuPilot.Test.Descriptor` (live) over `OcuPilot.Test.ClassicLinkRegistry`. mutation: guarded `classicLinkProblem`'s `LINK_OUT_DETAIL` comparison with `false &&` and `Registry.ClassicLinkProblem`'s `MayLinkOut` test with `If 0`, recompiled → both went red, the live one on six assertions including the fixture-roster refusal.
- The check cannot pass by looking at nothing → `ui/tools/classic-links.test.mjs` "a descriptor the reader did not return is a refusal, not a shorter population" + "an unreadable vocabulary is reported, not an empty set". mutation: guarded the `scanned !== fileCount` refusal with `false &&` and made `parseArchetypes` return `archetypes` rather than `null` for an empty vocabulary → three went red, the two named plus "a population larger than the tree is a refusal too".
- The check is wired into every gate → `ui/tools/classic-links.test.mjs` "the check is named in prebuild, in prestart and in the pre-commit hook". mutation: changed the hook's dispatch from `|| STATUS=1` to `|| true`, so the check still runs and still prints its refusal but no longer blocks → that test went red on "the hook's dispatch feeds a refusal into STATUS". (Dropping the invocation from `prebuild` reddens the same test on "prebuild runs it before ng build"; the `|| true` form is the stronger mutation, because every name-only assertion survives it.)
- Integration AC: the card renders from the real mirror → `ui/src/app/shell/classic-link-card.spec.ts` "Integration AC: the card renders the published title and one same-origin new-tab anchor". mutation: dropped `rel="noreferrer"` from the card's anchor → that test went red on `expected null to be 'noreferrer'`.
- No URL is derived from `classicPage` → `ui/tools/classic-links.test.mjs` "an exemption with no declared href is refused -- no URL is derived from classicPage" plus the card spec's absence row. mutation: guarded `hrefProblem`'s empty-href refusal with `false &&` → that test went red on `/no URL is ever derived from classicPage/`, and the missing-part test with it.
- **DW-173** the paused chip is bounded → `ui/tools/design-tokens.test.mjs` "DW-173: .ocu-command-bar-refresh is bounded and ellipsizes, and its row can shrink it". mutation: restored `flex: 0 0 auto` and the shared rule's `height: var(--ocu-control-height)`, removing `max-width: 100%` and `min-width: 0` from the chip → that test went red on "the chip is capped to its row".

**Ledger (`owned_ledger=DW-173`).** Addressed by the `_components.scss` task, the last I/O matrix row, the DW-173 acceptance criterion and the `design-tokens.test.mjs` pin.

## Auto Run Result

Status: done
Blocking condition: none

**What was built.** `src/OcuPilot/Screen/Archetype.cls` closes the archetype vocabulary in one
`XData` block -- sixteen keys, each classified `list` | `detail` | `none`, with only `detail`
permitted to declare a `classicLinkExemption` and everything else, an undeclared key included,
refused. `Base.cls` gained `ClassicLinkHref()`/`ClassicLinkLabel()`; `Registry.cls` gained public
`ClassicLinkProblem()` and `ClassicHrefProblem()`, called from `Validate()`. `ui/tools/classic-links.mjs`
is the new build-time check, wired into `prebuild`, `prestart` and the hook's `OS_TRIGGER` block;
it reports its scanned count, the per-class tally, one line per honored exemption and the stable
`classic-links: N exemption(s) honored (SM-C1)` on every run, refusing or not. `screen-mirror.mjs`
carries the two new sub-fields, emits the `ArchetypeKey` union and refuses an archetype outside it.
`ClassicLinkCard` renders the published title and one same-origin new-tab anchor, and nothing at
all without an honored exemption. DW-173 is fixed by the DW-145 recipe. The card ships without the
caption slot: no planning document publishes that sentence (DW-126), so it is absent rather than
placeholdered, and `REQUIRED_ALONGSIDE_TABLE` did not grow.

**Files changed.**
- `src/OcuPilot/Screen/Archetype.cls` -- new; the closed vocabulary and its four readers.
- `src/OcuPilot/Screen/Descriptor/Base.cls` -- the two new exemption accessors.
- `src/OcuPilot/Screen/Descriptor/Home.cls` -- the exemption states all four fields.
- `src/OcuPilot/Screen/Registry.cls` -- `ClassicLinkProblem()`/`ClassicHrefProblem()`, called from `Validate()`.
- `src/OcuPilot/Test/Screen/Detail.cls`, `Test/ClassicLink/Bad.cls`, `Test/ClassicLinkRegistry.cls` -- new fixtures: the honored path and the refused one, on separate registries.
- `src/OcuPilot/Test/Screen/Multi.cls` -- its exemption gained the label and href the new refusal requires.
- `src/OcuPilot/Test/Descriptor.cls` -- three new methods: the vocabulary, every refusal as values plus the fixture roster, and the honored detail path.
- `ui/tools/classic-links.mjs` + `classic-links.test.mjs` -- new; the check and its 20 tests.
- `ui/tools/screen-mirror.mjs` + `screen-mirror.test.mjs` -- the vocabulary reader, the union, the refusal, the two sub-fields.
- `ui/tools/design-tokens.test.mjs` -- the DW-173 and card-surface pins.
- `ui/src/app/shell/classic-link-card.ts` + `.spec.ts` -- new; the card and its four tests.
- `ui/src/app/core/screens.generated.ts` -- regenerated, never hand-edited.
- `ui/src/styles/_components.scss` -- `.ocu-classic-link-card` and the DW-173 fix.
- `ui/package.json`, `.githooks/pre-commit` -- the three gate dispatches.
- `ui/src/app/shell/screen-outlet.ts`/`.spec.ts` and nine component specs -- the retired free-text claim, and the exemption literal's two new fields.

**Review findings.** Four layers reported 43 findings: 29 medium, 14 low, no high. 16 entries were
patched in this pass (13 medium, 3 low), 5 deferred, and the rest rejected on their refutation --
every one with its row in `## Review Triage Log`. The substantive patches were the ones that made a
check able to fail: the report now prints on every early-return path, the two population sources must
now be *equal* rather than merely not-short, a descriptor sub-directory is refused (the registry's
`%STARTSWITH` query reaches one that both one-level readers would miss together), the gate test now
pins `|| STATUS=1` rather than the invocation text, `main()` is exercised by a spawned process, and
the Integration AC now fails if the mirror carries no Home. Six patches corrected claims the code did
not support -- the loudest being two new comments asserting that `Validate()` stops an install when
nothing on the serving path calls it.

**Follow-up review recommended: true.** The named unverified risk is the restated chip height. DW-173
and the box-sizing fix are asserted as stylesheet text because jsdom computes no layout, so nothing in
this tree observes that `.ocu-command-bar-refresh` and `.ocu-command-bar-action` now render at the same
height or that the chip ellipsizes under real pressure -- a browser check at a narrow width would settle
both in one look. Patched by verdict: 13 medium, 3 low, 0 high.

**Verification.** `node tools/classic-links.mjs` exit 0, 1 scanned / 0 honored; `npm run test:tools`
476/476; `npm run test:components` 184/184 over 19 files; `npm run build` succeeds with the check in
`prebuild`; `screen-mirror.mjs --check` up to date; `bash .githooks/pre-commit` over a staged `.cls`
runs the check inside `OS_TRIGGER` (nothing committed, index restored); `uv run scripts/check-objectscript.py`
and `bash scripts/lint-docs.sh` clean. Live on `ocupilot-iris`: `OcuPilot.Test.Descriptor` 18/18 and
`OcuPilot.Test.Navigation` 11/11, both confirmed by the numeric-run-index SQL probe over
`%UnitTest_Result` after the patched classes were recompiled. `%SYS.Portal.Resources` was never read
or written; no container lifecycle command was run. All seven pinning mutations were demonstrated by
this agent -- applied, observed red, reverted, with `git status --short` and `git diff --stat` unchanged
each time; the three whose target code the patches changed were demonstrated again afterwards.

**Residual risks.** The card has no consumer in shipped chrome -- Home is Epic 1's only screen and is
not a reduced form -- so `ClassicLinkCard` is exercised only by its spec until Story 9.9, and Release 1
honors zero exemptions. The closed vocabulary now constrains every later descriptor and is a
Consistency-Conventions-row candidate for the lead under Rule 20; the spine's row `:526` does not yet
name `Archetype.cls`. The caption clause stays unimplementable as worded until the owner publishes the
literal (DW-126), and the OAuth archetype conflict in the `deferred:` list decides whether Story 6.4's
exemption is honored or refused.
