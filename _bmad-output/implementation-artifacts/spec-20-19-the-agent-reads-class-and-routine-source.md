---
title: "Story 20.19: The agent reads class and routine source"
type: 'feature'
created: '2026-10-08'
status: 'done'
baseline_revision: 'f69ec5ccf275183a2c7da1b1476bd7986dba0240'
baseline_commit: 'f69ec5ccf275183a2c7da1b1476bd7986dba0240'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-20-context.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** The agent cannot read a class's or routine's source: a document's text never reaches a tool (AD-36). The owner reversed that for the source read on 2026-10-08: "Yes it should send the code." (Q2, kept). The agent's saves are Story 20.21 and its creates Story 20.20; this story ships only the read.

**Approach:** one read tool per kind answers one document's text. The text is cut at whole lines so it serializes to at most 60,000 characters, the cut is reported, and the result reaches the model through AD-60's sanitizer like every tool result. There is no on/off switch for the read (owner, 2026-10-08).

## Boundaries & Constraints

**Always:**

- **Names.** The reads bind to the viewer screens `explorer.class` and `explorer.routine` (descriptors `ExplorerClassDocument`, `ExplorerRoutineDocument`). Their declared reads already hold `explorer.class.read` and `explorer.routine.read`, so the two tools are `explorer.class.source` and `explorer.routine.source` (Design Notes, Names; the spine's Tool naming row).
- **The source read.**
  - Input `{name}`: one document, as the viewer's `name` criterion takes it (maxLength 256).
  - Gate: the viewer's pairs (`Gate.Evaluate`), then the port's own gate.
  - It reads through `AtelierPort.Invoke(<Class|Routine>, "LIST", name, form "udl", namespace Scope.Current())`, as `ExplorerSaveProbe.Document` does.
  - Answer `{name, namespace, lines, linesSent, truncated, text}`.
    - `text` is the first `linesSent` lines joined by LF, kept whole while their JSON-escaped length is at most `SOURCEMAXLENGTH` (60,000). A string's escaped length is `$Length([s].%ToJSON()) - 4`, plus 2 for each LF.
    - A first line longer than that alone is cut to fit.
    - `lines` is the document's line count.
  - A document whose text the instance does not keep (`available` false) answers 404 `PORT.NOTFOUND`.

**Never:**

- No agent save, create or advertised Save: `explorer.classes.save` and `explorer.routines.save` stay person-only and unadvertised until Story 20.21, and `explorer.sqldata.save` is unchanged.
- No change to a person's Save or the editors.
- No governance key for the reads, and no on/off switch.

## I/O & Edge-Case Matrix

Setup: in process as the suite account in `USER`, on probe documents made by `ExplorerSaveProbe` / `ExplorerProbe` (`OcuProbe193`), removed afterwards. The plan adds the routine row and any row its open security-posture check needs.

| Scenario | Input / State | Expected | Error |
|---|---|---|---|
| Read | `explorer.class.source {name: OcuProbe193.Alpha.cls}` | `text` equals `ExplorerSaveProbe.Source`; `truncated` false; `linesSent` = `lines` | none |
| Read cut | A probe class whose text escapes to more than 60,000 characters, quotes and backslashes included | `truncated` true; `text` is whole lines; serialized `text` at most 60,000; `linesSent` < `lines` | none |
| Read refused | `name` `Bad`; an absent class; a screen pair denied | 400 `PORT.VALIDATION`; 404 `PORT.NOTFOUND`; 403 `AUTH.NOPRIVILEGE` | no read |

</intent-contract>

## Code Map

**Names.** The two tools are `explorer.class.source` and `explorer.routine.source` (Design Notes, Names).

Server (`src/OcuPilot/`):

- `Screen/Tool/ExplorerSqlRead.cls` -- the template for a read with a class of its own: declaration :25-58, `PrivilegePairs` :63-66, `SecretArguments` :70-74, closed `ResultSchema` :80-105, `View` :117-186 (argument refusal :125-129; screen gate and `Kernel.Denial` fault :130-137). Discovery (`Registry.ListTools` :106-147) is the registration.
- `Screen/Tool/Registry.cls` -- header :11-17 and `Claim` :727-745: a name two sources claim refuses the whole listing. `TOOLNAMEPATTERN` :33.
- `Port/AtelierPort.cls` -- `Invoke` :830 (`maxRows` :938-942, one document :960); `Document` :2584-2678 answers `{name, form, available, content, modified, ...}`, a bad name 400 `PORT.VALIDATION`, an absent one 404 `PORT.NOTFOUND`. Keys `NAMESPACEKEY` :453, `MAXROWSKEY` :456, `NAMEKEY` :477, `FORMKEY` :480; `ENDPOINTCLASS` :90, `ENDPOINTROUTINE` :93; `REASONNOTFOUND` :557.
- `Kernel/Agent/Dispatch.cls` :323-346: a result with no `rows` skips `Bound` and takes `Capped` :790-841 (total only). `Kernel/Agent/Loop.cls` :463-470 and :511: one 65,536-character budget per model reply, shared by its calls; :638 `Sanitize.Results` (AD-60).
- `Kernel/Agent/Bound.cls` :80-82: the surrogate-pair guard the first-line cut copies.
- `Screen/Context.cls` `ScreenTools` :164-245: lists every advertised read bound by `DESCRIPTORCLASS`, so the viewers' context `tools` gain the reads with no edit.
- `Screen/Descriptor/ExplorerClassDocument.cls` and `ExplorerRoutineDocument.cls` :5-9: the header says the read tool never sees `document`.

Test templates:

| Need | Template |
|---|---|
| Probe documents in `USER` | `Test/ExplorerSaveProbe.cls` (`Document` :24, `Source` :45; `ExplorerProbe.MakeClass` :26, `MakeRoutine` :38, `Remove` :150); `Kernel.Scope.Set` / `Clear` |
| Object-only routine | `Test/AtelierPortDocument.cls` :211-218 (`AtelierPortFixture.UseFakeRoutes`, `SetVersion`, `SetResources`, `Arm`, `Clear`) |
| A pair denied at dispatch | `Test/ScreenRefusal.cls` `Refused` :44-55 (`ToolDispatchProbe.DenyPair`, `Answer`, `Reset`) |
| A turn over the wire | `Test/SqlAgentRead.cls` `OnBeforeAllTests` :57-78 (USERA with `%Development:U` and the namespace's code database), `TestATurnReadsRowsFramedAsData` :299-338 (`TurnProvider.Script`, `Recorded`; `TurnWireFixture.Unwrapped`) |
| Seeded injection | `Test/InjectionSeed.cls` `Plant` :168 (`h` :198), `Remove` :227 (`h` :244), `ReadCall` :623 (`h` :640); `Test/InjectionChannels.cls` `ReadSource` :182, `TestClassDescription` :261 |

## Tasks & Acceptance

**Execution:**

- `src/OcuPilot/Screen/Tool/ExplorerSourceRead.cls` (new, `[ Abstract ]`, extends `Screen.Tool.Base`) -- the shared read.
  - `KIND` read; `SOURCEMAXLENGTH` 60000; `NAMEHINT` (set by each subclass); abstract `Endpoint()`.
  - `InputSchema`: closed, `name` a string, maxLength 256, required, described by `NAMEHINT`. `PrivilegePairs`: `Gate.RequiredPairs(..#DESCRIPTORCLASS)`. `ResultSchema`: closed, the six members required. No `SecretArguments` here: an abstract intermediate declares none of its own (DW-1121, pinned by `ToolWrite.cls` :355-361).
  - `View` as Boundaries, with `ExplorerSqlRead.View`'s refusal shapes. It sends `maxRows` 1 (the rows are not answered). `available` false is 404 built with `Kernel.Fault.Build(Api.Error.#NOTFOUND, Api.Error.#PORTNOTFOUND, AtelierPort.#REASONNOTFOUND)`. A port refusal passes through unchanged.
  - `ClassMethod Cut(pLines As %DynamicArray, pMax As %Integer, Output pSent As %Integer, Output pTruncated As %Boolean) As %String`, public and pure, the one home of the cut. Each line is measured from a `%DynamicArray` it was `%Push`ed into with type `"string"`, because a numeric-looking line otherwise serializes unquoted. A first line over `pMax` is cut at a character boundary, never ending on a high surrogate.
- `src/OcuPilot/Screen/Tool/ExplorerClassSource.cls` and `ExplorerRoutineSource.cls` (new) -- `TOOLNAME` `explorer.class.source` / `explorer.routine.source`; `DESCRIPTORCLASS` the viewer; `Endpoint` `ENDPOINTCLASS` / `ENDPOINTROUTINE`; `NAMEHINT` the viewer's own `name` hint (descriptor :58); `SecretArguments` declared none, on each class. `DESCRIPTION` says, in order: it reads one document's source text in the turn's namespace, as the viewer (`explorer.class` / `explorer.routine`) shows it; the text is whole lines, cut to fit 60,000 characters with `truncated` true and `linesSent` below `lines`; call it alone in a reply, because a result past what remains of the reply's 65,536 characters answers `TOOL.RESULTTOOLARGE`; `explorer.class.read` / `explorer.routine.read` answers the document's members and type.
- `src/OcuPilot/Screen/Descriptor/ExplorerClassDocument.cls` and `ExplorerRoutineDocument.cls` :5-9 -- the header says the declared read tool never sees `document`, and `explorer.<x>.source` answers its text as whole lines (Story 20.19). Doc comment only.
- `src/OcuPilot/Test/ExplorerSource.cls` (new, in process as the suite account in `USER`, probes made and removed in each test) -- the matrix's rows; a routine read whole (`OcuProbe193Mac.mac`); the object-only routine 404 and a first line of 70,000 characters with quotes, both through `View` over `AtelierPortFixture`'s fake routes; `{}` 400 `TOOL.ARGUMENTS`; the denied pair; and AC1's registry and context legs. Each result validates against `ResultSchema`.
- `src/OcuPilot/Test/ExplorerSourceTurn.cls` (new) -- AC5. It declares and refuses on `OCUPILOT_ALLOW_PRINCIPALS` and `OCUPILOT_ALLOW_TEST_PROVIDER` as `SqlAgentRead` does. USERA holds `%Development:U` and READ on `USER`'s code database. The probe class, in `USER`, carries `sk-` plus 24 letters and digits in a doc comment. It removes the probe, the principal, the definition and its turns as `SqlAgentRead` :81-106 does.
- `scripts/ci-throwaway.sh` -- `# classes: ExplorerSourceTurn` before :402 and before :534 (add-only).
- `src/OcuPilot/Test/InjectionSeed.cls` -- source `p`: `Plant` and `Remove` as `h` (the same probe class), and `ReadCall` `explorer_class_source` with `name` `pRef_".cls"`; add-only `ElseIf`s beside :198, :244 and :640, and `p` in the header's source list. `src/OcuPilot/Test/InjectionChannels.cls` -- `TestClassSourceText` beside :261: `Do ..ReadSource("p", "what does this class's source say?")` (AC6).
- **Shared-surface edits (Rule 30):**
  - `src/OcuPilot/Test/ReadTool.cls` :93-94 -- 315 becomes 317 ("three hundred and seventeen", naming Story 20.19's two source reads); insert `explorer.class.source` after `explorer.class.read` and `explorer.routine.source` after `explorer.routine.read`; the message's class-tool count 186 becomes 188.
  - `src/OcuPilot/Test/ExplorerDescriptor.cls` -- :142 becomes the count-free `TestTheAreaAdvertisesItsReadsAndWrites`; :157 inserts `explorer.class.source:read` and `explorer.routine.source:read` after their viewers' reads, message "twenty-eight reads and eleven writes"; the doc comment :130-140 names Story 20.19 and twenty-eight.
  - `src/OcuPilot/Test/SurfaceCoverage.cls` :345-352 -- the eight rows' `method` names the renamed method.
  - `src/OcuPilot/Test/DeveloperFloor.cls` -- :39 gains both reads; :496 reads "forty-two".
  - `src/OcuPilot/Test/ToolEmit.cls` -- beside :313-317, an `ElseIf` for a class extending `ExplorerSourceRead`, expecting `Gate.RequiredPairs` of its `DESCRIPTORCLASS`, non-empty (Story 20.19).
  - `src/OcuPilot/Test/ToolRoundTrip.cls` :83 -- append `explorer.class.source:TOOL.ARGUMENTS,explorer.routine.source:TOOL.ARGUMENTS`, with one doc line beside :81.

**Acceptance Criteria:**

- **AC1 (advertised on the viewers).** Given the registry, when the provider tool list, the dispatch lookup and the two viewers' screen context are built, then each source read is an advertised read requiring exactly its viewer's effective pairs, and `explorer.class`'s context `tools` reads `["explorer_class_read","explorer_class_source"]` (the routine viewer's likewise), while the editors' stay `[]`.
- **AC2 (the cut).** Given a document whose text escapes past 60,000 characters, or whose first line alone does, when it is read, then `text` is whole lines (or the first line cut) escaping to at most 60,000 characters, the next line would not fit, `truncated` is true and `linesSent` is below `lines`.
- **AC3 (routines and object code).** Given a probe routine, when `explorer.routine.source` reads it, then `text` is its whole text; and given a routine the instance keeps only as object code, the read answers 404 `PORT.NOTFOUND`.
- **AC4 (the viewer's pairs).** Given `%Development:USE` denied, when the model calls `explorer_class_source`, then it reads `AUTH.NOPRIVILEGE` naming `%Development:USE` and the screen `explorer.class`.
- **AC5 (Integration: the provider request, AD-60).** Given a real turn on `ocupilot-b-ci` as a principal holding the viewer's pairs, when the scripted model calls `explorer_class_source` on a probe class in `USER`, then the next provider request's `tool_result` is wrapped in `<ocupilot-data>`, carries the class's lines, and reads `[redacted]` where the class holds the `sk-` key.
- **AC6 (untrusted text, AD-11).** Given a seed in a probe class's source (source `p`), when a real turn reads it through `explorer.class.source`, then the seed arrives inside a `tool_result` and `InjectionChannels`' invariants hold.
- **AC7 (nothing else moves).** Given this story, when `ExplorerSave`, `SqlDataSaveRoutes` and `GovernanceBaseline` run unchanged, then the two saves and `explorer.sqldata.save` stay unadvertised and their keys unchanged, and no governance key, client file or string is added.

## Spec Change Log

- 2026-10-08, runner, spec gate: the intent contract's names follow the plan's finding (the viewers' declared reads hold `.read`), so it names `.source` throughout; the AD-36, AD-24 and Tool naming amendments are applied to the spine.

- 2026-10-08, runner, orchestrator rulings on the first plan (by=merge_gate, feature 2bc6d842): Q3 split. This spec keeps Part A, the source read; Part B (the saves) is Story 20.21, which reads the first plan at `git show eda69374:_bmad-output/implementation-artifacts/spec-20-19-the-agent-edits-existing-classes-and-routines-on-the-person.md`. Q1 A and Q2 A are 20.21's. The read tools are named by the spine's convention. Status reset to draft for a re-plan.

## Review Triage Log

## Design Notes

**Names: `explorer.class.source` and `explorer.routine.source`, not `.read`.** The viewers already carry a read: `ExplorerClassDocument` :50-62 and `ExplorerRoutineDocument` :50-62 declare one, which the registry lists as `explorer.class.read` and `explorer.routine.read` (pinned in `ReadTool.cls` :94, `ExplorerDescriptor.cls` :157, `DeveloperFloor.cls` :39; called in `InjectionSeed.cls` :641). A class tool claiming either name makes `Registry.Claim` (:727-731) refuse the whole tool listing, so no tool would be offered. Folding the text into the declared read was rejected: the contract's input `{name}` and answer shape are not the declared read's, the declared read's tool view is its rows under AD-24's per-field cut, and every member listing would then carry up to 60,000 characters. `source` follows the precedent of a second read-kind tool on a screen with a verb other than `read` (`permissions.privileges.check` on the Users list, Story 16.3).

**Governing ADs.** AD-36 (a document's text was screen-only; the reversal), AD-24 (the per-field bound, which `Bound` applies only to row fields), AD-60 and AD-11 (untrusted source, framed and redacted; source `p`), AD-61 (the port's gate and document read), AD-29, AD-8 (the viewer's effective pairs, AD-64 adjustments included), AD-7 (no new shape: the declared read already issues the same `GET doc` in the turn job), AD-10 (the code arm refuses writes; "an export only reads and is not refused"), AD-22 (reads carry no key), AD-53 (the saves stay unadvertised until 20.21).

**Owner's words.** "Yes it should send the code." (2026-10-08, relayed by the Planner). No on/off switch.

**Spine amendments (one line each, for the runner at the spec gate):**

- **AD-36, line 717:** replace "A document's whole text stays the screen-only payload beside the rows and never reaches a tool." with "A document's whole text stays the screen-only payload beside the rows; the agent's source reads, `explorer.class.source` and `explorer.routine.source` (Story 20.19), are read tools, not declared reads, and answer it as whole lines escaping to at most 60,000 characters with the cut reported, through AD-60 (owner, 2026-10-08: "Yes it should send the code."). Named limit: a credential a person wrote into their source as a literal reaches the model unless it matches one of AD-60's shapes."
- **AD-24:** "Named exception: the source reads' `text` (Story 20.19) is one field bounded by its own cut, whole lines escaping to at most 60,000 characters, in place of the 1,000-character field bound; the total bound still applies, so a read past what remains of its reply's budget answers `TOOL.RESULTTOOLARGE`." Needed, as checked: AD-24's Rule puts the field bound on every read tool result, while `Bound.Apply` cuts only row values (:64-99) and a result without `rows` goes to `Capped`, which bounds the total alone (`Dispatch` :332-346).
- **Conventions, Tool naming (line 1215):** append "A viewer whose declared read already holds `<screen>.read` names its source read `<screen>.source` (`explorer.class.source`, `explorer.routine.source`, Story 20.19)."
- **AD-8:** none. The reads declare exactly the viewer's effective pairs, as `explorer.sqlquery.read` declares its screen's, and the port adds the namespace's database pairs at call time (AD-61 rule 1).

**Posture:** no new refusal and no open question: the reads answer only what the person can open in the viewer (its effective pairs, then the port's database pairs); AD-10's code arm already lets a read of OcuPilot's own code through ("an export only reads and is not refused"), OcuPilot's source is published, and `%` and `%SYS` source ships with the instance; a credential literal in a person's own source is covered by the owner's ruling and named in AD-36's amendment.

**Named limits.**

- A read shares its reply's 65,536-character budget with that reply's other calls (`Loop` :463-470): a full-size read after about 5,000 characters of earlier results answers `TOOL.RESULTTOOLARGE`, and the model can re-read it alone, as the description says.
- Each later provider call in the turn carries the text again: about 15,000 tokens per full read (inference), within the turn's 500,000.

**Integration ACs (Rules 1 and 2).** AC5 is the Integration AC: the turn loop and the provider request consume the new tools on a real instance.

- **Consumes:** `AtelierPort`'s document read (Story 19.1); `Gate.RequiredPairs` and its adjustments (20.15); dispatch's screen-named refusal (20.18); AD-60's sanitizer (14.3).
- **Consumed-by:** Story 20.21, through the model: it copies each `Old` from this text. Its mint does not consume the tool: it reads the document through `AtelierPort.Invoke` itself. Stories 20.20 and 20.16 have the model read neighbouring or current source before proposing.

**Rule 11** (checked 2026-10-08 against `epic-18` `origin/feature...HEAD` and `status -s`; Epic 18 is implementing 18.29, which adds `Screen/Tool/UserCopy.cls`):

| File | Edit | Status |
|---|---|---|
| `Test/ToolRoundTrip.cls` :83 | two entries | CONTENDED: Epic 18 rewrites this line; cleared on union terms (orchestrator, Q2), keep both sides' entries |
| `Test/SurfaceCoverage.cls` :345-352 | eight rows' method name | CONTENDED, non-add-only (Epic 18 edits elsewhere in the file); cleared on union terms |
| `scripts/ci-throwaway.sh` | two `# classes:` lines | add-only (Epic 18 edits the file) |
| `Test/ReadTool.cls` :93-94 | count and list | not in Epic 18's diff today; 18.29's `UserCopy` tool will change the same line (inference), so the forward merge takes the union and sums the counts |
| `Test/ExplorerDescriptor.cls`, `DeveloperFloor.cls`, `ToolEmit.cls`, `InjectionSeed.cls`, `InjectionChannels.cls`, the two descriptors | as Tasks | not in Epic 18's diff |

No edit to `Baseline.cls`, EXPERIENCE.md, `strings.ts` or any client file.

**Ledger and standing rules.** The inbox is empty. FR-80: no write, so no field list. DW-2096 declined: `SqlPort.PASSWORDPATTERN` spans a whole text under `(?s)` and would rewrite source lines such as `Property Password`, which 20.21's edits copy verbatim. DW-1337 and 11.3's prompts: no client or screen change. No new error code.

**Budgets.** Client: no file changes, so +0 kB against the 3,326 kB warning. Fixed strings: +0.

## Verification

**Shared surfaces (Rule 30):** the registry's roster and count (`ReadTool`); the System Explorer area's advertised tools (`ExplorerDescriptor`, and `SurfaceCoverage`'s method names); the developer's held tools (`DeveloperFloor`); the per-class pair branches (`ToolEmit`); the empty-call refusals (`ToolRoundTrip`); the provider tool list and the two viewers' context `tools`; the seeded-injection sources (`InjectionSeed`); `ci-throwaway.sh`'s arming rosters.

**Standing criterion (Rule 30):** existing tests that assert a surface this story changes are updated in this story, and every test the story adds or changes passes on a freshly built instance and in either order.

**Setup (slot B):** sync with `rsync -a --delete /Users/jbrandt/git/OcuPilot/.worktrees/epic-20/src/ /Users/jbrandt/.ocupilot-throwaways/ocupilot-b-ci/src/`, then load in `docker exec -i ocupilot-b-ci iris session iris -U HSCUSTOM` with `$System.OBJ.LoadDir("/opt/ocupilot/src/OcuPilot","ck-d",.tErrors,1)`, checking the status and `tErrors`. One class per runner call; never re-submit after a client-side timeout.

**Commands:**

- `(loop)` `uv run scripts/check-objectscript.py` -- expected: 0 problems.
- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.<C>`, one class per call -- expected: 0 failed, read back from `%UnitTest_Result`. Classes: new `ExplorerSource`, `ExplorerSourceTurn`; edited `ReadTool`, `ExplorerDescriptor`, `SurfaceCoverage`, `DeveloperFloor`, `ToolEmit`, `ToolRoundTrip`, `InjectionChannels`; re-run `ExplorerSave`, `SqlDataSaveRoutes`, `GovernanceBaseline`, `ScreenRefusal`, `ToolSetFull`, `AtelierPortDocument`.
- `(loop)` `cd ui && npm run test:tools` (the `ci-throwaway.sh` rosters in `tools/ci.test.mjs`) -- expected: pass.
- `(once, before dev_complete)` the full ObjectScript sweep, `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci` -- expected: 0 failed; then `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS` -- expected: pass.
- `(CI)` The browser suite runs in CI's shards only (Rule 29). This story adds and changes no browser spec and no client file.

**Planned pinning mutations (Rule 19).** Apply each, observe red, revert to a byte-identical tree, and record a `mutation:` line here.

| AC | Mutation | Expected red |
|---|---|---|
| AC1 | `ExplorerClassSource` `ADVERTISED` 0 | `ExplorerSource` registry and context legs; `ExplorerDescriptor` area roster |
| AC2 | `Cut` measures the raw `$Length` of each line | `ExplorerSource` long-class leg |
| AC2 | `Cut` drops the first-line cut | `ExplorerSource` first-line leg |
| AC3 | `ExplorerRoutineSource.Endpoint` answers `ENDPOINTCLASS` | `ExplorerSource` routine leg |
| AC3 | `View` ignores `available` | `ExplorerSource` object-only leg |
| AC4 | `PrivilegePairs` answers `""` | `ExplorerSource` denied leg |
| AC5 | `Kernel/Agent/Loop.cls` :638 skips `Sanitize.Results` | `ExplorerSourceTurn` wrapper and `[redacted]` legs |
| AC6 | `Loop.Run` appends the last `tool_result` content to the system prompt | `InjectionChannels.TestClassSourceText` |
| AC7 | `ExplorerClassSave` `ADVERTISED` 1 | `ExplorerSave`'s roster leg |

mutation: AC1 `ExplorerClassSource` `ADVERTISED` 0 red in ExplorerSource's advertised, context-tools and provider legs (and its denied-pair leg, the tool no longer resolving); ExplorerDescriptor not run under it.
mutation: AC2 `Cut` measuring raw `$Length` red in ExplorerSource's long-class leg (62,709 escaped) and its cut-counting leg.
mutation: AC2 `Cut`'s first-line branch disabled red in ExplorerSource's wide-first-line leg.
mutation: AC3 `ExplorerRoutineSource.Endpoint` answering the class endpoint red in ExplorerSource's routine and object-only legs.
mutation: AC3 `View` ignoring `available` red in ExplorerSource's object-only leg.
mutation: AC4 `PrivilegePairs` answering `""` red in ExplorerSource's denied-pair and pairs-equality legs.
mutation: AC5 `Loop.cls` :638 skipping `Sanitize.Results` red in ExplorerSourceTurn's wrapper, `[redacted]` and key-absent assertions.
mutation: AC6 `Loop.Run` appending the last `tool_result` blocks to the system prompt red in InjectionChannels.TestClassSourceText (invariant 1 on call 2, the stub obeyed); 15 sibling sources red too.
mutation: AC7 `ExplorerClassSave` `ADVERTISED` 1 red in ExplorerSave.TestTheSaveIsAbsentFromEveryRosterTheAgentSees.

## Auto Run Result

Status: done
Blocking condition: none

The implement stage's handoff ran detached after its stage returned (harness default, Rule 18 item 5); the runner reconciled its finished work into one commit. Its own report: full ObjectScript sweep on `ocupilot-b-ci` 526 classes, 4,169 tests, 0 failed; `check-objectscript.py` 0 problems; `test:tools` 1900/1900; smoke 50/50; nine mutations red and restored. Build-auto's own review layers did not run; QA and code review follow.
