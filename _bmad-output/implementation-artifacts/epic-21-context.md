# Epic 21 Context: Stage 5 - custom-REST parity from the MCP suite's handlers

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Make every remaining classic-portal leaf in the instance-administration and data areas reachable through OcuPilot's own API, where the leaf has a backing class but no admin or Atelier route. That covers backup and mirroring, the startup, memory and compatibility tables, NLS locales and the SQL settings, globals and the data tools, the SQL tuning track, and the last leaves in the six original areas. The handler bodies are harvested from the MCP suite (`ExecuteMCPv2.REST.*`) through one seam, so each catalog row does not become a rewrite. Interoperability parity, the analytics editors, developer tools, and the agent's 28 harvested tools with undo moved to Epic 24, which runs beside this epic on a second slot.

## Stories

- Story 21.1: The harvest seam
- Story 21.2: Backup
- Story 21.3: Startup, memory and compatibility settings
- Story 21.4: NLS locales and SQL settings
- Story 21.5: Globals and the data tools
- Story 21.6: The SQL tuning track
- Story 21.10: The remaining leaves across the six areas
- Story 21.12: Mirroring
- Story 21.13: DDL mappings
- Story 21.14: NLS configured defaults and locale definitions
- Story 21.15: Locale and table import

## Requirements & Constraints

- **One contract for every screen added after Release 1.** Each screen is declared by exactly one descriptor and reaches outside through exactly one port. Its read tool and its write tools' field lists derive from that descriptor. Every write goes through a server-minted proposal, an instance-computed diff, an explicit confirmation and an agent audit marker. A story is accepted on that contract plus each row's own backing class; anything finer is authored when the row is picked up.
- **Destructive writes start disabled.** A new write key is never left out of the governance baseline: the baseline test requires a line for every registered write key, so a destructive key ships with a `false` line and joins that test's disabled list in the same change. Destructive actions are named as destructive (every global kill, for example). Backup run, mirror actions and global kill are the highest-consequence operations here.
- **Backup (21.2):** every write is a confirmed proposal whose destructive key ships disabled. Every freeze OcuPilot issues, from either caller, carries a bounded suspend limit, so writes never stay frozen indefinitely.
- **Harvested bodies are not policed yet (21.2):** a body is a public class method that any code or route could call past the harvest port's gate, and the port-gate test has no row kind for a body class.
- **Mirroring (21.12):** every write is a confirmed proposal whose destructive key ships disabled. Only removing a mirror together with its databases joins the kernel's prohibited set, beside the self-protection cases it already holds; removal that keeps the databases is an ordinary disabled-by-default write.
- Settings that need a restart say so on each change.
- **SQL, locale and NLS settings (21.4, 21.13 to 21.15):** 21.4 keeps the SQL, TSQL and ISQL settings with the SQL Shell settings; 21.13 the system and user DDL mappings; 21.14 the NLS configured defaults and the locale definitions editor; 21.15 locale and table import. Each round-trips over its backing class. All four configure the server's locales and settings; OcuPilot's own interface stays English in every one.
- The diagnose-slow-query guided workflow gains the SQL tuning screens it was written for.
- **Harvest cautions:**
  - Take handler bodies and nothing else. The MCP suite's IPM manifest is stale and its bootstrap is driven from TypeScript.
  - Two known defects have unverified fix status: the task-history filter, and resource creation with a description. Read the current bodies before harvesting them.
- **Some legacy CSP pages were never exported** (Backup, Journals, Global View/Edit, Find/Replace, the SQL wizards and others). Their action sets are inferred from rendered HTML, so pull the page source from the container before building those screens.
- A leaf whose backing class was never inventoried starts with identifying that class on the instance.

## Technical Decisions

- **The harvest seam (AD-23, built in 21.1):** harvested handlers inherit an OcuPilot base class that exposes `RenderResponseBody(pStatus As %Status, pMsgPart As %DynamicArray, pResPart As %DynamicObject) As %Status`, the signature called at all 738 harvested call sites. It emits OcuPilot's envelope instead of `%Atelier.REST`'s `{status, console, result}`. Only the base class changes; handler bodies are never edited to change response shape. `HarvestPort` is a body's one caller: it gates the call and runs the body in the caller's process, so a harvested body is reached through a port, not routed on its own.
- **One envelope, one writer (AD-12, AD-39):** a flat `{error, reason}` envelope with a slug from a fixed enum, plus a stable machine code and an optional detail object. Handlers never `Write` to the response. Inside a nested `Catch`, use `Return $$$OK`, never a bare `Quit`. The no-`}{` double-envelope test must keep passing. Vendor `%Status` text is normalized before it reaches the screen or the model.
- **Rename everything harvested.** None of `ExecuteMCPv2.*`, `SessionAgent.*`, `/api/executemcp/v2`, `^ExecuteMCPv2*`, `%ExecuteMCPOutput`, the `[IRIS-MCP-TRUNCATED…]` marker, the `iris_` tool prefix or any `IRIS_*` environment variable may appear. Tools are named `<area>.<screen>.<verb>`.
- **Ports (AD-29, AD-52):** a slice reaches outside only through a port, and every port carries its own authorization gate; the vendor's own check is a lower bound, not the whole requirement. A write tool declares its port, and the fresh read, the confirm's re-read, the prohibited-set check and the write all resolve through that declaration.
- **The write model:**
  - The proposal is single-use, fingerprinted and expires after 10 minutes (AD-6).
  - OcuPilot computes the merge itself and sends a complete body (AD-4).
  - A screen's own action and the agent's write are one operation reached by two callers (AD-53).
  - After a confirmed write, the target is read back and the response says whether it holds what was sent (AD-58).
  - A confirmed write emits one change event, and screens re-fetch instead of patching (AD-14).
  - Prohibited actions are absent from the tool set, and any new ones are added in the kernel, never in a policy file (AD-10).
- **Reads are bounded (AD-36, AD-24):** a screen and its tool share one declared read, which is capped and reports truncation. Context is capped and secret-typed fields are stripped.
- **No caller value is concatenated into SQL, and no endpoint accepts a filesystem path (AD-21).** This matters for backup, global export and import, and locale and table import: a caller names files from a fixed enum or a strict single-segment name. Secrets never reach a displayed surface or a log (AD-35).
- **Governance (AD-22):** each tool declares `read` or `write` at definition time and passes the single call-time gate.
- **Guided workflows (AD-66):** a workflow is a new entry in the catalog's `XData Catalog`, never a code path. Each write in it is one confirmed proposal; there is never a batch approval.
- **Classic page keys (AD-44):** each descriptor declares the classic page class it replaces, and its privilege set unions any custom resource assigned to that page. The portal's own pages for the split SQL and NLS stories are `%CSP.UI.Portal.SQL.Configure.SQL`, `.TSQL` and `.ISQL` (21.4), `%CSP.UI.Portal.Config.SQLDataTypes` with `Subject=SystemDataTypes` or `UserDataTypes` (21.13), `%CSP.UI.Portal.NLSConfigDefs` and `%CSP.UI.Portal.NLS` (21.14), and `%CSP.UI.Portal.NLSImport` (21.15); confirm each against the instance before keying a descriptor to it.
- Harvested helpers worth reusing: namespace switch and restore, the validators, `SanitizeError`, `ApplyOutputCeiling` and `SurrogateSafeCutLength`.

## UX & Interaction Patterns

- The proposal review card shows the target, the changed fields as before/after rows from a fresh read, the unchanged fields collapsed under "N unchanged fields", the rationale, the expected impact, and a "Reverse:" line where a reversal exists.
- A destructive action uses the typed-name confirm dialog. Its body states the consequence and ends "This cannot be undone." where that is true.
- New user-facing strings are published in EXPERIENCE.md's Fixed strings.

## Cross-Story Dependencies

- 21.1 (the seam) is on the feature branch and comes before every story that harvests a handler body: 21.2 to 21.6, 21.10 and 21.12 to 21.15. Epic 24's stories also harvest through it.
- 21.12 was split from 21.2 and is planned right after it.
- 21.13, 21.14 and 21.15 were split from 21.4 and are planned in that order right after it; each carries one part of 21.4's original round-trip criterion and the same English-interface criterion.
- 21.6 extends the diagnose-slow-query workflow from Epic 20.
- 21.10 adds leaves to the area slices from earlier epics, each in the slice that already owns its neighbors.
- Epic 24 (interoperability, analytics, developer tools, the 28 tools and undo) runs on another slot and depends on no story this epic still holds. Epic 22's long-tail rows stay out of scope.
