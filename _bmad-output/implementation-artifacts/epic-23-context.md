# Epic 23 Context: The range-end cleanup

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Epic 23 holds the standing cleanup stories chartered between releases, so that the deferred-work ledger stays honest and the code it names stays right. Each story takes an owner-approved slice of the `range-end-cleanup` queue and gives every entry a recorded disposition. Stories 23.1 to 23.4 and 23.6 are done. The story in flight, 23.5, is the visible-polish pass: the known visual and copy defects in the Angular shell, the panel, the list and detail pages and the count copy. Its aim is that the screens read cleanly at every common width and say what they mean. It also takes the CI flakes and test gaps routed to it since its charter.

## Stories

- Story 23.1: The range-end cleanup (done)
- Story 23.2: The range-end cleanup, part 2 (done)
- Story 23.3: The range-end cleanup, part 3 (done)
- Story 23.4: The range-end cleanup, part 4 (done)
- Story 23.5: The range-end cleanup, part 5 (in flight)
- Story 23.6: The Haiku-story cleanup (done)
- Story 23.7: The range-end cleanup, part 6 (backlog)
- Story 23.8: The range-end cleanup, part 7 (backlog)
- Story 23.9: The range-end cleanup, part 8 (backlog)
- Story 23.10: The range-end cleanup, part 9: two sweeps (backlog)

## Requirements & Constraints

**Every cleanup story.**

- Every owned entry ends with a disposition written by the ledger tool (`bash _bmad/scripts/ledger.sh <ledger> slice|show|append`):
  - `resolved-by` this story, with the commit; or
  - `wontfix-accepted` or `by-design`, with a reason and, where a condition would reopen it, that condition.
- Never read or edit the ledger whole.
- A story takes at most 12 entries, in this priority order: CI flakes, then security, then repeat occurrences, then the lowest fix-risk (Rule 27).
- A fix to code or a test comes after a test that reddens on the defect, and the spec records the Rule 19 `mutation:` line.
- Fixes land in batches by area, each green in CI on its own head, so a failing batch is reopened alone.
- A fix that contradicts a planning document, or settles a question one leaves open, corrects that document at its origin in the same pass.

**Story 23.5** (tracker key `23-5-the-range-end-cleanup-part-5`).

- **The slice.** It holds 24 entries: the 17 chartered from owner-approved batch (c), plus 7 routed since. The plan sizes them. Whatever exceeds the budget goes to a Clarification proposing a Story 23.11.
- **Red first, by tier.**
  - Copy and state fixes get a component spec.
  - Geometry fixes get a browser spec, because jsdom computes no layout.
  - Browser specs run against a rebuilt and redeployed bundle, in both themes.
- **Counts.** Every count the client renders reads in the singular for one. This comes from one shared rule, not from per-screen fixes.
- **The entries by area:**
  - **Shell geometry:**
    - DW-458: a narrowed panel traps the side bar at the yielding width. The ledger recommends that the panel width the user drags wins, and that the side bar yields again when the drag needs the room.
    - DW-460: the rail stays live under a full-screen panel.
    - DW-1148: the Home row at 1,920 px.
    - DW-2107: the agent picker's label is cut to "Anth" at the default panel width on a 1,440 px window.
  - **Shell state:**
    - DW-1341: the recents recorder keeps writing after sign-out.
    - DW-1342: the favorite toggle has no in-flight guard.
    - DW-1368: a transient help-read failure drops the Help control for the session.
    - DW-1371: the stale-bundle strip can sit above a blocking notice.
    - DW-1372: the reload prompt's status region is inserted, where it should stay mounted.
  - **Home and About:**
    - DW-1392: the System Information row has a hard height.
    - DW-1401: two surfaces render the generic-error sentence as a bare paragraph and cannot tell an unreachable instance from a 5xx.
  - **List and detail pages:**
    - DW-1976: a long text in a cell cannot be read whole through its tooltip.
    - DW-1978: the nine-tab strip hides tabs from 1,024 to 1,600 px.
    - DW-1951: an empty-state invitation chip shows a raw action id. Check every empty state.
  - **Count copy:**
    - DW-1985 and DW-2101: "1 rows" on the table footer, the command bar, the context chip and the ledger page, and "Saved 1 documents as <file>." on the code list.
    - Check every row-count string.
  - **The proposal card.** DW-1436: an opaque array (EscalationRoles) renders as the secret mask.
  - **The agent's reads.** DW-2246: `explorer.class.read` answers `TOOL.RESULTTOOLARGE` for a large class's view.
  - **Test and CI hygiene:**
    - DW-2163 and DW-2282: settle the layout, or the tool-call card's spinner, before the 720 px structural walk.
    - DW-2227: wait for the outgoing buttons to be gone before reading focus.
    - DW-2182: assert the pair-set refusal and a row, not the absence of a cut.
    - DW-2202: derive literal shared-surface counts.
    - DW-2221: `browserConfig` refuses unless both browser variables are set. Update `browser-config.test.mjs` and the README and DEVELOPMENT run lines.

## Technical Decisions

- **Client shape (AD-19).**
  - The client is zoneless and signal-based, with `OnPush` everywhere.
  - Screen state lives in a store keyed by its descriptor, never in a component field.
  - `ui/src/app/core/` imports no `@angular/core`. Its stores are plain subscribables mirrored into signals, and they are tested under `node --test`.
  - Cross-screen traffic is the change-event bus and the router only. A write re-fetches and never patches (AD-14).
- **Screens come from descriptors (AD-5).**
  - List and detail screens are drawn by the shared `ListPage` and `DetailPage` over the generated mirror. The tab strip and the empty-state keys are part of that shared machinery.
  - A fix lands in the shared component, not per screen.
  - A descriptor change is validated alike by `Screen/Registry.cls` and `ui/tools/screen-mirror.mjs`.
- **Strings.**
  - **Source.** The canonical source is `ui/src/app/core/strings.ts`. Each key cites its row as `/** EXPERIENCE.md:NNN */`.
  - **Completeness.** `strings.test.mjs` derives EXPERIENCE.md's Fixed strings table at run time, and every value must appear in it verbatim. A new string therefore adds its literal to the table, with a dated `[ADDED …]` or `[AMENDED …]` note.
  - **Voice.** No exclamation marks and no "successfully". Non-ASCII characters are written as `\uXXXX` escapes.
  - **Singulars.** The house pattern is a `…One` key chosen at exactly 1. A line that holds several counts is composed from per-count phrases, the way `core/impact.ts` does it and the way Story 19.18 did it for the data browser and the console.
  - After editing EXPERIENCE.md or epics.md, run `cd ui && npm run test:tools`.
- **Theme.** `ocu-theme-dark` on `<html>` is the whole theme. Components draw bare roles and never select on the theme. Use design tokens only: lint refuses hard-coded colors.
- **Read bounds (AD-24, AD-36).**
  - A screen and its tool share one bounded declared read.
  - A tool result is capped at 65,536 characters in total, and past that it answers `TOOL.RESULTTOOLARGE`. The only named field exception is the source reads' 60,000-character whole-line cut.
  - A document's whole text is a screen-only payload.
  - The screen shows a view's text and a procedure description whole, and cuts a statement's text at 1,021 characters with `...`.
  - Paging or cutting the class view (DW-2246) changes this contract, so the spine is amended first (Rule 20).
- **Errors (AD-12, AD-39).**
  - The envelope is flat: `{error, reason, code, detail}`. The screen renders `reason`.
  - The client tells an unreachable instance from a 5xx by the result's kind, as the panel and the fault banner already do.
- **Disclosure (AD-3, AD-35).**
  - A reviewed entry classifies each field `ordinary`, `secret` or `opaque`. A field with no entry is secret.
  - A display change for opaque values must not release anything the disclosure matrix withholds.
- **Per-user preferences (AD-50).**
  - Favorites, recents, the panel width and the side bar's open state live on the instance, read through caller-own shell-chrome routes.
  - They are never kept in browser storage and are never screen context.
  - Per-principal reads and writes are gated on the signed-in state.
- **Tests (Conventions › Tests, Rule 30).**
  - A test asserts on its own rows by marker, never on an empty store.
  - A browser spec waits for the screen's answered signal before it counts, clicks or types.
  - A count asserted outside its roster's own test is derived from the registry, descriptor or mirror. The roster pins (`SurfaceCoverage`, `EndpointCoverage` and the floor-only roster) stay literal.
- **Verification (slot A).**
  - Every MCP call takes `server: "ocupilot-slot-a"`.
  - The throwaway is `ocupilot-ci` (52776/1975), and the runner rebuilds it. Browser runs set `OCUPILOT_BROWSER_ORIGIN` and `OCUPILOT_BROWSER_CONTAINER`.
  - Rebuild and `docker cp` the bundle before reading any browser result.
  - Run one ObjectScript class at a time and take totals from `%UnitTest_Result`.
  - Rule 29: targeted classes and specs run in the loop, and the full ObjectScript sweep runs once. The full browser suite is left to CI.
  - Run `npm run build`, whose prebuild checkers must pass, and `npm run test:components`.
  - Rule 30: the fresh check runs forward and in reverse order.
  - Rule 31: extend the sibling, or say why a copy is better.
- **Prose and Git.**
  - Comments state the contract and never narrate stories, runs or mutations.
  - Stage by path.
  - Push the code commit alone, and confirm its run registered before stacking any `[skip ci]` commit.
  - Never touch a release branch.

## UX & Interaction Patterns

- **Shell geometry.**
  - Measures: the rail is 48 px, the side bar 240 px fixed with no resize affordance, and the content column at least 640 px. The panel is 400 px by default and 320 px at minimum. On Home it is `min(50vw, viewport − 48 − 640)`, with a 120 ms width transition (none under reduced motion). The header is 48 px and the status bar 24 px.
  - The panel is the only resizable edge, and it has no close control.
- **Yield order.**
  - When space runs out, three concessions apply in order: (1) the side bar collapses, (2) the panel shrinks to its minimum, (3) the content scrolls inside its own region. They are undone in reverse as width returns.
  - Never an overlay, and the page never scrolls sideways.
  - At 1,280 px and wider, the yield applies only when the side bar is open and the panel is too wide (any panel over 352 px at 1,280 px).
  - Home has no side bar of its own, so the shipped Home content is 912 px at 1,920. DESIGN.md's row says 672 with the side bar open; DW-1148 settles which, at origin.
- **Heights.**
  - Every height is a minimum (`min-height`), except the rows of the virtualized `data-table` and `log-viewer`.
  - Text-only zoom grows a row and never clips it. At 200% zoom a 1,440 px laptop is a 720 px viewport.
- **The panel header** reads: avatar, "Agent co-pilot", the agent picker, New conversation, the full-screen toggle.
  - With two or more enabled definitions, the picker is a text button showing the name, with the accessible name "Agent definition: <name>".
  - Full screen covers the content and the side bar, while the rail, header and status bar stay. The hidden content is `inert`, and Ctrl/Cmd+B is ignored.
- **The data table.**
  - A column's default width follows its kind: 240 px for a name or identifier, 160 px for text, 112 px for a number or status.
  - A header label is never cut.
  - A cut cell shows its whole value in a tooltip, using the tooltip recipe and kept inside the window. No cell carries a `title`.
  - The footer reads "<n> rows" and the "Max rows" field. The same count is the filter's polite match count.
- **The tab strip** is 40 px Material tabs. DESIGN.md says nothing about a strip wider than its column, so the overflow treatment is a design call recorded in DESIGN.md.
- **The empty state** is a title and one or two sentences. On a write-capable list the second line is "Or ask the agent: <a write it could propose here>.", which uses display labels and never an action id.
- **The generic error** reads "Something failed on the instance. Retry; if it keeps failing, check messages.log.", as `role="alert"` with Retry and Open messages.log. An unreachable instance gets its own banner.
- **Live regions.**
  - Polite status messages keep their region mounted and set its text. These include the stale-bundle prompt "A newer version of OcuPilot is installed. Reload to use it." with Reload, the favorites and recents confirmations, and the filter count.
  - A blocking notice replaces the product surface. The blocking notices are version mismatch, no privileges and install unreadable.
- **Gated and transient controls.** They stay focusable with `aria-disabled`, never `disabled`, and are never removed while they hold focus.

## Cross-Story Dependencies

- **This dispatch.** 23.5 runs alone on slot A, dispatched 2026-10-14 after Epic 18 merged into the feature branch (`0d54a098`). Implement runs on Sonnet.
- **The throwaway.** Epic 18's runner tore `ocupilot-ci` down at its close, so this runner brings up its own.
- **Epic 20 alongside.** Epic 20 runs at the same time on slot B (20.9) and touches shared list and detail code (`DetailPage`'s `body`) (inference: overlap with 23.5's tab-strip and table fixes). Forward-merge before implement and at each boundary, and find items by name, not by line.
- **The next stories.** 23.7, then 23.8, 23.9 and 23.10, follow on any idle slot. A CLAUDE.md line in 23.9 changes only through the Planner, with the owner's OK.
