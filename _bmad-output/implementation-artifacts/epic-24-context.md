# Epic 24 Context: Stage 5, second lane - interoperability, analytics, developer tools and the agent's harvested tools

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

This epic is the share of Stage 5 (custom-REST parity built from harvested MCP-suite handler bodies) that runs on slot B beside Epic 21: the remaining interoperability surfaces, the analytics editors Epic 20 left out, a developer-tools set, and the agent's 28 harvested inspection tools with undo by snapshot and revert. No story depends on one Epic 21 still holds. Stories 24.1 to 24.4 and 24.8 are done, and 24.6 and 24.7 are parked. The next story is the re-plan of 24.5, which the owner amended to the unit-test runner plus its own run record.

## Stories

- Story 24.1: Developer tools: code metrics and document hashes (done)
- Story 24.2: The analytics editors: the term-list editor (done)
- Story 24.3: Interoperability parity: auto-start, shutdown groups and Epic 20 cleanup fixes (done)
- Story 24.4: The agent gains the harvested tools: the fourteen session and message reads (done)
- Story 24.5: Unit-test runner and its run record (re-plan; work-queue viewer not planned, U-77)
- Story 24.6: The command and class-method consoles (parked until the DW-2634 fix reaches feature, U-78)
- Story 24.7: Web terminal (parked, same as 24.6)
- Story 24.8: Compare namespaces, documents only (done)
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

- **One contract per screen (Epic 21's preamble, unchanged).** One descriptor, one port; the read tool and the write tools' field lists derive from the descriptor. Every write is a server-minted proposal with an instance-computed diff, an explicit confirmation and an agent audit marker. Acceptance is that contract plus each row "round-trips over its backing class". Handler bodies are taken and nothing else; read the current body before harvesting.
- **Governance.** Every new write key joins the baseline in its story; every new destructive key ships `false` and is named destructive. Read-only surfaces add no key.
- **Harvest cautions.** Rename every harvested token, comments included; the ObjectScript checker refuses the siblings' names, globals (`^UnitTestRoot` among them), output markers, the `iris_` prefix and `IRIS_*` variables. Where a body cannot do what the page needs, extend the port, never edit the body.
- **Secrets and paths.** No credential reaches a screen or a log; no caller value is concatenated into SQL; no endpoint takes a filesystem path.
- **24.5 (owner answer U-77, A).** The run record is a read-only list of this namespace's `%UnitTest` runs (`%UnitTest_Result` instances, with each run's methods and failure messages), backed by those classes, with no key. The work-queue viewer (catalog DT-03) goes to the exclusion register as not planned, with the reason the AC states: the instance-wide queue records no owner, a read consumes another client's result, and nothing lists it. The register test holds the catalog's P4 rows, the stage extract and the register equal, so DT-03 moves in all three in one change with totals re-derived (24.8's DT-11 precedent). The runner never touches the Atelier `work` routes (AD-61 rule 7 stands); it runs `%UnitTest` in process.
- **24.5 runner shape from the first plan (reversible, to confirm).** A run executes test code as the user, so it is a destructive write with key `explorer.unittests.run` defaulting `false`, on `ExplorerSqlRun`'s model. One run in flight (409 otherwise), no cancel, and a run past the Web Gateway timeout loses its answer (named limit, AD-7). A `%UnitTest.TestProduction` class needs the production guard or a refusal. Measure first whether a `/noload` run needs a test root global.
- **24.9 is same-instance only (U-45).** Promote moves between two namespaces of this instance, keeps its four gates (plan, execute-with-confirm, steps allow-list, plan-hash freshness), and has no rollback, which the screen says.
- **Later stories.** 24.13 carries DW-2518; 24.15 carries a secret (AD-35, AD-56) and DW-2636; 24.20 (U-72, A) writes the undo AD into the spine at its spec gate.
- **Not Epic 24's:** DW-2634 (guarded storage methods take OcuPilot's protected role for any caller) is with the owner; do not fix it here.

## Technical Decisions

- **Harvest seam (AD-23).** Bodies inherit `OcuPilot.Port.Harvest.Handler` and run only through `HarvestPort.Invoke` from one area port, which validates shape, refuses wide input and applies cost caps first (count, then refuse over the cap; never truncate after the scan). A new body adds its `HARVEST_CALLERS` row and a `PortGate` `<body>` row. Namespace switches save and restore (AD-16).
- **`DevToolPort` (24.1, extended by 24.8).** The only caller of the developer-tool bodies, behind `AtelierPort`'s pairs. It checks the pairs, the namespace's shape and pairs, the input's shape, the wide-input rule, then the count cap, before any body runs; it sends a body only keys it built and references `AtelierPort`'s refusal reasons. Caller SQL never goes through Atelier's `action/query` (AD-61). A two-namespace operation passes each namespace's gate.
- **`InteropPort` (AD-62)** alone reads and writes production configuration, default settings included; **`AnalyticsPort` (AD-65)** gates before any vendor call, checks WRITE on the target global's database, and runs multi-call writes in one transaction with no audit, job or I/O inside.
- **Write model.** Single-use, fingerprinted, expiring proposal (AD-6, AD-34); complete merged body over a port-composed read (AD-4, AD-51, AD-56); screen action and agent write are one operation (AD-53); read-back (AD-58); one change event (AD-14); prohibited review in the kernel only (AD-10); script form for every write tool (AD-59); OcuPilot's own `ConfigChange` where the vendor audits nothing (AD-15).
- **Reads (AD-36, AD-5, AD-24, AD-44).** A screen and its tool share one capped read that reports truncation; screens are namespace-scoped; each descriptor names the classic page it replaces, or `""`.
- **Harvested agent tools (24.4's pattern).** Take the sibling's rules and query, never its classes or names; each tool is a declaration over `InteropInspect` that declares `KIND` and passes `Governance.Gate.Decide` once.
- **Waiting for the owner's attended architecture update (never edit them):** `DevToolPort` in AD-29's Binds; the AD clauses 24.2 to 24.4 proposed; AD-66's "promote, Story 24.1" meaning 24.9.

## UX & Interaction Patterns

- The proposal card shows target, before/after rows, an "N unchanged fields" fold, rationale, impact and a "Reverse:" line where a reversal exists. A destructive action uses the typed-name confirm, ending "This cannot be undone." where true.
- Developer tools sit in System Explorer and extend 24.1's `dev-tool.page.ts` and store. Per-production settings go on Productions as row actions with a dialog.
- An empty-state agent string is a lowercase action phrase, never a sentence. New strings go into EXPERIENCE.md's Fixed strings.

## Cross-Story Dependencies

- 24.5's tests never start a `%UnitTest` run inside the suite's own run: gating is pinned dry through 24.1's recorder seam, and the real round trip runs only from a browser spec on `ocupilot-b-ci`.
- 24.6 and 24.7 resume as a named AD-10 exception once the DW-2634 fix story reaches feature (U-78, C).
- 24.9 follows 24.8 and reuses its namespace pair; 24.8 compared documents only, the default-settings comparison went to 24.15 and mappings to the burn-down. 24.19's deployment follows the same promote pattern (four gates, log and rollback files). 24.10 to 24.14 extend 24.2's term-list tools and `AnalyticsPort`; 24.15 to 24.19 extend 24.3's `InteropPort` work.
- 24.20 consumes the proposal kernel (`Confirm`, `Mint`); its first declaring writes include 24.2's and 24.3's. 24.21 builds on `InteropInspect`; 24.22 reuses `ListSessions`' window.
- Epic 21 runs on slot A; its 21.24 (the config-settings fix) is merged into this branch. Shared rosters, counts and registries (`Test/ReadTool.cls`, `PortGate`, `Screen/Read.cls`, `Registry.cls`, `Navigation`, `ToolRoundTrip`, the governance baseline, the exclusion register) take append-only edits, unioned at integrate-forward with counts re-derived. Check each against `origin/OCU-1-epic21` before editing; never take Epic 21's stories.
