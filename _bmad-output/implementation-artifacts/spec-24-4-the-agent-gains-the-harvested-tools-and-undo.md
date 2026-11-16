---
title: 'Story 24.4: The agent gains the harvested tools and undo (first slice: the fourteen session and message tools)'
type: 'feature'
created: '2026-11-15'
status: 'done'
baseline_revision: '814552475df7d443b470c912f4cfaf9296258bf4'
baseline_commit: '814552475df7d443b470c912f4cfaf9296258bf4'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/harvest/iris-session-agent.md'
warnings: ['oversized', 'multiple-goals']
deferred: []
---

<intent-contract>

## Intent

**Problem:** The agent cannot follow an interoperability session. It can list message headers in a time window (`interop.messages.read`) and trace one message's session, but it cannot ask "which sessions came from this host", "what happened in session 4711", "which sessions share this super-session" or "show me this message's header and body together". iris-session-agent answers these with 28 read-only tools that the PRD says the agent gains in Stage 5, beside undo.

**Approach:** This is the first slice of the story; Design Notes › Proposed split charters the rest, undo included. The agent gains fourteen read tools, each harvested from one iris-session-agent tool by taking its rules and query, never its classes or names (harvest map §3). The data is read through `InteropPort` (AD-62), behind its gate:

- three new port reads, `Sessions`, `SessionSummary` and `SessionMessages`;
- the existing `MessageHeader` and `MessageContents` reads.

| Sibling tool | OcuPilot tool | Port read |
|---|---|---|
| `search_by_time` | `interop.sessions.bytime` | `Sessions` |
| `search_by_status` | `interop.sessions.bystatus` | `Sessions` |
| `search_by_source` | `interop.sessions.bysource` | `Sessions` |
| `search_by_target` | `interop.sessions.bytarget` | `Sessions` |
| `search_by_message_class` | `interop.sessions.bybodyclass` | `Sessions` |
| `search_by_session` | `interop.sessions.byid` | `Sessions` |
| `search_by_super_session` | `interop.sessions.bysupersession` | `Sessions` |
| `find_related_sessions` | `interop.sessions.related` | `Sessions` |
| `find_sessions_using_class` | `interop.sessions.byclass` | `Sessions` |
| `session_summary` | `interop.session.summary` | `SessionSummary` |
| `session_timeline` | `interop.session.timeline` | `SessionMessages` |
| `message_headers` | `interop.session.headers` | `SessionMessages` |
| `get_message_detail` | `interop.message.detail` | `MessageHeader`, then `MessageContents` |
| `get_message_body` | `interop.message.body` | `MessageContents` |

## Boundaries & Constraints

**Always:**

- **Each tool declares `KIND` `read` at definition time** (AD-22), through one new abstract base. Each is dispatched like every other tool: `Dispatch.AnswerOne` asks `Governance.Gate.Decide` once, then checks the pairs, then validates the arguments, then invokes. A read needs no baseline key.
- **Gate first (AD-29, AD-62 rule 2).** Before any vendor call, `InteropPort` checks the endpoint's pairs, then that the namespace runs interoperability (409 `INTEROP.NAMESPACE`), then READ on its globals database.
  - `Sessions`, `SessionSummary` and `SessionMessages` take `MESSAGEPAIRS` (`%Ens_Portal:USE`, `%Ens_MessageHeader:USE`), the classic Message Viewer's.
  - `interop.message.detail` and `interop.message.body` add `MESSAGECONTENTPAIR` (`%Ens_MessageContent:USE`).
  - Each tool's `PrivilegePairs` answers its endpoints' pairs, so a missing pair is refused `AUTH.NOPRIVILEGE` by name before the port is reached.
- **Bounded (AD-24, AD-36).**
  - A windowed search reads `hours` (1 to 720, default 24) ending at `endDateTime` (a local `YYYY-MM-DD HH:MM:SS`, default now). It is never open-ended.
  - The window becomes ID bounds by top-level statements, as `ListMessages` does.
  - A keyed lookup (`byid`, `bysupersession`, `related`, the `session.*` tools) leads on an indexed column (`SessionId`, `Ens.SuperSessionIndex.SuperSession`) and takes no window.
  - Every read is capped by `maxRows` (1 to 500, default 50; `byclass` 1 to 100, default 20, with `hours` 1 to 168) and reports `truncated`.
- **No caller value in SQL text (AD-21).** Every value is bound. An enum or column choice (`status`, `match`) selects a fixed fragment.
- **Vendor tables are read with `%ExecDirectNoPriv` after the gate** (AD-29), through `InteropPort.SqlRows`, in the target namespace by explicit save and restore (AD-16). No statement nests a `TOP`.
- **No compile-time interoperability dependency (AD-62 rule 12).** No shipped class names an `Ens.*` class where the compiler resolves it.
- **Absent reads as no rows (AD-37).** A session, header or super-session no row holds answers zero rows and is never a fault.
- **A body read records the vendor's `ViewContents`** through `ReadMessageContents`, as `interop.messagecontents.read` does (AD-62 rule 15).
- **Results reach the model only through AD-60's sanitizer and AD-24's cap**, as every tool result does. Tool code adds nothing to either.
- **Contended files take add-only edits, except those named in Design Notes › Contended files.**

**Never:**

- An iris-session-agent class, package, name or token in source, comments included. The checker refuses `SessionAgent`.
- A caller-chosen namespace, `%session`, `%request` or `$NAMESPACE` in a tool body. The namespace is `Kernel.Scope.Current()`.
- A screen, descriptor, route, write tool, governance key, client file or EXPERIENCE.md row.
- The fourteen tools Design Notes › Proposed split moves to Stories 24.21 to 24.23, and undo (Story 24.20).
- Rule decisions on `interop.message.detail`: they are read by Story 24.21's rule-log tool (Design Notes › Named limits).
- An edit to `Screen/Registry.cls`, `Screen/Tool/Registry.cls`, `Kernel/Agent/Dispatch.cls`, `Kernel/Governance/*`, `Workflow.cls`, `angular.json` or the CI workflow files.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Window search | `bysource {source:"OcuProbeIn", hours:2}`; headers from that source 1 h and 3 h ago | One row per session, newest first: `SessionId, FirstTime, Source, Target, BodyClass, Status, Messages, Errors`. Only the 1 h session. | none |
| Status list | `bystatus {status:["Error","Discarded"]}` | Sessions holding a header in either status | A word outside the nine: 400 `PORT.VALIDATION` naming `status` |
| Window too wide | `bytime {hours:721}`, or `byclass {hours:169}` | Nothing read | `TOOL.ARGUMENTS` (schema maximum) |
| Keyed session | `byid {session:"4711"}` | That session's row, read with no window | No such session: zero rows |
| Super-session | `bysupersession {superSession:"K1"}`, or `{session:"4711"}` as the seed | The sessions indexed under the key, or under the seed's key | Both or neither given: 400 `PORT.VALIDATION`. A seed with no key: zero rows |
| Related | `related {session:"4711"}` | The other sessions sharing 4711's super-session, without 4711 | A seed with no super-session: zero rows |
| Class blast radius | `byclass {className:"Demo.Msg", match:"any"}` | Sessions whose source, target or body class equals it | Bad class-name shape: 400 naming `className` |
| Summary | `session.summary {session:"4711"}` | One row: `SessionId, Messages, Errors, FirstTime, LastTime, Seconds, RootBodyClass` | No such session: zero rows |
| Timeline and headers | `session.timeline {session, beginDateTime?, endDateTime?}`; `session.headers {session, errorsOnly?}` | The session's headers in `ID` order, `MessageRow`'s columns plus `Step`, capped | Bad bounds: 400 naming the criterion |
| Detail | `message.detail {message:"123"}` | The 23 header rows, then the contents' first lines as `{Name:"Body", Position, Value}` rows | Missing content pair: `AUTH.NOPRIVILEGE` naming `%Ens_MessageContent:USE` |
| Body | `message.body {message:"123", summary:true}` | The contents rows; `summary` keeps the first 256 characters | A body the port cannot render: `INTEROP.MESSAGE.CONTENTS` |
| Pair missing | a caller with `%Ens_Portal:USE` alone calls any of the fourteen | Nothing read | `AUTH.NOPRIVILEGE` naming `%Ens_MessageHeader:USE` |
| Not interoperability | the turn's namespace runs no interoperability | Nothing read | 409 `INTEROP.NAMESPACE` |

</intent-contract>

## Code Map

All paths are under `/Users/jbrandt/git/OcuPilot/.worktrees/epic-24/` unless absolute.

**Tool framework (read; do not edit `Registry.cls` or `Dispatch.cls`):**

- `src/OcuPilot/Screen/Tool/Base.cls`: the contract.
  - `TOOLNAME` :26 and `KIND` :30; `DESCRIPTION` :44.
  - `InputSchema` :62, `ResultSchema` :69, `PrivilegePairs` :92, `SecretArguments` :112 (declare `pDeclared=1`).
  - `View` :136; `ArgumentsRefusal` :146, `InternalRefusal` :158, `BoundedMaxRows` :167.
- `src/OcuPilot/Screen/Tool/Registry.cls`: discovery by reflection (`ToolClasses` :804), so a compiled class is the whole registration.
  - `TOOLNAMEPATTERN` :46 allows three lower-case alphanumeric segments.
  - `SCHEMAKEYWORDS` :63: no `pattern`, `format`, `default`, `$ref` or `oneOf`.
  - `ProviderTools` :354 refuses an empty description or an undeclared `SecretArguments`.
  - `ValidateArguments` :778.
- `src/OcuPilot/Screen/Tool/ErrorRead.cls`: the nearest class read tool over a port. Copy its `View` shape.
- `src/OcuPilot/Screen/Tool/ExplorerSourceRead.cls` and `src/OcuPilot/Kernel/Shell/ReadTool.cls`: the abstract-intermediate precedent the new base follows. Note `Kernel.Scope.Current()` at `ExplorerSourceRead.cls:109`.
- `src/OcuPilot/Kernel/Agent/Dispatch.cls` `AnswerOne` :186: gate :241 (`GateClass` :53 is the test seam), pairs :288, validation :308, invoke :333, cap :356 (`Bound.Apply` for a `rows` result).
- `src/OcuPilot/Kernel/Governance/Gate.cls` `Decide`: a read is allowed without resolving its tool.

**The port (extend):**

- `src/OcuPilot/Port/InteropPort.cls`
  - `ENDPOINTS` :122, `Pairs` :1010, `Invoke` :1177, `Admit` :1287, `InvokeRuntime` :3567 (the LIST branch to extend).
  - `SqlRows` :4118 and `Mapped` :3474; `LocalStamp` :4050 and `StoredStamp` (before `ListMessages`).
  - `SQLMAX` :4164, `MessageRow` :4228, `LOWERIDSQL` :4253, `SEARCHSQL` :4260, `STATUSWORDS` :4275, `MESSAGEIDPATTERN` :4283, `CLASSNAMEPATTERN` :4286.
  - `MessageCriterionReason` :4289 and `RefuseCriterion`; `ListMessages` :4334 (the window and ID-bound pattern to reuse); `TRACESQL` and `ListMessageTrace` :4410.
  - `ReadMessageHeader` :4450, `ReadMessageContents` :4575 (records `ViewContents`).
  - `MESSAGEPAIRS` :271, `MESSAGECONTENTPAIR` :275, `MAXROWSKEY` :815.
- `src/OcuPilot/Kernel/Scope.cls` `Current()`.

**Vendor (read-only reference):**

- `irislib/Ens/MessageHeader.cls` :14-:28: `TimeCreated`, `SessionId`, `Status`, `SourceConfigName`, `TargetConfigName` and `MessageBodyClassName` are indexed.
- `irislib/Ens/SuperSessionIndex.cls` :10-:20: `SuperSession` is indexed as `SQLUPPER(250)`; `MessageHeader` is indexed.

**Sibling (read-only, never copied by name):** `/Users/jbrandt/git/iris-session-agent/src/SessionAgent/Tool/`

- `Search/Base.cls`: the window rule. Its default-window bug is not carried.
- `Search/SearchBy{Time,Status,Source,Target,MessageClass,Session,SuperSession}.cls`: one grouped query; only the predicate differs. `SearchByTime`'s open-ended range is not carried.
- `Search/FindSessionsUsingClass.cls`; `Inspection/FindRelatedSessions.cls`.
- `Inspection/SessionSummary.cls`, `SessionTimeline.cls` and `MessageHeaders.cls`: their uncapped reads are capped here.
- `Inspection/GetMessageDetail.cls` and `GetMessageBody.cls`.

**Tests (extend; contended literals in Design Notes):**

- `src/OcuPilot/Test/InteropMessageRead.cls` `StoreHeader`: the synthetic-header fixture.
- `src/OcuPilot/Test/InteropMessageTrace.cls`: the shape for a port-plus-tool test on stored headers.
- `src/OcuPilot/Test/InteropFloorTurn.cls` with `TurnWireFixture`: the armed real-turn pattern.
- Rosters:
  - `Test/ReadTool.cls` :93-:94 (447 and the name list);
  - `Test/ToolRoundTrip.cls` `REFUSEEMPTY` :103;
  - `Test/ToolEmit.cls` :158-:442 (one branch per tool source; the `Else` fails an unknown one);
  - `Test/InteropFloor.cls` `OPERATORTOOLS` :73 and `ADMINISTRATORTOOLS` :84;
  - `Test/ToolsFind.cls` (ranking; check only).
- `scripts/check-objectscript.py` `FORBIDDEN_LITERALS` :228-:239.
- `scripts/ci-throwaway.sh` `# classes:` arming lines, held by `ui/tools/ci.test.mjs`.

## Tasks & Acceptance

**Execution:**

- [x] **Task 0 (`ocupilot-b-ci`, HSCUSTOM, measure only, nothing left behind).**
  - (a) A grouped `SELECT TOP ? SessionId, MIN(...) ... GROUP BY SessionId` over an ID-bounded window runs through `SqlRows` for a principal holding only `MESSAGEPAIRS` and READ on the namespace's database.
  - (b) A `SuperSession` equality on `Ens.SuperSessionIndex` uses its index (`%SYS.PTools` plan or `EXPLAIN`).
  - Record both under Design Notes › Measured. If (a) refuses, read sessions as top-level header rows grouped in ObjectScript under the same cap, and record that.
- [x] `src/OcuPilot/Port/InteropPort.cls` -- add `Sessions`, `SessionSummary` and `SessionMessages` to `ENDPOINTS` and their `MESSAGEPAIRS` to `Pairs`. Route them in `InvokeRuntime`'s LIST branch to new private `ListSessions`, `ReadSessionSummary` and `ListSessionMessages`. Each validates its criteria by name (`RefuseCriterion` reasons appended to `MessageCriterionReason`), binds every value, reuses `LOWERIDSQL`, `StoredStamp`, `MessageRow` and `TRACESQL`'s session statement, and caps at `maxRows`. Update the class doc's endpoint list. -- one port, one gate (AD-62).
- [x] `src/OcuPilot/Screen/Tool/InteropInspect.cls` (new, abstract, `KIND` `read`) -- the shared base. It provides:
  - `PrivilegePairs` from `InteropPort.Pairs` for the tool's declared `ENDPOINTS`;
  - `SecretArguments` declaring none;
  - a `View` that validates, builds the port query from the tool's arguments (`Query` hook), calls `InteropPort.Invoke` with `Kernel.Scope.Current()`, and answers `{fields, rows, truncated, rowsSent, rowsAvailable, truncatedFields}`;
  - the common schema members (`hours`, `endDateTime`, `maxRows`).
- [x] `src/OcuPilot/Screen/Tool/InteropSessionsBy{Time,Status,Source,Target,BodyClass,Id,SuperSession,Class}.cls`, `InteropSessionsRelated.cls`, `InteropSessionSummary.cls`, `InteropSessionTimeline.cls`, `InteropSessionHeaders.cls`, `InteropMessageDetail.cls`, `InteropMessageBody.cls` (fourteen new) -- each declares `TOOLNAME`, `DESCRIPTION`, its schema and its `Query`; nothing else. -- extend, don't copy (Rule 31).
- [x] `src/OcuPilot/Test/InteropSessionRead.cls` (new) -- port-level coverage, on headers it stores with `InteropMessageRead.StoreHeader` and `Ens.SuperSessionIndex` rows it creates and removes by marker:
  - every matrix row;
  - window edges (721 and 169 refused; a header one second outside the window is absent);
  - the cap and `truncated`;
  - zero rows for an absent key;
  - `MESSAGEPAIRS` refused to a holder of `%Ens_Portal:USE` alone, through the gate seam.
- [x] `src/OcuPilot/Test/InteropSessionTools.cls` (new) -- tool-level coverage:
  - each of the fourteen is listed by the registry with `kind` `read` and is advertised by `ProviderTools` under its wire name;
  - a call through `Dispatch.AnswerOne` with a recording `GateClass` asks the gate exactly once, with kind `read`, before the port, and answers the port's rows;
  - the content pair is refused by name on `detail` and `body`, with the header pair alone;
  - `body` records one `ViewContents`.
- [x] `src/OcuPilot/Test/InteropSessionTurn.cls` (new, armed `OCUPILOT_ALLOW_PRINCIPALS` and `OCUPILOT_ALLOW_TEST_PROVIDER`) -- the integration criterion, after `InteropFloorTurn`'s pattern; list it under both variables in `scripts/ci-throwaway.sh`.
- [x] Rosters -- in `ReadTool`, `ToolRoundTrip`, `ToolEmit` and `InteropFloor`, add the fourteen names and the rows each needs. Then sweep `src/OcuPilot/Test`, `ui/tools` and `ui/browser` for any other assertion on the tool count or names, and add to it.

**Acceptance Criteria:**

- AC1: Given the registry on a fresh instance, when tools are listed, then each of the fourteen appears once under its canonical name with `kind` `read`, is advertised under its wire name, and has a non-empty description. With any one class's `KIND` removed, the listing and the checker's rule 14 both refuse.
- AC2: Given each of the fourteen called from a turn, when `Dispatch.AnswerOne` runs, then `Gate.Decide` is asked once, with kind `read`, before any pair check or port call. A caller missing a declared pair is answered `AUTH.NOPRIVILEGE` naming it, and the port is not reached.
- AC3: Given synthetic sessions in an interoperability namespace, when each tool runs with the matrix's inputs, then it answers exactly the matrix's rows, bounded and reporting `truncated`, and refuses each malformed input by name with nothing read.
- AC4 (integration, Rule 1): Given an armed principal holding `MESSAGEPAIRS` and not `%Ens_MessageContent:USE`, and a real turn job on the stub provider, when the turn calls `interop_sessions_bysource` and then `interop_message_body`, then the first step carries the planted session's row inside `<ocupilot-data>`, and the second is refused `AUTH.NOPRIVILEGE` naming the content pair. The turn completes.
- AC5: Given the shared rosters, when the suites run on a fresh throwaway in either order, then `ReadTool`, `ToolRoundTrip`, `ToolEmit`, `InteropFloor` and `ToolsFind` are green, and removing any one new row reddens its test alone.

### Review Findings

Code review 2026-11-15 (full-opus; blind-hunter, edge-case-hunter, verification-gap, acceptance-auditor). High 0, medium 5, low 7, rejected 9.

- [x] [Review][Patch] [med] Two-hour window legs depended on no foreign header in the last two hours (the lower ID bound) — the fixture now brackets one window with two session-less headers stored around H3, and every two-hour leg in `InteropSessionRead`, `InteropSessionTools` and `InteropSessionRoute` ends at `WindowEnd`.
- [x] [Review][Patch] [med] The body-class searches (`bodyclass`, `class` with `match` body) were asserted with "contains" — exact `AssertEquals` on the ordered sessions.
- [x] [Review][Patch] [med] `hours` and `endDateTime` carries of `bytime`, `bystatus`, `bytarget`, `bybodyclass`, `byclass` and the timeline's `endDateTime` were unpinned — two legs per tool and a timeline leg in `TestEachArgumentChangesWhatIsRead`.
- [x] [Review][Patch] [low] The default row bounds (50, and 20 for `byclass`) were unpinned — `TestTheDefaultRowsAreTheDescribedOnes`.
- [x] [Review][Patch] [low] The route's zero-view checks had no in-test control — `ViewControl` after each.
- [x] [Review][Patch] [low] `SESSIONMESSAGESSQL` copied `TRACESQL` (Rule 31) — removed; `ListSessionMessages` reads `TRACESQL` without its `ORDER BY`.
- [x] [Review][Patch] [low] Stale doc claims in `InteropInspect` (subclasses declare "nothing else"), `InteropSessionTurn` ("records no view"), `InteropSessionRoute` (`HOSTILE`, "six other reads") and `InteropSessionRead` (a header with no session id) — corrected.
- [x] [Review][Defer] [med] A port criterion refusal reaches the model as a bare `PORT.VALIDATION` and the tool step as "That tool could not be answered on this instance." — DW-2629, decision-pending (string).
- [x] [Review][Defer] [med, unverified] A 720-hour session search aggregates the whole window before `TOP` — DW-2630, escalated.
- [x] [Review][Defer] [low] Three descriptions omit the per-header alternative; `Step` numbers the rows answered; `detail` names no rule-log tool — DW-2631, decision-pending (string).
- [x] [Review][Defer] [low] `interop.message.detail` drops the header rows when the body is not text — DW-2632, wontfix-accepted.
- [x] [Review][Defer] [low] Nine search tools repeat the `FIELDS`/`ENDPOINTS` literals — DW-2633, wontfix-accepted.
- Rejected: Proposed strings' "reach the agent and the tool step" is wrong and the code right (AD-39: a tool result renders the code; `Dispatch.cls` is out of bounds); the six reasons live in the port fault's `reason`, read today only by a direct port caller, and the sentence is the lead's to correct · session rows take each column's minimum and the lowest status (the harvested grouped query, the matrix's columns) · `enum` on `status`/`match` (the matrix specifies `PORT.VALIDATION`) · detail reads the body when `maxRows` is 23 or less (already rejected) · an over-long `superSession`'s sentence (the schema bounds it; no screen) · a comma inside a status item, a null `TimeCreated`, a non-object port answer (theoretical) · Auto Run Result's "six strings" and file list (spec text) · descriptor roster edits and the spine's missing session clauses (already ruled) · the arming line's missing comment (cosmetic).

## Spec Change Log

- 2026-11-15, runner spec gate (unattended rulings, one veto item): (1) the `Proposed split` is applied in `epics.md`: 24.4 keeps the fourteen session and message tools; Stories 24.20 (undo, criterion word for word), 24.21, 24.22 and 24.23 are inserted after 24.19. (2) The six `Proposed strings` are kept as written. (3) The spine is not edited in this run: the AD-62 item 19 and AD-36 lines wait as proposed lines for the owner's attended architecture update; the `Proposed AD` for undo goes to the orchestrator when 24.20 is planned (a new AD is never written by a runner). (4) The edits to rosters and counts shared with Epic 21 append this story's members only (orchestrator ruling A); `origin/OCU-1-epic21` has none of this story's files changed against feature at this gate.

## Review Triage Log

### 2026-11-15 — Review pass

- verdicts: 13 findings — high 0, medium 2, low 11, false 0, maybe-false 0
- findings:
  - `[medium]` `patch` tool `Query` hooks drop secondary arguments with no test noticing — added `TestEachArgumentChangesWhatIsRead` (errorsOnly, beginDateTime, superSession, a two-word status list, `match`, `hours`, `endDateTime`); two mutations observed red and reverted.
  - `[medium]` `patch` hermeticity: `bytime`, `bystatus` and `bybodyclass` legs read the instance's newest 50 sessions — `maxRows` 500 on those three calls.
  - `[low]` `patch` `InteropSessionTurn` zero-view assertion has no positive control — the assertion is dropped there (AC4 pins the refusal by name); `InteropSessionTools` takes a positive control before its zero assertion.
  - `[low]` `patch` test doc comments claim mutation outcomes the spec does not record — the comments are removed; the spec's `## Verification` holds the lines.
  - `[low]` `patch` dead `"hours": 2` in `TestTheCapReportsTruncated` — removed.
  - `[low]` `reject` `InteropMessageDetail` records a view when `maxRows` is under 23 and no body row is returned — rare input; the fix adds a branch.
  - `[low]` `reject` window cut by header ID, so a session's counts can include headers older than the window — the same rule `ListMessages` applies (Design Notes, Named limits).
  - `[low]` `reject` `SESSIONKEYSQL` takes an arbitrary key when one session's headers sit under several — no such session was shown to exist.
  - `[low]` `reject` session rows aggregate the headers that matched the search, not the whole session — the sibling's grouped query does the same; tool descriptions say "it holds there".
  - `[low]` `reject` the 168-hour and 100-row maxima for `byclass` live in the tool schema, not the port — the matrix names the schema as the surface (`TOOL.ARGUMENTS`).
  - `[low]` `reject` tool pairs are derived from the port, so `ToolEmit` re-derives its expectation — `InteropFloor`'s role rosters and the pair-refusal legs pin the mapping from outside.
  - `[low]` `reject` non-append edits in `InteropPort` and four rosters (`InteropDescriptor`, `InteropHostDescriptor`, `InteropFloor`, `ReadTool`) — each is an appended member; the port is not an Epic 21 file.
  - `[low]` `reject` no tool-level test of the not-interoperability row — the port refuses it before any tool logic and `InteropSessionRead` pins it.

## Design Notes

**Governing ADs (Rule 6).**

- AD-22 is the read declaration and the single gate.
- AD-1 (in process), AD-29 and AD-8 (the gate, caller's own privileges) and AD-62 (the port).
- AD-36 and AD-24 (bounded reads; read tools, not declared reads, as `explorer.sqlquery.read` and the source reads are).
- AD-21 (bound values), AD-16 (namespace), AD-37 (absence), AD-11 and AD-60 (untrusted text), AD-41 (the ledger row every call already gets).

Checked and not engaged:

- AD-23: the harvest seam takes REST handler bodies that answer through `RenderResponseBody`. These sibling tools have another contract (`Invoke(ctx, args, .result)`), so `HarvestPort` would read every one as "no render". The harvest map (§3) says to take their rules and improve the mechanism, and the epic preamble's "handler bodies are taken and nothing else" concerns the MCP suite's bodies.
- AD-6, AD-15, AD-52, AD-58: no write.
- AD-66: no workflow is changed.

**Spine clauses for the spec gate (Rule 20; the runner writes them; veto items).**

- **AD-62, a new item 19, "Session reads":** `InteropPort` gains `Sessions`, `SessionSummary` and `SessionMessages` (`LIST`) under `MESSAGEPAIRS`, read with `%ExecDirectNoPriv` after the gate.
  - A windowed read is at most 720 hours, turned into ID bounds as `Messages` is.
  - A keyed read leads on `SessionId` or `Ens.SuperSessionIndex.SuperSession`.
  - They serve the agent's harvested tools and no screen.
- **AD-36, one sentence beside the source reads:** "The agent's harvested session and message tools (Story 24.4) are read tools, not declared reads, bounded by their own `maxRows` and AD-24."

**Extend, don't copy (Rules 2 and 31).**

- **The tools.** One abstract base, `InteropInspect`, as `ExplorerSourceRead` and `Shell/ReadTool` are. Each tool is a declaration over it. `ErrorRead` is the nearest concrete sibling.
- **The port.**
  - The three reads extend `ListMessages`' validation, window and binding, and `ListMessageTrace`'s session statement.
  - The nine sibling searches become one `ListSessions` with fixed predicate fragments. That is the sibling's own shared query, written once instead of nine times.
  - `detail` and `body` reuse `ReadMessageHeader` and `ReadMessageContents` unchanged.
- **The tests** extend `InteropMessageRead`'s fixture and follow `InteropMessageTrace` and `InteropFloorTurn`.

**Integration, Consumes, Consumed-by (Rules 1 and 2).**

- **Integration:** AC4.
- **Consumes:**
  - Story 20.9 (`Messages`, `MessageHeader`, `MessageContents`) and Story 20.30 (the session statement);
  - the tool registry and dispatch (Epics 4 and 14) and the turn job;
  - `InteropMessageRead`'s fixture and `TurnWireFixture`.
- **Consumed-by:**
  - Story 24.21: its rule-log and event-log tools filter by session through this base, and its process-instance tool reads the session the summary names (inference);
  - Story 24.22: its body searches reuse `ListSessions`' window and the contents rendering.

**Decided in-stage (plan).**

- **The slice is the fourteen tools that read sessions and messages.** They share three port reads and one base; the split follows the data each sibling tool reads.
- **Names.** `interop.sessions.*` names a search answering one row per session; `interop.session.*` a read of one session; `interop.message.*` a read of one message. The sibling names cannot pass `TOOLNAMEPATTERN`.
- **The window is `hours` back from `endDateTime`**, never a free begin and end. Every range is then bounded by construction, which fixes the sibling's open-ended `search_by_time`.
- **Times are the instance's local `YYYY-MM-DD HH:MM:SS`**, as `interop.messages.read` takes and answers them, not the sibling's UTC `Z` form.
- **`interop.message.detail` answers header and body, not rule decisions.** The rule log is a separate classic page with its own resource (`%Ens_RuleLog:USE`). Its reader is Story 24.21's tool, which this tool's description names.
- **Timeline and headers need only `MESSAGEPAIRS`.** They are the Message Viewer's rows for one session, which that page shows under `%Ens_MessageHeader:USE`. The trace screen's `%Ens_MessageTrace:USE` is for its diagram.
- **The tools carry no `DESCRIPTORCLASS`.** They are reached through `shell.tools.find`, so no screen's context tool list changes (inference: binding them to Messages would put fourteen more tools in that screen's starting set).
- **Descriptions** follow Story 23.12's exemption for searches and checks. Each says, in one or two sentences:
  - what one row is;
  - its bound;
  - which list to use instead for one header per row (`interop.messages`).

**Named limits.**

- No rule decisions on `detail` (above).
- A body read records `ViewContents` once per call, as the screen's contents tab does.
- `byclass` matches a class name against the source, target and body-class columns. A host's configuration name equals its class only when it was named so, as the sibling's own note says.

**Measured (Task 0, `ocupilot-b-ci`, nothing left behind).**

- The vendor indexes listed in Code Map were read from `irislib/`.
- (a) The grouped `SELECT TOP ? ... GROUP BY SessionId` over an ID-bounded window ran through `SqlRows` for a principal holding `%Ens_Portal:USE`, `%Ens_MessageHeader:USE` and READ on the namespace's database, and answered the planted session's row: `InteropSessionTurn`'s first step. No fallback to grouping in ObjectScript was needed.
- (b) `ssi.SuperSession = ?` does not use `Ens.SuperSessionIndex.SuperSession` (its subscript is `%SQLUPPER(250)` and the property allows 300). `%SQLUPPER(ssi.SuperSession, 250) = %SQLUPPER(?, 250) AND ssi.SuperSession = ?` reads that index map (`EXPLAIN`), so the port uses it.
- `MIN(col)` answers an upper-cased name here, as the column collates; `MIN(%EXACT(col))` answers it as stored, so the session rows use the second.

**Contended files (Epic 21 registers through the same rosters; check each against `origin/OCU-1-epic21` before editing).** These edits are not pure appends:

- `Test/ReadTool.cls` :93: the count literal 447 becomes 461 and its message sentence gains this story. Fourteen names go into the sorted name list at :94.
- `Test/ToolEmit.cls`: a new `ElseIf` branch before the `Else` at :442.
- `Test/InteropFloor.cls`: the twelve `MESSAGEPAIRS` tools go into every roster that holds `interop.messages.read` (`OPERATORTOOLS` :73), and `detail` and `body` into every roster that holds `interop.messagecontents.read` (`ADMINISTRATORTOOLS` :84). Each literal is sorted.
- `Test/ToolRoundTrip.cls` `REFUSEEMPTY` :103 takes thirteen `tool:CODE` rows. Every tool but `bytime` requires an argument; `bysupersession` answers `PORT.VALIDATION`.
- `Port/InteropPort.cls`: `ENDPOINTS`, `Pairs`, `InvokeRuntime` and `MessageCriterionReason` are edited in place. Epic 21 does not edit this file (inference from its footprint).

Add-only: `scripts/ci-throwaway.sh`'s two `# classes:` lines.

**Governance keys:** none. All fourteen are reads.

**Proposed strings (veto item).** No screen string is added. The new port refusal reasons are the port fault's `reason` (a direct port caller reads it; a tool result carries the code only, AD-39, and the gap is DW-2629):

- `hours`: "hours must be a whole number from 1 to 720."
- `endDateTime`: "endDateTime must be a local date and time, written YYYY-MM-DD HH:MM:SS."
- `status`: "status must name one to nine of Created, Queued, Delivered, Discarded, Suspended, Deferred, Aborted, Error, Completed."
- `superSession`: "Give either superSession or session, not both and not neither."
- `className`: "className must be a class name."
- `match`: "match must be any, source, target or body."

**Proposed split** (for the runner, Rule 5 tier 2; numbered from 24.20). The story's criteria are cut as follows:

- **24.4 (this story), "The agent gains the harvested tools and undo":** "**Given** the fourteen harvested session and message tools (search_by_time, search_by_status, search_by_source, search_by_target, search_by_message_class, search_by_session, search_by_super_session, find_related_sessions, find_sessions_using_class, session_summary, session_timeline, message_headers, get_message_detail, get_message_body) **When** they are added **Then** each declares `read` or `write` at definition time and passes the single call-time gate, like every other tool."
- **24.20 "Undo by snapshot and revert":** verbatim, "**Given** undo **When** it is built **Then** it captures a snapshot **before** the write and offers a one-click revert **And** the revert is itself a **confirmed proposal with its own diff and its own audit marker** - undoing is a write, not an exemption from the write model **And** the state-capture model it needs is what kept it out of Release 1, so it is designed here rather than retrofitted." It is planned once the orchestrator rules on the Proposed AD below.
- **24.21 "The agent's harvested log, process, source and configuration tools":** "**Given** the ten harvested tools event_log, rule_log, get_business_process_instance, get_business_process_source, list_business_process_methods, get_class_source, get_rule_source, get_production_config_item, get_queue_state and explain_error **When** they are added **Then** each declares `read` or `write` at definition time and passes the single call-time gate, like every other tool."
  - `get_production_config_item` answers every set setting value, so it needs the settings read's secret masking (AD-35).
  - `explain_error`'s table text names the sibling and must be rewritten.
- **24.22 "The agent's harvested message body searches":** "**Given** the three harvested tools inspect_body_candidates, search_by_body_field and find_sessions_by_body **When** they are added **Then** each declares `read` or `write` at definition time and passes the single call-time gate, like every other tool."
  - They read search tables and body text.
  - A caller's regular expression needs a bound.
- **24.23 "The agent's harvested vocabulary tool":** "**Given** the harvested tool vocab_lookup **When** it is added **Then** it declares `read` or `write` at definition time and passes the single call-time gate, like every other tool."
  - Its `save` mode writes a per-user store the sibling keeps, with a decay task and its own audit events. That is a change to stored data, and its plan decides whether it is a write tool.

The 28 tools each appear exactly once: 14 + 10 + 3 + 1.

**Proposed AD (for the orchestrator; never written by this run).** In the spine's format; the number is the orchestrator's next.

### AD-<n> — Undo is a revert proposal minted from a snapshot the confirm took, and only a write that declares its inverse can be undone

- **Binds:** Story 24.20; `Kernel/Proposal/Confirm` and `Mint`; every write tool that declares an inverse; AD-3, AD-6, AD-9, AD-10, AD-13, AD-14, AD-15, AD-22, AD-26, AD-30, AD-34, AD-35, AD-37, AD-40, AD-41, AD-52, AD-56, AD-58. It settles the `## Deferred` row "Undo by snapshot and revert".
- **Prevents:**
  - a revert that skips the write model;
  - a revert that silently overwrites a change made after the agent's;
  - a snapshot that holds a secret or lives unbounded;
  - an undo offered for a write nothing can reverse (a delete, a purge, a sent message, a password).
- **Rule:**
  1. **What is captured, and when.** A write tool is revertible only if it declares `UNDO`: either `self`, a merge reverted by the same tool sending the snapshot's values for the fields it changed, or the canonical name of a non-destructive inverse write tool on the same port and entity type (stop for start, disable for enable, a non-destructive delete for a create).
     - Never revertible:
       - a delete;
       - a `DESTRUCTIVE` tool;
       - a tool carrying a secret (AD-56);
       - a write whose diff changes a field the tool's classification does not mark ordinary (AD-3, AD-35);
       - a write the port answers as started (AD-26).
     - A test fails a declaration that breaks this.
     - For a declaring tool, inside the confirm transition, after the fingerprint re-read matched and the claim won and before the port write, the confirm stores the verified fresh read. That is the transition's re-read, never the mint's payload, and it holds only the ordinary fields the write sends (its derived list, AD-3).
     - After the read-back (AD-58), the snapshot records the after-state digest of the same fields, by AD-6's fingerprint rules.
     - A snapshot that cannot be stored never fails or alters the write. The answer says the change cannot be reverted, as a failed marker is reported (AD-15).
  2. **Where it lives, and for how long.** One row per snapshot in OcuPilot's protected state (AD-9), `Kernel/State/Snapshot`. The target is a weak reference (AD-13, AD-37). The row is revertible for 24 hours (`UNDOSECONDS`), then swept by the retention task. A user holds at most 200; the oldest is swept first (AD-41). Only the user who confirmed the original may revert it.
  3. **The revert.**
     - One click on a confirmed card asks the instance to mint a revert proposal. It is browser-only, as confirm is (AD-40).
     - The instance re-reads the target through the inverse tool's declared port (AD-52) and compares it with the snapshot's after-digest.
     - A mismatch is refused `UNDO.TARGETCHANGED`, naming the fields that moved, and nothing is minted, so a later change is never overwritten. A target that is gone is `UNDO.TARGETGONE`; a lapsed snapshot is `UNDO.EXPIRED`; a reverted one is `UNDO.DONE`.
     - Otherwise it mints an ordinary proposal for the inverse tool from the snapshot's values, with its own fresh read, diff, fingerprint, prohibited review (AD-10), both switches (AD-30) and the inverse tool's governance key (AD-22). No key is added.
     - It is shown as a card and confirmed like any other (AD-34): its own ledger row, change event and read-back, and its own marker carrying `reverts` (the original proposal id) beside the vendor's event (AD-15).
     - Confirming it marks the snapshot reverted. The revert's own confirm takes a snapshot like any declaring write, so it too can be reverted.
  4. **Scope.** Only an agent proposal's confirm takes a snapshot. A person's own screen write (AD-53, AD-55) does not, but it moves the target, so a revert across it is refused by rule 3.

**Stored-data shape it implies (veto item: a change to how stored data is kept).** `OcuPilot.Kernel.State.Snapshot` (table `OcuPilot_Kernel_State.Snapshot`, in the `OCUPILOT` database):

- `ProposalKey` (the original's, unique index);
- `UserName`;
- `ToolName` and `InverseTool`;
- `TargetRef` and `TargetKey` (AD-13, indexed with `State`);
- `Before`, a JSON object of ordinary fields only, at most 32,000 characters, else no snapshot;
- `AfterDigest`;
- `ChangedFields`, field names only;
- `CreatedAt` and `ExpiresAt`;
- `State`: `live`, `reverted` or `expired`;
- `RevertKey`, the revert proposal's key;
- `ConvKey`.

There is no secret column and no list property. The ledger row and marker are unchanged except for the marker's `reverts` member.

## Verification

**Shared surfaces:**

- the tool registry's count and names (`ReadTool`);
- `ToolRoundTrip`'s `REFUSEEMPTY`;
- `ToolEmit`'s per-source branches;
- `InteropFloor`'s role rosters;
- `ToolsFind`'s ranking;
- `InteropPort`'s `ENDPOINTS` and `Pairs`;
- the `ci-throwaway.sh` arming rosters, held by `ui/tools/ci.test.mjs`.

The implement stage greps `ui/browser`, `ui/tools`, the `ui/src` specs and `src/OcuPilot/Test` for the old count, `interop.messagetrace.read`'s roster neighbours and the endpoint list. Each file it changes joins the `(loop)` set.

*Every test added or changed passes on a fresh environment, in either order.* Each test stores its own headers and super-session rows by marker and removes them after each test. No test reads a store being empty.

**Setup (slot B, the throwaway `ocupilot-b-ci` only; never the dev instance `ocupilot-slot-b`).** Every check that creates principals or stores rows runs there.

- `(loop)` **Load `src`:**
  1. `rsync -a --checksum --delete /Users/jbrandt/git/OcuPilot/.worktrees/epic-24/src/ /Users/jbrandt/.ocupilot-throwaways/ocupilot-b-ci/src/`
  2. In `docker exec -i ocupilot-b-ci iris session iris -U HSCUSTOM`, run `$System.OBJ.LoadDir("/opt/ocupilot/src/OcuPilot","ck-d",.tErrors,1)`.

**Commands.** Run each in the foreground with `timeout: 600000`, one test run at a time, and keep one call under about 170 s. Read results from `%UnitTest_Result`.

- `(loop)` The new classes, one per call: `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.InteropSessionRead`, then `--class OcuPilot.Test.InteropSessionTools`, then `--class OcuPilot.Test.InteropSessionTurn`. Expected: green.
- `(loop)` The changed classes, batched from `ui/tools/ci-timings.json`:
  - `ReadTool`, `ToolRoundTrip`, `ToolEmit` and `ToolsFind`;
  - `InteropFloor`, `InteropMessageRead`, `InteropMessageTrace` and `InteropMessageContents`;
  - then every class the sweep changes.

  Expected: green.
- `(loop)` `cd ui && npm run test:tools`. Expected: green (`ci.test.mjs` holds the arming rosters).
- `(loop)` `uv run scripts/check-objectscript.py` and `bash scripts/lint-docs.sh`. Expected: clean.
- `(once)` The full ObjectScript sweep: `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --shard k/17` for k = 1 to 17, one per call. Expected: green.
- **Left to CI:** the full browser suite. This story changes no client file.

**Pinning mutations (Rule 19, planned).** The implement stage applies each, observes red, reverts byte-identically and recompiles, then records the line.

- AC1: `InteropInspect`'s `KIND` emptied → `InteropSessionTools`' listing leg, and `check-objectscript.py` rule 14.
  - mutation: `KIND = ""` on `InteropInspect` -> the registry listing refuses and `InteropSessionTools` reddens in all six methods, and `check-objectscript.py` names each concrete tool (nearest KIND is ''); reverted, recompiled.
- AC2: `InteropInspect.PrivilegePairs` answers `""` → `InteropSessionTools`' pair-before-port leg.
  - mutation: `PrivilegePairs` answers `""` -> `TestAMissingPairIsRefusedByNameBeforeThePort` (all fourteen) and `ToolEmit.TestEveryLiveToolRequiresItsScreensPairs` redden; reverted, recompiled.
- AC2: `Dispatch.AnswerOne`'s `Decide` call is skipped for kind `read` (a temporary edit, reverted) → `InteropSessionTools`' gate-asked-once leg.
  - mutation: `Decide` skipped for kind `read` -> `TestEachToolAsksTheGateOnceThenReadsThePort` reddens alone, for every tool; `Dispatch.cls` reverted (`git status` clean) and recompiled.
- AC3: `ListSessions` drops the window's lower ID bound → `InteropSessionRead`'s outside-the-window leg.
  - mutation: the window's lower ID bound bound as `0` -> `TestEachKindAnswersItsSessions` (the three-hour leg), `TestAClassNameIsMatchedWhereItIsAsked` and `TestTheWindowIsBoundedAndExact` redden; reverted, recompiled.
- AC3: the `related` read keeps the seed session → its related leg.
  - mutation: the seed's exclusion bound as `0` -> `TestTheSuperSessionReads` reddens alone; reverted, recompiled.
- AC3: `maxRows` is ignored → the cap leg.
  - mutation: `ListSessions` binds `SQLMAX` in place of the cap -> `TestTheCapCutsAndAMalformedCriterionIsRefused` reddens alone; reverted, recompiled.
- AC3 (tool arguments): each tool passes its own arguments on.
  - mutation: the `errorsOnly` line removed from `InteropSessionHeaders`, and separately the `hours` carry removed from `InteropSessionsBySource` -> `InteropSessionTools.TestEachArgumentChangesWhatIsRead` reddens alone each time; reverted byte-identically, recompiled.
- AC4: `InteropMessageBody` declares no content pair → `InteropSessionTurn`'s refused-step leg.
  - mutation: `ENDPOINTS = "MessageHeader"` on `InteropMessageBody` -> `InteropSessionTurn` reddens at its refused-step assertion, and `InteropSessionTools`' content and body legs redden; reverted, recompiled.
- AC5: one name removed from `ReadTool`'s list, and separately the count → `ReadTool` red alone.
  - mutation: `interop.session.summary` removed from the list, and separately the count set to 460 -> `ReadTool.TestTheRegistryListsDescriptorReadsAndInheritedKinds` reddens alone each time; reverted, recompiled.
- AC5: one `InteropFloor` row removed → that test alone.
  - mutation: `interop.sessions.related` removed from `OPERATORTOOLS` -> `TestTheToolsEachPrincipalHoldsAreItsRoster` reddens alone (operator and administrator); reverted, recompiled.
  - mutation: `interop.sessions.byid:TOOL.ARGUMENTS` removed from `REFUSEEMPTY` -> `ToolRoundTrip` reddens alone; the `ToolEmit` branch's class test made false -> `TestEveryLiveToolRequiresItsScreensPairs` reddens alone for the fourteen; reverted, recompiled.

**QA (real route, armed).** `src/OcuPilot/Test/InteropSessionRoute.cls` (QA, new; armed `OCUPILOT_ALLOW_PRINCIPALS` and `OCUPILOT_ALLOW_TEST_PROVIDER`, listed in both `# classes:` lines of `scripts/ci-throwaway.sh`): a real least-privileged principal runs a real turn job per test; no gate seam stands in. `node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.InteropSessionRoute` -> 6 tests, green. Mutations, each reverted byte-identically and recompiled:

- mutation: `Sessions` dropped from `MESSAGEPAIRS` in `InteropPort.Pairs` -> `TestAHolderOfTheMenuPairAloneIsRefusedAllFourteen` (with four others) reddens.
- mutation: the `AuditViewMessage` call in `AuditViewHere` removed -> `TestAContentHolderReadsABodyAndItsDetail` reddens alone.
- mutation: `ListSessions` binds the window's lower ID bound as `0` -> `TestTheWindowTheCapAndAbsenceHoldOverTheRoute` reddens alone.
- mutation: `InteropInspect.View`'s own row cut disabled -> `TestTheWindowTheCapAndAbsenceHoldOverTheRoute` reddens alone. Binding `SQLMAX` in place of the cap in the port alone reddens nothing at the route, since the tool cuts to its cap too; `InteropSessionRead` pins the port's cap.
- mutation: `InteropInspect` `MAXHOURS` 720 -> 9999 -> `TestTheBoundsAndRefusalsHoldOverTheRoute` reddens alone.
- mutation: `Sanitize.Neutralize` returns its input -> `TestASessionsHostileTextReachesTheModelCleaned` reddens alone.

**Code review (patched tests).** On `ocupilot-b-ci`, each reverted byte-identically and the tree reloaded:

- mutation: the `bodyclass` fragment and its bound value removed from `ListSessions` -> `InteropSessionRead.TestEachKindAnswersItsSessions` reddens alone (run 842).
- mutation: the `hours` carry removed from `InteropSessionsByStatus` -> `InteropSessionTools.TestEachArgumentChangesWhatIsRead` reddens alone (run 843).
- mutation: `InteropSessionsByClass` `DEFAULTROWS` 20 -> 500 -> `InteropSessionTools.TestTheDefaultRowsAreTheDescribedOnes` reddens alone (run 844).
- After the reverts: `InteropSessionRead` 8/8, `InteropSessionTools` 8/8, `InteropSessionRoute` 6/6, `InteropSessionTurn` 1/1 green.

## Auto Run Result

Status: done
Blocking condition: none

**Summary.** The agent gains fourteen read tools over three new `InteropPort` reads (`Sessions`, `SessionSummary`, `SessionMessages`, all under the message viewer's pairs) and the existing `MessageHeader` and `MessageContents` reads. One abstract base, `InteropInspect`, holds the gate-facing contract; each tool is a declaration over it.

**Files changed.**

- `src/OcuPilot/Port/InteropPort.cls`: three endpoints, their pairs, the runtime routing and the six proposed refusal strings.
- `src/OcuPilot/Screen/Tool/InteropInspect.cls` and fourteen `InteropSession*` / `InteropMessage*` tool classes (new).
- `src/OcuPilot/Test/InteropSessionRead.cls`, `InteropSessionTools.cls`, `InteropSessionTurn.cls` and `InteropSessionProbe.cls` (new); `scripts/ci-throwaway.sh` arms the turn class.
- Appended roster members in `ReadTool`, `ToolRoundTrip`, `ToolEmit`, `InteropFloor`, `InteropDescriptor` and `InteropHostDescriptor`.

**Review.** 13 findings, 0 high, 2 medium, 11 low: 5 patched (tool-argument pass-through test added, hermetic caps, positive control for the zero-view check, dead line, mutation narration removed from comments), 8 rejected with reasons in the Review Triage Log. None deferred. Follow-up review recommended: false (two medium patches, both tests).

**Verification.** `LOADERRORS=0` on `ocupilot-b-ci`. The three new classes, the changed rosters and their neighbours are green; the full ObjectScript sweep ran all 17 shards green after the last patch (5,670 tests, 0 failed). `npm run test:tools` (2,292), `check-objectscript.py` (0 problems), `lint-docs.sh` and `screen-mirror --check` are clean. Mutations are recorded under Verification.

**Decided in-stage (implement).** `bysource` and `bytarget` refuse an empty name with the fallback sentence; `message.detail`'s `maxRows` caps header and body rows together; the grouped session read uses `MIN(%EXACT(col))` and the super-session equality uses the index's `%SQLUPPER(250)` form.

**Residual risks.** Session row counts cover the headers matching the search; the window assumes header IDs rise with time, as `ListMessages` does. `interop.message.detail` names no tool for rule decisions until Story 24.21 lands one.
