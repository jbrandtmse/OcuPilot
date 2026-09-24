# Epic 11 Context: The agent explains itself, cites its work, and streams

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Make the agent self-explanatory to a judge or voter trying it for the first time. It answers about the screen in front of them without re-fetching what they can already see, and it knows which of its tools act on that screen. It explains any screen or log entry in one click, offers suggested prompts, and cites the rows it used with chips that take you to them. The privilege a proposal needs is named before Confirm, and replies stream token by token. This is polish-week work, allowed to keep landing through the voting week. All of it changes the same panel transcript render path, so it is one epic. Story 11.9 runs first and alone (high priority, owner 2026-09-24). The rest run in the order 11.7, 11.8, 11.1, 11.2, 11.3, 11.4. The data-egress line and the agent audit viewer moved to Epic 16 (16.15, 16.16).

## Stories

- Story 11.9: The agent knows the screen it is on
- Story 11.7: Token streaming
- Story 11.8: The proposal names the privilege it needs
- Story 11.1: "Explain this screen"
- Story 11.2: Explain a log or audit entry
- Story 11.3: Suggested prompts per screen
- Story 11.4: Citation chips with click-through

## Requirements & Constraints

- **Nothing may break a Release 1 screen or a Release 1 agent write.** Anything that risks either waits for Stage 2. Every new tool declares `read` or `write` at definition time or the build fails. Every new write key goes into Epic 14's governance baseline rather than being left to default.
- **The system prompt stays one build-time constant (11.9).** Nothing read at runtime is joined to it. A definition's override replaces it whole. The prompt must also say, in substance:
  - A turn may open with the screen being viewed: route, namespace, selected row, rows as shown with the count available, the tools that act on that screen, and whether the agent is read-only.
  - Answer from that context when it holds the answer. Call a read tool when it does not, or when its rows were cut.
  - A change confirmed through one of the screen's tools refreshes that screen and marks the changed row.
  - While read-only, say so and describe the change instead of proposing it.
  - Use only the tools offered, and say so when none can do what was asked.
- **Two members the kernel derives (11.9).** They are added to a turn's screen context on the instance and never taken from the request. A request that carries either member is refused as an invalid context (`TURN.CONTEXT.INVALID`, 422):
  1. The wire names of the screen's read tool and of the write tools behind its row actions and primary action, from the descriptor registry.
  2. The turn's read-only verdict, which must be the same verdict dispatch enforces.
- **Screens that send no rows (11.9).** The application-error list loads through its own endpoint. Its context carries only the rows it shows, narrowed to its declared summary fields and capped like any other screen. The captured variable table never goes. Form pages and Home still send no field values or rows; a form page gains only the two derived members.
- **Tests (11.9).** AD-11's seeded-injection test and AD-24's bounds pass unchanged, and the two added members count within AD-24's bounds. CI calls no live model, so tests pin three things: the prompt's required statements; the derived members for a list screen with row actions, a detail screen and a form page; and the refusal of a request that sends them. The model's live behaviour is proven in the owner's check in Story 17.7.
- **Streaming (11.7).** It is conditional on build step 7 having finished. The turn stays a background job, the panel still polls, and neither contract changes; the render path only gains an append mode. Streamed text follows every Release 1 rule: sanitized, markup-free, no remote resource, and rendered as data. Under reduced motion, or after a failure mid-stream, the reply resolves to the same final rendering a non-streamed turn produces.
- **Privilege line (11.8).** It names the resource from the endpoint's `ResourcesOR()`, which is the list AdminPort already gates on. It says whether the user holds it, read from the privilege map the shell already loads. The wording is "requires", never "sufficient". Confirm stays enabled even when the resource is missing, because the instance is the authority.
- **Explain (11.1, 11.2).** It is one click from the panel on every screen, and the reply cites the read tool it used. An entry's explain sends that entry only. For an application error it sends the summary fields and never the variable table, which can hold patient data. The entry text reaches the model as delimited tool-result content.
- **Prompts and chips (11.3, 11.4).** Each screen offers at least three prompts, grouped by task, declared in its descriptor next to its command-box aliases. Choosing one sends it as a turn. A citation chip replaces the Release 1 "names in backticks plus an offer to select". It selects the row or opens the screen through the same allow-listed navigation the agent uses, never a URL. A missing target reports "no longer present" and does not fail the screen.

## Technical Decisions

- **AD-11 (untrusted content).** Screen context is a synthetic, never-advertised call and its result. The canonical name is `screen.context`; the wire name is `screen_context`, with id `ocupilot_screen_context`. It sits after `Prompt.CONTEXTPREAMBLE` and before the user's message, and a model-issued call with that name is refused as unknown. `Kernel/Agent/Prompt`'s `BUILTIN` is the constant 11.9 rewrites. The current prompt's backtick-and-offer sentence is what 11.4 later replaces. `OcuPilot.Test.TurnContext` already pins the synthetic call's shape.
- **AD-24 (bounds).** Rows are capped at 1 to 1,000 (default 200), the payload at 65,536 characters (cut by whole rows from the end), and each field at 1,000 characters (a cut value ends in U+2026). The payload reports `rowsSent`, `rowsAvailable`, `truncated` and `truncatedFields`, and secret-typed fields never leave. 11.9 must amend AD-24 at its origin to record that the kernel adds the two members. Earlier turns replay only the user message and the final reply; earlier context and tool results are never replayed.
- **AD-5 (descriptor as the single source).** The derived tool names resolve through the descriptor: `Screen/Context.Build` finds it by route (`Registry.DescriptorForRoute`). `Screen/Descriptor/Base` already exposes `ToolIdentifier`, `PrimaryActionId`, `RowActionIds` and `CommandAliases`, and the tool registry is `Screen/Tool/Registry`. Tool identity is independent of screen naming. Canonical tool names are `<area>.<screen>.<verb>`, and each dot becomes an underscore on the wire.
- **AD-30 (read-only verdict).** Read-only and the kill switch are evaluated on the instance and re-read between turn steps. While either is in force, a write tool returns a structured "blocked" result and no proposal is minted. The derived verdict must come from the same source dispatch uses, `Kernel/Restraint.Verdict(user, definitionId)` behind `Dispatch.Restraint`, never a second computation.
- **AD-36 (read contract).** A screen and its tool share one declared read, narrowed by AD-24 and stripped of secret fields. That is why "answer from context, else call the read" is sound.
- **AD-48 (application errors).** The log is read through `SYS.ApplicationError` via `LogSourcePort`. The detail payload (captured variables, `$ROLES`, `$USERNAME`) is secret by default. It never enters screen context or a tool result, and the read tool returns summary fields only.
- **AD-53 / AD-55 (one operation, two callers).** A screen's row action or Save and the agent's confirmed write are two callers of one tool class. That is why the write tools behind a screen's actions are exactly the ones the agent should name. Read-only and the kill switch gate the agent, not a person's own screen action.
- **Other ADs that apply.** AD-7 and AD-33 for streaming: progress is untrusted content in protected storage, and the panel renders it as data. AD-29 for 11.8: `ResourcesOR()` is a lower bound. AD-11 rule 3 and AD-13 for chips: allow-listed routes, scoped ids. AD-37: stored references are weak. AD-39: a screen renders `reason` and a tool renders `code`.

## UX & Interaction Patterns

- "Explain this screen" is a fixed string owned by EXPERIENCE.md. Every user-visible string comes from `core/strings.ts` and must appear in EXPERIENCE.md.
- The context chip reads `<Screen>, <NAMESPACE> · <N rows> · <provider> · <endpoint host>`. `<N rows>` is what the next turn would send, and it must stay truthful once 11.9 adds members.
- Home's starter prompts and suggested view (Story 4.10) are the precedent for 11.3. EXPERIENCE.md is canonical there: Home shows its prompts.

## Cross-Story Dependencies

- 11.9 builds on Epic 4: 4.4's context payload and `TURN.CONTEXT.INVALID`, 4.11's chip, and 4.7's `shell.screen.open`. It also builds on Epic 3's switches and the restraint verdict, and on the row and primary actions of Epics 7 to 9 and 12. Its live proof is the owner's check in Story 17.7.
- 11.2's "variable table never goes" is the same rule 11.9 applies to the error list's context.
- 11.3 declares prompts for every screen that exists when it runs. The editors of Epics 9 and 12 declare their own prompts, whichever lands first.
- 11.8 reuses Story 1.9's privilege map, and may carry the same line on row-action tooltips and Save bars in Epics 7 to 9 and 12. Where it is not wired, that is a recorded omission.
- 11.4 reuses 4.7's navigation directive and replaces the citation sentence in the prompt.
- Ledger entries routed here must each be addressed or declined with a reason. 11.1 carries DW-458, DW-460, DW-1077 (Home's empty route) and DW-1112. 11.3 carries DW-1147, DW-1158 and DW-1160.
