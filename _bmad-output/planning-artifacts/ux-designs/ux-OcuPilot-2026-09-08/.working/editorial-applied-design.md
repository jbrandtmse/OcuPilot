# Editorial punch list applied — DESIGN.md

Target: `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/DESIGN.md`
Applied 2026-09-08. Lines 1243 → 1278. Words 15,652 → 16,152 (the open-items index, five group
orienting lines and the composition rule add more than the condensations remove).

Frontmatter untouched: parses as YAML, `status: draft`, all 42 `components` entries present in
their original order, every key and value byte-identical to the pre-edit file.

## Structural changes

| # | Item | Status | Notes |
|---|---|---|---|
| 1 | Split the contrast table | applied | Four counter-evidence rows moved out of the relied-on table into a new sub-table under the bold lead-in **Measured and rejected — never drawn**, with a one-line rationale. `secondary` / `code-surface` stayed in the relied-on table. The first moved row's inline "— **never drawn**" was trimmed as redundant with the new heading; nothing else in the rows changed. |
| 2 | Move the OpenAPI path-and-verb browser under `data-table` | applied | Cut from `log-viewer`, placed after `data-table`'s row-state table. Subtitle gained "in the REST API explorer" so the moved block still says where it lives. |
| 3 | Condense `focus-ring` | applied | Now anatomy → three grounds (surface/sheet, chrome, code) → inset rule → `:focus-visible` rule → skip link. Eleven reproduced ratios replaced by a pointer to §Colors › Contrast. **No ratio was unique to the entry** — every one is carried by the Contrast tables, and the 1.18:1 light-ring-on-chrome figure is carried by Colors rule 1 — so none was kept; the entry now cites rule 1 for that prohibition. |
| 4 | Orienting line under the five `###` group headings | applied | Shell, Screen, Panel, Feedback and dialogs, Focus. `### Buttons` already had an intro and was left alone. |
| 5 | Front-load §Brand & Style | applied | **Foundation.** paragraph moved to directly after the opening positioning paragraph; the precedence sentence follows it as its own paragraph, reworded to "This document and EXPERIENCE.md take precedence over any mock, wireframe or import." Removed from the section's tail. |
| 6 | Collect the open items | applied | Nine-row index at the end of the §Components intro: marker kind, where it lives, the one-line ask. Assumptions that surface in several places (status bar, log rows, form widths) are one row naming every site. All three `[NOTE FOR ARCHITECTURE]` rows — the two installer notes and the auditing note — are marked **Release-blocking**. Every inline marker stayed in place (10 `[ASSUMPTION]`, 3 architecture, 1 PRD in the body; the index adds one mention of each). |
| 7 | State the composition rule | applied | Added to the §Components intro, naming all five compositions. |
| 8 | Merge the duplicated Do cells | applied | Three pairs merged (gradient, yellow, `restrained`); the two rows of each pair are now adjacent and the second carries an empty Do cell, the markdown idiom for a row-span. All six Don't cells kept, distinct and in their own cells. Row count unchanged at 24. |
| 9 | Condense frontmatter restatements | applied | `toast`: dropped "360px wide" and "elevation 3". `skeleton`: dropped "1.2s ease-in-out" (the 40 / 25 / 15% bar widths are prose-only and stayed). `attention-dot`: dropped 8px, 1.5px and the 2px offset. Token names and every prose-only fact — including all contrast ratios — kept. |
| 10 | Reduce the reference-only import rows | applied | Five rows (`Logo.jpeg`, `Logo-full`, `Logo-web`, `Logo-transparent`, both wordmarks) collapsed into one **Reference only — not rendered in the UI** provenance row that names each file, its dimensions, its role and which of them are flood-fill cutouts of the master. Rendered assets keep their own rows; sizes and placement removed from the reversed-lockup, light-lockup, mark, favicon and robot rows and replaced with a pointer to `logo-lockup` / `avatar-agent`. |
| 11 | Leave the three wordmark statements, `panel`, `proposal-card`, inline ratios at full length | applied (no-op) | Nothing deduplicated there. `panel` and `proposal-card` were re-punctuated only (items below), not cut. |

## Wording fixes

| Fix | Status | Notes |
|---|---|---|
| `rail-item` tooltip pair reversed | applied | Now `{colors.inverse-on-surface}` on `{colors.inverse-surface}`, matching the frontmatter and the "<text> on <background>" convention. |
| `avatar-agent` file rule explicit | applied | "the 256px file, or … the 64px file, wherever it renders below 32px". |
| `proposal-card` Expired "No opacity fade anywhere." | applied | |
| §Components intro missing commas (two) | applied | |
| `status-bar` recast | applied | Left group's four items in one list; the account-menu detail is its own sentence. |
| `panel` footer sentence | applied | Lead sentence plus a three-item bulleted list (read-only status line; composer with Send; caption line). No content cut. |
| `header` "spanning the full width above the rail and the panel" | applied | Matches §Layout & Spacing. |
| Yield order "the row between the header and the status bar" | applied | |
| `confirm-dialog` document path not the subject | applied | "the set of dialogs listed in EXPERIENCE.md › …". |
| `locator-bar` "40px under the header" | applied | |
| Contrast **4.497:1**, parenthetical dropped | applied | |
| Buttons intro "the inner halo" | applied | |
| `diff-row` "in this document and in EXPERIENCE.md" | applied | |
| `panel` auditing note "(memlog assumption)" dropped | applied | |
| Rail order lists with `·` | applied | Both §Layout & Spacing and `rail`. |
| `proposal-card` Diff measure leads | applied | "The card's default height is two changed rows and one disclosure line, whatever the payload carries." |
| "direction **A, Bridge**" | applied | |
| `attention-dot` three parallel triggers | applied | "the agent is unconfigured, the kill switch is on, or a definition needs attention". |
| §Brand mark sentence split into three | applied | |
| `toast` "because the inverse surface flips" moved beside the swap | applied | |
| "Known cosmetic flaw:", outline called teal | applied | |
| `logo-lockup` motif assignment stated once, agentlessly | applied | Also removed from the favicon table row. |
| Two `[ASSUMPTION]` parentheticals scoped | applied | "(the assumption is the widths; the sticky bar itself is decided)" and "(the thresholds, not the behavior)". |
| §Layout Home re-punctuated | applied | Width and transition in one sentence; the formula follows in its own. |
| "outline borders controls" | applied | "`outline` draws the borders of controls". |
| `restrained` role parallel phrasing | applied | "The agent holding back, and the portal holding something back…". |
| Rule 7 "it is what a reloaded transcript consists of" | applied | "a reloaded transcript is made of them". |
| Form-login "The state stays for other users." | applied | "The expired-password state stays in the design regardless, because other users can meet it." |
| `data-table` on/off → enabled/disabled | applied | |
| OpenAPI browser tautology | applied | "teal is reserved for actions and the status roles for status". |
| `classic-link-card` "naming what is only there" | applied | "naming what only the classic portal offers". |
| `proposal-card` footer "(who the write runs as)" | applied | Dropped; it duplicated the "Runs as <user name>…" caption two clauses earlier. |
| Repeated "this document" fifteen words apart | applied | §Colors Contrast lead-in. |
| Expand `UJ-3` and `OFL` at first use | applied | UJ-3 at its first mention (the `key-webapps-proposal` row) now reads "the climax of UJ-3, the demo journey in which the agent fixes a disabled web application"; the second mention keeps the bare ID. OFL expanded in §Typography's opening sentence to "the SIL Open Font License (OFL)". The frontmatter typography comment still says "both OFL" — frontmatter was held byte-identical by constraint. |
| `server-flag-badge` clipped flags and "reads as such" | applied | "one pair per flag: Live on red (`{colors.server-flag-live}` on `{colors.server-flag-live-container}`), Test on amber, Failover on violet, Development on green"; "reads as production at a glance". |
| "the contest's parentheticals" named | applied | "the screens the contest task statement names in its parentheticals". |
| One consistent image-dimension style | applied | "at 256 and 64 px" → "at 256px and 64px"; every other dimension already used `N×N px`. |
| `empty-state` doubled "saying" | applied | Second becomes "telling the reader what to do next". |
| `command-bar` "need a selection … until a row is selected" | applied | "Actions that act on a row are unavailable (38%) until one is selected". |
| `logo-lockup` "Variants:" nesting | applied | Recast as a sentence with the slot-width aside set off by dashes. |
| Rule 2 "the eye's reading of the artwork" | applied | "the artwork's left-to-right reading", with the paired stripe now "the docked panel's top-to-bottom reading". |
| "in this file" → "in this document" | applied | Two occurrences, both in the Visual references table. |
| `panel-resize-handle` back-to-back dash asides | applied | Split into two sentences. |
| "which is not a token on purpose" | applied | "deliberately kept out of the token set". |
| "win on conflict with" → "take precedence over" | applied | One occurrence in this document (the §Brand precedence sentence). EXPERIENCE.md carries its own copy of the phrase; not touched, per instructions. |
| `confirm-dialog` "else on Cancel" | applied | "or on Cancel where the dialog has none". |
| One consistent ratio notation | **partly skipped** | The explicit case (4.497) was applied. A document-wide sweep was judged ambiguous and skipped: the tables deliberately drop `:1` on multi-value `·`-separated rows and keep it on single-value rows, and the prose mixes bare `X:1 / Y:1` pairs with labelled "X:1 light / Y:1 dark" pairs — the punch list explicitly protects the labelled form, and there is no stated target for the rest. Normalizing would have touched ~30 sites with no rule to point at. |
| One consistent style for padding values | **partly applied** | Applied the one unambiguous case: `panel` used both "padding `<value>`" and "`<value>` padding" in the same entry; both now read "`<value>` padding", which is the document's dominant order everywhere else. The deeper inconsistency — literal px pairs (`8px 12px`) alongside token pairs (`{spacing.2} {spacing.3}`) — was left: both styles are used heavily, several shorthands necessarily mix a token with a non-token literal (10px, 6px), and the punch list names no target style. |

## Things the punch list missed

1. **The Contrast tables use two ratio conventions on purpose**, and the document never says so. Single-value rows write `5.42:1`; multi-value `·`-separated rows write bare numbers. A one-line note above the first table would stop a future editor "fixing" it. (Left alone — adding it is content, not organization.)
2. **Rule 7 and the rejected-pairs table disagree on the same measurement.** Rule 7 says the 60%-opacity expired card "measured 2.6–4.4:1"; the table's light row measures `4.38 · 2.89 · 3.04 · 2.77 · 3.38` — a 2.77–4.38 range. Both were left untouched (numbers are sacrosanct), but one of them is wrong and the owner should reconcile them.
3. **The frontmatter typography comment still abbreviates OFL** and still says "in either face"; the frontmatter hold prevented touching it, so the expansion lives only in the body.
4. **`{colors.error}` vs `{colors.destructive}` are the same hexes today** and `severity-chip` uses `error` while `tool-call-card` uses `destructive` for the same visual red. That is deliberate per the §Colors note, but nothing in §Components says which role a new component should reach for.
5. **`banner` sits in the Panel group** though it is used in forms and the content column too; the new group line names the overlap, but the placement itself may want revisiting.
6. **The `panel-home` formula appears twice in two notations** — `calc(100vw - …)` in the frontmatter and `viewport − …` (with a minus sign, not a hyphen) in §Layout & Spacing. Consistent enough to read, but a reader diffing them will pause.
