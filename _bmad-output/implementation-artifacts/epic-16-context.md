# Epic 16 Context: The remaining polish-week extras

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

This is voting-week work. It covers the classic portal's remaining second-tier screens and actions, each of which a person and the agent reach through one operation. Six stories deferred from the contest build close the epic. The last, 16.15, makes egress visible on every turn. On each turn that shares screen context, the agent panel says which provider the turn used and whether the screen data left the instance, so the disclosure no longer depends on the user reading the context chip. **Nothing here may break a Release 1 screen or agent write**; anything that risks either waits for Stage 2.

- **Done:** 16.1 to 16.14 and 16.16 to 16.25. 16.14 was committed at `d08d4ab5`; its CI run 36825179541 was pending when last logged.
- **Remaining, on slot A:** 16.15, then the epic close.

## Stories

- Story 16.1: The try-it request console
- Story 16.2: Web sessions, listed and ended
- Story 16.3: Effective privileges and the permission-check tool
- Story 16.4: Task export and import
- Story 16.5: Background tasks
- Story 16.6: Broadcast a message to processes
- Story 16.7: License usage and the full dashboard
- Story 16.8: The six secondary log viewers
- Story 16.9: The unified log hub
- Story 16.10: External language servers
- Story 16.11: Start, suspend and resume the Task Manager
- Story 16.12: Remove locks - one, all of a process, all of a remote client
- Story 16.13: The service editor
- Story 16.14: The LDAP and Kerberos editor
- Story 16.15: The data-egress line
- Story 16.16: The agent audit viewer
- Story 16.17: The read-back line
- Story 16.18: Home's performance row
- Story 16.19: Impact lines on removals
- Story 16.20: Older messages.log files
- Story 16.21: Security findings, with a fix you confirm
- Story 16.22: The Guardrails page
- Story 16.23: Any table, downloaded as CSV
- Story 16.24: A try-it request, copied as curl
- Story 16.25: The external language server editor

## Requirements & Constraints

### 16.15, the data-egress line

- **The line.** On every turn with context sharing on, the panel shows a line. It names the provider in use and states whether the screen data left the instance.
- **One source.** The statement derives from the same configuration the turn's request actually used, so the line and the destination cannot disagree.
- **Local case.** For a local provider on a private network, the line says the data did not leave, which matches the chip's absent "leaves the instance" pill.
- **Line versus chip.** The chip forecasts the next turn: it reads the current default definition and the current sharing choice. The line reports the turn that ran. After a default-marker move the two may legitimately differ for an earlier turn.
- **Screen data only.** The claim concerns screen data. The user's message always goes to the provider, so the line must not imply that nothing left (inference).
- **Copy.** EXPERIENCE.md has no row for the line. Add its strings to the Fixed strings table, which is canonical, and to `ui/src/app/core/strings.ts` in the same change. Add its placement in Component Patterns.
- **DW-1076, routed here by the spec gate.**
  - Add a fixture with a second enabled definition on a different endpoint host; `Test/TurnWireFixture` creates only one.
  - Add a live browser leg. In it, a real default-marker move (definition-actions' mark-default, or a form Save) makes the chip's host and pill follow, and so does the line on the next turn.
  - Today this is pinned only at store level, in `ui/tools/agent-context.test.mjs`. `Test/EgressLocal` pins the server computation.
- **DW-1192, decided at the merge gate.**
  - A Gemini endpoint with no `{model}` placeholder stays allowed, but never silently. Today `Kernel/Provider/Gemini`'s URL builder returns such an endpoint unchanged, so the model the definition names is not the one called.
  - At minimum, log a line naming the definition whose Model is unused, and say so on the Definition form where the endpoint is edited.
  - A create-time model validation rule stays deferred: it needs a new violation code. The wire already refuses an unusable model as `PROVIDER.EGRESS`.
- **DW-1335**, also routed here, was resolved by 15.9; nothing remains.

### Every story

- **Write tools.** Should 16.15 add a write tool (none is expected, inference), the registry rules apply in full. These include port snippets (AD-59), read-back compares (AD-58), canonical spelling, auditing measured, `CLASSICPAGES` and a governance baseline key in the same change.
- **Planning documents.** EXPERIENCE.md (993 lines) and epics.md are cited by line. Edit them in place, then run `cd ui && npm run test:tools`.
- **Bundle.** 16.14 left it at 2,383,623 B against `maximumWarning` 2384kB (`maximumError` 4000kB). A re-base updates the `angular-json.test.mjs` literal in the same change.
- **Tests.** One test-runner call at a time, never two in one message.
- **DW-118 (epic level).** Decline it as resolved by Story 15.6.

## Technical Decisions

- **Egress is configuration, judged once on the instance (AD-42).**
  - An endpoint decides where data goes. It must be an absolute HTTPS URL, or an explicitly local address for the OpenAI-compatible adapter. A cloud metadata endpoint is refused even when marked local.
  - A configured proxy is a destination judged by the same policy. A marked-local endpoint bypasses the proxy, so a proxy the call does not take cannot make the call read as leaving.
  - The computation is `ProviderPort.ResolveEndpoint(definitionId)`, which yields provider, host, marked-local and proxy host, followed by `Kernel.Egress.LeavesInstance(host, markedLocal, proxyHost)`. The proxy is instance-wide, in `Kernel.State.Egress`.
  - `Api/Context` (`/agent/context`) runs this for the current default definition and answers `leavesInstance` as null when no endpoint resolves.
  - The line reuses this computation rather than adding a second judgment, client-side or otherwise (inference), and it needs a defined reading for null that never claims "did not leave" (inference).
- **Which configuration a turn used.**
  - `Api/Turn` resolves the default definition when the turn starts, and the turn row records `DefinitionId`.
  - So derive the line from the turn's own definition, not from the current default (inference).
  - Settle at the spec gate whether to snapshot provider, host and the verdict on the turn row at start (inference). Otherwise an edited or deleted definition rewrites the history. Under AD-37 a stored reference is weak and renders as "no longer present" rather than failing.
  - A new `Turn` property that older rows read back as `""` needs no `SCHEMAVERSION` move. `ContextRoute` and `Citations` are the precedent.
- **Sharing (AD-24).**
  - The toggle is per user (`Kernel.State.Sharing`) and falls back to the instance default on Switches. Secret-typed fields never leave, whatever the toggle says.
  - Context is bounded by the row cap (default 200), 65,536 characters in total and 1,000 characters a field, and reports `rowsSent`.
  - Whether a context-off turn shows anything is the spec gate's call (inference).
- **Delivery (AD-7, AD-33, AD-11).**
  - The turn runs in a background job, and the panel polls `GET /turn/{id}/progress`.
  - Progress lives in protected storage and is owned by the turn's user; a poll for another user's turn is a 404. Progress is untrusted content, rendered as data, never markup, and it never causes a request to any host.
  - Provider names and hosts are operator configuration; render them as text.
  - Adding a key to the progress payload changes the poll's contract (11.7's streaming deliberately added none), so decide the transport at the spec gate (inference).
  - An agent navigation changes which screen's context the next turn carries, and so what leaves. It is announced before it happens (AD-11 rule 3).
- **Client (AD-19, AD-14).**
  - Stores in `ui/src/app/core/` import no `@angular/core`; components mirror them into signals.
  - `core/agent-context.ts` already re-reads on agent-definition and agent-switch change events, and the chip's pill is `leavesInstance() === true`.
  - No store mutates another's. Cross-screen communication is the change-event bus and the router only.
- **Secrets and errors (AD-35, AD-39).**
  - The DW-1192 log line names the definition and the unused model, never a key, credential or credential-bearing URL. OcuPilot shows its own logs, so anything it writes there is later displayed and read by the agent.
  - A provider failure is a turn error in the one envelope, never an exception to the client.
- **Ledger and transcripts (AD-41).** Ledger rows record what actually executed, finalized after the fact, with secret-typed fields excluded at write time. Transcripts already show a turn's screen context ("No screen context was sent with this turn."). If the line is persisted, it must agree with what those records say the turn used (inference).
- **Preferences (AD-50).** A new per-user preference, for example one that hides the line, goes into the one Kind-discriminated store (`Kernel.State.Pref`) through a caller-own shell-chrome route. It never becomes a new State class or `localStorage`, and a preference is never screen context.
- **The write path, for any other work in this epic (AD-53, AD-55, AD-22, AD-34).**
  - A screen Save and the agent's write resolve through one tool class.
  - Governance is asked at dispatch and again at Confirm.
  - A confirm holds the target's lock from the fresh read through the read-back, and refuses `WRITE.TARGETBUSY` (409) after 10 s.

## UX & Interaction Patterns

- **Panel body order.** First the banners (kill switch, enforced read-only, writes not marked, reminder, lock), then the context chip, then the transcript. The transcript is `role="log"`, polite, newest at the bottom. A line placed inside it is announced by construction (inference).
- **The chip.**
  - It reads `<Screen>, <NAMESPACE> · <N rows> · <provider> · <endpoint host>`.
  - When the host is not private it adds a "leaves the instance" pill in the egress-warning colors, with the tooltip "Screen context is sent to <host>".
  - With sharing off it reads "Screen context off — nothing from this screen is sent."
  - A screen with secret-typed fields adds a key glyph, named "Secret fields on this screen are never sent".
  - The chip is absent in the configuration-empty state, because there is no provider to name.
- **Color never carries egress alone.** The line states egress in words, and any egress-warning tint only supplements them. Theme roles have `-dark` twins, so draw bare roles and never select on the theme.
- **The Definition form** (`areas/agent/definition-form.page.ts`) already carries an endpoint hint: "This endpoint is not encrypted, so the key travels across the network in clear." That hint is the precedent for DW-1192's note where the endpoint is edited.
- **Fixed strings are canonical.** Quotations elsewhere in EXPERIENCE.md are illustrations, never second sources.

## Cross-Story Dependencies

- **What 16.15 builds on.**
  - Story 4.11: the chip, the sharing toggle, and the agent context's re-read.
  - Story 10.3: `LeavesInstance`, marked-local and the proxy bypass.
  - Story 10.2: the Gemini adapter.
  - Story 11.7: streaming progress text.
- **Keep intact.** Epic 14's governance baseline, sanitizer and per-user read-only, and 16.16's ledger viewer.
- **Slot B.**
  - Epic 18 runs in `.worktrees/epic-18`. Before editing a file, check it with `diff --stat` against feature and `status -s`. Edit a contended file add-only; otherwise stop and ask.
  - Shared rosters are unioned at each merge, so keep edits to them additive: `EntityType`, the `Prohibited` codes, the `AdminPort` type lists, `CLASSICPAGES`, the baseline and the screen mirror.
- **Slot A.**
  - Use the `ocupilot-slot-a` profile and the `ocupilot-ci` throwaway (52776/1975).
  - Since DW-48 and DW-1885, a product start deletes compiled `OcuPilot.Test` classes. `ocupilot-ci` has not been restarted since, so load and compile through the MCP loader rather than restarting it; slot B's throwaway carries the same instruction.
- **Release 1.0.5** is cut Thursday 2026-10-01 at 14:00 PDT, with a story-start cutoff of 12:00. Whatever is green on feature ships.
- **Epic close.** After 16.15, the Rule 27 burn-down gate runs.
  - It charters only entries that block the next release or a downstream story, plus CI flakes. DW-1867, the language-server-editor browser flake, was filed for this close.
  - Two entries go to the decision sheet: DW-1888, an LDAP name stored non-canonically (decision pending), and DW-1889, which cannot clear the last LDAP attribute (escalated).
  - DW-1883 is decided (wontfix-accepted).
  - Every other entry is re-owned to `range-end-cleanup`.
  - Then Epic 19 starts on slot A, while Epic 18 continues on slot B.
