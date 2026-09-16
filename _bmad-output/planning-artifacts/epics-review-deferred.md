# epics.md review - deferred decisions

Findings from the 2026-09-09 `bmad-review` of [epics.md](epics.md) that were **not** applied, because each
needs an owner decision, adds scope, or changes the story roster. The 42 findings that were corrected are
in commits `160d7a2`, `f410600`, `e0f65ab` and `da7be8c`; the full four-lens report is
[epics-review-report.md](epics-review-report.md).

Ordered by when the decision is needed. Every item carries a recommendation so it can be decided quickly.

> **Status 2026-09-09.** The owner decided **D2, D4, D5 and D7** at the start of `/epic-cycle` epic 1
> (branch `OCU-1-epic1`), each as its stated recommendation. All four are **applied** to `epics.md`;
> D2 is also reconciled in the PRD (FR-9, FR-44); D2 and D4 carry Rule 20 writes into the architecture
> spine (AD-44, AD-30) plus two new Consistency Conventions rows. They are no longer open decisions -
> do not re-mine them as such. **D1 remains accepted-unresolved** (no sizing exists; the capacity
> question stands). D3, D6, D8 and D9 are untouched and still open, each falling outside epics 1-3.
> Section 3's edge conditions are now **filed in the deferred-work ledger**, owner-routed to the story
> that must address or decline each one.

---

## 1. Decide before sprint planning

### D1. No sizing exists anywhere *(Adversarial A13)*

84 stories form the binding floor; 18 calendar days; one developer. The cut line is discussed at length as
a **sequencing** device and never once as a **capacity** one, so the plan's central mechanism - "any step
must be able to become the cut" - has never been tested against how many steps are reachable.

Epic 1 is the sharp end: 17 stories including a greenfield Angular workspace, a design-token layer with
automated two-mode contrast checking, a build-failing string-literal lint, a protected-database installer,
Docker, IPM, JWT sign-in, the descriptor registry, all shell chrome, the auto-refresh framework and CI.

**Recommendation.** Add S/M/L per story - Stages 2-6 already carry it - plus one sentence: "at N stories
per day the floor is reached on `<date>`; below that rate the first things to go are X, Y, Z." Do this
before `bmad-sprint-planning`, because the gate will otherwise pass a plan nobody has costed.

### D2. Story 1.15's check and Story 6.4's OAuth link-outs contradict each other *(Adversarial A1)*

Story 1.15 mandates an automated check that **no** list screen in the six areas links out to the classic
portal. Story 6.4 ships the OAuth 2.0 screen as five lists whose name cells link to the classic editor
until Epic 12. Story 17.7 makes the check a condition of the binding 2026-09-27 floor. As written, the
submitted build fails its own check. The PRD carries the same contradiction (FR-9 "a list screen never
links out" vs FR-44 "Every list links to the classic portal editor"), so whatever is decided has to go
back there too.

**Three ways out, pick one:**

| | Option | Cost |
|---|---|---|
| a | Declare the OAuth tabs **detail views, not lists**, and give Story 1.15's check a defined exemption predicate | Cheapest; slightly strains the word "list" |
| b | Move a **minimal OAuth entry view** into Release 1 so the name cell opens an OcuPilot route | Real work in the tightest week |
| c | Amend Story 17.7's floor AC to record the OAuth screen as the **one dated exception**, counted against SM-C1 | Honest, but ships below the stated floor |

**Recommendation: (a).** It costs nothing to build, keeps the floor claim true, and SM-C1 already exists to
count exactly this.

### D3. The fingerprint re-read has two homes *(Adversarial A5)*

Story 5.3 already requires confirm to re-read the target and compare the fingerprint. Story 10.6 is titled
"The target fingerprint re-read" and sits in Epic 10 as one of "the last three guards". A developer may
skip it in Epic 5 as "Epic 10's job", or a reviewer may mark 10.6 done because 5.3 covered it.

**Recommendation.** Keep the re-read in Story 5.3 (it belongs to the floor) and rewrite Story 10.6 down to
what is genuinely only its own: the **enumerated-id-set fingerprint** for application-error deletes and the
**mismatch card treatment** (warning banner inside the card, footer offering only Re-propose). Update the
FR-17 coverage line to match.

---

## 2. Decide before the epic concerned starts

### D4. Enforced read-only is specified in a stretch story *(Adversarial A4)*

The coverage map assigns "enforced instance-wide read-only" to Epic 3, but Story 3.7's criteria cover only
the banner, the footer status line, the point-of-effect evaluation and the in-flight stop. The behaviour
FR-19 actually requires - every write tool returning a structured "blocked by read-only mode" result, the
agent stating what it would have changed and on which screen, and **no proposal card appearing** - is
written only in Story 10.4, a build-step-7 stretch about the *per-user* toggle.

If step 7 is cut, which the plan explicitly permits, enforced read-only ships as a banner over an agent
that still mints proposal cards, and UJ-4's climax is unbuilt.

**Recommendation.** Move those three clauses into Story 3.7 and reduce Story 10.4 to what its own text
says it is ("data and UI, not a new enforcement point"). Also add to 3.7 the case of a write tool already
in flight when the switch flips. **This moves work into the floor - hence a capacity decision, see D1.**

### D5. No story specifies the OcuPilot API's own dispatcher *(Adversarial A6)*

Build step 0 lists "the OcuPilot API skeleton" and the harvest names "the `API/Router.cls` thin-wrapper
and `OnPreDispatch` structure ... keeping all three UrlMap ordering invariants". Story 1.1's criteria cover
only `Response`, `Error`, `Log` and `Utils`. Every custom endpoint - login, refresh, logout, turn,
progress, transcript, lock state, definition CRUD, messages.log, application errors, alerts tail,
readiness - hangs off a router with no acceptance criteria and a named trap.

**Recommendation.** Add an AC block to Story 1.1 rather than a new story (keeps the roster stable): the
`UrlMap` with its three ordering invariants asserted by test, `OnPreDispatch` doing authentication and
namespace resolution once, `ReadRequestBody`/`DecodeUtf8Stream` on the harvested `Utils`, and a routing
test that a percent-encoded id in one path segment reaches the right handler.

### D6. Release 1 has no context-window management *(Adversarial A9)*

Epic 4 notes the harvested `AgentLoop` "has no context-window trimming at all"; Story 18.12 says context
management is what "this stage is the first to need". Meanwhile Story 4.5 restores prior turns on reload,
Story 4.4 sends up to 200 rows per turn, and Story 4.1 bounds a turn only by iteration count, wall clock
and total tokens. Story 4.8 covers 429, 5xx and timeout - **not** a 400 "context length exceeded".

**Recommendation.** Do not add trimming; add the failure criterion to Story 4.8 ("the turn ends with an
error card naming the cause and offering New conversation") and record it as a documented Release 1
limitation. Trimming is Stage 2 work; an unclassified provider 400 in front of a judge is the actual risk.

### D7. Transcript retention is configurable but unenforced *(Adversarial A10)*

Agent definitions carry a retention period from Release 1 and transcripts persist from Release 1 carrying
each turn's screen context, but the purge task lands only in Story 14.4 ("the rest as time allows").
Neither installer story creates a scheduled task, though Story 13.1's uninstall hook removes "the
scheduled tasks" - an object no story creates.

**Recommendation.** Disable the retention field in Story 3.1 with the caption "Retention is not yet
enforced" until Story 14.4 ships, and reconcile Story 13.1's uninstall list with what the installer
actually creates. Cheaper than moving a purge task into the floor, and it stops the field promising
something nothing does.

### D8. Story 16.6 rewrites the shared selection model in the last epic *(Adversarial A15)*

Story 16.6 states it is "the one Release 1-era screen needing multi-select, which the data table otherwise
does not offer - so the selection model is extended here". UX-DR29 mandates "Single selection everywhere in
Release 1"; Story 2.4 specifies "one row at a time"; UX-DR30's APG grid model ties selection to arrow-key
movement. This touches the component all ~60 screens use, during the voting week, in an epic whose own
preamble says "Nothing here may break a Release 1 screen."

**Recommendation.** Give broadcast a **target-picker dialog** that does not touch the table's selection
model. Second choice: declare `selection: single | multi` per descriptor in Story 2.4, unused in Release 1,
so the shared component is built once. If neither, require the full data-table and APG-grid regression
suite to pass in 16.6.

### D9. The security model's own proof is optional at the deadline *(Adversarial A18)*

NFR-6 names five invariants, the fifth of which **is** the seeded-injection test. That test is Story 10.8,
in Epic 10 - "the stretch; anything not reached by the deadline ships first in the polish week". So the
entry can ship claiming "the model is assumed fully compromised" with no test proving any of it.

*(The circular half of this finding - the AC listing the test itself among the invariants it was proving -
has already been corrected.)*

**Recommendation.** Move a **minimum** seeded-injection test into Epic 4 or 5: one seeded source (a tool
result), asserting zero proposals and zero navigations. Leave the six-source sweep in Story 10.8. One
invariant verified at the floor is worth more than five verified only if there is time.

---

## 3. Edge cases to fold into stories

51 conditions the acceptance criteria leave unhandled, from the Edge-Case Hunter lens. Each adds scope, so
none was applied. They are listed by owning story in
[epics-review-report.md](epics-review-report.md) under *Lens: Edge-Case Hunter*; the JSON form is
[epics-review-findings.json](epics-review-findings.json).

The three already folded in are E3 (downgraded code against forward-migrated state, now in Story 1.4),
E37 and E41 (FR-17's unbuilt refusal conditions, now in Story 5.3).

**Recommendation.** Do not bulk-add them. Take each story's slice as its **ledger inbox** when that story
is planned - the `/epic-cycle` pipeline already has this mechanism (`LEDGER slice <key>`), and it forces
each condition to be either addressed in the story's criteria or declined with a reason. The clusters
worth reading before their epic starts:

| Cluster | Findings | Why it matters |
|---|---|---|
| Propose/confirm lifecycle (Epic 5) | 12 | The densest cluster in the review, and the demo is built on it |
| Sign-in, tokens, tab duplication (Epic 1) | 3 | E5 (concurrent 401s each triggering their own refresh) can sign a user out mid-demo |
| Install, upgrade, readiness (Epic 1) | 6 | E1 - a login during install reads as bad credentials on a judge's first load |
| Demo fixtures (Story 1.4) | 3 | E15/E16 - UJ-6 and the Logs demo have no data on a clean install |
| Self-lockout prohibitions | 3 | E43 - a change to OcuPilot's own web application breaks sign-in instance-wide |
| Agent definitions and providers (Epic 3) | 4 | E22 - endpoint hostname resolving to loopback is an SSRF path |

---

## 4. Document restructures

Structure-lens recommendations not applied, all content-preserving. None is urgent; each is a half-hour of
mechanical work whose value is navigability.

| | Change | Saving | Why deferred |
|---|---|---|---|
| S2 | Merge the duplicated epic summaries (20 of 22 are byte-identical between the Epic List and the epic bodies); move `Implementation notes` into the body and `Applies to every story` out of it | ~1,203 words | Changes what a per-story reader sees; interacts with S15's caveat about agents reading one story |
| S3 | Move the 22,587-word Requirements Inventory behind the epics as an appendix | 0 | Explicitly a trade-off: better reading order for the human, worse self-containment for an agent handed only this file |
| S6 | Add anchor links to the ~490 `Epic N` / `Story N.M` cross-references (the file has 1,129 identifier references and zero Markdown links) | 0 | Adds real noise to the raw text every agent reads, to fix a problem only the human has |
| S7 | Make the Epic List a table, removing the 22 duplicate `###` headings that collide anchor slugs | 0 | Folded into S2. Confirmed harmless to `sprint_plan.py` |
| S8 | Move Epic 17's 942-word contest-strategy essay out of the Epic List into the epic body | 0 | Safe, but only worth doing alongside S2 |
| S9 | Merge the three overlapping FR traceability structures into one table, keeping split rationale as a column | ~800 words | The prose glosses are genuinely useful; merging them badly loses the *why* behind each split |
| S10 | Split `Additional Requirements` (7,603 words) into Architecture Constraints / Build Order and Gates / Open Questions | 0 | Reorders a heavily cross-referenced section |
| S14 | `What gates the stage` appears on 3 of 5 stage epics - decide whether Epic 21's absence is a decision or a gap | - | Owner's call. The reading guide now says a missing paragraph is a statement, so this is no longer misleading either way |
| S18 | Split Story 1.2 "The design system" (816 words, 12 scenarios, 5.9x the median story) | - | **Changes the story roster** `sprint_plan.py` generates - owner decision |

Three findings were **PRESERVE**: the 11 epic preambles' DRY (with the caveat now covered by the reading
guide), all 206 stories' `As a`/`I want`/`So that`/Given-When-Then shape, and the document's line-level
redundancy (~77 verbatim-repeated words in 72,123 - the document is not over-written).

---

## 5. Prose items not applied

- **P8.** UX-DR62 is a single **275-word** sentence covering all ten write-lifecycle steps; the document's
  next-longest is 142 words. Splitting it after the fourth step is safe but touches the canonical
  description of the write lifecycle - worth an owner's eye rather than an editor's.
- **P9 (partial).** `the sibling's mapping manager` at Story 18.2 still reads "the sibling". The other four
  bare references now name their repository, but no harvest document attributes the `%`-global guard, so
  naming one would be a guess. **Owner: which repo is this?**
- **Minor.** `2s` (UX-DR sections, 4x) versus `two seconds` (stories, 14x) for the same threshold, and
  `10 seconds`/`ten seconds` likewise. Each section is internally consistent, and the UX-DR shorthand is
  arguably correct in a spec; normalising would touch 18 places for marginal gain.
- **Not a defect.** The lens flagged "three `Then` clauses opening with a conditional `would`". On
  inspection all but one are genuine counterfactuals ("the same 403 the screen *would* produce") and
  correct as written; the one real instance was corrected.
