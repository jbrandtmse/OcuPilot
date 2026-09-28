---
title: 'Story 18.1: The directory allow-list'
type: 'feature'
created: '2026-09-27'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-18-context.md'
warnings: ['oversized']
deferred: []
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
- **AC4:** Given the new screen, when the DW-1337 structural walk runs in both themes, then no violation outside the baseline appears. The production build stays under its 2004 kB warning.

## Spec Change Log

- 2026-09-27, spec gate (runner): the proposed AD-21 sixth case under Design Notes was written into the spine verbatim, with "every server-path field (Story 18.1 on)" added to AD-21's Binds (Rule 20). The spine is the authority from here; Design Notes keeps the proposal text for the reviewer.

## Review Triage Log

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

## Auto Run Result

Status: ready-for-dev
Blocking condition: none

This was a planning pass only, and the run halted after planning as dispatched. No code was written and nothing was committed.

The vendor endpoints, `%SYS.FileSystemAccess` and `%CSP.Portal.Utils` were read on `ocupilot-b-ci`. The observed shapes were confirmed there with the probe purpose `OcuPilotProbe181`, which was created and then deleted; `%SYS.FileSystemAccess` reads 0 rows afterwards.

The AD-21 sixth-case text under Design Notes is for the runner to write at the spec gate.
