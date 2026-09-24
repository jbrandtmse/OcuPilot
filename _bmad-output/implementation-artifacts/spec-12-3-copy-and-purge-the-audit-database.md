---
title: 'Story 12.3: Copy and purge the audit database'
type: 'feature'
created: '2026-09-24'
status: 'done'
baseline_revision: 'e693249be3bd6ae29b81c796860b9b3f3ba7b121'
baseline_commit: 'e693249be3bd6ae29b81c796860b9b3f3ba7b121'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-12-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-12-2-revoke-a-user-s-oauth-2-0-tokens.md'
warnings: ['oversized']
deferred:
  - 'A PORT.TIMEOUT answer (503) is classified server-fault, so the shell connectivity banner may show beside the page still-running line (inference; the bound was not reached, a 30,579-record copy took 0.53 s)'
  - summary: >-
      The purge's removal of records dated before the cut-off has not been observed: every throwaway holds only today's records, so the before-cut-off count is 0 before the purge as well as after it.
    evidence: |-
      %SYS.Audit refuses saves and imports into %SYS, so no test can create a past-dated record; the port's body is pinned by exact JSON and the vendor's Delete end time is read as exclusive in its source. Settle by running AuditPurge's today leg on an instance holding a previous day's records.
    location: >-
      src/OcuPilot/Test/AuditPurge.cls TestTheScreenRoutePurgesBeforeTodayAndKeepsToday
    severity: medium (unverified)
  - summary: >-
      The purge dialog counts days back on the browser's calendar, so a browser whose date is ahead of the instance's gets 0 days refused as a future cut-off, and one behind names a cut-off a day earlier than the instance's today minus N.
    evidence: |-
      purgeCutoff takes the page's new Date(); CutoffProblem refuses a date after +$Horolog. The dialog names and the person types the exact date sent, so nothing is purged that was not confirmed. The client has no instance clock, so aligning it adds a read surface; the spec's task chose the local calendar.
    location: >-
      ui/src/app/areas/security/audit-purge-dialog.ts purgeCutoff
    severity: low
footprint_extensions:
  - 'ui/src/app/areas/security/** (auditing-config.page.ts and its spec, two new dialogs): the actions attach to Security > Auditing, not to the Logs area'
  - 'src/OcuPilot/Screen/Descriptor/AuditingConfig.cls (two appended row actions)'
  - 'src/OcuPilot/Screen/Tool/Base.cls, src/OcuPilot/Screen/Tool/Registry.cls, src/OcuPilot/Screen/Context.cls (the unadvertised-tool declaration)'
  - 'src/OcuPilot/Port/AdminPort.cls (contended: two MUTATINGTYPES entries, one new parameter, one guard condition)'
  - 'ui/src/app/shell/screen-action-handler.ts (contended: sendFor gains an optional values parameter; see Open questions)'
  - 'ui/src/app/core/screen-actions.ts (two labels)'
  - 'src/OcuPilot/Kernel/Proposal/Prohibited.cls (contended: Target passes Resolve its new unadvertised argument, one line outside Epic 9 hunks; the screen route asks this set)'
  - 'src/OcuPilot/Test/X509SecretProbe.cls, src/OcuPilot/Test/SecretSpelling.cls (fixture method Advertised renamed AdmittedNames: it clashed with Base.Advertised)'
  - 'src/OcuPilot/Test/ToolSetFull.cls, src/OcuPilot/Test/ToolEmit.cls (advertised roster compared against the advertised half of ListTools)'
  - 'src/OcuPilot/Test/AuditingScreen.cls, src/OcuPilot/Test/Descriptor.cls (Auditing action roster)'
  - 'src/OcuPilot/Test/Prohibited.cls (Epic 9 edits the same method at :424+; this story adds the port-composed branch at :366, outside those hunks)'
---

<intent-contract>

## Intent

**Problem:** An administrator cannot archive or trim the IRIS audit database without the classic "Copy Audit Log" and "Purge Audit Log" pages, so auditing either grows without bound or is managed outside OcuPilot.

**Approach:** Add two actions to Security › Auditing (`security/auditing`, the singleton `auditing-configuration` target `SYSTEM`): **Copy to namespace** and **Purge old records**. Each is a row action run through AD-53's route by its own write tool, `security.auditing.copy` and `security.auditing.purge`. Both tools reach the admin API's `Security.Audit.Record` `COPY` and `PURGE` request types through a new `Port/AuditPort` (AD-52). The vendor runs both in its own async worker, and the port polls it (AD-26). Copy is also the agent's tool. Purge is screen-only: it is declared unadvertised, so no provider request, dispatch or screen context sees it.

## Boundaries & Constraints

**Always:**

- The vendor queues both types (`ShouldRunAsync()` true) and discards their counts; `RunCopy` calls `%SYS.Audit.Copy(.n, AuditCopyNamespace, 1=DeleteAfterCopy, Begin, End)` and `RunPurge` calls `%SYS.Audit.Delete(.n, Begin, End)`. `EndDateTime` is exclusive, and both write the vendor's own `%System/%Security/AuditChange` event.
- The port composes the vendor body from the tool's arguments. Copy sends `{AuditCopyNamespace, DeleteAfterCopy: false, BeginDateTime: "", EndDateTime: ""}`, which copies every record and deletes none. Purge sends `{BeginDateTime: "", EndDateTime: "<PurgeBefore> 00:00:00"}`, which is the classic page's own cut-off (`$ZDT(+$H-days,3)_" 00:00:00"`).
- Both tools declare the Auditing screen's pairs plus `%Admin_Operate:USE`, because the port polls the vendor's `AsyncResult` endpoint, whose `ResourcesOR()` names that resource. A caller missing a pair is refused by name before any port call (AD-8).
- The purge confirmation names the scope and the cut-off: every audit record on this instance dated before `<date>` 00:00 (instance time), including the agent's markers from that period. Purge stays disabled until the person types that date.
- Every visible word is a `STRINGS.<key>` with a Fixed strings row appended after EXPERIENCE.md :469. Styling uses tokens only. The dialogs and the page pass DW-1337 with no new baseline entry.

**Never:**

- Register `security.auditing.purge` with the agent. It is absent from `ProviderTools`, `Resolve`, `ResolveWire` and `Screen.Context.ScreenTools` (AC3). Epic 14 flips the declaration together with its policy key.
- Offer delete-after-copy on either caller: it is a purge in effect.
- Add a route, a polling endpoint, a new dialog kind in the shell, an entity type, or a prohibited-set arm. Emit an OcuPilot marker on the screen path (AD-53).
- Write any test that copies or purges on `ocupilot-slot-b` or another dev instance. Name an `%Api.Admin.*` class outside `AdminPort` (AD-27).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Copy (screen) | Namespace `USER` | The page shows copying to `USER` as running on the instance. Then `{action: "copy", id: "SYSTEM", values: {CopyNamespace: "USER"}}` answers 200 `updated`, and USER's `%SYS.Audit` holds every record %SYS held at the start. %SYS keeps its own records | None |
| Copy into `%SYS`, or an unknown namespace | `%SYS` / `NOSUCHNS` | 400 `TOOL.ARGUMENTS` naming the namespace problem | Nothing is queued |
| Purge (screen) | 0 days, so the cut-off is today | 200 `updated`. Every record dated today survives, and the vendor records its own purge event | None |
| Purge cut-off malformed or in the future | `2026-13-01` or tomorrow | 400 `TOOL.ARGUMENTS` | Nothing is queued |
| Still running at the bound | The vendor task is not terminal after `AsyncTimeout()` (30 s) | 503 `PORT.TIMEOUT`. The page's status line says the operation is still running on the instance and finishes in the background | The worker keeps running |
| Vendor failure | Task `Failed` | The envelope's sentence appears in the page's refusal banner | Nothing is published |
| Missing pair | A caller holding the screen's pairs but not `%Admin_Operate:USE` | 403 naming `%Admin_Operate:USE`, from the screen route (both tools) and from the mint (copy) | Nothing is queued |
| Agent purge | A model calls `security_auditing_purge` | Refused as an unknown tool. It is not in the advertised list | No proposal is minted |

</intent-contract>

## Code Map

- **Vendor, read on `ocupilot-slot-b` in `%SYS` with `GetTextAsString` (hidden classes):**
  - `%Api.Admin.Endpoints.Security.Audit.Record`: `TYPECOPY` 10 and `TYPEPURGE` 11. `ShouldRunAsync()` and `NeedsRequestBody()` are true for both. `ResourcesOR()` is `%Admin_Secure`. `ValidateRequest` uses the inline schemas quoted in the Always list, and no template method exists.
  - `%Api.Admin.Util.AsyncTask`: the states are `Queued`, `Running`, `Finished`, `Failed`, `Canceled` and `Paused`. `AddToAsyncQueue` queues on `$System.WorkMgr` and records `%session.Username`.
  - `%Api.Admin.Endpoints.AsyncResult`: `ResourcesOR()` is `%Admin_Operate`. GET answers `{State, TaskName, Console, FailureReason, Result, TimeQueued, TimeStarted, TimeFinished}` and 404 for another user's task.
  - `irissys/%SYS/Audit.cls`: `Copy` is :557, runs in one `TSTART`, refuses `%SYS`, and writes `AuditChange`. `Delete` is :764, with `EndDateTime` "up through, but not including". `%OnBeforeSave` :3032 refuses `%SYS`, and `Import` refuses `%SYS`, so no test can create old records in `%SYS`.
  - `irissys/%CSP/UI/Portal/Audit/ActionTemplate.cls` :118-146 holds the classic pages' parameters.
- **`src/OcuPilot/Port/AdminPort.cls`:**
  - `MUTATINGTYPES` :254;
  - `CONSTANTBODIES` :393, the precedent for a port-supplied body;
  - the `Sequence` async guard :1843-1865 (DW-1279), and the class doc :144-151 that says no async entry is mutating;
  - `IsMutating` :1674, `EndpointType` :1700, `AwaitTask` :1892 (bound `ASYNCTIMEOUT` :477 = 30), `ForgetTask` :1047.

  Epic 9 (`origin/OCU-1-epic9`) edits :118, :244-314, `Invoke` :645-753, :1084, :1660, :1698, :1922 and :1947+. It does not touch the guard. It rewrites the `MUTATINGTYPES` line, so a merge conflict there is resolved by keeping both lists.
- **`src/OcuPilot/Port/TokenPort.cls`** (Story 12.2) is the model for an `Invoke` override that answers a port-synthesized read type and rewrites the query before calling `##super`.
- **Write-tool base, `Screen/Tool/Write.cls`:**
  - `SCREENACTIONS` :157, `SCREENVALUES` :190, `PortQuery` :331, `ScreenActionDelta` :498;
  - `READANSWERS`, `PRECONDITIONFIELD`, `FINGERPRINTSUBJECT`, `SENDSBODY`, `STATEFIELD`.

  `Screen/Tool/Base.cls` has `TOOLNAME` :26 and `KIND` :30.
- **`Screen/Tool/AuditingUpdate.cls`** is the model: the same descriptor, the singleton id argument and its `InputSchema` description, and `PrivilegePairs` appending one pair. `ErrorDelete.cls` is the model for overriding `SettableFields` and `InputSchema` with typed arguments and for `PortQuery`.
- **Kernel flow (read only):**
  - `Kernel/Proposal/Mint.cls` :160-275. For a bodyless tool, `Merge` builds the diff from the fresh read, the `StateDiff` rows are appended, and the payload is narrowed to `FINGERPRINTSUBJECT`.
  - `Api/ScreenAction.cls` `Run` :165-270 and `Body` :333, which *replaces* the diff with the `StateDiff` rows for a bodyless tool.
  - `Operation.Query` :173 feeds `PortQuery(payload)`, and `Apply` :298.
  - `Kernel/Proposal/Prohibited.cls`: `COVEREDTYPES` :174 already covers `auditing-configuration`. The `Auditing` arm :1097 is `ReviewedFewOnly` over `Enabled`, and `SkippedFields` skips `STATEFIELD` and the subject.
- **Tool registry:**
  - `Screen/Tool/Registry.cls`: `ListTools` :104, `Resolve` :189, `ResolveWire` :212, `ProviderTools` :238.
  - `Kernel/Agent/Dispatch.cls` advertises through `ProviderTools` (:98) and resolves through `ResolveWire` (:202, :454).
  - `Screen/Context.cls` `ScreenTools` :144 (AD-24).
  - `Api/ScreenAction.cls` `ToolFor` :419 reads `ListTools` directly, so an unadvertised tool stays reachable by the screen. None of these files is in Epic 9's diff.
- **`Screen/Descriptor/AuditingConfig.cls`:** `rowActions` is `enable, disable`. Its privileges are `%Admin_Secure:USE` and `%DB_IRISSYS:READ`, its `toolIdentifier` is `security.auditing`, and its entity type is the singleton `auditing-configuration`.
- **Client:**
  - `ui/src/app/areas/security/auditing-config.page.ts` (454 lines): the template :98-183, the handler `inject` :196, and `RELOAD_ENTITIES` :69.
  - `ui/src/app/shell/screen-action-handler.ts`: `SCREEN_ACTION_DESCRIPTORS` :39 includes AuditingConfig. The constructor :298 registers every declared row action. `send` :489 posts `{action, id, values}` and publishes the change event. `sendFor` :533 takes no values.
  - `ScreenActions.register` (`core/screen-actions.ts` :122) replaces an existing registration. The AuditingConfig labels are at :105.
  - Namespaces come from `core/scope.ts` (`/api/ocupilot/namespaces`).
  - `strings.ts` ends at :1700 (`} as const;`).
- **Test precedents:**
  - `Test/TokenRevoke.cls` / `TokenProbe.cls`: arming, principals, mint → confirm with `AuditMarker.MarkerRows`, and `DispatchRefusal`.
  - `Test/AdminPortAsync.cls` :49 pins the mutating-async refusal with the probe `OcuPilotProbeAsyncWrite/PUT`; :114 is the live `Security.Audit.Record` LIST.
  - `Test/ToolWrite.cls` :1126-1222: `MUTATINGTYPES` equals the reached pairs, and bodyless or constant-body ⇔ `SENDSBODY=0`.
  - `Test/PortFixture.cls` :21, `PortGate.cls` :28, `ReadTool.cls` :93, `ToolRoundTrip.cls` :35, `SurfaceCoverage.cls` :54.
  - Browser: `ui/browser/token-revoke.browser-spec.mjs` (`irisSession`, three DW-1337 passes) and `structural-walk.mjs` (`assertThrowaway` :689).
  - The existing Auditing tests are `Test/AuditingScreen.cls`, `AuditingUpdate.cls`, `auditing-screen.browser-spec.mjs`, `auditing-write.browser-spec.mjs` and `auditing-config.page.spec.ts`.

## Tasks & Acceptance

**Execution:**

- `src/OcuPilot/Screen/Tool/Base.cls` and `Screen/Tool/Registry.cls` and `Screen/Context.cls` -- add `Parameter ADVERTISED As BOOLEAN = 1` and `ClassMethod Advertised()`.
  - `ListTools` entries carry `advertised`.
  - `ProviderTools`, `Resolve` and `ResolveWire` skip an unadvertised entry, and `ScreenTools` leaves it out of `tools`.
  - `ScreenAction.ToolFor` is unchanged. Grep every `Resolve(` and `ResolveWire(` caller and confirm none serves the screen route.

  This declaration is the one Epic 14 flips (open question R1).
- `src/OcuPilot/Port/AdminPort.cls` -- read `origin/OCU-1-epic9`'s version first.
  - Append `Security.Audit.Record/COPY` and `Security.Audit.Record/PURGE` to `MUTATINGTYPES`.
  - Add `Parameter QUEUEDWRITES` naming exactly those two pairs, with one doc paragraph: they are queued by the vendor, and their bodies carry no secret field.
  - Narrow the guard at :1857 so it refuses a mutating queued request only when its pair is not in `QUEUEDWRITES`.
  - Correct the doc at :144-151 in place.
- `src/OcuPilot/Port/AuditPort.cls` (new, extends `AdminPort`, declares `Parameter COMPOSEDTYPES` = the same two pairs) -- override `Invoke` for `Security.Audit.Record` only:
  - `DATABASE`: `##super("Security.Audit.Enabled", "GET")`, answering `{Enabled, CopyNamespace: "", PurgeBefore: ""}`.
  - `COPY` / `PURGE`: compose the body from `pQuery("CopyNamespace")` / `pQuery("PurgeBefore")` as the Always list says, then call `##super` with an empty query.
  - Everything else: `##super`.

  Expose `ClassMethod Body(pType, ByRef pQuery) As %DynamicObject` so the composition is unit-testable. Add the class to `Test/PortGate.cls` `ROSTER`.
- `src/OcuPilot/Screen/Tool/AuditCopy.cls` (new): `security.auditing.copy`, with `DESCRIPTORCLASS` AuditingConfig and `SCREENACTIONS` `copy`.
  - `SCREENVALUES` `copy=CopyNamespace`, `PORTCLASS` AuditPort, `READTYPE` `DATABASE`, `WRITETYPE` `COPY`, `SENDSBODY` 0, `CHANGEACTION` `updated`, `DESTRUCTIVE` 0.
  - `READANSWERS` `Enabled,CopyNamespace,PurgeBefore`; `PRECONDITIONFIELD` and `FINGERPRINTSUBJECT` `CopyNamespace`.
  - Overrides: `Endpoint` `Security.Audit.Record`, `SettableFields` `CopyNamespace`, `InputSchema` (the singleton id text of AuditingUpdate plus `CopyNamespace`), `StateDiff` (no row; Merge's `CopyNamespace` row is the card's), `PortQuery` (copies `CopyNamespace` from the payload into the query), and `PrivilegePairs` (the screen's pairs plus `%Admin_Operate:USE`).
  - `ArgumentProblem` and `ScreenActionDelta` share one check: the value is non-empty, it is not `%SYS`, and `##class(%SYS.Namespace).Exists()` is true.
  - `DESCRIPTION`: the call copies every record into the named namespace's audit globals and deletes nothing, anyone who can read that database can read the copy, and nothing changes until the user confirms.
- `src/OcuPilot/Screen/Tool/AuditPurge.cls` (new): `security.auditing.purge`, with the same shape as copy and these differences:
  - `ADVERTISED` 0, `SCREENACTIONS` `purge`, `SCREENVALUES` `purge=PurgeBefore`, `WRITETYPE` `PURGE`, `DESTRUCTIVE` 1.
  - The subject and precondition are `PurgeBefore`.
  - The check requires `^\d{4}-\d{2}-\d{2}$`, a real date, and a date no later than `+$Horolog` (Conventions › Dates).
- `src/OcuPilot/Screen/Descriptor/AuditingConfig.cls` -- append `{"id": "copy", "selfProtection": ""}` and `{"id": "purge", "selfProtection": ""}` to `rowActions`, and one doc `<p>`. Regenerate `ui/src/app/core/screens.generated.ts` with `node tools/screen-mirror.mjs`.
- `ui/src/app/shell/screen-action-handler.ts` -- `sendFor(descriptor, actionId, target, values?: ActionValues)` forwards `values` to `send`. Read `origin/OCU-1-epic9`'s version first and change no other line (R5).
- `ui/src/app/core/screen-actions.ts` -- add labels for `copy` and `purge` under AuditingConfig (:105).
- `ui/src/app/areas/security/audit-copy-dialog.ts` (new) -- `app-dialog` with a labeled native `<select>` of the scope namespaces minus `%SYS`, the consequence line, and a primary Copy button.
- `ui/src/app/areas/security/audit-purge-dialog.ts` (new):
  - a days field (`inputmode="numeric"`, whole number 0 to 9999, labeled);
  - a live scope and cut-off line from the exported `purgeCutoff(days, today)`, which gives `YYYY-MM-DD`, today minus `days` on the local calendar;
  - a typed-date field. The destructive Purge button stays `aria-disabled` until the typed text equals the cut-off.
- `ui/src/app/areas/security/auditing-config.page.ts` -- an "Audit database" group below the status control, with the two buttons:
  - The page registers `copy` and `purge` itself through `ScreenActions.register`, replacing the handler's registrations. Each opens its dialog.
  - Confirm calls `handler.sendFor(AuditingConfig, action, 'SYSTEM', values)`.
  - While the request is in flight, a `data-audit-operation` status line reads running on the instance, with the start time. Both buttons are disabled.
  - Then it reads the finished sentence, or the refusal banner. `PORT.TIMEOUT` reads the still-running sentence.
- `ui/src/app/core/strings.ts`, EXPERIENCE.md (append after :469, Story 12.3, FR-75), and `_components.scss` (own classes only, tokens only) -- the strings listed in Design Notes.
- `src/OcuPilot/Test/AuditCopy.cls` (new, <500 lines, arms `OCUPILOT_ALLOW_PRINCIPALS`, cleans USER with `%SYS.Audit.Delete` run in USER):
  - the declarations and the resolved pair set;
  - `AuditPort.Body` for both types;
  - the screen route copy (USER count ≥ the %SYS count at start, %SYS unchanged, no agent marker);
  - `%SYS`, unknown and empty namespace refused, with nothing queued;
  - mint → confirm → one `AuditMarker.MarkerRows` row naming the proposal;
  - a principal holding only the screen's pairs refused 403 naming `%Admin_Operate:USE` on the route for copy and for purge, and on the mint and `DispatchRefusal` for copy.
- `src/OcuPilot/Test/AuditPurge.cls` (new, arms the new `OCUPILOT_ALLOW_AUDIT_PURGE`):
  - the declarations;
  - unadvertised: absent from `ProviderTools`, `ResolveWire` and `ScreenTools("…AuditingConfig")`, while copy is present and the route resolves purge. A dispatch of `security_auditing_purge` through `ToolDispatchProbe` answers the unknown-tool refusal, and no proposal row is written;
  - screen route purge at instance-today: every record dated today still exists, and the vendor's `AuditChange` row is present;
  - malformed and future cut-offs refused, with the counts unchanged.
- Rosters, own entries only:
  - `scripts/ci-throwaway.sh` gets a new arming block for `OCUPILOT_ALLOW_AUDIT_PURGE` naming `AuditPurge` and the copy/purge browser spec's needs, and `AuditCopy` is added to the PRINCIPALS roster. Update the `ui/tools/ci.test.mjs` pins.
  - `AdminPortAsync.cls` keeps the probe refused and asserts the admitted list is exactly `QUEUEDWRITES`.
  - `ToolWrite.cls`: bodyless, constant or port-composed (`COMPOSEDTYPES` on the declared port) ⇔ `SENDSBODY=0`, plus the new pairs.
  - `PortFixture.cls` `MUTATINGTYPES`; `ReadTool`, `ToolRoundTrip` `REFUSEEMPTY`, `SurfaceCoverage` rows; and any Auditing test pinning its action set.
- Client tests:
  - `audit-copy-dialog.spec.ts` and `audit-purge-dialog.spec.ts` (new): `purgeCutoff` round-trips, the typed-date gate, and the labels.
  - `auditing-config.page.spec.ts`: the in-flight status line, and `values` sent through `sendFor`.
  - `ui/browser/audit-copy-purge.browser-spec.mjs` (new):
    - `before` runs `assertThrowaway` and records the counts;
    - Copy to USER until the finished line, then assert the USER count through `irisSession`;
    - Purge with 0 days, the typed date, then the finished line, then the today-survives count;
    - DW-1337 `detectScreen` with each dialog open at 1280 light (`INVARIANTS`), 720 light (`name`, `min-width`, `overflow`) and 1280 dark (`contrast`), `route: 'security/auditing'`, with an empty `compare(...).fresh` and the `.ocu-dialog-body` scroll check;
    - `after` cleans USER.

**Acceptance Criteria:**

- **AC1 (copy).** Given Security › Auditing, when an administrator chooses Copy to namespace, picks `USER` and confirms, then the page reports the copy running on the instance and then finished. USER's audit database holds every record the instance held when it started, the instance's own records remain, and the write ran with the caller's privileges and left no OcuPilot marker.
- **AC2 (purge).** Given the Purge dialog with N days, when it is open, then it names the scope and the cut-off (today minus N, 00:00 instance time) and keeps Purge disabled until that date is typed. When it is confirmed, every record dated before the cut-off is removed, every record dated on or after it remains, and the audit database carries the vendor's own record of the purge.
- **AC3 (screen only, epic AC4).** Given governance has not shipped, when the tool set is built, then `security.auditing.purge` is not advertised, cannot be resolved by the model, and is absent from the Auditing screen's context `tools`, while the screen's Purge still performs it. `security.auditing.copy` is advertised.
- **AC4 (agent copy).** Given the agent proposes `security.auditing.copy` to `USER`, when it is minted, then the proposal is non-destructive, names `USER` in its diff, and copies nothing. When it is confirmed, the records are copied and the audit database carries OcuPilot's marker for that proposal (AD-15).
- **AC5 (privilege).** Given a caller holding the screen's pairs but not `%Admin_Operate:USE`, when either action or the copy proposal is attempted, then it is refused 403 naming that pair before any port call, and nothing is copied or purged.
- **AC6 (DW-1337).** Given either dialog open on Security › Auditing, when it is measured at 1280 px light, 720 px light and 1280 px dark, then no structural or contrast violation is found beyond the baseline.
- Epic AC3 (the agent's purge carries the full model, and its card states that the purge destroys the marker's record) and epic AC5 (the purge key defaults to disabled) belong to the Epic 14 change that registers purge. This story ships no agent path for them (open question R6).

## Spec Change Log

- 2026-09-24, spec gate (lead). The orchestrator answered R1-R6 (logged 12e290dc, by=merge_gate), each as recommended, and the spine carries them: AD-53 names the unadvertised tool, AD-26 names `QUEUEDWRITES`, AD-51 names the port-built body, AD-8's clause covers an endpoint the call must reach, with `%Admin_Operate:USE` its second case. Two pins are required: purge absent from the provider tool list, the dispatch lookup and the screen context's `tools` (`Test/AuditPurge.cls`), and a mutating queued type off `QUEUEDWRITES` still refused (`Test/AdminPortAsync.cls`). R5 stands. Epic AC3 and AC5 now sit in Story 14.2's block, and 12.3's block marks them delivered there. AC1's "reporting progress" is the running line, then the outcome, because the vendor exposes no count (inference, accepted).

## Review Triage Log

### 2026-09-24 — Review pass

- verdicts: 14 findings — high 0, medium 1, low 5, false 5, maybe-false 3
- findings:
  - `[medium]` `[patch]` Page spec's "registers both for the command bar" used `has()`, which the handler's own registration already satisfies — rewritten to run each action through `ScreenActions` and assert its dialog opens with no POST; mutation (drop the page's two `register` lines) → red.
  - `[maybe-false]` `[defer]` Purge's removal of pre-cut-off records never observed (fresh throwaways hold only today's rows) — deferred, medium (unverified); settle on an instance with a previous day's records.
  - `[low]` `[patch]` "Both buttons refuse" in flight was pinned only by `aria-disabled` — added a click during the held copy asserting no purge dialog opens; mutation (drop `operation() !== null` from the guard) → red.
  - `[low]` `[defer]` Purge cut-off on the browser calendar against the instance's `+$Horolog` (VG other finding) — the confirmed date is exactly what is purged; the fix needs an instance-clock surface; deferred.
  - `[low]` `[reject]` Page spec computes the PORT.TIMEOUT cut-off at assertion time and could drift across local midnight — a sub-second window; not worth a change.
  - `[false]` `[reject]` `AdminPortAsync` probe-not-admitted assertion adds no cover — redundant with the exact-roster equality above it, which is itself the pin; no bad outcome.
  - `[low]` `[defer]` Intent (a): the calendar reading diverges (R1a/R1b) — same root cause as the browser-calendar row; shares its deferred item.
  - `[maybe-false]` `[defer]` Intent (b): PORT.TIMEOUT tested only at the component with a stub; the shell banner may also show — already in `deferred:` (first item); settle by driving a >30 s copy.
  - `[maybe-false]` `[reject]` Intent (c): a `Failed` vendor task for these two types is not driven end to end — the task-to-envelope mapping is the shared `AdminPort` async path; if real it would be low.
  - `[false]` `[reject]` Intent (d): the agent-side refusal is tested with a denied pair, not a real principal — the same test proves the real principal lacks exactly that pair (`HoldsPair`), and the dispatch gate is where the agent's call stops before the mint.
  - `[low]` `[reject]` Intent (e): copy completeness checked by count (`>=`) — a record-for-record diff of ~30k rows buys little; unlikely to be met.
  - `[false]` `[reject]` Intent (f): `Prohibited.Target` resolves unadvertised tools — every agent-path caller reaches it only after `ResolveWire`, which refuses an unadvertised tool.
  - `[false]` `[reject]` Intent (g): the queued-write guard changed in the shared base port — the change is AD-26 as amended and is pinned by the exact `QUEUEDWRITES` roster and the refusal leg.
  - `[false]` `[reject]` Intent (h): the group heading reuses `auditListLabel` — it is a `STRINGS` key with its own Fixed strings row.

## Design Notes

**Governing ADs:** AD-2, AD-3, AD-5, AD-6, AD-7, AD-8, AD-10, AD-13, AD-14, AD-15, AD-16, AD-22, AD-24, AD-26, AD-27, AD-29, AD-35, AD-51, AD-52, AD-53, AD-56. The DW-1337 gate applies. AD-4 is not engaged, because no merge body is sent.

- **Why Security › Auditing, not the Logs audit viewer.**
  - The classic Copy and Purge pages sit beside System Events under Auditing. EXPERIENCE.md :148 and :168 place "Audit copy / purge" in Security and secrets, "attached to existing screens", as dialogs.
  - The Auditing screen already acts on its singleton through AD-53 row actions (`enable`, `disable`), so no route, entity type or prohibited arm changes.
  - The viewer's route admits row actions only, and its id is an audit record.
- **Why a port.** One `Endpoint` must answer the mint's read and carry the write. `Security.Audit.Record` `GET` needs a record key, so `AuditPort` answers `DATABASE` from `Security.Audit.Enabled` (the vendor gate still applies, AD-29) with the two argument fields empty. Merge can then set them, and they become the card's row and the fingerprint subject. The subject is the argument itself: nothing in the audit database is a precondition of copying or purging it (AD-51 adequacy).
- **Background and progress.** The vendor runs both types in a Work Queue worker. The port waits up to `AsyncTimeout()` and returns the terminal state (AD-26), and the page shows the live running state meanwhile.
  - The vendor exposes no count or percentage: `RunCopy` and `RunPurge` discard it.
  - Past 30 s, the answer is `PORT.TIMEOUT`, and the page says the work continues on the instance.
  - Named limitation: an agent copy past the bound confirms as failed while the vendor completes it. The vendor's `AuditChange` rows record the truth (inference: rare, and measured below).
- **Copy is the agent's tool, and delete-after-copy is not offered.** This follows the owner's "developer tool first". Copy destroys nothing, and the vendor audits it. With delete-after-copy it would be a purge through a side door.
- **Strings** (`auditDatabase*`):
  - "Audit database"; "Copy to namespace"; "Purge old records";
  - "Copy audit records"; "Namespace";
  - "Copies every record in the audit database into this namespace. Anyone who can read that namespace's database can read the copy. The originals stay where they are.";
  - "Copy"; "Purge audit records"; "Older than (days)";
  - "Removes every audit record on this instance dated before {date} 00:00, instance time, including the agent's audit markers from that period. This cannot be undone.";
  - "Type {date} to confirm"; "Purge";
  - "Copying to {namespace} on the instance since {time}"; "Purging records dated before {date} on the instance since {time}";
  - "Copied the audit database to {namespace}."; "Purged audit records dated before {date}.";
  - "Still running on the instance. It finishes in the background."

  Placeholders follow the existing parameterized-string idiom in `strings.ts`.
- **Integration ACs.** `AuditPort` and the unadvertised declaration are introduced. Their consumers in this story are the two tools through the screen route, the mint, the confirm and the dispatch (AC1–AC5).
  - Consumes: Story 7.4's Auditing screen and its row-action handler; AD-53's route; AD-26's async path.
  - Consumed-by: the Epic 14 story that registers purge and adds its policy key (it flips `ADVERTISED`).
- **Ledger inbox:** empty.
- **Measurements for the implement stage (on `ocupilot-b-ci` only; record each in Verification):**
  1. The vendor's `AuditChange` rows land for copy and for purge.
  2. The Work Queue worker runs as the caller: a principal holding exactly the pair set succeeds.
  3. The copy's duration on the throwaway's record count, to size the bound's reachability.
  4. The `Auditing` prohibited arm permits a `CopyNamespace` or `PurgeBefore` change because `SkippedFields` skips the subject (inference). If it refuses `UNCOVEREDFIELD`, append the two names to the `TYPEAUDITING` line of `PermittedChangeFields` after reading Epic 9's version (contended), and report it.

**Open questions for the spec gate (each with the recommendation this spec is built on; Rule 20 writes the first four into the spine):**

- **R1, AD-53 (new clause).** A write tool may declare itself unadvertised. The screen's caller reaches it, and no provider request, dispatch resolution or screen context does. The one case is `security.auditing.purge`, until Epic 14's policy registers it disabled by default (AD-22).
- **R2, AD-26.** Add `Security.Audit.Record` `COPY` and `PURGE` as Release 1 async entries: mutating, self-declared through `ShouldRunAsync()`, awaited within the bound. The DW-1279 refusal is narrowed to pairs outside `QUEUEDWRITES`, whose bodies carry no secret. AD-7 holds: the confirm or screen request originates the write and awaits its outcome, and the vendor worker runs it for that user (measurement 2).
- **R3, AD-8.** Add a named case: a tool whose endpoint queues declares the `AsyncResult` gate's `%Admin_Operate:USE`, since the port must poll through it.
- **R4, AD-51.** A tool's declared port may compose the vendor body of an action-style write from the tool's declared non-secret arguments carried in the port query, as `CONSTANTBODIES` supplies a fixed one.
- **R5, footprint.** The UI lives in `ui/src/app/areas/security/**`, not `logs/**`. The contended `screen-action-handler.ts` takes the one-parameter `sendFor` change, outside Epic 9's hunks (:533). Fallback: the page posts through `ApiService` with the handler's exported path constants and publishes the change event itself.
- **R6, Epic 14.** Epic 14's governance story block should carry epic AC3 and AC5 as acceptance lines: flip `ADVERTISED`, add the card's destroys-the-marker consequence, and add the default-disabled key. That is another epic's block, so the lead owns it.

## Verification

Slot B. Every IRIS MCP call carries `server: "ocupilot-slot-b"`. Every copy, purge and principal test runs on `ocupilot-b-ci` only (web 52777, super 1976). Run one test class per call, and wait until it lands in `%UnitTest_Result`.

**Commands:**

- `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/` (loop) -- expected: the bundle under test is the one just built.
- `cd ui && OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci node --test --test-concurrency=1 browser/audit-copy-purge.browser-spec.mjs browser/auditing-screen.browser-spec.mjs browser/auditing-write.browser-spec.mjs` (loop) -- expected: every leg passes.
- `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class <C>`, one call each for `AuditCopy`, `AuditPurge`, `AdminPortAsync`, `ToolWrite`, `ToolRoundTrip`, `ReadTool`, `SurfaceCoverage`, `PortGate`, `AuditingScreen`, `AuditingUpdate` and `Descriptor` (loop) -- expected: 0 failures each.
- `cd ui && npm run test:components && npm run test:tools && node tools/screen-mirror.mjs --check` (loop) -- expected: 0 failures, no drift.
- `uv run scripts/check-objectscript.py <changed .cls> && bash scripts/lint-docs.sh` (loop) -- expected: clean.
- The full ObjectScript sweep on `ocupilot-b-ci`, one class per call, with totals checked against `%UnitTest_Result` (once, before dev_complete) -- expected: 0 failed and a non-zero count.
- `cd ui && npm run build && npm test`, then `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS` (once, before dev_complete) -- expected: green, and a non-zero smoke count.
- The full browser suite is not run locally. CI's `browser` job runs it (Rule 29).

**Pinning tests and mutations (Rule 19; the implementer records each as `mutation: … → …`):**

- AC1: the `AuditCopy` screen-route leg and the browser copy leg. Mutation: `AuditPort.Body` sends `DeleteAfterCopy: true` (the "%SYS unchanged" assertion goes red).
- AC2: the `AuditPurge` today-survives leg and the browser purge leg. Mutation: `EndDateTime` sent as `""`. Component: the Purge button enabled before the typed date.
- AC3: the `AuditPurge` unadvertised leg. Mutation: `ProviderTools` ignores `advertised`.
- AC4: the `AuditCopy` mint and confirm leg. Mutation: `PortQuery` drops `CopyNamespace` (the vendor refuses, and the leg is red).
- AC5: the least-privilege leg. Mutation: drop `%Admin_Operate:USE` from `PrivilegePairs`.
- AC6: the browser structural assertion. Mutation: give the cut-off line a 1400px `min-inline-size`.

**Measured on `ocupilot-b-ci`, 2026-09-24:**

- M1: copy and purge each write `%System/%Security/AuditChange` as the caller: copy two rows ("Copy audit data", then "Copied N audit records", both carrying the target namespace), purge a "Delete audit records" row carrying `End Date: <cut-off> 00:00:00`.
- M2: a principal holding exactly the screen's pairs, the install code read and `%Admin_Operate:USE` copies through the route (200), and the vendor rows name that principal, so the Work Queue worker runs as the caller (`AuditCopy.TestAPrincipalHoldingExactlyThePairSetCopiesAsItself`).
- M3: 30,452 records copied through the port in 0.531 s; 30,579 through the route in 0.530 s (bound 30 s).
- M4: `Prohibited.Prohibits` permits both tools (`0`, no code): `SkippedFields` skips the subject. `PermittedChangeFields` is unchanged.
- `Prohibited.Target` resolves tools for the screen route too, so `Registry.Resolve` takes `pUnadvertised` (default 0); the proposal-path callers keep the default.
- `AuditPurge` ran with `docker exec -e OCUPILOT_ALLOW_AUDIT_PURGE=1`: the running throwaway predates the variable.
- Bundle initial total 1,337,502 bytes (below 1378 kB; no DW-1166 change).

**Runs:** `AuditCopy` 6/6 (run 27), `AuditPurge` 4/4 (run 24), `AdminPortAsync` 4/4 (run 30), `ToolWrite` 29, `ToolRoundTrip` 2, `ReadTool` 27, `SurfaceCoverage` 4, `PortGate` 4, `AuditingScreen` 9, `AuditingUpdate` 11, `Descriptor` 50, `ToolSetFull` 2, `ToolEmit` 11, `SecretSpelling` 2, `ScreenGrounding` 10, 0 failed each; `test:tools` 1375/1375, `test:components` 1076/1076; `audit-copy-purge`, `auditing-screen`, `auditing-write` browser specs green over the redeployed bundle.

- mutation: `AuditPort.Body` sends `DeleteAfterCopy: true` → `AuditCopy` red on the Body assertion and on the screen-route leg (the earlier copy emptied the instance's audit database); `audit-copy-purge` copy leg red on "the instance keeps its own: 0 against 272" (AC1)
- mutation: `AuditPort.Body` sends `EndDateTime` `""` for a purge → `AuditPurge.TestTheScreenRoutePurgesBeforeTodayAndKeepsToday` red on "every record dated today remains: 1 against 98" (AC2)
- mutation: `audit-purge-dialog.ts` `matches` ignores the typed date → `audit-purge-dialog.spec.ts` "keeps Purge aria-disabled until the cut-off is typed exactly" red (AC2)
- mutation: `Registry.ProviderTools` ignores `advertised` → `AuditPurge.TestThePurgeIsAbsentFromEveryRosterTheAgentSees` red on the provider list (AC3)
- mutation: `Registry.ResolveWire` ignores `advertised` → same leg red on the dispatch lookup, the unknown-tool refusal and "no proposal is written" (AC3)
- mutation: `Context.ScreenTools` ignores `advertised` → same leg red: the context carried `security_auditing_purge` (AC3)
- mutation: `AuditCopy.PortQuery` adds nothing → `AuditCopy` agent, screen-route and exact-pair legs red, 400 `PORT.VALIDATION` (AC4)
- mutation: `AuditCopy.PrivilegePairs` drops `%Admin_Operate:USE` → `AuditCopy.TestAPrincipalWithoutOperateIsRefusedByName` red (dispatch and route; the copy then ran before the poll was refused) and the declaration leg red (AC5)
- mutation: `[data-audit-purge-consequence] { min-inline-size: 1400px }` appended to `_components.scss`, rebuilt and redeployed → `audit-copy-purge` purge leg red on the dialog-body overflow (`scroll` 1400 > `client` 390) (AC6)
- mutation: `OcuPilotProbeAsyncWrite/PUT` added to `QUEUEDWRITES` → `AdminPortAsync` refusal leg and `TestOnlyTheNamedQueuedWritesAreAdmitted` red (DW-1279)
- mutation: the `Sequence` guard reads `IsMutating(...) && 0` → `AdminPortAsync.TestAMutatingRequestThatWouldQueueIsRefusedBeforeTheTaskRowIsWritten` red (DW-1279)
- mutation: `sendFor` forwards no `values` → `auditing-config.page.spec.ts` copy and purge legs red
- mutation: `STILL_RUNNING_CODE` misspelt → `auditing-config.page.spec.ts` PORT.TIMEOUT leg red

Each mutation was reverted, recompiled with subclasses or rebuilt and redeployed, and `git status --short` with `git diff --stat` read identical to before it.

- mutation: the page's two `register` lines removed → `auditing-config.page.spec.ts` command-bar leg red (review patch)
- mutation: `operation() !== null` dropped from `openDatabaseDialog` → the in-flight leg red (review patch)

**Stage verification (once, before dev_complete), `ocupilot-b-ci`:** whole `OcuPilot` package recompiled from the worktree source; full sweep 226 classes (runs 31-256), 2006 tests, 1 failed (`Prohibited.TestNoWriteToolAdmitsAnAlwaysProhibitedField`: a bodyless tool admitting its port-composed argument); fixed in `Test/Prohibited.cls` and rerun 12/12 (run 257); `AuditPurge` armed 4/4 (run 258). Total 227 classes, 2010 tests, 0 failed. `npm run build` initial total 1.34 MB (1,337,502 bytes as the handoff measured; budget 1378 kB unchanged); `npm test` tools 1375/1375 after adding the live-container refusal to `audit-copy-purge.browser-spec.mjs`, components 1076/1076; story browser specs 6/6 on the redeployed bundle; `smoke.sh` executed 48, passed 48; check-objectscript and lint-docs clean.

## Auto Run Result

Status: done
Blocking condition: none

**Change.** Security > Auditing gains an Audit database group: Copy to namespace (`security.auditing.copy`, advertised) and Purge old records (`security.auditing.purge`, unadvertised), each an AD-53 row action through a dialog. `Port/AuditPort` composes the vendor `Security.Audit.Record` COPY/PURGE bodies from the tool argument and answers a `DATABASE` read from `Security.Audit.Enabled`; `AdminPort` admits exactly `QUEUEDWRITES` to the vendor queue. `Base.ADVERTISED` keeps purge out of `ProviderTools`, `ResolveWire`, default `Resolve` and `ScreenTools`, while the screen route and the prohibited set reach it.

**Files.** New: `Port/AuditPort.cls`, `Screen/Tool/AuditCopy.cls`, `Screen/Tool/AuditPurge.cls`, `Test/AuditCopy.cls`, `Test/AuditPurge.cls`, `audit-copy-dialog.ts`, `audit-purge-dialog.ts` and their specs, `browser/audit-copy-purge.browser-spec.mjs`. Changed: `AdminPort.cls` (roster, `QUEUEDWRITES`, guard), `Tool/Base.cls`, `Tool/Registry.cls`, `Screen/Context.cls`, `Kernel/Proposal/Prohibited.cls` (one `Resolve` argument), `Descriptor/AuditingConfig.cls`, `auditing-config.page.ts`, `screen-action-handler.ts` (`sendFor` values only), `screen-actions.ts`, `screens.generated.ts`, `strings.ts`, `_components.scss`, EXPERIENCE.md :470, `ci-throwaway.sh` (arming), and the test rosters listed under `footprint_extensions`.

**Review.** 14 findings: 2 patched (1 medium, 1 low, both in `auditing-config.page.spec.ts`, each falsified by a mutation), 4 deferred (2 new `deferred:` items; 2 rows share existing items), 8 rejected with reasons in the Review Triage Log. Stage verification also fixed `Test/Prohibited.cls` (red in the full sweep) and the browser spec's missing live-container refusal (red in `angular-json.test.mjs`).

**Follow-up review:** false (no high patched, one medium patched).

**Verification.** See `## Verification`: full ObjectScript sweep 227 classes, 2010 tests, 0 failed on `ocupilot-b-ci`; client 1375 + 1076 green; story browser specs 6/6; smoke 48/48; bundle 1.34 MB under 1378 kB.

**Residual risks.** A purge's removal of past-dated records is unobserved (deferred); the purge cut-off uses the browser calendar (deferred); a PORT.TIMEOUT may also raise the shell's connectivity banner (deferred). `ocupilot-b-ci` predates `OCUPILOT_ALLOW_AUDIT_PURGE`, so `AuditPurge` ran with the variable passed to `docker exec`; a throwaway brought up from this tree sets it.
