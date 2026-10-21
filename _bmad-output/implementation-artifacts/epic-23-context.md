# Epic 23 Context: The range-end cleanup

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Epic 23 holds the cleanup stories chartered after each release. Each takes an owner-approved slice of the deferred-work ledger, at most twelve entries, and gives every entry a disposition, so the ledger stays honest and the code it names stays right. Stories 23.1 to 23.7 and 23.11 are done. Story 23.8 is next. It resolves the last seven medium-severity entries and five low-severity tidy-ups. The medium entries cover the scripts, the install and smoke checks, the client lint, the screen-open contract and the shared Save. The tidy-ups are in the System Explorer save path and a proposal test fixture. The aim is that the scripts, the install checks and the explorer's save path say and do the same thing. Stories 23.9 and 23.10 follow it.

## Stories

- Story 23.1: The range-end cleanup (done)
- Story 23.2: The range-end cleanup, part 2 (done)
- Story 23.3: The range-end cleanup, part 3 (done)
- Story 23.4: The range-end cleanup, part 4 (done)
- Story 23.5: The range-end cleanup, part 5 (done)
- Story 23.6: The Haiku-story cleanup (done)
- Story 23.7: The range-end cleanup, part 6 (done)
- Story 23.8: The range-end cleanup, part 7 (next)
- Story 23.9: The range-end cleanup, part 8 (backlog)
- Story 23.10: The range-end cleanup, part 9: two sweeps (backlog)
- Story 23.11: The range-end cleanup, part 10 (done)

## Requirements & Constraints

**Every cleanup story**

- The ledger tool writes each owned entry's disposition: `resolved-by` the story with its commit, or `wontfix-accepted` or `by-design` with a reason and any condition that would reopen it.
  - Story 23.8's criteria allow no other disposition, so no entry is re-owned onward.
  - Use `ledger.sh slice|show|append`, and never read the ledger file whole.
- An entry is a finding, not a fact. Verify it at head and record whether it is confirmed, refuted or already fixed. Counts in an entry's evidence date from its filing, so recount them.
- Every fix gets a test that reddens before the fix, with a Rule 19 `mutation:` line. If no test can go red, the entry says why.
- Fixes land in batches grouped by area. Each batch is its own commit with CI green on its own head.
- A change a user can see is named in the plan beside its entry. A fix that contradicts a planning document corrects that document at its origin.

**Story 23.8's entries** (owner `23-8-the-range-end-cleanup-part-7`). Each is listed with its severity, then its fix-risk.

- **Scripts, install and container**
  - DW-216 (med/med): `Install.Smoke.Port` uses the instance's own `WebServerPort`, so behind an external Web Gateway every HTTP check fails. The fix is a documented constraint at least, and an override at best.
  - DW-235 (med/low): when `TMPDIR` is `/`, the scratch-root guard in `ci-throwaway.sh` admits any absolute path, which a root container then removes.
  - DW-432 (med/low): `OCUPILOT_ALLOW_PRODUCTION_INSTALL` reddens test classes on any non-throwaway instance.
    - It is documented only in a shell comment and in class headers: 29 classes at head, against 11 at filing.
    - It belongs to the `OCUPILOT_ALLOW_*` arming family that `ci-throwaway.sh` sets. None of that family appears in CLAUDE.md, the rules or `docs/DEVELOPMENT.md`.
  - DW-1762 (med/low): every container stop logs "Previous system shutdown was abnormal", including the README's `docker compose restart iris` update step.
    - It was seen at every upgrade check from 1.0.2 to 1.0.5. Nothing was lost.
    - Measure the cause first. A stop timeout too short for IRIS is a guess (inference).
- **Client lint**
  - DW-1188 (med/med): no client-lint family checks the `ocu-` classes in templates against the stylesheets.
  - It needs a curated allow-list of deliberately unstyled hooks, and a policy for runtime-composed names and for `ocu-` ids.
- **Navigation contract**
  - DW-1462 (med/med): `shell.screen.open`'s `entityId` is a row key on some screens and the parent's id on parent-scoped ones.
  - The orchestrator has ruled. `entityId` names the entity the registry declares for that screen. A parent reference gets its own `parentId` across `Navigate.cls`, the directive and the client navigator.
  - `Test.ToolNavigate`'s registry sweep pins today's split. The entry's seven screens date from 2026-09-22, so derive the current set.
- **Shared Save (Rule 31)**
  - DW-2278 (med/med): Superserver, MFT connections (the Security slice) and Doc DB applications (the WebApp slice) each copy one Save, Rules and form shape.
  - Stories 18.31, 18.33 and 18.34 logged the same copy. The proposed fix is one kernel base the slices extend.
- **Explorer save and a test fixture** (all low severity)
  - DW-2256: `ExplorerSaveMint` answers `REASONNOTFOUND` where `AtelierPort.REASONNOSOURCE` applies.
  - DW-2257: `ExplorerSaveMint` measures the escaped length inline instead of calling the public `ExplorerSourceRead.Escaped`.
  - DW-2258: `Test/ExplorerSaveTurn` discards `RemoveKeyed()`'s status three times.
  - DW-2261: `Test/ExplorerSource` and `Test/ExplorerSourceEdges` hard-code `LIMIT = 60000` rather than reading `SOURCEMAXLENGTH`.
  - DW-1267: `Test/ProposalFixture.RemoveSeeded`'s doc comment promises a sweep its error path skips, and that path drops the keys it had not yet reached.

## Technical Decisions

- **Slices.**
  - A slice never depends on another slice, so a base shared by the Security and WebApp slices lives under `Kernel/`.
  - Rule 31 keeps a copy only when the two will diverge, when a base would couple unrelated areas or vendor APIs, or when two short copies read better.
- **Screen Save (AD-53, AD-55).** A screen's Save and the agent's confirmed write are two callers of one tool class. A shared base keeps all of the following:
  - The Save resolves the tool's endpoint, fields, payload and port.
  - The prohibited set is checked after the state read and before the port write.
  - The per-target lock is held from the fresh read through the read-back.
  - No proposal is minted.
  - Neither read-only nor the kill switch gates it.
- **Navigation (AD-5, AD-11, AD-13).**
  - Navigation proposes only registry routes, and every refusal happens on the instance before any announcement.
  - A sub-resource screen's route id names an entity of its parent screen's primary type.
  - An id is one percent-encoded segment from the shared encoder, and a composite id never gets a second grammar.
  - Citation chips open rows through the navigation tool's allow-list and URL builder, so they are reached by the change too (inference).
  - Every tool has a round-trip test over its generated schema.
- **Atelier source (AD-61, AD-39).**
  - A document with no source is `PORT.NOTFOUND` with `REASONNOSOURCE`.
  - The agent saves only within its namespace's own routines database, refused at the mint and again at Confirm.
  - Vendor text is logged and never sent.
- **Install and smoke (AD-17, AD-38, AD-45).**
  - One smoke path, owned by `Install/` with its assertions in `OcuPilot.Install.Smoke`, defines "installed and working", and CI runs it.
  - A product start compiles no test class.
  - Health is this start's install record, never a log line.
- **Pinned rosters.**
  - `ui/tools/ci.test.mjs` holds the arming rosters in `ci-throwaway.sh` against the classes that declare each variable.
  - `compose.test.mjs` pins the compose ports.
  - `client-lint.mjs` runs in prebuild, and each family is a pure function tested in `client-lint.test.mjs`.
  - An allow-list stays literal. Any count asserted elsewhere is derived.
- **Tests.**
  - Tests are hermetic: each asserts on its own rows by marker, with no dependence on run order or instance age.
  - Every plan carries a `Shared surfaces:` line.
  - `ProposalFixture.RemoveSeeded` is a shared surface: a name grep finds about 240 files (inference).
- **Verification.**
  - Run on slot A, with `server: "ocupilot-slot-a"` and the throwaway `ocupilot-ci` (52776/1975).
  - Run one ObjectScript class per call, and take totals from `%UnitTest_Result`.
  - Rule 29: the `(loop)` set is the story's own tests. The full ObjectScript sweep runs once, before `dev_complete`, and the browser suite is left to CI.
  - Rule 30: the fresh check runs forward and in reverse before the push.
  - Rule 32: the code head is pushed alone, never with `[skip ci]`, with `missing=none` before any bookkeeping push.
- **Containers.**
  - Never start, stop, recreate or `down` `ocupilot` or any `ocupilot-slot-*` container.
  - A `docker-compose.yml` change recreates the owner's live container on its next `up`, so DW-1762 needs the owner's coordination.
  - Measure on the throwaway, whose compose definition `ci-throwaway.sh` writes itself.
- **Prose and Git.**
  - Comments state the contract and never narrate.
  - Check Markdown with `scripts/lint-docs.sh`.
  - The README is user-facing: plain language, with no internals.
  - Stage by path, and never touch `main` or a release branch.

## UX & Interaction Patterns

- **DW-2256.** A refused agent save of a document with no source reads the viewer's existing sentence, "The instance keeps no source for this document.". The `code` stays the same, and the plan names the wording.
- **DW-1462.** The navigation tool's parameters change. An agent navigation is still announced first, and the departing screen can still refuse it.
- **DW-216 and DW-1762.** A changed README install or update step is something an operator sees.

## Cross-Story Dependencies

- **Order.** Story 23.8 runs on slot A after Story 23.7. Batch 4 of 23.7 is committed with CI pending. Under Rule 28 that CI resolves before 23.8's implement stage, not before its plan.
- **Story 23.6's siblings.** Story 23.6 left `REASONNOSOURCE`, the public `Escaped` and the `RemoveKeyed` status fix in `ExplorerSourceTurn`. Extend these rather than copying them (Rule 31).
- **Epic 20 on slot B.** Its pushed branch contains feature `854081b0`. Beyond feature, it changes:
  - `scripts/ci-throwaway.sh` (add-only roster comments), touched by DW-235, DW-432 and DW-1762
  - `scripts/check-objectscript.py`
  - `ui/src/styles/_components.scss` (+55 lines), which DW-1188 reads
  - `strings.ts`, `screens.generated.ts` and `screen-outlet.ts`
  - `Test/Navigation.cls` and `ui/tools/navigation.test.mjs`, beside DW-1462
- **Before editing those files (Rule 11).** Check Epic 20's diff first. Add-only edits were ruled fine during Story 23.11; anything else is a clarification for the orchestrator. DW-1188's rule will also judge Epic 20's new templates when that epic merges (inference).
- **Footprint.** `README.md` and `docker-compose.yml` lie outside Epic 23's paths. An edit to either is reported under `footprint_extensions:`.
- **CLAUDE.md and the rules.** DW-432 asks for lines in CLAUDE.md and `.claude/rules`, and the entry routed that decision to the owner. A CLAUDE.md line changes only through the Planner, with the owner's OK, so report the wording it needs. `docs/DEVELOPMENT.md` is in Epic 23's footprint.
