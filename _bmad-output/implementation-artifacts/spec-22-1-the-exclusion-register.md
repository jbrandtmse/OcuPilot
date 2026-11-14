---
title: 'Story 22.1: The exclusion register'
type: 'chore'
created: '2026-11-14'
status: 'done'
baseline_revision: '8774fda9f8a66145a68b9d577bce3444988df474'
review_loop_iteration: 0
followup_review_recommended: true
context: []
warnings: [oversized]
deferred: []
---

<intent-contract>

## Intent

**Problem:** The 56 catalog rows OcuPilot does not build (tier P4) carry a one-phrase reason in the catalog and, for some groups only, a gate in the PRD's stage extract. Nothing records, row by row, what would have to become true before a row could be built, so a future request is answered against a blank.

**Approach:** Add one builder-facing register, `docs/exclusion-register.md`, holding every P4 row in the extract's eight groups with its reason, a gate kind, the gate and how to tell it has cleared. A `node --test` check holds the register equal to the catalog's P4 rows and to the extract's grouping, both derived from those documents, so the register cannot drift silently.

## Boundaries & Constraints

**Always:**

- The register's row set is exactly the catalog's P4 rows and its groups are exactly the extract's Stage 5 groups; the test derives both from the documents, never from a typed id list or count.
- A license, edition or platform gate names a runnable check (backticked), where the vendor evaluates it, and what it read on the slot B instance on the observation date. A deprecation gate names the deprecated feature and says an owner decision to support it clears it.
- A gate the planning documents do not source is a judgment and says plainly what evidence clears it (kind `demand`, `vendor-page`, `dependency` or `not-applicable`). Every unconfirmed check carries `(inference)`.
- Reasons restate the catalog Evidence cell's "excluded:" phrase in plain words; nothing is claimed that was not read or observed.

**Never:**

- No row is built, promoted or re-tiered; no planning document is edited (the catalog, the extract, the PRD, the spine, `epics.md`).
- No product string, screen, descriptor, ObjectScript, README or `docs/DEVELOPMENT.md` change. No IPM release or article (owner-only).
- No IRIS write: slot B is read only (`server: "ocupilot-slot-b"`), and no throwaway is started.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| In step | register rows equal catalog P4 rows and extract groups | test passes | none |
| Row missing or extra | a P4 id absent from the register, or a register id that is not P4 | red, naming each missing and each extra id | message lists both directions |
| Duplicate | one id in two register rows | red, naming the id | none |
| Wrong group | a row under a group the extract does not put it in | red, naming the extract group whose members differ | none |
| Bad row | empty reason, gate or how-to-tell; kind not in the Gate kinds table | red, naming the row | none |
| Vague gate | `license`, `edition` or `platform` row with no backticked check | red, naming the row | none |
| Parse floor | catalog yields no Tier column or zero P4 rows; extract yields zero groups | red, naming the document | never a vacuous green |

</intent-contract>

## Code Map

- `_bmad-output/planning-artifacts/research/technical-ocupilot-portal-feature-landscape-2026-09-08/feature-catalog.md` -- source of the P4 set: per-section tables, header row names a `Tier` column (find it by name, not position); row lines match `^\| [A-Z]{2}-\d+ \|`. 538 rows, 56 at P4 today (lines 76 to 655). Evidence cell holds the "excluded:" reason. Read only.
- `_bmad-output/planning-artifacts/prds/prd-OcuPilot-2026-09-08/extract-stages.md:646-775` -- `### Stage 5` (called Stage 6 in the PRD and epics): eight `**<group>** — N rows` lines (em dash U+2014; write it as `—` in the `.mjs`, Rule 14, `client-lint.mjs` `checkNonAsciiLiterals` covers `ui/tools`), each followed by a table; the "API readiness that gates the stage" bullet names the sourced gates. Read only.
- `_bmad-output/planning-artifacts/epics.md:9365-9379` -- Story 22.1's group wording, used for the register's `###` headings.
- `ui/tools/credential-lists.test.mjs` -- sibling to follow: `REPO_ROOT` join, reads checked-in documents only, sorted set comparison naming the difference.
- `ui/tools/strings.test.mjs:57-70` -- sibling table-row loop (header, skip separator, stop at first non-row line).
- `irislib/EnsPortal/Application.cls` (`GetEnsembleArray`, lines 63 to 226) -- the interoperability menu's own edition checks; `irislib/HS/HC/Security/Installer.cls:13` -- SS-40; `irissys/%CSP/UI/Portal/Application.cls:236,281,291` and `irissys/%CSP/UI/Portal/Config/Telnet.cls:29,52` -- Windows checks. Read only.
- `src/OcuPilot/Screen/Descriptor/AnalyticsArchitectLink.cls`, `AnalyticsAnalyzerLink.cls`, `AnalyticsUserPortalLink.cls`, `src/OcuPilot/Screen/ExternalPage.cls` -- the AN-04 to AN-06 links (Story 20.32, commit `bd8593f88`), compiled on slot B.
- `scripts/check-prose.py` (`DEFAULT_GLOBS` includes `docs/**/*.md`) -- lints the new document with no edit.

## Tasks & Acceptance

**Execution:**

- `docs/exclusion-register.md` -- create: a short opening (what the register is, the two source documents by path, the Stage 5/Stage 6 naming note, that a row is picked up only on demand and when its gate has cleared), `## Gate kinds` (table `| Kind | What clears it |`, the eight kinds in Design Notes), `## The register` with one `###` heading per group and one table each, header `| ID | Feature | Reason | Gate kind | Gate | How to tell it has cleared |`; fill each row from Design Notes. Re-run the slot B checks read-only and write the values read with the date.
- `ui/tools/exclusion-register.test.mjs` -- create: parse the three documents, then assert ID-set equality both ways with no duplicates, group-partition equality with the extract, the row completeness and kind vocabulary rules, and a backticked check on every `license`, `edition` and `platform` row, with the parse floors of the matrix.

**Acceptance Criteria:**

- Given the register and the catalog, when `exclusion-register.test.mjs` runs, then the register's IDs equal the catalog's P4 IDs in both directions with no duplicate, and its eight groups hold exactly the extract's Stage 5 memberships under the epics' group wording.
- Given any register row, when it is read, then it carries its reason, a gate kind from the Gate kinds table, its gate and how to tell it has cleared; a judgment gate says what evidence clears it.
- Given a row whose gate is a license, an edition or a platform, when it is read, then it names a runnable check, where the vendor evaluates it and what slot B read on the observation date; a deprecation row names the deprecated feature and the owner decision that clears it.
- Given AN-23, when it is read, then its row says the Architect, Analyzer and User Portal links ship (Story 20.32) and that rebuilding them stays excluded.
- Given the change, when `bash scripts/lint-docs.sh` runs, then it passes, and the diff adds no product string.

## Spec Change Log

## Review Triage Log

### 2026-11-14 — Review pass

- verdicts: 14 findings — high 0, medium 4, low 10, false 0, maybe-false 0
- findings:
  - `[medium]` `[patch]` AN-23's "links ship, rebuilding stays excluded" had no pinning test — added `AN-23 says the three analytics links ship...` and a mutation line.
  - `[medium]` `[patch]` "where the vendor evaluates it" and "names the deprecated feature" were unpinned — the license/edition/platform test now needs `evaluates it` and `slot B read <value>`; the deprecation test needs the named feature; OS-34 gained its vendor citation.
  - `[medium]` `[patch]` Reasons of SA-53 to SA-58 and EX-55 to EX-57 added words the catalog does not carry — restated from the catalog phrase.
  - `[medium]` `[patch]` IO-83 to IO-89 said "No instance check applies", but the vendor menu lists those pages only where the package is installed — rows now cite the check and what slot B read (1 for X12, ASTM, DICOM, SEF, XML, read 2026-11-14); kind stays `demand`, a small call within the story.
  - `[low]` `[patch]` Several tests had no mutation line — seven more recorded.
  - `[low]` `[patch]` A test name overstated what it pins — renamed to the extract-versus-catalog comparison it makes.
  - `[low]` `[patch]` IO-76 and IO-77 gate text did not match the check — reworded.
  - `[low]` `[patch]` "hidden administration API" is not sourced — now "admin-v2 API", the catalog's wording.
  - `[low]` `[reject]` EX-55 to EX-57 "no OcuPilot link exists yet" has no re-read path — searched `src/OcuPilot/Screen` and `ui/src`, no descriptor names them; Story 22.2 re-reads a row's gate before a pick-up.
  - `[low]` `[reject]` Feature cells paraphrase catalog names — the reason is what the spec ties to the catalog.
  - `[low]` `[reject]` A mistyped id is skipped by the parsers — it surfaces as a missing id.
  - `[low]` `[reject]` The test reads one sentence of Story 22.1 in `epics.md` — the spec chose that source for the group wording.
  - `[low]` `[reject]` IO-75 takes `demand` though its group is edition-gated — stated in the row and in Design Notes.
  - `[low]` `[reject]` No test checks reason fidelity, `(inference)` labels or the truth of a check — the spec makes these a manual check, done by two layers against the catalog and the instance.

## Design Notes

**Architecture decisions.** The spine's capability map gives Stage 6 no AD of its own ("long tail, on demand, —"). The register cites AD-27 (OS-31, OS-32 and SA-50 reach `%Api.Admin.*` only through `AdminPort`) and AD-1 with AD-2 (in-process, same instance) for EX-58. AD-5 governs a pick-up, which is Story 22.2's.

**Integration ACs.** No consumers in this story; the first consumer will be Story 22.2. Consumed-by: Story 22.2 (reads a row's gate kind, gate and how-to-tell before building; a promotion that re-tiers a catalog row reddens this test until the register drops it). Consumes: none.

**Extend, don't copy (Rule 31).** The test follows `credential-lists.test.mjs`. No shared Markdown-table helper exists (`strings.test.mjs` and `panel-layout.test.mjs` each parse inline), so a short local `tableRows()` is a copy by choice: extracting one would edit two unrelated suites.

**Gate kinds:** `license`, `edition`, `platform` (a runnable check clears), `deprecation` (an owner decision to support the deprecated feature), `dependency` (something outside OcuPilot must exist), `vendor-page` (the vendor's page or class is live on a menu of a supported release), `not-applicable` (only a spine amendment makes it apply), `demand` (no gate beyond a recorded request naming the row; the extract's "a demand signal").

**Gates per row.** Observed on slot B (IRIS for Health Community 2026.2 build 221U), 2026-11-14. "A" is `irislib/EnsPortal/Application.cls`.

| Rows | Kind | Gate and how to tell |
| --- | --- | --- |
| SA-50, SA-51, SA-52 | license | sharding license: `$$Sharding^%SYS.LICENSE` returns 1 (read 0); SA-50 is admin-v2 backed |
| SS-40 | edition | `/ui/security-config` created when `##class(%SYS.Namespace).Exists("HSSYS")` (Installer:13); read 1 and the app enabled, so cleared on IRIS for Health; plain IRIS not observed (inference: no HSSYS); still not on any menu |
| IO-71 | edition | Hub/IMT: `$Data(^EnsLib.Hub)` (A:226, inference: the Hub menu's link to Agents not confirmed); read 0 |
| IO-74 | edition | `##class(%Dictionary.ClassDefinition).%ExistsId("HS.InteropTools.HL7.GenerateDTL.UI.List")` (A:90); read 1, cleared on IRIS for Health |
| IO-75 | demand | no edition check found: the menu lists it on every instance (A:79) |
| IO-76, IO-77 | edition | a Message Bank server to link to: `$Data(^Ens.MsgBankSvr)` non-zero there (A:65); offered on non-bank instances (A:82, A:113-124, `EnsPortal.FindMsgBank.GetBankLink()`) |
| IO-78, IO-79 | edition | `$Data(^Ens.MsgBankSvr)` non-zero on this instance (A:100-102); read 0 |
| IO-80, IO-81 | edition | `$Data(^Ens.Enterprise.MonitorClientD)\10` true (A:66, 104, 144); read 0 |
| IO-90 | edition | `##class(%Dictionary.PackageDefinition).%ExistsId("ITK.Setup")` (A:216); read 0 |
| LG-13, SA-59, SO-18, SO-19 / AN-18 to AN-22 | deprecation | an owner decision to support shadowing / iKnow Text Analytics despite deprecation |
| SA-53 to SA-58 | demand | cluster, InterSystems Reports, Zen Reports: a recorded request |
| WA-17 | platform | `$$$ISWINDOWS`, which is `($zversion(1)=2)` (`%sySite.inc:16`; `%CSP.UI.Portal.Application`:291, `%DB_IRISSYS:READ` at :281); read 3 |
| OS-34 | platform | same check; the menu always lists it and the page is read-only off Windows (`Config.Telnet`:29, 52) |
| OS-31, OS-32, OS-33 | demand | low usage; OS-31 and OS-32 are admin-v2 backed, the cheapest with SA-50 |
| IO-72 | vendor-page | legacy (pre-2012), not on a menu |
| IO-73, IO-82 to IO-89 | demand | adapter dialogs, PubSub, DICOM, non-HL7 EDI authoring |
| AN-23 | demand | links ship (AN-04 to AN-06, Story 20.32; three descriptors compiled on slot B); a request the links cannot answer |
| EX-55, EX-56, EX-57 | demand | no OcuPilot link exists yet; the classic portal serves them |
| SH-29 | demand | cosmetic |
| SA-60, SA-61, AN-24 | vendor-page | not on any menu, commented-out menu item, dead code |
| SA-62 | vendor-page | each class the catalog cell names: `##class(%Dictionary.CompiledClass).%ExistsId("<name>")` returns 1 on a supported release |
| DT-12 | dependency | a debugger implementation (the harvested tool is a placeholder) |
| EX-58 | not-applicable | OcuPilot runs in the instance it administers (AD-1, AD-2) |
| PK-26 | dependency | IRIS AI Hub available outside early access on Community Edition |

**Decided in-stage:**

- Form and location: one Markdown document in `docs/`, inside the footprint, linted by the existing glob, readable by Story 22.2 and people, and parseable; a separate data file would be a second artifact to keep equal.
- Drift guard: both sides of every equality are derived from the catalog and the extract.
- The eight gate kinds above. IO-75 takes `demand` though grouped as edition-gated, because the vendor checks nothing; the group is kept.
- SS-40 and IO-74: the vendor's check reads cleared on IRIS for Health; the register records it and the rows stay P4 (demand still needed; a pick-up is Story 22.2's).
- AN-23 (checked): delivered as links in the repository and compiled on slot B; the rebuild stays excluded. EX-55 to EX-57 have no link; adding one is product UI and out of scope.
- No pointer from `README.md` (user-facing) or `docs/DEVELOPMENT.md` (cited by line from `ci.test.mjs`).
- Concurrency: `origin/OCU-1-epic21` has no commit beyond the feature branch, so no file is contended.
- Ledger inbox: none.

## Verification

**Commands:**

- `(loop)` `cd ui && node --test tools/exclusion-register.test.mjs` -- expected: all pass.
- `(loop)` `bash scripts/lint-docs.sh` -- expected: exit 0 (covers the new document and this spec).
- `(loop)` `cd ui && node tools/client-lint.mjs` -- expected: exit 0 (no literal non-ASCII in the new `.mjs`).
- `(once)` `cd ui && npm run test:tools` -- expected: all pass.
- No ObjectScript sweep: the story touches no ObjectScript. No browser spec; the full browser suite is left to CI.

**Shared surfaces:** none. Every test added or changed passes on a fresh environment, in either order.

**Pinning tests and planned mutations (Rule 19):**

- mutation: deleted the IO-85 row -> `the register holds exactly the catalog P4 rows, each once` went red naming IO-85 as missing (the group test went red too, naming the group that lost it); reverted.
- mutation: moved the SH-29 row into the sharding group -> `each register group holds exactly the extract group of the same position` went red naming that group and SH-29; reverted.
- mutation: removed the backticks from SA-50's how-to-tell -> `a license, edition or platform gate names a runnable check` went red naming SA-50; reverted.
- mutation: set AN-23's kind to `rebuild` -> `every row names a gate kind from the Gate kinds table` went red naming AN-23; reverted.
- mutation: replaced AN-23's reason with "Full applications." -> `AN-23 says the three analytics links ship and that rebuilding stays excluded` went red; reverted.
- mutation: removed IO-76's "The vendor's interoperability menu evaluates it" sentence -> `a license, edition or platform gate names a runnable check` went red naming IO-76; reverted.
- mutation: duplicated the SA-51 row -> `the register holds exactly the catalog P4 rows, each once` went red naming SA-51 as listed twice; reverted.
- mutation: added a row with a non-P4 id (SA-01) -> the same test went red naming it as not P4; reverted.
- mutation: blanked SA-52's reason -> `every row carries a reason, a gate and a way to tell it has cleared` went red naming SA-52; reverted.
- mutation: removed the deprecated feature from LG-13's gate -> `a deprecation gate names the deprecated feature and the owner decision that clears it` went red naming LG-13; reverted.
- mutation: renamed the `## The register` heading -> `the parsers read something from every document` went red; reverted.

**Manual checks:**

- Each row's reason matches its catalog Evidence cell; each slot B value was re-read with `server: "ocupilot-slot-b"`, read only.

## Auto Run Result

Status: done
Blocking condition: none

Added `docs/exclusion-register.md` (56 P4 rows in eight groups, with a Gate kinds table) and `ui/tools/exclusion-register.test.mjs` (10 tests: row set, extract grouping and epics wording, row completeness, kind vocabulary, runnable check with vendor source and slot B reading, deprecation, AN-23, parse floors). No other file changed; no planning document, product string or IRIS write.

Review: 4 medium and 4 low patched (all in the register wording and the test; see the triage log), 6 low rejected. Follow-up review recommended: true, because four medium patches changed register wording that no second layer re-read.

Verified: `node --test tools/exclusion-register.test.mjs` 10 of 10; `bash scripts/lint-docs.sh` exit 0; `node tools/client-lint.mjs` exit 0; eleven mutations each red and reverted, files byte-identical (checksums). Slot B reads on 2026-11-14 matched the Design Notes; added reads: `IsPackageInstalled` for X12, ASTM, DICOM, SEF, XML and HL7, all 1. Vendor line cites differ from the Design Notes by one line: `%sySite.inc:17`, `EnsPortal.Application` 66 and 67.
