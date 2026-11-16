# Epic 24 Context: Stage 5, second lane - interoperability, analytics, developer tools and the agent's harvested tools

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

This epic is the share of Stage 5 (custom-REST parity built from harvested MCP-suite handler bodies) that runs on slot B beside Epic 21. It covers the remaining interoperability surfaces, the analytics editors Epic 20 left out, a developer-tools set, and the last two steps of the agent's growth: the 28 harvested interoperability inspection tools, and undo by snapshot and revert. No story depends on one Epic 21 still holds. Stories 24.1 to 24.4 are done; their remaining surfaces were split into Stories 24.5 to 24.23. The next story is 24.5, which extends 24.1's `DevToolPort`.

## Stories

- Story 24.1: Developer tools: code metrics and document hashes (done)
- Story 24.2: The analytics editors: the term-list editor (done)
- Story 24.3: Interoperability parity: auto-start, shutdown groups and eight Epic 20 cleanup fixes (done)
- Story 24.4: The agent gains the harvested tools: the fourteen session and message reads (done)
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

- **One contract per screen (Epic 21's preamble, unchanged).** One descriptor, one port; the read tool and the write tools' field lists derive from the descriptor. Every write is a server-minted proposal with an instance-computed diff, an explicit confirmation and an agent audit marker. A story is accepted on that contract plus each row "round-trips over its backing class".
- **Governance.** Every new write key joins the baseline in its story; every new destructive key ships `false` and is named destructive. Read-only surfaces add no key.
- **Harvest cautions.** Take handler bodies only, and read the current body first. Rename every harvested token, comments included; the ObjectScript checker refuses the siblings' names, globals (`^UnitTestRoot` becomes an `^OcuPilot*` global in the protected database), output markers, the `iris_` prefix and `IRIS_*` variables. Where a body cannot do what the classic page does, extend the port and never edit the body.
- **Secrets and paths.** No credential reaches a screen or a log. No caller value is concatenated into SQL. No endpoint takes a filesystem path.
- **24.5:** each surface round-trips over its backing class (the MCP suite's `%UnitTest` run body is the runner's source). A runner that starts `%UnitTest` runs on the instance should allow one run in flight at a time, since concurrent runs have corrupted a shared instance here (inference).
- **24.6:** the execute-command console's output is capped by the harvested output ceiling (32,768 characters).
- **24.8 and 24.9 (owner answer U-45):** diff and promote work between namespaces of the same instance only; remote profiles go to the exclusion register, amended at 24.8's plan. Promote keeps its four gates (plan, execute-with-confirm, steps allow-list, plan-hash freshness), has no rollback, and the screen says so.
- **24.13 (owner answer U-34) carries DW-2518:** a partly applied cube build or synchronize is audited as a failed configuration change naming the steps applied; the AD-15 sentence is added at its spec gate.
- **24.15:** credentials carry a secret (AD-35, AD-56). **24.19:** identify the hidden EnsPortal pages' backing classes on the instance first; deployment writes log and rollback files, and its history offers rollback and delete.
- **24.20 (owner answer U-72, A):** the undo AD proposed in 24.4's spec is accepted as written and goes into the spine at 24.20's spec gate, settling the Deferred row. Vetoes under U-67 stand.
- **24.21 to 24.23:** `get_production_config_item` needs the settings read's secret masking; `explain_error`'s text names the sibling and is rewritten; 24.22's caller regular expression needs a bound; 24.23's `save` mode writes a per-user store, and its plan decides whether that is a write tool.

## Technical Decisions

- **Harvest seam (AD-23).** Bodies inherit `OcuPilot.Port.Harvest.Handler` and run only through `HarvestPort.Invoke` from one area port, which validates shape, refuses wide input and applies cost caps first (count, then refuse over the cap; never truncate after the scan). A new body adds its `HARVEST_CALLERS` row and a `PortGate` `<body>` row. Namespace switches save and restore (AD-16).
- **`DevToolPort` (24.1; 24.5 and 24.6 add endpoints).** The only caller of its bodies. Before any body runs it checks, in order: `AtelierPort.Pairs()`, the namespace's shape, `AtelierPort.NamespacePairs(ns)`, the input's shape, the wide-input rule, then the count cap; it passes the full pair set to `HarvestPort`. It sends a body only the query keys it built itself, and references `AtelierPort`'s refusal reasons rather than copying them. Caller SQL never goes through Atelier's `action/query` (AD-61). It is built under AD-29's rule without amending its Binds.
- **`InteropPort` (AD-62)** alone reads and writes production configuration: endpoint pairs, then namespace shape (409 `INTEROP.NAMESPACE`), then the classic page's resource plus database privilege; vendor calls only, and a silent vendor no-op is refused by name. Vendor editors load in a same-origin frame (AD-63).
- **`AnalyticsPort` (AD-65)** gates before any vendor call, checks WRITE on the database the target global maps to, runs multi-call writes in one transaction with no audit, job or I/O inside, and refuses an unjournaled database.
- **Write model.** Single-use, fingerprinted, expiring proposal (AD-6, AD-34); complete merged body over a port-composed read (AD-4, AD-51, AD-56); screen action and agent write are one operation (AD-53); read-back (AD-58); one change event (AD-14); prohibited review in the kernel only, including the protected-global arm (AD-10); script form for every write tool (AD-59); OcuPilot's own `ConfigChange` where the vendor audits nothing (AD-15). Dry-run then confirm for purge and promote; a count over the cap is refused.
- **Reads (AD-36, AD-5, AD-24, AD-44).** A screen and its tool share one capped read that reports truncation; screens are namespace-scoped; each descriptor names the classic page it replaces, or `""`.
- **Harvested agent tools (24.4's pattern).** Take the sibling's rules and query, never its classes or names. Each tool is a declaration over one abstract base (`InteropInspect`), declares `KIND` at definition time and passes `Governance.Gate.Decide` once; `PrivilegePairs` answers its endpoints' pairs. No `DESCRIPTORCLASS` (reached through `shell.tools.find`). Names must pass `TOOLNAMEPATTERN`. Windowed searches take `hours` back from `endDateTime`, never an open range; keyed lookups lead on an indexed column; every read is capped by `maxRows` and reports `truncated`. No caller namespace, `%session`, `%request` or `$NAMESPACE`.
- **Undo (accepted AD, written at 24.20).** Only a write tool that declares `UNDO` (`self` or a non-destructive inverse on the same port) is revertible; never a delete, a destructive tool, a secret-carrying tool or a started write. The confirm stores the verified fresh read's ordinary fields before the port write and the after-digest after read-back, in `Kernel/State/Snapshot` (24 hours, 200 per user, only the confirming user reverts). A revert re-reads through the inverse's port; a moved target is `UNDO.TARGETCHANGED`, and otherwise an ordinary proposal is minted and confirmed, its marker carrying `reverts`. Only agent confirms take snapshots.
- **Waiting for the owner's attended architecture update (never edit them):** `DevToolPort` in AD-29's Binds; the AD clauses 24.2 to 24.4 proposed (24.4's AD-62 session-reads item and AD-36 sentence are not in the spine yet); AD-66's "promote, Story 24.1" now meaning 24.9.
- **Open questions:** DW-2597 (agent mint answers a rule refusal as `TOOL.ARGUMENTS`); DW-2616 (sentence-shaped empty-state phrases); DW-2629 (a port criterion refusal reaches the model as a bare `PORT.VALIDATION`).

## UX & Interaction Patterns

- The proposal card shows target, before/after rows, an "N unchanged fields" fold, rationale, impact and a "Reverse:" line where a reversal exists; undo builds on it. A delete has neither after-state nor "Reverse:".
- A destructive action uses the typed-name confirm, ending "This cannot be undone." where true.
- Developer tools sit in System Explorer and extend 24.1's `dev-tool.page.ts` and store. Per-production settings go on Productions as row actions with a dialog.
- An empty-state agent string is a lowercase action phrase, never a sentence. New strings go into EXPERIENCE.md's Fixed strings.

## Cross-Story Dependencies

- Run order: 24.5 to 24.9, 24.10 to 24.14, 24.15 to 24.19, then 24.20 to 24.23 (inference from the split numbering); 24.9 follows 24.8.
- 24.5 and 24.6 extend `DevToolPort`; 24.8 may reuse 24.1's hashes (inference). 24.10 to 24.14 extend 24.2's term-list tools and `AnalyticsPort`; 24.15 to 24.19 extend 24.3's `InteropPort` work.
- 24.20 consumes the proposal kernel (`Confirm`, `Mint`); its first declaring writes include 24.2's term-list writes and 24.3's auto-start and shutdown-group writes. 24.21 builds on `InteropInspect`; 24.22 reuses `ListSessions`' window and the contents rendering.
- Epic 21 runs on slot A (21.2 to 21.4 merged). Shared rosters, counts and registry lists (`Test/ReadTool.cls`, `PortGate`, `Screen/Read.cls` and `Registry.cls` source lines, `Navigation`, `InteropFloor`, `ToolRoundTrip`) take append-only edits, unioned at integrate-forward, with counts re-derived and a mutation that reddens each count. Check each against `origin/OCU-1-epic21` before editing; anything beyond an append needs the orchestrator's ruling. Never take Epic 21's stories.
