---
title: 'Story 18.28: SQL column and admin privileges'
type: 'feature'
created: '2026-10-08'
status: 'done'
baseline_revision: '3fcc942ca730de8ec2c4a7c55f00f2c3905ababf'
baseline_commit: '3fcc942ca730de8ec2c4a7c55f00f2c3905ababf'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-18-context.md'
warnings: ['oversized', 'multiple-goals']
deferred: []
---

<intent-contract>

## Intent

**Problem:** A user's or role's SQL column and SQL admin privileges are classic-only. The admin API's `Security.SQLPrivilege.Column` answers every refusal 200, sometimes storing a row its own list never shows, and matches the object case-sensitively. `.Admin` answers its grantor rule with a 500 (-99).

**Approach:** Extend Story 18.9's slice: the same tab, the same four tools and `SqlPrivilegePort`, and the same guard, Rules and AD-10 arm. `Type` gains `ADMIN`, and an optional `Column` makes a table or view privilege a column privilege. Two unlisted declared reads feed new tab sections and two read tools.

## Boundaries & Constraints

**Always:**

- **Reads**, unlisted and modeled on `SqlPrivilegeList`:
  - `SqlColumnPrivilegeList` (`permissions/sql-column-privileges`): `.Column` `LIST` with `includeSystem=1`; criteria `grantee`, `namespace` and `object` (257); classic page `%CSP.UI.Portal.Dialog.ColumnPriv`.
  - `SqlAdminPrivilegeList` (`permissions/sql-admin-privileges`): `.Admin` `LIST`; criteria `grantee` and `namespace`; classic page `%CSP.UI.Portal.User`.
  - Each criterion has a `hint`; `object`'s says to spell it as `permissions.sqlprivileges.read` does.
  - `SqlPrivilegeList` adds `HasColumnPriv` to its fields and context.
- **Tools:** the four 18.9 tools, keys unchanged.
  - `Type` adds `ADMIN`; `Object` stays required for every other type; an optional `Column` is allowed only on `TABLE` or `VIEW`.
  - `Column` joins `SCREENVALUES`, `READANSWERS` and `FINGERPRINTSUBJECT`, and the answer always carries it.
  - Each `CLASSICPAGES` adds `%CSP.UI.Portal.Dialog.ColumnPriv`, the classic column dialog. Admin privileges are set on the editor's own page, which each tool already declares.
- **Before any vendor call**, on both callers, as 18.9: the Rules (422 `SQLPRIV.VALIDATION`), then the pairs (Security's set plus READ on the namespace's databases, each refused by name), then the prohibited set, then the port's preconditions.
- **The guard** covers `.Column` and `.Admin`, reads included. It refuses `*` or `,` in `column` or `privilege` (400 `SQLPRIV.LIST`), and a `.Column` `object` that is not two name parts (400 `SQLPRIV.OBJECT`).
- **The column family** (a query with `column`):
  - It spells `object` and takes `type` from the `TABLE` or `VIEW` row of the grantee's Standard `LIST` (`includeSystem` 1) that matches ignoring case. A grant that finds no such row takes them from the caller's own list; when neither list has one, it sends them as given.
  - It counts the grantee's `Direct` `.Column` rows for the column (ignoring case) and the action.
  - A revoke is sent once per grantor, with `asGrantor`.
- **The admin family** (`ADMIN`): the `.Admin` `LIST` row whose privilege matches exactly. A revoke is sent once and names no grantor.
- **In both families:**
  - A grant's state read (`GRANTSTATE`) first confirms the grantee exists: `Security.User` `GET`, then `Security.Role` `GET`. A grantee absent from both is 404 `SQLPRIV.NOGRANTEE`, and nothing is sent.
  - A `SuperUser` row is 409 `.SUPERUSER`. 18.9's `.HELD` and `.NOTHELD` apply.
  - A re-read judges each write: a state that did not move is 409 `.NOTAPPLIED`. `.Admin` #516 with -99 is 403 `.GRANTOR`.
- New codes go in `Api/SqlPrivilegeError.cls`; `Api/Error.cls`'s `SQLPRIV.` dispatch covers them. Probes use 18.9's `SqlPrivilegeProbe` on `ocupilot-ci` only, and are removed. One test class per call.

**Never:**

- A new tool, governance key, entity type, route or AD-10 arm, or an edit to `Prohibited.cls`.
- A catalog read (`$SYSTEM.SQL.Schema`, `INFORMATION_SCHEMA`) to spell an object; both are privilege-filtered.
- A grantor-rule pre-check (18.9 Decision 5).
- A grant-option-only revoke.
- `CUBES`.
- 18.29's role members, Copy from and password checks.
- A change to an existing line of a file Epic 20 is changing, beyond the list inserts in Tasks and EXPERIENCE.md's row edited in place.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected | Error handling |
|---|---|---|---|
| Column read | Columns on a `TABLE`/`VIEW` row, or the tool | `{Column, Action, GrantedBy, GrantOption, GrantedVia}`; Revoke on `Direct` only | Bad object: 400 `.OBJECT`. Another case: no rows (named limit) |
| Admin read | The tab, or the tool | `{Privilege, GrantOption, GrantedVia}` | 18.9's guard |
| Column grant | `TABLE`, `ocusqlprivprobe.t1`, `ID`, `SELECT`, opt. `WithGrant` | A `Direct` row by the caller; a view sent as `TABLE` lands on the view | Unknown grantee: 404 `.NOGRANTEE`. Nothing stored: 409 `.NOTAPPLIED` |
| Column revoke | Another account's `Direct` row | One `REVOKE` per grantor; row gone | No `Direct` row: 409 `.NOTHELD` |
| Admin grant / revoke | `ADMIN`, `%CREATE_TABLE`, opt. `WithGrant` | Row added (option set or upgraded) or removed | -99: 403 `.GRANTOR` |
| Rules | `ADMIN` with object or column; column on another type, not one name, or `DELETE`/`%ALTER`; privilege outside the 31 (case included) | 422 on the field (new `SQLPRIV.COLUMN`) | The mint refuses the same |
| Lists | `*` or `,` in `column` or `privilege` | 400 `.LIST` | Before the vendor |
| OcuPilot's own | Column grant on `OcuPilot_Kernel_State.Turn`; grant to `OcuPilotAdmin` or `%DB_OCUPILOT` | `PROHIBITED.OCUPILOTSQLPRIVILEGE`; `.OCUPILOTROLE` | 18.9's arm |

The Rules:

- `ADMIN` takes the 31 names the instance grants (`GetPrivNum`'s 32 less `%DEFER`, which it refuses #514), spelled exactly. Its `Object` and `Column` are empty.
- A column matches `NAMEPATTERN`.
- Column actions, on a table or a view: `SELECT`, `INSERT`, `UPDATE`, `REFERENCES`.

</intent-contract>

## Code Map

- `Port/SqlPrivilegePort.cls`: `TYPES` :71, `Violations` :141, `State` :185, `Facts` :211, `Grant` :302, `Revoke` :327, `Snippet` :373; the seam overrides `Call` :87.
- `Port/AdminPort.cls`: `MUTATINGTYPES` :466, `BODYLESSTYPES` :482, `SQLCODEFAULTS` :2858, `SqlPrivilegeGuard` :2923, `SqlCodeFault` :2949. `AdminRoutes.cls` :194-199 already has the routes.
- `Screen/Tool/SqlPrivilegeWrite.cls`: `InputSchema` :86, `PortQuery` :158, `ScreenActionDelta` :172, `StateDiff` :200, which already draws a grantor-less revoke as one row.
- `Kernel/Proposal/Prohibited.cls` `SqlPrivilege` :2432 is unchanged: `IsOcuPilotCode("")` is 0, and the grantee arm judges every call.
- Vendor (`[Hidden]`, copied to the plan scratch `epic-18-d9/p1828/`): `.Column` calls `SaveObjPriv`, which drops its SQLCODE; `.Admin`'s `GetPrivNum` lists 32 names, of which the instance grants 31; admin rows are `Security.SQLAdminPrivilegeSet`, keyed by namespace and lower-case grantee.
- Client: the tab's `onRevoke` and `onSubmit`, the store's `distinctRows`, `viaHint` and `load`, the dialog's lists :8-30.
- Tests: `Test/SqlPrivilegeProbe.cls` (`RevokeAll` :74, `RemoveAll` :126, `Remaining` :157; `T1 (ID INT)`, `V1`, `GiveAll`) and `SqlPrivilegeSeamPort`.

## Tasks & Acceptance

**Execution (server):**

- `src/OcuPilot/Port/SqlPrivilegePort.cls`: `ADMIN`, `ADMINPRIVILEGES`, `COLUMNACTIONS` and the `column` and `privilege` keys; the Rules; the family dispatch in `Facts`, `Grant`, `Revoke` and `Snippet`. A column revoke's script names `<grantor>`.
- `src/OcuPilot/Port/AdminPort.cls`: the four new `GRANT`/`REVOKE` pairs in `MUTATINGTYPES` and `BODYLESSTYPES`; both endpoints in `SQLPRIVILEGETYPES`; the guard; `Security.SQLPrivilege.Admin|-99=403/SQLPRIV.GRANTOR`, read from #516's second parameter.
- `src/OcuPilot/Api/SqlPrivilegeError.cls`: `SQLPRIV.COLUMN` on `Column` ("The column is one name of letters, digits and _ @ # $, on a table or view only."); `TYPE` and `OBJECT` name `ADMIN`.
- `src/OcuPilot/Screen/Tool/SqlPrivilegeWrite.cls` and its four subclasses: the Boundaries' tool changes, with `Object` optional in `InputSchema` and `Described` and `DESCRIPTION` covering both kinds.
- `src/OcuPilot/Screen/Descriptor/SqlPrivilegeList.cls`: `HasColumnPriv`.
- `src/OcuPilot/Screen/Descriptor/SqlColumnPrivilegeList.cls` and `SqlAdminPrivilegeList.cls` (new): composite ids `[Column, Action, GrantedVia, GrantedBy]` and `[Privilege, GrantedVia]`; `toolIdentifier` `permissions.sqlcolumnprivileges` and `permissions.sqladminprivileges`; three `userPromptGroupAccess` prompts each.

**Execution (client):**

- `sql-privileges-tab.store.ts`: `HasColumnPriv` on rows; admin rows read with the object rows; a column target `{type, object}` read on demand. A namespace change drops all three, and every read keeps the generation guard.
- `sql-privileges-tab.ts`:
  - An "Admin privileges" section, and a "Column privileges on `<object>`" section.
  - Columns on a `TABLE` or `VIEW` row with `HasColumnPriv`, in place of Revoke on a column-only row.
  - Revoke sends `Type`, `Object`, `Column` and `Action`, or `ADMIN` and the privilege. `viaHint` reads `Role - <r>`.
- `sql-privilege-dialog.ts`: `ADMIN` hides Object and lists the 31. An optional Column for `TABLE` and `VIEW` switches to the column actions. The lists are exported.
- `strings.ts` (add-only) and EXPERIENCE.md's Permissions Fixed strings row, in place. Regenerate `screens.generated.ts`, and re-base `angular.json` if its budget is crossed (DW-1166).

**Tests:**

- `Test/SqlPrivilegeProbe.cls`: `RevokeAll` also revokes admin and column privileges; `RemoveAll` deletes, and `Remaining` counts, a probe grantee's `Security.SQLAdminPrivilegeSet` rows.
- `Test/SqlPrivilegeDescriptor.cls`: the declarations, tool parameters, new code, `.Admin` entries and Rules legs.
- `Test/SqlPrivilegeRead.cls`: each new read answers one set for screen and tool (`Direct` and role-held rows); the guard's new refusals reach no vendor call.
- `Test/SqlColumnPrivilegeWrite.cls` (new, armed by `OCUPILOT_ALLOW_PRINCIPALS`): the matrix's column rows for a user and a role on both callers, including a lower-case object, a view sent as `TABLE`, another grantor's row (`SqlPrivilegeGate`'s principal), an absent column, and an unknown grantee with no row stored.
- `Test/SqlAdminPrivilegeWrite.cls` (new, armed): the matrix's admin rows on both callers, including an upgrade, `SUPERUSER` (`GiveAll`), -99 on both verbs and `.OCUPILOTROLE`.
- `Test/SqlPrivilegeGate.cls`: column and admin calls pass with the gate's pairs and are refused by name without the namespace READ.
- Client: `sql-privileges-tab.spec.ts`, `.store.spec.ts` and `sql-privilege-dialog.spec.ts`.
- `ui/tools/sql-privilege-lists.test.mjs` (new, DW-2190): the dialog's lists equal the port's `TYPES`, action lists, `COLUMNACTIONS` and `ADMINPRIVILEGES`.
- `ui/browser/permissions-sql-privileges.browser-spec.mjs`, after the tab answers: a probe user's column grant from the dialog, Columns, its `Direct` row and revoke; an admin grant, shown and revoked.

**Shared-surface sweep (Rule 30).** List inserts only, wherever Epic 20 is changing the file:

- The two read tools: `Test/ReadTool.cls` :94, `SurfaceCoverage` (and the two screens), and `ToolRoundTrip` `REFUSEEMPTY` (`:SQLPRIV.NAMESPACE`).
- The two screens: `Test/Descriptor.cls` :177, `Wire.cls` :565, `WireSecurityRead.cls` :846, :997 and :1026, `ui/tools/navigation.test.mjs` :244 and `screen-mirror.test.mjs` :1385.
- `MappingDescriptor` `CLASSICROSTER`: `ColumnPriv` on the four rows. `PortFixture` `MUTATINGTYPES`: the four pairs.
- `scripts/ci-throwaway.sh`: a new block whose `# classes:` names the two new classes.
- Then grep `ui/browser`, `ui/tools`, the `ui/src` specs and `src/OcuPilot/Test` for `sqlprivileges`, `grantsql`, `revokesql` and `SQL_PRIVILEGE_TYPES`.

**Acceptance Criteria:**

- **C1.** Given a probe user and role in USER and a table, when their column privileges are listed, granted (in any case, with or without the grant option) and revoked from the tab and by a confirmed proposal, then each round-trips through `Security.SQLPrivilege.Column`, and the tab and the read tool answer one set. A grant stored as nothing reads as refused (`.NOTAPPLIED`), and an unknown grantee is refused before the call (`.NOGRANTEE`).
- **C2.** Given a probe user and role in USER, when their admin privileges are listed, granted (with and without the admin option) and revoked by either caller, then each round-trips through `Security.SQLPrivilege.Admin`. A privilege outside the 31 is refused before any call, and -99 is 403 `SQLPRIV.GRANTOR`.
- **C3.** Given a column grant naming a wildcard, a list, or a table in an OcuPilot schema, when either caller sends it, then 18.9's input refusals and AD-10's schema arm refuse it before any vendor call.
- **C4.** Given the rosters, when the suites run, then the descriptors, tools, codes and the dialog's lists are pinned on both sides (DW-2190).
- **Integration.** Given `ocupilot-ci`, when the tab and the agent act, then the tab goes through `GET /screens/:screen/read` and `POST /screens/:screen/action` (`grant-sql` and `revoke-sql` with `Column`), and the agent through the four tools and the two new read tools.

### Review Findings

Code review, 2026-10-08: four layers, 48 rows; 20 entries after grouping (14 patched, 6 deferred) and 21 rows rejected.

- [x] [Review][Patch] (high, AD-59) A column copy-out script sent the object and type as the query spelled them, so its lower-case revoke removes nothing and a view sent as `TABLE` stores an unlisted row; it now ends with a comment saying to name them as the instance lists them [src/OcuPilot/Port/SqlPrivilegePort.cls:634]
- [x] [Review][Patch] (med) The Rules and the dialog took `%DEFER`, which the instance's admin privilege store refuses (#514, 500 and a severity-2 log on every grant), and no test sent the names to the instance; dropped from both lists, refused 422 before any call, and every listed name is now granted and revoked live [src/OcuPilot/Port/SqlPrivilegePort.cls:101]
- [x] [Review][Patch] (med) The agent's admin revoke card was never asserted [src/OcuPilot/Test/SqlAdminPrivilegeWrite.cls:138]
- [x] [Review][Patch] (med) An assertion read back the `Body` helper's own constant `TABLE` [src/OcuPilot/Test/SqlColumnPrivilegeWrite.cls:170]
- [x] [Review][Patch] (med, Rule 30) Browser tests 3 and 4 relied on test 1's revoke, and the browser and dialog specs asserted a literal 32; each test now revokes the probe principals' privileges first, the Revoke check is scoped to the table's row, and the offered list equals the dialog's export [ui/browser/permissions-sql-privileges.browser-spec.mjs:199]
- [x] [Review][Patch] (low) Contract text left from Story 18.9: `ScreenAction.Values`' doc, the port's header (one `LIST`, `cascade` 0 on every revoke, the query keys) and `ToolRoundTrip`'s `REFUSEEMPTY` note [src/OcuPilot/Api/ScreenAction.cls:507]
- [x] [Review][Patch] (low) The column descriptor named role rows `Role - <name>`; they read `Role:<name>` [src/OcuPilot/Screen/Descriptor/SqlColumnPrivilegeList.cls:15]
- [x] [Review][Patch] (low) The revoke tools told the agent a revoke goes once per direct grantor; an admin revoke goes once [src/OcuPilot/Screen/Tool/UserSqlRevoke.cls:12]
- [x] [Review][Patch] (low) The vendor-defect control leg did not say what its red would mean [src/OcuPilot/Test/SqlColumnPrivilegeWrite.cls:204]
- [x] [Review][Patch] (low) The kernel-refusal test lost its whole-object payload; it now asks with and without a column [src/OcuPilot/Test/SqlPrivilegeDescriptor.cls:380]
- [x] [Review][Patch] (low) The tab spec's namespace test named an admin-row drop it did not assert [ui/src/app/areas/permissions/sql-privileges-tab.spec.ts:318]
- [x] [Review][Patch] (low) The DW-2190 parity test held three types' actions as literals; the port declares `PROCEDUREACTIONS` and `USEACTIONS` and the test reads them [ui/tools/sql-privilege-lists.test.mjs:62]
- [x] [Review][Patch] (low) A stray space before a semicolon in the Permissions Fixed-strings row [EXPERIENCE.md:468]
- [x] [Review][Patch] (low, Rule 19) `SCREENOPTIONAL`'s handling in `ScreenAction.Values` had no mutation line; written under Verification
- [x] [Review][Defer] (med, Rule 30) Literal screen lists and counts in contended rosters (`Wire.cls`, `WireSecurityRead.cls`, `navigation.test.mjs`, `screen-mirror.test.mjs`, `ReadTool.cls`'s 47) [src/OcuPilot/Test/ReadTool.cls:368] — deferred: list inserts the spec instructs in Epic 20's shared files; occurrence on DW-2202 (routed 23-5)
- [x] [Review][Defer] Vendor candidate: `.Admin` `GRANT` of `%DEFER`, which `GetPrivNum` maps, answers 500 #514 — deferred: DW-2215, owner hold
- [x] [Review][Defer] (low) `SCREENOPTIONAL` has no spine sentence beside AD-56 (ii) — deferred: DW-2216, the lead's Rule 20 write
- [x] [Review][Defer] (low) The spec and the epic context say 32 admin privileges and 32 `SuperUser` rows; the instance takes and lists 31 — deferred: DW-2217, the lead's Rule 5 amendment
- [x] [Review][Defer] (low) The admin option is worded "grant option" on the dialog and card — deferred: DW-2218 wontfix-accepted, reopen_if 18.29 ships an "admin option" string
- [x] [Review][Defer] (low) A table held only through columns lists with blank cells and no hint — deferred: DW-2219 wontfix-accepted

Rejected:

- `false` A probe principal's admin set outlives cleanup: `Security.SQLAdminPrivilegeSet` held 0 rows after the sweep and after runs 693-701.
- `false` An unknown grantee's column or admin revoke or read answers 500: measured 200 `[]` on each `LIST` and 409 `SQLPRIV.NOTHELD` on `REVOKESTATE`.
- `low` A column revoke may cascade to dependents: the column call passes the 0 that `RevokePrivilege` takes as cascade (inference), so a dependent most likely leaves it `NOTAPPLIED`; a grantee passing on `WITH GRANT` would settle it.
- `low` A non-column action names `Column`'s sentence: spec-bound (Tasks fixes the field and the sentence).
- `low` `REASONLIST`, `REASONOBJECT` and `REASONACTION` read awkwardly for admin and column calls: the guard's two are unreachable from either tool caller, and `ACTION`'s holds.
- `false` The column section has no close control: it shows the chosen object's column privileges, and the spec asks for none.
- `low` Several Columns buttons for one object (inference) and three identical refusal banners: cosmetic.
- `false` `press()` hides a sticky-bar defect: the form page's `scroll-padding-bottom` keeps a reached control above the in-flow bar; the in-page click works around Puppeteer's in-viewport check.
- `low` Another case reads no column rows; column refusals answer `NOTAPPLIED`: Decisions 5 and 2.
- `false` `ColumnTally` nears `MAXROWS`: 100,000 against 7,543 measured.
- `low` The card says "table" for a view sent as `TABLE`: the fix moves `Facts`' fingerprinted `Type`.
- `false` The guard calls the subclass's `ObjectValid` and a literal endpoint: no harm, both inside the AD-27 port family.
- `low` The eight mid-sweep reds and the 2.96 MB figure: both fixes edit this spec; each class passed alone, and this review's build measured 3.16 MB with no budget warning.
- `false` `explorerSqlColumnNumber` reuse: one key per value is the convention.
- `false` The `object` hint does not name the tool id: it says to spell the object as the SQL privileges read lists it.
- `low` The agent's mint answers an unknown grantee 400 rather than `NOGRANTEE`: the refusal precedes any call; the code is `Mint.cls`'s uniform absent-target refusal.
- `low` `SCREENOPTIONAL` names are not checked against `SCREENVALUES`: a misspelt name leaves the value required, which the tool's route tests catch.
- `low` The probe's `RevokeColumns` and `RevokeAdmin` drop their statuses: their effect is pinned by `Remaining()` with recorded mutations (runs 126, 131, 132).

## Spec Change Log

- 2026-10-08, spec gate (lead): Decisions 1-5 confirmed. Spine amendments written (AD-8, AD-2, AD-44, AD-52, AD-36). DW-2007 gains `.Admin` #516; DW-2173 gains the unlisted-row cases; vendor candidates DW-2204, DW-2205, DW-2206 under the owner's hold. The column `DELETE` claim is corrected at origin (the split record and the epic context).

## Review Triage Log

### 2026-10-08 — Review pass

- verdicts: 6 findings — high 0, medium 1, low 3, false 2, maybe-false 0
- findings:
  - `[medium]` `patch` Newly optional `Object` on non-ADMIN types has no route or mint test — added a `Violations` case, a route grant and revoke leg and a mint leg (`SqlPrivilegeDescriptor`, `SqlPrivilegeWrite`); mutation recorded (run 159).
  - `[low]` `reject` Rule 19 lines missing for `ScreenAction.Values`, the `privilege` guard key, the column `ObjectValid` refusal and `viaHint` — each sits under an AC with a recorded mutation (one per AC); the route change is now covered by the optional-Object mutation.
  - `[low]` `reject` Revoke card's grantor reads `$Username` while the grant used the wire account — the card is minted in this process and names its own user; both are `_SYSTEM` on every instance the suite runs on, and the assertion passed on a fresh run.
  - `[low]` `reject` `ScreenActionDelta` empty-string guards may be unreachable from the route — a defensive branch with no named harm; removing it is no direct correction worth a change.
  - `[false]` `reject` Intent-alignment: no divergence from the extension reading (R1); wire and tab tested separately by design (Integration AC names both surfaces).
  - `[false]` `reject` Intent-alignment: tab and read tool "answer one set" unasserted — `SqlPrivilegeRead.TestTheColumnAndAdminReadsAnswerOneSetForScreenAndTool` pins it (mutation run 122).

## Design Notes

**Governing ADs:** AD-2, AD-5, AD-8, AD-10, AD-13, AD-22, AD-27, AD-29, AD-36, AD-39, AD-44, AD-51, AD-52, AD-53, AD-55, AD-56, AD-58 and AD-59. AD-15 and AD-53 need no named case: the vendor audits every column and admin grant and revoke (measured).

**Measured at plan** (`ocupilot-ci`, 2026-10-08, `/api/admin/v2`; callers `_SYSTEM` and a principal with `%Admin_Secure:U`, `%DB_USER:R` and `%DB_IRISSYS:R` but no SQL privilege; the split record holds the rest):

- **Column.** A `withGrant` re-grant upgrades the row, and a view's columns take the four actions. `LIST` and `REVOKE` match the object's case (another case lists nothing and revokes nothing, 200); `GRANT`, the column, grantee and grantor match any case. A one-part object makes `LIST` answer 500 `<INVALID OREF>`. A non-grantor's revoke without `asGrantor` removes nothing.
- **Column refusals are all 200.** An absent table or column, or a grantor without the privilege, stores nothing. `DELETE`, `%ALTER`, an unknown grantee, or a view sent as `TABLE` stores a row the list never shows.
- **The Standard list** shows a table held only through columns as `{Action: "", GrantedVia: "", HasColumnPriv: true}`. A super-user's own list names every table and view with its type (7,543 rows in USER, 0.15 s).
- **Admin.** Rows are per namespace, and `Role - <r>` names a role holder; a `withGrant` re-grant upgrades. A lower-case privilege answers 400 #5001, and an unknown grantee 500 #515. Without the admin option, grant and revoke both answer 500 #516 `[..., -99]`; an admin-option holder revokes another's grant. An `%All` holder lists 31 `SuperUser` rows.
- **Other.** `Security.User` and `.Role` `GET` answer an absent name 404 to that principal. The vendor audits even a write that stored nothing. The `OcuSqlColProbe*` probes were removed, leaving S0, so no Task 0 is needed.

**Decisions:**

1. The four 18.9 tools carry both kinds, with the same pairs, Rules, arm and keys.
2. The instance's own lists spell the object, because a revoker may hold no SQL privilege while a grantor appears in their own list. Where no list names the object, the vendor stores nothing and the re-read answers `NOTAPPLIED`.
3. A grant confirms its grantee exists, because a column grant to an unknown name stores a row that a later principal of that name would hold.
4. There is no grantor pre-check: `.Admin` -99 logs at severity 2 until DW-2007 takes #516.
5. The column read sends `includeSystem` 1 because it reads one object. Named limit: another case reads no rows.

**Integration ACs.** In-story consumers are the tab and the agent. Consumes: 18.9, 9.1, 9.3, 16.17 and 23.4. Consumed-by: 18.12 (the agent) and 18.29 (Copy from).

**Ledger (Rule 17).** The inbox is empty. The context routes DW-2190's reopen trigger here, and C4's parity test addresses it.

**For the lead** (Rule 20):

- AD-2: the guard on both endpoints, including the object shape.
- AD-8: no new pairs; -99 also governs an admin revoke.
- AD-44: `ColumnPriv` on the four tools.
- AD-52: the port's spelling, grantee check and per-family revokes.
- AD-36: the two reads, and the column read's case limit.
- DW-2007 gains `.Admin` #516.
- Correct at origin: the split record and the epic context say a column `DELETE` grant stores nothing; it stores an unlisted row.
- Vendor candidates (owner hold): (a) the column `LIST` and `REVOKE` match case and `GRANT` does not; (b) the unlisted rows, which refine DW-2173; (c) `<INVALID OREF>`; (d) `Role - <r>`.

**Footprint (Rule 11).** List inserts in the contended files the sweep names. `footprint_extensions`: `AdminPort.cls`.

**Size (inference).** One implement pass, smaller than 18.9's: no new port, tool, key or arm.

## Verification

**Setup.** Load with `sh /private/tmp/claude-501/-Users-jbrandt-git-OcuPilot/1518373f-040c-4be6-a814-a27bfbff2961/scratchpad/epic-18-d8/load-ocupilot-ci.sh` (`LOAD-OK`, `STARTPATH-OK`). Each test class lands in `%UnitTest_Result` before the next starts. Browser runs use a rebuilt bundle `docker cp`'d to `ocupilot-ci`, with `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776` and `OCUPILOT_BROWSER_CONTAINER=ocupilot-ci`. S0: no `OcuSqlPrivProbe*` or `OcuSqlColProbe*` principal, object, statement-index node, `Security.SQLPrivileges` row or `Security.SQLAdminPrivilegeSet` row; monitor 0.

**Shared surfaces:** the SQL privileges tab, the SQL privilege dialog, the four tools' arguments and `CLASSICPAGES`, the SQL privileges read's fields, the read-tool roster, Permissions' unlisted screens, and `AdminPort`'s type lists. Standing criterion: *existing tests that assert a surface this story changes are updated in this story, and every test the story adds or changes passes on a freshly built instance and in either order.*

**Commands:**

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.<C>` for `SqlPrivilegeDescriptor`, `SqlPrivilegeRead`, `SqlColumnPrivilegeWrite`, `SqlAdminPrivilegeWrite`, `SqlPrivilegeGate` and `SqlPrivilegeWrite`, then each class the sweep changed: 0 failures, totals checked in `%UnitTest_Result`.
- `(loop)` `cd ui && node --test --test-concurrency=1 browser/permissions-sql-privileges.browser-spec.mjs browser/users-editor.browser-spec.mjs browser/roles-editor.browser-spec.mjs`: pass.
- `(loop)` `npm run test:tools && npm run test:components`, `uv run scripts/check-objectscript.py <changed .cls>`, `bash scripts/lint-docs.sh`: clean.
- `(once, before dev_complete)` the full ObjectScript sweep, one class at a time; `cd ui && npm test && npm run build`; `bash scripts/smoke.sh --container ocupilot-ci --user _SYSTEM --password SYS`; S0.
- `(CI)` the full browser suite (Rule 29).

**Mutations (Rule 19)**, each applied on `ocupilot-ci` (the mutated class and its descendants reloaded), observed red, reverted byte-identical (`git status` and `git diff --stat` unchanged). Run numbers are `%UnitTest_Result` run indexes.

- C1:
  - mutation: `ObjectValid` accepts an empty object on every type -> `SqlPrivilegeWrite.TestTheRoutesAnswerAndKeepTheirBodiesClosed` red (run 159).
  - mutation: `SqlPrivilegePort.ColumnTally` sends the object as given -> `SqlColumnPrivilegeWrite.TestTheObjectIsSpelledAndTypedByTheInstance` red (run 104).
  - mutation: the grantee check skipped in `Facts` -> `SqlColumnPrivilegeWrite.TestAnAbsentColumnOrGranteeIsRefusedAndNothingIsStored` red (run 105) and `SqlAdminPrivilegeWrite.TestTheRulesAndOcuPilotsOwnRolesAreRefusedOnBothCallers` red (run 106).
  - mutation: `SqlPrivilegeWrite.PortQuery` drops `Column` -> `SqlColumnPrivilegeWrite`, six methods red (run 115).
  - mutation: the column branch of `WriteQuery` drops `asGrantor` -> `TestARevokeNamesAnotherGrantor` red (run 116).
  - mutation: `ColumnTally` counts a role's row as direct -> `TestAColumnHeldThroughARoleIsNoDirectRow` red (run 117) and `SqlPrivilegeRead.TestTheColumnAndAdminStateReadsComposeTheDirectRows` red (run 118).
  - mutation: the column descriptor's read drops `GrantedVia` -> `SqlPrivilegeRead.TestTheColumnAndAdminReadsAnswerOneSetForScreenAndTool` red (run 122).
- C2:
  - mutation: the `.Admin` -99 entry dropped from `SQLCODEFAULTS` -> `SqlAdminPrivilegeWrite.TestTheGrantorRuleIsRefusedOnBothVerbs` red (run 107) and `SqlPrivilegeDescriptor.TestTheAdminPortAdmitsTheWritesAndMapsTheCodes` red (run 108).
  - mutation: the Rules compare an admin privilege upper-cased -> `SqlPrivilegeDescriptor.TestTheRulesRefuseEachField` red (run 109) and `SqlAdminPrivilegeWrite.TestTheRulesAndOcuPilotsOwnRolesAreRefusedOnBothCallers` red (run 110).
  - mutation: `WriteQuery` sends an admin write to the standard endpoint -> `SqlAdminPrivilegeWrite`, three methods red (run 119).
  - mutation: `AdminTally` counts a role's row as direct -> `TestAnAdminPrivilegeThroughARoleAndAnAllHolderAreNoDirectRows` red (run 120).
  - mutation: `ADMINPRIVILEGES` carries `%DEFER` (the list before code review) -> `SqlAdminPrivilegeWrite.TestEveryAdminPrivilegeTheRulesTakeIsGrantedAndRevoked` red (run 697).
  - mutation: `SqlPrivilegeWrite.StateDiff` drops the grantor-less revoke row -> `SqlAdminPrivilegeWrite.TestAnAdminGrantAndRevokeRoundTripOnBothCallers` red at the revoke card (run 694).
- C3:
  - mutation: the guard's list check drops `column` -> `SqlPrivilegeRead.TestTheGuardRefusesTheColumnAndAdminCallsBeforeTheVendorIsReached` red (run 111).
  - mutation: `Prohibited.SqlPrivilege` skips `IsOcuPilotCode` -> `SqlColumnPrivilegeWrite.TestTheColumnRulesAndOcuPilotsOwnAreRefusedOnBothCallers` red (run 112).
- C4:
  - mutation: the dialog drops `%NOJOURN` from `SQL_ADMIN_PRIVILEGES` -> `sql-privilege-lists.test.mjs` red (the type-action-map and the admin-privileges tests).
  - mutation: the column read's fixed `includeSystem` set to 0 -> `SqlPrivilegeDescriptor.TestTheColumnAndAdminScreensAreDeclared` red (run 124).
- Integration:
  - mutation: `Column` leaves `UserSqlGrant.SCREENVALUES` -> `SqlColumnPrivilegeWrite` red (run 113) and `SqlPrivilegeDescriptor.TestTheToolsDeclareTheirKindPortPairsAndArguments` red (run 114).
  - mutation: the tab's Columns button removed from the bundle -> the browser spec's column test red; the dialog keeps its Object field for `ADMIN` -> the admin test red.
  - mutation: `ScreenAction.Values` ignores `SCREENOPTIONAL` -> `SqlAdminPrivilegeWrite`, four methods red on the route legs (run 693).
  - mutation: `SqlPrivilegePort.Snippet` without the column family's spelling comment (the port before code review) -> `SqlPrivilegeDescriptor.TestTheScriptsMirrorTheBranches` red (run 695).
- Gate and probe:
  - mutation: `ArgumentPairs` answers none -> `SqlPrivilegeGate.TestTheColumnAndAdminCallsRideTheSamePairs` red (run 125).
  - mutation: `RevokeColumns` does nothing -> `SqlPrivilegeRead.TestTheProbeCleanupTakesColumnAndAdminPrivileges` red (run 126); the same with `RevokeAdmin` (run 132) and with the admin-set sweep selecting nothing (run 131).
- Client:
  - mutation: the store keeps the admin rows, or the column target, on a namespace change -> `sql-privileges-tab.store.spec.ts` red; the admin or the column read loses its generation guard -> the same spec red.
  - mutation: the store's `drop` keeps the admin rows -> `sql-privileges-tab.spec.ts`'s namespace test red.
  - mutation: `onRevokeAdmin` sends the privilege as `Object`, Columns drawn on every row, or the column revoke omitting `Column` -> `sql-privileges-tab.spec.ts` red.
  - mutation: the dialog keeps its Object field for `ADMIN`, or keeps the type's actions once a column is named -> `sql-privilege-dialog.spec.ts` red.

## Auto Run Result

Status: done
Blocking condition: none

**Summary.** The four 18.9 tools, the port, the guard and the tab now carry SQL column privileges (an optional `Column` on `TABLE`/`VIEW`) and SQL admin privileges (`Type` `ADMIN`); two unlisted reads (`SqlColumnPrivilegeList`, `SqlAdminPrivilegeList`) feed the new tab sections and read tools; `SqlPrivilegeList` carries `HasColumnPriv`. New code `SQLPRIV.COLUMN`; `.Admin` #516 with -99 is 403 `SQLPRIV.GRANTOR`.

**Beyond the spec.** `Screen/Tool/Write.cls` gains `SCREENOPTIONAL` / `ScreenActionOptionalNames` and `Api/ScreenAction.Values` honours them, so a screen action may omit `Object` (ADMIN) and `Column`; the privilege rides in `Action` for ADMIN. `footprint_extensions`: `AdminPort.cls`, `Screen/Tool/Write.cls`, `Api/ScreenAction.cls`, `SqlPrivilegePort.DELEGATEDTYPES` (the roster pins ToolWrite reads).

**Review.** One pass: 1 medium patched (no test for an absent `Object` on a non-ADMIN type; legs added, mutation run 159), 3 low rejected, 2 false; nothing deferred. Follow-up review recommended: false.

**Verification.** Full ObjectScript sweep on `ocupilot-ci`: 521 classes. 512 green in the sweep; `ToolWrite` failed on a real roster gap (fixed with `DELEGATEDTYPES`, 34 tests green); eight classes (`LedgerWire`, `LicenseServerWrite`, `LicenseWriteGate`, `MappingCodeGlobals`, `MappingWriteGate`, `MftConnectionWrite`, `OAuthAuthorizationServerClients`, `OAuthAuthorizationServerWire`) failed mid-sweep and passed on rerun alone (runs 683-690); cause not traced, none touches this story's files. `test:tools` 1893 and `test:components` 2683 pass; build 2.96 MB (warning 3165 kB, no re-base); smoke 50/50; check-objectscript and lint-docs clean; S0 holds.

**Residual risk.** The eight mid-sweep reds are unexplained order or state effects; the runner's fresh-instance check (Rule 30) covers them.
