# Polish applied: OcuPilot PRD

Applied on 2026-09-08 to `prd.md` and `addendum.md` from `polish-structure-prd.md` (structure pass first) and `polish-prose-prd.md` (prose pass second), under the owner's acceptance decisions 1 to 16. Only `prd.md` and `addendum.md` were modified; the frontmatter of both is unchanged (`updated` still `2026-09-08`).

## Word counts

| File | Before | After | Delta |
| --- | --- | --- | --- |
| `prd.md` (`word_metrics.py` total) | 17,313 | 16,854 | −459 |
| `addendum.md` (`word_metrics.py` total) | 6,442 | 6,968 | +526 |

PRD sections that changed, before to after: 0 Document Purpose 172 to 157; 1 Vision 394 to 380; new 1.1 Release 1 commitment, listing build and floor 274; new 1.2 Success Metrics 362 (moved intact); 2 Why Now 211 to 164; 5 Features intro 35 to 114 (the FR index); 6 NFRs 662 to 590; 7.1 Safety 205 to 147; 7.2 Privacy 130 to 110; 7.3 Cost 89 to 59; 8 Integration 366 to 329; 9 Non-Goals 178 to 146; 10.1 Release 1 build 1,155 to 627; 10.2 polish week 107 to 97; 10.3 Stages 927 to 482; 10.4 Out of scope 56 to 60; 13 Assumptions Index 128 to 18. Addendum: section 1 grew by the assumptions review record (1,572 to 1,711), section 12 by the per-stage inventory (91 to 479). The reviewer projected about −750 for the PRD; the difference is the FR index (+45), the consequences re-homed into FR-18, FR-19 and FR-20 (owner decision 13, net 0 by design) and the pointers left behind where passages moved.

## Section renumbering and reference changes

| Before | After | Section |
| --- | --- | --- |
| (new) | 1.1 | Release 1 commitment, listing build and floor |
| 11 | 1.2 | Success Metrics (body moved intact; heading `### 1.2 Success Metrics`) |
| 12 | 11 | Risks and Mitigations |
| 13 | 12 | Open Questions (item numbers 1 to 17 unchanged) |
| 14 | 13 | Assumptions Index (one pointer sentence) |

References changed, all checked after the edit:

- `prd.md` section 0: "section 14 records the outcome" replaced by "Inferences were tagged and resolved with the owner; see the addendum, section 1." (the only PRD reference to a renumbered section).
- `prd.md` 10.1: new lead line points to section 1.1; in 1.1 the floor paragraph reads "steps 0 to 4 (section 10.1)" and the feasibility sentence reads "every step of the build order (section 10.1)".
- `prd.md` build step 7: "(FR-17, section 7.3, NFR-6)" is now "(FR-17, FR-19, NFR-6)", because the turn limits moved into FR-19.
- `prd.md` FR-19 c.6: "(section 7.3)" replaced by the turn limits themselves with "(build step 7, section 10.1)".
- `prd.md` FR-72 c.5: "(section 7.2)" back-pointer dropped; "as recorded per ledger row (FR-21)" added, making FR-72 the canonical transcript rule.
- `prd.md` 10.3 table note: now points at "the addendum, section 12" for the per-stage screen inventory.
- `prd.md` section 13: pointer to "the addendum, section 1".
- `addendum.md` section 13: "the PRD's section 12 carries the top 10" is now "the PRD's section 11".
- `addendum.md` decision 22: the listing build and application floor are now cited at "PRD section 1.1"; 10.1 remains cited as the build order and cut line.
- `addendum.md` section 12 lead: sentence added introducing the per-stage inventory that follows.

No "§11" to "§14" forms existed in either file. "Open Question n" numbers were not touched. Every remaining "section 1x" string in both files points at an addendum section (12) or at the renumbered PRD section 11.

## Structure pass: 26 rows

| Row | Verdict | Outcome |
| --- | --- | --- |
| 1 | MOVE 10.1 opening, listing build, floor to 1.1 | Applied (decision 1). 10.1 keeps heading, build order, cut-editor paragraph, first-week decisions, submission plan, plus a one-line lead. |
| 2 | MOVE section 11 to 1.2; renumber 12 to 14 | Applied (decision 2). |
| 3 | CONDENSE stage bullets | Applied (decision 3). Five one-liners, 167 words including the bold stage names; the inventories are in addendum section 12, one paragraph per stage, every capability kept. |
| 4 | MOVE Assumptions Index; condense section 0 sentence | Applied (decision 4). "Assumptions review record" paragraph placed directly after addendum decision 15, cross-referencing decisions 9 to 15 and 21. |
| 5 | CUT streaming half of the PM note; MERGE Analytics sentence | Applied (decision 5). Analytics rider is in the Stage 4 one-liner. |
| 6 | CONDENSE scheduling sentences | Applied (decision 6) in FR-17 c.9, FR-19 c.2, FR-25 c.1 ("Anthropic first" kept), NFR-6 tail; 7.3's copy went with row 13. |
| 7 | CONDENSE 7.2 bullets; FR-72 canonical | Applied (decision 7). |
| 8 | CONDENSE NFR-3, NFR-8, NFR-10 | Applied (decision 8) with pointers FR-1 and section 8, FR-3, FR-13; NFR-10 keeps "the whole shell, panel included". |
| 9 | CONDENSE CP-28 to two statements | Applied (decision 9). CP-28 now appears in FR-71 and the Stage 2 one-liner only; removed from 5.12, 7.3, 10.2, the 10.3 table note and the assumptions stub. |
| 10 | MERGE sections 9 and 10.4 | Applied (decision 10). Section 9 holds seven permanent non-goals; 10.4 holds four Release 1 deferrals with their stages; the interoperability trio, free-form SQL and the multi-instance/mobile/localization items each appear once. The mobile tension is resolved as "in Release 1 or in any planned stage". |
| 11 | CONDENSE section 8 provenance and sibling sentence | Applied (decision 11). |
| 12 | CUT the 22-large-rows sentence | Applied (decision 12). Open Question 13 keeps it. |
| 13 | QUESTION re-home 7.1 b.3, 7.1 b.5, 7.3 b.3 | Applied (decision 13): switch reachability under FR-20, the prohibited set under FR-18, turn limits under FR-19; one-line principles remain in 7.1 and 7.3. |
| 14 | MOVE head-start bullet | Applied (decision 14) into the 1.1 feasibility sentence; section 2 has three bullets under "three reasons". |
| 15 | CONDENSE cut-editor sentence | Applied (decision 15). |
| 16 | CONDENSE section 1 tails | Partially applied: the "/api/admin v2 ... five of the six" mechanism clause is gone; the "nobody ships an assistant inside the IRIS portal" tail is kept because the prose lens lists that refrain as an intentional choice to keep. |
| 17 | CONDENSE 5.12 order sentence | Applied: "(order within the week: section 10.2)". |
| 18 | QUESTION section 5 FR index | Applied (+45 words); ranges verified against the headings. |
| 19 | QUESTION regroup closed Open Questions | Skipped: pulling items 6, 9 and 13 under a trailing sub-heading would renumber them when the Markdown list renders, so the numbers would not survive. |
| 20 | QUESTION FR-66 retitle or move c.6 to c.8 | Skipped: a retitle changes an FR heading, and a move would re-point the "smoke script (FR-66)" citations in 10.1 and section 11; left for the owner. |
| 21 to 26 | PRESERVE | No-ops. Row 25's NFR-6 sub-list rendering was not applied, being a PRESERVE row. |

## Prose pass: 38 rows

Applied (definitive): 1 (FR-17 c.1), 2 (FR-66 c.2), 3 (FR-71 "whether"), 4 (section 8 Atelier comma), 5 (UJ-4 "OcuPilot administrator", two places), 6 (FR-2 c.1 "vendor's editors"), 7 (7.1 tier parentheses), 8 (5.7 semicolons), 9 (FR-41 c.1), 10 (3.1 "read-only mode and the kill switch"), 11 ("audit database" in section 1 and both 3.1 places), 12 ("Release 1" in sections 1, 3.1 and 3.2), 13 (FR-26 c.4), 14 (UJ-6 toast), 15 (seven US spellings plus the FR-14 heading "synchronization"), 16 (UJ-5), 17 (section 8 semicolon), 18 (FR-11 c.3 rewrite; the optional bullet split not taken), 20 (FR-9 c.1; the 10.1 copy was absorbed by structure row 15), 26 (FR-47 c.1), 27 (FR-6 c.1 and FR-19 c.1 commas), 30 (FR-65 c.2), 34 (FR-52 c.2 "pulled from"), 36 ("the panel", at 1.1).

Applied (Consider): 19 ("(see Open Questions)" to Open Question 7, 7 and 5; mappings checked against the items' text), 21 (FR-72 c.3 "write tool-and-action key"), 24 (FR-23 c.3 one installer), 25 (5.8 "before the stretch step"), 28 (FR-12 c.2), 31 (section 1 "addresses"), 32 ("estimates the work at", at 1.1), 33 (FR-48 horizon), 35 (Open Question 12), 37 (UJ-1 edge case).

Skipped (Consider, in doubt): 22 ("rung": the proposed ladder gloss would assert an environment-variable-first order that FR-26 does not state, and "rung" is also the addendum's term in section 13); 23 (UJ-6 "suggested view": the owner knows which panel element is meant, and FR-70 is polish week); 29 ("username": owner's choice of form, and UJ-3 uses "user name"); 38 (numerals: representation only, but the owner's constraint on numbers makes this a doubt).

## Verification

- FR headings: 79, contiguous FR-1 to FR-79, in order; every consequence bullet's substance kept (moves: prohibited set to FR-18, turn limits to FR-19, switch reachability to FR-20; transcript rule canonical in FR-72).
- References: every FR-n, UJ-n, SM-n (1 to 6, C1 to C3), NFR-n (1 to 14) and Open Question n (1 to 17) reference in `prd.md` resolves to an existing heading or item; Open Questions 1 to 17 present in order.
- Catalog row tokens (`[A-Z]{2}-[0-9]+`): `prd.md` set after equals the set before (245 tokens; none lost, none gained); `addendum.md` lost none and gained FR-11, FR-72 and UJ-4 from the assumptions review record.
- Stale section references: none; the changes are listed above.
- Frontmatter: unchanged in both files. Logo block: unchanged. Glossary: 38 terms, same set, same order.
- Em-dashes: 38 before and after in `prd.md` (all glossary separators); 0 in `addendum.md`. No em-dash introduced into running prose.
- US spelling: no "synchronis", "cancell", "acknowledgement" or "licence" remains outside code spans; "audit log", "first release", "instance administrator" and "agent panel" no longer occur.
- CP-28 occurs twice in `prd.md` (FR-71 and the Stage 2 one-liner).
- No failures.
