---
title: 'Story 11.8: The proposal names the privilege it needs'
type: 'feature'
created: '2026-09-25'
status: 'done'
baseline_revision: '773d0522cba127c8c3c42f0cf9db76ac253630b2'
baseline_commit: '773d0522cba127c8c3c42f0cf9db76ac253630b2'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-11-context.md'
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
warnings: ['oversized']
deferred:
  - summary: >-
      A live card's privilege line is refreshed only while its turn is still polling; after the turn ends, a revocation shows no warning until a conversation restore.
    evidence: |-
      pollUntilTerminal (ui/src/app/core/turn.ts) stops at the turn's terminal state, and the turn usually completes right after the proposal, so the line keeps its last "held" answer while the card stays live. Confirm still refuses with AUTH.NOPRIVILEGE naming the pair. Closing it means re-reading live proposals after turn end, a change to the contended turn.ts / panel.ts polling.
    location: >-
      ui/src/app/core/turn.ts pollUntilTerminal
    severity: medium
---

<intent-contract>

## Intent

**Problem:** A proposal card does not say which privilege its write needs. A user who lacks one finds out only when Confirm answers 403.

**Approach:**

1. At mint, the proposal records the pair set its write's own gate resolves. That is the tool's declared pairs: the endpoint's `ResourcesOR()` resource the tool declares, AD-8's extra pairs, and the pairs its arguments add.
2. Every time the row is serialized, the proposal's wire row carries that set. It also carries the first pair the owner does not hold at that moment, evaluated by the same check Confirm's gate makes.
3. The card renders one line from the two:
   - "Requires <resources>, which you hold."
   - or, as a warning, "Requires <resources>. You don't hold <resource>."

   Confirm stays enabled either way.

## Boundaries & Constraints

**Always:**

- **One source for "requires".** It is `Operation.RequiredPairsOf`: the lines of `Operation.Gate` at `:311-323`, extracted, with `Gate` calling the extracted method. The value is `Registry.RequiredPairs(tool)` followed by `Registry.ArgumentPairs(tool, args)`, over the same stored arguments Confirm's gate reads.
  - `Mint` records the answer, de-duplicated, in resolution order, spelled `resource:permission` and comma-joined. This is the spelling `Screen.Gate.ParsePairSpec` reads and the ledger records.
  - No endpoint is constructed, nothing calls `AdminPort`, and the client derives nothing.
- **"Held" is evaluated at every serialization, never stored.** The value is `Operation.MissingPair(owner, pairs, "")`: the call Confirm's gate makes, which asks `CheckUserPermission` about the user's current grants (AD-8, never cached). It is evaluated in the request process, outside any escalated frame (AD-9).
- **Wire shape.** Each proposal row gains `privilege`:
  - `{requires: ["%Admin_Secure:USE", ...], missing: "<pair>" | ""}` when a set was recorded;
  - `null` when none was (rows minted before this story, or a set that did not resolve or did not fit the column).
  - `Propose.WireRow` is its only writer, and `Test/ProposalWire`'s `WIREKEYS` pins it.
- **Wording.** The two sentences are fixed strings. Both begin "Requires". Neither ever says "sufficient", because `ResourcesOR()` is a lower bound (AD-29) and the instance's answer is the verdict.
- **Where the line appears.**
  - It shows exactly while Confirm and Cancel do (`buttonsVisible`), directly above the runs-as caption.
  - Held: a caption with the runs-as caption's class.
  - Missing: `ocu-banner ocu-banner-warning ocu-proposal-card-warning` with `role="status"`.
  - The text is rendered by interpolation only (AD-11 rule 4).
- **Confirm is unchanged.** `confirmAriaDisabled` and `confirmReasonId` never read the privilege. The instance refuses as it does today: `Operation.Gate` answers 403 `AUTH.NOPRIVILEGE` naming the pair, and the card's refusal line renders it.
- **A mint never fails over the line.** An unresolved set, or one longer than the column, records `""` and logs a fault, and the proposal is minted as today.
- **A streamed and a plain turn render identical cards.** `stream-reply` leg (e) stays green and unedited.
- Every stateful check runs on `ocupilot-ci`, one test class per runner call. CI stays stub-based.

**Never:**

- **These stay unchanged:**
  - `Dispatch`'s gate;
  - `Operation.Gate`'s outcomes;
  - `Confirm`, the audit marker and the ledger;
  - `Prompt.cls`;
  - `TurnWire`'s turn-level keys;
  - the navigation payload (the shell's privilege map);
  - `screens.generated.ts`;
  - `AdminPort`.
- **Nothing is wired to row-action tooltips or form Save bars.** AC4 records this as an omission.
- **Epic 12's hunks and files stay untouched:**
  - `proposal-view.ts` `:146-162`;
  - `proposal-card.spec.ts` around `:774`;
  - `panel.ts`, `panel.spec.ts` and `ui/tools/proposal-view.test.mjs` are not edited at all;
  - `turn.ts` `:89`, `:326-331`, `:1093`, `:1133`.
- No new style rule, and no live key in any test.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Held | Owner holds the whole set (`webapp_list_update`) | Caption "Requires %Admin_Secure:USE, …, which you hold."; Confirm enabled | none |
| Revoked after mint | Principal loses `%Admin_Secure` while the card is live | Next poll: warning "Requires …. You don't hold %Admin_Secure:USE."; Confirm stays enabled | Confirm answers 403 `AUTH.NOPRIVILEGE` naming it, as today |
| Extra pair | A device tool | `requires` includes `%DB_IRISSYS:WRITE` | none |
| Argument pairs | `ErrorDelete` for a namespace | `requires` includes that namespace's globals-database resource at `WRITE` | none |
| Nothing recorded | Pre-story row, or unresolved or over-long set | `privilege` null; no line; the rest of the card unchanged | fault logged at mint |
| Terminal card | Confirmed, canceled or expired | No line | none |
| Streamed vs plain | Same `ToolUseReply` | Identical card DOM | none |

</intent-contract>

## Code Map

**Server.** All paths are under `src/OcuPilot/`.

- `Kernel/Proposal/Operation.cls`:
  - `Gate` `:297-340`: the pairs at `:311`, the argument pairs at `:319`, `MissingPair` at `:325`, then 403 `AUTHNOPRIVILEGE` with `detail.failedPair`.
  - `MissingPair(pUser, pPairs, pHolderClass)` `:404` and `Holds` `:419` (`CheckUserPermission`, with a holder-class seam).
- `Kernel/Agent/Dispatch.cls:257-291`: the mint-time gate. It refuses before the tool runs, so a card exists only for a user who held the set when it was minted.
- `Screen/Tool/Registry.cls`: `RequiredPairs` `:404`, `ArgumentPairs` `:426`.
- `Screen/Tool/*`:
  - Each tool's `PrivilegePairs` is its screen's set (`Screen/Gate.RequiredPairs:106`, with the classic union) plus `WRITERESOURCE:WRITEPERMISSION`.
  - Device tools declare `%DB_IRISSYS:WRITE`: `DeviceCreate:47`, `DeviceUpdate:38`, `DeviceDelete:51`.
  - `ErrorDelete.ArgumentPairs:158` answers through `LogSourcePort.PairsFor`.
- `Screen/Gate.cls:227` `ParsePairSpec`: comma-joined `resource:permission`. A malformed member voids the whole spec.
- `Kernel/Proposal/Mint.cls`:
  - `tValues` is filled at `:294-341`, with `arguments` near `:300`, and `GuardedMint` is called at `:342`.
  - `..RegistryClass()` `:103` is the resolve seam; `WarnsAuditingOff` `:400` shows how it is used.
  - `ErrorDeleteMint` calls `##super`. `Install/Smoke.cls:1410` shows a direct call to `Mint.Mint`.
- `Kernel/State/Propose.cls`:
  - properties `:51-159`;
  - `GuardedMint` `:202`, which sets fields at `:214+`;
  - `RowValues` `:590-633` (`pValues("user")` `:601`);
  - `WireRow` `:642-667`, the only writer of the row shape. It already calls `Disclosure.Rows`.
  - `GuardedRowsForTurn` `:515` and `GuardedRowsForConvo` `:546` escalate only inside the `Guarded*` helpers, so `WireRow` runs unescalated.
- `Kernel/Proposal/Disclosure.cls`: the home for the new builder, beside `Rows`.
- `Api/Turn.cls:215` (poll) and `Api/Conversation.cls:116/132` (restore) both reach `WireRow`. Neither is edited.
- `Test/ProposalWire.cls:28` `WIREKEYS`, checked in both directions at `:122` and `:125`.
- `Test/ProposalFixture.cls:249` mints straight through `GuardedMint`, with no pairs.
- `Test/ProposalMint.cls` and `Test/DeviceWriteGate.cls` hold mint set-ups to copy.
- `Test/ToolEmit.cls:180-215` already pins `Registry`'s pairs per tool.

**Client.**

- `ui/src/app/core/turn.ts`: `TurnProposal` `:209-244`; `parseProposal` `:498-522` (`consequence` at `:521`); `restoredProposals` `:546`.
- `ui/src/app/core/proposal-view.ts`:
  - It imports `STRINGS` (`:24`).
  - `ProposalCardView` `:56-118`; `toCardView` `:361-387` (`consequence:` at `:384`).
  - `consequenceSentence` `:151` is the pattern to follow.
- `ui/src/app/shell/proposal-card.ts`:
  - consequence block `:248-257`; footer `:272-335`; runs-as caption `:298` (`ocu-proposal-card-runs-as`);
  - `live` `:708`, `buttonsVisible` `:778`, `confirmAriaDisabled` `:783-789`.
- `ui/src/app/shell/panel.ts:916-933` `proposalView` hands the parsed proposal to `toCardView`, so it needs no edit.
- `ui/src/app/core/strings.ts`:
  - `privilegeDeniedAction` `:238`, the `privilege*` group;
  - `:1949` holds the only citation past the table (`EXPERIENCE.md:554`).
- `ui/tools/strings.test.mjs`: every table literal must be in `strings.ts`, nothing extra (`:580`), and every `EXPERIENCE.md:n` citation must resolve (`:744-789`).
- EXPERIENCE.md (`_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md`):
  - the Fixed-strings table's last row is `:513`;
  - the proposal-card anatomy is `:592-603`, with the footer bullet at `:600`.
- Browser:
  - `ui/browser/proposal-card.browser-spec.mjs` arms `webapp_list_update` at `:128` and `:168`, with the second reply hanging.
  - `ui/browser/refused-tool.browser-spec.mjs:55-75` creates a principal.
  - `Test/TurnWireFixture.cls`: `Resources` `:48`, `EnsurePrincipal` `:70`, `SetRoleResources` `:115`, `RemovePrincipals` `:162`.
  - `ui/browser/stream-reply.browser-spec.mjs` leg (e) is at `:327-357`.

## Tasks & Acceptance

**Execution:**

- `src/OcuPilot/Kernel/Proposal/Operation.cls` -- Add `RequiredPairsOf(pTool As %DynamicObject, pArgumentsJson As %String, Output pPairs As %List) As %Status`. It holds `:311-323`'s two resolutions, with the same error texts when either half is unresolved. `Gate` calls it and then `MissingPair`, and its behavior does not change.
- `src/OcuPilot/Kernel/State/Propose.cls` -- Add `Property RequiredPairs As %String(MAXLEN = 1024);`.
  - Doc comment: the set recorded at mint, in the spelling above; no `SCHEMAVERSION` move, because a pre-story row reads `""`.
  - `GuardedMint` stores `pValues("requiredPairs")`, and `RowValues` reads it back.
  - `WireRow` sets `privilege` from `Disclosure.Privilege(requiredPairs, user)`, or `null` when that answers `""`.
- `src/OcuPilot/Kernel/Proposal/Disclosure.cls` -- Add `Privilege(pRequired As %String, pUser As %String, pHolderClass As %String = "")`. It answers `""` when `ParsePairSpec` gives an empty list. Otherwise it answers `{requires: [spelled pairs in order], missing: Operation.MissingPair(pUser, list, pHolderClass)}`.
- `src/OcuPilot/Kernel/Proposal/Mint.cls` -- After `tValues("arguments")` is set:
  1. Resolve the tool through `..RegistryClass()`.
  2. Call `Operation.RequiredPairsOf(tool, tValues("arguments"))`.
  3. Set `tValues("requiredPairs")` to the joined, de-duplicated spelling when it resolved and fits the column (read the column's `MAXLEN` rather than repeating it). Otherwise set `""` and log through `Kernel.Fault`. The mint proceeds either way.
- `src/OcuPilot/Test/ProposalWire.cls` -- Add `privilege` to `WIREKEYS`.
- `src/OcuPilot/Test/PrivilegeHolderProbe.cls` (new) -- `HoldsPair(user, resource, permission)` answers 0 only for the resource `OcuPilotProbeNotHeld`.
- `src/OcuPilot/Test/ProposalPrivilege.cls` (new, arms nothing) -- Legs:
  - (a) Mint `webapp_list_update` against the demo `/csp/myapp` as `Smoke.cls:1410` does. The stored `RequiredPairs` equals `RequiredPairsOf` over the stored arguments and contains `%Admin_Secure:USE`. `GuardedRowsForTurn`'s `privilege.requires` is that list in order, and `missing` is `""`.
  - (b) `RequiredPairsOf` for each device tool contains `%DB_IRISSYS:WRITE`. For `ErrorDelete` with `{namespace: $Namespace}` it contains every pair `LogSourcePort.PairsFor` adds.
  - (c) `Disclosure.Privilege("%Admin_Secure:USE,OcuPilotProbeNotHeld:USE", user, probe)` answers `missing` `OcuPilotProbeNotHeld:USE`. The same call with the not-held pair removed answers `""`.
  - (d) A `ProposalFixture` row minted without `requiredPairs` serializes `privilege` as `null`. A malformed stored spec does too.
- `ui/src/app/core/turn.ts` -- Export `TurnProposalPrivilege {requires: readonly string[]; missing: string}`.
  - Add `privilege?: TurnProposalPrivilege | null` to `TurnProposal`. It is optional so that existing literals compile.
  - `parseProposal` sets it after `consequence`. It is `null` unless `requires` is a non-empty array of strings and `missing` is a string.
- `ui/tools/turn.test.mjs` -- Append parse cases: valid, absent, `requires` not an array, empty, a non-string member, `missing` not a string.
- `ui/src/app/core/strings.ts` -- Directly after `privilegeDeniedAction` (`:238`), add:
  - `privilegeProposalHeld: 'Requires <resources>, which you hold.'`
  - `privilegeProposalMissing: 'Requires <resources>. You don\'t hold <resource>.'`

  Each cites `/** EXPERIENCE.md:514 */`. Change `:1949`'s citation from `EXPERIENCE.md:554` to `EXPERIENCE.md:555` (Design Notes, merge).
- `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md`:
  - Append one Fixed-strings row after `:513`: `| "Requires <resources>, which you hold." · "Requires <resources>. You don't hold <resource>." | the proposal card's privilege line (Story 11.8, AD-8, AD-29): <resources> resolves to every resource:permission pair the write's own gate requires, comma-separated, and <resource> to the first the signed-in user does not hold; the second is a warning, and Confirm stays available [ADDED 2026-09-25 - Story 11.8] |`.
  - On `:600`'s footer bullet, in place, append: "Above the caption, the privilege line names the pairs the write's gate requires and whether you hold them. It says requires, never sufficient, because the endpoint's own check is a lower bound, and Confirm stays available either way `[ADDED 2026-09-25 - Story 11.8]`."
- `ui/src/app/core/proposal-view.ts`:
  - Export `ProposalPrivilegeLine {text: string; missing: boolean}` and `privilegeLine(privilege)`.
  - `privilegeLine` answers `null` for an absent value or an empty `requires`. Otherwise it fills `privilegeProposalHeld` or `privilegeProposalMissing`: `<resources>` becomes `requires.join(', ')` and `<resource>` becomes `missing`.
  - Add `privilege?: ProposalPrivilegeLine | null` to `ProposalCardView` after `consequence`, and set it in `toCardView` beside `consequence:`.
- `ui/tools/proposal-privilege.test.mjs` (new) -- Cover:
  - `privilegeLine` for held, missing, null and empty;
  - `toCardView` carrying it;
  - both strings start with "Requires " and neither matches `/sufficient/i`.
- `ui/src/app/shell/proposal-card.ts` -- Add a `privilegeLine` getter (`view.privilege ?? null`).
  - Inside `@if (buttonsVisible)`, directly before the runs-as `<p>` (`:298`), render `<p data-slot="privilege">` with the classes and role under Always, following the consequence block's pattern.
  - `confirmAriaDisabled` and `confirmReasonId` are untouched.
- `ui/src/app/shell/proposal-card-privilege.spec.ts` (new) -- Cover:
  - held renders the caption with no warning class;
  - missing renders the warning, `role="status"`, and names the pair;
  - when missing, live, with no secrets, Confirm's `aria-disabled` is null;
  - a null privilege renders no line, and neither does a confirmed or expired phase.
- `ui/browser/proposal-privilege.browser-spec.mjs` (new) -- Copy `proposal-card.browser-spec.mjs`'s arming, with the second reply hanging.
  - (a) Signed in as the spec's administrator, `[data-slot="privilege"]` reads "Requires " + the stored `RequiredPairs` (read through `runIris`), comma-separated, + ", which you hold.". The set contains `%Admin_Secure:USE`, there is no warning class, and Confirm is not `aria-disabled`.
  - (b) A principal whose role holds exactly the tool's set plus what OcuPilot needs (`EnsurePrincipal`) sees the held line. After `SetRoleResources` without `%Admin_Secure`, within 5 s the line is the warning naming `%Admin_Secure:USE`, and Confirm is still not `aria-disabled`. Pressing Confirm renders the card's refusal line naming the same pair.
  - `after` removes the principal and the definition.

**Acceptance Criteria:**

- **Integration AC.** Given a live write proposal, when the card renders, then it carries one line naming every pair the write's gate requires, the endpoint's `ResourcesOR()` resource and AD-8's extra pairs among them, and whether the signed-in user holds them. The panel's card reads the proposal wire's `privilege` (browser (a)).
- Given the user lacks a pair, when the card renders, then the line is a warning naming it and Confirm stays enabled. Confirm is refused by the instance exactly as today (browser (b), component spec). The audit marker and the ledger are unchanged: no code on those paths changes, and the Confirm classes in the loop stay green.
- Given either sentence, when it is worded, then it begins "Requires" and never says "sufficient".
- Given a row action or a form Save, when it renders, then it carries no privilege line: a recorded omission (Design Notes).
- Given the prompt pins, `TurnWire` and `stream-reply` (e), when they run, then they are green and unedited.

### Review Findings

Code review 2026-09-25 (full-opus; blind-hunter, edge-case-hunter, verification-gap, acceptance-auditor). 29 findings: 8 patched, 1 escalated, 20 rejected.

- [x] [Review][Patch] (med) A refused Confirm left the line saying "which you hold" beside the refusal naming the pair, once the turn had stopped polling -- `decideProposal` now records the refusal's `failedPair` as the line's `missing` (Confirm's own answer, AD-8) [ui/src/app/core/turn.ts:1194]
- [x] [Review][Patch] (low) Mint's call into `RecordedPairs` was unpinned for an argument-pair tool -- leg (f) mints `logs.applicationerrors.delete` and compares the stored set with the gate's over the stored arguments [src/OcuPilot/Test/ProposalPrivilege.cls]
- [x] [Review][Patch] (low) De-duplication was unpinned though reachable (the error delete's set for `%SYS` repeats pairs) -- leg (e) asserts the repeat and the once-each spelling [src/OcuPilot/Test/ProposalPrivilege.cls]
- [x] [Review][Patch] (low) The warning's place above the runs-as caption was asserted only for the held line [ui/src/app/shell/proposal-card-privilege.spec.ts]
- [x] [Review][Patch] (low) Leg (d) discarded `EntityRef.Key`'s status [src/OcuPilot/Test/ProposalPrivilege.cls]
- [x] [Review][Patch] (low) `Disclosure.Privilege` swallowed an evaluation failure with no fault [src/OcuPilot/Kernel/Proposal/Disclosure.cls:105]
- [x] [Review][Patch] (low) The footer sentence said "Above the caption" where the bullet names two captions, and its marker was in backticks [EXPERIENCE.md:602]
- [x] [Review][Patch] (low) `epic-11-context.md` still described the pre-amendment mechanism (the bare `ResourcesOR()` resource, the shell's privilege map) [_bmad-output/implementation-artifacts/epic-11-context.md:35]
- [x] [Review][Defer] (med) DW-1669: after the turn ends the line is never re-read, so a revocation shows no warning before Confirm; a restore shows no line at all (restored live rows render expired). AC2's predictive half is effectively unmet in the common case; the fix is a post-terminal re-read loop in `turn.ts`, against the documented "polling simply stops" contract -- `escalated`, fix-risk high [ui/src/app/core/turn.ts:1386] -- deferred: decision sheet

Rejected:

- false: browser (b) checks the refusal on the tool-call card -- the card's refusal slot renders the envelope's generic reason by design (AD-39); the tool-call card is where the instance names `failedPair`. The task's wording is the inaccuracy.
- low: `TOOL_GRANTS` is hand-written -- a change to the tool's declared set fails loudly at (b)'s first assertion.
- low: bare `.ocu-proposal-card-warning` selectors in other specs now match the privilege warning -- each signs in as a `%All` holder or uses fixtures with no privilege, so the warning cannot render there.
- low: the warning banner is a content-width flex item in the footer -- cosmetic, and the class list and "no new style rule" are specified.
- low: `WireRow` evaluates rows that never show the line -- a few `CheckUserPermission` calls per row; the specified wire shape carries `privilege` on every recorded row.
- low: the recorded set can drift from Confirm's re-resolution within a proposal's life -- by design (AD-8 records at mint; Confirm is the verdict).
- false: `RecordedPairs` reads MAXLEN 0 when the property cannot be opened -- the store class is compiled with the mint.
- low: a third registry `Resolve` per mint -- negligible, and removing it adds a parameter.
- low: leg (e)'s `$Length > 8` is weak -- it is the over-long leg's precondition; the spelling is pinned by (a), (e) and (f).
- false: `GuardedMint` stores `RequiredPairs` uncut -- only the length-checked mint and a test fixture write it, and a cut would weaken the set.
- maybe-false: the AD-9 rationale in `Privilege`'s caller contract -- would need `CheckUserPermission`'s behavior under an escalated frame measured; the AD-9 contract itself holds.
- low: the Accessibility Floor's status list omits the line -- the card's existing `role="status"` banners are not listed either; the card lives in the transcript's `role="log"`.
- false: a `role="status"` node inserted with its text may go unannounced -- it is inserted inside the transcript's `role="log"`, whose additions are announced.
- low: test fixture duplication in `turn.test.mjs` and `proposal-privilege.test.mjs` -- cosmetic.
- false: AC4 and AC5 lack mutation lines -- already triaged (omission; pre-existing unedited pins).
- low: AC2's "no code on those paths changes" is inexact (`Gate` was refactored) -- the refactor's outcomes are pinned by `UserUpdate`, `ProhibitedRoute` and `ErrorDeleteScope`; a spec-wording fix.
- false: the reviewed diff includes QA's uncommitted spec change -- the lead commits it.
- low: DW-1669's "until a conversation restore" is wrong -- corrected on its trailer.
- low: `RecordedPairs` re-implements `Ledger.PairsToString` without its separator guard -- a separator in a resource name yields a spec `ParsePairSpec` voids, which fails safe to no line.
- low: "the endpoint's `ResourcesOR()` resource among them" is shown for one tool -- follows from AD-8's 2026-09-21 amendment (a tool's set is its screen's); per-tool pairs are `ToolEmit`'s pins.

## Spec Change Log

- 2026-09-25, lead spec gate: the proposed AC1 wording is applied to `epics.md` (Rule 5 tier-1, `[AMENDED]` marker) and the proposed AD-8 sentence is written into the spine (Rule 20). The plan's two departures from the dispatch prompt (the pair set rather than the bare `ResourcesOR()` resource; live Confirm-gate check rather than the shell's privilege map) are accepted as intent-preserving.

## Review Triage Log

### 2026-09-25 — Review pass

- verdicts: 15 findings — high 0, medium 1, low 8, false 6, maybe-false 0
- findings:
  - `[low]` `[patch]` Over-long set branch of `Mint.RecordedPairs` unpinned — added `Test/PrivilegeMintProbe` (store column MAXLEN 8) and leg (e) asserting `""`; mutation recorded.
  - `[low]` `[reject]` The fault logged for an unrecorded set is never asserted — `LogRaw` writes a console line only; pinning it needs a new fault seam on `Mint` (added surface) for a diagnostic users never see.
  - `[false]` `[reject]` AC4 has no pinning test or mutation line — AC4 is a recorded omission with no code; there is nothing to falsify.
  - `[low]` `[reject]` AC5 has no mutation line — its pins (prompt pins, `TurnWire`, stream-reply (e)) are pre-existing and unedited; streamed and plain share `WireRow` and `parseProposals`, so no story-specific mutation separates them.
  - `[low]` `[patch]` Leg (d)'s malformed case never read back its seeded set — added an `AssertEquals` on the stored `RequiredPairs` per case.
  - `[false]` `[reject]` The spec's closing run record still read "ready-for-dev" — finalize writes it; the section was not stale at close.
  - `[low]` `[patch]` `ProposalPrivilege` header said it "mints without writing to the instance" — header now names the proposal rows and fault lines it writes.
  - `[false]` `[reject]` `WireRow` calls `CheckUserPermission` per pair per row — the intent requires evaluation at every serialization; a few pairs per row.
  - `[medium]` `[defer]` A revocation after the turn ends shows no warning until restore — the intent's mechanism (every serialization) is met; the client stops re-reading when the turn ends, pre-existing polling in contended files. Deferred (frontmatter).
  - `[low]` `[patch]` Argument pairs were pinned at `RequiredPairsOf`, not on the recording path — leg (e) now asserts `RecordedPairs` for `ErrorDelete` carries `LogSourcePort.PairsFor`'s pairs; mutation recorded.
  - `[low]` `[patch]` Over-long and fault halves of "nothing recorded" untested — same root as the first row; over-long half patched there, fault half rejected with the second row.
  - `[false]` `[reject]` "Held"/"missing" proven on the instance only through `%All` and the holder probe — browser (b) drives the real `CheckUserPermission` on `ocupilot-ci`, as the intent constrains.
  - `[false]` `[reject]` No evidence stream-reply (e) ran — it ran green against the redeployed bundle in this stage (12/12 with the two other specs).
  - `[low]` `[reject]` Reusing the runs-as class makes bare-class selectors hit the privilege line — the intent requires that class; the only affected selector (`proposal-card.browser-spec.mjs`) was scoped, and the two component specs' fixtures carry no privilege.
  - `[false]` `[reject]` Changes outside the listed surface (EXPERIENCE.md, per-row evaluation) — both are the spec's own tasks and intent.

## Design Notes

**Governing ADs.**

- AD-2 step 3 and AD-29: `ResourcesOR()` is a lower bound, and each port has its own named gate.
- AD-8, with its 2026-09-21 and 2026-09-23 amendments: the pair set, the extra pairs, never cached.
- AD-6: confirm re-checks authorization.
- AD-9: the evaluation runs outside any escalated frame.
- AD-11 rule 4, and rule 1: the prompt is untouched.
- AD-19: `privilegeLine` is a pure function in `core/`.
- AD-39: the refusal envelope is unchanged.
- AD-52: declared ports.
- AD-53 and AD-55: the screen caller, which is out of scope (AC4).
- AD-5: `screens.generated.ts` is untouched.
- AD-10: no prohibited set is involved.

**Where each fact already lives, and the carriage chosen.**

- **The endpoint's `ResourcesOR()`** is evaluated only inside a running call (`AdminPort.Sequence` `:2021-2028`). No method answers it for an (endpoint, type) pair without running the endpoint, and adding one would be the new derivation this story forbids.
- **The tool's declared set** is what `Dispatch` evaluates at mint and `Operation.Gate` evaluates at confirm. Under AD-8's 2026-09-21 amendment it is the screen's set, whose first pair is the endpoint's `ResourcesOR()` pair (pinned for LIST by `Test/Descriptor.cls:2005`). It also carries AD-8's extra pairs.
- **So the line names that set.** Recording it at mint is the smallest faithful carriage: the pairs the write path evaluates, resolved by the write path's own method. It is not a second source, because Confirm re-resolves the same declarations and remains the authority.
- **The privilege map** (`GET /navigation`, `Kernel/Shell/Navigation`) answers yes or no per area and per screen. It cannot answer a tool's own pair, an extra pair or an argument pair, and the client would read it stale until it is re-read.
- **"Held" therefore comes from Confirm's own check** at each poll.

**Proposed wording corrections for the lead (Rule 5, apply-and-report; the intent is unchanged).** AC1 of 11.8 in `epics.md`:

- "the resource the endpoint declares through its `ResourcesOR()` list" → "the pairs the write's own gate requires, the endpoint's `ResourcesOR()` resource among them";
- "read from the privilege map the shell already loads (Story 1.9, FR-4)" → "evaluated on the instance by the check Confirm's gate makes (AD-8), at each read of the proposal".

**Proposed AD-8 sentence (Rule 20).** "A proposal records the pair set its write's gate resolves at mint. Its wire row carries that set with the first pair the owner lacks, evaluated at each read by Confirm's own check, and the card's line says 'requires', never 'sufficient'."

**Ports other than `AdminPort` (AD-29, AD-52).**

- `ProcessPort`'s `%Admin_Operate`: `ProcessTerminateWithError` inherits `ProcessTerminate`'s `WRITERESOURCE`.
- `LogSourcePort`: `ErrorDelete.ArgumentPairs` → `PairsFor`.
- `TaskPort` and `WalletPort` pass through `AdminPort`'s `ResourcesOR()`, and their tools declare that resource.
- `MgmntPort` has no write tool.

Every one is inside the recorded set, so none needs a derivation of its own.

**Why "held" is evaluated live.** `Dispatch` refuses to mint for a user lacking any pair (`:262`). A value stored at mint would therefore always read "held". The warning is reachable only through a change after mint, such as a revoked role, which is exactly the refusal the line exists to predict.

**Scope decision: AC4, a recorded omission.** Row-action tooltips (`data-table.ts:791-817`, `command-bar.ts:404-424`) and form Save bars (14 hand-rolled form pages plus `reduced-form.page.ts`) are not wired. None of them holds a tool's pairs on the client. Wiring them would mean:

- mirroring the tool pairs into `screens.generated.ts`;
- a per-pair "held" answer;
- edits to about 17 files.

AC4 names this as an omission, not a defect.

**Merge with Epic 12.** Both branches append Fixed-strings rows after `:513`, and both change `strings.ts:1949`'s citation (Epic 12 to `:561`). Whichever merges second sets `:1949` to 562 and moves its own new rows' citations by the other branch's count. `strings.test.mjs` names any line that is missed.

**Integration ACs.** The new wire member has one consumer, the panel's proposal card, which renders it (browser (a) and (b)).

- **Consumes:** 5.1–5.3 (mint, the proposal card, confirm), 1.9 (the gate's evaluators), 7.x–9.x (the tools' declared pairs, device extra pairs, `ErrorDelete`'s argument pairs), 11.7 (the streamed card is equal to the plain one).
- **Consumed-by:** 17.7, the owner's live check. No other consumer is scheduled. Wiring row actions and Save bars would be the next one.

**Ledger inbox:** none.

**footprint_extensions:**

- Contended, staying beside Epic 12's hunks: `ui/src/app/core/turn.ts`, `ui/src/app/core/proposal-view.ts`, `ui/src/app/core/strings.ts` (shared-append, plus the forced `:1949` citation).
- Shared-append: EXPERIENCE.md, one row plus one in-place sentence.
- Outside Epic 11's footprint: `Kernel/Proposal/Operation.cls`, `Mint.cls`, `Disclosure.cls`, `Kernel/State/Propose.cls`, `Test/ProposalWire.cls`.

## Verification

**Slot and instance.**

- Slot A. Every IRIS MCP call carries `server: "ocupilot-slot-a"`.
- Stateful checks run only on `ocupilot-ci` (52776/1975). Never touch `ocupilot`, `ocupilot-slot-*` or `ocupilot-b-ci`.
- Load and recompile the whole package with `bash /tmp/epic-11-lead/load.sh`, which prints `LOADRESULT` and `ERRCOUNT`.
- Browser runs:
  1. `cd ui && npm run build`;
  2. `docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`;
  3. export `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776` and `OCUPILOT_BROWSER_CONTAINER=ocupilot-ci`.

**Commands:**

- `uv run scripts/check-objectscript.py && bash scripts/lint-docs.sh` -- expected: clean.
- **(loop)** Run each of these classes with `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.<C>`, one per call:
  - `ProposalPrivilege`, `ProposalWire`, `ProposalMint`, `ProposalConfirm`, `Proposal`;
  - `ConfirmRoute`, `DeviceWriteGate`, `ErrorDelete`, `ToolEmit`, `TurnWire`, `TurnStream`.

  Expected: green, each confirmed by the `%UnitTest_Result` probe, and never re-submitted.
- **(loop)** `cd ui && npm run test:tools && npm run test:components` -- expected: green. This covers `turn.test.mjs`, `proposal-privilege.test.mjs`, `proposal-view.test.mjs`, `strings.test.mjs`, `proposal-card-privilege.spec.ts`, `proposal-card.spec.ts` and `panel.spec.ts`.
- **(loop)** `cd ui && node --test --test-concurrency=1 browser/proposal-privilege.browser-spec.mjs browser/proposal-card.browser-spec.mjs browser/stream-reply.browser-spec.mjs` -- expected: green against the redeployed bundle.
- **(once, before dev_complete)** The full ObjectScript sweep on `ocupilot-ci`, one class at a time, then `bash scripts/smoke.sh --container ocupilot-ci --user _SYSTEM --password SYS`. Report the sweep as "N ran, 13 refused (arming), 1 known residue". The full browser suite runs in CI only.

**Pinning mutations (Rule 19).** Recompile the whole package, or rebuild and redeploy, before reading each one. Revert, and confirm `git status --short` is unchanged.

- mutation: `Mint` records `""` always → `ProposalPrivilege.TestAMintRecordsTheGatesPairsAndTheWireCarriesThem` red (run 12137); browser (a) and (b) red (no `[data-slot="privilege"]`).
- mutation: `RequiredPairsOf` drops the argument half → `ProposalPrivilege.TestTheSetCarriesExtraAndArgumentPairs` red on the `ErrorDelete` leg (`%DB_HSCUSTOM:READ`, `%DB_HSCUSTOM:WRITE`; run 12138).
- mutation: `Disclosure.Privilege` answers `missing` `""` always → `ProposalPrivilege.TestMissingNamesTheFirstPairNotHeld` red (run 12139); browser (b) red (no warning within 5 s), (a) green.
- mutation: `WireRow` omits `privilege` → `ProposalWire.TestTheWireRowCarriesTheTripleTheDiffAndTheState` red (run 12140).
- mutation: `toCardView` omits `privilege` → `proposal-privilege.test.mjs` "toCardView carries the privilege line" red; rebuilt and redeployed, browser (a) and (b) red.
- mutation: `confirmAriaDisabled` answers `'true'` when a pair is missing → `proposal-card-privilege.spec.ts` "leaves Confirm enabled when a pair is missing" red; rebuilt and redeployed, browser (b) red ("and Confirm is still offered"), (a) green.
- mutation: the held sentence gains "sufficient" → `proposal-privilege.test.mjs` wording case red (with the held-line and `toCardView` cases).
- mutation: `RecordedPairs`' length check never fires → `ProposalPrivilege.TestAnUnresolvedOrOverlongSetRecordsNone` red ("a set longer than the column records none"; run 12399).
- mutation: `RecordedPairs` passes `"{}"` instead of the stored arguments → the same test red on `%DB_HSCUSTOM:READ` and `:WRITE` (run 12400).
- (QA) mutation: the privilege `@if` block moved out from under `@if (buttonsVisible)` in `proposal-card.ts`'s template → `proposal-card-privilege.spec.ts` "renders no line on a confirmed, canceled or expired card" red (fails on the `confirmed` phase); reverted, `git status --short` unchanged.
- (CR) mutation: `decideProposal` drops the `recordProposalMissingPair` call → `turn.test.mjs` "a confirm refused for a pair records that pair as the line's missing one" red.
- (CR) mutation: `Mint.Mint` passes `"{}"` to `RecordedPairs` instead of the stored arguments → `ProposalPrivilege.TestAMintRecordsItsArgumentPairs` red (run 12405).
- (CR) mutation: `RecordedPairs` drops its `tSeen` check → `TestAnUnresolvedOrOverlongSetRecordsNone` and `TestAMintRecordsItsArgumentPairs` red (run 12406).
- (CR) mutation: an element inserted after the warning `<p>` in `proposal-card.ts` → `proposal-card-privilege.spec.ts` "renders a missing pair as a status warning that names it" red.

## Auto Run Result

Status: done
Blocking condition: none

**Change.** A mint records the pair set its write's gate resolves (`Operation.RequiredPairsOf`, extracted from `Gate`) in `Propose.RequiredPairs`. `WireRow` adds `privilege: {requires, missing}`, with `missing` from `MissingPair` at each read, or `null`. The card renders the held caption or the warning above the runs-as caption while the buttons show. Confirm is untouched.

**Files.**

- Server: `Operation.cls` (extraction), `Mint.cls` (`RecordedPairs`), `Propose.cls` (column, store, wire), `Disclosure.cls` (`Privilege`), `Test/ProposalWire.cls` (`WIREKEYS`); new `Test/ProposalPrivilege.cls`, `Test/PrivilegeHolderProbe.cls`, `Test/PrivilegeMintProbe.cls`.
- Client: `turn.ts` (parse), `proposal-view.ts` (`privilegeLine`, `toCardView`), `proposal-card.ts` (the line), `strings.ts` (two strings; the `:1949` citation to 555); new `proposal-privilege.test.mjs`, `proposal-card-privilege.spec.ts`, `browser/proposal-privilege.browser-spec.mjs`; parse cases in `turn.test.mjs`; `proposal-card.browser-spec.mjs` runs-as selector scoped with `:not([data-slot])`.
- Docs: EXPERIENCE.md row 514 and the footer sentence.

**Review.** 15 findings: 5 patched (all low), 1 deferred (medium, frontmatter), 9 rejected with reasons in the triage log. Follow-up review: false, since no high or medium was patched.

**Verification** (all on `ocupilot-ci`, one class per runner call):

- `check-objectscript.py` 0 problems; `lint-docs.sh` 0 issues; `load.sh` LOADRESULT=OK, ERRCOUNT=0.
- Full ObjectScript sweep, once: 254 ran, 13 refused (arming), 1 known residue (`WireSecurityRead` task history); 2,076 tests, 0 overlaps.
- Story classes green: `ProposalPrivilege` 5/5 after the patches (run 12401), `ProposalWire`, `ProposalConfirm`, `Proposal`, `ConfirmRoute`, `DeviceWriteGate`, `ToolEmit`, `TurnWire`, `TurnStream`. `ProposalMint` is a Mint subclass, not a test class; `ErrorDelete` refuses (arming).
- `npm run test:tools` 1432 pass; `npm run test:components` 1252 pass.
- Browser, against the redeployed bundle: `proposal-privilege`, `proposal-card` and `stream-reply` 12/12, leg (e) unedited and green.
- `smoke.sh --container ocupilot-ci` 49/49 passed.
- Bundle initial total 1.60 MB (1,595,771 bytes), under the 1670 kB warning.
- Every Rule 19 mutation went red and was reverted byte-identical (see `## Verification`).

**Residual risk.** The deferred item: after a turn ends, the line is not refreshed until a restore. Suite mints of unregistered probe tools now log one fault line each.

**footprint_extensions:**

- Contended, beside Epic 12's hunks: `ui/src/app/core/turn.ts`, `ui/src/app/core/proposal-view.ts`, `ui/src/app/core/strings.ts` (shared-append plus the `:1949` citation; a one-line merge conflict is expected).
- Shared-append: EXPERIENCE.md (one row, one in-place sentence).
- Outside Epic 11's footprint: `Kernel/Proposal/Operation.cls`, `Mint.cls`, `Disclosure.cls`, `Kernel/State/Propose.cls`, `Test/ProposalWire.cls`, `ui/browser/proposal-card.browser-spec.mjs` (one selector).
