# Epic 20 Context: Stage 4 - Interoperability, with the Analytics rider

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Bring the classic portal's Interoperability work into OcuPilot for namespaces that support it, with Analytics riding along, so the largest area the classic portal still owns is usable here. Shipped so far: category gating, production control, items and their settings, per-host tabs, the monitor, queue and job reads and actions, lookup tables, read-only business partners, host and transformation tests, the interoperability floor, per-screen permissions, the panel collapse, the agent's source reads, saves and creates, the shared tool-listing cache, the sign-in hand-off, a clean compile and install in a namespace without interoperability, screens that load on demand, and the rule, BPL and DTL editors InterSystems built, loaded in place inside the shell (20.7). 20.16 is ready for development: the agent edits the content behind those editors, on the person's confirmation. 20.8 is the next story to plan: the HL7, X12 and ASTM schema viewers and the production configuration diagram, embedded the way 20.7 embeds the editors. Still to come: source-control hooks, message search, resend and trace, item runtime actions, partner writes, the Analytics rider, and guided workflows with Investigate.

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
- **Embedding a vendor app (20.7 as built; 20.8 and 20.10 follow it).**
  - **In place, never copied.** The app loads from the instance, signed in through 20.13's hand-off. The vendor's bundles are never copied or redistributed, and they carry no license text.
  - **Normal mode.** The app reports a save, a compile or a failed compile in its own notice inside the frame. Nothing reaches OcuPilot's shell, and OcuPilot shows a result only through its own reads (a list's Modified after its next fetch).
  - **What opens a frame.** A screen issues only its source list's declared read and draws the frame only for a row that read answers; for a process or transformation, only when the row is not `Coded`. Otherwise it shows its "no longer exists" or "written as a class" sentence, and a refusal names the failed pair.
  - **A drawn frame is never navigated.** A new document, a namespace move or Refresh draws a new frame, so the app's unsaved-changes alert does not show. The screen's note says that leaving it, or choosing Refresh, discards any change not saved in the editor (DW-2376, ruled by design). No leave guard and no confirm dialog. DW-2388, a probe for a vendor-emitted dirty signal, is in the burn-down.
  - **The app can move away unseen**: its logo, Back to standard UI, its own Open, Namespace and Settings, and the history entries it pushes. The screen keeps naming its own document, never reads the frame, and Refresh opens that document again.
  - **Scope.** Each embed screen declares its own screen, gate, classic page and adjustable pairs. An embed brings no write tool, governance key, entity type, read tool or area. A new rule, BPL or DTL is created with the editor's own New, never with a `NEW` parameter.
- **The schema viewers and the diagram (20.8, next to plan).**
  - **Task 0 first.** Each app's document parameter is established on the instance before anything is built.
  - **The schema viewer.** The research reads one app, `/ui/interop/schema-viewer`, for HL7, X12 and ASTM, rated medium-low: the classic schema pages pass a malformed `&ST` key, and the bundle reads no `ST`, so its document-selection contract is unproven (research reading, not measured). The viewers are read-only.
  - **The diagram.** The research reads `/ui/interop/interop-editor` with `$NAMESPACE`, `$PRODUCTION` and an optional `HOST`. It writes those parameters back with `history.pushState`, and its sibling editors and message viewer open in new tabs (research reading, not measured). It renders in place.
  - **Joining the source builder.** A new app joins `interopEditorSource`'s closed vocabulary only once its parameter is read on the instance. Today the document value must be a class name (`CLASS_NAME`). A `$PRODUCTION` value is one; a schema parameter that is not would need its own shape under AD-21 (inference).
  - **The diagram is the vendor's production configuration app**, so in it the person may change configuration as themselves, as in the rule editor (inference).
- **Rule, DTL and BPL edits (20.16, ready for development).**
  - **The owner's flow.** Warn the person to save the editor if needed, because OcuPilot cannot read the frame's unsaved state. The agent then reads the stored content and proposes the edit with its diff and the agent marker. Confirm is refused when the stored content changed after the mint (the class save's `Modified` fingerprint). After Confirm the editor shows the saved text.
  - **Six tools.** `interop.ruleeditor`, `interop.processeditor` and `interop.transformeditor`, each with `.source` and `.save`. They extend 20.21's class read and class save through two abstract bases. The saves are agent-only and declare `SCREENLISTED`, so the editor screen's context lists them.
  - **Pairs.** Each tool requires the editor screen's effective pairs plus `%Development:USE`. Each save also requires `%Ens_Code:WRITE`, because the orchestrator ruled the path is never looser than the classic editor, and keeps routines-database WRITE. A holder of only `%Ens_DTL`, `%Ens_BPL` or `%Ens_Rules*` WRITE is refused, and so is `%EnsRole_Administrator`, which holds `%Ens_Code:READ` only.
  - **Kind check.** A save admits only a class its editor opens: a subclass of `Ens.Rule.Definition`, `Ens.BusinessProcessBPL` or `Ens.DataTransformDTL` in the dictionary. It is checked at the mint and again at Confirm.
  - **The warning comes three times**: the screen's bar says the agent reads only what is saved, the tools' descriptions tell the model to say so first, and the card says confirming drops the editor's unsaved changes.
  - **Posture.** Keys ship enabled, with the standard confirmed proposal, no typed name, and a compile on Confirm.
- **What 20.16 builds on (20.19 to 20.21).**
  - **Read.** Capped at about 60,000 characters, cut at whole lines, passed through the one sanitizer, reporting truncation.
  - **Save.** The agent sends exact replacements, each `Old` matching exactly once against the stored text; the model's sanitized copy can differ, and the mint then refuses and says why. The mint stores the new text and one changed-lines hunk of at most 30,000 characters. Every save compiles on Confirm, and the card says plainly when a document saved but did not compile.
  - **Where.** Only a document stored in its namespace's own routines database: never in `%SYS`, never a `%` name, never under OcuPilot's own packages, checked at the mint and again at Confirm. A mapped document's refusal names where it lives and says the person can save it from the editor.
- **Messages (20.9).** Search and the viewer read through the port, with saved searches where the API offers them. Resend and edit-and-resend take a dry run, then a Confirm, with a bounded cap per action. A session trace renders visually, with a generated sequence diagram as the alternative. The message-contents renderer is the custom half. The research reads the vendor's viewer as `/ui/interop/message-viewer` with `SESSIONID`.
- **Source control (20.10).** Its Task 0 establishes the hook exchange on the instance; the hooks, menus, user actions and status go through the port.
- **Item runtime actions (20.25).** A temporary stop, start or restart of one item is followed by the production update the vendor requires. Each is refused by name where the vendor would answer success while doing nothing (a stopped production, a disabled item). Copy and change of class run as the classic page does, and the vendor audits them.
- **Partner writes (20.26)** on `Ens.Config.BusinessPartner`.
  - Each is confirmed over a fresh read and records OcuPilot's own audit row.
  - The vendor renames by a delete and a create with no transaction, so a rename is either refused or done in one transaction.
  - Removing a partner that an item's `BusinessPartner` setting names first reads those items, then refuses or warns.
  - The pair posture goes to the orchestrator; 20.5's plan recommends `%Ens_ProductionConfig:WRITE`.
- **Analytics (20.11).** Cube build, synchronize and repair are the only analytics writes. MDX results render with drill-through and cancel. Architect, Analyzer and the User Portal are linked, not rebuilt; anything beyond those links needs a DeepSee-enabled namespace.
- **Workflows and Investigate (20.12).** A workflow is a sequence of individually confirmed proposals, never a batch approval. Each write still evaluates the prohibited set, both agent switches and governance. Investigate starts from an alert or a log entry and returns a recap and ranked hypotheses that cite the rows used. Harvested prompts take OcuPilot's names.
- **No compile-time dependency on interoperability.** No shipped class includes `Ensemble` or another interoperability include, or names an `Ens.*`, `EnsLib.*` or `EnsPortal.*` class where the compiler resolves it (a superclass, a property, an argument or return type, `DependsOn`, `CompileAfter`, or a class query's SQL). Such a value is typed `%RegisteredObject` or `%String` and reached at run time while switched; `##class(Ens.…)` in a method body, `#dim`, embedded SQL and strings all compile. `OcuPilot.Test.CompileWithoutInterop` and the `package` job's IPM install into a namespace without interoperability enforce it. Test classes are out of scope.
- **Secrets and paths.** A Secrets-pattern setting answers an empty value and default, with `Secret` true, and setting one is refused before any vendor call, from both callers. No endpoint accepts a path outside a case AD-21 names, and pasted content is never a path: pasted XML reaches a vendor parser only from its first `<`, a message that declares a document type is refused, and no entity or schema the text names is resolved.
- **Posture questions** go to the orchestrator, with options and a recommendation.

## Technical Decisions

- **Client loading (AD-5).**
  - **Pages load on demand.** Every screen route has one `''` child whose `loadComponent` is `rememberedPage(loader)`, the loader named in `ScreenOutlet`'s maps (`shell/screen-outlet.ts`). One page has one loader, and several descriptors may name one loader constant, as the three editor screens name `INTEROP_EDITOR_PAGE`. `ScreenOutlet` still decides whether a page mounts.
  - **Adding a screen.** A new screen of an existing page is descriptor-only plus its map line. A new page is one loader line, never a static import, and no preloading strategy is added; `build-output.test.mjs` reddens naming an eager page. Routes stay generated from the descriptor mirror, and `screens.generated.ts` is never hand-edited.
  - **Ready and focus.** The outlet's host reads `aria-busy` until its routed page renders, and a focus hand-off lands after the lazy page renders. A lazy-loading defect is fixed in the product, never with a wait in a spec.
  - **Budgets.** The initial bundle is about 1.91 MB after 20.7, against `maximumWarning` 1992kB and `maximumError` 4000kB, which `angular-json.test.mjs` pins. Each lazy chunk stays under 88 kB, and each forward merge re-measures the warning on the merged tree. The area stores `app.ts` constructs stay initial (DW-2367).
  - **AD-19.** Zoneless, `OnPush`, screen state in framework-free stores; `core/` imports no `@angular/core`.
  - **Browser specs** reach screens by navigation and run against the deployed bundle, so rebuild and redeploy before reading any result.
- **Embedded apps (AD-63)** are a named exception to "tokens never within a frame's reach" and "an embedded vendor page is inert". It binds 20.7, 20.8 and 20.10.
  - **Source.** Only `interopEditorSource` (`ui/src/app/core/vendor-frame.ts`) builds `/ui/interop/<app>/index.html` on the instance's origin, from a closed vocabulary (`rule-editor` takes `rule`, `dtl-editor` `DTL`, `bpl-editor` `BP`) with the namespace in `$NAMESPACE`. Values come from OcuPilot's own reads and are percent-encoded; anything else answers `null` and no frame is drawn. The text `/ui/interop` appears nowhere else in the client.
  - **Frame.** `app-interop-editor-frame` draws one unsandboxed `<iframe>` (a sandboxed frame never signs in), with `src` set once per element through `Renderer2` and no `sandbox`, `allow`, `srcdoc` or `credentialless` attribute. A change of source or of its `revision` input draws a new element. It makes no API call.
  - **Normal mode only.** Never `?VSCODE=1`, and never pre-written tokens.
  - **Nothing crosses.** OcuPilot posts nothing into the frame and reads nothing from it (no `contentWindow`, `contentDocument`, `frames`, messages or vendor storage keys). The token store, the CSP, `index.html` and the headers are unchanged, and CORS stays off. The vendor's own client in the frame calls `%Api.InteropEditors` as the person; OcuPilot calls none of it.
  - **The reload after an agent save.** 20.16 has the editor page listen on `ChangeBus`: a `changed` event of type `class`, in the page's namespace, naming its document calls the store's `refresh()`, which draws a new frame (a new `revision`).
  - **Sign-in and sign-out.** The app signs itself in from the browser-level login and clears its own keys on `pagehide`. OcuPilot's sign-out ends that sign-in and revokes each app's own pair, and the shell withholds every frame while signed out.
  - **Named consequences.** The frame can read the tab's `ocupilot.token-pair` and script the shell, as any same-origin code can. The app's own Logout ends OcuPilot's pair, which shows its session-ended card at the next request and never fills or reads the app's sign-in form. A tab the app opens without `noopener` gets a copy of the tab's storage, and sign-out revokes it.
- **Interoperability port (`Port/InteropPort`).** The only class that starts, stops, restarts, updates or recovers a production, and the only source of declared interoperability reads. It calls the documented vendor classes the classic pages call, in process, as the signed-in user, and never calls `%Api.InteropEditors.*`. A new read or write extends this port and names its case in AD-62 at its spec gate, and in AD-36 too for a read.
  - **`Coded` and `IsCodeOfKind`.** The Processes and Transforms lists answer `Coded`, true for a class that does not descend from `Ens.BusinessProcessBPL` or `Ens.DataTransformDTL` in the dictionary (the vendor's editors answer 400 for one). 20.16 adds `IsCodeOfKind`, the same dictionary question for a rule, BPL or DTL base. Both read while switched and write nothing.
- **Gate first.** The vendor's production, lookup, partner and test calls check no privilege (measured), so the port's gate is the whole gate.
  - **Order.** The endpoint's pairs, then READ on the namespace's globals database (WRITE for a write); a refusal names the failed pair.
  - **Extra pairs.** Declared only where a least-privileged run on a throwaway measured them, refused by name before any port call, and pinned by a test that removes them.
  - **The code lists and their editors** declare `%Ens_Code:READ`. A holder of only `%Ens_Rules`, `%Ens_RoutingRules`, `%Ens_BusinessRules`, `%Ens_DTL` or `%Ens_BPL` is refused, and so is `%EnsRole_RulesDeveloper`, which reaches the classic rules pages through `%Ens_Rules`: narrower audiences AD-8 accepts.
  - **The floor** admits `%Ens_Portal:USE`, so every new surface declares its own pair, sharing a member with its classic page's resource, and the `InteropFloor*` rosters pin it.
  - **Adjustment.** `Screen.Gate.RequiredPairs` is the one reader of a screen's requirement. A port's pairs and the vendor's are never adjustable.
- **Source saves (`Port/AtelierPort`).** The gate is `%Development:USE` and READ on the namespace's routines and globals databases and every database it maps code from except IRISSYS, plus WRITE on the target's routines database for a save. A save sends the version it read and never `ignoreConflict`: 409 is `EXPLORER.DOCUMENT.CONFLICT`, 423 `EXPLORER.DOCUMENT.LOCKED`. A compile also counts as failed when its console reads `Detected <n> errors during compilation` with n above zero, because a class whose generated class fails answers 200 with no status error (measured on a BPL).
- **SQL reads without grants.** `InteropPort` reads `Ens.MessageHeader` and `Ens_Util.Log` with `%ExecDirectNoPriv` after its own gate. Such a statement nests no query that carries `TOP`: on a cold cached query it is refused SQLCODE -99, and a copy a privileged reader warmed hides that. The item Messages read is therefore a top-level `UNION ALL` of two `TOP` branches.
- **Namespace.** `appliesWhen` (`IsEnsembleNamespace`, and `%IsDeepSeeEnabled` for Analytics) decides whether a surface applies, not who may open it. The port switches by explicit save and restore and calls no `OcuPilot.*` class while switched; rows are built after the restore. OcuPilot adds no elevation. A namespace under source control refuses item and lookup writes.
- **Write shape.**
  - **Action-style.** Each write declares its request type, sends no body or a port-built one, and fingerprints a port-composed fresh read; a create fingerprints the target's absence. Whatever the vendor would answer as a silent success, or write to the device about, is refused by name before any vendor call.
  - **Two callers, one operation.** A screen action and the agent's write share the fresh read, the prohibited set inside the per-target lock, the gate, the change event and the read-back. Only the agent's caller mints, writes the marker and answers to the agent switches. 20.18's dispatch refuses before any mint when the user does not hold the screen's effective pairs.
  - **Its own request.** Each write finishes in its own request, capped at 15 s, with no spawn site. A troubled production gets Recover, never Clean.
  - **After OK.** The write re-reads its target (`readBack`). Every port that defines `Invoke` also defines a pure `Snippet` mirroring each branch, with secrets as placeholders.
- **Audit.** Item and setting changes go through `Ens.Util.Auditing.AuditModifyProductionConfig`, never with a value. Writes the vendor does not audit, tests included, record OcuPilot's own `ConfigChange` from either caller.
- **Tests and parsing.** The shared helpers are `IsTestWrite`, the `INTEROP.TEST.*` codes, `AddTestLines`, `core/test-answer.ts` and `AtelierPort`'s output capture; extend each rather than copy it. A test's output, error and console lines ride the confirm response to the screen and the proposal card only, never to the model, a tool result, the ledger, an audit payload, a log line or screen context. HL7 text reaches its parser as a character stream (`ImportFromLibraryStream` over `%Stream.TmpCharacter`), as the classic dialog does, because `ImportFromString` turns a character past Latin-1 into `?`; both tests move to it in the burn-down (DW-2378).
- **Reads and ids.** Reads use source kind `interop`. A parent-scoped list takes its parent's route id as its one criterion and answers the parent key on each row. Every read has a row cap and reports truncation. An id keeps every part exactly, never uses the vendor's integer id, and is percent-encoded in one path segment; `production-item` is `[Production, Name]`.
- **Tools.**
  - **Declarations.** Each tool declares its `CLASSICPAGES`, and each new write type is reviewed against AD-10's prohibited set. The editor screens' classic pages are `EnsPortal.RuleEditor`, `EnsPortal.BPLEditor` and `EnsPortal.DTLEditor`.
  - **Hierarchy and names.** New interoperability tools extend the `InteropAction` hierarchy rather than copying a sibling, and are named `<area>.<screen>.<verb>`.
  - **Reaching the model.** A turn starts with the shell area's tools, the discovery tool `shell.tools.find`, and the screen context's `tools`; every other tool is reached through discovery. A screen's context lists its read, the writes behind its declared actions, and a bound agent-only write that declares `SCREENLISTED`.
  - **Gemini schemas.** Keep numeric enums top-level; one nested deeper is respelled but not decoded (DW-2358, accepted).
- **Untrusted content.** Message bodies, log text, names, settings, lookup values, test inputs and outputs, and rule, DTL or BPL content reach the model only through the one sanitizer. No gate or test relies on the sanitizer as its defense.
- **Measure on the instance**, and amend the spine at the spec gate rather than working around it.

## UX & Interaction Patterns

- **Loading.** A screen's first load shows its skeleton until the first page arrives (two-second target), and never on a re-fetch. A lazily fetched screen is held to the same target (inference).
- **Rail and tabs.** Interoperability and Analytics follow System Explorer and appear only where the namespace reports the feature. A screen joins the side bar only once it has shipped. An item's tabs: Status, Settings, Queue, Log, Messages, Jobs, Test.
- **The editor screens** are unlisted `viewer (source)` screens at `<list route>/document/<name>.cls`, opened from the Business rules, Business processes and Data transformations name cells, whose content is the vendor's editor in a frame. Empty is the screen's "no longer exists" sentence, and a process or transformation written as a class shows its sentence instead of an editor. A bar above the frame holds the note ("Leaving this screen, or choosing Refresh to open the document again, discards any change not saved in the editor.") and Refresh, which opens the document in a new frame; 20.16 adds a note that the agent reads only what is saved. Frame titles are "Rule editor", "DTL editor" and "BPL editor", and each screen has three suggested prompts.
- **Other embeds.** The configuration diagram renders in place, and its sibling editors open in new tabs. The HL7, X12 and ASTM schema browsers are read-only.
- **Gated controls are never hidden.** They stay focusable and `aria-disabled`, and name the failed pair.
- **Strings.** Each list has a title, an empty state and three suggested prompts, and a write-capable list's empty state adds the line inviting the agent. Every new string goes into EXPERIENCE.md's Fixed strings and `strings.ts`, whose values are unique. A refusal sentence lives once, on the server, pinned equal to its fixed string. `ui/tools/strings.test.mjs` bounds the Fixed strings literal count at 3,400; the count is 3,371 after 20.7 and 18.37, within 50 of the bound, and 20.16's plan raises it to 3,800.
- **Dialogs.** A dialog exists only where EXPERIENCE.md's dialog list names one, and a new dialog or pre-write warning amends that list at the spec gate. Dialogs never stack, and a destructive screen action uses the typed-name confirm.
- **Auto-refresh** is opt-in per screen, off by default, and declared in the descriptor and in EXPERIENCE.md's roster.
- **Cards.** Proposal cards follow the standard lifecycle, and production cards say to recover before cleaning. An agent's destructive proposal carries no typed name. A block over about eight lines starts collapsed with a summary line naming what changes, where and how big, plus the compile outcome where there is one; Confirm never requires expanding it.

## Cross-Story Dependencies

- **Done:** 20.1 to 20.7, 20.13 to 20.15, 20.17 to 20.24, and 20.27 to 20.29. 20.7's code head was committed with its CI run still pending at this compile.
- **Order.** 20.16 (ready for development) and 20.8 (next to plan), then 20.9 to 20.12 in the orchestrator's order. The orchestrator places 20.25, and 20.26 follows it.
- **20.16 consumes** 20.7's editor screens and the frame's `revision`, 20.19's source read, 20.21's save and mint, 20.17's card collapse and 20.18's refusal on a screen the user cannot open. 20.27's test can check a DTL edit, and 20.12's workflows may propose one (both inference).
- **20.8 consumes** 20.13's `interopEditorSource`, `app-interop-editor-frame` and `interop-editor-spec.mjs`, whose sign-in, sign-out and no-traffic assertions 20.7's `interop-editors.browser-spec.mjs` already re-runs on real screens. It reuses the editor page's shape (inference) and shows 20.2's productions and 20.3's items. A schema read, if one is needed, extends `InteropPort`.
- **20.10** runs source control inside these frames.
- **Other links.** 20.9's trace reuses `interop-message` (inference) and renders the session id a host test answers. 20.12 can run a guided disable followed by Update. 20.25 consumes 20.3's items and 20.4's per-host tabs, and 20.26 consumes 20.5's Business partners screen and read.
- **Later screens.** Every screen added from here (20.8 to 20.11, 20.25, 20.26) is a loader line in `ScreenOutlet`'s maps.
- **Epic 18 runs beside this epic.**
  - **Shared rosters** take add-only edits, summed at the forward merge: the entity types, the screen mirror, `strings.ts`, the navigation tests, EXPERIENCE.md's rows, and the `ReadTool` and `ToolRoundTrip` tool rosters (379 tools after 18.37; 20.16 adds six, three of them writes). Anything else is asked first. Every new Epic 20 screen also needs a row in `Test/StageTwoTools`'s `Elsewhere` block.
  - **The bundle.** Epic 18's new pages are loader lines too, and each forward merge re-measures `maximumWarning` on the merged tree.
  - **Interoperability usage** (18.37) is an OS management screen read in `%SYS` through `MonitorPort`, not `InteropPort`; the vendor's queries refuse a caller without `%Admin_Operate:USE`.
- **Into Epic 21.** Epic 21 reuses 20.12's diagnose-slow-query workflow. It owns interoperability credentials, purge, deployment, record maps, workflow and the analytics editors, so those stay out of this epic.
