---
title: 'The REST API explorer and its OpenAPI document viewer'
type: 'feature'
created: '2026-09-16'
status: 'done'
baseline_revision: 'c4750cd12cf1b11b67f81d4a455412676bf053a2'
baseline_commit: 'c4750cd12cf1b11b67f81d4a455412676bf053a2'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-6-context.md'
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
warnings: [oversized]
deferred:
  - summary: >-
      The browser verification command omits OCUPILOT_BROWSER_CONTAINER, so its docker exec legs run inside slot A's throwaway ocupilot-ci when a slot B runner follows it as written.
    evidence: |-
      ui/browser.config.mjs defaults the container to ocupilot-ci. In this stage the command as written sent the audit, error-log, gate, processes, tasks, unreadable and users exec legs to ocupilot-ci (container 6f064de71f8b, which Epic 4 then recreated mid-run as 4bbc39ef); re-run with OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci it was 81/81 green. The slot parameters (Rule 21) name no browser container.
    location: >-
      _bmad/custom/skill-rules.md Rule 21; this spec's Verification browser command
    severity: high
  - summary: >-
      The derived webapp.openapi.read schema describes the application criterion as a comma-separated list with a wildcard that may be omitted, while MgmntPort accepts exactly one name.
    evidence: |-
      Screen/Tool/Read.cls AddCriteria gives every text criterion the audit comma-list description; MgmntPort answers a list, a wildcard or an absent value with 400 PORT.VALIDATION. Screen/Tool/** is contended for this epic.
    location: >-
      src/OcuPilot/Screen/Tool/Read.cls AddCriteria
    severity: medium
  - summary: >-
      AD-8 says no elevation anywhere on the request path, while the vendor path MgmntPort reaches adds roles temporarily inside %SYS.REST and %REST.API.
    evidence: |-
      Recorded as an inference under Design Notes; the port's own gate runs in the caller's process first, so OcuPilot elevates nothing. A spine clarification of AD-8 for vendor-internal elevation is the lead's call (Rule 20).
    location: >-
      ARCHITECTURE-SPINE.md AD-8
    severity: low
  - summary: >-
      Nothing enforces that MgmntPort is the only product class naming %Api.Mgmnt.*, %REST.* or %SYS.REST.
    evidence: |-
      scripts/check-objectscript.py enforces the equivalent rule for %Api.Admin only (rule 16); the checker is contended for this epic.
    location: >-
      scripts/check-objectscript.py
    severity: low
  - summary: >-
      The locator bar's screen segment on an open OpenAPI document links to the viewer route with no id, which renders the port's 400 refusal sentence.
    evidence: |-
      ui/src/app/shell/locator-bar.ts links the screen segment to screen.route whenever an entity segment follows; for an unlisted id-keyed screen at its own route that route has no id to read.
    location: >-
      ui/src/app/shell/locator-bar.ts:215
    severity: low
  - summary: >-
      DESIGN.md :1056 and EXPERIENCE.md :561 still describe the OpenAPI browser as a composition on the explorer's table whose refused document is the empty state.
    evidence: |-
      The spec's Design Notes record DESIGN.md :1056 as superseded by the AC and EXPERIENCE.md :133; neither planning source was amended.
    location: >-
      _bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/DESIGN.md:1056
    severity: low
  - summary: >-
      documentScreenFor's built, unlisted and id-keyed guards have no test that reaches a failing branch.
    evidence: |-
      The shipped mirror has no <list>/document screen that fails a guard, so deleting the three guards leaves every test green; pinning them needs an injectable roster, as editorScreenFor's comment already notes for its own guards.
    location: >-
      ui/src/app/core/navigation.ts documentScreenFor
    severity: low
  - summary: >-
      ReadTool.TestTheErrorReadToolCarriesTheSummaryFieldsOnly failed once on a freshly started throwaway and passed on the immediate re-run.
    evidence: |-
      Run 4 on a new ocupilot-b-ci failed only "and reports that it truncated (AD-24, AD-36)"; run 5 was 24/24. The assertion depends on how many application errors the instance holds for the first date; this story does not touch ErrorRead.
    location: >-
      src/OcuPilot/Test/ReadTool.cls TestTheErrorReadToolCarriesTheSummaryFieldsOnly
    severity: low
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

- [x] `src/OcuPilot/Port/MgmntPort.cls`: create it.
  - `Invoke(pEndpoint,pType,ByRef pQuery,pBody,Output pResult,Output pHttpStatus,Output pFault,Output pDocument)` serves endpoints `Applications` and `Document`, type `LIST`.
  - It follows the Boundaries contract and the Matrix.
  - Test seams: `GateClass`, `ImplClass`.
- [x] `src/OcuPilot/Screen/Read.cls`: add `SOURCEMGMNT="mgmnt"` and a `MgmntPortClass()` seam. In the mgmnt branch, seed `namespace` from `Kernel.Scope.Current()` plus the declared criteria, call the port, and set `pResult.document` when the port returned one.
- [x] `src/OcuPilot/Screen/Registry.cls`:
  - Accept `mgmnt`; the sentence names all three kinds.
  - Allow criteria on `admin` or `mgmnt`; the sentence is reworded.
  - Refuse `rowGet` on `mgmnt`.
- [x] `src/OcuPilot/Screen/Descriptor/RestApiList.cls`: create it.

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

- [x] `src/OcuPilot/Screen/Descriptor/OpenApiViewer.cls`: create it.

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
- [x] `src/OcuPilot/Test/MgmntPort.cls`, `MgmntPortWire.cls`, `MgmntPortDenial.cls` (armed): cover every Matrix row. Wire tests use `Test.Http`, and the denial class uses real principals on the throwaway. An `ImplClass` fixture supplies the vendor 400, 403 and fault rows the live instance cannot produce on demand.
- [x] Existing tests and smoke:
  - Add mgmnt cases to `Test/CriteriaCorpus.cls` and `Test/AdminPairCorpus.cls`.
  - `Test/ReadTool.cls`: 10 tools.
  - `Test/ScreenRead.cls`: a mgmnt live-field test.
  - `Test/Descriptor.cls`: both descriptors.
  - `Test/WireSecurityRead.cls`: the three JSON pins.
  - `Install/Smoke.cls` and `Test/Smoke.cls`: a seventh check, `webapp.restapis`.
- [x] `ui/tools/screen-mirror.mjs`: mirror the Registry rules and regenerate `screens.generated.ts`. `ui/tools/screen-mirror.test.mjs`: update the read and criteria rosters.
- [x] `ui/src/app/core/navigation.ts`: add `DOCUMENT_ROUTE_SUFFIX='document'` and `documentScreenFor`, with the same built, unlisted and id-keyed test. `ui/src/app/shell/data-table.ts`: the link target becomes `editorScreenFor ?? documentScreenFor ?? screen`. `ui/tools/navigation.test.mjs`: the routes are `…/rest-apis/document`, `…/list`, `…/rest-apis`.
- [x] `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md`: append one Fixed strings row per screen after `:344`, so earlier key comments do not renumber. `ui/src/app/core/strings.ts`: add the keys:
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
- [x] `ui/src/app/areas/web-applications/openapi-viewer.store.ts` + `openapi-viewer.page.ts` + `.page.spec.ts`:
  - Read through `screenReadPath` with `application` set to the outlet's `entityId`.
  - Group rows into paths in `Order`.
  - Show the skeleton on first load. Refresh (`REFRESH_ACTION_ID`) re-reads without a skeleton; a namespace change re-fetches.
  - Refused-document state for any 4xx: `formatDeniedAction(privilegeDeniedAction, pair, "read this document")` for `AUTH.NOPRIVILEGE` with `detail.failedPair`, otherwise the envelope `reason`.
  - Keep the last values on a banner fault.
  - Show the cap notice.
- [x] `ui/src/app/shell/screen-outlet.ts` (+spec): map `'viewer (OpenAPI)'` to `OpenApiViewerPage`. `ui/src/styles/_components.scss`: add the viewer styles:
  - the disclosure reuses the form disclosure;
  - verb chips use `secondary-container`/`on-secondary-container`;
  - the Raw `<pre>` sits on the code-surface tokens with its own two-dimensional scroll.
- [x] `ui/browser/rest-apis.browser-spec.mjs`: add the browser ACs below.

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

### Review Findings

Code review 2026-09-16, tier `full-opus`: blind-hunter, edge-case-hunter, verification-gap, acceptance-auditor. 35 rows, 26 entries; 0 decision-needed, 13 patch, 4 defer, 9 rejected.

- [x] [Review][Patch] (med) The viewer's read was never checked for the route's namespace [ui/browser/rest-apis.browser-spec.mjs:133]
- [x] [Review][Patch] Verb-chip and Raw text tokens were unpinned [ui/browser/rest-apis.browser-spec.mjs:181]
- [x] [Review][Patch] The Raw `mutation:` line reddened only a class-name check; a browser Raw mutation is now recorded [spec ## Verification]
- [x] [Review][Patch] The denial route leg could not tell the route's gate from the port's [src/OcuPilot/Test/MgmntPortDenial.cls:270]
- [x] [Review][Patch] The row-cap test passed a document cut short [src/OcuPilot/Test/MgmntPortWire.cls:239]
- [x] [Review][Patch] `browserConfig` refused an origin without a container, not a container without an origin [ui/browser.config.mjs:62]
- [x] [Review][Patch] `PAIRS` doc said the vendor refuses `%SYS` without `%DB_IRISSYS:READ`; it silently reads its user namespace [src/OcuPilot/Port/MgmntPort.cls:31]
- [x] [Review][Patch] The viewer's Fixed strings row said the read tool's schema names its column labels [EXPERIENCE.md:346]
- [x] [Review][Patch] The viewer store computed a fault nothing reads [ui/src/app/areas/web-applications/openapi-viewer.store.ts:256]
- [x] [Review][Patch] Section headings were `h3` with no `h2` [ui/src/app/areas/web-applications/openapi-viewer.page.ts:136]
- [x] [Review][Patch] Two test comments overclaimed: "either direction", and the moved-gate mutation's outcome [src/OcuPilot/Test/MgmntPort.cls:404]
- [x] [Review][Patch] DW-1004: the locator's screen segment on a document opens the paired list [ui/src/app/shell/locator-bar.ts:215]
- [x] [Review][Patch] DW-1007: ReadTool's truncation assertion depended on the first date's entry count [src/OcuPilot/Test/ReadTool.cls:1025]
- [x] [Review][Defer] The viewer answer carries the uncapped document beside capped rows (AD-36) [src/OcuPilot/Screen/Read.cls] — deferred: DW-1008 `by-design`, spec-bound
- [x] [Review][Defer] A vendor `<PROTECT>` answers 500, not 403 [src/OcuPilot/Port/MgmntPort.cls:507] — deferred: DW-1009 `wontfix-theoretical` (maybe-false; settles with a reader lacking a dispatch class's routine database)
- [x] [Review][Defer] Port gates do not refuse the AD-21 placeholder accounts themselves [src/OcuPilot/Port/MgmntPort.cls:170] — deferred: DW-1010 `wontfix-theoretical`
- [x] [Review][Defer] Rule 21 names no `OCUPILOT_BROWSER_CONTAINER` [_bmad/custom/skill-rules.md] — deferred: DW-1011 `wontfix-accepted`

Rejected:

- `false` "three sources" contradicts AD-36: the sentence counts three `port` values; AD-36's two kinds group admin and mgmnt, as `Read.cls` says.
- `false` an unknown namespace reaches the vendor as a misleading 403: `Router.OnPreDispatch` answers 400 `NS.UNKNOWN` first.
- `low` no registry rule for mgmnt pairs, endpoints or criteria: no shipped descriptor reaches it, and `TestThePortsPairsAreBothDescriptorsAndTheAreas` pins every production mgmnt read.
- `low` `$ref` responses, body schemas, percent-encoded or path-item `$ref`: the vendor generates none; Raw shows them.
- `low` no copy button on Raw: part of DESIGN.md `:1056`'s superseded paragraph, left with DW-1005.
- `low` no real principal lacking only `%DB_IRISSYS:READ`: that pair's refusal is pinned at the port and in the navigation JSON.
- `low` a first-read server fault leaves the body blank: adjudicated in the implement triage.
- `low` a `127.0.0.1` or trailing-slash origin throws, a mismatched pair passes: a loud refusal is intended; the pairing is unknowable to the config.
- `low` stale `deferred:` frontmatter, Auto Run Result file list, spec narration: the fix edits the spec's lead-owned sections.

## Spec Change Log

- 2026-09-16 (after implement): the deferred HIGH (browser command without `OCUPILOT_BROWSER_CONTAINER`) is fixed in-story by the lead, orchestrator-approved: `browserConfig` throws on a non-default origin with no container, pinned by `ui/tools/browser-config.test.mjs`; the Verification command carries the variable. The other seven deferred items were harvested as DW-1001..DW-1007.
- 2026-09-16 (spec gate): AD-7 conflict raised by the lead (discovery rewrites a vendor cache during a read); orchestrator chose option (a). AD-7's Rule amended in the spine to name the derived-cache shape; Design Notes cite it, record the vendor elevation as an inference, and bind the AD-29 gate-before-call; `## Verification` names the gate mutation explicitly.

## Review Triage Log

### 2026-09-16 — Review pass

- verdicts: 56 findings — high 1, medium 7, low 43, false 5, maybe-false 0
- findings:
  - `[low]` `[patch]` blind: `ApplicationShapeOk`'s `.*[ctrl].*` match misses CR/LF — now `$Locate`; CRLF leg added to the shape test (red on the old code, observed).
  - `[medium]` `[patch]` blind: `MergedParameters` raises `<SUBSCRIPT>` on a parameter with no `name` or `in` — keyed by `$ListBuild(in,name)`; unnamed parameter added to the canned document (red on the old code, observed).
  - `[low]` `[patch]` blind: nothing holds a future mgmnt descriptor to the port's pairs — the pairs test now checks every production mgmnt read.
  - `[low]` `[reject]` blind: a `namespace` criterion on a mgmnt read would be overwritten by the scope — no descriptor declares one, scope-wins is the safe order, and the fix is a new rule in two engines.
  - `[low]` `[defer]` blind: the locator's screen segment opens the viewer with no id and shows the 400 sentence — shell locator semantics; deferred.
  - `[low]` `[reject]` blind: Raw is unreachable from the empty state — unlikely (vendor documents carry operations); fix adds a new state.
  - `[low]` `[patch]` blind: the cap notice showed under Raw — moved inside the paths view.
  - `[low]` `[reject]` blind: a first-load server fault leaves the viewer body blank — matches the error-log page's pattern; `ApiService` raises the shell banner.
  - `[medium]` `[defer]` blind: the derived tool schema describes `application` as a comma list — `Screen/Tool/**` is contended; deferred.
  - `[low]` `[defer]` blind: AD-36 and AD-8 not amended — AD-36 part false (mgmnt is its first kind, an instance endpoint behind a port); AD-8 wording deferred to the lead.
  - `[low]` `[patch]` blind: stale comments after a third source and a seventh check — `Read.cls`, `Install/Smoke.cls`, `Test/Smoke.cls` corrected; the cursor refusal sentence (still true, pinned in both engines) and the historical count in `strings.test.mjs` left.
  - `[low]` `[patch]` blind: "only class in the tree" is unenforced and tests name `%Api.Mgmnt.v2` — wording scoped to product classes; checker enforcement deferred (contended).
  - `[low]` `[patch]` blind: the "treat any 2xx as success" mutation note named legs that stay green — note now names the wrong-kind legs.
  - `[low]` `[patch]` blind: the navigation mutation note is compound — rewritten; guard pinning deferred.
  - `[low]` `[patch]` blind: `Test/MgmntPort` header overclaims and `%request`/`%session` are unpinned — header corrected; the caller-objects test now covers all three.
  - `[low]` `[reject]` blind: vendor 403 is only fixture-driven — spec assigns the 400/403/fault rows to the `ImplClass` fixture.
  - `[low]` `[patch]` blind: section headings uppercased and chip padding off DESIGN.md — uppercase removed, padding `0 6px`.
  - `[low]` `[defer]` blind: DESIGN.md :1056 and EXPERIENCE.md :561 not corrected at source — planning artifacts; deferred.
  - `[low]` `[patch]` blind: EXPERIENCE.md :346 row mislabels the column keys and carries a double negative — row text corrected.
  - `[low]` `[reject]` blind: smoke check named by tool identifier — the spec names the check `webapp.restapis`.
  - `[false]` `[reject]` blind: spec records no verification — written at finalize; full re-verification ran on a fresh throwaway with a rebuilt bundle.
  - `[low]` `[patch]` blind: `RestApiList` doc omits that `%` system APIs list in every namespace — doc corrected.
  - `[low]` `[reject]` blind: 256 and the pair parsing are duplicated — both halves answer 400; no named divergence.
  - `[low]` `[reject]` blind: `x-` response keys and an empty type span — rare in vendor documents, cosmetic; fix adds guards.
  - `[medium]` `[patch]` edge: `<SUBSCRIPT>` in `MergedParameters` — same entry as the blind finding above.
  - `[medium]` `[defer]` edge: tool schema for `application` — same entry as the blind finding above.
  - `[low]` `[patch]` edge: CR/LF passes the shape check — same entry as the blind finding above.
  - `[false]` `[reject]` edge: upper-case verb keys are dropped — Swagger 2.0 path-item field names are case-sensitive lower case.
  - `[low]` `[reject]` edge: Raw unreachable from the empty state — as above.
  - `[low]` `[patch]` edge: mgmnt read with fewer pairs passes the registry — as above.
  - `[low]` `[reject]` edge: `namespace` criterion overwritten — as above.
  - `[low]` `[reject]` edge: a 200 without `rows` renders nothing — the route always answers `rows` on 200; theoretical.
  - `[low]` `[patch]` edge: the mirror test applies a non-object `rowGet` the ObjectScript corpus ignores — guard aligned to an object check.
  - `[low]` `[reject]` edge: Refresh after a failed first read shows the skeleton — nothing is on screen to keep.
  - `[medium]` `[patch]` gap: the one-token-pair browser check opened a one-chip path — leg now opens a path with two or more operations and asserts two chips; mutation observed.
  - `[low]` `[defer]` gap: `documentScreenFor` guards unpinned — comment corrected; pinning deferred.
  - `[medium]` `[patch]` gap: the store's stale-answer guard is unpinned — overlapping-read page-spec leg added; mutation observed.
  - `[medium]` `[patch]` gap: a new route id is never exercised — new-id page-spec leg added; mutation observed.
  - `[low]` `[patch]` gap: AC2 and AC6 browser legs had no mutation lines — both observed and recorded.
  - `[high]` `[defer]` gap: the browser command reaches slot A's throwaway — it did in this stage; fix belongs to the slot parameters (Rule 21); deferred.
  - `[low]` `[patch]` gap: registry accepts an under-privileged mgmnt descriptor — as above.
  - `[false]` `[reject]` gap: no verification outcomes recorded — written at finalize.
  - `[false]` `[reject]` intent: the tool carries no `document` — the Integration AC requires exactly that.
  - `[low]` `[patch]` intent: the denial probe exercised only the fixture subclass — it now also calls the production `MgmntPort.Invoke` (403 naming the pair; 200 for both pairs).
  - `[low]` `[reject]` intent: deep-link denial untested for these routes — shell-generic and browser-covered on other lists; the denied nav entries are pinned.
  - `[low]` `[reject]` intent: the pair-named refusal sentence only in jsdom — the live 403 envelope and its rendering are each pinned.
  - `[low]` `[reject]` intent: vendor 400/403 refused-document state only at port level — the store's refusal branch is status-band generic.
  - `[low]` `[reject]` intent: `/api/interop-editors` refusal not in the browser — same page path; wire pins its reason.
  - `[low]` `[reject]` intent: viewer cap notice only against a stub — the viewer carries no max-rows control by spec.
  - `[low]` `[reject]` intent: no-vendor-call counts only through the fixture — counting needs the fixture; the route runs the same port code.
  - `[false]` `[reject]` intent: over-long `application` answers `READ.CRITERION` — the matrix row does not cover length; the declared bound answers 400 first.
  - `[low]` `[reject]` intent: production `LogFault` subsystem unasserted — one-line delegation to a parameter.
  - `[low]` `[reject]` intent: "never sets `$NAMESPACE`" checked by reading — structural; no assignment exists.
  - `[low]` `[reject]` intent: live document order weakly checked — canned unit test pins order, browser pins live path order.
  - `[low]` `[reject]` intent: store lifecycle by construction — page `providers` is the guarantee the spec names.
  - `[low]` `[reject]` intent: `70vh`, port reasons, roster edits, test strings — DESIGN.md sets no code-block height and lint passes; reasons follow LogSourcePort; roster edits are spec-required; test strings grouped above.

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
- **AD-7 (amended 2026-09-16 for this story):** the tool writes nothing of its own. `GetRESTApps` reaches `%SYS.REST.ListRESTApplications`, which rebuilds the vendor's discovery cache `^%SYS("REST","Application",ns)` when the namespace's class index changed. AD-7's Rule now names that derived-cache shape as its second read-triggered-write exception, so the explorer's read and its derived tool stay inside AD-7. A hand-copied `%Dictionary` discovery was refused: it reimplements vendor internals and would drift from what `/api/mgmnt` reports.
- **Vendor elevation (inference):** the same vendor path runs `$$$AddAllRoleTemporary` inside `%SYS.REST`/`%REST.API`. OcuPilot does not elevate; the port's own gate (below) is evaluated in the caller's process before the vendor call and is stricter than the vendor's own check, so AD-8 holds.
- **AD-29 gate (binding, orchestrator 2026-09-16):** `MgmntPort` evaluates its declared pairs `%Admin_Secure:USE` and `%DB_IRISSYS:READ` through `Screen.Gate.EvaluatePairs` (which is `$System.Security.Check` in the calling process) BEFORE any `%Api.Mgmnt`/`%REST` call, on the route and on a direct `Invoke` alike. A denial makes no vendor call.

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
- From `ui/`, redeploy the bundle with `docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`, then run `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci npm run test:browser` -- expected: `rest-apis.browser-spec.mjs` green; `ui/browser.config.mjs` refuses a non-default origin without the container. The spec reads only and uses no `docker exec`.
- `bash scripts/lint-docs.sh` -- expected: clean for EXPERIENCE.md.

**Mutations (Rule 19; record each as `mutation:` once observed):**

- mutation: `If 0` in place of `MgmntPort.Invoke`'s `EvaluatePairs` check (gate dropped), recompiled with `MgmntPortFixture` on `ocupilot-b-ci` -> `MgmntPortDenial.TestAPrincipalWithoutAdminSecureIsRefusedByTheRouteAndByThePort` red on both direct legs, whose `403 calls=0 AUTH.NOPRIVILEGE %Admin_Secure:USE` comparison carries the refusal and the no-vendor-call count (observed, run 11).
- mutation: `MgmntPort.Document` answers a vendor 404 as 200 with empty rows -> `MgmntPort.TestVendorRefusalsAreWrittenReasons` and `TestTheLivePortLeavesTheNamespaceWhereItWas`, `MgmntPortWire.TestTheRefusedServiceIsAnsweredByTheMethodThatRefusedIt`, and the browser refusal leg red (observed, runs 12-13 and `rest-apis.browser-spec.mjs`).
- mutation: sort `MgmntPort.DocumentRows`' answer by `Path` -> `MgmntPort.TestDocumentRowsFollowTheDocumentsOwnOrder` red on the order assertion (observed, run 14).
- mutation: drop `documentScreenFor` from `data-table.ts`'s link target, bundle rebuilt and redeployed -> the browser explorer-to-viewer leg and the %SYS refusal leg (reached through the same name cell) red (observed).
- mutation: render Raw's `<pre>` without `ocu-openapi-raw` -> `openapi-viewer.page.spec.ts` Raw leg red (observed).
- mutation: `Screen.Read.MgmntPortClass` answers `OcuPilot.Port.AdminPort`, recompiled with its descendants -> `MgmntPortWire.TestTheReadToolAnswersTheRoutesRowsNarrowedAndNoDocument` red on `the tool reads` for both tools (`<PARAMETER>` at `AdminPort.Invoke`) (observed, run 17).

- mutation: give the second operation's verb chip `surface-container` (`.ocu-openapi-operation:nth-child(2) .ocu-openapi-verb`), bundle rebuilt and redeployed -> `rest-apis.browser-spec.mjs` viewer leg (AC2) red (observed).
- mutation: drop `void this.readNow()` from `RefreshService.noteScopeChanged`, bundle rebuilt and redeployed -> `rest-apis.browser-spec.mjs` namespace-switch leg (AC6) red: no `%SYS` explorer read captured (observed).
- mutation: drop the generation check in `OpenApiViewerStore.read` -> page spec "a late answer for a read the page has moved past is dropped" red (observed).
- mutation: reload on `paramMap` only while no application is loaded -> page spec "a new id on the same route reads that document from the start" red (observed).
- mutation (lead, deferred HIGH fixed in-story): `browserConfig`'s container guard condition replaced by `if (false)` -> `ui/tools/browser-config.test.mjs` "a non-default origin with no container is refused, naming the variable" red (2 pass, 1 fail); reverted byte-identical, 3/3 (observed). (QA-style file record: `ui/browser.config.mjs`, `ui/tools/browser-config.test.mjs`.)
- mutation (QA): `groupByPath` in `openapi-viewer.store.ts` drops its `.sort((a, b) => a.order - b.order)` (paths grouped by first-encountered row instead of by `Order`) -> `openapi-viewer.page.spec.ts` "reads the route id as the declared criterion, draws the skeleton, then paths in Order as closed disclosures" and "opens a path to sentence-case verb chips with their parameters and responses, as text" both red (`['/alpha','/zeta']` vs expected `['/zeta','/alpha']`), independently exercising AC2's document-order claim, which the two already-recorded AC2 mutations (Raw class, verb-chip color) do not touch (observed via `npx ng test --include src/app/areas/web-applications/openapi-viewer.page.spec.ts`, 8/10 then 2 red; reverted, byte-identical, 10/10).

- mutation (CR): the viewer store's read passes `{ scope: null }`, bundle rebuilt and redeployed -> `rest-apis.browser-spec.mjs` viewer leg (AC2) and %SYS refusal leg (AC3) red on "the document is read in the route's namespace" (observed).
- mutation (CR): `.ocu-openapi-verb` on `surface-container-high`/`on-surface`, bundle rebuilt and redeployed -> the AC2 leg red on "that pair is secondary-container / on-secondary-container" (observed).
- mutation (CR): `.ocu-openapi-raw` `overflow: visible`, bundle rebuilt and redeployed -> the AC2 leg red on Raw's `overflowX` (observed).
- mutation (CR): the throwaway's copy of `Api/ScreenRead.Handle` gate replaced by `If 0`, recompiled with its subclass -> `MgmntPortDenial.TestAPrincipalWithoutAdminSecureIsRefusedByTheRouteAndByThePort` red on both "the route's own gate refuses" legs while the 403 held (observed, run 4; reverted, run 5 green).
- mutation (CR): the throwaway's copy of `MgmntPort.Document` drops the last path when the rows reach the cap -> `MgmntPortWire.TestTheRowCapNeverCutsTheDocument` red only on the whole-document comparison (observed, run 3; reverted, run 6 green).
- mutation (CR, DW-1004): the locator's screen segment route back to `screen.route` -> `locator-bar.spec.ts` DW-1004 leg red (observed).
- mutation (CR): `browserConfig`'s container-without-origin guard replaced by `if (false)` -> `browser-config.test.mjs` "a non-default container with the default origin is refused" red (observed).

Each was reverted, reloaded, and the tree confirmed byte-identical (`git status --short` and `git diff --stat` unchanged, file hashes equal); after the browser mutations the clean bundle was rebuilt, redeployed and the spec re-run green.

## Auto Run Result

**Change.** `Port/MgmntPort` reaches `%Api.Mgmnt.v2.impl` in process behind its own `%Admin_Secure:USE` + `%DB_IRISSYS:READ` gate, evaluated before any argument or vendor call; `mgmnt` is a third declared-read source; the REST API explorer (`webapp.restapis`) and the OpenAPI document viewer (`webapp.openapi`, bespoke page and store) are built on it, with a seventh smoke check.

**Files.**

- Server: `Port/MgmntPort.cls` (new port); `Screen/Read.cls` (mgmnt branch, `document`); `Screen/Registry.cls` (third source, criteria, no `rowGet`); `Screen/Descriptor/RestApiList.cls`, `OpenApiViewer.cls` (new); `Install/Smoke.cls` (seventh check).
- Server tests: `Test/MgmntPort.cls`, `MgmntPortWire.cls`, `MgmntPortDenial.cls` (armed), fixtures `MgmntImplFixture`, `MgmntPortFixture`, `MgmntReadFixture`, `MgmntDenialProbe` (new); `AdminPairCorpus`, `CriteriaCorpus`, `ReadTool`, `ScreenRead`, `Descriptor`, `WireSecurityRead`, `Wire`, `Smoke` (rosters and pins).
- Client: `core/navigation.ts` (`documentScreenFor`), `shell/data-table.ts` (link target), `shell/screen-outlet.ts` (+spec), `areas/web-applications/openapi-viewer.{store,page,page.spec}.ts` (new), `styles/_components.scss`, `core/strings.ts`, `core/screens.generated.ts` (regenerated), `tools/screen-mirror.mjs`, tool tests, `browser/rest-apis.browser-spec.mjs` (new).
- Docs: EXPERIENCE.md Fixed strings rows 345-346.

**Review.** 56 findings in 22 patch, 7 defer and 27 reject rows: 18 patched entries (4 medium, 14 low); 6 deferred entries, recorded with the checker-enforcement half of one patched finding and one verification flake as 8 `deferred:` items (1 high, 1 medium, 6 low); every rejection's reason is in the triage log. Follow-up review: `false` — the four patched mediums each carry an observed mutation, and the two port fixes were observed red on the pre-patch code.

**Verification.** `check-objectscript` 0 findings; `lint-docs` clean; `npm run build` green; `npm test` 794 node + 393 component tests green. Full `src/` loaded and compiled on `ocupilot-slot-b`. On a fresh `ocupilot-b-ci`, one class per call: MgmntPort 11, MgmntPortWire 8, MgmntPortDenial 2, ReadTool 24, ScreenRead 22, Descriptor 32, WireSecurityRead 6, Smoke 25, Wire 20, ScreenReadWire 6, all green (ReadTool's first run failed one environment-dependent assertion, deferred). After patches, re-upped: MgmntPort, MgmntPortWire, MgmntPortDenial green; `smoke.sh` 20/20 including `webapp.restapis`; browser suite 81/81 with `OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci`.

**Residual risks.** `Screen/Read.cls` doc lines were reworded in place, a likely merge touchpoint with Epic 4. The browser-container gap this stage found was fixed in-story (`browserConfig` refuses a non-default origin without its container).

Status: done
Blocking condition: none
