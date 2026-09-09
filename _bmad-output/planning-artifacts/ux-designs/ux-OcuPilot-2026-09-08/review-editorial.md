# Editorial Review — OcuPilot spines

Run at the direction of `bmad-ux`'s `doc_standards` (`skill:bmad-review lenses=structure,prose`).
Content class: docs. Two targets, two lenses; the prose lens ran on top of each document's
structure findings. Reader type: humans. Style guide: Microsoft Writing Style Guide.

Findings are reported here as the lenses returned them, before triage. What was applied, and
what was declined, is recorded in `.working/editorial-applied-design.md` and
`.working/editorial-applied-experience.md`.

## Editorial Structure — DESIGN.md

Structure model applied: Reference/Database. Section order and names treated as fixed by the
design.md spec. 15,652 words; frontmatter 2,046 (components block 1,329), Brand & Style 1,186,
Colors 2,523, Typography 478, Layout & Spacing 824, Elevation & Depth 389, Shapes 160,
Components ~40 entries, Do's and Don'ts 886.

13 recommendations: 6 condense or merge, 3 move, 1 question, 1 add, 2 preserve. Estimated net
reduction if all accepted: ~980 words, 6.3%. The lens put the honest ceiling near 10% and
called the rest load-bearing reference.

| # | Finding | Shape |
|---|---|---|
| 1 | `toast`, `skeleton` and `attention-dot` restate frontmatter literals, creating two sources of truth for the same number | Condense |
| 2 | Logo asset facts stated three times across the Visual references table, the mark paragraph, and `logo-lockup` / `avatar-agent` | Merge |
| 3 | Four counter-evidence rows (never-drawn and retired pairs) sit in the table headed "this document relies on" | Move |
| 4 | Ten `[ASSUMPTION]` and four `[NOTE FOR …]` markers scattered across 14 locations, three inside YAML comments | Move |
| 5 | The OpenAPI path-and-verb browser is filed under `log-viewer` against its own declaration as a `data-table` composition | Move |
| 6 | Five compositions carry no frontmatter token block and nothing says why | Question |
| 7 | The Material 3 foundation paragraph and the precedence sentence sit behind the logo prose | Move |
| 8 | "The wordmark is never typeset" stated six times | Condense |
| 9 | Three paired rows of Do's and Don'ts repeat their Do cell eight rows apart | Merge |
| 10 | `focus-ring` reproduces eleven ratios already tabulated in §Colors | Condense |
| 11 | The five `###` component group headings carry no orienting line in a 15,000-word random-access reference | Add |
| 12 | `panel` and `proposal-card`, the two largest entries, encode the product's differentiator and accessibility decisions found nowhere else | Preserve |
| 13 | Inline contrast ratios elsewhere in Components are the guard at the point of use for a human reader | Preserve |

## Editorial Prose — DESIGN.md

Voice noted and preserved: compressed spec register, deliberate fragments, house shorthand for
pointers, light/dark ellipsis, spaced em dashes, aphoristic closers.

25 fixes reported, plus a 26-item minor tail. The ones that change correctness rather than
readability: `rail-item`'s hover tooltip specifies its color pair backwards, against both the
frontmatter and the document's own convention; "No opacity anywhere" states the opposite of the
rule it introduces; `header` says it spans "rail to panel" where §Layout & Spacing says full
width; the yield-order sentence names the rail and panel as bounding a row they are inside;
`locator-bar` points at the command box where it means the command bar; a value bolded as
failing reads as passing at 4.50:1; "the white halo" contradicts the dark-mode ratio in the same
clause. The remainder are garden paths, over-long sentences, non-parallel lists, ambiguous
referents, and comma-list ambiguity in the rail order, where two of seven names contain "and".

## Editorial Structure — EXPERIENCE.md

Structure model applied: Reference/Database with a Tutorial tail in Key Flows. 19,473 words;
Component Patterns 3,956, Surfaces 2,757, Voice and Tone 1,658, State Patterns › Panel 1,447.

All eight required sections present and soundly ordered. Both triggered sections earn their
place. Of the four invented sections, Agent Write Lifecycle and Privilege Gating are clearly
earned; Screen Synchronization and Live Data is earned in principle but holds little that is
not stated elsewhere; Session and Sign-in declares itself additive-only and then repeats what
it said it would not.

17 recommendations: 4 cut, 3 merge or move out, 6 condense, 2 question, 2 preserve, 4 small
additions. Estimated net reduction: ~900 words, 4.6%. The lens's own framing: the percentage is
small because the fix for most redundancies is a pointer, not a deletion, and the real result is
that the proposal contract, the gating mechanism, the keyboard model, the size tokens and the
fixed strings each end up with exactly one owner.

| # | Finding | Shape |
|---|---|---|
| 1 | The proposal lifecycle is stated four times in full; "Press Confirm on the card to apply it" appears eight times | Merge |
| 2 | A 19,500-word random-access reference with 28 headings has no contents list and no ownership rule | Condense and add |
| 3 | Agent Write Lifecycle and Privilege Gating are defined after the eight sections that consume them; Privilege Gating is referenced by eight forward jumps | Move |
| 4 | Six table cells exceed 150 words, putting the APG grid model and the proposal anatomy in the least findable place in the document | Move |
| 5 | Session and Sign-in restates the Form login card and Sign out against its own stated contract | Cut |
| 6 | Screen Synchronization and Live Data is a fifth copy rather than a home | Question |
| 7 | Six Interaction Primitives bullets are third statements of their component and state rows | Cut |
| 8 | The six shell size numbers live in three sections; `panel-min` appears seven times, `panel-home` eight | Condense |
| 9 | The eight table key bindings are spelled out three times | Condense |
| 10 | The gated-controls accessibility bullet names its own source and then restates it, dropping the `skipPredicate` point | Condense |
| 11 | Fixed strings are quoted inline in five other sections with no rule making those illustrations rather than second sources | Condense |
| 12 | A release-blocking install prerequisite is the last clause of a 229-word cell in row 24 of a 44-row table | Move |
| 13 | The Surfaces table carries a PRD build-step number the document cannot detect drift in | Question |
| 14 | UJ-3 step 3 re-enumerates the proposal card anatomy already specified twice | Condense |
| 15 | The side-bar screen lists, the six journeys and the voice Do/Don't table serve random access and teaching, against the brevity argument | Preserve |

## Editorial Prose — EXPERIENCE.md

Style preserved: the telegraphic register, `·` enumerations, bold lead-ins, "else" as a
conjunction. Quoted UI strings treated as content and only aligned to each other.

23 fixes reported, plus a 20-item minor tail and one pervasive decision. The ones that change
correctness: six canonical strings drift from their Fixed strings entries, including a context
chip missing the segment its own pattern requires; the off-screen-toast sentence asserts a
consequence its premise does not support and contradicts itself inside one sentence; the
Surfaces legend claims Shell and Session states for `external`, which the state matrix denies;
"the rail with its eight area bands" conflicts with "the seventh area" two lines later; the
Firefox chord bindings are glossed in reverse order, pairing each chord with the wrong conflict;
"one explicit confirmation per proposal, never fewer" leaves the batch-approval prohibition
implicit at the one place the rule is defined; "confirming anything on the agent's behalf" is
ambiguous about who acts for whom in a safety prohibition. The rest are over-long sentences in
the two lifecycle steps most likely to be extracted verbatim into a story, comma splices,
non-parallel lists, numerals below the Microsoft threshold, and two pieces of editorial voice
in a contract.

The pervasive item, offered as one accept or reject: the document uses *login* as its noun and
*sign in* as its verb, which is internally coherent but against the Microsoft guide. The PRD
glossary fixes *silent login*, *form login* and *first-login gate*, so those stay; the
non-glossary usages were aligned.
