---
title: 'Story 18.1: The directory allow-list'
type: 'feature'
created: '2026-09-27'
status: 'done'
review_loop_iteration: 0
baseline_revision: '8eee0559d50dc31de1bfed6d9dc91576582921db'
baseline_commit: 'e3d44277999c4fec1400e21a8628db4a431ede7c'
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-18-context.md'
warnings: ['oversized']
deferred:
  - summary: >-
      AD-21's sixth case names iris.cpf among the manager directory's own files, but the CPF sits in the manager directory's parent, so PATH.MANAGER does not protect it and an overwriting consumer under an allowed install-directory root could resolve it.
    evidence: |-
      On ocupilot-b-ci, iris.cpf, _LastGood_.cpf and iris.cpf_20260928 are in /durable/iris/, the parent of $System.Util.ManagerDirectory() (/durable/iris/mgr/). DirectlyInManagerDirectory refuses only a file whose parent is the manager directory, as the rework item directs; under a restricted root /durable/iris/ iris.cpf is refused only by PATH.EXISTS, which pOverwrite 1 skips (inference; not executed). No consumer overwrites yet. The runner corrects AD-21's example list at its origin, or the orchestrator widens the rule.
    location: >-
      src/OcuPilot/Port/PathPort.cls:324
    severity: medium
  - summary: >-
      PATH.INSTANCE protects only the files DW-1777 enumerates, so an overwriting consumer under a root that reaches another database directory or the journals can still resolve an existing instance file there.
    evidence: |-
      On ocupilot-b-ci the active CPF puts IRISLIB, ENSLIB and HSLIB at /usr/irissys/mgr/<name>/, not below $System.Util.ManagerDirectory() (/durable/iris/mgr/); InstanceFile answers 0 for /usr/irissys/mgr/irislib/IRIS.DAT (executed read-only by the verification-gap layer). Journal files under <mgr>/journal/ and an IRIS.DAT deeper down or under another root are outside the rule too. The code matches DW-1777 and AD-21 as written; widening them (for example, any configured database's IRIS.DAT) is the orchestrator's call. No consumer overwrites yet.
    location: >-
      src/OcuPilot/Port/PathPort.cls:408
    severity: medium
---

<intent-contract>

## Intent

**Problem:** Every later server-path field would otherwise decide for itself which directories it may touch. That covers the database directory (18.3), the journal directories (18.5), the task export and import file (16.4), the Stage 3 export and import pickers (19.2, 19.8) and backup (21.2). Meanwhile AD-21 lets no OcuPilot endpoint accept a filesystem path. The instance already keeps an allow-list for its own file dialogs: `%SYS.FileSystemAccess`, purpose `%GUIFileSelector`. The admin API reads it at `/fs-access-purpose` and `/fs-access-purpose/paths`.

**Approach:** The story adds four things:

- **One port, `Port/PathPort`.** On every call it computes the allowed roots: the `%GUIFileSelector` roots when that purpose is restricted, otherwise the manager directory alone. It resolves a caller-named root plus a relative name to a contained path, under a new AD-21 case.
- **A read-only Security › Allowed directories screen and its read tool.** Both show those roots through a new `path` read source.
- **A shared `app-server-path-picker`.** It is fed by that screen's read, and every later path field embeds it.
- **A framework-free store** that the picker consumes.

## Boundaries & Constraints

**Always:**

- **Roots.** `PathPort` alone computes them, on every call, with nothing cached:
  - It reads through `AdminPort`: `FSAccess.Purpose` `GET` with `purpose=%GUIFileSelector`, and `FSAccess.Path` `LIST` with the same purpose and `maxRows`. It also calls `$System.Util.ManagerDirectory()`.
  - A 404 on the purpose `GET`, or on the paths `LIST` (the purpose was removed between the two calls), or `Restricted` false, gives one root, the manager directory.
  - `Restricted` true gives exactly that purpose's `RootPath` values, in the vendor's order. There may be none.
- **The port's own gate (AD-29).** Before any `AdminPort` call, `PathPort` checks `%Admin_FileSystemAccess:USE` and then `%DB_IRISSYS:READ`. It refuses 403 `PORT.ACCESSDENIED` with `detail.failedPair`.
- **`Resolve(root, path, kind)`** follows these rules:
  - It re-reads the roots with the read ceiling of 1,000.
  - `root` must equal a returned root character for character. Otherwise it refuses 400 `PATH.ROOT`.
  - `path` is empty or at most 8 `/`-separated segments. Each segment matches `^[A-Za-z0-9][A-Za-z0-9._-]{0,99}$`. A literal `..` is refused anywhere. `kind` `file` needs at least one segment. Otherwise it refuses 400 `PATH.NAME`.
  - It composes with the one-argument `%File.NormalizeDirectory` for a directory, or `NormalizeFilename` for a file, on `root _ path`. The result must begin with the root. The root itself is allowed for a directory.
  - Each refusal is `detail.violations[{field, code, reason}]` on caller-named fields, `root` and `path` by default. The reason and detail never echo a path.
- **Read rows** are `{Directory, Restricted}`. They are bounded by the read's cap, and truncation is reported (AD-36).
- **The screen's pairs** are `%Admin_FileSystemAccess:USE` (declared as its own pair) and `%DB_IRISSYS:READ`. The Security area's set is unchanged (AD-8).
- **The picker** offers only the roots that the screen's read answered:
  - Its one text entry is the relative name.
  - Its composed path is display only.
  - It renders server reasons on the field they name (AD-39).
- **Contended files are edited add-only:**
  - EXPERIENCE.md is edited in place and stays 993 lines.
  - `strings.ts` keys are appended.
  - The shared rosters get added entries only.

**Never:**

- No free-text or absolute path field, and no browsing of subdirectories.
- No write to the allow-list, no write tool, and no governance key.
- No `%Api.Admin.*` name outside `AdminPort`. No direct call to `%SYS.FileSystemAccess` or `%CSP.Portal.Utils`: each escalates internally and would widen the read (AD-8, AD-27).
- No client copy of the segment rule.
- No spine edit. The runner writes AD-21.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
| --- | --- | --- | --- |
| Unrestricted | `%GUIFileSelector` absent (a fresh instance), or present with `Restricted` false and paths | One row, `{Directory: <ManagerDirectory>, Restricted: false}`; any stored paths are ignored | No error expected |
| Restricted | Purpose restricted, with roots `/tmp/` and the install directory | Exactly those rows in the vendor's order, `Restricted: true`; the manager directory only if listed | No error expected |
| Restricted, empty | Purpose restricted, with no roots | Zero rows; the screen shows the empty state; the picker shows the empty line with no select or input | No error expected |
| No privilege | Caller lacks `%Admin_FileSystemAccess:USE` | The screen read and `PathPort` refuse before any `AdminPort` call | 403 `PORT.ACCESSDENIED`, `failedPair` `%Admin_FileSystemAccess:USE`; the picker shows the reason with no select |
| Resolve OK | root `/tmp/` and path `""`, `a/b`, or `exports/t.xml` (kind `file`) | `/tmp/`, `/tmp/a/b/`, and `/tmp/exports/t.xml` | No error expected |
| Foreign root | `/tmp/a/` or `/TMP/` while `/tmp/` is allowed; the manager directory while restricted; `/etc/` | Refused on `root` | 400 `PATH.ROOT`, no path echoed |
| Bad name | `..`, `a/../b`, `a..b`, `/x`, `a//b`, `a/`, `a\b`, `c:x`, 9 segments, a 101-character segment, or empty for a file | Refused on `path` | 400 `PATH.NAME`, nothing echoed |
| Not cached | A root is removed between two `Resolve` calls | The second call is refused | 400 `PATH.ROOT` |
| Integration | The screen read route and `security.alloweddirectories.read` | The same rows as `PathPort.Rows` (AD-36) | Same gate as the screen |

</intent-contract>

## Code Map

**Vendor classes, read on `ocupilot-b-ci`:**

- `%Api.Admin.Endpoints.FSAccess.Purpose`
  - `ResourcesOR` is `%Admin_FileSystemAccess`.
  - `LIST` uses the `ListPurposes` query and returns `[{Purpose, Restricted}]`.
  - `GET` requires the query parameter `purpose`, returns `{Restricted}`, and answers 404 #758 for an absent purpose.
- `%Api.Admin.Endpoints.FSAccess.Path`
  - `LIST` requires `purpose` and uses `ListByPurpose`, which returns `[{Purpose, RootPath}]` ordered by `RootPath` and honours `maxRows`. It answers 404 for an absent purpose.
- Both endpoints are synchronous and neither touches CSP state.
- `%SYS.FileSystemAccess`
  - `Create` normalizes the path and refuses a missing directory.
  - `GetAllowedRootPaths` returns none unless the purpose is restricted.
- `%CSP.Portal.Utils:582-692`
  - `GetAllowedDirectories` reads `%GUIFileSelector`.
  - `IsDirectoryAllowed` does a textual prefix check.

**Port layer:**

- `src/OcuPilot/Port/AdminPort.cls:747`: `Invoke(endpoint, type, .query, body, .result, .status, .fault)`.
  - A 403 answers `PORT.ACCESSDENIED` with `failedPair` (:888).
  - `HoldsResource` is at :1004.
  - `FSAccess.*` is already in `Test/AdminInventory.cls:57-58`.
- `src/OcuPilot/Port/LogSourcePort.cls:787` (`Rows`), `:2643-2691` (`Resolve`, `DirectlyIn`, `FileRefusal`): the model for a port that feeds a read source and refuses with no echo.
- `src/OcuPilot/Area/WebApp/Location.cls:18,53-58,75-82`:
  - the pattern and `..` refusal;
  - the one-argument normalize;
  - the `IsInsideRoot` precedent. It is strict; ours is not, because a directory kind may name the root itself.
- `src/OcuPilot/Kernel/Shell/Effective.cls:38-41,252-261`: the precedent for a `PortClass()` seam and for gate-then-`Invoke`.

**Screen layer:**

- `src/OcuPilot/Screen/Read.cls`:
  - `SOURCE*` parameters at :131-151;
  - dispatch at :251-290, where `logsource` is the model;
  - the `*PortClass()` seams at :143-158.
- `src/OcuPilot/Screen/Registry.cls`:
  - source validation at :1026-1040;
  - per-port rules at :1131-1141;
  - `OwnPrivilegesProblem` at :736;
  - `AreaCoverageProblem` at :794;
  - `PROMPTGROUPKEYS` at :2383.
- `ui/tools/screen-mirror.mjs`:
  - `READ_SOURCE_PORTS` at :920-934;
  - the port sentence at :1117;
  - the per-port rules at :1198-1210;
  - the `%DB_IRISSYS:READ` rule at :1300-1318.
- `src/OcuPilot/Screen/Descriptor/WalletCollectionList.cls`: the model descriptor (read-only, instance scope, no classic page).
- `src/OcuPilot/Screen/Descriptor/LogEventViewer.cls:25-26`: the `ownPrivileges` grammar.
- `src/OcuPilot/Kernel/EntityType.cls:38`: `TYPES`.

**Error vocabulary:**

- `src/OcuPilot/Api/Error.cls:374-380`: the `LOGFILE` code-parameter model. `Test/Envelope.cls:252` sweeps the codes.

**Client:**

- `ui/src/app/core/screen-read.ts:204-236` (`createScreenRead`) and `ui/src/app/core/navigation.ts:381` (`screenForRoute`).
- `ui/src/app/areas/os-management/database-details.page.ts:208,276-293`: a page issuing a sibling screen's read.
- `ui/src/app/areas/logs/log-viewer.store.ts:256-275`: a store loading a server list for a select.
- `ui/src/app/shell/role-dialog.ts` and its `.spec.ts`: the shell component and host-spec pattern.
- `ui/src/app/areas/web-applications/create-form.page.ts:252-276,767-780` and `ui/src/app/core/violations.ts:20-67`: the field, the display-only resolved caption, and the violation rendering.
- `ui/src/app/core/table-model.ts:94-103`: a boolean in a `status` column renders Yes or No.

**Rosters:**

- `Test/ReadTool.cls:93,94,112`: the count goes from 127 to 128, plus the name list and the descriptor pair.
- `Test/SurfaceCoverage.cls`: the `XData Coverage` rows, one per descriptor.
- `Test/Descriptor.cls`: the `ReadShapes` row at :67, and the entity-type count at :1608, which goes from 31 to 32.
- `Test/SecurityLists.cls:50-64`: `Screens()`.
- The Security screen lists:
  - `Test/Wire.cls:592`;
  - `Test/WireSecurityRead.cls:787,935,963,1070,1089`;
  - `Test/WireOAuthRead.cls:273,288,307,323,342`.
- `ui/tools/navigation.test.mjs:178-201`.
- `scripts/ci-throwaway.sh:192-231`: the `OCUPILOT_ALLOW_PRINCIPALS` block, pinned by `ui/tools/ci.test.mjs:1891`.

**Strings:**

- `EXPERIENCE.md:168` is the Security side-bar row.
- `EXPERIENCE.md:364` is the Security Fixed strings row to extend.
- `strings.ts` already holds `lockColumnDirectory` "Directory", `databaseVolumeColumnFile` "File" and `tableReadOnlyEmptyNext`. Values are unique (`strings.test.mjs:708`), so reuse them.

## Tasks & Acceptance

**Execution:**

**Server:**

- `src/OcuPilot/Port/PathPort.cls` (new): create the port as a `%RegisteredObject` with a class doc comment covering AD-21, AD-29 and AD-27.
  - Parameters:
    - `PURPOSE="%GUIFileSelector"`;
    - `SEGMENTPATTERN`;
    - `MAXSEGMENTS=8`;
    - `SOURCES="roots"`.
  - Seams:
    - `AdminPortClass()`;
    - `ManagerDirectory()`;
    - `HoldsPrivilege(res, perm)`.
  - Methods:
    - `Gate` checks the two pairs in order.
    - `Roots(pMaxRows,.pRows,...)` implements the matrix rows through `$ClassMethod(..AdminPortClass(),"Invoke",…)`.
    - `Rows(pSource,pMaxRows,.pAnswer,.pHttpStatus,.pFault)` refuses any source outside `SOURCES`.
    - `Resolve(pRoot,pPath,pKind,pRootField="root",pPathField="path",.pResolved,.pHttpStatus,.pFault)`.
    - `Contains(pRoot,pCandidate)` is non-strict and keeps the trailing separator.
  - Switch namespace only through `AdminPort`, which runs in `%SYS` (AD-16).
- `src/OcuPilot/Api/Error.cls`: add the documented parameters `PATHROOT="PATH.ROOT"` and `PATHNAME="PATH.NAME"` (`BADREQUEST` slug), with these reasons:
  - "That directory is not one of the instance's allowed directories."
  - "Name a directory or file under it with letters, digits, '.', '_' or '-', at most eight names separated by '/', and no '..'."
- `src/OcuPilot/Screen/Read.cls`:
  - add `SOURCEPATH="path"`;
  - add a dispatch branch calling `PathPortClass().Rows(endpoint, tMax+1, …)`, modeled on `logsource`;
  - add the `PathPortClass()` seam.
- `src/OcuPilot/Screen/Registry.cls`: admit the `path` port, and make the unknown-port refusal name five sources. A `path` source:
  - declares `endpoint` from `PathPort.#SOURCES` and `type` `LIST`;
  - declares no `rowGet`, `forEach`, `query` or `parts`;
  - requires `%DB_IRISSYS:READ`.
- `src/OcuPilot/Kernel/EntityType.cls`: append `allowed-directory` to `TYPES`.
- `src/OcuPilot/Screen/Descriptor/AllowedDirectoryList.cls` (new):
  - `route` is `security/allowed-directories`, `area` is `security`, `sideBarPosition` is 7 and `archetype` is `list`, with no refresh.
  - `privileges` is `[%Admin_FileSystemAccess:USE, %DB_IRISSYS:READ]`, and `ownPrivileges` is `[%Admin_FileSystemAccess:USE]`.
  - `entityType` is `allowed-directory`, `scope` is `instance` and the id is `single`.
  - It declares no actions and has `classicPage ""`, because no classic page exists.
  - The read source is `{port:"path",endpoint:"roots",type:"LIST"}`, with fields, context, filter and sort all `Directory` and `Restricted`, default `Directory` ascending, and paging `cap`.
  - The table has two columns: `Directory` (`name`, `lockColumnDirectory`) and `Restricted` (`status`), plus `emptyNextKey` `tableReadOnlyEmptyNext`.
  - `commandAliases` is `["allow-list","file access"]`.
  - It declares three `userPromptGroupAccess` prompts.
  - `toolIdentifier` is `security.alloweddirectories`.

**Client:**

- `ui/tools/screen-mirror.mjs`: mirror the `path` source and its three rules, and make the source sentence (:1117) name five sources. Then regenerate `ui/src/app/core/screens.generated.ts` with `node tools/screen-mirror.mjs`.
- `ui/src/app/core/allowed-directories.ts` (new): export `ALLOWED_DIRECTORIES_ROUTE` and `AllowedDirectoriesStore`.
  - The store is a framework-free subscribable (AD-19).
  - `load(api)` issues that screen's read through `createScreenRead(screenForRoute(...).screen)` with `maxRows` 1000.
  - Its state is `{status: 'loading'|'ready'|'refused', roots, truncated, reason}`.
- `ui/src/app/shell/server-path-picker.ts` (new): `app-server-path-picker`.
  - Inputs: `store` (required), `kind` (`directory` or `file`), `root`, `path`, `rootReason`, `pathReason`, `idPrefix`.
  - Output: `changed: {root, path}`.
  - It mirrors the store into a signal and renders four states: loading, refused, empty, and ready. Ready shows a native select plus one input and the "Resolves to" caption.
  - Styles use the existing `.ocu-field*` classes. Add to `ui/src/styles/_components.scss` only what they lack.
- `ui/src/app/core/strings.ts`: append these keys, each cited `/** EXPERIENCE.md:364 */`:
  - "Allowed directories"
  - "Restricted"
  - "The instance's allow-list names no directory." (the screen empty state and the picker's empty line)
  - the three prompts:
    - "Which server directories can a file or directory field choose from?"
    - "Does this instance restrict the directories its file dialogs can reach?"
    - "Is the manager directory one of the allowed directories?"
  - "Allowed directory"
  - "Subdirectory"
  - "File name"
  - "Resolves to <path>"
  - "Reading the allowed directories…" (the ellipsis is `…` in `strings.ts` and the literal character in EXPERIENCE.md)
  - "Only the first <n> allowed directories are listed."
- `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md`: edit two rows in place, keeping the file at 993 lines.
  - `:364`: append the new literals and a where-clause ending `[ADDED 2026-09-27 - Story 18.1]`.
  - `:168`: in the Security row's third cell, name "Allowed directories (Stage 2, Story 18.1)".

**Tests:**

- `src/OcuPilot/Test/PathPort.cls` (new): armed under `OCUPILOT_ALLOW_PRINCIPALS`.
  - One method per matrix row from "Unrestricted" through "Not cached", plus `Contains` legs.
  - A gate leg uses a seam subclass: it denies `HoldsPrivilege` and asserts the named refusal with zero `AdminPort` calls.
  - Each method records `%GUIFileSelector` before it runs and restores it exactly after, including on failure. On a fresh instance the purpose is absent, so restoring means `ClearPurpose`.
- `src/OcuPilot/Test/PathPortPrivilege.cls` (new): armed, following the `WireSecurityRead` `EnsurePrincipal` pattern (AD-29).
  - A principal holding exactly the screen's two pairs, plus the sign-in floor, reads the screen with a 200.
  - Without either pair it gets a 403 naming that pair.
  - Any further pair the instance demands is added to the descriptor and the gate, and recorded here.
- `scripts/ci-throwaway.sh`:
  - add `# classes: PathPort, PathPortPrivilege`;
  - extend the block comment with "or the instance's file-system access allow-list".
- `src/OcuPilot/Test/Descriptor.cls`: add registry legs for the `path` rules, the `ReadShapes` row, and the count of 32.
- `ui/tools/screen-mirror.test.mjs`: add the mirrored `path` rules.
- `src/OcuPilot/Test/SecurityLists.cls`: add the screen to `Screens()`.
- The rosters `ReadTool`, `SurfaceCoverage`, `Wire`, `WireSecurityRead` and `WireOAuthRead`: add the screen wherever the list's principal holds `%Admin_FileSystemAccess:USE`.
- `ui/tools/navigation.test.mjs`: add the route after `security/auditing`.
- `ui/tools/allowed-directories.test.mjs` (new): cover the store's path, its states, and truncation, against a fake api.
- `ui/src/app/shell/server-path-picker.spec.ts` (new): a host spec covering each state and the outputs.
- `ui/browser/allowed-directories.browser-spec.mjs` (new):
  - Model it on `devices.browser-spec.mjs` and `list-spec.mjs`, calling `resetRememberedState()`.
  - Use `docker exec` to clear the purpose, then set it up.
  - Cover two legs, fresh and restricted. Clear the purpose again in `after`.

**Acceptance Criteria:**

- **AC1:** Given a signed-in holder of both pairs, when they open Security, then "Allowed directories" is the seventh side-bar entry. Its list shows the matrix rows for the instance's state. `security.alloweddirectories.read` answers the same rows, narrowed only by its cap.
- **AC2:** Given least-privileged principals on `ocupilot-b-ci`, when they read the screen over the wire, then:
  - a principal holding exactly the declared pairs gets a 200 with rows;
  - a principal lacking either pair gets a 403 naming it;
  - `PathPort` called directly without `%Admin_FileSystemAccess:USE` refuses before any `AdminPort` call.
- **AC3:** Given a consumer embedding `app-server-path-picker` with an `AllowedDirectoriesStore`, when the store is in each state, then the picker shows the following:
  - Loading: the loading line.
  - Refused: the store's reason, with no select and no input.
  - Empty: the empty line, with no select and no input.
  - Ready:
    - a select whose options are exactly the roots in read order, preselected when there is one root, and that preselection emits `changed` once so the consumer holds the root;
    - one relative-name input, labeled "Subdirectory" for a directory or "File name" for a file;
    - a display-only "Resolves to" caption;
    - the truncation line when the read was truncated.
  - A `root` input that is not among the roots is not selected.
  - Each change emits `{root, path}`.
  - `rootReason` and `pathReason` render on their own fields with `aria-invalid` and `aria-describedby`.
- **AC4:** Given the new screen, when the DW-1337 structural walk runs in both themes, then no violation outside the baseline appears. The production build stays under its 2106 kB warning [AMENDED 2026-09-28 - see the story change log].

### Review Findings

Code review 2026-09-28, four layers, `full-opus`. 51 rows, 15 entries: 10 patched, 5 ledgered, 31 rows rejected.

- [x] [Review][Patch] `[medium]` The picker was never drawn before its store settled, so dropping its subscription stayed green (AC3) [ui/src/app/shell/server-path-picker.spec.ts:105]
- [x] [Review][Patch] `[medium]` A restricted purpose whose root-path list fails with anything but 404 had no leg (fail-closed) [src/OcuPilot/Test/PathPort.cls:361]
- [x] [Review][Patch] `[medium]` The browser spec's teardown cleared the allow-list on any non-live container, including one its own `before()` had refused [ui/browser/allowed-directories.browser-spec.mjs:59]
- [x] [Review][Patch] `[low]` `Resolve` checked the kind before its gate, against its doc [src/OcuPilot/Port/PathPort.cls:224]
- [x] [Review][Patch] `[low]` `Resolve`'s unknown-kind 500 had no leg [src/OcuPilot/Test/PathPort.cls:232]
- [x] [Review][Patch] `[low]` `Resolve`'s normalize comment described the two-argument form [src/OcuPilot/Port/PathPort.cls:253]
- [x] [Review][Patch] `[low]` `Resolve`'s containment check (AD-21) was pinned only through `Contains` alone; a seam now admits any name [src/OcuPilot/Test/PathPort.cls:242]
- [x] [Review][Patch] `[low]` The integration leg skipped the tool comparison silently on an OK status with no view [src/OcuPilot/Test/PathPort.cls:311]
- [x] [Review][Patch] `[low]` AC2's 200 leg had no `mutation:` line; demonstrated below [src/OcuPilot/Test/PathPortPrivilege.cls:216]
- [x] [Review][Patch] `[low]` `Wire.cls` said "sixteen built screens" beside the twenty-three it asserts [src/OcuPilot/Test/Wire.cls:567]
- [x] [Review][Defer] `[low]` The destructive-test gate cannot see the allow-list helpers reached through `$ClassMethod(..#FIXTURE, …)` [scripts/check-objectscript.py:1353] — deferred: occurrence on DW-1451 (same root cause)
- [x] [Review][Defer] `[med]` `Resolve` admits any file name under the manager-directory default root, instance files included [src/OcuPilot/Port/PathPort.cls:277] — deferred: DW-1770 `decision-pending`, an owner call before 16.4 writes a file
- [x] [Review][Defer] `[low]` The picker's refused line is empty without an envelope reason [ui/src/app/shell/server-path-picker.ts:52] — deferred: DW-1771 `wontfix-accepted`
- [x] [Review][Defer] `[low]` `HoldsPrivilege`'s real check is never denied in a test [src/OcuPilot/Port/PathPort.cls:80] — deferred: DW-1772 `wontfix-theoretical`
- [x] [Review][Defer] `[low]` `PATH.NAME`'s reason omits the leading-character, 100-character and trailing-`/` rules [src/OcuPilot/Api/Error.cls:401] — deferred: DW-1773 `by-design`

**Rejected:**

- `false`: AD-8's "the one case today is Logs" (blind-hunter, acceptance-auditor). It is a spine edit, which Rule 20 gives to the runner, not a code defect.
- `false`: the matrix "No privilege" code (acceptance-auditor). The fix would edit this spec; the screen gate refuses first by construction.
- `false`: `PORT.ACCESSDENIED` for the port's own gate. The Always list names that code.
- `false`: the caption shows nothing until a root is chosen. There is nothing to compose, and a spec test pins it.
- `false`: default field ids. `idPrefix`'s default is evaluated per instance.
- `false`: `onRoot` and `onPath` read the root differently. The picker is controlled, as its doc says ("the consumer owns … the `{root, path}`").
- `false`: the unrestricted root is misstated, and the empty state gives no remedy. Both are spec-bound (Design Notes, Tasks).
- `false`: symbolic links. AD-21 names textual containment.
- `false`: `lockColumnDirectory` reuse and the Wallet row at `EXPERIENCE.md:364`. The spec directs both.
- `false`: smoke skips the `path` source. AD-45 asks for one list per area.
- `false`: EXPERIENCE.md:168 was not add-only. The spec directs that in-place cell edit.
- `false`: AC3 needs more mutations. Rule 19 asks one per AC.
- `false`: the picker has no browser host. No page embeds it until 18.3, so Rule 3's real-runtime evidence is the screen's browser spec.
- `low`: the caption for a `..` name, a trailing `/`, or a file with no name. The caption is display only, and no client copy of the name rule is allowed.
- `low`: no placeholder option in the select, a reload unmounting the controls, a one-root picker drifting from a stale consumer root, no live-region role on the refused line. Each is a new string or a behavior change, with no consumer yet.
- `low`: AC1's side-bar entry is never seen allowed for a principal who also lacks the area's pairs. The position is pinned by `navigation.test.mjs`, and the area gate is AD-8's.
- `low`: the empty-state iteration compares nothing with nothing. The other two iterations carry that test.
- theoretical: a missing or non-boolean `Restricted`; `tBase` read as `""`; a row without `RootPath`; the mirror's `.trim()`; the two 1,000-row caps coupled only by comment. Each needs vendor drift or more than 1,000 roots.
- theoretical: throwaway-only test hygiene. That covers principals left after a failed setup, a partial `Restore`, a `Scope` left set on a throw, and the untested caller-fault branches (unknown source, `maxRows` below 1, a non-object purpose, a non-array list).

### Rework iteration 1 (CI red and integrate-forward)

- [x] [CI] browser shard 1/3, run 36393142503: `ui/browser/oauth.browser-spec.mjs:283` (AC1) pins the Security side bar as six entries and now reads a seventh, "Allowed directories" -- add it to the expected list.
- [x] [CI] browser shard 3/3, run 36393142503: `ui/browser/ssl.browser-spec.mjs:206` (AC4) pins the same side bar and its assertion message -- add "Allowed directories" to both. Then grep every other test for a pinned Security side-bar list or Security screen count and extend each one the new screen reaches.
- [x] [Merge] The runner merged feature `f03c1e32` in as `b219bc17` (Story 16.9's `timeline` read source beside this story's `path` source; `Read.Execute`'s port list now admits `SOURCEPATH`; the unknown-port refusal names six sources in `Registry.cls`, `screen-mirror.mjs` and `AdminPairCorpus.cls`; `ReadTool` 129). Re-derive every exact-count roster this story bumped against the merged code (`ReadTool`, `SurfaceCoverage`, `Descriptor`, `Wire`, `WireSecurityRead`, `WireOAuthRead`, `SecurityLists`, `navigation.test.mjs`, `screen-mirror.test.mjs`, `ci.test.mjs`) and fix any the merge left wrong. Verify on a throwaway loaded with the merged `src/` (Rule 22): the story's own classes and the rosters above, `LogHubWire`, the full ObjectScript sweep once, the story's browser spec plus `oauth.browser-spec.mjs` and `ssl.browser-spec.mjs`, the client tiers, and smoke.
- [x] [Merge] CI run 36397094123 on `b219bc17`: every `gates` leg fails `ui/tools/build-output.test.mjs` DW-371, the merged initial total 2,005,146 bytes against `maximumWarning` 2004kB. Re-base the warning per DW-1166 (about 5% above the merged total you measure) in `ui/angular.json` and `ui/tools/angular-json.test.mjs`'s pinned literal together. (`instance shard 1/3` failed bringing up its throwaway on a bound host port; no test ran.)

### Review Findings (round 2)

Code review 2026-09-28, of rework 1 and merge `b219bc17`: four layers, `full-opus`. 15 rows, 11 entries: 3 patched, 2 ledgered, 6 rejected. No high. The three rework items are fixed, and the merge resolutions hold to AD-36 and AD-21's sixth case.

- [x] [Review][Patch] `[low]` The merge left the read-source enumerations at five, without `timeline`, whose fields and criterion are fixed [ui/tools/screen-mirror.mjs:921] (also `:2928`, `Registry.cls:976`, and `screens.generated.ts` regenerated)
- [x] [Review][Patch] `[low]` The rework's side-bar `mutation:` lines edit the tests' expected lists, and AC1's seventh entry had no product mutation; it is demonstrated below [src/OcuPilot/Screen/Descriptor/AllowedDirectoryList.cls:26]
- [x] [Review][Patch] `[low]` The budget test's example of loosening, "2MB", is below the warning it claims to loosen [ui/tools/angular-json.test.mjs:372]
- [x] [Review][Defer] `[med]` Area side bars are pinned as literal lists in browser specs that a screen-adding story does not target [ui/browser/oauth.browser-spec.mjs:283] — deferred: DW-1774 `routed` to 18-7-encryption
- [x] [Review][Defer] `[low]` `maximumWarning` is edited on both epics' branches again [ui/angular.json:54] — deferred: occurrence on DW-1749

**Rejected:**

- `low`: AC4 still names 2004 kB. The fix edits this spec; it is the runner's Rule 5 apply-and-report amendment.
- `low`: "The CI red is closed" was written before run 36403585450 finished, and `b219bc17`'s gates legs skipped the checkers. The fix edits this spec. At review time the run's three gates legs, `package`, `images` and `instance shard 2/3` were green; the other shards were still running, and Rule 28 leaves them to the lead.
- `low`: the Spec Change Log counts three rework items where four are ticked. The fix edits the runner's section.
- `false`: DW-1771 is a live hand-off to 18.3. It is terminal, and its `reopen_if` names what the embedding page would show, which is Rule 15's hand-off.
- `low`: no corpus row refuses `criteria` on a `path` read. The rule is an allow-list whose refusing branch the `monitor` and `state` rows pin, so only a deliberate edit that adds `path` escapes it.
- `low`: commit `86e9c0a9`'s message places run 36393142503 on `b219bc17`, but that run's head is `b29c7ea7`. The fix rewrites pushed history, and the spec's `[CI]` item names no head.

### Rework iteration 2 (DW-1770, orchestrator decision)

- [x] [Decision] DW-1770, decided by the orchestrator at the 18.1 boundary (2026-09-28) and written into AD-21's sixth case: for `kind` `file`, `PathPort.Resolve` also refuses (1) a name that already exists on disk, unless the caller declares that it overwrites (a new trailing `pOverwrite` argument, default 0, so no consumer overwrites by accident), and (2) a name directly in `<ManagerDirectory>` itself (one segment under an unrestricted root, or any root that normalizes to the manager directory), which holds the instance's own files. A `directory` kind is unaffected. Each refusal is a `detail.violations[]` entry on the `path` field with its own code and a server-written reason in `Api/Error.cls` (no path echoed, AD-39), refused before any vendor call. Pin each refusal with a `PathPort` test leg and a Rule 19 mutation (the existence check removed; the manager-directory check removed; overwrite ignored), and extend the `Test/PathPort.cls` matrix legs; the picker needs no change. Evaluated at every `Resolve`, so at the mint and again at the write.

### Review Findings (round 3)

Code review 2026-09-28, of rework 2 (`e3d44277..27246d90`): four layers, `full-opus`. 29 rows, 8 entries: 5 patched, 3 ledgered, 15 rows rejected. No high. DW-1770's two refusals and the overwrite switch are done, each pinned with a recorded mutation, and hold to AD-21's sixth case, AD-29 and AD-39.

- [x] [Review][Patch] `[low]` With `pOverwrite` 1, a file resolved over an existing directory; a directory at the name is now refused `PATH.EXISTS` whatever `pOverwrite` says [src/OcuPilot/Port/PathPort.cls:276]
- [x] [Review][Patch] `[low]` "A directory is unaffected" had no `mutation:` line; two are demonstrated below [src/OcuPilot/Test/PathPort.cls:323]
- [x] [Review][Patch] `[low]` The manager-directory mutation line counted five refused legs and its test doc said each resolves; re-run on the final tree, six go red [src/OcuPilot/Test/PathPort.cls:309]
- [x] [Review][Patch] `[low]` `DirectlyInManagerDirectory` normalized an empty manager directory to the current directory instead of failing closed [src/OcuPilot/Port/PathPort.cls:325]
- [x] [Review][Patch] `[low]` The `ManagerDirectory()` seam doc named only the root, not the directory `PATH.MANAGER` guards [src/OcuPilot/Port/PathPort.cls:68]
- [x] [Review][Defer] `[med]` The file kind offers only new-or-overwrite: an import or a key file to activate is refused `PATH.EXISTS` unless it passes `pOverwrite`, which no declaration governs [src/OcuPilot/Port/PathPort.cls:276] — deferred: DW-1778 `routed` to 18-7-encryption
- [x] [Review][Defer] `[med]` Databases one level down (`irisaudit/`, `irissecurity/` `IRIS.DAT`) resolve to an overwriting consumer [src/OcuPilot/Port/PathPort.cls:325] — deferred: occurrence on DW-1777 (same root cause as the CPF)
- [x] [Review][Defer] `[med]` A directory-kind location may be the manager directory itself, where a vendor-named file lands among the instance's own [src/OcuPilot/Port/PathPort.cls:271] — deferred: DW-1779 `routed` to 18-3, severity unverified

**Rejected:**

- `low`: no leg re-resolves a name after creating it. `Resolve` calls `%File.Exists` on every call, and Rule 19 asks one mutation per AC; the three the rework item names are recorded.
- `low`: `PATH.MANAGER` compares text, so a case-variant, symlinked or re-mounted spelling of the manager directory escapes it (four rows). AD-21 names textual containment, and without `pOverwrite` `PATH.EXISTS` still refuses an existing instance file.
- theoretical: a file created between the write-time `Resolve` and the vendor's write (two rows); `%File.Exists` answering 0 for an unreadable name or a dangling symlink.
- `by-design`: an unrestricted instance's file needs a subdirectory. The orchestrator's decision refuses one name under the manager directory by design.
- `false`: the class doc omits the two refusals. It enumerates none, and `Resolve`'s doc carries all four.
- `false`: DW-1770 is not closed. The runner closes this story's entries at `ledger_adjudicated`.
- `low`: the Auto Run Result's counts and caller list, the `deferred:` entry's wording, and a triage-log line number (four rows). Each fix edits this spec's implement-stage record; DW-1777 is the harvested record.

### Rework iteration 3 (DW-1777, DW-1778, DW-1779, orchestrator decision)

- [x] [Decision] DW-1778 (orchestrator, by=merge_gate 2026-09-28, before Epic 16's 16.4 builds on the `pOverwrite` workaround): add a read-existing mode to `PathPort.Resolve`, `kind` `source`, which requires the file to exist (refused with its own `PATH.*` code and server-written reason when it does not, and when the name is a directory) and never implies overwrite; `file` keeps new-or-overwrite. A `source` is not refused for existing, and is still contained and still refused directly in the manager directory. Amend AD-21's sixth case once, at origin, in the runner's words (the runner writes the spine; say in the spec what the sentence must state).
- [x] [Decision] DW-1777: for any overwriting consumer (`file` with `pOverwrite` 1), also refuse the instance's configuration file and its siblings in the data directory (`iris.cpf`, `_LastGood_.cpf`, dated CPF copies -- the directory `$System.Util.ManagerDirectory()`'s parent on this build; derive it at call time from the instance's own CPF location, never a literal) and a database file one level below the manager directory (`irisaudit/IRIS.DAT`, `irissecurity/IRIS.DAT`, any `<subdir>/IRIS.DAT` directly under the manager directory), with a `PATH.*` code; a new file is unaffected.
- [x] [Decision] DW-1779, if small: a `directory` kind that resolves to the manager directory itself (the unrestricted root with an empty name) is refused for a consumer whose vendor writes its own files into the chosen directory. If it is not a small change, leave it unchecked and say so in the Auto Run Result; the runner re-owns it to 18.3.
  - AD-21's sixth case does not carry this rule yet. The sentence it needs: "A directory the consuming tool's vendor writes its own files into (a database, a journal, a backup) is refused when it is `<ManagerDirectory>` itself; the tool declares that its vendor writes there, and every other directory is unaffected."
- Each refusal and the new mode is pinned by a `Test/PathPort.cls` leg with a Rule 19 mutation, recompiling `PathPort` and `PathPortFixture` on the throwaway.

## Spec Change Log

- 2026-09-27, spec gate (runner): the proposed AD-21 sixth case under Design Notes was written into the spine verbatim, with "every server-path field (Story 18.1 on)" added to AD-21's Binds (Rule 20). The spine is the authority from here; Design Notes keeps the proposal text for the reviewer.
- 2026-09-28, rework iteration 1 (runner): re-opened on CI run 36393142503's red (two browser specs pin the Security side bar) and on the integrate-forward merge `b219bc17`; the work is the three items under Tasks & Acceptance › Rework iteration 1.
- 2026-09-28, runner (Rule 5, apply and report): AC4 read "stays under its 2004 kB warning". The merged bundle measured 2,005,146 bytes and rework 1 re-based `maximumWarning` to 2106kB under the owner's DW-1166 policy (the runner's brief allows a re-base and stops only above 3800kB), so AC4 now names 2106 kB. Intent unchanged: the build stays under its warning.
- 2026-09-28, rework iteration 2 (runner): re-opened on the orchestrator's decision of DW-1770 at the 18.1 boundary, which directs the fix as its own commit before 18.2's implement push; the work is the one item under Tasks & Acceptance > Rework iteration 2. AD-21's sixth case carries the rule.
- 2026-09-28, rework iteration 3 (runner): re-opened on the orchestrator's decision (by=merge_gate) that DW-1777, DW-1778 and, if small, DW-1779 are fixed here, as their own commit, before Epic 16's 16.4 consumes PathPort; the work is the items under Tasks & Acceptance > Rework iteration 3.

## Review Triage Log

### 2026-09-28 — Review pass

- verdicts: 17 findings — high 0, medium 3, low 7, false 7, maybe-false 0
- findings:
  - `[medium]` `[patch]` (verification-gap) A `path` read cut at its cap is never tested for `truncated` — added a cap-of-one read under two roots to `PathPort.TestTheScreenReadAndToolAnswerThePortsRows`, asserting one row and `truncated` 1; `tMax + 1` → `tMax` reddens it.
  - `[medium]` `[patch]` (verification-gap) `Roots`' fail-closed pass-through and its list-404 fallback are unpinned — `PathPortFixture.Script` answers a named endpoint and type; `TestAVendorFaultPassesThroughAndARemovedPurposeFallsBack` pins 500 and 403 pass-through and the race fallback; both mutations redden it alone.
  - `[low]` `[patch]` (verification-gap) `Resolve`'s own gate call is not load-bearing — a denied caller's `a..b` now asserts 403 per pair; removing the gate reddens it.
  - `[low]` `[patch]` (verification-gap) `parsePathSources`' null branch has no test — two asserts beside `parseEntityTypes`'; answering `[]` reddens them.
  - `[low]` `[patch]` (verification-gap) AC4 has no `mutation:` line — a header-label contrast mutation, rebuilt and redeployed, reddened the AC4 leg on this route's own keys; line added under Verification.
  - `[low]` `[reject]` (verification-gap, other) `## Auto Run Result` says the browser spec passed 3 of 3 — the fix edits this spec; Finalize rewrites that section (4 of 4).
  - `[low]` `[patch]` (verification-gap, other) `AdminPairCorpus` says the system-read rule names admin reads alone — corrected to admin and path reads at the doc comment and both case names.
  - `[low]` `[reject]` (intent-alignment) Matrix "No privilege" reads `PORT.ACCESSDENIED` for the screen read, while the wire answers the screen gate's `AUTH.NOPRIVILEGE` — the screen's declared pairs equal the port's, so AD-8's screen gate always refuses first, naming the pair and before any `AdminPort` call; the port's code is pinned in process and by `PortGate`, and the picker renders any refusal's reason. No change satisfies both the literal code and the declared pairs.
  - `[false]` `[reject]` (intent-alignment) `Resolve` checks the name before the roots, so a request with both faults answers `PATH.NAME` — the intent fixes no order; AD-21 asks both refusals to come before any vendor call, and a name refused first spares an admin read.
  - `[false]` `[reject]` (intent-alignment) The picker takes reasons from its consumer and nothing maps `violations[].field` end to end — the picker renders each reason on the field it names, as the intent says; the mapping is the consumer's (Design Notes › Consumed-by), and no consumer exists in this story.
  - `[false]` `[reject]` (intent-alignment) The tool and table show the roots in the declared sort, not the vendor's order — the route and port answer the vendor's order; AD-36 makes the tool's view the screen's view, and the test compares against `ApplyView` of the port's rows.
  - `[low]` `[reject]` (intent-alignment) No principal-driven test calls the read tool without a pair — the tool's gate is the descriptor's by construction (`Screen/Tool/Read.PrivilegePairs` → `Screen.Gate.RequiredPairs`), shared by every derived read tool; a new principal fixture would add complexity for code this story does not touch.
  - `[medium]` `[patch]` (intent-alignment) Truncation is not covered through the route or the tool for a `path` source — same root cause as the first row; closed by the same leg.
  - `[false]` `[reject]` (intent-alignment) `PathPortFixture` calls `%SYS.FileSystemAccess` directly — the Never list governs the shipped port; the spec's Tasks require the fixture to record, set and restore the allow-list, and it is test-scoped and armed.
  - `[false]` `[reject]` (intent-alignment) `strings.ts` keys are inserted beside `walletListEmpty`, not at the end — no existing key changed; they sit with the other `EXPERIENCE.md:364` citations, and nothing enforces position.
  - `[false]` `[reject]` (intent-alignment) Roster counts, messages and one corpus case changed — each is forced by the added entry and named by the spec (127 → 128, 31 → 32, "five sources"); nothing was removed or reordered.
  - `[false]` `[reject]` (intent-alignment) The "Resolves to" caption shows a path for a name the server would refuse — by design: the caption is display only and the Never list forbids a client copy of the segment rule; `PATH.NAME` arrives as `pathReason`.

### 2026-09-28 — Review pass, rework 1

- verdicts: 8 findings — high 0, medium 0, low 3, false 5, maybe-false 0
- findings:
  - `[low]` `[reject]` (verification-gap, other) AC4 still reads "under its 2004 kB warning" while the diff re-bases the warning to 2106kB — the fix edits this spec; the re-base follows DW-1166's owner policy, and the AC4 figure is reported to the runner as a Rule 5 apply-and-report amendment.
  - `[low]` `[reject]` (verification-gap, other) `## Auto Run Result` is stale and records none of this pass's verification — the fix edits this spec; Finalize rewrites that section with this pass's record, including the merged-tree sweep that covers `instance shard 1/3`'s unrun leg.
  - `[false]` `[reject]` (intent-alignment) The diff's tests exercise the side bar and the budget, not the port, read, picker and store the intent lives at — this pass changes no code on those surfaces, and their pinning tests ran on the merged tree: `PathPort` 12/12, `PathPortPrivilege` 2/2, `allowed-directories.browser-spec.mjs` 4/4, full sweep 0 failed.
  - `[low]` `[reject]` (intent-alignment) No test reads the Allowed directories entry for a principal lacking `%Admin_FileSystemAccess:USE` — not caused by this pass; the "No privilege" row is pinned by `PathPort`'s gate leg, `PathPortPrivilege` and the picker spec, the own pair by `Descriptor.cls:1064`, and a lesser-principal browser leg adds a fixture for AD-8's generic gate.
  - `[false]` `[reject]` (intent-alignment) The screen's side-bar placement is pinned only by sibling specs — it is pinned at `navigation.test.mjs:379` and in three browser specs; which file pins it has no named harm.
  - `[false]` `[reject]` (intent-alignment) The `[Merge]` roster item is ticked with no evidence in the diff — re-derivation found no roster wrong, so no roster or mutation line changed; the sweep was re-read from `%UnitTest_Result` on `ocupilot-b-ci` (334 classes, 2,760 passed, 0 failed, none unlanded).
  - `[false]` `[reject]` (intent-alignment) The side-bar mutations' "rebuilt and redeployed bundle" is unchecked — checked: the served `index.html` on `ocupilot-b-ci` loads `main-HO67DN2T.js`, md5-identical to the working tree's `dist/`.
  - `[false]` `[reject]` (intent-alignment) Under a broad add-only reading the rewritten test titles, messages and `maximumWarning` break the constraint — the intent's add-only list names EXPERIENCE.md, `strings.ts` and the shared rosters; each rewritten message sits beside an appended entry, and DW-1166 re-bases the budget value in place with its pinned literal.

### 2026-09-28 — Review pass, rework 2

- verdicts: 13 findings — high 0, medium 2, low 5, false 6, maybe-false 0
- findings:
  - `[low]` `[patch]` (verification-gap) Which refusal wins for an existing file directly in the manager directory is unpinned — added `IRIS.DAT` without overwrite, expecting `PATH.MANAGER`; swapping the two checks reddens it alone (run 363).
  - `[medium]` `[defer]` (verification-gap, other) `iris.cpf` sits in the manager directory's parent, so `PATH.MANAGER` does not protect it — confirmed on `ocupilot-b-ci` (`/durable/iris/iris.cpf`); the rework item scopes the rule to "directly in", and the fix is AD-21's example list or a wider rule, the runner's and orchestrator's; `deferred:`.
  - `[medium]` `[defer]` (intent-alignment) Reading A3, "the instance's own files", reaches `iris.cpf` and the diff does not — same root cause and route as the row above.
  - `[false]` `[reject]` (intent-alignment) The root-above leg exceeds the parenthetical, and a differently spelled root is untested — `DirectlyInManagerDirectory` compares the normalized file with the normalized manager directory whatever the root, and AD-21 reads "directly in".
  - `[false]` `[reject]` (intent-alignment) `pOverwrite` is a runtime argument, not a tool declaration — the rework item directs a trailing `pOverwrite`, default 0; the declaration is the consumer's, and none exists yet.
  - `[false]` `[reject]` (intent-alignment) No test creates a name between two resolutions — `Resolve` calls `%File.Exists` on every call with nothing cached (`PathPort.cls:276`).
  - `[low]` `[reject]` (intent-alignment) The existing `/tmp/` file legs now pass only while those names are absent — nothing in `src`, `ui` or `scripts` writes `/tmp/exports`, and CI throwaways are fresh.
  - `[low]` `[reject]` (intent-alignment) The matrix and Always bullets do not name the two refusals — the fix edits this spec's intent block; AD-21 carries the rule.
  - `[false]` `[reject]` (intent-alignment) `epic-18-context.md` still lists DW-1770 as pending and two codes — the spine (03:35) is newer than the cache (02:54), so the pre-warm recompiles it before the next plan spawn.
  - `[low]` `[patch]` (intent-alignment) Which code wins is not pinned — same root cause as the first row; closed by the same assertion.
  - `[false]` `[reject]` (intent-alignment) The client has no map of `PATH.*` codes — the picker renders the consumer's reason for any code (AD-39), as the rework item says.
  - `[low]` `[reject]` (intent-alignment) A manager directory that does not normalize refuses every file, untested — unreachable on a running instance; it fails closed by design.
  - `[false]` `[reject]` (intent-alignment) The three mutation lines were not re-run by the auditor — runs 348 to 350 on `ocupilot-b-ci` each failed exactly the named method, and the verification-gap layer matched each line to the code.

### 2026-09-28 — Review pass, rework 3

- verdicts: 17 findings — high 0, medium 2, low 7, false 8, maybe-false 0
- findings:
  - `[low]` `[patch]` (verification-gap) A source directly in the manager directory had no `mutation:` line, and the rework-2 manager-directory line's "alone" went stale — limiting the check to a `file` reddened the source leg alone (run 23); removing it reddened both methods (run 24), and that line now says so.
  - `[low]` `[patch]` (verification-gap) The database-file refusal was tested only with the manager directory as the root — added a leg restricted to the directory above it, expecting `PATH.INSTANCE`; the helper-false mutation reddens it (run 29).
  - `[low]` `[patch]` (verification-gap) The case-insensitive `IRIS.DAT` match was untested — added a direct assertion on `DatabaseFileBelowManagerDirectory` for a lower-case name; comparing with case reddens it alone (run 25).
  - `[low]` `[patch]` (verification-gap) Three decided clauses had no `mutation:` line (an existing source resolves, a new file is unaffected, only a declared vendor write is refused) — runs 26, 27 and 28 each reddened the named legs; lines added.
  - `[medium]` `[defer]` (verification-gap, other) `PATH.INSTANCE` misses the library databases at `/usr/irissys/mgr/<name>/`, outside the manager directory — the code matches DW-1777 and AD-21 as written; widening is the orchestrator's call; `deferred:`.
  - `[low]` `[reject]` (verification-gap, other) carried: `## Auto Run Result` still describes the previous pass — the fix edits this spec; Finalize rewrites it.
  - `[low]` `[reject]` (verification-gap, other) `Test/PathPort.cls` is 606 lines against the rules' 500 — the rework item puts every leg in that class; a split is more than a direct correction, and no reader is misled.
  - `[false]` `[reject]` (intent-alignment) Under a closed reading the diff adds a kind, three codes and two arguments — the intent defers to "a new AD-21 case" that the runner writes, and AD-21 now carries DW-1777 and DW-1778.
  - `[false]` `[reject]` (intent-alignment) Nothing exercises the mint-then-write sequence, the wire envelope for the new codes, or a picker showing them — `Resolve` has no consumer or route in this story (Design Notes), `Envelope` sweeps every code, and the picker renders whatever reason its consumer passes.
  - `[false]` `[reject]` (intent-alignment) The picker's `kind` is `directory` or `file`, so a source embeds it as `file` — `kind` chooses only the label and the caption separator (`server-path-picker.ts:238,248`), and "File name" with no trailing separator is right for a source.
  - `[false]` `[reject]` (intent-alignment) carried: `pOverwrite` (and now `pVendorWrites`) is a per-call argument, not a tool declaration — the rework items direct trailing arguments, default 0; the declaration is the consumer's, and none exists yet.
  - `[low]` `[reject]` (intent-alignment) `PATH.MANAGERDIR` runs ahead of AD-21, which does not state DW-1779 yet — the fix is a spine edit, which the Never list gives to the runner; the sentence is recorded under the rework item and handed to the runner in the Auto Run Result.
  - `[false]` `[reject]` (intent-alignment) The first half of the configuration test derives its directory with the port's own call — the seam leg tells the two derivations apart, and its mutation reddened it alone (run 7).
  - `[medium]` `[defer]` (intent-alignment) "The instance's own files" also covers journals and databases deeper down or under another root — same root cause as the library-database row; same route.
  - `[false]` `[reject]` (intent-alignment) `PATH.INSTANCE` refuses every existing file beside the CPF, `irisinfo.txt` included — the rework item names the CPF "and its siblings", every file there is the instance's, and a new name there resolves.
  - `[false]` `[reject]` (intent-alignment) `PATH.EXISTS`, `PATH.NOFILE` and `PATH.INSTANCE` let a caller probe names — the Never list's "no browsing" bars a listing control; DW-1778 requires a missing source to be refused with its own code, and the caller holds the port's two pairs.
  - `[false]` `[reject]` (intent-alignment) The diff edits two existing mutation lines in place on an oversized spec — Rule 19 requires a changed pinning test's line to be updated in the same pass; Finalize rewrites the Auto Run Result.

## Design Notes

**Governing ADs:**

- AD-21: the new case, below.
- AD-2 and AD-27: `FSAccess` is reached only through `AdminPort`, and it is already in the inventory fixture.
- AD-29: `PathPort`'s own gate.
- AD-8: pairs checked at call time; the screen's own pair; no elevation, which is why `%CSP.Portal.Utils` is not used.
- AD-5, AD-36 and AD-44: one descriptor and one read for the screen, the tool and the picker; there is no classic page.
- AD-13 and AD-14: the new `allowed-directory` type.
- AD-19: the store.
- AD-39: reasons are written on the server only.
- AD-22: read-only, so no governance key; `Baseline.cls` is untouched.
- AD-3, AD-53 and AD-55: consumers compose the location field.

**Measured on `ocupilot-b-ci`, 2026-09-27.**

- On a fresh instance there are no purposes, so every picker offers the manager directory `/durable/iris/mgr/`.
- The roles that grant `%Admin_FileSystemAccess:U` are `%Manager`, `%SecurityAdministrator`, `%Admin_Secure` and the resource's own role. `%Operator` is not among them.
- A probe purpose `OcuPilotProbe181` answered as follows:
  - `PUT` with `{"Restricted":true}` gave 201.
  - A path `PUT` gave 201, and the stored path had a trailing slash.
  - A missing directory gave 500 #5021.
  - The reads answered the shapes in the Code Map, and `maxRows` 1 answered one row.
  - The `DELETE` of the purpose cleared both the purpose and its paths. Afterwards `%SYS.FileSystemAccess` held 0 rows.

**Proposed AD-21 amendment (Rule 20), for the runner to write at the spec gate as AD-21's sixth case.** Also add "every server-path field (Story 18.1 on)" to its Binds.

> The sixth is a location drawn from the instance's directory allow-list, the one form every server-path field takes from Story 18.1 on [AMENDED 2026-09-27, Story 18.1 spec gate, Rule 20]: the caller names a **root** and a **relative name**, never a path. `Port/PathPort` alone computes the roots, at call time and never cached. When the instance restricts `%GUIFileSelector`, the purpose its own file dialogs read, the roots are that purpose's root paths as the admin API answers them (`FSAccess.Purpose` `GET`, `FSAccess.Path` `LIST`). Otherwise, with the purpose absent or its flag off, the root is `<ManagerDirectory>` alone. A root is accepted only when it equals, character for character, one that read answers. The relative name is empty or at most eight `/`-separated segments, each matching `^[A-Za-z0-9][A-Za-z0-9._-]{0,99}$`, with a literal `..` refused; a file takes at least one segment. The port composes the path under the root with `%File` and requires the normalized result to begin with the root. It refuses `PATH.ROOT` or `PATH.NAME` before any vendor call, and no refusal echoes a path. A write tool resolves again at the write, so a root dropped after the mint refuses the confirm. The vendor receives the composed path under its own field, which is never a settable field of the tool. The tool declares the port's pairs, `%Admin_FileSystemAccess:USE` and `%DB_IRISSYS:READ`, under AD-8's endpoint clause. The roots are the Allowed directories screen's read (source `path`), so the screen, its tool and every picker show one list. Containment is textual, as the vendor's `IsDirectoryAllowed` is, so a symbolic link inside a root is followed.

**Why the manager directory when unrestricted.** The unrestricted instance permits every directory, and AD-21 permits none named by a caller. The existing five cases all root at `<ManagerDirectory>`, and so do the classic defaults for a database, a journal and an export. The alternative was to offer nothing, which would leave every picker empty on a default install and on the demo container. An operator who wants other locations restricts `%GUIFileSelector` and names them.

**Integration ACs:**

- In this story, the Allowed directories screen and its read tool consume `PathPort.Rows`. That is the matrix Integration row, with AC1 and AC2.
- The resolver and the picker have no consumers in this story. Their first consumer will be Story 18.3.

**Consumed-by:**

| Story | Uses |
| --- | --- |
| 18.3 | database create directory |
| 18.5 | journal directories |
| 16.4 | task export and import file (slot A, after this merges) |
| 19.2 | export and import files |
| 19.8 | data export file |
| 21.2 | backup location |

Each consumer does the following:

- declares `root` and `path` arguments;
- declares `%Admin_FileSystemAccess:USE` itself;
- calls `PathPort.Resolve` at the mint and again at the write;
- sends the resolved path under the vendor's own field;
- embeds the picker with a store its page owns, and renders `PATH.*` violations on it.

**Consumes:**

- `AdminPort` (`FSAccess.Purpose`, `FSAccess.Path`)
- `createScreenRead`

**Declined and out of scope:**

- No ledger entries are owned (the inbox was empty).
- DW-1527 and DW-1640 do not touch this story.

**Contended with Epic 16. Every edit is add-only:**

- `Error.cls`, `strings.ts`, EXPERIENCE.md and `_components.scss`;
- the rosters `ReadTool`, `SurfaceCoverage`, `Descriptor`, `Wire*` and `navigation.test.mjs`;
- `ci-throwaway.sh` and `ci.test.mjs`;
- `screens.generated.ts`, which is regenerated rather than hand-merged;
- `Screen/Read.cls`, `Screen/Registry.cls` and `screen-mirror.mjs`, which gain a new branch only.

**Not touched:**

- `Router.cls` and `EndpointCoverage.cls`, because there is no new route;
- `Baseline.cls`;
- `Area.cls`.

## Verification

**Setup.** This runs on slot B:

- Copy each changed `.cls` into `/tmp/ocupilot-b-ci/src` and load it on `ocupilot-b-ci`. The allow-list mutations happen on that throwaway only.
- Run one test class per call.
- Before any browser run, rebuild, then `docker cp ui/dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`. Set `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777` and `OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci`.

**Commands:**

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.<C>`, one call at a time, for each of these classes:
  - `PathPort`
  - `PathPortPrivilege`
  - `SecurityLists`
  - `Descriptor`
  - `ReadTool`
  - `SurfaceCoverage`
  - `Wire`
  - `WireSecurityRead`
  - `WireOAuthRead`
  - `Envelope`

  Expected: 0 failures each, with totals checked against `%UnitTest_Result`.
- `(loop)` `cd ui && node --test --test-concurrency=1 browser/allowed-directories.browser-spec.mjs`. Expected: pass.
- `(loop)` `cd ui && npm run test:tools && npm run test:components`, then `uv run scripts/check-objectscript.py <changed .cls>`, then `bash scripts/lint-docs.sh`. Expected: clean, and `wc -l` on EXPERIENCE.md reads 993.
- `(once, before dev_complete)` Run the full ObjectScript sweep on `ocupilot-b-ci`, one class per call. Then run `cd ui && npm test && npm run build` and `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS`. Expected: green, with a non-zero count. CI runs the full browser suite (Rule 29).

**Planned pinning mutations (Rule 19).** Apply each, observe red, revert byte-identical, and record it as a `mutation: … → …` line:

| AC | Mutation | Expected red |
| --- | --- | --- |
| AC1 | The unrestricted branch returns `[]` | `PathPort`'s unrestricted leg, and the browser spec's fresh leg |
| AC1 | The manager directory is always appended | The restricted legs |
| AC1 | The `path` source admits `rowGet` | `Descriptor` and `screen-mirror.test.mjs` |
| AC2 | The `Gate` call is removed | The `PathPort` gate leg |
| AC2 | `%DB_IRISSYS:READ` is dropped from the descriptor | The registry and the mirror refuse it |
| AC3 | An unlisted `root` renders as an option | `server-path-picker.spec.ts` |
| AC3 | The select renders while refused | `server-path-picker.spec.ts` |
| AC3 | The store reads another route | `allowed-directories.test.mjs` |
| Matrix | The membership check becomes a prefix check | The foreign-root leg |
| Matrix | The `..` check is removed | The `a..b` leg |
| Matrix | `Contains` drops its trailing separator | The `/a/bc/` leg |
| Matrix | The roots are cached in `^||` | The not-cached leg |

**Demonstrated on `ocupilot-b-ci`, each reverted byte-identical (Rule 19):**

- mutation: `PathPort.Roots`' unrestricted branch answers `[]` → `PathPort.TestUnrestrictedAnswersTheManagerDirectoryAlone` and `TestResolveComposesUnderAnAllowedRoot`, and the browser spec's fresh leg
- mutation: `Roots` always appends the manager directory → `PathPort.TestRestrictedAnswersExactlyItsRoots`, `TestRestrictedWithNoRootsAnswersNone`, `TestAForeignRootIsRefused` and `TestUnrestrictedAnswersTheManagerDirectoryAlone`
- mutation: `Registry.ReadProblem` admits `rowGet` on a `path` source → `Descriptor.TestTheAllowedDirectoriesListDeclaresThePathSource`; the same in `screen-mirror.mjs` → `screen-mirror.test.mjs`'s AdminPairCorpus test
- mutation: the `Gate` call removed from `Roots` → `PathPort.TestTheGateRefusesBeforeAnyAdminPortCall`
- mutation: `%DB_IRISSYS:READ` dropped from `AllowedDirectoryList` → `Registry.Validate` and `screen-mirror.mjs --check` both refuse it with the `path` sentence
- mutation: `%Admin_FileSystemAccess:USE` dropped from the descriptor's pairs → `PathPortPrivilege.TestEitherPairMissingIsRefusedNamingIt` (the port refused the principal on `PORT.ACCESSDENIED`)
- mutation: an unlisted `root` rendered as an option → `server-path-picker.spec.ts` "does not select, or offer, a root the store did not read"
- mutation: a select rendered while refused → `server-path-picker.spec.ts` "draws the store's reason and no control"
- mutation: `ALLOWED_DIRECTORIES_ROUTE` pointed at `security/wallet` → `allowed-directories.test.mjs`'s first test
- mutation: membership made a prefix check → `PathPort.TestAForeignRootIsRefused`
- mutation: the literal `..` refusal removed → `PathPort.TestABadNameIsRefused` (`a..b`)
- mutation: `Contains` compares without the trailing separator → `PathPort.TestContainsKeepsTheTrailingSeparator` (`/a/bc/`)
- mutation: `Roots` answers from a `^||` cache → `PathPort.TestTheRootsAreNotCached`, among six
- mutation: `PathPort`'s row absent from `Test/PortGate.cls`'s port roster (the tree before this pass added it) → `PortGate.TestEveryPortDeclaresANamedGate`, red in the full sweep and green once added
- mutation: `Roots` falls back to the manager directory when a restricted purpose lists no root → `allowed-directories.browser-spec.mjs` "Restricted, empty" (the screen's empty state; the leg the Matrix Test Audit added)
- mutation: `Screen.Read`'s `path` branch asks the port for `tMax` rows instead of `tMax + 1` → `PathPort.TestTheScreenReadAndToolAnswerThePortsRows` "cut: and the read says it was cut"
- mutation: `Roots` treats every failed purpose read as absent (its 404 test dropped) → `PathPort.TestAVendorFaultPassesThroughAndARemovedPurposeFallsBack` (the 500 and 403 legs), alone
- mutation: `Roots` drops the manager-directory fallback on the root-path list's 404 → `PathPort.TestAVendorFaultPassesThroughAndARemovedPurposeFallsBack` (the race leg)
- mutation: the `Gate` call removed from `Resolve` → `PathPort.TestTheGateRefusesBeforeAnyAdminPortCall` "a bad name meets the gate before the name rule", for both pairs
- mutation: `parsePathSources` answers `[]` for a missing parameter → `screen-mirror.test.mjs` "the path-source parser reads PathPort.SOURCES"
- mutation (AC4): `.ocu-data-table-header-label` drawn in `--ocu-surface`, bundle rebuilt and redeployed → `allowed-directories.browser-spec.mjs` "AC4 (DW-1337)", fresh `security/allowed-directories|contrast|light` and `|dark` entries
- mutation (AC2, the 200 leg): `PathPort.PAIRS` gains `%Admin_Secure:USE` → `PathPortPrivilege.TestTheDeclaredPairsReadTheScreen`, both states (code review)
- mutation (AC3): the picker's store subscription removed → `server-path-picker.spec.ts` "follows the store from loading to ready after it has drawn", alone (code review)
- mutation: `Resolve` checks the kind before its `Gate` call → `PathPort.TestTheGateRefusesBeforeAnyAdminPortCall` "and so does a kind the port does not know", both pairs (code review)
- mutation: `Resolve`'s kind check removed → `PathPort.TestABadNameIsRefused` "a kind other than the three is a caller fault", alone (code review; re-run on the source kind, run 20, rework 3)
- mutation: `Roots` drops the 404 test on the root-path list read → `PathPort.TestAVendorFaultPassesThroughAndARemovedPurposeFallsBack`, the list-fault leg, alone (code review)
- mutation: `Resolve` drops its `Contains` test → `PathPort.TestResolveRefusesANameThatLeavesItsRoot`, alone (code review); re-run with its source leg, all three legs red, run 9 (rework 3)
- mutation: `STRINGS.allowedDirectoriesLabel` dropped from `oauth.browser-spec.mjs`'s expected side bar → its AC1 test, on the rebuilt and redeployed bundle (rework 1)
- mutation: the same entry dropped from `ssl.browser-spec.mjs`'s AC4 list → its AC4 test (rework 1)
- mutation: the same entry dropped from `security.browser-spec.mjs`'s AC1 list → its AC1 test (rework 1)
- mutation: `maximumWarning` put back at 2004kB → `build-output.test.mjs` DW-371 (2,005,146 bytes over 2,004,000) and `angular-json.test.mjs`'s pinned literal (rework 1)
- mutation (AC1, the seventh entry): `AllowedDirectoryList`'s `sideBarPosition` 7 → 0, `screens.generated.ts` regenerated → `navigation.test.mjs` "a side bar lists only built screens, in side-bar order" and its Security side-bar assertion (code review 2)
- mutation: `Resolve`'s existence test removed → `PathPort.TestAnExistingNameIsRefusedUnlessTheCallerOverwrites` (the four refused legs), alone (rework 2)
- mutation: `Resolve`'s manager-directory test removed → `PathPort.TestAFileDirectlyInTheManagerDirectoryIsRefused` (all six refused legs, both `IRIS.DAT` legs included) and `TestASourceMustBeAnExistingFile` "a source directly in the manager directory is refused", run 24 (rework 3 review)
- mutation: `Resolve` ignores `pOverwrite` → `PathPort.TestAnExistingNameIsRefusedUnlessTheCallerOverwrites` "a caller that overwrites resolves the existing file", alone (rework 2)
- mutation: `Resolve` tests the existing name before the manager directory → `PathPort.TestAFileDirectlyInTheManagerDirectoryIsRefused` "and to a caller that does not, an instance file is refused as the manager directory's", alone, run 363 (rework 2 review)
- mutation: `Resolve`'s directory test on a file's name dropped → `PathPort.TestAnExistingNameIsRefusedUnlessTheCallerOverwrites` "but not a directory standing where the file would go", alone, run 366 (code review 3)
- mutation (a directory is unaffected): the existence test moved out of the file-only branch → "an existing directory is never refused for existing", "and the directory itself is not refused" and `TestResolveComposesUnderAnAllowedRoot` "an empty name is the root itself", run 367 (code review 3)
- mutation (a directory is unaffected): the manager-directory test moved out of the file-only branch → `PathPort.TestAFileDirectlyInTheManagerDirectoryIsRefused` "and the directory itself is not refused", alone, run 368 (code review 3)
- mutation (a source must exist): the source's existence test dropped from `Resolve` → `PathPort.TestASourceMustBeAnExistingFile` "an absent name is refused", "and overwrite does not make it a new file" and its named-field leg, alone, run 2 (rework 3)
- mutation (a source is never a directory): the source's directory test dropped → `PathPort.TestASourceMustBeAnExistingFile` "a directory at the name is refused", alone, run 3 (rework 3)
- mutation (a source never implies an overwrite): a source passed `pOverwrite` resolved as a file → `PathPort.TestASourceMustBeAnExistingFile` "and overwrite does not make it a new file", alone, run 4 (rework 3)
- mutation (the configuration files): `DirectlyInConfigurationDirectory` answers false → `PathPort.TestAnOverwriteNeverReachesTheInstancesOwnFiles`, the legs for `iris.cpf`, `iris.cpf_20260928` and `irisinfo.txt`, its named-field leg and its seam leg, alone, run 5 (rework 3)
- mutation (the configuration directory is read at call time): it is taken as the manager directory's parent instead → `PathPort.TestAnOverwriteNeverReachesTheInstancesOwnFiles` "and refused once the configuration file is read there", alone, run 7 (rework 3)
- mutation (a database file one level down): `DatabaseFileBelowManagerDirectory` answers false → `PathPort.TestAnOverwriteNeverReachesTheInstancesOwnFiles`, all ten `<subdir>/IRIS.DAT` legs, the root-above leg and the ignoring-case assertion, alone, run 29 (rework 3 review)
- mutation (DW-1779): the vendor-directory test dropped from `Resolve` → `PathPort.TestAVendorsDirectoryIsNeverTheManagerDirectory`, its three refused legs, alone, run 8 (rework 3)
- mutation (a source in the manager directory): the manager-directory test limited to a `file` → `PathPort.TestASourceMustBeAnExistingFile` "a source directly in the manager directory is refused, though it exists", alone, run 23 (rework 3 review)
- mutation (a source that exists resolves): the source branch refuses every name → `PathPort.TestASourceMustBeAnExistingFile` "an existing file resolves as a source" and "and the same to a caller passing overwrite", alone, run 26 (rework 3 review)
- mutation (a new file is unaffected): the existence test in front of `InstanceFile` dropped → `PathPort.TestAnOverwriteNeverReachesTheInstancesOwnFiles` "a new name there resolves" and "a new database file name resolves", alone, run 27 (rework 3 review)
- mutation (DW-1779, only a declared vendor write): `pVendorWrites` dropped from the vendor-directory test → `PathPort.TestAVendorsDirectoryIsNeverTheManagerDirectory` "and without the declaration the manager directory resolves as any directory does" and `TestAFileDirectlyInTheManagerDirectoryIsRefused` "and the directory itself is not refused", run 28 (rework 3 review)
- mutation (a database file's name ignoring case): `DatabaseFileBelowManagerDirectory` compares the name with its case → `PathPort.TestAnOverwriteNeverReachesTheInstancesOwnFiles` "a database file's name is matched ignoring case", alone, run 25 (rework 3 review)

## Auto Run Result

Status: done
Blocking condition: none

**Summary (rework iteration 3).** All three orchestrator decisions are done, DW-1779 included, because it turned out small. Each refusal is one `detail.violations[]` entry on the name's field, echoes no path, and fails closed when the directory it reads is empty.

- **DW-1778:** `Resolve` takes a third kind, `source`, a file the consumer reads.
  - It must be an existing file: an absent name or a directory is refused `PATH.NOFILE`.
  - It is never refused for existing and ignores `pOverwrite`.
  - It is still contained, and still refused `PATH.MANAGER` directly in the manager directory.
- **DW-1777:** a caller passing `pOverwrite` is refused `PATH.INSTANCE` for two kinds of existing file:
  - one directly in the configuration file's directory, read at call time through the new `ConfigurationFile()` seam (`%SYS.System.GetCPFFileName()`);
  - an `IRIS.DAT`, ignoring case, one directory below the manager directory.

  A new name is unaffected, and a caller that does not overwrite still gets `PATH.EXISTS`.
- **DW-1779:** a new trailing `pVendorWrites` argument, default 0. With it set, a directory that is the manager directory itself is refused `PATH.MANAGERDIR`. Every other directory is unaffected.

**New error codes**, appended to `Api/Error.cls`:

- `PATHNOFILE` "PATH.NOFILE": "No file of that name exists to read. Name a file that is already there, not a directory."
- `PATHINSTANCE` "PATH.INSTANCE": "That file belongs to the instance itself and cannot be overwritten. Choose another name."
- `PATHMANAGERDIR` "PATH.MANAGERDIR": "The manager directory holds the instance's own files, so these files cannot go in it. Name a subdirectory of it."

**Files changed.**

- `src/OcuPilot/Port/PathPort.cls`: the `source` kind, `pVendorWrites`, the `ConfigurationFile()` seam, and four helpers (`IsManagerDirectory`, `InstanceFile`, `DirectlyInConfigurationDirectory`, `DatabaseFileBelowManagerDirectory`).
- `src/OcuPilot/Api/Error.cls`: the three codes and their reasons, add-only.
- `src/OcuPilot/Test/PathPortFixture.cls`: `UseConfigurationFile`, a seam over the configuration file.
- `src/OcuPilot/Test/PathPort.cls`:
  - three new methods: `TestASourceMustBeAnExistingFile`, `TestAnOverwriteNeverReachesTheInstancesOwnFiles` and `TestAVendorsDirectoryIsNeverTheManagerDirectory`;
  - a source leg in the containment test.
- This spec:
  - the three items checked off, with DW-1779's sentence for AD-21;
  - twelve new `mutation:` lines and three corrected ones;
  - the triage log;
  - one new `deferred:` item.

**Review.** Two layers filed 17 findings: medium 2, low 7, false 8.

- **Four lows patched:**
  - `mutation:` lines were added for a source in the manager directory, an existing source, a new file, and an undeclared vendor write (runs 23 and 26 to 28);
  - a root-above database leg and a lower-case `iris.dat` assertion were added (runs 29 and 25);
  - the rework-2 manager-directory line was corrected (run 24).
- **Two mediums deferred**, with one root cause. `PATH.INSTANCE` covers only what DW-1777 names. So an overwrite is not refused the library databases outside the manager directory (`/usr/irissys/mgr/irislib/IRIS.DAT` on this build), or the journals. Widening the rule is the orchestrator's call.
- **The other 11 rejected.** The triage log gives each reason.

**Follow-up review: false.** This is a follow-up pass, and it patched no `high`. Patched counts: high 0, medium 0, low 4.

**Verification.** All on `ocupilot-b-ci`. It was recreated before this pass, so its run indices restart at 1. Its `src/` copies are md5-identical to the worktree.

- **Targeted, one class per call:**
  - `PathPort` 17/17 on the final tree (run 22);
  - `PathPortPrivilege` 2/2, `PortGate` 4/4, `Descriptor` 58/58 and `Envelope` 15/15;
  - the classes that read `Error.cls`: `AgentViolation` 8/8, `LedgerPairs` 9/9, `ToolEmit` 11/11 and `TurnStore` 11/11 (runs 11 to 18).
- **Mutations:** runs 2 to 9, 20, and 23 to 29.
  - Each was applied to the throwaway's copy alone, with `PathPort` and `PathPortFixture` recompiled.
  - Each was reverted md5-identical, and the worktree's status and diff stat were unchanged.
- **Full ObjectScript sweep, once:** 342 classes, 2,819 tests, 0 failed (runs 30 to 371). It was read back from `%UnitTest_Result`, with no run unlanded. The throwaway carries the merged tree, so the sweep also serves Rule 22's check.
- **Other checks:**
  - smoke 49/49;
  - `npm run test:tools` 1,684/1,684;
  - `check-objectscript` 0 problems and `lint-docs` 0 issues;
  - no non-ASCII bytes in source.

  No client file changed.

**For the runner.**

- AD-21 still needs DW-1779's sentence, which is recorded under the rework item (Rule 20).
- The first `deferred:` item is DW-1777's harvested record, which this pass closes. The second item is new.

**Residual risks.**

- No consumer calls `Resolve` yet. The picker's `kind` is `directory` or `file`, so a source field passes `file`.
- `PATH.MANAGER`'s reason, "A file cannot go directly…", reads oddly for a source. `Error.cls` is add-only.
- `Test/PathPort.cls` is 606 lines.
