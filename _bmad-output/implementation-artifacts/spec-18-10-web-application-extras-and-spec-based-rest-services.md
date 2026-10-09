---
title: 'Story 18.10: Web application extras and spec-based REST services'
type: 'feature'
created: '2026-10-08'
status: 'draft'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-18-context.md'
warnings: ['multiple-goals']
deferred:
  - summary: >-
      The web-application tools can reach OcuPilot's own privileged routine applications, and no prohibited arm refuses them.
    evidence: |-
      On ocupilot-ci, Prohibited.Prohibits answered 0 for webapp.list.delete on OcuPilotState and for webapp.list.update setting its MatchRoles to :%All. WebApp.App GET, PUT and DELETE reach any application type (vendor source). The delete's mint refuses only because the GET answers no NameSpace (WebAppDelete.StateDiff); whether the update's mint and the editor's Save reach it is unmeasured (inference).
    location: >- # file:line
      src/OcuPilot/Kernel/Proposal/Prohibited.cls:5181
    severity: high (unverified)
---

<intent-contract>

## Intent

**Problem:** The web application editor has no `%`-class access list, which the classic page offers. And OcuPilot's own privileged routine applications, `OcuPilotState` and `OcuPilotIdentity`, are reachable by the web application tools with no AD-10 arm refusing a delete or a `MatchRoles` change (DW-2239, measured at this story's first plan). The vendor's privileged-routine endpoint also writes any application type.

**Approach:** This follows the orchestrator's 2026-10-09 rulings Q1 and Q4 on this story's first plan. Two parts:

- The `%`-class access list on the web application editor, read and changed through the admin API.
- An AD-10 arm refusing a delete of OcuPilot's own two privileged routine applications, and any change to their `MatchRoles` or `Roles`, through every path that reaches them, including the vendor's privileged-routine endpoint. It sits in the family of the existing arms for OcuPilot's own web applications (`PROHIBITED.PRIVILEGEGRANT`, and deleting OcuPilot's own web applications). A target-type check goes wherever OcuPilot reaches that endpoint. A Rule 19 test proves each arm reddens under its mutation, and AD-10 is amended at this story's spec gate.

Doc DB applications (18.30), privileged routine applications (18.31) and spec-based REST services (18.32) are split out.

## Boundaries & Constraints

**Always:** The measurements in Design Notes are this story's baseline and the split stories' Task 0 baseline; re-measure only what they leave open. Under ruling Q3 (2026-10-09), the Fixed-strings bound becomes 3400 in the first code head that needs it, with a comment line in `strings.test.mjs` naming the ruling; a merge takes the higher value.

**Never:** Build Doc DB applications, the privileged routine application screens and tools, or spec-based REST services here. Build on DW-2084 or any other owner-hold entry.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| OcuPilot's own privileged routine application | A delete of `OcuPilotState` or `OcuPilotIdentity`, or a change to its `MatchRoles` or `Roles`, through any path | Refused by the AD-10 arm; nothing sent | Today: `Prohibits` answers 0 |
| Privileged-routine write to a web application | `PUT` or `DELETE` on `Security.PrivilegedRoutine` naming `/csp/...` | Refused by the type check; nothing sent | Vendor: changes the application then answers 500, or deletes it |
| %-class access field shape | A class without a leading `%`, a type other than `AllowClass` or `AllowPrefix`, or an absent application | Refused on its field | Vendor: 500 #1498, #1496 or #869, each logged at severity 2 |

</intent-contract>

## Code Map

- `Port/MgmntPort.cls` -- reads only (`LIST`, `Document`). `PAIRS` is `%Admin_Secure:USE,%DB_IRISSYS:READ` (:33), and `IMPLCLASS` is `%Api.Mgmnt.v2.impl` (:27).
- `Screen/Descriptor/RestApiList.cls` (route `web-applications/rest-apis`), `WebAppForm.cls`, `WebAppList.cls`; client `ui/src/app/areas/web-applications/web-app-editor.page.ts`.
- `Kernel/Proposal/Prohibited.cls`: `ServesOcuPilot` :5181 reads `Install/Roster.cls`'s three web paths and install's web-application records. `WebApplication` :1739.
- `Kernel/State/Base.cls`: `APPLICATION` :50 (`OcuPilotState`) and `IDENTITYAPPLICATION` :60 (`OcuPilotIdentity`). Both are created by `Install/Installer.cls` `EnsureApplication` :2123 and `EnsureIdentityApplication` :2192.
- Derived field lists already exist: `Screen/Tool/FieldLists.cls` `DocDB` :71, `Security.PrivilegedRoutine` :534, `WebApp.PctClassAccess` :799. Routes are in `Port/AdminRoutes.cls` :103-104, :188-189 and :235-236.
- Classic pages, `RESOURCE` `%Admin_Secure` where they declare one: `%CSP.UI.Portal.Dialog.WebAppPctAccess`, `%CSP.UI.Portal.Applications.DocDBList` and `.DocDB`, `.PrivRoutineList` and `.PrivRoutine`.

## Tasks & Acceptance

No build tasks. The story is blocked (Auto Run Result).

## Spec Change Log

- 2026-10-09, lead: the orchestrator's rulings on the first plan were applied to the intent block. Q1 narrows 18.10 to the `%`-class access list plus DW-2239 and splits out 18.30 (Doc DB applications), 18.31 (privileged routine applications) and 18.32 (spec-based REST services). Q2 answers AD-53 with (B), written at 18.32's gate. Q3 sets the Fixed-strings bound to 3400. Q4 puts DW-2239's AD-10 arm and type check here. Reset to `draft` for a re-plan.

## Review Triage Log

## Design Notes

**Task 0, measured at plan.** Measured on `ocupilot-ci` on 2026-10-08, as `_SYSTEM` over HTTP unless noted, with probe prefix `OcuProbe1810`. Every probe object was removed.

*%-class access* (`WebApp.PctClassAccess`; its `ResourcesOR` is `%Admin_Secure`):

- **Keys and body.** The query keys are `name`, `allowType` and `class`. The body `{AllowAccess}` is required: 400 #40301 without it.
- **Upsert.** `PUT` answered 201 on a create and 200 on a change.
- **Validation.**
  - `name` must be an existing application or `all-applications`; anything else is 500 #869.
  - `allowType` must be `AllowClass` or `AllowPrefix`; anything else is 500 #1496.
  - `class` must begin with `%`; anything else is 500 #1498.
- **Ids.** `name` is case-insensitive: a `PUT` on `/CSP/USER` changed `/csp/user`'s entry. `class` is case-sensitive.
- **Delete.** `DELETE` answered 200, and 404 #1495 when repeated.
- **Audit.** Every write recorded `%System/%Security/ApplicationChange`.
- **System entries.** A `PUT` re-sending a system entry's stored value answered 200. A changing `PUT` and a delete of a system entry were not run. The class documents a system entry as not deletable (inference).

*Doc DB applications* (`DocDB`; `%Admin_Secure`):

- **Reads.** `GET` (`name`, `namespace`) answers `{Description, Enabled, Resource}`. `LIST` adds `Name` and `Namespace`.
- **Writes.** `PUT` is an upsert, answering 201 on a create. A partial `PUT` keeps the keys it omits. `Enabled` took `true` and `"0"`; the template shows `""`.
- **Ids.** Name and namespace are case-insensitive.
- **Records stand alone.** The vendor stored a record for an absent namespace, an absent resource and a document database that does not exist.
- **Audit.** Every write recorded `%System/%Security/DocDBChange`.

*Privileged routine applications* (`Security.PrivilegedRoutine`; `%Admin_Secure`):

- **Reads.**
  - `GET` answers `{MatchRoles[{MatchRole, TargetRoles[]}], Routines[{RoutineOrClass, Db, Type}], Enabled, Resource, Description}`. The name is case-insensitive.
  - `LIST` answers `Enabled` false on every row, where `GET` answers true.
- **Writes.**
  - `PUT` is an upsert, answering 201 on a create.
  - A `PUT` without `Routines` empties them, while an omitted `MatchRoles` is kept. A change must therefore send the complete set (AD-4).
- **Validation.** An absent target role answers 500 #879 and stores nothing. An absent `Resource`, an absent `Db` and a routine or class that does not exist are all stored as given.
- **It reaches every application type.**
  - Its `PUT` on a probe web application changed that application's `Description`, then answered 500 `<UNDEFINED>`.
  - Its `DELETE` deleted the web application.
  - Its `GET` of `/api/ocupilot` answers the same 500.
- **OcuPilot's own.** `OcuPilotState` (`MatchRoles` `:%DB_OCUPILOT`) and `OcuPilotIdentity` (`:OcuPilotIdentity`), each with `Routines` `OcuPilot.Kernel.State.Base:HSCUSTOM:1`.
- **Audit.** Every write recorded `%System/%Security/ApplicationChange`.

*Pairs (admin).* A principal holding exactly `%Admin_Secure:U` and `%DB_IRISSYS:R` listed, created and deleted each of the three.

*Spec-based REST services* (`/api/mgmnt/v2/:ns/:app`, reaching `%REST.API`):

- **Create.** `POST` is an upsert: 201 "created", then 200 "updated" on a second `POST`. It generated and compiled `<app>.spec`, `.disp` and `.impl` in USER.
- **Delete.** `DELETE` removed `.spec` and `.disp` and kept `.impl`, as the vendor source says. It answers 200 for an application that does not exist.
- **Refusals.**
  - A `%` name answered 404 with `<PROTECT>` and the IRISLIB directory in its text, and wrote a `%System/%Security/Protect` audit row.
  - A `swagger` 3.0 document answered 404 and left no class.
- **Audit.** No vendor event records a create or a delete (auditing on).
- **Pairs.** `%REST.API` checks `%Development:USE`.
  - A principal holding `%Development:U`, `%DB_IRISSYS:R` and `%DB_USER:R` was refused `<PROTECT>` on `^oddDEF`, with nothing left.
  - With `%DB_USER:RW` it created and deleted.
- **Read in source.**
  - `%REST.API.CreateApplication` treats a `swagger` that is not an object as a URL or a server file name, and fetches or reads it (`LoadDynamicObject`).
  - Its delete calls `$system.OBJ.Delete(<app>.spec)` on whatever class has that name. That may include a class not built from a specification (inference).

**End state.** `ocupilot-ci` is at S0:

- no `OcuProbe1810*` application, Doc DB record, %-class access entry, user, role or class;
- `/csp/user` holds no %-class access entry, as before;
- the monitor state read 2 before the first probe and 0 after `$SYSTEM.Monitor.Clear()`.

**The three inferences, settled.**

- **(a) Privileged routine applications are not covered.** In process on `ocupilot-ci`, `Prohibited.Prohibits` answered 0 for `webapp.list.delete` on `OcuPilotState`, and 0 for `webapp.list.update` setting its `MatchRoles` to `:%All`. The building story needs two refusals, before any vendor call:
  - an AD-10 arm refusing every write to OcuPilot's two privileged routine applications, through either endpoint;
  - a port check refusing a privileged-routine write whose target is not a privileged routine application, by reading `Type` first.
- **(b) REST services.** An `OcuPilot*` package already meets `PROHIBITED.OCUPILOTCODE`: AD-10 covers "new names under its packages". `%` names and `%SYS` are 20.21's refusals. What stays open is the agent caller (see the intent gap below).
- **(c) Doc DB applications stand clear of DW-2084.** They manage `Security.DocDBs` records as objects of their own. They never create or drop a document database, they leave 19.17's in-process drop unchanged, and they report nothing upstream. One interaction (inference): a record naming a resource gates the vendor's `/api/docdb`, but not `DocDbPort`'s drop, which reads no record (AD-29's Story 19.17 named limit).

**Why blocked.**

1. **Size.** The story has four write surfaces: three admin endpoints, each a list or a dialog with two or three tools, and MgmntPort's first writes, each needing its own `Snippet` (AD-59). Story 18.26, with one list, one form and four tools, was a story of its own. The rule is one implement pass at 18.28's size or smaller.
2. **Strings.** About 70 Fixed strings are needed (inference): about 10 for the dialog, about 20 for Doc DB applications (18.26 used 23), about 30 for privileged routine applications and their four editor tabs, and about 10 for the REST services. 36 remain (2964 of 3000).
3. **Intent gap, AD-53 (Rule 6).** AD-53 makes the class and routine Saves agent-proposed, "the agent authoring code only through these saves". A REST create generates and compiles three classes from the caller's document, and a write tool is advertised by default (AD-8). Advertised, the create lets the agent write code down a second path, which contradicts that rule. As an unadvertised tool (a new AD-53 named case), it is screen-only. Both readings are defensible, and they lead to different products.
   - **Recommendation (B):** amend AD-53 to name the REST create as the agent's second code path, held to 20.21's rules at the mint and at Confirm. All three generated names must be stored in the namespace's own routines database, and none may be in `%SYS`, a `%` name or `OcuPilot*`. The card shows the whole document, and the key ships enabled. The delete is destructive and its key ships `false` (AD-22). The owner's 20.20 direction ("Agent should be able to propose new classes and routines") supports this.
   - **Alternative (A):** the create is unadvertised and screen-only.

**Proposed split.** The lead numbers the new stories; 18.30 is the burn-down.

- **18.10** becomes the %-class access list: a dialog off the web-app editor, with `WebApp.PctClassAccess` `PUT` and `DELETE` (about 10 strings, within the 36).
- **New:** Doc DB applications, a list and a form with three tools (about 20 strings).
- **New:** privileged routine applications, a list and an editor with three tools, the AD-10 arm and the type check from (a). It can also close this spec's `deferred:` item (about 30 strings).
- **New:** spec-based REST services through MgmntPort, after the AD-53 ruling (about 10 strings).

Each later story moves the bound at its own spec gate, under `strings.test.mjs`'s protocol. The alternative is two stories, the admin extras and the REST services. Each would exceed the size rule and need the bound moved.

**Governing ADs:** AD-2, AD-3, AD-4, AD-8, AD-10, AD-13, AD-15, AD-21, AD-22, AD-27, AD-29, AD-44, AD-52, AD-53, AD-54, AD-58 and AD-59.

**Integration ACs.** No consumers in this plan. The first consumer is Story 18.12 (the agent's tools for this stage). Consumes: 6.1 and 16.1 (the REST API explorer), 8.x (the web-app editor) and 19.17 (`DocDbPort`).

**Ledger (Rule 17).** The inbox is empty. DW-2084 (decision-pending) is not built on; see (c).

**For the lead** (Rule 20). These items are for the stories that build each part; this plan writes nothing to the spine.

- **AD-10:** the arm in (a) for OcuPilot's two privileged routine applications.
- **AD-53:** the REST create's posture, (B) or (A).
- **AD-21:** the REST create's document is passed as a parsed object, never as a string, because the vendor fetches a URL or reads a server file named by a string.
- **AD-15 and AD-53 named gaps:** a REST create or delete records no vendor event.
- **AD-8:** the three admin surfaces need exactly `%Admin_Secure:USE` and `%DB_IRISSYS:READ`. The REST writes need `%Development:USE` and WRITE on the namespace's routines database, which MgmntPort's read pairs do not include.
- **AD-4:** a privileged routine `PUT` empties an omitted `Routines`. Doc DB records keep omitted keys.
- **AD-13:** a %-class access entry is keyed by its name (case-insensitive) and its class (exact). A Doc DB record's name and namespace, and a privileged routine application's name, are case-insensitive.
- **Vendor candidates** (owner hold; never reported):
  1. the privileged-routine endpoint writes to, deletes and fails on any application type;
  2. its `LIST` answers `Enabled` false for enabled applications;
  3. the management API answers a `%` name with a 404 that carries a server directory.
- **Pre-existing gap:** the `deferred:` entry above.

## Verification

**Manual checks:**

- The Task 0 probes in Design Notes ran on `ocupilot-ci` after the loader printed `LOAD-OK` and `STARTPATH-OK`, one at a time. `ocupilot` was not touched, and no IRIS MCP call was made.
- `ocupilot-ci` is at S0, as recorded under Design Notes, End state.
- Shared surfaces: none, because this plan changes no source. The bundle (3,173,310 bytes initial against the 3326kB warning) is unchanged.

## Auto Run Result

Status: blocked
Blocking condition: Two conditions. (1) Size and Fixed strings: the story has four write surfaces needing about 70 Fixed strings against the 36 left (2964 of 3000), and is more than one implement pass at 18.28's size; the proposed four-way split is in Design Notes. (2) Intent gap on AD-53: whether the agent may propose a spec-based REST service create, when AD-53 says the agent writes code only through the class and routine Saves; the recommendation is (B) in Design Notes.
