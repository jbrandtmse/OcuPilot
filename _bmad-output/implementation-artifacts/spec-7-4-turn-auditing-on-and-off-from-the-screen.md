---
title: 'Story 7.4: Turn auditing on and off from the screen'
type: 'feature'
created: '2026-09-23'
status: 'in-progress'
baseline_revision: '6ae2918f4cc1c958b936254cf5849001c8d00d39'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-7-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-5-10-security-and-secrets-disable-and-re-enable-auditing.md'
warnings: ['oversized']
deferred: []
footprint_extensions:
  - 'ui/src/app/shell/screen-outlet.ts'
  - 'ui/src/app/core/screens.generated.ts'
  - 'src/OcuPilot/Test/ToolWrite.cls'
  - 'src/OcuPilot/Test/AuditingUpdate.cls'
  - 'src/OcuPilot/Test/ProhibitedRoute.cls'
  - 'src/OcuPilot/Test/SurfaceCoverage.cls'
  - 'src/OcuPilot/Test/ReadTool.cls'
  - 'src/OcuPilot/Kernel/Audit/Event.cls'
---

<intent-contract>

## Intent

**Problem:** The auditing switch is reachable only through the agent. `AuditingConfig` is declared
`built: false`, so no screen exists. The panel's "not being marked" banner carries its sentence
alone, and Story 5.10 deferred its link and "Turn auditing on" action to this story. The banner
also reads a stored `writesMarked` fact that only install and the agent's confirm write, so a
screen-side disable would leave it hidden.

**Approach:** Build the Auditing configuration form page as the screen caller of Story 5.10's
`security.auditing.update` (AD-53). It gets `enable`/`disable` actions over `POST
/screens/security.auditing/action`. A disable goes through a `button-primary` warning dialog. Make
the screen caller record the observed marking fact after an auditing write, so the banner turns
on and off with the setting. Make the banner's link and action live. Add two read-only event lists
and embed them beneath the form. Add the cross-link to the Audit database viewer.

## Boundaries & Constraints

**Always:** One operation, two callers (AD-53). The screen action reuses `ScreenAction`,
`Operation` and `AuditingUpdate` unchanged in shape. It mints no proposal and emits no OcuPilot
marker. The kill switch and enforced read-only do not gate it. Its pairs are the screen's own
(`%Admin_Secure:USE`, `%DB_IRISSYS:READ`), checked before any read (AD-8). One AD-14
`auditing-configuration` `updated` event per write. The page re-fetches and never patches.
Observing the marking fact never fails the write and never propagates (AD-15's posture). A failed
observation records nothing and logs. The agent's confirm path keeps recording from its marker's
answer, unchanged. Reads the page issues for the lists are those screens' declared reads through
the ordinary read route (AD-5, AD-36). Every new string goes to Fixed strings and `strings.ts`
(append only). Tests restore auditing on every exit path.

**Never:** No second write path. No marker from the screen caller. Do not read `Security.System`
or `Security.Events` directly from a request path; go through `AdminPort` (AD-27). No
auto-refresh (AD-43). No row action on either event list (Story 7.11). No new armed test class and
no `scripts/ci-throwaway.sh` edit. No edit to `Screen/Tool/Write.cls`,
`Kernel/Proposal/Confirm.cls`, `Kernel/Proposal/Mint.cls` or any Epic 8-exclusive file. The page
does not bind `RefreshService`, whose reconcile would clear the singleton selection.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Disable from screen | auditing on; "Turn auditing off" → Proceed | warning dialog first; then one `POST …/security.auditing/action {action:"disable",id:"SYSTEM"}` → 200 `{action:"updated",target:{type:"auditing-configuration",scope:"instance",id:"SYSTEM"}}`; auditing off; `GET /agent/restraint` `writesMarked:false`; banner shows | No error expected |
| Cancel the warning | Escape, Cancel or scrim | zero requests; auditing unchanged; focus returns to the opener | n/a |
| Enable from screen | auditing off; "Turn auditing on" | no dialog; one POST `enable`; `writesMarked:true` when OcuPilot's marker event is enabled; banner clears | No error expected |
| Observation read fails | port fault on the post-write read | write still answers 200; the fact is left as it was; one `Audit.Log` error line | never propagates |
| Short of a pair | principal without `%Admin_Secure:USE` | 403 `AUTH.NOPRIVILEGE`, `detail.failedPair` `%Admin_Secure:USE`, before any read | nothing read or written |
| Banner link | any user, `writesMarked:false` | "Auditing configuration" opens `security/auditing` | a denied user sees the screen's own refusal |
| Banner action | OcuPilot administrator only | "Turn auditing on" opens the screen with that button focused | absent for non-administrators |

</intent-contract>

## Code Map

Measured on `ocupilot-slot-a`, 2026-09-23:

- `AdminPort` on `Security.Audit.Enabled` `GET` answers `{"Enabled":true}` (200).
- `Security.Audit.Event` `LIST` with `eventOwner` 1 answers the system events (75 rows). With 0 it
  answers the user events (4 rows, OcuPilot's own among them, e.g.
  `OcuPilot/Security/ConfigChange`). With 2 it answers all 79.
- A row is `{EventName, Enabled (boolean), Total, Written, Lost}`.
- The vendor endpoint's `ResourcesOR` is `%Admin_Secure`. `GET` needs `source`/`type`/`name` and
  answers `{Description, Enabled}` (`%Api.Admin.Endpoints.Security.Audit.Event`, read from the
  instance).

Server:

- `src/OcuPilot/Screen/Descriptor/AuditingConfig.cls`: `built:false`, `sideBarPosition 0`,
  `rowActions []`, no `read`. The doc paragraphs explain why it is unbuilt.
- `src/OcuPilot/Screen/Tool/AuditingUpdate.cls`: merge write, `SettableFields` = `Enabled`, no
  `SCREENACTIONS`. The `DESTRUCTIVE` doc says the screen's dialog is `button-primary`.
- `src/OcuPilot/Screen/Tool/Write.cls:120-173`: `SCREENACTIONS` grammar
  `enable=Enabled:true,disable=Enabled:false` (the `WebAppUpdate.cls:57` precedent). Read-only
  (contended; Epic 8 has hunks at `:115`, `:176`, `:416`, `:508`).
- `src/OcuPilot/Api/ScreenAction.cls`: `Handle` `:73` requires the action in `RowActionIds` `:112`.
  `Run` `:164`, and the write succeeds at `:260-265`. The hook goes between that and `EntityRef.Wire`
  `:267`.
- `src/OcuPilot/Kernel/Audit/Event.cls`: `WritesMarked` `:299`, `RecordMarking` `:322` (a no-op
  when unchanged, never propagates), plus `Source()`/`Type()`/`EVENTAGENTWRITE`.
- `src/OcuPilot/Kernel/Proposal/Confirm.cls:413` records from `tEmitted`. Unchanged.
- `src/OcuPilot/Install/Installer.cls:3082` `ObserveAuditMarking`: the rule to mirror is
  marked = auditing on AND the marker event enabled. Read only (Epic 8's).
- `src/OcuPilot/Kernel/EntityRef.cls:105` `RULESINGLETONID` = `SYSTEM`. Every spelling folds to it.
- Precedents: `DatabaseVolumeList.cls` (list read), `TaskOnDemandList.cls:54` (`source.query`),
  `LdapConfigList.cls:57` (read-only `table`, `status` column), `SystemUsage.cls` (single-object
  `GET` read).

Client:

- `ui/src/app/shell/screen-action-handler.ts`: roster `:29`, `DESTRUCTIVE_CONSEQUENCES` `:90`,
  `PendingKind` `:104`, `start` `:225` (target = store selection `:351`), `confirmPending` `:182`.
- `ui/src/app/core/screen-actions.ts:81` `DESCRIPTOR_ACTION_LABELS`, and `run()` `:131`.
- `ui/src/app/shell/screen-outlet.ts:86` `DESCRIPTOR_PAGES`. Epic 8 appends three entries here
  and three imports at `:27`.
- `ui/src/app/shell/panel.ts`: the not-marked slot `:253-259`, the reminder link pattern
  `:265`/`:1420-1430`, `administrator` `:622`, `writesNotMarked` doc `:657-672`.
- `ui/src/app/core/agent-status.ts:61`: `RESTRAINT_ENTITIES` already re-reads on an
  `auditing-configuration` change.
- `ui/src/app/areas/os-management/database-details.page.ts:44-80,273-300`: a page issuing another
  screen's declared read and rendering its rows without `app-data-table`.
- `ui/src/app/shell/dialog.ts` (the modal shape, `dialogAction` slot) and `typed-name-dialog.ts`
  (the sibling to copy).
- Existing keys: `auditingOffBanner`, `auditingConfigurationLink`, `auditingTurnOnAction`,
  `proposalAuditWarning`, `actionCancel`, `auditListLabel`, `auditColumnEventName`,
  `tableColumnEnabled`, `tableReadOnlyEmptyNext`.

Tests that pin today's shape and must move:

- `Test/Descriptor.cls:357` `TestTheAuditingConfigurationDescriptorIsDeclaredUnbuiltAndOwnsTheWriteTool`
- `Test/ToolWrite.cls:498-513` (asserts `IsBuilt` 0)
- `Test/SurfaceCoverage.cls:4-8,106`
- `Test/ReadTool.cls:93-94`
- `ui/src/app/shell/panel.spec.ts:286-289`
- `ui/browser/auditing-write.browser-spec.mjs:322-331`

## Tasks & Acceptance

**Execution:**

- `src/OcuPilot/Screen/Descriptor/AuditingConfig.cls`:
  - Set `built:true`, `sideBarPosition 6`, `commandAliases ["auditing"]`.
  - Add `rowActions [{"id":"enable","selfProtection":""},{"id":"disable","selfProtection":""}]`.
  - Add a single-object `read` (`{"port":"admin","endpoint":"Security.Audit.Enabled","type":"GET"}`,
    fields `["Enabled"]`) and set `context.fields ["Enabled"]`.
  - Rewrite the "built: false" doc paragraphs to state what it is now.
- `src/OcuPilot/Screen/Tool/AuditingUpdate.cls`:
  - Add `SCREENACTIONS = "enable=Enabled:true,disable=Enabled:false"`.
  - Add `Parameter MOVESMARKING = 1`, with a doc saying the write opens or closes the channel
    AD-15 marks through.
- `src/OcuPilot/Kernel/Audit/Event.cls`: add `ObserveMarking(pPortClass, Output pMarked) As
  %Status`.
  - Read through `pPortClass`: `Security.Audit.Enabled` `GET`, and `Security.Audit.Event` `GET`
    for `Source()`/`Type()`/`EVENTAGENTWRITE`.
  - `pMarked` = both `Enabled`.
  - Any read fault is an error status (a failed read is never an answer).
- `src/OcuPilot/Kernel/Proposal/Operation.cls` (contended, untouched by Epic 8): add
  `MovesMarking(pToolClass) As %Boolean`. It reads `$Parameter(pToolClass,"MOVESMARKING")`, where
  `""` or an unaskable class means 0.
- `src/OcuPilot/Api/ScreenAction.cls`: after the write succeeds, when `MovesMarking` holds, call
  `ObserveMarking(..PortClass(), .tMarked)` and then `RecordMarking(tMarked)` only on OK. Log an
  error otherwise. Never alter `tSC` or the answer.
- `src/OcuPilot/Screen/Descriptor/AuditSystemEventList.cls` and `AuditUserEventList.cls` (new):
  - Built `list` archetype, `sideBarPosition 0`.
  - Routes `security/auditing/system-events` and `…/user-events`.
  - `toolIdentifier` `security.auditsystemevents` and `security.audituserevents`.
  - `entityType` `audit-event`, id `composite ["EventName"]`, the AuditingConfig pairs,
    `rowActions []`.
  - `read` `Security.Audit.Event` `LIST` with `source.query {"eventOwner":"1"}` and `{"eventOwner":"0"}`.
  - Fields/filter/sort `EventName, Enabled, Total, Written, Lost`.
  - Table columns name/status/number×3, `emptyNextKey tableReadOnlyEmptyNext`.
  - `classicPage` `%CSP.UI.Portal.Audit.SystemEvents` and `%CSP.UI.Portal.Audit.UserEvents`.
- `ui/src/app/shell/screen-action-handler.ts`:
  - Add `AuditingConfig` to the roster.
  - Add `WARNING_CONSEQUENCES` = `{AuditingConfig:{disable: STRINGS.proposalAuditWarning}}`.
  - Add `PendingKind` `'warning'`. `start` opens it when the consequence is non-empty.
    `confirmPending` sends for `typed-name` or `warning`.
- `ui/src/app/core/screen-actions.ts`: `DESCRIPTOR_ACTION_LABELS[AuditingConfig]` = `{enable:
  auditingTurnOnAction, disable: auditingTurnOffAction}`.
- `ui/src/app/shell/warning-dialog.ts` (+ `.spec.ts`, new):
  - `app-dialog` titled with the verb, with the consequence paragraph.
  - Proceed is `ocu-button-primary` in `dialogAction`, and Cancel is the dismissing action.
  - Initial focus Cancel. Escape, Cancel and the scrim emit `cancelled`.
- `ui/src/app/areas/security/auditing-config.store.ts`, `.page.ts`, `.page.spec.ts` (new):
  - On construction the page injects `ScreenActionHandler` and sets its store selection to
    `['SYSTEM']`.
  - One-shot reads: its own declared read and both list reads (`createScreenRead`).
  - It re-reads on a `ChangeBus` `auditing-configuration` event.
  - It renders a status line (`auditingStatusOn`/`Off`) and one button. When auditing is on, it
    is `auditingTurnOffAction` (secondary). When off, it is `auditingTurnOnAction` (primary).
    Both go through `ScreenActions.run`.
  - It renders `app-warning-dialog` from `pending()`.
  - It renders the cross-link `auditListLabel` → `logs/audit` (`withQuery` for `ns`).
  - It renders two sections headed by each list's label, linking to its route: a read-only table
    of the declared columns and its empty state.
  - Refusals come from the store (AD-39).
  - It exports `AUDITING_FOCUS_ENABLE`, a router-state key. When the key is present on arrival,
    the enable button takes focus after first render.
- `ui/src/app/shell/screen-outlet.ts`: import the page and add
  `'OcuPilot.Screen.Descriptor.AuditingConfig': AuditingConfigPage` to `DESCRIPTOR_PAGES`.
- `ui/src/app/shell/panel.ts`: in the not-marked slot, add the `ocu-panel-banner-link` anchor
  `auditingConfigurationLink` for every user. For `administrator`, add an `ocu-button-text`
  `auditingTurnOnAction` that navigates with `state: {[AUDITING_FOCUS_ENABLE]: true}`. Rewrite
  the `writesNotMarked` doc.
- `ui/src/app/core/strings.ts`: append the keys under Design Notes.
- `ui/src/app/core/screens.generated.ts`: regenerate with `screen-mirror.mjs`.
- `src/OcuPilot/Test/AuditingScreen.cls` (new, unarmed, no instance write):
  - Declarations: `AuditingConfig` is built with both actions and its read. The tool's
    `ScreenActionIds` are `enable,disable`, and `MovesMarking` is 1.
  - `ObserveMarking` through a new `OcuPilot.Test.MarkingPort` fixture (subclass of `AdminPort`
    answering canned reads), covering the on/on, off/on, on/off and fault arms.
  - Both lists read through `OcuPilot.Screen.Read` as `_SYSTEM`. The system list holds
    `%System/%Security/AuditChange`, and the user list holds `OcuPilot/…` and no `%System/`
    row.
- `src/OcuPilot/Test/AuditingUpdate.cls` (armed, append only):
  - `TestTheScreenActionTurnsAuditingOffAndOnAndMovesTheBanner` over HTTP as the test user.
  - Disable: 200 and the triple. `AuditEnabled()` is 0, `GET /agent/restraint` `writesMarked`
    is false, and no ledger row or `AgentWrite` audit row is added.
  - Enable: `writesMarked` true.
  - Restore auditing in its own frame.
- `src/OcuPilot/Test/ProhibitedRoute.cls` (contended; append after the last method):
  - As its existing short-of-pair auditing principal: the screen action is 403 naming
    `%Admin_Secure:USE`, and auditing is unchanged.
  - As its least-privileged auditing principal: the three reads answer 200. Neither leg toggles.
- `src/OcuPilot/Test/Descriptor.cls:357`, `ToolWrite.cls:498-513`, `SurfaceCoverage.cls` (three
  read-tool rows, header), `ReadTool.cls:93-94`, `ToolRoundTrip.cls`: roster and shape updates.
  Read the names from the instance.
- `ui/src/app/shell/panel.spec.ts:270-300`:
  - Invert the test: the slot carries the link for every user.
  - The action appears for an administrator only.
- `ui/src/app/shell/screen-action-handler.spec.ts`:
  - Disable opens `warning` with the consequence and sends nothing until `confirmPending`.
  - Enable sends at once.
  - The target is `SYSTEM`.
- `ui/browser/auditing-write.browser-spec.mjs:322-331`: assert the link is now present.
- `ui/browser/auditing-screen.browser-spec.mjs` (new):
  - `before` asserts auditing is on. `after` restores it through the port.
  - Open `security/auditing` and press "Turn auditing off". The dialog title, consequence and
    Proceed are checked (`ocu-button-primary`, not destructive).
  - Cancel sends nothing. Proceed: the panel banner appears with its link and action.
  - Click "Turn auditing on": the screen opens with that button focused. Press it, and the banner
    clears.
  - The cross-link and both sections render rows.

**Acceptance Criteria:**

- AC1: Given the Auditing configuration screen with auditing on, when the user chooses "Turn
  auditing off", then a dialog titled "Turn auditing off" states "Agent writes will no longer be
  marked in the audit database." Its Proceed is `button-primary`, never destructive, and nothing
  is sent until Proceed. *Pin:* `auditing-screen.browser-spec.mjs` dialog leg and
  `warning-dialog.spec.ts`.
- AC2: Given auditing goes off from the screen, when any panel renders, then the banner appears at
  once, and it clears the moment the screen turns auditing back on. *Pins:*
  `auditing-screen.browser-spec.mjs` banner legs, and `AuditingUpdate`'s screen-action test (CI).
- AC3: Given the banner shows, then every user gets the "Auditing configuration" link and an
  OcuPilot administrator also gets "Turn auditing on", which opens the screen with that control
  focused (epics 5.x `:3539`). *Pin:* `panel.spec.ts` and the browser leg.
- AC4: Given the screen renders, then it cross-links to the Audit database viewer. Beneath its
  form it embeds the system-event and user-event lists from their declared reads, each headed by a
  link to its own `list` route, which `ListPage` serves. *Pin:* `auditing-config.page.spec.ts` and
  `AuditingScreen`'s read legs.
- AC5: Given a screen action on auditing, then it emits no OcuPilot marker, writes no ledger row,
  and refuses a principal short of `%Admin_Secure:USE` with a named 403 before any read. *Pins:*
  `AuditingUpdate` (no marker), `ProhibitedRoute` (403).
- Integration AC (Rule 1): the panel consumes the `writesMarked` fact that the screen caller now
  records, observed in the browser banner leg against a real throwaway, never a mock.

**Open items on re-dispatch (2026-09-23, lead, orchestrator rulings):**

- [ ] Update the three Epic-8-modified roster tests the new screens redden -- `ui/tools/navigation.test.mjs`,
  `src/OcuPilot/Test/WireSecurityRead.cls`, `src/OcuPilot/Test/Wire.cls` -- adding only 7.4's own
  screens, off Epic 8's hunks (read `git show origin/OCU-1-epic8:<path>` first); list each under
  `footprint_extensions:`. Standing roster rule (2026-09-23): a shared test or roster file the other
  epic modified may take this story's own members under that discipline; its members, or a product
  source file it modified that is not on the contended list, stay a HALT.
- [ ] Replace the three borrowed strings the read's table and empty-state declaration names but the
  page never shows. Choose the option that matches what the page does, and record the choice under
  Design Notes: (1) a real state that text would describe -> HALT with the exact proposed copy for
  the lead to publish (tier-1); or (2) scope the registry rule in `Screen/Registry.cls` and its twin
  `ui/tools/screen-mirror.mjs` (both contended) so a form page whose read renders no table needs no
  table text, pinned by a test that fails when the scoping is removed.
- [ ] Finish the halted pass: the full ObjectScript sweep, the smoke check, the review layers,
  finalize; delete `_bmad-output/implementation-artifacts/7-4-wip.patch` and
  `7-4-wip-untracked.tgz` in the finalize commit.

## Spec Change Log

- 2026-09-23, lead spec gate: intent gap 1 ratified as recommended -- the AD-53 amendment is in the
  spine (MOVESMARKING; the screen's caller records the observed marking fact). The copy under Design
  Notes is published at `EXPERIENCE.md:409-413` and appended to `strings.ts` (keys as listed;
  `npm run test:tools` 1,327/0) -- consume, do not re-author. Intent gap 2: `Test/ToolWrite.cls` is
  contended for both epics (edit off Epic 8's hunks) and `screens.generated.ts` is regenerated;
  `screen-outlet.ts` and `Test/AuditingUpdate.cls` await the orchestrator.
- 2026-09-23, orchestrator ruling (implement dispatch): intent gap 2 approved. Before editing any
  file Epic 8 has touched, `git fetch origin` and read `git show origin/OCU-1-epic8:<path>`; list
  each under `footprint_extensions:`. `screen-outlet.ts`: append one import and one
  `DESCRIPTOR_PAGES` entry only, never the `form-page` doc comment. `Test/AuditingUpdate.cls`:
  append the method, never the code-count line. Any other file Epic 8 modified (`git diff --stat
  dd70e59 origin/OCU-1-epic8 -- <path>`) outside the lists above is an intent-gap HALT.

- 2026-09-23, lead: the implement HALT's three roster files are approved by the orchestrator
  (standing roster rule); the borrowed strings are ruled out; the WIP is committed as a patch and
  tarball for crash safety; `status` reset to `in-progress`.

## Review Triage Log

## Design Notes

**Governing ADs (Rule 6):**

- AD-53 (the seam, and the amendment below)
- AD-15 as amended (the drop is recorded, and a screen action emits no marker)
- AD-5 (a page issues another screen's read)
- AD-8 (the screen's own pairs, at `USE`)
- AD-10 (`Enabled` stays permitted)
- AD-13 (the singleton)
- AD-14, AD-19, AD-27 (reads through the port)
- AD-29, AD-36 (single-object `GET`, `source.query`)
- AD-39, AD-43 (no refresh)
- AD-44 (classic keys), AD-56 (`{action,id}` only)

**Intent gap 1: recommended AD-53 amendment** (Rule 20; blocks until ratified). Measured:
`RecordMarking` has two callers, `Installer.cls:3118` and `Confirm.cls:413`. `ScreenAction`
records nothing, so a screen-side disable would leave the banner hidden, which breaks AC2.

The banner cannot read the setting live. The restraint route is ungated. Reading
`Security.System` from it would need a third privileged routine application, which AD-8 and AD-9
do not carry (`Event.cls:291-298`).

Recommended text for AD-53's "What both callers share" paragraph:

> *A write that opens or closes the audit channel also records the observed marking fact the
> panel banner reads (AD-15). The agent's caller takes it from its marker's own answer. The
> screen's caller emits no marker, so after the write it re-reads, through the tool's port and
> with the caller's own privileges, the instance auditing flag and OcuPilot's marker event. The
> fact is OcuPilot's own state, not a marker, so AD-53's "emits no OcuPilot marker" is
> unchanged. A failed observation records nothing and never fails the write.*

Story 7.11's disable of OcuPilot's own events is the second tool that declares `MOVESMARKING`.

**Intent gap 2: footprint** (the lead's rule on files Epic 8 modified). Unavoidable edits:

- `ui/src/app/shell/screen-outlet.ts`: one import and one `DESCRIPTOR_PAGES` entry. Epic 8
  appends beside both, so the conflict is trivial.
- `src/OcuPilot/Test/ToolWrite.cls:513`: flip the unbuilt assertion. Epic 8's hunks are at `:133`
  and `:804`.
- `src/OcuPilot/Test/AuditingUpdate.cls`: append one method. Epic 8's single line is at `:505`.
  This is the only armed home, and it takes the class past about 500 lines.
- `ui/src/app/core/screens.generated.ts`: regenerated, on the 7.3 precedent.

Recommendation: approve all four as footprint extensions.

Contended edits (after `fetch` + `git show origin/OCU-1-epic8:<path>`, off its hunks):
`Kernel/Proposal/Operation.cls` (Epic 8 has not touched it), `Test/ProhibitedRoute.cls` (append),
`Test/SurfaceCoverage.cls`, `Test/ReadTool.cls`, `Test/ToolRoundTrip.cls`. `Kernel/Audit/Event.cls`
is outside every footprint, so it is a footprint extension.

**Pointer 3.** The handler serves any rostered descriptor whose store has a selection. A form has
no rows, so the page selects the singleton itself. The only shared extension is the `warning`
pending kind, which Suspend Task Manager and the web-service warning reuse later. The command bar
and the command box then offer both actions, as EXPERIENCE requires.

**AC4 split.** Delivered here: both lists as read-only declared screens with their own routes,
embedded read-only beneath the form. Story 7.11 owns the row actions (enable, disable, reset
counter, create, configure, delete) and the SQL wizard on these same descriptors.

**Consumes:** 5.10 (`AuditingUpdate`, the recorded fact, the banner); 7.1 (`ScreenAction`,
`Operation`, the handler); 6.11 (a page issuing another screen's read). **Consumed-by:** 7.11 (the
lists, `MOVESMARKING`, the `warning` dialog); 16.x Suspend Task Manager (the `warning` kind).

The side bar reads `auditingConfigurationLink`, "Auditing configuration", where EXPERIENCE's
table says "Auditing" (inference: the table names the entry, not its label).

**Copy for the lead to publish** (EXPERIENCE.md Fixed strings; `strings.ts` append):

| key | wording | row note |
| --- | --- | --- |
| `auditingTurnOffAction` | "Turn auditing off" | action label and warning title, Auditing configuration (7.4) |
| `actionProceed` | "Proceed" | the `button-primary` of a warning before a write (`:552`) |
| `auditingStatusOn` / `auditingStatusOff` | "Auditing is on." / "Auditing is off." | the form's state line |
| `auditSystemEventListLabel` / `auditUserEventListLabel` | "System events" / "User events" | list titles and section headings |
| `auditEventColumnTotal` / `…Written` / `…Lost` | "Total" / "Written" / "Lost" | event list columns |
| `auditSystemEventListEmpty` / `auditUserEventListEmpty` | "No system events." / "No user events." | empty states |

Reused: `proposalAuditWarning` (dialog body), `auditingTurnOnAction`, `auditingConfigurationLink`,
`auditListLabel`, `actionCancel`.

## Verification

Destructive checks run only on the throwaway `ocupilot-ci` (web 52776). Run one test class per
call and never re-submit. Auditing is restored after each check. Never stop, remove or recreate
any container.

**Targeted (loop):**

- `node ui/tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.AuditingScreen`,
  then, one call each: `Descriptor`, `ToolWrite`, `ReadTool`, `SurfaceCoverage`, `ToolRoundTrip`,
  `ProhibitedRoute` -- each green.
- `AuditingUpdate` refuses on the reused `ocupilot-ci`, which predates its arming variable. CI's
  fresh throwaway runs it. A refusal is not a pass, and its result is read from CI.
- `cd ui && npm run test:tools && npm run test:components` -- green.
- `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`,
  then `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci node
  --test --test-concurrency=1 browser/auditing-screen.browser-spec.mjs
  browser/auditing-write.browser-spec.mjs` -- green, and auditing reads 1 afterwards.
- `uv run scripts/check-objectscript.py` on the changed paths -- clean.
- Rule 19. Record one `mutation:` line per AC. Expected shapes:
  - AC1: map `disable` into `DESTRUCTIVE_ACTIONS` → the browser dialog leg goes red.
  - AC2: remove the `ScreenAction` marking hook, reload it on `ocupilot-ci` → the browser banner
    leg goes red.
  - AC3: drop the banner anchor → `panel.spec.ts` goes red.
  - AC4: swap the two `eventOwner` values → `AuditingScreen`'s read legs go red.
  - AC5: skip the pair check in `ScreenAction.Run` → the `ProhibitedRoute` leg goes red.
  - `ObserveMarking` ignoring the event flag → the `AuditingScreen` off-arm goes red.
  - `mutation: AC1 -- add 'disable' to screen-action-handler.ts DESTRUCTIVE_ACTIONS, rebuild, redeploy to ocupilot-ci -> auditing-screen.browser-spec.mjs red (no warning dialog opens; 30 s timeout). DEMONSTRATED 2026-09-23, reverted, tree fingerprint unchanged, both browser specs 4/4 green after redeploy`
  - `mutation: AC2 -- remove the MovesMarking/ObserveMarking hook from ScreenAction.Run, reload on ocupilot-ci (compiled Run checked free of MovesMarking) -> auditing-screen.browser-spec.mjs red waiting for the banner. DEMONSTRATED 2026-09-23, reverted and reloaded, auditing read 1 after`
  - `mutation: AC3 -- drop the banner anchor from panel.ts -> panel.spec.ts's two banner tests red. DEMONSTRATED 2026-09-23, reverted`
  - `mutation: AC4 -- swap the two eventOwner values, reload the two descriptors on ocupilot-ci -> AuditingScreen's two list-read tests red (run 7384). DEMONSTRATED 2026-09-23, reverted, tree fingerprint unchanged`
  - `mutation: AC5 -- Set tRefused = 0 after ScreenAction.Run's pair Gate, reload on ocupilot-ci -> ProhibitedRoute.TestAnAccountShortOfTheAuditingPairIsRefusedTheScreenAction red on code and failedPair (run 7386). DEMONSTRATED 2026-09-23, reverted, ProhibitedRoute 22/22 (run 7388)`
  - `mutation: ObserveMarking answers the auditing flag alone -> AuditingScreen.TestObservingMarkingNeedsAuditingAndTheMarkerEvent red on the on/off arm (run 7385). DEMONSTRATED 2026-09-23, reverted`
  - `mutation: drop ScreenAction.ObserveMarking's LogObserveFailure call -> AuditingScreen.TestAFailedObservationAfterTheScreensWriteRecordsNothingAndLogs red (run 7404). DEMONSTRATED 2026-09-23, reverted, AuditingScreen 6/6 (run 7405)`

**Once, before `dev_complete`:** run the full ObjectScript sweep on `ocupilot-ci`, per class and
one call at a time, with totals from the numeric-run-index probe. Then run `bash scripts/smoke.sh
--container ocupilot-ci --user _SYSTEM --password SYS` -- every check executed and passing. The
full browser suite is not run locally (Rule 29).

## Auto Run Result

Status: blocked
Blocking condition: intent gap -- three files Epic 8 has modified, on neither approved list, pin the
Security side-bar roster that `AuditingConfig` (position 6) and the two event lists (position 0)
change, so the full sweep and `test:tools` go red without them: `ui/tools/navigation.test.mjs`
(4 red: `:120`, `:260`, `:918`, `:945`), `src/OcuPilot/Test/WireSecurityRead.cls` (5 red: `:786`,
`:812`, `:840`, `:939`, `:958`; beside Epic 8's hunks at 781-785 and 807-811) and
`src/OcuPilot/Test/Wire.cls` (the SSL-list Security roster near `:577`). Recommended: approve all
three as footprint extensions (mechanical roster rows), then re-dispatch at `in-progress`.

footprint_extensions: as frontmatter, plus `WireOAuthRead.cls` and `ui/tools/toasts.test.mjs`
(neither touched by Epic 8).

Tiers run (implement, uncommitted in the worktree): `ocupilot-ci` per class -- AuditingScreen 6/6,
Descriptor 50/50, ToolWrite 23/23, ReadTool 27/27, SurfaceCoverage 4/4, ToolRoundTrip 2/2,
ProhibitedRoute 22/22, WireOAuthRead 6/6; AuditingUpdate refuses there (unarmed; 7/7 once in an
armed session, run 7382 -- CI's result governs). `test:components` 873/873; `test:tools`
1,323/1,327 (the four above); both browser specs 4/4 on a redeployed bundle; check-objectscript 0.
Not run: the full ObjectScript sweep, smoke, the review layers. Auditing reads 1 on `ocupilot-ci`.
