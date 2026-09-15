---
title: 'Story 3.0: Epic 2 deferred cleanup'
type: 'bugfix'
created: '2026-09-15'
status: 'done'
baseline_revision: '836d5e3387a6ea68c45148fa88b8a6a260c14ef5'
baseline_commit: '836d5e3387a6ea68c45148fa88b8a6a260c14ef5'
baseline_commit: '836d5e3387a6ea68c45148fa88b8a6a260c14ef5'
review_loop_iteration: 0
followup_review_recommended: true
context: []
warnings: ['multiple-goals', 'oversized']
deferred:
  - summary: >-
      EXPERIENCE.md's own `:N` self-citations are resolved by no gate, and most of those at or
      below the Fixed strings table already point at the wrong row.
    evidence: |-
      `ui/tools/citations.test.mjs` declares ROOTS as ui/src, ui/tools, ui/browser, src/OcuPilot
      and scripts, so neither EXPERIENCE.md nor `_bmad-output/**` is scanned; only `strings.ts`'s
      gated pins are resolved, by `strings.test.mjs:494-531`. Checked each citation at or below
      329 against `git show 836d5e3:`: `:336`, `:339` (x3), `:342`, `:345`, `:353`, `:359`,
      `:369`, `:389` (x3), `:536` (x2) and `:610` (x2) were already pointing at the wrong row
      BEFORE this story; only row 325's `:343` was correct and it is patched here. This is the
      rot `citations.test.mjs`'s own header names, and DW-309's reopen_if covers it.
    location: >-
      _bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md
    severity: low
  - summary: >-
      WireSecurityRead's Mutation paragraph still asserts an unobserved second mutation - the
      descriptor pair swap - in the very paragraph DW-307 was opened about.
    evidence: |-
      `src/OcuPilot/Test/WireSecurityRead.cls` keeps "Swap the descriptor's first two pairs -> the
      SECUREUSER assertions go red, and only they." AC4's window ran the pair REMOVAL only, so the
      swap outcome is derived, not seen - the same shape as the claim this story corrected.
      Settling it needs another throwaway up/down cycle this story did not charter.
    location: >-
      src/OcuPilot/Test/WireSecurityRead.cls:376-377
    severity: medium
  - summary: >-
      The privilege-denial sentence is never rendered from a real envelope; AC3's browser leg
      covers the 404 LOG.NAMESPACE arm only.
    evidence: |-
      Both halves of the contract are pinned on their own side - `Test/ErrorLogDenial.cls` asserts
      the server writes `detail.failedPair` over HTTP, and `ui/tools/api.test.mjs:494-512` asserts
      the client lifts it out of a raw envelope - but the rendered sentence
      "You need <pair> to read this log." exists only against `StubApi`, whose `detail` argument
      this same story added. A browser or over-the-wire leg would close the seam.
    location: >-
      ui/browser/error-log.browser-spec.mjs:399-415
    severity: medium
---

<intent-contract>

## Intent

**Problem:** Every named refusal on the application error log renders the one generic sentence
`STRINGS.connectivityRequestRefused`, so an unknown namespace, a purged date, an entry that has gone
and a privilege denial are indistinguishable on screen (DW-297) — the page holds `fault.code` and
throws it away at `showRefusal`. Separately, the burn-down promised a throwaway real-principal
observation of `AdminPort`'s own named 403 and never wrote it, leaving a shipped doc comment in
`Test/WireSecurityRead.cls` asserting an outcome nobody has seen (DW-307).

**Approach:** Branch the page's refusal notice on the envelope's machine code (AD-39) and publish one
sentence per named refusal, adding a single Fixed-strings row in the same pass so the cardinality gate
holds; reuse the existing `You need <resource> to <action>.` 403 pattern for the privilege denial,
resolved from `detail.failedPair` (AD-8). Then run the pre-named mutation window on the throwaway,
record what a real least-privileged principal actually observes, and correct the shipped claim to match.

## Boundaries & Constraints

**Always:** Copy comes from EXPERIENCE.md's Fixed strings table, added there first and cited from
`strings.ts` by line; the new row is **inserted at line 329**, immediately after the error-log rows, and
the five existing `/** EXPERIENCE.md:n */` pins citing 329–331 are bumped by one in the same edit.
Every refusal the page cannot name keeps `connectivityRequestRefused` — the fallback is the default, not
an error. The DW-307 window is a **recorded and reverted** source mutation: snapshot `git status --short`
and `git diff --stat`, apply, observe, revert, confirm byte-identical. Principal-creating work runs only
on the throwaway (`ocupilot-ci`, port 52776) behind `OCUPILOT_ALLOW_PRINCIPALS`; one
`iris_execute_tests` / one runner class per call.

**Never:** Do not touch `ui/src/app/core/fault.ts`, `api.ts` or `screen-read.ts` — the failed pair is
captured in the error-log store, so the shared fault path stays untouched (this is what the ledger's
`fix-risk: high` was about). Do not render the server's human `reason` (AD-39). Do not widen
`REQUIRED_ALONGSIDE_TABLE` or `EXTRACTED_FROM_PROSE` in `strings.test.mjs`. Do not add a sentence for
`LOG.MAXROWS` — no shipped client path sends a bad `maxRows`. Do not touch `DataTable`'s own refusal.
Do not create a principal, rotate a log or seed an error on the live `ocupilot` container, and never
`docker compose up`/`down` against it. Do not ship a screen descriptor that under-declares its pair set.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Unknown namespace (DW-297) | a drill read answers 404, envelope `code` `LOG.NAMESPACE` | `[data-ocu-drill="refusal"]` reads `STRINGS.errorLogRefusedNamespace` | this is the error path |
| Purged date (DW-297) | 404, `LOG.DATE` | reads `STRINGS.errorLogRefusedDate` | as above |
| Entry gone (DW-297) | 404, `LOG.ENTRY` | reads `STRINGS.errorLogRefusedEntry` | as above |
| Privilege denial naming a pair (DW-297) | 403, `AUTH.NOPRIVILEGE`, `detail.failedPair` = `%DB_IRISSYS:READ` | reads `formatDeniedAction(STRINGS.privilegeDeniedAction, failedPair, STRINGS.errorLogRefusedAction)` → `You need %DB_IRISSYS:READ to read this log.` | as above |
| Privilege denial with no pair | 403, `AUTH.NOPRIVILEGE`, envelope carries no `detail` | falls back to `STRINGS.connectivityRequestRefused` | never renders `You need  to read this log.` with an empty slot |
| Any unnamed refusal | 400 `LOG.MAXROWS`, a `null` code, or `not-installed` | `STRINGS.connectivityRequestRefused`, unchanged | the fallback is the default arm |
| Refusal clears | a later level's read succeeds | the notice goes, the captured pair is cleared with it | a stale pair must not survive into the next refusal |
| Port's named 403 (DW-307) | on `ocupilot-ci`, `%Admin_Manage:USE` removed from `ProcessList`'s `privileges`, `OPERATEUSER` GETs `/api/ocupilot/screens/osmgmt.processes/read` | the observed status, `code` and `detail.failedPair` are recorded verbatim in `## Verification` | if the observation is not 403 / `PORT.ACCESSDENIED` / `%Admin_Manage:USE`, record what it was and correct `WireSecurityRead`'s Mutation paragraph to the observation — the claim is what is on trial |

</intent-contract>

## Code Map

Anchors re-verified 2026-09-15 against the working tree; where the prior pass was wrong the correction
is marked **(was …)**.

- `ui/src/app/areas/logs/error-log.page.ts` — `showRefusal` at **:278-282** calls `this.generation()`
  (:279), reads `this.drill.fault()` and consults only `isBannerFault(fault)`, discarding `fault.code`.
  **This is the defect's single line.** The render line is **:65** exactly, inside the
  `data-ocu-drill="refusal"` host at **:64**. Doc comment **:268-277**. `generation` is a
  `signal(0)` at **:220**, read for effect to force `OnPush`.
- `ui/src/app/areas/logs/error-log.store.ts` — `faultValue` at **:154**; `fault()` at **:238-240**;
  `read()` clears it at **:343** and sets `classifyFault(result, path)` at **:355**; `reset()` clears it
  at **:187**. Those are **all four** sites — a sibling field must be declared at :154 and cleared at
  :187 and :343. **`result.kind !== 'ok'` narrows to `installing | error`, and the `installing` arm has
  no `detail` field**, so reading `result.detail` needs a further `result.kind === 'error'` guard
  (was: "that narrowed arm still holds `result.detail`" — it does not, without the extra narrow).
  The store's own `generation` is a **number** at **:156**, unrelated to the page's signal.
- `ui/src/app/core/fault.ts` — `Fault` keeps `kind/status/code/path`; `isBannerFault` at **:102-104** is
  true only for `unreachable`/`server-fault`. **Read-only for this story.**
- `ui/src/app/core/api.ts` — `JsonResult`'s error arm: `kind: 'error'` **:111**, `code` **:113**,
  `detail: Record<string, unknown> | null` at **:120** (was: :116-118, which is its doc comment).
  **Read-only.**
- `ui/src/app/core/navigation.ts` — `RESOURCE_PLACEHOLDER` **:145**, `formatRequires` **:162-164**,
  `SCREEN_PLACEHOLDER` **:167**, `formatDeniedScreen` **:174-176**. Construction style to copy:
  `template.split(PLACEHOLDER).join(value)` chained, no regex.
- `ui/src/app/core/strings.ts` — 217 keys, **201** carrying a `/** EXPERIENCE.md:n */` pin (was: 202).
  `privilegeDeniedAction: 'You need <resource> to <action>.'` at **:221**, pinned `EXPERIENCE.md:295`,
  and **referenced by nothing in `ui/`** — reusing it costs zero cardinality. Error-log block
  **:408-445**. The **five** pins to bump are the pin lines **:446, :448, :450, :452, :454**
  (`homeStarterPromptExplainScreen`, `homeStarterPromptExplainLog`, `homeStarterPromptChangeOneThing`
  at `:329`; `proposalExpectedImpactExample` at `:330`; `auditMarkerDescription` at `:331`).
  Nearest existing sentence: `faultAbsentEntity` at **:81** — see Design Notes on wording.
- `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md` — Fixed strings
  header `| String | Where |` **:252**, rows **:254-331** (202 literals), blank line **:332** terminates
  the extractor. Error-log rows **:325-328**; the empty states are **:326**; the 403 pattern row is
  **:295**. Literals inside one `String` cell are separated by `" · "` (space, U+00B7, space).
- `ui/tools/strings.test.mjs` — cardinality **:346-350** is `keys === expectedLiterals +
  EXTRACTED_FROM_PROSE + REQUIRED_ALONGSIDE_TABLE`; **both sides derive from the files, so a matched
  row+keys edit balances it with no number to change**. Literal band `150..220` at **:306-309** applies
  to **table literals** (202 → 206), not keys — no breach. Duplicate-**value** ban **:444-450** (exact
  equality). Line-pin resolver **:493-529**: a pin only resolves when the key declaration is on the very
  next line, and the pinned EXPERIENCE.md line must contain the value wrapped in **double quotes**
  (:524). Namespace roster **:376-383** with its comment at **:366-375**, which asserts *"there is still
  no sentence for an unknown namespace"* — the claim this story falsifies.
- `ui/tools/citations.test.mjs` — quoted-phrase anchors must occur in EXPERIENCE.md **exactly once**
  (**:136-160**); bare line numbers banned outside `strings.ts`'s gated comments (**:94**, **:162-179**);
  a mid-table insertion is green by design (**:22**); `> 150` gated citations asserted **:181-189**.
- `ui/src/app/areas/logs/error-log.page.spec.ts` — `api.refuse('dates', 403, 'AUTH.NOPRIVILEGE')` at
  **:297**; the pin to change is **:303**; keep the empty-state separation pin at **:310**. The stub's
  `refusals` field is **:45** (`Record<string, { status: number; code: string }>`) and `refuse()` is
  **:54-57**; the envelope at **:65** hard-codes `detail: null`, **so the stub needs a new optional
  `detail` argument** to exercise the failed-pair rows (was: "the stub already carries `code`" — true,
  but silent about `detail`).
- `ui/browser/error-log.browser-spec.mjs` — rewrites the outgoing `namespace` parameter, asserts a
  genuine **404** from the live endpoint at **:400**, the refusal node at **:406**, and the generic
  sentence at **:407-411**; inline `Mutation (Rule 19)` note **:402-405**.
- `src/OcuPilot/Port/LogSourcePort.cls` — outcome switch: `"namespace"` → 404 `LOG.NAMESPACE` **:602**,
  `"unresolvable"` → `DeniedRefusal("")` **:609** (the real no-pair 403 path), `"denied"` →
  `DeniedRefusal(tFailedPair)` **:613**, `"date"` → 404 `LOG.DATE` **:617**, `"entry"` → 404 `LOG.ENTRY`
  **:621**; `LOG.MAXROWS` → 400 **:569**. `DeniedRefusal` **:639-647** adds `detail.failedPair` only
  when `pFailedPair '= ""`. **Read-only.**
- `src/OcuPilot/Api/Error.cls` — `AUTHNOPRIVILEGE = "AUTH.NOPRIVILEGE"` **:111**,
  `PORTACCESSDENIED = "PORT.ACCESSDENIED"` **:160**, `LOGNAMESPACE` **:246**, `LOGDATE` **:255**,
  `LOGENTRY` **:261**. **Read-only** — no new code is needed.
- `src/OcuPilot/Port/AdminPort.cls` — `Parameter QUERYPAIRS = "Process/LIST=%Admin_Manage:USE|%DB_IRISSYS:WRITE"`
  **:121** (any-of). The probe at **:355** fires only when the sequence errored **and** the status is
  exactly 500 **and** `QueryPairRefused` answers 1; that helper (**:591-613**) names
  `$ListGet(tPairs, 1)` — **the first pair of the any-of set** — at **:604**, so the reported
  `failedPair` is `%Admin_Manage:USE` whichever one the caller lacks. `Denied` raises 403
  `PORT.ACCESSDENIED` at **:890-898**. Class doc **:27-33** states the 403 is reachable on the error
  path only. **Read-only.**
- `src/OcuPilot/Screen/Descriptor/ProcessList.cls` — `privileges` is one line, **:88**, declaring
  `%Admin_Operate:USE`, **`%Admin_Manage:USE`**, `%DB_IRISSYS:READ` in that order; the middle pair is the
  mutation target. `toolIdentifier` `osmgmt.processes` **:121**.
- `src/OcuPilot/Test/WireSecurityRead.cls` — `Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS"`
  **:40**, guard **:126-128**. `OPERATEUSER` **:75**, built at **:165** with the code-read resource plus
  `%Admin_Operate:U,%DB_IRISSYS:R`, read back at **:179**. `AssertReadRefused` **:285-293** makes **four**
  assertions: the request completed (**:288**), status `= 403` (**:289**, hard-coded), `code =
  "AUTH.NOPRIVILEGE"` (**:291**, **hard-coded, not a parameter**), `detail.failedPair = pPair`
  (**:292**, the only caller-supplied expectation). The ProcessList leg is **:381** (was: :375); the
  area/screen verdicts are **:379-380**. The **Mutation paragraph is :369-374** and names the
  `os-management` area in addition to the descriptor.
- `src/OcuPilot/Screen/Registry.cls` — `AreaCoverageProblem` **:371-391** loops the **screen's** pairs
  (**:376**) and requires the **area** to cover each (**:379-384**), so removing a pair from a descriptor
  alone shrinks the checked set and still installs; removing it from the area alone does not.
  `Parameter DESCRIPTORPACKAGE = "OcuPilot.Screen.Descriptor."` **:43**; `Descriptors()` **:80** filters
  `Name %STARTSWITH` it (**:88**) via the overridable seam `DescriptorPackage()` **:48-55**, documented
  *"Production never overrides it"*.
- `src/OcuPilot/Api/ScreenRead.cls` — `Handle` gates on `Gate.Evaluate(tDescriptor, …)` at **:56-62**;
  `Screen/Gate.cls` `RequiredPairs` **:69-85** is the **descriptor's** pairs plus the classic page's
  custom resource — **the area's pairs are not consulted on the read route**. This is what makes the
  descriptor-only window sufficient.
- `scripts/ci-throwaway.sh` — `PROJECT="ocupilot-ci"` **:25**, `WEB_PORT="52776"` **:26**; the `up)` case
  `rm -rf` the scratch dir (**:86**) then copies `src/`, `scripts/`, `module.xml` and, only if it exists,
  an already-built `ui/dist` (**:93-106**) — it runs no client build, so **`npm run build` must precede
  `up`, and a source mutation must be applied to the repo before `up` to reach the container**.
  `OCUPILOT_ALLOW_PRINCIPALS: "1"` **:139** (with `OCUPILOT_ALLOW_LOG_ROTATION` :133 and
  `OCUPILOT_ALLOW_ERROR_SEED` :143); `up -d --wait` **:168**.
- `ui/package.json` — `prebuild` chains six checkers (`version-guard`, `client-lint`,
  `screen-mirror --check`, `classic-links`, `ipm-manifest --check`, `field-lists --check`);
  `test` is `node --test tools/*.test.mjs && ng test`; `pretest:browser` runs
  `ng build --configuration production,harness`.

## Tasks & Acceptance

**Execution:**

- `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md` — insert **one row at
  line 329**, directly under the error-log rows, carrying four double-quoted literals separated by `" · "`:
  `That namespace is no longer present in this log. Use Back to see which namespaces are.`,
  `That date is no longer present in this log. Use Back to see which dates are.`,
  `That application error is no longer present in this log. Use Back to see which errors are.`, and
  `read this log`. The `Where` cell names the screen, says one sentence per named refusal, points at the
  Back control row (`` `:328` ``) and the 403 pattern row (`` `:295` ``); it must contain **no double
  quotes**. Rationale: the copy is canonical there before any code cites it (DW-297).
- `ui/src/app/core/strings.ts` — add `errorLogRefusedNamespace`, `errorLogRefusedDate`,
  `errorLogRefusedEntry`, `errorLogRefusedAction`, each on one line, single-quoted, trailing comma, each
  **immediately** preceded by its own `/** EXPERIENCE.md:329 */` line (the resolver only matches a pin
  whose key is on the very next line); bump the five pins at `:446, :448, :450, :452, :454` by one. Every
  literal is ASCII (Rule 14). Rationale: keys and pins land with the row so the cardinality and line-pin
  gates balance without editing a number.
- `ui/tools/strings.test.mjs` — add `errorLogRefusedNamespace` to the roster array at **:381** and
  replace the comment at **:366-375** with what is now true: this screen publishes a sentence for a
  namespace the log does not carry, so the roster holds three keys, and it enumerates every
  namespace-named key so a new one stays a deliberate act. Do not relax the assertion to a count or a
  prefix. Rationale: correct the wrong claim at its origin rather than route around it.
- `ui/src/app/core/navigation.ts` — add `ACTION_PLACEHOLDER = '<action>'` and
  `formatDeniedAction(template, failedPair, action)` beside `formatDeniedScreen`, substituting both slots
  in the same chained-`split/join` style. Rationale: one construction per published pattern, as
  `formatRequires` and `formatDeniedScreen` already are.
- `ui/src/app/areas/logs/error-log.store.ts` — declare a `failedPairValue` field beside `faultValue`
  (**:154**), clear it at **:187** and **:343** wherever `faultValue` is cleared, and set it at
  **:355** from `result.detail` **behind a `result.kind === 'error'` narrow** (string values only;
  anything else, and the `installing` arm, leave `''`). Expose `failedPair(): string` beside `fault()`
  (**:238-240**). Rationale: the pair is available here, so `fault.ts` need not change.
- `ui/src/app/areas/logs/error-log.page.ts` — add a `refusalMessage` getter that reads
  `this.generation()` first (as `showRefusal` does at :279) then maps the fault's `code`:
  `LOG.NAMESPACE`/`LOG.DATE`/`LOG.ENTRY` to their new strings; `AUTH.NOPRIVILEGE` **with a non-empty**
  `this.drill.failedPair()` to
  `formatDeniedAction(STRINGS.privilegeDeniedAction, pair, STRINGS.errorLogRefusedAction)`; everything
  else — including an `AUTH.NOPRIVILEGE` with no pair — to `STRINGS.connectivityRequestRefused`. Render
  it at **:65** in place of the fixed string. Update the **:268-277** doc comment to state that the
  notice is chosen by the envelope's code and that the fallback is the default arm; keep it to the
  method's contract, no review history. Rationale: this is DW-297's fix.
- `ui/src/app/areas/logs/error-log.page.spec.ts` — add an optional `detail` argument to the stub's
  `refuse()` (**:54-57**) and its `refusals` type (**:45**), and emit it at **:65** instead of the
  hard-coded `detail: null`; change the **:303** assertion to the resolved 403 sentence; add one case per
  matrix row, including the no-pair fallback and one unnamed code. Rationale: the matrix's edge cases
  need a unit host, and the failed-pair rows are untestable until the stub can carry `detail`.
- `ui/browser/error-log.browser-spec.mjs` — change the **:407-411** assertion to
  `STRINGS.errorLogRefusedNamespace` (and its message, which currently argues for the generic sentence),
  and update the inline `Mutation (Rule 19)` note at **:402-405**. Rationale: this is the Integration
  AC's observation — a real 404 from the live endpoint, rendered by the shipped bundle.
- `src/OcuPilot/Test/WireSecurityRead.cls` — after the observation, rewrite the Mutation paragraph at
  **:369-374** to state what was observed rather than what was derived, and drop *"and from the
  `os-management` area"*: the read route gates on the descriptor alone (`Screen/Gate.cls:69-85`), so the
  area edit is a second, unnecessary change. Name which assertions move and which hold. Keep it to two
  sentences. Rationale: a shipped comment must not assert an unobserved outcome.
- `_bmad-output/implementation-artifacts/spec-2-13-epic-2-burn-down.md` — append one line to its
  `## Spec Change Log` recording that its third promised verification step was kept here, citing this
  spec's `### DW-307 observation`. Rationale: Story 3.0's first AC requires a promised step to either
  become real or be struck **at the spec that promised it**.
- `_bmad-output/implementation-artifacts/spec-3-0-epic-2-deferred-cleanup.md` — fill
  `### DW-307 observation` under `## Verification` with the verbatim status, `code` and
  `detail.failedPair`, plus the pre- and post-window snapshot evidence. Rationale: DW-307's deliverable
  is the recorded observation.

**Acceptance Criteria:**

- **AC1 (DW-297).** Given the four named refusals the error-log read can answer, when each reaches the
  page, then each renders a different published sentence and no two read alike — the privilege denial
  through the existing `You need <resource> to <action>.` row resolved from `detail.failedPair`, and an
  `AUTH.NOPRIVILEGE` carrying no pair, an unnamed code and a `null` code all through the unchanged
  `connectivityRequestRefused` fallback.
- **AC2 (DW-297, gates).** Given the new copy, when `npm run build` and `npm test` run from `ui/`, then
  `strings.test.mjs` passes with the cardinality balancing at 206 table literals + 12 prose + 3 extras =
  221 keys, its namespace roster listing exactly three keys, and `citations.test.mjs` passes with no bare
  line number outside `strings.ts`'s gated comments.
- **AC3 (Integration AC, DW-297).** Given the shipped bundle on the throwaway, when
  `ui/browser/error-log.browser-spec.mjs` forces a genuine 404 `LOG.NAMESPACE` against the live endpoint,
  then the browser observes `STRINGS.errorLogRefusedNamespace` in `[data-ocu-drill="refusal"]` — not the
  generic sentence, and not a blank frame.
- **AC4 (DW-307).** Given `ocupilot-ci` built from a tree with `%Admin_Manage:USE` removed from
  `ProcessList`'s descriptor `privileges` (`:88`) and `OCUPILOT_ALLOW_PRINCIPALS` armed, when
  `OPERATEUSER` — a real principal holding `%Admin_Operate:USE` and `%DB_IRISSYS:READ` and not
  `%Admin_Manage:USE` — GETs `/api/ocupilot/screens/osmgmt.processes/read`, then the status, `code` and
  `detail.failedPair` it observes are recorded verbatim under `### DW-307 observation`,
  `WireSecurityRead.cls`'s Mutation paragraph is rewritten to state that observation and the
  descriptor-only recipe and to assert nothing the story did not see, the window is reverted, and
  `git status --short` and `git diff --stat` are byte-identical to the pre-window snapshot.

## Spec Change Log

- 2026-09-15, lead (owner-delegated decision on the plan's intent gap): the AC was self-contradictory and the AC is the half that was wrong. `epics.md` Story 3.0's second acceptance criterion now reads "a real principal on the throwaway observes the named 403 over HTTP - its status, `code` and `detail.failedPair` recorded - inside a recorded and reverted mutation window, rather than the refusal being observable only through the port's stubbed seam" (was: "rather than the refusal being reachable only through a mutation"). The intent is unchanged: a real principal, real HTTP, the real port rather than `PortFixture`'s seam. The plan's other corrections are accepted as found - the fault code is discarded at `error-log.page.ts`'s `showRefusal`, not by `classifyFault`, so DW-297's blast radius is one screen; `privilegeDeniedAction` already exists and costs no cardinality; the new row goes in at line 329 for five pin bumps; and the mutation window is descriptor-only, since `AreaCoverageProblem` iterates the screen's pairs.
- 2026-09-15, re-plan against the amended AC. The intent contract is carried verbatim. Corrections found on re-verification, each fixed at its Code Map anchor: `api.ts`'s `detail` is at `:120`, not `:116-118`; `result.kind !== 'ok'` narrows to `installing | error` and the `installing` arm has **no** `detail`, so the store capture needs a further `result.kind === 'error'` guard; `strings.ts` carries 201 pinned keys, not 202, and the five pins to bump are the pin lines `:446/:448/:450/:452/:454`; the `150..220` band constrains table literals (202 to 206), not keys, and the cardinality assertion derives both sides so no number is edited; the page-spec stub hard-codes `detail: null` and needs a new argument; `WireSecurityRead`'s ProcessList leg is `:381`, not `:375`, and `AssertReadRefused` hard-codes both 403 and `AUTH.NOPRIVILEGE` so the `code` assertion is the one that moves. The three 404 sentences were reworded into the house `is no longer present` family (see Design Notes). AC5 was folded into AC4 so that every AC carries a pinning test with a demonstrated mutation (Rule 19).

## Review Triage Log

### 2026-09-15 — Review pass

- verdicts: 31 findings — high 0, medium 6, low 24, false 1, maybe-false 0
- findings:
  - `[low]` `[patch]` blind-hunter: inserting the row at EXPERIENCE.md:329 moved the document's own `` `:N` `` back-references — verified each against `git show 836d5e3:`; exactly one (row 325's `` `:343` ``, the namespace switch's accessible name) pointed at the right `| header |` row before the change and now points at `| side-bar |`. Patched to `` `:344` ``; the rest were already wrong pre-change and are deferred.
  - `[low]` `[reject]` blind-hunter: `refusalMessage` branches on `code` alone, so `LOG.NAMESPACE` at `list`/`detail` and `LOG.DATE` at `detail` name a list Back does not reach in one press — CONFIRMED real (`LogSourcePort.ErrorsRead` checks `NamespaceHeld` for every level but `namespaces`, `DateHeld` for `list`/`detail`), but the Back control renders during a refusal and `back()` walks one level per press, so the advice converges instead of dead-ending, and it needs a purge landing between two reads in one session. The fix is a level branch (which would swap an accurate sentence for the `'request refused'` fragment) or a copy rewrite — more than a direct correction. `reopen_if`: a session shows the sentence naming a list Back does not reach and the user stops rather than pressing Back again.
  - `[medium]` `[patch]` blind-hunter: `spec-2-13`'s `## Auto Run Result` still read "**Not written:** DW-307's third leg" — a wrong claim standing at its origin, which CLAUDE.md names as the thing later passes mine as evidence. Rewritten there to "Deferred to Story 3.0, and written there", citing `### DW-307 observation`.
  - `[low]` `[patch]` blind-hunter: `### DW-307 observation` cited `WireSecurityRead.cls:379`/`:380` — CONFIRMED stale (this story's own doc-comment rewrite moved them to `:382`/`:383`). The stale cites removed from the prose and the AC4 `mutation:` line, and the current positions stated with why they moved.
  - `[low]` `[patch]` blind-hunter: `formatDeniedAction`/`ACTION_PLACEHOLDER` ship with no test in `ui/tools/navigation.test.mjs`, where both siblings are pinned — added there with both slots, every-occurrence and no-placeholder-ships assertions, and a demonstrated mutation.
  - `[low]` `[reject]` blind-hunter: `connectivityRequestRefused` is `'request refused'`, a status-strip fragment rather than a sentence, and `LogSourcePort.cls:609`'s pairless 403 is a shipped path that lands on it — CONFIRMED as fact, but this is pre-existing published copy the intent explicitly preserves ("Every refusal the page cannot name keeps `connectivityRequestRefused`"); changing it needs an EXPERIENCE.md row edit and is a product copy decision. `reopen_if`: a user reports the bare fragment on the unresolvable-namespace path.
  - `[medium]` `[defer]` blind-hunter: the 403-carrying-a-pair sentence is never exercised against a real envelope — deferred with evidence; both halves of the seam are pinned on their own side, the rendered sentence is not.
  - `[medium]` `[patch]` blind-hunter: the matrix's `not-installed` input had no test host, because `StubApi` could only return `kind: 'error'` — added a `StubApi.install()` arm and a leg pinning that an `INSTALL.*` 503 renders the fallback and captures no pair. Mutation demonstrated.
  - `[low]` `[patch]` blind-hunter: "the captured pair is cleared with it" was asserted only for the notice, never for the pair, on a successful read — leg added that re-establishes the pair, asserts it present, then succeeds and asserts both cleared; mutation demonstrated. The `reset()` half was checked and left: every `read()` clears before any fault is set, so no user-visible regression exists if it is dropped.
  - `[false]` `[reject]` blind-hunter: frontmatter `status: 'in-review'` disagrees with `## Auto Run Result`'s `Status: done` — an artifact of reviewing a mid-flight spec; step-04's Finalize writes `status: done` and rewrites the section, which it has.
  - `[low]` `[patch]` blind-hunter: `baseline_commit` absent — added (30 of 33 specs in the tree carry both keys, and `bmad-walkthrough` keys on `baseline_commit` alone).
  - `[low]` `[patch]` blind-hunter: `reverted=` records aggregate counts this story's own later edits invalidated — kept as the window-time snapshot they are, and restated in the durable form a later reader can re-check: `ProcessList.cls` appears nowhere in the story's diff.
  - `[low]` `[patch]` blind-hunter: `strings.test.mjs`'s test title no longer described its body — extended to name the namespace-key roster it now also pins.
  - `[low]` `[reject]` blind-hunter: the row deviates from DW-297's adjudication (one row carrying four literals, against "three new rows") without recording it — the fix is to edit this build's spec or the ledger, and `bmad-build-auto` never writes the ledger (Rule 15a); the lead annotates DW-297 at harvest.
  - `[low]` `[reject]` blind-hunter: `showRefusal`'s doc comment lost its matrix citation — the replacement states the contract, `refusalMessage` carries the AD-39/AD-8 citations, and the project's Prose discipline asks for less narration at doc comments, not more.
  - `[low]` `[reject]` blind-hunter: the three sentences end in an elliptical clause ("…to see which namespaces are.") unlike `faultAbsentEntity`'s completed one — the copy is canonical in EXPERIENCE.md, passes `check-prose.py`, reads as idiomatic ellipsis, and rewording published copy is a product decision.
  - `[low]` `[reject]` blind-hunter: the rewritten Mutation paragraph mixes imperative recipe with passive past report in one ~90-word sentence — accurate, inside the spec's two-sentence budget, and the mixed voice is the content: the recipe is a recipe, the outcome was observed.
  - `[low]` `[reject]` edge-case-hunter: `refusalMessage` level mismatch — same root cause as the blind-hunter row above; shares its route and its `reopen_if`.
  - `[low]` `[patch]` edge-case-hunter: the row insertion shifted ungated `EXPERIENCE.md:N` citations across `_bmad-output/**` — same root cause as the first row; the one in-document citation this change broke is patched and the corpus-wide rot deferred.
  - `[medium]` `[defer]` edge-case-hunter: the retained "Swap the descriptor's first two pairs -> the SECUREUSER assertions go red, and only they" is an unobserved claim left in the paragraph DW-307 was about — CONFIRMED (the window ran the pair REMOVAL only). Deferred rather than patched: settling it needs another throwaway cycle this story did not charter, and deleting a useful recipe is worse than labelling it.
  - `[low]` `[patch]` edge-case-hunter: `:382`/`:383` versus the recorded `:379`/`:380` — same root cause as the stale-cite row; patched with it.
  - `[low]` `[patch]` verification-gap: EXPERIENCE.md:325's `` `:343` `` was correct at HEAD and is broken by this change — accepted pre-verified and patched to `` `:344` ``, which independent checking confirmed.
  - `[low]` `[defer]` verification-gap: no gate resolves EXPERIENCE.md's own line citations or the spec corpus's, and the rest of them were already stale — deferred with the per-citation evidence.
  - `[low]` `[patch]` verification-gap: the spec's observation cites `:379`/`:380` — same root cause as the stale-cite row; patched with it.
  - `[low]` `[patch]` verification-gap (Rule 19): `error-log.page.spec.ts:354` and `:361`'s `not.toBe` assertions cannot fail — each is entailed by the preceding `toBe` against a different key plus `strings.test.mjs`'s every-value-is-unique gate. Both removed, and the comment now says what actually carries "no two read alike". The pinning assertions themselves are falsifiable and their mutation is demonstrated.
  - `[low]` `[reject]` verification-gap (Rule 19): nothing keeps `WireSecurityRead`'s prose true if `AdminPort`'s probe changes — real, and dispositioned by design at `## Design Notes` › "Why AC5 was folded into AC4 (Rule 19)", which establishes that no test in this repo asserts on `.cls` comment text and that `check-objectscript.py` strips comments before its rules run.
  - `[medium]` `[defer]` intent-alignment D1: the privilege-denial row is specified at the envelope and asserted only at a stub this same diff taught to carry that envelope — same root cause as the blind-hunter browser-coverage row; shares its deferral.
  - `[medium]` `[patch]` intent-alignment D2: `not-installed` is named by the matrix, reaches `refusalMessage`, and is exercised by nothing — same root cause as the `StubApi.install()` row; patched with it.
  - `[low]` `[patch]` intent-alignment D3: `formatDeniedAction` added at the `core/navigation.ts` surface and tested only at the page surface — same root cause as the navigation-test row; patched with it.
  - `[low]` `[patch]` intent-alignment D4: "the captured pair is cleared with it" asserted at the refusal surface, not the success surface — same root cause as the clearing row; patched with it.
  - `[low]` `[patch]` intent-alignment D5: `reverted=` carries a prose summary and aggregate counts rather than either command's output — same root cause as the `reverted=` row; patched with it.

## Design Notes

**Governing architecture decisions (Rule 6).**

- **AD-39** — one envelope, two renderings: the screen chooses its own published copy by the **stable
  machine code**, never by the rewordable human `reason`. DW-297 is this AD not yet kept at this surface.
- **AD-8** — a denial names the `(resource, permission)` pair that failed *"so the UX can say which
  privilege is missing."* Rendering `detail.failedPair` into the 403 pattern is that promise kept.
- **AD-12** — one error envelope, one response writer: no new code and no new envelope field.
- **AD-29** — a screen's pair set is established by reading the backing query **and** *"run the read as a
  real least-privileged principal on a throwaway and add what the instance still refuses."* AC4 is the
  technique this AD names.
- **AD-37** — a reference that no longer resolves renders as "no longer present" rather than failing the
  screen; the three 404 sentences follow that published pattern, in its published words.
- **AD-48** — the application error log reads through `SYS.ApplicationError`, which is where the three
  absence codes come from.
- **AD-19** — screen state is a store, never a component field: the failed pair is captured in
  `ErrorLogDrill`, not in the page.

**Consumes:** Story 2.12 (the error-log endpoint, its codes and the page), Story 2.13 (`QUERYPAIRS`, the
port's named 403 and the `Test/AdminPortFault` seam), Story 1.13 (fault classification and the inline
refusal), Story 1.2 (the string table and its two gates), Story 2.9 (`ProcessList` and `WireSecurityRead`'s
nine principals).

**Consumed-by:** no later story consumes these strings — this is a cleanup story that introduces no
service. AC4's technique is consumed by **Stories 6.8 and 6.10**, whose narrower os-management screens
`Test/NarrowArea.cls` says must have their pair sets settled by running each read as a least-privileged
principal on a throwaway.

**Why the failed pair is captured in the store, not in `Fault`.** DW-297 is recorded `fix-risk: high`
because branching on `fault.code` looked like it needed the shared fault path. It does not: `code` already
survives `classifyFault` and is discarded at the page's own `showRefusal`, and `detail` is still in hand in
`error-log.store.ts`'s error arm. Capturing the pair there leaves `fault.ts`, `api.ts` and `screen-read.ts`
untouched, so the blast radius is one screen.

**Why the sentences are worded as they are.** `strings.ts:81` already publishes
`<name> is no longer present on this instance. Return to the list to see what is there now.`
(`faultAbsentEntity`, EXPERIENCE.md:264, AD-37) for a detail view whose target no longer resolves. The
three new sentences are deliberately the same family in the same words — *is no longer present* — rather
than a second spelling of it, and differ only where the surface differs: they name the drill level the
read refused and send the user to this screen's own **Back** control (`errorLogBack`, EXPERIENCE.md:328)
instead of "the list". They must also not read like the **empty states** one row above them
(EXPERIENCE.md:326, `No application errors in <NAMESPACE>.`), which mean the opposite thing — a level that
resolved and holds nothing. `faultAbsentEntity` itself is not reused: it takes a `<name>` the page would
have to resolve per level, which is the formatter and second failure mode this story declines below.

**Why the row is inserted at 329 rather than appended.** Insertion shifts the `strings.ts` line pins below
it; only **five** pins cite 329 or later, so the cost is five one-character edits and the row stays with
its screen's group. Inserting above the error-log rows would shift roughly 190 pins.
`citations.test.mjs` is unaffected either way — its anchors are quoted phrases, not line numbers.

**Declined, with reasons.** No sentence is published for `LOG.MAXROWS`: the client owns the `maxRows` it
sends, so no shipped path reaches that 400, and copy for an unreachable refusal is a claim no one can
check. The sentences carry no `<NAMESPACE>`/`<DATE>` placeholder: distinguishing the four refusals is the
chartered fix, and naming the refused value needs a formatter and a second failure mode for no gain
against that defect.

**A test-package descriptor is not an option for AC4.** The HTTP read route gates on the descriptor the
registry resolved (`Api/ScreenRead.cls:56-62`), and `Screen.Registry.Descriptors` enumerates
`OcuPilot.Screen.Descriptor.` only (`Registry.cls:43, :80-88`); its `DescriptorPackage()` seam
(`:48-55`) is an in-process subclass override documented *"Production never overrides it"*, so a fixture
under `OcuPilot.Test.` is never routed over HTTP **(inference from those two sites; the window itself
confirms it, since a routed fixture would have made the window unnecessary)**. The port's probe is
defence in depth for a **mis-declared** screen, and every shipped descriptor declares correctly — so a
real principal can reach `PORT.ACCESSDENIED` only while a descriptor is temporarily wrong. That is why
AC4 is a recorded and reverted window and not a committed test.

**Why AC5 was folded into AC4 (Rule 19).** The prose claim in `WireSecurityRead`'s Mutation paragraph has
no pinning test and cannot get one: no test anywhere in this repo asserts on the text of a `.cls` doc
comment, and `scripts/check-objectscript.py` strips comments before its rules run
(`wire_test_sources()`), deliberately. Rather than leave a fifth AC whose `mutation:` line would read
`n/a`, the paragraph rewrite is an outcome of AC4, whose pinning test — `AssertReadRefused`'s `code`
assertion — does move under the window and back. A reviewer checks the paragraph against
`### DW-307 observation` in the same file.

**Stale claim noted, not rewritten here.** `strings.test.mjs`'s roster comment attributes its claim to
DW-126's root cause (*"EXPERIENCE.md publishes no sentence for a namespace that does not exist"*). This
story falsifies that for this screen. The comment is corrected as a task above; the ledger entry is the
lead's to annotate at harvest — `bmad-build-auto` does not write the ledger (Rule 15a).

## Verification

**Commands** (client legs from `ui/`; throwaway legs need `npm run build` first, then
`sh scripts/ci-throwaway.sh up` — container `ocupilot-ci` on port 52776, which is what arms
`OCUPILOT_ALLOW_PRINCIPALS`. Never against the live `ocupilot` container.):

- `npm run build` — expected: the six prebuild checkers and the Angular build pass.
- `npm test` — expected: `node --test tools/*.test.mjs` green, with `strings.test.mjs`'s cardinality
  balancing at 206 + 12 + 3 = 221 and its namespace roster at three keys; then `ng test` green,
  including the new per-code cases in `error-log.page.spec.ts`.
- `OCUPILOT_BROWSER_EXECUTABLE="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" npm run test:browser`
  — expected: `error-log.browser-spec.mjs` green, its refused-level test observing the namespace sentence.
  `pretest:browser` rebuilds the harness bundle, so the client change is in the bundle under test.
- `node ui/tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.WireSecurityRead` — expected:
  green on the unmutated tree; **one class per invocation, and never two test calls in one message.**
- `uv run scripts/check-objectscript.py` — expected: 17 rules, no findings.
- `bash scripts/lint-docs.sh` — expected: clean, including the edited EXPERIENCE.md.

**The DW-307 observation window (AC4), in order:** snapshot `git status --short` and `git diff --stat`;
remove the `%Admin_Manage:USE` entry from `ProcessList.cls:88` (**the descriptor only** — the area keeps
its three, and `AreaCoverageProblem` checks the area covers the screen, so the narrowed screen still
installs); `npm run build` in `ui/`; `sh scripts/ci-throwaway.sh up`; `sh scripts/wait-readiness.sh --url
http://localhost:52776/api/ocupilot/readiness/`; run `OcuPilot.Test.WireSecurityRead` and read
`AssertReadRefused`'s assertions for `OPERATEUSER`; record the actual status, `code` and
`detail.failedPair` below verbatim; `sh scripts/ci-throwaway.sh down`; revert; confirm `git status
--short` and `git diff --stat` match the snapshot; `up` again and confirm the class is green.

### DW-307 observation

`ocupilot-ci`, 2026-09-15, `%Admin_Manage:USE` removed from `ProcessList.cls:88` only.
`OcuPilotWireOperate` was created through `WireSecurityRead.EnsurePrincipal` with the leg's own
resources and read back as `operate=1 irissysread=1 manage=0`, then issued
`GET /api/ocupilot/screens/osmgmt.processes/read?maxRows=5` over HTTP:

- `status=403`
- `code=PORT.ACCESSDENIED`
- `detail.failedPair=%Admin_Manage:USE`
- `reverted=` `git status --short` and `git diff --stat` after the revert `diff` clean against the
  pre-window snapshot taken at window time (9 modified files; `215 insertions(+), 36 deletions(-)`),
  with `ProcessList.cls:88` again declaring all three pairs. Those counts are the window's, not the
  story's, and the story kept editing after it, so the durable form a later reader can re-check is
  this: **`src/OcuPilot/Screen/Descriptor/ProcessList.cls` appears nowhere in this story's diff**
  (`git diff <baseline_revision> --stat`), which is only true if the window was reverted.

Whole envelope, verbatim:
`{"error":"forbidden","reason":"This account may not perform that operation on this instance","code":"PORT.ACCESSDENIED","detail":{"failedPair":"%Admin_Manage:USE"}}`

Under the same window `OcuPilot.Test.WireSecurityRead` ran 6 tests, 1 failed:
`TestTheProcessesListsPairSetIsEnforcedForARealPrincipal`, on `ScreensFor` (the screen is now listed
allowed) and on `AssertReadRefused`'s hard-coded `code` assertion (`:291`). Its status (`:289`),
`failedPair` (`:292`) and area-verdict assertions stayed green — which is the independent
confirmation that the status was 403 and the pair `%Admin_Manage:USE`. The class was green on the
unmutated tree before the window and after the revert. The two leg assertions are at `:382`
(`ScreensFor`) and `:383` (`AreaVerdictFor`) in the committed tree; they were three lines higher
during the window, before this story's own doc-comment rewrite grew the method's header.

**Pinning tests and their mutations (Rule 19 — one demonstrated mutation per AC; apply, observe red,
revert, confirm `git status --short` and `git diff --stat` unchanged):**

- **AC1** — `error-log.page.spec.ts`'s per-code cases.
  `mutation: return STRINGS.errorLogRefusedEntry from refusalMessage's LOG.DATE arm -> the purged-date
  case goes red naming both sentences, while the entry case stays green.`
- **AC1, no-pair edge** — the `AUTH.NOPRIVILEGE`-without-`detail` case.
  `mutation: drop the non-empty check on failedPair -> that case renders "You need  to read this log."
  and goes red, while the case that carries a pair stays green.`
- **AC1, unnamed fallback** — the `LOG.MAXROWS` / `null`-code / `not-installed` case.
  `mutation (observed): return STRINGS.errorLogRefusedNamespace from refusalMessage's final arm ->
  the unnamed-fallback test and the privilege-denial test's no-pair leg both go red, while the
  named-code test (LOG.NAMESPACE / LOG.DATE / LOG.ENTRY) stays green.`
- **AC1, refusal clears** — the pair-cleared-by-a-successful-read leg.
  `mutation (observed): clear failedPairValue only on read()'s error path instead of at the top of
  every read -> that leg goes red with 'expected %DB_IRISSYS:READ to be ""', while the leg proving
  a pair does not survive into a pairless refusal stays green.`
- **AC2** — `ui/tools/strings.test.mjs`.
  `mutation (observed): add a fifth key with no EXPERIENCE.md row -> the unauthorized-values
  assertion goes red naming that key -- it asserts before the count in the same test, so the
  cardinality line is never reached; remove errorLogRefusedNamespace from the roster list -> the
  roster assertion goes red.`
- **AC2, the new formatter** — `ui/tools/navigation.test.mjs`'s placeholder test.
  `mutation: give ACTION_PLACEHOLDER any other spelling -> formatDeniedAction's assertion goes red
  with <action> still unresolved, while formatRequires and formatDeniedScreen stay green.`
- **AC3** — `ui/browser/error-log.browser-spec.mjs`'s refused-level test.
  `mutation (observed): render STRINGS.connectivityRequestRefused unconditionally at
  error-log.page.ts:65 -> that browser leg goes red against the real 404 from the live endpoint while
  the other three browser legs stay green. Only the browser leg was run under this mutation, so what
  the stubbed unit cases do under it is not recorded here.`
- **AC4** — the window is itself the mutation; record it applied.
  `mutation (applied, observed, reverted): remove %Admin_Manage:USE from ProcessList.cls:88 ->
  AssertReadRefused's hard-coded code assertion (WireSecurityRead.cls:291) goes red for OPERATEUSER
  naming the observed code, and the leg's ScreensFor verdict goes red with it, while the status
  (:289), the failedPair (:292) and the area verdict stay green; reverted, all are green.`

**QA pass (DW-322, DW-323 closure), both windows on `ocupilot-ci`, both reverted:**

- **DW-322** — `WireSecurityRead.cls`'s retained pair-swap claim, observed rather than struck.
  `mutation (applied, observed, reverted): swap ProcessList.cls:88's first two declared pairs ->
  only SECUREUSER's ScreensFor assertion (:389) goes red, naming %Admin_Manage:USE instead of
  %Admin_Operate:USE; its AreaVerdictFor (:390), every OPERATEUSER/PROCESSUSER assertion and the
  rest of the suite (6 methods, 1 failed) stay green.` Reverted; `git status --short` and
  `git diff --stat` matched the pre-window snapshot (clean), and the class was green again (6/6)
  after. The Mutation paragraph (`WireSecurityRead.cls:369-377`) is corrected to this observed
  outcome — one assertion, not "the SECUREUSER assertions" plural.
- **DW-323** — a new browser leg drives a genuine `AUTH.NOPRIVILEGE` with a failed pair to the
  rendered page. `ui/browser/error-log.browser-spec.mjs` reuses `OcuPilot.Test.ErrorLogDenial`'s
  own `SERVEDUSER` — its `OnBeforeAllTests`/`OnAfterAllTests` invoked directly rather than through
  `%UnitTest.Manager`, so the account survives the whole browser session — signs in as it, and
  drills into the namespace it holds only READ on.
  `mutation (applied, observed, reverted): disable refusalMessage's AUTH.NOPRIVILEGE arm in
  error-log.page.ts -> the new leg goes red reading the connectivityRequestRefused fragment
  ("request refused") instead of "You need %DB_USER:WRITE to read this log.", while the other
  four legs in the file stay green.` Reverted; `git diff --stat` clean, the rebuilt bundle hash
  (`main-FIQYVADU.js`) matched the pre-mutation build exactly, and the file was green again (5/5)
  after. **An instance-level denial is not reachable this way** — a principal missing
  `%Admin_Operate:USE` or `%DB_IRISSYS:READ` is denied the same pair by the navigation map and
  never gets past `screen-outlet.ts`'s own `allowed()` gate to reach this page at all (confirmed
  against `WireSecurityRead`'s own `TestTheAuditListsPairSetIsEnforcedForARealPrincipal`, which
  shows `logs/errors` denied at the navigation map for exactly that shortfall); the per-namespace
  denial (AD-48) is what closes this gap.
- Files changed in this pass: `ui/browser/error-log.browser-spec.mjs` (QA) — the DW-323 leg and
  its fixture helpers; `src/OcuPilot/Test/WireSecurityRead.cls` (QA) — Mutation paragraph
  corrected to the DW-322 observation. Both ledgered `resolved-by:3-0-epic-2-deferred-cleanup`.

**Manual checks:**

- Confirm no principal, role, rotated log or seeded error is left on the live `ocupilot` container after
  the story, and that the live container was neither recreated nor restarted.
- Confirm the four new literals occur in EXPERIENCE.md exactly once each, that the `Where` cell of the
  new row carries no double quotes, and that each new `strings.ts` key sits on the line immediately
  after its own pin comment.

## Auto Run Result

Status: done
Blocking condition: none

**What was implemented.** DW-297: `refusalMessage` chooses the refusal notice by the envelope's
machine `code` (AD-39) — one published sentence each for `LOG.NAMESPACE`, `LOG.DATE` and
`LOG.ENTRY`, the existing `You need <resource> to <action>.` pattern for an `AUTH.NOPRIVILEGE` that
names a pair (AD-8), and `connectivityRequestRefused` as the default arm. The pair is captured in
`ErrorLogDrill` (AD-19), so `fault.ts`, `api.ts` and `screen-read.ts` are untouched and the blast
radius is one screen. DW-307: the descriptor-only mutation window was opened on `ocupilot-ci` with a
real least-privileged principal, what it observed is recorded verbatim under
`### DW-307 observation`, and the shipped claim in `Test/WireSecurityRead.cls` now states that
observation. Every task in `## Tasks & Acceptance` was executed as written; no plan correction was
needed.

**Files changed (13).**

- `.../EXPERIENCE.md` — one Fixed-strings row at line 329 (four literals); one stale citation in the
  neighbouring row repaired (`:343` → `:344`).
- `ui/src/app/core/strings.ts` — four keys, each on the line after its own `EXPERIENCE.md:329` pin;
  the five pins below bumped.
- `ui/src/app/core/navigation.ts` — `ACTION_PLACEHOLDER` and `formatDeniedAction`.
- `ui/src/app/areas/logs/error-log.store.ts` — `failedPairValue` beside `faultValue`, cleared at both
  of its sites, set behind the required `result.kind === 'error'` narrow; `failedPair()` exposed.
- `ui/src/app/areas/logs/error-log.page.ts` — `refusalMessage`, rendered in place of the fixed string.
- `ui/src/app/areas/logs/error-log.page.spec.ts` — `detail` and `installing` arms on the stub; three
  new cases covering every matrix row.
- `ui/browser/error-log.browser-spec.mjs` — the refused-level leg now asserts the namespace sentence.
- `ui/tools/strings.test.mjs` — the namespace roster grew to three keys and its stale DW-126 claim was
  replaced at its origin; title extended to name the roster.
- `ui/tools/navigation.test.mjs` — `formatDeniedAction` pinned beside its two siblings.
- `src/OcuPilot/Test/WireSecurityRead.cls` — Mutation paragraph rewritten to the observation,
  descriptor-only, `os-management` dropped.
- `spec-2-13-epic-2-burn-down.md` — the "Not written" claim corrected at its origin, plus a change-log
  line.
- `spec-3-0-epic-2-deferred-cleanup.md` — the observation, the triage log, the deferrals, this section.

**Review findings.** 31 findings across four layers — high 0, medium 6, low 24, false 1.
**Patched (10 entries: 2 medium, 8 low):** the one EXPERIENCE.md citation this change broke;
`spec-2-13`'s wrong claim at its origin; the stale `:379`/`:380` cites; `formatDeniedAction`'s missing
gate test; the untested `not-installed` matrix input; the unasserted pair-clearing on a successful
read; `baseline_commit`; the `reverted=` evidence; the `strings.test.mjs` title; two `not.toBe`
assertions that could not fail. **Deferred (3):** EXPERIENCE.md's ungated and largely pre-stale
self-citations; the unobserved pair-swap claim retained in `WireSecurityRead`'s paragraph; the
privilege-denial sentence never rendered from a real envelope. **Rejected (8), each with its reason in
the triage log:** the drill-level/Back-instruction mismatch (real but converging, and its fix is a
branch or a copy rewrite); `connectivityRequestRefused` being a fragment (pre-existing copy the intent
preserves); the frontmatter/result disagreement (false — finalize resolves it); the one-row-vs-three
adjudication departure (the ledger is the lead's); the `showRefusal` comment's dropped matrix citation;
the sentences' elliptical clause; the Mutation paragraph's voice; and the doc comment's inability to
be pinned by a test (dispositioned by design in `## Design Notes`).

**Verification.** `npm run build` and `npm test` from `ui/` — 720 `node --test`, 290 Angular, 0 failed,
cardinality balancing at 206 + 12 + 3 = 221 and the namespace roster at three keys; `bash
scripts/lint-docs.sh` clean; `uv run scripts/check-objectscript.py` 17 rules, 0 problems; the full
browser suite on `ocupilot-ci` 63/63, its refused-level leg reading `errorLogRefusedNamespace` off a
real 404; `node ui/tools/ci-runner.mjs --container ocupilot-ci` **59 classes, 562 tests, 0 failed,
green**; `bash scripts/smoke.sh --container ocupilot-ci` 18/18; `bash scripts/smoke.sh --container
ocupilot` 17/17. The same suite against the live `ocupilot` container ran 59 classes, 482 tests, 0
failed — it exits 1 there only because the ten classes armed by `OCUPILOT_ALLOW_*` refuse off the
throwaway, which is the guard working. The patches after those instance runs touched only tests and
documents: the content-hashed bundle is the same `main-FIQYVADU.js` the browser suite drove, and no
ObjectScript source changed, so both instance legs stand.

**Mutations applied and observed (Rule 19).** AC1 named codes: the `LOG.DATE` arm returning the entry
sentence -> the purged-date leg red naming both sentences, the entry leg green. AC1 no-pair: the
non-empty `failedPair` check dropped -> `You need  to read this log.` and red, the pair-carrying leg
green. AC1 fallback: the final arm returning the namespace sentence -> the unnamed-fallback test and
the no-pair leg red, the named-code test green. AC1 clearing: clearing the pair only on the error path
-> "expected %DB_IRISSYS:READ to be ''" on the successful-read leg, the pairless leg green. AC2:
a fifth key with no table row -> the unauthorized-values assertion red naming the key; the key removed
from the roster -> the roster assertion red. AC2 formatter: `ACTION_PLACEHOLDER` respelled -> the new
assertion red with `<action>` unresolved, its two siblings green. AC3: the generic sentence rendered
unconditionally -> that browser leg red against the live 404, the other three green. AC4: the window
itself. Each was reverted and `git status --short` and `git diff --stat` confirmed unchanged against
the snapshot taken before it. Two `mutation:` lines written at plan time were corrected to what was
actually observed: AC2's (the unauthorized-values assertion reddens before the count line is reached,
naming the key rather than "222 against 221") and AC3's (only the browser leg was run under that
mutation, so what the stubbed unit cases do under it is not claimed).

**Follow-up review recommended: true.** Two medium entries were patched, and the named unverified
risk is this: `StubApi` gained an `installing` arm authored by the review pass, giving the test double
a third `JsonResult` shape it never had. Its behaviour is pinned only by this pass's own mutation, and
nothing in the suite compares the double against the real `ApiService`, so a drift between them would
show as a green `not-installed` leg that proves nothing.

**Residual risks.** The three deferrals above. Also `refusalMessage`'s level-blindness, rejected as a
low with a reopen probe: `LOG.NAMESPACE` at the `list` or `detail` level renders a sentence naming the
namespace list, which Back reaches in two or three presses rather than one.

**The live `ocupilot` container was neither recreated nor restarted** (up 3 days, started 2026-09-11)
and carries no test principal — `Security.Users` holds only `HS_Services` and `irisowner` beyond the
vendor's own, and the three `OcuPilot*` names are the installer's product roles. Every
principal-creating and descriptor-mutating step ran on `ocupilot-ci`, which is down and its scratch
directory removed.
