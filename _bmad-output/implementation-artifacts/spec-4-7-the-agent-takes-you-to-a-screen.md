---
title: 'Story 4.7: The agent takes you to a screen'
type: 'feature'
created: '2026-09-17'
status: 'done'
baseline_revision: '9d1657116eb2a1dcf7cf71e578e9b8c2c704bb16'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md'
warnings: ['oversized']
deferred:
  - summary: 'A list row does not take the selected treatment from the entity id in the route, so UJ-1''s "the agent selects the row" shows the locator entity segment and the screen context''s entity but not a selected row'
    evidence: 'ui/src/app/shell/screen-outlet.ts reads the :id param and exposes it as data attributes; the data table reads selection from the per-descriptor screen store (data-table.ts:400, :810), and nothing joins the two. No Story 4.7 acceptance criterion requires it.'
    location: 'ui/src/app/shell/screen-outlet.ts'
    severity: 'med'
  - summary: 'EXPERIENCE.md :630 promises focus moves to the new screen''s heading on every route change; this story wires it for agent navigation only'
    evidence: 'ui/src/app/app.ts:376 focusOnFrameArrival states there is no route-arrival focus mechanism anywhere in the client. Widening it to every navigation changes the focus order every existing browser spec asserts (shell.browser-spec.mjs), which is a larger change than this story''s ACs ask for.'
    location: 'ui/src/app/shell/locator-bar.ts'
    severity: 'med'
  - summary: 'A settle POST that fails in flight is not retried, and TurnStore already marks the directive acted before the request resolves, so a browser that actually navigated can still be reported NAV.UNAVAILABLE after the server-side wait lapses'
    evidence: 'ui/src/app/core/turn.ts settleNavigation() sets actedNavigationSeq before awaiting api.requestJson, and agent-navigator.ts act() does not check settleNavigation''s returned boolean or retry. Fixing this needs a retry-semantics decision (how many attempts, what happens if all fail) the intent does not specify; the existing NAVWAITSECONDS lapse already bounds the damage to a wrong-but-recoverable turn outcome, never a hang or data loss.'
    location: 'ui/src/app/core/turn.ts:485'
    severity: 'med (unverified how often it fires in production; real but narrow -- a transient network failure in the single-digit-second window between navigate and settle)'
---

<intent-contract>

## Intent

**Problem:** The agent can read a screen and talk about it, but it cannot open one. A user following "the task is suspended, shall I open Task details?" has to hunt through the rail and side bar themselves. Nothing in the product moves the browser on the agent's behalf, and the turn runs in a background IRIS job that holds no request open, so there is no channel by which a tool could.

**Approach:** One registered read tool, `shell.screen.open`, whose fulfilment happens in the browser. It takes an allow-listed route identifier (an `enum` of the descriptor registry's built routes) and an optional entity id — never a URL. Dispatch runs its whole existing refusal chain, the turn job commits the agent's announcement to the step log, writes a directive the browser learns from the progress poll it is already making, and waits for the browser's answer within a bound. The browser announces first, moves about a second later, focuses the arrived screen's title, and posts the outcome back — including the departing screen's refusal, which reaches the turn as an ordinary tool result.

## Boundaries & Constraints

**Always:**

- **AD-11 invariant 3 governs.** Navigation is a proposal of a route: only registry routes, announced before it happens, and the departing screen may refuse it — the refusal reaching the turn as an ordinary tool result (`is_error` false), not an error, with the announcement withdrawn rather than left standing.
- **The allow-list is the descriptor registry, twice.** `route` is a JSON-Schema `enum` built from every built screen's `Route()`, so an off-list value is refused by `Registry.ValidateArguments` before the tool body runs and an off-list value is never advertised; the tool body re-resolves the route against `Screen.Registry` and refuses with `NAV.ROUTEUNKNOWN` if the two ever disagree. No argument can hold a URL because `route` is an enumeration of identifiers and `entityId` is an opaque id.
- **The target screen's privileges are the caller's own.** The tool's `ArgumentPairs` returns the target descriptor's `Screen.Gate.RequiredPairs`, so Dispatch's existing step-7 check answers `AUTH.NOPRIVILEGE` with `detail.failedPair` against current grants (AD-8). No new gate.
- **Announce, then move, provably.** `Nav.GuardedRequest` refuses a `Seq` that names no committed `announce` step for that turn, and `Turn.GuardedView` emits `navigation` only alongside the announce step it names — so no reader can observe the directive without the announcement. The client navigates only once the announcement is in the transcript, then after `NAVIGATIONDELAYMS`.
- **`KIND = "read"`** (AC9), so the write restraint, read-only and kill-switch branches do not apply; `Boundary` still runs before the call and throughout the wait.
- Rule 14: non-ASCII in source is a `\uXXXX` escape. Rule 19: every AC's pinning test has a recorded mutation.

**Never:**

- Never a URL, a filesystem path, or a caller-supplied string that reaches the router unencoded — the client builds the target with the same `encodeEntityId` the data table's name cell uses.
- Never a second channel: no new poll, no server-sent events, no socket. The browser learns the directive from `GET /turn/{id}/progress` and answers on one new route.
- Never an existence check on the entity id — a target that is gone renders AD-37's "no longer present" sentence on arrival.
- Never `replaceUrl`, `skipLocationChange` or an in-app undo control: agent navigation is an ordinary history entry and Back is the published affordance.
- Never a hang: the wait is bounded by `NAVWAITSECONDS` and by `Boundary` (stop, kill switch, lease, wall clock, tokens) on every pass.
- Out of scope: carrying a filter into the target screen (UJ-3's "with the agent-marker filter applied"), making a list row take the selected treatment from the route id, and route-arrival focus for user-initiated navigations. See frontmatter `deferred:`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Open a screen for a row | `{route:"permissions/users", entityId:"_SYSTEM"}` (`id.kind = "single"`), browser polling | announce step committed → directive → browser renders the announcement, waits ~1 s, navigates, focuses the screen title with the heading announcement, posts `opened` → `tool_result` `{"navigated":true,...}`, `is_error` false | No error expected |
| Open a screen with no row | `{route:"tasks/schedule"}` | same, and the announcement takes the no-entity form | No error expected |
| Off-list route | `{route:"/csp/sys/UtilHome.csp"}` or any value not in the enum | refused by `ValidateArguments`; **no announce step and no directive are written** | `TOOL.ARGUMENTS`, `detail.problem`, `is_error` true |
| Route the caller cannot open | a built route whose pairs the user lacks | refused at Dispatch step 7 before any announcement | `AUTH.NOPRIVILEGE`, `detail.failedPair` |
| `entityId` on a screen whose id is `none` or `composite` | `{route:"agent/switches", entityId:"x"}`; `{route:"logs/audit", entityId:"x"}` | refused by the tool body before any announcement -- the tool never invents a second composite grammar (AD-5), so a composite-id screen is openable only without an entity | `NAV.ENTITYNOTALLOWED`, `is_error` true |
| Departing form has unsaved changes | on `agent/switches` (archetype `form-page`), dirty, target `tasks/schedule`, user declines "Leave without saving?" | URL unchanged; announce step settled `error` `NAV.REFUSEDUNSAVED` and removed from the transcript | ordinary result: `{"navigated":false,"code":"NAV.REFUSEDUNSAVED"}`, `is_error` **false** |
| Browser gone, closed, or reloaded | no poll answers the directive within `NAVWAITSECONDS` | announce step settled `error` `NAV.UNAVAILABLE` and removed; the turn continues to the next provider call | ordinary result: `{"navigated":false,"code":"NAV.UNAVAILABLE"}`, `is_error` false |
| Stop pressed during the wait | stop flag set | `Boundary` ends the turn at the next pass (≤ 250 ms); the tool step settles `stopped` | existing `TURN.STOPPED` |
| Settle a turn the caller does not own | `POST /turn/{other}/navigation` | 404 | `TURN.NOTFOUND` |
| Settle twice, or with no directive pending | second `POST` for the same `seq` | 409 | `STATE.CONFLICT` |
| Settle with an outcome or code outside the closed set | `{"outcome":"maybe"}` | 422; the client can never author model-visible text | `TURN.NAVIGATION.INVALID` |
| Entity id needing AD-13 encoding | `entityId:"/csp/myapp"` | the client encodes with `encodeEntityId`, so the agent's URL and a name-cell click's URL are byte-identical | No error expected |

</intent-contract>

## Code Map

Server — read these before editing:

- `src/OcuPilot/Screen/Tool/Base.cls` — `TOOLNAME` :26, `KIND` :30, abstract `InputSchema` :37, `ResultSchema` :44, `Description` :51, `PrivilegePairs` :60, `ArgumentPairs` :71, abstract `View` :84. Add `Parameter FULFILMENT = "instance"`.
- `src/OcuPilot/Screen/Tool/Registry.cls` — `TOOLNAMEPATTERN` :33 (three lower-alnum dot segments), `KINDS` :36, `ListTools` :96, `Resolve` :158, `WireName` :174, `ResolveWire` :182, `ProviderTools` :205, `EmitSchema` :266 (permits `enum`; strips `maxLength` into the description), `RequiredPairs` :366, `ArgumentPairs` :388, `InvokeTool` :410, `ValidateArguments` :461, `KindProblem` :445, `Claim` :524.
- `src/OcuPilot/Screen/Tool/ErrorRead.cls` — the class-of-its-own tool pattern (`TOOLNAME` :32, `KIND` :34); `Screen/Tool/Read.cls` — the descriptor-derived pattern.
- `src/OcuPilot/Kernel/Shell/NamespacesRead.cls` :8, `PrivilegesRead.cls` :7, `InstanceRead.cls` :7 — the `shell.<thing>.<verb>` naming precedent this tool follows.
- `src/OcuPilot/Kernel/Agent/Dispatch.cls` — `Advertise` :85, `Answer` :124, `AnswerOne` :171 and its ordered chain (wire name :195 → identity :207 → gate :212 → restraint :226 → pairs :242 → arguments :255 → argument pairs :264 → invoke :277), `TargetOf` :339, `RedactedArguments` :364, `ErrorContent` :407, `Capped` :419.
- `src/OcuPilot/Kernel/Agent/Loop.cls` — `LimitsClass` :27, `PortClass` :33, `DispatchClass` :39, `DispatchTools` :67, `Run` :92, `Boundary` :229 (eight live re-checks, in order), `AnswerTools` :363 with the tool step appended `running` before dispatch :437.
- `src/OcuPilot/Kernel/Agent/Prompt.cls` — `BUILTIN` :8, `Builtin()` :11, `ContextPreamble()` :16.
- `src/OcuPilot/Kernel/Agent/Limits.cls` — the fourteen limits; add `NAVWAITSECONDS`.
- `src/OcuPilot/Kernel/State/Base.cls` — `GuardedSaveIfCurrent` :156 (conditional `WHERE ID=? AND COALESCE(RowVersion,0)=?` inside one transaction; returns only after `TCOMMIT`), `IsStaleSave` :204, `GuardedTurnSignalSet` :369 / `Get` :384 (`^OcuPilotTurnSignal(key,name)` — the existing browser→job channel: `stop`, `abandon`, `renewed`).
- `src/OcuPilot/Kernel/State/Step.cls` — `Kind` is `%String(MAXLEN=16)` with **no closed vocabulary** :18, so `announce` needs no change here; `TurnSeqIdx` unique on `(TurnKey, Seq)` :63; `GuardedAppend` :75, `GuardedUpdate` :118, `GuardedFinishTool` :135, `GuardedRows` :158 (`Seq` order), row projection :168.
- `src/OcuPilot/Kernel/State/Turn.cls` — `GuardedRenew` :335, `GuardedRequestStop` :342, `GuardedView` :414 (the progress shape).
- `src/OcuPilot/Api/Turn.cls` — `HandleStart`, `HandleProgress` :209 (renews the lease on every non-terminal poll), `HandleStop` :227 (owner gate → terminal check → signal write → trivial ack: the template the new route follows).
- `src/OcuPilot/Api/Router.cls` — `UrlMap` :66-98; the three `/turn/:id/*` routes are declared longest-path-first above the bare `POST /turn` (class header :56).
- `src/OcuPilot/Screen/Context.cls` — `Build` :37, private `DescriptorForRoute` :126 (promote to `Screen.Registry` and have `Context` call it — one route→descriptor lookup, one place).
- `src/OcuPilot/Screen/Registry.cls` — `Descriptors` :80, `Validate` :133 (build-time grammar). `Screen/Descriptor/Base.cls` — `Route()` :161, `LabelKey()` :173, `IdKind()` :264, `PrivilegePairs()` :210, `IsBuilt()`. `Screen/Gate.cls` — `RequiredPairs` :89, `EvaluatePairs` :109.
- `scripts/check-objectscript.py` — Rule 19 :152 (`Kernel/Agent/` names no `OcuPilot.Screen.*` but `Screen.Tool.Registry`, no `OcuPilot.Api.*` but `Api.Error`), Rule 20 :159 (`InvokeTool` only in `Registry.cls` and `Dispatch.cls`), `check_tool_kind` :1715, `check_route_ordering` :1756, `check_handler_wire_tests` :1527.

Client:

- `ui/src/app/core/turn.ts` — `TurnStep` :82, `TurnEntry` :105, `TurnStore` :270, `parseStep` (`kind` defaults to `'tool'` unless exactly `'model'`; unknown `status` defaults to `'running'`), `pollOnce`/`pollUntilTerminal` (1000 ms default, injectable `schedule`), `send`, `stop`. "Steps are read, never written, here" — there is no per-step hook today.
- `ui/src/app/shell/panel.ts` — transcript `role="log" aria-live="polite"` :162, `Panel.turns` step filter :475 (`kind === 'tool' || status === 'stopped'`), `assembleContext` :622, `sendCurrentDraft` :610, `navigateByUrl` :516.
- `ui/src/app/shell/locator-bar.ts` — `resolved` builds `area / screen / entity`; the `screen` segment is `aria-current="page"` and not a link until an entity follows it (DW-142); `.ocu-locator-current` is DESIGN.md's `display` type. **This is the screen title** (DESIGN.md :865, :1035) and therefore the heading this story focuses.
- `ui/src/app/core/shell-state.ts` — `subscribe` :54, `setActiveArea` :107, `showArea` :156; framework-free (AD-19), already injected by `locator-bar.ts`.
- `ui/src/app/app.routes.ts` — `leaveFormGuard` :24 (`CanDeactivateFn` → `FormDirty.requestLeave()`), attached only to `form-page` routes; `buildRoutes` :62. Its own comment: every programmatic navigation is `Router.navigateByUrl`, and the agent's tool "inherits the answer by construction because it will call the same method".
- `ui/src/app/core/form-dirty.ts` — `requestLeave(): Promise<boolean>`, `answer(leave)`; a decline makes `navigateByUrl`'s promise resolve `false`.
- `ui/src/app/core/screens.generated.ts` — `ScreenDeclaration` :247 (`route`, `labelKey`, `id`, `privileges`, `built`). `core/navigation.ts` — `builtScreens` :106, `hasIdRoute` :187, `withQuery` :259, `screenForUrl` :287. `core/entity-id.ts` — `encodeEntityId`/`decodeEntityId`.
- `ui/src/app/core/strings.ts` — `agentNavigationAnnouncement` :186 and `agentNavigationHeadingAnnouncement` :188 **already exist**; `productName` :580 is the document's one visually-hidden `h1` (`_components.scss` :722).
- `ui/src/app/core/api.ts` — `isOcuPilotApiPath` :191, `requestJson` :328, `JsonResult` union.
- `ui/angular.json` :35-40 — `initial` budget `maximumWarning` 780 kB / error 1 MB; `ui/tools/build-output.test.mjs` :168 measures the emitted `main-*.js` + `styles-*.css` against it (1000 bytes/kB). The runner reported 761.53 kB measured before this story (not re-measured at plan time) — **about 18 kB of headroom**; the implement stage's own `npm run build` is the figure to trust.
- `ui/browser/turn.browser-spec.mjs`, `reply.browser-spec.mjs`, `context-chip.browser-spec.mjs` — each defines the same ten turnprobe helpers (`nextTag`, `escapeOs`, `runIris`, `markerValue`, `markedDefault`, `removeDefinition`, `ensureDefinition`, `setTag`, `scriptReply`, `forgetTag`) with a per-file marker prefix (`OCUTURN-`, `OCUREPLY-`, `OCUCHIP-`), a second marker convention beside `ui/browser/iris-session.mjs`'s `OCU-<name>-START`, and a `scriptReply` that writes the literal `"ok"` into its marker instead of `Script`'s own `%Status` (`reply` :136, `turn` :138, `context-chip` :147) — an `assert.ok` that cannot fail. `ui/browser/list-spec.mjs` is the DW-267 precedent: plain named exports, options objects, no class, and a filename outside the `*.browser-spec.mjs` glob.
- `ui/browser/shell-entry.mjs` — `pathOf(page)`, `leaveFirstLoginGate` (the only `page.goBack()` in the tree). `ui/browser/gate.browser-spec.mjs` — the `document.activeElement` assertion style.
- `src/OcuPilot/Test/TurnWireFixture.cls` — `EnsurePrincipal`, `EnsureDefinition` (arms the `turnprobe` row), `SetTag`, `MarkedDefault`, `RemoveDefinition`, `Call`, `StartBody`, `StartConversation`, `AwaitEnd`, `AwaitCall`, `Sweep`. `src/OcuPilot/Test/TurnProvider.cls` — `Script(tag, hangSeconds, bodyExpr)` / `Forget(tag)`, the scripted adapter. `Test/TurnLoopProbe.cls` — switchable loop seams. `Test/ToolDispatchProbe.cls` — switchable dispatch seams.

## Tasks & Acceptance

**Execution:**

- `src/OcuPilot/Screen/Tool/Base.cls` -- add `Parameter FULFILMENT = "instance"` with its caller contract -- a client-fulfilled tool is validated and announced on the instance and answered by the browser.
- `src/OcuPilot/Screen/Tool/Registry.cls` -- add `FULFILMENTS = "instance,client"`, refuse an unlisted value and refuse `FULFILMENT = "client"` on a `write`-kind tool at validation, carry `fulfilment` on the tool object, and add `FulfilmentOf(pTool)` -- a client tool cannot pass the write restraint path, so the build refuses the combination rather than the dispatcher discovering it.
- `src/OcuPilot/Screen/Registry.cls` -- promote `DescriptorForRoute(pRoute) As %String` to a public registry method and have `Screen/Context.cls` call it -- one route→descriptor lookup for the context projection and the navigation allow-list.
- `src/OcuPilot/Screen/Tool/Navigate.cls` -- new: `TOOLNAME = "shell.screen.open"`, `KIND = "read"`, `FULFILMENT = "client"`; `InputSchema` with `route` (required, `enum` of every built screen's `Route()`) and `entityId` (optional, `maxLength` 256, accepted only when the target declares `id.kind = "single"`); `ResultSchema` `{navigated, route, entityId, code}`; `ArgumentPairs` returning the target's `Screen.Gate.RequiredPairs`; `Directive(pArgs, Output pRoute, Output pEntityId, Output pFault)` refusing `NAV.ROUTEUNKNOWN` and `NAV.ENTITYNOTALLOWED`; `View` answering `NAV.NOTINSTANCE` so a mis-wiring fails loudly.
- `src/OcuPilot/Kernel/State/Nav.cls` -- new store on `State/Base`: `TurnKey`, `Seq`, `Route`, `EntityId`, `RequestedAt`, `Outcome`, `Code`, `SettledAt`, unique index on `TurnKey`. `GuardedRequest` **refuses a `Seq` that names no committed `announce` step for that turn** -- that read-back is the ordering guarantee. `GuardedSettle` claims through `GuardedSaveIfCurrent`, so exactly one caller wins and the loser reads `STATE.CONFLICT`. `GuardedPending` reads the unsettled row by parameterized SQL, holding no OREF across a wait (`%OpenId` on a held OREF returns the stale copy).
- `src/OcuPilot/Kernel/State/Turn.cls` -- `GuardedView` emits `navigation: {seq, route, entityId}` **only when the announce step at that `Seq` is in the same projection**, and omits it once settled.
- `src/OcuPilot/Kernel/Agent/Dispatch.cls` -- after the argument-pair check, branch on `fulfilment = "client"`: call the tool's `Directive`, report the validated route and entity id to the loop as a pending detail with no `tool_result`, and add `SettleClient(pDetail, pOutcome, pCode, Output pContent)` so the `tool_result` shape stays owned here (`is_error` false for `refused` and `unavailable`, per AD-11 invariant 3 and AD-39).
- `src/OcuPilot/Kernel/Agent/Loop.cls` -- in `AnswerTools`, on a pending client call: append the `announce` step (`Kind="announce"`, `Target`=route, `Text`=entity id, `Status="running"`), then `Nav.GuardedRequest`, then wait in 250 ms passes up to `NAVWAITSECONDS` re-running `Boundary` each pass, then settle the announce step (`ok`, or `error` with the code) and the tool step and append the content `SettleClient` built.
- `src/OcuPilot/Kernel/Agent/Limits.cls` -- add `NAVWAITSECONDS = 60`, doc'd as the one bound: long enough for a person to answer "Leave without saving?", and cut short by `Boundary`'s stop, kill-switch, lease, wall-clock and token checks on every pass.
- `src/OcuPilot/Kernel/Agent/Prompt.cls` -- **DW-1084**: append two sentences to `BUILTIN` -- name each row you report in backticks and offer to select it; open a screen or select a row with the navigation tool, which announces the move before the browser moves and which the user may refuse. Keep the constant short; nothing else changes.
- `src/OcuPilot/Api/Turn.cls` + `Api/Router.cls` -- add `POST /turn/:id/navigation` beside the other `/turn/:id/*` routes (above the bare `POST /turn`): owner gate (404 `TURN.NOTFOUND`), closed body vocabulary `{seq, outcome:"opened"|"refused", code:"NAV.REFUSEDUNSAVED"|null}` (422 `TURN.NAVIGATION.INVALID` otherwise, so the client can never author model-visible text), then `Nav.GuardedSettle` (409 `STATE.CONFLICT` when already settled or nothing pending), then a trivial `{settled}` ack.
- `src/OcuPilot/Api/Error.cls` -- reasons for `NAV.ROUTEUNKNOWN`, `NAV.ENTITYNOTALLOWED`, `NAV.REFUSEDUNSAVED`, `NAV.UNAVAILABLE`, `NAV.NOTINSTANCE`, `TURN.NAVIGATION.INVALID`.
- `ui/src/app/core/turn.ts` -- parse `kind: 'announce'` in `parseStep`; add `TurnNavigation {seq, route, entityId}`, `navigation()` (the pending directive, exposed only when the announce step at that seq is present in the same view), a settled-seq guard so a directive is acted on once, and `settleNavigation(outcome, code)` posting the new route.
- `ui/src/app/shell/agent-navigator.ts` -- new injectable: subscribes to `TurnStore`, and for a fresh directive whose announcement is rendered, waits `NAVIGATIONDELAYMS` (1000, through the injected `schedule`), calls `router.navigateByUrl(withQuery(route + encoded entity, router.url))`, records the arrival announcement on `ShellState`, and posts `opened` or `refused`/`NAV.REFUSEDUNSAVED` from the promise's own resolution. No `replaceUrl`, no `skipLocationChange`.
- `ui/src/app/core/shell-state.ts` -- an arrival slot (`announceArrival(route, announcement)`, `arrivalAnnouncement(route)`) cleared by the next navigation, so the label is present only on the arrival it describes.
- `ui/src/app/shell/locator-bar.ts` -- wrap the `screen` segment in `<h2 id="ocu-locator-screen" class="ocu-locator-heading" tabindex="-1">` carrying the existing `display` treatment, take the `aria-label` from `ShellState`'s arrival slot, and focus it once per arrival. `h2` because `.ocu-product-heading` is already the document's `h1`.
- `ui/src/app/shell/panel.ts` -- render an `announce` step as a `message-agent` paragraph composed from `STRINGS` (`textContent` only -- the entity id is model-supplied, so untrusted, AD-33), with the no-entity form when the step carries none, and render nothing for an announce step settled `error` (the withdrawal is a removal; the agent's own next reply explains it).
- `ui/src/app/core/strings.ts` + `EXPERIENCE.md` Fixed strings -- add the no-entity form of the announcement and extend the `:281` row to carry it (see Design Notes).
- `ui/src/styles/_components.scss` -- `.ocu-locator-heading`: no visual change, the existing `display` type and focus ring.
- `ui/src/app/app.ts` -- inject `AgentNavigator` for its own sake, as `DefinitionActions` is.
- `ui/browser/turnprobe-spec.mjs` -- new shared module (**DW-1086**): the ten helpers as plain named exports taking a `{container, marker}` options object, on `iris-session.mjs`'s single `OCU-<name>-START` convention, with `scriptReply` threading `Script`'s own `%Status` through the marker and asserting it, and one `armProbeDefinition`/`disarmProbeDefinition` pair owning the before/after order so the cleanup hazard exists once. Named outside the `*.browser-spec.mjs` glob, as `list-spec.mjs` is.
- `ui/browser/turn.browser-spec.mjs`, `reply.browser-spec.mjs`, `context-chip.browser-spec.mjs` -- delete the local copies and import from `turnprobe-spec.mjs`; keep each file's own assertions unchanged.
- `ui/browser/navigate.browser-spec.mjs` -- new, importing `turnprobe-spec.mjs`; asserts its own cleanup and leaves `/api/ocupilot/agent/definitions` empty, the `gate.browser-spec.mjs` / `panel.browser-spec.mjs` pattern.
- `src/OcuPilot/Test/ToolNavigate.cls`, `src/OcuPilot/Test/TurnNavigate.cls` -- new (each under ~500 lines): registry and schema refusals in the first, the wire and ordering behaviors in the second.
- `ui/tools/turn.test.mjs` + a `locator-bar` / `panel` component spec -- the directive parse, the one-shot guard, the delay, the heading focus and the announcement render.

**Acceptance Criteria:**

- **AC1** — Given the advertised tool set, when `Dispatch.Advertise` runs, then `shell_screen_open` appears with `KIND = "read"` and its `route` property's `enum` equals exactly the set of built screens' routes from `Screen.Registry`, so no unadvertised route and no URL is representable.
- **AC2** — Given a `route` outside that enum, or an `entityId` on a screen whose `id.kind` is `none` or `composite`, or a route whose pairs the caller lacks, when the model calls the tool, then the call is refused with `TOOL.ARGUMENTS`, `NAV.ENTITYNOTALLOWED` and `AUTH.NOPRIVILEGE` respectively, and a probe of `Step.GuardedRows` for that turn finds no `announce` step and `Nav.GuardedPending` finds no directive.
- **AC3** — Given a directive whose announce step is absent, when anything reads it, then `Nav.GuardedRequest` refuses the `Seq` and `Turn.GuardedView` omits `navigation`, so no reader can observe the directive before the announcement is committed.
- **AC4** — Given the browser holds a directive, when it acts on it, then it renders the announcement first and navigates only after `NAVIGATIONDELAYMS`, and the announcement text is present in the DOM at the instant `history.pushState` runs.
- **AC5** — Given the arrival, when the route has changed, then focus is on `#ocu-locator-screen` and its `aria-label` reads `"<title> — opened by the agent; Back returns"` resolved for that screen.
- **AC6** — Given the user did not want to move, when they press the browser Back button, then the departing screen is restored with its selected row still selected, and the announcement element contains no button, because Back is the only undo.
- **AC7** — Given the departing route is a dirty `form-page` and the operator declines "Leave without saving?", when the guard answers, then the URL is unchanged, the announcement is gone from the transcript, and the `tool_result` is `{"navigated":false,"code":"NAV.REFUSEDUNSAVED"}` with `is_error` false.
- **AC8** — Given no browser answers, when `NAVWAITSECONDS` elapse, then the announcement is removed, the turn continues to its next provider call with `{"navigated":false,"code":"NAV.UNAVAILABLE"}`, and the turn's own bounds (stop, kill switch, lease, wall clock, tokens) still cut the wait short at the next 250 ms pass.
- **AC9** — Given the tool is client-fulfilled, when Dispatch reaches it, then `InvokeTool` is not called for it and `Navigate.View` answers `NAV.NOTINSTANCE` if it ever is; and given a `write`-kind tool declaring `FULFILMENT = "client"`, when the registry validates, then it refuses at build time.
- **AC10** — Given a second `POST /turn/:id/navigation` for the same `seq`, or one from a user who does not own the turn, or one carrying an outcome or code outside the closed set, when it arrives, then it answers 409 `STATE.CONFLICT`, 404 `TURN.NOTFOUND` and 422 `TURN.NAVIGATION.INVALID` respectively.
- **AC11 (Integration, Rule 1)** — Given consumer `ui/src/app/shell/agent-navigator.ts` reading the directive from `core/turn.ts`, when a navigation lands, then `window.location.pathname` is the target route, consumer `shell/context-chip.ts` names the arrived screen, and the next `POST /turn`'s `context.route` — recorded by `OcuPilot.Test.TurnProvider` — is the arrived route, never the departed one.
- **AC12 (DW-1084)** — Given `Prompt.Builtin()`, when a test reads it, then it carries the citation sentence and the navigation sentence verbatim, so Story 4.6's backtick renderer has a producer.
- **AC13 (DW-1086)** — Given `ui/browser/`, when the suite runs, then the ten turnprobe helpers exist once in `turnprobe-spec.mjs`, the three existing specs import them, one marker convention remains, and `scriptReply` asserts `Script`'s own `%Status`.

## Design Notes

**Governing ADs:** AD-11 (invariant 3 is this story's contract; invariant 1 for the announcement being OcuPilot's own voice and the entity id being untrusted), AD-5 (the descriptor registry is the allow-list), AD-13 (one encoded segment, one encoder), AD-8 (call-time pairs from current grants), AD-1 and AD-22 (one gate point, tools declare their kind), AD-19 (framework-free `core/`, mirrored into signals), AD-24 (the tool result passes the existing cutter), AD-33 (progress is untrusted content rendered as data), AD-36, AD-37 (a missing target renders "no longer present", so the tool does not existence-check), AD-39 (one envelope, machine half to the tool), AD-44 (the route carries `?ns=` as data scope).

**Why the job waits at all.** AD-11 invariant 3 requires the departing screen's refusal to reach the turn "as an ordinary tool result rather than as an error". A fire-and-forget navigation cannot satisfy that, so the wait is mandated rather than chosen. It reuses two existing shapes and adds no channel: the browser already polls `GET /turn/{id}/progress` every second (which also renews the lease throughout the wait), and an API route already writes state a running job reads at a step boundary (`^OcuPilotTurnSignal`'s `stop`/`abandon`/`renewed`). A reloaded tab does not re-attach to a live turn, so its directive lapses to `NAV.UNAVAILABLE` — stated rather than worked around.

**One tool, not two.** EXPERIENCE.md says "the navigation tool" in the singular everywhere it speaks (`:248`, UJ-1 `:701`, UJ-6 `:753`), and selecting a row is opening its route with its id — the same argument pair. `shell.screen.open` follows `Kernel/Shell/`'s own `shell.<thing>.<verb>` precedent and the registry's three-segment pattern.

**Why the locator bar's current segment is the heading.** DESIGN.md `:865` and `:1035` both say the screen title *is* the locator bar's current segment, set in `display`, "the largest text in the product" — so it is the visible heading EXPERIENCE.md `:630` and `:632` refer to, and focusing it shows a focus ring where a visually hidden heading would not. `h2`, because `.ocu-product-heading` is already the document's `h1`.

**Why the withdrawal needs no new copy.** AD-11 invariant 3 says the announcement is "withdrawn rather than left standing" — a removal, not a replacement, so no sentence is authored. The user's explanation is the agent's own next reply, produced from the tool result, which is how the product already handles a refused write (EXPERIENCE.md `:242`). `screen-outlet.ts` set this project's precedent that new product copy is the owner's call.

**EXPERIENCE.md amendment (part of this spec).** The `:281` row publishes only the entity-bearing form. Opening a screen with no row selected has nothing to fill `<entity>`, so extend that row to carry the second form — the same words minus the clause with nothing to fill it, not new copy:

> `| "I'm opening <screen> for <entity> — use Back to return." · "I'm opening <screen> — use Back to return." · "<title> — opened by the agent; Back returns" | the agent's navigation announcement (FR-16), the one phrasing and its form when the screen is opened with no row selected; the new screen's heading announcement |`

**Consumes:** 4.1 (turn job, `Step`, `Turn`), 4.2 (registry, `Dispatch`, the one gate point), 4.4 (`Bound`, `Screen/Context`), 4.5 (`core/turn.ts`, the progress shape, the tool-step fields), 4.6 (the reply renderer that makes backticked citations render), 4.11 (`core/screen-context.ts`'s fresh-at-Send assembly and the chip), Epic 1 (descriptor registry, locator bar, `strings.ts`, `encodeEntityId`), Epic 3 (`core/form-dirty.ts`'s unsaved-changes guard).

**Consumed-by:** Epic 11's click-through citation chips (FR-71) call `shell.screen.open` rather than adding a navigation path of their own; Epic 14's governance gates it like any other tool. No other Release 1 story uses the client-fulfilment seam, so `FULFILMENT` has exactly one client implementation today and the registry refuses a second shape (a `write`-kind client tool) at build time.

**Point 5 — what the next turn carries.** Nothing new is needed and that is the design: `assembleScreenContext` runs fresh inside `Panel.sendCurrentDraft` from `router.url`, and `ContextChip` re-reads on `router.events`, so after an arrival the chip and the next turn's `context.route` agree by construction. The announcement is what makes the change non-silent, which is the half AD-11 invariant 3 actually requires.

**Budget.** About 18 kB of headroom against the 780 kB gate, on the runner's pre-story figure. The additions are one small injectable, two render branches, one heading wrapper and one string; if the measured total crosses the gate, raise `maximumWarning` deliberately in `ui/angular.json` and say so — `ui/tools/build-output.test.mjs` reads the value, so the two move together.

## Verification

**Commands:**

- `uv run scripts/check-objectscript.py` -- expected: clean. Watch Rule 19 (`Kernel/Agent/` may not name `OcuPilot.Screen.Registry` or the new tool class -- route resolution stays inside `Screen/Tool/Navigate.cls`, and the fulfilment flag reaches `Dispatch` as a field on the tool object from `Screen.Tool.Registry`), Rule 20 (`InvokeTool` stays in its two files), `check_route_ordering` and `check_handler_wire_tests` (the new route needs an HTTP test).
- IRIS MCP compile of `src/OcuPilot/` with `server: "ocupilot-slot-a"` -- expected: no errors; recompile the whole package before reading any mutation result.
- `iris_execute_tests` on `OcuPilot.Test.ToolNavigate`, then `OcuPilot.Test.TurnNavigate`, then `OcuPilot.Test.TurnLoop`, then `OcuPilot.Test.ToolEmit` -- **one class per call, never two in one message, never re-submit a timed-out call** (poll `%UnitTest_Result` instead). Expected: all green, verified by the per-class SQL probe in `.claude/rules/objectscript-testing.md`.
- `cd ui && npm test` -- expected: green, including the new `turn.test.mjs` cases and the component specs; `strings.test.mjs` passes only once the EXPERIENCE.md row carries the new literal.
- `cd ui && npm run build` -- expected: the six prebuild checkers pass and `build-output.test.mjs`'s budget test stays green.
- `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/ && OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci npm run test:browser` -- expected: 112 prior + the new spec's tests green. The full `npm run build` script, never a bare `npx ng build` (`licence.browser-spec.mjs` asserts on the `3rdpartylicenses.txt` the script copies), and the bundle must be redeployed before any browser result is read.
- (QA) `ui/browser/navigate.browser-spec.mjs` -- one added test closing the follow-up-review risk named below: two consecutive real turns, each a single-tool-call navigation, whose announce steps both land on `Seq` 3 (`Step.TurnSeqIdx` is per-turn), proving `AgentNavigator.activeSeq`'s per-turn reset against `TurnStore`'s own poll-driven `notify()` rather than a hand-simulated one. Mutation: drop the `directive === null` reset branch in `agent-navigator.ts`'s `check()` -> this test times out waiting for the second navigation, and (as an expected side effect matching DW-1092) the stuck 60 s wait also reddens the following `AC11` test in the same file; reverted, both green.
- `bash scripts/smoke.sh --container ocupilot-ci --user _SYSTEM --password SYS` -- expected: non-zero executed checks, all passing.

**Mutations (Rule 19 — one per AC, applied, observed red, reverted, tree byte-identical after):**

- **AC1** (`ToolNavigate`) -- mutation: replace `route`'s `enum` with a bare `{"type":"string"}` in `Navigate.InputSchema` -> the enum-equality test and the off-list refusal test go red.
- **AC2** (`ToolNavigate`, `TurnNavigate`) -- mutation: move the `Directive` call above Dispatch's argument-pair check -> the "no `announce` step and no directive after a refusal" assertions go red. AC2's `AUTH.NOPRIVILEGE` leg is pinned separately by `ToolWire.TestANavigationTargetTheCallerCannotOpenIsRefusedBeforeAnyAnnouncement` (a real armed principal, throwaway-only) -- mutation: blank `ResolveClientCall`'s `tFailedPair := ..MissingPair(...)` result -> both the refusal and the no-announce-step assertions go red.
- **AC3** (`TurnNavigate`) -- mutation: drop `Nav.GuardedRequest`'s read-back of the announce step -> the orphan-directive refusal test goes red. Second mutation: drop `GuardedView`'s pairing condition -> a fixture-written orphan row surfaces as `navigation` and the reader test goes red.
- **AC4** (`navigate.browser-spec.mjs`, component spec) -- mutation: in `agent-navigator.ts`'s `check()`, call `act(directive)` directly instead of through `setTimeout` -> the browser spec's "the URL has not moved the instant the announcement appears" assertion goes red (`actual '/ocupilot/permissions/users/_SYSTEM'`, `expected '/ocupilot/'`). Second mutation: delete `NAVIGATIONDELAYMS` -> the component spec's "no `navigateByUrl` before the scheduled callback fires" assertion goes red.
- **AC5** (`navigate.browser-spec.mjs`) -- mutation: remove the `focus()` call in `locator-bar.ts` -> the `document.activeElement.id` assertion goes red. Respelling either announcement in `strings.ts` reddens `strings.test.mjs`.
- **AC6** (`navigate.browser-spec.mjs`) -- mutation: pass `{replaceUrl: true}` in `agent-navigator.ts` -> Back no longer returns to the departing screen and the spec goes red. Second mutation: render the announcement with an added button -> the "no button in the announcement" assertion goes red.
- **AC7** (`navigate.browser-spec.mjs`, `TurnNavigate`) -- mutation: ignore `navigateByUrl`'s `false` and post `opened` -> the URL-unchanged, announcement-removed and `is_error false` / `NAV.REFUSEDUNSAVED` assertions go red.
- **AC8** (`TurnNavigate`) -- mutation: raise `NAVWAITSECONDS` beyond the test's own wait -> the lapse test goes red. Drive the lapse from a scripted turn with no browser answering, never from a real clock longer than the class's budget. AC8's own "stop... cut the wait short" clause is pinned separately by `TestStopDuringTheWaitEndsTheTurnAtTheNextPass` -- mutation: drop the `Boundary` call from `AnswerClientCall`'s wait loop -> the test never observes a `stopped` tool step and goes red.
- **AC9** (`ToolNavigate`) -- mutation: set `FULFILMENT = "instance"` on `Navigate` -> `Dispatch` invokes `View`, the `NAV.NOTINSTANCE` fault becomes the tool result, and the pending-path test goes red. Second mutation: set `KIND = "write"` -> the registry's build-time refusal test goes red.
- **AC10** (`TurnNavigate`) -- mutation: drop the `seq` comparison in `Nav.GuardedSettle` -> the double-settle test reads 200 instead of 409 and goes red.
- **AC11** (`navigate.browser-spec.mjs`) -- mutation: pass `{skipLocationChange: true}` -> the URL never changes, the chip keeps naming the departed screen and the next turn's recorded `context.route` is the old one; the integration assertion goes red.
- **AC12** (`TurnNavigate.TestAC12BuiltinCarriesBothSentences`) -- mutation: delete either added sentence from `BUILTIN` -> that test goes red. (Added at review: the three pre-existing `Builtin()` assertions compare the sent prompt to `Prompt.Builtin()` and so could not see either sentence.)
- **AC13** (`navigate.browser-spec.mjs`) -- mutation: make `TurnProvider.Script` answer an error status (call it with an unarmed tag) -> the extracted `scriptReply` goes red where all three local copies passed, which is the falsification of the unasserted status.
- **The announce step's own entity id (`TurnNavigate.TestAC9SuccessfulCallNeverInvokesView`)** -- review finding, not a lettered AC: `Loop.AnswerClientCall`'s settle call carries `tEntityId` forward instead of `""`, so a restored or later-polled transcript still renders the selected row. Mutation: pass `""` for the settle's `pText` again -> the "entity id survives settling" assertion goes red.
- **The `AgentNavigator.activeSeq` per-turn reset (`agent-navigator.spec.ts`)** -- review finding: `check()` resets `activeSeq` to 0 whenever no directive is pending, so a later turn's own navigation is not silently dropped when it reuses a `seq` an earlier, already-settled turn used (`Step.Seq` restarts at 1 per turn). Mutation: drop the `directive === null` reset branch -> "a later turn reusing the same seq... is still acted on" goes red.

**Mutations recorded at review (2026-09-18), each applied, observed red, reverted):**

- **A dropped announce step lapses rather than failing the turn** (`TurnNavigate.TestADroppedAnnounceStepLapsesRatherThanFailingTheTurn`) -- mutation: delete `AnswerClientCall`'s `'tAnnounceStored` branch -> `ERROR #5001: turn ...: Seq 3 names no committed announce step, so no directive can be requested for it` and the test goes red.
- **The stop path settles the directive** (`TurnNavigate.TestStopDuringTheWaitEndsTheTurnAtTheNextPass`) -- mutation: delete the `Nav.GuardedSettle` call from the `Boundary` branch -> the "no reader still sees it pending" and "the view no longer carries the directive" assertions go red.
- **A second request presents unsettled** (`TurnNavigate.TestASecondRequestPresentsUnsettled`) -- mutation: drop `GuardedRequest`'s three clearing lines -> the test reads the first call's stored outcome and goes red.
- **A turn's directive is deleted with the turn** (`TurnNavigate.TestDeletingATurnRemovesItsDirective`) -- mutation: drop `Turn.GuardedDelete`'s `Nav.GuardedDeleteForTurn` call -> the test goes red.
- **The settled `tool_result` payload** (`TurnNavigate.TestAC9SuccessfulCallNeverInvokesView`) -- mutation: emit `navigated` as a literal `0` in `Dispatch.SettleClient` -> "reporting the navigation as performed" goes red.
- **The arrival slot clears** (`ui/tools/shell-state.test.mjs`) -- mutation: make `ShellState.clearArrival` a no-op -> "clearing the arrival drops it" goes red.

**Manual checks:**

- `docker compose ps` only; never `up`, `down` or `restart` against `ocupilot`, any `ocupilot-slot-*`, `ocupilot-b-ci` or `iris-community-edition`, and never run `ci-throwaway.sh` — `ocupilot-ci` is already up and is the runner's.
- After the browser suite, confirm `GET /api/ocupilot/agent/definitions` is empty and no probe principal survives (`TurnWireFixture.PrincipalsLeft`).

## Review Triage Log

### 2026-09-18 — Review pass

- verdicts: 14 findings — high 1, medium 5, low 6, false 2, maybe-false 0
- findings:
  - `[high]` `[patch]` `AgentNavigator.activeSeq` is a tab-lifetime singleton never reset per turn, so a later turn's navigation reusing an earlier turn's `seq` (`Step.Seq` restarts at 1 per turn) is silently never scheduled — fixed: `check()` resets `activeSeq` to 0 whenever `navigation()` is null; pinned by a new `agent-navigator.spec.ts` test, mutation (drop the reset) confirmed red then reverted.
  - `[medium]` `[patch]` Settling the announce step passes `pText=""` to `GuardedUpdate`, and `ApplyContent` unconditionally overwrites `Text`, wiping the entity id a successful navigation recorded — fixed: pass `tEntityId` instead; pinned by an added assertion in `TestAC9SuccessfulCallNeverInvokesView`, mutation (revert to `""`) confirmed red then reverted.
  - `[low]` `[reject]` `AgentNavigator.act()`'s `.catch(() => false)` reports a genuine `navigateByUrl` rejection the same as a `CanDeactivateFn` decline (`NAV.REFUSEDUNSAVED`) — unlikely in this app specifically (a single bundle with no lazy-loaded routes, and `leaveFormGuard` the only guard on these routes), and a real fix needs a new server-side closed-vocabulary code the intent does not specify, more than a direct correction.
  - `[medium]` `[defer]` `TurnStore.settleNavigation()` marks the directive acted before its POST resolves and is never retried, so a browser that actually navigated can still be reported `NAV.UNAVAILABLE` after the server-side wait lapses — real but the smallest correct fix needs a retry-semantics decision (attempt count, exhaustion behavior) outside this story's intent; the existing `NAVWAITSECONDS` lapse already bounds the damage to a wrong-but-recoverable outcome. Recorded in frontmatter `deferred:`.
  - `[low]` `[patch]` The wait loop's `Nav.GuardedPending` read-error branch never calls `Nav.GuardedSettle`, unlike the sibling timeout branch, leaving the Nav row open after the turn has already reported the lapse — fixed: mirrored the timeout branch's `GuardedSettle` call.
  - `[medium]` `[patch]` `OcuPilot.Api.Error.NavCodes()`/`ReasonForNav()` has no test walking the vocabulary the way `RestraintCodes()`/`ReasonForRestraint()` is pinned in `Restraint.cls` (grouped with the Verification Gap layer's same finding below) — fixed: added `ToolNavigate.TestEveryNavCodeHasAWrittenSentence`, mutation (blank one branch) confirmed red then reverted.
  - `[low]` `[patch]` The new `ToolWire` test discarded `TurnProvider.Script`'s own `%Status` via bare `Do`, the pattern this story's own change to `Script` says callers should stop using — fixed: the two new call sites now assert `$$$AssertStatusOK`.
  - `[low]` `[reject]` `NAVIGATIONDELAYMS` is duplicated as a literal in `agent-navigator.ts` and `navigate.browser-spec.mjs` with no cross-check — already documented in the browser spec's own comment as a known, accepted tradeoff (a browser test cannot import a `.ts` constant), matching the project's existing accepted pattern for this exact class of duplication (CLAUDE.md's compose/proxy port literals). No action.
  - `[false]` `Loop.cls`'s wait loop checks `Boundary` before `Nav.GuardedPending` each pass, so a stop landing the same pass as the browser's own settle discards the recorded outcome for `TURN.STOPPED` — matches the existing, accepted "stop always wins" contract this class's own Design Notes document for every in-flight tool call interrupted by a stop; not specific to navigation and not a regression.
  - `[medium]` `[patch]` The lapse branch calls `Nav.GuardedSettle` and discards `pClaimed`, so when the browser's own settle wins the claim race in the same instant, the loop reports its own locally-computed `unavailable` instead of what was actually persisted — fixed: on `'tClaimed`, re-read the directive via `GuardedPending` and use its real outcome/code.
  - `[low]` `[reject]` Duplicate of the `navigateByUrl` rejection finding above, same disposition.
  - `[false]` `AgentNavigator.act()`'s `screenForRoute(directive.route)` could return `null` for a route the server validated, rendering an empty title in the arrival `aria-label` — structurally prevented: `ui/tools/screen-mirror.mjs --check` (part of `npm run build`'s prebuild, which this pass ran clean) keeps the client's own screen list identical to the server's descriptor registry, so a route the server names is always one `screenForRoute` resolves.
  - `[low]` `[patch]` `Registry.ListTools`'s descriptor-derived read-tool loop never calls `FulfilmentProblem` before `Claim`, unlike the manual tool-class loop, so AC9's general "a write-kind client tool refuses at build time" claim is unenforced on that path — fixed: added the check once (the read-tool class is fixed, not per-descriptor, so it is checked outside the loop rather than per iteration).
  - `[medium]` `[patch]` Verification Gap layer's own filed finding for the same `NavCodes()`/`ReasonForNav()` gap as above (grouped) — same fix.
- Two additional regressions surfaced by this pass's own re-verification sweep, not filed by a review layer, both pre-existing tests broken by the story adding a 12th live tool: `ReadTool.TestTheRegistryListsDescriptorReadsAndInheritedKinds` pinned the production registry at exactly eleven tools by name — fixed to twelve, `shell.screen.open` inserted in its alphabetical position. `ToolRoundTrip.TestEveryToolConformsToItsResultSchemaOrAnswersACode` calls every live tool with `{}` and expects a result or a named `REFUSEEMPTY` code; `shell.screen.open`'s `View` always answers `NAV.NOTINSTANCE` by design — fixed by adding `shell.screen.open:NAV.NOTINSTANCE` to `REFUSEEMPTY`. Both now pass; the whole affected-class sweep (`ReadTool`, `ToolRoundTrip`, `ToolDispatch`, `ToolShell`, `ToolEmit`, `ToolNavigate`, `TurnNavigate`, `TurnLoop`) reran green after every patch.

## Auto Run Result

Status: done
Blocking condition: none

**Summary.** Implemented `shell.screen.open`, the one client-fulfilled navigation tool: the
`FULFILMENT` mechanism on `Screen.Tool.Base`/`Registry`, the tool class itself, the `Nav` store
and its announce-paired read-back guarantee, `Dispatch.ResolveClientCall`/`SettleClient`,
`Loop.AnswerClientCall`'s announce-wait-settle sequence, `POST /turn/:id/navigation`'s closed
vocabulary, and the client half (`AgentNavigator`, the locator bar's focusable heading, the
panel's announce-step rendering). DW-1084 (the `BUILTIN` prompt sentences) and DW-1086
(`turnprobe-spec.mjs` extraction) are both closed. Reviewed and patched in this pass; see the
Review Triage Log above for the full findings list.

**Files changed:** the 42 files in the diff since `baseline_revision` — server:
`Api/{Error,Router,Turn}.cls`, `Kernel/Agent/{Dispatch,Limits,Loop,Prompt}.cls`,
`Kernel/State/{Nav (new),Turn}.cls`, `Screen/Context.cls`, `Screen/Tool/{Base,Navigate (new),Registry}.cls`,
`Test/{BadFulfilment/* (new),NavSettleJob (new),ReadTool,ToolEmit,ToolNavigate (new),ToolRoundTrip,
ToolWire,TurnLimitsNav (new),TurnNavigate (new),TurnProvider}.cls`; client:
`browser/{context-chip,reply,turn}.browser-spec.mjs` (refactored onto the shared fixture),
`browser/{navigate.browser-spec.mjs,turnprobe-spec.mjs}` (new), `src/app/app.ts`,
`src/app/core/{navigation,shell-state,turn}.ts`, `src/app/shell/{agent-navigator (new),
locator-bar,panel}.ts` and their specs, `src/styles/_components.scss`, `tools/turn.test.mjs`.

**Review findings breakdown** (four parallel layers -- blind-hunter, edge-case-hunter,
verification-gap, intent-alignment -- 14 findings total): 7 patched (1 high, 3 medium, 3 low,
after grouping two same-root-cause findings into one), 1 deferred (medium, real but needs a
retry-semantics decision outside this story's intent -- see frontmatter `deferred:`), 4 rejected
(3 low as unlikely-in-practice with a fix bigger than a direct correction, 1 low as an
already-documented, accepted duplicated-literal tradeoff), 2 false (both structurally prevented
by existing invariants -- the "stop always wins" contract and the screen-mirror build-time
parity check). Full list with evidence: `## Review Triage Log` above. This pass's own
re-verification sweep additionally found and fixed two pre-existing tests broken by the new
12th live tool (`ReadTool`'s pinned eleven-tool list, `ToolRoundTrip`'s `REFUSEEMPTY` set) --
neither was filed by a review layer.

**Follow-up review recommendation:** `true`. A patched entry was `high` (the
`AgentNavigator.activeSeq` cross-turn reuse fix). Named risk: that fix is pinned only at the
unit level (`agent-navigator.spec.ts`, a stubbed `TurnStore` with a manually simulated
`clearNavigation()` in between two directives sharing a `seq`); it has not been exercised
end-to-end against two consecutive real turns in a live browser, where the reset trigger is
`TurnStore`'s own ordinary poll-driven `notify()` rather than a hand-simulated one.

**Verification performed** (commands and outcomes; full detail in `## Verification` above):
`check-objectscript.py` clean (365 files, 21 rules, 0 problems) after every edit in this pass.
Full-package IRIS compile (365 classes) clean. `%UnitTest` on `ocupilot-slot-a`, one class per
call, SQL-probe-confirmed: `ToolNavigate` 15/15, `TurnNavigate` 10/10, `TurnLoop` 11/11,
`ToolEmit` 11/11, `ReadTool` 23/23, `ToolRoundTrip` 2/2, `ToolDispatch` 17/17, `ToolShell` 2/2
(94 total, 0 failed). `ToolWire` (armed, throwaway-only) 3/3 on `ocupilot-ci`, including a new
wire-level `AUTH.NOPRIVILEGE` test for the navigation tool. `cd ui && npm test`: 937 node + 472
vitest, all green. `cd ui && npm run build`: clean, six prebuild checkers pass, bundle 766.33 kB
against the 780 kB budget (`build-output.test.mjs` 13/13). Rebuilt and redeployed to `ocupilot-ci`
after every code change; `npm run test:browser` 117/117 green on the final deployed bundle.
`bash scripts/smoke.sh --container ocupilot-ci`: 18/18 passed, 2 pending (Epic 3), 1 skipped
(benign). Post-suite cleanup confirmed: `/api/ocupilot/agent/definitions` empty,
`TurnWireFixture.PrincipalsLeft()` empty. Every patch's own mutation applied, observed red, and
reverted (tree confirmed byte-identical via `grep MUTATION` after each revert and a clean
recompile) before the next step.

**Residual risks:** the follow-up-review risk named above (activeSeq fix not yet proven against
two real consecutive turns in a live browser). The one `defer`red finding (settle-POST retry
semantics) is real but narrow and bounded by the existing 60 s lapse fallback. The two `reject`ed
low findings (navigateByUrl rejection conflated with a guard decline; the `NAVIGATIONDELAYMS`
duplicated literal) are documented above with why they were not worth fixing now.
