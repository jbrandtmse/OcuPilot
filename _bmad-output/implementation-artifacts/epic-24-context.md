# Epic 24 Context: Stage 5, second lane - interoperability, analytics, developer tools and the agent's harvested tools

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

This epic is the share of Stage 5 (custom-REST parity built from harvested MCP-suite handler bodies) that runs on slot B beside Epic 21. It covers the remaining interoperability surfaces, the analytics editors Epic 20 left out, a developer-tools set, and the last two steps of the agent's growth: the 28 harvested interoperability inspection and search tools, and undo by snapshot and revert. No story depends on one Epic 21 still holds. Stories 24.1 (code metrics and document hashes), 24.2 (the term-list editor) and 24.3 (auto-start, shutdown groups and eight Epic 20 cleanup fixes) are done. Their other surfaces were split into Stories 24.5 to 24.19.

## Stories

- Story 24.1: Developer tools (done)
- Story 24.2: The analytics editors (done)
- Story 24.3: Interoperability parity (done)
- Story 24.4: The agent gains the harvested tools and undo
- Story 24.5: Unit-test runner and work-queue viewer
- Story 24.6: The command and class-method consoles
- Story 24.7: Web terminal
- Story 24.8: Remote instance profiles and environment diff (retitled at its plan, U-45)
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

## Requirements & Constraints

- **One contract per screen.** One descriptor, one port. The read tool and the write tools' field lists derive from the descriptor. Every write is a server-minted proposal with an instance-computed diff, an explicit confirmation and an agent audit marker. A story is accepted on that contract plus each row "round-trips over its backing class".
- **Governance.** Every new write key joins the baseline in its story. Every new destructive key ships `false` and is named destructive. Read-only surfaces add no key.
- **Harvest cautions.** Take handler bodies only, and read the current body first. Rename every harvested token, comments included; the ObjectScript checker refuses the sibling's names, globals, output markers, `iris_` prefix and `IRIS_*` variables. Where a body cannot do what the classic page does, extend the port instead and never edit the body (24.3's auto-start, `BackupPort`'s freeze).
- **Secrets and paths.** No credential reaches a screen or a log. No caller value is concatenated into SQL. No endpoint takes a filesystem path; transfer files are named from a fixed enum or a strict single-segment name.
- **24.4.** Each of the 28 tools declares `read` or `write` at definition time and passes the single call-time gate. Undo captures a snapshot **before** the write and offers a one-click revert; the revert is itself a confirmed proposal with its own diff and audit marker. The spine still lists undo as Deferred, needing "a state-capture model the write path does not yet have", and no AD covers it. Readiness flagged this and continued under veto U-43 (reversal: stop Epic 24 until an architecture update). The runner amends no AD unattended, so the model goes into the spec as a proposed AD for the owner's attended update, as 24.1 to 24.3 did.
- **24.6:** the execute-command console's output is capped by the harvested output ceiling (32,768 characters).
- **24.8 and 24.9 (owner answer U-45).** Diff and promote work between namespaces of the **same instance** only. Remote instance profiles go to the exclusion register, the epics text is amended at 24.8's plan, and no AD is needed. Promote keeps its four gates (plan, execute-with-confirm, steps allow-list, plan-hash freshness), has no rollback, and the screen says so.
- **24.13 (owner answer U-34) carries DW-2518.** A cube build or synchronize that applied only some steps is audited as a failed configuration change naming the steps applied (today `PerformCube` returns before `AuditWrite`). The owner sanctioned an AD-15 sentence, added at 24.13's spec gate.
- **24.11 and 24.12** save and compile a class. **24.15:** credentials carry a secret (AD-35, AD-56); the MCP suite's credential and default-settings bodies exist. **24.19:** identify the hidden EnsPortal pages' backing classes on the instance first; deployment writes its log and rollback files, and its history offers rollback and delete.

## Technical Decisions

- **Harvest seam (AD-23).** Bodies inherit `OcuPilot.Port.Harvest.Handler` (`RenderResponseBody` emits OcuPilot's envelope); only the base class changes. Bodies run only through `HarvestPort.Invoke` from one area port, which validates shape, refuses wide input and applies cost caps first (count, then refuse over the cap; never truncate after the scan). A new body adds its `HARVEST_CALLERS` row and a `PortGate` `<body>` row. Namespace switches save and restore (AD-16).
- **Ports (AD-29, AD-52).** Each port carries its own authorization gate; the vendor's check is a lower bound. A write tool declares its port, and every re-read, check and write resolves through it.
  - `DevToolPort` (24.1; 24.5 and 24.6 extend it) is not in AD-29's Binds, which waits for the owner. Caller SQL never goes through Atelier's `action/query` (AD-61).
  - `InteropPort` (AD-62) alone reads and writes production configuration. 24.3's gate is the template: endpoint pairs, then namespace shape (409 `INTEROP.NAMESPACE`), then the classic page's `EDITRESOURCE` plus WRITE on the globals database, naming `detail.failedPair`. Vendor calls only, never a `Set` of a vendor global; a silent vendor no-op is refused by name (`SAME`). Vendor editors load in a same-origin frame OcuPilot never reaches into (AD-63).
  - `AnalyticsPort` (AD-65) calls `%DeepSee` in process and only reads measured to write nothing. Its writes gate before any vendor call, check WRITE on the database the target global maps to, run multi-call writes in one transaction with no audit, job or I/O inside, and refuse an unjournaled database (`NOTJOURNALED`, vetoes U-46 and U-48 kept).
- **Write model.** Single-use, fingerprinted, expiring proposal (AD-6, AD-34); complete merged body over a port-composed read (AD-4, AD-51, AD-56); screen action and agent write are one operation (AD-53); read-back of the fields sent (AD-58); one change event (AD-14); prohibited review in the kernel only (AD-10); script form for every write tool (AD-59). Where the vendor audits nothing (measured on the throwaway), each write records OcuPilot's own `ConfigChange` from either caller (AD-15). Screen action values are strings.
- **Spine additions merged in from Epic 21.**
  - AD-10 gained a protected-global arm, refused from either caller with the key on or off: a write under an OcuPilot name stem, or one resolving to OcuPilot's database or `SYSTEMDATABASES`, is `PROHIBITED.PROTECTEDGLOBAL`; a code-global write reaching OcuPilot's code is `PROHIBITED.OCUPILOTCODE`.
  - AD-51 gained owner-allowed action-write cases: each answers its fresh read through a port-composed type, and a reviewed payload's digest is the fingerprint, so content that moved after review refuses the write.
  - Writes whose card carries values that must never reach the model are unadvertised person-only writes with keys shipped `false`; the agent proposes only a by-name form (AD-36).
- **Reads (AD-36, AD-5, AD-24, AD-44).** A screen and its tool share one capped read that reports truncation; screens are namespace-scoped; each descriptor names the classic page it replaces, or `""`.
- **Guided workflows (AD-66)** are `XData Catalog` entries; promote's stays absent until 24.9.
- **Dry-run then confirm** for purge and promote. A match count over the cap is refused, never truncated and executed.
- **The 28 tools** are iris-session-agent's read-only, Ens-specific `Tool.*` set. Take the rules, not the mechanism: the cross-vendor JSON-Schema subset (no `$ref`, `oneOf`, `anyOf`, `allOf` or `pattern`), searches bounded to a time window on an indexed lead column, and no touching `%session`, `%request` or `$NAMESPACE`.
- **Pending for the owner's attended architecture update (never edit them):** `DevToolPort` in AD-29's Binds and the AD clauses 24.2 and 24.3 proposed.
- **Open questions:** DW-2597 (the agent's mint answers a rule refusal as `TOOL.ARGUMENTS`); DW-2616 (sentence-shaped agent phrases on three non-interop screens, owner burn-down).

## UX & Interaction Patterns

- The proposal card shows the target, before/after rows, an "N unchanged fields" fold, rationale, impact and a "Reverse:" line where a reversal exists. A delete has no after-state and no "Reverse:" line. Undo builds on that line.
- A destructive action uses the typed-name confirm dialog, ending "This cannot be undone." where true.
- Developer tools sit in System Explorer and extend 24.1's `dev-tool.page.ts` and store. New per-production settings go on Productions as row actions with a dialog, as 24.3's did.
- An empty-state agent string is a lowercase action phrase, never a sentence. New strings go into EXPERIENCE.md's Fixed strings.

## Cross-Story Dependencies

- Run order: 24.4, then 24.5 to 24.9, 24.10 to 24.14 and 24.15 to 24.19 (inference from the split numbering; 24.5 to 24.9 were ruled to run after 24.4).
- 24.4 reaches interoperability through `InteropPort`. Its undo must cover earlier writes, including 24.2's term-list writes and 24.3's `interop.productions.autostart` and `shutdowngroup` (each reversed by setting the before value back).
- 24.5 and 24.6 extend `DevToolPort`; 24.8 may reuse 24.1's hashes (inference); 24.9 follows 24.8. 24.10 extends 24.2's term-list tools; 24.10 to 24.14 extend `AnalyticsPort`. 24.15 to 24.19 extend 24.3's `InteropPort` startup work; 24.15 may reuse its gate shape (inference).
- Epic 21 runs on slot A; Stories 21.2, 21.3 and 21.4 are merged in. Shared rosters, counts and registry lists take append-only edits, unioned at integrate-forward, with counts re-derived and a mutation that reddens each count. Stop if a merge would reorder entries or change an assertion. Anything beyond an append in a file Epic 21 also edits (`Screen/Read.cls`, `Prohibited.cls`, EXPERIENCE.md's interop row, roster literals) needs the orchestrator's ruling. Never take Epic 21's stories.
