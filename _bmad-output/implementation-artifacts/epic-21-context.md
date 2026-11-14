# Epic 21 Context: Stage 5 - custom-REST parity from the MCP suite's handlers

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Make every remaining classic-portal leaf that has a backing class but no admin, Atelier, interop or analytics route reachable through OcuPilot's own API. That covers backup and mirroring, the startup, memory and compatibility tables, NLS locales and the SQL settings, globals and the SQL tuning track, the remaining interoperability surfaces, the analytics editors, a developer-tools set, and the last leaves in the six original areas. The handler bodies are harvested from the MCP suite (`ExecuteMCPv2.REST.*`) so 165 catalog rows (S 60 / M 79 / L 26, about 128 new endpoints) do not each become a rewrite. The agent also takes the last two steps of its growth: the 28 harvested interoperability inspection and search tools, and undo by snapshot and revert. This is the largest stage, and the one the harvest seam was designed for.

## Stories

- Story 21.1: The harvest seam
- Story 21.2: Backup
- Story 21.3: Startup, memory and compatibility settings
- Story 21.4: NLS locales and SQL settings
- Story 21.5: Globals and the data tools
- Story 21.6: The SQL tuning track
- Story 21.7: Interoperability parity
- Story 21.8: The analytics editors
- Story 21.9: Developer tools
- Story 21.10: The remaining leaves across the six areas
- Story 21.11: The agent gains the harvested tools and undo
- Story 21.12: Mirroring

## Requirements & Constraints

- **One contract for every screen added after Release 1.** Each screen is declared by exactly one descriptor and reaches outside through exactly one port. Its read tool and its write tools' field lists derive from that descriptor. Every write goes through a server-minted proposal, an instance-computed diff, an explicit confirmation and an agent audit marker. A story is accepted on that contract plus each row's own backing class; anything finer is authored when the row is picked up.
- **Destructive writes start disabled.** A new write key is never left out of the governance baseline: the baseline test requires a line for every registered write key, so a destructive key ships with a `false` line and joins that test's disabled list in the same change. Destructive actions are named as destructive (for example, every global kill). The highest-consequence operations are backup run, mirror actions, global kill, purge and deployment.
- **Backup (21.2):** every write is a confirmed proposal whose destructive key ships disabled. Every freeze OcuPilot issues, from either caller, carries a bounded suspend limit; the bound, its mechanism and how it holds where the vendor ignores the suspend limit (a clustered system) are measured in the story.
- **Harvested bodies are not policed yet (21.2):** a body is a public class method that any code or route could call past the harvest port's gate, and the port-gate test has no row kind for a body class.
- **Mirroring (21.12):** every write is a confirmed proposal whose destructive key ships disabled. Only removing a mirror together with its databases joins the kernel's prohibited set, refused from either caller; removal that keeps the databases is an ordinary disabled-by-default write.
- Settings that need a restart say so on each change.
- NLS work configures the server's locales. OcuPilot's own interface stays English.
- The execute-command console's output is capped by the harvested output ceiling (32,768 characters).
- Environment promote keeps its four gates: plan, execute-with-confirm, a steps allow-list, and plan-hash freshness. It has no rollback, and the screen says so.
- Remote instance profiles (DT-11) land before environment diff and promote (DT-09, DT-10).
- Deployment writes its log and rollback files, and the deployment history offers rollback and delete.
- The diagnose-slow-query guided workflow gains the SQL tuning screens it was written for.
- **Harvest cautions:**
  - Take handler bodies and nothing else. The MCP suite's IPM manifest is stale and its bootstrap is driven from TypeScript.
  - Two known defects have unverified fix status: the task-history filter, and resource creation with a description. Read the current bodies before harvesting them.
- **Legacy CSP pages were never exported** (Backup, Journals, Global View/Edit, Find/Replace, the SQL wizards and others). Their action sets are inferred from rendered HTML, so pull the page source from the container before building those screens.
- A leaf whose backing class was never inventoried starts with identifying that class on the instance. Hidden EnsPortal pages have only estimated action sets.

## Technical Decisions

- **The harvest seam (AD-23, built in 21.1):** harvested handlers inherit an OcuPilot base class that exposes `RenderResponseBody(pStatus As %Status, pMsgPart As %DynamicArray, pResPart As %DynamicObject) As %Status`. That is the signature called at all 738 harvested call sites. It emits OcuPilot's envelope instead of `%Atelier.REST`'s `{status, console, result}`. Only the base class changes; handler bodies are never edited to change response shape. `HarvestPort` is a body's one caller: it gates the call and runs the body in the caller's process, so a harvested body is reached through a port, not routed on its own.
- **One envelope, one writer (AD-12, AD-39):** a flat `{error, reason}` envelope with a slug from a fixed enum, plus a stable machine code and an optional detail object. Handlers never `Write` to the response. Inside a nested `Catch`, use `Return $$$OK`, never a bare `Quit`. The no-`}{` double-envelope test must keep passing. Vendor `%Status` text is normalized before it reaches the screen or the model.
- **Rename everything harvested.** None of `ExecuteMCPv2.*`, `SessionAgent.*`, `/api/executemcp/v2`, `^UnitTestRoot`, `^ExecuteMCPv2*`, `%ExecuteMCPOutput`, the `[IRIS-MCP-TRUNCATED…]` marker, the `iris_` tool prefix or any `IRIS_*` environment variable may appear. Tools are named `<area>.<screen>.<verb>`.
- **Ports:**
  - A slice reaches outside only through a port, and every port carries its own authorization gate (AD-29). The vendor's own check is a lower bound, not the whole requirement.
  - A write tool declares its port, and the fresh read, the confirm's re-read, the prohibited-set check and the write all resolve through that declaration (AD-52).
  - Interoperability surfaces go through `InteropPort` (AD-62), analytics through `AnalyticsPort` (AD-65), and Atelier-backed developer tools (unit tests, the work queue, the terminal) through `AtelierPort` (AD-61).
- **The write model:**
  - The proposal is single-use, fingerprinted and expires after 10 minutes (AD-6).
  - OcuPilot computes the merge itself and sends a complete body (AD-4).
  - A screen's own action and the agent's write are one operation reached by two callers (AD-53).
  - After a confirmed write, the target is read back and the response says whether it holds what was sent (AD-58).
  - A confirmed write emits one change event, and screens re-fetch instead of patching (AD-14).
  - Prohibited actions are absent from the tool set, and any new ones are added in the kernel, never in a policy file (AD-10).
- **Reads are bounded (AD-36, AD-24):** a screen and its tool share one declared read, which is capped and reports truncation. Context is capped and secret-typed fields are stripped.
- **No caller value is concatenated into SQL, and no endpoint accepts a filesystem path (AD-21).** This matters for backup, global export and import, deployment files and locale import: a caller names files from a fixed enum or a strict single-segment name. Secrets (interop credentials, passwords) never reach a displayed surface or a log (AD-35).
- **Governance (AD-22):** each tool declares `read` or `write` at definition time and passes the single call-time gate. The 28 harvested tools do the same.
- **Guided workflows (AD-66):** a workflow is a new entry in the catalog's `XData Catalog`, never a code path. Each write in it is one confirmed proposal; there is never a batch approval.
- **Classic page keys (AD-44):** each descriptor declares the classic page class it replaces, and its privilege set unions any custom resource assigned to that page.
- **Undo is designed in this epic, not retrofitted.** It needs a per-entity state-capture model that the write path does not have yet, and no harvested source provides one. It takes a snapshot before the write and offers a one-click revert. The revert is itself a confirmed proposal with its own diff and its own audit marker.
- **The 28 tools** come from iris-session-agent's `Tool.*` (all read, all Ens-specific): session summary and timeline, message headers, detail and body, event and rule logs, explain error, BP instance, source and methods, related sessions, queue state, config item, and the `search_by_*` family. Take the rules, not the mechanism:
  - the cross-vendor JSON-Schema subset (no `$ref`, `oneOf`, `anyOf`, `allOf` or `pattern`);
  - bounded time-window searches;
  - tools never touch `%session`, `%request` or `$NAMESPACE`; everything arrives through the caller context.
- Harvested helpers worth reusing: namespace switch and restore, the validators, `SanitizeError`, `ApplyOutputCeiling` and `SurrogateSafeCutLength`. The dry-run-plus-confirm double gate is the reference for resend, purge and promote, and it refuses a match count over its cap rather than truncating and executing.

## UX & Interaction Patterns

- The proposal review card shows the target, the changed fields as before/after rows from a fresh read, the unchanged fields collapsed under "N unchanged fields", the rationale, the expected impact, and a "Reverse:" line where a reversal exists. Undo builds on that last line.
- A destructive action uses the typed-name confirm dialog. Its body states the consequence and ends "This cannot be undone." where that is true.
- New user-facing strings are published in EXPERIENCE.md's Fixed strings.

## Cross-Story Dependencies

- 21.1 (the seam) comes before every story that harvests a handler body: 21.2 to 21.10 and 21.12.
- In 21.9, remote instance profiles (DT-11) land before environment diff and promote (DT-09, DT-10).
- 21.6 extends the diagnose-slow-query workflow from Epic 20 (Story 20.12).
- 21.7 extends Epic 20's Interoperability slice and `InteropPort`. 21.8 extends Epic 20's analytics rider and `AnalyticsPort`.
- 21.12 is planned right after 21.2, which it was split from.
- 21.11 depends on 21.7's interoperability surfaces for the 28 tools. Undo applies across every write tool from earlier epics.
- 21.10 adds leaves to the area slices from Epics 1 to 18, each in the slice that already owns its neighbors.
- Epic 22's long-tail rows stay out of scope.
