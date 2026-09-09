# Validation Report — OcuPilot

- **DESIGN.md:** `/Users/jbrandt/git/OcuPilot/_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/DESIGN.md`
- **EXPERIENCE.md:** `/Users/jbrandt/git/OcuPilot/_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md`
- **Run at:** 2026-09-09T01:00:11Z

## Overall verdict

The pair is a usable contract: every source journey has a Key Flow with its climax and failure path, all 99 distinct token references resolve to a 64-light + 64-dark palette whose stated ratios recompute correctly, and the 42 component names are identical, in the same order, in the DESIGN frontmatter, the DESIGN Components section and the EXPERIENCE Component Patterns table. What keeps it from *strong* is that the two spines were distilled separately and disagree on a dozen concrete points a story-dev would hit in the first week — the primary button's fill colour, the attention dot's token (EXPERIENCE's choice is 1.80:1 on the rail), whether a tool-call card expands, how a typed-name mismatch is reported, and which button variant Cancel and Re-propose take — plus DESIGN.md carrying UI strings that EXPERIENCE.md owns and states differently. The transparent logo exports that arrived after distillation (memlog 64) are referenced by neither spine, so the header lockup is still specified as an opaque PNG on a white plate. These are all one-line fixes; none require a new decision from the owner except the proposal-expiry interval and the side-bar width question.

The two extra lenses move the picture from tidy-up to three decisions the spines have not made. The accessibility review, recomputing every ratio from the frontmatter hexes, reproduces DESIGN's contrast tables exactly and then finds two criticals in states the tables never list: nothing says where focus goes when the control under it is disabled or removed — the composer on every Send, Confirm at the UJ-3 climax, the buttons at expiry, the side bar on Ctrl/Cmd+B — and the expired proposal card's 60 % opacity fails AA in light (2.6–4.4:1), which is the resting state of every restored transcript. The judge's eye adds a critical of a different kind: the trust story's last beat ("done · audit marked", the event under the user's own name) depends on instance auditing being on, and a Normal-level Community container ships with it off, so unless the installer creates that state the panel's first words on every screenshot are "Agent writes are not being marked." The same lens rates the fresh-container first five minutes — an expired `_SYSTEM` password on the first screen, an empty suggested view on Home, five empty Security lists, a no-key voter who never sees a proposal, and Home not fitting a 1,280 px window — as the biggest usability risk, because the spine is written around Dana's lived-in instance rather than Priya's. After merging five findings two reviewers raised in common and folding the rubric's §8 pointer into §6, the report carries **3 critical, 16 high, 30 medium and 26 low** findings. The rubric's own set stays one-line edits; the three criticals and the fresh-container highs need an installer decision (auditing on, password unexpired, demo state seeded) and a Focus-destination rule in the Accessibility Floor before a story-dev can build from the pair.

## Category verdicts

- Flow coverage — strong
- Token completeness — strong
- Component coverage — adequate
- State coverage — adequate
- Visual reference coverage — adequate
- Bloat & overspecification — adequate
- Inheritance discipline — adequate
- Shape fit — strong
- Accessibility — thin (derived: the review states no single word; the AA + keyboard claim "does not yet" hold, with two criticals in demo-critical states, though the reviewer calls the claim close — "fix those two, the gradient-end eyebrow, and the macOS gap in the row-menu keyboard model, and the AA-text + keyboard claim holds")
- Judge's eye — adequate (its scorecard: Usability adequate, strong if the high findings land; Developer Experience strong in-product, adequate for extension; Clarity strong with a key, thin without; Distinctiveness strong if the assets land, thin if placeholders ship)

## Findings by severity

### Critical (3)

**[Accessibility]** — Focus is dropped by disabling or removing the focused control, on every turn and at the UJ-3 climax (§ EXPERIENCE.md `panel` / State Patterns "Busy" and "Locked"; Interaction Primitives Ctrl/Cmd+B; DESIGN.md `proposal-card` Confirmed / Canceled / Expired / Kill-switch-disabled)
EXPERIENCE.md `panel` / State Patterns "Busy" say the composer and Send are *disabled* the moment a turn starts; a natively disabled textarea cannot hold focus, so Enter-to-send throws focus to `<body>`, Ctrl/Cmd+I cannot "focus the panel input from anywhere" for the 60–90 s the turn runs, and the "Locked" state ("the typed text is kept in the input", "a second Enter shows the lock banner") is impossible because nothing can be typed into a disabled field. Same pattern on the `proposal-card`: Confirm is pressed, "the footer becomes" a success strip and the button leaves the DOM (DESIGN.md `proposal-card` Confirmed/Canceled/Expired: "the buttons go"; Kill-switch-disabled: buttons "become unavailable (38%)") — focus is lost at the exact moment the write completes. Also Ctrl/Cmd+B with focus inside the side bar (Interaction Primitives), and deletion of the selected, focused row.
Fix: add a **Focus destination** rule to the Accessibility Floor: (1) the composer is never natively disabled — it stays editable during a turn, Send is `aria-disabled`, Enter shows the lock banner (this also resolves the Busy/Locked contradiction); (2) on Confirm, Cancel, expiry, target-changed and kill-switch, the card's footer status element (`tabindex="-1"`) receives focus and its text ("Confirmed by …", "Canceled", "Expired — Re-propose available") is announced; buttons that go away are first `aria-disabled` for the transition, never removed while focused; (3) Ctrl/Cmd+B with focus inside the side bar moves focus to that area's rail-item; (4) deleting the focused row moves focus to the next row, else the table's empty-state or the command-bar filter. State in one sentence: "No control is disabled or removed while it holds focus without a named destination."

**[Accessibility]** — Expired proposal card text fails AA in light mode (§ DESIGN.md `proposal-card` Expired; EXPERIENCE.md State Patterns, restored from a reloaded transcript)
DESIGN.md `proposal-card` Expired: "the header, diff and agent's text drop to 60% opacity". Computed over `surface-container-lowest`: `on-surface` 4.38:1, `on-surface-variant` labels and countdown 2.89:1, diff before (`destructive`) 3.04:1, diff after (`success`) 2.77:1, `primary` title 3.38:1, "Agent's rationale" heading on its faded container 2.59:1. Dark: `on-surface-variant` 4.33:1 and `primary-dark` title 4.45:1 also fail. Because "a card restored from a reloaded transcript is always shown expired", this is the resting state of the entire transcript after any reload, and the diff is still content the user reads ("what did I confirm earlier?"). It is not an inactive UI component — the card still carries a live Re-propose button.
Fix: drop the opacity. Dim with roles that pass: title, labels and diff values in `{colors.restrained}` (6.55:1 light, 9.64:1 dark), body in `{colors.on-surface-variant}`, the agent's text kept on `agent-container` at full opacity (its heading already exists to mark it), the bar `restrained` as specified. If a visual fade is wanted, cap it at 85% for `on-surface` only (≈7:1) and never apply it to the status colors.

**[Judge]** — The trust story's last beat depends on auditing being on, and the spine does not create that state (§ Judge §4, §1 — tool-call-card "done · audit marked"; UJ-3 step 6; auditing-off banner; Logs › Audit database)
"done · audit marked" on the tool-call card and the event under Priya's own name in Logs › Audit database need instance auditing enabled plus OcuPilot's user events registered. IRIS enables auditing only at the Locked Down security level; a Normal-level Community container ships with it off. This project's own container reports auditing on — with four `AuditChange` records, i.e. switched on by hand. Left alone, the panel's first words on every README screenshot are "Agent writes are not being marked. Auditing is off on this instance." and UJ-3 step 6 ends in "No events match."
Fix: the installer enables auditing and registers OcuPilot's events (owner-consented, itself audited); the auditing-off banner uses its optional link — "Turn auditing on" → Auditing configuration — so the state is one click from recovered; the README names it in the install steps; the smoke script asserts the marked audit row exists after the demo write.

### High (16)

**[Component coverage]** — `button-primary` fill: `primary` in EXPERIENCE, `secondary` (teal) in DESIGN and the memlog (§ EXPERIENCE.md:239 · DESIGN.md:503, 685, 687, 1093)
EXPERIENCE.md:239 says "Filled `{colors.primary}`"; DESIGN.md:503 (`background: '{colors.secondary}'`), 1093 and the Colors table (685, 687) say teal `secondary`, and memlog 63 records that resolution ("buttons/links/selection use secondary (teal), primary (deep blue) keeps focus ring and titles").
Fix: EXPERIENCE.md:239 → "Filled `{colors.secondary}`".

**[Component coverage]** — `attention-dot` token: EXPERIENCE's choice is 1.80:1 on the rail (§ EXPERIENCE.md:214 · DESIGN.md:245, 773, 886)
EXPERIENCE.md:214 says "`{colors.agent-accent}` dot"; DESIGN.md:245, 886 and rule 1 (773) say `{colors.agent-accent-dark}` in both modes because the dot sits on the navy rail. Light-mode `agent-accent` (#6B5E00) on `shell` (#0F3A5F) recomputes at **1.80:1** — an invisible dot for the unconfigured / kill-switch signal that UJ-2 step 3 relies on. (The accessibility review's verified-pairs table confirms `agent-accent-dark` on `shell` at 8.09 light / 10.81 dark.)
Fix: EXPERIENCE.md:214 → `{colors.agent-accent-dark}`.

**[Component coverage · Accessibility]** — `tool-call-card` interactivity: expands on click (EXPERIENCE) vs not interactive in Release 1 (DESIGN) (§ EXPERIENCE.md:231 · DESIGN.md:1027, 1037)
EXPERIENCE.md:231 "Expands on click or Enter to show the arguments summary and the result"; DESIGN.md:1037 "The card is not interactive in Release 1 (no expand)" and its rest state already shows "the tool name and argument summary" (1027). FR-12 requires name, arguments summary and result status to be visible; EXPERIENCE's collapsed view hides the summary behind an expand that DESIGN says does not exist. The accessibility review raises the same contradiction (its medium "Contradictions between the spines", item b) and adds: if it expands it is a `<button aria-expanded>` with the status text inside the name.
Fix: pick one. Recommended: DESIGN's — non-interactive, summary always visible — and delete the expand sentence; add an `[ASSUMPTION]` if a P1 expand is wanted.

**[Visual reference coverage · Judge]** — The transparent logo exports are orphans; the header lockup is still an opaque PNG on a white plate (§ DESIGN.md:16–19, 268–271, 664–673, 906 · imports/OcuPilot-Logo-transparent.png · imports/OcuPilot-Mark-transparent.png · Judge §5)
`imports/OcuPilot-Logo-transparent.png` (1182×774, alpha) and `imports/OcuPilot-Mark-transparent.png` (950×479, alpha) are orphans: not in either frontmatter, not in the Visual references table, not referenced anywhere. They were added after distillation (memlog 64, 16:58) precisely to resolve DESIGN's plate assumption — `logo-lockup` still specifies the opaque `OcuPilot-Logo-web.png` (480×322, no alpha — verified) "on a `{colors.surface-container-lowest}` plate" with the note "if the owner supplies a transparent export the plate goes" (DESIGN.md:268–271, 906). A story-dev following DESIGN as written builds the plate the owner has already been offered a way out of, and memlog 54 shows the owner is sensitive to the logo's rendering. Memlog 66 records a logo reconcile in flight; this review is what it must land in. The judge reaches the same component from the README: a stacked 480 × 322 PNG at 40 px on a white plate in the navy band puts the wordmark at about 11 px on screen and 7 px in a README image, and the plate reads as a broken-image patch.
Fix: point `logo-lockup.asset` at the transparent lockup (or the mark, if the wordmark is illegible at 40 px — the second `[ASSUMPTION]` at 906 already raises that), drop the plate, add both files to both frontmatter `imports:` lists and to the references table with a note that the owner's own export supersedes them. The judge's concrete recommendation: the eye-and-panel mark (the new transparent mark import) at 32 px plus a typeset "OcuPilot" in the vendored brand face; no plate.

**[Accessibility]** — The "Namespace" eyebrow sits on the gradient's failing end (§ DESIGN.md `header` — namespace switch, `on-shell` at 72% over `shell-edge`)
DESIGN.md `header`: the namespace switch is at the right, where the gradient reaches `shell-edge`, and its eyebrow is `on-shell` at 72%. Computed: 3.60:1 light, 4.17:1 dark — below 4.5 for 11px text. (The 72% value only passes against flat `shell`, 6.15:1, which is where the table claims it.)
Fix: eyebrow at 100% `on-shell` (5.35 / 6.43) or end the gradient at 55% so the switch sits on flat `shell`; add the pair "on-shell at 72% / shell-edge" to the contrast table so it is not re-introduced.

**[Accessibility · Judge]** — Row actions have no keyboard path on macOS; the grid model is incomplete and the table is not stated to be one Tab stop (§ EXPERIENCE.md Interaction Primitives, Accessibility Floor — `row-overflow-menu`, `data-table` role="grid" · Judge §6)
Interaction Primitives and Accessibility Floor give the row-overflow-menu exactly two keys: Shift+F10 and the menu key. Mac keyboards have no menu key, F10 is a media/Mission Control key unless Fn is held, and Chrome on macOS does not dispatch `contextmenu` for Shift+F10 (VoiceOver's VO+Shift+M is the only documented route). The table is `role="grid"` but only Up/Down are specified, so nothing says how a keyboard user reaches the name link, the ⋮ trigger or a `severity-chip` (a button) inside a row. The only mitigation is that the command-bar duplicates the row's actions — real, but undiscoverable from the row. The judge's low "Table Tab stop" is the same gap from the other side: without a single Tab stop a keyboard user tabs through rows to reach the panel.
Fix: specify the APG grid: one Tab stop; Up/Down/Home/End/PageUp/PageDown move row focus; Right/Left step into the row's cells (name link, chips, ⋮) and back; Enter on the row opens; Tab leaves the grid. Open the row menu on the `contextmenu` event (covers Shift+F10 and the menu key on Windows and VO+Shift+M) **and** on a platform-neutral chord (Alt/Option+Down on the focused row, the disclosure convention). Keep focus on a container with `aria-activedescendant` rather than on the recycled row element so CDK virtual scroll and in-place re-fetch can never drop it (this is the safe way to honor "virtual scroll keeps the focused row rendered"). Show the chord in the empty-state kbd hints.

**[Accessibility]** — Status messages (WCAG 4.1.3, AA) are incomplete — the agent's reply is not on the list (§ EXPERIENCE.md Accessibility Floor → Live regions; `panel` transcript)
Accessibility Floor → Live regions enumerates tool-call cards, proposal arrival, lock banner, toasts, change highlight, navigation, countdown and two banners. Missing: the `message-agent` reply itself (the answer to every question, the UJ-1 climax), the turn error card, "Connected. Reply: …" after Test connection (UJ-2 climax), "Saved" in the sticky bar, "Sign-in failed", "The instance is unreachable", "Refresh paused", the search "n of N", "No screen or action matches" and result counts in the command-box, the 403 inline message, and status-bar connection-state transitions. Also, the transcript "scrolls independently" but contains buttons, so Chrome will not make it keyboard-scrollable on its own.
Fix: make the transcript a `role="log"` region (polite, `aria-label="Conversation"`, `tabindex="0"`) — appended messages, cards and proposals are then announced by construction and the per-card rules reduce to status-change text updates; give the Test-connection result, "Saved", the search count and the command-box count `role="status"`; give the sign-in failure, unreachable banner, generic error and 403 presentation `role="alert"` or move focus to them; declare the auto-refresh stamp and the countdown explicitly *not* live, and the connection-state segment live only on transitions.

**[Accessibility]** — The disabled-with-tooltip mechanism conflicts with Material's defaults in three of its six surfaces (§ EXPERIENCE.md Privilege Gating, Accessibility Floor — `row-overflow-menu`, `command-box`, `command-bar`)
Privilege Gating and the Floor correctly require gated controls to stay focusable with the tooltip as `aria-describedby`, and MatButton's `disabledInteractive` (v17+) does that for buttons. But: `mat-menu` and every CDK `ListKeyManager` skip `disabled` items with the arrow keys by default and `MatMenuItem` has no `disabledInteractive` (open issue through v19), so gated `row-overflow-menu` items are unreachable; `command-box` results are a listbox driven by `aria-activedescendant` — DOM focus never leaves the input, so no tooltip can ever show on a disabled result; and the command-bar's *unavailable* actions ("disabled with a tooltip when nothing is selected", 38% native disabled) get a tooltip nobody without a mouse can reach.
Fix: in the Floor: gating uses `aria-disabled="true"`, never the `disabled` attribute; key managers override `skipPredicate` so gated items are focusable and announced; in menus and result lists the reason is **visible inline text** ("Requires %Admin_Secure" as a trailing caption in `{colors.restrained}`) and part of the item's accessible name — tooltips only on controls that receive DOM focus (rail-item, side-bar entry, area-tile, buttons); for "nothing selected" either drop the tooltip or apply the same mechanism. Add the pair `restrained` on `secondary-container` (the keyboard-active menu row) to the contrast table.

**[Judge]** — Home does not fit on a 1,280 px window, and the 900–1,279 band has no rule (§ Judge §7 — EXPERIENCE.md Responsive & Platform, `panel-resize-handle`; DESIGN.md Layout & Spacing)
Rail 48 + side bar 224 + content-min 640 + panel-min 320 = 1,232 px, so 1,280 fits only with the panel squeezed to 368; the remembered 400 does not fit with the side bar open (1,312). On Home the panel is 50vw: content stays at 640 only above 1,376 px with the side bar closed and 1,824 with it open. At 1,280 (1080p at 150 %, the common Windows laptop) the tile row gets 592 px, or 368 with the side bar open, and scrolls horizontally; a 1,440 px MacBook Air fails the moment the side bar is open (448 px). The responsive table says "≥ 1,280: panel at its remembered width" and "900–1,279: nothing changes", while the resize-handle rule caps the panel where content reaches its minimum; DESIGN says "the side bar collapses first", EXPERIENCE says "no panel auto-collapse" and squeezes only below ~900. Related: the accessibility review's low on 200% zoom reflow.
Fix: exempt Home from content-min and let the six tiles wrap (grid, 168 px minimum); `panel-home = clamp(panel-default, 50vw, viewport − rail − side bar − content-min)`; write one yield order for 900–1,279 in both spines (side bar collapses first, then the panel to its minimum, then content scrolls).

**[Judge]** — Answering the proposal in chat cancels it (§ Judge §2 — UJ-1, UJ-6; Agent Write Lifecycle "Sending a new message cancels every live proposal"; composer caption)
UJ-1 and UJ-6 teach the user to answer "Shall I…?" by typing "yes"; at the card, "Sending a new message cancels every live proposal", so the same reflex destroys the diff under review and the agent then answers "yes" with nothing to act on.
Fix: while a proposal is live the composer caption reads "A proposal is waiting — use Confirm or Cancel on the card. Sending a message cancels it."; the agent's message that accompanies a proposal ends "Press Confirm on the card to apply it."; Send drops its filled treatment while a card is live (which also removes the two-primaries-in-one-view violation: Send and Confirm are both filled teal today).

**[Judge]** — The unchanged-payload rows push Confirm below the fold (§ Judge §2 — `proposal-card` "every field the payload will send"; 400 px panel)
The card lists "every field the payload will send"; a web application update carries dozens (the classic editor is 1,423 lines), so in a 400 px panel two changed rows are followed by a screen of muted rows before the buttons. The mock's legibility comes from omitting them.
Fix: "Also sent, unchanged (38)" is a collapsed disclosure and the diff shows changed rows by default; where the API accepts a partial update, the write tool sends only the changed fields so the list is what the user asked for.

**[Judge]** — The first screen sends the voter away (§ Judge §1 — Form login, Expired password state)
On a fresh Community container `_SYSTEM`'s password is expired; the form's expired state says "Change it in the classic portal, or run the command in the README" — the voter's first interaction bounces her out of the product she came to score.
Fix: the compose/installer path unexpires `_SYSTEM` so the README path never reaches this state (the project's own CLAUDE.md carries the one-liner); keep the state for other users but add an inline "Set a new password" (current, new, confirm) so the fix stays inside the form; name the user in the message ("The password for _SYSTEM has expired.").

**[Judge]** — The no-key voter sees nothing of the agent (§ Judge §1 — `panel` unconfigured empty-state; Home 50vw)
Unconfigured, the panel is an empty-state with the avatar and "who can configure it" — 400 px on every screen and half the viewport on Home — and the voter never sees a proposal.
Fix: the unconfigured empty-state renders a static, labeled example ("Example — what a proposal looks like") of the UJ-3 card in its live state, non-interactive, plus three sentences (reads with your privileges; proposes; you confirm; every write is marked in the audit database); on Home the unconfigured panel stays at panel-default, not 50vw; the README leads with the same card.

**[Judge · State coverage]** — Home's suggested view is empty on a fresh instance (§ Judge §1 — EXPERIENCE.md:298 suggested view; Rubric §4)
The lines are suspended tasks, application errors today, new alerts.log entries — all zero on a container that just started — so the panel-forward Home shows three "0" lines and the agent status; the video's first frame is thin. The rubric's state walk flags the same gap as a missing state row (no state for the suggested view when nothing needs attention); this entry prescribes that state's content.
Fix: when every attention line is zero, the block shows three starter prompts instead ("Which web applications are disabled?", "Which users can't sign in, and why?", "What is using the most CPU right now?") — Release 1's cheap version of FR-70; after the first definition is saved the panel posts a first-run message ("I'm ready. Try one of these.") that repeats them.

**[Judge]** — "Visible rows" is undefined and uncounted (§ Judge §7, §4 — screen context, `context-chip`, read tool-call card, "leaves the instance" pill)
With virtual scroll a 1,280 × 800 window shows about sixteen rows of a 1,000-row fetch; the spine never says whether the sixteen or the thousand travel with each turn. A thousand rows is on the order of 100 k tokens a turn — cost, first progress past the 10 s target, and the exact privacy question a judge asks at the "leaves the instance" pill.
Fix: define screen context as the rows in the viewport plus the active filter and sort (so the read tool can reproduce the set), capped (50); the context-chip shows the count ("Web applications, HSCUSTOM · 6 rows") and the read tool-call card shows rows returned.

**[Judge]** — Placeholder icons will be in the screenshots (§ Judge §5 — rail-item, area-tile, empty-state)
Initials in outlined circles on the rail, the tiles and the empty-states are wireframe furniture; if the owner's icons slip, every README image and the first video frame ship with them.
Fix: vendor a Material Symbols subset now as the interim set (allowed under NFR-10); the owner's icons replace it file for file.

### Medium (30)

**[Flow coverage]** — The proposal-expiry interval is decided only by example (§ EXPERIENCE.md:518 · 181–204 · 281 · 398–411 · 419 · prd.md:378)
UJ-3 step 3 shows "Expires in 4:59" (EXPERIENCE.md:518), which fixes a five-minute window that appears nowhere else: not in Fixed strings (181–204), not in the Agent Write Lifecycle (398–411), not in the memlog (memlog 56 records the countdown caption, not the interval), and the PRD only says "a fixed interval" (prd.md:378). The interval governs how long auto-refresh pauses on a screen (EXPERIENCE.md:281, 419) and the demo's pacing. Related: the accessibility review's medium on the same limit (WCAG 2.2.1 basis, administrator-settable) and the judge's low on countdown pressure ("Valid until 10:47").
Fix: state the interval once in the Lifecycle step 5 or Fixed strings with an `[ASSUMPTION]` tag, and derive the 4:59 from it.

**[Component coverage · Accessibility]** — `typed-name-field` mismatch feedback: silent (EXPERIENCE) vs "Does not match" on blur (DESIGN) (§ EXPERIENCE.md:237 · DESIGN.md:1081)
EXPERIENCE.md:237 "mismatch shows no error, the button simply stays disabled"; DESIGN.md:1081 "a mismatch on blur shows a 2px `{colors.destructive}` border and 'Does not match'". Opposite behaviours for the destructive-confirmation control used in every delete dialog and every step-7 destructive proposal. The accessibility review (its medium "Contradictions between the spines", item a) notes DESIGN's satisfies WCAG 3.3.1; a silently disabled Delete gives a screen-reader user no reason.
Fix: EXPERIENCE decides (behaviour); DESIGN keeps only the appearance of whichever state exists. The accessibility review's direction: keep DESIGN's "Does not match" on blur.

**[Component coverage · Judge]** — Button variant assignments disagree in four places (Cancel, Re-propose, Load newer, Raw, Filter) (§ EXPERIENCE.md:222, 232, 240, 241, 243, 305 · DESIGN.md:434, 437, 928, 951, 1048, 1055, 1097)
Cancel on the proposal card is `button-secondary` in EXPERIENCE.md:232 but `button-text` in DESIGN.md:434 and 1048; Cancel on the form-page sticky bar is `button-secondary` in EXPERIENCE.md:243 but `button-text` in DESIGN.md:951; Re-propose, Load newer and Raw are `button-text` in EXPERIENCE.md:241 and 305 but `button-secondary` in DESIGN.md:437, 1055, 1097 (and the frontmatter's `footer-expired`). EXPERIENCE.md:240 also lists "Filter" as a secondary button while the command-bar row (222) and DESIGN.md:928 make the filter a field. The judge's low "Cancel variant conflict" is the same finding, resolved the same way: text.
Fix: keep DESIGN's mapping (it matches the M3 hierarchy and the Bridge mock) and rewrite EXPERIENCE.md:232, 240, 241, 243, 305.

**[Component coverage]** — Administrator reminder banner on `agent-container` breaks DESIGN's own rule 4 (§ EXPERIENCE.md:234 · DESIGN.md:776, 999, 1067, 1126)
EXPERIENCE.md:234 puts it on `{colors.agent-container}`; DESIGN.md:999 and 1067 make it the *info* variant, and DESIGN's rule 4 (776) and Do's/Don'ts (1126) forbid `agent-container` under anything but the agent's own words.
Fix: EXPERIENCE.md:234 → info variant.

**[Component coverage]** — `focus-ring` on mouse focus: "never suppressed" vs `:focus-visible` only (§ EXPERIENCE.md:251 · DESIGN.md:1111)
EXPERIENCE.md:251 "never suppressed for mouse users"; DESIGN.md:1111 "It shows for keyboard focus (`:focus-visible`), not for mouse clicks".
Fix: EXPERIENCE (behaviour) should say `:focus-visible` semantics — visible for keyboard and programmatic focus, never removed by `outline: none` — which is what "never suppressed" was trying to protect.

**[Component coverage]** — Components with no row on either side: Form login, the two notices, Home's suggested view, the OpenAPI browser (§ EXPERIENCE.md:66–67, 265, 268–269, 298 · IA row 121 · DESIGN.md:1101)
The **Form login** card (a step-0 P0 surface and the first thing UJ-2 and UJ-5 see) has only a state row ("centered card with the logo, user name, password, Sign in", EXPERIENCE.md:265) and no visual spec. The **Version-mismatch** and **No-administrative-privileges** notices (66–67, 268–269) likewise. Home's **suggested view** block (298; UJ-6 step 1) has a state row and a button-text mention (DESIGN.md:1101) but no anatomy for the attention lines and their "Open ›" affordance. The **OpenAPI path-and-verb browser** (FR-34, IA row 121) has no behavioural or visual rule beyond the refusal state.
Fix: four short rows in each spine — or, for the notices, a sentence mapping them to `empty-state` + `banner`.

**[State coverage]** — The IA table's Archetype column is declared to key the matrix, but only 7 of its 31 values appear as matrix rows (§ EXPERIENCE.md:60, 62–141, 343–358)
The IA table's Archetype column is declared to key the matrix (EXPERIENCE.md:60) but only 7 of its 31 distinct values appear as matrix rows. Release 1 rows that do not key: the six shell rows (`transition`, `form`, `notice` ×2, `redirect`, `action` — covered by the Shell/Session tables but nothing says so), the nine `confirm-dialog` rows (matrix says `dialog`), Audit database viewer `viewer (server criteria)` (matrix says `list (server criteria)`), OAuth 2.0 `list (tabs)` (no row, not in Exceptions), Auditing configuration `form-page + lists` (only its warning dialog is in Exceptions), and the compound P1 keys.
Fix: normalise the column to the twelve matrix names (plus `shell` and `external`), and add one line under the matrix: "shell and external archetypes take their states from the Shell and Session tables".

**[Visual reference coverage]** — DESIGN.md's frontmatter `imports:` omits the two avatar files its own components reference (§ DESIGN.md:16–19, 399–400, 1023 · EXPERIENCE.md:17–22)
DESIGN.md's frontmatter `imports:` (16–19) lists only the three logo files, although the file's own components reference `imports/robot-avatar.png` and `imports/robot-avatar-64.png` (399–400, 1023). EXPERIENCE.md:17–22 lists all five.
Fix: add the two avatar files to DESIGN's list.

**[Bloat & overspecification · Judge]** — DESIGN.md carries UI copy that EXPERIENCE.md owns, and the two have drifted (§ DESIGN.md:914, 943, 993, 1000, 1019, 1058 · EXPERIENCE.md:175, 219, 225, 281, 315, 409)
Status-bar connection words: "connected / refreshing token / instance unreachable" (DESIGN.md:914) vs "Connected / Instance unreachable — retrying / Signing in again…" (EXPERIENCE.md:219, Fixed strings). Navigation announcement: "Taking you to …" (DESIGN.md:1019) vs "I'm opening <screen> for <entity> — use Back to return." (EXPERIENCE.md:315; and 175 has a third phrasing, "I'll open Task details…"). Refresh-paused: "Refresh paused" on the stamp (DESIGN.md:943) vs "Auto-refresh paused — a proposal is awaiting confirmation" on the chip (EXPERIENCE.md:281). Kill-switched card footer: "Agent disabled: <reason>" (DESIGN.md:1058) vs "The agent is switched off" (EXPERIENCE.md:409). Read-only footer line: DESIGN always renders "Read-only: off" (993, 1000) while EXPERIENCE shows the line only while a read-only state applies (225, tagged `[ASSUMPTION]`). The judge's low "Read-only line conflict" is the same disagreement and takes a side: always show it — a judge learns the mode exists.
Fix: strip the strings from DESIGN (keep placeholders like `<connection word>`), and reconcile EXPERIENCE's two navigation phrasings into one Fixed string. For the read-only line, the judge's resolution: always show it.

**[Bloat & overspecification · Shape fit]** — The sign-in story is told three times in EXPERIENCE.md, with drifting strings (§ EXPERIENCE.md:263–269, 322–337, 423–437)
The sign-in story is told three times in EXPERIENCE.md: Shell state rows 1–7 (263–269), the Session table (322–337), and Session and Sign-in (423–437). Each carries slightly different strings ("Your session ended. Sign in to continue." appears in two of the three; the Shell table has no session-ended row at all). Rubric §8's only finding (the two invented sections that duplicate) points here.
Fix: keep the Session table as the authority (it is the auth spike's numbering), reduce the Shell rows to those with a distinct visual (Silent login in progress, Form login, Expired password, Version mismatch, No privileges), and cut Session and Sign-in to the two assumptions it adds (the silent retry, the "unsaved changes were not kept" toast).

**[Inheritance discipline]** — The side bar's width is "remembered per browser" but nothing can change it (§ EXPERIENCE.md:43, 215, 378 · DESIGN.md:810 · memlog 27)
The side-bar's width is "remembered per browser" (EXPERIENCE.md:43, 215; DESIGN.md:810), inherited from memlog 27, but the only drag in the product is the panel handle (EXPERIENCE.md:378 "No drag except the panel-resize-handle") and no side-bar sash exists in either spine. A remembered width that cannot change is either a missing component or a stray word.
Fix: ask the owner: add a `side-bar-resize-handle` mirroring the panel's (with a visual spec and a min/max), or drop "width" from the two rows and keep `{spacing.side-bar-width}` fixed.

**[Accessibility]** — Rail active indicator is below 3:1 for most of its length (§ DESIGN.md `rail-item` Active — `linear-gradient(shell-edge, #2090A0)` on `shell`)
`rail-item` Active: `linear-gradient(180deg, shell-edge, #2090A0)` on `shell`: 1.94:1 at the top (2.00 dark), 2.47 at the midpoint (2.92 dark), 3.10 at the bottom (4.15 dark). The only other state cue is the icon stepping from 72% to 100% `on-shell` (about 1.6:1 between the two states). DESIGN.md's own Contrast section claims 3:1 for non-text and state indicators.
Fix: run the hairline from `{colors.secondary-dark}` (6.72 / 8.97 on the shell — rule 1 already says teal on the chrome is `secondary-dark`) to `#2090A0`, or make it solid `secondary-dark`; add `aria-current="page"` on the active rail-item and side-bar entry so the state is programmatic as well.

**[Accessibility]** — Proposal expiry is a time limit with no stated basis (WCAG 2.2.1, level A) (§ EXPERIENCE.md Agent Write Lifecycle; `proposal-card` countdown; Accessibility Floor)
Five minutes ("Expires in 4:59", PRD "fixed interval"), not user-adjustable, and Re-propose is a *new turn with a fresh read and diff*, which is a recovery path, not an "extend". The countdown turning `{colors.warning}` under 1:00 is visual only. Related: the rubric's medium on the interval being decided only by example (Flow coverage) and the judge's low on countdown pressure.
Fix: state the exception in the Floor: the limit is essential to the security model (server-minted, single-use, fingerprinted confirmation; extending would confirm a stale diff) — and make it defensible: announce "One minute left to confirm" politely at 1:00; make the interval a server-side setting the OcuPilot administrator can raise for their users; note that the countdown and the running spinner are auto-updating content covered by the same essential exception (2.2.2) and that the countdown is not a live region.

**[Accessibility]** — Off-screen toast: a 10 s timed control that is last in the focus order (§ EXPERIENCE.md `toast`; Tab order after the panel)
`toast` persists "until dismissed or 10 s" and carries the only "Open in <screen>" shortcut; toasts sit after the panel in the Tab order, twenty-odd stops from the content. A keyboard user cannot reach it before it goes.
Fix: pause the timer while any toast is hovered or focused and while focus is inside the toast region; do not auto-dismiss a toast that carries an action until it has been focused at least once, or lengthen action toasts to 30 s; state that the agent's reply names the same change so nothing is lost when the toast expires. Keep `role="status"` (correct).

**[Accessibility]** — Diff-row direction is carried by an arrow glyph, a strike-through and color (§ DESIGN.md `diff-row` · EXPERIENCE.md `diff-row`)
DESIGN.md `diff-row`: "the strike-through and the weight carry the direction" — neither is announced, and "→" is read inconsistently across screen readers. A screen-reader user reviewing the write hears "Enabled No Yes".
Fix: give each diff-row an accessible rendering "Enabled: was No, now Yes" (visually hidden "was"/"now", arrow `aria-hidden`) and "unchanged" for the "Also sent, unchanged" rows. Also resolve the color contradiction: DESIGN.md says before `destructive` / after `success`, EXPERIENCE.md `diff-row` says `on-surface-variant` / `on-surface` — both pass, pick one.

**[Accessibility]** — Contradictions between the spines with accessibility consequences; resolve toward the accessible side (§ `typed-name-field` · `tool-call-card` · `status-bar` · `rail-item` · panel composer)
(a) `typed-name-field`: EXPERIENCE "mismatch shows no error, the button simply stays disabled" vs DESIGN "'Does not match' in `destructive` on blur" — DESIGN's satisfies 3.3.1; a silently disabled Delete gives a screen-reader user no reason. (b) `tool-call-card`: EXPERIENCE "Expands on click or Enter" vs DESIGN "not interactive in Release 1" — if it expands it is a `<button aria-expanded>` with the status text inside the name. (c) `status-bar`: DESIGN "stamp → toggles auto-refresh" vs EXPERIENCE "Nothing else in the bar is interactive". (d) `rail-item` 48×48 (DESIGN) vs 48×46 (Floor). (e) Composer disabled vs draft kept (see the critical finding). Items (a), (b) and (d) are also raised by the rubric under Component coverage and are cross-cited there; (c) is unique to this review; (e) is the first critical.
Fix: one pass to align them.

**[Accessibility]** — Keyboard chords are not scoped, and the navigation announcement races the route change (§ EXPERIENCE.md Interaction Primitives (Ctrl/Cmd+I, +K, +B); `confirm-dialog`; navigation tool "route changes on the next tick")
Nothing says Ctrl/Cmd+I, +K, +B are inert while a `confirm-dialog` is open — as written they would pull focus out of a trapped dialog. And "the route changes on the next tick" after the "I'm opening …" message means the new heading takes focus and pre-empts the polite announcement the Floor promises will be read first.
Fix: chords are ignored while a dialog or the command-box overlay is open (Escape first); the navigation tool commits the message to the log, then changes route after the announcement has been dispatched (≈1 s), and the new screen's heading announcement includes "opened by the agent — Back returns" so the two cannot be lost together.

**[Accessibility]** — The command-box has no named ARIA pattern (§ EXPERIENCE.md `command-box`)
It is the shell's primary keyboard navigation, grouped, filterable, with disabled entries, but the spine specifies only keys and copy.
Fix: `role="combobox"` input with `aria-expanded`, `aria-controls` and `aria-activedescendant`; results a `role="listbox"` with `role="group"` + `aria-label` for Screens / Actions; a polite `role="status"` that reads "5 screens, 2 actions" as the filter changes and "No screen or action matches"; disabled results per the gating finding (inline reason, still arrow-reachable); Escape closes then returns focus (already specified).

**[Accessibility]** — Forms: error association and focus after a failed Save are unspecified (§ DESIGN.md `form-page`; `typed-name-field`, `masked-secret`, filter, max-rows footer field; Form login)
DESIGN.md `form-page` puts an error summary banner at the top and "server rules land on the field they name"; nothing says the banner gets focus or `role="alert"`, that the first invalid field receives focus (the spine only switches tabs), that custom fields (typed-name, masked-secret, the filter, the max-rows footer field) carry `aria-invalid` and `aria-describedby` the way `mat-form-field` does for free, or that the required asterisk has a legend/`aria-required`. The sign-in failure and expired-password text under the fields need the same.
Fix: on failed Save focus the summary banner (`tabindex="-1"`, `role="alert"`), each entry a link to its field; server errors set `aria-invalid` and focus the first; custom fields replicate mat-form-field's describedby wiring; "Saved" is a `role="status"`.

**[Judge]** — Rail click opens a menu; tile click navigates (§ Judge §3 — `rail-item` "navigates nothing by itself"; `area-tile`)
A rail item "navigates nothing by itself": the voter clicks Logs and the Web applications list stays on screen, while Home's tiles open the area's first screen. Only VS Code users expect the first behavior, and it costs one extra click per area on a thirty-minute clock.
Fix: a rail click opens the side bar and, when the current route is outside that area, navigates to the area's first screen; clicking the active item still collapses.

**[Judge]** — The gate lands without orientation (§ Judge §1 — First-login gate redirect; Definition form; administrator reminder banner; sticky bar)
The redirect opens the Definition form — twelve-plus fields and no sentence saying why she is here; the panel's reminder banner tells her to go where she already is; after Save the editor stays open with "Saved" and nothing points onward.
Fix: an info banner above the form on the gate landing ("OcuPilot needs one agent definition before the panel can help. Anthropic is selected — paste a key and press Test connection. You can skip this and browse."); provider, key and Test connection above the fold with the rest under "Advanced"; on the first successful Save the sticky bar offers "Go to Home" and the panel posts its first-run message.

**[Judge]** — Security and secrets is five empty lists on a fresh container (§ Judge §3, §1 — SSL/TLS, X.509, LDAP, Wallet, OAuth empty-states; UJ-5)
SSL/TLS, X.509, LDAP, Wallet and OAuth are all empty, so the contest's most detailed bullet meets "No SSL/TLS configurations." five times; UJ-5's "at least one list backed by live data" holds only for Auditing, last in the side bar.
Fix: empty-states on write-capable lists gain a second line inviting the agent ("Or ask the agent: create an SSL/TLS configuration for outbound HTTPS."); the README walkthrough uses one of these as its second write; consider seeding a demo SSL/TLS configuration and a self-signed X.509 credential at install.

**[Judge]** — Ctrl/Cmd+K, +I and +B are invisible (§ Judge §6, §3 — command-box ⌘K hint; rail tooltips; empty-state kbd chips; composer caption)
Only the ⌘K hint in the command box exists; the keyboard-first stake earns nothing a voter can see, and the no-close panel plus rail toggle are VS Code conventions with no on-screen explanation.
Fix: the reconcile note's defaults — caption "Enter to send · Ctrl+I to focus", Ctrl+B in the rail tooltips, kbd chips in empty-states.

**[Judge]** — Trust lines the screen never says (§ Judge §4 — `proposal-card` footer; Done reply; "leaves the instance" pill)
Nothing before Confirm states that the write runs as the user; the Done reply does not lead to the audit event; the "leaves the instance" pill has no explanation and can read as an error.
Fix: card footer caption "Confirm runs this as Dana Okafor, with your privileges."; the Done reply pattern ends "Shall I show you the audit entry?" and the navigation tool opens Audit database with the agent-marker filter applied; the pill's tooltip reads "Screen context is sent to api.anthropic.com".

**[Judge]** — No Stop, no new conversation (§ Judge §4, §7 — `panel` Busy; panel header)
A mistyped prompt during the recorded demo runs to completion (60–90 s); the only clean slate is a new tab, and a reload restores the messy transcript with its cards expired. A judge probing restraint will ask "can I stop it?".
Fix: Send becomes Stop while Busy (cancels at the next tool boundary; card "Stopped by you at <step>"); a "New conversation" button-text in the panel header — both per the reconcile note.

**[Judge]** — The name cell does not look like a link (§ Judge §7 — `data-table` identifier columns; row hover; name link)
Identifier columns are `code` in on-surface; the row hover and the name link share the same cell, so the voter who clicks the name to select lands in the editor and needs Back.
Fix: name cells take `secondary` with underline on hover and a pointer cursor; row hover stays on the row; the first-run message says once "click a row to select it, its name to open it".

**[Judge]** — The side bar on Home shows the previous area (§ Judge §1 — `side-bar` "stays open across routes"; Home locator)
It "stays open across routes", so Home reads "Home" in the locator beside a PERMISSIONS list, and it eats 224 px of the tile row.
Fix: navigating to Home collapses the side bar; the remembered state returns on the next area click.

**[Judge]** — Area tiles say the name, not the contents (§ Judge §3 — `area-tile`)
A judge ticking "Operating system management (processes, disks, CPU, memory, devices)" sees "OS management" and a circle. The area names already match the six bullets closely.
Fix: each tile carries its side-bar entries as a caption ("Processes · Locks · System usage · Databases · Devices") so the contest parentheticals are visible on Home.

**[Judge]** — Adding a screen is not fully derivable from the spine (§ Judge §6 — EXPERIENCE.md archetype matrix; route ids; panel registration)
The archetype matrix carries the states, but nothing says how an entity id becomes a route segment (`/csp/myapp` → `csp-myapp`; a task name with spaces; `_SYSTEM`), nor what a screen must register for the panel: entity-type key for change events, allow-listed route id, context serializer, highlight target.
Fix: a ten-line "Screen contract" in EXPERIENCE.md — route pattern and id encoding, side-bar entry, archetype, privilege resource, entity-type key, context serializer, primary action, row-menu items, empty-state sentence, fixed strings.

**[Judge]** — Test connection failure breaks the error rule (§ Judge §1, §6 — Definition form Test connection; sticky bar "Saved")
"The provider's error text verbatim" is an Anthropic JSON body with no next step; Save without a passing test leaves a disabled definition signaled only by the attention dot.
Fix: "The provider refused the request. Check the key and try again. Provider said: <text>"; the sticky bar shows "Saved — disabled until Test connection passes." on that save.

### Low (26)

**[Flow coverage]** — "Confirmed by <user>" — login name or full name is unspecified (§ EXPERIENCE.md:520 · DESIGN.md:1053)
"Confirmed by <user>" is rendered as "Confirmed by Dana Okafor" (EXPERIENCE.md:520, DESIGN.md:1053) while Dana signs in as `_SYSTEM` in UJ-2/UJ-5. Whether `<user>` is the login name or the full name is unspecified; the status-bar "user" segment has the same ambiguity.
Fix: one word in Fixed strings: user name (what the audit database records) or full name.

**[Token completeness]** — `destructive-container` / `on-destructive-container` are defined but unused (§ DESIGN.md:71–72, 135–136, 689, 707, 1047)
`destructive-container` / `on-destructive-container` (DESIGN.md:71–72, 135–136) are defined and given a story ("Delete, terminate, remove locks, and every typed-name confirmation", 707) but no component, rule or contrast row uses them; `button-destructive` uses `destructive`/`on-destructive` only. Same for `tertiary`'s four roles, though those are explicitly kept for Material (689).
Fix: either give the destructive container a use (the destructive proposal's 3 px bar region at 1047 is the natural one) or note it as reserved the way `tertiary` is.

**[Token completeness]** — The user bubble's radius is the only shape not expressed through a token (§ DESIGN.md:384, 1015 · 196, 856)
The user bubble's radius is a literal `'12px 12px 2px 12px'` (DESIGN.md:384, 1015) where `{rounded.lg}` is 12 px (196, 856). Harmless, but it is the only shape in the file not expressed through a token.
Fix: `'{rounded.lg} {rounded.lg} 2px {rounded.lg}'`.

**[Component coverage]** — Naming drift for the turn-ending error: "error card" vs a `banner` (error) (§ EXPERIENCE.md:301 · DESIGN.md:1019)
PRD and EXPERIENCE call it an **error card** (EXPERIENCE.md:301); DESIGN renders it as "a `banner` (error) in the agent's slot" (1019). A consumer searching DESIGN for "error card" finds nothing.
Fix: one sentence in the EXPERIENCE state row: "rendered as a `banner` (error) beside the avatar".

**[Component coverage]** — `empty-state`: "No illustration" vs a 32px placeholder icon (§ EXPERIENCE.md:249 · DESIGN.md:975)
EXPERIENCE.md:249 "No illustration"; DESIGN.md:975 specifies "a 32px icon … (placeholder until the owner's icons)".
Fix: agree (an icon is not an illustration, but say so).

**[Component coverage · Accessibility]** — Row-overflow trigger 24 px vs 28 px; rail-item "48 × 46" vs 48 × 48 (§ EXPERIENCE.md:224, 466 · DESIGN.md:335, 947)
Row-overflow trigger 24 px minimum (EXPERIENCE.md:224, 466) vs 28 px (DESIGN.md:335, 947); rail-item "48 × 46" (EXPERIENCE.md:466) vs 48 × 48 everywhere else. The accessibility review lists the rail-item figure as item (d) of its cross-spine contradictions.
Fix: cite the DESIGN value; fix the typo.

**[State coverage]** — No state for Home's suggested view when nothing needs attention, nor for the Task schedule when the Task Manager is suspended (§ EXPERIENCE.md:90, 298)
No state for Home's suggested view when nothing needs attention (298 lists the attention lines but not the empty case), and none for the Task schedule when the Task Manager itself is suspended (90 promises "Task Manager status and control"). The Home case is escalated by the judge to a high finding ("Home's suggested view is empty on a fresh instance"), which prescribes the content of that state; this entry keeps the Task-schedule gap.
Fix: one row each.

**[Visual reference coverage]** — The frontmatter comment cites a working file that is not being promoted (§ DESIGN.md:23)
The frontmatter comment cites `.working/theme-lantern-tokens.md` (DESIGN.md:23) — a working file that is not being promoted — as the origin of every hex, while the body cites `mockups/color-themes-1.html`.
Fix: cite only the promoted mock.

**[Bloat & overspecification]** — Session rows 11, 12 and 14 have no user-facing state; Privilege Gating restates existing rows (§ EXPERIENCE.md:270, 334–337, 439–454)
Session rows 11, 12 and 14 (334–337) are "not in Release 1" / "no user-facing state"; no consumer of an experience spine reads them. Privilege Gating (439–454) restates the Privilege-disabled state row (270), the rail-item/side-bar/command-bar/row-menu rows and the matrix's permission-denied column; only the self-protection list (447) and the "rail-item itself never disables" rule (453) are new.
Fix: drop the three rows; fold the two new rules into the component rows and delete the section.

**[Bloat & overspecification]** — Decorative asides that do not carry a decision (§ DESIGN.md:800, 1041)
"(12.5px in Bridge; 12px here)" (DESIGN.md:1041); the typography rule about the vendor's Noto Sans (800) when embedded editors are Stage 2+.
Fix: cut.

**[Inheritance discipline]** — The Resource editor is a dialog beyond memlog 41's five cases, untagged; DESIGN's dialog count is stale (§ EXPERIENCE.md:112, 161 · DESIGN.md:1077 · memlog 41)
Memlog 41 decides "dialogs only for set password, resource grant, terminate process, remove locks and delete confirmations"; EXPERIENCE.md:112 and 161 make the **Resource editor** a dialog as well, untagged, and DESIGN.md:1077 still says "the five dialog cases".
Fix: tag the resource-editor dialog `[ASSUMPTION: small three-field form]` or make it a form-page; make DESIGN's count match EXPERIENCE's list (which also carries the audit-event detail and the three warning dialogs).

**[Inheritance discipline · Judge]** — The changed-row highlight "fades and clears" (EXPERIENCE) vs "settles and holds" (DESIGN) (§ EXPERIENCE.md:283, 416 · DESIGN.md:848, 939 · Judge §2)
EXPERIENCE.md:283 and 416 say it "fades over 2 s and clears on the next interaction"; DESIGN.md:848 and 939 say it "settles over 2 s and then holds". Read literally, EXPERIENCE's "fades" ends the highlight before the interaction FR-14 keys it to. The judge's low "Highlight timing conflict" is the same finding: settle and hold — the screenshot needs it.
Fix: "settles to its resting tint over 2 s and holds until the next interaction" in EXPERIENCE.

**[Accessibility]** — Zoom and reflow (§ EXPERIENCE.md Responsive & Platform squeeze rule; `content-min-width` 640; fixed row heights)
At 200% on a 1,440-px laptop the CSS viewport is 720 px: the squeeze rule leaves 720 − 48 − 320 = 352 px for content, below `content-min-width` 640, so *everything* in the column scrolls horizontally — not only the tables the 1.4.10 exception covers. Fixed heights (`row-height` 36, `log-row-height` 28, `diff-row` 24, chips 20, badge 18) will clip under 1.4.12 text-spacing overrides, and a wrapping log text column contradicts a fixed-size virtual-scroll strategy. Related: the judge's high on Home not fitting 1,280 px.
Fix: form-page, banners, the transcript and the proposal card reflow at any width; only data-tables, the raw log and code blocks claim the 2-D exception; heights become `min-height` except in virtualized lists, which use the autosize strategy or a no-wrap column; name the full-screen panel toggle as the zoom accommodation.

**[Accessibility]** — Browser shortcut conflicts (§ EXPERIENCE.md Interaction Primitives — Ctrl/Cmd+K, +I, +B; composer caption)
Ctrl+K takes Chrome's omnibox search on Windows/Linux (overridable with `preventDefault`; not reserved); Firefox binds Ctrl+B (bookmarks sidebar), Ctrl/Cmd+I (page info) and Ctrl+K (search) — best-effort browsers, but say so; Chrome on macOS binds none of ⌘K/⌘I/⌘B. No single-character shortcuts exist, so 2.1.4 does not apply — record that. Add "Shift+Enter for a new line" to the composer's visible caption or `aria-description` (the judge's low on the composer caption asks for the same).
Fix: record the browser-binding caveats and the 2.1.4 non-applicability in the Floor; add the Shift+Enter caption.

**[Accessibility]** — Names, roles and glyphs (§ `rail-item`, `locator-bar`, `panel-resize-handle`, full-screen toggle, skeletons, separators, Home suggested view, max-rows field, Skip link)
Rail-items need `aria-label` = area name (the placeholder initial would otherwise be the name; Material suppresses the describedby when tooltip text equals the label — verify on the installed version); `aria-current` on the active rail-item, side-bar entry and locator segment; locator-bar as `nav aria-label="Breadcrumb"`; `panel-resize-handle` as `role="separator" aria-orientation="vertical"` with `aria-valuenow/min/max` (the window-splitter pattern) so "the new width is announced" has a mechanism; full-screen toggle `aria-expanded` with the hidden content `inert`; skeletons `aria-hidden` inside an `aria-busy` region; "●", "→", "›" and "·" separators `aria-hidden`; Home suggested-view lines are buttons distinct from "Open ›"; the editable max-rows footer field labeled; a "Skip to content" link as the first Tab stop (landmarks serve screen readers; sighted keyboard users get Escape only after they are already in the header).
Fix: add each of the above to the Accessibility Floor's names-and-roles list.

**[Accessibility]** — Tab error dot is color-and-shape only (§ DESIGN.md `tabs`; stepper error step)
`tabs`: "a 6px `destructive` dot after its label". A screen-reader user cannot tell which tab holds the errors before Save switches to one.
Fix: the tab's accessible name gains ", 2 errors"; the stepper's error step uses Material's `errorMessage` text, not only the circle color.

**[Accessibility]** — Dark-mode cosmetics and two marginal passes (§ `server-flag-live-container-dark` on `shell-dark`; `error-container-dark` disc; toast link; selected-row name link)
`server-flag-live-container-dark` on `shell-dark` is 1.15:1 and the `error-container-dark` connection disc 1.72:1 — not failures (the word is always present, text inside the badge is 6.72:1) but the pill outline vanishes; consider a 1px `on-shell` at 20% edge. Marginal passes to guard with a test: toast link `secondary` on `inverse-surface-dark` 4.64:1; the name link `secondary` on a selected row's `secondary-container` 4.56:1 light.
Fix: optional 1px `on-shell` at 20% edge on the dark badges; add contrast tests for the two marginal pairs.

**[Accessibility]** — Running text below the spine's own floor (§ DESIGN.md `proposal-card` body (caption 12px); Typography "13px body is the floor for running text")
`proposal-card` body is `caption` 12px, yet "Agent's rationale" and "Expected impact" are multi-sentence prose; Typography says "13px `body` is the floor for running text". Not a WCAG failure; a self-consistency one.
Fix: agent text blocks in `body`, keep `caption` for the diff labels and countdown.

**[Judge]** — Countdown pressure (§ Judge §2 — `proposal-card` header countdown)
A 4:59 ticker in the card header reads as a timer to a first-time voter.
Fix: "Valid until 10:47" until the last minute, then the ticking "Expires in 0:59" in warning; tooltip "Proposals expire so a stale diff is never applied."

**[Judge]** — Command-box vocabulary (§ Judge §3 — `command-box`)
"web apps", "REST", "x509", "certificates", "CPU", "disks" should hit.
Fix: an alias list per screen drawn from the contest wording.

**[Judge]** — Sign-out hunt (§ Judge §6 — `status-bar` user segment)
The status-bar user segment has no visible menu affordance.
Fix: a ▾ glyph like the namespace switch.

**[Judge]** — Avatar crop (§ Judge §5 — imports/robot-avatar-64.png; 24 px rendering)
The robot fills about half the 64 px box; at 24 px it is a yellow dot on teal.
Fix: a tighter crop (robot about 80 % of the box).

**[Judge · Accessibility]** — Composer caption (§ Judge §7 — `panel` composer caption)
The composer caption does not name the new-line chord. The accessibility review's browser-shortcuts finding asks for the same "Shift+Enter for a new line" in the visible caption or `aria-description`, and the judge's medium on invisible chords proposes "Enter to send · Ctrl+I to focus" — one caption should carry all three.
Fix: "Enter to send · Shift+Enter for a new line".

**[Judge]** — Panel width jump (§ Judge §7 — `panel` 400 ↔ 50vw on Home transitions)
400 ↔ 50vw on every Home transition with no transition specified.
Fix: 120 ms width transition; none under reduced motion.

**[Judge]** — Toast overflow (§ Judge §7 — `toast` stack beyond three)
Beyond three is unspecified.
Fix: the oldest drops; the row highlight and the ledger keep the record.

**[Judge]** — Demo prerequisite: `/csp/myapp` does not exist on a fresh container (§ Judge §2 — UJ-3; installer; README)
`/csp/myapp` does not exist on a fresh container.
Fix: the installer seeds it disabled with no resource, or the README first has the voter disable one from the row menu (which shows the screen's own action).

## Deduplication ledger

Raw counts: rubric 28 (0 / 4 / 11 / 13), accessibility 20 (2 / 4 / 8 / 6), judge 33 (1 / 8 / 12 / 12) = 81. Six merges → 75 entries above:

- Highlight timing: Rubric §7 low + Judge low → one low (Inheritance discipline · Judge).
- Cancel variant: Judge low → Rubric §3 medium (button variants).
- Read-only footer line: Judge low → Rubric §6 medium (UI copy ownership).
- Table single Tab stop: Judge low → Accessibility high (row actions / grid model).
- Header lockup at README width: Judge medium → Rubric §5 high (transparent logo orphans).
- Rubric §8's pointer ("the two invented sections that duplicate — see §6") folded into the §6 sign-in entry.

Partial overlaps cross-cited without merging: typed-name-field, tool-call-card and rail-item size (Rubric §3 ↔ Accessibility "Contradictions" finding); Home suggested-view empty state (Rubric §4 low ↔ Judge high); proposal expiry (Rubric §1, Accessibility 2.2.1, Judge countdown); composer caption (Judge low ↔ Accessibility browser shortcuts); layout width (Judge 1,280 px ↔ Accessibility zoom reflow).

## Mechanical notes (rubric)

- **Frontmatter key asymmetry.** DESIGN.md uses `name:`; EXPERIENCE.md uses `title:` (line 2). The reference examples use `name` for both. Harmless for humans; a headless consumer keyed on `name` will miss the experience spine.
- **`[ASSUMPTION]` counts.** DESIGN.md has 16 tag occurrences (memlog 63 says 10 — the frontmatter and prose repeat several); EXPERIENCE.md has 19 occurrences (memlog 62 says 14 distinct). Not a defect; the memlog numbers are distinct assumptions, the files repeat them where they apply.
- **Prose vs identifier forms.** Both files use the two-word prose form beside the hyphenated identifier ("side bar" ×12 and `side-bar` ×8 in DESIGN; "proposal card" ×14 and `proposal-card` ×6 in EXPERIENCE). The identifiers themselves are consistent; the prose forms are natural language and match the examples' practice. No action unless a headless consumer will grep prose.
- **Tag case.** DESIGN writes the changed-row tag as "CHANGED" (702, 763, 790, 939); EXPERIENCE writes "Changed" (223, 283, 416, 520). DESIGN's own typography rule says `label` is uppercased only for eyebrows and column headers and "chips keep sentence case" (790, 799), yet `severity-chip` is "uppercase" (967). Decide once: eyebrows and column headers only, or eyebrows plus tags and chips.
- **Two statements of the same dialog set.** DESIGN.md:1077 "five dialog cases" vs EXPERIENCE.md:161's eleven-item list — see the Inheritance discipline low.
- **`spacing.'1'` and `spacing.'5'`** are never referenced by token; the Scale prose (815) names 4 and 20 px directly. Cosmetic.
- **Memlog freshness.** The memlog grew from 63 to 66 lines during the rubric review (transparent imports, the VS Code reconcile note, the reviewer-gate dispatch). Rubric findings cite the 66-line numbering.
- **Nothing broken (rubric).** No unresolved token, no missing source, no missing hex, no missing dark pair, no unnamed component, no UJ without a flow.

## Reviewer files

- `review-rubric.md` — eight-category rubric walk of the spine pair against its seven sources, the memlog, `imports/` and the promoted `.working/` mocks; 28 findings (0 critical, 4 high, 11 medium, 13 low); verdicts strong / strong / adequate / adequate / adequate / adequate / adequate / strong; every token reference resolved by script and every load-bearing ratio recomputed.
- `review-accessibility.md` — WCAG 2.1 AA text contrast (light and dark), keyboard operation and visible focus; every ratio recomputed from the frontmatter hexes (45-row verified-pairs table), Angular Material behaviour checked against v17–v19; 20 findings (2 critical, 4 high, 8 medium, 6 low).
- `review-judge.md` — contest Usability and Developer Experience as Priya (thirty minutes, a laptop, a fresh Community container) and an expert-panel judge; scorecard on four criteria and a "what to show first" list; 33 findings (1 critical, 8 high, 12 medium, 12 low).
