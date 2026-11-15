# Epic 21 Context: Stage 5 - custom-REST parity from the MCP suite's handlers

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Make every remaining classic-portal leaf in the instance-administration and data areas reachable through OcuPilot's own API, where the leaf has a backing class but no admin or Atelier route. That covers backup, the mirror monitor, the startup, memory and compatibility tables, NLS locales and the SQL settings, globals and the data tools, the SQL tuning track, and the last leaves in the six original areas. Handler bodies are harvested from the MCP suite (`ExecuteMCPv2.REST.*`) through one seam, so no catalog row becomes a rewrite. Interoperability parity, the analytics editors, developer tools, and the agent's 28 harvested tools with undo moved to Epic 24, which runs beside this epic on a second slot. The mirroring writes left this epic for Epic 22's exclusion register: this project's Community license allows no mirroring, and a join needs a second instance.

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
- **Governance baseline.** Every write key a story adds joins the baseline in that story. A key absent from the baseline defaults to disabled. Every new destructive key ships disabled, and every kill or delete is named as destructive.
- **Backup (21.2):** every backup write is a confirmed proposal whose destructive key ships disabled. Every freeze OcuPilot issues, from either caller, carries a bounded suspend limit.
- **Harvested bodies are not yet policed:** a body is a public class method that any code or route could call past `HarvestPort`'s gate, and the port-gate test has no row kind for a body class.
- **Mirroring (21.12), narrowed:**
  - The mirror monitor reads the instance's mirror state, including the state of not being a member.
  - Removing a mirror's configuration with the option that takes its databases out of mirroring is refused from either caller. That covers `SYS.Mirror.RemoveMirrorConfiguration` with `DeleteDB` and `RemoveOneMirrorSet` with `DeleteDBs`. The refusal joins the kernel's prohibited set, and its code is named at the story's spec gate.
  - The mirroring writes are not built: create, edit for failover and async members, join, and the member and database actions. Each one becomes a row in the exclusion register's license-gated group, naming the license it needs.
- Each settings change states its restart requirement where one applies (21.3).
- **SQL, locale and NLS settings (21.4, 21.13 to 21.15):** each story round-trips over its backing class.
  - 21.4 keeps the SQL, TSQL and ISQL settings, with the SQL Shell settings.
  - 21.13 holds the system and user DDL mappings.
  - 21.14 holds the NLS configured defaults and the locale definitions editor.
  - 21.15 holds locale and table import.

  All four configure the server; OcuPilot's own interface stays English.
- The diagnose-slow-query guided workflow gains the SQL tuning screens it was written for (21.6).
- **Harvest cautions:**
  - Take handler bodies and nothing else. The MCP suite's manifest is stale, and its bootstrap is driven from TypeScript.
  - Two known defects have unverified fix status: the task-history filter, and resource creation with a description. Read the current bodies before harvesting them.
- **Some legacy CSP pages were never exported**, among them Backup, Journals and Global View/Edit. Their action sets are inferred, so read the page on the instance before building a screen for one.
- A leaf whose backing class was never inventoried starts by identifying that class on the instance (21.10).

## Technical Decisions

- **The harvest seam (AD-23):** a harvested handler inherits an OcuPilot base class exposing `RenderResponseBody(pStatus As %Status, pMsgPart As %DynamicArray, pResPart As %DynamicObject) As %Status`, the signature called at all 738 harvested call sites. The base class emits OcuPilot's envelope instead of `%Atelier.REST`'s `{status, console, result}`. Only the base class changes; a body is never edited to change response shape.
- **One envelope, one writer (AD-12, AD-39):** the envelope carries a slug from a fixed enum, a reason, a stable machine code and an optional detail object. Handlers never `Write` to the response. In a nested `Catch`, use `Return $$$OK`, never a bare `Quit`. The no-`}{` double-envelope test must keep passing.
- **Rename everything harvested:** packages, web paths, globals and the `iris_` tool prefix take OcuPilot's own names.
- **Ports (AD-29, AD-52):** every port carries its own authorization gate, and the vendor's check is a lower bound, not the whole requirement. A write tool declares its port. The fresh read, the confirm's re-read, the prohibited-set check and the write all resolve through that declaration.
- **The write model:**
  - The proposal is single-use, fingerprinted and expires (AD-6).
  - A screen's action and the agent's write are one operation reached by two callers (AD-53, AD-55).
  - Action-style writes and create writes are first-class kinds (AD-51, AD-54).
  - After the write, the target is read back to check it holds what was sent (AD-58).
  - A confirmed write emits one change event, and screens re-fetch (AD-14).
- **Prohibited set (AD-10):** a refusal is evaluated on the instance against the resolved target, from either caller, and is declared once in the kernel, never in a policy file or a screen. The self-protection arms already reach OcuPilot's own databases and the protected databases through backup and mirroring paths, by effect.
- **Bounded reads (AD-36):** a screen and its tool share one declared read, which is capped and reports truncation.
- **No SQL concatenation and no caller path (AD-21).** This matters for backup, global export and import, and locale and table import: a caller names a file from a fixed enum or a strict single-segment name, never a path.
- **Guided workflows (AD-66):** a workflow is a catalog entry, never a code path. Each write in it is one confirmed proposal.
- **Classic page keys (AD-44):** each descriptor declares the classic page class it replaces, and its privilege set includes any custom resource assigned to that page. The mirror monitor's page is `%CSP.UI.Portal.Mirror.Monitor`, NLS import's is `%CSP.UI.Portal.NLSImport`, and the DDL mappings use `%CSP.UI.Portal.Config.SQLDataTypes` with a `Subject` of `SystemDataTypes` or `UserDataTypes`. Confirm each against the instance first.

## UX & Interaction Patterns

- The proposal card shows the target, before and after rows from a fresh read, the unchanged fields collapsed, and "Reverse:" where a reversal exists.
- A destructive action uses the typed-name confirm dialog. Its body states the consequence and ends "This cannot be undone." where that is true.
- New user-facing strings go into EXPERIENCE.md's fixed strings.

## Cross-Story Dependencies

- Stories 21.1 to 21.3 are done. The seam (21.1) comes before every story that harvests a body, including Epic 24's stories.
- 21.12 was split from 21.2. Its exclusion-register rows land in `docs/exclusion-register.md`. `ui/tools/exclusion-register.test.mjs` holds the register equal to the catalog's P4 rows and to the stage extract's groups, so the catalog and the extract change in the same commit. The mirroring rows are SA-43 to SA-49 and SO-17; SO-16 is the monitor.
- 21.13, 21.14 and 21.15 were split from 21.4, and each is planned right after the previous one.
- 21.6 extends Epic 20's diagnose-slow-query workflow. 21.10 adds each leaf to the slice that already owns its neighbors.
