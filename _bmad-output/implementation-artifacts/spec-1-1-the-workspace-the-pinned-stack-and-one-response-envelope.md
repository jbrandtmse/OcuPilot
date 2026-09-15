---
title: 'Story 1.1 — The workspace, the pinned stack and one response envelope'
type: 'feature'
created: '2026-09-09'
status: 'done'
baseline_revision: 'ac652ec23d6c1af12eef0da93c88e0a0d59ff708'
baseline_commit: 'ac652ec23d6c1af12eef0da93c88e0a0d59ff708'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/.claude/rules/objectscript-basics.md'
  - '{project-root}/.claude/rules/objectscript-testing.md'
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/harvest/HARVEST-PLAN.md'
warnings: ['multiple-goals', 'oversized']
deferred:
  - summary: >-
      OcuPilot.Kernel.Utils has no dedicated test suite and no production call site in
      this story, so none of its non-trivial logic has ever actually executed.
    evidence: |-
      Verified: grep for OcuPilot.Kernel.Utils under src/OcuPilot/ finds only the class's
      own header and one doc-comment mention in Api/Router.cls (prose, not a call). A
      "no consumer in this story" note (mirroring Test.Http.cls's existing pattern) was
      added to the class now; authoring a full behavioral test suite for a 373-line
      harvested class with zero current consumers is not a trivial patch and is better
      done together with this class's first real caller.
    location: >-
      src/OcuPilot/Kernel/Utils.cls
    severity: medium
  - summary: >-
      Kernel.Utils.ReadRequestBody's inner fallback Catch (around %request.Content)
      silently reports a genuine read fault as an empty, successful body instead of the
      error its own doc comment says it distinguishes.
    evidence: |-
      Traced directly: the inner Catch sets tStream="" and execution falls through to
      "If '$IsObject($Get(tStream)) Quit", exiting with tSC still $$$OK. Real defect, but
      Kernel.Utils has zero consumers and zero test coverage in this story (see the
      companion deferred entry), so fixing this one path without a test to exercise it
      would leave it unfalsifiable — defer to be fixed together with this class's first
      real test host.
    location: >-
      src/OcuPilot/Kernel/Utils.cls (ReadRequestBody)
    severity: medium
  - summary: >-
      OcuPilot.Api.Router.ReportHttpStatusCode's new $$$ISERR(pSC) branch (rendering an
      internal-error envelope when %CSP.REST itself passes a failing status) has no test
      forcing that path, only the harvested 404/else paths.
    evidence: |-
      Verified via irislib/%CSP/REST.cls:351-421: OnPreDispatch's own error status is
      re-thrown by $$$ThrowOnError and caught by DispatchRequest's outer Try/Catch, which
      is the one call site that ever passes a genuine error pSC into
      ReportHttpStatusCode. No fixture route or test in this story forces OnPreDispatch
      itself to throw (as opposed to a deliberate pContinue=0 denial with tSC=$$$OK), so
      this specific branch is unexercised. Reasonable follow-up (a new fixture mechanism
      to force OnPreDispatch to throw), not a blocker for this story.
    location: >-
      src/OcuPilot/Api/Router.cls (ReportHttpStatusCode)
    severity: medium
  - summary: >-
      No test asserts that Api.Error.RenderInternal's call into Kernel.Audit.Log.Error
      actually carries the exception's subsystem/message/detail correctly.
    evidence: |-
      Partially addressed: a real Flag/Severity argument-order defect in
      Kernel.Audit.Log.Emit was found and fixed this pass, with a new direct test
      (OcuPilot.Test.Log) pinning the class's own severity/flag mapping and
      never-throws contract. What remains untested is the specific RenderInternal ->
      Log.Error wiring (subsystem "router", message "Internal error", the exception's
      DisplayString() as detail) — asserting it well needs either a stub seam or reading
      the live console log file, both more than a trivial patch.
    location: >-
      src/OcuPilot/Api/Error.cls (RenderInternal)
    severity: medium
  - summary: >-
      The AC's "bundle filenames carry content hashes" claim is tested only at the
      outputHashing:"all" config-knob level; nothing asserts on the actual built
      filenames in ui/dist/.
    evidence: |-
      Verified by inspection of ui/tools/angular-json.test.mjs (asserts the config value
      only) and independently confirmed, by actually running npm run build in this pass,
      that the real output is hashed (main-ZVKF3V26.js, styles-5INURTSO.css) — so the AC
      currently holds, but nothing would catch a regression where the config were correct
      yet the build tool stopped honoring it. A build-invoking test is materially heavier
      than the existing pure-config node --test suite; deferred rather than folded in.
    location: >-
      ui/tools/angular-json.test.mjs
    severity: low
  - summary: >-
      Kernel.Utils.ValidateInteger's doc comment says it accepts an "optionally signed"
      integer, but the pattern match only accepts a leading "-", not "+".
    evidence: |-
      Verified against the pattern (pValue '? 1.N && (pValue '? 1"-"1.N)): a value like
      "+5" satisfies neither branch and is rejected. This is a faithful harvest (AD-23) of
      pre-existing behavior with no call site in this story; correcting it in isolation
      from its harvest source is not this story's problem.
    location: >-
      src/OcuPilot/Kernel/Utils.cls (ValidateInteger)
    severity: low
  - summary: >-
      Test.Http.RawRequest has no final Else branch for an unsupported HTTP method,
      unlike its sibling MakeRequest, which does.
    evidence: |-
      Verified by reading both methods side by side. Test.Http has no consumer in this
      story (Story 1.5 is its first, per Design Notes); the natural point to harden this
      helper is when it gets its first real caller and real usage patterns.
    location: >-
      src/OcuPilot/Test/Http.cls (RawRequest)
    severity: low
  - summary: >-
      ui/package.json declares a "test"/"pretest" script but angular.json has no test
      architect target and no test runner is installed, so npm test cannot currently
      succeed; no .spec.ts file exists despite tsconfig.spec.json being wired for one.
    evidence: |-
      Verified: angular.json defines only build/serve targets; package-lock.json resolves
      no karma/jasmine-core as installed dependencies. Real, but no AC in this story
      requires a working ng test, and Stories 1.2/1.9/1.10 add the first real UI code this
      story's own scope explicitly excludes — the natural point to wire a runner and a
      first spec is whichever of those adds the first component worth testing.
    location: >-
      ui/package.json
    severity: low
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
- `src/OcuPilot/Kernel/Utils.cls` -- `OcuPilot.Kernel.Utils`: the harvest-plan-authoritative eleven methods and their two governing Parameters, renamed, with no `%Atelier` reference; `InvokeWithArgs` and `BYREFNODECEILING` are deliberately not harvested — see Design Notes finding 3 -- taken before the router because everything downstream uses it (harvest plan, Step 0).
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

### Review Findings

Independent code review, 2026-09-09. Four layers ran (blind-hunter, edge-case-hunter, verification-gap, acceptance-auditor); none failed. 11 patch groups applied, 8 deferred to the ledger, 12 rejected. Suite after patches: **29/29** ObjectScript (EntityId 3, Envelope 9, Log 5, Routing 12 — confirmed per class by the `%UnitTest_Result` SQL probe, not the runner envelope) and **17/17** `node --test tools/`; `check-objectscript.py` exits 0; the version-guard CLI still fires (exit 0, correct message).

**Rule 3 (real-runtime evidence) — satisfied.** The in-process router tier is real-runtime evidence for what it covers: `Test.Dispatch` calls the real `%CSP.REST.DispatchRequest`, which runs the real generated `DispatchMap` matcher, the real `$$$ThrowOnError(..OnPreDispatch(...))` seam and both real framework-error overrides, capturing the genuinely unparsed body the `}{` assertion needs. The `ui/` half is stronger still — `build-output.test.mjs` invokes the real `ng build` and asserts on real emitted filenames. What the tier is *not* evidence for is anything inside `Page()`; see the patch on `RouterFixture`'s doc comment and DW-25.

**Rule 19 (falsifiability) — one HIGH found and fixed.** The 12 plan-stage mutations are recorded as predictions, not in Rule 19's `mutation: <what> → <which test>` grammar next to each test; only QA's 2 are. Rather than take the `## Auto Run Result`'s self-report on trust — a log this review has now shown carries two false "Fixed:" claims — the highest-value one was re-run live: **re-applying the exact Flag/Severity swap this story reported fixing, at `Kernel/Audit/Log.cls`'s console call site, left the entire suite green** (Log 4/4, Envelope 8/8, Routing 12/12). `Test.Log` pinned the pure `ResolveSeverityAndFlag` lookup, not the call site where the defect actually lived. Fixed below, with the mutation demonstrated red and reverted.

- [x] [Review][Patch] The story's one HIGH defect was unpinned — a mutation of the corrected call site left all 27 tests green [src/OcuPilot/Kernel/Audit/Log.cls:54] — added a `WriteConsole` seam, `OcuPilot.Test.LogProbe` capturing its four arguments, and `Test.Log.TestEmitPassesFlagAndSeverityInThatOrder`. `mutation:` swap `tFlag`/`tSeverity` in `Emit`'s `WriteConsole` call → `TestEmitPassesFlagAndSeverityInThatOrder` red (4 assertions), `TestSeverityAndFlagMapping` still green — applied live, observed, reverted, tree confirmed byte-identical by checksum.
- [x] [Review][Patch] The Review Triage Log records two fixes that are not in the code [src/OcuPilot/Test/Envelope.cls:23, src/OcuPilot/Test/Dispatch.cls:54] — line 261 claims "added `Quit` immediately after the assertion inside the `Catch`" (there was none; `tObj.error` then ran against `tObj=""`) and line 249 claims the cleanup guard was "moved to before those two statements" (`Set tCapturing = 1` was still after `Open`/`Use`/`ReDirectIO(1)`). Verified no commit after `94f32e5` touched either file. Both fixes now actually applied.
- [x] [Review][Patch] `RouterFixture`'s AD-12 justification names a framework mechanism that does not exist [src/OcuPilot/Test/RouterFixture.cls:143] — it claimed `DispatchRequest`'s outer `Try`/`Catch` "routes any exception it catches to `ReportHttpStatusCode`". Verified false: `irislib/%CSP/REST.cls:415-419` is `Catch (e) { Set sc = e.AsStatus() }` then `Return sc`. The conclusion survives by a different route — `Page()` (`:205-210`) calls `..Http500(...)`, and `Http500` (`:493`) is `..ReportHttpStatusCode(500, pE.AsStatus())`, which dispatches to this tree's override — so AD-12 does hold over the wire, just not in-process. Comment rewritten with the verified mechanism and the testing consequence.
- [x] [Review][Patch] `check-objectscript.py`'s `p`-prefix rule still blocks the `%OnNew(initvalue)` signature `.claude/rules/objectscript-testing.md` mandates [scripts/check-objectscript.py:199] — the review pass narrowed the `%`-in-name ban to unblock `%OnNew` and stopped one rule short; demonstrated by running the checker's own regexes against that signature (`parameter 'initvalue' does not start with p`). Added a `FRAMEWORK_CALLBACKS` exemption; re-probed clean.
- [x] [Review][Patch] The pre-commit hook's ObjectScript trigger cannot match a file directly under `src/OcuPilot/` [.githooks/pre-commit:66] — a git pathspec is not a shell glob: without `:(glob)`, `src/OcuPilot/**/*.cls` requires an intermediate directory. Demonstrated: `git ls-files -- 'scripts/**/*.py'` returns nothing while `'scripts/*.py'` returns three files. A stray `src/OcuPilot/Stray.cls` therefore never fired the hook — exactly the case `check_package_placement` was added to catch. Root-level pathspecs added.
- [x] [Review][Patch] `check_write_discipline` silently exempted every `.mac` and `.inc` from AD-12's one-writer rule [scripts/check-objectscript.py:232] — the docstring's stated scope covers them; the code did `if p.suffix != ".cls": continue`. Now scans all three suffixes (XData tracking is a harmless no-op for routines).
- [x] [Review][Patch] The version-guard CLI entry fails open [ui/tools/version-guard.mjs:119] — `import.meta.url === \`file://${process.argv[1]}\`` compares a percent-encoded URL against a raw path, so on any checkout path with a space `main()` never runs and `prebuild`/`pretest` exit 0 having checked nothing, silently voiding AC-3's "the CLI entry exits non-zero before any compilation starts". Now `pathToFileURL(process.argv[1]).href`.
- [x] [Review][Patch] `npm start` bypassed the version guard, and nothing in the repo ran the node tests [ui/package.json:10] — added `prestart` and a `test:tools` script so `node --test tools/` is discoverable rather than remembered (partially addresses DW-30).
- [x] [Review][Patch] `.gitignore` misses build/bytecode outputs that dirty the tree [.gitignore] — `ui/out-tsc/` (both tsconfigs write there) and `__pycache__/`, which running the new checker creates under `scripts/`. An untracked `__pycache__/` blocks the next `bmad-build-auto` dispatch under Rule 16.
- [x] [Review][Patch] QA's build test discarded build diagnostics and over-pinned the hash format [ui/tools/build-output.test.mjs:25] — a failing build reported only an exit code; and `[0-9A-Z]{8}` pins esbuild's current hash format rather than the AC's claim. Now surfaces stdout/stderr on failure and matches `[0-9A-Za-z]{6,}`; the "no unhashed filename" assertion carries the rest. Also fixed the 405 reason's grammar ("Only GET, POST is allowed" → "This route allows only GET, POST"), which the client renders verbatim.
- [x] [Review][Defer] `Kernel.EntityId` is a byte/Latin-1 codec; a browser-encoded id does not round-trip [src/OcuPilot/Kernel/EntityId.cls:21] — deferred: DW-31, routed to Story 1.5. Probed live: `Encode("café")` → `caf%E9`, but `Decode("caf%C3%A9")` (what `encodeURIComponent` sends) returns a 5-character string that is not the original. Both corpus tests pass because both halves are the same ObjectScript pair. AD-13's Rule as written is satisfied; the wire behavior is 1.5's replay to settle.
- [x] [Review][Defer] The structural `XData UrlMap` ordering check the Design Notes promise does not exist [scripts/check-objectscript.py] — deferred: DW-32, **escalated** to the epic decision sheet. Fix-risk raised to high on the ground that its correctness cannot be demonstrated in this story: the production `UrlMap` is empty, so there is no real route to validate a new checker rule against, and authoring an unvalidated gate is precisely the failure this review just found three instances of. The Design Notes' claim that "the structural check is what catches the first real violation in Story 1.5" should not be relied on until this is built.
- [x] [Review][Defer] `OnPreDispatch` validates the resolved namespace and discards it, though the Task item and Design Notes both say it "stashes the result" [src/OcuPilot/Api/Router.cls:84] — deferred: DW-33, routed to Story 1.11. The code is correct for this story; adding undemonstrated process-wide state with no consumer was rejected. 1.11 adds the stash and its first consumer together.
- [x] [Review][Patch] `GetSlugForStatus` shipped entirely unexecuted, and the router derived a numeric machine code from it [src/OcuPilot/Api/Router.cls:109, src/OcuPilot/Api/Error.cls:146] — reachable, not theoretical: `%CSP.REST.Page():169` calls `..Http403()`, which lands in this branch. It emitted `"ROUTE." _ tStatus` → `ROUTE.403`, a number, which the Design Notes explicitly rule out ("a stable dotted uppercase identifier ... rather than a number, so that adding a code never renumbers an existing one"). The code is now derived from the slug (`ROUTE.FORBIDDEN`), and `Test.Envelope.TestSlugForStatusMapping` pins all twelve mappings plus the fallback and the derived code's shape. `mutation:` swap the 401 and 403 returns in `GetSlugForStatus` → `TestSlugForStatusMapping` red (3 assertions) — applied live, observed, reverted, checksum-verified. Residual (the `Else` branch having no dispatch-level test) narrowed into DW-35, routed to Story 1.5.
- [x] [Review][Defer] `check-objectscript.py` has no test of its own; AC-5 rests on one-off manual runs [scripts/check-objectscript.py] — deferred: DW-36, routed to Story 1.17. This review found three real gaps the implement pass missed, so "green" and "the rules stopped matching" are currently the same observable.
- [x] [Review][Defer] `CLAUDE.md`'s "Running and verifying" is stale — no `check-objectscript.py`, still "TODO once code exists" for the Angular build/test — deferred: DW-34, `owner=burndown`. Step-04 routes any fix that edits an agent-context file to defer.
- [x] [Review][Defer] `RenderInternal` → `Log.Error` wiring still unasserted — DW-26, occurrence appended. Cheaper now that the `WriteConsole` seam exists, but `RenderInternal` names `OcuPilot.Kernel.Audit.Log` by hard class name, so a probe subclass cannot intercept it.
- [x] [Review][Defer] `ValidateInteger`'s "optionally signed" doc-vs-behavior gap — DW-28, unchanged; `Kernel.Utils` still has no consumer or test host (DW-23).
- [x] [Review][Defer] `Test.Http.RawRequest` has no final `Else` — DW-29, unchanged; first consumer is Story 1.5.

**DW-27 closed.** Verified as the lead asked: `ui/tools/build-output.test.mjs` runs the real `npm run build` against a cleaned `ui/dist/` and asserts on the actual emitted filenames, not the config knob. It passed in this review's own run. Ledger trailer written: `status=resolved-by:1-1-...`.

#### Rejected

- `false` — "`DecodeUtf8Stream` spins forever because `Read()` overwrites `tChunkSize` ByRef" (edge-case-hunter). Refuted: the call is `pRawStream.Read(tChunkSize)` with no leading `.`, so ObjectScript passes by value and the callee's write-back never propagates.
- `false` — "`ApplyOutputCeiling` leaves `pTruncated` undefined on the no-truncation path" (edge-case-hunter). Refuted: the method's own doc states this contract ("an already-true value the caller passed in ByRef is left untouched, so a caller ORs this in for free"). Documented by design.
- `false` — "sprint-status says `review` while the spec frontmatter says `done`" (edge-case-hunter). Refuted: that is the expected mid-cycle state; this stage syncs it.
- `false` — "`Test.Dispatch.Invoke` leaks `%request`/`%response`, so `TestUnknownSlugIsRefused`'s premise is false" (verification-gap/acceptance-auditor). The leak is real, but the refusal is checked before any `%response` access (`Error.cls:73-80`), so the assertion holds in either state; only the doc comment's *reasoning* is loose, and its fix edits prose the checker does not read.
- `false` — "`ReportHttpStatusCode`'s `$$$ISERR` branch answers `Http403(pSC)`/`Http404(pSC)` with a 500" (acceptance-auditor). Checked every framework call site: `%CSP.REST` calls `Http403()` with no argument (`:169`, `pSC` defaults to `$$$OK`) and `Http500(e)` with an error (correctly 500). No reachable path passes an error status with a non-500 code. Recorded as `wontfix-theoretical`; it becomes real the day project code calls `Http404(sc)`.
- `false` — "AD-27 (image tag pinned) is violated" (acceptance-auditor). The pin is Story 1.4's AC (`epics.md:1095`) and this story's Boundaries exclude container work; AD-27 is over-declared in the Design Notes list, and correcting that edits the spec under review.
- `false` — "`Test.Http` commits a credential" (blind-hunter). `TESTPASSWORD = "SYS"` is the documented container default already published in `CLAUDE.md` and `README.md`; not a secret.
- `low` — `WRITE_RE` is case-sensitive with no abbreviated form, so `write "x"` / `w "x"` pass. Re-raised by two layers with a fresh demonstration, but already adjudicated twice in the implement pass on a stated rationale (matching a bare `w` would flag ordinary identifiers), and the checker's own docstring discloses it is "deliberately line-oriented rather than a full UDL parser". Reaffirmed reject; the case-only half remains the safer future fix.
- `low` — `METHOD_RE`'s `[^)]*` and `extract_param_names`' naive comma split mis-parse a signature with `)` or `,` inside a parameter default. No such signature exists in the tree; the fix is a balanced-paren scanner, not a direct correction. `wontfix-accepted`, reopen if any project signature acquires such a default.
- `low` — `TestOrderingGuardBeforeCatchAll` would also pass with the catch-all deleted (blind-hunter). True but not the failure mode: moving the guard *below* the catch-all does turn it red, which is the invariant the test names.
- `low` — `Api.Response.JSONStatus`, `Api.Error.Render501` and `Test.Http` are shipped but unexercised. Real, disclosed, and each has a named first consumer in Story 1.5; not worth new fixture routes now.
- `low` — `t`-prefix not used for loop indices (`For i=1:1:…`) in `Test/Routing.cls:151` and `Test/EntityId.cls:14`. This spec's Design Notes already settle the `t` prefix as a review convention rather than a checked rule.

## Spec Change Log

## Review Triage Log

### 2026-09-09 — Review pass
- verdicts: 41 findings — high 1, medium 13, low 20, false 7, maybe-false 0
- findings:
  - `medium` `patch` blind-hunter: `check-objectscript.py`'s XData exemption never activates because `xdata_depth` was computed from the `XData Name [...]` declaration line itself, whose `{` is on the next line — verified with a synthetic scratch file; rewrote `check_write_discipline` as a 3-state (none/awaiting-open/inside) machine and confirmed the same scratch file now correctly exempts XData content.
  - `low` `reject` blind-hunter: write-discipline scan isn't comment/string-aware beyond `///`/`;`/whole-line block comments (a same-line `/* Write */`, a trailing `; ... Write` after code, or a string literal containing "Write" could false-positive) — unlikely given this tree's actual style, and the checker's own docstring already discloses it is "deliberately line-oriented rather than a full UDL parser"; a full comment/string-aware lexer is more than a direct correction.
  - `medium` `patch` blind-hunter: AC "every project class lives under `src/OcuPilot/` in one of the seven fixed package folders" had no corresponding check in `check-objectscript.py` — verified (no folder-name logic anywhere in the 234-line script); added `check_package_placement`, verified it flags a synthetic `OcuPilot.Bogus.Stray` class and passes the real tree.
  - `low` `patch` blind-hunter: the checker's own docstring claimed "four ACs" but numbered only three — resolved as a side effect of the package-placement fix above; docstring now numbers and describes four.
  - `medium` `defer` blind-hunter: `Kernel.Utils.cls` (373 lines) has no dedicated test and no production call site in this story, unlike `Test.Http` it carried no "no consumer" note — added that note now (mirroring `Test.Http`'s pattern); authoring a full behavioral test suite for a 373-line harvested class with no current consumer is not a trivial patch, so the test-authorship gap itself is deferred to this class's first real consumer story.
  - `medium` `patch` blind-hunter: `Kernel.Utils.cls` omits `InvokeWithArgs` and `BYREFNODECEILING` (spec Code Map named 12 methods/3 Parameters; delivered has 11+3 new/2) with no Design Notes entry documenting the deviation as deliberate — verified against `HARVEST-PLAN.md`'s own Step 0 table (11 methods, matching delivered code) and the harvest source; added Design Notes finding 3 and corrected the Task item's wording.
  - `low` `patch` blind-hunter: `RouterFixture.cls`'s `ThrowingRoute` doc comment claimed "every handler carries one [Try/Catch]" when 9 of 12 fixture routes have none — verified against `irislib/%CSP/REST.cls:351-421`, which shows `DispatchRequest`'s own outer Try/Catch wraps every route's `Call` target and routes any exception to `ReportHttpStatusCode` (which this class overrides through `Api.Error`), so AD-12 still holds for those routes; reworded the comment to explain the real mechanism instead of overstating a per-route pattern.
  - `low` `defer` blind-hunter: `ui/package.json` declares `"test": "ng test"`/`"pretest"` but `angular.json` has no `test` architect target and no test runner is installed — real, but out of this story's own ACs (no AC requires a working `ng test`, and Stories 1.2/1.9/1.10 add the first real UI code); the natural point to wire a runner and a first spec is the story that adds the first component worth testing.
  - `low` `defer` blind-hunter: no `.spec.ts` file exists anywhere under `ui/src/`, despite `tsconfig.spec.json` being wired for it — same root cause as the row above.
  - `low` `patch` blind-hunter: `Test.Dispatch.cls`'s `Invoke` set its cleanup guard `tCapturing = 1` only after `Open`/`Use` had already executed, so a throw from either would skip cleanup — real but narrow (a null-device `Open`/`Use` essentially never fails); moved the guard to before those two statements, a direct one-line reorder.
  - `low` `patch` blind-hunter: `.githooks/pre-commit`'s failure banner only mentioned markdown remediation even though `check-objectscript.py` (added in this same diff) can also set `STATUS=1` — added a second remediation line naming the ObjectScript/ui gate.
  - `low` `reject` edge-case-hunter: `WRITE_RE` is case-sensitive with no abbreviated-command form (misses `w "x"`) — real in principle, but ObjectScript command abbreviation is not this codebase's style anywhere in the tree, and a naive case-insensitive/abbreviated match on a single letter like "w" would flag ordinary variable names and text, trading a low-probability gap for a real regression.
  - `low` `reject` edge-case-hunter: a same-line `/* ... Write ... */` block comment could false-positive — same root cause and disposition as the blind-hunter write-discipline row above.
  - `medium` `patch` edge-case-hunter: XData declaration with the attribute block before the opening brace breaks the checker's brace tracking — same root cause and fix as the blind-hunter XData row above.
  - `medium` `patch` edge-case-hunter: a future class declaring a standard framework override (`%OnNew`, `%OnClose`, ...) would fail the method-naming gate — verified directly by tracing `check_naming`'s regex against the literal name `%OnNew` (flagged before the fix); `.claude/rules/objectscript-testing.md` already discusses overriding `%OnNew` on `%UnitTest.TestCase` subclasses in this very project, so this was reachable soon, not hypothetical. Fixed: dropped the `%` check for method and class-parameter names (kept for class/property names), matching `.claude/rules/objectscript-basics.md`'s actual text, which never extends the `%` ban past class/property names.
  - `high` `patch` edge-case-hunter: `Kernel.Audit.Log.Emit` passed `tSeverity`/`1` into `$ZU(9,"",tLogLine,tSeverity,1)` in the wrong argument order — verified definitively against the live instance's own implementation (`irissys/%SYS/System.cls:170-176`, `WriteToConsoleLog` calls `$zu(9,"",Message,Flag,Severity,Event)`, Flag before Severity), so every OcuPilot log line was written with severity hardcoded to 1 (Warning) regardless of actual level, and debug shared info's severity. Fixed: replaced the raw `$ZU` call with the documented `##class(%SYS.System).WriteToConsoleLog(...)` wrapper and extracted the mapping into a new public `ResolveSeverityAndFlag` method; added `OcuPilot.Test.Log` with a `TestSeverityAndFlagMapping` test pinning all four levels, and demonstrated the mutation (reverting to the swapped mapping) turns it red, then reverted.
  - `false` `reject` edge-case-hunter: "if `Kernel.Audit.Log.Error`'s write fails inside `RenderInternal`, the lost audit write is invisible" — refuted by the class's own explicit, documented contract ("never throwing and never failing its caller... logging is informational and must not affect application behavior," Consistency Conventions: Logging); an informational logger that cannot observably fail its caller is the intended design, not a defect.
  - `false` `reject` edge-case-hunter: "`Api/Response.cls`'s `JSON`/`JSONStatus` aren't wrapped in Try/Catch unlike `Error.cls`" — refuted: the Code Map explicitly directs copying the 33-line harvested original "nearly as-is" (AD-23), and `%CSP.REST.DispatchRequest`'s own outer Try/Catch (`irislib/%CSP/REST.cls:351-421`) already provides the equivalent safety net for any handler, harvested or not.
  - `low` `reject` edge-case-hunter, intent-alignment: `OnPreDispatch`/`ReportHttpStatusCode`/`Http405`/`NestedCatchRoute` discard `Api.Error.Render*`'s returned `%Status` via bare `Do` — real in principle, but every current call site passes a compile-time-fixed valid slug/code literal, so the failure path is unreachable today, and there is no good fallback if the tree's own designated error writer itself failed (checking and then doing what?) — the fix would add unclear-value complexity rather than a direct correction.
  - `low` `defer` edge-case-hunter: `Kernel.Utils.ValidateInteger`'s doc comment says "optionally signed" but the pattern only accepts a leading `-`, not `+` — real, but this method is a faithful harvest (AD-23) with no call site in this story; not this story's problem to correct in isolation from its harvest source.
  - `medium` `defer` edge-case-hunter: `Kernel.Utils.ReadRequestBody`'s inner fallback `Catch` (around `%request.Content`) sets `tStream=""` and falls through to a plain `Quit`, so a genuine read fault there is reported as `$$$OK` with an empty body rather than the fault the method's own doc comment says it distinguishes — verified by tracing the control flow; real defect, but `Kernel.Utils` has zero consumers and zero test coverage in this story (see the deferred no-test-host entry), so fixing this one path without a test exercising it would leave Rule 19 unsatisfied — deferred to be fixed together with this class's first real test host.
  - `low` `patch` edge-case-hunter: `Test.Envelope.AssertSingleEnvelope`'s `Catch` records a failed assertion via `$$$AssertTrue(0, ...)` but does not `Quit`/`Return`, so execution falls through to `tObj.error` on `tObj=""` (a plain string) — verified this would raise a dot-syntax runtime error on any object member access against a non-object, exactly when the test is already reporting a different failure, degrading the diagnostic at the worst time. Fixed: added `Quit` immediately after the assertion inside the `Catch`.
  - `low` `defer` edge-case-hunter: `Test.Http.RawRequest` has no final `Else` for an unsupported method (unlike `MakeRequest`, which has one) — real, but `Test.Http` explicitly has no consumer in this story (Story 1.5 is its first, per Design Notes); the natural point to harden it is when it gets its first real caller.
  - `low` `reject` edge-case-hunter: `.githooks/pre-commit` triggers `check-objectscript.py` based on staged files but the checker itself scans the whole working tree, so an unrelated unstaged violation could block an otherwise-clean commit — real, but the pre-commit script's own comment already discloses this tradeoff ("it always scans the whole ... tree ... not a filtered file list") and names the workaround (`git commit --no-verify`); a per-file mode is a larger change than this review's scope.
  - `low` `patch` edge-case-hunter, intent-alignment: the Task item for `Test.Dispatch.cls` said "redirect `$IO` to a temp file," but the delivered mechanism is a bound mnemonic I/O space over the null device, not a temp file — verified against the delivered code; corrected the Task item's wording to describe the actual (and, for this purpose, better — no disk I/O or cleanup) mechanism.
  - `medium` `patch` edge-case-hunter: same `InvokeWithArgs`/`BYREFNODECEILING` omission as the blind-hunter row above — same evidence and same fix (Design Notes finding 3, Task item correction).
  - `low` `reject` edge-case-hunter: same `WRITE_RE` case/abbreviation gap as the row above, restated as an AC-coverage claim — same disposition.
  - `medium` `defer` verification-gap (pre-verified, filed disposition respected): `ReportHttpStatusCode`'s `$$$ISERR(pSC)` branch (new vs. the harvested source) is reachable — via `OnPreDispatch` itself throwing, propagated by `$$$ThrowOnError` and caught by `DispatchRequest`'s own outer Try/Catch, per `irislib/%CSP/REST.cls:351-421` — but no fixture route or test forces `OnPreDispatch` to throw, so the branch is unexercised; deferred as reasonable follow-up requiring a new fixture mechanism, not a blocker for this story.
  - `medium` `defer` verification-gap (pre-verified): no test asserts that `RenderInternal`'s call to `Kernel.Audit.Log.Error` actually carries the exception detail — partially addressed (the `Kernel.Audit.Log` Flag/Severity bug found independently is now fixed and the class has its own direct test host for the first time), but the specific `RenderInternal` → `Log.Error` wiring (subsystem, message, detail) remains unasserted; deferred, since asserting it well requires either reading the live console log file or a stub seam, both larger than a trivial patch.
  - `medium` `patch` verification-gap (pre-verified): same seven-fixed-package-folders AC gap as the blind-hunter row above — same fix.
  - `medium` `defer` verification-gap (pre-verified): same `Kernel.Utils` no-executed-test-host finding as the blind-hunter row above — same disposition (doc note added now, full test suite deferred).
  - `low` `defer` verification-gap (pre-verified): the AC's content-hash claim ("bundle filenames carry content hashes") is only tested at the `outputHashing: "all"` config-knob level; no test reads `ui/dist/`'s actual filenames — real, and I independently confirmed via a real `npm run build` in this pass that the built output is in fact hashed (`main-ZVKF3V26.js`, `styles-5INURTSO.css`), but a build-invoking assertion is a materially heavier test than the existing pure-config `node --test` suite; deferred rather than folded in as a trivial patch.
  - `low` `patch` verification-gap (pre-verified): same pre-commit banner gap as the blind-hunter row above — same fix.
  - `false` `reject` intent-alignment: "four utility classes" (Approach) vs. six delivered production classes reads as ambiguous — resolves cleanly on a careful reading: the four "utility classes" are `Response`/`Error`/`Log`/`Utils` (all harvested), the separately-named "one router" is the fifth harvested item called out by role, and `EntityId` is newly authored (per Design Notes, "a slice that writes its own codec is the failure this class prevents") and simply isn't named in the terse Approach sentence at all — a single defensible reading, not a genuine multi-way ambiguity.
  - `false` `reject` intent-alignment: the `t`-prefix-for-locals convention isn't mechanically gated — already resolved in this spec's own Design Notes ("Local-variable prefixes are a review convention, not a checked rule"); not a new finding.
  - `false` `reject` intent-alignment: `Set tSC = $$$OK`/Try-Catch shape isn't applied uniformly (harvested validators and thin-wrapper overrides skip it) — refuted by AD-23 ("harvested bodies keep their call sites; only the base class changes"), already recorded in Design Notes; the split tracks exactly harvested/thin-wrapper code vs. newly authored control flow.
  - `low` `reject` intent-alignment: same discarded-`%Status` finding as the edge-case-hunter row above, restated as a reading divergence — same disposition.
  - `false` `reject` intent-alignment: "nothing in the diff is an executed build log/MCP output/SQL-probe output" — true of the diff text in isolation (that reviewer's own containment forbade it from running anything), but refuted as a claim about this story's actual completion state: this pass directly executed `npm ci`/`npm run build`/`node --test`, IRIS MCP `iris_doc_load`/`iris_doc_compile` (12→13 classes clean) and `iris_execute_tests` per class, and confirmed 27/27 via the `%UnitTest_Result` SQL probe.
  - `false` `reject` intent-alignment: same write-discipline-is-lexical-not-semantic observation as the blind-hunter/edge-case-hunter rows above — already disclosed in the checker's own docstring, not a new finding.
  - `false` `reject` intent-alignment: the version-guard CLI's `process.exit(1)` path is untested (only the pure predicate is) — already explicitly named and accepted in this spec's own Task item text ("this is the only way to assert it without installing Node 20"); a already-accepted design choice, not an undocumented gap.

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

**Three findings that change the implementation, recorded with their evidence:**

1. **`Utils.cls` carries no `%Atelier` coupling.** The AC says "`Utils`' `%Atelier` coupling is dropped". Verified directly: `grep -in atelier /Users/jbrandt/git/iris-execute-mcp-v2/src/ExecuteMCPv2/Utils.cls` returns nothing, the class `Extends %RegisteredObject`, and it has no `Include` line. The coupling in that repository lives in files this story does **not** copy — `Tests/BaseTest.cls` (10 hits), `REST/Base.cls` (9), `Setup.cls` (4), `REST/{EnvSync,Dispatch}.cls` (2 each), `Loc/Scanner.cls` (2), and four others with one each. Treatment: satisfy the AC as a **guard**, not a deletion — `%Atelier` is a forbidden token in `scripts/check-objectscript.py`, so the day a later harvest drags `%Atelier.REST`'s `{status, console, result}` envelope in (which AD-23 exists to prevent), the check fails. This is deliberately not a no-op test: its mutation is demonstrable.

2. **`%CSP.REST` provides no post-dispatch hook, so `OnPreDispatch` resolves but does not hold a namespace switch.** `Page()` at `irislib/%CSP/REST.cls:132-231` never calls `OnPostHTTP`; `DispatchRequest` (351) returns straight to `Page()`. A `Set $NAMESPACE` performed in `OnPreDispatch` therefore has nowhere to be restored and would leak into the next request on a reused CSP worker. The AC's clause "resolves the namespace **once**, in that one place, the namespace switched by explicit save and restore (AD-16) with `$NAMESPACE` restored as the first line of every `Catch`" is read accordingly, and it is the only implementable reading: **resolution and validation happen exactly once, in `OnPreDispatch`, which stashes the resolved namespace; the switch itself is a bounded save/restore through the one shared `Kernel.Utils.SwitchNamespace`/`RestoreNamespace` pair**, restore first in every `Catch` — which is also why the AC says "every `Catch`" in the plural. The alternative reading is not defensible, so this is a resolved reading rather than an intent gap.

3. **`Kernel.Utils` omits `InvokeWithArgs` (and its private helpers) and the `BYREFNODECEILING` parameter**, leaving 11 of the Code Map's named 12 methods plus 3 new ones (`WriteDecoded`, `SanitizeUnpairedSurrogates`, `IncompleteUtf8TailLength` — extracted from `DecodeUtf8Stream`'s body during implementation, not separately named in the Code Map) and 2 of the 3 named Parameters. Two things justify the omission rather than making it a defect: (a) `HARVEST-PLAN.md`'s own Step 0 table — the authoritative harvest source per this spec's `context:` list — names only eleven `Kernel.Utils` methods, omitting `InvokeWithArgs`; the Code Map's inline file-content citation and the harvest plan's own table disagree, and the harvest plan is the more authoritative of the two for *which* methods to harvest. (b) Nothing in this story's ACs, I/O matrix, or mutations exercises dynamic by-name class-method invocation, and the capability `InvokeWithArgs` provides — calling any class method by string name with `ByRef` positional arguments — already exists, gated, as the `iris-dev` MCP server's own `iris_execute_classmethod` tool; copying a second, ungated implementation of it into shipped `Kernel` code with no consumer and no story-mandated need is exactly the kind of avoidable security-relevant surface AD-8 ("privilege evaluated in the calling process at call time") argues against introducing without cause. Treatment: satisfied as a documented, evidence-backed deviation rather than harvested wholesale — if a later story needs by-name dynamic invocation, it re-evaluates `InvokeWithArgs` against that story's own actual consumer and gating requirements, rather than inheriting an unused, untested surface from this one.

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

**QA pass (`bmad-qa-generate-e2e-tests`, 2026-09-09) — added tests and their mutations.**

Scope: the deliverable of Story 1.1 (the diff since `ac652ec`), tested against this
spec's own Tasks & Acceptance and I/O & Edge-Case Matrix, using only the project's two
existing tiers (`%UnitTest` under `src/OcuPilot/Test/`, `node --test` under
`ui/tools/`). Full audit of all 7 Acceptance Criteria and all 15 I/O-matrix rows found
them already covered by the implementer's own suite, with one exception: the AC "the
emitted bundle filenames carry content hashes" was pinned only at the `outputHashing:
"all"` config-knob level (this spec's own `deferred:` entry on
`ui/tools/angular-json.test.mjs`), never against the real built output — closed below.
A second, smaller gap (`ui/.npmrc`'s `engine-strict`/`save-exact` values, named by a
Task item but never asserted, only mentioned in a comment string) was closed alongside
it. `scripts/check-objectscript.py`'s own two ACs (exits 0 over the real tree; a
deliberate violation makes it exit non-zero naming file+rule) were left untouched: they
were verified during implementation only against synthetic scratch trees outside the
repo, and giving them a durable regression test would mean either a new Python test
framework (excluded by this pass's own scoping decision, matching the project's
two-tier constraint) or a `node --test` file outside `ui/tools/` with no existing
command that discovers it (Rule 8) — both larger than this pass's mandate.

- `ui/tools/build-output.test.mjs` (QA, new file) -- `npm run build succeeds and emits content-hashed bundle filenames`: runs the real `ng build` (via `npm run build`) against a clean-room `ui/dist/`, then asserts the emitted `ui/dist/ocupilot-ui/browser/` filenames actually match `main-<HASH>.js` / `styles-<HASH>.css`, not just that the config knob is set — mutation: set `outputHashing` to `"none"` in `ui/angular.json` -> the test goes red (`main.js`/`styles.css`, no hash suffix); reverted, confirmed `git diff --stat` unchanged, rebuilt, confirmed green again (15/15 at the time, now 17/17 with the `.npmrc` tests below).
- `ui/tools/version-guard.test.mjs` (QA, 2 tests added to existing file) -- `.npmrc sets engine-strict=true, so npm ci fails outright on an unsupported Node version` and `.npmrc sets save-exact=true, so a later npm install cannot re-float the typescript pin`: read the real `ui/.npmrc` and assert both lines are present -- mutation: change `engine-strict=true` to `engine-strict=false` in `ui/.npmrc` -> the first test goes red; reverted, confirmed `git status --short`/`git diff --stat` unchanged, confirmed green again.

`mutations_demonstrated=2` (one per newly-added pinning test group above; both applied live, observed red, reverted, and the tree confirmed byte-identical via `git status --short` / `git diff --stat` before and after).

**Fix pack (lead-directed, 2026-09-09).** Four bounded fixes closing DW-26, DW-28, DW-29 and
DW-30 from this spec's own `deferred:` list and Review Triage Log. Each mutation below was
applied live against the classes compiled on `ocupilot-iris`/`HSCUSTOM` (or, for the `ui/`
fix, against the real `npm test` invocation), observed red, reverted, and the tree confirmed
unchanged (`git diff --stat`) before moving to the next.

- DW-26 — `Api.Error.RenderInternal`'s audit-log call was untestable: it named
  `OcuPilot.Kernel.Audit.Log` by hard class name, so no test could intercept it. Added an
  overridable `LogError` seam mirroring `Kernel.Audit.Log.WriteConsole`'s pattern, a new
  `OcuPilot.Test.ErrorProbe` subclass capturing the three arguments, and
  `Test.Envelope.TestRenderInternalRoutesSubsystemMessageAndDetailThroughSeam`. `mutation:`
  change the literal `"Internal error"` message `RenderInternal` passes to the seam to
  `"internal error"` → the new test's message assertion went red
  (`AssertEquals: RenderInternal logs message "Internal error" through the seam`) — applied
  live, observed, reverted; `Test.Envelope` reconfirmed 10/10 and
  `git diff --stat -- src/OcuPilot/Api/Error.cls` unchanged (22 insertions, 2 deletions,
  same as before the mutation).
- DW-28 — `Kernel.Utils.ValidateInteger`'s doc comment said "optionally signed" but the
  pattern (`pValue '? 1.N && (pValue '? 1"-"1.N)`) accepts only a leading `-`, never `+`.
  Corrected the doc comment only; the validation pattern is unchanged (widening it is
  explicitly out of scope — no consumer yet, per DW-23). Documentation-only change, so there
  is no code mutation to demonstrate and no pinning test to turn red — `Kernel.Utils` still
  has no dedicated test host in this suite (DW-23, deferred separately). Falsifiability
  evidence instead: a live probe against the compiled class confirms the doc's corrected
  claim on the instance — `ValidateInteger("+5", "test")` returns an error status
  ("Parameter 'test' must be a valid integer") and `ValidateInteger("-5", "test")` returns
  `$$$OK` (1) — unchanged before and after the doc edit, since no byte of the executable
  pattern changed.
- DW-29 — `Test.Http.RawRequest` had no final `Else` for an unsupported HTTP method, unlike
  its sibling `MakeRequest`, and fell through to read a response that was never requested.
  Added a final `Else { Quit "" }`, mirroring `MakeRequest`'s own guard. `mutation:` remove
  the added `Else` branch (reverting to the pre-fix fall-through) → a live probe,
  `##class(OcuPilot.Test.Http).RawRequest("PATCH", "/nonexistent", "", "application/json",
  .tStatus)`, raised `<INVALID OREF>` reading `tReq.HttpResponse.StatusCode` before any
  request had been issued — applied live, observed, reverted; recompiled clean, the same
  probe now returns `""` / `pStatus=0` with no error, and
  `git diff --stat -- src/OcuPilot/Test/Http.cls` unchanged (5 insertions, same as before
  the mutation).
- DW-30 — `ui/package.json`'s `"test": "ng test"` could never succeed (`angular.json` has no
  `test` architect target and no runner is installed). Pointed `test` at `node --test
  tools/`, the suite that actually exists; `pretest`'s version-guard hook is untouched.
  `mutation:` revert `"test"` to `"ng test"` → `npm test` (with `pretest` still firing
  first) failed with `Cannot determine project or target for command.` (exit 1) — applied
  live, observed, reverted; `npm test` now exits 0 (17/17) and
  `git diff --stat -- ui/package.json` unchanged (3 insertions, 1 deletion, same as before
  the mutation).

`fix_pack_mutations_demonstrated=3` code mutations (DW-26, DW-29, DW-30), each applied live,
observed red, reverted, and confirmed byte-identical via `git diff --stat`; DW-28 is a
documentation-only correction with no applicable code mutation, verified instead by a live
behavioral probe against the unchanged compiled method.

## Auto Run Result

**Summary.** Stood up the greenfield workspace exactly as specified: the seven fixed ObjectScript package folders under `src/OcuPilot/`, the pinned `ui/` Angular 22.1.5 / TypeScript 6.0.3 workspace with its pure version guard, four harvested utility classes renamed under OcuPilot's own names with no rename-checklist token surviving, one response writer (`Api.Response`), one closed-enum error envelope (`Api.Error`), and one `%CSP.REST` router (`Api.Router`) whose three route-ordering invariants, pre-dispatch identity/namespace seam, and framework-error overrides are each asserted behaviourally against `Test.RouterFixture`. The review pass that followed found and fixed a real severity/flag argument-order defect in the new structured logger, three real defects in the new mechanical ObjectScript checker (including one that would have blocked a documented, near-term IRIS framework pattern), and several smaller documentation/robustness fixes; eight remaining findings are recorded as deferred with evidence and location, and none of the review's findings constituted an intent gap or a bad-spec loopback.

**Files changed** (35 files touched; `ui/package-lock.json` generated by `npm ci`, omitted below):
- `src/OcuPilot/Api/Response.cls` — the one success-path response writer (`JSON`/`JSONStatus`), harvested near-verbatim.
- `src/OcuPilot/Api/Error.cls` — the one error writer: 12-slug closed enum, `Render`/`RenderInternal`/`Render405`/`Render501`/`GetSlugForStatus`, `{error,reason,code[,detail]}` envelope.
- `src/OcuPilot/Api/Router.cls` — `%CSP.REST` subclass: empty `UrlMap` (Story 1.5 owns the first route), `OnPreDispatch` (identity + namespace resolution), `ReportHttpStatusCode`/`Http405` overrides.
- `src/OcuPilot/Kernel/Utils.cls` — 11 harvested methods + 2 Parameters (see Design Notes finding 3 for the `InvokeWithArgs`/`BYREFNODECEILING` omission), now carrying a "no consumer in this story" note.
- `src/OcuPilot/Kernel/EntityId.cls` — the one shared `Encode`/`Decode` percent-encoding pair (AD-13).
- `src/OcuPilot/Kernel/Audit/Log.cls` — four-level structured logger; fixed during review to call the documented `%SYS.System.WriteToConsoleLog` wrapper with the correct Flag/Severity argument order (was swapped) via a new, directly-testable `ResolveSeverityAndFlag` method.
- `src/OcuPilot/Screen/.gitkeep`, `src/OcuPilot/Area/.gitkeep`, `src/OcuPilot/Port/.gitkeep`, `src/OcuPilot/Install/.gitkeep` — the four fixed package folders that take no class yet.
- `src/OcuPilot/Test/Dispatch.cls` — in-process dispatch harness (mnemonic-I/O-space capture); fixed a narrow cleanup-guard-ordering gap during review.
- `src/OcuPilot/Test/RouterFixture.cls` — fixture routes exercising all three ordering invariants, pre-dispatch denial, and the entity-id corpus; doc comment corrected during review.
- `src/OcuPilot/Test/Routing.cls` — 12 tests covering every routing/ordering/namespace/entity-id matrix row.
- `src/OcuPilot/Test/Envelope.cls` — 8 tests covering the envelope/key-set/internal-exception matrix rows, including one added during review for the previously-untested "handler success" row.
- `src/OcuPilot/Test/EntityId.cls` — 3 tests round-tripping the fixed corpus.
- `src/OcuPilot/Test/Log.cls` — new during review: 4 tests directly pinning `Kernel.Audit.Log`'s severity/flag mapping and never-throws contract.
- `src/OcuPilot/Test/Http.cls` — over-the-wire helper, ready to call, no consumer in this story (Story 1.5).
- `scripts/check-objectscript.py` — the mechanical tree checker; fixed three real defects during review (XData exemption never activated, method/class-parameter naming over-broad on `%`, missing package-placement check) and added the fourth check.
- `.githooks/pre-commit` — wired to run the checker on staged ObjectScript/`ui` files; failure banner corrected during review to mention it.
- `.gitignore` — excludes `ui/node_modules|dist|.angular`.
- `ui/package.json`, `ui/.npmrc`, `ui/angular.json`, `ui/tsconfig*.json` — the pinned Angular 22.1.5/TypeScript 6.0.3 workspace, `@angular/build:application` only, `outputHashing:"all"`/`baseHref:"/ocupilot/"` at options level.
- `ui/tools/version-guard.mjs`, `ui/tools/version-guard.test.mjs`, `ui/tools/angular-json.test.mjs` — the pure version-guard predicate/CLI and its 14 tests.
- `ui/src/index.html`, `ui/src/main.ts`, `ui/src/app/app.ts`, `ui/src/styles.css` — the minimum zoneless/OnPush bootstrap.
- `_bmad-output/implementation-artifacts/spec-1-1-...md` (this file) — `baseline_revision`, Design Notes finding 3, Task item corrections, Review Triage Log, `deferred:` list, this section.

**Review findings breakdown** (41 findings across 4 review layers; full evidence in `## Review Triage Log` above):
- **Patched (11 grouped root causes, applied directly per Rule 18):** the `Kernel.Audit.Log` Flag/Severity argument-order bug (high) with a new direct test and demonstrated mutation; `check-objectscript.py`'s XData-exemption-never-activates bug, its over-broad `%`-in-method/parameter naming check (would have blocked `%OnNew`), and its missing package-placement check (all medium), each verified against a synthetic scratch tree; the `Kernel.Utils` `InvokeWithArgs`/`BYREFNODECEILING` omission, now documented as Design Notes finding 3 with evidence (medium); `Test.Dispatch.Invoke`'s cleanup-guard ordering (low); `Test.Envelope.AssertSingleEnvelope`'s missing `Quit` after a failed-parse assertion, which could otherwise throw uncaught (low); the checker's stale "four ACs" docstring, the `pre-commit` failure banner, the `RouterFixture` doc-comment overstatement, and the `Test.Dispatch` spec-wording ("temp file" vs. the actual mnemonic-I/O-space mechanism) — all low, cosmetic/documentation corrections.
- **Deferred (8 entries, filed to frontmatter `deferred:` with evidence, location and severity):** `Kernel.Utils`'s missing test host (medium); a real fault-swallowing bug in `Kernel.Utils.ReadRequestBody`'s fallback path (medium); `Router.ReportHttpStatusCode`'s new internal-error branch being reachable but untested (medium); `RenderInternal`'s audit-log wiring being unasserted, now only partially addressed (medium); the content-hash AC being tested only at the config-knob level (low); `ValidateInteger`'s "optionally signed" doc-vs-behavior gap on harvested code (low); `Test.Http.RawRequest`'s missing `Else` branch (low); and `ui/package.json`'s `test` script having no working runner yet (low).
- **Rejected (22 findings, reasons recorded in the Review Triage Log):** 7 refuted as `false` (an ambiguity that resolves on careful reading; two already-settled Design Notes resolutions restated as new findings; a claim about "no executed verification" refuted by this pass's own direct execution; a disclosed lexical-checker limitation; an already-accepted version-guard testing gap); 15 rejected as `low` and not worth the fix's cost — mostly disclosed, deliberate simplifications (the write-discipline checker's lexical scope, the whole-tree-vs-staged-files scan) or currently-unreachable code paths whose fix would add complexity without a demonstrated benefit.

**Follow-up review recommendation: `true`.** One patched entry was `high` severity (the logging Flag/Severity swap) and four were `medium` — either condition alone crosses this pass's threshold. Named unverified risk: the high- and medium-severity defects above were found *and* fixed *and* verified within this same automated pass rather than by an independent follow-up — a fresh pass would give independent confirmation that (a) `check-objectscript.py`'s narrowed `%`-naming rule (now `_`-only for methods/class-parameters) doesn't miss a naming violation it should still catch elsewhere in the tree, and (b) `Kernel.Audit.Log`'s corrected `WriteToConsoleLog` call (in particular its `Event` parameter, `"OcuPilot.Log"`) behaves correctly under every log level in a review pass that didn't just write the fix being checked.

**Verification performed:**
- `cd ui && npm ci` — succeeded on Node 26.8.1.
- `cd ui && npm run build` — `@angular/build:application` succeeded; content-hashed output confirmed directly (`main-ZVKF3V26.js`, `styles-5INURTSO.css`).
- `cd ui && node --test tools/` — 14/14 passed.
- `uv run scripts/check-objectscript.py` — 0 problems, both before and after the review-pass fixes; the three fixes were additionally verified correct against synthetic scratch trees outside the repo (a `%OnNew` method, an XData block containing the literal word "Write", and an out-of-package `OcuPilot.Bogus.Stray` class) before being confirmed clean against the real tree.
- IRIS MCP `iris_doc_load`/`iris_doc_compile` (`server: "ocupilot-iris"`, namespace `HSCUSTOM`) — all 13 classes (12 delivered + `Test.Log` added during review) compile clean; re-verified after every review-pass edit.
- IRIS MCP `iris_execute_tests` per class for `Test.Routing` (12), `Test.Envelope` (8, incl. the review-added handler-success test), `Test.EntityId` (3) and `Test.Log` (4, new) — 27/27 passed; cross-checked against `%UnitTest_Result` via the SQL probe in `.claude/rules/objectscript-testing.md` (`Total=27, Passed=27, Failed=0`).
- Matrix Test Audit: all 15 I/O-matrix rows covered by a test that ran and passed, including the "handler success" row, which had no covering test until this pass (added `TestHandlerSuccessWritesJsonOnceWithContentType`, mutation-verified against `Api.Response.JSON`'s `ContentType` assignment).
- Mutations executed live and reverted (`git status --short`/`git diff --stat` confirmed unchanged after each): all 12 spec-listed mutations, plus 3 more from this review pass (`Kernel.Audit.Log`'s severity/flag mapping; the checker's XData exemption; the checker's package-placement check) — every one produced the expected red, then reverted clean.

**Residual risks:** the 8 deferred findings above, each with its own named severity and evidence; and the follow-up-review risk named above. No intent gap, no bad-spec loopback, and no `git commit`/`git push` performed by this agent or any subagent it spawned (verified: `git log --branches --not --remotes` shows no commit from any subagent).

Status: done
Blocking condition: none
