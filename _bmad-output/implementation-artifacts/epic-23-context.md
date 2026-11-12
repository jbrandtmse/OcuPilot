# Epic 23 Context: The range-end cleanup

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Epic 23 holds the fix stories chartered between releases. Each cleanup story gives an owner-approved slice of the deferred-work ledger a disposition, so the ledger stays honest and the code it names stays right. Story 23.12 is the only story in this dispatch, chartered at the owner's request after the 1.0.13 demo. It makes the agent read the list that actually holds an answer. Every read tool's description will say what its list holds and which fields it returns. The built-in system prompt gains three short rules: check every likely list before answering "none", never describe a list without reading it, and name the lists checked. The Planner cuts 1.0.14 from this story, and then the run holds again.

## Stories

- Story 23.1: The range-end cleanup (done)
- Story 23.2: The range-end cleanup, part 2 (done)
- Story 23.3: The range-end cleanup, part 3 (done)
- Story 23.4: The range-end cleanup, part 4 (done)
- Story 23.5: The range-end cleanup, part 5 (done)
- Story 23.6: The Haiku-story cleanup (done)
- Story 23.7: The range-end cleanup, part 6 (done)
- Story 23.8: The range-end cleanup, part 7 (done)
- Story 23.9: The range-end cleanup, part 8 (backlog)
- Story 23.10: The range-end cleanup, part 9: two sweeps (backlog)
- Story 23.11: The range-end cleanup, part 10 (done)
- Story 23.12: The agent picks the right list (next, and the only story in this dispatch)

## Requirements & Constraints

**Story 23.12**

- **The defect** was measured on the 1.0.13 demo with `claude-haiku-5-5`. Asked "Which tasks are suspended?" with no screen open, the agent answered "nothing is suspended" three times out of three, while three scheduled tasks were suspended.
  - The discovery search returned the schedule's read tool among eight tools.
  - The model read the empty background-jobs list instead, and then claimed the other task lists have no status column.
  - Today every read tool's description is the same templated sentence with a screen identifier in it.
- **Descriptions.** Each read tool's description names three things:
  - the screen's title as a person sees it;
  - what one row is;
  - the fields the read returns, derived from the descriptor's declared read fields and never written a second time.
- **Labels.** Lists a model could confuse each carry a short declared label. It says what the list holds and, where confusion is plausible, what it does not hold.
  - The groups include at least the five task screens, local against remote databases, and the log screens.
  - The plan measures the full set and names it.
- **Prompt rules.** The built-in system prompt gains three rules, each worded once and kept short:
  - read every likely list before answering "none";
  - never say a list lacks a field or a status without having read it;
  - a "nothing found" answer names the lists it checked.
- **Token cost.** Measure the first request of a turn with no screen open, and of a turn on a busy screen, before and after the change. Record the growth, and keep it within a bound the plan states and the code review checks.
- **Live evaluation.** About ten questions, each answered by one of several similar lists: suspended tasks, failed task runs, a dismounted database, a remote database, and a `messages.log` error against an application error.
  - Run them on `claude-haiku-5-5` against a throwaway seeded with a known state, once before the change and once after.
  - The after run must answer every question right. Keep the script and both score sheets with the story.
  - State a cost cap first: a few US dollars at most.
  - CI stays stub-based. The provider keys in `.env.local` may be used for live checks, but never copy or print them.
- **Roster test.** It fails when any read tool's description lacks its title, its row noun or its field list, or when a tool in a confusable group lacks its label. Its pinning mutation removes the field list from one description.
- **Out of scope.**
  - Stored data and the installer. No upgrade check is expected, and the plan confirms that from its diff.
  - Write tools' descriptions, beyond what the shared builder changes for free.
  - Which tools a turn starts with.

**Cleanup stories 23.9 and 23.10.** These carry the epic's standing rules, as before:

- The ledger tool writes each entry's disposition.
- Each entry is verified at head as a finding, and any count it quotes is recounted.
- A test reddens before each fix, with a Rule 19 mutation, or the entry says why none can.
- Fixes land in area batches, each with CI green on its own head.
- A CLAUDE.md line changes only through the Planner, with the owner's OK.

## Technical Decisions

- **The descriptor is the one source (AD-5).**
  - The tool listing is built only from compile-time declarations. It is kept per process and rebuilt when the `OcuPilot` package's compile signature changes, and nothing read at run time enters it.
  - So labels and field lists are declarations, and the builder must be deterministic. Anthropic receives the whole tool set byte-identical within a turn: tools outside the starting set carry `defer_loading`, and the last non-deferred tool is cache-marked.
- **How descriptions are built today.** `Screen/Tool/Read.cls` builds each description from its `DESCRIPTION` parameter and the tool identifier, then appends the read's optional `note` text.
  - `read.note` is `{key, text}`: the list page shows the key's string, and the tool gets the text.
  - `Screen/Registry.cls` and `ui/tools/screen-mirror.mjs` validate it alike over a shared corpus. A new declaration follows that pattern, extending the sibling rather than copying it (Rule 31).
- **Title and row noun.** These are client string keys on the descriptor, `labelKey` and `entityLabelKey`, and some screens leave `entityLabelKey` empty. Their text lives in `ui/src/app/core/strings.ts`. The plan's main design question is how to put the title a person sees into a description built on the instance without writing it twice.
- **Field list.** It names what the read returns:
  - the declared read `fields`, including the detail fields that `source.rowGet` merges in;
  - the schedule's `Suspended` comes from the vendor's `INFO` call, because its LIST reports every task as not suspended;
  - minus secret-typed fields, which never leave the instance (AD-35, AD-36).
- **Tool names stay `<area>.<screen>.read`.** On the wire, dots become underscores. Tool identity does not depend on how a screen is named, so a title in the description changes no name and no governance key.
- **The system prompt is a build-time constant (AD-11).**
  - Nothing read at run time is joined to it.
  - A definition's prompt override replaces the built-in prompt whole, so a definition that carries one does not get the new rules (inference). The plan says whether any shipped or demo definition carries one.
  - Keep the prompt's existing content: it names `<ocupilot-data>` as data (AD-60) and explains the explain-entry marker.
- **Turn budget (AD-24, Stories 18.39 and 18.45).**
  - A turn starts with the shell area's tools, `shell.tools.find` among them, plus the screen context's `tools`. Every other advertised tool is reached through the search.
  - The 2026-10-12 baselines on `claude-haiku-5-5`: a scoped first request of 4,644 tokens, a largest starting set of 11,135, and 192,172 tokens for the full set. The 368 advertised tools then serialized to 525,414 characters, 112,090 of them descriptions.
  - Re-measure, because the tool count has grown since (inference). Longer descriptions may also change what the discovery search returns (inference).
- **Tests.**
  - Every tool keeps its round-trip test over its generated schema.
  - Tests are hermetic.
  - A roster's allow-list stays literal, and any count asserted elsewhere is derived.
- **Verification.**
  - Run on slot A, with `server: "ocupilot-slot-a"` and the throwaway `ocupilot-ci` (52776/1975).
  - Run one ObjectScript test class per call, and take totals from `%UnitTest_Result`.
  - Rules 29, 30 and 32 apply.
  - Never start, stop or recreate `ocupilot` or any `ocupilot-slot-*` container, and tear down only a throwaway this run started.
- **Prose.** Comments state contracts only, and source text is ASCII with `\uXXXX` escapes. An AD the change reshapes is amended in the spine (Rule 20).

## UX & Interaction Patterns

- **The agent's voice.** The agent speaks in the first person and in plain language, and never claims what it did not verify. It names the screen it means, and names rows in backticks, which render as citation chips. A "nothing found" reply names the lists it checked, by the titles people see.
- **What a user can see.** If a label reuses `read.note`, its text also appears above that list on the page. The plan names that as a change a user can see.

## Cross-Story Dependencies

- **Order.** Story 23.12 runs alone on slot A under the owner's charter. Epic 20 is held, with Story 20.34 next, and Stories 23.9 and 23.10 stay in the backlog.
- **Earlier stories.**
  - It leaves Story 18.45's discovery tool and per-screen starting set unchanged.
  - It stays within Story 18.39's turn budget.
  - It extends Story 19.14's `read.note`.
- **Footprint.** Epic 23 covers `src/OcuPilot/`, `ui/src/`, `ui/tools/`, `ui/browser/`, `scripts/`, `docs/` and the planning artifacts. An edit anywhere else is reported under `footprint_extensions:`.
