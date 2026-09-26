---
title: 'Story 11.11: The screen shows what the agent is talking about'
type: 'feature'
created: '2026-09-26'
status: 'done'
baseline_revision: '0c5317cb2b99de99ba5a93ecd8e3a4739df27447'
baseline_commit: '0c5317cb2b99de99ba5a93ecd8e3a4739df27447'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** The audit database (`logs/audit`) and the all-task history (`tasks/history`) open on an empty criteria form and read nothing until Search. When the agent opens one and describes rows, the person sees none. The navigation tool can name only a flag (`criterion: "marker"`), so it cannot pass on the window or the text its read used.

**Approach:** The declared read gains a server-side default window, so the screen and the read tool apply the same default (AD-36). The audit's `beginDateTime` defaults to 24 hours before instance-local now. Task history gets a new `since` criterion, applied on the instance over `LogDatetime`, that defaults to 7 days. The read's answer reports the criteria it applied. `shell.screen.open` gains a `criteria` object. Each value is validated on the instance against the target's declared criteria, and the arriving screen runs exactly that search.

## Boundaries & Constraints

**Always:**

- The default applies only when a caller **omits** a criterion. An explicit empty value means the bound is unset, as it does today. The route and the tool apply this rule identically.
- Both screens read once on open, newest first, within the screen's remembered row limit.
- Each field the request left absent is filled from the answer's `criteria`. The audit shows its `beginDateTime`, and task history shows `since`. An end bound left blank means "now".
- An agent arrival carrying criteria issues **exactly one** read. It sends only the criteria the directive carries, so an omitted criterion takes its default, exactly as the agent's own read did. The URL carries only `ns`.
- Validation happens in `Navigate.Directive`, before any announcement. A name the target does not declare is refused `NAV.CRITERIONUNKNOWN`. A value that is not a string, or that the read's own check (`SeedCriteria`) refuses, is refused `NAV.CRITERIONINVALID`. Either refusal carries `detail: {criterion: "<name>"}` and reaches the model as a tool result (AD-39).
- `criterion` (the flag name) keeps its current contract and stays beside `criteria`. The flag overrides its own param, as the marker does today.
- Every value reaches the vendor only as a read criterion (a query parameter) or as an instance-side string comparison. It is never concatenated into SQL (AD-21).
- The default audit search never applies the agent marker (AD-46).
- Every screen keeps its three or more suggested prompts (Story 11.3).
- EXPERIENCE.md is edited in place, with its line count unchanged at 981.

**Never:**

- Criteria in a URL, a route segment or a citation chip. Chips and `entityUrl` stay as they are (Story 11.4).
- Auto-refresh on either screen (AD-43).
- Any change to `AuditSystemEventList` or `AuditUserEventList`.
- A default computed in the browser. The browser clock is not the instance clock.
- A second read path for the tool, or a widened settle vocabulary (`opened` or `refused` + `NAV.REFUSEDUNSAVED` only).
- Edits inside `ui/browser/audit.browser-spec.mjs:534-619`, which Epic 23 is editing. The spine is not edited either; that belongs to the lead.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Audit open | no criteria sent | vendor gets `beginDateTime` = instance-local now - 24 h; answer `criteria.beginDateTime` = that value; form shows it; marker off | async LIST keeps skeleton, then rows or the error presentation |
| Explicit empty | `?beginDateTime=` or tool arg `""` | no `beginDateTime` sent to the vendor (all time); echo `""` | - |
| History open | no criteria | `since` = now - 168 h; rows with `LogDatetime` earlier are dropped before `truncated` is judged; `since` is never sent to the vendor | row with empty `LogDatetime` dropped |
| History cap | port answers cap+1 rows, row cap+1 older than `since` | `truncated` false | cap+1 row in window -> true |
| Arrival | `criteria {eventSources:"OcuPilot", beginDateTime:t0, endDateTime:t1}` | one read with exactly those; fields show them; rows = agent's read rows | - |
| Undeclared | `criteria {nosuch:"x"}`, or any criteria on a screen with none | tool result `NAV.CRITERIONUNKNOWN`, `detail.criterion` = `nosuch` | no directive, no announcement |
| Bad value | `{beginDateTime:"2026-09-26"}` or `{pids:5}` | `NAV.CRITERIONINVALID`, `detail.criterion` names it | as above |
| Return visit | the person has not pressed Search | default re-runs | after a Search, the person's last criteria re-run |

</intent-contract>

## Code Map

- `src/OcuPilot/Screen/Read.cls` -- `Execute:230`. The admin LIST/HISTORY branch is `:354-367`. `tTruncated` is set at `:376`, and the answer is built at `:401-406`. `SeedCriteria:691-741` is public and value-driven: an empty value is skipped at `:707`, `vendorParam` is handled at `:729`, and `DATETIMEFORM:120`. `CriteriaParams:610`. `PortClass` can be overridden, which is how the tests reach `OcuPilot.Test.PortFixture`.
- `src/OcuPilot/Api/ScreenRead.cls:67-73` -- reads each declared param with `%request.Get`, so absent and empty look the same. `$Data(%request.Data(p,1))` separates them (inference; the route test pins it).
- `src/OcuPilot/Screen/Tool/Read.cls` -- `AddCriteria:136-164` has a datetime description at `:155`. `View:180-238` builds `tCriteria` for every param (`:206-211`). `ResultSchema:~80-93` is closed.
- `src/OcuPilot/Screen/Registry.cls` -- `CriteriaFieldsProblem:1328-1403`, with the allowed keys at `:1346-1347` and kinds at `:1391`. `CRITERIARESERVEDPARAMS:1216`. The mirror twin is `ui/tools/screen-mirror.mjs` `criteriaProblem:1399` (keys `:1461-1462`), with the TS template at `:2744-2794`. The shared corpus `OcuPilot.Test.CriteriaCorpus` is checked by `screen-mirror.test.mjs:1056`.
- `src/OcuPilot/Screen/Descriptor/AuditList.cls`, `TaskHistoryList.cls` -- their criteria blocks. Both doc comments say "renders nothing until Search". Correct that at origin.
- `src/OcuPilot/Screen/Tool/Navigate.cls` -- `InputSchema:76-104`, `Directive:177`, and the flag check at `:200-210`. The class doc comment says "`criterion` names a filter; it never carries one". Rewrite it at origin to describe both arguments.
  - `Tool/Registry.cls` `EmitSchema` refuses a nested `properties`, so `criteria` is declared as a bare `{"type":"object"}` and each key is checked in `Directive`.
- The directive's path through the kernel:
  - `Kernel/Agent/Dispatch.cls` -- `ResolveClientCall:419` calls `Directive` at `:541`. The refusal at `:543-545` drops `detail`, although `ErrorContent(pCode, pDetail):704` takes one. The criterion is read at `:558`.
  - `Kernel/Agent/Loop.cls:624,676`.
  - `Kernel/State/Nav.cls` -- `Criterion` is at `:37`, `GuardedRequest` at `:81` and `GuardedPending` at `:98-113`. Adding a property does not move `SCHEMAVERSION` (see the precedent at `:35-36`).
  - `Kernel/State/Turn.cls:511-531` serializes the navigation.
- `src/OcuPilot/Api/Error.cls` -- the NAV parameters are at `:764-796`, their reasons at `:876-891`, `NavCodes():950` and `ReasonForNav:957-966`.
- `src/OcuPilot/Install/Smoke.cls:661-700` -- the audit row expects exactly one row at `maxRows=1`. With a 24-hour default, a quiet instance could answer 0.
- Client audit -- `ui/src/app/areas/logs/audit.page.ts`:
  - `:195` is the null-bind gate that reads nothing on open, and `:202` re-reads on return.
  - Refresh is registered only after a Search (`:208-223`). `onSearch:355-362`.
  - The form is built from the descriptor (`:71-119`). The time hint is at `:105`.
- `audit.store.ts` -- holds `values`, `markerOn` and `searchedOnce` (`:53-57`). Also `criteria():166-174`, `readFor:186-194`, `openWith:225-236` and `reset:81-88`.
- Client task history -- `ui/src/app/areas/tasks/history.page.ts`:
  - The form is hand-written (`:102-120`). The null-bind gate is at `:178`, the read at `:229-231` and Search at `:278-285`.
  - `history.store.ts:22-26,107-112` is one store per `ScreenStore`, held in a WeakMap in the page (`:63-72`).
- Client shared -- `ui/src/app/shell/screen-outlet.ts:83,112`. `ui/src/app/core/screen-read.ts` has `screenReadPath:163-179`, which drops empty values. The precedent for reading on open is `areas/tasks/upcoming.page.ts:156-160`.
- Client navigation:
  - `ui/src/app/core/turn.ts` -- `TurnNavigation:270-280`, `parseNavigation:470-484`, `settleNavigation:1366-1379`.
  - `ui/src/app/shell/agent-navigator.ts:48,92-110,131-134` -- injects `AuditSearch` concretely. With a read on open, it would issue two reads.
- `ui/src/app/core/strings.ts` -- the audit keys are at `:408-424` and cite `EXPERIENCE.md:322-324`. The task-history keys at `:773-791` cite `:371`.
- `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md` -- the IA rows are `:88` and `:107`. The Fixed-strings row is `:371`. The archetype row is `:782` and the exceptions line `:793`. The file has 981 lines.
- Tests that pin today's behavior:
  - Client:
    - `audit.page.spec.ts:225,235,278,394`.
    - `history.page.spec.ts:183,195,262,275`.
    - `ui/tools/history-store.test.mjs:19,47`.
    - `agent-navigator.spec.ts:137,150,156`.
  - Browser:
    - `audit.browser-spec.mjs`: the `search()` helper `:329-338`, and the tests at `:409` (AC1), `:621` (row click), `:738` (the AC6 timing) and `:773` (the AC7 exact reads, no grid).
    - `tasks.browser-spec.mjs:452,633`.
    - `proposal-demo.browser-spec.mjs:576` (the marker hand-off).
    - `screen-height.browser-spec.mjs:63` (a stale comment).
    - `structural-baseline.json`: the `logs/audit` and `tasks/history` keys (`:213-225`, `:1984-2029`).
  - ObjectScript:
    - `ToolNavigate.cls:208` (three properties), `:404` (its doc comment names the audit-only client).
    - `LedgerClientTool/Probe.cls:45` and `ClientCallFault/Probe.cls:41` (the 6-argument `Directive`).
    - `TaskHistory.cls:194,237` (compared against the vendor's whole history).
    - `Descriptor.cls:745`.
    - `ReadTool.cls` (the result schema).
- Stub-provider mechanism -- `src/OcuPilot/Test/TurnProvider.cls`: `ToolUseReply:120` copies `input` verbatim, and `Recorded(tag,n,"messages"):101`. `ui/browser/turnprobe-spec.mjs` provides `armProbeDefinition:171`, `scriptReply:151` and `requireFreeSlot:231`. The navigate pattern is at `navigate.browser-spec.mjs:161-164`. The probe task is `OcuPilot.Test.TaskRunFixture` (`EnsureRunProbeTask:40`, `HistoryHighWater`, `AwaitRun`, `DeleteRunProbeTask`), driven as in `task-run.browser-spec.mjs`.

## Tasks & Acceptance

**Execution:**

- `src/OcuPilot/Screen/Registry.cls` + `ui/tools/screen-mirror.mjs` + `src/OcuPilot/Test/CriteriaCorpus.cls` -- Admit two per-field keys:
  - `defaultHoursAgo`: datetime only, an integer from 1 to 8760.
  - `atOrAfterField`: datetime only, names a `read.fields` member, and cannot be combined with `vendorParam`.
  - Add one corpus sentence per refusal, with the same sentence from both engines. Add both as optional members to the TS `ReadCriterion`.
- `src/OcuPilot/Screen/Descriptor/AuditList.cls` -- Add `"defaultHoursAgo": 24` to `beginDateTime`. Rewrite the "renders nothing until Search" sentences.
- `src/OcuPilot/Screen/Descriptor/TaskHistoryList.cls` -- Add `{"param":"since","labelKey":"taskHistorySince","kind":"datetime","maxLength":50,"defaultHoursAgo":168,"atOrAfterField":"LogDatetime"}` and fix its doc comment.
- `src/OcuPilot/Screen/Read.cls` -- Change `SeedCriteria` and `Execute`:
  - For a declared default: when the param is **undefined** in `pSupplied`, use instance-local now minus N hours (`$Horolog` arithmetic, `$ZDateTime(h,3)`). A defined empty value means unset.
  - Never seed an `atOrAfterField` criterion. Instead, drop rows whose field is lexically earlier before `:376`.
  - Answer `criteria {param: effective value}` for every declared criterion.
- `src/OcuPilot/Api/ScreenRead.cls` -- Set `tCriteria(p)` only when the request carries the key.
- `src/OcuPilot/Screen/Tool/Read.cls` -- In `View`, set a criterion only when `%IsDefined`. Pass `criteria` through, and add it to `ResultSchema`. The datetime description says "Omit to use the screen's default (N hours back); an empty string leaves the bound unset."
- `src/OcuPilot/Install/Smoke.cls` -- The audit row reads `maxRows=1&beginDateTime=`, all time, keeping its meaning.
- `src/OcuPilot/Api/Error.cls` -- Shared-append `NAVCRITERIONINVALID` with its reason "That value is not one this screen's filter accepts.", and add it to `NavCodes`/`ReasonForNav`.
- `src/OcuPilot/Screen/Tool/Navigate.cls` -- Add the `criteria` property, described as "the criteria your read of that screen used (its answer's `criteria`)". In `Directive`, check one key at a time against `CriteriaParams`, then check the string type, then call `SeedCriteria`. Add `Output pCriteria As %DynamicObject` as the 7th parameter, and rewrite the doc comment.
- `Kernel/Agent/Dispatch.cls`, `Loop.cls`, `Kernel/State/Nav.cls`, `Kernel/State/Turn.cls`:
  - `Dispatch` passes `tFault.detail` to `ErrorContent`.
  - Plumb `pCriteria` through.
  - `Nav` gains `Criteria As %String(MAXLEN = 16000)`, holding JSON; `SCHEMAVERSION` stays.
  - The progress payload's `navigation` gains `criteria {}`.
- `Test/LedgerClientTool/Probe.cls`, `Test/ClientCallFault/Probe.cls` -- Add the 7th output parameter.
- `src/OcuPilot/Test/ToolNavigate.cls` -- `:208` now expects four properties. Add tests:
  - the criteria travel onto the progress payload;
  - `NAV.CRITERIONUNKNOWN`, with its `detail`, for `nosuch` and for criteria on `web-applications/list`;
  - `NAV.CRITERIONINVALID` for a bare date and for a number;
  - the flag test still passes.
- `src/OcuPilot/Test/CriteriaDefault.cls` (new) -- Use `PortFixture` to capture the query. Pin these cases:
  - absent means now - 24 h (to within 5 s of the instance time) and is echoed;
  - defined empty sends no key;
  - `since` is never sent;
  - the cutoff and cap+1 truncation cases from the matrix;
  - the tool and the route give the same answer;
  - an HTTP `?beginDateTime=` differs from an absent key.
- `src/OcuPilot/Test/TaskHistory.cls:194,237` and any sweep failure whose reads compare against the whole history -- Pass `since` explicitly empty.
- Client stores and pages:
  - In `audit.store.ts`, `history.store.ts`, `audit.page.ts` and `history.page.ts`, a value is `string | undefined`, where undefined means absent.
  - Open with the default read and fill the absent fields from the echo.
  - Search sends the form as shown; `screen-read.ts` sends `p=` for an explicit empty.
  - Register Refresh after the open read.
  - A return visit re-runs the person's last Search, or the default when there was none.
  - Task history gains the `#ocu-task-history-since` input, with the `auditCriteriaTimeHint` hint.
- `ui/src/app/core/screen-arrival.ts` (new, framework-free) + `agent-navigator.ts` + `core/turn.ts`:
  - `parseNavigation` keeps only the string values of `criteria`.
  - The navigator sets a one-shot arrival `{route, criterion, criteria}` before `navigateByUrl`.
  - The arriving page consumes it once in place of its default. A page that is already mounted is handed it through a subscriber.
  - The arrival is cleared on a refusal. `AuditSearch.openWith` is replaced.
- Client specs:
  - Rewrite the tests named in the Code Map to the new contract.
  - Add `screen-read.test.mjs` (explicit empty is kept) and `turn.test.mjs` (criteria parse).
  - Add `screen-arrival.test.mjs`: one-shot, and the same-route case.
- `ui/src/app/core/strings.ts` -- Add `taskHistorySince: 'Logged since'` citing `/** EXPERIENCE.md:371 */`, next to the task-history keys.
- `EXPERIENCE.md` -- Run `wc -l`, which must read 981 before and after. Rewrite in place:
  - `:88` gains "opens on the last 24 hours, agent marker off".
  - `:107` becomes "search text (vendor filter), a user-defined-only checkbox and a logged-since time; opens on the last 7 days, Search narrows".
  - `:371` gains `"Logged since"`.
  - `:782` cold-load becomes "default search on open, skeleton until it answers, the criteria form showing the values used".
  - `:793` becomes "...search on the server, open on the last 24 hours and the last 7 days respectively, and do not auto-refresh".
- `ui/browser/default-search.browser-spec.mjs` (new) -- Four legs:
  - **(a) Audit.** Seed one uniquely named audit row. Opening the screen issues one read with no `beginDateTime` and shows the seeded row. The begin field equals the answer's echo, and is within 120 s of the instance's `$ZDateTime($H,3)` minus 24 h. The marker is unticked. A narrower Search sends the typed begin.
  - **(b) Task history.** Run the `TaskRunFixture` probe once. Opening the screen issues one read and shows `OcuPilotProbeRunTask`. `since` equals the echo, within 120 s of now - 168 h, and every answered row's `LogDatetime` is at or after `since`.
  - **(c) Audit hand-off.** Arm turnprobe and seed OcuPilot-source rows inside a closed instance window `[t0,t1]`. Script `logs_audit_read {eventSources:"OcuPilot",beginDateTime:t0,endDateTime:t1}`, then `shell_screen_open {route:"logs/audit",criteria:{the same}}`, then a text reply. Assert:
    - the URL has no criteria;
    - one read follows the arrival, carrying all three values, and the fields show them;
    - the grid rows equal the tool-result rows read back through `TurnProvider.Recorded`.
  - **(d) Task-history hand-off.** `criteria {search:"OcuPilotProbeRunTask", since:""}` issues one read carrying both, and every row's Name is the probe task.
  - Teardown deletes the probe task and disarms the definition.
- Browser updates:
  - `audit.browser-spec.mjs` -- `search()` waits for its own read before rows. `:409`, `:621`, `:738` (time from click to the first row of the Search's own response) and `:773` count the open read. Do not touch `:534-619`.
  - `tasks.browser-spec.mjs:452,633`.
  - `proposal-demo:576`, only if it goes red.
  - `screen-height:63`, the comment only.
  - `structural-baseline.json` -- lead ruling 2026-09-26 on the implement-1 intent gap: append exactly the two printed keys `logs/audit|overflow|720|app-status-bar>span.ocu-status-bar-segment.ocu-status-bar-stamp` and `tasks/history|overflow|720|app-status-bar>span.ocu-status-bar-segment.ocu-status-bar-stamp`, each with `"dw": "DW-1584"` (the gate's own "append the printed entry" path; the same root cause is baselined on 33 routes and owned by range-end-cleanup). Entries become 225. Any other new key is still fixed at its cause or HALTs. The status bar is not edited.
- Lead gate addition -- an arrival whose `criteria.eventSources` equals the declared marker value (`OcuPilot`) opens with the marker affordance ticked and the Event source field empty, which sends the identical read, so "filtered to agent-marked events" is what the person sees. Leg (c) asserts the marker reads ticked.

**Acceptance Criteria:**

- Given either screen, when a person opens it, then one read runs at once over the default window, newest first, within the row limit. The form shows the applied values, and Search narrows or widens (an emptied field means unset). Pinned by `CriteriaDefault` and legs (a) and (b).
- Given the agent reads a screen and then navigates to it with the criteria it used, when the screen arrives, then it runs exactly that search and its rows equal the agent's tool-result rows. This is the Integration AC: the consumer is the arriving page, and the effect is equal rows, shown by leg (c) on a real instance.
- Given criteria the target does not declare, or a value its read refuses, when the call is dispatched, then the tool result names the criterion (`NAV.CRITERIONUNKNOWN`/`NAV.CRITERIONINVALID`), and no announcement or directive exists.
- Given EXPERIENCE.md, when the story completes, then the archetype row, `:88`, `:107`, `:371` and `:793` state the default search, `wc -l` is still 981, and `strings.test.mjs` passes.

## Spec Change Log

- 2026-09-26, implement-1 halted on the structural gate (225 vs 223, two status-bar stamp keys, DW-1584). Lead ruling: admit the two keys with `dw: DW-1584`; the rest of the implementation stands as written in the tree.
- 2026-09-26, lead spec gate: AD-11 and AD-36 amendments written into the spine; the structural baseline must not grow (DW-1337, 223 entries); an arrival carrying the marker value ticks the marker affordance.

## Review Triage Log

### 2026-09-26 — Review pass

- verdicts: 21 findings — high 0, medium 5, low 11, false 5, maybe-false 0
- findings:
  - `[medium]` `[patch]` An audit arrival that is not the marker's has no test keeping the marker off — added "an arrival whose criteria are not the marker's leaves the marker off" to `audit.page.spec.ts`.
  - `[medium]` `[patch]` `useDefault` after an arrival is unpinned; the audit spec header's `useDefault` mutation could not fail — added arrival-then-return tests to both page specs and corrected the header line.
  - `[low]` `[patch]` The audit echo's stale-answer guard has no test — added a held-open-read race test to `audit.page.spec.ts`.
  - `[medium]` `[patch]` `shell.screen.open` accepts `criteria` for screens whose page never takes an arrival (`tasks/upcoming` and others) — `Navigate.CriteriaRefusal` now accepts keys only on a `list (server criteria)` target (`ARRIVALARCHETYPE`), and `ToolNavigate` refuses `tasks/upcoming {hoursOffset}`.
  - `[low]` `[reject]` `HoursAgo`'s sub-day branch is untested — read correct for non-multiples of 24, and no shipped descriptor declares one.
  - `[low]` `[reject]` Leg (b)'s at-or-after assertion cannot redden on a young throwaway — the cutoff's pin is `CriteriaDefault` with its recorded mutation; leg (b) pins the open read on a real instance.
  - `[low]` `[patch]` Two `CriteriaDefault` absence assertions had no proof a query was recorded — each now asserts `maxRows` was sent.
  - `[medium]` `[patch]` `TestSinceIsNeverSent`'s 168-hour echo sat inside an `If` and could be skipped — made unconditional.
  - `[low]` `[patch]` AC1's Task-history half had no mutation line — recorded below.
  - `[low]` `[patch]` AC3's `NAV.CRITERIONINVALID` half had no mutation line — recorded below.
  - `[low]` `[patch]` AC4 had no mutation line — recorded below.
  - `[false]` `[reject]` A criteria-free agent navigation replaces the person's last Search with the default — the intent says an arrival sends only the directive's criteria, so an omitted one takes its default.
  - `[medium]` `[patch]` Tool reach exceeds screen reach (intent-alignment) — same root cause and fix as the `ARRIVALARCHETYPE` row above.
  - `[low]` `[reject]` Default-to-default agreement is fixture-level only; each read recomputes its window — the tool asks the model to pass the read's `criteria`, which legs (c) and (d) pin; closing a seconds-wide edge would need shared state.
  - `[false]` `[reject]` The marker-ticked representation of an arrival is only one reading — the spec's lead gate addition mandates it.
  - `[low]` `[reject]` Search, edit without searching, return: the edited form is sent — form and rows still agree, and the behavior predates the story.
  - `[false]` `[reject]` A return after an arrival runs the default — that is the matrix's Return-visit row.
  - `[low]` `[reject]` Refresh is offered from the open read, and a namespace switch reads — both user-initiated (AD-43 forbids timers only), and the spec orders Refresh after the open read.
  - `[false]` `[reject]` The defaults are pinned only against a stub port — legs (a) and (b) pin them on a real instance.
  - `[low]` `[reject]` `NAV.CRITERIONINVALID` is not tested through `Dispatch` — `Dispatch` passes any fault's `detail` regardless of code, pinned through it with `NAV.CRITERIONUNKNOWN`.
  - `[false]` `[reject]` A marker-only arrival now reads the last 24 hours instead of all time — the flag overrides only its own param; an omitted criterion takes its default per the intent.

## Design Notes

**Governing ADs:**

- AD-11: rule 3, and "A tool the browser fulfils".
- AD-36: one read, bounded.
- AD-21: bound values, no URL.
- AD-5: the descriptor is the source, and the mirror is generated.
- AD-19: the arrival holder is framework-free and lives in `core/`.
- AD-24: the echo is small and counts within the bound.
- AD-26: the async audit LIST on open.
- AD-39: codes and detail.
- AD-43: no refresh.
- AD-46: the marker is never a default.
- AD-13: routes.
- The Conventions: Dates, and "When `SCHEMAVERSION` moves".

**Why the default lives in the read and not the page.** The route and the tool reach the same `Execute`. A default kept on the client would make the agent's criteria-free read cover all time while the screen shows 24 hours, so AC2 could not hold. The instance's clock also defines "instance local time", which the form's hint promises.

**Absent versus empty** is the one rule that lets a default coexist with "unset". Search sends the form as shown. An open or an arrival sends only what it was given.

**Sibling audit lists.** `AuditSystemEventList` and `AuditUserEventList` are archetype `list` and already read on open. They do not share the pattern and are not changed.

**Risk (inference).** Some provider adapters may refuse a bare `object` property in the schema they translate. The adapter schema tests settle this in the sweep. If one refuses, HALT rather than reshape the argument.

**Spine amendments -- written by the lead at the spec gate (2026-09-26), in the spine as AD-11 "Navigation may carry the criteria of the read it shows" and AD-36 "A declared criterion may carry a default, and may be applied on the instance".** The text as proposed:

- **AD-11**, after the "A tool the browser fulfils" paragraph: "**Navigation may carry the criteria of the read it shows** [AMENDED 2026-09-26, Story 11.11 spec gate, Rule 20]. Beside `criterion`, which names a flag the target declares and never its value, `shell.screen.open` accepts `criteria`, values keyed by the target's declared criteria fields (AD-36). Dispatch validates each on the instance before any announcement exists, through the read's own criterion check (kind, `maxLength`, `options`, datetime form). It refuses a name the target does not declare `NAV.CRITERIONUNKNOWN` and a value it would refuse `NAV.CRITERIONINVALID`, each naming the criterion in `detail`. The values travel on the directive, never in the URL, and reach the read only as its own criteria (AD-21). The arriving screen runs that search in place of its default."
- **AD-36**, appended: "**A declared criterion may carry a default and may be applied on the instance** [AMENDED 2026-09-26, Story 11.11 spec gate, Rule 20]. A `datetime` criterion may declare `defaultHoursAgo` (1 to 8,760). When a caller omits it, the read sends the instance's local time that many hours earlier (from `$Horolog`, as `YYYY-MM-DD HH:MM:SS`). A caller that sends it empty leaves the bound unset. A `datetime` criterion may instead declare `atOrAfterField`, a read field it is compared against on the instance rather than sent to the vendor. Earlier rows are dropped before truncation is judged, which is sound only for a read the vendor answers newest first (Task history's `HISTORY`). The answer reports every declared criterion's applied value as `criteria`. Screen and tool apply the same default through the one read."

**Integration ACs.**

- Consumes:
  - Story 2.10: the audit viewer and its marker.
  - Story 6.6: task history.
  - Story 4.7: the navigation tool, its announcement and Back.
  - Story 5.8: the flag `criterion`.
  - Story 11.4: chips, which must not widen.
- Consumed-by:
  - Story 14.8: the seeded-injection test still asserts zero navigations.
  - Story 17.7: the owner's live check of the agent's navigation.

**Footprint extensions:**

- Server: `Screen/Read.cls`, `Screen/Registry.cls`, `Screen/Tool/Read.cls`, `Api/ScreenRead.cls`, `Install/Smoke.cls`, `Kernel/State/Nav.cls`, `Kernel/State/Turn.cls`.
- Client: `ui/tools/screen-mirror.mjs`, `core/screen-read.ts`, `core/turn.ts`, `core/screen-arrival.ts` (new).
- Tests: the named test and probe classes, and the browser specs listed.
- None is on Epic 23's changed list except `audit.browser-spec.mjs`, whose region is avoided.

**Ledger inbox:** none.

## Verification

**Commands:**

- `(loop)` `uv run scripts/check-objectscript.py` on touched `.cls` -- expected: clean.
- `(loop)` Load and compile this worktree's `src/OcuPilot` into `ocupilot-ci`. Then, one class at a time: `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.<X>`, for X in `CriteriaDefault`, `ToolNavigate`, `Descriptor`, `TaskHistory`, `ReadTool`, `LedgerClientTool`, `ClientCallFault` -- expected: green.
- `(loop)` `cd ui && npm run test:tools && npm run test:components` -- expected: green.
- `(loop)` Run `cd ui && npm run build` (prebuild checkers). The initial bundle must stay under the 1854kB warning, and the measurement is recorded. Then `docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`.
- `(loop)` `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci node --test --test-concurrency=1 browser/default-search.browser-spec.mjs browser/audit.browser-spec.mjs browser/tasks.browser-spec.mjs browser/proposal-demo.browser-spec.mjs browser/a11y-structural-invariants.browser-spec.mjs browser/screen-height.browser-spec.mjs` -- expected: green. Assert only on rows the spec creates, never on the instance's history count.
- `(loop)` `wc -l` on EXPERIENCE.md reads 981, and `bash scripts/lint-docs.sh` is clean.
- `(once, before dev_complete)` The full ObjectScript sweep, `node tools/ci-runner.mjs --container ocupilot-ci`, and the full `npm test`. The full browser suite runs in CI.

**Mutations to record (Rule 19):**

- Drop `defaultHoursAgo` from the audit: `CriteriaDefault` and leg (a) go red.
- Skip the `since` cutoff: the `CriteriaDefault` cutoff case goes red.
- Make `Directive` return empty `pCriteria`: leg (c) and the `ToolNavigate` travel test go red.
- Skip the name check: the `ToolNavigate` unknown test goes red.

Observed (2026-09-26, `ocupilot-ci`, whole package recompiled per mutation, tree restored after):

- mutation: `defaultHoursAgo` dropped from `AuditList` -> `CriteriaDefault` absent-begin, tool/route and HTTP legs red; leg (a) red.
- mutation: the `AtOrAfter` call skipped in `Read.Execute` -> `CriteriaDefault` cutoff and truncation legs red.
- mutation: `Navigate.Directive` answers `{}` for `pCriteria` -> `ToolNavigate.TestCriteriaTravelOnTheDirective` red; leg (c) red (the arrival read carried no `eventSources`).
- mutation: the `CriteriaParams` name check skipped in `Navigate.CriteriaRefusal` -> `ToolNavigate.TestAnUndeclaredCriteriaKeyIsRefusedByName` red.
- mutation: `screenReadPath` filters out `''` -> `screen-read.test.mjs` explicit-empty test red.
- mutation: `parseNavigation` answers `criteria: {}` -> `turn.test.mjs` criteria test red.
- mutation: `ScreenArrivals.take` ignores the route -> `screen-arrival.test.mjs` red.
- mutation: `AgentNavigator.act` sets no arrival -> two `agent-navigator.spec.ts` Story 11.11 tests red.
- mutation: `AuditPage` ignores a held arrival -> `audit.page.spec.ts` arrival test red.
- mutation: `Navigate.CriteriaRefusal` drops the `ARRIVALARCHETYPE` gate -> `ToolNavigate.TestAnUndeclaredCriteriaKeyIsRefusedByName` red (`tasks/upcoming`, run 14153).
- mutation: `CriteriaRefusal` skips the `SeedCriteria` value check -> `ToolNavigate.TestAnInvalidCriteriaValueIsRefusedByName` red (AC3, run 14154).
- mutation: `TaskHistoryList` `defaultHoursAgo` 168 -> 24 -> `CriteriaDefault.TestSinceIsNeverSent` red (AC1 history half, run 14155).
- mutation: EXPERIENCE.md `:371` "Logged since" -> "Logged after" -> `strings.test.mjs` red, three tests (AC4).
- mutation: `useArrival` ticks the marker whenever one is declared -> `audit.page.spec.ts` "not the marker's" red.
- mutation: `useDefault` keeps the arrival's mode -> the "return after an arrival" tests in `audit.page.spec.ts` and `history.page.spec.ts` red, each alone.
- mutation: the stale-answer guard dropped from `AuditSearch.applyEcho` -> `audit.page.spec.ts` "a late answer" red.

## Auto Run Result

Status: done
Blocking condition: none

- Summary: both screens open on an instance-side default search (audit 24 h, Task history 7 d via `since`), the read answers the `criteria` it applied, and `shell.screen.open` carries `criteria` that the arriving screen runs exactly. The implementation is implement-1's; this pass appended the lead-ruled baseline keys and patched the review findings.
- This pass changed:
  - `ui/browser/structural-baseline.json`: two DW-1584 stamp keys (`logs/audit`, `tasks/history` at 720 px), 225 entries.
  - `Screen/Tool/Navigate.cls`: `criteria` accepted only on a `list (server criteria)` target (`ARRIVALARCHETYPE`), and the tool description says so.
  - Tests: `ToolNavigate` (`tasks/upcoming` refused), `CriteriaDefault` (unconditional echo and recorded-query proofs), `audit.page.spec.ts` (+3 tests, harness can hold the open read), `history.page.spec.ts` (+1 test).
- Review: 21 findings (0 high, 5 medium, 11 low, 5 false). Patched 4 medium entries and 5 low; rejected 12 with the reasons in the triage log; nothing deferred.
- Follow-up review recommended: false (no high patched).
- Verification (this pass, `ocupilot-ci`):
  - `a11y-structural-invariants` 10/10: 225 found, 225 in baseline, 0 stale, no fresh key.
  - `ToolNavigate` 23/23 (run 14156), `CriteriaDefault` 7/7 (14157), `ToolEmit` 11/11 (14158).
  - The two page specs 27/27; `strings.test.mjs` 25/25; `client-lint` clean; `check-objectscript` 0 problems.
  - Seven mutations observed red and reverted (see `## Verification`).
- Carried from implement-1:
  - ObjectScript sweep: 292 ran, 14 refused (arming), 1 known residue (`WireSecurityRead` task history).
  - `npm test`: tools 1,475/1,475, components 1,454/1,454 (the two page specs re-run this pass).
  - Bundle: 1,844,256 B initial, under the 1854kB warning. The bundle is unchanged since.
- Judged at the lead's request:
  - Navigating to the route already open now settles `opened` instead of `refused` `NAV.REFUSEDUNSAVED`. The router answers `false` for a same-URL move, and the mounted page takes the arrival through the subscriber. This is within the settle vocabulary and required by the spec's same-route arrival, so it was kept.
  - Out-of-footprint edits:
    - `app.ts`: a comment only.
    - `main.ts`: provides `ScreenArrivals`.
    - `MgmntPortWire`, `SecurityLists`, `TaskLists`: key lists admit the new `criteria` key.
    - `TurnNavigate`: adds the payload test.
    - All kept; report under footprint_extensions.
- For the lead (Rule 20): the AD-11 amendment says `criteria` are "keyed by the target's declared criteria fields". This pass narrows acceptance to `list (server criteria)` targets, so the spine sentence may want that qualifier.
- Residual risk: another archetype that adopts arrivals later must widen `ARRIVALARCHETYPE`.
- Finalize commit: the one commit on `OCU-1-epic11` that carries this line (`git log -1 --format=%h -- _bmad-output/implementation-artifacts/spec-11-11-the-screen-shows-what-the-agent-is-talking-about.md`); a commit cannot hold its own sha.
