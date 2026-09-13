# Epic 1 Decision Sheet

Twenty-seven ledger entries the cycle could not close on its own authority. Each is here because
a rule said so, not because it was hard: Rule 15 sends a MED finding with high fix-risk to the
owner, Rule 20 sends an AD-vs-AD conflict, and a planning-artifact amendment is never a
reviewer's to make.

Source: `deferred-work.md` at 213 entries — 146 terminal, 40 routed to a later story, 27 here.
Generated 2026-09-13 against branch `OCU-1-epic1`. Nothing below blocks Epic 1's commit history;
all of it blocks the SC-4 merge gate.

Each item gives the question, the options, a recommendation, and what the recommendation costs.
The recommendation is mine and is not a decision. Where several entries collapse into one call,
they are grouped and the group is decided once.

---

## A. Two UX documents with no referee — 8 entries

`DESIGN.md` and `EXPERIENCE.md` were written as peers. Eight stories have now found places where
they disagree, and nothing says which wins. Seven of the eight items below are symptoms; the
first is the disease.

### A1 · DW-139 — no precedence rule between DESIGN.md and EXPERIENCE.md · escalated

Eight recorded divergences: command-box placeholder width, the lockup's accessible name
(`OcuPilot` vs `OcuPilot - Home`), where the sort control lives, which bar renders the
last-update stamp, whether the banner reaches instance-unreachable, full-width strip vs inline
notice, three connection words vs four, and A2's banner question.

- **Options** — (a) EXPERIENCE.md wins on behaviour and copy, DESIGN.md on visual treatment;
  (b) one document wins outright; (c) resolve the eight one at a time and add no rule.
- **Recommend (a).** It matches how the two documents actually read: EXPERIENCE.md is written
  in sentences about what happens, DESIGN.md in tokens and measurements. It also settles A4's
  and A5's shape for free.
- **Cost** — one paragraph added to both documents' headers. Six of the eight divergences then
  resolve mechanically; the lockup name and the sort control still need a call, because both are
  behaviour-and-treatment at once.

### A2 · DW-127 — do the two blocking notices carry a banner? · escalated · low

`DESIGN.md:1066` says yes; `EXPERIENCE.md:348/:428/:429` say no. This is shipped code — Story
1.8's instance notice — so the answer may change a built component.

- **Recommend: no banner.** A blocking notice already owns the whole surface; a banner above it
  is a second announcement of the same thing. Under A1(a) EXPERIENCE.md wins here anyway.
- **Cost** — none if EXPERIENCE.md wins; one component edit in 1.8 if DESIGN.md does.

### A3 · DW-126 — the Fixed strings table has no row for ~15 strings now on screen · escalated · 6 occurrences

The table is declared canonical over every inline quotation, and `strings.test.mjs` has a
converse test that fails the suite if a literal is invented. Missing rows now: the eight area
names, a permission-denied line, the status bar's Server/Instance/Licensed-to labels, the
command bar's filter label, the command box's two result-group labels, copy for five 1.13
failure modes, refresh-rate chip copy beyond `off` and `10s`, and 1.15's classic-link card
caption — which shipped with no caption at all because inventing one would redden the suite.

- **Options** — (a) I draft the rows and you review the copy; (b) you write the copy;
  (c) relax the converse test so unlisted strings are permitted.
- **Recommend (a).** (c) removes the only mechanism keeping copy in one place, which is the
  thing that is working.
- **Cost** — a copy-review pass over roughly 20 short strings. Until it lands, 1.15's card has
  no caption and 1.14 permits only two refresh rates.

### A4 · DW-164 — Home's six tile captions are empty until Epic 2 · escalated

Both UX documents show the caption as a list of the area's screens, so the contest task
statement's parentheticals are visible on Home. Epic 1 builds no screens, and AD-5 forbids a
second source beside each descriptor's `labelKey`, so hard-coding is unavailable.

- **Options** — (a) accept empty captions until Epic 2 fills them; (b) amend the documents to
  describe a caption Epic 1 can render; (c) relax AD-5.
- **Recommend (a).** The captions fill themselves as descriptors land, and it is the only option
  that costs nothing now. Flagging it: Home looks unfinished to anyone who sees it before Epic 2,
  which includes any early demo.
- **Cost** — none, plus the risk above.

### A5 · DW-175 — AD-43 counts ten auto-refreshing screens; EXPERIENCE.md:561 names six · escalated

Nothing in Epic 1 depends on the number. Story 2.3 onward does. Picking one needs the intended
screen roster, which is yours to state.

- **Recommend: name the six.** EXPERIENCE.md enumerates them; AD-43's ten is a count with no
  list behind it, so the six are the only evidence of intent (**inference** — I did not find a
  ten-screen list anywhere).
- **Cost** — a one-line spine amendment, which I make under Rule 20 once you pick the number.

### A6 · DW-179 — the OAuth 2.0 screen's archetype · escalated

`EXPERIENCE.md:142/:522` call it `list`; `epics.md:3325` and `prd.md:698` (FR-44) call its five
tabs detail views. It matters because only a detail view may declare a classic-link exemption,
so this decides whether Story 6.4's exemption is honored or refused.

- **Recommend: `detail`.** Two documents to one, and the PRD is the senior of the three.
- **Cost** — one line in EXPERIENCE.md. Story 6.4 keeps its exemption.

### A7 · DW-163 — an unrecognised system mode is ellipsized with nowhere to read it · escalated

DW-145's fix traded an unbounded stretch for an unreadable value. The clip reaches both the 24px
status bar and Home's instance line. No planning artifact publishes a disclosure pattern.

- **Options** — (a) a tooltip carrying the full value; (b) render it in full on Home and clip
  only in the status bar, the way 1.12 closed DW-146 for the version; (c) accept the clip.
- **Recommend (b).** It reuses a pattern this epic already shipped and needs no new copy.
- **Cost** — one component edit, plus a DESIGN.md line describing the pattern.

### A8 · DW-108 — three blocking surfaces are not announced to assistive technology · decision-pending

The signed-out banner (1.7), the session-ended banner (1.6) and the blocking instance notice
(1.8). The notice replaces the entire product surface with no heading, no live region and no
focus move. `EXPERIENCE.md:582` enumerates the polite `role=status` and `role=alert` messages as
a closed list that excludes all three, so adding them is a UX amendment, not a patch.

- **Options** — (a) open the enumeration: banners `role=status`, the blocking notice a heading
  plus a focus move; (b) leave it closed and accept that three blocking states are silent.
- **Recommend (a).** (b) is an accessibility defect the closed list is currently authoring.
- **Cost** — an EXPERIENCE.md amendment and three small component edits.

---

## B. Spine amendments — 4 entries

### B1 · DW-136 — AD-5's Rule is narrower than what Story 1.9 ships · escalated

AD-5 says "Only one thing is generated from it: the write tools field lists (AD-3)".
`screen-mirror.mjs` generates `screens.generated.ts` from the same descriptors, which
`epic-1-context.md` authorizes and AD-5 elsewhere permits. No implementation change is wanted.

- **Recommend: I sharpen the sentence** under Rule 20, the same shape as this epic's six other
  spine amendments. Flagging it only because you asked to see every spine edit.
- **Cost** — one line.

### B2 · DW-187 — AD-27 and AD-44 are in tension · escalated

AD-27's Rule says every screen keeps FR-9's classic link. AD-44's closed archetype vocabulary
makes an exemption impossible for 12 of 16 archetypes, and `prd.md:298`'s own consequence bullet
agrees with AD-44 — a list screen never links out, a detail view may. Rule 20 calls an AD-vs-AD
conflict a re-architecture, not an amendment, which is why it is here rather than done.

- **Recommend: AD-44 and the PRD win; AD-27's summary sentence is corrected.** The code is
  already right against AD-44; only the sentence no longer holds.
- **Cost** — one sentence in AD-27. No code change.

### B3 · DW-177 — AD-19 says signal store; `screen-store.ts` is a framework-free subscribable · decision-pending · fix-risk high

AD-19's Rule: "live in a signal store … components read signals". `screen-store.ts` holds a
`Set<() => void>` with `subscribe()`/`notify()` and imports no `@angular/core`; `status-bar.ts`
and `command-bar.ts` mirror it into a `signal(0)` generation counter. The deviation originates
in `instance.ts`, not 1.14, but this is the first store AD-19 literally describes, and the
precedent binds all 60 screens. `core/` must stay framework-free to run under `node --test`.

- **Options** — (a) amend AD-19 to name the framework-free store plus signal mirror as the
  shape; (b) change the shape to a real signal store and give up `node --test` on `core/`;
  (c) split — signals in `core/`, and move the tests to the Angular component runner 1.9 added.
- **Recommend (a).** The constraint that produced the deviation is real and load-bearing: `core/`
  under `node --test` is the fastest suite in the project. (c) is defensible later; doing it now
  re-tests 60 screens' worth of nothing.
- **Cost** — one spine amendment. Every future store copies the mirror, which is ~4 lines per
  consumer.

### B4 · DW-206 — nothing marks the install gate `installing` on the IPM path · escalated · fix-risk high

`MarkInstalling` is called only from `container-start.sh:168`. `module.xml` carries one
`<Invoke>`, so `GateStatus` reads `installed` throughout IPM's Compile phase — which recompiles
every OcuPilot class — and IPM's `Enabled=1` WebApplication elements run in Activate, before the
`When=After` Invoke. A Compile/Before Invoke cannot mark on a first IPM install, because the
class is not compiled yet. AD-38's mark clause was written for the container start path and
tolerates a start that cannot mark; IPM is a new path outside it.

- **Options** — (a) extend AD-38 to say the mark is best-effort on any path, and accept that an
  IPM install serves a window where the API answers as installed while classes recompile;
  (b) design an IPM-specific marking step, which needs a live throwaway IPM run to settle.
- **Recommend (a) for Release 1, with (b) charted as a story.** The window exists only during an
  install someone is actively running, and IPM is not the shipped install path — the container is.
- **Cost** — one spine amendment; a story in a later epic.

---

## C. Secrets, packaging, licence — 5 entries

### C1 · DW-49 + DW-59 — the demo X.509 fixture · escalated · fix-risk high · decide together

**DW-49:** a private RSA key is checked into `OcuPilot.Install.Fixture.cls` source. Real
secret-scanner bait. By design per the class's own rationale: no supported ObjectScript API
generates an X.509 certificate at install time, and shelling out was rejected as an
undocumented-internals risk.

**DW-59:** because the fixture sets `Certificate` and the transient `PrivateKey` directly rather
than going through `%SYS.X509Credentials.LoadCertificate`, the credential lands with empty
`SubjectDN`, `IssuerDN`, `Thumbprint`, `SerialNumber` and validity, and `HasPrivateKey=0`. The
AC's observable (the alias exists) holds; Story 6.3's Security lists would show a mostly-empty
row.

A later review found `PKI.CAServer.Configure` generates a CA certificate and key to files, and
`%ZHSLIB.TLS.Utils` uses it — so a supported generate-at-install path may exist after all.

- **Options** — (a) research the `PKI.CAServer` path and generate the pair at install, deleting
  the checked-in key and fixing both entries at once; (b) keep the checked-in key, document it
  as a demo-only fixture, and accept the empty metadata; (c) drop the X.509 fixture from the
  demo set entirely.
- **Recommend (a), charted as a story, with (b) as the fallback if the research does not land.**
  It is the only option that removes the key from source. Flagging the real risk: it is
  research, not a correction, and it could dead-end.
- **Cost** — one story. Until then a private key sits in a repo that goes public on 2026-09-24 —
  **this one has a date on it.**

### C2 · DW-48 — the start hook compiles every `Test.*` class into the production instance · escalated

The container start hook compiles the whole `src/OcuPilot/` tree, fault-injection fixtures
included. Two consequences: a compile error in any test class fails every container start, and
`Install.DemoTask` ships on every path, demo flag off or not. Exclusion needs either a roster
AD-17 forbids or a tree move that changes `FIXED_PACKAGES` and 1.16's `module.xml` input.

- **Options** — (a) move tests to a sibling tree (`test/OcuPilot/`) excluded from both the start
  hook and `module.xml`; (b) accept it — the instance is a demo instance; (c) filter by package
  prefix in the start hook, which AD-17 arguably forbids.
- **Recommend (a), charted as a story.** It is the only option that survives a real deployment,
  and it also removes the fail-every-start hazard.
- **Cost** — one story; touches `FIXED_PACKAGES`, `module.xml`, the start hook and every test
  class's path.

### C3 · DW-38 — the OFL licence texts do not travel with the fonts · decision-pending

Verified after a real build: `dist/…/browser/media/` holds five hashed `woff2` files and no
licence text. `3rdpartylicenses.txt` is esbuild's npm extract, sits one directory above the
served root, and names neither Inter nor JetBrains Mono. SIL OFL 1.1 §2 requires the notice to
accompany each distributed copy; near-universal web practice ships webfonts without one, so
whether the source-tree copy suffices is a call, not a defect.

- **Options** — (a) add the two OFL texts to `angular.json`'s `assets` so they land beside the
  faces; (b) ship an `ATTRIBUTIONS` file at the repo root and in the IPM module; (c) accept the
  source-tree copy.
- **Recommend (a) and (b) together.** Both are cheap, and (a) is the one that satisfies the
  clause as literally worded.
- **Cost** — two `angular.json` lines and one file. No code.

### C4 · DW-166 — the expired-password banner links "the README" to the repo's GitHub URL · decision-pending

`sign-in.ts:37`. The URL is the real remote, correct after release, and UJ-5's judge arrives
from it — but before 2026-09-24 it 404s for anyone but you, and it puts your account name in
shipped copy. The state is unreachable on this build (1.6 verified an expired password returns
an ordinary 401), so the exposure is latent. It ships inside a private instance's bundle, so it
is not publication.

- **Options** — (a) unlink the phrase until release, leaving the sentence; (b) keep the URL;
  (c) point at a release-neutral home.
- **Recommend (a).** It costs one line now and one line back on release day, and it is the only
  option with no account name in the bundle before the repo is public.
- **Cost** — one line, twice.

---

## D. Gates that cannot fail — 5 entries

The family this epic kept finding: a check that passes because it looked at nothing.

### D1 · DW-32 — the promised UrlMap route-ordering check does not exist · escalated

Story 1.1's Design Notes say the three routing invariants "are enforced by a structural check
over the router's XData UrlMap". `check-objectscript.py` has four checks and none parses a
UrlMap. When the entry was written the production UrlMap was empty, so there was nothing to
validate a new rule against — that is no longer true.

- **Recommend: build the check now**, charted into the burn-down story. Real routes exist to
  test it against, which was the blocker.
- **Cost** — part of one story.

### D2 · DW-96 — the SQL grant is install-created state nothing fingerprints · escalated · fix-risk high

`EnsureSqlPrivileges` grants `OcuPilot_Kernel_State` to the DBRESOURCE role on every install.
`StateFingerprint` folds the two applications and the shell role but not the grant, so a revoked
or widened grant leaves the fingerprint byte-identical while the install gate answers
`INSTALL.INSTALLING` to every non-`%All` caller — which is the live defect this step was added
to fix. `tSchema` is a literal derived from nothing and pinned by nothing.

- **Recommend: fold the grant into `StateFingerprint`** and derive the schema name rather than
  transcribing it. The reason it is escalated rather than fixed: reading a SQL grant inside
  `StateFingerprint`'s switched-namespace window needs its own failure sentinel, and picking
  that sentinel's semantics is a design call.
- **Cost** — part of one story. **This is the entry I would put first** — it is the only one
  here that can make a healthy instance refuse every caller with no signal.

### D3 · DW-207 — `RosterNames`' two refusals are exercised by nothing · escalated · fix-risk high

The non-absolute-path and empty-asserted-set refusals are what the corrected docs name as the
real anti-vacuity protection. `RosterNames` is `Private` and builds its input through a hard
`##class(OcuPilot.Install.Roster).Application` call, so no subclass seam can hand it a bad
roster: deleting either refusal leaves the whole suite green. The JavaScript half of both rules
is now covered.

- **Recommend: add an overridable roster seam** on the production installer, which is precisely
  what a reviewer may not do on its own authority.
- **Cost** — part of one story. Small.

### D4 · DW-213 — a source-text pin read from the instance's compiled copy · escalated · fix-risk high

`TestFixtureCreateUsesTheCallersNamespaceNotTheResolvedDefault` never calls `Create`. It reads
the class back with `%Compiler.UDL.TextServices.GetTextAsString` and asserts a substring — so
any rewrite that reaches the wrong namespace without touching that literal stays green, and the
subject is the instance's compiled source rather than the committed file. Noted by the reviewer
as a general property of every source-text pin in this suite.

- **Recommend: a `Fixture` namespace seam**, or fold it into DW-193's container run (routed to
  1.17). Worth a sweep for other source-text pins at the same time.
- **Cost** — part of one story.

### D5 · DW-186 — the eight-refusal link-out rule is two hand-maintained copies · escalated

`classic-links.mjs` reads `exemption.exempt === true`; `Base.ClassicLinkExempt()` is
`''..NestedField(...)`, and `''1` is 1 — so `{"exempt": 1}` is a half-made declaration to the
build and an honored exemption to the registry. Each engine's corpus is a literal inside its own
language's test, no test drives both, and the refusal sentences already differ in ways the I/O
matrix calls "the same sentence". The build copy fails closed and is gated; `Registry.Validate`
has no production caller.

- **Options** — (a) a shared JSON corpus both engines read, with a test per engine over it;
  (b) delete the ObjectScript copy, since it has no production caller; (c) accept the drift.
- **Recommend (a).** (b) is tempting and cheaper, but the registry copy is the one that runs on
  a customer instance where the build gate never ran.
- **Cost** — part of one story.

---

## E. Product behaviour — 5 entries

### E1 · DW-44 — should an idempotent re-install re-emit the RoleGranted audit row? · decision-pending

Verified live: `%SYS.Audit` holds 426 `ROLEGRANTED` and 415 `ROLEGRANTEDPROBE` rows for a role
granted once — one per `Install()` call. `EnsureGrant` has no already-held branch. AD-15 ties
the marker to a write and AC10 forces exactly this already/now distinction on the sibling
auditing step, but AC9's own text — "when install completes … an audit row is written" — blesses
the current behaviour, and AD-46 puts these rows in OcuPilot's own audit screen.

- **Options** — (a) emit only on an actual grant, and reword AC9; (b) keep emitting every run.
- **Recommend (a).** An audit row for a grant that did not happen is a false record, and this
  product's own audit screen displays it. Flagging the cost honestly: it flips
  `TestGrantForRealAccountGrantsAndAudits`, whose row-count assertion is that same AC's evidence.
- **Cost** — one branch, one AC reword, one test rewritten.

### E2 · DW-3 — the stale-bundle reload prompt · decision-pending

The server half shipped in 1.8 (`buildIdentity` on the instance response). The client prompt
needs two things the project does not have: UX copy in neither document, and a real build
identity — `Installer.cls:73` is the literal `'dev'`.

- **Options** — (a) charter both halves (a real build stamp plus the prompt copy) as a story;
  (b) accept it — a container upgrade during a session is a demo-instance non-event.
- **Recommend (a), scheduled after the copy pass in A3.** A real build identity is worth having
  for its own sake, and the prompt is small once it exists.
- **Cost** — one story, plus a build-stamp mechanism (git SHA at image build is the obvious one).

### E3 · DW-124 — AdminPort reads the class definition, not the compiled XData · escalated

The admin API version is derived from the class-**definition** UrlMap XData, so an IRIS build
shipping `%Api.Admin` with its source removed reports version 0 and blocks the whole product on
a healthy instance. Probed 2026-09-12: 133 `%`-classes already ship `Deployed=1`; `%Api.Admin`
is not one of them today. Reading `%Dictionary.CompiledXData` instead survives source removal
but breaks the parity AdminPort's own doc claims — the vendor's `Info()` reads the same
definition dictionary and would report its seed of 1.

- **Options** — (a) leave it: `Test.Instance.TestTheRealAdminApiIsReportedAtVersionTwo` goes red
  at such an upgrade, which is AD-27's designed catch; (b) read the compiled XData and drop the
  parity claim; (c) read the definition, fall back to compiled, and document the asymmetry.
- **Recommend (a).** The failure is hypothetical, the detector exists, and (b) trades a real
  documented property for a hypothetical one.
- **Cost** — none.

### E4 · DW-156 — `GET /namespaces` attempts a connection per namespace · escalated

`%SYS.Namespace.GetAllNSInfo` is called once per namespace with `DontConnect` defaulted to 0, so
on an instance with ECP- or remote-mapped namespaces every list read attempts a connection. This
container has neither, so the cost is invisible here and appears on a customer instance.

- **Recommend: set `DontConnect=1`** in the burn-down story and accept that it cannot be tested
  here. The fix is one argument; the risk of leaving it is a list endpoint that hangs on exactly
  the instances a system-management tool is for.
- **Cost** — one argument, untestable on this instance.

### E5 · DW-39 — the dark-mode class flip reaches 30 roles, not the other 34 · escalated

Parsed from the emitted `styles-<hash>.css`: the `:root.ocu-theme-dark` block re-points 30
`--mat-sys-*` variables and redefines zero `--ocu-*` roles. `--ocu-shell: #0f3a5f` is the only
declaration of that name anywhere, so `var(--ocu-shell)` is light in both modes. Story 1.10 is
named as the first surface drawing shell / on-shell / shell-edge and would have to hand-pick
`var(--ocu-<role>-dark)` per call site — which is not "the flip is a class flip". The spec's own
mechanism sketch shows only `--mat-sys-*` re-points, so the two readings conflict.

- **Options** — (a) define all 34 `--ocu-*` roles under the dark scope, keeping the class flip
  whole; (b) leave it and let Story 15.6 own the whole dark theme (DW-118 already routes there);
  (c) narrow the `--ocu-*` layer so it derives from `--mat-sys-*` and inherits the flip.
- **Recommend (b).** FR-73 already defers the toggle, 15.6 already owns the theme, and DW-118 is
  the same defect described from the other side. Doing it now means designing 34 dark values
  against no dark surface to check them on.
- **Cost** — none now; 15.6 gets larger.

---

## Dispositions

On 2026-09-13 the owner granted standing decision authority and asked for the recommendations to
be implemented. Every item below was decided to its recommendation, with two corrections made
while implementing — both recorded at the item.

**Decided and implemented (15 entries).** A1, A2, A4, A5, A6, A7, A8, B1, B2, B3, B4, C3, C4,
E3, E5. Document and spine amendments are in `DESIGN.md`, `EXPERIENCE.md` and
`ARCHITECTURE-SPINE.md`; code changes are in `sign-in.ts`, `instance-notice.ts`,
`server-flag.ts`, `home.page.ts`, `_components.scss` and `angular.json`, plus
`ATTRIBUTIONS.md`. Build clean, four prebuild gates clean, 575 tools tests and 184 component
tests green. Each carries a terminal ledger trailer naming what changed and where.

Two corrections found while implementing rather than while recommending:

- **A2's polarity was backwards in the first draft.** `DESIGN.md:1066` says "Neither is a
  banner"; EXPERIENCE.md asks for one at three sites. The precedence rule gives treatment to
  `DESIGN.md`, so the shipped component — which had already read EXPERIENCE's "(error)" as a
  colour treatment rather than a stacked component — was right, and the fix was to remove the
  ambiguity at EXPERIENCE.md's three sites.
- **A5 is better grounded than the recommendation claimed.** `EXPERIENCE.md:561` does not
  merely imply six; it names all six. AD-43's "ten" had no list behind it, so the roster is now
  copied into the spine.

**Charted into Story 1.18, the burn-down story (12 entries).** A3, C1 (DW-49 + DW-59), C2, D1,
D2, D3, D4, D5, E1, E2, E4. These are work, not decisions: a story each or part of one. The
decision recorded for each is the option letter above; the implementation goes through 1.18's
own QA and code review rather than landing as a lead amendment.

Ordered by the clock:

1. **C1 (DW-49)** — a private RSA key in a repo that goes public on 2026-09-24.
2. **D2 (DW-96)** — the only entry that can make a healthy instance refuse every caller.
3. **A3 (DW-126)** — 1.15 shipped a card with no caption and 1.14 permits two refresh rates,
   both waiting on this copy.

**Chartered beyond Epic 1.** B4's IPM-native install marking needs a live throwaway IPM run to
settle and belongs with the IPM work, not the Epic 1 burn-down.

The retrospective stays with the owner.
