---
title: 'Story 7.8: Terminate, suspend and resume a process'
type: 'feature'
created: '2026-09-23'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-7-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-7-6-run-suspend-resume-and-delete-a-task.md'
warnings: ['oversized']
deferred: []
footprint_extensions: # planned; this story's own members only (roster rule, 2026-09-23)
  - 'src/OcuPilot/Port/ProcessPort.cls' # new; outside every listed glob (TaskPort precedent)
  - 'src/OcuPilot/Port/AdminPort.cls' # shared-append: two parameter lines gain one entry each
  - 'src/OcuPilot/Kernel/Proposal/Prohibited.cls' # contended; DW-1499's two ReasonFor lines + two params in this branch's own REASON block (:59-77), off Epic 8's hunks
  - 'ui/src/app/core/screen-actions.ts' # Epic 8 modified (DESCRIPTOR_ACTION_LABELS); one ACTION_LABELS entry, off its hunk
  - 'src/OcuPilot/Test/ToolWrite.cls'
  - 'src/OcuPilot/Test/SurfaceCoverage.cls'
  - 'src/OcuPilot/Test/ReadTool.cls'
  - 'src/OcuPilot/Test/ToolRoundTrip.cls'
  - 'src/OcuPilot/Test/PortFixture.cls'
  - 'src/OcuPilot/Test/ProhibitedRoute.cls'
  - 'ui/tools/screen-mirror.test.mjs'
  - 'ui/src/app/core/screens.generated.ts' # regenerated
---

<intent-contract>

## Intent

**Problem:** Processes and Process details have no controls. Only the agent can suspend or resume a
process (5.12), and nobody can terminate one. The two process refusal sentences still name the agent
(DW-1499).

**Approach:** Put Suspend, Resume and Terminate on Processes and Process details. Each is one
operation with two callers (AD-53): the screen action and the agent's proposal.

- Suspend and Resume reuse 5.12's tools and gain `SCREENACTIONS`.
- Terminate is two new action-style tools, because the vendor's `Process` `TERMINATE` cannot carry
  the error-to-job flag:
  - `osmgmt.processes.terminate` goes through the vendor endpoint.
  - `osmgmt.processes.terminatewitherror` goes through a new `ProcessPort`, which calls
    `SYS.Process.Terminate(1)`.
- In the dialog, the flag picks the second tool through an undrawn declared action,
  `terminate-with-error`.

## Boundaries & Constraints

**Always:**

- The prohibited set decides refusals on the instance, whoever calls (AD-10). Terminate reaches the
  existing `process` arm by entity type: `IsOcuPilotProcess`, then the `JobType` allow-list.
- The screen caller mints no proposal, emits no marker and ignores the switches. The agent caller
  does all three.
- Pairs are checked before the fresh read. They are the screen's three pairs (AD-8, AD-29).
- Publish one `process` change event per write, then re-fetch.
- Every string lands in Fixed strings and `strings.ts`, append-only, and is published by the lead.
- The dialog is typed-name. The person types the pid.
- Destructive probes run only on `ocupilot-ci`, and only against a process the test or spec JOBs
  itself.

**Never:**

- No real terminate, suspend or resume of a system process or an OcuPilot process. This holds in any
  test and any mutation. Those refusals are pinned at the predicate, or on the test's own pid, where
  the vendor itself answers 409.
- No edit to `Write.cls`, `Mint.cls`, `Confirm.cls`, `Operation.cls`, `ScreenAction.cls`,
  `Screen/Registry.cls` or `screen-mirror.mjs`. No new `selfProtection` value. No new armed class.
  No edit to `scripts/ci-*.sh` or `ci.yml`.
- No `angular.json` budget change beyond the lead's port of `1967125`.
- No broadcast and no multi-select (16.6).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected | Error |
|---|---|---|---|
| Terminate | probe; row menu, command bar or Details; pid typed | dialog "Terminate <pid>", consequence, flag unchecked; button `aria-disabled` until the pid matches. 200 `{action:"deleted",target:{type:"process",scope:"instance",id}}`; the row leaves; Details reads `processDetailsGone`; no `^ERRORS` entry | mismatch: "Does not match", nothing sent |
| Terminate + flag | same, flag checked | sends `terminate-with-error`; the process ends; one `<RESJOB>` entry naming its `$J` in its namespace | – |
| Suspend / Resume | probe | no dialog; `State` re-reads with / without `SUSP` | no-op: 400 `TOOL.ARGUMENTS` `detail.problem` (5.12's `StateDiff`), nothing sent |
| Gone mid-dialog | process ends before Confirm | refusal shown, nothing terminated | the route's not-found answer |
| OcuPilot process | pid is `$Job`, or a running turn's job | 403 `PROHIBITED.OCUPILOTPROCESS` + `OCUPILOTPROCESSREASON` | nothing sent |
| System process | `JobType` off the allow-list (e.g. 36, 59) | 403 `PROHIBITED.SYSTEMPROCESS` + `SYSTEMPROCESSREASON` | nothing sent |
| Vendor guard | `CanBeTerminated` 0, not refused above | 409, flag on or off (the port mirrors `RunTerminate`) | normalized reason (AD-39) |
| Agent terminate | proposal, both tools | destructive card, typed pid, row `State: <state> → Terminated` (or `→ Terminated, with a <RESJOB> error logged`); one marker, one ledger row | a new `StartTimeUTC` on that pid → `PROPOSAL.TARGETCHANGED` |
| Short of the pair | no `%Admin_Operate:USE` | 403 `AUTH.NOPRIVILEGE`, failedPair `%Admin_Operate:USE`, before any read | – |

</intent-contract>

## Code Map

Measured 2026-09-23. Vendor source was read from `ocupilot-ci`. Probes ran on `ocupilot-ci` against
self-JOBbed processes only, and were all cleaned up.

- **Vendor `Process` (`[Hidden]`).**
  - Types: RESUME 11, SUSPEND 12, TERMINATE 13. `NeedsRequestBody` is 0 for all three.
  - `ResourcesOR` is `%Admin_Operate` for every type. `id` is required.
  - `RunTerminate` opens `SYS.Process` (404 if absent) and returns 409 `$$$UnableToKill` when
    `'CanBeTerminated`. Otherwise it calls `obj.Terminate()`, which **never passes `SendError`**,
    and answers 200 `{}` without waiting.
  - `CanBeTerminated` is 0 for the caller's own `$J` and for daemons. It is 1 for the Task Manager
    (36), Work Queue workers (59) and CSP servers (27).
  - A self-JOBbed probe reads `JobType` 2. After a terminate, `GET` answers 404 at once, and a
    suspended process terminates at once. With the flag on, the job runs `^%ETN` for under 0.3 s and
    leaves one `^ERRORS` entry (`$ZE <RESJOB>…`, `$J`) in its namespace.
  - No audit row is written: `%System/%Login/Terminate` is `Enabled=0` on this build.
  - A principal holding exactly the three Processes pairs can run
    `SYS.Process.Suspend/Resume/Terminate(0)/Terminate(1)`.
- **Tools.** `Screen/Tool/ProcessSuspend.cls` and `ProcessResume.cls` have no `SCREENACTIONS`.
  - Their docs (`ProcessSuspend :14-17`) claim terminate ships no tool.
  - `Write.PortQuery` (`:290`) is the hook for extra query parameters. `Operation.Query`
    (`:173-179`) applies it to the write and to the confirm re-read. Precedent: `ErrorDelete.PortQuery
    :195`.
  - `TaskDelete.cls` is the destructive action template. `TaskPort.cls` is the port-subclass template
    (`Invoke :42`).
- **Why two tools, not `SCREENVALUES`.** A non-secret value has to land in a settable field:
  `ScreenAction.cls :215-231` answers 500 otherwise. A bodyless tool has no settable field.
  `Mint.Merge` drops non-settable arguments (`Mint.cls :345-369`), and `PortQuery` sees only the
  stored payload. Carrying the flag as an argument would need edits to `Mint`, `Confirm` or `Write`,
  all of which Epic 8 has modified.
- **Kernel.**
  - `Prohibited.cls`: the `process` arm is at `:720-741`. Coverage is by entity type (`:149`), so the
    new tools are covered.
  - `ReasonFor :258-259` holds the two agent-naming literals.
  - The caller-neutral precedent is the parameters at `:59-77` plus `ReasonFor :252-257`.
  - `RefusalCopy.cls :22-47` pins those parameters. `Test/Prohibited.cls :476-521` pins each sentence
    as written exactly once.
- **AdminPort.**
  - `MUTATINGTYPES :208` and `BODYLESSTYPES :224` hold `Process/SUSPEND,Process/RESUME`. Append
    `Process/TERMINATE` to both.
  - The "TERMINATE and DELETE are deliberately absent" paragraph (`:160-172`) goes stale. It is
    append-only, so leave it; the lead corrects it at the Epic 7/8 merge (DW-1557 precedent).
- **Descriptors.**
  - `ProcessList.cls` has `rowActions []`, `emptyAgentKey ""`, id `single` `Pid`, and a doc
    (`:19-26`) that says terminate is absent.
  - `ProcessDetails.cls` is a detail archetype with id composite `["Pid"]` and `rowActions []`
    (doc `:28-31,43`).
  - Both refresh at 5/10/30/60 s.
  - `ScreenAction.ToolFor` (`:419-438`) matches tools by `DESCRIPTORCLASS`, and every process tool
    names `ProcessList`.
- **Client.**
  - `shell/screen-action-handler.ts`:
    - roster `:32-40`;
    - `UNDRAWN_ACTIONS :76` (7.2's precedent);
    - `DESTRUCTIVE_ACTIONS :88` (keyed by action id);
    - `DESTRUCTIVE_CONSEQUENCES :99`;
    - `PendingConfirm :154`;
    - `start :270`;
    - `confirmPending :227`, which sends no values;
    - `send :388-422`, which POSTs to `screen.toolIdentifier`.
  - `shell/typed-name-dialog.ts`: inputs `:83-92`, and `confirmed` is `void`. The checkbox idiom is
    `set-password-dialog.ts :62-67,155`. It is bound at `list-page.ts :77-86`.
  - `areas/os-management/process-details.page.ts` is a bespoke page. It binds `RefreshService`
    (`:134`), calls `clearAnswers` (`:132`, which empties the selection), and has no handler or
    dialog. The singleton-selection precedent is `auditing-config.page.ts :258-264`.
  - An open dialog does not pause `refresh.ts`. The pending `target` is captured when the dialog
    opens.
  - `core/screen-actions.ts` `ACTION_LABELS :61-76` has no `terminate`. Epic 8's hunk is at
    `DESCRIPTOR_ACTION_LABELS` (~`:87`).
- **Fault banner (DW-1155, DW-1189).**
  - `shell/fault-banner.ts :57-76`: `@if (visible)` wraps the strip, and `@if (serverFault)` wraps
    its control.
  - `visible` = `isBannerFault(fault())` (`:125`).
  - `ConnectivityService.note` (`connectivity.ts :161-202`) clears on any success, and a drained park
    re-raises. Unmounting and remounting in that gap is the lost-click and flicker window.
  - Specs: `fault-banner.spec.ts :196-207`, `fault-banner.wire.spec.ts :150`.
- **Tests and rosters.**
  - `Test/ProcessControl.cls` is armed (`OCUPILOT_ALLOW_PROCESS_CONTROL`, `OCUPILOT_ALLOW_PRINCIPALS`).
    Its helpers are `StartProbeProcess :655`, `ProcessState`, `JobTypeOf`, `SystemPid :806` and
    `StopProbeProcess :865`.
  - `ToolWrite`:
    - process constants `:44-50`;
    - `AssertActionWrite :923` hardcodes the subject `Pid,State`;
    - the TERMINATE-absent legs at `:1102-1105` and `:1186-1197` flip to "admitted", while
      `Process/DELETE` stays absent. Epic 8 rewrote the same leg.
  - Other rosters:
    - `ReadTool :93` (count 60, which becomes 62) and `:94`;
    - `ToolRoundTrip :34` `REFUSEEMPTY`;
    - `PortFixture :21`;
    - `SurfaceCoverage :101-102`;
    - `Descriptor :91,:620-636`;
    - `Test/ProcessDetails.cls :100` (no action, which becomes the declared ones);
    - `ProhibitedRoute :1421`, with the 7.6 precedent at `:1710`;
    - `ui/tools/self-protection.test.mjs :105-122`.
  - `ui/browser/processes.browser-spec.mjs :263-273` hard-codes 7 header labels; the actions column
    adds a hidden eighth. `process-control.browser-spec.mjs :147-180` starts and stops its probe.

## Tasks & Acceptance

**Precondition (lead, DW-1553):** `1967125`'s two hunks are applied to `ui/angular.json` and
`ui/tools/angular-json.test.mjs` (1185kB). If they are absent, HALT `blocked` naming DW-1553.

**Execution:**

- `src/OcuPilot/Port/ProcessPort.cls` (new) -- extends `AdminPort`. It overrides `Invoke` only for
  `Process`/`TERMINATE` with `pQuery(SENDERRORPARAM)` = 1:
  - check `$System.Security.Check("%Admin_Operate","USE")` (403 on failure);
  - switch to `%SYS` by AD-16;
  - `SYS.Process.%OpenId` (404 if absent);
  - `'CanBeTerminated` gives 409;
  - otherwise call `Terminate(1)`, drop the OREF, and answer 200 `{}` in `Invoke`'s own output shape.

  Every other call goes to `##super` with that parameter removed. The class names no `%Api.Admin.*`
  class (AD-2, AD-27).
- `src/OcuPilot/Screen/Tool/ProcessTerminate.cls` (new) -- `osmgmt.processes.terminate`, on
  `DESCRIPTORCLASS` `ProcessList`:
  - `READTYPE GET`, `WRITETYPE TERMINATE`, `SENDSBODY 0`, `DESTRUCTIVE 1`, `CHANGEACTION deleted`;
  - `SCREENACTIONS terminate`;
  - `%Admin_Operate:USE`;
  - `PRECONDITIONFIELD StartTimeUTC`, `FINGERPRINTSUBJECT` `Pid,StartTimeUTC`, and `READANSWERS`
    naming at least `StartTimeUTC`, which Processes' read does not declare (`Write.cls :153`;
    mirror `TaskDelete`);
  - `STATEFIELD State`, with `StateDiff`'s one row going from the fresh `State` to `STATEAFTER`
    "Terminated";
  - the refusal is only for an unreadable `State` or `StartTimeUTC`;
  - the description says OcuPilot's own processes and system processes are refused.
- `src/OcuPilot/Screen/Tool/ProcessTerminateWithError.cls` (new) -- extends `ProcessTerminate`.
  It changes `TOOLNAME` to `osmgmt.processes.terminatewitherror`, `SCREENACTIONS` to
  `terminate-with-error`, `PORTCLASS` to `OcuPilot.Port.ProcessPort` and `STATEAFTER` to
  "Terminated, with a <RESJOB> error logged". Its `PortQuery` sets the port's `SENDERRORPARAM` to 1,
  and its description names the error log.
- `src/OcuPilot/Screen/Tool/ProcessSuspend.cls`, `ProcessResume.cls` -- add `SCREENACTIONS suspend`
  and `resume`, and correct the terminate-absent sentences.
- `src/OcuPilot/Port/AdminPort.cls` -- append `Process/TERMINATE` to `MUTATINGTYPES` and
  `BODYLESSTYPES`.
- `src/OcuPilot/Kernel/Proposal/Prohibited.cls` -- after `:77`, add `OCUPILOTPROCESSREASON` and
  `SYSTEMPROCESSREASON` with the published sentences. `ReasonFor :258-259` returns them. Touch
  nothing else.
- `src/OcuPilot/Screen/Descriptor/ProcessList.cls`:
  - `rowActions` `suspend, resume, terminate, terminate-with-error`, all with `selfProtection ""`;
  - `entityLabelKey proposalEntityProcess`;
  - `emptyNextKey ""`, `emptyAgentKey processListEmptyAgent`;
  - rewrite the doc.
- `src/OcuPilot/Screen/Descriptor/ProcessDetails.cls` -- the same four `rowActions`; rewrite the doc.
- `ui/src/app/core/screen-actions.ts` -- `terminate: STRINGS.actionTerminate`, placed after `resume`.
- `ui/src/app/shell/screen-action-handler.ts`:
  - add `ProcessList` and `ProcessDetails` to the roster;
  - add `terminate` to `DESTRUCTIVE_ACTIONS`;
  - add `{terminate: STRINGS.processTerminateConsequence}` for both descriptors;
  - add `UNDRAWN_ACTIONS` `terminate-with-error` for both;
  - add a flag map `{terminate: {label: STRINGS.processTerminateErrorFlag, action:
    'terminate-with-error'}}`;
  - `PendingConfirm` gains `flagLabel` (`''` when none);
  - `confirmPending(flag = false)` sends the flag's action when checked;
  - an action address map `{ProcessDetails → ProcessList}` makes `send` POST to
    `osmgmt.processes/action`.
- `ui/src/app/shell/typed-name-dialog.ts`, `list-page.ts`:
  - add an optional `flagLabel` input that renders the set-password checkbox idiom
    (`data-slot="flag"`, unchecked) only when the label is non-empty;
  - `confirmed` emits the checkbox state, or `false`;
  - `list-page` binds `[flagLabel]` and passes the state to `confirmPending`.
- `ui/src/app/areas/os-management/process-details.page.ts`:
  - after each load, select the page's pid in its store;
  - render the typed-name dialog while `handler.pending()` is its own, and cancel it on destroy;
  - after a `process` change event, re-read, so that a terminate reads `processDetailsGone`.
- `ui/src/app/shell/fault-banner.ts` -- `FAULT_CLEAR_HOLD_MS = 1500`:
  - a clear keeps the strip mounted for the hold;
  - a fault raised within the hold reuses the same strip and control, with its content updated in
    place;
  - otherwise the strip unmounts when the hold ends.
- `ui/src/app/core/screens.generated.ts` -- regenerate.
- `src/OcuPilot/Test/ProcessTerminate.cls` (new, unarmed; terminates nothing):
  - both tools' declarations;
  - `StateDiff` over canned reads;
  - a mint of `terminate` over a canned read, and its `TARGETCHANGED` when `StartTimeUTC` moves;
  - `ProcessPort` answers 404 for an absent pid and 409 for `$Job`, and the test's process lives;
  - the port strips `SENDERRORPARAM` before `##super` on a `GET`;
  - `Prohibits` refuses both tools for `$Job` (`OCUPILOTPROCESS`) and for `SystemPid()`
    (`SYSTEMPROCESS`) — predicate only, never `Apply`.
- `src/OcuPilot/Test/ProcessControl.cls` (armed; append; its own probe only):
  - a real terminate through the screen route with the flag off: the probe is gone and no `^ERRORS`
    entry is left;
  - with the flag on, as a principal holding exactly the three pairs: gone, and one `<RESJOB>`
    entry naming its pid, which the test deletes;
  - an agent mint and confirm of each tool: one marker, one ledger row, the `State` row.
- Rosters (this story's members only):
  - `ToolWrite`: two action-write tests with subject `Pid,StartTimeUTC`, plus the TERMINATE legs;
  - `ReadTool` 62;
  - `ToolRoundTrip` ×2;
  - `PortFixture`, `SurfaceCoverage`, `Descriptor`, `Test/ProcessDetails`;
  - `ProhibitedRoute` short-of-pair Terminate leg;
  - `RefusalCopy` gains the two codes;
  - `self-protection.test.mjs` gets the two server/client pins;
  - `screen-mirror.test.mjs`.
- `ui/src/app/shell/screen-action-handler.spec.ts`:
  - Suspend and Resume are sent at once;
  - Terminate opens the dialog titled with the pid;
  - unchecked sends `terminate`, checked sends `terminate-with-error`;
  - Details posts to `osmgmt.processes`;
  - a `values` key is never sent.
- `typed-name-dialog.spec.ts`: the flag is present only with a label, and `confirmed` carries its
  state.
- `process-details.page.spec.ts`: selection, dialog, and the gone state after a `deleted` event.
- `fault-banner.spec.ts` and `.wire.spec.ts`:
  - clear then re-raise within the hold keeps the same strip and control nodes;
  - a lone clear unmounts after the hold;
  - update the immediate-`null` assertions.
- `ui/browser/processes.browser-spec.mjs` -- the header list gains the hidden Actions label.
- `ui/browser/process-actions.browser-spec.mjs` (new; `-ci` guard; probe as `process-control`
  starts it):
  - Suspend, then Resume, from the row menu, waiting for the re-read;
  - Terminate from the command bar with the rate set to 5 s, waiting past one tick before typing the
    pid and confirming; the row leaves;
  - a second probe is terminated with the flag from Process details, the page reads the gone state,
    and one `<RESJOB>` entry exists, which is then deleted;
  - a mismatch sends nothing.

**Acceptance Criteria:**

- **AC1:** Given a selected probe, when the user terminates it from Processes or Process details,
  then:
  - the dialog names the pid, states the consequence and offers the unchecked flag;
  - it releases only on the typed pid;
  - the process ends, with a `<RESJOB>` entry exactly when the flag is checked.

  *Pins:* `process-actions.browser-spec.mjs`; `ProcessControl`.
- **AC2:** Given `$Job` or a running turn's job, when any of the four process tools is attempted, then it is
  refused `PROHIBITED.OCUPILOTPROCESS` with its published sentence. *Pins:* `ProcessTerminate`
  (terminate tools); `ProcessControl` (existing suspend/resume legs).
- **AC3:** Given a system process, when a terminate is attempted, then it is refused on the
  instance, and no tool advertises terminating one. *Pin:* `ProcessTerminate`.
- **AC4:** Given a probe, when the user suspends and then resumes it, then no dialog opens and the
  `State` cell re-reads each change. *Pin:* the browser spec.
- **AC5:** Given an agent terminate proposal, when it is minted and confirmed, then:
  - it is a destructive, pid-typed card with the `State` row;
  - a replaced process (a new `StartTimeUTC`) is refused;
  - each tool writes one marker.

  *Pins:* `ProcessTerminate`; `ProcessControl`.
- **AC6:** Given a principal short of `%Admin_Operate:USE`, when it sends Terminate, then it gets 403
  `AUTH.NOPRIVILEGE` before any read. *Pin:* `ProhibitedRoute`.
- **AC7:** Given the two process codes, when their reason is read, then it equals the published
  sentence and names no caller. *Pins:* `RefusalCopy`; `self-protection.test.mjs`.
- **AC8 (DW-1155, DW-1189):** Given a raised fault banner, when the fault is cleared and re-raised
  within the hold, then the strip and its control are the same nodes; when it is cleared alone, the
  strip unmounts once the hold ends. *Pin:* `fault-banner.spec.ts`.
- **Integration AC (Rule 1):**
  - `ListPage` and Process details consume the `process` change event and re-read.
  - `ProcessTerminateWithError` reads and writes through `ProcessPort` and produces the `<RESJOB>`
    entry.

  Both are observed on `ocupilot-ci`.

## Spec Change Log

- 2026-09-23, lead spec gate: AD-52's sentence is in the spine; the seven strings are published at
  `EXPERIENCE.md:419-425` and appended to `strings.ts` (`actionTerminate`, `processTerminateConsequence`,
  `processTerminateErrorFlag`, `processRefusalOcuPilot`, `processRefusalSystem`, `processListEmptyAgent`,
  `proposalEntityProcess`) -- consume them. The card's after-values stay server-side. DW-1553's port of
  `1967125`'s two budget hunks awaits the orchestrator; implement does not start without it.

## Review Triage Log

## Design Notes

**Governing ADs:** AD-53, AD-51 (declared subject), AD-52 (`ProcessPort`), AD-56 (ii), AD-10,
AD-8, AD-29, AD-2, AD-27, AD-16, AD-3 (no template, so an empty field list), AD-6, AD-13, AD-14,
AD-15, AD-34, AD-39, AD-43, AD-5.

**Spine amendment for the lead (Rule 20, light path at the spec gate).** AD-52 gains one sentence:

> A tool-declared port may carry out a write the admin API cannot express, through the documented
> `%SYS` class that the vendor endpoint itself calls. It then reproduces that endpoint's gate (its
> `ResourcesOR()` resource at `USE`), its not-found answer and its guard before the call.

The case: `Process` `RunTerminate` never passes `SYS.Process.Terminate`'s `SendError`, so
`ProcessPort` does. This was measured on `ocupilot-ci`, including with a least-privileged principal.

The epic context's line "7.8 reuses `SCREENVALUES`" is superseded by the two-tool design; the Code
Map says why. AD-56 (ii) holds: `terminate-with-error` declares no value, and a `values` key is
refused.

**The subject is `Pid,StartTimeUTC`.** `StartTimeUTC` is the pid-reuse guard. `State` is left out,
because it moves on exactly the busy processes a terminate targets (AD-51's own case). The
`CanBeTerminated` 409 comes after the prohibited set, so a system process or an OcuPilot process
gets its own sentence rather than a generic one.

**Refusals are after the click.** A process rule cannot be computed on the client: `JobType` is
read only by `GET`, and turn pids and `$Job` are known only on the server. The row actions therefore
declare `selfProtection ""`, and the envelope's `reason` is shown with `role="alert"` (inference:
this satisfies EXPERIENCE `:220`). 7.2's `LASTALLHOLDER` is the precedent for a sentence refused at
the write alone.

**Audit.** The screen caller relies on the vendor's event, as AD-53 says. On this build that event
is disabled by default, which is the same as the classic portal.

**The empty state is unreachable in practice.** The read itself runs in a listed process
(inference), so the invitation names the list's own verbs instead of a create the list does not
have.

**Copy for the lead to publish** (each is an EXPERIENCE Fixed-strings row plus a `strings.ts` key):

- `actionTerminate`: "Terminate"
- `processTerminateConsequence`: "Terminating this process stops it at once, and it does not
  finish what it was doing. This cannot be undone."
- `processTerminateErrorFlag`: "Log a <RESJOB> error in its namespace's application error log"
- `processRefusalOcuPilot` (= `OCUPILOTPROCESSREASON`): "OcuPilot itself is running in this
  process, for this request or for an agent turn. It cannot be suspended, resumed or terminated from
  OcuPilot."
- `processRefusalSystem` (= `SYSTEMPROCESSREASON`): "This is an IRIS system process, and the
  instance relies on it. It cannot be suspended, resumed or terminated from OcuPilot."
- `processListEmptyAgent`: "suspend or terminate a process that has stopped responding"
- `proposalEntityProcess`: "Process"
- The card's after-values, which live on the server: "Terminated" and "Terminated, with a <RESJOB>
  error logged".

Reused keys: `actionSuspend`, `actionResume`, `formTypedNameConfirm`, `formTypedNameMismatch`,
`processDetailsGone`.

**Ledger inbox:**

- **DW-1155 — addressed** by the hold (AC8). The premise it was routed on, that a Terminate click is
  lost on a tick, is pinned false by the browser leg that waits past a tick.
- **DW-1189 — addressed** by the same hold.
- **DW-1499 — addressed** (AC7).
- **DW-1553** — the lead's precondition; this story makes no other budget change.

**Merge notes:**

- `AdminPort :160-172` is stale.
- The `ToolWrite` TERMINATE leg, `ReadTool :93`, `PortFixture :21` and the two `AdminPort` lines
  conflict with Epic 8 by construction.

**Consumes:**

- 5.12: the tools, the predicates and the `ProcessControl` helpers;
- 6.8: Process details;
- 7.1: the seam and the dialog;
- 7.2: `UNDRAWN_ACTIONS` and the checkbox idiom;
- 7.6: `TaskPort` and `TaskDelete` as templates.

**Consumed-by:** 16.6 (broadcast on the same list).

## Verification

Writes happen only on `ocupilot-ci` (web 52776), and only to self-JOBbed probes. Run one test class
per call and never re-submit. No container is stopped, removed or recreated.

**Targeted (loop):**

- `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.ProcessTerminate`
  -- expected green. Then run one call each for `ToolWrite`, `Descriptor`, `SurfaceCoverage`,
  `ReadTool`, `ToolRoundTrip`, `PortFixture`, `ProhibitedRoute`, `RefusalCopy`, `Prohibited` and
  `ProcessDetails`.
  - `ProcessControl` is armed and runs in CI. Locally, run its new methods through an unarmed
    temporary subclass, then delete that subclass (7.6 precedent).
- `cd ui && npm run test:tools && npm run test:components` -- expected green.
- `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`,
  then
  `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci node --test --test-concurrency=1 browser/process-actions.browser-spec.mjs browser/processes.browser-spec.mjs browser/process-control.browser-spec.mjs`
  -- expected green, with no probe process and no probe `^ERRORS` entry left.
- `uv run scripts/check-objectscript.py` -- expected clean.
- Rule 19 mutations. Record one per AC. Never follow a predicate mutation with a real write.
  - AC1: `ProcessPort` calls `Terminate(0)`. Expected red: the flag leg.
  - AC2 and AC3: remove each arm from `Prohibited.Process`. Expected red: `ProcessTerminate`.
  - AC4: `ProcessSuspend` `SCREENACTIONS ""`. Expected red: the Suspend leg.
  - AC5: drop `StartTimeUTC` from the subject. Expected red: the `TARGETCHANGED` test.
  - AC6: skip the pair gate. Expected red: `ProhibitedRoute`.
  - AC7: revert `ReasonFor :258`. Expected red: `RefusalCopy`.
  - AC8: remove the hold. Expected red: `fault-banner.spec.ts`.

**Once, before `dev_complete`:**

- Run the full ObjectScript sweep on `ocupilot-ci`, per class, and take the totals from the
  numeric-run-index probe.
- Run `bash scripts/smoke.sh --container ocupilot-ci --user _SYSTEM --password SYS`.
- Do not run the full browser suite locally (Rule 29).

## Auto Run Result

Status: ready-for-dev
Blocking condition: none

Planned only, and halted after planning as directed. This pass wrote no code.

- **Measured on `ocupilot-ci`** against self-JOBbed probes, all cleaned up:
  - the vendor's `TERMINATE` has no error flag;
  - `SYS.Process.Terminate(1)` works for a principal holding exactly the three Processes pairs;
  - a suspended process terminates at once.
- **For the lead at the spec gate:**
  - AD-52's one-sentence amendment (Rule 20);
  - publishing the copy block;
  - the DW-1553 budget port (`1967125`) before implement.
