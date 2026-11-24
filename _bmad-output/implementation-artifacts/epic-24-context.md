# Epic 24 Context: Stage 5, second lane - interoperability, analytics, developer tools and the agent's harvested tools

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Finish Stage 5's parity work on a second slot, running beside Epic 21. The epic covers the remaining interoperability surfaces, the analytics editors Epic 20 left out, a developer-tools set (unit-test runner, consoles, web terminal, environment diff and promote), and for the agent the 28 harvested inspection tools plus undo by snapshot and revert. Each surface is built the same way as every earlier screen, so OcuPilot moves toward classic-portal parity without a second way of building anything.

## Stories

- Story 24.1: Developer tools (LOC metrics and drift hashes)
- Story 24.2: The analytics editors (term-list editor)
- Story 24.3: Interoperability parity (auto-start and shutdown groups, plus routed cleanup)
- Story 24.4: The agent gains the harvested tools and undo (session and message reads)
- Story 24.5: Unit-test runner and work-queue viewer
- Story 24.6: The command and class-method consoles
- Story 24.7: Web terminal
- Story 24.8: Remote instance profiles and environment diff
- Story 24.9: Environment promote
- Story 24.10: Folder manager transfer and term-list import, export and copy
- Story 24.11: Listing groups
- Story 24.12: Quality measures
- Story 24.13: Analytics settings
- Story 24.14: PMML model tester and dashboard viewer
- Story 24.15: Credentials, default settings and schedules
- Story 24.16: Purge, suspended messages, export and the archive manager
- Story 24.17: Managed alerts, logs, the system monitor and workflow
- Story 24.18: PEX, record maps and HL7 authoring
- Story 24.19: The registries, interface maps and references, port authority and deployment
- Story 24.20: Undo by snapshot and revert
- Story 24.21: The agent's harvested log, process, source and configuration tools
- Story 24.22: The agent's harvested message body searches
- Story 24.23: The agent's harvested vocabulary tool

## Requirements & Constraints

- **Acceptance contract.** Each surface is accepted on one screen descriptor, one port, derived field lists, and a round trip over its own backing class. Every agent write is a server-minted, confirmed proposal that carries a diff and an agent marker.
- **Governance.** A new write key joins the governance baseline in the change that ships it. Write keys default to enabled. Every new destructive key ships disabled, and a key missing from the baseline counts as disabled.
- **Harvest discipline.** Take handler bodies and nothing else. Read each current body before taking it. Rename every harvested package, global, audit source, web path and `iris_` tool prefix to OcuPilot's own names (`<area>.<screen>.<verb>`).
- **Single instance.** No request leaves the instance, so environment diff and promote run only between namespaces of this instance. Remote instance profiles and the work-queue viewer go into the exclusion register as not planned, each with its reason. The unit-test runner's run record takes the work-queue viewer's place.
- **Developer tools.** Console output is bounded by the harvested output ceiling. Promote keeps four gates: plan, execute-with-confirm, a steps allow-list, and plan-hash freshness. It says that it has no rollback. Deployment writes log and rollback files, and its history offers rollback and delete.
- **Agent tools.** Every harvested tool declares `read` or `write` when it is defined and passes the single call-time gate. Undo snapshots the target before the write. Its revert is itself a confirmed proposal with its own diff and audit marker, and the state-capture model is designed in this epic.

## Technical Decisions

- **Harvest seam.** Harvested handlers inherit OcuPilot's base class, whose `RenderResponseBody` emits the single error and response envelope. The handler body itself is never edited to reshape output.
- **In-process, as the user.** Tools call IRIS classes in the caller's process: no HTTP hop, no elevation, and privilege is checked at call time and never cached. Each port evaluates its declared resource pairs before any vendor call, because many vendor classes check nothing.
- **InteropPort** is the only path to production writes and interoperability configuration reads:
  - It never calls `%Api.InteropEditors`.
  - The namespace must report interoperability. The port switches namespace by explicit save and restore and makes no `OcuPilot.*` call while switched.
  - Items are identified by `[Production, Name]`. A namespace under source control refuses item writes, and secret-named settings are refused.
  - The vendor's silent no-ops are refused by name before any vendor call.
  - A long write runs in its confirm or action request. The classic pages' `%RunBackgroundMethod` jobs are not used.
  - `New $ROLES` is allowed only in `PurgeFrame`, which contains a vendor escalation and never adds a role.
- **AnalyticsPort** calls `%DeepSee` in process, never `/api/deepsee`. It checks resource pairs, then namespace shape, then that analytics is enabled, then READ on the namespace's databases. It calls only reads measured to write nothing. MDX that runs code fails closed. Analytics ids match case exactly.
- **Class-backed definitions** (listing groups, quality measures, export-to-cube classes) are saved and compiled. A refused compile puts the class back as it was. Classes in the `%` and `OcuPilot` packages are refused.
- **AtelierPort** is the only class that names `%Api.Atelier.*`. Its writes also need WRITE on the target namespace's routines database.
- **Run-code exception** (unit-test runner, consoles, terminal):
  - Only a person can use these tools. They declare `PERSONGATE`, and an agent call is refused `PROHIBITED.PERSONONLY`.
  - Their governance keys ship `false`.
  - Every run is confirmed, and the confirmation names its consequence.
  - Output reaches only the screen, never the model, ledger, audit or log. A console run records a `SecurityChange` row that never includes the command.
- **One operation, two callers.** A screen action and an agent write share target resolution, the fresh read, the prohibited-set check, the change event and the read-back. A screen action mints no proposal.
- **Read-back.** After a write, the target is re-read through the tool's port with the caller's privileges and reported as `readBack`. A write and a fresh read never share a request type.
- **Audit.** Measure each write with auditing on. Where the vendor records nothing, record OcuPilot's own `ConfigChange` or `SecurityChange`, or name the gap.
- **Files and SQL.** No endpoint accepts a path or concatenates caller values into SQL.
- **Guided workflows** are catalog entries, never code paths: one named step per write, one proposal per turn.
- When an architecture decision has to change, amend the spine; never work around it.

## UX & Interaction Patterns

- Every screen registers the standard contract: a route with `?ns=`, a side-bar entry, an archetype, a privilege resource, a context serializer, actions (destructive last) and an empty-state sentence. Sub-screens and tabs never appear in the side bar.
- On a write-capable list, the "Or ask the agent:" line takes a short phrase, never a sentence.
- An action's label is also its dialog's title. Secrets show as a mask, and only their own action sets them. Stored expressions are shown as text and never run.
- Gated controls stay focusable with `aria-disabled` and say why they are gated. Destructive screen actions use a typed-name confirm. Agent destructive proposals use the destructive card.
- Refusals show the server's sentence. Vendor text is logged, never shown. Result lines carry `role=status`.
- Fixed strings come from the experience spine's string table. Reuse the words other screens already use.

## Cross-Story Dependencies

- Every story harvests through Story 21.1's seam. Interoperability stories extend Epic 20's InteropPort, and analytics stories extend its AnalyticsPort.
- Story 24.5 establishes the run-code exception, and Stories 24.6 and 24.7 build under it.
- Story 24.8's diff compares the per-namespace default settings that Story 24.15 reads. Story 24.9's promote tool is the one the harvested promote workflow is waiting for.
- Story 24.10 extends 24.2's term-list editor. Story 24.12 reuses 24.11's class-save pattern.
- The 28 harvested tools are split across Stories 24.4 (14), 24.21 (10), 24.22 (3) and 24.23 (1).
- Stories 24.5, 24.8 and 24.14 add exclusion-register rows, and a test holds the register equal to the catalog.
