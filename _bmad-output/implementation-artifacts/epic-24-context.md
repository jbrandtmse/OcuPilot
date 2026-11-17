# Epic 24 Context: Stage 5, second lane - interoperability, analytics, developer tools and the agent's harvested tools

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

This epic is the share of Stage 5 (custom-REST parity built from harvested MCP-suite handler bodies) that runs on slot B beside Epic 21: the remaining interoperability surfaces, the analytics editors Epic 20 left out, a developer-tools set, and for the agent the 28 harvested inspection tools plus undo by snapshot and revert. No story depends on one Epic 21 still holds. Stories 24.1 to 24.6 and 24.8 to 24.10 are done. Story 24.7, the web terminal, is parked at plan (U-104): its backing class, the vendor's Atelier v7 terminal WebSocket, cannot be reached under the spine as it stands, and its scope is the owner's call. The next story is 24.11; the analytics stories (24.11 to 24.14) come before the interoperability (24.15 to 24.19) and agent-tool (24.20 to 24.23) stories.

## Stories

- Story 24.1: Developer tools: code metrics and document hashes (done)
- Story 24.2: The analytics editors: the term-list editor (done)
- Story 24.3: Interoperability parity: auto-start, shutdown groups and Epic 20 cleanup fixes (done)
- Story 24.4: The agent gains the harvested tools: the fourteen session and message reads (done)
- Story 24.5: Unit-test runner and its run record; work-queue viewer not planned (done)
- Story 24.6: The command and class-method consoles (done)
- Story 24.7: Web terminal (parked, owner's call)
- Story 24.8: Environment diff, same instance only; remote profiles not planned (done)
- Story 24.9: Environment promote, same instance only (done)
- Story 24.10: Folder manager transfer and term-list import, export and copy (done)
- Story 24.11: Listing groups (next)
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
- **Secrets and paths.** No credential reaches a screen or a log; no caller value is concatenated into SQL; no endpoint takes a filesystem path. A file transfer uses the existing server-file case only: an overwriting export whose directory must exist, an import read as text up to the 3,000,000-character transfer bound (larger is refused), and a local file's name and content as screen values, never in a tool's schema.
- **Analytics writes (24.10's precedent for 24.11 to 24.14).** Gate before any vendor call: the screen's pairs, the namespace's shape, analytics on, then the vendor's own resource checks; an item the caller cannot see is absent. A write needs WRITE on the database its vendor global maps to, read-write and journaled, refused by name otherwise. An import parses the file side-effect free before writing, is create-only (a held name refused before any write), re-reads the file at the write and refuses a moved digest, and writes inside one transaction rolled back on failure. Never load or compile through `$system.OBJ`, and never call a vendor read not measured to write nothing. Each write records OcuPilot's own `ConfigChange` row.
- **Later stories.** 24.13 carries DW-2518 (a vendor cube build that ran then failed records no change row) with its audit sentence at the spec gate (U-34); 24.15 carries a secret and DW-2636 (environment diff gains a per-namespace default-settings comparison); 24.19's deployment produces log and rollback files and its history offers rollback and delete; 24.20 writes the undo decision into the spine at its spec gate (U-72): snapshot before the write, revert as its own confirmed proposal with its own diff and audit marker, the state-capture model designed here rather than retrofitted.

## Technical Decisions

- **Harvest seam (AD-23).** Bodies inherit `OcuPilot.Port.Harvest.Handler` and run only through `HarvestPort.Invoke` from one area port, which validates shape, refuses wide input and applies cost caps first (count, then refuse over the cap; never truncate after the scan). A new body adds its `HARVEST_CALLERS` row and a `PortGate` `<body>` row. Namespace switches save and restore (AD-16).
- **`AnalyticsPort` (AD-65)** calls the vendor's `%DeepSee` classes in process as the signed-in person, never `/api/deepsee`; it refuses a namespace without analytics (`ANALYTICS.NAMESPACE`) and never calls `%GetMemberTree`, `%GetDimensionMembers` or `%GetFavoritesForUser`. **`InteropPort` (AD-62)** alone reads and writes production configuration, default settings included, with no compile-time dependency on interoperability classes. **`DevToolPort`** is the only caller of the developer-tool bodies; it is not yet in AD-29's Binds, which is the owner's attended update, never edited here.
- **Write model.** Single-use, fingerprinted, expiring proposal (AD-6, AD-34); complete merged body over a port-composed read (AD-4, AD-51, AD-56); a create fingerprints the target's absence (AD-54); screen action and agent write are one operation (AD-53); read-back (AD-58); one change event (AD-14); prohibited review in the kernel only (AD-10); script form for every write tool (AD-59); OcuPilot's own `ConfigChange` where the vendor audits nothing (AD-15). Server refusals are shown as the server sent them (AD-39).
- **Reads (AD-36, AD-5, AD-24, AD-44).** A screen and its tool share one capped read that reports truncation; screens are namespace-scoped; each descriptor names the classic page it replaces, or `""`.
- **Harvested agent tools (24.4's pattern).** Take the sibling's rules and query, never its classes or names; each tool is a declaration over `InteropInspect` that declares `KIND` and passes `Governance.Gate.Decide` once.

## UX & Interaction Patterns

- The proposal card shows target, before/after rows, an "N unchanged fields" fold, rationale, impact and a "Reverse:" line where a reversal exists. A destructive action uses the typed-name confirm, ending "This cannot be undone from OcuPilot." where true.
- Transfers reuse the published words Export and Import, to a server file or to this browser; an applied write leaves a status line on the screen ("Exported <name>.", "Imported <name>.").
- An empty-state agent string is a lowercase action phrase completing "Or ask the agent: ...", never a sentence. Every new label, help line, refusal and status line goes into EXPERIENCE.md's Fixed strings in its story.

## Cross-Story Dependencies

- 24.11 to 24.14 extend 24.2's and 24.10's `AnalyticsPort` work (the term-list and folder-item tools, transfer helpers and the generalized write admit); 24.15 to 24.19 extend 24.3's `InteropPort` work; 24.19's deployment follows 24.9's promote pattern (plan, execute-with-confirm, a steps allow-list, plan-hash freshness).
- 24.20 consumes the proposal kernel (`Confirm`, `Mint`); its first declaring writes include 24.2's, 24.3's and 24.10's. 24.21 builds on `InteropInspect`; 24.22 reuses `ListSessions`' window.
- Epic 21 runs on slot A, most of its stories still ready-for-dev. Shared rosters, counts and registries (`Test/ReadTool.cls`, `PortGate`, `Screen/Read.cls`, `Registry.cls`, `Navigation`, `ToolRoundTrip`, the governance baseline, the exclusion register) take append-only edits, unioned at integrate-forward with counts re-derived. Check each against `origin/OCU-1-epic21` before editing; never take Epic 21's stories.
