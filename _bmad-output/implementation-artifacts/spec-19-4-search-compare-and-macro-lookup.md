---
title: 'Story 19.4: Search, compare and macro lookup'
type: 'feature'
created: '2026-10-02'
status: 'done'
baseline_revision: '6f718d934244b6f45b511e5cb72f1d15038bac7e'
baseline_commit: '8c085caf0744609c41d3d6018fdcb99e7799bbab'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-19-context.md'
warnings: ['multiple-goals', 'oversized']
deferred:
  - summary: >-
      Screen/Tool/Read.AddCriteria describes every text criterion as a comma-separated name list where * matches, which misdescribes Search's text and Macros' document and macro to the model.
    evidence: |-
      Occurrence of DW-1001 (owner range-end-cleanup). The three are required free text or one name: an omitted or malformed value is refused PORT.VALIDATION with a reason, but a * in text is searched literally and answers no rows with no refusal. No test pins the descriptions. Not fixed here: the fix DW-1001 names is a descriptor-declared criterion description, which needs the criteria grammar in Screen/Registry.cls (this story may not edit it) and the screen mirror; a port-supplied hint would be a second source for the tool schema beside the descriptor (AD-5).
    location: >-
      src/OcuPilot/Screen/Tool/Read.cls:171
    severity: medium
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

- [x] [CI] Run 37080963199 (head ddf5c5a3) red, browser shard 2/3: `ui/browser/definitions.browser-spec.mjs:445` expects the command box's screens for `Definition` to be exactly `['Definitions']` and gets `['Macros','Definitions']` (Macros' alias `macro definition`). Ruling: Macros legitimately matches; the assertion becomes "Definitions is offered and the Definition form is not". Check every other command-box spec for an exact offered list the new screens widen. Prove on `ocupilot-a2-ci` with a rebuilt bundle.

- [x] [Follow-up] DW-1962 (by=merge_gate): `Definition` + Enter in the command box opens Macros (alias `macro definition`) instead of Definitions. Rank `command-box.ts` screen rows: exact label, label prefix, other label match, then alias-only; favorites first among equal ranks; declaration order last. Keep the alias. Tests: the command box's component spec (with a ranking mutation), definitions spec asserts Definitions first; every command-box spec reading the first row re-run on a rebuilt bundle.

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

### Review Findings

Code review 2026-10-02 (four layers, full-opus): 58 rows, 18 entries (high 0, medium 2, low 16), 25 rejected. No AD violation; AC1-AC9 hold, Rule 3 met.

- [x] [Review][Patch] (med) Compare diffed a side the instance keeps no source for as empty text: two object-only routines read identical [ui/src/app/areas/system-explorer/code-compare.page.ts:216]
- [x] [Review][Patch] Search labeled a match in a member's attribute `Member+attrline`, as a line of its code; now `Member[Attribute]` [ui/src/app/areas/system-explorer/code-search.store.ts:77]
- [x] [Review][Patch] An arrival omitting a criterion left the earlier search or lookup in effect (Search with no text; Macros keeping the old document or macro) [code-search.store.ts:159, macro-lookup.store.ts:120]
- [x] [Review][Patch] Macros re-read the earlier lookup beside a `?document=` naming another document [ui/src/app/areas/system-explorer/macro-lookup.page.ts:150]
- [x] [Review][Patch] Search's cap notice stayed above a refused search [ui/src/app/areas/system-explorer/code-search.page.ts:302]
- [x] [Review][Patch] `hunks` collapsed a single unchanged line into a "1 unchanged lines" marker [ui/src/app/areas/system-explorer/line-diff.ts:161]
- [x] [Review][Patch] A change event's re-compare blanked the drawn diff until the re-read landed (AD-14) [ui/src/app/areas/system-explorer/code-compare.store.ts:111]
- [x] [Review][Patch] No test held Compare's overtaken-answer guard [code-compare.page.spec.ts, "Compare state"]
- [x] [Review][Patch] No test held a routine side's re-compare on a `routine` change [code-compare.page.spec.ts]
- [x] [Review][Patch] The four new port refusals were outside the server/client/EXPERIENCE parity roster [ui/tools/self-protection.test.mjs]
- [x] [Review][Patch] No test held that 256 characters, the bound, are searched [src/OcuPilot/Test/AtelierPortSearch.cls]
- [x] [Review][Patch] No test held `MacroContext`'s 50-name cap [src/OcuPilot/Test/AtelierPortMacro.cls]
- [x] [Review][Patch] The viewer's "Compare with" and "Look up a macro" had no browser leg [ui/browser/system-explorer-find.browser-spec.mjs]
- [x] [Review][Patch] `ExplorerFindProbe.Make`'s doc named the include as compiled; a garbled sentence in `AtelierPortSearch` [src/OcuPilot/Test/ExplorerFindProbe.cls:38]
- [x] [Review][Defer] (med) DW-1001 occurrence: `explorer.search.read` is the first silent case, `*TODO*` or a comma list searched literally with no refusal [src/OcuPilot/Screen/Tool/Read.cls:171] — deferred: the implement stage's reason holds (Registry grammar, Never list); trailer added, priority raised, owner range-end-cleanup
- [x] [Review][Defer] `MacroContext` misses a mid-line `/*` and a one-line `/* */ Include X`, and counts a routine's `#include` in `/* */` or `#if 0` [src/OcuPilot/Port/AtelierPort.cls:1060] — deferred: DW-1961 wontfix-accepted
- [x] [Review][Defer] `MACRONAMEPATTERN` refuses 54 of the image's 28,574 macro names (underscore, leading digit) [src/OcuPilot/Port/AtelierPort.cls:126] — deferred: DW-1960 by-design (the Matrix's pattern)

Rejected: screen context lacks `Attribute` (spec's context fields; the tool row carries it) · `IncludeGenerator` sent as `includes` (generator methods see those macros; the body is AD-61 rule 3's) · "Defined in X, line " with no line (no case shown where the instance names a document without a line) · Compare's prompts and empty context (closed in the triage log; AC6) · "1 lines" plurals (spec strings) · Compare pressed with a blank side sends nothing (as Search and Macros do) · location column header, cut match line, no line anchor, no result count, per-visit Compare state (features, or the viewer's precedent) · Macros not re-run on a class edit (spec: entity `routine`) · a failed location route fails the read (fails loudly; no reachable case) · strings bound with no comment (the lead's byte-identical edit) · probe classes share a package (needs two runs at once, which the one-run rule forbids) · Search/Macros duplication and the `hits` getter (no named defect; bounded) · one line-number column (layout change, low) · search timeout (false: AD-61 rule 8 measured) · per-clause mutation lines (closed; one per AC) · 1,000-edit time cost (needs ~50k-line documents; fix adds a worker) · DESIGN.md "reserved" sentence (scoped to Release 1, still true) and the 14.3:1 figure (spec edit) · client rosters untouched and QA leg uncommitted (no defect; the lead commits).

Code review 2026-10-02 (CI rework re-review, four layers, full-opus, diff from `69afc567`): 13 entries (high 0, medium 0, low 2), 11 rejected. The `[CI]` checklist holds: both recorded mutations match `screenCandidates`, and the sweep is complete (probed over the real mirror).

- [x] [Review][Patch] Test 5 identified the form only by a label key it shares with Macros, so a relabeled form offered in the box passed; now also absent by route-derived row id, with the list's row anchoring the id scheme [ui/browser/definitions.browser-spec.mjs:456]
- [x] [Review][Patch] The file header's claim 3 said the side bar lists Definitions alone [ui/browser/definitions.browser-spec.mjs:12]

Rejected: Enter on `Definition` now opens Macros (low, real; rows keep declaration order, favorites first, Story 15.2; outside the rework range and not high) · header "Eight claims" against ten tests (pre-existing, outside the range) · the new comment narrates the change (false: it states why membership) · triage-log labels, the acted-on `[reject]` row, the log's `baseline_revision`, two dates for one rework, "alone" in Rework 1, rework narrative in an oversized spec (each fix edits the spec or the lead's log) · the sweep omits Enter's first-row dependency (false: no new label, route or alias contains `web apps` or `sign out`) · `a11y-structural-invariants` unreported locally (outside the range; CI's browser shards run it, Rule 29).

## Spec Change Log

- 2026-10-03, lead (rework 2, orchestrator follow-up): re-opened for the `[Follow-up]` item under Tasks & Acceptance (DW-1962, command-box ranking).

- 2026-10-03, lead (CI rework 1): re-opened for the `[CI]` item under Tasks & Acceptance (run 37080963199, `definitions.browser-spec.mjs` test 5).

- 2026-10-02, lead (implement halt resolved, by=merge_gate): `ui/tools/strings.test.mjs:575-576` moves the Fixed-strings bound from 2000 to 2100, byte-identical to Epic 18's 081bbd5e on those two lines and with no comment line of this story's (a three-way merge with 18.5's file is clean and identical to it). The lead applied the edit; `npm run test:tools` 1777/1777. The implementation is committed locally as a work-in-progress commit; `baseline_revision` stays `6f718d93`.

## Review Triage Log

### 2026-10-02 — Review pass

- verdicts: 14 findings — high 0, medium 5, low 5, false 4, maybe-false 0
- findings:
  - `[medium]` `[defer]` No test pins what `explorer.search.read` and `explorer.macro.read` tell the model about `text`, `document` and `macro` — grouped with the two description findings below; deferred with its reason (DW-1001 occurrence).
  - `[low]` `[patch]` Compare's re-compare was verified only for the second document — `code-compare.page.spec.ts` now also publishes an unrelated class (no read) and the first document (re-compare); the "only the right side" mutation reddens it.
  - `[false]` `[reject]` Rule 19 clauses without their own `mutation:` line — each of the nine ACs has its line; Rule 19 asks one per AC, not per clause.
  - `[medium]` `[defer]` The two tools' criterion descriptions contradict the port (required, not a name list; `*` literal) — same root cause as the first row: `AddCriteria`'s one text description, DW-1001; the descriptor-declared fix needs `Screen/Registry.cls`.
  - `[medium]` `[patch]` Search and Macros never show the instance's reason for a refusal — both stores now keep the refused answer's reason and the refusal strip shows it, falling back to the generic sentence; two page-spec cases pin it.
  - `[low]` `[patch]` A change event re-comparing overwrote the names the person was typing — `recompare` now reads the compared sides without touching the form; a page-spec case pins it and reddens under the old overwrite.
  - `[medium]` `[defer]` The advertised schema (`required: []`, name-list descriptions) diverges from the port — same root cause as the first row.
  - `[low]` `[reject]` Each derived read tool's own description is generic ("Read the rows the explorer.search screen lists") — the shared description of every derived read, unchanged here; a product-wide change for no user-met defect.
  - `[medium]` `[patch]` The matrix's "Banner" reading with the port's reason is not met on Search and Macros — same root cause and fix as the refusal-reason row above.
  - `[low]` `[reject]` Compare across two namespaces is shown in jsdom only — the per-side `scope` is asserted there and the browser spec covers the same read path in USER; a second-namespace browser leg would need probes in two namespaces for no reachable defect.
  - `[false]` `[reject]` `Definition` is not shown cut or wrapped — `Kernel/Agent/Bound.Apply` cuts every string field of every row whatever its name, and AD-60 wraps the whole block; `Text`'s test exercises that path for this read.
  - `[false]` `[reject]` `max` defaults to 200 when no cap is named — the spec's Tasks state it (`max` is `maxRows`, else 200).
  - `[low]` `[reject]` Compare's prompts lead the agent to other reads — the prompts are the spec's Design Notes › Strings, and the agent has no compare by design (AC6).
  - `[false]` `[reject]` The spec's run-result section still said `Status: blocked` — finalize rewrites that section; nothing in code.

### 2026-10-02 — Review pass (CI rework 1)

- verdicts: 4 findings — high 0, medium 0, low 1, false 3, maybe-false 0
- findings:
  - `[low]` `[reject]` The `[CI]` item's sweep of the other command-box specs had no recorded outcome, and `## Auto Run Result` still described the earlier pass — the fix is an edit to this spec; finalize records the sweep under Rework 1.
  - `[false]` `[reject]` The alias `macro definition` could have been narrowed instead of the assertion — the lead's ruling on the `[CI]` item keeps the alias (a person looks up a macro's definition on Macros); Macros being offered for `Definition` is intended.
  - `[false]` `[reject]` Membership no longer catches any other screen offered for `Definition` — the test's claim is only that the list is offered and the form is not; both recorded mutations redden it, and other areas' screens are not its subject.
  - `[false]` `[reject]` `macro-lookup.page.ts:101` labels the definition block with the Agent area's `agentDefinitionFormLabel` — `strings.ts` keeps one key per value, so an identical literal renders its existing key; the block reads "Definition" as intended, and the line predates this pass.

### 2026-10-02 — Review pass (rework 2)

- verdicts: 10 findings — high 0, medium 0, low 5, false 5, maybe-false 0
- findings:
  - `[low]` `[patch]` Nothing pins that Macros' shipped alias still reaches it for `Definition`: the component cases use a stub roster and test 5 asserted only Definitions — test 5 now also asserts Macros is offered after Definitions; removing `macro definition` from the mirror reddens it alone.
  - `[low]` `[reject]` The follow-up's mutations have no `mutation:` line in `## Verification` — the fix edits this spec; finalize records them (Rule 19), the favorite-key ones marked as the handoff's.
  - `[low]` `[reject]` Test 5's `aria-activedescendant` assertion was never red alone — the pinning assertion is `offered[0]`, which reddened; the active row is the first row by the box's existing contract, and isolating it needs a contrived mutation of unchanged code.
  - `[false]` `[reject]` The re-run of the command-box specs that read the first row has no evidence — the stage ran seven files on the clean bundle, recorded under Rework 2.
  - `[false]` `[reject]` `labelRank` ranks a route-only match with alias-only ones, where the item names alias-only — a route-only match is not a label match, so it ranks after every label match as the item requires; no row is dropped.
  - `[false]` `[reject]` With text typed, a favorite no longer leads the whole Screens group (Story 15.2) — the item keeps favorites first among equal ranks, by the orchestrator's ruling.
  - `[false]` `[reject]` Story 15.2's older cases pass under both orders, so nothing separates rank from favorites — "Story 15.2 within a rank" does: favorites sorted ahead of rank, and the favorite key dropped, each redden it.
  - `[low]` `[reject]` The ranking rule is stated in no planning document — the class comment states it and three component cases pin it; EXPERIENCE.md states no order for the box at all, and adding one edits a planning document Epic 18 has uncommitted edits in, for no defect a user meets.
  - `[low]` `[reject]` The component cases use a stub roster, with no route-only match beside an alias-only one — the two share a rank by design, so their order is the favorites-then-declaration tie-break "Story 15.2 within a rank" already pins; the shipped roster is covered by test 5 and the seven-file sweep.
  - `[false]` `[reject]` Whether the first-row specs were re-run on a rebuilt bundle is unknown — same as the re-run row above.

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
- (QA) `ui/browser/system-explorer-find.browser-spec.mjs` -- two added legs: Compare identical and refused side, Macros empty state.
- mutation: Compare's identical status sentence replaced, rebuilt and redeployed -> `system-explorer-find` "AC4 (QA)" went red; Macros' empty sentence given no document -> "AC5 (QA)" went red; both reverted byte for byte.
- (Review) mutation: `readSide` reads an unavailable side's empty text → `code-compare.page.spec.ts` "names a side the instance keeps no source for"; the generation check dropped, and a re-compare blanking the diff → "Compare state"; a routine side matched to `class` events → "compares a routine again"; `hunks` without its spare line → `line-diff.spec.ts` "never collapses a single unchanged line"; `hitLocation` without the member-attribute case, `useArrival` keeping the sent search, the status line without its fault check → three `code-search.page.spec.ts` cases; Macros keeping an omitted document, and skipping `forget` → two `macro-lookup.page.spec.ts` cases; one word of `REASONSEARCHTEXT` → `self-protection.test.mjs` Story 19.4; text bound `>=`, cap 60, whole tree recompiled → `AtelierPortSearch` (run 2809) and `AtelierPortMacro` (run 2810). Each reverted byte for byte; green after (runs 2811, 2812).
- (CI) mutation: `screenCandidates` also offers `agent/definitions/edit`, rebuilt and redeployed → `definitions` "AC5: the form is routable and listed nowhere" on the form assertion (offered `["Macros","Definition","Definitions"]`); `screenCandidates` drops `agent/definitions` → the same test on the list assertion (offered `["Macros"]`). Reverted byte for byte, clean bundle redeployed, 10/10 green.
- (Re-review) mutation: `screenCandidates` also offers `agent/definitions/edit` labeled `actionCreate`, rebuilt and redeployed → whole `definitions` file 9/10, test 5 alone red on "and no row opens the form's route" (the label assertion passed). Reverted byte for byte, `main-CW3DWYXW.js` redeployed, 10/10 green.
- (Rework 2) mutation: the Screens sort drops its rank key → `command-box.spec.ts` "ranks screens by how the text meets each name", "offers Definitions before Macros" and "Story 15.2 within a rank" (3 red, 41 green); `labelRank`'s alias-only 3 made 2 → the first and third of those (2 red); the rank key dropped, rebuilt and redeployed → `definitions` test 5 alone (9/10), "Definitions is offered first: ["Macros","Definitions"]"; `macro definition` removed from the mirror, built and redeployed → test 5 alone (9/10), "Macros … still follows it: ["Definitions"]"; the favorite key dropped, and favorites sorted ahead of rank → the favorites cases red (reported by the handoff). Each reverted byte for byte; clean `main-SN6EFID5.js` redeployed.

## Auto Run Result

Status: done
Blocking condition: none

- Prior halt: closed by the lead's Fixed-strings bound edit (Spec Change Log); the work-in-progress commit `524de82d` carried the implementation.
- Summary: Search and Macros are declared reads through `AtelierPort` (`SearchRows`, `MacroRows`, `MacroContext`), each an advertised read tool; Compare is a form page that reads both sides through the viewers' declared read and diffs them with the project's own Myers diff (`line-diff.ts`). The viewer links to Compare and Macros.
- Files:
  - `src/OcuPilot/Port/AtelierPort.cls` -- the two endpoints, their validation, the macro context and the four reasons.
  - `src/OcuPilot/Screen/Descriptor/ExplorerSearch.cls`, `ExplorerMacro.cls`, `ExplorerCompare.cls` -- the three listed screens.
  - `src/OcuPilot/Test/AtelierPortSearch.cls`, `AtelierPortMacro.cls`, `ExplorerFind.cls`, `ExplorerFindProbe.cls` -- port, wire and tool legs and their probe documents; `AtelierPortDenial`, `AtelierDenialProbe`, `AtelierPortFixture`, `InjectionChannels`, `InjectionSeed` -- denial legs, canned routes and source (i); `ReadTool`, `ToolRoundTrip`, `SurfaceCoverage`, `Descriptor`, `DeveloperFloor`, `ExplorerDescriptor` -- rosters.
  - `ui/src/app/areas/system-explorer/line-diff.ts`, `code-search.*`, `macro-lookup.*`, `code-compare.*` and their specs -- the diff and the three pages; `document-viewer.page.ts` -- the two links.
  - `ui/src/app/shell/screen-outlet.ts`, `core/screens.generated.ts`, `core/strings.ts`, `styles/_components.scss` -- page registration, mirror, strings, diff styles.
  - `ui/browser/system-explorer-find.browser-spec.mjs`, `system-explorer.browser-spec.mjs`; `ui/tools/navigation.test.mjs`, `screen-mirror.test.mjs`, `strings.test.mjs` (the lead's bound), `angular-json.test.mjs` with `ui/angular.json` -- browser legs, client rosters, budget.
  - EXPERIENCE.md -- the :594 Fixed-strings row and line 159.
- This pass: the Matrix Test Audit added a refused-read case to the Search and Macros page specs. Review patches: both pages show the instance's reason for a refused read (falling back to the generic sentence); Compare's re-compare reads the compared sides without overwriting the form; Compare's change-event case now covers the first document and an unrelated class. The budget re-based to 2527kB (measured 2,526,006 bytes).
- Review: 14 findings (medium 5, low 5, false 4). Patched 3 entries: 1 medium (refusal reason, 2 rows), 2 low. Deferred 1 entry (3 rows): the criterion descriptions, a DW-1001 occurrence (frontmatter `deferred:`). Rejected: the generic read-tool description, two-namespace browser coverage and Compare's prompts (low); per-clause mutation lines, `Definition`'s bound, the `max` default and this section's stale status (false), each with its reason in the triage log.
- Follow-up review: not recommended (no high and one medium entry patched).
- Verification: the story's 14 ObjectScript classes green one per call (runs 2376-2389); the full sweep once on `ocupilot-a2-ci`, 416 classes, 3,428 tests, 2 red, both residue of the throwaway's age, not this story: `WireSecurityRead.TestTaskHistoryPairSetsAreEnforcedForARealPrincipal` (1,583 task-history rows, DW-1554) and `Retention.TestAnEntryAgesByItsOwnDefinitionAndTheLedgerByTheLongest` (24 `_SYSTEM` conversation entries from browser-spec turns since 2026-10-01T22:56Z, older than the one-day retention the test's probe definition sets; no 19.4 test leaves an entry). `npm test` once: tools 1,777/1,777, components 2,170/2,170 in 162 files. `system-explorer-find` 3/3 after the rebuilt bundle was deployed; `lint-docs` and `check-objectscript` clean. Each new page-spec case reddened under its mutation and the tree was restored.
- Residual risk: the two new tools' criterion descriptions stay wrong until DW-1001 lands; a `*` in a model's search text answers no rows rather than a refusal.

### Rework 1 (CI run 37080963199)

Status: done
Blocking condition: none

- **Change:** `ui/browser/definitions.browser-spec.mjs` test 5 ("AC5: the form is routable and listed nowhere") asserts that the command box's offered screens for `Definition` include `STRINGS.agentDefinitionListLabel` and exclude `STRINGS.agentDefinitionFormLabel`, in place of exact equality with `['Definitions']`; a one-sentence comment says why (Macros' alias `macro definition` legitimately matches). No other line changed.
- **Sweep:** no other command-box spec holds an exact offered-screen list the new screens widen. `system-explorer` already asserts membership; `account-and-filter`, `security` and `web-applications` read one row by id or selector for needles no new screen matches; `tasks` and `command-bar.spec.ts` read the Actions group; `theme`, `panel` and `audit` type nothing; `command-box.spec.ts` uses a stub roster.
- **Review:** follow-up pass, two layers (verification-gap, intent-alignment) over the diff from `69afc567`: 4 findings, low 1 and false 3, all rejected with their reasons in the triage log; nothing patched or deferred. Follow-up review recommended: false (no `high` patched).
- **Verification:** bundle rebuilt and deployed to `ocupilot-a2-ci` (`main-CW3DWYXW.js`, the clean tree's); `definitions` 10/10, `system-explorer-find` 6/6, `system-explorer` 4/4, one file per run; `npm run test:tools` 1,779/1,779; `lint-docs` clean. The `(CI) mutation:` line in `## Verification` records both mutations reddening test 5 alone. No ObjectScript changed, so no class run or sweep (Rule 29). `baseline_revision` kept at the story baseline.

### Rework 2 (DW-1962, command-box ranking)

Status: done
Blocking condition: none

- **Change:** `command-box.ts` `screenCandidates` sorts the Screens group by `labelRank` (whole label, label prefix, elsewhere in the label, then alias or route alone), then favorites (Story 15.2), then declaration order; at an empty query every screen shares one rank. Macros keeps `macro definition`.
- **Files:** `ui/src/app/shell/command-box.ts` (rank and sort, class comment); `command-box.spec.ts` (three cases: four ranks and Enter, `Definition` and `macro` on the shipped pair, favorites within a rank); `ui/browser/definitions.browser-spec.mjs` (test 5: Definitions first, the row Enter opens, Macros still offered after it); `ui/angular.json` and `ui/tools/angular-json.test.mjs` (budget 2548kB to 2549kB, measured 2,548,187 bytes; DW-1166).
- **Footprint:** Epic 18 does not touch the command box. Its uncommitted 18.18 edits the same budget lines (2532kB); this branch already changes them, so the merge re-measures as at every forward merge.
- **Review:** follow-up pass, two layers over the diff from `8c085caf`: 10 findings (low 5, false 5). Patched 1 low (Macros' alias pinned in test 5); rejected the rest, each with its reason in the triage log; nothing deferred. Follow-up review recommended: false (no high patched).
- **Verification:** `command-box`, `command-bar` and `header` component specs 115/115; `npm run test:tools` 1,779/1,779; browser on the clean `main-SN6EFID5.js`, one file per run: `definitions` 10/10 (after the patch), `web-applications` 4/4, `account-and-filter` 4/4, `system-explorer` 4/4, `system-explorer-find` 6/6, `security` 5/5, `theme` 5/5. Mutations in `## Verification`. No ObjectScript changed (Rule 29). `baseline_revision` kept at the story baseline.
