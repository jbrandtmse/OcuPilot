---
review: currency-and-reality-check
target: ARCHITECTURE-SPINE.md
date: 2026-09-09
lens: "Was every committed decision web-researched or reality-checked, or asserted from training data?"
verdict: "Mostly sound — but two load-bearing claims are provably wrong and one is a silent contract risk."
---

# Currency Review — Architecture Spine, OcuPilot

**Single lens:** every committed decision must trace to the live web, the running IRIS instance, or a
sibling codebase. Anything asserted from recollection is a target.

**Method.** Every Stack-table row was checked against a primary source (angular.dev, the Angular
v22.0.0 release notes, the npm registry, docs.intersystems.com, Docker Hub). Every IRIS claim was
re-probed on the running `ocupilot` container (`server: "ocupilot-iris"`, IRIS for Health 2026.2
Build 221U). The run's `.memlog.md` was read first and its recorded probes are treated as verified;
findings below are almost entirely about claims that appear in the spine but **not** in the memlog.

**Headline.** The memlog is unusually disciplined — 19 of ~22 substantive claims trace to a live
probe or a dated web search. The failures are concentrated in three places: (1) a TypeScript version
carried over from Angular 21, (2) two quantitative claims about the vendor endpoint classes that were
generalized from a single-class probe and are false at population scale, and (3) an entire dependency
on undocumented vendor internals that carries no risk note anywhere in the document.

---

## 1. Stack table — row by row

The table is headed **"Verified current 2026-09-09."** That header is the strongest claim in the
document and it is not fully earned.

| # | Claim as written | Verdict | Evidence |
| --- | --- | --- | --- |
| 1 | InterSystems IRIS for Health Community **2026.2 (build 221U)** | **CONFIRMED** | `iris_server_info` on `ocupilot-iris` returns `IRIS for UNIX (Ubuntu Server LTS for ARM64 Containers) 2026.2 (Build 221U) Fri Jun 26 2026`. 2026.2 is GA as a CD release — [docs.intersystems.com PAGE_release](https://docs.intersystems.com/irislatest/csp/docbook/DocBook.UI.Page.cls?KEY=PAGE_release), [GA announcement](https://community.intersystems.com/post/intersystems-announces-general-availability-intersystems-iris-intersystems-iris-health-and-1) |
| 2 | Angular **22.1.x**; v22.0.0 released **2026-06-03**; zoneless default since v21 | **CONFIRMED** | `@angular/core` `latest` dist-tag = **22.1.5** ([registry.npmjs.org/@angular/core](https://registry.npmjs.org/@angular/core)). Release date 2026-06-03 ([Ninja Squad](https://blog.ninja-squad.com/2026/06/03/what-is-new-angular-22.0), [angular.dev/events/v22](https://angular.dev/events/v22)). Zoneless default since v21 ([push-based.io](https://push-based.io/article/angular-v21-goes-zoneless-by-default-what-changes-why-its-faster-and-how-to)) |
| 3 | Angular Material + CDK **22.x** | **CONFIRMED** | `@angular/material` latest = 22.1.5 ([npmjs.com/package/@angular/material](https://www.npmjs.com/package/@angular/material?activeTab=versions)) |
| 4 | TypeScript **5.9.x (as pinned by Angular 22)** | **WRONG — CORRECTED** | Angular **22.x pins TypeScript `">=6.0.0 <6.1.0"`**. `>=5.9.0 <6.0.0` is **Angular 21's** row. [angular.dev/reference/versions](https://angular.dev/reference/versions); v22.0.0 release notes: *"TypeScript versions older than 6.0 are no longer supported"* ([github.com/angular/angular/releases/tag/v22.0.0](https://github.com/angular/angular/releases/tag/v22.0.0)) |
| 5 | ObjectScript — IRIS 2026.2 dialect | **CONFIRMED** (follows from row 1) | — |
| 6 | IPM **0.10.x** — distribution channel only | **CONFIRMED** | Current line is 0.10.x; **0.10.9** released 2026-08-05 ([IPM 0.10.9 release notes](https://community.intersystems.com/post/ipm-version-0-10-9-release-notes)) |
| 7 | Admin API **`/api/admin` v2, pinned** | **CONFIRMED** | `%Api.Admin` `UrlMap` forwards `/v1` → `%Api.Admin.Dispatch.v1` and `/v2` → `%Api.Admin.Dispatch.v2`; `Info()` computes `apiVersion` as the max `Dispatch.vN` = **2**. `Dispatch.v2 Extends Dispatch.v1`, so the memlog's `Main()` proof against v1 carries to v2 by inheritance |
| 8 | Monitoring API `/api/monitor` | **CONFIRMED** | `iris_webapp_list` %SYS: `/api/monitor` → `%Api.Monitor`, enabled |
| 9 | Management API `/api/mgmnt` v2 | **CONFIRMED** | `iris_webapp_list` %SYS: `/api/mgmnt` → `%Api.Mgmnt.v2.disp`, enabled |
| 10 | Docker image `intersystems/irishealth-community:latest-cd` | **CONFIRMED, with a caveat** | Local image inspect: `org.opencontainers.image.version = 2026.2.0.221.0-0-linux-arm64v8`, created `2026-06-26`, arch `arm64`, digest `sha256:462de1fb…`. Tag scheme confirmed at [Upcoming InterSystems Container Changes](https://community.intersystems.com/post/upcoming-intersystems-container-changes). Caveat in §4.4 |

### Missing from the Stack table

| Missing | Why it matters | Correct value |
| --- | --- | --- |
| **Node.js** | Angular 22 has a *narrow* floor and the project is greenfield with no `package.json`. A wrong Node is a first-hour build failure and an install prerequisite (FR-64…FR-69, NFR-13). | `^22.22.3 \|\| ^24.15.0 \|\| ^26.0.0` — [angular.dev/reference/versions](https://angular.dev/reference/versions). *(Local dev box runs Node v26.8.1 / npm 11.19.0 — compliant.)* |
| **Build system** | v22 **deprecates** `@angular-devkit/build-angular` / `@ngtools/webpack`; the esbuild/Vite `application` builder is the live default. A spine that names no builder invites someone to scaffold onto the deprecated one. | Use the default `@angular/build` `application` builder. [v22 release notes](https://github.com/angular/angular/releases/tag/v22.0.0) |
| **RxJS** | Named nowhere despite `ui/src/app/core/` implying an HTTP layer. | `^6.5.3 \|\| ^7.4.0` |

---

## 2. Greenfield check — what an `ng new` scaffold actually gives you

`src/` contains **0 files** and there is no `ui/`, no `package.json`, no `Dockerfile`. The project is
genuinely greenfield, so the starter's live defaults are load-bearing for AD-19.

**AD-19 as written:** *"Angular standalone components, zoneless change detection, `OnPush` everywhere."*

| Scaffold property | Spine's assumption | Live reality | Verdict |
| --- | --- | --- | --- |
| Zoneless by default | Yes ("zoneless default since v21") | Confirmed. `ng new` since v21 emits no `zone.js`; v22 carries it forward | **CONFIRMED** |
| Standalone components | Implied default | Confirmed — standalone has been the `ng new` default since v19 | **CONFIRMED** |
| `OnPush` for new components | "`OnPush` everywhere" — reads as a *project convention to enforce* | Confirmed, but **stronger than the spine knows**: as of v22 it is the **framework default**. *"Components without an explicitly set `changeDetection` property now default to `OnPush`"* — [v22.0.0 release notes](https://github.com/angular/angular/releases/tag/v22.0.0). `ng generate` emits OnPush with no configuration | **CONFIRMED — and AD-19 can be simplified** |
| `ChangeDetectionStrategy.Default` | Not mentioned | **Deprecated and renamed `Eager` in v21.2.** Opting *out* of OnPush is now `changeDetection: ChangeDetectionStrategy.Eager` | **GAP** — [lacolaco](https://blog.lacolaco.net/posts/angular-v22-onpush-by-default.en), [RFC #66779](https://github.com/angular/angular/discussions/66779) |
| HTTP backend | Not mentioned | **v22 changed the default `HttpClient` backend from XHR to Fetch.** Upload-progress reporting now requires `provideHttpClient(withXhr)`. Relevant if any screen ever uploads (X.509 import, wallet secrets, FR-44) | **GAP** — v22.0.0 release notes |

**Net:** the greenfield assumptions in AD-19 are correct and, on OnPush, now understated. The two
gaps are cheap one-line additions, not rework.

---

## 3. IRIS-specific claims

### 3.1 `%Api.Admin` versioning — CONFIRMED

Probed directly. `%Api.Admin` is the dispatch class for `/api/admin`; its `UrlMap` maps `/v1` and
`/v2`; `Info()` derives `apiVersion` from the `UrlMap` itself and returns 2. Pinning v2 (NFR-8) is
correct and the memlog's v1 proof survives because `Dispatch.v2 Extends Dispatch.v1`.

### 3.2 `intersystems/irishealth-community:latest-cd` — CONFIRMED as real

Not merely plausible: the tag is what `docker-compose.yml` pulls and what is running. Image labels
confirm `2026.2.0.221.0-0-linux-arm64v8`.

### 3.3 IRIS 2026.2 — CONFIRMED as a real, GA, CD release

Not a hallucinated future version. GA announced; docs published under `irislatest`.

### 3.4 **Support stance on undocumented `%Api` classes — UNADDRESSED. This is the largest gap.**

AD-2 makes the whole architecture depend on instantiating `%Api.Admin.Endpoints.<X>` in-process and
replaying the vendor's private dispatch sequence. Verified on the instance: **every one of these
classes is declared `[ Hidden ]`** — `%Api.Admin`, `%Api.Admin.Dispatch.v1`, `%Api.Admin.Dispatch.v2`,
`%Api.Admin.Endpoint`, and all 70 `%Api.Admin.Endpoints.*`.

Per InterSystems' own keyword reference, `Hidden` means *"the class … is not listed in the class
reference, nor in the ObjectScript Explorer pane"* —
[ROBJ_class_hidden](https://docs.intersystems.com/irislatest/csp/docbook/DocBook.UI.Page.cls?KEY=ROBJ_class_hidden).
`/api/admin` is correspondingly absent from the documented built-in web applications table, and the
project's own `.claude/rules/reference-folders.md` already says: *"treat it as undocumented/internal."*
The general InterSystems position is that undocumented internals carry no behavioral contract and may
change without notice.

The spine states none of this. There is no NFR, no Deferred row, and no risk note acknowledging that
`AD-2` — the decision that "prevents reimplementing 70 vendor endpoints" — is built on an unsupported
surface. **This is compounded by row 10**: `latest-cd` is a *floating* tag on a *continuous delivery*
stream, so the very next `docker compose pull` can move the instance to 2026.3 and silently change
the private methods (`ValidateRequest`, `ValidateSemantics`, `Run`, `SaveOneQueryParam`,
`RequestBodySchema`, `IsRunningAsync`) that AD-2 and AD-3 replay.

The Stack table says **"2026.2 (build 221U) — floor for the project, the only version tested"** while
the same table pins a tag that does not honor that floor. Those two rows contradict each other.

---

## 4. Findings — claims asserted in the spine, absent from the memlog, and not web-checked

### 4.1 `[HIGH]` — TypeScript 5.9.x is Angular 21's pin, not Angular 22's

**Claim (Stack):** *"TypeScript | 5.9.x (as pinned by Angular 22)"*
**Verdict:** **WRONG.** Angular 22.x requires `>=6.0.0 <6.1.0`. TypeScript 5.9 will not build an
Angular 22 project — the v22 release notes list it as a breaking change.
**Where it came from:** almost certainly recall of Angular 21's compatibility row. The memlog's
`(version)` entry — otherwise the most carefully dated line in the file — never mentions TypeScript,
so the spine added an unchecked number to a verified row and inherited its "Verified current" header.
**Source:** [angular.dev/reference/versions](https://angular.dev/reference/versions) ·
[v22.0.0 release notes](https://github.com/angular/angular/releases/tag/v22.0.0)
**Fix:** `TypeScript | 6.0.x (Angular 22 pins ">=6.0.0 <6.1.0")`. Note also that TypeScript **7.x is
released but not usable** with Angular 22 — `@angular/compiler-cli` fails on `readConfiguration` /
`DiagnosticCategory` ([angular#69704](https://github.com/angular/angular/issues/69704)) — so pin 6.0.x
explicitly rather than using a caret range.

### 4.2 `[HIGH]` — "Only 4 of 70 endpoint classes override `ShouldRunAsync`; none is on a Release 1 path"

**Claim (Deferred, "Async admin API endpoints").**
**Verdict:** **WRONG on both counts.** Probed on the instance.

**It is 7, not 4.** Classes that define their own `ShouldRunAsync` (base `%Api.Admin.Endpoint` returns
`0`):

`Database.Actions` · `Database.SysCRUD` · `ECP.DataServer` · `Journal.File` · `Namespace.Namespace` ·
`Security.Audit.Record` · `Security.LDAP`

**And at least three sit squarely on Release 1 paths.** The bodies, read from the instance:

```objectscript
// %Api.Admin.Endpoints.Security.LDAP
Method ShouldRunAsync() As %Boolean { Return ..Type = ..#TYPETEST }

// %Api.Admin.Endpoints.Security.Audit.Record
Method ShouldRunAsync() As %Boolean {
    /// The list endpoint also runs async, but it does its own logic
    /// to queue up a special async task
    Return (..Type = ..#TYPECOPY) || (..Type = ..#TYPEPURGE)
}

// %Api.Admin.Endpoints.Namespace.Namespace
Method ShouldRunAsync() As %Boolean { Return (..Type = ..#TYPEINTEROP) || (..Type = ..#TYPEMAPPINGS) }
```

Mapping to the binding scope (FR-1…FR-79, all of Release 1):

| Endpoint | Async when | Release 1 row |
| --- | --- | --- |
| `Security.Audit.Record` | `COPY`, `PURGE` — **and the vendor's own comment says the *list* path queues a special async task** | **SS-14 / LG-02 "View audit database" is P0** (FR-46); copy/purge is FR-76 |
| `Security.LDAP` | `TYPETEST` (test authentication) | **FR-75**, polish week — inside Release 1 |
| `Namespace.Namespace` | interop / mappings | **SH-03 namespace switch is P0**; the async branch is the interop/mapping sub-path |

The audit one is the sharp edge: the audit database viewer is a **P0** screen, and the endpoint's own
source says its list path queues an async task. The PRD addendum already knew this — *"FR-76 carries
the catalog's caveat about the admin API's asynchronous tasks"* — and the spine's Deferred row
silently overrides that caveat with an unverified count.
**Fix:** correct to 7; drop "none is on a Release 1 path"; move `%Api.Admin.Util.AsyncTaskEndpoint`
+ result polling out of Deferred and into the Release 1 AdminPort scope, at minimum for
`Security.Audit.Record`. (`%Api.Admin.Util.AsyncTask`, `.AsyncTaskEndpoint`,
`.AsyncTaskEndpointQueryParameters`, `.AsyncTaskList`, `.AsyncTaskListResultRows` all exist on the
instance — the spine's naming of `AsyncTaskEndpoint` is **CONFIRMED**.)

### 4.3 `[HIGH]` — "All 70 endpoint classes are free of `%request` / `%response` references"

**Claim (AD-2):** *"All 70 endpoint classes are free of `%request` / `%response` references, so
nothing else is required to decouple them."*
**Verdict:** **WRONG.** Scanned all 70 class sources on the instance: **5 reference `%request` or
`%response`.**

| Class | Reference | Consequence in-process |
| --- | --- | --- |
| `Security.Encryption.Settings` | `%request.GetCgiEnv("HTTP_ADMINNAME")` / `("HTTP_ADMINPASSWORD")` at L52–53 | **Hard dependency.** Guarded by `If ..ApiVersion = 1` — v2 reads `AdminName`/`AdminPassword` from the body instead. Safe *only because* NFR-8 pins v2. The spine never connects the two, so "pin v2" currently reads as a versioning preference rather than a correctness requirement |
| `Database.Actions` (×3), `Journal.Record`, `Security.Audit.Record` | `Set task.TaskName = ..GetName(%request)` | On the async-task naming path — i.e. exactly the path 4.2 says does not exist in Release 1 |
| `Database.AsyncTaskSysBackground` (×6) | `Set %response.Status = ##class(%CSP.REST).#HTTP409CONFLICT` | Writes to `%response` directly |

The memlog is precise here and the spine is not. The memlog says the endpoint *"sets `IsRunningAsync=1`
to neutralize every `%response`/`%request` touch"* and was *"verified by instantiating
`%Api.Admin.Endpoints.WebApp.App`"* — **one class**. The spine generalized a single-class probe into a
population claim about 70, then drew the conclusion *"nothing else is required."*
**Fix:** replace with the accurate version — 5 classes touch `%request`/`%response`; `IsRunningAsync = 1`
neutralizes them on the async path; `Security.Encryption.Settings` is safe **only** on `ApiVersion ≥ 2`,
which makes NFR-8's v2 pin a correctness constraint, not a preference. Add an AdminPort test that
asserts `ApiVersion` is 2 before any endpoint is constructed.

### 4.4 `[MEDIUM]` — The Stack table pins a floor and a floating tag in the same breath

**Claim (Stack rows 1 and 10):** *"2026.2 (build 221U) — floor for the project, the only version
tested"* alongside *"image `intersystems/irishealth-community:latest-cd`."*
**Verdict:** **INTERNALLY INCONSISTENT.** `latest-cd` tracks the newest continuous-delivery release;
per [Upcoming InterSystems Container Changes](https://community.intersystems.com/post/upcoming-intersystems-container-changes)
that tag exists precisely to float. Next CD release, `docker compose pull` moves the "only version
tested" out from under the project. This matters more than usual here because AD-2 and AD-3 replay
**undocumented, `[ Hidden ]`** vendor internals (§3.4) that carry no stability contract, and because
FR-67 explicitly has to survive "up with a newer image."
**Fix:** pin `2026.2` (or the digest `sha256:462de1fb3597…`) in `docker-compose.yml` and say in the
Stack table that `latest-cd` is the *upgrade-test* target, not the pinned one. Add an AdminPort
smoke test that fails loudly if the private call sequence changes.

### 4.5 `[MEDIUM]` — No risk is recorded for depending on undocumented vendor internals

See §3.4. AD-2 and AD-3 are the two highest-leverage decisions in the document and both rest on
`[ Hidden ]` classes with no published contract. AD-18 gets a `[ADOPTED]` tag and an explicit
"Verified:" sentence; AD-2's far larger exposure gets neither a caveat nor a fallback.
**Fix:** add a Deferred/risk row: *"AD-2 depends on `[ Hidden ]`, undocumented `%Api.Admin.Endpoints.*`
internals. Mitigation: pinned image (4.4), a contract test per endpoint shape, and a documented
fallback to HTTP `/api/admin/v2` if a CD release breaks the in-process sequence."* Note that the
fallback is cheap to keep open — it is the same endpoint objects behind an HTTP envelope — but only
if AD-1's "no tool issues an HTTP request to `/api/admin`" is written as a default rather than an
absolute.

### 4.6 `[LOW]` — Angular scaffold details the spine should state, now that it is greenfield

Consolidating §2: add Node `^22.22.3 || ^24.15.0 || ^26.0.0`; name the `@angular/build` `application`
builder (webpack builders are deprecated in v22); note that opting out of OnPush is now
`ChangeDetectionStrategy.Eager`, not `.Default`; note the XHR→Fetch `HttpClient` default change if any
screen uploads.

### 4.7 `[LOW]` — Stale patch number in the memlog

Memlog records *"Angular Material + CDK v22 (22.0.4)"*; npm now shows **22.1.5**. The spine's `22.x`
is unaffected. Noted only so the memlog is not later mined for an exact pin.

### 4.8 `[INFO]` — Claims re-checked and left standing

These appear in the spine, trace to the memlog, and were spot-verified on the instance this pass:
70 `%Api.Admin.Endpoints.*` classes (**exactly 70** — confirmed by `COUNT(*)` on
`%Dictionary.CompiledClass`); `%Api.Admin.Util.AsyncTaskEndpoint` exists; `/api/monitor` and
`/api/mgmnt v2` are enabled web applications; IRIS 2026.2 build 221U; the durable-volume database
layout behind AD-17; `New $ROLES` containment behind AD-9; get-merge-put PUT semantics behind AD-4;
`RequestBodySchema()` behind AD-3; the 738-call-site `RenderResponseBody` seam behind AD-23. No
correction needed on any of them.

---

## 5. Recommended edits, in priority order

1. **Stack:** `TypeScript | 6.0.x` — pin exactly, note TS 7 is blocked by `@angular/compiler-cli`.
2. **Deferred / async endpoints:** 4 → **7**; delete "none is on a Release 1 path"; pull
   `AsyncTaskEndpoint` + polling into Release 1 for `Security.Audit.Record` (P0 audit viewer).
3. **AD-2:** replace the "all 70 are free of `%request`/`%response`" sentence with the measured
   result (5 classes), and state that NFR-8's v2 pin is what makes
   `Security.Encryption.Settings` safe in-process.
4. **Stack + `docker-compose.yml`:** pin `2026.2` or the digest; demote `latest-cd` to the
   upgrade-test target.
5. **New risk row:** AD-2/AD-3 depend on `[ Hidden ]` undocumented vendor internals — mitigation and
   fallback.
6. **Stack:** add Node, the `@angular/build` builder, and RxJS.
7. **AD-19:** note OnPush is now the framework default (v22) and that the opt-out is `Eager`.

## 6. Sources

- [angular.dev — Version compatibility](https://angular.dev/reference/versions)
- [Angular v22.0.0 release notes](https://github.com/angular/angular/releases/tag/v22.0.0)
- [Angular v22 event page](https://angular.dev/events/v22) · [Ninja Squad — What's new in Angular 22.0](https://blog.ninja-squad.com/2026/06/03/what-is-new-angular-22.0)
- [RFC #66779 — OnPush as the default CD strategy](https://github.com/angular/angular/discussions/66779) · [lacolaco — Eager and OnPush by default](https://blog.lacolaco.net/posts/angular-v22-onpush-by-default.en)
- [angular#69704 — TypeScript 7.x peer range request](https://github.com/angular/angular/issues/69704)
- [npm registry — @angular/core](https://registry.npmjs.org/@angular/core) · [npm — @angular/material versions](https://www.npmjs.com/package/@angular/material?activeTab=versions)
- [Angular v21 goes zoneless by default](https://push-based.io/article/angular-v21-goes-zoneless-by-default-what-changes-why-its-faster-and-how-to)
- [InterSystems IRIS 2026.2 release page](https://docs.intersystems.com/irislatest/csp/docbook/DocBook.UI.Page.cls?KEY=PAGE_release) · [2026.2 GA announcement](https://community.intersystems.com/post/intersystems-announces-general-availability-intersystems-iris-intersystems-iris-health-and-1)
- [IPM 0.10.9 release notes](https://community.intersystems.com/post/ipm-version-0-10-9-release-notes)
- [Upcoming InterSystems Container Changes](https://community.intersystems.com/post/upcoming-intersystems-container-changes) · [intersystems/irishealth-community on Docker Hub](https://hub.docker.com/r/intersystems/irishealth-community)
- [Hidden (Class Keyword)](https://docs.intersystems.com/irislatest/csp/docbook/DocBook.UI.Page.cls?KEY=ROBJ_class_hidden)
- Live probes: `ocupilot-iris` (IRIS for Health 2026.2 Build 221U) via `iris_server_info`,
  `iris_webapp_list`, `iris_sql_execute` over `%Dictionary.CompiledClass` / `.CompiledMethod`, and
  `%Compiler.UDL.TextServices.GetTextAsString` over all 70 `%Api.Admin.Endpoints.*` sources.
