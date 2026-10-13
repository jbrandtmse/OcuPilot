# Epic 20 Context: Stage 4 - Interoperability, with the Analytics rider

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Bring the classic portal's Interoperability work into OcuPilot for namespaces that support it, with Analytics riding along, so the largest area the classic portal still owns is usable here. Shipped so far: category gating, production control, items and their settings, per-host tabs, the monitor, queue and job reads and actions, lookup tables, read-only business partners, host and transformation tests, the interoperability floor, per-screen permissions, the panel collapse, the agent's source reads, saves and creates, the shared tool-listing cache, the sign-in hand-off, a clean compile and install in a namespace without interoperability, screens that load on demand, and the rule, BPL and DTL editors InterSystems built, loaded in place inside the shell (20.7). Two stories are ready for development. In 20.16 the agent edits the content behind those editors once the person confirms. 20.8 adds the schema viewer and the production configuration diagram, embedded as 20.7 embeds the editors. 20.9 is the next story to plan: message search, the message viewer, resend and edit-and-resend, and the session trace. Still to come: source-control hooks, item runtime actions, partner writes, the Analytics rider, and guided workflows with Investigate.

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
- Story 20.28: OcuPilot compiles in a namespace without interoperability
- Story 20.29: Screens load on demand

## Requirements & Constraints

- **Every write** is a server-minted proposal with a diff the instance computes, an explicit Confirm and an agent marker. A new write key joins the checked-in governance baseline in the same change, and a destructive key ships `false`. Each plan states the action's destructiveness, its key's default and its audit record.
- **Messages (20.9, next to plan).**
  - **The acceptance.** Search and the viewer read through the port, with saved searches where the API offers them. Resend and edit-and-resend run a dry run, then a Confirm, with a bounded cap on how many messages one action resends. A session's trace renders visually, with a generated sequence diagram as the alternative. Message contents use the embedded viewer or a rebuilt renderer. The rebuild is the custom half, and it ships read-only first.
  - **The classic pages** (research reading, not measured):
    - `EnsPortal.MessageViewer`: header search with basic and extended criteria, saved searches, and header, body, contents and trace panes, over `Ens.MessageHeader` and `EnsPortal.MsgFilter.*`.
    - `EnsPortal.MessageResend` (with an optional new target) and `EnsPortal.MessageResendEdit`.
    - `EnsPortal.VisualTrace?SESSIONID=`.
    - Their resources are `%Ens_MessageHeader:USE`, plus `%Ens_MessageContent`, `%Ens_MessageResend`, `%Ens_MessageEditResend`, `%Ens_MessageExport` and `%Ens_MessageTrace`, each at USE. Each new surface declares its own pair and its classic pages.
  - **No `%Api.InteropEditors`.** The research catalogs search, trace and resend on the vendor's v7 `messages` routes. OcuPilot never calls those (AD-62 item 1), so the port calls what the classic pages call (inference).
  - **The harvested resend reference** (sibling project; rename on harvest).
    - A dry run is the default and answers a shape distinct from an executed resend. Executing needs both "not a dry run" and "confirm"; either alone is refused with "No changes were made."
    - Explicit ids are capped at 100. A filtered resend defaults to 100 messages, and a match count over 500 is refused, never truncated and run. The window is at most 7 days.
    - The same harvest holds a seven-class sequence-diagram generator that writes Mermaid `sequenceDiagram` text.
  - **The vendor's viewer** is `/ui/interop/message-viewer` with `$NAMESPACE` and `SESSIONID` (research reading, not measured). An embed of it joins the source builder only once its parameter is read on the instance. A session id is not a class name, so it needs its own value shape under AD-21 (inference).
- **Embedding a vendor app (20.7 as built; 20.8 and 20.10 follow it).**
  - **In place, never copied.** The app loads from the instance, signed in through 20.13's hand-off. The vendor's bundles are never copied or redistributed.
  - **Normal mode.** The app reports a save, a compile or a failed compile in its own notice inside the frame. Nothing reaches OcuPilot's shell, and OcuPilot shows a result only through its own reads.
  - **What opens a frame.** A screen issues only its declared read, or another built screen's, and draws a frame only for a row that read answers (for a process or transformation, only when the row is not `Coded`). Otherwise it shows its "no longer exists" or "written as a class" sentence, and a refusal names the failed pair.
  - **A drawn frame is never navigated.** A new document, a namespace move or Refresh draws a new frame, so the app's unsaved-changes alert does not show. The screen's note says leaving it, or choosing Refresh, discards unsaved changes (DW-2376, ruled by design). There is no leave guard and no confirm dialog.
  - **The app can move away unseen** through its logo, Back to standard UI, its own Open, Namespace and Settings, and the history entries it pushes. The screen keeps naming its own document, and Refresh opens that document again.
  - **Scope.** An embed brings no write tool, governance key, entity type, read tool or area, and no query parameter beyond `$NAMESPACE` and the app's document parameter. A new rule, BPL or DTL is created with the editor's own New.
- **The schema viewer and the diagram (20.8, ready for development).**
  - **Schema viewer.** One listed screen, `interoperability/schema-viewer`, with no read and no document parameter.
    - The vendor app clears its `&ST` before reading it, so every address opens on ASC X12 (measured). The person picks HL7 v2.x or ASTM in the viewer's own list. The viewer is read-only.
    - DW-2396 is a vendor candidate under the owner's hold. 20.8's AC2 is its tripwire and reddens if the vendor fixes it.
  - **Diagram.** One unlisted screen, `interoperability/productions/diagram/<production>`, linked from Production items.
    - It draws the configuration app with `$PRODUCTION` only for a row whose `Name` exactly matches the route id in the Productions list's read.
    - In it the person may change configuration and start or stop the production as themselves, and OcuPilot's write path, governance and agent switches do not reach the frame (inference).
    - The app opens its sibling editors and the classic Queue, Jobs and Log pages in new tabs without `noopener`, or as panels inside the frame. Each load stores one `Ens.Message.Search` row for the person (measured).
- **Rule, DTL and BPL edits (20.16, ready for development).**
  - **Flow.** The person saves the editor first, because OcuPilot cannot see its unsaved state. The agent reads the stored content and proposes the edit with a diff. Confirm is refused if the stored content changed after the proposal was minted. After Confirm the frame is redrawn, showing the saved text.
  - **Tools.** Six tools, `.source` and `.save` on `interop.ruleeditor`, `interop.processeditor` and `interop.transformeditor`. They extend 20.21's class read and save through two abstract bases.
  - **Pairs.** Each tool requires the editor screen's effective pairs plus `%Development:USE`. Each save also requires `%Ens_Code:WRITE` and routines-database WRITE.
  - **Checks and posture.** A kind check (`IsCodeOfKind`) runs at the mint and again at Confirm. The saves are agent-only and `SCREENLISTED`. The keys ship enabled, and every save compiles on Confirm.
- **What 20.16 builds on (20.19 to 20.21).** A source read is capped at about 60,000 characters, cut at whole lines, sanitized, and reports truncation. A save sends exact replacements, each `Old` matching exactly once against the stored text. The proposal holds one changed-lines hunk of at most 30,000 characters. Only a document stored in its namespace's own routines database can be saved: never in `%SYS`, never a `%` name, never OcuPilot's own packages.
- **Source control (20.10).** Its Task 0 establishes the hook exchange on the instance. The hooks, menus, user actions and status go through the port.
- **Item runtime actions (20.25).** A temporary stop, start or restart of one item is followed by the production update the vendor requires. Each is refused by name where the vendor would answer success while doing nothing (a stopped production, a disabled item). Copy and change of class run as the classic page does.
- **Partner writes (20.26)** on `Ens.Config.BusinessPartner`.
  - Each write is confirmed over a fresh read and records OcuPilot's own audit row.
  - The vendor renames by a delete and a create without a transaction, so OcuPilot either refuses a rename or runs it in one transaction.
  - Before removing a partner, it reads the items whose `BusinessPartner` setting names it, then refuses or warns.
  - The pair posture goes to the orchestrator; 20.5's plan recommends `%Ens_ProductionConfig:WRITE`.
- **Analytics (20.11).** Cube build, synchronize and repair are the only analytics writes. MDX results render with drill-through and cancel. Architect, Analyzer and the User Portal are linked, not rebuilt. Anything beyond those links needs a DeepSee-enabled namespace.
- **Workflows and Investigate (20.12).** A workflow is a sequence of individually confirmed proposals, never a batch approval. Each write still evaluates the prohibited set, both agent switches and governance. Investigate starts from an alert or a log entry and returns a recap and ranked hypotheses that cite the rows used. Harvested prompts take OcuPilot's names.
- **No compile-time dependency on interoperability.** No shipped class includes an interoperability include file, or names an `Ens.*`, `EnsLib.*` or `EnsPortal.*` class where the compiler resolves it: a superclass, a property, an argument or return type, `DependsOn`, `CompileAfter` or a class query's SQL. Such a value is typed `%RegisteredObject` or `%String` and reached at run time while switched. `##class(Ens.…)` in a method body, `#dim`, embedded SQL and strings all compile. `OcuPilot.Test.CompileWithoutInterop` and the `package` job's install enforce this.
- **Secrets and paths.** A secret-named setting answers empty, and setting one is refused before any vendor call. No endpoint accepts a path outside a case AD-21 names, and pasted content is never treated as a path. Pasted XML reaches a vendor parser only from its first `<`. A pasted message that declares a document type is refused, and no entity or schema the text names is resolved.
- **Posture questions** go to the orchestrator, with options and a recommendation.

## Technical Decisions

- **Client loading (AD-5, AD-19).**
  - Every screen route has one `''` child that loads through `rememberedPage(loader)`, the loader named in `ScreenOutlet`'s maps. Several descriptors may share one loader, as the editor screens share `INTEROP_EDITOR_PAGE`.
  - A new screen of an existing page needs only a descriptor and its map line. A new page needs one loader line, never a static import or a preloading strategy. Routes are generated from the descriptor mirror, and `screens.generated.ts` is never hand-edited.
  - The initial bundle is about 1.91 MB, against `maximumWarning` 1992kB, re-measured at each forward merge. Each lazy chunk stays under 88 kB.
  - The client is zoneless and `OnPush`, and screen state lives in framework-free stores. A lazy-loading defect is fixed in the product, never with a wait in a spec.
- **Embedded apps (AD-63)** are a named exception to AD-28 and AD-47.
  - **Source.** Only `interopEditorSource` (`ui/src/app/core/vendor-frame.ts`) builds `/ui/interop/<app>/index.html` on the instance's origin, with `$NAMESPACE`. It builds from a closed vocabulary: `rule-editor` takes `rule`, `dtl-editor` takes `DTL` and `bpl-editor` takes `BP`, and 20.8 adds `interop-editor` with `$PRODUCTION`. 20.8 also adds `schema-viewer`, which takes no parameter and answers `null` if given a document. Today every document value must match `CLASS_NAME`, and anything else answers `null`, so no frame is drawn. The text `/ui/interop` appears nowhere else in the client.
  - **Frame.** `app-interop-editor-frame` draws one unsandboxed `<iframe>`. `src` is set once through `Renderer2`, with no `sandbox`, `allow`, `srcdoc` or `credentialless`. A new source or `revision` draws a new element.
  - **Nothing crosses.** There is never `?VSCODE=1` and never a pre-written token. OcuPilot posts nothing into the frame and reads nothing from it. The CSP, `index.html`, headers, token store and CORS are unchanged.
  - **Sign-in and sign-out.** The vendor's client calls `%Api.InteropEditors` as the person. Sign-out ends the app's sign-in and revokes its pair, and also revokes the copy a `noopener`-less tab received.
  - **Same origin.** The frame can read the tab's `ocupilot.token-pair` and script the shell, as any same-origin code can. 20.16's editor page redraws on a `changed` event of type `class` that names its document.
- **Interoperability port (AD-62, `Port/InteropPort`).**
  - **Its role.** It is the only class that starts, stops, restarts, updates or recovers a production, and the only source of declared interoperability reads. It calls the documented vendor classes the classic pages call, in process, as the signed-in user.
  - **Extending it.** A new read or write extends the port and names its case in AD-62 at its spec gate. A read also names its case in AD-36.
  - **Class kinds.** `Coded` and `IsCodeOfKind` answer dictionary-descent questions while switched, and write nothing.
- **Gate first.** The vendor's production, lookup, partner and test calls check no privilege (measured), so the port's gate is the whole gate.
  - **Order.** The endpoint's pairs come first, then READ on the namespace's globals database (WRITE for a write). A refusal names the failed pair.
  - **Extra pairs** are declared only where a least-privileged run measured them. Each is refused by name before any port call and pinned by a test that removes it.
  - **The code lists and their editors** declare `%Ens_Code:READ`, so holders of only the narrower rule, DTL or BPL resources (and `%EnsRole_RulesDeveloper`) are refused. AD-8 accepts that narrower audience.
  - **The floor** admits `%Ens_Portal:USE`, so every new surface declares its own pair, sharing a member with its classic page's resource. The `InteropFloor*` rosters pin this.
- **Classic pages and adjustment (AD-44, AD-64).** `Screen.Gate.RequiredPairs` is the one reader of a screen's requirement. It unions the custom resource of each classic page the screen replaces. A screen replacing several classic pages names the extra ones in its descriptor class's `CLASSICPAGES`, as a write tool does. A port's pairs and the vendor's are never adjustable.
- **SQL reads without grants.** `InteropPort` reads `Ens.MessageHeader` and `Ens_Util.Log` with `%ExecDirectNoPriv` after its own gate. Such a statement nests no query that carries `TOP`: on a cold cached query that is refused with SQLCODE -99, and a copy a privileged reader warmed hides the failure. The item Messages read is therefore a top-level `UNION ALL` of two `TOP` branches.
- **Namespace.** `appliesWhen` decides whether a surface applies, not who may open it. It uses `IsEnsembleNamespace`, plus `%IsDeepSeeEnabled` for Analytics. The port switches by explicit save and restore and calls no `OcuPilot.*` class while switched. OcuPilot adds no elevation. A namespace under source control refuses item and lookup writes.
- **Write shape.**
  - **Action-style.** Each write declares its request type and fingerprints a fresh read the port composes. Anything the vendor would answer as a silent success, or write to the device about, is refused by name before any vendor call.
  - **Two callers, one operation.** A screen action and the agent's write share the fresh read, the prohibited set inside the per-target lock, the gate, the change event and the read-back. Only the agent's caller mints, writes the marker and answers to the agent switches.
  - **One request.** Each write finishes in its own request, capped at 15 s, with no spawn site. A troubled production gets Recover, never Clean.
  - **Snippets.** Every port that defines `Invoke` also defines a pure `Snippet` mirroring each branch, with secrets as placeholders.
- **Audit.** Item and setting changes go through `Ens.Util.Auditing.AuditModifyProductionConfig`, never with a value. Writes the vendor does not audit record OcuPilot's own `ConfigChange`.
- **Tests and parsing.** Extend the shared helpers rather than copy them: `IsTestWrite`, the `INTEROP.TEST.*` codes, `AddTestLines`, `core/test-answer.ts` and `AtelierPort`'s output capture. A test's output reaches only the screen and the proposal card, never the model. HL7 text reaches its parser as a character stream, not through `ImportFromString` (DW-2378, in the burn-down).
- **Reads and ids.** Reads use source kind `interop`. A parent-scoped list takes its parent's route id as its one criterion and answers the parent key on each row. Every read has a row cap and reports truncation. An id keeps every part exactly, never uses the vendor's integer id, and is percent-encoded in one path segment.
- **Tools.**
  - **Declarations.** Each tool declares its `CLASSICPAGES`, and each new write type is reviewed against AD-10's prohibited set.
  - **Hierarchy and names.** New interoperability tools extend the `InteropAction` hierarchy and are named `<area>.<screen>.<verb>`.
  - **What a turn sees.** A turn starts with the shell area's tools, `shell.tools.find` and the screen context's `tools`. A screen's context lists its read, its declared actions' writes, and any `SCREENLISTED` agent-only write.
  - **Gemini.** Keep numeric enums at the top level of the schema (DW-2358).
- **Untrusted content.** Message bodies, log text, names, settings, lookup values, test inputs and outputs, and rule, DTL or BPL content reach the model only through the one sanitizer. No gate or test relies on the sanitizer as its defense.
- **Measure on the instance**, and amend the spine at the spec gate rather than working around it.

## UX & Interaction Patterns

- **Loading.** A screen's first load shows its skeleton until the first page arrives (two-second target), never on a re-fetch.
- **Rail and tabs.** Interoperability and Analytics follow System Explorer and appear only where the namespace reports the feature. A screen joins the side bar only once it has shipped. An item's tabs are Status, Settings, Queue, Log, Messages, Jobs and Test.
- **Embed screens** are `viewer (source)` screens with a bar above the frame holding the note and Refresh.
  - **The editors** are unlisted, at `<list route>/document/<name>.cls`, and opened from the list name cells. 20.16 adds a note that the agent reads only what is saved.
  - **The Schema viewer** has no read, so it shows no skeleton, empty sentence or refusal of its own.
  - **The Configuration diagram** behaves as the editors do, with "This production no longer exists."
- **Gated controls are never hidden.** They stay focusable and `aria-disabled`, and name the failed pair.
- **Strings.**
  - Each list has a title, an empty state and three suggested prompts. A write-capable list's empty state adds the line inviting the agent.
  - Every new string goes into EXPERIENCE.md's Fixed strings and `strings.ts`, whose values are unique. A refusal sentence lives once, on the server, pinned equal to its fixed string.
  - `strings.test.mjs` bounds the literal count at 3,400, and the count is 3,371. The bound is raised once to 3,800 by whichever story lands first: Epic 18's 18.38 is ruled to, and 20.16 and 20.8 raise it only if it still reads 3,400.
- **Dialogs.** A dialog exists only where EXPERIENCE.md's dialog list names one. A new dialog or pre-write warning amends that list at the spec gate. Dialogs never stack, and a destructive screen action uses the typed-name confirm.
- **Auto-refresh** is opt-in per screen, off by default, and declared in the descriptor and EXPERIENCE.md's roster.
- **Cards.** Proposal cards follow the standard lifecycle, and production cards say to recover before cleaning. An agent's destructive proposal carries no typed name. A block over about eight lines starts collapsed with a summary line, and Confirm never requires expanding it.

## Cross-Story Dependencies

- **Done:** 20.1 to 20.7, 20.13 to 20.15, 20.17 to 20.24, and 20.27 to 20.29. 20.7's CI rework head, `49436efa`, was committed with run 38463014073 still pending at this compile.
- **Order.** 20.16, then 20.8, both ready for development. Then 20.9 to 20.12, in the orchestrator's order. The orchestrator places 20.25, and 20.26 follows it.
- **20.16 and 20.8 share** the editor page, its store, `strings.ts`, EXPERIENCE.md and their tests.
  - 20.8's Task 0 re-anchors to whatever 20.16 merged, and shows 20.16's agent line only on the rule, BPL and DTL kinds.
  - If 20.16 has not merged by then, that bullet routes to 20.16 instead.
- **20.9 consumes:**
  - 20.4's item Messages read and the `interop-message` entity type (inference).
  - 20.6's host test, which answers a session id a trace can open.
  - 20.8's vocabulary and page shape, for an embed of the message viewer (inference).
- **Consumers of 20.9.** 20.12's harvested resend-failed-messages workflow needs this stage's message screens.
- **20.10** runs source control inside these frames.
- **Known defects in the embeds.**
  - **DW-2395, escalated.** OcuPilot's `LogSourcePort.IntegrityReport` closes the web process's null device even when that process already held it.
    - A later vendor compile in that process (DTL, BPL) fails `<NOTOPEN>`, and the editor shows a server error.
    - It is routed to the burn-down, because Epic 18 is changing that file.
    - 20.7's browser spec accepts the vendor's notice only when the log records that `NOTOPEN`. Drop that tolerance when the fix lands.
  - **DW-2394, on the owner's hold.** The vendor uses the null device without opening it.
- **Epic 18 runs beside this epic.**
  - **Shared rosters** take add-only edits, summed at the forward merge: the entity types, the screen mirror, `strings.ts`, the navigation tests, EXPERIENCE.md's rows, and the `ReadTool` and `ToolRoundTrip` tool rosters (379 tools after 18.37; 20.16 adds six). Anything else is asked first. Every new Epic 20 screen also needs a row in `Test/StageTwoTools`'s `Elsewhere` block.
  - **Interoperability usage** (18.37) is an OS management screen. It is read in `%SYS` through `MonitorPort`, not `InteropPort`.
- **Into Epic 21.** Epic 21 reuses 20.12's diagnose-slow-query workflow. It owns interoperability credentials, purge, deployment, record maps, workflow and the analytics editors, so those stay out of this epic.
