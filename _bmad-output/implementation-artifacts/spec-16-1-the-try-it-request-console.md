---
title: 'Story 16.1: The try-it request console'
type: 'feature'
created: '2026-09-26'
status: 'done'
baseline_revision: 'efd43df6b9c20eb7ff9666cba1696fe3fd80c744'
baseline_commit: 'efd43df6b9c20eb7ff9666cba1696fe3fd80c744'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-16-context.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** The OpenAPI document viewer (Story 6.1) shows a REST application's operations, but a developer who wants to know whether one works has to leave OcuPilot for curl or a second tool.

**Approach:** Each operation in the viewer gains a try-it console: the person fills the operation's declared parameters (and a body for a verb that takes one), sends it from the browser to the same origin with the current session, and reads the status, headers and body back on the code surface as text. The console's record of the request masks every secret.

## Boundaries & Constraints

**Always:**

- The request is composed only from the document: the listed web application's path, the operation's path and verb, and its declared parameters. A path parameter fills exactly one segment (`encodeURIComponent`); a value of `.` or `..` is refused. The URL is absolute on `location.origin`, and one whose resolved origin differs is never sent.
- "The current session" is the tab's own access token as `Authorization: Bearer`, with `credentials: 'omit'` (no cookie, so no silent `/login` mint and no `/logout` side effect) and `redirect: 'manual'`. The refresh token is never sent (AD-57 (1)).
- A verb other than GET, HEAD or OPTIONS is sent only after a confirmation dialog restating the verb and the full URL.
- The console refuses, without sending, (i) any request whose target resolves under one of OcuPilot's own applications (`/ocupilot`, `/api/ocupilot`, `/api/ocupilot/readiness`), whatever the verb, and (ii) any `POST`, `PUT`, `PATCH` or `DELETE` whose target resolves under `/api/admin` (AD-57 (2)). The target is resolved **the way the browser will resolve it** before it is compared: the final URL is built through `new URL(...)` on `location.origin` (dot segments removed), then percent-decoded (so `%2e`, `%6F` and the like cannot hide a segment), repeated slashes collapsed, a trailing slash normalized, and case folded (IRIS matches applications case-insensitively, AD-13's web-application rule); the prefix match is on whole segments (`/api/ocupilotx` is not under `/api/ocupilot`). One function does the resolution and both refusals, and every refusal is pinned by a test that reddens when it is removed.
- The response renders as text on `--ocu-code-surface` in a `pre`: JSON is pretty-printed through `JSON.parse`/`JSON.stringify` only, anything else is shown as decoded text up to a 256 KB cap with the cut marked, and a non-text content type shows its byte count, never an `img`, frame or link (AD-11 rule 4). Nothing is bound as markup.
- The record (the request line, headers and body shown beside the response) holds only masked values once sent: the `Authorization` value reads masked, and any query, header or top-level JSON body member whose name matches the Conventions › Secrets credential pattern reads masked. The unmasked value lives only in the form field until send.
- The console state never enters screen context, a tool result, the ledger or a log line; the viewer's context fields are unchanged (AD-24, AD-36).

**Never:**

- No agent tool, no tool-registry entry, no governance wiring (`Kernel/Governance/Gate.cls` untouched), no new REST route, port or server class. No server code issues the request (AD-1).
- The request never goes through `ApiService` (its refresh-retry and envelope parsing are `/api/ocupilot` semantics), and never sends a cookie.
- A spec-based service listed by package name only (no web application) has no URL: its operations show no console, with the published reason.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| JWT app, GET | `/api/admin` document, `GET /v2/web-apps` | Sent with Bearer; status 200, headers, pretty JSON body | none |
| Non-JWT password app | `/api/mgmnt`, `GET /v2/` | Sent; status 401 and its body shown as the round trip's honest answer (measured) | none |
| Mutating verb | any `DELETE`/`POST`/`PUT`/`PATCH` | Confirmation dialog first; Cancel sends nothing | Confirm sends once |
| OcuPilot's own app | `/api/ocupilot` document, or a composed URL resolving under it | Not sent; refusal line in place of Send | none |
| Own app by another spelling | `/API/OcuPilot/x`, `/api/%6Fcupilot/x`, `/api/admin/../ocupilot/x`, `//api//ocupilot/x`, `/ocupilot` | Not sent; same refusal (resolved as the browser resolves it) | none |
| Admin API write | any `POST`/`PUT`/`PATCH`/`DELETE` resolving under `/api/admin` (any spelling above) | Not sent; the admin-write refusal names where the change is made instead | none |
| Admin API read | `GET` under `/api/admin` | Sent (row 1) | none |
| Traversal | path parameter `..` | Not sent; field-level refusal | none |
| Secret in request | query `apiKey=x`, header `X-Token`, body `{"Password":"p"}` | Record shows each value masked; Authorization masked | none |
| Network failure | fetch rejects | Console states the request did not complete; no status invented | none |
| Package-only service | application named by package | No console; reason shown | none |

</intent-contract>

## Code Map

- `ui/src/app/areas/web-applications/openapi-viewer.page.ts` -- the viewer; each operation `section` gains the console. `OperationView` resolves per operation; conditions stay paren-free (client-lint).
- `ui/src/app/areas/web-applications/openapi-viewer.store.ts` -- `OpenApiParameter {name,in,required,type}`; `document()` holds the vendor document, whose `basePath` is the application path (measured: `/api/admin`). Rows carry no app path, so the console takes `basePath`, falling back to the route's application id when it starts with `/`.
- `src/OcuPilot/Port/MgmntPort.cls:291` `Document` -- a name starting with `/` is a listed web application; a package name is a service with no web application.
- `ui/src/app/core/token-store.ts:184` `accessToken()` -- the one source of the Bearer value.
- `ui/tools/credential-pattern.mjs` -- `CREDENTIAL_SUFFIXES` plus the exact names; build-time only, so masking needs a runtime copy pinned equal by a test.
- `ui/src/app/shell/dialog.ts`, `warning-dialog.ts` -- the confirmation dialog to reuse.
- `ui/src/styles/_components.scss:3890-3910,4106` -- the code-surface pair; new rules append at the file's end (Epic 23 edits near line 4431).
- `ui/src/app/core/strings.ts:623-643` -- `openApi*` keys; new keys append with their `/** EXPERIENCE.md:n */` citations.
- `ui/browser/rest-apis.browser-spec.mjs` -- the explorer's browser spec; the console gets its own file.
- `src/OcuPilot/Api/StaticHandler.cls:350` -- CSP `connect-src 'self'` already permits a same-origin fetch; unchanged.

## Tasks & Acceptance

**Execution:**

- `ui/src/app/core/secret-names.ts` -- new: the credential pattern as a runtime `isSecretName(name)`, and the existing `ui/tools/credential-lists.test.mjs` pins it equal to `credential-pattern.mjs` -- masking needs the one list at runtime.
- `ui/src/app/areas/web-applications/try-it.ts` -- new framework-free module: `composeRequest(basePath, operation, values)` (segment encoding, `.`/`..` refusal, origin check), `resolveTarget(url)` (browser-equivalent resolution: `new URL`, percent-decode, slash collapse, trailing slash, case fold) and `refusal(verb, target)` (OcuPilot's own applications for any verb; `/api/admin` for `POST`/`PUT`/`PATCH`/`DELETE`, AD-57 (2)), `isSafeVerb`, `maskedRecord(request)`, `renderBody(contentType, bytes)` -- the rules above in one testable place.
- `ui/src/app/areas/web-applications/try-it.store.ts` -- new store (AD-19), provided by the page: per-operation field values, in-flight flag, the masked record and the rendered response; sends through an injected `fetch` with the Bearer from `TokenStore`.
- `ui/src/app/areas/web-applications/openapi-viewer.page.ts` -- a "Try it" disclosure per operation: one labeled input per declared parameter, a body `textarea` when the verb takes one, Send (confirmation for a non-safe verb), then the record and response on the code surface.
- `ui/src/app/core/strings.ts` + EXPERIENCE.md -- new copy appended at the end of the Fixed strings table (line count otherwise unchanged): "Try it", "Send", "Request", "Response", "Body", "Send <VERB> <URL>?", the own-application refusal, the admin-write refusal (naming that OcuPilot's own screens make those changes), the traversal refusal, the package-only reason, "The request did not complete.", the cut notice.
- `ui/src/styles/_components.scss` -- append console rules (tokens only; no control under its declared minimum; no page-level horizontal scroll -- the response `pre` scrolls inside itself).
- `ui/tools/try-it.test.mjs` -- node test over `try-it.ts`: every matrix row's composition, refusal and masking, including every spelling in the "another spelling" row against each of the three own applications and `/api/admin`; each refusal arm (own applications; admin write) has a case that reddens alone when that arm is removed.
- `ui/src/app/areas/web-applications/openapi-try-it.page.spec.ts` -- new component spec (leave `openapi-viewer.page.spec.ts`, contended with Epic 23, untouched).
- `ui/browser/openapi-try-it.browser-spec.mjs` -- new: against `ocupilot-ci`, open `/api/admin`'s document, send `GET /v2/web-apps`, assert status 200 and body text; `/api/mgmnt` `GET` answers 401; a `DELETE` on a non-admin application shows the dialog and Cancel sends nothing; a `DELETE` in `/api/admin`'s document offers no Send and shows the admin-write refusal; the `/api/ocupilot` document offers no Send; both themes pass the DW-1337 structural gate with no new allowance.

**Acceptance Criteria:**

- Given an operation in the OpenAPI document viewer of a JWT-enabled application, when the person sends it, then the request carries the tab's access token and the console shows the answer's status and body.
- Given any response, when it renders, then it is text on the code surface; a body containing `<img src=x onerror=...>` renders as those characters and issues no request.
- Given a request whose target resolves, by any spelling, under OcuPilot's own applications, or a `POST`/`PUT`/`PATCH`/`DELETE` resolving under `/api/admin`, when the person tries to send it, then nothing is sent and the console shows the refusal (AD-57 (2)).
- Given a request carrying a secret-named query, header or body member, when it has been sent, then the record shows the value masked and the page's DOM holds the unmasked value nowhere but the input it was typed into.

### Review Findings

Code review 2026-09-26 (full-opus; blind-hunter, edge-case-hunter, verification-gap, acceptance-auditor): 52 rows, 16 entries — high 1, medium 4, low 11; 0 decision-needed, 12 patched, 1 deferred (ledgered), 3 by-design, the rest rejected.

- [x] [Review][Patch] **HIGH, AD-57 (2)/Rule 6:** a path parameter of `..%2F..%2F..%2Fx` composes `/api/admin/.../..%252F..%252F..%252Fx`, which `resolveTarget` fully decodes to `/api/x`, so a `DELETE` was offered while the wire path stays under `/api/admin` (probed on `ocupilot-ci`: the same spelling under `/api/ocupilot` is answered by OcuPilot's router). Fixed: `refuseRequest(verb, url)` refuses when any reading (each decoding, with and without dot removal) is refused; the page and store call it [ui/src/app/areas/web-applications/try-it.ts:224]
- [x] [Review][Patch] The dialog heading's URL masking was unpinned (AC4 DOM half) [openapi-try-it.page.spec.ts]
- [x] [Review][Patch] The store's `send`-side refusal reddened nothing alone; now `pending()` is asserted null [ui/tools/try-it.test.mjs]
- [x] [Review][Patch] The browser "no cookie" check read `request.headers()`, which precedes cookie attachment; it now reads CDP `requestWillBeSentExtraInfo` with a floor [ui/browser/openapi-try-it.browser-spec.mjs:152]
- [x] [Review][Patch] The package-only "no toggle" assertion had no rendered-operation floor [openapi-try-it.page.spec.ts]
- [x] [Review][Patch] "One function does the resolution and both refusals" was two functions combined at two call sites; `refuseRequest` is that function [try-it.ts]
- [x] [Review][Patch] `confirmHeading` passed the URL to `String.replace` as a string, so `$&` in a document path garbled it; replacer functions now [openapi-viewer.page.ts:469]
- [x] [Review][Patch] The per-operation no-address refusal was untested [openapi-try-it.page.spec.ts]
- [x] [Review][Patch] DW-1337 never drew a refusal line; the admin-write refusal case now runs `assertStructure` [openapi-try-it.browser-spec.mjs]
- [x] [Review][Patch] The node test header's trailing-slash mutation line contradicted the observed result; corrected [ui/tools/try-it.test.mjs:18]
- [x] [Review][Patch] `resolveTarget`'s comment claimed decoding "until nothing changes" (it stops at eight); rewritten with the patch [try-it.ts]
- [x] [Review][Patch] The QA redirect test's comment narrated spec history; trimmed to what it pins [ui/tools/try-it.test.mjs]
- [x] [Review][Defer] CLAUDE.md says "all 56 ADs"; the spine holds 57 [CLAUDE.md:105] — deferred: agent-context file, DW-1704 wontfix-accepted
- [x] [Review][By-design] Only top-level JSON body members are masked (nested ones and non-JSON bodies are not): the Always bullet says top-level; the body field shows the same text unmasked.
- [x] [Review][By-design] `X-API-Key`, `api_key` escape the credential pattern: the spec binds masking to Conventions › Secrets; a separator-insensitive pattern is a convention change.
- [x] [Review][By-design] JSON integers above 2^53 lose precision when pretty-printed: the spec mandates `JSON.parse`/`JSON.stringify` only.

Rejected:

- false: an expired token is sent after 60 s — `Session.scheduleRenewal` renews before expiry.
- false: an unparseable URL reads as own-application — `composeRequest` yields only parsed same-origin URLs.
- false: the `strings.ts` `:614`→`:615` citation edit breaks add-only — sanctioned in Design Notes, and correct.
- wontfix-theoretical: `%00`, `;param`, trailing `%20` after a protected prefix — each is answered by the web server's own 404 on `ocupilot-ci`; real only behind a front end that strips `;params` or truncates at NUL.
- low: required parameters are not enforced (`/v2//`) — the dialog restates the exact URL; the fix needs a new Fixed string while EXPERIENCE.md is line-frozen.
- low: a redirect shows as status 0 — rare; same Fixed-string constraint.
- low: the dialog shows `displayUrl`, not `resolved.href`; the record lists `Authorization` with no token — previously adjudicated.
- low: whole-body buffering, no timeout; body always `application/json`; `formData` on GET; duplicate path names; non-UTF-8 charsets; `__proto__` members; multibyte split at the cap — unlikely, each fix adds machinery.
- low: `OWN_APPLICATIONS` not pinned to the installer; Cancel clicked by position; heading outline and live-region; "256 KB"/"1 bytes" wording; disabled-Send and note contrast unmeasured; AC4 masking proven in jsdom only; the second `calls` assertion — cosmetic or unlikely.

## Spec Change Log

- 2026-09-26, lead, spec gate: orchestrator ruling (A) on the AD-10 intent gap, written into the spine as AD-57 (pointers from AD-10, AD-28, AD-39). Added the `/api/admin` write refusal, browser-equivalent target resolution before comparison, the spelling and admin-write matrix rows, the refusal AC, and per-arm reddening tests. Status reset to ready-for-dev.

## Review Triage Log

### 2026-09-26 — Review pass

- verdicts: 18 findings — high 0, medium 5, low 8, false 5, maybe-false 0
- findings:
  - `[medium]` `[patch]` (verification-gap) switching documents clears the console, untested — added the component case "opening another document forgets every console" and the node case "reset forgets every console"; mutations observed red. The "late answer lands in B" half is false: `reset` detaches each console's state, so a late answer writes to an orphan.
  - `[medium]` `[patch]` (verification-gap) the dropped declared `Authorization` header and the no-token case are unpinned at `fetch` — added the store case; mutation observed red.
  - `[low]` `[patch]` (verification-gap) the page's cut notice and byte-count line are untested — added the component case; each template block's removal observed red.
  - `[medium]` `[patch]` (verification-gap) the `basePath`-versus-application choice is never exercised — added the component case for a declared and an absent `basePath`; mutation observed red.
  - `[medium]` `[patch]` (verification-gap) form-body masking is unpinned — added the node case; mutation observed red.
  - `[low]` `[reject]` (verification-gap) the "issues no request" assertions cannot fail — the jsdom `img` query pins it with a recorded mutation and a node that was never created issues nothing; a browser case needs an instance endpoint answering markup.
  - `[low]` `[patch]` (verification-gap) the store refusal mutation line is imprecise — observed each check alone green and both removed red; line corrected.
  - `[low]` `[patch]` (verification-gap) AC1's display half has no mutation line — dropped the body from the answer text, the GET case went red; line added.
  - `[low]` `[reject]` (verification-gap) the record lists `Authorization` when no token was sent — a tab on the viewer holds a token; the fix adds a parameter for a state users do not meet.
  - `[medium]` `[patch]` (intent-alignment) R1: `basePath` preferred over the listed application, untested — grouped with the `basePath` row above; same case.
  - `[false]` `[reject]` (intent-alignment) R3: decoding until stable is stricter than the browser — over-refusal is the safe side of AD-57 (2); no request that must be refused is sent.
  - `[low]` `[reject]` (intent-alignment) the origin is not re-checked in the store — `composeRequest` is its only producer and its `no-address` cases are pinned; a re-check adds a branch for an unreachable state.
  - `[false]` `[reject]` (intent-alignment) R4: secrets held in store memory — the contract scopes the unmasked value to the field versus the record and DOM; the form state is the field's value, and the pending request is "until send".
  - `[low]` `[reject]` (intent-alignment) R5: the dialog shows the masked `displayUrl`, not `resolved.href` — masking is AD-57 (4)'s; they differ only for dot segments in a document literal (inference), and a second URL rendering adds surface.
  - `[false]` `[reject]` (intent-alignment) the screen-context negative is not pinned by a test — the diff adds no context wiring and no ObjectScript; the viewer's declared context is unchanged.
  - `[low]` `[reject]` (intent-alignment) R8: record versus wire — same as the no-token record row.
  - `[false]` `[reject]` (intent-alignment) R6/R7 wording readings — the spec's Tasks name the admin-write wording and one package-only reason; the diff matches.
  - `[false]` `[reject]` (intent-alignment) mutations exercise the resolver on raw strings only — two composed-request refusals, the component "show Send whatever `refusal` answers" mutation and the browser spec's refused-Send cases pin the composed path.

## Design Notes

**Design decision (flagged for review): where the request is issued and what "the current session" is.** Measured on `ocupilot-ci` (52776), 2026-09-26, after a form login to `/api/ocupilot/login`:

- The login sets one cookie, `CSPBrowserId` (path `/`, HttpOnly). A cookie-only request answered **401** at `/api/admin`, `/api/mgmnt`, `/api/atelier`, `/api/fhir-explorer` and `/api/ocupilot/instance`: the cookie authenticates no data route, only the token endpoints.
- The OcuPilot **access token authenticates every JWT-enabled application**, not only `/api/ocupilot`: `GET /api/admin/v2/web-apps` and `GET /api/admin/v2/web-app?name=/api/atelier` answered 200 with the full configuration, `/api/fhir-explorer/` answered 404 (authenticated, no route). At non-JWT password apps (`/api/mgmnt`, `/api/atelier`) it answered 401.
- JWT-enabled on this build: `/api/admin`, `/api/ocupilot`, `/api/interop-editors`, `/api/fhir-explorer`, `/api/security-config`, `/csp/fhir-management/api`, `/csp/fhirsql/api/ui`, `/csp/healthshare/hssys/app/api`, `/csp/oauth2-client/api`, `/csp/oauth2-server/api`.
- The explorer lists `/api/admin` and `/api/ocupilot` in `HSCUSTOM`, and `/api/admin`'s document declares `put` and `delete` on `/v2/web-app`.

So (c): the only credential that makes "with the current session" true for an authenticated application is the tab's access token, sent from the browser. A server-side relay cannot carry the session without a new instance-to-itself HTTP path (a new outbound path, and AD-1's spirit), and a cookie authenticates nothing. The request is therefore issued by the browser, same-origin, Bearer, no cookie. It is not a tool, so AD-1 is not engaged; nothing rendered issues it (AD-11 rule 4: a person's click does); CSP `connect-src 'self'` already admits it and nothing is evaluated (AD-47); no port is involved, so AD-29's gate is the target application's own authentication and the viewer's pair set (AD-8).

(a) A non-safe verb takes a confirmation dialog restating verb and URL: the person has composed it, but a DELETE sent by a stray Enter is the failure "developer tool first" still guards against (permit behind confirmation, not ban). No typed name: the console names no object.

(b) Requests resolving under OcuPilot's own applications are refused without sending: `/login` would mint and display a live token pair, `/logout` would end the instance-wide login (AD-28), and every other route refuses a request the console makes no differently from the shell's own.

**Ruled (orchestrator, 2026-09-26, option A; AD-57).** The halt below was answered by AD-57: the console is a browser request under the tab's token, neither a tool nor the write path; it refuses OcuPilot's own applications and `/api/admin` writes after browser-equivalent resolution, confirms every other write, and keeps the raw response screen-only (a named AD-39 exception). Named gap: those writes stay reachable outside OcuPilot, as from the classic portal. The halt as raised: With the access token, a try-it `DELETE` or `PUT` on `/api/admin/v2/web-app?name=/api/ocupilot` would delete or weaken OcuPilot's own web application through the vendor admin API, outside OcuPilot's write path where AD-10's prohibited set is evaluated (inference: the GET was measured authenticated and the route is declared; the delete was not executed). A console-side refusal is "a self-protection rule a screen enforces only in its UI", which AD-10 says is not a prohibition. The token also reaches the target application's own code (bounded by the access token's 60 s lifetime), which AD-28 does not say; and the raw response body reaching the screen is a new AD-39 exception.

**Governing ADs:** AD-57, AD-1, AD-5, AD-8, AD-10, AD-11, AD-13, AD-19, AD-20, AD-24, AD-28, AD-29, AD-36, AD-39, AD-47.

**Integration ACs:** no service is introduced; the console is screen-only and has no consumers. **Consumes:** Story 6.1's viewer, its read and `MgmntPort` `Document`, and `TokenStore`.

**Governance:** the epic preamble's "added to Epic 14's governance baseline" does not apply: this story adds no tool.

**Declined DW-118:** already resolved by Story 15.6 (`resolved-by:15-6-the-light-and-dark-theme`).

**Contended files touched:** `ui/src/styles/_components.scss` (append at end only). `openapi-viewer.page.spec.ts`, `Router.cls`, `AdminPort.cls`, `proposal-card.ts` are not touched; EXPERIENCE.md gains rows at the end of Fixed strings only. Its one appended row moves every later line by one, so `strings.ts`'s `taskCreate` citation moves `:614` -> `:615`.

**Bundle re-base (DW-1166):** the initial total measured 1,856,906 bytes, past the 1854 kB warning. The policy's 5% would give 1950 kB, past the 1900 kB stop line for this epic, so `maximumWarning` is 1900 kB, pinned in `ui/tools/angular-json.test.mjs`.

## Verification

**Commands:**

- `cd ui && node --test tools/try-it.test.mjs tools/credential-lists.test.mjs` (loop) -- expected: green; mutation: drop the `..` refusal in `composeRequest` -> the traversal case reds; mutation: remove the own-application arm of `refusal` -> the own-app cases red; mutation: remove the `/api/admin` write arm -> the admin-write cases red; mutation: skip the percent-decode in `resolveTarget` -> the `%6F` spelling case reds.
- `cd ui && npx ng test --include src/app/areas/web-applications/openapi-try-it.page.spec.ts` (loop) -- expected: green; mutation: bind the body with `[innerHTML]` -> the markup-as-text case reds.
- `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/ && OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci node --test --test-concurrency=1 browser/openapi-try-it.browser-spec.mjs` (loop) -- expected: green on `ocupilot-ci` only (a mutating verb is only ever sent there); mutation: omit the Bearer -> the `/api/admin` 200 case reads 401.
- `cd ui && npm test` (once, before dev_complete) -- expected: green, bundle under `maximumWarning`, re-based to 1900 kB under DW-1166 (see Design Notes).
- Full ObjectScript sweep through `node tools/ci-runner.mjs --container ocupilot-ci`, one class at a time (once, before dev_complete) -- expected: green; this story changes no ObjectScript.

**Observed (implement, 2026-09-26; each file restored byte for byte after its run):**

- mutation: drop the `.`/`..` segment check in `composeRequest` -> "a path parameter of . or .. is refused at its field" red.
- mutation: remove the own-application arm of `refusal` -> "every spelling of OcuPilot's own applications", "a composed request that resolves under OcuPilot's own application" and "the store refuses at send" red.
- mutation: remove the `/api/admin` write arm of `refusal` -> "a write under /api/admin is refused by every spelling" and "the store refuses at send" red.
- mutation: skip the percent-decode in `resolveTarget` -> the resolution table, the own-application spellings and the admin-write spellings red.
- mutation: skip the dot-segment removal after decoding -> the resolution table and the own-application spellings red.
- mutation: skip the slash collapse -> the resolution table, the own-application and admin-write spellings red.
- mutation: skip the trailing-slash drop -> the resolution table red (the whole-segment match alone already refuses `/api/admin/`).
- mutation: skip the case fold -> the resolution table, the own-application and admin-write spellings red.
- mutation: skip the backslash-as-slash step -> the resolution table red.
- mutation: stop masking a secret query value, a secret header, or a secret body member -> "every secret the request carries reads masked" red.
- mutation: drop `token` from `secret-names.ts` -> the credential-lists pin and the masking case red.
- mutation: send `credentials: 'include'` -> "the store sends a safe verb at once" red; drop both of the store's refusal checks (in `send` and `dispatch`) -> "the store refuses at send" red, where either alone stays green because the other still refuses; send a write without holding it -> "the store holds a write for its confirmation" red.
- mutation: bind the answer with `[innerHTML]` -> the component spec's markup-as-text case red; show Send whatever `refusal` answers -> its admin-write and own-application cases red; confirm a write right after Send -> its dialog case red; bind a field with `[attr.value]` -> its secrets-in-DOM case red.
- mutation: omit the Bearer in `try-it.store.ts`, rebuilt and redeployed to `ocupilot-ci` -> the browser spec's `/api/admin` case read 401, not 200.
- mutation (review pass): drop the body from the answer text in `tryItView` -> the component GET case red (AC1's display half); drop `this.tryIt.reset()` from the page's load -> "opening another document forgets every console" red; drop `this.consoles.clear()` from `reset` -> "reset forgets every console" red; send a declared `Authorization` header -> "the store sends the tab's token as the one Authorization" red; drop the cut notice, or the byte-count line, from the template -> the component cut/byte-count case red; make `basePath()` ignore the document -> the component basePath case red; show the form body unmasked -> "a secret-named form parameter reads masked" red.
- (QA) `ui/tools/try-it.test.mjs` -- added "a redirect answer (fetch resolved, redirect: manual) is shown as status 0 with nothing invented", pinning the Auto Run Result's named residual (a redirect reads status 0, no explanatory line) as observed behavior rather than leaving it unverified; mutation: mark `state.failed` true whenever `answer.status === 0` in `try-it.store.ts`'s `dispatch` -> red (`store.failed` reads `true`, not `false`); reverted, `try-it.store.ts` confirmed byte-identical.
- mutation (code review): make `refuseRequest` read only the fully decoded path -> "a path whose readings disagree is refused when any reading lies under a protected application" red; the same in the page -> the component disagreeing-readings case red; remove either arm of `refusal` -> the own-application or admin-write cases and "the store refuses at send" red; drop the store's `send`-side check -> "the store refuses at send" red (`pending()` not null); fill the dialog from `url` -> the component secrets case red; pass the URL to `replace` as a string -> the `$&` case red; drop the page's no-address refusal -> the no-address case red; send `credentials: 'include'`, rebuilt and redeployed to `ocupilot-ci` -> the browser `/api/admin` case red at "no cookie is sent". Each file restored byte for byte.

## Auto Run Result

Implement pass, 2026-09-26. Each operation of a listed application's OpenAPI document gets a "Try it" console. It is sent by the browser under the tab's Bearer, with no cookie and no redirect. It refuses OcuPilot's own applications and `/api/admin` writes after browser-equivalent resolution, confirms every other write, masks the record, and renders the answer as text on the code surface (AD-57).

- Files:
  - `ui/src/app/areas/web-applications/try-it.ts` (new): composition, resolution, refusal, masking and rendering.
  - `ui/src/app/areas/web-applications/try-it.store.ts` (new): the framework-free console store.
  - `ui/src/app/areas/web-applications/openapi-viewer.page.ts`: the disclosure, form, dialog, record and answer.
  - `ui/src/app/core/secret-names.ts` (new): the runtime credential pattern.
  - `ui/src/app/core/strings.ts` and EXPERIENCE.md: 11 keys and one appended Fixed-strings row.
  - `ui/src/styles/_components.scss`: rules appended at the end only.
  - `ui/angular.json` and `ui/tools/angular-json.test.mjs`: the warning re-based to 1900 kB (Design Notes).
  - Tests (new): `ui/tools/try-it.test.mjs`, `ui/tools/credential-lists.test.mjs` (extended), `openapi-try-it.page.spec.ts` and `ui/browser/openapi-try-it.browser-spec.mjs`.
- Review: 18 findings. Seven patched, all test additions or mutation lines: five mediums in four entries, plus three lows. Five were rejected as false and six lows rejected (Review Triage Log). None was deferred.
- Follow-up review: `false`. The four patched medium entries were missing tests, each added with its mutation observed red, and the patch pass changed no production code, so no unverified risk remains to name.
- Verification:
  - Node story tests: 24 of 24 pass.
  - Component spec: 12 of 12 pass.
  - Browser spec on `ocupilot-ci`, after rebuild and redeploy: 5 of 5 pass, with DW-1337 holding in both themes and no new allowance.
  - `npm test`: 1488 node tests and 1463 component tests pass. The bundle measures 1,856,906 bytes.
  - Full ObjectScript sweep on `ocupilot-ci` (source refreshed and recompiled first): 291 classes ran, 14 refused for arming (`OCUPILOT_ALLOW_*`: task control 7, service config 3, audit purge, audit toggle, error delete, process control), and 1 is known residue (`WireSecurityRead` task history, DW-1425/DW-1468). The 14th refusal is still an arming refusal; this story changes no ObjectScript.
- Residual risks:
  - A redirect answer shows status 0 with no explanatory line.
  - EXPERIENCE.md prose citations after line 573 were already stale, and are now off by one more.

Status: done
Blocking condition: none
