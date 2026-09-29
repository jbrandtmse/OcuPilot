---
title: 'Story 16.6: Broadcast a message to processes'
type: 'feature'
created: '2026-09-28'
status: 'done'
baseline_revision: '4552cadf3d8daa7083a393f705b56b81f9cd9e9b'
baseline_commit: '4552cadf3d8daa7083a393f705b56b81f9cd9e9b'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-16-context.md'
warnings: ['oversized']
deferred:
  - summary: >-
      A broadcast whose every checked pid has ended is refused as not found (the RECIPIENTS read's
      404), not with the published PROCESS.BROADCAST.RECIPIENT sentence AC3 names.
    evidence: |-
      Port/ProcessPort.cls answers RECIPIENTS 404 when no pid of the set is running, as the intent's
      Boundaries specify; the screen route (Api/ScreenAction.cls:255-262) and the mint both stop on that
      read, so AC3's sentence and the matrix's 409 are reached only by a set that still names a running pid.
    location: >-
      src/OcuPilot/Port/ProcessPort.cls RECIPIENTS branch
    severity: low
---

<intent-contract>

## Intent

**Problem:** An administrator about to take the instance down cannot warn the people on its terminals from OcuPilot. The classic Processes page's Broadcast dialog is the only way, and OcuPilot's data table offers single selection only.

**Approach:** Processes gains checkboxes, the data table's first multi-select: an additive checked set that a descriptor declares, beside the unchanged single selection. A command-bar Broadcast opens a message dialog that names how many processes will receive it. One action write tool, `osmgmt.processes.broadcast`, carries it for both callers through `ProcessPort` to the admin API's own `Process` `BROADCAST`.

## Boundaries & Constraints

**Always:**

- **Target** (AD-13, AD-34): entity type `process`, scope `instance`, id = the pid set, comma-joined.
  - A new `integerset` id rule replaces `process:integer`. It canonicalizes to unique plain-decimal pids, ascending (`" 907,812, 812"` → `812,907`).
  - A single pid canonicalizes exactly as `integer` does today.
  - A set holds 1 to 20 pids.
- **Tool** (AD-51, AD-52, AD-53): `osmgmt.processes.broadcast`.
  - Declarations: `PORTCLASS` `OcuPilot.Port.ProcessPort`, `WRITETYPE` `BROADCAST`, `SENDSBODY 0`, `DESTRUCTIVE 0`.
  - Arguments: id argument `Pids`, the set as a string, and one declared non-secret argument `Message` (`SCREENVALUES broadcast=Message`).
  - Its pairs are the screen's three. Measured minimum: `%Admin_Operate:USE` + `%DB_IRISSYS:READ` to send, plus `%Admin_Manage:USE` for the recipients' `LIST`.
- **Fresh read** `RECIPIENTS`: a `ProcessPort` pseudo type over one admin `Process` `LIST`.
  - It answers `{Recipients: [{Pid, Username, CanReceiveBroadcast}], Absent: [pids], Message: ""}`, and 404 when no pid is found.
  - `READANSWERS` names those three, `PRECONDITIONFIELD` is `Recipients` and `FINGERPRINTSUBJECT` is `Recipients,Absent`.
- **Eligibility** is `CanReceiveBroadcast`, the vendor's own flag for a foreground terminal job (JobType 1 or 3). An absent or ineligible pid refuses the whole broadcast; there is never a partial send.
  - At the mint, `StateDiff` refuses with the published sentence.
  - At the write, for both callers, the port re-reads the recipients and refuses 409 `PROCESS.BROADCAST.RECIPIENT` before any vendor call.
- **Body** (AD-51's third named case): the port composes `{Message, PidList: [integers]}` from the stored `Message` and the canonical id, and refuses any caller body. `Snippet` renders the same REST call (AD-59).
- **Message:** one `MessageProblem`, used by `ArgumentProblem`, the pre-mint check and `ScreenActionDelta`.
  - It holds at least one non-space character and at most 255 characters.
  - It refuses `\p{Cc}` (C0 including TAB, CR and LF; DEL; C1) and an unpaired surrogate.
  - It is sent exactly as given. The vendor frames it as `BEL CR LF ***<message>*** CR LF` on each recipient's terminal (measured).
- **Card** (agent): the merge's `Message` row, and one `Recipients` row whose after-value names the count and the pids (`3 processes: 812, 907, 1033`; `1 process: 812`).
- **Prohibited set** (AD-10): the process arm (`OCUPILOTPROCESS`, `SYSTEMPROCESS`, `ReviewedFewOnly`) is not evaluated for a `BROADCAST` write, keyed on the tool's write type. Every system process and every process OcuPilot runs in reads `CanReceiveBroadcast` 0 (measured), so the eligibility refusal refuses them for both callers.
- **Read** (AD-24, AD-36): `ProcessList`'s `read.fields` and `context.fields` gain `CanReceiveBroadcast`, with no column.
- **Multi-select declaration** (AD-5, AD-19): the new optional key `multiSelect {action, eligible, max, ineligibleKey}`, validated alike by `Screen/Registry.cls` and `ui/tools/screen-mirror.mjs`.
  - `action` names one of the screen's `rowActions`.
  - `eligible` names one of its `read.fields`.
  - `max` is 1 to 1000.
  - `ineligibleKey` is a strings key.
  - It is allowed only on a `list` with a `read` and a `table`.
  - `ProcessList` declares `{"action": "broadcast", "eligible": "CanReceiveBroadcast", "max": 20, "ineligibleKey": "processBroadcastIneligible"}` and appends row action `broadcast`.
  - A test pins `max` equal to the port's cap.
- **Table, only where declared:**
  - The checked set lives in `ScreenStore`, apart from `selection`, and is never persisted.
  - The checkbox sits at the leading edge of the name cell, and a header "Check all" checks the eligible rows in view.
  - Space toggles the active row's check, and a checkbox click toggles only that check.
  - An ineligible row's checkbox is `aria-disabled` and carries the declared reason.
  - Checks survive auto-refresh; a row that leaves the view or turns ineligible is unchecked.
  - Single selection, `aria-selected`, the arrows, Enter, the row menu and CSV are unchanged, and there is no `aria-multiselectable`.
- **Command bar and command box:** the declared action is left out of the row menu. On the command bar and in the command box it acts on the checked set, and it is `aria-disabled` with "Check one or more rows first" at 0 checked, or "Check at most <n> rows" above `max`.
- **Broadcast dialog** (new, non-destructive):
  - The title is "Broadcast to <n> processes", or "Broadcast to 1 process".
  - It has a single-line Message field with `maxlength` 255 and initial focus, plus Send (primary) and Cancel.
  - Send trims the message and posts one `{action: "broadcast", id: "<pids>", values: {Message}}`.
  - On 200 the checks clear, and the body reads "Message sent." with Close.
  - A refusal shows the envelope's reason in the dialog.
- **Record:**
  - The vendor writes no audit row (measured, auditing on), so this is the fourth AD-15 and AD-53 no-vendor-event case.
  - The agent's caller keeps its marker and ledger row; the ledger carries the message as an argument.
  - The screen's caller leaves no record.
  - The read-back is AD-58's action-style verdict: the instance keeps no message to compare.
- **Governance:** `osmgmt.processes.broadcast` is appended to `Baseline.cls`, enabled.
- **Copy:** EXPERIENCE.md is edited in place and stays at 993 lines; `strings.ts` is appended. The kernel's reason for `PROCESS.BROADCAST.RECIPIENT` equals its published sentence.

**Never:**

- No new port, no AD-27 case, no read source kind and no REST route.
- Nothing calls `$ZU(94)`, `%SYSTEM.Process.Broadcast` or `PID^BROADCAS` directly.
- No partial send, no pid sent twice, and no send inside a transaction.
- No checkbox, check or Space handling on any screen that does not declare `multiSelect`, and no change to Process details.
- No test sends a message to a process it did not start, and nothing is sent on `ocupilot`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Screen send | two terminal sessions checked; Send "Down at 18:00" | title "Broadcast to 2 processes"; one POST; each terminal shows `***Down at 18:00***` once; "Message sent."; checks cleared | none |
| Agent | `{Pids: "907, 812", Message}` | the card shows target `812,907`, the `Message` row and `2 processes: 812, 907`; Confirm sends; marker and ledger row written | none |
| Ineligible row | a daemon, a CSP server, a JOB'd process | checkbox `aria-disabled`; reason "Only a terminal session can receive a broadcast." | Space and click do nothing |
| Nothing or too many checked | 0 checked; 21 checked | Broadcast `aria-disabled`: "Check one or more rows first"; "Check at most 20 rows" | none |
| Recipient ended or ineligible | a set holding an ended or JOB'd pid, from either caller | nothing sent to any pid | 409 `PROCESS.BROADCAST.RECIPIENT` with the published sentence |
| Bad message | "", "   ", 256 characters, ESC, TAB, `$C(155)`, an unpaired surrogate | refused; nothing sent | agent: 400 `TOOL.ARGUMENTS`, before the mint; screen: the envelope's reason in the dialog |
| Good message | 255 characters; "é"; a non-BMP pair | sent as given | none |
| Bad set | "", "abc", "0", 21 pids | refused; nothing sent | agent: 400 `TOOL.ARGUMENTS`, before the mint; screen: 400 `PORT.VALIDATION` |
| Moved | between mint and confirm a recipient ends, or its `CanReceiveBroadcast` or `Username` changes | refused | `PROPOSAL.TARGETCHANGED` |
| Refresh | an auto-refresh tick in which a checked row ends | the other checks kept; the ended row unchecked | none |
| Other tables | any screen that does not declare `multiSelect` | no checkbox; Space does nothing; everything as today | none |
| Suspend unchanged | suspend a daemon, or the request's own job | still refused by the process arm | `PROHIBITED.SYSTEMPROCESS` / `PROHIBITED.OCUPILOTPROCESS` |

</intent-contract>

## Code Map

- **Vendor (read-only):**
  - `%Api.Admin.Endpoints.Process` is hidden; a copy is at `scratchpad/epic-16/16-6/process-cls.txt`. It has `TYPEBROADCAST` 10 and a strict `ValidateRequest` over `{Message, PidList}`. Its `RunBroadcast` JOBs `PID^BROADCAS` once per member and answers `{}` whatever happens. `ResourcesOR` is `%Admin_Operate`, and the call is synchronous.
  - `irissys/BROADCAS.int:47-63` frames the message and applies its gates.
  - `irissys/%SYS/ProcessQuery.cls:2259` retrieves `CanReceiveBroadcast` (FOREJOB or FORAPPJOB).
  - `irissys/%CSP/UI/Portal/Dialog/Broadcast.cls` is the classic dialog: a multi-select table where only eligible rows can be checked, under `%Admin_Operate:USE`.
- **Ports:**
  - `src/OcuPilot/Port/ProcessPort.cls` -- `Invoke` :41, `SnippetForm` :117, `Snippet` :127. Every non-terminate call defers to `##super`.
  - Composed-body models:
    - `Port/AuditPort.cls`: `COMPOSEDTYPES` :55, the build :87-95 and :347-368, the `Snippet` :380-387.
    - `Port/OAuthResourceServerPort.cls` :75, :128-140, and :361-381, where a fresh read carries the argument empty.
  - A published 409 answered from a port: `Port/BackgroundTaskPort.cls:299`.
  - `Port/AdminPort.cls`:
    - `MUTATINGTYPES` :305. `BODYLESSTYPES` is :321, where this type does **not** go.
    - The mutating-body object check :844-848.
  - `Port/AdminRoutes.cls:140` already routes `BROADCAST` to `POST /process/broadcast`.
- **Tool framework:**
  - `src/OcuPilot/Screen/Tool/Write.cls` -- `READANSWERS` :170, `SCREENVALUES` :207, `PortQuery` :430, `StateDiff` :476, `MintClass` :485, `ScreenActionDelta` :597, `InputSchema` :687, `ArgumentProblem` :799.
  - The subject/precondition guard is at `Screen/Registry.cls:2458`.
  - Models:
    - `Screen/Tool/ProcessSuspend.cls` for the pairs and the schema override.
    - `Screen/Tool/AuditCopy.cls:87-121` for a declared argument checked by one function for both callers.
    - `Screen/Tool/BackgroundTaskMint.cls` for a pre-mint check.
- **Screen-action route:** `src/OcuPilot/Api/ScreenAction.cls` -- body keys :101-109, row-action admission :151, values :453-491. Values must be non-empty strings.
- **Kernel:**
  - `src/OcuPilot/Kernel/EntityRef.cls` -- `IDRULES` :59, `IDRULENAMES` :64, rule dispatch :247-252, `PlainInteger` :268.
  - `Kernel/Proposal/Prohibited.cls`:
    - The process branch :922-925, `Process` :1754 and `Target` :2836.
    - The wallet and user arms key on the write type, which is the model.
  - `Kernel/Proposal/ReadBack.cls` `KindOf` :206.
  - `Kernel/Governance/Baseline.cls` -- append after :99.
  - `Api/Error.cls:3965-3967` is the published-code model.
- **Descriptor and registries:**
  - `src/OcuPilot/Screen/Descriptor/ProcessList.cls` -- its doc at :27-33 says the read omits `CanReceiveBroadcast`; rewrite it.
  - `Screen/Registry.cls` -- `DECLARATIONKEYS` :396. `RowTargetProblem` :3413 and its call at :310 are the model for a new key.
  - `ui/tools/screen-mirror.mjs`:
    - `DECLARATION_KEYS` :1018 and `IMPLEMENTED_ID_RULES` :162.
    - The `rowTarget` precedent: `rowTargetProblem` :2274, called at :2793, emitted at :2852, typed at :3169.
- **Client:**
  - `ui/src/app/core/screen-store.ts` -- `selected` :125, `applyTick` :286, `selection()` :320, `clearAnswers`.
  - `ui/src/app/shell/data-table.ts`:
    - Row template :306-381, `menuItems` :826-845, `onGridKeydown` :966.
    - `measureLabels` :1125, `onRowClick` :1321, `sync()` :1461, `select()` :1605, `onGridFocusIn`.
  - `ui/src/app/shell/command-bar.ts` `resolved` :414-455; `command-box.ts` :505-520.
  - `ui/src/app/shell/screen-action-handler.ts` -- `PendingKind` :304, `startFor` :494, `send` :694.
  - `screen-action-dialogs.ts` :27-68, with `set-password-dialog.ts` as the value-dialog model.
  - `ui/src/app/core/entity-ref.ts` holds the id rules.
  - `ui/src/app/core/screen-actions.ts` -- `ACTION_LABELS` :72-93, `DESCRIPTOR_ACTION_LABELS` :104-140.
  - `ui/src/app/core/strings.ts`:
    - Append before `} as const;` at :3442.
    - Reuse `logViewerColumnMessage` 'Message', `actionSend`, `actionCancel` and `auditDialogClose` 'Close'.
  - `ui/src/styles/_components.scss` -- the 24px checkbox pattern is at :5910-5919; append new rules at the end.
- **EXPERIENCE.md** (`_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/`): :173 Dialogs, :294 selection reasons, :320 Processes strings, :603 command-bar, :648 Selection, :869 Tables.
- **Test models:**
  - `Test/ProcessControl.cls` -- `EnsureThreePairsPrincipal` :1204 and `RemoveThreePairsPrincipal` :1235.
  - `Test/BackgroundTasksLive.cls` principals :455.
  - `Test/RowTargetCorpus.cls`; `Test/DeclarationCorpus.cls` :129.
  - `ui/browser/processes.browser-spec.mjs` `irisSession` :74.
  - `ui/browser/structural-walk.mjs` `MIN_WIDTH_SOURCES` :133 (append only).

## Tasks & Acceptance

**Execution:**

**Server:**

- `src/OcuPilot/Kernel/EntityRef.cls`, `ui/src/app/core/entity-ref.ts`, `ui/tools/screen-mirror.mjs` -- Add the `integerset` rule (appended to `IDRULENAMES` and `IMPLEMENTED_ID_RULES`) and set `process:integerset` in `IDRULES`. This gives one canonical key per pid set (AD-13), and a value it cannot read falls back as `integer` does.
- `src/OcuPilot/Port/ProcessPort.cls`:
  - Add `BROADCASTMAXPIDS` 20.
  - Add the `RECIPIENTS` read.
  - For `BROADCAST`:
    1. Parse and cap the id (400 `PORT.VALIDATION`).
    2. Refuse a caller body.
    3. Re-read the recipients, and answer 409 `PROCESS.BROADCAST.RECIPIENT` before any vendor call.
    4. Compose the body and call `##super`.
  - `SnippetForm`/`Snippet` mirror that branch.
- `src/OcuPilot/Port/AdminPort.cls` -- Append `Process/BROADCAST` to `MUTATINGTYPES`.
- `src/OcuPilot/Screen/Tool/ProcessBroadcast.cls` (new) -- Per Boundaries:
  - `MessageProblem` and `PidsProblem`.
  - `StateDiff`: its refusal is the published sentence, and it adds the `Recipients` row.
  - `PortQuery` passes `Message`.
  - `InputSchema` describes both arguments: comma-separated pids the Processes read reports `CanReceiveBroadcast` true, at most 20.
  - `PrivilegePairs` as in `ProcessSuspend`.
- `src/OcuPilot/Screen/Tool/ProcessBroadcastMint.cls` (new) -- Run both problems before the kernel mint, answering 400 `TOOL.ARGUMENTS`, as `BackgroundTaskMint` does.
- `src/OcuPilot/Kernel/Proposal/Prohibited.cls` -- The process branch answers "not prohibited" for a `BROADCAST` write before its target read. The doc names why.
- `src/OcuPilot/Api/Error.cls` -- Append `PROCESS.BROADCAST.RECIPIENT` (409) with its reason.
- `src/OcuPilot/Screen/Descriptor/ProcessList.cls` -- Add `CanReceiveBroadcast` to the read and context fields, row action `broadcast`, and `multiSelect`; rewrite the doc.
- `src/OcuPilot/Screen/Registry.cls`, `ui/tools/screen-mirror.mjs`:
  - Validate `multiSelect` alike (`MultiSelectProblem`/`multiSelectProblem`).
  - Append it to `DECLARATIONKEYS`/`DECLARATION_KEYS`.
  - Emit it `?? null`, with its interface.
  - Add a new shared `src/OcuPilot/Test/MultiSelectCorpus.cls`.
  - `DeclarationCorpus` carries the key and an absent-is-sound case.
- `src/OcuPilot/Kernel/Governance/Baseline.cls` -- Append `"osmgmt.processes.broadcast"`, `true`.

**Client:**

- `ui/src/app/core/screen-store.ts` -- `checked()`, `setChecked()`, `toggleChecked()`. `applyTick` leaves them alone; `clearAnswers` and sign-out drop them.
- `ui/src/app/shell/data-table.ts`, with `_components.scss` appended -- Per Boundaries, every branch gated on `screen.multiSelect`. `sync()` prunes checks, and `measureLabels` counts the header checkbox.
- `ui/src/app/shell/command-bar.ts`, `command-box.ts`, `screen-action-handler.ts` -- The declared action reads the checked set and its reasons, the row menu drops it, and a `broadcast` pending kind is added.
- `ui/src/app/shell/broadcast-dialog.ts` (new), `screen-action-dialogs.ts` -- The dialog.
- `ui/src/app/core/screen-actions.ts` -- `broadcast` "Broadcast"; the `ProcessList` entry.
- `ui/src/app/core/screens.generated.ts` -- Regenerate.
- `ui/src/app/core/strings.ts` and EXPERIENCE.md -- Each key is cited `/** EXPERIENCE.md:NNN */`. EXPERIENCE.md is edited in place with `[ADDED 2026-09-28 - Story 16.6]` and stays at 993 lines:
  - :320 gains "Broadcast", "Broadcast to <n> processes", "Broadcast to 1 process", "Message sent.", "Only a terminal session can receive a broadcast." and the refusal "At least one of these processes has ended or is not a terminal session, so nothing was sent.".
  - :294 gains "Check one or more rows first", "Check at most <n> rows" and "Check all".
  - :648 replaces "(Broadcast's multi-select is P1)" with the checked set and its Space key.
  - :603, :869 and :173 name the checked-set action, Space and the broadcast dialog.

**Rosters (additive only):**

| File | Change |
|---|---|
| `Test/ReadTool.cls:93-94` | 136→137 tools and 80→81 writes; the name |
| `Test/SurfaceCoverage.cls` | a tool row after :153 |
| `Test/ToolRoundTrip.cls:41` | `osmgmt.processes.broadcast:TOOL.ARGUMENTS` |
| `Test/ToolWrite.cls:1192`, `Test/PortFixture.cls:21` | `Process/BROADCAST`, mutating and not bodyless; its own action-write leg, because `AssertActionWrite` :1027 expects no settable field |
| `Test/Descriptor.cls:639-682` | read fields gain `CanReceiveBroadcast` (the :662 absence assertion becomes presence); row actions gain `broadcast`; `multiSelect` |
| `Test/EntityRef.cls`, `ui/tools/entity-ref.test.mjs:261` | `process` becomes `integerset` |
| `ui/tools/screen-mirror.test.mjs:1000-1009` | ProcessList's row actions pinned apart from ProcessDetails' |
| `ui/tools/screen-actions.test.mjs:110-122` | the label |
| `ui/tools/self-protection.test.mjs:351-360` | the published-code pin, modeled on `BACKGROUND_TASK_REFUSAL` |
| `ui/browser/process-actions.browser-spec.mjs:264` | the command-bar roster gains Broadcast; the row menu at :265 is unchanged |

**Tests:**

- `src/OcuPilot/Test/ProcessBroadcast.cls` (new, canned port answers, ≤500 lines):
  - the declarations;
  - `integerset` on each spelling;
  - both problems, per the matrix;
  - the `RECIPIENTS` mapping and its 404;
  - the `StateDiff` refusals and the count row;
  - the fingerprint refusing a moved recipient;
  - the port's composed body (deduplicated integers), its caller-body refusal and its 409 before any vendor call;
  - `Snippet`;
  - the reason equal to the published sentence;
  - a `BROADCAST` passing the process arm while a `SUSPEND` of a daemon is still refused;
  - `max` equal to `BROADCASTMAXPIDS`.
- `src/OcuPilot/Test/ProcessBroadcastLive.cls` (new). It needs no arming variable, because it acts only on processes it spawns.
  - `Receiver(pSeconds)` writes `$J` to a test global and `PID=<pid>` to its principal device, then `Hang`s.
  - Receivers are spawned with `$ZF(-100, "/ASYNC /STDOUT=... /STDERR=...", <binary directory>_"iris", "session", <instance>, "-U", $NAMESPACE, "##class(OcuPilot.Test.ProcessBroadcastLive).Receiver(60)")` and terminated in teardown.
  - The legs:
    - the Processes read reports a receiver's `CanReceiveBroadcast` true and a JOB'd process's false;
    - the screen action sends to two receivers, and each output file shows `***<token>***` once within 5 s;
    - a set holding a JOB'd or ended pid answers 409, and its receiver gets nothing;
    - a purpose-built principal holding the screen's three pairs succeeds (never `%Operator`);
    - the agent's mint names the count, and Confirm delivers the message with the marker.
- `ui/browser/process-broadcast.browser-spec.mjs` (new, `-ci` throwaway):
  - It spawns a receiver through `docker exec` (no `-t`, the `Receiver(120)` entry) and reads the pid from `PID=`.
  - A daemon row's checkbox is disabled, with the reason.
  - Space checks the receiver, and Broadcast opens "Broadcast to 1 process".
  - After Send, the receiver's stdout shows the message and the dialog reads "Message sent.".
  - The DW-1337 gate runs in both themes with the checkboxes drawn and the dialog open, with no new allowance.
  - `after` terminates the receiver inside a `finally`.
- Component and tools tests:
  - `data-table.spec.ts`:
    - an undeclared screen has no checkbox and ignores Space;
    - a declared one toggles, refuses an ineligible row, checks all eligible rows only, prunes on refresh, and keeps exactly one `aria-selected`.
  - `command-bar.spec.ts` and `command-box.spec.ts`: the reasons at 0 and above `max`; absent from the row menu.
  - `broadcast-dialog.spec.ts` and `screen-action-handler.spec.ts`: the title's count, one POST shape, Cancel sending nothing, the refusal shown, the checks cleared on 200.
  - `ui/tools/screen-store.test.mjs`, `entity-ref.test.mjs`, `screen-mirror.test.mjs` (the corpus).

- The two limits are stated before they are hit (orchestrator, 2026-09-28): the 255-character message limit and the 20-recipient cap are named in this story's Fixed strings row and stated in the Broadcast dialog -- a hint under the Message field names 255 characters, and the dialog or the command bar names the 20-process cap (the over-cap reason already does) -- each pinned by a test.

**Acceptance Criteria:**

- Given terminal sessions checked on Processes, when the user broadcasts a message, then the dialog first names how many will receive it, and each checked process receives it once. Given the same broadcast proposed by the agent, then its card names the count, and Confirm sends it.
- Given the shared data table, when a screen declares `multiSelect`, then it offers checks beside its unchanged single selection; a screen that does not declare it behaves exactly as before (keyboard, focus, row menu, DW-1337).
- Given a set naming a process that cannot receive or has ended, when either caller broadcasts, then nothing is sent and the refusal is the published sentence.
- Given a message that is empty, longer than 255 characters or holds a control character, when either caller sends it, then it is refused and nothing is sent.

### Review Findings

Code review, 2026-09-29 (four layers, full-opus: blind-hunter, edge-case-hunter, verification-gap, acceptance-auditor). 1 decision, 12 patches, 3 closed, 20 rejected. No high; no AD violation in product code (AD-5, 10, 12, 13, 19, 22, 51, 52/53, 58, 59 checked). Rule 3 is met by `process-broadcast.browser-spec.mjs` and `ProcessBroadcastLive`.

- [x] [Review][Decision] An ineligible row's reason reaches no pointer user and is not announced through the grid: it sits only in `aria-description` on a checkbox that never holds focus, and Space or a click on it is silent. This is the lead's UX question. EXPERIENCE.md's letter is met: the :648 Selection rule says `aria-disabled` with its reason, and the Mechanism's tooltip clause binds only a control that takes DOM focus. Its intent ("names its reason", "always announced") is not. The surface is a UX call against :646 (no `title`, no tooltip on an uncut cell). Medium; DW-1815, decision-pending, for the epic's decision sheet.
- [x] [Review][Patch] A checkbox click left DOM focus on the checkbox, off the grid (EXPERIENCE.md:869), so Space then toggled the active row rather than the clicked one [ui/src/app/shell/data-table.ts:1424]
- [x] [Review][Patch] The dialog's refusal was never drawn through the path Processes renders [ui/src/app/shell/broadcast-dialog.spec.ts:224]
- [x] [Review][Patch] The in-flight guard behind "one Send is one request" was untested [ui/src/app/shell/screen-action-handler.spec.ts:762]
- [x] [Review][Patch] `Registry.Validate`'s `MultiSelectProblem` call was untested (AD-5's server half); a fixture registry now pins it [src/OcuPilot/Test/Descriptor.cls:1986]
- [x] [Review][Patch] The browser spec required exactly one row after a substring pid filter, so a live pid holding the target's digits timed it out [ui/browser/process-broadcast.browser-spec.mjs:158]
- [x] [Review][Patch] An Enter that commits an IME composition sent the message [ui/src/app/shell/broadcast-dialog.ts:166]
- [x] [Review][Patch] A Send answered after its dialog was closed and reopened marked the reopened dialog sent [ui/src/app/shell/screen-action-handler.ts:513]
- [x] [Review][Patch] `stopReceiver` asserted before killing the `docker exec` child, so a failed terminate left the child running [ui/browser/process-broadcast.browser-spec.mjs:77]
- [x] [Review][Patch] The class doc said the confirm refuses with the published sentence; it refuses as a changed target [src/OcuPilot/Screen/Tool/ProcessBroadcast.cls:19]
- [x] [Review][Patch] Stale counts: "four max cases" (five), "thirty-two keys" (34), "four write tools" (five), and the Processes row-action comment and assertion message [src/OcuPilot/Test/Descriptor.cls:1951]
- [x] [Review][Patch] `EnsurePrincipal`'s Catch did not restore `$NAMESPACE` first (AD-16's letter, low: every path restored it after the Try, and the Catch names no class outside `%SYS`) [src/OcuPilot/Test/ProcessBroadcastLive.cls:426]
- [x] [Review][Patch] EXPERIENCE.md's Keyboard model table lacked Space; it is folded into the data-table Enter row, and the file is still 993 lines [EXPERIENCE.md:821]
- [x] [Review][Defer] Check all has no keyboard path [ui/src/app/shell/data-table.ts] — closed: DW-1816, wontfix-accepted (Space reaches every row).
- [x] [Review][Defer] A broadcast to a set marks no row; a one-pid broadcast marks its row Changed [src/OcuPilot/Screen/Tool/ProcessBroadcast.cls:55] — closed: DW-1817, wontfix-accepted.
- [x] [Review][Defer] A pasted tab gets the agent-worded `TOOL.ARGUMENTS` sentence in the dialog [src/OcuPilot/Api/ScreenAction.cls:550] — closed: DW-1818, wontfix-accepted, out of footprint.
- For the lead: AD-51 says "Two cases:" and lists three (ARCHITECTURE-SPINE.md:659). The spine is the lead's under Rule 20, so it was not edited here.

Rejected:

- `false` Error.cls says the port answers 409 "for both callers": it does, at either caller's write.
- `false` The live class's `Delete` statuses go unchecked: the `Exists` read-back after them turns a survivor into an error.
- `false` A transport fault leaves the dialog silent: `ApiService` reports transport and install faults on the shell's own surfaces (api.ts:346, :367), as for every dialog.
- `low` A refused send retries the set frozen at open: the dialog sends exactly the set its title named, and nothing partial.
- `low` A filter unchecks hidden rows: Boundaries, "a row that leaves the view ... is unchecked", is pinned.
- `low` Check all ignores `max`: Boundaries, "checks the eligible rows in view"; the over-cap reason names the cap.
- `low` The dialog trims and the agent does not: Boundaries, "Send trims the message".
- `low` The dialog names a count, not pids: Boundaries set the title to the count.
- `low` The checked set is not in screen context: no AC asks for it.
- `low` The corpus has no non-string `action`/`eligible`/`ineligibleKey` case: each type check shares its branch and sentence with the pinned empty case, and a declaration is hand-written JSON reviewed with its class.
- `low` No check that a `multiSelect` entity type can hold a set: theoretical; the one declaration is on `integerset`.
- `low` 255 and 20 are literals in the dialog, hint and `DESCRIPTION`: developer-only drift, and the fix is a cross-file test.
- `low` `multi-select.ts` has no tools test: three component specs execute it.
- `low` The live class does not check `%System_CallOut`: theoretical, since CI runs as `_SYSTEM`.
- `low` A receiver can outlive the 10 s poll: it ends itself at 60 s.
- `low` Pid reuse or an end between the port's `LIST` and the vendor call: Design Notes, "Message sent." means handed to the instance.
- `low` An all-ended set answers 404: duplicate of DW-1812 (by-design).
- `low` `\p{Zl}`, `\p{Zp}` and `\p{Cf}` pass: the refused set is the Boundaries'.
- `low` A non-boolean `eligible` passes validation: theoretical.
- `low` The matrix's `""` set departure is missing from the Spec Change Log: the fix edits this spec; Auto Run Result records it.

## Spec Change Log

- 2026-09-29, after implement (lead): four Boundaries/Tasks statements are superseded by the build, as its Auto Run Result reports -- `FINGERPRINTSUBJECT` is `Recipients,Absent,Message` (the mint narrows the stored payload to the subject, so without `Message` the broadcast would carry none); the mint's recipient refusal lives in `MergeUpdate`, not `StateDiff` (the screen route also runs `StateDiff` and would answer 400 instead of the port's 409); `ProcessBroadcastLive` is armed on `OCUPILOT_ALLOW_PRINCIPALS` because it creates a user; the receiver records its pid in `^OcuPilotTestBroadcast` instead of writing `PID=` (AD-12's one-writer check refuses a bare `Write`). The frozen intent block is left as written.

- 2026-09-28, spec gate (lead): the orchestrator accepted the 255-character message and 20-recipient caps as product choices and asked that both be named in the Fixed strings and stated in the dialog (Tasks). Spine amended at the gate: AD-5, AD-10, AD-13, AD-15, AD-51, AD-53.

## Review Triage Log

### 2026-09-28 — Review pass

- verdicts: 30 findings — high 0, medium 7, low 19, false 4, maybe-false 0
- findings:
  - verification-gap:
    - `[low]` `patch` The hint's 20-process cap is never checked on the path Processes renders (`ScreenActionDialogs.broadcastMax`) — asserted the hint through the real handler in `broadcast-dialog.spec.ts`; mutation `broadcastMax` → `0` red.
    - `[medium]` `patch` A checked row a filter hides is never tested for being unchecked — added the `data-table.spec.ts` filter leg; mutation `store.data()` red.
    - `[medium]` `patch` An ineligible row's checkbox carried a `title`, breaking DW-146's "no `title` under the table" — removed it, so the reason rides `aria-description` alone; added the multi-select no-`title` leg; mutation re-adding it red.
    - `[low]` `reject` `measureLabels`' Check all term has no geometry test — the term is measured as the header lays it out; a regression needs a user to narrow Process ID below its label, and a browser geometry leg is more than a direct correction.
    - `[medium]` `patch` The port's `$TLevel` refusal (the Never rule's only enforcement) is untested — added a `TSTART` leg to `ProcessBroadcast`; mutation red (run 18826).
    - `[low]` `patch` Focus moving to Close after a send is untested — asserted in `process-broadcast.browser-spec.mjs` with the check cleared; mutation of the focus effect red after redeploy.
    - `[low]` `defer` A set in which every pid has ended answers the fresh read's 404, not the published 409 — the intent's `RECIPIENTS` clause specifies 404 when no pid is found; which the dialog should show is a product call (deferred).
    - `[medium]` `patch` The fingerprint test's ended and flag legs passed for the wrong reason, and its fresh reads went through `$ListBuild`, which stringified them, so every moved leg was vacuous — the ended and flag legs now assert the merge's refusal and the user and message legs a non-empty differing digest; mutation red (run 18827).
    - `[low]` `reject` Sub-parts of ACs and in-file mutation comments have no recorded run — Rule 19 scopes to one pinning test per AC, each recorded; the tests this stage added carry recorded lines.
    - `[low]` `reject` `ProcessBroadcastLive` is armed on `OCUPILOT_ALLOW_PRINCIPALS` where the spec says no arming — the fix edits this spec; the class creates and deletes a user, which every such class arms for, and `ci-throwaway.sh`'s roster names it.
    - `[low]` `reject` The mint's refusal lives in `MergeUpdate`, not `StateDiff` as Tasks say — the fix edits this spec; `ScreenAction.Body` runs `StateDiff` (`Api/ScreenAction.cls:421`), so a `StateDiff` refusal would answer the screen 400 instead of the port's 409.
  - intent-alignment:
    - `[false]` `reject` The agent's mint answers 400 with the sentence, not 409 — Boundaries put the sentence at the mint (every mint refusal is 400 `TOOL.ARGUMENTS`, `Kernel/Proposal/Mint.cls:204`) and the 409 at the write for both callers, which the port answers.
    - `[false]` `reject` `FINGERPRINTSUBJECT` adds `Message` to the intent's `Recipients,Absent` — the mint narrows the stored payload to the subject (`Mint.cls:270-284`) and `PortQuery` reads the message from it, so the literal subject sends no message on either caller; `Message` never moves in the fresh read. The intent text needs the correction.
    - `[medium]` `patch` Filter-driven unchecking is unpinned — grouped with the filter row above.
    - `[low]` `defer` An all-ended set never yields 409 — grouped with the 404 row above.
    - `[low]` `reject` The card is tested as the proposal's `changed` rows, not as rendered — the panel renders every action write's rows generically; a rendered-card leg is more than a direct correction.
    - `[false]` `reject` `ineligibleKey` is shape-checked only — it joins `declaredStringKeys`, which the same loop resolves against `strings.ts` for every declared key (`ui/tools/screen-mirror.test.mjs:134`).
    - `[false]` `reject` Additions beyond the literal intent (the hint, Check all's indeterminate state, the caller-body 500, the transaction guard) — the hint is the spec gate's Task, the body refusal and the guard are Boundaries and Never items, and the indeterminate state is a neutral affordance.
    - `[medium]` `patch` The checkbox `title` — grouped with the DW-146 row above.
    - `[low]` `reject` The arming variable — grouped with the arming row above.
    - `[low]` `patch` The browser spec never asserts the checks cleared after a send — asserted with the focus row above; two-receiver delivery stays pinned at the route by `ProcessBroadcastLive`.
    - `[low]` `reject` The ledger's message argument is not asserted — the dispatch path records every tool call's arguments and the live class mints below dispatch; `Message` matches no secret pattern; a dispatch leg is more than a direct correction.
    - `[low]` `reject` The browser draws only a daemon's ineligible checkbox — checkability is one vendor flag per row, pinned for a JOB'd process on the live read and for the drawing in `data-table.spec.ts`.
    - `[low]` `reject` The 0 and over-max reasons are jsdom only — one function (`multi-select.ts`) computes them for the bar and the box, both pinned; the browser pins `aria-disabled`.
    - `[low]` `reject` A good message is pinned at the rule, not delivered — `ScreenActionDelta` carries it exactly and `BroadcastBody` composes it unchanged, both pinned; the terminal's rendering is the vendor's.
    - `[low]` `reject` The screen's "" set and the agent's "0" and 21-pid sets are unit only — "" is refused by the route's own empty-id check before the tool (`Api/ScreenAction.cls:192`); the mint runs the unit-pinned `PidsProblem` first, which its "abc" leg shows.
    - `[medium]` `patch` The moved flag and ended legs pass by the merge's refusal — grouped with the fingerprint row above; the ended case is also pinned end to end (`TestAConfirmAfterARecipientEndedIsRefused`).
    - `[low]` `reject` Refresh is pinned by `readNow`, not a timer tick — the timer calls the same read (AD-43) and `pruneChecked` runs on every store change.
    - `[low]` `reject` Other tables and Suspend are pinned in jsdom and by a direct `Prohibits` call — `Prohibits` is the set's one home, the call every `Prohibited` test makes.
    - `[low]` `reject` "The screen's caller leaves no record" and AD-58's action verdict are untested here — both are the kernel's behavior for every screen action and every bodyless write, pinned by their own suites.

## Design Notes

**Measured on `ocupilot-ci`, 2026-09-28** (probes and vendor copies in `scratchpad/epic-16/16-6/`):

- **Who can receive:** an `iris session` process reads `CanReceiveBroadcast` 1 (JobType 1 with commands on stdin, 3 with an entry argument). JOB'd processes (2), CSP servers (27), the Task Manager, Work Queue workers and every daemon read 0, and so do all 27 processes on slot A.
- **Admin API behavior:**
  - 200 `{}` for every well-formed body, whether delivered or not.
  - An ended or ineligible pid is dropped silently; `[pid,pid]` is delivered twice; `Message ""` delivers `******`.
  - The text lands in 6–37 ms, and a receiver in the middle of a `Hang` keeps running.
- **Characters and length:**
  - ESC sequences, OSC 52, C0 and C1 reach the terminal verbatim, hence the `\p{Cc}` refusal.
  - Nothing limits the length below 3.6 M characters, where the send fails silently.
- **Pairs:**
  - `%Admin_Operate:USE` + `%DB_IRISSYS:READ` send.
  - Without `%DB_IRISSYS:READ` the answer is 403 (`<PROTECT>` on `BROADCAS`).
  - The `LIST` also needs `%Admin_Manage:USE`.
  - In process, neither `%SYSTEM.Process.Broadcast` nor `PID^BROADCAS` checks `%Admin_Operate`, which is one more reason to use the admin API.
- **Audit:** no vendor row with auditing on.

**Receiver recipes:**

- **ObjectScript:** `$ZF(-100)` as in Tests. It needs `%System_CallOut:USE` and writes one `%System/%System/OSCommand` audit row per spawn. JobType 3 was measured with a Python entry, and a class-method entry takes the same path (inference: check it first).
- **Node:** `spawn('docker', ['exec', ctr, 'iris', 'session', 'iris', '-U', ns, entry])`. Killing the client does not stop the process, so terminate it by pid with `docker exec <ctr> iris session iris -U %SYS '##class(%SYSTEM.Process).Terminate(<pid>)'`.

**Decisions.** The lead records these spine cases at the spec gate (Rule 20):

- **Why the admin API (no AD-27 case):** it carries the send. `ProcessPort` adds only the recipient read and the eligibility refusal the vendor lacks.
- **AD-51:** the third named case. `ProcessPort` composes `Process` `BROADCAST`'s body from `Message` and the target's pid set.
- **AD-13:** a `process` id may name a pid set, under the `integerset` rule.
- **AD-10, the lead's question:** a broadcast to a system process, or to a process OcuPilot runs in, is refused as ineligible rather than as prohibited. Its effect is a line of text that the vendor would drop, and such processes cannot receive it (measured). The process arm stays scoped to suspend, resume and terminate.
- **AD-15 and AD-53:** broadcast is the fourth no-vendor-event case.
- **AD-5:** a list may declare one multi-select action.
- **Why checks rather than a multi-row selection:** the single selection is the context entity, the locator segment and the target of the row actions, so making it a set would change every screen.
- **The cap of 20:** a target key is stored in `Ledger.Target` (256 characters) after `process` and `instance`, and 20 seven-digit pids fit.
- **255 characters:** a product bound, since a terminal line is 80 columns.
- **Parity gaps, stated:** only terminal sessions can receive, so web users see nothing, as on the classic page. The vendor reports no delivery per pid, so "Message sent." means handed to the instance.

**Governing ADs:** AD-2, AD-5, AD-6, AD-8, AD-10, AD-13, AD-14, AD-15, AD-16, AD-19, AD-22, AD-24, AD-29, AD-34, AD-36, AD-39, AD-43, AD-51, AD-52, AD-53, AD-56, AD-58, AD-59.

**Integration ACs (Rule 1):**

- **Consumer:** in this story, Processes consumes the table's multi-select. `process-broadcast.browser-spec.mjs` checks a receiver through it, and the message reaches that receiver on the instance.
- **Consumes:** `AdminPort` (`Process` `LIST` and `BROADCAST`), the screen-action route, `ScreenStore`, and the dialog shell.
- **Consumed-by:** no later story names `multiSelect` yet.

**Ledger inbox (Rule 17):** empty.

**Footprint:**

- **Contended, add-only:** the `MUTATINGTYPES` list in `AdminPort.cls`, `Baseline.cls`, `Api/Error.cls`, `strings.ts`, `_components.scss`, EXPERIENCE.md (in place), `DECLARATIONKEYS`/`DECLARATION_KEYS`, `screens.generated.ts`, and the rosters.
- **The one in-place list edit:** `EntityRef.cls` `IDRULES` `process:integer` → `process:integerset`. Epic 18's branch appends to the same line, so it merges as a one-line union.
- **Gated edits:** every `data-table.ts` change is gated on `multiSelect`.
- **Footprint extensions to report:** `Kernel/EntityRef.cls`, and `Kernel/Proposal/Prohibited.cls` (one branch, no list change).

## Verification

**Commands:**

- Loop, ObjectScript on `ocupilot-ci`:
  1. `rsync -a --delete src/ /tmp/ocupilot-ci/src/`
  2. `sh /private/tmp/claude-501/-Users-jbrandt-git-OcuPilot/1518373f-040c-4be6-a814-a27bfbff2961/scratchpad/epic-16/compile.sh <changed paths>`
  3. `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class <C>`, one class per call, for `ProcessBroadcast`, `ProcessBroadcastLive`, `ProcessTerminate`, `ProcessPortProbe`, `Prohibited`, `EntityRef`, `Descriptor`, `ReadTool`, `SurfaceCoverage`, `ToolRoundTrip`, `ToolWrite`, `ToolEmit`, `ScreenRead`, `ReadBack`, `RefusalCopy`, `DraftRegistry`, `DraftPorts`, `GovernanceBaseline` and `ProposalConfirm`.

  Expected: green.
- Loop, client: `cd ui && npm run test:tools && npx ng test --include src/app/shell/data-table.spec.ts --include src/app/shell/command-bar.spec.ts --include src/app/shell/command-box.spec.ts --include src/app/shell/list-page.spec.ts --include src/app/shell/screen-action-handler.spec.ts --include src/app/shell/broadcast-dialog.spec.ts`. Expected: green.
- Loop, browser, covering the new spec and every existing spec that exercises the shared table: `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/ && OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci node --test --test-concurrency=1 browser/process-broadcast.browser-spec.mjs browser/data-table.browser-spec.mjs browser/data-table-columns.browser-spec.mjs browser/processes.browser-spec.mjs browser/process-actions.browser-spec.mjs browser/csv-download.browser-spec.mjs browser/column-widths.browser-spec.mjs browser/screen-height.browser-spec.mjs browser/a11y-structural-invariants.browser-spec.mjs`. Expected: green. A spec that refuses on an arming variable `ocupilot-ci` lacks is recorded as residue.
- Once, before dev_complete:
  - `cd ui && npm test`, with the bundle under the 2107kB `maximumWarning`.
  - The full ObjectScript sweep on `ocupilot-ci`, one class at a time: green apart from the known residue.
  - The full browser suite is CI's.

**Planned mutations:**

- AC1: the port drops the last `PidList` member → the two-receiver leg of `ProcessBroadcastLive` goes red.
- AC1: the title counts the selection instead of the checks → `broadcast-dialog.spec.ts` goes red.
- AC2: Space is handled without the `multiSelect` guard → the undeclared leg of `data-table.spec.ts` goes red.
- AC3: the port skips its recipient re-check → the 409 leg of `ProcessBroadcastLive` goes red.
- AC4: `\p{Cc}` is dropped from `MessageProblem` → the ESC leg of `ProcessBroadcast` goes red.
- `integerset` sorts as strings → `EntityRef` and `entity-ref.test.mjs` go red.

**Recorded mutations** (each reverted and the tree confirmed byte-identical; ObjectScript compiled on `ocupilot-ci` with every descendant, before and after the revert):

- mutation: `ProcessPort.BroadcastBody` loops to `$ListLength(pPids) - 1` → `ProcessBroadcastLive` red (runs 18781, 18794): `TestTheScreenActionSendsToTwoReceivers` "and so does the second", `TestTheAgentsConfirmDeliversWithTheMarker`, `TestAThreePairsPrincipalBroadcasts`.
- mutation: `ScreenActionHandler.startCheckedSet` sets `count: store.selection().length` → `broadcast-dialog.spec.ts` red: "titles the dialog with the checked rows' count" (expected "Broadcast to 2 processes", got "Broadcast to 1 process").
- mutation: `DataTable.onGridKeydown` drops `this.screen().multiSelect !== null &&` from the Space branch → `data-table.spec.ts` red: "an undeclared list draws no checkbox and leaves Space to the browser".
- mutation: `ProcessPort.Invoke`'s `Receivable` refusal becomes `If 0 Quit ...` → `ProcessBroadcastLive` red (run 18782): `TestASetHoldingAnIneligiblePidSendsNothing`, both the JOB'd and the ended legs; `ProcessBroadcast` red (run 18783): `TestThePortComposesTheBodyAndRefusesBeforeAnyVendorCall`.
- mutation: `ProcessBroadcast.MessageProblem`'s `$Locate(pValue, "\p{Cc}")` becomes `0` → `ProcessBroadcast` red (run 18784): `TestTheMessageRuleRefusesPerTheMatrix`, the escape, tab, C1, DEL and line-feed legs and the screen's value.
- mutation: `EntityRef.PlainIntegerSet` subscripts every positive member at length 1, and `entity-ref.ts`'s `integerset` sorts with `.sort()` → `EntityRef` red (run 18785): "'10,9,100' is the set 9,10,100"; `entity-ref.test.mjs` red: "the integerset rule folds a process id set to unique pids in ascending order".
- mutation: `multiSelect.max`'s upper bound dropped in `Registry.MultiSelectProblem` and `screen-mirror.mjs`'s `multiSelectProblem` → `Descriptor` red (run 18786): `TestEveryMultiSelectCorpusCaseGetsItsSentence` "a max above a thousand"; `screen-mirror.test.mjs` red: "multiSelectProblem returns every sentence OcuPilot.Test.MultiSelectCorpus declares".
- mutation: `Prohibited`'s `BROADCAST` skip of the process arm becomes `If 0 && ...` → `ProcessBroadcast` red (run 18787): `TestABroadcastPassesTheProcessArmWhileASuspendIsRefused`, the daemon and this-job legs.
- mutation (matrix audit, stage): `ProcessBroadcast.MergeUpdate`'s `Receivable` refusal becomes `If 0` → `ProcessBroadcast` red (run 18821): `TestTheAgentsMintRefusesABadSetABadMessageAndAnIneligibleSet` (the daemon leg mints) and `TestTheStateRowNamesTheCountAndTheMergeRefusesAnIneligibleSet`.
- mutation (matrix audit, stage): that `If 0` plus `FINGERPRINTSUBJECT` and `PRECONDITIONFIELD` narrowed to `Message` → `ProcessBroadcastLive` red (run 18822): `TestAConfirmAfterARecipientEndedIsRefused` reads 409 `PROCESS.BROADCAST.RECIPIENT` from the port, not `PROPOSAL.TARGETCHANGED`.
- mutation (matrix audit, stage): `MessageProblem`'s `\p{Cc}` check becomes `If 0` → `ProcessBroadcastLive` red (run 18823): `TestTheScreenRefusesABadSetAndABadMessage`, the tab leg.
- mutation (review pass): `ProcessPort.Invoke`'s `$TLevel` refusal becomes `If 0` → `ProcessBroadcast` red (run 18826): `TestThePortComposesTheBodyAndRefusesBeforeAnyVendorCall`, the transaction leg.
- mutation (review pass): `MergeUpdate`'s `Receivable` refusal becomes `If 0` → `ProcessBroadcast` red (run 18827): `TestTheFingerprintRefusesAMovedRecipient` (the ended and flag legs), with the two tests above.
- mutation (review pass): `pruneChecked` builds its set from `store.data()`; the row checkbox binds `[attr.title]`; `ScreenActionDialogs.broadcastMax` answers `0` → red, one each: `data-table.spec.ts` "a filter that hides a checked row unchecks it" and "Story 15.8: no element under a multi-select table carries a title", `broadcast-dialog.spec.ts` "titles the dialog with the checked rows' count" (the hint).
- mutation (review pass): `BroadcastDialog`'s focus effect never runs, rebuilt and redeployed → `process-broadcast.browser-spec.mjs` red: the Space/Broadcast/Send leg times out waiting for focus on Close.
- mutation (QA pass): `DataTable`'s row-mapping `checkReason` becomes `null` unconditionally (`data-table.ts`) → `data-table.spec.ts` red: "an ineligible row's checkbox is aria-disabled with the declared reason, and neither Space nor a click checks it" (expected the published sentence, got `null`); reverted, tree byte-identical. This is the matrix's "Ineligible row" leg: the Boundaries and EXPERIENCE.md:648 ask only that the checkbox "carries the declared reason" (`aria-disabled` + `aria-description`), not that the reason be visible to a sighted mouse user without assistive tech — the DW-146 no-`title` constraint already forecloses a hover tooltip. The follow-up review's residual risk is therefore a product question for the lead, not an unpinned behavior: what the spec asks for is pinned and now demonstrated load-bearing.
- mutation (code review): `DataTable.onCheckClick`/`onCheckAll` lose `keepGridFocus()` -> `data-table.spec.ts` red: "a checkbox click, a row's or Check all, leaves DOM focus on the grid"; rebuilt and redeployed, `process-broadcast.browser-spec.mjs` red: "with DOM focus on the grid, not the checkbox".
- mutation (code review): `ScreenActionDialogs.broadcastRefusal` answers `''` -> `broadcast-dialog.spec.ts` red: "draws the instance's refusal in the dialog it opened"; `onEnter` loses its `isComposing` return -> red: "an Enter that commits an IME composition does not".
- mutation (code review): `submitBroadcast` loses `pending.sending === true ||` -> `screen-action-handler.spec.ts` red: "a second Send while the first is in flight sends nothing"; its identity check becomes a kind-and-target compare -> red: "a Send answered after its dialog was closed and reopened leaves the reopened one unsent".
- mutation (code review): `Registry.Validate`'s `MultiSelectProblem` call deleted on `ocupilot-ci`, compiled with subclasses -> `Descriptor` red (run 19180): `TestAMultiSelectOutsideTheGrammarIsRefusedByTheRoster`; restored, green (run 19181).
- Each mutation was reverted and the tree confirmed byte-identical.

## Auto Run Result

Status: done
Blocking condition: none

**Summary.** Processes lists `CanReceiveBroadcast` and declares the data table's first `multiSelect`: a checked set in `ScreenStore` beside the unchanged selection, checkboxes at the name cell, Space and Check all, pruned on every sync. The command bar and command box act on the set, and the new broadcast dialog sends one `{action, id, values: {Message}}`. `osmgmt.processes.broadcast` is an action write through `ProcessPort`: `RECIPIENTS` read, eligibility refused 409 before any vendor call, body composed from the canonical pid set (`integerset` rule). The prohibited process arm is skipped for `BROADCAST`, and the key is in the governance baseline.

**Files changed:**

- Server:
  - `Port/ProcessPort.cls`: `RECIPIENTS`, `BROADCAST`, `Snippet`.
  - `Screen/Tool/ProcessBroadcast.cls` and `ProcessBroadcastMint.cls` (new): the tool and its pre-mint checks.
  - `Kernel/EntityRef.cls`: `integerset`.
  - `Kernel/Proposal/Prohibited.cls`: the broadcast skip.
  - `Screen/Registry.cls`: `MultiSelectProblem`.
  - `Screen/Descriptor/ProcessList.cls`.
  - Appended to `Port/AdminPort.cls`, `Api/Error.cls` and `Kernel/Governance/Baseline.cls`.
- Client:
  - `ui/src/app/core/multi-select.ts` (new).
  - `ui/src/app/core/screen-store.ts`, `entity-ref.ts` and `screen-actions.ts`; `strings.ts` appended.
  - `ui/src/app/shell/data-table.ts`, `command-bar.ts`, `command-box.ts`, `screen-action-handler.ts` and `screen-action-dialogs.ts`.
  - `ui/src/app/shell/broadcast-dialog.ts` (new).
  - `ui/tools/screen-mirror.mjs`; `screens.generated.ts` regenerated.
  - `_components.scss` appended.
- Tests:
  - New: `ProcessBroadcast`, `ProcessBroadcastLive` and `MultiSelectCorpus`; `broadcast-dialog.spec.ts`; `process-broadcast.browser-spec.mjs`.
  - Rosters and pins in 13 ObjectScript classes, 4 component specs, 5 tools tests and `process-actions.browser-spec.mjs`.
- Docs: EXPERIENCE.md edited in place, still 993 lines.

**Review findings breakdown:**

- 7 entries patched, six with a test and one in code: the filter prune, the checkbox `title` removed (DW-146), the transaction guard, the vacuous fingerprint legs, the hint through the real path, focus to Close, and the checks cleared in the browser.
- 1 deferred: an all-ended set answers 404.
- 16 rejected, each with its reason in the triage log: 4 `false` and 12 `low`.
- The matrix audit added four legs before review: the agent's mint refusals, the screen's bad set and bad message, and a confirm after a recipient ended.

**Follow-up review: recommended.** Patched: medium 4, low 3. The named unverified risk: removing the checkbox `title` leaves an ineligible row's reason on `aria-description` only. A pointer user sees a dimmed checkbox with no visible reason, since the table's tooltip shows cut values only. No test or reviewer has judged that acceptable against the Boundaries' "carries the declared reason".

**Verification:**

- ObjectScript on `ocupilot-ci`: every class the spec names, plus `ScreenGrounding`, `TurnGrounding`, `WireSecurityRead` and `Envelope`, one at a time, green apart from `WireSecurityRead`'s known task-history test.
- Final runs: `ProcessBroadcast` 12/12 (run 18825) and `ProcessBroadcastLive` 7/7 (run 18820).
- `npm test`: tools 1694/1694 and components 1745 in 129 files.
- Browser, after rebuild and redeploy: `process-broadcast`, `data-table`, `data-table-columns`, `processes`, `process-actions`, `process-control`, `csv-download`, `column-widths`, `screen-height`, `a11y-structural-invariants`, `ui-state-survives-sign-out` and `context-chip`, 84/84, before and after the patches.
- Bundle: 2,089,183 bytes initial, under the 2107kB warning.
- Full sweep, once, as `--shard 1/10` through `10/10`, one class at a time: 349 classes and 2708 tests.
  - 6 methods failed. The known residue is `WireSecurityRead.TestTaskHistoryPairSetsAreEnforcedForARealPrincipal`, `TaskHistory`'s three demo-task tests and `Retention.TestAnEntryAgesByItsOwnDefinitionAndTheLedgerByTheLongest`.
  - The sixth is `PathPortInstance.TestAnOverwriteNeverReachesADatabasesFiles`. It is environmental: this throwaway's `/durable/iris/mgr/iristemp/` holds no `IRIS.DAT` (measured).
  - 22 classes refused on arming variables `ocupilot-ci` lacks: `TaskSave`, `TaskWire`, `LdapEdit`, `TaskRules`, `PreferencesWire`, `ProcessControl`, `TaskResume`, `AuditPurge`, `TaskEdit`, `DemoErrorSeed`, `ErrorDelete`, `LdapUpdate`, `NamespaceRefusals`, `ServiceEdit`, `InjectionChannels`, `NamespaceWrite`, `TaskCreate`, `NamespaceWriteGate`, `DraftExecute`, `TaskUpdate`, `AuditingUpdate` and `InjectionCompromised`.

**Residual risks and spec drift (for the lead):**

- The intent's `FINGERPRINTSUBJECT` reads `Recipients,Absent`. The code adds `Message`, because the mint narrows the stored payload to the subject and the literal value sends no message; the intent text needs correcting at origin.
- Tasks name `StateDiff` for the mint refusal; it is `MergeUpdate`, so the screen keeps the port's 409.
- `ProcessBroadcastLive` is armed on `OCUPILOT_ALLOW_PRINCIPALS`, where the spec says it needs no arming variable, because it creates a user; the class is added to `scripts/ci-throwaway.sh`'s roster.
- The receiver records its pid in `^OcuPilotTestBroadcast` rather than writing `PID=`, which AD-12's one-writer check refuses.
- A "" set from the screen is refused by the route's own empty-id check (400 `TOOL.ARGUMENTS`), not 400 `PORT.VALIDATION`.
- The epic's `compile.sh` loads with `ck`, which leaves subclasses stale; this run recompiled with `b`.

**Footprint extensions:** `src/OcuPilot/Kernel/EntityRef.cls` (expected), `src/OcuPilot/Kernel/Governance/Baseline.cls` (standing ruling), `scripts/ci-throwaway.sh` (one comment line in the principals roster), `ui/src/app/testing/screen-declaration.ts` (the test fixture's `multiSelect: null`), and EXPERIENCE.md.
