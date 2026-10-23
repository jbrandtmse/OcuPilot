---
title: 'Story 18.42: Allowed directories: a person''s write'
type: 'feature'
created: '2026-10-12'
status: 'done'
baseline_revision: '42d8d784d567f658a2c3c39980036c7f863aa379'
baseline_commit: '42d8d784d567f658a2c3c39980036c7f863aa379'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-18-context.md'
warnings: ['oversized']
deferred:
  - summary: >-
      No audit event records an FSAccess write (Path PUT and DELETE, Purpose PUT), where the classic AllowDirectory and RemoveDirectory audit RESTRICTDIRECTORIES.
    evidence: |-
      Vendor candidate; owner hold: decision-pending, never reported upstream. Task 0 on ocupilot-ci with auditing on: the four endpoint calls left no audit row; the classic calls, with %System/%Security/RestrictDirectories enabled, wrote two. OcuPilot's own SecurityChange row is the only record of an allow-list write (AD-15).
    location: >-
      irissys/%SYS/FileSystemAccess.cls
    severity: low
---

<intent-contract>

## Intent

**Problem:** The admin API writes the directory allow-list (`FSAccess`), the fence around every server-path field (AD-21's sixth case). OcuPilot offers no way to change it. The owner decided (DW-2334): a person edits the list on its screen after a confirmation, switched off by default, and the agent never does.

**Approach:** One unadvertised write tool carries add, change and remove. Only the screen's own route calls it, and that route first asks the tool's governance key (shipped `false`). A port composes the `FSAccess` calls over a fresh read of `%GUIFileSelector`. The kernel refuses an allow-list write that comes through any tool the agent can reach.

## Boundaries & Constraints

**Always:**

- Write only `PathPort.PURPOSE`, as one change over a fresh read (AD-56 (ii)), holding one target, the list (AD-34).
- No write drops a root the person did not name (see Design Notes).
- Refuse a predictable vendor refusal before any vendor call.
- Leave the read, its tool and the pickers unchanged (AD-36).
- Every write records OcuPilot's own `SecurityChange`, with the roots before and after (AD-15).

**Never:**

- An advertised allow-list tool, or `SCREENACTIONS` on one.
- Another purpose, `FSAccess.Purpose` `DELETE`, or turning the restriction off.
- An edit to `Api/ScreenAction.cls`, `Screen/Tool/Write.cls`, `Screen/Tool/Registry.cls` or `Kernel/Agent/*` (Epic 20).
- A code in `Api/Error.cls`, or a `decision-pending` entry.

## I/O & Edge-Case Matrix

A directory is absolute, at most 1,024 characters, has no control character, and is compared normalized (`%File.NormalizeDirectory`). Every refusal below happens before any vendor call.

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Add, restricted | `Directory` exists, unlisted | `FSAccess.Path` `PUT` | listed: 409 `ALLOWLIST.LISTED`; absent: 422 `ALLOWLIST.NODIRECTORY`; relative or malformed: 400 `ALLOWLIST.PATH` |
| Add, unrestricted | purpose absent or `Restricted` false (the one row is `<ManagerDirectory>`) | `PUT` the manager directory unless stored, `PUT` `Directory`, then `FSAccess.Purpose` `PUT {Restricted: true}` | a failed step stops before the restriction; the roots are unchanged |
| Change | listed `Directory`, `NewDirectory` | `PUT` new, then `DELETE` old | new as for an add; old unlisted: 409 `ALLOWLIST.NOTLISTED` |
| Remove | listed `Directory` | `DELETE`. Removing the last entry empties the list, the screen's published empty state | unlisted: 409 `ALLOWLIST.NOTLISTED` |
| Fallback row | change or remove of the unrestricted manager-directory row | 409 `ALLOWLIST.FALLBACK` | -- |
| Key off | baseline `false`, no setting stored | 403 `ALLOWLIST.OFF` before any read | -- |
| Agent | any advertised tool that writes the allow-list | 403 `PROHIBITED.ALLOWLISTAGENT`, at Confirm and on the route | the unadvertised tool is never listed, dispatched or found (AD-53) |
| Busy | another write holds the list | 409 `WRITE.TARGETBUSY` | -- |

</intent-contract>

## Code Map

Under `src/OcuPilot/`, `5890fe4d`.

- `Port/PathPort.cls` (reuse): `PURPOSE` :37, `PAIRS` :50, `AdminPortClass` :88, `Gate` :121, `Roots` :156 (fallback row :218), `Resolve` :269.
- Siblings (Rule 31): `Port/EncryptionPort.cls` (extends `AdminPort`, `PathPort.PAIRS`); `Port/DatabasePort.cls` `COMPOSEDTYPES` :156, `DELEGATEDTYPES` :165, `Snippet` :928; `Port/ScreenAccessPort.cls` `GET` :302, `Audit` :387; `Screen/Tool/ScreenAccessAction.cls` :17-92; `Area/WebApp/RestServiceSave.cls` :46-79.
- Kernel: `Operation` `HoldTool` :77, `Read` :277, `Gate` :398, `Apply` :457; `Governance/Gate.Decide` :26; `Prohibited` `COVEREDTYPES` :259, `Codes` :992, `ReasonFor` :1000, `RegistryClass` :1347, `Prohibits` :1364, guard :1375, 18.31 clause :1459-1463.
- `AdminPort.MUTATINGTYPES` :492; `Test/PortFixture.cls` :21; `Test/PathPortFixture.cls` `Snapshot` :235, `Restore` :327.

## Tasks & Acceptance

**Task 0** (implement, on `ocupilot-ci` once loaded; vendor: `irissys/%SYS/FileSystemAccess.cls` :27-66; halt on a contradiction): record S0 (`PathPortFixture.Snapshot`); with auditing on, make `<mgr>ocuprobe1842a/` and `…b/`; through `AdminPort.Invoke`, as `_SYSTEM` and as a principal holding only the screen's pairs, send `FSAccess.Path` `PUT` (new, repeated, missing, relative) and `DELETE` (held, unheld), and `FSAccess.Purpose` `GET` and `PUT` (true, false; absent, present), reading each answer, `PathPort.Roots`, audit rows and alert state; remove the probes, restore S0, record findings under "For the lead".

**Execution:**

1. `Api/AllowListError.cls` (new, `RestServiceError`'s shape): the six `ALLOWLIST.*` codes with sentences, `Codes`, `ReasonFor`; an `ALLOWLIST.` arm beside each `RESTSERVICE.` arm in `Error.cls`.
2. `Port/AllowListPort.cls` (new, extends `AdminPort`, as `EncryptionPort`):
   - `PathPort.Gate` first; every `FSAccess` call through `AdminPortClass()`, so a test counts them. Endpoint `AllowList`: `GET` reads `PathPort.Roots` and answers `{Purpose, Restricted, Paths, Roots, Action, Directory, NewDirectory, Result}`, refusing by the matrix; `PUT` re-reads, runs the matrix's sequence and records `SecurityChange` (`Event.Record(…, 1)`) with `Roots` before and after, logging no refusal it predicted.
   - `COMPOSEDTYPES` `AllowList/PUT`, `DELEGATEDTYPES` the three `FSAccess` writes; the four pairs join `AdminPort.MUTATINGTYPES` and `PortFixture`'s copy. `Snippet` renders each branch through `##super` (AD-59).
3. `Screen/Tool/AllowedDirectoryUpdate.cls` (new, `Write`, shaped as `ScreenAccessAction`): `security.alloweddirectories.update` on `AllowedDirectoryList`, endpoint `AllowList`.
   - `ADVERTISED` 0, no `SCREENACTIONS`; `READTYPE` `GET`, `READSVALUES` 1, `READANSWERS` task 2's `GET` keys, `SENDSBODY` 0, `DESTRUCTIVE` 1; `STATEFIELD` `Roots`, `PRECONDITIONFIELD` `Paths`, `FINGERPRINTSUBJECT` `Restricted,Paths`, `READBACKFIELDS` `Roots`; write pair `%Admin_FileSystemAccess:USE`, the screen's (`ToolEmit` :316).
   - Values `Action` (`add`, `change`, `remove`), `Directory`, `NewDirectory`, through `PortQuery`; id `PathPort.#PURPOSE`; `StateDiff` `Roots` → `Result`. Its code names no `Api` class but `Error`.
4. `Kernel/Governance/Baseline.cls`: `"security.alloweddirectories.update": false,` in name order.
5. `Kernel/Proposal/Prohibited.cls` (add-only):
   - `TYPEALLOWEDDIRECTORY` in `COVEREDTYPES` and the :1375 guard; `ALLOWLISTAGENT`, its reason naming no caller, appended to `Codes` and in `ReasonFor`.
   - After the 18.31 clause: `If tType = ..#TYPEALLOWEDDIRECTORY { If ..AgentReachable(pToolName) Do ..Refuse(..#ALLOWLISTAGENT, .pProhibits, .pCode)  Quit }`.
   - At the end, `AgentReachable`: `RegistryClass()`'s `Resolve`, unadvertised excluded, finds the tool; a failed resolve answers 1.
6. `Area/Security/AllowedDirectorySave.cls` (new; its own route, as 18.34's, since `ScreenAction.Run` asks no governance), `POST /allowed-directories`, in order: the screen's pairs (`Operation.Gate`, no prohibited class), 403 naming the pair; a JSON object of only `Action`, `Directory`, `NewDirectory`, else 400 as `RestServiceSave`; `Gate.Decide`, 403 `ALLOWLIST.OFF`; `HoldTool`; `Operation.Read`, its refusal passed through; `Operation.Gate` with `Prohibited`; `Apply`, `ReadBack.Of`; 200 `{action, target, readBack}`. `Release` on every exit; route and wrapper at `Router.cls`'s tail.
7. Strings: the seven refusal sentences into EXPERIENCE.md :364 in place and `strings.ts`; `ui/tools/self-protection.test.mjs` pins them (`KERNEL_REFUSALS` gains `ALLOWLISTAGENT`; a new test holds `AllowListError`'s six). Literals: 3,306 + 7 = 3,313 of 3,400.

**Tests** (each under 500 lines, restoring the purpose, probe directories and key):

8. `Test/AllowListPort.cls` (armed as `Test/PathPort`): every matrix row through the port; a refused change makes no `FSAccess` call; the `SecurityChange` row; `PathPort.Roots` answers at once. mutation: the unrestricted add without its manager-directory `PUT` → the keep-root test red.
9. `Test/AllowedDirectorySave.cls` (HTTP, armed): key off, 403 `ALLOWLIST.OFF`, nothing changed; key on, add then remove a probe, read back; without `%Admin_FileSystemAccess:USE`, 403 naming it; `POST /screens/security.alloweddirectories/action` `add`, 404 (no `SCREENACTIONS`); from unrestricted, the add leaves the screen's read listing the manager directory and the probe (C2), and `PathPort.Resolve` under the probe answers 200, then `PATH.ROOT` after the remove (Integration). mutation: no `Gate.Decide` → the key-off leg red; the add without its `FSAccess.Purpose` `PUT` → the Integration leg red.
10. `Test/AllowListAgent.cls` (not armed): a `Prohibited` subclass whose `RegistryClass` lists an advertised probe tool refuses `PROHIBITED.ALLOWLISTAGENT`, as does a failing registry; the real tool passes and is in no provider list, `ResolveWire`, context `tools` or `shell.tools.find` result (as `WalletKeyRead` :296-325). mutation: `AgentReachable` answers 0 → the refusal red.
11. Rule 30 sweep; run each class changed:
    - Add-only: `ToolRoundTrip` :92; `GovernanceBaseline` :15; `Governance` (`ALLOWLISTUPDATE` and its `0|baseline` line after :174); `ToolDispatch` after :184; `SurfaceCoverage` (a `<tool>` row on task 9's method); `PortGate` :29 (`AllowListPort=OcuPilot.Port.PathPort.PAIRS`); `EndpointCoverage` after :278; `Test/Prohibited` :456 (`…update": 3`); `ci-throwaway.sh` (`# classes: AllowListPort, AllowedDirectorySave`).
    - Literal changes: `StageTwoTools` :26 (`UNADVERTISED`), :76 (`kind="writes"`); `ReadTool` :93-94 (375 tools, 193 write, 199 class); `Test/Prohibited` :233 (62 types), :766 (35 codes); the 34-code pins in `AuditingUpdate` :505, `AuthOptionsDescriptor` :166, `EncryptionStartupDescriptor` :138, `SqlPrivilegeDescriptor` :374, `SuperserverDescriptor` :173.
    - Unchanged, run: `SaveHoldCoverage`, `DraftRegistry`, `ToolEmit`, `ToolWrite`, `DeveloperFloorRoutes`, `InteropFloorRoutes`, `PathPort`, `PathPortPrivilege`.

**Acceptance Criteria** (epics.md, 18.42):

- **C1.** Given the key enabled, when a person posts an add, change or remove to `POST /allowed-directories`, then `FSAccess` holds it and the port's next read answers it; with the shipped `false`, nothing is written.
- **C2.** Given an unrestricted instance, when a person adds a directory, then the Allowed directories read answers the manager directory and the new one.
- **C2b (orchestrator, 2026-10-12).** Given a list a remove has emptied, when a server-path consumer resolves a path, then it answers what Task 0 measured an emptied `%GUIFileSelector` list means to IRIS (nothing allowed, or the fallback only), stated in Design Notes, and never everything allowed; test 9 pins it with a `mutation:` line.
- **C3.** Given any tool the agent can reach that writes the allow-list, when it reaches Confirm or the route, then it is refused `PROHIBITED.ALLOWLISTAGENT`.
- **Integration.** Given a directory a person added, when `PathPort.Resolve` (every server-path consumer's resolver) is asked for a file under it, then it resolves; after the remove, it answers `PATH.ROOT`.

### Review Findings

Code review 2026-10-12 (full-opus; blind, edge-case, verification-gap, acceptance layers): 30 rows, 23 entries -- 7 patched, 3 deferred, 13 rejected. Rule 31 check: the per-class `Joined`, `ArrayOf` and `Body` helpers follow a 20-file convention, and `HandleSave` composes the shared `Operation` kernel with the spec's stated reason for not extending `ScreenAction`.

- [x] [Review][Patch] (med, fix-risk low, in-story) An unrestricted add makes every path the purpose already stores a root, while `REASONFALLBACK` said the list becomes "that directory and the manager directory" (the vendor's `DisablePurpose` keeps stored paths) -- sentence corrected in its three copies; a test leg pins the read's `Result` and the roots [src/OcuPilot/Api/AllowListError.cls:43]
- [x] [Review][Patch] (low, fix-risk low, in-story) A partial run that stored paths without moving the roots recorded no `SecurityChange` -- the audit condition also reads the stored paths; leg added [src/OcuPilot/Port/AllowListPort.cls:169]
- [x] [Review][Patch] (low, fix-risk low, in-story) `Normalized` admitted `C:\x` and `\\srv\share` on UNIX, where `NormalizeDirectory` maps them under the namespace directory and to `/srv/share/` (measured) -- the absolute pattern is the platform's; legs added [src/OcuPilot/Port/AllowListPort.cls:407]
- [x] [Review][Patch] (low, fix-risk low, in-story) `Snippet` did not mirror the unrestricted add's two calls (AD-59) -- an add ends with a `comment` step, `UNRESTRICTEDNOTE`, as `MftPort`'s `DELETENOTE` does; leg added [src/OcuPilot/Port/AllowListPort.cls:497]
- [x] [Review][Patch] (low, fix-risk low, in-story) The port header said `PUT` "answers the state it left" on every exit -- it states the failed step's fault [src/OcuPilot/Port/AllowListPort.cls:17]
- [x] [Review][Patch] (low, fix-risk low, in-story) `AllowListAgent`'s mutation note claimed the context leg goes red under `ADVERTISED` 1; the descriptor declares no action, so it cannot [src/OcuPilot/Test/AllowListAgent.cls:93]
- [x] [Review][Patch] (low, fix-risk low, in-story) `Governance.Gate` said it is never asked for a person's screen write, and `allowed-directory` named only a root keyed by its path -- both corrected at their origin [src/OcuPilot/Kernel/Governance/Gate.cls:5]
- [x] [Review][Defer] (med) `Prohibited.Codes()`'s count asserted as `35` in five descriptor classes outside `Test/Prohibited`'s roster pin [src/OcuPilot/Test/AuditingUpdate.cls:505] -- deferred: occurrence on DW-2202 (routed, owner 23-5)
- [x] [Review][Defer] (low) A directory between about 470 and 1,024 characters passes `ALLOWLIST.PATH`, but a three-subscript reference of this shape fails `<SUBSCRIPT>` at 480 [src/OcuPilot/Api/AllowListError.cls:46] -- deferred: DW-2374, IRIS defect candidate, decision-pending, owner hold
- [x] [Review][Defer] (low) AD-8's list of today's unadvertised tools omits this story's tool (spine :230; AD-53 :1161 names it) -- deferred: DW-2375, wontfix-accepted; the spine is the lead's and in Epic 20's diff

Rejected:

- false: an unrestricted add's audit row misstates the roots -- `PathPort.Roots` is the manager directory alone while unrestricted, so `[mgr] -> [mgr, dir]` is exact and `[]` means allows nothing.
- false: the read-back always answers `nothingSent` -- AD-58: an action-style write "sends no value and says so", as `ScreenAccessAction`.
- false: adding the manager directory while unrestricted should be `LISTED` -- the matrix's unrestricted add has no `LISTED`; it restricts, as `REASONFALLBACK` says.
- false: an unregistered tool name passes `AgentReachable` -- no caller reaches `Prohibits` with a name the registry does not resolve; a failed resolve answers 1.
- low: `REASONPATH` at exactly 1,024 without a trailing separator -- unlikely; the bound is AD-21's, normalized.
- low: a non-object fresh read answers 404 `ROUTE.NOTFOUND` -- `ScreenAction`:636's shape; the port's `GET` never answers one.
- low: an after-write read that fails leaves the answer's flag stale -- no caller reads the `PUT` answer; it needs a failed read moments after a good one.
- low: more than 1,000 stored paths are judged on a truncated list -- wontfix-theoretical; real when a list reaches 1,000 directories.
- low: a body that fails at read or decode answers 400 -- the `Body` shape of 30 Save routes.
- low: a body string past the longest string answers 500 -- a 3.6 MB directory; nothing is written.
- low: a `PUT` with a body ignores it -- `Apply` sends none for `SENDSBODY` 0.
- low: an `FSAccess` write under another entity type would pass `ALLOWLISTAGENT` -- wontfix-theoretical; no tool but this port's reaches an `FSAccess` write (grep); real when one does.
- low: an `Event.Record` error status is not logged -- as `ScreenAccessPort`:395; emission never fails a write (AD-15).

## Spec Change Log

- 2026-10-12, lead, spec gate: (1) the roots question takes reading A as this plan built it -- no write drops a root the person did not name, the unrestricted fallback row cannot be changed or removed, a remove may empty the list; `epics.md` 18.42's AC and AD-21's DW-2334 sentence are restated to match. (2) Split for size (Rule 5): this story keeps Task 0, tasks 1-6, task 10's refusal sentences, tests 11-13 and the sweep's ObjectScript rosters, with C1 at the route, C2, C3 and Integration; Story 18.46 takes the screen (tasks 7-9, the rest of task 10, tests 14-15, the client greps, C1 on the screen). Re-plan in place to this story's part.
- 2026-10-12, lead, spec gate (after the re-plan): ready; the For-the-lead wording for AD-22, AD-21, AD-10, AD-13, AD-15, AD-53 and AD-51 applied to the spine as proposed (appended to each AD). Rule 11: the `Prohibited.cls` clause and task 11's literal changes sent to the orchestrator for pre-authorization as unions.
- 2026-10-12, orchestrator: reading A accepted as a tier-1 restatement; say what an emptied list means to IRIS (Task 0 measures it after the remove: `%SYS.FileSystemAccess` and `PathPort.Resolve` on a probe path) and pin it (C2b), so "a remove may empty the list" never silently means "everything allowed". Task 11's literals and the `Prohibited.cls` clause are pre-authorized as unions under Rule 22; recount each literal on the merged tree at every forward merge.

## Review Triage Log

### 2026-10-12 -- Review pass

- verdicts: 23 findings -- high 0, medium 4, low 18, false 1, maybe-false 0
- findings:
  - `[medium]` `[patch]` The route's prohibited-set gate (C3 "on the route") is pinned only through `Operation.Gate` called directly -- new `AllowedDirectorySaveFixture` runs `HandleSave` in process over the armed set; `TestARouteWhoseToolTheAgentCanReachIsRefusedByTheKernel`; mutation red (715).
  - `[medium]` `[patch]` "Key off, before any read" is indistinguishable from "after the read" -- the key-off test posts a relative and a listed directory, expecting `ALLOWLIST.OFF`; the key-after-read mutation is red (716).
  - `[medium]` `[patch]` The `removed` and `changed` `SecurityChange` rows and their roots are never asserted -- both asserted in `AllowListPort`; verb mutations red (709, 710).
  - `[low]` `[patch]` `Normalized`'s 1,024 bound has no edge assertion -- a directory of exactly 1,024 characters is admitted; `>=` mutation red (711).
  - `[low]` `[patch]` `AgentReachable`'s raising-registry path is untested (the reviewer proposed defer; a 10-line two-way door) -- `AllowListAgentSet.ArmRaise` and a leg; `Catch` mutation red (714).
  - `[medium]` `[patch]` `AllowListPort` asserted `Roots` equal to `Result`, built from one variable -- now compares the answer's roots to the real roots.
  - `[low]` `[reject]` Two legs of `TestTheScreensActionRouteReachesNoTool` pass with or without `SCREENACTIONS` -- true and stated in the test; its `ScreenActionIds` leg discriminates (698).
  - `[low]` `[patch]` Pinning tests with no recorded mutation (failed step, change order, `Normalized`, the roster rows, the Fixed-strings test, `ADVERTISED`, C2b on the port) -- each mutation demonstrated and written to `## Verification` (711-713, 717-719, 696, 730).
  - `[low]` `[reject]` Tests with no mutation line that pin no AC (script form, code vocabulary, body-shape refusals, the kernel code's sentence) -- Rule 19 scopes to the AC's pinning test; a mutation per helper test is not worth the quota.
  - `[low]` `[patch]` `AllowListAgent`'s gate test needs the screen's pairs and its header did not say so -- stated.
  - `[low]` `[reject]` `TestEveryRefusalIsExactAndSendsNoWrite` assumes `ocuprobe1842missing/` is absent -- a name only this story uses, which no test creates.
  - `[low]` `[patch]` `## Auto Run Result` read `ready-for-dev` -- written at finalize.
  - `[low]` `[patch]` Intent audit: the 400, 422 and fallback refusals are asserted at the port, not on the wire -- wire legs added for `PATH`, `NODIRECTORY` and `FALLBACK`.
  - `[low]` `[reject]` Intent audit: no test drives the Confirm endpoint for the allow-list target -- no shipped tool the agent can reach mints it; the shared gate and the route are pinned.
  - `[low]` `[reject]` Intent audit: "never listed, dispatched or found" is tested at the registry, not a live provider call -- the registry builds what the provider receives.
  - `[low]` `[reject]` Intent audit: the audit row is asserted at the port, not on the route -- the route calls the port; the drop mutation is red (697).
  - `[low]` `[reject]` Intent audit: an effect-based fence (a generic admin tool naming `FSAccess` pairs) is not addressed -- no shipped tool names those pairs but `AllowListPort`; a later generic console owns its own gate (inference).
  - `[low]` `[reject]` Intent audit: `strings.ts` and the parity test are client files -- Task 7 and the Fixed strings rule require them; no dialog was built.
  - `[low]` `[reject]` Intent audit: `StageTwoTools` flips the screen's row to `writes` -- Task 11's literal change.
  - `[low]` `[reject]` Intent audit: the route takes no server-side confirmation -- by design; the dialog is Story 18.46.
  - `[low]` `[reject]` Intent audit: the `deferred` entry's evidence carries the words `decision-pending` -- the stage prompt prescribes that note for the vendor candidate.
  - `[false]` `[reject]` Intent audit: Task 0's date reads 2026-10-13 against a 2026-10-12 `created` -- the throwaway's clock is UTC; both are the same evening.
  - `[low]` `[reject]` Intent audit: the two armed classes refuse to run unarmed -- stated in their headers and listed in `ci-throwaway.sh`'s roster; no defect.

## Design Notes

**Governing ADs:** AD-8, 10, 13, 14, 15, 21, 22, 29, 34, 36, 39, 51, 52, 53, 55, 56, 58 and 59. **Story 18.46** takes the screen, its client half, EXPERIENCE.md :173 and C1 on the screen.

**The roots (reading A).** OcuPilot needs no allow-list root: no install, start, sign-in, serving, turn or smoke path resolves one. Its one root is `PathPort`'s fallback `<ManagerDirectory>` while unrestricted; the route refuses changing or removing it (`ALLOWLIST.FALLBACK`), and an add stores it before restricting. No confirm reaches it: `Confirm` resolves advertised tools only (:254), and those are refused `ALLOWLISTAGENT`.

**For the lead** (Rule 20; placement, then the text to paste, tagged `[AMENDED 2026-10-12, Story 18.42 spec gate, Rule 20]`):

- **AD-22**, after "As shipped": **One person's write asks its key**: `POST /allowed-directories` asks `security.alloweddirectories.update`, shipped `false`, before any read, refusing 403 `ALLOWLIST.OFF`: the owner decided it ships "with the action switched off by default" (DW-2334). No other person's write is asked.
- **AD-21**, after the ninth case: **The tenth is the allow-list itself**: on `POST /allowed-directories` alone a person names one whole absolute directory (at most 1,024 characters, compared normalized, else `ALLOWLIST.PATH`), written to `%GUIFileSelector` alone; an unrestricted add stores `<ManagerDirectory>` before it restricts.
- **AD-10**, a bullet: **The allow-list, through any tool the agent can reach**: an `allowed-directory` write whose tool resolves among the advertised tools, or whose resolve fails, is refused `PROHIBITED.ALLOWLISTAGENT` at Confirm and on the route.
- **AD-13**, a rule: **The allow-list is one target**: `allowed-directory`, instance scope, id `%GUIFileSelector` kept exactly, so AD-34's lock orders its writes.
- **AD-15**, a named case: An allow-list write, which the vendor does not audit (inference until Task 0), records OcuPilot's own `SecurityChange`, roots before and after.
- **AD-53**, its list: …and `security.alloweddirectories.update` (Story 18.42: never the agent's, AD-21; key disabled; one caller, `POST /allowed-directories`, so no `SCREENACTIONS`; its `SecurityChange` row leaves no named gap).
- **AD-51**, a case: `AllowListPort` composes `AllowList` `PUT` from `Action`, `Directory` and `NewDirectory` as `FSAccess.Path` `PUT`/`DELETE` and `FSAccess.Purpose` `PUT` over a fresh `PathPort.Roots` read, read through a port-composed `AllowList` `GET`.
- **Vendor candidate, never reported:** no audit event records an `FSAccess` write, where the classic `AllowDirectory` audits `RESTRICTDIRECTORIES` (measured, below).
- **Task 0 (measured on `ocupilot-ci`, 2026-10-13, as `%All` and as a principal holding `%DB_HSCUSTOM:R`, `%Admin_FileSystemAccess:USE` and `%DB_IRISSYS:READ`; both answered alike):**
  - **An emptied list allows nothing.** Restricted with no path: `FSAccess.Path` `LIST` answers 200 `[]`, `PathPort.Roots` no row, `%CSP.Portal.Utils.IsDirectoryAllowed` 0 for every directory, and `PathPort.Resolve` `PATH.ROOT` even under the manager directory -- not the fallback, not everything.
  - **No `FSAccess` write emits an audit event.** With auditing on, `Path` `PUT` and `DELETE` and `Purpose` `PUT` left no row; the classic `AllowDirectory` and `RemoveDirectory` audit `%System/%Security/RestrictDirectories`, disabled by default, and with it enabled they wrote two rows where the four endpoint calls wrote none. OcuPilot's `SecurityChange` is the only record (AD-15).
  - **Answers:** `Path` `PUT` 201 new, 200 repeated, normalized (trailing separator, `..`), and it creates an absent purpose unrestricted; a missing or relative directory is 500 `INTERNAL`, logged at severity 2 (the alert state read 0 after 5 s); `DELETE` of an unheld path is 404 and logged; reads of an absent purpose are 404; `Purpose` `PUT` 201 on an absent purpose and 200 otherwise. `Path` `PUT` and `DELETE` read no body, so both join `BODYLESSTYPES`; without it `AdminPort` refuses the call 500 before the vendor.

**Rule 11.** Of these files Epic 20's diff and `status -s` (2026-10-12) touch only `strings.ts`, EXPERIENCE.md and `ci-throwaway.sh` (uncommitted). Every edit outside new files is add-only, `Prohibited.cls` included (**its clause keyed on advertised tools is the orchestrator ask**), except task 11's literal changes, unioned at forward merges as 18.45's were.

**Consumes:** 18.1, 20.15, 18.34, 14.2. **Consumed-by:** 18.46 (its dialog) and every `PathPort` consumer. **Ledger:** DW-2334, addressed by the write and route; its screen half is 18.46's.

## Verification

**Commands** (one run per call, `timeout: 600000`):

- `(loop)` `sh /Users/jbrandt/git/OcuPilot/.worktrees/.coordination/carry-2026-10-08/epic-18-d8/load-ocupilot-ci.sh`: `LOAD-OK`, `STARTPATH-OK`.
- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.<C>`, one at a time (totals in `%UnitTest_Result`): tasks 8-10 and every class task 11 names.
- `(loop)` `cd ui && npm run test:tools && npm run build` (bundle under the 3527kB warning); `uv run scripts/check-objectscript.py` and `bash scripts/lint-docs.sh`, 0 problems.

**Shared surfaces:** `%GUIFileSelector`; the governance baseline; `Prohibited`'s types, codes and count pins; the tool, port, mutating-type and route rosters; the Fixed strings; `ci-throwaway.sh`'s arming roster.

every test added or changed passes on a fresh environment, in either order

**Mutations (Rule 19)**, each applied to the throwaway's mounted copy only (client wording: to the file, restored byte-identical), recompiled with its descendants, observed red, reverted, and green again (runs 720-729, 731-733):

- mutation: the unrestricted add without its manager-directory `put` step in `AllowListPort.Plan` -> `AllowListPort.TestAnAddToAnUnrestrictedListKeepsTheManagerDirectoryAndRestrictsLast` (run 683).
- mutation: `Event.Record` dropped from `AllowListPort.Audit` -> `AllowListPort.TestAnAddToARestrictedListSendsOnePutAndRecordsTheRoots` (697); a remove recorded as `added` -> `TestRemovingTheLastEntryLeavesAListThatAllowsNothing` (709); a change recorded as `added` -> `TestAChangeStoresTheNewThenDeletesTheOld` (710).
- mutation: the restricted add's `LISTED` check dropped from `Plan` -> `AllowListPort.TestEveryRefusalIsExactAndSendsNoWrite` (699); `AllowListPort.Invoke` skips `PathPort.Gate` -> `TestTheGateAndAnotherPurposeRefuseBeforeAnyCall` (702); `Execute` does not stop at a failed step -> `TestAFailedStepStopsBeforeTheRestrictionAndLeavesTheRoots` (712); a change deletes the old entry before it stores the new -> `TestAChangeStoresTheNewThenDeletesTheOld` (713); `Normalized` refuses 1,024 characters (`>=`) -> `TestNormalizedAdmitsOnlyAbsoluteBoundedCleanDirectories` (711).
- C1, mutation: `Gate.Decide`'s verdict ignored in `HandleSave` -> `AllowedDirectorySave.TestTheKeyShippedOffRefusesAndChangesNothing` (686); the key asked after the port's read -> the same test, its path and listed legs (716); `Apply` dropped -> `TestAnAddAChangeAndARemoveAreWrittenAndReadBack` (705); `HoldTool` dropped -> `TestAHeldTargetIsAnsweredBusyAndNothingIsWritten` (693); the pairs refusal ignored -> `TestACallerWithoutTheScreensPairIsRefusedByNameBeforeTheKey` (694).
- C2 and Integration, mutation: the unrestricted add's `Purpose` `PUT` step dropped from `Plan` -> `AllowedDirectorySave.TestAnAddFromAnUnrestrictedListReachesTheScreenAndTheResolver` (684).
- C2b, mutation: `Purpose` `PUT {Restricted: false}` sent after a `DELETE` in `Execute` -> `AllowedDirectorySave.TestAnEmptiedListAllowsNothing` (685) and `AllowListPort.TestRemovingTheLastEntryLeavesAListThatAllowsNothing` (730).
- C3, mutation: `Prohibited.AgentReachable` answers 0 -> `AllowListAgent.TestAToolTheAgentCanReachCannotWriteTheAllowList` and `TestTheSharedOperationGateRefusesItWhenTheToolIsReachable` (687); its `Catch` answers 0 -> the first of them (714); the route's second `Operation.Gate` handed no prohibited class -> `AllowedDirectorySave.TestARouteWhoseToolTheAgentCanReachIsRefusedByTheKernel` (715).
- Unadvertised, mutation: `AllowedDirectoryUpdate.ADVERTISED` 1 -> `AllowListAgent.TestTheShippedToolIsInNoListTheAgentSees` and the two above (696); `SCREENACTIONS` `add` -> `AllowedDirectorySave.TestTheScreensActionRouteReachesNoTool`, its tool leg (698; the descriptor declares no row action, so the route's 404 alone cannot tell).
- Rosters, mutation: the `SurfaceCoverage` row removed -> `TestEveryWriteToolHasACoverageRowAndBack` (717); the `EndpointCoverage` probe removed -> `TestEveryRouteHasAProbeAndEveryProbeHasARoute` (718); the `PortGate` row removed -> `TestEveryPortDeclaresANamedGate` (719).
- Fixed strings, mutation: a word added to `REASONLISTED`, or to `ALLOWLISTAGENTREASON`, -> `ui/tools/self-protection.test.mjs`, the story's test and the kernel-refusal test.
- (QA) Matrix rows, each applied to `ocupilot-ci`'s mounted copy only, recompiled with `AllowListPortFixture`, observed red, restored byte-identical and recompiled:
  - mutation: the `FALLBACK` refusal of the unrestricted manager-directory row dropped from `Plan` -> `AllowListPort.TestEveryRefusalIsExactAndSendsNoWrite` (cases 14, 15) and `AllowedDirectorySave.TestAnAddFromAnUnrestrictedListReachesTheScreenAndTheResolver` (runs 736, 737).
  - mutation: the restricted `NOTLISTED` check of a change or remove dropped from `Plan` -> `AllowListPort.TestEveryRefusalIsExactAndSendsNoWrite` (cases 6, 10) and `AllowedDirectorySave.TestAnAddAChangeAndARemoveAreWrittenAndReadBack` (738, 739).
  - mutation: `DirectoryExists` answers 1, the `NODIRECTORY` refusal of an add and of a change's new directory -> `AllowListPort.TestEveryRefusalIsExactAndSendsNoWrite` (cases 2, 8, 18) and `AllowedDirectorySave.TestAnAddAChangeAndARemoveAreWrittenAndReadBack` (740, 741).
  - mutation: `Normalized` no longer requires an absolute directory, the `PATH` refusal -> `AllowListPort.TestEveryRefusalIsExactAndSendsNoWrite` (cases 3, 9), `TestNormalizedAdmitsOnlyAbsoluteBoundedCleanDirectories`, `TestTheScriptFormRendersTheVendorCallsOfTheChange` and `AllowedDirectorySave.TestAnAddAChangeAndARemoveAreWrittenAndReadBack` (742, 743).
  - mutation: a change's `NewDirectory` `LISTED` check dropped from `Plan`, so a change onto a listed directory would delete it -> `AllowListPort.TestEveryRefusalIsExactAndSendsNoWrite` (case 7) (746).
- (QA) Integration, the remove half, mutation: `Execute` sends no `DELETE` -> `AllowedDirectorySave.TestAnAddFromAnUnrestrictedListReachesTheScreenAndTheResolver` (the `PATH.ROOT` leg), `TestAnAddAChangeAndARemoveAreWrittenAndReadBack`, `TestAnEmptiedListAllowsNothing`, and `AllowListPort.TestAChangeStoresTheNewThenDeletesTheOld`, `TestRemovingTheLastEntryLeavesAListThatAllowsNothing` (744, 745).
- (QA) C1, the shipped default, mutation: `Baseline`'s `security.alloweddirectories.update` `true` -> `AllowedDirectorySave.TestTheKeyShippedOffRefusesAndChangesNothing` and `GovernanceBaseline.TestThePurgeIsTheOneDisabledLine` (747, 748).
- (CR) Each applied to `ocupilot-ci`'s mounted copy only, recompiled with `AllowListPortFixture`, observed red, the mount restored byte-identical, reloaded and green (755):
  - mutation: the unrestricted add's result built without the stored paths in `Plan` -> `AllowListPort.TestAnAddToAnUnrestrictedListKeepsTheManagerDirectoryAndRestrictsLast`, its stored-path leg (753).
  - mutation: the stored-paths clause dropped from `Invoke`'s audit condition -> `TestAFailedStepStopsBeforeTheRestrictionAndLeavesTheRoots`, its second leg (753).
  - mutation: `Normalized` back to the platform-blind pattern -> `TestNormalizedAdmitsOnlyAbsoluteBoundedCleanDirectories`, its three UNIX legs (753).
  - mutation: `Snippet`'s add note dropped -> `TestTheScriptFormRendersTheVendorCallsOfTheChange` (754).
- (QA) Rule 3: `AllowedDirectorySave` posts `POST /allowed-directories` over `%Net.HttpRequest` (`Http.MakeRequest`, `AbsoluteRequest`), asserts the status, the body and the real list read back through `PathPort.Roots`, and the refusals leave it unchanged; no test file was added or changed in this pass.


## Auto Run Result

Status: done
Blocking condition: none

**Summary.** The server half of a person's allow-list write: `POST /allowed-directories` (pairs, body shape, key `security.alloweddirectories.update` shipped `false` -> 403 `ALLOWLIST.OFF`, the target hold, the port's fresh read, the prohibited set, the write, the read-back), the unadvertised `AllowedDirectoryUpdate` tool, `AllowListPort` over `FSAccess.Path` and `Purpose` (reading A for the roots; an emptied list allows nothing), the kernel refusal `PROHIBITED.ALLOWLISTAGENT` for any tool the agent can reach, the six `ALLOWLIST.*` codes and seven fixed sentences. This pass (resume from WIP `d9244e95`) re-verified the sweep on `ocupilot-ci`, demonstrated the mutations, ran both review layers and patched their findings.

**Files.** New: `Api/AllowListError.cls`, `Area/Security/AllowedDirectorySave.cls`, `Port/AllowListPort.cls`, `Screen/Tool/AllowedDirectoryUpdate.cls`; tests `AllowListPort`, `AllowListPortFixture`, `AllowedDirectorySave`, `AllowedDirectorySaveFixture`, `AllowListAgent`, `AllowListAgentSet`. Edited: `Api/Error.cls` (two dispatch arms), `Api/Router.cls` (route), `Kernel/Governance/Baseline.cls`, `Kernel/Proposal/Prohibited.cls` (type, code, clause, `AgentReachable`), `Port/AdminPort.cls` (mutating and bodyless types), the shared roster tests and literal pins of task 11, `strings.ts`, `self-protection.test.mjs`, EXPERIENCE.md :364, `ci-throwaway.sh`.

**Review.** 23 findings: 4 medium and 6 low patched (gate at the route, key order, audit rows, tautology, bound, raising registry, wire refusals, mutation lines, header); 1 vendor candidate in `deferred:`; 13 rejected with reasons in the log. Follow-up review recommended `true`: four medium patches were made, and the new route fixture and the wire, audit and key-order legs are verified by their own mutations only.

**Verification.** `ocupilot-ci` loaded (LOAD-OK, STARTPATH-OK); every class of the Rule 30 sweep and the story's three classes green (final runs 720-729, 731-733); `npm run test:tools` 1948/1948; `npm run build` clean; `check-objectscript.py` 2016 files, 0 problems; `lint-docs.sh` 0; 27 mutations demonstrated and reverted byte-identical (`## Verification`). Task 0: an emptied list allows nothing; no `FSAccess` write is audited (vendor candidate, never reported). The throwaway ends at S0.

**Residual risks.** The vendor audit gap is OcuPilot's own `SecurityChange` row only. A generic admin console (Story 16.1) must gate `FSAccess` writes itself (inference).
