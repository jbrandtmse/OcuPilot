---
title: 'Story 9.2: The web application editor'
type: 'feature'
created: '2026-09-24'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-9-context.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** A web application can be created (8.1) and enabled, disabled or deleted from its list (5.x, 7.1), but nothing edits one. `web-applications/list/edit/<id>` mounts the create page, which ignores the id, so a reload there draws an empty create form (DW-1490). Five more routed entries land here as well.

**Approach:** Build a tabbed editor at `web-applications/list/edit/<id>`, following 9.1's user editor. The tabs are named after the classic page: General, Application Roles, Matching Roles and Cross-Origin Settings.

- **Save:** a new `PUT /web-applications/:id` through `WebAppUpdate` (AD-55). The tool's reviewed field set widens to the settings the story lists.
- **Roles:** the two roles tabs add and remove through AD-53 screen actions, as server-side deltas (AD-56 ii). The agent gets a `MatchRoles` argument.
- **Reuse:** 9.1's tabs, action path, routing and form-page pieces.
- **Routed entries:** DW-1490, DW-1493, DW-1502, DW-1577, DW-1595 and DW-1596 are fixed as the tasks list.

## Boundaries & Constraints

**Always:**

- Save follows `UserSave.Update`'s order. The tool's pair set first. Then a fresh read, where an absent application is a 404 and nothing is sent. Any body key outside `PERMITTEDFIELDS` is 400 `PORT.FIELD.UNEXPECTED`. Then the rules, the merge (the complete set, AD-4), the prohibited set (before any port call), and the send.
- One rule copy serves both callers. `WebAppUpdate.ArgumentProblem` and the Save call the same update-mode `Create.Validate`.
- The editable settings are exactly these 19: AutheEnabled, AutoCompile, CorsAllowlist, CorsCredentialsAllowed, CorsHeadersList, Description, Enabled, GroupById, IsNameSpaceDefault, JWTAccessTokenTimeout, JWTAuthEnabled, JWTRefreshTokenTimeout, LockCSPName, Recurse, Resource, ServeFiles, ServeFilesTimeout, Timeout and WSGIType.
  - `PermittedChangeFields("web-application")` holds those 19 plus `MatchRoles`.
- The General tab also shows, read-only: Name, the derived type, NameSpace, DispatchClass, WSGIAppName, WSGICallable, WSGIAppLocation, Path, Package and SuperClass.
  - They choose which code answers at the address, or where it runs from (DW-1207, AD-21), so no caller changes them here.
  - They carry the one caption `webAppEditorFixedFields`.
- The shipped asymmetric predicates stay:
  - Of all AutheEnabled changes, only clearing Unauthenticated passes (`UNAUTHENTICATED`).
  - Clearing Resource is refused (`AUTHORIZATION`).
  - Both sentences become caller-neutral `…REASON` parameters, published and pinned (AD-53).
- Application roles on any other application are permitted, `%All` included.
  - The agent's proposal is minted destructive and names the privilege (`GrantsPrivilegeByEffect`, unchanged).
  - The editor shows `privilegedGrantEffect` under a privileged choice. When an application role is added to an application whose AutheEnabled holds the Unauthenticated bit, it shows `privilegedGrantEffectUnauthenticated` instead: one line, never two.
- On OcuPilot's own applications, the order of refusal is unchanged:
  - A roles change is `PROHIBITED.PRIVILEGEGRANT`.
  - Every other change, disable included, is `PROHIBITED.SERVINGPATH`.
  - The editor draws both refused beforehand.
- Save publishes one `web-application`/`updated` change event. The list re-fetches; it is never patched.
- New strings are appended to `strings.ts` and to EXPERIENCE.md's Fixed-strings rows. Tokens only; non-ASCII as `\uXXXX`. Every input is named; nothing overflows.

**Never:**

- Never a MatchRoles list computed by the client. Save refuses `MatchRoles`.
- No Percent Class Access tab. It is a separate endpoint (`WebApp.PctClassAccess`) and outside the AC.
- No session or cookie fields beyond `Timeout`, no custom pages, and no Zen, DeepSee, iKnow or inbound-web-services flags. The AC lists none of them.
- No edits to Epic 10's exclusive paths:
  - `Api/Definitions.cls`, `Kernel/Provider/**`, `Port/ProviderPort.cls`, `Kernel/AgentRules.cls`, `Kernel/Egress.cls`, `Kernel/State/Agent.cls`
  - the listed `Test/*` classes
  - `areas/agent/definition-form.*`, `shell/context-chip.ts`, `browser/definitions.browser-spec.mjs`, `README.md`
- Shared-append files take appends only: `Api/Error.cls`, `strings.ts`, `_components.scss`, the Fixed-strings rows, and `DW-n:` bullets. `Screen/Tool/Registry.cls` and `ui/tools/strings.test.mjs` are contended: read `origin/OCU-1-epic10`'s copy first and change only your own members.
- No change to `UNCOVEREDFIELD`'s sentence (DW-1598 is 9.3's) and no DW-1597 work.
- No private keys in any file, and no full browser suite locally.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Two-field save | `PUT /web-applications/<id>` `{Description, Timeout}` on a probe application with CORS, JWT and ServeFiles set | 200. The vendor receives the complete set, and every other read field reads back unchanged. One `updated` event. | — |
| Undeclared key | body carries `MatchRoles`, `DispatchClass`, `NameSpace` or `Path` | 400 `PORT.FIELD.UNEXPECTED` naming each key; nothing sent | — |
| System application | Save on a probe created with `Type` 3 | `Type` still reads 3 afterwards. Measured on `ocupilot-ci`: the vendor PUT forces `Type` 2 (`WebApp.App.MergeJsonAndProperties:153`) and `Modify` clears the system bit. | a failed restore answers the port's fault |
| Own app, AC3 | Save `{Enabled:false}` on `/api/ocupilot`; the add-application-role action with `%All` on `/ocupilot` | 403 `PROHIBITED.SERVINGPATH`; 403 `PROHIBITED.PRIVILEGEGRANT`; nothing sent | each sentence is its published `…REASON` |
| Auth weakening | Save adds Unauthenticated, or clears Resource, on a probe | 403 `PROHIBITED.UNAUTHENTICATED` / `PROHIBITED.AUTHORIZATION`, with the new caller-neutral sentences | — |
| Privileged role | editor adds application role `%All` to an unauthenticated probe; the agent proposes `MatchRoles` with `%All` | the editor shows `privilegedGrantEffectUnauthenticated` only; the proposal is destructive and names `%All` | — |
| DW-1490 | hard reload of `web-applications/list/edit/<id>` | the editor reads the application and shows its values | absent id → the editor's absent state (404 `WEBAPP.NAME.ABSENT`) |
| DW-1493 | agent create of `/csp/CaseProbe92/` confirmed; agent create of user `CaseProbe92` confirmed | the vendor stores `/csp/CaseProbe92` and `CaseProbe92` as typed. `TargetRef` stays canonical. | — |
| DW-1577 | agent `webapp.list.update` `{Enabled:<current>}`; any merge tool with no changed row | 400 `TOOL.ARGUMENTS`, no proposal row | — |
| DW-1596 | the web-application editor and the user editor at 1440x900 | the form bar's bottom equals the shell content bottom (±1px) without scrolling; the page itself scrolls | — |

</intent-contract>

## Code Map

S = `src/OcuPilot/`, U = `ui/src/app/`.

Server:

- `S/Screen/Tool/WebAppUpdate.cls`:
  - `PERMITTEDFIELDS` at :51 and `EXCLUDEDFIELD MatchRoles` at :41.
  - `SCREENACTIONS` at :57 is `enable`/`disable`.
  - It inherits `ArgumentProblem` and `ScreenActionDelta` from `Write.cls` (:739, :537).
  - `ScreenActionValueNames` (`Write.cls:509`) already parses `a=X:Y`.
- `S/Screen/Tool/WebAppCreate.cls`:
  - `MATCHROLESARGUMENT` at :64, the `SettableFields` append at :110-113, the array-of-object `InputSchema` at :171-184, and `ArgumentProblem` → `Create.Validate(...,0)` at :191.
  - `UserUpdate.cls` is the precedent for an authored list argument plus role actions: `ROLESARGUMENT` at :69, `SCREENVALUES` at :59, `ScreenActionDelta` at :213-260.
- `S/Area/WebApp/`:
  - `FormRules.HandleForm` (:90-127) does not read `?name=`.
  - `Create.Validate` (:227-295) and `MatchRolesViolation` (:297).
  - Precedent for a form read with a name: `Area/Permissions/UserCreateRules.HandleForm` (:370-427) and `Account()` (:480-495).
  - Precedent for the Save: `Area/Permissions/UserSave.cls` (`HandleUpdate`, `Update`, `Gate`).
- `S/Api/Router.cls`: web-app routes at :95-97; the precedent `PUT /users/:id` at :100 with its handler at :322-329.
- `S/Kernel/Proposal/Prohibited.cls`:
  - Parameters: `SERVINGPATH` and the `…REASON` parameters at :59-176.
  - `ReasonFor` at :324-347. `PRIVILEGEGRANT`, `UNAUTHENTICATED` and `AUTHORIZATION` are inline literals (:326-329).
  - `PermittedChangeFields` at :410-424 (web app at :413), `WebApplication()` at :817-871, `ServesOcuPilot` at :2241, `GrantsPrivilegeByEffect` at :1622.
- `S/Kernel/Proposal/Mint.cls`:
  - Create vs merge is decided at :183-193, `Merge` at :433-501 (rows only when a value differs, :460), and `StateDiff` rows at :221-241.
  - Nothing checks for an empty diff after :241.
  - `Refuse` (400 `TOOL.ARGUMENTS`) is at :791-799.
- `S/Kernel/Proposal/Confirm.cls`:
  - `FingerprintMatches` (:570) sets the id from `EntityRef.Parse(targetRef)` (:585-587), which is canonical, and returns in the create branch at :598-606.
  - The stored arguments (`pRow("arguments")`, parsed at :615) carry the typed name under the tool's `IdArgument()`.
  - Creates affected: WebApp, User, Role and Resource (`EntityRef.cls` `IDRULES` :59).
- `S/Port/AdminPort.cls`: the one place `WebApp.App` PUTs pass through (AD-2, AD-27).
- `S/Api/Error.cls`: `REASONAGENTCREDTYPEUNAVAILABLE` at :1285 (code at :421, mapped at :1061).
- `S/Test/RefusalCopy.cls` (66 lines; legs at :24-64), `Test/ToolWrite.cls:150` (asserts no `CorsAllowlist`; update it), and `Test/Prohibited.cls:355` (schema equals `PermittedChangeFields`).
- `S/Screen/Descriptor/`:
  - `WebAppForm.cls` has no `suggestedPrompts`; `UserForm.cls:45` is the precedent.
  - `WebAppList.cls` rowActions: enable, disable and delete, all `serves-ocupilot`.
  - `Screen/Registry.cls:2244` is `SELFPROTECTIONRULES`.

Client:

- `U/areas/web-applications/create-form.page.ts` (792 lines) and `create-form.store.ts` (730 lines):
  - The field template and the order of the classic page.
  - `absorbRules` at :673-730 (reuse it; export it rather than copy it).
  - `privilegeEffect` at :545.
  - The retain handoff at :708-723 and :787, which DW-1490 replaces.
- `U/areas/permissions/user-editor.page.ts` (923 lines) and `user-editor.store.ts` (563 lines): the pattern to mirror.
  - Tabs at :145-446 and the form bar at :448-460.
  - `routeId`/`NavigationEnd` at :516-523; change bus at :525-528.
  - Actions: `startFor` at :845, `onApplied` at :852; `afterRefusal` at :883.
  - `changedFields` at :296, `arriveSaved`/`open` at :332-351, `refresh` at :355, `save` at :410-451.
- `U/shell/screen-action-handler.ts`:
  - `startFor(descriptor, actionId, target, rowFields, sink, role='')` at :395.
  - `VALUE_ACTIONS` at :99, `UNDRAWN_ACTIONS` at :104, `send` at :533.
- `U/shell/screen-outlet.ts:123-125` (`DESCRIPTOR_EDIT_PAGES`) and `U/core/navigation.ts:202-205` (`CREATE_ONLY_FORMS` = WebAppForm, RoleForm).
- `U/core/self-protection.ts:23,99-105` (`SERVES_OCUPILOT_RULE`, `OCUPILOT_APPLICATION_PATHS`). `ui/tools/screen-mirror.mjs:313` is `IMPLEMENTED_SELF_PROTECTION_RULES`.
- `ui/tools/self-protection.test.mjs`: `stringValue` at :55-60 and the parameter/key pairs at :110-147.
- `ui/src/styles/_components.scss`:
  - The flex host list at :734-747.
  - `.ocu-form-page` at :2841 (`overflow-y:auto`).
  - `.ocu-form-bar` at :2962 (sticky).
  - The toast lift at :5512-5514.
- DW-1595 prose:
  - `U/shell/toast-host.ts:12-22` and `:48-52`: the "component-scoped" paragraph, now stale.
  - `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/DESIGN.md:1210`.
- EXPERIENCE.md Fixed strings at :254-468; the row format is :467. `privilegedGrantEffect*` rows are :403-404. The IA row is :129.
- Browser specs:
  - `ui/browser/users-editor.browser-spec.mjs`: helpers at :141-183, visual gate at :323-374, and the geometry test at :379-410, whose `scrollIntoView` at :392 is DW-1596's workaround.
  - `web-applications.browser-spec.mjs:231` (AC5 name link).
  - `web-applications-create.browser-spec.mjs:250-295` (AC2 post-create URL and Saved).

## Tasks & Acceptance

**Execution:**

Server tasks:

- `S/Kernel/Proposal/Prohibited.cls`:
  - `PermittedChangeFields("web-application")` becomes the 19 settings plus `MatchRoles`. Its doc names the fixed-field rationale.
  - Add `PRIVILEGEGRANTREASON` (the existing sentence), `UNAUTHENTICATEDREASON` ("The only change OcuPilot makes to how a web application signs people in is removing the option of reaching it without signing in.") and `AUTHORIZATIONREASON` ("OcuPilot does not remove the resource that guards a web application."). `ReasonFor` returns each `..#XREASON`.
- `S/Screen/Tool/WebAppUpdate.cls`:
  - `PERMITTEDFIELDS` becomes the 19 settings. Author descriptions for each. The enums are `ServeFiles` {`No`, `Always`, `Always and cached`, `Use CSP security`} (the display list measured on the instance) and `WSGIType` {`WSGI`, `ASGI`}.
  - Add `MATCHROLESARGUMENT` and its schema, as in `WebAppCreate`.
  - `SCREENACTIONS` adds `add-application-role`, `remove-application-role`, `add-matching-role` and `remove-matching-role`. `SCREENVALUES` is `…-application-role=Role` and `…-matching-role=MatchRole:Role`.
  - `ScreenActionDelta` builds the complete `MatchRoles` from the fresh read, plus or minus one target role in the entry whose `MatchRole` is `""` (application) or the named one (matching). It creates or drops an entry as needed.
    - Refused: an empty value, an add already held, a remove not held, and an unknown role (404 through the port), as `UserUpdate` refuses.
  - `ArgumentProblem` → `Create.Validate` update mode.
  - Update the `DESCRIPTION`.
- `S/Area/WebApp/Create.cls`:
  - `Validate` gains an update mode over the 19 plus MatchRoles.
  - Rules: lengths from `FormRules` `LENGTHFIELDS`, integer timeouts ≥ 0, the enums, a known AutheEnabled mask, strings in the CORS arrays, a GroupById length, and `MatchRolesViolation`.
- `S/Area/WebApp/FormRules.cls`:
  - `HandleForm` with `?name=` also answers `application`, which is `WebAppUpdate`'s fresh read through its own port and `ReadType`.
  - A missing application is 404 `WEBAPP.NAME.ABSENT`, appended to `Api/Error.cls`.
- `S/Area/WebApp/WebAppSave.cls` (new), plus `S/Api/Router.cls`:
  - Add `PUT /web-applications/:id` → `HandleUpdate`/`Update`, in `UserSave`'s order through `WebAppUpdate`.
  - The route goes after `/web-applications/form` and `/name` and before `POST`.
- `S/Port/AdminPort.cls`:
  - For a `WebApp.App` `PUT` against an existing application, read `Security.Applications` `Type` in `%SYS` before the vendor call.
  - When the call leaves `Type` different from that value, re-apply it with `Security.Applications.Modify`, under the same `%Admin_Secure` gate.
  - This is AD-27's fifth named case (see Design Notes).
- `S/Kernel/Proposal/Mint.cls` (DW-1577): after the `StateDiff` rows, a non-create tool that sends a body and has zero diff rows is refused through `Refuse` with 400 `TOOL.ARGUMENTS` ("nothing would change"), and no proposal row is written.
- `S/Kernel/Proposal/Confirm.cls` (DW-1493):
  - For a create tool, the id value sent to `ReadAt`/`ApplyAt` is the stored argument under the tool's `IdArgument()`.
  - The canonical id stays the fallback when that argument is absent.
  - `TargetRef`, the lock and the sibling cancel stay canonical.
- Descriptors, registry and mirror: `S/Screen/Descriptor/WebAppList.cls`, `WebAppForm.cls`, `S/Screen/Registry.cls`, `ui/tools/screen-mirror.mjs`.
  - WebAppList declares the four role actions with the new rule `ocupilot-application-roles`, appended to `SELFPROTECTIONRULES` and to `IMPLEMENTED_SELF_PROTECTION_RULES`.
  - WebAppForm declares 3 `suggestedPrompts` and an editor label.
  - Regenerate the mirror.
- Tests:
  - `S/Test/WebAppSave.cls` (new): each matrix row from "Two-field save" to "Privileged role", covering both the Save and the screen actions, plus the form read's `application` and 404. The refused legs run through `Test.HeldPutPort`.
  - `Test/ProposalMint.cls`: DW-1577 for `webapp.list.update` and one other merge tool.
  - `Test/ProposalCreate.cls`: DW-1493 for the web-app and user creates.
  - `Test/RefusalCopy.cls`: the three new `…REASON` legs, plus a leg equating `Error.ReasonForViolation(AGENTCREDTYPEUNAVAILABLE)` with `#REASONAGENTCREDTYPEUNAVAILABLE`.
  - Update `ToolWrite.cls:150` and `Prohibited.cls:355` to the widened set.

Client tasks:

- `U/areas/web-applications/web-app-editor.page.ts` and `web-app-editor.store.ts` (new), each with a `.spec.ts`:
  - Mirror `UserEditorPage` and `UserEditor`: load `GET /web-applications/form?name=`, follow `NavigationEnd`, save changed fields to `PUT`, then the summary, opening the tab, "Saved", the `FormDirty` guard, a clean re-read on an event, and roles-only while dirty.
  - Tabs:
    - General: the 19 settings minus CORS, plus the fixed fields read-only with `webAppEditorFixedFields`. The type is derived as the create page derives it: REST if DispatchClass, Python if WSGIAppName, else CSP.
    - Application Roles: held roles with Remove, and a role select with Assign.
    - Matching Roles: each entry's targets with Remove, and match-role and target selects with Assign.
    - Cross-Origin Settings.
  - The auth fieldset is captioned with the `UNAUTHENTICATED` sentence.
  - On an application `serves-ocupilot` names, fields and Save are drawn refused with `webAppServesOcuPilotRefusal`, and role controls with the `ocupilot-application-roles` sentence.
  - Import `absorbRules` from `create-form.store.ts`; do not copy it.
- `U/shell/screen-action-handler.ts`:
  - `startFor` takes an optional trailing `values: ActionValues`, sent as the action's declared values (the `role` argument stays for 9.1).
  - The four role actions go under WebAppList in `UNDRAWN_ACTIONS`.
- `U/core/self-protection.ts` plus `ui/tools/self-protection.test.mjs`:
  - The `ocupilot-application-roles` rule has the `serves-ocupilot` predicate and answers `webAppPrivilegeGrantRefusal`.
  - Add pairs for PRIVILEGEGRANT, UNAUTHENTICATED and AUTHORIZATION, and for the Error.cls credtype reason (its `Parameter REASON… =` line).
- `U/shell/screen-outlet.ts` and `U/core/navigation.ts`: `DESCRIPTOR_EDIT_PAGES` gains `WebAppForm: WebAppEditorPage`, and WebAppForm leaves `CREATE_ONLY_FORMS`.
- `U/areas/web-applications/create-form.page.ts` and `.store.ts`: replace the retain handoff with the editor's `arriveSaved(id)` before `navigateByUrl`, as `user-create-form.page.ts:488` does (DW-1490).
- `ui/src/styles/_components.scss` (appended rule, DW-1596):
  - Every element whose direct child is `.ocu-form-page`, reached under `app-screen-outlet`, is a column flex host with `flex: 1 1 auto` and `min-height: 0`.
  - First verify the outlet's DOM chain. Do not edit the existing list.
- `U/core/strings.ts` and the EXPERIENCE.md Fixed-strings rows (appended, `[ADDED 2026-09-24 - see the story change log]`):
  - the tab labels (reuse keys where they exist) and the new field labels;
  - `webAppEditorFixedFields` ("Which code answers at this address, and where it runs from, are set when the application is created.");
  - `webAppPrivilegeGrantRefusal` and the `UNAUTHENTICATED`/`AUTHORIZATION` sentences;
  - the credtype sentence (`agentCredTypeUnavailable`);
  - the 3 prompts.
- DW-1595, both documentation-only:
  - `U/shell/toast-host.ts:12-22,48-52`: the prose names the form-bar lift in `_components.scss` and drops the contention paragraph.
  - DESIGN.md:1210, applying the Design Notes wording with an `[AMENDED 2026-09-24 - Story 9.2, DW-1595]` marker. It is a Rule 5 tier-1 amendment; the lead reports it.

Browser tasks:

- `ui/browser/web-applications-editor.browser-spec.mjs` (new):
  - The name cell opens the editor with its 4 tabs.
  - A two-field Save reads back through `docker exec`, and the toast "Open in Web applications" lands on the list, where the row shows the new Resource without a reload (AC2).
  - A tab error shows its dot and name. The leave guard holds.
  - Assigning `%All` shows only the unauthenticated line.
  - `/api/ocupilot` is drawn refused.
  - The visual gate, and the bar flush at 1440x900 with no scrolling.
- `users-editor.browser-spec.mjs`: drop the `scrollIntoView` workaround at :392 and assert the bar is flush without scrolling (DW-1596).
- `web-applications.browser-spec.mjs` AC5: re-point the name link to `…/list/edit/<id>`.
- `web-applications-create.browser-spec.mjs` AC2: after the create, the editor's own bar reads "Saved". A hard reload of that URL shows the created values (DW-1490).

**Acceptance Criteria:**

- **Given** a web application row, **when** its name is opened, **then** `web-applications/list/edit/<id>` shows the tabs General, Application Roles, Matching Roles and Cross-Origin Settings. Together they cover type, enabled, namespace, default application, dispatch class, resource, group by id, authentication methods, session timeout, JWT, CORS, CSP file settings, serve files, Python protocol, and application and matching roles.
- **Given** a Save, **when** it completes, **then** the Web applications list reflects it without a manual refresh, through the change-event bus.
- **Given** one of OcuPilot's own applications, **when** a Save disables it or a role action sets application or matching roles on it, **then** the instance refuses with `PROHIBITED.SERVINGPATH` or `PROHIBITED.PRIVILEGEGRANT`, each sentence pinned by `RefusalCopy` and `self-protection.test.mjs` (DW-1502).
- **Integration:** **given** `form-tabs`, `startFor` and `DESCRIPTOR_EDIT_PAGES`, **when** `WebAppEditorPage` shows a refusal on an unselected tab and assigns an application role, **then** the tab opens with its dot and ", 1 error", and the role reaches the instance through the list's own AD-53 action route. The browser spec observes both.

## Spec Change Log

## Review Triage Log

## Design Notes

**Governing ADs:** AD-3, AD-4, AD-5, AD-6, AD-8, AD-10, AD-13, AD-14, AD-19, AD-21, AD-27, AD-36, AD-39, AD-51, AD-53, AD-54, AD-55 and AD-56.

**Consumes:**

- 9.1's `form-tabs`, `screen-action-dialogs`/`startFor`, `DESCRIPTOR_EDIT_PAGES`, the `suggestedPrompts` key, the toast lift and the `UserSave` order.
- 8.1's `/web-applications/form` rules and create page.
- 7.1's web-app row actions and self-protection.
- 5.5's reviewed-few predicates.

**Consumed-by:**

- 9.3 reuses the generalized `startFor(…, values)`.
- 9.3, 9.5 and 9.8 inherit the form-page flex rule (DW-1596).

**Why these fields are read-only.** `WebApplication()`'s asymmetric arms implement DW-1207, the owner's floor-blocking decision of 2026-09-19: no confirmation repoints the code that answers at an address. AD-10's 2026-09-23 amendment reverses privilege grants only.

- The editor therefore shows DispatchClass, the WSGI app and callable, NameSpace, Package and SuperClass read-only.
- Path and WSGIAppLocation are read-only because they name server paths (AD-21 permits a directory only on a create).
- Of all authentication changes, only clearing Unauthenticated passes, as shipped.

**Owner call available at the spec gate:** if "developer tool first" is meant to cover DW-1207's predicates too, the delta is:

- drop the `UNAUTHENTICATED`, `AUTHORIZATION` and `DISPATCH` arms and add those fields to the 19;
- drop `webAppEditorFixedFields` for them;
- amend AD-10.

This plan takes the recorded decision.

**Recommended amendments (the lead's at the spec gate):**

- **AD-27, a fifth named case after the fourth:**

  > The fifth case [AMENDED 2026-09-24, Story 9.2 spec gate]: `WebApp.App` `PUT` on an existing application — the admin API cannot keep an application's `Type`: `MergeJsonAndProperties` sets `Type` to CSP on every PUT, and `Security.Applications.Modify` then clears a system application's bit 0 (measured on `ocupilot-ci` 2026-09-24: 3 became 2). `AdminPort` reads `Security.Applications` `Type` before the vendor call and re-applies it after, under the same `%Admin_Secure` gate; nothing above the port knows.

- **DESIGN.md:1210** (DW-1595) becomes:

  > …at the bottom-right of the content area — `{spacing.4}` above the status bar, or above the form bar on a form page so no toast covers Save or Cancel — and offset from the right edge by the panel's live width…

- **New Fixed-strings rows** for the five published refusal sentences, `webAppEditorFixedFields`, the tab labels and the prompts.

**Ledger inbox:**

- Addressed: DW-1490, DW-1493, DW-1502, DW-1577, DW-1595 and DW-1596.
- Declined: none.
- DW-1502's credtype half pins the existing `Error.cls` parameter and edits no Epic 10 file.

## Verification

**Commands:**

- `(loop)` `cd ui && node --test tools/self-protection.test.mjs tools/navigation.test.mjs tools/strings.test.mjs tools/screen-mirror.test.mjs tools/field-lists.test.mjs`. Expected: green.
- `(loop)` `cd ui && npm run test:components`. Expected: green, including the `web-app-editor.*.spec.ts` specs and `screen-action-handler.spec.ts`.
- `(loop)` `node ui/tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.<X>`, one run at a time, for X = `WebAppSave`, `ProposalMint`, `ProposalCreate`, `RefusalCopy`, `ToolWrite`, `Prohibited`, `ProhibitedByEffect`, `ProhibitedRoute`, `WebAppCreate`, `WebAppWire` and `Descriptor`. Expected: 0 failures.
- `(loop)` `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`, then with `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci`, `node --test --test-concurrency=1` one file at a time over these specs. Expected: green.
  - web-applications-editor, web-applications, web-applications-create, web-applications-actions
  - users-editor, users, users-create, users-actions
  - device-editor, roles-create, wallet-secret, x509-import, switches, definitions, toast
- `(loop)` `uv run scripts/check-objectscript.py` and `bash scripts/lint-docs.sh`. Expected: clean. The initial bundle stays under 1378kB.
- `(once, before dev_complete)` `node ui/tools/ci-runner.mjs --container ocupilot-ci --package OcuPilot.Test`. Expected: 0 failures, excluding only the four arming-variable classes this throwaway refuses.

**Mutations (Rule 19):** each AC and matrix row gets one `mutation:` line here, written by the pass that adds its pinning test.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none
