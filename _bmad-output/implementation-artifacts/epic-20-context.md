# Epic 20 Context: Stage 4 - Interoperability, with the Analytics rider

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Bring the classic portal's Interoperability work into OcuPilot for namespaces that support it, with Analytics riding along, so the largest area the classic portal still owns is usable here. Shipped so far: category gating, production control, items and their settings, per-host tabs, the monitor, queue and job reads and actions, lookup tables, read-only business partners, host and transformation tests, the interoperability floor, per-screen permissions, the panel collapse, the agent's source reads, saves and creates, the shared tool-listing cache, the sign-in hand-off, a clean compile and install in a namespace without interoperability, screens that load on demand, the rule, BPL and DTL editors InterSystems built, loaded in place inside the shell (20.7), and the agent's confirmed edits to the content behind those editors (20.16). Five stories are ready for development: 20.8 (the schema viewer and the production configuration diagram), 20.9 (message search and the Header and Contents tabs), 20.30 (the session trace), 20.31 (message resend and edit-and-resend) and 20.10 (source control). The next story to plan is 20.11, the Analytics rider: cubes, the model browser, the MDX tool and the cube manager, whose build, synchronize or repair is its one write. Still to come after it: guided workflows with Investigate, item runtime actions and partner writes.

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

## Requirements & Constraints

- **Every write** is a server-minted proposal with a diff the instance computes, an explicit Confirm and an agent marker. A new write key joins the checked-in governance baseline in the same change, and a destructive key ships `false`. Each plan states the action's destructiveness, its key's default and its audit record.
- **The Analytics rider (20.11, the next story to plan).**
  - **The acceptance.**
    - The cube list, model browser, term list viewer and folder browser each read through the analytics API.
    - An MDX query's results render, with drill-through and cancel.
    - The cube manager's build, synchronize or repair is a confirmed write, the one analytics write in this stage.
    - Architect, Analyzer and the User Portal are linked, not rebuilt.
  - **Scope.**
    - Cube list: name, class, last build and size.
    - Model browser: a cube's relationships and member tree (cubes, measures, filters).
    - Term lists are read only. Folder items (pivots, dashboards, favorites) are browsed only.
    - MDX tool: a cube picker, the member tree and execute. Drill-through and cancel are the acceptance.
    - **Out of this stage:** term-list editing, folder export, import and delete, listing groups, quality measures, analytics settings, and the cube registry's register, group and schedule edits. Epic 21 owns the analytics editors. Text Analytics (deprecated) and rebuilding Architect, Analyzer or the User Portal are excluded.
  - **Backing.** `/api/deepsee` (`%Api.DeepSee`, forwarding to `%DeepSee.REST.v3`): its `Info/*` reads, `MDXExecute`, `MDXDrillthrough` and `MDXCancelQuery`, and the `BuildCube`, `SynchronizeCube` and `RepairBuild` commands. Its guide is mirrored at `irisdocs/guides/D2CLIENT_rest_api.md`. The links go to the namespace's own `_DeepSee.UI.Architect.zen`, `_DeepSee.UI.Analyzer.zen` and `_DeepSee.UserPortal.Home.zen`.
  - **No port reaches the analytics API yet.** Nothing crosses the boundary except through a port, so 20.11 names its port at its spec gate, with its gate first (AD-29) and its write's declared port (AD-52). AD-61 (route methods in process, stub CSP state, capture, outcome read from every place) and AD-62 (the vendor classes the classic pages call) are the two precedents.
  - **The harvested reference** is the sibling project's `REST/Analytics.cls` (cube list, MDX execute, cube build and sync), renamed on harvest.
  - **Namespace and pairs.**
    - The area applies only where `%DeepSee.Utils.%IsDeepSeeEnabled` answers true. Anything beyond the three links needs such a namespace, and so do 20.11's tests.
    - The area's pair, `%DeepSee_Portal:USE`, is public, so every account holds it. Each screen and tool declares its classic page's own resource (AD-8, AD-44).
    - The classic pages, read in the vendor source: the cube manager declares `%DeepSee_Admin`; the MDX tool and folder manager `%DeepSee_Admin,%Development`; the term list manager `%DeepSee_PortalEdit`; the model browser `%DeepSee_Portal,%DeepSee_PortalEdit`. A Zen page admits a holder of any one member of its list, while AD-8 requires every declared pair, and its only either-of check covers 20.15's five surfaces. So a two-member list is a spine question for 20.11's gate (inference).
    - The API floor admits no `%DeepSee_*` resource, so an account holding analytics resources alone is refused before any route runs. Admitting it would be an owner decision, as DW-2140 was for `%Ens_Portal` (inference).
  - **For its plan to measure (inference).** Cancel implies an MDX run that outlasts one request, and the SQL console's owner-scoped background run is AD-7's only precedent. A cube build may outlast the confirm request. A caller's MDX is free text run as the caller, as the SQL console's statement is. The build's destructiveness and key posture are settled at its gate.
  - **Already shipped elsewhere.** The Analytics log is under Logs (`logs.analytics.read`, through `LogSourcePort`), so it is not 20.11's.
- **The vendor's message viewer is never embedded** (measured in its bundle). `/ui/interop/message-viewer` reads only `$NAMESPACE` and `SESSIONID`, and no parameter opens one message. Every load stores an `Ens.Message.Search` row. So 20.9, 20.30 and 20.31 build their own surfaces.
- **Message reads (20.9, ready for development; AD-62 item 15).**
  - **Endpoints.** `Messages` (`LIST`) takes `beginDateTime` (required), `endDateTime`, `status`, `type`, `source`, `target`, `bodyClass`, `session` and `errors`. `MessageHeader` and `MessageContents` (`LIST`) take one criterion, `message`, the header `ID`. Every statement reads `Ens.MessageHeader` with `%ExecDirectNoPriv` after the gate, every value bound. The time window becomes ID bounds through two top-level statements, as the classic viewer does.
  - **Ids.** A message id is kept exactly and matches `^[1-9][0-9]{0,18}$`. An id no header holds reads as zero rows, and any other text is refused 400 `PORT.VALIDATION`.
  - **Contents** are rendered as text only: EDI as the raw view or indented XML, `%XML.Adaptor` through `%XML.Writer`, a character stream as read. Any other body is refused `INTEROP.MESSAGE.CONTENTS`. At most 1,000,000 characters are shown, each line cut at 4,000. Each read that opens a body first records the vendor's `%Ensemble/%Message/ViewContents` through `Ens.Util.Auditing.AuditViewMessage`, except for alarm messages, and a failed audit never fails the read.
  - **Pairs.** Every message read requires `%Ens_MessageHeader:USE` (`%EnsRole_Operator` holds it). Contents also requires `%Ens_MessageContent:USE` (`%EnsRole_Administrator` and `%EnsRole_WebDeveloper`).
  - **Screens.** The list (server criteria) is `interoperability/messages`. Its tab group is `interoperability/messages/document`: Header at position 1, Contents at `.../contents`, position 2. The classic page is `EnsPortal.MessageViewer`. Queue messages' `rowTarget` opens the Header tab. A `detail` screen may not declare a `rowTarget`.
  - **Not used:** saved searches (a named limit), `Ens.Message.Search`, `Ens.Message.Utils` and either saved-search store.
  - **Tests** use synthetic headers saved with `%New`/`%Save`, which needs no production. A fresh throwaway holds no message header, and the save does not set `SessionId`.
- **The session trace (20.30, ready for development; AD-62 item 16).**
  - **Screen.** A third tab, `interoperability/messages/trace` at position 3, classic page `EnsPortal.VisualTrace`. It requires `%Ens_MessageHeader:USE` and `%Ens_MessageTrace:USE`, both held by `%EnsRole_Operator`.
  - **Read.** `MessageTrace` (`LIST`, criterion `message`). Two top-level statements after the gate: the header's `SessionId`, then `TOP ?` of that session's headers in `ID` order. No header, or no session, reads as zero rows. Rows carry a numeric `Step` as the only sort key, because string ids sort `10` before `9`.
  - **Drawing.** OcuPilot draws the trace as template-bound SVG through 20.9's `body` input: participants in first-appearance order, one arrow per header, a response dashed, an error in the error token, each arrow linking to its Header tab. Data reaches the SVG only as attribute values and interpolated text. The Mermaid `sequenceDiagram` text is built in the browser from the same rows, porting the sibling `Diagram/Writer.cls`'s id, escape and label rules.
  - **From the host test.** 20.6's Test dialog links its answer's `sessionId` (the first header's `ID`) to the trace.
  - **Named limits.** The event, rule and IO logs and `SuperSession` are not read. The trace draws the first `maxRows` headers (1,000 by default) and says when it is cut.
- **Resend and edit-and-resend (20.31, ready for development; AD-62 item 17).**
  - **Two tools**, action-style over port-composed `RESEND` and `EDIT` reads (AD-51): `interop.messages.resend` takes a set of 1 to 100 ids, and `interop.messageheader.editresend` one id and the changed fields of its body. Both call `Ens.MessageHeader.ResendDuplicatedMessage` in process, which checks no privilege. The resent header keeps the session, so it appears in 20.30's trace.
  - **Pairs.** Resend requires `%Ens_MessageResend:USE`. Edit also requires `%Ens_MessageContent:USE` and `%Ens_MessageEditResend:USE`. Both need WRITE on the globals database. The classic pages are `EnsPortal.MessageResend`, and `EnsPortal.MessageResendEdit` for edit.
  - **Verdicts before any vendor call.** A stopped production is refused 409 `INTEROP.PRODUCTION.NOTRUNNING` as a whole. Each message reads one of `gone`, `nobody` (its body is gone), `targetoff` (a request whose target is not an enabled item of the running production; measured, the vendor would queue it and answer OK), `noreplyqueue` or `resend`.
  - **The set.** `interop-message` takes the integerset rule (AD-13): canonical, each id once, ascending. Over 100 ids, or a malformed member, is refused 400 naming `Messages`, never truncated.
  - **The double gate.** The agent's card is the dry run, fingerprinted over the verdicts, production and namespace. A person's dialog fetches the same rows from `POST /screens/:screen/dryrun`, then confirms with the typed name, carrying the reviewed digest. Verdicts that moved are refused 409 `INTEROP.RESEND.CHANGED`, with nothing sent.
  - **Confirm** resends exactly the reviewed `resend` members, in ascending ID order, and records a vendor failure on its message while the rest still go.
  - **Edit saves a clone, never a changed original.** An object body goes through 20.6's field model. An HL7 v2 body follows the vendor's edit. Any other kind is refused `INTEROP.EDIT.NOTEDITABLE`. The edit's read records `ViewContents`.
  - **Posture.** Both tools are destructive, and both keys ship `false` (AD-22). The vendor audits each new header with `%Ensemble/%Message/Resend`, so OcuPilot records no `ConfigChange`.
  - **Named limits:** no new target, no head of queue, no resend of every match, and no X12, EDIFACT or ASTM edits.
  - **It adds no screen, entity type, area or read endpoint.** It uses the list's multi-select and page-drawn actions on the Header tab.
  - **Its tests remove what they cause.** `ProductionProbe`'s removal leaves the start-up `Ens.ScheduleService` header and every body (DW-2408).
- **Embedding a vendor app (20.7 as built; 20.8 follows it).**
  - **In place, never copied.** The app loads from the instance, signed in through 20.13's hand-off.
  - **Results.** The app reports a save, a compile or a failed compile in its own notice inside the frame. Nothing reaches the shell, which shows results only through its own reads.
  - **When a frame is drawn.** A screen issues only its declared read, or another built screen's, and draws a frame only for a row that read answers (for a process or transformation, a row that is not `Coded`). Otherwise it shows its "no longer exists" or "written as a class" sentence, and a refusal names the failed pair.
  - **A drawn frame is never navigated.** A new document, a namespace move or Refresh draws a new frame. Leaving, or Refresh, discards unsaved changes (DW-2376, by design), with no leave guard. The app can move away unseen through its own links; the screen keeps naming its own document.
  - **Scope.** An embed brings no write tool, governance key, entity type, read tool or area, and no query parameter beyond `$NAMESPACE` and the app's document parameter.
- **The schema viewer and the diagram (20.8, ready for development).**
  - **Schema viewer.** One listed screen, `interoperability/schema-viewer`, with no read and no document parameter. The app clears its `&ST`, so every address opens on ASC X12 (measured), and the person picks HL7 v2.x or ASTM in the viewer. DW-2396 is on the owner's hold, and 20.8's AC2 is its tripwire.
  - **Diagram.** One unlisted screen, `interoperability/productions/diagram/<production>`, linked from Production items, drawn only for a row whose `Name` exactly matches the route id. Inside it the person may change configuration and start or stop the production as themselves; OcuPilot's write path, governance and agent switches do not reach the frame (inference). Each load stores one `Ens.Message.Search` row (measured).
- **Rule, DTL and BPL edits (20.16, done).** Six tools, `.source` and `.save` on the three editors, extending 20.21's class read and save. Each requires the editor screen's pairs plus `%Development:USE`, and each save also `%Ens_Code:WRITE` and routines-database WRITE. `IsCodeOfKind` runs at the mint and at Confirm. Confirm is refused if the stored content changed after the mint, and every save compiles; a console that reports errors counts as a failed compile. Only a document in its namespace's own routines database can be saved: never in `%SYS`, a `%` name or OcuPilot's own packages.
- **Source control (20.10, ready for development, after 20.31).** The embedded editors exchange hooks, menus, user actions and status with the instance themselves, and nothing reaches the shell. OcuPilot's own saves run the save and compile hooks through `AtelierPort`, in the caller's process; `GET doc` runs no load hooks. An unreleased document is refused 409 `EXPLORER.DOCUMENT.SOURCECONTROL` (#5845, #5865 or #6151). An error from the hook's own `OnBeforeSave` stays 422 `EXPLORER.SAVE.REFUSED`.
- **Item runtime actions (20.25).** A temporary stop, start or restart of one item is followed by the production update the vendor requires. Each is refused by name where the vendor would answer success while doing nothing (a stopped production, a disabled item). Copy and change of class run as the classic page does.
- **Partner writes (20.26)** on `Ens.Config.BusinessPartner`. Each is confirmed over a fresh read and records OcuPilot's own audit row. The vendor renames by a delete and a create without a transaction, so a rename is refused or runs in one transaction. Before a removal it reads the items that name the partner, then refuses or warns.
- **Workflows and Investigate (20.12).** A workflow is a sequence of individually confirmed proposals, never a batch approval. Each write still evaluates the prohibited set, both agent switches and governance. Investigate starts from an alert or a log entry and returns a recap and ranked hypotheses that cite the rows used. Its resend workflow needs an administrator to enable the resend key first.
- **No compile-time dependency on interoperability.** No shipped class includes an interoperability include file, or names an `Ens.*`, `EnsLib.*` or `EnsPortal.*` class where the compiler resolves it (superclass, property, argument or return type, `DependsOn`, `CompileAfter`, a class query's SQL). Such a value is typed `%RegisteredObject` or `%String` and reached at run time while switched. `##class(Ens.…)` in a method body, `#dim`, embedded SQL and strings all compile. `OcuPilot.Test.CompileWithoutInterop` and the `package` job enforce this.
- **Secrets and paths.** A secret-named setting answers empty, and setting one is refused before any vendor call. No endpoint accepts a path outside a case AD-21 names. Pasted XML reaches a vendor parser only from its first `<`, and HL7 text as a character stream (DW-2378, in the burn-down). A pasted message that declares a document type is refused.
- **Posture questions** go to the orchestrator, with options and a recommendation.

## Technical Decisions

- **Client loading (AD-5, AD-19).**
  - Every screen route has one `''` child, which loads through `rememberedPage(loader)`. A new screen of an existing page needs only a descriptor and its map line in `ScreenOutlet`; a new page needs one loader line, never a static import.
  - Routes are generated from the descriptor mirror. `screens.generated.ts` is never hand-edited.
  - The initial bundle is about 1.92 MB, against a `maximumWarning` of 1992kB, re-measured at each forward merge. Each lazy chunk stays under 88 kB.
  - The client is zoneless and `OnPush`, with screen state in framework-free stores.
- **A `detail` tab's body (AD-5).** `DetailPage` takes an optional `body` component that draws the rows in place of the table, with everything else `ListPage` does unchanged. 20.9's Contents tab is its first consumer, and 20.30's trace the next.
- **Embedded apps (AD-63)** are a named exception to AD-28 and AD-47.
  - Only `interopEditorSource` (`ui/src/app/core/vendor-frame.ts`) builds `/ui/interop/<app>/index.html`, with `$NAMESPACE`, from a closed vocabulary. A document value that is not a `CLASS_NAME` answers `null`, so no frame is drawn.
  - `app-interop-editor-frame` draws one unsandboxed `<iframe>`. Its `src` is set once, and a new source or `revision` draws a new element.
  - OcuPilot posts nothing into the frame and reads nothing from it. The CSP, headers, token store and CORS are unchanged.
- **Interoperability port (AD-62, `Port/InteropPort`).**
  - It is the only class that starts, stops, restarts, updates or recovers a production, and the only source of interoperability reads. It calls the vendor classes the classic pages call, in process, as the signed-in user.
  - A new read or write extends the port and names its case in AD-62 at its spec gate (a read also in AD-36). 20.9's reads are item 15, 20.30's trace item 16 and 20.31's resend item 17.
  - A new endpoint takes an explicit `Pairs` branch ahead of the `CODEPAIRS` default.
- **Gate first.** The vendor's production, lookup, partner, test and resend calls check no privilege (measured), so the port's gate is the whole gate.
  - **Order.** The endpoint's pairs, then the tool's own, then READ on the namespace's globals database (WRITE for a write). A refusal names the failed pair.
  - **Extra pairs** are declared only where a least-privileged run measured them. Each is refused by name before any port call, and a test that removes it pins it.
  - **The floor** admits `%Ens_Portal:USE`, so every new surface declares its own pair. The `InteropFloor*` rosters pin this.
- **Classic pages and adjustment (AD-44, AD-64).** `Screen.Gate.RequiredPairs` is the one reader of a screen's requirement. It unions the custom resource of each classic page the screen replaces. A port's pairs and the vendor's are never adjustable.
- **SQL reads without grants.** `InteropPort` reads `Ens.MessageHeader` and `Ens_Util.Log` through `SqlRows`, with `%ExecDirectNoPriv` after its own gate. No such statement nests a query that carries `TOP`: on a cold cached query that is refused with SQLCODE -99, and a copy a privileged reader warmed hides the failure. Use separate top-level statements, or a top-level `UNION ALL` of `TOP` branches.
- **Namespace.** `appliesWhen` uses `IsEnsembleNamespace`, and `%IsDeepSeeEnabled` for Analytics. A port switches by explicit save and restore and calls no `OcuPilot.*` class while switched, so local-to-UTC conversion runs before the switch.
- **Write shape.**
  - **Action-style.** Each write declares its request type and fingerprints a fresh read the port composes. Anything the vendor would answer as a silent success is refused by name before any vendor call.
  - **Two callers, one operation (AD-53).** A screen action and the agent's write share the fresh read, the prohibited set inside the per-target lock, the gate, the change event and the read-back. A person's action is never asked of governance.
  - **Dry-run review (AD-53).** A screen action whose tool declares `DRYRUN` is reviewed through `POST /screens/:screen/dryrun`, which resolves it as the action route does and stops before the write, answering the rows the agent's card shows. The person's action then carries the reviewed digest, and the port refuses it when the review moved. 20.31 builds the route, and any later `DRYRUN` tool reuses it.
  - **One request.** Each write finishes in its own confirm request, with no spawn site.
  - **Snippets.** Every port that defines `Invoke` also defines a pure `Snippet`, with secrets as placeholders.
- **Audit.** Item and setting changes go through `Ens.Util.Auditing.AuditModifyProductionConfig`. A contents read and a resend record the vendor's own message audit events. Writes the vendor does not audit record OcuPilot's own `ConfigChange`.
- **Reuse rather than copy.** Extend the shared helpers: on the server `SqlRows`, `LocalStamp`, `RenderTargetHere`, `ClassFieldsHere`, `ParseTestFields`, `SecretPath`, `Ledger.LocalToUtc`, `IsTestWrite` and the `INTEROP.TEST.*` codes; on the client `core/test-answer.ts`, `DataTable`'s getters, the typed-name dialog and the shared skeleton and fault classes; in the tests `runIris`, `list-spec.mjs`, `panel-spec.mjs`, `MintAs`, `ConfirmHttp`, `ProductionProbe` and InteropFloor's principals.
- **Reads and ids.** Interoperability reads use source kind `interop`. Every read has a row cap and reports truncation. A parent-scoped list takes its parent's route id as its one criterion. An id keeps every part exactly and is percent-encoded in one path segment. A set target takes the integerset rule, as `interop-message` does.
- **Tools.**
  - New interoperability tools extend the `InteropAction` hierarchy, are named `<area>.<screen>.<verb>` and declare their `CLASSICPAGES`. Each new write type is reviewed against AD-10's prohibited set.
  - A turn starts with the shell area's tools, `shell.tools.find` and the screen context's `tools`.
  - For Gemini, keep numeric enums at the top level of the schema.
- **Untrusted content.** Message bodies and headers, session participants, log text, names, settings, rule, DTL or BPL content, cube, member and folder item names and MDX results are untrusted. They reach the screen only as interpolated text, and the model only through the one sanitizer. No gate or test relies on the sanitizer as its defense.
- **Measure on the instance**, and amend the spine at the spec gate rather than working around it.

## UX & Interaction Patterns

- **Loading.** A screen's first load shows its skeleton until the first page arrives (two-second target), never on a re-fetch.
- **Rail and tabs.**
  - Interoperability and Analytics follow System Explorer, and appear only where the namespace reports the feature.
  - A screen joins the side bar only once it has shipped. EXPERIENCE.md lists no Analytics side-bar entries yet, so 20.11 adds them.
  - An item's tabs are Status, Settings, Queue, Log, Messages, Jobs and Test. A message's tabs are Header, Contents and Trace.
- **Embed screens** are `viewer (source)` screens with a bar above the frame holding the note and Refresh. The editors' bar also says the agent reads only what is saved. The Schema viewer shows no skeleton, empty sentence or refusal of its own. The Configuration diagram behaves as the editors do.
- **Classic links** open in a new tab, and their caption notes that the classic portal may ask the user to sign in again. A classic-link card is never placed on a list screen.
- **Gated controls are never hidden.** They stay focusable and `aria-disabled`, and name the failed pair.
- **Strings.**
  - Each list or tab has a title, an empty state and three suggested prompts. A write-capable list's empty state adds the line inviting the agent.
  - Every new string goes into EXPERIENCE.md's Fixed strings and `strings.ts`, whose values are unique. A refusal sentence lives once, on the server, pinned equal to its fixed string.
  - `strings.test.mjs` bounds the literal count at 3,800. The count was 3,374 before 20.9, 20.30 and 20.31 (20.31 adds about 25). The next raise comes when the count is within 50 of the bound.
- **Dialogs.** A dialog exists only where EXPERIENCE.md's dialog list names one, so 20.31 adds its resend and edit-and-resend reviews to it. Dialogs never stack. A destructive screen action uses the typed-name confirm.
- **Auto-refresh** is opt-in per screen, off by default, and declared in the descriptor and in EXPERIENCE.md's roster.
- **Cards.**
  - Proposal cards follow the standard lifecycle. An agent's destructive proposal carries no typed name.
  - A block over about eight lines starts collapsed with a summary line. Confirm never requires expanding it.
  - A code change behind an editor shows the line diff, and its consequence says the editor opens the document again and drops changes not saved there.

## Cross-Story Dependencies

- **Done:** 20.1 to 20.7, 20.13 to 20.24, and 20.27 to 20.29. 20.16's second rework, which fixed the cause of the Retention flake (DW-2285), is in CI run 38532797700, so a red on that test is no longer the known flake.
- **Order:** 20.8, 20.9, 20.30, 20.31, 20.10, 20.11, 20.12, 20.25, 20.26, then the burn-down.
- **20.8** re-anchors to 20.16's merged editor page, and shows 20.16's agent line only on the rule, BPL and DTL kinds.
- **20.30 consumes** 20.9's message tab group, `body` input, pairs, id check, header row builder and synthetic-header fixture; 20.4's `SqlRows`, `LocalStamp` and the `interop-message` entity type; and 20.6's Test dialog, its `sessionId` and the probe fixture. 20.9 is not yet built, so 20.30 builds against 20.9's spec.
- **20.31 consumes** 20.9's list (multi-select), Header tab, message pairs, id check and raw view; 20.30's `interop.messagetrace.read`, which its integration criterion reads the resent header through; 20.6's field model, `SecretPath` and Test dialog; and 20.23's action-write shape and digest. Neither 20.9 nor 20.30 is built yet, so its Task 0 re-anchors on their shipped code.
- **Consumers.** 20.12's Investigate cites a session's rows through `interop.messagetrace.read`, and its resend-failed-messages workflow proposes `interop.messages.resend`.
- **20.10** comes after 20.31. Its integration criterion exercises 20.16's save under source control.
- **20.11** builds on 20.1's Analytics area and its `appliesWhen`, and touches no interoperability code (inference). Epic 21's analytics editors wait on it.
- **Known defects.**
  - **DW-2395 is fixed on feature** by Epic 18's 18.38: `LogSourcePort` no longer closes a null device the process already held. 20.7's browser spec no longer tolerates the vendor's `NOTOPEN` notice.
  - **On the owner's hold:** DW-2394 (the vendor uses the null device without opening it) and DW-2396 (the schema viewer's `&ST`).
  - **DW-2408, routed to the burn-down:** 20.6's `interop-item-test.browser-spec.mjs` leaves the host test's message headers and the probe production's `Ens_Util.Log` rows behind in USER.
- **Epic 18 runs beside this epic.**
  - **Shared rosters** take add-only edits, summed at the forward merge:
    - the entity types and their id rules, the screen mirror, `strings.ts`, the navigation tests and EXPERIENCE.md's rows;
    - the tool rosters in `ReadTool`, `ToolRoundTrip`, `ToolEmit` and `SurfaceCoverage` (385 tools after 20.16 and 18.38; 20.9 and 20.30 add four);
    - `Test/StageTwoTools`' `Elsewhere` block, which needs a row for every new Epic 20 screen;
    - `ToolWrite`'s other-port write count (49 after 20.16), which 20.31's two tools update in the same pass.
  - **Ask first** before editing anything else contended, such as `Screen/Registry.cls`, `Screen/Read.cls`, `Kernel/EntityType.cls`, the prohibited set, the governance baseline, `LogSourcePort`, `app.routes.ts`, `angular.json` or the CI files.
  - **Interoperability usage** (18.37) is an OS management screen, read in `%SYS` through `MonitorPort`, not `InteropPort`.
- **Into Epic 21.** Its SQL tuning track extends 20.12's diagnose-slow-query workflow, its analytics editors wait on 20.11, and its interoperability parity and harvested tools wait on Epic 20's merge. Epic 21 owns interoperability credentials, purge, deployment, record maps, workflow and the analytics editors, so those stay out of this epic.
