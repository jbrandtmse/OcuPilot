---
title: 'Story 20.17 (first half of a recommended split): Long blocks in the agent panel start collapsed'
type: 'feature'
created: '2026-10-08'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-20-context.md'
warnings: ['oversized', 'multiple-goals']
deferred: []
---

<intent-contract>

## Intent

**Problem:** The agent panel renders every block at full length: a long reply, a tool result, a proposal card's diff or a compile's output pushes the conversation and the card's Confirm off screen. The agent source edits planned after this story will put whole documents on cards, so the collapse has to exist first. A long card also gives no one-line account of what it changes.

**Approach:**

- One shared long-block component wraps every long block in the panel. A block estimated at more than eight lines shows its first eight lines and a Show more / Show less button.
- A framework-free store remembers each block a person opened, by a stable key, for as long as the conversation lasts.
- A proposal card that holds a long block shows a summary line under its header: the name, how many fields change and, once a compile has run, its outcome. Confirm and the safety lines are never inside a collapsed block.

This plans the first half of the split that Design Notes recommends. The source-edit and create criteria are named there for the stories that follow.

## Boundaries & Constraints

**Always:**

- **Long means an estimate, made from the content.** `estimateLines(text)` adds `max(1, ceil(length / 80))` for each `\n`-separated line. A block is long when the estimate is above 8. jsdom computes no layout, so geometry never decides.
- **Collapsed means clamped.** The whole text stays in the DOM and is read in full by a screen reader. The region is clipped to `8lh` with `overflow: hidden`, with no fade and no animation. Nothing is removed from the page.
- **The control.**
  - A native `<button type="button" class="ocu-long-block-toggle">` sits under the region. It reads `STRINGS.longBlockShowMore`, or `longBlockShowLess` once open.
  - It carries `aria-expanded` and `aria-controls`, naming the region's id. The id is derived from the block's key, never from a counter, so a streamed turn and a plain one render the same DOM.
  - A short block renders no control and no wrapper class.
  - Focus moving into a collapsed region opens it, so focus is never hidden.
  - Toggling neither scrolls the transcript nor moves focus.
- **Keys.**
  - A turn's blocks use `<conversation id>:t<turn index>`, plus `:message`, `:reply` or `:s<seq>:arguments` / `:s<seq>:result`.
  - A card's blocks use `p:<proposal id>`, plus `:diff`, `:rationale`, `:impact`, `:reverse`, `:output` or `:draft`.
  - A card given no `blockKey` (the example card), or a tool-call card given no `turnKey`, gives every block the key `''`. An empty key keeps its state in the component only.
- **The store (AD-19).** `LongBlocks` in `ui/src/app/core/long-blocks.ts` imports no `@angular/core`. It is a plain subscribable built in `main.ts` and cleared by `endSession()` on sign-out. A new conversation has a new id, so its keys never meet an earlier conversation's.
- **Wrapped blocks:**
  - the user message;
  - the finished reply (never the streamed block, which stays `inert` and unwrapped);
  - a tool-call card's arguments and result;
  - a proposal card's changed rows (one region), rationale, expected impact, reverse and output;
  - the panel's draft script.
- **Never inside a region, on any card:**
  - the header and the summary line;
  - the "N unchanged fields" disclosure;
  - the destructive bar, the consequence, impact, privilege and runs-as lines;
  - the masked secret fields;
  - Confirm, Cancel and the status line.
- **The summary line**, `<p class="ocu-proposal-card-summary">` under the header, shows whenever a card holds a long block.
  - Its first part is `proposalSummaryFields` (`<name>: <n> changed fields`), or `proposalSummaryField` when n is 1, or `cardTitleName(view)` alone when n is 0.
  - Once a confirmed card carries output whose `errors` is a boolean, a second part follows: `proposalSummaryCompiled` or `proposalSummaryCompileErrors`.
- The tool-call result's twelve-line inner scroll and the card output's `30vh` cap are replaced by the collapse.
- Every new literal sits in EXPERIENCE.md's Fixed strings and in `strings.ts`. Keys go beside `proposalUnchangedFieldsDisclosure`, never at the file's end.

**Never:**

- No ObjectScript change, route, tool, error code, governance key or descriptor; `screens.generated.ts` is not regenerated.
- No `ResizeObserver` or measured geometry; no `innerHTML`; no third-party library.
- No change to `reply.ts`, `code-block.ts`, the tool-call card's own disclosure, the unchanged-fields disclosure, or what a reply renders (AD-11 rule 4).
- No collapse in the screens: the long block is the panel's.
- No quoted string added to EXPERIENCE.md's tool-call-card row, whose eight quoted spans `strings.test.mjs` pins.
- No new line inside EXPERIENCE.md's Fixed strings table or between it and :645, which would move `taskCreate`'s citation.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Short | A finished reply of 8 lines, each at most 80 characters | Rendered whole; no control | none |
| Long | 9 lines; or one line of 721 characters (estimate 10) | Region clamped to 8 lines; "Show more", `aria-expanded="false"`; full text in the DOM | none |
| Open and close | Click, Enter or Space on the control | Whole block; "Show less", `aria-expanded="true"`; pressing again clamps it | none |
| Re-render | An opened reply, then the next poll and a second turn | Still open | none |
| Focus | A collapsed reply with a citation chip on its 12th line; Tab reaches the chip | The block opens before the chip is shown with focus | none |
| Streaming | A 30-line reply still streaming | Unwrapped, no control. Once finished it renders collapsed | none |
| Tool result | An expanded tool-call card whose result is 4,096 characters | Result clamped with its own control; no inner scroll; the `pre` keeps no child element | none |
| Long card | A live proposal with 12 changed rows | Rows region clamped; summary `<name>: 12 changed fields`; Confirm enabled, and pressing it confirms with the region closed | none |
| Compile outcome | A confirmed compile whose answer is `output {lines: 10 lines, errors: true}` | Output clamped; the summary reads `<name>` then "Compiled with errors."; `errors:false` reads "Compiled without errors." | none |
| Example card | The configuration-empty example | No control, no summary, nothing focusable | none |
| Reset | New conversation; sign-out | No block reads open | none |

</intent-contract>

## Code Map

Client (`ui/`). The anchors were read by the plan's investigator; confirm each at implement.

- `src/app/shell/panel.ts`:
  - transcript template :480-545: user message :482, `app-tool-call-card` :494, `app-proposal-card` :497-517 with the projected draft `app-code-block` :512-516, the finished `app-reply` :519-529, the `inert` streamed block :533-539 (left alone);
  - `turns` getter :1034-1093 (`entries().map`): add `key`, `messageLines` and `replyLines`;
  - the proposal view builder :1124 (`output`), and `outputLinesOf`'s caller near :1400;
  - optional injections :628-631 (`ExplainEntry`, `FixFinding`), the pattern for `LongBlocks`;
  - track keys: turns `$index`, steps `step.seq`, cards `proposalId`, so instances survive polls.
- `src/app/shell/proposal-card.ts`:
  - header :119-135;
  - changed rows :137-167;
  - unchanged disclosure :181-209 (stays outside every region);
  - rationale, impact and reverse :212-226;
  - output `app-code-block` :340-342 and getters :928-935;
  - impact, privilege and runs-as lines :346-374;
  - footer :375-389.
- `src/app/shell/tool-call-card.ts`: body :56-67 (`ocu-tool-call-arguments` :58, `pre.ocu-tool-call-result` :61). Its own `manualExpanded` disclosure :33-38 and :129-136 is unchanged.
- `src/app/core/turn.ts`: `outputLinesOf` :482-487, beside which `outputErrorsOf` goes; `conversationId()`.
- `src/app/core/proposal-view.ts`: `ProposalCardView` :61, `ProposalDiffRow` :35, `cardTitleName` :733.
- `src/app/core/panel-layout.ts` `PanelState` :136-416: the store idiom, with `subscribe` and `notify` near :405-415.
- `src/main.ts`: stores built at :166-177 and provided at :275-276. `src/app/app.ts` :736-744 calls each `endSession()`.
- `src/styles/_components.scss`:
  - `.ocu-tool-call-result` cap :4368-4381;
  - `.ocu-proposal-card-output` `30vh` :7688-7691;
  - `ocu-focus-ring` :42-46 and its code-surface variant :4127-4131;
  - `.ocu-visually-hidden` :3738.
- `src/app/core/strings.ts`: `proposalUnchangedFieldsDisclosure` :181 (insert beside it); `stringFor` :6274. Each Fixed key carries `/** EXPERIENCE.md:NNN */`.
- `tools/client-lint.mjs`:
  - no literal text nodes or quoted strings in `{{ }}`;
  - `@if` / `@for` conditions are paren-free member references;
  - tokens only for color;
  - non-ASCII as `\uXXXX`.
- `tools/strings.test.mjs`:
  - bound 150-3000 at :604-607. The plan measured 2,917 literals, so six more is 2,923;
  - tool-call-card row's eight quoted spans :197-215;
  - line references :839-883.

  `tools/citations.test.mjs` :136-160.
- Templates:
  - `browser/transcript-follow.browser-spec.mjs`: `scriptReply` and `TextReply`;
  - `browser/turnprobe-spec.mjs`;
  - `browser/proposal-demo.browser-spec.mjs`, for a scripted many-field create card and its cleanup.

**Rule 30: tests that assert a shape this story changes.** "Clamp" means the text stays in the DOM.

| File | What it asserts | Action |
|---|---|---|
| `browser/transcript-follow.browser-spec.mjs` :65-73, :189-337 | 24-48-paragraph replies overflow the transcript | Update: a helper opens each finished reply's control after `waitForReplies`, so every leg still overflows |
| `browser/stream-reply.browser-spec.mjs` :228-236, :262-280 | overflow while streaming; the final DOM equals the plain run's | Re-run: the streamed block is unwrapped, and ids derive from keys |
| `browser/reply.browser-spec.mjs` :200-291 | a 13-line mixed reply's computed styles | Re-run: clamp |
| `browser/seeded-injection.browser-spec.mjs` :206-218 | the result `pre`'s text, with no children | Re-run: the wrapper sits outside the `pre` |
| `browser/proposal-demo.browser-spec.mjs` :397-405 | 44 unchanged rows after the disclosure | Re-run: the disclosure is outside the region |
| `browser/copy-out-draft.browser-spec.mjs` :203, :287, :321 | copy-button clicks in the draft and in a reply's code frame | Re-run. If a frame lies past line 8, open its block first |
| `browser/proposal-card.browser-spec.mjs` :240, :264; `agent-sql.browser-spec.mjs` :180; `screen-permissions-agent.browser-spec.mjs` :175 | diff-row counts and text | Re-run: clamp |
| `browser/citation-chips.browser-spec.mjs` :117-140; `turn.browser-spec.mjs` :153-438 (`.ocu-tool-call-toggle` counts :329-334); `proposal-confirm.browser-spec.mjs` | chips, tool toggles, Confirm | Re-run: the new class is distinct |
| `src/app/shell/panel.spec.ts` :4855-4874 (streamed equals plain; no button in the streamed block :4865), :4079 and :4094 (`app-reply` counts), :3504-3509 (output) | | Re-run; extend :3504 for the outcome |
| `src/app/shell/proposal-card.spec.ts` :444-453 (the example card has nothing focusable), :1137-1144 (output `pre`); `tool-call-card.spec.ts` :131-149; `proposal-card-draft.spec.ts` :140 | | Re-run |
| `tools/strings.test.mjs`, `citations.test.mjs`, `client-lint.test.mjs`, `angular-json.test.mjs` :542-547 | | Re-run, with no edit |

## Tasks & Acceptance

**Execution** (in dependency order):

- `ui/src/app/core/long-blocks.ts` (new, framework-free):
  - `LONG_BLOCK_LINES = 8`, `LONG_BLOCK_WIDTH = 80`, `estimateLines(text)`, `isLong(lines)` (`> 8`), and `blockId(key)`, which is `ocu-long-block-` plus the key with every character outside `[A-Za-z0-9_-]` turned into `_`.
  - `class LongBlocks`: `isOpen(key)`, `setOpen(key, open)`, `subscribe(listener): () => void`, `endSession()`. An empty key is never stored.
- `ui/src/app/core/strings.ts`: add six keys beside :181, each citing the Fixed-strings row the spec gate amends (`EXPERIENCE.md:604`):
  - `longBlockShowMore`: "Show more"
  - `longBlockShowLess`: "Show less"
  - `proposalSummaryFields`: "<name>: <n> changed fields"
  - `proposalSummaryField`: "<name>: 1 changed field"
  - `proposalSummaryCompiled`: "Compiled without errors."
  - `proposalSummaryCompileErrors`: "Compiled with errors."
- `ui/src/main.ts`: build `new LongBlocks()` beside `PanelState` and provide it.
- `ui/src/app/app.ts` :736-744: call its `endSession()` beside the others.
- `ui/src/app/shell/long-block.ts` (new): `app-long-block`, OnPush, zoneless.
  - Inputs `key` (default `''`) and `lines` (default 0).
  - It injects `LongBlocks` with `{ optional: true }`, falling back to a private instance, and mirrors it into a signal on subscribe, releasing it on destroy.
  - Template: `div.ocu-long-block` with `[class.ocu-long-block-collapsed]`, then `div.ocu-long-block-region` with `[attr.id]` and `(focusin)` around `<ng-content />`, then the control under `@if (long)`.
- `ui/src/styles/_components.scss`:
  - add `.ocu-long-block-collapsed > .ocu-long-block-region { max-height: 8lh; overflow: hidden; }` and the toggle as a text button, with `ocu-focus-ring` and a target of at least 24×24 px;
  - remove the `max-height` and vertical scroll from `.ocu-tool-call-result` and `.ocu-proposal-card-output`, keeping the horizontal scroll.
- `ui/src/app/core/turn.ts`: add `outputErrorsOf(output): boolean | null`. It answers `errors` when `lines` is an array and `errors` is a boolean, and `null` otherwise. Keep it add-only.
- `ui/src/app/shell/panel.ts`:
  - The `turns` view gains `key` (`<conversationId() ?? ''>:t<index>`), `messageLines` and `replyLines`.
  - Wrap the user message and the finished `app-reply` in `app-long-block`. The reply's wrapper sits inside `.ocu-panel-message-agent`, so `app-reply` keeps its class and count.
  - Pass `[turnKey]="turn.key"` to `app-tool-call-card`, and `[blockKey]="proposal.proposalId"` and `[outputErrors]` to `app-proposal-card`.
  - Wrap the draft `app-code-block` under the key `p:<id>:draft`, with its lines computed in TS.
  - Carry `outputErrors` from the confirm answer beside `output`.
- `ui/src/app/shell/tool-call-card.ts`: add input `turnKey` (default `''`). Wrap the arguments `p` and the result `pre`, each whole and with the wrapper outside the element, under keys `<turnKey>:s<seq>:arguments` / `:result`.
- `ui/src/app/shell/proposal-card.ts`:
  - Add inputs `blockKey` (default `''`) and `outputErrors` (default `null`).
  - Wrap the changed-rows `@for` in one region (`:diff`; lines are the sum of each row's `field before after` estimate). Wrap rationale, impact and reverse each, and the output block.
  - Add the summary paragraph under the header, its first part a span and the outcome a second span, shown when `summaryVisible`.
  - Keep the unchanged disclosure and every line under Never-inside outside all regions.
- Tests (new):
  - `ui/tools/long-blocks.test.mjs` (`node --test`): the estimate at the boundaries (8 lines; 9 lines; 80 and 81 characters; empty text is 1); `blockId`'s determinism; open/close per key; `endSession`; listeners.
  - `ui/src/app/shell/long-block.spec.ts`: no control when short; when long, the class, the label, `aria-expanded`, `aria-controls` equal to the region id, click toggling, `focusin` opening, the state surviving re-creation with the same key and store, and no state stored for an empty key.
  - `ui/browser/panel-collapse.browser-spec.mjs` against `ocupilot-b-ci`, with scripted turns (`TurnProvider.TextReply`, as `transcript-follow` does):
    - a 20-line reply is clamped (`scrollHeight > clientHeight` on the region), and an 8-line reply has no control;
    - Enter on the control opens the reply, which stays open through a second turn;
    - Tab into a collapsed block's link opens it;
    - a scripted create proposal with at least nine fields (the `proposal-demo` template) shows the summary and its count, with Confirm enabled and inside the viewport, and the region closed; Confirm confirms; the spec deletes what it created in `after`.
- Tests (edited): the Rule 30 table. Add legs to `panel.spec.ts` (key persistence across `nextPoll`, the streamed block unwrapped, and the outcome at :3504), `proposal-card.spec.ts` (summary forms, safety lines and Confirm outside the region, and the example card) and `tool-call-card.spec.ts` (both wraps).

**Acceptance Criteria:**

- **AC1 (long blocks start collapsed).** Given any wrapped block the Boundaries list, when it renders, then a block estimated above eight lines is clamped to eight with the control, a block at or under eight renders whole with no control, and the streamed block never collapses.
- **AC2 (the control).** Given a long block, when a person uses the control by click, Enter or Space, or moves focus into the collapsed region, then it opens or closes, its label and `aria-expanded` follow, and `aria-controls` names the region.
- **AC3 (stays open).** Given a block a person opened, when the panel re-renders on a poll, a later turn or a card's phase change, then it stays open; and given a new conversation or a sign-out, no block reads open.
- **AC4 (the card).** Given a proposal card holding a long block, when it is shown, then the summary line names the target and the changed-field count, every Never-inside element is outside the regions, and Confirm confirms with every region closed.
- **AC5 (compile outcome).** Given a confirmed card that holds a long block and whose output carries `errors`, when it renders, then the summary adds "Compiled with errors." or "Compiled without errors.".
- **AC6 (strings).** Given the six literals, when `npm run test:tools` runs, then each is in EXPERIENCE.md's Fixed strings and held equal in `strings.ts`.
- **AC7 (Integration, Rule 1).** Given `Panel`, `ProposalCard` and `ToolCallCard` consuming `LongBlock` and `LongBlocks`, when a scripted long reply and a long card render in a real browser on `ocupilot-b-ci`, then they behave as AC1 to AC4 state.

## Spec Change Log

## Review Triage Log

## Design Notes

**Governing ADs.**

- AD-19: the store is framework-free, and components mirror it.
- AD-11 rule 4 and AD-33: a reply's rendering path is untouched; the wrapper adds a button and a clamp only.
- AD-6, AD-34 and AD-10's destructive treatment: Confirm and every safety line stay outside the collapse.
- AD-39's fifth exception: compile lines reach the card only, so only the flag joins the summary.
- AD-58: the read-back line is unchanged.
- AD-47: no new request and no injected markup.

The plan proposes no spine amendment for this half (Rule 6). The UX amendments are below.

**Why an estimate and a clamp.** jsdom has no layout, so a content estimate is the only rule a component spec can pin. Clamping keeps every existing `textContent` assertion true, keeps the live log from re-announcing on toggle, and keeps the text whole for a screen reader. The cost is that focusable elements in the clipped part stay in the tab order, which the focus-opens rule answers. At 80 characters a line, the estimate is at most the real line count in a panel narrower than 80 characters a line, so a control never opens to nothing there. A full-screen panel may show a control on a block that fits (inference).

**Split (owner allowance; the orchestrator approves and charters).**

- **Recommended: three stories.**
  - **This spec, Story 20.17:** the panel collapse, ordered first, retitled "Long blocks in the agent panel start collapsed".
  - **Story B (proposed 20.19): agent edits of existing classes and routines.**
  - **Story C (proposed 20.20): agent creates.**
- **Why three.** Each later half carries its own new mint behavior and rosters:
  - Story B: a source read for the model, the posture question Q2, a text diff on the card, and the advertising flip.
  - Story C: the create kind, name rules refused at the mint, and new keys.

  20.15 needed three implement passes, and both halves together would be larger than it.
- **Two stories instead.** If the orchestrator prefers two, B and C's lists below form one story.

**Story B's criteria (the epics block's ACs 1-5, plus these measured needs):**

- Both Saves advertised and agent-offered; `Baseline.cls` :195-196 `true` (CONTENDED non-add-only); `explorer.sqldata.save` (:199) stays unadvertised and pinned.
- The model reads a document's source before proposing (Q2).
- The tool takes the new text, or exact replacements the instance applies over the fresh read. Story B's plan picks one: the provider's 32,000-token output caps a whole text near 100-130 KB (inference).
- The version and the fingerprint come from the fresh read's `Modified`. A document changed after the mint is refused at confirm (fingerprint, then the vendor's 409).
- The mint stores the before and after text. The card renders a line diff, moving `areas/system-explorer/line-diff.ts` (Myers) to `core/`, inside one long block, with the summary "<name>: +a / -r lines". The result handed to the model stays within 65,536 characters: today an oversized `changed` answers `TOOL.RESULTTOOLARGE` after the row is stored (`Dispatch.cls` :342).
- `OCUPILOTCODE` is refused at the mint too: `Prohibits` runs only at confirm (`Confirm.cls` :299).
- The card shows the compile output and outcome; the agent marker; 20.18's refusal names `explorer.classes` / `explorer.routines`, the saves' `DESCRIPTORCLASS`.
- Rosters:
  - `ExplorerSave.cls` :203-209 and :232-279;
  - `ExplorerDescriptor.cls` :157, :167, :182-195;
  - `Governance.cls` :34; `GovernanceBaseline.cls` :15;
  - `SurfaceCoverage.cls` :350-351;
  - the comments in `ToolEmit.cls` :89 and `ToolSetFull.cls` :193.
- Spine amendments:
  - AD-53 and AD-8's unadvertised lists;
  - AD-36 and AD-24 (the source read);
  - AD-61 rule 6 (the vendor's #5883 arrives at 400 and maps to `PORT.VALIDATION` today);
  - AD-10 (the code arm at the mint);
  - the "because the agent never authors code" clause on `explorer.sqlquery.run` (AD-53).

**Story C's criteria (the epics block's ACs 6-9):**

- `explorer.classes.create` and `explorer.routines.create`, with `CREATES = 1` (AD-54) through `AtelierPort`, keys `true` (add-only). `SaveSet` refuses an absent document today (404 `EXPLORER.DOCUMENT.ABSENT`).
- The fingerprint is the SAVEDOCS absence. The confirm sends `PutDoc` with no `If-None-Match`, which the vendor refuses 409 once the name exists. That refusal needs a create-worded sentence: today's says "changed … after you opened it".
- Name rules at the mint:
  - the header names the target exactly, and a class name carries its package;
  - `OcuPilot*` is refused;
  - every `%` name is refused (Q3);
  - a name whose destination database is mounted read-only is refused by name.
- The target is the current namespace, behind the existing routines-database WRITE pair, settled against the list screen's effective pairs (20.15) and named by 20.18's refusal. The card shows the whole new document as added lines in one long block.
- Rosters: `ReadTool.cls` :93-94 (308 → 310), `SurfaceCoverage`, `ExplorerDescriptor`, `Baseline.cls`.

**Measured on `ocupilot-b-ci`, 2026-10-08, for Stories B and C.** The session ran as `irisowner` (`%All`). Every `OcuProbe2017*` probe and helper was removed and checked absent.

- M1: `PutDoc` on an absent name answers 201 with or without `If-None-Match`, which the vendor ignores when the document is absent. On a present name it answers 409 with none, 200 with the current `ts`, and 409 with a stale one. Routines behave the same.
- M2: SAVEDOCS on an absent name answers `{Present:"", Modified:"", Absent:<name>}`. `PresentSet`, SAVE and COMPILE answer 404 `EXPLORER.DOCUMENT.ABSENT`. When another process created the name, every absence signal flipped. The docnames read costs 125-145 ms for classes in USER.
- M3: `cuk` compile lines:
  - success: a first line `""`, then "Compiling class …", then "Compilation finished successfully in …", with `errors:false`;
  - failure: lines naming the class and error, ending "Detected N errors …", with `errors:true`.

  Put plus compile of a 150-line class took 143-166 ms. `PutDoc` stores malformed class text without refusing it.
- M4 (destinations):

  | Name | USER | HSCUSTOM |
  |---|---|---|
  | `%` class | IRISLIB (read-only) | IRISLIB (read-only) |
  | `%Z.` package, `%Z*` routine | IRISSYS (writable) | IRISSYS (writable) |
  | `Ens` / `EnsLib` | ENSLIB (read-only) | ENSLIB (read-only) |
  | `HS` | USER | HSLIB (read-only) |

  Read with `%SYS.Namespace.GetPackageDest` / `GetRoutineDest` and `SYS.Database`. A PUT of `EnsLib.X.cls` in HSCUSTOM was refused #5883 at HTTP 400, which the port maps to `PORT.VALIDATION`; nothing was written.
- M5: no documented write-free syntax check exists. The `cvt/doc/xml` route fails with `<UNDEFINED>` on this build. Classes can be checked without writing through `^||%oddDEF` plus `%Compiler.UDL.TextServices.SetTextFromArray`, an undocumented mechanism. `%Library.Routine.CheckSyntax` handles INT only.
- M6: `Header` keeps the text's own spelling. A package-less `Class X` is stored as `User.X`. A URL and header that disagree store the header's class while the port reports "nothing was saved".
- M7: a new document's SAVEDOCS `Modified` equals its `PutDoc` `ts`, a save with it answers 200, and the list shows it at once.

**Questions for the orchestrator** (for the owner). This spec builds none of these; each shapes the later halves.

| # | Question | Options | Recommended |
|---|---|---|---|
| Q1 | Split | **A** three stories, the collapse first (this spec). **B** two: the collapse, then edits and creates together. **C** none | A |
| Q2 | Posture: today no tool returns a class's or routine's source to the model (AD-36: the whole text is screen-only). To propose an informed edit, source must reach the provider, and its comments are untrusted content (AD-11). | **A** a bounded agent source read: one document, at most about 60,000 characters within AD-24's 65,536, truncation reported, through AD-60's sanitizer; amends AD-36 and AD-24. **B** edits only from what the person pastes. **C** no edits of existing documents, creates only | A |
| Q3 | Posture: `%` classes land in read-only IRISLIB, but `%Z*` routines and the `%Z` package land in writable IRISSYS, shared by every namespace (M4). | **A** refuse every `%` name for the agent's save and create, leaving a person's Save unchanged. **B** refuse only read-only destinations | A |
| Q4 | The compile outcome "on the card": a pre-confirm outcome would need M5's undocumented class check, and nothing exists for MAC or INC. | **A** before Confirm, the card says the save compiles as you; the outcome shows after Confirm, in the output and the summary (this story builds the summary). **B** use the undocumented class check before Confirm | A |

**Spine and UX amendments for the spec gate.**

- **If Q1 is A or B, AD-53:**
  - replace "Story 20.17 makes both Saves agent-offered" with "Story 20.19 makes both Saves agent-offered";
  - replace "It covers new classes and routines too" with "Story 20.20 covers new classes and routines";
  - replace "Until Story 20.17 ships" with "Until Story 20.19 ships".

  Use the keys the orchestrator charters. The epic context's "AD-53 reversed (Story 20.17)" heading and 20.17's epics block move with it: a Rule 5 retitle, so `SPRINT_PLAN generate`.
- **EXPERIENCE.md** (no new line between :604 and :645):
  - **:604, the last Fixed-strings row.** Append to its strings cell ` · "Show more" · "Show less" · "<name>: <n> changed fields" · "<name>: 1 changed field" · "Compiled without errors." · "Compiled with errors."`. Append to its usage cell: "; the agent panel's long-block control, and a proposal card's summary line with its compile outcome (Story 20.17) [ADDED 2026-10-08, Story 20.17]".
  - **:628 message-user.** Append "A message longer than eight lines starts collapsed (panel › Long blocks) [AMENDED 2026-10-08, Story 20.17]."
  - **:629 message-agent.** Append "A finished reply longer than eight lines starts collapsed; a streaming reply never does (panel › Long blocks) [AMENDED 2026-10-08, Story 20.17]."
  - **:631 tool-call-card.** Append, with no quotes, "In the body, the arguments and the result each collapse past eight lines (panel › Long blocks) [AMENDED 2026-10-08, Story 20.17]."
  - **:632 proposal-card.** Append "Its changed rows, rationale, impact, reverse, output and script collapse past eight lines, and such a card shows a summary line under its header (→ `proposal-card` below) [AMENDED 2026-10-08, Story 20.17]."
  - **`### panel`.** After **Body**, add this paragraph:

    > **Long blocks** [ADDED 2026-10-08, Story 20.17]. A transcript block longer than eight lines (each source line, and each further 80 characters of a long line) starts collapsed. It shows its first eight lines and, under them, a text button reading Show more, or Show less once open: a native button (click, Enter, Space) carrying `aria-expanded` and `aria-controls`. Focus moving into a collapsed block opens it. An opened block stays open for the conversation, through every poll and later turn, and a new conversation or sign-out forgets it. The whole text stays in the page for a screen reader. A streaming reply never collapses.

  - **`### proposal-card`.** After **diff-rows**, add this bullet:

    > - **summary line** [ADDED 2026-10-08, Story 20.17]: on a card holding a block longer than eight lines, under the header, the name and how many fields change, and once a compile or import has run, whether it compiled with errors. The unchanged disclosure, the destructive bar, the consequence, impact, privilege and runs-as lines, the secret fields, Confirm, Cancel and the status line are never inside a collapsed block, so confirming never requires opening one.

- **DESIGN.md:**
  - **:1160.** Replace "at most twelve lines before the block scrolls inside itself" with "each collapsed past eight lines under the long-block control and shown whole once opened (EXPERIENCE.md › panel › Long blocks) [AMENDED 2026-10-08, Story 20.17]".
  - **:1178.** Replace "The card's default height is two changed rows and one disclosure line, whatever the payload carries." with "Changed rows past eight lines collapse under the long-block control, and the card then shows a summary line under the header [AMENDED 2026-10-08, Story 20.17: was a two-row default height the build never applied]."

**Integration ACs (Rules 1 and 2).**

- **Consumes:** `Panel`, `ProposalCard`, `ToolCallCard`, `TurnStore.conversationId()` and the confirm answer's `output`. AC7 exercises them on a real instance.
- **Consumed-by:**
  - Story B: the code diff, in one long block, with the lines summary;
  - Story C: the whole new document;
  - Story 20.12: Investigate's long replies (inference).

**Rule 11** (checked 2026-10-08 against `.worktrees/epic-18` `origin/feature…HEAD` and `status -s`):

| File | Edit | Status |
|---|---|---|
| `ui/src/app/core/strings.ts` | six keys beside :181 | CONTENDED, add-only. Epic 18 adds at :6205 |
| EXPERIENCE.md | the spec gate's in-row amendments at :604 and :628-632, and two additions after :699 | CONTENDED non-add-only. Epic 18's hunks are :163-169 and :465-471, which do not overlap |
| DESIGN.md | :1160 and :1178 | not contended |
| `shell/*`, `core/long-blocks.ts`, `core/turn.ts`, `main.ts`, `app.ts`, `_components.scss`, the specs | | not contended |

**Budgets.**

- Bundle: the last build was 3.12 MB against the 3165 kB warning. The component, store and CSS should add about 5-9 kB (inference), so the budget is unchanged. Stop and report if the build passes 3165 kB.
- Fixed strings: 2,917 + 6 = 2,923, within the 3,000 bound.

**Ledger.** This story owns no ledger entries.

## Verification

**Shared surfaces (Rule 30):**

- the agent panel transcript's user message and finished reply;
- the tool-call card body's arguments and result;
- the proposal card: changed rows, rationale, impact, reverse, output, the new summary line and the draft script;
- EXPERIENCE.md's message-user, message-agent, tool-call-card and proposal-card rows, and the Fixed strings.

**Standing criterion (Rule 30):** existing tests that assert a surface this story changes are updated in this story, and every test the story adds or changes passes on a freshly built instance and in either order.

**Setup (slot B):**

- Before a browser run: `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`.
- Set `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777` and `OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci`.
- Run one spec file per call, or one `node --test --test-concurrency=1` run, and never re-submit after a client-side timeout.

**Commands:**

- `(loop)` `cd ui && node --test tools/long-blocks.test.mjs tools/strings.test.mjs tools/citations.test.mjs tools/client-lint.test.mjs tools/angular-json.test.mjs`: expected pass.
- `(loop)` `cd ui && npm run test:components`: expected pass, including `long-block.spec.ts`, `panel.spec.ts`, `proposal-card*.spec.ts` and `tool-call-card.spec.ts`.
- `(loop)` `cd ui && node --test --test-concurrency=1` over these browser specs, each with `.browser-spec.mjs` under `browser/`: `panel-collapse`, `transcript-follow`, `stream-reply`, `reply`, `seeded-injection`, `proposal-demo`, `copy-out-draft`, `proposal-card`, `proposal-confirm`, `citation-chips`, `turn`, `agent-sql`, `screen-permissions-agent`. Expected: pass.
- `(loop)` `bash scripts/lint-docs.sh`: expected clean.
- `(once, before dev_complete)`, in this order:
  1. `git diff --name-only <baseline>` lists no `src/OcuPilot` path, so no ObjectScript changed and no class sweep applies (Rule 29's sweep covers ObjectScript a story touches). Record the check.
  2. `cd ui && npm test && npm run build`: expected pass, with the bundle under 3165 kB.
  3. `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS`: expected pass.
- `(CI)` The full browser suite runs in CI's shards only (Rule 29).

**Planned pinning mutations (Rule 19).** Apply each, observe red, revert to a byte-identical tree, and record a `mutation:` line here.

| AC | Mutation | Expected red |
|---|---|---|
| AC1 | `isLong` answers false | `long-blocks.test.mjs`; `panel-collapse` clamp leg |
| AC2 | the `(focusin)` handler removed; separately, `aria-expanded` dropped | `long-block.spec.ts` |
| AC3 | the component ignores `LongBlocks` and keeps local state | `panel.spec.ts` re-render leg; `panel-collapse` second-turn leg |
| AC4 | Confirm moved inside the diff region; separately, the summary not rendered | `proposal-card.spec.ts`; `panel-collapse` card leg |
| AC5 | `outputErrorsOf` answers `null` | `panel.spec.ts` :3504 leg |
| AC6 | one `strings.ts` value differs from the Fixed row | `strings.test.mjs` |
| AC7 | the panel stops wrapping the finished reply | `panel-collapse` clamp leg |

## Auto Run Result

Status: ready-for-dev
Blocking condition: none

Planned the first half of a recommended three-way split: the panel-wide long-block collapse and the proposal card's summary line, client only. Stories B (agent edits of existing classes and routines) and C (agent creates) are named with their criteria and the measurements on `ocupilot-b-ci` under Design Notes. Q1-Q4 go to the orchestrator; each recommended option is the one assumed.
