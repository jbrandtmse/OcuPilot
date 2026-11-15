# Epic 24 Context: Stage 5, second lane - interoperability, analytics, developer tools and the agent's harvested tools

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

This epic is the share of Stage 5 (custom-REST parity built from harvested MCP-suite handler bodies) that runs on slot B beside Epic 21. It covers the remaining interoperability surfaces, the analytics editors Epic 20 left out, a developer-tools set, and the last two steps of the agent's growth: the 28 harvested interoperability inspection and search tools, and undo by snapshot and revert. No story depends on one Epic 21 still holds. Stories 24.1 (code metrics and document hashes) and 24.2 (the term-list editor) are done. Their other surfaces were split into Stories 24.5 to 24.9 and 24.10 to 24.14.

## Stories

- Story 24.1: Developer tools (done)
- Story 24.2: The analytics editors (done: the term-list editor)
- Story 24.3: Interoperability parity
- Story 24.4: The agent gains the harvested tools and undo
- Story 24.5: Unit-test runner and work-queue viewer
- Story 24.6: The command and class-method consoles
- Story 24.7: Web terminal
- Story 24.8: Environment diff (title amended at its plan, see below)
- Story 24.9: Environment promote
- Story 24.10: Folder manager transfer and term-list import, export and copy
- Story 24.11: Listing groups
- Story 24.12: Quality measures
- Story 24.13: Analytics settings
- Story 24.14: PMML model tester and dashboard viewer

## Requirements & Constraints

- **One contract per screen.** Each screen has one descriptor and reaches outside OcuPilot through one port. Its read tool and its write tools' field lists derive from that descriptor. Every write is a server-minted proposal with an instance-computed diff, an explicit confirmation and an agent audit marker. A story is accepted on that contract plus each catalog row "round-trips over its backing class".
- **Governance.** Every new write key joins the baseline in the story that ships it. Every new destructive key ships `false` and is named as destructive. Read-only surfaces add no key.
- **Harvest cautions.** Take handler bodies only, and read the current body before harvesting it. Rename every harvested token, comments included; the ObjectScript checker refuses the sibling's names, globals, output markers, `iris_` prefix and `IRIS_*` variables.
- **Secrets and paths.** No credential reaches a screen or a log. No caller value is concatenated into SQL. No endpoint accepts a filesystem path: transfer files are named from a fixed enum or a strict single-segment name.
- **24.3** carries eight routed ledger entries: DW-2361, DW-2378, DW-2379, DW-2388, DW-2421, DW-2433, DW-2452 and DW-2554. Deployment writes its log and rollback files, and its history offers rollback and delete. The hidden EnsPortal pages (registries, interface maps and references) have estimated action sets only, so identify their backing class on the instance first.
- **24.4.** Each of the 28 tools declares `read` or `write` at definition time and passes the single call-time gate. Undo takes a snapshot before the write, and its revert is itself a confirmed proposal with its own diff and audit marker. No AD covers the state-capture model yet, so the story needs a spine amendment.
- **24.6:** the execute-command console's output is capped by the harvested output ceiling (32,768 characters).
- **24.8 and 24.9 (owner answer U-45).** Environment diff and promote work between namespaces of the **same instance** only. There are no remote instance profiles: they go to the exclusion register, the epics text for 24.8 and 24.9 is amended at 24.8's plan, and no new AD is needed. No request leaves the instance, so the privacy, single-instance and not-planned statements stay as written. Promote keeps its four gates (a plan, execute-with-confirm, a steps allow-list, plan-hash freshness). It has no rollback, and the screen says so.
- **24.13 (owner answer U-34) carries DW-2518.** A cube build or synchronize that applied only some steps is audited as a failed configuration change naming the steps that applied. Today `PerformCube` returns before `AuditWrite` on failure. The owner sanctioned an AD-15 sentence, which is added at 24.13's spec gate.
- **24.11 and 24.12** save and compile a class.

## Technical Decisions

- **Harvest seam (AD-23).** Bodies inherit `OcuPilot.Port.Harvest.Handler`, whose `RenderResponseBody(pStatus, pMsgPart, pResPart)` emits OcuPilot's envelope. Only the base class changes, never the body. A harvested support library joins its handler by inheritance, so `..X()` resolves while the body is switched to another namespace. A `%Atelier` text read becomes `Kernel.Utils.DocumentLines`.
- **Bodies run only through `HarvestPort.Invoke`, from one area port.** `SanitizeError` turns a body's own refusal into `INTERNAL`, so the area port does shape validation, refuses wide input and applies cost caps before any body runs. Where a body has no cap, count first and refuse over the cap, never truncate after the scan. The checker's `HARVEST_CALLERS` maps each `Port/Harvest/*` class to the one port allowed to name it, so a new body adds its row there and a `PortGate` `<body>` row. Namespace switches use save and restore (AD-16), and no `OcuPilot.*` class is named by `##class` while switched.
- **`DevToolPort` (24.1)** gates with `AtelierPort.Pairs()`, namespace shape, `NamespacePairs(ns)`, spec shape, the wide-spec rule and a document cap (`MAXDOCUMENTS` 1,000). 24.5 and 24.6 extend it rather than adding ports. It is not yet in AD-29's Binds, which waits for the owner's attended architecture update. Caller SQL never goes through Atelier's `action/query` (AD-61).
- **Ports (AD-29, AD-52).** Every port carries its own authorization gate, and the vendor's check is only a lower bound. A write tool declares its port, and every re-read, check and write resolves through that declaration.
  - `InteropPort` (AD-62) alone reads and writes production configuration. Items are keyed `[Production, Name]`. A write calls `SaveToClass`, and a namespace under source control refuses item writes. Vendor editors load in a same-origin frame that OcuPilot never reaches into (AD-63).
  - `AnalyticsPort` (AD-65) calls `%DeepSee` in process, never `/api/deepsee`, and calls only reads measured to write nothing.
- **Analytics write pattern (24.2, reused by 24.10 to 24.14).**
  - The gate runs before any vendor call. `AdmitDestination` checks WRITE on the database the target global maps to, mounted read-write.
  - Multi-call writes run in one `TSTART`/`TCOMMIT`, with nothing audited, no job and no I/O inside the transaction. Term-list writes refuse an unjournaled database (`NOTJOURNALED`); that ruling stands, because the owner kept vetoes U-46 and U-48.
  - The vendor audits none of these writes, so each write records OcuPilot's own `ConfigChange` from either caller.
  - Every registered write tool needs a script form (AD-59, `DraftRegistry`).
  - Screen action values are strings (AD-56).
  - The agent's mint answers a rule refusal as `TOOL.ARGUMENTS`; that question is open as DW-2597.
- **Write model.** A proposal is single-use, fingerprinted and expiring (AD-6). OcuPilot sends a complete merged body (AD-4). Action-style writes declare their own request type (AD-51). A screen action and the agent's write are one operation (AD-53). The target is read back after the write (AD-58). One change event is emitted, and screens re-fetch (AD-14). Prohibited actions are added only in the kernel (AD-10).
- **Reads (AD-36, AD-5, AD-24, AD-44).** A screen and its tool share one capped read that reports truncation. Each descriptor names the classic page it replaces, or `""`.
- **Guided workflows (AD-66)** are `XData Catalog` entries. The promote workflow stays absent until 24.9 supplies its tools.
- **Dry-run then confirm** is the pattern for purge and promote. A match count over the cap is refused, never truncated and then executed.
- **The 28 tools** are iris-session-agent's read-only, Ens-specific `Tool.*` set. Take the rules, not the mechanism: the cross-vendor JSON-Schema subset (no `$ref`, `oneOf`, `anyOf`, `allOf` or `pattern`), bounded time-window searches on an indexed lead column, and no touching `%session`, `%request` or `$NAMESPACE`.

## UX & Interaction Patterns

- The proposal card shows the target, before/after rows, an "N unchanged fields" fold, the rationale, the impact, and a "Reverse:" line where one exists. Undo builds on that line.
- A destructive action uses the typed-name confirm dialog, ending "This cannot be undone." where true.
- Developer tools sit in System Explorer, and new screens extend 24.1's `dev-tool.page.ts` and its store. The empty-state agent string is a lowercase action phrase, never a full sentence (DW-2452). New strings go into EXPERIENCE.md's Fixed strings.

## Cross-Story Dependencies

- Run order: 24.3, 24.4, then 24.5 to 24.9, then 24.10 to 24.14 (inference from the split numbering).
- 24.3 extends Epic 20's interoperability slice. 24.4 reaches interoperability through `InteropPort`, and its undo covers every earlier write tool, including 24.2's term-list writes.
- 24.5 and 24.6 extend `DevToolPort`. 24.8 may reuse 24.1's hashes (inference), and 24.9 follows 24.8.
- 24.10 extends 24.2's term-list tools. 24.10 to 24.14 extend `AnalyticsPort`.
- Epic 21 runs on slot A. Story 21.2 (backup, `BackupPort`) is merged in. Rosters, counts and registry lists shared with Epic 21 take append-only edits, unioned at integrate-forward, with counts re-derived and a mutation that reddens the count. Stop if a merge would reorder entries or change an assertion. Never take Epic 21's stories.
