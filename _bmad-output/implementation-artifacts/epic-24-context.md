# Epic 24 Context: Stage 5, second lane - interoperability, analytics, developer tools and the agent's harvested tools

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Finish Stage 5's parity work on a second slot beside Epic 21: the remaining interoperability surfaces, the analytics editors, a developer-tools set, and for the agent 28 harvested inspection tools plus undo by snapshot and revert, all built the way earlier screens were.

## Stories

- Story 24.1: Developer tools
- Story 24.2: The analytics editors
- Story 24.3: Interoperability parity
- Story 24.4: The agent gains the harvested tools and undo
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

- **Acceptance.** Epic 21's preamble applies unchanged: one screen descriptor, one port, derived field lists, and a round trip over the row's own backing class. Every agent write is a server-minted, confirmed proposal with a diff and an agent marker.
- **Governance.** A new write key joins the baseline in the change that ships it. Write keys default to enabled; every new destructive key ships disabled; a key missing from the baseline counts as disabled.
- **Harvest.** Take handler bodies and nothing else, reading each current body first. Rename packages, globals, audit sources, web paths and the `iris_` prefix to OcuPilot's own (`<area>.<screen>.<verb>`).
- **Single instance.** No request leaves the instance: diff and promote run only between its namespaces. Remote profiles and the work-queue viewer are excluded as not planned; the unit-test run record replaces the viewer.
- **Developer tools.** Console output is bounded by the harvested ceiling. Promote keeps four gates (plan, execute-with-confirm, steps allow-list, plan-hash freshness) and states it has no rollback. Deployment history offers rollback and delete.
- **Agent tools.** Each harvested tool declares `read` or `write` at definition and passes the single call-time gate. Undo snapshots the target before the write; its revert is itself a confirmed proposal with its own diff and audit marker. The state-capture model is designed in this epic.

## Technical Decisions

- **Harvest seam.** Handlers inherit OcuPilot's base class, whose `RenderResponseBody` emits the single envelope; handler bodies are never edited to reshape output.
- **In-process, as the user.** No HTTP hop, no elevation; privilege is checked at call time, never cached. Each port evaluates its declared resource pairs before any vendor call.
- **InteropPort** is the only path to production writes and interoperability configuration reads. It never calls `%Api.InteropEditors`; the namespace must report interoperability; it switches namespace by explicit save and restore with no `OcuPilot.*` call while switched. Items are `[Production, Name]`. A source-controlled namespace refuses writes; secret-named settings and the vendor's silent no-ops are refused by name before any vendor call. `New $ROLES` only in `PurgeFrame`, which never adds a role.
- **Long writes** (purge, export, archive run, cube build) run in their confirm or action request, never in `%RunBackgroundMethod` jobs. One outlasting the Web Gateway timeout runs to its end and its answer is lost (named limit); the audit log records its outcome. An export writes no file on the instance.
- **AnalyticsPort** calls `%DeepSee` in process, never `/api/deepsee`: resource pairs, then namespace shape, then analytics enabled, then READ on the namespace's databases. Only reads measured to write nothing; MDX that runs code fails closed; ids match case exactly.
- **Class-backed definitions** (listing groups, quality measures, export-to-cube) are saved and compiled; a refused compile restores the class. `%` and `OcuPilot` packages are refused.
- **AtelierPort** alone names `%Api.Atelier.*`; its writes also need WRITE on the target routines database.
- **Run-code exception** (test runner, consoles, terminal): person-only (`PERSONGATE`; an agent call is refused `PROHIBITED.PERSONONLY`), keys ship `false`, every run is confirmed naming its consequence, and output reaches only the screen. A console run records a `SecurityChange` row without the command.
- **One operation, two callers.** Screen action and agent write share target resolution, fresh read, prohibited-set check, change event and read-back; a screen action mints no proposal. Read-back re-reads through the port with the caller's privileges as `readBack`; a write and a fresh read never share a request type.
- **Audit.** Measure each write with auditing on; where the vendor records nothing, write OcuPilot's `ConfigChange` or `SecurityChange`, or name the gap.
- No endpoint accepts a path or concatenates caller values into SQL. Guided workflows are catalog entries, one proposal per turn.

## UX & Interaction Patterns

- Each screen registers route with `?ns=`, side-bar entry, archetype, privilege resource, context serializer, actions (destructive last) and empty-state sentence; sub-screens and tabs stay out of the side bar.
- The "Or ask the agent:" line takes a short phrase. An action's label is its dialog's title. Secrets show masked and are set only by their own action; stored expressions show as text and never run.
- Gated controls stay focusable with `aria-disabled` and say why. Destructive screen actions use a typed-name confirm; agent destructive proposals use the destructive card. Dialog and card state the same consequence, claiming no more than the instance does.
- Refusals show the server's sentence; vendor text is logged, never shown. Result lines carry `role=status`. Fixed strings go in the experience spine's string table in the story that ships them; reuse existing words.

## Cross-Story Dependencies

- All stories harvest through Story 21.1's seam (on the feature branch); none depends on a story Epic 21 still holds. Interoperability stories extend Epic 20's InteropPort, analytics stories its AnalyticsPort.
- 24.5 establishes the run-code exception for 24.6 and 24.7. 24.8's diff compares the default settings 24.15 reads; 24.9's promote tool is what the harvested promote workflow awaits. 24.10 extends 24.2's term-list editor; 24.12 reuses 24.11's class-save pattern.
- The 28 harvested tools split 14 / 10 / 3 / 1 across 24.4, 24.21, 24.22, 24.23.
- 24.5, 24.8 and 24.14 add exclusion-register rows; a test holds the register equal to the catalog.
