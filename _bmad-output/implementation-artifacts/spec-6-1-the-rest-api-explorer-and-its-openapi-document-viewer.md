---
title: 'The REST API explorer and its OpenAPI document viewer'
type: 'feature'
created: '2026-09-16'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-6-context.md'
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
warnings: [oversized]
deferred: []
---

<intent-contract>

## Intent

**Problem:** Nothing in OcuPilot answers "what API is running here?": the Web applications area has one screen, the spine's `MgmntPort` does not exist, and the declared read accepts only the `admin` and `state` source kinds.

**Approach:** Add `Port/MgmntPort`, which reaches `/api/mgmnt`'s own business-logic class (`%Api.Mgmnt.v2.impl`) in process behind its own gate, and add `mgmnt` as a third declared-read source kind. Build two descriptors on it: the REST API explorer (`list`), and the OpenAPI document viewer (`viewer (OpenAPI)`), whose rows are the document's operations and whose read answer also carries the document. Each screen's read tool is derived from its descriptor. Only the viewer gets a bespoke page.

## Boundaries & Constraints

**Always:**

- **Port contract.** `MgmntPort` is the only class that names `%Api.Mgmnt.*`, `%REST.*` or `%SYS.REST` (AD-29).
- **Call sequence.** Evaluate the gate first. Then shape-validate the arguments. Then `New %request,%response,%session` with fresh `%CSP.Request`/`%CSP.Response` stubs, capture device output through `$$BeginCapture^%SYS.Capture`/`$$EndCapture^%SYS.Capture`, and call the impl method. Read the outcome from both its return and `%response.Status`.
- **Faults.** Every fault goes through `Kernel.Fault` with a written reason (AD-39). Raw vendor text reaches only `Fault.LogRaw`, never the response device (AD-12).
- **Gate.** The pairs are `%Admin_Secure:USE`, `%DB_IRISSYS:READ`, the web-applications area's own set, in that order. They are declared once as a port parameter and equal both descriptors' `privileges`. The port checks them with `Screen.Gate.EvaluatePairs` before any vendor call, on the route and on the tool path alike (AD-8, AD-29).
- **Namespace.** The namespace is the route's scope. `Screen.Read` passes `Kernel.Scope.Current()` to the port as `namespace`. The port itself never sets `$NAMESPACE`: the impl methods switch for themselves (AD-16, AD-44).
- **Explorer rows** come from `GetWebRESTApps(ns)` plus `GetRESTApps(ns)`. A spec-based service reached through a listed web application's dispatch class appears once, under that web application. Each row carries:
  - `Name`: the web application path, or the service package.
  - `Namespace`: the row's own namespace.
  - `DispatchClass`.
  - `SpecBased`: true when the vendor's `swaggerSpec` is a `/api/mgmnt/v2/` URL, or the row came from discovery.
  - `Enabled`: `null` for a service with no web application.
- **Document resolution.**
  - A web application name must equal a `Name` in `GetWebRESTApps(ns)` exactly. The vendor's lookup is a longest-contains match.
  - Such a name resolves to `GetApplication(row namespace, package)` when `SpecBased`, and otherwise to `GetWebRESTApplication(row namespace, name)`.
  - A package name goes to `GetApplication(ns, name)`.
- **Document rows.** One row per operation, following `paths` iteration order and each path item's own key order (`get put post delete options head patch`). Each row carries:
  - `Order`: 1-based.
  - `Path`, `Verb`, and `Summary` / `OperationId` (`""` when absent).
  - `Parameters`: `[{name,in,required,type}]`. Path-level parameters are merged in, the operation's own win on the same `name`+`in`, and `#/parameters/<n>` references resolve from the document.
  - `Responses`: `[{code,description}]`.

  The unmodified document travels as the answer's `document` key. The row cap never cuts it.
- **Rendering.** Every document string renders as text, never markup (AD-11).
- **Client.** The viewer store imports no Angular and is provided by the page, never at root, so nothing survives sign-out. Styles use design tokens only (AD-19). Every new copy is a Fixed strings row plus its `strings.ts` key (non-ASCII as `\uXXXX`). Changes to Epic 4's shared files are additive.

**Never:**

- No HTTP request from product code to `/api/mgmnt` (AD-1).
- No hand-written tool class; nothing under `Screen/Tool/**`, `Kernel/**`, `scripts/check-objectscript.py`, `app.ts` or `shell/panel/**`.
- No reading of `^%SYS("REST",…)` and no reimplemented discovery.
- No classic link, auto-refresh, write or row action.
- A refusal, denial or fault is never an empty state.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Explorer, HSCUSTOM | `GET /screens/webapp.restapis/read?ns=HSCUSTOM` | 200. The rows include `/api/ocupilot` (SpecBased false, HSCUSTOM) and `/api/mgmnt` (SpecBased true, %SYS). | No error expected |
| Explorer, %SYS | `ns=%SYS` | The rows include `%Api.InteropEditors.v7` (SpecBased true, Enabled `null`, no web application dispatches to it) and `/api/interop-editors`. `%Api.Mgmnt.v2` is not a separate row, because `/api/mgmnt` deploys it. | No error expected |
| Generated document | `webapp.openapi`, `application=/api/ocupilot`, HSCUSTOM | One row per operation, `Order` in document order. `document` equals the body of `GET /api/mgmnt/v1/HSCUSTOM/spec/api/ocupilot`. | No error expected |
| Stored document | `application=/api/mgmnt`, HSCUSTOM | `document.swagger` is `"2.0"`. Each of its `#/parameters/` references (9 on 2026.2) appears in the rows as a resolved `{name,in,required,type}`. | No error expected |
| Vendor refusal | `application=%Api.InteropEditors.v7` in %SYS, or `/api/interop-editors` | 404 `PORT.NOTFOUND`. The reason is written per impl method: "The management API refused this document: it reports no REST application by that name." or "…: it reports no REST specification for that web application." | Neither `ERROR #` nor a class name appears in the reason. The viewer shows the refusal, with no browser and no empty state. |
| Unlisted web application | `application=/api/nosuch` | 404 `PORT.NOTFOUND` "This namespace lists no REST application by that name.", and no generation call | — |
| Bad argument | `application` absent, or neither `/…` nor a package name | 400 `PORT.VALIDATION`, and no vendor call | — |
| Vendor 400 / 403 | build failure / namespace switch refused | 400 `PORT.VALIDATION` "The management API could not build this document." / 403 `PORT.ACCESSDENIED` "The management API refused to enter this namespace for this account." | Refused-document state |
| Denied | principal without `%Admin_Secure:USE` | 403 `AUTH.NOPRIVILEGE`, `detail.failedPair` `%Admin_Secure:USE`, both from the route's gate and from the port's own gate when called directly (the tool path). A deep link shows the shell's screen-denied message naming the pair. A read refused with a pair after the page loaded shows "You need %Admin_Secure:USE to read this document." | No vendor call |
| Row cap | `maxRows=5` on a document with more operations | 5 rows, `truncated` true, full `document`. The viewer shows the cap notice. | — |
| Vendor fault | exception, capture refused, other non-2xx | 500 `INTERNAL`, generic reason | Raw text only in `Fault.LogRaw("mgmntport",…)` |

</intent-contract>

## Code Map

### Server

- `src/OcuPilot/Screen/Read.cls`:
  - `:64-75` has the `PortClass` seam and the `SOURCEADMIN`/`SOURCESTATE` parameters.
  - `:161-182` holds `Execute`'s port branch and the `tQuery("maxRows")` cap+1.
  - The answer is `{fields,rows,truncated,banner}`.
- `src/OcuPilot/Screen/Registry.cls`:
  - `:645-646` refuses any port other than admin or state.
  - `:664-673` refuses rowGet and criteria on state.
  - `:842-845` allows criteria on admin only.
  - `:755-766` is the admin-only `%DB_IRISSYS` arm.
  - `:740-744` is the `toolIdentifier` pattern `^[a-z][a-z0-9]*\.[a-z][a-z0-9]*$`.
- `src/OcuPilot/Screen/Tool/Read.cls` (read-only):
  - `:35-38` names each tool `<toolIdentifier>.read`.
  - `:119-167` `View` keeps only `fields`/`rows`/`truncated`, so the tool never sees `document`.
  - `AddCriteria` gives every `text` criterion the audit comma-list description.
- `src/OcuPilot/Api/ScreenRead.cls:44-90` plus `Router.cls:81`: `GET /screens/:screen/read` gates, seeds the declared criteria and runs Execute. No router change.
- `src/OcuPilot/Port/LogSourcePort.cls` is the own-gate pattern:
  - `ParsePairs` `:270`, `Gate` `:1034`
  - `DeniedRefusal` `:639-647`, `Refuse` `:1229`, `Fail` `:1239`
- `src/OcuPilot/Port/AdminPort.cls`:
  - `:708-751` stubs and saves/restores.
  - `:800-812` captures output and maps `<PROTECT>` to 403.
  - It names `%Api.Admin.Util.General`, which is off-limits here (AD-27), so use the `%SYS.Capture` routines it wraps.
- `irissys/%Api/Mgmnt/v2/impl.cls`:
  - `GetRESTApps` `:38`, `GetApplication` `:61`; the latter refuses `%Api.InteropEditors*` at `:72` and maps `RESTNoApplication` to 404.
  - `GetWebRESTApps` `:193`, `GetWebRESTApplication` `:216`; the latter refuses `/api/interop-editors` at `:226`.
  - `%ReportRESTError` `:249` writes `{"msg"}` to the device.
  - `%AdjustNamespace` `:265`.
- `irislib/%SYS/REST.cls`:
  - `:17-52` classifies web applications by `swaggerSpec` v2 versus v1.
  - `:190-215` is the discovery's class-list cache.
- `src/OcuPilot/Screen/Descriptor/WebAppList.cls` is the list descriptor template. `Screen/Area.cls:89` is the web-applications pair set. `Kernel/EntityType.cls:28` has `rest-service`. `Kernel/Scope.cls` `Current()`.
- Rosters to extend:
  - `Test/ReadTool.cls:97-98` (count 8 and names)
  - `Test/ScreenRead.cls:179-252` (the live-field test skips non-admin ports)
  - `Test/Descriptor.cls:63-83`
  - `Test/WireSecurityRead.cls:452,469,487` (web-applications screen JSON)
  - `Install/Smoke.cls:46-66,475-517` and `Test/Smoke.cls:198-240,373-390` (six list checks)
  - `Test/CriteriaCorpus.cls:82` ("admin port alone")
  - `Test/AdminPairCorpus.cls` (port cases)
- `Test/LogSourceDenial.cls:29,75-174` is the principal pattern, armed by `OCUPILOT_ALLOW_PRINCIPALS`.

### Client

- `ui/tools/screen-mirror.mjs`:
  - `:359-361` `READ_SOURCE_PORTS`
  - `:504-509` port sentence
  - `:744-746` criteria on admin only
  - `:1272` port union
  - the output goes to `ui/src/app/core/screens.generated.ts`.
- `ui/src/app/core/navigation.ts:156-180`: `EDITOR_ROUTE_SUFFIX`/`editorScreenFor`. `ui/src/app/shell/data-table.ts:404-416` resolves the name-cell link target.
- `ui/src/app/shell/screen-outlet.ts:48-54`: `ARCHETYPE_PAGES`, whose type requires every built archetype. `:203-206`: `entityId`.
- `ui/src/app/core/screen-read.ts:163-179` `screenReadPath`; `core/fault.ts:69-102`; `core/screen-actions.ts:29` `REFRESH_ACTION_ID`.
- `ui/src/app/areas/logs/error-log.page.ts` / `error-log.store.ts:354-380` are the pattern for the skeleton, refusal, pair-named denial and refresh-without-skeleton. `ui/src/app/app.ts:335-344` resets root stores, which is why the viewer store is page-provided.
- Tokens:
  - `ui/src/styles/_tokens.scss:156-159` code surface
  - `_typography.scss:105-110` code type
  - `_components.scss` disclosure `:2799-2820`, skeleton `:77-100`, empty state `:321`
- UX sources:
  - DESIGN.md `:1056`: verb chip is `secondary-container`, sentence case, no color per verb.
  - EXPERIENCE.md `:132-133`, `:477`, `:559`.
  - Fixed strings `:250-345`; strings.test ties each key to its row line, and `:319` is the literal-count band.
- Test rosters:
  - `ui/tools/navigation.test.mjs:116-132`
  - `ui/tools/screen-mirror.test.mjs:440-445,520-524`
  - `ui/src/app/shell/screen-outlet.spec.ts:332-344`
  - `ui/browser/error-log.browser-spec.mjs:205-225` (`signedInAtScreen`)

## Tasks & Acceptance

**Execution:**

- [ ] `src/OcuPilot/Port/MgmntPort.cls`: create it.
  - `Invoke(pEndpoint,pType,ByRef pQuery,pBody,Output pResult,Output pHttpStatus,Output pFault,Output pDocument)` serves endpoints `Applications` and `Document`, type `LIST`.
  - It follows the Boundaries contract and the Matrix.
  - Test seams: `GateClass`, `ImplClass`.
- [ ] `src/OcuPilot/Screen/Read.cls`: add `SOURCEMGMNT="mgmnt"` and a `MgmntPortClass()` seam. In the mgmnt branch, seed `namespace` from `Kernel.Scope.Current()` plus the declared criteria, call the port, and set `pResult.document` when the port returned one.
- [ ] `src/OcuPilot/Screen/Registry.cls`:
  - Accept `mgmnt`; the sentence names all three kinds.
  - Allow criteria on `admin` or `mgmnt`; the sentence is reworded.
  - Refuse `rowGet` on `mgmnt`.
- [ ] `src/OcuPilot/Screen/Descriptor/RestApiList.cls`: create it.

  | Key | Value |
  | --- | --- |
  | route | `web-applications/rest-apis` |
  | sideBarPosition | 2 |
  | archetype | `list` |
  | scope | `namespace` |
  | entityType | `rest-service` |
  | id | `single` |
  | read | `mgmnt`/`Applications`, fields as the Boundaries list, filter Name/Namespace/DispatchClass, sort fields Name/Namespace/DispatchClass with default Name asc, paging `cap` |
  | table | Name (name), Namespace, Dispatch class, Spec-based (status), Enabled (status) |
  | toolIdentifier | `webapp.restapis` |
  | classicPage | `""` |
  | aliases | `["REST","REST APIs"]` |
  | refreshes | false |

- [ ] `src/OcuPilot/Screen/Descriptor/OpenApiViewer.cls`: create it.

  | Key | Value |
  | --- | --- |
  | route | `web-applications/rest-apis/document` |
  | sideBarPosition | 0 |
  | archetype | `viewer (OpenAPI)` |
  | id | `single` |
  | read | `mgmnt`/`Document`, fields as the Boundaries list, filter Path/Verb/Summary, sort fields Order/Path/Verb with default Order asc, paging `cap` |
  | criteria | `application`: text, maxLength 256 |
  | table | Path (name), Verb, Summary |
  | context | Path, Verb, Summary, OperationId |
  | toolIdentifier | `webapp.openapi` |
  | empty state | "This document declares no paths." |

  Its privileges equal the explorer's.
- [ ] `src/OcuPilot/Test/MgmntPort.cls`, `MgmntPortWire.cls`, `MgmntPortDenial.cls` (armed): cover every Matrix row. Wire tests use `Test.Http`, and the denial class uses real principals on the throwaway. An `ImplClass` fixture supplies the vendor 400, 403 and fault rows the live instance cannot produce on demand.
- [ ] Existing tests and smoke:
  - Add mgmnt cases to `Test/CriteriaCorpus.cls` and `Test/AdminPairCorpus.cls`.
  - `Test/ReadTool.cls`: 10 tools.
  - `Test/ScreenRead.cls`: a mgmnt live-field test.
  - `Test/Descriptor.cls`: both descriptors.
  - `Test/WireSecurityRead.cls`: the three JSON pins.
  - `Install/Smoke.cls` and `Test/Smoke.cls`: a seventh check, `webapp.restapis`.
- [ ] `ui/tools/screen-mirror.mjs`: mirror the Registry rules and regenerate `screens.generated.ts`. `ui/tools/screen-mirror.test.mjs`: update the read and criteria rosters.
- [ ] `ui/src/app/core/navigation.ts`: add `DOCUMENT_ROUTE_SUFFIX='document'` and `documentScreenFor`, with the same built, unlisted and id-keyed test. `ui/src/app/shell/data-table.ts`: the link target becomes `editorScreenFor ?? documentScreenFor ?? screen`. `ui/tools/navigation.test.mjs`: the routes are `…/rest-apis/document`, `…/list`, `…/rest-apis`.
- [ ] `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md`: append one Fixed strings row per screen after `:344`, so earlier key comments do not renumber. `ui/src/app/core/strings.ts`: add the keys:
  - "REST API explorer"
  - "Spec-based"
  - "No REST applications in <NAMESPACE>."
  - "OpenAPI document"
  - "Path", "Verb", "Summary"
  - "Parameters", "Responses", "Required"
  - "Raw"
  - "This document declares no paths."
  - "read this document"
  - "This document was cut at the row cap — some operations are not shown."

  Raise `ui/tools/strings.test.mjs:319`'s upper bound only if the count exceeds it.
- [ ] `ui/src/app/areas/web-applications/openapi-viewer.store.ts` + `openapi-viewer.page.ts` + `.page.spec.ts`:
  - Read through `screenReadPath` with `application` set to the outlet's `entityId`.
  - Group rows into paths in `Order`.
  - Show the skeleton on first load. Refresh (`REFRESH_ACTION_ID`) re-reads without a skeleton; a namespace change re-fetches.
  - Refused-document state for any 4xx: `formatDeniedAction(privilegeDeniedAction, pair, "read this document")` for `AUTH.NOPRIVILEGE` with `detail.failedPair`, otherwise the envelope `reason`.
  - Keep the last values on a banner fault.
  - Show the cap notice.
- [ ] `ui/src/app/shell/screen-outlet.ts` (+spec): map `'viewer (OpenAPI)'` to `OpenApiViewerPage`. `ui/src/styles/_components.scss`: add the viewer styles:
  - the disclosure reuses the form disclosure;
  - verb chips use `secondary-container`/`on-secondary-container`;
  - the Raw `<pre>` sits on the code-surface tokens with its own two-dimensional scroll.
- [ ] `ui/browser/rest-apis.browser-spec.mjs`: add the browser ACs below.

**Acceptance Criteria:**

- Given a signed-in user on HSCUSTOM, when the Web applications area opens, then "REST API explorer" is its second side-bar entry, and the explorer's `/api/ocupilot` name cell opens `/ocupilot/web-applications/rest-apis/document/%252Fapi%252Focupilot?ns=HSCUSTOM`, which is never listed in the side bar.
- Given that viewer, when it renders, then:
  - paths appear in document order as collapsed `aria-expanded` disclosures;
  - opening one shows sentence-case verb chips that share one token pair, with each verb's parameters and response codes;
  - Raw (`aria-pressed`) shows the pretty-printed document on the code surface, scrolling inside its own block while the page does not scroll horizontally.
- Given `ns=%SYS` and the `%Api.InteropEditors.v7` row, when the viewer resolves, then it shows the refusal sentence from the envelope and no path browser and no empty state.
- Integration: given consumer `Screen.Tool.Read.View`, when it reads `webapp.restapis.read` and `webapp.openapi.read` (`application=/api/ocupilot`) with scope HSCUSTOM, then it returns the route's rows narrowed by the cap and no `document` key.
- Given a throwaway principal holding the install code database READ and both pairs, when it reads either screen in HSCUSTOM, then it gets 200. Without `%Admin_Secure:USE`, both the route and a direct `MgmntPort.Invoke` answer 403 naming that pair before any vendor call, and the explorer's side-bar entry stays listed and focusable, naming the resource.
- Given the explorer on HSCUSTOM, when the namespace switches to %SYS, then it re-fetches, and the `%Api.*` spec-based services appear.

## Spec Change Log

## Review Triage Log

## Design Notes

**Architecture decisions:**

- **AD-1:** the port calls in process.
- **AD-5:** one descriptor per screen, and tools are derived.
- **AD-8 / AD-29:** the port's own gate. The pairs match `WebAppList`, because the explorer exposes the web application list. `%DB_IRISSYS:READ` is also what the vendor's `%AdjustNamespace` requires for `%SYS`.
- **AD-11:** document text is untrusted.
- **AD-12 / AD-39:** output is captured, and reasons are written per impl method and status, so vendor text is never parsed or echoed.
- **AD-13 / AD-44:** namespace scope. The id is one segment. `classicPage` is empty because WA-06/07 are new, and the screens link out to nothing.
- **AD-16, AD-19, AD-21, AD-24, AD-36:** one read serves screen and tool. The tool narrows it to `rows`.
- **AD-43:** no refresh.
- **AD-7:** the tool writes nothing. `GetRESTApps` refreshes the vendor's derived class-list cache `^%SYS("REST","Application",ns)` when a namespace's class index changes. That is the vendor's own bookkeeping during a read, like AD-26's self-queued audit LIST.

**Why the impl class and not `%REST.API`:** the refusal lives only in the impl (`impl.cls:72`, `:226`). `%REST.API` returns the InteropEditors documents successfully, so calling it could never show "the refusal".

**Criterion description:** the tool schema describes the viewer's `application` criterion with the generic comma-list text from `Screen/Tool/Read.cls AddCriteria`, which is outside this epic. The port refuses anything but one exact name with a reason saying so.

**UX conflict:** DESIGN.md `:1056`'s "code block beneath the table" is superseded by the AC and EXPERIENCE.md `:133` per-path disclosures.

**Integration ACs:** the tool AC above, the explorer-to-viewer browser AC, and the smoke check.

**Consumed-by:**

- Story 16.1, the try-it console launched from viewer operations.
- Story 18.10, whose spec-based service create and delete round-trip through `MgmntPort`.

**Consumes:** `Screen.Read`/`ScreenRead` (Story 2.3), `ListPage`/data table (Story 2.4), `Kernel.Scope` (Story 1.11).

**Ledger inbox:** none owned by 6-1.

## Verification

**Commands:**

- `uv run scripts/check-objectscript.py` -- expected: 0 findings.
- Load and compile `src/OcuPilot/` through the IRIS MCP tools with `server: "ocupilot-slot-b"`, namespace HSCUSTOM -- expected: a clean compile.
- `sh scripts/ci-throwaway.sh up --dir /tmp/ocupilot-b-ci --project ocupilot-b-ci --web 52777 --super 1976` -- expected: healthy. Teardown: `sh scripts/ci-throwaway.sh down --dir /tmp/ocupilot-b-ci --project ocupilot-b-ci`.
- From `ui/`, `node tools/ci-runner.mjs --container ocupilot-b-ci --class <Class>`, one class per call, for:
  - MgmntPort, MgmntPortWire, MgmntPortDenial
  - ReadTool (which runs both corpora), ScreenRead, Descriptor, WireSecurityRead, Smoke

  Expected: all green, with totals confirmed from `%UnitTest_Result`.
- `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS` -- expected: non-zero checks, including `webapp.restapis`, with no failures.
- `cd ui && npm run build && npm test` -- expected: green, `screen-mirror --check` clean.
- From `ui/`, redeploy the bundle with `docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`, then run `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 npm run test:browser` -- expected: `rest-apis.browser-spec.mjs` green. The spec reads only and uses no `docker exec`.
- `bash scripts/lint-docs.sh` -- expected: clean for EXPERIENCE.md.

**Mutations (Rule 19; record each as `mutation:` once observed):**

- Skip the port gate → `MgmntPortDenial` port-path test goes red.
- Return empty rows on a vendor 404 → the refusal tests and the browser refusal go red.
- Sort document rows by Path → the `Order` test goes red.
- Drop `documentScreenFor` from the link → the browser explorer-to-viewer test goes red.
- Render Raw without the code-surface class → the page spec goes red.
- Point `MgmntPortClass` at `AdminPort` → the tool integration test goes red.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none
