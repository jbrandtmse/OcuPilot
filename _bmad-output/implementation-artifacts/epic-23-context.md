# Epic 23 Context: The range-end cleanup

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Epic 23 holds the cleanup stories chartered after each release. Each one takes an owner-approved slice of the deferred-work ledger, at most twelve entries, and gives every entry a disposition, so the ledger stays honest and the code it names stays right. Stories 23.1 to 23.6 and 23.11 are done. Story 23.7 is next. It closes twelve medium-severity test gaps and contract mismatches in the kernel, the agent and the ports, so that the behavior each entry describes is pinned by a test that can fail. Stories 23.8 to 23.10 follow it.

## Stories

- Story 23.1: The range-end cleanup (done)
- Story 23.2: The range-end cleanup, part 2 (done)
- Story 23.3: The range-end cleanup, part 3 (done)
- Story 23.4: The range-end cleanup, part 4 (done)
- Story 23.5: The range-end cleanup, part 5 (done)
- Story 23.6: The Haiku-story cleanup (done)
- Story 23.7: The range-end cleanup, part 6 (next)
- Story 23.8: The range-end cleanup, part 7 (backlog)
- Story 23.9: The range-end cleanup, part 8 (backlog)
- Story 23.10: The range-end cleanup, part 9: two sweeps (backlog)
- Story 23.11: The range-end cleanup, part 10 (done)

## Requirements & Constraints

**Every cleanup story.**

- The ledger tool writes each owned entry's disposition: `resolved-by` the story with its commit, or `wontfix-accepted` or `by-design` with a reason and any condition that would reopen it. Use `bash _bmad/scripts/ledger.sh <ledger> slice|show|append` and never read the ledger whole.
- An entry is a finding, not a fact. Verify it at head and record whether it is confirmed, refuted or already fixed.
- Every fix gets a test that reddens on the defect before the fix, with a Rule 19 `mutation:` line. For an entry that is only a missing test, that means the new pinning test goes red under a mutation of the product code. If no test can go red, the entry says why.
- Fixes land in batches grouped by area. Each batch needs CI green on its own head, so a failing batch is reopened alone.
- A change a user can see is named in the plan beside its entry. A fix that contradicts a planning document corrects that document at its origin.

**Story 23.7's entries, by area** (owner `23-7-the-range-end-cleanup-part-6`)

- **Proposal and conversation kernel**
  - DW-1233: no executing test tells `AttachProposals`' seq join from a join by ordinal. Telling them apart needs a fixture that writes entries out of order.
  - DW-1234: the conversation read's unreadable-proposal-store degradation is pinned only by a scan of the handler's source.
  - DW-1255: the proactive close at turn start (`Api.Conversation.HandleCreate`) is driven only through the store, never through the handler.
  - DW-1211: the rule that no path from a write tool's View reaches the claim is guarded by a five-filename source scan. It needs a tree rule.
- **Gate, port and ledger**
  - DW-1306: the class-level port-gate assertions substitute a stub for the gate class. The OR semantics are already pinned by `refused-tool.browser-spec.mjs`.
  - DW-1258: `AdminPort`'s mutating path (`MUTATINGTYPES`, `HttpMethodFor`, `EndpointType`) has no class-level test.
  - DW-1308: nothing asserts exactly one refused ledger row per refused call. `DenialParity` asserts only the sentence.
  - DW-2266: `BackgroundTaskMint` and `EncryptionKeyFileMint` pass a raw U+0001 composite id into `detail.problem`.
  - DW-1783: on UTC instances, a reversed local-to-UTC conversion in the agent ledger cannot be caught. Fix-risk is high.
- **Errors and copy**
  - DW-1170: `REASONAGENTBADBODY` offers "or no body at all" on routes that refuse an absent body. This is user-visible copy.
  - DW-1377: the gate that checks every field-level code has a published sentence filters on the prefix `AGENT`, so `HELP.*`, `ACCOUNT*` and `PREFERENCES*` escape it.
- **Provider test fixtures**
  - DW-1191: `ProviderStub` and `ProviderStubTransport` hold two copies of the scripted transport body. The AD-35 half of this entry is closed.

## Technical Decisions

- **Proposals and confirm.** These come from AD-6, AD-34 and AD-40.
  - A proposal is server-minted, single-use and fingerprinted, and it expires after 10 minutes.
  - Confirm is a user-originated request only. It is not a tool, and it refuses whenever the turn's "on behalf of the model" marker is set.
  - The claim burns the token and commits the write in one atomic transition, under the target's lock. Every gate is evaluated at the write.
  - A proposal is bound to its turn's lifetime.
- **Privilege.** This comes from AD-8 and AD-29.
  - Gates are pair sets of `(resource, permission)`, checked in the calling process at call time and never cached. A denial names the failed pair.
  - `AdminPort` inherits the vendor's `ResourcesOR()` gate, which is only a lower bound. Every other port checks with `$System.Security.Check` before it calls anything.
  - A test that proves a denial uses a purpose-built principal, never `%Operator`.
- **Errors.** This comes from AD-12 and AD-39.
  - The envelope is flat: `{error, reason, code, detail}`. A `code` is never reworded, while a `reason` may be.
  - Fixed refusal sentences are written once, on the server, in `Api/Error.cls`.
  - A field refusal is `detail.violations[] {field, code, reason}`. A field code with no published reason is a defect.
  - Code families are routed by prefix through `ReasonForViolation` and `ReasonForToolCode`, and Epic 20 is still adding families. A sweep should therefore derive the families rather than list them.
- **Ledger.** This comes from AD-41 and the Dates convention.
  - The ledger row is finalized after the write and records what actually ran. Secret-typed fields are excluded when the row is written.
  - A row's `time` and the audit viewer's criteria are the instance's local time, `YYYY-MM-DD HH:MM:SS`, converted on the instance. `loggedAt` stays in ISO UTC.
  - `ocupilot-ci` and the CI throwaways run `Etc/UTC`, according to the entry's probe.
- **Secrets.** This comes from AD-35 and AD-48.
  - `ProviderPort` never lets a credential reach an exception, a status or a log line.
  - A test forces a provider failure and checks that the error log, read through `SYS.ApplicationError`, holds no credential.
- **Composite ids.** These come from AD-13.
  - Refusal text never carries a raw U+0001. `ErrorDeleteMint.ReadableId` cleans the id, as `SuperserverMint`, `MappingMint` and `WebAppPctAccessMint` already do.
  - Prefer one shared helper over a fifth copy (Rule 31).
- **Static checks.**
  - `scripts/check-objectscript.py` already holds rules of the same shape as DW-1211 needs: `check_restraint_containment` and `check_tool_dispatch`.
  - Its harness pins the rule count that CLAUDE.md states (21 today) to `CHECKS`. A new rule therefore moves that count.
- **Tests.**
  - Every handler gets an HTTP integration test covering status, content type and body shape.
  - Tests are hermetic: no leftovers, no dependence on run order or on the instance's age. Each asserts on its own rows by marker.
  - A count asserted outside its own roster test is derived, not written as a literal. Each plan carries a `Shared surfaces:` line.
- **Verification on slot A.**
  - Every MCP call passes `server: "ocupilot-slot-a"`.
  - The throwaway is `ocupilot-ci` (52776/1975).
  - Run one ObjectScript test class per call, and take totals from `%UnitTest_Result`.
  - Rule 29: the `(loop)` set is the story's own classes. The full ObjectScript sweep runs once, before `dev_complete`, and the full browser suite is left to CI.
  - Rule 30: run the fresh check, forward and then in reverse, before the push.
- **Prose and Git.**
  - Comments state the contract and never narrate. Non-ASCII characters are written as `\uXXXX` escapes.
  - Stage by path.
  - Push the code head alone, without `[skip ci]`.
  - Never touch `main` or a release branch.

## UX & Interaction Patterns

- The server's refusal sentence is what a person reads under the field or in the panel. Rewording `REASONAGENTBADBODY` (DW-1170) is therefore a visible change: the plan names the new wording, and the machine `code` stays unchanged.

## Cross-Story Dependencies

- **Order.** Story 23.7 runs on slot A. Stories 23.8, 23.9 and 23.10 follow it in that order, each filling a slot that would otherwise sit idle.
- **Integrate forward first.** The feature branch (`fa0dd517`) carries Story 23.11's batch c, so integrate forward before implement and again at each batch boundary.
- **Epic 20 alongside.** Epic 20 runs at the same time on slot B.
  - When this context was compiled, Epic 20's branch held edits not yet on feature to three files: `Api/Error.cls` (a new `ANALYTICS.` family in both reason routers), `scripts/ci-throwaway.sh` and `Kernel/EntityType.cls`.
  - These are likely contended with DW-1170, DW-1377 and DW-1783 (inference).
  - Rule 11: check Epic 20's diff before editing any of these files. An add-only edit is fine; anything else goes to the orchestrator.
- **CLAUDE.md.** DW-1211's new rule makes CLAUDE.md's rule count stale in the same commit. A CLAUDE.md line changes only through the Planner, with the owner's OK, so report the wording the change needs. `_bmad/custom/*.yaml` belongs to the orchestrator.
- **DW-1783 needs a non-UTC instance.** Pinning it needs one run on a throwaway started in a non-UTC time zone, which means a change to `ci-throwaway.sh` or to CI. If neither fits, the entry takes a disposition that says why no test can go red.
- **DW-2266 builds on Story 23.6.** It repeats the root cause of Story 23.6's `WebAppPctAccessMint` fix (18.10 item 1). Extend that fix rather than adding another copy.
