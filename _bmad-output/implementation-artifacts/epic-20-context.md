# Epic 20 Context: Stage 4 - Interoperability, with the Analytics rider

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Bring the classic portal's Interoperability work into OcuPilot for namespaces that support it, with Analytics riding along, so the largest area the classic portal still owns is usable here. Shipped so far: category gating, production control, items and their settings, per-host tabs, the monitor, queue and job reads and actions, lookup tables, read-only business partners, host and transformation tests, the interoperability floor, per-screen permissions, the panel collapse, the agent's source reads, saves and creates, the shared tool-listing cache, the sign-in hand-off, a clean compile without interoperability, screens that load on demand, the rule, BPL and DTL editors loaded in place (20.7) and the agent's edits behind them (20.16), the schema viewer and the production configuration diagram (20.8), and message search with its Header and Contents tabs (20.9). Planned and ready for development, in order: 20.30 (the session trace), 20.31 (resend and edit-and-resend), 20.10 (source control) and 20.11 (the analytics port and its four read surfaces). The next story to plan is 20.32, the analytics links: Architect, Analyzer and the User Portal reached from OcuPilot, never rebuilt. After it come 20.33 (the MDX tool), 20.34 (cube build and synchronize), 20.12 (guided workflows and Investigate), 20.25 (item runtime actions), 20.26 (partner writes), then the burn-down.

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

## Requirements & Constraints

- **Every write** is a server-minted proposal with a diff the instance computes, an explicit Confirm and an agent marker. A new write key joins the checked-in governance baseline in the same change, and a destructive key ships `false`. Each plan states the action's destructiveness, its key's default and its audit record.
- **Posture questions** go to the orchestrator, with options and a recommendation.

### Analytics (20.11 planned; 20.32 to 20.34 chartered from its split)

- **The port (AD-65).** `Port/AnalyticsPort` calls the vendor's `%DeepSee` classes in process, as the signed-in person. It never calls `/api/deepsee`, `%Api.DeepSee` or `%DeepSee.REST.*`: that layer resets roles to the login roles, checks no `%DeepSee_*` resource and splices caller text into MDX and SQL (DW-2416, under the owner's hold).
  - **Gate order, before any vendor call:** the endpoint's pairs; the namespace's shape; that the namespace reports analytics, else 409 `ANALYTICS.NAMESPACE` ("Analytics is not enabled in this namespace."); READ on the namespace's globals and routines databases (a cube class's code runs). A refusal names the failed pair.
  - **The vendor's own checks still apply.** `%DeepSee.Utils.%CheckPrivilege` hides a cube carrying a resource the caller lacks, and a folder item's `%CheckResource()` hides that item.
  - **Reads only where measured to write nothing.** Never `%GetMemberTree` (writes `^DeepSee.Session`), `%GetDimensionMembers` (writes the MDX cache) or `%GetFavoritesForUser` (deletes favorites). Never a caller value into `%GetFolderItemList`, which splices its folder argument into SQL. The port prepares no statement of its own.
  - **Later stories extend this port.** MDX is 20.33's, and build and synchronize are 20.34's.
- **Measured vendor facts** (on a throwaway, 2026-10-14):
  - The vendor classes check no `%DeepSee_*` resource. A principal holding only `%DB_USER:RW` read every model, built cubes and ran MDX, cancel included; only a cube's or folder item's `resource` filtered anything.
  - No shipped role holds any `%DeepSee_*` resource, and `%DeepSee_Portal` is public USE. The API floor admits no `%DeepSee_*` resource, so an analytics-only account is refused; admitting one is an owner decision.
  - USER and HSCUSTOM do not report analytics; HSLIB and HSSYS do. In an enabled namespace the classic DeepSee pages answer 200; in HSCUSTOM, 403.
  - **License.** Each cookieless classic DeepSee page load holds a license unit for its session's 900 s. Eight loads exhausted a Community throwaway's license for about five minutes.
- **20.11 as planned** (ready for development):
  - Source kind `analytics` becomes the fifteenth: the "fourteen sources" message changes in `Registry.cls`, `screen-mirror.mjs` and five test classes.
  - Seven `LIST` endpoints and seven screens: Cubes (`analytics/cubes`, side-bar position 1); a cube tab group Measures, Dimensions and Relationships (head `analytics/cubes/document`, criterion `cube`); Term lists (position 2) and their parent-scoped entries (criterion `termlist`); Folder items (position 3).
  - Entity types `cube`, `term-list`, `term-list-entry` (`[TermList, Key]`) and `folder-item`, each id kept exactly.
  - **Pairs:** Cubes and its tabs `%DeepSee_Portal:USE`; Term lists `%DeepSee_PortalEdit:USE`; Folder items `%Development:USE`, a named narrower audience (the classic Folder Manager admits `%DeepSee_Admin` or `%Development`).
  - **The fixture.** `Test/AnalyticsProbe` enables analytics on USER's default web application, creates the probe cubes, term list, folder items and favorites, and its `Remove` and `Gone` restore USER exactly. Its suites are armed `OCUPILOT_ALLOW_PRINCIPALS`. HSCUSTOM is not analytics-enabled, so the structural walk skips analytics screens, and the analytics browser spec walks them in USER.
- **20.32, the analytics links (next to plan).** Architect, Analyzer and the User Portal open the namespace's own page (`_DeepSee.UI.Architect.zen`, `_DeepSee.UI.Analyzer.zen`, `_DeepSee.UserPortal.Home.zen`) in a new tab, never rebuilt and never framed.
  - **Recommended shape:** three listed screens of the existing `external` archetype, which opens a new tab and has no states of its own, each naming its page from a closed vocabulary. The address is composed on the instance from the namespace's default CSP application (`$System.CSP.GetDefaultApp`: USER `/csp/user`, HSLIB `/csp/healthshare`), never from a caller's text, and answered as Help's address is. The side bar and the command box open it with `noopener`, because a tab opened without it starts with a copy of the per-tab token storage.
  - **What it needs:** registry and mirror rules for `external` (no descriptor uses it, and no `href` key exists); an `ARCHETYPE_PAGES` entry; the new-tab exception in EXPERIENCE.md's banned list; and an AD-44/AD-47 clause. Each link declares the classic page it opens, its normalized name read on the instance.
  - **Its gate question:** Architect's (`%DeepSee_Architect,%DeepSee_ArchitectEdit`) and Analyzer's either-of resource lists against AD-8's every-pair rule. Screen permissions' write is OcuPilot's only either-of check, and 20.11's Folder items set the precedent of one named narrower pair.
  - **Its browser test must not load the classic pages repeatedly** (the license, above). Size: small to medium (inference).
- **20.33, the MDX query tool** (charter):
  - An owner-scoped asynchronous run with a row cap, a time bound, cancel and drill-through, never a write.
  - The vendor runs the query on DeepSee's agents in the caller's security context, and its cancel checks no owner, so OcuPilot keeps an owner-scoped run row as the SQL console's background run does (AD-7, AD-33).
  - Drill-through defaults to 1,000 rows and needs SQL SELECT on the source table. `CREATE` and `DROP` write only the session and are refused.
  - **Named limits:** `RETURN`, `%SQLRESTRICT` and SQL computed dimensions splice the query's text into SQL, and `%KPI` runs class code; it is the caller's own query, as the SQL console's statement is.
  - **Its gate:** AD-7's new cost shape (queries write `^DeepSee.Cache.*`, `^DeepSee.AgentLog` and IRISTEMP); the classic MDX tool's `%DeepSee_Admin,%Development` either-of list; and whether the agent gets an MDX read tool. Member values (they run MDX) arrive here.
- **20.34, the cube manager** (charter):
  - A listed Cube manager with the own pair `%DeepSee_Admin:USE`, classic page `%DeepSee.UI.CubeRegistry`.
  - **Writes.** Build and Synchronize are action-style row actions through `AnalyticsPort` (AD-51, AD-52), over a port-composed `STATE` read. Build is destructive, so its key ships `false`: it kills every fact first and leaves them gone if it fails. Synchronize keeps the cube queryable, so its key ships `true`. Repair is the vendor's same build call and is offered as Build.
  - **Refused by name:** a synchronize on a source without `DSTIME`, and a build while another holds `^DeepSee.Build`.
  - The card names the dependent cubes (`%GetDependentCubes`, pure). The vendor records `CubeEvent` rows, not an audit event.
  - **Its gate:** a build can outlast the confirm request (the classic page `JOB`s it and polls), the audit, and the user code a build runs.
- **Out of this epic:** term-list editing, folder export, import and delete, listing groups, quality measures, analytics settings, and the cube registry's register, group and schedule edits (Epic 21's analytics editors). Text Analytics (deprecated) and rebuilt Architect, Analyzer or User Portal are excluded. The Analytics log already ships under Logs.

### Interoperability still to build

- **Messages as built (20.9).** `interoperability/messages` searches headers through `InteropPort` (`Messages`, criteria with hints, `beginDateTime` required). A message opens to its tab group `interoperability/messages/document`: Header, then Contents.
  - A message id matches `^[1-9][0-9]{0,18}$`. An id no header holds reads as zero rows.
  - Contents is rendered as text only, capped, and records the vendor's `ViewContents` audit.
  - Pairs: `%Ens_MessageHeader:USE`, and `%Ens_MessageContent:USE` for Contents.
  - The vendor's message viewer is never embedded, and saved searches are not offered.
- **20.30, the session trace (AD-62 item 16).** A third tab `interoperability/messages/trace`, requiring `%Ens_MessageTrace:USE` too. `MessageTrace` reads the session's headers in `ID` order, capped. OcuPilot draws template-bound SVG and builds the Mermaid `sequenceDiagram` text in the browser from the same rows. 20.6's Test dialog links its `sessionId` here. It also shares one state helper between the Contents and Trace bodies (DW-2434).
- **20.31, resend and edit-and-resend (AD-62 item 17).**
  - `interop.messages.resend` (1 to 100 ids, the integerset rule, refused beyond and never truncated) and `interop.messageheader.editresend`, both through `Ens.MessageHeader.ResendDuplicatedMessage` in process.
  - Each message gets a verdict before any vendor call. A stopped production is refused 409.
  - The agent's card is the dry run. A person's dialog reviews through `POST /screens/:screen/dryrun` and confirms with the typed name and the reviewed digest. Moved verdicts are refused 409 `INTEROP.RESEND.CHANGED`.
  - An edit saves a clone, never a changed original. Both keys are destructive and ship `false`. The vendor audits each new header.
- **20.10, source control.** The embedded editors exchange hooks with the instance themselves, and nothing reaches the shell. OcuPilot's own saves run the save and compile hooks through `AtelierPort`, and an unreleased document is refused 409 `EXPLORER.DOCUMENT.SOURCECONTROL`.
- **20.25, item runtime actions.** A temporary stop, start or restart is followed by the production update the vendor requires. A vendor no-op (a stopped production, a disabled item) is refused by name.
- **20.26, partner writes.** Each is confirmed over a fresh read and records OcuPilot's own audit row. A rename is refused or runs in one transaction. A removal first reads the items that name the partner.
- **20.12, workflows and Investigate.**
  - A workflow is a sequence of individually confirmed proposals, never a batch approval. Each write still evaluates the prohibited set, both agent switches and governance.
  - Investigate returns a recap and ranked hypotheses that cite the rows used.
- **No compile-time dependency on interoperability.** No shipped class names an `Ens.*`, `EnsLib.*` or `EnsPortal.*` class where the compiler resolves it, or includes an interoperability include file. `OcuPilot.Test.CompileWithoutInterop` and CI's `package` job enforce this.
- **Secrets and paths.** A secret-named setting answers empty, and setting one is refused. No endpoint accepts a path outside AD-21's cases.

## Technical Decisions

- **Ports are the whole gate (AD-29).** The vendor's production, lookup, partner, test, resend and analytics calls check no privilege (measured), so each port gates first.
  - **Order:** the endpoint's pairs, then the tool's own, then database READ (WRITE for a write). A refusal names the failed pair.
  - **Extra pairs** are declared only where a least-privileged run measured them, and a test that removes each one pins it.
  - **The floor** admits `%Ens_Portal:USE`, so every new surface declares its own pair.
- **`InteropPort` (AD-62)** is the only class that controls a production, and the only source of interoperability reads. A new read or write names its case in AD-62 at its spec gate, and a read also in AD-36. A new endpoint takes an explicit `Pairs` branch ahead of the `CODEPAIRS` default.
- **Classic pages (AD-44, AD-64).** Each descriptor declares the classic page it replaces, by normalized class name. `Screen.Gate.RequiredPairs` is the one reader of a screen's requirement, and unions each classic page's custom resource. A port's pairs and the vendor's checks are never adjustable.
- **SQL reads without grants.** `InteropPort` reads through `SqlRows`, with `%ExecDirectNoPriv` after its own gate. No statement nests a query carrying `TOP`; a cold cached query refuses it with SQLCODE -99. Use separate top-level statements.
- **Namespace (AD-16).** A port switches by explicit save and restore, calls no `OcuPilot.*` class while switched, and builds rows after it restores.
- **Write shape (AD-51 to AD-53).**
  - Action-style: each write declares its request type and fingerprints a fresh read the port composes.
  - A screen action and the agent's write are one operation. A person's action is never asked of governance.
  - A tool declaring `DRYRUN` is reviewed through 20.31's dry-run route, and any later one reuses it.
  - Each write finishes in its own confirm request, and every port with `Invoke` also defines a pure `Snippet`.
- **Reads and ids (AD-13, AD-36).** Every read has a row cap and reports truncation. A parent-scoped read takes its parent's route id as its one criterion. An id keeps every part exactly in one percent-encoded segment.
- **Client (AD-5, AD-19).**
  - Every screen route loads its page through `rememberedPage(loader)`. A new screen of an existing page needs only a descriptor and its `ScreenOutlet` map line; a new page needs one loader line.
  - `screens.generated.ts` is generated and never hand-edited.
  - The initial bundle is about 1.92 MB against a `maximumWarning` of 1992kB, and each lazy chunk stays under 88 kB.
  - The client is zoneless and `OnPush`, with screen state in framework-free stores. A `detail` tab may draw its rows with a `body` component.
- **Embedded vendor apps (AD-63)** are the one exception to AD-47's inert embeds. Only `interopEditorSource` builds `/ui/interop/<app>/index.html` from a closed vocabulary. The frame is never navigated, nothing is posted into it or read from it, and an embed brings no write tool, key or read.
- **Tools.** Interoperability tools extend `InteropAction`, are named `<area>.<screen>.<verb>` and declare `CLASSICPAGES`. Each new write is reviewed against the prohibited set. For Gemini, keep numeric enums at the schema's top level.
- **Untrusted content (AD-11, AD-60).** Message bodies and headers, session participants, log text, names, settings, editor content, cube, member, term and folder item names, and MDX results are untrusted. They reach the screen only as interpolated text, and the model only through the one sanitizer.
- **Reuse rather than copy (Rule 31).** Extend the shared helpers: server `SqlRows`, `LocalStamp`, `SecretPath`, `Ledger.LocalToUtc`; client `DataTable`'s getters, the typed-name dialog, the skeleton and fault classes; tests `runIris`, `list-spec.mjs`, `MintAs`, `ConfirmHttp`, `ProductionProbe`, `AnalyticsProbe` and the floors' principals. Each in-process port keeps its own private `Deny`, `Refuse` and `Conflict`.
- **Measure on the instance**, and amend the spine at the spec gate rather than working around it.

## UX & Interaction Patterns

- **Rail and side bar.** Interoperability and Analytics follow System Explorer and appear only where the namespace reports the feature. A screen joins the side bar only once it ships. 20.11 adds the first Analytics entries (Cubes, Term lists, Folder items), and 20.32 adds the three links.
- **Tabs.** An item's tabs are Status, Settings, Queue, Log, Messages, Jobs and Test. A message's are Header, Contents and Trace. A cube's are Measures, Dimensions and Relationships.
- **New tabs are banned except where EXPERIENCE.md names them** (today the classic-link card and a `rowLink` exemption's name cell), so 20.32 adds its links to that list. A classic link's caption notes the classic portal may ask the user to sign in again. A classic-link card is never placed on a list screen.
- **Loading.** A screen's first load shows its skeleton until the first page arrives (two-second target), never on a re-fetch.
- **Gated controls are never hidden.** They stay focusable and `aria-disabled`, and name the failed pair.
- **Strings.** Each list or tab has a title, an empty state and three suggested prompts. Every new string goes into EXPERIENCE.md's Fixed strings and `strings.ts`, with unique values. A refusal sentence lives once, on the server, pinned equal to its fixed string. `strings.test.mjs` bounds the literal count at 3,800, raised when the count comes within 50.
- **Dialogs** exist only where EXPERIENCE.md's dialog list names one, never stack, and a destructive screen action uses the typed-name confirm.
- **Auto-refresh** is opt-in per screen, off by default, and declared in the descriptor and EXPERIENCE.md's roster.
- **Cards.** An agent's destructive proposal carries no typed name. A block over about eight lines starts collapsed, and Confirm never requires expanding it.

## Cross-Story Dependencies

- **Done:** 20.1 to 20.9, 20.13 to 20.24, and 20.27 to 20.29. **Ready for development:** 20.30, 20.31, 20.10, 20.11. **Backlog:** 20.32, 20.33, 20.34, 20.12, 20.25, 20.26.
- **Order:** 20.30, 20.31, 20.10, 20.11, 20.32, 20.33, 20.34, 20.12, 20.25, 20.26, then the burn-down. Plans run ahead of implementation, so a story planned against an unbuilt predecessor re-anchors on its shipped code at Task 0.
- **20.32** consumes 20.11's Analytics area and first listed screens, and is planned against 20.11's spec.
- **20.33** consumes `AnalyticsPort` and Cubes as its cube picker. **20.34** consumes the port's writes, with Cubes' Last build and Facts as its read-back.
- **20.30** consumes 20.9's message tab group, `body` input, pairs, id check and synthetic-header fixture, plus 20.6's Test dialog. **20.31** consumes 20.9's list and Header tab, 20.30's `interop.messagetrace.read`, 20.6's field model and 20.23's action-write shape.
- **20.12** cites a session's rows through `interop.messagetrace.read`, and its resend workflow proposes `interop.messages.resend`. **20.10's** integration criterion exercises 20.16's save under source control.
- **Shared rosters take add-only edits:**
  - entity types, the screen mirror, `strings.ts`, the navigation tests and EXPERIENCE.md's rows;
  - the tool rosters (`ReadTool`, `ToolRoundTrip`, `ToolEmit`, `SurfaceCoverage`), `ToolWrite`'s other-port write count (20.31 makes it 51), and `PortGate`'s `ROSTER`;
  - `StageTwoTools`' `Elsewhere` block, which needs a row for every new screen, and the `InteropFloor` and `DeveloperFloor` rosters.
- **Ask first** before editing anything else contended: `Screen/Registry.cls` and `Screen/Read.cls` beyond add-only, `Kernel/EntityType.cls`, the prohibited set, the governance baseline, `LogSourcePort`, `app.routes.ts`, `angular.json` or the CI files. Epic 23's range-end cleanup runs beside this epic; its sweeps touch many Area and test classes (inference: forward-merge conflicts there).
- **Known defects.**
  - **On the owner's hold:** DW-2394 (the vendor uses the null device without opening it), DW-2396 (the schema viewer's `&ST`), DW-2416 (the `/api/deepsee` layer).
  - **Burn-down:** DW-2408 (a host-test browser spec leaves headers and log rows in USER), DW-2420 (the diagram follows no confirmed change), DW-2433 (no cut note at the contents cap).
  - **DW-2415** is the canonical entry for `log-viewer.spec.ts` AC6's timer-count red.
- **Into Epic 21.** Its analytics editors (21.8) extend 20.11's Term lists, Folder items and `AnalyticsPort`, and may extend 20.34's Cube manager (inference). Its SQL tuning track extends 20.12's slow-query workflow. Epic 21 owns interoperability credentials, purge, deployment, record maps and workflow.
