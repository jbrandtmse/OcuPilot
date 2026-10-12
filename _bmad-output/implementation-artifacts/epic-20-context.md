# Epic 20 Context: Stage 4 - Interoperability, with the Analytics rider

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Bring the classic portal's Interoperability work into OcuPilot for namespaces that support it: productions, their items and settings, per-host tabs, the monitor, queues and jobs, lookup tables and business partners, host and transformation tests, message search, resend and trace, the schema viewers and configuration diagram, and the vendor's rule, BPL and DTL editors embedded in place. Analytics rides along with cubes, the model browser, the MDX tool and the cube manager. The agent grows with the stage through guided workflows, Investigate, and rule, DTL and BPL edits. Already shipped: category gating, productions, items and settings, the interoperability floor, screen permissions, the panel collapse, the agent's class and routine reads, saves and creates, the shared tool-listing cache, the per-host tabs, monitor, queues and jobs with their actions, lookup tables, and business partners read-only. Next comes testing hosts and transformations, then the remaining screens, item runtime actions, partner writes and the embeds. Together they make the largest area the classic portal still owns usable here.

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

## Requirements & Constraints

- **One build contract.** Each screen has one descriptor and reaches the instance through one port; its read tool and its write tools' field lists derive from it. Every write is a server-minted proposal with an instance-computed diff, an explicit Confirm and an agent marker.
- **Governance.** A new write key joins the checked-in baseline in the same change; a destructive key ships `false`. Each new action's plan states its destructiveness, its key's default and its audit record.
- **Vendor bundles are never copied or redistributed.** They load in place from the instance.
- **Reads first, as a stated partial.** One remains: the message-contents renderer (20.9). Business-partner save and remove, 20.5's partial, are Story 20.26.
- **Testing hosts and transformations (20.6, next).**
  - A host test builds its request from the target's own schema and shows the result. A transformation test runs on pasted input, renders the output, and is a confirmed write because it executes code on the instance. The research catalog marks both rows confirm-gated; the AC names only the transformation test, so the host test's classification is the plan's to settle and state (a test request runs the target's code (inference)).
  - Classic pages as research read them: `EnsPortal.TestingService` with `Dialog.TestingService` and `Dialog.ObjectEntry` (target type BP or BO, target name, request class and its properties, result as a visual trace; `EnsLib.Testing.Service`; `%Ens_TestingService:USE`; the production must have testing enabled), and `EnsPortal.DataTransformations` with `Dialog.TestTransform` (`Ens.Util.IO`, `Ens.Util.Serialized.Reader`; `%Ens_DTLTest:USE`). Settle calls and pairs from the pages' own source.
  - Research maps both to interop-editors v7 routes (`/productions/production/test/{class}/{target}`, `/dtl/test/{dtlClass}`). The port never calls `%Api.InteropEditors.*`, so 20.6 reaches the vendor classes in process and names its case in AD-62 at its spec gate (inference).
  - Input is pasted content, never a path; a server-file input would be a new AD-21 case written at the spec gate.
- **Business-partner writes (20.26).** Create, update and remove on `Ens.Config.BusinessPartner` through the port, confirmed, over a fresh read, each recording OcuPilot's own audit row. A rename (the vendor's delete then create, no transaction) is refused or done in one transaction; removing a partner an item's `BusinessPartner` setting names reads those items first and refuses or warns, as the plan states. The pair posture goes to the orchestrator (20.5's plan recommends `%Ens_ProductionConfig:WRITE`).
- **Item runtime actions (20.25).** Temporary stop, start and restart of one item, each followed by the production update the vendor requires. Refuse by name where the vendor would answer success while doing nothing (a stopped production, a disabled item). Copy and change of class run as the classic page does, audited by the vendor.
- **Secret-named values.** A name matching the one Secrets pattern (server and client lists pinned equal) is answered with an empty value and default and `Secret` true, and code refuses to set it before any vendor call, from both callers. Lookup entries apply it to keys. Named limit: a secret stored under a non-matching name is not caught.
- **No endpoint accepts a path, except a case the spine names.** A local file's text is a screen action value, never a path and never in a tool's schema; a server file goes through `PathPort`, as an export with a constant overwrite or an import `source` (System Explorer, tasks, lookup tables). Item location settings are AD-21's ninth case.
- **Other writes with extra rules.**
  - Resend and edit-and-resend take a dry run, then a Confirm, with a bounded cap on how many messages one action resends.
  - A cube build, synchronize or repair is the only analytics write. Architect, Analyzer and the User Portal are linked, not rebuilt. Anything beyond the links needs a DeepSee-enabled namespace.
- **Vendor contracts are established against the instance as a story's first task:** the schema browsers' document-selection parameter, the editors' messages and the source-control hook exchange. 20.7 re-scopes its saved, compiled and invalid criterion at its spec gate, because normal mode sends none of those messages.
- **Guided workflows** are a sequence of individually confirmed proposals, never a batch approval; every write still evaluates the prohibited set, both agent switches and governance. Investigate, from an alert or a log entry, returns a recap and ranked hypotheses citing the rows it used. Harvested prompts take OcuPilot's names.
- **Rule, DTL and BPL edits (20.16).** Warn the user to save the editor first, read the stored content, propose with diff and marker, refuse if the stored content changed after the mint, then reload the editor. The key ships enabled.
- **Agent code paths.** The agent authors code only through the confirmed class and routine saves and creates and the spec-based REST service create. Each refuses `OcuPilot*` names, `%` names, `%SYS` and any document outside its namespace's own routines database, at the mint and at Confirm.
- **Posture questions go up** to the orchestrator with options and a recommendation.

## Technical Decisions

- **Interoperability port (`Port/InteropPort`).** The only class that starts, stops, restarts, updates or recovers a production, and the only declared-read source for interoperability configuration.
  - It calls the documented classes the classic pages call (`Ens.Director`, `Ens.Config.Production:ProductionStatus`, `%Dictionary.ClassDefinition:SubclassOf`, `Ens.Queue` and `Ens.Job`, and `Ens.Util.LookupTable` under the vendor's own table lock, `^Ens.LookupTable(<table>)` for 3 s) in the caller's process. It never calls `%Api.InteropEditors.*`.
  - Shipped: production control, `Items`, `Settings`, 20.4's nine `LIST` reads, 20.23's queue and job actions, and 20.5's `LookupTables` (`LIST`, `LOOKUPTABLE`, `DELETETABLE`, `IMPORTTABLE`, `IMPORT`, `EXPORT`), `LookupEntries` (`LIST` by `table`, `LOOKUPENTRY`, `ADDENTRY`, `SETENTRY`, `REMOVEENTRY`) and `BusinessPartners` (`LIST`). A later read or write extends this port and names its case in AD-62 (and AD-36 for a read) at its spec gate.
  - It reads `Ens.MessageHeader` and `Ens_Util.Log` with `%ExecDirectNoPriv` after its own gate, never calls `Ens.Job:Enumerate` (whose `MarkDeadJobs` writes), and a read writes nothing.
- **Gate first, because the vendor checks nothing.** Its production reads and its lookup and partner calls check no privilege (measured), and the lookup and partner calls audit nothing. The port's gate is the whole gate for a read: endpoint pairs, then READ on the namespace's globals database (WRITE for a write); a refusal names the failed pair.
  - Production writes add `%Ens_ProductionRun:USE`. Item and setting writes need `%Ens_ProductionConfig:WRITE` plus WRITE on the globals and routines databases. Queue and job actions declare the vendor's own checks (`%Ens_Queues:WRITE`, `%Ens_Jobs:WRITE`, `%Ens_MessageSuspend:USE`).
  - Lookup reads need `%Ens_LookupTables:READ`, writes `%Ens_LookupTables:WRITE` plus WRITE on the globals database; partners `%Ens_ProductionConfig:READ`. The lookup export adds `%Admin_FileSystemAccess:USE`, stricter than the classic page, because its file carries every value.
  - Settle a surface's pairs from its classic page's own check, then run a least-privileged principal on a throwaway. Extra pairs are declared only where measured, refused by name before any port call, and pinned by a test that removes each one.
- **Namespace and elevation.** The namespace must report interoperability. The port switches by explicit save and restore and calls no `OcuPilot.*` class while switched. The vendor escalates start, stop, restart and update to `_Ensemble`; OcuPilot adds no elevation. A namespace under source control refuses every item and lookup write.
- **Write shapes.** An action-style write declares its request type, sends no body or a port-built one from declared non-secret arguments, and fingerprints every field its precondition reads over a port-composed fresh read (`STATE`, `QUEUE`, `ENTRY`, `JOB`).
  - Before any vendor call the port refuses by name anything the vendor would answer as a silent success (an empty queue, a job whose process ended, a production not running).
  - A merge write sends a complete body. A create inverts the fresh read: absence is the precondition and is fingerprinted. A lookup table is created with its first entry, and removing its last entry removes it.
- **Destructiveness.** The five production writes are not destructive. The queue and job aborts are destructive; suspend and stop are not. A forced job stop ends only a job of the running production.
- **Each write finishes in its own request.** Stop, restart, update and a job stop are capped at 15 s; past the cap the target is left as it was (`INTEROP.PRODUCTION.BUSY`). No spawn site is added. Recover is used, never Clean.
- **Two callers, one operation.** A screen action and the agent's write share the fresh read, the prohibited set inside the per-target lock, the gate, the change event and the read-back. Only the agent's caller mints, emits the marker and is gated by the agent switches. A list-valued field changes by a server-side delta over a fresh read.
- **Tool classes share a parent.** `InteropAction` parents `InteropProductionAction` and `InteropItemAction`; a new interoperability tool family extends this hierarchy rather than copying a sibling's members.
- **Tool listing** is cached per process and revalidated on every call against the `OcuPilot` package's compile signature. Only compile-time declarations decide listing.
- **Audit.** Start, stop and restart record the vendor's `StartStop`; Update and Recover are named gaps. Item and setting changes go through `Ens.Util.Auditing.AuditModifyProductionConfig`, never with a value. Queue, job and lookup writes, which the vendor does not audit, record OcuPilot's own `ConfigChange` from either caller. A new unaudited vendor operation is named among the spine's gaps, or the port records the event itself.
- **Read-back and script.** After OK a write re-reads its target through its port and returns `readBack`. Every port that defines `Invoke` defines a pure `Snippet` mirroring each branch, secrets as placeholders.
- **Reads, ids, classic pages.**
  - Source kind `interop`. A parent-scoped list takes its parent's route id as its one required criterion, and the port answers the parent key on each row. Reads are capped at 65,536 characters in total and 1,000 per field.
  - Ids keep every part exactly, never use the vendor's integer id, and are percent-encoded in one path segment: `production`, `production-item` (`[Production, Name]`), `production-item-setting`, `interop-queue`, `interop-message`, `interop-job`, `lookup-table`, `lookup-entry` (`[Table, Key]`), `business-partner`.
  - Each tool declares its `CLASSICPAGES` (lookup: `EnsPortal.LookupSettings`, import `EnsPortal.Dialog.Import`; partners: `EnsPortal.BusinessPartners`). Each new write's type is reviewed against AD-10's prohibited set and declared covered, as `lookup-table` and `lookup-entry` were (`ReviewedFewOnly`, no self-protection target).
- **Floor, gating and adjustment.** The API floor admits `%Ens_Portal:USE`, so every new surface declares its own pair matching its classic page's check, and the `InteropFloor*` rosters pin that. `appliesWhen` (`IsEnsembleNamespace`, `%IsDeepSeeEnabled`) decides applicability, not access. `Screen.Gate.RequiredPairs` is the one reader of a screen's requirement; port and vendor pairs are never adjustable.
- **Embedded editors.** A same-origin, unsandboxed `<iframe>` at `/ui/interop/<editor>/index.html`, carrying only the editor's own query parameters from a read OcuPilot answered. Normal mode only: never `?VSCODE=1`, never pre-written tokens. OcuPilot posts nothing into the frame, reads nothing from it and touches none of its storage.
- **Untrusted content.** Message bodies, log text, item names, settings, lookup values, test inputs and outputs, and rule, DTL or BPL content reach the model only through the one sanitizer. No gate or test relies on the sanitizer as its defense.
- **Naming and measurement.** Tools are named `<area>.<screen>.<verb>`. Measure on the instance, and amend the spine at the spec gate rather than working around it.

## UX & Interaction Patterns

- **Rail.** Interoperability and Analytics follow System Explorer and appear only where the namespace reports the feature. The side bar holds Productions, Business processes, Data transformations, Business rules, Production monitor, Queues, Jobs, Lookup tables and Business partners; a new screen joins only once shipped. An item's name cell or a monitor row opens its tabs (Status, Settings, Queue, Log, Messages, Jobs); a queue opens to its messages; a lookup table to its entries.
- **Auto-refresh.** Production monitor, Queues and Jobs auto-refresh, default off. A screen joins only by declaring it in its descriptor and in EXPERIENCE.md's Auto-refresh roster.
- **Gated controls are never hidden.** They stay focusable and `aria-disabled`, and name the failed pair.
- **Strings.** Each list has a title, an empty state (a write-capable list adds the line inviting the agent) and three suggested prompts. Every new string goes into EXPERIENCE.md's Fixed strings and `strings.ts`, whose values are unique. A refusal sentence lives once, on the server, pinned equal to the fixed string by a test.
- **Dialogs** exist only where EXPERIENCE.md's dialog list names them; everything else is a full-page route, and dialogs never stack. A destructive screen action uses the confirm dialog with a typed name (queue and job aborts type the message id, queue name or pid; a lookup delete the table's name or the entry's key). 20.5 added the lookup entry, set-value, export and import dialogs. A new dialog or pre-write warning, such as a test request builder, amends that list at the spec gate.
- **Cards.** Proposal cards follow the standard lifecycle; production cards carry recover-before-clean guidance. An agent's destructive proposal carries no typed name. A block over eight lines starts collapsed with a summary line naming what changes; Confirm never requires expanding.
- **Embeds and viewers.** The configuration diagram renders in place, its sibling editors opening in new tabs. The HL7, X12 and ASTM schema browsers are read-only. A session trace renders visually, with a generated sequence diagram as the alternative.

## Cross-Story Dependencies

- **Done:** 20.1 to 20.5, 20.14, 20.15, 20.17 to 20.24.
- **Next, 20.6.** Builds on the port: a host test targets a production item (20.3), and a transformation test starts from 20.2's Data transformations list (inference). The classic host test shows its result as a visual trace, which 20.9 builds.
- **Interoperability screens.** 20.9 reuses `interop-message` (inference). 20.8's diagram shows 20.3's items. 20.12 can run a guided disable followed by Update.
- **20.25** consumes 20.3's Production items and 20.4's per-host tabs; **20.26** consumes 20.5's Business partners screen and read. Their place in the order is the orchestrator's.
- **Embeds.** 20.13 comes first and gates 20.7, 20.8 and 20.10. 20.16 follows 20.7 and builds on 20.21's agent source saves.
- **Epic 18 runs beside this epic** and shares roster files (entity types, the screen mirror, `strings.ts`, navigation tests, EXPERIENCE.md's rows). Edits there are add-only, summed at the forward merge; anything else is asked first.
- **Into Epic 21.** Epic 21 reuses 20.12's diagnose-slow-query workflow and owns interoperability credentials, purge, deployment, record maps, workflow and the analytics editors, so those stay out of this epic.
