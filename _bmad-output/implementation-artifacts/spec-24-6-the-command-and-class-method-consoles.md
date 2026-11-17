---
title: 'Story 24.6: The command and class-method consoles'
type: 'feature'
created: '2026-11-15'
status: 'draft'
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: ['oversized']
deferred:
  - summary: "OcuPilot's guarded storage methods escalate for any caller, so any code a %Development holder runs can rewrite OcuPilot's protected state (kill switch, governance keys) without OcuPilotAdmin."
    evidence: "Test/State.TestEscalationIsWhatGrantsTheDeniedUserAccess (measured, pinned): a user refused <PROTECT> on a direct write succeeds through Kernel.State.Base's guarded methods. Kernel/State/Switch.SetGuarded and Policy.GuardedApply check no caller privilege; Api/Governance.cls checks IsAdministrator() before calling GuardedApply. Reachable today through the vendor's web terminal (%Development:USE only); the end-to-end governance rewrite by a non-administrator is (inference)."
    location: 'src/OcuPilot/Kernel/State/Base.cls; src/OcuPilot/Kernel/State/Policy.cls:73; src/OcuPilot/Kernel/State/Switch.cls:165'
    severity: 'high'
---

# Story 24.6: The command and class-method consoles

The plan stage halted on an intent gap against AD-10. A console that runs caller-typed ObjectScript, or calls a caller-named class method, can reach every arm of AD-10's prohibited set, and OcuPilot's own protected state through its guarded storage methods, with no write-path predicate able to see it. The spine has no named gap for that, and "whatever the caller" is its Rule. The investigation, the options and the prepared shape are kept below so the re-plan can start from them.

## Intent

Not planned yet: the plan stage halted on an intent gap (Auto Run Result). The story's two ACs (`epics.md:10115-10131`) are unchanged: each console round-trips over its backing class, and the command console's output is bounded by the harvested output ceiling.

## Boundaries & Constraints

Pending the ruling. Fixed whichever option is taken: no edit to `Port/HarvestPort.cls` or `Port/Harvest/Handler.cls`; bodies harvested only through `DevToolPort` (AD-23, AD-29); no sibling name anywhere; the output ceiling is the sibling's 32,768 characters.

## I/O & Edge-Case Matrix

Pending the ruling.

## Code Map

The sibling repository is `/Users/jbrandt/git/iris-execute-mcp-v2` at `c6aad31`. It is read-only. The ledger slice for `24-6-the-command-and-class-method-consoles` is empty.

### Backing classes (sibling)

- `src/ExecuteMCPv2/REST/Command.cls` (436 lines; the harvest map's 376 is stale).
  - `Execute:61` reads `{command, namespace}`, switches namespace, redirects I/O to a null device bound to `"^"_$ZNAME` (`:115-118`), runs `XECUTE tCommand` (`:122`), tears down (`TeardownRedirect:45`), then bounds the output with `Utils.ApplyOutputCeiling` and answers `{output, truncated}`.
  - `ClassMethod:243` reads `{className, methodName, args, namespace}` and calls `Utils.InvokeWithArgs`, answering `{returnValue, argCount, output, byRefValues, truncated, byRefTruncated, returnValueTruncated}`.
  - `Redirects:424` holds the mnemonic labels. The comment at `:85` says the sibling maps its package to `%ALL` so `^$ZNAME` resolves after the switch; OcuPilot's package is not mapped there (inference that the redirect fails in another namespace; Task 0 measures).
- `src/ExecuteMCPv2/Utils.cls`: `OUTPUTCEILING` 32768 (`:27`, the AC's "harvested output ceiling"), `BYREFNODECEILING` 1000 (`:34`), `ApplyOutputCeiling:324`, `SurrogateSafeCutLength:364`, `ParseArgEntry:394`, `BuildByRefNode:504`, `AddByRefPosition:607`, `InvokeWithArgs:700-973` (the 20-argument ladder and the shared budget). About 580 library lines join the class-method body.
- `src/ExecuteMCPv2/Setup.cls:73,89`: the sibling's web application resource is `%Development`.
- Catalog (`research/.../feature-catalog.md:617-618`): DT-05 and DT-06, both `write-confirm`, backing "custom(ExecuteMCPv2.REST.Command ...)", classic page "new".

### Vendor bar

- `irissys/%Atelier/v7/TerminalAgent.cls:10,375`: the vendor's web terminal (`/api/atelier/%SYS/terminal`) refuses without `%Development:USE`. The portal has no command page, so this and terminal programmer mode are the bar.

### OcuPilot seams

- `src/OcuPilot/Port/DevToolPort.cls` (378 lines): endpoints `:52-55`, `Endpoints():125`, `Invoke:151` (gate, namespace pairs, validation, then `HarvestPortClass()`), `Deny`/`Refuse`/`Fail` `:353-370`, `Snippet`/`SnippetForm` `:341-347`.
- `src/OcuPilot/Port/HarvestPort.cls:76` `Invoke`: wraps the body in `%SYS.Capture` and discards its device output (`:125-142`); a body's error render becomes `INTERNAL`/`PORT.*` with the text logged, never sent (AD-39).
- `src/OcuPilot/Screen/Tool/ExplorerSqlRun.cls`: the model for a write that runs caller-chosen code (`PORTCLASS` `SqlPort` `:40`, `READTYPE` `GUARD` `:49`, `DESTRUCTIVE` 1 `:61`). `Kernel/Governance/Baseline.cls:215,217`: `explorer.sqlquery.run` and `explorer.sqldata.save` ship `false`.
- `src/OcuPilot/Kernel/State/Base.cls:183-376`: every guarded method escalates through `OcuPilotState`. `Switch.SetGuarded:165` and `Policy.GuardedApply:73` check no caller privilege; `Api/Governance.cls:43,71` checks `IsAdministrator()` before calling them.
- `ui/src/app/areas/system-explorer/dev-tool.page.ts` (277 lines) and `dev-tool.store.ts` (68 lines).

## Tasks & Acceptance

Pending the ruling.

## Design Notes

**Owner answer U-78 (2026-11-16, "C: fix U-79 first, then A (Recommended)"), condition met:** the DW-2634 fix (Story 21.30) is on feature (orchestrator, run 43850988016). Both consoles are built as a named AD-10 exception: a person's alone, off by default, gated as the vendor terminal is, every run confirmed with its consequence named. Story 24.5 built the mechanism and the spine now carries it (AD-10 "Code a person runs through OcuPilot", AD-22's `PERSONGATE` exception, AD-53's unadvertised person-only tools, all citing U-86): each console declares `PERSONGATE` with its own refusal code and a key shipped `false`; the AD-10 paragraph already names Stories 24.6 and 24.7. At this story's spec gate the runner extends AD-53 (and AD-22's named tool list) with this story's tools, citing U-78.


### The blocking question (intent gap, AD-10)

**AD-10's Rule:** "Every item here is refused on the instance, on the write path, whatever the caller", its predicates are "evaluated against the resolved target at the moment of the write", and "A self-protection rule that a screen enforces only in its UI is not a prohibition."

What the plan found:

1. **No target to judge.** A command or a class method runs with the signed-in person's rights. A caller who holds the privileges can delete `_SYSTEM`, disable `%Service_WebGateway`, change OcuPilot's roles, or delete `OcuPilot.*` classes in one line. No predicate on the write path can see what the code will do.
2. **OcuPilot's own state is reachable by any caller, not only a privileged one.** `Test/State.TestEscalationIsWhatGrantsTheDeniedUserAccess` (measured, pinned) shows a user refused `<PROTECT>` on a direct write succeeds through the guarded storage methods. `Switch.SetGuarded` and `Policy.GuardedApply` check no caller, and the governance API's `IsAdministrator()` check sits above them. So one console line could turn off the kill switch or enable every governance key for a `%Developer` who is not an OcuPilot administrator (inference: not executed end to end). The same path exists today through the vendor's web terminal; it is recorded in `deferred:` for the lead to harvest.
3. **A text screen is not sound.** Refusing a command that names `ocupilot` stops a literal reference only: `$ClassMethod("Ocu"_"Pilot...")`, `Xecute`, indirection and `$Char` pass it. The class-method console's class name can be refused soundly, but not what that method's code does.
4. **The posture against the vendor is not the problem.** Gated on `AtelierPort.Pairs()` (`%Development:USE`) and the namespace's pairs, the console asks what the vendor's web terminal asks. The conflict is with OcuPilot's own AD-10 and AD-9 promises.
5. **The spine names this family case by case, never in general:** the SQL console's "Named gap: a procedure's or function's own code" (AD-10), MDX constructs that run code behind a person's confirmation while the agent refuses them (AD-65), the cube build's source expressions (AD-65), and the try-it console's named gap (AD-57). Each was an AD amendment at a spec gate. No AD names a console that runs caller-typed ObjectScript.

So the console cannot be built without amending AD-10 with a named gap that weakens "whatever the caller". That is a spine amendment and a weakened guarantee (veto window, Rule 20 U7), so this stage cannot decide it.

### Options

- **A (recommended).** Amend AD-10 with a named gap for the two consoles, and build them person-only:
  - Gate: `AtelierPort.Pairs()` then `NamespacePairs(ns)`, as `DevToolPort` already does. Never looser than the vendor's terminal.
  - Both write tools are unadvertised (AD-53's named case, as `explorer.sqldata.save` and Story 21.5's node writes). The agent never proposes code to run: the model is assumed compromised (NFR-6), and a command, unlike a SQL statement, has no classification to refuse on. This follows AD-65's "an agent read tool never executes code".
  - Each run asks a confirmation that names the consequence, on AD-65's precedent.
  - Defense in depth, stated as not a prohibition: the class-method console refuses a class in an `OcuPilot` package (`PROHIBITED.OCUPILOTCODE`), and the command console refuses text naming an OcuPilot stem in any case.
  - Proposed AD-10 sentence: "**The command and class-method consoles (Story 24.6)**: a person's own run executes with that person's rights, as the vendor's terminal does, and can reach every arm of this set, OcuPilot's protected state through its storage classes included. Named gap: what the code itself does. The consoles are person-only, gated on `%Development:USE` and the namespace's pairs, confirm each run, and refuse a literal reference to OcuPilot's own names as a screen, not a prohibition."
  - Two smaller amendments ride with it: AD-39's eighth exception (output, return value, by-reference values and error text reach the screen only), and an AD-53 named gap if Task 0 measures that the vendor audits no run.
- **B.** A, plus admission: refuse a caller who holds `%All`, `%Admin_Secure`, `%Admin_Manage` or `%Admin_Operate`, or WRITE on the install namespace's routines database. Not recommended: it does not close item 2, which any caller reaches, and it shuts out the administrators the tool is for, which the owner's developer-tool-first rule argues against.
- **C.** Close item 2 first, in its own story: the guarded storage methods refuse a caller outside OcuPilot's API and turn. Then A. This changes AD-9 and is out of this story's scope.
- **D.** Exclude DT-05 and DT-06 (P4, exclusion register). Reason: "OcuPilot cannot keep AD-10's self-protection for code a person types; the vendor's terminal serves it." Gate: "AD-10 names a gap for caller-written code." Dropping scope is owner-only.

### Prepared for the re-plan under A (decided in-stage, reversible)

- **Size.** One implement pass is reachable with named limits: two endpoints on `DevToolPort` (`Command`, `ClassMethod`), one harvested body class `Port/Harvest/Command.cls` plus the five `Utils` library methods as a mixin (24.1's rename-table model), two descriptors on one System Explorer screen with two tabs, and `dev-tool.page.ts` extended.
- **Governance keys:** `explorer.command.run` and `explorer.classmethod.run`, default `false`, destructive. A person's own run asks no key (AD-22, AD-53).
- **Task 0 measures:**
  1. whether the body's `"^"_$ZNAME` redirect resolves after a switch to a namespace OcuPilot is not mapped into. If it does not, the port runs the body in the install namespace and the body's own `namespace` switch does the rest, or the port is extended (never the body);
  2. whether `HarvestPort`'s `%SYS.Capture` and the body's own redirect nest without losing the body's captured output;
  3. whether the vendor writes an audit event for a run;
  4. whether `$System.Alarm`, as `SqlPort` uses it, stops a runaway command. Named limit either way: code that catches `<ALARM>`, or runs past the gateway timeout, keeps its CSP worker until it ends, as the cube build's does (AD-65).
- **Hermeticity.** Tests run only commands and probe class methods that touch a `^||` node or a probe class in `USER`, which each test makes and removes.

### Proposed strings (veto item, for the re-plan)

- Titles: "Command console" · "Class method console".
- Confirmation: "This runs ObjectScript as you, with your rights. OcuPilot cannot check what it changes, including OcuPilot itself."
- Truncation note: "Output was cut at 32,768 characters."

### Governing ADs (to confirm at the re-plan)

AD-10 (the conflict), AD-9, AD-23, AD-29, AD-61 rule 1, AD-36, AD-39, AD-53, AD-22, AD-65 (precedent), AD-57 (precedent), AD-60, AD-7, AD-16, AD-21. There is no `## Deferred` row on either surface.

## Verification

Pending the ruling.

## Auto Run Result

Status: blocked
Blocking condition: intent gap -- AD-10. The consoles run caller-typed ObjectScript or a caller-named class method with the person's rights, so every arm of AD-10's prohibited set is reachable, and OcuPilot's protected state is reachable by any caller through the guarded storage methods (measured: Test/State.TestEscalationIsWhatGrantsTheDeniedUserAccess). No write-path predicate can see what code does, and a name screen is bypassed by indirection, so "refused on the instance, on the write path, whatever the caller" cannot hold. Recommended resolution (option A): amend AD-10 with a named gap for the two consoles, built person-only (unadvertised write tools, keys `explorer.command.run` and `explorer.classmethod.run` default false), gated on `%Development:USE` and the namespace's pairs as the vendor's web terminal is, each run confirmed with its consequence named, with a literal OcuPilot-name refusal as defense in depth only, plus AD-39's eighth exception. Options B to D and the prepared shape are in Design Notes. A further split of 24.6 is not available. Separately, the guarded-storage escalation path is recorded in `deferred:` for harvest (out of footprint).
