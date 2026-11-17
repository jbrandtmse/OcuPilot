---
title: 'Story 24.6: The command and class-method consoles'
type: 'feature'
created: '2026-11-15'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** OcuPilot cannot run an ObjectScript command or call a class method (catalog DT-05, DT-06). Both run code with the signed-in person's rights, so nothing on the write path can see what they change (owner answer U-78).

**Approach:** Build both consoles under AD-10's run-code exception, on Story 24.5's mechanism and with no new gate:

- **People only.** Each write tool is unadvertised and declares `PERSONGATE`, so `PROHIBITED.PERSONONLY` refuses any call the agent can reach.
- **Off by default.** Each tool's key ships `false`, and `POST /screens/:screen/action` asks it after the screen's pairs and before any hold or read.
- **Gated like the vendor terminal, or more strictly.**
- **Confirmed.** Every run passes a warning dialog that names its consequence.
- **The work.** The sibling's library methods are harvested unchanged (`ApplyOutputCeiling` with its 32,768-character ceiling, and `InvokeWithArgs` with its helpers). They run through `DevToolPort` and `HarvestPort` (AD-23).

## Boundaries & Constraints

**Always:**

- A person's Run goes through `POST /screens/:screen/action` (24.5, unchanged). The order is: the screen's pairs, the key (403 `EXPLORER.COMMAND.OFF` or `EXPLORER.CLASSMETHOD.OFF`), the hold, the fresh read, then the write.
- `DevToolPort` checks everything before any body runs, in this order:
  1. `AtelierPort.Pairs()` (`%Development:USE`).
  2. The namespace's shape, then `WritePairs(ns)`.
  3. The request type.
  4. The input's shape.
  5. The `ocupilot` screen.
  6. For a class method, its resolution.
- A body runs only through `HarvestPort.Invoke`. Its device output comes back only through `HarvestPort`'s existing capture and the handler's `OnCaptured`. The output is cut by the harvested `ApplyOutputCeiling`:
  - a command's output with the full 32,768 characters;
  - a class method's output with the budget `InvokeWithArgs` leaves after the return value and the by-reference values.
- An error raised by the person's own code is the run's answer (200, `error`), not a fault.
- After the body, the port rolls back any transaction the code left open, back to the level the run began at (24.5's `RunLocked` model).
- Each run that reaches a body writes one OcuPilot `SecurityChange` audit row: the console, the namespace and, for a class method, the class and method. It never carries the command, the arguments or the answer.
- The output, return value, by-reference values and error reach the screen only (AD-39's eighth exception).
- The harvested methods are the sibling's at `c6aad31` after the rename table.

**Never:**

- The agent never starts or fills a console. No advertised tool, no mint, no proposal card, no copy-out draft, no screen context and no arrival values.
- No sibling body taken whole.
- No edit to `Api/ScreenAction.cls`, `Kernel/Proposal/Prohibited.cls` or `Screen/Tool/Write.cls`; 24.5's mechanism serves as built.
- No `JOB`, no time limit and no cancel.
- No caller value in SQL text and no path (AD-21).
- No sibling name.
- No ObjectScript test runs code outside `^||` nodes, locals and the probe class it makes.

## I/O & Edge-Case Matrix

The rows run in `USER` on `ocupilot-b-ci`. `OcuProbe246.Echo` is made and removed by each test that uses it:

- `Echo(pText, ByRef pOut)` writes `pText`, sets `pOut = pText_"!"` and returns `$Length(pText)`.
- `Big()` returns 40,000 characters.
- `Fails()` divides by zero.

Rows from Command to Open transaction assume the key is on.

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Command | `Write "ok"` | 200 `{output: "ok", truncated: false, error: ""}`; one audit row | none |
| Code error | `Write "a" Set x=1/0` | 200, `output` "a", `error` names `<DIVIDE>` | not logged |
| Long output | a command writing 40,000 characters | `output` is at most 32,768 characters and ends with the cut marker; `truncated` true | none |
| Class method | `OcuProbe246.Echo`, `Echo`, `["hi", {"byRef": true, "value": "x"}]` | 200: `returnValue` "2", `output` "hi", `byRefValues` `{"1": "hi!"}`, `argCount` 2 | none |
| Big return | `OcuProbe246.Echo`, `Big`, `[]` | `returnValueTruncated` true, `returnValue` at most 32,768 characters | none |
| Method error | `OcuProbe246.Echo`, `Fails` | 200, `error` names `<DIVIDE>` | not logged |
| Open transaction | `TStart  Set ^\|\|ocu246=1` | 200; `$TLevel` back to its starting value after the run | none |
| Not found | a missing class, an instance method or a private method | 404 `EXPLORER.CLASSMETHOD.NOTFOUND` | not logged |
| Bad shape | blank command, over 30,000 characters, or a control character; class `a..b` or method `1x`; arguments not a JSON array, over 20 entries, a `null`, a nested array, or `{"byRef": false}` with no value | 400 `PORT.VALIDATION` with the field's reason | not logged |
| Own code | a command naming `ocupilot` in any case; a class whose first segment is `ocupilot` | 400 `EXPLORER.COMMAND.OWNCODE` or `EXPLORER.CLASSMETHOD.OWNCODE` | not logged |
| Gate | no `%Development:USE`, or no WRITE on the routines database | 403 `AUTH.NOPRIVILEGE` with `detail.failedPair` | not logged |
| Switched off | any Run with the key at its shipped `false` | 403 `EXPLORER.COMMAND.OFF` or `EXPLORER.CLASSMETHOD.OFF`, before the hold and the read | not logged |
| Agent | `explorer_command_run` or `explorer_classmethod_run` by any name | `TOOL.UNKNOWN`; a fixture registry that advertises it gets 403 `PROHIBITED.PERSONONLY` | structured |

In every refusal row, the recorder records no body call and no audit row is written.

</intent-contract>

## Code Map

**Sibling (read-only):** `/Users/jbrandt/git/iris-execute-mcp-v2` at `c6aad31`. The ledger slice for this story is empty.

- `src/ExecuteMCPv2/REST/Command.cls` (436 lines):
  - `Execute:61` and `ClassMethod:243` give the call order the handlers keep.
  - Their redirect (`Use tNull::("^"_$ZNAME)`, `:115-118`, `:289-291`) and `Redirects:424` are not taken. A mnemonic of the body's own routine raises `<NOROUTINE>` once switched to a namespace OcuPilot's code is not mapped into. 24.5 measured this for `RunTests`'s identical redirect; Task 0 item 3 confirms it here.
- `src/ExecuteMCPv2/Utils.cls`, taken verbatim after the rename table. The doc comments are replaced by OcuPilot contract comments.
  - `OUTPUTCEILING` 32768 (`:27`) and `BYREFNODECEILING` 1000 (`:34`).
  - `ApplyOutputCeiling:324`, `SurrogateSafeCutLength:364`, `ParseArgEntry:394`, `BuildByRefNode:504`, `AddByRefPosition:607` and `InvokeWithArgs:700-905`.
  - Rename table: `%ExecuteMCPTruncated` becomes `%OcuPilotConsoleTruncated` (`:714,840,841`). The marker `[IRIS-MCP-TRUNCATED ceiling=<n>chars]` becomes `[cut at <n> characters]` (`:333`).

**Vendor bar:** `irissys/%Atelier/v7/TerminalAgent.cls:10,375`. The vendor's web terminal asks `%Development:USE` alone, and the portal has no command page. The consoles ask that, plus `WritePairs(ns)`, behind a key that is off by default, so they are stricter.

**24.5's mechanism (consumed, not edited):**

- `Screen/Tool/Write.cls:177` declares `PERSONGATE`.
- `Api/ScreenAction.cls:316-329` asks the key; the reason comes from `AtelierError.ReasonFor`.
- `Kernel/Proposal/Prohibited.cls:1546-1550` is the `PERSONONLY` arm.
- `Screen/Tool/ExplorerUnitTestRun.cls` is the tool model: `READSVALUES`, `ScreenActionDelta`, `PortQuery`, `StateDiff` and `WriteOutput`.
- `Kernel/Governance/Baseline.cls:221`.
- `Api/AtelierError.cls:261-310` holds the code, reason and `ReasonFor` pattern.

**Seams:**

- `Port/DevToolPort.cls` (1,727 lines):
  - `Endpoints:306`, `COMPOSEDTYPES:115` and `Invoke:344`, whose unit-test dispatch at `:356` is the model for the console dispatch.
  - `UnitTest:524` is the check-order model. `RunLocked:703` is the rollback model. `Audit:1551` is the audit model.
  - `SnippetForm:1570`, `Snippet:1591`, `RunSnippet:1653`, and `Deny`, `Refuse` and `Fail` (`:1702-1719`).
- `Port/HarvestPort.cls`: `Invoke:76`, which keeps `tLines` from `EndCapture` (`:140`) and calls `Answer` (`:151`, `Answer:176`).
- `Port/Harvest/Handler.cls` is the base. `Port/Harvest/UnitTestRun.cls` is the model for an OcuPilot handler over harvested methods (`..SwitchNamespace`, `RenderResponseBody`).
- `Port/AtelierPort.cls`: `Pairs():755`, `WritePairs():788`, and `NAMESPACEPATTERN` with its refusal reasons.
- `Kernel/Audit/Event.cls:194` `Record`.
- `Kernel/State/Switch.cls:170` `SetGuarded` refuses a non-administrator (21.30).
- `Screen/Descriptor/ExplorerSqlQuery.cls` is the model for a form page with no read, the row action `run`, and the literal target under `class`.

**Client:**

- `ui/src/app/areas/system-explorer/dev-tool.store.ts:150-185` is the model for ask, cancel and proceed through `RunSender.sendFor`.
- `shell/screen-action-handler.ts:1836` `lastOutput()` gives the run's answer.
- `shell/warning-dialog` and `shell/screen-outlet.ts:225-238` hold the loader lines.

**Tests and rosters:**

- Models: `Test/UnitTestRunGate.cls`, `UnitTestPersonOnly.cls` (parameterized by class parameters), `UnitTestActionFixture.cls`, `DevToolHarvestRecorder.cls`, `DevToolPortFixture.cls` and `DevToolProbe.cls`.
- `Test/NamespacePromote.cls:243-265` is the audit-row assertion model (`Test/AuditEvent.RowsCarrying`).
- Browser models: `ui/browser/unit-tests.browser-spec.mjs`, `unit-tests-principals.browser-spec.mjs` and `preferences-reset.mjs` (`setGovernanceKey`, `resetGovernancePolicy`).
- Rosters. Every file that names 24.5's tool is a roster to check, and each count is re-derived:
  - `Test/Descriptor`, `DeveloperFloor`, `ExplorerDescriptor`, `Governance`, `GovernanceBaseline`, `Prohibited`, `ReadTool`, `StageTwoTools`, `SurfaceCoverage`, `ToolEmit` (`:328`, the branch for 24.5's tool) and `ToolRoundTrip`;
  - `ui/tools/screen-mirror.test.mjs` and `navigation.test.mjs`;
  - `DraftRegistry`, `PortGate`, `ClassicPageGate`, `Navigation`, `Wire` and `WireAreaAnyScreen`.

## Tasks & Acceptance

**Execution, batch 1 (server):**

- **Task 0, on `ocupilot-b-ci`, before any code.** Run one probe at a time and record each result under Design Notes as `Task 0 (measured)`. Item 1 stops the story if it fails.
  1. A probe handler under `HarvestPort.Invoke`, called from `HSCUSTOM` and switched to `USER`, runs `Xecute "Write ""a"",!,""b"""` and then a 40,000-character `Write`. Check that `EndCapture`'s lines carry both writes whole.
  2. The same probe calls a parent-class method with `..` while switched. Check that it resolves, as 24.5's `..BuildTestSpec` does.
  3. The sibling's redirect form, bound to the probe's own routine and switched to `USER`, raises `<NOROUTINE>`. This is recorded only.
- `src/OcuPilot/Port/Harvest/Handler.cls` -- add `ClassMethod OnCaptured(pLines As %DynamicArray, pResult As %DynamicObject) As %Status`, a no-op by default. Its contract: called after an OK render with the body's captured device lines.
- `src/OcuPilot/Port/HarvestPort.cls` -- after an OK render whose result is an object, call `$ClassMethod(pHandler, "OnCaptured", tLines, pResult)` with the namespace already restored. An error from it, or an exception, is 500 `INTERNAL`, logged. The header says the output is discarded unless the handler takes it (AD-39's eighth exception).
- `src/OcuPilot/Port/Harvest/Console.cls` -- new; extends `Handler`. The two parameters and the six methods, verbatim after the rename table.
- `src/OcuPilot/Port/Harvest/ConsoleRun.cls` -- new; extends `Console`.
  - `Command()` reads `command` and `namespace`, switches with `..SwitchNamespace`, and runs `Xecute` inside its own `Try`. It restores the namespace and renders `{truncated: false, error, outputBudget: OUTPUTCEILING}`.
  - `ClassMethod()` reads `class`, `method`, `args` (JSON text, `%FromJSON`) and `namespace`. It calls `..InvokeWithArgs`, then builds `returnValue` as the sibling does: the OREF guard, then `ApplyOutputCeiling` with `returnValueTruncated`. It renders `{returnValue, argCount, byRefValues, truncated, byRefTruncated, returnValueTruncated, error, outputBudget}`.
  - `error` is the code's `$System.Status.GetErrorText`, or `""`.
  - `OnCaptured` joins the lines with `$Char(10)`, stopping one character past `outputBudget`. It sets `output` to `..ApplyOutputCeiling(text, .truncated, outputBudget)`, ORs that into `truncated`, and removes `outputBudget`.
- `src/OcuPilot/Port/DevToolPort.cls`:
  - Add the endpoints `Command` and `ClassMethod` (`STATE`, `RUN`), dispatched like `UnitTestEndpoints`, with `COMPOSEDTYPES` appended. Add the keys `command`, `class`, `method` and `args`, and `COMMANDMAX` 30000.
  - `Console()` runs the Always checks. Class and method match `^%?[A-Za-z][A-Za-z0-9]*(\.[A-Za-z][A-Za-z0-9]*)*$` and `^%?[A-Za-z][A-Za-z0-9]*$`. The arguments follow `ParseArgEntry`'s accepted shapes, with at most 20.
  - Resolution, with the namespace saved and restored: a compiled, public class method in `%Dictionary.CompiledMethod`.
  - `STATE` echoes `{Namespace, Command}` or `{Namespace, Class, Method, Arguments}`, where `Arguments` is the count.
  - `RUN` calls `HarvestPort` with `HANDLERCONSOLE`, then rolls back as `RunLocked` does, then writes the audit row with `Event.Record("run", "class", <"command"|"classmethod">, {}, 1, effects)`, as `Audit:1551` does.
  - `SnippetForm` and `Snippet`: an `objectscript` step holding the command, and a `comment` step naming the class and method, as `RunSnippet` does. Update the header.
- `src/OcuPilot/Screen/Tool/ExplorerCommandRun.cls` and `ExplorerClassMethodRun.cls` -- new, on `ExplorerUnitTestRun`'s model:
  - `ADVERTISED 0`, `PORTCLASS DevToolPort`, `READTYPE STATE`, `WRITETYPE RUN`, `DESTRUCTIVE 1`, `SENDSBODY 0` and `READSVALUES 1`.
  - `SCREENACTIONS run`, with `IDARGUMENT` `Target` and the literals `command` and `classmethod`.
  - `PERSONGATE` `EXPLORER.COMMAND.OFF` and `EXPLORER.CLASSMETHOD.OFF`.
  - `SCREENVALUES` `run=command` and `run=class:method:args`.
  - `WriteOutput` passes the answer's fields through.
- `src/OcuPilot/Kernel/Governance/Baseline.cls` -- add `"explorer.command.run": false` and `"explorer.classmethod.run": false`, add-only.
- `src/OcuPilot/Api/AtelierError.cls` -- add the five codes with the reasons under Proposed strings, and add them to `ReasonFor`.
- `src/OcuPilot/Screen/Descriptor/ExplorerCommand.cls` and `ExplorerClassMethod.cls` -- new, on `ExplorerSqlQuery`'s model:
  - Routes `system-explorer/command` and `system-explorer/class-method`, at side-bar positions 18 and 19.
  - `form-page`, no `read`, id `none`, `%Development:USE`, entity type `class`, scope `namespace`.
  - Row action `run`, `classicPage` `""` with no exemption (as 24.5), and empty `context`.
  - `toolIdentifier` `explorer.command` and `explorer.classmethod`.
- `src/OcuPilot/Screen/Titles.cls` -- regenerate. Add this story's members to every roster in the Code Map, appending only, and re-derive each count.
- `src/OcuPilot/Test/ToolEmit.cls:328` -- widen 24.5's branch from that one class to every tool that declares `PERSONGATE`.
- `scripts/check-objectscript.py` and `scripts/test_check_objectscript.py` -- add the `HARVEST_CALLERS` row `OcuPilot.Port.Harvest.ConsoleRun`, with `DevToolPort` as its caller, and one harness case for naming it anywhere else.
- Tests:
  - `src/OcuPilot/Test/ConsoleGate.cls` -- new, under 500 lines, through a `ScreenAction` fixture and `DevToolHarvestRecorder`. It covers every refusal row and Switched off for both tools, and the key-on path recording `ConsoleRun.Command` or `ClassMethod` with the port's keys only. It saves and restores the stored policy.
  - `src/OcuPilot/Test/ConsoleRoundTrip.cls` -- new. Through `DevToolPortFixture` with the real bodies, it covers the rows from Command to Open transaction, the audit row (`AuditEvent.RowsCarrying`, with no command text in its data), and the namespace and `$TLevel` restored.
  - `src/OcuPilot/Test/CommandPersonOnly.cls` and `ClassMethodPersonOnly.cls` -- new subclasses of `UnitTestPersonOnly` with its parameters overridden. A leg that needs a read tool is overridden, because a console declares none.
  - `src/OcuPilot/Test/DevToolProbe.cls` -- add `MakeConsoleProbe` and `RemoveConsoleProbe` for `OcuProbe246.Echo`.

**Execution, batch 2 (client):**

- `ui/src/app/areas/system-explorer/console.store.ts` and `console.page.ts` (with `.spec.ts`) -- new; one page serves both descriptors.
  - The Command form is a textarea limited to 30,000 characters. The Class method form has Class, Method and Arguments.
  - Run opens `app-warning-dialog` with the console's consequence. Confirm sends `sendFor(descriptor, 'run', <literal>, values, sink, scope)`. Cancel sends nothing.
  - The answer is read from `lastOutput()`: output, return value, by-reference values, error, and each truncation note. A refusal shows the instance's reason.
  - Spec cases: the dialog's consequence, Cancel sends nothing, the off reason, and the truncation note.
- `ui/src/app/shell/screen-outlet.ts` -- two loader lines.
- `ui/src/app/core/strings.ts`, `core/screens.generated.ts` (`node tools/screen-mirror.mjs`) and EXPERIENCE.md's Fixed strings (`_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md`) -- add-only.
- `ui/browser/consoles.browser-spec.mjs` -- new, as administrator. `before` asserts the throwaway and makes the probe.
  - With the key at baseline, Run then Confirm shows the off sentence.
  - With the key on, the command, long-output, class-method and error rows show through the dialog.
  - `after` removes the probe and restores the policy.
- `ui/browser/consoles-principals.browser-spec.mjs` -- new, on `unit-tests-principals`'s model. A principal holds `%Development:USE` and the `USER` and `HSCUSTOM` database pairs, and is not an OcuPilot administrator.
  - Both consoles run with the key on.
  - Each missing pair gives 403 naming it.
  - Both tools are in none of the agent's lists.
  - A command calling the kill switch's guarded store by indirection (`$ClassMethod("Ocu"_"Pilot.Kernel.State.Switch", "SetGuarded", ...)`) leaves the switch as it was.

**Acceptance Criteria:**

- **AC1.** Given the key switched on, when a person runs a command and confirms, then it round-trips over the harvested console class: matrix rows Command, Code error and Open transaction, observed in the browser on `ocupilot-b-ci`.
- **AC2.** Given the key switched on, when a person calls a class method with arguments, one passed by reference, and confirms, then it round-trips over `InvokeWithArgs`: matrix rows Class method, Big return and Method error.
- **AC3.** Given a command's output, when it is returned, then it is bounded by the harvested output ceiling: at most 32,768 characters, ending with the cut marker, with `truncated` true.
- **AC4.** Given any refusal row, when the run is asked, then it answers that row's status and code. The recorder records no body call, and no audit row is written.
- **AC5 (Integration, off by default).** The consumer is `ScreenAction`. Given either tool's `PERSONGATE` and its key at the shipped `false`, when a person's Run is sent, then it answers 403 with the tool's `OFF` code, and nothing is held, read or run. After an administrator's `PUT /agent/governance` sets the key on, the same Run runs.
- **AC6 (people only).** Given the agent, when it looks for or calls either console, then neither tool is in any of its lists or resolves by any name. A registry that offered one is refused `PROHIBITED.PERSONONLY` on the instance.
- **AC7 (confirmed).** Given either console, when the person presses Run, then the warning dialog shows that console's consequence. Nothing is sent before Confirm, and Cancel sends nothing.
- **AC8.** Given the six harvested methods, when they are compared with the sibling's after the rename table, then each implementation's SHA-256 matches the pinned hash, and `uv run scripts/check-objectscript.py` passes.
- **AC9 (least privilege).** Given the principal above, when it runs either console over the real route, then the run succeeds with exactly those pairs and is refused 403 without each one. An indirect call of OcuPilot's guarded store from that principal's command leaves OcuPilot's state unchanged.
- **AC10 (audited).** Given a run that reaches a body, when it ends, then one `SecurityChange` row names the console and the namespace (and the class and method). The command, the arguments and the answer are in no row.

## Spec Change Log

- 2026-11-16, re-plan (iteration 2), owner answer U-78 "C: fix U-79 first, then A (Recommended)"; the DW-2634 fix (Story 21.30) is on feature. The halted draft was replaced by a full plan on Story 24.5's `PERSONGATE` mechanism.
  - The `deferred:` item was harvested as DW-2634, which 21.30 resolved, so it was removed and the next harvest does not file it twice.
  - The sibling's `Execute` and `ClassMethod` are no longer taken whole, because their redirect cannot resolve across namespaces. OcuPilot's handlers keep their call order over the harvested library methods.
  - KEEP: the harvested library methods, the 32,768 ceiling and the answer shapes.

## Review Triage Log

## Design Notes

**Owner answer U-78 (2026-11-16):** both consoles are built under AD-10's run-code exception, which the spine already carries for 24.5 and which names this story. The condition, the DW-2634 fix, is met: `SetGuarded` and `GuardedApply` refuse a caller who is not an OcuPilot administrator (`AdminWriteRefused`, Story 21.30). The 24.5 mechanism serves unchanged, so there is no intent gap.

### Governing ADs

- AD-10: the run-code exception and its named gap. AD-22: the person key. AD-53: unadvertised, two callers, and the dialog as the review.
- AD-39: the eighth exception. AD-15: OcuPilot's own row for a person's write the vendor does not audit.
- AD-23 and AD-29: the harvest seam and `DevToolPort`'s gate. AD-61: the gate pairs.
- AD-7: the run happens in the action request. AD-34: the hold. AD-14: the change event. AD-51, AD-52 and AD-58: the write model.
- AD-16: switches save and restore. AD-21: bound values only. AD-24: no context. AD-11 and AD-60: output never reaches the model. AD-35: output may hold secrets, so it is never logged. AD-17: probe classes only on the throwaway.

### Decided in-stage (reversible)

- **OcuPilot's handlers, not the sibling's.** `ConsoleRun` is a deliberate copy of the sibling's call order (Rule 31). The only differences: no redirect, and the code's own error becomes `error` (a failed render reaches the person only as `INTERNAL`).
- **The output rides `HarvestPort`'s capture.** `%SYS.Capture` resolves in every namespace; 24.5's Task 0 item 2 measured this from `USER`.
  - The one extension is `OnCaptured`: two lines in `HarvestPort` and a no-op on the base. It is a hook, not a second capture, because `%SYS.Capture` refuses to nest ("Capture Already Active").
  - The ceiling is applied inside the harvested class, so `ApplyOutputCeiling` keeps a harvested call site.
- **The audit row.** Running code is the most security-relevant act the product offers. An OcuPilot row per run (AD-15, promote's precedent) is stricter than a named gap, and it holds no text, because a command can carry a password.
- **Limits and shapes:**
  - The command is one line of at most 30,000 characters: `Xecute` takes one line, and 30,000 is the card width's precedent.
  - At most 20 arguments, the sibling's limit.
  - A class method must be compiled, public and a class method, so a call `$ClassMethod` would refuse becomes a clean 404.
- **The `ocupilot` screen** is text matching in any letter case. It is a screen, not a prohibition: indirection passes it, and 21.30's guarded stores are what hold.
- **One page, `console.page.ts`, for both consoles.** `dev-tool.page.ts` (577 lines) is a list page over a read, and the consoles have no read. The run-mode state follows `dev-tool.store.ts`'s ask, cancel and proceed.
- **Side-bar positions 18 and 19**, after Unit tests (17). Position 15 stays free.
- **Named limits (inference until the browser spec observes them):**
  - The code runs in OcuPilot's request process. A lock, a device change, a process-private global or a `$Roles` change it leaves stays with that process. A person can clear them from Locks and Processes.
  - A run past the Web Gateway timeout loses its answer and keeps its process until it ends. A person can end it from Processes.
  - A `Read` gets no input.
  - Two runs of one console in one namespace are serialized by AD-34's hold; the second gets 409.
  - The whole device output is held in process-private storage until the run ends. Only the first 32,768 characters reach the screen.

### Integration ACs, Consumed-by and Consumes

- **Integration ACs:** AC5 (`ScreenAction` consumes each tool's `PERSONGATE`), and AC1 and AC3 (`HarvestPort` consumes `ConsoleRun.OnCaptured`; the person sees the bounded output).
- **Consumed-by:** 24.7 (the web terminal) may reuse `OnCaptured` and the `Console` ceiling (inference). No other consumer is in this story.
- **Consumes:**
  - 24.5's `PERSONGATE` ask, the `PERSONONLY` arm and `UnitTestPersonOnly`;
  - 24.1's `DevToolPort`, recorder and probe;
  - `AtelierPort`'s pairs and `Event.Record`;
  - 21.30's guarded stores.

### Contended files (orchestrator ruling A): edits beyond appending (check `origin/OCU-1-epic21` at integrate-forward)

- `Prohibited.cls` and `ScreenAction.cls`: none.
- More than an append:
  - `DevToolPort.cls`: the header and the `Invoke` dispatch.
  - `HarvestPort.cls`: an insertion after the answer.
  - `Harvest/Handler.cls`: a new method.
  - `Test/ToolEmit.cls`: the branch widened.
- Re-derived counts: `ReadTool` (no new read tool, so expected unchanged), the write-tool count, `ClassicPageGate`, and the descriptor and side-bar rosters. Re-count after the union; never add the deltas.

### Governance keys

- `explorer.command.run`: default `false`, destructive, person-only.
- `explorer.classmethod.run`: default `false`, destructive, person-only.

### Proposed strings (veto item)

- Titles: "Command console" and "Class method console". Buttons: "Run command" and "Call method".
- Fields:
  - "Command".
  - "Class" and "Method".
  - "Arguments", with the hint: A list in square brackets, such as ["a", 1]. Write {"byRef": true, "value": "x"} to pass a value by reference.
- Dialogs:
  - "Run this command?": "This runs ObjectScript as you, with your rights, in this namespace. OcuPilot cannot see or undo what it changes."
  - "Call this class method?": "This runs the method's code as you, with your rights, in this namespace. OcuPilot cannot see or undo what it changes."
- Answer labels: "Output", "Return value", "By-reference values" and "Error". When there is no output: "Nothing was written."
- Truncation notes:
  - "The output was cut at 32,768 characters."
  - "The return value was cut at 32,768 characters."
  - "Some by-reference values were left out to keep the answer under 32,768 characters."
  - The in-text marker: `[cut at 32768 characters]`.
- Refusals:
  - "Running commands is switched off on this instance. An administrator can switch it on in Governance policy."
  - "Calling class methods is switched off on this instance. An administrator can switch it on in Governance policy."
  - "OcuPilot does not run a command that names OcuPilot."
  - "OcuPilot does not call its own class methods."
  - "No compiled class method of that name is in this namespace."
  - "Enter the command on one line, up to 30,000 characters."
  - "Name a class and one of its class methods with letters, digits, dots and %."
  - "Give the arguments as a list in square brackets of at most 20 values: text, numbers, true or false, or a by-reference value."
- Tool descriptions:
  - "Run an ObjectScript command in a namespace. Only a person runs it, from the Command console; the agent never does."
  - "Call a class method in a namespace. Only a person calls it, from the Class method console; the agent never does."
- Suggested prompts:
  - Command console: "How do I list a global's first subscripts?", "What does $ZVERSION show?" and "How do I count a table's rows in one command?"
  - Class method console: "Which class method returns the instance's version?", "How do I pass an argument by reference?" and "What does a %Status return value mean?"
- Agent phrases, used only if the screen mirror requires one for these pages: "explain an ObjectScript command" and "explain a class method".
- Command aliases:
  - Command console: "command console", "run command" and "execute command".
  - Class method console: "class method console", "call class method" and "run class method".

### Proposed spine amendments (the runner writes these at the spec gate, citing owner answer U-78)

Written at the spec gate on 2026-11-16, citing owner answer U-78: AD-10's consoles sentence, AD-22's two keys, AD-53's sixth and seventh unadvertised tools, and AD-39's eighth exception (orchestrator ruling; owner veto U-101). Orchestrator ruling on the audit row (DW-2673): the audit test proves the row exists, that it never carries the command, the arguments or the output, and that Story 24.5's runner gets the same row if a measurement at the route shows it has none.

- **AD-10**, appended to the paragraph "Code a person runs through OcuPilot":

  > **The command and class-method consoles** [AMENDED 2026-11-16, Story 24.6 spec gate, owner answer U-78: "C: fix U-79 first, then A (Recommended)", Rule 20] run a command the person types, or a class method the person names, with the person's rights, as the vendor's terminal does. Named gap: what that code does, which can reach every arm of this set. OcuPilot's protected state stays refused to anyone who is not an OcuPilot administrator by its guarded stores (Story 21.30). A command that names OcuPilot in any letter case, or a class in an `OcuPilot` package, is refused by the port as a screen, not a prohibition.

- **AD-22**, in "One person's write asks its key", after "`explorer.unittests.run` ships `false` (Story 24.5)", add: "; `explorer.command.run` and `explorer.classmethod.run` ship `false` (Story 24.6, owner answer U-78)".
- **AD-53**, after "A fifth unadvertised tool":

  > **A sixth and a seventh unadvertised tool** [AMENDED 2026-11-16, Story 24.6 spec gate, owner answer U-78, Rule 20]: `explorer.command.run` and `explorer.classmethod.run` (Story 24.6) are a person's alone under AD-10's run-code exception. Their keys ship `false` and are asked by the screen action route (AD-22), and they have no mint, no proposal card and no copy-out draft. Each run records OcuPilot's own `SecurityChange` row naming the console, the namespace and, for a class method, the class and method, never the command, the arguments or the answer (AD-15), so neither is a named audit gap.

- **AD-39**, after the seventh exception:

  > **The eighth exception** [AMENDED 2026-11-16, Story 24.6 spec gate, owner answer U-78, Rule 20]: a console run's output, return value, by-reference values and error text (Story 24.6) reach the screen only, as text, and never the model, a tool result, a ledger row, an audit payload, a log line or screen context.

## Verification

**Shared surfaces:** System Explorer side-bar positions 18 and 19; the registered and unadvertised tool rosters; the governance baseline and the stored policy; the `EXPLORER.*` code roster and EXPERIENCE.md's Fixed strings; `HarvestPort`'s answer (`OnCaptured`); `ToolEmit`'s person-gate branch. Every test added or changed passes on a fresh environment, in either order. Tests touch only `^||` nodes, locals and `OcuProbe246` in `USER`, which they make and remove. Tests that store a key restore the policy they found.

**Commands:**

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.ConsoleGate --class OcuPilot.Test.ConsoleRoundTrip --class OcuPilot.Test.CommandPersonOnly --class OcuPilot.Test.ClassMethodPersonOnly` -- expected: all pass.
  - Run each class touched the same way, one call at a time, each under about 170 s: the Code Map rosters, `UnitTestPersonOnly`, `UnitTestRunGate`, `Harvest`, `PortCapture`, `DevToolPort*` and `NamespacePromote`.
- `(loop)` `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/ && OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci node --test --test-concurrency=1 browser/consoles.browser-spec.mjs browser/consoles-principals.browser-spec.mjs` -- expected: pass. Never run beside a `ci-runner` call.
- `(loop)` `cd ui && npm run test:tools && npm run test:components` -- expected: pass.
- `(loop)` `uv run scripts/check-objectscript.py && uv run scripts/test_check_objectscript.py` -- expected: clean.
- `(once)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --shard k/17`, for k = 1..17, one call each -- expected: green. The full browser suite is left to CI.

**Mutations (Rule 19), one per AC, recorded as `mutation:` lines by the implement stage:**

- AC1: `OnCaptured` no longer sets `output`.
- AC2: `ClassMethod()` drops `byRefValues`.
- AC3: `outputBudget` is ignored in `OnCaptured`.
- AC4: the `ocupilot` screen is made unreachable.
- AC5: a tool's `PERSONGATE` is emptied.
- AC6: `ADVERTISED 1`.
- AC7: Run sends without the dialog.
- AC8: one harvested line is changed.
- AC9: a `WritePairs` pair is dropped.
- AC10: the audit call is removed.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none
