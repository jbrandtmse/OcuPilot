# Epic 20 Context: Stage 4 - Interoperability, with the Analytics rider

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Bring the classic portal's Interoperability work into OcuPilot for namespaces that support it: production items and their settings, per-host tabs, the monitor, queues and jobs, lookup tables and business partners, host and transformation tests, message search, resend and trace, the schema viewers and configuration diagram, and the vendor's rule, BPL and DTL editors embedded in place. Analytics rides along with cubes, the model browser, the MDX tool and the cube manager. The agent grows with the stage through guided workflows, Investigate, and rule, DTL and BPL edits. Already shipped: category gating, productions, production items and their settings, the interoperability floor, screen permissions, the panel collapse, and the agent's class and routine reads, saves and creates. Next comes a fix that stops every agent tool call from rebuilding the tool registry listing. Then the per-host tabs, monitor, queue and job reads ship, followed by their actions, and after them the remaining interoperability and analytics screens and embeds. Together they make the largest area the classic portal still owns usable here.

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

- **One build contract.** Each screen has one descriptor and reaches the instance through one port. Its read tool and its write tools' field lists derive from that descriptor. Every write is a server-minted proposal with an instance-computed diff, an explicit Confirm and an agent marker. Acceptance is that contract plus each row's own backing route or class.
- **Governance.** A new write key joins the checked-in baseline in the same change. A destructive action defaults to disabled (the item remove's key is `false`). The five production writes are not destructive: each is undone by its inverse, and recover deletes no messages. Each new action's plan states its destructiveness, its key's default and its audit record.
- **Vendor bundles are never copied or redistributed.** They load in place from the instance.
- **Read-only first, as a stated partial.** Story 20.4 ships only the reads for the per-host tabs, the monitor, queues and jobs. Their actions are its stated partial, carried by 20.23. Business-partner save and remove and the message-contents renderer also ship their reads first, and their specs name the row partial.
- **Queue and job actions (20.23).** Four targets: abort one queued message, abort a whole queue, abort or suspend a job's active message, and stop a job.
  - Each is a confirmed action-style write over a fresh read, through the interoperability port.
  - Where the vendor would answer success on a target it does nothing to, the port refuses by name before any vendor call. Two such targets are named: a job that is not retrying its message, and a pid that is not a job of the running production.
  - Measured: the vendor writes no audit row for any of these actions. A stop forced past its timeout requeues the active message and leaves Update pending. Stop is capped at 15 s.
  - The classic per-host Actions tab's other item actions have no story yet: temporary stop, start and restart of one item, change class, and copy. 20.23 either carries them or names the story that will.
- **Tool registry listing (20.24).** Today every agent tool call lists the whole tool registry twice before its gate, about 1.1 s per call (measured).
  - Build the listing once and serve it from one cache to every caller: the gate's resolve, the wire resolve and dispatch. Do not give each caller its own cache.
  - Measure the same call before and after on the throwaway, and record the saving per tool call.
  - A tool class compiled after the listing was cached must appear on the next call without a restart; this is the in-place IPM upgrade case. A test pins it.
- **Secret-named values.** This is the precedent for any row that carries configuration, set by item settings.
  - A name matching the Secrets pattern is answered with an empty value and default and `Secret` true. It is never set through OcuPilot: code refuses it before any vendor call, from both callers.
  - Every other value reaches the model through the one sanitizer.
  - Named limit: a secret stored under a name the pattern does not match is answered like any other value.
- **No endpoint accepts a path, except a case the spine names.** The shipped ninth case: a host or adapter setting whose classic editor is a directory or file selector is validated by its declaring class (`<Name>IsValid`).
  - PathPort's self-protection refusals still apply, from either caller, at the mint and again at the write.
  - A value is judged as the item's namespace normalizes it.
  - An inbound file adapter's subdirectory descent that would reach the manager directory or a served directory is refused `INTEROP.SETTING.DESCENT`.
- **Other writes with extra rules.**
  - Lookup tables: list, create, edit, delete, import and export each round-trip through the port.
  - A host test builds its request from the target's own schema.
  - A transformation test is a confirmed write, because it executes code.
  - Resend and edit-and-resend take a dry run and then a Confirm. One action may resend only a bounded number of messages.
  - A cube build, synchronize or repair is the only analytics write. Architect, Analyzer and the User Portal are linked, not rebuilt. Anything beyond those links needs a DeepSee-enabled namespace.
- **Establish vendor contracts against the instance as each story's first task.** These are the schema browsers' document-selection parameter, the editors' messages and the source-control hook exchange. 20.7 re-scopes its saved, compiled and invalid criterion at its spec gate, because normal mode sends none of those messages.
- **Guided workflows** are a sequence of individually confirmed proposals, never a batch approval. Every write still evaluates the prohibited set, both agent switches and governance. Investigate, from an alert or a log entry, returns a recap and ranked hypotheses that cite the rows it used. Harvested prompts take OcuPilot's names: no `iris_` prefix and no sibling package names.
- **Rule, DTL and BPL edits (20.16).**
  - Warn the user to save the editor first, because OcuPilot cannot read the frame's unsaved state.
  - Read the stored content, then propose the edit with its diff and agent marker.
  - Refuse the proposal if the stored content changed after the mint, and reload the editor after the write.
  - The key ships enabled. Ask for a typed-name confirmation only for a concrete reason.
- **Agent code writes (shipped, reused by 20.16).** The agent writes class and routine source only through the confirmed saves and creates. These refuse names beginning `OcuPilot`, `%` names, `%SYS`, and any document stored outside its namespace's own routines database. `explorer.sqldata.save` stays person-only and unadvertised.
- **Posture questions go up.** Any further security-posture question a plan finds goes back to the orchestrator with options and a recommendation.

## Technical Decisions

- **Interoperability port (`Port/InteropPort`).**
  - It is the only class that starts, stops, restarts, updates or recovers a production, and the only declared-read source for interoperability configuration.
  - It calls `Ens.Director`, `Ens.Config.Production:ProductionStatus` and `%Dictionary.ClassDefinition:SubclassOf` in the caller's process.
  - It never calls `%Api.InteropEditors.*`, which is `[Hidden]` and answers an unknown state with success.
  - Any later interoperability read or write extends this port and names its case in AD-62.
- **Port endpoints.**
  - `Items`, shipped: `LIST` (one `production` criterion), `ITEM`, `ENABLE`, `DISABLE`, `ADD`, `REMOVE`.
  - `Settings`, shipped: `LIST` (one `item` criterion, either the item's composite or the vendor's `Production||Item`), `SETTING`, `SET`, `RESET`.
  - 20.4 adds nine `LIST` reads, each behind its classic page's pair: `Monitor`, `ItemStatus`, `Queues`, `QueueItems`, `ItemQueue`, `ItemLog`, `ItemMessages`, `Jobs`, `ItemJobs`.
  - 20.4 reads `Ens.MessageHeader` and `Ens_Util.Log` with `%ExecDirectNoPriv` after the port's own gate. Plain `%ExecDirect` answered SQLCODE -99 to a holder of every read resource, because SQL grants are not kept per namespace.
  - 20.4 never calls `Ens.Job:Enumerate`, whose `MarkDeadJobs` writes, and calls no queue or job action.
- **Item and setting writes.**
  - An item write changes the stored configuration and then the production class (`SaveToClass`), and touches no job. Measured: `EnableConfigItem` alone leaves the class stale, and a recompile reverts the item and renumbers every vendor item id.
  - An item write never calls Update, start, stop, restart, recover or `CleanProduction`. A running production then reads update pending, and 20.2's confirmed Update applies it.
  - A remove is refused while the item is enabled. A namespace under source control refuses every item write (`INTEROP.ITEM.SOURCECONTROL`).
  - A setting write is an item write. It uses the same pairs, the same source-control refusal, the concurrency-4 open, `SaveToClass`, and an audit that names the setting but never its value.
  - The vendor's `SetItemSettingValue` validates nothing (measured), so the port validates before any vendor call.
- **Tool classes share a parent.** `InteropAction` is the parent of the production, item and setting tools. `InteropProductionAction` and `InteropItemAction` extend it, and the setting tools extend `InteropItemAction`. A new interoperability tool family extends this hierarchy rather than copying a sibling's members.
- **Gate first, because the vendor checks nothing.** The vendor's reads check nothing, so the port gate is the whole gate for a read.
  - The gate requires the endpoint's pairs, then READ on the namespace's globals database (WRITE for a write). A production write adds `%Ens_ProductionRun:USE`.
  - An item or setting write's pairs are `%Ens_ProductionConfig:WRITE` plus WRITE on the namespace's globals and routines databases. They never include the run resource. A test pins each pair by removing it and observing the refusal by name.
  - A refusal names the failed pair.
  - Settle a surface's pairs from its classic page's own check, then run a least-privileged principal on a throwaway. A write tool declares pairs beyond its screen's only where that run measured them, and is refused by name before any port call.
  - The code lists declare `%Ens_Code:READ`. Where the audience is narrower than the classic page's, the spec says so.
- **Namespace.** The namespace must report interoperability. The port switches namespace by explicit save and restore, and calls no `OcuPilot.*` class while switched. An item add and a setting set judge their Confirm in the namespace they were minted in.
- **Production escalation.** For start, stop, restart and update, the vendor checks the caller's run resource and then acts as `_Ensemble`. OcuPilot adds no elevation of its own.
- **Write shapes.**
  - An action-style write declares its request type. It sends no body, or a port-built body made from declared non-secret arguments.
  - Its fingerprint covers every field the action's precondition reads. `PRECONDITIONCODES` names the precondition refusals a fresh read can return.
  - Before any vendor call, a production write refuses by name anything the vendor would answer as a silent no-op.
  - A merge write sends a complete body. A setting set reads its value from the declared `Value` of its merged body. A declared value may be empty only where the tool's `SCREENEMPTY` names it.
  - A create, such as an added item or a new lookup table, inverts the fresh read. A 404 is the precondition and the fingerprint covers the name's absence.
  - A port may sequence several calls for one write.
- **Each write finishes in its own request.** Start returns once its jobs launch. Stop, restart and update are capped at 15 s; past the cap the answer is `INTEROP.PRODUCTION.BUSY` and the production is left as it was. No spawn site is added. Recover is used, never Clean.
- **Two callers, one operation.** A screen action and the agent's write share the fresh read, the prohibited set inside the per-target lock, the port's gate, the change event and the read-back.
  - Only the agent's caller mints, emits the marker and is gated by the agent switches.
  - A screen Save resolves through the write tool. A screen action accepts only declared values.
  - A list-valued field changes by a server-side delta over a fresh read, never by a list the client computed.
  - A prohibited-set predicate is stated over the effect, never over the payload's shape.
- **Registry cache limits (20.24).** The shared cache may hold only the tool listing.
  - Privilege is checked in the caller's process at call time and never cached.
  - `Screen.Gate.RequiredPairs` reads a screen's pairs on every call.
  - Read-only and the kill switch are re-read between steps and at Confirm.
  - On every call, dispatch still runs its whole chain: wire name, identity, gate, required pairs and arguments.
  - Prohibited actions stay absent from the tool set.
- **Secrets pattern.** Redaction is schema-driven first. The name pattern is a backstop that can only add redaction.
  - It matches, case-insensitively, a name ending in `password`, `passwd`, `pwd`, `secret`, `secret64`, `apikey`, `privatekey`, `token` or `credential`, or a name that is exactly `Key` or `CredentialName`.
  - The server's redactor and the client's build-time pattern hold one list, and a test pins them equal.
  - Per call, a tool may name the arguments its ledger row and agent step redact (`CallSecretNames`).
- **Read-back, script, audit.**
  - After OK, a write re-reads its target through its port and returns `readBack`. An action-style write's read-back says nothing was sent.
  - Every port that defines `Invoke` defines a pure `Snippet` that mirrors each branch. A registry test fails any write tool without a script form. Secrets render as placeholders.
  - A vendor operation that records no audit event is listed by name among the spine's named gaps, or the port records the event itself. Production Update and Recover are such gaps.
  - Start, stop and restart record `%Ensemble/%Production/StartStop`. Item enable and disable carry the vendor's `ModifyConfiguration` event.
  - Item add and remove and setting writes are audited through `Ens.Util.Auditing.AuditModifyProductionConfig`, never with a value.
- **Reads, ids, classic pages.**
  - The declared-read source kind is `interop`. A parent-scoped list takes its parent's route id as its one required criterion, and the port answers the parent key on each row. Queue messages (`queue`) and an item's tabs (`item`) are parent-scoped this way. A new read amends AD-36 and AD-62.
  - Reads are capped at 65,536 characters in total and 1,000 per field, and screen context is capped per screen.
  - Ids keep every part exactly and never use the vendor's integer id. Each is percent-encoded in one path segment:
    - `production`: the class name.
    - `production-item`: `[Production, Name]`.
    - `production-item-setting`: `[Production, Item, Target, Name]`.
    - `interop-queue`: the queue's name.
    - `interop-message`: the message header's id.
    - `interop-job`: the job's pid.
  - Each tool declares its `CLASSICPAGES`, and an action performed on a list's own page declares none.
    - An item's tabs map to `EnsPortal.ProductionConfig`.
    - Production monitor maps to `EnsPortal.ProductionMonitor`, Queues and Queue messages to `EnsPortal.Queues`, and Jobs to `EnsPortal.Jobs`.
    - The item add declares the three `EnsPortal.Dialog.ProductionAdd*` dialogs, and the setting reset declares `EnsPortal.Dialog.ProductionItemSettings`.
- **Floor, gating, adjustments.**
  - The API floor admits `%Ens_Portal:USE`. Every new interoperability or analytics surface declares its own pair matching its classic page's check, and the `InteropFloor*` rosters pin that. `%EnsRole_Monitor` also opens Production monitor and its read tool.
  - The `interoperability` and `analytics` values of `appliesWhen` are `%Library.EnsembleMgr.IsEnsembleNamespace` and `%DeepSee.Utils.%IsDeepSeeEnabled`. They decide whether a screen applies, not who may open it.
  - `%DeepSee_Portal` is public USE and can never be a gate.
  - `Screen.Gate.RequiredPairs` is the one reader of a screen's requirement. Port and vendor pairs can never be adjusted.
- **Embedded editors.**
  - The frame is a same-origin, unsandboxed `<iframe>` at `/ui/interop/<editor>/index.html`.
  - It carries only the editor's own query parameters, with values taken from a read OcuPilot answered.
  - Normal mode only: never `?VSCODE=1`, and never tokens pre-written into the editor's storage.
  - OcuPilot posts nothing into the frame, reads nothing from it and touches none of its storage.
  - Sign-out ends the editors' sign-in.
- **Code writes, reused by 20.16.**
  - Code writes go through the Atelier port. Its gate is `%Development:USE`, plus READ on the namespace's code databases, plus WRITE on the routines database of the proposal's stored namespace.
  - A save seeds If-None-Match and never sends `ignoreConflict`. A 409 answers `EXPLORER.DOCUMENT.CONFLICT` and a 423 answers `EXPLORER.DOCUMENT.LOCKED`.
  - Each `Old` must match the stored text exactly once.
  - The save compiles on Confirm. Compile output reaches the screen and the card only, never the model.
- **Untrusted content.** Message bodies, log text, item names, comments, settings, and rule, DTL or BPL content reach the model only through the one sanitizer. No gate or test relies on the sanitizer as its defense.
- **Tool naming and measurement.** Tools are named `<area>.<screen>.<verb>`. Measure on the instance, and amend the spine at the spec gate rather than working around it.

## UX & Interaction Patterns

- **Rail.**
  - Interoperability and Analytics follow System Explorer and appear only where the namespace reports the feature, giving nine to eleven rail items.
  - The Interoperability side bar today holds Productions, Business processes, Data transformations and Business rules, and new screens add to it.
  - Production items is a parent-scoped screen keyed by its production. Item settings and the item's tabs open from an item row.
  - Screen permissions sits under Agent co-pilot.
- **Auto-refresh.** Production monitor, Queues and Jobs join the auto-refreshing screens, default off, as their classic pages refresh. A screen joins only by declaring auto-refresh in its descriptor and appearing in EXPERIENCE.md's Auto-refresh roster.
- **Gated controls are never hidden.** They stay focusable and `aria-disabled`, and name the failed pair.
- **Strings.**
  - Each list has a title, an empty state and three suggested prompts, following the Productions pattern.
  - An action's warning is also its card's consequence.
  - Every new string goes into EXPERIENCE.md's Fixed strings and into `strings.ts`, whose values must be unique.
  - A refusal sentence lives once, on the server, and a test pins it equal to the fixed string.
- **Dialogs.** A dialog exists only where EXPERIENCE.md's dialog list names it. Everything else is a full-page route, and dialogs never stack. A new dialog or pre-write warning amends that list at the spec gate.
- **Cards.**
  - Proposal cards follow the standard lifecycle. Production cards carry the guidance to recover before cleaning.
  - A screen's destructive action uses the confirm dialog with a typed-name field.
  - A transcript block over eight lines starts collapsed, and a summary line names what changes. Confirm never requires expanding.
- **Embeds and viewers.**
  - The configuration diagram renders in place, and its sibling editors open in new tabs.
  - The HL7, X12 and ASTM schema browsers are read-only.
  - A session trace renders visually, with a generated sequence diagram as the alternative.

## Cross-Story Dependencies

- **Done:** 20.1, 20.2, 20.3, 20.14, 20.15, 20.17 to 20.22. 20.4 is specified, reads only, and ready for development.
- **Order:** 20.24 comes next on slot B, ahead of 20.4 and 20.23. Then come 20.4, 20.23, 20.5, 20.6, 20.13, 20.7, 20.16, 20.8, 20.9, 20.10, 20.11 and 20.12, followed by the epic's burn-down.
- **20.24 and Epic 18.** Epic 18's 18.12 adds tools and touches the registry. Before each edit, check the registry and dispatch files against Epic 18's diff. Only add-only edits proceed without asking.
- **20.4 to 20.23.** The per-host tabs open from 20.3's item row and read through the interoperability port alongside the production monitor.
  - 20.23 consumes 20.4's Queues, Queue messages, Queue tab and Jobs reads. Its charter is the measured split in 20.4's design notes.
  - The `interop-queue`, `interop-message` and `interop-job` change-event types let 20.23's writes refresh those screens. 20.9 reuses `interop-message` (inference).
- **Interoperability screens.** 20.4 to 20.6, 20.9 and 20.23 build on the interoperability port and 20.2's production screens. 20.3's items feed later stories:
  - a 20.6 host test names its item;
  - 20.8's diagram shows the items;
  - 20.12 can run a guided disable followed by Update.
- **Embeds.** 20.13 gates 20.7, 20.8 and 20.10. 20.16 also builds on 20.21's agent source saves.
- **Into Epic 21.** Epic 21 reuses 20.12's diagnose-slow-query workflow. It also owns interoperability credentials, purge, deployment, record maps, workflow and the analytics editors, so those stay out of this epic.
