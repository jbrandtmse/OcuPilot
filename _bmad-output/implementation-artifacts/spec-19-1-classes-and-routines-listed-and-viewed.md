---
title: 'Story 19.1: Classes and routines, listed and viewed'
type: 'feature'
created: '2026-10-01'
status: 'done'
baseline_revision: '08ec761ccfc52af24593c821594c6df9654d9f79'
baseline_commit: '08ec761ccfc52af24593c821594c6df9654d9f79'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-19-context.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** OcuPilot cannot show a namespace's code. Stage 3 needs a port to the Atelier API, a System Explorer area, and the first two lists and their document views, and every later Epic 19 story builds on them.

**Approach:** Add `Port/AtelierPort`. It calls `%Api.Atelier.v8`'s own route methods in the caller's process, as the signed-in user, behind its own gate, the way `AdminPort` and `MgmntPort` call their vendor classes. Add a ninth rail area, System Explorer, listing Classes and Routines. Each is a declared read whose classic filters are server criteria under the max-rows cap. Each list's name cell opens an unlisted document viewer offering five views: Source, XML, Intermediate code, Structure and Documentation. Everything in this story is read-only.

## Boundaries & Constraints

**Always:**

- Every Atelier call goes through `Port/AtelierPort`, the only class that names an `%Api.Atelier.*` class. The browser never calls `/api/atelier`. Nothing sends a Basic header, and no vendor web application is changed.
- **The port's gate runs in the caller's process before any vendor call (AD-29).**
  - It checks `%Development:USE`, READ on the target namespace's routines-database resource (resolved at call time), and whatever else Task 0 measures.
  - A refusal names the failed pair.
  - A denial never reads as an empty list.
- **The namespace is switched by explicit save and restore (AD-16).**
  - The restore is the first line of every `Catch`.
  - No `OcuPilot.*` class is called while switched.
- **Reads are bounded and shared (AD-36).**
  - Every read is cut at the max-rows cap and reports `truncated`.
  - A screen and its read tool share one declared read.
  - Every list filter is applied on the instance to the parsed rows, before the cap.
- **Document text stays on the screen.** Source, XML and `.int` text is AD-36's screen-only `document`: it is never part of a tool's view and never enters screen context.
  - The agent reads the structure rows: kind, name, type, flags and description.
  - Those rows are bounded by AD-24 and pass through AD-60's sanitizer.
- **Vendor errors are normalized at the port (AD-39).**
  - Faults use the existing `PORT.*` codes with port-owned reason parameters, as `MgmntPort` does.
  - The raw vendor text is logged.
  - A read answered 404 is not logged (AD-2).
- **The literal `%Atelier` never appears under `src/` or `ui/`.** The checker's rule 1 forbids it, comments included.
- **Edits to files Epic 18 is changing are add-only**, apart from the edits listed under Design Notes › Footprint. Before editing any existing file, check Epic 18's diff:
  - `git -C /Users/jbrandt/git/OcuPilot/.worktrees/epic-18 diff --stat=200 origin/feature/OCU-1_ocupilot-mvp...HEAD`
  - `git -C /Users/jbrandt/git/OcuPilot/.worktrees/epic-18 status -s`

**Never:**

- No write of any kind. That means no write tool, no proposal, no row or primary action, and no governance key, so `Baseline.cls` is unchanged. No compile, save, delete or import (Stories 19.2 and 19.3).
- Never call `POST modified`. It writes `^ISC.Src.Jrn` in every mapped database.
- Never send `docnames`' `filter` parameter. The vendor concatenates it into SQL (AD-21).
- No new third-party library, no edit to `Api/Error.cls`, and no new error code.
- No Documatic embed or link-out (that is Story 19.9). No "Look in: Database" mode, which would make an implied namespace (`^^<directory>`) the data scope.
- Never insert a line into EXPERIENCE.md above line 586, nor into DESIGN.md at all. Code cites both files by line number (1,830 references in `strings.ts`).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Classes, defaults | `GET /screens/explorer.classes/read?ns=HSCUSTOM` as `_SYSTEM`, no criteria | 200. Rows are `{Name, Modified, Database, Generated}`, excluding `%` names and generated classes and including mapped ones, at most `maxRows` (default 1000), with `truncated` true when more matched. `criteria` reports `pattern` "*", `system` "no", `generated` "no", `mapped` "yes" | none |
| Name pattern | `pattern=OcuPilot.Kernel.Entity*` | Exactly `OcuPilot.Kernel.EntityId.cls`, `.EntityRef.cls` and `.EntityType.cls`. Matching is case-sensitive, `*` is the only wildcard, `a,b` is a union and a leading `'` excludes, as on the classic page (observed: lower-case `ocupilot.*` matches nothing there) | none |
| Include and date filters | `system=yes`, `generated=yes`, `mapped=no`, `from`/`to` | `%` names included. Generated documents included, sent to the vendor as `generated=1`. Rows whose `Database` is not the namespace's routines database are dropped. Rows whose `Modified` falls outside `[from, to]` are dropped. All of this happens before the cap | none |
| Routines, defaults | `explorer.routines` read, no criteria | `pattern` "*.mac", `generated` "yes", `mapped` "yes", the classic defaults. A pattern piece with no extension matches every routine type: `mac`, `int`, `inc`, `bas`, `mvi` and `mvb` | none |
| Bad criterion | `system=maybe`; `from=2026-09-30`; `pattern` containing `;`, a quote or a space | 400 `READ.CRITERION` from the read's own check for kind and form. 400 `PORT.VALIDATION` from the port's pattern shape. No vendor call | the reason names the criterion |
| Class viewer | `explorer.class` read, `name=OcuPilot.Kernel.EntityId.cls`, `form=udl` | 200. Rows: one `class` row (`Type` = superclasses, plus `Description`, `Modified`, `Database` and `Generates`), then one row per parameter, property and method in index order. `document` is `{name, form, available, content[], modified, database, generates[]}` | none |
| Other forms | `form=xml`; `form=int` | `content` holds the XML export, or the first `.int` named in the index's `others` (`OcuPilot.Kernel.EntityId.1.int`). A class with no `.int` (`%Library.String`) answers `available` false and empty `content` | the screen states it; not a fault |
| Routine viewer | `explorer.routine`, `name=HS.HC.Info.mac`, `form=int` | One `routine` row (`Type` "mac", `Generates` "HS.HC.Info.int"). `content` is the text of `HS.HC.Info.int`. `form=xml` gives the routine's XML (observed 200) | none |
| Missing document | `name=No.Such.Class.cls` | 404 `PORT.NOTFOUND`, nothing logged | the viewer shows its empty state |
| Malformed name | `name` empty, `../x.cls`, `A.cls;B`, or a routine name on `explorer.class` | 400 `PORT.VALIDATION` before any vendor call | named reason |
| Denied | the caller lacks a pair in the port's set | 403 `AUTH.NOPRIVILEGE` naming the failed pair. No vendor call | none |
| Old instance | the version seam reports a highest Atelier version below the endpoint's minimum | 501 `PORT.NOTIMPLEMENTED` with a reason naming both versions. No vendor call | none |
| Oversize answer | the vendor answer exceeds the capture ceiling | 503 `PORT.UNAVAILABLE` with the port's reason. The capture is closed and `$NAMESPACE` restored | logged |
| Tool view (Rule 1) | `explorer.class.read` dispatched in a turn | Rows only, each field cut by AD-24 and sanitized. No `document` key. An empty call is refused `PORT.VALIDATION` | none |
| Screen (Rule 1) | Classes opened in the browser on HSCUSTOM | Rows read through `AtelierPort` render in the shared table with the footer cap. The name cell opens `system-explorer/classes/document/<id>` | none |

</intent-contract>

## Code Map

### Server: precedents to mirror

- `src/OcuPilot/Port/MgmntPort.cls` is the template for `AtelierPort`:
  - `PAIRS` :33, the gate in `Invoke` :158-173 (`GateClass().EvaluateRequired`), the 501 for an unknown endpoint, `NAMESPACEPATTERN` :57;
  - `Call` :481-524: `New %request,%response,%session`, fresh stubs, `$$BeginCapture^%SYS.Capture`/`EndCapture`, status read from the return value and `+%response.Status`;
  - `Outcome` :533-558, `REASON*` parameters :80-105, the `GateClass`/`ImplClass` seams, `LogFault` → `Kernel.Fault.LogRaw`, and the `Snippet`/`SnippetForm` stubs (AD-59).
- `src/OcuPilot/Port/AdminPort.cls` is reference only:
  - `RunSequence` :2455-2503, capture :2588-2597, `<PROTECT>`→403 :2593-2595;
  - `HighestDispatchVersion`, the precedent for reading the vendor's URL map for its highest version.
- `src/OcuPilot/Port/LogSourcePort.cls`: `PairsFor`/`DatabaseReadSpec` :480-510 is the precedent for a per-namespace READ pair resolved before the switch.
- `src/OcuPilot/Kernel/Shell/Namespaces.cls` :75: `NamespaceInfo` → `%SYS.Namespace.GetAllNSInfo`. `RoutineDB.Resource` is observed as `%DB_HSCUSTOM` for HSCUSTOM.
- `src/OcuPilot/Kernel/Fault.cls`: `Build` :156, `Outcome` :120, `LogRaw` :197, and the `PORT.*` codes :167-197. Use `UNAVAILABLE`, `NOTIMPLEMENTED`, `VALIDATION`, `NOTFOUND` and `ACCESSDENIED`.

### Server: files this story edits

- `src/OcuPilot/Screen/Read.cls`:
  - source parameters :145-230, which gain `SOURCEATELIER = "atelier"` and an `AtelierPortClass()` seam;
  - the mgmnt branch :400-414, which is the shape to mirror;
  - `document` set at :565;
  - `SeedCriteria` :885-975, where the new criterion `default` is applied;
  - `DEFAULTMAXROWS` :90.
- `src/OcuPilot/Screen/Registry.cls`:
  - the allowed source ports :1070-1072, whose sentence `AdminPairCorpus` pins;
  - the criteria ports :1464-1467, whose sentence `CriteriaCorpus` pins;
  - the allowed criterion keys :1523, which gain `default`;
  - `READTOOLIDENTIFIERPATTERN` :990 and `PROMPTGROUPKEYS` :2692. Use `webAppPromptGroupCode`, whose label is "Code".
- `src/OcuPilot/Screen/Area.cls` :66-77 holds the eight areas. `src/OcuPilot/Screen/Archetype.cls` :59-77 holds the sixteen archetypes.
- `src/OcuPilot/Kernel/EntityType.cls` :57: `TYPES`, a comma list.
- `src/OcuPilot/Screen/Descriptor/RestApiList.cls` and `OpenApiViewer.cls` are the declaration templates. The viewer's `name` criterion is filled from the route id, as `application` is there.
- `src/OcuPilot/Screen/Tool/Read.cls`:
  - `View` :187-252 never copies `document`;
  - `InputSchema` :110-170 adds one property per criterion.

  `Screen/Tool/Registry.cls` :160-171 registers `<toolIdentifier>.read` on its own, so the tool registry needs no edit.
- `src/OcuPilot/Api/Router.cls` :132: `GET /screens/:screen/read`, the generic route. No new route is needed. Its namespace gate is at :1360-1382.
- `src/OcuPilot/Install/Smoke.cls`: `CheckAreaLists` and its tool parameters (AD-45).
- `scripts/check-objectscript.py`:
  - :223-234 `FORBIDDEN_LITERALS` contains `%Atelier`;
  - :916 `CAPTURE_ALLOWED` names AdminPort and MgmntPort only.

### Vendor, read-only (observed unless marked)

- `irissys/%Api/Atelier.cls`:
  - :55-62 is the URL map. Its highest `Forward` is `%Api.Atelier.v8`.
  - :143 `AccessCheck`.
  - The web application is `/api/atelier`, resource `%Development`, namespace `%SYS`.
- `irissys/%Api/Atelier/v1.cls`:
  - `GetDocNames` :1675-1913. Its parameters are `generated` and `filter`. `filter` is spliced into SQL at `%Library/RoutineMgr.cls` :1282. An explicit `""` passed as `pType` answers 400, so trailing arguments are omitted.
  - `GetNamespace` :2419: its `db[]` row with `default` true is `GetRoutineDest`, the namespace's routines database.
  - `CreateSourceControlClass` :2304.
- `irissys/%Api/Atelier/v4.cls`:
  - `GetDoc` :189-287 takes the `format` values `udl` (default), `xml` and `udl-multiline`. It answers a soft error with 200 and `result.status`.
  - `Index` :379-523 refuses any `%request.ContentType` other than `application/json` with 415 (:401). `ContentTypeSet` is private (`irislib/%CSP/Request.cls` :49).
- **Observed sizes on HSCUSTOM:**
  - `docnames/CLS` returns 13,806 rows, 1.83 MB, in 0.5 s.
  - `CLS` with `generated=1` returns 1.95 MB.
  - `RTN` returns 394 rows; with `generated=1` it returns 1.35 MB.
  - The capture ceiling is about 3.64 million characters, one string node (`irislib/%SYS/Capture.int`).

### Client

- `ui/src/app/shell/screen-outlet.ts`: `ARCHETYPE_PAGES` :95-106 and `DESCRIPTOR_PAGES` :124. `list (server criteria)` defaults to `AuditPage`, so both lists need `DESCRIPTOR_PAGES` entries. `TaskHistoryList`'s entry is the precedent.
- `ui/src/app/core/navigation.ts` :250-270: `documentScreenFor` pairs a list with `<list route>/document`.
- `ui/src/app/shell/data-table.ts`: name-cell link order :632-680, Max rows and the cap notice :475-483 and :1053-1057.
- `ui/src/app/areas/web-applications/openapi-viewer.page.ts` and `.store.ts`: document text in `<pre tabindex=0>` as text (AD-11), on the code surface.
- `ui/src/app/areas/tasks/history.page.ts` and `.store.ts`: a criteria form above the shared table.
- `ui/src/app/areas/home/home.page.ts` :202-209: "a ninth area would take a tile without this file changing".
- `ui/src/app/shell/rail-icons.ts`: `AREA_ICONS`, holding a 20px rail drawing and a 24px tile drawing per area key.
- `ui/src/app/core/strings.ts`: every value is published in EXPERIENCE.md's Fixed strings. Exactly one reference sits below line 585, at `:626`.
- `ui/tools/screen-mirror.mjs`: source ports :935-944 and :1185-1190, the criteria ports :1671. It regenerates `ui/src/app/core/screens.generated.ts`.

### Tests and tools

- `src/OcuPilot/Test/MgmntPort.cls`, `MgmntPortWire.cls`, `MgmntPortDenial.cls` and `MgmntDenialProbe.cls` are the test precedents for a non-admin port.
- `ui/browser/rest-apis.browser-spec.mjs` is the browser precedent. `web-sessions.browser-spec.mjs` :121-150 holds the `structural()` helper.
- `src/OcuPilot/Test/InjectionChannels.cls` :227 `TestEntityComment` is the precedent for a seeded channel (AD-11 rule 5).

## Tasks & Acceptance

**Execution:**

- **Task 0, measure first, on `ocupilot-ci` only.** Use a purpose-built role and user, never `%Operator`. Clean up exactly what you created. Write the results into Design Notes › Task 0 results, which the lead folds into AD-61 rule 1.
  - **T0.1, the gate.** Holding one administrative resource to pass the API floor, run the in-process recipe for `docnames/CLS`, `GET doc` and `action/index`:
    - in HSCUSTOM, USER and `%SYS`;
    - with `%Development:USE`, the namespace's routines-database READ and `%DB_IRISSYS:READ`, each dropped in turn;
    - with a mapped database's resource made non-public, then restored.

    Record each answer: refused, empty with 200, partial, or an envelope error. **Decision rule:** any pair whose absence yields an empty or partial answer, or a vendor `<PROTECT>`, joins the port's gate. A pair that is the same for every namespace also joins the descriptors' and the area's `privileges`.
  - **T0.2, the JSON body.** Compile the request stub (task below). Confirm that `Index` answers 200 in process with a JSON array body.
  - **T0.3, the capture ceiling.** Drive an answer above the ceiling, through a seam or a synthetic route method in a test class. Record the error type. Confirm `^||%capture` is gone, the device is restored and `$NAMESPACE` is unchanged.
  - **T0.4, side effects.** Snapshot the top of `^CacheTemp`, the routines database's `^rINDEX` and `^ISC.Src.Jrn` before and after one `docnames`, `doc` and `index` call each.
  - **T0.5, timing.** Measure the Classes default read on HSCUSTOM end to end in process. The target is 2 s or less (NFR-1).
- **`src/OcuPilot/Port/AtelierPort.cls`, new.** Its shape is `MgmntPort`'s. Its single entry point is `Invoke(pEndpoint, pType, ByRef pQuery, pBody, Output pResult, Output pHttpStatus, Output pFault, Output pDocument)`. Its endpoints:
  - `Classes`: `GetNamespace`, then `GetDocNames` with `CLS`.
  - `Routines`: `GetNamespace`, then `GetDocNames` with `RTN`.
  - `Class` and `Routine`: `Index`, then `GetDoc` of the name or of the first `.int` in `others`.

  Under the endpoints sit the AD recipe's eight steps (Design Notes), plus:
  - a `MINVERSION` per endpoint: `docnames` 1, `doc` 2, `index` 1;
  - `PINNEDVERSION` 8;
  - the name shapes:
    - class: `^%?[A-Za-z][A-Za-z0-9]*(\.%?[A-Za-z][A-Za-z0-9]*)*\.cls$`
    - routine: `^%?[A-Za-z][A-Za-z0-9]*(\.[A-Za-z0-9]+)*\.(mac|int|inc|bas|mvi|mvb)$`
  - the pattern shape: comma-separated pieces matching `^'?[A-Za-z0-9%.*]+$`;
  - case-sensitive `*` matching;
  - description markup flattened to text on the instance: `<...>` removed, and `&lt; &gt; &amp; &quot; &#39;` decoded;
  - the seams `GateClass`, `ImplClass` and `HighestVersion`;
  - `LOGSUBSYSTEM` "atelierport", plus the `Snippet` stubs.

  The class must never name `%Atelier`.
- **`src/OcuPilot/Port/AtelierRequest.cls`, new.** A `%CSP.Request` subclass with one method that sets `i%ContentType` to `application/json` and a JSON stream as `Content`. Nothing else uses it.
- **`src/OcuPilot/Screen/Read.cls`**:
  - add `SOURCEATELIER` and `AtelierPortClass()`, plus an atelier branch mirroring mgmnt's: `maxRows`+1, the criteria, `namespace` from `Kernel.Scope.Current()`, and `.tDocument`;
  - in `SeedCriteria`, an omitted `text` or `choice` criterion takes its declared `default`, which is reported in `criteria`. A criterion sent empty stays unset.
- **`src/OcuPilot/Screen/Registry.cls` and `ui/tools/screen-mirror.mjs`.** Change both identically:
  - admit `atelier` as a source port, and as a criteria port;
  - admit `default` on `text`, where it must fit `maxLength`, and on `choice`, where it must be one of `options`;
  - refuse `default` on `datetime`.

  Update the pinned refusal sentences in `Test/AdminPairCorpus.cls`, `CriteriaCorpus.cls` and `ReadSourceCorpus.cls`.
- **`src/OcuPilot/Screen/Area.cls`**: add `{"key":"system-explorer","railPosition":8,"labelKey":"navAreaSystemExplorer","navigates":false,"pinBottom":false,"privileges":[%Development:USE plus Task 0's same-for-every-namespace pairs]}`. Agent moves to `railPosition` 9.
- **`src/OcuPilot/Screen/Archetype.cls`**: add `{"key":"viewer (source)","linkOut":"none"}`.
- **`src/OcuPilot/Kernel/EntityType.cls`**: append `class,routine` to `TYPES`. Each canonicalizes to itself (AD-13).
- **Descriptors under `src/OcuPilot/Screen/Descriptor/`**, all four with:
  - `area` `system-explorer`, `scope` namespace, `refreshes` false;
  - no actions, `tableReadOnlyEmptyNext`;
  - at least 3 `webAppPromptGroupCode` prompts (Design Notes › Area);
  - `privileges` set per Task 0.

  The four:
  - **`ExplorerClassList.cls`**:
    - route `system-explorer/classes`, label "Classes", `sideBarPosition` 1, archetype `list (server criteria)`;
    - `entityType` `class`, `classicPage` `%CSP.UI.Portal.ClassList`, aliases `["classes", "class list", "source code"]`;
    - read `{port: atelier, endpoint: Classes, type: LIST}` with fields `Name, Modified, Database, Generated`. `filter` is `Name, Database`. `sort` is `Name, Modified, Database`, default `Name` ascending;
    - criteria:
      - `pattern`: text, maxLength 256, default `*`, label "Class name";
      - `system`, `generated` and `mapped`: choice `yes`/`no`, defaults `no`, `no` and `yes`;
      - `from` and `to`: datetime;
    - the table shows the four fields;
    - `toolIdentifier` `explorer.classes`.
  - **`ExplorerRoutineList.cls`**: the same, except:
    - route `system-explorer/routines`, label "Routines", position 2, `entityType` `routine`;
    - `classicPage` `%CSP.UI.Portal.RoutineList`, aliases `["routines", "include files", "mac routines"]`;
    - `pattern` default `*.mac`, label "Routine and include files", and `generated` default `yes`;
    - `toolIdentifier` `explorer.routines`.
  - **`ExplorerClassDocument.cls`**:
    - route `system-explorer/classes/document`, label "Class", `sideBarPosition` 0, archetype `viewer (source)`;
    - `id` single, `entityType` `class`, `classicPage` `%CSP.UI.Portal.ClassList`. It replaces that page's Documatic pane, so that page's custom resource gates it too (AD-44);
    - read `{port: atelier, endpoint: Class, type: LIST}` with fields `Order, Kind, Name, Type, Flags, Description, Modified, Database, Generates`, `sort` default `Order`, `filter` `Name, Kind`;
    - `context.fields` `Kind, Name, Type, Flags`;
    - criteria `name` (text, maxLength 256, from the route id) and `form` (choice `udl`/`xml`/`int`, default `udl`);
    - the table shows `Kind`, `Name`, `Type` and `Flags`;
    - `toolIdentifier` `explorer.class`.
  - **`ExplorerRoutineDocument.cls`**: the same, except route `system-explorer/routines/document`, label "Routine", `entityType` `routine`, `classicPage` `%CSP.UI.System.ViewCode` (normalized, observed), endpoint `Routine`, and `toolIdentifier` `explorer.routine`.
- **`src/OcuPilot/Install/Smoke.cls` and `src/OcuPilot/Test/Smoke.cls`**: add `explorer.classes` to `CheckAreaLists` as an exactly-one list at `maxRows=1`. The install namespace always holds OcuPilot's own classes.
- **`scripts/check-objectscript.py`**: add `src/OcuPilot/Port/AtelierPort.cls` to `CAPTURE_ALLOWED`, with its pin in `scripts/test_check_objectscript.py`.
- **`ui/src/app/areas/system-explorer/code-list.page.ts` and `code-list.store.ts`, new.** One page serves both lists.
  - It draws a criteria form from the descriptor's declared criteria: text → field, choice → checkbox or select, datetime → field. Labels come from `labelKey`, and the form opens on each criterion's declared default.
  - Search applies the form. The shared `DataTable` sits below with the max-rows footer.
  - Register both descriptors in `DESCRIPTOR_PAGES`. The store is framework-free (AD-19).
- **`ui/src/app/areas/system-explorer/document-viewer.page.ts` and `.store.ts`, new.** Registered in `ARCHETYPE_PAGES` under `viewer (source)`.
  - A header shows the name, database, last modified time and the generated `.int` names.
  - One control per view:
    - **Source**, **XML** and **Intermediate code**, each a re-read with `form`, show `document.content` as text in `<pre tabindex=0>` on `code-surface`, or the not-available sentence;
    - **Structure** is the shared table over the rows;
    - **Documentation** shows the class row's and each member's `Description` as text, under the member's name.
  - Structure and Documentation say "A routine has no class structure." for a routine.
- **`ui/src/app/shell/rail-icons.ts`**: add a `system-explorer` rail icon (20px) and tile icon (24px), a magnifier over `</>` at 1.5 stroke in `currentColor`. Draw them first in DESIGN.md's `mockups/key-home.html`, as a rail item and a Home tile.
- **`ui/src/app/core/strings.ts`**: add the new keys only, plus one change: move the single `/** EXPERIENCE.md:626 */` reference down by the number of Fixed strings rows added. Regenerate `ui/src/app/core/screens.generated.ts` with `node tools/screen-mirror.mjs`; never hand-edit it.
- **`_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md` and `DESIGN.md`.** Make the add-only edits listed in Design Notes › Area. Then run `bash scripts/lint-docs.sh` and `cd ui && npm run test:tools`.
- **Rosters and tests that must take rows.** See the footprint list for contended files.
  - **Server rosters:**
    - `Test/PortGate.cls` `ROSTER`: add `OcuPilot.Port.AtelierPort=PAIRS`, a driven denial leg, and `OcuPilot.Port.AtelierRequest` under a new `<stub>` marker (asserted to define no `Invoke`, as `<table>` is).
    - `Test/SurfaceCoverage.cls`: four rows.
    - `Test/Descriptor.cls`:
      - `ReadShapes` takes four rows;
      - the area count and rows (:1835-1868) go from 8 to 9;
      - the archetype count (:1389) goes from 16 to 17.
    - `Test/ReadTool.cls` :93-94 and :112: the count, the sorted names and the pairs.
    - `Test/ToolRoundTrip.cls` :51: `REFUSEEMPTY` gains `explorer.class.read:PORT.VALIDATION` and `explorer.routine.read:PORT.VALIDATION`.
    - `Test/InjectionChannels.cls`: a `TestClassDescription` channel, whose seed is the doc comment of a test-package fixture class read through `explorer.class.read`.
  - **Client rosters:**
    - `ui/tools/screen-mirror.test.mjs`: areas, the `withCriteria` list, the source ports.
    - `ui/tools/navigation.test.mjs`, `strings.test.mjs` (nine `navArea*` keys in rail order), `rail-icons.test.mjs` and `classic-links.test.mjs` (state-matrix key).
    - `rail.spec.ts`, `rail-wire.spec.ts` and `home.page.spec.ts` count pins: rail 8 to 9, tiles 6 to 7.
    - `ui/browser/home-performance.browser-spec.mjs` :349.
    - `ui/browser/structural-walk.mjs`: an id source for `viewer (source)`, so both viewers are walked rather than skipped.
  - **The arming variable.** `scripts/ci-throwaway.sh` takes a `# classes:` line for each new class that arms one, with `ui/tools/ci.test.mjs` following.
- **New tests**, each class at most about 500 lines, split where larger:
  - `src/OcuPilot/Test/AtelierPort.cls` and `AtelierPortFixture.cls`, in process:
    - every matrix row;
    - `filter` never seeded;
    - the namespace restored after success and after each fault;
    - no capture left open;
    - the version seam.
  - `src/OcuPilot/Test/AtelierPortDenial.cls`: real least-privileged principals, one leg per Task 0 pair. It arms `OCUPILOT_ALLOW_PRINCIPALS`.
  - `src/OcuPilot/Test/ExplorerDescriptor.cls`: all four validate, the classic pages normalize, the area row, the prompts, and every `explorer.*` tool reads `read` with none in `Baseline`.
  - `src/OcuPilot/Test/ExplorerWire.cls`, over HTTP: both list reads, both viewer reads with `document`, a denial, and each `explorer.*.read` dispatched through the tool path, which returns rows and no `document`.
  - `ui/src/app/areas/system-explorer/*.spec.ts`.
  - `ui/browser/system-explorer.browser-spec.mjs`, which includes the `structural()` walk on all four screens in light and dark.

- [x] [Lead] Pin `findmappings^%R`'s contract, which AD-61 rule 1 now names: a test in `Test/AtelierPort` or a sibling class (each under about 500 lines) calls it for HSCUSTOM as `AtelierPort` does and asserts the answer shape the port reads, HSLIB's directory among the mapped code databases, with a `mutation:` line under Verification.

**Acceptance Criteria:**

- **AC1 (the story's first criterion).** Given System Explorer's Classes or Routines list on a namespace, when it loads, then its rows come through `Port/AtelierPort` with the classic filters as server criteria and the max-rows cap. Those filters are the name pattern and the system, generated and mapped items, plus modified from and to. The footer shows the cap notice when the read reports `truncated`. Switching the namespace re-reads.
- **AC2 (the story's second criterion).** Given a class or routine row, when its name cell opens the viewer, then Source (UDL), XML, Intermediate code, Structure and Documentation (the quick view) are each available. Where the instance keeps no such form, the viewer says so in one sentence.
- **AC3 (Integration, Rule 1).** Given a turn on the Classes screen, when the agent calls `explorer.classes.read` with no arguments, then it receives the rows the screen opens on, under the same defaults. Given the class viewer, when the agent calls `explorer.class.read` with a name, then its result carries the structure rows, sanitized and bounded, and no source text.
- **AC4.** Given a signed-in holder of the area's pairs, when the shell loads, then System Explorer is the eighth rail item, after Security and secrets, drawn with its own icon, and Agent co-pilot stays pinned at the bottom. Home shows a seventh tile captioned "Classes · Routines". The command box finds both lists by their aliases. Every new built screen declares at least three suggested prompts.
- **AC5 (gate).** Given a principal holding exactly the measured pair set, when it reads either list or viewer, then it succeeds. Given the same principal missing any one pair, when it makes the same read, then it is refused 403 naming that pair, and never answered an empty list.
- **AC6 (read-only).** Given the tool registry and governance after this story, when `ExplorerDescriptor` enumerates every `explorer.*` tool and route, then no `explorer.*` tool classifies `write`, `Baseline.cls` is unchanged, and no route mints a proposal for the new area.
- **AC7 (DW-1337).** Given the structural walk, when it covers all four screens at 1280 light, 720 light and 1280 dark, then it adds no entry to `structural-baseline.json`.
- **Limit (AC4, AC5).** An account holding only `%Developer` cannot open System Explorer, because OcuPilot's `%Admin_*` floor guards every route and AD-61's gate sits on top of it until Story 19.12 widens that floor to admit `%Development:USE` (DW-1903, owner decision 2026-10-01).

## Spec Change Log

- 2026-10-01, implement halt (intent gap, AD-61 rule 5): lead ruling. AD-61 rule 5 now names a port-owned temporary file for `action/index` and rule 1 folds Task 0's pair set; re-dispatched `in-progress` with `baseline_revision` kept at `08ec761c` and the implementation intact in the tree.
- 2026-10-01, spec gate (orchestrator answers, by=merge_gate): AD-61 and its five companion amendments written into the spine; System Explorer at rail 8 approved as a tier-1 amendment; "Look in: Database" dropped; the `%Admin_*` floor kept for 19.1, and widened by Story 19.12 on the owner's later decision (DW-1903); the four non-additive edits approved with disjoint hunks; never sending `filter` and never calling `POST modified` recorded at AD-61.

## Review Triage Log

### 2026-10-01 — Review pass

- verdicts: 16 findings — high 0, medium 7, low 7, false 2, maybe-false 0
- findings:
  - `[medium]` `[patch]` AC4's command-box check typed `classes`/`routines`, which the labels and routes match before any alias — the browser AC4 loop now types `source code` and `include files`; mutation observed.
  - `[medium]` `[patch]` The index route's temporary file was never shown deleted — the fixture records each route's device; `AtelierPortDocument.TestTheIndexRouteWritesAPortOwnedFileItDeletes` asserts it gone after a read, a raise and an oversize answer; mutation observed (run 426).
  - `[medium]` `[patch]` `FILEDEVICEROUTES` was pinned only by a chance crash — the same test asserts `Index` ran on its own file with no redirect and `GetDoc` under the capture; mutation observed.
  - `[low]` `[patch]` Non-ASCII text through the file and the capture was never round-tripped — `ExplorerWire` asserts EntityId's U+2014 in `Description` and the source; its `Read` helper no longer re-decodes the already-decoded body, which had mangled it; mutation observed (run 428).
  - `[medium]` `[patch]` `Invoke`'s caller contract (its CSP objects unchanged) was unpinned — `AtelierPortDocument.TestTheCallersCspObjectsAreUntouched`, the canned route now leaving `%SourceControl` set as the vendor's does; mutation observed (run 427).
  - `[medium]` `[patch]` Intermediate code's not-available sentence had no client assertion — `document-viewer.page.spec.ts` case for a class that generates none; mutation observed.
  - `[low]` `[patch]` `AtelierPortDenial`'s USER-leg mutation sentence named the routines pair alone, which the coinciding globals pair masks — corrected to both pairs.
  - `[low]` `[reject]` A viewer read in flight across a namespace switch could land its document after the new one — needs out-of-order answers within one switch, and the fix adds a namespace guard to the viewer state.
  - `[low]` `[reject]` Include/date filters, all six routine types and the old-instance and unlogged-404 rows are tested at the port, not over the wire — the port tests pin the behavior and the wire legs pin the pass-through; duplicating them over HTTP adds tests, not a defect.
  - `[medium]` `[patch]` The oversize row was tested only on the capture path — the index-file test's oversize leg answers 503 with the file gone and the device and namespace restored.
  - `[low]` `[patch]` `system=maybe` reached the length bound, never option membership — `ExplorerWire` also sends `system=yep` (400 `READ.CRITERION`).
  - `[low]` `[patch]` A document read in a namespace holding none of OcuPilot's code (the request stub handed to the vendor there) was untested — `TestALiveClassReads` reads `%Library.RegisteredObject.cls` in USER, namespace restored.
  - `[false]` `[reject]` Document text could reach screen context client-side — context is projected from the store's rows through `context.fields` (Kind, Name, Type, Flags, pinned by `ExplorerDescriptor`); the document lives in `SourceViewerState`, not the store.
  - `[false]` `[reject]` "Including mapped ones" is asserted nowhere — `AtelierPort.TestTheReadExecutorAppliesDefaultsAndCarriesTheDocument` asserts `Beta.Mapped.cls` (LIBDB) under the defaults; the 1,000 cap is asserted by the browser AC1 cap notice and `code-list.page.spec.ts`.
  - `[medium]` `[patch]` The three Fixed-strings rows and the state-matrix row shifted EXPERIENCE.md's own citations at or past :586 (:610, :617, :627, :647, :662, :664, :701, :728, :867) onto other rows — each moved by the inserted rows (+3, +4 past :800), no line inserted.
  - `[low]` `[reject]` `Test/ReadTool.cls` :365 (criteria count 15 to 19) lies outside the approved :93-94 and :112 hunks — the count must follow the four criteria-bearing descriptors, and neither concurrent worktree touches the file; reported to the lead.

## Design Notes

**Governing ADs:** AD-61 (the port's contract), AD-1, AD-2 (the pattern this port copies), AD-5, AD-7, AD-8, AD-11, AD-12, AD-13, AD-14, AD-16, AD-19, AD-21, AD-24, AD-27 (its containment pattern), AD-29, AD-36, AD-39, AD-43, AD-44, AD-45, AD-60.

### AD-61 (in the spine)

The lead wrote AD-61 into the spine at the spec gate with its five companion amendments (Design Paradigm's port list, AD-7's fourth shape `^rINDEX`, AD-29's Binds, AD-36's criterion `default`, the capability map). AD-61 is the contract for `AtelierPort`; read it there. Task 0's measured pairs are folded into AD-61 rule 1 by the lead after `dev_complete`.

**Where each of AC2's six forms comes from** (Atelier v8; each route's minimum version in brackets):

| Form | Route [minimum version] | Available when |
|---|---|---|
| source | `GET /:ns/doc/:name`, no `format` [v1] | always |
| UDL | the same route: a class's source *is* its UDL. `udl-multiline` is not offered | always |
| XML | `GET doc?format=xml` [v2] | classes and routines (observed 200 for `HS.HC.Info.mac`) |
| macro-expanded `.int` | `GET doc/<the first .int in index others>` [v1] | when `others` names one. Deployed library classes (`others: []`) and `.inc` files have none |
| class structure index | `POST /:ns/action/index` [v1] | classes. A routine's index returns empty `content` (observed) |
| Documatic quick view | the index's `desc` arrays, flattened to text | classes |

Story 19.9 owns the full Documatic page, so 19.1 neither embeds it nor links to it. That keeps AD-28's no-token-in-a-frame rule and AD-44's link rules out of this story.

**The classic filters (AC1).** Read on `%CSP.UI.Portal.ClassList` :58-72 and :277-309, and on `RoutineList`.

| Classic control | Default (classes / routines) | How OcuPilot carries it |
|---|---|---|
| Class name or routine pattern | `*.cls` / `*.mac` | `pattern`, matched by the port. Classes are matched without `.cls`. A routine piece with no extension matches every type |
| System items | off | `system`, matched by the port on a leading `%` |
| Generated items | off / on | `generated`, sent to the vendor as `generated=1` |
| Mapped items | on | `mapped`. The port drops rows whose `db` is not `GetNamespace`'s `default` database |
| Begin date and End date | blank | `from` and `to` (datetime), matched by the port on `ts` |
| Maximum rows | 1000, at most 10,000 | the shared max-rows cap. The declared read has no upper bound |
| Look in: Database | Namespace | **Not carried.** An implied namespace is a path-shaped scope (AD-21) that AD-13's triple has no form for. A database is reached through a namespace |
| `.obj` mask and `;*` backups | | **Not carried.** Atelier's `docnames` lists neither |
| SQL table name (classes) | off | **Not carried.** It is a display option that links to SQL globals, Story 19.5's ground |
| Size column | | **Not carried.** `docnames` rows carry no size |

**The agent's view (AD-36, AD-24, AD-60).** Document text is AD-36's screen-only payload: "a read whose rows are derived from a single named vendor object may return that object alongside the capped rows… never part of the tool's view… never enters screen context". The OpenAPI viewer is the precedent. Three reasons:

- it is untrusted text whose comments can carry instructions (AD-11);
- one class's source runs to 184 KB (`AdminPort.cls`), far past AD-24's 65,536-character total, so the model would get a mid-file cut;
- the structure rows answer every suggested prompt.

`Description` reaches the tool, cut at 1,000 characters and sanitized. Screen context carries `Kind`, `Name`, `Type` and `Flags`.

**Area (the lead's prompt, item 2).** Filling in the area is a gap-fill, not a product call. The epic context makes the first story to add a screen responsible for the area, and placing it after Security and secrets moves no existing area.

- **Name and position.** The area is named "System Explorer", the classic menu's own name, and sits at rail position 8, ahead of Agent co-pilot.
- **Screens.**
  - The side bar lists Classes (1) and Routines (2).
  - Each list has an unlisted viewer at `<list route>/document`, at `sideBarPosition` 0.
  - Two viewers, rather than one shared viewer, follow `documentScreenFor`'s one-viewer-per-list convention. A `rowTarget` is barred on a criteria list.
- **Home tile.** Home's tile follows by design, captioned "Classes · Routines".
- **Prompts** (group "Code"):
  - Classes: "Which classes in this namespace changed most recently?" · "Which classes here are mapped from another database?" · "Which packages hold the most classes?"
  - Routines: "Which routines changed most recently?" · "Which include files does this namespace hold?" · "Which routines here are generated?"
  - Class: "Summarize what this class does." · "Which methods does this class define?" · "Which members are deprecated or internal?"
  - Routine: "When did this routine last change?" · "Which database holds this routine?" · "Which intermediate routines does this routine generate?"
- **EXPERIENCE.md edits** (approved at the spec gate as a Rule 5 tier-1 amendment). All are in place, with no line inserted above :586. Rows added below :585 shift every later line, so update every EXPERIENCE.md line citation the suites hold, not only `strings.ts`'s; `npm run test:tools` names them.
  - :52 and :66: add "· System Explorer" after "Security and secrets". In :66, Agent co-pilot becomes "the eighth area".
  - :159: append "System Explorer (Stage 3, Story 19.1): Classes · Routines; each list's documents open in its unlisted viewer." A new side-bar table row would shift every reference below it.
  - :310: add `"System Explorer"` before `"Agent co-pilot"`.
  - :593: "eight rail-items" becomes "nine rail-items".
  - :634: "Six tiles … one per contest area" becomes "Seven tiles … one per area but Home and Agent co-pilot".
  - Add a `viewer (source)` state-matrix row after `viewer (OpenAPI)` (about :800).
  - Append new Fixed-strings rows after :585, holding the new labels, criteria labels, column headers, view names, the not-available sentences, the empty states ("No classes in <NAMESPACE> match.", "No routines in <NAMESPACE> match.") and the twelve prompts.
- **DESIGN.md edits** (in place):
  - :975: "Eight" becomes "Nine", add "· System Explorer", "the eight drawn" becomes "the nine drawn", and "six areas" becomes "seven".
  - :1103: "Home's six areas" becomes "seven".
  - `mockups/key-home.html` gains the icon and the tile.

**Read-only (the lead's prompt, item 6).** Story 19.1 mints no proposal, registers no write tool and adds no governance key. AC6 pins this.

**Integration ACs (Rules 1 and 2).**

- **Consumes:** `Screen/Read.cls` (AD-36), `Kernel.Scope`, `Screen.Gate`, `Kernel.Fault`, `Kernel.Shell.Namespaces.NamespaceInfo`, the shared `DataTable` and the read-tool registry.
- **Consumed-by:**
  - **19.2:** compile, delete, export and import as `AtelierPort` write endpoints, with v7's version gate through the same `MINVERSION`.
  - **19.3:** `PUT doc` with the ETag. The viewer's read keeps `ts` for it.
  - **19.4:** search, macro lookup and two document reads diffed.
  - **19.5 to 19.8 and 19.10:** `action/query` through the port.
  - **19.9:** Documatic beside the viewer.
  - **19.11:** the agent's SQL tool.

**Footprint (Rule 11).**

- **Contended, add-only:** `Test/SurfaceCoverage.cls` rows, `Test/ToolRoundTrip.cls` `REFUSEEMPTY` entries, new `strings.ts` keys, the EXPERIENCE.md edits above, the `scripts/ci-throwaway.sh` `# classes:` line, and the regenerated `screens.generated.ts`.
- **Contended and not strictly add-only, approved at the spec gate with disjoint hunks.** Re-check both concurrent worktrees at edit time (`git -C /Users/jbrandt/git/OcuPilot/.worktrees/epic-18 diff --stat=200 origin/feature/OCU-1_ocupilot-mvp...HEAD` plus `status -s`, and the same for `.worktrees/epic-23`). If either changes the same lines, HALT `blocked` naming the file and lines. Story 18.15 changes `Test/ReadTool.cls` :93-94; the lead integrates it from feature before this stage, and if it is not in your tree at edit time, HALT.
  - `Test/ReadTool.cls` :93-94 and :112: the count literal and the sorted name string.
  - `ui/tools/strings.test.mjs`: the eight-key area list, plus any count literal.
  - `strings.ts`: the one `EXPERIENCE.md:626` reference.
  - `ui/angular.json` and `ui/tools/angular-json.test.mjs`: re-base `maximumWarning` to the measured initial size only if the build exceeds 2,388 kB. Stop and ask above 3,800 kB.
- **Not contended:** everything else, including the spine, which the lead edits.

**Named limitations, for the lead.**

- **The capture ceiling.** A namespace listing more than about 3.6 million characters of document names gets `PORT.UNAVAILABLE` (HSCUSTOM's classes use 1.83 MB).

**Ledger inbox:** none.

**Task 0 results** (`ocupilot-ci`, 2026-10-01; principals `%Admin_Operate:U` + `%DB_HSCUSTOM:R` + the pairs named, each dropped in turn, removed afterwards):

- **T0.1.** Superuser baseline, `docnames/CLS`: HSCUSTOM 13,867 rows, USER 5,214, `%SYS` 3,649.
  - Without `%Development:USE`: `docnames` and `index` answer in full; `GET doc` answers 200 with `result.status` "ERROR #5838: You need %Development:Use privilege". Joins the gate, the descriptors and the area.
  - Without the namespace's database READ (`%DB_USER` in USER, `%DB_IRISSYS` in `%SYS`): `<PROTECT>` at the namespace switch, all three routes. Joins the gate per namespace.
  - Without `%DB_IRISSYS:READ`: HSCUSTOM and USER answer in full, the rows IRISSYS holds included (159 classes, 28 routines; `GET doc` and `index` of `%SYS.Audit.cls` answer 200). Does not join outside `%SYS`.
  - `%DB_HSLIB` made non-public (a mapped code database): `docnames/CLS` in HSCUSTOM answers 200 with no rows (twice); `doc` and `index` answer 200. Joins the gate: READ on every database the namespace maps code from (`findmappings^%R`), the system database excepted, resolved at call time. Restored to `R`.
  - Measured pair set: `PAIRS` = `%Development:USE`; per namespace, READ on its routines database, its globals database (the switch needs it; the two coincide in all three namespaces) and its mapped code databases but IRISSYS. The descriptors and the area declare `%Development:USE` alone.
- **T0.2.** `index` answers 200 in process with a JSON array body through `Port/AtelierRequest`.
- **T0.3.** An answer of 3.9 million characters: the renderer's own `Try` returns `<MAXSTRING>write+10^%SYS.Capture`; the port answers 503 `PORT.UNAVAILABLE`, `^||%capture` is gone, `$IO` and the redirect are restored, `$NAMESPACE` is unchanged, and the next call reads.
  - **`index` under `%SYS.Capture` ends the process.** Background jobs of 20 calls each: 5 of 10, then 3 of 10, died with signal 11, mostly on the first call. `GET doc`, `docnames` and `GetNamespace` under the same capture: 0 of 10 each. `index` through a file device: 0 of 10; with no redirect: 0 of 10; the vendor's own HTTP route, 40 calls: none. The port writes `index`'s answer to a temporary file it reads back and deletes (`FILEDEVICEROUTES`); the `Class` endpoint then ran 10 jobs of 20 calls with none. AD-61 rule 5 names the capture for every route (inference: amend it to name the file device for `index`).
- **T0.4.** `docnames`: the `^CacheTemp` counter rises by one and no node remains; `^rINDEX` (4,388 nodes, CRC unchanged) and `^ISC.Src.Jrn` in all five databases are unchanged. `doc` and `index`: nothing changed.
- **T0.5.** The Classes default read through `Screen/Read.Execute` on HSCUSTOM: 0.32 to 0.36 s, 1,000 rows, truncated.

## Verification

Load the source into `ocupilot-ci` without the MCP tools, and never restart that container:

```bash
rsync -a --delete /Users/jbrandt/git/OcuPilot/.worktrees/epic-19/src/ /tmp/ocupilot-ci/src/
docker exec -i ocupilot-ci iris session iris -U HSCUSTOM
# then: Set tSC=$System.OBJ.LoadDir("/opt/ocupilot/src","ck",.tErrors,1)
#       and check both tSC and tErrors
```

**One test-runner call at a time, ever.** Run one ObjectScript class or one browser spec file per tool call, and wait for it to finish. Never put two test calls in one message. Never re-submit after a client-side timeout: wait, then read `%UnitTest_Result`. Every subagent inherits this rule.

**Commands:**

- `uv run scripts/check-objectscript.py && uv run scripts/test_check_objectscript.py` (loop): expected green.
- `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class <Class>` (loop), one class per call, for each of:
  - `OcuPilot.Test.AtelierPort`, `AtelierPortDenial`, `ExplorerDescriptor` and `ExplorerWire`;
  - `PortGate`, `Descriptor`, `ReadTool`, `ToolRoundTrip` and `SurfaceCoverage`;
  - `AdminPairCorpus`, `CriteriaCorpus` and `ReadSourceCorpus`;
  - `InjectionChannels` and `Smoke`.

  Expected green. Planned mutations:
  - send `filter` → AtelierPort's "never seeded" leg reds;
  - drop the routines-database pair → AtelierPortDenial reds;
  - skip the restore in `Catch` → AtelierPort's restore leg reds;
  - copy `document` into `Tool/Read.View` → ExplorerWire's tool leg reds;
  - drop a criterion `default` → AtelierPort's defaults row reds;
  - declare a write tool on an `explorer.*` descriptor → ExplorerDescriptor's read-only leg reds.
- `cd ui && node --test tools/screen-mirror.test.mjs tools/navigation.test.mjs tools/strings.test.mjs tools/rail-icons.test.mjs tools/classic-links.test.mjs tools/suggested-prompts.test.mjs tools/citations.test.mjs tools/ci.test.mjs` (loop): expected green.
- `cd ui && npx ng test --include 'src/app/areas/system-explorer/**' --include src/app/shell/rail.spec.ts --include src/app/areas/home/home.page.spec.ts` (loop): expected green. Planned mutation: bind `content` with `[innerHTML]` → the viewer spec's markup-as-text case reds.
- `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/` (loop, before each browser run), then run each of these files on its own:
  - `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci node --test --test-concurrency=1 browser/system-explorer.browser-spec.mjs`
  - the same command for `browser/a11y-structural-invariants.browser-spec.mjs`
  - the same command for `browser/home-performance.browser-spec.mjs`

  Expected green, with `structural-baseline.json` unchanged. The full browser suite is CI's three shards, not a local step.
- `bash scripts/lint-docs.sh && cd ui && npm run test:tools` (loop, after any EXPERIENCE.md or DESIGN.md edit): expected green.
- `cd ui && npm test` (once, before dev_complete): expected green, with the bundle under `maximumWarning`, or re-based per the footprint note.
- `cd ui && node tools/ci-runner.mjs --container ocupilot-ci`, the full ObjectScript sweep, one class at a time (once, before dev_complete). Expected green apart from named residue: classes refused for older arming variables, `WireSecurityRead`'s task-history test (DW-1425/DW-1468), and tests that assume no agent definitions (DW-1759). CI's fresh container is the proof.

Record one `mutation: <change> → <test that reddened>` line per AC under this section as each is observed (Rule 19).

- mutation: AC1, seed `filter` into `ListRows`' `GetDocNames` call → `AtelierPort.TestListFiltersApplyBeforeTheCapAndFilterIsNeverSent` (run 23785); drop the `default` line from `Read.SeedCriteria` → `AtelierPort.TestTheReadExecutorAppliesDefaultsAndCarriesTheDocument` (run 23794); send the atelier read's `maxRows` as the cap rather than the cap plus one in `Read.Execute` → `system-explorer.browser-spec.mjs` AC1 (no cap notice, `ocupilot-a2-ci`).
- mutation: AC2, bind the viewer's text with `[innerHTML]` → `document-viewer.page.spec.ts` "opens a class on Source"; give Intermediate code the XML sentence in `NOT_AVAILABLE` → "a class that generates no intermediate code says so on Intermediate code".
- mutation: AC3, copy `document` into `Tool/Read.View`'s result → `ExplorerWire.TestTheReadToolsAnswerRowsAndNeverTheDocument` (run 23788).
- mutation: AC4, drop `system-explorer` from `AREA_ICONS` → three `rail-icons.test.mjs` tests; empty both lists' `commandAliases`, regenerated, rebuilt and deployed → `system-explorer.browser-spec.mjs` AC4.
- mutation: AC5, drop the namespace's own database pairs from `NamespacePairs` → `AtelierPortDenial.TestWithoutTheNamespacesDatabaseTheReadIsRefusedNamingIt` (run 23787); drop its mapped databases → `TestAMappedDatabaseIsGatedRatherThanReadEmpty` (run 23796); skip the `PAIRS` check → `TestWithoutDevelopmentEveryReadIsRefusedNamingIt` (run 23795) and `PortGate.TestEveryPortEvaluatesItsDeclaredGate` (run 23800).
- mutation: AC6, declare a row action on `ExplorerClassList` → `ExplorerDescriptor.TestTheAreaIsReadOnly` (run 23790).
- mutation: AC7, `.ocu-source-view { min-width: 1200px }`, rebuilt and deployed → both viewer tests of `system-explorer.browser-spec.mjs` (overflow entries outside the baseline).
- mutation: AD-16, delete the restore from `Route`'s call `Catch` → `AtelierPort.TestTheNamespaceIsRestoredAfterSuccessAndAfterAFault` (run 23786).
- mutation: AD-61 rule 1, `DatabaseResources` reads `findmappings^%R`'s third argument in place of its second → `AtelierPort.TestFindMappingsAnswersTheShapeThePortReads` (run 2, `ocupilot-a2-ci`).
- mutation: AD-61 rule 3, drop `%session` and `%SourceControl` from `Route`'s `New` → `AtelierPortDocument.TestTheCallersCspObjectsAreUntouched` (run 427).
- mutation: AD-61 rule 5, `FILEDEVICEROUTES` set to `""` → `AtelierPortDocument.TestTheIndexRouteWritesAPortOwnedFileItDeletes` (single-method run; the class run dies on signal 11 in `TestALiveClassReads`); delete the file's deletion from `Route` → the same test (run 426); read the file back `RAW` → `ExplorerWire.TestTheClassViewerAnswersRowsAndTheDocument` (run 428).

## Auto Run Result

Status: done
Blocking condition: none

**Change.** `Port/AtelierPort` (with its `AtelierRequest` stub) reads the source code API in process behind its own gate; System Explorer is the eighth rail area, with the Classes and Routines lists (classic filters as server criteria, declared defaults) and the class and routine viewers (Source, XML, Intermediate code, Structure, Documentation); four read tools, no write.

**This pass (cycle 2, on `ocupilot-a2-ci`).**

- Pinned `findmappings^%R` (`AtelierPort.TestFindMappingsAnswersTheShapeThePortReads`).
- The full sweep reddened three area rosters the ninth area changes (`WireAreaAnyScreen`, `Wire`, `Navigation`); each now carries System Explorer (`%Development:USE`), with the two captured navigation payloads (`rail-wire.spec.ts`, `navigation-wire.test.mjs`) given its entry.
- Review patches (triage log): the alias-only command-box check, the cap notice in the browser AC1 leg, the index file's device and deletion on every path, the caller's CSP objects, non-ASCII round trip (and `ExplorerWire.Read` no longer re-decoding a decoded body), the int not-available sentence, `system=yep`, a USER document read, EXPERIENCE.md's own shifted citations, one doc sentence.

**Review.** 16 findings: 12 patched (medium 7, low 5), 0 deferred, 4 rejected (2 low not worth a guard or duplicate HTTP tests, 2 false), each with its reason in the triage log. Follow-up review: `false`; every patch's mutation was observed red and reverted byte-identical, so no named risk is left unverified.

**Verification.**

- `check-objectscript.py` 0 problems; its harness 144 passed.
- Loop classes one at a time, green: AtelierPort, AtelierPortDenial, AtelierPortDocument, ExplorerDescriptor, ExplorerWire, PortGate, Descriptor, ReadTool, ToolRoundTrip, SurfaceCoverage, InjectionChannels, Smoke. `AdminPairCorpus`, `CriteriaCorpus` and `ReadSourceCorpus` are corpora `ReadTool` runs, not test cases.
- Full sweep, 20 sequential shards: 397 classes, 3,280 tests; the 5 failures were the three rosters above, green after the fix (runs 149, 253, 355).
- `npm test` 1,766 + 2,075 green; after the patches `test:tools` 1,766 and the story's component specs 109 green; `lint-docs.sh` clean.
- Build 2,419,637 bytes, under the 2420kB warning. Browser, each file alone against the redeployed bundle: `system-explorer` 4/4, `a11y-structural-invariants` 12/12 (`structural-baseline.json` unchanged), `home-performance` 4/4.
- Matrix Test Audit: all 15 rows covered by tests that ran green.

**For the lead.**

- Files outside the spec's footprint, none touched by Epic 18 or 23: `Test/WireAreaAnyScreen.cls`, `Test/Wire.cls`, `Test/Navigation.cls`, `ui/tools/navigation-wire.test.mjs`; and `Test/ReadTool.cls` :365 beside its approved hunks.
- `ocupilot-a2-ci` `messages.log` holds one signal 11 at 23:37:37 from the `FILEDEVICEROUTES` mutation (the vendor crash reproduced); the mutation's temporary files were removed.
