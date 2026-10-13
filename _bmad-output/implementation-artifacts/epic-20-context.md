# Epic 20 Context: Stage 4 - Interoperability, with the Analytics rider

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Bring the classic portal's Interoperability work into OcuPilot for namespaces that support it, with Analytics riding along, so the largest area the classic portal still owns is usable here. Shipped so far: category gating, production control, items and their settings, per-host tabs, the monitor, queue and job reads and actions, lookup tables, read-only business partners, the host Test tab, the interoperability floor, per-screen permissions, the panel collapse, the agent's source reads, saves and creates, the shared tool-listing cache, the sign-in hand-off every embedded vendor editor needs, a clean compile and install in a namespace without interoperability, and screens that load on demand. Next is 20.27, the transformation test: a Test action on Data transformations runs a transformation once on pasted input and shows its output, as a confirmed write, so a change can be checked here before it is deployed. 20.7 follows. Still to come: the rule, BPL and DTL editors in place and the agent's edits behind them, the schema viewers and configuration diagram, source-control hooks, message search, resend and trace, item runtime actions, partner writes, the Analytics rider, and guided workflows with Investigate.

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
- **Transformation test (20.27).**
  - **What runs.** For a transformation Data transformations lists, pasted input is parsed into the source class, the transformation runs once in the caller's process, and the target renders as text: an EDI document's raw text or indented XML, capped at 1,000,000 characters and marked cut. Anything the test stored is deleted.
  - **A confirmed write, not destructive.** It executes code on the instance, from both callers: a person's screen action and the agent's proposal. Its key `interop.transforms.test` ships `true`, and the card shows the input and the consequence (the code runs as the person) before Confirm.
  - **Refused before any vendor call.** A source or target that is neither EDI nor `%XML.Adaptor` (Record Map, batch and other non-XML sources included), a class the list does not list, and empty or over-long content.
  - **Outcomes.** Input that does not parse, a `Transform` error or fault, and output that cannot be written each answer the test's status with its error lines. What the transformation writes to the device comes back as console lines, and the HTTP answer stays a JSON envelope.
  - **Pasted text only.** No file or server path, no file picker, and no `aux`, `process` or `context` values.
  - **Audit.** OcuPilot's own `ConfigChange` row from either caller, since the vendor records none. It never carries the input, the output or any line.
  - **Still to measure (carried from 20.6's Task 0).** A transformation's device write is captured with the route answer still JSON, and an X12 target renders through the call the classic dialog uses.
  - **Named limits.** An HL7 parse leaves the vendor's per-process `^EnsHL7.Segment` node, as the classic dialog's parse does, and a transformation's own code has no cap beyond the gateway's timeout.
- **No compile-time dependency on interoperability (standing since 20.28).**
  - **Never resolved by the compiler.** No shipped class includes `Ensemble` or another interoperability include. None names an `Ens.*`, `EnsLib.*` or `EnsPortal.*` class where the compiler resolves it: a superclass, a property, an argument or return type, `DependsOn`, `CompileAfter`, or a class query's SQL.
  - **Reached at run time.** Such a value is typed `%RegisteredObject` or `%String` and reached at run time while switched. `##class(Ens.…)` in a method body, `#dim`, embedded SQL and strings all compile.
  - **The guards.** `OcuPilot.Test.CompileWithoutInterop` and the `package` job's IPM install into a namespace created without interoperability hold the rule. Test classes are out of scope.
- **Vendor bundles are never copied or redistributed.** They load in place from the instance.
- **Embeds.** 20.7 re-scopes its "saved, compiled, invalid" criterion at its spec gate, because the editors send none of those in normal mode. Each embed story's Task 0 establishes its vendor contract on the instance: the schema browsers' document parameter for 20.8, and the hook exchange for 20.10.
- **Rule, DTL and BPL edits (20.16)** take five steps, with the key enabled: warn the user to save the editor (OcuPilot cannot read the frame's unsaved state), read the stored content, propose the edit with its diff and marker, refuse if the stored content changed after the mint, then reload the editor.
- **Messages (20.9).** Search and the viewer read through the port, with saved searches where the API offers them. Resend and edit-and-resend take a dry run, then a Confirm, with a bounded cap per action. A session trace renders visually, with a generated sequence diagram as the alternative. The message-contents renderer is the custom half.
- **Item runtime actions (20.25).** A temporary stop, start or restart of one item is followed by the production update the vendor requires. Each is refused by name where the vendor would answer success while doing nothing (a stopped production, a disabled item). Copy and change of class run as the classic page does, and the vendor audits them.
- **Partner writes (20.26)** on `Ens.Config.BusinessPartner`.
  - Each is confirmed over a fresh read and records OcuPilot's own audit row.
  - The vendor renames by a delete and a create with no transaction, so a rename is either refused or done in one transaction.
  - Removing a partner that an item's `BusinessPartner` setting names first reads those items, then refuses or warns.
  - The pair posture goes to the orchestrator; 20.5's plan recommends `%Ens_ProductionConfig:WRITE`.
- **Analytics (20.11).** Cube build, synchronize and repair are the only analytics writes. MDX results render with drill-through and cancel. Architect, Analyzer and the User Portal are linked, not rebuilt; anything beyond those links needs a DeepSee-enabled namespace.
- **Workflows and Investigate (20.12).** A workflow is a sequence of individually confirmed proposals, never a batch approval. Each write still evaluates the prohibited set, both agent switches and governance. Investigate starts from an alert or a log entry and returns a recap and ranked hypotheses that cite the rows used. Harvested prompts take OcuPilot's names.
- **Secrets and paths.** A Secrets-pattern setting answers an empty value and default, with `Secret` true, and setting one is refused before any vendor call, from both callers. A secret under a non-matching name is a named limit. No endpoint accepts a path outside a case AD-21 names, and pasted content is never a path.
- **Posture questions** go to the orchestrator, with options and a recommendation.

## Technical Decisions

- **Client loading (AD-5, as built in 20.29).**
  - **Pages load on demand.** Every screen route and `:id` route has one `''` child whose `loadComponent` is the loader that `ScreenOutlet`'s maps (`ARCHETYPE_PAGES`, `DESCRIPTOR_PAGES`, `DESCRIPTOR_EDIT_PAGES` in `shell/screen-outlet.ts`) name for it. `ScreenOutlet` still decides whether a page mounts (not found, denied, held by the first-login gate, map unanswered) and renders a `<router-outlet />`.
  - **Adding a screen.** A new screen of an existing page is descriptor-only. A new page is one loader line in those maps, never a static import. The route table stays generated from the descriptor mirror, `screens.generated.ts` is never hand-edited, and a built archetype with no page still fails `ng build` (`BuiltArchetypeKey`).
  - **No eager page.** No module in the initial set imports a page module statically, and no router preloading strategy is added. `build-output.test.mjs` treats every `*.page.ts` as a routed page and reddens naming the selector of one made eager.
  - **Budgets.** The initial total is 1,896,272 bytes (it was 3,405,631). `maximumWarning` is 1992kB (5% above, DW-1166; the builder's kB is 1,000 bytes) and `maximumError` 4000kB, and `angular-json.test.mjs` pins the literal. Each lazy chunk stays under `LAZYCHUNKMAX`, 88 kB (largest 83,326 bytes, the data browser). Each forward merge re-measures `maximumWarning` on the merged tree.
  - **Stale tabs.** A signed-in tab whose navigation fails re-reads `/instance` (`recheckBuild()`), so the stale-bundle notice explains a chunk a reinstalled instance no longer serves (it answers `index.html`).
  - **Named limit (DW-2367).** The area stores and actions `app.ts` constructs (about 427 kB) stay in the initial bundle.
  - **AD-19.** Zoneless, `OnPush`, screen state in stores. `core/` imports no `@angular/core`.
  - **Browser specs** reach screens by navigation, never by importing page modules (`panel-spec.mjs` shares `openFromSideBar`). They run against the deployed bundle, so rebuild and redeploy before reading any browser result.
- **Embedded editors (AD-63)** are a named exception to "tokens never within a frame's reach" and "an embedded vendor page is inert".
  - **Source.** Only `interopEditorSource` (`ui/src/app/core/vendor-frame.ts`) builds `/ui/interop/<editor>/index.html` on the instance's origin. Its vocabulary is closed: `rule-editor` takes `rule`, `dtl-editor` takes `DTL`, `bpl-editor` takes `BP`, and the namespace goes in `$NAMESPACE`. Values come from OcuPilot's own reads and are percent-encoded; anything else answers `null` and no frame is drawn. A new `/ui/interop` app (20.8) joins once its parameter is read on the instance.
  - **Frame.** `app-interop-editor-frame` draws one unsandboxed `<iframe>`, because a sandboxed frame never signs in. `src` is set through `Renderer2`, with no `sandbox`, `allow`, `srcdoc` or `credentialless` attribute, and the per-editor title is its accessible name.
  - **Normal mode only.** Never `?VSCODE=1`, and never pre-written tokens.
  - **Nothing crosses.** OcuPilot posts nothing into the frame and reads nothing from it (no `contentWindow`, `contentDocument`, `frames`, messages or vendor storage keys), so 20.16's reload cannot be a message (inference). The token store, the CSP, `index.html` and the headers are unchanged, and CORS stays off.
  - **Sign-in and sign-out.** The editor signs itself in from the browser-level login. OcuPilot's sign-out ends that sign-in and revokes each editor's own pair, and the shell withholds every frame while signed out.
  - **Named consequences.** The frame can read the tab's `ocupilot.token-pair` and script the shell, as any same-origin code can. The editor's own Logout ends OcuPilot's pair, which shows its session-ended card at the next request and never fills or reads the editor's sign-in form. A tab the editor opens without `noopener` gets a copy of the tab's storage, and sign-out revokes it.
- **Interoperability port (`Port/InteropPort`).** The only class that starts, stops, restarts, updates or recovers a production, and the only source of declared interoperability reads.
  - It calls the documented vendor classes the classic pages call, in process, as the signed-in user, and never calls `%Api.InteropEditors.*`.
  - A new read or write extends this port and names its case in AD-62 at its spec gate, and in AD-36 too for a read.
- **Gate first.** The vendor's production, lookup, partner and test calls check no privilege (measured; `Transform` included), so the port's gate is the whole gate.
  - **Order.** The endpoint's pairs, then READ on the namespace's globals database (WRITE for a write); a refusal names the failed pair.
  - **Extra pairs.** Declared only where a least-privileged run on a throwaway measured them, refused by name before any port call, and pinned by a test that removes them.
  - **The floor.** It admits `%Ens_Portal:USE`, so every new surface declares its own pair, and the `InteropFloor*` rosters pin it.
  - **Adjustment.** `Screen.Gate.RequiredPairs` is the one reader of a screen's requirement. A port's pairs and the vendor's are never adjustable.
- **Namespace.** `appliesWhen` (`IsEnsembleNamespace`, and `%IsDeepSeeEnabled` for Analytics) decides whether a surface applies, not who may open it. The port switches namespace by explicit save and restore and calls no `OcuPilot.*` class while switched: vendor values go into locals, and rows are built after the restore. OcuPilot adds no elevation. A namespace under source control refuses item and lookup writes.
- **Write shape.**
  - **Action-style.** Each write declares its request type, sends no body or a port-built one, and fingerprints a port-composed fresh read. A create fingerprints the target's absence. Whatever the vendor would answer as a silent success, or write to the device about, is refused by name before any vendor call.
  - **Two callers, one operation.** A screen action and the agent's write share the fresh read, the prohibited set inside the per-target lock, the gate, the change event and the read-back. Only the agent's caller mints, writes the marker and answers to the agent switches.
  - **Its own request.** Each write finishes in its own request, capped at 15 s, with no spawn site. A troubled production gets Recover, never Clean.
  - **After OK.** The write re-reads its target (`readBack`). Every port that defines `Invoke` also defines a pure `Snippet` mirroring each branch, with secrets as placeholders.
- **Audit.** Item and setting changes go through `Ens.Util.Auditing.AuditModifyProductionConfig`, never with a value. Writes the vendor does not audit, tests included, record OcuPilot's own `ConfigChange` from either caller.
- **Test writes (20.27 consumes 20.6's helper).**
  - **Shared from 20.6.** `IsTestWrite` (a test needs WRITE on the globals database and never the routines database), the `INTEROP.TEST.*` code family in `InteropError`, `AuditRuntime` verb `test`, `core/test-answer.ts` (20.27 extends it for its own statuses), and the output capture `AtelierPort` opens (`$$BeginCapture^%SYS.Capture`), called the same way rather than copied; `check-objectscript.py` already admits it in `InteropPort`.
  - **Port types.** `Transforms` gains `TRANSFORM`, a composed read of the source and target classes and document types and whether the source is a document or XML, and `TRANSFORMTEST`, which joins `IsTestWrite` and `COMPOSEDTYPES`.
  - **Parsing and running.** A virtual document's `ImportFromString` or `Ens.Util.XML.Reader.ObjectFromString`, never the `[Hidden]` serialized reader. `Transform` runs in process with `process` and `context` newed empty, and the parse, the run and the render all run inside the capture.
  - **Pairs and page.** `%Ens_Portal:USE`, `%Ens_Code:READ` and `%Ens_DTLTest:USE`, plus WRITE on the globals database: a named narrower audience than the classic dialog's, which needs only `%Ens_DTLTest:USE` and runs any class with a compiled `Transform`. `%EnsRole_Administrator` and `%EnsRole_WebDeveloper` hold the test resources. Its `CLASSICPAGES` entry is `EnsPortal.Dialog.TestTransform`.
  - **The tool** `interop.transforms.test` extends `InteropAction` on the `InteropTransformList` descriptor; its `WriteOutput` answers the result, never `outcome`.
  - **AD-39's seventh exception.** A test's output, error and console lines ride the confirm response to the screen and the proposal card only, as text. They never reach the model, a tool result, the ledger, an audit payload, a log line or screen context; the agent sees its proposal confirmed, not the output.
- **Reads and ids.** Reads use source kind `interop`. A parent-scoped list takes its parent's route id as its one criterion and answers the parent key on each row. Every read has a row cap and reports truncation. An id keeps every part exactly, never uses the vendor's integer id, and is percent-encoded in one path segment; `production-item` is `[Production, Name]`.
- **Tools.**
  - **Declarations.** Each tool declares its `CLASSICPAGES`, and each new write type is reviewed against AD-10's prohibited set.
  - **Hierarchy and names.** New interoperability tools extend the `InteropAction` hierarchy (`InteropProductionAction`, `InteropItemAction`) rather than copying a sibling, and are named `<area>.<screen>.<verb>`.
  - **Reaching the model.** A turn starts with the shell area's tools, the discovery tool `shell.tools.find`, and the screen context's `tools`; every other tool is reached through discovery.
  - **Gemini schemas.** A numeric enum is respelled for Gemini and decoded back only at a top-level argument or its `items`; one nested deeper would be respelled but not decoded (DW-2358, accepted), so keep numeric enums top-level.
- **Untrusted content.** Message bodies, log text, names, settings, lookup values, test inputs and outputs, and rule, DTL or BPL content reach the model only through the one sanitizer. No gate or test relies on the sanitizer as its defense.
- **Measure on the instance**, and amend the spine at the spec gate rather than working around it.

## UX & Interaction Patterns

- **Loading.** A screen's first load shows its skeleton until the first page arrives (two-second target, NFR-1), and never on a re-fetch. A lazily fetched screen is held to the same target (inference).
- **Rail and tabs.** Interoperability and Analytics follow System Explorer and appear only where the namespace reports the feature. A screen joins the side bar only once it has shipped. An item's tabs: Status, Settings, Queue, Log, Messages, Jobs, Test.
- **Transformation test (20.27).** Data transformations gains a Test row action and becomes write-capable, so its empty state gains the line inviting the agent. The dialog shows the transformation's name, one multi-line Input with a sentence naming the formats, and Run. The result shows the source and target class, a status sentence, and the lines and console in a code block, rendered as text, never markup. The dialog is not yet in EXPERIENCE.md's dialog list, so 20.27's spec gate adds it with its Fixed strings.
- **Embeds and viewers.** The editors and the configuration diagram render in place inside the shell, and the diagram's sibling editors open in new tabs. The HL7, X12 and ASTM schema browsers are read-only.
- **Gated controls are never hidden.** They stay focusable and `aria-disabled`, and name the failed pair.
- **Strings.** Each list has a title, an empty state and three suggested prompts, and a write-capable list's empty state adds the line inviting the agent. Every new string, frame titles included, goes into EXPERIENCE.md's Fixed strings and `strings.ts`, whose values are unique. A refusal sentence lives once, on the server, pinned equal to its fixed string.
- **Dialogs.** A dialog exists only where EXPERIENCE.md's dialog list names one, and a new dialog or pre-write warning amends that list at the spec gate. Dialogs never stack, and a destructive screen action uses the typed-name confirm.
- **Auto-refresh** is opt-in per screen, off by default, and declared in the descriptor and in EXPERIENCE.md's roster.
- **Cards.** Proposal cards follow the standard lifecycle, and production cards say to recover before cleaning. An agent's destructive proposal carries no typed name. A block over about eight lines starts collapsed with a summary line, and Confirm never requires expanding it.

## Cross-Story Dependencies

- **Done:** 20.1 to 20.6, 20.13 to 20.15, 20.17 to 20.24, 20.28 and 20.29 (20.29's CI run was still pending at this compile). 20.13 and 20.28 are merged into the feature branch, and release 1.0.12 has shipped.
- **20.27 is next, then 20.7**, the orchestrator's order after splitting 20.6 (20.6, 20.13, 20.27, 20.7).
  - **It consumes** 20.6's shared test helper, AD-39's seventh exception, and 20.2's Data transformations list (`InteropTransformList`, Epic 20's own, edited in place). 20.6's spec keeps 20.27's measured charter as its Part B block.
  - **Its page.** It adds a page, so it adds one loader line, and the page's weight lands in a lazy chunk under the 88 kB ceiling.
  - **Later consumers.** 20.16's DTL edits are something a test can check, and 20.12's guided workflows may propose one (both inference).
- **Later screens.** Every screen added after 20.29 (20.7 to 20.11, 20.25 to 20.27) is a loader line in `ScreenOutlet`'s maps.
- **20.13 unblocks 20.7, 20.8 and 20.10.** 20.7 is the frame component's first real-browser host, and it owns three follow-ups:
  - It re-runs the frame browser spec against its real screens.
  - On a document switch, it chooses between re-setting `src` and drawing a new frame. Re-setting adds a history entry, so Back moves the frame; a new frame skips the editor's unsaved-changes alert.
  - It handles a frame that moves away from its screen unseen: the logo and Back to standard UI navigate the frame, DTL and BPL push history entries, and the rule editor's Settings switches its namespace.
- **The editing stories.** 20.16 follows 20.7 and builds on 20.21's agent source saves.
- **Other links.** 20.9's trace reuses `interop-message` (inference) and renders the session id a host test answers. 20.8's diagram shows 20.3's items. 20.12 can run a guided disable followed by Update.
- **20.25 and 20.26.** 20.25 consumes 20.3's items and 20.4's per-host tabs, and 20.26 consumes 20.5's Business partners screen and read. The orchestrator places both in the order.
- **Epic 18 runs beside this epic.**
  - **Shared rosters** take add-only edits, summed at the forward merge: the entity types, the screen mirror, `strings.ts`, the navigation tests and EXPERIENCE.md's rows. Anything else is asked first. Every new Epic 20 screen also needs a row in `Test/StageTwoTools`'s `Elsewhere` block.
  - **The bundle.** Epic 18's new pages are loader lines too, and each forward merge re-measures `maximumWarning` on the merged tree.
  - **Story 18.13 is in this branch.** OcuPilot has one install namespace per instance, the one holding the profile's globals mapping. Install refuses a system or missing namespace, an IRIS below the roster's floor, a package that resolves from another database, and any second namespace. Uninstall refuses a second namespace, `scripts/container-start.sh` refuses before it compiles, and the IPM manifest's guard invoke `Installer.GuardTarget` after `Compile` refuses before IPM touches a web application. The retention sweep keeps each profile's newest 100 install stamps.
- **Into Epic 21.** Epic 21 reuses 20.12's diagnose-slow-query workflow. It owns interoperability credentials, purge, deployment, record maps, workflow and the analytics editors, so those stay out of this epic.
