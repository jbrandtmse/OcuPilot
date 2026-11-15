---
title: 'Story 21.17: Global export and import'
type: 'feature'
created: '2026-11-15'
status: 'draft'
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: ['oversized']
deferred:
  - summary: 'Story 19.13 import already loads a global from an XML file, and self-protection judges only the document name: an `oddDEF.GBL` or `rOBJ.GBL` holding `OcuPilot...` subscripts (written into OcuPilot''s database through the package mapping), or a `%`-global (written into IRISSYS), is not refused.'
    evidence: 'AtelierPort.Examine keeps every name xml/list answers, with no type filter; Prohibited.Code judges names by OwnNameStems only. Measured read-only on ocupilot 2026-11-15: 31 of the 37 globals in /durable/iris/mgr/ocupilot/ are code globals not named OcuPilot*; GetGlobalDest(HSCUSTOM, %SYS) is /durable/iris/mgr/. The write itself is unmeasured (inference).'
    location: 'src/OcuPilot/Port/AtelierPort.cls Examine; src/OcuPilot/Kernel/Proposal/Prohibited.cls Code / IsOcuPilotCode'
    severity: 'high'
  - summary: 'Story 19.13 import of a file that replaces an existing global reads its version from %RoutineMgr.GetDate, which answers the current time for any existing global, so the reviewed summary changes every second and the write refuses EXPLORER.IMPORT.CHANGED.'
    evidence: 'Measured read-only on ocupilot 2026-11-15: GetDate("ROUTINE.GBL") and GetDate("oddDEF.GBL") both equal $ZDT($H,3); a missing global answers -1. The refusal at the write is inferred from ImportSet''s summary comparison (inference).'
    location: 'src/OcuPilot/Port/AtelierPort.cls Examine / ImportSet; irissys/%Api/Atelier/v7.cls ListDocumentsInXMLFiles'
    severity: 'med'
---

<intent-contract>

## Intent

**Problem:** The classic Globals page exports a namespace's globals to XML and imports them back. OcuPilot cannot export a global. Its System Explorer import (Story 19.13) already loads a global an XML file holds (inference), but does not handle it correctly.

**Approach:** Not planned. The independence check failed: no existing surface, port or AD-10 arm carries this story without Story 21.5's parked pieces or a new AD entry. Design Notes give the evidence.

## Boundaries & Constraints

**Always:** Nothing is built until Story 21.5's ruling, and the AD-10 entry below, are settled.

**Never:** Do not plan around a missing AD entry. Do not build a second globals list, entity type or port beside 21.5's.

## I/O & Edge-Case Matrix

These rows show what the current code does, as evidence for the halt. They are not a plan.

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Export a global today | a `.gbl` name in an explorer export set | refused by the set's name pattern; `docnames` lists no globals | 400 `PORT.VALIDATION` / 404 `EXPLORER.DOCUMENT.ABSENT` (inference) |
| Import a new global today | an XML file holding `<Global>` for a missing global | listed as `<name>.GBL new` and loaded (inference) | none |
| Import over an existing global today | the same file, the global present | the reviewed `ts` is the current time, so the write differs | 409 `EXPLORER.IMPORT.CHANGED` (inference) |
| Import a code or `%` global today | `oddDEF.GBL` or `%SYS.GBL` | not refused, because only the name is judged (inference) | none: the gap |

## Re-plan basis (2026-11-15)

Story 21.5 is planned (ready-for-dev, its spec final) and the owner allowed its AD-10 `PROHIBITED.PROTECTEDGLOBAL` arm with an import clause, now in the spine (owner answer U-59). Re-plan this story on 21.5's declared `GlobalPort`, Globals list (export as a row action), `global` entity type and the arm, reusing Story 19.13's export and import tools, server-file handling and dialogs. DW-2608 (routed here) is this story's to fix. Any new AD entry is not covered by an owner answer: if one is needed, HALT as an intent gap naming it.

</intent-contract>

## Code Map

- `src/OcuPilot/Port/AtelierPort.cls`
  - `CLASSNAMEPATTERN` :527 and `ROUTINENAMEPATTERN` :530 validate an export set. Neither admits `.gbl`.
  - `Docs` :1793 and `PresentSet` :1850 read presence through `docnames`, which lists no globals (21.5's spec, measured).
  - `Examine` :2312 keeps every document `xml/list` answers, of any type. `ImportSet` :2439 compares the reviewed summary at the write.
- `irissys/%Api/Atelier/v7.cls`:
  - `ExportToXMLFile` :171 runs `ExportToStream` whole before answering, so an export has no size bound before the work. The capture ceiling only refuses the answer.
  - `ListDocumentsInXMLFiles` :468 is `LoadStream(..,listonly 1)` with `ts` from `%RoutineMgr.GetDate`.
- `src/OcuPilot/Kernel/Proposal/Prohibited.cls`: the import routing is at :1542. `IsOcuPilotCode` :2906 matches by name stem only.
- `_bmad-output/implementation-artifacts/spec-21-5-globals-and-the-data-tools.md` (blocked) holds the `GlobalPort`, `global` entity type, Globals list and the proposed `PROHIBITED.PROTECTEDGLOBAL` arm that this story would consume.

## Tasks & Acceptance

**Execution:** none until the story is re-planned after the ruling.

**Acceptance Criteria (epics.md, verbatim):**

- Given global export and import, when each runs, then it round-trips, every write a confirmed proposal.

## Design Notes

**Governing ADs:** AD-10, AD-21 (sixth case), AD-51 (Story 19.13's `AtelierPort` case), AD-61 (rules 1, 2 and 5, and "a later call Atelier cannot carry names itself here"), AD-6, AD-36, AD-53.

**Independence check: fails.**

1. **Export has no person-side surface without 21.5.** The Classes and Routines lists check documents from `docnames`, which lists no globals, so a global can never be in their checked set. The agent side would need an id of a new kind. Story 19.13's set types are `class` and `routine`, validated by the patterns above. Admitting `.gbl` would change what those types mean. The proper type is 21.5's `global`, and the proper surface is its Globals list's row action.
2. **Export needs a presence and size read that Atelier cannot carry.** Exporting a missing global answers success (21.5, measured), and `docnames` cannot see globals. A size bound has to come before `ExportToStream`, because the capture ceiling only refuses the answer after the vendor has done the work. Both reads are outside Atelier, so they need either 21.5's `GlobalPort` or a new AD-61 named case.
3. **Import fits 19.13's AD-21 and AD-51 cases, but not AD-10.**
   - `^OcuPilot*` globals: the existing `OCUPILOTCODE` arm covers them by name. `OcuPilotX.GBL` begins with the stem. This was read in code and not run (inference).
   - OcuPilot's own database and the protected databases: no existing arm covers these. Measured read-only on `ocupilot`:
     - 31 of the 37 globals in `/durable/iris/mgr/ocupilot/` are code globals not named `OcuPilot*` (`oddDEF`, `rOBJ`, `ROUTINE`, …), which a namespace reaches through subscript-level package mappings (inference).
     - `^%SYS` from `HSCUSTOM` resolves to `/durable/iris/mgr/` (IRISSYS).

     An import of `oddDEF.GBL` or `%SYS.GBL` is judged by that name and is not refused. `OCUPILOTDATABASE` covers deleting and reconfiguring a database, never writing into one.
4. **Import does not round-trip over an existing global.** `GetDate` answers the current time for any existing global (measured), so the reviewed version never matches at the write (inference). Fixing it needs a stable version of the global, such as a content digest, which is again a read outside Atelier (item 2).

**Smallest entries needed (for the owner's ruling; not adopted):**

- **AD-10:** "An import whose reviewed documents include a global is refused `PROHIBITED.PROTECTEDGLOBAL`, from either caller, when the global, or any subscript the file holds for it, resolves in the target namespace, read at the write, to OcuPilot's own database or one of the seven protected databases." This is 21.5's proposed arm, with an import clause added.
- **AD-61 named case (only if 21.5's `GlobalPort` is not ruled in):** "`AtelierPort` reads a global's presence, size and content digest in the target namespace outside the Atelier routes, behind rule 1's gate."

**Recommendation:** rule 21.5 first. Then re-plan 21.17 as a consumer of 21.5's Globals list (an export row action), `global` entity type, `GlobalPort` (presence, size and digest) and `PROTECTEDGLOBAL` arm. It would reuse 19.13's `ExplorerExport`/`ExplorerImport` tools, `PathPort` file case and dialogs. The two `deferred:` findings above stand whatever 21.17's fate: 19.13 ships today with the self-protection gap.

**Decided in-stage:**

- The epic context was reused as the runner directed. The only newer planning change is the 21.5 split, whose 21.17 block was read directly.
- **Contention:** `origin/OCU-1-epic24` changes no file named here (checked 2026-11-15).

**Ledger inbox:** none.

## Verification

**Manual checks:** none until re-planned. This plan pass ran read-only probes on `ocupilot`: `%RoutineMgr.GetDate` and `Exists` on a present and a missing global, `GetGlobalDest` for `%SYS`, `oddDEF` and `OcuPilotTurnSignal`, and `%SYS.GlobalQuery:DirectoryList` on OcuPilot's database.

## Auto Run Result

Status: blocked
Blocking condition: intent gap -- depends on parked Story 21.5: its Globals list (the only person-side surface where a global can be chosen for export), its `global` entity type (the export's id; 19.13's `class`/`routine` sets admit no `.gbl`), and its `GlobalPort` (the global presence, size-before-export and content-version reads Atelier cannot carry; otherwise a new AD-61 named case). It also needs a new AD-10 entry: import self-protection by resolved database. The existing `OCUPILOTCODE` arm covers `^OcuPilot*` by name, but not code globals such as `oddDEF`/`rOBJ` written into OcuPilot's database through package mappings (31 of the 37 globals there, measured), nor `%`-globals written into IRISSYS (measured). The smallest entry is 21.5's proposed `PROHIBITED.PROTECTEDGLOBAL` arm plus an import clause. Two findings on shipped Story 19.13 are in `deferred:` for harvest: the import self-protection gap (high), and a replace-import that always refuses CHANGED because `GetDate` answers the current time for any existing global (med).

Plan pass used read-only probes on slot A `ocupilot` only; nothing ran against `ocupilot-ci`.
