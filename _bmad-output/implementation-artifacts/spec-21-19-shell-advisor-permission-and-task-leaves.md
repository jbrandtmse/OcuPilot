---
title: 'Story 21.19: Shell, advisor, permission and task leaves'
type: 'feature'
created: '2026-11-15'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-21-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-21-20-os-management-and-log-leaves.md'
warnings: ['multiple-goals', 'oversized']
deferred:
  - summary: 'The Task Manager mail password reaches an audit row OcuPilot shows, whoever sets it'
    evidence: '%SYS.Task.Config.AuthPassSet stores Base64(password) through UpdateData, which writes OldValue/NewValue into a %System/%System/ConfigurationChange audit row (irissys/%SYS/Task/Config.cls:43-63,98-104); that event is enabled on slot A, and AuditPort declares no mask for it (VENDORSYSTEMSECRETS covers SMTP Password only). Base64 is not a mask. (inference until a set is measured on a throwaway)'
    location: 'src/OcuPilot/Port/AuditPort.cls:131'
    severity: 'high'
---

<intent-contract>

## Intent

**Problem:** Five classic-portal leaves have no OcuPilot surface: the Security Advisor (SS-39), resource export and import (PM-24), a task's output file (TM-17), the Task Manager email settings (TM-18) and Copy from on the web application create form (WA-15). Two ledger entries are also open: a create form's hand-off shows Saved before the editor opens (DW-2372), and a 200 answer of the wrong shape leaves a screen with no alert (DW-2471).

**Approach:** Each leaf joins the slice that owns its neighbors, through one descriptor and one port. Three leaves need no AD change and are planned in full: the Advisor (Security), the email settings (Tasks, on Story 21.3's `ConfigPort`) and Copy from (Web applications). Three parts need an AD record no owner answer covers, so the plan halts on them: PM-24 (an AD-51 named entry), TM-17 (an AD-21 case) and TM-18's password (an AD-35 mask declaration). Their batch is written so it can be built once the records exist.

## Boundaries & Constraints

**Always:** One descriptor and one port per screen (AD-5, AD-52); every port gates first (AD-29). Every write is one operation reached by two callers (AD-53): a confirmed proposal for the agent, a row action or Save for a person. Every fresh read is fingerprinted and every write is read back (AD-6, AD-58). New write keys join `Baseline.cls`. Reads are capped and report truncation (AD-36). Every user-facing string comes from EXPERIENCE.md through `strings.ts`. Shared registration files take add-only edits.

**Never:** No new AD, no AD amendment, and nothing in Batch 4 before its record is written. No caller path (AD-21). No secret is read, shown, stored in a proposal or logged (AD-35, AD-56). No edit to `InteropPort.cls` or `Timeline.cls`. No write to slot A's `ocupilot`; no test on `ocupilot-ci` during this plan.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Advisor read | any instance | one row per recommendation `{Type, Area, Element, Code, Recommendation, Ignored}`, equal to `SecurityAdvisorPane.GetRecommendations` at that read (173 rows on slot A) | none |
| Advisor ignore | row `Ignored` false | `SetIgnoreFlag(Type, Element, Code, 1, "")` runs with its output discarded; the row reads `Ignored` true; one AD-15 marker for the agent | already ignored: 409 `ADVISOR.IGNORED` |
| Advisor stop ignoring | row `Ignored` true | `SetIgnoreFlag(..., 0, "")`; the row reads `Ignored` false | not ignored: 409 `ADVISOR.NOTIGNORED` |
| Advisor gone | row absent after the read | mint 404, confirm closes changed | as every action write |
| Task mail read | any | 12 rows `{Name, Value, Kind, Accepts, Restart}` from `EmailGet`; `AuthPassword` is never a row | none |
| Task mail set | `Port` `587` | `EmailSet("Port","587")`; read-back `587` | `Port` not a whole number 1-65535 or empty: 409 `CONFIG.SETTING.VALUE` |
| Task mail subject | text with `#(BOGUS)#` | no vendor call | 409 `CONFIG.SETTING.SUBSTITUTION`, naming the vendor's fields |
| Copy from | create form, source `/csp/user` chosen | every field the create form carries is filled from the source's read except `WSGIAppLocation`; the name stays empty, and the form has no `Path` or `IsNameSpaceDefault`; Save is the existing create | the source's read refused: the form stays as it was, with the refusal shown |
| Missing pair | caller lacking a declared pair | no read, no vendor call | 403 `PORT.ACCESSDENIED` naming the pair |

</intent-contract>

## Code Map

- **Advisor, vendor:** `irissys/%CSP/UI/System/SecurityAdvisorPane.cls` -- `GetRecommendations(Output)` :382 fills `rec(Type,Element,"list",Code)=ignored`, plus `"enabled"`/`"public"`/`"resource"` per element; `SetIgnoreFlag(pType,pElement,pMessage,pFlag,id)` :720 writes through `$$SecurityAdvisorGlobalSet`/`Kill^%SYS.SECURITY` and then writes JavaScript (`&js<>`) to the current device. The 40 codes and their English sentences are `DrawBODY` :170-220; element `" "` is the general row of a type. The page checks `%Admin_Secure:USE` (:239). Measured on slot A: calling `$$SecurityAdvisorGlobalExists^%SYS.SECURITY` from user code fails #795 (protected routine), so only the pane's own methods may be called; `GetRecommendations` answers 173 rows over 6 types and 25 codes.
- **Advisor siblings:** `Port/BackgroundTaskPort.cls` (an `AdminPort` with one pseudo-endpoint: `ENDPOINT` :48, `CONTROLTYPES` :55, `PAIRS` :78, `Invoke` :111, `Gate` :152, `Row`/`Find` :225/:246, `Control` :295, `StateRefusal` :333). `Screen/Tool/BackgroundTaskCancel.cls` with `BackgroundTaskMint.cls` (composite id join). `Screen/Descriptor/BackgroundTaskList.cls` for a list with row actions. Security uses positions 1-13; 21.10 adds 14 and 15.
- **Output capture:** find the existing helper that runs a vendor call with its device output discarded (the harvest seam's renderer or `Port/Harvest/Handler.cls` is the first place to look). If none exists, the port opens a null device around the call and restores the device in its `Catch`.
- **Task mail, vendor:** `irissys/%SYS/Task/Config.cls` -- `EmailGet`/`EmailSet` :159/:175 check `%Admin_Manage:USE` and take 13 names; `AuthPassword` routes to `AuthPassSet` :98. `EmailSet` returns `$$$OK` even when `UpdateData` fails (:187), so only the read-back catches a failed set. `SubstitutionsValid` :113 and `SubstitutionFields` :107 list the allowed `#(...)#` fields. Slot A: every value empty; `%System/%System/ConfigurationChange` enabled.
- **Task mail siblings (Story 21.3/21.4):** `Port/ConfigPort.cls` -- `PAIRS` :39 (`%Admin_Manage:USE,%DB_IRISSYS:READ`), `ENDPOINTS` :54, the roster family (`ISQLROSTER` :95, `TSQLROSTER`/`TSQLSETTERS` :99/:103, `IsRoster` :214, `RosterOf` :546, `RosterValue` :630, `SendNode` :677, `SendTsql` :712, `Apply` :534). `Area/OsMgmt/ConfigSettingRules.cls`; `Api/ConfigError.cls`; `Screen/Tool/ConfigSettingSet.cls` (`SCREENACTIONS set`, `SCREENVALUES set=Value`, `SCREENEMPTY`, `READBACKFIELDS Value`) and `StartupSettingSet.cls`; `Screen/Descriptor/StartupSettingList.cls`; `ui/src/app/areas/os-management/config-settings.page.ts`; `ui/tools/screen-mirror.mjs:1226` (`configEndpoints()` parses `ENDPOINTS`). Tasks uses positions 1-5.
- **AD-44 classic pages (measured):** `%cspapp.sec.utilsyssecurityadvisor` and `%cspapp.mgr.utilsystaskmail` exist on slot A with no `RESOURCE` parameter; legacy `%cspapp` keys have precedent (`BackupTaskList.cls`). `%CSP.UI.Portal.Applications.Web` is `%Admin_Secure`; `%CSP.UI.Portal.Dialog.ExportResource` is `%Admin_Secure:USE`.
- **Copy from, vendor:** `irissys/%CSP/UI/Portal/Applications/Web.cls` -- `CopyApp` :823 reads `Security.Applications.Get(source)`; `PopulateFields(1,...)` :1017 skips `Name`, `Path` and `WSGIAppLocation` and sets `IsNameSpaceDefault` 0. `Security.WebAppPctAccess.CopyAll` runs only on a rename (:960), so Copy from copies no `%`-class access.
- **Copy from, OcuPilot:** `ui/src/app/areas/web-applications/create-form.store.ts` (`WebAppCreateForm` :168, `emptyBuffer` :139-147, `WRITABLE_FIELDS` :29-42, `open` :387-402, `body` :590-612) and `create-form.page.ts` (:421, `store.open()` :446). `Screen/Tool/WebAppCreate.cls` admits 11 fields (`PERMITTEDFIELDS` :70) plus application roles (:110-113); `Path` is derived (`DERIVEDPATH` :76) and `WSGIAppLocation` takes one directory name (`DerivedFields` :132-145, AD-21's second case); `IsNameSpaceDefault` is not a create field. One application's full read already exists: `GET /web-applications/form?name=` (`Api/Router.cls:99`, `Area/WebApp/FormRules.cls` `Application` :160-174, 404 `WEBAPPNAMEABSENT`), used by `web-app-editor.store.ts:624-626`. **Client sibling:** the user create form's Copy from (`ui/src/app/areas/permissions/user-create-form.store.ts` `COPY_FROM_FIELD` :28, the picker over the Users list :25, `setCopyFrom` :346-368; page :109-125, :541-544; string `userCopyFrom`, `core/strings.ts:2136`). User copy's server half (`UserCopy`, `UserCopyPort`) is not a sibling: a web-app copy only fills the form.
- **DW-2372:** `ui/src/app/shell/screen-outlet.ts:282-293` (`DESCRIPTOR_EDIT_PAGES`: UserForm :283, WebAppForm :284, RoleForm :285). Each create page's `onSave` sets the arrival Saved and navigates: web app `create-form.page.ts:714-729` (its own `role="status"` :390-392, `showSaved` :587-590, store `savedValue` `create-form.store.ts:566`), user `user-create-form.page.ts:569-582` (:283, :430), role `role-create-form.page.ts:473-486` (:205, :383). The editor's arrival Saved is `web-app-editor.store.ts:475-491`. `ui/src/app/app.routes.ts:113-133` (`rememberedPage`, `withPage`; its doc names this flash). No warm helper exists. A held-chunk test precedent is `ui/browser/about-help-links.browser-spec.mjs:120-145`; chunk helpers `lazy-screens.browser-spec.mjs:75-89`. `ui/browser/panel-spec.mjs:297-307` `saveAndSettle` accepts any form-bar Saved.
- **DW-2471:** `ui/src/app/core/screen-read.ts:230-234` turns an `ok` answer of the wrong shape into `{kind:'error', status}`, which `core/fault.ts:69-93` classifies `server-fault`, a banner kind (`isBannerFault` :113-115); `api.ts:425-434` reports no fault for the `ok` answer, and `core/read-state.ts:54-57,69-71` draws neither refusal nor empty. `core/refresh.ts:618` parks banner faults. The table draws refusals at `shell/data-table.ts:246-248`. Story 23.11's local fixes: `web-app-class-access-tab.ts:211-214` (remaps a 2xx fault to `rejected`) and `core/guardrails.ts:292-297`; `core/findings.ts:343` does the same. 28 product files call `createScreenRead(` (grep, excluding the module and the test harness), and `shell/list-page.ts:196` serves every list. Pins: `ui/tools/screen-read.test.mjs:261-266` (asserts `server-fault`), `ui/tools/read-state.test.mjs:50-57`, `web-app-class-access-tab.spec.ts:220-227`, `guardrails.page.spec.ts:233-240`.
- **Gated (Batch 4):** `Screen/Tool/TaskExport.cls`, `TaskImport.cls`, their mints, and `Port/TaskTransferPort.cls` (AD-51's Story 16.4 entry) are the siblings for PM-24; `irissys/Security/Resources.cls` `Export(FileName, .NumExported, Resources="*", PublicPermissions=-1, Type=-1)` :135 and `Import(FileName, .NumImported, Flags)` :172 (`Flags` bit 0 counts only). `Screen/Descriptor/TaskDetails.cls` shows no `OutputDirectory`/`OutputFilename` today. `Screen/Tool/AuthOptionsSmtpPassword.cls` (`SECRETBODY`, `CLEARABLESECRETS`) and `Port/AuditPort.cls:131-134` (`VENDORSYSTEMSECRETS`, `VENDORSYSTEMSOURCE`) are the siblings for the mail password.
- **Strings:** `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md`; "Copy from" exists (:398, the user create form). `ui/tools/strings.test.mjs` holds the literal cap.

## Tasks & Acceptance

**Execution.** Task 0 runs on `ocupilot-ci` once the runner frees it, and is recorded under Design Notes before any code. Each item is (inference) until measured:

- (a) A caller holding only `%Admin_Secure:USE` and `%DB_IRISSYS:READ` reads `GetRecommendations` in `%SYS`, and sets and clears an ignore flag through `SetIgnoreFlag` with its device output discarded; the flag survives a re-read. Any extra pair is recorded as the ignore tools' `WRITEPAIRS`; a pair beyond `%DB_IRISSYS:WRITE` is a HALT `intent gap`.
- (b) A `ConfigPort.PAIRS`-only caller reads every `EmailGet` name; `%DB_IRISSYS:WRITE` added is enough for `EmailSet`. Each non-secret set writes one `ConfigurationChange` row naming the old and new value.
- (c) For Batch 4 only, after its records: a `AuthPassSet` writes Base64 of the password into that row's `New value`.

### Batch 1: the Security Advisor (server and client; commit when its loop is green)

- `src/OcuPilot/Port/AdvisorPort.cls` -- new, on `BackgroundTaskPort`'s shape: an `AdminPort` with pseudo-endpoint `SecurityAdvisor`.
  - `PAIRS` `%Admin_Secure:USE,%DB_IRISSYS:READ`, gated first; `WRITEPAIRS` from Task 0 (a).
  - `LIST`: `GetRecommendations` in `%SYS` (AD-16), flattened to rows `{Type, Area, Element, Code, Recommendation, Ignored}` ordered by type then element then code, capped by `maxRows` (default 1000) with truncation reported. `Element` is the vendor's verbatim, `" "` for a type's general row. `Area` comes from the port's `ADVISORAREAS` roster (`Type=label`) and `Recommendation` from its `ADVISORTEXTS` roster (`Code=sentence`), both the ruled strings; an unknown type or code answers itself.
  - `ROW`: one row by `Type`, `Element`, `Code`; absent is 404.
  - `IGNORE` and `UNIGNORE`: refuse 409 when the row already holds the state, else `SetIgnoreFlag(Type, Element, Code, 1|0, "")` with output discarded (Code Map). The read-back is the next `ROW`.
  - Overridable seams `Recommendations(Output)` and `SetFlag(...)`, so tests never touch the instance's flags.
- `src/OcuPilot/Api/AdvisorError.cls` -- new, on `LockError`'s shape: `IGNORED`, `NOTIGNORED` and their reasons.
- `src/OcuPilot/Screen/Descriptor/SecurityAdvisorList.cls` -- new, on `BackgroundTaskList`'s shape. Route `security/advisor`, the position after 21.10's 15; entity `security-recommendation`; id composite `Type,Element,Code`; columns `Area`, `Element`, `Recommendation`, `Ignored`; `rowActions` `ignore`, `unignore`; `classicPage` `%cspapp.sec.utilsyssecurityadvisor`; pairs `AdvisorPort.PAIRS`; tool `security.advisor`.
- `src/OcuPilot/Screen/Tool/SecurityAdvisorIgnore.cls`, `SecurityAdvisorUnignore.cls` -- new, on `BackgroundTaskCancel`'s shape: `TOOLNAME` `security.advisor.ignore` / `.unignore`, `PORTCLASS AdvisorPort`, `READTYPE ROW`, `WRITETYPE IGNORE`/`UNIGNORE`, `SENDSBODY 0`, `DESTRUCTIVE 0`, `PRECONDITIONFIELD` and `FINGERPRINTSUBJECT` `Ignored`, `PRECONDITIONCODES` the two 409s. `SecurityAdvisorMint.cls` joins the three-part id as `BackgroundTaskMint` joins two: a subclass of it, or a shared helper if a subclass reads worse.
- Add-only rows: `Baseline.cls` both keys `true`; `Kernel/EntityType.cls` `security-recommendation`; `Prohibited.cls` the type covered with no predicate; `Screen/Titles.cls`, regenerated.
- Client: `core/screen-actions.ts` (`ignore` "Ignore", `unignore` "Stop ignoring"); `shell/screen-action-handler.ts` `SCREEN_ACTION_DESCRIPTORS`; `core/strings.ts`, `core/screens.generated.ts`. The generic list page draws it (inference: no page component).
- Tests: `Test/AdvisorRead.cls` (live-safe: rows equal the pane at that read, ordered and capped; a seam's general row and unknown code; gate refusal), `Test/AdvisorWrite.cls` (live: picks a row the read answers, both callers ignore and stop ignoring it, the pane's own `GetRecommendations` reads each state back, the flag is restored in `OnAfterOneTest`; seam legs for both 409s and the key `false`; one marker for the agent), `ui/browser/security-advisor.browser-spec.mjs` (rows after the answered signal; ignore then stop ignoring a seam-free row the spec restores), a `ui/tools` test that every `ADVISORAREAS` and `ADVISORTEXTS` string is an EXPERIENCE.md literal.

### Batch 2: the Task Manager email settings (server and client; commit when its loop is green)

- `src/OcuPilot/Port/ConfigPort.cls` -- `ENDPOINTS` adds `TaskMail`, a roster endpoint (`TASKMAILROSTER`): `Server`, `Sender`, `ReplyTo`, `TimeZone`, `AuthUser`, `SSLConfiguration` text; `Port` text judged as a port; `UseSTARTTLS` boolean; `SubjectSuccess`, `SubjectFailure` text; `MessageSuccess`, `MessageFailure` text up to 32000. Read through `EmailGet`, set through `EmailSet` (a `RosterValue`/`SendNode` branch beside TSQL's). `AuthPassword` is never in the roster. `Restart` false for all.
- `src/OcuPilot/Area/OsMgmt/ConfigSettingRules.cls` -- `TaskMail`: `Port` empty or 1-65535; subjects and messages pass `%SYS.Task.Config.SubstitutionsValid`, else 409 `CONFIG.SETTING.SUBSTITUTION` naming `SubstitutionFields()`.
- `src/OcuPilot/Api/ConfigError.cls` -- `SETTINGSUBSTITUTION` and its reason.
- `src/OcuPilot/Screen/Descriptor/TaskMailSettingList.cls` -- new, on `StartupSettingList`'s shape: route `tasks/email`, Tasks position 6, entity `task-mail-setting`, source `config`/`TaskMail`/`LIST`, row action `set`, `classicPage` `%cspapp.mgr.utilsystaskmail`, privileges `%Admin_Task:USE` plus `ConfigPort.PAIRS`, tool `tasks.mail`.
- `src/OcuPilot/Screen/Tool/TaskMailSettingSet.cls` -- new subclass of `ConfigSettingSet`: `TOOLNAME tasks.mail.set`, `ENDPOINTNAME TaskMail`, `CLASSICPAGES %cspapp.mgr.utilsystaskmail`.
- Add-only rows: `Baseline.cls` `tasks.mail.set` `true`; `EntityType.cls`, `Prohibited.cls` (covered, no predicate), `Titles.cls`.
- Client: the screen on `config-settings.page.ts` as Startup settings is; `strings.ts`, `screens.generated.ts`, the mirror.
- Tests: extend `Test/ConfigSettingRead.cls` or add `Test/TaskMailSettingRead.cls` if the class is near 500 lines (live-safe: rows equal `EmailGet`, no `AuthPassword`, gate refusals); `Test/TaskMailSettingRules.cls` (every refusal, no vendor write); `Test/TaskMailSettingWrite.cls` (armed: both callers set `Port` and a subject, read back, restore every value in `OnAfterOneTest`); `ui/browser/config-settings.browser-spec.mjs` gains a Task Manager email leg that sets and restores one value.

### Batch 3: Copy from, DW-2372 and DW-2471 (client; commit when its loop is green)

- `ui/src/app/areas/web-applications/create-form.store.ts` -- add `copyFrom` on `user-create-form.store.ts`'s `setCopyFrom` model: the picker lists the Web applications list's names; choosing one reads `GET /web-applications/form?name=<source>` and fills every `WRITABLE_FIELDS` member the answer's `application` holds, except `WSGIAppLocation` (and `Path` and `Name`, which the form does not carry), plus the source's application roles (its `MatchRoles` entries with an empty match part). Clearing the choice restores `emptyBuffer()`. A refused read leaves the buffer unchanged and shows the refusal as the editor's load does. Save is unchanged.
- `ui/src/app/areas/web-applications/create-form.page.ts` -- the Copy from select at the top of the form, labeled with the existing "Copy from".
- DW-2372: export `warmEditPage(descriptor)` from `ui/src/app/shell/screen-outlet.ts`, which calls `DESCRIPTOR_EDIT_PAGES[descriptor]()`. The web-app, user and role create pages await it before `navigateByUrl`, and their own Saved stays hidden while the hand-off runs, so the only Saved shown is the editor's arrival Saved. If `ui/tools/bundle-imports.mjs` or `build-output.test.mjs` refuses the page-to-outlet import, each page instead dynamically imports its own editor module (the same chunk), recorded in the spec.
- DW-2471: `ui/src/app/core/screen-read.ts:230-234` answers an `ok` answer it cannot read as `{kind:'rejected', status, code:null, path}`, so every shared-read screen draws its refusal and holds until Retry. The class-access tab's own remap (`web-app-class-access-tab.ts:211-214`) is removed as redundant; Guardrails and findings keep their own reads.
- Tests: `create-form.store.spec.ts` (copy fills and skips, a refused source read keeps the buffer, clearing restores); `ui/browser/web-applications-create.browser-spec.mjs` (Copy from a source the spec creates, Save, the editor shows the copied values; the spec deletes both apps); a held-chunk leg in it and in `users-create.browser-spec.mjs` and `roles-create.browser-spec.mjs` (the editor chunk is held: no Saved status shows; released: the editor's Saved shows); `ui/tools/screen-read.test.mjs:261-266` now asserts `rejected`; `web-app-class-access-tab.spec.ts`'s unreadable leg keeps passing through the shared read, its `mutation:` note moved to the shared read.

### Batch 4: moved to Story 21.21 at the spec gate (not built in this story)

- **PM-24**, on `TaskExport`/`TaskImport`'s shape: `permissions.resources.export` (all resources or the selected ones, to a `PathPort` root and name as an overwriting `file` whose overwrite is a constant) and `permissions.resources.import` (a `source` file or the screen's local text, through a temporary file OcuPilot names, previewed with `Flags` 1 and refused when the file no longer yields the reviewed resource names). Row/toolbar actions on `ResourceList`; `classicPage` `%CSP.UI.Portal.Dialog.ExportResource`. Import is destructive by name (it overwrites existing resources), so its key ships `false`.
- **TM-17**: Task details gains `OutputFile` and an Open output action that reads the task's stored output file, bounded and tail-first through `LogSourcePort`, only where the record allows it.
- **TM-18's password**: `tasks.mail.password`, a secret-only write on `AuthOptionsSmtpPassword`'s shape (AD-56 (i)), and `AuditPort`'s declaration for the `ConfigurationChange` row.

**Acceptance Criteria:**

- AC1 (SS-39). Given the Security advisor screen or `security.advisor`, when either reads, then both answer the same rows, equal to the vendor's recommendations at that read. When a person ignores a row, or confirms the agent's ignore, then the row reads Ignored on the next read and the classic Security Advisor shows it ignored; stopping restores it. The agent's write records one AD-15 marker and a `readBack`; the person's records none.
- AC2 (TM-18). Given the Task Manager email screen, when a person or the agent's confirmed `tasks.mail.set` sets `Port` or a subject, then `EmailGet` answers the new value and the screen re-fetches it; an invalid port or substitution field is refused before any vendor call; `AuthPassword` never appears in a read, a proposal or a ledger row.
- AC3 (WA-15). Given the web application create form, when a person chooses Copy from and an existing application, then every field the create form carries is filled from the source's read except the name and the Python app location, and Save creates the new application through the existing create, with no namespace-default flag and no `%`-class access copied.
- AC4 (DW-2372). Given the editor's page code held unloaded, when a person saves the web-app, user or role create form, then no Saved status shows until the editor has opened, and then the editor's own Saved shows.
- AC5 (DW-2471). Given a list screen whose read answers 200 with a body that is not a read's shape, when it renders, then it shows its refusal with Retry, not a blank table and no banner.
- AC6. Given the default baseline, when the agent proposes any new write, then it mints and confirms; with its key `false`, the governance gate refuses it.

## Spec Change Log

## Review Triage Log

## Design Notes

**Governing ADs:** AD-5, AD-6, AD-8, AD-10, AD-12/AD-39, AD-13, AD-14, AD-15, AD-16, AD-21, AD-29, AD-35, AD-36, AD-44, AD-51, AD-52, AD-53, AD-54, AD-55, AD-56, AD-58.

**Consumed-by / Consumes (Rules 1-2):**

- `AdvisorPort` is consumed by the Security advisor screen and `security.advisor`(`.ignore`/`.unignore`) (AC1); `ConfigPort`'s `TaskMail` by the Task Manager email screen and `tasks.mail`(`.set`) (AC2). No later story consumes them.
- Consumes: `ConfigPort`, `ConfigSettingRules`, `ConfigSettingSet` and `config-settings.page.ts` (21.3, 21.4); `BackgroundTaskPort`'s and `BackgroundTaskMint`'s shapes (16.5); the web-app create form and read (8.2).

**Extends (Rule 2/31):**

- `AdvisorPort` extends `BackgroundTaskPort`'s shape as a sibling `AdminPort` pseudo-endpoint, not an addition to `BackgroundTaskPort`, whose pairs are Operate's and whose rows are jobs.
- The ignore tools extend `BackgroundTaskCancel`'s; `SecurityAdvisorMint` extends `BackgroundTaskMint`'s join.
- The email settings extend `ConfigPort`'s roster family, `ConfigSettingRules`, `ConfigSettingSet` and its page rather than a new port.
- Copy from extends the create form with the edit form's existing read.

**Decided in-stage:**

- Ignoring is not destructive and is undone by Stop ignoring, so both advisor keys ship `true`; `SetIgnoreFlag` is called rather than the `%SYS.SECURITY` labels, which refuse user code (#795, measured).
- The advisor's sentences are the vendor's own English sentences for each code, held by the port so the screen and the agent read one text; the classic page's per-element links are not carried (named limit).
- The email settings live in Tasks on `ConfigPort` (its pairs are the vendor's `%Admin_Manage:USE`), not on `TaskPort`, which is an admin-API task port.
- Copy from copies no `%`-class access, as the classic page does on a create.
- The tree held another stage's uncommitted Story 21.12 files at this plan's start; this stage wrote only its spec.
- The epic context is reused as the runner instructed.

**Declined:** none. DW-2372 and DW-2471 are addressed in Batch 3 (AC4, AC5).

**DW-2471, decided in-stage:** option (a), map a success-status unreadable answer to `rejected` in the shared read. It is the shape Story 23.11 already applied twice locally, it reaches every shared-read screen in one place, and a reader outside `ReadState` sees it too; option (b) would fix only `ReadState` users and leave `refresh.ts` parking the read as a banner fault. Fix-risk stays high because 28 product files share the read; the shared-surface sweep below covers them.

**Copy from, decided in-stage:** it fills what the create form carries (11 fields and application roles); the other settings the classic page copies are set in the editor the create hands off to (named limit). It copies no matching roles, as the form sends none.

**Records Batch 4 needs (the halt; proposed text for the runner and owner):**

- **PM-24, AD-51 named entry:** "Story 21.19's case: `TaskTransferPort` (or a sibling `ResourceTransferPort`) builds `Security.Resources.Export`'s and `Import`'s file argument from the export and import tools' declared `root` and `path`, resolved through `PathPort` at the write, or from the screen's local text through a temporary file OcuPilot names and deletes; it answers the import's fresh read with the file's resource names (`Flags` 1) and refuses an import whose file no longer yields them." Plus an AD-21 consumer line on 16.4's and 21.15's model: the export an overwriting `file` whose overwrite is a constant, the import a `source`, local text a screen value.
- **TM-17, an AD-21 case:** AD-21's third case lets a task write only `<ManagerDirectory>` plus a single-segment `.txt` name; no case reads a file whose path a task definition stores, and the fifth case's precedent (a name derived from instance state) took its own record. Proposed: "A task's output file is read only when its stored `OutputDirectory` normalizes to `<ManagerDirectory>`, computed at call time, and its `OutputFilename` matches the third case's pattern; it is read through `LogSourcePort` under the task screens' pairs, bounded, and any other location is shown, never read."
- **TM-18's password, an AD-35 declaration:** "The sixth declaration: `%SYS.Task.Config.AuthPassSet` writes the Task Manager mail password, Base64-encoded, as the `New value` and `Old value` of its `%System/%System/ConfigurationChange` row for `Config.MailAuthPassword`, so the audit read masks both values for that row on both paths." This mask is needed whoever sets the password (frontmatter `deferred`).
- Recommended: the owner allows the three records (A), or Batch 4 moves to Story 21.21 with the owner-gated leaves (B). Either way Batches 1-3 can be built now.

**Strings, escalated for the spec gate's ruling** (proposed wording; nothing is used until ruled):

- Security advisor: title and side-bar entry "Security advisor"; columns "Area", "Item", "Recommendation", "Ignored"; values "Auditing", "Services", "Roles", "Users", "Web applications", "Privileged routine applications", "Client applications"; actions "Ignore", "Stop ignoring"; empty state "There are no recommendations."; prompt "Which of these recommendations matter most on this instance?".
- The 40 recommendation sentences: the vendor's English sentence for each code, verbatim from `SecurityAdvisorPane.cls:170-220`, with `$$$PUBLICUsername` written `_PUBLIC`.
- `ADVISOR.IGNORED`: "This recommendation is already ignored." `ADVISOR.NOTIGNORED`: "This recommendation is not ignored."
- Task Manager email: title and side-bar entry "Task Manager email"; prompt "Is task email set up to reach anyone?".
- `CONFIG.SETTING.SUBSTITUTION`: "Use only these fields between #( and )#: <fields>."
- Copy from reuses "Copy from" (EXPERIENCE.md:398) and adds one string, the select's empty choice: "None".

## Verification

Shared surfaces (each is in the `(loop)` set; the implement stage greps `ui/browser`, `ui/tools`, `ui/src` specs and `src/OcuPilot/Test` for the old shape):

- Security and Tasks rosters and pair-order counts: `Navigation` (two screens added: Security after 21.10's positions, Tasks 6), `WireSecurityRead`, `WireAreaAnyScreen`, `ui/tools/navigation.test.mjs`.
- `Descriptor` and `EntityType.Count`; `TeardownGuard`; the read-source count.
- `ReadTool`'s size, `ReadDescriptions`, `ToolWrite`'s counts, `StageTwoTools`, `GovernanceBaseline`.
- `Prohibited`, `ClassicPageGate`, `MappingDescriptor`, `SurfaceCoverage`, `ToolRoundTrip`, `PortGate`, `EndpointCoverage`.
- `LanguageServerWire` and its browser spec, unchanged and re-run.
- `screen-mirror` (`configEndpoints()`), `ci.test.mjs` (any new arming variable), the EXPERIENCE.md literal cap, which the 40 sentences may cross: raise it under its protocol and say so.
- The shared read's refusal shape (`screen-read.test.mjs`, `read-state.test.mjs`, every component spec that feeds a 2xx unreadable answer: grep `ui/src` for `status: 200` with an error or fault kind), the three create pages' Saved status (`saveAndSettle` callers that save a create form).

Every test added or changed passes on a fresh environment, in either order. Each pinning test records `mutation:` lines here:

- AC1: `IGNORE` skips `SetFlag`.
- AC2: drop the `Port` range rule.
- AC3: copy `Path` too.
- AC4: navigate before the warm resolves.
- AC5: restore the `server-fault` mapping at `screen-read.ts:230-234`.
- AC6: the key fallback.

**Commands.** ObjectScript test runs are one call each, never two in one message.

- `sh /private/tmp/claude-501/-Users-jbrandt-git-OcuPilot/4667058b-f052-49c9-b08a-221f7f41dfab/scratchpad/e21u/lead/reload.sh /Users/jbrandt/git/OcuPilot/.worktrees/epic-21 ocupilot-ci` (loop) -- expected: `LOADERRORS=0`, no compile error.
- `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.<Class>` (loop), once for each of: `AdvisorRead`, `AdvisorWrite`, `ConfigSettingRead` (or `TaskMailSettingRead`), `TaskMailSettingRules`, `TaskMailSettingWrite`, `ConfigSettingRules`, `ConfigSettingWrite`, `SqlSettingRead`, `WebAppCreate`, `WebAppWire`, and every shared-surface class above -- expected: all green.
- `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/` (loop) -- expected: within the 2500/4000 kB budgets.
- `cd ui && OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci node --test --test-concurrency=1 browser/<file>.browser-spec.mjs` (loop), one call per file: `security-advisor`, `config-settings`, `web-applications-create`, `users-create`, `roles-create`, `web-applications-class-access`, `language-servers` -- expected: green.
- `cd ui && npm run test:tools` and `cd ui && npm run test:components` (loop) -- expected: green.
- `uv run scripts/check-objectscript.py`, `uv run scripts/test_check_objectscript.py`, `bash scripts/lint-docs.sh` (loop) -- expected: clean.
- The full ObjectScript sweep over `src/OcuPilot/Test` (once, before `dev_complete`), one class per call or batches sized from `ui/tools/ci-timings.json` to about 8 minutes -- expected: green. The full browser suite is left to CI (Rule 29).

**Runner ruling at the spec gate (2026-11-16):** Batch 4 (PM-24, TM-17, TM-18's password) moves to Story 21.21, which waits on the owner for the three records; this story builds Batches 1 to 3. The mail-password audit exposure is ledgered as DW-2625 (decision-pending, owner item requested). The escalated strings and named limits are kept (veto U-69).

## Auto Run Result

Status: ready-for-dev
Blocking condition: none
