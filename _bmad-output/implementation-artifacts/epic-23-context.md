# Epic 23 Context: The range-end cleanup

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Epic 23 holds the standing cleanup stories chartered between releases, so that the deferred-work ledger stays honest and the code it names stays right. Stories 23.1 to 23.4 drained owner-approved slices of the `range-end-cleanup` queue, and 23.5 (visible polish) waits in the backlog. Story 23.6, the current story, is not driven by the ledger. The Planner's read-only quality review covered the three stories implemented during the Haiku trial (20.19, 20.21 and 18.29), and the owner chose to keep all three with targeted cleanup rather than re-implement them. 23.6 fixes that review's findings, or declines each with a reason, so that the code reads like the rest of the codebase and its comments and tests say what the code does.

## Stories

- Story 23.1: The range-end cleanup (done)
- Story 23.2: The range-end cleanup, part 2 (done)
- Story 23.3: The range-end cleanup, part 3 (done)
- Story 23.4: The range-end cleanup, part 4 (done)
- Story 23.5: The range-end cleanup, part 5 (backlog)
- Story 23.6: The Haiku-story cleanup (current)

## Requirements & Constraints

**Story 23.6** (tracker key `23-6-the-haiku-story-cleanup`). It owns no ledger slice, so every disposition goes in the spec's `## Review Triage Log`.

- **Verify first.** Treat each item as a reviewer's finding, not a fact. Check it at the current head, and record it as confirmed, refuted or already fixed before planning any fix. Line references are at the merged heads (20.21 `d94d922a`, 20.19 `ac551bcf`, 18.29 `866790f4`). Stories 18.10 (which touched `Prohibited.cls`) and 20.20 have landed or will land since, so find each item by name, not by line.
- **The one correctness item.** In 20.21's item 2, `ExplorerSave`'s `ConfirmProblem` lets a confirm through when the stored arguments do not parse. It must refuse instead, failing closed. A test must redden on the old behavior before the fix, with a Rule 19 `mutation:` line in `## Verification`.
- **Every other item** is a refactor, comment or prose change, so behavior stays the same. The affected classes and specs pass before and after the change, and Rule 30's fresh check passes.
- **The other items, by theme.** epics.md's Story 23.6 block holds the full list.
  - **20.21:** a test that matches too loosely, an unused `ExplorerSaveAgent.ClassText`, and comments that misdescribe `proposal-card.ts`, `ExplorerSaveMint` and `ExplorerSaveAgentProbe`. Also a literal 20 beside `ExplorerSaveMint`'s `MAXEDITS`, and an optional fold of duplicate tests into `ExplorerSaveFlow`.
  - **20.19:** a doc line that narrates the story, and `Escaped`, `Fetch` and `ArmDocument` copied across two test classes plus a private production `Escaped`, which become one shared helper. Also an object-only routine that answers `REASONNOTFOUND` and gets its own reason, and two discarded `RemoveKeyed()` statuses.
  - **18.29:**
    - `UserCopy` duplicates `UserCreate.Perform`; add a compose hook in the parent.
    - Comments misstate the code.
    - An 825-line test class is to be split around a shared probe fixture.
    - Run narration sits in a test, and a mutation note sits in a product class.
    - `USEREndpoint` becomes all capitals.
    - The 422 body, the copy field list and two literals (`"COPY"`, and `"USERCOPY.SOURCE"` instead of `UserCopyError.#SOURCE`) are duplicated.
    - On the client, `set-password-dialog.ts` redefines an exported path, and a block in `user-create-form.page.ts` is unindented inside `@if (!copying)`.
- **Out of scope:**
  - `text-diff.ts` duplicating Compare.
  - DW-2241, Take as script on an agent save, which Story 20.20 fixes.

**Story 23.5** (backlog, slice owner `23-5-the-range-end-cleanup-part-5`). It holds 25 entries as of 2026-10-09: the 17 chartered visible-polish entries, plus CI flakes and test gaps routed to it since.

- Each entry ends terminal through the ledger tool.
- For a layout or copy fix, a test reddens first: a component spec for copy and state, or a browser spec for geometry. The spec runs on a redeployed bundle in both themes.
- Every count reads in the singular for one, through one shared rule.
- Fixes land in batches by area, each green on its own head.

## Technical Decisions

- **Prose.**
  - A doc comment states what the method does, its caller contract and any constraint the signature hides. It never names stories, review rounds, runs, finding ids or mutation notes.
  - To fix a wrong comment, replace the sentence. Do not append an explanation.
  - A test-class header says what the class pins and what it needs from the environment.
- **ObjectScript.**
  - Parameter names have no underscores: all capitals or camel case.
  - Reference a parameter by `#NAME` rather than repeating its literal.
  - Check every `%Status` with `$$$ISERR`.
  - Keep a test class to about 500 lines, and give a test class no property whose name starts with `Test`.
  - `uv run scripts/check-objectscript.py` must pass. The pre-commit hook blocks the commit otherwise.
- **Where a shared helper lives.** A product install compiles no `OcuPilot.Test.*` class and deletes any that an earlier start compiled (AD-17). A helper that production code calls must therefore live in product code. A test-only helper can live in a test fixture class.
- **One home per rule.**
  - AD-10's prohibited set is declared once, in the kernel, and never duplicated into a tool, screen or descriptor.
  - A field list is derived or authored once per tool (AD-3).
  - The flat error envelope carries a stable dotted-uppercase `code`, and its `reason` is written once on the server (AD-12, AD-39, AD-53).
- **Agent source saves (AD-53, AD-54, AD-59, AD-61).**
  - `explorer.classes.save` and `explorer.routines.save` are advertised confirmed writes whose governance keys ship enabled.
  - The agent sends exact replacements, and each `Old` must match the stored text exactly once.
  - The mint stores the new text and one changed-lines hunk of at most 30,000 characters. The save always compiles on Confirm.
  - Refused at the mint and again at Confirm, before anything is written: OcuPilot's own packages, `%` names, `%SYS`, and any document not stored in its namespace's own routines database.
  - A document that changed since the mint is refused.
  - `ConfirmProblem` belongs to that Confirm-side refusal.
- **Source reads (20.19).**
  - `explorer.class.source` and `explorer.routine.source` are read tools, not declared reads.
  - They answer whole lines, at most 60,000 characters after escaping, report the cut, and pass through AD-60's sanitizer.
  - The reply's total bound still applies (`TOOL.RESULTTOOLARGE`).
  - The screen already says "The instance keeps no source for this document." That sentence is a candidate for the object-only routine's new reason (inference).
- **User copy (18.29; AD-27, AD-55, AD-56).**
  - The admin API has no copy route. `UserCopyPort` calls `Security.Users.Copy` in `%SYS`, under the caller's own `%Admin_Secure:USE`.
  - It re-reads the source when it writes and refuses 409 if the source's roles or escalation roles changed since the mint. A copy always takes a new password.
  - A source that holds `%All` or an `%Admin_*` role, directly or as an escalation role, makes the copy destructive-confirmed, naming the privilege.
  - `AdminPort`'s password guard runs `$SYSTEM.Security.ValidatePassword` and answers 422, unlogged, before the vendor call. `UserCopyPort` maps #837, #838, #845 and #958 to unlogged refusals.
  - A screen Save and the agent's write are two callers of one tool class (AD-55), so the compose hook must leave both callers' payloads unchanged.
- **Verification.**
  - Slot A: every MCP call takes `server: "ocupilot-slot-a"`, and the throwaway is `ocupilot-ci`, handed over from Epic 18.
  - Run one test class at a time, and take totals from `%UnitTest_Result`.
  - Recompile the whole affected tree before reading a mutation.
  - Rebuild and redeploy the bundle before reporting a browser result.
  - Rule 29: run the targeted classes and specs in the loop, and the full ObjectScript sweep once, before `dev_complete`.
  - Client edits need `npm run test:components` and a build, whose prebuild checkers must pass.
  - A test-class split changes the class roster that CI shards over, so check `ui/tools/ci-timings.json` and the arming rosters in `ui/tools/ci.test.mjs` (inference).
  - Rule 30: `## Verification` names the shared surfaces the story changes, and the fresh check runs the story's classes and specs forward and in reverse on a rebuilt throwaway.
- **Git.**
  - Stage by path.
  - Push the code commit alone and confirm that its run registered before stacking any `[skip ci]` commit.
  - Never touch a release branch.

## UX & Interaction Patterns

- **The code-change card.** It shows the changed lines as one line diff, with three lines of context and line numbers. Its summary line counts the lines removed and added, and its consequence line says the compile runs on Confirm. When a confirmed save did not compile, the card says so under the status line and names the saved text as what the instance now holds. `summaryFields`' comment should describe this lines-changed form.
- **Copy from, on the create-a-user form.** It names a local account. That account's roles and escalation roles show read-only, with the copy's consequence line when one of them grants a privilege. The password's reason on blur is the instance's own. The indentation fix must not change what renders.

## Cross-Story Dependencies

- **Order.** 23.6 runs on slot A after 18.10 (merged) and 20.20. Its implement stage waits for 20.20 to merge (CI run 37952814550), because 20.20 changes the same Explorer save, script and AtelierPort code (DW-2241, DW-2242). Forward-merge the feature branch before implement, and re-locate every item afterwards.
- **Model.** Implement runs on Sonnet, on the owner's word of 2026-10-09.
- **Other epics meanwhile.** Epic 20 continues on interoperability (20.3 onward), clear of the Explorer files. Epic 18 is paused at 18.30 and resumes on slot A after 23.6, re-checking 23.6's files when it does.
- **Not this story's.** DW-2246 (`explorer.class.read` refuses a large class's view as `TOOL.RESULTTOOLARGE`) belongs to 23.5.
