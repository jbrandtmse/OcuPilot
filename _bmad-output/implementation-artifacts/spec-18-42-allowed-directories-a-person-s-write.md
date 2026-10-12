---
title: 'Story 18.42: Allowed directories: a person''s write'
type: 'feature'
created: '2026-10-12'
status: 'draft'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-18-context.md'
warnings: ['oversized']
deferred: []
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
| Fallback row | change or remove of the unrestricted manager-directory row | 409 `ALLOWLIST.FALLBACK`; the control is drawn `aria-disabled` | -- |
| Key off | baseline `false`, no setting stored | 403 `ALLOWLIST.OFF` before any read | -- |
| Agent | any advertised tool that writes the allow-list | 403 `PROHIBITED.ALLOWLISTAGENT`, at Confirm and on the route | the unadvertised tool is never listed, dispatched or found (AD-53) |
| Busy | another write holds the list | 409 `WRITE.TARGETBUSY` | -- |

</intent-contract>

## Code Map

Under `src/OcuPilot/` unless `ui/`, at `beb02acb`.

- **`Port/PathPort.cls`** (reuse, never copy): `PURPOSE` :37, `PAIRS` :50, endpoints :56-59, `Gate` :121, `Roots` :156.
- **The vendor, read on `ocupilot` on 2026-10-12:**
  - `FSAccess.Path` `PUT` takes the `purpose` and `rootPath` query parameters and no body. A stored entry answers 200 `{}`. Otherwise it calls `%SYS.FileSystemAccess.Create`, which answers 201, refuses a missing directory, and creates an absent purpose unrestricted.
  - `FSAccess.Path` `DELETE` of an absent entry answers 404.
  - `FSAccess.Purpose` `GET` answers `{Restricted}`, and its `PUT` takes `{Restricted}`.
  - Each checks `%Admin_FileSystemAccess:USE` and then escalates itself (`irissys/%SYS/FileSystemAccess.cls` :27-66).
  - `ocupilot` holds no purpose.
  - No vendor audit event is written (inference): only `%CSP.Portal.Utils.AllowDirectory` audits `RESTRICTDIRECTORIES`.
- **Siblings (Rule 31):**
  - `Port/ScreenAccessPort.cls`: its `GET` answers `Result`, the change's outcome; also its `PUT`, `Audit` :387 and `Snippet` :493.
  - `Screen/Tool/ScreenAccessAction.cls`: the `READSVALUES` tool.
  - `Area/WebApp/RestServiceSave.cls`: a person's route through a tool.
  - `Api/ScreenAction.cls` `Run` :216-420: the gate order (read only).
- **Kernel and registry:**
  - `Kernel/Proposal/Operation.cls`: `Read`, `Gate` :398, `Apply`, `HoldTool`.
  - `Kernel/Governance/Gate.cls`: `Decide`.
  - `Screen/Tool/Registry.cls`: `Resolve` :293.
  - `Kernel/Proposal/Prohibited.cls`: :259, :1375, the 18.31 clauses at :1453-1465, `Codes` :992, `ReasonFor` :1000.
- **Rosters and error arms:** `Test/StageTwoTools.cls` :26 and :76; `Screen/Registry.cls` :2996; `Api/Error.cls` :1240 and :1452 (`RestServiceError` arms).
- **Client (`ui/src/app/`):**
  - `core/screen-actions.ts` :298, and its labels at :157-285.
  - `shell/screen-outlet.ts` :161 and `areas/web-applications/rest-api-list.page.ts` :51-54.
  - `areas/system-explorer/docdb-create-dialog.ts` and `.store.ts` :109-139.
  - `superserver-form.store.ts` :574-585.
  - `shell/typed-name-dialog.ts` and `core/self-protection.ts`.
  - `tools/screen-mirror.mjs` :315 and :3087-3100.
- **Strings:** EXPERIENCE.md :364 and :173. The table holds 3,306 literals; the bound is 3,400.

## Tasks & Acceptance

**Task 0** (on `ocupilot-ci`, after `LOAD-OK` and `STARTPATH-OK`; halt on any contradiction):

1. Record S0 (`PathPortFixture.Snapshot`).
2. With auditing on, create `<mgr>ocuprobe1842a/` and `…b/`.
3. Through `AdminPort.Invoke`, as `_SYSTEM` and as a principal holding only the screen's pairs, call:
   - `FSAccess.Path` `PUT` for a new entry, a repeated entry, a missing directory and a relative name;
   - `DELETE` of a held entry and an unheld one;
   - `FSAccess.Purpose` `GET` and `PUT` (true and false) on an absent purpose and a present one.
4. For each call, read the status and body, `PathPort.Roots`, the audit rows and the alert state.
5. Remove the probes, restore S0, and record the findings under "For the lead".

**Execution:**

1. **`Api/AllowListError.cls`** (new, modeled on `RestServiceError`). Codes `ALLOWLIST.OFF`, `.PATH`, `.NODIRECTORY`, `.LISTED`, `.NOTLISTED` and `.FALLBACK`, each with its sentence. Add an `ALLOWLIST.` arm in `Error.cls` beside :1240 and beside :1452.
2. **`Port/AllowListPort.cls`** (new, shaped on `ScreenAccessPort`):
   - **Gate:** `PathPort.Gate`.
   - **Endpoint:** `AllowList`, keyed by `purpose`.
   - **`GET`:** answers `{Purpose, Restricted, Paths, Roots, Action, Directory, NewDirectory, Result}` from the purpose `GET` and the path `LIST`, and refuses by the matrix's rules.
   - **`PUT`:** re-reads, runs the matrix's sequence, and records `SecurityChange` (`Kernel/Audit/Event.Record`) with `Roots` before and after. It logs no refusal it predicted.
   - **`Snippet`:** one per branch, from `AdminRoutes` (AD-59).
   - **Seam:** `AdminPortClass`.
3. **`Screen/Tool/AllowedDirectoryUpdate.cls`** (new, extends `Write`): `security.alloweddirectories.update`.
   - `ADVERTISED` 0, and no `SCREENACTIONS`.
   - Port `AllowListPort`. `READTYPE` `GET`, `READSVALUES` 1, `SENDSBODY` 0.
   - Values `Action` (`add`, `change` or `remove`), `Directory` and `NewDirectory`, passed through `PortQuery`.
   - `FINGERPRINTSUBJECT` `Restricted,Paths`; `READBACKFIELDS` `Roots`.
   - `StateDiff` answers `Roots` → `Result`.
   - `DESTRUCTIVE` 1. Its id is `PathPort.#PURPOSE`, and its pairs are the screen's.
4. **`Kernel/Governance/Baseline.cls`:** add `"security.alloweddirectories.update": false`.
5. **`Kernel/Proposal/Prohibited.cls`** (add-only):
   - `TYPEALLOWEDDIRECTORY`, and `ALLOWLISTAGENT` with its reason.
   - Entries in `COVEREDTYPES`, the :1375 chain, `Codes` and `ReasonFor`.
   - Before `Target()`: `If tType = ..#TYPEALLOWEDDIRECTORY { If ..AgentReachable(pToolName) Do ..Refuse(..#ALLOWLISTAGENT, .pProhibits, .pCode)  Quit }`.
   - At the end, `AgentReachable`: whether `RegistryClass()`'s `Resolve`, with `pUnadvertised` 0, finds the tool. A failed resolve answers 1.
6. **`Area/Security/AllowedDirectorySave.cls`** (new): `POST /allowed-directories` with `{Action, Directory, NewDirectory}`; any other key answers 400. It runs, in order:
   1. the screen's pairs (`Operation.Gate`, no prohibited class);
   2. `Gate.Decide`, which answers 403 `ALLOWLIST.OFF`;
   3. `HoldTool`;
   4. `Operation.Read`, passing the port's refusal through as is;
   5. `Operation.Gate` with `Prohibited`;
   6. `Apply` and `ReadBack.Of`;
   7. `{action, target, readBack}`.

   It releases the hold on every exit. Append the route at the tail of `Api/Router.cls`.
7. **The descriptor:**
   - `primaryAction` `add`; `rowActions` `change` and `remove`, each with `selfProtection` `allowed-directory-fallback`.
   - `emptyNextKey` `""` and `emptyAgentKey` `allowedDirectoriesAgentHint`, an explanation request.
   - A header that names the write.
   - Add the rule to `SELFPROTECTIONRULES`, then run `node tools/screen-mirror.mjs`.
8. **`core/self-protection.ts` and `screen-mirror.mjs` :315:** `allowed-directory-fallback` refuses a row whose `Restricted` is `false`, with `ALLOWLIST.FALLBACK`'s sentence.
9. **Client (`areas/security/`):**
   - `allowed-directories.page.ts` wraps `<app-list-page/>`, registers the three actions as `rest-api-list.page.ts` does, and is mapped in `DESCRIPTOR_PAGES`.
   - `allowed-directory-dialog.ts` serves Add and Change: a text field, its hint, and the add's consequence when the row is unrestricted.
   - Remove opens `typed-name-dialog`, with the directory as the target.
   - `allowed-directories.store.ts` posts to the route, shows the field or envelope `reason`, and publishes `{kind: 'changed', type: 'allowed-directory', scope: INSTANCE_SCOPE, id: '%GUIFileSelector', action}`.
   - Labels go in `DESCRIPTOR_ACTION_LABELS`.
10. **Strings:** at most 22 new, so the total stays at or under 3,328, below the 3,350 margin. They are three labels, two titles, two fields, a hint, three consequences, seven refusals and the agent hint.
    - EXPERIENCE.md :364 takes them in place.
    - EXPERIENCE.md :173 gains "add or change an allowed directory (Story 18.42)".
    - Add the matching keys to `strings.ts`, then run `npm run test:tools`.

**Tests.** Each class is under 500 lines and armed as `Test/PathPort` is. Each snapshots and restores the purpose, creates and removes its probe directories, and stores and restores the key.

11. **`Test/AllowListPort.cls`:**
    - Every matrix row, through the port.
    - A refused change makes no `FSAccess` write; the seam counts the calls.
    - The `SecurityChange` row is written.
    - `PathPort.Roots` answers the result at once.
    - mutation: the unrestricted add without its manager-directory `PUT`; the keep-root test goes red.
12. **`Test/AllowedDirectorySave.cls`** (HTTP):
    - Key off: 403 `ALLOWLIST.OFF`, and nothing changes.
    - Key on: add, then remove, a probe, each read back.
    - A caller without `%Admin_FileSystemAccess:USE`: 403 naming that pair.
    - `POST /screens/security.alloweddirectories/action` with `add`: 404.
    - Integration: after the add, `PathPort.Resolve` of a file under the probe answers 200; after the remove, `PATH.ROOT`.
    - mutation: no `Gate.Decide`; the key-off leg goes red.
13. **`Test/AllowListAgent.cls`:**
    - A `Prohibited` subclass whose registry lists an advertised probe tool on this descriptor refuses `PROHIBITED.ALLOWLISTAGENT`.
    - The real tool passes.
    - `ResolveWire("security_alloweddirectories_update")` finds nothing.
    - mutation: `AgentReachable` answers 0; the refusal goes red.
14. **Client specs:**
    - the page: actions registered, the fallback row `aria-disabled`;
    - the dialog and store: the `reason`s and the event;
    - `tools/self-protection.test.mjs`.
15. **Browser** (`allowed-directories.browser-spec.mjs`):
    - Arm the key with `PUT /agent/governance`, and restore it afterwards.
    - Add a probe, wait for the answered signal, check its row, then remove it.
    - The fallback row's actions are `aria-disabled`.
16. **Rule 30 sweep:**
    - `StageTwoTools`: :76 becomes `writes`, the tool joins `UNADVERTISED`, and it admits actions that resolve to an unadvertised tool without `SCREENACTIONS`.
    - Grep `src/OcuPilot/Test` and `ui/tools` for `rest-service`, `RestServiceSave`, `allowedDirectories`, `tableReadOnlyEmptyNext` and `AllowedDirectoryList`. Beside each roster found, add the route and the tool. Expected: `EndpointCoverage`, `SurfaceCoverage`, `DeveloperFloorRoutes`, `InteropFloorRoutes`, `DraftRegistry`, `RefusalCopy`, `GovernanceBaseline`, `Descriptor` and `ToolRoundTrip`.
    - Run `PathPort`, `PathPortPrivilege`, `StageTwoTools` and every class changed. Edit only what goes red.

**Acceptance Criteria** (epics.md, 18.42):

- **C1.** Given the screen with the key enabled, when a person adds, changes or removes an entry, then the change is written through `FSAccess` and the list re-reads with it. With the shipped `false`, the Save is refused `ALLOWLIST.OFF` and nothing is written.
- **C2.** Given an unrestricted instance, when a person adds a directory, then the roots are the manager directory and the new one. No write drops a root the person did not name. This is the open question (Design Notes).
- **C3.** Given any tool the agent can reach that writes the allow-list, when its write reaches Confirm or the route, then it is refused `PROHIBITED.ALLOWLISTAGENT`. The update tool is in no provider list, dispatch or search.
- **Integration.** Given a directory a person added, when `PathPort.Resolve` (every server-path consumer's resolver) is asked for a file under it, then it resolves; after the remove, it answers `PATH.ROOT`.

## Spec Change Log

- 2026-10-12, lead, spec gate: (1) the roots question takes reading A as this plan built it -- no write drops a root the person did not name, the unrestricted fallback row cannot be changed or removed, a remove may empty the list; `epics.md` 18.42's AC and AD-21's DW-2334 sentence are restated to match. (2) Split for size (Rule 5): this story keeps Task 0, tasks 1-6, task 10's refusal sentences, tests 11-13 and the sweep's ObjectScript rosters, with C1 at the route, C2, C3 and Integration; Story 18.46 takes the screen (tasks 7-9, the rest of task 10, tests 14-15, the client greps, C1 on the screen). Re-plan in place to this story's part.

## Review Triage Log

## Design Notes

**Governing ADs:** AD-8, 10, 13, 14, 15, 21, 22, 29, 34, 36, 39, 51, 52, 53, 55, 56, 58 and 59.

**Open question: what are "the roots OcuPilot needs to run"?** The source names none:

- The installer, the start hook, sign-in, serving, turns and the smoke resolve nothing through `PathPort`.
- Only the server-path consumers read the roots, at each call.
- An empty list is a published state (EXPERIENCE.md :364).

OcuPilot's only own root is `PathPort`'s fallback, `<ManagerDirectory>`, used while the purpose is unrestricted, and no entry stores it.

**Recommended reading (built above): no write drops a root the person did not name.**

- An add keeps every root, storing the fallback before it restricts.
- The fallback row cannot be changed or removed.
- A remove may empty the list. Its consequence is shown. Nothing stops running, and this screen can re-add a root without needing one.

**Alternatives:** (B) refuse removing the last root; (D) refuse dropping the manager directory. Each adds one rule to task 2 and one string.

**Why a route of its own** (as 18.34 has): AD-22 never asks governance about a person's write. The registry and ports must not ask governance (the dependency rule). `ScreenAction` belongs to Epic 20.

**Why `AgentReachable`:** `Prohibits` sees no caller, and every agent write passes an advertised tool (`ResolveWire`, Confirm's `Resolve`). If a later story advertises this tool, the person is locked out as well, so that change cannot go unnoticed.

**For the lead** (Rule 20 amendments at the gate):

- **AD-22:** the one person's write that asks its key. The owner: "with the action switched off by default."
- **AD-21:** a tenth case: a person names a whole directory, on this route only, as in the matrix.
- **AD-10:** the agent-reachable arm.
- **AD-13:** the target is `allowed-directory`/`%GUIFileSelector`, kept exactly.
- **AD-15 and AD-53:** `SecurityChange` replaces the missing vendor event (inference, Task 0). That is a vendor candidate, never reported.
- **AD-51:** the `AllowListPort` case.
- **AD-53:** the fourth unadvertised tool.

**Rule 11 (all add-only):** task 5, the `Router.cls` route, the `Error.cls` arms, `Baseline`, `SELFPROTECTIONRULES`, `strings.ts`, and EXPERIENCE.md :173 and :364 edited in place. Epic 20's diff (2026-10-12) touches no other file named here.

**Consumes:** 18.1, 20.15, 18.34 and 14.2. **Consumed-by:** every `PathPort` consumer, at its next call. **Ledger:** closes DW-2334. **Live provider checks:** none.

## Verification

**Commands** (one run per call, `timeout: 600000`):

- `(loop)` `sh /Users/jbrandt/git/OcuPilot/.worktrees/.coordination/carry-2026-10-08/epic-18-d8/load-ocupilot-ci.sh` prints `LOAD-OK` and `STARTPATH-OK`.
- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.<C>` for `AllowListPort`, `AllowedDirectorySave`, `AllowListAgent` and each class the sweep changes, one at a time. Read the totals from `%UnitTest_Result`.
- `(loop)` `cd ui && npm run test:tools && npm run test:components`.
- `(loop)` With `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776` and `OCUPILOT_BROWSER_CONTAINER=ocupilot-ci`:
  1. `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`
  2. `node --test --test-concurrency=1 browser/allowed-directories.browser-spec.mjs`
  3. Check the bundle against 3527kB: rebase it per DW-1166 if it crosses; stop above 3800kB.
- `uv run scripts/check-objectscript.py` and `bash scripts/lint-docs.sh`: 0 problems.

**Shared surfaces:**

- the Allowed directories descriptor and its mirror
- the instance's `%GUIFileSelector`
- the governance baseline
- `Prohibited`'s types and codes
- the route and tool rosters
- the self-protection vocabulary
- the Fixed strings

every test added or changed passes on a fresh environment, in either order

**Mutations (Rule 19):** one per AC, recorded as `mutation:` once observed (tasks 11-13). For the browser leg, the mutation is the wrapper's `add` registration.

## Auto Run Result

Status: blocked
Blocking condition: intent gap and size. (1) The AC "the roots OcuPilot needs to run cannot be dropped" names nothing in source. The installer, the start hook, sign-in, serving, turns and the smoke resolve no allow-list root. Only PathPort's consumers read the roots, at each call, and an empty list is a published state (EXPERIENCE.md :364). Readings that lead to different outcomes: (A, recommended, and built in this spec) no write drops a root the person did not name, the unrestricted fallback row cannot be changed or removed, and a remove may empty the list; (B) also refuse removing the last root; (D) refuse dropping the manager directory. The lead or the owner picks one, and epics.md 18.42's AC and AD-21's DW-2334 sentence are restated to match. (2) The planned spec is about 19.5 KB, over the 16 KB limit. Proposed split: 18.42 keeps the server and kernel: Task 0, tasks 1-6, task 10's refusal sentences, tests 11-13 and the sweep's ObjectScript rosters; its ACs are C1 at the route, C2, C3 and Integration. A new story (18.46, one past the highest) takes the screen: tasks 7-9, the rest of task 10, tests 14-15 and the sweep's client greps; its AC is C1 on the screen. Either way the gate amends AD-21, AD-22, AD-10, AD-13, AD-15/AD-53 and AD-51 as Design Notes lists.
