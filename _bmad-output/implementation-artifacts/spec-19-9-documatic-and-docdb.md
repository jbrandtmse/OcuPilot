---
title: 'Story 19.9: Documatic and DocDB'
type: 'feature'
created: '2026-10-04'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-19-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-19-16-the-data-browser-export-shortcuts-go-to-row-and-tabs.md'
warnings: ['multiple-goals', 'oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** System Explorer's class viewer (Story 19.1) shows a class's source and doc comments as text, but not the instance's own class reference, which the classic Classes page shows beside its list. Separately, Data browser's Download CSV writes a negative number as `'-12.5`, which a spreadsheet reads as text (DW-2061).

**Approach:** The class viewer gains a sixth view, Class reference. It loads the instance's own Documatic page for the class in an `<iframe sandbox="">`. The frame's source is a fixed same-origin path, authenticated by the browser-level sign-in alone, so no token is involved. The frame runs no script, submits no form and has an opaque origin. Download CSV writes a number column's cell bare when its value is wholly a number; every other cell, and every other export, keeps the guard. The DocDB browser, the story's second criterion, moves to a new Story 19.17 (Design Notes › Intent gap).

## Boundaries & Constraints

**Always:**

- **The frame's source.** `classReferenceUrl(namespace, name)` builds it, a pure function: `/csp/documatic/%25CSP.Documatic.cls?PAGE=CLASS&SHOWCLASSONLY=1&LIBRARY=<ns>&CLASSNAME=<class>`.
  - Each value is `encodeURIComponent`-encoded. `<class>` is the viewer's id with a trailing `.cls` removed, ignoring case.
  - It answers `null` unless the class matches `^%?[A-Za-z][A-Za-z0-9]*(\.[A-Za-z][A-Za-z0-9]*)*$` and the namespace matches `^%?[A-Za-z0-9_-]{1,64}$`.
  - It carries no token, no credential and no other caller value.
- **The frame element.**
  - The template declares `sandbox=""` statically: no flag at all, so no `allow-same-origin`, `allow-scripts`, `allow-forms`, `allow-popups` or `allow-top-navigation`.
  - It also declares `title` (STRINGS).
  - The page sets `src` with `Renderer2.setAttribute` after the frame renders. Nothing binds `[src]` and nothing bypasses Angular's sanitizer.
- **When the frame loads.**
  - It loads only while Class reference is the active view, and only once the viewer's read has answered the document for the name and namespace on screen (`hasDocument`, so the port's gate has passed).
  - A refusal, an empty state, a gone class or a stale document shows what the viewer shows today, and no frame.
  - A routine viewer offers no Class reference view.
  - A namespace switch drops the frame. It returns once the new namespace's read answers.
- **Navigation the frame starts itself.**
  - The page counts the frame's `load` events against the loads it started.
  - On a load it did not start (a link followed inside the frame), it sets the class's `src` again. The `role="status"` line under the frame then reads "That link does not open here; the class reference shows <class> again."
  - A fragment link inside the page fires no `load` and is left alone.
- **DW-2061 (Data browser's export only).** `pageCsvText(columns, rows)` in `core/data-browser-model.ts` builds the file.
  - It uses `pageCsvRows`, with `CSV_BOM` and `csvField` imported from `core/csv.ts`.
  - A cell is written bare only when its column's kind is `number` and its text fully matches `CSV_NUMBER` = `^-?(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)(?:[eE][-+]?[0-9]+)?$` (ruled by=merge_gate).
  - Every other cell, and the header, goes through `csvField`, so it keeps the guard.
  - `exportPage` uses `pageCsvText`. `core/csv.ts` and every other export are unchanged.
- Styling uses `--ocu-*` tokens only. Inside the frame, the vendor page keeps InterSystems' own styling in both themes.

**Never:**

- A sandbox flag; an unsandboxed or `allow-same-origin` frame; a `csp` attribute on the frame (measured: it blocks the page).
- `postMessage` to or from the frame, a token or password in its URL, or a script reaching into it.
- `DomSanitizer.bypassSecurityTrust*`.
- A new descriptor, route, read, tool, port, error code or governance key. No edit to `StaticHandler.cls`'s policy.
- Server-side fetching or re-rendering of Documatic's HTML, or the Documatic frameset or index page.
- An edit to `core/csv.ts`, `shell/data-table.ts` or any other export.
- Any DocDB work in this story.

## I/O & Edge-Case Matrix

Measured on `ocupilot-a2-ci` with `_SYSTEM` and purpose-built principals (Design Notes › Measured).

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Class reference | `OcuProbe199.Doc.cls` open in USER; Class reference chosen | frame title "Class OcuProbe199.Doc"; the vendor page's text | None |
| Script in a description | the probe's description holds `<script>window.ocuprobe199=1</script>` | `ocuprobe199` undefined in the frame; reading `sessionStorage` from the frame throws `SecurityError` | None |
| Link inside the frame | follow the page's `%Library.Persistent` link | the frame shows `OcuProbe199.Doc` again; the status sentence names it | None |
| Not loaded | viewer read refused (pair named); class gone; another namespace's document still on screen | no frame; the viewer's own refusal, empty state or skeleton | Banner/empty state as today |
| Routine | `HS.HC.Info.mac` | five views, no Class reference | None |
| Namespace switch | Class reference showing, switch to HSCUSTOM | frame dropped; reloads with `LIBRARY=HSCUSTOM` after the read answers | None |
| URL shape | id `%Library.String.CLS`, ns `USER`; id `a b`; ns `x/y` | `...LIBRARY=USER&CLASSNAME=%25Library.String`; `null`; `null` | No frame for `null` |
| CSV, number column | `-12.5`, `1e-3`, `-.5`, `.5`, `1200` | written bare | None |
| CSV, guarded | `-1+1`, a lone `-`, a lone `.` and `+5` in a number column; `-12.5` and `=1+1` in a text column; NULL | `'-1+1`, `'-`, `.` as written (no guard character), `'+5`; `'-12.5`; `'=1+1`; empty | None |

</intent-contract>

## Code Map

- **Viewer page** (`ui/src/app/areas/system-explorer/document-viewer.page.ts`, 432 lines, not contended):
  - `VIEW_LABELS` :45-51 and the view buttons :112-124. The link row :125-133 is unchanged.
  - The text, structure and documentation blocks :140-170.
  - `isRoutine` :234, `hasDocument` :244, `showTable` :250, `viewControls` :289, `showDocumentation` :330, `onView` :412.
  - The scope hook `onScopeChange` → `state.forget()` :211.
- **Viewer state** (`document-viewer.store.ts`, 247 lines): `SourceViewKey` :22, `SOURCE_VIEWS` :24, `isTextView` :33, `SourceViewerState.setView` :167 (a non-text view reads nothing), `forget` :195.
- **Viewer spec** (`document-viewer.page.spec.ts`, 311 lines): "opens a class on Source ... five views" :161 (now six), Structure and Documentation :185/:200, routine :226, namespace switch :250.
- **Page archetype:** `shell/screen-outlet.ts:122` maps `'viewer (source)'` to `SourceViewerPage`. It is unchanged.
- **Policy (unchanged):** `src/OcuPilot/Api/StaticHandler.cls:350`, `default-src 'self'` with no `frame-src`, so a same-origin frame is admitted (measured: no violation).
- **DW-2061:**
  - `core/data-browser-model.ts`: `DataKind` :24, `cellView` :171-178, `pageCsvRows` :737-744.
  - `core/csv.ts`: `CSV_BOM` :15, `FORMULA_LEAD` :18 (`=+-@` TAB CR), `csvField` :27-30, `csvText` :33-35. Unchanged.
  - `areas/system-explorer/data-browser.store.ts` `exportPage` :627-639.
  - Tests: `ui/tools/data-browser-model.test.mjs:336-352` (the one export case); `data-browser-export.page.spec.ts:83-179`; `ui/tools/csv.test.mjs:55`.
- **Browser fixtures:**
  - `ui/browser/turnprobe-spec.mjs` `runIris` :52 and `markerValue` :67; `panel-spec.mjs` `signedInAt` :62.
  - Pattern to follow: `system-explorer-find.browser-spec.mjs:29-54` with `src/OcuPilot/Test/ExplorerFindProbe.cls` (`Make` :40, `MakeClass` :70, `Compile` :101, `Remove` :118).
  - The view-click helper: `system-explorer.browser-spec.mjs:114-115`.
  - The a11y walk (`a11y-structural-invariants.browser-spec.mjs`, `SOURCE_VIEWER_IDS` :87-90) opens viewers on Source, so it is unchanged.
- **Strings, styles, budgets:**
  - `core/strings.ts`: the last key :5515 and `} as const` :5516.
  - `src/styles/_components.scss`: `.ocu-source-text` :4938, `.ocu-source-note` :4957, `.ocu-source-docs` :4967; the file ends at :8487.
  - `ui/tools/strings.test.mjs:583-586` caps Fixed strings at 2,600, with 2,545 used (measured by the extractor at :48-69).
  - `ui/angular.json:54` sets `maximumWarning` 2860kB, pinned at `ui/tools/angular-json.test.mjs:497`.
- **EXPERIENCE.md** (`_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/`):
  - the viewers' Fixed-strings row :587;
  - the last Fixed-strings row :600;
  - the Download CSV paragraph :689;
  - the data table's CSV rule :667, which stays as it is.

## Tasks & Acceptance

**Execution:**

- [ ] `ui/src/app/areas/system-explorer/document-viewer.store.ts`:
  - `SourceViewKey` and `SOURCE_VIEWS` gain `reference`, last. `setView('reference')` reads nothing.
  - Add the pure `classReferenceUrl(namespace, name): string | null` (Boundaries).
- [ ] `ui/src/app/areas/system-explorer/document-viewer.page.ts`:
  - A sixth button, "Class reference", offered only when `!isRoutine`.
  - The frame block: rendered while the view is `reference`, `hasDocument` holds and the URL is non-null. The note sentence sits above the frame and the `role="status"` line below it.
  - `src` is set by `Renderer2` once per document, namespace and entry to the view.
  - The `(load)` counter restores a self-started navigation.
  - The class doc comment states the sandbox and the reasons for it.
- [ ] `ui/src/app/core/strings.ts` (end, add-only), four literals:
  - "Class reference";
  - "Class reference for <class>";
  - "This is the instance's own class reference for <class>, shown with your browser's sign-in to the instance. Links inside it do not open here.";
  - "That link does not open here; the class reference shows <class> again."
- [ ] `ui/src/styles/_components.scss` (end, add-only): `.ocu-source-reference`, a full-width frame of at least 480px, its border on tokens.
- [ ] `ui/src/app/core/data-browser-model.ts` (add-only): `CSV_NUMBER` and `pageCsvText`. `ui/src/app/areas/system-explorer/data-browser.store.ts` `exportPage` calls `pageCsvText(answer.columns, answer.rows)`.
- [ ] `src/OcuPilot/Test/DocumaticProbe.cls` (new, modeled on `ExplorerFindProbe`), with `Make(ns)` and `Remove(ns)` naming only package `OcuProbe199`:
  - `OcuProbe199.Doc` extends `%Persistent`, so its page links to `%Library.Persistent`.
  - Its description is `<script>window.ocuprobe199=1</script>OcuProbe199 class reference probe.`
- [ ] **Tests:**
  - `ui/src/app/areas/system-explorer/document-viewer.page.spec.ts`:
    - six views on a class, five on a routine;
    - no frame before `hasDocument`, on a refusal or after a namespace switch;
    - the frame's `sandbox` is `""`, its `title` is the class's, and its `src` equals `classReferenceUrl`;
    - a dispatched second `load` resets `src` and shows the status sentence;
    - the `classReferenceUrl` matrix rows.
  - `ui/tools/data-browser-model.test.mjs`: the CSV matrix rows through `pageCsvText`, and BOM, CRLF and quoting equal to `csvText` for a guarded row.
  - `ui/src/app/areas/system-explorer/data-browser-export.page.spec.ts`: a page holding `-12.5` in a number column saves it bare.
  - `ui/browser/system-explorer-documatic.browser-spec.mjs` (new): AC1-AC3 and AC6 on the throwaway, with `DocumaticProbe` made in `before` and removed in `after`.
- [ ] EXPERIENCE.md:
  - a new Fixed-strings row after :600 for the four literals (Class reference, Story 19.9), whose description names the sandbox, the restore and InterSystems' own styling;
  - :689 in place: the `'` prefix applies except to a number column's cell that is wholly a number;
  - move the citations (`npm run test:tools`).
- [ ] `ui/angular.json` with `ui/tools/angular-json.test.mjs`: re-base `maximumWarning` to the measured build (DW-1166). Stop and ask above 3,800 kB.

**Acceptance Criteria:**

- **AC1 (Integration, Rule 1: loads in place).** Given `OcuProbe199.Doc.cls` open in the class viewer in USER on the real instance, when Class reference is chosen, then a frame inside the page shows the instance's Documatic page for that class, signed in by the browser-level login alone. The frame's title reads "Class OcuProbe199.Doc", and its URL carries no token.
- **AC2 (inert).** Given the frame showing `OcuProbe199.Doc`, when the browser spec inspects its document, then:
  - its `sandbox` attribute is empty;
  - the description's script has not run (`ocuprobe199` undefined in the frame);
  - reading `window.top.sessionStorage` from the frame throws `SecurityError`, so the tab's token pair is out of the page's reach.
- **AC3 (navigation it starts).** Given the frame, when a link inside it is followed, then the frame shows `OcuProbe199.Doc` again and the status line reads the restore sentence. No sign-in page stays on screen.
- **AC4 (only after the read).** Given the class viewer, when its read is refused, answers an empty state or a gone class, still shows another namespace's document, switches namespace, or shows a routine, then:
  - a refused read, an empty state, a gone class and another namespace's document load no frame;
  - a namespace switch drops the frame and reloads it for the new namespace;
  - a routine offers no Class reference.
- **AC5 (DW-2061).** Given a page holding the CSV matrix rows, when Download CSV runs, then the number-column values matching `CSV_NUMBER` are written bare and every other value keeps the guard. `core/csv.ts`'s own exports are unchanged.
- **AC6 (accessibility).** Given Class reference showing, when it is reached by keyboard and walked by the structural invariants, then:
  - its control is a toggle button with `aria-pressed`, like the other five;
  - the frame's accessible name is "Class reference for OcuProbe199.Doc", and Tab reaches it;
  - the status line is a live region;
  - the structural walk passes on the view, wide light and wide dark.

## Spec Change Log

- 2026-10-04, lead (spec gate): the split is approved by=merge_gate (Story 19.17 `19-17-the-docdb-browser` takes criterion 2; epics.md, story_order and the tracker amended), so this story builds criterion 1 and DW-2061 only; `CSV_NUMBER` is the ruled `-?(\d+(\.\d*)?|\.\d+)([eE][-+]?\d+)?` against the whole value of a number-typed column, with `.5` bare and a lone `-`, a lone `.` and `+5` guarded where the guard applies; the sandboxed frame, its sign-in-page detection and description images fetched as the classic Documatic does are accepted; the spine carries AD-47, AD-28, the Deferred row and the capability map; EXPERIENCE.md :689 in place and the bundle re-base are approved.

## Review Triage Log

## Design Notes

**Intent gap: split (lead's call, Rule 5 ask-first).** The two criteria share no code.

- Documatic is one view on an existing page.
- DocDB is about as large as Story 19.8. It needs:
  - a new port with its own gate (AD-29, AD-52);
  - a new read source kind, which means in-place edits to the contended `Screen/Read.cls:346`, `Screen/Registry.cls:1142` and `ui/tools/screen-mirror.mjs:946`;
  - a create tool and a destructive drop tool, the drop requiring `drop` or `delete` in the contended `screen-action-handler.ts` (`DESTRUCTIVE_ACTIONS` :366);
  - a live fixture that enables `%Service_DocDB` and restores it;
  - two governance keys, whose baseline entry after 2026-10-04 is the owner's call (AD-22);
  - about fifteen roster edits.

**Recommended:** 19.9 is criterion 1 plus DW-2061 (this spec). Criterion 2 goes to a new Story `19-17-the-docdb-browser` (N.<M+1>, M = 16), with the criterion verbatim. epics.md marks 19.9's second criterion `[SPLIT to 19.17 2026-10-04]`. The 19.9 key and title stay, as Story 19.8's did.

**Second question (DW-2061's pattern).** Read literally, the ruling ("optional leading -, digits, optional decimal part") keeps `'-.5`. Yet `-.5` is how the instance answers -0.5 in ODBC mode: measured, NUMERIC and DOUBLE `-0.5` read `-.5`, and `0.25` reads `.25`. `CSV_NUMBER` therefore also admits a fraction with no integer digits. The lead confirms that reading, or strikes the `|\.[0-9]+` arm.

**Why `sandbox=""` (measured on `ocupilot-a2-ci`, 2026-10-04, headless Chrome 24.24.0, the shell's own page):**

- **Unsandboxed:** Documatic loaded under the browser-level login. A probe class's description `<script>` ran, and it read the tab's `sessionStorage`, which holds the token pair (AD-28, AD-47). Documatic passes description HTML through (`%CSP.Documatic.RenderDescription` writes non-Documatic tags verbatim).
- **`sandbox="allow-scripts"`:** the page loaded and the script ran in an opaque origin; storage access threw `SecurityError`.
- **`sandbox=""`:** the page loaded and every script was blocked. It rendered the same text as with scripts: `%Library.String`, 6,417 characters both ways.
- **The cookie:** `/api/ocupilot/login` sets `CSPBrowserId` (`path=/`, `HttpOnly`, `SameSite=Strict`). A navigation the shell starts carries it, and one the opaque frame starts does not:
  - the sandboxed frameset's inner frames and a link followed inside the frame each answered "Login IRIS";
  - the sandbox cannot submit that form.
  - Hence AC3's restore, and the class page only (`SHOWCLASSONLY=1`), never the frameset.
- **No framing refusal:** `/csp/documatic` answers no `X-Frame-Options` and no policy header.
- **The application:** `%Development` resource, `GroupById` `%ISCMgtPortal`, `AutheEnabled` 96, namespace `%SYS`.
  - A principal holding `%Development:USE` loaded the page.
  - One without it got the sign-in page. The viewer's own pair is `%Development:USE`, so that caller never reaches the view.
  - A namespace the caller cannot read answers Documatic's own `<PROTECT>` page, naming `$ROLES` and a directory. The viewer's read refuses that namespace first, hence AC4.
- **Named consequence (for the spine gate):** an image, stylesheet or font a class description names is fetched from any host. The shell's policy does not govern the vendor's document.
  - Measured: an `<img>` pointing at another host was requested.
  - The iframe `csp` attribute (embedded enforcement) blocked the whole page, because the vendor answers no opt-in.
  - The classic Documatic fetches the same thing. No token is reachable.
  - Alternative, unmeasured: render a fetched copy in `srcdoc` under a meta policy. Not recommended, because it parses vendor HTML in the client.
- **Probe residue:** during the probes the instance recorded `%System/%Security/Protect` rows for `CSPSystem`, once per sandboxed navigation without the cookie (inference).

**Spine amendments (draft, for the lead's gate):**

- **AD-47**, a new paragraph: "**A vendor page OcuPilot embeds is inert** [AMENDED 2026-10-04, Story 19.9 spec gate, Rule 20]. The class reference (Story 19.9) loads `/csp/documatic/%25CSP.Documatic.cls`'s class page, a fixed same-origin path whose only values are the namespace and the class the source viewer's read answered, in an `<iframe sandbox="">` with no flag. It runs no script, submits no form, opens nothing and has an opaque origin, so nothing in it can read the tab's storage. The shell's policy is unchanged, and its `default-src 'self'` admits the frame. Named consequences: a link followed inside the frame reaches the instance without the browser-level login and answers the sign-in page, which the page replaces with the class; and an image, stylesheet or font a class description names is fetched as the classic Documatic fetches it, because no policy of OcuPilot's governs the vendor's document. Measured on `ocupilot-a2-ci`: unsandboxed, a description's script read the tab's `sessionStorage`; sandboxed, reading it threw `SecurityError`; the iframe `csp` attribute blocked the page."
- **AD-28**, after "never posted into an embedded frame": "and never within an embedded frame's reach (AD-47). The class reference authenticates with the group's browser-id cookie alone, which the browser sends on the navigation the shell starts and not on one the sandboxed frame starts (`SameSite=Strict`, measured, Story 19.9)."
- **Deferred**, the "Embedded vendor editors and the sign-in hand-off" row, appended: "A read-only vendor page needs no hand-off: Story 19.9's class reference is AD-47's inert frame."
- **Capability map**, the Stage 3 row: add AD-47.

**Story 19.17's ground, measured here** (plan input; on `ocupilot-a2-ci`; every probe database, class and principal removed; `%Service_DocDB` restored to disabled and checked):

- **Stock state:**
  - `%Service_DocDB` is disabled (`Enabled` 0).
  - `%Developer` grants `%DocDB_Admin:U` and `%Service_DocDB:U`.
  - `%DocDB_Admin` reads "Grants access to Create and Delete Doc DB databases".
- **The vendor's REST gate** (`%Api.DocDB` `OnPreDispatch`, `%Api.DocDB.v1`, `irissys/%SYS/DOCDB.int`):
  - `CheckServiceStatus`: the service is enabled and the caller holds `%Service_DocDB:USE`.
  - `CheckAdmin`: `%DocDB_Admin:USE` or `%Admin_Secure:USE`. The list, create and drop require it.
  - The drop also requires `CheckAccess "W"`, which needs a `Security.DocDBs` record. Neither path creates one for a database made without a resource, so the REST drop of such a database answered 822 even for `_SYSTEM`. This is a candidate vendor defect.
- **In-process `%SYSTEM.DocDB`:** `GetAllDatabases`, `CreateDatabase` and `DropDatabase` check neither the service nor `%DocDB_Admin`.
  - Measured: `%All` with the service disabled, and three principals each missing one pair.
  - Create and drop need WRITE on the namespace's routines database. Without it, create raised `<PROTECT>` on `^oddDEF`, and drop raised #5883 with the database intact.
  - So the port must repeat the vendor's guard, as AD-61 repeats `%Development`.
- **`CheckServiceStatus^%SYS.DOCDB`:** public, and it raises its own roles internally (`%DB_IRISSECURITY`).
  - It answers 822 for both "disabled" and "not held".
  - Each refusal writes `%System/%Security/AccessDenied` ("Doc DB Access", EventData #800).
  - Telling disabled from not held needs the caller's own `$System.Security.Check("%Service_DocDB","USE")` first.
  - `Security.Services` needs `%Admin_Secure:USE` plus `%SYS`.
- **Names:**
  - A name must be a valid class name (#25053 for `%Foo`, `1x`, `a b`, `x.`).
  - A duplicate answers #25051, and an existing class #25070, so nothing is overwritten.
  - An unqualified name becomes `ISC.DM.<name>`; a qualified name is used as is.
  - Data globals are hashed (`^E9BC.DmNs.1`).
  - A resource requires `CheckAdmin` and a valid DocDB resource (`%DB_USER` #896).
- **Audit:** no vendor event records a create or drop with the stock event set.
- **Self-protection:**
  - OcuPilot owns no DocDB database.
  - A name resolving into the `OcuPilot` package creates or deletes OcuPilot code. `Prohibited.Code` refuses it unedited when the tools target entity type `class` with a write type other than `RUN` or `EXPORT` (`Prohibited.cls:1114-1124`, `:2035`).
- **Recommended for 19.17:**
  - `Port/DocDbPort`. Its pairs: `%Development:USE`, with own pairs `%DocDB_Admin:USE` and `%Service_DocDB:USE`, then `AtelierPort.NamespacePairs`. Create and drop add `AtelierPort.WritePairs`.
  - The service check, pinned by a test, answers 409 naming the service.
  - `explorer.docdb.create` (`CREATES` 1) and `explorer.docdb.delete` (destructive).
  - Proposed keys: create `true`, delete `false`, as the owner rules (AD-22).
  - `classicPage ""`: the classic Doc DB Applications page is the `Security.DocDBs` list (WA-11).
  - Named gaps for AD-15 and AD-53.

**Product decisions settled from the spine:**

- No descriptor, read or tool. The vendor page never passes through OcuPilot, so AD-36's and AD-24's bounds have no subject.
- The view inherits the viewer's pair, its `classicPage` (`%CSP.UI.Portal.ClassList`, whose documentation pane it replaces, AD-44) and the port's gate.
- The frame's document never reaches the model, screen context, the ledger or a log line.

**Strings and budgets.**

- Fixed strings: 2,545 + 4 = 2,549 of 2,600, so no raise here. With Epic 18's 18.7 rows (about 58) the union reaches about 2,607, so whichever epic lands second raises the bound (lead).
- The bundle crosses 2,860 kB, so it is re-based. Epic 18 has 2,885 kB on its branch, and the merge takes the larger measured value.

**ADs:** AD-5, AD-8, AD-11, AD-19, AD-20, AD-28, AD-29, AD-36, AD-39, AD-44, AD-47, AD-61.

**Integration ACs:** AC1.

**Consumes:**

- Story 19.1's class viewer: its read, `hasDocument`, the scope hook and the view toggle;
- Story 19.16's `pageCsvRows`/`exportPage`;
- the instance's `/csp/documatic`.

**Consumed-by:** No consumers in this story; Story 19.17 (DocDB) reuses nothing from it.

**Footprint (Rule 11).** Checked 2026-10-04 against `.worktrees/epic-18` at `5721393e289431584f08997d99c1c7ef4ddb3414` (committed diff and `status -s`; 18.7 in progress).

- **Contended, add-only:**
  - `core/strings.ts` (end);
  - EXPERIENCE.md's new row after :600. Epic 18 edits :165-176, :361 and :487.
- **Contended, not add-only (lead approval):**
  - EXPERIENCE.md :689;
  - `ui/angular.json` with `angular-json.test.mjs`;
  - the spine;
  - epics.md: 19.9's split marker and the new 19.17 block.
- **Not contended:**
  - `document-viewer.page.ts`, `.store.ts` and `.page.spec.ts`;
  - `_components.scss` (absent from Epic 18's diff);
  - `data-browser-model.ts`, `data-browser.store.ts`, `data-browser-model.test.mjs` and `data-browser-export.page.spec.ts`;
  - the new probe class and browser spec.
- **Not edited:** every roster test, `screens.generated.ts`, `screen-outlet.ts`, `Router.cls`, `Prohibited.cls`, `Baseline.cls`, `StaticHandler.cls` and `core/csv.ts`.

**Ledger inbox:** DW-2061 is planned as a task, pinned by AC5. Its mutation is listed below.

## Verification

Load `src/` into `ocupilot-a2-ci` and never restart it: `rsync -a --delete /Users/jbrandt/git/OcuPilot/.worktrees/epic-19/src/ /tmp/ocupilot-a2-ci/src/`, then `$System.OBJ.LoadDir("/opt/ocupilot/src","ck",.tErrors,1)` in `docker exec -i ocupilot-a2-ci iris session iris -U HSCUSTOM`.

- Run one test-runner call per message, wait for each, and never re-submit after a client-side timeout.
- Remove every `OcuProbe199*` object after the run.
- Never touch `ocupilot-ci` or `ocupilot`.

**Commands:**

- `uv run scripts/check-objectscript.py && uv run scripts/test_check_objectscript.py` (loop): expected green.
- `cd ui && npm run test:tools && npx ng test --include 'src/app/areas/system-explorer/**/*.spec.ts'` (loop): expected green.
- Browser (loop). Build and deploy first: `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-a2-ci:/durable/iris/csp/ocupilot/`. Then run each file alone with `OCUPILOT_BROWSER_ORIGIN=http://localhost:52780 OCUPILOT_BROWSER_CONTAINER=ocupilot-a2-ci node --test --test-concurrency=1 browser/<file>`, for:
  - `system-explorer-documatic.browser-spec.mjs`;
  - `system-explorer.browser-spec.mjs`;
  - `a11y-structural-invariants.browser-spec.mjs`.
  - Expected green. The full browser suite is CI's.
- `bash scripts/lint-docs.sh && cd ui && npm run test:tools` (loop, after the EXPERIENCE.md edit): expected green.
- `cd ui && npm test` (once, before dev_complete): expected green, with the budget re-based.
- `cd ui && node tools/ci-runner.mjs --container ocupilot-a2-ci`, the full ObjectScript sweep, one class at a time (once, before dev_complete): expected green apart from the known residue (the classes this throwaway is not armed for, `MappingCodeGlobals`, and `WireSecurityRead` DW-1554).

**Planned mutations (Rule 19)**, one per AC:

- AC1: `classReferenceUrl` drops `SHOWCLASSONLY=1&PAGE=CLASS` → the browser spec's AC1 leg (the frameset's inner frames sign in) red.
- AC2: the template's `sandbox=""` becomes `sandbox="allow-scripts allow-same-origin"` → the browser spec's AC2 leg and the page spec's sandbox case red.
- AC3: the `load` counter ignores self-started loads → the browser spec's AC3 leg and the page spec's reset case red.
- AC4: the frame block drops its `hasDocument` condition → the page spec's refusal and namespace cases red.
- AC5: `pageCsvText` drops its kind check → `data-browser-model.test.mjs`'s text-column `-12.5` case red.
- AC6: the frame's `title` binding is removed → the page spec's title case and the browser spec's a11y leg red.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none (the split and `CSV_NUMBER` are ruled by=merge_gate 2026-10-04)

**Plan pass.**

- **Read:** the spine in full, the epic context, Story 19.8's spec (continuity), the vendor `%Api.DocDB`, `%SYSTEM.DocDB`, `%DocDB.Database`, `%SYS.DOCDB.int` and `%CSP.Documatic` sources, and the server and client code (two read-only subagents).
- **Measured on `ocupilot-a2-ci`** (Design Notes):
  - created principals `OcuProbe199Dev`, `Nad`, `Nsv` and `Nod` with their roles, classes `OcuProbe199.Doc`, `.Exists` and `.Img`, and DocDB databases `OcuProbe199*` and `ISC.DM.Twice`;
  - enabled `%Service_DocDB` for the DocDB measurements;
  - then removed every object and principal, restored the service to disabled, and checked each gone or restored.
- **The tree:** it held only the lead's write-ahead line for this spawn (`cycle-log-epic-19.md`). This pass wrote only this spec and committed nothing.
- **For the lead's spec gate:**
  - the spine draft (AD-47, AD-28, Deferred, the map);
  - the contended edits (EXPERIENCE.md :689 and the bundle re-base);
  - the Fixed-strings union with Epic 18 (second to land raises the bound);
  - the named consequence that a description's external image is fetched.
