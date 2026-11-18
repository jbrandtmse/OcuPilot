# Epic 24 Context: Stage 5, second lane - interoperability, analytics, developer tools and the agent's harvested tools

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Epic 24 was split from Epic 21 (Stage 5, custom-REST parity) so that a second slot can run it beside Epic 21. It takes the remaining classic-portal leaves that have a backing class but no route: the rest of the interoperability area, the analytics editors the Epic 20 rider left out, and a developer-tools set harvested from the MCP suite. It also grows the agent: the 28 inspection tools harvested from iris-session-agent, and undo by snapshot and revert. Every surface is built under the same staged-delivery contract as earlier stages, so the product reaches parity without a second way of building a screen, a tool or a write.

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

- **The staged-delivery contract governs every story.** Acceptance is that contract plus each catalog row's own backing class, and each surface must round-trip over that class. Every new screen is declared by exactly one screen descriptor and reaches outside OcuPilot through exactly one port. Its read tool and its write tools' field lists derive from that descriptor, never from hand-written tool code. The agent gains its read tool and its confirmed write tool in the same story as the screen.
- **Every write is a confirmed proposal**: server-minted, with a diff computed on the instance, an explicit confirmation and an agent audit marker. A confirmed write reads its target back and reports whether the instance holds what was sent.
- **Governance:** each new write key joins the governance baseline in the story that ships it, enabled unless the story sets it disabled. **Every new destructive key defaults to disabled.** A mutating key absent from the baseline is disabled.
- **Harvest discipline:** take handler bodies and nothing else. The MCP suite's manifest is stale and its bootstrap is TypeScript-driven. Read the current body before harvesting it, because two known defects (the task-history filter, and creating a resource with a description) have unverified fix status.
- **Single instance only.** No request leaves the instance except to the configured LLM provider. OcuPilot manages only the instance that serves it, so environment diff and promote work between namespaces of this instance only. Remote instance profiles and the work-queue viewer are recorded in the exclusion register as not planned, each with its stated reason.
- The interface stays English. Every confirmation names its consequence in plain words.

## Technical Decisions

- **Harvest seam.** Harvested `ExecuteMCPv2.REST.*` bodies inherit an OcuPilot base that exposes `RenderResponseBody(pStatus, pMsgPart, pResPart)` and emits OcuPilot's single error/response envelope. Only the base class changes, and a body is never edited to change response shape. The no-double-envelope assertion must keep passing. The seam (Story 21.1) is already on the feature branch. An open ledger item (from 21.2) notes that nothing yet polices harvested body classes past the harvest port's gate.
- **Ports and gates.** Interoperability work goes through `InteropPort`, which calls `Ens.Director` and the configuration classes in process behind its own gate. Analytics goes through `AnalyticsPort`, which calls `%DeepSee` classes in process, never `/api/deepsee`, and uses only reads measured to write nothing. Source and document work goes through `AtelierPort`. Each port checks its own resource/permission pairs at call time, before any vendor call. The vendor's checks are a lower bound, not the whole requirement. Switch namespaces by explicit save and restore, and never with `New $NAMESPACE`. No caller value is ever concatenated into SQL, and no endpoint accepts a path.
- **Run-code exception** (Stories 24.5 to 24.7): the unit-test runner, the command and class-method consoles and the web terminal run code with the signed-in person's rights, under three rules:
  - The tool is a person's alone. It declares `PERSONGATE` and is unadvertised. A call the agent can reach is refused `PROHIBITED.PERSONONLY`, and the tool has no mint, no proposal card and no copy-out draft.
  - It is off by default. Its governance key ships `false` and is asked by `POST /screens/:screen/action`.
  - Every run passes a confirmation that names its consequence.

  Shipped keys: `explorer.unittests.run`, `explorer.command.run` and `explorer.classmethod.run`. The port refuses a target in an `OcuPilot` package, or a command that names OcuPilot in any letter case. Console output, return values, by-reference values and error text reach the screen only, as text. They never reach the model, a tool result, a ledger row, an audit payload, a log line or screen context. Console output is bounded by the harvested output ceiling. Each console run records OcuPilot's own `SecurityChange` row: the console, the namespace and, for a class method, the class and method, never the command, the arguments or the answer. A unit-test run records no vendor audit event, which is a named gap.
- **Harvested agent tools (28).** Each tool declares `read` or `write` at definition time and passes the single call-time gate. They come from iris-session-agent, where all 28 are non-mutating and Ens-specific. Take the rules, not the mechanism:
  - Use the locked JSON-Schema subset, with no `$ref`, `oneOf`, `anyOf`, `allOf` or `pattern`.
  - Tools never touch `%session`, `%request` or `$NAMESPACE` directly.
  - Rename everything into OcuPilot's own names, including the `iris_` prefix.
  - Tool results and log text reach the model only through the sanitizer, and an agent read tool never executes code.
- **Undo (24.20).** Capture a snapshot before the write and offer a one-click revert. The revert is itself a confirmed proposal with its own diff and audit marker. Undo is deferred to Stage 5 because the write path has no state-capture model, so the model is designed here and not retrofitted.
- **Promote (24.9)** keeps its four-gate model: plan, execute-with-confirm, a steps allow-list, and plan-hash freshness. It states that there is no rollback. The harvested "promote" guided workflow stays empty until this tool exists. Any workflow is a catalog entry, and every write in it is one confirmed proposal.
- **Deployment (24.19)** produces its log and rollback files, and the deployment history offers rollback and delete.
- **Interoperability writes** are identified by `[Production, Name]` and never by the vendor's integer id. A namespace under source control refuses item writes. Production stop, restart and update are capped at 15 s and never call clean.

## UX & Interaction Patterns

- Each confirm dialog states the write's consequence. A destructive confirm says "This cannot be undone" where that applies. All copy goes in the experience spec's copy tables.
- Run-code screens draw their action off with the key's refusal sentence while the governance key is disabled.
- List screens and their read tools share one bounded, declared read that reports when it truncated.

## Cross-Story Dependencies

- Every story harvests through Story 21.1's seam, which is on the feature branch. No story depends on a story Epic 21 still holds.
- The interoperability stories (24.3, 24.15 to 24.19) and the analytics stories (24.2, 24.10 to 24.14) extend Epic 20's merged `InteropPort` and `AnalyticsPort`. 24.10 builds on 24.2's term-list editor.
- 24.6 and 24.7 come in under the run-code exception that 24.5 established. The consoles also rely on Story 21.30's guarded stores to keep OcuPilot's protected state refused to non-administrators.
- 24.9 depends on 24.8, which supplies the same-instance environment diff. One ledger entry asks 24.15's default-settings read to feed environment diff per namespace.
- 24.20 to 24.23 complete the 28-tool set that 24.4 started.
