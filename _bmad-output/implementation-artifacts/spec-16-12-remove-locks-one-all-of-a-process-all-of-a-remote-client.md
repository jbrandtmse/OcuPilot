---
title: 'Story 16.12: Remove locks - one, all of a process, all of a remote client'
type: 'feature'
created: '2026-09-30'
status: 'in-progress'
baseline_revision: '7e8cd3ceab5c88138aeda1f1f664f391079ab7bf'
baseline_commit: '7e8cd3ceab5c88138aeda1f1f664f391079ab7bf'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-16-context.md'
warnings: ['oversized', 'multiple-goals']
deferred: []
---

<intent-contract>

## Intent

**Problem:** The Locks list (Story 6.10) shows every lock on the instance but offers no way to clear one. Clearing a stuck lock still means leaving for the classic Manage Locks page. Separately, a row whose owner is a remote client links its Process ID cell to Process details, which then says the process does not exist (DW-1074).

**Approach:**

- Add three action-style write tools. They remove this lock, every lock of the owning process, or every lock of the remote client. The screen and the agent both reach them (AD-53).
- A new `Port/LockPort` sends the vendor's own `Lock` `DELETE`, one per lock, with the vendor's in-transaction check on. That check's 409 is the signal for the warning (DW-1073).
- The Locks row menu opens one "Remove locks" dialog. It offers the three scopes, and it shows the warning when the removal is refused because the owner is in a transaction.
- `rowTarget` gains an optional `unless` field, which withholds the link on a remote-owner row.

## Boundaries & Constraints

**Always:**

- **The three tools.** Each has endpoint `Lock`, `PORTCLASS` `OcuPilot.Port.LockPort`, `SENDSBODY` 0, `DESTRUCTIVE` 1 and `CHANGEACTION` `deleted`. Each takes id argument `DeleteID` and id parameter `id`, and is its own governance key, added **enabled** to `Kernel/Governance/Baseline.cls`:

  | Tool | Screen action | `READTYPE` / `WRITETYPE` | Acts on |
  |---|---|---|---|
  | `osmgmt.locks.remove` | `remove` | `ROW` / `REMOVE` | the one row whose `DeleteID` is the id |
  | `osmgmt.locks.removeprocess` | `removeprocess` | `OWNER` / `REMOVEOWNER` | every listed lock whose owner (the id's third comma piece, e.g. `P905`) is the row's, for a local owner |
  | `osmgmt.locks.removeclient` | `removeclient` | `OWNER` / `REMOVEOWNER` | the same, for a remote owner (`C…`) |

- **`LockPort` extends `AdminPort` and reaches the vendor only through `Lock` `LIST` and `DELETE`.** Its composed types are:
  - **`ROW`** answers `{DeleteID, Pid, Owner, RemoteOwner, Reference, ModeCount, Directory, System, RemoveInTransaction: null}`. It reads LIST with `filter` = the id and matches `DeleteID` exactly. No match is a 404.
  - **`OWNER`** answers `{DeleteID, Pid, Owner, RemoteOwner, DeleteIDs, Locks: [{DeleteID, Reference, ModeCount, Directory}], RemoveInTransaction: null}`. It reads LIST with `filter` = `,<Owner>,` and `maxRows` = `MAXOWNERLOCKS` + 1, where `MAXOWNERLOCKS` is 200. It keeps the rows whose `DeleteID` third piece equals `Owner` exactly. It answers 404 when the id itself is not among them.
  - **`REMOVE` and `REMOVEOWNER`** re-list, then send one `Lock` `DELETE` `?id=<DeleteID>&checkTxn=<c>` per id in the stored payload. They send only a `DeleteID` found verbatim in that fresh listing. A `DeleteID` that names no listed lock crashed the serving process in measurement.
    - `c` is 1 for a local owner unless `RemoveInTransaction` is true. It is always 0 for a remote owner, as the classic page does.
    - A stored id no longer listed is skipped, because its owner has released it. On `REMOVE`, that skip is a 404 `PORT.NOTFOUND`.
    - The vendor's 409 answers `LOCK.INTRANSACTION` (409, `CONFLICT` slug, `LockError.REASONINTRANSACTION`), and the port stops.
  - **`DELEGATEDTYPES`** is `Lock/DELETE`. `Snippet` renders one `DELETE` step per stored id (AD-59).
- **`RemoveInTransaction`** is a required boolean argument on all three tools (the `LocalDatabaseDelete` precedent). `SCREENVALUES` names it for each action, and `ScreenActionDelta` parses `'true'`/`'false'`. It is in each fingerprint subject.
  - If it is true on a local owner, the proposal's `Consequence` is `LOCK.INTRANSACTION`, which carries the warning sentence.
- **Fingerprint (AD-51).**
  - `remove`: subject `DeleteID,RemoteOwner,RemoveInTransaction`, precondition `DeleteID`.
  - The owner tools: subject `Owner,DeleteIDs,RemoteOwner,RemoveInTransaction`, precondition `DeleteIDs`.
- **`StateDiff`.** It emits one removed row per lock, `{field: <Reference>, before: <ModeCount>, after: "", removed: true}`, and refuses the following with `detail.problem`, on both callers, before any write:
  - `removeprocess` on a remote owner: `REMOTEREASON`, "Its owner is a remote client, not a process on this instance."
  - `removeclient` on a local owner: `LOCALREASON`, "Its owner is a process on this instance, not a remote client."
  - an owner set above 200: `TOOMANYREASON`, "This owner holds more than 200 locks, and one removal names at most 200."
- **Pairs.** Each tool requires the screen's `%Admin_Operate:USE` and `%DB_IRISSYS:READ`, and also declares `%DB_IRISSYS:WRITE` (AD-8 amendment). A caller without it is refused by name before any port call: at the mint, at Confirm and on the route.
  - `CLASSICPAGES` is `%CSP.UI.Portal.Locks`. Read its normalized key on the instance.
- **The prohibited set (AD-10).**
  - `lock` joins `COVEREDTYPES` with a `Lock` arm. A removal whose lock is on a global named `OcuPilot…` (the name after any `^[...]` or `^|...|` prefix) is refused `PROHIBITED.OCUPILOTLOCK`, on either caller. For the owner scopes the arm checks every lock in the set.
  - A lock held by an IRIS system process is permitted.
- **The descriptor (`LockList`):**
  - `rowActions` gains `remove`, `removeprocess` and `removeclient`.
  - `read.fields` and `context.fields` gain `RemoteOwner`. It gets no column.
  - `rowTarget` gains `"unless": "RemoteOwner"`.
  - `table.emptyNextKey` is `""` and `emptyAgentKey` is `lockListEmptyAgent` (the screen is now write-capable).
  - The three prompts stay (11.3).
- **`rowTarget.unless`** is optional. When present it is a non-empty string naming one of `read.fields`. `Screen/Registry.cls`, `ui/tools/screen-mirror.mjs` and `Test/RowTargetCorpus.cls` refuse anything else in the same words:
  - "rowTarget.unless is empty, and an unless names the read field that withholds a row's link"
  - "rowTarget.unless '<f>' is not one of read.fields"

  In `data-table.ts`, a row whose `unless` field is JSON `true` has an empty `url`: the cell is text, with no link and no Enter navigation.
- **The dialog.** The row menu draws one entry, "Remove locks" (the `remove` id). It opens `LockRemoveDialog`, titled "Remove locks held by <PID>", where `<PID>` is the row's Process ID cell.
  - **Scopes.** A radio fieldset with the legend "What to remove" offers "This lock: <REFERENCE>", "Every lock this process holds" and "Every lock its remote client holds". The first is selected. The scope that does not fit the row's `RemoteOwner` is `aria-disabled`, with the tool's refusal sentence as its reason.
  - **Confirming.** The body states `lockRemoveConsequence`. A typed-name field asks for the Process ID cell. Remove is `button-destructive`.
  - **Sending.** Submit sends the chosen scope's action with `RemoveInTransaction` `'false'`.
  - **The transaction warning.** On a refusal whose `code` is `LOCK.INTRANSACTION`, the dialog stays open. It shows that sentence as a `role="alert"` advisory, and the button becomes "Remove anyway". The next submit sends `'true'`.
  - **Other refusals** show inside the dialog. On success the dialog closes, and the change event re-reads the list (AD-14).
- **At Confirm**, a vendor 409 answers the agent's card with `LockError.REASONINTRANSACTION`. `Api/Error.ReasonForToolCode` resolves `LOCK.*` codes through `LockError.ReasonFor`, and the generic sentence is never used for them.
- **The vendor's 409 on `Lock` `DELETE` is not logged**, because it is the expected answer (AD-2 amendment).
- **Tests.**
  - Probe locks are held on a global that does not begin with `OcuPilot` (`^OcuProbeLock`), by jobs each test starts, bounded by `Hang` of at most 600 s.
  - Every holder is terminated, and every probe principal deleted, in teardown that also runs on failure.
  - No test removes a lock it did not create. Nothing touches `ocupilot`.
- **Shared files.** Changes to shared files are add-only, apart from the declared edits named in Tasks. EXPERIENCE.md stays at 993 lines, with `npm run test:tools` green. Check Epic 23's footprint before each edit (spawn-prompt rule).

**Never:**

- Call `SYS.Lock.DeleteAllLocks`, `$zu`, `$ZU` or `%SYS.ProcessQuery` for a transaction check. Send a `DeleteID` that was not in the port's own fresh listing.
- Remove a lock on `ocupilot`, or any lock a test did not take.
- Add an `Api/Error.cls` parameter (it is at the 1,000 limit), a REST route, an entity type or a client `selfProtection` rule. Hand-edit `screens.generated.ts`, `FieldLists.cls` or `ToolFields.cls`. Edit `Port/PathPort.cls`.
- Put the dialog's scope choice into the tool view or screen context. Let the client compute which locks an owner holds; the server does.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Remove this lock | A probe holds `a` and `b`, not in a transaction | `remove` on `a` removes `a` only, and the row leaves the list on the re-read | none |
| Remove every lock of the process | Probe P1 holds `a` and `b`; P2 holds `c` | `removeprocess` on P1's `a` removes `a` and `b`; `c` stays | none |
| Owner in a transaction (DW-1073) | A probe holds `t` inside `TSTART` | The first send is answered 409 `LOCK.INTRANSACTION` with the sentence, and `t` stays listed. The dialog warns. "Remove anyway" removes `t`, and the holder is still in its transaction. | Nothing removed before the warning |
| Agent, no override, owner in a transaction | `{DeleteID, RemoveInTransaction:false}` | The mint succeeds. Confirm is answered 409 with the published sentence and removes nothing. | Card shows the sentence |
| Agent, override | `RemoveInTransaction:true` | The card carries the `LOCK.INTRANSACTION` consequence and is destructive. Confirm removes the lock, reads back `notFound`, and publishes `lock/instance/<DeleteID>` `deleted`. | none |
| Wrong owner kind | `removeclient` on a local row | 400 `TOOL.ARGUMENTS` with `LOCALREASON`; the dialog draws that scope `aria-disabled` | Nothing sent |
| OcuPilot's own lock | A lock on `^OcuPilot…` alone, or in an owner's set | 403 `PROHIBITED.OCUPILOTLOCK` on both callers | Nothing sent |
| System-process lock | A daemon's lock (e.g. `^TASKMGR`) | Permitted after the typed-name confirmation. Tests never remove one. | none |
| Least privilege | A holder of exactly the screen's two pairs | It lists; each removal is refused 403 naming `%DB_IRISSYS:WRITE`. With that pair added, it removes. | Refused before any port call |
| State moved | P1 takes a new lock after an owner-scope mint | Confirm is refused `PROPOSAL.TARGETCHANGED` | Nothing sent |
| Crafted id | `DeleteID` `1,1,P<live pid>,` | The fresh read finds no such row: the mint refuses it as not present, and the route answers 404 | Never reaches the vendor |
| Remote-owner row (DW-1074) | `RemoteOwner` true | The Process ID cell is text, with no link. The process scope is drawn `aria-disabled`; this lock and the client scope stay enabled. | Unobservable without ECP: canned rows only |
| Audit | Any removal, auditing on | The vendor records `%System/%System/ConfigurationChange` "Delete lock <reference>" under the caller. The agent's path also emits its marker. | Marker failure never fails the write |

</intent-contract>

## Code Map

Anchors are as of `eb6ed8f4`. Paths are relative to `src/OcuPilot/` unless they start `ui/`, `_bmad`, or `scripts/`.

**Server:**

- **Descriptor.** `Screen/Descriptor/LockList.cls`:
  - declaration `:39-95`: `rowActions` `:61`, `context` `:62`, `read.fields` `:74`, `table` empty keys `:89-90`, `rowTarget` `:92`;
  - doc lines `:19-25` and `:43-45` say removal and DW-1074 are later work, and must be rewritten.
- **Write-tool base, `Screen/Tool/Write.cls`.** Parameters are at `:30-217`:
  - `READROWKEY` `:191`, `CHANGEACTION` `:134`, `SCREENVALUES` `:217`, `PORTCLASS` `:114`.
  - The hooks are `PortQuery` `:440`, `StateDiff` `:486`, `ScreenActionDelta` `:607`, `InputSchema` `:697` and `ArgumentProblem` `:809`.
  - `Base.cls:92` is `PrivilegePairs`. `Consequence` is optional and called by `Kernel/Proposal/Mint.cls:755-764`.
  - `Merge` refuses an argument the fresh read lacks (`Mint.cls:553-555`), which is why the read answers `RemoveInTransaction: null`.
- **Precedents:**
  - `Screen/Tool/WebSessionEnd.cls:36-150`: a destructive action-style delete with removed diff rows, `WRITERESOURCE` pairs and a `notFound` read-back.
  - `LocalDatabaseDelete.cls:48,56,81-96,133-155`: a boolean screen value through `SCREENVALUES` and `PortQuery`.
  - `ProcessBroadcast.cls:37-67`: a custom port with a composed read.
  - `LanguageServerStart.cls:128-160`: published `StateDiff` refusals.
  - `TaskManagerSuspend.cls:100,177-180`: a consequence code.
- **Ports:**
  - `Port/ProcessPort.cls:52,71,121-138,306-324`: `RECIPIENTS`, `COMPOSEDTYPES` and `Snippet`.
  - `Port/DatabasePort.cls`: sequencing through `Call` (`:169-172`, `:283-322`); `DELEGATEDTYPES` `:165`; remapping a vendor 409 (`:295-297`, `:757-765`); `Snippet` `:928-973`.
  - `Port/AdminPort.cls`:
    - `Invoke` `:903`, `Snippet`/`SnippetForm` `:2874-2895`, `RestStep` `:2926-2950`.
    - `MUTATINGTYPES` `:394` and `BODYLESSTYPES` `:410` have no `Lock/DELETE` yet (a call answers 501).
    - `Fail` `:2570-2599` logs every non-read failure. Its `pRead && 404` exemption is at `:2597`.
  - `Port/AdminRoutes.cls:129` already routes `Lock` DELETE.
  - `Kernel/Fault.cls:128-131,170-178` maps 409 to `PORT.CONFLICT`, "An item with that name already exists…". That sentence is wrong for locks, so it is remapped.
- **Write path:**
  - `Kernel/Proposal/Operation.cls`: `Query` `:173-184`, `ReadTarget` `:267-294`, `Gate` `:313-364`, `ApplyAt` `:388-404`.
  - `Kernel/Proposal/Confirm.cls:439-451`: the write-failure code is passed through, and its sentence is resolved by `Api/Confirm.cls:146-151`, then `Api/Error.cls:1210-1221` `ReasonForToolCode`, whose fallback is generic.
  - `Api/ScreenAction.cls`: `Resolve` `:151-190`, `Run` `:245-341`, `Values` `:453-491`; a port fault is rendered verbatim at `:530-536`.
  - `Kernel/Proposal/ReadBack.cls:101-111`: a delete-kind read-back reads `notFound` on 404.
- **Errors.** `Api/LanguageServerError.cls` and `Api/DatabaseError.cls` are the area-class pattern. The delegation methods are at `Api/Error.cls:1512-1534`.
- **Prohibited set, `Kernel/Proposal/Prohibited.cls`:**
  - `COVEREDTYPES` `:250` (30 types), the type guard `:966-975`, the dispatch `:1037-1125`;
  - `Codes()` `:638-641` (23), `ReasonFor` `:646-676`;
  - the process arm's sentences `:93,97` and predicates `:2520-2595` (a model for wording only);
  - `Test/Prohibited.cls:218` (CoveredTypes), `:603` (`UncoveredWriteTools` empty), `:686` (Codes 23).
  - `Test/RefusalCopy.cls:106-114`.
  - The Guardrails page iterates `Codes()` (`Kernel/Shell/Guardrails.cls:57-62`); it needs no roster edit.
- **OcuPilot's own locks:**
  - `^OcuPilotTurnSlot(user)`, held for a whole turn: `Kernel/State/Base.cls:455,472`, `Turn.cls:317`, `Kernel/Agent/Job.cls:95`, and `ReconcileHeld` `Turn.cls:274-304`.
  - `^OcuPilotProposalTarget`: `Base.cls:493`, `Propose.cls:444-477`.
  - `^OcuPilotStateCap`: `Base.cls:294-317`.
  - The install lock: `Install/Installer.cls:527-552`, listed as `^["^^<mgr>"]OcuPilotInstallLock(...)`.
- **rowTarget grammar:**
  - `Screen/Registry.cls`: `ROWTARGETKEYS` `:3587`, `RowTargetProblem` `:3610-3656`, with the field check ending `:3652` and the read-fields list at `:3643-3649`.
  - `Descriptor/Base.cls:332` `RowTarget()`.
  - `Test/RowTargetCorpus.cls`: `Cases` `:19-59`, whose sound `rowTarget` at `:43` must carry every key; its `read.fields` are at `:34`.
  - `Test/Descriptor.cls:2033` (the key-set pin) and `:2101-2132` (the Locks exact fields, 8, and rowTarget).
- **Rosters (add or bump your own entries only):**
  - `Kernel/Governance/Baseline.cls:135` (append after it);
  - `Test/ReadTool.cls:93-94` (185 becomes 188);
  - `Test/SurfaceCoverage.cls:265` (tool rows) and `:85`;
  - `Test/ToolRoundTrip.cls:49` (`REFUSEEMPTY`);
  - `Test/ToolWrite.cls:841-903` (the action-write pattern) and `:1290-1325` (`MUTATINGTYPES` equality; at most one port that is not an `AdminPort`);
  - `Test/PortFixture.cls:21`;
  - `Test/DraftRegistry.cls:56` (`TYPEDTARGETIDS`: add a `lock=` synthetic DeleteID);
  - `Test/EndpointCoverage.cls:107`, whose "declares no row action" justification becomes false;
  - `Test/WireSecurityRead.cls:735-748` (fields 8 becomes 9);
  - `Install/Smoke.cls:159,653` (unchanged).
- **Arming.** `scripts/ci-throwaway.sh:200-259` is the `PRINCIPALS` `# classes:` block. It is held equal by `ui/tools/ci.test.mjs:1909`.
- **Test hosts:**
  - `Test/InstallLock.cls:49-100` (`HoldInstallLock`, `WaitUntilHeldBy`, `LocksHeldBy`);
  - `Test/ProcessControl.cls:821-866,1065` (a JOBed probe with a bounded `Hang`, and `StopProbeProcess`);
  - `Test/WebSessionsLive.cls:19` (the principals arming parameter).

**Client:**

- **`ui/src/app/shell/data-table.ts`:**
  - `rowModels` `:619-717`, with the rowTarget branch `:647-660` and the link at `:673-674` (the one choke point for `unless`);
  - the menu entries `:883-912`;
  - `ui/src/app/shell/data-table.spec.ts:217`.
- **`ui/tools/screen-mirror.mjs`:**
  - `ROW_TARGET_KEYS` `:2354`, `rowTargetProblem` `:2371-2397`;
  - the emitted `ScreenRowTarget` `:3437` (add `readonly unless?: string`).
  - Tests are `ui/tools/screen-mirror.test.mjs:865-928`, with the key-set pin `:879-883` and the Locks rowTarget `:926`.
- **`ui/src/app/shell/screen-action-handler.ts`:**
  - `UNDRAWN_ACTIONS` `:232-247`, `PUBLISHED_PROBLEMS` `:450-462`, `refusalReason` `:465-469`;
  - `ActionRefusal` `:550-554` has no `code` yet (add it);
  - `sendFor` `:1093`, `lastRefusal` `:1105`.
- **Page-owned action precedent.** `ui/src/app/shell/screen-outlet.ts:122,148` (`DESCRIPTOR_PAGES`, `NamespaceListPage`) and `ui/src/app/areas/os-management/namespace-list.page.ts`.
- **Dialog pieces:**
  - `ui/src/app/shell/dialog.ts` is the base.
  - `broadcast-dialog.ts:60-62` shows an in-dialog refusal, with sending state.
  - `warning-dialog.ts:44-49` is the advisory markup.
  - `typed-name-dialog.ts` has the typed-name field.
  - `ui/src/app/areas/database/database-wizard.page.ts:180-200` is the radio fieldset.
- **Labels, codes and strings:**
  - `ui/src/app/core/screen-actions.ts:140-198` (`DESCRIPTOR_ACTION_LABELS`);
  - `ui/src/app/core/proposal-view.ts:137-241` (consequence codes);
  - `ui/src/app/core/strings.ts:1099-1111` (the Locks keys, cited `:376`) and `:3997` (`} as const`).
- **Tools tests:**
  - `ui/tools/self-protection.test.mjs:253-293` (`KERNEL_REFUSALS`) and `:434-455` (per-story tool reasons);
  - `ui/tools/screen-actions.test.mjs:99-141`;
  - `ui/tools/strings.test.mjs:461-575` (literal bound) and `:796` (citations).
- **Browser.**
  - `ui/browser/locks.browser-spec.mjs` has 143 lines, with a DW-1074 comment at `:136-138`.
  - `ui/browser/turnprobe-spec.mjs:47-67` provides `runIris`, `markerValue` and `escapeOs`.
  - `ui/browser/process-control.browser-spec.mjs:104-170` is the probe-and-`finally` pattern.
  - `ui/browser/structural-walk.mjs:531` is the DW-1337 walk.
- **Docs.** EXPERIENCE.md is at `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md`: `:376` is the Locks row (rewrite in place), `:95` is Remove locks and `:728` is the confirmation dialog (both unchanged).

## Tasks & Acceptance

**Execution:**

- **`src/OcuPilot/Api/LockError.cls` (new)** -- the area error class, following the `LanguageServerError` pattern.
  - Declares `INTRANSACTION` = `LOCK.INTRANSACTION` and `REASONINTRANSACTION` = "Its owner is in an open transaction. Removing the lock leaves that transaction running without it."
  - `ReasonFor` returns that sentence for that code.
- **`src/OcuPilot/Api/Error.cls`** -- add a `ReasonForLock` method, and one line in `ReasonForToolCode` before its fallback that asks it. No parameter is added.
- **`src/OcuPilot/Port/AdminPort.cls`** -- declared additions for `Lock`:
  - add `Lock/DELETE` to `MUTATINGTYPES` and `BODYLESSTYPES`;
  - add a parameter `UNLOGGEDREFUSALS` = `Lock/DELETE/409`, which `Fail` consults so that answer is not logged.
- **`src/OcuPilot/Port/LockPort.cls` (new)** -- the composed reads and writes, the `checkTxn` rule, the 409 remap and `Snippet`/`SnippetForm` (Boundaries). Its gate is `AdminPort`'s own.
- **`src/OcuPilot/Screen/Tool/LockRemove.cls` (new)** -- the base tool.
  - `SCREENACTIONS` `remove` and `SCREENVALUES` `remove=RemoveInTransaction`.
  - `PrivilegePairs` is the screen's two pairs plus `%DB_IRISSYS:WRITE`, unioned with `CLASSICPAGES` through `Screen.Gate.WithClassicPages`.
  - Its other members are `InputSchema` (the `DeleteID` string, "a DeleteID the Locks read returned", and the required `RemoveInTransaction` boolean), `ScreenActionDelta`, `PortQuery`, `StateDiff` and `Consequence`.
  - An agent-facing `DESCRIPTION` says it proposes, what the override means, and what is refused.
- **`src/OcuPilot/Screen/Tool/LockRemoveProcess.cls` and `LockRemoveClient.cls` (new)** -- the owner-scope tools. `LockRemoveProcess` extends `LockRemove`, and `LockRemoveClient` extends `LockRemoveProcess`.
  - Each declares its own `TOOLNAME`, `SCREENACTIONS`, `SCREENVALUES`, `READTYPE` `OWNER`, `WRITETYPE` `REMOVEOWNER`, subject and precondition.
  - Its `StateDiff` refuses the wrong owner kind (`REMOTEREASON`/`LOCALREASON`) and a set above 200 (`TOOMANYREASON`).
- **`src/OcuPilot/Kernel/Proposal/Prohibited.cls`** -- the `lock` arm:
  - `TYPELOCK`, and `lock` appended to `COVEREDTYPES` and the type guard;
  - the dispatch branch and a `Lock` arm reading `Reference` or every `Locks[].Reference`;
  - `OCUPILOTLOCK` = `PROHIBITED.OCUPILOTLOCK` with `OCUPILOTLOCKREASON` = "This lock keeps OcuPilot's own state consistent. It cannot be removed from OcuPilot.", added to `Codes()` and `ReasonFor`.
- **`src/OcuPilot/Screen/Descriptor/LockList.cls`** -- the declaration changes under Boundaries, plus the rewritten doc comment.
- **`src/OcuPilot/Screen/Registry.cls`, `Screen/Descriptor/Base.cls`, `ui/tools/screen-mirror.mjs`, `src/OcuPilot/Test/RowTargetCorpus.cls`** -- `unless` is added to `ROWTARGETKEYS` and `ROW_TARGET_KEYS`, with its two refusals in both engines.
  - The corpus's shared declaration gains a boolean read field, and its sound `rowTarget` gains `unless`.
  - Add corpus cases for an empty `unless` and for an unknown field.
  - Regenerate `screens.generated.ts`.
- **`src/OcuPilot/Kernel/Governance/Baseline.cls`** -- append the three keys, `true`.
- **`src/OcuPilot/Test/LockRemoveTools.cls` (new, unarmed, canned rows)** -- tests for the tools, the port and the arm:
  - registration as action-style: `SENDSBODY` 0, no field rows, `Lock` publishes no template, `CHANGEACTION` `deleted`, and the subjects above;
  - the pairs, including `%DB_IRISSYS:WRITE`, and `CLASSICPAGES`;
  - the three baseline keys;
  - `PortQuery`'s `checkTxn` over local and remote owners, with and without the override;
  - the owner-kind and too-many refusals;
  - the consequence;
  - the `Lock` arm on a canned `OcuPilot…` reference and on a system-owned one;
  - `Snippet`, one step per stored id.
- **`src/OcuPilot/Test/LockRemoveLive.cls` (new, armed with `OCUPILOT_ALLOW_PRINCIPALS`)** -- live tests against probe locks. A `StartHolder(tag, n, inTxn)` class method JOBs a holder of `^OcuProbeLock(tag, i)` and returns its pid once the locks are listed; the browser spec calls it too. Every holder and principal is removed in `OnAfterOneTest` and `OnAfterAllTests`. The legs:
  - the route for each scope, as `_SYSTEM`;
  - the 409 and then the override;
  - the agent's mint and Confirm: the diff, the consequence, the 409 sentence at Confirm, `readBack` `notFound`, the marker and the change event;
  - the fingerprint refusal after a new lock;
  - an exact-pairs principal refused naming `%DB_IRISSYS:WRITE`, and then succeeding with it;
  - a crafted id answered 404;
  - `PROHIBITED.OCUPILOTLOCK` on a probe holding `^OcuPilotTestLock16x12`, held and released by the test itself;
  - the vendor's "Delete lock" audit rows over a timestamp window.
- **Existing tests and arming:**
  - `Test/Descriptor.cls` (9 fields and `unless`), `Prohibited.cls` (CoveredTypes 31, Codes 24), `RefusalCopy.cls`;
  - `ReadTool.cls` (188), `SurfaceCoverage.cls` and `ToolRoundTrip.cls` (three rows each), `ToolWrite.cls`, `PortFixture.cls`, `DraftRegistry.cls` (`lock=`), `EndpointCoverage.cls:107`, `WireSecurityRead.cls` (9);
  - `scripts/ci-throwaway.sh` (`LockRemoveLive` on the `PRINCIPALS` classes line).
- **`ui/src/app/areas/os-management/lock-list.page.ts` (new), `lock-remove-dialog.ts` (new), `ui/src/app/shell/screen-outlet.ts`** -- the page wraps `<app-list-page />`, and is registered in `DESCRIPTOR_PAGES` beside `NamespaceListPage`. It registers `remove` to open the dialog, which sends through `sendFor` and reads `lastRefusal()`.
- **`ui/src/app/shell/screen-action-handler.ts`** -- the handler's lock entries:
  - `ActionRefusal` gains `code`;
  - `UNDRAWN_ACTIONS[LockList]` gets all three ids;
  - `PUBLISHED_PROBLEMS` gets the three tool reasons.
- **`ui/src/app/shell/data-table.ts`** -- `url` is `''` when `rowTarget.unless` names a field that is JSON `true` on the row.
- **`ui/src/app/core/screen-actions.ts`, `proposal-view.ts`** -- `LockList` `remove` → "Remove locks", and `LOCK.INTRANSACTION` → `lockRemoveInTransaction`.
- **`ui/src/app/core/strings.ts`** -- append these keys, each citing `EXPERIENCE.md:376`:
  - `lockRemoveAction`, `lockRemoveTitle`, `lockRemoveScopeLegend`;
  - `lockRemoveScopeLock`, `lockRemoveScopeProcess`, `lockRemoveScopeClient`;
  - `lockRemoveConsequence` = "Removing a lock lets another process take it at once, whatever its owner was using it to protect. This cannot be undone.";
  - `lockRemoveInTransaction`, `lockRemoveAnyway`;
  - `lockRemoveRefusalRemote`, `lockRemoveRefusalLocal`, `lockRemoveTooMany`, `lockRefusalOcuPilot`;
  - `lockListEmptyAgent` = "remove a lock that a stuck process still holds".

  If the literal bound in `strings.test.mjs` is crossed, raise it with a comment.
- **EXPERIENCE.md `:376` (in place, 993 lines)** -- rewrite the Locks row so it carries every new string above, and replace "since removal is Story 16.12's and the screen offers no action" with the removal dialog's gloss.
- **Client tests:**
  - `screen-mirror.test.mjs` (the key set, the corpus and the Locks rowTarget with `unless`);
  - `self-protection.test.mjs` (`KERNEL_REFUSALS` `OCUPILOTLOCK`, and the four tool and error reasons);
  - `screen-actions.test.mjs`, `strings.test.mjs`;
  - component specs `data-table.spec.ts` (an unlinked remote row), `lock-remove-dialog.spec.ts` (new), `lock-list.page.spec.ts` (new) and `screen-action-handler.spec.ts`.
- **`ui/browser/locks.browser-spec.mjs`** -- legs guarded to `-ci` containers, each terminating its holder in `finally`:
  1. Remove locks → the three scopes, with the client scope `aria-disabled` → type the pid → Remove → the row leaves the list.
  2. Every lock of a process: the other probe's row stays.
  3. A transaction holder: the warning appears, then "Remove anyway" → the row leaves the list.
  4. The DW-1337 structural walk of the dialog, in both themes.

- [ ] [CI] instance shard 1/3 (run 36745076438, head 4d7a5aa1): `OcuPilot.Test.AuditingUpdate.TestTheProhibitedBranchPermitsEnabledAndRefusesEveryOtherField` pins `$ListLength(Prohibited.Codes())` at 23 (`src/OcuPilot/Test/AuditingUpdate.cls:505`); this story's `PROHIBITED.OCUPILOTLOCK` makes 24. Bump the count and add this story's lock code to the assertion's message, then run `AuditingUpdate` through the shim armed with `OCUPILOT_ALLOW_AUDIT_TOGGLE` (it did not run locally: the shim's four names left it unarmed), and grep `src/OcuPilot/Test/` and `ui/tools/` for any other pin of the code count.

**Acceptance Criteria:**

- **AC1.** Given a lock row, when the user chooses Remove locks, then the dialog offers this lock, every lock of the owning process and every lock of the remote client, each naming what it removes. The scope that does not fit the owner is drawn `aria-disabled` with its reason. Pinned in the browser and by `lock-remove-dialog.spec.ts`.
- **AC2 (DW-1073).** Given the owning process is in an open transaction, when a removal is requested:
  - The vendor's 409 refuses it, and nothing is removed.
  - The dialog warns with the published sentence before anything is removed, and "Remove anyway" removes the lock.
  - The agent's un-overridden Confirm is answered with that sentence, and an overriding proposal carries it as its consequence.

  Pinned by `LockRemoveLive` and the browser.
- **AC3.** Given `Lock` publishes no body template, when the tools are built, then each is action-style, with an empty derived field list and no hand-typed field list. Pinned by `LockRemoveTools` and `DerivedFields`.
- **AC4.** Given each scope, when it is applied, then it removes exactly the locks it names and no others. Pinned by `LockRemoveLive`.
- **AC5.** Given a caller without `%DB_IRISSYS:WRITE`, when any removal is requested, then it is refused 403 naming that pair before any port call, at the mint, at Confirm and on the route. With the pair it succeeds. Pinned by `LockRemoveLive`.
- **AC6.** Given each tool, when it is registered and its removal is confirmed, then it has:
  - an enabled governance key and a script form (`DraftRegistry`);
  - a declared subject, and a Confirm refused when the subject moved;
  - `readBack` `notFound` and the change event `lock/instance/<id>` `deleted`;
  - the vendor's own audit row.

  Pinned by `LockRemoveTools` and `LockRemoveLive`.
- **AC7.** Given a lock on one of OcuPilot's own globals, alone or in an owner's set, when either caller removes it, then it is refused `PROHIBITED.OCUPILOTLOCK` and nothing is sent. Pinned by `LockRemoveLive` and `Prohibited`.
- **AC8 (DW-1074).** Given a row whose `RemoteOwner` is true, when the table renders, then its Process ID cell is text, with no link. `rowTarget.unless` is refused alike by both engines. Pinned by `data-table.spec.ts`, `RowTargetCorpus` through `Descriptor` and `screen-mirror.test.mjs`.
- **AC9.** Given any test in this story, when it ends, whether it passed or failed, then no `^OcuProbeLock` holder, probe principal or test lock remains.

### Review Findings

Code review 2026-09-30, full-opus tier: blind-hunter, edge-case-hunter, verification-gap and acceptance-auditor; 38 rows, 8 entries after grouping. Every patch is applied and verified on `ocupilot-ci`.

- [x] [Review][Patch] **High (AD-10).** An owner-scope removal on the screen's caller could remove one of OcuPilot's own locks [src/OcuPilot/Port/LockPort.cls:109]. The trigger is the target lock dropping out between the route's read and the prohibited set's own read. The set then reads the target as absent and permits the write. The port still sent every stored id it found listed, and the screen's caller has no fingerprint to stop it. The fix: a write whose target is no longer listed answers 404 and sends nothing. Fix-risk low; in-story. Pinned by the new owner leg of `LockRemoveTools.TestThePortSendsOnlyWhatItsFreshListingHolds`.
- [x] [Review][Patch] **Medium (AC9).** Each browser leg started its holders and signed in before its `try` [ui/browser/locks.browser-spec.mjs:319]. A failed setup therefore leaked the holder for up to 300 s, and the browser context with it. Holders now start inside `try`, and `atLocks` closes its own context on failure. Fix-risk low.
- [x] [Review][Patch] **Medium (Rule 19, AC1).** No test gave the page a row owned by a remote client, so its `RemoteOwner` mapping was unpinned [ui/src/app/areas/os-management/lock-list.page.spec.ts:160]. A canned remote row now checks the withheld process scope and the `removeclient` send. Fix-risk low.
- [x] [Review][Patch] **Low.** A Remove could be answered after its dialog was canceled and another row's dialog opened [ui/src/app/areas/os-management/lock-list.page.ts:148]. That answer then armed "Remove anyway" on the new dialog, or closed it. The page now ignores an answer whose dialog is gone, and a component test pins it.
- [x] [Review][Patch] **Low (Rule 19).** The lock arm's quoted-directory case could not fail: its only `]`-inside-quotes case sat in a `|...|` prefix [src/OcuPilot/Test/LockRemoveTools.cls:192]. Cases were added for a closing character inside each prefix kind, and for the state classes' `^OcuPilot.Kernel.State.BaseD` storage global.
- [x] [Review][Patch] **Low.** Nothing pinned the Locks list's `context.fields` `RemoteOwner` or its `emptyAgentKey` [src/OcuPilot/Test/LockRemoveTools.cls:349]. The new test sits in the story's own class, because `Test/Descriptor.cls` is contended by Epic 23.
- [x] [Review][Patch] **Low.** The dialog's claim that an arrow key cannot select a refused scope was untested [ui/browser/locks.browser-spec.mjs:340]. A new browser assertion holds it green: Chrome's arrow-key selection goes through the canceled click.
- [x] [Review][Defer] **Medium, unverified.** An owner-scope removal lists once and then sends its `DELETE`s one after another [src/OcuPilot/Port/LockPort.cls:120]. So a lock its owner renumbers during that sequence is sent under a stale `DeleteID`. The renumbering was measured here: taking a sibling under the same first subscript changed the held lock's id. The vendor's answer to such an id was not measured, because this stage may not send an unlisted id. Deferred as DW-1868, `decision-pending owner=burndown`: it is the AD-52 named-limit call, set out under Decisions in the review's closing summary.

**Rejected (25 rows):**

- `false`:
  - The fingerprint subject should carry `Reference`. Measured: a reused slot gets a new second piece (230006, then 230008), so no `DeleteID` named a different reference.
  - `HoldsOcuPilotLock` fails open. The port's answers always carry `Reference` as a string, so the object without one is unreachable.
  - AC5 is contradicted at the mint. `Dispatch.cls:257-262` refuses the tool call on its pairs before the mint runs.
  - `IdsOf`'s single-id fallback. It is unreachable, because `PortQuery` always stores the read's ids.
  - The client's code literals are unpinned. The browser AC2 leg drives the real 409 through them.
  - The `EndpointCoverage` probe could remove a lock. Its body is refused unreadable, and it names no listed id.
  - The port's own 404 is left unlogged. No vendor call is made, and AD-2 governs vendor answers.
  - `LockRemoveClient` inherits its read and write types. Their values are identical and pinned.
- By design (spec-bound):
  - A failure part-way through an owner removal leaves its earlier removals done and listed until the next read (the named limit: not atomic).
  - The script renders no re-list (AD-59 and the named limit).
  - Waiter rows join the set (the named limit on vendor-unremovable rows).
  - The empty state's agent invitation is the spec's.
  - A remote owner's key granularity, and its `Pid` as the title and typed name (two rows), are inference on unobserved rows under the spec's decision.
- `low`, not worth the change:
  - A dialog with no sentence for a transport fault; the connectivity banner reports it.
  - Review counts in the bookkeeping.
  - Stale EXPERIENCE.md anchors (`:319`, `:408`) that predate this story.
  - `LockRemoveLive` running past 500 lines.
  - Swapped `IdOf` labels in a test.
  - The wording of the non-string `unless` refusal; two sentences are fixed.
  - Shared and waiter rows sharing an id.
  - An owner above 201 matching rows reading as absent rather than as too many.
- Needs a spec edit, not a code change: I/O row "Remote-owner row" reads "only the client scope is enabled", while Boundaries, AC1 and the code withhold the one scope that does not fit. For the lead.

## Spec Change Log

- 2026-09-30, lead, rework iteration 1 (trigger: CI red, run 36745076438): re-opened for the one `[CI]` item under Tasks & Acceptance; nothing else changes.
- 2026-09-30, lead, after code review (tier 1, Rule 5): the I/O row "Remote-owner row" said only the client scope is enabled; Boundaries, AC1 and the code withhold only the scope that does not fit, so the row now says the process scope is drawn `aria-disabled`.

## Review Triage Log

### 2026-09-30 — Review pass

- verdicts: 23 findings — high 0, medium 6, low 8, false 9, maybe-false 0
- findings:
  - `[medium]` `[patch]` (verification-gap) No test reaches `LockPort`'s fresh-listing guard, its `REMOVE`-skip 404 or its remote-owner `checkTxn` 0 — added `Test/LockRecordPort` (canned `LIST`, recorded `DELETE`s, nothing sent) and `LockRemoveTools.TestThePortSendsOnlyWhatItsFreshListingHolds`, which also pins the 409 stop.
  - `[medium]` `[patch]` (verification-gap) The owner read's `maxRows` 201, on which the 200-lock refusal depends, is never exercised — added `LockRemoveTools.TestAnOwnerBeyondTheCapIsRefused` over 250 canned rows; the record port answers at most `maxRows` rows, as the vendor does.
  - `[medium]` `[patch]` (verification-gap) The client's `LOCK.INTRANSACTION` consequence sentence is untested — added the `proposal-view.test.mjs` test on the Task Manager pattern, reading the code from `LockRemove.cls`.
  - `[medium]` `[patch]` (verification-gap) `LockRemoveLive`'s residue check reads a failed lock list as zero locks — `ProbeRows` reports readability; `ProbeLockCount`, `CountOf` and `Listed` answer -1 on a failed read.
  - `[false]` `[reject]` (verification-gap) AC6 has no `mutation:` line for its key, script form, read-back or audit legs — Rule 19 asks one demonstrated mutation per AC, and AC6's fingerprint line is recorded.
  - `[false]` `[reject]` (verification-gap) AC8's two-engine refusal has no `mutation:` line — one per AC; AC8's `data-table.ts` line is recorded, and both engines read the one corpus.
  - `[false]` `[reject]` (verification-gap) AC2's client half has no `mutation:` line — one per AC; AC2's `checkTxn` line is recorded, and the page and dialog specs carry their own mutation notes.
  - `[low]` `[patch]` (verification-gap) `LockRemoveLive`'s `removeprocess` leg removed a set of one — P1 now holds three locks, so `removeprocess` removes two, asserted by `CountOf` before and after.
  - `[low]` `[patch]` (verification-gap) The crafted-id mint leg accepted any mint failure — it now asserts 400 `TOOL.ARGUMENTS` with the "is not present on this instance" problem.
  - `[low]` `[reject]` (verification-gap) Rows of other owners whose text carries `,P<pid>,` count against the 201-row budget, so a near-cap owner can be listed short without the refusal — needs about 200 such rows; the card enumerates the exact set, so nothing unreviewed is removed; the fix adds a truncation branch.
  - `[medium]` `[patch]` (intent-alignment) Most of the port's composed paths never run — same root cause as the first two rows; closed by the same two tests.
  - `[low]` `[reject]` (intent-alignment) The agent's pair refusal is pinned on `Registry.RequiredPairs` and `Operation.MissingPair`, not a full dispatch — dispatch reads that same `RequiredPairs`; its gate is pinned by the dispatch suites; a full dispatch needs an agent-capable principal.
  - `[false]` `[reject]` (intent-alignment) "Card shows the sentence" is asserted on `ReasonForToolCode`, not the rendered envelope — `Api/Confirm` renders a write-failure code through that same method (Code Map, `Api/Confirm.cls:146-151`).
  - `[medium]` `[patch]` (intent-alignment) The client consequence mapping is untested — same root cause as the third row; closed by the same test.
  - `[low]` `[patch]` (intent-alignment) A multi-lock owner removal ran only in the browser — same root cause as the eighth row; closed there.
  - `[false]` `[reject]` (intent-alignment) The remote-client scope never runs end to end — the intent itself scopes it to canned rows ("Unobservable without ECP"); the canned port now also pins its `checkTxn` 0.
  - `[low]` `[reject]` (intent-alignment) Least privilege runs live only for `remove` — the owner tools inherit `LockRemove.PrivilegePairs` unchanged, pinned per tool by `TestEachToolRequiresTheWritePairAndTheClassicPage`.
  - `[low]` `[reject]` (intent-alignment) OcuPilot's own lock is refused at Confirm only for a single lock — Confirm and the route call the one `Prohibited.Prohibits`; the set case is pinned on the route and on canned sets.
  - `[false]` `[reject]` (intent-alignment) No "no Enter navigation" assertion on a withheld row — `data-table.ts:1111-1122` navigates on Enter only for a non-empty `url`, which a withheld row never has.
  - `[false]` `[reject]` (intent-alignment) After a warning, a changed scope sends `'true'` — every enabled scope on a local row acts on the one owner whose transaction was warned about, and the spec says the next submit sends `'true'`.
  - `[false]` `[reject]` (intent-alignment) Edits beyond the Tasks (`Lock/REMOVE` and `Lock/REMOVEOWNER` in `MUTATINGTYPES`, `Fail`'s `pType`, a `PATH.ROOT` expectation, `Prohibited`'s uncovered probe) — each is additive and required by `ToolWrite`'s roster, `UNLOGGEDREFUSALS`, `ActionRefusal.code` and `lock` being covered.
  - `[false]` `[reject]` (intent-alignment) The diff cannot show `screens.generated.ts` was regenerated — `screen-mirror.mjs --check` in `prebuild` and the tools suite fail on any generated file that differs from the generator's output; both pass.
  - `[low]` `[reject]` (intent-alignment) Principals are deleted once per class, not per test — `OnAfterAllTests` runs on failure too, so AC9 holds when the class ends; per-test re-creation adds cost and no protection.

## Design Notes

**Measured on `ocupilot-ci`, 2026-09-30.** The transcript is in the session scratchpad, `epic-16/16-12/`. The vendor source was read on `ocupilot` with `iris_doc_get`.

- **The vendor has two types.** `%Api.Admin.Endpoints.Lock` has only `LIST` (`GET /api/admin/v2/locks`) and `DELETE` (`/lock?id=&checkTxn=`), and `ResourcesOR()` is `%Admin_Operate`.
  - With `checkTxn` 1 (the default) and the owner in a transaction, the DELETE answers 409 "Lock <id> is currently in a transaction" and removes nothing.
  - With `checkTxn` 0 it answers 200 and removes the lock, and the owner stays in its transaction. Another process then took the lock at once.
  - A stale id answers 500 "Delete lock operation did not remove any lock", not 404.
  - A released and re-taken lock gets a new `DeleteID`, with all three pieces changed.
- **A crafted id can crash the serving process.** A `DeleteID` with a live pid and slot pieces that do not match answered 500 with an empty body. At the same moment the serving CSP worker processes caught signal 7 (`messages.log`, 13:07Z). This is why the port sends only ids it has just listed.
- **`filter` is a case-insensitive substring over the whole row.** `P184` matched four pids, so the owner is always compared exactly.
- **Privilege.**
  - A holder of `%Admin_Operate:USE` and `%DB_IRISSYS:READ` lists, but is answered 500 `#921` "Operation requires %DB_IRISSYS:WRITE privilege" on a DELETE.
  - With `%DB_IRISSYS:WRITE` added, it removes.
  - Without `%Admin_Operate` it is refused 403. The transaction check fires before the privilege check.
- **Audit.** Each DELETE is recorded as `%System/%System/ConfigurationChange`, "Delete lock <full reference>", under the caller, `checkTxn` 0 included. There is no dedicated lock event, and this is not a new AD-15/AD-53 case.
- **Daemon rows.** All 57 idle-instance rows belong to daemons (the license monitor, the Task Manager, the work-queue managers), and every one reads `Removable` true. None was removed.
- **The classic Manage Locks page** (`%CSP.UI.Portal.Locks`, `RESOURCE` `%Admin_Operate`) offers Remove, "Remove all locks for process" (local owners) and "Remove all locks from remote client" (remote owners). It asks its own transaction question only for a local owner.

**Decisions:**

- **Signal (DW-1073).** The warning is the vendor's own 409, as the orchestrator decided. The vendor checks before it removes anything, so the first send is a safe probe, and "Remove anyway" is an explicit second send. No `$zu` or `ProcessQuery` read is added.
  - The agent's path gets the same sentence twice over: as the Confirm refusal, and as an overriding proposal's consequence.
- **Owner scopes use the admin API, one DELETE per lock (AD-52), not `SYS.Lock.DeleteAllLocks`.** Only the admin DELETE yields the 409. `DeleteAllLocks` removes a transaction's lock without checking (measured) and would need an AD-27 case.
  - The set is enumerated at the mint and fingerprinted, which is the AD-48 idiom. Locks the owner takes later are not removed.
- **"All of a remote client"** is every lock whose owner key (the `DeleteID` third piece, `C<client>`) equals the row's. This is the classic page's `"C"_PidInternal` (inference from vendor source; needs an ECP client to observe).
- **AD-10.**
  - A lock on `^OcuPilot…` is refused. Removing the turn-slot lock lets the next poll abandon a live turn and admit a second one (AD-41); the proposal-target lock and the install lock keep AD-34's and AD-38's single-holder guarantees.
  - A lock held by an IRIS system process is permitted: the vendor and the classic page refuse none, a removal ends no process, and the owner's 2026-09-23 direction keeps only self-protection bans. The lead may flip this at the gate by adding a `PROHIBITED.SYSTEMLOCK` arm over the owner's `JobType`, reusing the process arm's allow-list.
- **One dialog, three tools.** Each scope is its own key (AD-22), so the dialog maps the chosen scope to an action id, and only `remove` is drawn in the menu.
- **The typed name is the Process ID cell**, the one short owner identifier on every row.

**Governing ADs:**

- AD-2 (the unlogged 409);
- AD-3 (no template);
- AD-5 (`rowTarget.unless`);
- AD-6 and AD-51 (subjects, the port-built query);
- AD-8 (the extra pair);
- AD-10 (`OCUPILOTLOCK`);
- AD-13 (`lock` has no id rule, so the verbatim `DeleteID` is used);
- AD-14;
- AD-15 and AD-53 (vendor-audited);
- AD-22;
- AD-24 (`RemoteOwner` in context);
- AD-29;
- AD-34;
- AD-39 (published refusals, the area error class);
- AD-40;
- AD-44 (`CLASSICPAGES`);
- AD-52 (`LockPort`, sequencing);
- AD-53, AD-55 and AD-56 (ii) (the screen value);
- AD-58 (`notFound`);
- AD-59 (`Snippet`).

**Spine amendments for the lead (Rule 20):**

- (a) **AD-8**, appended: "**Story 16.12's lock removals declare a pair beyond their screen's set** [AMENDED 2026-09-30, Story 16.12 spec gate, Rule 20]: `osmgmt.locks.remove`, `osmgmt.locks.removeprocess` and `osmgmt.locks.removeclient` declare `%DB_IRISSYS:WRITE`, because a principal holding only the Locks screen's `%Admin_Operate:USE` and `%DB_IRISSYS:READ` listed locks and was answered 500 `#921` on every `Lock` `DELETE`, the lock left in place (measured on `ocupilot-ci`, 2026-09-30). Each is refused by name before any port call."
- (b) **AD-10**, a bullet: "**OcuPilot's own locks** [AMENDED 2026-09-30, Story 16.12 spec gate, Rule 20]: removing a lock on one of OcuPilot's own globals (a global whose name begins with `OcuPilot`: the turn slot, the proposal target, the state cap, the install lock), alone or among an owner's locks, is refused `PROHIBITED.OCUPILOTLOCK` from either caller, because each keeps one of AD-34's, AD-38's or AD-41's single-holder guarantees. A lock held by an IRIS system process is permitted at the destructive confirmation: the vendor refuses none (every daemon row reads `Removable` true, measured on `ocupilot-ci`), and a removal ends no process."
- (c) **AD-5**, a bullet after `rowTarget`: "**A row target may name the read field that withholds it** (`unless`, Story 16.12, DW-1074) [AMENDED 2026-09-30, Story 16.12 spec gate, Rule 20]. A row where that field reads `true` renders its name cell as text: a lock held by a remote client has no local pid for Process details to open. Validated alike by `Screen/Registry.cls` and `ui/tools/screen-mirror.mjs`."
- (d) **AD-51**, a case: "Story 16.12's case: `LockPort`, which builds `Lock` `DELETE`'s query -- `id` from each `DeleteID` its fresh read enumerated, `checkTxn` from the owner's kind and the declared `RemoveInTransaction` -- and answers the lock tools' fresh read through port-composed `ROW` and `OWNER` types [AMENDED 2026-09-30, Story 16.12 spec gate, Rule 20]."
- (e) **AD-52**, appended to the sequencing paragraph: "`LockPort` sends one `Lock` `DELETE` per lock of an owner, re-listing first and sending only an id that listing holds, because a `DeleteID` naming no listed lock crashed the serving process (measured on `ocupilot-ci`, 2026-09-30) [AMENDED 2026-09-30, Story 16.12 spec gate, Rule 20]."
- (f) **AD-44**: "**Story 16.12's `CLASSICPAGES`** [AMENDED 2026-09-30, Story 16.12 spec gate, Rule 20]: the three lock removals declare the classic Manage Locks page `%CSP.UI.Portal.Locks`."
- (g) **AD-2**, appended to the 404 bullet: "A `Lock` `DELETE` answered 409 has found its owner in an open transaction, the answer Story 16.12's warning is taken from, and the port logs nothing for it (`UNLOGGEDREFUSALS`) [AMENDED 2026-09-30, Story 16.12 spec gate, Rule 20]."
- There is no AD-15, AD-53 or AD-27 amendment: the vendor audits each removal, and `DeleteAllLocks` is not used.

**Named limits:**

- **An owner scope is not atomic.** A failure part-way leaves the earlier removals done.
- **A lock released between the port's listing and its DELETE** answers the vendor's 500, which `AdminPort` logs.
- **A drafted script (AD-59)** carries the reviewed ids, and OcuPilot's fingerprint does not protect it.
- **Remote-owner rows are unobserved.** Their `Pid`, the client scope and `checkTxn` 0 are all read from vendor source.
- **A vendor-unremovable row** (a pending lock) is sent like any other.
- **The measurement left seven signal-7 lines in `ocupilot-ci`'s `messages.log`.** A test that asserts a clean alert state there may read them.

**Integration:**

- **Consumes:**
  - 6.10's read, `rowTarget` and row key;
  - 16.2's `WebSessionEnd` shape;
  - 18.3's `SCREENVALUES` boolean;
  - 16.6's in-dialog refusal;
  - 18.14's page-registered action;
  - the process arm's wording;
  - `AdminPort`.
- **Consumed-by:** the Locks list, in this story. `rowTarget.unless` has no later consumer yet, and neither has `LockPort`.
- **Integration ACs:** AC1 and AC2, where the Locks dialog reads through `LockPort` and the row leaves the list on the change event, and AC8, where `data-table` renders the `unless` grammar.

**Ledger:**

- DW-1073 is addressed by AC2 and the `LockPort`/dialog tasks.
- DW-1074 is addressed by AC8 and the `rowTarget.unless` tasks.

## Verification

Everything that takes or removes a lock, or creates a principal, runs on `ocupilot-ci`, and only one test run is in flight at a time.

- **Browser runs** first rebuild and redeploy: `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`. They export `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776` and `OCUPILOT_BROWSER_CONTAINER=ocupilot-ci`.
- **Armed classes** use the lead's shim: `EPIC16_ARM="OCUPILOT_ALLOW_PRINCIPALS OCUPILOT_ALLOW_PRODUCTION_INSTALL OCUPILOT_ALLOW_TASK_CONTROL OCUPILOT_ALLOW_NAMESPACE_CONFIG" PATH=<scratchpad>/epic-16-recover/shim:$PATH`.

**Commands:**

- **Tools tier (loop):** `cd ui && npm run test:tools`. Expected green, covering screen-mirror, strings, citations, self-protection, screen-actions and ci.
- **Component specs (loop):**

  ```sh
  cd ui && npx ng test \
    --include src/app/shell/data-table.spec.ts \
    --include src/app/areas/os-management/lock-remove-dialog.spec.ts \
    --include src/app/areas/os-management/lock-list.page.spec.ts \
    --include src/app/shell/screen-action-handler.spec.ts
  ```

  Expected green.
- **ObjectScript classes (loop):** `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class <C>`, one class per call. Expected green. `<C>` is each of:
  - `OcuPilot.Test.LockRemoveTools`, then `LockRemoveLive` (armed);
  - `Descriptor`, `Prohibited`, `RefusalCopy`, `ReadTool`, `SurfaceCoverage`, `EndpointCoverage`;
  - `ToolWrite`, `ToolRoundTrip`, `PortFixture`, `DraftRegistry`, `GovernanceBaseline`, `DerivedFields`;
  - `ScreenRead`, `WireSecurityRead` (armed), `GuardrailsWire`.
- **Browser specs (loop):** `cd ui && node --test --test-concurrency=1 browser/locks.browser-spec.mjs`. Expected green within the structural baseline.
- **Once, before `dev_complete`:** `cd ui && npm test`, `uv run scripts/check-objectscript.py`, `bash scripts/lint-docs.sh`, and `wc -l` on EXPERIENCE.md. Expected green, and 993 lines.
- **The full ObjectScript sweep on `ocupilot-ci` (once, before `dev_complete`)**, one class at a time. Expected green apart from the spawn prompt's named residue. The full browser suite runs in CI (Rule 29).

**Mutations to demonstrate (Rule 19, one per AC; each reverted, with the tree unchanged afterward):**

- **AC1:** the dialog enables every scope. `lock-remove-dialog.spec.ts` goes red.
- **AC2:** `LockPort` always sends `checkTxn` 0. `LockRemoveLive`'s 409 leg goes red.
- **AC3:** `LockRemove.SENDSBODY` is set to 1. `LockRemoveTools` goes red.
- **AC4:** the owner match uses the `filter` substring alone. `LockRemoveLive`'s "other probe stays" leg goes red.
- **AC5:** `PrivilegePairs` drops `%DB_IRISSYS:WRITE`. The exact-pairs leg goes red.
- **AC6:** the subject drops `DeleteIDs`. The fingerprint leg goes red.
- **AC7:** the `Lock` arm is skipped. The `OCUPILOTLOCK` leg goes red.
- **AC8:** `data-table.ts` ignores `unless`. `data-table.spec.ts` goes red.
- **AC9:** `OnAfterOneTest` skips the holder stop. The class's own residue check goes red.

**Demonstrated (each reverted, tree unchanged afterward):**

- mutation: `LockPort.Invoke` sends `checkTxn` 0 always → `LockRemoveLive.TestAnOwnerInATransactionIsRefusedThenOverridden` and `TestTheAgentsConfirmWarnsThenOverrides` red (run 21917).
- mutation: `LockPort.Listing` keeps owner-scope rows without the exact owner compare → `LockRemoveLive.TestEachScopeRemovesExactlyItsLocks` red, P2's decoy lock (reference carrying `,P<P1>,`) removed with P1's (run 21918).
- mutation: `LockRemove.PrivilegePairs` drops `%DB_IRISSYS:WRITE` → `LockRemoveLive.TestAPrincipalWithoutTheWritePairIsRefusedByName` red on the route, dispatch and Confirm legs (run 21919).
- mutation: `LockRemoveProcess` subject drops `DeleteIDs` (precondition moved to `Owner` so it registers) → `LockRemoveLive.TestAnOwnerThatTookALockSinceTheMintRefusesTheConfirm` red (run 21922).
- mutation: the `lock` branch of `Prohibited.Prohibits` skips the arm → `LockRemoveLive.TestOcuPilotsOwnLockIsRefusedOnBothCallers` red (run 21923).
- mutation: `LockRemove.SENDSBODY` 1 → `LockRemoveTools.TestEachToolIsAnActionWriteOverTheLockPort` red for all three tools (run 21924).
- mutation: `LockRemoveLive.OnAfterOneTest` skips the holder stop → the residue assertion red in all eight tests; `OnAfterAllTests` swept the holders, probe locks 0 afterward (run 21925).
- mutation: `lock-remove-dialog.ts` draws every scope enabled (`refused` false) → `lock-remove-dialog.spec.ts` AC1 and selection tests red.
- mutation: `data-table.ts` ignores `rowTarget.unless` → `data-table.spec.ts` "a rowTarget's unless withholds the link" red.
- mutation: `LockPort.Invoke`'s fresh-listing guard treats an unlisted id as listed → `LockRemoveTools.TestThePortSendsOnlyWhatItsFreshListingHolds` red on its 404, no-`DELETE` and sent-ids assertions (run 22339).
- mutation: `LockPort.Listing` asks `maxRows` `MAXOWNERLOCKS` rather than one more → `LockRemoveTools.TestAnOwnerBeyondTheCapIsRefused` red, the owner reading 200 locks and no refusal (run 22340).
- mutation: `consequenceSentence` drops its `LOCK.INTRANSACTION` branch → `proposal-view.test.mjs` "the lock removal's in-transaction consequence code…" red.
- mutation (code review): `LockPort.Invoke` answers a target it no longer lists only for a read → `LockRemoveTools.TestThePortSendsOnlyWhatItsFreshListingHolds` red on the `REMOVE` 404 and the owner-target 404 legs (AC7, run 22345).
- mutation (code review): `Prohibited.GlobalName` drops its quote toggle → `LockRemoveTools.TestTheLockArmReadsOcuPilotsOwnGlobals` red on both quoted-directory legs (AC7, run 22346).
- mutation (code review): the Locks list's `context.fields` drops `RemoteOwner` → `LockRemoveTools.TestTheLocksListSendsTheOwnerKindAsContext` red (run 22347).
- mutation (code review): `LockListPage.onOpen` reads `remote` as `false` → `lock-list.page.spec.ts` "AC1: on a row a remote client owns…" red (AC1).
- mutation (code review): `LockListPage.onRemove` drops its open-dialog check → `lock-list.page.spec.ts` "ignores a Remove answered after its dialog was canceled…" red.

## Auto Run Result

Status: done
Blocking condition: none

- **Implemented.** Three action-style lock removals (`LockRemove`, `LockRemoveProcess`, `LockRemoveClient`) over a new `Port/LockPort` that re-lists and sends one vendor `Lock` `DELETE` per freshly listed id, the vendor's in-transaction 409 as `LOCK.INTRANSACTION` (new `Api/LockError`, unlogged via `AdminPort.UNLOGGEDREFUSALS`), the `PROHIBITED.OCUPILOTLOCK` arm, `rowTarget.unless` in both engines, the Locks page and its Remove locks dialog, 14 strings, and EXPERIENCE.md `:376` rewritten in place (993 lines).
- **Files.**
  - New: `Api/LockError.cls`, `Port/LockPort.cls`, the three `Screen/Tool/LockRemove*.cls`, `Test/LockRemoveTools.cls`, `Test/LockRemoveLive.cls` (armed), `Test/LockRecordPort.cls`, `lock-list.page.ts` and `lock-remove-dialog.ts` with their specs.
  - Changed: `Api/Error`, `AdminPort` (`Lock/DELETE`, `Lock/REMOVE`, `Lock/REMOVEOWNER`; `Fail`'s `pType`), `Prohibited`, `Baseline`, `Registry`, `Descriptor/Base`, `LockList`, the client handler, table, outlet, labels, consequence map and strings, `screens.generated.ts` (regenerated), and the roster tests the Code Map names.
  - Outside the Code Map: `Test/ClassicPageGate`, `Test/MappingDescriptor`, `Test/PortGate` (LockPort's roster row, which the sweep reddened), `Test/LockRecordPort`, `ui/src/styles/_components.scss` (appended) and `ui/tools/proposal-view.test.mjs`. Epic 23 touches none of them.
  - Footprint: every file was uncontended when edited (checked 14:52Z). At finalize, Epic 23's uncommitted batch also edits `Prohibited`, `Screen/Registry`, `Test/Descriptor`, `screen-mirror.mjs` and its test, in hunks that do not overlap this story's (compared by range).
- **Review** (Review Triage Log, 23 findings): patched 4 medium and 2 low entries, all test-only; rejected 9 false and 5 low with reasons; deferred none.
- **Follow-up review recommendation: `false`.** Patched: medium 4, low 2. The patches add tests and a test port only, each red demonstrated by mutation, so no unverified risk can be named.
- **Verification (slot A, `ocupilot-ci`, one run at a time).**
  - `npm test` green (1,730 tools, then 1,731 after the patch; 1,979 components); `check-objectscript` 0 problems; `lint-docs` 0 issues; bundle 2.32 MB.
  - Full sweep: 384 classes, 2,972 tests, 7 failed. `PortGate` 1 was this story's, fixed and green (run 22337). The rest is named residue: `PathPortInstance` 1, `Retention` 1, `TaskHistory` 3, `WireSecurityRead` task history 1; 22 classes did not run for arming variables outside the shim's four.
  - After the patch: `LockRemoveTools` 11/11 (run 22341), `LockRemoveLive` 8/8 (run 22336), `PortGate` 4/4; `locks.browser-spec.mjs` 6/6 on a rebuilt, redeployed bundle, DW-1337 in both themes.
  - Twelve mutations are recorded under Verification, one or more per AC; each reverted, the tree byte-identical.
  - No probe lock, holder or principal remains on `ocupilot-ci` (checked after the last run); nothing ran against `ocupilot`.
- **Residual risks.**
  - A process that takes a lock under the same first subscript as one it holds gives that lock a new `DeleteID` (measured), so an open dialog or proposal against it answers "no longer present" or `PROPOSAL.TARGETCHANGED` and must be reopened; a stale id is still never sent. Candidate wording for AD-52's limits.
  - Remote-owner behavior (the client scope, `checkTxn` 0) is pinned on canned rows only, as the spec accepts.
  - `ocupilot-ci`'s `messages.log` holds the planning probe's seven signal-7 lines and a few `#921` lines from the AC5 mutation runs.
