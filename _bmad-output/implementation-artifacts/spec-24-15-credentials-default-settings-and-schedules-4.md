---
title: 'Story 24.15: Credentials, default settings and schedules (Batch 3: schedules)'
type: 'feature'
created: '2026-11-22'
status: 'blocked'
baseline_revision: 'fab07a3951807de4ceadd4bc5d427251f9bb29a9'
review_loop_iteration: 0
followup_review_recommended: false
owned_ledger: 'DW-2838'
context:
  - '{project-root}/_bmad-output/implementation-artifacts/spec-24-15-credentials-default-settings-and-schedules-2.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** An interoperability namespace's schedule specs (`Ens.Util.Schedule`, the classic `EnsPortal.ScheduleEditor` page, "Schedule Specs") have no OcuPilot screen or tool, so the story's third surface does not yet round-trip over its backing class. Batch 2 also left a defect (DW-2838): a refused New credential clears the typed password, so a corrected second Save adds the credential with no password and no warning.

**Approach:** Batch 3 of three, the story's last (Batch 1's Design Notes › Questions 1). First commit: DW-2838, the credential dialog keeps the typed password across a refused Save and clears it only on an accepted one. Then Interoperability gains **Schedule specs**: a list read through `InteropPort`, with add, edit and remove, each one operation reached by the screen and by the agent, built on Batch 2's family pattern. "Round-trips over its backing class" means: a schedule spec added or edited from either caller reads back from `Ens.Util.Schedule` exactly as sent, and a removed one is gone.

## Boundaries & Constraints

**Always:**

- **DW-2838 first, as its own commit** (orchestrator ruling): the New credential password is cleared only by an accepted Save, as `ldap-editor.store.ts` and `ssl-form.store.ts` do; no new string.
- **One port (AD-62).** `InteropPort` gains `Schedules` (`LIST`, `SCHEDULE`, `ADDSCHEDULE`, `SETSCHEDULE`, `REMOVESCHEDULE`) over `Ens.Util.Schedule` (`%New`, `%OpenId` at concurrency 4, `%Save`, `%DeleteId`; SQL read with `%ExecDirectNoPriv` after the gate), switched, with no `OcuPilot.*` call while switched.
- **Rows** `{Name, Description, ScheduleSpec, Deployable, Namespace}`, id `Name` kept exactly, capped with truncation reported (AD-36). The spec is shown as text and never run.
- **Gate (AD-29, AD-8), before any vendor call and before any value is judged.** Read: `%Ens_Portal:USE`, `%Ens_ProductionConfig:READ`, then `Admit`. Write, all three writes including remove: `%Ens_ProductionConfig:WRITE` and globals-database WRITE, plus any pair Task 0 (b) measures. Never cached.
- **Write refusals by name, after the gate and before any vendor call:** a source-controlled namespace (409 `SOURCECONTROL`, every write); a name empty, over 50 characters or holding a control character (422 `NAME`); an add whose name an existing one equals ignoring letter case (409 `TAKEN`); an edit or remove whose name is absent (404); a spec `Ens.ScheduleHandler.ValidateScheduleSpec` refuses, the empty spec included (422 `SPEC`); a description over 256 characters (422 `DESCRIPTION`). `ParseScheduleSpec` is never called: it writes the event log on a bad spec and answers OK.
- **No caller-supplied text in a log.** A vendor refusal (the validator's segment errors, a `%Save` status) reaches `InteropPort.LogFault` as a status carrying the vendor's error code and a fixed message only, never the vendor's text, which echoes the spec or name.
- **Writes (AD-3, AD-6, AD-34, AD-51 to AD-55, AD-58, AD-59, AD-14, AD-10, AD-22).** Three tools `interop.schedules.add|update|remove` over one fresh read. The add is a create (AD-54). Edit changes `Description`, `ScheduleSpec` and `Deployable` only, sending the fields the person changed (`SCREENOPTIONAL`). The name never changes: a rename is a remove and an add. Read-back through the update's read. A script form per tool. Keys `add`, `update` `true`; `remove` `false` (destructive). A screen action mints nothing and is not gated by read-only or the kill switch.
- **Namespace at confirm (AD-52).** Every tool's stored proposal carries `Namespace` (the add and edit in their arguments through the family's mint, the remove in its `FINGERPRINTSUBJECT`), and every judgment at confirm (the fresh read, the taken test, the spec and description rules) runs in the proposal's namespace, whichever namespace the confirm is sent from.
- **Audit (AD-15).** The agent's marker on every agent write; OcuPilot's own `ConfigChange` from either caller through `AuditRuntime`, naming the namespace, the schedule and the changed field names, never a value (Task 0 (a) confirms the vendor records nothing).

**Never:**

- `%Api.InteropEditors`; `EnsPortal.*` methods; `Ens.ScheduleHandler.ParseScheduleSpec`; `Ens.Util.Schedule.Evaluate`; starting, stopping or updating a production.
- A spec, description or name in a log line.
- Import or export of schedule specs; a structured spec editor or preview; an in-use check on remove (the vendor and the classic page have none).
- `src/OcuPilot/Api/Error.cls` (frozen); `ui/angular.json`; `ui/vitest-base.config.mjs`; `scripts/ci-throwaway.sh` beyond add-only roster lines and never its bring-up retry block; any logic edit in `Prohibited.cls` beyond the appended terms in Code Map; a spine or README edit.

## I/O & Edge-Case Matrix

Route namespace USER unless named. Probe schedule specs are named `OcuProbe2415S*`; the probe production is `Test/ProductionProbe.cls`'s.

| Scenario | Input / State | Expected | Error |
|---|---|---|---|
| Add, both callers | `OcuProbe2415SA`, spec `START:*-*-*T08:00:00,STOP:*-*-*T17:00:00`, a description, Deployable true | Row reads back exactly as sent; read-back `matches` | - |
| Edit | Spec only, from the screen | Spec changed; description and Deployable kept | - |
| Remove | A probe schedule | Gone; card destructive | - |
| Taken / absent | Add `ocuprobe2415sa` beside `OcuProbe2415SA`; edit or remove a missing name | Refused | 409 `INTEROP.SCHEDULE.TAKEN`; 404 |
| Invalid | Spec `START:*-*-*T25:00:00`, `FOO:*-*-*T08:00:00` or empty; name of 51 characters or with a control character; description of 257 | Refused; no log line carries the spec | 422 `INTEROP.SCHEDULE.SPEC`; `NAME`; `DESCRIPTION` |
| Gate | No `%Ens_ProductionConfig:WRITE` (remove included); no read pair | Refused before any vendor call or judgment | 403 naming the pair |
| Source control | A namespace the port reads as source-controlled | Every write refused | 409 `INTEROP.SCHEDULE.SOURCECONTROL` |
| Confirm elsewhere | Add, edit and remove minted in USER, confirmed with `?ns=HSCUSTOM`, where HSCUSTOM holds a same-named schedule | Each acts in USER only; the add is not refused `TAKEN`; HSCUSTOM's row unchanged | - |
| DW-2838 | New credential refused (409 `TAKEN`), name corrected, Save again | The second Save sends the typed password; the row reads `Stored` | - |

</intent-contract>

## Code Map

Paths under `/Users/jbrandt/git/OcuPilot/.worktrees/epic-24` (HEAD `e6db2ed9f`). **Contended with Epic 21 (add-only; re-check each with `git log --no-merges origin/OCU-1-epic21 ^origin/feature/OCU-1_ocupilot-mvp -- <path>` before editing):** `Kernel/Governance/Baseline.cls`, `Screen/Registry.cls`, `ui/src/app/core/{strings,screens.generated}.ts`, `scripts/ci-throwaway.sh`, `Test/{DraftRegistry,ToolWrite,SurfaceCoverage}.cls`, EXPERIENCE.md; `Prohibited.cls` appended terms only, always. Clean at plan: `InteropPort`, `InteropError`, `EntityType`, `Router`, `Titles`, the shell files, `ConfirmNamespaceRoster`, `InteropLookupFixture`.

- **DW-2838:** `ui/src/app/areas/interoperability/interop-credential-dialog.ts` `onConfirm` :307-310 clears the password whether or not `store.add` was accepted; the doc comment :30-32 and `clearPassword` :316 say so. Precedent: `areas/security/ldap-editor.store.ts` :751-753/:792-800, `ssl-form.store.ts` :542-544/:574-580. Spec: `interop-credential-dialog.spec.ts` (:117 posts as typed, :166 draws a refusal); no test chains a refusal and a resubmit.
- **`Port/InteropPort.cls`** (10,800 lines; sibling: credentials, extend the pattern): `ENDPOINTS` :128, `ENDPOINTCREDENTIALS` :196, `CREDENTIALPAIRS`/`CREDENTIALWRITEPAIR` :295/:298, types :533-545, family parameters :791-810, `IsCredentialWrite` :1117, `IsAnyWrite` :1130, `Pairs` :1160 (:1208), `Serves` :1237, `Invoke` :1394, `Admit` :1454 (generic), `SourceControlled` :1785 (refusal precedent `DefaultSettingWriteRefusal` :8184), `AuditRuntime` :6347, `SnippetForm` :6367, `Snippet` :6399; the credential family :8512-8960 (`CredentialNameOK` :8516, `CredentialMoves` :8639, `CredentialViolations` :8692, `CredentialWriteToken` :8717, `ReadCredential` :8726, `InvokeCredential` :8745, `PerformCredential` :8796 with its `AuditRuntime` :8888, `CredentialSnippet` :8913).
- **Vendor (read-only):** `irislib/Ens/Util/Schedule.cls` (id `Name` :30, compiled MAXLEN 50; `Description` 256 :22; `ScheduleSpec` unlimited :24; `Deployable` :33; no `%OnValidateObject`; `%OnAfterSave` :75-109 JOBs `Ens.ScheduleService.CallScheduleService()` only for an edit that changed the spec while a production runs an item whose schedule is `@`name, compared ignoring case; delete notifies nothing; no audit). `irislib/Ens/ScheduleHandler.cls` `ValidateScheduleSpec` :186 (`[Internal]`, pure, one error per segment, what the classic page calls) and `ParseScheduleSpec` :147 (logs a bad spec and answers OK). `irislib/EnsPortal/ScheduleEditor.cls` (`RESOURCE` READ :11, `EDITRESOURCE` WRITE :14 gating only `SaveData` :1329; `DeleteID` :781 needs READ; source control per document `Ens.Util.Schedule-<Name>.SDD` :1419-1456).
- **`Api/InteropError.cls`:** codes `SCHEDULETAKEN`, `NAME`, `SPEC`, `DESCRIPTION`, `SOURCECONTROL`, consequences `SCHEDULEREMOVE`, `SCHEDULECHANGE`, after the credential block :474-496; `ScheduleCodes`/`SchedulePreconditionCodes` beside :765/:772, joined into `Codes` :669 and `ConsequenceCodes` :675; `ReasonFor` beside :947.
- **Tools (new, `Screen/Tool/`):** `InteropScheduleAction` (abstract, as `InteropCredentialAction`; `WRITERESOURCE` `%Ens_ProductionConfig`; `MintClass` answers `InteropCredentialMint`, whose doc comment's first sentence is widened to name the schedule tools), `InteropScheduleAdd` (`CREATES`, `READBACKTOOL` the update), `InteropScheduleUpdate` (`SCREENOPTIONAL` `edit=Description:ScheduleSpec:Deployable`, `CONSEQUENCECODE` `CHANGE`), `InteropScheduleRemove` (`DESTRUCTIVE`, `FINGERPRINTSUBJECT` `Name,Description,ScheduleSpec,Deployable,Namespace`, `REMOVALROWS`).
- **Save route (new):** `Area/Interop/ScheduleSave.cls` extending `ItemSave` as `CredentialSave.cls`; `POST /interop/schedules` in `Api/Router.cls` beside :300, handler beside :2125.
- **Descriptor (new):** `Screen/Descriptor/InteropScheduleList.cls` as `InteropCredentialList.cls` (route `interoperability/schedules`, side bar 15, `list`, entity type `interop-schedule`, primary `add`, rows `edit`, `remove`, no secret arguments, `classicPage` `EnsPortal.ScheduleEditor`, `toolIdentifier` `interop.schedules`).
- **Kernel:** `Kernel/EntityType.cls` :118/:163 add `interop-schedule`; `Kernel/Governance/Baseline.cls` three keys after :331; `Prohibited.cls` (append-only): `TYPEINTEROPSCHEDULE` beside :871, `COVEREDTYPES` :320, the condition term :1750, arms in `PermittedChangeFields` beside :1476 (`Description,ScheduleSpec,Deployable`), `PermittedCreateFields` beside :1665 (`Name,Description,ScheduleSpec,Deployable`), the created arm beside :1974, `ReviewedFewOnly` beside :2274.
- **Client (`ui/src/app/`):** `areas/interoperability/interop-schedule-{list.page,dialog,store}.ts` and specs, modeled on the default-setting files (no secret; Deployable checkbox); `shell/screen-outlet.ts` :282, `core/screen-actions.ts` :316, `shell/screen-action-handler.ts` :151/:630/:832/:951, `core/proposal-view.ts` :497/:729, `core/strings.ts` after :9435; regenerate `screens.generated.ts` and `Screen/Titles.cls`.
- **Tests (new; principal legs armed by `OCUPILOT_ALLOW_PRINCIPALS`, a `# classes:` line after `scripts/ci-throwaway.sh` :575):** `Test/InteropScheduleControl.cls` (both callers, round trip, read-back, audit, draft), `Test/InteropScheduleRefusals.cls` (matrix and gate as principals, no spec in a log), `Test/InteropScheduleElsewhere.cls` (the three cross-namespace confirms, shapes as `InteropCredentialControl.TestAnAddConfirmedFromAnotherNamespaceIsJudgedWhereItRead` and `InteropConfirmNamespace`). Fixture: new `Test/InteropScheduleFixture.cls` (`PutSchedule`, `ScheduleText`, `ScheduleCount`, `DropSchedules` by prefix, each with `pNamespace`, as `InteropLookupFixture.PutCredential` :445/`DropCredentials` :533), and one `DropSchedules` call in `InteropLookupFixture.Clear` :157. Browser: `ui/browser/interop-schedules.browser-spec.mjs`, imports as `interop-credentials.browser-spec.mjs` (`interopListHelpers` from `./interop-list-spec.mjs`).
- **Rosters (Rule 30; what Batch 2 touched, re-grep `interop-credential`, `InteropCredentialList`, `interop.credentials` across `src/OcuPilot/Test`, `ui/tools`, `ui/browser`, `ui/src`):** `ToolWrite` :1326 other-port count; `ToolEmit` :361 `%Extends` clause; `ToolDispatch` :193 and `Governance`'s disabled-key constant; `SaveHoldCoverage` :130; `GovernanceBaseline.DISABLED`; `ToolRoundTrip.REFUSEEMPTY`; `ReadTool`, `Navigation`, `Descriptor` (count 114, ReadShapes) and `Prohibited` literals; `InteropFloor`; `StageTwoTools`; `SurfaceCoverage`; `EndpointCoverage`; `ConfirmNamespaceRoster` (`Walk` :319 checks the new tools by itself; `CHECKEDFLOOR` :34 rises by three); `DraftRegistry` (derived; no row unless the sweep reddens).
- **EXPERIENCE.md:** one Fixed strings row after :625 (the table's last row), once the strings are ruled.

## Tasks & Acceptance

**Execution:**

- [ ] **Task 1, its own commit (DW-2838):** `interop-credential-dialog.ts` clears the password only when `store.add` answers accepted, with its doc comments made true; `interop-credential-dialog.spec.ts` gains "a refused New credential keeps the typed password, and the corrected Save sends it".
- [ ] **Task 0** (`ocupilot-b-ci`, USER and HSCUSTOM; every probe row, item, production, role and user removed after; record under Design Notes › Measured): (a) with auditing on, the vendor records no audit row for an add, an edit and a remove; (b) a principal holding `%Ens_Portal:USE`, `%Ens_ProductionConfig:READ` and the database's READ lists and opens rows; name the pair `%Save` and `%DeleteId` need and the database `^Ens.Util.ScheduleD` maps to; (c) whether two names differing only in case both save, and whether `%OpenId` resolves another case; (d) a 51-character name and a 257-character description fail `%Save`, a control character in a name saves; (e) with the probe production running an item whose schedule is `@OcuProbe2415SR`, a spec edit through the port as the (b) write principal is followed by an `Ens.ScheduleHandler` log row (as `InteropJobEnd.cls:75` reads) and an add is not; (f) after that schedule's remove, the item is no longer started or stopped by it; (g) `ValidateScheduleSpec` refuses each matrix spec and writes no log row or global. HALT if a read writes, if (a) finds a vendor row, or if (e) or (f) measures otherwise.
- [ ] `InteropPort.cls`, `InteropError.cls`: endpoint, gate, read, three writes, snippets, codes.
- [ ] The three tools, `ScheduleSave.cls`, the route, descriptor, entity type, baseline keys, `Prohibited.cls` terms, `InteropCredentialMint` doc sentence.
- [ ] Client page, dialog, store, maps, strings, regenerated mirror and titles, EXPERIENCE.md row.
- [ ] Tests: the matrix in the three new classes and the fixture, the browser spec, component specs, every roster.
- [ ] **Task 2, signature pin (orchestrator relay, same rules as AD-61's `findmappings^%R` pin):** a test reads `Ens.ScheduleHandler.ValidateScheduleSpec`'s compiled formal spec and return type from the instance and asserts they match what the port calls; a vendor change turns it red. It carries a `mutation:` line (for example, the port's call with one argument more or less, or the asserted return type changed -> that test red). Model it on the existing AD-61 pin (grep `findmappings` under `src/OcuPilot/Test`).
- [ ] **Task 3, README (the story's LAST task, after everything else is green):** read the Interoperability paragraph (README.md around :212) and the switched-off list first, keep their own sentence form (semicolon-separated items stay semicolon-separated), and add only the ruled clauses from Design Notes › README. The edit is add-only: `git diff --word-diff=porcelain <baseline> -- README.md` shows no removed words, except a stated count that the new items change, which shows as a one-word replacement; re-derive any count the README states over those lists and name it in the Auto Run Result, with the removed lines of that word-diff.

**Acceptance Criteria:**

- **AC1 (round trip, both callers).** Given the probe names, when a person adds, edits and removes a schedule spec from the screen, and the agent's confirmed proposals do the same to another, then each reads back from `Ens.Util.Schedule` exactly as sent, the removed one is gone, and the read-back says `matches`.
- **AC2 (refusals and gate).** Given each refusal row of the matrix, when either caller writes, then the named code answers before any vendor call, the class is unchanged, and on the port leg no `LogFault` line (captured by a port subclass that overrides it, as `Test/AuditStartedPort.cls:31`) carries the spec or the name.
- **AC3 (the proposal's namespace; Integration, Rule 1).** Given a same-named schedule in USER and HSCUSTOM, when the agent's add, edit and remove are minted in USER and confirmed from HSCUSTOM, then each acts in USER, the add is judged against USER's names, and HSCUSTOM's row is unchanged.
- **AC4 (DW-2838).** Given a New credential refused for a held name, when the person corrects the name and saves again, then the second request carries the typed password, and only an accepted Save clears the field.
- **AC5 (browser).** Given a fresh instance, when a person adds, edits and removes a probe schedule spec on the screen, then the list shows each change.
- **AC6 (fresh, either order).** Given any new or changed test, run first on a fresh instance in either order, when it ends, then no probe schedule spec, item or production remains in either namespace.

## Spec Change Log

- 2026-11-22, spec gate (runner, veto item U-140): Design Notes 1 to 6 kept as recommended. The README line is in scope as this batch's last task: the Interoperability paragraph and switched-off list gain the proposed clauses, add-only, and any count the README states over those lists is re-derived. The story-end spine lines stay proposed for the orchestrator.

## Review Triage Log

## Design Notes

**Veto items (recommended option first).**

1. **Remove needs `%Ens_ProductionConfig:WRITE`** (stricter than the classic page, whose `DeleteID` needs READ only, `ScheduleEditor.cls:781`/:1329).
2. **A source-controlled namespace refuses every write** (stricter than the classic page, which edits each schedule as the document `Ens.Util.Schedule-<Name>.SDD` and goes read-only only where source control says so), as the family does (`SourceControlled`, namespace-wide). Alternative: drive source control's hooks on that document, which no OcuPilot port does.
3. **An add whose name equals another ignoring case is refused** (stricter than the vendor's exact id), because the vendor resolves `@`name and decides whom to notify ignoring case (`Schedule.cls:84`; `ScheduleHandler.cls:153` looks the name up by SQL, which folds case (inference)).
4. **The empty spec is refused**, as the classic validator refuses it; `Evaluate` reads an empty spec as always on.
5. **`ValidateScheduleSpec` is `[Internal]`.** It is the classic page's own check and the only pure one; a named limit, as AD-62 item 11 names `GetMessageList`.
6. **Proposed strings** (reused: "Name", "Description", "Deployable", "Schedule" (`taskDetailsSchedule`), "Edit <name>" and "Remove <name>" (the credential keys), each read true here):
   - Label: "Schedule specs" · action and dialog title "New schedule spec".
   - Help: "A schedule spec starts and stops the production items whose schedule names it, as @ and its name. Each part is START or STOP, a colon and a date and time, for example START:\*-\*-\*T08:00:00,STOP:\*-\*-\*T17:00:00, where \* matches any." · "Deployable schedule specs are included when schedule specs are exported to a deployment package."
   - Consequences: `CHANGE` (edit) "A running production that uses this schedule spec follows a changed spec at once." · `REMOVE` "Items that name this schedule spec are no longer started and stopped by it, and it cannot be restored from OcuPilot."
   - Refusals: `TAKEN` "This namespace already has a schedule spec with that name, in some letter case." · `NAME` "A schedule spec name is 1 to 50 characters and holds no control characters." · `SPEC` "This schedule is not valid. Each part is START or STOP, a colon and a date and time." · `DESCRIPTION` "A description is at most 256 characters." · `SOURCECONTROL` "This namespace uses source control, so change schedule specs in the classic Schedule Specs page."
   - Empty state: "This namespace has no schedule specs." (agent phrase "add a schedule spec").
   - Prompts: "Explain when this schedule spec starts and stops items." · "Which schedule specs are deployable?" · "Add a schedule spec that runs on weekdays from 8 to 5."

**Proposed spine lines for story end (Batches 1, 2 and 3; the orchestrator writes them, add-only; never written here).**

Each line takes the spine's `[AMENDED <its date>, Story 24.15, Rule 20]` tag when written.

- AD-62, item 18: "**Default settings, credentials and schedule specs.** `InteropPort` gains `DefaultSettings` and `DefaultSettingsDiff` over `Ens.Config.DefaultSettings`, behind `%Ens_SystemDefaultConfig` and the classic page's `Enabled` and restricted-UI rules, evaluated at the call, a secret-named setting never read or written; `Credentials` over `Ens.Config.Credentials`, behind `%Ens_Credentials`, the password never read, only whether one is stored; and `Schedules` over `Ens.Util.Schedule`, behind `%Ens_ProductionConfig` (WRITE for every write, the remove included), the spec judged by the vendor's `ValidateScheduleSpec` (a named limit: it is `[Internal]`) and never by `ParseScheduleSpec`, which logs. A namespace under source control refuses every default-setting and schedule write. Every write's stored proposal carries its namespace, and every judgment at confirm runs there."
- AD-35: "**A secret-named system default setting:** the vendor writes `SettingValue` in plain text into its `%Ensemble/%Production/ModifyDefaultSetting` rows (measured on `ocupilot-b-ci`, 2026-11-21), so the audit read masks that event's value lines when its setting name matches the credential pattern, on both paths (`AuditPort.VENDORDEFAULTSETTINGSOURCE`)."
- AD-10: "**The provider's credential** (Story 24.15): the agent's remove or password change of an `Ens.Config.Credentials` row that an enabled `creds` agent definition names, in the process's own namespace, is refused `PROHIBITED.PROVIDERCREDENTIAL` when proposed; the screen is not refused; a failed read refuses."
- AD-15, named case: "**Credential and schedule spec writes** (Story 24.15), which the vendor does not audit, record OcuPilot's own `ConfigChange` from either caller, naming the fields changed and never a value or password; default-setting writes keep the vendor's own `ModifyDefaultSetting` row."
- AD-22: "**Story 24.15's keys:** `interop.defaultsettings.remove`, `interop.credentials.remove` and `interop.schedules.remove` ship `false`; the other seven ship `true`."

**README (story end).** A line belongs: the Interoperability paragraph gains "keep system default settings and compare them between two namespaces; keep credentials, whose passwords are never shown; and add, edit and remove schedule specs", and the switched-off list gains "removing a default setting, a credential or a schedule spec". README is outward-facing, so it is the owner's call and not written here.

**Decided in-stage (plan).**

1. The tree carried the lead's ruling bookkeeping at start (cycle log and ledger lines at 10:32:37Z, written after this stage's spawn); this stage proceeded and left both files untouched.
2. The schedule tools reuse `InteropCredentialMint` unchanged: it stamps `Namespace` for any `CREATES` or `SENDSBODY` tool and names nothing credential-specific (Rule 31); its doc sentence is widened.
3. The spec is stored exactly as sent; the validator's normalized form is not written back (`ScheduleHandler.cls:209` normalizes per segment only).
4. The client siblings are the default-setting files, which share the Deployable checkbox and carry no secret.
5. The schedule fixture is its own class: `InteropLookupFixture` is 597 lines.
6. Only the edit carries a consequence: the vendor notifies a running production only on an edit that changes the spec (`Schedule.cls:78`).
7. The vendor's notification JOB runs in the confirm request; OcuPilot adds no spawn site, and no transaction wraps the write (no `TSTART` in the port or the confirm path).
8. No harvest (AD-23 not engaged); side bar 15.

**Measured (Task 0, `ocupilot-b-ci`, USER and HSCUSTOM, 2026-11-22; every probe row, item, production, role and user removed, final counts 0 in both namespaces).**

- (a) Auditing on; an add, an edit and a remove of `Ens.Util.Schedule` wrote no audit row (a positive-control event appeared as exactly one row; the vendor sources name no audit).
- (b) `^Ens.Util.ScheduleD` maps to the namespace's own database (`%DB_USER` in USER, `%DB_HSCUSTOM` in HSCUSTOM). A principal with `%Ens_Portal:USE`, `%Ens_ProductionConfig:READ` and the database's READ listed through `%ExecDirectNoPriv` and opened rows; its `%Save` and `%DeleteId` failed `<PROTECT>`. The only pair `%Save` and `%DeleteId` need is WRITE on the database holding the globals; no other pair. Reads wrote nothing.
- (c) `OcuProbe2415SC` and `ocuprobe2415sc` both saved as two ids; `%OpenId` and `%DeleteId` of another case fail (#5809, #5810); SQL `Name=` equality is exact-case here. The Design Note 3 inference that the vendor's SQL lookup folds case is refuted; only `%OnAfterSave`'s item match folds case (`$zconvert(...,"U")`).
- (d) A 50-character name and a 256-character description save; 51 and 257 fail (#7201, MAXLEN); an empty name fails (#5659); a name holding `$c(9)` or `$c(1)` saves.
- (e) With a running item whose schedule is `@OcuProbe2415SR`: an add and an edit with the same spec wrote no `Ens.ScheduleHandler` row; an edit that changed the spec wrote `updating...`, `Stopping job`, `stopped in job`, `updated.` rows (and the item restarted on the edit back).
- (f) **Measured otherwise than the spec expects.** A `%DeleteId` of that schedule wrote no log row and the item kept running. At the next production update the vendor logged `ErrInvalidScheduleEventSpec: '@OCUPROBE2415SR' ... is invalid` (`Ens.ScheduleHandler`), then `ConfigItem 'OcuPilotProbeOp' is disabled because its schedule string is invalid.`, and stopped the item's job; the item stayed stopped (Job 0) until the schedule was re-added and a production update ran. So a removed schedule does not leave its items "no longer started and stopped by it": they are stopped and disabled at the next production update.
- (g) `ValidateScheduleSpec` refused `START:*-*-*T25:00:00` (segment 1), `FOO:*-*-*T08:00:00` and the empty spec, each `ErrInvalidScheduleEventSpec`, and accepted `START:*-*-*T08:00:00,STOP:*-*-*T17:00:00`; it wrote no `Ens_Util.Log` row, no audit row and no global; its text echoes the spec. Compiled signature: `ClassMethod`, `Internal`, `FormalSpec` `&pScheduleSpec,&pScheduleErrors,*pLength`, `ReturnType` `%Library.Status`.

**Governing ADs (Rule 6):** AD-3, AD-4, AD-5, AD-6, AD-8, AD-10 (the covered type and its reviewed-few arms; no new prohibited effect), AD-13, AD-14, AD-15, AD-16, AD-21, AD-22, AD-29, AD-34, AD-36, AD-44, AD-51, AD-52, AD-53, AD-54, AD-55, AD-58, AD-59, AD-60, AD-62. Not engaged: AD-23, AD-35 (no secret), AD-63, AD-65, AD-66.

**Integration and linkage (Rules 1, 2, 31).** Integration: AC3 (the kernel's confirm consumes the stored proposal in its own namespace) and AC1's agent leg (the derived read tool). Consumes: `InteropPort` (`Admit`, `AuditRuntime`, `SourceControlled`), `InteropCredentialMint`, `ItemSave`, the kernel's proposal, confirm, governance and audit. Consumed-by: Story 24.20's undo snapshots these writes. Extends: `InteropCredential*` (tools, save, port family), `InteropDefaultSetting*` (client).

**Ledger inbox (Rule 17; `owned_ledger=2`).** DW-2838: Task 1. DW-2827: declined here, closed by Batch 1b's merge (the lead closes it `resolved-by` at adjudication).

## Verification

**Commands** (one `ci-runner` call per message; `ocupilot-b-ci` only):

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.InteropScheduleControl`, then likewise `InteropScheduleRefusals`, `InteropScheduleElsewhere`, `ConfirmNamespaceRoster`, `DraftRegistry`, `Prohibited`, `GovernanceBaseline`, `InteropCredentialControl`, and every class the roster sweep changes. Expected: green; new classes green on their first run.
- `(loop)` `cd ui && npm run test:tools && npm run test:components`. Expected: green.
- `(loop)` `cd ui && npm run build`, then `docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`, then `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci node --test --test-concurrency=1 browser/interop-schedules.browser-spec.mjs browser/interop-credentials.browser-spec.mjs`. Expected: green.
- `(once)` The full ObjectScript sweep, `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --shard k/17` for k = 1 to 17, one call each. Expected: green. The full browser suite is left to CI.
- `uv run scripts/check-objectscript.py` and `bash scripts/lint-docs.sh`. Expected: clean.

**Shared surfaces:** the Interoperability side bar; the entity-type vocabulary; the governance baseline; `COVEREDTYPES`; the read-tool, coverage, endpoint, draft, confirm-namespace and other-port write rosters; `InteropError`'s code lists; `screen-mirror.test.mjs`; the arming roster; USER's and HSCUSTOM's schedule specs; the probe production.

**Hermeticity:** every test added or changed passes on its first run on a fresh instance, in either order; it asserts on its own probe rows by marker and removes them, and any probe production or item it starts.

**Mutations** (each AC's pinning test shown red, reverted byte-identical, recorded as `mutation: <change> -> <test>`; the planned ones):

- mutation: AC1, `PerformSchedule` drops `Deployable` on a set -> `InteropScheduleControl` round-trip test red.
- mutation: AC2, the spec check answers valid -> `InteropScheduleRefusals` spec test red.
- mutation: AC2 log, the spec refusal logs the validator's text -> `InteropScheduleRefusals` no-spec-in-a-log leg red.
- mutation: AC3, `InteropScheduleAction.MintClass` answers the kernel's mint -> `InteropScheduleElsewhere` add leg red; the remove's `FINGERPRINTSUBJECT` without `Namespace` -> its remove leg red.
- mutation: AC4, `onConfirm` clears the password before the add answers -> the new `interop-credential-dialog.spec.ts` test red.
- mutation: AC5, the page's Edit sends no `ScheduleSpec` (bundle rebuilt and redeployed) -> browser spec red.
- mutation: AC6, `InteropScheduleFixture.DropSchedules` removes nothing -> `InteropScheduleControl` red on its `none survives` leg.

## Auto Run Result

Status: blocked
Blocking condition: intent gap: Task 0 (f) measured otherwise than the spec expects. After a schedule's remove, a running production's items that name it are not simply "no longer started and stopped by it": at the next production update the vendor logs an invalid-schedule error, disables each such item ("disabled because its schedule string is invalid") and stops its job, and the item stays stopped until the schedule is re-added and a production update runs (measured on `ocupilot-b-ci`, see Design Notes > Measured (f)). The ruled consequence string for `REMOVE` ("Items that name this schedule spec are no longer started and stopped by it, and it cannot be restored from OcuPilot.") is therefore not true, and the true wording is a new string: intent gap: new string <text of the REMOVE consequence that says the items are stopped and disabled at the next production update>. Also for the owner: the spec's inference that the vendor's name lookup folds case is refuted (Measured (c)); the TAKEN check ignoring case stays the stricter guard and needs no change. No product code was written for the schedules work; Task 1 (DW-2838) is committed as fab07a3951807de4ceadd4bc5d427251f9bb29a9. Tasks 2 (signature pin; formal spec measured in (g)) and 3 (README) are ready to run once (f) is ruled.

**Plan.** Batch 3 of three, the story's last: DW-2838 first, as its own commit (orchestrator ruling relayed by the lead), then Schedule specs (list, add, edit, remove) through `InteropPort`, with every write's proposal keeping its namespace and every confirm judging there. Veto items: Design Notes 1 to 6. The story-end spine block and the README line are under Design Notes. Epic context reused as committed (dispatch instruction); AD-15, AD-22, AD-35, AD-59 and AD-62 read at HEAD. Read-only probes on `ocupilot-b-ci` (52777, identity checked, by a research subagent): `Ens.Util.Schedule` compiled (`Name` 50, `Description` 256, spec unlimited), no rows and no source-control class in USER or HSCUSTOM; `ValidateScheduleSpec` refuses an hour of 25, an unknown action and the empty spec, and accepts a lower-case valid spec; `ParseScheduleSpec` reads the matrix's spec as START until 17:00. Nothing was written to the instance; no scratch class or row was left.
