---
title: 'Story 21.15: Locale and table import'
type: 'feature'
created: '2026-11-15'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** The classic Import Locale page (`%CSP.UI.Portal.NLSImport`) loads custom locales, tables and subtables from an export file into the instance; OcuPilot has no route, screen action or tool for it, so a person who wants a custom locale from another instance has to use the classic portal.

**Approach:** One destructive import write on Story 21.14's `LocalePort`, reached by the Locale definitions screen's Import action and by a confirmed agent proposal (AD-53). The file is a server file named by an allowed root and a relative name (AD-21's sixth case, `source`), or, from the screen only, a file on the person's computer whose text the browser sends. Either way the port reviews the text, writes exactly that text to a temporary file whose name OcuPilot chooses, calls `Config.NLS.Locales.ImportAll` on it, and deletes it.

## Boundaries & Constraints

**Always:** `LocalePort` is the only product class that calls `ImportAll` and the only one that writes the temporary file; it gates before any vendor call (AD-29) and switches namespace by save and restore (AD-16). No caller value is a path: the vendor receives only OcuPilot's temporary file name, never the caller's resolved path (AD-21). The text is reviewed before the confirm (records, digest) and compared again at the write; a difference refuses with nothing imported (AD-6, AD-51). Text holding `<!DOCTYPE` is refused before any parse, OcuPilot's or the vendor's. The import key ships `false` and the write is destructive (typed-name confirm). A file that would replace the current locale or a table it loads is refused from either caller, whatever the key (Design Notes, Self-protection). Every read is bounded (AD-36). Imported locales appear in Story 21.14's locale list after the change event (AD-14).

**Never:** No caller-named path reaches the vendor; no `.goq` legacy import (`ImportLegacy`); no Locales/Tables/Both choice (the whole file is imported, Flags 7); no Export (owner, DW-2606); no Install, Copy, properties edit or Load table (21.14, 21.16). The local file's name and text never enter a tool schema, a proposal's stored arguments beyond the fingerprinted payload, a log line or the ledger. No user-facing string beyond those the spec gate rules. OcuPilot's own interface stays English.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Local import | person: `import-local` with `fileName`, `content` of an export holding custom locale `y…` | card/answer lists the file's custom locales (names), tables and subtables (counts) and how many replace existing ones; after confirm the locale is listed, `readBack` matches | none |
| Server import | agent: `root`, `path` of such a file under an allowed root | same review; proposal, confirm, same result | PathPort's own refusals (`PATH.*`, 403) |
| Source shape | both sources, neither, a local name with `/`, `\`, a control character or over 255 characters | nothing read | 400 `PORT.VALIDATION` |
| Too large | text over 3,000,000 characters | nothing parsed | 409 `LOCALE.IMPORT.TOOLARGE` |
| Not an export | `<!DOCTYPE`, malformed XML, or no `Locales`/`Tables`/`SubTables` record | nothing imported | 409 `LOCALE.IMPORT.SHAPE` |
| Nothing custom | every record's name is a shipped one | nothing imported | 409 `LOCALE.IMPORT.EMPTY` |
| Current locale | a record named as the current locale, or a table in its `GetTables` set | refused at review and at the write, key on or off | 409 `LOCALE.IMPORT.CURRENT` |
| Changed | the text's digest or the replaced-record count differs at the write | nothing imported | 409 `LOCALE.IMPORT.CHANGED` |
| Key off | default baseline | governance refusal, both callers | as every key-off write |

</intent-contract>

## Code Map

- `irissys/%CSP/UI/Portal/NLSImport.cls` -- `RESOURCE` `%Admin_Manage` (:21); `SaveData` :117-163: extension `xml` → `Config.NLS.Locales.ImportAll(FileName,.NumImported,SelBits)`, `goq` → `ImportLegacy`; answers `NumImported("Locales"|"Tables"|"SubTables")`.
- `irissys/Config/NLS/Locales.cls` -- `ImportAll` :439 (Flags 1 SubTables, 2 Tables, 4 Locales; "On failure, no records will be imported"), `ImportLegacy` :484 ("System records are skipped"), `Export` :330, `ExportList` :357 (counts tables and subtables too), `GetTables` :411, `OpenCurrent` :553; custom = name starts `y` (:14-19). `Tables.cls:15-21` (custom when `NameFrom` or `NameTo` starts `y`; IdKey `Type||NameFrom||NameTo`, `List(Types,NamesFrom,NamesTo)` :432); `SubTables.cls:14-16` (custom rule by name part). `irissys/NLS.int:380-417` (terminal import; "No custom locale or table to import." (inference: the vendor imports custom records only)).
- **Measured (read-only, slot A `ocupilot`, 2026-11-15):** current `enuw`; 36 locales, 241 tables (`List("*","*","*")`), 192 subtables, none custom; a locale record serializes as `<Locales>…<Name>enuw</Name>…</Locales>` (`XMLExportToString`, 3,980 characters); `ImportAll`'s body is not exported (deployed).
- **Closest sibling:** `src/OcuPilot/Screen/Tool/InteropLookupTableImport.cls` -- `READTYPE` :29, `SCREENACTIONS`/`SCREENVALUES` :35-38, `DESTRUCTIVE` :43, `STATEMARKER`, `FINGERPRINTSUBJECT`, `PRECONDITIONFIELD`/`PRECONDITIONCODES`, `CLASSICPAGES`, `CONSEQUENCECODE`, `REVIEWED` :46-64, `SettableFields`, `InputSchema` (uses `TaskExport.AddFileArguments` :113), `ArgumentPairs` (`ExplorerExport.FilePairs` :90), `StateDiff` :148-168.
- `src/OcuPilot/Port/InteropPort.cls` -- `ImportText` :6522-6562 (source checks, PathPort `source` resolve, `AtelierPort.ReadText`), `ImportShape` :6578 (SHA-256 digest of the UTF-8 bytes), `ReadImportTable` :6643, `PerformImport` :6682-6716 (reviewed compare, again under the lock). Private and contended (Epic 24 edits it): read only.
- `src/OcuPilot/Port/AtelierPort.cls` -- `MAXIMPORTCHARACTERS` :429, `MAXFILENAME` :432, `ReadText` :2181; temp-file model `TempFilename("json")` :3078 and its unconditional delete :3149-3150. `Port/TaskTransferPort.cls:594-599` (a vendor call taking a resolved file). `Port/PathPort.cls` -- `PAIRS` :50, `KINDSOURCE` :69, `Resolve` :269.
- **Story 21.14 (ready-for-dev, implemented before this story):** `Port/LocalePort.cls` (`Locales` endpoint, `WRITETYPES`, seams, `Snippet`), `Api/LocaleError.cls`, `Area/OsMgmt/LocaleRules.cls`, `Screen/Tool/LocaleAction.cls`, `Screen/Descriptor/LocaleList.cls`, `Test/LocaleGateSeam.cls`, `ui/src/app/areas/os-management/locale-list.page.ts`. Use the names as landed.
- **Client:** `ui/src/app/areas/system-explorer/explorer-import-dialog.ts` (shared: server/local source, `IMPORT_MAX_CHARACTERS`, `FileReader` in `onFile` :187-204, `title`/`replaces`/`accept`/`compileOption` inputs); caller model `ui/src/app/areas/interop/interop-lookup-table-list.page.ts:129,299`; `shell/screen-action-handler.ts` (lookup's `import`/`import-local` entry near :505, `DESTRUCTIVE_ACTIONS`, `DESTRUCTIVE_CONSEQUENCES`); `core/proposal-view.ts`; `core/strings.ts` (lookup import strings :7203-7221).
- `Kernel/Governance/Baseline.cls:246` (`interop.lookuptables.import` `false`, the row model); `scripts/ci-throwaway.sh` (`OCUPILOT_ALLOW_CONFIG_SETTINGS` `# classes:` line).

## Tasks & Acceptance

**Execution, batch 1 (server; commit when its loop commands are green):**

- Task 0, on `ocupilot-ci`, recorded under Design Notes before code, every probe restored: (a) a `y` locale made by vendor `Create` from `enuw`'s `Get`, exported with `Export`: the file's root and record elements, its encoding declaration, and whether shipped tables ride along; (b) `ImportAll` of an `enuw` export whose `Description` was edited in the text: written or skipped (restore from a first export); (c) `ImportAll` of the `y` export after `Delete` (recreated, `NumImported`), over an existing `y` (replaced?), and of a malformed file (error, nothing written); (d) `%File.TempFilename("xml")`'s directory, and a UTF-8 round trip of a non-ASCII `Description`; (e) whether `ImportAll` records a vendor audit event with auditing on; (f) how a table's subtables are named, so `GetTables`' set maps to them; (g) `NormalizePage("%CSP.UI.Portal.NLSImport")`'s spelling and custom resource, and one locale's import time. (inference throughout until measured.)
- `src/OcuPilot/Port/LocalePort.cls` -- `Locales` adds read type `IMPORTFILE` and write type `IMPORT` (target literal `import`). `ImportText` (the source checks and read of `InteropPort.ImportText`, with `LOCALE.IMPORT.TOOLARGE`); `ImportReview` (refuses `<!DOCTYPE`, parses with `%XML.TextReader`, collects each `Locales` `Name`, each `Tables` `Type`/`NameFrom`/`NameTo` and each `SubTables` `Name`; keeps custom ones; answers `{Digest, Locales[] (at most 50, with Truncated), LocaleCount, TableCount, SubTableCount, Replaces, root, path, fileName, content}`, `content` always empty on the wire); refusals `SHAPE`, `EMPTY`, `CURRENT` (current locale's name; its `GetTables` set; its subtables per Task 0 (f)), and per Task 0 (b) `SYSTEM` when the vendor writes shipped records. `IMPORT` repeats the review under the per-target lock, refuses `CHANGED` on a digest or `Replaces` difference, then the `SendImport` seam: `TempFilename("xml")`, write the reviewed text as UTF-8, `ImportAll(file, .n, 7)`, delete always; answers the three counts. A vendor error is logged (AD-39) and answers 500 `INTERNAL`. Read-back: every reviewed locale listed. `Snippet` renders `ImportAll` with a placeholder file and literal flags (AD-59).
- `src/OcuPilot/Api/LocaleError.cls` -- add `LOCALE.IMPORT.SHAPE`, `.EMPTY`, `.CURRENT`, `.CHANGED`, `.TOOLARGE` (and `.SYSTEM` only if Task 0 (b) needs it), consequence `LOCALE.IMPORT`, with ruled sentences. `src/OcuPilot/Area/OsMgmt/LocaleRules.cls` -- the import's precondition codes for the tool.
- `src/OcuPilot/Screen/Tool/LocaleImport.cls` -- new, `LocaleAction` with `InteropLookupTableImport`'s import parameters: `osmgmt.locales.import`, `READTYPE` `IMPORTFILE`, `WRITETYPE` `IMPORT`, `SCREENACTIONS` `import,import-local`, `SCREENVALUES` `import=root:path,import-local=fileName:content`, `DESTRUCTIVE`, `CHANGEACTION` `updated`, `STATEMARKER` `Digest`, fingerprint `root,path,fileName,content,Digest,LocaleCount,TableCount,SubTableCount,Replaces`, `PRECONDITIONCODES` the six refusals, `CLASSICPAGES` `%CSP.UI.Portal.NLSImport`, `CONSEQUENCECODE` `LOCALE.IMPORT`; schema `root`, `path` only (`AddFileArguments`); `ArgumentPairs` by `FilePairs`; `StateDiff` rows File, Locales, Tables, Subtables.
- Add-only rows: `Kernel/Governance/Baseline.cls` (`osmgmt.locales.import` `false`); `Screen/Descriptor/LocaleList.cls` (the command-bar action `import`); `scripts/ci-throwaway.sh` (`LocaleImportWrite` on the config-settings `# classes:` line).
- `src/OcuPilot/Test/LocaleImportRules.cls` (live-safe, `LocaleGateSeam`: every matrix refusal at the mint, the screen action and the port, before `SendImport`; the agent schema carries no `fileName`/`content`; the snippet) and `LocaleImportWrite.cls` (armed: creates a `y` locale, exports it to text, deletes it, imports by `import-local` and by an agent proposal over a server file it writes under an allowed root, both listing it again; `CHANGED` when the file changes after the mint; restores in `OnAfterOneTest`).
- The shared-surface tests under Verification, each to the new shape.

**Execution, batch 2 (client; commit when its loop commands are green):**

- `ui/src/app/areas/os-management/locale-list.page.ts` with its spec -- the Import action opens `ExplorerImportDialog` (`compileOption` false, `accept` `.xml`, ruled title and replaces sentence) and sends `import` or `import-local` with target `import`, as the lookup page does. `shell/screen-action-handler.ts` (`import`, `import-local` for `LocaleList`, destructive, consequence), `core/proposal-view.ts` (`LOCALE.IMPORT`), `core/strings.ts`, `core/screens.generated.ts`.
- `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md` -- the ruled strings into Fixed strings (add-only).
- `ui/browser/nls-locales.browser-spec.mjs` -- after the answered signal: Import opens the dialog; with the default baseline, a local `.xml` holding only a shipped locale's record is refused by governance; with the key on in the spec's own fixture and restored, the same file shows the `LOCALE.IMPORT.EMPTY` sentence.

**Acceptance Criteria:**

- AC1. Given the import key `true` on `ocupilot-ci` and a `y` locale the test exported and then deleted, when a person imports the export from a local file, then the card lists it, the confirm round-trips over `Config.NLS.Locales.ImportAll` (the locale is listed again, `readBack` matches), and no temporary file remains.
- AC2. Given the same export as a server file under an allowed root, when the agent proposes it and the person confirms, then it imports likewise; and when the file changes after the mint, the confirm is refused `LOCALE.IMPORT.CHANGED` with nothing imported.
- AC3. Given a file holding the current locale's record or a table it loads, when either caller imports it with the key on, then it is refused `LOCALE.IMPORT.CURRENT` before any vendor call.
- AC4. Given the default baseline, when either caller imports, then governance refuses it; and a `<!DOCTYPE` text is refused `LOCALE.IMPORT.SHAPE` before any parse.
- AC5. Given these configure the server's locales rather than OcuPilot's own interface, when the dialog, card and refusals render, then each is an English `strings.ts` value pinned equal to its `LocaleError` sentence.

## Spec Change Log

## Review Triage Log

## Design Notes

**Governing ADs:** AD-5, AD-6, AD-8, AD-10, AD-11, AD-13, AD-14, AD-15, AD-16, AD-21 (sixth case `source`; no caller path reaches the vendor), AD-22 (key `false`), AD-29, AD-34, AD-36, AD-39, AD-44, AD-51, AD-52, AD-53, AD-56 (local values are screen values), AD-58, AD-59.

**The file mechanism.** Two sources, as Stories 19.13 and 20.5 take them: a server file (`root` + relative `path`, PathPort `source`, both callers) and a local file's text (screen only, never in the schema). Both become the same reviewed text; the vendor receives only a temporary file OcuPilot names with `%File.TempFilename("xml")`, written from that text and deleted on every path. So no caller value is a path (AD-21 needs no amendment), and the vendor imports exactly the bytes the person reviewed, never a server file that could change between the check and the call. No precedent writes uploaded text to a file (AtelierPort's temp file is an output); the vendor offers no stream form of `ImportAll`.

**Proposed, for the spec gate (AD amendments; not halting):**

- **AD-51 named entry (needed).** The vendor call carries a caller's choice, so by AD-51's "any further case is a new named entry": "Story 21.15's case: `LocalePort`, which builds `Config.NLS.Locales.ImportAll`'s file argument from the import tool's declared `root` and `path`, resolved through `PathPort` as a `source`, or from the screen's local text, in either case written to a temporary file OcuPilot names and deletes; its flags are a constant; it answers the fresh read through a port-composed `IMPORTFILE` type and refuses an import whose text no longer yields the reviewed digest." No design without it exists: an import cannot take no file. (Load table's question at 21.14 was the same.)
- **AD-21 record (optional, by precedent):** "Story 21.15's consumer of the sixth case: the locale import's file is a `source`; local text is a screen value."
- **AD-53 named gap (only if Task 0 (e) finds no vendor audit event):** the locale import, as Story 19.13's.

**Self-protection: refused, and destructive with its key off.** An import replaces any custom record of the same name without asking, so it is destructive and ships `false`. A file that would replace the current locale's record or a table it loads is refused from either caller, key on or off: every process of the instance, OcuPilot's included, takes its tables and formats from the current locale at the next start or reload, and 21.14 already refuses deleting it, which a replacement amounts to. On a stock instance the current locale is a shipped one, so this bites only when a custom locale is current, or if Task 0 (b) shows the vendor writes shipped records; then the port refuses any shipped record `LOCALE.IMPORT.SYSTEM`, consistent with 21.14 changing only custom NLS records (stricter than the classic page, which the run's defaults allow).

**Decided in-stage:** XML only (`.goq` is the pre-IRIS format, refused by extension for a local file and by `SHAPE` otherwise). The `<!DOCTYPE` refusal keeps both parses from resolving an external entity, which would read a server file by content (AD-21's intent). The preview is OcuPilot's own `%XML.TextReader` read of element names, since `ImportAll` has no count-only flag. Import is a command-bar action on 21.14's Locale definitions screen, not a new screen.

**Escalated for the spec gate's ruling (veto window):**

- **No Locales/Tables/Both choice** (recommended): the whole file is imported (Flags 7); the classic radio is not carried, which keeps the shared dialog unedited and the AD-51 entry to one argument. Alternative: a `Records` enum, which edits `explorer-import-dialog.ts` (shared with System Explorer and lookup tables) and adds three strings.
- **New strings** (reuse "Import", "File", "Locales", the dialog's own strings): dialog title "Import locales and tables"; replaces line "Importing replaces any custom locale or table with the same name."; card rows "Tables" · "Subtables"; `LOCALE.IMPORT` consequence "Importing replaces any custom locale or table with the same name. This cannot be undone."; `LOCALE.IMPORT.SHAPE` "This file is not a locale or table export."; `LOCALE.IMPORT.EMPTY` "This file holds no custom locale or table to import."; `LOCALE.IMPORT.CURRENT` "This file would replace the current locale or a table it loads, so it cannot be imported."; `LOCALE.IMPORT.CHANGED` "The file or the locales changed after the import was reviewed, so nothing was imported. Review the import again."; `LOCALE.IMPORT.TOOLARGE` "An import file holds at most 3,000,000 characters, and this one holds more."; only if Task 0 (b) needs it, `LOCALE.IMPORT.SYSTEM` "This file holds a locale or table InterSystems ships; only custom ones, whose names start with y, can be imported."; done line "Imported <locales> locales, <tables> tables and <subtables> subtables."; empty-agent phrase "import a locale"; prompt "Import a locale from a file".

**Extend, don't copy (Rule 2/31):** extends 21.14's `LocalePort`, `LocaleError`, `LocaleRules`, `LocaleAction`, `LocaleList`, the locale page and `LocaleGateSeam`; reuses `PathPort.Resolve`, `AtelierPort.ReadText` and its two size parameters, `TaskExport.AddFileArguments`, `ExplorerExport.FilePairs` and `ExplorerImportDialog`. `LocaleImport` copies `InteropLookupTableImport`'s import parameters (subclassing would tie locales to interoperability). `LocalePort.ImportText` copies `InteropPort.ImportText`'s source checks (about 25 lines) because that method is private in a file Epic 24 is editing; the implement stage records the unification (one shared source-check helper) in `deferred:` for the lead's harvest.

**Integration ACs:** consumed in this story by its screen action and its agent tool (AD-53's two callers); AC1 and AC2 observe the result through 21.14's locale list. **Consumes:** Story 21.14's `LocalePort`, `LocaleAction`, `LocaleList` and page; Story 18.1's `PathPort`; Story 19.13's dialog; Story 20.5's import shape. **Consumed-by:** Story 21.16 (a copied or table-loaded locale may come from an import; none required).

**Ledger inbox:** none.

**Contended paths:** no Epic 24 commit beyond feature touches a file named here (checked at plan time). Epic 24's worktree holds uncommitted edits to `EXPERIENCE.md`, `ci-throwaway.sh`, `Baseline.cls`, `Prohibited.cls`, `Screen/Read.cls`, `InteropPort.cls` and several shared tests (`ClassicPageGate`, `Descriptor`, `MappingDescriptor`, `ReadTool`, `SurfaceCoverage`, `ToolRoundTrip`, `ToolWrite`); this story does not edit `InteropPort.cls`, and its edits elsewhere are add-only.

## Verification

**Shared surfaces:** OS management roster, positions and pair-order counts (`Navigation`, `WireSecurityRead`, `WireAreaAnyScreen`, `LanguageServerWire` and `ui/browser/language-servers.browser-spec.mjs`, `ui/tools/navigation.test.mjs`; no new screen, so expected unchanged); `Descriptor` (LocaleList's action list); the tool registry (`ReadTool` size unchanged, `ToolWrite`'s other-port count +1, `ToolRoundTrip`, `ToolDispatch`, `ToolEmit`, `SurfaceCoverage`); `PortGate` (LocalePort's pairs, now with PathPort's on a server file); `Prohibited`'s covered types (entity `locale` already covered; confirm); `TeardownGuard`; `ClassicPageGate` and `MappingDescriptor` (`%CSP.UI.Portal.NLSImport`); the read-source count (unchanged, source `locale`); `GovernanceBaseline`; `ui/tools/ci.test.mjs` (arming roster); `ui/tools/strings.test.mjs` with the EXPERIENCE.md literal cap (4200; if crossed, raise it by 400 under the file's protocol and report it); `proposal-view.test.mjs`; `ui/tools/screen-mirror.test.mjs`. The implement stage greps `ui/browser`, `ui/tools`, the `ui/src` specs and `src/OcuPilot/Test` for each; every test it changes joins `(loop)`.
*Every test added or changed passes on a fresh environment, in either order.* Each import test makes and removes its own `y` locale and its own files, and asserts on its own records by name.

**Commands.** One per foreground call, `timeout: 600000`, against `ocupilot-ci` only; never two test calls in one message.

- `(loop)` `sh /private/tmp/claude-501/-Users-jbrandt-git-OcuPilot/4667058b-f052-49c9-b08a-221f7f41dfab/scratchpad/e21u/lead/reload.sh /Users/jbrandt/git/OcuPilot/.worktrees/epic-21 ocupilot-ci` -- expected: `LOADERRORS=0`.
- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.LocaleImportRules`, one class per call, then each of `LocaleImportWrite`, `LocaleRead`, `LocaleRules`, `LocaleWrite`, `PortGate`, `SurfaceCoverage`, `GovernanceBaseline`, `Governance`, `Prohibited`, `ReadTool`, `ReadDescriptions`, `ToolEmit`, `ToolDispatch`, `ToolRoundTrip`, `ToolWrite`, `Descriptor`, `Navigation`, `ClassicPageGate`, `MappingDescriptor`, `StageTwoTools`, `Wire`, `WireAreaAnyScreen`, `WireSecurityRead`, `LanguageServerWire`, `TeardownGuard` -- expected: green.
- `(loop)` `uv run scripts/check-objectscript.py`, `uv run scripts/test_check_objectscript.py`, `bash scripts/lint-docs.sh` -- expected: clean.
- `(loop)` `cd ui && node --test tools/strings.test.mjs tools/screen-mirror.test.mjs tools/navigation.test.mjs tools/ci.test.mjs tools/proposal-view.test.mjs` and every `ui/tools` test the sweep changes -- expected: green.
- `(loop)` `cd ui && npm run build` and `npm run test:components`; redeploy with `docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`; then `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci node --test --test-concurrency=1 browser/nls-locales.browser-spec.mjs browser/language-servers.browser-spec.mjs` -- expected: green.
- `(once)` `cd ui && npm run test:tools` -- expected: green.
- `(once)`, runner-owned: the full ObjectScript sweep one class per call, `smoke.sh --container ocupilot-ci`, and Rule 30's fresh check. The full browser suite is left to CI.

**Mutations (Rule 19), one per AC, each applied, observed red, reverted byte-identical and the reverted source reloaded, then recorded here as `mutation: <change> -> <test red>`:** AC1 `SendImport` passes flags 3 (no locales); AC2 the digest compare dropped from `IMPORT`; AC3 the current-locale check dropped from `ImportReview`; AC4 `osmgmt.locales.import` `true` in `Baseline`; AC5 one word of `LOCALE.IMPORT.CURRENT` changed in `strings.ts`.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none

Plan pass from read-only probes on slot A (`ocupilot`); nothing ran against `ocupilot-ci`. Escalated for the spec gate: an AD-51 named entry for `LocalePort`'s import (needed; no design avoids it), an optional AD-21 record, an AD-53 gap conditional on Task 0 (e), dropping the Locales/Tables/Both choice, and the new strings.
