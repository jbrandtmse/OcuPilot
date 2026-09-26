---
title: 'Story 16.19: Impact lines on removals'
type: 'feature'
created: '2026-09-26'
status: 'ready-for-dev'
baseline_revision: '6591c799f689eff794f1a58d79ca6bcccb3ce4d2'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-16-context.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** A person about to delete a role or a resource, or to take a role from a user, is not told what else depends on it. The agent's proposal card and the screen's dialog show neither the accounts, applications and databases affected nor the privileges a user would actually lose.

**Approach:** One kernel computation answers an `impact` object on the instance, with the caller's own privileges. The agent's mint records it on the proposal, and a new read route answers it to the screen's dialog when that dialog opens. The client renders one "Impact: …" line from Fixed strings on the proposal card, above 11.8's privilege line, and in the dialog. The user's net loss comes from a reusable composition of effective privileges that Story 16.3 will take.

## Boundaries & Constraints

**Always:**

- **Covered removals.** Only these three get an impact; every other tool answers `impact: null`.

  | Removal | Tool | Proposal card | Screen dialog |
  |---|---|---|---|
  | Role delete | `permissions.roles.delete` | yes | Roles list Delete. The role editor's Delete uses the same dialog. |
  | Resource delete | `permissions.resources.delete` | yes | Resources list Delete |
  | Role removal | `permissions.users.update`, whenever the sent `Roles` lacks a role the fresh read held | yes | Users list "Remove role" dialog, when a role is chosen |

- **Wire shape (names only, AD-11).**
  - The shape is `impact: {kind, refused, parts}`.
    - `kind` is one of `role-delete | resource-delete | role-removal`.
    - `refused` is `null` or `{code, reason}`.
    - `parts` is `[{part, count, names, unchecked}]`.
  - `part` is one of `holders | grantingApplications | grantingRoles | guardedApplications | guardedDatabases | loses`. The order is fixed per kind (see Design Notes).
  - `names` holds the first three by name order. `unchecked` is `""`, the first missing pair, or `truncated`.
  - A `loses` name is `<resource>:<letters>` (`%DB_USER:RW`), or `%All`.
  - No value other than names, counts, pairs and the refusal leaves the instance. Nothing is added to screen context or to the model's tool result (AD-24).
- **Refused before counted (AD-10).**
  - `Impact.Of` asks `Prohibited.Prohibits` first, with the write's own tool, target, payload and diff.
  - A refused removal answers `refused: {code, reason: ReasonFor(code)}` and no parts. The line renders that reason, never an impact.
  - The write-time check is unchanged and stays the verdict (AD-40).
- **Every part is read as the caller (AD-8, AD-29).** Each part is read through the declared read or `AdminPort` call of the screen that owns that data.
  - Before reading, `Gate` checks that screen's pair set (`Gate.RequiredPairs` of `RoleList`, `UserList`, `ResourceList`, `WebAppList` or `DatabaseList`).
  - A missing pair makes the part `unchecked: "<pair>"` with `count` 0. It is never read, and the line never says "no …" for it.
  - A read that truncates is `unchecked: "truncated"`.
  - There is no escalation, and nothing reads `%SYS` classes directly for this.
- **Fresh at mint and at open.**
  - Mint computes the impact once and stores it (`Propose.Impact`). It is never recomputed at serialization, because the AC ties it to mint.
  - The dialog asks the route each time it opens, and each time the remove-role choice changes. A late answer for a stale choice is dropped.
- **Composition (measured, Design Notes)** is `Kernel/Shell/Effective.cls`:
  - pure `Compose(roles, roleRows, public)` and `Loss(before, after, public)`;
  - `Read(roots, …)`, which fetches the `GrantedRoles` closure with role GETs, guarded against cycles, and the public permissions from the resource list.

  A role's loss is `Loss(Compose(fresh Roles), Compose(sent Roles), public)`.
- **A mint or dialog never fails over the impact.**
  - A fault in the computation, or a stored value over `MAXLEN`, logs and records `""`. The card then has no line and the proposal is minted as it is today.
  - A route failure opens the dialog without a line.
- **Placement.**
  - **Card:** first child of `@if (buttonsVisible)` in `proposal-card.ts`, above the privilege line.
    - An impact is a caption with the runs-as class and `data-slot="impact"`.
    - A refusal is the privilege line's warning banner with `role="status"`.
  - **Typed-name dialogs:** the `advisory` slot. It replaces the role-delete holders line (DW-1513).
  - **Role dialog:** a caption under the select, with `aria-describedby`.
- **Copy** is the Fixed-strings row in Design Notes, verbatim.
  - Append it at EXPERIENCE.md:577 and cite it `/** EXPERIENCE.md:577 */` in `strings.ts`.
  - Every existing `EXPERIENCE.md:n` citation with n >= 577 moves up by one. Today that is `strings.ts:1957` (`:617`); grep the whole tree for others.
  - Row 479 is edited in place: drop the three holders literals, and say the advisory is the impact line (Story 16.19). Delete `roleHoldersLine` and its three keys.
  - The anatomy footer bullet (:664) gains one sentence, in place.

**Never:**

- No change to `Kernel/Governance/Gate.cls`, `Operation.cls`, `Confirm.cls`, the ledger, `AdminPort.cls`, `Prompt.cls`, `screens.generated.ts` or `structural-baseline.json`. No new tool and no governance key.
- No impact on the user editor's or role editor's inline member removals. They open no dialog, and adding one is out of scope. No impact on a role update's `GrantedRoles` or `Resources`.
- Epic 14's hunks stay untouched. `proposal-card.ts` 661-672 stays untouched. The contended files are listed in the Code Map.
- No reuse of `Prohibited.Walk`/`DirectRoles`. They read `%SYS` directly for AD-10's live predicates, not as the caller.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Role delete | role held directly by U1, U2 (one as escalation), and granted by `/csp/p` MatchRoles (as an application role or a matching role's target) | `holders` 2 `[U1,U2]`, `grantingApplications` 1 `[/csp/p]` | none |
| Union | U holds A (X:R) and B (X:W); remove B | `loses [X:W]` | none |
| Transitive | U holds G1 and G2; G1 grants G2; remove G2 | `loses` count 0: "loses nothing their other roles do not still grant" | none |
| %All kept | U holds A and AllVia (grants `%All`); remove A | `loses` 0 | none |
| %All lost | U holds AllVia and P; remove AllVia | `loses` names start `%All`, then each pair P itself does not grant | none |
| Public | X public R; remove the role granting X:R | X:R not in `loses` | none |
| Escalation | an escalation role on the user | never counted as held | none |
| Resource delete | R granted by roles A, B; `/csp/q` Resource R; database USER guarded by R | `grantingRoles` 2, `guardedApplications` 1, `guardedDatabases` 1 | none |
| Unread part | caller lacks `%Admin_Manage:USE` | `guardedDatabases` `unchecked "%Admin_Manage:USE"` → "which databases it guards was not checked (requires %Admin_Manage:USE)" | other parts still read |
| Refused | delete an OcuPilot role; remove the last `%All` holder's `%All` | `refused` with the code's reason; no parts | the write-time refusal is unchanged |
| Other tools | a web app delete | `impact: null`; no line | none |

</intent-contract>

## Code Map

Server (under `src/OcuPilot/`):

- `Kernel/Proposal/Mint.cls`: `tValues` is filled at :293-342. Add `impact` beside `consequence` at :332, and `GuardedMint` is at :343. The model's `pProposal` at :354-360 stays unchanged.
- `Kernel/State/Propose.cls`:
  - properties :51-179. Add `Impact As %String(MAXLEN = 4000)` after `ReadBack` :179, with the no-`SCHEMAVERSION` line.
  - `GuardedMint`: contract :209-216, fields :234-259.
  - `RowValues` :660-699, `WireRow` :713-751. Add `impact` (object or null), after `readBack` :743-748.
  - Epic 14 edits only :46-50.
- `Kernel/Proposal/Disclosure.cls:89` `Privilege`: the pattern for a wire builder.
- `Kernel/Proposal/Prohibited.cls`: `Prohibits` :777 and `ReasonFor` :478. The arms are `Role` :1290, `User` :1228 and `Resource` :1386.
- `Api/ScreenAction.cls`: `Handle` :76 (descriptor and action resolution); `Run` :167, which does pairs `Gate` :194, fresh `Read` :204, `ScreenActionDelta` :221, `Body` :241, then the prohibited `Gate` :252.
  - Add an optional preview argument to `Run` that returns tool, target, fresh, payload and diff after `Body`, before :252, without writing, so the route reuses the exact resolution.
  - `Run`'s write path must stay byte-identical in behavior.
- `Api/Router.cls`: add `/screens/:screen/impact` GET beside :114-115. Put its thin target near `ScreenRead` :651. Epic 14 edits :129 and :750.
- `Screen/Read.cls:234` `Execute` (`truncated` :385/:413). `Screen/Gate.cls` `RequiredPairs` :106, `EvaluatePairs` :132. `Port/AdminPort.cls:747` `Invoke`.
- `Area/Permissions/RoleCreateRules.cls:506` `Members`: the `OWNERLIST` precedent, to copy and not to call (the kernel does not depend on a slice).
- Tools:
  - `Screen/Tool/RoleDelete.cls` and `ResourceDelete.cls`.
  - `UserUpdate.cls`: `ScreenActionDelta` :213-271 (remove-role); `EscalationRoles` excluded :72.
- Descriptors (pairs): `UserList` :56 (`Roles` only via `rowGet`), `RoleList` :39, `ResourceList` :41, `WebAppList` :62 (LIST has `Resource`, no `MatchRoles`), `DatabaseList` :63 (`%Admin_Manage:USE` + `%DB_IRISSYS:READ`, `Database.SysCRUD` rows carry `Resource`).
- Tests:
  - `Test/ProposalWire.cls:28` `WIREKEYS`.
  - `Test/EndpointCoverage.cls` beside :104 (Epic 14 edits :118).
  - `Test/TurnWireFixture.cls` `EnsurePrincipal` :70, `SetRoleResources` :115, `RemovePrincipals` :162.
  - `Test/UserUpdate.cls:1077-1133`: HTTP precedent. `Install/Smoke.cls:1410`: a direct `Mint.Mint` call.

Client (under `ui/src/app/`):

- `shell/proposal-card.ts`: `@if (buttonsVisible)` :302 and the privilege line :303-315; `readBackText` :805-808 (add the `impactLine` getter after it). Epic 14 edits :337-345, :399-404 and :875.
- `core/proposal-view.ts`: `ProposalCardView` `privilege` :118-122 (add `impact` after it); `toCardView` :426-452 (`privilege:` :449). Epic 14 edits :207-372.
- `core/turn.ts`: `TurnProposal` :253-259 (optional `impact?`); `parseProposal` :581-582. Epic 14 edits :43 and :1136.
- `shell/screen-action-handler.ts`:
  - `startFor` :462-541, with role delete at :521-524;
  - `openRoleDelete` :609-632, which becomes the generic impact preflight;
  - `openRole` :576-607;
  - `roleHoldersLine` :778-783, to delete;
  - `ROLE_LIST` :82, `RESOURCE_LIST` :85, `REMOVE_ROLE` :128;
  - GET through `ApiService.requestJson` (`core/api.ts:328`).
- `shell/role-dialog.ts`: select :30-41, caption precedent :42-44, `onChange`. `shell/typed-name-dialog.ts`: `advisory` slot :50-55.
- `core/strings.ts`: append before `} as const` :2915; `readBackMore` :2901 is reused; delete `roleDeleteHolders*` :1819-1824.
- Specs:
  - `shell/proposal-card-privilege.spec.ts` (pattern);
  - `screen-action-handler.spec.ts` :928-945 (holders test to replace), :429;
  - `role-dialog.spec.ts`;
  - `ui/tools/proposal-privilege.test.mjs` (pattern).
- Browser:
  - `ui/browser/roles-editor.browser-spec.mjs:425` (the holders assertion becomes impact);
  - `resources-editor.browser-spec.mjs:340`;
  - `users-actions.browser-spec.mjs:243`;
  - DW-1337 pattern `read-back.browser-spec.mjs:173-232`.

## Tasks & Acceptance

**Execution:**

- `src/OcuPilot/Kernel/Shell/Effective.cls` (new): the composition piece.
  - `Compose(pRoles As %DynamicArray, pRoleRows As %DynamicObject, pPublic As %DynamicObject) As %DynamicObject` answers `{all, allVia, resources: {<res>: {<letter>: <granting role>}}}`. It takes the closure over `GrantedRoles` and unions the letters. `%All` anywhere in the closure sets `all`. Escalation roles are never passed in.
  - `Loss(pBefore, pAfter, pPublic) As %DynamicArray`.
  - `Read(pRoots, Output pRoleRows, Output pPublic, Output pUnchecked) As %Status`: role GETs through `AdminPort` with a visited set, and the public permissions from the `ResourceList` read, each after its pair gate.
- `src/OcuPilot/Kernel/Proposal/Impact.cls` (new): `Of(pToolName, pTargetRef, pFreshJson, pPayloadJson, pDiffJson) As %DynamicObject` (or `""`).
  - It checks the prohibited set first.
  - Then, per kind:
    - holders: `Security.Role` `OWNERLIST`, `Type` beginning `User`, de-duplicated by name;
    - granting applications: each `WebAppList` row's GET, `MatchRoles[].TargetRoles`;
    - granting roles: each `RoleList` row's GET, `Resources[].Name`;
    - guarded applications and databases: the `Resource` field of the `WebAppList` and `DatabaseList` rows;
    - loses: `Effective`.
  - Names are compared case-insensitively (inference: IRIS resolves these names without case).
- `Kernel/Proposal/Mint.cls`, `Kernel/State/Propose.cls`: record `impact` (fault or over-length gives `""` and a log line); property, `GuardedMint`, `RowValues`, and `WireRow` `impact`.
- `src/OcuPilot/Api/ScreenImpact.cls` (new) plus `ScreenAction.cls` preview plus `Router.cls`: `GET /screens/:screen/impact?action=&id=&value=`.
  - It resolves exactly as the action POST does.
  - It answers `{impact}` (null for a tool with none) through `Response.JSON`, and faults through `Error.Render`.
- Client:
  - new `core/impact.ts`: `impactOf(unknown)`, which answers null outside the vocabulary; `impactLine(impact, subject)`.
  - `turn.ts` and `proposal-view.ts` carry it.
  - `proposal-card.ts` renders it.
  - `screen-action-handler.ts`: role and resource delete preflight to the route (`advisory`); remove-role fetches on choice and hands the line to `role-dialog.ts`, which gets a new `impact` input and a caption.
- `strings.ts`, EXPERIENCE.md (append at 577; edit 479 and 664 in place; move the shifted citations).
- Tests:
  - new `Test/Effective.cls`: the measured table, through `Compose`/`Loss` over literal rows.
  - new `Test/ImpactRoute.cls`, HTTP on `ocupilot-ci` with `OcuImpact*` probe objects removed in `OnAfterAllTests`: each matrix row over the route, and one `Mint.Mint` role delete whose wire row carries `impact`.
  - `ProposalWire` `WIREKEYS` + `impact`.
  - `EndpointCoverage` probe row.
  - `ui/tools/impact.test.mjs`.
  - new `shell/proposal-card-impact.spec.ts`; cases in `screen-action-handler.spec.ts` and `role-dialog.spec.ts`.
  - new `ui/browser/impact.browser-spec.mjs`; update `roles-editor.browser-spec.mjs:425`.

**Acceptance Criteria:**

- **AC1.** Given a role two users hold and one web application grants, when the Roles list's Delete dialog opens or the agent's delete proposal is minted, then each shows "Impact: 2 users hold it: <a>, <b>; 1 web application grants it: <app>.", and a holder added after the mint is absent from the card but present when the dialog is reopened.
- **AC2.** Given a user whose other roles still grant part of what role A grants (directly, through a granted role, `%All`, or a public permission), when A's removal is proposed or chosen in the Remove role dialog, then the line names only the pairs no remaining role grants, or "loses nothing their other roles do not still grant".
- **AC3.** Given a resource two roles grant, guarding one web application and one database, when its Delete dialog opens or its delete is minted, then the line names all three parts with counts and names.
- **AC4.** Given a caller holding the Resources screen's pairs but not `%Admin_Manage:USE`, when a resource delete's line renders, then it reads "which databases it guards was not checked (requires %Admin_Manage:USE)" and never "it guards no database".
- **AC5.** Given a removal the prohibited set refuses (one of OcuPilot's own roles), when the card or dialog renders, then the line is that refusal's reason and no impact.
- **AC6 (Integration).** The Roles list and the role editor, the consumers, read `GET /screens/permissions.roles/impact` on `ocupilot-ci` and render the line in the typed-name dialog in both themes. It passes the DW-1337 structural gate (wide and narrow, light and dark) with no new allowance, and the bundle stays under 1900 kB.

## Spec Change Log

- 2026-09-26, lead, spec gate: AD-8's "A removal names its impact" paragraph and AD-53's shared-list item written into the spine exactly as recommended below (Rule 20, light path; no existing Rule contradicted). Status reset to ready-for-dev; no other change.

## Review Triage Log

## Design Notes

**Recommended spine change (the halt, Rule 20).** This story adds two things later stories rely on:

- a piece shared by both callers of three write tools, which AD-53's list of shared things would otherwise miss;
- a measured composition rule that Story 16.3 will assume.

Recommended text:

> **AD-8, appended after the 11.8 paragraph:** "**A removal names its impact** [AMENDED 2026-09-26, Story 16.19 spec gate, Rule 20]. A role delete, a resource delete and a write that removes roles from a user carry an impact computed on the instance, once when the proposal is minted (kept on the proposal row) and again when the screen's dialog opens. For a role, it gives its direct holders and the web applications whose `MatchRoles` grant it. For a resource, it gives the roles granting it and the web applications and databases it guards. For a user, it gives the pairs lost net of the remaining roles. Each part is read with the caller's own privileges through the owning screen's declared read and pair set. A part the caller cannot read is reported unchecked, naming the pair, never as no impact. A target the prohibited set refuses shows that refusal's reason instead (AD-10). Effective privilege is composed as the instance composes it (measured on `ocupilot-ci`, 2026-09-26): the union over the user's roles and, transitively, every role they grant; `%All` anywhere in that closure holds everything; a resource's public permission is held by every user; an escalation role counts for nothing until the user escalates. `Kernel.Shell.Effective` is the one composition, and a later effective-privilege read uses it. The impact is names only and never enters screen context or a tool result."
>
> **AD-53, "What both callers share":** add "the impact of a removal (AD-8)".

No AC contradicts an existing AD Rule. Once the text is in the spine, set `status: ready-for-dev` with no other change.

**Measured on `ocupilot-ci`, 2026-09-26.** Ground truth was `CheckUserPermission`, cross-checked by real logins. The probe objects were removed and a count query read 0.

- **Union.** Permissions union across roles: A X:R and B X:W give RW, and removing B leaves R.
- **Transitive.** `GrantedRoles` are followed at every depth, and `$roles` at login lists the chain. A role still reachable through another held role loses nothing when removed directly.
- **`%All`.** Held directly or through `GrantedRoles`, `%All` answers RWU on any resource, even one that does not exist. The `%All` role's GET shows `Resources: []`, so it must be special-cased.
- **Public.** `PublicPermission` R is held by a user with no roles, and W is not.
- **Escalation.** `EscalationOnly` roles are refused as ordinary roles (#1485). A user's `EscalationRoles` give nothing until the user escalates.
- **Admin API v2.**
  - `security/role` GET carries `GrantedRoles`, `Resources[{Name,Permissions}]` and `EscalationOnly`; the LIST carries none of them.
  - `security/role/owners` (`OWNERLIST`) lists direct holders only, typed `User`, `Role` or `User (escalation)`. `%All` holders appear twice.
  - `security/user` GET carries `Roles` and `EscalationRoles`.
  - `security/resources` carries `PublicPermission`.
  - `web-app` GET carries `MatchRoles[{MatchRole,TargetRoles}]`, where an empty `MatchRole` is an application role; LIST carries `Resource`.
  - `database-dirs` carries `Resource`.

**Part order:** role-delete is `holders`, `grantingApplications`; resource-delete is `grantingRoles`, `guardedApplications`, `guardedDatabases`; role-removal is `loses`. The parts are joined with "; ". Names are joined with ", ", and past three they are followed by `readBackMore`.

**Copy for the EXPERIENCE.md row at 577, verbatim:**

> "Impact: <parts>." · "<n> users hold it: <names>" · "1 user holds it: <names>" · "no user holds it" · "<n> web applications grant it: <names>" · "1 web application grants it: <names>" · "no web application grants it" · "<n> roles grant it: <names>" · "1 role grants it: <names>" · "no role grants it" · "it guards <n> web applications: <names>" · "it guards 1 web application: <names>" · "it guards no web application" · "it guards <n> databases: <names>" · "it guards 1 database: <names>" · "it guards no database" · "<user> loses <names>" · "<user> loses nothing their other roles do not still grant" · "who holds it was not checked" · "which web applications grant it was not checked" · "which roles grant it was not checked" · "which web applications it guards was not checked" · "which databases it guards was not checked" · "what <user> loses was not checked" · " (requires <pair>)" · " (too many to check)"

Where column: "the impact line of a removal (Story 16.19, AD-8): on the proposal card above the privilege line, while Confirm shows; in a role or resource Delete dialog as its advisory; under the role picker of Remove role. `<parts>` joins the part phrases with "; "; `<names>` lists up to three names with ", ", then " and <n> more"; an unchecked part takes " (requires <pair>)" or " (too many to check)"; a refused removal shows the prohibited set's reason instead. [ADDED 2026-09-26 - Story 16.19]"

**Decisions:**

1. The impact is stored at mint, not re-read per poll (AC4: "read fresh when the proposal is minted").
2. The impact replaces the role-delete holders advisory, because it contains the same count.
3. Holders are the direct holders, escalation holders included. Users who hold the role only through another role are not counted (inference: this is the AC's "hold the role").

**Governing ADs:** AD-8, AD-10, AD-6, AD-9, AD-11, AD-12, AD-13, AD-19, AD-20, AD-24, AD-29, AD-36, AD-39, AD-40, AD-53, AD-55, AD-58.

**Integration ACs.**

- **Consumes:** 11.8's privilege line placement and `Disclosure` pattern, 16.17's card layout, `Prohibited.Prohibits`, `Screen.Read`, `AdminPort`.
- **Consumed-by:**
  - 16.3: `Effective.Compose`/`Loss`, for effective privileges and the permission check naming the granting role (inference until its plan).
  - 16.21: Fix it proposals carry the impact through the ordinary card (inference).

**Governance:** no tool is added and `Gate.cls` is untouched. **DW-118** is declined, because Story 15.6 already resolved it. The ledger inbox is empty.

## Verification

**Commands:**

- `cd ui && node --test tools/impact.test.mjs tools/strings.test.mjs tools/proposal-privilege.test.mjs` (loop). Expected: green. Mutation: `impactLine` renders "no user holds it" for an unchecked part, and the unchecked case should turn red.
- `cd ui && npx ng test --include src/app/shell/proposal-card-impact.spec.ts --include src/app/shell/screen-action-handler.spec.ts --include src/app/shell/role-dialog.spec.ts` (loop). Expected: green. Mutation: drop the card's impact slot, and the card case should turn red.
- `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.Effective`, then `ImpactRoute`, `ProposalWire` and `EndpointCoverage`, one at a time (loop). Expected: green. Mutations:
  - drop the `GrantedRoles` walk: the transitive case turns red;
  - skip the pair gate: the unchecked case turns red;
  - skip `Prohibits`: the refused case turns red.
- `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/ && OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci node --test --test-concurrency=1 browser/impact.browser-spec.mjs browser/roles-editor.browser-spec.mjs` (loop). Expected: green in both themes, within the structural baseline. Mutation: the route answers `{impact:null}`, and the AC6 case should turn red.
- `cd ui && npm test`, `uv run scripts/check-objectscript.py`, `bash scripts/lint-docs.sh` (once, before dev_complete). Expected: green, and the bundle under 1900 kB.
- The full ObjectScript sweep on `ocupilot-ci`, one class at a time (once, before dev_complete). Expected: green.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none (AD-8 and AD-53 amended by the lead at the spec gate on 2026-09-26)
