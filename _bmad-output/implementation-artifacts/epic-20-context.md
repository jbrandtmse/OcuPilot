# Epic 20 Context: Stage 4 - Interoperability, with the Analytics rider

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Bring the classic portal's Interoperability work into OcuPilot for namespaces that support it: productions and their items, per-host tabs, queues and jobs, lookup tables and business partners, host and transformation testing, message search, resend and trace, schema viewers, and the vendor's rule, BPL and DTL editors embedded in place. Analytics rides along with cubes, the model browser, the MDX tool and the cube manager. The agent grows with the stage: guided multistep workflows and Investigate, screen-permission proposals, rule, DTL and BPL edits, and, after the owner reversed the person-only code save, reading class and routine source and saving confirmed edits to it (both shipped), then creating new classes and routines. Owner-added stories make each screen's required permission visible and adjustable and keep long agent-panel content readable.

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
- **Agent source reads (shipped).** `explorer.class.source` and `explorer.routine.source` return whole lines up to 60,000 characters, report the cut, and pass the tool-result sanitizer; the text goes to the configured model provider, with no on/off switch. Named limit: a credential written into source as a literal reaches the model unless it matches a sanitizer secret shape.
- **Agent saves (shipped).** `explorer.classes.save` and `explorer.routines.save` are advertised, agent-offered confirmed writes with enabled keys. The agent sends exact replacements; each `Old` must match the stored text exactly once, or the mint refuses and tells the model why (its copy came through the sanitizer and can differ). The mint stores the new text and one changed-lines hunk of at most 30,000 characters. Before Confirm the card says the compile runs on Confirm; Confirm is refused if the document changed after the mint, always compiles, reports the result, says plainly when a document saved but did not compile (the saved text is what the instance now holds), and writes the marker.
- **Refused to the agent, at the mint and again at Confirm, before anything is written:** names beginning `OcuPilot` in any case (new names too), every `%` name, system classes and the read-only system databases, any document in `%SYS`, and any document not stored in its namespace's own routines database. A mapped document's refusal names where it lives and says the person can save it from the editor. `explorer.sqldata.save` stays person-only and unadvertised; a person's own Save is unchanged.
- **Agent creates (20.20, next).** A confirmed proposal whose card shows the whole new document; its compile outcome follows the saves' rule. It fingerprints the name's absence and is refused if a document of that name appeared after the mint, so it never overwrites. It targets the user's current namespace and needs write access to that namespace's code database, settled against the screen's effective pairs; its key ships enabled. It carries two fixes that apply to saves and creates alike: Take as script must render the stored text, header-aware and bounded, instead of a `<content>` placeholder, so the script is the reviewed change; and Confirm must gate WRITE on the routines database of the proposal's stored namespace, not the request's.
- **Rule, DTL and BPL edits (20.16).** Warn the user to save the editor first, because OcuPilot cannot read the frame's unsaved state; then read the stored content and propose the edit with diff and marker, refused if the stored content changed after the mint; reload the editor after the write. Raise a typed-name confirmation only for a concrete reason.
- **Posture questions go up.** Any further security-posture question a plan finds returns to the orchestrator with options and a recommendation.

## Technical Decisions

- **Interoperability port.** The only class that starts, stops, restarts, updates or recovers a production, and the only declared-read source for interoperability configuration (source kind `interop`). It calls `Ens.Director`, `Ens.Config.Production:ProductionStatus` and `%Dictionary.ClassDefinition:SubclassOf` in the caller's process, never `%Api.InteropEditors.*`. Gate first: the endpoint's pairs, READ on the namespace's globals database (WRITE for a write), and `%Ens_ProductionRun:USE` for a production write; the vendor's reads check nothing, so this gate is the whole gate. The namespace must report interoperability; switch by explicit save and restore and call no OcuPilot class while switched. Writes are action-style over a port-composed STATE read, refuse a would-be silent no-op by name, finish in their own request (stop, restart and update capped at 15 s, else `INTEROP.PRODUCTION.BUSY`), and add no spawn site. Recover, never Clean. A `production` id is the class name, kept exactly. Code lists declare `%Ens_Code:READ`.
- **Category gating and the floor.** A rail area declares `appliesWhen` (`interoperability`, `analytics`), read per navigation for the route's namespace; applicability, not privilege. The API floor admits `%Ens_Portal:USE` beside `%Admin_*` and `%Development`. Every new surface declares its own pair matching its classic page's check, and the `InteropFloor*` rosters pin it. `%DeepSee_Portal` is public USE and can never be the floor.
- **Embedded editors.** A same-origin, unsandboxed `<iframe>` at `/ui/interop/<editor>/index.html` carrying only the editor's own query parameters, with values from a read OcuPilot answered. Normal mode only: never `?VSCODE=1`, never tokens pre-written into the editor's storage. OcuPilot posts nothing into the frame, reads nothing from it, and touches none of its storage or messages. Sign-out ends the editors' sign-in. Saved, compiled and invalid notices are unavailable in normal mode.
- **Screen permissions.** `Screen.Gate.RequiredPairs` is the one reader of a screen's requirement, uncached; every gate reaches a screen's pairs through it. Screen context carries the screen's `verdict` and the `unavailable` tools, and a privilege refusal names the screen. The client never derives availability from the generated mirror.
- **Code writes go through the Atelier port.** Its gate is `%Development:USE` plus READ on the namespace's routines and globals databases and every mapped code database except IRISSYS; a write also needs WRITE on the target namespace's routines-database resource. A save seeds If-None-Match with the version it read and never sends `ignoreConflict`. 409 is `EXPLORER.DOCUMENT.CONFLICT`, 423 `EXPLORER.DOCUMENT.LOCKED`, a refused save under a 2xx `EXPLORER.SAVE.REFUSED`, and an `OcuPilot` document `PROHIBITED.OCUPILOTCODE` from either caller.
- **Creates are a first-class write kind.** The tool declares that it creates; the fresh read keeps its place and must find the target absent (a 404 is the precondition); the fingerprint covers that absence; Confirm re-reads and refuses if the name was taken. The payload is composed from the arguments, so every supplied field is a diff row. The per-target lock keys on the canonical intended name; the prohibited set, marker, ledger row and change event are unchanged, with the prohibited set's per-type lists keyed by create versus change.
- **Take as script.** A user-originated request, refused from a turn, rendered on the instance from the stored proposal by the port's `Snippet`, which mirrors every branch `Invoke` takes; a registry test fails any write tool without a script form. Secrets render as placeholders. The draft sends nothing, is refused where the prohibited set refuses, and otherwise closes the proposal as `canceled` with reason `draft`.
- **Compile output stays off the model.** Compile lines reach the screen and the proposal card only, as text, never the model, a tool result, a ledger row, a log line or screen context.
- **Advertising.** An unadvertised tool is absent from the provider tool list, the dispatch lookup and screen context's `tools`, and a test fails if it appears in any of them. Unadvertised today: License key's activation, `explorer.sqldata.save` and `security.secrets.replacesymmetric`. The agent authors code only through the confirmed class and routine writes; `explorer.sqlquery.run` still refuses it a statement carrying code (`EXPLORER.SQL.AGENTCODE`).
- **Write-path patterns, reused unchanged.** A screen action and the agent's write are one operation through one tool, sharing the fresh read, the prohibited-set predicates inside the per-target lock (held through the write and its read-back), the caller's privileges through the port's gate, the change event and the read-back. Only the agent's caller mints, emits the marker and is gated by the agent's switches. A prohibited-set predicate is stated over the effect, never the payload's shape. A refusal sentence lives once on the server and once in EXPERIENCE.md's fixed strings, pinned equal by a test. A write tool declares pairs beyond its screen's set only where measured on the instance.
- **Text bound for the model.** Every tool result passes one sanitizer as the turn's history is built (strips control and invisible characters, redacts secret shapes, neutralizes its delimiter, wraps the data); idempotent, fails closed, and never the defense a gate or test relies on. Reads are bounded at 65,536 characters in total and 1,000 a field; source text is the one named exception to the field bound, and a read past what remains of its reply's budget answers `TOOL.RESULTTOOLARGE`.
- **Tool naming.** `<area>.<screen>.<verb>`, lower case, dots only, with `read` for a screen's one read tool.
- **Measure, don't assume.** Settle a pair set from the classic page's own check and a least-privileged principal on a throwaway; amend the spine at the spec gate rather than working around it.

## UX & Interaction Patterns

- **Rail.** Interoperability and Analytics follow System Explorer and are drawn only where the namespace reports the feature. The Interoperability side bar starts Productions, Business processes, Data transformations, Business rules; Screen permissions sits under Agent co-pilot.
- **Gated controls are never hidden:** focusable, `aria-disabled`, naming the failed pair.
- **Long blocks.** A transcript block over eight lines starts collapsed behind a native Show more / Show less button; a streaming reply never collapses. A proposal card holding a long block shows a summary line naming what changes and how big, plus the compile outcome once one has run; Confirm never requires expanding.
- **Code cards.** An agent's save shows its changed lines as one line diff with three lines of context and line numbers inside the long block; the summary line counts lines removed and added; the consequence says Confirming saves and then compiles as the user; a confirmed save that did not compile says so under the status line. A create card shows the whole new document. Every new string goes into EXPERIENCE.md's fixed strings and `strings.ts`.
- **Proposal cards** follow the standard lifecycle. Production cards carry recover-before-clean guidance. An agent's destructive card uses the destructive Confirm with no typed name.
- **Embeds and viewers.** The production configuration diagram renders in place, its sibling editors opening in new tabs. The HL7, X12 and ASTM schema browsers are read-only, their document-selection parameter established against the instance. A session trace renders visually, with a generated sequence diagram as the alternative.

## Cross-Story Dependencies

- **Done:** 20.1, 20.2, 20.14, 20.15, 20.17, 20.18, 20.19, 20.21. **Order:** 20.20 next, then 20.3 to 20.6.
- **Agent creates.** 20.20 builds on 20.21's save path (card, compile report, refusals), 20.18's refusal to propose on a screen the user cannot open, 20.17's collapse and summary line, 20.15's effective pairs, and Epic 19's Atelier port and person Saves. Its script and Confirm-gate fixes also change 20.21's shipped saves.
- **Embeds.** 20.13 gates 20.7, 20.8 and 20.10. 20.16 follows 20.7 and builds on 20.21's agent source edits.
- **Interoperability screens.** 20.3 to 20.6 and 20.9 build on the interoperability port and 20.2's production screens.
- **Into Epic 21.** Epic 21 reuses 20.12's diagnose-slow-query workflow.
