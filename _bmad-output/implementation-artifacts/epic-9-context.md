# Epic 9 Context: The full editors

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Give administrators full editors that carry the classic portal's whole field set, so they can edit an existing instance object the way they actually work, without returning to the classic portal. The editors cover user, web application, role, SSL/TLS, the New Task wizard and Edit task. The service editor and the LDAP/Kerberos editor move to Stories 16.13 and 16.14 and ship reduced here. This is build step 6, done in story order. It holds the largest forms in Release 1, so the cut line is most likely to bite here, and FR-9's reduced-form rule is the designed answer when it does: a cut editor ships as an honest reduced form, never as a half-working full form.

## Stories

- Story 9.1: The user editor
- Story 9.2: The web application editor
- Story 9.3: The role editor
- Story 9.5: The SSL/TLS editor
- Story 9.7: The New Task wizard
- Story 9.8: Edit task
- Story 9.9: A cut editor ships reduced, never half-working

## Requirements & Constraints

- **Every editor (applies to all stories; not restated per story):**
  - Each editor is a full-page `form-page` route, with sections in Material tabs named after the classic editor's tabs.
  - One form spans all tabs, and Save applies everything. A validation error switches to the tab that holds it. That tab shows a `destructive` dot and appends ", N errors" to its accessible name.
  - Every save reads fresh, applies the diff and sends the **complete property set**, because most of these endpoints do not merge.
  - Every editor ships its agent write tool over the derived field list.
  - Every editor declares its suggested prompts in its descriptor, following Story 11.3's contract whether or not Epic 11 has landed.
- **User editor (9.1):**
  - It is the pattern the other editors follow for tabs, validation, the error summary and the unsaved-changes guard.
  - A test proves that a two-field save preserves every other field.
  - `Password`/`NewPassword` are the tool's own **secret** fields. They are kept out of model arguments, screen context, stored proposal arguments and the ledger. When the agent proposes a password change, the user fills them in at confirmation.
- **Web application editor (9.2):**
  - After a save, the list updates through the change-event bus with no manual refresh.
  - On OcuPilot's own web applications, disabling the application or setting `Roles`/`MatchRoles` is refused on the instance.
- **Role editor (9.3):** the resource-grant dialog shows the current grant and the resulting grant, as it does on the create path.
- **SSL/TLS editor (9.5):**
  - Private key material is **never returned** by any read, diff, ledger row or log line.
  - The installer-created `ProviderPort` configuration can be edited, but its role is shown.
  - Test connection reports the instance's own result text, whether the test succeeds or fails.
- **New Task wizard (9.7):**
  - It is a linear vertical stepper: Basics, Task type and settings, Schedule, Options and notifications.
  - Next validates the current step, and Back keeps the values already entered. The type step loads that type's settings. The last step's primary button reads "Create task". A step with an error names the error in text, not only through its step circle.
  - The field list comes from the task class's inherited properties: 49 of its 66 carry documentation, all declared on `%SYS.TaskSuper`.
  - `TimePeriod` 0–5 fixes how `TimePeriodEvery` and `TimePeriodDay` are read.
  - `DailyFrequency` governs a quadruple: `DailyFrequencyTime` (minutes or hours), `DailyIncrement`, `DailyStartTime` and `DailyEndTime`. Dropping `DailyFrequencyTime` makes the increment 120-fold ambiguous.
  - The semantics of `ExpiresDays/Hours/Minutes` and `RunAsUser`'s `%Admin_Secure:Use` requirement are **established by test against the instance**, never guessed.
- **Edit task (9.8):**
  - It uses the wizard's model, so its fields match the wizard's by construction.
  - It sends the complete set from a fresh read.
  - The next-scheduled time is excluded from the fingerprint by the descriptor's declared exclusions.
- **Cut editors (9.9):**
  - A cut editor ships a reduced form of the fields used in daily administration, plus a `classic-link-card`. The card is titled "More in the classic portal", names the classic page it opens, opens it in a new tab, and carries the caption about signing in again.
  - The editor's write tool ships anyway, as a get-merge-put.
  - Each area needs at least one create or edit form. **No list screen links out**.
  - The service editor and the LDAP/Kerberos editor get their reduced forms and write tools here.
- **Routed deferred work:** each story's `DW-*` items in the epics file must be addressed or declined with a reason. Several are Epic 7/8 screen callers that landed here:
  - Row-action Deletes: Roles and Resources (9.3), X.509 and wallet secret (9.5).
  - The editor half of the user actions (DW-1501).
  - The change-on-login ordering (DW-1516).
  - The consequence line in the Add role dialog, now possible because `privilegedGrantEffect` has landed (DW-1523).
  - The web-app cold-load and name canonicalization (DW-1490, DW-1493).
  - Whether the `PROHIBITED.PRIVILEGEGRANT` sentence is published and pinned (DW-1502, still decision-pending in the spine).

## Technical Decisions

- **Field lists are derived, never typed by hand (AD-3).** They are generated at build time from the endpoint's body-template method, as a checked-in artifact. Only `required`, `enum` and `description` are authored, once per tool. Every derived field is classified `ordinary`, `secret` or `opaque`. An unclassified field defaults to secret. A string field whose name matches the credential pattern fails the build unless it is classified secret.
- **OcuPilot does the merge (AD-4).** Read fresh, apply the diff, send the whole object. `Security.User`, `Task.CRUD` and others erase any field that is omitted.
- **One descriptor per screen (AD-5).** It declares route, privilege set, entity type, context serializer and secret fields, actions, and fingerprint exclusions. An editor declares `sideBarPosition` 0 and is reached from its list's name cell or from Create.
- **Proposals (AD-6, AD-34):**
  - A proposal is minted on the server, single-use and fingerprinted over the complete set, minus declared exclusions. It expires after 10 minutes.
  - The confirm channel admits only the fields the descriptor declares secret.
  - Privileges are re-checked at confirm. Confirm is one atomic transition that also cancels sibling proposals.
- **Privileges and the prohibited set:**
  - Privileges are the process's own, checked at call time as `(resource, permission)` pairs. Administrative resources are checked at `USE` (AD-8).
  - **Owner decision 2026-09-23, "developer tool first" (AD-10 amended).** Where the vendor API allows something, OcuPilot permits it behind confirmation. Granting `%All`, an `%Admin_*` role (or a role carrying one), an escalating resource grant, or a privileged application role on any *other* web application is **permitted at the strongest confirmation**.
  - The prohibited set is still refused on the instance, whoever the caller:
    - application roles on OcuPilot's own web apps (`PROHIBITED.PRIVILEGEGRANT`)
    - public permission on `%DB_OCUPILOT`/`OcuPilotAdmin` (`PROHIBITED.OCUPILOTRESOURCE`)
    - disabling the path that serves OcuPilot
    - account protections: the current user, `_SYSTEM`, the service account, and the last `%All` holder. These are judged **by effect**: a delete, a disable, or a `Roles` delta that strips `%All`.
  - The prohibited set is enforced by kernel predicates only, never by the UI.
- **Privilege-grant proposals.** An agent proposal that grants privilege is minted **destructive**, with the typed-name confirmation, and its server-computed diff **names the privilege**. On a person's Save, the field shows `privilegedGrantEffect`. On an unauthenticated web app it shows `privilegedGrantEffectUnauthenticated` instead, as **one line, not two**: it replaces both the privilege line and the unauthenticated line. Both warn and refuse nothing.
- **Ids (AD-13).** One percent-encoded path segment. Every reference carries the `(type, scope, id)` triple. Canonical spelling is a per-type rule in the identity layer; the web-app rule is case-insensitive with trailing-slash normalization.
- **Change events (AD-14).** A confirmed write and a screen Save each publish one change event. Screens re-fetch and never patch.
- **Reads (AD-36).** A screen and its tool resolve through one declared read. It may use a `rowGet` detail call; for example, `Task.CRUD` `INFO` answers `Suspended` truthfully where LIST does not.
- **Admin API fallbacks (AD-27).** The admin API is confined to `AdminPort`. A vendor-class fallback is allowed only for a named endpoint, in four cases: a `Security.Resource` PUT with empty `PublicPermission`, an X.509 import from content, a `Wallet.Secret` read, and a `Process` terminate with the error flag. Any new case (an SSL private key, for example) must be added to AD-27 by name first.
- **Validation (AD-39).** Errors use `detail.violations[]` `{field, code, reason}`. The screen renders `reason` at the field. Refusal copy is written once on the server.
- **Row actions (AD-53).** A screen's row action and the agent's write are **one operation with two callers**, sharing the port, the fresh read, the prohibited predicates, the privilege gate, the change event and the vendor audit. The screen caller mints no proposal, emits no agent marker, and is not gated by the read-only switch or the kill switch. A refusal sentence is published once in EXPERIENCE.md Fixed strings and pinned by a test.
- **Create (AD-54).** The fresh read must find the target **absent**, and the fingerprint covers that absence under the canonical name. Prohibited field lists are keyed by create versus change.
- **Screen Save (AD-55).** A screen's Save goes **through the same write tool class** as the agent: the tool's endpoint, request type, fields, payload composition and port, with AD-10 evaluated before any port call. There is no proposal, and the read-only switch and kill switch do not gate it. The one exception is a self-service change to the user's own account (AD-49).
- **Secrets and list fields (AD-56).**
  - The password change is action-style (`CHANGEPWD`) and sends only `{NewPassword}`. Secrets use the descriptor's existing `secretArguments`.
  - The **change-on-login flag is sent before the password and again after it**, because the vendor's password change clears it. When two agent proposals carry both, the flag's proposal is confirmed after the password's.
  - A screen action accepts only the values its tool declares. List fields such as roles change by a server-side delta over a fresh read, never by a list the client computed.
- **Secrets never reach a surface (AD-35).** They are never returned, logged or put in an error. Redaction is schema-driven, with the name pattern as a backstop.
- **Patterns to reuse:**
  - Epic 7's row actions: `src/OcuPilot/Kernel/Proposal/Operation.cls`, reached through `POST /screens/:screen/action` (`Api/ScreenAction.cls`). The tool declares `SCREENACTIONS`, the list descriptor declares `rowActions`, and the client handles them in `ui/src/app/shell/screen-action-handler.ts`.
  - Epic 8's create/Save routes (AD-55): the `/<entity>/form`, `/name`, `POST` and `PUT /:id` routes in `Api/Router.cls`, with handlers in `src/OcuPilot/Area/<Area>/*Save.cls`/`*Rules.cls`.
  - Epic 8's form pages: `ui/src/app/areas/<area>/*-form.page.ts` and `*-form.store.ts`, for example `permissions/user-create-form.*` and `web-applications/create-form.*`. `shell/classic-link-card.ts` already exists.

## UX & Interaction Patterns

- **Form-page:** fields in classic order and a sticky Save/Cancel bar. Validation runs inline on blur and on Save. A failed Save focuses the error summary (`role="alert"`), which links to each field, then focuses the first invalid field and opens its tab. Required fields carry `aria-required` and the asterisk legend.
- **Saving and leaving:** an edit route stays open and shows "Saved" (`role="status"`). Leaving with unsaved changes asks "Leave without saving?", and an agent navigation waits for the same answer (AD-11).
- **Destructive row actions** use the typed-name confirmation dialog. A self-protected action is drawn disabled, with its reason.
- **Screen state** follows the store pattern: framework-free stores mirrored into signals, zoneless, OnPush (AD-19).
- New user-facing strings go in `ui/src/app/core/strings.ts` and in EXPERIENCE.md Fixed strings.

## Cross-Story Dependencies

- 9.1 sets the tab, validation, error-summary and unsaved-changes pattern that 9.2 through 9.8 reuse.
- 9.8 depends on 9.7's shared task model; the two build their forms from it.
- 9.9 depends on the fate of every other story. It also ships the reduced service and LDAP/Kerberos forms, which Epic 16 (16.13, 16.14) later replaces.
- The epic builds on:
  - Epic 7's operation, screen-action route and self-protection predicates.
  - Epic 8's create forms, create/Save routes, `privilegedGrantEffect` strings and absence fingerprint. Each create opens the editor this epic builds.
  - Story 11.3's suggested-prompt descriptor contract.
- Story 14.7 owns the typed-name field for destructive proposals.
