# Epic 20 Context: Stage 4 - Interoperability, with the Analytics rider

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Bring the classic portal's Interoperability work into OcuPilot for namespaces that support it, with Analytics riding along. The agent also gains guided multistep workflows and Investigate, so the largest area the classic portal still owns can be used here. Most of the epic has shipped, including 20.37's SqlRun fix-forward in 1.0.13. This dispatch runs one owner-chartered story, 20.38: a SQL schema's name opens that schema's tables, views and procedures, and no list's name links to a dead route again. It runs on slot B beside Epic 23's 23.12, then holds, and 1.0.14 is cut once both are in. After the hold come 20.34 (cube manager), 20.36 (Investigate), 20.25 (item runtime actions), 20.26 (partner writes) and the burn-down.

## Stories

- Story 20.1: Namespace category gating
- Story 20.2: Productions, listed and controlled
- Story 20.3: Production items
- Story 20.4: Per-host tabs, the monitor, queues and jobs
- Story 20.5: Lookup tables and business partners
- Story 20.6: Testing hosts and transformations
- Story 20.7: The three embedded vendor editors
- Story 20.8: The schema viewers and the production configuration diagram
- Story 20.9: Messages - search, view, resend and trace
- Story 20.10: Source-control hooks
- Story 20.11: The Analytics rider
- Story 20.12: The agent gains guided workflows and Investigate
- Story 20.13: The sign-in hand-off to the embedded vendor editors
- Story 20.14: Interoperability holders reach OcuPilot
- Story 20.15: Per-screen permissions, seen and adjusted
- Story 20.16: The agent edits rule, DTL and BPL content behind the embedded editors
- Story 20.17: Long blocks in the agent panel start collapsed
- Story 20.18: The agent proposes permission changes and refuses on a screen the user cannot open
- Story 20.19: The agent reads class and routine source
- Story 20.20: The agent creates new classes and routines, on the person's confirmation
- Story 20.21: The agent saves edits to existing classes and routines
- Story 20.22: Production item settings
- Story 20.23: Queue and job actions
- Story 20.24: Agent tool calls stop re-listing the tool registry
- Story 20.25: Item runtime and configuration actions
- Story 20.26: Business partners saved and removed
- Story 20.27: Transformations tested
- Story 20.28: OcuPilot compiles in a namespace without interoperability
- Story 20.29: Screens load on demand
- Story 20.30: The session trace
- Story 20.31: Message resend and edit-and-resend
- Story 20.32: The analytics links
- Story 20.33: The MDX query tool
- Story 20.34: The cube manager's build and synchronize
- Story 20.35: The agent's MDX read
- Story 20.36: Investigate
- Story 20.37: SqlRun stored slot order
- Story 20.38: A schema opens its tables, views and procedures
- Story 20.39: Every list's name opens something (split from 20.38; not in this dispatch)

## Requirements & Constraints

### 20.38: a schema opens its objects (current)

- **The defect.** The SQL schemas list's Schema column is a name column with no row target, so the shared table links each name to `system-explorer/sql-schemas/<schema>`. No screen answers that route: the address and the breadcrumb change, and the page stays the list. The classic SQL page opens a schema into its tables, views and procedures.
- **The schema screen** opens at `system-explorer/sql-schemas/document/<schema>` (runner ruling at the plan: AD-5's parent-scoped head, Story 19.5's shape; `sql-schemas/<schema>` stays the list's own id route). It is a tab group with "Tables", "Views" and "Procedures":
  - each tab lists through the existing SQL tables, views and procedures reads with their `schema` criterion (extend those reads, never copy them);
  - each tab lists every object in its schema, system ones included, with no System control of its own (runner ruling: AD-5 gives a parent-scoped read one criterion);
  - each object's name opens its existing table, view or procedure screen;
  - the breadcrumb reads SQL schemas › <schema>.
- **An empty tab** says so plainly while a tab of a kind the schema holds shows rows. Ens holds tables and procedures and no views (measured). The tab names are fixed. The empty-tab sentences are the runner's ruling (veto U-14): "This schema has no SQL tables.", "This schema has no SQL views.", "This schema has no SQL procedures." Any other new on-screen string goes to the orchestrator.
- **The agent** on this screen gets the tabs' own reads, scoped to the schema, as its screen context and tools: three new read tools, one per tab (runner ruling). No new agent action or write.
- **The bug-class check.** A client test fails when any built list's name-column link leads to a route with no built screen.
  - The plan measured 18 self-linking lists. SQL schemas is fixed here; the other 17 sit in an exact allow-list, and Story 20.39 (split sibling, after 23.12 merges) fixes them.
  - `ui/tools/screen-mirror.mjs` and `Screen/Registry.cls` take add-only edits from 20.38 (orchestrator ruling: reserved to 23.12 otherwise).
- **The browser spec** clicks a schema name, lands on the schema's screen, sees the Procedures rows of a schema that holds procedures, and opens one procedure.
- **Out of scope:** stored data and the installer (no upgrade check is expected, and the plan confirms that from its diff), editing schemas, and any change to what the tables, views and procedures screens show on their own. The merge report says whether the diff touches stored data, the installer, the start path, `module.xml` or compose.

### Rest of the epic

- **Every write** is a server-minted proposal. It carries a diff the instance computes, needs an explicit Confirm and carries an agent marker.
  - A new write key joins the governance baseline in the same change, and a destructive key ships `false`.
  - Each plan states the action's destructiveness, its key's default and its audit record.
  - Posture questions go to the orchestrator with options and a recommendation.
- **No compile-time dependency on interoperability.** No shipped class names an `Ens.*`, `EnsLib.*` or `EnsPortal.*` class where the compiler resolves it.
- **Secrets.** A secret-named setting reads as empty, and an attempt to set one is refused.
- **20.34, the cube manager.** Build and Synchronize run through `AnalyticsPort`.
  - **Gate.** `MANAGERPAIRS` plus WRITE on the fact global's database; a read-only database answers 409 `ANALYTICS.CUBE.READONLY`.
  - **Refused by name** before any vendor call: `ANALYTICS.CUBE.BUSY`, and for a synchronize also `ANALYTICS.CUBE.NODSTIME` and `ANALYTICS.CUBE.NOTBUILT`.
  - **Keys.** Build's key ships `false` and Synchronize's `true`. Repair is offered as Build.
  - **Running.** Vendor calls run inside an output capture. OcuPilot records its own `ConfigChange`.
  - DW-2485 rides along.
- **20.36, Investigate** is one more entry in the workflow catalog and adds no new mechanism.
  - **The entry:** no writes, `entry: true`, offered by no suggested prompt.
  - **Writes.** Every write in its turn answers `WORKFLOW.NOTASTEP`.
  - **The answer** is a recap and hypotheses ranked most likely first, citing the rows used.
  - **Never added:** a route, tool, key, screen, entity type or system-prompt sentence.
  - **Owns DW-2468 and DW-2469.** Step tools join the starting tool set, and `previous` reports only the same workflow's turns.
- **20.25, item runtime actions.** Temporary stop, start and restart, copy, and change of class, each over a fresh read through the interoperability port.
  - A runtime action is followed by the production update the vendor requires.
  - A vendor no-op is refused by name.
- **20.26, partner writes.** Each write is confirmed over a fresh read and records OcuPilot's own audit row.
  - A rename is refused or runs in one transaction.
  - A remove first reads the items that name the partner.
  - The pairs go to the orchestrator; the recommendation is `%Ens_ProductionConfig:WRITE`.

## Technical Decisions

- **One descriptor per screen.** A hand-written descriptor is the single source for route, gate, read tool, context and change events. Adding a screen means adding a descriptor, never editing a router, nav list or tool registry. `screens.generated.ts` is generated by `screen-mirror.mjs` and never hand-edited. Any new descriptor grammar is validated alike by `Screen/Registry.cls` and `screen-mirror.mjs`.
- **Tabbed screens.** A tabbed screen is one descriptor per tab, grouped by a declared `tab`.
  - A parent-scoped group's members name the same `parentScope` and its one criterion, and the strip carries the route id from tab to tab (a SQL table's catalog tabs).
  - Today a list's name cell opens a paired viewer only at `<list route>/document`, which is unlisted (side-bar position 0) and takes an id. Without one, the name links to the dead `<list route>/<id>`.
  - 20.38 uses that grammar: its schema screen is at `sql-schemas/document/<schema>` (runner ruling). Any change to the route or tab-group grammar goes to the orchestrator: a runner never amends an AD on its own.
- **Reads.** A screen's list and its read tool share one declared read: the same filter, fields and cap, reporting truncation and the applied `criteria`. A page may issue another built screen's read, and that screen's gate, cap and field set then apply unchanged, so it never widens.
- **The SQL catalog reads** go through `AtelierPort`.
  - **Gate:** `%Development:USE` plus READ on the namespace's code databases, resolved at call time. A refusal names the failed pair and is never an empty list.
  - **Statements:** fixed, with validated parameters only.
  - **Classic page:** these screens replace `%CSP.UI.Portal.SQL.Home`, whose custom resource also gates them. A new screen declares the classic page it replaces, or says it has none.
- **Ids** take one path segment, encoded and decoded by the shared pair only.
- **Screen context.** The kernel derives the context's `tools` from the screen's reads and actions on the instance, and refuses them in a request.
- **Client.** Zoneless, `OnPush`, and state held in a framework-free store, never a component field.
  - Each built page loads on demand: one loader line, and no static import from the initial bundle.
  - Bundle limits are a 2,500 kB warning and a 4,000 kB hard stop. A crossing is reported to the owner, never re-based.
- **Untrusted content** (vendor text, names, MDX, message bodies) reaches the screen only as interpolated text, and reaches the model only through the one sanitizer.
- **Stored state.** A new stored property is declared after every existing one, since the source carries no Storage section. `SCHEMAVERSION` moves only when a stored row's meaning changes.
- **Ports are the whole gate** for vendor production, partner, test, resend and analytics calls, which check no privilege themselves. Each checks the endpoint's pairs, the tool's pairs, then database READ (WRITE for a write). `InteropPort` alone controls productions, and its writes refuse vendor silent successes by name. `AnalyticsPort` calls `%DeepSee` in process, never `/api/deepsee`. Namespace switches use explicit save and restore.
- **Tests.**
  - No class depends on state another class left.
  - Run one test class at a time, and read results from `%UnitTest_Result`.
  - A browser spec runs against the deployed bundle, so rebuild and redeploy before reading a result.

## UX & Interaction Patterns

- **Gated controls are never hidden.** They stay focusable and `aria-disabled` and name the failed pair. An unlisted screen is reached from its list and never advertised.
- **Strings.** "Tables", "Views", "Procedures", "Schema" and "System items" already exist as fixed strings from the SQL catalog, so reuse them. A new string goes into EXPERIENCE.md's Fixed strings and `strings.ts` with a unique value and no internal ids. Other suites cite EXPERIENCE.md by line, so run `cd ui && npm run test:tools` after editing it.
- **Destructive actions.** A person's destructive action, such as the cube manager's Build, uses the typed-name confirm. Dialogs never stack.
- **Workflows.** The chip reads "Guided workflow", then Continue and End workflow. Investigate is gated like Explain this and sits beside it.

## Cross-Story Dependencies

- **Status.**
  - Done: 20.1 to 20.24, 20.27 to 20.33, 20.35 and 20.37.
  - 20.34 is ready for development.
  - 20.36's spec is written, but the tracker reads backlog.
  - 20.25, 20.26 and 20.38 are backlog.
- **Order.** 20.38 alone, then hold. On resume: 20.34, 20.36, 20.25, 20.26, then the burn-down.
- **20.38 builds on Epic 19's SQL catalog** (the schemas, tables, views and procedures lists and their viewers) and on the shared table's name-cell links.
- **Contention with Epic 23.** 20.38 runs beside 23.12 (slot A). 23.12 changes `Screen/Tool/Read.cls` (read descriptions), `Kernel/Agent/Prompt.cls`, and the labels on the task, database and log descriptors.
  - Check Epic 23's diff before editing a file. An add-only edit is fine; anything else in a file it changed is a Clarification.
  - The generated mirror and the roster unions resolve at integrate-forward: regenerate, or keep both sides.
  - If 23.12 merges first, integrate forward and push that merge alone before the code push.
- **20.34** consumes 20.11's port, error and probe types, 20.33's checks and 20.23's action-write shape. **20.36** consumes 20.12's catalog, workflow call, refusals and chip.
- **Shared rosters take add-only edits.** These include the governance baseline, `strings.ts`, the screen mirror, `ReadTool`, `ToolRoundTrip`, `ToolEmit` and `SurfaceCoverage`. `ToolWrite`'s other-port write count moves with 20.34, 20.25 and 20.26.
- **Known flakes:** DW-1822 (a Chrome protocol timeout in the a11y walk, which recurred on the 1.0.13 release PR), DW-2461, DW-2472 and DW-2493. Re-run a failed job once; a second red on the same head is a story red.
- **Epic 21 waits on this epic.** 21.8 waits on 20.11, and 21.7 and 21.11 wait on all of Epic 20.
