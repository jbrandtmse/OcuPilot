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
- **Save reads the object fresh, applies the diff and sends the complete property set.** Most of these endpoints do not merge (`Security.User`, `Task.CRUD`, `Security.Audit.Event`), so a partial body erases the omitted fields. Each editor needs a test proving that untouched fields survive a two-field save. `Task.CRUD` has named omissions (see Technical Decisions).
- Every editor ships its agent write tool over the derived field list. It also declares its suggested prompts in its descriptor under Story 11.3's contract, whether or not Epic 11 has landed.
- The user editor's tab, validation, error-summary and unsaved-changes behavior is the pattern the others follow.
- User passwords (`Password`, `NewPassword`) are secret fields of the tool. They never appear in model arguments, screen context, stored proposal arguments or the ledger. The user fills them in at confirmation.
- SSL/TLS: private key material is never returned by any read, and never appears in a diff, a ledger row or a log line. The CRL slot is only a caption saying the setting is deprecated and not exposed. The installer-created `ProviderPort` configuration can be edited, but its role must be visible. Test connection reports the instance's own result text. Delete uses the one delete tool behind a typed-name confirmation.
- **Tasks (wizard and Edit task share one model, so their field lists match by construction).** Fields and legal values come from the inherited property set of `%SYS.TaskSuper`, never the classic page. `TimePeriod` 0–5 fixes how `TimePeriodEvery`/`TimePeriodDay` are read. `DailyFrequency` governs the `DailyFrequencyTime`/`DailyIncrement`/`DailyStartTime`/`DailyEndTime` quadruple. The undocumented `Expires*` offsets and `RunAsUser`'s `%Admin_Secure:Use` requirement are established by test on the instance.
  - The next-scheduled time is outside the fingerprint because the tool's fresh read does not carry it (measured). A test pins that a proposal whose task ran before confirm still writes.
  - Edit task shows type and namespace read-only. A changed output file on a task that writes outside the manager directory is refused as classic-only. A `%SYS.Task.Password`-typed setting is classic-only for both create and edit.
- **Cut editors.** A cut editor ships as a reduced form of the daily-administration fields plus a `classic-link-card`, never as a half-working full form. Its write tool ships anyway, as a get-merge-put. The 2026-09-27 floor needs at least one create or edit form in each of the **five areas that administer an object**. Logs administers none, and a test pins it at zero forms. No list screen in the six areas links out: a link-out on a list counts against the counter-metric, and one on an editor is a recorded cost.
- User audit events: create goes through the write tool. Source, Type and Name are read-only once created. The vendor's rules for those three are measured on the instance and checked before the call, so a refusal reads as OcuPilot's own sentence on the field. A system event can't be created or edited through the user-event tools, and each audit-event tool refuses the other list's events.
- Each story's AC list includes routed deferred-work items (DW-*). Address each one in that story or decline it with a reason.

## Technical Decisions

- **One operation, two callers (AD-53, AD-55).** A screen's Save and the agent's confirmed write resolve through the same tool class: its endpoint, request type, settable fields, payload composition and port. The screen caller mints no proposal and emits no agent marker, and read-only and the kill switch do not gate it. It still inherits the prohibited set, validation and fingerprint gates, and the screen's own privilege pairs. A screen that composes its own payload or names its own endpoint is a defect.
- **Field lists are derived from the endpoint's body-template method (AD-3)** and checked in as generated source. The only hand-authored parts are required fields, enums and descriptions. Each field is classified `ordinary`, `secret` or `opaque`, and an unclassified field defaults to secret. A string field whose name matches the credential pattern must be secret, or the build fails. `Security.Audit.Event` publishes no template, so its field list comes from `Security.Events`, pinned by a test.
- **`Task.CRUD` exceptions to the complete body (AD-4).** The port omits a re-sent `DailyStartTime` or `DailyEndTime` equal to the stored value, an unchanged `Settings` (a sent `Settings` replaces every setting) and its own `Type`. The vendor keeps an omitted key (measured). A changed `Settings` on a type with a secret-typed setting must carry that secret re-entered as a write-only field, or be refused by name before any port call.
- **Create writes (AD-54).** The fresh read must find the target absent (404), and the fingerprint covers that absence under AD-13's canonical spelling. The payload is composed from the caller's arguments. Where the vendor's create requires the full body (the task create needs all 34 keys), the keys the caller didn't supply take default values and are counted as unchanged. `Security.Audit.Event` and `WebApp.App` PUTs are upserts, so the absence fingerprint is load-bearing.
- **Action-style writes (AD-51, AD-56).** An action-style write declares its request type and sends no body, or a body made only of its declared secrets (the password change sends `{NewPassword}`). Its fingerprint covers a declared subject of the fresh read, and a card row's before value comes from that read. The vendor's password change clears `ChangePassword`, so the password write re-applies a change-on-login flag that its fresh read found set. A list-valued field such as roles changes by a server-side delta over a fresh read, never by a list the client computed.
- **Prohibited set (AD-10)** is refused on the instance whatever the caller, and is judged by effect rather than by verb or payload shape. The arms that bite in this epic:
  - Application roles (`MatchRoles`/`Roles`) on OcuPilot's own web applications.
  - Making those applications unauthenticated, clearing their authorization resource, or changing their dispatch class, namespace, Python app, `Package` or `SuperClass`.
  - Changing `GrantedRoles`, `Resources` or `EscalationOnly` on OcuPilot's own roles.
  - `VerifyPeer`, `CAFile`, `Type` or `Enabled` on OcuPilot's provider SSL configuration, or deleting it.
  - **Disabling `%Service_WebGateway`**, the only service that serves OcuPilot on 2026.2 (`%Service_Web` and a CSP service do not exist on this build). It is refused `PROHIBITED.SERVINGSERVICE` from either caller. Changing its allowed addresses or authentication methods is permitted, but it is minted destructive with a consequence line. No Release 1 tool reaches the superserver.
  - A new password or change-on-login set on the service account.
  - Removing `_SYSTEM`, the signed-in user, the service account or the last `%All` holder, or stripping their `%All` directly or through a role.
  - Every other privilege grant, including `%All` and application roles on other applications, is **permitted** but gets the strongest confirmation and a consequence line.
- **Classic link-outs (AD-44).** A detail view may link out only where its descriptor declares `classicLinkExemption` with a reason. The check fails any list archetype that declares one, and it reports every exemption it honors. Release 1 has exactly three: the OAuth 2.0 tabs, the reduced service editor (removed by 16.13) and the reduced LDAP editor (removed by 16.14). Each counts against SM-C1.
- **Locations are named, never pathed (AD-21).** A task's output file is one segment matching `^[A-Za-z0-9][A-Za-z0-9._-]{0,99}\.txt$`, written to the manager directory resolved at call time. SSL file fields are shown but never set.
- **Privilege (AD-8).** A write tool's pair set is the screen's declared set, with administrative resources required at `USE`, never `WRITE`.
- **Refusals (AD-39, AD-53).** A refusal is `{field, code, reason}` in `detail.violations[]`. Its sentence is written once on the server, published in EXPERIENCE.md's Fixed strings, and pinned equal by a test. A reason that names "the agent" is a defect.
- **Change events (AD-14).** Save publishes the scoped triple, and lists re-fetch without a manual refresh. Ids are percent-encoded in a single path segment (AD-13), and each entity type has its own canonical-spelling rule.
- Editors declare `sideBarPosition` 0: they are reached from their list's name cell or its Create action.

## UX & Interaction Patterns

- **form-page.** Fields follow the classic order, with a sticky Save/Cancel bar. Validation runs inline on blur and on Save, and server rules land on the field they name. On a failed Save, the error summary (`role="alert"`) takes focus with a link per field, and then the first invalid field is focused with its tab opened. Required fields use `aria-required` plus the asterisk legend. Save on an edit route shows "Saved" in the bar. Leaving with unsaved changes asks "Leave without saving?", and agent navigation waits for the same answer.
- **Stepper (New Task wizard).** A custom vertical `form-stepper`, not Material's. The steps are Basics · Task type and settings · Schedule · Options and notifications, and the flow is linear. The last step's primary reads "Create task". A step with an error names it in text, never by its circle alone.
- **classic-link-card.** Titled "More in the classic portal". It names the classic page, opens it in a new tab, and carries the caption "The classic portal may ask you to sign in again." It is never placed on a list.
- **Self-protection is drawn, not warned.** The service form draws its Enabled control unavailable on `%Service_WebGateway`, with the published reason, before any click. A permitted-but-risky change shows its consequence line at the field and on the proposal card. A reduced form at its bare route links back to its list, and at an id the instance no longer holds it shows the published "no longer exists" sentence.
- Gated controls stay focusable with `aria-disabled` and name their reason.
- Every new label, caption, refusal and suggested prompt becomes a row in EXPERIENCE.md's Fixed strings and a key in `strings.ts`.

## Cross-Story Dependencies

- Stories 9.1 to 9.9 are done. 9.10 runs last. It carries the create and configure halves of user audit events that Epic 7 (Story 7.11) left behind, and it depends on AD-54's create kind and AD-55's screen Save.
- Stories 16.13 and 16.14 own the full service and LDAP/Kerberos editors, replacing 9.9's reduced forms and removing their link-out exemptions. 16.13's disable of the serving service is a disabled control, not a warning dialog. Epic 12 owns the OAuth 2.0 editors. Story 11.3 owns the suggested-prompts contract that each descriptor declares.
