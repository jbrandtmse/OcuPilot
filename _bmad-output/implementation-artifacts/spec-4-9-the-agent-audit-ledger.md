---
title: 'Story 4.9 - The agent audit ledger'
type: 'feature'
created: '2026-09-18'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
warnings: ['oversized']
owned_ledger: ['DW-448']
deferred: []
---

<intent-contract>

## Intent

**Problem:** A turn makes provider calls and tool calls and leaves only a progress trail that dies with the
turn (`Limits.RETENTIONSECONDS` 900 s). Nothing on the instance says afterwards who asked, on which screen,
with which arguments, under which IRIS resource, at what token cost - so "what did the agent do" is only
answerable by correlating a live poll with the vendor audit database by hand.

**Approach:** One durable row per provider call and per tool answer, in OcuPilot's protected state
(AD-9), written on the agent's own path from the frames that already hold every value; redacted by
declaration before the name-pattern backstop runs; bounded per turn with overflow counted; read back
through one route whose cross-user gate is the resource set recorded on each row.

## Boundaries & Constraints

**Always:**

- Storage is `OcuPilot.Kernel.State.Ledger` on `Kernel/State/Base` - protected database, `%DB_OCUPILOT`,
  escalation only inside each `Guarded*` frame, `GuardedSaveIfCurrent` for every update (AD-9, Conventions
  "Concurrent writes"). 28 characters, inside the 29-character `%Persistent` cap.
- The ledger never fails a turn. Every writer call is `Do`-and-log (`Fault.LogRaw("ledger", ...)`); its
  `%Status` is never propagated into the turn's outcome (AD-15 failure posture, Conventions "Logging").
- Redaction runs in one order and only ever adds: (1) drop-by-declaration from the tool's own
  `SecretArguments`, (2) `Kernel.Audit.Log.Redact`'s name pattern over the result. Layer 2 can add a
  `[redacted]`; it can never restore one (AD-3, Conventions "Secrets").
- Every bound is a named `Parameter` on `Kernel/Agent/Limits.cls`, read with
  `$Parameter(pLimitsClass, ...)` so a test subclass narrows it (AD-41).
- Timestamps are ISO-8601 UTC via `$Translate($ZDateTime($ZTimeStamp, 3, 1), " ", "T") _ "Z"`.
- The cross-user gate is evaluated in the caller's own process at read time, never cached, through
  `Screen.Gate.EvaluatePairs` (AD-8). It lives in `Kernel/Audit/Ledger.cls`, not in any screen (AD-46).
- User references are weak: a `%String` column, matched `%EXACT`, never a foreign key (AD-37).
- New API codes go in `Api/Error.cls` with a paired `REASON*` parameter, a `LedgerCodes()` list and a
  `ReasonForLedger()` arm (AD-12, AD-39).

**Never:**

- Never a screen descriptor, a read tool, a screen-mirror entry or a `core/strings.ts` value. The ledger
  viewer, its filters and its side-bar entry are Story 14.x / FR-71 (EXPERIENCE.md `:152`, `:169`), and
  AD-22 says the ledger is configuration, not a governed tool - the agent must not be able to read it.
- Never a new top-level package under `src/OcuPilot/` (`Install/Roster.cls` `XData Manifest` fixes the
  seven, and `ipm-manifest.mjs` compares byte for byte).
- Never a `Ledger` arm on `Turn.GuardedDelete`'s cascade, and never a retention sweep over ledger rows in
  this story - rows outlive their turn and their user (AD-37). Retention is Story 14.4's.
- Never touch `Loop.Boundary`'s check order, its per-boundary re-read of live grants, or
  `Turn.GuardedAbandonForUser`'s `%EXACT(UserName)` scoping - they are what invalidates a deleted user's
  work and this story only has to not undo them.
- Never store a prompt, a message body or a tool result body. "Arguments" for a provider row means the
  call's own parameters; transcripts are Story 14.4.
- Never build SQL by concatenating a caller value; the new bounded helper binds (AD-21).
- Never hand-write a Storage section, and do not move `Installer.SCHEMAVERSION`: a new table has no
  pre-existing rows to reinterpret, and `Turn.ContextRoute` reads `""` on every row written before it
  (Conventions "When `SCHEMAVERSION` moves", `Step.cls:37-39` precedent).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Provider call completes | `Loop.Run` after the usage copy | one `llm` row: user, ISO-8601 UTC, turn key, seq, provider key, model, iteration, context route, `requestTokens`/`responseTokens`, `status` `ok`/`error`, `code` | write failure logged `ledger`, turn unaffected |
| Tool answered | `Dispatch.AnswerOne` common exit | one `tool` row: canonical tool name, target, redacted arguments, `status`, `code`, `requiredPairs` = declared pairs UNION argument-derived pairs | as above |
| Tool refused before dispatch | `Loop.AnswerTools` boundary stop / reply-budget refusal | one `tool` row with `status` `stopped`/`error` and the refusal code; pairs empty | as above |
| Client-fulfilled call settles | `Loop.AnswerClientCall` settle / refuse / lapse | one `tool` row carrying the settled outcome code and the target screen's argument-derived pairs | as above |
| Declared secret argument | tool declares `Value` secret; call sends `{"Value":"s3cr3t"}` | row's `arguments` reads `"Value":"[redacted]"`; the literal appears nowhere in the row | - |
| Undeclared credential-named argument | `{"apiKey":"..."}`, tool declares no secrets | pattern backstop redacts it | - |
| Tool declares nothing | a tool class with no `SecretArguments` override | `Registry` refuses to advertise it, naming the missing declaration | refusal, not a silent "no secrets" |
| Turn exceeds the row cap | more than `LEDGERMAXROWS` calls | later calls are counted, not stored; one `overflow` row per turn with `Dropped` = n | - |
| Arguments over the size bound | argument JSON longer than `LEDGERROWMAXLENGTH` | cut to the bound, last character U+2026, `argumentsTruncated` 1 | - |
| Self read | `GET /agent/ledger` | 200, the caller's own rows, newest first, bounded | - |
| Cross-user read, admin holds every pair | `?user=<other>` with `OcuPilotAdmin:USE` and the rows' pairs | 200, the rows, `rowsWithheld` 0; one `LedgerRead` audit event | - |
| Cross-user read, admin lacks a row's pair | as above, pair not held | 200, that row omitted, `rowsWithheld` incremented | - |
| Cross-user read, caller not an OcuPilot administrator | `?user=<other>` without `OcuPilotAdmin:USE` | 403 `forbidden` / `AUTH.NOPRIVILEGE`, `detail.failedPair` `OcuPilotAdmin:USE` | - |
| Bad window / maxRows / user | `windowHours=9999`, `maxRows=0`, `user` failing the name shape | 400 `bad_request` / `LEDGER.WINDOW.INVALID`, `LEDGER.MAXROWS.INVALID`, `LEDGER.USER.INVALID` | one envelope |
| Subject user deleted | rows referencing a name the instance no longer holds | rows still read, name rendered as recorded | never a failed read |
| Store unreadable | guarded read returns an error status | 503 `unavailable` / `LEDGER.UNAVAILABLE` | one envelope, detail logged |

</intent-contract>

## Code Map

- `src/OcuPilot/Kernel/State/Base.cls` -- `BoundedWhere` `:636` (returns fragment text + pushes the cutoff
  onto `pParams` **last**, so pass it an **empty** array and push predicate values after); every executor is
  fixed-arity scalar (`GuardedIdsWhere` `:679`, `...TwoParam` `:704`, `...NoParam` `:729`) - the arity wall
  behind DW-448. `GuardedSaveIfCurrent` `:156`, `IsStaleSave` `:204`, `GuardedOpenId` `:233`. SQLCODE -400
  trap documented `:530-540`: passing an unused parameter raises it, so a zero-argument branch is required.
- `src/OcuPilot/Kernel/State/Turn.cls` -- `NewKey()` `:525` (32 hex, the key-minting idiom to copy);
  `GuardedForOwner` `:392` (`%EXACT` on both key and user, `pFound` 0 for unknown and for another user's
  alike - the 404-not-403 shape); `GuardedSweep` `:488` and `GuardedDelete` `:507` (the cascade that must
  **not** gain a ledger arm); `GuardedAbandonForUser` `:354`; `Cap(...)` used by `RedactedArguments`.
- `src/OcuPilot/Kernel/State/Step.cls` -- `GuardedAppend` `:75` with `Output pStored` - the
  "counted, not stored" idiom the overflow row copies; `FailedPair` `:59` is the `resource:permission`
  string precedent; `:37-39` is the "added with no `SCHEMAVERSION` move" precedent.
- `src/OcuPilot/Kernel/Agent/Dispatch.cls` -- `AnswerOne` `:171`; gate order `:195/:207/:213/:228/:242/:255/
  :264/:277`; `tPairs` `:242`, `tArgumentPairs` `:264` (note `tResolved` is reused - capture the first);
  common exit `:331`; `ResolveClientCall` `:349` (has **no** `pKey`); `RedactedArguments` `:540` (public,
  already `Log.Redact` + `Cap` + U+2026 - reuse it verbatim so ledger and step strings reconcile);
  `TargetOf` `:515`.
- `src/OcuPilot/Kernel/Agent/Loop.cls` -- `Run` `:92`, context consumed `:120-144` (the **only** place the
  screen-context route exists today), provider call `:175` with `tResponse.RequestTokens`/`.ResponseTokens`
  `:177-178`; `Boundary` `:228` (check order; row 6 `HoldsAnyResource` is the deleted-user path);
  `AnswerTools` `:363` with the two pre-dispatch refusals `:387-405` and `:407-433`;
  `AnswerClientCall` `:516` settle `:658`, refuse `:539`, lapse `:565`.
- `src/OcuPilot/Kernel/Agent/Limits.cls` -- 16 named bounds, `Parameter NAME As %Integer = n` with a
  unit-and-consequence doc comment; consumed only as `$Parameter(pLimitsClass, "NAME")`.
- `src/OcuPilot/Screen/Tool/Base.cls` -- `TOOLNAME` `:26`, `KIND` `:30`, `FULFILMENT` `:41`, `DESCRIPTION`
  `:44`, `PrivilegePairs` `:71`, `ArgumentPairs` `:82` - the shape the new `SecretArguments` copies.
- `src/OcuPilot/Screen/Tool/Registry.cls` -- advertise-time refusals `:250` (blank description) and `:255`
  (no result schema) - the pattern for refusing an undeclared tool; wrappers `RequiredPairs` `:387`,
  `ArgumentPairs` `:409`; `SCHEMAKEYWORDS` `:50` admits no classification keyword, which is why the
  declaration is a method and not a schema key.
- `src/OcuPilot/Screen/Tool/Navigate.cls` -- `:111` declares **no** static pairs and resolves everything in
  `ArgumentPairs` `:123`; a row recording only declared pairs would record nothing for `shell.screen.open`.
- `src/OcuPilot/Screen/Gate.cls` -- `EvaluatePairs(pPairs As %List, Output pFailedPair) As %Boolean` `:109`
  (evaluates the **current** process, `$System.Security.Check`), `HoldsPrivilege` `:143`.
- `src/OcuPilot/Screen/Context.cls` -- `Build` `:37`; the secret exclusion `:64-69` is all-or-nothing and
  descriptor-keyed, and the class header `:4-8` forbids it naming `Kernel/Agent` - so it is **applied**
  upstream, never re-invoked by the ledger.
- `src/OcuPilot/Kernel/Audit/Log.cls` -- `Redact` `:117` (copy, never mutates; array indices preserved;
  never throws), `IsCredentialName` `:172`, `CREDENTIALSUFFIXES` `:53`, `CREDENTIALEXACTNAMES` `:63`,
  `REDACTED` `:42`; `:68-75` states the backstop-only contract this story completes.
- `src/OcuPilot/Kernel/Audit/Event.cls` -- `Roster()` `:64`, `Names(pSuffix)`, `Description(pBaseName)`
  `:86`, `Record(...)` `:136` (no namespace switch, never throws, status ignored by the caller); a base name
  with no `Description` arm self-names.
- `src/OcuPilot/Install/Installer.cls` -- `Names()` `:140`/`:163-181` resolves the roster in the install
  namespace; `EnsureAuditEvents` `:2810` runs inside the `%SYS` window, `Security.Events.Exists` then
  `Create(source, type, name, description, 1, 0)`, repairs a disabled event; uninstall `:3707-3715` deletes
  roster-driven. A fourth name costs no installer edit.
- `src/OcuPilot/Api/Router.cls` -- `UrlMap` `:64-100`; ordering rules `:50-63`; `Call=` targets are thin.
- `src/OcuPilot/Api/Conversation.cls` -- the owner-scoped read shape: `CallerUsername()`, store answers
  ownership, `Error.ReasonFor*` decoration in the API layer (the kernel must not name `OcuPilot.Api`).
- `src/OcuPilot/Api/Error.cls` -- slug enum, code families, `TurnCodes()`/`ReasonForTurn()` as the model for
  `LedgerCodes()`/`ReasonForLedger()`, `Render` `:1134`, `RenderInternal` `:1184`.
- `src/OcuPilot/Screen/Read.cls` -- `Execute`'s cap+1 truncation idiom (ask for `maxRows + 1`, set
  `truncated`), which the ledger read copies instead of a second COUNT scan.
- `src/OcuPilot/Test/TurnStore.cls:244` -- `TestEveryTurnCodeHasASentence` enumerates
  `%Dictionary.CompiledParameter` for `parent = 'OcuPilot.Api.Error'`; the `LEDGER.*` family needs its own
  copy because that test filters on `TURN`.
- `src/OcuPilot/Test/AuditEvent.cls` -- `RowsCarrying()` reads `%SYS.Audit` with `%NOINDEX` on the three
  event predicates and a `UTCTimeStamp` lower bound (the indexes refresh ~60 s late); armed by
  `OCUPILOT_ALLOW_AUDIT_EVENTS`; `TestADeletedRegistrationDropsTheRowAndReportsIt` is the negative leg to
  extend. Teardown re-installs and fails if a triple is missing.
- `src/OcuPilot/Test/TurnWireFixture.cls` -- `Resources(pOperate)`, `EnsurePrincipal`,
  `SetRoleResources`, `DeletePrincipal`, `Sweep(pTags)` (returns a string naming every survivor).
- `src/OcuPilot/Test/TurnLimits.cls` -- the narrowing-subclass pattern; `TurnFixture.Age(key, prop, n)`
  ages a stored timestamp for bounds that cannot be waited out.
- `ui/tools/strings.test.mjs` -- forward, converse and **count-equality** assertions over
  `ui/src/app/core/strings.ts` against EXPERIENCE.md's Fixed strings table; adding a literal to one file
  only reddens two or three assertions. This story adds none.

## Tasks & Acceptance

**Execution:**

1. `src/OcuPilot/Kernel/State/Base.cls` -- add `GuardedIdsBounded(pSelectPrefix, pFragment, pSuffix,
   pMaxRows, ByRef pParams As %DynamicArray, Output pIds) As %Status [ Private ]`, closing **DW-448**.
   `pSelectPrefix` and `pSuffix` are call-site literals; the method joins
   `pSelectPrefix _ " WHERE " _ pFragment _ " " _ pSuffix` **inside `Base`** so no subclass ever
   concatenates (rule 21). Binding order is fixed and documented: `pMaxRows` first, then `pParams` members
   in array order - so the literal spells `SELECT TOP ?` before the fragment's placeholders. Copy the
   escalation frame, `Kill pIds` + `pIds($Increment(pIds)) = tRS.%GetData(1)`, the
   `"GuardedIdsBounded failed: SQLCODE=..."` error text and `[ Private ]` from `GuardedIdsWhere` `:679`.
   Branch to a no-argument `%ExecDirect` when the argument count is zero (SQLCODE -400, `:530-540`).
   Header records the `BoundedWhere` push-order contract: pass an **empty** `pParams`, push predicate values
   after, cutoff lands at index 1.
2. `src/OcuPilot/Kernel/State/Ledger.cls` -- new `%Persistent` on `Kernel/State/Base`. Properties:
   `LedgerKey` `%String(MAXLEN=64)`, `UserName` `%String(MAXLEN=160)`, `LoggedAt` `%String(MAXLEN=32)`,
   `TurnKey` `%String(MAXLEN=64)`, `Seq` `%Integer`, `Kind` `%String(MAXLEN=16)` (`llm`|`tool`|`overflow`),
   `Name` `%String(MAXLEN=128)` (canonical tool name or provider key), `Model` `%String(MAXLEN=128)`,
   `Route` `%String(MAXLEN=512)`, `Target` `%String(MAXLEN=256)`, `Arguments` `%String(MAXLEN=4096)`,
   `ArgumentsTruncated` `%Boolean`, `Status` `%String(MAXLEN=16)` (`ok`|`error`|`stopped`),
   `Code` `%String(MAXLEN=64)`, `RequestTokens`/`ResponseTokens` `%Integer`,
   `RequiredPairs` `%String(MAXLEN=512)` (canonical `res:perm` comma-joined, sorted, de-duplicated - a
   scalar like `Step.FailedPair`, not a `list Of`), `Dropped` `%Integer [ InitialExpression = 0 ]`.
   Indices: `LedgerKeyIdx On LedgerKey [ Unique ]`; `LedgerUserTimeIdx On (UserName, LoggedAt)` (the first
   user+time index in the package - the windowed read needs it); `LedgerTurnSeqIdx On (TurnKey, Seq)
   [ Unique ]`, the overflow row taking `Seq` 0. Methods: `GuardedAppend(..., pLimitsClass, Output pSeq,
   Output pStored)` (refuses past `LEDGERMAXROWS`, `pStored` 0), `GuardedCountOverflow(pTurnKey)`
   (open-or-create the `Seq` 0 row, `Dropped = Dropped + 1`, `GuardedSaveIfCurrent` on the version just
   read), `GuardedIdsForWindow(...)` over `BoundedWhere` + `GuardedIdsBounded`,
   `GuardedRow(pId, Output pValues)`, `GuardedDroppedFor(pUser, pWindow, Output pCount)`. Names nothing
   outside `OcuPilot.Kernel.State`. No Storage section.
3. `src/OcuPilot/Kernel/State/Turn.cls` -- add `ContextRoute` `%String(MAXLEN=512)`, written once when the
   turn is begun from the same `context.route` the job already holds. Safe default `""`; no
   `SCHEMAVERSION` move, reasoning recorded at the property.
4. `src/OcuPilot/Screen/Tool/Base.cls` -- add
   `ClassMethod SecretArguments(pDescriptor As %String = "", Output pDeclared As %Boolean) As %List`,
   returning the top-level argument property names that are secret. Base sets `pDeclared = 0` and returns
   `""`; a method rather than a schema keyword because `SCHEMAKEYWORDS` `:50` admits none and a descriptor-
   driven tool must be able to vary per descriptor.
5. `src/OcuPilot/Screen/Tool/Registry.cls` -- add the wrapper `SecretArguments(pTool, Output pDeclared)`
   mirroring `RequiredPairs` `:387`, and refuse to advertise a tool whose `pDeclared` is 0, with a refusal
   naming the missing declaration - same shape as the blank-description refusal `:250`.
6. `src/OcuPilot/Screen/Tool/*.cls` (`Read`, `Navigate`, `ErrorRead` and every other concrete tool) -- add
   the one-line declaration. Most return `""` with `pDeclared = 1` ("declared: none"); none of today's read
   tools takes a secret argument.
7. `src/OcuPilot/Kernel/Agent/Limits.cls` -- add three bounds in the house style:
   `LEDGERMAXROWS = 200`, `LEDGERROWMAXLENGTH = 4096`, `LEDGERVIEWMAXROWS = 200`.
8. `src/OcuPilot/Kernel/Audit/Ledger.cls` -- new. The ledger's one public face.
   - `RecordProviderCall(pTurnKey, pUser, pRoute, pProvider, pModel, pIteration, pRequestTokens,
     pResponseTokens, pStatus, pCode, pLimitsClass)`.
   - `RecordToolCall(pTurnKey, pUser, pRoute, pName, pTarget, pInput, pDeclaredPairs, pArgumentPairs,
     pSecretNames, pStatus, pCode, pLimitsClass)`.
   - `RedactArguments(pInput, pSecretNames, pMaxLength, Output pTruncated)`: layer 1 replaces each declared
     name's value with `Log.#REDACTED` on a **copy**; layer 2 runs `Dispatch.RedactedArguments` (which is
     `Log.Redact` + `Cap` + U+2026) over the result. Returns the redacted-key set alongside the string and
     asserts the declared set is a subset of it, so layer 2 can only add.
   - `PairsToString(pPairs)` / `StringToPairs(pText)` - sorted, de-duplicated, round-trip tested.
   - `ViewForUser(pCaller, pSubject, pWindowHours, pTurnKey, pMaxRows, Output pView, Output pFault)`:
     resolves the subject (default the caller); for another subject requires `OcuPilotAdmin:USE` through
     `Screen.Gate.HoldsPrivilege` and refuses with `detail.failedPair` otherwise; reads ids cap+1 through
     `State.Ledger`; **outside every escalated frame** evaluates each row's `RequiredPairs` with
     `Screen.Gate.EvaluatePairs`, omitting a row the caller cannot hold and counting it in `rowsWithheld`;
     sums `rowsDropped`; emits the `LedgerRead` audit event once per cross-user read, after the read
     resolved, ignoring its status.
   Every writer entry point returns `%Status`; no caller propagates it.
9. `src/OcuPilot/Kernel/Audit/Event.cls` -- add `Parameter EVENTLEDGERREAD = "LedgerRead"`, its entry in
   `Roster()` and its `Description()` arm ("OcuPilot agent ledger read of another user's rows"). Confirm the
   `EntityType` member `user` (already in `Kernel/EntityType.cls` `:28`) as `Record`'s `pType`, with the
   subject user's name as the id and `instance` as the scope. No installer edit: `EnsureAuditEvents`
   `:2810` and uninstall `:3707` are roster-driven.
10. `src/OcuPilot/Kernel/Agent/Loop.cls` -- capture `tContextRoute` once where the context is consumed
    (`:120-144`); pass it to `Dispatch.Answer`, to `AnswerClientCall` and to the two pre-dispatch refusal
    sites (`:387-405`, `:407-433`), each of which writes its own `tool` row. Write the `llm` row
    immediately after the usage copy `:177-178`, carrying `tResponse.HttpStatus` into `Status`/`Code`.
    Read the provider key the way `IterationCap` `:314-327` already reads the definition, so no property is
    added to `Provider/Response.cls`.
11. `src/OcuPilot/Kernel/Agent/Dispatch.cls` -- add `pRoute` to `Answer`/`AnswerOne` and `pKey` + `pRoute`
    to `ResolveClientCall`. In `AnswerOne`, capture the first `tResolved` before `:264` overwrites it, and
    write one row at the common exit `:331`, `$Get`-guarding `tPairs`/`tArgumentPairs` (undefined on an
    early refusal). The client-fulfilled row is written from `Loop.AnswerClientCall`'s settle, refuse and
    lapse points, where the outcome is known.
12. `src/OcuPilot/Api/Ledger.cls` + `src/OcuPilot/Api/Router.cls` -- `GET /agent/ledger` → `AgentLedger`,
    placed beside `GET /agent/restraint` (two-segment literal; no `:param` conflict). Handler is thin:
    `%request.Get` for `user`, `windowHours`, `turnKey`, `maxRows`; validate shape only; delegate to
    `Kernel.Audit.Ledger.ViewForUser`; render through `Response.JSON` or `Error.Render`. Response:
    `{rows[], rowsSent, truncated, rowsWithheld, rowsDropped, windowHours}`.
13. `src/OcuPilot/Api/Error.cls` -- add `LEDGER.WINDOW.INVALID`, `LEDGER.MAXROWS.INVALID`,
    `LEDGER.USER.INVALID`, `LEDGER.UNAVAILABLE` with paired `REASON*` parameters, plus `LedgerCodes()` and
    `ReasonForLedger()` mirroring the `TURN`/`TOOL` families.
14. `src/OcuPilot/Test/Ledger.cls`, `src/OcuPilot/Test/LedgerWire.cls`,
    `src/OcuPilot/Test/LedgerLimits.cls` (narrowing subclass, `LEDGERMAXROWS = 2`),
    `src/OcuPilot/Test/LedgerToolProbe.cls` (a fixture tool declaring `Value` secret) and one fixture tool
    declaring nothing -- the suites in `## Verification`. Class headers state blast radius; probe rows carry
    a shared prefix; `OnAfterOneTest` asserts nothing survives; every test method carries its `Mutation:`
    line; no property name begins with `Test`.
15. `src/OcuPilot/Test/AuditEvent.cls` -- one added method for the `LedgerRead` round trip and its
    deleted-registration negative leg. The existing roster-driven tests pick the new name up unchanged.

**Acceptance Criteria:**

- **AC1** Given a turn that makes one provider call and answers one tool call, when it ends, then
  `GET /agent/ledger?turnKey=<key>` returns two rows - an `llm` row carrying the provider key, the model and
  non-zero token figures, and a `tool` row carrying the canonical tool name, the screen-context route, the
  redacted arguments and `status` `ok` - each with the caller's name and an ISO-8601 UTC `loggedAt`.
- **AC2** Given a tool call, when its row is written, then `requiredPairs` carries the declared pairs
  unioned with the argument-derived pairs; for `shell.screen.open`, whose pairs are argument-derived only,
  the row still carries the target screen's pairs.
- **AC3** Given a tool declaring `Value` secret, when a call passes `{"Value":"s3cr3t"}`, then no
  serialization of the row contains `s3cr3t`; given an undeclared argument named `apiKey`, it is redacted by
  the backstop; and given a tool that declares nothing, the registry refuses to advertise it.
- **AC4** Given a turn making more calls than `LEDGERMAXROWS`, when it ends, then exactly `LEDGERMAXROWS`
  rows are stored, one `overflow` row carries the count of the rest, and the view reports `rowsDropped`;
  given arguments longer than `LEDGERROWMAXLENGTH`, the stored value is cut to the bound, ends U+2026 and
  sets `argumentsTruncated`.
- **AC5** Given `LedgerRead` is on `Event.Roster()`, when install has run, then it is registered and enabled
  in `%SYS` and a cross-user read lands exactly one audit row; when its registration is deleted, the same
  read still succeeds and lands none - proving the registration, not the emission, is what makes it land.
- **AC6** Given user B holds `OcuPilotAdmin:USE` but not a resource user A's row recorded, when B reads
  `?user=A`, then that row is absent and `rowsWithheld` counts it; granting B the resource makes the row
  appear; a caller without `OcuPilotAdmin:USE` asking for another user gets 403 `AUTH.NOPRIVILEGE` with
  `detail.failedPair` `OcuPilotAdmin:USE`; a caller always sees their own rows.
- **AC7** Given a terminal turn swept by `Turn.GuardedSweep`, when the sweep completes, then the turn and
  its steps are gone and its ledger rows still read; given the user named by those rows is deleted mid-turn,
  the turn abandons with `TURN.ABANDONED.PRIVILEGE` and the rows still read.
- **AC8 (Integration, Rule 1)** Given consumer `OcuPilot.Api.Ledger`, which reads from
  `OcuPilot.Kernel.Audit.Ledger`, when a real least-privileged principal calls
  `GET /api/ocupilot/agent/ledger` over the wire after a turnprobe turn, then it receives that turn's rows
  with their recorded pairs - asserted at the HTTP tier, never against the store's internals.
- **AC9 (DW-448)** Given `BoundedWhere`'s fragment and its parameter array, when the ledger's windowed read
  runs, then it executes through `Base.GuardedIdsBounded` with every value bound; a `user` containing
  `' OR 1=1 --` matches literally and returns no extra row.

## Design Notes

**Governing ADs:** AD-9 (protected storage; the two re-entry rules), AD-3 and the Secrets convention
(schema-driven redaction, pattern as backstop only), AD-8 (call-time privilege, never cached), AD-11
(nothing here becomes instruction; the ledger is never a tool), AD-12/AD-39 (one envelope, machine code),
AD-15 (registration is what makes an event land; emission never fails the operation), AD-21 (bind, never
concatenate), AD-24/AD-36 (bounded reads that report truncation), AD-22 (the ledger is configuration, not a
governed tool), AD-37 (weak references; rows outlive their subject), AD-41 (the ledger is a bounded
resource; overflow is a count), AD-46 (per-user scope, and the gate lives with the ledger).

**Why the gate is not in `Kernel/State/Ledger.cls`.** `check-objectscript.py`'s state-package isolation
refuses a reference to `OcuPilot.Screen` from `Kernel/State`, and AD-9 forbids re-entry from inside an
escalated frame. So the store answers rows as data, including each row's pair string, and
`Kernel/Audit/Ledger.cls` - outside the state package and outside every escalated frame - evaluates them.
That is still "with the ledger rather than with any screen": the gate is a method of the ledger subsystem
and no screen can bypass it.

**Why the declaration must be mandatory.** `Log.Redact` `:68-75` already says a name pattern "cannot see a
wallet secret stored in a field called `Value`". If an undeclared tool meant "no secrets", the schema layer
would be advisory and the pattern would be the real defense - the exact inversion AD-3 forbids. Refusing at
registration makes "declared: none" an act, and it is the same fail-closed posture as the missing-`KIND`
and blank-`DESCRIPTION` refusals already in `Registry`.

**Why a provider row stores parameters, not the prompt.** The screen-context route is its own column, so
"the arguments" for a provider call means the call's own parameters (model, iteration, token figures).
Message bodies and tool-result bodies are transcripts - Story 14.4 - and storing them here would both
duplicate that store and defeat `LEDGERROWMAXLENGTH`. The screen context that entered the turn reached the
row only through the payload `Screen.Context.Build` already produced, so its `secretFields` exclusion
applies with no second projection path.

**Why these numbers.** `LEDGERMAXROWS` 200 is not a new invention: a turn is capped at `MAXITERATIONS` 100
provider calls, and the common shape is one tool answer per iteration, so 200 is "one row per call at the
turn's own ceiling". An ordinary turn therefore never overflows; a turn that returns several `tool_use`
blocks per iteration can, and that is precisely the "unusually chatty" case the AC names.
`LEDGERROWMAXLENGTH` 4096 is four times `SUMMARYMAXLENGTH` (1000), the cap the step's own argument string
already obeys - so a ledger row can never be narrower than the step it reconciles with, and the worst-case
per-turn footprint is bounded at about 800 KB. `LEDGERVIEWMAXROWS` 200 is AD-24's row cap, applied to a
bounded read like any other.

**Consumes:** 4.1 (`Job`/`Loop`/`State.Turn`), 4.2 (`Screen/Tool/Registry`, `Screen/Gate`, `Dispatch`'s gate
chain and `RedactedArguments`), 4.4 (`Screen/Context`'s bounded, secret-excluded payload), 4.5
(`State/Step`'s `pStored` idiom and the tool step whose arguments the ledger must match byte for byte),
4.7 (`Navigate`'s argument-derived pairs and `AnswerClientCall`'s settle points), 4.8
(`Provider/Response`'s token figures and the fault vocabulary), 1.4 (`Installer.EnsureAuditEvents`,
`Event.Roster`).

**Consumed-by:** Story 14.4 - an administrator's transcript read is gated by "every resource that
transcript's tool calls required, as recorded per ledger row", which is exactly the `RequiredPairs` column
and `ViewForUser`'s per-row evaluation this story lands. Story 14.x / FR-71 - the agent audit viewer with
filters by user, screen and date, over this route. Epic 14 also owns ledger retention;
`Agent.RetentionDays` exists and has no consumer today, and this story deliberately does not become one.

**No client surface.** EXPERIENCE.md `:152` and `:169` put the ledger screen in the polish-week column
(FR-71/FR-72), and 4.9's own AC says the gate lives with the ledger "rather than with any screen". So there
is **no new `ui/src/app/core/strings.ts` value and no new EXPERIENCE.md Fixed-strings row**;
`strings.test.mjs`'s count-equality assertion makes a speculative one a two-file change for no user-visible
text. No screen descriptor means no `screen-mirror.mjs` regeneration and no `classic-links.mjs` change; the
classes live inside the existing seven packages, so `Install/Roster.cls` and `module.xml` are untouched.

**owned_ledger:** DW-448 - **addressed**, by task 1 (`Base.GuardedIdsBounded`), with the ledger's windowed
read as its first consumer and AC9/its mutation as the proof. The entry's own evidence line named the arity
wall and rule 21 as the two blocks; the helper removes both by doing the join inside `Base`. Its unstated
third hazard - `BoundedWhere` pushes the cutoff last while the fragment names it first - is settled by
contract (pass an empty array) and pinned by a test.

## Verification

**Commands:**

- `uv run scripts/check-objectscript.py` -- expected: clean over every changed path; in particular the
  29-character cap (`OcuPilot.Kernel.State.Ledger` is 28), the state-package isolation, and the three
  `UrlMap` ordering rules over the new route.
- `uv run scripts/test_check_objectscript.py` -- expected: green.
- Compile through the IRIS MCP tools with **`server: "ocupilot-slot-a"` on every call**. Into the
  throwaway: `rsync -a --delete src/ /tmp/ocupilot-ci/src/` then
  `$System.OBJ.LoadDir("/opt/ocupilot/src", "ck", , 1)` inside `ocupilot-ci`.
- `%UnitTest` classes run **one per message** through
  `node ui/tools/ci-runner.mjs --container ocupilot-ci --class <Class>`, each confirmed in
  `%UnitTest_Result` before the next; never two in one message, never a re-submit on a timeout. Final run,
  in order: `OcuPilot.Test.Ledger`, `OcuPilot.Test.LedgerWire`, `OcuPilot.Test.AuditEvent`,
  `OcuPilot.Test.TurnStore` (mandatory - error codes were added), `OcuPilot.Test.Envelope`,
  `OcuPilot.Test.Routing`, `OcuPilot.Test.Dispatch`, `OcuPilot.Test.ToolRoundTrip`,
  `OcuPilot.Test.ToolNavigate`, `OcuPilot.Test.TurnWire`, `OcuPilot.Test.StateBound`,
  `OcuPilot.Test.Convo`, `OcuPilot.Test.State`, `OcuPilot.Test.AuditRecord`, `OcuPilot.Test.Smoke`.
- From `ui/`: `npm test` (expected unchanged - 940 node assertions plus the vitest files) and
  `npm run build` (expected: the six `prebuild` checkers pass and the initial total stays under the
  780 kB warning; this story adds no client code, so the measured figure must not move).
- `bash scripts/smoke.sh --container ocupilot-ci --user _SYSTEM --password SYS` -- expected: every check
  executed, zero failures; `CheckAuditEvent` reports the new roster entry.

**Falsifiability (Rule 19) - one demonstrated mutation per AC:**

| AC | Pinning test | mutation |
|----|--------------|----------|
| AC1 | `LedgerWire.TestATurnWritesOneProviderRowAndOneToolRow` | delete the `RecordToolCall` call at `Dispatch.AnswerOne`'s common exit -> the `tool` row is absent |
| AC2 | `LedgerWire.TestARowCarriesTheResourceTheToolRequired` | record only `tPairs` and drop `tArgumentPairs` -> `shell.screen.open`'s row reads empty `requiredPairs` |
| AC3a | `Ledger.TestADeclaredSecretIsAbsentFromTheWholeRow` (asserts the literal appears nowhere in the serialized row, not that a field equals `[redacted]`) | remove layer 1 from `RedactArguments`, leaving only `Log.Redact` -> `s3cr3t` appears |
| AC3b | `Ledger.TestThePatternAddsAndTheDeclarationSurvivesIt` | swap the two layers so `Log.Redact` runs first and layer 1 rebuilds from the raw input -> the declared-subset assertion fails |
| AC3c | `Ledger.TestAToolDeclaringNothingIsRefusedAtRegistration` | make `Registry` read `pDeclared = 0` as "no secrets" -> the fixture advertises |
| AC4 | `Ledger.TestTheRowCapStoresNoMoreAndCountsTheRest` under `Test.LedgerLimits` | drop the `pStored` check so `GuardedAppend` always saves -> four rows and no `overflow` row |
| AC5 | `AuditEvent.TestACrossUserLedgerReadLandsOneRowAndVanishesUnregistered` | remove `LedgerRead` from `Event.Roster()` -> both the registration test and the round trip redden |
| AC6 | `LedgerWire.TestARowIsWithheldFromAnAdministratorWhoLacksItsResource` (asserts the row's **absence** and the withheld count) | return the subject's rows without evaluating `RequiredPairs` -> the withheld row appears |
| AC7 | `Ledger.TestASweepRemovesTheTurnAndLeavesItsLedgerRows` | add a `Ledger` arm to `Turn.GuardedDelete`'s cascade -> the rows vanish |
| AC8 | `LedgerWire.TestTheRouteReturnsTheTurnsRowsOverTheWire` | remove the `GET /agent/ledger` row from the `UrlMap` -> 404 `ROUTE.NOTFOUND` |
| AC9 | `Ledger.TestTheBoundedHelperBindsTheWindowAndThePredicates` | concatenate the predicate values into the SQL instead of binding -> the `' OR 1=1 --` user returns extra rows |

Each mutation is applied, observed red, reverted, and the tree confirmed byte-identical
(`git status --short` and `git diff --stat` unchanged) before the next.

**Manual checks:**

- `iris_sql_execute` on `OcuPilot_Kernel_State.Ledger` in `ocupilot-ci` after a probe turn: the rows exist,
  `RequiredPairs` is sorted and de-duplicated, and no value in any column is a credential.
- `iris_global_list` confirms the ledger's data global sits under `OcuPilot*` (so inside `%DB_OCUPILOT`) and
  that its name was not hashed - the 29-character cap held.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none

This pass planned only; no source was changed. Investigation covered `Kernel/State/*` (the `Guarded*`
surface, `BoundedWhere` and the arity wall behind DW-448), `Kernel/Agent/{Dispatch,Loop,Limits}` (the exact
frames holding every ledger column), `Screen/Tool/*` and `Screen/Gate` (declaration point and pair shape),
`Screen/Context` (the exclusion is descriptor-keyed and all-or-nothing, so it is applied upstream rather
than re-invoked), `Kernel/Audit/{Log,Event}` and `Installer.EnsureAuditEvents` (roster-driven registration),
`Api/{Router,Error,Conversation}` and the test harness. Verified: `bash scripts/lint-docs.sh` -> 0 issues in
72 files, `check-prose` 0 problems. The working tree is otherwise clean; this spec is the only new file and
the runner's bookkeeping commit lands it.
