# Epic 20 Context: Stage 4 - Interoperability, with the Analytics rider

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Bring the classic portal's Interoperability work into OcuPilot for namespaces that support it, with Analytics riding along, and give the agent guided multistep workflows and Investigate, so the largest area the classic portal still owns can be used here. Already shipped: category gating, productions with their items and settings, per-host tabs, the monitor, queue and job actions, lookup tables, read-only business partners, host and transformation tests, per-screen permissions, the agent's source reads, saves and creates, the embedded rule, BPL and DTL editors with the agent's edits behind them, the schema viewers and configuration diagram, messages (search, contents, trace, resend), source-control hooks, and guided workflows (20.12). Still to build: the Analytics rider (20.11, 20.32, 20.33, 20.35, 20.34), Investigate (20.36), item runtime actions (20.25) and partner writes (20.26), then the burn-down.

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

## Requirements & Constraints

- **Every write** is a server-minted proposal with a diff the instance computes, an explicit Confirm and an agent marker. A new write key joins the governance baseline in the same change, and a destructive key ships `false`. Each plan states the action's destructiveness, its key's default and its audit record.
- **Posture questions** go to the orchestrator, with options and a recommendation.
- **No compile-time dependency on interoperability.** No shipped class names an `Ens.*`, `EnsLib.*` or `EnsPortal.*` class where the compiler resolves it (`OcuPilot.Test.CompileWithoutInterop` and CI's `package` job enforce it).
- **Secrets and paths.** A secret-named setting reads as empty and setting one is refused. No endpoint accepts a path outside AD-21's cases.

### Analytics (AD-65)

- **One port.** `Port/AnalyticsPort` calls the vendor's `%DeepSee` classes in process, as the signed-in person, never `/api/deepsee`, `%Api.DeepSee` or `%DeepSee.REST.*`. Every analytics story extends it.
  - **Gate order, before any vendor call:** the endpoint's pairs; the namespace's shape; that the namespace reports analytics, else 409 `ANALYTICS.NAMESPACE`; READ on the namespace's globals and routines databases. The vendor's own `%CheckPrivilege` (cubes) and `%CheckResource()` (folder items) still apply.
  - **Reads only where measured to write nothing.** Never `%GetMemberTree`, `%GetDimensionMembers` or `%GetFavoritesForUser`. The port prepares no statement of its own.
- **MDX that runs code or SQL** (`%SEARCH`, `%SQLRESTRICT`, `RETURN`, `%ORDER`, `%PARM`): one detector, `AnalyticsPort.MdxConstructs`, reads the vendor's tokens and each quoted string's tokens, before prepare and again on the variable-resolved text, and fails closed. The person's MDX screen asks first in plain words (their own step, not a proposal); the agent's read refuses with `ANALYTICS.MDX.SQL`. Stored definitions are not inspected (accepted limit).
- **Measured vendor facts.** The vendor checks no `%DeepSee_*` resource, so an analytics-only account is refused by the API floor (the owner's call to change). USER and HSCUSTOM do not report analytics, so browser specs walk USER, which `Test/AnalyticsProbe` enables and restores. Each classic DeepSee page load holds a license unit for 900 s, so no test loads those pages repeatedly. MDX writes the vendor's cache and needs WRITE (read-only: 409 `ANALYTICS.MDX.READONLY`). `%CancelQuery` checks no owner, so OcuPilot's run row is the owner check.
- **Surfaces:**
  - **20.11:** source kind `analytics`, seven `LIST` endpoints; Cubes (tabs Measures, Dimensions, Relationships), Term lists, Folder items (needs `%Development:USE`); side-bar positions 1 to 3.
  - **20.32:** Architect, Analyzer and the User Portal as `external` link screens at positions 4 to 6, opened in a new tab with no opener, never framed or rebuilt.
  - **20.33:** MDX query at position 7 (`%DeepSee_Portal:USE` plus `%Development:USE`). Only `SELECT` with at most two axes, and `DRILLTHROUGH`, run as an owner-scoped background run with a row cap, time bound and cancel; never a write.
  - **20.35:** `analytics.mdxquery.read` runs in the turn job through `MdxRun` under the MDX pairs and caps, reserving no background run. Rosters: `ReadTool`, `ToolRoundTrip`, `ToolEmit`, `DeveloperFloor`; no `SurfaceCoverage` row.
  - **20.34:** the Cube manager at position 8 (`%DeepSee_Admin:USE`, held by no shipped role but `%All`). Build and Synchronize are action-style row actions over a port-composed `STATE` spanning the cube and its dependents, adding WRITE on `^DeepSee.Fact`'s database (read-only: 409 `ANALYTICS.CUBE.READONLY`). `analytics.cubemanager.build` ships `false` (it kills facts first); `analytics.cubemanager.synchronize` ships `true`; Repair is offered as Build. Refused by name: `ANALYTICS.CUBE.BUSY`, and for a synchronize `ANALYTICS.CUBE.NODSTIME` and `ANALYTICS.CUBE.NOTBUILT`. The write runs in its confirm or action request; a build outlasting the gateway timeout loses its answer. The vendor audits nothing, so OcuPilot records its own `ConfigChange`.
- **Out of this epic:** term-list editing; folder export, import and delete; analytics settings and cube-registry edits (21.8); Text Analytics; rebuilt Architect, Analyzer or User Portal.

### Investigate (20.36) over guided workflows (AD-66)

- **One more catalog entry, no new mechanism.** `investigate` is data in `Kernel/Agent/Workflow`'s `XData Catalog`: no `writes`, `entry: true`, offered by no suggested prompt, every `reads` name resolving as `read`. Every write in the turn answers `WORKFLOW.NOTASTEP` and mints nothing; the finish tells the model to name the workflow or screen that would make a fix.
- **The control** sits beside every Explain this entry (log-viewer rows, the error log's row menu, the audit dialog, the log hub's source and timeline). It extends `core/explain-entry.ts` with a kind under the same gate, and sends "Investigate the selected entry" with the same entry marker and `workflow: "investigate"`; the workflow then rides every send until ended, replacing any active one.
- **The answer:** a Recap and Hypotheses ranked most likely first, each naming its rows in backticks; a row from a citable read becomes a citation chip. Named limits: log rows get no chip (their ids are `none` or composites), and "an alert" means an alerts.log row until 21.7's managed alerts.
- **Never:** a new route, tool, governance key, screen, descriptor, entity type, suggested prompt or system-prompt sentence.
- **Owns two defects from 20.12:** DW-2468 (a step's tools are not in the turn's starting tool set, so off-screen the model finds them via `shell_tools_find`) and DW-2469 (`previous` reports the newest earlier turn whatever workflow it ran; report it only when that turn ran the same workflow).
- **Workflow invariants still binding:** never a batch approval, a control that confirms more than one proposal, an automatic continue, a turn that waits for a confirm, a new engine or background process, or per-workflow system-prompt text; production `clean` is never offered. The prohibited set, both switches and governance are evaluated at each write.

### Interoperability still to build

- **20.25, item runtime actions:** temporary stop, start and restart of one item, copy, and change of class, each over a fresh read through the interoperability port. A runtime action is followed by the production update the vendor requires; a vendor no-op (stopped production, disabled item) is refused by name before any vendor call. Copy and change class are audited by the vendor.
- **20.26, partner writes** on `Ens.Config.BusinessPartner`, each confirmed over a fresh read and recording OcuPilot's own audit row (the vendor records none). A rename is refused or runs in one transaction; a removal first reads the items whose `BusinessPartner` setting names the partner. Its pairs go to the orchestrator (`%Ens_ProductionConfig:WRITE` recommended).

## Technical Decisions

- **Ports are the whole gate (AD-29).** The vendor's production, partner, test, resend and analytics calls check no privilege, so each port gates first: the endpoint's pairs, then the tool's own pairs, then database READ (WRITE for a write). A refusal names the failed pair. The API floor admits `%Ens_Portal:USE`, so every new surface declares its own pair.
- **`InteropPort` (AD-62)** is the only class that controls a production. A new read or write names its case in AD-62 at its spec gate (a read also in AD-36). Each in-process port keeps its own private `Deny`, `Refuse` and `Conflict`.
- **SQL and namespace.** `InteropPort` reads through `SqlRows` with `%ExecDirectNoPriv` after its own gate; no statement nests a query carrying `TOP`. Namespace switches are explicit save and restore, calling no `OcuPilot.*` class while switched.
- **Background runs.** A background run never mutates; one live run per user per kind, five per instance; the answer is held for its owner alone and swept 900 s after the run ends; another user's run reads as 404. 20.33 plans `Kernel/Shell/BackgroundRun`, shared by the SQL console and MDX.
- **Write shape.** An action-style write declares its request type and fingerprints a fresh read the port composes; a screen's action and the agent's write are one operation, and a person's action is never put to governance. Each write finishes in its own confirm request. Every port with `Invoke` also defines a pure `Snippet`.
- **Descriptors (AD-5).** Each descriptor declares in `CLASSICPAGES` the classic page it replaces, by the class name read on the instance; `Screen.Gate.RequiredPairs` is the one reader of a screen's requirement. A list, and now also a tab of a tabbed group (a `detail` screen drawing a table), may declare one cross-screen row target: the cube's Relationships tab opens the related cube's Measures tab (owner answer U-1). An `external` screen declares no read, table, action, tab or parent scope.
- **OcuPilot's stored state.** A property added to a `%Persistent` state class goes after every existing one; a rename or removal needs a migration step. `SCHEMAVERSION` moves only when a stored row's meaning changes.
- **Compile order.** A `Parameter` whose `{...}` value names a project class needs `Extends` or `DependsOn` on it, or a fresh container compile fails `LOAD-FAILED`.
- **Reads and ids.** Every read has a row cap and reports truncation; an id keeps every part, in one percent-encoded segment.
- **Client.** Zoneless and `OnPush`, screen state in framework-free stores; every screen route loads through `rememberedPage(loader)`; `screens.generated.ts` is generated, never hand-edited. Bundle: 1.97 MB initial after 20.12; warning 2,500 kB, hard stop 4,000 kB; a crossing is reported to the owner, never re-based.
- **Frames.** Only the interoperability editors run in a same-origin frame, which OcuPilot never navigates, posts into or reads. Analytics pages are linked, never framed.
- **Tools.** Names follow `<area>.<screen>.<verb>`; each declares `CLASSICPAGES`; each new write is reviewed against the prohibited set. For Gemini, numeric enums stay at the schema's top level.
- **Untrusted content** (message bodies and headers, settings, log text, cube, member, term and folder-item names, MDX statements, cells and listings, the vendor's error text) reaches the screen only as interpolated text and the model only through the one sanitizer.
- **Reuse rather than copy.** Server: `SqlRows`, `LocalStamp`, `SecretPath`, `Ledger.LocalToUtc`, the SQL console's background run, `Loop.Run`'s opening builder and the `Guarded*ForTurn` readers. Client: `DataTable`'s getters, `core/read-state.ts`, `shell/read-state-blocks.ts`, `core/explain-entry.ts`, `followInAppLink`, `pickCount`, the typed-name dialog, `WarningDialog`, `classifyFault`/`classifyFailure`. Tests: `runIris`, `list-spec.mjs`, `MintAs`, `ConfirmHttp`, `ProductionProbe`, `AnalyticsProbe`, `TurnToolsCase`, `TurnWireFixture`, `TurnProvider`, `GovernanceFixture`, `SwitchFixture`, the floors' principals.
- **Measure on the instance**, and amend the spine at the spec gate rather than work around it.

## UX & Interaction Patterns

- **Rail and side bar.** Interoperability and Analytics appear only where the namespace reports the feature; a screen joins the side bar only once it ships. Analytics positions 1 to 8 as above.
- **Tabs.** A cube has Measures, Dimensions and Relationships; a term list's name cell opens its entries.
- **New tabs** open only where EXPERIENCE.md names them: the classic-link card, a `rowLink` exemption, and 20.32's links.
- **Dialogs** appear only where EXPERIENCE.md's dialog list names one, and never stack. A person's destructive screen action (the Cube manager's Build) uses the typed-name confirm; an agent's destructive card carries none.
- **Gated controls are never hidden:** focusable, `aria-disabled`, naming the failed pair or reason. Investigate is gated exactly like Explain (kill switch, a running turn, sharing off).
- **The workflow chip** above the composer reads "Guided workflow" with the starting text (for Investigate, "Investigate this entry"), with Continue and End workflow. End workflow, a new conversation or sign-out clears it.
- **Strings.** Each list or tab has a title, an empty state and three suggested prompts. Every new string goes into EXPERIENCE.md's Fixed strings and `strings.ts` with a unique value; a count reads singular at 1 through `pickCount`; a refusal sentence lives once, on the server.

## Cross-Story Dependencies

- **Status.** Done: 20.1 to 20.10, 20.12 to 20.24, 20.27 to 20.31. Ready for development: 20.32, 20.33, 20.34, 20.35 and 20.36 (spec). 20.11 is back in draft: its re-plan re-applies its set-aside patches over 20.12's `strings.ts` additions (an append-only union). Backlog: 20.25, 20.26.
- **Order.** 20.11, 20.32, 20.33, 20.35, 20.34, 20.36, 20.25, 20.26, then the burn-down. A spec planned against an unbuilt predecessor re-anchors on shipped code at Task 0.
- **20.36 consumes** 20.12's catalog, synthetic `workflow` pair, refusals and chip, plus the shipped explain-entry marker and citation chips.
- **20.34 consumes** 20.11's port, `AnalyticsError`, `AnalyticsProbe`, gate principals, `cube` type and Cubes' Last build and Facts, 20.33's destination check and 20.23's action-write shape; `Screen/Tool/AnalyticsAction` follows `InteropAction` rather than sharing a parent. **20.35 consumes** 20.33's `MdxAdmit`, `MdxConstructs`, `MdxPrepare` and `MDX*` caps.
- **Epic 21 waits on this epic.** 21.6 extends the slow-query workflow once 20.12 reaches feature; 21.8 waits for 20.11; 21.7 and 21.11 wait for all of Epic 20; 21.2 and 21.9 add their workflows as catalog data.
- **Shared rosters take add-only edits:** entity types, the screen mirror, `strings.ts`, EXPERIENCE.md's rows, the navigation tests; `ReadTool`, `ToolRoundTrip`, `ToolEmit`, `SurfaceCoverage` (write tools only); `PortGate`'s `ROSTER`, the governance baseline, `StageTwoTools`' `Elsewhere` block, the `InteropFloor` and `DeveloperFloor` rosters; `ToolWrite`'s other-port write count, now 51, which every non-admin-port write moves (20.34, 20.25 and 20.26; DW-2407, owned by 20.25).
- **Ask first** before editing anything else contended: `Screen/Registry.cls` and `Screen/Read.cls` beyond add-only, `Kernel/EntityType.cls`, the prohibited set, `Kernel/Proposal/*`, `LogSourcePort`, `app.routes.ts`, `angular.json` and the CI files.
- **Epic 23 runs in parallel** (23.11 on slot A); forward merges can conflict in `Registry.cls`, the mirror, `strings.ts`, EXPERIENCE.md and `_components.scss` (inference).
- **Known defects.** Owner's hold: DW-2394, DW-2396, DW-2416. Owner decision pending: DW-2420, DW-2442. Burn-down: DW-1280, DW-2408, DW-2452, DW-2457, DW-2459. Flakes (re-run the failed job once; a second red on the same head is a story red): DW-2236, DW-2461.
