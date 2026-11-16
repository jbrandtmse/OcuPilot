# Epic 24 Context: Stage 5, second lane - interoperability, analytics, developer tools and the agent's harvested tools

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

This epic is the share of Stage 5 (custom-REST parity built from harvested MCP-suite handler bodies) that runs on slot B beside Epic 21. It covers the remaining interoperability surfaces, the analytics editors Epic 20 left out, a developer-tools set, and the last two steps of the agent's growth: the 28 harvested interoperability inspection tools, and undo by snapshot and revert. No story depends on one Epic 21 still holds. Stories 24.1 to 24.4 are done; 24.5 to 24.7 are parked on owner questions. The next story is 24.8, environment diff between namespaces of this instance, which also records remote instance profiles as not planned.

## Stories

- Story 24.1: Developer tools: code metrics and document hashes (done)
- Story 24.2: The analytics editors: the term-list editor (done)
- Story 24.3: Interoperability parity: auto-start, shutdown groups and Epic 20 cleanup fixes (done)
- Story 24.4: The agent gains the harvested tools: the fourteen session and message reads (done)
- Story 24.5: Unit-test runner and work-queue viewer (parked, U-77: the work-queue viewer against AD-61)
- Story 24.6: The command and class-method consoles (parked, U-78: consoles run arbitrary code, against AD-10)
- Story 24.7: Web terminal (parked, U-78, same question)
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

- **One contract per screen (Epic 21's preamble, unchanged).** One descriptor, one port; the read tool and the write tools' field lists derive from the descriptor. Every write is a server-minted proposal with an instance-computed diff, an explicit confirmation and an agent audit marker. Acceptance is that contract plus each row "round-trips over its backing class". Handler bodies are taken and nothing else; read the current body before harvesting.
- **Governance.** Every new write key joins the baseline in its story; every new destructive key ships `false` and is named destructive. Read-only surfaces add no key.
- **Harvest cautions.** Rename every harvested token, comments included; the ObjectScript checker refuses the siblings' names, globals, output markers, the `iris_` prefix and `IRIS_*` variables. Where a body cannot do what the page needs, extend the port, never edit the body.
- **Secrets and paths.** No credential reaches a screen or a log; no caller value is concatenated into SQL; no endpoint takes a filesystem path.
- **24.8 and 24.9 are same-instance only (owner answer U-45).** No request leaves the instance except to the configured provider; OcuPilot manages only the instance that serves it, and multi-instance management stays Not planned. Diff and promote compare and move between two namespaces of this instance. 24.8 keeps its title and key and records remote instance profiles in `docs/exclusion-register.md` as not planned, with that reason. The register is held equal to the feature catalog's P4 rows and the stage extract's last stage by `ui/tools/exclusion-register.test.mjs`, so the row (catalog DT-11, today P3) moves in all three in one change, with totals re-derived (inference from the register's own rule and the 21.12 precedent). The catalog's diff and promote rows (DT-09, DT-10) still say "between two instances" (inference: reword with them).
- **24.9:** promote keeps its four gates (plan, execute-with-confirm, steps allow-list, plan-hash freshness); it has no rollback, and the screen says so. Dry-run then confirm; a count over the cap is refused.
- **Later stories.** 24.13 (U-34) carries DW-2518: a partly applied cube build or synchronize is audited as a failed configuration change naming the steps applied. 24.15's credentials carry a secret (AD-35, AD-56). 24.19 identifies the hidden EnsPortal pages' backing classes on the instance first. 24.20 (U-72, A) writes the accepted undo AD into the spine at its spec gate. 24.21's configuration-item read needs the settings read's secret masking; 24.22's caller regular expression needs a bound; 24.23's `save` mode writes a per-user store.
- **Not Epic 24's:** DW-2634 (guarded storage methods take OcuPilot's protected role for any caller) is with the owner; do not fix it here.

## Technical Decisions

- **Harvest seam (AD-23).** Bodies inherit `OcuPilot.Port.Harvest.Handler` and run only through `HarvestPort.Invoke` from one area port, which validates shape, refuses wide input and applies cost caps first (count, then refuse over the cap; never truncate after the scan). A new body adds its `HARVEST_CALLERS` row and a `PortGate` `<body>` row. Namespace switches save and restore (AD-16).
- **`DevToolPort` (24.1).** The only caller of its bodies, behind `AtelierPort`'s pairs. Before any body runs it checks `AtelierPort.Pairs()`, the namespace's shape, `AtelierPort.NamespacePairs(ns)`, the input's shape, the wide-input rule, then the count cap. It sends a body only query keys it built, and references `AtelierPort`'s refusal reasons rather than copying them. Caller SQL never goes through Atelier's `action/query` (AD-61). 24.1's harvested document hashes (`EnvSync`) are the documents half of 24.8's diff (inference); a two-namespace diff passes each namespace's own gate (inference).
- **`InteropPort` (AD-62)** alone reads and writes production configuration (default settings included); **`AnalyticsPort` (AD-65)** gates before any vendor call, checks WRITE on the target global's database, and runs multi-call writes in one transaction with no audit, job or I/O inside.
- **Write model.** Single-use, fingerprinted, expiring proposal (AD-6, AD-34); complete merged body over a port-composed read (AD-4, AD-51, AD-56); screen action and agent write are one operation (AD-53); read-back (AD-58); one change event (AD-14); prohibited review in the kernel only (AD-10); script form for every write tool (AD-59); OcuPilot's own `ConfigChange` where the vendor audits nothing (AD-15).
- **Reads (AD-36, AD-5, AD-24, AD-44).** A screen and its tool share one capped read that reports truncation; screens are namespace-scoped; each descriptor names the classic page it replaces, or `""`.
- **Harvested agent tools (24.4's pattern).** Take the sibling's rules and query, never its classes or names. Each tool is a declaration over `InteropInspect`, declares `KIND`, passes `Governance.Gate.Decide` once, and answers its pairs; names pass `TOOLNAMEPATTERN`. Windowed searches take `hours` back from `endDateTime`; reads are capped by `maxRows` and report `truncated`.
- **Undo (24.20).** Only a write tool declaring `UNDO` is revertible, never a delete, destructive, secret-carrying or started write. The confirm snapshots the fresh read before the write and the digest after read-back (24 hours, 200 per user, confirming user only); a moved target is `UNDO.TARGETCHANGED`, otherwise an ordinary proposal is minted carrying `reverts`.
- **Waiting for the owner's attended architecture update (never edit them):** `DevToolPort` in AD-29's Binds; the AD clauses 24.2 to 24.4 proposed; AD-66's "promote, Story 24.1" meaning 24.9.

## UX & Interaction Patterns

- The proposal card shows target, before/after rows, an "N unchanged fields" fold, rationale, impact and a "Reverse:" line where a reversal exists. A destructive action uses the typed-name confirm, ending "This cannot be undone." where true.
- Developer tools sit in System Explorer and extend 24.1's `dev-tool.page.ts` and store. Per-production settings go on Productions as row actions with a dialog.
- An empty-state agent string is a lowercase action phrase, never a sentence. New strings go into EXPERIENCE.md's Fixed strings.

## Cross-Story Dependencies

- 24.9 follows 24.8 and reuses its namespace pair. 24.19's deployment follows the same promote pattern (four gates, log and rollback files). 24.10 to 24.14 extend 24.2's term-list tools and `AnalyticsPort`; 24.15 to 24.19 extend 24.3's `InteropPort` work.
- 24.20 consumes the proposal kernel (`Confirm`, `Mint`); its first declaring writes include 24.2's and 24.3's. 24.21 builds on `InteropInspect`; 24.22 reuses `ListSessions`' window.
- Epic 21 runs on slot A; its 21.24 carries the config-settings fix, and 24.3's staging waits for it. Shared rosters, counts and registries (`Test/ReadTool.cls`, `PortGate`, `Screen/Read.cls`, `Registry.cls`, `Navigation`, `ToolRoundTrip`, the exclusion register) take append-only edits, unioned at integrate-forward with counts re-derived. Check each against `origin/OCU-1-epic21` before editing; never take Epic 21's stories.
