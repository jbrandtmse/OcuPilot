# Epic 20 Context: Stage 4 - Interoperability, with the Analytics rider

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Bring the classic portal's Interoperability work into OcuPilot for namespaces that support it, with Analytics riding along, so the largest area the classic portal still owns can be used here. Already shipped: category gating, productions and their items and settings, per-host tabs, the monitor, queue and job actions, lookup tables, read-only business partners, host and transformation tests, the interoperability floor, per-screen permissions, the agent's source reads, saves and creates, the embedded rule, BPL and DTL editors with the agent's edits behind them, the schema viewer and configuration diagram, message search, contents and session trace, and message resend and edit-and-resend (20.31). Ready for development: 20.10 (source control), 20.11 (the analytics port and its read screens), 20.32 (the analytics links), 20.33 (the MDX query tool) and 20.35 (the agent's MDX read). The next story to plan is 20.34, the cube manager's build and synchronize, which is the one analytics write in this stage. After it come 20.12 (guided workflows and Investigate), 20.25 (item runtime actions) and 20.26 (partner writes), then the burn-down.

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

## Requirements & Constraints

- **Every write** is a server-minted proposal with a diff the instance computes, an explicit Confirm and an agent marker. A new write key joins `Kernel/Governance/Baseline` in the same change, and a destructive key ships `false`. Each plan states the action's destructiveness, its key's default and its audit record.
- **Posture questions** go to the orchestrator, with options and a recommendation.
- **No compile-time dependency on interoperability.** No shipped class names an `Ens.*`, `EnsLib.*` or `EnsPortal.*` class where the compiler resolves it. `OcuPilot.Test.CompileWithoutInterop` and CI's `package` job enforce this.
- **Secrets and paths.** A secret-named setting reads as empty, and an attempt to set one is refused. No endpoint accepts a path outside AD-21's cases.

### Analytics (AD-65)

- **One port.** `Port/AnalyticsPort` (20.11) calls the vendor's `%DeepSee` classes in process, as the signed-in person. It never calls `/api/deepsee`, `%Api.DeepSee` or `%DeepSee.REST.*` (DW-2416, under the owner's hold). Every analytics story extends this port.
  - **Gate order, before any vendor call:** the endpoint's pairs; the namespace's shape; that the namespace reports analytics, else 409 `ANALYTICS.NAMESPACE`; READ on the namespace's globals and routines databases.
  - **The vendor's own checks still apply:** `%CheckPrivilege` for cubes and `%CheckResource()` for folder items.
  - **Reads only where measured to write nothing.** Never `%GetMemberTree`, `%GetDimensionMembers` or `%GetFavoritesForUser`. The port prepares no statement of its own.
- **MDX text that runs code or SQL.** `%SEARCH`, `%SQLRESTRICT`, `RETURN`, `%ORDER` and `%PARM` make the vendor run ObjectScript or SQL with the caller's rights.
  - **One detector,** `AnalyticsPort.MdxConstructs` (20.33). It reads the vendor's own tokens and each quoted string's tokens, runs before prepare and again on the variable-resolved text, and fails closed.
  - **The person's screen asks first** ("This query runs server-side code or SQL with your rights."). That confirmation is the person's own step, not an AD-6 proposal.
  - **The agent's read refuses** such text with `ANALYTICS.MDX.SQL`.
  - **Named limits:** stored definitions are not inspected (DW-2451, accepted). SQL computed dimensions and `%KPI` classes are the cube author's code.
- **Measured vendor facts.**
  - The vendor classes check no `%DeepSee_*` resource. The API floor admits none, so an analytics-only account is refused; changing that is an owner decision. No shipped role holds `%DeepSee_Admin`.
  - USER and HSCUSTOM do not report analytics, so the analytics browser specs walk USER, which `Test/AnalyticsProbe` enables and then restores.
  - Each cookieless classic DeepSee page load holds a license unit for 900 s, so no test loads those pages repeatedly.
  - MDX writes the vendor's cache, so it needs WRITE, and a read-only database is refused 409 `ANALYTICS.MDX.READONLY`. `%CancelQuery` checks no owner, so OcuPilot's run row is the owner check.
- **The planned analytics surfaces** (their specs carry the details):
  - **20.11:** source kind `analytics`, with seven `LIST` endpoints, plus Cubes and its tabs, Term lists and Folder items (side-bar positions 1 to 3).
  - **20.32:** Architect, Analyzer and the User Portal as `external` link screens (positions 4 to 6). Each opens in a new tab with `noopener` and is never framed.
  - **20.33:** MDX query (position 7) requires `%DeepSee_Portal:USE` plus `%Development:USE`. Only `SELECT` with at most two axes and `DRILLTHROUGH` run. It is an owner-scoped background run whose answer stays on the screen.
  - **20.35:** `analytics.mdxquery.read` runs in the turn job through `MdxRun`, under the MDX pairs and caps, and reserves no background run. Its answer reaches the model through AD-60.
- **20.34, the cube manager (next to plan).**
  - **Screen.** A listed Cube manager with its own pair, `%DeepSee_Admin:USE`. Its classic page is `%DeepSee.UI.CubeRegistry`.
  - **Writes.** Build and Synchronize are action-style row actions through `AnalyticsPort` (AD-51, AD-52), over a `STATE` read the port composes.
  - **Build** kills every fact first. The cube and its dependents cannot be queried while it runs, and the facts stay gone if it fails. It is destructive, so its key ships `false`.
  - **Synchronize** applies only the recorded source changes and keeps the cube queryable, so its key ships `true`.
  - **Repair** is the vendor's same `%BuildCube` call, so it is offered as Build.
  - **Refused by name:** a synchronize on a source without `DSTIME`, and a build while another process holds `^DeepSee.Build`.
  - **The card** names the dependent cubes (`%GetDependentCubes`, which writes nothing). Cubes' Last build and Facts are the read-back.
  - **Gate questions:**
    - A build can outlast the confirm request. AD-7 runs a write in that request and forbids a detached process from mutating, while the classic page `JOB`s the build and polls a tracking global.
    - The audit record: the vendor writes `CubeEvent` rows, not an audit event (see AD-15's named cases).
    - The user code a build runs: `^DeepSee.InitCode` and the registry's Post code.
- **Out of this epic:**
  - term-list editing;
  - folder export, import and delete;
  - analytics settings and the cube registry's edits, which are Epic 21's analytics editors;
  - Text Analytics, and rebuilt Architect, Analyzer or User Portal.

### Interoperability still to build

- **20.10, source control.** The embedded editors exchange source-control hooks with the instance themselves. OcuPilot's own saves run the save and compile hooks through `AtelierPort`, and an unreleased document is refused 409 `EXPLORER.DOCUMENT.SOURCECONTROL`.
- **20.25, item runtime actions.** These are temporary stop, start and restart, copy, and change of class. A runtime action is followed by the production update the vendor requires. A vendor no-op (a stopped production, a disabled item) is refused by name before any vendor call.
- **20.26, partner writes.** Each write is confirmed over a fresh read and records OcuPilot's own audit row.
  - A rename is refused, or runs in one transaction.
  - A removal first reads the items that name the partner.
  - Its pairs are an orchestrator question.
- **20.12, workflows and Investigate.**
  - A workflow is a sequence of confirmations, each individually confirmed and never batch-approved. Each write still evaluates the prohibited set, both agent switches and governance.
  - Investigate returns a recap and ranked hypotheses that cite the rows used.
  - Its resend workflow proposes `interop.messages.resend`, whose key ships `false`, so an administrator must enable it first.

## Technical Decisions

- **Ports are the whole gate (AD-29).** The vendor's production, partner, test, resend and analytics calls check no privilege (measured), so each port gates first.
  - **Order:** the endpoint's pairs, then the tool's own pairs, then database READ (WRITE for a write). A refusal names the failed pair.
  - **Extra pairs** are declared only where a least-privileged run measured them.
  - **The floor** admits `%Ens_Portal:USE`, so every new surface declares its own pair.
- **`InteropPort` (AD-62)** is the only class that controls a production. A new read or write names its case in AD-62 at its spec gate, and a read also names it in AD-36. Each in-process port keeps its own private `Deny`, `Refuse` and `Conflict`.
- **Classic pages (AD-44, AD-64).** Each descriptor declares, in `CLASSICPAGES`, the classic page it replaces or opens, using the class name as read on the instance. `Screen.Gate.RequiredPairs` is the one reader of a screen's requirement.
- **SQL and namespace.** `InteropPort` reads through `SqlRows`, with `%ExecDirectNoPriv` after its own gate. No statement nests a query that carries `TOP`. A port switches namespace by explicit save and restore and calls no `OcuPilot.*` class while switched (AD-16).
- **Background runs (AD-7, AD-41, AD-42).**
  - **The rules:** a background run never mutates. Each run carries a kind, and a user may have one live run per kind and the instance five across all kinds. The answer is held for its owner alone and swept 900 s after the run ends. Another user's run reads as 404.
  - **The shared class:** 20.33 plans `Kernel/Shell/BackgroundRun`, the fourth spawn site, shared by the SQL console and MDX.
  - **20.34** could add a third kind (inference). AD-7's ban on mutation by a detached process makes that a gate question.
- **Write shape (AD-51 to AD-53).**
  - An action-style write declares its request type and fingerprints a fresh read that the port composes. A screen's action and the agent's write are one operation, and a person's action is never put to governance.
  - Each write finishes in its own confirm request.
  - Every port with `Invoke` also defines a pure `Snippet`.
  - A tool that declares `DRYRUN` is reviewed through `POST /screens/:screen/dryrun` (20.31), which any later dry-run tool reuses.
- **OcuPilot's stored state.**
  - **Property order:** a property added to a `%Persistent` class of OcuPilot's state is declared after every existing one. A rename or removal needs a migration step.
  - **`SCHEMAVERSION`** moves only when a stored row's meaning changes.
  - **Decision sheet:** two questions are open there. One is whether a changed index definition moves the version (DW-2456). The other is that a proposal target longer than `Propose.TARGETREFMAX` (2,200 characters) fails its mint with 500 (DW-2457).
- **Compile order.** A `Parameter` whose `{...}` value names a project class needs `Extends` or `DependsOn` on that class. Without it, a fresh container compile fails `LOAD-FAILED` (20.31's CI red; the checker rule is DW-2459).
- **Reads and ids (AD-13, AD-36).** Every read has a row cap and reports truncation. An id keeps every part exactly, in one percent-encoded segment.
- **Client (AD-5, AD-19).**
  - Every screen route loads through `rememberedPage(loader)`.
  - `screens.generated.ts` is generated and never hand-edited.
  - The client is zoneless and `OnPush`, with screen state in framework-free stores.
  - **Bundle:** the owner set `maximumWarning` to 2,500 kB, with 4,000 kB as the hard stop. A crossing is reported to the owner and never re-based. Each lazy chunk stays under 88 kB.
- **Embedded vendor apps (AD-63).** The same-origin frame is the one exception to AD-47's inert embeds, and only for the interoperability editors. OcuPilot never navigates, posts into or reads from the frame. Analytics pages are linked, never framed.
- **Tools.** Names follow `<area>.<screen>.<verb>`, and each tool declares `CLASSICPAGES`. Each new write is reviewed against the prohibited set. For Gemini, numeric enums stay at the schema's top level.
- **Untrusted content (AD-11, AD-60).** This covers message bodies and headers, settings, log text, and cube, member, term and folder-item names, as well as MDX statements, cells, listings and the vendor's error text. It reaches the screen only as interpolated text, and the model only through the one sanitizer.
- **Reuse rather than copy (Rule 31).**
  - **Server:** `SqlRows`, `LocalStamp`, `SecretPath`, `Ledger.LocalToUtc`, and the SQL console's background run (`Area/Explorer/SqlBackground`, `Kernel.State.SqlRun`).
  - **Client:** `DataTable`'s getters, `core/read-state.ts`, `shell/read-state-blocks.ts`, `followInAppLink`, `pickCount`, the typed-name dialog, `WarningDialog`, and `classifyFault` with `classifyFailure`.
  - **Tests:** `runIris`, `list-spec.mjs`, `MintAs`, `ConfirmHttp`, `ProductionProbe`, `AnalyticsProbe` and the floors' principals.
- **Measure on the instance**, and amend the spine at the spec gate rather than work around it.

## UX & Interaction Patterns

- **Rail and side bar.** Interoperability and Analytics appear only where the namespace reports the feature. A screen joins the side bar only once it ships. Analytics positions 1 to 7 are taken (20.11, 20.32 and 20.33), so the Cube manager takes the next free one (inference).
- **Tabs.** An item has Status, Settings, Queue, Log, Messages, Jobs and Test. A message has Header, Contents and Trace. A cube has Measures, Dimensions and Relationships.
- **New tabs** are opened only where EXPERIENCE.md's list names them: the classic-link card, a `rowLink` exemption and 20.32's links.
- **Dialogs** appear only where EXPERIENCE.md's dialog list names one, and never stack. A destructive screen action uses the typed-name confirm. 20.33 adds its ask-first warning to that list's warnings before a non-delete write.
- **Gated controls are never hidden.** They stay focusable and `aria-disabled`, and name the failed pair.
- **Strings.**
  - Each list or tab has a title, an empty state and three suggested prompts.
  - Every new string goes into EXPERIENCE.md's Fixed strings and `strings.ts`, with a unique value.
  - A count reads singular at 1, through `pickCount`.
  - A refusal sentence lives once, on the server.
  - `strings.test.mjs` caps the literals at 3,800.
- **Cards.** An agent's destructive proposal carries no typed name. A block over about eight lines starts collapsed, and Confirm never requires expanding it.

## Cross-Story Dependencies

- **Status.** Done: 20.1 to 20.9, 20.13 to 20.24, and 20.27 to 20.31. Ready for development: 20.10, 20.11, 20.32, 20.33 and 20.35. Backlog: 20.34, 20.12, 20.25 and 20.26.
- **Order.** 20.10, 20.11, 20.32, 20.33, 20.35, 20.34, 20.12, 20.25, 20.26, then the burn-down. A story planned against a predecessor that is not yet built re-anchors on its shipped code at Task 0.
- **20.34 consumes:**
  - from 20.11: `AnalyticsPort`, `AnalyticsError`, `AnalyticsProbe`, the gate principals, the `cube` entity type, and Cubes' Last build and Facts;
  - from 20.33, possibly: `BackgroundRun` (inference).
  - Epic 21's 21.8 may extend its Cube manager (inference).
- **20.35** consumes 20.33's `MdxAdmit`, `MdxConstructs`, `MdxPrepare` and `MDX*` caps.
- **20.12** cites a session's rows through `interop.messagetrace.read` (20.30).
- **20.10's** integration criterion exercises 20.16's save under source control.
- **Shared rosters take add-only edits:**
  - entity types, the screen mirror, `strings.ts`, EXPERIENCE.md's rows and the navigation tests;
  - `ReadTool`, `ToolRoundTrip`, `ToolEmit` and `SurfaceCoverage`, which holds write tools only;
  - `PortGate`'s `ROSTER`, the governance baseline, `StageTwoTools`' `Elsewhere` block, and the `InteropFloor` and `DeveloperFloor` rosters;
  - `ToolWrite`'s other-port write count, now 51: every write that reaches its target through a non-admin port moves it, including 20.34's, 20.25's and 20.26's (DW-2407).
- **Ask first** before editing anything else contended:
  - `Screen/Registry.cls` and `Screen/Read.cls` beyond add-only, and `Kernel/EntityType.cls`;
  - the prohibited set and `LogSourcePort`;
  - `app.routes.ts`, `angular.json` and the CI files.
- **Epic 23 in parallel.** 23.5 (batch d in progress) runs beside this epic. Its batches b and c changed shell components, `core/fault.ts`, `shell/dialog.ts`, `_components.scss` and DESIGN.md's panel widths, so forward merges can conflict there (inference).
- **Known defects.**
  - **On the owner's hold:** DW-2394, DW-2396 and DW-2416.
  - **Burn-down:** DW-2408, DW-2452 and DW-2459.
  - **Decision pending:** DW-2420 and DW-2442.
  - **Escalated to the Epic 20 decision sheet:** DW-2456 and DW-2457.
  - **CI flake:** DW-2458 (log-viewer AC6) goes to 23.11. Re-run the failed job once.
