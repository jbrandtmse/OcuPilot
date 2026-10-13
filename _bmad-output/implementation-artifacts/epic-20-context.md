# Epic 20 Context: Stage 4 - Interoperability, with the Analytics rider

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Bring the classic portal's Interoperability work into OcuPilot for namespaces that support it, with Analytics riding along, so the largest area the classic portal still owns is usable here. Shipped so far: category gating, production control, items and their settings, per-host tabs, the monitor, queue and job reads and actions, lookup tables, read-only business partners, host and transformation tests, the interoperability floor, per-screen permissions, the panel collapse, the agent's source reads, saves and creates, the shared tool-listing cache, the sign-in hand-off every embedded vendor editor needs, a clean compile and install in a namespace without interoperability, and screens that load on demand. 20.7 is ready for development: the rule, BPL and DTL editors InterSystems already built, loaded in place inside the shell, so they are reused rather than rebuilt. 20.16 is the next story to plan: the agent edits the content behind those editors, on the person's confirmation. Still to come: the schema viewers and configuration diagram, source-control hooks, message search, resend and trace, item runtime actions, partner writes, the Analytics rider, and guided workflows with Investigate.

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
- **The embedded editors (20.7, ready for development).**
  - **In place, never copied.** Each editor loads from the instance, signed in through 20.13's hand-off. The vendor's bundles are never copied or redistributed, and they carry no license text.
  - **Messages, as re-scoped.** In normal mode the editor reports a save, a compile and a failed compile in its own notice inside the frame. No message reaches OcuPilot's shell or the frame, and OcuPilot shows a result only through its own reads (the list's Modified after its next fetch).
  - **What opens an editor.** Each screen sits at `<list route>/document/<name>.cls`, opened from its list's name cell, and issues only its list's own declared read. It draws the frame only for a row that read answers, and for a process or transformation only when the row is not `Coded`. Otherwise it shows its "no longer exists" or "written as a class" sentence; a refusal names the failed pair.
  - **A drawn frame is never navigated (DW-2350).** A new document, a namespace move or Refresh draws a new frame, so the editor's unsaved-changes alert does not show (measured), and the screen's note asks the person to save first. No leave guard or confirm dialog. DW-2376 is decision-pending in the burn-down: keep the note and Refresh, or have a later story add a leave guard that raises the editor's own alert (an AD-63 amendment).
  - **The editor can move away unseen (DW-2351)** through its logo, Back to standard UI, its own Open, Namespace and Settings, and the history entries DTL and BPL push. The screen keeps naming its own document, never reads the frame, and Refresh opens that document again. Back moving the frame first is a named limit.
  - **DW-2347.** 20.7's browser spec re-runs `ui/browser/interop-editor-spec.mjs`'s assertions against the real screens.
  - **Scope.** Each editor screen declares its own screen, gate, classic page and adjustable pairs. 20.7 adds no write tool, governance key, entity type, read tool or area, and leaves the three lists' columns, row actions, prompts and empty states alone. A new rule, BPL or DTL is created with the editor's own New, never with a `NEW` parameter.
- **Rule, DTL and BPL edits (20.16, next to plan).**
  - **The owner's flow.** Warn the person to save the editor if needed, because OcuPilot cannot read the frame's unsaved state. The agent then reads the stored content and proposes the edit with its diff and the agent marker. Confirm is refused when the stored content changed after the mint (a fingerprint or ETag, as the source saves use). After the write, the editor reloads and shows the new content.
  - **Posture.** Its governance key ships enabled, and the confirmation is the standard confirmed proposal. The plan raises a typed-name confirmation for DTL or BPL code only if it finds a concrete reason.
  - **Why the warning comes first.** A reload draws a new frame, and removing a frame drops the editor's unsaved changes without its alert (measured at 20.7's plan).
- **What 20.16 builds on (20.19 to 20.21).**
  - **Read.** The agent reads source through a read tool capped at about 60,000 characters, cut at whole lines, passed through the one sanitizer and reporting truncation.
  - **Save.** The agent sends exact replacements, and each `Old` must match exactly once against the stored text. The model's copy passed the sanitizer, so it can differ; the mint then refuses and tells the model why. The mint stores the new text and one changed-lines hunk of at most 30,000 characters. Every save compiles on Confirm: the card says so beforehand, and afterwards it says plainly when a document saved but did not compile.
  - **Where.** The agent saves only a document stored in its namespace's own routines database. Never in `%SYS`, never a `%` name, never under OcuPilot's own packages, checked at the mint and again at Confirm. A mapped document's refusal names where it lives and says the person can save it from the editor.
- **Other embeds.** Each embed story's Task 0 establishes its vendor contract on the instance: the schema browsers' document parameter for 20.8, and the hook exchange for 20.10.
- **Messages (20.9).** Search and the viewer read through the port, with saved searches where the API offers them. Resend and edit-and-resend take a dry run, then a Confirm, with a bounded cap per action. A session trace renders visually, with a generated sequence diagram as the alternative. The message-contents renderer is the custom half.
- **Item runtime actions (20.25).** A temporary stop, start or restart of one item is followed by the production update the vendor requires. Each is refused by name where the vendor would answer success while doing nothing (a stopped production, a disabled item). Copy and change of class run as the classic page does, and the vendor audits them.
- **Partner writes (20.26)** on `Ens.Config.BusinessPartner`.
  - Each is confirmed over a fresh read and records OcuPilot's own audit row.
  - The vendor renames by a delete and a create with no transaction, so a rename is either refused or done in one transaction.
  - Removing a partner that an item's `BusinessPartner` setting names first reads those items, then refuses or warns.
  - The pair posture goes to the orchestrator; 20.5's plan recommends `%Ens_ProductionConfig:WRITE`.
- **Analytics (20.11).** Cube build, synchronize and repair are the only analytics writes. MDX results render with drill-through and cancel. Architect, Analyzer and the User Portal are linked, not rebuilt; anything beyond those links needs a DeepSee-enabled namespace.
- **Workflows and Investigate (20.12).** A workflow is a sequence of individually confirmed proposals, never a batch approval. Each write still evaluates the prohibited set, both agent switches and governance. Investigate starts from an alert or a log entry and returns a recap and ranked hypotheses that cite the rows used. Harvested prompts take OcuPilot's names.
- **No compile-time dependency on interoperability (standing since 20.28).** No shipped class includes `Ensemble` or another interoperability include, or names an `Ens.*`, `EnsLib.*` or `EnsPortal.*` class where the compiler resolves it (a superclass, a property, an argument or return type, `DependsOn`, `CompileAfter`, or a class query's SQL). Such a value is typed `%RegisteredObject` or `%String` and reached at run time while switched; `##class(Ens.…)` in a method body, `#dim`, embedded SQL and strings all compile. `OcuPilot.Test.CompileWithoutInterop` and the `package` job's IPM install into a namespace without interoperability enforce the rule. Test classes are out of scope.
- **Secrets and paths.** A Secrets-pattern setting answers an empty value and default, with `Secret` true, and setting one is refused before any vendor call, from both callers. A secret under a non-matching name is a named limit. No endpoint accepts a path outside a case AD-21 names, and pasted content is never a path: pasted XML reaches a vendor parser only from its first `<`, a message that declares a document type is refused, and no entity or schema the text names is resolved (both tests do this today).
- **Posture questions** go to the orchestrator, with options and a recommendation.

## Technical Decisions

- **Client loading (AD-5, as built in 20.29).**
  - **Pages load on demand.** Every screen route has one `''` child whose `loadComponent` is `rememberedPage(loader)`, the loader named in `ScreenOutlet`'s maps (`ARCHETYPE_PAGES`, `DESCRIPTOR_PAGES`, `DESCRIPTOR_EDIT_PAGES` in `shell/screen-outlet.ts`). One page has one loader. `ScreenOutlet` still decides whether a page mounts.
  - **Adding a screen.** A new screen of an existing page is descriptor-only. A new page is one loader line, never a static import, and no preloading strategy is added; `build-output.test.mjs` reddens naming an eager page. Routes stay generated from the descriptor mirror, and `screens.generated.ts` is never hand-edited.
  - **Ready and focus.** The outlet's host reads `aria-busy` until its routed page renders, and a focus hand-off lands after the lazy page renders. A lazy-loading defect is fixed in the product, never with a wait in a spec. DW-2372 (routed to the burn-down): a create form's first hand-off to an editor in another module shows the form's Saved status while that editor's code loads.
  - **Budgets.** The initial bundle is about 1.90 MB after 20.27, against `maximumWarning` 1992kB and `maximumError` 4000kB, which `angular-json.test.mjs` pins. Each lazy chunk stays under 88 kB, and each forward merge re-measures the warning on the merged tree. The area stores and actions `app.ts` constructs (about 427 kB) stay initial (DW-2367).
  - **AD-19.** Zoneless, `OnPush`, screen state in framework-free stores; `core/` imports no `@angular/core`.
  - **Browser specs** reach screens by navigation, never by importing page modules, and run against the deployed bundle, so rebuild and redeploy before reading any result.
- **Embedded editors (AD-63)** are a named exception to "tokens never within a frame's reach" and "an embedded vendor page is inert".
  - **Source.** Only `interopEditorSource` (`ui/src/app/core/vendor-frame.ts`) builds `/ui/interop/<editor>/index.html` on the instance's origin, from a closed vocabulary: `rule-editor` takes `rule`, `dtl-editor` takes `DTL`, `bpl-editor` takes `BP`, and the namespace goes in `$NAMESPACE`. Values come from OcuPilot's own reads and are percent-encoded; anything else answers `null` and no frame is drawn. A new `/ui/interop` app (20.8) joins once its parameter is read on the instance.
  - **Frame.** `app-interop-editor-frame` (`areas/interoperability/interop-editor-frame.ts`) draws one unsandboxed `<iframe>` (a sandboxed frame never signs in), with `src` set through `Renderer2` and no `sandbox`, `allow`, `srcdoc` or `credentialless` attribute. Its accessible name is the per-editor title. It makes no API call. 20.7 adds a `revision` input: a change of source or revision draws a new element, and `src` is set once per element. 20.16's reload is that page's Refresh path, a new revision (inference).
  - **Normal mode only.** Never `?VSCODE=1`, and never pre-written tokens.
  - **Nothing crosses.** OcuPilot posts nothing into the frame and reads nothing from it (no `contentWindow`, `contentDocument`, `frames`, messages or vendor storage keys). The token store, the CSP, `index.html` and the headers are unchanged, and CORS stays off. The vendor's own client in the frame calls `%Api.InteropEditors` as the person; OcuPilot calls none of it.
  - **Sign-in and sign-out.** The editor signs itself in from the browser-level login and clears its own keys on `pagehide`. OcuPilot's sign-out ends that sign-in and revokes each editor's own pair, and the shell withholds every frame while signed out.
  - **Named consequences.** The frame can read the tab's `ocupilot.token-pair` and script the shell, as any same-origin code can. The editor's own Logout ends OcuPilot's pair, which shows its session-ended card at the next request and never fills or reads the editor's sign-in form. A tab the editor opens without `noopener` gets a copy of the tab's storage, and sign-out revokes it.
- **Interoperability port (`Port/InteropPort`).** The only class that starts, stops, restarts, updates or recovers a production, and the only source of declared interoperability reads. It calls the documented vendor classes the classic pages call, in process, as the signed-in user, and never calls `%Api.InteropEditors.*`. A new read or write extends this port and names its case in AD-62 at its spec gate, and in AD-36 too for a read.
  - **`Coded` (20.7).** The Processes and Transforms lists answer `Coded`, true for a class that does not descend from `Ens.BusinessProcessBPL` or `Ens.DataTransformDTL` in the dictionary (the vendor's editors answer 400 for one). It is read while switched and writes nothing; Rules rows stay `{Name, Modified}`.
- **Gate first.** The vendor's production, lookup, partner and test calls check no privilege (measured), so the port's gate is the whole gate.
  - **Order.** The endpoint's pairs, then READ on the namespace's globals database (WRITE for a write); a refusal names the failed pair.
  - **Extra pairs.** Declared only where a least-privileged run on a throwaway measured them, refused by name before any port call, and pinned by a test that removes them.
  - **The code lists.** The rules, transformations and processes lists declare `%Ens_Code:READ`; a holder of only `%Ens_Rules`, `%Ens_RoutingRules`, `%Ens_BusinessRules`, `%Ens_DTL` or `%Ens_BPL` is refused, a narrower audience AD-8 accepts.
  - **The floor** admits `%Ens_Portal:USE`, so every new surface declares its own pair, and the `InteropFloor*` rosters pin it.
  - **Adjustment.** `Screen.Gate.RequiredPairs` is the one reader of a screen's requirement. A port's pairs and the vendor's are never adjustable.
- **Source saves (`Port/AtelierPort`, which 20.16 builds on).** The gate is `%Development:USE` and READ on the namespace's routines and globals databases and every database it maps code from except IRISSYS, plus WRITE on the target's routines database for a save. A save sends the version it read and never `ignoreConflict`, so the vendor refuses a document another writer changed: 409 is `EXPLORER.DOCUMENT.CONFLICT`, 423 `EXPLORER.DOCUMENT.LOCKED`.
- **SQL reads without grants.** `InteropPort` reads `Ens.MessageHeader` and `Ens_Util.Log` with `%ExecDirectNoPriv` after its own gate. Such a statement nests no query that carries `TOP`: on a cold cached query it is refused SQLCODE -99, and a copy a privileged reader warmed hides that. The item Messages read is therefore a top-level `UNION ALL` of two `TOP` branches.
- **Namespace.** `appliesWhen` (`IsEnsembleNamespace`, and `%IsDeepSeeEnabled` for Analytics) decides whether a surface applies, not who may open it. The port switches by explicit save and restore and calls no `OcuPilot.*` class while switched; rows are built after the restore. OcuPilot adds no elevation. A namespace under source control refuses item and lookup writes.
- **Write shape.**
  - **Action-style.** Each write declares its request type, sends no body or a port-built one, and fingerprints a port-composed fresh read; a create fingerprints the target's absence. Whatever the vendor would answer as a silent success, or write to the device about, is refused by name before any vendor call.
  - **Two callers, one operation.** A screen action and the agent's write share the fresh read, the prohibited set inside the per-target lock, the gate, the change event and the read-back. Only the agent's caller mints, writes the marker and answers to the agent switches. 20.18's dispatch refuses before any mint when the user does not hold the screen's effective pairs.
  - **Its own request.** Each write finishes in its own request, capped at 15 s, with no spawn site. A troubled production gets Recover, never Clean.
  - **After OK.** The write re-reads its target (`readBack`). Every port that defines `Invoke` also defines a pure `Snippet` mirroring each branch, with secrets as placeholders.
- **Audit.** Item and setting changes go through `Ens.Util.Auditing.AuditModifyProductionConfig`, never with a value. Writes the vendor does not audit, tests included, record OcuPilot's own `ConfigChange` from either caller.
- **Tests (20.6 and 20.27).** The shared helper is `IsTestWrite`, the `INTEROP.TEST.*` codes, `AddTestLines`, `core/test-answer.ts` and the output capture `AtelierPort` opens; extend each rather than copy it. A test's output, error and console lines ride the confirm response to the screen and the proposal card only (AD-39's seventh exception), never to the model, a tool result, the ledger, an audit payload, a log line or screen context.
- **Reads and ids.** Reads use source kind `interop`. A parent-scoped list takes its parent's route id as its one criterion and answers the parent key on each row. Every read has a row cap and reports truncation. An id keeps every part exactly, never uses the vendor's integer id, and is percent-encoded in one path segment; `production-item` is `[Production, Name]`.
- **Tools.**
  - **Declarations.** Each tool declares its `CLASSICPAGES`, and each new write type is reviewed against AD-10's prohibited set. The editor screens' classic pages are `EnsPortal.RuleEditor`, `EnsPortal.BPLEditor` and `EnsPortal.DTLEditor`.
  - **Hierarchy and names.** New interoperability tools extend the `InteropAction` hierarchy rather than copying a sibling, and are named `<area>.<screen>.<verb>`.
  - **Reaching the model.** A turn starts with the shell area's tools, the discovery tool `shell.tools.find`, and the screen context's `tools`; every other tool is reached through discovery.
  - **Gemini schemas.** Keep numeric enums top-level; one nested deeper is respelled but not decoded (DW-2358, accepted).
- **Untrusted content.** Message bodies, log text, names, settings, lookup values, test inputs and outputs, and rule, DTL or BPL content reach the model only through the one sanitizer. No gate or test relies on the sanitizer as its defense.
- **Measure on the instance**, and amend the spine at the spec gate rather than working around it.

## UX & Interaction Patterns

- **Loading.** A screen's first load shows its skeleton until the first page arrives (two-second target), and never on a re-fetch. A lazily fetched screen is held to the same target (inference).
- **Rail and tabs.** Interoperability and Analytics follow System Explorer and appear only where the namespace reports the feature. A screen joins the side bar only once it has shipped; the editor screens are unlisted. An item's tabs: Status, Settings, Queue, Log, Messages, Jobs, Test.
- **The editor screens** are `viewer (source)` screens whose content is the vendor's editor in a frame. Empty is the screen's "no longer exists" sentence, a process or transformation written as a class shows its sentence instead of an editor, and refreshing is Refresh, which opens the document in a new frame. A bar above the frame holds the note ("Leaving this screen, or choosing Refresh to open the document again, discards any change not saved in the editor.") and Refresh. Frame titles are "Rule editor", "DTL editor" and "BPL editor", and each screen has three suggested prompts.
- **Other embeds.** The configuration diagram renders in place, and its sibling editors open in new tabs. The HL7, X12 and ASTM schema browsers are read-only.
- **Gated controls are never hidden.** They stay focusable and `aria-disabled`, and name the failed pair.
- **Strings.** Each list has a title, an empty state and three suggested prompts, and a write-capable list's empty state adds the line inviting the agent. Every new string goes into EXPERIENCE.md's Fixed strings and `strings.ts`, whose values are unique. A refusal sentence lives once, on the server, pinned equal to its fixed string. `ui/tools/strings.test.mjs` bounds the Fixed strings literal count at 3,400 (3,326 after 20.27) and is raised once the count comes within 50 of it.
- **Dialogs.** A dialog exists only where EXPERIENCE.md's dialog list names one, and a new dialog or pre-write warning amends that list at the spec gate. Dialogs never stack, and a destructive screen action uses the typed-name confirm.
- **Auto-refresh** is opt-in per screen, off by default, and declared in the descriptor and in EXPERIENCE.md's roster.
- **Cards.** Proposal cards follow the standard lifecycle, and production cards say to recover before cleaning. An agent's destructive proposal carries no typed name. A block over about eight lines starts collapsed with a summary line naming what changes, where and how big, plus the compile outcome where there is one; Confirm never requires expanding it.

## Cross-Story Dependencies

- **Done:** 20.1 to 20.6, 20.13 to 20.15, 20.17 to 20.24, and 20.27 to 20.29. 20.27's code head was committed with its CI run still pending at this compile.
- **Order.** 20.7 (ready for development), then 20.16, then 20.8 to 20.12, in the orchestrator's order. The orchestrator places 20.25 and 20.26.
- **20.7 consumes** 20.13's `interopEditorSource`, `app-interop-editor-frame` and `interop-editor-spec.mjs`; 20.2's `ListClasses` and the three list reads, which gain `Coded`; 20.29's loader maps (one page, one lazy chunk under 88 kB); and Epic 19's `listForDocumentScreen` and `screenReadPath`. It owns DW-2347, DW-2350 and DW-2351.
- **20.16 consumes** 20.7's editor screens (its reload a new revision, inference), 20.19's source read, 20.21's saves, 20.17's card collapse and 20.18's refusal on a screen the user cannot open. 20.27's test can check a DTL edit, and 20.12's workflows may propose one (both inference).
- **Later embeds.** 20.8's schema viewers and diagram reuse the frame's `revision` and the editor page's shape (inference), and its diagram shows 20.3's items. 20.10 runs source control inside these frames.
- **Other links.** 20.9's trace reuses `interop-message` (inference) and renders the session id a host test answers. 20.12 can run a guided disable followed by Update. 20.25 consumes 20.3's items and 20.4's per-host tabs, and 20.26 consumes 20.5's Business partners screen and read.
- **Later screens.** Every screen added from here (20.7 to 20.11, 20.25, 20.26) is a loader line in `ScreenOutlet`'s maps.
- **Epic 18 runs beside this epic.**
  - **Shared rosters** take add-only edits, summed at the forward merge: the entity types, the screen mirror, `strings.ts`, the navigation tests, EXPERIENCE.md's rows, and the `ReadTool` and `ToolRoundTrip` tool rosters (376 tools, 194 writes after 18.42). Anything else is asked first. Every new Epic 20 screen also needs a row in `Test/StageTwoTools`'s `Elsewhere` block.
  - **The bundle.** Epic 18's new pages are loader lines too, and each forward merge re-measures `maximumWarning` on the merged tree.
- **Into Epic 21.** Epic 21 reuses 20.12's diagnose-slow-query workflow. It owns interoperability credentials, purge, deployment, record maps, workflow and the analytics editors, so those stay out of this epic.
