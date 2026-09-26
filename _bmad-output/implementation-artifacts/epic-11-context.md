# Epic 11 Context: The agent explains itself, cites its work, and streams

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Make the agent easy to understand and easy to check for a first-time judge or voter. Done so far: it answers about the screen in view, a first change request ends in a confirmable proposal, replies stream, a proposal names the privilege it needs, one click explains a screen or a single log or audit entry, every screen's idle panel offers suggested prompts, and a reply carries citation chips for the rows it used. What remains is Story 11.11, an owner high-priority fix that ships in release 1.0.1. The audit database and the all-task history open on an empty criteria form and read nothing until Search, so when the agent opens one and describes rows, the person sees none. After 11.11 both screens run a default search on open, and the agent's navigation carries the criteria its own read used, so the rows on screen are the rows the agent describes.

## Stories

- Story 11.9: The agent knows the screen it is on (done)
- Story 11.10: A judge succeeds the first time (done)
- Story 11.7: Token streaming (done)
- Story 11.8: The proposal names the privilege it needs (done)
- Story 11.1: "Explain this screen" (done)
- Story 11.2: Explain a log or audit entry (done)
- Story 11.3: Suggested prompts per screen (done)
- Story 11.4: Citation chips with click-through (done)
- Story 11.11: The screen shows what the agent is talking about

## Requirements & Constraints

- **Release 1 is protected.** Nothing may break a Release 1 screen or agent write. Every tool declares `read` or `write` at definition or the build fails, and every new write key joins Epic 14's governance baseline.
- **Default search on open (11.11).** Audit database: last 24 hours. Task history (all): last 7 days. Both newest first, within the screen's row limit, with the criteria form showing the values used and Search still there to narrow them. Neither screen gains auto-refresh; both still search on the server.
  - The audit criteria are the eight the audit API filters on, plus the agent-marker filter. Its time fields are instance local time, `YYYY-MM-DD HH:MM:SS`.
  - Task history (all) declares only a search text (the vendor's filter) and a user-defined-only checkbox. The planning documents name no time-range criterion for it, so the 7-day window has no existing field to show it in (inference).
- **The agent-marker filter is an affordance, never a default.** The agent's own audit events are never hidden. The default search must not apply the marker filter; only an agent navigation carrying that criterion does. Example: "Which changes did the agent make?" opens the audit database filtered to agent-marked events.
- **Navigation carrying criteria (11.11).** When the agent opens either screen, it passes the criteria its read used, and the screen runs that search. The navigation tool still accepts only allow-listed registry routes and entity ids, never a URL. Criteria the model supplies are untrusted, so they should be limited to the criteria the screen's declared read accepts (inference).
- **The system prompt is one ASCII build-time constant.** Nothing read at runtime is joined to it, and a definition override replaces it whole. Tests pin its required statements. CI calls no live model, so the model's compliance is live-check evidence only.
- **Done work that must stay intact:**
  - Streaming: a polled background job whose whole-text snapshot renders `inert` through the one reply component.
  - The proposal card's "requires" line, with Confirm left enabled.
  - Explain turns go through the panel's own Send path.
  - The one-row entry context never carries the application-error variable table.
  - Each descriptor declares at least three suggested prompts.
  - Citation chips are derived on the instance and open through the navigation allow-list, never a URL.
- **Evidence.** Browser specs must pin two things: both screens show rows on open, and an agent navigation carrying criteria shows the matching rows. Browser specs run against the rebuilt, redeployed bundle. Any claim about every screen needs a registry-driven test.

## Technical Decisions

- **One declared read serves the screen and its tool.** Filter, sort and field set cannot diverge. Every read is bounded by the max-rows cap and reports truncation. The row limit is remembered per screen on the instance, never in browser storage.
- **The audit record LIST is asynchronous.** The vendor queues it, and `AdminPort` polls it within a bounded wait that fails as `PORT.TIMEOUT`, never with a partial result. A default search on open takes this same path, so the screen needs its skeleton and error states for it.
- **Navigation is a proposal of a route, not an action.** A navigation the user did not start is announced first, is reversible with Back and can be refused by the departing screen. It runs client-side as a read tool, and dispatch validates its arguments before any announcement exists. The browser answers from a closed set of outcomes and never authors text the model sees.
- **Untrusted content never becomes instruction.** Screen context enters as a synthetic `screen.context` tool result. Nothing rendered from a reply or a tool result requests any host.
- **Routes** are `/ocupilot/<area>/<screen>[/<id>]?ns=<NAMESPACE>`, and the namespace in a route is data scope. Entity references carry the triple (entity type, scope, id).
- **No caller value is ever concatenated into SQL**; criteria are bound as parameters.
- **The descriptor is the one source** for a screen's route, read, context, prompts and aliases. The client mirror is generated from it and never hand-edited.

## UX & Interaction Patterns

- **The "list (server criteria)" archetype must change at origin.** EXPERIENCE.md's state matrix gives its cold-load state as "criteria form first, skeleton on Search". 11.11 rewrites that row to state the default search, and adjusts the exception line saying these screens search on the server and do not auto-refresh. The IA row that says Task history (all) reads on Search changes to match.
- **Empty states:** "No events match." on the audit database and "No task runs match." on task history. Every new user-visible string needs a string-table key and a row in EXPERIENCE.md's Fixed-strings table.
- **The post-confirm flow ends on the audit database.** After a confirmed write, the reply ends "Shall I show you the audit entry?". Answering yes opens Logs › Audit database with the agent-marker filter applied, and the event should now be visible on arrival.
- **Reply rules:** the agent speaks in first person, names the screen it means, and backticks the rows it used, which render as citation chips. It never claims success it did not verify.

## Cross-Story Dependencies

- 11.11 builds on:
  - Story 2.10: the audit viewer and its marker filter.
  - Story 6.6: task history across all tasks.
  - Story 4.7: the navigation tool, its announcement and Back.
  - Story 11.10: the prompt statement that the agent opens the screen under discussion first.
  - Story 11.4: chips reuse the navigation allow-list, so criteria support must not widen what a chip can open.
- 11.11 runs alone on slot A. Epic 16 is paused at 16.1 while it runs. Release 1.0.1 is cut from the feature branch when 11.11 merges.
- Story 14.8's seeded-injection test asserts zero navigations from planted text, and it runs against this prompt and tool set. Story 17.7's owner live check exercises the agent's navigation.
