---
title: 'Story 7.11: System and user audit event configuration'
type: 'feature'
created: '2026-09-23'
status: 'blocked'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-7-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-7-4-turn-auditing-on-and-off-from-the-screen.md'
warnings: ['oversized']
deferred: []
footprint_extensions:
  - 'src/OcuPilot/Kernel/Proposal/Prohibited.cls' # contended, Epic 8-modified; IG-2
  - 'src/OcuPilot/Kernel/Proposal/Mint.cls' # contended, Epic 8-modified; WarnsAuditingOff body only; IG-2
  - 'src/OcuPilot/Kernel/EntityRef.cls' # Epic 8-modified; IDRULES line; IG-2
  - 'src/OcuPilot/Screen/Tool/Classification.cls' # contended, Epic 8-modified; IG-2
  - 'src/OcuPilot/Screen/Tool/ToolFields.cls' # generated; IG-2
  - 'ui/src/app/core/screen-actions.ts' # Epic 8-modified; one ACTION_LABELS line; IG-2
  - 'ui/src/app/core/screens.generated.ts' # regenerated
  - 'src/OcuPilot/Kernel/EntityType.cls'
  - 'src/OcuPilot/Test/ProhibitedRoute.cls' # roster rule, 2026-09-23
  - 'src/OcuPilot/Test/AuditingUpdate.cls' # roster rule, 2026-09-23
  - 'src/OcuPilot/Test/ToolWrite.cls' # roster rule, 2026-09-23
  - 'src/OcuPilot/Test/SurfaceCoverage.cls' # roster rule, 2026-09-23
  - 'src/OcuPilot/Test/ReadTool.cls' # roster rule, 2026-09-23
  - 'src/OcuPilot/Test/ToolRoundTrip.cls' # roster rule, 2026-09-23
  - 'src/OcuPilot/Test/PortFixture.cls' # roster rule, 2026-09-23
  - 'src/OcuPilot/Test/Prohibited.cls' # roster rule, 2026-09-23
  - 'src/OcuPilot/Test/EntityRef.cls' # roster rule, 2026-09-23
  - 'ui/tools/navigation.test.mjs' # roster rule, 2026-09-23
---

<intent-contract>

## Intent

**Problem:** The System events and User events lists (Story 7.4) are read-only. FR-47's event
configuration therefore works through neither caller: nobody can enable, disable or reset an event
from OcuPilot, or delete a user event. The classic portal's Selective SQL Auditing wizard has no
equivalent. Disabling OcuPilot's own marker event carries no warning. Both lists also share entity
type `audit-event`, so a user-event change links to the system list (DW-1529).

**Approach:** Add write tools over the vendor's `Security.Audit.Event`, one set per list, each with
two callers (AD-53):

- `update` (a merge `PUT` of `Enabled`, reached as `enable`/`disable`);
- `reset` (action-style `CLEARCOUNT`);
- `delete` (action-style, user list only).

`AdminPort` splits the row key `Source/Type/Name` into the vendor's three query parameters. Give
user events their own entity type. Warn before a disable, and advise before a delete, that would
stop agent writes being marked. Add a Selective SQL auditing dialog to the Auditing configuration
page that toggles the twelve granular SQL events through the same `update` action.

## Boundaries & Constraints

**Always:**

- One operation, two callers. The screen action mints no proposal, emits no marker, and is not
  gated by the kill switch or read-only (AD-53).
- Both callers resolve the target through `AdminPort`, read fresh, and check the list's own pairs
  (`%Admin_Secure:USE`, `%DB_IRISSYS:READ`) before any read (AD-8, AD-29). The prohibited set is
  evaluated inside the transition (AD-10, AD-34).
- Each write publishes one AD-14 change. `update` and `delete` declare `MOVESMARKING` (AD-53 as
  amended).
- The `update` body is the complete `{Description, Enabled}` over the fresh `GET` (AD-4). Its
  field list is the committed class derivation `Security.Audit.Event:Security.Events` (AD-3), and
  `Enabled` is its only settable field. A target missing at mint, at screen action or at confirm is
  refused, so the upsert never creates a stub (AD-4, AD-6).
- Ids fold case (AD-13; the vendor keys events case-insensitively).
- New copy goes to `strings.ts` (append) with the lead-published EXPERIENCE rows.
- Tests act only on events they created, restore `OcuPilot/Security/AgentWrite` and auditing on
  every exit, and run one class at a time.

**Never:**

- No user-event create or Description edit here (IG-1).
- No new armed test class and no `scripts/ci-throwaway.sh` edit.
- No edit to Epic 8-exclusive files, `field-lists.mjs`, `Write.cls`, `Confirm.cls`, `Router.cls`,
  `Screen/Registry.cls`, `screen-mirror.mjs` or `navigation.ts`.
- No row actions on the lists embedded in the Auditing configuration page. They stay read-only
  views, and the actions live at the list routes.
- `delete` is not offered on system events (the vendor answers 409, error #854).
- No new self-protection vocabulary.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Enable a system event | `%System/%SQL/XDBCStatementUtility` off → "Enable" | no dialog; one `POST /screens/security.auditsystemevents/action {action:"enable",id}` → 200 `{action:"updated",target:{type:"audit-event",scope:"instance",id:<folded>}}`; row re-fetched on | No error expected |
| No-op | enable an enabled event | 400 `TOOL.ARGUMENTS` with `detail.problem`; nothing sent to the vendor | refusal on the list |
| Reset counters | any row → "Reset counters" | no dialog; `CLEARCOUNT` with the port's constant `{}`; `Total`/`Written`/`Lost` read 0 after re-fetch | 404 if the event vanished |
| Delete a user event | probe row → typed-name dialog, name = `EventName` | 200 `deleted`, type `audit-user-event`; `Security.Events.Exists` 0 | Cancel/Escape send nothing |
| Upsert guard | event deleted after the row was read, or between mint and confirm | screen action 404 / confirm refused; `Exists` still 0 (no stub) | refusal, no write |
| Disable marker event (screen) | `OcuPilot/Security/AgentWrite` → "Disable" | warning dialog: verb title, body `proposalAuditWarning`, Proceed `button-primary`, focus on Cancel; on Proceed `writesMarked:false` and the banner shows; "Enable" clears it | Cancel sends nothing |
| Disable marker event (agent) | `security.audituserevents.update` `Enabled:false` on that id | card carries `auditWarning:true`; after confirm the banner shows | ordinary AD-15 not-marked row |
| Delete marker event | its typed-name dialog | advisory `proposalAuditWarning` above the field; agent card `auditWarning:true` | as delete |
| Other events | disable, delete or reset any other event | no warning or advisory; marking unchanged | n/a |
| Malformed id | not exactly three non-empty `/` pieces | port answers 404 without a vendor call | 404 |
| SQL wizard | page → "Selective SQL auditing"; tick one box → Apply | one `enable` per changed box, sequentially, none for unchanged; lists re-read | the first refusal stops the run and shows its reason plus `auditSqlWizardStopped` |
| Short of a pair | principal without `%Admin_Secure:USE` | 403 `AUTH.NOPRIVILEGE`, `failedPair` named, before any read | nothing read or written |

</intent-contract>

## Code Map

Measured 2026-09-23 on slot A: reads, plus two create probes the instance refused (Auto Run
Result). The vendor class
`%Api.Admin.Endpoints.Security.Audit.Event` was read from the instance.

Vendor:

- Request types: `LIST` (`names`, `eventOwner`), `GET`, `PUT`, `DELETE` and `TYPECLEARCOUNT=10`.
- `GET`, `PUT`, `DELETE` and `CLEARCOUNT` require `source`, `type` and `name` query parameters.
- `PUT` is an upsert. It `Create`s when the event is absent and answers 201. Otherwise it
  `Modify`s only the keys present. `ValidateRequest` accepts the inline schema
  `{Description, Enabled}`.
- `CLEARCOUNT`'s `NeedsRequestBody` is true, and `RunClearCount` ignores the body.
- `DELETE` answers 409 on error #854 (a system-defined event).
- `GET` with a lower-cased triple answers 200 through `AdminPort.Invoke`.
- `LIST names=<EventName>` answers one row that includes `Total`.
- `Security.Events` refuses `/` in a Name (#851) and fails `<SUBSCRIPT>` on one in a Source.
  Nothing was created by these probes.
- The user events are `OcuPilot/Security/{ConfigChange,LedgerRead,RoleGranted,SecurityChange}`.
  `AgentWrite` is not registered on slot A.
- There are twelve granular SQL system events, `%System/%SQL/{Dynamic,Embedded,XDBC}Statement{Query,DDL,DML,Utility}`.
  They are the ones `%CSP.UI.Portal.Audit.SelectiveWizard` toggles (`irissys/%CSP/UI/Portal/Audit/SelectiveWizard.cls:31-125`).
  The classic list hides the seven aggregate `%SQL` events (`SystemEvents.cls:51-57`).

Server:

- `Screen/Tool/Write.cls`:
  - parameters `:38-173`, among them `READTYPE`/`WRITETYPE` `:57/:62`, `SENDSBODY :67`,
    `STATEFIELD :75`, `FINGERPRINTSUBJECT :97`, `PRECONDITIONFIELD :105`, `PORTCLASS :114`,
    `CHANGEACTION :124` and `SCREENACTIONS :140`;
  - `IdArgument`/`IdParam` `:373/:380`, `StateDiff :336`.
  - It is read-only here.
- Precedents to copy:
  - `WebAppUpdate` (merge plus `SCREENACTIONS`);
  - `AuditingUpdate` (`MOVESMARKING`, `PERMITTEDFIELDS`, `PrivilegePairs`);
  - `UserDelete :27-54`, `TaskRun` (state row, constant body);
  - `TaskSuspend extends TaskResume`, the one-tool-per-descriptor subclass pattern.
    `ScreenAction.ToolFor :419-438` picks the tool by `DESCRIPTORCLASS` and action.
- `Port/AdminPort.cls`:
  - `MUTATINGTYPES :208`, `BODYLESSTYPES :224` and `CONSTANTBODIES :251`. Epic 8 also edited
    the first two lines.
  - `Invoke :486`; the query seeding is at `:1038-1042`.
  - `ImplementsRead :1000-1007` passes `CLEARCOUNT` because the vendor overrides `Run`.
- `Kernel/Proposal/Mint.cls`:
  - the fresh read sets only `tQuery(IdParam)` (`:141-143`);
  - `AUDITINGTOOL :33`, and `WarnsAuditingOff` `:296-321` is called at `:235`.
  - Epic 8 has not touched `WarnsAuditingOff`'s body.
- `Kernel/Proposal/Prohibited.cls`:
  - `COVEREDTYPES :157` (Epic 8 edits the same line);
  - `PermittedChangeFields :321-327`, `Prohibits :388-447`;
  - `Auditing :655` is the arm to copy (`ReviewedFewOnly :810`).
- `Kernel/EntityType.cls:34` `TYPES`, and `Kernel/EntityRef.cls:59` `IDRULES` (Epic 8 edits the
  same line).
- `Kernel/Audit/Event.cls`: `EVENTAGENTWRITE :38`, and `ObserveMarking :354-388`, which answers
  0 with auditing off and "not marked" on a 404.
- `Api/ScreenAction.cls`: `Run :165`; the marking hook is at `:269`, and `OBSERVEFAILED :289`.
- `Screen/Tool/Classification.cls`: `security.auditing.update :82`. Epic 8 inserts after that
  entry's closing brace and at the tail.
- `FieldLists.cls:151-154` already holds `Security.Audit.Event:Security.Events`
  (`Description`, `Enabled`), pinned by `Test/DerivedFields.cls:178`. `ToolFields.cls` is
  regenerated by `cd ui && node tools/field-lists.mjs`, with no `field-lists.mjs` change.
- `Screen/Descriptor/AuditSystemEventList.cls` and `AuditUserEventList.cls`:
  - `rowActions []` at `:34`;
  - `emptyNextKey tableReadOnlyEmptyNext` and `emptyAgentKey ""` at `:55-56`;
  - `entityLabelKey ""`.
  - A list that has row actions must set `emptyAgentKey` and empty `emptyNextKey`
    (`Screen/Registry.cls:1924-1931`).

Client:

- `ui/src/app/shell/screen-action-handler.ts`:
  - roster `:36-47`, `DESTRUCTIVE_CONSEQUENCES :138`;
  - a destructive action with no consequence is never registered (`:277`);
  - `TYPED_NAME_ROWS :181-185`, which does exact-equality advisories;
  - `WARNING_CONSEQUENCES :193`, per descriptor only;
  - `start :339-388`, `send :466-502`.
- `ui/src/app/shell/list-page.ts:60,77-104`: hosts typed-name, set-password and role dialogs, but
  no warning dialog. Epic 8 has not touched it.
- `ui/src/app/core/screen-actions.ts:61-78`: `ACTION_LABELS`, which has no `reset`.
- `ui/src/app/core/agent-status.ts:61`: `RESTRAINT_ENTITIES`.
- `ui/src/app/areas/security/auditing-config.page.ts`:
  - it hosts `app-warning-dialog` (`:156-163`);
  - its plain event tables are at `:118-155`;
  - it re-reads only on `auditing-configuration` changes (`:208-211`).
- `ui/tools/navigation.test.mjs:932` pins `screenForEntityType('audit-event')`.
- `ui/browser/auditing-screen.browser-spec.mjs`:
  - `restoreAuditing :75`;
  - `runIris` comes from `turnprobe-spec.mjs:52`;
  - the row-menu helpers are in `task-schedule-actions.browser-spec.mjs:151-257`.

## Tasks & Acceptance

**Execution:**

Server:

- `src/OcuPilot/Port/AdminPort.cls` (shared-append):
  - Append `Security.Audit.Event/PUT,/DELETE,/CLEARCOUNT` to `MUTATINGTYPES`, and
    `Security.Audit.Event/DELETE` to `BODYLESSTYPES`.
  - Add `;Security.Audit.Event/CLEARCOUNT={}` to `CONSTANTBODIES`.
  - Add `Parameter SPLITQUERIES = "Security.Audit.Event/event=source:type:name"`. `Invoke`
    applies it to a copy of the query before seeding: it splits the named key on `/`. Anything
    other than exactly three non-empty pieces answers 404 `PORT.NOTFOUND` without a vendor call.
  - Document it as a vendor wire fact (AD-27).
- New tool classes under `src/OcuPilot/Screen/Tool/`. Each extends `Write`, sets `Endpoint()` to
  `Security.Audit.Event`, `IdArgument` to `EventName` and `IdParam` to `event`, sets
  `WRITERESOURCE %Admin_Secure:USE`, and uses `PrivilegePairs` as in `AuditingUpdate`:
  - `AuditEventUpdate` — `security.auditsystemevents.update`, `AuditSystemEventList`.
    - Merge `PUT`, `PERMITTEDFIELDS "Enabled"`.
    - `SCREENACTIONS "enable=Enabled:true,disable=Enabled:false"`, `MOVESMARKING 1`.
    - `ClosesMarking(pId, pArgs)` answers 1 when the canonical id is the canonical
      `Source()/Type()/EVENTAGENTWRITE` and `Enabled` coerces false.
  - `AuditUserEventUpdate extends AuditEventUpdate` — `security.audituserevents.update`,
    `AuditUserEventList`.
  - `AuditEventReset` — `security.auditsystemevents.reset`.
    - `SCREENACTIONS "reset"`, `WRITETYPE CLEARCOUNT`, `SENDSBODY 0`, `CHANGEACTION updated`.
    - `PRECONDITIONFIELD`/`FINGERPRINTSUBJECT`/`READANSWERS "Enabled"` / `"Enabled"` /
      `"Description,Enabled"`.
    - `STATEFIELD "Total"`. `StateDiff` answers one row `{Total, before "", after "0"}`.
  - `AuditUserEventReset extends AuditEventReset` — `security.audituserevents.reset`.
  - `AuditUserEventDelete` — `security.audituserevents.delete`.
    - `SCREENACTIONS "delete"`, `WRITETYPE DELETE`, `SENDSBODY 0`, `CHANGEACTION deleted`,
      `DESTRUCTIVE 1`, `MOVESMARKING 1`.
    - `PRECONDITIONFIELD Enabled`, `FINGERPRINTSUBJECT "Description,Enabled"`.
    - `ClosesMarking` answers 1 on the marker event.
- `src/OcuPilot/Kernel/Proposal/Mint.cls`, `WarnsAuditingOff` body only: also answer the
  resolved tool's `ClosesMarking(canonical id, pArgs)` when the class implements it. It fails
  closed to 0, exactly as it does today.
- `src/OcuPilot/Kernel/Proposal/Prohibited.cls`:
  - Add `audit-event` and `audit-user-event` to `COVEREDTYPES`, with `PermittedChangeFields` =
    `Enabled` for both.
  - Add them to the `Prohibits` dispatch, and append an `AuditEvent` arm (`ReviewedFewOnly`).
  - Document it: AD-10 names no audit-event effect, and disabling or deleting one is warned, not
    refused.
- `src/OcuPilot/Kernel/EntityType.cls`: add `audit-user-event`, and say in the doc that
  `audit-event` is a system event.
- `src/OcuPilot/Kernel/EntityRef.cls:59`: add `audit-event:foldcase,audit-user-event:foldcase`.
- `src/OcuPilot/Screen/Tool/Classification.cls`: add entries for both update tools
  (`fieldList "Security.Audit.Event:Security.Events"`, both fields `ordinary`), inserted
  **before** `security.auditing.update`. Then regenerate `ToolFields.cls`.
- `AuditSystemEventList.cls`:
  - `rowActions [{"id":"enable",…},{"id":"disable",…},{"id":"reset",…}]`, each with
    `selfProtection ""`;
  - `entityLabelKey proposalEntityAuditEvent`;
  - `emptyNextKey ""`, `emptyAgentKey auditSystemEventListEmptyAgent`.
- `AuditUserEventList.cls`:
  - `entityType audit-user-event`;
  - the same actions, plus `delete` last;
  - `emptyAgentKey auditUserEventListEmptyAgent`.
  - Update both docs.

Client:

- `ui/src/app/shell/screen-action-handler.ts`:
  - Add both lists to the roster.
  - `DESTRUCTIVE_CONSEQUENCES.AuditUserEventList.delete = auditUserEventDeleteConsequence`.
  - `TYPED_NAME_ROWS.AuditUserEventList = {name:'EventName', field:'EventName', equals:
    AGENT_WRITE_EVENT, advisory: proposalAuditWarning}`.
  - Add `WARNING_ROWS`, keyed by descriptor then action as `{field, equals, consequence}`. Its
    one entry is `disable` on `AuditUserEventList` for `AGENT_WRITE_EVENT`. `start()` consults it
    after `WARNING_CONSEQUENCES`.
  - Expose `sendFor(descriptor, action, id)`, which shares `send()`'s POST and bus publish, for
    the wizard.
- `ui/src/app/shell/list-page.ts`: import and render `app-warning-dialog` from `pending()`, as
  `auditing-config.page.ts:156-163` does.
- `ui/src/app/core/screen-actions.ts`: `ACTION_LABELS.reset = STRINGS.actionResetCounters` (one
  line).
- `ui/src/app/core/agent-status.ts`:
  - `export const AGENT_WRITE_EVENT = 'OcuPilot/Security/AgentWrite'`;
  - add `audit-event` and `audit-user-event` to `RESTRAINT_ENTITIES`.
- `ui/src/app/areas/security/sql-audit-dialog.ts` (+ `.spec.ts`, new):
  - An `app-dialog` titled `auditSqlWizardAction`, with the prompt and a 4×3 checkbox grid (rows
    Query/DDL/DML/Utility, columns Dynamic/Embedded/XDBC). Each checkbox is named `<source>
    <kind>` and its initial state is the system list's `Enabled`. A missing event is not drawn.
  - Apply is `ocu-button-primary`. Cancel, Escape and the scrim send nothing.
  - It emits the changed `{id, action}` list.
- `auditing-config.page.ts` / `.store.ts`:
  - Add an `auditSqlWizardAction` secondary button under the System events section.
  - On apply, call `sendFor(AuditSystemEventList, …)` sequentially, stop at the first failure,
    and show its reason plus `auditSqlWizardStopped` in the page's refusal banner.
  - Re-read on `audit-event` and `audit-user-event` changes.
- `ui/src/app/core/strings.ts`: append the keys listed under Design Notes. Then regenerate
  `screens.generated.ts`.

Tests:

- `src/OcuPilot/Test/AuditEventTools.cls` (new, unarmed, no instance write):
  - the five tools' declarations and `ScreenActionIds`;
  - update `AdmittedFields = Enabled` over the `Security.Events` list;
  - `SPLITQUERIES` 404s on malformed ids, and a real `GET` of `%System/%Security/AuditChange`
    through the split;
  - the prohibited arms (`Enabled` permitted, `Description` `UNCOVEREDFIELD`, for both types);
  - both fold rules;
  - `WarnsAuditingOff` for disabling or deleting the marker event (1), enabling it (0), and
    another event (0).
- `src/OcuPilot/Test/AuditingUpdate.cls` (armed, append only):
  - Over HTTP, on a probe user event the test creates: disable, enable, reset (counters 0 after a
    seeded `$System.Security.Audit`), a no-op 400, delete, then enable against the deleted id
    → 404 with `Exists` 0.
  - Agent: mint `update Enabled:false` on a probe, delete it directly, confirm → refused, `Exists`
    0.
  - The marker event via the screen: `writesMarked` false, then true.
  - Restore in its own frame.
- `src/OcuPilot/Test/ProhibitedRoute.cls` (append; DW-1530):
  - As `DECLAREDPAIRSONLY` (plus the code resource), `disable` then `enable` on a probe user event
    → 200 each, no `OBSERVEFAILED` line, `writesMarked` unchanged.
  - A principal short of the pair → 403 naming `%Admin_Secure:USE`.
- Rosters, with only this story's members:
  - `ToolWrite` (`PortFixture :21` pairs, the bodyless roster `:1122`);
  - `SurfaceCoverage :105-121`, `ReadTool :94` (count +5), `ToolRoundTrip :34`;
  - `Prohibited :181`, `EntityRef` and the `EntityType.Count` pin;
  - `AuditingScreen` (the lists now carry actions);
  - `Descriptor`.
  - Read every name from the instance.
- `ui/tools/navigation.test.mjs:932`: `audit-event` → system events, `audit-user-event` → user
  events.
- `ui/tools/audit-marker.test.mjs` (new): pins `AGENT_WRITE_EVENT` equal to `Kernel/State/Base.cls`
  `Source`/`Type` plus `Kernel/Audit/Event.cls` `EVENTAGENTWRITE`, read from the files.
- `ui/src/app/shell/screen-action-handler.spec.ts` (new block after `:652`):
  - reset and enable are sent at once;
  - the marker disable opens `warning` and other rows do not;
  - delete opens typed-name, with the advisory only on the marker row.
- `list-page.spec.ts`: a warning is rendered.
- `auditing-config.page.spec.ts`: the wizard button and a sequential stop.
- `ui/browser/audit-events.browser-spec.mjs` (new; `ocupilot-ci` only; `before` asserts auditing
  on; `after` restores `AgentWrite` enabled and auditing, and removes the probe):
  - the system-row enable/disable and reset;
  - the marker disable → dialog → banner → enable clears it;
  - the probe delete through typed-name;
  - the wizard ticks one box → Apply → one POST → the row is enabled → restored.
- `ui/angular.json`: re-base `maximumWarning` under DW-1166 **only if** `npm run build` exceeds
  1181kB.

**Acceptance Criteria:**

- AC1: Given the System events list, when the user acts on a row, then it can be enabled,
  disabled and reset, sent at once, and the row re-fetches in place. *Pins:* browser system leg,
  `AuditingUpdate`.
- AC2: Given the Selective SQL auditing dialog, when a box changes and Apply is pressed, then
  exactly the changed granular SQL events are enabled or disabled through the system `update`
  action, and nothing is sent for an unchanged box. *Pins:* `sql-audit-dialog.spec.ts`, page spec,
  browser wizard leg.
- AC3: Given the User events list, then an event can be enabled, disabled, reset and deleted, the
  delete behind the typed-name dialog. *Create and Description edit: IG-1.* *Pins:* browser probe
  leg, `AuditingUpdate`.
- AC4: Given `Security.Audit.Event`'s templateless upsert, then the `update` tools admit only
  `Enabled` from the class-derived list, and a write against a vanished event is refused with no
  stub created, for both callers. *Pins:* `AuditEventTools`, `AuditingUpdate` upsert legs.
- AC5: Given the marker event, when a disable or delete is attempted, then the screen states
  `proposalAuditWarning` (a warning dialog, or the typed-name advisory) and the agent's card
  carries it. The banner appears on the disable from either caller and clears on the enable.
  *Pins:* browser marker leg, `AuditEventTools` predicate, `AuditingUpdate` marker leg.
- AC6 (DW-1529): Given a user-event change, then its toast and link open the User events list.
  *Pin:* `navigation.test.mjs`.
- AC7 (DW-1530): Given a principal holding exactly the declared pairs, when it runs a user-event
  screen action, then the marking fact is observed and no `OBSERVEFAILED` line is written. *Pin:*
  the `ProhibitedRoute` leg.
- Integration AC (Rule 1): the panel's banner consumes the fact the event tools record, observed
  in the browser against `ocupilot-ci`, never a mock.

## Spec Change Log

- 2026-09-23, lead spec gate (partial): IG-3 ratified -- the "agent writes stop being marked"
  consequence appears only for `OcuPilot/Security/AgentWrite`, the one event whose disable or delete
  stops marking. IG-1 and IG-2 are with the orchestrator.

## Review Triage Log

## Design Notes

**Governing ADs:** AD-53 (and its `MOVESMARKING` amendment), AD-15, AD-3/AD-4 (derived list,
complete body, upsert), AD-51, AD-52 (default `AdminPort`), AD-56 (`{action,id}` only), AD-6,
AD-8, AD-10, AD-13 (fold rules), AD-14, AD-27 (the split is a port wire fact), AD-29, AD-34,
AD-39.

**IG-1: scope (ask-first; blocks).** User-event **create**, and the **Description** half of
"configure", are not deliverable on this branch:

- A create is AD-54's write kind: `Write.CREATES`, `Mint`'s absent-target branch and
  `Prohibited.PermittedCreateFields`.
- A screen-side edit Save is AD-55's route.
- Both exist only on `origin/OCU-1-epic8` (`Write.cls:126-219`, `Mint.cls:160-306,489-637`,
  `Router.cls:94-114`).
- Building either here would be a second create path, which is exactly what AD-54/AD-55 exist to
  prevent. It would also land in hunks Epic 8 owns.

Delivered here: `Enabled` (enable/disable), reset and delete on user events.

Recommendation:

- Amend 7.11's third AC to "enabled, disabled, reset and deleted".
- Add **Story 9.10 "The user audit event editor"** to Epic 9, which becomes eligible once 7 and 8
  merge: create and edit `{Source, Type, Name, Description, Enabled}` as an AD-55 dialog editor
  (Story 8.4's `resource-editor-dialog` / `DIALOG_EDITORS` precedent) over an AD-54 create on
  `Security.Audit.Event`.

The SQL wizard **is** delivered here: it is a checkbox dialog over the existing `update`, not an
editor.

**IG-2: footprint.** These product files are Epic 8-modified, and each edit is unavoidable:

- `Prohibited.cls`: the `COVEREDTYPES` line, which Epic 8 edits too (a one-line merge), plus the
  new arm appended. AD-10 refuses an uncovered type.
- `EntityRef.cls:59` `IDRULES`: the same line as Epic 8's `role`/`resource` rules. AD-13 requires a
  rule per type.
- `Mint.cls`: the `WarnsAuditingOff` body, off Epic 8's hunks.
- `Classification.cls`: two entries placed before `security.auditing.update`, off Epic 8's
  inserts. `ToolFields.cls` is regenerated.
- `screen-actions.ts`: one `ACTION_LABELS` line; Epic 8's hunk is in `DESCRIPTOR_ACTION_LABELS`.
- `AdminPort.cls` (shared-append): the `MUTATINGTYPES`/`BODYLESSTYPES` lines, which both epics
  already edit.

Recommendation: approve. AD-3 needs no `field-lists.mjs` change, because `FieldLists.cls:151`
already carries the class derivation.

**IG-3: which events warn (recommended reading; confirm).** Only
`OcuPilot/Security/AgentWrite`'s disable or delete stops agent writes being marked
(`ObserveMarking` reads that event alone; AD-15). Stating that consequence for `ConfigChange`,
`LedgerRead`, `RoleGranted` or `SecurityChange` would be false. So the warning, advisory and card
warning key on the marker event only.

**DW-1529:** addressed with a second entity type rather than an owner-aware lookup. The change
event carries no owner, and the id does not reveal one. **DW-1530:** addressed by AC7.

**Wizard semantics** (EXPERIENCE row for the lead):

- Apply is sequential and stops at the first refusal. What already applied stays applied, and the
  re-read shows it.
- The agent's path is per-event `update` proposals; no wizard tool.

**Consumes:** 7.4 (the lists, `MOVESMARKING`, `warning-dialog`, `ObserveMarking`), 7.1
(`ScreenAction`, `Operation`, the handler, the typed-name dialog), 7.5 (`CONSTANTBODIES`), 5.10
(the banner fact). **Consumed-by:** the proposed 9.10 (the tools and the port split).

**Copy for the lead to publish** (EXPERIENCE Fixed strings; `strings.ts` append):

| key | wording | where |
| --- | --- | --- |
| `actionResetCounters` | "Reset counters" | row action and command bar on both event lists |
| `auditUserEventDeleteConsequence` | "Deleting this event removes its registration, and the instance discards every record raised for it until it is registered again. This cannot be undone." | typed-name body, Delete user event |
| `auditSystemEventListEmptyAgent` / `auditUserEventListEmptyAgent` | "enable an event this instance should record" / "enable or delete an event an application registered" | empty-state agent invitations |
| `proposalEntityAuditEvent` | "Audit event" | card and toast entity noun |
| `auditSqlWizardAction` | "Selective SQL auditing" | button and dialog title |
| `auditSqlWizardPrompt` | "Which SQL statement types and sources should this instance audit?" | dialog prompt |
| `auditSqlSourceDynamic`/`…Embedded`/`…Xdbc`; `auditSqlKindQuery`/`…Ddl`/`…Dml`/`…Utility` | "Dynamic", "Embedded", "XDBC"; "Query", "DDL", "DML", "Utility" | grid headers |
| `actionApply` | "Apply" | the dialog's primary |
| `auditSqlWizardStopped` | "Not every change was applied. The list shows each event as it is now." | after a refusal |

Reused: `proposalAuditWarning`, `agentDefinitionEnable`/`Disable`, `actionDelete`,
`actionProceed`, `actionCancel`.

## Verification

Destructive checks run only on `ocupilot-ci` (web 52776), one test class per call, and are never
re-submitted. Each restores `AgentWrite` and auditing. Never stop, remove or recreate a container.

**Commands (loop):**

- `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.AuditEventTools`,
  then, one call each: `AuditingScreen`, `Descriptor`, `ToolWrite`, `ReadTool`,
  `SurfaceCoverage`, `ToolRoundTrip`, `Prohibited`, `EntityRef`, `DerivedFields`,
  `ProhibitedRoute`, `AuditingUpdate` -- all green. If `AuditingUpdate` refuses on the reused
  container's arming, its result is read from CI, and a refusal is not a pass.
- `cd ui && npm run test:tools && npm run test:components` -- green.
- `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`,
  then `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci node
  --test --test-concurrency=1 browser/audit-events.browser-spec.mjs
  browser/auditing-screen.browser-spec.mjs` -- green. Auditing and `AgentWrite` read enabled
  after.
- `uv run scripts/check-objectscript.py` on the changed paths -- clean.
- Rule 19, one `mutation:` line per AC. Expected shapes:
  - AC1: drop `reset` from `AuditEventReset.SCREENACTIONS` → browser system leg red.
  - AC2: send every box, not only the changed ones → `sql-audit-dialog.spec.ts` red.
  - AC3: remove the delete's `DESTRUCTIVE_CONSEQUENCES` entry → handler spec and browser delete
    leg red.
  - AC4: skip the fresh-read 404 in the screen path by reading a stub → `AuditingUpdate` upsert
    leg red.
  - AC5: `ClosesMarking` answers 0 → `AuditEventTools` predicate red; drop `WARNING_ROWS` →
    browser marker leg red.
  - AC6: revert `AuditUserEventList` to `audit-event` → `navigation.test.mjs` red.
  - AC7: make `Kernel.Audit.Event.ObserveMarking` answer an error status after its read →
    the `ProhibitedRoute` leg is red on the `OBSERVEFAILED` line.

**Once, before `dev_complete`:** the full ObjectScript sweep on `ocupilot-ci`, per class and one
call at a time, with totals from the numeric-run-index probe. Then `bash scripts/smoke.sh
--container ocupilot-ci --user _SYSTEM --password SYS`, with every check executed. The full
browser suite runs in CI, not locally (Rule 29).

## Auto Run Result

Status: blocked
Blocking condition: intent gap -- IG-1 (user-event create and Description edit need AD-54/AD-55,
which exist only on Epic 8's branch; recommended: amend 7.11 AC3 and charter Story 9.10), IG-2
(six Epic 8-modified product files listed under Design Notes; recommended: approve), IG-3 (the
warning keys on `OcuPilot/Security/AgentWrite` alone; recommended: confirm). The spec is otherwise
complete; on ratification set `status: ready-for-dev`.

Planning note: two `Security.Events.Create` shape probes ran on slot A and were refused (#851,
`<SUBSCRIPT>`); `Exists` read 0 for both, so nothing was created.
