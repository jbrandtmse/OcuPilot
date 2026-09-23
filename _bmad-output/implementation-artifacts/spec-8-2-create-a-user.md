---
title: 'Story 8.2: Create a user'
type: 'feature'
created: '2026-09-23'
status: 'in-progress'
review_loop_iteration: 0
baseline_revision: '97d3bad240a2fd996a7559833bc4c1799e970770'
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-8-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-8-1-create-a-web-application.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** A user cannot create an account from OcuPilot, and the create write kind 8.1 built cannot yet express one: `Security.User` creates by `POST` with a `{User, Password}` wrapper the port does not run or shape, and no shipped tool carries a secret to the proposal card. Separately, 8.1's web-application create copies a caller-supplied directory into `Path` against AD-21 (DW-1495, HIGH, floor-blocking), and neither of its callers names what choosing Unauthenticated does (DW-1489).

**Approach:** Ship `permissions.users.create` and a `permissions/users/edit` create form as two callers of one tool (AD-54, AD-55), teaching the port the vendor's POST wrapper and the card a create's masked password. Contain a WSGI/ASGI application's directory under one fixed root resolved at call time on both of 8.1's callers, and name the unauthenticated effect on the proposal card and at the form's authentication-method field.

## Boundaries & Constraints

**Always:**

- The password is a secret end to end (AD-3, AD-6, AD-35, Conventions > Secrets): declared once in `UserList.secretArguments`, never in the model's schema, a proposal's stored arguments or payload, a diff value, the ledger, screen context, a log line or any read; supplied on the screen once and at confirm on the card; masked, never pre-filled or echoed, `autocomplete="new-password"`, cleared from the store on success, reset and sign-out.
- Adding `%All`, any `%Admin_*` role, or a role that reaches one through nested roles or a resource it holds is refused inside the write path whatever the caller, by the prohibited set's existing escalation predicate (`Prohibited.GrantsPrivilege`/`RoleEscalates`), never by a client check. On the screen the refusal arrives as one AD-39 `detail.violations[]` row `{field:"Roles", code:"PROHIBITED.PRIVILEGEGRANT", reason}` whose `reason` is one server-authored sentence; the bootstrap read ships that same sentence for the picker's pre-mark.
- Both user-create callers resolve one tool class for endpoint, request type, settable fields, payload composition, validation and port. The screen evaluates the prohibited set over the caller's fields before the port and merges the password only after that verdict, as `Confirm.WithSecrets` does.
- Every field sentence is authored once in `Api/Error.cls` and ships with the bootstrap read. Every visible word is `STRINGS.<key>`, and each new key has an EXPERIENCE.md Fixed strings row.
- DW-1495: `WSGIAppLocation` is a single directory name matching `^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$` that contains no literal `..`. It resolves under the fixed root `##class(%File).NormalizeDirectory("wsgi", $System.Util.ManagerDirectory())`, computed on every call and never cached (`/durable/iris/mgr/wsgi/` on this build). The check is post-normalization prefix containment that keeps the trailing separator and refuses the root itself. The sent `WSGIAppLocation` and `Path` are the resolved directory, never the caller's text, and both callers pass one validation.

**Never:**

- Never edit `Kernel/Proposal/Confirm.cls` (no edit is needed), `Kernel/Restraint.cls`, `Port/LogSourcePort.cls`, `Install/Smoke.cls`, `ui/src/app/areas/{tasks,logs}/**`.
- Never create a directory from OcuPilot, and never accept an absolute or multi-segment location. Arbitrary locations stay a classic-portal action.
- Never prohibit an unauthenticated web application (DW-1489, owner ruling (b)).
- No Epic 9 work: `permissions/users/edit/:id` redraws the create form with the created values, as 8.1's does. Story 9.1's editor takes it over, and until then re-saving there is refused because the name is taken.
- No user field outside the acceptance criterion's set (name, password, full name, roles, expiry, startup namespace, startup routine). `EscalationRoles` is excluded from the create tool's schema and payload.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Create through the screen | `POST /api/ocupilot/users` with a free `Name`, a policy-conforming `Password`, and optional `FullName`, `ExpirationDate`, `NameSpace`, `Routine` and non-privileged `Roles` | 201; the port sends `POST Security.User?name=<Name>` with body `{User:{…}, Password}`; the client publishes `{kind:'changed', type:'user', scope:'instance', id, action:'created'}` and replaces the route with `permissions/users/edit/<id>`; the password field is empty and captioned `STRINGS.formSecretStored` | No error expected |
| Create through the agent | `permissions.users.create` minted without a password, then confirmed on the card with one | The diff is every supplied field plus one `Password` row masked on both sides, and `unchangedCount` is 0. Confirm matches the absence fingerprint and posts the wrapped body; the ledger names every sent field except `Password`; there is a marker and a `created` event | No error expected |
| Password supplied by the model | `Password` among the mint arguments | Mint refuses 400: a secret field is never accepted from the agent (`Mint.cls:141`) | No proposal stored |
| Privileged role, either caller | `Roles` contains `%All`, `%Admin_Secure`, or a role whose nested roles or resources reach one | Screen: 422 with the Roles violation row, no port call. Agent: minted, then refused 403 `PROHIBITED.PRIVILEGEGRANT` inside the transition | Nothing is created |
| Name taken | The name exists in any case (`Security.Users` keys on `NameLowerCase`) | Screen: a `USER.NAME.TAKEN` violation on Name (also answered on blur by `GET /users/name`). Mint: 400 `TOOL.ARGUMENTS`. Taken after the mint: 409 `PROPOSAL.TARGETCHANGED` | The vendor POST is never reached |
| Field rules | Name empty, over 160 characters, containing a control character or `@`; password empty or failing `Security.System.PasswordPattern`; `ExpirationDate` not a real `YYYY-MM-DD`; `NameSpace` not a namespace; `Routine` without `NameSpace` or over 64 characters; a role that does not exist | One `USER.<FIELD>.<RULE>` violation per failing field. The same `Validate` runs as the tool's `ArgumentProblem` at mint. Everything the vendor's post-create `Modify` reads is validated first, because the vendor creates the account before it applies the fields | The banner takes focus, then the first invalid field |
| DW-1495 location, both callers | `WSGIAppLocation` of `..`, `/tmp/ocupilotprobe`, or `../wsgiprobe` | Screen: a `WEBAPP.WSGIAPPLOCATION.SHAPE` violation. Mint: 400 `TOOL.ARGUMENTS` | No application is created |
| DW-1495 valid location | `WSGIAppLocation: "probeapp"` | The body carries `WSGIAppLocation` and `Path` as `<root>probeapp/`, resolved at the call, and the form shows that path read-only | Unresolvable at confirm: both keys are dropped, never passed through |
| DW-1489 | A web-application create whose `AutheEnabled` includes Unauthenticated (bit 64) | The proposal row carries `consequence: "WEBAPP.UNAUTHENTICATED"` and the card shows `STRINGS.webAppUnauthenticatedEffect`; the form shows the same string at the authentication-method field while Unauthenticated is checked | Not refused |

</intent-contract>

## Code Map

**Contention (Epic 7 on slot A).** Before editing any file marked ⚠, read Epic 7's pushed version with `git show origin/OCU-1-epic7:<path>`, keep off its hunks, and restructure nothing it added. `Kernel/Proposal/Confirm.cls` needs no edit. `Kernel/Proposal/Mint.cls` and `Kernel/State/Propose.cls` are not in Epic 7's diff.

### Server: the write kind and the prohibited set

- `src/OcuPilot/Screen/Tool/UserUpdate.cls` -- the precedent to copy: `ROLESARGUMENT` :45, `SettableFields` :70, `InputSchema` adding `Roles` :94, `PrivilegePairs` with its `$ListFind` guard.
- `src/OcuPilot/Screen/Tool/WebAppCreate.cls` -- the create-tool shape: `CREATES`, `CHANGEACTION`, `PERMITTEDFIELDS` :62, `DerivedFields` :117-125 (copies `WSGIAppLocation` into `Path` verbatim, which is DW-1495), `ArgumentProblem` :131.
- ⚠ `src/OcuPilot/Screen/Tool/Write.cls` -- `READTYPE` :57, `WRITETYPE` :62, `CREATES` :141, `SecretArguments` :366 (reads the descriptor), `FieldRows` :384 (skips secrets), `ArgumentProblem` :568. **No edit needed.** Epic 7 adds `SCREENACTIONS` at :125 and methods at :178.
- `src/OcuPilot/Kernel/Proposal/Mint.cls` -- secret refusal :141; stored values :270-290 (`auditWarning` :282 is the precedent for a card warning); `Compose` :485; `CreatesOf` :551 (the `$ClassMethod` try-ask idiom).
- ⚠ `src/OcuPilot/Kernel/Proposal/Prohibited.cls`:
  - `PermittedCreateFields` :314 and `AlwaysProhibitedCreateFields` :328 have a `web-application` branch only.
  - `Prohibits` create dispatch :405-412.
  - `Created` :504 has no per-type step.
  - `User` :662; `GrantsPrivilege` :939 (a delta against the live roles); `RoleEscalates` :1010; `IsPrivilegedRole` :1092.
  - `PRIVILEGEGRANT` :72; its agent-worded reason :214.
  - Epic 7's hunks: the `SERVINGPATHREASON` parameter near :47-57, `ReasonFor` :209, `WebApplication` :447.
- `src/OcuPilot/Kernel/EntityRef.cls` `IDRULES` :59 -- already has `user:foldcase`, so no edit.
- ⚠ `src/OcuPilot/Port/AdminPort.cls`:
  - `MUTATINGTYPES` :166 -- Epic 7 appends `WebApp.App/DELETE` on the same line.
  - `HttpMethodFor` :818.
  - `EndpointType` needs `TYPE<suffix>` on the class.
  - `ImplementsRead` :852-858 -- Epic 7 adds `If pSuffix = "DELETE" Set tRunner = "RunDelete"` next to the `$Case`.
  - Vendor field refusals are mapped onto `detail.violations` in `Fail`.
- `src/OcuPilot/Kernel/State/Propose.cls` -- `auditWarning` :221, :608, :651 is the column-plus-wire precedent for `consequence`.

### Server: secrets declaration and validation

- `src/OcuPilot/Screen/Tool/Classification.cls` :53-72 -- the `permissions.users.update` entry. The grammar reserves keys and has no authored-row facility.
- `ui/tools/field-lists.mjs` -- `classify` :188, `buildToolFields` :256. Emits `ToolFields.cls`.
- ⚠ `src/OcuPilot/Screen/Registry.cls`:
  - `ConfirmChannelProblem` ~:1981-2030 refuses a `secretArguments` name that is neither an ordinary settable row nor a read field.
  - `DeclaredNames` :2177.
  - `ToolFieldRows` :2392-2429, whose flag 1 is ordinary-literal only.
  - Epic 7's hunks: ~:296 and a 73-line insert in `FingerprintSubjectProblem` near :2141-2160.
- ⚠ `ui/tools/screen-mirror.mjs` :436-470 -- the client twin of that check.

### Server: screen routes (8.1 precedent)

- `src/OcuPilot/Area/WebApp/Create.cls`:
  - `HandleCreate` :92, `Perform` :142 (the prohibited call is :182, the fault :189).
  - `Validate` :223, with the `WSGIAppLocation` rules :257 and :262.
  - `CallerFields` :299, `RenderViolations` :407, `Gate` :420 (returns `pRefused`), `PortClass` :71.
- `src/OcuPilot/Area/WebApp/FormRules.cls` -- `HandleForm` :82, `HandleName` :114, `Taken` :149 (a live read through the tool's port), `Rules` :300.
- `src/OcuPilot/Api/StaticHandler.cls` -- the containment idiom: `..` rejection :158, `NormalizeFilename` :174, `IsInsideRoot` :198-203. `NormalizeDirectory` resolves `..` lexically and ignores the base for absolute input (probed).
- ⚠ `src/OcuPilot/Api/Router.cls` -- 8.1's routes :94-96 and handlers :263-279. Epic 7 inserts `POST /screens/:screen/action` near :93 and its handler after :250.
- `src/OcuPilot/Api/Error.cls` -- the `WEBAPP.*` codes :1500-1583 and `ReasonForViolation` :1041. `REASONACCOUNTPASSWORDPOLICY` :1254 is 15.1's sentence.
- `src/OcuPilot/Screen/Descriptor/UserList.cls` -- `primaryAction` and `table.emptyNextKey`/`emptyAgentKey`; `Screen/Registry.cls` enforces the pair once a descriptor is write-capable.
- `src/OcuPilot/Screen/Descriptor/WebAppForm.cls` -- the `form-page` declaration to copy.

### Client

- `ui/src/app/areas/web-applications/create-form.{page,store}.ts` (679 and 642 lines) and `web-app-actions.ts` -- copy their shape; do not extract a base.
  - Generic parts: page 73-92, 345-375, 399-454, 569-678; store 196-353, 447-510, 547-591.
  - `WSGIAppLocation` field block; authentication `fieldset` at page 314-330.
- `ui/src/app/shell/change-password-dialog.ts` 97-154 and 232-237 -- the reveal toggle, `.ocu-reveal-toggle`, `accountShowPassword`/`accountHidePassword`.
- `ui/src/app/areas/agent/definition-form.page.ts` 270-297 -- a store-held secret with the `formSecretStored` caption.
- `ui/src/app/core/navigation.ts` -- `createFormFor` :188, `CREATE_ONLY_FORMS` :200. `ui/src/app/shell/screen-outlet.ts` `DESCRIPTOR_PAGES` :87-96. `ui/src/app/app.ts` -- `WebAppActions` :227, sign-out teardown :469-498.
- ⚠ `ui/src/app/core/proposal-view.ts` -- `maskedRow` :278, `payloadSecrets` :341 (keeps the declared secrets a diff row names).
- ⚠ `ui/src/app/shell/proposal-card.ts` -- masked inputs :190-206, the `auditWarning` line :212-215.
- ⚠ `ui/src/app/core/strings.ts` -- 8.1's block ends :1344 before `} as const;` :1347. Epic 7 appends at the same point.
- ⚠ EXPERIENCE.md Fixed strings table -- rows :252-396. Epic 7 inserts after :394.
- `ui/browser/web-applications-create.browser-spec.mjs` -- the harness (`signedInAt`, `removeProbeApplications` via `docker exec`).
- `ui/src/app/areas/web-applications/create-form.store.spec.ts` -- the store-spec harness.

## Tasks & Acceptance

**Execution:**

*Port and secret plumbing:*

- `src/OcuPilot/Port/AdminPort.cls`:
  - Append `Security.User/POST` to `MUTATINGTYPES`.
  - Map `POST` to `RunPost` in `ImplementsRead`, on its own line beside Epic 7's `DELETE` line.
  - Add `Parameter WRAPPEDTYPES = "Security.User/POST=User:Password"`, applied in `Invoke` before `ValidateRequest`: every key except the listed outer ones moves under the wrapper key, and a missing outer key stays missing. `Fail` strips a leading `User.` from a vendor `params[0]` for a wrapped type.
  - First confirm on the instance that the class declares `TYPEPOST`, and that `RunPost` is defined or `Run` is overridden.
  - Rationale: the whole system sees `Security.User`'s derived flat field list, and the vendor's wrapper is a wire fact, which AD-27 confines to the port.
- `src/OcuPilot/Screen/Tool/Classification.cls`, `ui/tools/field-lists.mjs`, `ui/tools/field-lists.test.mjs`:
  - Add an `authored` key to the entry grammar, an object mapping a top-level name the endpoint's wrapper carries and the template does not to `secret`. `secret` is the only accepted class. A name that collides with a derived path is refused.
  - `buildToolFields` emits it as `{path, shape:"literal", templateType:"string", class:"secret", authored:true}`.
  - Add the `permissions.users.create` entry: `Security.User` classified as the update entry is, with `authored: {"Password": "secret"}`.
  - Regenerate `ToolFields.cls` with `node tools/field-lists.mjs`.
  - Rationale: this is AD-3's "the write tool authors [wrapper fields] as secret fields of its own", stated where the generator can check it.
- `src/OcuPilot/Screen/Registry.cls` (`DeclaredNames`/`ConfirmChannelProblem`) and `ui/tools/screen-mirror.mjs` with its test:
  - Accept a `secretArguments` name that is a top-level `secret` row of the screen's tools, in addition to the two sources already accepted.
  - Pin both directions: a top-level secret row passes, and an unknown name is still refused.
  - Rationale: today only ordinary rows qualify, so neither 8.5's derived `PrivateKeyPassword` nor this authored `Password` could be declared.
- `src/OcuPilot/Screen/Descriptor/UserList.cls`:
  - Set `primaryAction.id` to `"create"`.
  - Replace `emptyNextKey` with `emptyAgentKey: "userListEmptyAgent"`.
  - Add `secretArguments: ["Password"]`.
  - This also opens the update tool's confirm channel to `Password`. The vendor's PUT schema refuses the key, and the card never asks for it, because no update diff names it (DW-1227's narrowing).

*The tool and the kernel:*

- `src/OcuPilot/Screen/Tool/UserCreate.cls` -- new, on `UserUpdate`'s shape:
  - `TOOLNAME = "permissions.users.create"`, `DESCRIPTORCLASS = OcuPilot.Screen.Descriptor.UserList`, `CREATES = 1`, `CHANGEACTION = "created"`, `WRITETYPE = "POST"`, `Endpoint() = "Security.User"`.
  - `PERMITTEDFIELDS = "ExpirationDate,FullName,NameSpace,Routine"` plus the authored `Roles` array (`InputSchema` names the refused privileged roles); `ExcludedFields` returns `EscalationRoles`.
  - `ArgumentProblem` → `UserCreateRules.Validate`.
  - `ComposedSecrets()` returns `$ListBuild("Password")`.
  - `PrivilegePairs` is copied from `UserUpdate`.
- `src/OcuPilot/Kernel/Proposal/Mint.cls`:
  - For a create, `Compose` appends one row `{field, before:"", after:""}` per name the tool's `ComposedSecrets()` answers, asked with the `CreatesOf` try idiom. A tool that cannot answer adds none. `unchangedCount` stays 0.
  - Store `tValues("consequence")` from the tool's `Consequence(payload)`, asked the same way.
- `src/OcuPilot/Kernel/State/Propose.cls` -- add a `Consequence` `%String` property carried on the proposal wire beside `auditWarning`.
  - No `SCHEMAVERSION` move: every pre-existing row reads `""`, which is the Conventions' safe-default case. Record that reasoning at the property.
- `src/OcuPilot/Kernel/Proposal/Prohibited.cls`:
  - Add `user` branches to `PermittedCreateFields` (`ExpirationDate,FullName,NameSpace,Routine,Roles`) and `AlwaysProhibitedCreateFields` (`EscalationRoles`).
  - Add a `user` step in `Created` that refuses `PRIVILEGEGRANT` when `GrantsPrivilege(payload, {})` (every role counts as new).
  - Add a public `RoleGrantsAdministrativePrivilege(pRole) As %Boolean` over `RoleEscalates`, for the bootstrap read's pre-mark.
  - Stay off Epic 7's hunks.

*The screen routes:*

- `src/OcuPilot/Area/Permissions/UserCreate.cls` -- new, mirroring `Area/WebApp/Create.cls`: `HandleCreate`, `Perform`, `Gate`, `CallerFields`, `PortClass`.
  - Prohibited verdict over `CallerFields` minus the declared secrets. A `PRIVILEGEGRANT` becomes the 422 violation row on `Roles` with `REASONUSERROLESPRIVILEGED`, not a 403 banner.
  - Then `Validate`, then the password is set on the body, then the port.
  - Nothing logs the request body.
- `src/OcuPilot/Area/Permissions/UserCreateRules.cls` -- new:
  - `Validate`, the one rule set both callers use.
  - `HandleForm` (`GET /users/form`) answers: required fields, maximum lengths, every rule sentence, `roles: [{name, privileged}]` (listed through the tool's port, `Security.Role` `LIST`, each marked by `RoleGrantsAdministrativePrivilege`) and the Roles sentence.
  - `HandleName` (`GET /users/name`), and `Taken`, a live read through the tool's port.
  - The password rule reads `PasswordPattern` in `%SYS` (AD-16) and matches with `?@`.
- `src/OcuPilot/Api/Router.cls` -- add `GET /users/form`, `GET /users/name` and `POST /users` with thin `Call=` wrappers after 8.1's block, the sub-resources before `POST /users`.
- `src/OcuPilot/Api/Error.cls` -- add, beside the `WEBAPP.*` block:
  - a `USER.VALIDATION` 422 envelope code shaped like `WEBAPPVALIDATION` :1500, with its reason;
  - the `USER.<FIELD>.<RULE>` codes with their `REASON*` sentences, and `REASONUSERROLESPRIVILEGED`;
  - `WEBAPP.WSGIAPPLOCATION.SHAPE` and its sentence.
  - Register all of them in `ReasonForViolation` and `ViolationCodes`.
- `src/OcuPilot/Screen/Descriptor/UserForm.cls` -- new `form-page` copying `WebAppForm`:
  - `route: "permissions/users/edit"`, `area: "permissions"`, `labelKey: "userFormLabel"`, `sideBarPosition: 0`.
  - `entityType: "user"`, the `UserList` privileges, `classicPage: "%CSP.UI.Portal.User"`, `toolIdentifier: "permissions.userform"`.
  - `context.secretFields: ["Password"]`.

*DW-1495 and DW-1489 on 8.1's create:*

- `src/OcuPilot/Area/WebApp/Location.cls` -- new:
  - `Root()` computes the fixed root on every call and returns `""` on failure.
  - `Resolve(pName, Output pPath) As %Boolean` applies the pattern, the literal `..` refusal, `NormalizeDirectory` under the root, then `StaticHandler`'s prefix idiom with the trailing separator kept and the root itself refused.
- `src/OcuPilot/Area/WebApp/Create.cls` `Validate` -- replace the non-empty-only rule with `Location.Resolve`, giving `WEBAPP.WSGIAPPLOCATION.SHAPE`. This reaches the agent path through `WebAppCreate.ArgumentProblem`.
- `src/OcuPilot/Screen/Tool/WebAppCreate.cls`:
  - `DerivedFields` sets `WSGIAppLocation` and `Path` to the resolved directory, or removes both.
  - `Consequence(payload)` returns `WEBAPP.UNAUTHENTICATED` when `AutheEnabled`'s bit 64 is set.
  - `InputSchema` describes `WSGIAppLocation` as one directory name.
- `src/OcuPilot/Area/WebApp/FormRules.cls` -- the bootstrap adds `wsgiRoot` (from `Location.Root()`) and the location rule sentence.

*Client:*

- `ui/src/app/areas/permissions/user-create-form.{page,store}.ts` and `user-actions.ts` -- new, copying 8.1's shape with the `ocu-user-` prefix. Fields in the classic order: Name, Full name, Password (masked, reveal toggle, `autocomplete="new-password"`), Account expiration date (`type="date"`), Startup namespace, Startup tag^routine, Roles (a checkbox fieldset from the bootstrap's `roles`).
  - A privileged role is `disabled`, with the bootstrap's sentence as its described-by text.
  - The store clears the password on a successful save, on `reset()` and before `retainAcrossRouteReplacement`.
  - Reuse `.ocu-reveal-toggle` and `.ocu-form-authe`. Add no SCSS.
- `ui/src/app/core/navigation.ts` -- add `UserForm` to `CREATE_ONLY_FORMS`.
- `ui/src/app/shell/screen-outlet.ts` -- the `DESCRIPTOR_PAGES` entry.
- `ui/src/app/app.ts` -- inject `UserActions` beside :227, and reset the user form store in the sign-out teardown.
- `ui/src/app/areas/web-applications/create-form.page.ts`:
  - Under Application directory, a read-only line `STRINGS.webAppFormPythonDirectoryResolved` shows `wsgiRoot` plus the typed name. It is display only; the server resolves.
  - At the authentication fieldset, `STRINGS.webAppUnauthenticatedEffect` appears while Unauthenticated is checked.
- `ui/src/app/core/proposal-view.ts` and `ui/src/app/shell/proposal-card.ts` -- carry `consequence`, and render `STRINGS.webAppUnauthenticatedEffect` for `WEBAPP.UNAUTHENTICATED` beside the `auditWarning` line.
- `ui/src/app/core/strings.ts` and EXPERIENCE.md, **append only**, after 8.1's block and rows:
  - Form and list: `userFormLabel` ('New user'), `userFormPassword` ('Password'), `userFormExpiry` ('Account expiration date'), `userFormNamespace` ('Startup namespace'), `userFormRoutine` ('Startup tag^routine'), `userFormRefusedAction` ('create a user'), `userListEmptyAgent`.
  - The two ruled rows: `webAppFormPythonDirectoryResolved` (DW-1495) and `webAppUnauthenticatedEffect` (DW-1489).
  - Reuse a key wherever its value already exists.
- `ui/src/app/core/screens.generated.ts` -- regenerate; never hand-merge.

*Tests and rosters:*

- `src/OcuPilot/Test/UserCreate.cls` and `src/OcuPilot/Test/UserCreateFixture.cls` -- new; the fixture overrides `PortClass` as `CreateFixture` does.
  - The schema has no `Password` and no `EscalationRoles`, and the permitted set equals `Prohibited.PermittedCreateFields("user")`.
  - Every field rule is checked on both callers, and the screen and the tool send one body.
  - A privileged role is refused on both callers, including a seeded row inside the transition.
  - The password is absent from stored arguments, payload, diff values and ledger names.
  - The port wraps and unwraps.
- `src/OcuPilot/Test/UserCreateWire.cls` -- new, over the wire on the throwaway:
  - `POST /users` creates the account.
  - Neither the Users read nor `GET Security.User` carries any key naming the password.
  - Cleanup by exact probe name.
- `src/OcuPilot/Test/WebAppLocation.cls` -- new:
  - DW-1495's `..`, absolute and sibling inputs are refused on the screen route and on `webapp.list.create`, and a valid name yields `<root><name>/` in both bodies.
  - A direct leg pins the prefix check with a normalized sibling (`<mgr>/wsgiprobe/`).
  - DW-1489: the mint stores `consequence` for bit 64 and `""` otherwise.
- `ui/src/app/areas/permissions/user-create-form.store.spec.ts` -- new, on the 8.1 harness.
- `ui/browser/users-create.browser-spec.mjs` -- new. `resetRememberedState`, and exact-name cleanup with `Security.Users.Delete`.
- `ui/browser/web-applications-create.browser-spec.mjs` -- add the resolved-path legs and the unauthenticated-effect legs.
- Update the rosters that redden: `ui/tools/navigation.test.mjs` 133-176 and 250-262, `ui/tools/proposal-view.test.mjs` (the `consequence` field), ⚠ `ui/src/app/shell/proposal-card.spec.ts` (the consequence line), `strings.test.mjs` (via EXPERIENCE.md), ⚠ `Test/{SurfaceCoverage,EndpointCoverage,ReadTool,ToolRoundTrip,Prohibited,ToolWrite,Descriptor}.cls`, and `scripts/ci-throwaway.sh` with `ui/tools/ci.test.mjs` only if a new class declares an arming parameter.

*Orchestrator rulings 2026-09-23 (from Epic 7's Story 7.2), apply before review:*

- [ ] [Lead] `userListEmptyAgent` is exactly `'create a user'` in `strings.ts` (it is `'create a user account'` now), and its EXPERIENCE.md Fixed strings row quotes the same value -- Epic 7's 7.2 adopts the same key and value.
- [ ] [Lead] This story owns `Prohibited.ReasonFor`'s `PRIVILEGEGRANT` sentence: make it caller-neutral (it reads "not something the agent can propose", and a person now meets it on the Roles field -- DW-1496's reopen condition), and use that one published sentence for the Roles violation and the picker's pre-mark rather than a second `REASONUSERROLESPRIVILEGED` (AD-53: a refusal is written once). Do not touch the CURRENTUSER, SYSTEMACCOUNT, SERVICEACCOUNT or LASTALLHOLDER reasons. `Prohibited.cls` is contended: read Epic 7's version first and stay off its hunks.
- [ ] [Lead] The `secretArguments` widening in `Screen/Registry.cls`, `ui/tools/screen-mirror.mjs` and `ui/tools/screen-mirror.test.mjs` stays self-contained (no unrelated edits to those three files): Epic 7 ports it byte-for-byte. `Screen/Descriptor/UserList.cls` is contended; this story owns its `primaryAction`, `emptyAgentKey` and `secretArguments` lines, Epic 7 adds `rowActions`.

*Orchestrator rulings on the implement halt, 2026-09-23:*

- [ ] [Lead] `src/OcuPilot/Test/PortFixture.cls` joins the contended-edit discipline: read `git show origin/OCU-1-epic7:src/OcuPilot/Test/PortFixture.cls` first, then append `Security.User/POST` to its `MUTATINGTYPES` line and change nothing else on that line (Epic 7 appends `WebApp.App/DELETE` there; the merge keeps both). `ToolWrite` goes green 20/20; its roster assertion is not weakened.
- [ ] [Lead] The bundle budget, per the owner's standing policy on DW-1166 (`23f8f3b`: re-base the warning to about 5% above the measured total at each epic close; 1,600 kB raw is the hard stop): set `ui/angular.json`'s initial `maximumWarning` to `1185kB` (the Angular parser counts 1 kB as 1,000 bytes; 1,185,000 is 5.05% above the measured 1,128,027 B), and the literal pinned in `ui/tools/angular-json.test.mjs` to the same, in the same change, replacing that file's budget-history comment sentence with the current figure and its reason rather than appending a paragraph. `maximumError` stays `1600kB`. `ui/angular.json` goes under `footprint_extensions:`. Re-measure after the last edit; if the emitted total has grown past 1,185,000 B, re-base to about 5% above the new measurement and say so in `## Auto Run Result`.

**Acceptance Criteria:**

- **AC1.** Given the Users list's Create, when the create form renders, then it captures name, password, full name, expiry, startup namespace, startup routine and roles, in that order, under the `form-page` contract.
- **AC2.** Given the password, when it is entered and saved, then:
  - it is sent once, in a masked field that is never pre-filled or echoed;
  - after the save the field is empty and captioned;
  - no read, stored proposal, ledger row or screen context carries it;
  - on the agent path it is supplied only on the card, beside a diff row masked on both sides.
- **AC3.** Given roles that include `%All`, an `%Admin_*` role, or one reaching either through its nested roles or resources, when saved by either caller, then the instance refuses the grant.
  - On the screen, the server's sentence lands on the Roles field.
  - The picker pre-marks those roles unavailable with the same sentence.
- **AC4 (Integration).** Given a valid Save, when the server accepts it, then:
  - the user exists with the sent fields;
  - the route becomes `permissions/users/edit/<id>`;
  - `STRINGS.formSaved` shows;
  - the Users list, the change bus's consumer, shows the account without a refresh.
- **AC5.** Given `permissions.users.create`, when the agent proposes a create and the user confirms it with a password, then the write is marked, a ledger row names the sent fields without the password, and a `created` event is published.
- **AC6 (DW-1495).** Given either web-application create caller, when `WSGIAppLocation` is `..`, an absolute path or a sibling escape, then it is refused.
  - A valid name is sent as its directory under the fixed root, computed at the call.
  - The form shows that path read-only.
  - Removing containment reddens the pinning test on both callers.
- **AC7 (DW-1489).** Given a web-application create choosing Unauthenticated, when it is proposed or filled in, then the proposal card and the form's authentication-method field state the unauthenticated effect, and the create is not refused.

## Spec Change Log

- 2026-09-23, lead: implement halted on two gates; both ruled by the orchestrator and added as `[Lead]` tasks with the three Story 7.2 rulings; status reset to `in-progress` with the implementation still uncommitted in the tree.

- 2026-09-23, spec gate: AD-21 amended with the WSGI directory rule this spec proposed; the Design Notes heading says so.

## Review Triage Log

## Design Notes

**Governing ADs:** AD-2, AD-3, AD-4, AD-5, AD-6, AD-8, AD-10, AD-12, AD-13, AD-14, AD-15, AD-16, AD-19, AD-21, AD-27, AD-34, AD-35, AD-39, AD-40, AD-41, AD-44, AD-52, AD-54, AD-55.

**AD-21's fixed WSGI root (written into AD-21's Rule at the spec gate, 2026-09-23).** A web application's Python directory is a single name resolved under `<ManagerDirectory>wsgi/` at call time, and the vendor's `Path` is set to the resolved directory by the tool, never by a caller. The Manager Directory was chosen because it is AD-21's own runtime base and is durable on this image. The alternative, `<InstallDirectory>mgr/python`, is the non-durable install tree and the `irispip` target (inference). `DataDirectory()` was rejected to keep one base. No shipped application on slot B uses WSGI. Epic 9.2's editor inherits this.

**What the instance settled.**

- `Security.User` creates by `POST ?name=` with body `{User:{…}, Password}`, and both keys are required. `PUT` refuses an absent user with 404, so it is not an upsert.
- A duplicate `POST` answers 500 (#837). The absence fingerprint is kept anyway, per AD-54.
- The vendor calls `Create` with the password and then `Modify` with the fields, which is why every field `Modify` reads is validated first.
- `PasswordPattern` is `3.255ANP`.
- The classic page `%CSP.UI.Portal.User` orders Name, Full Name, Comment, Password, …, Expiration Date, Startup Namespace, Startup Tag^Routine, and assigns Roles on a separate tab after save.
- The omitted fields belong to Story 9.1. There is no confirm-password field: the reveal toggle serves, and a match rule would be a client-authored sentence.

**Known carry-over.** DW-1493, now escalated, applies here too: the agent's create posts the canonical lowercased name, while the screen posts the typed one. The fix is in `Confirm.Transition`, which waits for Epic 7's merge.

**Consumes:** Story 8.1's create kind, `form-page` contract and `CreateFixture` seam; Story 5.x's `UserUpdate`, escalation predicate, confirm channel and card masking; Story 15.1's reveal toggle.

**Consumed-by:** Story 8.3 (role create: `RoleGrantsAdministrativePrivilege`, the roles fieldset); Story 8.5 (the relaxed secret-row declaration); Story 9.1 (takes over `permissions/users/edit/:id` and reuses `UserCreateRules`); Story 9.2 (`Location`); any later tool with a kernel-owned warning (`consequence`).

**Integration ACs:** AC4 (the Users list re-reads on the change bus) and AC7 (the proposal card renders the kernel's `consequence`).

## Verification

Stateful checks run on slot B's throwaway, brought up after the last edit: `sh scripts/ci-throwaway.sh up --dir /tmp/ocupilot-b-ci --project ocupilot-b-ci --web 52777 --super 1976`. Every IRIS MCP call carries `server: "ocupilot-slot-b"`. Run one test class per call, and wait for each run to land before the next.

**Targeted (loop):**

- `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/` -- expected: the bundle under test is the one just built.
- `cd ui && OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci node --test --test-concurrency=1 browser/users-create.browser-spec.mjs browser/web-applications-create.browser-spec.mjs` -- expected: all pass.
- `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class <C>`, once per class, for `OcuPilot.Test.UserCreate`, `UserCreateWire`, `WebAppLocation`, `ProposalCreate`, `WebAppCreate`, `Prohibited`, `ToolWrite`, `SurfaceCoverage`, `EndpointCoverage`, `ReadTool`, `DerivedFields` and `Descriptor` -- expected: 0 failures each.
- `cd ui && npm run test:tools && npm run test:components` -- expected: 0 failures.
- `cd ui && node tools/field-lists.mjs --check && node tools/screen-mirror.mjs --check && node tools/client-lint.mjs && node tools/browser-reset.mjs` -- expected: no drift.
- `uv run scripts/check-objectscript.py <changed paths>` and `bash scripts/lint-docs.sh` -- expected: clean.

**Once, before `dev_complete`:**

- The full ObjectScript sweep on a fresh throwaway, one class at a time, with the totals checked against `%UnitTest_Result` -- expected: 0 failures and a non-zero count.
- `cd ui && npm run build && npm test` -- expected: green.
- `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS` -- expected: all pass, with a non-zero count. The smoke runs on the throwaway because slot B mounts source from outside this worktree.
- The full browser suite is **not** run locally: CI's `browser` job runs it on a fresh throwaway (Rule 29; DW-1447 found the local suite non-idempotent).

**Pinning tests and mutations (Rule 19; the implementer records what was observed):**

| AC | Pinning test | Mutation |
|---|---|---|
| AC1 | `users-create.browser-spec.mjs` field-order leg | Swap Password and Full name in the page |
| AC2 | `UserCreate.cls` secret-absence test; the browser no-echo leg | Store `Password` in `Mint.StoredArguments`; bind the input's `[value]` to the buffer after save |
| AC3 | `UserCreate.cls` both-callers privileged test | Remove the `user` step from `Prohibited.Created` |
| AC4 | `user-create-form.store.spec.ts` change-event test | Drop the `ChangeBus.publish` call |
| AC5 | `UserCreate.cls` confirm test (the fixture port records the wrapped body) | Remove `Security.User/POST` from `WRAPPEDTYPES` |
| AC6 | `WebAppLocation.cls` both-callers test | Make `Location.Resolve` return 1 with the caller's text |
| AC7 | `WebAppLocation.cls` consequence test; `proposal-view.test.mjs` | Return `""` from `WebAppCreate.Consequence` |

Observed (implement stage, each applied to the checked-in file, recompiled with `cbk` or rebuilt and redeployed, observed red, reverted, tree byte-identical):

- mutation: swapped the Full name and Password blocks in `user-create-form.page.ts` → `users-create.browser-spec.mjs` AC1 red
- mutation: `Mint.StoredArguments` sets `Password` on the stored text → `UserCreate.TestThePasswordIsAbsentFromEveryStoredSurface` red
- mutation: the store keeps the password through a Save and the route replacement → `users-create.browser-spec.mjs` AC2 red (binding the page's `[value]` to a copy did not redden: the route replacement builds a new page)
- mutation: disabled the `user` step in `Prohibited.Created` → `UserCreate.TestAPrivilegedRoleIsRefusedOnBothCallers` red on the screen and the confirm, for `%All` and `%Manager`
- mutation: removed the `publishCreated()` call from `UserCreateForm.save()` → `user-create-form.store.spec.ts` change-event test red
- mutation: emptied `AdminPort.WRAPPEDTYPES` → `UserCreate.TestAConfirmedCreateIsMarkedAndItsBodyIsWrapped` red
- mutation: `Location.Resolve` returns 1 with the caller's text → `WebAppLocation.TestAnEscapingLocationIsRefusedOnBothCallers` red on the screen route and on `webapp.list.create` for all three inputs, and `TestAValidNameIsSentAsItsDirectoryUnderTheRootOnBothCallers` red on both bodies
- mutation: `WebAppCreate.Consequence` returns `""` → `WebAppLocation.TestTheUnauthenticatedConsequenceIsStoredAndNotRefused` red; deleting `consequence` from `toCardView` → `proposal-view.test.mjs` consequence test red
- mutation: dropped the `SecretRowNames` clause from `Registry.ConfirmChannelProblem` → `UserCreate.TestTheConfirmChannelAdmitsATopLevelSecretRowAndNothingElseNew` red; the same clause in `screen-mirror.mjs` → `screen-mirror.test.mjs` red (the Users list is refused)
- mutation: dropped the authored row's push in `field-lists.mjs` `classify` → `field-lists.test.mjs` authored-field test and the committed-output tests red

## Auto Run Result

Status: blocked
Blocking condition: intent gap: footprint src/OcuPilot/Test/PortFixture.cls (and a bundle-budget decision, item 2)

The implementation pass is complete and uncommitted in the worktree (45 tracked files changed, 18 new); review layers did not run. Two gates stay red, each needing a lead decision:

1. `OcuPilot.Test.ToolWrite` `TestEveryWriteToolsRequestTypeAgreesWithThePortsBodylessRoster` (19/20): it requires every `AdminPort.MUTATINGTYPES` pair in `Test/PortFixture.cls`'s override, and the spec's `Security.User/POST` is not there. `PortFixture.cls` is in Epic 7's diff (it appends `WebApp.App/DELETE` to the same line) and not in the spec. Recommended: authorize appending `Security.User/POST` to `PortFixture.MUTATINGTYPES`.
2. `ui/tools/build-output.test.mjs`: the initial bundle is 1,128,027 B against `maximumWarning` 1120kB (DW-371 gate; the build exits 0). Recommended: raise `ui/angular.json`'s `maximumWarning` and `angular-json.test.mjs`'s pinned literal together (e.g. 1200kB, under the 1600kB error), as the Epic 4 raise was done.

Verified on `ocupilot-b-ci` by the handoff pass, one class per call: UserCreate 9/9, UserCreateWire 5/5, WebAppLocation 4/4, and ProposalCreate, WebAppCreate, WebAppWire, Prohibited, SurfaceCoverage, EndpointCoverage, ReadTool, Descriptor, DerivedFields, ToolRoundTrip, UserUpdate, AgentViolation green; browser users-create 4/4 and web-applications-create 7/7 on a rebuilt bundle; `test:components` 841/841; `test:tools` 1323 pass, 1 fail (item 2); generators, `client-lint`, `check-objectscript` and `lint-docs` clean. Rule 19 mutations are recorded under `## Verification`. The full ObjectScript sweep has not run.

Deviations for review: the form orders Name, Full name, Password (the classic order the tasks give; AC1's sentence lists password first); the `USER.*` codes are registered in a new `UserViolationCodes`, since `ViolationCodes` is agent-only and pinned exactly by `AgentViolation`; `Test/Prohibited`'s reviewed-secret check excludes authored wrapper secrets; no `userFormPassword` key (`fieldPassword` already holds 'Password').

Resume: after the two rulings, apply them, set `status: in-review`, and re-dispatch; `baseline_revision` stays valid.

footprint_extensions: src/OcuPilot/Kernel/Proposal/Prohibited.cls, src/OcuPilot/Screen/Registry.cls, ui/tools/screen-mirror.mjs, ui/tools/screen-mirror.test.mjs, src/OcuPilot/Api/Router.cls, src/OcuPilot/Test/SurfaceCoverage.cls, src/OcuPilot/Test/EndpointCoverage.cls, src/OcuPilot/Test/ToolRoundTrip.cls, src/OcuPilot/Test/ReadTool.cls, src/OcuPilot/Test/Prohibited.cls, src/OcuPilot/Kernel/Proposal/Mint.cls, ui/src/app/core/proposal-view.ts, ui/src/app/shell/proposal-card.ts, ui/src/app/shell/proposal-card.spec.ts, src/OcuPilot/Port/AdminPort.cls (append), ui/src/app/core/strings.ts (append), EXPERIENCE.md Fixed strings (append)
