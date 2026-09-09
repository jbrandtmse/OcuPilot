# BMad Review — [epics.md](epics.md)

**Reviewed:** 2026-09-09 (against the pre-correction file; see [epics-review-deferred.md](epics-review-deferred.md) for what was applied)
**Reviewed:** 2026-09-09 · **Content:** 6,069 lines / 458 KB / ~72,000 words · 22 epics, 206 stories
**Content class:** docs with a behavioral surface
**Lenses run:** Adversarial · Edge-Case Hunter · Editorial Structure · Editorial Prose (after Structure)
**Not run:** Verification Gap — `applies_to: code`; the working tree is clean and there is no diff.
**Settings:** reader_type `humans` · style_guide `Microsoft Writing Style Guide` · output_format `both`

**Totals:** 111 findings — Adversarial 22 · Edge-Case Hunter 54 · Structure 18 (+3 minor) · Prose 17 (+7 minor).

No lens proposed cutting scope, changing a requirement, or altering a technical decision. The editorial
lenses treated content as sacrosanct by contract; the behavioral lenses propose added or relocated
acceptance criteria, never removed ones.

---

## Cross-lens convergence

Overlap between lenses is signal, not duplication. Four findings were reached independently by two lenses:

1. **Proposal lifetime is bound to its turn's lifetime, and "died" is never distinguished from
   "completed."** Adversarial #3 and Edge-Case #33 both land on Story 5.1's final AC (epics.md:2535-2537).
   Read literally, no proposal is ever confirmable, because a turn normally ends the moment it emits the
   proposal card. This is the single highest-confidence defect in the document: two lenses with different
   stances, given no knowledge of each other, produced the same finding with the same line reference.

2. **The fingerprint re-read has two homes.** Adversarial #5 (Story 5.3 vs the stretch Story 10.6) and
   Edge-Case #34 (volatile fields inside the fingerprint) converge on the same guard being both
   duplicated and under-specified.

3. **Enforced read-only is specified in the wrong story.** Adversarial #4 places FR-19's actual behavior
   in Story 10.4 (a step-7 stretch) rather than Story 3.7; Edge-Case #41 finds the missing terminal card
   state for a read-only switch that flips between mint and confirm.

4. **Section-scoped drift.** Structure #1 (fused CommonMark paragraphs split by section) and Prose #1/#2
   (component-name hyphenation and US/British spelling, both splitting along the same UX-DR vs. story
   boundary) describe one underlying cause: the requirements sections and the story sections were written
   to different conventions and never reconciled.

**What the two behavioral lenses agree the document's weakest area is:** the propose/confirm lifecycle
(Epic 5). Adversarial contributes 5 findings there, Edge-Case 11. It is also the epic the demo is built
around.

---

## Lens: Adversarial — 22 findings

**A1 · Story 1.15 (1391-1393) vs Story 6.4 (3088-3090) vs Story 17.7 (5165-5168)**
Story 1.15 mandates an automated check that *no* list screen in the six areas links out to the classic
portal; Story 6.4 ships the OAuth 2.0 screen as five lists whose name cells link to the classic editor
until Epic 12; Story 17.7 makes "no list screen links out" a condition of the binding 2026-09-27 floor.
**Fix:** resolve in one place — declare the OAuth tabs detail views with a defined exemption predicate,
move a minimal OAuth entry view into Release 1, or amend the 17.7 floor AC to record the exception
against SM-C1. The PRD carries the same contradiction (FR-9 vs FR-44), so the resolution pushes back there.
**Consequence:** the submitted build fails its own automated check and sits below the floor the document
calls "the thin interface the contest rules reject" — found in Story 17.7's single late assessment pass.

**A2 · Epic List "Epic 17 floats" (689) and Epic 17 ordering note (4972) vs Stories 17.4 (5066), 17.5 (5099)**
Both places claim Epic 17 has "no forward dependency at all — every screen, every agent write and every
polish-week item its walkthrough might photograph already exists." Story 17.4 targets release 2026-09-24;
the polish week is 2026-09-28 to 2026-10-04. At the actual target none of Epics 11-16 exists.
**Fix:** rewrite the ordering note to say Epic 17 runs *before* the polish week, so the walkthrough
photographs the Release 1 build only; re-check every Epic 17 AC assuming a later epic landed (17.6's
"nothing it shows is a mock-up or a build that no longer matches").
**Consequence:** the stated reason for placing Epic 17 last is false, so a reader schedules the
submission after the voting week begins — after the hard deadline.

**A3 · Story 5.1 final AC (2535-2537); AD-40 restatement (206)** *(converges with E33)*
"Given the turn that minted a proposal dies / When confirmation is attempted / Then it is refused." A turn
normally ends the moment it emits the proposal card. The document never distinguishes "died" from
"completed", nor says what records the difference.
**Fix:** add an AC defining the turn's terminal states and which invalidate a proposal — refused when the
turn ended `abandoned`, `stopped` or `error`; a `completed` turn leaves proposals confirmable until their
own 10-minute expiry; the turn record carries the terminal state and outlives the job for that window.
**Consequence:** implemented literally, no proposal is ever confirmable and Epic 5 does not work;
implemented loosely, a proposal from a turn abandoned for privilege loss stays confirmable.

**A4 · Story 3.7 (2043-2071) vs FR-19 (62), FR Coverage Map (486), Story 10.4 (3980)**
The coverage map assigns "enforced instance-wide read-only" to Epic 3, but Story 3.7's ACs specify only
the banner, footer status line, point-of-effect evaluation and in-flight stop. The behavior FR-19 requires
— write tools returning a structured "blocked by read-only" result, the agent stating what it would have
changed and where, and *no proposal card appearing* — is written only in Story 10.4, a step-7 stretch.
**Fix:** move those three clauses into Story 3.7; reduce 10.4 to "data and UI, not a new enforcement
point" as its own text says. 3.7 also needs the case of a write tool in flight when the switch flips.
**Consequence:** if step 7 is cut — which the plan permits — enforced read-only ships as a banner over an
agent that still mints proposal cards. UJ-4's climax is unbuilt and the safety claim is cosmetic.

**A5 · Story 5.3 (2614-2617) vs FR Coverage Map FR-17 (484) and Story 10.6 (4014-4036)** *(converges with E34)*
Story 5.3 already requires confirm to re-read the target and compare the fingerprint; Story 10.6 is titled
"The target fingerprint re-read" and sits in Epic 10 as one of "the last three guards". One guard, two
homes, one of them a stretch item.
**Fix:** pick one. Strike the fingerprint clauses from 5.3 and say the floor is weakened, or delete 10.6
and rewrite the FR-17 map line. Keep 10.6's distinct content — the enumerated-id-set fingerprint for
application-error deletes and the mismatch card treatment — wherever it lands.
**Consequence:** a developer skips the re-read as "Epic 10's job", or a reviewer marks 10.6 done because
5.3 covered it, and the mismatch card treatment is built by nobody.

**A6 · Story 1.1 (906-909); build order step 0 (289); harvest requirements (271)**
No story specifies the OcuPilot API's own `%CSP.REST` dispatcher. Step 0 lists "the OcuPilot API skeleton"
and the harvest names "the `API/Router.cls` thin-wrapper and `OnPreDispatch` structure … keeping all three
UrlMap ordering invariants" — but Story 1.1's ACs cover only `Response`, `Error`, `Log` and `Utils`.
Every custom endpoint hangs off a router with no acceptance criteria and a named trap.
**Fix:** add a story or AC block for the router: the `UrlMap` with its three ordering invariants asserted
by test, `OnPreDispatch` doing auth and namespace resolution once, `ReadRequestBody`/`DecodeUtf8Stream`
on the harvested `Utils`, and a routing test that a percent-encoded id reaches the right handler.
**Consequence:** the flagged trap is rediscovered at runtime as endpoints silently shadowing each other,
in build step 0, on the critical path for every later epic.

**A7 · Stories 1.4 (1046-1049) and 1.5 (1064-1066); FR-65 map (469)**
FR-65 requires `/api/ocupilot` to be password-authenticated, JWT enabled, `UseSession = 0`, joined to the
vendor's `%ISCMgtPortal` `GroupById` group, with no application or matching roles. Story 1.5 covers only
the `/ocupilot` static application; Story 1.4 covers only the CSP Gateway registration gap and the Web
Gateway timeout report. The most load-bearing configuration in the product has no AC in Epic 1.
**Fix:** add to 1.4 or 1.5 an install-time test asserting all of it, including the 60/900 token pair.
**Consequence:** FR-1, FR-2, NFR-3 and UJ-2's first screen depend on settings nothing verifies. Silent
sign-in fails on a fresh install and looks like an authentication bug rather than a missing install step.

**A8 · Story 1.9 first AC (1192-1195) vs Additional Requirements (186) and Story 6.4 (3084-3086)**
Additional Requirements say a descriptor must handle multi-entity screens (OAuth), sub-resource screens
(task history), composite ids, and tool identity independent of screen naming. Story 1.9's descriptor AC
enumerates ten declared things and covers none of those four. Story 6.4 then requires a descriptor
declaring more than one entity type; 6.6 needs a sub-resource screen; 2.5 needs a composite id.
**Fix:** add a fifth AC to 1.9 covering primary plus secondary entity types in change-event routing, a
parent-scope reference for sub-resources, a composite id round-tripping through one shared encode/decode
pair, and a tool name declared independently of the screen name.
**Consequence:** the descriptor mechanism — built in step 0, depended on by ~60 screens — is retrofitted
in Epic 6 for OAuth: exactly the rewrite AD-5 exists to prevent, at the tightest point in the calendar.

**A9 · Epic 4 notes (721), Story 4.8 (4001-4017), Story 18.12 (5390)**
Epic 4 notes the harvested `AgentLoop` "has no context-window trimming at all"; Story 18.12 says context
management is what "this stage is the first to need" — so Release 1 ships without it. Meanwhile 4.5
restores prior turns on reload, 4.4 sends up to 200 rows per turn, and 4.1 bounds a turn only by
iteration count, wall clock and total tokens. Story 4.8 covers 429, 5xx and timeout — not a 400
"context length exceeded".
**Fix:** either add trimming with an AC (budget history against the definition's maximum, drop oldest
first, mark the truncation), or add the explicit failure AC to 4.8 and record it as a documented
Release 1 limitation. State which.
**Consequence:** a long conversation on a busy screen fails with an opaque provider 400 that 4.8 does not
classify, in front of a judge, on the one journey the entry is scored on.

**A10 · Story 3.1 (1852), Story 14.4 (4635-4637), Story 13.1 (4464), Stories 1.3/1.4**
Agent definitions carry a transcript retention period from Release 1; transcripts persist from Release 1
(Story 4.5) carrying each turn's screen context. The purge task lands only in Story 14.4 — Epic 14, "the
rest as time allows". Neither installer story creates a scheduled task, though 13.1's uninstall hook
removes "the scheduled tasks".
**Fix:** move a minimal purge into Epic 1 or 4 with an installer AC creating the task, or disable the
retention field with "Retention is not yet enforced". Reconcile 13.1's list with what the installer creates.
**Consequence:** a configurable retention period that silently does nothing, over data containing screen
context from every turn — the exact problem Story 3.3's user story exists to deny — plus an uninstall
hook removing an object no story created.

**A11 · Story 5.11 (2907-2909), Story 2.11 (1795-1797), Story 3.6 (2022-2023)**
Three ACs cannot be exercised when their story completes. 5.11: "Given Story 6.7 has landed / … / Then the
agent navigates to Task details instead" — an Epic 5 AC verifiable only after Epic 6, and 6.7's own ACs
never say the navigation target changes. 2.11 requires a forced-provider-failure log test, but there is no
provider until Epic 3 (where 3.2 duplicates it). 3.6 requires a static example proposal card matching a
component whose spec the coverage map assigns solely to Story 5.2, two epics later.
**Fix:** move each clause to the story that can satisfy it — give 6.7 an AC re-pointing the navigation tool
and re-running UJ-6; delete the provider clause from 2.11; move the example card to 5.2 or declare the
dependency in Epic 3's notes.
**Consequence:** stories marked done on unverifiable criteria; the "no forward dependency" property the
epic ordering claims is quietly false; UJ-6's destination is never changed because neither story owns it.

**A12 · FR to Story Index (605, 632) and UX-DR Coverage Map (648, 649, 664, 672, 675)**
The index asserts every FR-1..FR-79 resolves to at least one story, but FR-16 resolves partly to "Epic 6
preamble". The UX-DR map assigns UX-DR31 to "Epic 7's preamble", 32-33 and 55-57 to "Epic 8's preamble",
76-77 to "Epic 6's preamble", 80's widths to "Epic 8's preamble". A preamble is not a work item, has no
ACs, and will not appear in the sprint status file. Separately, four of UX-DR80's five `[ASSUMPTION]`
closures are assigned to stories whose ACs never mention confirming them; only 6.9 has an explicit one.
**Fix:** give each preamble a story ("Story 7.0: the row-overflow menu component", "Story 8.0: the
form-page shell"), or reassign each preamble-owned UX-DR to the first story that builds it. Add closure
ACs to 1.10 (24px status bar), 4.3 (640px content minimum), 6.14 (28px log rows), and the form widths.
**Consequence:** sprint planning generates no work item for the row-overflow menu, the form-page shell, or
four of five assumption confirmations — and the coverage maps, the document's only traceability
mechanism, assert coverage that does not exist.

**A13 · General — Epic List preamble (681) and the whole story set**
No sizing, estimate or capacity statement anywhere, while the entire structure rests on a hard external
date. Epics 1-10 hold 110 stories, each with five to ten multi-clause ACs; steps 0-4 (Epics 1-7, 84
stories) are the binding floor. One solo developer, 18 calendar days. The cut line is discussed at length
as a *sequencing* device and never once as a *capacity* one.
**Fix:** add a sizing pass — even S/M/L per story, as Stages 2-6 already carry — plus one statement: "at N
stories/day the floor is reached on <date>; if the rate is lower, the first things to go are X, Y, Z."
Epic 1 in particular (17 stories: greenfield Angular workspace, design-token layer with automated two-mode
contrast checking, build-failing string-literal lint, protected-database installer, Docker, IPM, JWT
sign-in, descriptor registry, all shell chrome, auto-refresh framework, CI) should be split or costed first.
**Consequence:** the plan's central mechanism — "any step must be able to become the cut" — is never
tested against how many steps are reachable, so the project discovers at step 2 that steps 3 and 4 were
never possible, with the floor already unreachable.

**A14 · Epic 11 preamble (4110), Epic 16 preamble (4780), Story 12.3 (4336-4338), Epic 14 header (4539)**
Three epics require new write keys to be "added to Epic 14's governance baseline rather than left to
default", and Story 12.3 states its audit-database *purge* is restrained because the Epic 14 policy
defaults it to disabled. Epic 14 is scheduled "the rest as time allows" and ranked after Epics 11, 12, 13
— all of which ship before it.
**Fix:** make the restraint local. Add to 12.3: available from the screen only, not registered as an agent
write tool, registered in the same change that adds the policy. Apply to every polish-week write, and
state the ordering constraint in Epic 14's header rather than in the epics that depend on it.
**Consequence:** if Epic 14 is cut — which its own scheduling permits — the agent gains a confirmed write
that destroys the audit database, with the only stated restraint in an epic that never shipped.

**A15 · Story 16.6 (4886-4888) vs UX-DR29 (377) and Story 2.4 (1608)**
Story 16.6 says it is "the one Release 1-era screen needing multi-select, which the data table otherwise
does not offer — so the selection model is extended here". UX-DR29 mandates "Single selection everywhere
in Release 1"; Story 2.4 specifies "one row at a time"; UX-DR30's APG grid model ties selection to
arrow-key movement. Extending selection touches the component all ~60 screens use, in the last,
lowest-priority epic whose own preamble says "Nothing here may break a Release 1 screen."
**Fix:** give broadcast a target-picker dialog that does not touch the selection model, or move the
extension into Story 2.4 as a descriptor-declared capability (`selection: single | multi`, multi unused in
Release 1). If neither, require the full data-table and APG-grid regression suite to pass afterwards.
**Consequence:** a last, time-boxed story rewrites the selection and keyboard model of every list during
the voting week, breaking exactly the Release 1 screens its epic promises not to break.

**A16 · Story 18.7 (5296-5300) vs Additional Requirements, AD-26 (198)**
AD-26 records that `Security.Encryption.Settings` "is excluded by the v2 pin." Story 18.7 requires
"database encryption with its startup settings" to round-trip through the admin API, and Epic 18's
preamble adds "encryption changes" to the destructive keys — presupposing the endpoint exists at v2.
**Fix:** add a first-task AC establishing the reachable subset against the instance, with the
startup-settings half either behind an explicit version gate or recorded as a classic-portal link-out.
The same check belongs in Epic 18's "What gates the stage".
**Consequence:** a whole story in the first post-contest release is planned against an endpoint the
architecture already recorded as unreachable, discovered only when the developer opens it.

**A17 · Story 4.5 (2287) and UX-DR49 (400) vs NFR-1 (157)**
NFR-1 requires "first visible progress (a tool-call card *or the start of a reply*) within ten seconds".
Story 4.5 narrows this to "the first tool-call card appears within ten seconds"; UX-DR49 restates it as
"The first card appears within 10 seconds of Send." A turn that answers without calling a tool — which
"Explain this screen" and any conversational follow-up will do — produces no card.
**Fix:** restate the AC as NFR-1 has it, and add the zero-tool-call turn to Story 4.5's state list.
**Consequence:** the most common turn shape in the polish week (Epic 11's one-click explains) has no
responsiveness criterion, and a tester marks the AC failed for a turn that behaved correctly.

**A18 · Story 10.8 (4067-4078) and Non-functional coverage, NFR-6 (574)**
NFR-6 names five invariants, the fifth of which *is* the seeded-injection test. That test is Story 10.8,
in Epic 10 — "the stretch; anything not reached by the deadline ships first in the polish week". The
security posture's own verification is optional at the deadline. 10.8's third AC is also circular: it
lists "the five invariants the defence actually rests on" and closes with "and this test passed".
**Fix:** move a minimum seeded-injection test into Epic 4 or 5 — one seeded source, asserting zero
proposals and zero navigations — and leave the six-source sweep in Epic 10. Rewrite the third AC to list
the four structural invariants without including the test in its own precondition.
**Consequence:** the entry ships claiming "the model is assumed fully compromised" with no test proving
any of it, and the AC meant to prove it cannot be evaluated because it presupposes its own result.

**A19 · Story 5.10 (2857-2879), Story 5.5 (2687), Story 10.7 (4046-4048)**
Disabling auditing is chosen as the Security area's showcase confirmed write, and it destroys the
mechanism FR-22, FR-7 and NFR-7 all rest on. It is not in the prohibited set and not declared destructive,
so it carries no typed-name confirmation — the agent can switch off its own accountability with less
friction than deleting a device. The only restraint is the in-card warning sentence.
**Fix:** declare the auditing-off write destructive so 10.7's typed-name field applies, and add an AC
requiring the typed-name field and `destructive` bar for any proposal disabling auditing or an OcuPilot
audit event type. Record explicitly why it is not prohibited rather than leaving the omission silent.
**Consequence:** the single write the demo showcases has the weakest confirmation, and a reviewer who
notices reads the whole safety model as unexamined — precisely the reading Epic 5 exists to prevent.

**A20 · Story 4.1 (2137) vs Story 10.5 (4004)**
Story 4.1 fixes "a bounded number of concurrent turns — one in Release 1, enforced on the instance", and
4.5 builds the conversation lock on it. Story 10.5 then makes a per-user concurrent-turn limit
administrator-configurable, with no floor, ceiling, default, or statement of what happens to the lock if
an administrator sets it to three.
**Fix:** state that the permitted range in Release 1 is exactly 1 and render the field read-only with its
reason, because the lock and the panel's single transcript assume one turn per user; widening it is a
Stage 2 change. Or specify the multi-turn panel behavior, which nothing currently does.
**Consequence:** an administrator raises the limit, the exclusive lock and single-transcript panel are no
longer sufficient, and two turns write progress records the panel renders as one conversation.

**A21 · General — Story 1.4 (1037-1039), Operational envelope (225)**
Upgrade is "install again", exercised by an `up` with a newer image against an existing durable volume,
and the envelope requires "OcuPilot's state carrying a schema version that migrates forward on first start
and never in a request". No story has an AC for that migration. By the polish week the protected database
holds definitions, switches, the ledger, transcripts, per-user UI state and governance policy. Story 1.4
asks only that the upgrade "reach the same working state".
**Fix:** add an AC: given state at schema version N, a newer image migrates forward before the web
applications accept traffic; existing ledger rows, transcripts and definitions survive with their values;
a migration failure fails install loudly rather than serving partial state; a test exercises N → N+1 with
populated data.
**Consequence:** the daily path silently loses or corrupts the ledger during the voting week, when the
entry is being publicly improved daily and every publish exercises the upgrade path.

**A22 · General — undefined identifiers; Story 4.3 (2222), UX-DR52 (403)**
`SM-C1` appears at UX-DR40, Story 6.4 and Story 12.9 and is never expanded; `UJ-1`, `UJ-2`, `UJ-4`, `UJ-6`
are cited as acceptance context with partial expansions and `UJ-5` is never mentioned at all; the catalog
codes (`SH-`, `CP-`, `WA-`, `PM-`, `SS-`, `TM-`, `OS-`, `LG-`, `PK-`, `EX-`, `IO-`, `AN-`, `DT-`, `SA-`,
`SO-`) carry the entire scope of Epics 18-22 with no legend. Separately, the "administrator reminder"
banner is required in Story 4.3's fixed banner order and listed in UX-DR52, but no story defines its text
or the condition that raises it.
**Fix:** add an "Identifiers used in this document" block after the Overview expanding SM-1..SM-4 and
SM-C1..SM-C2, listing UJ-1..UJ-6 by name and owning story, and pointing at the catalog's key. Add an AC
to 3.7 or 4.3 defining the administrator-reminder banner's condition and string.
**Consequence:** a developer on Story 6.4 or 12.9 cannot tell what "counts against SM-C1" obliges; UJ-5 has
no owner and is verified nowhere; the panel ships with a banner slot nothing fills, which the state-set
acceptance (UX-DR73) will fail on.

---

## Lens: Edge-Case Hunter — 54 findings

Conditions the acceptance criteria leave unhandled. Grouped by the area of the plan they land in.

### Install, upgrade and readiness (Epic 1)

| # | Location | Trigger condition | Guard to add | Consequence |
|---|---|---|---|---|
| E1 | 1095-1104 | Silent probe or form login runs while install is still running | A login against a not-yet-installed API renders the "installing" state, never a sign-in failure | Judge's first load reads as bad credentials rather than install in progress |
| E2 | 1448-1451 | Install fails; readiness reports only installed, version and running | Readiness carries a fourth state "install failed" with the failing step | A failed install is indistinguishable from one that never started |
| E3 | 1033-1044 | Container starts with code older than the recorded state schema version | Install refuses and reports when stored schema version exceeds the deployed code's | Downgraded code silently runs against forward-migrated state |
| E4 | 1074-1076 | Container upgrades OcuPilot while a browser holds the old bundle | The API returns its build stamp; a mismatched client is prompted to reload | Old SPA calls an upgraded API and fails in undefined ways |
| E13 | 1424-1427 | Neither HSCUSTOM nor USER exists, or the documented override names a missing namespace | Install validates the target namespace exists and fails loudly naming it | Install fails obscurely or lands in an unintended namespace |
| E17 | 996-999, 2081-2083 | Installer creates the administrative resource and role but grants the role to nobody | Install grants the role to the installing user, or documents the required grant | No one can configure the agent; the first-login gate never fires |

### Demo fixtures (Story 1.4)

| # | Location | Trigger condition | Guard to add | Consequence |
|---|---|---|---|---|
| E14 | 1051-1054 | Operator's instance already carries a real `/csp/myapp` application | The fixture path is genuinely namespaced, or install refuses on collision | Demo enables and grants a resource on the operator's real application |
| E15 | 1051-1054 | Fixture list omits the suspended task Stories 2.8 and 5.11 require | Story 1.4's fixture set includes a task suspended after an error | UJ-6 has no data on a clean install; the Tasks demo cannot run |
| E16 | 1051-1054 | Clean install has no application errors for the Logs area's confirmed write | The demo opt-in seeds application errors, or the Logs demo names another write | One-confirmed-write-per-area is unreproducible on the judge's own path |

### Sign-in, tokens and tabs (Epic 1)

| # | Location | Trigger condition | Guard to add | Consequence |
|---|---|---|---|---|
| E5 | 1117-1121 | Several in-flight calls return 401 at once, each triggering its own refresh | Refresh is single-flight; concurrent 401s await one refresh, then retry | Refresh-token rotation invalidates the pair and signs the user out mid-session |
| E6 | 1136-1143 | Logout call fails or the instance is unreachable during sign-out | Tab storage clears and the form login shows even when logout errors | Tokens remain in the tab on a shared machine after apparent sign-out |
| E7 | 1111-1115 | Tab duplication copies sessionStorage, including token pair and conversation id | A per-tab nonce is stamped; a duplicated tab re-authenticates and starts a new conversation | Two tabs silently share one token and one conversation lock |

### Namespace scope, privileges and shell (Epic 1)

| # | Location | Trigger condition | Guard to add | Consequence |
|---|---|---|---|---|
| E8 | 1266-1268 | User can read a namespace but not write it | List every readable namespace; gate its write actions rather than hiding the namespace | Read-only screens become unreachable, contradicting gated-never-hidden |
| E9 | 1270-1277 | Route carries an `ns` that does not exist or the user cannot enter | An unresolvable `ns` renders a named error and falls back to a permitted namespace | Deep link renders an empty or wrongly-scoped screen with no explanation |
| E10 | 1192-1201 | Roles or classic-page custom resources change after the startup-resolved privilege set | The privilege map re-reads on any 403 and after a permissions change event | Navigation gating disagrees with the instance until a call fails |
| E11 | 1237-1239 | Instance reports no server flag, or one outside the four named | An unset or unrecognised flag renders a defined default badge with its word | Status bar and Home instance line render an empty badge |
| E12 | 1328-1338 | Detail route or deep link loaded for an entity that no longer exists | A 404 on a detail route renders "no longer present" with a link back to the list | Deleted entity produces a generic error or a blank detail screen |

### Data table and log viewer (Epic 2)

| # | Location | Trigger condition | Guard to add | Consequence |
|---|---|---|---|---|
| E18 | 1592-1594 | User types an arbitrarily large value into the editable max-rows field | Max rows clamps to a server-enforced ceiling and the clamp is reported | Unbounded fetch defeats the bounded-read rule and the two-second floor |
| E19 | 1600-1604 | Active row vanishes on a silent re-fetch or filter change, not a delete | Any re-fetch dropping the active row moves focus and selection exactly as a delete does | `aria-activedescendant` points at a recycled row and focus is lost |
| E20 | 1778-1788 | `messages.log` absent, unreadable, or the manager directory moved between calls | A missing or unreadable source returns a named refusal, distinct from an empty page | Viewer shows an empty log, implying the instance logged nothing |

### Agent definitions and providers (Epic 3)

| # | Location | Trigger condition | Guard to add | Consequence |
|---|---|---|---|---|
| E21 | 1863-1869 | The single default definition is disabled by an endpoint change or deleted | Define the fallback — promote another enabled definition, else the configuration-empty state | Every user's panel silently stops working with no stated state |
| E22 | 1896-1898, 1962-1965 | Endpoint hostname resolves to loopback, link-local or the instance itself | Validate the resolved address at call time, not only the URL literal | SSRF to instance metadata or local services through a DNS name |
| E23 | 1927-1931 | Referenced environment variable or IRIS credential is missing when a turn runs | An unresolvable credential fails the turn with a named reason and flags the definition | Turns fail with an opaque error the ladder is forbidden to explain |
| E31 | 2264-2267 | Administrator sets the instance context default off while users remember "on" | State whether the instance setting is a default for new users or an enforced ceiling | Existing users keep sending screen data after the administrator turned it off |

### The turn: dispatch, progress, abandonment (Epic 4)

| # | Location | Trigger condition | Guard to add | Consequence |
|---|---|---|---|---|
| E24 | 2116-2118 | `JOB` cannot start (license, process limit) after the turn id was returned | The endpoint confirms the job started, else returns an error instead of a turn id | Panel polls forever for a turn that never ran |
| E25 | 2129-2132 | Re-check demands privileges of remaining steps the model has not yet chosen | Re-check the next step's privilege at dispatch, plus enabled-user status between steps | Criterion is unimplementable as written and gets skipped entirely |
| E26 | 2129-2132, 2060-2063 | Turn abandoned for lost privilege, kill switch, wall clock or iteration cap | Each abandonment renders a named terminal card and string, like the timeout card | Turn stops with no reply and no error, reading as a hang |
| E27 | 2136-2137 | Second conversation's send refused by the instance-enforced per-user turn limit | The per-user refusal carries its own banner string, distinct from the conversation lock | Send is refused citing a conversation that is not actually running |
| E28 | 2148-2151 | Progress record dies with the turn between two polls | The terminal progress record persists until fetched, or the transcript carries the reply | Completed turn polls as 404 and its reply is never rendered |
| E29 | 2299-2313 | Tab reloads mid-turn; transcript restores with no running cards | A restored transcript reattaches to the running turn and offers Stop | Lock refuses every message with no reachable way to stop the turn |
| E30 | 2246-2256 | Descriptor omits or under-declares its secret-typed field list | A descriptor with no declared secret-field list fails the build, as read/write declarations do | Secret-typed fields leave the instance because nothing declared them |
| E32 | 2374-2389 | User answers "stay" after the agent already announced its destination | A cancelled navigation posts a correction to the log and suppresses the heading announcement | Log claims a screen was opened that the user never reached |

### Propose and confirm (Epic 5) — the densest cluster

| # | Location | Trigger condition | Guard to add | Consequence |
|---|---|---|---|---|
| E33 | 2535-2537 | Turn ends normally while its proposal still has minutes of validity *(converges with A3)* | Define the turn's terminal states; only abnormal termination invalidates its proposals | Every proposal becomes unconfirmable the moment its own turn finishes |
| E34 | 2509-2512, 2939-2941 | Target's live counters or last-run stamp change between propose and confirm *(converges with A5)* | The fingerprint covers operator-settable fields only; volatile fields excluded by default | Legitimate confirms refused as "target changed" on any busy object |
| E35 | 2526-2529, 3628-3638 | Non-merging endpoint needs the whole object including a never-returned secret | State how unchanged secret fields are preserved inside a complete-property-set payload | Editing a description blanks the stored secret or demands re-entry every save |
| E36 | 2557-2559, 3712-3714 | Payload carries a secret field the user is not actually changing | A secret input is required only when the diff changes that field | Every user edit demands the account password before Confirm |
| E37 | 2613-2618 | Definition or conversation changes between mint and confirm, as FR-17 requires refusing | Confirm also refuses when the definition or the originating conversation has changed | Two promised refusal conditions appear in no story and go unbuilt |
| E38 | 2632-2634 | Confirm response lost in transport after the atomic transition committed | On transport failure the card resolves from the proposal's terminal state on reconnect | User cannot tell whether the write ran; card stuck mid-transition |
| E39 | 2578-2581 | Throttled tab or clock skew leaves client countdown ahead of server expiry | Expiry is server-authoritative; a late confirm resolves to Expired with Re-propose | Confirm refused with no explanation while the card still shows time |
| E40 | 2531-2533, 2784-2786 | User switches namespace or screen while a proposal is live | The card names its scope and warns before Confirm when the current scope differs | User confirms a write into a namespace they are no longer viewing |
| E41 | 2583-2585 | Enforced read-only turns on between proposal mint and confirm *(relates to A4)* | Add a read-only terminal card state and status string alongside the kill switch | Refusal renders with no defined status line among the nine card states |
| E45 | 2959-2963, 3488-3490 | Some enumerated error ids are already gone when confirm runs | State whether a partially-missing id set refuses or deletes the remainder, and report it | Confirm errors out, or silently deletes a set other than the one shown |
| E46 | 3464-3470 | Locks acquired between propose and confirm fall inside "all locks of this process" | Fingerprint the enumerated lock set, exactly as the application-error delete does | Confirmation removes locks the user never saw or reviewed |
| E51 | 2869-2875 | User abandons the demo after disabling auditing and before re-enabling it | The disable proposal states restoration is manual, and a persistent action re-enables it | Instance left permanently unaudited; every later agent write goes unmarked |

### Self-lockout prohibitions

| # | Location | Trigger condition | Guard to add | Consequence |
|---|---|---|---|---|
| E42 | 2699-2701, 3319-3321, 3768-3774 | Human disables OcuPilot's web *service* (permitted) but not its web *application* (refused) | State per prohibition whether it binds model-originated writes only or every caller | Self-lockout blocked on one path and allowed on the equivalent one |
| E43 | 3730-3738 | Change to `GroupById`, JWT or authentication on OcuPilot's own API application | Prohibit by effect any change to OcuPilot's own applications that breaks sign-in | Silent-first sign-in and the classic-portal fallback break instance-wide |
| E44 | 3792-3794 | Installer-created named SSL configuration is deleted or its verification disabled | Refuse deleting it; the agent reports a missing configuration rather than falling back | Every provider call fails, or proceeds over unverified TLS |

### Async values, logs and multi-entity screens (Epics 6, 12)

| # | Location | Trigger condition | Guard to add | Consequence |
|---|---|---|---|---|
| E47 | 3229-3232, 3189-3191 | Async free-space call or a meter value fails or times out | A failed async value renders a terminal "(unavailable)" cell, never a permanent skeleton | Skeleton pulses forever and reads as still loading |
| E48 | 3258-3260 | Monitor API entries overlap the bounded `alerts.log` file tail | Merge by a stated key and ordering so each entry appears exactly once | Duplicate alerts, or entries ordered wrongly against the file |
| E49 | 3266-3269 | Log entry spans lines or lacks time, pid or severity | An unparseable line renders verbatim in the text column with no severity chip | Stack traces dropped or mis-attributed to the preceding entry |
| E50 | 3076-3086 | One screen carries five entity types under the one-read-tool-per-screen contract | State whether each tab declares its own read, gate and truncation report | Either one uncapped read returns five lists, or four tabs get no tool |

### Governance and submission (Epics 14, 17)

| # | Location | Trigger condition | Guard to add | Consequence |
|---|---|---|---|---|
| E52 | 4587-4589 | Policy denies a call; the tool-call card's status set is fixed at six | Add a governance-disabled status to the card's enumerated statuses and the string table | Denied calls render with no defined status or accessible name |
| E53 | 4573-4577 | A Release 1 write tool or action key is renamed after the freeze | Renames carry their baseline entry forward; a key with no baseline match fails the build | Rename silently disables a shipped write and breaks the six-writes metric |
| E54 | 5040-5043, 5065-5069 | Open Exchange review has not approved the listing when the application is submitted | The application waits on listing approval, with that wait budgeted before 2026-09-27 | Application made against a listing that does not yet exist |

---

## Lens: Editorial Structure — 18 findings (+3 minor)

**Structure model applied:** Reference/Database (206 stories accessed randomly, not read start to finish);
front matter judged as Strategic/Context (Pyramid). Story bodies score near-perfectly; almost every
finding is in the 46.5% of the document that is *not* stories.

**Word budget (72,123 total):** stories 38,586 (53.5%) · Requirements Inventory 22,587 (31.3%) ·
Epic List 5,541 (7.7%) · epic-body preambles 2,891 (4.0%) · Overview 231 (0.3%).

| # | Target | Change | Rationale |
|---|---|---|---|
| S1 | Every `**Given**/**When**/**Then**/**And**` block (2,587 lines, ~789 scenarios) and the `FR-n:`/`NFR-n:`/`UX-DR-n:` lists (36-452) | **CONDENSE (formatting)** — blank line between scenario lines, or make each requirement a `- ` item | **Highest impact, zero word cost.** Consecutive non-blank lines are one paragraph in CommonMark, so GitHub and VS Code preview collapse these. 176 requirement entries render as **26 run-on paragraphs**; worst is UX-DR "Panel and agent components" (12 entries → one **1,323-word** paragraph); all 14 NFRs → one 449-word paragraph. Raw text is unaffected, so the agent reader never sees it — this is entirely a cost to the human. |
| S2 | `## Epic List` `### Epic N:` entries (5,541 words) and `## Epic N:` bodies (2,891 words) | **MERGE + MOVE** — cut the duplicated summary from the body; move `FRs covered` and `Implementation notes` into the body | 20 of 22 epic summaries are **byte-identical** in both places (1,203 words). Worse, the half a builder needs while working (`Implementation notes`, 3,773 words) sits in the table of contents while `Applies to every story` sits in the body. Saves ~1,203 words. |
| S3 | `## Requirements Inventory` (32-678, 22,587 words, 31.3%) | **QUESTION / MOVE** — relocate below the epics as an appendix, leaving the coverage maps in place | A reader traverses 22,587 words mirrored from `prd.md` and the UX contract before reaching the list of what is being built. Filed as a QUESTION because of a real trade-off: self-containment for an agent handed only this file vs. map-first reading order for the human. Net word change 0. |
| S4 | No table of contents; no "how to use this document" | **ADD** — a reading guide in `## Overview`, plus a TOC (~80 words) | 6,069 lines, 235 H3 headings, two audiences with different access patterns, no entry point. The guide should say what the Requirements Inventory is for, that stories carry no inline FR tags *by design* (stated at line 631, discoverable only by reaching it), and that 11 epics carry an "Applies to every story" contract a per-story reader will otherwise miss. Highest navigability return per word. |
| S5 | 40 bold-only lines used as section titles | **CONDENSE (formatting)** — promote to `####` | The document has **zero `####` headings**. The two largest sections (Additional Requirements 7,603 words; UX Design Requirements 7,667) are each subdivided into ~14 unnamed blocks no TOC lists, no anchor addresses, no outline exposes. Zero word cost. |
| S6 | 1,129 identifier cross-references (`FR-` ×442, `Story N.M` ×255, `Epic N` ×231, `AD-` ×112, `UX-DR` ×89) | **ADD** — anchor links on at least `Epic N` and `Story N.M` | The file contains **zero Markdown links**. In 458 KB, "see the deviation note in Additional Requirements" is unresolvable without a search. Cheapest fix covers ~490 references, all to headings that already exist. Zero word cost. |
| S7 | `### Epic 1: …` (691) vs `## Epic 1: …` (883), ×22 | **CONDENSE** — make the Epic List a table (Epic · Name · Build step · FRs covered) | Identical heading text at two levels collides anchor slugs, so every "Epic 3" link is ambiguous and the outline shows each epic twice. **Verified harmless to `sprint_plan.py`** (its `EPIC_RE` matches `#{1,3}` but dedupes via `setdefault`) — a navigation cost, not a tracker bug. Folded into S2. |
| S8 | Epic 17's Epic List entry (819-839, 942 words) | **MOVE** — keep summary + `FRs covered`; move six paragraphs of deviations, accepted costs, risk and sequencing into the body | Every other entry is 106-371 words in a fixed shape. This is a 942-word essay on contest strategy inside what should be a scannable index — 17% of the Epic List for one of 22 epics. Net word change 0. |
| S9 | `### FR Coverage Map` (1,664 w) + `### FR to Story Index` (530 w) + 22 `FRs covered:` lines (~330 w) | **MERGE** — one table: FR · Epic(s) · Story(ies) · split rationale | Three overlapping FR traceability structures, 2,524 words. The Coverage Map's per-FR gloss restates the FR title already given. The split rationale is genuine information and must survive as a fourth column. Saves ~800 words. |
| S10 | `### Additional Requirements` (7,603 words) | **MOVE / QUESTION** — split into `Architecture Constraints`, `Build Order and Gates`, `Open Questions and Superseded Decisions` | Not MECE: architectural invariants, a coding style guide, a build sequence, a dated calendar and a live decision log under one heading. "Build order, which is also the cut line" is referenced *by* the Epic List's ordering rationale (681) and belongs next to it. Zero word cost. |
| S11 | `**Open questions still live (external, not blocking)**` (320), third bullet begins `**Closed 2026-09-09, no longer to be asked:**` | **MOVE** — closed items to a `Resolved` list | A heading saying "still live" containing resolved items invites a reader to re-open a settled question. Two-line fix. |
| S12 | Epic 22 `Implementation notes` (879) vs Story 22.1 ACs (6041) | **MERGE** — keep the eight-group exclusion list once, in the story that makes it testable | Near-verbatim duplication. Saves ~95 words. |
| S13 | `## Overview` first sentence | **CUT** — replace with the reading guide | Unresolved template boilerplate ("decomposing the requirements from the PRD, **UX Design if it exists**, and Architecture requirements") that restates the title; the UX design does exist and is named in the frontmatter. The three paragraphs after it (Scope, Authority order, Stage numbering) are the real orientation and are excellent. Saves ~35 words. |
| S14 | `Applies to every story in this epic` in 11 of 22 epics; `What gates the stage` in 3 of 5 stage epics (18, 19, 20 — not 21 or 22) | **QUESTION** — is the absence a decision or a gap? | A reader who learns stage epics carry a gating paragraph will read its absence from Epic 21 — the largest stage at 165 catalog rows — as an omission rather than as "nothing gates it". Either add it or say in the reading guide that it appears only where something gates. |
| S15 | The 11 `Applies to every story` preambles | **PRESERVE — with caveat** | Genuinely excellent DRY; spot-checked Epic 6 and its stories really do not restate the descriptor contract. **But** an agent handed only "Story 6.5" (90 words) never sees the 200-word contract governing it. Do not restate per story — have the epic-cycle prompt load the epic preamble alongside the story, and say so in the reading guide. |
| S16 | All 206 stories: `As a` / `I want` / `So that` / `Acceptance Criteria:` / Given-When-Then | **PRESERVE** | Verified mechanically: 206/206 carry all four elements; numbering is contiguous with no gaps or duplicates across 22 epics; `---` separators precede all 22 epic bodies. Four stories open with a persona ("As Dana, demonstrating OcuPilot on a video call" — 5.8, 5.11, 10.3, 15.1) — a deliberate demo-narrative choice, not drift. The strongest part of the document. |
| S17 | Line-level redundancy document-wide | **PRESERVE** | Measured: excluding the 20 duplicated epic summaries, only ~77 of 72,123 words are verbatim repeats of a line 12+ words long. Unusually disciplined; there is no bloat to cut and length is not the problem. |
| S18 | Story 1.2 "The design system" — 816 words, 12 scenarios | **QUESTION** — split into a token/type story and a copy/string-table story? | 5.9× the 139-word median story, 1.3× the next largest. The one story where "one story = one sitting" visibly breaks. Raised as a question because splitting changes the roster `sprint_plan.py` generates — an owner decision. |

**3 minor:** FR group headers carry orphan PRD section numbers (`**5.1 Portal shell and sign-in**` … `5.13`)
with no section 5 in this document · `## Overview`, `## Requirements Inventory` and `## Epic List` lack the
`---` separator every `## Epic N` has · the Epic List intro's 476 words of ordering rationale precede the
list they explain.

**Structure summary:** 4 MERGE · 5 MOVE · 3 CONDENSE · 1 CUT · 3 QUESTION · 3 PRESERVE. Estimated reduction
if all accepted: **~2,130 words, 3.0%** — deliberately small. The problems are placement, rendering and
navigation, not length; four of the highest-impact fixes cost zero words. Two comprehension trade-offs
noted: merging the coverage maps loses the prose glosses unless split rationale survives as a column, and
moving the Requirements Inventory costs an agent handed only this file its up-front context.

---

## Lens: Editorial Prose — 17 findings (+7 minor)

**Voice preserved, not edited.** Four deliberate choices the lens identified and left alone: strict ASCII
(458 KB contains exactly *one* non-ASCII character, so the 806 spaced hyphens standing in for em dashes are
a constraint, not carelessness — no global em-dash conversion proposed); the **reason-carrying `Then`**
(nearly every AC appends *why* — "because a `JOB` inherits `$ROLES` at the moment of the spawn" — the
document's best feature and its main defence against an agent building the letter of a story and missing
its point); bold as an emphasis-of-record; and the named-persona openings. Fixed UI strings were not
reworded anywhere, per the document's own authority rule.

| # | Target | Change | Rationale |
|---|---|---|---|
| P1 | Component names split between hyphenated and open forms: `side bar` 14 / `side-bar` 25 · `command box` 9 / `command-box` 14 · `command bar` 11 / `command-bar` 9 · `status bar` 15 / `status-bar` 8 · `context chip` 13 / `context-chip` 1 · `empty state` 8 / `empty-state` 14 · `log viewer` 9 / `log-viewer` 1 · `rail item` 1 / `rail-item` 8 · `locator bar` 6 / `locator-bar` 2 · `data table` 3 / `data-table` 1 | Adopt one stated rule and normalize ~170 occurrences: **hyphenated only inside backticks as the component identifier**; **open in running prose** | **The same sentence appears both ways** — L384 "the `command-bar` shows the active filter with Clear" vs L3293 "the command bar shows the active filter with Clear". The split is by *section* (UX-DR entries hyphenate, story criteria don't), not by grammatical role, so it reads as drift. These strings become Angular selectors and the copy-lint table, and a builder handed one story cannot tell which spelling is the name. |
| P2 | ~60 British spellings against a US baseline: `labelled` ×8, `colour`/`colours`/`coloured`/`recoloured` ×12, `cancelled` ×5, `behaviour` ×6, `licence` ×11, `defence` ×3, `honouring`/`honoured` ×2, plus `centred`, `customised`, `organising`, `organisation`, `judgement`, `localised`, `neighbours`, `e-mail` | US forms throughout | MSWSG is US English. **Three actively contradict the document:** L2575 writes "every live proposal is **cancelled** with the status line "**Canceled** — by your message"" — prose disagreeing with the canonical fixed string in the same sentence; L642/955 say "the seven **colour** rules" where L348 (UX-DR12, the definition) says "the seven **color** rules"; L5276 "the **licence** key, **licence** servers" names IRIS screens actually titled *License Key* and *License Servers*. The document already uses `judgment` (L5192) and `honoring` (L60), so both spellings of the same word are in play. |
| P3 | FR Coverage Map — ` - ` carries two unrelated jobs, sometimes in one line. L459 gloss; L483 sequence; L502 both, nested | Keep ` - ` for the gloss; join epic sequences with `then` | ~30 lines affected. The build order **is** the cut line, so whether these epics are alternatives or a sequence is exactly what the reader came to this map for. L513 already uses a comma-list, so the mark does three jobs across adjacent rows. |
| P4 | `**FRs covered:** FR-80 - 59 post-Release-1 catalog rows …` at L853, L861, L869, L877 (×5) | `FR-80, covering 59 post-Release-1 catalog rows …` | "FR-80 - 59" parses first as arithmetic. Five occurrences, all in epic headers where a reader lands cold. |
| P5 | L753: "…silently creates a stub rather than failing, **which the fresh read plus fingerprint is what covers**." | "…rather than failing **- which is what the fresh read plus fingerprint covers**." | Garbled relative clause — two constructions collapsed into one. The correct phrasing already exists twice (L2883, L3638), so this is the outlier. |
| P6 | L737: "**Two of the two** Release 1 async endpoint paths surface here (AD-26)…" | "**Both** Release 1 async endpoint paths surface here (AD-26)…" | "Two of the two" reads as a partitive and stalls the reader; the sentence's point is completeness. |
| P7 | L4077 (Story 10.8): "**Then** untrusted text entered only as delimited tool-result content and never the system prompt…" | "**Then** it confirms that untrusted text entered only as…; that no write occurred…" | The `Then` has no main clause, so the first item reads as an adjectival participle before resolving as a past-tense verb. This is the AC for the security model's own proof; it should not need re-parsing. |
| P8 | L419, UX-DR62 — one sentence of **275 words** covering all ten lifecycle steps (next longest in the document: 142) | Consider a break after the fourth step | Three times the document's own next-longest sentence, and it is the write lifecycle — the thing most often read cold. A minimal split preserves the entry's shape without touching S1. |
| P9 | Bare "the sibling" with the antecedent ~2,000 lines away: L2191, L2303, L5215, L5857, L5975 | Name the repository, as the document does everywhere else | Two problems. (a) The word does double duty — "sibling proposal" (L205, L419, L2626) means something unrelated. (b) A story handed to an agent in isolation gives it nothing to look up; every other harvest reference names the repo outright ("harvested from iris-session-agent's configuration form", L1855). |
| P10 | "the contest's **named** X" ×4: L1299, L3242, L3620, L3676 | "the screens **the contest names**", "the "devices" **the contest names**", … | The participle reads first as part of the noun phrase ("the contest's named-devices"). L3221 gets it right — "So that the contest's "disks" reads as real operational data" — so the pattern is inconsistent as well as awkward. |
| P11 | The read-only reference tree called three things: L737 `` `irislib/` `` · L3187 "the reference export" · L3682, L3806 "the reference folders" | Use `` `irislib/` `` (or the explicit path) in all four | "Which reference export?" is a real question for an implementer who has only this story open — and the answer is a specific gitignored folder with a specific rule attached. |
| P12 | Past/subjunctive tense in seven Given/When/Then clauses where all ~780 others are present: L1492, L2090, L2450, L2981, L3545, L3638 | Present tense throughout | Present tense is the document's convention and the reason the criteria read as testable assertions. L1487/L1491's counterfactual subjunctive ("**Given** `IsRunningAsync` **were** left at 1") is deliberate and correct — but L1492's "**When** the call **ran**" should still be "runs". |
| P13 | L155: `### NonFunctional Requirements` | `### Non-functional requirements` | Not a word in any register. (Note: the seven index headings are title case while all 22 epic and 206 story headings are sentence case; MSWSG prescribes sentence case throughout, but that is a larger call.) |
| P14 | L837: the announcement post quote ending `approved**…** not subject to appeal` | ASCII `...` | The **only** non-ASCII character in 458 KB, in a document otherwise strictly ASCII by evident design. Renders as `?` or a box in a terminal diff. |
| P15 | L4893 (Story 16.7): "I want the **licence position** and every dashboard meter group," | "I want the instance's **license usage** and every dashboard meter group," | "Position" is opaque; the screen the story then specifies is literally named *License usage* (L4898). Also picks up P2. |
| P16 | L668 "Epic 5 **entire** - Stories 5.1 to 5.7"; L674 "Epic 11 **entire**, plus Story 14.1" | "**All of** Epic 5 …"; "**All of** Epic 11 …" | Postpositive "entire" is nonstandard; in a two-column table the reader has no room to recover from it. |
| P17 | L2887: "As Dana **troubleshooting** on Home," | "As Dana**,** troubleshooting on Home," | The other two named-persona openings both take the comma (L2790, L3944), so this reads as a slip rather than a variant. |

**7 minor:** `2s` (UX-DR, ×4) vs `two seconds` (stories, ×14) for the same threshold, and `ten seconds`/`10
seconds` likewise — the same section-split pattern as P1, with MSWSG favouring numerals for measurements ·
three `Then` clauses opening with a conditional `would` where neighbouring criteria assert · two
adjacent-line repetitions of "the same shape of risk already accepted".

**Prose summary:** net word change ≈ **zero** (~40 words gained from the FR-map "then" insertions and the
P7 lead-in, ~15 lost to tightened clauses) — a copy-edit, not a reduction, matching Structure's finding
that length is not the problem. **Two findings carry most of the value: P1 and P2, together ~230
individual edits.** Both are mechanical and safely scriptable outside code spans, and both matter more here
than in an ordinary document — this text is the source for a copy-lint table and a token lint rule that
will fail the build, and it is consumed one story at a time by agents that cannot see how a term is
spelled 3,000 lines away. No comprehension trade-offs; nothing above cuts an example, a rationale clause,
or a reader-orienting sentence.
