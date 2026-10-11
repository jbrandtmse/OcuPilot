# Epic 20 Context: Stage 4 - Interoperability, with the Analytics rider

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Bring the classic portal's Interoperability work into OcuPilot for namespaces that support it: productions, their items and settings, per-host tabs, the monitor, queues and jobs, lookup tables and business partners, host and transformation tests, message search, resend and trace, the schema viewers and configuration diagram, and the vendor's rule, BPL and DTL editors embedded in place. Analytics rides along with cubes, the model browser, the MDX tool and the cube manager. The agent grows with the stage through guided workflows, Investigate, and rule, DTL and BPL edits. Already shipped: category gating, productions, items and settings, the interoperability floor, screen permissions, the panel collapse, the agent's class and routine reads, saves and creates, the shared tool-listing cache, the per-host tabs, monitor, queues and jobs, and the queue and job actions. Next come lookup tables and business partners, then the remaining screens, item runtime actions and embeds. Together they make the largest area the classic portal still owns usable here.

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

## Requirements & Constraints

- **One build contract.** Each screen has one descriptor and reaches the instance through one port; its read tool and its write tools' field lists derive from it. Every write is a server-minted proposal with an instance-computed diff, an explicit Confirm and an agent marker.
- **Governance.** A new write key joins the checked-in baseline in the same change; a destructive key ships `false`. Each new action's plan states its destructiveness, its key's default and its audit record.
- **Vendor bundles are never copied or redistributed.** They load in place from the instance.
- **Reads first, as a stated partial.** Two remain: business-partner save and remove (20.5) and the message-contents renderer (20.9). The read ships first and the spec names the partial.
- **Lookup tables and business partners (20.5).** Lookup tables are listed, created, edited, deleted, imported and exported, each round-tripping through the port, writes as confirmed proposals. Business partners are a read through the port.
  - The classic pages are `EnsPortal.LookupSettings` (`Ens.Util.LookupTable`) and `EnsPortal.BusinessPartners` (`Ens.Config.BusinessPartner`). Research read the partners page's check as `%Ens_ProductionConfig:READ` and lists a `%Ens_LookupTables` resource; settle both from the pages' own checks.
  - The research catalog maps lookup tables to the interop-editors v7 routes. The port never calls `%Api.InteropEditors.*`, so 20.5 reaches the vendor classes in process and names its case in AD-62 at its spec gate (inference).
- **Item runtime actions (20.25).** Temporary stop, start and restart of one item, each followed by the production update the vendor requires. Refuse by name where the vendor would answer success while doing nothing (a stopped production, a disabled item). Copy and change of class run as the classic page does, audited by the vendor.
- **Secret-named values.** A name matching the one Secrets pattern (server and client lists pinned equal) is answered with an empty value and default and `Secret` true, and code refuses to set it before any vendor call, from both callers. Named limit: a secret stored under a non-matching name is not caught.
- **No endpoint accepts a path, except a case the spine names.** Existing import and export precedents: a local file's text is a screen action value, never a path and never in a tool's schema; a server file goes through `PathPort`, as an export with a constant overwrite or an import `source`. Item location settings are AD-21's ninth case. A new file case is written into AD-21 at its spec gate.
- **Other writes with extra rules.**
  - A host test builds its request from the target's own schema. A transformation test is a confirmed write, because it executes code.
  - Resend and edit-and-resend take a dry run, then a Confirm, with a bounded cap on how many messages one action resends.
  - A cube build, synchronize or repair is the only analytics write. Architect, Analyzer and the User Portal are linked, not rebuilt. Anything beyond the links needs a DeepSee-enabled namespace.
- **Vendor contracts are established against the instance as a story's first task:** the schema browsers' document-selection parameter, the editors' messages and the source-control hook exchange. 20.7 re-scopes its saved, compiled and invalid criterion at its spec gate, because normal mode sends none of those messages.
- **Guided workflows** are a sequence of individually confirmed proposals, never a batch approval; every write still evaluates the prohibited set, both agent switches and governance. Investigate, from an alert or a log entry, returns a recap and ranked hypotheses citing the rows it used. Harvested prompts take OcuPilot's names.
- **Rule, DTL and BPL edits (20.16).** Warn the user to save the editor first, read the stored content, propose with diff and marker, refuse if the stored content changed after the mint, then reload the editor. The key ships enabled.
- **Agent code paths.** The agent authors code only through the confirmed class and routine saves and creates and the spec-based REST service create. Each refuses `OcuPilot*` names, `%` names, `%SYS` and any document outside its namespace's own routines database, at the mint and at Confirm.
- **Posture questions go up** to the orchestrator with options and a recommendation.

## Technical Decisions

- **Interoperability port (`Port/InteropPort`).** It is the only class that starts, stops, restarts, updates or recovers a production, and the only declared-read source for interoperability configuration.
  - It calls the documented classes the classic pages call (`Ens.Director`, `Ens.Config.Production:ProductionStatus`, `%Dictionary.ClassDefinition:SubclassOf`, and `Ens.Queue` and `Ens.Job` for the queue and job actions) in the caller's process. It never calls `%Api.InteropEditors.*`.
  - Shipped: production control, `Items`, `Settings`, 20.4's nine `LIST` reads, and 20.23's `QUEUE`/`ABORTQUEUE`, `ENTRY`/`ABORTMESSAGE` and `JOB`/`ABORTJOB`/`SUSPENDJOB`/`STOPJOB`. A later read or write extends this port and names its case in AD-62 (and AD-36 for a read) at its spec gate.
  - It reads `Ens.MessageHeader` and `Ens_Util.Log` with `%ExecDirectNoPriv` after its own gate. It never calls `Ens.Job:Enumerate`, whose `MarkDeadJobs` writes. A read writes nothing.
- **Gate first, because the vendor checks nothing.** The port's gate is the whole gate for a read: endpoint pairs, then READ on the namespace's globals database (WRITE for a write); a refusal names the failed pair.
  - Production writes add `%Ens_ProductionRun:USE`. Item and setting writes need `%Ens_ProductionConfig:WRITE` plus WRITE on the globals and routines databases.
  - Queue and job actions declare the vendor's own checks: `%Ens_Queues:WRITE` for the queue aborts, `%Ens_Jobs:WRITE` for a job's abort and stop, `%Ens_MessageSuspend:USE` for suspend, each plus WRITE on the globals database.
  - Settle a surface's pairs from its classic page's own check, then run a least-privileged principal on a throwaway. Extra pairs are declared only where measured, refused by name before any port call, and pinned by a test that removes each one.
- **Namespace and elevation.** The namespace must report interoperability. The port switches by explicit save and restore and calls no `OcuPilot.*` class while switched. The vendor escalates start, stop, restart and update to `_Ensemble`; OcuPilot adds no elevation.
- **Write shapes.** An action-style write declares its request type, sends no body or a port-built one from declared non-secret arguments, and fingerprints every field its precondition reads, over a port-composed fresh read (`STATE`, `QUEUE`, `ENTRY`, `JOB`).
  - Before any vendor call the port refuses by name anything the vendor would answer as a silent success. 20.23's cases: an empty queue, a job whose process ended, an abort or suspend of a job not retrying its message.
  - A queue abort aborts exactly the entries its read enumerated, through `Ens.Queue.AbortItem`, and refuses a queue whose entries moved; `AbortQueue` is never called.
  - A merge write sends a complete body. A create inverts the fresh read: absence is the precondition and is fingerprinted.
- **Destructiveness.** The five production writes are not destructive. The three aborts are destructive; suspend and stop are not. A forced job stop ends only a job of the running production, never a system process or one OcuPilot runs in.
- **Each write finishes in its own request.** Stop, restart, update and a job stop are capped at 15 s; past the cap the target is left as it was (`INTEROP.PRODUCTION.BUSY`). No spawn site is added. Recover is used, never Clean.
- **Two callers, one operation.** A screen action and the agent's write share the fresh read, the prohibited set inside the per-target lock, the gate, the change event and the read-back. Only the agent's caller mints, emits the marker and is gated by the agent switches. A list-valued field changes by a server-side delta over a fresh read.
- **Tool classes share a parent.** `InteropAction` parents `InteropProductionAction` and `InteropItemAction`; a new interoperability tool family extends this hierarchy rather than copying a sibling's members.
- **Tool listing** is cached per process and revalidated on every call against the `OcuPilot` package's compile signature. Only compile-time declarations decide listing; run-time values are read by their own readers on every call.
- **Audit.** Start, stop and restart record the vendor's `StartStop`; Update and Recover are named gaps. Item and setting changes go through `Ens.Util.Auditing.AuditModifyProductionConfig`, never with a value. The queue and job actions, which the vendor does not audit, record OcuPilot's own `ConfigChange` from either caller. A new unaudited vendor operation is named among the spine's gaps, or the port records the event itself.
- **Read-back and script.** After OK a write re-reads its target through its port and returns `readBack`. Every port that defines `Invoke` defines a pure `Snippet` mirroring each branch, secrets as placeholders.
- **Reads, ids, classic pages.**
  - Source kind `interop`. A parent-scoped list takes its parent's route id as its one required criterion, and the port answers the parent key on each row. Reads are capped at 65,536 characters in total and 1,000 per field.
  - Ids keep every part exactly, never use the vendor's integer id, and are percent-encoded in one path segment: `production`, `production-item` (`[Production, Name]`), `production-item-setting` (`[Production, Item, Target, Name]`), `interop-queue`, `interop-message`, `interop-job`.
  - Each tool declares its `CLASSICPAGES`. The queue and job tools declare `EnsPortal.ProductionConfig`, and a job's abort and suspend `EnsPortal.Queues` too.
- **Floor, gating and adjustment.** The API floor admits `%Ens_Portal:USE`, so every new surface declares its own pair matching its classic page's check, and the `InteropFloor*` rosters pin that. `appliesWhen` (`IsEnsembleNamespace`, `%IsDeepSeeEnabled`) decides applicability, not access; `%DeepSee_Portal` can never be a gate. `Screen.Gate.RequiredPairs` is the one reader of a screen's requirement; a write tool's base follows its screen's adjustment, while port and vendor pairs are never adjustable.
- **Embedded editors.** A same-origin, unsandboxed `<iframe>` at `/ui/interop/<editor>/index.html`, carrying only the editor's own query parameters from a read OcuPilot answered. Normal mode only: never `?VSCODE=1`, never pre-written tokens. OcuPilot posts nothing into the frame, reads nothing from it and touches none of its storage.
- **Untrusted content.** Message bodies, log text, item names, settings, lookup values and rule, DTL or BPL content reach the model only through the one sanitizer. No gate or test relies on the sanitizer as its defense.
- **Naming and measurement.** Tools are named `<area>.<screen>.<verb>`. Measure on the instance, and amend the spine at the spec gate rather than working around it.

## UX & Interaction Patterns

- **Rail.** Interoperability and Analytics follow System Explorer and appear only where the namespace reports the feature. The Interoperability side bar holds Productions, Business processes, Data transformations, Business rules, Production monitor, Queues and Jobs. A new screen joins it only once shipped. An item's name cell or a monitor row opens its tabs (Status, Settings, Queue, Log, Messages, Jobs); a queue opens to its messages.
- **Auto-refresh.** Production monitor, Queues and Jobs auto-refresh, default off; the item tabs do not. A screen joins only by declaring it in its descriptor and in EXPERIENCE.md's Auto-refresh roster.
- **Gated controls are never hidden.** They stay focusable and `aria-disabled`, and name the failed pair.
- **Strings.** Each list has a title, an empty state (a write-capable list adds the line inviting the agent) and three suggested prompts. Every new string goes into EXPERIENCE.md's Fixed strings and `strings.ts`, whose values are unique. A refusal sentence lives once, on the server, pinned equal to the fixed string by a test.
- **Dialogs** exist only where EXPERIENCE.md's dialog list names them; everything else is a full-page route, and dialogs never stack. A destructive screen action uses the confirm dialog with a typed name: the queue and job aborts type the message id, the queue's name or the job's pid. Suspend and stop take a warning dialog. A new dialog or pre-write warning amends that list at the spec gate.
- **Cards.** Proposal cards follow the standard lifecycle; production cards carry recover-before-clean guidance. An agent's destructive proposal carries no typed name. A block over eight lines starts collapsed with a summary line naming what changes; Confirm never requires expanding.
- **Embeds and viewers.** The configuration diagram renders in place, its sibling editors opening in new tabs. The HL7, X12 and ASTM schema browsers are read-only. A session trace renders visually, with a generated sequence diagram as the alternative.

## Cross-Story Dependencies

- **Done:** 20.1 to 20.4, 20.14, 20.15, 20.17 to 20.24.
- **Next, 20.5.** Builds on the port and 20.2's production screens. Lookup-table writes ship in it; business-partner save and remove are its stated partial.
- **Interoperability screens.** 20.6 and 20.9 build on the port as well: a 20.6 host test names its item, and 20.9 reuses `interop-message` (inference). 20.8's diagram shows 20.3's items. 20.12 can run a guided disable followed by Update.
- **20.25** consumes 20.3's Production items and 20.4's per-host tabs. Its place in the order is the orchestrator's.
- **Embeds.** 20.13 comes first and gates 20.7, 20.8 and 20.10. 20.16 follows 20.7 and builds on 20.21's agent source saves.
- **Epic 18 runs beside this epic** and shares roster files (entity types, the screen mirror, `strings.ts`, navigation tests, EXPERIENCE.md's rows). Edits there are add-only, summed at the forward merge; anything else is asked first.
- **Into Epic 21.** Epic 21 reuses 20.12's diagnose-slow-query workflow and owns interoperability credentials, purge, deployment, record maps, workflow and the analytics editors, so those stay out of this epic.
