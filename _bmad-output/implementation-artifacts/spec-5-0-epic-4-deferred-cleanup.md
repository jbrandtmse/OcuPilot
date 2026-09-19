---
title: 'Epic 4 deferred cleanup'
type: 'bugfix'
created: '2026-09-18'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-5-context.md'
warnings: ['oversized', 'multiple-goals']
deferred: []
---

<intent-contract>

## Intent

**Problem:** Epic 4 shipped the dispatch, ledger and panel code every Epic 5 story extends with
twelve unclosed ledger entries against it: branches with no executing assertion, rules and helpers
that exist in two to four copies, two string-shaped ledger invariants that accept values they
cannot round-trip, and one agent-instruction file naming a build path that does not exist.

**Approach:** Close each entry with the smallest mechanical change that makes the invariant
observable — a pinning test with a named mutation where the gap is a missing assertion, one copy
where there are several — and decline, with the reason stated once, the three whose honest fix is a
product decision or a redesign of a shared base class.

## Boundaries & Constraints

**Always:** Every branch this story pins gets a pinning test plus a recorded `mutation:` line
(Rule 19). Each of the twelve entries is either cited by a Task or an I/O row, or declined by name
under `## Design Notes`. Redaction stays schema-driven with the name pattern as an add-only
backstop (Conventions › Secrets): a change may only alter *which keys are reported as* redacted,
never whether a value is redacted. One `%UnitTest` class per runner call, waiting for it to land
before the next (`.claude/rules/objectscript-testing.md`). A browser result counts only after
`npm run build` and `docker cp dist/ocupilot-ui/browser/.` — the real output path, which is what
DW-1168 corrects.

**Never:** Do not edit `src/OcuPilot/Api/Error.cls` or `src/OcuPilot/Screen/Tool/Registry.cls` —
both are Epic 10's contended paths, so **no new error slug or code is available to this story** and
every refusal must reuse a landed signal. Do not edit
`src/OcuPilot/Kernel/{Provider/**,AgentRules.cls,Egress.cls,State/Agent.cls}`,
`src/OcuPilot/Port/ProviderPort.cls`, `src/OcuPilot/Api/Definitions.cls`,
`src/OcuPilot/Test/{OpenAI,Gemini,Compatible,Adapter,CatalogProbe,AgentRules,Provider,Egress}*.cls`,
`ui/src/app/areas/agent/definition-form.*`, `ui/src/app/shell/panel/context-chip*`,
`ui/browser/definitions.browser-spec.mjs`, `ui/tools/strings.test.mjs` or `README.md`; reaching one
is a HALT, not an edit. Do not add a multi-column guarded-read primitive to
`src/OcuPilot/Kernel/State/Base.cls` (see the DW-1128 decline). Do not consolidate the four
privilege-reason **reveal** rules — `ui/tools/design-tokens.test.mjs` pins their exact two-line
selector spelling. Do not add a key to `ui/src/app/core/strings.ts`: every sentence this story
touches already exists there. Do not edit another epic's spec files or write any ledger trailer
line (Rule 15(a)).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| DW-1097 registry read fails | `ToolDispatchProbe.SetRegistryClass("OcuPilot.Test.BadFulfilment.Registry")`, then `ResolveClientCall` for any wire name | The call is a refusal, not a turn failure: `tSC` is `$$$OK`, the step is an error result, and `ToolDispatchProbe.Logged()` carries the registry fault with `TOOL.UNAVAILABLE` | No status escapes; the turn continues |
| DW-1097 gate read fails | `ToolDispatchProbe.FailGate()`, then `ResolveClientCall` | Same shape — refusal normalised to `$$$OK`, fault logged | As above |
| DW-1097 `Directive` errors with no fault code | A fixture client tool whose `Directive` returns an error status and leaves `pFault` empty | Same shape — the `Else` leg logs and normalises; no announcement survives | As above |
| DW-1123 provider call fails | `TurnProvider.Script` armed with an HTTP 500 | The turn's `llm` ledger row reads `status = "error"` and carries the fault's `code` | Row is written; the turn reports the provider fault |
| DW-1123 client-call step cap | A narrow-`MAXSTEPS` limits fixture so the announce row cannot be stored | A client row is recorded with `status = "ok"`, `code = NAV.UNAVAILABLE`, and the turn is unharmed | Drop is counted, never raised |
| DW-1123 boundary stop inside the wait | A call-counting `Boundary` probe that allows the pre-dispatch check and stops during the wait | A client row reads `status = "stopped"` with the boundary's code | Announcement withdrawn |
| DW-1123 client-call settles | A narrow-`NAVWAITSECONDS` limits fixture so the wait lapses on its first pass | A client row is recorded at settle with `status = "ok"` and the announce outcome | Lapse is an ordinary tool result |
| DW-1123 view truncates | `LedgerLimits.LEDGERVIEWMAXROWS = 3` with four rows recorded | The view answers `truncated` **true** and `rowsSent` equal to the cap | No error |
| DW-1123 unparseable requirement | `RequiredPairs` set to `notapair` by direct SQL, then a cross-user read through `LedgerGateProbe` | The row is withheld and counted, never rendered | Withhold, not a fault |
| DW-1123 unreadable store over the route | `Api.Ledger` subclass whose `LedgerClass()` is `Test.LedgerFaultProbe`, driven in process with `%request`/`%response` stubs | `RenderFault` answers **HTTP 503** with the existing `LEDGER.UNAVAILABLE` code | One envelope, no new slug |
| DW-1126 separator in a pair | `PairsToString` given a pair whose resource or permission contains `,` or `:` | That pair is omitted **and** `pTruncated` is set, so the recorded set is marked incomplete and the row is withheld on a cross-user read | Refusal by the landed truncation signal |
| DW-1126 caller sends the marker | A declared-secret argument whose value the caller supplied as the literal `[redacted]` | The key is still redacted; it is **not** reported as evidence of redaction, the survival scan does not trip, and the whole argument string is **not** discarded | No `LogFailure`; nothing is logged as a redaction failure |
| DW-1173 AdminPort inside an open capture | A test capture opened **and given output**, then `AdminPort` invoked | The port's own `BeginCaptureOutput` is refused, the call becomes an internal fault, and **no vendor endpoint runs** | Refusal, not a silent pass |
| DW-1173 cross-port nesting | `MgmntImplFixture` armed with a mode that calls `AdminPort.Invoke` from inside `MgmntPort`'s capture window | The inner capture is refused once the outer holds output; the outer's collected lines survive | Inner call faults; the outer envelope is intact |
| DW-1162 the panel's empty sentence | `panel-principal.browser-spec.mjs`'s real non-administrator principal, no enabled definition | `.ocu-panel-empty`'s **computed** style is asserted — the body type ramp, `margin: 0`, and the on-surface-variant color — not only its presence | Spec fails if the rule block is deleted |

</intent-contract>

## Code Map

Server — the branches to pin (all `src/OcuPilot/`):

- `Kernel/Agent/Dispatch.cls` — `ResolveClientCall` `:403-546`; the three normalised branches are
  `:436-441` (registry, `$$$OK` at `:439`), `:457-463` (gate, `:461`) and the `Else` at `:525-528`
  (`Directive` errored with no fault code, `:527`). All three are **error-status** returns, not
  throws, so the observable is `LogFault` output — no throwing seam is needed. `StepArguments`
  `:612-615` and its doc `:609-611`; the unknown-tool exits at `:207-211` and `:442-446`
  (read-only, DW-1133 declined).
- `Kernel/Agent/Loop.cls` — `RecordProviderRow` `:745`, the `error` leg `:752`, call site `:211`.
  `AnswerClientCall` `:558-713`: step-cap drop writer `:612`, boundary stop during the wait `:641`,
  settle `:702`, pre-announce refusal `:585` (already covered). The boundary-stop refusal writer is
  `:436` inside `:422-437`.
- `Kernel/Audit/Ledger.cls` — `RedactedKeys` `:201-214` (marker equality at `:208`, one caller at
  `:176`); `PairsToString` `:228-259` (`:` at `:240`, `,` at `:247`, the `PAIRSMAXLENGTH` cut
  `:242-252`); `StringToPairs` `:264-280`; the unparseable withhold `:379-384`; `ViewForUser`
  `:302-408` with the per-row loop `:337-349` and the view `truncated` at `:330`/`:396`;
  `RedactArguments` `:154-197` — the soundness check `:178-180`, the value-survival scan
  `:181-183`, the discard-and-log at `:184-187`; the withhold-whole case `:121-124`.
- `Kernel/Audit/Log.cls` — `Parameter REDACTED = "[redacted]"` `:42` (the marker's one home);
  `Redact` `:125-126`; `IsCredentialName` `:172-198` (anchored, deliberately not a substring match).
- `Kernel/State/Ledger.cls` — `RequiredPairs` MAXLEN 512 `:100`, `PAIRSMAXLENGTH` `:113`,
  `argumentsTruncated` write `:166`; `GuardedAppend` `:139` with the `COUNT(*)` cap check `:145-153`
  and `Seq = tStoredCount + 1` `:159` under `LedgerTurnSeqIdx` `:126` (read-only, DW-1128 declined).
- `Api/Ledger.cls` — `LedgerClass()` seam `:43-46` ("Overridable for a fixture"); `Handle` `:90`;
  `RenderFault` `:104` with the 503 leg `:111-113`. `Api/Router.cls:158` hard-codes
  `##class(OcuPilot.Api.Ledger).Handle()`, so the 503 is reachable **in process only**, not over the
  wire — the precedent for in-process handler tests with `%CSP.Request`/`%CSP.Response` stubs is
  `Test/Dispatch.cls`, `Test/AdminPortSync.cls`, `Test/MgmntPort.cls`.
- `Api/Error.cls` — read-only (contended). The whole ledger vocabulary is four slugs:
  `LEDGERWINDOWINVALID` `:849`, `LEDGERMAXROWSINVALID` `:854`, `LEDGERUSERINVALID` `:860`,
  `LEDGERUNAVAILABLE` `:865`; `LedgerCodes()` `:884`, `ReasonForLedger()` `:891`, and
  `Test/Ledger.cls:127` asserts the vocabulary is complete — which is why no new slug is available.
- `Port/AdminPort.cls` — `Sequence` `:807-876`; `BeginCaptureOutput` `:855`, `EndCaptureOutput`
  `:864`, `Parameter CAPTURECLASS` `:95`; the only thing inside the window is
  `pEndpoint.Run(.tSC, pBody)` `:857` (AD-2 step 6).
- `Port/MgmntPort.cls` — read-only for edits; `Call` `:486-529`, `$$BeginCapture^%SYS.Capture`
  `:498`, `$$EndCapture` `:514`, `tCapturing` guard `:499-511`, and the `ImplClass()` seam `:119`
  that `Test/MgmntPortFixture.cls:32` already overrides. This seam is the only project-controlled
  way into either capture window.

Reference (read-only) — the vendor semantics DW-1173 turns on:

- `irislib/%SYS/Capture.int` (identical copy in `irissys/`) — `BeginCapture` `:7-19` refuses with
  `ERROR #5001: Capture Already Active` **only when `$Data(^||%capture)`** (`:10`), i.e. once the
  outer capture holds output; `BeginCapture` itself kills the buffer at `:12`, and `EndCapture`
  `:20-41` kills it again at `:39`. So an **empty** outer capture is silently nestable and loses its
  buffer. `%Api.Admin.Util.General` is absent from the export; `irissys/%Atelier/v1/Utils/General.cls:127-152`
  is a bare wrapper over the same routine (inference: AdminPort and MgmntPort share one mechanism).

Server — the tests (all `src/OcuPilot/Test/`):

- `Ledger.cls` — **928 lines** (the ledger entry's "778" is stale), 21 test methods, no properties.
  `OnBeforeOneTest` `:40-44`, `OnAfterOneTest` `:46-53` (four statements: `Clear()`, `RowCount() = 0`,
  `TurnFixture.RemoveTurns`, `tRemaining = 0`), `Clear` `:56-61`. Class-method helpers `RowCount`
  `:65-70`, `RowText` `:75-87`, `StepText` `:94-106`, `NewTurnKey` `:109-112`, `Record` `:117-120`,
  `DispatchedPairs` `:387-416`, `MaxLenOf` `:698-706`, `UserExists` `:760-772`. Parameters
  `PROBEUSER` `:32`, `KEYPREFIX` `:35`, `NARROW` `:24`, `BUDGET` `:27`.
  Already-landed coverage this story must **not** duplicate: `:502` asserts row-level
  `argumentsTruncated` true; `:743` asserts `requiredPairsTruncated` true; `:841-879` pins the
  boundary-stop refusal writer; `:916-926` asserts the unreadable-store fault **object**.
- `LedgerStep.cls` — 110 lines, the **established split precedent**: extends `%UnitTest.TestCase`
  directly `:8`, its own `PROBEUSER` `:21`, its own `OnBeforeOneTest` `:27` / `OnAfterOneTest` `:33` /
  `Clear` `:41`, and reuses the sibling's class-method helpers by full name (`:78`, `:95`). There is
  no test base class and no `.inc` anywhere in the tree; all 126 test classes extend
  `%UnitTest.TestCase` directly.
- Fixtures that already exist and must be reused, not rebuilt: `ToolDispatchProbe.cls` (`FailGate()`
  `:31-34`, `SetRegistryClass` `:19-22`, `Logged()` `:59`); `BadFulfilment/Registry.cls:121-125` and
  `ClashTool/Registry.cls:131-132` (two registries whose `ListTools` already fails, so
  `Registry.ResolveWire` `Screen/Tool/Registry.cls:203-216` returns an error);
  `LedgerClientTool/{Probe,Registry}.cls` (`Directive` `:41-47` — the pattern for the new
  erroring-`Directive` fixture); `LedgerClientDispatchProbe.cls`; `LedgerLoopStopProbe.cls` (stops
  unconditionally, so it **cannot** reach the in-wait branch as written); `LedgerLimits.cls`
  (12 lines, parameters only: `LEDGERMAXROWS = 2`, `LEDGERROWMAXLENGTH = 24`,
  `LEDGERVIEWMAXROWS = 3`) and `LedgerBudgetLimits.cls` — the one-parameter-subclass pattern for the
  new narrow-`MAXSTEPS` and narrow-`NAVWAITSECONDS` fixtures; `LedgerFaultProbe.cls:16-21`
  (`GuardedIdsForWindow` always errors); `LedgerGateProbe.cls`; `TurnProvider.cls:38` `Script(...)`
  whose `pHttpStatus` is its own transport-failure contract (`:115`, `:146`); `TurnFixture.cls`
  (`%RegisteredObject`, `RemoveTurns`, `PROBEPREFIX = OcuPilotProbeTurn`); `MgmntImplFixture.cls:21`
  `Arm(pMethod, pStatus, pJson, pMode)` with its existing `throw`/`write` modes.
- `AdminPortFault.cls:143-160` `TestDeviceOutputNeverReachesTheCaller` — opens a capture at `:146`,
  writes **no** output, and asserts `[]`. Reading `Capture.int`, AdminPort's inner `Begin` therefore
  *succeeded* and the `[]` is the inner `End`'s `Kill ^||%capture`, not containment: **this test
  passes for the wrong reason.**
- `MgmntPort.cls:368-378` — the correct shape to copy, with the mechanism stated at `:371`
  ("A capture counts as open once it holds output, so the open one is given some").
- `LedgerWire.cls:218-237` — asserts the `llm` row's `status = "ok"` only; `:378` `StartNavigationTurn`.
- `Limits.cls` (`Kernel/Agent/`) — `MAXSTEPS = 100` `:30`, `SUMMARYMAXLENGTH = 1000` `:33`,
  `LEDGERMAXROWS = 200` `:74`, `LEDGERROWMAXLENGTH = 4096` `:80`, `LEDGERVIEWMAXROWS = 200` `:84`,
  `NAVWAITSECONDS` read at `Loop.cls:624`.

Client:

- `ui/src/app/core/agent-status.ts` — `formatKillSwitch` `:132`, `FOOTER_KEYS`; the framework-free
  home for the single selector. `ui/src/app/core/` imports no `@angular/core` in any of its 34
  files (the two matches are doc comments); **no lint rule enforces that** —
  `ui/tools/client-lint.mjs:595-602` declares six families and none is about framework imports.
- `ui/src/app/core/suggested-view.ts:305-323` — `agentStatusLine()`: kill switch at `:307-312`, else
  `stringFor(restraint.footerKey)` `:313`. No `answered()` guard (the caller supplies it at
  `panel.ts:686-689`).
- `ui/src/app/shell/panel.ts` — `killSwitch` `:505-507`, `killSwitchMessage` `:513-521`,
  `enforcedReadOnly` `:524-526`, `readOnlyLine` `:532-535` (rendered unconditionally at `:309`),
  and `readOnlyOn` `:540` with a **bare `'statusReadOnlyOff'` literal** — a fourth spelling of
  `FOOTER_KEYS[0]`. `.ocu-panel-empty` template `:248` under `unconfigured` `:484-486` and
  `emptySentence` `:500-502`. `.ocu-suggested-reason` at `:226`, its id built at `:756`.
- `ui/src/app/shell/rail.ts:200-215` — `attentionReason()`, a **different** ladder (gate reminder vs
  read-only). Out of scope; see Design Notes.
- `ui/src/styles/_components.scss` — the four byte-identical base blocks, 14 declarations each:
  `.ocu-locator-reason` `:1449-1465`, `.ocu-command-bar-reason` `:1545-1561`,
  `.ocu-area-tile-reason` `:2000-2016`, `.ocu-suggested-reason` `:3391-3407`. The four **reveal**
  rules `:1467-1474`, `:1563-1570`, `:2018-2025`, `:3409-3416` are pinned by
  `ui/tools/design-tokens.test.mjs:532-537`, `:546-551`, `:567-572`, `:582-587`, each building a
  RegExp from the exact two-line selector spelling — leave them alone. `.ocu-panel-empty`
  `:3267-3272` (type ramp, `margin: 0`, `color: var(--ocu-on-surface-variant)`).
- `ui/browser/panel.browser-spec.mjs` — `authHeader` `:66-68`, `definitions` `:70-76`, `signedInAt`
  `:120-134`, `panelSettlesAt` `:213-219`, `geometry` `:181-210`.
  `ui/browser/suggested-view.browser-spec.mjs` — `authHeader` `:96-98`, `definitions` `:100-106`,
  `signedInAt` `:118-133`, `panelSettlesAt` `:136-143`, `geometry` `:146-164`. Measured by diff:
  `authHeader` and `definitions` are **byte-identical**; `signedInAt` differs only by a third
  `mediaFeatures = null` parameter and one `emulateMediaFeatures` line (a superset);
  `panelSettlesAt` differs in tolerance (`0.01` vs `0.51`) and `geometry` in field count (16 vs 10)
  — those two are **not** duplicates.
  Byte-identical `authHeader` also in `context-chip.browser-spec.mjs:194`, `gate.browser-spec.mjs:97`,
  `switches.browser-spec.mjs:72`. `definitions.browser-spec.mjs:69` has a **different** body and is
  contended — leave it.
- `ui/browser/` shared non-glob modules (the precedent DW-1086 set): `turnprobe-spec.mjs` (the
  agent-definition/turn fixture, header lineage at `:3`), `list-spec.mjs`, `shell-entry.mjs`,
  `iris-session.mjs`; config one level up at `ui/browser.config.mjs` (`DEFAULT_ORIGIN`
  `http://localhost:52776` `:24`, `DEFAULT_CONTAINER` `ocupilot-ci` `:42`, `LIVE_CONTAINER`
  `ocupilot` `:45`, origin/container cross-check refusals `:63-75`).
- `ui/browser/panel-principal.browser-spec.mjs` — 125 lines, one test `:79`; it **does** reach the
  non-administrator state with a real purpose-built principal (`TurnWireFixture.EnsurePrincipal`
  `:34`, `:57-67`, removed `:75-76`, live container refused `:54`) and asserts `.ocu-panel-empty`
  presence `:101` and text `:107`/`:117` — never a computed style.
- `ui/src/app/core/strings.ts` (shared-append, **no change needed**) — `agentGateEmptyState` `:200`,
  `agentReadOnlyEnforcedBanner` `:202`, `agentKillSwitchBanner` `:204`, `statusReadOnlyOff` `:206`,
  `statusReadOnlyEnforced` `:208`, `statusReadOnlyByDefinition` `:212`,
  `privilegeRequiresResource` `:228`, `stringFor` `:1133`.
- Gates: `ui/package.json` `prebuild` `:7` (six checkers), `build` `:10`, `test` `:13`
  (`node --test tools/*.test.mjs && ng test`), `pretest:browser` `:16`, `test:browser` `:17`
  (`--test-concurrency=1`). `ui/angular.json:20` `outputPath: "dist/ocupilot-ui"`; budget `:51-57`
  (`maximumWarning "1050kB"` `:54`, `maximumError "1600kB"` `:55`) pinned at
  `ui/tools/angular-json.test.mjs:365-366`; `ui/tools/build-output.test.mjs:46` reads
  `dist/ocupilot-ui` and `:168-204` is the size gate.

Docs and scripts:

- `.claude/rules/objectscript-testing.md:177-195` — the redeploy section; the one stale token is
  **`:189`** `docker cp dist/ocupilot/browser/. \`. The file is git-tracked and is inside the lint
  gate's document set (`scripts/check-prose.py:40` globs `.claude/rules/*.md`; `IGNORE_PREFIXES`
  `:58-67` does not exclude it), so `bash scripts/lint-docs.sh` must stay clean after the edit.
  The correct form already exists verbatim at `ui/browser/suggested-view.browser-spec.mjs:26` and
  `_bmad-output/implementation-artifacts/spec-4-12-epic-4-burn-down.md:553-554`.
- `scripts/check-objectscript.py` — `CAPTURE_RE` `:907`, the allow-list
  `CAPTURE_ALLOWED = frozenset({"src/OcuPilot/Port/AdminPort.cls", "src/OcuPilot/Port/MgmntPort.cls"})`
  `:912` (comment naming DW-1173 at `:908-911`), enforced `:944-948`, test classes exempt `:918`.
  The rule's reason is stated correctly at `:892-893` and `:947` ("a capture that **holds output**")
  and **incorrectly** in the prose copy at `:165`, which drops the qualifier. 21 checks at
  `:1809-1831`, and `scripts/test_check_objectscript.py:275-300` now pins CLAUDE.md's stated count
  to `len(CHECKS)`.

## Tasks & Acceptance

**Execution** — in this order, so every source edit lands before the single compile-and-test sweep
and the single build-and-deploy sweep.

Group 1 — server source (two files, no new slug):

- `src/OcuPilot/Kernel/Audit/Ledger.cls` — in `PairsToString`, treat a pair whose resource or
  permission contains `,` or `:` as unrepresentable: omit that pair **and** set `pTruncated = 1`,
  so the recorded set is marked incomplete and the existing cross-user withhold (already pinned by
  `Test/Ledger.cls:743`) applies. Reuse the landed truncation signal; invent no new code or slug.
  (DW-1126, first half.)
- `src/OcuPilot/Kernel/Audit/Ledger.cls` — make `RedactedKeys` report provenance rather than
  equality: a key counts as redacted only when the redactor changed it, i.e. its pre-redaction value
  was not the marker and its post-redaction value is. Give it the before object as well as the
  after, and make the value-survival scan at `:181-183` skip a declared value that is itself the
  marker, so a caller-sent `[redacted]` no longer discards the whole argument string or logs a false
  redaction failure. Redaction itself is unchanged — only the reporting is. (DW-1126, second half.)

Group 2 — split the oversized ledger test class before adding to it (DW-1134):

- `src/OcuPilot/Test/LedgerRedaction.cls` (new) — move the two-layer, mandatory-declaration and
  withhold tests out of `Test/Ledger.cls`: its current methods at `:152-196`, `:209-242`, `:257-283`,
  `:294-325`, `:335-361`, `:424-439`. Follow `Test/LedgerStep.cls` exactly: extend
  `%UnitTest.TestCase` directly, declare its **own** `PROBEUSER` keeping the `OcuPilotProbeTurn`
  prefix (so `TurnFixture.RemoveTurns` still sweeps it), its own `OnBeforeOneTest`/`OnAfterOneTest`/
  `Clear`, and call `OcuPilot.Test.Ledger`'s class-method helpers by full class name.
- `src/OcuPilot/Test/LedgerPairs.cls` (new) — move the pair-string, declared-bound and vocabulary
  tests: `:127-143`, `:372-379`, `:447-465`, `:635-668`, `:679-693`, `:722-756`, and the
  `DispatchedPairs` / `MaxLenOf` helpers they need (or call them on `OcuPilot.Test.Ledger`). Same
  shape and its own `PROBEUSER`.
- `src/OcuPilot/Test/Ledger.cls` — keep the store-and-read half (`:475-503`, `:512-540`, `:547-564`,
  `:579-619`, `:790-831`, `:841-879`, `:892-908`, `:916-926`) **and every class-method helper**,
  because `Test/LedgerStep.cls:78,95` already calls them by name. `:841-879` is DW-1123's
  already-pinned boundary-stop writer and must survive the split unchanged, mutation note at
  `:838-840` included. Each of the three parts must come out under the ~500-line guidance.

Group 3 — the pinning tests (each names its own mutation in `## Verification`):

- `src/OcuPilot/Test/ClientCallFault/` (new, two small classes) — a client-fulfilled tool whose
  `Directive` returns an error status and leaves `pFault` empty, plus its registry, modeled on
  `Test/LedgerClientTool/{Probe,Registry}.cls`. This is the **only** new seam DW-1097 needs: the
  registry-read and gate-read branches are already drivable with `BadFulfilment/Registry.cls` and
  `ToolDispatchProbe.FailGate()`. (DW-1097.)
- `src/OcuPilot/Test/ToolDispatchClientFault.cls` (new) — three methods, one per DW-1097 branch,
  each asserting the refusal shape (`$$$OK` status, error result, the fault in
  `ToolDispatchProbe.Logged()` with its code) rather than a turn failure. (DW-1097.)
- `src/OcuPilot/Test/LedgerWire.cls` — add one method arming `TurnProvider.Script` with HTTP 500 and
  asserting the `llm` row's `status = "error"` and its `code`. (DW-1123, leg 1.)
- `src/OcuPilot/Test/LedgerClientRows.cls` (new) + one narrow-`MAXSTEPS` limits fixture, one
  narrow-`NAVWAITSECONDS` limits fixture (each a parameters-only subclass in the
  `Test/LedgerLimits.cls` pattern) and one **call-counting** `Boundary` probe (`LedgerLoopStopProbe`
  stops unconditionally and cannot reach the in-wait branch) — three methods pinning
  `Loop.AnswerClientCall`'s step-cap drop `:612`, in-wait boundary stop `:641` and settle `:702`.
  (DW-1123, legs 3-5.)
- `src/OcuPilot/Test/Ledger.cls` — add two methods to the kept store-and-read half: the view's
  `truncated` reading **true** under `LedgerLimits.LEDGERVIEWMAXROWS = 3` with four rows, and the
  unparseable-requirement withhold, reaching it by setting `RequiredPairs` to `notapair` through the
  direct-SQL idiom already at `:67,78,97` (because `PairsToString` cannot produce such a string) and
  reading cross-user through `LedgerGateProbe`. (DW-1123, legs 6-7.)
- `src/OcuPilot/Test/Ledger.cls` — extend `TestAnUnreadableStoreIsOneUnavailableEnvelope` `:916-926`
  (or add a sibling) to assert the **status**: an `Api.Ledger` subclass whose `LedgerClass()` is
  `Test.LedgerFaultProbe`, driven in process with `%CSP.Request`/`%CSP.Response` stubs, answers
  **503** carrying the existing `LEDGER.UNAVAILABLE`. In process, not over the wire —
  `Api/Router.cls:158` offers no seam. (DW-1123, leg 8.)
- `src/OcuPilot/Test/AdminPortFault.cls` — fix `TestDeviceOutputNeverReachesTheCaller` `:143-160`
  so it proves what it claims: give the outer capture output before invoking the port, copying
  `Test/MgmntPort.cls:368-378`'s shape, and assert the port's capture was refused, the call became
  an internal fault, and no vendor endpoint ran. As written it passes because the inner `End` killed
  the outer's buffer. (DW-1173.)
- `src/OcuPilot/Test/MgmntImplFixture.cls` + `src/OcuPilot/Test/PortCapture.cls` (new) — add one
  additive `pMode` value to `Arm` that calls `OcuPilot.Port.AdminPort.Invoke` from inside
  `MgmntPort`'s capture window, and one test asserting the inner capture is refused once the outer
  holds output and the outer's lines survive. (DW-1173.)
- `scripts/check-objectscript.py:165` — correct the prose copy of the capture rule to carry the
  qualifier the mechanism actually has ("a capture that holds output"), matching `:892-893` and
  `:947`. Add no check, so the CLAUDE.md count stays 21. (DW-1173.)

Group 4 — client, single source where there are several copies:

- `ui/src/app/core/agent-status.ts` — export one framework-free selector that maps a restraint state
  to its one sentence: the kill-switch sentence via the existing `formatKillSwitch` when the switch
  is on, otherwise `stringFor(footerKey)`. No `@angular/core` import. (DW-1150.)
- `ui/src/app/core/suggested-view.ts:305-323` and `ui/src/app/shell/panel.ts:513-535` — call that
  selector instead of re-deriving the ladder, and replace `panel.ts:540`'s bare
  `'statusReadOnlyOff'` with `FOOTER_KEYS[0]`. The panel keeps rendering its banner and its footer
  line as it does today; only the key selection becomes one copy. (DW-1150.)
- `ui/tools/agent-status.test.mjs` — add a table case over every `FOOTER_KEYS` value × kill switch
  on/off asserting the selector's sentence, so the two consumers cannot drift. (DW-1150.)
- `ui/browser/panel-spec.mjs` (new, deliberately outside the `*.browser-spec.mjs` glob, matching
  `turnprobe-spec.mjs` and `list-spec.mjs`) — export `authHeader`, `definitions` and `signedInAt` in
  its superset form (`mediaFeatures = null` default, which is behavior-preserving for the panel's
  call site). Convert **every byte-identical copy** to import them — `panel`, `suggested-view`,
  `context-chip`, `gate` and `switches` browser specs — and leave `panelSettlesAt` and `geometry`
  where they are, because their bodies genuinely differ (tolerance and field count); say so in one
  comment at each. Do not touch `definitions.browser-spec.mjs` (contended, and its body differs).
  (DW-1151.)
- `ui/src/styles/_components.scss` — consolidate the four byte-identical 14-declaration base blocks
  (`:1449-1465`, `:1545-1561`, `:2000-2016`, `:3391-3407`) into one selector list. Leave the four
  reveal rules exactly as spelled — `ui/tools/design-tokens.test.mjs` regexes their two-line
  selectors. Re-measure the initial total with this branch's own `npm run build` and state the
  before/after in the commit message; do **not** reuse DW-1161's 778.17/779.49 figures, which were
  measured on the Epic 4 branch against a different budget. (DW-1161.)
- `ui/tools/design-tokens.test.mjs` — add one assertion that a **single** selector list names all
  four `*-reason` classes and carries the shared 14-declaration body, so a later re-split or a
  dropped class name reddens. Nothing pins the base blocks today, which is why four copies could
  drift; this is the test the consolidation needs in order to be falsifiable. (DW-1161.)
- `ui/browser/panel-principal.browser-spec.mjs` — add a computed-style assertion for
  `.ocu-panel-empty` (the body type ramp, `margin: 0`, the on-surface-variant color) beside the
  existing presence and text assertions. This spec already reaches the state with a real
  non-administrator principal, so no new fixture is needed. (DW-1162, the pin half; the lint-rule
  half is declined — see Design Notes.)

Group 5 — the agent-instruction file:

- `.claude/rules/objectscript-testing.md:189` — change `dist/ocupilot/browser/.` to
  `dist/ocupilot-ui/browser/.`, the path `ui/angular.json:20` declares. One token; leave the
  surrounding prose alone. (DW-1168.)

**Acceptance Criteria:**

- Given every branch this story pins, when a named mutation is applied to that branch, then exactly
  the pinning test for it reddens, and the mutation is reverted with `git status --short` and
  `git diff --stat` byte-identical to before (Rule 19).
- Given `src/OcuPilot/Test/Ledger.cls`, when the split lands, then each of the three resulting
  classes is under ~500 lines, each has its own `PROBEUSER` carrying the `OcuPilotProbeTurn` prefix
  and its own teardown, `Test/LedgerStep.cls`'s calls to `OcuPilot.Test.Ledger`'s helpers still
  resolve, and no test class carries a property whose name begins with `Test`.
- Given the four privilege-reason surfaces, when `_components.scss` is consolidated, then all four
  class names still resolve to the same 14 declarations, `ui/tools/design-tokens.test.mjs` stays
  green on all four reveal rules, and the measured initial total is below
  `ui/angular.json`'s `maximumWarning`.
- Given Home's agent-status line and the panel's footer, when the restraint state changes, then both
  render the sentence the one selector in `core/agent-status.ts` returns, and
  `ui/tools/agent-status.test.mjs` fails if either consumer re-derives it. **(Integration AC,
  Rule 1: consumers `core/suggested-view.ts` and `shell/panel.ts` read the new selector and produce
  the observable sentence asserted by `ui/tools/agent-status.test.mjs` and
  `ui/src/app/shell/panel.spec.ts`.)**
- Given the new `ui/browser/panel-spec.mjs`, when `npm run test:browser` runs against the deployed
  bundle, then every converted spec is green and the module is not itself collected as a spec.
  **(Integration AC, Rule 1: consumers `panel`, `suggested-view`, `context-chip`, `gate` and
  `switches` browser specs import from it and still pass.)**
- Given `.claude/rules/objectscript-testing.md`, when its `docker cp` line is followed verbatim from
  `ui/`, then it names a directory the build actually writes, and `bash scripts/lint-docs.sh` is
  clean.
- Given each of the twelve routed entries, when this story closes, then it is cited by a Task or an
  I/O row above, or declined by name under `## Design Notes` with its reason — none is silent.

## Spec Change Log

## Review Triage Log

## Design Notes

**Governing architecture decisions (Rule 6).** AD-41 — the ledger is a bounded resource, its row is
finalized after the write and records what was executed; DW-1123's unasserted writers, DW-1126's
pair round trip and DW-1128 all sit on it. AD-46 — a user sees their own ledger rows and a
cross-user view is gated by the resources recorded *on the row*, which is exactly what DW-1126's
round trip decides. AD-9 — the guarded escalation idiom (`New $ROLES`, nothing spawned or re-entered
from inside an escalated frame) is what DW-1128 is about and what its decline preserves. AD-2 —
step 6 of the AdminPort sequence is `BeginCaptureOutput`/`EndCaptureOutput`, and the reason it is
load-bearing is that device output would otherwise corrupt AD-12's envelope; DW-1173 is that step's
containment. AD-12 and AD-39 — one envelope, one response writer, a stable `code` that is never
reworded: DW-1123's 503 leg must answer through `Error.Render` with the *existing*
`LEDGER.UNAVAILABLE`, because `Api/Error.cls` is contended and `Test/Ledger.cls:127` asserts the
vocabulary is closed. AD-11 (as amended 2026-09-18 for Story 4.7) and AD-33 — a client-fulfilled
tool's refusals are ordinary tool results and progress content is untrusted data; DW-1097 pins that
normalisation and DW-1133 is a question about how it is rendered. AD-19 — `core/` is framework-free,
so DW-1150's selector goes there and imports no `@angular/core`. Conventions rows that bind:
Secrets (schema-driven redaction, the name pattern add-only — DW-1126 changes reporting only, never
whether a value is redacted), Tests (no `Test*`-prefixed property — DW-1134's split), Client asset
homes (tokens and `strings.ts` — DW-1161, DW-1162). No AC here contradicts an AD.

**Consumes:** `Kernel/Agent/Dispatch.cls` and `Loop.cls` (Story 4.7, 4.9), `Kernel/Audit/Ledger.cls`
and `Kernel/State/Ledger.cls` (4.9), `Api/Ledger.cls` (4.9), `Port/AdminPort.cls` (2.1),
`Port/MgmntPort.cls` (Epic 6, read-only), `core/agent-status.ts` and `shell/panel.ts` (4.3, 4.10),
`ui/src/styles/_components.scss` (1.2), and the fixture classes listed in the Code Map.

**Consumed-by:** the new `core/agent-status.ts` selector — Story 5.2's proposal card and 5.7's
change highlight, both of which render restraint state beside a live proposal; the new
`ui/browser/panel-spec.mjs` — every later panel-shaped browser spec (5.2, 5.3, 5.7); the split
ledger test classes and the new client-row fixtures — Stories 5.3 and 5.6, whose confirm and audit
marker write ledger rows through the same writers pinned here.

**Declined DW-1128:** no measurement establishes a cost — the read is bounded at 200 rows by
`LEDGERVIEWMAXROWS` and nothing has been timed — and the only structural fix is a new multi-column
guarded-read primitive on `Kernel/State/Base.cls`, which every one of the eight stores inherits and
which three of them (`State/Agent.cls`, `State/Hold.cls`, `State/Step.cls`) already implement the
ids-then-per-row-open way; replacing the house read idiom is a redesign this cleanup story is
charted not to do, and the `COUNT(*)` additionally derives `Seq` under the unique
`LedgerTurnSeqIdx`, so it cannot be dropped without re-deciding that index. Reopen if a ledger read
at the 200-row cap is measured above NFR-1's two seconds, or if a later story needs a multi-column
guarded read for its own reason.

**Declined DW-1133:** the honest fix is a product decision about what a progress card shows for a
call the model invented — withholding the blob would leave the user a card with a target and a name
and no arguments at all. The asymmetry with the ledger row is deliberate and documented at
`Kernel/Agent/Dispatch.cls:609-611` and `Loop.cls:766-768`, and a step's lifetime differs from a
ledger row's (a step dies with the turn's retention sweep; `State/Ledger.cls:5-10` records that a
ledger row does not). The lead's own trailer line already names the exit as a product call. Reopen
at the decision sheet, or when a story gives the progress card a rule for model-authored arguments.

**Declined DW-1162, general-gap half:** the lead's adjudication already sized the client-lint rule
family as story-sized, and the investigation confirms why — templates carry 423 distinct `ocu-`
class names against 406 class selectors across the five sheets in `ui/src/styles/`, and 37 template
names are *intentionally* unstyled test and browser hooks (`ocu-panel-full-screen-toggle`,
`ocu-data-table-count`, the four `ocu-log-cell-*`, …), so the rule needs a curated allow-list plus a
policy for names composed at runtime (`list-page.ts:180-185`'s `ocu-banner-${severity}`,
`core/reply.ts:268`'s `ocu-reply-heading-${depth}`, which produces six rules no template names) and
for the `ocu-`-prefixed *ids* a naive scanner would mistake for classes (`panel.ts:35,38,41,44`).
That is design work, not a mechanical cleanup. The `.ocu-panel-empty` pin — the half that is
mechanical — is addressed above. Reopen when a story can own the allow-list and the
dynamic-name policy; the attachment point is family 7 in `ui/tools/client-lint.mjs:595-602` with its
own fixtures in `ui/tools/client-lint.test.mjs`.

**DW-1123's eight legs, and which were already closed.** Two of the entry's six named branches were
pinned by Story 4.9's rework after the entry was filed, so this story confirms rather than rebuilds
them: the boundary-stop refusal writer by `Test/Ledger.cls:841-879`, and row-level
`argumentsTruncated` reading true by `:502`. The remaining legs — the provider `error` leg, the
three client-call writers, the **view**-level `truncated`, the unparseable-requirement withhold and
`Api.Ledger.RenderFault`'s 503 — are the Tasks and I/O rows above. Stating this here is the entry's
disposition: nothing in it is silently dropped.

**Out of scope, with the reason.** `ui/src/app/shell/rail.ts:200-215` implements a *different*
ladder (gate reminder and empty-state sentences, not footer keys) and folding it into DW-1150's
selector would change what the rail says; it is not a copy of the panel's precedence.
`panelSettlesAt` and `geometry` are not duplicates — unifying them would change a tolerance and a
returned field set, which is a behavior change dressed as de-duplication.

**Reported to the lead, not changed here.** (a) The same stale `dist/ocupilot` path DW-1168 fixes
also sits in two of Epic 6's spec files (`spec-6-10-the-locks-view.md:213`,
`spec-6-11-databases-with-free-space-arriving-as-it-lands.md:215`) — another epic's implementation
artifacts, so this story does not edit them (Rule 11). (b) `DW-457` is the same defect, still
`routed owner=17-2-…`; the lead should decide whether it closes with DW-1168 or stays with 17.2.
(c) `CLAUDE.md` says the pre-commit hook runs `check-objectscript.py` "on staged paths", but the
script has no per-file mode and `.githooks/pre-commit:72,101` says so and runs it bare — a stale
claim in a live file, outside this story's footprint.

**Footprint extensions to report (Rule 11(b)).** `.claude/rules/objectscript-testing.md` and
`scripts/check-objectscript.py` are outside the footprint named in the dispatch and are owned by no
contended epic; both edits are one line each.

## Verification

**Commands** — from `/Users/jbrandt/git/OcuPilot/.worktrees/epic-5`, slot A throughout:

- `uv run scripts/check-objectscript.py` -- expected: 0 problems, and the printed check count still
  21 (nothing added, so the CLAUDE.md pin at `scripts/test_check_objectscript.py:275-300` holds).
- `uv run scripts/test_check_objectscript.py` -- expected: all OK.
- `bash scripts/lint-docs.sh` -- expected: clean, including the edited
  `.claude/rules/objectscript-testing.md`.
- Load and compile the whole `src/OcuPilot/` tree into the dev instance through the IRIS MCP tools
  with `server: "ocupilot-slot-a"` (container `ocupilot`) -- expected: compile clean. A mutation
  proves nothing until the package is recompiled, since every subclass keeps its own compiled copy
  of an inherited method.
- `cd ui && npm run build` -- expected: `prebuild`'s six checkers pass and the `Initial total` is
  below `maximumWarning`; record the before/after totals for DW-1161 from **this** branch's build,
  not from the ledger's Epic 4 figures.
- `cd ui && npm test` -- expected: `node --test tools/*.test.mjs` then the component runner, all
  green, including `agent-status.test.mjs`, `design-tokens.test.mjs`, `angular-json.test.mjs`,
  `build-output.test.mjs`, `client-lint.test.mjs` and `panel.spec.ts`.
- `sh scripts/ci-throwaway.sh up --dir /tmp/ocupilot-ci --project ocupilot-ci --web 52776 --super 1975`
  then `sh scripts/wait-readiness.sh --url http://localhost:52776/api/ocupilot/readiness/` --
  expected: readiness answers. Tear this throwaway down at the end with
  `sh scripts/ci-throwaway.sh down --dir /tmp/ocupilot-ci --project ocupilot-ci`, and tear down
  nothing else.
- `node ui/tools/ci-runner.mjs --container ocupilot-ci --class <Class>` -- **one class per call**,
  waiting for each to land in `%UnitTest_Result` before the next, for at least
  `OcuPilot.Test.Ledger`, `LedgerRedaction`, `LedgerPairs`, `LedgerStep`, `LedgerWire`,
  `LedgerClientRows`, `ToolDispatchClientFault`, `AdminPortFault`, `MgmntPort`, `PortCapture`,
  `ToolNavigate`, `TurnNavigate`, `AuditEvent` -- expected: each green with a non-zero assertion
  count. Then `node ui/tools/ci-runner.mjs --container ocupilot-ci` for the full sweep -- expected:
  0 failed, 0 leftovers, 0 overlaps.
- `sh scripts/smoke.sh --container ocupilot-ci --user _SYSTEM --password SYS` -- expected: every
  check passes and the executed count is non-zero (zero executed checks is a failure, never a pass).
- `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`
  then `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci npm run test:browser`
  -- expected: every spec green, including the converted `panel`, `suggested-view`, `context-chip`,
  `gate` and `switches` specs and `panel-principal`'s new computed-style leg. No browser result
  counts before this rebuild and copy: the spec reads the deployed bundle, not the working tree.

**Planned mutations (Rule 19 — apply, observe red, revert, confirm `git status --short` and
`git diff --stat` unchanged, then record each as `mutation: <change> -> <test>` here):**

- DW-1097 registry: delete `Set tSC = $$$OK` at `Dispatch.cls:439` -> `ToolDispatchClientFault`'s
  registry method red (the refusal becomes a turn failure).
- DW-1097 gate: same at `:461` -> the gate method red.
- DW-1097 Directive: same at `:527` -> the Directive method red.
- DW-1123 provider: force `RecordProviderRow`'s leg at `Loop.cls:752` to `"ok"` unconditionally ->
  the new `LedgerWire` provider-error method red.
- DW-1123 client rows: remove each `RecordClientRow` call at `Loop.cls:612`, `:641`, `:702` in turn
  -> the corresponding `LedgerClientRows` method red, one per writer.
- DW-1123 view truncation: force `Audit/Ledger.cls:330`'s `tTruncated` to 0 -> the view-truncated
  method red.
- DW-1123 withhold: remove the `Continue` at `Audit/Ledger.cls:384` -> the unparseable-requirement
  method red (the row is rendered instead of withheld).
- DW-1123 503: map the `LEDGER.UNAVAILABLE` leg at `Api/Ledger.cls:111-113` to 500 -> the status
  assertion red.
- DW-1126 separators: drop the separator check from `PairsToString` -> the separator method red (the
  pair round-trips wrongly and the row is not withheld).
- DW-1126 marker: restore the bare equality test in `RedactedKeys` -> the caller-sent-marker method
  red (the argument string is discarded and a redaction failure is logged).
- DW-1134 split: drop the `OcuPilotProbeTurn` prefix from one new class's `PROBEUSER` -> that
  class's `OnAfterOneTest` `tRemaining = 0` assertion red (`TurnFixture.RemoveTurns` no longer
  sweeps its turns), which is the property the split has to preserve.
- DW-1150: change the selector's precedence so `footerKey` wins over the kill switch ->
  `agent-status.test.mjs`'s table case red **and** `suggested-view.test.mjs:114-128` red.
- DW-1151: make `panel-spec.mjs`'s exported `authHeader` return an empty header, rebuild, redeploy
  -> every converted browser spec red together, which is what one shared copy is for.
- DW-1161: remove one of the four class names from the consolidated selector list -> the new
  `design-tokens.test.mjs` assertion red, while the four reveal tests stay green (they pin the
  reveal rules, not the base).
- DW-1162: delete the `.ocu-panel-empty` block from `_components.scss`, rebuild and redeploy ->
  `panel-principal.browser-spec.mjs`'s computed-style leg red (its presence leg alone stays green,
  which is the gap being closed).
- DW-1173 AdminPort: remove the `If $$$ISERR(tSC) Quit` after `AdminPort.cls:855` -> the corrected
  `TestDeviceOutputNeverReachesTheCaller` red (a vendor endpoint runs outside a capture).
- DW-1173 cross-port: remove `MgmntPort.cls:499-500`'s `tCapturing` guard -> `PortCapture`'s nesting
  method red (the outer's cookie is ended by the inner).
- DW-1168: a prose path has no code mutation and no test host, so the check replaces one: after
  `npm run build`, run the rule file's `docker cp` line verbatim from `ui/` against the throwaway
  and confirm it copies files, and confirm `grep -n 'dist/ocupilot/' .claude/rules/objectscript-testing.md`
  returns nothing. Recorded as a check, not as a pass with no mutation.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none
