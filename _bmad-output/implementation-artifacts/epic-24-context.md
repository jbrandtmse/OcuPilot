# Epic 24 Context: Stage 5, second lane - interoperability, analytics, developer tools and the agent's harvested tools

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Epic 24 was split from Epic 21 (Stage 5, custom-REST parity) so a second slot can run it beside Epic 21. It makes the remaining classic-portal leaves that have a backing class but no route reachable: the rest of the interoperability area, the analytics editors the Epic 20 rider left out, and a developer-tools set harvested from the MCP suite. It also grows the agent: the 28 inspection tools harvested from iris-session-agent, and undo by snapshot and revert. Every surface is built under the same staged-delivery contract as earlier stages, so the product reaches parity without a second way of building a screen, a tool or a write.

## Stories

- Story 24.1: Developer tools (LOC metrics and drift hashes)
- Story 24.2: The analytics editors (term-list editor)
- Story 24.3: Interoperability parity (auto-start and shutdown groups, plus routed cleanup entries)
- Story 24.4: The agent gains the harvested tools and undo (14 session and message read tools)
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

- **The staged-delivery contract governs every story.** Acceptance is that contract plus the catalog row's own backing class: each surface round-trips over that class. A new screen is declared by exactly one descriptor and reaches outside OcuPilot through exactly one port. Its read tool and its write tools' field lists derive from that descriptor.
- **Every write is a confirmed proposal**: server-minted, with a diff computed on the instance, an explicit confirmation and an agent audit marker. A confirmed write reads its target back and reports whether the instance holds what was sent.
- **Governance:** a new write key joins the governance baseline in the story that ships it. **Every new destructive key defaults to disabled.** A mutating key absent from the baseline is disabled.
- **Harvest discipline:** take handler bodies and nothing else. The MCP suite's manifest is stale and its bootstrap is TypeScript-driven. Read the current body before harvesting it, because known defects (the task-history filter, resource creation with a description) have unverified fix status.
- **Single instance only.** No request leaves the instance except to the configured LLM provider. Environment diff and promote work between namespaces of this instance only. Remote instance profiles and the work-queue viewer are recorded in the exclusion register as not planned, each with its stated reason.
- Every confirmation names its consequence in plain words. Reads are bounded and report truncation.

## Technical Decisions

- **Harvest seam (Story 21.1, already on the feature branch).** Harvested `ExecuteMCPv2.REST.*` bodies inherit an OcuPilot base exposing `RenderResponseBody(pStatus, pMsgPart, pResPart)`, which emits OcuPilot's single envelope. Only the base class changes; a body is never edited to change response shape, and the no-double-envelope assertion must keep passing. Open item: nothing yet polices a harvested body class called past `HarvestPort`'s gate.
- **Ports and gates.** Interoperability goes through `InteropPort`, which calls `Ens.Director` and the configuration classes in process and never `%Api.InteropEditors`. Analytics goes through `AnalyticsPort`, which calls `%DeepSee` classes in process, never `/api/deepsee`, and uses only reads measured to write nothing. Source and document work goes through `AtelierPort`. Each port checks its own pairs at call time before any vendor call, because the vendor's reads check nothing. Switch namespaces by explicit save and restore and call no `OcuPilot.*` class while switched. No shipped class may depend on `Ens.*` at compile time. Interoperability items are identified by `[Production, Name]`, never by the vendor's integer id. A namespace under source control refuses item writes. Production stop, restart and update are capped at 15 s and never call clean. No caller value is concatenated into SQL, and no endpoint accepts a path.
- **Run-code exception** (24.5 to 24.7): the unit-test runner, the consoles and the web terminal run code with the signed-in person's rights, under three rules:
  - The tool is a person's alone. It declares `PERSONGATE` and is unadvertised. An agent-reachable call is refused `PROHIBITED.PERSONONLY`, and the tool has no mint, proposal card or copy-out draft.
  - It is off by default. Its governance key ships `false` and is asked only by `POST /screens/:screen/action`. The shipped keys are `explorer.unittests.run`, `explorer.command.run` and `explorer.classmethod.run`.
  - Every run passes a confirmation that names its consequence.

  The port refuses a target in an `OcuPilot` package, or a command naming OcuPilot in any letter case. OcuPilot's protected state stays refused to non-administrators through its guarded stores. Console results reach the screen only, as text, and console output is bounded by the harvested output ceiling. Each console run records OcuPilot's own `SecurityChange` row (the console, the namespace, and the class and method), never the command, the arguments or the answer. A unit-test run records no vendor audit event, which is a named gap.
- **The 28 harvested agent tools** (24.4, 24.21 to 24.23): each declares `read` or `write` at definition time and passes the single call-time gate. From iris-session-agent, take the rules and not the mechanism:
  - Use the locked JSON-Schema subset, with no `$ref`, `oneOf`, `anyOf`, `allOf` or `pattern`.
  - Tools never touch `%session`, `%request` or `$NAMESPACE`.
  - Rename everything into OcuPilot's names, including the `iris_` prefix.
  - Tool results reach the model only through the sanitizer, and an agent read tool never executes code.
- **Undo (24.20):** capture a snapshot before the write and offer a one-click revert. The revert is itself a confirmed proposal with its own diff and audit marker. The write path has no state-capture model yet, so design it here rather than retrofit it.
- **Promote (24.9)** keeps four gates: plan, execute-with-confirm, a steps allow-list and plan-hash freshness. It states plainly that there is no rollback. A guided workflow is a catalog entry, and every write in it is one confirmed proposal.
- **Deployment (24.19)** produces its log and rollback files. The deployment history offers rollback and delete.

## UX & Interaction Patterns

- All copy goes in the experience spec's copy tables, added in the story that ships it. A destructive confirm says the action cannot be undone where that applies.
- A run-code confirmation says the code runs as the person, with the person's rights, in this namespace, and that OcuPilot cannot see or undo what it changes.
- List screens and their read tools share one bounded, declared read that reports truncation.

## Cross-Story Dependencies

- Every story harvests through Story 21.1's seam. No story depends on a story Epic 21 still holds.
- The interoperability stories (24.3, 24.15 to 24.19) extend Epic 20's merged `InteropPort`, and the analytics stories (24.2, 24.10 to 24.14) extend its `AnalyticsPort`.
- 24.6 and 24.7 come in under the run-code exception that 24.5 established. The consoles rely on Epic 21's guarded stores (21.30, 21.33, 21.35).
- 24.9 builds on 24.8's same-instance diff. An entry routed to 24.15 asks that its default-settings read feed environment diff per namespace.
- 24.20 to 24.23 complete the 28-tool set that 24.4 started.
