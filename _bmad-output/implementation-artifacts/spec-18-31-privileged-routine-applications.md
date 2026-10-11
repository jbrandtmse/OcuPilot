---
title: 'Story 18.31: Privileged routine applications'
type: 'feature'
created: '2026-10-10'
status: 'done'
baseline_commit: '7324381b4e3ac5644f73160b12bd78cac5c938fc'
baseline_revision: '0b19284d3a08a8945f7139dc8cf3c23ef9958c10'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-18-context.md'
warnings: ['oversized']
deferred:
  - summary: >-
      The agent's change or delete of a name a web application holds is refused at the mint as 400 TOOL.ARGUMENTS
      "not present", not as 404 PRIVROUTINE.TYPE.
    evidence: |-
      Mint.cls turns every 404 fresh read into the generic "not present" refusal, so the port's PRIVROUTINE.TYPE fault does not reach the agent; RoutineAppWrite.TestAWebApplicationNameIsAnsweredFromTheFreshReadByEveryRoutineTool pins "0 400".
      The Save, the list's Delete and the port answer 404 PRIVROUTINE.TYPE, and nothing is sent on any path.
    location: >-
      src/OcuPilot/Kernel/Proposal/Mint.cls:184
    severity: low
---

<intent-contract>

## Intent

**Problem:** Privileged routine applications are `Security.Applications` type 4, behind the classic `%CSP.UI.Portal.Applications.PrivRoutineList` and `.PrivRoutine` pages, gated by `%Admin_Secure`. They are classic-only: `AdminPort` answers `Security.PrivilegedRoutine` writes 501, and a web-application write naming one fails as a logged 500 (DW-2252).

**Approach:** A Web applications list at position 5. An unlisted editor with the classic page's General tab. Four tools: `webapp.routineapps.read`, `.create`, `.update` and `.delete`, over `Description`, `Enabled` and `Resource`. The update resends the freshly read roles and routines, because the vendor empties routines it isn't sent. OcuPilot's own two are refused by Story 18.10's arm, extended to the new type. The Application roles, Matching roles and Routines tabs, the database list and the `%All` grant check are Story 18.33's (orchestrator ruling on this story's first plan, 2026-10-10: split for size, Rule 5).

## Boundaries & Constraints

**Always:**

- The id is the name, `foldcase`; a create sends it as typed.
- An update merges the complete set over a fresh `GET` (AD-4). General's Save sends `Description`, `Enabled` and `Resource`.
- Keys: create and update `true`, delete `false` (AD-22).
- Every Rules row is refused before any `PUT` (AD-39).

**Never:**

- Add an AD-10 code or predicate. Reuse `Prohibited.OwnRoutineApplication`, `RefusesBeforeState` and `RoutineEndpointRefused` (Rule 31).
- Write `OcuPilotState` or `OcuPilotIdentity`, even under a mutation.
- Change `WebApp.App` `GET` or the Web applications list.
- Touch `MappingMint` outside Task 12.
- Build on an owner-hold entry.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Read | List or read tool | One read's rows, with `Enabled` and `Description` from each row's `GET` | Missing pair: 403 |
| Create | `OcuProbe1831A` | 201, stored as typed (either caller) | Name any application holds: `PRIVROUTINE.TAKEN` |
| Update | A setting | The complete set, with lists as freshly read | 404; 409 `WRITE.TARGETBUSY` |
| Delete | A probe | Gone; the name is typed to confirm | 404 `PORT.NOTFOUND` |
| Rules | `Name` empty or over 64; `Description` over 256; `Enabled` not one of its six forms; `Resource` neither empty nor a listed `Service`, `System` or `Application` resource; a wrong shape | 422 `PRIVROUTINE.*` on the field; nothing sent | The mint refuses the same way |
| Own two | Any write, by any path | 403 `PROHIBITED.OCUPILOTROUTINEAPP`; controls `aria-disabled` | Nothing sent |
| Web app | A routine tool naming `/csp/user` | 404 `PRIVROUTINE.TYPE` from the fresh read | Nothing sent |
| DW-2252 | `WebApp.App` `PUT` or `DELETE` naming a routine app | 409 `PRIVROUTINE.WEBAPP`, unlogged, before the vendor | Today: 500 #799, and `DELETE` deletes it |

</intent-contract>

## Code Map

Paths are under `src/OcuPilot/` unless they start with `ui/`. **Analog: Story 18.30** (`git show 05b99fd1 c494cfe5`): each roster it edits has a counterpart here.

- **Tools.** `Screen/Tool/RoutineAppCreate`, `RoutineAppUpdate` and `RoutineAppDelete` extend the `DocDbApp*` tools, overriding the tool, descriptor, `PORTCLASS` (`AdminPort`), `RULES`, `CLASSICPAGES`, `Endpoint`, `MintClass` (the kernel's `Mint`), `InputSchema` (no `Namespace`) and `RefusedBeforeState`; the create also `TypedId` and `ArgumentProblem`.
- **Rules and Save.** `Area/WebApp/RoutineAppRules` and `RoutineAppSave` extend Doc DB's, whose new `ERRORCLASS` (default `OcuPilot.Api.DocDbAppError`) and `NAMESPACED` (default 1; 0 drops `Namespace`, its rule and the composite join) leave Doc DB unchanged.
- `Api/RoutineAppError`, `RoutineAppList`, `RoutineAppForm` and `Test/RoutineAppProbe` take their Doc DB siblings' shapes; the `rowGet` is `LdapConfigList` :68's.
- `ui/src/app/areas/web-applications/routine-app-form.page.ts`, `.store.ts` and `routine-app-actions.ts` copy the Doc DB form without `Namespace`: no form base exists (DW-2278).
- `Mint.Merge` :550 sends the whole fresh read, so the update resends `MatchRoles` and `Routines`.

## Tasks & Acceptance

**Task 0** (`ocupilot-ci`, after `LOAD-OK` and `STARTPATH-OK`): record S0; halt on a contradiction with Design Notes.

**Execution:**

1. `routine-application`, `foldcase`, beside `docdb-application` in `Kernel/EntityType.cls`, `Kernel/EntityRef.cls` and `ui/src/app/core/entity-ref.ts`.
2. **DW-2262.** `Api/RoutineAppError.cls`: `PRIVROUTINE.VALIDATION`, `.NAME`, `.DESCRIPTION`, `.ENABLED`, `.RESOURCE`, `.TAKEN`, `.WEBAPP`, and `.TYPE` moved unchanged from `Api/PctAccessError.cls` :2, :49-55 and :67. Repoint `AdminPort` :1972, :1985-1986 and `Api/Error.cls` :1239, :1450.
3. **DW-2252.** `Port/AdminPort.cls`: `Security.PrivilegedRoutine/PUT` and `/DELETE` join `MUTATINGTYPES` :484, `/DELETE` `BODYLESSTYPES` :500 (and `Test/PortFixture.cls` :21). :1257 also calls `PrivilegedRoutineGuard` :1975 for `WebApp.App`: a `PUT` or `DELETE` on a `KeptType` with bit 4 answers 409 `PRIVROUTINE.WEBAPP`, unlogged.
4. `Kernel/Proposal/Prohibited.cls`, add-only (Epic 20 edits it): `TYPEROUTINEAPPLICATION` beside :596 and in :259 and :1327; the lists beside :1124 and :1244 answer `DocDbApplicationFields()`; after :1403, refuse `OCUPILOTROUTINEAPP` for the type when `OwnRoutineApplication(tId)`; `ReviewedFewOnly` beside :1606.
5. `Screen/Descriptor/RoutineAppList`: `web-applications/routine-applications`, position 5, list, instance, id `Name`, the area's pairs, create, and delete with `selfProtection` `ocupilot-routine-application`; `LIST` with `rowGet {key: Name, param: name, fields: [Enabled, Description]}`; columns `Name`, `Enabled`, `Resource`, `Description`; `.PrivRoutineList`; three prompts; `webapp.routineapps`. `RoutineAppForm`: `.../edit`, 0, form-page, `.PrivRoutine`, three prompts, `webapp.routineappform`.
6. Rule `ocupilot-routine-application`, a `Name` of `OcuPilotState` or `OcuPilotIdentity` in any case, sentence `routineAppRefusalOcuPilot` (exists): `Screen/Registry.cls` :2967, `ui/tools/screen-mirror.mjs` :315, `ui/src/app/core/self-protection.ts`; `self-protection.test.mjs` pins the names to `Kernel/State/Base`.
7. `Screen/Tool/RoutineApp*` (`%Admin_Secure:USE`, `PERMITTEDFIELDS` `Description,Enabled,Resource`): create and update declare `CLASSICPAGES` `%CSP.UI.Portal.Applications.PrivRoutine`; the create's `ArgumentProblem` adds `Taken` (`PRIVROUTINE.TAKEN`); the delete's `READANSWERS` and `FINGERPRINTSUBJECT` name all five fields.
8. `Area/WebApp/RoutineAppRules` overrides `IsName` (non-empty, at most 64 characters) and `Taken` (an object, or a 404 carrying `PRIVROUTINE.TYPE`).
9. `Api/Router.cls`, beside Doc DB's: `GET /routine-application/form`, `PUT /routine-application/:id`, `POST /routine-application`. `Screen/Tool/Classification.cls` beside :685: `webapp.routineapps.create` and `.update`, three `ordinary` settings, `MatchRoles` and `Routines` unnamed as in `webapp.list.update`; then `bash scripts/field-lists.sh`. `Kernel/Governance/Baseline.cls`: `true`, `true`, `false`.
10. Client: the Code Map's form (`Name` on create only); on the own two, Save is `aria-disabled` with the rule's sentence. Wire it beside Doc DB's in `ui/src/app/`: `shell/screen-outlet.ts`, `shell/screen-action-handler.ts` (`routineAppDeleteConsequence`, `{name: 'Name'}`) and `app.ts`, sign-out reset included; run `node tools/screen-mirror.mjs`.
11. `ui/src/app/core/strings.ts` add-only, cited `/** EXPERIENCE.md:NNN */`; EXPERIENCE.md :167 and :357 in place, `[ADDED 2026-10-10 - Story 18.31]`. 3000 of 3400 used; stop past 3350.
12. **DW-2279**, only if `grep -c PARENTDESCRIPTION src/OcuPilot/Screen/Tool/MappingMint.cls` is non-zero here: add `Screen/Tool/DocDbAppMint`, extending `MappingMint` with Doc DB wording in its three description parameters; name it in the `DocDbApp*` tools' `MintClass`; add a `DocDbAppWrite` leg. Otherwise change nothing and say so in Auto Run Result.

**Tests** (prefix `OcuProbe1831`; `OCUPILOT_ALLOW_PRINCIPALS` arms all but the descriptor class; `OnAfterOneTest` runs `RoutineAppProbe.RemoveAll`):

13. `Test/RoutineAppDescriptor`: declarations, classification, baseline, codes. `RoutineAppRead`: rows against the raw `GET`, the form read, absent 404. `RoutineAppWrite`: this story's matrix rows, both callers and the wire; the own two through `Prohibits`, as `OwnRoutineApplication.Ask`. `RoutineAppGate`: exactly `%Admin_Secure:USE`, `%DB_IRISSYS:READ` and the install database's READ allow everything; without the first, each is refused by name before any port call.
14. Page, store and actions specs. `ui/browser/routine-applications.browser-spec.mjs`: from the side bar, wait for `OcuPilotState`'s row (Delete `aria-disabled`); create, change and typed-name delete a probe; an after hook runs `RemoveAll`.
15. **Rule 30 sweep**, as 18.30 did:
    - entity types 64 to 65: `Test/Descriptor`, `SuperserverDescriptor`, `MftConnectionDescriptor`;
    - `ReadTool` (327 to 331), `SurfaceCoverage`, `EndpointCoverage`, `ToolRoundTrip`, `Governance`, `ToolDispatch`, `GovernanceBaseline`, `ClassicPageGate`, `MappingDescriptor`, `Test/Prohibited`, a `SaveHoldCoverage` leg; `ScreenRead`, `ToolWrite`, `PortGate`, `ProhibitedRoute`, `RefusalCopy` and `field-lists.test.mjs` only if red;
    - `Wire`, `WireSecurityRead`, `WebSessionsLive`, `navigation.test.mjs`, `side-bar-pins.test.mjs`, `screen-mirror.test.mjs`, `ci-throwaway.sh`'s arming roster;
    - `WebAppPctAccess` :170 reads `RoutineAppError`; `OwnRoutineApplication` drops "501" from :7-9, :291 and :302 and does not re-run its endpoint `DELETE` mutation.

**Acceptance Criteria:**

- **C1.** Given the list and `webapp.routineapps.read`, when each reads, then both answer one read's rows with each row's `GET` `Enabled` and `Description`; the form read answers the name and three settings.
- **C2.** Given probes, when either caller runs the matrix's Create, Update, Delete, Rules, Web app and DW-2252 rows, then each answers as the matrix says, a refusal sends nothing, read-backs `match` (absent after a delete), and a change keeps a probe's role and routine (AD-4).
- **C3.** Given `OcuPilotState` or `OcuPilotIdentity`, when the list, the editor, the mint or the confirm targets it, then it answers 403 `PROHIBITED.OCUPILOTROUTINEAPP`, nothing changes, and Delete and Save are `aria-disabled` with that sentence.
- **C4.** Given the rosters, when the suites run, then position 5, keys `true`/`true`/`false`, `routine-application` `foldcase` on both sides, `PRIVROUTINE.TYPE` from `RoutineAppError` (DW-2262) and the strings bound hold.
- **Integration.** Given `ocupilot-ci`, when the page and the agent act, then the page consumes the three routes and the delete action, and the agent the four tools (C1-C3, the browser spec).

### Review Findings

Code review 2026-10-11 (full-opus, four layers; 30 layer rows, 2 reviewer rows). 0 decision-needed, 10 patch (applied), 1 defer, 20 rejected.

- [x] [Review][Patch] MED: `RoutineAppProbe.Facts` read only the vendor `LIST`, which carries no `Description` and a constant `Enabled`, so "nothing was written" could not fail for 4 of 7 change cases or the gate's change and confirm legs; it now appends each probe's own `GET` (fix-risk low) [src/OcuPilot/Test/RoutineAppProbe.cls:45]
- [x] [Review][Patch] MED: the page spec's C3 "a click sends nothing" could not fail, an unchanged buffer sending nothing anyway; the buffer is changed first. The browser twin ("sends nothing" after a Delete that needs a typed name) is removed (fix-risk low) [ui/src/app/areas/web-applications/routine-app-form.page.spec.ts:217]
- [x] [Review][Patch] MED (Rule 30): `RoutineAppRead` asserted the own two's `Enabled` as literals it never set; it now compares each with its `GET` at that moment (fix-risk low) [src/OcuPilot/Test/RoutineAppRead.cls:92]
- [x] [Review][Patch] MED (Rule 30): entity-type count literals outside the roster pin; dropped from `SuperserverDescriptor` and `MftConnectionDescriptor`, as feature already has them (fix-risk low) [src/OcuPilot/Test/SuperserverDescriptor.cls:130]
- [x] [Review][Patch] MED (Rule 30): the browser spec clicked a side-bar item and a filtered row before either answered; it waits for the item and for the filter to apply (fix-risk low) [ui/browser/routine-applications.browser-spec.mjs:142]
- [x] [Review][Patch] MED (Rule 2/31): `RoutineAppGate` was a 215-line near-copy of `DocDbAppGate` with no stated reason; it now extends it, which gains `SAVEPATH`, `NAMESPACE`, `OBJECTS` and name, id and body helpers (fix-risk med) [src/OcuPilot/Test/RoutineAppGate.cls:14]
- [x] [Review][Patch] LOW: `MappingDescriptor` named seventy-three tools; `CLASSICROSTER` holds 74 [src/OcuPilot/Test/MappingDescriptor.cls:119]
- [x] [Review][Patch] LOW: `DocDbAppRules.ERRORCLASS` and `Check` docs did not say the namespace code and rule apply only when `NAMESPACED` [src/OcuPilot/Area/WebApp/DocDbAppRules.cls:29]
- [x] [Review][Patch] LOW: `AdminPort.MUTATINGTYPES` said the routine `PUT` empties any list it omits; only the routines were measured [src/OcuPilot/Port/AdminPort.cls:489]
- [x] [Review][Patch] LOW: `RoutineAppWrite`'s header named a `MergeUpdate` the class lacks and an unrecorded `Resource` mutation [src/OcuPilot/Test/RoutineAppWrite.cls:190]
- [x] [Review][Defer] MED (Rule 2): the client form, store and actions copy Doc DB's for DW-2278's reason (no form base) [ui/src/app/areas/web-applications/routine-app-form.store.ts:1] — deferred: occurrence appended to DW-2278, routed to 23-7-the-range-end-cleanup-part-6

Decisions: QA's finding (a web application delete naming a routine application answers `WebAppDelete.StateDiff`'s 400 before the port's 409 `PRIVROUTINE.WEBAPP`) matches DW-2252's intent: nothing reaches the vendor and nothing is logged on any path, and the 409 is pinned at the port and on the `PUT` callers, so QA's either-refusal delete legs stand (`by-design`). Doc DB's hooks default to its old behavior (`RenderRead` ignores the fault on a 404); `DocDbAppGate` is green after the refactor. `MappingMint` and `Mint` are untouched. No story test counts applications, so `/csp/myapp` (48 against 47) matters to none. DW-2296 stays as harvested.

Rejected:

- false: a `WebApp.PctClassAccess` write naming `OcuPilotState` reaches the application — the vendor writes `Security.WebAppPctAccess`, not the application (vendor source read on `ocupilot-ci`).
- false: a trailing slash slips past the `WebApp.App` guard — `Security.Applications.Exists` and `Get` resolve `OcuPilotState/` as type 4 (probed).
- false: `ReadTool`'s write-tool count is stale — the message lists each story's additions, 18.31's among them.
- false: no `%Admin_Secure`-only read legs — `WireSecurityRead` pins that principal's `%DB_IRISSYS:READ` verdict on both routine screens; Task 13 words the read leg "without the first".
- false: `RoutineAppProbe.Lists` can throw — the vendor `GET` always answers both lists, and a missing one fails loudly.
- false: own-two fields use native `disabled` — Save, the gated action, is `aria-disabled` with the sentence; read-only fields use `[disabled]="locked"` as ten sibling form pages do.
- false: no audit measurement — `%System/%Security/ApplicationChange` records each create and delete (168 events for `OcuProbe1831` names on `ocupilot-ci`), so AD-53 owes no named gap.
- low, wontfix-accepted: a create naming an own application answers "already present" or 422 `PRIVROUTINE.TAKEN`, not 403 — `Mint` skips `RefusedBeforeState` for a create, so the Code Map's override would be inert, and nothing is sent; reopen_if= such a create is accepted or sends a `PUT`.
- low, wontfix-accepted: the card states no consequence when `Resource` is cleared — no sibling editor states one; reopen_if= 18.33's grant check or the owner asks for it.
- low, wontfix-accepted: the form read echoes the URL's spelling of the name — the list links the stored spelling; reopen_if= a name opened from the list shows re-cased.
- low, wontfix-accepted: `WireSecurityRead`'s messages omit the new screens — cosmetic; reopen_if= a reader is misled by one.
- low, wontfix-accepted: only the update confirm runs least-privileged — as `DocDbAppGate`; reopen_if= a create or delete confirm skips its gate.
- low, wontfix-accepted: a padded or whitespace-only name passes `IsName` — reopen_if= one is stored or answers 500.
- low, wontfix-theoretical: a client application (type 8) passes the `WebApp.App` guard — outside DW-2252; real if an instance holds one and a web application write names it.
- low, wontfix-theoretical: a create racing another writer between `Taken` and the `PUT` — real only for a writer outside OcuPilot inside one Save; OcuPilot's writers take the per-target hold.
- low, wontfix-accepted: the resource picker reads 500 rows, as Doc DB's — reopen_if= an instance lists more.
- low, wontfix-accepted: the delete's precondition text says "record" — unreachable here, a routine application's `GET` always answering its settings; reopen_if= it is reached.
- not re-opened: the mint's 400 for a web application name (DW-2296), the shape codes (earlier triage) and the Rule 30 sweep's counts (a spec edit).

## Spec Change Log

- 2026-10-10, spec gate (lead): DW-2279 re-owned to 18.33, because 20.3 is not on feature (Task 12 stays unbuilt here); AD-2, AD-13, AD-44 and AD-54 amended.

- 2026-10-10, spec gate (lead): the intent was trimmed of 18.33's half (the Deltas row, the role and routine Rules clauses, and the tab-delta and `MatchRoles`-grant Always bullets), matching the split ruling.

- 2026-10-10, lead: the orchestrator ruled to split for size. 18.31 keeps the list, the General tab and the four tools over `Description`, `Enabled` and `Resource`, plus DW-2252, DW-2262 and DW-2279 (conditional on 20.3). The roles, matching roles and routines tabs, the database list and C6 move to 18.33, whose plan is seeded from this spec's first version (commit `18436f8d`). The status is reset to `draft` for a re-plan.

## Review Triage Log

### 2026-10-10 — Review pass

- verdicts: 21 findings — high 0, medium 2, low 18, false 1, maybe-false 0
- findings:
  - `[medium]` `[patch]` verification-gap: the `routine-application` reviewed-few branch of `Prohibits` had no test (the one non-own leg named `Description`, which the fall-through also accepts, on an absent target) — added a seeded probe and `Routines` and `MatchRoles` legs expecting `PROHIBITED.UNCOVEREDFIELD`; skipping the branch reddens `TestTheOwnTwoApplicationsAreRefusedEveryWrite` (run 125).
  - `[low]` `[patch]` verification-gap: `MappingDescriptor`'s comment named "ninety-seven" tools; `CLASSICROSTER` holds 73 (counted) — now "seventy-three".
  - `[false]` `[reject]` verification-gap: the `WebApp.App` guard checks the exact name given — `Security.Applications.Exists` is case-insensitive on the instance (reviewer's own probe), so a re-cased name is caught.
  - `[low]` `[patch]` verification-gap: `routine-app-form.store.spec.ts` asserted `store.value('Namespace')` is `''`, true by construction — removed from the assertion; the page and browser specs pin the absent control.
  - `[low]` `[patch]` verification-gap: the taken-name loop's sentence assertion was vacuous for the own two (`|| tHeld '= "/csp/user"`) — an unconditional form failed, because the kernel refuses a held own name as "already present" — now each name asserts its own expected text.
  - `[low]` `[reject]` verification-gap: the browser spec's first test reads the dialog and actions right after the click — redundant with the `aria-disabled` read and `screen-action-handler.spec.ts`, so no everyday defect and the fix needs a browser rerun.
  - `[low]` `[patch]` verification-gap: no recorded mutation for the delete's `MUTATINGTYPES` and `BODYLESSTYPES` entries, though a comment named it — run (run 131) and recorded.
  - `[low]` `[reject]` verification-gap: no recorded mutation for the busy, moved-target, `SaveHoldCoverage` and `RenderRead` legs — Rule 19 asks one per AC and C2 has eight lines; the legs sit inside tests those lines already redden.
  - `[medium]` `[patch]` verification-gap: nothing moved the roles or routines after a delete mint, so `FINGERPRINTSUBJECT`'s lists were pinned only as a literal — added the lists-moved confirm to `TestADeleteRemovesTheApplicationOnBothCallers`, red without the lists in the subject (run 126).
  - `[low]` `[patch]` verification-gap: the wire half of C3 — `OwnRoutineApplication.TestEndpointDisableRefused` claimed a red it never showed once the 501 backstop went — now "not re-run", as its delete twin; the unseparated `RefusedBeforeState` and kernel arms are DW-2283's by the spec.
  - `[low]` `[reject]` verification-gap: no jsdom pin for the `DESCRIPTOR_PAGES` entry and `inject(RoutineAppActions)` — Doc DB's twins have none either, and the browser spec opens the editor through both.
  - `[low]` `[reject]` intent-alignment: a create naming OcuPilot's own two answers 422 `PRIVROUTINE.TAKEN` (the mint, "already present"), not 403 — the Own two and Create rows both apply, nothing is sent, and the kernel's 403 for a create is pinned through `Prohibits`.
  - `[low]` `[reject]` intent-alignment: the agent's mint naming `/csp/user` answers 400 `TOOL.ARGUMENTS`, not 404 `PRIVROUTINE.TYPE` — the `Mint` contract answers a missing target 400, the 404 is the port, Save and Delete answer, and nothing is sent; recorded under `deferred:`.
  - `[low]` `[reject]` intent-alignment: DW-2252 is tested at the port, not through the editor or `webapp.list.update`, "unlogged" holds by construction and `KeptType` passes a caller short of its pair — the guard sits at the port every caller shares, runs before the vendor call that logs, and a caller short of the pair is refused at its gate first.
  - `[low]` `[reject]` intent-alignment: a shape violation carries `PORT.FIELD.SHAPE`, the mint answers 400 and an empty name is refused at the tool's entry — Doc DB's twins do the same, and the envelope is `PRIVROUTINE.VALIDATION`.
  - `[low]` `[reject]` intent-alignment: the Save sends the changed settings, not all three — the update merges the complete set over a fresh `GET` server-side (AD-4), as Doc DB's form does.
  - `[low]` `[patch]` intent-alignment: the resend mutation was worded against `RoutineAppUpdate.MergeUpdate`, which the class does not define — redone as a temporary override (run 127) and the line says so.
  - `[low]` `[patch]` intent-alignment: `OwnRoutineApplication`'s `PUT` recipe would write `OcuPilotIdentity` if run (same edit as the wire-half row above).
  - `[low]` `[reject]` intent-alignment: the agent is driven by calling the tools' mint and confirm in-process — `DocDbAppWrite` does the same.
  - `[low]` `[reject]` intent-alignment: the typed-name confirm exists on the client alone — the spec's own log marks the `TYPED_NAME_ROWS` entry untestable.
  - `[low]` `[reject]` intent-alignment: `RoutineAppGate` asserts the read gate for `%Admin_Secure:USE` alone — Task 13 words it "without the first".

## Design Notes

**Scope.** 18.33 builds the role, matching-role and routine deltas, their rules, the database list and the `MatchRoles` grant check; this story builds none of them.

**Measured** (`ocupilot-ci`; the first plan, `18436f8d`, seeds 18.33; the epic context has the rest):

- `LIST` answers no `Description`; a `GET` body sent back changes nothing. `PUT` keeps the name as typed, and a three-setting create answered 201 with both lists empty (this re-plan). A name over 64 or a description over 256 is 500 #7201.
- For 18.33: a sent `MatchRoles` replaces the list; any `Type` but `Routine` stores `Class` and an empty entry is dropped (vendor candidates, owner hold); no `Type` is 400 #40301; `%DB_HSCUSTOM:R` reads `Config.Databases`.

**For the lead.** DW-2283: `OwnRoutineApplicationWire` settles the own two, DW-2252's `DELETE` leg the rest. The monitor state read 1 before the probe; S0 omits it (epic context).

**Ledger.** DW-2252: Task 3, C2. DW-2262: Task 2, C4. DW-2279: Task 12, which the lead re-owns while 20.3 is off feature, as now.

**Governing ADs:** AD-2 (now `WebApp.App` writes), 3, 4, 5, 6, 8, 10, 13 (`routine-application`, `foldcase`), 14, 15, 22, 27, 34, 36, 39, 44 (`.PrivRoutine`), 52, 53, 54 (`TypedId` on a single-part id), 55, 58, 59; the noted ones want spine lines at the gate (Rule 20). **Consumed-by:** 18.33 (its tabs extend these tools and form; it may re-parent the update onto `WebAppUpdate`), 18.12. **Consumes:** 18.10, 18.30, 8.x (`ResourceList`). **Integration ACs:** the Integration line, `RoutineAppWrite`, the browser spec.

## Verification

**Shared surfaces:** Web applications side bar and lists, entity types, tool, route, key and classic-page rosters, self-protection rules, `PRIVROUTINE.TYPE`'s home, Doc DB's Rules and Save, 18.10's tests, Fixed strings.

**Standing criterion:** *existing tests that assert a surface this story changes are updated in this story, and every test the story adds or changes passes on a freshly built instance and in either order.*

**Commands:**

- `(loop)` `sh /Users/jbrandt/git/OcuPilot/.worktrees/.coordination/carry-2026-10-08/epic-18-d8/load-ocupilot-ci.sh` -- expected `LOAD-OK` and `STARTPATH-OK`.
- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.<C>`, one at a time, totals from `%UnitTest_Result`: the new classes, Task 15's, the four `DocDbApp*`, both `OwnRoutineApplication*` and `WebAppPctAccess`.
- `(loop)` `cd ui && npm run test:tools && npm run test:components`; `uv run scripts/check-objectscript.py`.
- `(loop)` With `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776` and `OCUPILOT_BROWSER_CONTAINER=ocupilot-ci`: `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`, then `node --test --test-concurrency=1 browser/routine-applications.browser-spec.mjs` and Task 15's specs.
- `(once, before dev_complete)` The full ObjectScript sweep, one class at a time; `cd ui && npm test && npm run build`, the bundle against 3,213,418 bytes and the 3326kB warning (DW-1166); `bash scripts/smoke.sh --container ocupilot-ci --user _SYSTEM --password SYS`; S0.

**Mutations (Rule 19),** each recorded as `mutation:`, none writing the own two: C1 drop `rowGet`; C2 drop, each alone, the absence fingerprint, one rule, the `Routines` resend and the guard's `WebApp.App` branch; C3 drop the kernel branch (asked through `Prohibits`; the port arm stays), then the client rule; C4 the delete's key `true`.

- mutation: C1 `RoutineAppList` loses its `rowGet` → `RoutineAppRead.TestTheScreenAndTheReadToolAnswerTheSameRows` red on the probe rows and the own-two rows (run 74).
- mutation: C2 `Mint.AbsenceState` answers present 0 (no absence fingerprint) → `RoutineAppWrite.TestATakenNameAMovedTargetAndABusyTargetAreRefused` red on the taken-since confirm (run 75).
- mutation: C2 `DocDbAppRules.Valid` accepts any `Description` (the length rule removed; `RoutineAppRules` recompiled) → `RoutineAppWrite.TestEveryCreateRuleIsRefusedBeforeAnyPutOnBothCallers` and `TestEveryChangeRuleIsRefusedBeforeAnyPutOnBothCallers` red, the vendor answering 500 (run 76).
- mutation: C2 a temporary `RoutineAppUpdate.MergeUpdate` override that calls `##super` and removes `Routines` from the payload → `RoutineAppWrite.TestAChangeKeepsWhatItDoesNotSendOnBothCallers` red on both callers' lists legs, the vendor emptying the routines (runs 77 and 127); the resend itself is `Mint.Merge`'s, inherited through `DocDbAppUpdate`.
- mutation: C2 (DW-2252) `AdminPort.PrivilegedRoutineGuard` loses its `WebApp.App` branch → `RoutineAppWrite.TestAWebApplicationWriteNamingARoutineApplicationIsRefused` red, the `PUT` unrefused and the `DELETE` deleting the probe (run 78).
- mutation: C3 the kernel's `routine-application` arm in `Prohibited.Prohibits` dropped (asked through `Prohibits`; the port arm and `RefusesBeforeState` stay, so nothing was written) → `RoutineAppWrite.TestTheOwnTwoApplicationsAreRefusedEveryWrite` red on its twelve `Prohibits` legs alone (run 79); the own two read as they did (`S0`).
- mutation: C3 the client rule, `selfProtectionReason`'s `ocupilot-routine-application` branch answering `''` → `self-protection.test.mjs`, `screen-action-handler.spec.ts` and `routine-app-form.page.spec.ts` red, and with the bundle rebuilt and redeployed `routine-applications.browser-spec.mjs`'s first test red on the Delete's `aria-disabled`; nothing was sent for the own application, and the rebuilt and redeployed bundle reads green again.
- mutation: C4 `Baseline` `webapp.routineapps.delete` set `true` → `RoutineAppDescriptor.TestTheBaselineKeysShipAsTheSpecSays` red (run 80).
- mutation: C2 `RoutineAppDelete.FINGERPRINTSUBJECT` without `MatchRoles,Routines` → `RoutineAppWrite.TestADeleteRemovesTheApplicationOnBothCallers` red on its lists-moved confirm, which then deletes the application (run 126).
- mutation: C2 `Security.PrivilegedRoutine/DELETE` dropped from `AdminPort.MUTATINGTYPES` (the `OcuPilot.Port` package recompiled) → all fifteen `RoutineAppWrite` tests red, the delete legs answering 501 and the cleanup that deletes through the port failing (run 131); the 31 probe applications it left were removed by `RoutineAppProbe.RemoveAll` and S0 read again.
- mutation: C3 the `routine-application` reviewed-few branch of `Prohibits` skipped (`If 0`) → `RoutineAppWrite.TestTheOwnTwoApplicationsAreRefusedEveryWrite` red on its `Routines` and `MatchRoles` legs (run 125); each of the three reverted byte-identical.
- mutation (descriptor batch, each reddening its own test in one run, 81 to 89): `RoutineAppCreate.TypedId` replaced by `##super` → `TestTheCreateNamesItsTargetAsTyped`; the `Namespace` removal dropped from `Described` → `TestTheToolsDeclareTheirKindPortPairsAndFields`; `routine-application:foldcase` dropped from `IDRULES` → `TestTheEntityTypeKeepsOneKeyForAnyCase`; `REASONENABLED` emptied → `TestTheCodesAnswerTheirSentences`; `Error.ReasonForViolation`'s `PRIVROUTINE.` line pointed at `PctAccessError` → the same test; `Routines` dropped from the delete's `READANSWERS` → `TestTheDeleteCardListsWhatTheActionRemoves`; the update's permitted fields without `Resource` → the tools test; the list's `sideBarPosition` 6 → `TestTheListIsDeclaredAsTheSpecPlacesIt`; the create entry's `Resource` classified secret → `TestTheClassificationIsReviewed`.
- mutation (write batch, 90 to 96): `NAMEMAX` 63 → `TestTheLongestNameAndDescriptionAreAccepted`; `IsEnabled` refusing a number → `TestEveryEnabledFormChangesTheFlagOnTheFormsSave`; `CreateBody` returning its argument → `TestEveryEnabledFormIsStoredAsABooleanOnBothCallers`; `RESOURCETYPES` `Application` alone → `TestAListedServiceOrApplicationResourceIsAccepted`; an unchanged resource judged → `TestEveryChangeRuleIsRefusedBeforeAnyPutOnBothCallers`; `RoutineAppRules.Taken` reading a `PRIVROUTINE.TYPE` 404 as free → `TestATakenNameAMovedTargetAndABusyTargetAreRefused` on the web application name; `ComposeCreate` without `CompleteBody` → `TestACreateOfTheNameAloneTakesTheInstancesDefaults`.
- mutation (read and gate, 97 to 102): `RoutineAppRules.UPDATETOOL` at the Doc DB tool → `RoutineAppRead.TestTheFormReadAnswersTheNameAndThreeSettings`; `Truth` answering 0 → the same test; `PrivilegedRoutineGuard` passing every name → `TestAWebApplicationNameIsRefusedByTheTypeCheck` and the form leg; `DocDbAppSave.Gate` refusing every caller → `RoutineAppGate.TestTheDeclaredPairsReadAndWrite`; passing every caller → `TestWithoutTheAreasResourceEveryReadAndWriteIsRefused` and `TestWithoutTheSystemDatabaseReadEveryWriteIsRefused`. A mutation that skipped only the screen-pair half of `Gate` stayed green (run 101): the write tool's pairs, asked next, cover the same two.
- mutation (client, each reverted byte-identical): the store drops `readBackOf` → the page spec's create leg red; the page binds Description to `Name` → its create and edit legs red; `flagAt` answers `ON` for every row → its disabled-application leg red; the leave dialog dropped → its leave leg red; `RESOURCE_TYPES` without `System` → the store and page pickers' legs red; `RoutineAppActions` drops its `register` → `routine-app-actions.spec.ts` two tests red; the list's `DESTRUCTIVE_CONSEQUENCES` entry dropped → `screen-action-handler.spec.ts`'s registration leg red; `app.ts` drops `routineAppForm.reset()` → `app.spec.ts`'s sign-out leg red. The list's `TYPED_NAME_ROWS` entry stays unfalsified: a single-name id types its row key, which is the name, so the entry the spec asks for is explicit and untestable.
- (QA) files: `src/OcuPilot/Test/RoutineAppWebAppGuard.cls` (new, armed in `scripts/ci-throwaway.sh`), `RoutineAppDescriptor.TestTheCodeStringsAreThePublishedOnes`, and the list-row assertion in `ui/browser/routine-applications.browser-spec.mjs`.
- mutation: C2 (DW-2252, through the web application callers) `AdminPort.PrivilegedRoutineGuard` without its `pWebApp` branch → `RoutineAppWebAppGuard` red on the editor's Save and the agent's update confirm, both answering the vendor's refusal (run 561); its delete legs stay green, because `WebAppDelete.StateDiff` refuses a routine application's empty record first; with that precondition also removed the delete legs go red and the probe is deleted (run 562); both reverted byte-identical.
- mutation: C4 (DW-2262) `RoutineAppError.WEBAPP` set to `PRIVROUTINE.WEBAPPS` → `RoutineAppDescriptor.TestTheCodeStringsAreThePublishedOnes` red alone (run 565).
- mutation: the arming roster line for `RoutineAppWebAppGuard` removed from `scripts/ci-throwaway.sh` → `ci.test.mjs` "each arming roster names exactly the classes that declare that variable" red.
- mutation (browser, each rebuilt and redeployed, reverted byte-identical): the store's create body without `Description` → the C2 test red on the create body; the action handler sending the delete's id upper-cased → red on the delete's id; the list descriptor without `rowGet`, recompiled → red on the new row assertion; the list's `sideBarPosition` 0 with the mirror regenerated → the C4 test red on the fifth-place assertion.
- mutation (review): C2 a temporary `RoutineAppSave.Update` override that writes the description `leaked` through the port after the inherited Save → `RoutineAppWrite.TestEveryChangeRuleIsRefusedBeforeAnyPutOnBothCallers` red on all seven "nothing was written" legs, its 422 legs green (run 570); reverted byte-identical, green (run 573).
- mutation (review): `DocDbAppSave.Gate` passing every caller → the inherited legs red in `RoutineAppGate` (3 of 3, run 571) and `DocDbAppGate` (2 of 3, run 572); reverted byte-identical, green (runs 574, 575).
- mutation (review): C3 `RoutineAppFormPage.onSave` without its `saveBlocked` guard → `routine-app-form.page.spec.ts`'s C3 test red, the changed buffer put for `OcuPilotState`; reverted byte-identical.

**S0:** no `OcuProbe1831*` application, role or user; the own two as Task 0 recorded them.

## Auto Run Result

Status: done
Blocking condition: none

**Summary.** The Web applications area gains Privileged routine applications (list at position 5, unlisted General-tab editor) and four tools over `Description`, `Enabled` and `Resource`: `webapp.routineapps.read`, `.create`, `.update`, `.delete`. `RoutineAppRules` and `RoutineAppSave` extend Doc DB's, which gain `ERRORCLASS` and `NAMESPACED` and keep their behavior (the four `DocDbApp*` classes are green); the tools extend the `DocDbApp*` tools. The update resends the freshly read roles and routines (`Mint.Merge`). OcuPilot's own two are refused by 18.10's arm, extended to the new type: `Prohibits` gets one branch for the type, with no new code or predicate. DW-2252: `AdminPort` refuses a `WebApp.App` `PUT` or `DELETE` naming a routine application, 409 `PRIVROUTINE.WEBAPP`, before the vendor. DW-2262: `PRIVROUTINE.*` moved to `Api/RoutineAppError`. Task 12 (DW-2279) is not done and `MappingMint`, `MftConnectionCreate`, `MftPort` and the MFT rules are untouched, as the lead re-owned it to 18.33.

**Files changed.** Server: `Api/RoutineAppError` (new codes), `Api/Error` and `Api/PctAccessError` (repointed), `Api/Router` (3 routes), `Area/WebApp/RoutineAppRules` and `RoutineAppSave` (new), `DocDbAppRules` and `DocDbAppSave` (two parameters), `Kernel/EntityType`, `EntityRef`, `Governance/Baseline` (3 keys), `Proposal/Prohibited` (add-only), `Port/AdminPort` (two types, the `WebApp.App` branch), `Screen/Descriptor/RoutineAppList` and `RoutineAppForm`, `Screen/Registry` (the rule), `Screen/Tool/RoutineAppCreate`, `Update`, `Delete`, `Classification`, `ToolFields`. Tests: `RoutineAppDescriptor`, `Read`, `Write`, `Gate`, `Probe` (new), the rosters the Rule 30 sweep names, `OwnRoutineApplication` and `WebAppPctAccess` (501 wording). Client: `routine-app-form.page.ts`, `.store.ts`, `routine-app-actions.ts` with specs, shell wiring (`app.ts`, `screen-outlet.ts`, `screen-action-handler.ts`), `self-protection.ts`, `strings.ts`, `screens.generated.ts` (regenerated), `ui/tools` pins, `ui/browser/routine-applications.browser-spec.mjs`, EXPERIENCE.md :167 and :357 in place, `scripts/ci-throwaway.sh` arming.

**Review.** 21 findings (medium 2, low 18, false 1): 9 patched (the reviewed-few leg, the delete fingerprint leg, two vacuous assertions, the `MappingDescriptor` count, two `OwnRoutineApplication` comment rows, the `MergeUpdate` mutation line, the `MUTATINGTYPES` mutation), 12 rejected with their reasons in the Review Triage Log, one of them (the mint's 400 for a web application name) also recorded under `deferred:`.

**Follow-up review recommended:** false. The two medium patches were each shown red under a mutation and green after it; no unverified risk remains.

**Verification.** `LOAD-OK` and `STARTPATH-OK` on `ocupilot-ci`; `check-objectscript` 0 problems. Final runs on the patched tree: `RoutineAppDescriptor` 11 (run 118), `RoutineAppRead` 3 (119), `RoutineAppWrite` 15 (132), `RoutineAppGate` 3 (121), `DocDbAppWrite` 11 (122), `MappingDescriptor` 6 (129), `OwnRoutineApplication` 12 (130). The implement pass ran, green, `DocDbAppDescriptor` 10 (108), `DocDbAppRead` 5 (109), `DocDbAppGate` 3 (111), `OwnRoutineApplicationWire` 3 (113), `WebAppPctAccess` 11 (114), `ReadTool` 28 (44), `SurfaceCoverage` 4 (45), `EndpointCoverage` 2 (46), `ToolRoundTrip` 2 (47), `Governance` 14 (48), `ToolDispatch` 18 (116), `GovernanceBaseline` 3 (117), `ClassicPageGate` 8 (54), `Test.Prohibited` 14 (115), `SaveHoldCoverage` 2 (58), `Test.Descriptor` 60 (59), `SuperserverDescriptor` 7 (60), `MftConnectionDescriptor` 8 (61), `Wire` 20 (62), `WireSecurityRead` 25 (63), `WebSessionsLive` 7 (64), `ScreenRead` 30 (68), `ToolWrite` 34 (69), `PortGate` 4 (70), `ProhibitedRoute` 24 (71), `RefusalCopy` 8 (72), `DraftRegistry` 9 (73). Client: `npm run test:tools` 1905 pass, the components 222 files and 2812 tests (implement pass), the patched store spec 9 pass, `npm run build` clean through its seven checkers; bundle 3,235,721 bytes (3.03 MB main plus 205 kB styles) under the 3326kB warning, `angular.json` unchanged. Browser: `routine-applications` 2/2 on a rebuilt and redeployed bundle (implement pass: `docdb-applications` 2/2, `web-sessions` 3/3). Fixed strings 3014 of 3400 (3000 plus 14). The full ObjectScript sweep and the full browser suite were not run, as ruled. S0: `ocupilot-ci` holds 47 applications, no `OcuProbe1831*` application, role, user or resource, and OcuPilotState and OcuPilotIdentity read as Task 0 recorded them (type 4, same roles and routines); the run-131 mutation left 31 probe applications, removed by exact name.

**Residual risks.** (1) The agent's mint of a web application's name is a 400, not the matrix's 404 (deferred). (2) A create naming an own application is refused as a held name (422 or "already present"), not 403; the 403 is pinned through `Prohibits`. (3) `OwnRoutineApplication`'s `PUT` and `DELETE` endpoint mutations can no longer be run, since the port now reaches the vendor; DW-2283 settles them. (4) `RoutineAppWrite` is about 670 lines against the 500 guideline; the spec fixed the class layout. (5) The `TYPED_NAME_ROWS` entry cannot be falsified by any test.
