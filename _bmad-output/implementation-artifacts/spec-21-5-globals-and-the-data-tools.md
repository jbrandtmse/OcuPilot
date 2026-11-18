---
title: 'Story 21.5: Globals and the data tools'
type: 'feature'
created: '2026-11-15'
status: 'in-progress'
baseline_revision: '81f86d9c497c70b9c73a17a73d576ea20fe3f718'
baseline_commit: '81f86d9c497c70b9c73a17a73d576ea20fe3f718'
review_loop_iteration: 0
followup_review_recommended: true
context: []
warnings: ['oversized']
deferred:
  - summary: >-
      A node changed after the edit dialog opened answers 400 TOOL.ARGUMENTS with an unruled plain sentence, where the matrix names 409 target-changed.
    evidence: |-
      ExplorerGlobalNodeSave.ScreenActionDelta compares the screen value Was with the fresh read; the screen action route carries no fingerprint, and no ruled sentence exists. Nothing is written, so AC3 holds. The owner rules the sentence and the status.
    location: >-
      src/OcuPilot/Screen/Tool/ExplorerGlobalNodeSave.cls:82
    severity: medium
  - summary: >-
      A saved node value may reach a change event or an audit payload, which AD-36 forbids for node values.
    evidence: |-
      ExplorerGlobalNodeSave carries the person's new value in its tool payload and the port query. Reading the change event and the audit record written after a save on ocupilot-ci would settle whether the value is stored.
    location: >-
      src/OcuPilot/Screen/Tool/ExplorerGlobalNodeSave.cls
    severity: medium (unverified)
  - summary: >-
      The Globals list's whole-global Delete typed-name dialog has no component or browser spec for an ordinary global.
    evidence: |-
      The browser spec only checks the disabled Delete row of an OcuPilot-named global; global.test.mjs matches source text. A spec in the style of interop-lookup-table-list.page.spec.ts would pin the dialog and its sentence.
    location: >-
      ui/src/app/shell/screen-action-handler.ts
    severity: low
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

## Runner rulings and owner answer (2026-11-15)

- **Split (decide):** this story keeps list, view, edit and kill; export and import are Story 21.17 (which reuses this story's `GlobalPort`, Globals list and `global` entity type, so it is planned after this one) and find and replace Story 21.18 (`epics.md`).
- **Owner answer U-59, quoted: "A: all four (Recommended)".** The three AD records this plan proposed are allowed: the AD-10 `PROHIBITED.PROTECTEDGLOBAL` arm, the AD-36 record (the node page is screen-only) and the AD-53 record (node save and delete are person-only and unadvertised). The runner writes them into the spine at this story's spec gate.
- **DW-2607 (routed here):** the protected-global arm also covers `.GBL` documents loaded by the shipped System Explorer import (Story 19.13), whose self-protection judges names only; add that import clause to the arm's wording and a test that an import of a code global or a `%`-global is refused.

</intent-contract>

## Code Map

- **Classic pages (read-only, slot A `ocupilot`):** `irissys/%CSP/UI/Portal/GlobalList.cls` -- `RESOURCE` `%Development` (:22); list from `%SYS.GlobalQuery:NameSpaceList` called `(ns, spec, showSys, , , 1)` (`ExecuteRS` :315-331); View/Edit link `UtilExpGlobalView.csp`/`UtilExpGlobalDrill.csp` (:111-112); Delete is `%Studio.Global.Kill(name, 1)` (:578-606). `NormalizePage` keys: `%CSP.UI.Portal.GlobalList`, `%cspapp.exp.utilexpglobalview`, `%cspapp.exp.utilexpglobaldrill`. View and Drill are deployed stubs with no source, so their action sets are inferred.
- `irislib/%Studio/Global.cls` -- `format` :148 is the display form (reuse); `Set` :28 format 2 uses `$XECUTE` (never used); `Kill` :12.
- `irislib/%SYS/Namespace.cls` `GetGlobalDest(ns, global, subscriptText)` :93 -- a node's database directory, `^<dir>` with the system piece blank when local.
- `src/OcuPilot/Kernel/Proposal/Prohibited.cls` -- `Prohibits` :1487 (covered-type list :1498, class/routine branch :1544, import names via `ImportedNames` :2845); `Code` :2739; `Lock` :2672 (arm model); `IsOcuPilotCode` :2906; `OwnDatabaseNames` :3131 (includes the install namespace's databases -- do not use it as the protected set); `OwnDatabaseDirectories` :3151 (reuse with `DATABASENAME` + `SYSTEMDATABASES`); `OwnNameStems` :3903; parameters `COVEREDTYPES` :282, `SYSTEMDATABASES` :440, `OCUPILOTCODE` :811, `IMPORTTARGET` :803, `CODEGLOBALS` :933, `NESTEDCODEGLOBALS` :939.
- `src/OcuPilot/Port/AtelierPort.cls` -- `Examine` :2313 (an XML file's documents, `.gbl` included, kept by name); `<PROTECT>` -> 403 mapping :2885 (model for `GlobalPort`).
- **Siblings:** `Area/Explorer/SqlData.cls` + `Port/SqlPort.cls` `BrowseRequest`/`BrowsePlan`/`BrowseRun` (screen-only page: gate, shape, then page; nothing logged); `Screen/Tool/ExplorerSqlDataSave.cls` (person-only write: `ADVERTISED` 0, `SCREENVALUES`, key `false`); `Screen/Tool/ExplorerDelete.cls`, `ExplorerRoutineDelete.cls` (delete tools); `Screen/Descriptor/ExplorerRoutineList.cls` (list descriptor, `source` `{port, endpoint, type}`, `toolIdentifier`); `Screen/Descriptor/ExplorerSqlData.cls` (screen-only descriptor); `Port/BackupPort.cls` (`PAIRS`, `ENDPOINTS`, `Invoke` :190).
- Registration rows (add-only): `Kernel/EntityType.cls` `TYPES` :134; `Kernel/Governance/Baseline.cls` explorer keys :207-217; `Screen/Read.cls` source list :478 and dispatch beside `SOURCEBACKUP` :684; `Api/Router.cls` beside `/explorer/sql/data`.
- **Client:** `ui/src/app/areas/system-explorer/data-browser.page.ts`/`.store.ts` (page and store model); `shell/screen-action-handler.ts` (`DESTRUCTIVE_ACTIONS`, `DESTRUCTIVE_CONSEQUENCES`); `core/proposal-view.ts`, `core/strings.ts`, `core/screens.generated.ts`, `core/self-protection.ts`.
- **Side bar:** System Explorer positions 1-14 are taken (`ExplorerDocumentHashes` 14); Globals takes 15.
- **Tests to extend:** `src/OcuPilot/Test/ExplorerTransfer.cls` (424 lines; `TestTheCodeArmReadsEveryNameAnImportReviewed` :363 is the arm-level model, `TestAnImportOfOcuPilotsOwnCodeIsRefusedOnBothCallers` :275 the screen-leg model).

## Tasks & Acceptance

**Task 0, on `ocupilot-ci` (implement stage, before code; restore every probe; record results under Design Notes):** (d) whether `Set`/`Kill` of a global records a vendor audit event with auditing on; (e) a `<PROTECT>` write on `IRISLIB` -- its status text; (h) whether an XML export of `^ZZOcuGlb<pid>` with the name rewritten to `%ZZOcuGlb<pid>` lists through `xml/list` as one `.gbl` document. Each is (inference) until measured. The read-only items were measured (Design Notes).

**Batch 1, server (commit when its loop commands are green):**

- `src/OcuPilot/Port/GlobalPort.cls` (new) -- `PAIRS` `%Development:USE`; namespace switch by save and restore; `<PROTECT>` -> 403 `PORT.ACCESSDENIED`. Endpoints:
  - `Globals` `LIST`: `NameSpaceList(ns, pattern, system, , , 1)`, capped, rows `Name, Database, Collation, Journal`, rows whose `Name` holds `(` dropped, `truncated` reported.
  - `Globals` `GET` (fresh read) `{Name, Defined, Locations}`, where `Locations` is every directory the global's `NameSpaceList` rows answer, subscript-level rows included; `DELETE` is `Kill ^Name`.
  - `Node` `GET` (fresh read) `{Reference, Value, Defined, Editable, Location}` (`Location` from `GetGlobalDest`); `PUT` sets the reviewed `Value`; `DELETE` kills the node. The endpoint and the entity types are the ones 21.17 extends; build no export or import here.
  - `Page(ns, request)`, screen-only: `{global, start, after, pageSize}` -> `{rows, next, cut}`, `$Query` walk, rows `{reference, value, cut, editable, below}`.
  - `ParseReference`: `^` required, `$QSubscript(ref,0)` matches the name pattern, `$QSubscript(ref,-1)` empty, rebuilt `$Name` equals the text, else 400 `PORT.VALIDATION`. Refusals `GLOBAL.NOTFOUND`, `GLOBAL.NODE.NOTFOUND`, `GLOBAL.NODE.NOTEDITABLE`, `GLOBAL.VALUE.SHAPE`. `Editable` is `%Studio.Global.format` answering 1 and length at most 1,000. A test seam stands in for the vendor walk.
- `src/OcuPilot/Api/GlobalError.cls` (new) -- the codes above, the ruled sentences, consequences `GLOBAL.DELETE` and `GLOBAL.NODE.DELETE`.
- `src/OcuPilot/Area/Explorer/GlobalNodes.cls` (new) -- `POST /explorer/globals/nodes`, `SqlData`'s order: gate, shape, then `Page`. Nothing logged.
- `src/OcuPilot/Kernel/Proposal/Prohibited.cls` (add-only) -- `PROTECTEDGLOBAL` and its reason; `global`, `global-node` in `COVEREDTYPES` and the covered-type branch list; a `Global` arm implementing the AD-10 text in Design Notes over the fresh read; the import clause (DW-2607) in the class/routine import branch: each imported name ending `.gbl` (any case) is judged after `Code`, reading `Globals` `GET` through `GlobalPort` in the target ref's scope namespace. A failed read refuses.
- Tools (new, each `Extends OcuPilot.Screen.Tool.Write`, `PORTCLASS` `GlobalPort`, `CLASSICPAGES` set): `Screen/Tool/ExplorerGlobalDelete.cls` (`explorer.globals.delete`, advertised, destructive, key `false`, list row action `delete`); `ExplorerGlobalNodeSave.cls` (`explorer.globalnodes.save`, `ADVERTISED` 0, settable `Value`, screen value `save=Value`, key `false`); `ExplorerGlobalNodeDelete.cls` (`explorer.globalnodes.delete`, `ADVERTISED` 0, destructive, key `false`).
- Descriptors (new): `Screen/Descriptor/ExplorerGlobalList.cls` (route `system-explorer/globals`, position 15, `list (server criteria)`, entity `global`, scope `namespace`, id = name without `^`, criteria `pattern` default `*` and `system` default `no`, source `{port: "global", endpoint: "Globals", type: "LIST"}`, `toolIdentifier` `explorer.globals`, `classicPage` `%CSP.UI.Portal.GlobalList`); `ExplorerGlobalView.cls` (route `system-explorer/globals/nodes`, position 0, entity `global-node`, no declared read, row actions `save`, `delete`, `classicPage` `%cspapp.exp.utilexpglobalview`).
- Add-only rows: `Kernel/EntityType.cls` (`global`, `global-node`); `Kernel/Governance/Baseline.cls` (three keys, `false`); `Screen/Read.cls` (source `global`); `Api/Router.cls` (the route).
- Tests (new): `src/OcuPilot/Test/GlobalRead.cls` (list vs `NameSpaceList` and the agent read; page, cursor and cut over its own `^ZZOcuGlb<pid>`; every hostile text; the route's gate). `src/OcuPilot/Test/GlobalWrite.cls` (edit, node kill, global kill on both permitted callers; `NOTEDITABLE`, `SHAPE`, target-changed; the self-protection rows by refusal before any write, never by writing a protected global; `<PROTECT>` -> 403; key off; the import clause at the arm: `oddDEP.gbl new` and `%ZZOcuGlb.gbl new` -> `PROHIBITED.PROTECTEDGLOBAL`, `ZZOcuGlb.gbl new` -> permitted, the target ref from `EntityRef.Key("class", "USER", "import")`, as `ExplorerTransfer` builds it). Each makes and kills its own global in `OnAfterOneTest`.
- `src/OcuPilot/Test/ExplorerTransfer.cls` -- one test (DW-2607): the screen's local import of an XML file holding `^%ZZOcuGlb<pid>` (built per Task 0 (h); if (h) does not list it, the test writes the `<Export><Global>` XML itself) is 403 `PROHIBITED.PROTECTEDGLOBAL` with the published sentence, and `^%ZZOcuGlb<pid>` stays undefined.
- Every shared-surface test under Verification, updated to the new shape.

**Batch 2, client (commit when its loop commands are green):**

- `ui/src/app/areas/system-explorer/global-view.page.ts`, `global-view.store.ts` and their specs (new) -- rows Node, Value, Below; "More" by cursor; a Start node field; Edit opens a one-field dialog, Value prefilled, drawn disabled with the reason when not `editable`; Delete opens the typed-name dialog (the global's name); re-reads on the change event; the list's name cell opens it.
- `shell/screen-action-handler.ts`, `core/proposal-view.ts` (`GLOBAL.DELETE`, `GLOBAL.NODE.DELETE`), `core/strings.ts`, `core/screens.generated.ts` (regenerated), `core/self-protection.ts` (the `PROTECTEDGLOBAL` sentence) -- add-only.
- `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md` -- the ruled strings into Fixed strings (add-only).
- `ui/browser/system-explorer-globals.browser-spec.mjs` (new) -- each step waits for the answered signal: the list shows the spec's own global; the view pages through it; an edit round-trips; a node delete asks for the typed name and removes the node; an `^OcuPilot*` row shows Delete disabled with the sentence.

**Acceptance Criteria:**

- AC1. Given a namespace holding the test's own global, when the person opens Globals and the agent calls `explorer.globals.read`, then both answer the same capped rows for the same criteria, and no row is a subscript-level mapping.
- AC2. Given that global with more nodes than one page, when the person pages through it, then every node appears once, in `$Query` order, with long values cut and flagged, and no node value or subscript reaches screen context, a tool or a log line.
- AC3. Given a plain-text node, when the person edits it and confirms, then the instance holds the new value and the read-back matches; when the node changed after the dialog opened, nothing is written.
- AC4. Given the delete keys `true`, when the person deletes a node or the agent proposes a global's delete, then each asks for the global's name typed before it runs and the target is absent after confirm; with the default baseline the agent's proposal is refused by governance.
- AC5. Given any write to an `^OcuPilot*` global, a node in OcuPilot's own database or one of the seven protected databases, or OcuPilot's code globals, when either caller makes it, then it is refused before any write with that refusal's sentence, which the client mirror pins equal.
- AC6 (DW-2607). Given a System Explorer import whose file holds a code global or a `%`-global, when the person or the agent imports it, then it is refused `PROHIBITED.PROTECTEDGLOBAL` before anything loads; a file holding only an ordinary global of the namespace is not refused by this clause.

### Review Findings

**Rework 1 directions (runner, 2026-11-18, decide):** (1) HIGH: find the protected locations without reading configuration as the caller — the destination of each global through the caller-readable namespace mapping (`%SYS.Namespace.GetGlobalDest`, or the vendor's equivalent the caller may call), the manager directory for IRISSYS (`$System.Util.ManagerDirectory()`), and OcuPilot's own database as the destination of one of OcuPilot's own globals; measure as `OcuPilotProbeDeveloper` that each write answers as the classic page would (200, or 403 for a protected global). If no caller-readable source exists and the lookup would need an escalated read, HALT `blocked` naming the read (an AD-9 escalation case is the orchestrator's ruling, not this stage's). (2) MED read-back: compare the node's `Value` (AC3 stands; no amendment). (3) MED DW-2722: answer the stale save with 409 `STATE.CONFLICT` (the client shows EXPERIENCE.md's `formStaleSave`) and the empty global with 404 `GLOBAL.NOTFOUND`, through an add-only mapping in `Api/ScreenAction.Run` for those two codes (every other problem keeps 400); no new user-facing string.

Code review 2026-11-18: four layers on the full-opus tier. Measured on `ocupilot-ci` as `OcuPilotProbeDeveloper` (`%Developer` plus code READ, without `%All` or `OcuPilotAdmin`) and as `_SYSTEM`.

- [ ] [Review][Patch] HIGH: every global write by a `%Development` holder without administrator rights answers 500 `INTERNAL` [`Prohibited.cls` `ProtectedLocation`]. The arm reads the directories of OcuPilot's database and the system databases through `AdminPort` `Database.ConfigCRUD` `LIST`, as the caller, and the developer meets `<PROTECT>` on IRISSYS. As the developer, a node save and a node kill in `USER` and in `HSCUSTOM`, and a delete of `oddDEF`, each answered 500. The same writes as `_SYSTEM` answered 200, or 403 for the protected globals. This breaks AD-10's arm ("as writable as the classic page leaves them"), and it breaks AC3 and AC4 for the screen's own pair. Fix: read the directories from a source the screen's caller can read; all three call sites now go through `ProtectedLocation`. An AD-9 privileged read would change privileges, which needs a veto. Add a developer-principal leg (`DeveloperFloorFixture`, armed). Fix-risk: med.
- [ ] [Review][Patch] MED: the node save's read-back reports `nothingSent` (measured), but a value was sent [`ExplorerGlobalNodeSave.cls`]. This breaks AC3 ("the read-back matches") and AD-58. The value travels in the port query (`COMPOSEDTYPES`), so `ReadBack.KindOf` treats the save as action-style. Fix: compare `Value`, or have the runner amend AC3. Fix-risk: med.
- [ ] [Review][Patch] MED (DW-2722): two refusals cannot carry their own code. A node that changed after the dialog opened answers 400 `TOOL.ARGUMENTS`. A global that holds nothing answers 400, not 404 `GLOBAL.NOTFOUND` [`ExplorerGlobalNodeSave.cls`:82, `ExplorerGlobalDelete.StateDiff`]. `ScreenAction.Run` answers every delta problem with 400. Fix: answer the stale save with the existing stale-save refusal, 409 `STATE.CONFLICT`, which the client renders as EXPERIENCE.md's `formStaleSave`, so no new string is needed. Fix-risk: med, since it touches the shared route.
- [x] [Review][Defer] AD-53 named audit gap. With auditing on, a save, a node kill and a whole-global delete wrote 0 `%SYS.Audit` rows, while control rows were present. Recorded as an occurrence on DW-2613.
- [x] [Review][Patch] The arm judges every write except a value edit (`PUT`) by every mapping row, including a write by an unresolved tool [`Prohibited.Global`].
- [x] [Review][Patch] One protected-directory helper, `ProtectedLocation`, replaces the copy in `Global` and `ImportedGlobals` (Rule 2/31).
- [x] [Review][Patch] AD-36 pin: after a save and a node kill, the value is in no node of the OCUPILOT or IRISAUDIT databases and in no new `messages.log` line (`GlobalWrite.TestANodesValueReachesNoStoreAndNoLog`). DW-2723 measured false.
- [x] [Review][Patch] The read-back verdicts of the screen's two deletes and of the agent's confirm are asserted (`notFound`).
- [x] [Review][Patch] A failing set and a failing node kill log no node text (`GlobalSeamPort.ArmWrites`, `GlobalRead`).
- [x] [Review][Patch] DW-2724: the list's Delete is pinned in the browser. It asks for the typed name, states `globalDeleteConsequence` and deletes the global. Each browser test now makes its own global.
- [x] [Review][Patch] Small corrections: the `oddDEF` test asserts the node is stored in IRISLIB before it acts; `GlobalRead` asserts `Resolve`'s status and adds a positive control; an import of an own-stem `.gbl` is pinned refused (`OCUPILOTCODE`); a false claim was removed from the agent-facing text of `explorer.globals.delete`; a stale `navigation.test.mjs` comment was corrected.
- [x] [Review][Defer] LOW: if the Start node field holds anything other than a canonical reference, the person is answered with `REASONPAGE`, a sentence about a page size they never set. Changing it needs a ruled string. Closed wontfix-accepted.
- Rejected:
  - `Page` re-validation (no caller skips `PageRequest`).
  - Delete on a row whose reference is cut (needs a reference over 1,000 characters, and the fix adds a server flag).
  - A subscript over 511 bytes answers 500 (a loud failure on invalid input).
  - The race between the `Was` check and the set (OcuPilot's hold orders its own writers).
  - `PRECONDITIONFIELD` on the save (no harm named).
  - The `Was` check is skipped without a fresh read: false, because `Run` answers 404 first.
  - The "Database" column shows a directory (spec-bound).
  - The `ExplorerGlobalView` id doc (cosmetic).
  - The stale port list in `CriteriaProblem` (pre-existing, and the file is contended).
  - `REASONNAME` omits dots (cosmetic, and the fix needs a ruled string).
  - An own-stem `.gbl` import is not refused: false, because the code arm refuses it first, and that is now pinned.
  - Mutation lines for sub-claims (every AC has one).
  - The dead `MAXCHARS` branch (the bound holds anyway).
  - Change-event ids carry subscripts (by design, AD-13).
  - The `Node/PUT` snippet (no draft reaches either node tool).
  - The matrix says 409 for the protected rows (fixing it means editing the spec).

## Spec Change Log

- 2026-11-18 (runner, rework 1): code review found developer writes failing 500 (`Prohibited` read configuration as the caller), the node save's read-back reporting `nothingSent`, and two refusals answering 400; re-opened with the directions under Review Findings.

- 2026-11-18 (runner, decide): Batches 1 and 2 land in one finalize commit; the pre-commit `screen-mirror.mjs --check` refuses a new descriptor until its client exists (Story 21.14).

## Review Triage Log

### 2026-11-17 — Review pass

- verdicts: 24 findings — high 0, medium 5, low 17, false 1, maybe-false 1
- findings:
  - `[medium]` `[patch]` reload with more than one page loaded is never exercised (store spec asserts `>= 3` sends over one page) — store spec now loads 101 rows, asserts the two requests and the rows; mutation (one page) observed red.
  - `[medium]` `[patch]` `GLOBAL.DELETE` and `GLOBAL.NODE.DELETE` sentences pinned by source text only — runtime `consequenceSentence` assertions added to `proposal-view.test.mjs`; the list dialog residual is the deferred item below.
  - `[medium]` `[patch]` hostile-text cursor leg refused by the other-global check, not the parse — the cursor now names the page's own global in `TestEveryHostileTextIsRefusedBeforeAnythingIsRead`.
  - `[low]` `[reject]` `TestTheToolsDeclareTheirWritePath` list-pairs `'>` can pass on equal sets — the `ClassicPageGate` roster pins the classic pages; not worth a guard.
  - `[low]` `[reject]` `ToolEmit` expected pairs use the production helpers — sibling tools' pin is the same oracle; a wrong formula is caught by `GlobalWrite` and `ClassicPageGate`.
  - `[low]` `[reject]` the edit's read-back is asserted present, not equal — line 168 asserts the instance holds the new value; the read-back is the framework's own step.
  - `[low]` `[reject]` the import failed-read leg asserts a not-OK status alone — the leg pins that a failed read refuses; the code is the arm's generic read error.
  - `[low]` `[reject]` `TestTheScreensDeclareTheirShape` passes for any unresolved read tool — the registry roster tests pin the registered tools.
  - `[low]` `[patch]` the store reload `toBeGreaterThanOrEqual(3)` — same root as the first row, closed there.
  - `[low]` `[reject]` browser spec test 2 relies on running before test 4 — one file is one ordered flow on its own global; each test waits for its answer.
  - `[low]` `[reject]` browser spec test 1 finds the global in the capped default list — the namespace holds far fewer than the cap's rows; the test would fail loud.
  - `[low]` `[reject]` `TestTheInstancesProtectedGlobalIsRefusedOnBothCallers` drives real writes at `^oddDEF` in `USER` — that global is stored in IRISLIB, read-only, so a regressed arm meets the vendor `<PROTECT>`; reopen if a different database holds it.
  - `[low]` `[patch]` `ExplorerTransfer`'s percent-global test has no teardown — `OnAfterOneTest` now kills both `^ZZOcuGlb<job>` and `^%ZZOcuGlb<job>`.
  - `[low]` `[reject]` client pins carry their mutation in code comments — the spec's `## Verification` carries a line for every AC.
  - `[medium]` `[patch]` node GET, PUT and DELETE log the vendor exception's text, which can name a subscript — the node calls now log the exception's name alone; `GlobalSeamPort` fails a node read and `GlobalRead` asserts no node text; mutation observed red.
  - `[low]` `[reject]` the Code Map and Tasks name the node route `.../nodes`, the descriptor ships `.../document` — the fix edits this spec; the code follows the repository's `<list route>/document` convention.
  - `[low]` `[reject]` `ImportedGlobals` is tested for a class import target only — the `.gbl` clause sits in the branch class and routine imports share.
  - `[medium]` `[defer]` a node changed after the dialog opened answers 400 `TOOL.ARGUMENTS` with an unruled sentence, where the matrix says 409 target-changed — nothing is written (AC3 holds); the sentence and status need a ruling (deferred item 1).
  - `[false]` `[reject]` AC4 "given the delete keys true" read as gating the person's own deletes — AD-53's record makes person-only writes ask no key; `GlobalWrite` pins that.
  - `[low]` `[reject]` the descriptor route differs from the spec's `.../nodes` — same as the route row above; the HTTP route is `/explorer/globals/nodes`.
  - `[low]` `[reject]` AC1 screen and agent parity is not driven in the browser — `GlobalRead` compares the port, the screen read path and the agent read.
  - `[maybe-false]` `[defer]` a saved node value may reach a change event or audit payload — the tool carries the person's new value and AD-36 forbids node values in an audit payload; inspecting the event after a save would settle it (deferred item 2).
  - `[low]` `[defer]` the list's whole-global Delete dialog (typed name) has no component or browser spec for an ordinary global (deferred item 3).
  - `[low]` `[reject]` no end-to-end write to a real `^OcuPilot*` global — the arm's refusal is before any write and is pinned at the arm for both callers; writing one is what the spec forbids.

## Design Notes

**Governing ADs:** AD-4, AD-5, AD-6, AD-8, AD-10, AD-13, AD-14, AD-15, AD-16, AD-21, AD-22, AD-23, AD-29, AD-34, AD-36, AD-39, AD-44, AD-51, AD-52, AD-53, AD-58, AD-59. No new AD-51 or AD-21 entry: edit is a merge write of `{Value}` over a fresh read (AD-4); the deletes send no body (AD-51's base shape, subject `Defined`); the namespace is the route's scope (AD-21).

**Spine records, final (owner U-59; the runner pastes them at the spec gate):**

- **AD-10 arm.** "OcuPilot's own and the instance's protected globals (Story 21.5). Refused from either caller, key on or off, read at the write; a read that fails refuses. (1) A write to a global whose name begins with one of OcuPilot's name stems, in any case: `PROHIBITED.PROTECTEDGLOBAL`. (2) A value edit of a node that resolves to OcuPilot's own database or one of `SYSTEMDATABASES`, or a kill of a node or a whole global any of whose mapping rows in the namespace, top or subscript-level, resolves to one: `PROHIBITED.PROTECTEDGLOBAL`. (3) A write to one of `CODEGLOBALS` that resolves to the install namespace's routines database and is the whole global or reaches a first subscript beginning with an own stem (any node of a `NESTEDCODEGLOBALS` member counts as reaching one): `PROHIBITED.OCUPILOTCODE`. Import clause: an import (Story 19.13) whose reviewed documents include a global (`.gbl`, any case) is refused `PROHIBITED.PROTECTEDGLOBAL` when that global is one of `CODEGLOBALS`, or any of its mapping rows in the target namespace resolves to OcuPilot's own database or one of `SYSTEMDATABASES`; the file's subscripts are not read. Other globals stay as writable as the classic page leaves them."
- **AD-36 record.** "A global's node page (Story 21.5) is a screen-only payload, as a data browser page is: a node's subscripts and values carry no classification. It holds 50 to 500 rows, cuts each value and subscript at 1,000 characters, holds 1,000,000 characters in all, and pages by an explicit reference cursor. The global list is an ordinary declared read."
- **AD-53 record.** "`explorer.globalnodes.save` and `explorer.globalnodes.delete` (Story 21.5) are unadvertised person-only writes, Story 19.8's case: their card and fresh read carry node values, which never reach the model (AD-36). Their keys ship `false`; a person's own write asks no governance key. The agent proposes only a whole global's delete, by name."
- **For the spec gate with the three:** AD-29's Binds gains `GlobalPort` (as Story 21.2 did for `BackupPort`).

**Measured read-only on slot A `ocupilot` (2026-11-15):**

- `$QLength`/`$QSubscript` evaluate nothing: `^G($$x())`, `^G(1)_x`, `^G(@x)`, `^G(x)`, `^G("a)`, `^G(01)`, `^G(1E2)` raise `<FUNCTION>`; `^|"%SYS"|G` answers length 0 with `$QSubscript(,0)` `^G` (so the environment check and the rebuild-equality check are both needed); `G(1)` parses as a local (so `^` is required). `$Name` canonicalizes `"1"` to `1`, keeps `"67000,123"` as one string subscript, doubles quotes, and leaves control characters raw.
- `GetGlobalDest` directories equal `Config.Databases` `Directory` exactly (`OCUPILOT` `/durable/iris/mgr/ocupilot/`, `IRISSYS` `/durable/iris/mgr/`, `IRISLIB` `/usr/irissys/mgr/irislib/`). In `HSCUSTOM`: `^OcuPilotTurnSignal` -> ocupilot; `^%ZZNever` -> IRISSYS; `^%qZZ` -> IRISLIB; `^oddDEF("OcuPilot.Api.Router")`, `^rOBJ`, `^ROUTINE(...)` -> HSCUSTOM (the install namespace's routines database).
- `NameSpaceList` with an exact name answers the global's subscript-level rows too (`oddDEF("%"):("%SYS.")` -> IRISLIB). In `USER`, 14 of the 16 `CODEGLOBALS` have rows in IRISLIB or IRISSYS; `oddDEP` and `rINDEXEXT` have none, which is why the import clause also refuses `CODEGLOBALS` by name.
- `%Studio.Global.format`: `$ListBuild` and a tab-bearing string answer 2; a 2,000-character string, plain text, a number and `""` answer 1.
- A 500-row `$Query` walk with `format` over `^oddDEF` took 31.8 ms and 35,681 characters.

**Decided in-stage:**

- No `ExecuteMCPv2.REST.Global` body is harvested (AD-23 checked): `ListGlobals` walks `^$GLOBAL` unbounded; `BuildGlobalRef` splits subscripts on commas, so `"67000,123"` would address a numeric pair.
- A kill checks every mapping row of the global, not only the node's own destination, because a kill reaches subscript-mapped descendants (fails closed).
- Only plain text of 1,000 characters or fewer is editable, keeping the reviewed diff whole (AD-6). A kill removes the node and everything below it; the typed name is the global's name.
- Globals takes position 15, appended; a future System Explorer screen from Epic 24 resolves its position at integration (a union).
- `GlobalPort`, the Globals list and the `global` entity type are shaped for Story 21.17: it adds its export row action, and its size and digest reads as new types on `Globals`; this story builds neither.
- Tests are not armed: each writes only its own `^ZZOcuGlb<pid>` (or `^%ZZOcuGlb<pid>` only through a refused import) and kills it.

**Escalated for the spec gate (strings; reusing "Name", "Database", "Delete", "Edit", "Value", "Collation"):** titles "Globals", "Global nodes"; columns "Journal", "Node", "Below"; "Start node", "More", "Edit node"; empty states "This namespace holds no global that matches." and "This global holds no nodes."; agent empty phrase "list the globals"; prompts "Which globals does this namespace hold?", "Which database stores this global?", "Delete a global"; consequences `GLOBAL.DELETE` "Deleting removes the global and all of its data. This cannot be undone." and `GLOBAL.NODE.DELETE` "Deleting removes this node and every node below it. This cannot be undone."; refusals `GLOBAL.NOTFOUND` "There is no global with that name in this namespace.", `GLOBAL.NODE.NOTFOUND` "This node no longer holds a value or nodes below it.", `GLOBAL.NODE.NOTEDITABLE` "Only a value of plain text, 1,000 characters at most, can be edited here.", `GLOBAL.VALUE.SHAPE` "Enter plain text of 1,000 characters at most.", `PROHIBITED.PROTECTEDGLOBAL` "This global holds OcuPilot's own data or the instance's protected system data, so it cannot be changed or deleted from OcuPilot."; cut flag "Value shortened".

**Extend, don't copy (Rules 2/31):** `GlobalNodes` follows `SqlData`'s route order and `GlobalPort.Page` `SqlPort.BrowseRun`'s bounds; the tools subclass `Screen/Tool/Write` as `ExplorerSqlDataSave` and `ExplorerDelete` do; the arm reuses `OwnNameStems`, `OwnDatabaseDirectories`, `SYSTEMDATABASES`, `CODEGLOBALS`, `NESTEDCODEGLOBALS`; the import clause extends the existing import branch after `Code`. The client page is a sibling of `data-browser.page.ts`, not a subclass: a grid of nodes is not a grid of SQL rows.

**Integration ACs.** `GlobalPort` is consumed in this story by its two screens, its route, its three tools and `Prohibited` (AC1-AC6 observe it through HTTP, the agent and the browser).

- **Consumes:** `Screen/Tool/Write`, `Kernel/Proposal/*`, `Screen.Gate`, Story 19.13's import branch.
- **Consumed-by:** Story 21.17 (Globals list row action, `global` entity type, `GlobalPort` presence and `Locations`, the import clause); Story 21.18 (node walk, edit, the arm).

**Ledger inbox:** DW-2607 addressed by the `Prohibited` import clause, the `GlobalWrite` arm cases, the `ExplorerTransfer` test and AC6.

**Contended paths:** Epic 24 (slot B) has no committed change beyond feature in any file named here (`origin/OCU-1-epic24`, checked 2026-11-15); its worktree holds uncommitted edits to `EXPERIENCE.md`, `Baseline.cls`, `Prohibited.cls`, `Screen/Read.cls`, `strings.ts`, `screen-action-handler.ts`, `proposal-view.ts`, `screens.generated.ts`, `ClassicPageGate`, `Descriptor`, `MappingDescriptor`, `ReadTool`, `SurfaceCoverage`, `ToolRoundTrip`, `ToolWrite`. Every edit there is add-only. No Epic 22 branch or worktree exists.

**Task 0, measured on `ocupilot-ci` (2026-11-18):** (d) the instance registers 80 audit events and none names a global's `Set` or `Kill` (auditing was off, so no event was observed being written; (inference) a global write records none). (e) a write of `^%qZZOcuProbe` (IRISLIB) with no roles is `<PROTECT>`, code 202, status text `ERROR #5002: ObjectScript error: <PROTECT> ^%qZZOcuProbe,/usr/irissys/mgr/irislib/`; as `_SYSTEM` it is `<PROTECT>` too, since IRISLIB is read-only. (h) an `$System.OBJ.Export` of `ZZOcuGlb<pid>.GBL` carries the name as `<Sub>^ZZOcuGlb<pid></Sub>`; rewritten to `^%ZZOcuGlb<pid>` it lists through `xml/list` as one global document and the screen's local import is refused `PROHIBITED.PROTECTEDGLOBAL` (`ExplorerTransfer`). A subscript holds 511 characters with the global's name, so a reference over 1,000 characters needs quotation marks in its subscript, which `$Name` doubles.

**Decided in-stage (implement):** `Globals` `GET` and `Node` `GET` also answer `Namespace`, so a confirm writes where the proposal read (as `DocDbPort`). The person's stale-node guard is the screen value `Was`, compared with the fresh read in `ExplorerGlobalNodeSave.ScreenActionDelta`: a node that changed since the dialog opened answers 400 `TOOL.ARGUMENTS` with a plain problem sentence, not the 409 the I/O table names, because the screen action route takes no fingerprint and no ruled sentence exists for it (open item). The save's fingerprint subject keeps `Value`, but the merge replaces `Value` with the new value, so dropping it changes no digest; AC3's mutation targets `Was`. The node page's descriptor route is `system-explorer/globals/document`, the list's paired document screen, because a `list (server criteria)` list declares no `rowTarget` and the name cell opens a paired `document` screen; its HTTP route stays `/explorer/globals/nodes`. The list's title reuses `processColumnGlobals` and the Edit button `agentPanelSecretWarningEdit` (`strings.test.mjs` refuses a repeated value). `Node/PUT` is a `COMPOSEDTYPES` member of `GlobalPort`, the new value travelling in its query. `GlobalPort` defines `Snippet` and `SnippetForm` for its three writes (the draft registry requires it). The classic Global view and Global edit pages, `/csp/sys/exp` pages like Open Table, are added to `DeveloperFloor.INTERNALCHECKS` (the application's resource, `%Development`, was read on the instance; that the two pages are served by it is (inference)). The new tools and descriptors take positions and rosters 15 (free; Epic 24 holds 16-19).

**Runner ruling at the spec gate (2026-11-15):** the three AD records are written into the spine (owner answer U-59); the AD-29 Binds addition stays a proposal beside DW-2559; the escalated strings and the stricter data posture are kept (veto U-60).

## Verification

**Shared surfaces:** the System Explorer rosters, positions and count (`Navigation`, `ui/tools/navigation.test.mjs`, `screen-mirror.test.mjs`, the System Explorer browser specs that count the side bar); `Descriptor`; `TeardownGuard`; the read-source count (+`global`); `ReadTool`'s size (+1); `ToolWrite`'s counts (+3); `Prohibited`'s covered types (+`global`, `global-node`) and code list; `ClassicPageGate`; `MappingDescriptor`; `SurfaceCoverage`; `ToolRoundTrip`; `ToolDispatch`; `ToolEmit`; `PortGate`; `EndpointCoverage`; `GovernanceBaseline` (+3 keys); entity types; the 19.13 import tests (`ExplorerTransfer`); `ui/tools/strings.test.mjs` with the EXPERIENCE.md literal cap 4200 (if crossed, raise it by 400 under the file's protocol and report it); `proposal-view.test.mjs`. The implement stage greps `ui/browser`, `ui/tools`, the `ui/src` specs and `src/OcuPilot/Test` for each; every test it changes joins `(loop)`.

*Every test added or changed passes on a fresh environment, in either order.* Each test makes its own marker-named global, asserts only on its own rows, and kills it.

**Commands** (one per foreground call, `timeout: 600000`, against `ocupilot-ci` only, never two test calls in one message):

- `(loop)` `sh /private/tmp/claude-501/-Users-jbrandt-git-OcuPilot/b708a79b-b765-42ec-adea-dbc87acf6251/scratchpad/e21u/lead/reload.sh /Users/jbrandt/git/OcuPilot/.worktrees/epic-21 ocupilot-ci` -- expected `LOADERRORS=0`.
- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.GlobalRead`, then the same, one class per call, for `GlobalWrite`, `ExplorerTransfer`, `PortGate`, `SurfaceCoverage`, `EndpointCoverage`, `GovernanceBaseline`, `Prohibited`, `ReadTool`, `ToolEmit`, `ToolDispatch`, `ToolRoundTrip`, `ToolWrite`, `Descriptor`, `Navigation`, `ClassicPageGate`, `MappingDescriptor`, `TeardownGuard` -- expected green.
- `(loop)` `uv run scripts/check-objectscript.py`; `uv run scripts/test_check_objectscript.py`; `bash scripts/lint-docs.sh` -- expected clean.
- `(loop)` `cd ui && node --test tools/strings.test.mjs tools/screen-mirror.test.mjs tools/navigation.test.mjs tools/proposal-view.test.mjs` plus every `ui/tools` test the sweep changes -- expected green.
- `(loop)` `cd ui && npm run build && npm run test:components`, then `docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`, then `cd ui && OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci node --test --test-concurrency=1 browser/system-explorer-globals.browser-spec.mjs browser/system-explorer.browser-spec.mjs` -- expected green.
- `(once)` `cd ui && npm run test:tools` -- expected green.
- `(once)`, runner-owned: the full ObjectScript sweep one class per call, `bash scripts/smoke.sh --container ocupilot-ci --user _SYSTEM --password SYS`, Rule 30's fresh check. The full browser suite is left to CI.

**Mutations (Rule 19)** -- each applied on `ocupilot-ci`, observed red, reverted byte-identical (checksum) and reloaded:

- mutation: AC1 drop the `(` filter in `GlobalPort.VendorList` -> `GlobalRead.TestTheListAndTheAgentsReadAnswerTheSameRowsWithNoMappingRow` red.
- mutation: AC2 make the cursor inclusive in `GlobalPort.VendorWalk` -> `GlobalRead.TestAPageWalksTheGlobalOnceInOrderWithLongValuesCut` and `TestAPageStartsWhereItIsToldAndLogsNoValue` red.
- mutation: AC3 drop the `Was` comparison in `ExplorerGlobalNodeSave.ScreenActionDelta` (the spec's "remove `Value` from the fingerprint subject" is unobservable, see Design Notes) -> `GlobalWrite.TestAnEditRoundTripsAndANodeChangedSinceIsNotWritten` red.
- mutation: AC4 set `explorer.globals.delete` `true` in `Baseline` -> `GlobalWrite.TestAGlobalDeleteWorksOnTheScreenAndForTheAgentOnceItsKeyIsOn` and `TestTheToolsDeclareTheirWritePath` red.
- mutation: AC5 drop the own-stem check from `Prohibited.Global` -> `GlobalWrite.TestTheArmRefusesOwnAndProtectedGlobalsBeforeAnyWrite` red (the client mirror's pin is `ui/tools/self-protection.test.mjs`).
- mutation: AC6 drop the `.gbl` clause from the import branch of `Prohibited.Prohibits` -> `GlobalWrite.TestAnImportIsJudgedByTheGlobalsItNames` and `ExplorerTransfer.TestAnImportOfAPercentGlobalIsRefusedAndLoadsNothing` red.
- mutation: AC2 (node calls log no node text) drop the quiet flag of `GlobalPort.NodeState`'s `Mapped` call -> `GlobalRead.TestAPageStartsWhereItIsToldAndLogsNoValue` red (observed).
- mutation: AC3 (a reload keeps the pages shown) read one page in `GlobalViewStore.reload` -> `global-view.store.spec.ts` "reads again as many pages as are shown" red (observed).
- mutation: AC2 (AD-36, a saved value is never stored or logged) log the new value in `ExplorerGlobalNodeSave.PortQuery` -> `GlobalWrite.TestANodesValueReachesNoStoreAndNoLog` red (observed, code review).
- mutation: AC4 (read-back) `ExplorerGlobalDelete.ReadBackGone` answers 0 -> `GlobalWrite.TestAGlobalDeleteWorksOnTheScreenAndForTheAgentOnceItsKeyIsOn` red on the screen and confirm verdicts (observed, code review).
- mutation: AC2 (a failing set logs no node text) quiet flag 0 on `GlobalPort.NodeSet`'s set -> `GlobalRead.TestAPageStartsWhereItIsToldAndLogsNoValue` red (observed, code review).
- mutation: AC4 (the list's typed-name Delete, DW-2724) map `ExplorerGlobalList`'s delete to `globalNodeDeleteConsequence` in `screen-action-handler.ts`, rebuild and redeploy -> `system-explorer-globals.browser-spec.mjs` list-Delete test red (observed, code review).

## Auto Run Result

Status: done
Blocking condition: none

Review pass: 24 findings (medium 5, low 17, false 1, maybe-false 1); patched 4 mediums and 2 lows (a multi-page reload spec, runtime consequence-sentence pins, the hostile cursor leg, node calls logging the exception name alone, an `ExplorerTransfer` teardown), deferred 3 (the stale-node sentence and status, whether a saved value reaches an event payload (unverified), the list's delete dialog spec), rejected 16 with reasons in the triage log. Re-verified after the patches on `ocupilot-ci`: `GlobalRead`, `GlobalWrite` and `ExplorerTransfer` green one at a time, `npm run test:components` 3,564 green, `proposal-view` and `global` tool tests green; two mutations observed red and reverted byte-identical. Follow-up review recommended: the patched code is not covered by a re-run of the browser specs or the other ObjectScript classes.

Implement pass: Task 0 measured; Batch 1 (`GlobalPort`, `GlobalError`, `GlobalNodes` route, the arm and import clause in `Prohibited`, three tools, two descriptors, registrations, `GlobalRead` and `GlobalWrite`, one `ExplorerTransfer` test, shared-surface rosters) and Batch 2 (node page and store with specs, strings, EXPERIENCE.md row, consequences, the `protected-global` rule, regenerated mirror, `global.test.mjs`, browser spec). Verified on `ocupilot-ci`: every `(loop)` class green one at a time, `check-objectscript` clean, `lint-docs` clean, `npm run build` (initial bundle 2.12 MB, under the 2,500 kB warning), `npm run test:components` 3,564 green, both browser specs green, six mutations red and reverted. Open: the stale-node refusal's sentence (Design Notes).
