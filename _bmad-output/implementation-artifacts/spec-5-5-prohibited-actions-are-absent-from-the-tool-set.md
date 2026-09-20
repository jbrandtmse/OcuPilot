---
title: 'Story 5.5: Prohibited actions are absent from the tool set'
type: 'feature'
created: '2026-09-20'
status: 'done'
baseline_revision: '777d484527e4fc695fe62e8ca8fdd970f7f162c1'
baseline_commit: '98ad9596bc9c33dd3c29eaa9f94754613e3b59ba'
review_loop_iteration: 2
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
warnings: ['oversized']
deferred:
  - summary: >-
      Two spellings of one web application are two scoped targets to the claim, so AD-34's
      per-target lock and its sibling cancel do not cover a re-cased or slash-suffixed id.
    evidence: |-
      `EntityRef.Key` concatenates the id verbatim, `Propose.TargetLockKey` digests the reference
      text and the sibling cancel is `%EXACT(TargetRef)` -- verified at `Propose.cls:283,345`. Two
      confirms against `/api/ocupilot` and `/API/OcuPilot` take different locks, so the second is
      refused 409 by the fingerprint gate rather than serialized, and a sibling stays live rather
      than being canceled. Closing it means normalizing an id per entity type where the mint builds
      the ref, which is wider than this story. reopen_if=a second write tool ships, or two proposals
      on one target are observed both live.
    location: 'src/OcuPilot/Kernel/EntityRef.cls:44'
    severity: medium
  - summary: >-
      `ServesOcuPilot` asks install's record store twice -- once for the normalized path, once for
      the id as it came -- because the store's own lookup is an exact compare.
    evidence: |-
      `WebApp.GuardedForPath` is `WHERE %EXACT(Path) = ?`, so neither call answers a record written
      in some third spelling. Every record install writes carries a roster or probe literal, and a
      test asserts each roster path is already in the instance's own form; the store is out of this
      story's footprint (`Kernel/State/**`). reopen_if=anything but install writes a record.
    location: 'src/OcuPilot/Kernel/Proposal/Prohibited.cls:412'
    severity: low
  - summary: >-
      That the mint checks all three of its stream writes is pinned from its source, not from a
      failing write.
    evidence: |-
      No input a caller can hand the mint makes a global stream refuse a write -- probed on
      `ocupilot-ci`: a file stream aimed at an unwritable path and `%Stream.NullCharacter` both
      answer `$$$OK`, and `%Stream.Object` is abstract. A fixture object whose own `Write` refuses
      cannot be declared either: `check-objectscript.py`'s one-writer rule (AD-12) refuses a method
      named `Write` outside `Api/Response.cls` and `Api/Error.cls`. The round trip pins that the
      three texts still store.
    location: 'src/OcuPilot/Test/ProhibitedByEffect.cls:445'
    severity: low
---

<intent-contract>

## Intent

**Problem:** AD-10's prohibited set has a seam and no set: `Write.ProhibitedClass()` answers `""`, so
the confirm transition asks "is this prohibited?", is told no, and writes. The one shipped write tool
makes that concrete — `AutheEnabled`, `Resource` and `DispatchClass` are ordinary, settable arguments
(DW-1207, floor-blocking), so a confirmed write can make a web application reachable unauthenticated,
drop its authorization resource, or point its URL at arbitrary compiled code.

**Approach:** Create the set's one home in the kernel as predicates evaluated against the **resolved
target**, read live at the moment of the write; point the shipped seam at it; fail closed for any
entity type the set does not yet evaluate; and take the fields whose every change is prohibited out of
the advertised tool schema, so the model cannot author them at all.

## Boundaries & Constraints

**Always:** One home — `src/OcuPilot/Kernel/Proposal/Prohibited.cls` is the only class that decides
what is prohibited, reached only through `Write.ProhibitedClass()`. Predicates compare the stored
payload against the target **as the instance holds it now**, read inside the transition through the
same port and endpoint the write uses; the set is defined by **effect, not by verb**, and never by a
match on request or argument fields. Refused whatever the caller, before the port call; governance can
disable a permitted tool and can never enable a prohibited one. Every code is dotted-uppercase
(`Api.Error` `CODEPATTERN`) with exactly one written reason, resolvable by `Api.Confirm.ReasonFor`. A
denial test uses a purpose-built least-privileged role, never `%Operator`. Every IRIS MCP call carries
`server: "ocupilot-slot-a"`; privilege-mutating checks run on the throwaway `ocupilot-ci`.

**Never:** No second decision point — the seam stays exactly where Story 5.3 put it, named once, before
the write goes out; 5.3's gate order is not reordered. No copy of the set in a screen, a descriptor, a
policy file or a governance flag. No persistence, so no Storage section. No delete path, no new write
tool, no client or UI change, no string-table entry. Do not edit `scripts/` (Epic 13) or
`ui/tools/field-lists.mjs`; do not write `deferred-work.md`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Weakened authentication (DW-1207) | Target web application reads `AutheEnabled` 32; stored payload carries 96 | Confirm refused 403 `PROHIBITED.UNAUTHENTICATED`; row stays live; `WriteCount()` 0 | Refusal, not error |
| Dropped authorization (DW-1207) | Target `Resource` `%Development`; payload `Resource` `""` | Refused 403 `PROHIBITED.AUTHORIZATION`; nothing reaches the port | Refusal |
| Repointed dispatch (DW-1207) | Payload `DispatchClass` differs from the target's | Refused 403 `PROHIBITED.DISPATCH`; and the model asking for it is refused earlier still, 400 `TOOL.ARGUMENTS`, with no proposal minted | Refusal at both points |
| Role grant | Payload `MatchRoles` differs from the target's | Refused 403 `PROHIBITED.PRIVILEGEGRANT`; the field is not in the advertised schema either | Refusal |
| OcuPilot's own path | Target is a path `Kernel.State.WebApp` records or `Install.Roster` declares; payload `Enabled` false | Refused 403 `PROHIBITED.SERVINGPATH` | Refusal |
| Entity type the set does not evaluate | `targetRef` of type `user`, `process`, `role`, `resource`, `service` or `database`, any payload | Refused 403 `PROHIBITED.UNCOVERED` | Refusal |
| A hardening change (Story 5.8's demo) | `Resource` `""` -> `%Development`, or `AutheEnabled` 96 -> 32, or `Enabled` false -> true on a non-OcuPilot application | Not prohibited; the confirm proceeds to the restraint, pair, conversation, definition and fingerprint gates unchanged | None |
| Target gone between mint and confirm | The set's read answers not-found | Not prohibited; the shipped fingerprint gate refuses 409 `PROPOSAL.TARGETCHANGED` and closes the row | Unchanged behavior |
| Target unreadable (port fault) | The set's read fails | `Prohibits` answers an error status; Confirm renders 500 `INTERNAL`; no write goes out | Fail closed |

</intent-contract>

## Code Map

- `src/OcuPilot/Kernel/Proposal/Write.cls:198` -- `ProhibitedClass()` returns `""`: AD-10's single
  named home, the one line this story repoints. `ReasonFor()` `:74` resolves the `PROPOSAL.*` family.
- `src/OcuPilot/Kernel/Proposal/Confirm.cls:57` -- `ProhibitedClassName()`; `:186-199` the call site
  inside `Transition`, before the restraint verdict, the pairs, the fingerprint re-read and the port
  call. The seam's contract is fixed there:
  `Prohibits(toolName, targetRef, payloadJson, diffJson, .prohibits, .code)` returning `%Status`,
  refused at 403
  with the set's own code; an error status becomes 500 `INTERNAL`.
- `src/OcuPilot/Kernel/Proposal/Confirm.cls:435-479` -- `FingerprintMatches`: the idiom for resolving a
  tool to its endpoint, id parameter and id value, and for reading the target fresh through `PortClass()`.
- `src/OcuPilot/Kernel/Proposal/Mint.cls:226` `Merge`, `:381` `Display` (`Private`) -- the rendered-form
  comparison the diff is computed with; the predicates must compare the same way.
- `src/OcuPilot/Screen/Tool/WebAppUpdate.cls:24,45` -- `EXCLUDEDFIELD`/`ExcludedFields()`, today
  `MatchRoles` alone; `:39` `SettableFields()` = `AdmittedFields()`.
- `src/OcuPilot/Screen/Tool/Write.cls:75,98,163` -- `ExcludedFields()`, `FieldRows()`, `InputSchema()`:
  an excluded name leaves both `SettableFields()` and the advertised schema, which is closed with
  `additionalProperties: false`, so the model asking for it is a 400 before any proposal exists.
- `src/OcuPilot/Screen/Tool/Classification.cls:36,46,65` -- the reviewed entries that make
  `AutheEnabled`, `DispatchClass` and `Resource` `ordinary`. **Read-only here**: the classification
  states what the vendor field is, not what the agent may do with it (DW-1207's footprint line names
  this file; the owner's decision puts the control in the prohibited set).
- `src/OcuPilot/Screen/Tool/Registry.cls:104` `ListTools`, `:179` `Resolve` -- a tool entry carries
  `name`, `kind`, `class`; a write tool's descriptor is `$Parameter(class, "DESCRIPTORCLASS")` and its
  entity type `PrimaryEntityType()` (`Screen/Descriptor/Base.cls:225`). Kernel may read the registry;
  the registry must not read the kernel.
- `src/OcuPilot/Kernel/State/WebApp.cls:60` -- `GuardedForPath(path, .object)`: whether install created
  or adopted the application at that path, production and probe profiles alike.
- `src/OcuPilot/Install/Roster.cls:105-148` -- the three declared application paths (`/ocupilot`,
  `/api/ocupilot`, `/api/ocupilot/readiness`) and `Application(key, .app)` to read them.
- `src/OcuPilot/Kernel/EntityRef.cls` -- `Parse(ref, .type, .scope, .id)`; `Kernel/EntityType.cls:28`
  the closed vocabulary.
- `src/OcuPilot/Api/Error.cls` `Parameter CODEPATTERN` -- `^[A-Z][A-Z0-9]*(\.[A-Z][A-Z0-9]*)*$`;
  `src/OcuPilot/Api/Confirm.cls:111` `ReasonFor` asks `Proposal.Write.ReasonFor` first.
- `src/OcuPilot/Kernel/Governance/Gate.cls:17` -- `Decide` allows every registered tool in Release 1;
  its own header already says what Release 1 refuses is absent from the tool set.
- `src/OcuPilot/Test/ProposalConfirm.cls:273-286` -- `TestTheProhibitedSeamIsCalledOnceBeforeThePortCall`
  **asserts `ProhibitedClass()` is `""`** and goes red the moment the seam is filled; `:288-300`
  `TestAProhibitedWriteIsRefusedBeforeThePortCall` drives the refusal branch through the fixture.
- `src/OcuPilot/Test/ProposalFixture.cls:99,109,118` -- `ArmProhibited`/`ProhibitedClass`/`Prohibits`
  (the fixture set, code `AGENT.PROHIBITED`); `:24-60` `Arm`/`ArmMissing`/`ArmEmpty`/`ArmWriteFault`;
  `:355-409` `EnsureWriteTarget`/`WriteTargetField`/`RemoveWriteTarget`, a **real** probe web
  application; `src/OcuPilot/Test/ConfirmFixture.cls` -- the seam-replacing Confirm subclass.
- Verified on `ocupilot-slot-a`, 2026-09-20: `irissys/%sySecurityMacros.inc:19-20` gives AuthePassword
  32 and AutheUnauthenticated 64; `Security.Applications` reads `/api/ocupilot` 32, `/ocupilot` 64,
  `/api/ocupilot/readiness` 64, `/csp/sys` 96.

## Tasks & Acceptance

**Execution:**

- `src/OcuPilot/Kernel/Proposal/Prohibited.cls` -- create AD-10's one home. It declares its codes and
  one written reason each (`Codes()`, `ReasonFor()`); `COVEREDTYPES` (Release 1: `web-application`);
  `AlwaysProhibitedFields(pType)` (`MatchRoles`, `DispatchClass`); an overridable `PortClass()`; and
  `Prohibits(pToolName, pTargetRef, pPayload, pDiff, .pProhibits, .pCode)`, which parses the ref,
  refuses
  `PROHIBITED.UNCOVERED` for an unparseable ref or an uncovered type, and otherwise runs that type's
  predicates in declared order against the target read live through the port -- first hit wins.
  `UncoveredWriteTools()` answers the registered write tools whose entity type has no predicate.
- `src/OcuPilot/Kernel/Proposal/Write.cls` -- `ProhibitedClass()` answers the new class; `ReasonFor()`
  delegates a `PROHIBITED.`-prefixed code to `..ProhibitedClass()` so the set still has one home.
- `src/OcuPilot/Kernel/Proposal/Mint.cls` -- drop `[ Private ]` from `Display()` so the predicates
  compare values exactly as the diff does, one copy rather than two.
- `src/OcuPilot/Screen/Tool/WebAppUpdate.cls` -- `ExcludedFields()` gains `DispatchClass`; the header
  states the two halves (absent from the tool set, and refused at the write whatever the caller) and
  why `AutheEnabled` and `Resource` stay settable.
- `src/OcuPilot/Test/ProhibitedFixture.cls` -- test-only subclass of the set replacing `PortClass()`
  with `OcuPilot.Test.ProposalFixture`, so the shipped predicates run against an armed target.
- `src/OcuPilot/Test/Prohibited.cls` -- the suite: every I/O matrix row, the acceptance criteria below,
  and a real end-to-end leg against `EnsureWriteTarget`'s probe application through the shipped
  `Confirm`. Keep it under ~500 lines; split if it grows past that.
- `src/OcuPilot/Test/ProposalConfirm.cls` -- update
  `TestTheProhibitedSeamIsCalledOnceBeforeThePortCall`: the seam now answers the kernel class, and the
  call-once/before-the-write assertions stay. Do not weaken either.

**Rework iteration 2's three items are closed. Iteration 1's four were closed before it.**

- `[x]` **DW-1352 (high).** Closed: `ServesOcuPilot` compares both sides through
  `Prohibited.NormalizedPath` -- lower case with every trailing slash removed, which is the
  normalization the instance itself performs. Pinned by
  `ProhibitedByEffect.TestAChangeToOcuPilotsOwnApplicationIsRefused` (each roster and recorded path
  under three spellings the instance resolves) and by
  `ProhibitedRoute.TestTheSetNormalizesAPathTheWayTheInstanceResolvesIt`, which compares the set's
  answer with the shipped port's for six spellings, three resolved and three not.
- `[x]` **DW-1353 (high when composed).** Closed: `GuardedMint` takes the status of all three
  stream writes and saves no row on a failure. Pinned by
  `ProhibitedByEffect.TestAMintChecksEachStreamWriteOrStoresNoRow`.
- `[x]` **DW-1354 (med).** Closed by composition, argued in `## Design Notes` under *Why a row
  whose diff names nothing is no longer producible*, with the producer half pinned in
  `ProhibitedByEffect.TestAProposalIsJudgedOnWhatItChanges`.

**Acceptance Criteria:**

- Given the shipped `Kernel.Proposal.Confirm` and a stored proposal whose payload would drop a real
  probe web application's `Resource`, when the browser POSTs `/api/ocupilot/proposal/{id}/confirm` on
  the throwaway, then the response is 403 with `code` `PROHIBITED.AUTHORIZATION` and a rendered
  `reason`, and the application's properties on the instance are byte-for-byte what they were.
  *(Integration AC, Rule 1: the consumer is the shipped confirm path, observed over HTTP.)*
- Given the prohibited set, when the tree is searched, then no class outside
  `Kernel/Proposal/Prohibited.cls` and the tests decides a prohibition or spells a `PROHIBITED.` code,
  and the set names no governance, screen, descriptor or policy class.
- Given every registered write tool, when its advertised input schema and `SettableFields()` are read,
  then neither admits any field `AlwaysProhibitedFields()` names for that tool's entity type, and
  `UncoveredWriteTools()` is empty.
- Given DW-1207's three fields, when the model asks for a `DispatchClass` change, then the tool refuses
  400 `TOOL.ARGUMENTS` and mints nothing; and when a proposal carrying any of the three weakening
  changes reaches confirm by any other route, then the write path refuses it. *(DW-1207)*
- Given the Release 1 governance gate allowing every registered tool, when a prohibited proposal is
  confirmed, then it is still refused -- the verdict is reached before the restraint verdict and is
  conditioned on no governance state.
- Given each code the set declares, when it is rendered, then it matches `Api.Error` `CODEPATTERN`,
  `Api.Confirm.ReasonFor` answers a non-empty sentence for it, and the sentence exists once.

## Spec Change Log

- 2026-09-20, lead spec gate: the plan stage's finding that DW-1207's evidence line inverts the
  `AutheEnabled` bitmask was corrected at the ledger entry itself (trailer `by=lead`) rather than
  carried as a deferred item, and that item was dropped from `deferred:`. `AuthePassword` is 32 and
  `AutheUnauthenticated` is 64; the entry's readings were right and only its interpretation sentence
  was inverted. The predicate keys off bit 64 being added.

## Review Triage Log

### 2026-09-20 -- Review pass

- verdicts: 45 findings -- high 5, medium 17, low 22, false 1, maybe-false 0
- findings:
  - `[medium]` `[patch]` `Confirm.cls` still says the seam answers `""` "until Story 5.5" at the gate's only call site -- replaced both the doc comment and the inline comment with what the seam now answers.
  - `[medium]` `[patch]` The new gate-order assertion `$Find(a) < $Find(b)` passes when the call is deleted, since `$Find` answers 0 -- both offsets are now asserted non-zero first; mutation 192 reddens it.
  - `[high]` `[defer]` Only `DispatchClass` is guarded among the fields that decide what code answers at a URL; `EventClass`, `SuperClass`, `NameSpace`, `Path` and five more are settable -- verified against the generated field list; pre-existing (nothing was refused before this story), deferred at high.
  - `[high]` `[defer]` `PROHIBITED.UNAUTHENTICATED` keys on bit 64 alone; `TwoFactorEnabled`, `CSRFToken`, `JWTAuthEnabled` and the rest are settable and unrefused -- same disposition and reason.
  - `[high]` `[defer]` `PROHIBITED.SERVINGPATH` refuses only `Enabled`, while `NameSpace` and `Path` break OcuPilot's own applications just as completely -- same disposition and reason.
  - `[low]` `[patch]` `UncoveredWriteTools()`'s doc claims it makes the next tool impossible to ship without predicates; it reads `CoveredTypes()` alone, so a covered type with no dispatch arm greens the gate and refuses at runtime -- the claim now states what the gate guarantees.
  - `[low]` `[patch]` `ParsedObject()`'s doc claims the predicates refuse an unreadable payload; `Unauthenticated("")` is 0, so a `{}` payload against a bare target is not prohibited -- the sentence now states what is true.
  - `[low]` `[reject]` The target is read live twice per confirm (the set, then the fingerprint gate) -- the spec's Design Notes require the set to resolve and read the target itself; one extra `GET`, no correctness effect.
  - `[low]` `[reject]` `ServesOcuPilot` parses the roster four times and does not stop at the first hit -- short-circuiting would skip roster reads whose failure the method currently surfaces as an error, trading fail-closed behavior for four XData parses.
  - `[medium]` `[patch]` Nothing asserted that the shipped set points at the production port and registry, so a class left on the fixture would read green wherever the armed suite cannot run -- two assertions added; mutation 200 reddens them.
  - `[low]` `[reject]` The `MatchRoles` member of the always-prohibited-field loop cannot redden -- the loop's contract holds, the vacuity is a property of the generated field list (both rows are dotted and dropped earlier), and the `DispatchClass` member is load-bearing.
  - `[low]` `[patch]` Four "this goes red" mutations stated in `Test/Prohibited.cls` doc comments were never run -- three are now demonstrated (runs 194, 195, 197) and the non-discriminating `COVEREDTYPES` claim was replaced by the registered-probe-tool mutation the record already carried.
  - `[false]` `[reject]` "`ProposalMint` and `Dispatch` were not run although `Mint.cls` changed" -- neither declares a `Test*` method; both are fixtures, and the runner fails an invocation that names one. The `## Verification` class list was corrected at its origin.
  - `[low]` `[reject]` `ProhibitedRoute`'s arming flag is named `OCUPILOT_ALLOW_PRINCIPALS` but the class creates a web application -- that flag is the project's one throwaway-arming switch, shared with `EnsureWriteTarget`; the class header states what it creates.
  - `[low]` `[reject]` A `Guard()` failure after `EnsureWriteTarget` leaks the probe application, since `OnAfterAllTests` never runs -- the trigger requires `Security.Applications.Modify` to fail on a throwaway holding `%All`.
  - `[low]` `[reject]` `PRIVILEGEGRANT`, `SERVINGPATH` and `UNCOVERED` never cross HTTP -- the envelope shape, the `forbidden` slug and the rendered reason are pinned over the wire once; three more legs is more than a direct correction.
  - `[low]` `[reject]` `Prohibits()` discards the scope `EntityRef.Parse` returns -- the tool's endpoint and the fingerprint re-read address the target by id the same way, and Release 1 mints web-application refs at instance scope only.
  - `[high]` `[defer]` (edge-case layer, same root cause as the `DispatchClass`-only finding above) a settable field other than `DispatchClass` repoints which code answers.
  - `[high]` `[defer]` (same root cause as the `SERVINGPATH` finding above) OcuPilot's own application weakened by any field except `Enabled`.
  - `[low]` `[reject]` A resource-to-resource swap is not refused -- already the spec's third `deferred:` entry, recorded from the owner's DW-1207 decision, which names "drop Resource".
  - `[low]` `[reject]` A non-numeric `AutheEnabled` fails open, because `$IsValidNum("96abc")` is 0 while the vendor normalizes it to 96 -- `Mint.cls:262-263` refuses a value the instance's own type cannot carry, so a stored payload's `AutheEnabled` is always a number.
  - `[low]` `[patch]` An empty or unparseable stored payload answers "not prohibited" -- grouped with the `ParsedObject()` claim above; the behavior is contained by the fingerprint gate and the doc now says so.
  - `[medium]` `[defer]` (same root cause as the stale-proposal finding above) `MatchRoles` reordered by a third party earns 403 rather than 409.
  - `[low]` `[reject]` (same root cause as the scope finding above) a namespace-scoped ref is judged against an instance-scope read.
  - `[medium]` `[patch]` `Confirm.Transition:298` merges declared secret values into the payload after the prohibited check at `:188`, so a future tool declaring an always-prohibited field as a secret would bypass the set -- not reachable today (the one write tool declares none); the invariant is now asserted per write tool, and mutation 201 reddens it.
  - `[low]` `[reject]` `Write.ReasonFor` calls `$ClassMethod(ProhibitedClass(), ...)` unguarded, so an absent class raises `<CLASS DOES NOT EXIST>` on the error path -- requires a deployment missing a class shipped in the same package, and the fix adds a guard.
  - `[medium]` `[patch]` (same root cause as the first row) the stale seam doc at `Confirm.cls:51-56,186-187`.
  - `[medium]` `[patch]` `ProhibitedRoute.Snapshot` compared four properties while the acceptance criterion says byte-for-byte -- it now compares the whole property set the vendor `GET` renders.
  - `[medium]` `[patch]` (same root cause as the verification-gap layer's `CallCount` finding) the "mints nothing" clause is pinned by a counter nothing on the path increments.
  - `[medium]` `[patch]` The `Kernel.State.WebApp` half of `ServesOcuPilot` was never observed -- every test case was answered by the roster branch, which returns first. A recorded-path leg was added; mutation 196 reddens it alone.
  - `[medium]` `[patch]` "nothing reached the port" and "byte-for-byte what they were" could not fail, because every seeded proposal carried fingerprint `"0"` and the gate behind the set refused first -- `Seed` now stores the digest the confirm re-computes; with the set removed (mutation 193) the confirms succeed and write, so the safety clauses redden.
  - `[medium]` `[patch]` `CallCount() = 0` observes a fixture that is not on the call path -- replaced by a proposal-row count for the running account; mutation 203 minted a real row and reddened it.
  - `[low]` `[patch]` AC2 had no mutation -- `PROHIBITED.DISPATCH` copied into `Kernel/Governance/Gate.cls`, run 194 red, line written.
  - `[low]` `[patch]` AC5's recorded mutation did not reach AC5's test, whose confirm fixture answers an armed set -- the prohibited call removed from `Confirm.Transition`, runs 192-193 red, attribution corrected.
  - `[low]` `[patch]` AC4 had no mutation line of its own -- both halves are now labeled against the mutations that redden them.
  - `[medium]` `[patch]` (same root cause as the gate-order row above) the ordering assertion passes on absence.
  - `[low]` `[patch]` `UncoveredWriteTools()` emptiness had no floor -- at least one inspected write tool is now asserted; mutation 198 reddens both floors.
  - `[medium]` `[patch]` (same root cause as the first row) stale doc comments in `ConfirmFixture.cls` and `ProposalFixture.cls`.
  - `[medium]` `[patch]` `WriteExclusion.cls` and `ToolWrite.cls` said the shipped tool's only exclusion is a subtree the nested-path filter drops, which `DispatchClass` makes false -- both sentences replaced.
  - `[medium]` `[defer]` (same root cause as the stale-proposal finding above) a third-party `DispatchClass` change earns a misleading sentence.
  - `[medium]` `[patch]` The matrix's "target unreadable (port fault)" row was exercised by `ArmEmpty`, an HTTP 200 carrying no object, which lands on a different branch -- `ArmReadFault` was added to the fixture and a leg drives the non-404 error branch; mutation 199 reddens it alone.
  - `[low]` `[reject]` `ProposalFixture.Prohibits` still answers the non-conforming code `AGENT.PROHIBITED`, invisible to the one-home sweep -- it is a fixture's own refusal code, and the sweep skips `OcuPilot.Test.` by design so that fixtures can carry codes the shipped set must not.
  - `[low]` `[reject]` `ProhibitedClass()` now has two call sites, the transition and `ReasonFor` -- the spec's Tasks require the delegation so the sentences have one home; a lookup is not a decision point.
  - `[low]` `[reject]` The serving-path predicate refuses an end state rather than a change, so it refuses a no-op -- the diff states and justifies that reading, and the matrix row is satisfied under either.

### 2026-09-20 -- Review pass (rework 1)

- verdicts: 48 findings -- high 2, medium 6, low 23, false 5, maybe-false 0
- findings:
  - `[high]` `[patch]` The set judged only the stored diff, so a row whose payload weakens the live target while its diff names nothing passed it silently and was written -- verified: `Confirm.Transition:298` sends the stored payload and `FingerprintMatches` digested only `Merge(fresh, storedArguments)`. Fixed at the gate AD-6's Rule names: the stored payload must digest to the row's own fingerprint. Mutation 295.
  - `[high]` `[patch]` (same root cause) an empty, absent or unparseable diff disarmed every predicate, `SERVINGPATH` included, where every other unreadable input fails closed -- the four legs of the new test cover `[]` and `"not json"`.
  - `[low]` `[patch]` Nothing tied `Changed()`'s `"field"` key to the `Mint.Merge` that writes it -- one assertion added over a real merge; mutation 300 renames the key and reddens it.
  - `[low]` `[patch]` `PROHIBITED.UNCOVEREDFIELD` cannot fire through the shipped tool, because the mint diffs only settable fields -- true and by design; the code is the backstop for a row the tool did not mint, which the new fingerprint check is what makes reachable-and-safe. The class header no longer overstates it.
  - `[high]` `[patch]` `AutheEnabled` carries strength modifiers as well as mechanisms (`irissys/%sySecurityMacros.inc:15-40`), so the subset test permitted turning two-factor off -- the exact weakening DW-1346 named -- and refused requiring it with a false sentence. Replaced by "clearing the unauthenticated bit and nothing else"; mutation 297.
  - `[low]` `[patch]` `32 -> 2080` was labeled "a mechanism this build does not define"; 2048 is `AutheLDAP`, which it does. Replaced by 1056 in the test and corrected in `## Auto Run Result`.
  - `[medium]` `[patch]` The reviewed-few floor was asserted in one direction only while the tool and the spec both claimed agreement -- the converse and a disjointness assertion added; mutation 298.
  - `[low]` `[patch]` The recorded mutation "drop `DispatchClass` from `ExcludedFields()`" no longer reddens anything, because the positive list governs admission -- the doc now names the mutations that do and says what the exclusions are now.
  - `[low]` `[patch]` `ProhibitedByEffect`'s header said nothing there writes to the instance while it writes a `Kernel.State.WebApp` record and seeds rows -- sentence corrected and the record's removal moved into `OnAfterOneTest`.
  - `[low]` `[reject]` `Write.PermittedFields()` defaults to no restriction, so the protection is opt-in per tool -- a base class cannot know a subclass's reviewed set, and the per-tool floor test reddens on drift. Rejecting a low whose fix adds a branch.
  - `[low]` `[patch]` `$ListFromString(..#PERMITTEDFIELDS)` does not trim, so a space-padded edit would silently drop fields -- closed by the converse assertion above, which reddens on a smaller settable list.
  - `[low]` `[patch]` No leg drove an array-valued property through `Rendered`/`Changed` -- a `CorsAllowlist` leg added.
  - `[medium]` `[patch]` `Widens`'s fail-closed branches were unreachable from any test, and `\ 1` truncated `32.5` into a no-op check -- the replacement refuses a value that is not a non-negative whole number and the test drives a fractional and two non-numeric values.
  - `[low]` `[patch]` That test's own mutation recipe named the wrong legs -- rewritten with the predicate.
  - `[medium]` `[defer]` `Enabled` is permitted with no asymmetric predicate, so disabling `/csp/sys` or `/api/atelier` is proposable -- the AD-38 argument covers OcuPilot's own paths only, so it is by design; the product question is in `deferred:`. The doc's claim about the reviewed argument is now written out.
  - `[medium]` `[defer]` `ServesOcuPilot` is an exact string compare and is now the first predicate -- unverified whether the vendor endpoint resolves a differently-cased id to the same application; in `deferred:` with the probe that settles it.
  - `[low]` `[defer]` `PROHIBITED.UNCOVEREDFIELD` names no field and picks it in collation order -- in `deferred:`; naming it means a detail alongside the code, which the seam's contract does not carry.
  - `[low]` `[patch]` `Codes()`, the parameter block and `WebApplication`'s doc gave three different predicate orders -- all three now give the evaluation order.
  - `[low]` `[patch]` `followup_review_recommended` was `true` with no named risk -- named under `## Auto Run Result`.
  - `[false]` `[reject]` "The rework deleted the previous pass's record" -- a rework's `## Auto Run Result` records this pass and does not restate earlier ones (project prose discipline), and the deleted slot-A paragraph was a wrong diagnosis the lead verified against.
  - `[low]` `[patch]` The `## Verification` command list named 17 classes against 19 run -- aligned.
  - `[low]` `[patch]` The smoke numbers were reported as 44/44 with one skip and no cause shown -- both readings recorded; the skip is `agentswitches` after this suite writes switches, and a clean run reads executed=45 passed=45 skipped=0.
  - `[false]` `[reject]` `"webapp.list.update"` in three constants can diverge unnoticed -- every direct call in both suites goes through the same tool, and a divergence reddens the first leg it reaches.
  - `[low]` `[patch]` `Classification.cls` still described the old model, with `ordinary` reading as "the tool admits it" -- one sentence added; the reviewed XData is untouched.
  - `[high]` `[patch]` (edge-case layer, same root cause as the first row) an empty or absent diff skips every predicate.
  - `[high]` `[patch]` (same root cause) a non-array or truncated diff reads as no changes.
  - `[medium]` `[defer]` `Propose` discards the status of `Diff.Write`, so a failed stream write stores a row with no diff -- out of footprint (`Kernel/State/**`); in `deferred:`.
  - `[medium]` `[patch]` (same root cause as the first row) a `FingerprintExcludes` path was checked by neither the set nor the fingerprint -- the stored-payload digest uses the same excludes, and any non-permitted field the payload moves is now refused by the set.
  - `[low]` `[patch]` A target mask of 0 makes every payload a refusal, so a genuine hardening on such an application cannot be proposed -- true of the new predicate too and now stated at the method; fixing it would need a ranking of mechanisms the instance does not publish.
  - `[medium]` `[patch]` (same root cause as the reviewed-few floor row) a name added to `PermittedChangeFields` alone reddened nothing.
  - `[high]` `[patch]` (same root cause as the first row) AC4's "by any other route" was not pinned by anything, and `ProhibitedRoute.Seed` had to gain a real diff for its legs to stay red.
  - `[low]` `[patch]` The first Execution bullet still stated the five-argument seam -- corrected.
  - `[high]` `[patch]` (verification-gap layer, same root cause as the first row) the diff is the set's only trigger and no test seeds a prohibited payload with an empty diff.
  - `[medium]` `[patch]` (same root cause as the `Widens` row) the fail-closed branches are unreachable from any test.
  - `[medium]` `[patch]` (same root cause as the reviewed-few floor row) the spec claimed both directions.
  - `[low]` `[patch]` `ParsedObject`'s new doc comment was wrong about what an unreadable payload does -- corrected.
  - `[low]` `[patch]` (same root cause as the class-list row) the two lists disagreed on which classes were run.
  - `[low]` `[patch]` No mutation line covered `Changed()`'s live-comparison half -- mutation 299 added.
  - `[low]` `[defer]` `Screen.Registry.ToolFieldRows` over-approximates a write tool's settable fields by 41 names -- conservative direction, inaccurate message, out of footprint; in `deferred:`.
  - `[false]` `[reject]` (intent layer) "the verdict gained an input the matrix does not have" -- true of the diff, and the matrix rows are decidable again now that the fingerprint gate covers the stored payload; DW-1351 required the third input.
  - `[medium]` `[patch]` (same root cause as the first row) the kernel's reach became a subset of the tool layer's field list.
  - `[medium]` `[defer]` The schema narrowing is forty-one fields wider than the intent's own clause -- the consequence of AD-10's title once every change to the unreviewed fields is prohibited; in `deferred:` for the owner.
  - `[false]` `[reject]` "No copy of the set in a screen" is strained by `PERMITTEDFIELDS` -- it is the pattern the baseline established for the two excluded names and the two lists are now asserted equal, so neither can drift.
  - `[low]` `[patch]` `64 -> 96` was pinned as refused under a "widening" sentence that did not describe it -- the new predicate and its sentence describe every refusal it makes.
  - `[low]` `[reject]` The serving-path predicate now permits a no-op on an already-disabled OcuPilot path -- DW-1351 requires the verdict to be about what the proposal changes, and a payload that changes nothing writes nothing.
  - `[false]` `[reject]` Fail-closed is asserted at one input and fails open at two others -- true of the diff before this pass; the fingerprint gate now refuses a row whose payload it does not cover, and the four legs pin it.
  - `[low]` `[reject]` The seventh code refuses by name-membership rather than by evaluating an effect -- the fail-closed default *is* the effect claim's shape, and it is what the re-open required; an effect evaluation per vendor property is the enumeration it replaced.
  - `[low]` `[patch]` (same root cause as the array-leg row) the array-schema assertion moved to a probe surface, so no shipped tool exercises an array shape -- the set's own array leg is added; the schema generator's array path stays pinned through `WriteExclusion`.

## Design Notes

**Governing ADs (Rule 6).** **AD-10** (the set, its single home in the kernel, effect-not-verb, never
advertised, governance can never enable it), **AD-34** (the atomic transition the verdict is reached
inside), **AD-40** (the gate is on the write, not on the tool call that minted the proposal). Also in
force: AD-6 (the executed write is the stored one), AD-4 (the payload is the complete merged property
set -- see below), AD-8, AD-9 (why the verdict is not reached deeper), AD-12/AD-39 (one envelope, one
reason per code), AD-13 (the scoped triple), AD-22 (Release 1's safety is this set plus confirmation),
AD-2/AD-27 (the target is read through the port, never by naming an `%Api.Admin.*` class).

**Why the verdict compares against a live read, not against the payload alone.** AD-4 makes the payload
the **complete** property set, so `AutheEnabled`, `Resource` and `DispatchClass` are present in every
web-application payload whether or not they change. A predicate that fired on presence would refuse
every web-application write, Story 5.8's demo included. The effect is therefore *the difference between
the payload and the target as the instance holds it now*, which is also what AD-10 means by "evaluated
against the resolved target": the set resolves the tool to its endpoint and id parameter through the
registry and reads the target itself, once, through `PortClass()`.

**Where the verdict sits, and why not deeper.** It sits where Story 5.3 put the seam:
`Confirm.Transition`, inside the confirm transition, before the claim commits and before the vendor
PUT. It is **not** moved inside `Propose.GuardedClaimAndClose`'s per-target lock, because that method
runs in `Kernel/State`'s escalated frame and AD-9 forbids re-entering a port or a tool from inside
one. The window this leaves is the ordinary one AD-34 already accepts -- the vendor call follows
`TCOMMIT` by design -- and the fingerprint re-read a few lines later refuses any target that moved.
A proposal that trips both answers the prohibition, per `Write.cls`'s "a proposal that trips two
conditions answers the earlier one".

**Why two fields are excluded and two are not.** Every change to `MatchRoles` or `DispatchClass` is
prohibited -- one grants privilege, the other decides what code answers at a URL -- so they are absent
from the tool set, which is AD-10's title. `AutheEnabled` and `Resource` stay settable because only
*weakening* them is an effect AD-10 forbids: adding the unauthenticated bit (64), and clearing a
resource that was set. Hardening stays available, and Story 5.8's "give it the `%Development` resource"
is exactly the allowed direction. That asymmetry is the AD's "by effect, not by verb" in one place.

**Why an uncovered entity type is refused wholesale.** AD-10's set also covers users, roles, resources,
services, processes and databases -- none of which Release 1 can yet target, because
`webapp.list.update` is the only write tool. Writing predicates against payload shapes that do not
exist yet would be speculative and unfalsifiable. Instead the set refuses every write against an entity
type it does not evaluate (`PROHIBITED.UNCOVERED`), which is strictly stronger than the enumerated
effects for those types, and `UncoveredWriteTools()` plus its test makes the next story's tool
impossible to ship without its predicates. That is the compliance argument for the AC's enumeration:
each listed effect is refused, by a named predicate where the target is reachable and by the
uncovered-type refusal where it is not.

**Consumes:** `Kernel.Proposal.Confirm` (the seam and its 403 rendering, Story 5.3);
`Screen.Tool.Registry` (tool -> class -> descriptor -> entity type); `Port.AdminPort` (the live read);
`Kernel.State.WebApp` + `Install.Roster` (which applications serve OcuPilot); `Kernel.EntityRef`;
`Kernel.Proposal.Mint.Display` (rendered-value comparison). Read `Kernel.State.WebApp` first and let
its escalated frame unwind before the port read -- never nest the two (AD-9).

**Consumed-by:** Story 5.8 (its "the target is one of OcuPilot's own web applications ... refused on
the instance and never advertised as a tool" AC is this set's `PROHIBITED.SERVINGPATH` and the two
excluded fields); Stories 5.9-5.13, each of which must add its entity type's predicates to this one home
before its write tool can register (`user`, `role`, `resource`, `service`, `process`, `database`);
Story 5.6 (a refused write emits no marker, because nothing is written).

**Why a row whose diff names nothing is no longer producible (DW-1354).** The set is scoped to the
stored diff, so a row whose payload weakens the live target while its diff names nothing would be
passed over. Nothing can produce one. The mint is the only writer of a proposal row, its own `Merge`
records a diff row for every field it moves, and since DW-1353 a stream write it could not complete
answers an error and saves no row at all -- so a stored payload and a stored diff are written
together or not at all. What remains is a direct write into OcuPilot's protected storage, which AD-9
(nothing outside `Kernel/State` holds the escalation) and AD-33 (that database is reached only
through those methods) put outside the threat model; behind that, AD-6's fingerprint gate still
refuses any row whose payload its own digest does not cover. The closure is therefore a composition
of gates already here, not a third mechanism: the set is not keyed on the stored arguments, which
this story's intent contract forbids, and the fingerprint gate did not move ahead of the seam.

**DW-1207 (floor-blocking, must-ship).** Addressed by the three matrix rows naming it, the fourth
acceptance criterion, and the `DispatchClass` exclusion. Not declined, not re-owned.

## Verification

**Slot A. Every IRIS MCP call carries `server: "ocupilot-slot-a"`. Every write-path or
privilege-touching check runs on the throwaway `ocupilot-ci` (52776/1975) -- never on `ocupilot`, never
on any `ocupilot-slot-*` container. Tear down only a throwaway whose `up` this transcript names.**

**Commands:**

- `uv run scripts/check-objectscript.py <staged paths>` -- expected: no findings. The new class holds no
  escalation and names no `Security.*` class, so `check_escalation_containment` and
  `check_state_package_isolation` are unaffected; a finding is a design error, not a license to edit
  `scripts/`.
- `bash scripts/lint-docs.sh` -- expected: clean.
- `cd ui && npm run build && npm test` -- expected: green, unchanged. No client file and no generated
  field list changes; `field-lists.mjs --check` reads `Classification.cls`, which this story leaves
  alone.
- `bash scripts/ci-throwaway.sh --dir /tmp/ocupilot-ci --project ocupilot-ci --web 52776 --super 1975`
  -- expected: `ocupilot-ci` healthy.
- Load and compile **one file at a time** to its exact relative path with the IRIS MCP tools, then
  `grep` the loaded source inside the container before believing a red or a green.
- `iris_execute_tests`, **one class per tool call**, each landed in `%UnitTest_Result` before the next:
  `OcuPilot.Test.Prohibited`, `…ProhibitedByEffect`, `…ProhibitedRoute`, then the shipped
  `…ProposalConfirm`, `…ConfirmRoute`,
  `…ProposalWrite`, `…Proposal`, `…ProposalRace`, `…ProposalClose`, `…ProposalWire`, `…ToolWrite`,
  `…ToolRoundTrip`, `…ToolSetFull`, `…ToolEmit`, `…ToolDispatch`, `…WebApp`, `…ReadTool`,
  `…Envelope`, `…Wire` -- nineteen classes.
  `…ProposalMint`, `…Dispatch` and `…WriteExclusion` are fixtures, not test classes: they declare no
  test method, and the runner fails an invocation that names one. Confirm the totals with the
  `%UnitTest_Result` SQL probe (numeric
  run index, joined through `TestMethod`) before reporting any suite green; a client-side timeout is
  not a failed run and is never re-submitted.
- `bash scripts/smoke.sh --container ocupilot-ci --user _SYSTEM --password SYS` -- expected: every check
  executed and passing; zero executed checks is a failure.

**Rule 19 mutations** -- each applied alone on `ocupilot-ci` (source copied file by file into its
mount, `grep`ed inside the container, loaded and recompiled across `OcuPilot.*`), observed red on its
named test, reverted, and the throwaway's tree confirmed byte-identical to the worktree afterwards
(`diff` per file, plus `git status --short` and `git diff --stat` unchanged).

- AC1, and AC4's write-path half: `Prohibited.WebApplication`'s `AutheEnabled` arm replaced by `If 0`
  -> runs 204-205 `Prohibited.TestAWeakenedAuthenticationIsRefused` and
  `ProhibitedRoute.TestAWeakenedAuthenticationIsRefusedOverTheWire` red; the HTTP leg confirmed and
  the probe application moved, so its untouched clause reddened with the code.
- AC1: `Write.ProhibitedClass()` back at `""` -> runs 163-165 red: all three `ProhibitedRoute` legs,
  `ProposalConfirm.TestTheProhibitedSeamIsCalledOnceBeforeThePortCall`, and
  `Prohibited.TestTheSetHasOneHomeAndOneSentencePerCode` (the reason no longer resolves). It does not
  reach AC5's test, whose confirm fixture answers an armed set rather than falling through.
- AC2: `PROHIBITED.DISPATCH` copied into `Kernel/Governance/Gate.cls` -> run 194
  `Prohibited.TestTheSetHasOneHomeAndOneSentencePerCode` red, naming the offending class.
- AC3, and AC4's 400 half: `DispatchClass` added to `WebAppUpdate`'s `PERMITTEDFIELDS` and dropped
  from its `ExcludedFields()` -> run 273
  `Prohibited.TestNoWriteToolAdmitsAnAlwaysProhibitedField` red on the schema, the settable list, the
  reviewed-few floor, the 400 and the mints-nothing clause; the unrefused call minted a row, removed
  afterwards. The positive list is what admits a field now, so dropping the name from
  `ExcludedFields()` alone no longer advertises it.
- AC3: a probe write tool registered over an uncovered entity type (`database`) -> run 168
  `Prohibited.TestNoRegisteredWriteToolHasAnUncoveredEntityType` red. It had to sit outside
  `OcuPilot.Test.`, which `Registry.ExcludedPackage()` skips; the probe class was deleted from the
  mount and from the instance afterwards and `UncoveredWriteTools()` re-read empty.
- AC5: the prohibited call removed from `Confirm.Transition` -> run 192
  `Prohibited.TestGovernanceCannotEnableAProhibitedWrite` red on the refusal and on the gate-order
  floor, and run 193 all three `ProhibitedRoute` legs red -- each confirm succeeded and wrote.
- AC6: the `SERVINGPATH` sentence removed from `Prohibited.ReasonFor()` -> run 169
  `Prohibited.TestTheSetHasOneHomeAndOneSentencePerCode` red.
- DW-1347: the serving-path predicate narrowed back to the enabled flag
  (`If pServes && $Data(pChanged("Enabled"))`) -> run 263
  `ProhibitedByEffect.TestAChangeToOcuPilotsOwnApplicationIsRefused` red -- the `NameSpace` and
  `Path` legs answer the reviewed-few code instead and the `Description` leg is not refused at all.
- DW-1347: `ServesOcuPilot`'s `Kernel.State.WebApp` lookup dropped -> run 264 the same test red on
  the recorded-path leg alone, which is the only leg that branch answers.
- `Prohibits`'s uncovered arms answer `pProhibits = 0` -> run 197
  `Prohibited.TestAnUncoveredEntityTypeIsRefusedWholesale` red.
- `Registry.ListTools` reports every tool `read` -> run 198 both write-tool floors red, in
  `TestNoRegisteredWriteToolHasAnUncoveredEntityType` and `TestNoWriteToolAdmitsAnAlwaysProhibitedField`.
- `Prohibited.Target` reads every failed read as absence -> run 199
  `Prohibited.TestAnUnreadableTargetFailsClosedAndAMissingOneDoesNot` red on the port-fault leg alone.
- `Prohibited.PortClass()` pointed at the fixture -> run 200
  `Prohibited.TestTheSetHasOneHomeAndOneSentencePerCode` red.
- `WebAppUpdate` declaring `DispatchClass` a secret argument -> run 201
  `Prohibited.TestNoWriteToolAdmitsAnAlwaysProhibitedField` red.
- DW-1345 and DW-1346: the reviewed-few loop deleted from `Prohibited.WebApplication` -> run 261
  `ProhibitedByEffect.TestAFieldTheReleaseHasNotReviewedIsRefused` red on all 21 unreviewed
  properties, the two invented ones among them, and on the over-the-confirm leg. `DispatchClass`
  stays green there, which is its own predicate answering.
- DW-1346: `Prohibited.ClearsUnauthenticatedOnly` replaced by the subset reading -- permitted iff the
  payload sets no bit the target does not -- -> run 297
  `ProhibitedByEffect.TestOnlyClearingUnauthenticatedAccessIsProposable` red on the two legs that
  reading permits: turning two-factor password authentication off (2097184 -> 32) and leaving no way
  in at all (32 -> 0).
- DW-1351: `Prohibited.Changed` ignoring the diff and comparing every payload member -> run 265
  `ProhibitedByEffect.TestAProposalIsJudgedOnWhatItChanges` red, answering the misleading 403
  `PROHIBITED.AUTHORIZATION` DW-1351 names and leaving the row live.
- DW-1351's other half: `Prohibited.Changed` trusting the diff, with
  `..Rendered(pPayload, tField) = ..Rendered(pTarget, tField)` dropped -> run 299
  `ProhibitedByEffect.TestAProposalIsJudgedOnWhatItChanges` red on its last leg, which is what pins
  the live comparison: a field the diff names whose value the instance already holds is refused
  403 `PROHIBITED.AUTHORIZATION`.
- AD-6, the fingerprint's cover of the stored payload: the second comparison removed from
  `Confirm.FingerprintMatches` -> run 295
  `ProhibitedByEffect.TestARowWhosePayloadItsFingerprintDoesNotCoverIsRefused` red on all four legs,
  each confirm succeeding and reaching the port.
- The reviewed-few floor in the other direction: `Timeout` added to
  `Prohibited.PermittedChangeFields` alone -> run 298
  `Prohibited.TestNoWriteToolAdmitsAnAlwaysProhibitedField` red on the converse assertion, naming the
  field the tool does not advertise.
- The diff row's own key: `Mint.Merge` writing `name` instead of `field` -> run 300
  `ProhibitedByEffect.TestAProposalIsJudgedOnWhatItChanges` red, which is what ties `Changed()`'s
  reader to the mint's writer.
- `NameSpace` added to `WebAppUpdate`'s `PERMITTEDFIELDS` -> run 266
  `Prohibited.TestNoWriteToolAdmitsAnAlwaysProhibitedField` red on the reviewed-few floor, which is
  what keeps the tool's admitted names and the set's reviewed few from drifting apart.
- the positive filter deleted from `Screen.Tool.Write.FieldRows` -> run 267
  `ToolWrite.TestTheSchemaIsDerivedFromTheClassifiedFieldList` red on the shipped tool advertising a
  field the set has not reviewed.

- DW-1352: `ServesOcuPilot` comparing both sides raw again, with the two
  `Prohibited.NormalizedPath` calls removed -> run 307
  `ProhibitedByEffect.TestAChangeToOcuPilotsOwnApplicationIsRefused` red on all eleven
  non-canonical spellings and green on every canonical one, which is the bypass itself.
- DW-1352: `Prohibited.NormalizedPath` reduced to the case fold, with the trailing-slash loop
  dropped -> run 308 `ProhibitedRoute.TestTheSetNormalizesAPathTheWayTheInstanceResolvesIt` red on
  the six slash-suffixed spellings, each of which the shipped port resolved to the roster path.
- DW-1352, the other direction: `Prohibited.NormalizedPath` stripping a leading slash as well ->
  run 309 the same test red on the three leading-slash-less spellings, which the port resolves to
  nothing -- so the agreement is pinned where the set must say no as well as where it must say yes.
- DW-1353: `Propose.GuardedMint` writing its diff stream with a bare `Do` again -> run 310
  `ProhibitedByEffect.TestAMintChecksEachStreamWriteOrStoresNoRow` red on all three of that field's
  source legs.
- DW-1353: the same write storing `$Get(pValues("diff")) _ " "` -> run 311 the same test red on the
  round trip alone, which is what pins that the three texts a mint is handed are the three stored.
- DW-1354: `Mint.Merge` pushing only its first diff row (`If tChanged = 0 Do pDiff.%Push(tRow)`) ->
  run 312 `ProhibitedByEffect.TestAProposalIsJudgedOnWhatItChanges` red on the producer legs, which
  are what make "a payload that changes something cannot be stored beside a diff that names
  nothing" falsifiable.

**Manual check, performed:** `ProhibitedRoute.Weakened` reads the probe application's complete
property set back through the shipped port before and after each confirm and asserts it equal, and
the seeded row carries the digest the confirm re-computes, so the 403 is the only gate left between
that confirm and a vendor write.

**QA (2026-09-20).** `src/OcuPilot/Test/ToolWrite.cls` (QA, existing file) gained two methods
closing the one gap left in AC3/AC4's mints-nothing rigor: `TestNoWriteToolAdmitsAnAlwaysProhibitedField`
already proved `DispatchClass` mints nothing against a real target, but `MatchRoles` (the other
always-prohibited field) and an unreviewed-but-otherwise-ordinary field were only checked at the
schema level, with no mint-count assertion against a live application. Every other leg the QA
prompt named -- the confirm-side HTTP refusal for `Resource`, `AutheEnabled` and `DispatchClass`,
byte-for-byte, over the wire -- is already `ProhibitedRoute`'s; the Review Triage Log's own
`[reject]` on adding `MatchRoles` as a fourth HTTP leg stands, so no wire-level test was added for
it here.

- `TestARoleGrantIsRefusedAndMintsNothingAgainstARealTarget` -- mutation: classify `MatchRoles`
  ordinary and give it a top-level field-list row (as `TestARoleGrantIsRefusedAsAnUnknownArgument`
  already names). Applied as a stand-in on `ocupilot-ci` -- `Write.View`'s own argument check
  disabled (`If 0` in place of `If $$$ISERR(tValidSC)`), which is the shared gate both mutations
  bypass -- red on both new methods (runs 333-334, refusal, HTTP and code assertions, and the mint
  count: two real proposal rows landed against `/ocupilot`), reverted (reloaded from source and
  recompiled, not merely recompiled -- a first revert attempt recompiled the still-cached mutated
  dictionary and stayed red), re-verified green (run 336, 11/11), stray rows deleted, `diff -rq`
  against the worktree and `git status --short`/`git diff --stat` confirmed clean.
- `TestAnUnreviewedFieldIsRefusedAndMintsNothingAgainstARealTarget` -- same mutation and run,
  covering `EventClass` (ordinary-classified, outside `PERMITTEDFIELDS`) as the distinct
  fail-closed-by-positive-list path AD-10's second half relies on.

## Auto Run Result

Status: done
Blocking condition: none

**Change (rework 2, the three open items).** DW-1352: the serving-path predicate compares a target's
id and the roster's paths through `Prohibited.NormalizedPath` -- lower case, with every trailing
slash removed -- which is what the instance itself does. Probed on `ocupilot-ci` rather than
recalled: `Security.Applications.Exists` and the vendor `WebApp.App` `GET` both answer the real
`/api/ocupilot` for `/API/OcuPilot`, `/api/ocupilot/` and `/API/OCUPILOT///`, and 404 for
`api/ocupilot`, `/api//ocupilot`, `/api/ocupilot/.` and a trailing space, so the normalization goes
exactly that far and no further. Install's own record is looked up by the normalized path and, where
that differs, by the id as it came, because that store's lookup is an exact compare. Before this the
endpoint reached OcuPilot's own API while the predicate read the target as somebody else's, so a
confirmed write could disable OcuPilot through a re-cased or slash-suffixed id, which AD-38 makes
unrecoverable. DW-1353: `GuardedMint` takes the status of each of its three stream writes and saves
no row on a failure. DW-1354: closed by composition and written out in `## Design Notes` -- no third
mechanism, the set is not keyed on the stored arguments, and the fingerprint gate did not move.

**Files changed.**

- `src/OcuPilot/Kernel/Proposal/Prohibited.cls` -- `NormalizedPath`, the normalized compare in
  `ServesOcuPilot`, and `Recorded` so the record store is asked for both spellings.
- `src/OcuPilot/Kernel/State/Propose.cls` -- the three stream writes are status-checked.
- `src/OcuPilot/Test/ProhibitedByEffect.cls` -- each roster and recorded path driven under three
  spellings the instance resolves, a floor that the roster's own spellings are already canonical,
  the mint's stream-write test, and DW-1354's producer legs.
- `src/OcuPilot/Test/ProhibitedRoute.cls` -- the set's normalization compared against the shipped
  port's own resolution over six spellings, read-only.

**Verified.** `check-objectscript.py` 0 problems over 557 files; `lint-docs.sh` clean; `ui`
`npm run build` green and `npm test` 1087 + 687. On the throwaway `ocupilot-ci`, the nineteen
classes one at a time through `ui/tools/ci-runner.mjs`, runs 313-331: 221 tests, 0 failed, 0 probe
leftovers, 0 overlaps, 0 foreign runs, confirmed against `%UnitTest_Result` (classes 19, total 221,
passed 221, failed 0 over those run indices). `smoke.sh --container ocupilot-ci`: executed 45,
passed 45, failed 0, pending 2, skipped 0. Each mutation line above was applied alone in the
throwaway's mount, grepped inside the container, loaded with its subclasses recompiled, observed red
on its named test and reverted; `diff -rq src/ /tmp/ocupilot-ci/src/` reports no differences
afterwards and the worktree carries only the four files above.

**Follow-up review recommended: true.** This pass patched two `high` entries. The named unverified
risk is the widened refusal: `SERVINGPATH` now answers a spelling that previously earned the
reviewed-few code or no refusal at all, so a caller addressing an OcuPilot application by a
non-canonical id is refused where it was not. That is the intent, and no shipped caller does it, but
it is a behavior change beyond the three items. `GuardedMint` likewise now answers an error instead
of saving a row when a stream write fails, on a path no input can reach.

**Residual risks.** Two spellings of one application are still two scoped targets to the claim, so
AD-34's per-target lock and sibling cancel do not cover a re-cased id; the fingerprint gate bounds
that to a 409 and a row left live rather than canceled. That, the record store's exact-compare
lookup, and the source-level half of the DW-1353 pin are in `deferred:`. The four items the lead
routed elsewhere -- the narrowed schema on the decision sheet, and DW-1356 to DW-1358 at
`range-end-cleanup` -- are not in that list and are not this pass's.
