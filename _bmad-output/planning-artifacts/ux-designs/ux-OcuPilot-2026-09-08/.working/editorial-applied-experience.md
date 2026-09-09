# Editorial punch list — EXPERIENCE.md — applied

Target: `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md`
630 lines before → 708 lines after. DESIGN.md untouched (read only, to resolve `{token}` references and the `command-box` cross-reference).

## Structural changes

| # | Item | Status | Note |
|---|---|---|---|
| 1 | Contents list + ownership rule in the intro | applied | Two paragraphs after the opening: **Contents.** (15 sections in final order) and **Where each kind of fact lives.** naming the seven owners plus "Component Patterns owns everything else", with the rule that a non-owner states the trigger and points at the owner. |
| 2 | Move §Agent Write Lifecycle and §Privilege Gating after §Information Architecture | applied | New H2 order: Foundation · Information Architecture · Agent Write Lifecycle · Privilege Gating · Voice and Tone · Component Patterns · State Patterns · Interaction Primitives · Screen Synchronization and Live Data · Session and Sign-in · Accessibility Floor · Responsive & Platform · Inspiration & Anti-patterns · Open items · Key Flows. No `above`/`below` cross-reference pointed at either moved section, so none needed reversing (checked every occurrence of both words). |
| 3 | Promote six oversized cells to `####` subsections | applied | `command-box` · `data-table` · `panel` · `proposal-card` · `banner` · `form-page`, in table order, beneath the table. Each keeps a one-line summary row ending "→ `<name>` below."; the table still lists all 42 components. The preamble names the six. |
| 4 | Merge the ten proposal rows of §State Patterns › Panel into §Agent Write Lifecycle | applied | Rows 11–20 (Proposal live/confirmed/canceled/expired · Target changed · Destructive · Secret · Read-only blocked · Enforced read-only indicator · Kill switch) reduced to trigger + one-phrase visual + "→ Agent Write Lifecycle *n*", exits kept. Facts migrated into the steps: "Send is a primary again" (3); restrained treatment and focus-on-status-line (4); "roles, never opacity — the diff stays readable at AA" and Re-propose = button-secondary (5); status line receives focus (6); the enforced read-only banner string, `{colors.restrained}` and the footer line (7); the kill-switch banner string, read-only transcript, focusable/`aria-disabled` composer and Send, focus move (8); Confirm is button-destructive and `aria-disabled` until the typed name matches, secret required before Confirm and the diff masked "••••••••" (2). |
| 5 | §Screen Synchronization and Live Data made authoritative | applied | Opening line states the authority and its scope. Thinned: State Patterns *Changed*, *Off-screen change toast*, *Auto-refresh paused*, *Async values arriving*; component cells `toast` and `log-viewer`. The `[ASSUMPTION: settle timing]` and bare `[ASSUMPTION]` markers were re-added to the two thinned rows so all 21 stay inline (see Deviations). "the table never reflows" moved into the *Async values* bullet. |
| 6 | Cut *Form login card* and *Sign out* from §Session and Sign-in | applied | Both were fully carried by the Surfaces table and the Shell/Session state rows. Mockup pointer, *Silent retry before the form*, *Values lost on a failed refresh* and *First-login gate* kept. |
| 7 | Cut six third-statement bullets from §Interaction Primitives | applied | *Send and Stop* · *New conversation* · *Selection* · *Resize* · *Command box* · *Side-bar toggle*. Two facts were not fully carried elsewhere and were preserved before the cut: "the Send button mirrors Enter" → `panel` subsection footer; "Single selection everywhere in Release 1 (Broadcast's multi-select is P1)" → `data-table` subsection. Kept: *Keyboard model*, *Mouse*, *Undo by Back*, *Confirmation gestures*, *Refresh*, *Banned everywhere*. |
| 8 | One owner for the size numbers | applied | Removed "(240 px)" from the `side-bar` cell — the only shell size number repeated in Component Patterns. Preamble adds "Sizes are cited as tokens; the pixel values are in Responsive & Platform." Foundation's shell table keeps its numbers. The remaining `px` in Component Patterns are not shell sizes (logo 32 px, resize step 16 px, empty-state icon 32 px) and were left. |
| 9 | Condense the duplicated key bindings | applied | §Interaction Primitives' keyboard table is the single home. `data-table` keeps `role="grid"`, one Tab stop, `aria-activedescendant` and the virtual-scroll rationale, plus "moving the active row also selects it", and points at the keyboard table. Accessibility Floor › *Tables* keeps the same rationale plus "Selection and sort state are announced." ("Sortable headers announce the sort" folded into that single statement.) |
| 10 | Condense Accessibility Floor › *Gated controls stay reachable* | applied | Now a one-line pointer at Privilege Gating › *Mechanism* with the two load-bearing facts (`aria-disabled` in the Tab and arrow order, never `disabled`, reason always announced). |
| 11 | Widen the canonicality clause in §Voice and Tone | applied | The table is canonical over `DESIGN.md` **and** over every inline quotation in this document; Component Patterns, State Patterns and Key Flows quotations are illustrations, not second sources; an illustration may resolve a placeholder (as UJ-3 resolves `<user name>` to `_SYSTEM`) but may not respell the string. |
| 12 | Move the auditing-off note; add an Open items table | applied | The `[NOTE FOR ARCHITECTURE]` now sits in §Foundation as **Install prerequisite — auditing.** New §Open items before §Key Flows indexes all nine markers (marker · section · one-line ask). All 21 `[ASSUMPTION]` markers left inline; the preamble says so explicitly. |
| 13 | Condense UJ-3 step 3 | applied | Points at Component Patterns › `proposal-card` for the anatomy and keeps only the demo values: the header, the two diff rows, "38 unchanged fields", the rationale and expected-impact text, the reversal line, "Expires in 9:59", plus the message ending, Send demoted, and the paused auto-refresh chip. |
| 14 | Keep the Step / tier column, side-bar lists, six UJ narratives, Do/Don't table | applied | Legend now reads: build step, then "the step number is inherited from PRD §10.1, which is authoritative if the sequencing changes". |

## Wording fixes

| Item | Status | Note |
|---|---|---|
| §Foundation `rail` row: `·` separators; split Home/Agent co-pilot | applied | "Agent co-pilot behaves the same way. Home is the exception: …" |
| §Screen Sync off-screen toast recast (bus does not cross tabs) | applied | Exactly as specified. |
| `data-table` "recycled row" → virtual scroll cannot recycle a focused row | applied | |
| Six drifting quotations aligned to *Fixed strings* | applied | Test connection reply `<the model's first words>`; kill-switch `<reason>`; rail tooltip `"<Area> · Ctrl+B toggles the side bar"` (⌘B on macOS); reduced-motion lower-case "running"; UJ-1 chip gains `· 6 rows`; UJ-6 timestamp resolved to "Confirmed by _SYSTEM · 09:14:22". |
| `message-agent`: stop using "inert" loosely | applied | "external links are not auto-activated — the full host stays visible and the link opens only on an explicit click (FR-13)". The three HTML-attribute uses of `inert` untouched. |
| `toast` timing grammar | applied, relocated | The corrected sentence ("persists for 10 seconds, or until it is dismissed" / "persists for 30 seconds") now lives in §Screen Synchronization's *Off-screen toast* bullet, the owner under item 5; the `toast` cell points there. See Deviations. |
| §IA screen-context definition leads with the term | applied | |
| §Surfaces legend: `external` split out of the shared relative clause | applied | |
| §IA "eight area bands" → "eight bands (Home plus the seven areas)" | applied | |
| §Foundation: name which mock predates the split | applied | "That direction study predates the header/status-bar split…" (the other is introduced as "Composition reference"). |
| Lifecycle steps 3 and 4 broken up; step 4's three consequences a list | applied | The "yes" cancellation keeps "Canceled — by your message". |
| `banner`: kinds separated | applied | Seven bullets, one per kind, in the original order. |
| `proposal-card` and lifecycle 2: "the unchanged fields **that** the payload still sends**,** collapsed under" | applied | Both places. |
| Numerals from 10 up | applied | 16 rows in a viewport · 12 state-matrix keys · "the same 10 things, so 60 screens behave alike" · UJ-2 "within 10 seconds" · UJ-5 "30 minutes and a laptop". NFR-1 budget now reads "within 10 seconds of Send (NFR-1)" in both `tool-call-card` and State Patterns › *Busy*. |
| Three comma splices → semicolons (`rail`, `side-bar`, `tabs`) | applied | |
| Firefox bindings reordered to match the chords | applied | "(search, page info, bookmarks)". |
| Reduced motion: four parallel clauses | applied | |
| *Banned everywhere*: confirmation prohibition made unambiguous | applied | "confirming a proposal for the user, whether by auto-confirmation or by any confirmation the user did not make". |
| Editorial voice removed | applied | The classic editor's "1,423-line" count; "a link, not a nag" → "it carries a link, cannot be dismissed, and goes the moment the condition clears". |
| Lifecycle preamble: "exactly one … never zero and never batched" | applied | |
| Glossary terms vs. surface name | applied | *silent login*, *form login*, *first-login gate* untouched. "Sign out" now consistent for the action: the Surfaces row title and its two "Reached from" references. |
| `XX-nn` defined at first use | applied | "a two-letter area code and a number, such as `LG-02` or `CP-16`". |
| "P0" and `1 (endpoint) / 3` explained in the legend | applied | |
| P1 log-screen names aligned | applied | Side-bar list adopts the §Surfaces names (Background task error log · xDBC error log · SQL diagnostics log · Unified log hub). |
| `rail-item` "navigates nothing by itself" | applied | "does not navigate by itself". |
| `command-box` dangling "matching each screen's alias list" | applied | "matching against each screen's alias list drawn from the contest wording". |
| `data-table` ambiguous "it", "(moving selects)", "with the cap an editable, labeled field" | applied | "that row becomes the screen context's selected entity"; "moving the active row also selects it"; "where the cap is an editable, labeled field". |
| "nothing else is authoritative" | applied | "nothing else on screen is authoritative until the probe resolves". |
| "the README path meets this state first" | applied | "a user following the README meets this state first". |
| "over three sentences" | applied | "above three sentences". |
| "(Fixed strings: …)" paraphrase | applied | "(the three Home starter prompts in *Fixed strings*)". |
| "the cookie still mints" | applied | "the session cookie can still mint a fresh pair". |
| "the chip toggles off / a rate" | applied | "the command-bar chip switches between off and a rate from a short fixed list". |
| Focus destinations: doubled dash, chord line, "(Escape first)" | applied | Dash aside recast as a parenthesis; "Ctrl/Cmd+K moves focus to the command-box and Escape returns it" (Focus order); "— close it with Escape first". |
| Missing comma in Privilege Gating › Mechanism | applied | |
| Row-overflow-menu trigger unit | applied | "28 × 28 CSS px". |
| "Release 1 form throughout" / "The read-only behavior is Release 1" | applied | "Every flow is written in its Release 1 form." / "The read-only behavior itself ships in Release 1." |
| "win on conflict with" → "take precedence over" | applied | |
| `classic-link-card` "may ask for sign-in" | applied | "may ask the user to sign in again". |
| Lifecycle item 10 bold label | applied | "10. **Polish week.** Adds the copy-out draft…". |

## Deviations and judgment calls

1. **`toast` timings.** The punch list asks both that the `toast` cell's timing grammar be fixed (wording fixes) and that the `toast` cell be thinned to trigger-plus-pointer because Screen Synchronization owns live-data behavior (item 5). These conflict. Resolved by writing the corrected sentence once, in the owning section, and pointing from `toast`. No fact lost; the `[ASSUMPTION: timings]` marker travelled with it.
2. **`[ASSUMPTION]` count.** Thinning the *Changed* and *Off-screen change toast* rows removed two markers whose only remaining copy was in Screen Synchronization. Because item 12 says all 21 stay inline, both were re-added to the thinned rows (`[ASSUMPTION: settle timing]`, `[ASSUMPTION]`), keeping the count at 21.
3. **UJ-6 timestamp.** "Resolved as UJ-3 resolves it" requires a concrete clock value; `09:14:22` was chosen. It is an illustration under the widened canonicality clause, not a Fixed string.
4. **Ninth `[NOTE FOR ...]` marker.** Only eight distinct asks exist; the ninth occurrence is UJ-5's cross-reference to the expired-password note. It is indexed as such rather than invented as a new ask.
5. **P1 log-screen names.** Aligned to the §Surfaces spelling rather than the side-bar spelling, because the Surfaces row is the fuller name and both refer to the same screens. If the owner prefers the shorter side-bar labels, one edit flips it.
6. **"Sortable headers announce the sort"** (was in `data-table`) folded into Accessibility Floor's "Selection and sort state are announced.", per item 9's instruction that Accessibility Floor keeps that statement.

## Things the punch list missed (found while applying, not changed)

- **`log-viewer` P1 entry point vs. the P1 surface row.** The `log-viewer` cell says "P1 adds an explain entry point per row"; the §Surfaces P1 log row says "explain entry points" for the hub. Consistent, but the hub-vs-row scope is not stated anywhere.
- **`area-tile` says "Six tiles"; §IA says seven areas.** Both are correct (Home and Agent co-pilot are not tiles), but nothing in the document says why Home shows six of seven areas. A half-clause in `area-tile` would close it.
- **"the seventh area" and "eight bands" now sit two lines apart** and are both correct after the fix, but a reader still has to do the arithmetic. Left as instructed.
- **`{spacing.header-height}` and `{spacing.status-bar-height}` carry no pixel value anywhere** — including §Responsive & Platform, which the ownership rule now names as the home for size numbers. Every other shell dimension has one.
- **§Surfaces has no `wizard` archetype row in the state matrix by itself** — it is grouped as "form-page · form-page (tabs) · wizard". Fine, but the matrix legend says "one of the 12 state-matrix keys… one-to-one with the rows below" while that row covers three keys.
- **Two Release-1 log screens (`alerts.log viewer`, `messages.log viewer`) share the `log-viewer` archetype with the P1 group row**, which lists `log-viewer · list`; the group row's per-surface mapping is not given.
- **`confirm-dialog` "the dialog list above"** still resolves (§Dialogs is in Information Architecture, above Component Patterns) but is now four sections away; naming the section would be more robust.

## Verification

- Frontmatter parses; 10 keys unchanged in order; `status: draft` intact; 7 sources and 8 imports intact.
- 42 component names present in the §Component Patterns table.
- Six Key Flows present, each with its protagonist parenthetical, numbered steps, a `**Climax:**` and an `Edge:` failure path.
- 31 distinct `{path.to.token}` references, all resolving to names present in DESIGN.md; 0 unresolved.
- All eight required section names present and unrenamed.
- 9 inline `[NOTE FOR ...]` markers (plus 9 index rows and 2 preamble mentions in §Open items); 21 `[ASSUMPTION]` markers.
