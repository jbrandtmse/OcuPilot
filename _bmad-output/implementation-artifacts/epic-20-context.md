# Epic 20 Context: Stage 4 - Interoperability, with the Analytics rider

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Bring the classic portal's Interoperability work into OcuPilot for namespaces that support it: production items and their settings, per-host tabs, the monitor, queues and jobs, lookup tables and business partners, host and transformation tests, message search, resend and trace, the schema viewers and configuration diagram, and the vendor's rule, BPL and DTL editors embedded in place. Analytics rides along with cubes, the model browser, the MDX tool and the cube manager. The agent grows with the stage through guided workflows, Investigate, and rule, DTL and BPL edits. Category gating, productions, the interoperability floor, screen permissions, the panel collapse and the agent's class and routine reads, saves and creates have shipped. What remains is mostly the interoperability and analytics screens and embeds, which make the largest area the classic portal still owns usable here.

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
- **Governance.** A new write key joins the checked-in baseline in the same change. A destructive action this stage adds defaults to disabled. The five production writes are not destructive: each is undone by its inverse, and recover deletes no messages.
- **Vendor bundles are never copied or redistributed.** They load in place from the instance.
- **Read-only first, as a stated partial.** Queue and job actions (abort, abort all, suspend, stop), business-partner save and remove, and the message-contents renderer each need custom endpoints. Their reads ship first.
- **Production items (20.3).** Enable, disable, add and remove each round-trip through the interoperability port as a confirmed write. An item write changes the stored configuration and the production class only. A running production then reads update pending, and 20.2's confirmed Update applies it. A remove is refused while the item is enabled.
- **Item settings (20.22), on the owner's ruling "A: hide secrets, allow paths".**
  - Settings are listed through the port with their source: production, system default or class default.
  - Set and reset are confirmed writes, validated by the host or adapter class, and save the production class. A running production then reads update pending.
  - A setting whose name matches the Secrets pattern is never returned, as value or default, to the screen, a tool, the context or the ledger, and is never set through OcuPilot. Code refuses it, and any value the host class refuses, before any vendor call, from both callers.
  - Every other setting is shown, reaches the model through the one sanitizer, and is settable by both callers.
  - A host's own server-path setting is accepted as its validated value under a new AD-21 named case, written at 20.22's spec gate quoting the owner, and its diff row names it.
  - Named limit, recorded in AD-36: a secret stored under a name the pattern does not match is not caught.
- **Other writes with extra rules.**
  - Lookup tables: list, create, edit, delete, import and export round-trip through the port.
  - A host test builds its request from the target's own schema.
  - A transformation test is a confirmed write, because it executes code.
  - Resend and edit-and-resend take a dry run, then a confirm, with a bounded cap on how many messages one action may resend.
  - A cube build, synchronize or repair is the one analytics write. Architect, Analyzer and the User Portal are linked, not rebuilt, and anything beyond links needs a DeepSee-enabled namespace.
- **Establish vendor contracts against the instance first, as the story's first task:** the production-update vocabulary (done in 20.2), the schema browsers' document-selection parameter, the editors' messages, and the source-control hook exchange. Story 20.7 re-scopes its saved, compiled and invalid criterion at its spec gate, because normal mode sends none of those messages.
- **Guided workflows** are a sequence of individually confirmed proposals, never a batch approval. The prohibited set, both agent switches and governance are evaluated at every write. Investigate, from an alert or a log entry, returns a recap and ranked hypotheses that cite the rows it used. Harvested prompts take OcuPilot's names: no `iris_` prefix and no sibling package names.
- **Rule, DTL and BPL edits (20.16).** Warn the user to save the editor first, because OcuPilot cannot read the frame's unsaved state. Then read the stored content and propose the edit with its diff and marker. Refuse the proposal if the stored content changed after the mint, and reload the editor after the write. The key ships enabled. Raise a typed-name confirmation only for a concrete reason.
- **Agent code writes (shipped, reused by 20.16).** The agent writes class and routine source only through the confirmed saves and creates. These are refused for names beginning `OcuPilot`, `%` names, `%SYS` and any document outside its namespace's own routines database. `explorer.sqldata.save` stays person-only and unadvertised.
- **Posture questions go up.** Any further security-posture question a plan finds returns to the orchestrator with options and a recommendation.

## Technical Decisions

- **Interoperability port (`Port/InteropPort`).** It is the only class that starts, stops, restarts, updates or recovers a production, and the only declared-read source for interoperability configuration. It calls `Ens.Director`, `Ens.Config.Production:ProductionStatus` and `%Dictionary.ClassDefinition:SubclassOf` in the caller's process. It never calls `%Api.InteropEditors.*`, which is `[Hidden]` and answers an unknown state with success. A later interoperability write or read, items and settings included, extends this port and names its case in the spine.
- **Gate first, because the vendor's reads check nothing.**
  - The gate requires the endpoint's pairs, then READ on the namespace's globals database (WRITE for a write), then `%Ens_ProductionRun:USE` for a production write.
  - A refusal names the failed pair.
  - Settle a surface's pairs from its classic page's own check, then run a least-privileged principal on a throwaway. A write tool declares pairs beyond its screen's only where that run measured them, and is refused by name before any port call.
  - The code lists declare `%Ens_Code:READ`. A narrower audience than the classic page is named, not hidden.
- **Namespace.** The namespace must report interoperability. The port switches by explicit save and restore and calls no `OcuPilot.*` class while switched.
- **Production escalation.** For start, stop, restart and update, the vendor checks the caller's run resource and then acts as `_Ensemble`. OcuPilot adds no elevation of its own.
- **Write shapes.**
  - Action-style writes declare their request type and send no body, or a port-built body from declared non-secret arguments. Their fingerprint subject is every field the action's precondition reads, and `PRECONDITIONCODES` names a fresh read's precondition refusals.
  - Production writes run over a port-composed `STATE` read. Before any vendor call they refuse by name whatever the vendor would answer as a silent no-op.
  - A merge write sends a complete body.
  - A create (an added item, a new lookup table) inverts the fresh read: a 404 is the precondition, the fingerprint covers the name's absence, and the prohibited set's per-type lists are keyed by create versus change.
  - A port may sequence several calls for one write.
- **Each write finishes in its own request.** Start returns once its jobs launch. Stop, restart and update are capped at 15 s, else `INTEROP.PRODUCTION.BUSY` with the production left as it was. No spawn site is added. Recover, never Clean.
- **Two callers, one operation.**
  - A screen action and the agent's write share the fresh read, the prohibited set inside the per-target lock, the port's gate, the change event and the read-back.
  - Only the agent's caller mints, emits the marker and is gated by the agent switches.
  - A screen Save resolves through the write tool.
  - A screen action accepts only declared values.
  - A list-valued field changes by a server-side delta over a fresh read, never by a list the client computed.
  - A prohibited-set predicate is stated over the effect, never over the payload's shape.
- **Secrets pattern.** Redaction is schema-driven first; the name pattern is a backstop that only adds redaction. It matches, case-insensitively, a name ending in `password`, `passwd`, `pwd`, `secret`, `secret64`, `apikey`, `privatekey`, `token` or `credential`, or a name exactly `Key` or `CredentialName`. The server's redactor and the client's build-time pattern hold one list, pinned equal by a test, and any exception is named in the spine and held by both copies.
- **Read-back, script, audit.**
  - After OK, a write re-reads its target through its port and answers `readBack`. An action-style write says nothing was sent.
  - Every port that defines `Invoke` defines a pure `Snippet` mirroring each branch. A registry test fails any write tool without a script form, secrets render as placeholders, and a script runs the same pasted line by line.
  - A vendor operation that records no audit event joins the spine's named gaps by name. Production Update and Recover are such gaps; start, stop and restart record `%Ensemble/%Production/StartStop`.
- **Reads, ids, classic pages.**
  - The declared-read source kind is `interop`, today `LIST` on four endpoints with no criteria, detail call or parts. A new read amends that.
  - Reads are bounded at 65,536 characters in total and 1,000 a field, and screen context is capped per screen.
  - A `production` id is the class name, kept exactly.
  - Ids are percent-encoded in one path segment.
  - Each tool declares its `CLASSICPAGES`.
  - No endpoint accepts a path, except a case the spine names. A server file goes through `PathPort` (`%Admin_FileSystemAccess:USE`); 20.22's host path setting is a new named case.
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
- **Untrusted content.** Message bodies, log text, item settings and rule, DTL or BPL content reach the model only through the one sanitizer. The sanitizer is never the defense a gate or test relies on.
- **Tool naming and measurement.** Tools are named `<area>.<screen>.<verb>`. Measure on the instance and amend the spine at the spec gate rather than working around it.

## UX & Interaction Patterns

- **Rail.** Interoperability and Analytics follow System Explorer, drawn only where the namespace reports the feature (nine to eleven rail items). The Interoperability side bar today is Productions, Business processes, Data transformations and Business rules; new screens add to it. Screen permissions sits under Agent co-pilot.
- **Gated controls are never hidden.** They stay focusable and `aria-disabled`, naming the failed pair.
- **Strings.** Each list has a title, an empty state and three suggested prompts, following the Productions pattern. An action's warning is also its card's consequence. Every new string goes into EXPERIENCE.md's Fixed strings and `strings.ts`. A refusal sentence lives once on the server, and a test pins it equal to the fixed string.
- **Cards and dialogs.** Proposal cards follow the standard lifecycle. Production cards carry recover-before-clean guidance. A screen's destructive action uses the confirm dialog with a typed-name field. A transcript block over eight lines starts collapsed, a summary line names what changes, and Confirm never requires expanding.
- **Embeds and viewers.**
  - The configuration diagram renders in place, and its sibling editors open in new tabs.
  - The HL7, X12 and ASTM schema browsers are read-only.
  - A session trace renders visually, with a generated sequence diagram as the alternative.

## Cross-Story Dependencies

- **Done:** 20.1, 20.2, 20.14, 20.15, 20.17 to 20.21.
- **Order:** 20.3 next, then 20.22, then 20.4 to 20.6. 20.13 comes before 20.7, and 20.16 follows 20.7.
- **20.3 carries two of 20.2's ledger items:**
  - DW-2157: a stop from Running can leave the production reading Suspended while the tool answers success.
  - DW-2162: a stop or restart whose jobs outlast the cap answers a logged 500, with the production half-stopped.
- **Items and settings.** 20.3's item writes and 20.22's settings writes leave a running production at update pending, so both rely on 20.2's confirmed Update. 20.22 consumes 20.3; its first plan is 20.3's first plan (`git show 6def26fa:_bmad-output/implementation-artifacts/spec-20-3-production-items.md`).
- **Interoperability screens.** 20.3 to 20.6, 20.22 and 20.9 build on the interoperability port and 20.2's production screens.
- **Embeds.** 20.13 gates 20.7, 20.8 and 20.10. 20.16 also builds on 20.21's agent source saves.
- **Into Epic 21.** Epic 21 reuses 20.12's diagnose-slow-query workflow. It also owns interoperability credentials, purge, deployment, record maps, workflow and the analytics editors, so those stay out of this epic.
