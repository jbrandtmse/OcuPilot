---
title: 'Story 1.1 — The workspace, the pinned stack and one response envelope'
type: 'feature'
created: '2026-09-09'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/.claude/rules/objectscript-basics.md'
  - '{project-root}/.claude/rules/objectscript-testing.md'
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/harvest/HARVEST-PLAN.md'
warnings: ['multiple-goals', 'oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** `src/OcuPilot/` is empty and `ui/` does not exist. Every later story in every epic compiles against a stack that is not yet pinned and writes failures through an error shape that has not yet been decided — so the first divergence (a second envelope, a webpack builder, a TypeScript 7 install, a slice inventing its own error field) becomes permanent before anyone notices.

**Approach:** Stand up the greenfield workspace on exactly the versions the spine's Stack table pins, create the seven fixed ObjectScript package folders, harvest four utility classes from the sibling repositories under OcuPilot's own names, and land one response writer, one error envelope and one `%CSP.REST` router whose ordering invariants, pre-dispatch seam and framework-error overrides are each asserted by their own test.

## Boundaries & Constraints

**Always:**

- All project ObjectScript lives under `src/OcuPilot/` in the seven package folders the spine fixes (`Api`, `Kernel`, `Screen`, `Area`, `Port`, `Install`, `Test`). Load and compile through the IRIS MCP tools with `server: "ocupilot-iris"`, namespace `HSCUSTOM`.
- House rules in `.claude/rules/` are binding: no `%` or `_` in class, property, parameter, parameter-name or method names; `p`-prefixed parameters, `t`-prefixed locals; three-dollar macros; `Set tSC = $$$OK` … `Quit tSC`; argumented `Quit` never inside `Try`/`Catch`; `///` doc comments only; no hand-written Storage section.
- Every project class name, including package dots, is **29 characters or fewer** (verified threshold — see Design Notes).
- `Api/Response.cls` and `Api/Error.cls` are the **only** classes in the tree permitted to `Write` to the response device (AD-12).
- Inside a nested `Catch`, the return is `Return $$$OK`, never a bare `Quit`.
- Every harvested file is renamed into OcuPilot's own names before it is loaded; no rename-checklist token survives anywhere in the tree.

**Never:**

- Never create, modify or assert a CSP web application — Story 1.5 owns both `/ocupilot` and `/api/ocupilot`. Nothing here may depend on either existing.
- Never add a design token, colour, string-table entry, shell component, screen descriptor, port, installer step or CI workflow — those are Stories 1.2, 1.9, 1.10, 1.3/1.4 and 1.17.
- Never edit, load, compile or search `irislib/`, `irissys/`, `irisui/`, `irisdocs/`.
- Never use `New $NAMESPACE` in a dispatch handler; never leave `$NAMESPACE` switched across a request boundary.
- Never add a field to the error envelope outside `Api/Error.cls`; never let a handler construct an envelope of its own.
- Never use a webpack-based Angular builder, a caret/tilde range on `typescript`, or a CDN reference.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| **Integration AC** — router consumes the one error writer | `OcuPilot.Test.RouterFixture` (extends `Api.Router`) dispatched in-process at an unmapped path | Consumer `Api.Router`'s framework-404 path reads from `Api.Error` and produces the observable effect: the captured response device holds exactly one JSON object `{"error":"not_found","reason":<text>,"code":"ROUTE.NOTFOUND"}` and `%response.Status` is 404 | No IRIS HTML error page; no second body |
| Mapped route, unsupported verb | `POST` at a path whose UrlMap declares only `GET` | One envelope, slug `method_not_allowed`, code `ROUTE.METHODNOTALLOWED`, `%response.Status` 405, `Allow` header listing the supported verbs | Framework `Http405` override, never the default |
| Handler success | Fixture route returning a `%DynamicObject` | `Response.JSON` writes it once; `%response.ContentType` is `application/json` | n/a |
| Nested-`Catch` failure | Fixture route whose inner parse `Try` throws, inside an outer `Try` | Exactly one well-formed envelope; captured body contains no `}{` | Inner `Catch` returns `Return $$$OK`; outer `Try` is not resumed |
| Unhandled internal exception | Fixture route throwing `<UNDEFINED>` | Client gets 500 with a **generic** reason and code `INTERNAL`; full exception text reaches `Kernel.Audit.Log` only | `RenderInternal` splits logged detail from client reason |
| Unknown slug | `Error.Render(400, "made_up", …)` | Refused: returns an error `%Status`, writes nothing | The slug enum is closed |
| Envelope field set | Any error path in the tree | Key set is exactly `{error, reason, code}`, or `{error, reason, code, detail}` when a detail object is supplied; `detail` is **omitted**, never `null`, when absent | A fifth key is a test failure |
| Pre-dispatch denial | Caller resolves to `UnknownUser` or `_PUBLIC` | `pContinue = 0`; one envelope via `Error.Render` (401, `unauthorized`, code `AUTH.ANONYMOUS`); `$NAMESPACE` unchanged from entry | Never a direct `Write`; restore is the first line of the `Catch` |
| Namespace resolution | `?ns=` absent | Resolves to the install namespace, once, in `OnPreDispatch` | n/a |
| Namespace resolution | `?ns=NOSUCHNS` | One envelope, 400, slug `bad_request`, code `NS.UNKNOWN`; `$NAMESPACE` unchanged | Validated with `##class(%SYS.Namespace).Exists()`; the value is never concatenated into anything |
| Entity id, single segment | Corpus ids: `_SYSTEM`, `a/b`, `a b`, `100%`, `café`, `x?y`, `#frag` | `EntityId.Encode` → one path segment; `EntityId.Decode` returns the original byte-for-byte | Round-trip asserted over the whole corpus |
| Entity id, double-encoded | Segment `%2520` reaches the handler | Handler receives the literal string `%20` — decoded exactly **once**, not twice | A second decode is the defect this row exists to catch |
| Node version guard | `{node: '20.19.5'}` | Guard returns not-ok with a message naming the required range | Non-zero exit from the `prebuild` script |
| TypeScript version guard | `{typescript: '5.9.2'}` or `{typescript: '7.0.1'}` | Guard returns not-ok naming `>=6.0.0 <6.1.0` | Non-zero exit; the build never starts |
| Version guard, supported | `{node: '26.8.1', typescript: '6.0.3'}` | Guard returns ok | n/a |

</intent-contract>

## Code Map

Nothing exists yet under `src/OcuPilot/` (0 files) and `ui/` is absent — this story creates both. The paths below are the sources to copy from and the system source that settles the mechanisms.

**Harvest sources (outside this repo — read-only, never modified):**

- `/Users/jbrandt/git/iris-couch/src/IRISCouch/Util/Response.cls` (33 lines) — the entire success surface: `JSON(pData)` sets `%response.ContentType` then writes `%ToJSON()`; `JSONStatus(pStatus, pData)` sets `%response.Status` and delegates. Copy nearly as-is.
- `/Users/jbrandt/git/iris-couch/src/IRISCouch/Util/Error.cls` (224 lines) — **14** slug `Parameter`s (lines 10–49), and 8 ClassMethods: `Render` (57), `RenderInternal` (73), `RenderValidate501` (99), `RenderValidateError` (121), `Render501` (158), `BuildJSRuntimeNotImplementedReason` (186), `Render405` (195, sets the `Allow` header at 197), `GetSlugForStatus` (207). **Its payload is only `{error, reason}`** — there is no machine code and no detail object anywhere in the class, so both are new work here, and `Render`'s signature must grow. `RenderInternal` (73–88) is the leak-prevention seam: exception text goes to `WriteToConsoleLog` + `Log.Error`; the client gets the caller-supplied generic reason.
- `/Users/jbrandt/git/iris-couch/src/IRISCouch/Util/Log.cls` (101 lines) — `Info`/`Warn`/`Error`/`Debug` (21/32/43/54) all `(pSubsystem, pMessage, pData)`, funnelling into private `Emit` (66) and `FormatTimestamp` (93). The one runtime literal to rename is line 78: `"[IRISCouch] " _ tEntry.%ToJSON()`.
- `/Users/jbrandt/git/iris-couch/src/IRISCouch/API/Router.cls` (762 lines) — declares only `Parameter UseSession = 0` (9) and `Parameter CONTENTTYPE` (12); **no CORS parameter exists here**, so none is inherited. `XData UrlMap` (15–107): 405 method guards at 37–40 before the `/:db` catch-all at 70; sub-resource routes 42–67 before `/:db` at 69; 4-segment before 3-segment at 85–92; 3-segment before 2-segment at 94–100. The `_all_dbs` incident is documented at 725–729. `OnPreDispatch` (507–667) — five concerns; **it never touches `$NAMESPACE`** (zero `NAMESPACE` hits in the file), and denies at 640–661 by setting `pContinue = 0` then calling `Error.Render` directly. `ReportHttpStatusCode` (692–702) and `Http405` (709–713) are the two overrides; `Http405` delegates the `Allow` header to `Error.Render405`. Thin wrappers at 111, 125, 133 are the shape to copy.
- `/Users/jbrandt/git/iris-couch/src/IRISCouch/Test/ErrorEnvelopeTest.cls` — `RawRequest` (140–158) and `AssertSingleEnvelope` (165–177). The `[ "}{"` check must run on the **unparsed** body; a `%FromJSON` first would parse only the leading object and hide the bug.
- `/Users/jbrandt/git/iris-couch/src/IRISCouch/Test/HttpIntegrationTest.cls` — `MakeRequest` (83) plus `GetTestServer`/`GetTestPort`/`GetTestUsername`/`GetTestPassword` (25/34/43/52), all reading `^IRISCouchTest` (12 occurrences) — rename to `^OcuPilotTest`.
- `/Users/jbrandt/git/iris-execute-mcp-v2/src/ExecuteMCPv2/Utils.cls` (1163 lines) — `Extends %RegisteredObject`, no `Include`. Signatures: `SwitchNamespace` (50), `RestoreNamespace` (64), `ValidateRequired` (77), `ValidateString` (88), `ValidateInteger` (100), `ValidateBoolean` (112), `SanitizeError` (124), `ApplyOutputCeiling` (297), `SurrogateSafeCutLength` (337), `InvokeWithArgs` (673), `DecodeUtf8Stream` (947), `ReadRequestBody` (1124). Exactly three `Parameter`s: `OUTPUTCEILING = 32768` (27), `BYREFNODECEILING = 1000` (34), `UTF8CHUNKSIZE = 1000000` (45). `ReadRequestBody` prefers `%request.GetMimeData("BODY")` and falls back to `%request.Content` (1142), always passing the stream through `DecodeUtf8Stream`.

**System source consulted (read-only reference, never loaded):**

- `irislib/%CSP/REST.cls` — `Page()` (132–231) **never calls `OnPostHTTP`**: there is no post-dispatch hook on the REST path. `DispatchRequest(url, method, forwarded, args...)` (351) calls `..OnPreDispatch(url, method, .continue)` at 359, and falls back to `..ReportHttpStatusCode(..#HTTP404NOTFOUND)` (403) and `..Http405($listtostring(matched))` (415). `DispatchMap` marshals route parameters as raw `matcher.Group(i)` — **`%CSP.REST` applies no URL decoding of its own** (`$zcvt` appears only at 355, 598, 835, 861, 911, none of them on a route parameter). Superclass signatures to match exactly: `OnPreDispatch(pUrl As %String, pMethod As %String, ByRef pContinue As %Boolean) As %Status` (320); `ReportHttpStatusCode(pHttpStatus, pSC As %Status = {$$$OK}) As %Status` (457); `Http405(pSupportedVerbs As %String = "") As %Status` (481 — note the default, which the iris-couch override omits).
- `irislib/%SYS/Namespace.cls` — `Exists(NamespaceName)` (29), `ListAll(Output array, ConvertImplicit)` (165), `Query List` (237).
- `irislib/%Library/Device.cls` — `ReDirectIO(n)` (547), the fallback capture mechanism.

**Repository files this story touches:** `.gitignore` (add the `ui/` build outputs), `.githooks/pre-commit` (currently markdownlint + `check-prose.py` on staged files), `scripts/` (holds `check-prose.py`, `lint-docs.sh`, `fetch-irisdocs.py`). Node 26.8.1 / npm 11.19.0 are installed and satisfy the pinned engines range.

## Tasks & Acceptance

**Execution:**

- `ui/package.json` -- create the workspace manifest: `@angular/*` and `@angular/cdk`/`@angular/material` pinned to 22.1.x / 22.x, `typescript` pinned **exactly** (no caret, no tilde) inside `>=6.0.0 <6.1.0`, `engines.node` = `^22.22.3 || ^24.15.0 || ^26.0.0`, and `prebuild`/`pretest` scripts invoking the version guard -- the AC's pin list is the contract every later story compiles against.
- `ui/.npmrc` -- set `engine-strict=true` and `save-exact=true` -- makes `npm install` on Node 20 fail rather than warn, and stops a later `npm i` re-floating the TypeScript pin.
- `ui/angular.json` -- single application project using the `@angular/build:application` builder with `outputHashing: "all"` set at the builder `options` level so every configuration inherits it, and `baseHref: "/ocupilot/"`; no `@angular-devkit/build-angular` or webpack builder anywhere in the file -- AD-19/AD-20 and the AC's builder clause.
- `ui/tsconfig.json`, `ui/tsconfig.app.json`, `ui/tsconfig.spec.json` -- full strict set (`strict`, `noImplicitOverride`, `noPropertyAccessFromIndexSignature`, `noImplicitReturns`, `noFallthroughCasesInSwitch`, `isolatedModules`) plus `angularCompilerOptions.strictTemplates`/`strictInjectionParameters`/`strictInputAccessModifiers` -- strictness is cheapest to adopt before there is code.
- `ui/tools/version-guard.mjs` -- export a **pure** `checkVersions({node, typescript})` returning `{ok, errors[]}` against the declared ranges, plus a CLI entry that reads `process.versions.node` and the resolved `typescript` version and exits non-zero with a named message -- the AC requires a *clear version error* rather than a compile, and this is the only way to assert it without installing Node 20.
- `ui/tools/version-guard.test.mjs` -- `node --test` cases for `20.19.5`, `5.9.2`, `7.0.1` (all not-ok, each naming the offending range) and `26.8.1` + `6.0.3` (ok) -- pins the I/O matrix's three version rows.
- `ui/src/index.html`, `ui/src/main.ts`, `ui/src/app/app.ts`, `ui/src/styles.css` -- the minimum standalone, zoneless (`provideZonelessChangeDetection`), `OnPush` bootstrap that makes `ng build` succeed; no chrome, no tokens, no API service -- without it the "installed and built" AC cannot be exercised, and Stories 1.2/1.10 own everything above it.
- `.gitignore` -- add `ui/node_modules/`, `ui/dist/`, `ui/.angular/` -- keeps the build outputs out of the 385-file tracked tree.
- `src/OcuPilot/Screen/.gitkeep`, `src/OcuPilot/Area/.gitkeep`, `src/OcuPilot/Port/.gitkeep`, `src/OcuPilot/Install/.gitkeep` -- create the fixed package folders that take no class in this story, so the whole tree shape is committed before anything lands in it.
- `src/OcuPilot/Kernel/Audit/Log.cls` -- `OcuPilot.Kernel.Audit.Log`: four levels funnelling into one private emitter, `[OcuPilot]` line prefix, never throwing and never failing its caller -- first, because `Api/Error.cls`'s internal path writes to it.
- `src/OcuPilot/Api/Response.cls` -- `OcuPilot.Api.Response` with `JSON(pData)` and `JSONStatus(pStatus, pData)` copied from the iris-couch original; the class doc states that it and `Api.Error` are the only permitted writers -- AD-12's single success writer.
- `src/OcuPilot/Api/Error.cls` -- `OcuPilot.Api.Error`: the **closed** slug enum as class Parameters (`bad_request`, `unauthorized`, `forbidden`, `not_found`, `method_not_allowed`, `conflict`, `precondition_failed`, `bad_content_type`, `validation_failed`, `server_error`, `not_implemented`, `unavailable`); a stable machine-code table; `Render(pStatus, pSlug, pReason, pCode, pDetail)` writing `{error, reason, code}` plus `detail` only when supplied, and **refusing an unknown slug**; `RenderInternal`, `Render405` (sets `Allow`), `Render501`, `GetSlugForStatus` -- AD-12 plus AD-39's machine code and structured detail, which the harvested source does not have.
- `src/OcuPilot/Kernel/Utils.cls` -- `OcuPilot.Kernel.Utils`: the twelve harvested methods and the three Parameters, renamed, with no `%Atelier` reference -- taken before the router because everything downstream uses it (harvest plan, Step 0).
- `src/OcuPilot/Kernel/EntityId.cls` -- `OcuPilot.Kernel.EntityId` with the one shared `Encode(pId)` / `Decode(pSegment)` pair, documented as the **only** decode point in the tree -- AD-13; a slice that writes its own codec is the failure this class prevents.
- `src/OcuPilot/Api/Router.cls` -- `OcuPilot.Api.Router Extends %CSP.REST`: `Parameter UseSession = 0`, `Parameter CONTENTTYPE = "application/json"`; an `XData UrlMap` carrying the three ordering rules as a header comment and no application routes yet; `OnPreDispatch` resolving the authenticated caller and the namespace exactly once (stashing the result, switching only through `Kernel.Utils`) and denying via `Error.Render` with `pContinue = 0`; `ReportHttpStatusCode` and `Http405` overrides matching the superclass signatures at `irislib/%CSP/REST.cls:457` and `:481` -- last of the production classes, since it consumes all four above.
- `src/OcuPilot/Test/Dispatch.cls` -- in-process dispatch harness: construct standalone `%CSP.Request`/`%CSP.Response` stubs, redirect `$IO` to a temp file, call `DispatchRequest(pUrl, pMethod)`, restore `$IO`, and return the **unparsed** captured body plus `%response.Status` -- gives an unparsed body without a web application, which Story 1.5 does not yet provide.
- `src/OcuPilot/Test/RouterFixture.cls` -- `OcuPilot.Test.RouterFixture Extends OcuPilot.Api.Router` with a UrlMap that deliberately exercises each of the three orderings plus a single-segment `:id` route, a success route, a nested-`Catch` route and a throwing route -- lets the production `OnPreDispatch`, `ReportHttpStatusCode` and `Http405` be exercised behaviourally while the production UrlMap is still empty.
- `src/OcuPilot/Test/Routing.cls` -- assert every I/O matrix routing row through `Test.Dispatch` against `Test.RouterFixture`: 404, 405 + `Allow`, the three orderings, pre-dispatch denial, namespace resolution and rejection, and the percent-encoded / double-encoded id rows -- the AC requires each ordering invariant to have *its own* test.
- `src/OcuPilot/Test/Envelope.cls` -- assert the single-envelope rows: no `}{` in any captured body, exactly one well-formed envelope per error path, the key set is `{error, reason, code}` (+ `detail`), `detail` omitted when absent, an unknown slug is refused, and an internal exception yields a generic client reason with the detail reaching `Kernel.Audit.Log` only -- AD-12's paired necessary-and-sufficient assertions.
- `src/OcuPilot/Test/EntityId.cls` -- round-trip `Encode`/`Decode` over the fixed corpus (leading underscore, slash, space, percent sign, non-ASCII, question mark, hash) asserting byte-for-byte equality in both directions -- AD-13's named corpus; encode-only assertions are not evidence.
- `src/OcuPilot/Test/Http.cls` -- the renamed `MakeRequest` / `RawRequest` helper reading `^OcuPilotTest`, defaulting to host `localhost`, port `52774`, `_SYSTEM`/`SYS` and base path `/api/ocupilot` -- delivered here per the harvest plan; **no consumer in this story** (see Design Notes).
- `scripts/check-objectscript.py` -- a tree checker over `src/OcuPilot/**` and `ui/**` failing on: any rename-checklist token (`IRISCouch`, `SessionAgent`, `ExecuteMCPv2`, `/iris-couch/`, `^IRISCouchTest`, `^UnitTestRoot`, `sa-static`, `/api/executemcp/v2`, the `iris_` tool prefix, any `IRIS_*` environment variable, `%Atelier`); `%` or `_` in any declared class, property, parameter, class-parameter or method name; a declared method parameter not starting with `p`; a class name longer than 29 characters; and a `Write` statement in any `.cls` other than `Api/Response.cls` and `Api/Error.cls` -- turns four ACs that read as prose into one mechanical gate.
- `.githooks/pre-commit` -- run `scripts/check-objectscript.py` on staged `.cls`/`.mac`/`.inc`/`ui` files alongside the existing markdown checks -- the checks that are not wired in are the ones that stop running.

**Acceptance Criteria:**

- Given a clean clone with no `node_modules`, when `npm ci && npm run build` runs in `ui/`, then the build succeeds on Node 26.8.1 and the emitted bundle filenames carry content hashes.
- Given `ui/angular.json`, when it is read, then the only builder named is `@angular/build:application` and no `@angular-devkit/build-angular` or webpack builder string appears anywhere in the file.
- Given the version guard's pure predicate, when it is called with Node `20.19.5`, TypeScript `5.9.2` or TypeScript `7.0.1`, then each returns not-ok with a message naming the required range, and the CLI entry exits non-zero before any compilation starts.
- Given the ObjectScript tree, when `scripts/check-objectscript.py` runs, then it exits zero, and every project class lives under `src/OcuPilot/` in one of the seven fixed package folders.
- Given a deliberately introduced violation of any one rule the checker enforces, when the checker runs, then it exits non-zero and names the offending file and rule.
- Given the four harvested classes loaded into `HSCUSTOM` through the IRIS MCP tools, when they are compiled, then all four compile clean under their OcuPilot names and no rename-checklist token appears anywhere in `src/OcuPilot/` or `ui/`.
- Given the whole `%UnitTest` suite for `OcuPilot.Test.*`, when it is run per class, then every class reports zero failures, and the totals are confirmed against `%UnitTest_Result` by the SQL probe in `.claude/rules/objectscript-testing.md` before the suite is called green.

## Spec Change Log

## Review Triage Log

## Design Notes

**Governing architecture decisions (Rule 6).** `AD-12` (one error envelope, one response writer — the nested-`Catch` `Return $$$OK` rule, the `}{` test and its paired one-envelope test, and the writer as the tree's only permitted response writer), `AD-39` (the same envelope carries a stable machine code and an optional structured detail object; screen renders the human half, tool the machine half), `AD-13` (entity ids percent-encoded in exactly one path segment through one shared pair, round-trip tested over a fixed corpus), `AD-16` (namespace by explicit save and restore, restore first in every `Catch`, never `New $NAMESPACE` in a dispatch handler), `AD-21` (anonymous does not mean unprivileged — every gate resolves the *authenticated* user and rejects `UnknownUser`/`_PUBLIC`; no caller value concatenated into SQL), `AD-8` (privilege evaluated in the calling process at call time), `AD-29` (denial renders through the one envelope), `AD-19` (zoneless, standalone, signal-based client), `AD-20` (the base href is set at build time and no API URL is relative), `AD-23` (harvested bodies keep their call sites; only the base class changes), `AD-27` (image tag pinned explicitly). Also binding, from the spine's tables: the ObjectScript-naming, names-never-inherited, REST-route-ordering, dates, status-handling and tests rows of **Consistency Conventions**, and the Angular/TypeScript/Node/builder rows of **Stack**.

**Consumed-by** (Rule 2 — this story introduces six shared modules: `Api.Response`, `Api.Error`, `Api.Router`, `Kernel.Utils`, `Kernel.EntityId`, `Kernel.Audit.Log`):

- Story 1.2 — extends `ui/` with the token layer, type ramp and string table.
- Story 1.5 — creates `/ocupilot` and `/api/ocupilot`; first HTTP consumer of `Api.Router`, `Api.Response` and `Api.Error`; first consumer of `Test.Http`; replays the `Kernel.EntityId` corpus over the wire.
- Stories 1.6, 1.7, 1.8 — add login, refresh, logout and identity routes as thin wrappers; consume `Response.JSON` and `Error.Render`.
- Story 1.11 — builds namespace-as-data-scope on `OnPreDispatch`'s single resolution point.
- Story 1.13 — the client renders the envelope's `reason` and branches on its `code`; consumes the slug and machine-code tables.
- Story 1.16 — generates the IPM manifest from the class roster under `src/OcuPilot/`.
- Story 1.17 — the readiness endpoint and smoke script are routes on this router.
- Every later epic — `Kernel.Utils`, `Kernel.EntityId` and `Kernel.Audit.Log` are used tree-wide.

**Consumes:** nothing. Story 1.1 is the first story of Epic 1 on a greenfield tree; there is no prior `done` spec and no upstream module.

**Integration ACs.** `Api.Response`, `Api.Error` and `Api.Router` have a real in-story consumer — the first I/O matrix row exercises `Api.Router`'s dispatch path against `Api.Error` and asserts an observable effect on the wire, not internal state. `Test.Http` has **no consumer in this story; the first consumer will be Story 1.5**, which is when `/api/ocupilot` first exists.

**Ledger inbox (Rule 17).** Empty — no `deferred-work.md` entry names this story key. Nothing to address or decline.

**Two findings that change the implementation, recorded with their evidence:**

1. **`Utils.cls` carries no `%Atelier` coupling.** The AC says "`Utils`' `%Atelier` coupling is dropped". Verified directly: `grep -in atelier /Users/jbrandt/git/iris-execute-mcp-v2/src/ExecuteMCPv2/Utils.cls` returns nothing, the class `Extends %RegisteredObject`, and it has no `Include` line. The coupling in that repository lives in files this story does **not** copy — `Tests/BaseTest.cls` (10 hits), `REST/Base.cls` (9), `Setup.cls` (4), `REST/{EnvSync,Dispatch}.cls` (2 each), `Loc/Scanner.cls` (2), and four others with one each. Treatment: satisfy the AC as a **guard**, not a deletion — `%Atelier` is a forbidden token in `scripts/check-objectscript.py`, so the day a later harvest drags `%Atelier.REST`'s `{status, console, result}` envelope in (which AD-23 exists to prevent), the check fails. This is deliberately not a no-op test: its mutation is demonstrable.

2. **`%CSP.REST` provides no post-dispatch hook, so `OnPreDispatch` resolves but does not hold a namespace switch.** `Page()` at `irislib/%CSP/REST.cls:132-231` never calls `OnPostHTTP`; `DispatchRequest` (351) returns straight to `Page()`. A `Set $NAMESPACE` performed in `OnPreDispatch` therefore has nowhere to be restored and would leak into the next request on a reused CSP worker. The AC's clause "resolves the namespace **once**, in that one place, the namespace switched by explicit save and restore (AD-16) with `$NAMESPACE` restored as the first line of every `Catch`" is read accordingly, and it is the only implementable reading: **resolution and validation happen exactly once, in `OnPreDispatch`, which stashes the resolved namespace; the switch itself is a bounded save/restore through the one shared `Kernel.Utils.SwitchNamespace`/`RestoreNamespace` pair**, restore first in every `Catch` — which is also why the AC says "every `Catch`" in the plural. The alternative reading is not defensible, so this is a resolved reading rather than an intent gap.

**Verified threshold — the storage-global hashing bound.** The AC requires class names "short enough that the compiler does not hash the storage global"; the spine repeats it and the harvest plan cites `^IRISCouch.Proje4479.MangoIndexD` and `^SessionAgenC88B*` as sibling casualties. Probed against the live instance on 2026-09-09 (`ocupilot-iris`, `HSCUSTOM`, over `%Dictionary.CompiledStorage`, whole population rather than a sample): the longest class name still receiving the natural `^<ClassName>D` global is **29 characters** (`%DeepSee.UserLibrary.UserData`, `HS.AU.Message.SMD.MessageType`, `HS.BulkFHIR.Session.PatientId`, `HS.FHIR.vSTU3.PDQm.QueryQueue` — all 29, all natural); at 30 the compiler hashes (`%DeepSee.XMLA.PropertiesRowset` → `^%DeepSee.XMLA.PropertiesR6C2ED`, `%Compiler.LG.JavaForeignKeyDef` → `^%Compiler.LG.JavaForeignK684D`). The generated global name is capped at 30 characters. **Bound: a project class name, package dots included, must be ≤ 29 characters.** The checker enforces it tree-wide rather than only on `%Persistent` classes, so it constrains names now — Story 1.1 introduces no `%Persistent` class, and a check scoped to persistent classes would be vacuous today and absent exactly when a later story needs it. `OcuPilot.` costs 9, leaving 20; every class this story creates fits (`OcuPilot.Api.Router` 19, `OcuPilot.Api.Response` 21, `OcuPilot.Kernel.Utils` 21, `OcuPilot.Kernel.EntityId` 23, `OcuPilot.Kernel.Audit.Log` 25).

**Reading of the envelope's field set.** AD-12 says "flat `{error, reason}`" and AD-39 says the same envelope also carries a machine code and an optional structured detail object. These are not in conflict: AD-39 opens by naming AD-12's envelope and then extends it, and the story's own ACs state both clauses together. "Flat" means no per-slice nesting, not a two-key limit. Settled shape: `error` (coarse slug from the closed enum), `reason` (human text, freely rewordable), `code` (stable, never-reworded, fine-grained machine identifier, always present), `detail` (structured object, present only when supplied). `code` is a stable dotted uppercase identifier (`ROUTE.NOTFOUND`, `AUTH.ANONYMOUS`, `NS.UNKNOWN`, `INTERNAL`) rather than a number, so that adding a code never renumbers an existing one; the intent constrains stability and machine-consumability, not the lexical form.

**Local-variable prefixes are a review convention, not a checked rule.** The checker enforces the `p` prefix on declared method parameters, which is reliably extractable from a signature. The `t` prefix on locals is not reliably extractable without parsing ObjectScript, and a regex over `Set <name> =` produces false positives on `%`-variables, globals and object properties. It stays a review item rather than becoming a checker that has to be suppressed — an unreliable gate is worse than a stated convention.

**Route ordering is enforced structurally and demonstrated behaviourally.** The production `Api/Router.cls` ships with no application routes (there is no endpoint this story owns — readiness is Story 1.17's), so the three invariants are enforced by a structural check over the router's `XData UrlMap` that fails on a violation of any of the three, and demonstrated behaviourally against `Test.RouterFixture`, which inherits the production `OnPreDispatch`, `ReportHttpStatusCode` and `Http405`. The fixture proves the checks and the framework behaviour are real; the structural check is what catches the first real violation in Story 1.5.

**Why the test tier is in-process.** Story 1.5 creates both web applications, so no HTTP endpoint exists yet. `DispatchRequest` is callable in-process and exercises the real UrlMap matcher, the real `OnPreDispatch` and both real framework-error overrides (`irislib/%CSP/REST.cls:359, 403, 415`) — that is the router's real runtime minus the gateway hop. Capturing the response device to a temp file yields the **unparsed** body the `}{` assertion needs. The over-the-wire replay of the same corpus lands in Story 1.5 through `Test.Http`, which this story delivers ready to call.

## Verification

**Commands:**

- `cd ui && npm ci` -- expected: succeeds on Node 26.8.1; fails with npm's "Unsupported engine" under `engine-strict` on any Node outside the pinned range.
- `cd ui && npm run build` -- expected: `@angular/build:application` completes and emits content-hashed filenames.
- `cd ui && node --test tools/` -- expected: all version-guard cases pass.
- `uv run scripts/check-objectscript.py` -- expected: exit 0 over `src/OcuPilot/**` and `ui/**` (a bare `python3` runs outside the project environment).
- IRIS MCP `iris_doc_load` + `iris_doc_compile` (`server: "ocupilot-iris"`, namespace `HSCUSTOM`) over `src/OcuPilot/` -- expected: all classes compile with no errors; read the error text rather than trusting a clean local file.
- IRIS MCP `iris_execute_tests` **per class** for `OcuPilot.Test.Routing`, `OcuPilot.Test.Envelope`, `OcuPilot.Test.EntityId` -- expected: zero failures each; aggregate the totals yourself, then confirm them with the `%UnitTest_Result` SQL probe in `.claude/rules/objectscript-testing.md` before calling the suite green.

**Mutations (Rule 19 — one per AC's pinning test; after each, revert and confirm `git status --short` and `git diff --stat` are unchanged):**

- Widen `checkVersions`' Node range to include `20.x` -> the Node-20 case in `tools/version-guard.test.mjs` goes red.
- Change `typescript` in `ui/package.json` to `^6.0.0` -> the exact-pin assertion goes red.
- Replace the `angular.json` builder with `@angular-devkit/build-angular:browser` -> the builder assertion goes red.
- Add `##class(%Atelier.v1.Utils.General).GetTextAsString()` to `Kernel/Utils.cls` -> `check-objectscript.py` goes red on the forbidden-token rule.
- Rename a class to 30 characters -> the class-name-length rule goes red.
- Add a bare `Write "x"` to `Api/Router.cls` -> the write-discipline rule goes red.
- Change the nested `Catch` in the fixture's nested-`Catch` route from `Return $$$OK` to a bare `Quit` -> the `}{` assertion in `Test.Envelope` goes red.
- Add a fifth key to the object `Error.Render` builds -> the key-set assertion goes red.
- Delete the `Allow` header from `Render405` -> the 405 row in `Test.Routing` goes red.
- Apply `EntityId.Decode` a second time in the fixture's `:id` wrapper -> the double-encoded `%2520` row goes red.
- Move the `/:id` route above its sub-resource route in the fixture's UrlMap -> the sub-resource-before-`:param` ordering test goes red.
- Remove the `UnknownUser` rejection from `OnPreDispatch` -> the pre-dispatch denial row goes red.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none
