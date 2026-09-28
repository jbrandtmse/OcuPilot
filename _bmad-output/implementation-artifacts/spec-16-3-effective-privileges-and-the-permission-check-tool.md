---
title: 'Story 16.3: Effective privileges and the permission-check tool'
type: 'feature'
created: '2026-09-27'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-16-context.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** "Can this account do X?" today needs a manual trace through a user's roles, the roles those grant, and public permissions, across three screens. OcuPilot shows no account's effective privileges, and the agent cannot check one (FR-74, catalog PM-17 and PM-18). Separately, DW-1018: the Security area's pair union gates the whole Security rail item on the wallet and OAuth pairs. So a holder of the pairs that SSL/TLS, X.509, LDAP and Auditing need cannot open the area. Stock `%SecurityAdministrator`, which lacks `%Admin_Wallet`, is one such holder (measured).

**Approach:** AD-8's one composition, `Kernel.Shell.Effective`, answers everything. It is extended to also return the role closure and, for each permission letter, the role whose own grant it is.

- **Effective privileges tab.** The User editor gains a read-only tab that reads `GET /api/ocupilot/users/effective`. The route composes the account's roles with the Roles, Resources, Web applications, Databases and Services screens' own reads, each behind that screen's gate.
- **Permission check.** Two callers share one operation, which answers yes or no, names the granting role, and short-circuits on `%All`:
  - the read tool `permissions.privileges.check`;
  - a "Check permission" command-bar dialog on the Users and Roles lists and on the user and role editors.
- **DW-1018 (Option A, decided by the owner at the merge gate 2026-09-28).** The wallet and OAuth pairs move off the Security area and onto the 13 screens that need them, as `ownPrivileges`.

## Boundaries & Constraints

**Always:**

- **One composition (AD-8).** Every effective-privilege answer is `Effective.Read` plus `Effective.Compose`, run over one of two inputs:
  - the account's `Roles`, never its `EscalationRoles`;
  - or the single role being checked.

  `Compose` gains two additive members. The existing members keep their meaning, because Findings and Impact read them.
  - `roles`: `[{name, through}]` in closure order. `through` is the root role the entry was reached from, or `""` for a root.
  - `sources`: `{<resource>: {<letter>: <role whose own Resources grant it>}}`, with `""` for a public letter.
- **Measured on `ocupilot-ci` at plan time** (probe principals, since removed). `Compose` agrees with `$System.Security.CheckUserPermission` on:
  - a grant through a granted role;
  - a public permission;
  - an escalation-only role, which counts for nothing;
  - `%All` reached through a granted role, which holds every existing resource.

  User, role and resource names resolve case-insensitively. A resource that does not exist answers 0 for an account holding `%All` through a granted role, but 1 for `_SYSTEM`. The check therefore refuses a missing resource first.
- **As the caller (AD-8, AD-29).** Nothing is elevated. Each part is read through the owning screen's declared read, after that screen's pair gate (`Effective.Gate`, then `Screen.Read.Execute`):
  - Roles and Resources, inside `Effective.Read`;
  - Web applications, through `WebAppList`;
  - Databases, through `DatabaseList`, which needs `%Admin_Manage:USE`;
  - Services, through `ServiceList`.

  When a part cannot be read, its `unchecked` reads either `<resource>:<permission>` (the missing pair) or `truncated` (the read was cut at its cap). An unreadable part is never reported as empty.
- **View: `GET /api/ocupilot/users/effective?name=<user>`.**
  - Gate: `UserForm`'s pair set. A failure is 403 `AUTH.NOPRIVILEGE`, naming the failed pair.
  - The account is read with `Security.User` `GET` through `AdminPort`. A 404 answers `USER.NAME.ABSENT`.
  - Answer: `{user, all, allVia, roles, resources, applications, databases, services}`. Each section is `{rows, unchecked}`.
  - `roles.rows`: `{name, through}`.
  - `resources.rows`: `{name, R?, W?, U?}`, sorted by name. Each held letter's value is its granting role, or `""` when public.
  - `applications.rows`: `{name, resource}`, for `WebAppList` rows with a non-empty `Resource` the account holds at `U`.
  - `databases.rows`: `{directory, resource, permissions}`, for `DatabaseList` rows whose `Resource` the account holds at `R`. `permissions` is `R` or `RW`.
  - `services.rows`: `{name}`, for `ServiceList` rows whose `Name` is a resource the account holds at `U`. A service with no resource of its own name is gated by other means and is never listed (8 of 15 services on `ocupilot-ci`).
  - When `all` is true, the four sections other than roles are not read and answer empty.
- **Check: `Kernel.Shell.PermissionCheck.Check(kind, name, resource, permission)`.**
  - Arguments:
    - `kind`: `user` or `role`.
    - `name`: non-blank, 1-160 characters for a user, 1-64 for a role.
    - `resource`: non-blank, 1-64 characters.
    - `permission`: `READ`, `WRITE` or `USE`.

    Anything else is 400 `TOOL.ARGUMENTS`, naming the argument.
  - Gate: `UserList`'s set (for a user) or `RoleList`'s set (for a role), then `Effective.Read`'s own gates. A failure is 403 naming the pair.
  - Before any composition:
    - the principal is read with `Security.User` or `Security.Role` `GET`; a 404 answers `USER.NAME.ABSENT` or `ROLE.NAME.ABSENT`;
    - the resource is read with `Security.Resource` `GET`; a 404 answers `RESOURCE.NAME.ABSENT`.
  - Answer: `{kind, name, resource, permission, held, all, public, grantedBy, through}`, filled by the first matching case:
    - `%All` is in the closure: `held` and `all`, `grantedBy` `%All`, root = `allVia`.
    - A role grants the letter: `held`, `grantedBy` = the `sources` value, root = the `resources` value.
    - The letter is public only: `held` and `public`, `grantedBy` `""`.
    - Otherwise: `held` false.

    `through` is the root when the principal is a user and the root differs from `grantedBy`; otherwise `through` is `""`, and always `""` for a role check.

    A truncated `Effective.Read` is 503 `PERMISSION.UNCHECKED`, never "no".
- **Two callers, one operation (AD-1, AD-53's shape).** Both give the same answer object for the same arguments.
  - **The tool** `permissions.privileges.check`:
    - `KIND` read;
    - `DESCRIPTORCLASS` `UserList`;
    - `PrivilegePairs` = `UserList`'s set;
    - a closed `InputSchema`;
    - `View` calls `Check`.
  - **The route** `GET /api/ocupilot/permissions/check?kind=&name=&resource=&permission=` is a thin handler that calls `Check` and renders its refusals through `Error.Render`.
- **Client.**
  - **Effective privileges tab.** The User editor's third tab. It reads when the tab is selected and again whenever the editor re-reads its account.
  - **Check permission action.**
    - Identity and registration: a well-known action id beside Refresh, registered for `UserList`, `RoleList`, `UserForm` and `RoleForm`, and listed by the command bar and the command box.
    - Scope: it is screen-level, so it is never `aria-disabled` for lack of a selection.
    - Prefill: Type is User on the Users screens and Role on the Roles screens; Name is the selected row, or the entity the editor has open.
    - Dialog: rendered by `app-screen-action-dialogs`.
    - Check button: `aria-disabled` with "Enter a name and a resource first." until both fields hold text.
    - Result: the answer appears in a polite status line. A refusal shows its own reason inline, and the dialog stays open.
- **Copy** is taken verbatim from Design Notes. EXPERIENCE.md is edited in place and stays at 993 lines.
- **DW-1018 (Option A, decided).**
  - The Security area's set becomes `{%Admin_Secure:USE, %DB_IRISSYS:READ}`.
  - `WalletCollectionList`, `WalletSecretList` and `WalletSecretForm` own `%Admin_Wallet:USE`.
  - Each OAuth tab and form owns its OAuth pair. The resource-server tab and form own `%Admin_OAuth2_Client:USE`.

**Never:**

- No second composition, meaning no role closure and no public union outside `Effective`. `$System.Security.CheckUserPermission` is a test oracle only.
- No escalation, no `%SYS` read outside `AdminPort` (AD-2, AD-27), and no SQL.
- No write tool, governance key or `Baseline.cls` entry.
- No new descriptor, archetype or declared-read kind.
- The view never enters screen context or a tool result.
- No screen's own `privileges`, read or route changes. DW-1018 changes only the area set and adds `ownPrivileges`.
- Never edit `.github/workflows/ci.yml`, `ui/tools/ci-runner.mjs` or `ui/browser.config.mjs`. Roster edits are add-only.
- No lazy route and no `@defer`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Chained grant | Account `U` has role `A`. `A` grants `B`, and `B` has `%DB_USER:R`. Escalation role `E` has `%Admin_Secure:U` | Tab: Roles show `A` and `B (through A)`, with no `E`. Resources shows `%DB_USER` with Read = `B`. Databases lists the USER database with Read. Check (`user`, `U`, `%DB_USER`, `READ`) → "Yes. U holds %DB_USER:READ, granted by B (through A)." | — |
| Escalation | Same account; check `%Admin_Secure:USE` | "No. U does not hold %Admin_Secure:USE." This agrees with `CheckUserPermission`. | — |
| Public | Check `%DB_IRISTEMP:WRITE` for `U` | "Yes. Every account holds %DB_IRISTEMP:WRITE publicly."; each public letter reads "Public" in the tab | — |
| `%All` via role | Account `V` has role `R`, and `R` grants `%All` | Tab reads "Holds every privilege: R is or grants %All." and lists roles only. Check (any existing resource) → "Yes. V holds <pair>, granted by %All (through R)." | — |
| Role check | (`role`, `A`, `%DB_USER`, `READ`) | "Yes. A holds %DB_USER:READ, granted by B." (a role check has no through) | — |
| Unread part | Caller holds `%Admin_Secure:USE`, `%DB_IRISSYS:READ` and the code database, but not `%Admin_Manage` | Databases reads "Not checked (requires %Admin_Manage:USE)". Every other section is listed. | not a fault |
| Services | `%Service_SQL` is public at `U` | listed under Services for every account. `%Service_Bindings` is never listed. | — |
| Unknown | missing user, role or resource | the dialog shows the reason: "This instance has no user with that name." (or role, or resource) | 404 `USER`/`ROLE`/`RESOURCE.NAME.ABSENT` |
| Bad arguments | `kind=group`, or `permission=ALL`, or a blank name | the tool is refused and the route answers 400. The dialog never sends: its Check stays `aria-disabled` | 400 `TOOL.ARGUMENTS` |
| No privilege | caller without `%Admin_Secure:USE` | route and tool refuse, naming `%Admin_Secure:USE` | 403 `AUTH.NOPRIVILEGE` |
| Cut read | `Effective.Read` answers `truncated` (fixture seam) | Check: refused. Tab: every section reads "Not checked (too many to check)" | 503 `PERMISSION.UNCHECKED` |
| DW-1018 (Option A) | Principal holds `%Admin_Secure:USE` and `%DB_IRISSYS:READ` only | The Security rail item opens. SSL/TLS, X.509, LDAP and Auditing are available. Wallet and OAuth 2.0 are unavailable in the side bar, each naming its pair. | deep links to those refuse 403 as today |

</intent-contract>

## Code Map

Server (`src/OcuPilot/`):

- `Kernel/Shell/Effective.cls`:
  - `Compose` :53-115. The BFS queue is at :72/:103 and holds `$ListBuild(name, root)`. `Grant` :266 records the root.
  - `Read` :171 (its cap is `Screen.Read.DEFAULTMAXROWS` :199), `Gate` :252, `TRUNCATED` :35.
  - Consumers that must stay unchanged:
    - `Kernel/Shell/Findings.cls`: `Compose` :233/:303, `Privileged` :258-275 (reads `resources.<res>.U/W` and `all`), seams :577-580 and :601-604;
    - `Kernel/Proposal/Impact.cls` `Loses` :301-328.
- `Kernel/Proposal/Impact.cls` `ListRows` :332-343. This gate-then-`Screen.Read.Execute` idiom, with truncation mapped to unchecked, is the pattern the view follows. `Guarded` :282 matches rows by `Resource`; databases are named by `Directory` (:133).
- `Screen/Tool/ErrorRead.cls` is the precedent for a class read tool that takes arguments: `TOOLNAME`/`KIND`/`DESCRIPTION` :32-36, `DESCRIPTORCLASS` :41, `InputSchema` :64-76, `PrivilegePairs` :80-83, `SecretArguments` :99, `ResultSchema` :109, `View` :138-156.
- `Screen/Tool/Base.cls`: required members :26-136, `ArgumentsRefusal` :146, `InternalRefusal` :158.
  - Tools are found by subclass scan (`Screen/Tool/Registry.cls` `ToolClasses` :627-667). The name must match `TOOLNAMEPATTERN` :33. `Dispatch.cls` checks `RequiredPairs` :257 before `ValidateArguments` :270.
  - Do **not** extend `Kernel/Shell/ReadTool.cls`, whose contract is no arguments (pinned by `Test/ToolShell.cls`).
  - `Kernel/Agent/Sanitize.Results` wraps every result (AD-60), with no per-tool change.
- `Port/AdminPort.cls` `Invoke(endpoint, type, .query, body, .result, .http, .fault)`. Measured on `ocupilot-ci`:
  - `Security.Resource` `GET name=` answers `{Description, PublicPermission}`, or 404 `PORT.NOTFOUND`.
  - `Security.User` `GET` answers `Roles` and `EscalationRoles`, or 404.
  - Declared reads: `WebAppList` rows carry `Name`, `Resource`. `DatabaseList` rows carry `Directory`, `Resource`. `ServiceList` rows carry `Name`, `Public`, with no resource field.
- `Api/Router.cls`:
  - Users routes :93-96, with `GET /users/form` → `UserFormRules` :383, which calls `Area/Permissions/UserCreateRules.HandleForm`.
  - `ScreenImpact` :695 shows the refusal-envelope pattern.
  - `OnPreDispatch` :1149 requires some `%Admin_*` resource.
  - Route order is checked by rule 15 of `scripts/check-objectscript.py`, and wire tests by rule 12.
  - `Kernel/Shell` may name no `Api.*` except `Api.Error` (rule 20).
- `Api/Error.cls`: `USERNAMEABSENT` :1996, `RESOURCENAMEABSENT` :2127, `ROLENAMEABSENT` :3230 (with their reasons), `AUTHNOPRIVILEGE` :111. This file is shared-append.
- `Screen/Descriptor/UserForm.cls` :24-52 (`form-page`, no read, `toolIdentifier` `permissions.userform`). `UserList.cls` :48-113. `RoleList.cls`. `RoleForm.cls`.
- DW-1018 (Option A):
  - `Screen/Area.cls:125` (the security row) and its docs :82-97.
  - `Screen/Registry.cls` `OwnPrivilegesProblem` :739 and `AreaCoverageProblem` :797 (unchanged).
  - The 13 descriptors: `WalletCollectionList`, `WalletSecretList`, `WalletSecretForm`, `OAuthServerDescriptionTab`/`Form`, `OAuthClientTab`/`Form`, `OAuthResourceServerTab`/`Form`, `OAuthServerTab`/`Form`, `OAuthServerClientTab`/`Form`.
- Tests:
  - `Test/Effective.cls` is pure (legs :37-94).
  - `Test/ImpactRoute.cls` has the principal pattern (fixtures :17-60, `CreateAll`/`RemoveAll` :102-174, `CodeDatabaseResource` :200, HTTP-as-user `Impact()` :218).
  - `Test/ToolSetFull.cls` `ProbeAs` :137 runs the tool dispatch as a principal.
  - `Test/FindingsFixture.cls` :101 is the seam-override pattern.
  - `Test/ReadTool.cls` :93 holds the count 128 and :94 the sorted roster.
  - `Test/ToolRoundTrip.cls` :37 `REFUSEEMPTY`.
  - `Test/EndpointCoverage.cls` `XData Probes` :72-207 (siblings :106-108).
  - `scripts/ci-throwaway.sh` `OCUPILOT_ALLOW_PRINCIPALS` roster :200-232, checked by `ui/tools/ci.test.mjs` :1896.
  - DW-1018 tests:
    - `Test/Descriptor.cls:1783` (security area row), with the own-pair row pattern at :1068-1070;
    - `Test/SecurityLists.cls:165` and `Test/OAuthTabs.cls:184` (coverage called without own pairs);
    - `Test/WireSecurityRead.cls:966` (BOTHUSER area verdict), with docs :951-953 and :1043-1044;
    - `Test/WireOAuthRead.cls:324` (SECUREUSER), with docs :316-319;
    - `Test/Navigation.cls` around :265-273.

Client (`ui/src/app/`):

- `areas/permissions/user-editor.page.ts`:
  - `<app-form-tabs>` with `ocuFormTab="general"` :147 and `"roles"` :428-446 (it closes at :447);
  - `selectedTab` :495, which is reset on id change at :522;
  - `tabs` :563-570;
  - `selectTab` :770;
  - `app-screen-action-dialogs` is rendered here.
- `areas/permissions/user-editor.store.ts`:
  - `USERS_FORM_PATH` :12-15;
  - tab constants :22-25;
  - `open` :352;
  - ChangeBus refresh :375;
  - `read` :486-488;
  - `absorb` :524-562.
- Read-only list markup: `.ocu-form-roles`, as in the Roles tab. `grantLine(name, permissions)` is at `areas/permissions/role-grant-dialog.ts:24` and renders "Name: Read, Write".
- `areas/permissions/user-actions.ts` and `role-actions.ts`: root registrations for the lists (see the DW-246 note on registration timing). `areas/permissions/role-editor.page.ts`.
- `core/screen-actions.ts`: `REFRESH_ACTION_ID` :29, `DOWNLOAD_CSV_ACTION_ID` :32, `actionLabel` :48, `ACTION_LABELS` :64, `register` :136.
- `shell/command-bar.ts`: the Refresh slot :307-314, `hasContent` :605.
- `shell/command-box.ts`: the Refresh listing in `actionCandidates` :492-495.
- `shell/screen-action-dialogs.ts` :20-40 hosts every action dialog per descriptor. `shell/dialog.ts` :49-84 is `app-dialog`.
- `core/impact.ts`: `whyUnchecked` :142. `core/strings.ts`: `impactRequires`/`impactTooMany` :3055-3057, and the object ends at `} as const`.
- `app.ts` sign-out reset block (around :590-642).
- `ui/tools/strings.test.mjs` pins keys to Fixed strings: values are unique, and each `/** EXPERIENCE.md:n */` must point at a line containing the value.
- DW-1018 client pieces:
  - `ui/tools/screen-mirror.test.mjs` :2114-2118 (the own-pair owner roster);
  - `core/screens.generated.ts` (regenerated);
  - `ui/browser/security.browser-spec.mjs` :328-341 and `oauth.browser-spec.mjs` :424-436 (the AC5 rail-gated legs).

Docs:

- EXPERIENCE.md `:114` (User editor), `:127`, `:166`, `:173` (the list of allowed dialogs), `:468` (the user-editor strings row), `:603` (command-bar).
- AD-8 in the spine.

## Tasks & Acceptance

**Execution:**

- `src/OcuPilot/Kernel/Shell/Effective.cls`:
  - `Compose` also answers `roles` (closure order; `through` = the root, or `""` for a root) and `sources` (per letter, the role whose row granted it; `""` for public).
  - Add a pure `Holds(pComposed, pResource, pLetter)` that matches case-insensitively and answers `{held, all, public, grantedBy, root}`.
  - Update the doc comment.
- `src/OcuPilot/Kernel/Shell/EffectiveUser.cls` (new, no storage):
  - `Of(pUser, Output pAnswer, Output pHttpStatus, Output pFault)` implements the view described under Always.
  - Its part reads follow `Impact.ListRows`: gate, then `Screen.Read.Execute`, with truncation reported as `truncated`.
  - `EffectiveRead` and `ListRows` are overridable seams, as in `Findings`.
- `src/OcuPilot/Kernel/Shell/PermissionCheck.cls` (new): the tool class and the one operation.
  - Parameters: `TOOLNAME` `permissions.privileges.check`, `KIND` read, `DESCRIPTORCLASS` `OcuPilot.Screen.Descriptor.UserList`.
  - `DESCRIPTION` (this text is for the model, and is not a Fixed string): "Check whether a user or a role holds one resource permission (READ, WRITE or USE), composed from its roles, every role they grant and public permissions; escalation roles do not count until used. Answers held, and the role that grants it."
  - Methods: `InputSchema`, `ResultSchema` (all nine members required), `SecretArguments` (none), `PrivilegePairs` = `Screen.Gate.RequiredPairs(UserList)`, and `View`, which calls `Check`.
  - `Check(...)` follows Always. `EffectiveRead` is a seam.
- `src/OcuPilot/Api/Privileges.cls` (new): `HandleEffective()` and `HandleCheck()` read the query parameters, call `EffectiveUser.Of` or `PermissionCheck.Check`, and answer through `Response.JSON` or `Error.Render`.
- `src/OcuPilot/Api/Router.cls`:
  - Add `GET /users/effective` → `UserEffective` beside `/users/form`.
  - Add `GET /permissions/check` → `PermissionCheck`.
  - Both are thin `Call=` wrappers, placed to satisfy rule 15.
- `src/OcuPilot/Api/Error.cls`: add `PERMISSION.UNCHECKED` (503, slug `unavailable`), with the reason "There are too many roles or resources to read, so this was not checked." (server-only).
- DW-1018 (Option A):
  - `src/OcuPilot/Screen/Area.cls` security row → `%Admin_Secure:USE`, `%DB_IRISSYS:READ`. Rewrite :82-97 into one short paragraph saying the wallet and OAuth screens declare their resource as their own pair (AD-8).
  - The 13 descriptors each gain `"ownPrivileges"`, set to their wallet or OAuth pair.
- Server tests, one class per run:
  - `Test/Effective.cls`: legs for `roles`, `sources` and `Holds` over literal rows. The chain `A→B` names source `B` with root `A`. There is also a `%All` leg and a case-insensitive lookup leg.
  - New `Test/PermissionCheck.cls`, armed by `OCUPILOT_ALLOW_PRINCIPALS`. It uses `OcuPermCheck`-prefixed probe roles, users, a resource and a web application, and removes them afterwards, failing if any are left. It pins:
    - for every probe triple, `held` equals `$System.Security.CheckUserPermission` (chain, public, escalation, `%All` via role, not held);
    - `grantedBy`/`through` and the role check;
    - each refusal, with its code and status;
    - that route and tool answer the same object;
    - the 403 through the route and through the dispatch path, as a least-privileged principal;
    - the fixture seam producing 503.
  - New `Test/EffectiveUser.cls` (armed alike) pins the matrix's tab rows:
    - sections and sort order, through, public, escalation absent;
    - `%All`;
    - Databases unchecked for a caller without `%Admin_Manage:USE`;
    - Services rule, application rule;
    - 404, 403, and the truncated seam.
  - Update rosters: `Test/ReadTool.cls` count 129, with `permissions.privileges.check` inserted in the sorted roster; `ToolRoundTrip` `REFUSEEMPTY` += `permissions.privileges.check:TOOL.ARGUMENTS`; two `EndpointCoverage` probes; add-only roster lines in `scripts/ci-throwaway.sh` and `ui/tools/ci.test.mjs`.
  - DW-1018 test updates: the rows listed in the Code Map, including a new `Navigation` row asserting that security is admitted with `%Admin_Secure:USE` and `%DB_IRISSYS:READ`, and per-screen own-pair rows in `Descriptor`.
- `ui/src/app/core/privileges.ts` (new, framework-free):
  - `effectiveOf(json)` and `checkAnswerOf(json)`, which validate the wire shapes;
  - `checkSentence(answer)`;
  - `effectiveAllLine(role)`.

  Each builds its text from STRINGS with replacer functions.
  - New `ui/tools/privileges.test.mjs` covers every sentence branch and shape refusal.
- `ui/src/app/areas/permissions/user-editor.store.ts` and `user-editor.page.ts`: `EFFECTIVE_TAB` becomes the third tab. The editor store reads `GET /api/ocupilot/users/effective?name=`, re-reads on select and on the editor's own re-read, and keeps the result's state. The page renders it, in order:
  - the intro sentence, or the all statement;
  - Roles;
  - Resources, as a table with columns Resource · Read · Write · Use, where each cell shows the grantor, "Public", or nothing;
  - Web applications;
  - Databases, one line per database via `grantLine`;
  - Services.

  An empty section reads "(none)". An unchecked section reads "Not checked" followed by `whyUnchecked`'s suffix.
- `ui/src/app/core/screen-actions.ts`: `PERMISSION_CHECK_ACTION_ID = 'permission-check'`, labeled `permissionCheckAction` in `ACTION_LABELS`.
- `ui/src/app/shell/command-bar.ts` and `command-box.ts`: draw and list the action after Refresh whenever a handler is registered. It is screen-level and never blocked by "Select a row first".
- New `ui/src/app/shell/permission-check.ts` (a root store: `pending` per descriptor, `open`, `check`, `answer`, `error`, `busy`, `reset`) and new `ui/src/app/shell/permission-check-dialog.ts` (`app-dialog`), rendered from `screen-action-dialogs.ts`.
  - The dialog's fields are Type (User/Role), Name, Resource and Permission (Read/Write/Use), then a Check button.
  - `user-actions.ts` and `role-actions.ts` register the action for the lists, with the selected row as prefill. `user-editor.page.ts` and `role-editor.page.ts` register it for their editors, with the open entity as prefill.
  - `app.ts` resets the store at sign-out, with a sibling assertion in `app.spec.ts`.
- `ui/src/app/core/strings.ts`: add the Design Notes keys, each citing `EXPERIENCE.md:468`. Regenerate `core/screens.generated.ts`.
- `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md`: make the in-place edits listed under Design Notes. `wc -l` must still read 993.
- Client tests:
  - `areas/permissions/user-editor.page.spec.ts`: the tab's sections, the through suffix, Public cells, the all statement, the unchecked line, and the fetch URL;
  - new `shell/permission-check-dialog.spec.ts`: prefill, the disabled reason, each sentence, an inline refusal, and the request URL with every value encoded;
  - `shell/command-bar.spec.ts` and `command-box.spec.ts`: the action is drawn and listed only where registered;
  - `app.spec.ts`: the reset;
  - `ui/tools/screen-mirror.test.mjs`: the owner roster, for DW-1018.
- New `ui/browser/permissions-effective.browser-spec.mjs`, on `ocupilot-ci` only, using `assertThrowaway`. It creates and removes probe principals, and covers:
  - the tab for the chained account and the `%All` account;
  - the Users-list dialog answer;
  - a scripted turn (`TurnProvider.Script`) calling `permissions.privileges.check`, whose recorded `tool_result` is read with `resultPayload` and equals the dialog's answer;
  - the DW-1018 principal leg;
  - the DW-1337 structural walk of the tab at wide light, narrow light and wide dark.

  Also update the AC5 legs in `security.browser-spec.mjs` and `oauth.browser-spec.mjs` for Option A.
- Bundle: only if `npm run build`'s initial total exceeds `maximumWarning`, re-base `ui/angular.json` and the `ui/tools/angular-json.test.mjs` literal under DW-1166, to 5% above the measured total. Stop and ask above 3800kB.

**Acceptance Criteria:**

- **AC1.** Given the chained account on `ocupilot-ci`, when its User editor's Effective privileges tab opens, then:
  - Roles list `A` and `B (through A)`, and the escalation role `E` is absent;
  - Resources shows `%DB_USER` with Read `B`, and every public permission reads "Public";
  - Databases, Web applications and Services list what the held resources guard.
- **AC2.** Given an account whose role grants `%All`, when the tab opens, then it reads "Holds every privilege: <role> is or grants %All." and lists its roles only.
- **AC3.** Given a caller holding `%Admin_Secure:USE` and `%DB_IRISSYS:READ` without `%Admin_Manage:USE`, when the tab opens, then Databases reads "Not checked (requires %Admin_Manage:USE)" and every other section is listed.
- **AC4.** Given the check dialog or the `permissions.privileges.check` tool, when a user and a resource permission are checked, then:
  - `held` equals `$System.Security.CheckUserPermission` for every probe triple;
  - a yes names the granting role, with the account's own role in parentheses when that role differs from the granting one;
  - a public permission says so.
- **AC5.** Given a role or a `%All` path, when checked, then:
  - a role check names the granting role with no through;
  - any holder of `%All` is answered yes, granted by `%All`, before any per-resource lookup;
  - a missing resource is refused rather than answered.
- **AC6.** Given a missing principal or resource, a malformed argument, a caller without `%Admin_Secure:USE`, or a truncated read, when checked, then the refusal is the matrix's code and status on both callers, and the dialog shows its reason inline and stays open.
- **AC7 (DW-1018, Option A).** Given a principal holding only `%Admin_Secure:USE` and `%DB_IRISSYS:READ`, when the shell loads, then the Security rail item opens, and in its side bar SSL/TLS, X.509, LDAP and Auditing are available while Wallet and OAuth 2.0 are unavailable, each naming its own pair.
- **AC8.** Given the new strings, when this story lands, then they are in EXPERIENCE.md's Fixed strings and in `strings.ts`, pinned equal by `npm run test:tools`, and EXPERIENCE.md still has 993 lines.
- **AC9 (Integration).** Given `ocupilot-ci` with the probe principals:
  - when `PermissionCheckDialog` (consumer) reads `GET /api/ocupilot/permissions/check`, and the agent's `permissions.privileges.check` answers the same question in a scripted turn (its `tool_result` read through `resultPayload`), then both show the same `held`, `grantedBy` and `through`;
  - and when `UserEditorPage` (consumer) opens the tab, it renders `GET /api/ocupilot/users/effective`'s sections.

  The bundle stays under the warning or is re-based under DW-1166.

## Spec Change Log

- 2026-09-28T06:45Z, lead spec gate: DW-1018 decided Option A by the owner (merge gate, relayed by the orchestrator); the `(pending)` markers in the intent contract and Tasks now read decided; status reset to `ready-for-dev`; spine changes (a) and (b) written by the lead; the residual rail cases filed as their own `decision-pending` entry owned by `range-end-cleanup`.

## Review Triage Log

## Design Notes

**Decisions.**

1. **A tab, not a new screen.** EXPERIENCE.md `:166` says "Effective privileges is a User editor view", and the User editor is one `form-page` descriptor whose tabs are local state. A third tab is that view; a new descriptor would be a second screen for the same account. Its read is a composed shell route, as `/users/form` and `/screens/:screen/impact` are, so it needs no new declared-read kind (AD-36 is untouched). The agent's path to the same facts is the check tool.
2. **The check is a read-kind class tool** (the `ErrorRead` precedent) plus a route, over one `Check`. Being a read tool, it needs no governance key (AD-22), and its result passes the sanitizer by construction (AD-60).
3. **`grantedBy` versus `through`.** The role whose own grant it is answers "which definition to change". The account's own role answers "which of their roles to remove". `Compose` already knows both, so recording both adds no second composition.
4. **Screen-level command-bar action.** The check needs no row, so it follows Refresh's well-known-id pattern rather than a descriptor `rowAction`. A `rowAction` would make `UserList`/`RoleList` write-capable in the sense of `Registry.IsWriteCapable`, and would route through `POST /screens/:screen/action`.

**Fixed strings.** Fold the following into EXPERIENCE.md `:468` in place, with no new line. The quoted literals are appended to its String cell and the text to its Where cell, tagged `[ADDED 2026-09-28 - Story 16.3]`. Keys cite `:468`:

> `"Effective privileges" · "What this account holds through its roles, the roles they grant, and public permissions. Escalation roles are not counted until used." · "Holds every privilege: <role> is or grants %All." · " (through <role>)" · "Not checked" · "Check permission" · "Permission" · "Check" · "Enter a name and a resource first." · "Yes. <name> holds <pair>, granted by <role>." · "Yes. Every account holds <pair> publicly." · "No. <name> does not hold <pair>."` — the user editor's Effective privileges tab (Story 16.3, FR-74): its label, its intro, the `%All` statement, a reached role's suffix, and an unread section, which takes " (requires <pair>)" or " (too many to check)" (`:577`); and the permission check (Story 16.3, FR-74), a command-bar action on the Users and Roles lists and the user and role editors: its label, the Permission field and its Check button, the reason Check stays unavailable, and its three answers, where `<pair>` is `<resource>:<READ|WRITE|USE>` and a yes's `<role>` may take " (through <role>)".

- **Keys:** `userEffectiveTab`, `userEffectiveIntro`, `userEffectiveAll`, `userEffectiveThrough`, `userEffectiveUnchecked`, `permissionCheckAction`, `permissionCheckField`, `permissionCheckRun`, `permissionCheckIncomplete`, `permissionCheckYes`, `permissionCheckPublic`, `permissionCheckNo`.
- **Reused keys:**
  - `userColumnRoles`, `resourceListLabel`, `webAppListLabel`, `databaseListLabel`, `serviceListLabel`;
  - `webAppColumnResource`, `permissionRead`/`Write`/`Use`, `oauthClientTypePublic` ("Public"), `tableEmptyValue`;
  - `tableColumnName`, `tableColumnType`, `processColumnUser`, `userRoleField`;
  - `impactRequires`, `impactTooMany`, `actionCancel`.
- **Other in-place edits:**
  - `:114`: append "; an Effective privileges tab (Story 16.3)" to its contents cell.
  - `:127`: change the contents cell to "FR-74: the User editor's Effective privileges tab; Check permission on the Users and Roles lists and both editors (Story 16.3)".
  - `:166`: "view" becomes "tab".
  - `:173`: add "check a permission (Permissions' Users and Roles lists and the user and role editors, Story 16.3)" to the dialog list.
  - `:603`: after "Refresh." insert "Check permission (Story 16.3) is, like Refresh, a screen-level action: it never waits on a selection, and a selected row or the open user or role prefills it."

**Spine changes for the lead (Rule 20).** None contradicts an AD.

- (a) AD-8, "A removal names its impact", after "a later effective-privilege read uses it": insert "(Story 16.3: the user editor's Effective privileges tab and the permission check, whose answer also names the role whose own grant it is and the account's role it is reached through)".
- (b) Option A only: in AD-8's DW-1755 paragraph, replace "The one case today is Logs, ..." with "The cases today are Logs, ... and Security, whose set is `%Admin_Secure:USE` and `%DB_IRISSYS:READ`: the wallet screens own `%Admin_Wallet:USE` and each OAuth 2.0 tab and form its OAuth resource (Story 16.3, DW-1018)".

**Governing ADs.** AD-8 (the composition, gates and DW-1018), AD-29, AD-1, AD-2/AD-27, AD-5, AD-36, AD-22, AD-60, AD-11, AD-12/AD-39, AD-13, AD-19/AD-20, AD-24, AD-53, AD-9 and AD-21.

**Integration.**

- **Consumes:**
  - 16.19's `Effective` (`Read`, `Compose`, `Gate`);
  - `AdminPort` `Security.User`/`Role`/`Resource` `GET`;
  - `Screen.Read.Execute` over `WebAppList`, `DatabaseList` and `ServiceList`;
  - 16.8's `ownPrivileges`;
  - `ScreenActions`, the command bar and box, `app-dialog`, and `app-screen-action-dialogs`;
  - `TurnProvider.Script` and `resultPayload`;
  - `structural-walk.mjs`.
- **Consumed-by:** no later story is planned. This story's own consumers are named in AC9.

**Ledger inbox.**

- **DW-1018 reproduces on this tree.** `Area.cls:125` still lists `%Admin_Wallet:USE` and the three OAuth pairs. Option A resolves the filed symptom, but not the decided rule (see Auto Run Result).
- **Residual under Option A**, measured on `ocupilot-ci` by reading role definitions:
  - a holder of `%Admin_Wallet` or an OAuth resource who lacks `%Admin_Secure` stays gated at the Security rail;
  - stock `%Operator` (`%Admin_Operate:U`, `%DB_IRISSYS:RW`, no `%Admin_Secure` or `%Admin_Manage`) stays gated at the Logs rail (DW-278) and the OS management rail (DW-275), although messages.log, alerts.log, Locks, System usage and Database details would serve it.
- **Why no pair set can express the rule.** Security's screen sets are `{Secure, IRISSYS}`, `{Wallet, IRISSYS}` and `{OAuth resource, IRISSYS}`. "Any screen" is therefore IRISSYS AND (Secure OR Wallet OR an OAuth resource), which a single AND set cannot state.

**CI.** Story 13.5 is not on this branch. The two new test classes and the new browser spec will land unassigned in its timings file when integrated forward.

## Verification

**Commands** (slot A). Everything that creates a principal runs on `ocupilot-ci` only. Every browser run first executes `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`, with `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci`.

- `cd ui && npm run test:tools` (loop). Expected green: `strings`, `privileges`, `screen-mirror` (owner roster), `ci` (roster), `citations`.
  - Mutations:
    - `checkSentence` drops the through suffix → the `privileges` through case goes red;
    - the Fixed strings row loses "Check" → the `strings` parity case goes red (AC8).
- `cd ui && npx ng test --include src/app/areas/permissions/user-editor.page.spec.ts --include src/app/shell/permission-check-dialog.spec.ts --include src/app/shell/command-bar.spec.ts --include src/app/shell/command-box.spec.ts --include src/app/app.spec.ts` (loop). Expected green.
  - Mutations:
    - the tab renders public letters as blank → the AC1 Public case goes red;
    - the dialog sends with a blank resource → the disabled-reason case goes red;
    - the reset is dropped → the `app.spec.ts` case goes red.
- `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class <C>` (loop), one class per call. `<C>` is each of `OcuPilot.Test.Effective`, `PermissionCheck`, `EffectiveUser`, `ReadTool`, `ToolRoundTrip`, `ToolEmit`, `ToolShell`, `ToolSetFull`, `EndpointCoverage`, `ImpactRoute`, `Findings`, `Descriptor`, `Navigation`, `SecurityLists`, `OAuthTabs`, `WireSecurityRead`, `WireOAuthRead`, `DeclarationCorpus`, `OwnPairRegistry`. Expected green.
  - Mutations:
    - `Compose` records the root in `sources` → the `Effective` chain leg goes red (AC4);
    - `Check` passes `EscalationRoles` in → the `PermissionCheck` oracle leg goes red (AC4);
    - `Check` skips the resource `GET` → the missing-resource leg goes red (AC5);
    - the `all` branch is removed → the `%All` leg goes red (AC5);
    - `Check` returns held false on truncation → the 503 leg goes red (AC6);
    - `EffectiveUser` reads `DatabaseList` without its gate → the AC3 leg goes red;
    - the escalation role is included in `roles` → the AC1 leg goes red;
    - `EffectiveUser` ignores `all` → the `EffectiveUser` `%All` leg goes red (AC2);
    - Option A: `%Admin_Wallet:USE` is put back on the area → the `WireSecurityRead` BOTHUSER leg goes red (AC7).
- The build and redeploy above, then `cd ui && node --test --test-concurrency=1 browser/permissions-effective.browser-spec.mjs browser/security.browser-spec.mjs browser/oauth.browser-spec.mjs browser/users-editor.browser-spec.mjs browser/users.browser-spec.mjs browser/roles-editor.browser-spec.mjs browser/impact.browser-spec.mjs browser/a11y-structural-invariants.browser-spec.mjs` (loop). Expected green within the structural baseline.
  - Mutation: the tool's `View` answers a constant → the AC9 parity leg goes red, on a rebuilt and redeployed bundle.
- `cd ui && npm run build` (once, before `dev_complete`): report the initial total, and re-base per DW-1166 if needed. Then `npm test`, `uv run scripts/check-objectscript.py`, `bash scripts/lint-docs.sh`, and `wc -l` on EXPERIENCE.md, which must read 993. Expected green.
- The full ObjectScript sweep on `ocupilot-ci`, one class at a time (once, before `dev_complete`). Expected green. The full browser suite runs in CI (Rule 29).

## Auto Run Result

Status: ready-for-dev
Blocking condition: none

Plan pass 2026-09-27 halted `blocked` on the DW-1018 intent gap (AD-8). The owner decided Option A at the merge gate (2026-09-28, relayed by the orchestrator): Security's set becomes `%Admin_Secure:USE` + `%DB_IRISSYS:READ` and the 13 wallet and OAuth screens declare their pair as `ownPrivileges`; an own pair is never one the area already declares (DW-1760's direction). The residual rail cases (a wallet-only or OAuth-only holder at Security; `%Operator` at Logs and OS management) are a separate ledger entry for an owner decision after the voting week, with Option B (AD-8's any-screen rail) as the named alternative. The lead wrote spine changes (a) and (b) and accepted the spec as written at the spec gate.
