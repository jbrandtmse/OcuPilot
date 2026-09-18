---
title: 'Story 4.9 - The agent audit ledger'
type: 'feature'
created: '2026-09-18'
status: 'done'
review_loop_iteration: 0
baseline_revision: 'f013a44fa2a8cdf00dff4404fe374a9ab43f9401'
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
warnings: ['oversized']
owned_ledger: ['DW-448']
deferred:
  - summary: >-
      An `llm` row and a pre-dispatch refusal row carry an empty `RequiredPairs`, and
      `Gate.EvaluatePairs("")` is held by everyone, so a cross-user reader holding only
      `OcuPilotAdmin:USE` receives them ungated.
    evidence: |-
      Screen/Gate.cls EvaluatePairs returns 1 for an empty list. A provider call requires no IRIS
      resource, so the empty set is truthful and the admin resource is the only gate - which is the
      intent as written. Whether that is the intended exposure (the screen route each turn ran from,
      and which tools were attempted) is a product call the intent's wording does not settle.
    location: >-
      src/OcuPilot/Kernel/Audit/Ledger.cls ViewForUser
    severity: medium (unverified)
  - summary: >-
      `SecretArguments` declared on the abstract intermediates `Kernel/Shell/ReadTool` and
      `Screen/Tool/Read` makes every present and future subclass inherit "declares none", so the
      mandatory-declaration refusal cannot bite those two subtrees.
    evidence: |-
      Both answer pDeclared 1 with "". Task 6 names `Read` explicitly, so this is the spec as
      written; the hazard is the next subclass that does take a secret argument. Per-descriptor
      declaration is the fix and it is product design.
    location: >-
      src/OcuPilot/Kernel/Shell/ReadTool.cls, src/OcuPilot/Screen/Tool/Read.cls
    severity: medium
  - summary: >-
      Nothing bounds the ledger table across turns until Story 14.4; one story's test and browser
      runs left 534 rows on the throwaway with no sweep, metric or operator-visible count.
    evidence: |-
      LEDGERMAXROWS caps rows per turn only. The class is deliberately outside
      Turn.GuardedDelete's cascade and GuardedSweep (AD-37). Measured by direct SQL on
      ocupilot-ci after the suite: SELECT COUNT(*) FROM OcuPilot_Kernel_State.Ledger = 534.
    location: >-
      src/OcuPilot/Kernel/State/Ledger.cls
    severity: medium
  - summary: >-
      Nine write and read branches have no assertion: a provider row's `error` leg, the three
      client-call writers (step-cap drop, boundary stop during the wait, settle), `truncated`
      reading true, the unparseable-requirement withhold, the windowed read, and
      `Api.Ledger.RenderFault`'s 503 and 500 arms.
    evidence: |-
      No test outside Test/Ledger*, Test/LedgerStep, Test/AuditEvent reads a ledger row; the nav
      classes that reach the client-call writers contain no ledger reference.
      TestAnUnreadableStoreIsOneUnavailableEnvelope asserts the fault object, not the route's
      status. Each is a fixture addition (a faulting turnprobe script, a route-side LedgerClass
      seam, a windowed wire read).
    location: >-
      src/OcuPilot/Kernel/Agent/Loop.cls, src/OcuPilot/Api/Ledger.cls
    severity: medium
  - summary: >-
      The 4096 and 512 column bounds are duplicated as literals in `State/Ledger.GuardedAppend` and
      `Turn.GuardedBegin`; raising `LEDGERROWMAXLENGTH` would cut silently at 4096 with no U+2026
      and `argumentsTruncated` still reading 0.
    evidence: |-
      State/Ledger.cls uses ..Cut(pArguments, 4096) against MAXLEN 4096 and Limits 4096;
      Turn.cls uses ..Cap(pContextRoute, 512, .tRouteCut) and never reads tRouteCut.
    location: >-
      src/OcuPilot/Kernel/State/Ledger.cls, src/OcuPilot/Kernel/State/Turn.cls
    severity: low
  - summary: >-
      `Test/Ledger.cls` is 778 lines against the ~500-line guidance in
      `.claude/rules/objectscript-testing.md`; it was already 641 before this rework added three
      methods.
    evidence: |-
      wc -l src/OcuPilot/Test/Ledger.cls = 778. Splitting it is a mechanical move of whole methods
      into a sibling class, larger than either rework item, and every method shares OnAfterOneTest's
      probe-row assertions.
    location: >-
      src/OcuPilot/Test/Ledger.cls
    severity: low
  - summary: >-
      An over-long `RequiredPairs` fails the whole row's write rather than losing a pair; nothing
      checks the joined string against the 512-character column before the write, and no test
      covers it.
    evidence: |-
      Documented at the property as deliberate. PairsToString has no length bound and
      RecordToolCall does not measure its result, so the failure surfaces only in the log.
    location: >-
      src/OcuPilot/Kernel/State/Ledger.cls RequiredPairs
    severity: low
  - summary: >-
      `PairsToString`/`StringToPairs` accept a resource or permission containing `,` or `:` and
      cannot round-trip it, and `RedactedKeys` treats a caller-sent literal `[redacted]` as
      evidence that a key was redacted.
    evidence: |-
      Neither rejects the separators; the round trip decides whether a row is withheld. IRIS
      resource names do not contain either character today, which is why this is low.
    location: >-
      src/OcuPilot/Kernel/Audit/Ledger.cls PairsToString, StringToPairs, RedactedKeys
    severity: low
  - summary: >-
      The ledger's only 403 reuses `Error.REASONAUTHNOPRIVILEGE`, whose sentence names a tool call;
      and `Event.LogFailure`'s hardcoded message reports a configuration change when a dropped
      `LedgerRead` emission is a read.
    evidence: |-
      Api/Error.cls REASONAUTHNOPRIVILEGE reads "the privilege that tool call requires".
      Kernel/Audit/Event.cls LogFailure's text is a literal. Either fix adds a parameter or a
      branch, which is why neither was patched.
    location: >-
      src/OcuPilot/Api/Error.cls, src/OcuPilot/Kernel/Audit/Event.cls
    severity: low
  - summary: >-
      A ledger read opens up to 201 rows one at a time through the escalated `GuardedOpenId`, and
      every append runs a `COUNT(*)` over the turn's rows first.
    evidence: |-
      ViewForUser loops GuardedRow per id (New $ROLES + AddRoles per call); GuardedAppend's cap
      check is a COUNT(*) before each write, so each recorded call costs two statements.
    location: >-
      src/OcuPilot/Kernel/Audit/Ledger.cls ViewForUser, src/OcuPilot/Kernel/State/Ledger.cls
    severity: low
  - summary: >-
      `scripts/check-objectscript.py` reports 21 rules while `CLAUDE.md` states 18.
    evidence: |-
      Observed this pass: "scanned 384 ObjectScript file(s) over 21 rule(s)". The fix edits an
      agent-context file, which this workflow routes to defer.
    location: >-
      CLAUDE.md
    severity: low
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
  `OcuPilot.Test.Routing`, `OcuPilot.Test.ToolDispatch` (`OcuPilot.Test.Dispatch` is the in-process
  dispatch harness, not a `%UnitTest.TestCase`), `OcuPilot.Test.ToolRoundTrip`,
  `OcuPilot.Test.ToolNavigate`, `OcuPilot.Test.TurnWire`, `OcuPilot.Test.StateBound`,
  `OcuPilot.Test.Convo`, `OcuPilot.Test.State`, `OcuPilot.Test.AuditRecord`, `OcuPilot.Test.Smoke`,
  `OcuPilot.Test.ConfigGate` (its `/agent/` route sweep gained the new route's exception).
- From `ui/`: `npm test` (expected unchanged - 948 node assertions and 477 vitest tests) and
  `npm run build` (expected: the six `prebuild` checkers pass and the initial total stays under the
  780 kB warning; this story adds no client code, so the measured figure must not move).
- `bash scripts/smoke.sh --container ocupilot-ci --user _SYSTEM --password SYS` -- expected: every check
  executed, zero failures; `CheckAuditEvent` reports the new roster entry.

**Falsifiability (Rule 19) - one demonstrated mutation per AC:**

| AC | Pinning test | mutation |
|----|--------------|----------|
| AC1 | `LedgerWire.TestATurnWritesOneProviderRowAndOneToolRow` | delete the `Do ..RecordLedger(...)` call at `Dispatch.AnswerOne`'s common exit -> the `tool` row is absent (that one method red; the `llm` assertions stay green) |
| AC2 | `LedgerWire.TestARowCarriesTheResourceTheToolRequired` | pass `""` in place of `tCCallPairs` at `Loop.AnswerClientCall`'s refusal `RecordClientRow` -> the row's `requiredPairs` is empty (AC6's method reddens with it: an unrecorded requirement is nothing to withhold on) |
| AC3a | `Ledger.TestADeclaredSecretIsAbsentFromTheWholeRow` (asserts the literal appears in no column and in no serialization of the view, not that a field equals `[redacted]`) | remove layer 1 from `Ledger.RedactArguments`, leaving only `Log.Redact` -> the value appears |
| AC3b | `Ledger.TestThePatternAddsAndTheDeclarationSurvivesIt` | run layer 2 over the raw input rather than over layer 1's result (`RedactedArguments(pInput, ...)`) -> the declaration is lost while the pattern still adds |
| AC3c | `Ledger.TestAToolDeclaringNothingIsRefusedAtRegistration` | remove the `SecretArguments` check from `Registry.ProviderTools` -> the undeclaring fixture advertises |
| AC4 | `Ledger.TestTheRowCapStoresNoMoreAndCountsTheRest`, under `Test.LedgerLimits` | drop the cap branch from `State.Ledger.GuardedAppend` so it always saves -> four rows and no `overflow` row |
| AC5 | `AuditEvent.TestACrossUserLedgerReadLandsOneRowAndVanishesUnregistered` | remove `LedgerRead` from `Event.Roster()` -> the roster-membership assertion reddens. The round trip stays green, because `EnsureAuditEvents` only creates and repairs: a triple already registered survives a roster edit until uninstall. The method's own negative leg is what pins the emission. |
| AC6 | `LedgerWire.TestARowIsWithheldFromAnAdministratorWhoLacksItsResource` (asserts the row's **absence**, the withheld count, and that nothing of it is on the wire) | remove the per-row `Gate.EvaluatePairs` branch from `Ledger.ViewForUser` -> the withheld row appears |
| AC7 | `Ledger.TestASweepRemovesTheTurnAndLeavesItsLedgerRows` | add a `Ledger` arm to `Turn.GuardedDelete`'s cascade -> the rows vanish |
| AC8 | `LedgerWire.TestTheRouteReturnsTheTurnsRowsOverTheWire` | remove the `GET /agent/ledger` row from the `UrlMap` -> the route 404s and all four `LedgerWire` methods redden |
| AC9 | `Ledger.TestTheBoundedHelperBindsTheWindowAndThePredicates` | concatenate the user into the fragment instead of binding it -> the `' OR 1=1 --` name is no longer matched literally; on this build it fails the read outright (`SQLCODE -1`), where the bound form returns no row |

Three matrix rows the ACs do not name carry their own pinning test, added at the Matrix Test Audit:

| Matrix row | Pinning test | mutation |
|------------|--------------|----------|
| Tool refused before dispatch | `Ledger.TestARefusalBeforeDispatchRecordsARowWithNoPairs`, under `Test.LedgerBudgetLimits`, `Test.LedgerLoopProbe` and `Test.LedgerDispatchProbe` | delete the `RecordRefusedRow` call at `Loop.AnswerTools`' reply-budget branch -> no row is written |
| Subject user deleted | `Ledger.TestARowOutlivesTheAccountItNames` (the probe user is no account this instance holds) | make `State.Ledger.GuardedRow` answer `""` for `user` -> the name is not rendered as recorded |
| Store unreadable | `Ledger.TestAnUnreadableStoreIsOneUnavailableEnvelope`, through `Test.LedgerFaultProbe` | return the store's raw status text as the fault's `reason` in `Audit.Ledger.Unavailable` -> the probe's marker reaches the envelope |
| AC3's wiring on the real instance-fulfilled path | `Ledger.TestADeclaredSecretDispatchedThroughAnswerOneIsAbsentFromTheRow`, through `Test.LedgerDispatchProbe` | replace `Dispatch.AnswerOne`'s `SecretArguments` call with `""` -> layer 1 has nothing to redact |
| AC3's wiring on the client-fulfilled path | `Ledger.TestADeclaredSecretResolvedForAClientFulfilledCallIsAbsentFromTheRow`, through `Test.LedgerClientTool.Probe` | the same call in `Dispatch.ResolveClientCall` -> the resolver's declaration reads empty |
| Tool refused at the per-call boundary | `Ledger.TestABoundaryStopBeforeDispatchRecordsARowWithNoPairs`, through `Test.LedgerLoopStopProbe` | delete the `RecordRefusedRow` call at `Loop.AnswerTools`' boundary-stop branch -> no row is written |
| A tool step's own argument string runs both layers | `LedgerStep.TestAToolStepsPreDispatchArgumentsAreDeclarationRedacted`, through `Test.LedgerRunningProbe` | replace any of the five `Dispatch.StepArguments` call sites with `Dispatch.RedactedArguments` -> the declared value is stored in clear (each site has its own reddening method; all five demonstrated together, runs 447-448) |
| A row gone before the view reads it | `LedgerStep.TestARowThatIsGoneAnswersNoValuesAndNoError` | remove the existence branch from `State.Ledger.GuardedRow` -> the read answers an error and the whole view is 503 (run 449) |
| Self read, newest first | `Ledger.TestTheRowCapStoresNoMoreAndCountsTheRest` | `ORDER BY LoggedAt DESC, Seq DESC` -> `ASC` in `GuardedIdsForWindow` -> the oldest rows survive the cap (run 450) |
| The turn row's own screen-context route | `LedgerWire.TestATurnWritesOneProviderRowAndOneToolRow` | pass `""` in place of `Loop.ContextRoute`'s answer at `Job.Run`'s `GuardedBegin` -> the column reads `""` for every real turn while the ledger rows stay right (run 451) |
| A call nothing classified withholds its arguments | `Ledger.TestAnUnclassifiedCallWithholdsItsArgumentsWhole` | drop the `pClassified` branch from `Audit.Ledger.RecordToolCall` so it always redacts by declaration -> the withheld row stores the model's own argument object and its undeclared `Value` reads in clear (run 500; the next row's method reddens with it) |
| The withheld row's wiring at the unresolved-name branch | `Ledger.TestACallWhoseWireNameResolvedNoToolWithholdsItsArguments`, through `Test.LedgerDispatchProbe` | pass `1` in place of `$Get(tSecretDeclared)` at `Dispatch.AnswerOne`'s common exit -> that one method reddens and the value is stored in clear (run 501) |
| AC2's `requiredPairs` on the instance-fulfilled path | `Ledger.TestARowsRequiredPairsComeFromTheDispatchersOwnReads`, through `Test.LedgerTool.Probe`'s declared `%Admin_Operate:USE` and argument-derived `%DB_IRISSYS:READ` | replace `$Get(tPairs), $Get(tArgumentPairs)` with `"", ""` at `Dispatch.AnswerOne`'s common exit -> both legs record no requirement (run 502) |

Each mutation is applied, observed red, reverted, and the tree confirmed byte-identical
(`git status --short` and `git diff --stat` unchanged) before the next.

**Manual checks:**

- `iris_sql_execute` on `OcuPilot_Kernel_State.Ledger` in `ocupilot-ci` after a probe turn: the rows exist,
  `RequiredPairs` is sorted and de-duplicated, and no value in any column is a credential.
- `iris_global_list` confirms the ledger's data global sits under `OcuPilot*` (so inside `%DB_OCUPILOT`) and
  that its name was not hashed - the 29-character cap held.

## Review Triage Log

### 2026-09-18 - Review pass

- verdicts: 50 findings - high 3, medium 17, low 28, false 1, maybe-false 1
- findings:
  - `[high]` `[patch]` `RecordRefusedRow` hardcodes `""` for `pSecretNames`, so layer 1 never runs on a pre-dispatch refusal row and a declared secret is stored in clear - both call sites now pass the resolved tool and read its declaration; mutation demonstrated (run 393 showed the raw value in the row)
  - `[maybe-false]` `[defer]` `llm` and refused rows carry an empty `RequiredPairs`, which `EvaluatePairs` holds for everyone - deferred; the empty set is truthful and the intent makes the admin resource the gate, so whether the exposure is intended is the owner's call
  - `[low]` `[reject]` A failed client-fulfilled navigation records `status` `ok` - the matrix specifies the settle row's **code**, not its status, the row carries `NAV.*` in `code`, and the tool step beside it is also `ok`; changing one desyncs the two
  - `[medium]` `[patch]` A row deleted between the id read and `GuardedRow` becomes an all-blank row, counted as sent and released ungated - the loop now skips a row that answered no values
  - `[medium]` `[patch]` `httpStatus` reads 0 for every failed provider call, not only for a call never made - `RecordProviderRow` now takes the port's own status output, which `Loop.Run` already held
  - `[medium]` `[patch]` `windowHours` on the wire echoed the request, so a default read reported 0 for a 24-hour window - `AppliedWindow` now reports the window `BoundedWhere` applied
  - `[low]` `[patch]` `Api.Ledger`'s header claims four validated query parameters; it validates three and binds `turnKey` - sentence corrected
  - `[low]` `[reject]` `LEDGERVIEWMAXROWS` is enforced at the route, not inside `ViewForUser` - the fix adds a limits parameter to a public signature; AD-24's cap is honored at the surface AD-24 is about
  - `[medium]` `[defer]` `SecretArguments` on two abstract intermediates makes their whole subtrees inherit "declares none" - deferred; task 6 names `Read` explicitly and per-descriptor declaration is product design
  - `[low]` `[reject]` `pDeclared` is read and discarded at dispatch - a tool whose declaration will not read cannot be advertised, and `Loop.Run` fails the turn when `Advertise` fails, so the model never sees it
  - `[low]` `[reject]` The value-substring soundness check can trip on a declared value that also appears under another key and then discards the whole argument string - needs a declared secret duplicated within one call's arguments and no shipped tool declares one; the header now says the scan is a substring test and what it costs
  - `[low]` `[reject]` A non-object tool input records no arguments while the step records some - no tool input schema admits a non-object, so the divergence is unreachable
  - `[low]` `[defer]` The 4096 and 512 bounds are duplicated literals, and `Cut` neither appends U+2026 nor updates `argumentsTruncated` - deferred
  - `[medium]` `[patch]` `Turn.ContextRoute` is written and read by nothing - pinned by an added assertion in the refusal test, and `Job.cls`'s false "one value rather than two derivations" claim corrected; mutation demonstrated (run 394)
  - `[low]` `[patch]` `AnswerClientCall`'s "Every exit records one ledger row" is an overclaim - header now names the four exits that record and says why the error exits do not
  - `[low]` `[reject]` A refused-before-resolution row stores the wire name in a column documented as canonical - the wire name is the only name such a call has; every resolved tool stores the canonical one
  - `[low]` `[reject]` `ViewForUser` never returns an error status, so `Api.Ledger`'s `$$$ISERR` branch is dead - failures reach the caller through `pFault`, which is rendered; removing the branch removes a defense and narrowing the signature is public surface
  - `[low]` `[defer]` The ledger's 403 reuses a sentence about tool calls - deferred; a new `REASON*` parameter is public surface
  - `[low]` `[defer]` `Event.LogFailure` reports a configuration change for a dropped read emission - deferred; the fix adds a branch
  - `[low]` `[patch]` `Test.Ledger`'s "Live-safe" header omits the instance-wide sweep one method runs - header corrected to name the exception
  - `[medium]` `[defer]` `truncated` reading true, the unparseable-requirement withhold, `RenderFault`'s 503/500 arms and the windowed read are unasserted - deferred with the fixtures each needs
  - `[low]` `[defer]` Per-row `%OpenId` in a loop and a `COUNT(*)` per append - deferred
  - `[medium]` `[defer]` Nothing bounds the ledger table across turns until Story 14.4 - deferred with the measured 534 rows
  - `[medium]` `[patch]` The self/cross-user split is case-sensitive while IRIS account names are not, so a caller naming their own account in another case is refused - a case-insensitive self match now resolves to the caller's own name while the column stays `%EXACT`; mutation demonstrated (run 395)
  - `[low]` `[defer]` `PairsToString`/`StringToPairs` cannot round-trip `,` or `:` in a resource name, and `RedactedKeys` trusts a caller-sent `[redacted]` - deferred
  - `[low]` `[patch]` The spec's `## Auto Run Result` under-reported the added fixtures and the tool declarations - rewritten below from this pass's own runs
  - `[high]` `[patch]` (edge-case) Declared secret stored verbatim on a refusal row - grouped with the first row; same fix
  - `[low]` `[reject]` (edge-case) The soundness check's false positives - grouped with the reject above
  - `[low]` `[reject]` (edge-case) The settle's `ok` status - grouped with the reject above
  - `[low]` `[patch]` (edge-case) Three client-call error exits record no row - the header now states it as the contract; recording a row for a call whose step never landed would outlive the only thing it reconciles with
  - `[medium]` `[patch]` (edge-case) The casing split - grouped with the casing patch above
  - `[false]` `[reject]` (edge-case) A vanished row makes the whole view answer 503 - refuted: `GuardedRow` answers `$$$OK` with no values when `%OpenId` finds nothing, so the error path is not taken; the real outcome is the blank row, patched above
  - `[low]` `[reject]` (edge-case) A limits class with `LEDGERMAXROWS` absent or zero stores nothing - the parameter is declared on `Limits` and inherited by every subclass, so the state is unreachable
  - `[low]` `[defer]` (edge-case) The duplicated `4096` literal - grouped with the defer above
  - `[low]` `[reject]` (edge-case) `pDeclared` discarded at dispatch - grouped with the reject above
  - `[medium]` `[patch]` (edge-case) `windowHours` echoes the request - grouped with the patch above
  - `[high]` `[patch]` (edge-case, claim) The redaction-order claim is false for refusal rows - grouped with the first row
  - `[low]` `[patch]` (edge-case, claim) The "every exit" claim - grouped with the header correction above
  - `[medium]` `[patch]` (verification-gap) The recorded `Test.Ledger` figure of 9 predates the three Matrix-Test-Audit tests - re-run and recorded: 12 of 12, run 397
  - `[medium]` `[patch]` (verification-gap) The self-read assertion cannot redden under its stated mutation, because `%UnitTest` runs as `%All` - both legs now run through `Test.LedgerGateProbe`; mutation demonstrated (run 396)
  - `[medium]` `[patch]` (verification-gap) `Turn.ContextRoute` is observed by nothing - grouped with the pin above
  - `[medium]` `[defer]` (verification-gap) The boundary-stop refusal writer and the three client-call writers are unasserted - grouped with the unasserted-branches defer
  - `[medium]` `[defer]` (verification-gap) A provider row's `error` leg is unasserted - grouped with the same defer, as the layer itself filed it
  - `[medium]` `[defer]` (verification-gap) The route's 503 and 500 mappings are unasserted - grouped with the same defer, as the layer itself filed it
  - `[low]` `[reject]` (verification-gap) The settle's `ok` status - grouped with the reject above
  - `[low]` `[reject]` (verification-gap) `Api.Ledger`'s `$$$ISERR(tViewSC)` branch is unreachable - grouped with the reject above
  - `[low]` `[reject]` (verification-gap) Eight `$$$AssertStatusOK(ViewForUser ...)` calls cannot fail - each sits beside the method's own falsifiable assertions and names the call that ran; removing them removes information and the load-bearing check is the `$IsObject(tFault)` line beside each
  - `[low]` `[reject]` (verification-gap) `tFragment [ "'"` cannot fail independently of the exact-equality assertion above it - cosmetic; it documents what the equality is being read for
  - `[medium]` `[patch]` (intent-alignment) The reported `Test.Ledger` 9 predates the three matrix tests - grouped with the re-run above

### 2026-09-18 - Code review (job 4-9-review-1)

- verdicts: high 1, medium 4, low 4 (4 layers plus the reviewer's own AD pass)
- findings:
  - `[high]` `[patch]` The declared-secret classification reached the ledger row and not the tool
    step written in the same frame, so every tool call stored its arguments in
    `State.Step.Arguments` with the name pattern alone - a secret in a field called `Value` in
    clear, in the column the turn's progress cards render. `Dispatch.StepArguments` now runs both
    layers for the step, at all five writers; mutation demonstrated (runs 447-448)
  - `[medium]` `[patch]` `GuardedRow` propagated `GuardedOpenId`'s not-found error, so a row
    deleted between the id read and the row read made the whole view answer 503 and the skip in
    `ViewForUser` was dead code. The earlier pass's `[false]` verdict on this rested on
    `GuardedOpenId` answering `$$$OK` for a missing id, which it does not; mutation demonstrated
    (run 449)
  - `[medium]` `[patch]` "Newest first" and the turn row's own `ContextRoute` writer were
    unasserted - one assertion each, in the cap test and the wire test; mutations demonstrated
    (runs 450-451)
  - `[medium]` `[defer]` A call whose wire name never resolved records its raw input in a
    permanently-retained row with an empty `RequiredPairs` - DW-1130
  - `[medium]` `[defer]` AC2's `requiredPairs` is unasserted on the instance-fulfilled path -
    DW-1131
  - `[low]` `[patch]` `GuardedIdsBounded` dropped the first bound argument when `pMaxRows` was not
    positive, sliding every predicate value up one placeholder; it now refuses
  - `[low]` `[patch]` `RecordRefusedRow`'s header claimed both refusal sites have resolved the
    tool - corrected
  - `[low]` `[patch]` The spec's `Test.Ledger` figure, its total, its fixture list, the
    boundary-stop claim in `deferred:` entry 4 and in the residual risks, and the seven missing
    `mutation:` rows - corrected above
  - `[low]` `[defer]` The window bound and its default are derived in three places - DW-1132

## Rework iteration 1 - open items

Re-opened for DW-1130 and DW-1131 only. Nothing else in this spec is re-opened, and no earlier
finding is re-argued here.

**Item 1 - DW-1130. A row whose call carried no readable secret-argument classification withholds
its arguments.** Four writers reach `Kernel.Audit.Ledger.RecordToolCall`: `Dispatch.AnswerOne`'s
common exit, `Loop.RecordClientRow` (from `Dispatch.ResolveClientCall`), and `Loop.RecordRefusedRow`
at its two sites. On the paths where the wire name never resolved to a tool, the declared-secret list
is `""` because there is no tool to ask - indistinguishable from a tool that declared none - so the
model-authored argument blob was stored with the name-pattern backstop as its only layer, in a table
with no retention sweep, on a row whose empty `RequiredPairs` releases it to any `OcuPilotAdmin:USE`
holder.

Fail closed. `RecordToolCall` takes `pClassified`, the writer's answer to "was a classification
read"; when it is 0 the row's `Arguments` stores `Kernel.Audit.Log.#REDACTED` whole and
`ArgumentsTruncated` 0, and `RedactArguments` is never called, so no caller-supplied value reaches
the column. The chosen shape is the **whole-blob redaction mark**, which a reader tells apart from
both of the other two states and which adds no literal - `[redacted]` already exists on `Log` and
already appears in this column for a redacted field:

| `arguments` reads | means |
|-------------------|-------|
| `""` | no arguments were sent, or the input was not an object |
| `[redacted]` | arguments were sent and were withheld: nothing classified them |
| `{...}` | arguments recorded, per-field redaction applied |

One implementation in `RecordToolCall` is what makes the four writers consistent. `pClassified`
defaults to 0, so a writer that does not answer the question fails closed. Each writer's source for
it is the `pDeclared` output the registry already answers: `AnswerOne` passes `$Get(tSecretDeclared)`
(undefined on both unresolved branches); `ResolveClientCall` answers it as a new
`pSecretDeclared` output that `RecordClientRow` carries; `RecordRefusedRow` reads it from its own
`pTool` argument, which is `""` on an unresolved wire name.

Out of scope, stated so it is not read as an oversight: the tool **step**'s argument string
(`State.Step.Arguments`, `Dispatch.StepArguments`) keeps the name pattern alone on an unresolved
call. DW-1130 is about the permanently-retained ledger row; a step dies with its turn's retention
window.

**Item 2 - DW-1131. AC2's `requiredPairs` is pinned on the instance-fulfilled path.** Replacing
`$Get(tPairs), $Get(tArgumentPairs)` with `"", ""` at `Dispatch.AnswerOne`'s common exit reddened
nothing, because `shell.instance.read` - the only tool the wire test reaches through that exit -
requires no pair, so its empty `requiredPairs` was truthful. The fix is on the test side, the way
DW-1131's own evidence names it: `Test.LedgerTool.Probe` gains a declared pair
(`%Admin_Operate:USE`, from `PrivilegePairs`) and an argument-derived one (`%DB_IRISSYS:READ`, from
`ArgumentPairs`, present only when the call names `Name`), and a new `Test.Ledger` method drives it
through `Test.LedgerDispatchProbe.Answer` - the shipped `AnswerOne`, whose common exit is the
mutation site - in two legs, asserting both halves on the row for the call that names `Name` and the
declared half alone for the call that does not. The refusal rows still record no pair: nothing read
them, which `RecordRefusedRow` says and its two tests assert.

## Auto Run Result

Status: done
Blocking condition: none

**What was built.** One durable row per provider call and per tool answer, in
`OcuPilot.Kernel.State.Ledger` on `Kernel/State/Base` (protected database, no hand-written Storage,
no `SCHEMAVERSION` move); `OcuPilot.Kernel.Audit.Ledger` as its one public face, holding the two
writers, the two-layer redaction, the pair-string round trip and `ViewForUser`'s cross-user and
per-row gates outside every escalated frame; `OcuPilot.Api.Ledger` behind `GET /agent/ledger`.
`Base.GuardedIdsBounded` closes DW-448 by joining the statement inside `Base` and binding
`pMaxRows` first, then `pParams` in array order, with a zero-argument branch for SQLCODE -400.
`Screen/Tool/Base.SecretArguments` makes the secret-argument classification mandatory, refused at
advertise time in `Registry.ProviderTools`. Three bounds on `Limits`, one `LedgerRead` roster name
(no installer edit), four `LEDGER.*` codes with `LedgerCodes()`/`ReasonForLedger()`. No `Ledger` arm
on `Turn.GuardedDelete` and no retention sweep. No client file changed.

**Files changed.** New: `Kernel/State/Ledger.cls` (the store), `Kernel/Audit/Ledger.cls` (writers,
redaction, gates, view), `Api/Ledger.cls` (the route's handler), `Test/{Ledger,LedgerWire}.cls` (the
two suites), `Test/{LedgerLimits,LedgerBudgetLimits}.cls` (narrowed bounds),
`Test/{LedgerGate,LedgerGateProbe,LedgerLoopProbe,LedgerDispatchProbe,LedgerFaultProbe,
LedgerLoopStopProbe,LedgerClientDispatchProbe}.cls` (fixture seams),
`Test/LedgerTool/{Probe,Silent,Registry,All}.cls` and `Test/LedgerClientTool/{Probe,Registry}.cls`
(a tool that declares a secret, a client-fulfilled one that does, one that declares nothing, and
the registries over them). Changed: `Base.cls` (the bounded helper),
`Turn.cls` (`ContextRoute`, written at `GuardedBegin`), `Loop.cls` (route capture, the provider row,
the two refusal rows, the four client-call rows), `Dispatch.cls` (`pRoute` through
`Answer`/`AnswerOne`, the common-exit row, `ResolveClientCall`'s new outputs), `Job.cls` (the route
at begin), `Limits.cls`, `Event.cls` (`LedgerRead` plus `Record`'s optional `pEventName`),
`Registry.cls` + `Screen/Tool/{Base,Read,ErrorRead,Navigate}.cls` + `Kernel/Shell/ReadTool.cls` and
eight test tool fixtures (the declaration), `Api/{Error,Router}.cls`, `Test/ConfigGate.cls` (the new
route's exception), `Test/AuditEvent.cls` (the `LedgerRead` round trip and its negative leg),
`Test/TurnLoopProbe.cls` (the `pRoute` pass-through).

**Review.** 50 findings across four layers - high 3, medium 17, low 28, false 1, maybe-false 1.
Patched: 1 high entry (layer 1 of the redaction skipped on every pre-dispatch refusal row), 7 medium
entries (the phantom row, the provider row's HTTP status, the echoed window, the write-only
`ContextRoute`, the case-sensitive self read, the self-read assertion that could not redden, the
stale recorded test figure) and 5 low entries (four doc corrections and this section). Deferred: 10
entries in the frontmatter `deferred:` list. Rejected with their reasons in the triage log above: the
settle's `ok` status (the matrix specifies the code), `LEDGERVIEWMAXROWS` at the route
(public surface), `pDeclared` discarded at dispatch (unadvertisable), the soundness check's false
positives (needs a duplicated declared value), a non-object tool input (no schema admits one), the
wire name on an unresolved row (the only name it has), the always-OK `%Status` (failures travel in
`pFault`), the eight decorative `AssertStatusOK` calls and one redundant assertion.

**Follow-up review recommended: true.** A `high` entry was patched. The named unverified risk: the
fix is pinned for the reply-budget refusal and the boundary stop before dispatch. The three
client-call writers (step-cap drop, boundary stop during the wait, settle) still write rows no test
reads, so a regression in those three would not redden - the fourth `deferred:` entry.

**Verified.** `check-objectscript` 0 problems over 384 files; `test_check_objectscript` 125 OK;
`lint-docs` 0 issues in 72 files and `check-prose` 0 problems. Compiled clean into the throwaway
(`LoadDir "ck"`, 0 errors) and into slot A through `iris_doc_load` (382 uploaded, 0 failed).
18 `%UnitTest` classes through `ci-runner.mjs --container ocupilot-ci`, one invocation, runs 397-414:
195 tests, 0 failed, 0 probe leftovers, 0 overlaps - `Ledger` 15, `LedgerWire` 4, `AuditEvent` 7,
`TurnStore` 11, `ConfigGate` 3, `Envelope` 15, `Routing` 18, `ToolDispatch` 17, `ToolRoundTrip` 2,
`ToolNavigate` 15, `TurnWire` 11, `TurnLoop` 11, `TurnNavigate` 14, `StateBound` 3, `Convo` 7,
`State` 12, `AuditRecord` 6, `Smoke` 24. Client: `npm test` 948 node + 477 vitest across 36 files,
0 failed; `npm run build` initial total 767.61 kB against the 780 kB gate, unmoved; `npm test:browser`
120 of 120 against the redeployed bundle, with `/agent/definitions` empty afterwards. Smoke:
executed=19 passed=19 failed=0 pending=2 skipped=0. Manual probes on the throwaway: rows present,
`RequiredPairs` sorted and de-duplicated (`%Admin_Operate:USE,%Admin_Secure:USE,%DB_IRISSYS:READ`),
no credential-shaped value in any `Arguments` column, and the data global is the inherited
`^OcuPilot.Kernel.State.BaseD` - unhashed, under `OcuPilot*`, so inside `%DB_OCUPILOT`.

**One defect this pass caught in its own test.** The first version of the refusal row's
secret-absence assertion ran under `LedgerLimits`, whose `LEDGERROWMAXLENGTH` of 24 cut the argument
string before the declared value - so the absence would have held by truncation rather than by
redaction. The reply-budget narrowing moved to its own `Test.LedgerBudgetLimits`, which keeps the
shipped argument bound, and the assertion is now load-bearing (demonstrated by run 393).

**Residual risks.** The three unasserted client-call writers named above; the ledger table has no
cross-turn bound until Story 14.4 (534 rows accumulated on the throwaway during this story's runs);
an empty `RequiredPairs` is held by every reader, so `llm` and refused rows are gated only by
`OcuPilotAdmin:USE`; `SecretArguments` on two abstract bases means a future subclass inherits
"declares none".

### Rework iteration 1 - DW-1130 and DW-1131

Status: done
Blocking condition: none

**What this pass changed.** `Audit.Ledger.RecordToolCall` takes `pClassified`, defaulting to 0, and
withholds the model's arguments whole when it is 0 - `Arguments` stores `Audit.Log.#REDACTED` when an
argument object was sent and `""` when none was, `ArgumentsTruncated` reads 0, and `RedactArguments`
never runs, so no caller-supplied value reaches the column. All four writers thread it from the
`pDeclared` the registry already answers: `Dispatch.AnswerOne`'s common exit passes
`$Get(tSecretDeclared)`, undefined and so 0 on both branches where the wire name resolved no tool;
`Dispatch.ResolveClientCall` answers a new `pSecretDeclared` output that `Loop.RecordClientRow`
carries at all four of its sites; `Loop.RecordRefusedRow` derives it from its own `pTool` at both
sites. The default is what makes a fifth writer fail closed. For DW-1131, `Test.LedgerTool.Probe`
gained a declared pair and an argument-derived one, and `Test.Ledger` gained three methods.

**Verified.** `check-objectscript` 0 problems over 390 files; `test_check_objectscript` 125 OK;
`lint-docs` 0 issues in 72 files and `check-prose` 0 problems. Compiled into `ocupilot-ci`
(`LoadDir "ck"`, 0 errors) before every run. Seven classes through
`ci-runner.mjs --container ocupilot-ci`, one invocation, runs 525-531: 77 tests, 0 failed, 0 probe
leftovers, 0 overlaps - `Ledger` 18 (15 before this pass), `LedgerStep` 2, `LedgerWire` 4,
`TurnStore` 11, `ToolDispatch` 17, `TurnLoop` 11, `TurnNavigate` 14. Smoke: executed=19 passed=19
failed=0 pending=2 skipped=0. No `ui/` file changed, so the client gates were not re-run; the
18-class figure recorded above is the previous pass's run 397-414 and is left as the record of that
run.

**Mutations (Rule 19), each applied, observed red, reverted, and the tree confirmed byte-identical.**
Run 523: `1` in place of `$Get(tSecretDeclared)` at `AnswerOne`'s common exit reddened only
`TestACallWhoseWireNameResolvedNoToolWithholdsItsArguments`, storing
`{"Name":"probe","Value":"s3cr3tledgervalue"}` in the `Arguments` column - the hazard itself. Run
524: `$Get(tPairs), $Get(tArgumentPairs)` to `"", ""` at that same exit reddened only
`TestARowsRequiredPairsComeFromTheDispatchersOwnReads`, both legs, where before this pass it reddened
nothing. The store-level leg of item 1 is run 500 in the table above.

**Residual risk.** The tool step's argument string keeps the name pattern alone on a call whose wire
name resolved no tool; that store is bounded by the turn's retention window, where the ledger row is
not, and the scope note above says so.
