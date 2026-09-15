---
title: 'Story 3.0: Epic 2 deferred cleanup'
type: 'bugfix'
created: '2026-09-15'
status: 'draft'
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

- `ui/src/app/areas/logs/error-log.page.ts` — `showRefusal` getter at **:278-282** reads `this.drill.fault()`
  and consults only `isBannerFault(fault)`, discarding `fault.code`. **This is the defect's single line.**
  Template refusal block at **:63-67** renders `{{ STRINGS.connectivityRequestRefused }}`. The doc comment
  at **:268-277** already names the four codes in play and quotes the unmet matrix requirement.
- `ui/src/app/areas/logs/error-log.store.ts` — `ErrorLogDrill`; `private async read()` sets
  `this.faultValue = classifyFault(result, path)` at **:355** inside `if (result.kind !== 'ok')`. That
  narrowed arm still holds `result.detail`, so the failed pair is capturable **here** with no change to
  `fault.ts`. `fault()` accessor at **:238**; `faultValue` field at **:154**.
- `ui/src/app/core/fault.ts` — `Fault` keeps `kind/status/code/path` (**:49-60**); `classifyFault`
  (**:69**) preserves `code` and drops `detail`. **Read-only for this story.**
- `ui/src/app/core/api.ts` — `JsonResult`'s `error` arm carries `detail: Record<string, unknown> | null`
  (**:116-118**), documented as where a refusal names the failed pair. **Read-only.**
- `ui/src/app/core/navigation.ts` — `RESOURCE_PLACEHOLDER`/`formatRequires` (**:162**),
  `SCREEN_PLACEHOLDER`/`formatDeniedScreen` (**:174**). `formatDeniedAction` belongs beside them.
- `ui/src/app/core/strings.ts` — `STRINGS` at **:53**, 217 keys, 202 with `/** EXPERIENCE.md:n */` pins.
  `privilegeDeniedAction: 'You need <resource> to <action>.'` at **:221** is **declared and rendered by
  nothing today** — reusing it costs zero cardinality. The error-log block is **:409-445**. The five pins
  to bump: three at `EXPERIENCE.md:329` (`homeStarterPrompt*`), one at `:330`
  (`proposalExpectedImpactExample`), one at `:331` (`auditMarkerDescription`).
- `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md` — Fixed strings table
  rows **254-331**, header `| String | Where |` at **:252**. Error-log rows **325-328**; the 403 pattern
  row is **:295** (`"You need <resource> to <action>."` / `request-refused inline message (403)`), which
  already designates this surface. Rows carry **no ids**: identity is line number plus literal text.
- `ui/tools/strings.test.mjs` — cardinality at **:346-350** (`table + prose + extras`, 202+12+3=217);
  duplicate-value ban at **:444-450**; line-pin resolver at **:493-530** (each pinned line must contain
  `"<value>"`); extractor band `150..220` at **:306-309**; **namespace-key roster at :376-383**, whose
  comment claims *"there is still no sentence for an unknown namespace"* — a claim this story falsifies.
- `ui/tools/citations.test.mjs` — anchors are **literal quoted phrases**, each of which must occur in
  EXPERIENCE.md **exactly once** (**:136-160**); line numbers are banned outside `strings.ts`'s gated
  comments (**:94, :162-179**). A mid-table insertion does **not** break this gate by design (**:22**).
- `ui/src/app/areas/logs/error-log.page.spec.ts` — the pin to change is **:303**
  (`expect(refusalText(fixture)).toBe(STRINGS.connectivityRequestRefused)`), driven by
  `api.refuse('dates', 403, 'AUTH.NOPRIVILEGE')` at **:297**; the stub already carries `code` (**:45, :65**).
  Keep the separation pin at **:310**.
- `ui/browser/error-log.browser-spec.mjs` — **:368-411** rewrites the outgoing `namespace` parameter,
  asserts a genuine **404** from the live endpoint (**:400**) and then the generic sentence (**:407-411**).
  This is the integration consumer and it exercises `LOG.NAMESPACE`.
- `src/OcuPilot/Port/LogSourcePort.cls` — `DeniedRefusal` (**:639-647**) supplies `detail.failedPair`
  **only when there is one**, which is the no-pair edge case above. Raise sites: `LOG.MAXROWS` **:569**
  (400), `LOG.NAMESPACE` **:602**, `LOG.DATE` **:617**, `LOG.ENTRY` **:621** (all 404). **Read-only.**
- `src/OcuPilot/Api/Error.cls` — the code vocabulary as class parameters; `AUTHNOPRIVILEGE` **:111**,
  `PORTACCESSDENIED` **:160**, `LOGNAMESPACE` **:246**, `LOGDATE` **:255**, `LOGENTRY` **:261**.
  **Read-only** — no new code is needed.
- `src/OcuPilot/Port/AdminPort.cls` — `Parameter QUERYPAIRS` **:121** (one entry:
  `Process/LIST=%Admin_Manage:USE|%DB_IRISSYS:WRITE`, any-of); the probe at **:355** fires only when the
  vendor sequence errored **and** `RunSequence` raised to 500 **and** the caller holds none of the set;
  `Denied` raises 403 `PORT.ACCESSDENIED` at **:890-898**. **Read-only.**
- `src/OcuPilot/Screen/Descriptor/ProcessList.cls` — `XData Declaration` `privileges` at **:88**; the
  middle pair `{"resource": "%Admin_Manage", "permission": "USE"}` is the mutation target.
  `toolIdentifier` `osmgmt.processes` at **:121**.
- `src/OcuPilot/Test/WireSecurityRead.cls` — guard **:40, :124-128**; principals built **:129-198**
  (`OPERATEUSER` = `%Admin_Operate:U` + `%DB_IRISSYS:R`, **:75, :165**); `AssertReadRefused` **:285-293**
  (asserts 403, then `code`, then `detail.failedPair`); the leg **:375**; the **Mutation paragraph at
  :369-374**, which asserts an outcome no test has observed and names the area as well as the descriptor.
- `src/OcuPilot/Screen/Registry.cls` — `AreaCoverageProblem` **:371-390** iterates the **screen's** pairs
  and requires the area to cover each, so removing a pair from the descriptor alone still installs.
  `Descriptors` **:80** enumerates `OcuPilot.Screen.Descriptor.` only, which is why a test-package
  descriptor (`Test/NarrowArea.cls`, `built: false`) can never serve an HTTP read.
- `scripts/ci-throwaway.sh` — arms the three `OCUPILOT_ALLOW_*` guards at **:126-143**; copies `src/`,
  `scripts/`, `module.xml` and an already-built `ui/dist` (**:93-106**) at `up` time — it does **not**
  build, so a client change needs `npm run build` in `ui/` before `up`, and a source mutation must be
  applied **before** `up` to reach the container.

## Tasks & Acceptance

**Execution:**

- `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md` — insert **one row at
  line 329**, directly under the error-log rows, carrying four double-quoted literals separated by `·`:
  `This instance records no application errors in that namespace. Use Back to see what it holds now.`,
  `The application errors for that date are no longer on this instance. Use Back to see what it holds now.`,
  `That application error is no longer on this instance. Use Back to see what it holds now.`, and
  `read this log`. The `Where` cell names the screen, says one sentence per named refusal, and cites the
  403 pattern row (`` `:295` ``); it must contain **no double quotes**. Rationale: the copy is canonical
  there before any code cites it (DW-297).
- `ui/src/app/core/strings.ts` — add `errorLogRefusedNamespace`, `errorLogRefusedDate`,
  `errorLogRefusedEntry`, `errorLogRefusedAction`, each on one line, single-quoted, trailing comma, each
  preceded by `/** EXPERIENCE.md:329 */`; bump the five pins citing 329/330/331 by one. Every literal is
  ASCII (Rule 14). Rationale: keys and pins land with the row so the cardinality and line-pin gates hold.
- `ui/tools/strings.test.mjs` — add `errorLogRefusedNamespace` to the namespace-key roster at **:376-383**
  and replace the comment's now-false claim (*"there is still no sentence for an unknown namespace"*) with
  what is true: this screen publishes one, and the roster enumerates every namespace-named key so a new one
  is a deliberate act. Rationale: correct the wrong claim at its origin rather than route around it.
- `ui/src/app/core/navigation.ts` — add `ACTION_PLACEHOLDER = '<action>'` and
  `formatDeniedAction(template, failedPair, action)` beside `formatDeniedScreen`, substituting both slots.
  Rationale: one construction per published pattern, as `formatRequires` and `formatDeniedScreen` already are.
- `ui/src/app/areas/logs/error-log.store.ts` — inside the `result.kind !== 'ok'` arm at **:353-358**,
  capture `failedPair` from `result.detail` (string values only; otherwise `''`) into a new private field
  beside `faultValue`, clear it wherever `faultValue` is cleared, and expose a `failedPair(): string`
  reader beside `fault()` at **:238**. Rationale: the pair is available here, so `fault.ts` need not change.
- `ui/src/app/areas/logs/error-log.page.ts` — add a `refusalMessage` getter that reads
  `this.generation()` then maps the fault's `code`: `LOG.NAMESPACE`/`LOG.DATE`/`LOG.ENTRY` to their new
  strings, `AUTH.NOPRIVILEGE` **with a non-empty** `this.drill.failedPair()` to
  `formatDeniedAction(STRINGS.privilegeDeniedAction, pair, STRINGS.errorLogRefusedAction)`, and everything
  else — including an `AUTH.NOPRIVILEGE` with no pair — to `STRINGS.connectivityRequestRefused`. Render it
  at **:65** in place of the fixed string. Update the **:268-277** doc comment to state that the notice is
  chosen by the envelope's code and that the fallback is the default arm; keep it to the method's contract,
  no review history. Rationale: this is DW-297's fix.
- `ui/src/app/areas/logs/error-log.page.spec.ts` — change the **:303** assertion to the 403 sentence and
  add one case per matrix row above, including the no-pair fallback and one unnamed code. Rationale: the
  matrix's edge cases need a unit host.
- `ui/browser/error-log.browser-spec.mjs` — change the **:407-411** assertion to
  `STRINGS.errorLogRefusedNamespace`, and update the inline `Mutation (Rule 19)` note at **:402-405** to
  the new sentence. Rationale: this is the Integration AC's observation — a real 404 from the live
  endpoint, rendered by the shipped bundle.
- `src/OcuPilot/Test/WireSecurityRead.cls` — after the observation, rewrite the Mutation paragraph at
  **:369-374** to say what was observed rather than what was derived, and drop *"and from the
  `os-management` area"* from the recipe: the window needs the descriptor alone, and the area edit is a
  second, unnecessary change whose own variant (`area` only) does not install. Keep it to two sentences.
  Rationale: a shipped comment must not assert an unobserved outcome.
- `_bmad-output/implementation-artifacts/spec-3-0-epic-2-deferred-cleanup.md` — record the observation's
  verbatim status, `code` and `detail.failedPair` under `## Verification`, with the snapshot evidence that
  the window was reverted. Rationale: DW-307's deliverable is the recorded observation.

**Acceptance Criteria:**

- **AC1 (DW-297).** Given the four named refusals the error-log read can answer, when each reaches the
  page, then each renders a different published sentence and no two read alike — the privilege denial
  through the existing `You need <resource> to <action>.` row resolved from `detail.failedPair`, and every
  other refusal through the unchanged `connectivityRequestRefused` fallback.
- **AC2 (DW-297, gates).** Given the new copy, when `npm run build` and `npm test` run from `ui/`, then
  `strings.test.mjs` passes with the cardinality balanced at 206 table literals + 12 prose + 3 extras = 221
  keys, its namespace roster lists exactly three keys, and `citations.test.mjs` passes with no bare line
  number outside `strings.ts`'s gated comments.
- **AC3 (Integration AC, DW-297).** Given the shipped bundle on the throwaway, when
  `ui/browser/error-log.browser-spec.mjs` forces a genuine 404 `LOG.NAMESPACE` against the live endpoint,
  then the browser observes `STRINGS.errorLogRefusedNamespace` in `[data-ocu-drill="refusal"]` — not the
  generic sentence, and not a blank frame.
- **AC4 (DW-307).** Given `ocupilot-ci` built from a tree with `%Admin_Manage:USE` removed from
  `ProcessList`'s `privileges` and `OCUPILOT_ALLOW_PRINCIPALS` armed, when `OPERATEUSER` — a real principal
  holding `%Admin_Operate:USE` and `%DB_IRISSYS:READ` and not `%Admin_Manage:USE` — GETs
  `/api/ocupilot/screens/osmgmt.processes/read`, then the status, `code` and `detail.failedPair` it
  observes are recorded verbatim in `## Verification`, the mutation is reverted, and `git status --short`
  and `git diff --stat` are byte-identical to the pre-window snapshot.
- **AC5 (DW-307).** Given that observation, when `Test/WireSecurityRead.cls`'s Mutation paragraph is
  re-read, then it states the observed outcome and the descriptor-only recipe, and asserts nothing the
  story did not see.

## Spec Change Log
- 2026-09-15, lead (owner-delegated decision on the plan's intent gap): the AC was self-contradictory and the AC is the half that was wrong. `epics.md` Story 3.0's second acceptance criterion now reads "a real principal on the throwaway observes the named 403 over HTTP - its status, `code` and `detail.failedPair` recorded - inside a recorded and reverted mutation window, rather than the refusal being observable only through the port's stubbed seam" (was: "rather than the refusal being reachable only through a mutation"). The intent is unchanged: a real principal, real HTTP, the real port rather than `PortFixture`'s seam. The plan's other corrections are accepted as found - the fault code is discarded at `error-log.page.ts`'s `showRefusal`, not by `classifyFault`, so DW-297's blast radius is one screen; `privilegeDeniedAction` already exists and costs no cardinality; the new row goes in at line 329 for five pin bumps; and the mutation window is descriptor-only, since `AreaCoverageProblem` iterates the screen's pairs.

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
  screen; the purged-date and gone-entry sentences follow that published pattern.
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

**Why the row is inserted at 329 rather than appended.** Insertion shifts the `strings.ts` line pins below
it; only **five** pins cite 329 or later, so the cost is five one-character edits and the row stays with
its screen's group. Inserting above the error-log rows would shift roughly 190 pins.
`citations.test.mjs` is unaffected either way — its anchors are quoted phrases, not line numbers.

**Declined, with reasons.** No sentence is published for `LOG.MAXROWS`: the client owns the `maxRows` it
sends, so no shipped path reaches that 400, and copy for an unreachable refusal is a claim no one can
check. The sentences carry no `<NAMESPACE>`/`<DATE>` placeholder: distinguishing the four refusals is the
chartered fix, and naming the refused value needs a formatter and a second failure mode for no gain
against that defect.

**A test-package descriptor is not an option for AC4.** `Screen.Registry.Descriptors` enumerates the
`OcuPilot.Screen.Descriptor.` package only, so a fixture under `OcuPilot.Test.` is never routed and can
never serve an HTTP read. The port's probe is defence in depth for a **mis-declared** screen, and every
shipped descriptor declares correctly — so a real principal can reach `PORT.ACCESSDENIED` only while a
descriptor is temporarily wrong. That is why AC4 is a recorded and reverted window and not a committed
test, and it is the blocking condition recorded below.

## Verification

**Commands** (client legs from `ui/`; throwaway legs need `npm run build` first, then
`sh scripts/ci-throwaway.sh up` — container `ocupilot-ci` on port 52776, which is what arms
`OCUPILOT_ALLOW_PRINCIPALS`. Never against the live `ocupilot` container.):

- `npm run build` — expected: the five prebuild checkers and the Angular build pass.
- `npm test` — expected: `node --test tools/*.test.mjs` green, with `strings.test.mjs`'s cardinality at
  206 + 12 + 3 = 221 and its namespace roster at three keys; then the component runner green, including the
  new per-code cases in `error-log.page.spec.ts`.
- `OCUPILOT_BROWSER_EXECUTABLE="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" npm run test:browser`
  — expected: `error-log.browser-spec.mjs` green, its refused-level test observing the namespace sentence.
- `node ui/tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.WireSecurityRead` — expected:
  green on the unmutated tree; **one class per invocation, and never two test calls in one message.**
- `uv run scripts/check-objectscript.py` — expected: 17 rules, no findings.
- `bash scripts/lint-docs.sh` — expected: clean, including the edited EXPERIENCE.md.

**The DW-307 observation window (AC4), in order:** snapshot `git status --short` and `git diff --stat`;
remove the `%Admin_Manage:USE` entry from `ProcessList.cls` `XData Declaration` `privileges` (**the
descriptor only** — the area keeps its three, and `AreaCoverageProblem` checks the area covers the screen,
so the narrowed screen still installs); `sh scripts/ci-throwaway.sh up`; `sh scripts/wait-readiness.sh
--url http://localhost:52776/api/ocupilot/readiness/`; run `OcuPilot.Test.WireSecurityRead` and read
`AssertReadRefused`'s code assertion for `OPERATEUSER` — only that assertion should move, since the status
and the failed pair are the same under both refusals; record the actual status, `code` and
`detail.failedPair` here verbatim; `sh scripts/ci-throwaway.sh down`; revert; confirm `git status --short`
and `git diff --stat` match the snapshot; `up` again and confirm the class is green.

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
  `mutation (applied, observed, reverted): remove %Admin_Manage:USE from ProcessList's privileges ->
  WireSecurityRead's AssertReadRefused code assertion for OPERATEUSER goes red naming the observed code,
  and ScreensFor/AreaVerdictFor move with it; reverted, all are green.`
- **AC5** — no automated pin; the paragraph is prose.
  `mutation: n/a -- verified by reading the paragraph against the recorded observation above.`

**Manual checks:**

- Confirm no principal, role, rotated log or seeded error is left on the live `ocupilot` container after
  the story, and that the live container was neither recreated nor restarted.
- Confirm the four new literals occur in EXPERIENCE.md exactly once each, and that the `Where` cell of the
  new row carries no double quotes.

## Auto Run Result

Status: blocked
Blocking condition: intent gap

**The gap.** `epics.md`'s Story 3.0 block contradicts itself. Its second acceptance criterion
(`_bmad-output/planning-artifacts/epics.md:2241-2243`) reads:

> **Given** a caller that passes a screen's own gate but not the backing query's
> **When** the port answers
> **Then** a real principal on the throwaway observes the named 403, **rather than the refusal being
> reachable only through a mutation.**

Six lines below it, the routed-ledger bullet for the same story (`epics.md:2248`) charters the opposite:
*"a recorded and reverted mutation window is how a shipped class is exercised"* — as does DW-307's decided
trailer (`by=adjudication`, 2026-09-15T11:46:10Z) and `epic-3-context.md:70-72`.

**Why the AC cannot be met as worded.** The port's named 403 exists as defence in depth for a screen whose
descriptor **under-declares** its pair set (`AdminPort.cls:28-33`). `AdminPort.QUERYPAIRS` declares exactly
one requirement, `Process/LIST=%Admin_Manage:USE|%DB_IRISSYS:WRITE` (`AdminPort.cls:121`), and
`Screen/Descriptor/ProcessList.cls:88` declares `%Admin_Manage:USE` — so passing the screen gate guarantees
holding a pair of the port's set, and the probe at `AdminPort.cls:355` can never fire for a real caller.
Every other admin-port endpoint has no declared pair set at all and keeps its 500. A test-package
descriptor cannot substitute: `Screen.Registry.Descriptors` (`Registry.cls:80`, `Parameter
DESCRIPTORPACKAGE`) enumerates `OcuPilot.Screen.Descriptor.` only, so `Test/NarrowArea.cls` is never routed.
Making the 403 reachable with no mutation therefore requires shipping a descriptor that under-declares its
pair set — the exact defect AD-8 and AD-29 exist to prevent. The AC is un-implementable as worded.

**Recommended amendment** (Rule 5; restates an unreachable observable while preserving the intent — a real
principal over real HTTP against the real port, rather than the stubbed `PortFixture` seam that
`Test/AdminPortFault.cls:253` uses today). Replace the `Then` clause at `epics.md:2243` with:

> **Then** a real principal on the throwaway observes the named 403 over HTTP — status, `code` and
> `detail.failedPair` recorded — under a recorded and reverted mutation window, rather than the refusal
> being observable only through the port's stubbed seam.

Everything else in this spec is planned and ready; only AC4/AC5 depend on the amendment. After amending,
record original-vs-amended wording in `## Spec Change Log` with an inline `[AMENDED 2026-09-15 — see the
story change log]` marker at the amended text, re-run the epic-context pre-warm (the amendment makes
`epics.md` newer than `epic-3-context.md`), reset this spec's `status` to `draft`, commit, and re-dispatch
on this spec path — step-02 preserves the `<intent-contract>` block verbatim on a draft resume.
