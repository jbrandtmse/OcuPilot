# Epic 20 Context: Stage 4 - Interoperability, with the Analytics rider

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Bring the classic portal's Interoperability work into OcuPilot for namespaces that support it: production items and their settings, per-host tabs, the monitor, queues and jobs, lookup tables and business partners, host and transformation tests, message search, resend and trace, the schema viewers and configuration diagram, and the vendor's rule, BPL and DTL editors embedded in place. Analytics rides along with cubes, the model browser, the MDX tool and the cube manager. The agent grows with the stage through guided workflows, Investigate, and rule, DTL and BPL edits. Category gating, productions, production items and their settings, the interoperability floor, screen permissions, the panel collapse and the agent's class and routine reads, saves and creates have shipped. What remains starts with the per-host tabs, the monitor, queues and jobs, then the rest of the interoperability and analytics screens and embeds. Together they make the largest area the classic portal still owns usable here.

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

## Requirements & Constraints

- **One build contract.** Each screen has one descriptor and reaches the instance through one port. Its read tool and its write tools' field lists derive from that descriptor. Every write is a server-minted proposal with an instance-computed diff, an explicit Confirm and an agent marker. Acceptance is that contract plus each row's own backing route or class, and nothing finer is invented in advance.
- **Governance.** A new write key joins the checked-in baseline in the same change. A destructive action this stage adds defaults to disabled (the item remove's key is `false`). The five production writes are not destructive: each is undone by its inverse, and recover deletes no messages.
- **Vendor bundles are never copied or redistributed.** They load in place from the instance.
- **Read-only first, as a stated partial.** Queue and job actions (abort, abort all, suspend, stop), business-partner save and remove, and the message-contents renderer each need custom endpoints. Their reads ship first, and the spec says the row is partial rather than complete.
- **Secret-named values (shipped with item settings, the precedent for any row that carries configuration).** A name matching the Secrets pattern is answered with an empty value and default and `Secret` true, never set through OcuPilot, and refused by code before any vendor call from both callers. Every other value reaches the model through the one sanitizer. Named limit: a secret stored under a name the pattern does not match (an `ExtraHeaders` value carrying a credential) is answered like any other value.
- **No endpoint accepts a path except a case the spine names.** The ninth case, shipped: a host or adapter setting whose classic editor is a directory or file selector is set as its declaring class validates it (`<Name>IsValid`). PathPort's self-protection refusals still apply from either caller, at the mint and again at the write (`PATH.MANAGERDIR`, `PATH.MANAGER`, `PATH.SERVED`). A value is judged as the item's namespace normalizes it, and an inbound file adapter's subdirectory descent that would reach the manager or served directory is refused `INTEROP.SETTING.DESCENT`. The card names the value a location on the server.
- **Other writes with extra rules.**
  - Lookup tables: list, create, edit, delete, import and export round-trip through the port.
  - A host test builds its request from the target's own schema.
  - A transformation test is a confirmed write, because it executes code.
  - Resend and edit-and-resend take a dry run, then a confirm, with a bounded cap on how many messages one action may resend.
  - A cube build, synchronize or repair is the one analytics write. Architect, Analyzer and the User Portal are linked, not rebuilt, and anything beyond links needs a DeepSee-enabled namespace.
- **Establish vendor contracts against the instance first, as the story's first task:** the schema browsers' document-selection parameter, the editors' messages, and the source-control hook exchange. Story 20.7 re-scopes its saved, compiled and invalid criterion at its spec gate, because normal mode sends none of those messages.
- **Guided workflows** are a sequence of individually confirmed proposals, never a batch approval. The prohibited set, both agent switches and governance are evaluated at every write. Investigate, from an alert or a log entry, returns a recap and ranked hypotheses that cite the rows it used. Harvested prompts take OcuPilot's names: no `iris_` prefix and no sibling package names.
- **Rule, DTL and BPL edits (20.16).** Warn the user to save the editor first, because OcuPilot cannot read the frame's unsaved state. Then read the stored content and propose the edit with its diff and marker. Refuse the proposal if the stored content changed after the mint, and reload the editor after the write. The key ships enabled. Raise a typed-name confirmation only for a concrete reason.
- **Agent code writes (shipped, reused by 20.16).** The agent writes class and routine source only through the confirmed saves and creates. These refuse names beginning `OcuPilot`, `%` names, `%SYS`, and any document outside its namespace's own routines database. `explorer.sqldata.save` stays person-only and unadvertised.
- **Posture questions go up.** Any further security-posture question a plan finds returns to the orchestrator with options and a recommendation.

## Technical Decisions

- **Interoperability port (`Port/InteropPort`).** It is the only class that starts, stops, restarts, updates or recovers a production, and the only declared-read source for interoperability configuration. It calls `Ens.Director`, `Ens.Config.Production:ProductionStatus` and `%Dictionary.ClassDefinition:SubclassOf` in the caller's process. It never calls `%Api.InteropEditors.*`, which is `[Hidden]` and answers an unknown state with success. A later interoperability read or write extends this port and names its case in AD-62.
- **Shipped endpoints.**
  - `Items`: `LIST` (one `production` criterion), `ITEM`, `ENABLE`, `DISABLE`, `ADD`, `REMOVE`.
  - `Settings`: `LIST` (one `item` criterion, the item's composite or the vendor's `Production||Item`), `SETTING`, `SET`, `RESET`.
- **Item and setting writes.**
  - An item write changes the stored configuration and then the production class (`SaveToClass`), and touches no job. Measured: `EnableConfigItem` alone leaves the class stale, and a recompile reverts the item and renumbers every vendor item id.
  - It never calls Update, start, stop, restart, recover or `CleanProduction`. A running production then reads update pending, and 20.2's confirmed Update applies it.
  - A remove is refused while the item is enabled. A namespace under source control refuses every item write (`INTEROP.ITEM.SOURCECONTROL`).
  - A setting write is an item write: the same pairs, the source-control refusal, the concurrency-4 open, `SaveToClass`, and an audit naming the setting, never its value. The vendor's `SetItemSettingValue` validates nothing (measured), so the port validates before any vendor call.
- **Tool classes share a parent (Rule 31).** `InteropAction` is the shared parent of the production, item and setting tools: `InteropProductionAction` and `InteropItemAction` extend it, and the setting tools extend `InteropItemAction`. A new interoperability tool family extends this hierarchy rather than copying a sibling's id, field, consequence, query or pair members.
- **Gate first, because the vendor checks nothing.**
  - The gate requires the endpoint's pairs, then READ on the namespace's globals database (WRITE for a write). A production write adds `%Ens_ProductionRun:USE`.
  - An item or setting write's pairs are `%Ens_ProductionConfig:WRITE` plus WRITE on the namespace's globals and routines databases, never the run resource. Each pair is pinned by a test that removes it and observes the refusal by name.
  - A refusal names the failed pair.
  - Settle a surface's pairs from its classic page's own check, then run a least-privileged principal on a throwaway. A write tool declares pairs beyond its screen's only where that run measured them, and is refused by name before any port call.
  - The code lists declare `%Ens_Code:READ`. A narrower audience than the classic page is named, not hidden.
- **Namespace.** The namespace must report interoperability. The port switches by explicit save and restore and calls no `OcuPilot.*` class while switched. An item add and a setting set judge their Confirm in the namespace they were minted in (`InteropAction.ArgumentNamespace`).
- **Production escalation.** For start, stop, restart and update, the vendor checks the caller's run resource and then acts as `_Ensemble`. OcuPilot adds no elevation of its own.
- **Write shapes.**
  - Action-style writes declare their request type and send no body, or a port-built body from declared non-secret arguments. Their fingerprint subject is every field the action's precondition reads, and `PRECONDITIONCODES` names a fresh read's precondition refusals.
  - Production writes run over a port-composed `STATE` read. Before any vendor call they refuse by name whatever the vendor would answer as a silent no-op.
  - A merge write sends a complete body. A setting set reads its value from the declared `Value` of its merged body, and a declared value may be the empty string only where the tool's `SCREENEMPTY` names it.
  - A create (an added item, a new lookup table) inverts the fresh read: a 404 is the precondition, the fingerprint covers the name's absence, and the prohibited set's per-type lists are keyed by create versus change.
  - A port may sequence several calls for one write.
- **Each write finishes in its own request.** Start returns once its jobs launch. Stop, restart and update are capped at 15 s, else `INTEROP.PRODUCTION.BUSY` with the production left as it was. No spawn site is added. Recover, never Clean.
- **Two callers, one operation.**
  - A screen action and the agent's write share the fresh read, the prohibited set inside the per-target lock, the port's gate, the change event and the read-back.
  - Only the agent's caller mints, emits the marker and is gated by the agent switches.
  - A screen Save resolves through the write tool. A screen action accepts only declared values.
  - A list-valued field changes by a server-side delta over a fresh read, never by a list the client computed.
  - A prohibited-set predicate is stated over the effect, never over the payload's shape.
- **Secrets pattern.** Redaction is schema-driven first; the name pattern is a backstop that only adds redaction. It matches, case-insensitively, a name ending in `password`, `passwd`, `pwd`, `secret`, `secret64`, `apikey`, `privatekey`, `token` or `credential`, or a name exactly `Key` or `CredentialName`. The server's redactor and the client's build-time pattern hold one list, pinned equal by a test. A tool may name, per call, the arguments its ledger row and agent step redact (`CallSecretNames`).
- **Read-back, script, audit.**
  - After OK, a write re-reads its target through its port and answers `readBack`. An action-style write says nothing was sent.
  - Every port that defines `Invoke` defines a pure `Snippet` mirroring each branch. A registry test fails any write tool without a script form, secrets render as placeholders, and a script runs the same pasted line by line.
  - A vendor operation that records no audit event joins the spine's named gaps by name. Production Update and Recover are such gaps. Start, stop and restart record `%Ensemble/%Production/StartStop`.
  - Item enable and disable carry the vendor's `ModifyConfiguration` event. Add and remove record none, so the port records it through `Ens.Util.Auditing.AuditModifyProductionConfig`; a setting write is audited the same way, naming the setting and never its value.
- **Reads, ids, classic pages.**
  - The declared-read source kind is `interop`. A parent-scoped list takes its parent's route id as its one required criterion, and the port answers the parent key on each row. A new read amends AD-36 and AD-62.
  - Reads are bounded at 65,536 characters in total and 1,000 a field, and screen context is capped per screen.
  - A `production` id is the class name, kept exactly. A `production-item` id is the composite `[Production, Name]` and a `production-item-setting` id is `[Production, Item, Target, Name]`, each part kept exactly, never the vendor's integer id. Ids are percent-encoded in one path segment.
  - Each tool declares its `CLASSICPAGES`. The item add declares the three `EnsPortal.Dialog.ProductionAdd*` dialogs and the setting reset `EnsPortal.Dialog.ProductionItemSettings`. Actions performed on a list's own page declare none.
- **Floor, gating, adjustments.**
  - The API floor admits `%Ens_Portal:USE`. Every new interoperability or analytics surface declares its own pair matching its classic page's check, and the `InteropFloor*` rosters pin that.
  - The `interoperability` and `analytics` values of `appliesWhen` are `%Library.EnsembleMgr.IsEnsembleNamespace` and `%DeepSee.Utils.%IsDeepSeeEnabled`. They are applicability, not privilege.
  - `%DeepSee_Portal` is public USE and can never be a gate.
  - `Screen.Gate.RequiredPairs` is the one reader of a screen's requirement. Port and vendor pairs are never adjustable.
- **Embedded editors.**
  - The frame is a same-origin, unsandboxed `<iframe>` at `/ui/interop/<editor>/index.html`. It carries only the editor's own query parameters, with values taken from a read OcuPilot answered.
  - Normal mode only: never `?VSCODE=1`, and never tokens pre-written into the editor's storage.
  - OcuPilot posts nothing into the frame, reads nothing from it, and touches none of its storage.
  - Sign-out ends the editors' sign-in.
- **Code writes (for 20.16).**
  - Code writes go through the Atelier port. Its gate is `%Development:USE` plus READ on the namespace's code databases, plus WRITE on the routines database of the proposal's stored namespace.
  - A save seeds If-None-Match and never sends `ignoreConflict`. A 409 is `EXPLORER.DOCUMENT.CONFLICT` and a 423 is `EXPLORER.DOCUMENT.LOCKED`.
  - Each `Old` must match the stored text exactly once.
  - The save compiles on Confirm. Compile output reaches the screen and the card only, never the model.
- **Untrusted content.** Message bodies, log text, item names, comments and settings, and rule, DTL or BPL content reach the model only through the one sanitizer. The sanitizer is never the defense a gate or test relies on.
- **Tool naming and measurement.** Tools are named `<area>.<screen>.<verb>`. Measure on the instance and amend the spine at the spec gate rather than working around it.

## UX & Interaction Patterns

- **Rail.** Interoperability and Analytics follow System Explorer, drawn only where the namespace reports the feature (nine to eleven rail items). The Interoperability side bar today is Productions, Business processes, Data transformations and Business rules; new screens add to it. Production items is a parent-scoped screen keyed by its production, and Item settings opens from an item row. Screen permissions sits under Agent co-pilot.
- **Gated controls are never hidden.** They stay focusable and `aria-disabled`, naming the failed pair.
- **Strings.** Each list has a title, an empty state and three suggested prompts, following the Productions pattern. An action's warning is also its card's consequence. Every new string goes into EXPERIENCE.md's Fixed strings and `strings.ts`, whose values must be unique. A refusal sentence lives once on the server, and a test pins it equal to the fixed string.
- **Dialogs.** A dialog exists only where EXPERIENCE.md's dialog list names it (Item settings' Set value and its reset warning are the latest); everything else is a full-page route, and dialogs never stack. A new dialog or pre-write warning amends that list at the spec gate.
- **Cards.** Proposal cards follow the standard lifecycle. Production cards carry recover-before-clean guidance. A screen's destructive action, such as the item remove, uses the confirm dialog with a typed-name field. A transcript block over eight lines starts collapsed, a summary line names what changes, and Confirm never requires expanding.
- **Embeds and viewers.**
  - The configuration diagram renders in place, and its sibling editors open in new tabs.
  - The HL7, X12 and ASTM schema browsers are read-only.
  - A session trace renders visually, with a generated sequence diagram as the alternative.

## Cross-Story Dependencies

- **Done:** 20.1, 20.2, 20.3, 20.14, 20.15, 20.17 to 20.22.
- **Order:** 20.4 next. Then 20.5, 20.6, 20.13, 20.7, 20.16, 20.8, 20.9, 20.10, 20.11 and 20.12, then the epic's burn-down.
- **Per-host tabs (20.4).** They open from 20.3's item row and read through the interoperability port alongside the production monitor; queue and job reads come from the port, and their actions are the stated partial.
- **Interoperability screens.** 20.4 to 20.6 and 20.9 build on the interoperability port and 20.2's production screens. From 20.3's items: a 20.6 host test names its item, 20.8's diagram shows the items, and 20.12 can run a guided disable followed by Update.
- **Embeds.** 20.13 gates 20.7, 20.8 and 20.10. 20.16 also builds on 20.21's agent source saves.
- **Into Epic 21.** Epic 21 reuses 20.12's diagnose-slow-query workflow. It also owns interoperability credentials, purge, deployment, record maps, workflow and the analytics editors, so those stay out of this epic.
