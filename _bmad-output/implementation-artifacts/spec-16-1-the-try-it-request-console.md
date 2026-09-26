---
title: 'Story 16.1: The try-it request console'
type: 'feature'
created: '2026-09-26'
status: 'ready-for-dev'
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

## Spec Change Log

- 2026-09-26, lead, spec gate: orchestrator ruling (A) on the AD-10 intent gap, written into the spine as AD-57 (pointers from AD-10, AD-28, AD-39). Added the `/api/admin` write refusal, browser-equivalent target resolution before comparison, the spelling and admin-write matrix rows, the refusal AC, and per-arm reddening tests. Status reset to ready-for-dev.

## Review Triage Log

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

**Contended files touched:** `ui/src/styles/_components.scss` (append at end only). `openapi-viewer.page.spec.ts`, `Router.cls`, `AdminPort.cls`, `proposal-card.ts` are not touched; EXPERIENCE.md gains rows at the end of Fixed strings only.

## Verification

**Commands:**

- `cd ui && node --test tools/try-it.test.mjs tools/credential-lists.test.mjs` (loop) -- expected: green; mutation: drop the `..` refusal in `composeRequest` -> the traversal case reds; mutation: remove the own-application arm of `refusal` -> the own-app cases red; mutation: remove the `/api/admin` write arm -> the admin-write cases red; mutation: skip the percent-decode in `resolveTarget` -> the `%6F` spelling case reds.
- `cd ui && npx ng test --include src/app/areas/web-applications/openapi-try-it.page.spec.ts` (loop) -- expected: green; mutation: bind the body with `[innerHTML]` -> the markup-as-text case reds.
- `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/ && OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci node --test --test-concurrency=1 browser/openapi-try-it.browser-spec.mjs` (loop) -- expected: green on `ocupilot-ci` only (a mutating verb is only ever sent there); mutation: omit the Bearer -> the `/api/admin` 200 case reads 401.
- `cd ui && npm test` (once, before dev_complete) -- expected: green, bundle under `maximumWarning` 1854 kB.
- Full ObjectScript sweep through `node tools/ci-runner.mjs --container ocupilot-ci`, one class at a time (once, before dev_complete) -- expected: green; this story changes no ObjectScript.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none (the AD-10 intent gap was answered by orchestrator ruling (A), recorded as AD-57 at the spec gate on 2026-09-26)
