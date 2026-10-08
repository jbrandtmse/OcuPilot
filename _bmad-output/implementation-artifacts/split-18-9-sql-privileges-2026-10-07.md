---
title: 'Story 18.9: SQL privileges and the permission extras'
type: 'feature'
created: '2026-10-07'
status: 'blocked'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-18-context.md'
warnings: ['multiple-goals', 'oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** SQL privileges are classic-only (the User and Role pages' SQL tabs and the `Dialog.SchemaPriv`, `Dialog.ColumnPriv` and `Dialog.MLConfigurationPriv` dialogs, each `%Admin_Secure`). So are user Copy from and password validation. The admin API carries the SQL privileges in three route families. The story's third criterion predates AD-10's owner amendment.

**Approach:** Not planned as one story. At Story 18.26's size it needs about three implement passes (Design Notes › Size). The lead decides on the proposed three-story split (Design Notes › Proposed split). Each part reuses the shapes measured here.

## Boundaries & Constraints

**Always:**

- The spine governs criterion 3: each part builds under AD-10 as amended (Design Notes › AD-10).
- Admin API calls go through `AdminPort` (AD-2, AD-27). Probes run on `ocupilot-ci` only.

**Never:**

- An elevation on the request path (AD-8).
- A SQL grant or revoke on one of OcuPilot's own schemas through OcuPilot (DW-236).

## I/O & Edge-Case Matrix

These are the hazards every part must hold; each was measured at plan.

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Silent no-op | A column grant the SQL layer refuses, a revoke by a non-grantor without `asGrantor`, a revoke of a privilege not held | The vendor answers 200 and changes nothing | The read-back (AD-58) reads it as not applied, never as a success |
| Lists and wildcards | `object`, `action` or `grantee` carrying `*`, `,` or a trailing `*` | The vendor expands it (`SELECT,INSERT` granted both) | Refused before any vendor call |
| OcuPilot's schemas | A grant or revoke on an `OcuPilot` schema object (DW-236) | Refused by an AD-10 self-protection arm, from either caller | No vendor call |
| Copy of `%All` | Copy from a user holding `%All` or an `%Admin_*` role | Permitted at the destructive treatment, naming the privilege (AD-10) | None |

</intent-contract>

## Code Map

For the parts' plans:

- **Vendor endpoints** (Hidden; read with `GetTextAsString`):
  - `%Api.Admin.Endpoints.Security.SQLPrivilege.Standard`: types `TABLE`, `VIEW`, `CUBES`, `SCHEMA`, `ML CONFIGURATION`, `FOREIGN SERVER`, `STORED PROCEDURE`; calls `$SYSTEM.SQL.Security.GrantPrivilege(WithGrant)` and `RevokePrivilege(..., wGrant, cascade, asGrantor)`.
  - `.Column`: types `TABLE` and `VIEW`; calls `%SQL.Manager.API.SaveObjPriv`.
  - `.Admin`: a closed list of 32 privileges (`GetPrivNum`); calls `GrantAdminOne` and `RevokeAdminOne`.
  - `Security.Role` `OWNERLIST`. `Security.User` has no copy type.
  - `GrantPrivilege` (`irislib/%SYSTEM/SQL/Security.cls:130-245`) accepts comma lists, `*` and trailing-`*` wildcards.
- **Routes already in the tree:** `Port/AdminRoutes.cls:194-202`, `Test/AdminInventory.cls:98-100` (no templates; all mutating).
- **Classic pages:**
  - `irissys/%CSP/UI/Portal/User.cls:93` and `Role.cls:99` tab captions. The SQL tabs are Admin Privileges, Tables, Views, Procedures, ML Configurations and Foreign Servers.
  - The Copy from save path is `User.cls:609-625` (`Security.Users.Copy(..., 1, 1, password)`).
- **Existing Permissions code:**
  - The role editor's Members tab already reads `OWNERLIST` (`Area/Permissions/RoleCreateRules.cls:506` `Members`, Story 9.3) and drops `AdminOption`.
  - The editors: `ui/src/app/areas/permissions/user-editor.page.ts` (1116 lines; General, Roles, Effective privileges) and `role-editor.page.ts` (956 lines; General, Members, Assigned to).
  - User create: `Area/Permissions/UserCreate.cls`, `UserCreateRules.cls`, `user-create-form.page.ts`.
- **Self-protection:** `Kernel/Proposal/Prohibited.cls` `IsOcuPilotCode` and `OCUPILOTSQL` :648 (the console's arm); `Install/Installer.cls:3432` `EnsureSqlPrivileges` grants `SELECT,INSERT,UPDATE,DELETE ON SCHEMA` to `%DB_OCUPILOT` (`Kernel/State/Base.cls:79`).
- **Password validator:** `Api/Account.cls:183` already calls `$System.Security.ValidatePassword(pNew, pUsername)` (Story 15.1, AD-39's third exception).
- **DW-1662:** `Area/Security/OAuthAuthorizationServerRules.cls:363` `CustomizationViolations` (`StoredRoles`, `Defaults` :150); its pin `Test/OAuthAuthorizationServerWire.cls:283` flips.
- **Harvest reference (read-only):** `irislib/ExecuteMCPv2/REST/Security.cls:3084` `SqlPrivilegeManage`, `:3349` `SqlPrivilegeList`.

## Tasks & Acceptance

None until the lead decides on the split (Design Notes › Decision needed). Each part's plan writes its own Task 0, tasks and criteria.

## Spec Change Log

## Review Triage Log

## Design Notes

**Measured at plan** (`ocupilot-ci`, 2026-10-07 PDT, as `_SYSTEM` through `/api/admin/v2` unless noted):

- **Standard family.**
  - `GET /security/sql-privileges` needs `grantee` and `namespace`. The grantee matches in any case.
  - A row is `{Type, Object, Action, GrantedBy, GrantOption, GrantedVia, HasColumnPriv}`. `GrantedVia` is `Direct`, `Role:<name>`, `Schema Privilege` or `Owner Privilege`.
  - Four `Ens` procedure rows (`Owner Privilege`) appear for every grantee: a new user, a new role and `_PUBLIC`.
  - `includeSystem=1` gave 350 rows on USER.
  - A schema grant is listed only as per-table rows (`Schema Privilege`), never as a `SCHEMA` row. Revoking `type=SCHEMA` on the schema removed them.
  - Rows answer `%ALTER`; the endpoint turns an `action` of `%ALTER` into `ALTER` (read in source).
  - A grant is a bodyless `POST` taking `namespace`, `grantee`, `object`, `action`, `type` and optional `withGrant`, answered 200 `{}`.
  - Failures are 500 #5540, carrying SQLCODE -30 (absent object), -60 (bad action), -400 (`type=COLUMN`) or -118 (unknown grantee). An unknown namespace answers 500 `<NAMESPACE>`.
  - A revoke of a privilege not held answers 200.
  - A revoke by a caller who is not the grantor answers 200 and revokes nothing. With `asGrantor=<the row's GrantedBy>` it revokes.
- **Column family.**
  - A row is `{Column, Action, GrantedBy, GrantOption, GrantedVia}`, per grantee, namespace and object `schema.table`.
  - A grant of an unknown column, or by a grantor without the privilege, answered 200 and stored nothing; a grant of `DELETE` answered 200 and stored a row the column list never shows (measured at Story 18.28's plan).
  - An `UPDATE` grant on column B, while the table-level `UPDATE` was held, stored nothing (inference: covered).
- **Admin family.**
  - A row is `{Privilege, GrantOption, GrantedVia}`, kept per namespace: USER and HSCUSTOM differed.
  - An unknown privilege answers 400 #5001. A revoke of one not held answers 200.
- **Grantor rule** (a principal holding `%Admin_Secure:U`, `%DB_IRISSYS:R` and `%DB_USER:RW`, no SQL privilege):
  - a standard grant answered 500 SQLCODE -112;
  - an admin grant or revoke answered 500 #516 SQLCODE -99;
  - a column grant answered 200 and stored nothing.
  - Holding `SELECT` with grant option, the same principal granted and revoked it.
- **Pairs.**
  - Without `%Admin_Secure:USE`, the standard list and grant answered 403. Each family's gate names only `%Admin_Secure` (read in source).
  - Without READ on the namespace's database (`%DB_USER`, which has no public permission), each list, grant and revoke tried, in all three families, failed `<PROTECT>` at the vendor's namespace switch.
  - A principal without `%DB_IRISSYS:READ` listed, granted and revoked standard privileges and listed admin privileges.
  - WRITE on the namespace's database was not needed: a standard-family grantor holding `%DB_USER:R` granted and revoked.
  - `OWNERLIST` needs `%Admin_Secure:USE` and `%DB_IRISSYS:READ`; without the second it answered `<PROTECT>` on `Security.Roles`.
  - Unmeasured: which of the namespace's routines and globals databases the switch needs, where the two differ.
- **Role owners.**
  - A row is `{Name, Type, AdminOption}`. `Type` is `User` or `Role`, and `AdminOption` is the string `"0"` or `"1"` (`"1"` after `GRANT ... WITH ADMIN OPTION`).
  - An escalation holder is `User (escalation)` with the boolean `false` (read in source).
  - An absent role answers 404 #883.
- **Copy from.**
  - No admin API route copies a user.
  - `Security.Users.Copy(source, new, "", 1, 1, password)`, the classic page's call, copied the source's roles, its standard, schema and column privileges in USER, and its admin privileges in USER and in HSCUSTOM.
- **Password validation.**
  - `$SYSTEM.Security.ValidatePassword(pw, user)` answers #845 outside the instance's pattern. The pattern is `3.255ANP` on `ocupilot-ci`: `a` and `x` were refused, `short1` accepted.
- **Audit.**
  - Grants and revokes record `%System/%Security/UserChange` "Object Privilege Granted/Revoked" and "System Privilege Granted/Revoked" for a user grantee, and `RoleChange` for a role grantee.
  - So no AD-15 or AD-53 named case is needed (inference: the column grants are among the "Object Privilege Granted" rows).
- **End state.** No `OcuProbe189*` user, role, table or schema. A scan of `^SYS`, `^%SYS` and USER's `^rINDEXSQL`, `^oddSQL` and `^oddPROC` (378,280 nodes) found no probe name. Monitor 0. The probes' audit rows stay.

**AD-10** (governs criterion 3). AD-10 as amended 2026-09-23 reads: "**Every other privilege grant is permitted, at the strongest confirmation**: granting `%All`, an `%Admin_*` role or any role carrying one to a user or a role ... go through the one tool (AD-55) with no caller-scoped predicate. An agent proposal that makes such a grant is confirmed as a delete is." Its amendment note records the rule criterion 3 restates ("adding `%All` or any `%Admin_*` role to any user or role ... not proposable at any confirmation level") as superseded by the owner ("I want to be able to grant those other roles, so grant %All").

- **No SQL route confers a role.** The three families take only the types and privileges listed in the Code Map, and `type=COLUMN` is refused -400.
- **The one role-conferring path is Copy from**, which copies the source's roles (measured).
- **Every part builds under AD-10 as amended.** A copy conferring `%All` or an `%Admin_*` role takes the destructive treatment and names the privilege. What stays refused is AD-10's current set, plus a new arm for SQL privileges on OcuPilot's own schemas (DW-236).
- This is not an open intent gap: the owner decided it, and the spine records it. Criterion 3's wording is a conflict with the spine, which the lead resolves (Decision needed, item 2).

**Size (inference).**

- Story 18.26 was one list, one form, four tools and one port, in one implement pass, and its spec was already oversized.
- The SQL standard family alone is about that size: a grantee- and namespace-scoped list on both editors, grant and revoke tools, an object picker over six object types, `asGrantor` from the row, the silent no-ops, the input refusals and the DW-236 arm.
- The column and admin families add two lists and four tools.
- Copy from, the members' admin option, password validation and DW-1662 add about one 18.25-sized story.

**Proposed split** (each part's own criteria; the lead numbers the new stories):

1. **Story 18.9, narrowed: SQL object privileges.** As an operator, I want a user's or role's SQL privileges on tables, views, procedures, schemas, ML configurations and foreign servers, so that the Permissions area reaches parity for SQL objects.
   - Given a user or a role and a namespace, when its SQL object privileges are listed, granted and revoked from its editor and by a confirmed agent proposal, then each round-trips through `Security.SQLPrivilege.Standard` and is read back.
   - Given a privilege another account granted, when it is revoked, then the revoke names that grantor (`asGrantor`); a row held through a role, a schema or ownership is shown and offers no revoke on this grantee.
   - Given a grant the instance's grantor rule refuses (-112), or a vendor 200 that changed nothing, when either caller sends it, then it is answered as refused by name, never as applied.
   - Given an object, action or grantee carrying `*`, `,` or a wildcard, or an unknown namespace, then it is refused before any vendor call.
   - DW-236: a grant or revoke of a SQL privilege on one of OcuPilot's own schemas is refused from either caller (new AD-10 arm).
2. **SQL column and admin privileges** (new).
   - Given a user or role, a namespace and a table, when its column privileges are listed, granted and revoked by either caller, then each round-trips through `Security.SQLPrivilege.Column`, and a grant answered 200 without being stored reads as refused.
   - Given a user or role and a namespace, when its SQL admin privileges are listed, granted (with or without the admin option) and revoked by either caller, then each round-trips through `Security.SQLPrivilege.Admin`. A privilege outside the vendor's 32 is refused before any call, and -99 is a named refusal.
   - The input refusals and the OcuPilot-schema arm hold for columns.
3. **Role members, user Copy from and password validation** (new).
   - Given a role, when its Members tab is read, then each member shows whether it holds the admin option, compared by value (`"1"`), and an escalation holder reads as one.
   - Given an existing user, when a new user is created from it by either caller, then the new account holds what the decision (item 3) copies. A copy conferring `%All` or an `%Admin_*` role is confirmed at the destructive treatment, naming the privilege.
   - Given a candidate password on the create form and the set-password dialog, when it is checked, then the instance's own validator answers, and no reason carries the password (AD-35).
   - DW-1662: a principal holding only the authorization server tab's two pairs creates a configuration with the default customization roles the editor pre-ticks.

**Ledger inbox (Rule 17).** Each entry is addressed by a part's criterion above. The lead re-owns it with the split:

- **DW-236** goes to part 1, refusal half. Its detection half (a grant widened outside OcuPilot) needs every grantee on the schema enumerated. Recommended: Story 18.13, which already reads back install's schema grant (AD-38).
- **DW-1662** goes to part 3.

**Decision needed** (for the lead):

1. Accept, reshape or reject the split, and number the parts. A retitle of 18.9 changes its sprint key, so the lead re-runs `SPRINT_PLAN generate` and re-owns its entries (Rule 5).
2. **Criterion 3 conflicts with the spine.** Recommended `epics.md` wording: "Given any grant, when it is proposed by the agent, then AD-10's prohibited set applies (application roles on OcuPilot's own web applications, OcuPilot's own roles and resources, SQL privileges on OcuPilot's own schemas), and a grant conferring `%All` or an `%Admin_*` role, as a copied user's roles can, is confirmed at the destructive treatment, naming the privilege."
3. **Copy from.**
   - **A (recommended):** an AD-27 named case for `Security.Users.Copy`, which carries the classic copy's SQL privileges and which the admin API cannot carry.
   - **B:** copy roles and fields only, through `GET` and `POST /security/user`. This is narrower than the classic page.
4. DW-236's detection half: Story 18.13, or part 1.

**For the lead** (Rule 20; written at each part's spec gate):

- **AD-8:** the SQL routes need `%Admin_Secure:USE` and READ on the target namespace's database, resolved at the call. The instance's grantor rule then decides (measured).
- **AD-10:** the SQL arm on OcuPilot's own schemas. A grant would widen AD-9's protected tables (DW-236). A revoke of `%DB_OCUPILOT`'s schema grant would leave OcuPilot `unreadable` (AD-38).
- **Vendor defect candidates** (owner hold, not reported):
  - (a) a `Security.SQLPrivilege.Column` grant the SQL layer refuses answers 200 and stores nothing;
  - (b) a `Security.SQLPrivilege.Standard` revoke by a caller who is not the grantor answers 200 and revokes nothing;
  - (c) a standard grant naming an unknown namespace answers 500 `<NAMESPACE>`.

**Governing ADs:**

- AD-2, AD-27: the port, and the named case for Copy from.
- AD-8, AD-29: the pairs.
- AD-10: the reconciliation above.
- AD-13: ids.
- AD-35, AD-39: passwords.
- AD-51, AD-52: port-built queries.
- AD-53, AD-55: two callers.
- AD-58: read-back for the silent no-ops.

**Integration ACs:** No consumers in this story, which builds nothing. Consumes: 9.1 and 9.3 (the user and role editors), 15.1 (the validator). Consumed-by: the three parts, and 18.12.

## Verification

**Manual checks:** `ocupilot-ci` reads as the End state above (no `OcuProbe189*` principal, table or schema; monitor 0).

## Auto Run Result

Status: blocked
Blocking condition: story oversized: three SQL privilege route families plus role owners, user Copy from and password validation measure about three implement passes at Story 18.26's size; the proposed three-story split, the AD-10 reconciliation of criterion 3 and the Copy from decision are in Design Notes › Decision needed for the lead.
