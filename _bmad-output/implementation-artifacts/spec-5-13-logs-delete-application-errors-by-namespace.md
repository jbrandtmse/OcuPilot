---
title: 'Story 5.13: Logs - delete application errors by namespace'
type: 'feature'
created: '2026-09-22'
status: 'done'
baseline_revision: '9f6b481ad6b3009e23bc0645db006d31f588344d'
baseline_commit: '64abadd0680c1c1e13eb12103ceb5798dc839ef6'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
warnings: ['oversized']
deferred:
  - summary: >-
      The narrowed process-ownership rule is corrected in the code and in Story 5.12's AC2, and
      nine other places still state the broad reading.
    evidence: |-
      Verified 2026-09-22 after the narrowing landed. epics.md:153 (FR-55), :807 (Epic 7 preamble),
      :3506-3508 (Story 5.5's worked example, which uses "act on the user's own process" to
      illustrate a rule "the instance refuses on the write path regardless of what the UI does" -
      now false) and :5636; EXPERIENCE.md:93, :220 and :414 (published self-protection copy Epic 7's
      row actions will read); prd.md:806; SPEC.md:99. Also spec-5-12-*.md:53, :623, :666, whose
      ## Verification mutation recipes at :928 and :943 name OwnedByCaller, a method that no longer
      exists, so 5.12's Rule 19 evidence is not re-runnable as written. Not patched here: Rule 5
      reserves planning-artifact amendments to the lead, and EXPERIENCE.md's list is published copy
      a UX call governs.
    location: >-
      _bmad-output/planning-artifacts/epics.md:153
    severity: medium
  - 'DW-1423, measured and not fixed. No reachable path emits the change announcement with action deleted: its one shipped call site is announceChanged() in shell/data-table.ts, and application-error is declared by exactly one descriptor (LogErrorList), a drill-down that renders its own grid and is not a DataTable. Story 5.13 therefore does not execute the branch either, so the premise the entry was routed on does not hold. The fixed Updated prefix is left unreworded, because that half is a UX call on the entry. Re-own it to a story whose screen is a DataTable and that can redden it.'
---

<intent-contract>

## Intent

**Problem:** Logs is the last read-only area and the epic's last area leg. Its write is the first
*destructive* one, the first to emit AD-14's `deleted` action, and the first with **no admin API
endpoint behind it** - the deletes are `SYS.ApplicationError`'s, reached through `LogSourcePort`,
whose read half Story 2.12 built. AD-48 governs it almost line by line and says in terms that the
missing endpoint changes none of the write invariants.

**Approach:** Ship `logs.applicationerrors.delete` as an action-style write (AD-51) whose fresh read
is a new `LogSourcePort` enumeration of the error ids in the drilled-to namespace, whose declared
fingerprint subject **is** that enumerated id set, and whose confirm removes exactly those ids. Give
the kernel write path a per-tool **port declaration** so a write that issues no vendor request is an
ordinary write rather than a special case, give the proposal card its removal-row form, and give the
error-log drill-down its change-event handling. Four of the seven inbox entries harden AD-51's seam,
and 5.13 is its first consumer.

**The three planning gaps are resolved** (`## Blocking Condition`), and so are the two the first
implement pass raised: AD-51's identity clause is corrected in the spine and AC2's ownership
prohibition is narrowed to one predicate (`## Spec Change Log`, 2026-09-22).

## Boundaries & Constraints

**Always:**

- **`SYS.ApplicationError` is the only door.** `NamespaceList`, `DateList`, `ErrorList`,
  `ErrorDetail` for reads; `DeleteByNamespace` / `DeleteByDate` / `DeleteByError` for writes. No
  `^ERRORS` traversal of OcuPilot's own, at any layer, in any test.
- **One `%SYS` window, namespace as a parameter.** The class does not exist in `HSCUSTOM` (probed
  2026-09-22: `%Dictionary.CompiledClass.%ExistsId` is 0 there, 1 in `%SYS`). `LogSourcePort` enters
  `%SYS` once by AD-16's explicit save and restore, never the target namespace, and the target
  namespace travels as the query's first parameter.
- **One namespace source.** The namespace is the level the user drilled to, held in
  `ErrorLogDrill.namespaceValue` and sent as the tool's own argument. The route's `?ns=` (AD-44)
  does not reach this port, at mint, at confirm, or at the re-fetch.
- **The fingerprint is the enumerated id set**, captured at proposal time, never a count and never a
  live re-query. It is AD-51's *declared subject* of the fresh read - not a second fingerprint model
  beside AD-51's (see `## Design Notes`).
- **The deletes are ordinary writes.** Proposal, server-computed diff, explicit confirmation (AD-6,
  AD-34), the caller's own privileges through the port's own gate (AD-29, AD-8), the agent marker
  (AD-15's ordinary case - this write does not close the audit channel). "No `AdminPort` call" is
  not "not a real write".
- **The gate is per namespace.** `LogSourcePort.PairsFor("applicationerrors", <ns>)` resolves
  `%Admin_Operate:USE`, `%DB_IRISSYS:READ`, then `%DB_<ns>:READ` and `%DB_<ns>:WRITE` from
  `Namespaces.GlobalDatabase`. The WRITE half is the half this story exists for
  (`LogSourcePort.cls:114-121` says so). Administrative resources stay at `USE`, never `WRITE`
  (AD-8 as amended); `%DB_*` resources carry real READ/WRITE and are unaffected by that rule.
- **The captured payload never moves.** `ErrorRead.SUMMARYFIELDS` stays the five summary fields;
  nothing this story adds puts an expression, a stack frame or a variable table into screen context,
  a tool result, a proposal payload, a diff row or a ledger row (AD-24, AD-35, AD-48).
- **Every destructive check runs on the throwaway `ocupilot-ci`**, against errors the test seeded
  itself through `OcuPilot.Test.ErrorLogSeed`. **Never delete an application error on `ocupilot` or
  any `ocupilot-slot-*` container.** One test class or suite per tool call.

**Never:**

- **No by-date and no by-error tool.** Story 7.10 (`epics.md:4297`) is chartered with all three
  scopes and restates the fingerprint, one-namespace-source and per-namespace-gate rules verbatim.
  AD-48's "explicitly refused, never left for a builder to discover" is satisfied by that charter,
  recorded here, not by shipping two more tools into this story.
- **No row action, no primary action, no dialog.** `EXPERIENCE.md:87`'s human gesture
  (row-overflow-menu / command-bar - dialog) is 7.10's; `epics.md:3935` forbids an inert control
  shipping ahead of its handler, and the converse - a handler with no charter for its control - is
  not a license to invent one. This story's path is the agent proposal.
- **No typed-name confirmation.** `proposal-card.ts:521-524` records it as Story 14.7's.
- **No new drill level and no new route.** The enumeration the mint reads is a port method reached
  only through the write path, never over HTTP; `Api/Router.cls:95-98`'s four routes are unchanged.
- **No second fingerprint validator.** DW-1475 and DW-1474 extend the one `Registry.DeclaredNames`
  extraction that `ConfirmChannelProblem` already uses. A second validator beside it is DW-1206's
  defect wearing a new hat, and AD-51 forbids it by name.
- **No `docker compose up`/`down`/`restart` against `ocupilot` or any `ocupilot-slot-*` container,
  and no teardown of `ocupilot-ci`**, which is up, is not pristine, and no session here brought it
  up.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Delete proposed | user drilled to `HSCUSTOM`; agent calls `logs.applicationerrors.delete` with that namespace | fresh read enumerates every `(date, errorNumber)` in the namespace; card shows the identifying fields as removals with no after-state; `destructive` true; no Reverse line; no unchanged-fields caption (bodyless) | No error expected |
| Namespace with no errors | the drilled-to namespace holds none | **refused at the mint**, naming that the namespace records no application errors; no proposal row, no card | `PROPOSAL.*` refusal; `StateDiff` answers `pProblem` |
| Namespace not in the log | a namespace `NamespaceList` does not answer | refused; the port's existing `LOG.NAMESPACE` 404 reason is reused | `LOG.NAMESPACE`, 404 |
| Two spellings of one namespace | agent sends `hscustom`, then `HSCUSTOM` | both canonicalize to one key, so the second proposal is the first's sibling: one lock, one cancel (AD-13, AD-34). **Measured 2026-09-22:** `DateList` answers 6 rows for `HSCUSTOM`, `hscustom` and `HsCustom` alike, so `application-error` needs an `IDRULES` entry exactly as `user` does | the loser is refused with the terminal state, never retried |
| Route scope present | the request carries `?ns=OTHER` while the drill is on `HSCUSTOM` | `HSCUSTOM`'s errors are enumerated, proposed and deleted; `OTHER` is untouched | none - the parameter reaches no layer; `ErrorLogWire:291` is the read precedent |
| Confirmed | user presses Confirm | the enumerated ids are removed through `SYS.ApplicationError`; one `changed` event `(application-error, instance, <NAMESPACE>)` with action **`deleted`**; marker emitted and the ledger row reads marked | a port fault passes through as its own envelope; the ledger row closes `error` and claims no marking |
| An error logged between mint and confirm | a new error lands in the namespace after the proposal | **BLOCKED - see `## Blocking Condition` item 1.** Under AD-48's "confirm deletes exactly those" the new error survives and the card says so; under the AC's literal `DeleteByNamespace` it is destroyed and there is no residue | the two readings differ observably; the amendment selects one |
| An enumerated error deleted by someone else | a listed id is gone at confirm | the fingerprint re-read differs, the confirm is refused `PROPOSAL.TARGETCHANGED`, nothing is deleted, the card offers only Re-propose | `PROPOSAL.TARGETCHANGED`, 409 |
| Least-privileged confirm | caller holds `%Admin_Operate:USE` and `%DB_IRISSYS:READ` but not `%DB_<ns>:WRITE` | 403 naming the failed pair; every error survives | `AUTH.NOPRIVILEGE` with `detail.failedPair` |
| Namespace whose globals database reports no guarding resource | `Namespaces.GlobalDatabase` answers `""` | refused naming no pair - "no resource" is never "no privilege required" | `AUTH.NOPRIVILEGE`, empty pair |
| Namespace whose globals database is mounted read-only | the resource resolves and the caller holds WRITE on it, but the mount refuses | the vendor `%Status` is normalized at the port boundary into OcuPilot's envelope; the proposal row closes `error` | one envelope, no partial delete claimed |
| A field on a bodyless write | the proposal carries any changed field | refused by name - `PermittedChangeFields("application-error")` is empty | `PROHIBITED.UNCOVEREDFIELD` |
| The id set moves under `Prohibited.Changed` | a new error lands between the stored fresh read and the prohibited set's live re-read | **not** a `PROHIBITED.UNCOVEREDFIELD` 403 with the row left live - the declared fingerprint subject is what adjudicates a moved subject, and `Changed()` skips the members it names | this is Story 5.11's `StateField` defect generalized; see `## Design Notes` |
| The drill re-fetches | the confirm lands while the error-log screen is open on that namespace | the level re-reads in place, the removed rows leave, and the drill steps up when the level the user is on no longer exists | the read's own refusals are unchanged |
| Screen not open | the confirm lands while another screen is showing | the off-screen toast reads `<entity> was deleted` with "Open in <screen>" (`toasts.ts:85`, built and until now unreachable) | none |
| A live proposal against `application-error` | a proposal is open while the error log is showing | **no pause.** `LogErrorList` declares `refreshes: false` and is not one of AD-43's seven roster screens, so there is no timer to suspend | none |

</intent-contract>

## Blocking Condition - ALL THREE RESOLVED 2026-09-22

Three gaps. All three are `Ask first` under Rule 5 - they change what the product does or what it
says - and all three want one sitting.

### 1. Two of this story's own acceptance criteria contradict each other (the load-bearing one)

`epics.md:3791` says the delete **"goes through `SYS.ApplicationError`'s `DeleteByNamespace`"**.
`epics.md:3785-3787`, and AD-48 in the same words, say the fingerprint is the enumerated id set,
that **"confirm deletes exactly those"**, and that **"residue from errors logged between proposal
and confirm is correct, and the card says so"**.

`DeleteByNamespace(ns)` deletes every application error in the namespace for every date
(`SYS.ApplicationError` doc comment, read on the instance 2026-09-22). So:

- If confirm calls `DeleteByNamespace`, it destroys more than the enumerated ids, there is **no**
  residue, and errors the user never saw are deleted - the exact outcome AD-48's fingerprint rule
  exists to prevent ("re-running the selection at confirm time would delete rows the user never
  saw").
- If confirm calls `DeleteByError(ns, date, <the ids enumerated for that date>)` once per date, it
  deletes exactly those, residue is real, and every safety clause holds - but the AC's named method
  is wrong.

Nothing in the intent selects between them, and the two differ observably in one sentence: *does an
error logged thirty seconds after the proposal survive the confirm?* This is also the epic's
signature defect at planning altitude - an asserted path whose executed behavior is not the
behavior the neighbouring assertion names.

**Recommended amendment (the second reading).** Amend `epics.md:3791` to read "goes through
`SYS.ApplicationError`'s deletes, removing exactly the enumerated ids", and leave AD-48 untouched -
it already says the right thing twice and names no single method for the confirm. `DeleteByError` is
one of the three methods AD-48 sanctions, so the amendment neither widens the API surface nor
touches the "no `^ERRORS` traversal" rule. The cost is N calls for N dates (6 for `HSCUSTOM` on the
live instance, 211 errors) instead of one; the benefit is that "confirm deletes exactly those" and
"residue is correct" both become true statements rather than one of them being dead text.

If the owner prefers the first reading instead, then AD-48's enumerated-id-set fingerprint and its
residue clause must be amended at their origin in the spine for the by-namespace scope, and this
spec's fingerprint subject, card rows, matrix and tests all change with it - which is why this
cannot be planned around.

### 2. AD-48's "the card says so" has no published copy, and the suite refuses an unpublished string

AD-48: *"Residue left by errors logged between proposal and confirm is correct, **and the card says
so**."* No string in `EXPERIENCE.md`'s Fixed strings table says it, and the card's only
published warning slot is `proposalAuditWarning` ("Agent writes will no longer be marked in the
audit database.", `EXPERIENCE.md:387`, `strings.ts:1269`).

This is not a style preference. `ui/tools/strings.test.mjs:497` - *"the string source holds nothing
the documents do not authorize - the table, the literals extracted from prose, and exactly three
named extras"* - reddens on any user-facing string `EXPERIENCE.md` does not publish, and
`ui/tools/citations.test.mjs` holds `strings.ts`'s gated `/** EXPERIENCE.md:<n> */` anchors to
phrases that exist there exactly once. So the sentence cannot be authored by a builder.

Two defensible readings, observably different: the card carries a published sentence saying residue
survives, or the card's enumerated removal rows are held to satisfy "says so" by showing the scope
and nothing is added. Authoring published copy is a UX call
(`EXPERIENCE.md`'s Fixed strings row), so this spec does not choose the wording.

**Recommended amendment.** Add one Fixed-strings row for a card warning on this write, in the same
slot and shape as the auditing warning, saying that errors logged after the proposal are not
removed. Recommended wording, for the owner to accept or replace: **"Errors logged after this
proposal will not be removed."** Gap 1's answer decides whether the sentence is needed at all - under
the first reading there is no residue to describe.

### 3. DW-1423's announcement copy, and the premise that routed it here

`STRINGS.tableChangeAnnouncement` is `'Updated: <entity> <action>'` (`strings.ts:1286`), published at
`EXPERIENCE.md:391` and again in the WCAG 4.1.3 status-messages paragraph at `EXPERIENCE.md:674`.
Its fixed `Updated:` prefix contradicts two of AD-14's three actions, and 5.13 deletes. The ledger
records the human half explicitly: `note=human=published copy; amending EXPERIENCE.md's
Fixed-strings row is a UX call`. This spec therefore raises it rather than rewording it.

**A second half of the entry needs the same answer, and it is not in the ledger.** The entry was
routed here because "5.13's own demo path executes the `deleted` branch". Measured: the branch's one
shipped call site is `ui/src/app/shell/data-table.ts:996`, and **the error-log drill-down is not a
`DataTable`** - `error-log.page.ts:50` renders its own grid, carries no `role="status"` region, and
`ui/src/app/core/screen-store.ts`'s `changedAction` never reaches it. So unless the error-log page is
given an announcement that reuses this string, the `deleted` branch stays as unexecutable on 5.13 as
it was on 5.11 and 5.12, and the fix banks a pass no test on this story can redden - the anti-pattern
the re-routing was meant to avoid.

**Recommended amendment, two lines.** (a) Amend the Fixed-strings row at `EXPERIENCE.md:391` and the
status-messages sentence at `EXPERIENCE.md:674` to drop the fixed prefix - recommended wording, for
the owner to accept or replace: **"<entity> <action>"**, which reads "HSCUSTOM deleted" and
"/csp/app01 updated" and keeps `<action>` as the machine vocabulary the row already says it is.
(b) Widen that row's scope from "a data table" to "a table or drill-down level", so the error-log
drill-down announces through the same string and this story can falsify the change by mutation. If
(b) is refused, DW-1423 should be re-owned to a story whose screen is a `DataTable` and that can
redden it, rather than closed here.

## Code Map

Line anchors read in this checkout on 2026-09-22. Instance facts carry the probe that produced
them; every probe below was read-only and ran with `server: "ocupilot-slot-a"`.

### Measured on the live instance, 2026-09-22

- **`SYS.ApplicationError` is `[ Abstract ]` with `Deployed=1`**, so every body is empty in the
  retrieved source and no internal privilege check is readable; `Requires` is `""` on every method
  (`%Dictionary.CompiledMethod`). Declarations: `NamespaceList(ListType)` ROWSPEC `Namespace`;
  `DateList(Namespace)` ROWSPEC `Date:%Date,Qty:%Integer`; `ErrorList(Namespace, Date)` ROWSPEC
  `Error #,Error message,Time,Process,DisplayPID,Username,Code line`;
  `ErrorDetail(Namespace, Date, Error, Type = 0)`; `DeleteByNamespace(NspList) As %Status`;
  `DeleteByDate(Namespace, DateList) As %Status`; `DeleteByError(Nsp, Date, ErrorList) As %Status`.
- **The per-error key is the triple `(Namespace, display date, Error #)`** - `Error #` is unique only
  within one `(Namespace, Date)`, and the date is `MM/DD/YYYY` as `DateList` emits it.
- **The namespace parameter is case-insensitive.** `DateList` answered 6 rows for `HSCUSTOM`,
  `hscustom` and `HsCustom` alike. That is AD-13's two-spellings rule, and DW-1359's shape - the HIGH
  defect this epic already paid for once.
- **The class is absent from `HSCUSTOM`** - `%Dictionary.ClassDefinition.%ExistsId` and
  `%Dictionary.CompiledClass.%ExistsId` both 0 there, 1 in `%SYS`.
- **The vendor's own UI calls each delete once per selected item**, one value in the "List"-named
  parameter, testing success as `tSC = 1` (`%CSP.UI.System.ExpResultPage.DeleteError`); its page gate
  is `%Admin_Manage:USE` **or** `%Admin_Operate:USE` (`.OnPreHTTP`).
- **Live shape:** `NamespaceList(0)` answers `%SYS`, `HSCUSTOM`; `DateList("HSCUSTOM")` answers six
  dates totalling 211 errors (123 on 09/11 alone).

### The read half, as Story 2.12 left it

- `src/OcuPilot/Port/LogSourcePort.cls` (1385 lines). `Errors()` `:687`, `ERRORLEVELS` `:186`; the one
  `%SYS` window is `ErrorsRead` `:800`/`:802`, restore first in the `Catch` `:867` and on the normal
  path `:872`, `ERRORSNAMESPACE` `:127`. Gate order inside `Errors`: source `:694`, level `:698`,
  `maxRows` `:705`, instance gate `:713`, per-namespace `PairsFor` + `Gate` **outside** the `%SYS`
  window `:720-731`, read `:733`, named outcomes to refusals `:738-760`.
- **The gate.** `PairsFor(pSource, pNamespace)` `:258` delegates to `ErrorPairSpec` `:274`, which
  answers `""` when the namespace is empty or `NamespaceResolver().GlobalDatabase` yields no
  resource, and otherwise `ERRORSINSTANCEPAIRS` (`:108`, `%Admin_Operate:USE,%DB_IRISSYS:READ`)
  appended with one pair per permission in `ERRORSDATABASEPERMISSIONS` (`:122`, `READ,WRITE`) -
  append, never prepend (`:110-113`). An empty answer is refused, never gated (`:249-253`); `Gate`
  fails closed `:1172-1175`. `InstancePairs()` `:292`. **`:114-121` names this story: "Revisit when
  Epic 5 adds the delete the WRITE half belongs to."**
- **The seams**, each documented "overridable for a fixture; production never overrides":
  `QueryClass()` `:321` (**overridden by nothing in the tree**), `DetailQuery()` `:329`,
  `NamespaceResolver()` `:337`, `OpenQuery(pQueryName, Output pResultSet)` `:348` - builds
  `%ResultSet.%New(..QueryClass()_":"_pQueryName)` `:353`, caller contract `$NAMESPACE` already
  `%SYS` `:345-347`. Also `Sources()` `:232`, `ErrorLevels()` `:313`, `GateClass()` `:398`.
- **Row projections.** Port level, seven fields: `ErrorRows` `:1021-1029` (`routine` derived by
  `RoutineOf` `:1055`; `line` is the offending line's *source text*, `:1050-1052`). Tool level, five:
  `Screen/Tool/ErrorRead.cls` `SUMMARYFIELDS` `:53`, `View` `:138`, `TOOLNAME` `:32`,
  `DESCRIPTORCLASS` `:41`, **`PrivilegePairs` `:95` calling
  `PairsFor(#ERRORSKEY, pArgs.%Get("namespace"))` - the precedent this story's write tool copies.**
- **Cap and truncation.** `DEFAULTMAXROWS` `:191` is 1000 with no ceiling (`:188-190`); every row
  loop caps and sets `pTruncated` `:891`, `:948`, `:1015`, `:1141`.
- `src/OcuPilot/Screen/Descriptor/LogErrorList.cls` - `XData Declaration` `:65-91`: route
  `logs/errors` `:68`, archetype `drill-down` `:72`, `built: true` `:73`, **`refreshes: false`**
  `:74`, privileges `%Admin_Operate:USE` + `%DB_IRISSYS:READ` `:76` (the per-namespace half
  deliberately not declarable, `:29-34`), `entityType: "application-error"` `:77`, `scope:
  "instance"` `:79`, `id: {"kind":"composite","parts":["namespace","date","errorNumber"]}` `:81`,
  `primaryAction` empty `:82`, `rowActions: []` `:83`, `context.fields` the five summary fields
  `:84`, `toolIdentifier: "logs.applicationerrors"` `:89`. **No `read` key at all** - deliberate,
  `:5-20`: three drill levels are three column sets and `read` is singular. **No `rowGet`, no
  `fingerprintExcludes`.** `:52-53` records AD-48's three delete scopes as Epic 5's.
- `src/OcuPilot/Api/ErrorLog.cls` - `Handle(pLevel)` `:48`, params `:22`/`:26`/`:29`/`:32`
  (`NAMESPACEPARAM = "namespace"`, "Never `ns`"), `:10-14` "It never reads `ns`".
  `src/OcuPilot/Api/Router.cls:95-98` binds the four levels to four routes `:258-286`.
- **Tests.** `Test/ErrorLogFixture.cls:19` (extends the port; arms `SetSources` `:25`, `SetLevels`
  `:31`, `SetErrorPairs` `:41`, `SetNamespaceResolver` `:49`, `SetGateClass` `:60`, `SetDetailQuery`
  `:66`; counters in the `OpenQuery` override `:152-156`; writes and deletes nothing).
  `Test/ErrorLog.cls:13` (610 lines, 15 tests; `TestNoQueryRunsBeforeTheGate` `:310`).
  **`Test/ErrorLogSeed.cls:23` is the only class in the tree that writes an application error** -
  `ARMINGVARIABLE = "OCUPILOT_ALLOW_ERROR_SEED"` `:30`, guarded in `OnBeforeAllTests` `:41-46`
  **and** inside `SeedInto` `:65-67`, `TARGETNAMESPACE = "USER"` `:35`, raises a real `<DIVIDE>`
  `:74-75` and calls `$$LOG^%ETN()` `:80`, returning `$LB($H day, errorNumber)` read at `:91-92` and
  converted with `$ZDate(tDay,1)` at `:145`; `:11-14` says "the delete is Epic 5's, and there is
  nothing here to undo it with." `Test/ErrorLogWire.cls:13`
  (`TestARouteScopeParameterChangesNothing` `:291`). `Test/ErrorLogDenial.cls:40`
  (`OCUPILOT_ALLOW_PRINCIPALS` `:48`, real least-privileged principals `:52-79`).
  `Test/ErrorNamespaceResolver.cls:12`.

### The write seam, as Story 5.12 left it - and the one thing it does not have

- `src/OcuPilot/Screen/Tool/Write.cls` (429 lines): `DESTRUCTIVE` `:51`, `READTYPE` `:56`,
  `WRITETYPE` `:61`, `SENDSBODY` `:66`, `STATEFIELD` `:74`, `FINGERPRINTSUBJECT` `:93`,
  `PRECONDITIONFIELD` `:101`; `ToolClass()` `:111`, `ReadType()` `:118`, `WriteType()` `:124`,
  `SendsBody()` `:130`, `StateField()` `:137`, `FingerprintSubject()` `:144` (CSV to `%List`,
  deduped), `PreconditionField()` `:156`, `StateDiff()` `:171`
  (`(pFresh, Output pRows, Output pProblem) As %Status`; contract `:161-170` - Mint calls it once
  after the fresh read and refuses the mint when `pProblem` is non-empty), `MintClass()` `:180`,
  `Destructive()` `:188`, `Endpoint()` `:194` `[Abstract]`, `SettableFields()` `:201` `[Abstract]`,
  `IdArgument()` `:208`, `IdParam()` `:215`, `PermittedFields()` `:235`, `FieldRows()` `:261` with
  the bodyless short-circuit `:271`, `View()` `:385` `[Final]`. `PrivilegePairs()` is
  `Screen/Tool/Base.cls:71`; `WRITERESOURCE`/`WRITEPERMISSION` are per-tool, not on the base.
- **The gap this story must close: every write reaches its target through `AdminPort`, and the port
  is a constant on the kernel class, not a declaration on the tool.** Four sites:
  `Mint.cls:43-46` `PortClass()`; `Confirm.cls:55-58` `PortClass()`;
  `Kernel/Proposal/Prohibited.cls:250` (its live target read); and each is documented "production
  never overrides it". The tool contributes only `Endpoint()`, `IdParam()`, `ReadType()`,
  `WriteType()`, `SendsBody()`. The one per-tool lever today is `Write.MintClass()` `:180`, which
  covers the mint half alone.
- `Mint.cls`: `Mint()` `:87`; secret-argument refusal before the port is touched `:101-108`;
  `EntityRef.Key` `:110`; **fresh read `:116-118`** via `..PortClass()` `Invoke` with
  `tQuery(pIdParam) = pIdValue` and `ReadTypeOf(pToolClass)` `:408-418`; `StateDiff` `:149` with the
  refusal `:154-157`; `If '$ClassMethod(pToolClass,"SendsBody") Set tUnchanged = 0` `:166`;
  `FingerprintSubjectOf` `:173` (method `:423-432`, **the blanket `Catch` that answers `""`** -
  DW-1476); `Projection` `:174-180`; `Fingerprint.Of(...)` `:181`; stored values `:187-216`;
  `GuardedMint` `:217`.
- `Confirm.cls`: `Transition()` `:216` with gates in order - pairs `:253-264`, prohibited `:268-283`,
  restraint `:287-300`, **fingerprint re-read `:331-345`** (`FingerprintMatches` `:563`, port read
  `:586`, subject `:601`, digests `:602`/`:605`), row version `:349-353`, `GuardedClaimAndClose`
  `:354`, body `:373-375` (`ToolSendsBody` `:677-686`, **fails open**), **write `:391`**, marker
  `:417` (`Audit/Event.cls:248`; `:412-416` "the one place a marker is emitted").
  `Kernel/State/Propose.cls:329`, per-target lock `:346-355`.
- `Kernel/Proposal/Fingerprint.cls`: `Of(pPayload, pExcludes, Output pDigest, pSubject)` `:39` -
  **`Projection(pSubject)` at `:49-52` runs before `Canonical(.., pExcludes)` at `:53`**, which is
  DW-1474 at its origin. `Projection()` `:65` errors "the fingerprint subject names '<name>', which
  this read does not answer" `:75`. `Canonical()` `:98` - array `[]`-path exclusion `:102`, `$Order`
  key collation `:123-130`.
- `src/OcuPilot/Screen/Registry.cls`: `FingerprintSubjectProblem` `:2054`, `WRITETOOLBASE` `:2033`;
  conditions - not a `Write` descendant `:2062`; subject on a body-sending write `:2064-2067`;
  parses empty `:2068-2073`; omits `IdArgument()` `:2074-2078`; `PRECONDITIONFIELD` empty
  `:2079-2083`; omits the precondition field `:2084-2087`; no `DESCRIPTORCLASS` `:2088-2092`;
  **unknown name `:2103-2109`, matched against `tNames("path")` union `tNames("read")` built at
  `:2093-2102` from the *screen's declaration*** - DW-1475. `DeclaredNames` `:2152`,
  `DECLAREDNAMEKINDS` `:2122` (`settable,path,criteria,read,credential`), `DeclaredReadFields`
  `:2193`; `ConfirmChannelProblem` `:1985` uses the same extraction `:2002`.
  `Screen/Tool/Registry.cls`: `ListTools` `:104-185`, the write branch's guard call `:135-141`,
  `EXCLUDEDPACKAGE` `:27`.
- `Kernel/Proposal/Prohibited.cls`: `COVEREDTYPES` `:99`, type constants `:102`-`:110`,
  `CoveredTypes()` `:183-191`, `PermittedChangeFields()` `:225-231`, `Prohibits()` `:275` with the
  uncovered arm `:281-285` and the **fail-closed arm for a listed type with no branch `:286-290`**,
  `Target` `:300` (port read `:1035`), `Changed` `:307` (method `:978-1002`, **`pStateField` skip
  `:990`**, `StateFieldOf` `:1074-1083`), branches `:310-326`, `ReviewedFewOnly()` `:623-645`,
  `UncoveredWriteTools()` `:344`. `Test/Prohibited.cls` - the three sites that move together:
  uncovered-example list `:168`, `CoveredTypes()` literal `:180`, seeded 403 row `:183`, all inside
  `TestAnUncoveredEntityTypeIsRefusedWholesale()` `:166` (`:158-163` names the `user`/`task`/`process`
  precedents).
- `Kernel/EntityType.cls:34` - `TYPES`, 29 members, **`application-error` already present**;
  `Count()` `:60-63`, asserted 29 at `Test/Descriptor.cls:1287`. **No enum change.**
  `Kernel/EntityRef.cls:59` `IDRULES`, `IDRULENAMES` `:64`, `NormalizedId()` `:233`, foldcase body
  `:240-245` with its verbatim fallback `:240`, `Canonical()` `:294`. Client twins
  `ui/src/app/core/entity-ref.ts:65-89` (foldcase `:71`), `IMPLEMENTED_ID_RULE_NAMES` `:95`;
  `ui/tools/screen-mirror.mjs:161`, `checkedIdRules()` `:2104-2141`.
- `Test/ProhibitedFixture.cls:164-182` - **`Digest` still calls the three-argument `Fingerprint.Of`
  at `:176`** (DW-1470); its sibling `Test/ProhibitedRoute.cls:276` `Minted` was updated (subject
  `:296`, `Projection` `:298`, four-argument `Of` `:302`) and `ProhibitedRoute.Digest` `:318-323`
  delegates to it. Callers: `ProhibitedByEffect.cls:487`; `ProhibitedRoute.cls:238`, `:248`, `:320`,
  `:439`. Other three-argument callers: `Test/ProposalSpelling.cls:264`, `Test/AuditMarker.cls:173`,
  `Test/Proposal.cls` (twelve).
- **The worked example.** `Screen/Tool/ProcessSuspend.cls`: `READTYPE` `:31`, `WRITETYPE` `:37`,
  `SENDSBODY` `:42`, `DESTRUCTIVE` `:47`, `WRITERESOURCE`/`WRITEPERMISSION` `:53`/`:55`,
  `PRECONDITIONFIELD` `:62`, `FINGERPRINTSUBJECT` `:66`, `STATEFIELD` `:76`, `Endpoint()` `:82`,
  `IdArgument()` `:89`, `PrivilegePairs()` `:126`, `StateDiff()` `:143`; `ProcessResume.cls` mirrors
  it. **`Screen/Tool/TaskResume.cls` now declares both as `Suspended`** - DW-1476, closed by this
  story.
- `Test/ToolWrite.cls`: `AssertActionWrite` `:562-613` (subject `:580`, precondition `:581`, guard
  answers `""` `:582`), the roster-equality test `:685-740`, the guard tests `:624-649` and
  `:658-666`. `Test/SubjectProbe/` - six probes (`BodyTaking`, `EmptySubject`, `ExcludedName`, `NoSubject`,
  `MissingPrecondition`, `UnknownName`) over `ProcessList`, admitted by a probe registry overriding
  `ToolPackage()` `:11-14` and `ExcludedPackage()` `:16-19`.
- `Test/SurfaceCoverage.cls`: `XData Coverage` `:56`, `<tool>` rows `:100-105`;
  `TestEveryWriteToolHasACoverageRowAndBack()` `:280` derives from `ListTools` and compares both
  directions `:289` with non-zero floors `:287`, `:292`. Row order is convention, not asserted.
- **A bodyless tool needs no `Classification.cls` entry and no `ToolFields` row** - `TaskResume`,
  `ProcessSuspend` and `ProcessResume` have none and the tree is green; `Classification.cls` holds
  exactly three entries (`:49`, `:70`, `:76`) and refusals are only for entries that exist.

### The client

- `ui/src/app/core/proposal-view.ts`: `ProposalDiffRow` `:29-33` - `{field, before, after}`, all
  three **required**, no removal variant; `ProposalUnchangedRow` `:39-42`; `reverse` `:62-63`
  ("`''` where no reversal exists (a delete has none)"); `toCardView` `:281-304` maps
  `proposal.changed` 1:1 through `secrets.has(row.field) ? maskedRow(row) : row` `:292`;
  `maskedRow` `:259-261`. **Header `:13-16`: `toCardView` writes no value of its own, and
  `ui/tools/proposal.test.mjs`'s literal scan fails the gate on any proposal field assigned a
  literal in a shipped module (AD-6).** Wire twin `core/turn.ts:171`, parsed `:415-425`. Tests are
  `ui/tools/proposal-view.test.mjs` (403 lines) - `core/` holds no `.spec.ts`.
- `ui/src/app/shell/proposal-card.ts` (717 lines): title `:91`/`:406-409`; diff rows `:108-122`
  (`.ocu-diff-before` `:112-115` `proposalDiffWas`, `.ocu-diff-after` `:117-120` `proposalDiffNow`,
  arrow `aria-hidden` `:116`/`:319`); `shown(value)` `:427-429` - the **only** value-substituting
  branch, `'' -> '(none)'`; unchanged caption `:123-151`, `discloses` `:440-442`; agent-tinted
  `rationale`/`expectedImpact` `:154-161`; **Reverse `:163-168`, `hasReverse` `:481-483`, rendered by
  interpolation - no `innerHTML` anywhere in the component**; audit warning `:192-195`/`:513-514`;
  destructive `:87`, `:242-243`, `:526-528`. Spec: AD-11 markup pin `:242-260` querying
  `.ocu-proposal-card-agent-text` `:251` with `children.length === 0` `:256` - **covers `rationale`
  and `expectedImpact` only** (DW-1242); Reverse absence `:262-268`; destructive `:565-575`.
  `DELETE_PROPOSAL` fixture `:38` is the only `(removed)` in the client, and is a fixture.
- **The announcement.** `STRINGS.tableChangeAnnouncement` `strings.ts:1286`, gated anchor `:1285`;
  sole shipped call site `shell/data-table.ts:996` inside `announceChanged()` `:984-997`, rendered
  `:147-148`; formatter `core/toasts.ts:109-110`. Chain: `core/change-bus.ts:40`/`:43` vocabulary,
  refused-rather-than-defaulted `:138-142`; `core/refresh.ts:613`; `core/screen-store.ts:315-326`.
  Verbatim assertions: `data-table.spec.ts:546`, `:552`, `:556`, `:584`, `:613`;
  `list-page.spec.ts:248`; `ui/tools/toasts.test.mjs:295-296`, `:304`.
- **No shipped path produces `deleted`.** Producers today: `core/turn.ts:1052` (hard-coded
  `'updated'`, with `:1042-1046` saying "a later story is their first producer"),
  `areas/agent/switches.store.ts:405`, `definition-actions.ts:160`, `definition-form.store.ts:589`
  and `:637`. Consumers waiting: `core/toasts.ts:85` -> `tableChangeDeleted` (`strings.ts:1280`);
  `core/refresh.ts:612-618`, whose `:614-616` names the delete case ("a delete is `reconcile`'s,
  which clears a selection whose key has left the view").
- `ui/src/app/areas/logs/error-log.page.ts` (480 lines), `.store.ts` (431 lines),
  `error-log.page.spec.ts` (608 lines). Registered `shell/screen-outlet.ts:25`/`:63` - the only
  `drill-down`. Store `ErrorLogDrill` `@Injectable({providedIn:'root'})` `:120-121` - `levelValue`
  `:124`, `namespaceValue` `:126`, `dateValue` `:128`, `errorNumberValue` `:130`, accessors
  `:200`-`:212`; `open*` `:256-313` each clearing the levels below, `back()` `:345-350`, `reopen()`
  `:329-343` (silent Refresh, DW-260), `reset()` `:182-198`. **Every call sends `scope: null`**
  `:365`; header `:105-110` already anticipates this story ("Two sources would let a later delete
  purge a namespace other than the one on screen"). **No `ScreenStore`, no `RefreshService`, no
  `ChangeBus`, no selection, no highlight, no announcement region** - `:111-115`, confirmed by grep.
  Page header `:43-45`: "Nothing here reads `?ns=`."
- `ui/browser/error-log.browser-spec.mjs` (646 lines, five tests `:348`, `:412`, `:465`, `:531`,
  `:593`); its only write leg uses `ErrorLogSeed` and carries a `LIVE_CONTAINER` refusal `:107` but
  **no `/-ci$/` guard**. The guard idiom to copy is `ui/browser/task-resume.browser-spec.mjs:74-78`
  and `:82-86`, with the `after`-hook repeat `:107`.
- `ui/tools/screen-mirror.mjs`: `checkedIdRules()` `:2104`, `checkedDeclaredNameKinds()` `:2174`
  (throws naming the source class on either difference), `refreshProblem()` `:696-710`,
  `declaredNames` `:485` / `confirmChannelProblem` `:444`.
- **The published copy that governs this story's card.** `EXPERIENCE.md:422` (`diff-row`): *"A delete
  proposal has no after-state: it shows the target's identifying fields as `field · value →
  (removed)`, reads `"<field>: <value>, removed"`, and carries no `"Reverse:"` line, since a delete
  has no reversal."* `EXPERIENCE.md:607` (drill-down state row): *"row removed after delete"*.
  `EXPERIENCE.md:87` assigns the human gesture (row-overflow-menu / command-bar, dialog) to build
  step 4. The gates over strings: `ui/tools/strings.test.mjs:497` and `:473`,
  `ui/tools/citations.test.mjs:136` and `:162`.

## Tasks & Acceptance

- [x] [Review] Narrow the ownership prohibition to **one predicate**: refuse the confirm's own
  `$JOB` and any OcuPilot turn job (AD-7), whoever owns it. Remove the broad owned-by-caller
  refusal from Story 5.12's `Prohibited` branch. Pin both arms, and pin that a process the
  confirming user owns which is neither is **permitted**. Closes DW-1472 and DW-1477 together.
- [x] [Review] `TaskResume` declares `FINGERPRINTSUBJECT = "Suspended"` and DW-1476's refusal is
  enforced: an action-style write that declares no subject fails registration. AD-51's corrected
  clause requires precondition fields the tool's own read answers - **not** identity.
- [x] [Review] Record the demo script's target in `## Design Notes`: a second portal session's
  process, permitted by the narrow reading.

- [x] [Review] Execute the delete as `DeleteByError(ns, date, <ids>)` once per enumerated date,
  removing exactly the enumerated ids (amended `epics.md:3791`). Scope stays by-namespace.
- [x] [Review] Render the authorised residue string on the card:
  `"Removes exactly the <n> errors listed here. Any logged since the proposal will remain."`
  Both facts must survive any tightening for width.
- [x] [Review] DW-1423: measure whether any reachable path emits the change announcement with
  action `deleted`. Fix and pin it if one does; record the finding and route the entry out if none
  does. Do not choose new copy - that half is a UX call.
- [x] [Review] DW-1472: the demo fixture creates its target process under an account other than the
  confirming user. If that cannot be done on the demo instance, HALT with an `intent gap`.
  **Superseded by the first item**: the narrow reading needs no fixture change (Spec Change Log,
  2026-09-22).
- [x] [Review] Declare the port per write tool, defaulting to `AdminPort` (AD-52), and resolve the
  mint's fresh read, the confirm's re-read, the prohibited-set evaluation and the write through it.

**Execution:**

- `src/OcuPilot/Port/LogSourcePort.cls` -- add the enumeration and the delete, plus a port-uniform
  `Invoke(pEndpoint, pType, ByRef pQuery, pBody, Output pResult, Output pHttpStatus, Output pFault)`
  façade whose signature matches `AdminPort.Invoke` -- so the kernel write path can call this port
  exactly as it calls that one. `ENUMERATE` answers
  `{namespace, entries:[{date, errorNumber}], count, truncated}` by walking `DateList` then
  `ErrorList` per date inside **one** `%SYS` window, gated by `PairsFor` resolved outside it exactly
  as `Errors` does; `DELETE` removes the ids named in `pQuery` through `SYS.ApplicationError`'s
  sanctioned methods (which method: `## Blocking Condition` item 1). Refuse a truncated enumeration
  at the mint rather than promising "exactly those" from a cut set. `ERRORSDATABASEPERMISSIONS`'
  doc comment `:114-121` loses its "Revisit when Epic 5 adds the delete" sentence and states the
  settled position.
- `src/OcuPilot/Screen/Tool/Write.cls` -- declare the write's **port** (`PORTCLASS`, defaulting to
  `OcuPilot.Port.AdminPort`) with a `PortClass()` accessor beside `ReadType()`/`WriteType()`, and
  declare the names the tool's own `READTYPE` read answers so DW-1475's guard has something real to
  validate against on a descriptor with no declared `read`.
- `src/OcuPilot/Kernel/Proposal/Mint.cls`, `Confirm.cls`, `Prohibited.cls` -- resolve the port
  **per tool** at the four sites that hard-wire it (`Mint.cls:43-46`, `Confirm.cls:55-58` used at
  `:391` and `:586`, `Prohibited.cls:250` used at `:1035`), defaulting to today's constant so every
  shipped tool is unchanged. Correct each "production never overrides it" doc comment at its origin.
- `src/OcuPilot/Kernel/Proposal/Mint.cls` -- narrow `FingerprintSubjectOf`'s blanket `Catch`
  (`:423-432`) so an unaskable tool class is a refusal rather than a silent empty subject (DW-1476).
- `src/OcuPilot/Kernel/Proposal/Prohibited.cls` -- `Changed()` skips every member the tool's declared
  `FingerprintSubject()` names, superseding the `pStateField` skip `:990` it already carries: the
  declared subject is precisely the set whose movement the fingerprint adjudicates, so `Changed()`
  re-adjudicating it is Story 5.11's defect with a wider blast radius (a 403 `UNCOVEREDFIELD` with
  the row left live where a 409 `TARGETCHANGED` with it closed is required). `StateField()` stays and
  is a subset.
- `src/OcuPilot/Screen/Registry.cls` -- `FingerprintSubjectProblem` gains two conditions:
  **DW-1474**, refusing a subject name the descriptor's `fingerprintExcludes` also names (the two
  relate in none of today's conditions, and `Fingerprint.Of` projects before excluding, collapsing
  the digest to the empty object); and **DW-1476**, refusing an action-style write that declares no
  subject at all. **DW-1475**: the name check consults `DeclaredNames` extended with the tool's own
  declared read-answer names -- one extraction, never a second validator (AD-51 forbids it by name).
  `DECLAREDNAMEKINDS` `:2122` grows by one member.
- `ui/tools/screen-mirror.mjs` -- mirror the new declared-name kind (`checkedDeclaredNameKinds()`
  `:2174` throws on either difference) and the new `IDRULES` pair; regenerate
  `ui/src/app/core/screens.generated.ts`.
- `src/OcuPilot/Kernel/EntityRef.cls` -- add `application-error:foldcase` to `IDRULES` `:59`.
  **Measured**: `DateList` answers identically for `HSCUSTOM`, `hscustom` and `HsCustom`, so two
  spellings are one entity and AD-34's per-target lock must cover both. No new rule name; the client
  twin already implements `foldcase`.
- `src/OcuPilot/Screen/Tool/ErrorDelete.cls` (new) -- the action-style write.
  `TOOLNAME = "logs.applicationerrors.delete"`, `DESCRIPTORCLASS` `LogErrorList`,
  `PORTCLASS` `LogSourcePort`, `READTYPE = "ENUMERATE"`, `WRITETYPE = "DELETE"`, `SENDSBODY = 0`,
  `DESTRUCTIVE = 1`, `IdArgument()`/`IdParam()` `namespace`, `PRECONDITIONFIELD = "entries"`,
  `FINGERPRINTSUBJECT = "namespace,entries"`, `SettableFields()` empty, `PrivilegePairs()`
  delegating to `LogSourcePort.PairsFor` on the tool's own `namespace` argument exactly as
  `ErrorRead.cls:95` does, and `StateDiff()` emitting the removal rows and refusing the mint on an
  empty or truncated enumeration.
- `src/OcuPilot/Kernel/Proposal/Prohibited.cls` + `src/OcuPilot/Test/Prohibited.cls` -- add
  `application-error` to `COVEREDTYPES` `:99` with its type constant, its dispatch branch and its
  empty `PermittedChangeFields`, and move the three test sites together (`:168`, `:180`, `:183`). A
  listed type with no branch is refused `PROHIBITED.UNCOVERED` by `:286-290`; a registered write tool
  over an unlisted type reddens `UncoveredWriteTools` `:344`.
- `ui/src/app/core/proposal-view.ts` + `ui/src/app/shell/proposal-card.ts` -- **DW-1228**: the
  removal row's drawn and spoken forms, per `EXPERIENCE.md:422`. The value comes from the instance;
  `toCardView` still writes no literal of its own (`proposal-view.ts:13-16`,
  `ui/tools/proposal.test.mjs`'s literal scan). The row renders `field · value → (removed)` and reads
  `<field>: <value>, removed`; the Reverse line stays absent (`hasReverse` `:481-483` already
  suppresses it).
- `ui/src/app/shell/proposal-card.spec.ts` -- **DW-1242**: extend the AD-11 markup pin `:242-260` to
  `.ocu-proposal-card-reverse` on a proposal that carries one, and keep the absence assertion
  `:262-268` for this delete card. The Reverse line is model-authored text on the same card and the
  pin covered only the two agent-tinted fields.
- `ui/src/app/areas/logs/error-log.store.ts` + `.page.ts` -- subscribe to the change bus for
  `application-error`, re-read the current level in place on a `deleted` event whose namespace
  matches the drilled-to one, step the drill up when the level the user is on has gone, and announce
  (announcement string: `## Blocking Condition` item 3). The store keeps its deliberate absence of a
  `ScreenStore` (`:111-115`); this is its own subscription, not a refresh binding.
- `src/OcuPilot/Test/ProhibitedFixture.cls` -- **DW-1470**: `Digest` `:176` projects and passes the
  declared subject, matching `ProhibitedRoute.Minted` `:296-302`. 5.13 is the first caller that would
  seed an action write through it, and two sibling declarations updated separately is DW-1206's
  shape.
- `src/OcuPilot/Test/SubjectProbe/` -- two further probes, one per new guard condition (a subject
  name the descriptor also excludes; an action write declaring no subject), each over a probe
  descriptor carrying `fingerprintExcludes` -- no shipped descriptor declares one, which is why the
  guard has never been exercised in that direction.
- `src/OcuPilot/Screen/Tool/TaskResume.cls` -- declare its `PRECONDITIONFIELD` and
  `FINGERPRINTSUBJECT` (DW-1476). Harmless today (`Task` `INFO` carries no moving counter) and
  required once the guard refuses an action write that declares none.
- `src/OcuPilot/Test/ErrorDelete.cls` (new) -- the story's ObjectScript suite, armed by
  `OCUPILOT_ALLOW_ERROR_DELETE` in the `ProhibitedRoute.cls:28`/`:111-114` shape (a real
  `GetEnviron` read and a hard `%Status` error, never a skip). It seeds its own errors through
  `ErrorLogSeed`, never deletes an ambient one, and reads back what it disturbed.
- `scripts/ci-throwaway.sh` -- one `# classes:` comment block plus one setting for the new arming
  variable (`:180-252`). Both halves of `ui/tools/ci.test.mjs:1648-1798`'s roster are derived, so
  that file needs no edit; the comment must sit immediately above its variable (`:1673`).
- `src/OcuPilot/Test/ToolWrite.cls` + `src/OcuPilot/Test/SurfaceCoverage.cls` -- the new tool's
  action-write assertions and its `<tool>` row (`:100-105`, alphabetically first).
- `ui/browser/error-log-delete.browser-spec.mjs` (new) -- the end-to-end leg, with the `/-ci$/` guard
  and `after`-hook repeat copied from `task-resume.browser-spec.mjs:74-86`, `:107`.

**Acceptance Criteria:**

- Given a user drilled to a namespace in the application error log, when the agent is asked to clear
  that namespace's errors, then the namespace the port receives is the one held in the drill state
  and the route's `?ns=` reaches no layer -- driven through the shipped path with a conflicting
  `?ns=` present, not through a fixture that replaces the resolver.
- Given the proposal is minted, when its fingerprint is computed, then it is the enumerated
  `(date, errorNumber)` set captured at proposal time -- demonstrated by a confirm that succeeds
  after an unrelated field of the read has moved, and a confirm that is refused
  `PROPOSAL.TARGETCHANGED` after one enumerated id has been removed by another party. Both
  directions, as AD-51's amendment required of 5.12.
- Given the delete executes, when it runs, then it goes through `SYS.ApplicationError` under the
  per-namespace gate resolved at call time, with the same proposal, server-computed diff, explicit
  confirmation and agent marker as any other write, and the ledger row reads marked.
- Given the caller holds `%Admin_Operate:USE` and `%DB_IRISSYS:READ` but not `%DB_<ns>:WRITE`, when
  they confirm, then they are refused 403 naming that pair and every error survives -- proved with a
  purpose-built least-privileged principal on the throwaway (AD-29's second half), never `%Operator`
  and never a fixture that replaces `Gate`.
- Given the delete is destructive, when the card renders, then it shows the identifying fields as
  removals with no after-state, carries no Reverse line, and its Confirm is `button-destructive`.
- Given the write completes, when the drill-down re-fetches, then the removed rows leave, the drill
  steps up when the level the user was on has gone, and the audit database carries the marked event.
- Given the agent reads the log at any point in this story, when it does, then the tool returns the
  five summary fields only and no expression, stack frame or variable table reaches screen context,
  a tool result, a proposal payload, a diff row or a ledger row.
- Given a registered write tool over an entity type outside `Prohibited.COVEREDTYPES`, when the
  registry builds, then `UncoveredWriteTools` reddens -- so `application-error` joining
  `COVEREDTYPES`, its branch and the three test sites are inseparable.
- Given an action-style write that declares an inadequate fingerprint subject -- empty, missing its
  identity, missing its precondition field, naming a field neither the screen nor the tool's own read
  answers, or naming one the descriptor's `fingerprintExcludes` also names -- when the tool list
  builds, then it refuses, naming the class and the problem, and the tool is neither registered nor
  mintable.

### Review Findings

Code review 2026-09-22, four layers (blind-hunter, edge-case-hunter, verification-gap,
acceptance-auditor), review tier `full-opus`, all four on the parent tier. Diff reviewed over the
story's **whole** footprint (`4500138..HEAD` plus the working tree), not `baseline_revision`
(`9f6b481`) alone: `9f6b481..HEAD` is the last pass only, and the AD-52 port declaration, the tool,
the port's deletes and the client card all landed before it with no code-review stage since.

- [x] [Review][Patch] The `application-error` prohibited branch was pinned by declaration reads, not
  by the shipped dispatch, and the doc comment named a mechanism the shipped rows do not use
  [src/OcuPilot/Test/ErrorDelete.cls:505, src/OcuPilot/Kernel/Proposal/Prohibited.cls:562] --
  `TestAChangedFieldOnAnApplicationErrorProposalIsRefused` asserted `CoveredTypes`,
  `PermittedChangeFields`, `SettableFields`, `FingerprintSubject` and `SkippedFields` and never
  called `Prohibits`, so emptying `ApplicationError` reddened nothing. Its claim that "`Changed`
  skips the names the tool's declared fingerprint subject covers" is not what protects the removal
  rows either -- they are labeled by **date**, a name neither side answers, so both render `""`.
  Patched: three armed legs through the shipped `Prohibits` (no-change, refused `count`, skipped
  `namespace`), and the claim corrected at its origin in `Prohibited.ApplicationError`.
- [x] [Review][Patch] The per-date fan-out -- the whole substance of Gap 1's amendment -- was never
  executed with more than one date [src/OcuPilot/Port/LogSourcePort.cls:1188] -- every error this
  suite seeds is stamped today, so stopping the loop after its first date passed every test.
  Patched: `TestTheDeleteReachesTheVendorOncePerEnumeratedDate`.
- [x] [Review][Patch] `ErrorDelete.StateDiff`'s truncated-enumeration refusal was executed by
  nothing [src/OcuPilot/Screen/Tool/ErrorDelete.cls:155] -- no reachable seeding passes
  `DEFAULTMAXROWS`, so deleting the branch reddened nothing while a cut set would be proposed and
  confirmed under a card promising "exactly the `<n>` listed here". Patched:
  `TestATruncatedEnumerationRefusesTheMint`, driven directly.
- [x] [Review][Patch] The `action !== 'deleted'` guard had no pinning test and its recorded mutation
  reddened nothing [ui/src/app/areas/logs/error-log.page.ts:254] -- all three published events in
  the spec carried `action: 'deleted'`. Patched: an `updated` leg, and the mutation line corrected.
- [x] [Review][Patch] `RemoveErrorIds`' `removed` is the requested count taken before any delete
  runs, and a mid-loop failure resets it to 0 while earlier dates are already gone
  [src/OcuPilot/Port/LogSourcePort.cls:1189] -- no consumer outside the tests today. Patched as a
  caller contract at the method; not measured, because `DeleteByError` answers no count.
- [x] [Review][Patch] `Test/TaskResume.cls`'s Rule 19 recipe named a mechanism that is not what
  happens [src/OcuPilot/Test/TaskResume.cls:186] -- the mutation reddens at the **mint**, through
  `TaskResume.StateDiff`'s precondition read, not at the confirm. Corrected in-pass (Rule 19 LOW).
- [x] [Review][Defer] The card's residue sentence is gated on "any removal row", not on the entity
  type [ui/src/app/shell/proposal-card.ts:517] -- deferred: `DW-1480`, routed to Story 7.1, the
  first delete of another type. Unreachable today.
- [x] [Review][Defer] `OcuPilot.Api.Error.LOGENTRY` now answers two refusals at two statuses
  [src/OcuPilot/Port/LogSourcePort.cls:893] -- deferred: `DW-1481` `wontfix-accepted`. The delete's
  400 travels the proposal envelope, never the drill's read-fault path that reads
  `VANISHED_LEVEL_CODES`; the fix adds a code to five `Api.Error` roster gates.
- [x] [Review][Defer] `ErrorDelete.ArgumentPairs` answers resolved with an empty pair set
  [src/OcuPilot/Screen/Tool/ErrorDelete.cls:120] -- deferred: `DW-1482` `wontfix-theoretical`.
  Needs a namespace `NamespaceList` answers whose globals database reports no guarding resource.
- [x] [Review][Defer] `IsOcuPilotProcess` normalizes the pid for its `$Job` arm and not for its
  turn-job arm [src/OcuPilot/Kernel/Proposal/Prohibited.cls:667] -- deferred: `DW-1483`
  `wontfix-theoretical`. Both sides are bare integers on this build, and normalizing one side alone
  can break the match.
- [x] [Review][Defer] Destructive test helpers carry no per-call arming guard, unlike
  `ErrorLogSeed.SeedInto` [src/OcuPilot/Test/ErrorDelete.cls:659] -- deferred: appended as an
  occurrence on `DW-1451`, whose root cause is the same: the destructive-test gate reads
  `OnBeforeAllTests` and cannot see a helper. The browser spec reaches `Clear()` through the shared
  `runIris`, so arming it is not a two-way door.
- [x] [Review][Defer] `Test/ErrorDelete.cls` is 702 lines against the 500-line guideline
  [src/OcuPilot/Test/ErrorDelete.cls:1] -- deferred: `DW-1484` `wontfix-accepted`.

**Rejected.** `PortClassOf` triplicated across `Confirm`, `Mint` and `Prohibited` -- `low`, and the
fix is an extraction across three kernel classes, not a direct correction. `ENDPOINTERRORS` and
`ERRORSKEY` holding one literal -- `low`, cosmetic. `applyDeleted`'s step-up loop and its
`reopen()` generation race -- would guard state nothing was shown to reach. `PreparePrincipal`'s
`'= 1` against the test's `= 0` -- `false`: `CheckUserPermission` answers 1 or 0, so the two agree.
`StateDiff`'s empty-enumeration branch being unreachable behind the port's 404 -- `low`, and the
branch is correct defensive code. The spec-hygiene findings (`## Blocking Condition` still argued in
the present tense, the superseded Gap 1 recommendation, the stale AC9 identity clause, matrix row
113, the Auto Run Result's tally against the triage log's) -- rejected under step 3's rule that a
finding whose fix is to edit the spec under review is not a code finding; they are the lead's, and
the spec is flagged `oversized`. Four coverage suggestions -- `Confirm.ToolPortQuery`'s empty
`Catch`, `OnAfterAllTests`' teardown assertion not being recorded by `%UnitTest.Manager`, no
instance-side assertion on `Write.CHANGEACTION` / the confirm answer's `action`, and
`PortClassOf`'s fallback arms -- `low` each: the AD-14 action is pinned where it is observable, by
`ui/browser/error-log-delete.browser-spec.mjs` against the real runtime (Rule 3), and the rest add
assertions rather than correct one.

## Spec Change Log

- **2026-09-22, lead, orchestrator-approved - both remaining gaps decided.**
  - **AD-51's adequacy clause is corrected in the spine.** The subject now carries **the
    precondition fields the tool's own read type answers**; **identity is NOT required**, because
    the proposal's `TargetRef` (AD-13) already answers "which object is this?" while the
    fingerprint answers "has the state I reviewed moved?". `TaskResume` therefore declares
    `Suspended` and DW-1476 becomes enforceable, which was its point. Do **not** re-add an
    identity requirement.
  - **AC2's ownership prohibition is NARROWED, reversing the 5.12 merge-gate ruling.** Refuse only
    **the process serving the confirm request (`$JOB`)** and **any OcuPilot turn job** (AD-7),
    whoever owns it. Everything else the user owns stays proposable. `$JOB` at confirm is the
    certain irrecoverable harm - suspending it kills the write inside AD-34's transition; a user's
    own portal session is recoverable by signing in again. AD-10 names accounts, the serving path
    and IRIS system processes, and **nowhere names process ownership**, so the broad reading was a
    new rule borrowing AD-10's authority. **One predicate, both harms** - the turn-job half closes
    DW-1477's cross-user vector inside the same predicate rather than as a second one to keep in
    step (DW-1206's lesson).
  - **The demo needs no fixture change.** Its target is a **second portal session's process**,
    which the narrow reading permits and the broad one refused. Recorded here so the demo script
    is known rather than rediscovered.
  - This changes Story 5.12's shipped `Prohibited.OwnedByCaller`; that edit lands here, in the
    story DW-1472 is routed to.

- **2026-09-22, lead, orchestrator-approved - all three gaps resolved plus the port seam.** The
  measurements below stand; only the decisions changed.
  - **Gap 1.** `epics.md:3791` named the right scope and the wrong method. It now reads "removes
    **exactly the enumerated ids**, executed as `DeleteByError(ns, date, <ids>)` once per enumerated
    date", carrying an `[AMENDED]` marker. AD-48 is untouched: its enumerated-id-set rule already
    stated this and gave the reason, and `DeleteByError` is one of its three sanctioned methods.
  - **Gap 2.** The residue sentence is now an authorised Fixed string in `EXPERIENCE.md`:
    `"Removes exactly the <n> errors listed here. Any logged since the proposal will remain."`
    `<n>` resolves to the enumerated count. The wording may be tightened to fit the card's width,
    but **both facts must survive** - a version saying only "removes <n> errors" fails the AC's
    second half.
  - **Gap 3 (DW-1423).** Do **not** defer it blind. This is the only story that would execute the
    `deleted` branch, so settle it here: determine whether any reachable path emits the change
    announcement with action `deleted`. If one does, fix the prefix and pin it with a test that
    reddens on the wrong branch. If nothing reaches it, say so and route the entry out with the
    finding recorded - a fix on an unexecutable branch banks an unfalsifiable pass wherever it
    lands. The copy half remains a UX call on the entry.
  - **The port seam - approved and written as AD-52.** A write tool declares the port it reaches its
    target through, defaulting to `AdminPort`. Measured: `AdminPort` is a constant at
    `Confirm.cls:57`, `Mint.cls:45` and `Prohibited.cls:252`, while AD-48 routes this log through
    `LogSourcePort`, which has no delete methods - so the write path could not express this story's
    write at all.
  - **DW-1472 routed here.** The broad ownership prohibition stands; the **demo fixture must create
    its target process under an account other than the confirming user**. If that is impossible on
    the demo instance, it is a Clarification, not something to work around.

## Review Triage Log

### 2026-09-22 - Review pass

- verdicts: 15 findings - high 0, medium 5, low 6, false 4, maybe-false 0
- findings:
  - `[medium]` `[patch]` the newly-permitted arm was asserted only through `ProcessControl.Verdict`,
    a test-local re-implementation of the branch order, never through the shipped `Prohibits` -
    verified: `Verdict` `:531` enumerates the two predicates itself, and the only `Prohibits` legs
    assert refusals. Patched: `TestTheShippedProhibitsPermitsAProcessTheConfirmingUserOwns` drives
    the shipped set against a second probe process started without a `Login`, reading its owner back
    from `%SYS.ProcessQuery` so the leg is not vacuous; mutation recorded and demonstrated.
  - `[medium]` `[patch]` (same root cause) the arms are pinned at the predicate, not at the shipped
    dispatch - closed by the leg above.
  - `[medium]` `[patch]` (same root cause) the permitted leg's `UserName` is inert because the
    predicate no longer reads it, and no recorded mutation reddened it - closed by the leg above and
    its `mutation:` line (re-add the ownership arm -> that leg red, every refusing leg green).
  - `[low]` `[patch]` `Test/ToolWrite.cls` said "the five ways one can be wrong" while the method
    asserts six and the paragraph this pass added enumerated six - verified against the body; both
    counts corrected.
  - `[low]` `[patch]` `Screen/Registry.cls`'s opening sentence still said a tool that declares no
    subject "has nothing wrong with it", which the new condition contradicts - the wrong sentence is
    replaced, not annotated, and the duplicated "One further condition:" opener is gone.
  - `[low]` `[patch]` `Kernel/Proposal/Prohibited.cls`'s class header still attributed both process
    predicates to AD-10 after the first one's authority became AD-7 plus AD-10's serving path -
    corrected at origin.
  - `[low]` `[patch]` `Turn.GuardedIsTurnJob`'s doc named the over-refusal window (a crashed job's
    `running` row) and not the under-refusal one (a `queued` row carries no `JobId` yet) - the
    converse is now named in the same paragraph.
  - `[low]` `[reject]` the fail-closed branch on a `GuardedIsTurnJob` error has no test and no seam -
    verified real, but it fails **closed**, is reachable only when the Turn table is unreadable, and
    the fix adds a `TurnStateClass()` seam: new public surface for one branch, which the low bar
    rejects.
  - `[low]` `[reject]` the spec's own Code Map still described `TaskResume` as declaring neither
    parameter and `SubjectProbe/` as five probes - real, but the fix edits this build's spec, which
    triage rejects; both sentences were corrected as bookkeeping instead.
  - `[medium]` `[defer]` superseded process-ownership claims survive outside this story's files -
    verified at `epics.md:153` (FR-55), `:807`, `:3506-3508`, `:5636`, `EXPERIENCE.md:93`, `:220`,
    `:414`, `prd.md:806`, `SPEC.md:99`, and `spec-5-12-*.md:53`, `:623`, `:666`, `:928`, `:943`.
    Deferred rather than patched: Rule 5 reserves planning-artifact amendments to the lead, and
    `EXPERIENCE.md`'s self-protection list is published copy a UX call governs.
  - `[medium]` `[defer]` (same root cause) 5.12's `## Verification` mutation recipes name
    `OwnedByCaller`, a method that no longer exists, so that story's Rule 19 evidence is no longer
    re-runnable as written.
  - `[false]` `[reject]` "5.13's own surface is absent from the diff" - descriptive and correct for a
    scoped rework: the tool, port, card and their tests were built in earlier passes and re-ran green
    in this pass's sweep.
  - `[false]` `[reject]` `ErrorDelete`'s subject framing is superseded - the amended AD-51 permits
    naming the id where the read answers one, so `namespace,entries` and its wording are both still
    accurate.
  - `[false]` `[reject]` the ledger is not written by this pass - Rule 15(a): build-auto records in
    the spec's `deferred:` list and the lead harvests.
  - `[false]` `[reject]` `GuardedIsTurnJob` spells `'running'` as a SQL literal rather than
    `..#STATERUNNING` - the class's own sibling queries at `:213` and `:373` use the same literal
    form, so this is the file's idiom, not a drift this pass introduced.

## Design Notes

**Governing ADs (Rule 6).** AD-48 (this story, whole), AD-51 **as amended 2026-09-22** and AD-6 **as
corrected in the same commit**, AD-16 (one explicit save/restore to `%SYS`, namespace as a
parameter), AD-13 **as amended** (the scoped triple and this story's own `foldcase` rule), AD-14
(one change event, the closed action enum, screens re-fetch and never patch -- **this story is the
first producer of `deleted`**), AD-8 **as amended 2026-09-21**, AD-10, AD-15 (ordinary case), AD-21
(namespace chosen from the set the user can read, never a caller path), AD-24 and AD-35 (the captured
payload reaches no surface the model sees), AD-29 (the port's own gate, established two ways
together), AD-34, AD-36, AD-40, AD-41, AD-43 (this screen is **not** on the roster of seven, so there
is no pause), AD-44 (the route's `?ns=` reaches this port on no path), AD-46, AD-5, AD-9,
AD-12/AD-39, AD-1, AD-2 (unchanged -- nothing here names an `%Api.Admin.*` class), AD-3 (no template
exists for `^ERRORS`, which is why the payload is secret by default), AD-4 (no subject: nothing is
sent), AD-11, AD-31, AD-33, AD-37, AD-45.

**Consumes:** 2.12 (the whole read half -- `LogSourcePort.Errors`, the drill levels, `PairsFor`,
`ErrorRead`, `ErrorLogFixture`, `ErrorLogSeed`, the drill store); 5.1-5.7 (mint, card, atomic
confirm, execution as the user, the prohibited set, the marker, the change bus, the toast and the
highlight); 5.8 (the `USE` pair rule); 5.9 (the per-type id rule and the per-type `Prohibited`
block); 5.10 (the declared-names union and the arming-variable pattern); 5.11 (the action-style seam
and `Changed`'s state-field skip); 5.12 (**the amended fingerprint-subject seam and its registration
guard** -- this story is its first consumer). Epic 13's coverage gates.

**Consumed-by:** Story 7.10 (`epics.md:4297`) adds the by-date and by-error scopes over this story's
tool, port façade and prohibited-set branch, and owns AD-48's by-date offer-or-refusal decision.
Stories after it that add a write with no vendor endpoint consume the per-tool port declaration.
**No consumer in this story for the port declaration itself beyond `ErrorDelete`; the first other
consumer is Story 7.10.**

**The AD-51 question, decided deliberately.** A `SYS.ApplicationError` delete **is** an action-style
write under AD-51, and AD-48's enumerated-id-set fingerprint is not a second fingerprint model beside
it -- it is what AD-51's *declared subject* projects out of this tool's fresh read. Every AD-51
clause is satisfied literally: the request type is declared per tool rather than assumed; no settable
field and no body; AD-4 has no subject because nothing is sent; the fingerprint covers the fresh
read; and the subject carries the scoped target identity (`namespace`) **and** the field the action's
own precondition reads (`entries` -- the mint refuses when it is empty). Reading it the other way --
that AD-48 answers the fingerprint differently -- would leave this tool outside AD-51's structural
guard, which is exactly the "declared but unchecked" state DW-1476 files against `TaskResume`, and
would make AD-51's amendment apply to no story that needed it. The decision is recorded here because
the spawn prompt is right that it would otherwise be taken by default.

**The demo script's process target, recorded rather than rediscovered.** The suspend demo acts on
**a second portal session's process** -- the operator signs in to the classic portal in another
browser and the demo suspends that session's job. The narrow ownership predicate permits it (it is
neither the confirming job nor a turn job) and the broad one refused it, which is why the target is
written down here. The demo fixture creates no process and needs no change: `Install/Fixture.cls`
creates the `/csp/myapp` application, the SSL configuration, the X.509 credential, the wallet
collection, the suspended `OcuPilotDemo nightly purge` task and one application error, and AD-25
forbids it to leave a long-lived process owned by an account it would have to create and assume.

**Why the fresh read is a new port method and not a fifth drill level.** `Errors`' four levels are
route-bound (`Api/Router.cls:95-98`); the enumeration is reached only through the write path and
never over HTTP, so a fifth level would add a public surface nobody calls. It is one `%SYS` window,
one `DateList` and one `ErrorList` per date -- six calls and 211 ids for `HSCUSTOM` on the live
instance, bounded by `DEFAULTMAXROWS`. A truncated enumeration **refuses the mint**: a cut set cannot
support "confirm deletes exactly those", and a silent partial delete is the shape this epic rules
against.

**Why the port is declared on the tool rather than switched inside the kernel.** AD-48 requires the
delete to be an ordinary write, and the kernel's four `AdminPort` constants are what make "ordinary"
impossible for a write with no vendor endpoint. Declaring the port beside the request type is the
same move AD-51 already made for the type (*"the request type is declared per tool, not assumed"*),
it leaves every shipped tool byte-identical through the default, and it keeps AD-2's containment
intact because nothing outside `AdminPort` names an `%Api.Admin.*` class. The alternative -- a branch
in the kernel keyed on the tool name or the entity type -- is a roster that must be kept in step with
the tools, which is the DW-1206 shape. **Rule 20 note for the lead:** this seam constrains later
stories, so it belongs in the spine (an AD-51 clause or an AD of its own) in the same bookkeeping
commit that resolves `## Blocking Condition`.

**Why `Changed()` must skip the declared subject, not just the state field.** A bodyless write's
stored payload **is** its fresh read (5.11's finding), so `Prohibited.Changed` compares two reads
rather than a payload against a read. For this tool the read's `entries`, `count` and `truncated`
all move whenever the instance logs an error -- which it does constantly, since that is what the log
is -- so today's one-field skip would turn every such race into a 403 `PROHIBITED.UNCOVEREDFIELD`
with the proposal row left **live**, where AD-6 requires a 409 `PROPOSAL.TARGETCHANGED` with it
closed. That is Story 5.11's defect with a wider blast radius, and `StateField()` was the narrow fix
for it. The declared subject is by construction the set whose movement the fingerprint adjudicates,
so it is the right skip.

**Where the eleventh instance of this epic's signature defect would hide, and how each refusal is
armed at its input.** Every refusal below is reached through the **shipped** entry point, with its
input arranged rather than its predicate replaced.

- *The per-namespace gate.* A purpose-built least-privileged principal on the throwaway holding the
  two instance pairs and `%DB_<ns>:READ` but not `%DB_<ns>:WRITE`, confirming through the real
  confirm route. Never `ErrorLogFixture.SetErrorPairs`, and never `%Operator` (which carries
  `%DB_IRISSYS:RW` and is a self-escalation primitive).
- *The prohibited set.* Driven through the shipped `Prohibits()`, not through a helper that
  re-implements the dispatch order -- 5.12's instance, verbatim.
- *The fingerprint, both directions.* A confirm that **succeeds** after a new error is logged (the
  non-vacuity floor: a subject that refused everything would read green on the refusal leg alone),
  and a confirm that is **refused** after an enumerated id is removed by another party. The first
  direction is blocked on `## Blocking Condition` item 1.
- *One namespace source.* A request carrying `?ns=` for a different namespace, asserted by reading
  back that the other namespace's errors survive -- an assertion about the instance, not about a
  parameter never passed on.
- *The registration guard.* Two new `SubjectProbe` classes drive `ListTools` to a refusal naming the
  class and the problem (`ToolWrite.cls:658-666`'s shape), not only the pure function.

**DW dispositions (Rule 17).** DW-1228, DW-1242, DW-1470, DW-1474, DW-1475 and DW-1476 each carry a
task above. DW-1423 is `## Blocking Condition` item 3 -- raised, not declined, because its copy half
is human-owned by its own trailer line and its routing premise (that this story's path executes the
`deleted` branch) needs the same answer. **DW-1475 is load-bearing here rather than a tidy-up**:
`LogErrorList` declares no `read` at all, so `DeclaredNames("read")` is empty for this descriptor and
today's guard would refuse **every** name `ErrorDelete` declares, at registration, before the tool
could exist.

**What this story does not touch.** `ErrorRead.SUMMARYFIELDS`; the four drill routes and their
levels; `EntityType.TYPES` and `Count()` (29, `Test/Descriptor.cls:1287`); `Classification.cls` and
`ToolFields` (a bodyless tool needs neither); `AdminPort.MUTATINGTYPES` and `BODYLESSTYPES`, which
key **vendor** request types and this write issues none; `LogErrorList`'s `refreshes: false` and
EXPERIENCE.md's roster of seven.

## Verification

**Targeted, inside the implement loop (loop):**

- `cd ui && node tools/screen-mirror.mjs` -- expected: regenerates cleanly; `git diff` touches only
  `screens.generated.ts`. `node tools/field-lists.mjs --check` is a no-op for this tool (bodyless).
- `uv run scripts/check-objectscript.py <changed paths>` -- expected: 21 rules pass.
- Load and compile the changed classes through the IRIS MCP tools with `server: "ocupilot-slot-a"`,
  reading the error text rather than assuming a clean compile. **Never delete an application error on
  `ocupilot`.**
- `cd ui && npm run test:tools` and `npm run test:components` -- expected: green, including
  `proposal-view.test.mjs`, `strings.test.mjs`, `citations.test.mjs`, `ci.test.mjs`,
  `screen-mirror.test.mjs`, `proposal-card.spec.ts`, `error-log.page.spec.ts`.
- The throwaway `ocupilot-ci` is up, is **not** pristine, and no session here brought it up -- **do
  not tear it down.** Before any result on it means anything: confirm it carries
  `OCUPILOT_ALLOW_ERROR_SEED` and the new `OCUPILOT_ALLOW_ERROR_DELETE` (a container started before a
  variable existed refuses the whole class and tests nothing while failing nothing -- DW-1452); where
  it does not, run the class through `docker exec -e OCUPILOT_ALLOW_ERROR_DELETE=1 ...` rather than
  recreating the container, and report the gap to the lead. Then sync the source to
  `/tmp/ocupilot-ci/src`, compile it, and run `OcuPilot.Install.Installer.Install` -- `ci-runner.mjs`
  does **not** load source, so a green under an unloaded mutation attributes nothing. Then
  `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`
  and re-run the installer -- a browser spec asserts the shipped bundle matches the stamp the
  **installer** recorded.
- `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.ErrorDelete` --
  and the same, **one class per invocation, waiting for each to land in `%UnitTest_Result` before the
  next**, for `OcuPilot.Test.ErrorLog`, `OcuPilot.Test.ErrorLogWire`, `OcuPilot.Test.ErrorLogDenial`,
  `OcuPilot.Test.Prohibited`, `OcuPilot.Test.ProhibitedRoute`, `OcuPilot.Test.ProhibitedByEffect`,
  `OcuPilot.Test.ToolWrite`, `OcuPilot.Test.Descriptor`, `OcuPilot.Test.TaskResume`,
  `OcuPilot.Test.ProcessControl`, `OcuPilot.Test.Proposal`, `OcuPilot.Test.ProposalConfirm`,
  `OcuPilot.Test.ProposalSpelling`, `OcuPilot.Test.AuditMarker`, `OcuPilot.Test.SurfaceCoverage`,
  `OcuPilot.Test.EndpointCoverage`, `OcuPilot.Test.WireSecurityRead`. Expected: each green, totals
  verified with the `%UnitTest_Result` SQL probe rather than the runner envelope. **Never two test
  calls in one message.** After the sweep, read back which namespaces still hold errors on the
  throwaway.
- `cd ui && OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci
  node --test --test-concurrency=1 browser/error-log-delete.browser-spec.mjs
  browser/error-log.browser-spec.mjs browser/change-highlight.browser-spec.mjs` -- expected: green.
  Clear `OcuPilot_Kernel_State.Pref` before trusting a local re-run (DW-1447, DW-1448).
- **Rule 19 -- one demonstrated mutation per AC, applied on `ocupilot-ci` with the whole `OcuPilot`
  package recompiled in the container, the named class run, then reverted in **both** the worktree
  and the container, with `git status --short` and `git diff --stat` confirmed unchanged after each.**
  The mutations this story owes, one per AC above, each recorded here as
  `mutation: <change> -> <which test went red>` by whoever writes or changes the pinning test:
  drop the drill-state namespace in favour of the route scope; empty `ErrorDelete.FINGERPRINTSUBJECT`;
  remove one enumerated id from the stored subject; answer `""` from `ErrorDelete.PrivilegePairs`;
  set `ErrorDelete.DESTRUCTIVE` to `0`; drop the removal row's `(removed)` branch from
  `proposal-view.ts`; drop `application-error` from `Prohibited.COVEREDTYPES`; drop
  `application-error:foldcase` from `EntityRef.IDRULES`; delete each new
  `FingerprintSubjectProblem` condition in turn; revert `ProhibitedFixture.Digest` to the
  three-argument `Fingerprint.Of`; run `OcuPilot.Test.ErrorDelete` with no
  `OCUPILOT_ALLOW_ERROR_DELETE`.
  Recorded by this pass, for the three pinning tests it changed -- each applied on `ocupilot-ci`
  with the whole package reloaded there, observed red, reverted and re-run green:
  `mutation: OcuPilot.Kernel.Proposal.Prohibited.IsOcuPilotProcess answers 0 ->
  OcuPilot.Test.ProcessControl, 2 methods red (the predicate legs and the shipped-Prohibits leg)`;
  `mutation: drop AND State = 'running' from OcuPilot.Kernel.State.Turn.GuardedIsTurnJob ->
  OcuPilot.Test.ProcessControl, 1 method red (the finished-turn leg)`;
  `mutation: delete the no-subject condition from OcuPilot.Screen.Registry.FingerprintSubjectProblem
  -> OcuPilot.Test.ToolWrite, 1 method red (TestAnInadequateFingerprintSubjectIsRefusedAtRegistration)`;
  `mutation: empty OcuPilot.Screen.Tool.TaskResume.FINGERPRINTSUBJECT -> OcuPilot.Test.ToolWrite,
  11 methods red -- the guard refuses the tool at registration, so it is no longer a tool`;
  `mutation: re-add the ownership arm to OcuPilot.Kernel.Proposal.Prohibited.IsOcuPilotProcess
  (refuse a target whose UserName is $Username) -> OcuPilot.Test.ProcessControl,
  TestTheShippedProhibitsPermitsAProcessTheConfirmingUserOwns red, every refusing leg green`.
  Recorded by the code-review pass (2026-09-22), for the four pinning tests it added or changed --
  each applied on `ocupilot-ci` only (the worktree copy left pristine and confirmed byte-identical
  by `shasum`), the named class run singly, observed red, restored and re-run `All PASSED`:
  `mutation: OcuPilot.Kernel.Proposal.Prohibited.ApplicationError answers permitted unconditionally
  -> OcuPilot.Test.ErrorDelete, TestAChangedFieldOnAnApplicationErrorProposalIsRefused red on the
  refused-count leg (run 5651)`;
  `mutation: drop the FingerprintSubject loop from
  OcuPilot.Kernel.Proposal.Prohibited.SkippedFields -> the same method red on the skipped-namespace
  leg, code PROHIBITED.UNCOVEREDFIELD (run 5652, applied alone -- with the ApplicationError mutation
  also in place the two mask each other on that assertion)`;
  `mutation: Quit after the first iteration of OcuPilot.Port.LogSourcePort.RemoveErrorIds' per-date
  loop -> OcuPilot.Test.ErrorDelete, TestTheDeleteReachesTheVendorOncePerEnumeratedDate red on the
  dates count and on the survival of the named error (run 5653)`;
  `mutation: delete the truncated branch from OcuPilot.Screen.Tool.ErrorDelete.StateDiff ->
  OcuPilot.Test.ErrorDelete, TestATruncatedEnumerationRefusesTheMint red, and nothing else (run
  5653)`;
  `mutation: drop the event.action !== 'deleted' guard from error-log.page.ts -> npm run
  test:components, error-log.page.spec.ts red at the updated leg (1 of 822)`.
  Measured for the multi-date leg: `SYS.ApplicationError.DeleteByError` answers `1` for a
  well-formed date the namespace holds no error on (`ocupilot-ci`, 2026-09-22), which is what makes
  a second date buildable without back-dating an `^ERRORS` node AD-48 forbids touching.


**Full runs, once, before `dev_complete` (once, before dev_complete):**

- `cd ui && npm run build && npm test` -- expected: the seven prebuild checkers pass and both client
  tiers are green. `npm test` does **not** run the browser suite.
- `cd ui && npm run test:browser` -- expected: the whole browser suite green against the redeployed
  bundle. The suite is **not** idempotent on a reused instance; capture the run in full rather than
  piping it through `tail`, which reports `tail`'s exit code.
- The full ObjectScript sweep through `ci-runner.mjs` against `ocupilot-ci`, one class at a time,
  reconciled against `%UnitTest_Result`.
- `bash scripts/smoke.sh --container ocupilot-ci --user _SYSTEM --password SYS` -- expected: zero
  checks `pending`, `fail = 0`, a non-zero executed count, and `agentwrite` and `auditmarker` both
  pass. Read the skip lines, not the number (DW-1402).
- `bash scripts/lint-docs.sh` -- expected: clean.

## Auto Run Result

Status: done
Blocking condition: none

**This pass closed the three items the 2026-09-22 decisions re-opened, and nothing else.**

**AC2's ownership prohibition is one predicate over two harms** (AD-7, AD-10).
`Prohibited.IsOcuPilotProcess` refuses the job serving the confirmation (`$Job`) and any job running
a turn, whoever owns it; a process the confirming user owns which is neither is now **permitted**.
A turn job is identified from OcuPilot's own record -- `Turn.GuardedIsTurnJob`, `running` rows only,
so a finished turn's pid cannot refuse the process the instance next gives that pid to -- rather
than from anything the process read carries, and the predicate fails closed on a read with no `Pid`
and on a state read that errors. The refusal code moved with the rule (`PROHIBITED.OWNPROCESS` ->
`PROHIBITED.OCUPILOTPROCESS`; still twelve codes, one sentence each), `FIELDUSERNAME` and
`OwnedByCaller` are gone, and both process tools' model-facing `DESCRIPTION` was corrected at its
origin. `epics.md`'s Story 5.12 AC2 carries the amendment marker.

**DW-1476 is enforced, and AD-51's corrected clause is what enforces it.**
`Screen.Registry.FingerprintSubjectProblem` refuses an action-style write that declares **no**
subject, and its identity condition is deleted -- identity is the proposal's `TargetRef` (AD-13),
not the digest's job. `TaskResume` declares `PRECONDITIONFIELD` and `FINGERPRINTSUBJECT` as
`Suspended`; its `SUSPENDEDFIELD` parameter became that precondition declaration rather than a
second name for the same field. `SubjectProbe/MissingIdentity` is replaced by `SubjectProbe/NoSubject`.

**The demo script's target is recorded** in `## Design Notes`: a second portal session's process,
which the narrow reading permits and the broad one refused. The fixture needs no change, so DW-1472
closes without one.

**Files changed.** `Kernel/Proposal/Prohibited.cls`; `Kernel/State/Turn.cls` (`GuardedIsTurnJob`);
`Screen/Registry.cls`; `Screen/Tool/Write.cls` (the adequacy contract at its origin);
`Screen/Tool/TaskResume.cls`; `Screen/Tool/ProcessSuspend.cls` and `ProcessResume.cls`;
`Test/ProcessControl.cls`; `Test/ProposalFixture.cls` (`SeedTurn` takes a `JobId`; `SetTurnState`
added); `Test/ToolWrite.cls`; `Test/TaskResume.cls`; `Test/SubjectProbe/NoSubject.cls` replacing
`MissingIdentity.cls`; `epics.md`.

**Review findings.** 15 filed across the two active layers (`blind-hunter` and `edge-case-hunter`
are disabled in `_bmad/custom/bmad-build-auto.toml`). Five entries patched -- one `medium` (the
newly-permitted arm was pinned only through a test-local re-implementation of the branch order, now
driven through the shipped `Prohibits` against a probe process the confirming user owns) and four
`low` doc corrections at their origin (`ToolWrite`'s five-versus-six count, `Registry`'s superseded
opening sentence, `Prohibited`'s AD attribution, `GuardedIsTurnJob`'s unnamed `queued` window). One
`medium` deferred: nine other documents still state the broad ownership reading, and Rule 5 reserves
that amendment to the lead. Four rejected as `false` and two as `low`, each with its reason in
`## Review Triage Log`. Follow-up review: `false` -- no `high` was patched on this follow-up pass.

**Verified.** `check-objectscript` 612 files / 21 rules / 0; `npm run test:tools` 1306/0;
`npm run test:components` 822/0; `npm run build` (seven prebuild checkers) clean; `lint-docs` clean.
On `ocupilot-ci`, the mounted source byte-identical to the worktree and the package reloaded before
every run: **the full ObjectScript sweep, 178 classes one at a time, 1,625 methods, 0 failures**,
reconciled against `%UnitTest_Result` rather than the runner envelope. Full browser suite 227 tests,
226 pass -- the one failure was the reused throwaway's shell directory holding three `main-*.js`
from successive `docker cp`s, so the stamp named the lexicographically greatest while the page
loaded another; refreshing the mounted bundle and re-running `Install` with its bundle source left
one `main`, and that spec re-ran 6/6. `smoke.sh --container ocupilot-ci` executed 46, passed 46,
failed 0, pending 0, `agentwrite` and `auditmarker` both passing, one environmental skip
(`agentswitches`). Five Rule 19 mutations applied on `ocupilot-ci` with the package reloaded there,
observed red, reverted in both the worktree and the container, and re-run green (`## Verification`).
The changed classes are loaded and compiled on `ocupilot-slot-a` too.

**One matrix row still names a mechanism the instance does not use**, unchanged from the previous
pass and for the lead: "Namespace with no errors" expects `StateDiff` to answer `pProblem`, while
`NamespaceList` answers only namespaces that hold errors, so the port refuses `LOG.NAMESPACE` 404
before `StateDiff` runs. The row's behavior column holds and is pinned (`Test/ErrorDelete.cls:263`).

**Left as it was found.** No process suspended on either instance and no probe process or probe
principal surviving (read back on `ocupilot-ci`: 0, 0, 0); `OcuPilotDemo nightly purge` still reads
`Suspended=1`; the throwaway's only namespace holding application errors is `HSCUSTOM`, so the
seeded `USER` errors are gone; `ocupilot` still holds its 6 dates and 211 errors, unchanged; no
container stopped, recreated or torn down.
