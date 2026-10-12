# Epic 20 Context: Stage 4 - Interoperability, with the Analytics rider

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Bring the classic portal's Interoperability work into OcuPilot for namespaces that support it, with Analytics riding along, so the largest area the classic portal still owns is usable here. Already shipped: category gating, production control, items and their settings, per-host tabs, the monitor, queues and jobs with their actions, lookup tables, read-only business partners, the host Test tab, the interoperability floor, per-screen permissions, the panel collapse, the agent's class and routine reads, saves and creates, and the shared tool-listing cache. Still to come: the sign-in hand-off that gates every embedded vendor editor (20.13, next), then the rule, BPL and DTL editors in place and the agent's edits behind them, the schema viewers and configuration diagram, source-control hooks, transformation tests, message search, resend and trace, item runtime actions, partner writes, the Analytics rider, and guided workflows with Investigate.

## Stories

- Story 20.1: Namespace category gating
- Story 20.2: Productions, listed and controlled
- Story 20.3: Production items
- Story 20.4: Per-host tabs, the monitor, queues and jobs
- Story 20.5: Lookup tables and business partners
- Story 20.6: Testing hosts and transformations
- Story 20.7: The three embedded vendor editors
- Story 20.8: The schema viewers and the production configuration diagram
- Story 20.9: Messages - search, view, resend and trace
- Story 20.10: Source-control hooks
- Story 20.11: The Analytics rider
- Story 20.12: The agent gains guided workflows and Investigate
- Story 20.13: The sign-in hand-off to the embedded vendor editors
- Story 20.14: Interoperability holders reach OcuPilot
- Story 20.15: Per-screen permissions, seen and adjusted
- Story 20.16: The agent edits rule, DTL and BPL content behind the embedded editors
- Story 20.17: Long blocks in the agent panel start collapsed
- Story 20.18: The agent proposes permission changes and refuses on a screen the user cannot open
- Story 20.19: The agent reads class and routine source
- Story 20.20: The agent creates new classes and routines, on the person's confirmation
- Story 20.21: The agent saves edits to existing classes and routines
- Story 20.22: Production item settings
- Story 20.23: Queue and job actions
- Story 20.24: Agent tool calls stop re-listing the tool registry
- Story 20.25: Item runtime and configuration actions
- Story 20.26: Business partners saved and removed
- Story 20.27: Transformations tested

## Requirements & Constraints

- **Every write** is a server-minted proposal with a diff the instance computes, an explicit Confirm and an agent marker. A new write key joins the checked-in governance baseline in the same change, and a destructive key ships `false`. Each new action's plan states its destructiveness, its key's default and its audit record.
- **Vendor bundles are never copied or redistributed.** They load in place from the instance.
- **The sign-in hand-off (20.13).** An embedded vendor editor signs in from the browser-level login. No password crosses into the frame, and the `postMessage` auth path is never used. The origin is not weakened to make this work: it stays hostile ground, and per-tab token storage with no cross-tab broadcast is unchanged. Signing out of OcuPilot also signs out the embedded editors.
- **The embeds after it.** 20.7 re-scopes its "saved, compiled, invalid" criterion at its spec gate, because the editors send none of those messages in normal mode. A story's first task establishes its vendor contract against the instance: the schema browsers' document-selection parameter for 20.8, and the source-control hook exchange for 20.10.
- **Rule, DTL and BPL edits (20.16).** These run in five steps:
  1. Warn the user to save the editor first, because OcuPilot cannot read the frame's unsaved state.
  2. Read the stored content.
  3. Propose the edit with its diff and the agent marker.
  4. Refuse if the stored content changed after the mint.
  5. Reload the editor.

  The key ships enabled.
- **Transformation test (20.27).** Runs a transformation on pasted input and renders the output. It is a confirmed write because it executes code on the instance.
- **Messages (20.9).** Search and the viewer read through the port, with saved searches where the API offers them. Resend and edit-and-resend take a dry run and then a Confirm, with a bounded cap on how many messages one action can resend. A session trace renders visually, with a generated sequence diagram as the alternative. The message-contents renderer is the stated custom half.
- **Item runtime actions (20.25).** A temporary stop, start or restart of one item is followed by the production update the vendor requires. Each is refused by name wherever the vendor would answer success while doing nothing: a stopped production, a disabled item. Copy and change of class run as the classic page does, and the vendor audits them.
- **Partner writes (20.26).**
  - Create, update and remove on `Ens.Config.BusinessPartner` are confirmed over a fresh read, and each records OcuPilot's own audit row.
  - The vendor performs a rename as a delete and then a create, with no transaction, so a rename is either refused or done in one transaction.
  - Before removing a partner that an item's `BusinessPartner` setting names, the port reads those items, then refuses or warns.
  - The pair posture goes to the orchestrator. 20.5's plan recommends `%Ens_ProductionConfig:WRITE`.
- **Analytics (20.11).** Build, synchronize and repair of a cube are the only analytics writes. MDX results render with drill-through and cancel. Architect, Analyzer and the User Portal are linked, not rebuilt. Anything beyond those links needs a DeepSee-enabled namespace.
- **Guided workflows and Investigate (20.12).** A workflow is a sequence of individually confirmed proposals, never a batch approval. Each write still evaluates the prohibited set, both agent switches and governance. Investigate starts from an alert or a log entry and returns a recap and ranked hypotheses that cite the rows it used. Harvested prompts take OcuPilot's names.
- **Secrets and paths.** A name matching the one Secrets pattern is answered with an empty value and default and with `Secret` true. Setting it is refused before any vendor call, from both callers. Named limit: a secret stored under a name that does not match is not caught. No endpoint accepts a path except a case AD-21 names, and pasted content is never a path.
- **Posture questions go up** to the orchestrator, with options and a recommendation.

## Technical Decisions

- **Embedded editors (AD-63).** This is a named case of AD-28 and AD-47.
  - **The frame.** A same-origin `<iframe>` loads `/ui/interop/<editor>/index.html` on the instance's own origin. It carries only the editor's own query parameters, with values from a read OcuPilot answered. It never uses another origin or a path built from a person's text.
  - **Normal mode only.** The frame never uses `?VSCODE=1`, whose `window.onmessage` accepts `{type:"auth", username, password}` from any sender. OcuPilot never pre-writes tokens into the editor's storage.
  - **Nothing crosses.** OcuPilot posts nothing into the frame, reads nothing from it, and touches none of its storage or messages. So 20.16's reload cannot be a message (inference).
  - **No sandbox.** The frame is not sandboxed, because a sandboxed frame never signs in. This differs from AD-47's inert class-reference frame (`sandbox=""`).
  - **Measured at 20.1's plan.** In normal mode the editor signs itself in with an empty `POST /api/interop-editors/login` that rides the browser-level login: `/ui/interop/rule-editor/index.html?$NAMESPACE=USER` rendered for the signed-in user. After OcuPilot signs out, that login answers 401. The editors post their notices to `window.parent`, with target origin `"*"`, only in `?VSCODE=1` mode.
  - **Named consequence.** The frame can read the tab's `ocupilot.token-pair` and script the shell. That gives it nothing beyond what same-origin code already gets from the browser-level login.
  - **Shape of 20.13.** 20.1's plan scoped option A as a shell frame component plus a browser spec that proves the silent sign-in.
- **Interoperability port (`Port/InteropPort`).** It is the only class that starts, stops, restarts, updates or recovers a production, and the only source of declared interoperability reads. It calls the documented vendor classes the classic pages call, in the caller's process as the signed-in user, and never calls `%Api.InteropEditors.*`. A new read or write extends this port and names its case in AD-62 at its spec gate, and in AD-36 too for a read.
- **Gate first.** The vendor's production reads and its lookup, partner and test calls check no privilege (measured), so the port's gate is the whole gate.
  - **Order.** The endpoint's pairs come first, then READ on the namespace's globals database, or WRITE for a write. A refusal names the failed pair.
  - **Settling pairs.** Start from the classic page's own check, then run a least-privileged principal on a throwaway. Extra pairs are declared only where measured, refused by name before any port call, and pinned by a test that removes each one.
  - **The floor.** The API floor admits `%Ens_Portal:USE`, so every new surface declares its own pair, and the `InteropFloor*` rosters pin it.
  - **Adjustment.** `Screen.Gate.RequiredPairs` is the one reader of a screen's requirement. Port and vendor pairs can never be adjusted.
- **Namespace and elevation.**
  - `appliesWhen` (`IsEnsembleNamespace`, and `%IsDeepSeeEnabled` for Analytics) decides whether a surface applies, not who can open it.
  - The port switches namespace by explicit save and restore, and calls no `OcuPilot.*` class while switched.
  - OcuPilot adds no elevation of its own.
  - A namespace under source control refuses item and lookup writes.
- **Write shape (AD-51, AD-53, AD-54).**
  - **Action-style.** Each write declares its request type, sends no body or a port-built one, and fingerprints a port-composed fresh read. Before any vendor call it refuses, by name, anything the vendor would answer as a silent success. A create fingerprints the target's absence.
  - **Two callers, one operation.** A screen action and the agent's write share the fresh read, the prohibited set inside the per-target lock, the gate, the change event and the read-back. Only the agent's caller mints, writes the marker and is gated by the agent switches.
  - **Its own request.** Each write finishes in its own request, capped at 15 s, with no spawn site. A troubled production gets Recover, never Clean.
  - **After OK.** The write re-reads its target (`readBack`). Every port that defines `Invoke` also defines a pure `Snippet` that mirrors each branch, with secrets as placeholders.
- **Audit.** Item and setting changes go through `Ens.Util.Auditing.AuditModifyProductionConfig`, never with a value. Writes the vendor does not audit, such as queue, job, lookup and test actions, record OcuPilot's own `ConfigChange` from either caller. A new unaudited vendor operation is either named in AD-15 or audited by the port itself.
- **Tests (AD-62 item 11).** 20.6 shipped the host half as `ItemTest` (`LIST` by `item`, `TESTTARGET`, `SENDTEST`). 20.27 adds `TRANSFORM` and `TRANSFORMTEST` to `Transforms`.
  - **Parsing.** The transformation test parses pasted text with a virtual document's `ImportFromString` or with `Ens.Util.XML.Reader.ObjectFromString`, never with the `[Hidden]` serialized reader.
  - **Running.** It runs `Transform` in process, with empty `process` and `context`. Before any vendor call it refuses by name, and it makes its vendor calls inside the output capture. It is not destructive.
  - **Pairs and pages.** It needs `%Ens_DTLTest:USE`, WRITE on the globals database and `%Ens_Code:READ`, a named narrower audience than the classic dialog's. Its `CLASSICPAGES` entry is `EnsPortal.Dialog.TestTransform`.
  - **Named limits.** The HL7 parse writes the per-process `^EnsHL7.Segment` node, and a transformation's own code has no cap beyond the gateway timeout.
- **AD-39's seventh exception.** A test's response, output, error and console lines reach the screen and the proposal card only, as text. They never reach the model, a tool result, a ledger row, an audit payload, a log line or screen context.
- **Reads and ids.**
  - Reads use source kind `interop`. A parent-scoped list takes its parent's route id as its one criterion and answers the parent key on each row. Every read has a row cap and reports when it truncates.
  - An id keeps every part exactly, never uses the vendor's integer id, and is percent-encoded in one path segment. For example, `production-item` is `[Production, Name]`.
  - Each tool declares its `CLASSICPAGES`. Each new write type is reviewed against AD-10's prohibited set and declared covered.
- **Tool classes.** `InteropAction` is the parent of `InteropProductionAction` and `InteropItemAction`, and a new interoperability tool extends that hierarchy rather than copying a sibling. Tools are named `<area>.<screen>.<verb>`.
- **Untrusted content.** Message bodies, log text, names, settings, lookup values, test inputs and outputs, and rule, DTL or BPL content reach the model only through the one sanitizer. No gate or test relies on the sanitizer as its defense.
- **Measure on the instance.** Amend the spine at the spec gate rather than working around it.

## UX & Interaction Patterns

- **Rail.** Interoperability and Analytics follow System Explorer, and appear only where the namespace reports the feature. A screen joins the side bar only once it has shipped. An item opens on these tabs: Status, Settings, Queue, Log, Messages, Jobs, Test.
- **Embeds and viewers.** The editors render in place inside the shell. The configuration diagram renders in place, and its sibling editors open in new tabs. The HL7, X12 and ASTM schema browsers are read-only.
- **Gated controls are never hidden.** They stay focusable and `aria-disabled`, and name the failed pair.
- **Strings.** Each list has a title, an empty state and three suggested prompts. A write-capable list's empty state adds the line inviting the agent. Every new string goes into EXPERIENCE.md's Fixed strings and into `strings.ts`, whose values are unique. A refusal sentence lives once, on the server, and a test pins it equal to its fixed string.
- **Dialogs.** A dialog exists only where EXPERIENCE.md's dialog list names one; 20.6 added Send test. A new dialog or pre-write warning amends that list at the spec gate. Dialogs never stack. A destructive screen action uses the confirm dialog with a typed name.
- **Auto-refresh** is opt-in per screen and off by default. A screen declares it in its descriptor and in EXPERIENCE.md's Auto-refresh roster.
- **Cards.**
  - Proposal cards follow the standard lifecycle, and production cards carry the guidance to recover before cleaning.
  - An agent's destructive proposal carries no typed name.
  - A block over about eight lines starts collapsed, with a summary line, and Confirm never requires expanding it.

## Cross-Story Dependencies

- **Done:** 20.1 to 20.6, 20.14, 20.15, and 20.17 to 20.24.
- **20.13 is next**, under the owner's option A (AD-63, DW-2141). Its measurements and candidates are in Story 20.1's blocked spec at commit `9faa902f`. It gates 20.7, 20.8 and 20.10, and 20.27 is ordered after it. 20.16 follows 20.7 and builds on 20.21's agent source saves.
- **20.27** consumes 20.6's shared test helper (`IsTestWrite`, the test code family, `test-answer.ts`), the seventh exception, and the Data transformations list.
- **Other links.** 20.9 builds the visual trace and reuses `interop-message` (inference). 20.8's diagram shows 20.3's items. 20.12 can run a guided disable followed by Update.
- **20.25 and 20.26.** 20.25 consumes 20.3's items and 20.4's per-host tabs, and 20.26 consumes 20.5's Business partners screen and read. The orchestrator places them in the order.
- **Epic 18 runs beside this epic.**
  - **Shared rosters.** Both epics edit the entity types, the screen mirror, `strings.ts`, the navigation tests and EXPERIENCE.md's rows. Edits there are add-only and are summed at the forward merge; anything else is asked first.
  - **New screens.** 18.12 is merged, with 18.36. Since then, every new Epic 20 screen needs a row in the `Elsewhere` block of `Test/StageTwoTools`, or that test reddens.
- **Into Epic 21.** Epic 21 reuses 20.12's diagnose-slow-query workflow. It owns interoperability credentials, purge, deployment, record maps, workflow and the analytics editors, so those stay out of this epic.
