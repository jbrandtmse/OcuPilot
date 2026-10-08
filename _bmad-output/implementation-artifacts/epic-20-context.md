# Epic 20 Context: Stage 4 - Interoperability, with the Analytics rider

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Bring the classic portal's Interoperability work into OcuPilot for namespaces that support it: productions and their items, per-host tabs, queues and jobs, lookup tables and business partners, host and transformation testing, message search, resend and trace, schema viewers, and the vendor's rule, BPL and DTL editors embedded in place. Analytics rides along with cubes, the model browser, the MDX tool and the cube manager. The agent grows with the stage: guided multistep workflows and Investigate, screen-permission proposals, rule, DTL and BPL edits, and, on the owner's reversal of the person-only code save, reading class and routine source, saving confirmed edits to it and creating new documents. Owner-added stories make each screen's required permission visible and adjustable and keep long agent-panel content readable.

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

## Requirements & Constraints

- **One build contract.** Each screen has one descriptor and reaches the instance through one declared port; acceptance is that contract plus each row's own backing route. Every agent write is a server-minted proposal with an instance-computed diff, an explicit Confirm and an agent marker. A new destructive governance key ships disabled. The owner set these keys enabled: the screen-permission tools, rule, DTL and BPL edits, and class and routine saves and creates.
- **Vendor bundles are never copied or redistributed;** they load in place from the instance.
- **Read-only first, as a stated partial:** queue and job actions (abort, abort all, suspend, stop), business-partner save and remove, and the message-contents renderer each need custom endpoints.
- **Writes with extra rules.** Message resend and edit-and-resend take a dry run, then a confirm, with a bounded cap per action. A transformation test is a confirmed write because it executes code. A cube build, synchronize or repair is the one analytics write; Architect, Analyzer and the User Portal are linked, not rebuilt; anything beyond links needs a DeepSee-enabled namespace.
- **Guided workflows** are a sequence of individually confirmed proposals, never a batch approval; the prohibited set, both agent switches and governance are evaluated at every write. Investigate, from an alert or a log entry, returns a recap and ranked hypotheses citing the rows it used. Harvested prompts take OcuPilot's names: no `iris_` prefix, no sibling package names.
- **Agent source read (20.19).** A read tool returns a class's or routine's source capped at about 60,000 characters, cut at whole lines, through the tool-result sanitizer, reporting truncation. The text goes to the configured model provider (owner: "Yes it should send the code"); there is no on/off switch for it. The two new read tools follow the `<area>.<screen>.<verb>` naming convention, which allows one `read` per screen, or the spec says why not. Every existing save, delete and import key is unchanged.
- **Agent saves (20.21).** `explorer.classes.save` and `explorer.routines.save` become advertised, agent-offered confirmed writes with enabled keys. The card shows the whole diff and says the compile runs on Confirm. Confirm is refused if the document changed after the mint. After Confirm the compile results are reported, a saved-but-not-compiled document is said plainly, and the marker is written.
- **Refused to the agent, at the mint and again at Confirm, before anything is written:** documents under OcuPilot's own packages (new names too), every `%` name, system classes and the read-only system databases, any document in `%SYS`, and any document not stored in its namespace's own routines database. A mapped document's refusal names where it lives and says the person can save it from the editor. `explorer.sqldata.save` stays person-only and unadvertised. A person's own Save is unchanged.
- **Agent creates (20.20).** The card shows the whole new document and its compile outcome. The fingerprint is the name's absence, so a create never overwrites. A create targets the user's current namespace and needs write access to its code database, settled against the screen's effective pairs; its key ships enabled.
- **Rule, DTL and BPL edits (20.16).** Warn the user to save the editor first, because OcuPilot cannot read the frame's unsaved state; then read the stored content and propose the edit with diff and marker, refused if the stored content changed after the mint; reload the editor after the write. Raise a typed-name confirmation only for a concrete reason.
- **Posture questions go up.** Any further security-posture question a plan finds returns to the orchestrator with options and a recommendation.

## Technical Decisions

- **Interoperability port.** The only class that starts, stops, restarts, updates or recovers a production, and the only declared-read source for interoperability configuration (source kind `interop`). It calls `Ens.Director`, `Ens.Config.Production:ProductionStatus` and `%Dictionary.ClassDefinition:SubclassOf` in the caller's process, never `%Api.InteropEditors.*`. Gate first: the endpoint's pairs, READ on the namespace's globals database (WRITE for a write), and `%Ens_ProductionRun:USE` for a production write; the vendor's reads check nothing, so this gate is the whole gate. The namespace must report interoperability; switch by explicit save and restore and call no OcuPilot class while switched. Writes are action-style over a port-composed STATE read, refuse a would-be silent no-op by name, finish in their own request (stop, restart and update capped at 15 s, else `INTEROP.PRODUCTION.BUSY`), and add no spawn site. Recover, never Clean. A `production` id is the class name, kept exactly. Code lists declare `%Ens_Code:READ`.
- **Category gating and the floor.** A rail area declares `appliesWhen` (`interoperability` = `%Library.EnsembleMgr.IsEnsembleNamespace`, `analytics` = `%DeepSee.Utils.%IsDeepSeeEnabled`), read per navigation for the route's namespace; applicability, not privilege. The API floor admits `%Ens_Portal:USE` beside `%Admin_*` and `%Development`. Every new surface declares its own pair matching its classic page's check, and the `InteropFloor*` rosters pin it. `%DeepSee_Portal` is public USE and can never be the floor.
- **Embedded editors.** A same-origin `<iframe>` at `/ui/interop/<editor>/index.html` carrying only the editor's own query parameters, with values from a read OcuPilot answered. Normal mode only: never `?VSCODE=1`, never tokens pre-written into the editor's storage. OcuPilot posts nothing into the frame, reads nothing from it, and touches none of its storage or messages. The frame is not sandboxed (a sandboxed frame never signs in). Sign-out ends the editors' sign-in. Saved, compiled and invalid notices are unavailable in normal mode.
- **Screen permissions.** `Screen.Gate.RequiredPairs` is the one reader of a screen's requirement, uncached, always unioning the classic page's custom resource; every gate reaches a screen's pairs through it. Screen context carries the screen's `verdict` and the `unavailable` tools, and a privilege refusal names the screen. The client never derives availability from the generated mirror.
- **Code reads and writes go through the Atelier port.** Its gate is `%Development:USE` plus READ on the namespace's routines and globals databases and every mapped code database except IRISSYS; a write also needs WRITE on the target namespace's routines-database resource. A save seeds If-None-Match with the version it read and never sends `ignoreConflict`. 409 is `EXPLORER.DOCUMENT.CONFLICT`, 423 `EXPLORER.DOCUMENT.LOCKED`, and a refused save under a 2xx `EXPLORER.SAVE.REFUSED`. Compile console lines reach the screen and the proposal card only, never the model, the ledger or a log. Documents named `OcuPilot*` are refused `PROHIBITED.OCUPILOTCODE` from either caller.
- **Creates** are a first-class write kind: the fresh read must find the target absent, and Confirm re-reads and refuses if the name was taken since the mint.
- **Write-path patterns, reused unchanged.** A screen action and the agent's write are one operation through one tool; the screen caller mints no proposal, emits no marker and is not gated by the agent's switches. Every write reads its target back. A write tool declares pairs beyond its screen's set only where measured on the instance.
- **Text bound for the model.** Every tool result passes one sanitizer when the turn's history is built. Reads are bounded at 65,536 characters in total and 1,000 per field. The spine still says a document's whole text is a screen-only payload that never reaches a tool, so 20.19's spec gate amends that rule; the ~60,000-character read also exceeds the per-field bound and needs a named exception (inference).
- **Spine text that predates the 2026-10-08 split.** The architecture's same-operation decision still says Story 20.19 makes both Saves agent-offered and that they stay unadvertised until 20.19 ships; the saves are now 20.21's, and its spec gate rewrites that line. Story 19.3's pointer note in the epics file still names 20.17.
- **Measure, don't assume.** Settle a pair set from the classic page's own check and a least-privileged principal on a throwaway; amend the spine at the spec gate rather than working around it.

## UX & Interaction Patterns

- **Rail.** Interoperability and Analytics follow System Explorer and are drawn only where the namespace reports the feature. The Interoperability side bar starts Productions, Business processes, Data transformations, Business rules; Screen permissions sits under Agent co-pilot.
- **Gated controls are never hidden:** focusable, `aria-disabled`, naming the failed pair.
- **Long blocks.** A transcript block over eight lines (each further 80 characters of a line counts as another) starts collapsed behind a native Show more / Show less button with `aria-expanded` and `aria-controls`; a streaming reply never collapses. A proposal card holding a long block shows a summary line naming what changes and how big, plus the compile outcome once one has run; Confirm never requires expanding.
- **Proposal cards** follow the standard lifecycle. Production cards carry recover-before-clean guidance. An agent's destructive card uses the destructive Confirm with no typed name.
- **Embeds and viewers.** The production configuration diagram renders in place, its sibling editors opening in new tabs. The HL7, X12 and ASTM schema browsers are read-only, their document-selection parameter established against the instance. A session trace renders visually, with a generated sequence diagram as the alternative.

## Cross-Story Dependencies

- **Done:** 20.1, 20.2, 20.14, 20.15, 20.17, 20.18. **Order:** 20.19, then 20.21, then 20.20, then 20.3 to 20.6.
- **Agent code work.** 20.21 starts with 20.19's source read in place. 20.19, 20.21 and 20.20 rely on 20.18's refusal to propose on a screen the user cannot open, 20.17's collapse and summary line, 20.15's effective pairs, and Epic 19's Atelier port and person Saves.
- **Embeds.** 20.13 gates 20.7, 20.8 and 20.10. 20.16 follows 20.7 and builds on the agent's source read and saves (20.19, 20.21; its epics note still names the pre-split 20.17).
- **Interoperability screens.** 20.3 to 20.6 and 20.9 build on the interoperability port and 20.2's production screens.
- **Into Epic 21.** Epic 21 reuses 20.12's diagnose-slow-query workflow.
