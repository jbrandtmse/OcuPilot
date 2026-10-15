# Epic 20 Context: Stage 4 - Interoperability, with the Analytics rider

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Bring the classic portal's Interoperability work into OcuPilot for namespaces that support it, with Analytics riding along, and give the agent guided workflows and Investigate, so the largest area the classic portal still owns can be used here. Already shipped: category gating, productions and their items and settings, per-host tabs, the monitor, queue and job actions, lookup tables, read-only business partners, host and transformation tests, the interoperability floor, per-screen permissions, the agent's source reads, saves and creates, the embedded rule, BPL and DTL editors with the agent's edits behind them, the schema viewer and configuration diagram, message search, contents, session trace, resend and edit-and-resend, and source-control hooks (20.10). Ready for development: the analytics stories 20.11, 20.32, 20.33, 20.35 and 20.34, and 20.12 (guided workflows). The next story to plan is 20.36, Investigate, which reuses 20.12's workflow catalog. After it come 20.25 (item runtime actions) and 20.26 (partner writes), then the burn-down.

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

- **Every write** is a server-minted proposal with a diff the instance computes, an explicit Confirm and an agent marker. A new write key joins `Kernel/Governance/Baseline` in the same change, and a destructive key ships `false`. Each plan states the action's destructiveness, its key's default and its audit record.
- **Posture questions** go to the orchestrator, with options and a recommendation.
- **No compile-time dependency on interoperability.** No shipped class names an `Ens.*`, `EnsLib.*` or `EnsPortal.*` class where the compiler resolves it. `OcuPilot.Test.CompileWithoutInterop` and CI's `package` job enforce this.
- **Secrets and paths.** A secret-named setting reads as empty, and an attempt to set one is refused. No endpoint accepts a path outside AD-21's cases.

### Guided workflows and Investigate (AD-66)

- **The catalog is data.** It is `Kernel/Agent/Workflow`'s `XData Catalog`, and a new workflow is a new entry, never a code path. Ids match `^[a-z][a-z0-9]*$`, all text is ASCII, and no text names an `iris_` tool. 20.12 ships the nine harvested workflows, renamed. Backup (21.2) and promote (21.9) get none until their tools exist (named limit).
- **Naming a workflow.** A turn names one in its body's `workflow`. An unknown id is refused 422 `WORKFLOW.UNKNOWN`, before the reserve, and the id is recorded on the turn row at begin. A screen offers a workflow through a suggested prompt's `workflow` key (AD-5).
- **The synthetic pair.** The loop adds a `workflow` call and result after screen context. It holds catalog constants plus `previous`: the previous turn's proposals as closed-vocabulary `{tool, state, closedReason, readBack}`, at most 10. It is never advertised (a model call named `workflow` is `TOOL.UNKNOWN`), it is sanitized, and it counts within the context bound (AD-11, AD-24, AD-60).
- **Two dispatcher refusals,** both tool results that mint nothing: a write no step names (`WORKFLOW.NOTASTEP`), and a second proposal in the same turn (`WORKFLOW.ONECHANGE`).
- **Writes are unchanged.** Each is an ordinary proposal through the existing mint, card and Confirm. The prohibited set, both switches and governance are evaluated at the write (AD-40).
- **Never:** a batch approval, a control that confirms more than one proposal, an automatic continue, a turn that waits for a confirm, a new engine or background process, or per-workflow text in the system prompt. Production `clean` is never offered.
- **Resend.** `resendmessages` meets `GOVERNANCE.DISABLED` until an administrator enables `interop.messages.resend`, which ships `false`.
- **Investigate (20.36, next to plan).** From an alert or a log entry, a multistep run returns a recap and hypotheses ranked most likely first, citing the rows it used. Its charter, drafted in 20.12's spec:
  - an Investigate control beside every Explain this entry: the log-viewer rows, the error log's row menu, the audit dialog and the log hub;
  - it extends `core/explain-entry.ts` with a kind, under the same gate;
  - it sends the DW-1838 entry marker with `workflow: "investigate"`. That is a catalog entry with no writes, offered by no prompt, so every write is refused;
  - a cited row from a citable read becomes a chip (AD-11's citation clause).
  - **Named limits:** log-viewer rows (id `none`) are cited as text, and managed alerts do not exist until 21.7.

### Analytics (AD-65)

- **One port.** `Port/AnalyticsPort` (20.11) calls the vendor's `%DeepSee` classes in process, as the signed-in person. It never calls `/api/deepsee`, `%Api.DeepSee` or `%DeepSee.REST.*` (DW-2416, under the owner's hold). Every analytics story extends this port.
  - **Gate order, before any vendor call:** the endpoint's pairs; the namespace's shape; that the namespace reports analytics, else 409 `ANALYTICS.NAMESPACE`; READ on the namespace's globals and routines databases.
  - **The vendor's own checks still apply:** `%CheckPrivilege` for cubes and `%CheckResource()` for folder items.
  - **Reads only where measured to write nothing.** Never `%GetMemberTree`, `%GetDimensionMembers` or `%GetFavoritesForUser`. The port prepares no statement of its own.
- **MDX text that runs code or SQL** (`%SEARCH`, `%SQLRESTRICT`, `RETURN`, `%ORDER`, `%PARM`). One detector, `AnalyticsPort.MdxConstructs` (20.33), reads the vendor's tokens and each quoted string's tokens, before prepare and again on the variable-resolved text, and fails closed. The person's screen asks first, as their own step rather than an AD-6 proposal. The agent's read refuses with `ANALYTICS.MDX.SQL`. Stored definitions are not inspected (DW-2451, accepted).
- **Measured vendor facts.**
  - The vendor classes check no `%DeepSee_*` resource, and the API floor admits none, so an analytics-only account is refused (changing that is the owner's call).
  - USER and HSCUSTOM do not report analytics, so the browser specs walk USER, which `Test/AnalyticsProbe` enables and then restores.
  - Each cookieless classic DeepSee page load holds a license unit for 900 s, so no test loads those pages repeatedly.
  - MDX writes the vendor's cache, so it needs WRITE, and a read-only database is refused 409 `ANALYTICS.MDX.READONLY`. `%CancelQuery` checks no owner, so OcuPilot's run row is the owner check.
- **The planned surfaces** (their specs carry the details):
  - **20.11:** source kind `analytics` with seven `LIST` endpoints. Cubes with its tabs, Term lists, and Folder items, which needs `%Development:USE`. Side-bar positions 1 to 3.
  - **20.32:** Architect, Analyzer and the User Portal as `external` links at positions 4 to 6. Each opens in a new tab with `noopener` and is never framed.
  - **20.33:** MDX query at position 7, requiring `%DeepSee_Portal:USE` plus `%Development:USE`. Only `SELECT` with at most two axes, and `DRILLTHROUGH`, run, as an owner-scoped background run whose answer stays on the screen.
  - **20.35:** `analytics.mdxquery.read` runs in the turn job through `MdxRun`, under the MDX pairs and caps. It reserves no background run.
  - **20.34:** the Cube manager at position 8, requiring `%DeepSee_Admin:USE`, which no shipped role but `%All` holds.
    - Build and Synchronize are action-style row actions over a port-composed `STATE` spanning the cube and its dependents. They add WRITE on `^DeepSee.Fact`'s database (read-only: 409 `ANALYTICS.CUBE.READONLY`).
    - **Keys:** `analytics.cubemanager.build` ships `false` (it kills the facts first). `analytics.cubemanager.synchronize` ships `true`. Repair is offered as Build.
    - **Refused by name:** `ANALYTICS.CUBE.BUSY`, and for a synchronize `ANALYTICS.CUBE.NODSTIME` and `ANALYTICS.CUBE.NOTBUILT`.
    - **Ruled at its gate:** the write runs in its confirm or action request, and a build that outlasts the gateway timeout loses its answer. The vendor audits nothing, so OcuPilot records its own `ConfigChange`. The user code a build runs is a named limit.
- **Out of this epic:** term-list editing; folder export, import and delete; analytics settings and the cube registry's edits (Epic 21's 21.8); Text Analytics; rebuilt Architect, Analyzer or User Portal.

### Interoperability still to build

- **20.25, item runtime actions:** temporary stop, start and restart of one item, copy, and change of class.
  - A runtime action is followed by the production update the vendor requires.
  - A vendor no-op (a stopped production, a disabled item) is refused by name before any vendor call.
  - It owns DW-2407: it names and moves `ToolWrite`'s other-port write count.
- **20.26, partner writes** on `Ens.Config.BusinessPartner`. Each is confirmed over a fresh read and records OcuPilot's own audit row, since the vendor records none.
  - A rename is refused, or runs in one transaction.
  - A removal first reads the items whose `BusinessPartner` setting names the partner.
  - Its pairs are an orchestrator question. 20.5's plan recommends `%Ens_ProductionConfig:WRITE`.

## Technical Decisions

- **Ports are the whole gate (AD-29).** The vendor's production, partner, test, resend and analytics calls check no privilege (measured), so each port gates first.
  - **Order:** the endpoint's pairs, then the tool's own pairs, then database READ (WRITE for a write). A refusal names the failed pair.
  - **Extra pairs** are declared only where a least-privileged run measured them.
  - **The floor** admits `%Ens_Portal:USE`, so every new surface declares its own pair.
- **`InteropPort` (AD-62)** is the only class that controls a production. A new read or write names its case in AD-62 at its spec gate, and a read also names it in AD-36. Each in-process port keeps its own private `Deny`, `Refuse` and `Conflict`.
- **Source control (20.10, AD-61).** OcuPilot's saves, compiles and deletes run the namespace's source-control hooks in the caller's process through `AtelierPort`. An unreleased document is refused 409 `EXPLORER.DOCUMENT.SOURCECONTROL`. The embedded editors exchange their hooks inside the frame themselves.
- **Classic pages (AD-44, AD-64).** Each descriptor declares, in `CLASSICPAGES`, the classic page it replaces or opens, using the class name as read on the instance. `Screen.Gate.RequiredPairs` is the one reader of a screen's requirement.
- **SQL and namespace.** `InteropPort` reads through `SqlRows`, with `%ExecDirectNoPriv` after its own gate. No statement nests a query that carries `TOP`. A port switches namespace by explicit save and restore and calls no `OcuPilot.*` class while switched (AD-16).
- **Background runs (AD-7, AD-41, AD-42).**
  - A background run never mutates. Each run carries a kind, and a user may have one live run per kind and the instance five across all kinds. The answer is held for its owner alone and swept 900 s after the run ends. Another user's run reads as 404.
  - 20.33 plans `Kernel/Shell/BackgroundRun`, shared by the SQL console and MDX.
  - No write is a background run: 20.34's build and synchronize and every workflow write run in their confirm or action request.
- **Write shape (AD-51 to AD-53).**
  - An action-style write declares its request type and fingerprints a fresh read that the port composes. A screen's action and the agent's write are one operation, and a person's action is never put to governance.
  - Each write finishes in its own confirm request.
  - Every port with `Invoke` also defines a pure `Snippet`.
  - A `DRYRUN` tool is reviewed through `POST /screens/:screen/dryrun` (20.31).
- **OcuPilot's stored state.**
  - A property added to a `%Persistent` class of OcuPilot's state is declared after every existing one. A rename or removal needs a migration step.
  - `SCHEMAVERSION` moves only when a stored row's meaning changes. A changed index definition does not move it: the installer refuses a stored version newer than the code (DW-2456, decided by design).
- **Compile order.** A `Parameter` whose `{...}` value names a project class needs `Extends` or `DependsOn` on that class. Without it, a fresh container compile fails `LOAD-FAILED` (DW-2459).
- **Reads and ids (AD-13, AD-36).** Every read has a row cap and reports truncation. An id keeps every part exactly, in one percent-encoded segment.
- **Client (AD-5, AD-19).**
  - Every screen route loads through `rememberedPage(loader)`. `screens.generated.ts` is generated and never hand-edited.
  - The client is zoneless and `OnPush`, with screen state in framework-free stores.
  - **Bundle:** 1.96 MB after 20.10. The owner set `maximumWarning` to 2,500 kB, with 4,000 kB as the hard stop. A crossing is reported to the owner, never re-based. Each lazy chunk stays under 88 kB.
- **Embedded vendor apps (AD-63).** The same-origin frame is the one exception to AD-47's inert embeds, and only for the interoperability editors. OcuPilot never navigates, posts into or reads from the frame. Analytics pages are linked, never framed.
- **Tools.** Names follow `<area>.<screen>.<verb>`, and each tool declares `CLASSICPAGES`. Each new write is reviewed against the prohibited set. For Gemini, numeric enums stay at the schema's top level.
- **Untrusted content (AD-11, AD-60).** This covers message bodies and headers, settings, log text, cube, member, term and folder-item names, MDX statements, cells and listings, and the vendor's error text. It reaches the screen only as interpolated text, and the model only through the one sanitizer.
- **Reuse rather than copy (Rule 31).**
  - **Server:** `SqlRows`, `LocalStamp`, `SecretPath`, `Ledger.LocalToUtc`, the SQL console's background run, and for workflows `Loop.Run`'s opening builder and the `Guarded*ForTurn` readers.
  - **Client:** `DataTable`'s getters, `core/read-state.ts`, `shell/read-state-blocks.ts`, `core/explain-entry.ts`, `followInAppLink`, `pickCount`, the typed-name dialog, `WarningDialog`, and `classifyFault` with `classifyFailure`.
  - **Tests:** `runIris`, `list-spec.mjs`, `MintAs`, `ConfirmHttp`, `ProductionProbe`, `AnalyticsProbe`, `TurnToolsCase`, `TurnWireFixture`, `TurnProvider`, `GovernanceFixture`, `SwitchFixture`, and the floors' principals.
- **Measure on the instance**, and amend the spine at the spec gate rather than work around it.

## UX & Interaction Patterns

- **Rail and side bar.** Interoperability and Analytics appear only where the namespace reports the feature. A screen joins the side bar only once it ships. Analytics positions 1 to 8 are planned (20.11, 20.32, 20.33, 20.34).
- **Tabs.** An item has Status, Settings, Queue, Log, Messages, Jobs and Test. A message has Header, Contents and Trace. A cube has Measures, Dimensions and Relationships.
- **New tabs** open only where EXPERIENCE.md names them: the classic-link card, a `rowLink` exemption, and 20.32's links.
- **Dialogs** appear only where EXPERIENCE.md's dialog list names one, and never stack. A destructive screen action uses the typed-name confirm, as the Cube manager's Build does.
- **Gated controls are never hidden.** They stay focusable and `aria-disabled`, and name the failed pair or reason.
- **The workflow chip (20.12)** sits above the composer while a workflow is active, with Continue and End workflow. Every send while it shows carries the workflow; a workflow prompt replaces it; End workflow, a new conversation or the session's end clears it. Continue is `aria-disabled`, naming why, while a turn runs or a proposal card is live. It never confirms, cancels or closes a proposal.
- **Investigate (20.36)** sits beside each Explain this entry and answers as a Recap and ranked Hypotheses, each naming its rows in backticks.
- **Strings.**
  - Each list or tab has a title, an empty state and three suggested prompts.
  - Every new string goes into EXPERIENCE.md's Fixed strings and `strings.ts`, with a unique value. A count reads singular at 1, through `pickCount`.
  - A refusal sentence lives once, on the server. `strings.test.mjs` caps the literals at 3,800.
- **Cards.** An agent's destructive proposal carries no typed name. A block over about eight lines starts collapsed, and Confirm never requires expanding it.

## Cross-Story Dependencies

- **Status.** Done: 20.1 to 20.10, 20.13 to 20.24, and 20.27 to 20.31. Ready for development: 20.11, 20.12, 20.32, 20.33, 20.34 and 20.35. Backlog: 20.36, 20.25 and 20.26.
- **Order.** 20.11, 20.32, 20.33, 20.35, 20.34, 20.12, 20.36, 20.25, 20.26, then the burn-down. A story planned against a predecessor that is not yet built re-anchors on the shipped code at Task 0.
- **20.36 consumes** 20.12's catalog, its synthetic `workflow` call and its refusals, and the explain-entry marker and citation chips already shipped.
- **20.12 consumes** 20.19 and 20.21 (source read, save and compile), 20.2 and 20.31 (the production and resend writes), and 20.30 (`interop.messagetrace.read`). 20.34's synchronize may join a workflow (inference).
- **20.34 consumes** 20.11's port, `AnalyticsError`, `AnalyticsProbe`, gate principals, `cube` type and Cubes' Last build and Facts. It also takes 20.33's destination check and 20.23's action-write shape. `Screen/Tool/AnalyticsAction` follows `InteropAction` rather than sharing a parent.
- **20.35** consumes 20.33's `MdxAdmit`, `MdxConstructs`, `MdxPrepare` and `MDX*` caps.
- **Epic 21 waits on this epic.** 21.6 extends `slowquery` and waits for 20.12 on feature. 21.8 waits for 20.11 and may extend the Cube manager (inference). 21.7 and 21.11 wait for all of Epic 20. 21.2 and 21.9 add their workflows as data.
- **Shared rosters take add-only edits:**
  - entity types, the screen mirror, `strings.ts`, EXPERIENCE.md's rows and the navigation tests;
  - `ReadTool`, `ToolRoundTrip`, `ToolEmit` and `SurfaceCoverage`, which holds write tools only;
  - `PortGate`'s `ROSTER`, the governance baseline, `StageTwoTools`' `Elsewhere` block, and the `InteropFloor` and `DeveloperFloor` rosters;
  - `ToolWrite`'s other-port write count, now 51. Every write that reaches its target through a non-admin port moves it, including 20.34's, 20.25's and 20.26's (DW-2407).
- **Ask first** before editing anything else contended:
  - `Screen/Registry.cls` and `Screen/Read.cls` beyond add-only, and `Kernel/EntityType.cls`;
  - the prohibited set, `Kernel/Proposal/*` and `LogSourcePort`;
  - `app.routes.ts`, `angular.json` and the CI files.
- **Epic 23 in parallel.** 23.5 is done, and its batch d (`data-table.ts`, `detail-page.ts`, `Registry.cls`, `screen-mirror.mjs`, `_components.scss`) is merged forward. 23.11 now runs on slot A. 20.12 edits `Registry.cls`, the mirror, `screens.generated.ts`, EXPERIENCE.md, DESIGN.md and `_components.scss` add-only, so forward merges can conflict there (inference).
- **Known defects.**
  - **On the owner's hold:** DW-2394, DW-2396 and DW-2416.
  - **Burn-down:** DW-1280 (the agent save's source-control refusal shows a generic card reason), DW-2408, DW-2452, DW-2457 (a target over 2,200 characters fails its mint with 500 rather than a field refusal) and DW-2459.
  - **Owner decision pending:** DW-2420 and DW-2442.
  - **CI flakes:** DW-2458 (log-viewer AC6, owned by 23.11) and DW-2461 (encryption-startup browser spec). Re-run the failed job once; a second red on the same head is a story red.
