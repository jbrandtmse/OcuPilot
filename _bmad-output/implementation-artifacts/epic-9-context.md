# Epic 9 Context: The full editors

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Give administrators full editors that carry the classic portal's whole field set, so they can edit an existing instance object the way they actually work, without returning to the classic portal. The editors cover user, web application, role, SSL/TLS, the New Task wizard and Edit task. The service editor and the LDAP/Kerberos editor move to Stories 16.13 and 16.14 and ship reduced here. This is build step 6, done in story order. It holds the largest forms in Release 1, so the cut line is most likely to bite here, and FR-9's reduced-form rule is the designed answer when it does: a cut editor ships as an honest reduced form, never as a half-working full form.

## Stories

- Story 9.1: The user editor (done; the reference editor)
- Story 9.2: The web application editor (done)
- Story 9.3: The role editor
- Story 9.5: The SSL/TLS editor
- Story 9.7: The New Task wizard
- Story 9.8: Edit task
- Story 9.9: A cut editor ships reduced, never half-working

## Requirements & Constraints

- **Every editor (applies to all stories; not restated per story):**
  - A full-page `form-page` route, sections in Material tabs named after the classic editor's tabs. One form spans all tabs; Save applies everything. A validation error opens the tab holding the first error; that tab shows a `destructive` dot and its accessible name gains ", 1 error" / ", N errors".
  - Every save reads fresh, applies the diff and sends the **complete property set** (most endpoints do not merge).
  - Every editor ships its agent write tool over the derived field list, and declares at least three suggested prompts in its descriptor (Story 11.3's contract, whether or not Epic 11 has landed).
  - A test proves a two-field save preserves every other field (set by 9.1; follow it).
  - Every merge tool refuses a no-op change with 400 `TOOL.ARGUMENTS` at mint, never an empty proposal.
  - A refusal sentence is caller-neutral (screen and agent share the predicate), published in EXPERIENCE.md Fixed strings and pinned by `Test/RefusalCopy.cls`, `strings.ts` and `ui/tools/self-protection.test.mjs`.
- **Role editor (9.3):** description, escalation-only, resource grants, members, granted-to. The resource-grant dialog shows current and resulting grant, as on the create path.
- **SSL/TLS editor (9.5):** private key material is **never returned** by any read, diff, ledger row or log line. The installer-created `ProviderPort` configuration is editable but its role is shown. Test connection reports the instance's own result text, pass or fail.
- **New Task wizard (9.7):** linear vertical stepper (Basics; Task type and settings; Schedule; Options and notifications). Next validates the step, Back keeps values, the type step loads that type's settings, the last primary button reads "Create task", and a step in error names it in text. Fields come from the task class's inherited properties (49 of 66 documented, all on `%SYS.TaskSuper`). `TimePeriod` 0–5 fixes how `TimePeriodEvery`/`TimePeriodDay` read; `DailyFrequency` governs `DailyFrequencyTime`, `DailyIncrement`, `DailyStartTime`, `DailyEndTime` (dropping `DailyFrequencyTime` makes the increment 120-fold ambiguous). `ExpiresDays/Hours/Minutes` semantics and `RunAsUser`'s `%Admin_Secure:Use` need are **established by test on the instance**, never guessed.
- **Edit task (9.8):** uses the wizard's model, sends the complete set from a fresh read, and excludes next-scheduled time from the fingerprint via the descriptor's exclusions.
- **Cut editors (9.9):** a reduced form of the daily-administration fields plus a `classic-link-card` ("More in the classic portal", names the classic page, new tab, sign-in-again caption). The write tool ships anyway as get-merge-put. Each area needs at least one create or edit form; **no list screen links out**. The reduced service and LDAP/Kerberos editors ship here.
- **Routed deferred work** (address or decline with a reason):
  - 9.3: Roles-list Delete row action with holder count in the typed-name confirmation (DW-1513); Resources-list Delete, drawn disabled with reason when `AllowDelete` is false (DW-1528); rewrite `PROHIBITED.UNCOVEREDFIELD`'s reason caller-neutral, publish and pin it (DW-1598).
  - 9.5: credential-name guard misses `PrivateKeyFile`/`CertificateFile`/`CAFile`/`CAPath` etc. (DW-268); destructive-test guard lacks `Security.SSLConfigs` create/delete (DW-332); no sentence for an absent entity on a list-less form page (DW-391); X.509-list Delete (DW-1541); wallet-secret delete tool and row action (DW-1556).

## Technical Decisions

- **Field lists are derived, never hand-typed (AD-3):** generated at build time from the endpoint's body template; only `required`, `enum`, `description` are authored. Every field is `ordinary`, `secret` or `opaque`; unclassified defaults to secret, and a credential-pattern name not classified secret fails the build.
- **OcuPilot does the merge (AD-4):** read fresh, apply the diff, send the whole object — `Security.User`, `Task.CRUD` and others erase omitted fields.
- **One descriptor per screen (AD-5):** route, privileges, entity type, context serializer, secret fields, actions, fingerprint exclusions, `commandAliases`, `suggestedPrompts`. An editor has `sideBarPosition` 0 and is reached from its list's name cell or from Create.
- **Proposals (AD-6, AD-34):** server-minted, single-use, fingerprinted over the complete set minus exclusions, 10-minute expiry; confirm admits only declared secrets, re-checks privilege, and atomically cancels siblings.
- **Fresh read (AD-51):** the tool declares its request type and its read type. Where the one-object read does not answer a field the diff shows, the read may be a list type filtered by a declared read parameter to the one row whose declared key equals the id (`READIDPARAM`/`READROWKEY`); no such row reads as absent.
- **Privileges and the prohibited set (AD-8, AD-10):** process's own `(resource, permission)` pairs at call time; admin resources at `USE`. "Developer tool first": what the vendor API allows is permitted behind confirmation — `%All`, `%Admin_*` roles, escalating grants and privileged roles on *other* web apps are permitted at the strongest confirmation. Refused on the instance for every caller, by kernel predicates only: application roles on OcuPilot's own web apps (`PROHIBITED.PRIVILEGEGRANT`); making one of OcuPilot's **own** web apps unauthenticated, clearing its resource, or repointing its code (`PROHIBITED.UNAUTHENTICATED`/`.AUTHORIZATION`/`.DISPATCH`); public permission on `%DB_OCUPILOT`/`OcuPilotAdmin`; disabling the path that serves OcuPilot; account protections for the current user, `_SYSTEM`, the service account and the last `%All` holder, judged by effect (delete, disable, `Roles` delta stripping `%All`). **Service-account sign-in arm:** a new password, or turning change-on-login on, for an account the instance's services run as is refused `PROHIBITED.SERVICEACCOUNTSIGNIN` on both callers; `_SYSTEM` and the signed-in account are exempt, and turning the flag off is always permitted.
- **Weakening another web app is permitted:** on any application not OcuPilot's own, making it unauthenticated, clearing its resource or repointing its code is minted destructive with its effect named (`Prohibited.WeakensByEffect`: `WEBAPP.UNAUTHENTICATED`/`NORESOURCE`/`REPOINTED`), and a person's Save shows a consequence line. `Path` and the Python location stay caller-unnameable (AD-21).
- **Privilege-grant proposals** are minted destructive with typed-name confirmation, and the diff names the privilege. On a person's Save the field shows `privilegedGrantEffect`, or on an unauthenticated web app the single line `privilegedGrantEffectUnauthenticated`. Both warn, never refuse.
- **Ids and events (AD-13, AD-14):** one percent-encoded segment, `(type, scope, id)` triple, per-type canonical spelling (web apps: case-insensitive, trailing slash normalized). Every confirmed write and Save publishes one change event; screens re-fetch, never patch.
- **Reads (AD-36):** screen and tool resolve through one declared read, which may use a `rowGet` detail call (`Task.CRUD` `INFO` answers `Suspended` truthfully where LIST does not).
- **Admin API fallbacks (AD-27):** admin API only via `AdminPort`; vendor-class fallbacks only for named endpoints (five today, the latest `WebApp.App` PUT, whose `Type` reset `AdminPort` restores). A new case (e.g. SSL private key) must be added to AD-27 by name first.
- **Validation (AD-39):** `detail.violations[]` `{field, code, reason}`, rendered at the field; refusal copy written once on the server.
- **Row actions (AD-53):** a screen row action and the agent write are one operation with two callers (same port, fresh read, predicates, privilege gate, change event, audit). The screen caller mints no proposal and is not gated by the read-only or kill switch. Each refusal sentence is published in EXPERIENCE.md Fixed strings and pinned by a test.
- **Create (AD-54):** fresh read must find the target absent; the fingerprint covers the absence under the canonical name, and Confirm sends the create's name as typed. A field prohibited for repointing a serving object (one of OcuPilot's own applications) is prohibited on a change, permitted on a create.
- **Screen Save (AD-55):** goes through the same write tool class (endpoint, request type, fields, payload, port), with AD-10 evaluated before any port call; no proposal, no switch gating (except self-service on one's own account, AD-49). Edit-Save order, as in `Area/Permissions/UserSave.cls` and `Area/WebApp/WebAppSave.cls` (`PUT /<entity>/:id`): privilege pairs, fresh read (404 if absent), undeclared keys 400, rules, merge, prohibited set, send.
- **Secrets and list fields (AD-56, AD-35):** the password change is action-style `CHANGEPWD` with only `{NewPassword}`, supplied at the write and never stored. The change-on-login flag is its own ordinary write sent before the password and again after it (the vendor's change clears it); when two agent proposals carry the pair, the password write re-applies a flag its fresh read found set, so either confirm order ends set. A screen action admits only declared keys; list fields (roles) change by a server-side delta over a fresh read, never a client-computed list. Secrets are never returned, logged or put in an error.
- **Theme:** `ocu-theme-dark` on `<html>` is the whole theme; components draw bare `--ocu-<role>`/`--mat-sys-*` tokens only, never color literals and never selecting on the theme. A surface reversed between modes gets a token pair in `_tokens.scss`.
- **Reuse, don't rebuild (from 9.1 and Epics 7/8):**
  - Tabs: `ui/src/app/core/form-tabs.ts` + `ui/src/app/shell/form-tabs.ts` (tab nav bar, error dot, count in the accessible name, opens the first error's tab).
  - Row/editor actions: `ui/src/app/shell/screen-action-dialogs.ts` (list action dialogs, reusable from an editor) and `screen-action-handler.ts`'s public `startFor(..., values)` (carries a role-delta action's values); server side `Kernel/Proposal/Operation.cls` via `POST /screens/:screen/action`, tool `SCREENACTIONS`, list descriptor `rowActions`.
  - Routing: `screen-outlet.ts`'s `DESCRIPTOR_EDIT_PAGES` renders the editor when the form-page route carries an id, the create page otherwise; `navigation.ts`'s `CREATE_ONLY_FORMS` lists forms with no editor.
  - Save routes and handlers: `Api/Router.cls` `/<entity>/form`, `/name`, `POST`, `PUT /:id`; `Area/<Area>/*Save.cls`/`*Rules.cls`. Form pages: `ui/src/app/areas/<area>/*-form.page.ts`/`*-form.store.ts`; `shell/classic-link-card.ts`.
  - `_components.scss` holds the toast lift above the form bar and the form-page flex rule that keeps a tall form's Save/Cancel bar on screen.
- **Bundle budget:** the build warns at 1467kB (measured 1,397,013 bytes); 1500kB is the owner's lazy-load line, so a large editor may need lazy loading.

## UX & Interaction Patterns

- **Form-page:** classic field order, sticky Save/Cancel form bar, inline validation on blur and Save. A failed Save focuses the error summary (`role="alert"`) linking to each field, then the first invalid field, opening its tab. Required fields carry `aria-required` and the asterisk legend.
- **Saving and leaving:** an edit route stays open and shows "Saved" (`role="status"`). Unsaved changes ask "Leave without saving?"; agent navigation waits for the same answer (AD-11).
- **Toasts:** a change toast carries "Open in <list>", opening the entity's **list** with the row selected, and is hidden only while that list is open — so a change made on an editor still offers its row in the list.
- **Destructive row actions** use the typed-name confirmation; a self-protected action is drawn disabled with its reason.
- **Stores:** framework-free stores mirrored into signals, zoneless, OnPush (AD-19).
- **Structural a11y gate:** `ui/browser/a11y-structural-invariants.browser-spec.mjs` fails CI on any unnamed input, a control narrower than its minimum, overflow, or page-level horizontal scroll. New editors get no baseline allowance.
- New user-facing strings go in `ui/src/app/core/strings.ts` and EXPERIENCE.md Fixed strings (9.1 added the service-account refusal, user-editor labels, the tab error-count names and its suggested prompts).

## Cross-Story Dependencies

- 9.1 and 9.2 (done) set the tab, validation, error-summary, unsaved-changes, edit-Save, refusal-copy and suggested-prompt patterns that 9.3–9.8 reuse.
- 9.8 depends on 9.7's shared task model.
- 9.9 depends on the fate of every other story and ships the reduced service and LDAP/Kerberos forms that Epic 16 (16.13, 16.14) later replaces.
- Builds on Epic 7's operation, screen-action route and self-protection predicates; Epic 8's create forms, Save routes, `privilegedGrantEffect` strings and absence fingerprint (each create opens this epic's editor); Epic 15's theme and structural a11y gate; Story 11.3's suggested-prompt contract.
- Story 14.7 owns the typed-name field for destructive proposals.
- Epic 10's 10.4/10.5 runs concurrently (slot B) and owns `Api/Definitions.cls`, `Kernel/Provider/**`, `Port/ProviderPort.cls`, `Kernel/AgentRules.cls`, `Kernel/Egress.cls`, `Kernel/State/Agent.cls` and their tests, `areas/agent/definition-form.*`, `shell/context-chip.ts`, `browser/definitions.browser-spec.mjs`, `README.md` — don't edit them. `Api/Error.cls`, `strings.ts` and EXPERIENCE.md Fixed-strings rows are append-only shared; `Screen/Tool/Registry.cls` and `ui/tools/strings.test.mjs` are contended, so keep edits minimal.
