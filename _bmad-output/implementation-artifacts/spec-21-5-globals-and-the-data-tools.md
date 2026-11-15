---
title: 'Story 21.5: Globals and the data tools'
type: 'feature'
created: '2026-11-15'
status: 'blocked'
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: ['oversized', 'multiple-goals']
deferred: []
---

<intent-contract>

## Intent

**Problem:** System Explorer has no globals surface. The classic Globals page (`%CSP.UI.Portal.GlobalList`) lists a namespace's globals and links to View (`UtilExpGlobalView.csp`) and Edit (`UtilExpGlobalDrill.csp`), and deletes, exports, imports, finds and replaces. OcuPilot offers none of these.

**Approach (conditional on the split ruling in Design Notes):** This story covers list, view, edit and kill. A new `GlobalPort` provides a declared, bounded globals list (the screen and the agent's read tool), and a screen-only node page that pages through a global with an explicit cursor. Three writes go through the one-operation path (AD-53): editing a node's value, which only the person can do; deleting a node and every node below it, which only the person can do; and deleting a whole global, which the agent may also propose. Each delete uses the typed-name confirmation and its key ships `false`. OcuPilot's own globals and protected globals are refused from either caller.

## Boundaries & Constraints

**Always:**

- `GlobalPort` is the only product class that reads or writes a global's nodes. It checks its own gate before any read or write (AD-29). It switches namespace by save and restore (AD-16).
- The namespace is the route's scope and must be one the caller can read. It is never a caller string inside a reference (AD-21).
- The global name must match `^%?[A-Za-z][A-Za-z0-9]*(\.[A-Za-z0-9]+)*$` (31 characters at most, `^` optional).
- A node is identified by its canonical reference text, `$Name` form, with no `|namespace|` part. The port parses it only with `$QLength` and `$QSubscript`. It rebuilds the reference by subscript indirection over the parsed values and requires the rebuilt `$Name` to equal the text it was given. Caller text never reaches `@`, `Xecute` or `$XECUTE`.
- Every read is bounded:
  - The list is capped by rows.
  - A node page holds 50 to 500 rows (default 100). Each value and subscript display is cut at 1,000 characters and flagged. A page holds at most 1,000,000 characters.
- Node values and subscripts are a screen-only payload (Design Notes, AD-36). They never reach a declared read, a read tool, screen context, the model, a log line, the ledger or an audit payload.
- Each write reads its target back (AD-58) and emits one change event (AD-14).

**Never:**

- No export, import, or find and replace in this story (proposed 21.17 and 21.18).
- No new node is created; edit changes an existing node's value only.
- No `$ZKill`: a kill removes the node and every node below it.
- No value edit through `%Studio.Global.Set` format 2 (it decodes with `$XECUTE`).
- No harvested `ExecuteMCPv2.REST.Global` body (Design Notes).
- No user-facing string beyond those the spec gate rules.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| List | `system-explorer/globals` in `USER`, default criteria | rows `Name`, `Database`, `Collation`, `Journal` from `%SYS.GlobalQuery:NameSpaceList`, system globals hidden, capped, `truncated` reported; agent's `explorer.globals.read` answers the same rows | none |
| Page | person opens `^ZZProbe` | first 100 nodes in `$Query` order from the start node, each `{reference, value, cut, editable, below}`; `next` cursor when more | none |
| Cursor | `after` = last row's reference | the next page, no row repeated | 400 `PORT.VALIDATION` if not canonical |
| Hostile text | reference `^G($$x())`, `^G(1)_x`, `^|"%SYS"|G`, an unmatched quote | nothing evaluated, nothing read | 400 `PORT.VALIDATION` |
| Edit | person saves `^ZZProbe(1)` = `new` (plain text ≤ 1,000) | dialog confirm, `Value` written, read-back matches, page re-reads | none |
| Not editable | value is a `$List`, holds a control character, or is over 1,000 characters | Edit drawn disabled with the reason; the route refuses too | 409 `GLOBAL.NODE.NOTEDITABLE` |
| Bad value | new value with a control character or over 1,000 characters | nothing written | 400 `GLOBAL.VALUE.SHAPE` |
| Moved | node changed or killed after the dialog opened | nothing written | 409 target-changed (fingerprint) / 404 `GLOBAL.NODE.NOTFOUND` |
| Node kill | person deletes `^ZZProbe(2)`, types `^ZZProbe` | node and descendants gone, read-back absent | none |
| Global kill | agent proposes `explorer.globals.delete` `^ZZProbe`; person confirms with typed name | global gone from the list | none |
| Own / protected | any write to `^OcuPilot*` (any case), or a node resolving to OcuPilot's database or one of the seven protected databases | refused before any write, both callers, key on or off | 409 `PROHIBITED.PROTECTEDGLOBAL` |
| Code global | a write to a `CODEGLOBALS` member, resolving to the install namespace's routines database, that is the whole global or reaches an own-name subscript | refused | 409 `PROHIBITED.OCUPILOTCODE` |
| No privilege | caller lacks WRITE on the global's database | vendor `<PROTECT>` | 403 `PORT.ACCESSDENIED` |
| Key off | default baseline, agent's global kill | governance refusal | as every key-off write |

</intent-contract>

## Code Map

- **Classic pages (measured, read-only, slot A `ocupilot`, 2026-11-15):**
  - The list page `irissys/%CSP/UI/Portal/GlobalList.cls`:
    - `RESOURCE` is `%Development` (:22).
    - It queries `%SYS.GlobalQuery:NameSpaceList` (:93-94, `ExecuteRS` :315-331, called as `(ns, spec, showSys, , , 1)`).
    - View and Edit link to `UtilExpGlobalView.csp` and `UtilExpGlobalDrill.csp` (:111-112).
    - Delete calls `%Studio.Global.Kill(name, 1)` (:578-606).
    - Export and Import open `%CSP.UI.Portal.Dialog.Export` and `Import`.
    - The Find and Replace pane is `irissys/%CSP/UI/System/FindPane.cls`, which offers no Replace in `%SYS` (:178).
  - `NormalizePage` answers:
    - `%CSP.UI.Portal.GlobalList`;
    - `/csp/sys/exp/UtilExpGlobalView.csp` → `%cspapp.exp.utilexpglobalview`;
    - `/csp/sys/exp/UtilExpGlobalDrill.csp` → `%cspapp.exp.utilexpglobaldrill`;
    - `/csp/sys/exp/UtilExpFindReplace.csp` → `%cspapp.exp.utilexpfindreplace`.
  - `^SYS("Portal")` is undefined, so no custom page resource is assigned.
  - The View, Drill and Find pages are deployed stubs with no source (#5360), so their action sets are inferred.
- **`NameSpaceList` (measured):**
  - It has 13 columns: `Name, Location, ResourceName, Permission, Empty, Keep, Collation, PointerBlock, GrowthBlock, HasData, Journal, LockLocation, HasSubscripts`.
  - `HSCUSTOM` lists 68 globals without system globals and 927 with them. Subscript-level mappings come back as separate rows, such as `oddDEF("%"):("%SYS.")`.
  - OcuPilot's globals (`OcuPilot.Kernel.State.BaseD`, `OcuPilotTurnSignal`, …) sit in `/durable/iris/mgr/ocupilot/` under `%DB_OCUPILOT`.
- `irislib/%Studio/Global.cls`:
  - `Kill` :12 (`Kill @Node`).
  - `Set` :28, whose format 2 uses `$XECUTE`, so it is not used.
  - `GlobalList` :71-146, the classic node walk, with a 32,000-byte row set.
  - `format` :148, the display form and value format 1/2/3. Reuse it for display.
  - `validateGlobalNode` :226.
- **MCP suite (read-only), `/Users/jbrandt/git/iris-execute-mcp-v2/src/ExecuteMCPv2/REST/Global.cls`:** `GetGlobal` :14, `SetGlobal` :63, `KillGlobal` :123, `ListGlobals` :172 and `BuildGlobalRef` :257 exist. None are harvested (Design Notes).
- **Closest siblings:**
  - `src/OcuPilot/Area/Explorer/SqlData.cls` and `Port/SqlPort.cls` `BrowseRequest`/`BrowsePlan`/`BrowseRun` are the screen-only page model: gate, shape, self-protection, then the page. Nothing is logged.
  - `Screen/Tool/ExplorerSqlDataSave.cls` is the person-only write model (`ADVERTISED` 0, `SCREENVALUES`, key `false`, ungoverned for a person).
  - `Screen/Descriptor/ExplorerRoutineList.cls` is the list descriptor model (criteria `pattern`, `system`; `toolIdentifier`; `rowActions`).
  - `Screen/Descriptor/ExplorerSqlData.cls` is the screen-only descriptor model.
  - `Screen/Tool/ExplorerDelete.cls`, `ExplorerRoutineDelete.cls` and `AnalyticsTermListDelete.cls` are the delete tool models.
- `src/OcuPilot/Kernel/Proposal/Prohibited.cls`:
  - Parameters: `COVEREDTYPES` :282, `SYSTEMDATABASES` :440, `OCUPILOTLOCK` :469, `OCUPILOTCODE` :811, `CODEGLOBALS` :933, `NESTEDCODEGLOBALS` :939.
  - Methods: `Codes` :1100, `ReasonFor` :1108, `IsOcuPilotLock` :2717, `OwnDatabaseNames` :3131, `OwnNameStems` :3903, and the `Lock` arm :2666 as the arm model.
- Registration rows (add-only):
  - `Kernel/EntityType.cls` `TYPES` :134;
  - `Kernel/Governance/Baseline.cls` (explorer keys near :206);
  - `Screen/Read.cls` source ports (`SOURCEATELIER` :252, `SOURCEBACKUP` :300, dispatch near :685);
  - `Api/Router.cls` beside `/explorer/sql/data` :253.
- **Client:**
  - `ui/src/app/areas/system-explorer/data-browser.page.ts` and `.store.ts` (`DATA_PATH` :72) are the screen-only page and store model.
  - `ui/src/app/shell/screen-action-handler.ts` holds `DESTRUCTIVE_ACTIONS` and `DESTRUCTIVE_CONSEQUENCES`.
  - Also touched: `core/proposal-view.ts`, `core/strings.ts`, `core/screens.generated.ts` and `core/self-protection.ts`.
- **Side bar:** System Explorer positions 1-14 are taken, and `ExplorerDocumentHashes` is 14. Globals takes 15.

## Tasks & Acceptance

**Execution, batch 1 (server; commit when its loop commands are green):**

- **Task 0, on `ocupilot-ci`:** record the results under Design Notes before writing code, and restore every probe. Every item is (inference) until measured.
  - (a) `$QLength`/`$QSubscript` on the matrix's hostile texts: does either one ever evaluate, and what does it answer? Also the `$Name` round trip of a `$H`-style subscript (`"67000,123"`) and of `"1"` against `1`.
  - (b) `%SYS.Namespace.GetGlobalDest` for a subscripted reference under a subscript-level mapping. Compare its directory form with `OwnDatabaseNames`' and `SYSTEMDATABASES`' directories.
  - (c) `%Studio.Global.format` on a `$List`, a control character, a 2,000-character value and an undefined node.
  - (d) Whether `Set`/`Kill` of a global records a vendor audit event with auditing on.
  - (e) A `<PROTECT>` read and write on a read-only database (`IRISLIB`): the status text and how `Kernel.Fault` maps it.
  - (f) The time of a 500-row page over a deep global.
  - (g) `NameSpaceList`'s `Location` against the `Database` field the Routines list shows, so that the two columns read alike.
- `src/OcuPilot/Port/GlobalPort.cls` (new) -- `PAIRS` `%Development:USE`. It has three endpoints:
  - `Globals` `LIST`: `NameSpaceList(ns, pattern, system, , , 1)`, capped, rows `Name, Database, Collation, Journal`, rows with `(` in `Name` dropped.
  - `Globals` `GET`/`DELETE`: the fresh read is `{Name, Defined}`, and the delete is `Kill ^Name`.
  - `Node` `GET`/`PUT`/`DELETE`, keyed by canonical reference: the fresh read is `{Reference, Value, Defined, Editable}`. `PUT` sets the reviewed `Value`, and `DELETE` kills the node.

  `Page(ns, request)` is screen-only. It takes `{global, start, after, pageSize}`, walks with `$Query` from the start or after the cursor, and answers `{rows, next, cut}`.

  The refusals are `GLOBAL.NOTFOUND`, `GLOBAL.NODE.NOTFOUND`, `GLOBAL.NODE.NOTEDITABLE` and `GLOBAL.VALUE.SHAPE`. The port also has the `ParseReference` helper, the read-back and `Snippet` (AD-59). A test seam stands in for the vendor walk.
- `src/OcuPilot/Api/GlobalError.cls` (new) -- the codes above, with the ruled sentences, and the consequences `GLOBAL.DELETE` and `GLOBAL.NODE.DELETE`.
- `src/OcuPilot/Area/Explorer/GlobalNodes.cls` (new) -- `POST /explorer/globals/nodes`, in `SqlData`'s order: gate, shape, then `Page`. Nothing is logged. The arm needs no self-protection check, because reads are not refused.
- `src/OcuPilot/Kernel/Proposal/Prohibited.cls` -- add-only changes:
  - Add `PROTECTEDGLOBAL` with its reason, and add `global` and `global-node` to `COVEREDTYPES`.
  - Add a `Global` arm, which evaluates the matrix's two self-protection rows against the resolved node inside the hold. It reuses `OwnNameStems`, `OwnDatabaseNames`, `SYSTEMDATABASES`, `CODEGLOBALS` and `NESTEDCODEGLOBALS`.
- Tools (new), each one per file:
  - `Screen/Tool/ExplorerGlobalDelete.cls`: `explorer.globals.delete`, advertised, destructive, key `false`, row action `delete` on the list.
  - `ExplorerGlobalNodeSave.cls`: `explorer.globalnodes.save`, `ADVERTISED` 0, a merge write whose settable field is `Value`, screen value `save=Value`, key `false`.
  - `ExplorerGlobalNodeDelete.cls`: `explorer.globalnodes.delete`, `ADVERTISED` 0, destructive, key `false`.

  Every one of the three tools declares `GlobalPort` and `CLASSICPAGES`.
- Descriptors (new):
  - `Screen/Descriptor/ExplorerGlobalList.cls`: route `system-explorer/globals`, position 15, `list (server criteria)`, entity `global`, criteria `pattern` (default `*`) and `system` (default `no`), `toolIdentifier` `explorer.globals`, `classicPage` `%CSP.UI.Portal.GlobalList`.
  - `ExplorerGlobalView.cls`: route `system-explorer/globals/nodes`, position 0, no declared read, row actions `save` and `delete`, `classicPage` `%cspapp.exp.utilexpglobalview`.
- Add-only rows:
  - `Kernel/EntityType.cls` gains `global` and `global-node`.
  - `Kernel/Governance/Baseline.cls` gains the three keys, each `false`.
  - `Screen/Read.cls` gains source `global`.
  - `Api/Router.cls` gains the route.
- Tests (new):
  - `src/OcuPilot/Test/GlobalRead.cls` is live-safe. It covers the list against `NameSpaceList` and the agent read; the page, cursor and cut over its own marker-named global (`^ZZOcuGlb<pid>`); every hostile text; and the route's gate.
  - `GlobalWrite.cls` covers edit, node kill and global kill on both permitted callers, `NOTEDITABLE`, `SHAPE`, target-changed, the two self-protection rows (the own-name row by a refusal before any write, never by writing an `^OcuPilot*` global), `<PROTECT>` → 403, and the key-off refusal. Each test makes and kills its own global in `OnAfterOneTest`.
- The shared-surface tests under Verification, each updated to the new shape.

**Execution, batch 2 (client; commit when its loop commands are green):**

- `ui/src/app/areas/system-explorer/global-view.page.ts` and `global-view.store.ts`, with their specs (new):
  - The page shows the node page as rows of Node, Value and Below, with a "More" button driven by the cursor and a Start node field.
  - Edit opens a one-field dialog, with Value prefilled. It is drawn disabled when the row is not `editable`.
  - Delete opens the typed-name dialog, where the name typed is the global's name.
  - The page re-reads on the change event.
  - The list's name cell opens this page.
- `shell/screen-action-handler.ts` -- `delete` on both screens is destructive, with its consequence. Also `core/proposal-view.ts` (`GLOBAL.DELETE`), `core/strings.ts`, `core/screens.generated.ts` (regenerated) and `core/self-protection.ts` (the `PROTECTEDGLOBAL` sentence).
- `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md` -- the ruled strings into Fixed strings (add-only).
- `ui/browser/system-explorer-globals.browser-spec.mjs` (new). Each step waits for the answered signal first:
  - the list shows the spec's own global;
  - the view pages through it;
  - an edit round-trips;
  - a node delete asks for the typed name and removes the node;
  - an `^OcuPilot*` row shows Delete disabled with the sentence.

**Acceptance Criteria:**

- AC1. Given a namespace holding the test's own global, when the person opens Globals and the agent calls `explorer.globals.read`, then both answer the same capped rows for the same criteria, and no row is a subscript-level mapping.
- AC2. Given that global with more nodes than one page, when the person pages through it, then every node appears once, in `$Query` order, with long values cut and flagged. No node value or subscript reaches screen context, a tool or a log line.
- AC3. Given a plain-text node, when the person edits it and confirms, then the instance holds the new value and the read-back matches. When the node changed after the dialog opened, nothing is written.
- AC4. Given the delete keys `true`, when the person deletes a node or the agent proposes a global's delete, then each asks for the global's name typed before it runs, and the target is absent after confirm. With the default baseline, the agent's proposal is refused by governance.
- AC5. Given any write to an `^OcuPilot*` global, a node in OcuPilot's own database or one of the seven protected databases, or OcuPilot's code globals, when either caller makes it, then it is refused before any write with that refusal's sentence, which the client mirror pins equal.

## Spec Change Log

## Review Triage Log

## Design Notes

**Split (decide; this halt's question).** The story's one criterion names seven operations across four backing shapes. Those are a screen-only node reader, node writes that only the person can make, a file transfer, and a bounded multi-node replace. Each sibling epic story of one shape ran about 60 to 80 files (Story 21.2: 78). Recommended split, each child taking the criterion verbatim for its operations, with a key and title that are new only for the children:

- **21.5 Globals and the data tools** (key unchanged): list, view, edit and kill. The criterion becomes "Given the global list, view, edit and kill, When each runs, Then it round-trips, every write a confirmed proposal and every kill destructive by name." This spec is written for it.
- **21.17 Global export and import**, planned next: "Given global export and import, When each runs, Then it round-trips, every write a confirmed proposal." A compliant design with no new AD entry exists (inference). It extends Story 19.13's `AtelierPort` case: `ExportToXMLFile` and `LoadXMLFiles` run `$SYSTEM.OBJ.ExportToStream`/`LoadStream`. Measured read-only on slot A: a list-only `LoadStream` of a `<Global>` export answered `ZZProbeNever.gbl` and wrote nothing. Export of a global that does not exist answered success (247 bytes), so the port needs its own presence check, because `GetDocNames` lists no globals.

  Its file is AD-21's sixth case as 19.13's is, and its download is 19.13's `export-browser`. It must bound an export's size, which is unbounded in memory there. It needs `GlobalPort`'s self-protection arm, because importing `^oddDEF` or `^OcuPilot*` is a write.
- **21.18 Global find and replace**, planned after 21.17: "Given find and replace, When it runs, Then it round-trips, every write a confirmed proposal." It is bounded (AD-36). It is a confirmed proposal, as this story's edit is, which only the person confirms because values never reach the model, and it states the count it will change.

  It likely needs an AD-51 named entry (inference): its port builds the write from the person's find and replace text, the U-58 question, though Story 21.2's freeze took a caller's limit with none. Its plan should take that up first.

That makes three stories, within the cap of six. No AC leaves Epic 21.

**Governing ADs:** AD-5, AD-6, AD-8, AD-10, AD-13, AD-14, AD-15, AD-16, AD-21, AD-22, AD-23, AD-29, AD-34, AD-36, AD-39, AD-44, AD-51, AD-52, AD-53, AD-54 (no create here), AD-58, AD-59.

**No new AD-51 or AD-21 entry.**

- Edit is an ordinary merge write (AD-4): the payload is `{Value}` over a fresh read.
- The two deletes send no body and carry no caller choice beyond the target (AD-51's base shape, subject `Defined`).
- No caller names a path, and the namespace is the route's scope (AD-21's global-source clause).

**Proposed, for the spec gate (veto window; records, not new kinds):**

- **AD-10 arm (needed):** "OcuPilot's own and the instance's protected globals (Story 21.5). The following are refused from either caller as `PROHIBITED.PROTECTEDGLOBAL`: a write to a global whose name begins with one of OcuPilot's name stems, in any case, and a write to a node that resolves to OcuPilot's own database or one of the seven protected databases (read at the write). A write to one of `CODEGLOBALS` that resolves to the install namespace's routines database, and is either the whole global or reaches a subscript that begins with an own stem, is refused as `PROHIBITED.OCUPILOTCODE`."

  The reasoning is AD-10's own: by effect, killing `^SYS("Security",…)` deletes `_SYSTEM` or OcuPilot's web application without going through either arm. Edits to other system globals stay as permitted as the classic page leaves them. Measured: OcuPilot's globals live in `/durable/iris/mgr/ocupilot/`.
- **AD-36 record (needed):** "A global's node page (Story 21.5) is a screen-only payload, as a data browser page is, because a node's subscripts and values carry no classification. It holds 50 to 500 rows, cuts each value and subscript at 1,000 characters, holds 1,000,000 characters in all, and pages by an explicit reference cursor." The global list is an ordinary declared read.
- **AD-53 record (needed):** `explorer.globalnodes.save` and `explorer.globalnodes.delete` are unadvertised, Story 19.8's case. Their card and fresh read carry node values. Their keys ship `false`, and a person's own write asks no governance key. A named gap is added if Task 0 (d) finds no vendor audit event.
- **AD-29 Binds:** add `GlobalPort` (as Story 21.2 proposed for `BackupPort`).

**Decided in-stage:**

- The `ExecuteMCPv2.REST.Global` bodies exist for get, set, kill and list (AD-23 checked). None are harvested:
  - `ListGlobals` walks `^$GLOBAL` unbounded (AD-36).
  - `GetGlobal` reads one node, with no walk.
  - `BuildGlobalRef` splits subscripts on every comma, so a `$H`-style string subscript (`"67000,123"`) addresses a different node, a numeric pair, with no error.
  - Story 21.2 took a body only where it fit (2 of its operations).
- The reference model is canonical `$Name` text with subscript indirection rebuild.
- The value format is display through `%Studio.Global.format`. Only plain text of 1,000 characters or fewer is editable, which keeps the reviewed diff whole (AD-6).
- A kill removes the node and every node below it (the classic Delete's `KillSubs` 1). The typed name is the global's name.
- Globals takes side-bar position 15, appended, because inserting at the classic menu's third place would renumber nine screens. Epic 24's future System Explorer screens resolve the position at integration (Rule 22, a union).
- Tests are not armed: each writes only its own `^ZZOcuGlb<pid>` global and kills it.

**Escalated for the spec gate's ruling:**

- **Values never reach the model** (recommended: the stricter choice). As a result, node edit and node delete are the person's alone, and the agent proposes only a whole global's delete, by name. "Every write a confirmed proposal" is then read as Story 19.8 read it: the person's confirmed dialog.

  Alternative: an agent node read tool, as `explorer.sqlquery.read`, with its named limits.
- **Self-protection is stricter than the classic page:** nodes in the seven protected databases are refused, for the AD-10 reason above. This is a security-posture change, stricter.
- **New strings** (reusing "Name", "Database", "Delete", "Edit", "Value" and "Collation" where they exist):
  - Titles: "Globals" and "Global nodes".
  - Columns: "Journal", "Node" and "Below".
  - Field and buttons: "Start node", "More" and "Edit node".
  - Empty states: "This namespace holds no global that matches." and "This global holds no nodes."
  - Agent empty phrase: "list the globals".
  - Prompts: "Which globals does this namespace hold?", "Which database stores this global?" and "Delete a global".
  - Consequences:
    - `GLOBAL.DELETE`: "Deleting removes the global and all of its data. This cannot be undone."
    - `GLOBAL.NODE.DELETE`: "Deleting removes this node and every node below it. This cannot be undone."
  - Refusals:
    - `GLOBAL.NOTFOUND`: "There is no global with that name in this namespace."
    - `GLOBAL.NODE.NOTFOUND`: "This node no longer holds a value or nodes below it."
    - `GLOBAL.NODE.NOTEDITABLE`: "Only a value of plain text, 1,000 characters at most, can be edited here."
    - `GLOBAL.VALUE.SHAPE`: "Enter plain text of 1,000 characters at most."
    - `PROHIBITED.PROTECTEDGLOBAL`: "This global holds OcuPilot's own data or the instance's protected system data, so it cannot be changed or deleted from OcuPilot."
  - Cut flag: "Value shortened".

**Extend, don't copy (Rule 2/31):**

- `GlobalNodes` follows `SqlData`'s route order. `GlobalPort.Page` follows `SqlPort.BrowseRun`'s bounds.
- The three tools subclass `Screen/Tool/Write` as `ExplorerSqlDataSave` and `ExplorerDelete` do.
- The prohibited arm reuses `OwnNameStems`, `OwnDatabaseNames`, `SYSTEMDATABASES` and `CODEGLOBALS`.
- The client page follows `data-browser.page.ts`'s store and paging, as a sibling: a grid of nodes is not a grid of SQL rows.

**Integration ACs:** `GlobalPort` is consumed in this story by its two screens, the route and its three tools (AD-53's two callers). AC1 to AC4 observe it through the API, the agent and the browser.

- **Consumes:** `Screen/Tool/Write`, `Kernel/Proposal/*`, `Kernel.Fault` and `Screen.Gate`.
- **Consumed-by:** Story 21.17, for presence and the self-protection arm on import, and Story 21.18, for the node walk, edit and the arm.

**Ledger inbox:** none.

**Contended paths:** no committed Epic 24 change beyond feature touches a file named here (checked against `origin/OCU-1-epic24`). Epic 24's worktree holds uncommitted edits to these shared files: `EXPERIENCE.md`, `ci-throwaway.sh`, `Baseline.cls`, `Prohibited.cls`, `Screen/Read.cls`, `strings.ts`, `screen-action-handler.ts`, `proposal-view.ts`, `screens.generated.ts`, and the shared tests `ClassicPageGate`, `Descriptor`, `MappingDescriptor`, `ReadTool`, `SurfaceCoverage`, `ToolRoundTrip` and `ToolWrite`. Every edit this story makes there is add-only. No System Explorer source file is in Epic 24's diff.

## Verification

**Shared surfaces:**

- The System Explorer roster, positions and count: `Navigation`, `ui/tools/navigation.test.mjs`, `screen-mirror.test.mjs`, and the System Explorer browser specs that count the side bar.
- Descriptor shape: `Descriptor`.
- The tool registry: `ReadTool`'s size +1, `ToolWrite`'s other-port count +3, `ToolRoundTrip`, `ToolDispatch`, `ToolEmit`, `SurfaceCoverage`.
- `PortGate` (the new port's pairs).
- `Prohibited`'s covered types (+`global`, `global-node`) and its code list.
- `TeardownGuard` (the new write tests).
- The read-source count (+`global`).
- `ClassicPageGate` and `MappingDescriptor` (three classic keys).
- `EndpointCoverage` (the new route).
- `GovernanceBaseline` (+3 keys).
- Entity types.
- `ui/tools/strings.test.mjs` with the EXPERIENCE.md literal cap (4200; if crossed, raise it by 400 under the file's protocol and report it).
- `proposal-view.test.mjs`.

The implement stage greps `ui/browser`, `ui/tools`, the `ui/src` specs and `src/OcuPilot/Test` for each surface. Every test it changes joins `(loop)`.

*Every test added or changed passes on a fresh environment, in either order.* Each test makes its own marker-named global and kills it, and asserts only on its own rows.

**Commands.** One command per foreground call, each with `timeout: 600000`, against `ocupilot-ci` only. Never put two test calls in one message.

- `(loop)` `sh /private/tmp/claude-501/-Users-jbrandt-git-OcuPilot/4667058b-f052-49c9-b08a-221f7f41dfab/scratchpad/e21u/lead/reload.sh /Users/jbrandt/git/OcuPilot/.worktrees/epic-21 ocupilot-ci` -- expected: `LOADERRORS=0`.
- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.GlobalRead`, one class per call. Then run each of these classes the same way: `GlobalWrite`, `PortGate`, `SurfaceCoverage`, `EndpointCoverage`, `GovernanceBaseline`, `Governance`, `Prohibited`, `ReadTool`, `ReadDescriptions`, `ToolEmit`, `ToolDispatch`, `ToolRoundTrip`, `ToolWrite`, `Descriptor`, `Navigation`, `ClassicPageGate`, `MappingDescriptor`, `TeardownGuard`, `Wire`. Expected: green.
- `(loop)` `uv run scripts/check-objectscript.py`, `uv run scripts/test_check_objectscript.py` and `bash scripts/lint-docs.sh` -- expected: clean.
- `(loop)` `cd ui && node --test tools/strings.test.mjs tools/screen-mirror.test.mjs tools/navigation.test.mjs tools/proposal-view.test.mjs`, plus every `ui/tools` test the sweep changes -- expected: green.
- `(loop)` Rebuild, redeploy and run the browser specs:
  1. `cd ui && npm run build` and `npm run test:components`.
  2. Redeploy with `docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`.
  3. `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci node --test --test-concurrency=1 browser/system-explorer-globals.browser-spec.mjs browser/system-explorer.browser-spec.mjs`

  Expected: green.
- `(once)` `cd ui && npm run test:tools` -- expected: green.
- `(once)`, owned by the runner: the full ObjectScript sweep, one class per call; `smoke.sh --container ocupilot-ci`; and Rule 30's fresh check. The full browser suite is left to CI.

**Mutations (Rule 19).** Make one per AC. Apply each, observe red, revert to a byte-identical tree and reload the reverted source, then record it here as `mutation: <change> -> <test red>`:

- AC1: drop the subscript-mapping row filter.
- AC2: make the cursor inclusive.
- AC3: remove the fingerprint's `Value`.
- AC4: set `explorer.globals.delete` to `true` in `Baseline`.
- AC5: drop the own-stem check from the `Global` arm.

## Auto Run Result

Status: blocked
Blocking condition: intent gap -- Story 21.5 is too large for one pass: seven operations across four backing shapes. Proposed split: 21.5 list, view, edit and kill (this spec; key unchanged); 21.17 global export and import (no new AD entry: Story 19.13's AtelierPort case, inference); 21.18 global find and replace (likely needs an AD-51 named entry, inference). Each child takes the criterion verbatim for its operations. Also for the gate's ruling: the AD-10, AD-36, AD-53 and AD-29 records, the stricter protected-database refusal, values never reaching the model (node writes are the person's alone), and the new strings.

Plan pass using only read-only probes on slot A (`ocupilot`); nothing ran against `ocupilot-ci`.
