---
title: 'Story 20.2: Productions, listed and controlled'
type: 'feature'
created: '2026-10-07'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md'
warnings: [oversized]
deferred: []
---

<intent-contract>

## Intent

**Problem:** The Interoperability area (Story 20.1) has no screen, and nothing in OcuPilot can list a namespace's productions, business processes, data transformations or business rules, or start, stop, restart, update or recover a production. No port reaches the interoperability runtime, and the vendor's own calls answer a no-op with success.

**Approach:** Add `Port/InteropPort` (proposed AD-62), the one class that calls `Ens.Director` and reads the interoperability configuration, in process, behind its own gate. Four list screens read through it (AD-36 source kind `interop`), and five action-style write tools reach a production through it (AD-51, AD-52). Task 0 re-measures the action vocabulary on `ocupilot-b-ci` before anything is built.

## Boundaries & Constraints

**Always:**

- Task 0 runs first, and its decision rule governs the rest.
- One descriptor per screen and exactly one port. Each read tool is derived from its descriptor. Every write is a server-minted proposal, or a person's row action through the same tool (AD-6, AD-53, AD-55, FR-80).
- The port gates before any vendor call, naming the failed pair (AD-29). It switches namespace by explicit save and restore, and calls no `OcuPilot.*` class while switched (AD-16).
- Each write refuses, by name and before any vendor call, the states in which the vendor would answer a silent success.
- Every write finishes inside its own request (AD-7). Stop, restart and update cap each vendor wait at 15 s.
- Every new screen lives in the `interoperability` area and inherits its `appliesWhen` (AD-44). Each declares its classic page and that page's own `RESOURCE` as its own pair. The API floor is untouched (DW-2140).
- Production, item and class names are untrusted content (AD-11, AD-60).
- Edits to files Epic 18 is changing are add-only, as listed under Design Notes. A new error code goes in `Api/InteropError.cls`.
- Every built screen declares at least three suggested prompts (11.3). The DW-1337 structural gate holds in both themes.

**Never:**

- Never call `Ens.Director.CleanProduction`, any `%Api.InteropEditors.*` class, or HTTP (AD-1).
- No new spawned job, and no `PORT.STARTED` answer.
- No frame, no link-out to `/ui/interop`, no `postMessage`, no vendor storage key, and no copied vendor bundle (20.13, DW-2141).
- No item-level actions (20.3). No production create, delete, import or export.
- No change to `Screen.Gate` `ADMINRESOURCES`/`FloorResources`.
- No hand-edited router or nav list (AD-5). No raw `^Ens.*`, `^rINDEXCLASS` or `^oddDEF` read in product code.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| List productions | `?ns=USER`; the probe production is configured | One row per `Ens.Config.Production`: `Name`, `Status` (the English state word), `LastStartTime`, `LastStopTime`. The tool returns the same rows. | No error expected |
| Code lists | `?ns=HSCUSTOM` | The namespace's transformation and process classes (measured 647 and 68 subclasses, less the excluded base class). Business rules: 0 subclasses measured, so the empty state shows. | Cap 1000; `truncated` reported |
| Start | Probe production `Stopped`, or `Suspended` under the same name | `Running`, change event, read-back | No error expected |
| Start refused | `Running` / `Troubled` / another production current | `INTEROP.PRODUCTION.RUNNING` / `.TROUBLED` / `.OTHER` | 409, no vendor call |
| Stop / restart | `Running`, idle | `Stopped` / `Running` again | No error expected |
| Stop, restart or update while busy | An item's message runs longer than the 15 s cap | The vendor refuses; the production stays `Running` (measured) | 409 `INTEROP.PRODUCTION.BUSY` |
| Not running | stop / restart / update on `Stopped`, `Suspended` or `Troubled` | Refused; the vendor would answer OK and change nothing (measured) | 409 `INTEROP.PRODUCTION.NOTRUNNING` |
| Update | `Running`, one item's setting changed | Only that item's job restarts, and `NeedsUpdate` reads false (measured) | `UPTODATE` 409 when nothing is pending |
| Recover | `Troubled` | `Suspended`, then Start gives `Running` (measured) | `NOTTROUBLED` 409 otherwise |
| Other states | `Unknown`, `NetworkStopped`, `ShardWorkerProhibited` or a mirror-backup state | Every action refused | 409 `INTEROP.PRODUCTION.STATE` |
| Not interop | `?ns=%SYS` route or tool | Refused before any switch | 409 `INTEROP.NAMESPACE` |
| Gate, reads | Caller lacking `%Ens_ProductionConfig:READ`, `%Ens_Code:READ` or READ on the namespace's globals database | Refused, naming that pair | 403 |
| Gate, writes | Caller lacking `%Ens_ProductionRun:USE` or WRITE on that database | Refused by name before any port call, at mint and on a screen action | 403 |
| Unknown production | id not in `Ens.Config.Production` | Mint and action refused | 404 `PORT.NOTFOUND` |
| Runtime lock busy | `GetProductionStatus` cannot take its lock | Fresh read fails | 503 `PORT.UNAVAILABLE` |

</intent-contract>

## Code Map

### Server, what the port and its source kind join

- `src/OcuPilot/Port/DocDbPort.cls` is the template for an in-process port.
  - `PAIRS` at :41.
  - `Invoke` at :226: gate first at :235, then the namespace from `pQuery("namespace")` or `Kernel.Scope.Current()` at :239-254.
  - Switch and restore at :315-345, with rows built after the restore.
  - `Mapped` :465, `Deny` :493, `Refuse` :501, `LogFault` :487 → `Kernel.Fault.LogRaw`.
  - `SnippetForm`/`Snippet` at :551-580.
- `Port/AtelierPort.cls`: `NAMESPACEPATTERN` (:486 use), `DatabaseResources` :677.
- `Kernel/Shell/NamespaceFeatures.cls` `Reports(feature, ns)` (Story 20.1): no switch.
- `Kernel/Shell/Namespaces.cls:84` `GlobalDatabase(ns, .resource, .readOnly)`, as `LogSourcePort.DatabaseReadSpec` (:504) reaches it.
- `Screen/Gate.cls:292` `EvaluateRequired`, `ParsePairSpec`, `WithClassicPages`.
- `Screen/Read.cls` (no Epic 18 edits):
  - `SOURCEDOCDB`/`DocDbPortClass` :271-290
  - the closed vocabulary :390
  - the docdb/sqlactivity branches :505-524
  - the header :26-43
- `Screen/Registry.cls`: source vocabulary :1166-1167; per-kind blocks docdb :1237-1254 and sqlactivity :1259-1276; criteria ports :1636.
- `ui/tools/screen-mirror.mjs`: constants and `READ_SOURCE_PORTS` :953-974; endpoint readers :1036-1072; `readProblem` :1256-1367; criteria :1818. Pinned by the sentence "the eleven sources" at `Test/AdminPairCorpus.cls:58` and `ui/tools/screen-mirror.test.mjs:2720`.
- `Kernel/EntityType.cls:87` `TYPES` (57). `Kernel/EntityRef.cls:59` `IDRULES`: no entry, so a production id is kept exactly.
- `Kernel/Proposal/Prohibited.cls`:
  - `COVEREDTYPES` :250 and the `TYPE<X>` params :253-513
  - the `'=` chain :1153
  - `ReviewedFewOnly` branches :1328-1348
  - `PermittedChangeFields` :942-955
  - `Target` (:4500) reads by id alone, so the port defaults the namespace to the scope.

### Server, the write path

- `Screen/Tool/Write.cls` parameters: `READTYPE` :57, `WRITETYPE` :62, `SENDSBODY` :67, `STATEFIELD` :75, `FINGERPRINTSUBJECT` :97, `PRECONDITIONFIELD` :105, `PORTCLASS` :114, `CLASSICPAGES` :124, `SCREENACTIONS` :167, `PRECONDITIONCODES` :502, `StateDiff` :525.
- `Screen/Tool/LanguageServerStart.cls` is the action template: state words, `StateDiff` :128 refusing with a reason, `PrivilegePairs` :114-119.
- `Screen/Tool/ExplorerDocDbWrite.cls` covers a non-admin port: `PORTCLASS` :20, `NAMESPACEFIELD` :29, `PrivilegePairs` :81-96, and `PortQuery` :101 carrying the proposal's namespace.
- `Screen/Tool/JournalAction.cls`: `CONSEQUENCECODE` :36, `Consequence()` :45. The client reads it in `ui/src/app/core/proposal-view.ts` `consequenceSentence` :372-434.
- `Kernel/Proposal/ReadBack.cls:232`: an action-style write reads `nothingSent`.
- `Kernel/Governance/Baseline.cls` XData `Keys` :17-191. `Test/GovernanceBaseline.cls:21-37`; `DISABLED` :15 is unchanged.
- `Api/DocDbError.cls` is the shape of a sibling error class. The prefix is registered at `Api/Error.cls` `ReasonForToolCode` :1229 and `ReasonForViolation` :1426-1430. `Error.cls` holds 989 parameters.
- Existing reads stay: `Kernel/Shell/SystemInfo.cls:195-231`, Home's production line.

### Tests and rosters

- `Test/PortGate.cls`: `ROSTER` :29, `TestEveryPortEvaluatesItsDeclaredGate` :168.
- `Test/DraftRegistry.cls:140,232`: every write port defines `Snippet`/`SnippetForm`.
- `Test/Prohibited.cls`: :232 (the `COVEREDTYPES` pin), :645, and :342/:446 (a tool with no body admits 0 fields).
- `Test/Descriptor.cls:1750` (entity count 57). `Test/ReadTool.cls:93-94` (283 and the sorted roster).
- `Test/SurfaceCoverage.cls`: screens :57-201, tools :202-371.
- `Test/Navigation.cls` per-area counts (:494, :516); `ui/tools/navigation.test.mjs:139+` (built routes).
- Fixture patterns:
  - `Test/ExplorerProbe.cls:26-33,98-109` (`%Compiler.UDL.TextServices.SetTextFromString` and a compile in a namespace)
  - `Test/DocDbGate.cls:21-24` (arming)
  - `scripts/ci-throwaway.sh` `OCUPILOT_ALLOW_PRINCIPALS` block with its `# classes:` rosters (:340-370), held by `ui/tools/ci.test.mjs`
- `ui/tools/self-protection.test.mjs`: each reason equals a strings value and is quoted in EXPERIENCE.md (DocDb rows :772-793).

### Client

- `ui/src/app/shell/screen-outlet.ts:101-120` maps `list` to `ListPage`, so no page is written.
- `ui/src/app/shell/screen-action-handler.ts`: `SCREEN_ACTION_DESCRIPTORS` :64-111, `WARNING_CONSEQUENCES` :536-562.
- `ui/src/app/core/screen-actions.ts` `ACTION_LABELS` (start and stop at :139-140).
- `ui/src/app/core/strings.ts`: reused keys `explorerColumnModified` "Last modified" :4264, `taskHistoryColumnStatus` "Status", `tableReadOnlyEmptyNext`, "Name". The Fixed-strings bound is at `ui/tools/strings.test.mjs:589-592` (2,800; the count is 2,756).

### EXPERIENCE.md

- The Fixed-strings table runs :252-604. Every row from :590 to :604 is cited, and :645 is the last cited line.
- `:158` is the side-bar order paragraph, which already folds in System Explorer's list.
- DW-2148 targets `:612` (rail) and `:653` (area-tile). `:64` "eight bands (Home plus the seven areas)" has the same root cause.
- `home.page.ts:203,211,234,499` and `home.page.spec.ts:44,403` quote "Seven tiles in daily-use order".
- Epic 18's EXPERIENCE.md hunks sit at :168 and :364 only (measured).

### Vendor (read only)

- `irislib/Ens/Director.cls`:
  - `StartProduction` :14-150, `UpdateProduction` :157-208, `StopProduction` :214-314, `RestartProduction` :320-349
  - `GetProductionStatus` :532-595, `IsProductionRunning` :602, `ProductionNeedsUpdate` :611, `RecoverProduction` :689-724
  - `CleanProduction` :1418 (never called)
  - `GetRunningProductionShutdownTimeout`/`UpdateTimeout` :2011-2019
- `irislib/Ens/Config/Production.cls` `ProductionStatus` :327-361: its `StatusEnum` column; `ProductionStateToText(n,0)` gives English.
- Classic pages, `RESOURCE` as read: `EnsPortal.Productions` (`%Ens_ProductionConfig:READ`), `EnsPortal.Rules`, `EnsPortal.DataTransformations` and `EnsPortal.BusinessProcesses` (OR lists led by `%Ens_Code:READ`).
- `EnsPortal.ProductionConfig`: `startProduction`…`updateProduction` :6087-6174, `hasDBPermissions` :8012.
- `EnsPortal.Application.CheckPrivileges` :234-247.
- The classic menu order is at `EnsPortal.Application.cls:131-135`.

## Tasks & Acceptance

**Execution:**

- [ ] **Task 0: the action vocabulary, first.** Run it on `ocupilot-b-ci` only, through `docker exec` (never MCP, never the dev instance). Use `Test/InteropProbe` once written; until then, use the same probe classes, loaded into USER and removed afterwards.
  - Re-measure every cell of the vocabulary table under Design Notes:
    - the vendor's answer and the resulting state for each action from each state;
    - start's duration, including an item whose `OnInit` waits 25 s;
    - stop, restart and update against an item busy past a 5 s timeout;
    - the caller's `$USERNAME` and `$ROLES` after each call;
    - the least-privileged legs: #940 without `%Ens_ProductionRun:USE`, and `<PROTECT>` on recover without database WRITE.
  - Also measure, with auditing on, whether any vendor event records update and recover (start and stop record `%Ensemble/%Production/StartStop`).
  - Measure that a confirm over HTTP of each action answers exactly one envelope (no vendor device output).
  - Record the table under `## Verification` as `Task 0:` lines.
  - **Decision rule:**
    - Any vocabulary, identity or gate cell that disagrees with the table: HALT `intent gap`, naming the cell, because AD-62's text rests on them.
    - Start measuring above 5 s: HALT `intent gap`, because the bounded-foreground decision rests on it.
    - The audit measurement only fixes which AD-15/AD-53 named-gap lines the runner adds (Design Notes, spine item 6).
- [ ] `src/OcuPilot/Port/InteropPort.cls` (new, `%RegisteredObject`, class methods, AD-62):
  - **Endpoints and parameters:**
    - `Productions`: types `LIST`, `STATE`, `START`, `STOP`, `RESTART`, `UPDATE`, `RECOVER`.
    - `Processes`, `Transforms`, `Rules`: `LIST`.
    - Per-endpoint read pairs: Productions `%Ens_Portal:USE,%Ens_ProductionConfig:READ`; the three code lists `%Ens_Portal:USE,%Ens_Code:READ`.
    - `WRITEPAIRS = "%Ens_ProductionRun:USE"`.
    - `STOPSECONDS = 15`.
    - `LOGSUBSYSTEM`.
    - `GateClass()`/`LogFault()` seams.
  - **`Invoke(endpoint, type, .query, body, .result, .http, .fault)`, in this order:**
    1. Closed endpoint/type check (501 `PORT.NOTIMPLEMENTED`).
    2. The endpoint's pairs, plus `WRITEPAIRS` for a write, through `EvaluateRequired`.
    3. The namespace: `pQuery("namespace")`, else `Kernel.Scope.Current()`, checked against `AtelierPort.#NAMESPACEPATTERN`. `NamespaceFeatures.Reports("interoperability", ns)` false → 409 `INTEROP.NAMESPACE`.
    4. READ (WRITE for a write) on `GlobalDatabase(ns)`'s resource. An unresolved resource → 400 `PORT.VALIDATION`.
    5. Switch, call the vendor into locals, restore (restore first in `Catch`), then build.
  - **`LIST` on Productions:** `Ens.Config.Production:ProductionStatus`. Fields `Name`, `Status` from `ProductionStateToText(StatusEnum,0)` (an `Unrecognized:` token reads `Unknown`), `LastStartTime`, `LastStopTime`.
  - **`LIST` on the code lists:** `%Dictionary.ClassDefinition:SubclassOf` of `Ens.BusinessProcess` less `Ens.BusinessProcessBPL`, `Ens.DataTransform` less `Ens.DataTransformDTL`, and `Ens.Rule.Definition`.
    - `Name` is the document name `<class>.cls`, AD-13's `class` spelling as System Explorer uses it.
    - `Modified` is `%Dictionary.ClassDefinition.TimeChanged` as local `YYYY-MM-DD HH:MM:SS`.
    - The vendor query writes nothing, unlike `EnsPortal.Utils:EnumerateEditableSubclasses`, which kills a shared `^IRIS.Temp` root.
  - **`STATE` for one production `pQuery("id")`:**
    - Absent from `Ens.Config.Production` (`%ExistsId`, exact) → 404 `PORT.NOTFOUND`, unlogged.
    - Otherwise `GetProductionStatus(.current, .state, 2)`. A failed lock → 503 `PORT.UNAVAILABLE`.
    - Answer `{Name, Namespace, State, Current, NeedsUpdate}`:
      - `State` is the target's word: the current production's state when `Name=Current`, else `Stopped`, as the vendor's list reads.
      - `NeedsUpdate` is `ProductionNeedsUpdate(.r,1)` only when the target is current and `Running`.
  - **Writes** call `StartProduction(id)`, `StopProduction(t,0)`, `RestartProduction(t,0)`, `UpdateProduction(u,0)` and `RecoverProduction()`:
    - `t = min(GetRunningProductionShutdownTimeout(), STOPSECONDS)` and `u = min(GetRunningProductionUpdateTimeout(), STOPSECONDS)`.
    - Map `ErrProductionNotQuiescent` and `ErrJobNotStopped` → 409 `INTEROP.PRODUCTION.BUSY`; `ErrProductionAlreadyRunning` → `.RUNNING`; `ErrProductionNotShutdownCleanly` → `.TROUBLED`; `ErrProductionSuspendedMismatch` → `.OTHER`; `<PROTECT>` → 403 `PORT.ACCESSDENIED`.
    - Anything else → 500 `INTERNAL`, with the vendor text logged and never sent (AD-39).
  - **`SnippetForm`/`Snippet`:** an `objectscript` step `zn "<ns>"` and the `Ens.Director` call with its timeout (AD-59).
- [ ] `src/OcuPilot/Api/InteropError.cls` (new, `DocDbError` shape, reasons from Design Notes):
  - `INTEROP.NAMESPACE`
  - `INTEROP.PRODUCTION.RUNNING`, `.OTHER`, `.TROUBLED`, `.NOTRUNNING`, `.UPTODATE`, `.NOTTROUBLED`, `.BUSY`, `.STATE`
  - `ViolationCodes()`, `ReasonFor()`
- [ ] `src/OcuPilot/Api/Error.cls`: add the `INTEROP.` prefix branch to `ReasonForToolCode` and `ReasonForViolation`, add-only beside DocDb's.
- [ ] `src/OcuPilot/Screen/Read.cls`: `SOURCEINTEROP = "interop"`, `InteropPortClass()`, a vocabulary entry, and an `ElseIf` branch as docdb's (`maxRows` cap+1, namespace from the scope). Update the header.
- [ ] `src/OcuPilot/Screen/Registry.cls`: `interop` joins the source vocabulary. Add a per-kind block: endpoint ∈ `InteropPort`'s four, type `LIST`, and no `rowGet`, `forEach`, `query`, `parts` or criteria (as docdb's).
- [ ] `ui/tools/screen-mirror.mjs`: the same rule, plus `interopEndpoints` read from `InteropPort.cls`. Regenerate `ui/src/app/core/screens.generated.ts` whole.
- [ ] `Test/AdminPairCorpus.cls:58` and `ui/tools/screen-mirror.test.mjs:2720`: "the eleven sources" becomes "the twelve sources" (an in-place word edit, needs runner clearance). Add an `interop` leg to `screen-mirror.test.mjs`.
- [ ] `src/OcuPilot/Kernel/EntityType.cls`: append `production` to `TYPES`, with a doc paragraph saying it is namespace-scoped and its id is the production class name, kept exactly. `Test/Descriptor.cls:1750` goes 57 → 58.
- [ ] `src/OcuPilot/Kernel/Proposal/Prohibited.cls`: add `production` to `COVEREDTYPES`, `TYPEPRODUCTION`, the chain clause, and a `ReviewedFewOnly` branch (AD-10 names no effect on a production). Update the pin at `Test/Prohibited.cls:232`.
- [ ] `src/OcuPilot/Screen/Descriptor/InteropProductionList.cls` (new):

  | Key | Value |
  |---|---|
  | `route` | `interoperability/productions` |
  | `area` | `interoperability` |
  | `sideBarPosition` | 1 |
  | `archetype` | `list` |
  | `privileges` | `[%Ens_Portal:USE, %Ens_ProductionConfig:READ]` |
  | `ownPrivileges` | `[%Ens_ProductionConfig:READ]` |
  | `classicPage` | `EnsPortal.Productions` |
  | `entityType` | `production` |
  | `scope` | `namespace` |
  | `id` | single |
  | read source | `{port "interop", endpoint "Productions", type "LIST"}` |
  | fields | `Name, Status, LastStartTime, LastStopTime`, sort `Name` |
  | table | Name (reused), Status (reused, kind `status`), "Last started", "Last stopped" |
  | `rowActions` | `start, stop, restart, update, recover` |
  | `context.fields` | the four fields |
  | `emptyStateKey` / `emptyAgentKey` | new |
  | `suggestedPrompts` | three, `promptGroupTroubleshooting` |
  | `toolIdentifier` | `interop.productions` |
  | `refreshes` | `false` |

- [ ] `src/OcuPilot/Screen/Descriptor/InteropProcessList.cls`, `InteropTransformList.cls`, `InteropRuleList.cls` (new):

  | Key | Processes | Transforms | Rules |
  |---|---|---|---|
  | route | `interoperability/processes` | `interoperability/transforms` | `interoperability/rules` |
  | `sideBarPosition` | 2 | 3 | 4 |
  | `classicPage` | `EnsPortal.BusinessProcesses` | `EnsPortal.DataTransformations` | `EnsPortal.Rules` |
  | `toolIdentifier` | `interop.processes` | `interop.transforms` | `interop.rules` |

  - All three:
    - `privileges` `[%Ens_Portal:USE, %Ens_Code:READ]`, `ownPrivileges` `[%Ens_Code:READ]`
    - `entityType` `class`, `scope` `namespace`
    - fields `Name, Modified`; columns Name and "Last modified" (both reused)
    - `emptyNextKey` `tableReadOnlyEmptyNext`; no actions
    - three `promptGroupGettingStarted` prompts each
  - Side-bar order follows the classic List menu: Productions, then the classic order.
- [ ] `src/OcuPilot/Screen/Tool/InteropProductionAction.cls` (new abstract base, as `LanguageServerStart` plus `ExplorerDocDbWrite`'s namespace handling):
  - `DESCRIPTORCLASS` InteropProductionList, `PORTCLASS` `OcuPilot.Port.InteropPort`, `READTYPE "STATE"`, `SENDSBODY 0`, `DESTRUCTIVE 0`.
  - `CLASSICPAGES = "EnsPortal.ProductionConfig,EnsPortal.Dialog.UpdateProduction,EnsPortal.StartStopFrame"`, spellings measured through `NormalizePage`.
  - `NAMESPACEFIELD`/`PortQuery`, so confirm and read-back reach the proposal's namespace.
  - `PrivilegePairs`: the screen's pairs + `%Ens_ProductionRun:USE` + `<GlobalDatabase(ns) resource>:WRITE` + `WithClassicPages`, each refused by name before any port call.
  - `SettableFields` empty. `StateDiff` refuses with the tool's precondition code, otherwise one row `{State, before, after}`. A state outside Running, Stopped, Suspended and Troubled refuses every action `INTEROP.PRODUCTION.STATE`.
- [ ] `src/OcuPilot/Screen/Tool/InteropProductionStart.cls`, `…Stop`, `…Restart`, `…Update`, `…Recover` (new):

  | Tool | `SCREENACTIONS` and `WRITETYPE` | `FINGERPRINTSUBJECT` | Refuses unless | After | `CONSEQUENCECODE` |
  |---|---|---|---|---|---|
  | `interop.productions.start` | `start`, `START` | `State,Current` | `Stopped`/`Suspended`, with `Current` empty or itself | `Running` | none |
  | `interop.productions.stop` | `stop`, `STOP` | `State` | `Running` | `Stopped` | `INTEROP.STOP` |
  | `interop.productions.restart` | `restart`, `RESTART` | `State` | `Running` | `Running` | `INTEROP.RESTART` |
  | `interop.productions.update` | `update`, `UPDATE` | `State,NeedsUpdate` | `Running` and `NeedsUpdate` | `Running` | `INTEROP.UPDATE` |
  | `interop.productions.recover` | `recover`, `RECOVER` | `State` | `Troubled` | `Suspended` | `INTEROP.RECOVER` |

  - `DESCRIPTION` states the precondition and, for stop/restart/update, the 15 s wait. Recover's carries the recover-before-clean sentence.
  - Doc comments name AD-15/AD-53's named gap where Task 0 measures no vendor event.
- [ ] `src/OcuPilot/Kernel/Governance/Baseline.cls`: append the five keys `true` (none destructive, Design Notes).
- [ ] `src/OcuPilot/Test/InteropProbe.cls` (new helper, no test methods):
  - **Creates** in USER, through `SetTextFromString` and compile, `OcuPilotProbe.Interop.Production` with items `OcuPilotProbeOp` (a `HangSeconds` setting) and `OcuPilotProbeSvc`, and a second production `OcuPilotProbe.Interop.Other`.
  - **Helpers:**
    - `Send()` queues one message to the op.
    - `SetHang(n)` changes the op's setting.
    - `MakeTroubled()` starts the production, terminates its `_Ensemble` jobs in USER and kills `^%SYS("Ensemble","RunningNamespace","USER")`. Measured: this reads `Troubled`.
    - `Remove()` force-stops, recovers or resumes-then-stops its own production as needed. It then deletes its config rows, classes and `^Ens.Configuration("csp","Activity",<own>)`, and `"LastProduction"` when it names its own. It purges the message headers, bodies and event-log rows whose config names begin `OcuPilotProbe`, and nothing else.
  - **Refusal:** each entry refuses, touching nothing, when USER's current production is not one of its own.
- [ ] `src/OcuPilot/Test/InteropControl.cls` (new; armed by `OCUPILOT_ALLOW_PRINCIPALS`, one class per run; the header says it compiles and runs a probe production in USER):
  - **Writes as `_SYSTEM`:** every matrix write row through the mint and confirm path and through the screen action. It checks state after, `readBack`, the change event, the ledger row and the marker.
  - **Busy:** stop, restart and update while the op hangs past a seam-shortened `STOPSECONDS`, giving `BUSY` and still `Running`.
  - **Namespace:** a proposal minted with scope USER and confirmed from an HSCUSTOM-scoped request acts on USER.
  - **Snippets:** each tool's snippet.
- [ ] `src/OcuPilot/Test/InteropGate.cls` (new; armed by `OCUPILOT_ALLOW_PRINCIPALS`): probe principals, each missing one pair, removed in `OnAfterAllTests`.
  - **Reads:** `%Ens_ProductionConfig:READ`, `%Ens_Code:READ`, `%DB_USER:READ`.
  - **Writes:** `%Ens_ProductionRun:USE`, `%DB_USER:WRITE`.
  - Each is refused naming its pair, through the port, the screen route and the tool, before any vendor call. Route legs also hold `%Development:USE` for the floor.
  - A holder of the full set reads every list and starts and stops the probe production.
- [ ] `src/OcuPilot/Test/InteropDescriptor.cls` (new, stateless):
  - the four declarations (pairs, own pairs, classic pages, area, entity types, prompts);
  - the registry's `interop` rules on synthetic bad sources;
  - the code lists read through the port in HSCUSTOM (counts ≥ 1 for processes and transforms, the base class absent, `Name` ending `.cls`);
  - `INTEROP.NAMESPACE` for `%SYS`;
  - every `InteropError` code resolving through `ReasonFor`.
- [ ] `src/OcuPilot/Test/InteropGateSeam.cls` (new seam), plus rows in `Test/PortGate.cls` (`ROSTER` and a driven refusal).
- [ ] Rosters, add-only:
  - `Test/ReadTool.cls:93-94`: 283 → 292, plus the nine names.
  - `Test/SurfaceCoverage.cls`: four screen rows and five tool rows.
  - `Test/Navigation.cls`: an interoperability count of 4.
  - `ui/tools/navigation.test.mjs`: the four routes.
  - `scripts/ci-throwaway.sh`: a `# classes: InteropControl, InteropGate` line with its sentence under `OCUPILOT_ALLOW_PRINCIPALS`.
- [ ] Client:
  - `ui/src/app/core/screen-actions.ts`: labels for `restart`, `update`, `recover`.
  - `ui/src/app/shell/screen-action-handler.ts`: add `InteropProductionList` to `SCREEN_ACTION_DESCRIPTORS`, and `WARNING_CONSEQUENCES` for stop, restart, update and recover. Start is sent at once, as Language servers' is.
  - `ui/src/app/core/proposal-view.ts`: map the four `INTEROP.*` consequence codes to the same four strings keys.
  - `ui/src/app/core/strings.ts`: add-only keys, each citing `EXPERIENCE.md:604`.
  - A tools-test leg (new `ui/tools/interop.test.mjs`) pins `STOPSECONDS` equal to the "15" in the stop, restart, update and busy sentences.
- [ ] `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md`, edited in place with no line inserted:
  - `:604`: the String cell gains every new literal, and the Where cell appends Story 20.2's description `[ADDED <date> - Story 20.2]`.
  - `:158`: append "Interoperability (Stage 4, Story 20.2): Productions · Business processes · Data transformations · Business rules."
  - Then `cd ui && npm run test:tools`.
  - Fixed strings are budgeted at 39, giving 2,795 ≤ 2,800. If the final count exceeds 2,800, raise the bound to 2,850 with a one-line comment naming Story 20.2, and report it.
- [ ] `ui/browser/interop-productions.browser-spec.mjs` (new; `before` and `after` call `InteropProbe` through `docker exec` on `OCUPILOT_BROWSER_CONTAINER`):
  - `?ns=USER`: the side bar lists the four screens in order, and Productions shows the probe row.
  - Start through the row action, then `Running` after the re-fetch. Stop through its warning dialog, then `Stopped`.
  - The command box offers "Productions" in USER and not in `%SYS`, and the locator names Interoperability on the route (20.1's pending legs).
  - Business processes in HSCUSTOM lists rows.
  - Add the file to `ui/tools/side-bar-pins.test.mjs` `SIDE_BAR_SPECS` if it reads side-bar labels.
- [ ] **[Runner clearance] DW-2148:** a sanctioned exception to "no in-place edit", since Epic 18 has not merged. Do it only if the spec gate records the clearance in the Spec Change Log; otherwise leave DW-2148 routed and say so in the Auto Run Result.
  - Correct EXPERIENCE.md `:64`, `:612` and `:653` in place, with no line inserted: eleven rail items by namespace (9 to 11 drawn), and one tile per applying area (seven to nine).
  - Move the quoted anchor in `home.page.ts:203,211,234,499` and `home.page.spec.ts:44,403` to the new wording.

**Acceptance Criteria:**

- **AC0 (Task 0):** Given the vocabulary was never read, when this story is picked up, then Task 0's re-measurement on `ocupilot-b-ci` is recorded under Verification before any other task, under its decision rule.
- **AC1 (lists, integration):** Given the throwaway with the probe production in USER and IRIS for Health's classes in HSCUSTOM, when the Productions, Business processes, Data transformations and Business rules screens load, then each reads through `InteropPort`, and its read tool returns the same rows (AD-36). Productions shows the probe production and its state; the code lists show the namespace's classes.
- **AC2 (writes):** Given start, stop, restart, update and recover, when each is proposed by the agent and confirmed, or pressed on the Productions row, then it is a confirmed write through `InteropPort` that leaves the production in the matrix's state. Recover's proposal card and dialog carry the recover-before-clean sentence; stop's, restart's and update's carry the 15 s wait.
- **AC3 (silent no-ops):** Given a production not in the state an action needs, when that action is proposed or pressed, then it is refused by its named code before any vendor call, where the vendor would have answered success.
- **AC4 (gates):** Given a principal lacking one declared pair, when it opens a screen, calls its tool or presses a row action, then it is refused naming that pair before any vendor call.
- **AC5 (category, from 20.1):** Given an interoperability namespace, when the shell renders, then the side bar, command box and locator offer the four screens; given `%SYS`, then none of them is offered.

## Spec Change Log

- 2026-10-07, runner spec gate: AD-62 claimed and written, with this story's AD-13 (`production` id), AD-36 (source kind `interop`), AD-44 (`CLASSICPAGES`) and AD-8 pair particulars folded into AD-62's own Rule rather than amending those ADs (Epic 18 amends AD-13 concurrently); AD-8 gained the vendor-escalation sentence; `InteropPort` joined the paradigm's port list, AD-29's Binds and the capability map. AD-15/AD-53 named gaps for update and recover are written at ship if Task 0 measures no vendor event. The count-word bumps (`AdminPairCorpus.cls:58`, `screen-mirror.test.mjs:2720`) are add-only count edits and cleared; DW-2148's in-place EXPERIENCE.md and `home.page.ts` edits await the orchestrator's clearance, and the implement prompt says whether they run.

## Review Triage Log

## Design Notes

**Governing ADs:**

- AD-1, AD-7 (writes in the request), AD-8 (pairs; the vendor's escalation, spine item 2), AD-10, AD-11 and AD-60
- AD-13 (`production` kept exactly; `class` ids as `.cls`), AD-14, AD-15, AD-16, AD-22, AD-29, AD-34
- AD-36 (source kind `interop`), AD-39, AD-44 (classic pages and `appliesWhen`)
- AD-51, AD-52, AD-53, AD-55, AD-58, AD-59, and AD-62 (proposed)

**Vocabulary, measured on `ocupilot-b-ci` (USER, probe production, 2026-10-07):**

| From state | start | stop | restart | update | recover |
|---|---|---|---|---|---|
| Stopped | Running, 0.01-0.05 s; 0.01 s also with a 25 s `OnInit` | OK, no-op | OK, no-op | OK, no-op | OK, no-op |
| Running, idle | `ErrProductionAlreadyRunning` | Stopped, 0.00 s | Running, 0.01 s | only changed items' jobs restarted, 0.00 s; no-op when up to date | no-op (read in source: acts only on Troubled) |
| Running, item busy | — | `ErrProductionNotQuiescent` at T (5.04 s), still Running | the same (5.09 s) | `ErrJobNotStopped` at T (4.02 s), still needs update | — |
| Suspended | Running when the same name; another name `ErrProductionSuspendedMismatch` | OK, no-op | — | — | OK, no-op |
| Troubled | `ErrProductionNotShutdownCleanly` | OK, no-op, still Troubled | OK, no-op | OK, no-op | Suspended, 0.00 s |

Also measured:

- **States:** 0 Unknown, 1 Running, 2 Stopped, 3 Suspended, 4 Troubled, 5 NetworkStopped, 6 ShardWorkerProhibited, and negative values for mirror backups.
- **Production timeouts:** the shutdown timeout defaults to 120 s and the update timeout to 10 s.
- **The vendor's own privilege checks:**
  - Reads check nothing: a principal holding only `%DB_USER:R` read the status, the production list and the rule list.
  - Start, stop and restart answer #940 without `%Ens_ProductionRun:USE`.
  - Update accepts `%Ens_ConfigItemRun:USE` alone.
  - Start and stop succeed with `%DB_USER:R` only (inference: `_Ensemble` does the writes).
  - Recover makes no check, and raises `<PROTECT>` on `^Ens.Suspended` without `%DB_USER:W`.
- **Identity:** `$USERNAME` and `$ROLES` read the same after every call.
- **Audit:** `%Ensemble/%Production/StartStop` is enabled. Whether update and recover are audited is unmeasured (inference: no audit call in their source).
- **The v7 API:** `UpdateProduction` (`/productions/{class}/{host}/{action}`) is copy or delete a host. `/productions/production/state` takes `start|stop|recover|force|updateforce`, has no update and no restart, and answers an unknown state with `Success`. It requires both run resources, and its v1-v4 implementation is `[Hidden]`. That is why `Ens.Director` backs the port.

**Pairs and named limits:**

- The classic `RESOURCE` for rules, transformations and processes is an OR list, which a pair set cannot express. `%Ens_Code:READ` is held by every shipped role that reaches these screens (`%EnsRole_WebDeveloper`, `_Developer`, `_Administrator`; measured). A holder of only `%Ens_Rules`/`%Ens_RoutingRules`/`%Ens_BusinessRules`/`%Ens_DTL`/`%Ens_BPL` (`%EnsRole_RulesDeveloper` alone) is refused.
- A `%Ens_ConfigItemRun`-only holder is refused Update.
- The database pair is the namespace's globals database. A namespace mapping `^Ens.Config*` elsewhere is gated on that database (inference).
- These are narrower audiences, as AD-8 accepts for Stories 18.15, 18.16 and 19.17. The floor itself is unchanged (DW-2140).

**Destructive (AD-22): none of the five.**

- Start, stop, restart and update delete, discard and overwrite nothing, and each is undone by its inverse.
- Recover marks private-queue messages Discarded and in-flight synchronous messages Suspended, and deletes no message (`Director.cls:411-441`). The messages stay in the store (inference: the message viewer, 20.9, resends them).
- So all five keys enter the baseline enabled, and the screen uses warning dialogs, not typed names.
- Clean, the destructive one, is never called.

**Long writes:** bounded foreground (AD-7), not AD-26.

- Start returns once its jobs are launched.
- Each stop, restart or update wait phase is capped at 15 s. A stop's worst case is quiesce plus stop-all, 30 s, inside AD-42's bound of 50 s at the gateway's measured 60 s.
- A busy production is refused and left unchanged (measured).
- So no fifth spawn site (`JOB_ALLOWED`) is added and no `PORT.STARTED` is answered.
- Named limit: an operator who lowers `Server_Response_Timeout` below about 35 s can see a gateway timeout on a busy stop (inference).

**Strings (39 new literals):**

- Titles: "Productions", "Business processes", "Data transformations", "Business rules".
- Columns: "Last started", "Last stopped".
- Empty states: "No productions in this namespace.", "No business processes in this namespace.", "No data transformations in this namespace.", "No business rules in this namespace.", "Ask the agent why no production is listed here."
- Prompts:
  - Productions: "Is any production here troubled or stopped?", "When did each production here last start and stop?", "Which production is running, and does it need an update?"
  - Each code list: "Which <kind> does this namespace hold?", "Which <kind> changed most recently?", "How many <kind> does this namespace hold?", written out per kind (nine literals).
- Actions: "Restart", "Update", "Recover".
- Warnings, which are also the card consequences:
  - stop: "Stopping this production waits up to 15 seconds for its work in progress to finish. If it takes longer, nothing is stopped."
  - restart: "Restarting this production stops it and starts it again. If its work in progress takes longer than 15 seconds to finish, nothing is stopped."
  - update: "Updating this production restarts only the items whose settings changed, and starts or stops the items enabled or disabled since it started. If an item takes longer than 15 seconds to finish its work, the update is refused and the production keeps running."
  - recover: "Recover is the first response to a troubled production: it returns it to Suspended so it can be started again, marking messages it cannot keep queued as Discarded or Suspended and deleting none. Clean, which deletes queued messages, is a last resort OcuPilot does not offer."
- Reasons:
  - `NAMESPACE`: "This namespace does not run interoperability productions."
  - `RUNNING`: "This production is already running."
  - `OTHER`: "Another production is running, suspended or troubled in this namespace, and a namespace runs one production at a time."
  - `TROUBLED`: "This production did not shut down cleanly. Recover it first; once it reads Suspended it can be started."
  - `NOTRUNNING`: "This production is not running."
  - `UPTODATE`: "This production is up to date, so there is nothing to update."
  - `NOTTROUBLED`: "Only a troubled production can be recovered."
  - `BUSY`: "The production's work in progress did not finish within 15 seconds, so it was left as it was."
  - `STATE`: "This production's state does not allow that action here."

**Spine decisions for the runner (Rule 20; the runner claims AD-62):**

1. **Add AD-62:**

   ### AD-62 — Interoperability is reached through one port that calls the vendor's production classes in process, behind its own gate

   - **Binds:** Stage 4 (Epic 20): every Interoperability screen, read tool and write tool; `Port/InteropPort`; AD-1, AD-7, AD-8, AD-16, AD-29, AD-36, AD-44, AD-51, AD-52, AD-58, AD-59
   - **Prevents:** a production started or stopped down a path with no gate of OcuPilot's, because the vendor's reads check nothing; a vendor no-op answered as success; a request held past the gateway by a production that will not quiesce; and the `[Hidden]` `%Api.InteropEditors` implementation becoming a second experimental dependency beside AD-27's
   - **Rule:** `Port/InteropPort` is the only class that starts, stops, restarts, updates or recovers a production, and the only one that reads interoperability configuration for a declared read (source kind `interop`).
     - **What it calls.** It calls the documented classes the classic pages call: `Ens.Director`, `Ens.Config.Production:ProductionStatus` and `%Dictionary.ClassDefinition:SubclassOf`. It calls them in the caller's process, as the signed-in user, and never calls `%Api.InteropEditors.*`. The v7 state route carries no update or restart and answers an unknown state with success, and its implementation is `[Hidden]` (read at Story 20.2's plan).
     - **The gate comes first.** It checks the endpoint's pairs, then READ on the namespace's globals database (WRITE for a write), with `%Ens_ProductionRun:USE` added for a write. These are the classic `EnsPortal.Productions` and `EnsPortal.ProductionConfig` checks. A refusal names the failed pair.
     - **The namespace** must report interoperability. The port switches by explicit save and restore, and calls no `OcuPilot.*` class while switched.
     - **The vendor escalates, OcuPilot does not.** `%SYS.Ensemble` checks the caller's run resource and then performs start, stop, restart and update as `_Ensemble`, and the production's jobs run as `_Ensemble`, as from the classic page. OcuPilot adds no elevation, and the caller's `$USERNAME` and `$ROLES` read the same afterwards (measured). Recover runs as the caller.
     - **Each write is action-style** over a port-composed `STATE` read. It refuses whatever the vendor would answer as a silent success: stop, restart or update when not running; update when up to date; recover when not troubled; start when the production is running or troubled, or when another production is current.
     - **Each write runs in its own request.** Start returns once its jobs are launched. Stop, restart and update pass the production's own timeout capped at 15 s. A production that does not quiesce in time is refused by the vendor and left as it was (`INTEROP.PRODUCTION.BUSY`; measured on `ocupilot-b-ci`, 2026-10-07).
     - **Clean is never called.** Recover is the response to a troubled production, and its card says so.
     - **Named limits:** the OR-list classic resources answered with `%Ens_Code:READ`, the Update audience, and a restart whose start fails leaves the production stopped, which its read-back reports.
     - Home's production line, category gating and the event log keep their own existing reads.
2. **Amend AD-8:** "A vendor method that runs its operation under the vendor's own service account after checking the caller's privilege (`%SYS.Ensemble`'s production control, AD-62) is the vendor's privilege model, not an OcuPilot elevation." Also add a Story 20.2 paragraph: the five tools declare `%Ens_ProductionRun:USE` and WRITE on the namespace's globals database beyond the screen's set, each refused by name before any port call, with the measured evidence above.
3. **Port lists:** add `InteropPort` (`Ens.Director` and interoperability configuration, in process, Stage 4, Story 20.2, AD-62) to the Design Paradigm's port list and table, and to AD-29's Binds.
4. **The Capability map's Stage 4 row:** "`Port/InteropPort`, new slice, embedded vendor editors | AD-5, AD-44 (`appliesWhen`, Story 20.1), AD-62, staged".
5. **AD-36, AD-13 and AD-44:**
   - AD-36: a declared read may name the interoperability port (source kind `interop`, `LIST` on four endpoints, no criteria, detail call or parts).
   - AD-13: a `production` id is the production class name, kept exactly.
   - AD-44 `CLASSICPAGES`: the five tools declare `EnsPortal.ProductionConfig`, `EnsPortal.Dialog.UpdateProduction` and `EnsPortal.StartStopFrame`.
6. **AD-15 and AD-53 named gaps:** add update and recover if Task 0 measures no vendor event for them.

**Integration ACs, Consumed-by and Consumes:**

- In-story consumers: the four list pages and their read tools (AC1), the confirm path and the screen action route (AC2), and 20.1's command box and locator (AC5).
- Consumed-by:
  - 20.3: items, through `InteropPort` and the `production` entity type, with item rows under a production.
  - 20.4: per-host tabs, the monitor, queues and jobs.
  - 20.5 and 20.6: lookup tables and testing.
  - 20.9: messages, and resending what recover marked.
  - 20.12: the recover-stuck-production workflow, through `interop.productions.recover` and `.start`, and Investigate's reads.
- Consumes:
  - Story 20.1's area, `appliesWhen` and `NamespaceFeatures`.
  - Story 19.17's in-process port pattern.
  - Story 19.2's probe-class pattern (`Test/ExplorerProbe`).

**Ledger (Rule 17):** DW-2148 is planned as the runner-gated task, because Epic 18 has not merged. Measured: Epic 18's EXPERIENCE.md hunks are at :168 and :364, so the edits at :64, :612 and :653 merge line-clean.

**Contended files (Rule 11), checked against `.worktrees/epic-18` on 2026-10-07:**

- **Add-only edits:**
  - Count bumps: `EntityType.cls` and `Test/Descriptor.cls` (Epic 18 also 57 → 58; the union is 59), `Test/ReadTool.cls` (Epic 18 283 → 286; the union is 295).
  - Roster and line additions: `Test/SurfaceCoverage.cls`, `Prohibited.cls` with the `Test/Prohibited.cls:232` string (the union of entries), `Baseline.cls`, `strings.ts`, `side-bar-pins.test.mjs`, EXPERIENCE.md `:158`/`:604` (no Epic 18 hunk there).
  - `Api/Error.cls`: two prefix lines beside Epic 18's `WEBAUTH` lines (:1228, :1430; the second epic to merge takes the union).
  - `screens.generated.ts`: regenerated whole.
- **Not contended:** `Screen/Read.cls`, `Screen/Registry.cls` and `screen-mirror.mjs` have no Epic 18 edits.
- **Need the runner's clearance:**
  - the word "eleven" → "twelve" in `Test/AdminPairCorpus.cls:58` and `screen-mirror.test.mjs:2720` (Epic 18 edits that test file elsewhere);
  - DW-2148's in-place edits;
  - a bound move in `strings.test.mjs`, if one is needed.
- **No edit:** `angular.json` (budget 3165kB; stop and ask above 3800 kB) and the spine.

## Verification

**Setup (slot B):**

- Load changed classes into `ocupilot-b-ci` only, never through the MCP loader, which reaches the dev instance.
- Every production- or principal-creating step runs on `ocupilot-b-ci`.
- Run one ObjectScript class per call, and send the next only once the previous run has landed in `%UnitTest_Result`. Never re-submit after a timeout.
- Before any browser run:
  - `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`
  - export `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777` and `OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci`.

**Commands:**

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.<C>`, one class per call. Expected: 0 failures, with totals checked in `%UnitTest_Result`. Classes:
  - `InteropDescriptor`, `InteropControl`, `InteropGate`
  - `PortGate`, `DraftRegistry`, `Prohibited`, `Descriptor`, `ReadTool`, `SurfaceCoverage`, `GovernanceBaseline`
  - `Navigation`, `Wire`, `WireAreaAnyScreen`, `DeveloperFloor`, `NamespaceFeatures`, `AdminPairCorpus`
- `(loop)` `cd ui && node --test --test-concurrency=1 browser/interop-productions.browser-spec.mjs browser/namespace-categories.browser-spec.mjs browser/rail-icons.browser-spec.mjs browser/a11y-structural-invariants.browser-spec.mjs`. Expected: pass, with the DW-1337 gate holding in both themes.
- `(loop)` Expected clean:
  - `cd ui && npm run test:tools && npm run test:components`
  - `uv run scripts/check-objectscript.py <changed .cls>`
  - `bash scripts/lint-docs.sh`
- `(once, before dev_complete)` The full ObjectScript sweep: `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci`, one class at a time. Then:
  - `cd ui && npm test && npm run build`: under `maximumWarning` 3165kB.
  - `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS`
- `(CI)` The full browser suite runs only in CI's shards (Rule 29).

**Planned pinning mutations (Rule 19).** Apply each on the throwaway, observe red, then revert byte-identical.

| AC | Mutation | Expected red |
|---|---|---|
| AC1 | Make the `interop` branch in `Read.cls` read Productions for every endpoint | `InteropDescriptor`'s code-list legs; browser Business processes |
| AC1, tool | Drop `Status` from the Productions fields | `InteropDescriptor`; the browser row |
| AC2 | Make `StopProduction`'s call `StartProduction` | `InteropControl` stop leg |
| AC2, card | Drop recover's `Consequence()` | `InteropControl` card leg; `proposal-view` spec |
| AC3 | Remove the `NOTRUNNING` refusal from stop's `StateDiff` | `InteropControl` (the vendor answers OK, so the state is unchanged and the refusal is missing) |
| AC3, busy | Map `ErrProductionNotQuiescent` to OK | `InteropControl` busy leg |
| AC4 | Drop `%Ens_ProductionRun:USE` from `PrivilegePairs` | `InteropGate` write leg |
| AC4, reads | Drop the globals-database pair from the port | `InteropGate` database leg; `PortGate` |
| AC5 | Make `screensThatApply` return everything | The browser `%SYS` command-box leg |

## Auto Run Result

Status: ready-for-dev
Blocking condition: none

Summary: planned and HALTed after planning.

Measured on `ocupilot-b-ci` during planning (USER, a probe production, and seven probe principals, all removed afterwards):

- the vocabulary table;
- the vendor's privilege checks;
- identity after each call;
- the classic page spellings.

The runner acts at the spec gate on:

- claiming AD-62 and the spine items under Design Notes (AD-8's vendor-escalation sentence among them);
- clearing or deferring the runner-gated DW-2148 task;
- clearing the in-place word edit "eleven" to "twelve" sources.
