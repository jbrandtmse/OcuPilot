# Polish applied: OcuPilot PRD addendum

Applied on 2026-09-08 to `addendum.md` from `polish-structure-addendum.md` (structure pass first) and `polish-prose-addendum.md` (prose pass second), under the owner's acceptance decisions. Only `addendum.md` was modified; `prd.md` was read for the section-reference check and not edited.

## Word counts

| Measure | Before | After | Delta |
| --- | --- | --- | --- |
| `word_metrics.py` total | 6,347 | 6,442 | +95 |
| Same, excluding table pipe characters (the script counts each `\|` as a word) | 5,896 | 5,949 | +53 |
| Pipe characters | 451 | 493 | +42, all from the new Names-to-avoid table in section 6 |
| Section 1 | 1,586 | 1,572 | −14 (condenses −105, lead and forward pointers +91) |

The reviewer projected about −277 net. The shortfall is deliberate: the owner's constraint (keep every outcome, name, number, date and FR/OQ reference in every decision) meant decisions 21 and 22 kept their invariant list and their dates in compressed form rather than being replaced by requirement references and a pointer to PRD 10.1, and the four additions (routing line, section-1 lead, forward pointers, open-for-architecture tags) landed at the reviewer's estimated size. Per-decision word counts, before to after: 16: 99 to 83; 17: 146 to 138; 18: 137 to 134; 19: 131 to 124; 21: 201 to 194; 22: 217 to 192. Decisions 2, 5 and 10 grew by the forward pointers and one prose fix (+10, +5, +2).

## Section renumbering map

| Before | After | Section |
| --- | --- | --- |
| 1 to 11 | 1 to 11 | unchanged |
| 14 | **12** | Stages 2 through 6, row detail (moved to follow 11) |
| 12 | **13** | Full risk register |
| 13 | **14** | Contest facts |
| 15 | 15 | Feasibility budget (finalize), unchanged |

In-document references after renumbering (all checked): bare "section N" now always means this addendum (sections 1, 2, 3, 6, 15 in decisions 16, 18, 19, 22; section 1 in section 12), and every reference to the PRD is prefixed "PRD section" or "the PRD's section" (10.1, 8, 10.3, 12). Decisions 17, 19 and 22 previously said "section 10.1" and "section 8" for PRD sections; those now read "PRD section 10.1" and "PRD section 8" so they cannot be misread against the renumbered addendum. The new routing line uses the new numbers (13 for the risk register, 12 for the stages detail, 14 for contest facts). No reference names a section that no longer holds the named content.

## PRD references to addendum sections

`prd.md` was grepped for "addendum, section N", "addendum section N" and "(addendum, section N)". Four numbered references exist and **none needs updating**, because every one points at a section whose number did not change:

| PRD line | Reference | Old | New | Status |
| --- | --- | --- | --- | --- |
| 818 | "(addendum, section 6)" | 6 | 6 | correct |
| 997 | "(addendum, section 15)" | 15 | 15 | correct |
| 1084 | "the budget in the addendum, section 15" | 15 | 15 | correct |
| 1120 | "recorded in the addendum, section 1" | 1 | 1 | correct |

Three further mentions (lines 950, 972, 1079) say "in the addendum" with no section number and need nothing.

## Structure pass: rows applied

| Row | Action | Notes |
| --- | --- | --- |
| Token-lifetime bullet to the head of §2 | MOVE, applied | Now the first bullet; its lead-in reads "(open for architecture; Open Question 17, due 2026-09-09)". §2's intro sentence was adjusted to say the open decision comes first and the transport facts follow. |
| Forward pointers on decisions 2, 5, 16 | applied | Decision 2 "(the per-user toggle is deferred to step 7, decision 22)"; decision 5 "(closed at finalize, decision 18)"; decision 16 "(section 3)". |
| Routing line in the preamble | QUESTION, accepted and applied | "**Routing.** Architecture: sections 2, 3, 4, 6, 7 and 13. UX: 7 (header strip) and 8. Stories and build: 3 (the write-payload directive), 5, 10, 11, 12 and 15. Contest: 9 and 14." Numbers are post-renumbering. |
| Decisions 16 to 19 condensed to outcome lists citing the reconcile files | CONDENSE, applied | Each cites its file once (`reconcile-brief.md`, `reconcile-idea-readme.md`, `reconcile-research.md`, `reconcile-catalog.md`). Every outcome, FR, UJ, OQ, row ID and path kept. Narration dropped: "is stated as", "now matches", "no longer assert" phrasing and decision 19's "(as renumbered at finalize)" aside. |
| Decision 21 condensed | CONDENSE, applied within the owner's constraint | Added the source (`review-agent-safety.md`) and the requirement locations (PRD 5.3, 7.1, 7.3, NFR-6); the three facilitator judgments are verbatim. The invariant list was compressed, not replaced by references, because the owner requires every outcome kept. 201 to 194 words rather than the reviewer's 105. |
| Decision 22 condensed | CONDENSE, applied within the owner's constraint | "PRD section 10.1 is the build order and the cut line" replaces the build-order narration, but the three dates (2026-09-14, 2026-09-27, 2026-09-23) stay in a parenthetical and the step-7 hardening list stays, both being numbers or outcomes the owner protects. 217 to 192 words rather than 130. |
| Section-1 lead | QUESTION, accepted and applied | "Read first: decision 22 …, decision 21 …, decisions 1 and 2 …, decision 20 …. The rest are recorded in the order they were made." |
| §15 closing paragraph | CUT first sentence; MOVE second, applied | The OQ15 verdict now closes §2's "Unobserved direction" bullet. |
| §14 to follow §11; placement sentence condensed | MOVE and CONDENSE, applied | Now §12. The numbering-offset explanation is kept; the placements now carry their own decision numbers (streaming, decision 7; Analytics, decision 8), fixing the reversed pairing the prose pass flagged. |
| §9 competitive summary | PRESERVE with one CUT, applied | Table and prior-art paragraph kept; "The field is empty as of 2026-09-08." cut (duplicated by the contest-facts Field row). |
| "(open for architecture …)" tags in §6 | QUESTION, accepted and applied | Docker bullet lead-in: "**Docker (open for architecture; Open Question 5).**" (PRD OQ5 confirmed as the build-versus-start question). State-protection lead-in: "**Protecting OcuPilot's state (FR-29, FR-66; open for architecture).**" |
| §3 directive sentence to the front of the payload paragraph | MOVE, applied | The row-ID list now follows the directive as its checklist. |
| §1 opening: cut "The eight decisions inherited from the brief are not restated." | CUT, applied | The surviving sentence takes the prose pass's "The decisions below were set by the owner …". |
| §10 note condensed | CONDENSE, applied | "The table shows catalog tiers. After decision 15 (CP-28 to Stage 2), the polish week carries 61 rows and Stage 2 carries 60." |
| REST-path resolution, decision 19 and §6 | MERGE, applied | §6 keeps the full version with the reasons; decision 19 ends "the catalog's REST-path inconsistency is resolved to `/api/ocupilot` (section 6)". |
| alerts.log endpoint, decision 16 and §3 | MERGE, applied | §3 keeps the reason; decision 16 reads "a fourth custom endpoint, the alerts.log tail, kept (section 3)". |
| §6 "Names to avoid" as a two-column table | CONDENSE (format only), applied | Table of Kind and Avoid with 11 kinds and a final bold "OcuPilot uses" row; every name kept verbatim, including `%ALL` mapping creation, the `iris_*` prefix and `IRIS_*` variables. The REST-path inconsistency sentence follows the table as its own paragraph. |
| §5 "New for OcuPilot" as a grouped list | CONDENSE (format only), applied | Four groups (Shell, Agent surface, Write model, Install); all 22 items placed once, none dropped or reworded beyond the spelling fix. |
| §12 risk register, decision 10, §15 caveats, §4, §7 header strip | PRESERVE, no-ops | The optional "(for UX)" tag on the header-strip bullet was not added: PRESERVE rows are no-ops and the routing line already names "7 (header strip)" for UX. |

## Prose pass: rows applied

All 17 definitive rows applied. Of the 11 Consider rows, 11 applied (none skipped):

| Row | Type | Applied as | Notes |
| --- | --- | --- | --- |
| "The vendor's bundles refresh at" | definitive | yes | §2 Tokens. |
| "visiting `%SYS` without a parameter redirects" | definitive | yes | §7. |
| Custom-endpoints list reordered so the seven are countable | definitive | yes | §3; the progress-channel rationale moved to the end of the parenthetical. |
| "Investigate" quoted as a label | Consider | yes | §8; matches the document's quoting of "Did you know". |
| "The twelve (SS-14 and LG-02 are one row):" | Consider | yes | §10; applied exactly as proposed, so the "(= LG-02)" marker after SS-14 also remains. |
| "and for IPM 0.10.x, and `${globalsDbRole}`." | definitive | yes | §6 IPM module. |
| "mirror menu leaves" | Consider | yes | §7; confirmed against `research.md` line 111, "the five Mirror leaves depend on the mirror-service state" (menu leaves). |
| Section 14 decision-number pairing and the "and so on" comma | definitive | yes | Absorbed into the condensed §12. |
| "the write tool of a large editor that is cut still ships" | definitive | yes | Absorbed into decision 17. |
| "on disabling the web service and on disabling auditing" | Consider | yes | Decision 10; confirmed against PRD lines 590 and 644, two warnings both about disabling. |
| "calls for a 300 s gateway timeout" | Consider | yes | §6. |
| Numerals for 10 and above: "12 (11 distinct)", "11 validation rules" (§5 table and §8), "top 10", "10 seconds" | definitive plus one Consider | yes, all five | Owner directed applying the numerals rows; "one second" and "two seconds" stay as words. The §5 harvest-table cell changed only in the spelling of the number. |
| "44-entry allow-list" | definitive | yes | §7. |
| "synchronization", "license" | definitive | yes | §5 list and the §13 risk-table Contest-terms row. |
| Serial commas removed in decision 3 and §3 | Consider | yes | The document's dominant convention (no serial comma) chosen; the comma before "and ObjectScript under" in §6 was kept as the review notes, though that sentence is now the table's last row. |
| "The decisions below were set by the owner" | Consider | yes | §1 opening. |
| "kept; both rows are small" | definitive | yes | §11. |
| "must map back to those keys, or existing assignments are lost" | definitive | yes | §7. |
| Decision 21 lead-ins ("folded into the requirements as added precision", "within those findings") | Consider | yes | Absorbed into the condensed decision 21. |
| "key guidance in the README" | Consider | yes | Absorbed into decision 22. |
| "visible improvement between listing and deadline, not a daily quota" | definitive | yes | Absorbed into decision 16. |
| "but only if" | definitive | yes | §2 Minting. |
| "as the single source of truth" | definitive | yes | §6 Docker. |
| "the acceptance criterion, whatever the mechanism" | definitive | yes | §6 state protection. |
| "browser ID" (three places, one in the risk table) | Consider | yes | `CSPBrowserId` code spans untouched. |
| "not the portal's" | Consider | yes | §7 Long-running work. |
| "`VSCODE=1`, which hides the top bar" | definitive | yes | §13 risk-table cell, punctuation only. |
| "`HSCUSTOM` if present, else `USER`, on the IPM path too" | definitive | yes | Absorbed into decision 17. |

Prose rows skipped: none. The reviewer's observation that decision 22 says "about 45 developer-days" while the §15 total row says "46 to 47" was left as written, as the review itself directed.

## Verification

- `word_metrics.py`: 6,442 total (before 6,347); the section breakdown is in the summary above.
- Decisions 1 through 22 present, in order, each keeping its number and bold lead-in.
- Table rows per table, before and after (header row included): auth settings 9/9; API backing 7/7; tiered autonomy 6/6; harvest map 5/5; competitive summary 8/8; sizing 13/13; risk register 20/20; contest facts 12/12; feasibility budget 18/18; plus the new Names-to-avoid table, 13 rows, in §6. A sorted diff of every table line before and after shows exactly the expected differences: the 13 new Names rows and the four accepted in-cell prose edits ("license", "browser-ID", the comma after `VSCODE=1`, and "11 validation rules"). No row was added to, removed from or reworded in any protected table.
- Section-by-section comparison against the pre-edit copy: §4 and Contest facts byte-identical; every other section's diff hunks correspond to an accepted row listed above.
- No dangling "section N" reference: every bare "section N" resolves to the addendum section holding the named content, and every PRD reference is prefixed.
- Frontmatter: the six-line block is byte-identical (MD5 `1767a8f7cae6785202397c38cbcf7718` before and after); `updated` was not bumped.
- No em-dash or en-dash anywhere in the file; the `exp − iat` minus sign in §2 is unchanged.
- No remaining "synchronis", "licence", "whitelist", spelled-out "eleven" or "ten", or lowercase "browser id".
