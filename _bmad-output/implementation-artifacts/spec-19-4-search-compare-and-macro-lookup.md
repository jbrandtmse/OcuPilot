---
title: 'Story 19.4: Search, compare and macro lookup'
type: 'feature'
created: '2026-10-02'
status: 'in-progress'
baseline_revision: '6f718d934244b6f45b511e5cb72f1d15038bac7e'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-19-context.md'
warnings: ['multiple-goals', 'oversized']
deferred:
  - 'Screen/Tool/Read.AddCriteria describes every text criterion as a comma-separated name list where * matches, which misdescribes Search''s text and Macros'' document and macro to the model.'
---

<intent-contract>

## Intent

**Problem:** System Explorer lists and shows code but cannot find text across a namespace, show what differs between two documents, or say what a macro expands to, so each of those needs Studio, VS Code or the classic Compare Routines page.

**Approach:** Three listed System Explorer screens. Search and Macros are declared reads through `AtelierPort`: a plain-text `GET action/search` bounded by the read's cap, and `POST action/getmacrodefinition` plus `getmacrolocation` in the context a named document's own text gives. Each is an advertised read tool. Compare issues the class or routine viewer's declared read once per side, possibly in two namespaces, and renders a line diff in the browser with the project's own diff code.

## Boundaries & Constraints

**Always:**

- AD-61's order holds for both new endpoints: the gate (`%Development:USE`, then the namespace's code-database READ pairs), the endpoint, the version (`MINVERSIONS` `Search:2,GetMacroDefinition:2,GetMacroLocation:2`), the arguments, then the routes.
- Search sends exactly `query` (the caller's text), `documents` (from the declared `scope` alone), `regex=0`, `case`, `sys=0`, `gen=0` and `max` (the read's `maxRows`, which `Screen.Read` sets to the cap plus one).
- The macro body is `{docname, macroname, includes, superclasses, imports}`. The port builds it from the declared `document` and `macro` and from the names the document's own UDL text gives. It travels through `AtelierRequest.SetJsonBody`. No new route writes.
- Search and macro rows reach a tool and screen context as rows only. `Text` and `Definition` are cut by AD-24's per-field bound and wrapped by AD-60, as `explorer.class.read`'s `Description` already is. A document's whole text stays screen-only.
- Compare reads only through `ExplorerClassDocument` or `ExplorerRoutineDocument`'s declared read, under that viewer's gate, with `ApiRequestInit.scope` naming each side's namespace (the `source-editor.store.ts` precedent).
- Code renders as text (AD-11 rule 4). Every screen declares three prompts in the `webAppPromptGroupCode` group.

**Never:**

- `regex` other than `0`, `word`, `wild`, or any caller text in `documents`.
- The `work` routes, `docnames`' `filter`, or `POST modified` (AD-61 rule 7).
- `getmacrolist`, `getmacrosignature` or `getmacroexpansion`.
- A diff library, a new runtime dependency, a new API route, a write tool or a governance key.
- An edit to `Api/Error.cls`, `Screen/Read.cls`, `Screen/Registry.cls` or EXPERIENCE.md line 173.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Search hits | USER probes; `text` a needle; `scope` all | One row per match, in the vendor's order: `{Order, Document, Member, Line, Attribute, Text}`. Class members carry a member and a line, a description carries `Attribute` `Description`, a parameter carries no line, and a routine carries a line | None |
| Case | `case` `no` (default), then `yes` | `no` also matches a lower-case line; `yes` does not | None |
| Scope | `scope` `classes` or `routines` | `documents` is `*.cls`, or `*.mac,*.int,*.inc,*.bas,*.mvi,*.mvb` | None |
| Over the cap | more matches than `maxRows` | Exactly the cap in rows; `truncated` true | Cap notice on screen |
| Metacharacters | `text` `OcuP.obe194Needle` | No rows (plain text, never a regex) | None |
| Bad search input | `text` empty, over 256 characters or holding a control character; `scope` or `case` outside its options | 400 `PORT.VALIDATION` with the port's reason, before any route | Banner |
| Macro found | `document` a class that `Include`s the probe include; `macro` a name it defines | One row `{Macro, Document, Line, Definition}`: the definition's lines joined by LF, and the `.inc` and line where it is defined | None |
| Macro through context | a subclass of that class; a routine's `#include`; an `.inc` naming itself; `$$$Name` | Found the same way; a leading `$$$` is dropped | None |
| Macro unknown | a name nothing in that context defines | Zero rows | Empty state names the macro and document |
| Macro document absent | no such document | 404 `PORT.NOTFOUND`, unlogged | Banner |
| Bad macro input | `document` matching neither name pattern; `macro` not `^(\$\$\$)?%?[A-Za-z][A-Za-z0-9]*$` | 400 `PORT.VALIDATION` before any route | Banner |
| Gate | no `%Development:USE`, or no READ on the namespace's code database | 403 `AUTH.NOPRIVILEGE` naming the pair, before any vendor call | Banner |
| Old instance | highest version 1 (version seam) | 501 `PORT.NOTIMPLEMENTED` | Banner |
| Compare identical | the same text twice | "The two documents are identical." | None |
| Compare differs | two versions | Hunks with three lines of context; removed and added lines marked by sign, color and announced direction; unchanged runs collapsed | None |
| Compare too large | more than 1,000 edits after trimming the common head and tail | The too-large sentence; nothing is drawn | None |
| Compare side refused | a side's read answers 404 or 403 | That side's reason; nothing is drawn | Banner |

</intent-contract>

## Code Map

- `src/OcuPilot/Port/AtelierPort.cls` -- the port.
  - `MINVERSIONS` :57; `ENDPOINT*` :72-81.
  - `MinVersion` :486: a `$Select` per endpoint and type.
  - `Invoke` :549: the gate prologue :560-582 is shared; `tServed` :582; read dispatch :660-670.
  - `ListRows` :687 is the pattern for validating criteria. `Document` :1775 calls `Route` `GetDoc` (~:1830).
  - `Route` :2041 already writes a dynamic `pBody` through `AtelierRequest`. `Outcome` :2173. `REASON*` :287-355.
- `src/OcuPilot/Screen/Read.cls:428-440` -- the atelier branch, endpoint-agnostic: it sends `maxRows` cap+1 and the criteria. Unchanged.
- `src/OcuPilot/Screen/Tool/Read.cls:193-258` -- `View` keeps rows only. `Kernel/Agent/Bound.cls:32` and `Dispatch.cls:313-334` apply AD-24's per-field 1,000 and total 65,536. Unchanged.
- `src/OcuPilot/Screen/Descriptor/ExplorerClassList.cls` -- a `list (server criteria)` atelier read with criteria.
  - `AgentSwitches.cls` is a listed `form-page` with no read and `id` `none`.
  - `LogErrorList.cls` is listed with no read and has a classic page.
  - A list read needs a `table` with exactly one `name` column, and `emptyNextKey` `tableReadOnlyEmptyNext` (`Registry.TableProblem` :2383).
  - Criteria have no `required` flag; the port refuses a missing value.
- `src/OcuPilot/Kernel/EntityType.cls:57` -- closed vocabulary. Use `class` and `routine`; add no type.
- Vendor (read, never edited):
  - `irissys/%Api/Atelier/v2.cls`: `Search` :1157 (parameters :1180-1196, the console parse :1235-1300); `GetMacroLocation` :884; `GetMacroDefinition` :959.
  - `irislib/%Atelier/v2/Utils/Macros.cls` `ParseMacroRequest` requires `application/json` and a valid `docname`.
  - `irislib/%Studio/Project.cls`: `FindInFiles` :2140, `FindInFilesRegex` :2358.
  - `irislib/%Library/RoutineMgr.cls:1146,1257-1262`: a bracketed part of the spec becomes `Filter`, spliced into SQL.
- Tests:
  - `Test/AtelierPortFixture.cls` -- the seams `ImplClass` :106, `HighestVersion` :119, `GateClass` :99, `LogFault` :137, and canned routes :153-231 via `Answer` :235.
  - `Test/AtelierReadFixture.cls` -- runs `Screen.Read` against the fixture.
  - `Test/AtelierPortDenial.cls` -- `EnsurePrincipal` :164, `Read` :203, `ProbeAs` :221.
  - `Test/ExplorerWire.cls:187` -- the tool view carries no document.
  - `Test/InjectionChannels.cls:257` with `InjectionSeed.cls:382` -- source (h), the precedent for a code-text channel.
- Client:
  - `areas/system-explorer/document-viewer.store.ts`: `createSourceRead` :225, `SourceDocument` :38-49.
  - `source-editor.store.ts:307-311`: another namespace through `{...init, scope}`.
  - `document-viewer.page.ts`: the `editLink` getter :339-348; "Edit source" :121-123.
  - `core/navigation.ts`: `entityUrl` :713, `documentScreenFor` :262, `listForDocumentScreen` :269.
  - `core/entity-id.ts:69` -- `encodeEntityId`.
  - `core/screen-read.ts:177-236` -- `screenReadPath` and `createScreenRead`.
  - `core/screen-arrival.ts:36-67` -- `ScreenArrivals.take`, used as `code-list.page.ts:312-332` and `code-list.store.ts:140-158` use it.
  - `core/change-bus.ts` `ChangeBus.subscribe`, with `os-management/database-details.page.ts` as the page-level precedent.
  - `shell/screen-outlet.ts` `DESCRIPTOR_PAGES` :184-189.
  - Do not reuse `CodeListPage`: `command-bar.ts:759-764` draws Import on registration alone, and `data-table.ts:653-679` links a name cell per list, not per row.
- Styles:
  - `_tokens.scss`: `--ocu-destructive-container`, `--ocu-on-destructive-container`, `--ocu-success-container`, `--ocu-destructive`, `--ocu-success`, `--ocu-on-surface`.
  - `_components.scss`: `.ocu-diff-direction` :4450 (visually hidden "was"/"now") and `.ocu-source-text` :4920.

## Tasks & Acceptance

**Execution:**

- [ ] `src/OcuPilot/Port/AtelierPort.cls` -- the two read endpoints.
  - Add `ENDPOINTSEARCH` `Search` and `ENDPOINTMACRO` `Macro`, served for `REQUESTTYPE` only, with `MinVersion` entries and the `MINVERSIONS` entries above.
  - **`SearchRows`**:
    - validates `text`, `scope` (`all` when absent) and `case` (`no` when absent);
    - maps `scope` through a `SEARCHDOCUMENTS` parameter;
    - routes `Search` with the parameters in Always (`max` is `maxRows`, else 200);
    - flattens `result` to rows, `Line` numeric (`line`, else `attrline`, else JSON null), and cuts at `maxRows`.
  - **`MacroRows`**:
    - validates `document` (`CLASSNAMEPATTERN` or `ROUTINENAMEPATTERN`) and `macro` (pattern above, `$$$` dropped);
    - routes `GetDoc` (udl) for the document's text, then derives the context with a new public `MacroContext(pName, pLines)`;
    - routes `GetMacroDefinition` and `GetMacroLocation` with the body;
    - answers zero rows when the definition is empty, else one row.
  - **`MacroContext`** answers the three name lists:
    - from a class's lines before its `Class` line: `Include`, `IncludeGenerator` and `Import`, each `Name` or `(A, B)`;
    - from the `Class` line: its `Extends` list;
    - from a routine: every `#include` line, case-insensitive, plus an `.inc`'s own name;
    - it keeps names matching `^%?[A-Za-z][A-Za-z0-9.]*$`, at most 50 per list.
  - Add `REASON*` sentences (Design Notes › Strings). Extend the class's doc comment by one paragraph.
- [ ] `src/OcuPilot/Screen/Descriptor/ExplorerSearch.cls` (new) -- the Search screen.
  - Route `system-explorer/search`, listed (`sideBarPosition` 3), `list (server criteria)`.
  - `%Development:USE`; `entityType` `class`, secondary `routine`; scope `namespace`; `id` `none`.
  - Read `{port: atelier, endpoint: Search, type: LIST}`:
    - fields `Order, Document, Member, Line, Attribute, Text`; filter `Document, Member, Text`; sort `Order, Document`, default `Order` asc; paging `cap`;
    - criteria: `text` (text, 256), `scope` (choice `all, classes, routines`, default `all`), `case` (choice `yes, no`, default `no`).
  - Table: `Document` name, `Member` identifier, `Line` number, `Text` text.
  - Context `Document, Member, Line, Text`; `classicPage` `""`; `toolIdentifier` `explorer.search`; aliases `search code`, `find in files`.
- [ ] `src/OcuPilot/Screen/Descriptor/ExplorerMacro.cls` (new) -- the Macros screen.
  - Route `system-explorer/macros`, position 5, `list (server criteria)`; entity `routine`.
  - Read endpoint `Macro`: fields `Macro, Document, Line, Definition`; criteria `document` (text, 256) and `macro` (text, 128).
  - Table: `Macro` name, `Document` identifier, `Line` number, `Definition` text.
  - Context `Macro, Document, Line, Definition`; `classicPage` `""`; `toolIdentifier` `explorer.macro`; aliases `macro`, `macro definition`.
- [ ] `src/OcuPilot/Screen/Descriptor/ExplorerCompare.cls` (new) -- the Compare screen.
  - Route `system-explorer/compare`, position 4, `form-page`, no read; entity `class`, secondary `routine`; `id` `none`.
  - Context `{fields: [], secretFields: []}`; `classicPage` `%CSP.UI.Portal.RoutineCompare`; `toolIdentifier` `explorer.compare`; aliases `compare`, `diff`.
- [ ] `src/OcuPilot/Test/AtelierPortSearch.cls` (new) -- the port legs of the search rows.
  - Live, on `USER` probes `OcuProbe194*` that it creates and removes: the row shapes, case, scope, metacharacters, and a cap of 2 with `Screen.Read` reporting `truncated`.
  - Through the fixture (new canned `Search`): the exact parameters sent, the validation refusals before any call, and the version gate.
- [ ] `src/OcuPilot/Test/AtelierPortMacro.cls` (new) -- the port legs of the macro rows.
  - Live, on probe include, class, subclass and routine: each context case, unknown, `$$$`, absent document unlogged.
  - Through the fixture (new canned `GetMacroDefinition` and `GetMacroLocation`): the body sent and the version gate.
  - `MacroContext` unit cases for both list forms and a comment banner.
- [ ] `src/OcuPilot/Test/ExplorerFind.cls` (new) -- over HTTP, `/screens/ExplorerSearch/read` and `/screens/ExplorerMacro/read`.
  - Each tool through dispatch: rows only, `Text` past 1,000 characters marked in `truncatedFields`.
  - Both screens' arrival criteria accepted by navigation dispatch.
- [ ] `src/OcuPilot/Test/AtelierPortDenial.cls` -- add search and macro legs: refused without `%Development`, and without the namespace's READ.
- [ ] `src/OcuPilot/Test/InjectionChannels.cls` and `InjectionSeed.cls` -- add source (i): a probe class whose comment line carries the seed, read through `explorer.search.read`'s `Text`.
- [ ] Rosters (Design Notes › Rosters): update each literal the change trips.
- [ ] `ui/src/app/areas/system-explorer/line-diff.ts` (new, framework-free).
  - `lineDiff(left, right, maxEdits = 1000)`: trim the common head and tail, then Myers on the middle.
  - Answers `{kind: 'same'|'removed'|'added', left?, right?, text}[]`, or `null` above `maxEdits`.
  - `hunks(ops, context = 3)` collapses unchanged runs.
- [ ] `ui/src/app/areas/system-explorer/code-search.store.ts` and `code-search.page.ts` (new).
  - The criteria form from the declared criteria. No read until Search is pressed with text, or until a `ScreenArrivals` arrival, which runs once.
  - Results as a page-owned table. The Document link goes to the class viewer for `.cls`, else to the routine viewer, through `entityUrl`; the location reads `Member+Line` or `[Attribute]`.
  - A cap notice when `truncated`. The last search is re-run on a `class` or `routine` change event in the page's namespace.
- [ ] `ui/src/app/areas/system-explorer/macro-lookup.store.ts` and `macro-lookup.page.ts` (new).
  - Fields for document and macro, prefilled from `?document=`, plus arrivals.
  - The definition on `.ocu-source-text`, and "Defined in" linking the routine viewer for the location document.
  - The empty-state sentence for zero rows.
- [ ] `ui/src/app/areas/system-explorer/code-compare.store.ts` and `code-compare.page.ts` (new).
  - Per side, a namespace select from the shell's namespace list and a document name (prefill `?left=`). The kind comes from the extension.
  - Compare issues both reads with `createSourceRead` (`udl`) and each side's `scope`, then renders `hunks(lineDiff(...))` (Design Notes › Diff).
  - A re-compare runs on a change event naming either side.
- [ ] `ui/src/app/areas/system-explorer/document-viewer.page.ts` -- beside "Edit source", add "Compare with…" (`system-explorer/compare?ns=&left=`) and "Look up a macro" (`system-explorer/macros?ns=&document=`), each shown while a document is on screen.
- [ ] `ui/src/app/shell/screen-outlet.ts` -- add three `DESCRIPTOR_PAGES` entries and their imports. Regenerate `screens.generated.ts` with `node tools/screen-mirror.mjs`.
- [ ] `ui/src/styles/_components.scss` -- add `.ocu-line-diff` rules (Design Notes › Diff).
- [ ] `ui/src/app/core/strings.ts` -- add the keys, each `/** EXPERIENCE.md:594 */`, and move `:2093`'s `:634` to `:635`.
- [ ] `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md`:
  - append one Fixed-strings row after :593 for Story 19.4;
  - edit line 159 in place to read "Stories 19.1 and 19.4: Classes · Routines · Search · Compare · Macros".
- [ ] Tests (client):
  - `line-diff.spec.ts`: identical, insert, delete, replace, head and tail trim, and `null` above the bound;
  - `code-search.page.spec.ts`, `macro-lookup.page.spec.ts`, `code-compare.page.spec.ts`;
  - `ui/browser/system-explorer-find.browser-spec.mjs`, against `ocupilot-a2-ci` probes: search, then the hit link to the viewer; compare two probe documents; macro lookup;
  - client rosters: `navigation.test.mjs` :249-266, `navigation-wire.test.mjs` :528-602, `rail-wire.spec.ts` :533-730, `screen-mirror.test.mjs` `withCriteria` :1247-1270.
- [ ] `ui/angular.json` and `ui/tools/angular-json.test.mjs` -- rebase `maximumWarning` to the measured build (DW-1166). Stop and ask above 3,800 kB.

**Acceptance Criteria:**

- AC1: Given probe documents in USER holding a needle, when a person searches it across classes and routines, then each match lists with its document, member and line as the instance answers them, and its document link opens that document's viewer.
- AC2: Given more matches than the cap, when the search runs, then the vendor is asked for the cap plus one, exactly the cap is listed, and the screen says the list was cut.
- AC3: Given any search text, when it runs, then the instance is asked for a plain-text search over the declared scope only: `regex=0`, and `documents` free of caller text.
- AC4: Given two documents, in one namespace or two, when they are compared, then the browser renders their line diff from two reads through the viewers' declared read; no API route or tool is added.
- AC5: Given a macro and a document, when it is looked up, then the definition and location the instance answers in that document's include and superclass context are shown, or the not-defined sentence.
- AC6: Given the agent's tools, when they are listed, then `explorer.search.read` and `explorer.macro.read` are advertised, Compare has none, and each result is rows bounded by AD-24 with no document text. A seeded comment read through a search hit produces no proposal or navigation (AD-11 rule 5).
- AC7: Given classic parity (AD-44), when the descriptors are read, then Compare declares `%CSP.UI.Portal.RoutineCompare` and Search and Macros declare none.
- AC8: Given a `%Developer` account, when it opens the three screens in USER, then it searches and looks up there, and is refused by name where it cannot read the code database (`DeveloperFloor`).
- AC9 (Integration, Rule 1): Given a search hit and a macro location, when the person follows each link, then `SourceViewerPage` reads that document through its own declared read on the real instance.

## Spec Change Log

- 2026-10-02, lead (implement halt resolved, by=merge_gate): `ui/tools/strings.test.mjs:575-576` moves the Fixed-strings bound from 2000 to 2100, byte-identical to Epic 18's 081bbd5e on those two lines and with no comment line of this story's (a three-way merge with 18.5's file is clean and identical to it). The lead applied the edit; `npm run test:tools` 1777/1777. The implementation is committed locally as a work-in-progress commit; `baseline_revision` stays `6f718d93`.

## Review Triage Log

## Design Notes

**Measured on `ocupilot-a2-ci`, 2026-10-02.** Probe documents `OcuProbe194*` in USER and a probe port subclass in HSCUSTOM ran the shipped `Route` and `Outcome`; all were removed and checked gone.

- **Search is synchronous and cheap.**
  - Over HSCUSTOM's 10,319 non-system classes, a search that finds nothing took 1.30 to 1.58 s and about 4.0 million global references.
  - All code, classes and routines: 1.38 s. With system documents: 4.5 s. With generated documents too: 6.6 s. Whole word: 3.0 s.
  - It stops at `max`: 201 matches in 0.02 s, with the console reading "Maximum search limit reached".
  - Ten background jobs ran 400 search and macro calls under the port's capture, and none died, so no file device is needed (AD-61 rule 5).
  - The route's own console capture nests under the port's.
- **The caller's regex is unsafe.**
  - `FindInFilesRegex` builds a `%Regex.Matcher` with `OperationLimit` 0, so there is no time limit.
  - `(a+)+c` against 22 `a`s took 0.094 s, and the time quadrupled with every two characters added (inference: about 25 s at 30 characters and hours at 40).
  - With a limit set, ICU stops with #8328. The route offers no way to set one.
  - The vendor's only check is compiling the pattern, which `<REGULAR EXPRESSION>` refuses.
  - So the port sends `regex=0`. The plain-text path tests each line with `[`.
- **`documents` reaches SQL.**
  - `OcuProbe194*.mac[1=0]` found nothing, and `[1=]` answered an SQL error, where the bare mask found the probe.
  - So `documents` comes from the declared scope only. `word=1` would turn `*`, `?` and `\` into pattern wildcards, so it is not sent.
- **Macro context comes from the document's own text.**
  - `$$$OK` resolves for any `docname`, even an absent one.
  - A macro from the class's own `Include` resolves only when `includes` names it. Through a superclass it resolves only when `superclasses` names it. A routine's `#include`, and an `.inc`'s own macros, need the same.
  - `$$$Name` answers nothing. An unknown macro answers `definition: []` and `{document: "", line: ""}`, both 200.
  - A multi-line macro answers one string per line. Location lines count from the include's first line.
  - A malformed `docname` answers 400 and is logged at error severity, hence the port's own check first.

**Decisions.**

- *Agent reach.* Search and Macros are declared reads, so AD-5 and AD-8 make each an advertised read tool. This is settled by the spine, not a product call.
  - `Text` and `Definition` reach the model the way Story 19.1's `explorer.class.read` `Description` does: a row field, bounded and sanitized. AD-11 rule 5's seeded test gains source (i).
  - Compare has no read of its own, so the agent has no compare.
- *Classic pages (AD-44), each read on slot A and in `irissys/`:*
  - `%CSP.UI.Portal.RoutineCompare` declares `RESOURCE = "%Development:USE"` and normalizes from its `CSPURL`.
  - No classic page looks up a macro: no `%CSP.UI.*` or `%cspapp.exp.*` class does.
  - Search is new capability. The legacy find and replace page, `%cspapp.exp.utilexpfindreplace`, is a Hidden stub with no source on the instance and no `SECURITYRESOURCE`. It also replaces text. Its only launcher, `%CSP.UI.System.FindPane`, is hosted by no page, so it is not declared (decision for the spec gate).
- *No new error code.* Refusals are `PORT.*` with new port reasons.

**ADs.** AD-5, AD-7, AD-8, AD-11, AD-13, AD-14, AD-19, AD-21, AD-24, AD-29, AD-36, AD-39, AD-44, AD-60, AD-61.

**Spine amendments for the spec gate (draft).**

- **AD-61:**
  - rule 2: search and the two macro routes need version 2;
  - rule 3: the macro body is built from the declared document and macro and the include, import and superclass names in the document's own text, read through `GetDoc`;
  - rule 7: search's `regex` is always 0 and `word` and `wild` are never sent (a caller's regex runs with no time limit, measured), and `documents` comes from the declared scope alone (its bracketed part is spliced into SQL, measured);
  - rule 8: a search reads every document in scope until `max` (HSCUSTOM's classes: 1.3 s and 4.0 million global references), and allocates `^CacheTemp` as `docnames` does.
- **AD-7, the routine index shape:** "`docnames` and the search route" (inference: both reach `StudioOpenDialogExecute`).
- **AD-36:** a row may carry one line of code (a search match, a macro's definition). It is untrusted content bounded by AD-24's per-field cut and passed through AD-60 like any row value. A document's whole text stays the screen-only `document`.

**Diff.**

- `line-diff.ts` is the project's own Myers O(ND) after a head and tail trim. Its trace is O(D²) at D ≤ 1,000 (about one million integers), about 150 lines and about 3 kB minified (inference). No library, so Rule 5's ask does not arise.
- DESIGN.md has no code-diff component. Lines draw on `--ocu-surface` in code type:
  - removed: `--ocu-destructive-container` behind `--ocu-on-destructive-container` (12.8:1 light, 7.2:1 dark);
  - added: `--ocu-success-container` behind `--ocu-on-surface` (14.3:1 light);
  - the `−`/`+` sign in `--ocu-destructive`/`--ocu-success` (at least 5.1:1);
  - a visually hidden "removed"/"added" per line.
  - The light theme's role colors on the code surface measure about 2.4:1, so the diff is not drawn there (computed).
- The bundle grows by about 30 to 45 kB (inference); the implement stage measures it.

**Strings** (one row, :594):

- Labels: "Search", "Compare", "Macros", "Text", "Look in", "Classes and routines", "Classes", "Routines", "Match case", "Document", "Member", "Line", "Match", "Macro", "Definition".
- Compare: "First document", "Second document", "Namespace", "Compare with…", "Look up a macro", "Defined in <document>, line <n>".
- Results: "The two documents are identical.", "<n> lines removed · <m> lines added", "<n> unchanged lines", "removed", "added", "These documents differ in more than 1,000 lines, so they are not compared line by line.".
- Empty states: "Nothing in this namespace matches that text.", "Enter text to find in this namespace's classes and routines.", "<macro> is not defined where <document> can see it.".
- Port reasons: "Name the text to search for: 1 to 256 characters, with no control character.", "scope must be all, classes or routines.", "case must be yes or no.", "Name a class or routine as the macro's context, and a macro, as Name or $$$Name.".
- Prompts:
  - Search: "Which classes in this namespace call ##class(%File)?", "Where does this namespace's code mention TODO?", "Which routines mention ^ERRORS?".
  - Compare: "Which classes changed in the last day?", "Which routines changed in the last day?", "Which documents in this namespace mention TODO?".
  - Macros: "What does $$$ISERR expand to?", "Where is $$$OK defined?", "What does $$$ThrowOnError do?".

**Rosters a 19.4 change trips** (verify each at implement):

- `ExplorerDescriptor`: `DESCRIPTORS`, the listed-screen literal :29, the read loop :38-50, the tool literal :131, and the reads-count method name.
- `ReadTool`: :93 count 210→212, :94 names, :112 pairs, :368 criteria count 19→21.
- `SurfaceCoverage`: three screen rows after :155.
- `Descriptor`: two `ReadShapes` rows after :136.
- `ToolRoundTrip` `REFUSEEMPTY` :57: both reads, `PORT.VALIDATION`.
- `DeveloperFloor`: `SCREENS` +3, `TOOLS` +2, the reads list :236, and "Twelve"→"Fourteen".
- `CriteriaCorpus`, if its corpus is per criterion.
- Client: the four files in Tasks.

**Consumes:** 19.1's viewers' declared reads, `createSourceRead`, `entityUrl`, `ScreenArrivals`, `ChangeBus`, and the port's gate, `Route` and `Outcome`. **Consumed-by:** none planned.

**Footprint (Rule 11).** Checked 2026-10-02 against `.worktrees/epic-18` at `35c0ca331070fcd99247a05ac2dff3fe0ab30299`. Its uncommitted files include the spine and `Test/Navigation.cls`.

- **Contended, add-only:**
  - `SurfaceCoverage` and `Descriptor` (rows at the same spots as Epic 18's, unioned at merge);
  - `screen-outlet.ts`;
  - EXPERIENCE.md (a row after :593 and line 159 in place; Epic 18 edits 164, 173 and 378 in place);
  - `navigation.test.mjs`, `navigation-wire.test.mjs`, `rail-wire.spec.ts` (System Explorer lines Epic 18 does not touch);
  - `screens.generated.ts` (regenerated).
- **Contended, not add-only (lead approval):**
  - `ReadTool` :93/:94/:368 and `ToolRoundTrip` :57 (the same lines as Epic 18);
  - `strings.ts` (keys at the block end, where Epic 18 also appends, plus the :2093 citation);
  - `angular.json` and `angular-json.test.mjs` (Epic 18 sets 2495kB);
  - the spine.
- **Not contended:** everything else, including `AtelierPort.cls`, `ExplorerDescriptor`, `DeveloperFloor*`, `Atelier*` tests and the injection tests.
- Re-check `git -C …/epic-18 diff` and `status -s` at edit time.

## Verification

Load source into `ocupilot-a2-ci` and never restart it:

1. `rsync -a --delete /Users/jbrandt/git/OcuPilot/.worktrees/epic-19/src/ /tmp/ocupilot-a2-ci/src/`
2. In `docker exec -i ocupilot-a2-ci iris session iris -U HSCUSTOM`, run `$System.OBJ.LoadDir("/opt/ocupilot/src","ck",.tErrors,1)`, then check the status and `tErrors`.

**Run one test-runner call at a time, and wait for each.** Never re-submit after a client-side timeout. Every `OcuProbe194*` document is removed.

**Commands:**

- `uv run scripts/check-objectscript.py && uv run scripts/test_check_objectscript.py` (loop) -- expected: green.
- `cd ui && node tools/ci-runner.mjs --container ocupilot-a2-ci --class OcuPilot.Test.<Class>` (loop), one class per call -- expected: green. Run it for:
  - `AtelierPortSearch`, `AtelierPortMacro`, `ExplorerFind`, `AtelierPortDenial`, `AtelierPort`, `AtelierPortDocument`, `ExplorerDescriptor`, `ExplorerWire`;
  - `ReadTool`, `ToolRoundTrip`, `SurfaceCoverage`, `Descriptor`, `DeveloperFloor`, `InjectionChannels`, `CriteriaCorpus`.
- `cd ui && npm run test:tools && npx ng test --include 'src/app/areas/system-explorer/**/*.spec.ts'` (loop) -- expected: green.
- Browser (loop). Build and deploy first: `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-a2-ci:/durable/iris/csp/ocupilot/`. Then run each file alone with `OCUPILOT_BROWSER_ORIGIN=http://localhost:52780 OCUPILOT_BROWSER_CONTAINER=ocupilot-a2-ci node --test --test-concurrency=1 browser/<file>`, for `system-explorer-find.browser-spec.mjs`, `system-explorer.browser-spec.mjs` and `a11y-structural-invariants.browser-spec.mjs` -- expected: green. The full browser suite is CI's.
- `bash scripts/lint-docs.sh && cd ui && npm run test:tools` (loop, after the EXPERIENCE.md edit) -- expected: green.
- `cd ui && npm test` (once, before dev_complete) -- expected: green, with the budget rebased.
- `cd ui && node tools/ci-runner.mjs --container ocupilot-a2-ci`, the full ObjectScript sweep, one class at a time (once, before dev_complete) -- expected: green apart from `WireSecurityRead`'s known task-history residue.

**Planned mutations (Rule 19)**, one per AC; record each as `mutation: <change> → <test that reddened>`:

- AC1: `SearchRows` drops `Member` → `AtelierPortSearch` row-shape leg.
- AC2: `SearchRows` sends `max` as `maxRows` − 1 → `AtelierPortSearch` cap leg (three matches, cap 2, `truncated` false).
- AC3: `regex` sent as 1 → the metacharacter leg; `documents` built from `text` → the fixture parameter leg.
- AC4: `lineDiff` stops trimming the common tail → `line-diff.spec.ts` tail case.
- AC5: `MacroContext` drops `Extends` → `AtelierPortMacro` superclass leg.
- AC6: `Kernel/Agent/Bound.Apply`'s per-field cut skipped → `ExplorerFind` bound leg.
- AC7: `ExplorerCompare` `classicPage` `""` → `ExplorerDescriptor`.
- AC8: `ExplorerSearch` privileges dropped → `DeveloperFloor` and the `AtelierPortDenial` search leg.
- AC9: the hit link always routing to the class viewer, rebuilt and redeployed → `system-explorer-find` routine-hit leg.


**Mutations observed (Rule 19)**, each reverted byte for byte and recompiled or rebuilt:

- mutation: AC1, `SearchRows` drops `Member` → `AtelierPortSearch.TestSearchRowsCarryTheInstancesShapes` and `TestTheSearchSendsExactlyItsParameters` (run 2359).
- mutation: AC2, `SearchRows` sends `max` as `maxRows` − 1 → `AtelierPortSearch.TestTheCapIsReportedThroughTheRead` and `TestTheSearchSendsExactlyItsParameters` (run 2360).
- mutation: AC3, `regex` sent as 1 → `AtelierPortSearch.TestAMetacharacterIsText`, with four other legs (run 2362); `documents` given the text → `AtelierPortSearch.TestTheSearchSendsExactlyItsParameters` (run 2363).
- mutation: AC4, `lineDiff` stops trimming the common tail → `line-diff.spec.ts` "keeps the shared head and tail".
- mutation: AC5, `MacroContext` drops `Extends` → `AtelierPortMacro.TestAMacroIsFoundThroughASuperclass`, `TestBothMacroRoutesAreSentTheBodyTheTextGives` and `TestMacroContextReadsTheDocumentsOwnText` (run 2364).
- mutation: AC6, `Kernel/Agent/Bound.Apply`'s per-field cut skipped → `ExplorerFind.TestTheReadToolsAnswerBoundedRowsAlone` (run 2365).
- mutation: AC7, `ExplorerCompare` `classicPage` `""` → `ExplorerDescriptor.TestCompareKeysTheClassicCompareRoutinesPage` (run 2366).
- mutation: AC8, `ExplorerSearch` privileges `[]` → `AtelierPortDenial.TestSearchAndMacrosAreRefusedNamingThePair` (run 2367) and `DeveloperFloor.TestEveryOpenScreenMatchesItsClassicPage` (run 2369).
- mutation: AC9, `viewerRouteFor` answers the class viewer for every hit, rebuilt and redeployed → `system-explorer-find` AC1/AC9 and AC5/AC9 tests.

## Auto Run Result

Status: blocked
Blocking condition: contended edit needs lead approval: `ui/tools/strings.test.mjs:575-576`. This story's Fixed-strings row takes the table to 2032 distinct literals against the bound of 2000 (`npm run test:tools`: 1 of 1,777 red), and Epic 18's 081bbd5e (Story 18.5) changes the same two assertion lines from 2000 to 2100. The 19.1 approval covered disjoint hunks only.

- Plan (2026-10-02): search, macro and capture behavior measured on `ocupilot-a2-ci` (Design Notes), every `OcuProbe194*` document, the probe port class and its global removed and checked gone; the classic pages read on slot A and in `irissys/`; no diff library needed; ledger inbox empty.
- For the spec gate: the drafted AD-61, AD-7 and AD-36 amendments; Search declaring no classic page; the contended non-additive edits (`ReadTool`, `ToolRoundTrip`, `strings.ts`, the budget, the spine).
- Implement (2026-10-02, baseline `6f718d934244b6f45b511e5cb72f1d15038bac7e`, all work uncommitted in the tree): every task is implemented. The story's 14 ObjectScript classes are green on `ocupilot-a2-ci`, one per call. Their latest runs, 2350-2358 and 2370-2375, were read back from `%UnitTest_Result`; the red runs 2359-2369 are the recorded mutations. Also green: `ng test` (162 files) and the three browser specs (bundle 2,525,385 bytes, warning re-based to 2526kB); every AC's `mutation:` line is recorded. `check-objectscript` passes, the `%Atelier` literal is absent, and no probe documents or principals are left. Not run yet: the full ObjectScript sweep, the step-04 review layers and the Matrix Test Audit.
- Recommended resolution: change only those two lines from 2000 to 2100, byte-identical to 18.5's, with no comment line of this story's. A three-way `git merge-file` of that edit against 18.5's file gave 0 conflicts and a result identical to 18.5's file. The two stories together add at most 2072 literals, which fits under 2100. Keep the baseline above when re-dispatching, so the review diff covers the whole story.
