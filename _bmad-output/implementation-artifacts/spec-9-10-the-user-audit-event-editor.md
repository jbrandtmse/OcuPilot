---
title: 'Story 9.10: The user audit event editor'
type: 'feature'
created: '2026-09-24'
status: 'done'
baseline_revision: 'c8f9f0c79a1cfa9cd551a3ebb6da093b9941c6e9'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-9-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-7-11-system-and-user-audit-event-configuration.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** A person can enable, disable, reset and delete a user audit event from OcuPilot (Story 7.11), but cannot create one or change its description. The agent cannot do either. Each audit event tool also accepts the other list's events, so a user event changed through a system tool publishes `audit-event` (DW-1575).

**Approach:** Add a dialog editor to the User events list, following the Story 8.4 resource editor:

- **Create** opens it empty. The Save goes to a new `POST /audit-events` through a new create tool, `security.audituserevents.create` (AD-54, AD-55).
- **The name cell** opens it over one event. Only Description is editable, and the Save goes to `PUT /audit-events/:id` through the existing `security.audituserevents.update` (AD-4, AD-55).

The vendor's measured rules for Source, Type and Name are checked on the server before any port call. Every audit event tool refuses events from the other list.

## Boundaries & Constraints

**Always:**

- **One tool per write, two callers.** The agent's create and Description edit use the same tool classes the Save resolves: endpoint, request type, settable fields, composition and port. The Save mints no proposal and emits no marker, and read-only and the kill switch do not gate it. It does inherit AD-10's set, the rules and the list's pairs (`%Admin_Secure:USE`, `%DB_IRISSYS:READ`) (AD-53, AD-55, AD-8).
- **Create kind.**
  - `AuditUserEventCreate` sets `CREATES 1`, `CHANGEACTION created`, `WRITETYPE PUT` and `PERMITTEDFIELDS "Description,Enabled"`.
  - Its id argument is `EventName` (`Source/Type/Name`) with `IdParam event`, split by the existing `AdminPort` `SPLITQUERIES`.
  - The agent's mint needs the target absent, and its fingerprint is that absence. A name taken since the mint is refused at confirm and never overwritten (AD-54: the PUT is an upsert).
  - The Save reads fresh too. A present target is refused `AUDITEVENT.TAKEN` on the Name field, and nothing is sent.
- **Edit.**
  - `AuditUserEventUpdate`'s `PERMITTEDFIELDS` becomes `"Description,Enabled"`. The system tool stays `Enabled` only.
  - The Save reads fresh, merges only the sent `Description` and sends the complete `{Description, Enabled}` (AD-4).
  - An edit body carrying any key other than `Description` is refused 400 `PORT.FIELD.UNEXPECTED`.
  - A target absent at the fresh read is refused 404 `AUDITEVENT.ABSENT`, and no stub is created.
- **Identity is read-only once created.** Source, Type and Name are not editable in edit mode. Enabled is not shown there: enable and disable stay the row actions that carry 7.11's marker warning.
- **Rules**, in `Area/Security/AuditEventRules.cls`. The Save calls them, and so does every tool's `ArgumentProblem`. Each refusal is `{field, code, reason}` and is checked before any port call:

  | Code | Field | When |
  |---|---|---|
  | `AUDITEVENT.PART.REQUIRED` | the part | a part is empty |
  | `AUDITEVENT.PART.LENGTH` | the part | a part is over 64 characters |
  | `AUDITEVENT.PART.SLASH` | the part | a part contains `/` |
  | `AUDITEVENT.PART.RESERVED` | `Source` or `Type` only | the value begins with `%`. A Name beginning with `%` is allowed (measured). |
  | `AUDITEVENT.DESCRIPTION.LENGTH` | `Description` | over 256 characters |
  | `AUDITEVENT.EVENTNAME.SHAPE` | `EventName` | the agent's id is not exactly three `/`-separated parts |
  | `AUDITEVENT.SYSTEM` | `EventName` | a user tool is given a system event |
  | `AUDITEVENT.USER` | `EventName` | a system tool is given a user event |
  | `AUDITEVENT.TAKEN` | `Name` | a create finds the event already present |
  | `AUDITEVENT.ABSENT` | `EventName` | the edit's target does not exist |

- **Ownership (DW-1575).** A system event is one whose Source begins with `%` (measured: the two lists split exactly on it). Every tool refuses the other list's events: `AuditEventUpdate` and `AuditEventReset` refuse user events, and the user update, reset, delete and create refuse system events. The check runs in `ArgumentProblem` (the mint) and in `ScreenActionDelta` (the screen action), and the Save calls it itself. The confirm needs no re-check, because the id cannot move.
- **Marking.** The create tool declares `MOVESMARKING 1`, since creating `OcuPilot/Security/AgentWrite` reopens marking. When a Save writes through a tool that declares `MOVESMARKING`, it then observes and records the marking fact through `Kernel.Audit.Event.ObserveMarking`/`RecordMarking`. This is the observation `Api/ScreenAction.cls:300-316` makes. It never fails the write (AD-53 as amended, AD-15).
- **AD-14.** After a successful Save the client publishes `audit-user-event` `created` or `updated` with the canonical triple the server answers.
- **Copy.** Every new label, refusal sentence and prompt is a row in EXPERIENCE.md's Fixed strings marked `[ADDED 2026-09-24 - see the story change log]`, and also a key in `strings.ts`. A value that already exists reuses its key. `\uXXXX` escapes only, and tokens only.
- **Probes.** They run on `ocupilot-ci` only, create events under Source `OcuP910Probe` only, and delete each one by exact name after the test.

**Never:**

- A third write mechanism, a new AD-27 case or a new AD-4 port exception. The admin API carries the create (measured 201).
- A system event created or edited through a user tool.
- A new prohibition. AD-10 names no audit-event effect.
- Editing Source, Type, Name or Enabled through the edit dialog.
- A full-page route for this editor.
- Edits beyond appends in shared-append files.
- A full browser-suite run locally.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected | Error |
|---|---|---|---|
| Create | `OcuP910Probe/Editor/One`, Description `d`, Enabled off, then Save | 201. The dialog becomes edit mode over the event. The list re-fetches and shows the row disabled | — |
| Name taken | Create `ocup910probe/editor/one` when `OcuP910Probe/Editor/One` exists | Nothing is sent, and the stored Description is unchanged | 422 `AUDITEVENT.TAKEN` on Name |
| Reserved | Source `%Mine`, or Type `%T` | Nothing is sent | `AUDITEVENT.PART.RESERVED` on that field |
| Bounds | a part of 64 characters, and Description of 256 | Created | — |
| Over bounds | a part of 65 characters, or Description of 257 | Nothing is sent | `PART.LENGTH` / `DESCRIPTION.LENGTH` on the field |
| Agent create race | Mint a create, create the same event directly, then confirm | The direct Description survives, and no second write is made | 409 `PROPOSAL.TARGETCHANGED` |
| Edit | A disabled event; change Description; Save | 200. Enabled still reads false (the untouched field survives) | — |
| Edit vanished | The event is deleted after the dialog opened; Save | `Security.Events.Exists` stays 0 | 404 `AUDITEVENT.ABSENT` |
| Wrong list | The system update or reset on a user event, or a user tool on `%System/%Security/AuditChange` (either caller) | Nothing is sent | `AUDITEVENT.USER` / `AUDITEVENT.SYSTEM` |
| Agent id shape | `EventName: "a/b"` | No proposal is minted | `AUDITEVENT.EVENTNAME.SHAPE` |

</intent-contract>

## Code Map

S = `src/OcuPilot/`, U = `ui/src/app/`.

**Measured 2026-09-24 on `ocupilot-ci`** through `/api/admin/v2/security/audit/event?source=&type=&name=`. Every probe event was deleted afterwards, and the user list reads as it did before.

- GET answers `{Description, Enabled}`; an absent event answers 404, #853.
- PUT is an upsert:
  - An absent event answers 201 and is created. `{}` creates it with `Enabled` true and `Description` `""`.
  - An update keeps an omitted key.
  - The key folds case: a PUT to `ocup910/t/n1` changed `OcuP910/T/N1`, and the stored case was kept.
- **Source/Type/Name rules:**
  - A Source or Type beginning with `%` answers 500, #851 (`%System` too). A Name beginning with `%` is created.
  - A part over 64 characters answers 500, #7201 (`MAXLEN` 64). Exactly 64 is created.
  - A `/` in Type or Name answers #851. In a Source it answers `<SUBSCRIPT>`.
  - An empty part answers `<SUBSCRIPT>`.
  - A Description over 256 characters answers 500. Exactly 256 is created.
  - Space, tab, `^`, `,`, `:`, `"` and `é` are all created.
- The two lists split exactly on the `%` prefix: `eventOwner=1` has 75 rows, all beginning with `%`; `eventOwner=0` has 6, none beginning with `%`.

**Server:**

- `S/Screen/Tool/AuditEventUpdate.cls` (`PERMITTEDFIELDS` :34, `ScreenActionDelta` :109), `AuditUserEventUpdate.cls` :7-11, `AuditEventReset.cls`, `AuditUserEventReset.cls` and `AuditUserEventDelete.cls`:
  - None of them checks ownership.
  - `IdArgument` is `EventName` and `IdParam` is `event` (:57/:64).
- `S/Screen/Tool/Write.cls`:
  - `CREATES` :141, `ComposeCreate` :304 (its default is `Mint.Compose`), `IdArgument` :490.
  - `ScreenActionDelta` :574 (the screen action calls it after the fresh read, `Api/ScreenAction.cls:219`).
  - `ArgumentProblem` :776 (the mint calls it for every tool, creates included, `Kernel/Proposal/Mint.cls:216-226`).
  - The create's absence read and refusal are at `Mint.cls:164-183` and `:264`, and the confirm's at `Confirm.cls:590-612`.
- Template: `S/Screen/Tool/ResourceCreate.cls` (whole) and `S/Area/Permissions/ResourceSave.cls`:
  - `CREATETOOL`/`UPDATETOOL` :21-23, `EDITFIELDS` :32;
  - `Create` :114, `Update` :153 (the fresh read, the 404 and `Mint.Merge`);
  - `Prohibited` :211, `Send` :227, `RenderViolations` :292.

  `ResourceSave.Create` does no absence read; `AuditEventSave.Create` must do one.
- `S/Kernel/Proposal/Prohibited.cls`:
  - `PermittedChangeFields` :529-531 (`Enabled` for both audit types).
  - `PermittedCreateFields` :634 has no audit arm, so a create is refused `UNCOVERED` at :912-915.
  - The `AuditEvent` arm is at :2805 (`ReviewedFewOnly`).
- `S/Api/Router.cls`: the `/resources` block is at :107-110, the per-editor blocks at :95-161, and the ordering rules at :56-71.
- `S/Api/Error.cls`: the LDAP family pattern is at :2946-3003, and the `ReasonForViolation` dispatch at :1065 and :1215.
- `S/Kernel/EntityType.cls:19-23`: its sentence "the id does not reveal one" is wrong (see the measurement above).
- `S/Screen/Tool/Classification.cls`: the audit entries are at :133/:140. Regenerate with `cd ui && node tools/field-lists.mjs`. `FieldLists.cls:151` (`Description,Enabled`) is unchanged.
- `S/Screen/Descriptor/AuditUserEventList.cls:39`: `primaryAction` `{"id": ""}`. It has no `suggestedPrompts` (Registry :564).
- Arming is in `scripts/ci-throwaway.sh`: `OCUPILOT_ALLOW_AUDIT_EVENTS` `# classes:` at :226, and `PRINCIPALS` at :197-212. `ui/tools/ci.test.mjs` holds the rosters.

**Client:**

- Template (Story 8.4):
  - `U/areas/permissions/resource-editor-dialog.ts`: the create/edit heading at :197, `readOnly` on edit at :100, `fieldView` at :336 and `focusRefusal` at :311.
  - `resource-editor.store.ts`: `openCreate` :293, `openEdit` :309 and `save` :425-480 (an edit sends only what changed, and an unchanged edit sends nothing). `publish` :575.
  - `resource-list.page.ts` :37-129 and `resource-actions.ts` :28.
- Registration points:
  - `U/shell/screen-outlet.ts:114` (`DESCRIPTOR_PAGES`);
  - `U/core/navigation.ts:209` (`DIALOG_EDITORS`);
  - `U/app.ts:254` (eager actions injection) and `:541` (reset on sign-out).
- Shared pieces: `U/shell/dialog.ts` (`app-dialog`), `U/core/violations.ts` and `FormDirty`. The name cell already links to `security/auditing/user-events/<EventName>` (`U/shell/data-table.ts:497-511`).
- Copy: `U/core/strings.ts` (the per-story block ends at :2139). `ui/tools/strings.test.mjs`:
  - literal band at :551;
  - no duplicate values (:580-599);
  - `EXPERIENCE.md:<n>` citations (:755-789). The `taskCreate` citation at :1949 points below the table and shifts when rows are appended.
- Budget: `ui/angular.json:54` (`1561kB`) and its pinned literal at `ui/tools/angular-json.test.mjs:375`. Measured after 9.9: 1,560,536 B, which leaves 464 B.
- Browser:
  - `ui/browser/resources-editor.browser-spec.mjs`: `openCreate` :117, `fill` :129 and `clickDialogButton` :149.
  - `audit-events.browser-spec.mjs`: `runIris` :80, and the `-ci` guard :54.
  - The DW-1337 dialog gate template is `ssl-editor.browser-spec.mjs:425-476`.

## Tasks & Acceptance

**Execution:**

Server:

- `S/Area/Security/AuditEventRules.cls` (new) -- `Validate` implements the rules table; `OwnerProblem(pTool, pEventName)` implements the ownership rule; `HandleForm` answers `GET /audit-events/form?event=`:
  - with no event: `{maxLengths}`;
  - with an event: `{event:{Source,Type,Name,Description,Enabled}, maxLengths}`;
  - it refuses `AUDITEVENT.SYSTEM` or `AUDITEVENT.ABSENT`.
  -- AD-39, AD-55.
- `S/Screen/Tool/AuditUserEventCreate.cls` (new) -- as in Boundaries. `DESCRIPTORCLASS` is `AuditUserEventList`, the pairs are those of `ResourceCreate.PrivilegePairs`, and `InputSchema` states the `Source/Type/Name` format. `ArgumentProblem` calls the rules and `OwnerProblem` -- AD-3, AD-54.
- `S/Screen/Tool/AuditEventUpdate.cls`, `AuditEventReset.cls`, `AuditUserEventUpdate.cls`, `AuditUserEventReset.cls`, `AuditUserEventDelete.cls`:
  - Each gets a list-owner parameter.
  - `ArgumentProblem` and `ScreenActionDelta` call `OwnerProblem` first, then `##super`.
  - The user update's `ArgumentProblem` also calls `Validate` for `Description`, and it widens `PERMITTEDFIELDS`.
  -- DW-1575.
- `S/Area/Security/AuditEventSave.cls` (new) -- `ResourceSave`'s shape:
  - `Create`: rules, then the absence read through the port (a present event gives `TAKEN`), then `Prohibited`, then `Compose`, then `Send`.
  - `Update`: `EDITFIELDS "Description"`, then the fresh read (404 gives `ABSENT`), then `OwnerProblem`, then `Validate`, then `Mint.Merge`, then `Prohibited`, then `Send`.
  - Then the marking observation, and the answer `{target}` from `EntityRef.Wire`.
  -- AD-55, AD-4, AD-53.
- `S/Api/Router.cls` -- append `GET /audit-events/form`, `PUT /audit-events/:id` and `POST /audit-events` as one block after `/ldap/:id`, with thin wrappers -- AD-12, route ordering.
- `S/Api/Error.cls` -- append the `AUDITEVENT.*` codes, one `REASON*` parameter each, `AuditEventViolationCodes`, and the dispatch line -- AD-39.
- `S/Kernel/Proposal/Prohibited.cls`:
  - `PermittedCreateFields` gains `audit-user-event` = `Description,Enabled`.
  - `PermittedChangeFields` gives `audit-user-event` `Description,Enabled` and leaves `audit-event` `Enabled`.
  -- AD-10, AD-54.
- `S/Screen/Tool/Classification.cls` -- add a `security.audituserevents.create` entry (both fields `ordinary`), then regenerate `ToolFields.cls` -- AD-3.
- `S/Screen/Descriptor/AuditUserEventList.cls` -- `primaryAction` `{"id":"create"}`, plus three `suggestedPrompts`. Update the doc comment -- AD-5, Story 11.3.
- `S/Kernel/EntityType.cls` -- replace the wrong sentence with the `%` rule.

Client:

- `U/areas/security/audit-event-editor.store.ts` and `audit-event-editor-dialog.ts` (new, each with a spec) -- a mirror of the resource store and dialog:
  - Fields in order: Source, Type, Name, Description, Enabled. In create mode Enabled is checked by default. In edit mode the identity fields are `readOnly` and Enabled is absent.
  - `maxlength` comes from the form read.
  - A refusal lands on the field it names. The error summary takes focus.
  - The dirty guard applies.
  - After a Save it publishes `audit-user-event`. The checkbox styles live in the component, not in `_components.scss`.
- `U/areas/security/audit-user-event-list.page.ts` and `audit-event-actions.ts` (new) -- the `ResourceListPage` and `ResourceActions` shape.
- `U/shell/screen-outlet.ts`, `U/core/navigation.ts` (`DIALOG_EDITORS`) and `U/app.ts` -- one registration line each, plus the reset line.
- `U/core/strings.ts` and EXPERIENCE.md Fixed strings -- the copy under Design Notes. Then `node tools/screen-mirror.mjs`.

Tests:

- `S/Test/AuditEventRules.cls` (new, unarmed, no instance write):
  - every rules row, at 64/65 and 256/257, with a `%` Name allowed;
  - ownership in both directions on all six tools, through both hooks;
  - the create tool's declarations and its schema;
  - both `Prohibited` field lists.
- `S/Test/AuditEventEditor.cls` (new, armed `OCUPILOT_ALLOW_AUDIT_EVENTS` and `OCUPILOT_ALLOW_PRINCIPALS`; append it to both `# classes:` lines and to `ci.test.mjs`):
  - the Matrix rows over HTTP;
  - the agent's create, the agent create race and the agent's Description edit;
  - a principal holding exactly the list's pairs creates and edits.
- The rosters, with only this story's rows and every name read from the instance:
  - `ToolWrite`, `SurfaceCoverage`, `ReadTool` (count), `ToolRoundTrip`, `Prohibited`;
  - `Descriptor`, `EndpointCoverage`, `Wire`;
  - `AuditEventTools` :35 (the widened `PERMITTEDFIELDS`) and :60 (its args now carry a system id).
- `ui/tools/audit-event-copy.test.mjs` (new) -- each `REASONAUDITEVENT*` in `Error.cls` equals its `strings.ts` value and is a Fixed-strings literal.
- `ui/browser/audit-event-editor.browser-spec.mjs` (new; `-ci` guard; `before` and `after` remove the `OcuP910Probe` events by exact name):
  - create through the command bar, and the row appears;
  - a `%` Source shows the sentence on the Source field, and nothing is created;
  - the name cell opens the dialog with identity read-only; a Description change is read back by `docker exec`;
  - the DW-1337 gate on the open dialog in both modes.
- `ui/angular.json` and `angular-json.test.mjs:375` -- raise both to the measured initial total rounded up to the next kB, never above 1580kB.

**Acceptance Criteria:**

- **AC1 (DW-1573).** Given the User events list, when the user chooses Create, fills in Source, Type, Name, Description and Enabled, and saves, then the event exists as entered. The agent's `security.audituserevents.create` makes the same write through the same tool. A name taken after the mint is refused at confirm, and the vendor's upsert never overwrites it.
- **AC2 (DW-1573).** Given an existing user event, when its name cell is followed and its Description is saved, then only Description changes, every other field reads back unchanged, and Source, Type and Name cannot be edited.
- **AC3 (DW-1575).** Given the measured vendor rules, when either caller breaks one, then the refusal is OcuPilot's sentence on the named field, and no port write happens. Every audit event tool refuses the other list's events, so a system event can be neither created nor edited through a user tool.
- **AC4.** Given the new labels, refusal sentences and prompts, when they render, then each one is a Fixed-strings row and a `strings.ts` key, and each server reason is pinned equal to its row.
- **Integration.** Given the dialog, which consumes `/audit-events/*` and `ChangeBus`, when a Save succeeds, then the User events list re-fetches and shows the change, observed in the browser against `ocupilot-ci`.

## Spec Change Log

- 2026-09-24 spec gate (lead): the four questions answered as recommended - (1) EXPERIENCE.md :173's dialog list now names the user audit event editor (Rule 5 tier 1, applied and reported); (2) edit mode carries Description only, Enabled stays a row action; (3) `maximumWarning` and its pinned literal re-base to the measured total below 1580kB (DW-1166), HALT above it with the lighter design; (4) the refusal sentences are `strings.ts` keys pinned equal to the server's.

## Review Triage Log

### 2026-09-24 — Review pass

- verdicts: 16 findings — high 0, medium 4, low 7, false 5, maybe-false 0
- findings:
  - `[medium]` `[patch]` The Save's post-write marking observation (`AuditEventSave.Send`) had no test -- added `Test/MarkingSave.cls` (port seam on `MarkingPort`) and `AuditEventEditor.TestASaveRecordsTheMarkingItObservesAfterTheWrite`; red with the observation removed.
  - `[medium]` `[patch]` The Description bound on the edit path was untested for both callers -- added a 257-character `PUT` leg (422 `Description:AUDITEVENT.DESCRIPTION.LENGTH`, stored value unchanged) and an `AuditUserEventUpdate.ArgumentProblem` assertion; each red under its mutation.
  - `[medium]` `[patch]` The store spec's `canSave` mutation could not redden (its 404 stub set `absent` first) -- added a 500-read leg where only the held read blocks Save; demonstrated red, and the comment moved there.
  - `[low]` `[patch]` Browser `stored()` read a failed probe as `''`, making the absence assertions vacuous on a probe failure -- it now fails when the instance gives no answer. The vendor-guaranteed "nothing created" clauses stay secondary; the 422 sentence is the discriminating assertion.
  - `[false]` `[reject]` AC1/AC2 clauses without their own `mutation:` line -- Rule 19 scopes to one demonstrated pinning mutation per AC, and AC1 and AC2 each carry one.
  - `[low]` `[reject]` The create tool's `OwnerRefusal` cannot fire after the part rules -- the spec's task names it; harmless, and removing it edits specified behavior.
  - `[false]` `[reject]` The form read with a present event is tested only in the browser -- the browser AC2 leg reads it against the instance and asserts the identity and Description it returns.
  - `[low]` `[reject]` Ownership refusals reach the mint and screen actions as `TOOL.ARGUMENTS` text with the sentence, not the code -- the Boundaries place the check in the two hooks whose contract is a problem string; carrying the code needs new envelope surface.
  - `[low]` `[reject]` A user create on `%System/...` answers `PART.RESERVED`, not `AUDITEVENT.SYSTEM` -- the Reserved row requires `PART.RESERVED` for a `%` Source on create, nothing is sent either way, and the mint's absence check refuses an existing system event first.
  - `[low]` `[reject]` Ownership for the user delete, system reset mint and create mint is tested through the hooks, not over HTTP -- the hooks are the seams both callers call, tested on all six tools, and the HTTP legs prove the wiring for both callers.
  - `[medium]` `[patch]` (grouped with the first row) No test checks the recorded marking fact after a Save -- same patch.
  - `[low]` `[reject]` AD-10 on a create, read-only/kill-switch independence, extra create keys and the full edit body are untested -- AD-10 names no audit-event effect, the Save has no read-only path, and the full body is pinned by the AC2 mutation.
  - `[false]` `[reject]` The create race does not observe "no second write" -- a confirm write would store the proposal's `agent|1`; the leg asserts `direct|0`.
  - `[false]` `[reject]` "The list re-fetches" is asserted through the changed marker -- the row did not exist before the create, so its appearance (now also with the disabled disc) is the re-read.
  - `[low]` `[patch]` The 64-character bounds probe was outside `OnAfterOneTest`'s sweep -- `OnAfterOneTest` now removes it by exact name.
  - `[false]` `[reject]` Edits beyond appends in shared-append files -- the `Error.cls` dispatch line is the spec's task, the `strings.ts` citation shift is forced by the strings test, and the other files are not shared-append files.

## Design Notes

**Governing ADs:** AD-3, AD-4, AD-5, AD-6, AD-8, AD-10, AD-13 (fold case, composite id in one segment), AD-14, AD-15, AD-19, AD-39, AD-52 (default `AdminPort`), AD-53 (with the marking amendment), AD-54, AD-55. AD-27 applies only as containment: nothing names `%Api.Admin`.

**Choices:**

- **A dialog, not a form page.** The AC asks for one, and the Story 8.4 precedent fits a five-field object.
- **Configure means Description.** DW-1573's own reading. Enabled stays with the row actions, so the marker warning keeps one home.
- **Ownership lives on the tool,** because both callers already pass through `ArgumentProblem` or `ScreenActionDelta`. A read-side 404 would make a user-tool create read a system event as absent (explorer's trap).
- **Validation beyond the vendor's.** None, except the agent's three-part shape. Whitespace, tab, `^` and non-ASCII are accepted, as the vendor accepts them.

**Bundle estimate (inference):** +12 to 17 kB.

- Basis: Story 9.9 added about 35 kB of TypeScript source, 29 literals and 154 SCSS lines, and cost +22.6 kB. This story's four client files are about 28 kB of source.
- That gives about 1,573 to 1,578 kB, under the 1580kB stop line and over the 1561kB warning.
- If the measured total exceeds 1580kB, implement HALTs `intent gap`. The lighter design is to drop the page wrapper and the route-driven edit, and make the Description edit an AD-53 value row action ("Edit description") through the existing screen-action handler. That saves about 5 kB (inference).

**Contention.** `origin/OCU-1-epic12` edits:

- `Api/{Error,Router}.cls`, `Kernel/Proposal/Prohibited.cls`, `Screen/Tool/{Classification,ToolFields}.cls`, `scripts/ci-throwaway.sh`;
- `U/app.ts`, `U/shell/screen-outlet.ts`, `U/core/{strings,screens.generated}.ts`, EXPERIENCE.md;
- the test rosters (`ToolWrite`, `SurfaceCoverage`, `ToolRoundTrip`, `Prohibited`, `Descriptor`, `EndpointCoverage`, `Wire`, `ReadTool`).

Every edit here is an append or a one-line roster change. Footprint extensions: `Kernel/EntityType.cls`, `Kernel/Proposal/Prohibited.cls`, `U/app.ts`, `U/shell/screen-outlet.ts`, `U/core/navigation.ts`.

**Integration ACs:**

- **Consumes:** 7.11's tools and `SPLITQUERIES`; AD-54's create kind (`Write.CREATES`, `Mint`, `Confirm`); 8.4's Save and dialog pattern; `ChangeBus`, `FormDirty` and `app-dialog`.
- **Consumed-by:** none. No consumers in this story; the create tool and `/audit-events/*` are leaf services, and no later story names them.

**Ledger inbox:** DW-1573 is AC1 and AC2. DW-1575 is AC3.

**Copy** (Fixed strings rows and `strings.ts`; reuse the existing keys for "Name", "Description", "Enabled", "Create", "Save" and "Cancel"):

| Where | Wording |
|---|---|
| Headings | "New user event" · "Edit user event <name>" |
| Labels | "Source" · "Type" (reuse any existing key) |
| `PART.REQUIRED` | "Enter a value. An audit event is named by its source, type and name." |
| `PART.LENGTH` | "Use 64 characters or fewer." |
| `PART.SLASH` | "Remove the slash. An event's source, type and name are joined with slashes, so none of them can contain one." |
| `PART.RESERVED` | "Start with a character other than %. A source or type beginning with % is reserved for the instance's own system events." |
| `DESCRIPTION.LENGTH` | "Use 256 characters or fewer." |
| `EVENTNAME.SHAPE` | "Name the event as source/type/name: three parts, none containing a slash." |
| `SYSTEM` | "This is one of the instance's own system events. Change it on the System events list." |
| `USER` | "This is a user event. Change it on the User events list." |
| `TAKEN` | "This instance already has an audit event with this source, type and name." |
| `ABSENT` | "This audit event no longer exists." |
| Prompts (three) | "Which user events are enabled?" · "Which user events have recorded the most?" · "Register an audit event for my application." |

**Questions for the lead** (the spec implements each recommended answer):

1. **EXPERIENCE.md:173** lists the only permitted dialogs, and it does not include this editor.
   *Recommended:* add "user audit event editor" (Rule 5, apply and report). The AC names a dialog.
2. **Enabled in edit mode.**
   *Recommended:* omit it, as described under Choices.
3. **Bundle.**
   *Recommended:* implement re-bases `maximumWarning` and its literal to the measured total rounded up to the next kB. It HALTs above 1580kB and offers the lighter design.
4. **Refusal sentences as `strings.ts` keys** that only the server renders (AC4, DW-1502's open question).
   *Recommended:* yes, pinned equal by `audit-event-copy.test.mjs`.

## Verification

**Commands (loop):**

- `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.AuditEventRules`, then one call at a time for `AuditEventEditor`, `AuditEventTools`, `AuditingUpdate`, `ProhibitedRoute`, `Prohibited`, `ToolWrite`, `SurfaceCoverage`, `ReadTool`, `ToolRoundTrip`, `Descriptor`, `EndpointCoverage`, `Wire` and `DerivedFields` -- each green. Load with `/private/tmp/claude-501/epic-9-loaders/load-ci.sh` (read it first).
- `cd ui && npm run test:tools && npm run test:components` -- green.
- `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`, then `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci node --test --test-concurrency=1 browser/audit-event-editor.browser-spec.mjs browser/audit-events.browser-spec.mjs` -- green. That includes the DW-1337 structural gate on `[role="dialog"]`: every input has an accessible name, no control is narrower than its declared minimum (24 px, or its computed `min-width`), and nothing overflows its container.
- `uv run scripts/check-objectscript.py` on the changed paths -- clean.
- Rule 19, one `mutation:` line per AC:
  - AC1: skip the Save's absence read → `AuditEventEditor` TAKEN leg red.
  - AC2: send the fresh `Enabled` as `true` → the untouched-field leg red.
  - AC3: `OwnerProblem` answers `""` → `AuditEventRules` ownership legs red; drop the `%` check → the browser Source leg red.
  - AC4: change one word of a `REASONAUDITEVENT*` → `audit-event-copy.test.mjs` red.
  - Integration: drop the store's `publish` → the browser create leg red.

- `mutation: AC1 -- AuditEventSave.Create's absence read never answers TAKEN (ocupilot-ci copy) -> AuditEventEditor.TestACreateThenATakenNameThenADescriptionEdit red on the 422 TAKEN leg and the stored Description overwritten (run 11034). DEMONSTRATED 2026-09-24, restored, whole tree reloaded, 8/8 green (run 11037)`
- `mutation: AC2 -- AuditEventSave.Update sends Enabled true in the merged body (ocupilot-ci copy) -> AuditEventEditor.TestACreateThenATakenNameThenADescriptionEdit red on "Enabled still reads false" (run 11035). DEMONSTRATED 2026-09-24, restored`
- `mutation: AC3 -- AuditEventRules.OwnerProblem answers "" (ocupilot-ci copy) -> AuditEventRules.TestEveryToolRefusesTheOtherListsEventsThroughBothHooks red on both hooks of all five list tools (run 11036); drop the % check from PartViolation -> audit-event-editor.browser-spec.mjs AC3 red at the Source sentence wait, nothing registered. DEMONSTRATED 2026-09-24, restored, 5/5 green`
- `mutation: AC4 -- REASONAUDITEVENTTAKEN reworded "has" -> "holds" -> audit-event-copy.test.mjs red naming REASONAUDITEVENTTAKEN and auditEventRefusalTaken. DEMONSTRATED 2026-09-24, restored`
- `mutation: Integration -- the store's publish call removed, rebuilt and redeployed -> audit-event-editor.browser-spec.mjs AC1 red at the changed-row wait. DEMONSTRATED 2026-09-24, restored, rebuilt, redeployed, 3/3 green; tree byte-identical (git status, diff --stat and diff digest compared)`
- `mutation: AC3 (edit path) -- AuditEventSave.Update's Validate call removed -> AuditEventEditor.TestACreateThenATakenNameThenADescriptionEdit red on the 257-character edit leg (run 11041); AuditUserEventUpdate.ArgumentProblem's ArgumentViolations call removed -> AuditEventRules.TestEveryRuleRefusesOnItsFieldAtTheBounds red on the agent's Description bound (run 11042). DEMONSTRATED 2026-09-24 (review pass), restored`
- `mutation: Marking (Boundaries) -- AuditEventSave.Send's ObserveMarking call removed -> AuditEventEditor.TestASaveRecordsTheMarkingItObservesAfterTheWrite red (run 11041). DEMONSTRATED 2026-09-24 (review pass), restored, tree byte-identical`
- `mutation: AC2 (client) -- canSave() ignores the held read -> audit-event-editor.store.spec.ts "an edit whose read failed for any other reason" red. DEMONSTRATED 2026-09-24 (review pass), restored`

**Once, before `dev_complete`:** the full ObjectScript sweep on `ocupilot-ci`, one class per call, with totals from the numeric-run-index probe. Then `bash scripts/smoke.sh --container ocupilot-ci --user _SYSTEM --password SYS`. The full browser suite runs in CI (Rule 29).

## Auto Run Result

Status: done
Blocking condition: none

- **Change:** the User events list gains a dialog editor. Create posts to `POST /audit-events` through the new `security.audituserevents.create` (absence read first, `AUDITEVENT.TAKEN` on a taken name in any case). The name cell opens it over one event; Description alone goes to `PUT /audit-events/:id` through the widened `security.audituserevents.update`, merged over a fresh read. Ten `AUDITEVENT.*` rules are checked before any write, all six audit-event tools refuse the other list's events through both hooks (DW-1575), a Save through a `MOVESMARKING` tool records the observed marking fact, and the client publishes `audit-user-event` with the server's triple.
- **Files:**
  - server: `Area/Security/{AuditEventRules,AuditEventSave}.cls` and `Screen/Tool/AuditUserEventCreate.cls` (new); five audit-event tools (owner parameter and hooks); `Api/{Router,Error}.cls` (appended); `Kernel/Proposal/Prohibited.cls` (field lists); `Classification.cls` and the regenerated `ToolFields.cls`; `AuditUserEventList.cls` (Create and three prompts); `Kernel/EntityType.cls` (sentence corrected).
  - client: `areas/security/` store, dialog, list page and actions, plus two specs; registrations in `app.ts`, `screen-outlet.ts` and `navigation.ts`; `strings.ts` and `screens.generated.ts`; `angular.json` and its pinned literal.
  - tests: `Test/{AuditEventRules,AuditEventEditor,MarkingSave}.cls` (new); roster rows in `ReadTool`, `ToolRoundTrip`, `EndpointCoverage`, `SurfaceCoverage` and `AuditEventTools`; `ui/tools/audit-event-copy.test.mjs` and `ui/browser/audit-event-editor.browser-spec.mjs` (new); `navigation.test.mjs`.
  - also: EXPERIENCE.md (four Fixed-strings rows) and `scripts/ci-throwaway.sh` (two `# classes:` lines).
- **Review:** 16 findings. Five were patched (three medium, two low), all test additions, each medium one demonstrated red under its mutation. Six were rejected as low and five as false, with the reasons in the triage log. Nothing was deferred.
- **Follow-up review:** `false`. The three medium patches are tests only, and each went red under its mutation, so no unverified risk remains to name.
- **Verification:**
  - Sweep: the full ObjectScript sweep ran on `ocupilot-ci`, one class per call, runs 11043 to 11290. The `%UnitTest_Result` probe gives 248 classes and 2161 tests, 2160 passed and 1 failed. The one failure is the known residue `WireSecurityRead.TestTaskHistoryPairSetsAreEnforcedForARealPrincipal` (DW-1425/DW-1468, about 2,000 task-history rows on the reused throwaway), which was reported and not fixed.
  - Smoke: `smoke.sh --container ocupilot-ci` passed 49 of 49.
  - This story's browser specs, after rebuilding and redeploying: `audit-event-editor` 3/3 and `audit-events` 4/4.
  - Client: `test:tools` 1407/1407 and `test:components` 1218/1218, with the store spec 7/7 after the patch.
  - Checkers: `check-objectscript.py` and `lint-docs.sh` clean.
  - Probe events left on `ocupilot-ci`: 0.
- **Bundle:** the measured initial total is 1,576,569 B (`main` 1,435,183 plus `styles` 141,386). `maximumWarning` and its pinned literal are 1577kB, below the 1580kB stop line.
- **Residual risk:** a user create of a `%`-Source event answers `PART.RESERVED`, not `AUDITEVENT.SYSTEM`. The matrix's Reserved row requires this. It is recorded in the triage log for the lead.
- **footprint_extensions:**
  - named in the spec's Design Notes: `src/OcuPilot/Kernel/EntityType.cls`, `src/OcuPilot/Kernel/Proposal/Prohibited.cls`, `ui/src/app/app.ts`, `ui/src/app/shell/screen-outlet.ts` and `ui/src/app/core/navigation.ts`;
  - outside the Code Map: `ui/tools/navigation.test.mjs` and `src/OcuPilot/Test/MarkingSave.cls`.
