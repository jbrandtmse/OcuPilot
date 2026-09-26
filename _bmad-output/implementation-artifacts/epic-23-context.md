# Epic 23 Context: The range-end cleanup

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Empty the deferred-work ledger slice owned by `range-end-cleanup`. Under the rule that floor cleanup stories carry only floor-blocking entries, every other closable entry was re-owned to this one story. At the charter the slice holds 178 entries: by severity 97 low and 81 medium, none high; by fix-risk 128 low, 44 medium and 6 high. The work runs in the contest voting week, after the submission cut (`release/1.0.0` at `9d7e1d27`), and merges to the feature branch. It never touches `release/1.0.0`. The aim is a ledger the judges' build leaves behind that is honest, and code that is as correct as the time allows.

## Stories

- Story 23.1: The range-end cleanup

## Requirements & Constraints

- **Every entry gets a disposition, and the slice ends empty.** Each disposition is written through the ledger tool and is one of these:
  - `resolved-by:23-1-the-range-end-cleanup`, with the commit;
  - `wontfix-accepted` or `by-design`, with a reason and, if some condition would reopen the entry, that condition;
  - re-owned by name to an Epic 14 or Epic 16 story that owns the code;
  - re-owned to `burndown`, for after the contest.
- **Which entries get fixed:**
  - Fix every entry whose fix-risk is low and whose fix stays inside the code the entry names, unless the plan records why not.
  - Fix a medium or high fix-risk entry only where the plan justifies that entry. Re-own the rest.
- **Three entries the owner routed here must be fixed:**
  - DW-1681: the demo fixture seeds a duplicate `<DIVIDE>` application error on every container start.
  - DW-1682: four code comments cite README sections that moved to `docs/DEVELOPMENT.md`.
  - DW-1688: the doc comment in `proposal-card.ts` names Story 14.7, which the owner scratched.
- **Changes a judge can see:** the plan names each one together with the entry that asks for it. A fix that contradicts a planning document corrects that document at its origin, by replacing the wrong sentence rather than appending an erratum.
- **Batching:**
  - Fixes land in batches grouped by area.
  - Each batch is its own commit, with CI green on its head.
  - A failing batch is re-opened alone and never holds back the others.
- **What the slice covers (inference, from the entry summaries):**
  - ObjectScript API handlers, the kernel, the gate and the proposal/confirm paths;
  - provider transport and egress;
  - installer, smoke and IPM packaging;
  - CI and the throwaway scripts;
  - client panel, chrome and browser specs;
  - test hygiene: oversized classes, stale Rule 19 recipes, duplicated helpers;
  - document drift in `epics.md`, `DESIGN.md`, `EXPERIENCE.md`, the spine, the PRD and `.claude/rules/`.

## Technical Decisions

- **Ledger tool:** `bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md <cmd>`.
  - `slice range-end-cleanup` lists the work and `show DW-<n>` prints one entry.
  - `append DW-<n> "status=... owner=... by=... note=..."` writes a disposition. Trailers are append-only.
  - Never read or hand-edit the whole ledger.
  - An `owner=` value must be `burndown` or a `development_status:` key in `sprint-status.yaml`. Valid targets include `14-1`…`14-6` and `14-8` (Governance, restraint and transcripts) and `16-1`…`16-20` (the remaining polish-week extras); use the full keys.
- **The architecture spine is a contract** (56 ADs). If an entry exposes an AD that is wrong, amend the AD rather than working around it. Several entries are about AD wording itself, for example AD-42's worst-case timeout, AD-43's refresh roster and AD-29's pair probe.
- **ObjectScript:**
  - Load and compile only through the IRIS MCP tools, with this runner's slot profile.
  - Run `uv run scripts/check-objectscript.py` before committing.
  - After a mutation, recompile the whole affected tree.
  - Run one test class at a time, and take results from `%UnitTest_Result`.
- **Client:**
  - `npm run build` (the prebuild chains seven checkers) and `npm test`.
  - `npm run test:browser` runs against the deployed bundle, so rebuild and redeploy before reading a browser result.
- **Documents:** run `bash scripts/lint-docs.sh`. A planning document that tests pin by line also needs `npm run test:tools`.
- **Prose discipline:** doc comments state the contract only. They carry no review history, finding ids or story narration. Several slice entries are exactly that kind of stale narration.
- **Git:**
  - Stage by path, never `git add -A`.
  - Do not push a `[skip ci]` bookkeeping commit together with a code commit: it suppresses the code commit's CI (an open entry in this slice).

## Cross-Story Dependencies

- Entries that are re-owned go to backlog stories in Epic 14 (governance, transcripts and ledger retention; for example, ledger-table bounding belongs to 14.4) or Epic 16 (polish extras). Re-own only where that story actually owns the code.
- The story follows Story 15.10. The release branch is frozen, so nothing here may be cherry-picked to `release/1.0.0`.
