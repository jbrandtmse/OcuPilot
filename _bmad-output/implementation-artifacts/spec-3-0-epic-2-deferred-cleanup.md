---
title: 'Story 3.0: Epic 2 deferred cleanup'
type: 'bugfix'
created: '2026-09-15'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: ['multiple-goals', 'oversized']
deferred: []
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

The implement pass writes exactly these four lines here, verbatim from the run, and nothing else:
`status=`, `code=`, `detail.failedPair=`, and `reverted=` (the post-revert `git status --short` and
`git diff --stat` output, shown equal to the pre-window snapshot). If the observation differs from
403 / `PORT.ACCESSDENIED` / `%Admin_Manage:USE`, record what it was — the claim is what is on trial,
and the `WireSecurityRead` paragraph is rewritten to the observation either way.

**Pinning tests and their mutations (Rule 19 — one demonstrated mutation per AC; apply, observe red,
revert, confirm `git status --short` and `git diff --stat` unchanged):**

- **AC1** — `error-log.page.spec.ts`'s per-code cases.
  `mutation: return STRINGS.errorLogRefusedEntry from refusalMessage's LOG.DATE arm -> the purged-date
  case goes red naming both sentences, while the entry case stays green.`
- **AC1, no-pair edge** — the `AUTH.NOPRIVILEGE`-without-`detail` case.
  `mutation: drop the non-empty check on failedPair -> that case renders "You need  to read this log."
  and goes red, while the case that carries a pair stays green.`
- **AC2** — `ui/tools/strings.test.mjs`.
  `mutation: add a fifth key with no EXPERIENCE.md row -> the cardinality assertion goes red naming 222
  against 221; remove errorLogRefusedNamespace from the roster list -> the roster assertion goes red.`
- **AC3** — `ui/browser/error-log.browser-spec.mjs`'s refused-level test.
  `mutation: render STRINGS.connectivityRequestRefused unconditionally at error-log.page.ts:65 -> the
  browser assertion goes red against the real 404 from the live endpoint, while the unit cases that stub
  the code also go red -- the browser leg is the one that proves the shipped bundle does it.`
- **AC4** — the window is itself the mutation; record it applied.
  `mutation (applied, observed, reverted): remove %Admin_Manage:USE from ProcessList.cls:88 ->
  AssertReadRefused's hard-coded code assertion (WireSecurityRead.cls:291) goes red for OPERATEUSER
  naming the observed code, and ScreensFor (:379) goes red with it, while the status (:289), the
  failedPair (:292) and the area verdict (:380) stay green; reverted, all are green.`

**Manual checks:**

- Confirm no principal, role, rotated log or seeded error is left on the live `ocupilot` container after
  the story, and that the live container was neither recreated nor restarted.
- Confirm the four new literals occur in EXPERIENCE.md exactly once each, that the `Where` cell of the
  new row carries no double quotes, and that each new `strings.ts` key sits on the line immediately
  after its own pin comment.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none

Planned against `epics.md` Story 3.0's amended second acceptance criterion (the mutation window is now
the sanctioned observation), so the intent gap that blocked the previous pass is closed. The
`<intent-contract>` block is carried verbatim from the draft. Two ledger items are in scope and each is
addressed: **DW-297** by AC1-AC3 and the seven client tasks, **DW-307** by AC4, the window, and the
`WireSecurityRead` and `spec-2-13` corrections. Every AC carries a pinning test with a planned
`mutation:` line; AC5 was folded into AC4 rather than shipped with `mutation: n/a`. No service is
introduced, so Rule 1's Integration AC is AC3's browser leg against the real endpoint, and Rule 2's
`Consumes:` / `Consumed-by:` lists are under `## Design Notes`. Nothing in the instance or the code
contradicts the amended AC, so Rule 5 raises no second tripwire.
