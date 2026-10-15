# Epic 20 Context: Stage 4 - Interoperability, with the Analytics rider

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Bring the classic portal's Interoperability work into OcuPilot for namespaces that support it, with Analytics riding along, so the largest area the classic portal still owns is usable here. Shipped so far: category gating, production control, items and their settings, per-host tabs, the monitor, queue and job reads and actions, lookup tables, read-only business partners, host and transformation tests, the interoperability floor, per-screen permissions, the panel collapse, the agent's source reads, saves and creates, the shared tool-listing cache, the sign-in hand-off, a clean compile without interoperability, screens that load on demand, the rule, BPL and DTL editors in place and the agent's edits behind them, the schema viewer and the configuration diagram, message search with its Header and Contents tabs, and the session trace (20.30). Planned and ready for development, in order: 20.31 (resend and edit-and-resend), 20.10 (source control), 20.11 (the analytics port and its four read surfaces) and 20.32 (the analytics links). The next story to plan is 20.33, the MDX query tool, re-planned around the orchestrator's rulings: the person's screen asks first before running query text that runs server-side code or SQL, and the agent's MDX read is its own story. Then 20.34 (cube build and synchronize) and 20.35 (the agent's MDX read) are planned. After them come 20.12 (guided workflows and Investigate), 20.25 (item runtime actions), 20.26 (partner writes), then the burn-down.

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

- **Every write** is a server-minted proposal with a diff the instance computes, an explicit Confirm and an agent marker. A new write key joins the checked-in governance baseline in the same change, and a destructive key ships `false`. Each plan states the action's destructiveness, its key's default and its audit record.
- **Posture questions** go to the orchestrator, with options and a recommendation.

### Analytics

- **The port (AD-65).** `Port/AnalyticsPort` calls the vendor's `%DeepSee` classes in process, as the signed-in person. It never calls `/api/deepsee`, `%Api.DeepSee` or `%DeepSee.REST.*`: that layer resets roles to the login roles, checks no `%DeepSee_*` resource and splices caller text into MDX and SQL (DW-2416, under the owner's hold). Stories 20.11 and 20.32 to 20.35 all extend this one port.
  - **Gate order, before any vendor call:** the endpoint's pairs; the namespace's shape; that the namespace reports analytics, else 409 `ANALYTICS.NAMESPACE`; READ on the namespace's globals and routines databases. A refusal names the failed pair.
  - **The vendor's own checks still apply.** `%DeepSee.Utils.%CheckPrivilege` hides a cube carrying a resource the caller lacks, and a folder item's `%CheckResource()` hides that item.
  - **Reads only where measured to write nothing.** Never `%GetMemberTree`, `%GetDimensionMembers` or `%GetFavoritesForUser`. Never a caller value into `%GetFolderItemList`. The port prepares no statement of its own. Member values run MDX, so they are not offered as a read.
- **MDX text that runs server-side code or SQL (AD-65; orchestrator ruling Q2 C, which the owner confirmed).** `%SEARCH`, `%SQLRESTRICT`, `RETURN` and `%ORDER` make the vendor run ObjectScript or SQL with the caller's rights.
  - The person's MDX screen (20.33) detects them and asks first, in a confirmation that reads "This query runs server-side code or SQL with your rights.", then runs the query. A query without them runs as a plain read.
  - That confirmation is the person's own step on their own query, not an AD-6 proposal. It is stricter than the classic page, which asks nothing.
  - The agent's MDX read (20.35) refuses them with `ANALYTICS.MDX.SQL`, because an agent read tool never executes code.
  - SQL computed dimensions and `%KPI` classes are the cube author's code, not query text, and stay named limits.
- **Measured vendor facts** (throwaways, 2026-10-14):
  - The vendor classes check no `%DeepSee_*` resource. No shipped role holds one, and `%DeepSee_Portal` is public USE. The API floor admits no `%DeepSee_*` resource, so an analytics-only account is refused; admitting one is an owner decision.
  - USER and HSCUSTOM do not report analytics; HSLIB and HSSYS do. HSLIB's database is read-only, so MDX cannot run there.
  - **License.** Each cookieless classic DeepSee page load holds a license unit for 900 s. Eight loads exhausted a Community throwaway's license for about five minutes, so no test loads those pages repeatedly.
  - **MDX writes the vendor's cache.** Even `%DeepSee.ResultSet.%New()` writes `^DeepSee.Cache.LocalResults`. A principal without WRITE on that database, or in a read-only one, gets `<PROTECT>`. A canceled crossjoin left millions of `^DeepSee.Cache.Axis` nodes, kept until the cube is next built or killed.
  - **Running and cancel.** `%PrepareMDX` with `%ExecuteAsynch` runs on the vendor's agents in the caller's security context. `%CancelQuery` checks no owner and stops every process running the same text. A cancel settled in 1.1 to 5.4 s.
  - **The splices are real.** `%SEARCH.&[... {$Increment(^g)}]` wrote a global before its SQL failed, and `RETURN`'s subquery ran.
  - **Drill-through** answers 1,000 rows by default and needs SQL SELECT on the source table (SQLCODE -99 without it). `CREATE` and `DROP` change only the session.
- **20.11 (ready for development).** Source kind `analytics` becomes the fifteenth. Seven `LIST` endpoints and seven screens: Cubes, with its Measures, Dimensions and Relationships tabs (`%DeepSee_Portal:USE`); Term lists and their entries (`%DeepSee_PortalEdit:USE`); Folder items (`%Development:USE`, a named narrower audience). Entity types `cube`, `term-list`, `term-list-entry` and `folder-item`. `Test/AnalyticsProbe` enables analytics on USER's default web application and restores USER exactly. HSCUSTOM is not analytics-enabled, so the analytics browser spec walks USER.
- **20.32 (ready for development; gate ruling Q1 A).** Architect, Analyzer and User Portal are three listed screens of the `external` archetype, at side-bar positions 4 to 6.
  - `Screen/ExternalPage` holds a closed vocabulary of vendor pages. The instance composes each address from `$System.CSP.GetDefaultApp(ns)`, the page file and `?$NAMESPACE=`, checked by `ClassicHrefProblem`. The navigation map carries `href` only on an `external` entry whose area applies.
  - The side bar and the command box open it with `noopener` in the person's own click or key press. The route itself shows the classic-link card. A vendor page is never framed, fetched or rebuilt.
  - **Pairs.** Architect requires `%DeepSee_Architect:USE` and Analyzer `%DeepSee_Analyzer:USE`, each with the area's `%DeepSee_Portal:USE`; the User Portal requires `%DeepSee_Portal:USE`. Named limit: a holder of only the `...Edit` resource, whom the vendor admits, is refused here. AD-64's either-of check is not extended.
- **20.33, the MDX query tool (re-plan).** Its first plan stays the measured baseline; the re-plan replaces its refusal of the four constructs with Q2 C's ask-first confirmation.
  - **Shape.** A listed Analytics screen where a person writes one MDX statement and runs it as an owner-scoped background run. It has a row cap, a time bound, cancel, and a grid of axis labels and cells. A cell's drill-through is composed on the instance from the vendor's `%GetFiltersForCellRange`, and never from client text beyond the original statement.
  - **What runs.** After prepare, only `SELECT` with at most two axes, and `DRILLTHROUGH`, run. `CREATE` and `DROP` are refused, and nothing is kept between runs.
  - **The run.** The SQL console's background run (Story 19.15) has the needed row, lock, sweep, owner 404 and bounds, so it is extended to a second kind rather than copied. The statement is never stored or logged. Cells, labels, listings and the vendor's error text are a screen-only payload.
  - **Gate.** Beyond AD-65's order, the gate needs WRITE on the database `^DeepSee.Cache.Results` maps to, and refuses a read-only one.
  - **Pairs.** The first plan proposed `%DeepSee_Portal:USE` plus the screen's own `%Development:USE`, a named narrower audience than classic `%DeepSee.UI.MDXQuery`'s `%DeepSee_Admin,%Development`.
  - **No agent surface:** no write tool, key, proposal or read tool here.
  - **Spine.** Only AD-65's splice clause is written. Its AD-7 cost shape, AD-8 pairs, AD-21, AD-36, AD-41 run kinds, AD-42 spawn site and AD-44 page clauses are written at its gate.
- **20.35, the agent's MDX read (charter).** Synchronous in the turn job through `AnalyticsPort`, with 20.33's row, time and drill-through caps and AD-60's sanitizer. It refuses the four constructs with `ANALYTICS.MDX.SQL`, and carries its own `ReadTool`, `ToolRoundTrip`, `ToolEmit` and `SurfaceCoverage` rows.
- **20.34, the cube manager (charter).** A listed Cube manager with the own pair `%DeepSee_Admin:USE`, classic page `%DeepSee.UI.CubeRegistry`.
  - Build and Synchronize are action-style row actions through `AnalyticsPort` (AD-51, AD-52) over a port-composed `STATE` read.
  - Build kills every fact first and leaves them gone if it fails, so it is destructive and its key ships `false`. Synchronize keeps the cube queryable, so its key ships `true`. Repair is the vendor's same build call and is offered as Build.
  - Refused by name: a synchronize on a source without `DSTIME`, and a build while another holds `^DeepSee.Build`. The card names the dependent cubes (`%GetDependentCubes`). The vendor records `CubeEvent` rows, not an audit event.
  - **Its gate:** a build can outlast the confirm request (the classic page `JOB`s it and polls), the audit, and the user code a build runs.
- **Out of this epic:** term-list editing, folder export, import and delete, listing groups, quality measures, analytics settings, and the cube registry's edits (Epic 21's analytics editors). Text Analytics and rebuilt Architect, Analyzer or User Portal are excluded. The Analytics log already ships under Logs.

### Interoperability still to build

- **Messages as built (20.9, 20.30).** A message opens to its tab group: Header, Contents and Trace.
  - Search reads headers through `InteropPort`, with `beginDateTime` required. A message id matches `^[1-9][0-9]{0,18}$`.
  - Contents is text only, capped, and records the vendor's `ViewContents` audit.
  - Trace (`MessageTrace`, `%Ens_MessageTrace:USE` too) reads the session's headers in `ID` order, capped. OcuPilot draws it as template-bound SVG, with Mermaid text built in the browser. `SuperSession` is not followed, as the classic Visual Trace does not follow it.
- **20.31, resend and edit-and-resend (AD-62 item 17).**
  - `interop.messages.resend` takes 1 to 100 ids, refused beyond and never truncated. `interop.messageheader.editresend` saves an edited clone, never a changed original. Both run through `Ens.MessageHeader.ResendDuplicatedMessage` in process.
  - Each message gets a verdict before any vendor call, and a stopped production is refused 409. The agent's card is the dry run. A person's dialog reviews through `POST /screens/:screen/dryrun`, and moved verdicts are refused 409 `INTEROP.RESEND.CHANGED`.
  - Both keys are destructive and ship `false`.
- **20.10, source control.** The embedded editors exchange hooks with the instance themselves, and nothing reaches the shell. OcuPilot's own saves run the save and compile hooks through `AtelierPort`, and an unreleased document is refused 409 `EXPLORER.DOCUMENT.SOURCECONTROL`.
- **20.25, item runtime actions.** A temporary stop, start or restart is followed by the production update the vendor requires. A vendor no-op (a stopped production, a disabled item) is refused by name.
- **20.26, partner writes.** Each is confirmed over a fresh read and records OcuPilot's own audit row. A rename is refused or runs in one transaction. A removal first reads the items that name the partner.
- **20.12, workflows and Investigate.** A workflow is a sequence of individually confirmed proposals, never a batch approval, and each write still evaluates the prohibited set, both agent switches and governance. Investigate returns a recap and ranked hypotheses that cite the rows used.
- **No compile-time dependency on interoperability.** No shipped class names an `Ens.*`, `EnsLib.*` or `EnsPortal.*` class where the compiler resolves it, or includes an interoperability include file. `OcuPilot.Test.CompileWithoutInterop` and CI's `package` job enforce this.
- **Secrets and paths.** A secret-named setting answers empty, and setting one is refused. No endpoint accepts a path outside AD-21's cases.

## Technical Decisions

- **Ports are the whole gate (AD-29).** The vendor's production, lookup, partner, test, resend and analytics calls check no privilege (measured), so each port gates first.
  - **Order:** the endpoint's pairs, then the tool's own, then database READ (WRITE for a write). A refusal names the failed pair.
  - **Extra pairs** are declared only where a least-privileged run measured them, and a test that removes each one pins it.
  - **The floor** admits `%Ens_Portal:USE`, so every new surface declares its own pair.
- **`InteropPort` (AD-62)** is the only class that controls a production, and the only source of interoperability reads. A new read or write names its case in AD-62 at its spec gate, and a read also in AD-36. A new endpoint takes an explicit `Pairs` branch ahead of the `CODEPAIRS` default.
- **Classic pages (AD-44, AD-64).** Each descriptor declares the classic page it replaces or opens, by normalized class name read on the instance. `Screen.Gate.RequiredPairs` is the one reader of a screen's requirement. A port's pairs and the vendor's checks are never adjustable.
- **SQL reads without grants.** `InteropPort` reads through `SqlRows`, with `%ExecDirectNoPriv` after its own gate. No statement nests a query carrying `TOP`, because a cold cached query refuses it with SQLCODE -99.
- **Namespace (AD-16).** A port switches by explicit save and restore, calls no `OcuPilot.*` class while switched, and builds rows after it restores.
- **Background runs (AD-7, AD-33, AD-41, AD-42).** The SQL console's background run is a job a person starts for one query, and it never mutates. A user has at most one live run and the instance at most five, a limit measured against the license. The answer is held for its owner's poll alone, swept 900 s after the run ends, and another user's run reads as 404.
- **Write shape (AD-51 to AD-53).**
  - Action-style: each write declares its request type and fingerprints a fresh read the port composes.
  - A screen action and the agent's write are one operation. A person's action is never asked of governance.
  - A tool declaring `DRYRUN` is reviewed through 20.31's dry-run route, and any later one reuses it.
  - Each write finishes in its own confirm request, and every port with `Invoke` also defines a pure `Snippet`.
- **Reads and ids (AD-13, AD-36).** Every read has a row cap and reports truncation. A parent-scoped read takes its parent's route id as its one criterion. An id keeps every part exactly in one percent-encoded segment.
- **Client (AD-5, AD-19).**
  - Every screen route loads its page through `rememberedPage(loader)`. A new screen of an existing page needs only a descriptor and its `ScreenOutlet` map line; a new page needs one loader line.
  - `screens.generated.ts` is generated and never hand-edited.
  - **Bundle.** The initial bundle measures about 1.95 MB. The owner fixed `maximumWarning` at 2500 kB, with 4000 kB as the hard stop. The re-base policy is retired: a crossing is reported to the owner, never re-based. AD-5 still states the older 5% rule. `angular.json`'s budgets are not edited in this epic. Each lazy chunk stays under 88 kB.
  - The client is zoneless and `OnPush`, with screen state in framework-free stores. A `detail` tab may draw its rows with a `body` component.
- **Embedded vendor apps (AD-63)** are the one exception to AD-47's inert embeds, for the interoperability editors only. The frame is never navigated, nothing is posted into it or read from it, and an embed brings no write tool, key or read. Analytics pages are linked in a new tab, never framed.
- **Tools.** Interoperability tools extend `InteropAction`, are named `<area>.<screen>.<verb>` and declare `CLASSICPAGES`. Each new write is reviewed against the prohibited set. For Gemini, keep numeric enums at the schema's top level.
- **Untrusted content (AD-11, AD-60).** Untrusted content includes:
  - message bodies and headers, session participants, log text and settings;
  - names, editor content, and cube, member, term and folder item names;
  - MDX statements, cells and listings, and the vendor's error text.

  It reaches the screen only as interpolated text, and the model only through the one sanitizer.
- **Reuse rather than copy (Rule 31).** Extend the shared helpers:
  - server: `SqlRows`, `LocalStamp`, `SecretPath`, `Ledger.LocalToUtc`, and the SQL console's background run (`Area/Explorer/SqlBackground`, `Kernel.State.SqlRun`);
  - client: `DataTable`'s getters, `core/read-state.ts`, `shell/read-state-blocks.ts`, `followInAppLink`, `core/sql-answer.ts`, `pickCount` for any count, the typed-name dialog and the fault classes;
  - tests: `runIris`, `list-spec.mjs`, `MintAs`, `ConfirmHttp`, `ProductionProbe`, `AnalyticsProbe` and the floors' principals.

  Each in-process port keeps its own private `Deny`, `Refuse` and `Conflict`.
- **Measure on the instance**, and amend the spine at the spec gate rather than working around it.

## UX & Interaction Patterns

- **Rail and side bar.** Interoperability and Analytics follow System Explorer and appear only where the namespace reports the feature. A screen joins the side bar only once it ships. 20.11 adds Cubes, Term lists and Folder items, and 20.32 adds the three links at positions 4 to 6.
- **Tabs.** An item's tabs are Status, Settings, Queue, Log, Messages, Jobs and Test. A message's are Header, Contents and Trace. A cube's are Measures, Dimensions and Relationships.
- **New tabs are banned except where EXPERIENCE.md names them:** today the classic-link card and a `rowLink` exemption's name cell. 20.32 adds its links to that list. A classic link's caption notes the classic portal may ask the user to sign in again. A classic-link card is never placed on a list screen.
- **Dialogs** exist only where EXPERIENCE.md's dialog list names one, and never stack. A destructive screen action uses the typed-name confirm. The SQL console's "Run this statement?" warning (Story 19.6) is the nearest precedent for 20.33's ask-first confirmation, which would join that list's warnings (inference).
- **Loading.** A screen's first load shows its skeleton until the first page arrives (two-second target), never on a re-fetch.
- **Gated controls are never hidden.** They stay focusable and `aria-disabled`, and name the failed pair.
- **Strings.**
  - Each list or tab has a title, an empty state and three suggested prompts.
  - Every new string goes into EXPERIENCE.md's Fixed strings and `strings.ts`, with unique values.
  - A count reads singular at 1, through `pickCount`.
  - A refusal sentence lives once, on the server, pinned equal to its fixed string.
  - `strings.test.mjs` bounds the literal count at 3,800, raised when the count comes within 50.
- **Auto-refresh** is opt-in per screen, off by default, and declared in the descriptor and EXPERIENCE.md's roster.
- **Cards.** An agent's destructive proposal carries no typed name. A block over about eight lines starts collapsed, and Confirm never requires expanding it.

## Cross-Story Dependencies

- **Status.**
  - Done: 20.1 to 20.9, 20.13 to 20.24, and 20.27 to 20.30.
  - Ready for development: 20.31, 20.10, 20.11, 20.32.
  - Backlog: 20.33 (draft, to re-plan), 20.35, 20.34, 20.12, 20.25, 20.26.
- **Order:** 20.31, 20.10, 20.11, 20.32, 20.33, 20.35, 20.34, 20.12, 20.25, 20.26, then the burn-down. Plans run ahead of implementation, so a story planned against an unbuilt predecessor re-anchors on its shipped code at Task 0.
- **20.33** consumes:
  - from 20.11: `AnalyticsPort`, `AnalyticsError`, `AnalyticsProbe`, the analytics gate principals, Cubes as its cube picker and the `cube` entity type;
  - from 20.32: the side-bar positions it takes;
  - 19.15's background run and 19.6's fetch loop;
  - 20.29's loader map.
- **20.35** consumes 20.33's port calls, caps and construct detection. **20.34** consumes the port's writes, with Cubes' Last build and Facts as its read-back. It may extend 20.33's background run with a third kind (inference).
- **Message stories.** **20.31** consumes 20.9's list and Header tab, 20.30's `interop.messagetrace.read`, 20.6's field model and 20.23's action-write shape. **20.12** cites a session's rows through `interop.messagetrace.read`, and its resend workflow proposes `interop.messages.resend`. **20.10's** integration criterion exercises 20.16's save under source control.
- **Shared rosters take add-only edits:**
  - entity types, the screen mirror, `strings.ts`, the navigation tests and EXPERIENCE.md's rows;
  - the tool rosters (`ReadTool`, `ToolRoundTrip`, `ToolEmit`, `SurfaceCoverage`), `ToolWrite`'s other-port write count (20.31 makes it 51), and `PortGate`'s `ROSTER`;
  - `StageTwoTools`' `Elsewhere` block, which needs a row for every new screen, and the `InteropFloor` and `DeveloperFloor` rosters.
- **Ask first** before editing anything else contended:
  - `Screen/Registry.cls` and `Screen/Read.cls` beyond add-only, and `Kernel/EntityType.cls`;
  - the prohibited set, the governance baseline and `LogSourcePort`;
  - `app.routes.ts`, `angular.json` and the CI files.

  Epic 23's range-end cleanup (23.5 in progress) runs beside this epic and edits `strings.ts`, EXPERIENCE.md, `data-table.ts` and many Area and test classes, which can conflict at forward merges (inference).
- **Known defects.**
  - **On the owner's hold:** DW-2394 (the vendor uses the null device without opening it), DW-2396 (the schema viewer's `&ST`), DW-2416 (the `/api/deepsee` layer).
  - **Burn-down:** DW-2408 (a host-test browser spec leaves headers and log rows in USER), DW-2420 (the diagram follows no confirmed change), DW-2433 (no cut note at the contents cap), DW-2442 (decision pending: a trace arrow's accessible name omits its visible label, WCAG 2.5.3).
  - **DW-2415** is the canonical entry for `log-viewer.spec.ts` AC6's timer-count red.
- **Into Epic 21.**
  - 21.8's analytics editors wait on 20.11 and extend its Term lists, Folder items and `AnalyticsPort`; they may extend 20.34's Cube manager (inference).
  - 21.6's SQL tuning track waits on 20.12's slow-query workflow, and 21.7 and 21.11 wait on all of Epic 20.
  - Epic 21 owns interoperability credentials, purge, deployment, record maps and workflow.
