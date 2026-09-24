# Epic 11 Context: The agent explains itself, cites its work, and streams

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Make the agent easy to understand for a judge or voter trying it for the first time. It answers about the screen in front of them without re-fetching what they can already see, and it knows which of its tools act on that screen. A first request for a change ends in a proposal they can confirm, on the screen that will show it. It explains any screen or log entry in one click, offers suggested prompts, and cites the rows it used with chips that link to them. The privilege a proposal needs is named before Confirm, and replies stream token by token. This is polish-week work, and it may keep landing through the voting week. All of it changes the same panel transcript render path, so it is one epic. Stories 11.9 and 11.10 are high priority (owner, 2026-09-24): each runs first and alone on slot B, and Epic 12 hands back at its boundary. After them the order is 11.7, 11.8, 11.1, 11.2, 11.3, 11.4. The data-egress line and the agent audit viewer moved to Epic 16 (16.15, 16.16).

## Stories

- Story 11.9: The agent knows the screen it is on
- Story 11.10: A judge succeeds the first time
- Story 11.7: Token streaming
- Story 11.8: The proposal names the privilege it needs
- Story 11.1: "Explain this screen"
- Story 11.2: Explain a log or audit entry
- Story 11.3: Suggested prompts per screen
- Story 11.4: Citation chips with click-through

## Requirements & Constraints

- **Nothing may break a Release 1 screen or a Release 1 agent write.** Anything that risks either waits for Stage 2. Every new tool declares `read` or `write` at definition time or the build fails. Every new write key goes into Epic 14's governance baseline rather than being left to default.
- **The system prompt stays one build-time constant (11.9, 11.10).** Nothing read at runtime is joined to it, and a definition's override replaces it whole. In substance, 11.9 adds:
  - A turn may open with the screen being viewed: its route, namespace, selected row, rows as shown with the count available, the tools that act on it, and whether the agent is read-only.
  - Answer from that context when it holds the answer. Call a read tool when it does not, or when its rows were cut.
  - A change confirmed through one of the screen's tools refreshes that screen and marks the changed row.
  - While read-only, say so and describe the change instead of proposing it.
  - Use only the tools offered, and say so when none can do what was asked.

  11.10 adds one more statement. When the user asks about, or asks to change, something a screen shows and they are not on that screen, open it with the navigation tool first. Do not navigate when they are already there. The move stays announced and reversible with Back.
- **Two members derived on the instance (11.9).** The kernel adds them and never takes them from the request. A request that carries either is refused `TURN.CONTEXT.INVALID` (422). They are `tools` (wire names of the screen's read tool and of the write tools behind its row actions and primary action) and `readOnly` (the dispatch verdict).
- **Screens that send no rows (11.9).** The application-error list's context carries only the rows it shows, narrowed to its declared summary fields and capped like any other screen. The captured variable table never goes. Form pages and Home still send no field values or rows; a form page gains only the two derived members.
- **Tests (11.9, 11.10).** CI calls no live model. Tests pin each prompt statement, the derived members for a list screen with row actions, a detail screen and a form page, the refusal of a request that sends them, and the new definition defaults. AD-11's existing pins and AD-24's bounds pass unchanged. The seeded-injection test belongs to Story 14.8 and does not exist yet; when it lands, it runs against this prompt. The live behaviour is proven in the owner's check in Story 17.7. That check includes asking "Can you create a web app for me?" from Home, which must open the web applications list before the proposal appears.
- **Definition defaults (11.10).** A new definition, created through the form or the API, is read/write. The flag starts off in both the stored default and the form's initial values. Every write still needs confirmation, and the prohibited set and enforced read-only are unchanged. A stored value from before this story is never rewritten. Tests pin read/write, and a mutation back to read-only must fail them. While a definition's own read-only flag is set, it acts as read-only mode.
- **Transcript follow (11.10).** On Send, scroll so the message and its progress card are in view. When the transcript is at its newest entry, it follows new progress, replies and proposal cards. When the user has scrolled up, it stays put and shows "Jump to latest", which hides once the newest entry is in view. That string is a row in EXPERIENCE.md's fixed-string table and a key in the string table. Under reduced motion, scrolling is instant. A browser spec pins this, since jsdom computes no layout.
- **Streaming (11.7).** It ships only if build step 7 has finished. The turn stays a background job and the panel still polls; neither contract changes, and the render path only gains an append mode. Streamed text is sanitized, markup-free, loads no remote resource, and renders as data. Under reduced motion, or after a failure mid-stream, it resolves to the same final rendering as a non-streamed turn.
- **Privilege line (11.8).** It names the resource from the endpoint's `ResourcesOR()`, which is the list AdminPort already gates on. Whether the user holds it comes from the privilege map the shell already loads. It says "requires", never "sufficient". Confirm stays enabled even when the resource is missing, because the instance is the authority. The audit marker and ledger are unchanged.
- **Explain (11.1, 11.2).** It is one click from the panel on every screen, and the reply cites the read tool it used. Explaining an entry sends that entry only. For an application error that means the summary fields, never the variable table, which can hold patient data. The entry reaches the model as delimited tool-result content.
- **Prompts and chips (11.3, 11.4).** Each screen offers at least three prompts, grouped by task, declared in its descriptor next to its command-box aliases, and choosing one sends it as a turn. A citation chip replaces Release 1's plain-text names and offer to select. It selects the row or opens the screen through the same allow-listed navigation the agent uses, never a URL. A missing target reports "no longer present" and does not fail the screen.

## Technical Decisions

- **AD-11 (untrusted content).** Screen context is a synthetic, never-advertised call and its result. The canonical name is `screen.context`, the wire name `screen_context`, and the id `ocupilot_screen_context`. It sits after `Prompt.CONTEXTPREAMBLE` and before the user's message. A model-issued call with that name is refused as unknown. The constant that 11.9 and 11.10 extend is `BUILTIN` in `Kernel/Agent/Prompt`. The current backtick-and-offer sentence is what 11.4 replaces. `OcuPilot.Test.TurnContext` pins the synthetic call's shape. Rule 3 requires navigation to be allow-listed, announced and reversible.
- **AD-24 (bounds).** Rows are capped at 1 to 1,000 (default 200), the payload at 65,536 characters (cut by whole rows from the end), and each field at 1,000 characters (a cut value ends in U+2026). The payload reports `rowsSent`, `rowsAvailable`, `truncated` and `truncatedFields`, and secret-typed fields never leave. The spine now records `tools` and `readOnly`: they are added before the total-size bound applies, so they count within it. A payload with no rows still carries both, and a form page's `tools` is empty. Later turns replay only earlier user messages and final replies.
- **AD-5 (descriptor as the single source).** `Screen/Context.Build` finds the descriptor by route (`Registry.DescriptorForRoute`). `Screen/Descriptor/Base` exposes `ToolIdentifier`, `PrimaryActionId`, `RowActionIds` and `CommandAliases`, and the tool registry is `Screen/Tool/Registry`. Canonical tool names are `<area>.<screen>.<verb>`; each dot becomes an underscore on the wire.
- **AD-30 (read-only verdict).** Read-only and the kill switch are evaluated on the instance and re-read between turn steps. While either is in force, a write tool returns a structured "blocked" result and no proposal is minted. `readOnly` is the `blocked` answer of `Kernel.Restraint.Verdict(user, definitionId)`, the same source dispatch uses, and is never computed a second time.
- **AD-36 (read contract).** A screen and its tool share one declared read, narrowed by AD-24 with secret fields removed. That is why "answer from context, else call the read" is sound.
- **AD-48 (application errors).** The log is read through `SYS.ApplicationError` via `LogSourcePort`. The detail payload is secret by default and never enters screen context or a tool result.
- **AD-53 / AD-55 (one operation, two callers).** A screen's row action or Save and the agent's confirmed write are two callers of one tool class. That is why the agent names exactly the write tools behind a screen's actions. Read-only and the kill switch gate the agent, never a person's own screen action.
- **Other ADs that apply.** Streaming uses AD-7 and AD-33: progress is untrusted content held in protected storage, and the panel renders it as data. 11.8 uses AD-29: `ResourcesOR()` is a lower bound. Chips use AD-11 rule 3 and AD-13: allow-listed routes and scoped ids. AD-37 makes stored references weak. Under AD-39, a screen renders `reason` and a tool renders `code`.

## UX & Interaction Patterns

- "Primary navigation is the agent": it answers, proposes, and takes the user to the screen it means after announcing the move. 11.10's prompt statement puts this into practice through the navigation tool from Story 4.7.
- Every user-visible string comes from `core/strings.ts` and must appear in EXPERIENCE.md. That includes "Explain this screen" and "Jump to latest".
- The panel's Body paragraph currently says only "newest at the bottom, scrolls independently" (`role="log"`, polite). 11.10 adds the follow rule to that paragraph, in EXPERIENCE.md itself. Under reduced motion, nothing animates.
- The context chip reads `<Screen>, <NAMESPACE> · <N rows> · <provider> · <endpoint host>`. `<N rows>` is what the next turn would send, and it must stay accurate.
- Home's starter prompts (Story 4.10) set the pattern for 11.3. EXPERIENCE.md is canonical: Home shows its prompts.

## Cross-Story Dependencies

- 11.9 builds on Epic 4 (4.4's context payload and `TURN.CONTEXT.INVALID`, 4.7's `shell.screen.open`, 4.11's chip). It also relies on Epic 3's switches and restraint verdict, and on the row and primary actions of Epics 7 to 9 and 12.
- 11.10 extends 11.9's prompt, changes Epic 3's definition defaults (FR-24's read-only flag), and reuses 4.7's navigation. Its live proof, like 11.9's, is the owner's check in Story 17.7.
- 11.2's "variable table never goes" is the same rule 11.9 applies to the error list's context.
- 11.3 declares prompts for every screen that exists when it runs. The editors of Epics 9 and 12 declare their own.
- 11.8 reuses Story 1.9's privilege map. It may carry the same line on row-action tooltips and Save bars from Epics 7 to 9 and 12; where it is not wired, that is recorded as an omission.
- 11.4 reuses 4.7's navigation directive and replaces the citation sentence in the prompt.
- Each ledger entry routed here must be addressed or declined with a reason:
  - 11.1: DW-458, DW-460, DW-1077 (Home's empty route) and DW-1112.
  - 11.2: DW-1610. Error-list context rows carry the shell's namespace and no date, so the agent cannot scope a read or delete to them.
  - 11.3: DW-1147, DW-1158 and DW-1160.
