---
title: 'Story 21.19: Shell, advisor, permission and task leaves'
type: 'feature'
created: '2026-11-15'
status: 'done'
baseline_revision: 'f6e5cc741b5cd175f4ea5311e442a64015a6734b'
review_loop_iteration: 0
followup_review_recommended: true
deferred:
  - summary: >-
      The Task Manager email settings' UseSTARTTLS and message values have no real set-and-read-back leg against the vendor.
    evidence: |-
      TaskMailSettingWrite sets Port, SubjectSuccess and SubjectFailure against the vendor; UseSTARTTLS and the two messages are exercised at the rules level and through a stubbed page spec only, so a vendor that stores UseSTARTTLS other than as EmailGet echoes it would read back as differs. (inference until measured on a throwaway)
    location: >-
      src/OcuPilot/Test/TaskMailSettingWrite.cls
    severity: medium (unverified)
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-21-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-21-20-os-management-and-log-leaves.md'
warnings: ['multiple-goals', 'oversized']
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
- (c) Moved to Story 21.36 with TM-18's password.

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

### Batch 4: PM-24 (TM-17 and TM-18's password moved to Story 21.36)

- **PM-24**, on `TaskExport`/`TaskImport`'s shape: `permissions.resources.export` (all resources or the selected ones, to a `PathPort` root and name as an overwriting `file` whose overwrite is a constant) and `permissions.resources.import` (a `source` file or the screen's local text, through a temporary file OcuPilot names, previewed with `Flags` 1 and refused when the file no longer yields the reviewed resource names). Row/toolbar actions on `ResourceList`; `classicPage` `%CSP.UI.Portal.Dialog.ExportResource`. Import is destructive by name (it overwrites existing resources), so its key ships `false`.
- **TM-17** (Task details `OutputFile` and an Open output action) and **TM-18's password** (`tasks.mail.password`): moved to Story 21.36; nothing is built for either here.

**Acceptance Criteria:**

- AC1 (SS-39). Given the Security advisor screen or `security.advisor`, when either reads, then both answer the same rows, equal to the vendor's recommendations at that read. When a person ignores a row, or confirms the agent's ignore, then the row reads Ignored on the next read and the classic Security Advisor shows it ignored; stopping restores it. The agent's write records one AD-15 marker and a `readBack`; the person's records none.
- AC2 (TM-18). Given the Task Manager email screen, when a person or the agent's confirmed `tasks.mail.set` sets `Port` or a subject, then `EmailGet` answers the new value and the screen re-fetches it; an invalid port or substitution field is refused before any vendor call; `AuthPassword` never appears in a read, a proposal or a ledger row.
- AC3 (WA-15). Given the web application create form, when a person chooses Copy from and an existing application, then every field the create form carries is filled from the source's read except the name and the Python app location, and Save creates the new application through the existing create, with no namespace-default flag and no `%`-class access copied.
- AC4 (DW-2372). Given the editor's page code held unloaded, when a person saves the web-app, user or role create form, then no Saved status shows until the editor has opened, and then the editor's own Saved shows.
- AC5 (DW-2471). Given a list screen whose read answers 200 with a body that is not a read's shape, when it renders, then it shows its refusal with Retry, not a blank table and no banner.
- AC6. Given the default baseline, when the agent proposes any new write, then it mints and confirms; with its key `false`, the governance gate refuses it.

### Review Findings

Code review 2026-11-20 (four layers, full-opus; 42 rows, 34 entries). Measured on `ocupilot-ci`; every roster class green before and after the patches.

- [x] [Review][Patch] The advisor shows the vendor's second `_PUBLIC` roles line as its raw code `PUBLICRolesList1` and never names the roles (medium) [src/OcuPilot/Port/AdvisorPort.cls `Listed`, `PublicRoles`]
- [x] [Review][Patch] The port's own `RESOURCEFILE.CHANGED` refusal was never driven (medium) [src/OcuPilot/Test/ResourceTransferRead.cls `TestAnImportIsRefusedWhenItsFileIsNotTheOneReviewed`]
- [x] [Review][Patch] The kernel's route of a resource import to `ResourceImport` was unpinned; the port's own check hid it (medium) [src/OcuPilot/Test/ResourceTransferWrite.cls]
- [x] [Review][Patch] An import's server file outside the allowed directories had no refusal test (medium) [src/OcuPilot/Test/ResourceTransferRead.cls]
- [x] [Review][Patch] `UseSTARTTLS` and the two messages had no set and read-back against the vendor (DW-2788; medium) [src/OcuPilot/Test/TaskMailSettingWrite.cls `TestTheStartTlsFlagAndTheMessagesRoundTripThroughTheVendor`]
- [x] [Review][Patch] The mail write's screen leg set a fixed `587` and asserted an audit row the vendor skips when the port already reads 587 (medium, Rule 19) [src/OcuPilot/Test/TaskMailSettingWrite.cls]
- [x] [Review][Patch] A Save pressed again during the editor hand-off posted the create twice [ui/src/app/areas/web-applications/create-form.page.ts, user-create-form.page.ts, role-create-form.page.ts `onSave`]
- [x] [Review][Patch] The advisor's changed-after-mint leg asserted only "not ok" [src/OcuPilot/Test/AdvisorWrite.cls]
- [x] [Review][Patch] `warmEditPage`'s unknown-descriptor test named a mutation that cannot redden it [ui/src/app/shell/screen-outlet.spec.ts]
- [x] [Review][Patch] The 2,000-resource bound was pinned above only [src/OcuPilot/Test/ResourceTransferRead.cls]
- [x] [Review][Patch] The CHANGED sentence's doc and the import header claimed the port compares the replaced count; `REPLACESPARAM` was never read [src/OcuPilot/Api/ResourceFileError.cls, ResourceTransferPort.cls, Screen/Tool/ResourceImport.cls]
- [x] [Review][Patch] The ignore tools' `type` enum repeated `ADVISORAREAS` [src/OcuPilot/Screen/Tool/SecurityAdvisorIgnore.cls]
- [x] [Review][Patch] PM-24's tests cited AC1-AC4, which are other features' criteria; the export's root refusal asserted only its status [src/OcuPilot/Test/ResourceTransferRead.cls, ResourceTransferWrite.cls]
- [x] [Review][Defer] A resource import that opens an administrative resource is not named as a privilege grant on its card [src/OcuPilot/Kernel/Proposal/Prohibited.cls `GrantsPrivilegeByEffect`] — deferred: DW-2793 escalated (contended file)
- [x] [Review][Defer] The Resources list's transfer glue is the eighth copy of the transfer-dialog glue [ui/src/app/areas/permissions/resource-list.page.ts] — deferred: DW-2794 routed burndown; the port's copy of LocalePort's file helpers is an occurrence on DW-2763
- [x] [Review][Defer] Closed at emission: DW-2795 (`tasks.mail.set` stricter than measured), DW-2796 (`ReadMail` public, contended file), DW-2797 (person's import has no typed confirm, by design), DW-2798 (failed export over an existing file), DW-2799 (digest-only read-back, as LocaleImport), DW-2800 and DW-2801 (theoretical)

**Strings (PM-24, orchestrator ruling).** All ten pass EXPERIENCE.md's plain-words, sentence-case and no-internal-id rules and are kept as written: the two refusals match the term-list and locale precedents, and the two lines an applied transfer leaves stay count-neutral ("Resources imported: <count>.", "Resources exported to <path>: <count>."), since the sentence form reads "Imported 1 resources." for the single-resource export the browser spec drives. ClassicPageGate's 158 `OWNPAIRS` names equal the instance's registry roster (run 1168).

**Rejected:** a >3,000,000-character text is "more than 2,000 resources" (`false`: each entry is bounded by the vendor's MAXLENs, so no real export of 2,000 or fewer exceeds the cap); export of several selected resources (`false`: the list is single-select); PM-24 has no AC (its fix edits the spec; the orchestrator ruled it into the story); Copy from on a 200 of the wrong shape, an unknown transport fault in the transfer dialog, the Copy from cap of 1,000 (low, unlikely, matched by siblings); AC5 has no browser leg (Rule 3 is met by the story's browser specs, and the shared read runs in real components); the local-import browser refusal and the agent's export-all (pinned by the ObjectScript legs).

## Spec Change Log

- 2026-11-20, orchestrator rulings on the implement halt: (1) PM-24's ten strings are accepted under the orchestrator's grant (U-118 precedent), style-checked at review, and listed verbatim in a veto item; EXPERIENCE.md stays add-only. (2) TM-17 (a task's output file) and TM-18's mail password move to Story 21.36 (split, Rule 5; owner answer U-70 carries); this story closes with Batches 1 to 3 and PM-24, and Batch 4's TM-17 and mail-password bullets and their acceptance clauses are out of scope here. The AD-35 audit mask for the mail password's ConfigurationChange row is already in feature (Story 21.24, `b706fb831`, `AuditPort.VENDORCONFIGSECRETS`, pinned by `OcuPilot.Test.TaskMailAuditMask`).

## Review Triage Log

### 2026-11-19 -- Review pass

- verdicts: 22 findings -- high 0, medium 2, low 13, false 6, maybe-false 1
- findings:
  - `[low]` `[patch]` warmEditPage's swallowed chunk failure and unknown-descriptor return had no test -- `screen-outlet.spec.ts` gains two cases (loader rejects, unknown descriptor), mutation recorded.
  - `[low]` `[patch]` advisor read-source grammar arm had no negative case -- `AdvisorRead.TestAnAdvisorReadSourceIsRefusedWhenItDeclaresAnythingButTheWholeList` added, mutation recorded.
  - `[medium]` `[patch]` advisor `Execute` never driven with a cap, so AD-36's truncation report was unpinned -- `AdvisorRead.TestTheScreenReadReportsACutAtItsCap` added, mutation recorded.
  - `[low]` `[reject]` recommendation-code roster checked against the vendor only where `irissys/` exists -- a wrong unemitted code shows its raw code as its sentence; the fix is a new reader of vendor source text.
  - `[low]` `[patch]` import consequence checked by source text only -- `proposal-view.test.mjs` now executes `consequenceSentence`, mutation recorded.
  - `[medium]` `[patch]` agent mint of an unlisted recommendation and a confirm after the flag changed were untested (matrix row "Advisor gone") -- `AdvisorWrite.TestTheAgentsProposalIsRefusedWhenTheRowChangedOrIsGone` added, mutation recorded.
  - `[maybe-false]` `[defer]` `UseSTARTTLS` and message values have no vendor round trip -- in the frontmatter `deferred:` list; a throwaway set and read of each settles it.
  - `[low]` `[reject]` ACs lack a `mutation:` line for secondary clauses -- Rule 19 asks one per AC and each AC has one.
  - `[low]` `[reject]` `TaskMailSettingRead`'s Value check is vacuous on an all-empty instance -- the armed write class and the browser spec pin Value.
  - `[low]` `[reject]` the refused-Save specs hold equally if no POST is made -- the accepted-Save legs in the same specs reach the POST.
  - `[false]` `[reject]` zero agent markers could be an auditing-off reading -- the agent leg in the same class asserts one, so the pair holds.
  - `[low]` `[reject]` `saveWithChunksHeld` waits a fixed 600 ms before asserting absence -- an absence check has no signal to wait for, and the released leg asserts the arrival.
  - `[false]` `[reject]` some tests are not self-contained -- each states what it needs and fails loudly without it.
  - `[low]` `[patch]` browser spec's sentence key for `UserNoNamespace` -- mapped to `UserNoDefault` as the string test does.
  - `[low]` `[patch]` a dropped space in `READ_SOURCE_PORTS =[` -- restored.
  - `[low]` `[reject]` `CONFIG.SETTING.VALUE` and the substitution code answer 400 where the matrix says 409 -- the shared code already answered 400 in Story 21.3, and the tests pin its code and slug.
  - `[false]` `[reject]` advisor pairs include `%DB_IRISSYS:WRITE` -- measured in Task 0 and decided in-stage; stricter than the classic page.
  - `[false]` `[reject]` Copy from keeps a typed name -- decided in-stage; the matrix's empty name holds for a form nothing was typed into.
  - `[low]` `[reject]` the Copy from picker's list read is capped at 1000 without a notice -- an instance with more web applications than that is not a case any measured instance reaches.
  - `[low]` `[reject]` the mail descriptor carries `ReadOnly` beyond the matrix's five members -- it is the config roster family's own field.
  - `[false]` `[reject]` the matrix's 173 rows were not observed -- the test compares to the pane at run time, and 173 was slot A's count, which the throwaway need not equal.
  - `[false]` `[reject]` the substitution check calls the vendor -- the matrix's "no vendor call" means no `EmailSet`, which the tests record.

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
- Batch 3: `warmEditPage` is exported from `screen-outlet.ts` and imported by the three create pages; `build-output.test.mjs` and the lazy-load tooling accepted it (initial bundle 2.18 MB). It resolves on a missing descriptor or a failed chunk, and the page's `handingOff` keeps its own Saved hidden for the whole hand-off.
- Batch 3, Copy from: the picker's empty choice reuses "None" through `STRINGS.sslVerifyPeerNone` (`strings.test.mjs` holds every value unique), so no string is added; the form fills the type its source's fields describe (dispatch class: REST, application file: Python) and the source's methods the instance offers, keeps a typed name through a choice or its clearing, and a refused read returns the select to the source the form holds.

**Batch 4 state:**

- PM-24 is built and verified on `ocupilot-ci`: `Port/ResourceTransferPort.cls`, `Api/ResourceFileError.cls`, `Screen/Tool/ResourceExport.cls`, `ResourceExportMint.cls`, `ResourceImport.cls`; `ResourceList.cls` row actions `export`, `export-all`, `import`, `import-local`; the add-only rows (`Baseline.cls` export `true` and import `false`, `AdminPort` `ResourceTransfer/EXPORT` and `/IMPORT`, `Error.cls`, `Prohibited.cls`, `strings.ts`, `proposal-view.ts`); client `resource-list.page.ts`, `explorer-export-dialog.ts`; tests `Test/ResourceTransferFixture`, `ResourceTransferRead`, `ResourceTransferWrite`, `ui/tools/resource-transfer.test.mjs`, `resource-transfer.spec.ts`, `ui/browser/resources-transfer.browser-spec.mjs`.
- PM-24 pairs, measured on `ocupilot-ci` (2026-11-20, a throwaway user whose role held `%Admin_Secure:USE` and `%DB_IRISSYS:READ` only, in a jobbed process after `$SYSTEM.Security.Login`): `Security.Resources` `Export` of every resource, `Import` with `Flags` 1 and with `Flags` 0 all succeed in `%SYS` (185 resources exported; the one resource imported and then held). `%DB_IRISSYS:WRITE` is not needed, so `ResourceTransferPort.PAIRS` stays `%Admin_Secure:USE,%DB_IRISSYS:READ` and no tool declares `WRITEPAIRS`.
- TM-17 and TM-18's password move to Story 21.36 (Spec Change Log): `TaskDetails.cls` carries no `OutputFile` and no Open output action, and no `tasks.mail.password` tool exists.

**Task 0, measured on `ocupilot-ci` (2026-11-19, a throwaway user whose role held exactly the listed pairs, run in a jobbed process after `$SYSTEM.Security.Login`):**

- (a) `%Admin_Secure:USE` + `%DB_IRISSYS:READ` is not enough: `GetRecommendations` raises `<PROTECT>` at `$ZU(69,64)` (`GetServiceRecommendations+14`), and adding `%Admin_Manage:USE` does not help. With `%DB_IRISSYS:WRITE` added it reads (184 rows on `ocupilot-ci`), `SetIgnoreFlag(...,1,"")` and `(...,0,"")` run with the null device current (`Open <null>::1`; `Open <null>:1` fails with `$Test` 0), and the flag reads back `1` then empty. No pair beyond `%DB_IRISSYS:WRITE` is needed, so there is no halt. **Decided:** `AdvisorPort.PAIRS` is `%Admin_Secure:USE,%DB_IRISSYS:READ,%DB_IRISSYS:WRITE` for the read and both writes, so no tool declares `WRITEPAIRS`; the screen's privilege set carries the same three pairs. This is stricter than the classic page's `%Admin_Secure` alone, never looser.
- (b) `%Admin_Manage:USE` + `%DB_IRISSYS:READ` (ConfigPort's `PAIRS`) reads all 12 non-secret `EmailGet` names, and `EmailSet("Port", ...)` succeeds with those pairs alone: no `WRITEPAIRS` for `tasks.mail.set`. Each set writes one `%System/%System/ConfigurationChange` row, `Modify Task Config.MailPort`, so a set and its restore wrote two.
- (c) Not re-measured: Story 21.24 recorded it in the spine (AD-35, `Config.MailAuthPassword`, Base64 in `Old value` and `New value`, measured 2026-11-16).

**Declined:** none. DW-2372 and DW-2471 are addressed in Batch 3 (AC4, AC5).

**DW-2471, decided in-stage:** option (a), map a success-status unreadable answer to `rejected` in the shared read. It is the shape Story 23.11 already applied twice locally, it reaches every shared-read screen in one place, and a reader outside `ReadState` sees it too; option (b) would fix only `ReadState` users and leave `refresh.ts` parking the read as a banner fault. Fix-risk stays high because 28 product files share the read; the shared-surface sweep below covers them.

**Copy from, decided in-stage:** it fills what the create form carries (11 fields and application roles); the other settings the classic page copies are set in the editor the create hands off to (named limit). It copies no matching roles, as the form sends none.

**Records Batch 4 needs (the halt; proposed text for the runner and owner):**

- **PM-24, AD-51 named entry:** "Story 21.19's case: `TaskTransferPort` (or a sibling `ResourceTransferPort`) builds `Security.Resources.Export`'s and `Import`'s file argument from the export and import tools' declared `root` and `path`, resolved through `PathPort` at the write, or from the screen's local text through a temporary file OcuPilot names and deletes; it answers the import's fresh read with the file's resource names (`Flags` 1) and refuses an import whose file no longer yields them." Plus an AD-21 consumer line on 16.4's and 21.15's model: the export an overwriting `file` whose overwrite is a constant, the import a `source`, local text a screen value.
- TM-17's AD-21 case and TM-18's password record (the AD-35 mask for the `ConfigurationChange` row, already in `AuditPort.VENDORCONFIGSECRETS` from Story 21.24) belong to Story 21.36.

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

- AC1: `IGNORE` skips `SetFlag`. mutation: `AdvisorPort.Control` sets `tSC = $$$OK` in place of the `SetFlag` call -> `AdvisorWrite` 4 of 4 red (person, agent, seam, key legs; run 904), reverted and reloaded, 180 rows / 0 ignored as before.
- AC1 (words): `ui/tools/advisor-strings.test.mjs`. mutation: `AuditingON=Auditing is enabled` respelled `Auditing is turned on` in `AdvisorPort.cls`'s `ADVISORTEXTS` -> 2 of 5 red (the EXPERIENCE.md literal and string-source legs), file restored byte-identical (shasum equal; never loaded, so no reload).
- AC1 (browser): `ui/browser/security-advisor.browser-spec.mjs`. mutation: `screen-action-handler.ts`'s send maps `ignore` to `unignore` -> AC2 red (the Ignored cell never changes, the instance reads the row not ignored), reverted (shasum equal), rebuilt and redeployed, 2 of 2 green; the ignored count is 0 before and after.
- AC2: drop the `Port` range rule. mutation: `ConfigSettingRules.TaskMailCode` loses its `MAXPORT` comparison -> `TaskMailSettingRules` 2 of 5 red (the 65536 and 99999 rows with a vendor call recorded, and the mint; run 969), reverted (shasum equal) and reloaded, 5 of 5 green. Also: `ConfigPort.CollectRoster` ignores `ReadMail`'s status -> `TaskMailSettingRead` 1 of 7 red (a failed read is a fault, run 974); `SendNode` sends no `EmailSet` -> `TaskMailSettingWrite` 2 of 4 red (read-back `differs`, run 975); the page's `multiline` binding removed -> the spec's message leg red.
- AC3: copy `Path` too. mutation: `fill` in `create-form.store.ts` also sets `next['Path'] = textAt(source, 'Path')` -> `create-form.store.spec.ts` 1 of 16 red (`value('Path')` reads `/probe/path/`), reverted (shasum equal).
- AC4: navigate before the warm resolves. mutation: `void warmEditPage(...)` in place of the `await` in the web application create page -> `create-form.page.spec.ts` 1 of 5 red (navigation while the loader is held), reverted (shasum equal). Browser: the `handingOff` check dropped from `showSaved` on all three create pages, rebuilt and redeployed -> the held-chunk leg red in `web-applications-create`, `users-create` and `roles-create` (a `Saved` status shows while the chunk is held), reverted (shasum equal), rebuilt and redeployed, all green.
- AC5: restore the `server-fault` mapping at `screen-read.ts`. mutation: the unreadable `ok` answer mapped to `server-fault` -> `screen-read.test.mjs` 1 of 15, `web-app-class-access-tab.spec.ts` 1 of 23 (the unreadable leg, which now passes through the shared read) and `list-page.spec.ts` 1 of 38 red, reverted (shasum equal).
- AC6 (tasks.mail.set): the key fallback. mutation: the `tasks.mail.set` line removed from `Baseline.cls` -> `TaskMailSettingRead` 1 of 7 red (the baseline leg and the mint; run 971), reverted (shasum equal) and reloaded, 7 of 7 green.
- AC6: the key fallback. mutation: the `security.advisor.unignore` line removed from `Baseline.cls` (an absent key reads disabled) -> `AdvisorWrite` 2 of 4 red (the agent's mint and the baseline leg; run 905), reverted and reloaded.
- AC1 (cap): mutation: the advisor branch of `Read.Execute` asks the port for `tMax` rows in place of `tMax + 1` -> `AdvisorRead` 1 of 8 red (the cut is never reported; run 1156), reverted and reloaded.
- AC1 (grammar): mutation: `Registry.ReadProblem`'s advisor arm drops its `type` check -> `AdvisorRead` 1 of 8 red (run 1158), reverted and reloaded.
- AC1 (agent, row gone): mutation: `AdvisorPort.Find` answers an unlisted recommendation as found -> `AdvisorWrite.TestTheAgentsProposalIsRefusedWhenTheRowChangedOrIsGone` red with two others (run 1162), reverted and reloaded. The changed-after-mint leg now asserts `409 PROPOSAL.TARGETCHANGED`. mutation: `SecurityAdvisorIgnore.FINGERPRINTSUBJECT` set to `Code` -> that test red with three others (run 1224), reverted, 5 of 5 green (run 1225).
- AC1 (`_PUBLIC` roles line): mutation: `Listed` skips `PublicRoles` -> `AdvisorRead.TestThePublicRolesLineReadsTheRolesPublicHolds` 1 of 9 red (run 1222), reverted and reloaded.
- AC2 (`UseSTARTTLS` and messages, DW-2788): mutation: `ConfigPort.SendNode` sends no `EmailSet` -> `TaskMailSettingWrite.TestTheStartTlsFlagAndTheMessagesRoundTripThroughTheVendor` red with two others (run 1232), reverted (diff empty), 5 of 5 green (run 1233).
- AC4 (second Save during the hand-off): mutation: the `handingOff()` check dropped from the web application create page's `onSave` guard -> `create-form.page.spec.ts` 1 of 6 red (two creates sent), reverted.
- AC4 (hand-off tolerance): mutation: the `try`/`catch` removed from `warmEditPage` -> `screen-outlet.spec.ts` 1 of 33 red, reverted (the file's diff from the baseline read as before). The unknown-descriptor case reddens only with the `Object.hasOwn` guard and the `try`/`catch` both removed (2 of 33 red at review), reverted.
- PM-24 (consequence card): mutation: the `CONSEQUENCE_RESOURCEFILEIMPORT` branch dropped from `consequenceSentence` -> `proposal-view.test.mjs` 1 red, restored.
- PM-24 (import writes): mutation: `ResourceTransferPort.SendImport` passing `Flags` 1 -> `ResourceTransferWrite` 1 of 2 red (the screen's and the agent's imports; run 1021), reverted (shasum equal) and reloaded.
- PM-24 (review): mutation: `Review` adding 0 in place of 1 for a resource the instance holds -> `ResourceTransferRead` 1 of 7 red (the replaced count; run 1022), reverted (shasum equal).
- PM-24 (export directory): mutation: `ExportFile` with its directory check made unreachable -> `ResourceTransferRead` 1 of 7 red (a name whose directory is absent; run 1023), reverted (shasum equal).
- PM-24 (gate): mutation: `Invoke` with its `Gate` check made unreachable -> `ResourceTransferRead` 1 of 7 red (the denial test; run 1024), reverted (shasum equal).
- PM-24 (own resources): mutation: `Prohibited.ImportedResources` stopping after the first entry -> `ResourceTransferRead` 1 of 7 red (every second-entry row and the port's refusal; run 1025), reverted (shasum equal) and reloaded.
- PM-24 (changed since review, import outside the allowed directories): mutations applied together, each in its own method: `Import` without its reviewed-values comparison, and `ImportText` reading the server file without `Locate` -> `ResourceTransferRead` 2 of 8 red, the two targeted methods (run 1227; the vendor import armed to fail, `T21Pm24Rd1` absent afterwards), reverted (diff empty).
- PM-24 (the 2,000 bound): mutation: `Review` refusing at `>=` the cap -> `ResourceTransferRead` 1 of 8 red (run 1236), reverted and reloaded.
- PM-24 (kernel route): mutation: `Prohibited.Prohibits` not calling `ResourceImport` for a resource import -> `ResourceTransferWrite` 1 of 2 red, on the kernel's own row only (run 1229), reverted (diff empty), 2 of 2 green (run 1230).
- PM-24 (client): mutation: `resource-list.page.ts` sending `export` for the all target -> `resource-transfer.spec.ts` 1 of 6 red (the body assertion), reverted (shasum equal). Browser: the `export` registration dropped, rebuilt and redeployed -> `resources-transfer.browser-spec.mjs` 1 of 2 red (no export dialog opens), reverted (shasum equal), rebuilt and redeployed, 2 of 2 green.

**Commands.** ObjectScript test runs are one call each, never two in one message.

- `sh /private/tmp/claude-501/-Users-jbrandt-git-OcuPilot/b708a79b-b765-42ec-adea-dbc87acf6251/scratchpad/e21u/lead/reload.sh /Users/jbrandt/git/OcuPilot/.worktrees/epic-21 ocupilot-ci` (loop) -- expected: `LOADERRORS=0`, no compile error.
- `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.<Class>` (loop), once for each of: `AdvisorRead`, `AdvisorWrite`, `ConfigSettingRead` (or `TaskMailSettingRead`), `TaskMailSettingRules`, `TaskMailSettingWrite`, `ConfigSettingRules`, `ConfigSettingWrite`, `SqlSettingRead`, `WebAppCreate`, `WebAppWire`, and every shared-surface class above -- expected: all green.
- `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/` (loop) -- expected: within the 2500/4000 kB budgets.
- `cd ui && OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci node --test --test-concurrency=1 browser/<file>.browser-spec.mjs` (loop), one call per file: `security-advisor`, `config-settings`, `web-applications-create`, `users-create`, `roles-create`, `web-applications-class-access`, `language-servers` -- expected: green.
- `cd ui && npm run test:tools` and `cd ui && npm run test:components` (loop) -- expected: green.
- `uv run scripts/check-objectscript.py`, `uv run scripts/test_check_objectscript.py`, `bash scripts/lint-docs.sh` (loop) -- expected: clean.
- The full ObjectScript sweep over `src/OcuPilot/Test` (once, before `dev_complete`), one class per call or batches sized from `ui/tools/ci-timings.json` to about 8 minutes -- expected: green. The full browser suite is left to CI (Rule 29).

**Rulings (2026-11-20):** this story closes with Batches 1 to 3 and PM-24; TM-17 and TM-18's password are Story 21.36's (Spec Change Log). PM-24's ten strings are accepted as written in `strings.ts` and EXPERIENCE.md's Fixed strings.

## Auto Run Result

Status: done
Blocking condition: none

**Change.** Security advisor (`AdvisorPort`, `SecurityAdvisorList`, ignore and stop-ignoring tools), Task Manager email settings (`ConfigPort` `TaskMail`, `TaskMailSettingList`, `TaskMailSettingSet`), web application Copy from, the three create pages' hand-off (DW-2372), the shared read's unreadable-200 refusal (DW-2471), and resource export and import (PM-24, `ResourceTransferPort` and its tools, `ResourceList` actions). TM-17 and TM-18's password are Story 21.36's; nothing is built for either, and the tree holds no half-built code for them (`TaskDetails.cls` and `AuditPort.cls` are unchanged from the baseline).

**Review.** 22 findings, none high: 7 patched (2 medium, 5 low), 1 deferred (`UseSTARTTLS` and message round trip, unverified medium), 14 rejected with their reasons in the Review Triage Log. Patches: executing tests for `warmEditPage`'s tolerance, the advisor read-source grammar, the advisor screen read's cap, the agent's unlisted-row mint, and the import consequence sentence; a browser-spec key map and one spacing fix. Follow-up review recommended: true, for the two medium patches, whose new tests each carry one mutation and whose changed-after-mint leg is guarded twice, so no single mutation reddens it alone.

**Verification.** `reload.sh` into `ocupilot-ci` `LOADERRORS=0`; the roster sweep (every `*Sweep`, `*Coverage`, `*Screen`, `*Descriptor` class plus `DraftRegistry`, `ToolEmit`, `ReadDescriptions`, `Navigation`) 53 classes green, `ProposalScreen` being an unregistered fixture with no tests; the pin classes, eight browser specs and `npm run test:components` green in the implement pass; after the patches `AdvisorRead` 8 of 8, `AdvisorWrite` 5 of 5, `GovernanceBaseline` 3 of 3, `screen-outlet.spec.ts` 33 of 33, `npm run test:tools` 2351 of 2351, `check-objectscript.py` 0 problems, `lint-docs.sh` 0 issues.

**Residual risk.** The full ObjectScript sweep and the full browser suite are left to CI (Rule 29).
