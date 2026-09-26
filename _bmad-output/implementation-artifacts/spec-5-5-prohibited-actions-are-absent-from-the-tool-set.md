---
title: 'Story 5.5: Prohibited actions are absent from the tool set'
type: 'feature'
created: '2026-09-20'
status: 'done'
baseline_revision: '266c37299a70919b0b9d29cde0ae5d1e11b6a0a3'
baseline_commit: '98ad9596bc9c33dd3c29eaa9f94754613e3b59ba'
review_loop_iteration: 3
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
warnings: ['oversized']
deferred:
  - summary: >-
      The client mirror `ui/src/app/core/entity-ref.ts` builds a reference key without
      normalizing, so a web-application key it builds no longer matches the server's.
    evidence: |-
      `entityRefKey` concatenates the id verbatim and `change-bus.ts:106` keys AD-14's change bus
      on it, while the server now folds a `web-application` id. Nothing diverges today -- every id
      the client keys on comes from a read whose spelling the server did not alter, and no shipped
      path publishes a change event on a proposal's target, whose id is now canonical. The fix is
      a client change, which this story's intent contract excludes ("no client or UI change").
      reopen_if=a confirmed write publishes its proposal's target on the change bus, or a screen
      highlights a row from a server-built key.
    location: 'ui/src/app/core/entity-ref.ts:59'
    severity: medium
  - summary: >-
      The identity layer now canonicalizes an id per entity type, which later write-tool stories
      must extend, and no AD says so.
    evidence: |-
      AD-13 defines the scoped triple and the encode-twice/decode-once URL codec; neither is
      contradicted -- `EntityId` is untouched and `Test.EntityId` is green -- but "which spelling
      of an id names one entity" is now a kernel rule that Stories 5.9-5.13 each extend for their
      own type, and a rule later builders would drift on belongs in the spine (Rule 20). A
      planning-artifact amendment is the lead's, not this workflow's (Rule 5).
    location: '_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md:237'
    severity: medium
  - summary: >-
      `Kernel.State.WebApp.GuardedRecord` stores a path verbatim, so the set's single remaining
      record lookup rests on a convention nothing enforces.
    evidence: |-
      `GuardedForPath` is `WHERE %EXACT(Path) = ?` and `Recorded` now asks it for the normalized
      path alone. Every production caller is `Installer.RecordApplicationProvenance` over
      roster-derived entries, and `ProhibitedByEffect` pins that every roster path is already
      canonical, so no path reaches it non-canonical today. Normalizing at the store is out of
      this story's footprint (`Kernel/State/**`). reopen_if=anything but install writes a record,
      or a recorded path differs from its normalized form.
    location: 'src/OcuPilot/Kernel/Proposal/Prohibited.cls:417'
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

**Rework iteration 3's two items are closed.**

- `[x]` **DW-1359 (high).** Closed: a web application's id reaches a reference key in one
  spelling, through `EntityRef.NormalizedId` -- keyed by entity type, next to `EntityRef.Validate`,
  and delegated to by `Prohibited.NormalizedPath` rather than the other way round. The stored ref
  is canonicalized again at the point of use, in `Propose.GuardedClaimAndClose`
  (`EntityRef.Canonical`), so a row written into the store directly serializes on its target's own
  lock too. Pinned by `ProposalSpelling.TestTwoSpellingsOfOneApplicationAreOneScopedTarget` (the
  sibling cancel) and `…TestASecondSpellingCannotWriteWhileAnotherConfirmIsInFlight` (the lock,
  with a rival in flight and the second write shown absent on the instance), and by
  `EntityRef.TestAWebApplicationIdReachesAKeyInOneSpelling` for the necessary condition alone.
- `[x]` **DW-1362 (low).** Closed: the stored-payload sentence is gone from `## Design Notes`, and
  DW-1354's composition stands on DW-1353.

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

### Review Findings

Code review 2026-09-20, tier `full-opus`, layers `blind-hunter`, `edge-case-hunter`,
`verification-gap`, `acceptance-auditor`. All patches applied in-pass; one mutation executed on
`ocupilot-ci` (recorded under `## Verification`).

- `[x]` `[Review][Patch]` **AC1's "byte-for-byte what they were" could not fail: the gate behind
  the set refused every wire row, not the set** [`src/OcuPilot/Test/ProhibitedRoute.cls:95-200`].
  `Seed` stored the fresh read's digest as the fingerprint beside a payload carrying the weakened
  value, so the stored-payload digest rework 1 added to `FingerprintMatches` (run 295) refused the
  row 409 `PROPOSAL.TARGETCHANGED` before the port whenever the set was removed. `Seed` now builds
  the two settable legs the way a mint does -- one `Mint.Merge` supplies payload, diff and count,
  and the fingerprint is that payload's own digest -- so both digests match and the set is the only
  gate left. Proved: run 339, the set removed, both legs answered `{"state":"confirmed"}` and failed
  the untouched-application clause; reverted, runs 340-343 green.
- `[x]` `[Review][Patch]` **The three legs' mutation doc comments claimed a reach they no longer
  had** [`src/OcuPilot/Test/ProhibitedRoute.cls:232-262`] -- each now says what its own row shape
  makes falsifiable, and the `DispatchClass` leg says why the untouched clause is not what it pins.
- `[x]` `[Review][Patch]` **The declared-secret invariant was asserted over two names, not over the
  hole** [`src/OcuPilot/Test/Prohibited.cls:310`]. `Confirm` merges a supplied secret over the
  payload after the verdict, and `FieldRows` drops secrets from the schema and the settable list, so
  a secret declared for a field outside the reviewed few would pass the reviewed-few floor and reach
  the vendor body unevaluated. The floor now asserts every declared secret is one of the reviewed
  few.
- `[x]` `[Review][Patch]` **No floor on `FingerprintExcludes`** [`src/OcuPilot/Test/Prohibited.cls`].
  Both digests use the same exclusions and the set is diff-scoped, so a settable field the descriptor
  excluded would be invisible to both gates. `WebAppList` declares `[]` today and nothing held it
  there; the floor now asserts no field a tool can set is excluded.
- `[x]` `[Review][Patch]` **`FingerprintMatches`' doc comment overstated the second digest**
  [`src/OcuPilot/Kernel/Proposal/Confirm.cls:432`]. `Mint` takes the fingerprint over the payload it
  stores, so the comparison is a tautology for every minted row; it refuses only a row no mint
  wrote. Corrected to state that, and the two things it does not reach.
- `[x]` `[Review][Patch]` **`## Verification` said this story leaves `Classification.cls` alone**
  while the diff adds a doc comment there -- corrected, and the stale AC1/AC5 mutation records and a
  blank line splitting the mutation list were fixed in the same section.
- `[x]` `[Review][Defer]` **DW-1362 (low, in-story)** -- the Design Notes present the stored-payload
  digest as the backstop that makes the fingerprint cover the write; it constrains no row a mint can
  produce, so the DW-1354 composition stands on DW-1353 alone. The code comment was corrected here;
  the spec's prose is the lead's to correct at its origin.
- `[x]` `[Review][Defer]` **DW-1363 (low, `wontfix-accepted`)** -- the CI runner's residue marker is
  roster-derived and cannot see `/csp/ocupilotprobeconfirm` or `ProhibitedByEffect`'s
  `Kernel.State.WebApp` record.
- `[x]` `[Review][Defer]` **DW-1320 `occurrence`** -- `OcuPilot.Install.Smoke` asserts nothing about
  the prohibited set, so an instance whose `ProhibitedClass()` regressed to `""` passes smoke and
  the health check.
- `[x]` `[Review][Defer]` **DW-1359 (high, held for iteration 3)** -- verified against the code, not
  re-filed. The target lock is taken inside `GuardedClaimAndClose`, **after** `FingerprintMatches`,
  so two concurrent confirms on two spellings of one application both match their fingerprints, take
  different locks, both win their conditional UPDATE and both PUT. The ledger's `high` reading is
  right and this spec's `deferred:` copy -- `medium`, "the second is refused 409 by the fingerprint
  gate rather than serialized" -- is wrong; the 409 bound holds for *sequential* confirms only.
  Correct it at its origin when the story re-opens.

**On the narrow DW-1359 fix (normalize the id at the mint, reusing `Prohibited.NormalizedPath`).**
Right direction, not complete as scoped, and the dependency runs the wrong way. It closes the race
for rows minted afterwards. It leaves (a) live rows minted before it, which stay a second scoped
target until they expire -- bounded by the 10-minute expiry, but real; (b) `GuardedClaimAndClose`,
which is handed the *stored* ref and so trusts an invariant nothing enforces at the point of use --
and this story has just spent two passes learning that the directly-stored row is the case the gates
must survive; and (c) the sibling cancel's `%EXACT(TargetRef)`, a second silent dependant on that
invariant. Normalizing inside `EntityRef.Key` (or a `Kernel` helper both it and the set call) closes
all three at once. The dependency direction matters: as proposed, `Kernel/State` and `Kernel/EntityRef`
would call into `Kernel.Proposal.Prohibited`, making AD-10's one home the project's path normalizer
and giving the identity layer a dependency on the safety gate -- the set should delegate to the
helper, not own it. And "Release 1 has one entity type" is why it is safe now, not why it is right:
normalization is per type (a web-application path case-folds, a user name does not), so the hook
should be type-keyed from the start, next to `EntityRef.Validate`, which already switches on type.
Two consequences to state rather than slip in: `TargetRef` is what the ledger and the panel show
(AD-37's weak reference), so the recorded id stops being the spelling the agent asked for; and
`Prohibited.Recorded`'s second lookup "for the id as it came" (DW-1360) becomes dead once refs are
canonical, so the two should land together. Not patchable here -- the fix belongs in
`Kernel/EntityRef.cls`, outside this story's footprint, and needs a two-confirm concurrency test to
be falsifiable at all.

**Also verified, no finding.** `GuardedMint`'s three status-checked stream writes are correct, and a
row written before this story is unaffected by the new gate: `Mint` has always taken the fingerprint
over the very payload it stores, so every pre-existing row passes the stored-payload digest and there
is no migration hazard. Rule 3 is satisfied by `ProhibitedRoute` -- real HTTP, real probe application,
properties read back through the shipped port. Rule 1's Integration AC is present and now pinned.
Rule 5: no NFR was worked around. `check-objectscript.py` 0 problems over 557 files; `lint-docs.sh`
clean. The client suite was not re-run: no client file and no generated field list changed.

**Rejected.** `by-design`: AC2's "names no screen class" against `RegistryClass()` -- the Code Map
says "Kernel may read the registry" and `Consumes:` names it, so the AC's wording is loose and the
code matches the design; `PERMITTEDFIELDS` restating the reviewed list in a screen class -- the
baseline's pattern, and both directions plus disjointness are now asserted; the resource-to-resource
swap (DW-1350) and `Enabled` on a non-OcuPilot path (DW-1356). `false`: `WriteExclusion` dropping the
parent's exclusions -- it is an `OcuPilot.Test.` fixture the registry skips, and admission is governed
by the positive list, which the reviewed-few floor pins for every registered tool.
`wontfix-theoretical`: the second `UNCOVERED` arm being unreachable -- it is the fail-closed default
for a type listed with no dispatch arm, real only if `COVEREDTYPES` grows without one, which AC3
catches at the tool; `ProhibitedFixture` rendering `MatchRoles` as a scalar -- `Rendered` goes through
`Mint.Display`, which renders an array as compact JSON, the array path is driven by the `CorsAllowlist`
leg, and `MatchRoles` is always-prohibited and unadvertised; `ProhibitedRoute.Read` comparing whole
JSON for "resolves" -- a read-only vendor GET echoes nothing of the request;
`ClearsUnauthenticatedOnly`'s zero-mask sentence -- it follows from the arithmetic and is stated as a
limitation at the method. `low`, not worth the complexity: a fourth code ordering in `ReasonFor`;
`Recorded` without its own `Try`/`Catch`, its one caller wrapping it; the registry loop's missing
`$IsObject` guard, where a malformed entry raises loudly in a test; `ParsedObject`/`ParsedArray`
duplicated inside `Kernel/Proposal`; `RegistryClass()` never overridden, which AC2's test asserts at
its shipped value; DW-1355's `note=note=` doubled key, where appending a clean trailer would truncate
the lead's recommendation and the origin line should be corrected instead; the three smoke totals in
the record, where slot A's 42 predates this story's classes. Rejected because the fix is to edit the
spec under review: `## Tasks & Acceptance` not describing `PermittedChangeFields`, `RegistryClass`,
`NormalizedPath`, the seventh code or the 45-to-4 narrowing -- the substantive half is already
DW-1355 `decision-pending`.

### Review Findings -- 2026-09-20, rework-3 re-review

Scoped to `git diff 266c372 a1b1500`, tier `full-opus`, layers `blind-hunter`, `edge-case-hunter`,
`verification-gap`, `acceptance-auditor`. All patches applied in-pass; two mutations executed on
`ocupilot-ci` (recorded under `## Verification`).

- `[x]` `[Review][Patch]` **HIGH -- the sibling cancel bound the canonical ref only, so two live
  rows storing one non-canonical `TargetRef` stopped being siblings of each other and the second
  reached the vendor `PUT`** [`src/OcuPilot/Kernel/State/Propose.cls:352`]. Stored refs are
  compared byte-for-byte, so canonicalizing the bound value alone matched no row written at a
  second spelling -- rows that canceled each other before this pass. Against AD-34's Rule
  ("confirming one proposal cancels its siblings on the same scoped target in the same
  transition"). The rejection recorded at iteration 3's triage rested on a bound that does not
  hold: the fingerprint gate does **not** refuse the second row, because
  `FingerprintMatches` re-merges the stored arguments over the fresh read and both rows here
  propose the same end state -- which is what `ProposalSpelling`'s own `HARDENRESOURCE` parameter
  is chosen for. Fixed by binding the canonical ref **and** the ref as stored; pinned by
  `ProposalSpelling.TestTwoRowsStoringOneSecondSpellingAreSiblings`, red alone under run 415 with
  the second row confirmed 200 and its token spent. Residual risks corrected at their origin.
- `[x]` `[Review][Patch]` **`ProposalRace.TestTwoClaimsOnOneTargetCannotBothWin` kept the
  unguarded `Lock` this pass fixed only where it was noticed** [`src/OcuPilot/Test/ProposalRace.cls:219`]
  -- `If 'tHeld Quit` added, and both race tests' wait loops now short-circuit on a failed `Job`
  rather than spinning `RACEWAITSECONDS` inside an open `TSTART`. That test's source locator for
  the sibling `UPDATE` was narrowed to `ClosedReason = ? WHERE`, which the new bind does not move.
- `[x]` `[Review][Patch]` **`EntityRef`'s class header still claimed a composite id passes through
  a key unharmed** [`src/OcuPilot/Kernel/EntityRef.cls:17`], which `NormalizedId` made false for
  `web-application` -- the sentence the moved composite test walked away from was left standing.
  Corrected at its origin: the separator keeps the parts intact, the rule folds them, and no
  caller builds one today.
- `[x]` `[Review][Patch]` **The DW-1359 mutation line was stale** -- it recorded "both
  `ProposalSpelling` methods red" against a class that now declares five. Re-observed (run 424,
  four of five red) and rewritten, with the one method the mutation leaves green named.
- `[x]` `[Review][Escalate]` **DW-1366 (med)** -- a confirm that cannot take the target lock
  answers 500 `INTERNAL`, where AD-34 says the loser is refused with the proposal's terminal
  state. Pre-existing from Story 5.3; this pass widens the population reaching it and pins it as
  contract. A published status code is a product call -- epic decision sheet.
- `[x]` `[Review][Defer]` **DW-1367 (low, `wontfix-accepted`)** -- `Key`'s new empty-normalized-id
  refusal surfaces from `Mint` as 500 `INTERNAL`. A narrow fix would have a caller consult the
  identity rule, which AD-13's amendment forbids.
- `[x]` `[Review][Defer]` **DW-1359 `occurrence`** -- the sibling-cancel half of that root cause,
  patched here; the trailer records it.

**Verified against the instance, not inferred.** The trailing-slash collapse the edge-case layer
raised is not reachable: on `ocupilot-ci`, `Security.Applications.Create("/csp/x/")` against an
existing `/csp/x` answers *ERROR #867 -- an application by that name already exists*, and `Exists`
answers 1 for both the slash-suffixed and the re-cased spelling. Two applications differing only
by a trailing slash cannot coexist, so `NormalizedId` cannot merge two distinct targets. Probe
application and global removed afterwards.

**Rejected.** `by-design`: `Canonical` answering a ref it cannot read verbatim (its stated
contract, and `EntityType` is a compile-time closed enum); `Parse` not normalizing (it would break
the key round trip, and AD-13's "where a stored key is read back" is delivered by `Canonical` at
the one place identity decides anything); later entity types having no rule yet (AD-13's amendment
says a type with no rule canonicalizes to itself and each write-tool story adds its own).
`false`: the spec's green claim at `a1b1500` predating `ProposalSpelling`'s arming-roster row --
Epic 13's `ci.test.mjs` gate reached this branch only at the later merge `e50d8dc`. `low`, not
worth the complexity: `ResourceOf` not normalizing `$Char(0)` (it reads the port's JSON, not a
SQL column); `CaseRows`' unused `pStored` on the pre-write call (positional); the mixed-case leg's
`tRows = 1` clause, which this build cannot falsify by case alone and which the spec already says
so -- its load-bearing assertions are the port read and the resource, both falsifiable under the
recorded mutation.

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

### 2026-09-20 -- Review pass (rework 3)

- verdicts: 35 findings -- high 0, medium 8, low 25, false 2, maybe-false 0
- findings:
  - `[low]` `[patch]` The `deferred:` entry for DW-1359 still described `EntityRef.Key` as concatenating the id verbatim -- the list is cleared and rewritten this pass, as the dispatch requires.
  - `[low]` `[patch]` The `deferred:` entry for DW-1360 described a second record-store lookup this pass deleted -- same rewrite.
  - `[low]` `[patch]` `Prohibited.NormalizedPath` delegated using its own `TYPEWEBAPPLICATION` literal, and `NormalizedId` answers an unrecognized type verbatim -- it now passes `EntityRef`'s own parameter. The drift is not silent (`ProhibitedByEffect`'s eleven non-canonical spellings redden on it), which is why this is `low` rather than `medium`.
  - `[low]` `[patch]` `Wire`'s doc claimed it refuses what `Key` refuses; `Key("web-application","instance","/")` is now refused and `Wire` is not -- the sentence now says what is true. No consumer reaches the gap: every `Wire` call site is fed by `Parse` of a key `Key` built, or carries no web-application id.
  - `[low]` `[reject]` An id that normalizes to nothing reaches `Mint` and renders 500 `INTERNAL` rather than a refusal -- an agent naming a web application `/` is not everyday input and the fix adds a branch.
  - `[medium]` `[patch]` The confirmed write is now addressed by the canonical id and no probe application in the suite was anything but lower case, so the resolution the write relies on was never exercised -- `ProposalSpelling.TestACanonicalIdStillAddressesAMixedCaseApplication` creates a mixed-case application and pins it; mutation, run 380.
  - `[medium]` `[defer]` The client mirror builds a key without normalizing -- in `deferred:`; a client change is excluded by the intent contract.
  - `[low]` `[reject]` A composite `web-application` id has its namespace half case-folded, and the composite test moved to another type -- no production path builds a composite web-application id (`JoinComposite` has no caller outside tests), and the separator claim the test carries is type-independent.
  - `[low]` `[patch]` A failed `Lock` did not stop the in-flight test, so it would `Job` a confirm that really writes -- `If 'tHeld Quit` added.
  - `[low]` `[patch]` That test asserted only that the jobbed confirm was non-OK -- it now pins the status, the code and the refusal's own text, read from a real run rather than guessed.
  - `[low]` `[defer]` `GuardedRecord` stores a path verbatim, so the single remaining record lookup rests on an unenforced convention -- in `deferred:`; the fix is out of footprint.
  - `[medium]` `[defer]` No AD records that ids are now canonicalized per entity type -- in `deferred:`. AD-13 is not contradicted: its round-trip guarantee is `EntityId.Encode`/`Decode`, untouched and green.
  - `[low]` `[patch]` The class header's "Nothing outside this class normalizes an id" read as "every id is normalized", which `Wire` deliberately is not -- the header now says the rule lives here while each entry point decides whether to apply it.
  - `[low]` `[reject]` The spec grew while flagged `oversized` -- the growth was what the rework item demanded, and the fix would be to edit this build's spec.
  - `[low]` `[reject]` `^OcuPilotProbeSpellingResult` is residue the runner's roster-derived marker cannot see -- DW-1363's accepted root cause; `OnAfterOneTest` kills it and every run reported it undefined.
  - `[low]` `[patch]` (same root cause as the `Wire` row) `Key` refuses an all-slash id where `Wire` accepts it.
  - `[low]` `[reject]` (same root cause as the 500 row) caller input answered `SERVERERROR` instead of an argument refusal.
  - `[low]` `[reject]` Two live rows both storing one **non-canonical** ref are no longer siblings of each other, because the cancel predicate is canonical -- real, bounded and already stated under residual risks: the target lock still serializes them and the fingerprint gate refuses the second 409, within the ten-minute expiry, and only for rows minted before this change. Matching both refs adds a branch to the claim.
  - `[medium]` `[patch]` (same root cause as the mixed-case row) the vendor `PUT` is issued with a folded id that no test resolves.
  - `[low]` `[reject]` Nothing asserts that every covered entity type has a normalization arm -- the verbatim default is correct for a type whose ids are the instance's own strings, so the proposed floor would assert something untrue of `user` and `role`.
  - `[medium]` `[defer]` (same root cause as the client-mirror row) mirror keys diverge with no gate comparing the two sides.
  - `[low]` `[reject]` (same root cause as the composite row) the namespace half of a composite id is folded with the path.
  - `[low]` `[reject]` A jobbed confirm answering after the wait expires is not killed -- the wait is four times the lock timeout, the outcome is a red plus residue rather than a false green, and it is `ProposalRace`'s pre-existing idiom.
  - `[low]` `[patch]` (same root cause as the failed-`Lock` row) the method proceeds unlocked.
  - `[low]` `[defer]` (same root cause as the `GuardedRecord` row) a provenance row at a non-canonical path would reopen DW-1352.
  - `[medium]` `[patch]` (verification-gap layer, same root cause as the mixed-case row) no test exercises a target the instance holds under a spelling the canonical id must resolve to.
  - `[medium]` `[patch]` The producer half was pinned by nothing: every canonical-ref assertion built its own ref, and the one test reading a ref a real mint stored used an already-canonical id, so hand-assembling the key in `Mint` left all twenty-six classes green -- `ProposalSpelling.TestAMintOfASecondSpellingStoresTheCanonicalTarget` drives the shipped write tool with the second spelling and pins the stored `TargetRef`; mutation, run 379.
  - `[low]` `[patch]` `AssertEquals(Snapshot(), tAfterFirst, "the application carries the one write and nothing else")` could not fail, because both rows carry the same end state -- deleted; the clause is carried by the unspent-token assertion above it.
  - `[low]` `[patch]` (same root cause as the `Wire` row) the symmetry sentence was reworded rather than made true.
  - `[low]` `[patch]` `Recorded`'s doc justified the removal with a reason that does not bear on it -- `ServesOcuPilot` normalizes its own argument before the lookup, so the caller's spelling never mattered; the sentence is gone and the pinned reason stands alone.
  - `[low]` `[defer]` (intent layer, same root cause as the `GuardedRecord` row) the one place this pass touches the prohibited set is subtractive and covered by an inspected rather than a pinned invariant.
  - `[false]` `[reject]` The new test's vehicle is the matrix's "not prohibited" hardening row -- that is deliberate and stated at the class: the row has to pass every gate in front of the claim for the claim to be what refuses the second confirm.
  - `[false]` `[reject]` The largest change is to a class the intent contract never names -- `Kernel/EntityRef.cls` is the lead's recorded footprint extension for DW-1359, and none of the contract's named prohibitions is touched.
  - `[medium]` `[defer]` (same root cause as the client-mirror row) "no client or UI change" is honoured in letter while the mirror drifts.
  - `[low]` `[patch]` (same root cause as the `Wire` row) `Key` validates the normalized id and `Wire` the raw one.


## Design Notes

**The four reviewed fields are an allowlist, and here is where a fifth goes.** `AutheEnabled`,
`Description`, `Enabled` and `Resource` are the web-application settings this release has reviewed.
Everything else the vendor exposes is refused, including a property a later IRIS build adds that
nobody here has seen. That is the point: an allowlist of four is safe **by construction**, where
advertising the vendor's forty-five would be safe only if the enumeration of what is harmless were
correct and stayed correct. [OWNER DECISION 2026-09-20, DW-1355: ship the four.] A later story that
needs a fifth adds the same name in **two** places --
`OcuPilot.Screen.Tool.WebAppUpdate.PERMITTEDFIELDS` (what the tool advertises) and
`OcuPilot.Kernel.Proposal.Prohibited.PermittedChangeFields` (what the set will let through) -- and
the suite fails if it adds only one. Widen it; do not re-derive the decision.


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
through those methods) put outside the threat model. The closure is therefore a composition
of gates already here, not a third mechanism: the set is not keyed on the stored arguments, which
this story's intent contract forbids, and the fingerprint gate did not move ahead of the seam.

**One target, one key (DW-1359).** A web application's id reaches a reference key in one spelling,
because `EntityRef.Key` puts it through `EntityRef.NormalizedId` first. That is what makes AD-34's
"one winner per target" true of a **target** rather than of a spelling of one: both the per-target
lock and the sibling cancel's `%EXACT(TargetRef)` key on the stored ref, and two spellings the
instance resolves alike would otherwise be two targets to both. The hook is keyed by entity type
and sits next to `EntityRef.Validate`, which already switches on type, because normalization is
per type -- a web application's path case-folds and a user name does not -- and the identity layer
owns it: `Prohibited.NormalizedPath` delegates here, so AD-10's one home reads the rule and does
not become the project's path normalizer. `Propose.GuardedClaimAndClose` canonicalizes the ref it
is handed as well (`EntityRef.Canonical`), because it is handed the **stored** ref: a row written
directly into the store, or minted before this existed, would otherwise take a lock no other
confirm of that target holds. Two consequences, stated rather than slipped in. `TargetRef` is what
the ledger and the proposal panel show (AD-37's weak reference), so the recorded id is the
canonical spelling and no longer the one the agent asked for; the instance's own spelling of the
application may differ from it in case, and a canonical id still addresses the target because the
vendor endpoint resolves either -- verified on `ocupilot-ci`, where the `WebApp.App` `GET` answers
byte-identical JSON for `/csp/ocupilotprobeconfirm` and `/CSP/OcuPilotProbeConfirm/`. And
`ServesOcuPilot`'s second record-store lookup "for the id as it came" (DW-1360) is dead once a
stored ref's id is canonical, so it is removed: install writes only roster and probe literals,
which are already in that form.

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
  field list changes. `field-lists.mjs --check` reads `Classification.cls`, whose reviewed XData
  this story leaves untouched -- it adds a doc comment there and nothing else, so the check's answer
  is unchanged.
- `bash scripts/ci-throwaway.sh --dir /tmp/ocupilot-ci --project ocupilot-ci --web 52776 --super 1975`
  -- expected: `ocupilot-ci` healthy.
- Load and compile **one file at a time** to its exact relative path with the IRIS MCP tools, then
  `grep` the loaded source inside the container before believing a red or a green.
- `iris_execute_tests`, **one class per tool call**, each landed in `%UnitTest_Result` before the next:
  `OcuPilot.Test.Prohibited`, `…ProhibitedByEffect`, `…ProhibitedRoute`, then the shipped
  `…ProposalConfirm`, `…ConfirmRoute`,
  `…ProposalWrite`, `…Proposal`, `…ProposalRace`, `…ProposalClose`, `…ProposalWire`, `…ToolWrite`,
  `…ToolRoundTrip`, `…ToolSetFull`, `…ToolEmit`, `…ToolDispatch`, `…WebApp`, `…ReadTool`,
  `…Envelope`, `…Wire` -- nineteen classes, and since rework 3 seven more that read the identity
  layer or the claim: `…ProposalSpelling`, `…EntityRef`, `…EntityId`, `…AuditEvent`, `…Descriptor`,
  `…TurnWire`, `…LedgerWire`.
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
  `ProhibitedRoute.TestAWeakenedAuthenticationIsRefusedOverTheWire` red on the 403, the code and the
  rendered reason. Runs 204-205 predate run 295 as above; the "probe application moved" reading they
  recorded is corrected by the code review's own run below, which is where the untouched-application
  clause is pinned.
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
  floor, and run 193 all three `ProhibitedRoute` legs red. Runs 192-193 predate the stored-payload
  digest this story's rework 1 added to `Confirm.FingerprintMatches` (run 295), which sits behind
  the set: from run 295 on, a `ProhibitedRoute` row seeded with the fresh read's fingerprint and a
  weakened payload was refused 409 `PROPOSAL.TARGETCHANGED` by that digest instead of reaching the
  port, so "each confirm succeeded and wrote" stopped being true and AC1's untouched-application
  clause stopped being able to fail. Re-established by the code review below.
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

- DW-1359: `EntityRef.NormalizedId`'s web-application arm answering `pId` verbatim (`If 1` in place
  of the type test) -> run 346 `EntityRef.TestAWebApplicationIdReachesAKeyInOneSpelling` red on all
  three one-key assertions, on `Canonical`'s reading of a stored second spelling and on the
  empty-id refusal, with the type-keyed task and role assertions green; run 424 four of
  `ProposalSpelling`'s five methods red -- the sibling-cancel leg (the first confirm canceled no
  sibling and the second was applied 200 rather than refused 409), the mint and mixed-case legs,
  and the in-flight leg's **"the application's properties on the instance are what they were"**,
  which is the second write itself. The same-spelling sibling leg stays green, because with the
  rule removed both of that claim's binds collapse to the one stored string.
- DW-1359 at the point of use: `Propose.GuardedClaimAndClose` keying its lock and its sibling
  cancel on `pTargetRef` again in place of `EntityRef.Canonical(pTargetRef)` -> run 348
  `ProposalSpelling.TestASecondSpellingCannotWriteWhileAnotherConfirmIsInFlight` red **alone**, the
  jobbed confirm of the directly-stored second spelling taking a lock nobody held, winning and
  writing while the rival was in flight. The sibling-cancel leg stays green, which is what
  separates the two mechanisms.
- Code review 2026-09-20, the cancel over the rows normalization never reached:
  `Propose.GuardedClaimAndClose` binding the sibling cancel to `tTargetRef` alone, in place of the
  canonical ref **and** the ref as stored -> run 415
  `ProposalSpelling.TestTwoRowsStoringOneSecondSpellingAreSiblings` red **alone**: the second row
  was left live, confirmed 200 instead of 409 `PROPOSAL.BURNED`, and spent its token -- the second
  vendor `PUT`. Reverted by copying the file back from the worktree and **re-loading** it, grepped
  inside the container, `diff` per file clean; re-verified green one class at a time -- runs 416
  (`ProposalSpelling` 5/0), 418 (`ProposalRace` 6/0), 419 and 426 (`EntityRef` 8/0), 420
  (`Proposal` 14/0), 421 (`ProposalClose` 7/0), 422 (`ProposalConfirm` 16/0), 423 (`ProposalWire`
  11/0), 425 (`ProposalSpelling` 5/0), each reporting no probe-application residue.
- Both reverted by copying each file back from the worktree and **re-loading** it (never by
  recompiling the dictionary), grepped inside the container afterwards, and re-verified green: run
  349, then runs 350-375 over the twenty-six classes.
- DW-1359 at the producer: `Mint.Mint` assembling the target key by hand from `pIdValue`, in place
  of `EntityRef.Key`'s answer -> run 379
  `ProposalSpelling.TestAMintOfASecondSpellingStoresTheCanonicalTarget` red **alone**, on the
  stored `TargetRef`: the shipped write tool, driven through `Screen.Tool.Write.View` with the
  re-cased and slash-suffixed spelling, stored that spelling as its scoped target.
- DW-1359's write half: `EntityRef.NormalizedId` stripping the leading slash as well as the
  trailing ones, so the canonical id is a spelling the instance resolves to nothing -> run 380
  `ProposalSpelling.TestACanonicalIdStillAddressesAMixedCaseApplication` red on the port read of
  its own mixed-case probe application by that id, with
  `TestTwoSpellingsOfOneApplicationAreOneScopedTarget` red beside it.
- Both applied alone in `ocupilot-ci`'s mount, grepped inside the container, then reverted by
  copying the file back from the worktree and **re-loading** it (never by recompiling the
  dictionary), grepped again, `diff -rq src/ /tmp/ocupilot-ci/src/` clean and `git status --short`
  and `git diff --stat` unchanged, and re-verified green one class at a time: runs 381
  (`ProposalSpelling` 4/0), 382 (`EntityRef` 8/0), 383 (`Prohibited` 11/0), 384
  (`ProhibitedByEffect` 6/0), 385 (`ProhibitedRoute` 4/0) and 386 (`Proposal` 14/0), each
  reporting no probe-application residue.

**Code review (2026-09-20), AC1's untouched-application clause.** `ProhibitedRoute.Seed` now builds
a row the way a mint does for the two fields the tool admits: one `Mint.Merge` over one real
argument supplies the payload, the diff and the unchanged count, and the fingerprint is that
payload's own digest -- the relationship `Mint.Mint` stores, so both of `FingerprintMatches`'
digests match and the set is the only gate left before the vendor PUT. `DispatchClass` is not
settable, so no mint produces a row for it and that leg stays hand-seeded.

- mutation: the prohibited call removed from `Confirm.Transition` (`If 0` in place of
  `If tProhibited '= ""`), applied alone in `ocupilot-ci`'s mount, grepped inside the container and
  loaded with `ConfirmFixture` recompiled -> run 339 `ProhibitedRoute` 3 of 4 red.
  `TestADroppedResourceIsRefusedOverTheWire` and
  `TestAWeakenedAuthenticationIsRefusedOverTheWire` each answered `{"state":"confirmed"}` -- the
  vendor write went out -- and failed **"the application's properties on the instance are what they
  were"** along with the 403, the code, the reason, the live row and the unspent token.
  `TestARepointedDispatchClassIsRefusedOverTheWire` was refused 409 `PROPOSAL.TARGETCHANGED`
  (`closedReason` `target-changed`) and its failure list stops before that clause, which is the
  pre-patch behavior of all three legs.
- reverted by reloading `Confirm.cls` from the worktree (not recompiled from the dictionary) and
  re-verified: `OcuPilot.Kernel.Proposal.Confirm||Transition` no longer carries the mutation,
  `diff -rq src/ /tmp/ocupilot-ci/src/` reports no differences, and the four classes touched or
  reloaded are green one at a time -- runs 337 (`ProhibitedRoute` 4/0), 338 (`Prohibited` 11/0),
  340 (`ProhibitedRoute` 4/0), 341 (`ProposalConfirm` 16/0), 342 (`ProhibitedByEffect` 6/0), every
  one reporting no probe-application residue. `check-objectscript.py` 0 problems over 557 files.

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

**Change (rework 3, the last two items).** DW-1359: a web application's id reaches a reference key
in one spelling. `EntityRef.NormalizedId` holds the rule -- keyed by entity type, beside
`EntityRef.Validate`, which already switches on type -- `EntityRef.Key` puts every id through it,
and `Prohibited.NormalizedPath` delegates to it, so the identity layer owns normalization and the
safety gate reads it. `Propose.GuardedClaimAndClose` canonicalizes the ref it is handed
(`EntityRef.Canonical`) before taking the target lock and canceling siblings, which covers a row
whose stored ref nothing normalized at the mint. Before this, two spellings of one application were
two scoped targets: two concurrent confirms matched their fingerprints, took two locks, both won
their conditional UPDATE and both reached the vendor PUT -- the AD-34 race DW-1250 closed in Story
5.3. DW-1360's second record-store lookup is dead once a stored id is canonical and is removed.
DW-1362: the stored-payload sentence is deleted from `## Design Notes`.

**Files changed.**

- `src/OcuPilot/Kernel/EntityRef.cls` -- `NormalizedId`, `Canonical`, and `Key` building its key
  from the normalized id.
- `src/OcuPilot/Kernel/State/Propose.cls` -- the claim's lock and sibling cancel key on the
  canonical ref.
- `src/OcuPilot/Kernel/Proposal/Prohibited.cls` -- `NormalizedPath` delegates, and
  `ServesOcuPilot`'s second record-store lookup is gone.
- `src/OcuPilot/Test/ProposalSpelling.cls` -- the four legs against real applications: the sibling
  cancel, the lock with a rival in flight, the shipped mint's stored target, and a canonical id
  addressing a mixed-case application.
- `src/OcuPilot/Test/EntityRef.cls` -- the one-key and type-keyed assertions, and the composite-id
  method moved off `web-application`, whose ids are canonicalized.

**Review findings.** 35 findings -- 0 high, 8 medium, 25 low, 2 false. Nine entries patched in
pass: 2 medium (the write half of the canonical id, and the producer half, each now pinned against
a real application with its own demonstrated mutation) and 7 low (the duplicated type literal, the
`Wire`/`Key` symmetry claim and the class header, the unaborted `Lock`, the too-weak refusal
assertion, the unfalsifiable snapshot assertion, `Recorded`'s doc justification, and the stale
`deferred:` list). Three entries deferred, all in `deferred:`: the un-normalizing client mirror
(medium, excluded by the intent contract), the missing spine record of a per-type identity rule
(medium, the lead's to write under Rule 20), and `GuardedRecord` storing a path verbatim (low, out
of footprint). Eleven rejected -- the 500 on an id that normalizes to nothing and the composite-id
fold, both `low` whose fix adds a branch to input no caller sends; the sibling pair that both store
one non-canonical ref, bounded by the target lock, the fingerprint gate and the ten-minute expiry
and stated under residual risks; a floor asserting a normalization arm per covered type, which
would be untrue of `user` and `role`; the unkilled jobbed confirm, `ProposalRace`'s own idiom;
the probe global, DW-1363's accepted root cause; the spec's growth, whose fix is to edit this
build's spec; and the two descriptive intent-layer observations. Every row is in the triage log.

**Follow-up review recommended: false.** Evaluated as a follow-up pass: no patched entry was
`high`, so the work has converged and patch volume is not grounds. Patched by verdict: high 0,
medium 2, low 7.

**Verified.** `check-objectscript.py` 0 problems over 558 files; `lint-docs.sh` clean; `ui`
`npm run build` green and `npm test` 1087 + 687, with no client file and no generated field list
changed. On the throwaway `ocupilot-ci`, each changed file copied to its exact relative path,
loaded one at a time and grepped inside the container before any red or green was read. The
twenty-six classes one at a time through `ui/tools/ci-runner.mjs`, runs 388-413: 313 tests, 0
failed, 0 probe leftovers, 0 overlaps, 0 foreign runs, confirmed against `%UnitTest_Result`
(classes 26, total 313, passed 313, failed 0 over those run indices) with the proposal table
empty afterwards. `smoke.sh --container ocupilot-ci`: executed 45, passed 45, failed 0, pending 2,
skipped 0. Each mutation in `## Verification` was applied alone in the throwaway's mount, observed
red on its named test, and reverted by re-loading the file from the worktree; `diff -rq src/
/tmp/ocupilot-ci/src/` reports no differences afterwards.

**Residual risks.** The sibling cancel binds the canonical ref and the ref as stored, so rows
written at one spelling still close each other and a row at the canonical spelling closes too. A
row stored at a *third* spelling of that target is serialized on the target's lock but not
canceled, and nothing behind the cancel refuses it: when both rows propose the same end state the
second row's stored payload still digests to its own fingerprint after the first has written, so
`FingerprintMatches` passes it and a second vendor `PUT` goes out. The ten-minute expiry is the
only bound. `TargetRef` is now the canonical spelling, so the
ledger and the proposal panel show it rather than the spelling the agent asked for; this build
cannot hold two applications differing only in case (`Security.Applications`' IdKey is
`NameLowerCase`), and the new mixed-case leg pins that a canonical id still reaches such an
application. Normalization is declared for one entity type, which is the only one Release 1 can
target; a story that adds a write tool adds its type's rule beside it or its ids stay the
instance's own strings.
