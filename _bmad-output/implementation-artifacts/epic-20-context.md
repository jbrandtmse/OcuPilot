# Epic 20 Context: Stage 4 - Interoperability, with the Analytics rider

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Bring the classic portal's Interoperability work into OcuPilot for namespaces that support it: productions, their items and settings, per-host tabs, the monitor, queues and jobs, lookup tables and business partners, host and transformation tests, message search, resend and trace, the schema viewers and configuration diagram, and the vendor's rule, BPL and DTL editors embedded in place. Analytics rides along with cubes, the model browser, the MDX tool and the cube manager. The agent grows with the stage through guided workflows, Investigate, and rule, DTL and BPL edits. Already shipped: category gating, productions, items and settings, the interoperability floor, screen permissions, the panel collapse, the agent's class and routine reads, saves and creates, the shared tool-listing cache, and the reads behind the per-host tabs, monitor, queues and jobs. Next come the queue and job actions, then the remaining screens and embeds. Together they make the largest area the classic portal still owns usable here.

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

## Requirements & Constraints

- **One build contract.** Each screen has one descriptor and reaches the instance through one port. Its read tool and its write tools' field lists derive from that descriptor. Every write is a server-minted proposal with an instance-computed diff, an explicit Confirm and an agent marker.
- **Governance.** A new write key joins the checked-in baseline in the same change. A destructive key ships `false`. Each new action's plan states its destructiveness, its key's default and its audit record.
- **Vendor bundles are never copied or redistributed.** They load in place from the instance.
- **Reads first, as a stated partial.** Where an action half needs custom endpoints, the read ships first and its spec names the partial: queue and job actions (now 20.23), business-partner save and remove, and the message-contents renderer.
- **Queue and job actions (20.23).** Four targets: abort one queued message, abort a whole queue, abort or suspend a job's active message, and stop a job.
  - Each is a confirmed action-style write over a fresh read, through the interoperability port.
  - Where the vendor answers success on a target it does nothing to, the port refuses by name before any vendor call: a job that is not retrying its message, and a pid that is not a job of the running production.
  - Measured: the vendor writes no audit row for any of these. A stop forced past its timeout requeues the active message and leaves Update pending. Stop is capped at 15 s.
  - The classic per-host Actions tab's other item actions (temporary stop, start and restart of one item, change class, copy) have no story yet. 20.23 carries them or names the story that will.
  - Its charter is the measured split in 20.4's Design Notes.
- **Secret-named values.** A name matching the Secrets pattern is answered with an empty value and default and `Secret` true. It is never set through OcuPilot: code refuses it before any vendor call, from both callers. Every other value reaches the model through the one sanitizer. Named limit: a secret stored under a name the pattern does not match is answered like any other value.
- **No endpoint accepts a path, except a case the spine names.** A host or adapter setting whose classic editor is a file or directory selector is validated by its declaring class, and PathPort's self-protection refusals apply at the mint and again at the write.
- **Other writes with extra rules.**
  - Lookup tables: list, create, edit, delete, import and export each round-trip through the port.
  - A host test builds its request from the target's own schema. A transformation test is a confirmed write, because it executes code.
  - Resend and edit-and-resend take a dry run and then a Confirm, with a bounded cap on how many messages one action resends.
  - A cube build, synchronize or repair is the only analytics write. Architect, Analyzer and the User Portal are linked, not rebuilt. Anything beyond those links needs a DeepSee-enabled namespace.
- **Vendor contracts are established against the instance as a story's first task:** the schema browsers' document-selection parameter, the editors' messages and the source-control hook exchange. 20.7 re-scopes its saved, compiled and invalid criterion at its spec gate, because normal mode sends none of those messages.
- **Guided workflows** are a sequence of individually confirmed proposals, never a batch approval. Every write still evaluates the prohibited set, both agent switches and governance. Investigate, from an alert or a log entry, returns a recap and ranked hypotheses that cite the rows it used. Harvested prompts take OcuPilot's names: no `iris_` prefix and no sibling package names.
- **Rule, DTL and BPL edits (20.16).** Warn the user to save the editor first, because OcuPilot cannot read the frame's unsaved state. Read the stored content, propose the edit with its diff and marker, refuse if the stored content changed after the mint, and reload the editor after the write. The key ships enabled; a typed-name confirmation only for a concrete reason.
- **Agent code paths.** The agent authors code only through the confirmed class and routine saves and creates and Epic 18's spec-based REST service create. Each refuses `OcuPilot*` names, `%` names, `%SYS`, and any document stored outside its namespace's own routines database, at the mint and at Confirm. `explorer.sqldata.save` stays person-only and unadvertised.
- **Posture questions go up.** Any further security-posture question a plan finds goes to the orchestrator with options and a recommendation.

## Technical Decisions

- **Interoperability port (`Port/InteropPort`).** It is the only class that starts, stops, restarts, updates or recovers a production, and the only declared-read source for interoperability configuration.
  - It calls `Ens.Director`, `Ens.Config.Production:ProductionStatus` and `%Dictionary.ClassDefinition:SubclassOf` in the caller's process. It never calls `%Api.InteropEditors.*`, which is `[Hidden]` and answers an unknown state with success.
  - Shipped endpoints: `Items`, `Settings`, and 20.4's nine `LIST` reads (`Monitor`, `ItemStatus`, `Queues`, `QueueItems`, `ItemQueue`, `ItemLog`, `ItemMessages`, `Jobs`, `ItemJobs`). Any later interoperability read or write extends this port and names its case in AD-62 at its spec gate.
  - It reads `Ens.MessageHeader` and `Ens_Util.Log` with `%ExecDirectNoPriv` after its own gate, because SQL grants are not kept per namespace. It never calls `Ens.Job:Enumerate`, whose `MarkDeadJobs` writes. A read writes nothing.
- **Gate first, because the vendor checks nothing.** The port's gate is the whole gate for a read.
  - Endpoint pairs, then READ on the namespace's globals database (WRITE for a write). A production write adds `%Ens_ProductionRun:USE`; an item or setting write needs `%Ens_ProductionConfig:WRITE` plus WRITE on the globals and routines databases. A refusal names the failed pair.
  - Settle a surface's pairs from its classic page's own check, then run a least-privileged principal on a throwaway. A write tool declares pairs beyond its screen's only where that run measured them, refused by name before any port call. A test pins each pair by removing it.
- **Namespace and elevation.** The namespace must report interoperability. The port switches by explicit save and restore and calls no `OcuPilot.*` class while switched. A write's Confirm is judged in the namespace it was minted in. The vendor escalates start, stop, restart and update to `_Ensemble` after checking the caller's run resource; OcuPilot adds no elevation.
- **Write shapes.**
  - An action-style write declares its request type. It sends no body, or a port-built body made only from declared non-secret arguments.
  - Its fingerprint covers every field the action's precondition reads. `PRECONDITIONCODES` names the precondition refusals a fresh read can return.
  - Before any vendor call, the port refuses by name anything the vendor would answer as a silent no-op.
  - A merge write sends a complete body. A create inverts the fresh read: a 404 is the precondition, and the fingerprint covers the name's absence. A port may sequence several calls for one write.
- **Each write finishes in its own request.** Stop, restart and update are capped at 15 s; past the cap the answer is `INTEROP.PRODUCTION.BUSY` and the target is left as it was. No spawn site is added. Recover is used, never Clean.
- **Two callers, one operation.** A screen action and the agent's write share the fresh read, the prohibited set inside the per-target lock, the port's gate, the change event and the read-back. Only the agent's caller mints, emits the marker and is gated by the agent switches. A screen action accepts only declared values. A list-valued field changes by a server-side delta over a fresh read. A prohibited-set predicate is stated over the effect, never the payload's shape.
- **Tool classes share a parent.** `InteropAction` parents `InteropProductionAction` and `InteropItemAction`, and the setting tools extend `InteropItemAction`. A new interoperability tool family extends this hierarchy rather than copying a sibling's members.
- **Tool listing.** The listing is cached per process and revalidated on every call against the `OcuPilot` package's compile signature. Only compile-time declarations may decide whether or how a tool is listed. Run-time values (privilege, screen adjustments, governance, read-only, the kill switch) are read by their own readers on every call and never enter the listing.
- **Secrets pattern.** Redaction is schema-driven first; the name pattern is a backstop that can only add. It matches, case-insensitively, a name ending in `password`, `passwd`, `pwd`, `secret`, `secret64`, `apikey`, `privatekey`, `token` or `credential`, or exactly `Key` or `CredentialName`. Server and client hold one list, pinned equal by a test. A tool may name per call the arguments its ledger row redacts (`CallSecretNames`).
- **Read-back, script, audit.**
  - After OK, a write re-reads its target through its port and returns `readBack`; an action-style write's says nothing was sent.
  - Every port that defines `Invoke` defines a pure `Snippet` mirroring each branch, with secrets as placeholders.
  - A vendor operation that records no audit event is named among the spine's gaps, or the port records the event itself. Production Update and Recover are named gaps. Start, stop and restart record `%Ensemble/%Production/StartStop`. Item and setting changes are audited through `Ens.Util.Auditing.AuditModifyProductionConfig`, never with a value.
- **Reads, ids, classic pages.**
  - The declared-read source kind is `interop`. A parent-scoped list takes its parent's route id as its one required criterion, and the port answers the parent key on each row (`production`, `queue`, `item`). A new read amends AD-36 and AD-62.
  - Reads are capped at 65,536 characters in total and 1,000 per field.
  - Ids keep every part exactly, never use the vendor's integer id, and are percent-encoded in one path segment: `production` (class name), `production-item` (`[Production, Name]`), `production-item-setting` (`[Production, Item, Target, Name]`), `interop-queue` (queue name), `interop-message` (header id), `interop-job` (pid).
  - Each tool declares its `CLASSICPAGES`; an action on a list's own page declares none. Item tabs map to `EnsPortal.ProductionConfig`, Production monitor to `EnsPortal.ProductionMonitor`, Queues and Queue messages to `EnsPortal.Queues`, Jobs to `EnsPortal.Jobs`.
- **Floor and gating.** The API floor admits `%Ens_Portal:USE`; every new surface declares its own pair matching its classic page's check, and the `InteropFloor*` rosters pin that. `appliesWhen` uses `%Library.EnsembleMgr.IsEnsembleNamespace` and `%DeepSee.Utils.%IsDeepSeeEnabled`, which decide applicability, not access. `%DeepSee_Portal` is public USE and can never be a gate. `Screen.Gate.RequiredPairs` is the one reader of a screen's requirement; port and vendor pairs are never adjustable.
- **Embedded editors.** A same-origin, unsandboxed `<iframe>` at `/ui/interop/<editor>/index.html`, carrying only the editor's own query parameters with values from a read OcuPilot answered. Normal mode only: never `?VSCODE=1`, never tokens pre-written into the editor's storage. OcuPilot posts nothing into the frame, reads nothing from it and touches none of its storage. Sign-out ends the editors' sign-in.
- **Untrusted content.** Message bodies, log text, item names, settings, and rule, DTL or BPL content reach the model only through the one sanitizer. No gate or test relies on the sanitizer as its defense.
- **Naming and measurement.** Tools are named `<area>.<screen>.<verb>`. Measure on the instance, and amend the spine at the spec gate rather than working around it.

## UX & Interaction Patterns

- **Rail.** Interoperability and Analytics follow System Explorer and appear only where the namespace reports the feature. The Interoperability side bar holds Productions, Business processes, Data transformations, Business rules, Production monitor, Queues and Jobs; new screens add to it. Production items is parent-scoped by its production. An item's name cell or a monitor row opens the item's tabs: Status, Settings, Queue, Log, Messages, Jobs. A queue opens to its messages.
- **Auto-refresh.** Production monitor, Queues and Jobs auto-refresh, default off; the item tabs do not. A screen joins only by declaring it in its descriptor and appearing in EXPERIENCE.md's Auto-refresh roster.
- **Gated controls are never hidden.** They stay focusable and `aria-disabled`, and name the failed pair.
- **Strings.** Each list has a title, an empty state and three suggested prompts. An action's warning is also its card's consequence. Every new string goes into EXPERIENCE.md's Fixed strings and `strings.ts`, whose values are unique. A refusal sentence lives once, on the server, pinned equal to the fixed string by a test.
- **Dialogs** exist only where EXPERIENCE.md's dialog list names them; everything else is a full-page route, and dialogs never stack. A new dialog or pre-write warning amends that list at the spec gate.
- **Cards.** Proposal cards follow the standard lifecycle; production cards carry recover-before-clean guidance. A screen's destructive action uses the confirm dialog with a typed-name field; an agent's destructive proposal carries no typed name (the destructive bar and Confirm are its confirmation). A block over eight lines starts collapsed with a summary line naming what changes; Confirm never requires expanding.
- **Embeds and viewers.** The configuration diagram renders in place, its sibling editors opening in new tabs. The HL7, X12 and ASTM schema browsers are read-only. A session trace renders visually, with a generated sequence diagram as the alternative.

## Cross-Story Dependencies

- **Done:** 20.1 to 20.4, 20.14, 20.15, 20.17 to 20.22, 20.24.
- **Next, 20.23.** It consumes 20.4's Queues, Queue messages, Queue tab and Jobs reads. Its writes refresh those screens through the `interop-queue`, `interop-message` and `interop-job` change-event types 20.4 added.
- **Epic 18 runs beside this epic** and shares roster files (entity types, the screen mirror, `strings.ts`, navigation tests, EXPERIENCE.md's rows). Edits there are add-only, summed at the forward merge; anything else is asked first.
- **Interoperability screens.** 20.5, 20.6, 20.9 and 20.23 build on the port and 20.2's production screens. 20.3's items feed later stories: a 20.6 host test names its item, 20.8's diagram shows the items, and 20.12 can run a guided disable followed by Update. 20.9 reuses `interop-message` (inference).
- **Embeds.** 20.13 comes first and gates 20.7, 20.8 and 20.10. 20.16 follows 20.7 and builds on 20.21's agent source saves.
- **Into Epic 21.** Epic 21 reuses 20.12's diagnose-slow-query workflow. It owns interoperability credentials, purge, deployment, record maps, workflow and the analytics editors, so those stay out of this epic.
