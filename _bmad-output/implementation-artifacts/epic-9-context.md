# Epic 9 Context: The full editors

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Give administrators the full-field editors the classic portal offers: user, web application, role, SSL/TLS, the New Task wizard and Edit task, plus a user audit event editor. With them, an instance can be administered from OcuPilot without going back to the classic portal. This is build step 6 and runs in the listed order. It is the first place the reduced-form rule applies: the service editor and the LDAP/Kerberos editor move to Epic 16, and Story 9.9 ships them here as reduced forms, each with its agent write tool. Every editor is a person's Save and also an agent write tool, and the two reach the instance through the same operation.

## Stories

- Story 9.1: The user editor
- Story 9.2: The web application editor
- Story 9.3: The role editor
- Story 9.5: The SSL/TLS editor
- Story 9.7: The New Task wizard
- Story 9.8: Edit task
- Story 9.9: A cut editor ships reduced, never half-working
- Story 9.10: The user audit event editor

## Requirements & Constraints

- **Every editor is a full-page form route with Material tabs** named after the classic editor's tabs. One form spans all the tabs, and Save applies everything. A validation error switches to the tab that holds it. That tab shows a destructive dot, and ", N errors" is added to its accessible name.
- **Save reads the object fresh, applies the diff and sends the complete property set.** Most of these endpoints do not merge (`Security.User`, `Task.CRUD`, `Security.Audit.Event`), so a partial body erases the omitted fields. Each editor needs a test proving that untouched fields survive a two-field save.
- Every editor ships its agent write tool over the derived field list. It also declares its suggested prompts in its descriptor under Story 11.3's contract, whether or not Epic 11 has landed.
- The user editor is the first large editor built. Its tab, validation, error-summary and unsaved-changes behavior is the pattern the others follow.
- User passwords (`Password`, `NewPassword`) are secret fields of the tool. They never appear in model arguments, screen context, stored proposal arguments or the ledger. The user fills them in at confirmation.
- SSL/TLS: private key material is never returned by any read, and never appears in a diff, a ledger row or a log line. The CRL slot is shown only as a caption saying the setting is deprecated and not exposed. The installer-created `ProviderPort` configuration can be edited, but its role must be visible. Test connection reports the instance's own result text. Delete uses the one delete tool behind a typed-name confirmation.
- Task fields and their legal values come from the task class's inherited property set, not from the classic page. 49 of its 66 compiled properties carry documentation: 47 declared on `%SYS.TaskSuper`, plus `%%OID` and `%Concurrency`.
  - `TimePeriod` 0–5 means daily, weekly, monthly, monthly-special, run-after and on-demand. Each value fixes how `TimePeriodEvery` and `TimePeriodDay` are read.
  - `DailyFrequency` 0 means once and 1 means several. It governs the quadruple `DailyFrequencyTime` (minutes or hours), `DailyIncrement` (meaningless without it), `DailyStartTime` and `DailyEndTime`.
  - `ExpiresDays`, `ExpiresHours` and `ExpiresMinutes` have no documentation, and `RunAsUser`'s `%Admin_Secure:Use` requirement is documented but unverified. Establish both **by test against the instance**, never by guessing.
- Edit task uses the same model as the wizard, so the field list matches by construction. The task's next-scheduled time is excluded from the fingerprint by the descriptor's declared exclusions.
- A cut editor ships as a reduced form of the daily-administration fields plus a `classic-link-card`, never as a half-working full form. Its write tool ships anyway, as a get-merge-put. The 2026-09-27 floor needs at least one create or edit form per area, and no list screen links out.
- User audit events: create goes through the write tool. Source, Type and Name are read-only once created. The vendor's rules for those three are measured on the instance and checked before the call, so a refusal reads as OcuPilot's own sentence on the field. A system event can't be created or edited through the user-event tools, and each audit-event tool refuses the other list's events.
- Each story's AC list includes routed deferred-work items (DW-*). Address each one in that story or decline it with a reason.

## Technical Decisions

- **One operation, two callers (AD-53, AD-55).** A screen's Save and the agent's confirmed write resolve through the same tool class: its endpoint, request type, settable fields, payload composition and port. The screen caller mints no proposal and emits no agent marker, and read-only and the kill switch do not gate it. It still inherits the prohibited set, validation and fingerprint gates, and the screen's own privilege pairs. A screen that composes its own payload or names its own endpoint is a defect.
- **Field lists are derived from the endpoint's body-template method (AD-3)** and checked in as generated source. The only hand-authored parts are required fields, enums and descriptions. Each field is classified `ordinary`, `secret` or `opaque`, and an unclassified field defaults to secret. A string field whose name matches the credential pattern must be secret, or the build fails. `Security.Audit.Event` publishes no template, so its field list comes from `Security.Events`, pinned by a test.
- **Create writes (AD-54).** The fresh read must find the target absent (404), and the fingerprint covers that absence under AD-13's canonical spelling. The payload is composed from the caller's arguments. Where the vendor's create requires the full body (the task create needs all 34 keys), the keys the caller didn't supply take default values and are counted as unchanged. `Security.Audit.Event` and `WebApp.App` PUTs are upserts, so the absence fingerprint is load-bearing.
- **Action-style writes (AD-51, AD-56).** An action-style write declares its request type and sends no body, or a body made only of its declared secrets (the password `CHANGEPWD` sends `{NewPassword}`). Its fingerprint covers a declared subject of the fresh read. The vendor's password change clears `ChangePassword`, so the password write re-applies a change-on-login flag its fresh read found set. A list-valued field such as roles changes by a server-side delta over a fresh read, never by a list the client computed.
- **Prohibited set (AD-10)** is refused on the instance whatever the caller, and is judged by effect rather than by verb or payload shape. The arms that bite in this epic:
  - Application roles (`MatchRoles`/`Roles`) on OcuPilot's own web applications.
  - Making those applications unauthenticated, clearing their authorization resource, or changing their dispatch class, namespace, Python app, `Package` or `SuperClass`.
  - Changing `GrantedRoles`, `Resources` or `EscalationOnly` on OcuPilot's own roles.
  - `VerifyPeer`, `CAFile`, `Type` or `Enabled` on OcuPilot's provider SSL configuration, or deleting it.
  - A new password or change-on-login set on the service account (`PROHIBITED.SERVICEACCOUNTSIGNIN`).
  - Removing `_SYSTEM`, the signed-in user, the service account or the last `%All` holder, or stripping their `%All` directly or through a role.
  - Every other privilege grant, including `%All` and application roles on other applications, is **permitted** but gets the strongest confirmation and a consequence line.
- **Locations are named, never pathed (AD-21).** A task's output file is one segment matching `^[A-Za-z0-9][A-Za-z0-9._-]{0,99}\.txt$`, written to the manager directory resolved at call time. SSL file fields are shown but never set.
- **Port completions (AD-27)** exist only for named cases. A `WebApp.App` PUT re-applies the application's stored `Type`. The X.509 import goes through `%SYS.X509Credentials`.
- **Privilege (AD-8).** A write tool's pair set is the screen's declared set, with administrative resources required at `USE`, never `WRITE`.
- **Refusals (AD-39, AD-53).** A refusal is `{field, code, reason}` in `detail.violations[]`. Its sentence is written once on the server, published in EXPERIENCE.md's Fixed strings, and pinned equal by a test. A reason that names "the agent" is a defect.
- **Change events (AD-14).** Save publishes the scoped triple, and lists re-fetch without a manual refresh. Ids are percent-encoded in a single path segment (AD-13), and each entity type has its own canonical-spelling rule.
- Editors declare `sideBarPosition` 0: they are reached from their list's name cell or its Create action.

## UX & Interaction Patterns

- **form-page.** Fields follow the classic order, with a sticky Save/Cancel bar. Validation runs inline on blur and on Save, and server rules land on the field they name. On a failed Save, the error summary (`role="alert"`) takes focus with a link per field, and then the first invalid field is focused with its tab opened. Required fields use `aria-required` plus the asterisk legend. Save on an edit route shows "Saved" in the bar. Leaving with unsaved changes asks "Leave without saving?", and agent navigation waits for the same answer.
- **Stepper (New Task wizard).** A custom vertical `form-stepper`, not Material's, which adds 83 kB. The steps are Basics · Task type and settings · Schedule · Options and notifications, and the flow is linear. Next validates the step, Back keeps values, and the task-type step loads that type's settings. The last step's primary reads "Create task". A step with an error names it in text ("This step needs attention: <reason>").
- **classic-link-card.** Titled "More in the classic portal". It names the classic page, opens it in a new tab, and carries the caption "The classic portal may ask you to sign in again." It is never placed on a list.
- Gated controls stay focusable with `aria-disabled` and name their reason. Self-protection refusals appear as disabled actions whose reason is the published sentence.
- Every new label and refusal becomes a row in EXPERIENCE.md's Fixed strings and a key in `strings.ts`.

## Cross-Story Dependencies

- Stories 9.1, 9.2, 9.3, 9.5 and 9.7 are done. Story 9.8 builds on 9.7's task model and field list. 9.9 follows every full editor. 9.10 runs last.
- 9.1 carries user-row actions over from Epic 7 (DW-1501). 9.3 adds the Role and Resource list Delete row actions. 9.5 adds the X.509 and wallet-secret deletes. Epic 7 left the create and configure halves of user audit events to 9.10.
- Stories 16.13 and 16.14 own the full service and LDAP/Kerberos editors, and 9.9 ships their reduced forms. Epic 12 owns the OAuth 2.0 editors. Story 11.3 owns the suggested-prompts contract that each descriptor declares.
