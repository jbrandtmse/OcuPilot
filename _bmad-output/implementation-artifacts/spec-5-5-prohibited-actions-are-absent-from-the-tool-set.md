---
title: 'Story 5.5: Prohibited actions are absent from the tool set'
type: 'feature'
created: '2026-09-20'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
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
  `OcuPilot.Test.Prohibited`, then the shipped `…ProposalConfirm`, `…ProposalWrite`, `…ProposalMint`,
  `…ProposalRace`, `…ProposalWire`, `…ToolWrite`, `…ToolRoundTrip`, `…ToolSetFull`, `…WebApp`,
  `…Dispatch`, `…Envelope`, `…Wire`. Confirm the totals with the `%UnitTest_Result` SQL probe (numeric
  run index, joined through `TestMethod`) before reporting any suite green; a client-side timeout is
  not a failed run and is never re-submitted.
- `bash scripts/smoke.sh --container ocupilot-ci --user _SYSTEM --password SYS` -- expected: every check
  executed and passing; zero executed checks is a failure.

**Mutations to record (Rule 19), one per acceptance criterion, applied on `ocupilot-ci` and reverted:**

- Make `Prohibits` answer `pProhibits = 0` for the `AutheEnabled` predicate -> the weakened-authentication
  row and the HTTP integration leg go red.
- Point `Write.ProhibitedClass()` back at `""` -> the integration AC and the seam test go red.
- Drop `DispatchClass` from `WebAppUpdate.ExcludedFields()` -> the advertised-schema AC goes red.
- Add `web-application` to a probe write tool for an uncovered type -> `UncoveredWriteTools()` is
  non-empty and its AC goes red.
- Remove one code's sentence from `ReasonFor()` -> the reason AC goes red.

**Manual checks:**

- After the prohibited legs, read the probe application's `AutheEnabled`, `Resource` and `DispatchClass`
  back from the throwaway and confirm each is what it was before the confirm.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none
