---
title: 'Story 2.3: One descriptor-declared read serves both the screen and its read tool'
type: 'feature'
created: '2026-09-14'
status: 'done'
baseline_revision: '5f03ae43989d3e425e68c994aebdb808b5a17b0c'
baseline_commit: '5f03ae43989d3e425e68c994aebdb808b5a17b0c'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
warnings: ['oversized']
deferred:
  - summary: >-
      A misspelt or unknown key in a descriptor's context or read (for example secretfields) passes both the instance and mirror refusals, so the read tool strips nothing.
    evidence: |-
      ReadProblem and readProblem skip the secret checks when context.secretFields is absent and neither refuses unknown keys in read, read.source or context; Tool.Read.View strips only ContextSecretFields. The context grammar predates Story 2.3; closing it means refusing unknown keys in both refusals.
    location: >-
      src/OcuPilot/Screen/Registry.cls ReadProblem; ui/tools/screen-mirror.mjs readProblem
    severity: medium
---

<intent-contract>

## Intent

**Problem:** Nothing yet turns a screen descriptor into data: no list read, no read tool, no registry to find tools, and the auto-refresh framework (`ui/src/app/core/refresh.ts:74`) waits for a read "Story 2.3 supplies". Six list screens are about to be built on top of that gap.

**Approach:** A descriptor declares one `read`; `OcuPilot.Screen.Read` executes it through `AdminPort` with a max-rows cap that reports truncation, one generic route serves it to the screen, and a descriptor-derived read tool narrows the same result by the context cap and strips secret-typed fields. The iris-session-agent registry is ported for discovery and argument validation only; nothing dispatches a tool until Story 4.2.

## Boundaries & Constraints

**Always:**
- The declaration grammar, one example: `"read": {"source": {"port": "admin", "endpoint": "WebApp.App", "type": "LIST"}, "fields": ["Name", "NameSpace", "Enabled"], "filter": ["Name", "NameSpace"], "sort": {"fields": ["Name", "NameSpace"], "default": "Name", "direction": "asc"}, "paging": "cap"}`. `read` is absent or `null` on a screen with no read. `port` is `admin` and `type` is `LIST`; `fields` is non-empty and unique; `filter`, `sort.fields` and `context.secretFields` are subsets of `fields`, and no secret field is in `filter` or `sort.fields` (a filter over a secret field would let a tool probe its value); `sort.default` is in `sort.fields`; `direction` is `asc` or `desc`; `paging` is `cap` (no Release 1 admin LIST accepts a cursor, so `cursor` on an `admin` source is refused).
- A read-declaring descriptor's `toolIdentifier` matches `^[a-z][a-z0-9]*\.[a-z][a-z0-9]*$`; its tool is `<toolIdentifier>.read`, kind `read`. Refused in both `OcuPilot.Screen.Registry.Validate` and `ui/tools/screen-mirror.mjs`, naming the class.
- One executor. `Read.Execute(descriptor, maxRows)` calls `AdminPort.Invoke(endpoint, "LIST")` with `maxRows` + 1, answers `{fields, rows, truncated}` with each row projected to `fields` (an absent key is `null`), `truncated` true exactly when more than `maxRows` came back, and at most `maxRows` rows. `maxRows` absent means 1,000; anything but a positive integer is refused before the port is called. A port fault passes through unchanged.
- One view rule, `ApplyView(rows, read, filter, sort, direction)`, implemented in ObjectScript and in `ui/src/app/core/screen-read.ts` and pinned by one shared corpus: the empty filter keeps every row; otherwise a row stays when any `filter` field's text contains the filter text, both with only ASCII `A-Z` lower-cased; a string's text is itself, a number's is its JSON text, a boolean's is `true`/`false`, `null` is empty. Sort is stable on one `sort.fields` member, in one direction (the declared `default` and `direction` when none is given): two numbers compare numerically, anything else by text in code-unit order; `null` sorts last in either direction.
- `GET /api/ocupilot/screens/:screen/read?maxRows=` (`:screen` is the `toolIdentifier`) gates with `OcuPilot.Screen.Gate.Evaluate` on the descriptor before touching the port (AD-8), and renders `Execute`'s result through `Response.JSON`. The screen filters and sorts on the client (`EXPERIENCE.md:377`).
- The tool view `Tool.Read.View(descriptor, args, contextCap)` validates `args` against its own input schema, runs `Execute`, applies `ApplyView`, keeps the first `contextCap` rows, and removes `context.secretFields` from `fields` and from every row; `truncated` is true when the fetch truncated or the cap cut rows. The cap is a parameter: the kernel supplies it in Epic 4 (AD-24), and the registry never reads kernel state.
- The input schema is the harvested subset: top level `{type: "object", properties, required, additionalProperties: false}`; properties `filter` (string), `sort` (enum of `sort.fields`), `direction` (enum `asc`, `desc`), `maxRows` (integer, minimum 1).
- ObjectScript under `src/OcuPilot/` only; `uv run scripts/check-objectscript.py` passes; one `iris_execute_tests` call per message, never re-submitted on a client timeout.

**Never:**
- No tool dispatch: no `Dispatch` or `Invoke` on the tool base or registry, no caller context, no call-time gate point, no audit row, no JSON-Schema emission for a provider (Story 4.2).
- No content half of the context cap (total size, per-field maxima) and no operator setting (Story 4.4).
- No production descriptor declares a read (Stories 2.5-2.9), no data table or filter field (Story 2.4), no server-side criteria (Story 2.10), no namespace-scoped vendor parameter.
- No per-screen route, tool class or registry edit; no class but `AdminPort` names `%Api.Admin`; no change to the three shell reads' shapes.
- No `docker compose up`/`down`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Truncated | Canned LIST of 6 rows, `maxRows=5` | 5 rows, `truncated: true`; port saw `maxRows` 6 | No error |
| Exactly at cap | Canned LIST of 5 rows, `maxRows=5` | 5 rows, `truncated: false` | No error |
| Bad cap | `maxRows=0`, `-1`, `2.5` or `abc` | Port not called | 400 `bad_request`, code `READ.MAXROWS` |
| Unknown or readless screen | `/screens/nosuch.screen/read`, `/screens/shell.home/read` | — | 404 `ROUTE.NOTFOUND` |
| Denied | Gate refuses the descriptor's pair | Port not called | 403 `AUTH.NOPRIVILEGE`, `detail.failedPair` |
| Port fault | Canned 404 from the endpoint | — | Port's HTTP status and `{error, reason, code}` |
| Tool argument | `{"maxRows": "5"}`, `{"sort": "Enabled"}` (outside `sort.fields`), `{"direction": "up"}`, `{"extra": 1}`, `{"maxRows": 0}` | No port call | Error status naming the argument and the schema rule |
| Declaration | `filter` names a field outside `fields`; a secret field in `sort.fields`; `paging: "cursor"`; `toolIdentifier: "security.ssl.detail"` with a read | Build and `Validate` refuse, naming the class | Mirror exits 1 |
| Tool kind | Concrete subclass of `OcuPilot.Screen.Tool.Base` whose nearest `KIND` is neither `read` nor `write` | — | `check-objectscript.py` exits 1 naming the class; `KindProblem` refuses the same value at runtime |

</intent-contract>

## Code Map

- `src/OcuPilot/Screen/Descriptor/Base.cls` -- `DeclarationJson` (`:58`) re-opens the XData and re-parses on every accessor through `Field` (`:85`), `PrivilegePairs` (`:143`), `RowActionIds` (`:237`); `ContextSecretFields` (`:219`) has no caller yet.
- `src/OcuPilot/Screen/Registry.cls` -- `Descriptors` (`:73`, embedded SQL plus `%Extends`, the discovery idiom to reuse), `Validate` (`:126`), value-driven `RefreshProblem` (`:226`) is the precedent for a public `ReadProblem`; `DescriptorPackage` (`:45`) is the fixture seam.
- `src/OcuPilot/Screen/Gate.cls` -- `Evaluate(pTarget, .pFailedPair)` (`:38`), `HoldsPrivilege` seam (`:123`).
- `src/OcuPilot/Port/AdminPort.cls` -- `Invoke(pEndpoint, pType, ByRef pQuery, pBody, .pResult, .pHttpStatus, .pFault)` (`:268`); a LIST answers a bare `%DynamicArray`. The vendor stops at `maxRows` without reading one more row and signals nothing (`%Api.Admin.Util.ClassQuery.GetMaxRows`, default 1,000, `<= 0` means unlimited).
- `src/OcuPilot/Test/PortFixture.cls` -- `SetCannedAnswer` (`:47`), `SetEndpointClass` (`:28`), `Recorded` (`:66`); `Test/AdminPortSync.cls:62` shows a real `WebApp.App` LIST under a cap.
- `src/OcuPilot/Api/Router.cls` -- `UrlMap` (`:56-63`), thin wrappers (`:67-86`); the doc claim at `:41-45` that a trailing `:param` spans `/` is wrong: `%CSP.REST.GetRegexForUrl` (`irislib/%CSP/REST.cls:677-692`) emits `([^/]+)`, and `%Regex.Matcher` on `/docs/([^/]+)` does not match `/docs/42/history` (probed).
- `src/OcuPilot/Api/Namespaces.cls` -- `GetAllNSInfo` call (`:81`); the third argument is `DontConnect` (`irislib/%SYS/Namespace.cls:80`). Probed: every local namespace returns the same `GlobalDB` `Resource` and `ReadOnly` at 0 and 1.
- `src/OcuPilot/Api/Error.cls` -- codes (`:111` `AUTH.NOPRIVILEGE`, `:121` `ROUTE.NOTFOUND`), `Render` (`:215`); `Kernel/Fault.cls` builds port faults.
- `src/OcuPilot/Test/Dispatch.cls:44`, `Test/RouterFixture.cls`, `Test/NamespaceFixture.cls` -- fixture-seam precedent for handlers; `Test/Http.cls` `AbsoluteRequest` and `Test/Wire.cls` for over-the-wire tests.
- `/Users/jbrandt/git/iris-session-agent/src/SessionAgent/Tool/Registry.cls` -- `ListTools` (L49-88), `ResolveToolName` (L294-321), `GetParameterValue` (L266, reads only a parameter declared on that exact class); `Dispatch` (L121-230) is not ported. `Tool/Base.cls` L86-93 holds the subset rule.
- `scripts/check-objectscript.py` -- `CHECKS` (`:1166`), `iter_named_xdata_blocks` (`:758`), `ROUTE_RE` (`:1021`, captures Url and Call, not Method); harness `scripts/test_check_objectscript.py` `FixtureTreeCase` (`:44`) and the shipped-tree tuple (`:981`).
- `ui/tools/screen-mirror.mjs` -- `buildMirror` refusals (`:357-409`), spread plus defaults (`:415-435`), `ScreenDeclaration` template (`:501-527`); `ui/tools/screen-fixture.test.mjs:56` pins fixture keys to the interface.
- `ui/src/app/core/refresh.ts` -- `RefreshReadResult`/`RefreshRead` (`:66-74`), `bind` (`:208`), `tick` (`:458`); `ui/tools/refresh-connectivity.wire.test.mjs:124-134` is the reference read over `api.requestJson` plus `classifyFault`.
- `ui/src/app/core/api.ts` -- `requestJson` (`:328`), `scope` init and `scopedPath` (`:412`); `ui/src/app/testing/screen-declaration.ts` -- the fixture builder.

## Tasks & Acceptance

**Execution:**
- `src/OcuPilot/Screen/Descriptor/Base.cls` -- read declarations through a per-process cache keyed by class name and `$$$comClassKeyGet(class, $$$cCLASShash)` (`^oddCOM(class, 89)`, 0.13 us per read against 66 us per `DeclarationJson`, probed), so a recompile is read fresh; nested objects handed out are copies; add `Read()` (a copy of `read`, or `""`) -- DW-128.
- `src/OcuPilot/Screen/Registry.cls` -- public `ReadProblem(pDeclaration)` covering the grammar, subsets and tool-identifier pattern; call it from `Validate` -- AD-5, AD-36.
- `src/OcuPilot/Screen/Read.cls` -- `DEFAULTMAXROWS` 1000, `Execute(pDescriptor, pMaxRows, Output pResult, Output pHttpStatus, Output pFault) As %Status`, `ApplyView(...)`, overridable `PortClass()` -- AD-2, AD-36.
- `src/OcuPilot/Screen/Tool/Base.cls` -- abstract; `Parameter TOOLNAME`, `Parameter KIND = ""`, `Parameter DESCRIPTION`, abstract `InputSchema()`; the harvested doc invariant that a tool never touches `%session`, `%request` or `$NAMESPACE`; no `Invoke` -- AD-22.
- `src/OcuPilot/Screen/Tool/Read.cls` -- abstract, `KIND = "read"`; `NameFor`, `InputSchema(pDescriptor)`, `View(pDescriptor, pArgs, pContextCap, Output pResult) As %Status`, reading through an overridable `ReadClass()` so a fixture reaches `PortFixture`.
- `src/OcuPilot/Screen/Tool/Registry.cls` -- the port: overridable `ToolPackage()` (`OcuPilot.`, excluding `OcuPilot.Test.`) and `ScreenRegistryClass()`; `ListTools(Output pTools)` returns `{name, kind, class, descriptor}` for every concrete class that `%Extends` the base (kind by `$Parameter`, so an inherited `KIND` counts) plus one read tool per read-declaring descriptor, refusing a duplicate name; `Resolve(pName, Output pTool)`; public `KindProblem(pClass, pKind)`; `ValidateArguments(pSchema, pArgs, Output pProblem) As %Status` over the subset (types string, integer, number, boolean, array, object; `enum`, `minimum`, `maximum`, `items`, `minItems`, `maxItems`, `required`, `additionalProperties: false`), refusing a schema that uses any other keyword -- AC6.
- `src/OcuPilot/Api/ScreenRead.cls` -- `Handle(pScreen)`: resolve the descriptor by `toolIdentifier`, 404 when absent or readless, gate, validate `maxRows`, `Execute`, then `Response.JSON`, or `Error.Render` with the port's HTTP status and fault; registry, gate and read classes overridable -- AD-12, AD-39.
- `src/OcuPilot/Api/Router.cls` -- `<Route Url="/screens/:screen/read" Method="GET" Call="ScreenRead"/>` first in the map, thin wrapper; replace the `:41-45` claim with the vendor's `[^/]+` behavior.
- `src/OcuPilot/Api/Error.cls` -- `READMAXROWS = "READ.MAXROWS"`.
- `src/OcuPilot/Api/Namespaces.cls` -- overridable `NamespaceInfo(pNamespace, ByRef pInfo, pDontConnect)`; `GlobalDatabase` calls it with 1 -- DW-156.
- `scripts/check-objectscript.py` -- `check_tool_kind` (a concrete class whose `Extends` chain in the tree reaches `OcuPilot.Screen.Tool.Base` and whose nearest `Parameter KIND` is not `read` or `write`, naming file and line); `check_route_ordering` over every `XData UrlMap`, in file order: refuse an earlier route whose Url, read as the vendor regex, matches a later route's Url with the same `Method`, and refuse, whatever the `Method`, a route that follows a shorter route whose Url matches its leading segments; a missing `Method` matches every method -- DW-32, Conventions REST route ordering.
- `scripts/test_check_objectscript.py` -- one planted violation per ordering invariant, a planted kind-less tool and an inherited-kind tool that passes; both rules join the shipped-tree tuple.
- `CLAUDE.md` -- "14 rules" becomes 16.
- `src/OcuPilot/Test/ReadViewCorpus.cls` -- `XData Cases`: rows (strings, integers, `0.5`, booleans, `null`, mixed case, a non-ASCII capital written as a `\u` escape, a duplicate sort key), then filter/sort/direction cases with expected row order.
- `src/OcuPilot/Test/Read/` -- fixtures: `Canned.cls` (toolIdentifier `webapp.canned`; fields `Name`, `NameSpace`, `Enabled`, `Secret`; filter and `sort.fields` `Name`, `NameSpace`; `Secret` in `context.secretFields`; read over a `PortFixture` canned LIST), `WebApps.cls` (read over the real `WebApp.App`), `Registry.cls` (descriptor package seam), `Tool/Middle.cls` (abstract, `KIND = "write"`) and `Tool/Leaf.cls` (concrete, extends `Middle`), `ScreenReadFixture.cls` (the handler with the fixture registry and `PortFixture`). `src/OcuPilot/Test/NamespaceInfoFixture.cls` records the `DontConnect` it is handed.
- `src/OcuPilot/Test/ScreenRead.cls` -- executor matrix rows, real `WebApp.App` at `maxRows` 2, corpus, cache, DontConnect, route rows through `Dispatch`.
- `src/OcuPilot/Test/ReadTool.cls` -- registry, kinds, validator rows, view, integration AC, no-dispatch assertion.
- `src/OcuPilot/Test/ScreenReadWire.cls` -- `AbsoluteRequest` for the 404 on `nosuch.screen` and on `shell.home`, asserting status, content type and body; no production descriptor declares a read yet, so the success, 403 and 400 rows run through `Dispatch` in `ScreenRead`.
- `ui/tools/screen-mirror.mjs`, `ui/tools/screen-mirror.test.mjs`, `ui/src/app/core/screens.generated.ts`, `ui/src/app/testing/screen-declaration.ts` -- `ReadDeclaration`, `read` defaulting to `null`, `readProblem` refusals matching `ReadProblem`; regenerate.
- `ui/src/app/core/screen-read.ts` -- `applyView(rows, read, {filter, sort, direction})` and `createScreenRead(api, declaration): RefreshRead` issuing `GET /api/ocupilot/screens/<toolIdentifier>/read?maxRows=<n>` under the service's own scope (no `scope` init), answering `{kind: 'fault', fault: classifyFault(...)}` on failure.
- `ui/tools/screen-read.test.mjs` -- corpus read from `ReadViewCorpus.cls` via `extractXData`; bind and tick; fault path.

**Acceptance Criteria:**
- AC1: Given `Test/Read/Canned` and `PortFixture` rows, when the route answers `maxRows=5` and `Tool.Read.View` runs with `{maxRows: 5, filter, sort}` and cap 3, then the tool's `fields` are the route's minus `Secret`, and its rows equal the first three of `ApplyView` over the route's rows with `Secret` removed -- Integration AC: the read tool consumes the screen's one read.
- AC2: Given `createScreenRead` bound through `RefreshService.bind` on a refreshing declaration with a read, when a tick fires, then exactly one request `GET /api/ocupilot/screens/<id>/read?maxRows=<store maxRows>&ns=<scope>` is issued and the store holds its rows and `truncated` -- Integration AC: the auto-refresh framework consumes the screen read.
- AC3: Given a registry over `Test/Read/Registry` and the tool fixture package, when `ListTools` loads, then each read-declaring descriptor yields exactly one tool `<toolIdentifier>.read` of kind `read` with no class of its own, a readless descriptor yields none, and `Leaf` is found with its inherited kind.
- AC4: Given a tree with a concrete tool class declaring neither kind, when `check-objectscript.py` runs, then it exits 1 naming the class; `KindProblem` refuses the same value.
- AC5: Given a read over a LIST longer than its cap, when it executes against the real `WebApp.App` at `maxRows` 2, then it answers 2 rows and `truncated: true`, and the matrix's cap rows hold.
- AC6: Given the ported registry, when discovery runs, then membership is `%Extends` over compiled classes rather than `Super` equality, `ValidateArguments` refuses every tool-argument matrix row, and neither `Tool.Base` nor `Tool.Registry` compiles a method named `Dispatch` or `Invoke`.
- AC7: Given `ReadViewCorpus`, when the ObjectScript and TypeScript `ApplyView` run every case, then both produce the expected order.
- AC8: Given a descriptor whose `DeclarationJson` counts its calls, when every accessor runs twice, then the XData is read once (DW-128).
- AC9: Given `NamespaceInfoFixture`, when `GlobalDatabase` runs, then `NamespaceInfo` received `DontConnect` 1, and the existing `OcuPilot.Test.Namespaces` assertions stay green (DW-156).
- AC10: Given a UrlMap with a catch-all before its guard, a `:param` before its literal sibling, or a shorter route before a longer one it prefixes, when the checker runs, then it names each offending pair; the shipped tree and `RouterFixture` pass (DW-32).

**Review patches (2026-09-14):**
- R1 `Screen/Read.cls` `ApplyView`/`Compare` -- a number sorted against text compares by its ObjectScript form (`.5`), the client by JSON text (`0.5`): keep each key's `TextOf` text and use it in the text branch. `Test/ReadViewCorpus.cls` -- let a case carry its own `rows` (both readers use `case.rows` when present), add a case sorting `0.5` against `"/a"` (expected text order), and correct the header claim that each sortable column holds one kind of value.
- R2 `scripts/check-objectscript.py` `check_route_ordering` -- split `Method` on commas (a shared verb collides); scan `<Route>` elements over the whole block, line from the match offset, accepting single- or double-quoted attributes; harness case for each.
- R3 `Api/Router.cls` doc -- invariant 3 cannot be observed by routing (`[^/]+`), so say `check-objectscript.py` enforces it rather than a behavioural test.
- R4 `Test/ScreenRead.cls` AC8 test -- plant a stale hash in the cache and assert the next accessor reads the declaration again.
- R5 `Screen/Registry.cls` `NameArrayProblem` -- remove the unread `pRequired` parameter and its doc.
- R6 `Test/ReadTool.cls` grammar test -- add instance cases for a secret field in `filter`, a bad `sort.direction`, `source.type` other than `LIST`, empty `fields`, `secretFields` outside `fields`, and a non-object `read`.
- R7 `Test/ReadTool.cls` AC1 test -- run the route and the view at `maxRows` 5 as AC1 states, with a filter that leaves more than three of the five rows, and re-verify AC1's mutation line.
- R8 `scripts/check-objectscript.py` -- `KIND_PARAM_RE` accepts a keyword list before `=` (`Parameter KIND As %String [ Final ] = "read";`); `ABSTRACT_KEYWORD_RE` does not read `Not Abstract` as abstract; harness case for each; the shipped-tree test asserts `OcuPilot.Test.Read.Tool.Leaf` is reached as a tool with kind `write`.
- R9 `Test/ScreenReadWire.cls` -- a request whose answer depends on the production route existing (a `POST` answered 405 with `Allow` naming `GET`, as `Test/Wire.cls:304` does), with a mutation line (delete the route -> red).
- R10 `Test/ReadTool.cls`, `ui/tools/screen-read.test.mjs` -- a view where neither the fetch nor the cap cuts asserts `truncated` 0; a tick answering `truncated: false` asserts the store reads `false`.
- R11 `Screen/Registry.cls` `Validate` and `ui/tools/screen-mirror.mjs` `buildMirror` -- refuse a `toolIdentifier` two descriptors declare, naming both classes (the route resolves by it); fixtures `Test/ReadTwin/` (two sound read-declaring descriptors sharing one identifier), `Test/ReadTwinRegistry.cls` and `Test/ReadTwinToolRegistry.cls`; tests: `Validate` refuses, `ListTools` refuses the name claimed twice, the mirror throws.
- R12 `Test/ReadTool.cls` -- every tool-argument matrix row runs through `View` and asserts the port was not called.
- R13 `ui/tools/screen-read.test.mjs` -- the test declaration's `toolIdentifier` is one the read grammar admits, not `stub`.

## Spec Change Log

## Review Triage Log

### 2026-09-14 — Review pass
- verdicts: 64 findings — high 0, medium 17, low 41, false 6, maybe-false 0
- findings:
  - `[medium]` `[patch]` blind: number-vs-text sort differs server/client; corpus header claim false — R1: `Compare` uses `TextOf` text; own-rows corpus case.
  - `[low]` `[reject]` blind: serving path never runs `ReadProblem` — nothing on the serving path runs `Validate` (precedent); the mirror build refuses every shipped read and `ListTools` re-checks.
  - `[medium]` `[patch]` blind: duplicate `toolIdentifier` accepted; route serves the first — R11: `Validate` and `buildMirror` refuse it.
  - `[low]` `[reject]` blind: `maxRows` has no ceiling — the intent defines the accepted set as any positive integer; the read is bounded by the named cap and the tool view by `contextCap`.
  - `[low]` `[patch]` blind: route-ordering ignores comma `Method` lists — R2 splits on commas (a missing `Method` stays any-method, conservative).
  - `[low]` `[reject]` blind: `<Map Prefix>` ignored — the production `Router` maps none; matching maps adds branches.
  - `[low]` `[patch]` blind: route elements read per line — R2 scans the whole block, either quote style.
  - `[low]` `[patch]` blind: invariant 3's routing test cannot fail, doc says it does — R3 doc names the checker.
  - `[medium]` `[patch]` blind: cache hash invalidation unpinned — R4 stale-hash assertions.
  - `[false]` `[reject]` blind: `View` has no gate — the intent's Never excludes a call-time gate point (Story 4.2).
  - `[low]` `[reject]` blind: `View` drops the port fault — `View`'s `%Status` signature is the spec's; the dispatch fault shape is Story 4.2's.
  - `[low]` `[patch]` blind: `NameArrayProblem` dead `pRequired` — R5 removed.
  - `[medium]` `[patch]` blind: instance grammar cases narrower than the mirror's — R6 six cases.
  - `[medium]` `[defer]` blind: a misspelt `secretFields` silently disables stripping — `context` key validation predates this story; deferred.
  - `[false]` `[reject]` blind: no-dispatch test only checks names — it pins the intent's clause exactly; `View` is required by the intent.
  - `[false]` `[reject]` blind: `## Auto Run Result` stale — finalize writes it.
  - `[low]` `[patch]` blind: AC1 test at `maxRows` 8 — R7 runs at 5.
  - `[false]` `[reject]` blind: DontConnect test not in `Test.Namespaces` — the spec's Tasks place it in `Test/ScreenRead.cls`.
  - `[low]` `[reject]` blind: checker docstring numbering — baseline already numbered 13 items for 14 checks; new items follow it.
  - `[low]` `[reject]` blind: `Resolve` rebuilds the list; one bad tool blocks all — refusal over a shorter list is specified; per-call cost is Story 4.2's.
  - `[low]` `[reject]` blind: schema subset admits type-inapplicable keywords, refuses null — schemas are code-authored; adds branches.
  - `[low]` `[patch]` blind: `KIND` with a keyword list misread — R8 (`Inheritance = right` not handled; unused in tree).
  - `[low]` `[reject]` blind: `%OcuPilotDeclarations` naming and lifetime — per-process lifetime is documented; a `Kill` only forces a re-read.
  - `[low]` `[reject]` blind: `read` key order in the generated mirror — JSON key order has no effect.
  - `[low]` `[patch]` edge: comma `Method` — R2.
  - `[low]` `[reject]` edge: `<Map Prefix>` — as above.
  - `[low]` `[patch]` edge: multi-line route — R2.
  - `[low]` `[reject]` edge: `Disabled="true"` route false-refused — loud, absent from the tree; adds a branch.
  - `[low]` `[patch]` edge: `[ Not Abstract ]` read as abstract — R8.
  - `[low]` `[reject]` edge: package-relative `Extends` escapes the kind rule — classes name superclasses fully qualified; resolution adds complexity.
  - `[low]` `[patch]` edge: `KIND` keyword list or `{expr}` or banner — R8 covers the keyword list; the others are unused forms.
  - `[low]` `[reject]` edge: `maxRows` unbounded — as above.
  - `[medium]` `[patch]` edge: mixed-type sort divergence — R1.
  - `[low]` `[reject]` edge: exponent-range number text differs — no admin LIST field carries such numbers.
  - `[low]` `[reject]` edge: route/`View` serve a refused read — as above.
  - `[medium]` `[patch]` edge: duplicate `toolIdentifier` — R11.
  - `[low]` `[reject]` edge: `DescriptorForTool` failure reads as 404 — same shape as `DescriptorForRoute`; a failed catalog query is an instance fault.
  - `[low]` `[reject]` edge: `ListTools` skips a non-object `read` — `Validate` and the mirror refuse it (R6 pins the instance half).
  - `[false]` `[reject]` edge: `InputSchema("")` throws — loud failure on an input no caller passes.
  - `[low]` `[reject]` edge: array `context` diverges instance/mirror — malformed `context` outside the read grammar; both refuse or fail loud.
  - `[low]` `[reject]` edge: store cap 0/NaN parks the timer — pre-existing store setter; no caller sets a non-positive cap.
  - `[low]` `[reject]` edge: DontConnect 1 also on the entry gate (inference) — the spec's task sets `GlobalDatabase` to 1.
  - `[low]` `[reject]` edge: gate pairs read from a process-public cache — as above.
  - `[low]` `[patch]` edge: `Method` compared as one string (claim) — R2.
  - `[low]` `[patch]` edge: AC1 test never truncates the fetch (claim) — R7.
  - `[medium]` `[patch]` gap: no test fails without the production route — R9 POST 405 over the wire.
  - `[medium]` `[patch]` gap: corpus cannot catch number-vs-text — R1.
  - `[medium]` `[patch]` gap: `truncated` false never asserted — R10.
  - `[medium]` `[patch]` gap: duplicate-name refusal untested — R11.
  - `[medium]` `[patch]` gap: cache invalidation untested — R4.
  - `[medium]` `[patch]` gap: `ReadProblem` rules pinned only client-side — R6.
  - `[false]` `[reject]` gap: clauses without their own `mutation:` line — Rule 19 asks one per AC; AC3, AC4, AC6 and AC10 each carry one.
  - `[medium]` `[patch]` gap: `ScreenReadWire` green without the route — R9.
  - `[low]` `[patch]` gap: shipped-tree kind check scans nothing provably — R8 asserts `Leaf` is reached with kind `write`.
  - `[medium]` `[patch]` gap: sort compares ObjectScript number form — R1.
  - `[low]` `[reject]` gap: comparator not transitive for numbers vs numeric strings — the specified rule; vendor LIST columns are single-typed.
  - `[medium]` `[patch]` gap: duplicate `toolIdentifier` accepted — R11.
  - `[medium]` `[patch]` intent: view-rule parity diverges — R1.
  - `[low]` `[reject]` intent: only cursor goes through `Validate`; mirror exit untested as a process — `Validate` prefixes every `ReadProblem` with the class (cursor and twin cases pin it); the CLI exit is shared by every refusal.
  - `[low]` `[patch]` intent: one tool-argument row checked for no port call — R12 all five.
  - `[low]` `[reject]` intent: `CHECKS` membership unasserted — the checker reports 16 rules.
  - `[low]` `[reject]` intent: route rows only through fixtures — the intent has no production read; Story 2.5 is the first over the wire.
  - `[low]` `[reject]` intent: AC1 compares with server `ApplyView`, not the client's — AC7's corpus binds both.
  - `[low]` `[patch]` intent: tick test uses identifier `stub` — R13 (`fields` ignored: `RefreshReadResult` carries rows and `truncated`).

## Design Notes

**Governing ADs:** AD-36 (one read, bounded, tool view narrowed), AD-5 (descriptor source; tool identity from `toolIdentifier`), AD-22 (kind at definition, build fails), AD-24 (cap applied to the tool view; content half is 4.4's), AD-8 (gate at call time), AD-2/AD-27 (port only), AD-12/AD-39 (envelope), AD-19/AD-20 (framework-free core, absolute API path), AD-43 (refresh through the same read), AD-44 (scope from `?ns=`). Conventions: Tool naming, REST route ordering, Secrets, Tests.

**The registry ACs hold together on one reading.** "Not yet dispatchable, because the registry, the caller context and the turn arrive in Epic 4" and "the harvested registry is ported" both hold when this story ports the registry's discovery half (`ListTools`, `ResolveToolName`, parameter reads) and adds the validator, and `Dispatch` with its caller context and audit arrives in Story 4.2, whose own AC says Epic 2's tools "become dispatchable". That is the smaller reading of the port. Recommended apply-and-report wording for the lead in `epics.md` Story 2.3: "because dispatch, the caller context and the turn that calls them arrive in Epic 4".

**Why filter and sort have two implementations.** `EXPERIENCE.md:377` puts sort and filter on the client, and the tool runs in-process on the server; the corpus in one XData block, read by both (the `screen-mirror.mjs` one-block-two-readers precedent), is what keeps them from diverging.

**Why N + 1.** The vendor class query stops at `maxRows` and returns a bare array, so one extra row is the only truncation signal that costs no second query.

**Integration ACs:** AC1 and AC2. **Consumed-by:**
- `2-4-the-data-table` -- `applyView`, `createScreenRead`, `truncated`.
- `2-5-the-web-applications-list` through `2-9-the-processes-list` -- the first production reads; 2.5 is the first read over the wire with a real denied principal.
- `2-10-the-audit-database-viewer-with-its-agent-marker-filter` -- the async LIST through `Execute`, plus server criteria.
- `4-2-the-tool-registry-its-one-gate-point-and-the-three-shell-rea` -- dispatch over `ListTools`, `Resolve`, `ValidateArguments`.
- `4-4-screen-context-on-every-turn-capped-with-its-toggle-and-chip` -- supplies `contextCap` and the content bounds.

**Consumes:** `OcuPilot.Port.AdminPort` (2.1), `Screen.Registry` and `Screen.Gate` (1.9), `RefreshRead` (1.14), the fixture builder (2.0).

**Ledger inbox:** DW-32, DW-128 and DW-156 are addressed by the tasks and AC10, AC8 and AC9.

## Verification

**Commands:**
- `cd ui && npm run build` -- expected: prebuild green, `screen-mirror.mjs --check` up to date.
- `cd ui && npm test` -- expected: `screen-read.test.mjs` and `screen-mirror.test.mjs` green.
- `uv run scripts/check-objectscript.py` and `uv run scripts/test_check_objectscript.py` -- expected: zero problems, harness OK.
- On `ocupilot-iris`, one `iris_execute_tests` call per class: `OcuPilot.Test.ScreenRead`, `OcuPilot.Test.ReadTool`, `OcuPilot.Test.ScreenReadWire`, `OcuPilot.Test.Namespaces`, `OcuPilot.Test.Descriptor`, `OcuPilot.Test.Routing` -- expected: zero failures, confirmed in `%UnitTest_Result`.

**Mutations (Rule 19; each applied, observed red, reverted, source byte-identical by `cmp`):**
- AC1: `View` projects `context.fields` instead of the read's fields -> `ReadTool:TestTheToolViewIsTheRouteReadNarrowed` red at `maxRows` 5 (fields and rows).
- AC2: `createScreenRead` drops `maxRows` from the path -> `screen-read.test.mjs` tick test red.
- AC3: `NameFor` names the tool from `Route()` -> `ReadTool:TestTheRegistryListsDescriptorReadsAndInheritedKinds` red (both read tools unregistered).
- AC4: `check_tool_kind` accepts an empty `KIND` -> harness `test_a_concrete_tool_declaring_no_kind_is_refused_naming_the_class` red.
- AC5: `Execute` asks the port for `maxRows`, not `maxRows` + 1 -> `ScreenRead` truncation, default-cap, real-list and route-success tests red.
- AC6: `ToolClasses` uses superclass equality instead of `%Extends` -> the `Leaf` discovery assertion red; drop the `additionalProperties` refusal -> validator `{"extra": 1}` row red.
- AC7: `Compare`'s text branch compares the stored values instead of each key's `TextOf` text -> `ScreenRead` corpus case "a number sorted against text compares by its JSON text" red; `toLowerCase()` in `applyView` -> case "a non-ASCII capital is not lower-cased" red in `screen-read.test.mjs`.
- AC8: `Declaration`'s cache hit drops the hash comparison -> `ScreenRead:TestEveryAccessorReadsTheDeclarationOnce` red (stale-hash assertions).
- AC9: `GlobalDatabase` calls `NamespaceInfo` with 0 -> `ScreenRead:TestTheNamespaceListAsksWithoutConnecting` red.
- Route: delete `/screens/:screen/read` from `Router`'s `UrlMap` -> `ScreenReadWire:TestAPostToTheScreenReadPathIsRefusedNamingGet` red (404, no `Allow`).
- AC10: drop the shorter-route branch -> harness `test_a_shorter_route_before_a_longer_one_it_prefixes_is_refused_whatever_the_method` red.

## Auto Run Result

Status: done
Blocking condition: none

**Implemented.** A descriptor declares one `read`; `Screen.Read.Execute` runs it through `AdminPort` at `maxRows` + 1 and reports truncation; `GET /screens/:screen/read` gates then serves it; `Tool.Read.View` validates arguments, applies the shared view rule, caps and strips secrets; `Tool.Registry` ports discovery and argument validation with no dispatch. Descriptor accessors read a hash-keyed per-process cache (DW-128); `GlobalDatabase` asks with DontConnect 1 (DW-156); `check-objectscript.py` gains tool-kind and route-ordering rules, 16 in all (DW-32).

**Files.** Server: `Screen/Read.cls`, `Screen/Tool/{Base,Read,Registry}.cls`, `Api/ScreenRead.cls` (new); `Screen/Descriptor/Base.cls`, `Screen/Registry.cls` (`ReadProblem`, `DescriptorForTool`, duplicate-identifier refusal), `Api/{Router,Error,Namespaces}.cls`. Tests and fixtures: `Test/{ScreenRead,ReadTool,ScreenReadWire,ReadViewCorpus,NamespaceInfoFixture,ReadBadRegistry,ReadTwinRegistry,ReadTwinToolRegistry}.cls`, `Test/Read/`, `Test/ReadBad/`, `Test/ReadTwin/`; `Test/{EndpointFixture,RouterFixture,Routing}.cls`. Scripts: `check-objectscript.py`, its harness; `CLAUDE.md` rule count. Client: `core/screen-read.ts` (new), `screen-mirror.mjs` (`readProblem`, duplicate identifier), `screens.generated.ts`, `testing/screen-declaration.ts`, `refresh.ts` doc, `tools/screen-read.test.mjs` (new), `tools/screen-mirror.test.mjs`.

**Review.** 64 findings (medium 17, low 41, false 6): 13 patch entries applied as R1-R13 by a fresh subagent (6 at medium: R1, R4, R6, R9, R10, R11; 7 at low); 1 deferred (unknown `context`/`read` keys); the rest rejected with reasons in the triage log. `followup_review_recommended: true` -- R11's new duplicate-`toolIdentifier` refusal in `Validate` and `buildMirror`, and R1's comparator change, are verified by tests but no review layer has read them.

**Verification.** `check-objectscript.py` 0 problems over 16 rules; harness 73 OK; `npm run build` exit 0; `npm test` 663 node tests plus 21 component files green. `ui/tools/ci-runner.mjs --container ocupilot`: 48 classes, 425 tests, 0 failed, 0 probe leftovers, 0 overlaps. Mutations in `## Verification` re-run for AC1, AC7, AC8 and the route after the patches. `npm run test:browser` not run: no app screen imports `screen-read.ts` yet, so the browser spec reaches nothing this story added.

**Residual risk.** Unknown declaration keys pass both refusals (deferred). The epics.md Story 2.3 wording amendment in Design Notes remains the lead's to apply.
