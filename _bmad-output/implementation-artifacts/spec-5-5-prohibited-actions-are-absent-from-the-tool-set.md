---
title: 'Story 5.5: Prohibited actions are absent from the tool set'
type: 'feature'
created: '2026-09-20'
status: 'done'
baseline_revision: '777d484527e4fc695fe62e8ca8fdd970f7f162c1'
review_loop_iteration: 1
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
warnings: ['oversized']
deferred:
  - summary: >-
      A row whose `arguments`, `payload` and `fingerprint` agree with each other but whose `diff`
      names nothing still reaches the port for the four reviewed fields.
    evidence: |-
      `FingerprintMatches` now pins the stored payload to `Merge(live, storedArguments)`, so a forged
      payload can differ from the live target only in a `SettableFields()` name. `Changed` scopes the
      predicates to the diff, so `AutheEnabled` 32 -> 96 behind an empty diff is unrefused. Closing it
      needs the set to key on the stored arguments rather than the diff, or the fingerprint gate ahead
      of the seam -- both settled outside this story (the intent contract forbids the first, the lead
      the second).
    location: 'src/OcuPilot/Kernel/Proposal/Prohibited.cls:304'
    severity: medium
  - summary: >-
      `Propose` discards the status of its three stream writes, so a failed `Diff.Write` stores a row
      with a payload and no diff.
    evidence: |-
      `Do tRow.Diff.Write($Get(pValues("diff")))` -- and the same for `Arguments` and `Payload`. The
      row then saves and the set has nothing to scope by. Pre-existing shape, out of this story's
      footprint (`Kernel/State/**`).
    location: 'src/OcuPilot/Kernel/State/Propose.cls:200'
    severity: medium
  - summary: >-
      `ServesOcuPilot` matches the roster's paths with an exact string compare and is now the first
      predicate, so a differently-spelled id that the vendor endpoint still resolves would read as
      not-OcuPilot's.
    evidence: |-
      `If $IsObject(tApp) && (tApp.path = pPath)` -- no case or trailing-slash normalization. Settled
      by one probe: ask the `WebApp.App` endpoint for `/API/OcuPilot` and see whether it answers the
      real application. Every test drives the roster's exact spellings, so nothing pins it either way.
    location: 'src/OcuPilot/Kernel/Proposal/Prohibited.cls:382'
    severity: medium (unverified)
  - summary: >-
      The advertised schema narrowed from forty-five fields to four, which is a product-facing
      reduction in what the agent may propose about a web application.
    evidence: |-
      It is the consequence of AD-10's title once every change to the unreviewed fields is prohibited,
      and it is fail-closed against a vendor property a later build adds. A later story that needs
      `Timeout` or the CORS list adds the name to `PermittedChangeFields` and to `PERMITTEDFIELDS`
      together; the reviewed-few floor now fails the suite if it adds only one. The owner may want a
      wider reviewed set.
    location: 'src/OcuPilot/Screen/Tool/WebAppUpdate.cls:48'
    severity: medium
  - summary: >-
      Disabling any web application that is not OcuPilot's own -- `/csp/sys`, `/api/atelier` -- is
      proposable.
    evidence: |-
      `Enabled` is one of the four reviewed fields and carries no asymmetric predicate, and the
      serving-path predicate covers only paths the roster declares or install recorded. AD-38's
      argument is about OcuPilot's own reachability, so this is by design; whether the Management
      Portal's own application should be refused too is a product call.
    location: 'src/OcuPilot/Kernel/Proposal/Prohibited.cls:124'
    severity: medium
  - summary: >-
      `PROHIBITED.UNCOVEREDFIELD` names no field, and the refusing field is picked in collation
      order, so a multi-field diff does not tell the user which setting was refused.
    evidence: |-
      The sentence is one per code (AD-39) and the loop walks `$Order(pChanged(tField))`. Naming the
      field would mean carrying a detail alongside the code, which the seam's contract does not have;
      `Confirm.Transition` already does exactly that for the privilege refusal's `failedPair`.
    location: 'src/OcuPilot/Kernel/Proposal/Prohibited.cls:279'
    severity: low
  - summary: >-
      `Screen.Registry.ToolFieldRows` still computes a write tool's settable fields from the
      generated entry without the positive list, so it over-approximates by forty-one names.
    evidence: |-
      The direction is conservative -- it would refuse a declaration naming a field the tool no longer
      admits -- so nothing is unsafe; its refusal message's wording is now inaccurate. Out of this
      story's footprint (`Screen/Registry.cls`). reopen_if=a descriptor declaration is refused for a
      field `webapp.list.update` does not advertise.
    location: 'src/OcuPilot/Screen/Registry.cls:2010'
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

**Open after the lead's harvest gate (rework iteration 1) -- work ONLY these:**

- [x] `[Review]` **DW-1345 (high).** `PROHIBITED.DISPATCH` compares `DispatchClass` alone, while
  `EventClass`, `SuperClass`, `Package`, `Path`, `NameSpace`, `LoginPage` and `ErrorPage` are
  settable and decide just as completely which compiled code answers at the URL. AD-10's Rule is
  **by effect, not by verb**: express the family as one predicate over "what answers here", so a
  new vendor property with that effect is covered by the predicate's shape rather than by having
  been enumerated. Verified by the lead: `Screen/Tool/FieldLists.cls:519-549`.
- [x] `[Review]` **DW-1346 (high).** `PROHIBITED.UNAUTHENTICATED` keys on bit 64 of `AutheEnabled`
  alone. `TwoFactorEnabled`, `CSRFToken`, `JWTAuthEnabled` and `UseCookies` are settable, and any
  non-64 `AutheEnabled` change (32 -> 0 among them) passes. Express authentication weakening as the
  effect it is, in the same by-effect shape.
- [x] `[Review]` **DW-1347 (high).** `PROHIBITED.SERVINGPATH` refuses only a payload that leaves
  OcuPilot's own path not enabled. `NameSpace` and `Path` are exactly what the installer asserts for
  `/ocupilot`, `/api/ocupilot` and `/api/ocupilot/readiness` (lead-verified on `ocupilot-slot-a`:
  all three read `NameSpace` `HSCUSTOM`), and a payload repointing either leaves `Enabled` true and
  passes. AD-38 makes an unreachable OcuPilot an unrecoverable instance, so this one is the
  serving-path predicate's whole point.
- [x] `[Review]` **DW-1351 (med).** The set compares the mint-time payload against the live target, so a
  third party adding a `Resource` after the mint earns 403 `PROHIBITED.AUTHORIZATION` -- a sentence
  about a change the agent never proposed -- and the row stays live. Report a prohibition only for a
  field the proposal actually **changes** relative to the target it was minted against, and let the
  fingerprint gate answer a target that moved with 409 `PROPOSAL.TARGETCHANGED`. **Do not reorder the
  gates**: the verdict stays where Story 5.3 put the seam, before the restraint verdict, per the
  Design Notes' AD-9 argument.

Each of the four needs a pinning test and a `mutation:` line in `## Verification`, demonstrated in
this pass (Rule 19). The three high items are **not** closed by enumerating today's vendor property
names in a list: a test that adds a plausible new property with the same effect and expects a refusal
is what makes the by-effect claim falsifiable.

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

**Manual check, performed:** `ProhibitedRoute.Weakened` reads the probe application's complete
property set back through the shipped port before and after each confirm and asserts it equal, and
the seeded row carries the digest the confirm re-computes, so the 403 is the only gate left between
that confirm and a vendor write.

## Auto Run Result

Status: done
Blocking condition: none

**Change (rework 1, the four open items).** The set now **permits by name and refuses by shape**.
`PermittedChangeFields(pType)` names the four web-application settings this release has reviewed
(`AutheEnabled`, `Description`, `Enabled`, `Resource`); every other changed field is refused
`PROHIBITED.UNCOVEREDFIELD`, a seventh code with its own sentence. That is what closes DW-1345 and
DW-1346 without enumerating vendor property names: `EventClass`, `SuperClass`, `Package`, `Path`,
`NameSpace`, the page and WSGI properties, `TwoFactorEnabled`, `CSRFToken`, `JWTAuthEnabled`,
`UseCookies`, `SessionScope`, `GroupById` and `Timeout` are all refused, and so are two properties
this build's endpoint does not carry at all. `AutheEnabled`, the one authentication field that stays
proposable, is judged by `ClearsUnauthenticatedOnly`: the only payload it permits is the target's own
mask with the unauthenticated bit cleared, because the mask carries strength modifiers as well as
mechanisms and a subset test reads two-factor backwards in both directions. That refuses 32 -> 0,
32 -> 8192, 32 -> 16384, 1056's undefined bit and two-factor either way.
DW-1347: a web application OcuPilot itself is
served by is refused **any** change (`SERVINGPATH`), so `NameSpace` and `Path` are covered by the
predicate being over the application rather than over a property list; the end-state "leaves it not
enabled" clause is gone, since the payload that carries it proposes no change. DW-1351: `Prohibits`
takes the stored diff, and `Changed` answers the fields the diff names **and** whose payload value
differs from the live target, so a field a third party moved after the mint is answered 409
`PROPOSAL.TARGETCHANGED` by the fingerprint gate rather than 403 by the set. AD-10's other half
follows: `Screen.Tool.Write` gains a positive `PermittedFields()` filter and `WebAppUpdate` declares
the same four names, so the advertised schema went from 45 fields to 4 and a vendor property a later
build adds reaches no schema until somebody reviews it. The seam stayed where Story 5.3 put it and
5.3's gate order is unchanged.

**Files changed.**

- `src/OcuPilot/Kernel/Proposal/Prohibited.cls` -- the reviewed-few rule,
  `ClearsUnauthenticatedOnly`, `Changed`, the serving-path predicate, the seventh code; `Unauthenticated` and `Enabled` are gone with the
  readings they served, and `UNAUTHENTICATEDBIT` is the one bit `ClearsUnauthenticatedOnly` permits a
  payload to change.
- `src/OcuPilot/Kernel/Proposal/Confirm.cls` -- the seam is handed the stored diff, and
  `FingerprintMatches` requires the stored payload to digest to the row's own fingerprint (AD-6).
- `src/OcuPilot/Screen/Tool/Write.cls` -- `PermittedFields()` and its filter in `FieldRows`.
- `src/OcuPilot/Screen/Tool/WebAppUpdate.cls` -- `PERMITTEDFIELDS`, and a header that says which
  families the four leave out.
- `src/OcuPilot/Screen/Tool/Classification.cls` -- one sentence separating `ordinary` from "the tool
  admits it"; the reviewed XData is unchanged.
- `src/OcuPilot/Test/ProhibitedByEffect.cls` (new) -- the four pinning tests.
- `src/OcuPilot/Test/ProhibitedFixture.cls` -- the suite's shared builders, so neither test class
  duplicates them and `Test/Prohibited.cls` stays inside the ~500-line guidance.
- `src/OcuPilot/Test/Prohibited.cls`, `…/ProhibitedRoute.cls` -- every seeded row carries the diff a
  mint would have recorded; the reviewed-few floor is asserted per write tool.
- `src/OcuPilot/Test/ProposalFixture.cls`, `…/ToolWrite.cls`, `…/WriteExclusion.cls` -- the fixture's
  seam signature, and the array-shape assertion moved to the probe tool that still admits one.

**Verified.** `check-objectscript.py` 0 problems over 557 files; `lint-docs.sh` clean; `ui`
`npm run build` and `npm test` green (1087 + 687). On the throwaway `ocupilot-ci`, one class per
call through `ui/tools/ci-runner.mjs` and confirmed against `%UnitTest_Result`: `Prohibited` 11,
`ProhibitedByEffect` 5, `ProhibitedRoute` 3, `ProposalConfirm` 16, `ConfirmRoute` 6, `ProposalWrite`
11, `Proposal` 14, `ProposalRace` 6, `ProposalClose` 7, `ProposalWire` 11, `ToolWrite` 9,
`ToolRoundTrip` 2, `ToolSetFull` 2, `ToolEmit` 11, `ToolDispatch` 18, `WebApp` 25, `ReadTool` 27,
`Envelope` 15, `Wire` 20 -- 19 classes, 219 tests, 0 failed, 0 probe leftovers, 0 overlaps, 0 foreign
runs. `smoke.sh --container ocupilot-ci`: executed 45, passed 45, failed 0, pending 2, skipped 0 before
the suite had written any agent switch on that instance, and 44 executed, 44 passed, 1 skipped
afterwards, because `agentswitches` reports that it can no longer tell whether the install wrote
none. Each
mutation line above was applied alone on the throwaway, grepped inside the container, loaded and
recompiled with its subclasses, observed red on its named test and reverted;
`diff -rq src/ /tmp/ocupilot-ci/src/` reports no differences afterwards.

**Review findings.** 48 findings from four layers -- high 2 root causes (6 members), medium 6, low 23,
false 5. 38 rows patched, 5 deferred, 5 rejected; patched entries after grouping: 2 high, 4 medium,
14 low. Both highs are this pass's own work, not the baseline's: the diff scoping DW-1351 asked for
left a row whose payload weakened the live target unrefused whenever its diff named nothing, and the
whole-mask subset test read two-factor backwards in both directions. The first is fixed where AD-6's
Rule already put it -- the fingerprint now covers the stored payload as well as the re-merged read,
so such a row is refused 409 `PROPOSAL.TARGETCHANGED` and closed rather than written, and the
prohibited seam did not move. Every rejected finding carries its reason in the triage log above.

**Follow-up review recommended: true.** This pass patched two `high` entries. The named unverified
risk is the one change outside the set: `Confirm.FingerprintMatches` now requires a second digest,
and every confirm the product makes runs it. Its premise -- that the mint stores the digest of the
very payload it stores, with the same descriptor exclusions -- was read in `Mint` and probed live on
`ocupilot-ci` (a real `WebApp.App` read merged and digested, then re-parsed from the stored JSON and
digested identically), and the 19-class sweep includes the three classes that mint and confirm
through the shipped path. It is still a strengthened gate on Story 5.3's surface that did not exist
when this story was first reviewed.

**Residual risks.** The advertised schema is now four fields, which is a deliberate narrowing of what
the agent may propose about a web application and the thing to review first: a later story that needs
`Timeout` or the CORS list adds it to `PermittedChangeFields` and to the tool's `PERMITTEDFIELDS`
together, and the reviewed-few floor now fails the suite if it adds only one. Behind the new
fingerprint check, a row whose `arguments`, `payload` and `fingerprint` agree with each other and
whose `diff` names nothing can still reach the port for those four fields; closing that needs the set
to key on the stored arguments, which the intent contract's "never by a match on request or argument
fields" forbids, or the fingerprint gate ahead of the seam, which the lead reserved. Both readings and
the five other open items are in `deferred:`.
