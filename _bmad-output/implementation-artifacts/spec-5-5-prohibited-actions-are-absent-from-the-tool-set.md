---
title: 'Story 5.5: Prohibited actions are absent from the tool set'
type: 'feature'
created: '2026-09-20'
status: 'done'
baseline_revision: '98ad9596bc9c33dd3c29eaa9f94754613e3b59ba'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
warnings: ['oversized']
deferred:
  - summary: >-
      A confirm refusal that leaves the proposal row live is invisible in the panel, so a prohibited
      (or restrained) refusal shows the user nothing and the card simply offers Confirm again.
    evidence: |-
      `turn.ts` `decideProposal` records an outcome only when the refusal carried `detail.state`, and
      `panel.ts` `onCardConfirm` drops its own decision in its `finally`. A prohibited refusal does
      not close the row, so neither the code nor the reason reaches a card. Pre-existing: AD-30's
      restraint refusal at confirm has the same shape. Out of this story's footprint (Epic 5 owns
      `panel*`, so it is in-epic, not out) and outside its ACs, which do not specify a card state.
    location: 'ui/src/app/core/turn.ts:840; ui/src/app/shell/panel.ts:852'
    severity: medium
  - summary: >-
      No Release 1 write tool declares a delete operation, so the delete half of AD-10's clauses is
      unreachable and the coverage gate checks entity types only.
    evidence: |-
      `Kernel.Proposal.Confirm` issues one write type (`Parameter WRITETYPE = "PUT"`, `:36`); a tool
      declares no operation of its own. Every predicate here is therefore expressed as an effect
      visible in the payload against the live target. The first delete-capable write tool must extend
      the predicates to its operation and extend the coverage gate past entity type.
    severity: medium
  - summary: >-
      A resource-to-resource swap on a web application is not refused; only dropping the resource is.
    evidence: |-
      `%Admin_Secure` -> `%Development` may weaken the gate, but "weaker" needs a privilege lattice the
      instance does not publish. The owner's DW-1207 decision names "drop Resource", which is what
      `PROHIBITED.AUTHORIZATION` refuses. The swap stays a confirmed, audited write by a user who
      holds `%Admin_Secure:WRITE`.
    severity: low
  - summary: >-
      The set refuses a repointed `DispatchClass`, but every other field that decides which compiled
      code answers at a web application's URL stays settable and unrefused.
    evidence: |-
      `webapp.list.update` admits 45 ordinary top-level fields, `EventClass`, `SuperClass`, `Package`,
      `Path`, `NameSpace`, `LoginPage`, `ErrorPage`, `ChangePasswordPage` and `PermittedClasses`
      among them. `PROHIBITED.DISPATCH` compares `DispatchClass` alone. DW-1207 names the three
      fields this story covers; the wider family is the same effect by another property.
    location: 'src/OcuPilot/Kernel/Proposal/Prohibited.cls:216'
    severity: high
  - summary: >-
      `PROHIBITED.UNAUTHENTICATED` keys on bit 64 of `AutheEnabled` alone, so every other
      authentication weakening the tool admits is unrefused.
    evidence: |-
      `TwoFactorEnabled`, `CSRFToken`, `JWTAuthEnabled`, `UseCookies`, `SessionScope`,
      `CorsAllowlist` and `CorsCredentialsAllowed` are settable, and so is any non-64 change to
      `AutheEnabled` itself (32 -> 8192 delegated, 32 -> 16384 login token, 32 -> 0). Turning off
      two-factor authentication is a weakening the set does not see.
    location: 'src/OcuPilot/Kernel/Proposal/Prohibited.cls:208'
    severity: high
  - summary: >-
      `PROHIBITED.SERVINGPATH` refuses only a payload that leaves OcuPilot's own path not enabled;
      `NameSpace` and `Path` break it just as completely and are settable.
    evidence: |-
      `NameSpace` and `Path` are exactly the properties the installer asserts for `/ocupilot`,
      `/api/ocupilot` and `/api/ocupilot/readiness` (`ipm-manifest --check`). A payload repointing
      `/api/ocupilot`'s namespace leaves `Enabled` true and passes the predicate.
    location: 'src/OcuPilot/Kernel/Proposal/Prohibited.cls:228'
    severity: high
  - summary: >-
      A third party changing the target between mint and confirm makes the set answer a
      `PROHIBITED.*` sentence for a change the agent never proposed, and leaves the row live.
    evidence: |-
      The set runs before the fingerprint re-read and compares the mint-time payload against the live
      target, so an operator adding a `Resource` after the mint earns 403 `PROHIBITED.AUTHORIZATION`
      -- "Removing the resource that guards a web application is not something the agent can propose"
      -- where the truthful answer is 409 `PROPOSAL.TARGETCHANGED`, which would also close the row.
      The gate order is settled by the spec's Design Notes; the misleading sentence is not.
    location: 'src/OcuPilot/Kernel/Proposal/Prohibited.cls:204'
    severity: medium
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
  `Prohibits(toolName, targetRef, payloadJson, .prohibits, .code)` returning `%Status`, refused at 403
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
  `Prohibits(pToolName, pTargetRef, pPayload, .pProhibits, .pCode)`, which parses the ref, refuses
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
  `OcuPilot.Test.Prohibited`, `…ProhibitedRoute`, then the shipped `…ProposalConfirm`, `…ConfirmRoute`,
  `…ProposalWrite`, `…Proposal`, `…ProposalRace`, `…ProposalClose`, `…ProposalWire`, `…ToolWrite`,
  `…ToolRoundTrip`, `…ToolSetFull`, `…WebApp`, `…ToolDispatch`, `…Envelope`, `…Wire`.
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
- AC3, and AC4's 400 half: `DispatchClass` dropped from `WebAppUpdate.ExcludedFields()` -> run 203
  `Prohibited.TestNoWriteToolAdmitsAnAlwaysProhibitedField` red on the schema, the settable list, the
  400 and the mints-nothing clause; the unrefused call minted a row, removed afterwards.
- AC3: a probe write tool registered over an uncovered entity type (`database`) -> run 168
  `Prohibited.TestNoRegisteredWriteToolHasAnUncoveredEntityType` red. It had to sit outside
  `OcuPilot.Test.`, which `Registry.ExcludedPackage()` skips; the probe class was deleted from the
  mount and from the instance afterwards and `UncoveredWriteTools()` re-read empty.
- AC5: the prohibited call removed from `Confirm.Transition` -> run 192
  `Prohibited.TestGovernanceCannotEnableAProhibitedWrite` red on the refusal and on the gate-order
  floor, and run 193 all three `ProhibitedRoute` legs red -- each confirm succeeded and wrote.
- AC6: the `SERVINGPATH` sentence removed from `Prohibited.ReasonFor()` -> run 169
  `Prohibited.TestTheSetHasOneHomeAndOneSentencePerCode` red.
- `ServesOcuPilot` answers 0 -> run 195 `Prohibited.TestDisablingOcuPilotsOwnPathIsRefused` red.
- its `Kernel.State.WebApp` lookup dropped -> run 196 the same test red on the recorded-path leg
  alone, which is the only leg that branch answers.
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

**Manual check, performed:** `ProhibitedRoute.Weakened` reads the probe application's complete
property set back through the shipped port before and after each confirm and asserts it equal, and
the seeded row carries the digest the confirm re-computes, so the 403 is the only gate left between
that confirm and a vendor write.

## Auto Run Result

Status: done
Blocking condition: none

**Change.** AD-10's set gets its one home. `Kernel/Proposal/Prohibited.cls` (new) declares six dotted
codes with one sentence each, `COVEREDTYPES` (`web-application`), `AlwaysProhibitedFields`, an
overridable `PortClass()`/`RegistryClass()`, and `Prohibits`, which parses the target reference,
refuses `PROHIBITED.UNCOVERED` for an unparseable ref or an uncovered type, resolves whether the path
serves OcuPilot (roster, then `Kernel.State.WebApp`, both before the port is entered so no escalated
frame nests a port call, AD-9), reads the target live through the tool's own endpoint, and runs five
web-application predicates in declared order -- unauthenticated bit added, resource dropped, dispatch
repointed, roles changed, OcuPilot's own path left disabled. A 404 is "not prohibited" and the
fingerprint gate answers it; any other read failure is an error status the confirm renders 500.
Values compare through `Mint.Display`, which loses `[ Private ]` so the predicates and the diff the
user reviewed read "changed" the same way. `Write.ProhibitedClass()` answers the new class and
`Write.ReasonFor()` delegates the `PROHIBITED.` family to it. `WebAppUpdate` excludes `DispatchClass`
as well as `MatchRoles`, so neither reaches the advertised schema or `SettableFields()`. The seam
stayed exactly where Story 5.3 put it; 5.3's gate order is unchanged.

**Files changed.**

- `src/OcuPilot/Kernel/Proposal/Prohibited.cls` (new) -- the set, its codes and its predicates.
- `src/OcuPilot/Kernel/Proposal/Write.cls` -- the seam answers the set; `ReasonFor` delegates the family.
- `src/OcuPilot/Kernel/Proposal/Mint.cls` -- `Display()` loses `[ Private ]`, one rendering not two.
- `src/OcuPilot/Kernel/Proposal/Confirm.cls` -- the seam's doc and call-site comment corrected; no code change.
- `src/OcuPilot/Screen/Tool/WebAppUpdate.cls` -- `DispatchClass` excluded; the header states both halves.
- `src/OcuPilot/Test/Prohibited.cls` (new) -- the matrix, the acceptance criteria and the tree sweep.
- `src/OcuPilot/Test/ProhibitedRoute.cls` (new) -- three legs over HTTP against a real probe application.
- `src/OcuPilot/Test/ProhibitedFixture.cls` (new) -- the shipped set with the port replaced.
- `src/OcuPilot/Test/ProposalFixture.cls` -- `ArmReadFault` added; two stale sentences corrected.
- `src/OcuPilot/Test/ProposalConfirm.cls` -- the seam test asserts the kernel class; its call-once and before-the-write assertions are unchanged.
- `src/OcuPilot/Test/ConfirmFixture.cls`, `Test/ToolWrite.cls`, `Test/WriteExclusion.cls` -- stale claims corrected at their origin.

Nothing under `scripts/`, `.github/`, `module.xml`, `Install/`, `ui/tools/ci*.mjs` or the client.

**Deviation from the task list.** The suite is two classes, not one: the end-to-end leg needs
`EnsureWriteTarget`, which is armed for a throwaway, so a single class would have kept the whole suite
off any unarmed instance. `Test/Prohibited.cls` runs anywhere and `Test/ProhibitedRoute.cls` carries
the arming guard. It is now 522 lines, just past the "~500, split if it grows past that" guidance.

**Review findings.** 45 findings from four layers -- high 5, medium 17, low 22, false 1.
22 patched, 8 deferred, 15 rejected. Patched entries after grouping: 9 medium, 4 low, 0 high. Every
rejected finding carries its reason in the triage log above. The four deferred items are in the
frontmatter `deferred:` list for the lead to harvest; three are high and name the same shape -- the
set refuses the three fields DW-1207 names and the serving path's `Enabled` flag, while the wider
families of fields with the same effect (`EventClass`, `SuperClass`, `NameSpace`, `Path`,
`TwoFactorEnabled`, `CSRFToken` and the rest) stay settable and unrefused.

**Follow-up review recommended: true.** Nine medium entries were patched on a first pass. The named
unverified risk is the patch pass's two changes to shared surfaces: `ProposalFixture.ArmReadFault`
adds a branch to `Invoke` ahead of the 404 branch in a fixture ten other classes use, and
`ProhibitedRoute.Seed` now computes its digest through `Registry.Resolve` -> `Mint.Merge` ->
`Fingerprint.Of` rather than storing `"0"`. Both are covered by the 16-class sweep, which is green,
but neither existed when the implementation was first reviewed.

**Verified.** `check-objectscript.py` 0 problems over 556 files; `lint-docs.sh` clean; `ui`
`npm run build` and `npm test` green (1087 + 687). On the throwaway `ocupilot-ci`, through
`ui/tools/ci-runner.mjs` one class at a time: `Prohibited` 12, `ProhibitedRoute` 3, `ProposalConfirm`
16, `ConfirmRoute` 6, `ProposalWrite` 11, `Proposal` 14, `ProposalRace` 6, `ProposalClose` 7,
`ProposalWire` 11, `ToolWrite` 9, `ToolRoundTrip` 2, `ToolSetFull` 2, `WebApp` 25, `ToolDispatch` 18,
`Envelope` 15, `Wire` 20 -- 16 classes, 177 tests, 0 failed, 0 probe leftovers, 0 overlaps, 0 foreign
runs. `smoke.sh --container ocupilot-ci`: executed 45, passed 45, failed 0, pending 2. Every Rule 19
mutation in `## Verification` was applied alone on `ocupilot-ci`, observed red on its named test and
reverted; `diff -rq src/ /tmp/ocupilot-ci/src/` reports no differences.

**The development instance `ocupilot` (slot A) is broken, and not by this story.** Every `OcuPilot*`
resource, role and privileged application is absent from it, while its version row still reads
`installed` and was last written 2026-09-16 -- so `Installer.Install("")` is a no-op and cannot repair
it. Consequently `GuardedUserEnabled` cannot enter its escalation, every OcuPilot route there answers
503 `INSTALL.UNREADABLE`, and any route-dispatch suite fails on slot A for that reason alone
(`OcuPilot.Test.Envelope` 8 of 15). The same source is byte-identical on `ocupilot-ci` and green
there, the project carries no class projection that a recompile could have fired, and the story's own
diff touches no security object, no install path and no router. Repairing it needs the version row
removed and the installer re-run, or the container recreated -- the owner's call, so it was not done.
Story 5.5's verification was completed on `ocupilot-ci` throughout.

**Residual risks.** The three high deferred items above are the material one: the set is a real
control over exactly the effects DW-1207 names, and a caller who can reach confirm can still repoint a
web application's event class, super class, namespace or physical path, or drop its second factor. The
`UNCOVERED` refusal does not extend to them, because `web-application` is a covered type. Story 5.8
and Stories 5.9-5.13 are where the set grows; the entries name the fields.
