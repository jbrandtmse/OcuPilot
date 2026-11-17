# Epic 24 Context: Stage 5, second lane - interoperability, analytics, developer tools and the agent's harvested tools

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

This epic is the share of Stage 5 (custom-REST parity built from harvested MCP-suite handler bodies) that runs on slot B beside Epic 21: the remaining interoperability surfaces, the analytics editors Epic 20 left out, a developer-tools set, and for the agent the 28 harvested inspection tools plus undo by snapshot and revert. No story depends on one Epic 21 still holds. Stories 24.1 to 24.6, 24.8 and 24.9 are done. The next story is 24.7, the web terminal, which the owner unparked (U-78) to come in under the same run-code exception as 24.5's runner and 24.6's consoles; the analytics, interoperability and agent-tool stories follow.

## Stories

- Story 24.1: Developer tools: code metrics and document hashes (done)
- Story 24.2: The analytics editors: the term-list editor (done)
- Story 24.3: Interoperability parity: auto-start, shutdown groups and Epic 20 cleanup fixes (done)
- Story 24.4: The agent gains the harvested tools: the fourteen session and message reads (done)
- Story 24.5: Unit-test runner and its run record; work-queue viewer not planned (done)
- Story 24.6: The command and class-method consoles (done)
- Story 24.7: Web terminal (next)
- Story 24.8: Environment diff, same instance only; remote profiles not planned (done)
- Story 24.9: Environment promote, same instance only (done)
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

- **One contract per screen (Epic 21's preamble, unchanged).** Acceptance is the parity contract plus each row "round-trips over its backing class". Every write is a confirmed proposal; every new destructive key defaults to disabled. Handler bodies are taken and nothing else (the suite's manifest is stale, its bootstrap TypeScript-driven); read the current body before harvesting.
- **Governance.** Every new write key joins the baseline in its story; every new destructive key ships `false`. Read-only surfaces add no key.
- **Harvest cautions.** Rename every harvested token, comments included; the ObjectScript checker refuses the siblings' names, globals, output markers, the `iris_` prefix and `IRIS_*` variables. Where a body cannot do what the page needs, extend the port, never edit the body.
- **Secrets and paths.** No credential reaches a screen or a log; no caller value is concatenated into SQL; no endpoint takes a filesystem path.
- **Run-code exception (24.7, as 24.5 and 24.6).** Code a person runs through OcuPilot is a named exception held to three rules: it is a person's alone (the tool declares `PERSONGATE`, is unadvertised, and any call the agent can reach is refused `PROHIBITED.PERSONONLY`); it is off by default (only the screen action route asks its governance key, after the screen's pairs and before the hold and fresh read, refusing 403 with the tool's code; the key ships `false`); and every run passes a confirmation naming its consequence. No mint, no proposal card, no copy-out draft. Input naming OcuPilot in any letter case, or a class in an `OcuPilot` package, is refused by the port as a screen, not a prohibition. OcuPilot's protected state stays refused to non-administrators by its guarded stores (Story 21.30, U-79), which are the last gate.
- **24.6's precedents for 24.7.** A console run's output, return value and error text reach the screen only, as text, never the model, a tool result, a ledger row, an audit payload, a log line or screen context (AD-39's eighth exception; 24.7 needs the same, written into the spine at its gate (inference)). Each run records OcuPilot's own `SecurityChange` row naming the console and namespace, never the command or the answer. Output is bounded by the harvested output ceiling.
- **Later stories.** 24.13 carries DW-2518 (a vendor cube build that ran then failed records no change row) with its AD-15 sentence at the spec gate (U-34); 24.15 carries a secret (AD-35, AD-56) and DW-2636 (environment diff gains a per-namespace default-settings comparison); 24.19's deployment produces log and rollback files and its history offers rollback and delete; 24.20 writes the undo AD into the spine at its spec gate (U-72): snapshot before the write, revert as its own confirmed proposal with its own diff and audit marker.

## Technical Decisions

- **Harvest seam (AD-23).** Bodies inherit `OcuPilot.Port.Harvest.Handler` and run only through `HarvestPort.Invoke` from one area port, which validates shape, refuses wide input and applies cost caps first (count, then refuse over the cap; never truncate after the scan). A new body adds its `HARVEST_CALLERS` row and a `PortGate` `<body>` row. Namespace switches save and restore (AD-16).
- **`DevToolPort` (24.1, extended since).** The only caller of the developer-tool bodies, behind `AtelierPort`'s pairs; checks pairs, namespace shape, input shape, the wide-input rule and the count cap before any body runs. Caller SQL never goes through Atelier's `action/query`, and the Atelier `work` routes are never used (AD-61). It is not yet in AD-29's Binds: that is the owner's attended architecture update; never edit it.
- **`InteropPort` (AD-62)** alone reads and writes production configuration, default settings included; **`AnalyticsPort` (AD-65)** gates before any vendor call, checks WRITE on the target global's database, and runs multi-call writes in one transaction with no audit, job or I/O inside.
- **Write model.** Single-use, fingerprinted, expiring proposal (AD-6, AD-34); complete merged body over a port-composed read (AD-4, AD-51, AD-56); screen action and agent write are one operation (AD-53); read-back (AD-58); one change event (AD-14); prohibited review in the kernel only (AD-10); script form for every write tool (AD-59); OcuPilot's own `ConfigChange` where the vendor audits nothing (AD-15). Each write finishes in its own request; a run past the Web Gateway timeout loses its answer, a named limit (AD-7).
- **Reads (AD-36, AD-5, AD-24, AD-44).** A screen and its tool share one capped read that reports truncation; screens are namespace-scoped; each descriptor names the classic page it replaces, or `""`.
- **Harvested agent tools (24.4's pattern).** Take the sibling's rules and query, never its classes or names; each tool is a declaration over `InteropInspect` that declares `KIND` and passes `Governance.Gate.Decide` once.

## UX & Interaction Patterns

- The proposal card shows target, before/after rows, an "N unchanged fields" fold, rationale, impact and a "Reverse:" line where a reversal exists. A destructive action uses the typed-name confirm, ending "This cannot be undone." where true.
- Developer tools sit in System Explorer and extend 24.1's `dev-tool.page.ts` and store. Per-production settings go on Productions as row actions with a dialog.
- An empty-state agent string is a lowercase action phrase, never a sentence. New strings go into EXPERIENCE.md's Fixed strings.

## Cross-Story Dependencies

- 24.7 builds on 24.6's console key gate, confirmation, audit row and screen-only output path (inference). 24.5's tests never started a `%UnitTest` run inside the suite's own run (gating pinned dry through 24.1's recorder seam, the real round trip in a browser spec on `ocupilot-b-ci`); run-code tests keep that discipline.
- 24.10 to 24.14 extend 24.2's term-list tools and `AnalyticsPort`; 24.15 to 24.19 extend 24.3's `InteropPort` work; 24.19's deployment follows 24.9's promote pattern (four gates).
- 24.20 consumes the proposal kernel (`Confirm`, `Mint`); its first declaring writes include 24.2's and 24.3's. 24.21 builds on `InteropInspect`; 24.22 reuses `ListSessions`' window.
- Epic 21 runs on slot A. Shared rosters, counts and registries (`Test/ReadTool.cls`, `PortGate`, `Screen/Read.cls`, `Registry.cls`, `Navigation`, `ToolRoundTrip`, the governance baseline, the exclusion register) take append-only edits, unioned at integrate-forward with counts re-derived. Check each against `origin/OCU-1-epic21` before editing; never take Epic 21's stories.
