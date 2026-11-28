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

- **Acceptance.** One screen descriptor, one port, derived field lists, and a round trip over the row's own backing class. Every agent write is a server-minted, confirmed proposal with a diff and an agent marker.
- **Governance.** A new write key joins the baseline in the change that ships it. Write keys default to enabled; every new destructive key ships disabled; a missing key counts as disabled.
- **Harvest.** Take handler bodies only, reading each current body first. Rename packages, globals, audit sources, web paths and the `iris_` prefix to OcuPilot's own (`<area>.<screen>.<verb>`).
- **Single instance.** No request leaves the instance.
- **Deployment** produces its log and rollback files; its history offers rollback and delete.
- **Agent tools** each declare `read` or `write` at definition and pass the single call-time gate. Undo snapshots the target before the write; its revert is itself a confirmed proposal with its own diff and audit marker; the state-capture model is designed here.

## Technical Decisions

- **Harvest seam.** Handlers inherit OcuPilot's base class, whose `RenderResponseBody` emits the single envelope; handler bodies are never edited to reshape output.
- **In-process, as the user.** No HTTP hop, no elevation; privilege is checked at call time, never cached. Each port evaluates its declared pairs before any vendor call; a refusal names the failed pair.
- **InteropPort** is the only path to production writes and interoperability configuration reads. It never calls `%Api.InteropEditors`; the namespace must report interoperability; it switches namespace by explicit save and restore and calls no `OcuPilot.*` class while switched. Items are `[Production, Name]`. No shipped class names an `Ens.*`/`EnsLib.*`/`EnsPortal.*` class where the compiler resolves it.
- **InteropPort patterns.** Pairs are the classic page's `RESOURCE` plus READ/WRITE on the namespace's globals database. Refuse by name, before any vendor call, whatever the vendor would answer as silent success. A source-controlled namespace refuses config writes. Secret-named settings and credential passwords are never read. Lists carry a row cap; check SQL SELECT where the classic query needs it. Record `ConfigChange` where the vendor audits nothing.
- **`New $ROLES`** only in `InteropPort.PurgeFrame`, which contains vendor `%All` escalations and never adds a role.
- **Long writes** run in their confirm or action request, never in background jobs; one outlasting the Web Gateway timeout loses its answer (named limit) and the audit log records its outcome. Vendor writes triggered by a read are a closed list of eight shapes; a new one needs a spine amendment.
- **Run-code exception** (test runner, consoles, terminal): person-only (`PERSONGATE`; an agent call is refused `PROHIBITED.PERSONONLY`), keys ship `false`, every run is confirmed naming its consequence, output reaches only the screen.
- **One operation, two callers.** Screen action and agent write share target resolution, fresh read, prohibited-set check, change event and read-back; a screen action mints no proposal.
- **Auto-refresh** is one shared framework; its fourteen-screen roster is fixed in the spine and experience spec, so adding a screen amends both.
- No endpoint accepts a path or concatenates caller values into SQL.

## UX & Interaction Patterns

- Each screen registers route with `?ns=`, side-bar entry, archetype, privilege resource, context serializer, actions (destructive last) and empty-state sentence; sub-screens stay out of the side bar.
- "Or ask the agent:" takes a short phrase, never a sentence. An action's label is its dialog's title. Secrets show masked; stored expressions show as text and never run.
- Gated controls stay focusable with `aria-disabled` and say why. Destructive screen actions use a typed-name confirm; agent destructive proposals use the destructive card, stating the same consequence.
- Refusals show the server's sentence; vendor text is logged, never shown. Result lines carry `role=status`. New fixed strings go in the experience spine's string table.

## Cross-Story Dependencies

- Done: 24.1 to 24.6 and 24.8 to 24.17. Open: 24.7 and 24.18 to 24.23.
- All stories harvest through Story 21.1's seam; interoperability stories extend Epic 20's InteropPort.
- 24.7 builds under the run-code exception 24.5 established and 24.6 reused.
- The 28 harvested tools split 14 / 10 / 3 / 1 across 24.4, 24.21, 24.22, 24.23.
- 24.5, 24.8 and 24.14 added exclusion-register rows; a test holds the register equal to the catalog.
