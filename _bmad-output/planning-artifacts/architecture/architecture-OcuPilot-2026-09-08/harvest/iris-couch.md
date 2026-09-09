# Harvest map — iris-couch (OcuPilot REST / hosting / installer patterns)

`/Users/jbrandt/git/iris-couch` · 146 `.cls` (64 production + 82 test), 108 `.ts` (40 spec), Angular 18.2.

## 1. REST router — copy the structure

`src/IRISCouch/API/Router.cls` (762) `Extends %CSP.REST`, plus 13 handler classes (`DocumentHandler` 818, `ChangesHandler` 534, `MangoHandler` 487, `BulkHandler` 440, `AdminUIHandler` 313, `ReplicationHandler` 279, `DatabaseHandler` 253, `AllDocsHandler` 258, `ViewHandler` 224, `AttachmentHandler` 195, `AuthHandler` 144, `SecurityHandler` 82, `ServerHandler` 70).

```objectscript
Class IRISCouch.API.Router Extends %CSP.REST
{
Parameter UseSession = 0;                      // stateless REST
Parameter CONTENTTYPE = "application/json";
```

**Three UrlMap ordering invariants** (`%CSP.REST` matches in file order — copy these rules):
1. **Explicit 405 method guards before the catch-all.** `PUT /_all_dbs` once fell through to `/:db` PUT and *silently created a database named `_all_dbs`*. Documented at `Router.cls:730`.
2. Sub-resource routes before `/:db`.
3. N-segment routes before (N−1)-segment routes.

**Thin wrapper pattern** — every `Call="X"` target is a 4-line ClassMethod that only delegates and records metrics. Zero business logic in the Router:
```objectscript
ClassMethod HandleDatabaseCreate(pDB As %String) As %Status
{
    Set tSC = ##class(IRISCouch.API.DatabaseHandler).HandleCreate(pDB)
    Do ..RecordRequestMetrics()
    Quit tSC
}
```

**Handler body shape** (all 13 follow it): outer `Try/Catch`, validate → check → act → render, never `Write` directly, always return `$$$OK`.

**`OnPreDispatch` seam** (`Router.cls:507-667`) — five concerns in strict order, able to short-circuit with `pContinue = 0`:

| # | Concern | Mechanism |
|---|---|---|
| 1 | Trailing-slash normalization | `pContinue=0` + re-`DispatchRequest(stripped)`. `%CSP.REST` won't match `/:db` against `/:db/`. |
| 2 | Auth context | sets `%IRISCouchUser`, `%IRISCouchRoles`, `%IRISCouchAuthMethod`. cookie → Bearer/JWT → proxy header → Basic. **Never blocks** — anonymous is a valid outcome. |
| 3 | SPA intercept | `$Extract(pUrl,1,7) = "/_utils"` → dispatch to `AdminUIHandler`. Needed because UrlMap `:param` is single-segment and SPA deep links are multi-segment. |
| 4 | Per-DB RBAC | on deny `pContinue=0` + `Error.Render(401\|403)` |
| 5 | Metrics start | `%IRISCouchRequestStart`, `%IRISCouchEndpoint` |

Two `%CSP.REST` overrides complete it: `ReportHttpStatusCode` (turns framework 404/405 into the JSON envelope instead of the IRIS HTML error page) and `Http405` (adds an `Allow` header).

## 2. Error / response envelope — copy nearly as-is

`Util/Response.cls` (33) — the whole success surface:
```objectscript
ClassMethod JSON(pData) As %Status
{
    Set %response.ContentType = "application/json"
    If $IsObject(pData) { Write pData.%ToJSON() } Else { Write pData }
    Quit $$$OK
}
ClassMethod JSONStatus(pStatus As %Integer, pData) As %Status
{
    Set %response.Status = pStatus
    Quit ..JSON(pData)
}
```
Rule asserted in the class doc: **handlers must NEVER `Write` JSON directly.**

`Util/Error.cls` (224) — flat two-field envelope `{"error":"&lt;slug&gt;","reason":"&lt;text&gt;"}`, 14 slug `Parameter`s, `GetSlugForStatus(code)`, plus `Render405(allowed)`, `Render501`, `RenderValidateError`.

**`RenderInternal(pSlug, pReason, pException)` is the leak-prevention seam:** full detail to `%SYS.System.WriteToConsoleLog` + `Util.Log.Error`; client gets only a generic reason at 500.

**The "no double envelope" bug class — carry the rule.** An argumentless `Quit` inside a **nested** `Catch` exits the Catch but *resumes the enclosing Try*, where a variable is now undefined → `<UNDEFINED>` → outer Catch → a **second** envelope written after the first, producing `{"error":"bad_request",...}{"error":"server_error",...}` on the wire. Fix: inside a nested parse-Catch use **`Return $$$OK`**, never bare `Quit`. Fixed at 7 sites (`DocumentHandler.cls:40,167,247,457`, `AllDocsHandler.cls:191`, `ReplicationHandler.cls:82,169`).

Asserted by `Test/ErrorEnvelopeTest.cls:164`:
```objectscript
Method AssertSingleEnvelope(pBody As %String, pLabel As %String)
{
    Do $$$AssertEquals(pBody [ "}{", 0, pLabel _ ": no }{ concatenation in body")
    ...
}
```
driven by a `RawRequest()` helper returning the **unparsed** body (a `%FromJSON` would mask the bug).

## 3. Static SPA serving — copy `AdminUIHandler.cls` (313)

**Not** a separate CSP web application. One web app (`/iris-couch/`, dispatch class only); the SPA is served from `/iris-couch/_utils/` via the `OnPreDispatch` intercept. The handler reads files off disk itself.

`HandleRequest(pPath)` pipeline: auth (401 + `WWW-Authenticate`) → admin role (403) → empty path → `index.html` → `$ZConvert(pPath,"I","URL")` → reject `$Char(0)` and `..` (400) → `%File.NormalizeFilename` → **post-normalization prefix containment check** (belt and braces with the `..` check) → exists? stream : **deep-link fallback to index.html** → index missing → 404.

**Cache headers** — hash detection is pattern-based, not manifest-based:
```objectscript
If ..IsHashedAsset(pFilename) {
    Do %response.SetHeader("Cache-Control", "public, max-age=31536000, immutable")
} Else {
    Do %response.SetHeader("Cache-Control", "no-cache")
}
```
`IsHashedAsset()` = strip extension, take text after the last `-`, require ≥8 chars all alphanumeric. Matches `main-XXBCC7VQ.js`; `index.html` falls through to `no-cache`.

Streaming via `%Stream.FileBinary` + `LinkToFile`, 32 KB chunks. `GetMimeType()` is a 15-arm chain, default `application/octet-stream`.

## 4. Auth — read for the traps, not the code

`Auth/Session.cls` (218) stateless HMAC-SHA256 cookie · `Auth/JWT.cls` (187) HS256 · `Auth/Basic.cls` (98) · `Auth/Proxy.cls` (72) · `Auth/Security.cls` (312) · `Auth/Users.cls` (332).

**`Auth/Basic.cls` does the right thing and OcuPilot must copy it:** it does **not** call `$System.Security.Login` (which would switch the process security context). Instead `Security.Users.Exists` + `Security.Users.CheckPassword`, with explicit `$NAMESPACE` save/restore (never `New $NAMESPACE`).

**Weaknesses — do not carry forward:**

| Weakness | Evidence |
|---|---|
| No `SameSite` on the session cookie | `AuthHandler.cls:58`, `:129` |
| No `Secure` flag | same lines |
| **No CSRF protection anywhere** | zero CSRF/XSRF logic in `src/` or `ui/src/`; with no `SameSite`, a cross-site POST carries the session |
| No CORS handling | `HandleCorsRequest` never set, `ProcessCorsRequest` never overridden; docs tell adopters to work around it |
| **Anonymous `%All` hole** (fixed, instructive) | `%Service_CSP.DEFAULT_USER` ships `UnknownUser` with `%All`, so a `$Roles`-only check let anonymous browsers in. Fix: consult `%IRISCouchUser` first and reject `UnknownUser`/`_PUBLIC`. **This will bite OcuPilot identically.** |
| Auth failures swallowed | `OnPreDispatch` wraps the auth chain in Try/Catch with "remain anonymous — don't block" |

## 5. Installer — copy the idempotency, fix the gaps

`src/IRISCouch/Installer.cls` (211) · `module.xml` (13 lines).

**The manifest is a gap, not a pattern.** `module.xml` has only `<Name>`, `<Version>`, `<Description>`, `<Packaging>`, `<SourcesRoot>src</SourcesRoot>`, `<Resource Name="IRISCouch.PKG"/>`. **No `<Invoke>`, no `<CSPApplication>`, no `<FileCopy>`, no UI-dist resource** — so a ZPM install only compiles classes and never creates the web app.

| Artifact | Created? |
|---|---|
| CSP web application | ✅ `Security.Applications.Create` (`Install()`:89) |
| Role `IRISCouch_Admin` | ✅ `Security.Roles.Create` |
| Role grants to `$Username` and `_SYSTEM` | ✅ |
| Audit events | ✅ delegates to `Audit.Emit.EnsureEvents()` |
| **Dedicated database** | ❌ operator must pre-create |
| **Dedicated resource (`%DB_*`)** | ❌ none |
| Global/package/routine mappings | ❌ none |

**Idempotency rests on three things** — copy all three:
1. `If Security.Applications.Exists(path)` → early-return `$$$OK`, **but still** run `EnsureAdminRole()` + `EnsureEvents()` (the upgrade path).
2. `EnsureAdminRole()`/`GrantAdminRole()` are guard-then-act, wrapped in Try/Catch with "best-effort — do not fail the install".
3. `Uninstall()` returns `$$$OK` when the app doesn't exist.

Namespace hygiene: `Set tOrigNS = $NAMESPACE` … `%SYS` … restore, **including as the first line of every Catch**.

`InstallerTest.cls` asserts idempotency directly (`TestInstallIdempotent` runs `Install` twice and asserts OK both times).

## 6. Audit — copy `Audit/Emit.cls` (339)

```objectscript
ClassMethod Emit(pEventType, pDB, pDocId, pRev, pUser, pExtra As %DynamicObject) As %Status
```
→ `$System.Security.Audit("IRISCouch", pEventType, pEventType, tEventDataStr, tDescription)`. Source is a literal; Type == Name == event type. Whole method wrapped: **audit failure must never propagate**.

`EnsureEvents()` switches to `%SYS` and loops 17 event types with `Security.Events.Exists` / `Create`. **Without pre-registration `$System.Security.Audit` silently returns 0 and drops the event — no error, no log entry.** Called from `Install()` on both the fresh and the upgrade path, always after restoring the namespace.

17 typed wrappers (3–6 lines each) pack extras into `pExtra`. Free-text reasons truncated to 256.

`Util/Log.cls` (101) — 4 levels, all `(pSubsystem, pMessage, pData As %DynamicObject)`, funnelling into `$ZU(9, "", "[IRISCouch] "_json, severity, 1)` → cconsole.log. Also Try/Catch-swallowed.

## 7. Prometheus collector

`Metrics/Collector.cls` (87) — lock-free, `$Increment` on `^IRISCouch.Metrics` only, no `%Persistent`, no LOCK. `Parameter BUCKETS = "0.005,...,10.0"`; `RecordLatency` increments *every* bucket ≥ duration so globals store already-cumulative values.

`Metrics/Record.cls` (113) — **cardinality control**: `ClassifyEndpoint(pUrl)` maps raw URLs to ~10 fixed labels and **never emits a database name or document id**.

`Metrics/Endpoint.cls` (159) — text-format renderer, `text/plain; version=0.0.4`. Every metrics method is Try/Catch; `HandlePrometheus` has a nested Catch writing an empty body rather than erroring.

## 8. Test harness — copy `MakeRequest`

`Test/HttpIntegrationTest.cls` — a **static** helper every other test class calls by name (no HTTP base class):
```objectscript
ClassMethod MakeRequest(pMethod, pPath, Output pStatusCode, Output pBody,
                        pRequestBody = "", pContentType = "", pBinaryBody = "") As %Status
```
Builds `%Net.HttpRequest` from four configurable accessors (`GetTestServer`/`Port`/`Username`/`Password`, each `$Get(^IRISCouchTest(...), ..#PARAM)`), dispatches by verb, then sniffs the first non-whitespace char: `{` or `[` → `%FromJSON`, else return the trimmed raw string (for endpoints returning a bare integer).

Scale: 82 test classes, 613 `Test*` methods, ~850 assertions. Naming convention is paired: `XxxTest.cls` (in-process) + `XxxHttpTest.cls` (over the wire). Each test class owns a distinct name prefix; cleanup in `OnAfterOneTest`.

Rule: every new handler method needs an HTTP integration test verifying (1) status code, (2) `Content-Type`, (3) body structure.

**Escape hatches** where the shared helper can't express the case: `ErrorEnvelopeTest.RawRequest()` (unparsed body), `AdminUIRBACTest.GetUtils(pSendAuth,...)` (send *no* auth, harvest response headers).

## 9. Angular app — one critical gotcha

Angular **18.2**, standalone, `bootstrapApplication`. Build `@angular-devkit/build-angular:application` → `dist/browser/`, `outputHashing: "all"`, budgets 500 kB warn / 1 MB error.

Base href set in **both** `angular.json` (`baseHref`) and `index.html` (`<base href="/iris-couch/_utils/">`).

**The gotcha OcuPilot must not repeat** — `ui/src/app/services/couch-api.service.ts` exists purely to defeat the base href:
> The base href causes relative URLs (e.g. `_session`) to resolve to `/iris-couch/_utils/_session`, which the AdminUIHandler serves as the SPA fallback (index.html) — **not** the REST API, which lives one level up at `/iris-couch/`.

```ts
private static readonly API_BASE = '/iris-couch/';   // absolute → not resolved against <base href>
private resolve(path: string): string {
  if (path.startsWith('http://') || path.startsWith('https://') || path.startsWith('/')) return path;
  return CouchApiService.API_BASE + path;
}
```
**A SPA served under a sub-path of its own API must never use relative URLs.** (Found in acceptance, commit `7ce04bd`.)

**Token storage: there is none.** No localStorage/sessionStorage/in-memory bearer. Auth is entirely the HttpOnly cookie; `AuthService` holds only a `BehaviorSubject` for UI state. *(OcuPilot's design differs — per-tab token storage per NFR-3 — so this part does not transfer.)*

`APP_INITIALIZER` runs `firstValueFrom(auth.checkSession())` so a refresh restores the session before the router activates. Functional `HttpInterceptorFn` maps 401 → clear + redirect, with a self-exclusion so the login call doesn't loop.

Error handling is two pieces worth copying: pure `mapError(err): MappedError` preserving the backend envelope verbatim, `status===0` → `network_error`; and `<app-feature-error [rawError] [statusCode] (retry)>` wrapping the display, extracted after three feature pages duplicated the map→store→render→retry boilerplate.

Routing uses custom `UrlMatcher`s because Angular splits on `/` and would parse `/db/testdb/doc/_design/myapp` as `docid="_design"`.

**Dev proxy is brittle by construction** — `ui/proxy.conf.js` uses a negative-lookahead regex listing every SPA route and static extension; every new top-level route must be added. **Redesign for OcuPilot.**

## 10. Names to rename

Package `IRISCouch` (+ `.API`, `.Auth`, `.Audit`, `.Core`, `.Storage`, `.Query`, `.View`, `.Projection`, `.Replication`, `.JSRuntime`, `.Metrics`, `.Util`, `.Test`) · ZPM module `iris-couch` · Angular project `iris-couch-ui` · web paths `/iris-couch/`, `/iris-couch/_utils/` · cookie `AuthSession` with `Path=/iris-couch` · role `IRISCouch_Admin` · **audit Source `IRISCouch`** with 17 event types · globals `^IRISCouch.*` (18 of them) + `^IRISCouchTest(...)` · process-private vars `%IRISCouchUser`/`Roles`/`AuthMethod`/`RequestStart`/`Endpoint` · metric names `iriscouch_*` · log prefix `[IRISCouch] ` · proxy headers `X-Auth-CouchDB-*`.

**`%Persistent` hashed-global trap:** `^IRISCouch.Proje4479.MangoIndexD` — a compiler-generated hashed global name pinned in the class's `<Storage>` XData. Watch for it if any OcuPilot `%Persistent` class name is long.

## Verdict

**Copy nearly as-is:** `Util/Response.cls`, `Util/Error.cls`, `Util/Log.cls`, `Audit/Emit.cls`, `Metrics/{Collector,Record,Endpoint}.cls`, the Router thin-wrapper + `OnPreDispatch` structure, `AdminUIHandler.cls`, the `MakeRequest` test harness, `error-mapping.ts` + `feature-error.component.ts`, and `couch-api.service.ts`'s absolute-base-path discipline.

**Fix while porting:** cookie `SameSite`+`Secure`; CSRF; explicit CORS decision; `module.xml` needs `<Invoke>` + `<FileCopy>`/`<WebApplication>` so ZPM install is complete; `Installer` should create a dedicated database + resource rather than assume the operator did; replace the proxy-config route-exclusion regex.
