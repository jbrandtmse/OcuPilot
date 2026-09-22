---
title: 'Story 5.14: Epic 5 burn-down'
type: 'bugfix'
created: '2026-09-22'
baseline_revision: 'fc425bed4a35223eba8a2dbf4c337243ab66ce9a'
status: 'done'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
warnings: ['oversized']
deferred:
  - summary: >-
      A failed run of ui/browser/tasks.browser-spec.mjs leaves its OcuPilotDemoProbe* task-history
      rows behind, and enough of them push the demo row off the rendered page and fail the next run.
    evidence: |-
      Measured on the reused ocupilot-ci: %SYS_Task.History held 42 OcuPilotDemoProbe* rows against
      3 for "OcuPilot nightly purge", with 0 probe tasks alive -- the purge runs only on the path a
      passing run takes, so the failure is self-reinforcing. Deleting the 42 orphans took the spec
      from 12/14 to 14/14 with the tree and bundle unchanged. A fresh throwaway, which is what CI
      builds, never sees it.
    location: >-
      ui/browser/tasks.browser-spec.mjs
    severity: low
  - summary: >-
      spec-5-12's other eight Rule 19 recipes still carry 1/9 and 1/10 denominators from the class
      sizes at the time each was measured; OcuPilot.Test.ProcessControl now holds 11 methods.
    evidence: |-
      Story 5.14 re-measured only the two recipes its own task list names. ProcessControl's 11 was
      read back from %UnitTest_Result on run 6059, not recalled.
    location: >-
      _bmad-output/implementation-artifacts/spec-5-12-os-management-suspend-and-resume-a-process.md
    severity: low
---

<intent-contract>

## Intent

**Problem:** Epic 5's burn-down gate chartered nine filed defects against surfaces this epic already
shipped — four floor-blocking (DW-1336, DW-1437, DW-1438, DW-1467) and five downstream-blocking
(DW-1447, DW-1448, DW-1452, DW-1473, DW-1479). Everything else Epic 5 filed went to
`range-end-cleanup`, which runs after the 2026-09-27 floor, so an entry's presence here is the
decision that it cannot wait.

**Approach:** Eight independent closures, each citing its `DW-n`, each with its own pinning test and
Rule 19 mutation. Nothing new is designed; every change is a correction at the origin of what is
already shipped. DW-1467 is **declined on measurement** (`## Design Notes`), and DW-1437 and DW-1438
are closed by **one** declared service-account list serving both harms rather than two lists kept in
step.

## Boundaries & Constraints

**Always:**

- A refusing arm is **armed at its input** and driven through the shipped `Prohibited.Prohibits()`
  with a real `pDiff`/`pPayload`, never through a test-local re-implementation of the branch order.
  The **permitted** arm is driven the same way. This is Epic 5's signature defect — a safety
  predicate whose executed path is not the path it names — found twelve times across six stories,
  three of them in Story 5.13 alone.
- Geometry belongs in the browser tier. jsdom computes no layout, so a width assertion in
  `panel.spec.ts` would be structurally unfalsifiable (Rule 19).
- A correction replaces the wrong sentence. It never appends a paragraph explaining that the
  sentence was wrong.
- Every `EXPERIENCE.md` edit stays **in place on its existing line**: `ui/src/app/core/strings.ts`
  carries 546 `/** EXPERIENCE.md:n */` references over lines 254-394 and
  `ui/tools/strings.test.mjs:719` resolves every one of them, so a line-count change at or above
  :220 reddens all three CI `gates` legs while `lint-docs` stays clean.
- Every IRIS MCP call carries `server: "ocupilot-slot-a"`. `smoke.sh --container` and any
  `docker exec` against the dev instance name `ocupilot`.

**Never:**

- Never change `.ocu-button-primary`'s `width: 100%` (`ui/src/styles/_components.scss:231`). It is
  load-bearing for the full-width form, login and card buttons; the fix is narrow, on
  `.ocu-panel-send`.
- Never add a probe `(endpoint, type)` pair to the shipped `AdminPort.MUTATINGTYPES`. A fixture
  overrides the parameter; test surface does not ship.
- Never delete an application error, suspend a process or suspend a task on the live `ocupilot` — it
  holds 6 dates and 211 errors and must keep them. Never stop, remove, recreate or `down` the
  `ocupilot` or any `ocupilot-slot-*` container.
- Never widen `AdminPort`'s admitted pair set beyond the six the registry actually reaches; a
  dropped `PUT` pair silently 501s a merge write *after* the claim has committed and the token is
  spent (`Confirm.cls:432-440`).
- No new `%UnitTest` skip may leave a class with zero executed methods; zero executed is a failure,
  never a pass.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Composer proportion | Panel docked at 1,280px and at 900px; empty draft; Send idle (`ocu-button-primary`) | Send's rendered width equals its intrinsic label width; the composer is the wider control; `.ocu-panel-composer-row` does not overflow | No error expected |
| Composer proportion, other states | Proposal live / turn running (`ocu-button-secondary`) | Send's width is unchanged across the three appearances (DESIGN.md `:1122`) | No error expected |
| Last `%All` holder de-privileged by role delta | `pDiff` names `Roles`; payload's roles drop `%All`; target is the only holder that counts | `Prohibits()` answers 1, `PROHIBITED.LASTALLHOLDER`, HTTP 403, zero writes | Refusal names the reason (AD-39) |
| Service account disabled | `pDiff` names `Enabled`; target is `CSPSystem`, `_Ensemble` or `irisowner` | `Prohibits()` answers 1, `PROHIBITED.SERVICEACCOUNT`, HTTP 403, zero writes | Refusal names the reason |
| Ordinary account disabled | `pDiff` names `Enabled`; target is enabled, not `_SYSTEM`, not the caller, not a service account, not the last holder | `Prohibits()` answers 0 — permitted, driven through the shipped entry point | No error expected |
| Census on a stock instance | `SuperUser`, `_Ensemble`, `_SYSTEM`, `irisowner` all hold `%All` | `CountsAsHolder` answers 0 for the three service accounts, so `LastAllHolder` can fire | Census read error fails closed (`pLast = 0`, unchanged) |
| `Task.CRUD/SUSPEND` through the port | `AdminPort.Invoke("Task.CRUD", "SUSPEND", …)` | 501 `PORT.NOTIMPLEMENTED`, before the endpoint is constructed | The pair is in no roster |
| Every shipped write tool's pair | The six `(endpoint, WRITETYPE)` pairs the registry reaches | Admitted unchanged; every merge and action write still executes | A missing pair 501s — the high-risk arm |
| Reused browser instance | Suite run twice back to back against the same throwaway | Both runs green; `OcuPilot_Kernel_State.Pref` carries no rows the first run left | Non-idempotency reddens the second run |
| Spec takes its page from a helper | `ui/browser/*.browser-spec.mjs` importing `signedInAt` from `panel-spec.mjs` | `browser-reset.mjs` counts the helper's context and requires the reset | A spec reaching a context with no reset and no exemption is refused, exit 1 |
| `ProhibitedRoute` on an unarmed throwaway | `OCUPILOT_ALLOW_PRINCIPALS=1`, `OCUPILOT_ALLOW_AUDIT_TOGGLE` unset | 12 methods execute, 1 skipped (`Status=2`), 0 failed | Both unset: the class still refuses whole, as today |

</intent-contract>

## Code Map

### DW-1336 — the panel composer and Send

- `ui/src/styles/_components.scss:3521-3525` `.ocu-panel-composer-row` — `display:flex`,
  `align-items:flex-end`, `gap: var(--ocu-space-2)`. Sizes none of its children.
- `ui/src/styles/_components.scss:3527-3543` `.ocu-panel-composer` — `flex: 1 1 auto`,
  `min-width: 0`, `min-height: var(--ocu-input-height)`, `max-height: calc(4lh + 2 * var(--ocu-space-2) + 2px)`,
  `field-sizing: content`.
- `ui/src/styles/_components.scss:225-240` `.ocu-button-primary` — carries **`width: 100%`** at
  `:231`. **Read-only for this story.**
- `ui/src/styles/_components.scss:3557-3565` — the only `.ocu-panel-send` rules, both
  `[aria-disabled='true']`-qualified. **There is no base `.ocu-panel-send` rule**; the new one lands
  here.
- `ui/src/app/shell/panel.ts:424-449` — the row: `<textarea class="ocu-panel-composer">` then
  `<button class="ocu-panel-send" [class.ocu-button-primary]="!sendSecondary" [class.ocu-button-secondary]="sendSecondary">`.
- `ui/src/styles/_metrics.scss:14,48,49` — `--ocu-space-2: 8px`, `--ocu-control-height: 32px`,
  `--ocu-input-height: 36px`; `:37-38` `--ocu-panel-default: 400px`, `--ocu-panel-min: 320px`.
- `DESIGN.md:1122` — **the declared figure**: the Send control's "width is fixed by the widest label
  so the composer never reflows". `DESIGN.md:536-545`'s `button-primary` token block declares
  height, padding, radius, typography, colors and states and **no `width`**.
- `DESIGN.md:1117` — the composer is a `{spacing.input-height}` field growing to four lines.
- `ui/browser/panel.browser-spec.mjs:180-207` `geometry(page)`, `:538-580` the composer's *height*
  legs, `:610-667` the yield order at 1,920/1,280/1,024/900. `ui/browser/proposal-card.browser-spec.mjs:187+`
  `measure(page, selector)` already returns `width` for `.ocu-panel-send` and discards it — the
  helper shape to reuse. `ui/browser/panel-spec.mjs:62-83` `signedInAt(browser, config, url, viewport, …)`.
- `ui/src/app/shell/panel.spec.ts:338-348` pins the footer's child order and Send's text; no width
  assertion, and none belongs there.

### DW-1437 / DW-1438 — the account side of AD-10

- `src/OcuPilot/Kernel/Proposal/Prohibited.cls:305-369` `Prohibits()` — the shipped entry point;
  `:311` parse, `:312-320` `UNCOVERED`, `:322-328` `ServesOcuPilot` (web-application branch only),
  `:330-331` live read, `:336-337` `pChanged`, `:340-343` the `#TYPEUSER` branch.
- `Prohibited.cls:474-523` `User()` — `:480` the disable-family guard, keyed on
  `$Data(pChanged("Enabled"))` **alone**; `:481-485` `SYSTEMACCOUNT`, `:486-489` `CURRENTUSER`,
  `:490-495` `LASTALLHOLDER`, `:497-508` `PRIVILEGEGRANT`, `:509-518` `UNCOVEREDFIELD`.
- `Prohibited.cls:921-973` `LastAllHolder()`, `:986-992` `CountsAsHolder()` — the only name-based
  exclusion is `Screen.Gate.IsAuthenticatedPrincipal` (`UnknownUser`, `_PUBLIC`); `:1000-1017`
  `HoldsAll()`.
- `Prohibited.cls:1182-1206` `ServesOcuPilot()` + `:51` `SERVINGPATH` — **the model** for an
  account-side analogue: normalize, closed list, error rather than empty, recorded fallback.
- `Prohibited.cls:1039-1063` `Changed()` — `pChanged` subscripts are the diff row's `field`
  spellings, exact case, no folding. Built by `Mint.Merge()` (`Mint.cls:397-401`); the one call site
  is `Confirm.cls:305`.
- `Prohibited.cls:51-101` the twelve codes; `:168-171` `Codes()`; `:176-191` `ReasonFor()`;
  `:238-244` `PermittedChangeFields()` (user admits `Enabled` and `Roles`); `:254-259`
  `AlwaysProhibitedFields()`.
- `src/OcuPilot/Screen/Gate.cls:49` `ANONYMOUSPRINCIPALS = "UnknownUser,_PUBLIC"` — the one existing
  closed account list, and the naming precedent.
- `src/OcuPilot/Test/Prohibited.cls:449-493` the code roster; **`:455` asserts twelve**.
- `src/OcuPilot/Test/UserUpdate.cls` — `:19` `OCUPILOT_ALLOW_PRINCIPALS`, `:149-172` `Seed()`
  (`:166` builds the diff — the armed input), `:177-191` `Refused()` (drives the whole shipped
  confirm), `:356/:381/:404/:440/:457/:510` the refusal legs.
- `src/OcuPilot/Test/ProhibitedFixture.cls:17` extends the shipped set, overriding only
  `PortClass()`, `LastAllHolder()` and `HoldsAll()`; `:67-91` `UserObject()`, `:135-148` `Diff()`,
  `:196-200` `Ask()`.

### DW-1447 / DW-1448 — the browser-tier reset and its checker

- `ui/browser/preferences-reset.mjs:34` `VALUE_KINDS = ['view','refresh','shell']`; `:14-17` the doc
  comment declaring the membership kinds deliberately untouched; `:50-59` `resetRememberedState()`
  POSTs `{kind, action:'clear'}` per kind.
- `ui/src/app/core/account-preferences.ts:33-57` — `FAVORITE_KIND`…`SHELL_KIND` and the
  `PreferenceKind` union: **the authoritative roster** the reset should derive from.
- `src/OcuPilot/Kernel/State/Pref.cls:65-84` the five `KIND*` parameters; `src/OcuPilot/Api/Preferences.cls:242-260`
  `Apply()` — `clear` is legal for the membership kinds too, so the reset needs no server change.
- `ui/src/app/shell/recents-recorder.ts:64` — `registerVisit(route)` on every navigation, which is
  why `recent` accumulates with no spec arranging it.
- `ui/browser/suggested-view.browser-spec.mjs:44` imports `resetRememberedState` and never calls it;
  `:119-121` its local `signedInAt` wrapper delegates to `panel-spec.mjs`, which **already** resets
  at `:68` — so adding a call would double-reset and the honest fix is to drop the unused specifier.
- `ui/tools/browser-reset.mjs:40,50` the two counted spellings; `:105-126` `resetProblem()` with the
  `contexts === 0` early return at **`:107`**; `:129-133` `specFileNames()`; `:148` `main()`'s
  `if (!source.includes(CONTEXT_CALL)) continue;` — a **fourth** blind spot that makes the
  `browser.newPage(` arm dead at the CLI.
- `ui/tools/browser-reset.test.mjs:65-68` the string fixtures, `:151-171` the real-tree loop,
  `:176-187` `runOver()`, `:192-208` the CLI legs, `:210-223` the prebuild/pre-commit wiring.
- `ui/browser/panel-spec.mjs:62-83` — the one shared helper that creates a context (`:68` reset,
  `:69` `createBrowserContext()`, `:70` `context.newPage()`). **12** spec files take their page from
  it and score zero contexts today. `ui/browser/licence.browser-spec.mjs` reaches no context at all
  and must keep passing.
- `ui/package.json:7,9` the `prebuild`/`prestart` chains; `:14` `test:tools`; `:17` `test:browser`.

### DW-1452 — `ProhibitedRoute`'s class-wide arming

- `src/OcuPilot/Test/ProhibitedRoute.cls:29` `ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS"`, `:37`
  `AUDITVARIABLE = "OCUPILOT_ALLOW_AUDIT_TOGGLE"`, `:126-138` `OnBeforeAllTests()` refusing on both,
  `:154-174` `OnAfterOneTest()` (asserts auditing was restored — it runs for a skipped method too).
- The **one** method that toggles auditing: `:805`
  `TestALeastPrivilegedPrincipalConfirmsTheAuditingWriteOverTheWire` (`:833` asserts
  `AuditEnabled() = 0`, `:841` restores). The class holds **13** test methods; **11**, not nine, are
  blocked by `AUDITVARIABLE` today — nine was the count at filing.
- `src/OcuPilot/Test/ProviderSsl.cls:15-17,29-36` — the class-level arming convention.
- `scripts/ci-throwaway.sh:246-247` the `OCUPILOT_ALLOW_AUDIT_TOGGLE` roster comment;
  `ui/tools/ci.test.mjs:1738` holds it equal to the classes that declare the variable — so the
  parameter must stay declared.
- `irislib/%UnitTest/TestCase.cls:50-52,94-95,241-247` and `irislib/%UnitTest/Manager.cls:1234,1272`
  — `$$$AssertSkipped` works from `OnBeforeOneTest` and **not** from `OnBeforeAllTests`; the skip is
  `Status=2`.

### DW-1473 — `AdminPort.MUTATINGTYPES`

- `src/OcuPilot/Port/AdminPort.cls:120-150` `MUTATINGTYPES = "PUT,RESUME,SUSPEND"` (bare suffixes);
  `:152-166` `BODYLESSTYPES = "Task.CRUD/RESUME,Process/SUSPEND,Process/RESUME"` and `:778-783`
  `IsBodyless(pEndpoint, pSuffix)` — **the model**; `:206` `BARETYPES`, read at `:808` with the same
  `pEndpoint _ "/" _ pSuffix` concatenation, one line above the defect.
- The four bare reads: `:437` (object-body refusal), `:793-796` `HttpMethodFor(pSuffix)` (one caller,
  `:443`), **`:813`** (the admission gate — the widening), `:942-947` `Sequence` (reads
  `%request.Method`, no endpoint in hand).
- `:798-818` `EndpointType()`; `""` becomes 501 `PORT.NOTIMPLEMENTED` at `:424-427`.
- The six reachable pairs, established three ways — the registry's own discovery rule
  (`src/OcuPilot/Screen/Tool/Registry.cls:573-584`), a whole-tree `Extends OcuPilot.Screen.Tool.Write`
  sweep including transitive subclasses, and `src/OcuPilot/Test/SurfaceCoverage.cls:100-106` with its
  both-directions assertion at `:291`: `WebApp.App/PUT`, `Security.User/PUT`,
  `Security.Audit.Enabled/PUT`, `Task.CRUD/RESUME`, `Process/SUSPEND`, `Process/RESUME`.
  `Screen/Tool/ErrorDelete.cls:32,40` declares `PORTCLASS = LogSourcePort` and `WRITETYPE = DELETE`
  (AD-52), so its `DELETE` is legitimately absent.
- `src/OcuPilot/Test/ToolWrite.cls:779-844` — `:787` the pair-shape assertion DW-1464 added, and the
  three bare reads that must reshape: **`:789`, `:821`, `:835`**.
  `src/OcuPilot/Test/ProposalFixture.cls:196,204` — has `pEndpoint` in scope and keys bare.
- `src/OcuPilot/Test/AdminPortAsync.cls:47-63` — invokes the probe endpoint
  `OcuPilotProbeAsyncWrite` with `PUT`, a pair in no roster; `src/OcuPilot/Test/PortFixture.cls:9`
  extends the real port, so it is where the probe pair is added.
- `src/OcuPilot/Test/AdminPortFault.cls:243-255` — its `DELETE` leg stays green; its
  `MUTATINGTYPES` comment at `:251-253` goes stale.
- No `ui/tools/` checker and no coverage test reads either parameter's shape.

### DW-1479 — the superseded ownership rule

- The corrected rule, verbatim at its origin:
  `src/OcuPilot/Kernel/Proposal/Prohibited.cls:653-674` `IsOcuPilotProcess` (the `$JOB` arm at
  `:670`, the turn-job arm at `:671-673`, fail-closed at `:667/:669/:672`); `:589-592` the
  dispatcher's narrowing comment; `:87` `OCUPILOTPROCESS`; **`:186` the published sentence**.
  `Screen/Tool/ProcessSuspend.cls:25` and `ProcessResume.cls:22` carry the model-facing wording:
  *"a process OcuPilot is itself running in -- this request, or an agent turn --"*.
  `OwnedByCaller`, `FIELDUSERNAME` and `PROHIBITED.OWNPROCESS` are absent from every code path.
- `_bmad-output/planning-artifacts/epics.md:153` (FR-55 roll-up), `:807` (Epic 7 implementation
  notes, middle conjunct only), **`:3506`** (Story 5.5's worked example, middle conjunct; it must
  stay a `- **Given**` list item for `check-prose.py` rule 1), and **`:5686`** (Story 16.2's
  trailing simile). **The ledger's `:5636` is stale** — `grep -n "own process"` over `epics.md`
  returns exactly 153, 807, 3506, 5686.
- `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md:93` (Surfaces
  table, Purpose cell), `:220` (Privilege Gating table, Rule cell — its one quoted literal
  `"This is OcuPilot's own web application."` illustrates the *web application* limb and stays
  byte-identical), `:414` (Component Patterns, `row-overflow-menu` parenthetical). All three are
  descriptive cells **outside** the Fixed-strings table (`:250` marker, `:252` header, `:254-394`
  rows) and outside `strings.ts`.
- `_bmad-output/planning-artifacts/prds/prd-OcuPilot-2026-09-08/prd.md:806` — a whole bullet, no
  surviving conjunct. `_bmad-output/specs/spec-OcuPilot/SPEC.md:99` (CAP-18) — the trailing clause
  `and refuse action on the user's own process`.
- `_bmad-output/implementation-artifacts/spec-5-12-os-management-suspend-and-resume-a-process.md`
  — `## Verification` at `:885`; the two recipes at **`:928-929`** and **`:943-946`** name
  `OwnedByCaller` and a stale `1/9` count (`ProcessControl` is 10 methods); three siblings outside
  `## Verification` at `:53`, `:623`, `:666`.
- `ui/tools/strings.test.mjs:22-31,48-68,719-764` — the 546 line references over EXPERIENCE.md
  254-394 and the test that resolves them; `ui/tools/citations.test.mjs:44-51,80,136,161` — anchors
  by quoted phrase and enforces **exactly one** occurrence per cited phrase; `scripts/check-prose.py:41-53,279-291`
  — reads all five documents and pins none by position. `lint-docs.sh` is **not** the covering
  checker for a line-anchor break.

## Tasks & Acceptance

**Execution** — Group 1 first so the source edits land before the single compile-and-test sweep.

Group 1 — documents and client tooling, no instance:

- `_bmad-output/planning-artifacts/epics.md` — DW-1479. Replace the superseded clause at `:153`; drop
  the `act on the user's own process` conjunct at `:807`; drop the `act on the user's own process,`
  conjunct at `:3506`, keeping it a `- **Given**` list item; replace the trailing simile at `:5686`.
  Converge on the shipped wording (`Prohibited.cls:186`, `ProcessSuspend.cls:25`). Delete the wrong
  text; add no explanatory paragraph.
- `_bmad-output/planning-artifacts/prds/prd-OcuPilot-2026-09-08/prd.md:806` — DW-1479. Replace the
  whole bullet with the narrowed rule.
- `_bmad-output/specs/spec-OcuPilot/SPEC.md:99` — DW-1479. Replace `and refuse action on the user's
  own process` in CAP-18's `success` line; leave the rest of the sentence untouched.
- `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md:93`, `:220`,
  `:414` — DW-1479. Apply the three replacements tabled in `## Design Notes` →
  *Rule 5 amendment recommendation*, or the lead's ratified variant where the spec gate records one.
  Each edit stays **in place on its existing line, with no line-count change**, and `:220`'s quoted
  literal stays byte-identical.
- `_bmad-output/implementation-artifacts/spec-5-12-os-management-suspend-and-resume-a-process.md`
  — DW-1479. Correct `:928-929` and `:943-946` to name `IsOcuPilotProcess` (`Prohibited.cls:665`),
  the refusing branch at `:605-608`, the `OCUPILOTPROCESS` assertions in
  `Test/ProcessControl.cls`, and the current 10-method count; and the three siblings at `:53`,
  `:623`, `:666`, so the set is not half-corrected.
- `ui/src/app/core/account-preferences.ts` — DW-1447. Export one `PREFERENCE_KINDS` roster holding
  all five kinds and derive the `PreferenceKind` union from it, so the union and the roster cannot
  drift.
- `ui/browser/preferences-reset.mjs` — DW-1447. Clear every kind in `PREFERENCE_KINDS`, imported
  from `account-preferences.ts` (the `await import('../src/app/core/…')` precedent is
  `suggested-view.browser-spec.mjs:47-48`), replacing the hand-listed `VALUE_KINDS` at `:34`.
  Replace the `:14-17` doc comment with what the helper now does; the server already accepts `clear`
  for the membership kinds (`Api/Preferences.cls:242-260`), so no endpoint changes.
- `ui/browser/suggested-view.browser-spec.mjs:44` — DW-1447. Drop the unused `resetRememberedState`
  specifier; `panel-spec.mjs:68` owns the reset for every helper-sourced context and a second call
  would double-reset. Keep `rememberedShellMember`.
- `ui/tools/browser-reset.mjs` — DW-1448. Re-key on **context creation wherever it occurs**: resolve
  the local `./*.mjs` import graph over `ui/browser/`, mark a module context-creating when its
  source (line comments stripped) creates a context, and charge a spec for every context it creates
  **or reaches** through an imported binding, including through an alias and a file-local wrapper.
  Delete the `contexts === 0` early return's blindness and `main()`'s `:148` `continue`. A spec that
  reaches no context (`licence.browser-spec.mjs`) still passes; the exemption marker still
  substitutes for the reset.
- `ui/tools/browser-reset.test.mjs` — DW-1448. Add the pins that would have caught all three
  under-detections, at the level each escaped: a helper-sourced spec whose helper does **not** reset
  is refused and one whose helper does is accepted; a spec written only with `browser.newPage(` is
  refused **through the CLI** via `runOver()`, not only through `resetProblem`; the
  call-without-import arm keeps its existing pin. Add a floor on the number of helper-sourced specs
  the graph resolved, so an empty graph reports rather than reading clean.
- `ui/tools/preferences-reset.test.mjs` (new) — DW-1447. Pin that the reset's cleared set equals
  `PREFERENCE_KINDS` and that the roster holds the five kinds `Kernel/State/Pref.cls:65-84`
  declares, so a sixth kind is covered by construction rather than by memory.
- `ui/src/styles/_components.scss` — DW-1336. Add a base `.ocu-panel-send` rule beside `:3557`
  giving the Send control its intrinsic width (`flex: 0 0 auto` and a `width` that cancels
  `.ocu-button-primary:231`'s `width: 100%`), so DESIGN.md `:1122`'s declared rule holds in all
  three appearances. Do **not** edit `.ocu-button-primary`.
- `ui/browser/panel.browser-spec.mjs` — DW-1336. Add the proportion legs described under
  *Acceptance Criteria*, reusing the `measure(page, selector)` shape from
  `proposal-card.browser-spec.mjs:187+` and `signedInAt(url, viewport)` for the two viewports.

Group 2 — ObjectScript:

- `src/OcuPilot/Kernel/Proposal/Prohibited.cls` — DW-1437 and DW-1438, closed with **one** declared
  list. Add a `SERVICEACCOUNTS` parameter (`CSPSystem`, `_Ensemble`, `irisowner`) beside
  `SYSTEMACCOUNTNAME` (`:127`), modeled on `Screen/Gate.cls:49`, with a doc comment naming why each
  member is on it. Use it twice: `CountsAsHolder()` (`:986-992`) answers 0 for a member, so
  `LASTALLHOLDER` can fire on a stock instance; and `User()` gains a refusal arm answering
  `PROHIBITED.SERVICEACCOUNT` when the change disables a member — the account-side analogue of
  `ServesOcuPilot` (`:1182-1206`), because disabling the account the CSP service runs as breaks
  every CSP request including OcuPilot's own. Widen the `:480` guard so a `Roles` delta that removes
  `%All` from the last counting holder reaches `LastAllHolder()` — **one** de-privileges-the-last-holder
  predicate for both the disable and the role-removal path, not two kept in step. Normalize the
  account name through `NormalizedUser()` (`:728-731`) so a re-cased spelling earns one verdict.
- `src/OcuPilot/Kernel/Proposal/Prohibited.cls:168-171` and `:176-191` — add the new code to
  `Codes()` and give it a sentence in `ReasonFor()`; a code with no sentence fails
  `Test/Prohibited.cls`. No client roster needs it — `screen-mirror.mjs` does not mirror error codes
  and the client renders the server's `reason`.
- `src/OcuPilot/Test/Prohibited.cls:455` — raise the declared code count from twelve to thirteen.
- `src/OcuPilot/Test/UserUpdate.cls` — DW-1437, DW-1438. Add the refusing legs and the permitted leg
  as *Acceptance Criteria* below, every one of them through `Refused()`/`Ask()`, which drive the
  shipped `Prohibits()` with an armed `Diff()` — never a test-local branch order.
- `src/OcuPilot/Port/AdminPort.cls` — DW-1473. Re-key `MUTATINGTYPES` (`:150`) to the six
  `(endpoint, type)` pairs, add an `IsMutating(pEndpoint, pSuffix)` helper mirroring `IsBodyless`
  (`:778-783`), and convert all four reads: `:437`, `:793-796` `HttpMethodFor` (add `pEndpoint`; one
  caller at `:443`), `:813` (the admission gate), and `Sequence` at `:942-947` (thread the endpoint
  rather than re-deriving it from `%request.Method`). Update the `:120-149` doc block and
  `AdminPortFault.cls:251-253`'s now-stale comment.
- `src/OcuPilot/Test/ToolWrite.cls:789`, `:821`, `:835` and
  `src/OcuPilot/Test/ProposalFixture.cls:204` — DW-1473. Key by pair; `ProposalFixture.Invoke` has
  `pEndpoint` at `:196`, and leaving it bare would silently diverge from the port's new rule.
- `src/OcuPilot/Test/PortFixture.cls` — DW-1473. Override `MUTATINGTYPES` to add the probe pair
  `OcuPilotProbeAsyncWrite/PUT` that `AdminPortAsync.cls:56` needs. The shipped parameter carries no
  probe pair.
- `src/OcuPilot/Test/ProhibitedRoute.cls` — DW-1452. Leave `ARMINGVARIABLE` class-wide in
  `OnBeforeAllTests` and move the `AUDITVARIABLE` refusal to `OnBeforeOneTest(pMethod)`, skipping the
  one auditing method with `$$$AssertSkipped` (`%UnitTest` supports a skip from `OnBeforeOneTest`
  and explicitly not from `OnBeforeAllTests`). Name that method in a class parameter rather than a
  bare literal, and correct the class header at `:12-19` to say what is now class-wide and what is
  per-method. Confirm `OnAfterOneTest` (`:154-174`) asserts nothing about state a skipped method
  never touched. Keep the `AUDITVARIABLE` parameter declared, or `ci.test.mjs:1738` reddens against
  `ci-throwaway.sh:246`.
- `src/OcuPilot/Test/ProhibitedRoute.cls` — DW-1452. Add one leg asserting the parameter names a
  method the class actually declares (`%Dictionary.CompiledMethod`), so a rename cannot silently
  un-skip the leg and run an audit toggle unarmed.
- `src/OcuPilot/Screen/Tool/AuditingUpdate.cls:55-56` — DW-1467, **declined**; this is its whole
  work. The flag stays `1`. Add one sentence to the existing `DESTRUCTIVE` doc comment naming the
  screen's own confirm dialog (Story 7.4, `button-primary`) as the other surface, so the next reader
  meeting `EXPERIENCE.md:426` beside this parameter does not re-file it. No test changes: every
  assertion on this flag stays as it is.

**Acceptance Criteria:**

- **DW-1336, measured before fixed.** Given the panel docked on a signed-in route, when the
  composer's and Send's rendered widths are measured at 1,280px and at 900px and diffed against
  DESIGN.md `:1122`, then the measurement is recorded in `## Verification` before any style edit —
  the charter requires measuring rather than assuming, and DESIGN.md `:1122` is the declared figure
  the diff is against.
- **DW-1336.** Given the panel at 1,280px and at 900px with an empty draft, when the composer row
  renders in each of Send's three appearances (`ocu-button-primary` idle, `ocu-button-secondary`
  while a proposal is live and while a turn runs), then Send's rendered width is its intrinsic label
  width and is the same in all three, the composer is the wider of the two controls, and
  `.ocu-panel-composer-row`'s `scrollWidth` does not exceed its `clientWidth`.
  `mutation: delete the new .ocu-panel-send base rule -> this leg red in the idle state and green in
  the other two` (the states differ today because `.ocu-button-secondary` declares no `width`, which
  is what makes the leg discriminating rather than a restatement).
- **DW-1437.** Given a proposal whose diff names `Roles` and whose payload removes `%All` from the
  only account that counts as a holder, when the shipped `Prohibits()` is asked with that armed
  input, then it answers 1 with `PROHIBITED.LASTALLHOLDER`, the confirm answers 403 and the write
  count is zero.
- **DW-1437.** Given a stock instance where `SuperUser`, `_Ensemble`, `_SYSTEM` and `irisowner` all
  hold `%All`, when the census runs, then `_Ensemble` and `irisowner` do not count as holders, so a
  disable of the last human holder is refused rather than permitted.
- **DW-1438.** Given a proposal to disable `CSPSystem`, `_Ensemble` or `irisowner`, when the shipped
  `Prohibits()` is asked, then it answers 1 with `PROHIBITED.SERVICEACCOUNT` — including for a
  re-cased spelling of the name — and the account is read back still enabled.
- **DW-1437/DW-1438, the permitted arm.** Given a proposal to disable an ordinary enabled account
  that is not `_SYSTEM`, not the confirming user, not a service account and not the last counting
  `%All` holder, when the shipped `Prohibits()` is asked through the same path, then it answers 0 and
  the write proceeds. This leg is driven through `Prohibits()`, never through a helper that
  re-implements the branch order.
- **DW-1447.** Given a throwaway instance on which the browser suite has already run once, when it
  runs again without clearing `OcuPilot_Kernel_State.Pref` by hand, then both runs are green and the
  suite is idempotent.
- **DW-1447.** Given `ui/browser/suggested-view.browser-spec.mjs`, when its imports are read, then
  every specifier it imports is called somewhere in the file — nothing is imported to look compliant.
- **DW-1448.** Given a spec that takes its page from a helper which does not reset, when
  `node tools/browser-reset.mjs` runs over it, then it exits 1 and names that spec; and given one
  whose helper does reset, then it exits 0.
  `mutation: delete the reset call from panel-spec.mjs:68 -> the checker refuses all 12
  helper-sourced specs` (under today's checker it refuses none, which is the under-detection).
- **DW-1448.** Given a spec written only with `browser.newPage(` and no reset, when the **CLI** runs
  over it — not `resetProblem` called directly — then it exits 1 and names that spec. Today `main()`
  skips the file at `:148` before `resetProblem` ever sees it, so the arm is unreachable from the
  gate that actually runs in `prebuild`.
- **DW-1448.** Given the shipped `ui/browser/` tree, when the re-keyed checker runs, then it reports
  clean — the tree is already behaviorally correct, so a refusal here is a false positive to
  investigate before shipping, not a defect found.
- **DW-1452.** Given a throwaway carrying `OCUPILOT_ALLOW_PRINCIPALS=1` and no
  `OCUPILOT_ALLOW_AUDIT_TOGGLE`, when `OcuPilot.Test.ProhibitedRoute` runs, then 12 methods execute
  and pass and 1 records a skip; with both variables set, 13 execute and pass. Zero executed remains
  a failure.
  `mutation: point the auditing-method parameter at a name the class does not declare -> the new
  roster leg red`.
- **DW-1473.** Given `AdminPort.Invoke("Task.CRUD", "SUSPEND", …)`, when the port resolves the type,
  then it answers 501 `PORT.NOTIMPLEMENTED` before constructing the endpoint; and given each of the
  six `(endpoint, WRITETYPE)` pairs the registry reaches, every one is still admitted and every
  shipped write still executes.
  `mutation: remove Security.User/PUT from MUTATINGTYPES -> OcuPilot.Test.UserUpdate red on the
  confirmed-write legs, and ToolWrite red on the roster leg`.
- **DW-1473.** Given `ToolWrite`'s roster sweep, when it compares every write tool's `WriteType()`
  against the port's admitted set, then it compares **pairs**, so admitting a suffix on one endpoint
  cannot be read as admitting it on another.
- **DW-1479.** Given the nine document locations and `spec-5-12`'s two recipes, when each is read,
  then none states the broad process-ownership rule, `epics.md:3506`'s worked example teaches the
  narrowed rule, and `spec-5-12`'s recipes name a method that exists and a count that matches the
  class.
- **DW-1479, regression guard.** Given the EXPERIENCE.md edits, when `npm run test:tools` runs, then
  `strings.test.mjs` and `citations.test.mjs` are green on all three Node bands — the covering
  checkers for a line-anchor break, which `lint-docs` does not see.
- **Integration.** Given `PREFERENCE_KINDS` newly exported from `ui/src/app/core/account-preferences.ts`,
  when `ui/browser/preferences-reset.mjs` clears remembered state, then it clears exactly the kinds
  that roster holds, observable as the browser suite being idempotent across two consecutive runs.

## Spec Change Log

## Review Triage Log

### 2026-09-22 — Review pass

- verdicts: 17 findings — high 0, medium 3, low 6, false 8, maybe-false 0
- findings:
  - `[medium]` `[patch]` verification-gap: `--ocu-panel-send-width` is pinned as a number for all three Send appearances but as *sufficient for the label* for only one — confirmed: only `panel.browser-spec.mjs`'s idle leg measured `max-content`, so a token that stopped covering the outlined label kept every equality assertion green. Patched: `proposal-card.browser-spec.mjs`'s `sendWidthToken` became `sendWidths`, returning declared **and** intrinsic, and legs (a) and (b) now assert `declared >= intrinsic`. `mutation:` set `--ocu-panel-send-width` to 64px, rebuild + redeploy + reinstall -> leg (a) red (`intrinsic 66.21875 against 64`) with leg (b) green, and every pre-existing equality assertion still passing, which is the gap; reverted to 72px, rebuilt, 14 of 14 green.
  - `[medium]` `[patch]` verification-gap: DW-1452's skip mechanism is unpinned — only the name it reads is. Confirmed: `TestTheAuditingMethodParameterNamesAMethodThisClassDeclares` asserts the parameter and the dictionary, never that `OnBeforeOneTest` still runs, and the audit-toggling body carries no guard of its own. Patched: that method now opens by asserting `AUDITVARIABLE` reads 1 and quitting if it does not. `mutation:` delete `OnBeforeOneTest` from `ProhibitedRoute` and recompile -> the class runs 14 and `TestALeastPrivilegedPrincipalConfirmsTheAuditingWriteOverTheWire` **fails** (run 6062), where before the patch it ran unarmed and passed; reverted, 14 of 14 green (run 6063).
  - `[medium]` `[patch]` verification-gap: `PortFixture.MUTATINGTYPES` is a hand copy of the shipped roster with nothing holding the two in step — confirmed: the shrink direction reddens `ToolWrite`, the growth direction is unpinned, so a later story admitting a pair would leave fixture-driven port tests on the non-mutating branch. Patched: `ToolWrite` now asserts every shipped pair is also in the fixture's roster (the fixture may add, never omit). `mutation:` drop `Process/RESUME` from `PortFixture.MUTATINGTYPES` -> `ToolWrite` red, 1 of 20 (run 6064); reverted, 20 of 20 green (run 6065).
  - `[low]` `[patch]` verification-gap (other): the "roster is exactly the two sub-rosters" assertion in `preferences-reset.test.mjs` compares `PREFERENCE_KINDS` with its own definition (`account-preferences.ts:74` spreads exactly those two) and cannot fail — structurally unfalsifiable (Rule 19). Patched: the tautology deleted, leaving the load-bearing comparison against `Pref.cls`'s five `KIND*` parameters; the now-unused `PREFERENCE_VALUE_KINDS` import dropped with it. Test count unchanged at 1,317.
  - `[false]` `[reject]` verification-gap (other): `ui/tools/preferences-reset.test.mjs` is untracked, so a commit staging by path could miss it — the file is part of the reviewed diff and this workflow's finalize commits every reviewed-diff file and then verifies the tree is clean, so the outcome does not occur.
  - `[low]` `[reject]` verification-gap (other): `HELPER_SOURCED_FLOOR = 12` sits at today's exact value, so one spec leaving `panel-spec.mjs` reddens it — true, but it fails loudly with a self-describing message, which is the safe direction; lowering the floor would trade away the only thing that tells "the graph resolved nothing" from "there was nothing to resolve".
  - `[false]` `[reject]` verification-gap (other): `AdminPortAsync`'s Rule 19 note is stale because the probe pair now lives on `PortFixture` — the note names the `MUTATINGTYPES` **check** in `AdminPort.Sequence`, not where the pair lives, and removing that check still reddens the two log assertions, so the recipe it describes is accurate.
  - `[false]` `[reject]` intent-alignment (a): the contract's "Send's rendered width equals its intrinsic label width" is not what the diff implements — the same row cites `DESIGN.md:1122`, which the spec designates as the declared figure and which reads "three appearances at one size; its width is fixed by the widest label"; the three intrinsic widths differ (64.22/66.22/62.95), so only the declared-width reading satisfies that row and the next row together. A fix here would edit this build's spec.
  - `[false]` `[reject]` intent-alignment (a, second half): nothing bounds the token from above — the proportion legs bound it (composer wider than Send, composer over half the row) and the sufficiency legs added under the first finding bound it from below; a token drifting upward inside those bounds is theoretical.
  - `[false]` `[reject]` intent-alignment (b): the three-appearance invariant is verified transitively through the token rather than cross-state — all three legs read the token from the same deployed stylesheet in their own page, so equality to one shared resolved value is a cross-state comparison.
  - `[low]` `[reject]` intent-alignment (c): DW-1447's idempotency lives on the instance but its unit test stubs `fetch` — the instance property is verified by execution (228/228 twice back to back, recorded under `## Verification`) and the unit test pins the mechanism; encoding "run the whole suite twice" as an assertion would add a harness, which is more than a direct correction.
  - `[low]` `[reject]` intent-alignment (d): DW-1438's row states a universal over three accounts while the test is environment-relative — the suite runs as `irisowner`, which is itself on the list, and `CURRENTUSER` is evaluated first by design; all three still answer 1 with 403 and zero writes, the test measures which code each earns rather than assuming, and asserts at least one reached the new arm.
  - `[low]` `[reject]` intent-alignment (e): the role-delta refusal is pinned at the branch and the census separately, never in one path — both halves are pinned, and joining them would need an instance with a single counting holder, which is what the fixture's arming exists to stand in for.
  - `[false]` `[reject]` intent-alignment (f): DW-1473 aligned at the surface its row names, after the correction recorded under `## Matrix Test Audit` — no divergence remains.
  - `[low]` `[reject]` intent-alignment (g): DW-1452's stated counts moved (12/1 and 13 to 13/1 and 14) — the closure's own roster leg is the fourteenth method; the behavior the row specifies holds exactly, and the only fix would edit this build's spec. Reconciled under `## Matrix Test Audit`.
  - `[false]` `[reject]` intent-alignment (h): DW-1448 reaches past the chartered defect by removing `main()`'s early `continue` — that blind spot is named in the spec's Code Map and Tasks as part of this closure.
  - `[false]` `[reject]` intent-alignment (i, j): the `DESTRUCTIVE` comment appends rather than replaces, and the diff adds new public surface against "nothing new is designed" — the neighbouring sentence was not wrong, so there was nothing to replace, and every new seam (`PREFERENCE_KINDS`, `SERVICEACCOUNTS`, `IsMutating`, `AUDITINGMETHOD`, the checker's exports) is named in the spec's Tasks and its `Consumes:` list.


## Design Notes

**Governing ADs (Rule 6).**

- **AD-10** governs DW-1437 and DW-1438. Its set is defined **by effect, not by verb**, declared once
  in the kernel, and evaluated inside AD-34's transition. Both entries exist because the current
  enumeration is by verb (`$Data(pChanged("Enabled"))`) and by role name (a census that counts a
  service account as a holder). Stripping `%All` from the last holder and disabling the account the
  serving path runs as both reach ends AD-10 names, so closing them is applying AD-10's own heading
  rather than widening it. AD-10 also fixes the shape: one home, in the kernel, as predicates over
  the resolved target — never a second list in a descriptor or a policy file.
- **AD-34** — the predicates read live state, so they are evaluated inside the single atomic
  transition, which `Confirm.cls:305` already does. Nothing about the call site changes.
- **AD-39 / AD-12** — the new refusal travels in the one envelope; `Api/Error.cls` validates by
  **shape**, so a new `PROHIBITED.*` code needs no contended edit. The three rosters it does need are
  `Prohibited.Codes()`, `Prohibited.ReasonFor()` and `Test/Prohibited.cls:455`'s count.
- **AD-2 / AD-26 / AD-51 / AD-52** govern DW-1473. The port reproduces the vendor's dispatcher once;
  the admission gate is part of that sequence. AD-52 is why `ErrorDelete`'s `DELETE` is absent from
  the roster — it reaches its target through `LogSourcePort`, not `AdminPort`.
- **AD-51 and AD-52 are young.** AD-51's adequacy clause requires the precondition fields **the
  tool's own read type answers**, and **identity is not required**. Nothing here re-adds it.
- **AD-13** — `NormalizedUser()` is the identity layer's per-type rule; the new service-account
  refusal delegates to it rather than comparing raw strings.
- **AD-45 / AD-29** — `ProhibitedRoute`'s least-privileged legs are the coverage AD-29 calls for
  ("run the read as a real least-privileged principal on a throwaway"); DW-1452 is that coverage
  silently removed on a reused container.

**DW-1467 — declined, on measurement.** The entry's premise is that `AuditingUpdate.cls:57`'s
`DESTRUCTIVE 1` disagrees with two planning artifacts. It does not: the two cited rows govern a
different surface.

- `EXPERIENCE.md:426` is the **`confirm-dialog` component row**, scoped by its own *Use* column to
  "the dialogs listed in Information Architecture › Dialogs" (`:173`) — the **screen's** dialogs. Its
  "non-destructive warnings … use button-primary" is about that dialog's action button.
  `EXPERIENCE.md:538` is the same surface (its *Where* column names Task schedule, Auditing
  configuration and the Service editor).
- `epics.md:4278` says the same thing for the same surface, inside **Story 7.4**'s screen ACs.
- `epics.md:807` groups the three as *warnings*; it nowhere calls them non-destructive.
- `epics.md:3677` — **Story 5.10's own acceptance criterion**, the one that governs this parameter —
  reads: *"the write is declared **destructive**, so it draws the `destructive` bar and the
  typed-name confirmation of Story 14.7 **as well as** the warning"*, with the reason stated. The
  shipped flag satisfies it, and `EXPERIENCE.md:197` (the proposal card's own Review step) classes
  the auditing proposal neither way.

So the agent's **proposal card** is destructive and the screen's **confirm dialog** is a
button-primary warning; they are two surfaces and both statements are true. Flipping the flag would
drop a delivered AC, redden four pinning tests (`Test/AuditingUpdate.cls:414`,
`Test/ToolWrite.cls:453`, `auditing-write.browser-spec.mjs:222-223`) and make three Rule 19 mutation
recipes lie. Recommended disposition: `wontfix-theoretical` — the flag is correct at its origin. The
only residue is that a later builder meeting Story 7.4 and Story 14.7 together will re-file this, so
the distinction goes in one line at its origin, on the existing `DESTRUCTIVE` doc comment
(`AuditingUpdate.cls:55-56`), naming the screen dialog as the other surface. That one line is the
whole of DW-1467's work.

**Rule 5 amendment recommendation — the `EXPERIENCE.md` half of DW-1479.** The lead ratifies the
wording at the spec gate; the implement stage applies what is ratified and chooses nothing.
Measurement first, because it narrows what the decision is about: none of the three lines is a Fixed
string. The Fixed-strings table is `:250`/`:252`/`:254-394`; `:93`, `:220` and `:414` sit outside it,
no source file cites a phrase from any of them (so `citations.test.mjs` asserts nothing about them),
and `"This is OcuPilot's own web application."` appears once in the whole document and in no client
string. They are descriptions of behavior that are now false, not shipped copy — so the UX call is
over wording, not over what the product does.

| Line | Current (the false span) | Recommended replacement |
|---|---|---|
| `:93` | `own process refused (FR-55)` | `a process OcuPilot is itself running in is refused (FR-55)` |
| `:220` | `The current user, the user's own process, OcuPilot's own web applications, …` | `The current user, a process OcuPilot is itself running in, OcuPilot's own web applications, …` |
| `:414` | `(self-protection: current user, own process, OcuPilot's own applications, …)` | `(self-protection: current user, a process OcuPilot is itself running in, OcuPilot's own applications, …)` |

Each is an in-place edit on the existing line with no line-count change, which is what keeps
`strings.test.mjs:719`'s 546 anchors valid; `:220`'s quoted literal is untouched. The wording is
taken from the shipped sentence (`Prohibited.cls:186`, `ProcessSuspend.cls:25`) so the documents and
the model-facing text agree, and — per `citations.test.mjs:136`'s exactly-once rule — the phrase
must not already be cited from elsewhere in the document; it is not today.

**One list, two harms (DW-1206's lesson).** DW-1437's census half and DW-1438's refusal both turn on
"which accounts are service accounts nobody signs in as". They take one declared parameter, read
twice, rather than a census exclusion list and a refusal list that must be kept in step — the shape
Story 5.12 was made to adopt after `Prohibited`'s two sibling declarations were validated against
different sets. Likewise DW-1437's two paths to "the last holder loses `%All`" — a disable and a role
removal — reach **one** predicate, not two.

**`browser-reset.mjs`: the invariant, and what it still cannot see.** Re-keying on context creation
resolved through the import graph closes the three recorded misses, and its own residual failure
modes are named rather than discovered later: the leaf predicate is still a spelling
(`createBrowserContext(` / `browser.newPage(`), so a helper that reached a page some third way would
re-open the hole one layer down; the graph is scoped to `ui/browser/`, so a helper moved to
`ui/tools/` or `browser.config.mjs` leaves it; and the graph says a helper *calls* the reset, not
that the call is unconditional. The floor on resolved helper-sourced specs is what turns "the graph
went empty" from a clean report into a refusal.

**Consumes:** `ui/src/app/core/account-preferences.ts` (`PREFERENCE_KINDS`, new here),
`src/OcuPilot/Kernel/Proposal/Prohibited.cls` (`SERVICEACCOUNTS`, new here),
`src/OcuPilot/Port/AdminPort.cls` (`IsMutating`, new here).
**Consumed-by:** `PREFERENCE_KINDS` → `ui/browser/preferences-reset.mjs` and
`ui/tools/preferences-reset.test.mjs`, both in this story. `SERVICEACCOUNTS` → `Prohibited.CountsAsHolder`
and `Prohibited.User`, both in this class. `IsMutating` → `AdminPort.Invoke`, `HttpMethodFor`,
`EndpointType` and `Sequence`, all in this class, plus `Test/ProposalFixture.cls:204`. No consumer
outside this story; the three are refactoring seams, not new services.

**Forward references.** DW-1473's tightening is what stops the bare-suffix widening compounding as
Story 7.6 and Epic 9 add action types. DW-1467's declined flag is what Story 14.7's typed-name field
keys on, and Story 7.4 builds the screen dialog the two cited rows actually govern. DW-1336's fix
was expected to remove a pre-existing horizontal overflow of `.ocu-panel-composer-row`; measured, no
such overflow existed at either viewport, so Story 15.6's DW-1388 baseline is unchanged by this
story — see `## Verification` and `## Ledger Dispositions`.

## Ledger Dispositions

The implement stage records outcomes here; **the lead writes the trailer lines** (Rule 15(a) — this
workflow never writes the ledger). One row per chartered entry, plus one note the lead carries to an
entry this story does not own.

| Entry | Planned disposition | Trailer line the lead writes |
|---|---|---|
| DW-1336 | fix | `status=resolved-by:5-14-epic-5-burn-down by=adjudication note=.ocu-panel-send sized intrinsically; button-primary width:100% left alone; proportion pinned at 1280 and 900 against DESIGN.md:1122` |
| DW-1437 | fix | `status=resolved-by:5-14-epic-5-burn-down by=adjudication note=one SERVICEACCOUNTS list; census excludes them and a Roles delta removing %All from the last holder reaches LastAllHolder` |
| DW-1438 | fix | `status=resolved-by:5-14-epic-5-burn-down by=adjudication note=PROHIBITED.SERVICEACCOUNT refuses disabling CSPSystem, _Ensemble, irisowner; the account-side analogue of ServesOcuPilot` |
| DW-1447 | fix | `status=resolved-by:5-14-epic-5-burn-down by=adjudication note=reset derives from PREFERENCE_KINDS and clears all five; suggested-view's unused specifier dropped; suite idempotent over two runs` |
| DW-1448 | fix | `status=resolved-by:5-14-epic-5-burn-down by=adjudication note=re-keyed on context creation through the import graph incl. helpers; CLI blind spot at main():148 removed; all three misses pinned` |
| DW-1452 | fix | `status=resolved-by:5-14-epic-5-burn-down by=adjudication note=AUDITVARIABLE moved to OnBeforeOneTest with AssertSkipped; 12 of 13 run unarmed; the skipped method name is pinned to a real method` |
| DW-1467 | **declined, measured** | `status=wontfix-theoretical owner=burndown by=burndown note=the two cited rows govern the SCREEN confirm-dialog; epics.md:3677 (Story 5.10 AC) requires the card destructive and the tree matches it. reopen_if=epics.md:3677 is amended` |
| DW-1473 | fix | `status=resolved-by:5-14-epic-5-burn-down by=adjudication note=MUTATINGTYPES keyed by (endpoint,type) over six pairs established three ways; probe pair on PortFixture, never shipped` |
| DW-1479 | fix | `status=resolved-by:5-14-epic-5-burn-down by=adjudication note=nine locations plus spec-5-12's recipes corrected at origin; the entry's epics.md:5636 anchor was stale, the fourth hit is :5686` |
| DW-1388 (not owned here) | note only | `occurrence=5-14-epic-5-burn-down` then `note=measured: .ocu-panel-composer-row never overflowed -- scrollWidth equalled clientWidth at 1280 and 900 before the fix, the composer absorbing it at min-width:0. 5.14 changed the row's proportions, not its overflow, so 15.6's baseline is unaffected` |

**Outcome.** All nine are disposed: eight fixed with a demonstrated mutation, DW-1467 declined and
terminal on the measurement in `## Design Notes`. None is left `routed`. No ledger file is edited
(`git diff -- _bmad-output/implementation-artifacts/deferred-work.md` must be empty at
`dev_complete`).

## Verification

Slot A throughout: `server: "ocupilot-slot-a"`, dev container `ocupilot`, throwaway `ocupilot-ci`
(`--dir /tmp/ocupilot-ci --project ocupilot-ci --web 52776 --super 1975`). The profile
`ocupilot-iris` does not exist. **Never** stop, remove, recreate or `down` `ocupilot` or any
`ocupilot-slot-*` container, and never delete an application error, suspend a process or suspend a
task on the live `ocupilot`.

**Targeted, inside the implement loop (loop):**

- `uv run scripts/check-objectscript.py <changed paths>` — expected: 21 rules pass.
- Load and compile the changed classes through the IRIS MCP tools with `server: "ocupilot-slot-a"`,
  reading the error text rather than assuming a clean compile.
- `cd ui && npm run test:tools` — expected green, and **this is the covering checker for the
  document edits**, not `lint-docs`: `strings.test.mjs` (546 `EXPERIENCE.md:n` anchors over lines
  254-394), `citations.test.mjs` (quoted phrases, exactly once each), plus `browser-reset.test.mjs`,
  the new `preferences-reset.test.mjs` and `ci.test.mjs`. Inserting a row into `EXPERIENCE.md`
  earlier in this epic shifted every later anchor and reddened all three CI `gates` legs while
  `lint-docs` read clean.
- `cd ui && npm run test:components` — expected green, including `panel.spec.ts` (the footer child
  order at `:338-348`) and `proposal-card.spec.ts`.
- `bash scripts/lint-docs.sh` — expected clean; `check-prose.py` rule 1 requires `epics.md:3506` to
  stay a `- **Given**` list item.
- Throwaway discipline before any result on it means anything: `ocupilot-ci` is reused and no
  session here brought it up — **do not tear it down**. Five classes refuse unarmed
  (`AuditingUpdate`, `ErrorDelete`, `ProcessControl`, `ProhibitedRoute`, `TaskResume`); where the
  container predates a variable, run the class through
  `docker exec -e OCUPILOT_ALLOW_AUDIT_TOGGLE=1 -e OCUPILOT_ALLOW_PROCESS_CONTROL=1 -e OCUPILOT_ALLOW_TASK_CONTROL=1 -e OCUPILOT_ALLOW_ERROR_DELETE=1 …`
  rather than recreating it, and report the gap to the lead. Then sync the source to
  `/tmp/ocupilot-ci/src`, compile it there, and run `OcuPilot.Install.Installer.Install` —
  `ci-runner.mjs` does **not** load source, so a green under an unloaded mutation attributes
  nothing, and that is the worse direction. Then
  `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`
  and **re-run the installer** — a browser spec asserts the shipped bundle matches the stamp the
  *installer* recorded.
- `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class <Class>` — **one class per tool
  call, waiting for each to land in `%UnitTest_Result` before the next; never two test calls in one
  message**, for `OcuPilot.Test.UserUpdate`, `OcuPilot.Test.Prohibited`,
  `OcuPilot.Test.ProhibitedByEffect`, `OcuPilot.Test.ProhibitedRoute`, `OcuPilot.Test.ToolWrite`,
  `OcuPilot.Test.AdminPortSync`, `OcuPilot.Test.AdminPortAsync`, `OcuPilot.Test.AdminPortFault`,
  `OcuPilot.Test.ProposalConfirm`, `OcuPilot.Test.TaskResume`, `OcuPilot.Test.ProcessControl`,
  `OcuPilot.Test.ErrorDelete`, `OcuPilot.Test.AuditingUpdate`, `OcuPilot.Test.SurfaceCoverage`.
  Totals verified with the `%UnitTest_Result` SQL probe rather than the runner envelope, and **zero
  executed methods is a failure, never a pass**. For `ProhibitedRoute` under the new split,
  `Total ≠ Passed + Failed`: a skip records `Status=2`, which the probe's pass/fail arithmetic does
  not count.
- `cd ui && OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci node --test --test-concurrency=1 browser/panel.browser-spec.mjs browser/suggested-view.browser-spec.mjs browser/auditing-write.browser-spec.mjs`
  — the story's own browser specs. The bundle must be rebuilt and redeployed first; a spec run
  against the old bundle proves nothing about a style edit.
- **Rule 19** — one demonstrated mutation per AC, applied on `ocupilot-ci` with the whole `OcuPilot`
  package recompiled in the container (or the bundle rebuilt and redeployed, for a client
  mutation), the named class or spec run, then **reverted in both the worktree and the container**,
  with `git status --short` and `git diff --stat` confirmed unchanged after each. Recorded here as
  `mutation: <change> -> <which test went red>` by whoever writes or changes the pinning test. The
  mutations this story owes, one per AC: delete the new `.ocu-panel-send` base rule; revert the
  `:480` guard to `$Data(pChanged("Enabled"))` alone; empty `Prohibited.SERVICEACCOUNTS`; delete the
  new `User()` refusal arm; answer permitted from `CountsAsHolder` for a service account; delete the
  reset call from `panel-spec.mjs:68`; restore `VALUE_KINDS` to the three value kinds; restore
  `main()`'s `:148` `continue`; point `ProhibitedRoute`'s auditing-method parameter at a name the
  class does not declare; remove `Security.User/PUT` from `MUTATINGTYPES`; restore
  `MUTATINGTYPES` to bare suffixes and re-run `ToolWrite`'s pair-shape leg.

**DW-1336, measured before fixed.** Signed in through the shipped form on
`/ocupilot/permissions/users?ns=HSCUSTOM` against `ocupilot-ci`, panel at its default dock, empty
draft, Send idle (`ocu-button-primary`):

| Viewport | Panel | `.ocu-panel-composer-row` | `.ocu-panel-composer` | `.ocu-panel-send` | row `scrollWidth`/`clientWidth` |
|---|---|---|---|---|---|
| 1,280px | 400px | 375px | **26.89px** | **340.11px** | 375 / 375 |
| 900px | 320px | 295px | **26.88px** | **260.13px** | 295 / 295 |

Send's computed `width` read `340.109px` with `flex: 0 1 auto` -- `.ocu-button-primary:231`'s
`width: 100%` resolved as its flex base, so the row's whole width was Send's base size and the
composer shrank to `min-width: 0`. The composer's 26.89px is under its own 24px padding plus 2px
border: roughly 0.9px of text.

Against DESIGN.md `:1122` ("three appearances at one size; its width is fixed by the widest label
so the composer never reflows"), the same element's own content width measured 64.22px as
`button-primary`, 66.22px as `button-secondary` and 62.95px as `button-secondary` reading *Stop* --
so the declared width is the widest of those, and `--ocu-panel-send-width` is 72px, that figure on
the 4px scale.

**The spec's `(inference)` is half true, and the false half matters to DW-1388.** A too-wide Send
does narrow the composer, so one rule closes both of DW-1336's symptoms. It does **not** overflow
`.ocu-panel-composer-row`: measured, `scrollWidth` equalled `clientWidth` at both viewports before
the fix, because `min-width: 0` let the composer absorb all of it. There was no pre-existing
horizontal overflow for this story to remove, so 15.6 takes DW-1388's baseline against a tree whose
overflow behavior 5.14 did not change -- see `## Ledger Dispositions`.

- `mutation:` delete the base `.ocu-panel-send` rule from `_components.scss`, rebuild and redeploy
  -> `panel.browser-spec.mjs` "DW-1336: Send keeps its declared width..." red at 1,280
  (`340.109375 against 72`), `proposal-card.browser-spec.mjs` (a) red (`66.21875`, the live-card
  secondary) and (b) red (`62.953125`, *Stop* while the turn runs); (c) stayed green. The three
  disagreeing numbers under one mutation are the leg's discrimination: only the filled appearance
  carries `width: 100%`, so the composer reflowed whenever the label changed.
- `mutation:` restore `VALUE_KINDS = ['view','refresh','shell']` in `preferences-reset.mjs` ->
  `preferences-reset.test.mjs` red on "the reset clears every kind the roster holds" and on "the
  membership kinds are in the cleared set"; the roster leg stayed green, which is what says the two
  sides are measured independently.
- `mutation:` drop `SHELL_KIND` from `PREFERENCE_VALUE_KINDS` -> `preferences-reset.test.mjs` red on
  "the roster is the five kinds Pref.cls declares" alone.
- `mutation:` delete `await resetRememberedState();` from `panel-spec.mjs`'s `signedInAt` ->
  `node tools/browser-reset.mjs` exits 1 with **13** refusals -- the 12 helper-sourced specs and
  `panel-spec.mjs` itself -- and `browser-reset.test.mjs` red on "the real browser directory passes
  its own check" and "the shipped tree resolves its helper-sourced specs". Under the spelling-keyed
  checker the same mutation refused none.
- `mutation:` restore `inspect()`'s `if (!source.includes(CONTEXT_CALL)) continue;` ->
  `browser-reset.test.mjs` red on "the CLI refuses a spec written only with browser.newPage(", "the
  CLI refuses a helper-sourced spec whose helper does not reset" and "the shipped tree resolves its
  helper-sourced specs". Both arms were unreachable from the gate `prebuild` runs.

**ObjectScript, on `ocupilot-ci`.** Every mutation below was applied in the worktree, synced to
`/tmp/ocupilot-ci/src`, compiled with `$System.OBJ.LoadDir("/opt/ocupilot/src/OcuPilot","cku",,1)`
over the **whole** package, run, then reverted and recompiled the same way; `git diff` against the
pre-mutation copy was empty after each.

- `mutation:` empty `Prohibited.SERVICEACCOUNTS` -> `UserUpdate` red on
  `TestDisablingAServiceAccountIsRefused` and `TestTheCensusDoesNotCountAServiceAccountAsAHolder`,
  each on its own emptiness floor.
- `mutation:` delete the `IsServiceAccount` arm from `Prohibited.User` -> `UserUpdate` red on
  `TestDisablingAServiceAccountIsRefused` alone, and on "the row stays live" as well as the code --
  without the arm the confirm **wrote**. The census leg stayed green, which is what says the
  parameter's two readers are pinned separately.
- `mutation:` answer permitted from `Prohibited.CountsAsHolder` for a service account (drop its
  `IsServiceAccount` arm) -> `UserUpdate` red on the census leg alone, naming all three accounts.
- `mutation:` revert `Prohibited.User`'s guard to the disable verb alone, so a `Roles` delta never
  reaches the census -> `UserUpdate` red on `TestARoleDeltaRemovingAllFromTheLastHolderIsRefused`,
  with the two permitted legs in that method still green.
- `mutation:` remove `Security.User/PUT` from `AdminPort.MUTATINGTYPES` -> `ToolWrite` red on the
  roster leg naming `permissions.users.update`, and `UserUpdate` red on the confirmed write with
  `PORT.NOTIMPLEMENTED`. That is the high-risk arm measured: the 501 lands after the claim.
- `mutation:` restore `AdminPort.MUTATINGTYPES` to the bare `PUT,RESUME,SUSPEND` -> `ToolWrite` red
  on the pair-shape leg for all three suffixes, on `IsMutating`, and on the `Task.CRUD/SUSPEND`
  discrimination.
- `mutation:` point `ProhibitedRoute.AUDITINGMETHOD` at a name the class does not declare ->
  `ProhibitedRoute` red on `TestTheAuditingMethodParameterNamesAMethodThisClassDeclares` alone, and
  the auditing method then **ran unarmed and passed** -- which is the harm the leg guards, observed
  rather than argued.
- `mutation:` add `Task.CRUD/SUSPEND` to `AdminPort.MUTATINGTYPES`, whole package recompiled
  (container read back the mutated parameter before the run) -> `ToolWrite` red, 1 of 20, on
  `TestEveryWriteToolsRequestTypeAgreesWithThePortsBodylessRoster`; reverted, recompiled, 20 of 20
  green and `git diff --stat` unchanged at 69 lines for `AdminPort.cls`. This is the matrix's
  `Task.CRUD/SUSPEND` row pinned **through `AdminPort.Invoke`** -- 501 with `tFault.code` reading
  `PORT.NOTIMPLEMENTED` -- and not only through `IsMutating`, which is the predicate the refusal
  uses rather than the refusal a caller meets.

**DW-1452, counted on the reused throwaway** (`ocupilot-ci` carries `OCUPILOT_ALLOW_PRINCIPALS=1`
and no `OCUPILOT_ALLOW_AUDIT_TOGGLE`, which is the unarmed case verbatim). Read from
`%UnitTest_Result`, not the runner envelope:

| Run | Environment | `Status=1` | `Status=2` | `Status=0` |
|---|---|---|---|---|
| 5849 | `OCUPILOT_ALLOW_PRINCIPALS=1` only | 13 | 1 (`TestALeastPrivilegedPrincipalConfirmsTheAuditingWriteOverTheWire`) | 0 |
| 5850 | both variables | 14 | 0 | 0 |

Before this story the whole class refused, so 0 executed. The counts are one higher than the
`<intent-contract>`'s 12/1 and 13, because the same spec's task list adds
`TestTheAuditingMethodParameterNamesAMethodThisClassDeclares`: the class now holds 14 test methods.

**DW-1479, and `spec-5-12`'s recipes.** `grep -n "own process"` over `epics.md`, `prd.md`,
`SPEC.md` and `EXPERIENCE.md` returns nothing after the edits; `EXPERIENCE.md` is 801 lines before
and after, so `strings.test.mjs`'s 546 anchors over 254-394 are untouched. `spec-5-12`'s two
recipes were **re-measured** rather than re-worded: `Quit 0` first in `Prohibited.IsOcuPilotProcess`
-> `ProcessControl` 2/11 failed; deleting the `IsOcuPilotProcess` branch from `Prohibited.Process`
-> 1/11; deleting the `IsActionableJobType` branch -> 1/11. `ProcessControl` holds 11 test methods,
not the 10 the task line states.

**Full runs, once, before `dev_complete` (once, before dev_complete):**

- `cd ui && npm run build && npm test` — expected: the seven prebuild checkers pass (including the
  re-keyed `browser-reset.mjs`) and both client tiers are green. `npm test` does **not** run the
  browser suite.
- `cd ui && npm run test:browser` — the whole suite against the redeployed bundle, **run twice back
  to back on the same throwaway without clearing `OcuPilot_Kernel_State.Pref` between runs**: both
  green is DW-1447's acceptance. Capture each run in full; piping through `tail` reports `tail`'s
  exit code.
- The full ObjectScript sweep through `ci-runner.mjs` against `ocupilot-ci`, one class at a time,
  reconciled against `%UnitTest_Result`.
- `bash scripts/smoke.sh --container ocupilot-ci --user _SYSTEM --password SYS` — expected: zero
  checks `pending`, `fail = 0`, a non-zero executed count, and `agentwrite` and `auditmarker` both
  pass. Read the skip lines, not the number (DW-1402).
- `bash scripts/lint-docs.sh` — expected clean.

**Full runs, as executed (2026-09-22, `ocupilot-ci`).**

- `uv run scripts/check-objectscript.py` — 612 files, 21 rules, 0 problems;
  `uv run scripts/test_check_objectscript.py` — 128 tests, OK.
- `cd ui && npm run test:tools` — 1,317 tests, 0 failed, including `strings.test.mjs`,
  `citations.test.mjs`, `ci.test.mjs`, the re-keyed `browser-reset.test.mjs` (23) and the new
  `preferences-reset.test.mjs` (3).
- `cd ui && npm run build && npm test` — the seven prebuild checkers pass (`browser-reset` reports
  57 files, 51 reaching a context, 12 through an imported helper, clean) and both client tiers are
  green: 1,317 tool tests and 822 component tests over 54 files.
- `bash scripts/lint-docs.sh` — 0 markdownlint issues over 114 files, `check-prose` 0 problems.
- **The browser suite, twice back to back on the same throwaway**, without clearing
  `OcuPilot_Kernel_State.Pref` between runs: **228 tests, 228 pass, 0 fail, both runs.** Nothing
  accumulated between them, which is DW-1447's acceptance. The deployed bundle is the one the
  installer stamped: the served directory is cleared before `docker cp`, because
  `Installer.BundleIdentity` takes the lexicographically greatest `main-*.js` and a copy-over-the-top
  leaves an older one to be stamped.
- **The two `tasks.browser-spec.mjs` failures an earlier pass saw were instance residue, measured
  and cleared, not a defect in this diff.** `%SYS_Task.History` on the reused `ocupilot-ci` held
  **42** `OcuPilotDemoProbe*` rows against 3 for `OcuPilotDemo nightly purge`, and **0** probe tasks
  — so the rows were orphans of earlier runs, and the demo row fell outside the table's rendered
  page. The residue is self-reinforcing: the tasks suite purges its own probe history only on the
  path a passing run takes, so one failure leaves more rows and the next run fails again. Deleting
  the 42 orphans took the spec from 12/14 to **14/14 against the same tree and the same bundle**,
  which is what attributes the failure to the container rather than to the story; the suite then
  ran clean twice and left `0` probe rows behind. The standing non-idempotency is under *Deferred
  findings*.
- **The ObjectScript sweep**, one class per call through `ci-runner.mjs`: **175 classes, 1,596
  tests, 0 failed, 0 probe leftovers, 0 overlaps, 0 foreign runs.** The four classes that refuse
  unarmed on this container ran separately through `docker exec` with the four
  `OCUPILOT_ALLOW_*` variables: `AuditingUpdate`, `TaskResume`, `ProcessControl`, `ErrorDelete` —
  all `All PASSED`. Together that is all **178** classes the project's own discovery query offers
  (`scripts/ci-unit-test.sh`), which requires a `Test*` method; `OcuPilot.Test.Http` declares none
  and is a shared HTTP base, so the sweep's one reported problem is an artifact of a wider
  hand-built class list and not a class that ran empty.
- `bash scripts/smoke.sh --container ocupilot-ci --user _SYSTEM --password SYS` —
  `executed=46 passed=46 failed=0 pending=0 skipped=1`, `PASSED`. `agentwrite` and `auditmarker`
  both pass. The one skip is `agentswitches`, which names its own reason: the switches have been
  written on this reused instance, so whether the install wrote none cannot be told here.

**Matrix Test Audit — the two rows whose covering evidence needed its own measurement.**

- `Task.CRUD/SUSPEND` **through the port**: the row's expected behavior is `Invoke` answering 501
  `PORT.NOTIMPLEMENTED` before the endpoint is constructed, and the covering assertion asked
  `IsMutating` instead — the predicate the refusal consults, not the refusal. `ToolWrite` now drives
  `AdminPort.Invoke("Task.CRUD", "SUSPEND", …)` against a task id no task carries and asserts 501
  and the fault code, beside the `Process/TERMINATE` and `Process/DELETE` legs that already did.
  20 of 20 green, run 6047.
- `ProhibitedRoute` **on an unarmed throwaway**: read from `%UnitTest_Result`, not the runner
  envelope. Unarmed (run 6048): 14 methods, **13 `Status=1`, 1 `Status=2`**, 0 failed, the skip being
  `TestALeastPrivilegedPrincipalConfirmsTheAuditingWriteOverTheWire`. Armed (run 6049): **14
  `Status=1`**, 0 skipped. The row reads 12 executed and 13 armed; both are one lower because the
  same task list adds `TestTheAuditingMethodParameterNamesAMethodThisClassDeclares`. The row's
  behavior — that one method is skipped, every other executes and passes, and zero execute is never
  a pass — holds exactly. Before this story the class refused whole and executed none.

**Re-verified after the added leg**, one class per call on `ocupilot-ci`, each landing in
`%UnitTest_Result` before the next: `ToolWrite` 20, `ProhibitedRoute` 14 (13+1 skip), `UserUpdate`
18, `SurfaceCoverage` 4, `AdminPortAsync` 3, `AdminPortFault` 24, `Prohibited` 11,
`ProhibitedByEffect` 6, `AdminPortSync` 7, `ProposalConfirm` 20 — 0 failed. Armed through
`docker exec`: `ProhibitedRoute` 14, `AuditingUpdate` 6, `ProcessControl` 11 — all `All PASSED`,
which is also where `ProcessControl`'s 11-method count is read rather than recalled.

**Restored, and read back.** `OcuPilotDemo nightly purge` is still suspended on `ocupilot-ci`
(`%SYS.Task:TaskList`, 19 tasks, the only `OcuPilot` one, `Suspend Leave`). No process is suspended
on either container (`%SYS.ProcessQuery:CONTROLPANEL`: `ocupilot-ci` 56 processes, 0 suspended;
`ocupilot` 32 processes, 0 suspended). No probe principal and no probe task survive on the
throwaway. The live `ocupilot` still holds its 6 dates and 211 errors in `HSCUSTOM`
(`SYS.ApplicationError:DateList`: 09-10 22, 09-11 123, 09-12 10, 09-13 26, 09-14 25, 09-15 5). The
throwaway was reused and was not torn down.

**Deferred findings, for the lead's ledger (Rule 15 — not written here).**

- `ui/browser/tasks.browser-spec.mjs` purges its `OcuPilotDemoProbe*` history only on the path a
  passing run takes, so a run that fails for any reason leaves its probe rows in
  `%SYS_Task.History`, and enough of them push `OcuPilotDemo nightly purge` outside the rendered
  page and fail "Story 6.6 AC1" and "AC3" — which leaves more rows again. Measured on `ocupilot-ci`:
  42 orphan rows against 3 demo rows with 0 probe tasks alive; deleting the orphans took the spec
  from 12/14 to 14/14 unchanged otherwise. A fresh throwaway (what CI uses) never sees it, so this
  is reused-container hygiene, not a product defect. Fix at either end: purge in a teardown that
  runs on the failure path too, or bound the spec's search to the exact task name.
- `spec-5-12`'s other eight Rule 19 recipes still carry `1/9` and `1/10` denominators from the
  class sizes when each was measured; `ProcessControl` now holds 11. Only the two this story names
  were re-measured.

## Auto Run Result

Status: done
Blocking condition: none

**What this pass changed.** Eight independent closures, each citing its `DW-n`, each with a pinning
test and a demonstrated Rule 19 mutation. DW-1479 corrected nine document locations plus
`spec-5-12`'s three Rule 19 recipes, whose counts were re-measured rather than re-worded. DW-1447
exported `PREFERENCE_KINDS` and derived the browser reset from it. DW-1448 re-keyed
`browser-reset.mjs` on context creation resolved through the local import graph and removed
`main()`'s blind `continue`. DW-1336 added a base `.ocu-panel-send` rule and the
`--ocu-panel-send-width` token, leaving `.ocu-button-primary` untouched. DW-1437 and DW-1438 added
one `SERVICEACCOUNTS` parameter read twice and one `DePrivilegesLastAllHolder` predicate serving
both the disable and the role-removal path. DW-1473 re-keyed `AdminPort.MUTATINGTYPES` by
`(endpoint, type)` and converted all four reads, with the probe pair on `PortFixture` alone.
DW-1452 moved the auditing refusal to `OnBeforeOneTest` with `$$$AssertSkipped`. DW-1467 is one
addition to `AuditingUpdate`'s `DESTRUCTIVE` doc comment and nothing else.

**Files changed** (27 modified, 1 new). Kernel and port: `Prohibited.cls` (the service-account
list, its two readers, the one de-privileging predicate, code 13), `AdminPort.cls` (pair-keyed
`MUTATINGTYPES`, `IsMutating`, four converted reads), `AuditingUpdate.cls` and `ProcessList.cls`
(doc comments). Tests: `UserUpdate`, `Prohibited`, `ProhibitedRoute`, `ToolWrite`, `PortFixture`,
`ProposalFixture`, `AdminPortFault`, `Test/AuditingUpdate`. Client: `_components.scss`,
`_metrics.scss`, `account-preferences.ts`, `preferences-reset.mjs`, `browser-reset.mjs`,
`browser-reset.test.mjs`, `panel.browser-spec.mjs`, `proposal-card.browser-spec.mjs`,
`suggested-view.browser-spec.mjs`, and the new `ui/tools/preferences-reset.test.mjs`. Documents:
`epics.md`, `prd.md`, `SPEC.md`, `EXPERIENCE.md`, `spec-5-12`, this spec.

**Review findings.** 17 findings over two layers — 3 medium, 6 low, 8 false. **Four patched**: the
Send token's label-sufficiency now asserted for the outlined and *Stop* appearances, not only the
idle one; `ProhibitedRoute`'s audit-toggling body now asserts its own arming variable, so losing
the skip reddens instead of disabling auditing quietly; `ToolWrite` now holds `PortFixture`'s
roster against the shipped one in the growth direction; and one structurally unfalsifiable
assertion deleted from `preferences-reset.test.mjs`. Each patch carries its own demonstrated
mutation in `## Review Triage Log`. **Two deferred** (frontmatter `deferred:`): the tasks spec's
self-reinforcing probe-history residue, and `spec-5-12`'s eight un-re-measured recipe denominators.
**Eleven rejected** — seven as `false` and four as `low` not worth their fix; each row in the
triage log carries its refutation or its reason.

**Three contract figures moved, each measured, each recorded rather than quietly adopted.**
`.ocu-panel-composer-row` never overflowed, so the DW-1388 note is a correction rather than the
expected confirmation and Story 15.6's baseline is unaffected. `ProhibitedRoute` runs 13+1 unarmed
and 14 armed, not 12+1 and 13, because this story's own task list adds the roster leg.
`ProcessControl` holds 11 test methods, not 10.

**Verification.** `check-objectscript` 612 files / 21 rules / 0 problems; `lint-docs` clean over 114
files. `npm run test:tools` 1,317 pass / 0 fail; `npm run test:components` 822 pass over 54 files;
`npm run build` with all seven prebuild checkers clean. **The full browser suite ran green three
times — 228/228 each — twice back to back on the same reused throwaway with nothing cleared between
them, which is DW-1447's acceptance, and once more after the review patches.** ObjectScript: the
full sweep (175 classes, 1,596 tests, 0 failed) plus the four unarmed-refusing classes through
`docker exec`; after the review patches the affected classes were re-run singly and green —
`ToolWrite` 20 (run 6065), `ProhibitedRoute` 14 unarmed as 13+1 skip (run 6063) and 14 armed (run
6049), with per-status counts read from `%UnitTest_Result` rather than the runner envelope. Smoke
on `ocupilot-ci`: `executed=46 passed=46 failed=0 pending=0 skipped=1`, `agentwrite` and
`auditmarker` both pass, the one skip naming its own reason.

**Restored, and read back.** `OcuPilotDemo nightly purge` still `Suspended=1` on `ocupilot-ci`;
auditing back on there; 0 probe history rows, 0 probe principals, 0 suspended processes on the
throwaway; 0 suspended processes on the live `ocupilot`, which still holds its 6 dates and 211
errors (67823-67828: 22+123+10+26+25+5). The throwaway was reused and was not torn down; no
`ocupilot` or `ocupilot-slot-*` container was stopped, removed, recreated or `down`ed.

**Follow-up review recommended: true.** Three medium entries were patched, which meets the
threshold. The specific unverified risk: the two ObjectScript patches — `ToolWrite`'s fixture-roster
assertion and `ProhibitedRoute`'s arming guard — were each demonstrated by mutation and re-run as
single classes, but the whole-package sweep ran before them and was not repeated afterwards. Both
are leaf test classes that nothing inherits from, so the exposure is narrow rather than unknown.

**Residual risks.** The re-keyed `browser-reset.mjs` still recognises a context by spelling at the
leaf, is scoped to `ui/browser/`, and reads a *call* to the reset rather than an unconditional one;
all three are named at the checker and the helper-sourced floor turns an empty graph into a red
test. `--ocu-panel-send-width` carries about 6px over the widest measured label, now asserted for
all three appearances.
