---
title: 'Story 9.2: The web application editor'
type: 'feature'
created: '2026-09-24'
status: 'done'
baseline_revision: '1bcbfb7f1c7edd67e72f82d396736631f7fa25ed'
baseline_commit: '1bcbfb7f1c7edd67e72f82d396736631f7fa25ed'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-9-context.md'
warnings: ['oversized']
deferred:
  - summary: 'The initial bundle is 1,397,013 bytes against the 1378kB warning budget, so `build-output.test.mjs` DW-371 is red; the editor adds about 37 kB and is under the 1500kB stop. Raising the budget or lazy-loading the editor is the lead''s call; angular.json is out of this story''s footprint.'
    evidence: 'npm run build: "bundle initial exceeded maximum budget ... by 19.01 kB"; HEAD baseline 1,360,009 bytes.'
    location: 'ui/angular.json'
  - summary: 'The Verification loop names `OcuPilot.Test.ProposalMint`, which is a fixture rather than a TestCase; the DW-1577 legs live in `OcuPilot.Test.Proposal`.'
    evidence: 'OcuPilot.Test.ProposalMint does not extend %UnitTest.TestCase.'
    location: 'src/OcuPilot/Test/Proposal.cls'
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

**Orchestrator ruling 2026-09-24 (binding; supersedes every line below that keeps DW-1207's refusals on other applications):** option (b). AD-10 is amended (see its "Weakening or repointing one of OcuPilot's own web applications" bullet) and DW-1207 is closed by-design.

- **Drop the `UNAUTHENTICATED`, `AUTHORIZATION` and `DISPATCH` arms for applications that are not OcuPilot's own.** `AutheEnabled` (all bits), `Resource`, `DispatchClass`, `NameSpace`, the Python application and callable (`WSGIAppName`, `WSGICallable`), `Package` and `SuperClass` are editable on the screen and settable by the agent, beside the 19.
- **Each such change is minted destructive with its effect named** - "reachable without signing in", "no authorization resource", "a different class now answers this address" - shows a consequence line at the field on the screen, and takes the typed-name confirmation on the card. Reuse the existing unauthenticated consequence (`WEBAPP.UNAUTHENTICATED`, `privilegedGrantEffectUnauthenticated`); add a Fixed-strings row (tier-1) only for a sentence that does not exist yet.
- **They stay refused on OcuPilot's own applications** (its API, static application and every application the installer creates), on the agent path and the screen alike - AD-10's serving-path self-protection.
- **`Path` and the Python location (`WSGIAppLocation`) stay read-only** (AD-21; WSGI locations stay contained under the fixed root, DW-1495).
- **Tests that fail when the ruling is wrong:** for a non-OcuPilot application, each of the three changes is proposable, destructive, and applies on the throwaway once confirmed; for an OcuPilot application, each is still refused on both callers; removing the destructive marking reddens a test.
- DW-1597 (an editor's own Save raising a toast) stays on the merge-gate sheet - not decided here.

**Always:**

- Save follows `UserSave.Update`'s order. The tool's pair set first. Then a fresh read, where an absent application is a 404 and nothing is sent. Any body key outside `PERMITTEDFIELDS` is 400 `PORT.FIELD.UNEXPECTED`. Then the rules, the merge (the complete set, AD-4), the prohibited set (before any port call), and the send.
- One rule copy serves both callers. `WebAppUpdate.ArgumentProblem` and the Save call the same update-mode `Create.Validate`.
- The editable settings are exactly these 25: AutheEnabled, AutoCompile, CorsAllowlist, CorsCredentialsAllowed, CorsHeadersList, Description, DispatchClass, Enabled, GroupById, IsNameSpaceDefault, JWTAccessTokenTimeout, JWTAuthEnabled, JWTRefreshTokenTimeout, LockCSPName, NameSpace, Package, Recurse, Resource, ServeFiles, ServeFilesTimeout, SuperClass, Timeout, WSGIAppName, WSGICallable and WSGIType.
  - `PermittedChangeFields("web-application")` holds those 25 plus `MatchRoles`.
- The General tab shows Name, the derived type, `WSGIAppLocation` and `Path` read-only, under the one caption `webAppEditorFixedFields`.
- On any other application, three effects are permitted and marked, never refused. Adding the Unauthenticated bit is `WEBAPP.UNAUTHENTICATED`. Clearing a resource the application held is `WEBAPP.NORESOURCE`. Changing any of DispatchClass, NameSpace, WSGIAppName, WSGICallable, Package or SuperClass is `WEBAPP.REPOINTED`.
  - An agent proposal carrying one is minted destructive. The card states one consequence sentence; the precedence is in Design Notes.
  - The editor states each effect's line once, at its own field.
- Application roles on any other application are permitted, `%All` included.
  - The agent's proposal is minted destructive and names the privilege (`GrantsPrivilegeByEffect`, unchanged).
  - The editor shows `privilegedGrantEffect` under a privileged choice. It shows `privilegedGrantEffectUnauthenticated` instead when the application is unauthenticated, as read or as the unsaved form stands: one line, never two.
- On OcuPilot's own applications, the first predicate that matches decides, in this order:
  - a roles change is `PROHIBITED.PRIVILEGEGRANT`;
  - adding Unauthenticated is `PROHIBITED.UNAUTHENTICATED`;
  - clearing its resource is `PROHIBITED.AUTHORIZATION`;
  - changing any of the six code fields is `PROHIBITED.DISPATCH`;
  - every other change, disable included, is `PROHIBITED.SERVINGPATH`.
  - The editor draws the whole form refused beforehand, with the serving-path sentence, and draws the role controls refused with the privilege-grant sentence.
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
- No card-side typed-name field here: Story 14.7 draws it for every destructive proposal, and this story sets `destructive` (see Design Notes).
- No private keys in any file, and no full browser suite locally.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Two-field save | `PUT /web-applications/<id>` `{Description, Timeout}` on a probe application with CORS, JWT and ServeFiles set | 200. The vendor receives the complete set, and every other read field reads back unchanged. One `updated` event. | — |
| Undeclared key | body carries `MatchRoles`, `Path` or `WSGIAppLocation` | 400 `PORT.FIELD.UNEXPECTED` naming each key; nothing sent | — |
| System application | Save on a probe created with `Type` 3 | `Type` still reads 3 afterwards. Measured on `ocupilot-ci`: the vendor PUT forces `Type` 2 (`WebApp.App.MergeJsonAndProperties:153`) and `Modify` clears the system bit. | a failed restore answers the port's fault |
| Own app, AC3 | Save `{Enabled:false}` on `/api/ocupilot`; the add-application-role action with `%All` on `/ocupilot` | 403 `PROHIBITED.SERVINGPATH`; 403 `PROHIBITED.PRIVILEGEGRANT`; nothing sent | each reason is its `…REASON` parameter |
| Weakening elsewhere | agent proposes adding 64 to AutheEnabled, `Resource:""`, and a new `DispatchClass`, each on a probe; then confirms; the same three as Saves | each proposal is destructive with consequence `WEBAPP.UNAUTHENTICATED` / `WEBAPP.NORESOURCE` / `WEBAPP.REPOINTED`; each confirm and each Save is 200 and reads back | — |
| Weakening own | the same three changes on a recorded own path, by confirm and by Save | 403 `PROHIBITED.UNAUTHENTICATED` / `AUTHORIZATION` / `DISPATCH`; nothing sent | — |
| Several effects | one proposal adds 64, clears Resource and changes DispatchClass; the editor makes the same three changes | the proposal is destructive with the one consequence `WEBAPP.UNAUTHENTICATED` and three diff rows; the editor shows three lines, one at each field | — |
| Privileged role | editor adds application role `%All` to an unauthenticated probe; the agent proposes `MatchRoles` with `%All` on it | the editor shows `privilegedGrantEffectUnauthenticated` only; the proposal is destructive with `WEBAPP.UNAUTHENTICATEDPRIVILEGED` | — |
| DW-1490 | hard reload of `web-applications/list/edit/<id>` | the editor reads the application and shows its values | absent id → the editor's absent state (404 `WEBAPP.NAME.ABSENT`) |
| DW-1493 | agent create of `/csp/CaseProbe92/` confirmed; agent create of user `CaseProbe92` confirmed | the vendor stores `/csp/CaseProbe92` and `CaseProbe92` as typed. `TargetRef` stays canonical. | — |
| DW-1577 | agent `webapp.list.update` `{Enabled:<current>}`; any merge tool with no changed row | 400 `TOOL.ARGUMENTS`, no proposal row | — |
| DW-1596 | the web-application editor and the user editor at 1440x900 | the form bar's bottom equals the shell content bottom (±1px) without scrolling; the page itself scrolls | — |

</intent-contract>

## Code Map

S = `src/OcuPilot/`, U = `ui/src/app/`.

Server:

- `S/Kernel/Proposal/Prohibited.cls`:
  - Codes and docs `UNAUTHENTICATED`/`AUTHORIZATION`/`DISPATCH`/`PRIVILEGEGRANT` at :96-113; `SERVINGPATHREASON` style at :65; `ReasonFor` at :324-347 (four inline literals at :326-329).
  - `PermittedChangeFields` at :410-424 (web app at :413); `AlwaysProhibitedFields` at :447-451 (answers `DispatchClass`).
  - `Prohibits` at :561-660; `Created` at :721; `WebApplication()` at :817-894 (own-app arms at :824-842, the three shipped arms at :846-857, unreviewed loop at :858-866).
  - `GrantsPrivilegeByEffect` at :1622, `Changed` at :2112, `ServesOcuPilot` at :2241, `Rendered` at :2301, `ClearsUnauthenticatedOnly` at :2320 (retired by this story).
- `S/Kernel/Proposal/Mint.cls`:
  - `CONSEQUENCEPRIVILEGED` at :63. Consequence and destructive at :300-306; `DestructiveTool` at :407; `ConsequenceOf` at :640-648.
  - Create vs merge at :183-193, `Merge` at :433-501, `StateDiff` rows at :221-241 (nothing checks an empty diff after them). `Refuse` (400 `TOOL.ARGUMENTS`) at :791-799.
- `S/Screen/Tool/WebAppUpdate.cls` (115 lines): `EXCLUDEDFIELD MatchRoles` :41, `EXCLUDEDDISPATCH` :45, `PERMITTEDFIELDS` :51, `SCREENACTIONS` :57, `ExcludedFields` :83. `ArgumentProblem`/`ScreenActionDelta` inherited from `Write.cls` (:739, :537); `ScreenActionValueNames` (`Write.cls:509`) parses `a=X:Y`.
- `S/Screen/Tool/WebAppCreate.cls`: `MATCHROLESARGUMENT` :64, consequence codes :87-92, `Consequence` :155, `InputSchema` :171-184, `ArgumentProblem` :191. `UserUpdate.cls` is the precedent for an authored list argument plus role actions (`ROLESARGUMENT` :69, `SCREENVALUES` :59, `ScreenActionDelta` :213-260).
- `S/Screen/Tool/Classification.cls:25-35,45-50`: doc prose that names the four reviewed fields and an unadvertised `DispatchClass`. `ToolFields.cls:198` confirms all 25 are ordinary top-level literals.
- `S/Area/WebApp/`: `FormRules` (`LENGTHFIELDS` :68, `HandleForm` :90-127 does not read `?name=`), `Create.Validate` :227-295 (type-shape rules :250-275), `MatchRolesViolation` :297. Precedents: `Area/Permissions/UserCreateRules.HandleForm` :370-427 with `Account()` :480-495, and `Area/Permissions/UserSave.cls` (`HandleUpdate`, `Update`, `Gate`).
- `S/Api/Router.cls`: web-app routes at :95-97; precedent `PUT /users/:id` at :100, handler :322-329.
- `S/Kernel/Proposal/Confirm.cls`: `FingerprintMatches` :570 sets the id from `EntityRef.Parse(targetRef)` :585-587 and returns in the create branch :598-606. The stored arguments (parsed :615) carry the typed name under `IdArgument()`. Creates: WebApp, User, Role, Resource (`EntityRef.cls` `IDRULES` :59).
- `S/Port/AdminPort.cls`: the one place `WebApp.App` PUTs pass (AD-2, AD-27).
- `S/Api/Error.cls`: `REASONAGENTCREDTYPEUNAVAILABLE` :1285 (code :421, mapped :1061).
- Tests the ruling inverts: `Test/Prohibited.cls:136-150` (three refusal legs on a probe), `:427`, `:435`, `:442` (the `View` leg asks for a `DispatchClass` change); `Test/ProhibitedByEffect.cls:128-170` (field sweep), `:200` (CorsAllowlist leg), `:210-240` (`TestOnlyClearingUnauthenticatedAccessIsProposable`), `:489` (own `NameSpace` case); `Test/ProhibitedRoute.cls:502-522` (`Weakened`), `:975`, `:1022-1045`. Also `Test/ToolWrite.cls:150`, `Test/Prohibited.cls:355`, `Test/RefusalCopy.cls` (legs :24-64), `Test/WebAppLocation.cls:151-164` (create consequence).
- `S/Screen/Descriptor/`: `WebAppForm.cls` has no `suggestedPrompts` (`UserForm.cls:45` is the precedent); `WebAppList.cls` rowActions enable, disable, delete, all `serves-ocupilot`; `Screen/Registry.cls:2244` `SELFPROTECTIONRULES`.

Client:

- `U/areas/web-applications/create-form.page.ts` (792 lines) and `create-form.store.ts` (730 lines): field template and classic order; `absorbRules` :673-730 (export it); consequence precedence :325-366 and :525-547 (`unauthenticatedEffect`, `privilegeEffect`); the retain handoff :708-723 and :787, which DW-1490 replaces.
- `U/areas/permissions/user-editor.page.ts` (923 lines) and `user-editor.store.ts` (563 lines), the pattern: tabs :145-446, form bar :448-460, `routeId`/`NavigationEnd` :516-523, change bus :525-528, `startFor` :845, `onApplied` :852, `afterRefusal` :883; store `changedFields` :296, `arriveSaved`/`open` :332-351, `refresh` :355, `save` :410-451.
- `U/core/proposal-view.ts:120-138`: consequence codes and `consequenceSentence`; `U/shell/proposal-card.ts:633`.
- `U/shell/screen-action-handler.ts`: `startFor(descriptor, actionId, target, rowFields, sink, role='')` :395, `VALUE_ACTIONS` :99, `UNDRAWN_ACTIONS` :104, `send` :533.
- `U/shell/screen-outlet.ts:123-125` (`DESCRIPTOR_EDIT_PAGES`), `U/core/navigation.ts:202-205` (`CREATE_ONLY_FORMS`).
- `U/core/self-protection.ts:23,99-105`; `ui/tools/screen-mirror.mjs:313` (`IMPLEMENTED_SELF_PROTECTION_RULES`); `ui/tools/self-protection.test.mjs` (`stringValue` :55-60, pairs :110-147).
- `U/core/strings.ts:1368` `webAppUnauthenticatedEffect`, :1408-1412 `privilegedGrantEffect*`.
- `ui/src/styles/_components.scss`: flex host list :734-747, `.ocu-form-page` :2841, `.ocu-form-bar` :2962, toast lift :5512-5514.
- DW-1595 prose: `U/shell/toast-host.ts:12-22,48-52`; `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/DESIGN.md:1210`.
- EXPERIENCE.md Fixed strings :254-468 (row format :467; `webAppUnauthenticatedEffect` :400, `privilegedGrantEffect*` :403-404; IA row :129).
- Browser specs: `users-editor.browser-spec.mjs` (helpers :141-183, visual gate :323-374, geometry :379-410 with DW-1596's `scrollIntoView` at :392); `web-applications.browser-spec.mjs:231` (AC5 name link); `web-applications-create.browser-spec.mjs:250-295` (AC2).

## Tasks & Acceptance

**Execution:**

Server tasks:

- `S/Kernel/Proposal/Prohibited.cls`:
  - `PermittedChangeFields("web-application")` becomes the 25 settings plus `MatchRoles`. `AlwaysProhibitedFields("web-application")` answers `""`.
  - Add `Parameter CODEFIELDS = "DispatchClass,NameSpace,WSGIAppName,WSGICallable,Package,SuperClass"`, and replace `ClearsUnauthenticatedOnly` with `AddsUnauthenticated(pPayload, pTarget)`. It is true when the payload's mask has bit 64 and the target's does not. A payload value that is not a whole number counts as adding the bit.
  - `WebApplication()`: on an own application, evaluate the five predicates in the intent's order. On any other application, only the unreviewed-field loop runs.
  - Add public `WeakensByEffect(pType, pPayload, pTarget, Output pEffect) As %Status`. For a web application, `pEffect` is the first of `EFFECTUNAUTHENTICATED` ("WEBAPP.UNAUTHENTICATED", when `AddsUnauthenticated`), `EFFECTNORESOURCE` ("WEBAPP.NORESOURCE", when the target's `Resource` is set and the payload's is empty) and `EFFECTREPOINTED` ("WEBAPP.REPOINTED", when any `CODEFIELDS` value differs). Otherwise `pEffect` is `""`.
  - Reasons: add `PRIVILEGEGRANTREASON` (the existing sentence) and these three:
    - `UNAUTHENTICATEDREASON`: "OcuPilot serves itself through this web application. Making it reachable without signing in is not available here."
    - `AUTHORIZATIONREASON`: "OcuPilot serves itself through this web application. Removing the resource that guards it is not available here."
    - `DISPATCHREASON`: "OcuPilot serves itself through this web application. Changing which code answers at its address is not available here."
    - `ReasonFor` answers `..#XREASON` for all four. Rescope the three codes' docs to OcuPilot's own applications.
- `S/Kernel/Proposal/Mint.cls`:
  - After `GrantsPrivilegeByEffect`, a non-create call asks `WeakensByEffect(tType, tPayload, tFresh, .tEffect)`.
  - `destructive` becomes `DestructiveTool || tPrivileged || (tEffect '= "")`.
  - `ConsequenceOf` gains `pEffect`. It passes `pEffect` to the tool's `Consequence`, and when that answers `""` it falls back to `CONSEQUENCEPRIVILEGED` if privileged, else to `pEffect`.
  - DW-1577: after the `StateDiff` rows, a non-create tool that sends a body and has zero diff rows is refused through `Refuse` with 400 `TOOL.ARGUMENTS` ("nothing would change"). No row is written.
- `S/Screen/Tool/WebAppCreate.cls`: `Consequence` gains an ignored `pEffect As %String = ""`.
- `S/Screen/Tool/WebAppUpdate.cls`:
  - `PERMITTEDFIELDS` becomes the 25. Delete `EXCLUDEDDISPATCH`; `ExcludedFields` answers `MatchRoles` alone.
  - Author descriptions for each field. The enums are `ServeFiles` {`No`, `Always`, `Always and cached`, `Use CSP security`} (the display list measured on the instance) and `WSGIType` {`WSGI`, `ASGI`}.
  - The three effect fields' descriptions say the change is confirmed as a delete is, and is refused on OcuPilot's own applications.
  - Add `MATCHROLESARGUMENT` and its schema, as `WebAppCreate` has them.
  - `SCREENACTIONS` adds `add-application-role`, `remove-application-role`, `add-matching-role` and `remove-matching-role`. `SCREENVALUES` is `…-application-role=Role` and `…-matching-role=MatchRole:Role`.
  - `ScreenActionDelta` builds the complete `MatchRoles` from the fresh read, adding or removing one target role in the right entry: `MatchRole` `""` for application roles, the named match role for matching roles. It creates or drops the entry as needed. It refuses what `UserUpdate` refuses: an empty value, an add already held, a remove not held, and an unknown role (404 through the port).
  - `Consequence(pPayload, pPrivileged, pEffect)` answers `WebAppCreate.Consequence(pPayload, 1)` when privileged, and `""` otherwise. The mint then falls back to `GRANT.PRIVILEGED` or to `pEffect`, whose own order `WeakensByEffect` sets.
  - `ArgumentProblem` calls `Create.Validate` in update mode. Rewrite the class doc and `DESCRIPTION` to the 25; no DW-1207 narration.
- `S/Screen/Tool/Classification.cls`: doc only. The two sentences naming "four of these rows" and an unadvertised `DispatchClass` state the 25 instead.
- `S/Area/WebApp/Create.cls` and `FormRules.cls`:
  - `Validate` gains an update mode over the 25 plus MatchRoles. Its type-shape rules read the merged body (the fresh read with the changes applied), so a Python application still needs its name, its fresh location and its type, and REST with Python is a conflict.
  - The other rules: NameSpace non-empty; lengths from `LENGTHFIELDS`, which appends `Package` and `SuperClass`; integer timeouts ≥ 0; the enums; a known AutheEnabled mask; strings in the CORS arrays; a GroupById length; and `MatchRolesViolation`.
  - `HandleForm` with `?name=` also answers `application`: `WebAppUpdate`'s fresh read, through its own port and `ReadType`. A missing application is 404 `WEBAPP.NAME.ABSENT`, appended to `Api/Error.cls`.
- `S/Area/WebApp/WebAppSave.cls` (new), plus `S/Api/Router.cls`: `PUT /web-applications/:id` goes to `HandleUpdate`/`Update`, in `UserSave`'s order, through `WebAppUpdate`. The route sits after `/web-applications/form` and `/name`, and before `POST`.
- `S/Port/AdminPort.cls`: for a `WebApp.App` `PUT` on an existing application, read `Security.Applications` `Type` in `%SYS` before the vendor call. When the call changes it, re-apply it with `Security.Applications.Modify` under the same `%Admin_Secure` gate. This is AD-27's fifth case.
- `S/Kernel/Proposal/Confirm.cls` (DW-1493): for a create tool, the id sent to `ReadAt`/`ApplyAt` is the stored argument under the tool's `IdArgument()`, with the canonical id as the fallback. `TargetRef`, the lock and the sibling cancel stay canonical.
- `S/Screen/Descriptor/WebAppList.cls`, `WebAppForm.cls`, `S/Screen/Registry.cls` and `ui/tools/screen-mirror.mjs`:
  - WebAppList declares the four role actions with the new rule `ocupilot-application-roles`. The rule is appended to `SELFPROTECTIONRULES` and to `IMPLEMENTED_SELF_PROTECTION_RULES`.
  - WebAppForm declares 3 `suggestedPrompts` and an editor label.
  - Regenerate the mirror.
- Tests:
  - `S/Test/WebAppSave.cls` (new): the Save and the screen actions over the matrix rows "Two-field save" through "Own app, AC3", plus the form read's `application` and its 404. The refused legs run through `Test.HeldPutPort`.
  - `S/Test/WebAppWeakening.cls` (new): the ruling's tests, run on a probe and on a probe path recorded as OcuPilot's own (`Kernel.State.WebApp.GuardedRecord`, as `ProhibitedRoute:664` does).
    - On the probe, for each of the three changes: the mint's row is destructive and carries its effect code. The confirm over the wire is 200 and the change reads back. The same change as a `PUT` Save is 200.
    - On the own path, the confirm and the Save are each 403 with their own code, and nothing is sent.
    - Legs for the "Several effects" and "Privileged role" rows.
  - Rewrite the inverted legs listed in the Code Map:
    - `Prohibited.cls:136-150`: permitted on a probe, and the own code on the recorded path.
    - `:427` and `:435`: an empty always-list, and DispatchClass among the change fields.
    - `:442`: ask for `Path` instead.
    - `ProhibitedByEffect`: the sweep keeps only fields outside the 26; the CorsAllowlist leg is permitted; the AutheEnabled cases assert `WeakensByEffect` (only an added 64 is marked); the `:489` own-NameSpace case expects `DISPATCH`.
    - `ProhibitedRoute`: delete `Weakened` and its three legs (superseded by `WebAppWeakening`), and fix the `:975` mutation text.
    - Also `ToolWrite.cls:150` and `Prohibited.cls:355`.
  - `Test/RefusalCopy.cls`: one leg per new `…REASON` (four), each its parameter and caller-neutral. Plus a leg equating `Error.ReasonForViolation(AGENTCREDTYPEUNAVAILABLE)` with `#REASONAGENTCREDTYPEUNAVAILABLE`.
  - `Test/ProposalMint.cls`: DW-1577, for `webapp.list.update` and one other merge tool. `Test/ProposalCreate.cls`: DW-1493, for the web-app and user creates.

Client tasks:

- `U/areas/web-applications/web-app-editor.page.ts` and `web-app-editor.store.ts` (new), each with a `.spec.ts`:
  - Mirror `UserEditorPage` and `UserEditor`. Load `GET /web-applications/form?name=` and follow `NavigationEnd`. Save the changed fields to `PUT`. Keep the summary, opening the tab, "Saved", the `FormDirty` guard, a clean re-read on an event, and roles-only refresh while dirty.
  - Tabs:
    - General: the 25 minus CORS, plus the fixed fields read-only under `webAppEditorFixedFields`. The type is derived live: REST if DispatchClass, Python if WSGIAppName, else CSP.
    - Application Roles: held roles with Remove, and a role select with Assign.
    - Matching Roles: each entry's targets with Remove, and match-role and target selects with Assign.
    - Cross-Origin Settings.
  - Consequence lines, one per effect, at its own field:
    - `webAppUnauthenticatedEffect` on the authentication fieldset when the form adds Unauthenticated.
    - `webAppNoResourceEffect` on Resource when the form clears a resource the read held.
    - `webAppRepointedEffect` once, at the first of the six code fields (in template order) that the form changes.
    - On the roles tabs, a privileged choice shows `privilegedGrantEffect`, or `privilegedGrantEffectUnauthenticated` when the read or the form holds Unauthenticated.
  - On an application `serves-ocupilot` names, fields and Save are drawn refused with `webAppServesOcuPilotRefusal`, and the role controls with `webAppPrivilegeGrantRefusal`.
  - Import `absorbRules` from `create-form.store.ts`; do not copy it.
- `U/core/proposal-view.ts`: add `CONSEQUENCE_NORESOURCE` and `CONSEQUENCE_REPOINTED`, mapped to their sentences. Add one `proposal-card.spec.ts` leg per code.
- `U/shell/screen-action-handler.ts`:
  - `startFor` takes an optional trailing `values: ActionValues`, sent as the action's declared values. The `role` argument stays for 9.1.
  - The four role actions go under WebAppList in `UNDRAWN_ACTIONS`.
- `U/core/self-protection.ts` plus `ui/tools/self-protection.test.mjs`:
  - The `ocupilot-application-roles` rule has the `serves-ocupilot` predicate and answers `webAppPrivilegeGrantRefusal`.
  - Add pairs `PRIVILEGEGRANTREASON`↔`webAppPrivilegeGrantRefusal`, and the `Error.cls` credtype `Parameter REASON… =` line ↔ `agentCredTypeUnavailable`.
- `U/shell/screen-outlet.ts` and `U/core/navigation.ts`: `DESCRIPTOR_EDIT_PAGES` gains `WebAppForm: WebAppEditorPage`, and WebAppForm leaves `CREATE_ONLY_FORMS`.
- `U/areas/web-applications/create-form.page.ts` and `.store.ts` (DW-1490): replace the retain handoff with the editor's `arriveSaved(id)` before `navigateByUrl`, as `user-create-form.page.ts:488` does.
- `ui/src/styles/_components.scss` (appended rule, DW-1596): every element whose direct child is `.ocu-form-page`, reached under `app-screen-outlet`, becomes a column flex host with `flex: 1 1 auto` and `min-height: 0`. Verify the outlet's DOM chain first, and do not edit the existing list.
- `U/core/strings.ts` and the EXPERIENCE.md Fixed-strings rows (appended, marked `[ADDED 2026-09-24 - see the story change log]`):
  - the tab labels (reuse keys where they exist) and the new field labels, `Package` and `SuperClass` among them;
  - `webAppEditorFixedFields`: "Where this application's files live is set when it is created.";
  - `webAppNoResourceEffect`: "No resource guards this application now, so anyone who can sign in can use it.";
  - `webAppRepointedEffect`: "A different class now answers this address.";
  - `webAppPrivilegeGrantRefusal` (the `PRIVILEGEGRANTREASON` sentence) and `agentCredTypeUnavailable`;
  - the 3 prompts.
- DW-1595, both documentation-only:
  - `U/shell/toast-host.ts:12-22,48-52`: the prose names the form-bar lift in `_components.scss` and drops the contention paragraph.
  - DESIGN.md:1210 gets the Design Notes wording and an `[AMENDED 2026-09-24 - Story 9.2, DW-1595]` marker. This is a Rule 5 tier-1 amendment, which the lead reports.

Browser tasks:

- `ui/browser/web-applications-editor.browser-spec.mjs` (new):
  - The name cell opens the editor with its 4 tabs.
  - A two-field Save reads back through `docker exec`. The toast "Open in Web applications" lands on the list, where the row shows the new Resource without a reload (AC2).
  - On a probe, ticking Unauthenticated, clearing Resource and changing DispatchClass each show their own line, the repointed line once. The Save applies all three, read back through `docker exec`.
  - A tab error shows its dot and name. The leave guard holds.
  - Assigning `%All` on an unauthenticated probe shows only the combined line.
  - `/api/ocupilot` is drawn refused.
  - The visual gate, and the bar flush at 1440x900 with no scrolling.
- `users-editor.browser-spec.mjs`: drop the `scrollIntoView` workaround at :392 and assert the bar is flush without scrolling (DW-1596).
- `web-applications.browser-spec.mjs` AC5: re-point the name link to `…/list/edit/<id>`.
- `web-applications-create.browser-spec.mjs` AC2: after the create, the editor's own bar reads "Saved", and a hard reload of that URL shows the created values (DW-1490).

**Acceptance Criteria:**

- **Given** a web application row, **when** its name is opened, **then** `web-applications/list/edit/<id>` shows the tabs General, Application Roles, Matching Roles and Cross-Origin Settings. Together they cover type, enabled, namespace, default application, dispatch class, resource, group by id, authentication methods, session timeout, JWT, CORS, CSP file settings, serve files, Python protocol, and application and matching roles.
- **Given** a Save, **when** it completes, **then** the Web applications list reflects it without a manual refresh, through the change-event bus.
- **Given** one of OcuPilot's own applications, **when** a Save disables it or a role action sets application or matching roles on it, **then** the instance refuses with `PROHIBITED.SERVINGPATH` or `PROHIBITED.PRIVILEGEGRANT`, each sentence pinned by `RefusalCopy` and `self-protection.test.mjs` (DW-1502).
- **Given** an application that is not OcuPilot's own, **when** the agent proposes, or a person saves, making it unauthenticated, clearing its resource or changing its dispatch class, **then** the proposal is destructive and names the effect, the editor states it at the field, and the change applies once confirmed or saved. **Given** OcuPilot's own, **then** each is refused with its own code on both callers.
- **Integration:** **given** `form-tabs`, `startFor` and `DESCRIPTOR_EDIT_PAGES`, **when** `WebAppEditorPage` shows a refusal on an unselected tab and assigns an application role, **then** the tab opens with its dot and ", 1 error", and the role reaches the instance through the list's own AD-53 action route. The browser spec observes both.

## Spec Change Log

- 2026-09-24 spec gate (lead): orchestrator ruling (b) on DW-1207 recorded in the intent contract; AD-10 amended; DW-1207 closed by-design by=orchestrator; AD-27 fifth named case (WebApp.App PUT `Type` restore) applied as recommended. Status reset to `draft` for a re-plan around the ruling.

## Review Triage Log

### 2026-09-24 — Review pass

Layers run: verification-gap, intent-alignment (edge-case-hunter not active in this build).

- verdicts: 22 findings — high 0, medium 7, low 7, false 8, maybe-false 0
- findings:
  - `[medium]` `[patch]` Four of the six `CODEFIELDS` never tested as a weakening change — added `ProhibitedByEffect.TestEveryCodeFieldIsMarkedElsewhereAndRefusedOnOcuPilotsOwn` over all six (REPOINTED elsewhere, DISPATCH on own); mutation line written.
  - `[medium]` `[patch]` Client `CODE_FIELDS` not pinned to server `CODEFIELDS` — parity test added to `ui/tools/self-protection.test.mjs`; mutation line written.
  - `[medium]` `[patch]` No denial test for `PUT /web-applications/:id`'s pair gate — added `WireSecurityRead.TestTheWebApplicationSaveRefusesACallerWithoutItsPairs`; mutation (bypass `Gate`) observed red, `/csp/user` unchanged.
  - `[medium]` `[patch]` Edit rules AUTHEUNKNOWN, TYPECONFLICT, text-field shape, MatchRoles shape and `Package` length unexercised — five rows added to `WebAppSave.TestTheEditsRulesRefuseEachFieldWithItsCode` (Package MAXLEN 64 measured on `ocupilot-ci`); mutation line written.
  - `[medium]` `[patch]` Editor's change-bus re-read unpinned — page-spec leg added publishing an odd spelling; mutation line written.
  - `[low]` `[reject]` Port type-restore failure paths untested — the paths are two guarded status checks; testing them needs a new fault-injecting port seam, and the success path is pinned. reopen_if: a WebApp.App PUT reported applied while `Security.Applications` reads a changed `Type`.
  - `[low]` `[patch]` `TestNoWriteToolAdmitsAnAlwaysProhibitedField`'s per-tool loops now run for no tool — doc comment states it; the emptiness itself is asserted.
  - `[low]` `[reject]` `TestASystemApplicationKeepsItsType` depends on the vendor demoting `Type` — the emptied-`TYPEKEPTTYPES` mutation was observed red on this build; a bypass precondition leg needs a new port seam.
  - `[low]` `[patch]` ACs 1-3, the Integration AC and six matrix rows had no `mutation:` line — each mutation applied, observed red, reverted; lines written under `## Verification`.
  - `[medium]` `[patch]` `toast.browser-spec.mjs` Integration leg depended on the previous test leaving the app disabled (DW-1577 refuses a no-op) — it now proposes the opposite of the value read from the instance; ran alone and in file order, green.
  - `[low]` `[reject]` The Verification loop names `OcuPilot.Test.ProposalMint`, a fixture — the fix edits this build's spec; recorded in `deferred:`.
  - `[false]` `[reject]` DW-1597 built into the editor's AC2 browser test — the spec's own browser task requires the toast leg; the diff changes no toast behavior.
  - `[medium]` `[patch]` DW-1493 tested at the port call, not the instance — measured that `Security.Applications` keeps the typed case; added `WebAppWeakening.TestAConfirmedCreateIsStoredAsTyped` (typed `/csp/OcuPilotProbeWeakeningCase/`, stored without the slash and in its case); mutation line written.
  - `[false]` `[reject]` Own-application detection differs client vs server — `self-protection.test.mjs` pins `OCUPILOT_APPLICATION_PATHS` equal to the install roster.
  - `[false]` `[reject]` The three new own-app `…REASON` sentences lack Fixed-strings rows — Design Notes settle it (no client surface draws them); the sentences they replaced were not published either.
  - `[false]` `[reject]` `agentCredTypeUnavailable` has no consumer — the spec task adds the key and pins it; its surface is Epic 10's.
  - `[low]` `[patch]` Agent-path weakening tests start at the kernel mint — `Mint` calls `ArgumentProblem`, so only schema validation was skipped; added `ToolWrite.TestARepointingCallMintsADestructiveProposal` through the dispatcher.
  - `[false]` `[reject]` Save gates on WebAppForm's pairs rather than the tool's — the same pattern as `UserSave` (UserForm), which the intent names; the Wire rosters show equal pairs.
  - `[low]` `[patch]` "One updated event" asserted as `some` — the page spec now asserts exactly one.
  - `[false]` `[reject]` E1 reading of "as read or as the unsaved form stands" — the intent's words are a disjunction.
  - `[false]` `[reject]` Label, prompts, deleted `ProhibitedRoute` legs outside the contract — each is a Tasks item; the label follows 9.1's UserForm precedent.
  - `[false]` `[reject]` Contended paths partly unverified — no Epic 10 exclusive path or `Test/{OpenAI,…,AgentConnection}*` class is in the diff (checked by name).

## Design Notes

**Governing ADs:** AD-3, AD-4, AD-5, AD-6, AD-8, AD-10 (as amended 2026-09-24), AD-13, AD-14, AD-19, AD-21, AD-27 (fifth case), AD-36, AD-39, AD-51, AD-53, AD-54, AD-55 and AD-56. AD-54 says "a field prohibited because it repoints a serving object is prohibited on a change". After AD-10's amendment, that serving object is one of OcuPilot's own applications, which is where `DISPATCH` still applies.

**Consumes:**

- 9.1's `form-tabs`, `screen-action-dialogs`/`startFor`, `DESCRIPTOR_EDIT_PAGES`, the `suggestedPrompts` key, the toast lift and the `UserSave` order.
- 8.1's `/web-applications/form` rules, create page and consequence codes.
- 7.1's web-app row actions and self-protection.
- 5.5's reviewed-few predicates.

**Consumed-by:**

- 9.3 reuses the generalized `startFor(…, values)`.
- 9.3, 9.5 and 9.8 inherit the form-page flex rule (DW-1596).
- 14.7 draws the typed-name field on every destructive card, these included.

**One home for the effect.** `Prohibited.WeakensByEffect` is the one classifier, as `GrantsPrivilegeByEffect` is for privilege. The mint ORs its verdict into `destructive`, and the tool maps it to the card's code. The editor's lines mirror it client-side, as the create page's consequence lines already do. The typed-name field on a destructive card is Story 14.7's (backlog). This story sets `destructive`, which is what 14.7 reads, as the shipped privileged grants already do.

**Precedence.** The card carries one consequence code, stored in a 64-character column, so a proposal with several effects names the first of these:

1. `WEBAPP.UNAUTHENTICATEDPRIVILEGED`: a privileged role on an application that is, or is being made, unauthenticated.
2. `WEBAPP.UNAUTHENTICATED`.
3. `GRANT.PRIVILEGED`.
4. `WEBAPP.NORESOURCE`.
5. `WEBAPP.REPOINTED`.

Its diff still lists every field, and one effect is enough to make it destructive. The editor has one line per effect, each at its own field. The one merge is the privilege line, which becomes the combined line when the application is unauthenticated, as read or as the unsaved form stands. The authentication line stays where it is, because roles apply through their own action and not through the Save.

**Own-app sentences.** `PRIVILEGEGRANTREASON` is drawn before a click, by `ocupilot-application-roles`, and returned after one. So it gets the full AD-53 treatment: a Fixed-strings row, a `strings.ts` key, and pins in both `self-protection.test.mjs` and `RefusalCopy`. No client surface draws the other three before a click, because the own-app form is refused as a whole under the serving-path sentence. They reach a person only as the server's own reason on a 403 or a refused card. So each is a caller-neutral `…REASON` parameter pinned in `RefusalCopy`, with no client copy to drift from.

**DESIGN.md:1210** (DW-1595) becomes:

> …at the bottom-right of the content area — `{spacing.4}` above the status bar, or above the form bar on a form page so no toast covers Save or Cancel — and offset from the right edge by the panel's live width…

**Ledger inbox:** DW-1490, DW-1493, DW-1502, DW-1577, DW-1595 and DW-1596 are addressed, and none is declined. DW-1502's credtype half pins the existing `Error.cls` parameter and edits no Epic 10 file. DW-1207 is closed by-design and is not owned here. Epic 10's branch touches only `strings.ts` and EXPERIENCE.md among this story's files, and only as appends.

## Verification

**Commands:**

- `(loop)` `cd ui && node --test tools/self-protection.test.mjs tools/navigation.test.mjs tools/strings.test.mjs tools/screen-mirror.test.mjs tools/field-lists.test.mjs`. Expected: green.
- `(loop)` `cd ui && npm run test:components`. Expected: green, including the `web-app-editor.*.spec.ts` specs, `proposal-card.spec.ts` and `screen-action-handler.spec.ts`.
- `(loop)` `node ui/tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.<X>`, one run at a time, for X in: `WebAppSave`, `WebAppWeakening`, `ProposalMint`, `ProposalCreate`, `RefusalCopy`, `ToolWrite`, `Prohibited`, `ProhibitedByEffect`, `ProhibitedRoute`, `WebAppCreate`, `WebAppLocation`, `WebAppWire` and `Descriptor`. Expected: 0 failures.
- `(loop)` `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`. Then, with `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci`, run `node --test --test-concurrency=1` one file at a time over these specs. Expected: green.
  - web-applications-editor, web-applications, web-applications-create, web-applications-actions
  - users-editor, users, users-create, users-actions
  - device-editor, roles-create, wallet-secret, x509-import, switches, definitions, toast
  - a11y-structural-invariants (DW-1337's gate on the new editor), proposal-card (the new consequence codes), screen-height (the outlet chain DW-1596 changes)
- `(loop)` `uv run scripts/check-objectscript.py` and `bash scripts/lint-docs.sh`. Expected: clean, and the initial bundle stays under 1378kB.
- `(once, before dev_complete)` `node ui/tools/ci-runner.mjs --container ocupilot-ci --package OcuPilot.Test`. Expected: 0 failures, excluding only the four arming-variable classes this throwaway refuses.

**Mutations (Rule 19):** each AC and matrix row gets one `mutation:` line here, written by the pass that adds its pinning test. The ruling's pinning tests, each ready for its line:

- Destructive marking: `WebAppWeakening`'s destructive-row assertion. Mutation: drop `|| (tEffect '= "")` from `Mint`'s `destructive`.
- Permitted elsewhere: `WebAppWeakening`'s probe confirm and Save legs. Mutation: restore the three arms for every application in `WebApplication()`.
- Refused on own: `WebAppWeakening`'s recorded-path legs, one per code. Mutation: delete the three own-app arms, so `SERVINGPATH` answers instead.
- Precedence: the "Several effects" leg. Mutation: in `WeakensByEffect`, test the cleared resource before the added Unauthenticated bit.
- One line: the combined-line test in `web-app-editor.page.spec.ts`. Mutation: render `privilegedGrantEffect` whatever the authentication state.

- mutation: drop `|| (tEffect '= "")` from `Mint`'s `destructive` → `WebAppWeakening.TestEachWeakeningIsMintedDestructiveAndAppliesOnceConfirmed` (three "marked destructive" asserts) and `TestSeveralEffectsNameTheFirstInPrecedence` go red.
- mutation: restore the three arms for every application in `WebApplication()` → `WebAppWeakening`'s confirm, Save and privileged-unauthenticated legs go red, the confirm refused `PROHIBITED.UNAUTHENTICATED`/`AUTHORIZATION`/`DISPATCH` on the probe.
- mutation: delete the three own-app arms (`tEffect` forced to `""`) → `WebAppWeakening.TestEachWeakeningIsRefusedWithItsOwnCodeOnOcuPilotsOwn` goes red on all three codes, for both callers.
- mutation: in `WeakensByEffect`, test the cleared resource before the added Unauthenticated bit → `WebAppWeakening.TestSeveralEffectsNameTheFirstInPrecedence` goes red ("naming the first effect in precedence").
- mutation: render `privilegedGrantEffect` whatever the authentication state → `web-app-editor.page.spec.ts` "states one privilege line ... the combined one where the application is unauthenticated" goes red.
- mutation: skip `Mint`'s empty-diff refusal (DW-1577) → `Proposal.TestAMergeThatChangesNothingIsRefusedAndStoresNothing` goes red for both `webapp.list.update` and `permissions.users.update`.
- mutation: skip `Confirm.FingerprintMatches`'s typed-name branch for a create (DW-1493) → `ProposalCreate.TestAConfirmedCreateNamesItsTargetAsTyped` goes red for the application and the account.
- mutation: empty `AdminPort`'s `TYPEKEPTTYPES` (AD-27's fifth case) → `WebAppSave.TestASystemApplicationKeepsItsType` goes red ("still reads Type 3").
- mutation: compare `Resource` against the form rather than the read in the store's `clearsResource` → `web-app-editor.store.spec.ts` "names each weakening effect against the read" goes red.
- mutation: stop the form-page host rule from matching (DW-1596), rebuilt and redeployed → `users-editor.browser-spec` "the form bar is flush ..." and `web-applications-editor.browser-spec` "the visual gate on every tab, and the form bar flush ..." go red.
- mutation: drop the 404 branch from the store's `absorb` (DW-1490's absent state) → `web-app-editor.store.spec.ts` "holds an application the instance does not have as absent ..." goes red.
- mutation (AC1): drop the Matching roles tab from the page's `tabs` → `web-app-editor.page.spec.ts` "opens an application on its four tabs ..." goes red.
- mutation (AC2): make the store's Save publish to no bus → `web-app-editor.page.spec.ts` "sends only the changed fields ... and publishes the change" (exactly one `updated` event) goes red.
- mutation (AC3, matrix "Own app, AC3"): remove the `Prohibited` call from `WebAppSave.Update` → `WebAppSave.TestOcuPilotsOwnApplicationIsRefusedOnBothCallers` goes red.
- mutation (Integration AC): skip `tabToOpen` in the page's `afterRefusal` → the page spec's "Integration: a refusal on Cross-origin settings ..." goes red.
- mutation (matrix "Two-field save"): merge over `{Name}` instead of the fresh read in `WebAppSave.Update` → `WebAppSave.TestATwoFieldSaveSendsTheCompleteSetAndTheOthersSurvive` goes red.
- mutation (matrix "Undeclared key"): admit `SettableFields` instead of `PermittedFields` in `WebAppSave.Update` → `WebAppSave.TestTheUndeclaredKeysAreRefusedAndNothingIsSent` goes red.
- mutation (matrix "DW-1490", hard reload): remove WebAppForm from `DESCRIPTOR_EDIT_PAGES`, rebuilt and redeployed → `web-applications-create.browser-spec` AC2 (and AC7) go red.
- mutation (matrix "Privileged role", proposal half): make `WebAppUpdate.Consequence` answer `""` → `WebAppWeakening.TestAPrivilegedRoleOnAnUnauthenticatedApplicationIsOneLine` goes red.
- mutation (matrix "Several effects", editor half): drop the unauthenticated line from the page's `generalFields` → the page spec's "states each weakening effect once, at its own field ..." goes red.
- mutation (matrix "DW-1493", instance half): drop `Confirm.FingerprintMatches`'s typed-name branch → `WebAppWeakening.TestAConfirmedCreateIsStoredAsTyped` goes red.
- mutation: cut `Prohibited.CODEFIELDS` to `DispatchClass,NameSpace` → `ProhibitedByEffect.TestEveryCodeFieldIsMarkedElsewhereAndRefusedOnOcuPilotsOwn` goes red.
- mutation: drop `'SuperClass'` from the store's `CODE_FIELDS` → `self-protection.test.mjs` "the editor's repointed fields are the prohibited set's CODEFIELDS" goes red.
- mutation: bypass `WebAppSave.Gate` in `HandleUpdate` → `WireSecurityRead.TestTheWebApplicationSaveRefusesACallerWithoutItsPairs` goes red.
- mutation: drop the added-unknown-bit rule from `Create.UpdateViolations` → `WebAppSave.TestTheEditsRulesRefuseEachFieldWithItsCode` goes red.
- mutation: drop the page's ChangeBus re-read → the page spec's "re-reads the application in place when another caller changes it ..." goes red.
- mutation: drop `|| (tEffect '= "")` from `Mint`'s `destructive` → `ToolWrite.TestARepointingCallMintsADestructiveProposal` (the dispatched model-facing path) goes red.

## Auto Run Result

Status: done
Blocking condition: none

**Change.** The web application editor at `web-applications/list/edit/<id>` (four tabs, the 25 settings, the fixed fields, both roles tabs through the list's AD-53 role actions), `PUT /web-applications/:id` through `WebAppUpdate` in `UserSave`'s order, and AD-10 as ruled: the three weakening effects permitted and marked destructive (`WeakensByEffect`) on other applications, refused with their own codes on OcuPilot's own. Also DW-1490 (the editor reads its id; the create hands off with `arriveSaved`), DW-1493 (a create confirm names the typed spelling), DW-1502 (`PRIVILEGEGRANTREASON` and credtype pins), DW-1577 (a no-op merge is 400), DW-1595 (DESIGN.md and `toast-host.ts` prose) and DW-1596 (form-page flex host rule), plus AD-27's fifth case (`AdminPort` keeps a system application's `Type`).

**Files.** Server: `Prohibited`, `Mint`, `Confirm`, `AdminPort`, `WebAppUpdate` (rewritten), `WebAppCreate`, `Classification`, `Area/WebApp/{Create,FormRules,WebAppSave (new)}`, `Router`, `Error` (append), `WebAppForm`/`WebAppList` descriptors, `Screen/Registry`. Tests: new `WebAppSave`, `WebAppWeakening`, two Save fixtures; edited `Prohibited`, `ProhibitedByEffect`, `ProhibitedRoute`, `ToolWrite`, `RefusalCopy`, `Proposal`, `ProposalCreate`, `WebAppCreate`, `EndpointCoverage`, `Wire`, `WireSecurityRead`; `scripts/ci-throwaway.sh` arming roster. Client: new `web-app-editor.{page,store}.ts` and specs; `create-form.{page,store}.ts`, `navigation.ts`, `screen-outlet.ts`, `screen-action-handler.ts`, `self-protection.ts`, `proposal-view.ts`, `strings.ts` (append), `_components.scss` (append), `toast-host.ts` (doc), regenerated `screens.generated.ts`, `screen-mirror.mjs`, tool tests; browser specs: new `web-applications-editor`, edited `users-editor`, `web-applications`, `web-applications-create`, `device-editor`, `toast`. Docs: EXPERIENCE.md rows 469-475, DESIGN.md:1210 `[AMENDED 2026-09-24 - Story 9.2, DW-1595]`.

**Review.** 22 findings: 12 patched (7 medium, 5 low; all test or doc patches, each new pinning test observed red under its mutation), 0 deferred from review, 10 rejected (8 false, 2 low; reasons in the triage log). One environment incident, repaired in-pass: a shared scratchpad backup name (`store.bak`) collided with another session's file and briefly replaced `web-app-editor.store.ts`; it was restored byte-for-byte from the review diff, backups moved to a private folder, and Epic 10's `definition-form.store.ts` was checked unchanged.

**Follow-up review:** `false` — patched counts: high 0, medium 7, low 5; every patch is a test or doc change verified green and red under its named mutation, so no unverified risk remains to name.

**Verification.**

- ObjectScript: full sweep `--package OcuPilot.Test` on `ocupilot-ci` once, 218 classes, 1,909 tests, 1 failed: `WireSecurityRead.TestTaskHistoryPairSetsAreEnforcedForARealPrincipal`, which was already failing on this throwaway. `AuditingUpdate`, `ErrorDelete`, `ProcessControl` and `TaskResume` refused (the environment's arming variables), and 0 probe leftovers. Before it, one class at a time: `ProhibitedByEffect` 8/8, `WebAppSave` 7/7, `WebAppWeakening` 6/6, `ToolWrite` 30/30, `Prohibited` 12/12, and `WireSecurityRead` 20/21 (the same pre-existing failure).
- Client: tools 1378 of 1379 pass. The one failure is `build-output.test.mjs` DW-371: the initial bundle is 1,397,013 bytes against the 1378kB warning (in `deferred:`, `angular.json` not touched). Components: 78 files, 1,067 tests, all green.
- Browser, after rebuild and redeploy: the handoff ran each listed spec file green on this bundle (web-applications-editor 7, web-applications 4, web-applications-create 8, web-applications-actions 3, users-editor 8, users 4, users-create 5, users-actions 2, device-editor 4, roles-create 5, wallet-secret 4, x509-import 4, switches 4, definitions 6, toast 3, a11y-structural-invariants 10, proposal-card 3, screen-height 15). This pass re-ran toast 3/3 (and its Integration leg alone), web-applications-editor 7/7, web-applications-create 8/8 and a11y-structural-invariants 10/10.
- `check-objectscript` 0 problems; `lint-docs` 0; no private-key material.

**Residual risks.** DW-371 reads red until the lead re-bases the budget or lazy-loads the editor. The WebAppForm label is now `proposalEntityWebApplication` (9.1's UserForm precedent), so `webAppFormLabel` is unused.
