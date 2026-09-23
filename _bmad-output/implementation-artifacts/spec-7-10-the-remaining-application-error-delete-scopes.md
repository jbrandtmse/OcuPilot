---
title: 'Story 7.10: The remaining application error delete scopes'
type: 'feature'
created: '2026-09-23'
status: 'done'
baseline_revision: 'b23f3d530168257564cad06f6d1634a27c8ca61a'
baseline_commit: 'b23f3d530168257564cad06f6d1634a27c8ca61a'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-7-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-5-13-logs-delete-application-errors-by-namespace.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-7-8-terminate-suspend-and-resume-a-process.md'
warnings: ['oversized']
deferred:
  - summary: >-
      The agent's absent-scope refusal is 400 TOOL.ARGUMENTS, not the matrix's 404 LOG.DATE or
      LOG.ENTRY: the kernel mint maps any port 404 to a refused argument naming the id.
    evidence: |-
      Kernel/Proposal/Mint.cls Mint: `If +$Get(tReadHttp) = 404` -> Refuse("'<id>' is not present").
      The port answers 404 LOG.DATE/LOG.ENTRY (ErrorDeleteScope, run 8437) and the screen route
      passes it through; Mint.cls is on this story's Never list. (inference: intended by 5.13)
    location: src/OcuPilot/Kernel/Proposal/Mint.cls
    severity: low
  - summary: >-
      A number reused within the same second as the error it replaces is not detected: the
      vendor's ErrorList Time has one-second resolution.
    evidence: |-
      ErrorList Time reads HH:MM:SS on ocupilot-ci (probe 2026-09-23). Needs the date emptied and a
      new error logged at the same number inside the original's second. (inference: theoretical)
    location: src/OcuPilot/Port/LogSourcePort.cls
    severity: low
  - summary: >-
      The ?ns= leg's "HSCUSTOM untouched" half cannot fail unless HSCUSTOM holds an error with the
      same date and number as the USER seed.
    evidence: |-
      ErrorDelete.TestAScreenDeleteIgnoresTheRoutesNamespace seeds only USER (the spec confines seeds
      to USER), so a port deleting in both namespaces would stay green. Settled by a colliding
      HSCUSTOM seed, which needs the USER-only rule relaxed.
    location: src/OcuPilot/Test/ErrorDelete.cls
    severity: low
footprint_extensions: # as landed; Epic 8-modified files, this story's own members only (roster rule, 2026-09-23)
  - 'src/OcuPilot/Test/ToolWrite.cls' # Epic 8 modified; only the ErrorDelete leg :818-878, off its hunks (~:164, ~:1133-1145, ~:1188-1190)
  - 'ui/tools/screen-mirror.test.mjs' # Epic 8 modified; only the LogErrorList pin :899-905
  - 'ui/src/app/core/screens.generated.ts' # regenerated
---

<intent-contract>

## Intent

**Problem:** Only the agent can delete application errors, and only a whole namespace at a time
(5.13). The error log screen has no delete. By-date and by-error deletes do not exist, and nothing
records that `DeleteByDate` was considered and refused.

**Approach:** Widen 5.13's one tool, `logs.applicationerrors.delete`, so it takes a scope, and put
a single **Delete** action on every level of the drill-down. It stays one operation with two
callers (AD-53).

- **Scope comes from the target id.** The id is a prefix of the error's composite id:
  - by namespace: `ns`
  - by date: `ns␁date`
  - by error: `ns␁date␁n`
- **The two callers supply that id differently.**
  - The screen sends the prefix for the drill level it is on.
  - The agent passes `namespace`, plus optional `date` and `errorNumber`. A new tool-declared
    `MintClass` joins them into the composite id before `##super`.
- **The port enumerates the scope at the write.** It deletes exactly the enumerated ids through
  `DeleteByError`, and never calls `DeleteByDate` (measured; see Design Notes).

## Boundaries & Constraints

**Always:**

- `SYS.ApplicationError` is the only door (AD-48).
  - The port calls `ErrorList`, `DateList` and `DeleteByError`, and never `DeleteByDate` or
    `DeleteByNamespace`.
  - It uses one `%SYS` window, with the namespace as a parameter (AD-16).
- The namespace always comes from the id. On the screen, the id is built from the drill level:
  the namespace row, or `namespaceValue`. The route's or the shell's `?ns=` reaches no layer.
- A proposal's fingerprint is the enumerated entry set (`namespace,entries`), captured at mint.
  - Confirm deletes exactly the entries that survive the re-read.
  - An error logged after the mint is residue, and the card says so (`proposalResidue`).
- The gate is per namespace, and it is checked before any read on both paths:
  - `%Admin_Operate:USE` and `%DB_IRISSYS:READ`;
  - `%DB_<ns>:READ` and `%DB_<ns>:WRITE`, both from `PairsFor`.

  `ArgumentPairs` takes the namespace from the id's first composite part.
- Summary fields only (AD-48, AD-24). No stack frame or variable table reaches a diff, a proposal,
  a ledger row or screen context.
- Publish one `application-error` `deleted` event per write, with the canonical id. The page
  re-reads and never patches.
- Every string lands in Fixed strings and `strings.ts`, append-only, and the lead publishes it.
- Destructive tests run only on `ocupilot-ci`, and only against errors the test itself seeded in
  `USER`. Run one test class per call.

**Never:**

- No edit to these files:
  - `Kernel/Proposal/**` (Mint, Confirm, Prohibited and the rest);
  - `Screen/Tool/Write.cls`, `Screen/Registry.cls`, `Kernel/EntityRef.cls`;
  - `Api/ScreenAction.cls`, `Operation.cls`, `Api/Router.cls`;
  - `ui/src/app/core/proposal-view.ts`, `ui/src/app/shell/proposal-card.ts`, `screen-outlet.ts`,
    `ui/tools/screen-mirror.mjs`;
  - `scripts/ci-*.sh`, `ci.yml`, `Install/**`.
- No new tool, no new drill level, no new route, no new `selfProtection` value, no new armed test
  class, and no new entity type.
- No `DeleteByDate` call anywhere in the product, and no `^ERRORS` traversal.
- Never delete an application error on `ocupilot` or on any `ocupilot-slot-*` container.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected | Error |
|---|---|---|---|
| Screen, namespace | namespaces level; Delete on the `USER` row; the user types `USER` | dialog "Delete the errors in USER"; POST `{action:"delete", id:"USER"}`; every error enumerated at the write is removed; the row leaves | mismatch: "Does not match", nothing is sent |
| Screen, date | dates level in `USER`; Delete on `09/23/2026` | dialog "Delete the errors of 09/23/2026"; id `USER␁09/23/2026`; only that date's errors go; the drill steps up if the namespace is now empty | – |
| Screen, one error | list or detail level; Delete on error 4 | dialog "Delete error 4"; id `USER␁09/23/2026␁4`; only #4 goes; detail steps up to the list | – |
| Agent, by date | args `{namespace, date}` | a destructive card with one removal row per entry on that date, plus the residue sentence; an error logged after the mint survives the confirm; one marker; the event id is `user␁09/23/2026` | – |
| Agent, by error | args `{namespace, date, errorNumber}` | one removal row; only that error goes | – |
| Bad arguments | `errorNumber` without `date`, or any argument containing U+0001 | 400 `TOOL.ARGUMENTS` with `detail.problem`; no port read | – |
| Absent scope | a date `DateList` does not answer as spelled (such as `9/23/26`), or a number `ErrorList` does not hold | 404 `LOG.DATE` or `LOG.ENTRY`; nothing is deleted | – |
| Number reused | after the mint, the date is emptied and new errors take the same numbers | 409 `PROPOSAL.TARGETCHANGED`; the new errors survive | – |
| Route scope | the request carries `?ns=HSCUSTOM` while the id names `USER` | only `USER` is touched; `HSCUSTOM`'s count is unchanged | – |
| Short of the pair | the caller lacks `%DB_USER:WRITE` (screen or agent) | 403 `AUTH.NOPRIVILEGE`, `failedPair` `%DB_USER:WRITE`, before any read; nothing is deleted | – |
| Too large | the scope holds more than 1,000 errors | refused by 5.13's truncation rule, for both callers | `detail.problem` |

</intent-contract>

## Code Map

Measured 2026-09-23. Line anchors are from this worktree.

**Probes.** Run on `ocupilot-ci`, namespace `HSSYSLOCALTEMP`, against probe errors only. The
baseline was restored and diffed identical.

- **`DeleteByDate`.**
  - Formats: `MM/DD/YYYY`, `M/D/YYYY` and a `$H` integer all delete the date. `9/23/26` (read as
    1926), `""` and a nonexistent namespace all answer `$$$OK` and delete nothing.
  - **It deleted an error logged after the enumeration.**
  - It kills the date node, so the next error on that date is **#1**.
- **`DeleteByError(ns, date, "3,2,1")`.**
  - It kept #4, logged after the enumeration, and the counter continued.
  - `$LB` and missing ids answer OK and delete nothing silently. A partial list deletes the ids
    that exist.
  - Emptying a date by any method drops the date from `DateList` and restarts its numbering at 1.
- `DateList` emits `09/23/2026`.

**Server.**

- `src/OcuPilot/Screen/Tool/ErrorDelete.cls` (202 lines):
  - parameters: `TOOLNAME` `:25`, `PORTCLASS` LogSourcePort `:32`, `READTYPE ENUMERATE` `:37`,
    `WRITETYPE DELETE` `:40`, `READANSWERS` `:59`, `PRECONDITIONFIELD entries` `:63`,
    `FINGERPRINTSUBJECT namespace,entries` `:69`;
  - `IdArgument`/`IdParam` answer `namespace` (`:79`, `:86`); `InputSchema` `:100`;
    `ArgumentPairs` `:131-136` (passes the whole id);
  - `StateDiff` `:145-184`, where row = `{field: date, before: errorNumber, after: "",
    removed: 1}` and truncation is refused at `:155`;
  - `PortQuery` `:195-200`;
  - no `SCREENACTIONS`.
- `src/OcuPilot/Port/LogSourcePort.cls` (Epic 7 only):
  - `Invoke` `:834-853` reads only `namespace` and `entries`;
  - `ErrorSet` `:860-907` checks the instance pairs, then `PairsFor`, then maps faults;
  - `ErrorSetRun` `:918-976` is the one `%SYS` window; `NamespaceSpelling` is at `:927`;
  - `ENUMERATE` `:942-955` goes to `ErrorIdRows` `:1025-1072` or `SurvivingIdRows` `:1084`;
  - `DELETE` goes to `RemoveErrorIds` `:1187-1209`, one `DeleteByError` per date;
  - `RequestedIds` `:1130`, `DateHeld` `:1404`, `ErrorHeld` `:1501`;
  - `DeleteByNamespace` is mentioned at `:140` and `:1171`.
- **The id reaches the port only as `IdParam`'s value.**
  - The mint reads `tQuery(IdParam)=id` with no `PortQuery` (`Kernel/Proposal/Mint.cls:141-143`).
  - `Prohibited.Target` does the same (`:1346-1348`).
  - The screen route passes the whole normalized id as `IdArgument` (`Api/ScreenAction.cls:141`,
    `:191`). Its gate runs first (`:192`), then the fresh read (`:202`), then `Apply`, which adds
    `PortQuery` (`:261`).
  - Confirm re-reads from the stored `TargetRef` together with `PortQuery`
    (`Confirm.cls:548-604`).
- **The only per-tool lever is `MintClass()`.**
  - `Write.cls:345` declares it and `:617` calls it. `Write.View` (`:599`) is `Final`.
  - `Mint.Mint`'s signature is the same on both branches (`:112` here, `:131` on Epic 8).
  - `Mint.Refuse` (`:576`) answers 400 `TOOL.ARGUMENTS`, and a subclass may call it.
- **Codec and identity.**
  - `Kernel/EntityId.cls` `JoinComposite` `:74` and `SplitComposite` `:81` use `$C(1)`.
  - `EntityRef` `IDRULES` `application-error:foldcase` (`:59`) lowercases the whole composite.
- `src/OcuPilot/Screen/Descriptor/LogErrorList.cls`:
  - drill-down, composite id `namespace,date,errorNumber` (`:81`);
  - `rowActions []` (`:83`); no `read` and no `table`, so the Registry needs no `emptyAgentKey`;
  - the doc at `:52-53` says the scopes are Epic 5's.
- **Tests.**
  - `Test/ErrorDelete.cls` is armed by `OCUPILOT_ALLOW_ERROR_DELETE`, `_ERROR_SEED` and
    `_PRINCIPALS` (`:27-36`). Its target is `USER` (`:40`). Helpers: `PreparePrincipal :112`,
    `Seed :612`, `Enumerate :625`, `Mint :649`, `ConfirmAs :661`, `RemoveDirect :669`,
    `Clear :691`. The least-privilege leg is at `:571`.
  - `Test/ToolWrite.cls:875` asserts that a `date` argument is refused.
  - `Test/Descriptor.cls:922-923` asserts no row action.
  - `ui/tools/screen-mirror.test.mjs:899-905`.
- **Stale docs that the rules forbid this story to edit.** `Prohibited.cls:311-312`, `:680-688`
  ("the one write … by-namespace delete").

**Client.**

- **`ui/src/app/areas/logs/error-log.page.ts`.**
  - Its own grid is at `:82-148` and `:389-446`. Row keys: the namespace, then the date, then
    `String(errorNumber)`.
  - The detail view is at `:449-486`. Refresh is registered at `:237`.
  - The bus subscription is at `:248-257`, and it calls `drill.applyDeleted(event.id)`.
  - It has no selection, no menu, no dialog and no handler.
- **`error-log.store.ts`.**
  - Levels are at `:8`, state at `:134-162`, `open*` at `:266-323`, `reopen` at `:339` and `back`
    at `:381`.
  - Every read sends `scope: null` (`:400`).
  - `applyDeleted(namespace)` (`:370-378`) compares the whole id to the namespace (`sameNamespace`
    `:478`) and steps up on `VANISHED_LEVEL_CODES` (`:18`).
- **The precedent for a bespoke page that hosts actions** is `os-management/process-details.page.ts`:
  - it injects the handler (`:140`);
  - it selects its own row (`:195`, `:218-227`);
  - it shows the dialog through `pendingTypedName` (`:230-234`, template `:117-127`);
  - confirm and cancel are at `:242-248`, and cancel on destroy at `:210`;
  - its refusal banner is at `:72-77` and `:237-240`.
- **`shell/screen-action-handler.ts`.**
  - `SCREEN_ACTION_DESCRIPTORS :34-44`, `DESTRUCTIVE_ACTIONS :121`, `DESTRUCTIVE_CONSEQUENCES
    :132-140` (an action with no entry is not registered, `:250-252`), `TYPED_NAME_ROWS :154-158`.
  - `start :312-356`, `row() :419` (reads `store.data()`, which the drill never fills).
  - `send :433-469` POSTs `{action, id, values?}` to `/screens/<toolIdentifier>/action` and
    publishes the answer's `target`.
- **`shell/typed-name-dialog.ts`**: the heading and the button read `${verb} ${target}` (`:144`,
  `:146`).
- **`shell/command-bar.ts` `bindStore :531-535`** follows no store when `screen.read === null`, so
  on this screen the bar would never see a selection.
- **The DataTable idioms to copy**: the hidden Actions header (`data-table.ts:225-231`) and the row
  menu (`:311-350`, `:661-680`).
- **Displaying ids.**
  - `core/entity-id.ts` `joinCompositeId`/`splitCompositeId` `:38-48`.
  - Ids are rendered raw by `formatProposalTitle` (`shell/example-proposal.ts:39`) and by
    `formatChangeSentence` (`core/toasts.ts:94`, used by `toast-host.ts:177` and `panel.ts:933`).
  - The card's residue sentence is keyed on `application-error` (`proposal-card.ts:40`,
    `:549-555`) and is correct for any scope.
- **Browser.**
  - `ui/browser/error-log.browser-spec.mjs` checks the header lists with `deepEqual` at `:361`,
    `:368-372` and `:373-386`, and seeds at `:106-130`.
  - `error-log-delete.browser-spec.mjs` has the `-ci` guard idiom (`:60-72`, `:90`).
  - The typed-name flow to copy is `process-actions.browser-spec.mjs:289`.
- **Bundle**: `ui/angular.json:54` `maximumWarning` is `1181kB`, pinned at
  `angular-json.test.mjs:373`.

## Tasks & Acceptance

**Execution:**

- `src/OcuPilot/Port/LogSourcePort.cls`:
  - **Parse the id.** `Invoke` splits `pQuery(namespace)` with `EntityId.SplitComposite` into a
    namespace, an optional date and an optional error number. More than three parts, or an empty
    part, is 400 `LOG.ENTRY`.
  - **`ENUMERATE` narrows to the scope.**
    - A date must equal, character for character, a `DateList` row for the namespace. Otherwise it
      is 404 `LOG.DATE`.
    - A number must be held by `ErrorList` on that date. Otherwise it is 404 `LOG.ENTRY`.
  - **Each entry carries the vendor's `Time`.** An entry is `{date, errorNumber, time}`, and the
    re-read answers the current `Time`, never the stored one.
  - `DELETE` is unchanged: exactly the given entries, through `DeleteByError`.
  - The class doc names the three scopes and states that `DeleteByDate` and `DeleteByNamespace` are
    never called, and why.
- `src/OcuPilot/Screen/Tool/ErrorDelete.cls`:
  - add `SCREENACTIONS "delete"`;
  - `InputSchema` adds optional `date` ("exactly as the log lists it, MM/DD/YYYY") and optional
    `errorNumber`, and describes the three scopes;
  - `MintClass()` answers `OcuPilot.Screen.Tool.ErrorDeleteMint`;
  - `ArgumentPairs` resolves `PairsFor` on `$List(SplitComposite(id),1)`;
  - update `DESCRIPTION`.
- `src/OcuPilot/Screen/Tool/ErrorDeleteMint.cls` (new, extends `OcuPilot.Kernel.Proposal.Mint`).
  It overrides `Mint` only:
  - `errorNumber` without `date`, or any argument containing `$C(1)`, is refused with `..Refuse`;
  - otherwise it calls `##super` with `pIdValue = JoinComposite(namespace[, date[, errorNumber]])`;
  - it rewrites `$C(1)` in a returned `detail.problem` as `" › "`.
- `src/OcuPilot/Screen/Descriptor/LogErrorList.cls`:
  - `rowActions [{"id":"delete","selfProtection":""}]`;
  - `entityLabelKey proposalEntityApplicationErrors`;
  - rewrite the doc at `:52-53`.
- `ui/src/app/areas/logs/error-log.store.ts`:
  - add `selectionKey(row)` per level: `ns`, then `join(ns,date)`, then `join(ns,date,n)`, with the
    namespace always the row's or `namespaceValue`, never the route's;
  - `applyDeleted(id)` compares `splitCompositeId(id)[0]`;
  - clear the selection on every level change and whenever the selected key leaves after a re-read.
- `ui/src/app/areas/logs/error-log.page.ts`:
  - **Hosting the handler.** Inject `ScreenActionHandler`, and write the selection into
    `ScreenStores.for(LogErrorList, refreshRates)`.
  - **The row menu.** Add a visually hidden Actions header and a last-cell "⋮" row menu at the
    namespaces, dates and list levels, copying DataTable's idiom. Opening the menu, or clicking a
    row outside its link, selects the row (`aria-selected`).
  - **The detail level** selects its own error after each load.
  - **Dialog and refusals.** Render the typed-name dialog while the pending action is this
    screen's, using `pending.verb`, `pending.name` and `pending.consequence`. Cancel it on destroy.
    Show the `role="alert"` refusal banner.
- `ui/src/app/shell/screen-action-handler.ts`:
  - add `LogErrorList` to the roster;
  - add `DESTRUCTIVE_CONSEQUENCES.LogErrorList.delete` (the namespace sentence);
  - add a `SCOPED_TARGETS` map: for `LogErrorList`, the composite part count (1, 2 or 3) selects
    the verb and the consequence, and `name` is the last part.
- `ui/src/app/shell/command-bar.ts` -- `bindStore` also follows a screen that has no read but
  declares row actions.
- `ui/src/app/core/entity-id.ts` -- `displayEntityId(id)` joins the composite parts with
  `' › '`. `formatProposalTitle` and `formatChangeSentence` apply it to the name or entity.
- `ui/src/app/core/screens.generated.ts` -- regenerate.
- **Conditional (DW-1166).** If `npm run build`'s initial total goes past 1181kB, re-base
  `maximumWarning` to 5% above the measured total, rounded up to a whole kB (1 kB = 1,000 B).
  Change only `ui/angular.json`'s value line and the pin in `angular-json.test.mjs`.
- **Tests.**
  - `src/OcuPilot/Test/ErrorDeleteScope.cls` (new, unarmed, deletes nothing):
    - the schema (optional `date` and `errorNumber`, still closed);
    - `ErrorDeleteMint`'s two refusals;
    - `ArgumentPairs` on a composite equals `PairsFor` on its namespace;
    - the port answers 400 for four parts, and 404 `LOG.NAMESPACE`/`LOG.DATE` for scopes that are
      not in the log;
    - `LogErrorList` declares `delete`, and `ErrorDelete.ScreenActionIds()` contains it. (`ToolFor` is
      `[Private]`; the screen legs in `ErrorDelete` cover the route's choice.)
  - `src/OcuPilot/Test/ErrorDelete.cls` (armed; append; its own `USER` seeds). Each leg reads the
    result back:
    - agent by date, where an error seeded after the mint survives;
    - agent by error;
    - reused numbers give `TARGETCHANGED`, via `RemoveDirect` and then a re-seed;
    - screen route: each of the three scopes;
    - screen by error with `?ns=HSCUSTOM`, where the `HSCUSTOM` count is unchanged;
    - screen by date as a principal short of `%DB_USER:WRITE`, which gives 403 with that
      `failedPair`.
  - Rosters (this story's members only):
    - `ToolWrite :875`: `date` and `errorNumber` are admitted, and an unknown key is still refused;
    - `Descriptor :922-923`;
    - `screen-mirror.test.mjs :899-905`;
    - `screen-action-handler.spec.ts`'s pins of `SCREEN_ACTION_DESCRIPTORS`, if it has any.
  - Client:
    - `error-log.page.spec.ts`: the menu selects the composite for each level; the dialog heading,
      name and consequence for each scope; the posted id's namespace is the drilled one under a
      route with `?ns=OTHER`; a mismatch sends nothing; the refusal banner; a composite `deleted`
      event re-reads and steps up; the selection clears;
    - `screen-action-handler.spec.ts`: the scoped verb, name and consequence;
    - `command-bar.spec.ts`: the bar follows the selection on a screen with no read;
    - `ui/tools/entity-id.test.mjs` and `toasts.test.mjs`: `displayEntityId`;
    - `example-proposal` spec: the title of a composite id.
  - Browser:
    - `ui/browser/error-log.browser-spec.mjs`: the header lists gain the hidden Actions label;
    - `ui/browser/error-log-actions.browser-spec.mjs` (new, `-ci` guard, seeds in `USER`): delete
      one error from the list row menu (typing its number); delete a date from the command bar;
      delete the namespace from the namespaces level; a mismatch sends nothing; the drill steps up.

**Acceptance Criteria:**

- **AC1 (three scopes):** Given the drill-down, when the user deletes from the namespaces, dates,
  list or detail level, then:
  - the dialog names that scope;
  - the dialog releases only on the typed name;
  - exactly that scope's errors enumerated at the write are removed;
  - the row leaves.

  `DeleteByDate` is refused by design: no layer calls it.

  *Pins:* `error-log-actions.browser-spec.mjs`; `ErrorDelete` (the screen legs).
- **AC2 (the fingerprint is the id set):** Given a by-date or by-error proposal, when it is minted
  and confirmed, then:
  - its rows are the enumerated entries;
  - confirm deletes exactly those that survive;
  - an error logged after the mint remains;
  - a reused number is refused with `TARGETCHANGED`.

  *Pin:* `ErrorDelete`.
- **AC3 (one namespace source):** Given a request or a route that carries `?ns=`, when a delete is
  resolved, then the namespace is the id's (the drilled level), and the other namespace is
  untouched. *Pins:* `ErrorDelete` (the `?ns=` leg); `error-log.page.spec.ts`.
- **AC4 (per-namespace gate):** Given a caller without `%DB_<ns>:WRITE`, when it deletes any scope,
  then it gets 403 `AUTH.NOPRIVILEGE` naming that pair before any read. *Pin:* `ErrorDelete`
  (the principal leg).
- **AC5 (agent arguments):** Given `errorNumber` without `date`, or U+0001 in an argument, then it
  gets 400 `TOOL.ARGUMENTS` and nothing is read. *Pin:* `ErrorDeleteScope`.
- **Integration AC (Rule 1):** `ErrorLogPage` consumes the screen-action answer's composite
  `deleted` event and re-reads. `Confirm` consumes `ErrorDeleteMint`'s composite target and removes
  exactly the enumerated entries. Both are observed on `ocupilot-ci`.

## Spec Change Log

- 2026-09-23, lead spec gate: the AD-48 sentence is in the spine; EXPERIENCE `:87` is amended; the copy is
  published at `EXPERIENCE.md:426-429` and appended to `strings.ts` under these keys (two renamed, one
  reused -- consume them): `errorDeleteEveryVerb` ("Delete the errors in"), `errorDeleteDateVerb`,
  `errorDeleteOneVerb`, `errorDeleteEveryConsequence` (the by-namespace body), `errorDeleteDateConsequence`,
  `errorDeleteOneConsequence`; the card's noun reuses `errorLogListLabel` ("Application errors", already
  published) instead of a new `proposalEntityApplicationErrors`. A key whose name contains "namespace" is
  refused by `strings.test.mjs`'s namespace roster, hence the renames.

## Review Triage Log

### 2026-09-23 — Review pass

- verdicts: 17 findings — high 0, medium 3, low 7, false 7, maybe-false 0
- findings:
  - `[medium]` `[patch]` A date-scoped enumeration was never checked against a namespace with several dates — added a `QueriesNamed(DateList) = 1` assertion to `ErrorDeleteScope`'s narrowing leg; red under "walk every date" (run 8446).
  - `[medium]` `[patch]` AC4's named pin stays green under its own mutation; "before any read" unobserved on the route — added `ErrorDeleteScope.TestTheRouteGateRefusesEveryScopeShortOfItsWritePair` (the shared `Operation.Gate` the route runs before `Read`, `ScreenAction.cls:192`, with each composite id); red under "whole id to PairsFor" (run 8446).
  - `[low]` `[defer]` The `?ns=` leg's HSCUSTOM half cannot fail without a colliding HSCUSTOM seed — settling it needs a non-USER seed the intent excludes; recorded in `deferred:`.
  - `[low]` `[reject]` Tasks and Design Notes still name `proposalEntityApplicationErrors` — the fix edits this spec; the Spec Change Log records the switch to `errorLogListLabel`.
  - `[low]` `[reject]` A proposal pending across the deploy gets 409 because entries gained `time` — safe refusal, short-lived; a guard adds complexity.
  - `[low]` `[defer]` Agent-side absent scope is 400 `TOOL.ARGUMENTS`, not 404 — `Kernel/Proposal/Mint.cls` maps any port 404 and is on the Never list; carried in `deferred:` from implement.
  - `[medium]` `[patch]` Short of the pair "before any read" — same root cause as the AC4 row above and patched by the same leg; the agent half is false, since the agent's `ArgumentPairs` reads the bare `namespace` argument and 5.13's confirm leg covers it.
  - `[low]` `[reject]` Bad arguments tested through `ErrorDeleteMint.Mint`, not the dispatcher — the `MintClass` lever is pre-existing (`Write.cls:617`) and `ErrorDeleteScope` asserts the tool answers `ErrorDeleteMint`; a dispatcher leg adds fixture complexity.
  - `[low]` `[reject]` Agent by date: card residue and event id not asserted — the card and the client's event read the proposal target, asserted `user␁<date>` in the by-date leg; the residue sentence is keyed on the unchanged entity type.
  - `[low]` `[patch]` Delete from the detail level and its step-up untested — added a detail-level leg to `error-log.page.spec.ts`; red with `syncSelection`'s detail branch removed.
  - `[false]` `[reject]` Too large not tested for the screen caller — `ScreenAction.cls:344` runs the tool's `StateDiff` and refuses on its problem; 5.13's `TestATruncatedEnumerationRefusesTheMint` pins the refusal.
  - `[false]` `[reject]` `time` goes beyond `namespace,entries` — the Tasks mandate `{date, errorNumber, time}` entries; the fingerprint subject is unchanged.
  - `[false]` `[reject]` Mismatch asserted by element, not "Does not match" text — the text is the shared typed-name dialog's (7.6), unchanged here.
  - `[false]` `[reject]` `displayEntityId` in `formatProposalTitle`/`formatChangeSentence` reaches other screens — mandated by the Tasks; a one-part id reads as itself (`entity-id.test.mjs`).
  - `[false]` `[reject]` `bindStore` follows any read-less screen with row actions — mandated by the Tasks; a screen with neither keeps the early return.
  - `[false]` `[reject]` The page re-implements DataTable's menu — the Tasks direct copying DataTable's idiom.
  - `[false]` `[reject]` `ErrorDeleteScopeTool` might be listed as a tool — `Registry` excludes `OcuPilot.Test.` (`EXCLUDEDPACKAGE`, `Registry.cls:27`).

## Design Notes

**Governing ADs:** AD-48, AD-53, AD-51, AD-52, AD-56 (ii), AD-6, AD-8, AD-10, AD-13, AD-14, AD-15,
AD-16, AD-21, AD-24, AD-29, AD-34, AD-35, AD-39, AD-5, AD-19.

**`DeleteByDate` is refused, on evidence.** The owner's "developer tool first" rule is met, because
the by-date *scope* ships. The *method* breaks AD-48's "confirm deletes exactly those": it removed
an error logged after the enumeration, and it restarts the date's numbering. So the by-date scope
enumerates, like by-namespace, and deletes through `DeleteByError`.

**Why one tool.** A single `delete` action keeps the command bar honest. With three action ids it
would offer all three scopes at every level, because it lists every declared row action. The scope
is the target: a prefix of the declared composite id, which is AD-13's own codec rather than a
second grammar.

A namespace proposal and a date proposal are not siblings (AD-34). Confirming one moves the other's
entries, so the other is refused with `TARGETCHANGED`.

**Why the `MintClass` subclass.** `Write.View` is `Final` and sends one id, and both `Write.cls` and
`Mint.cls` are Epic 8-contended. The per-tool `MintClass` lever composes the id without editing
either. It sits in `Screen/Tool/`, and its dependency on `Kernel.Proposal.Mint` is the one
`MintClass()` already names.

**`time` in each entry** closes the number-reuse window that was measured. Without it, a date
emptied between mint and confirm would let new errors match the stored numbers.

**The screen caller carries no fingerprint (AD-53).** It deletes what its fresh read enumerates at
the write, as the classic portal does. The consequence sentence says that errors logged after
Confirm are kept.

**The composite display** `' › '` is a separator, not copy. It uses the breadcrumb metaphor.

**Spine amendment for the lead (Rule 20, light path).** AD-48 gains:

> The narrower scopes are prefixes of the error's composite id (namespace; namespace and date;
> namespace, date and number), and each is enumerated at proposal time and deleted through
> `DeleteByError`. `DeleteByDate` and `DeleteByNamespace` are never called: measured on this build,
> `DeleteByDate` deletes an error logged after the enumeration, and emptying a date by any method
> restarts its numbering, so each enumerated entry carries its `Time`.

**Copy for the lead to publish** (an EXPERIENCE row plus a `strings.ts` key for each):

- EXPERIENCE `:87` amended to: "by namespace, by date or one error; names the scope".
- `proposalEntityApplicationErrors`: "Application errors"
- `errorDeleteNamespaceVerb`: "Delete the errors in"
- `errorDeleteDateVerb`: "Delete the errors of"
- `errorDeleteOneVerb`: "Delete error"
- `errorDeleteNamespaceConsequence`: "Deleting removes every application error this namespace has
  logged, on every date, and everything each one captured. Errors logged after you confirm are
  kept. This cannot be undone."
- `errorDeleteDateConsequence`: "Deleting removes every application error this namespace logged on
  this date, and everything each one captured. Errors logged after you confirm are kept. This
  cannot be undone."
- `errorDeleteOneConsequence`: "Deleting removes this application error and everything it
  captured. This cannot be undone."

Reused keys: `actionDelete`, `formTypedNameConfirm`, `formTypedNameMismatch`,
`commandBoxGroupActions`, `privilegeSelectRowFirst`, `proposalResidue`, `tableChangeDeleted`,
`errorLogRefused*`. The row menu's `aria-label` reuses `commandBoxGroupActions`, as `data-table.ts`
does.

**Merge notes:**

- `Prohibited.cls :311-312` and `:680-688` still say "by-namespace". They are contended, so they are
  left as they are (the DW-1563 precedent).
- The `ToolWrite` ErrorDelete leg.
- The `screen-mirror.test.mjs` pin.

**Consumes:**

- 5.13: the tool, the port, the seeds and the principal.
- 2.12: the drill.
- 7.1: the route and the dialog.
- 7.6: the typed-name mechanism.
- 7.8: the pattern of a bespoke page hosting actions.

**Consumed-by:** none. `ErrorDeleteMint` is this tool's own lever. **Ledger inbox:** none.

## Verification

Writes happen only on `ocupilot-ci` (web 52776), and only to errors seeded in `USER`. Run one test
class per call and never re-submit. No container is stopped, removed or recreated.

**Targeted (loop):**

- `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.ErrorDeleteScope`.
  Then run one call each for `ErrorLog`, `ErrorLogWire`, `ToolWrite`, `Descriptor` and
  `ReadTool`.
- `ErrorDelete` is armed and runs in CI. Locally, run its new legs through a temporary unarmed
  subclass on `ocupilot-ci`, then delete that subclass (7.8 precedent).
- `cd ui && npm run test:tools && npm run test:components`.
- Rebuild the bundle: `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`.
  Then run
  `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci node --test --test-concurrency=1 browser/error-log-actions.browser-spec.mjs browser/error-log.browser-spec.mjs browser/error-log-delete.browser-spec.mjs`.
  Browser specs that read a secondary read must wait for it.
- `uv run scripts/check-objectscript.py`.
- Rule 19 mutations. Record one per AC.
  - AC1: `ErrorDelete` with `SCREENACTIONS ""`. Expected red: the browser spec and the screen legs.
  - AC2: the port `DELETE` calls `DeleteByDate` for a date scope. Expected red: the later-error
    survival assertion. Then drop `time` from the entries. Expected red: the reuse leg.
  - AC3: the store builds the key from the route namespace. Expected red:
    `error-log.page.spec.ts`.
  - AC4: `ArgumentPairs` passes the whole id. Expected red: the principal leg's `failedPair`.
  - AC5: remove the `errorNumber`-needs-`date` refusal. Expected red: `ErrorDeleteScope`.

**Recorded (implement, `ocupilot-ci`).** ObjectScript mutations were applied to the
`/tmp/ocupilot-ci/src` copy only, the package reloaded, the class run singly, then the copy
restored from the worktree (`diff -r` identical) and reloaded; client mutations were applied in the
worktree and restored from a backup (`shasum` identical). `ErrorDelete` ran through a temporary
unarmed subclass, deleted afterwards.

- `mutation: ErrorDelete SCREENACTIONS "" -> red: ErrorDelete's three screen legs (run 8442) and error-log-actions.browser-spec.mjs 3/3 (AC1)`
- `mutation: LogSourcePort delete calls DeleteByDate for a date scope -> red: ErrorDelete.TestAnAgentDeleteByDateLeavesAnErrorLoggedAfterTheProposal, the later error gone (run 8440) (AC2)`
- `mutation: drop time from ErrorIdRows and SurvivingIdRows -> red: ErrorDelete.TestANumberReusedAfterTheDateWasEmptiedRefusesTheConfirm, the confirm succeeds (run 8441) (AC2)`
- `mutation: selectionKey takes the route's ns for the dates level -> red: error-log.page.spec.ts AC3 leg (AC3)`
- `mutation: ArgumentPairs passes the whole id -> red: ErrorDeleteScope.TestArgumentPairsOnACompositeAreItsNamespacesPairs (run 8438); the principal leg stays green (run 8439), because the port's own gate refuses the same pair with the same envelope (AC4)`
- `mutation: delete ErrorDeleteMint's errorNumber-needs-date refusal -> red: ErrorDeleteScope.TestTheMintRefusesAMalformedScopeBeforeAnyRead (run 8436) (AC5)`
- `mutation: applyDeleted compares the whole id -> red: error-log.page.spec.ts composite deleted-event leg (Integration AC)`
- `mutation: command-bar bindStore returns early for every read-less screen -> red: command-bar.spec.ts Story 7.10 leg`
- `mutation: SCOPED_TARGETS without the log's entry -> red: screen-action-handler.spec.ts Story 7.10 scope leg`
- `mutation: ErrorIdRows walks every date for a date scope -> red: ErrorDeleteScope.TestThePortNarrowsToADateOrOneErrorAndRefusesOneItDoesNotHold, DateList read twice (run 8446) (review)`
- `mutation: ArgumentPairs passes the whole id -> red: ErrorDeleteScope.TestTheRouteGateRefusesEveryScopeShortOfItsWritePair, 2- and 3-part scopes let through (run 8446) (AC4, review)`
- `mutation: drop syncSelection's detail branch -> red: error-log.page.spec.ts detail-level Delete leg (review)`

Green after restore: `ErrorDeleteScope` 7/0 (run 8437), `ErrorDelete` 15/0 via the subclass (run
8443), `ToolWrite` 29/0 (8427), `Descriptor` 50/0 (8431), `ErrorLog` 15/0 (8432), `ErrorLogWire` 7/0
(8433), `ReadTool` 27/0 (8434), `ToolRoundTrip` 2/0 (8435); `test:tools` 1,330/0;
`test:components` 905/0; browser trio 9/9 on the redeployed bundle; initial bundle 1,134,019 B,
under the 1181kB warning, so no re-base.

**Once, before `dev_complete`:**

- Run the full ObjectScript sweep on `ocupilot-ci`, per class, and take the totals from the
  numeric-run-index probe.
- Run `bash scripts/smoke.sh --container ocupilot-ci --user _SYSTEM --password SYS`.
- Do not run the full browser suite locally (Rule 29).

## Auto Run Result

Status: done
Blocking condition: none

**Change.** `logs.applicationerrors.delete` takes a scope, which is a prefix of the error's composite
id: the namespace, the namespace and date, or the namespace, date and number. `ErrorDeleteMint` (new)
joins the agent's `namespace`, `date` and `errorNumber` into that id, and refuses `errorNumber` without
`date`, or any argument that contains U+0001. `LogSourcePort` parses the id, narrows `ENUMERATE` to
the scope (404 `LOG.DATE` or `LOG.ENTRY` when the scope is absent), and records each entry's `Time`.
It deletes only through `DeleteByError`. `ArgumentPairs` gates on the id's own namespace.
`LogErrorList` declares one `delete` row action. The error log page hosts it on every drill level:
a row menu, a typed-name dialog and a refusal banner. The handler picks the verb and the
consequence from the part count, the command bar follows a screen that has no read, and
`displayEntityId` renders a composite id as `a › b › c`.

**Files.**

- Server: `Port/LogSourcePort.cls`, `Screen/Tool/ErrorDelete.cls`, `Screen/Tool/ErrorDeleteMint.cls`
  (new) and `Screen/Descriptor/LogErrorList.cls`.
- Client: `error-log.page.ts`, `error-log.store.ts`, `screen-action-handler.ts`, `command-bar.ts`,
  `entity-id.ts`, `toasts.ts`, `example-proposal.ts` and the regenerated `screens.generated.ts`.
- Tests: `ErrorDeleteScope` (new) with its helper `ErrorDeleteScopeTool`; the `ErrorDelete` legs; the
  `ToolWrite`, `Descriptor` and `screen-mirror` roster rows; the page, handler and command-bar specs;
  `entity-id`, `toasts` and `example-proposal`; the new `error-log-actions.browser-spec.mjs`; and the
  header lists in `error-log.browser-spec.mjs`.

**Review.** The first pass logged 17 findings: 3 medium, 7 low and 7 false. It patched two medium
entries: the date-scope narrowing assertion, and the route-gate leg for AC4, which also answers the
"short of the pair" finding. It patched one low, the detail-level page leg. Every patch was test-only
and was observed red under its mutation. Three lows are in `deferred:`, and the rejections carry their
reasons in the Triage Log. `followup_review_recommended: false`: no patch changed product code, so
there is no unverified risk to name. This pass re-ran no review layer; it checked that the patches
were present and green.

**Verification** (on `ocupilot-ci`, the source rsynced from the worktree and `LoadDir` returned OK
with 0 errors):

- ObjectScript unit tests. The disk roster (`testClassesOnDisk`) has 185 classes:
  - **From the recorded sweep** (runs 8443–8610): 159 classes, 1,436 tests, 0 failed. One skip is
    by design: `ProhibitedRoute`'s auditing method, `Status=2`.
  - **The four armed classes** (`AuditingUpdate`, `ErrorDelete`, `ProcessControl`, `TaskResume`)
    refuse on this reused throwaway and run in CI. `ErrorDelete`'s legs ran 15/0 through a
    temporary subclass (run 8443), which was later deleted.
  - **Missed by the sweep and run now**, one class per call (runs 8612–8633): 22 classes, 240 tests,
    1 failed. The failure is `WireSecurityRead`'s 1,000-row task-history check, DW-1554, which is
    not this story's.
  - **Re-run for the review patches**: `ErrorDeleteScope` 8/0 (run 8611).
- `smoke.sh --container ocupilot-ci`: 49 of 49 passed.
- `test:tools`: 1,330 of 1,330 passed.
- `test:components`: 906 of 906 passed.
- `check-objectscript.py`: 0 problems in 642 files.
- `npm run build`: the initial total is 1.13 MB, under the 1181kB warning, so there was no DW-1166
  re-base.
- The rebuilt bundle was redeployed to `ocupilot-ci`, and the story's three browser specs passed 9
  of 9.

**Footprint.** The story lies inside Epic 7's footprint. Epic 8 also modified three of its files
(`ToolWrite.cls`, `screen-mirror.test.mjs` and `screens.generated.ts`), and the story adds only its
own members to them (roster rule, 2026-09-23).

**Residual risks.** The three lows in `deferred:`. The stale "by-namespace" sentences in
`Prohibited.cls` are left for the merge (see Merge notes).
