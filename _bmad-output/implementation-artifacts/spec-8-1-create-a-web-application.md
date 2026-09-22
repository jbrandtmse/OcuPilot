---
title: 'Story 8.1: Create a web application'
type: 'feature'
created: '2026-09-22'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-8-context.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** A user cannot create a web application from OcuPilot, and the write path cannot express a create at all: `Mint` reads the target fresh unconditionally (`Mint.cls:141-143`) and refuses when that read is not an object (`:154-157`), so every shipped write presupposes a target that already exists. Story 8.1 is the product's first create, the first screen-side write that has to pass the prohibited set, and the story that builds the shared `form-page` contract Epics 8 and 9 inherit.

**Approach:** Add a third write kind — a **create write** — that keeps the same port, the same proposal, the same atomic confirm and the same audit trail, and changes exactly two things: the fresh read's acceptance is inverted (the target must be *absent*), and the fingerprint covers the target's absence rather than a property set. Ship it as `webapp.list.create` plus a full-page create form at `web-applications/list/edit`, both callers of one tool class, and confirm the `form-page` column and field widths by measurement so the figures stop being an assumption.

## Boundaries & Constraints

**Always:**

- The create's fresh read runs through the tool's declared port (AD-52), at the same endpoint and read type as the update tool, and a **404 is the success precondition**. A present target refuses the mint.
- The confirm re-reads and refuses `PROPOSAL.TARGETCHANGED` (409) when the name has been taken since the mint. This is load-bearing, not ceremony: `%Api.Admin.Endpoints.WebApp.App:RunPut` is an **upsert** with no refusal path, so without it a create silently rewrites somebody else's application.
- Two spellings of one name are one target (AD-13): the web-application rule is foldcase plus strip-trailing-slash and it already exists (`EntityRef.cls:59` `IDRULES`). `TargetRef` carries the canonical intended name from the mint, so AD-34's per-target lock and sibling cancel cover two creates of the same name unchanged.
- The screen's Save and the agent's confirm resolve **one tool class** for endpoint, request type, settable fields, payload composition and the prohibited-set evaluation. A story is not done when the button works.
- `AutheEnabled` is always sent explicitly and at least one authentication method is required. `Security.Applications.AutheEnabled` has `InitialExpression = 64` (Unauthenticated), so omitting the field creates an unauthenticated application by default.
- Every field-level sentence is authored once on the server and travels as AD-39's `detail.violations[]` `{field, code, reason}`.
- Every visible word is `{{ STRINGS.<key> }}`; every new key is appended at the end of `strings.ts` with a matching row in EXPERIENCE.md's Fixed strings table (`strings.test.mjs:557` holds them set-equal).

**Never:**

- Never send `Type` on the wire. `MergeJsonAndProperties` hard-codes `Type = $$$AppTypeCSP` (2) and `Type` is absent from `RequestBodySchema()`, so sending it is a 400 `UnexpectedRequestBodyField`. The CSP/REST/WSGI/ASGI choice is a *form* control that maps to a combination of `DispatchClass`, `WSGIType` and the WSGI fields — exactly as `%CSP.UI.Portal.Applications.Web` does it.
- Never put `Name` in the body (400 `UnexpectedRequestBodyField`); it is the `name` query parameter.
- Never let `MatchRoles` into the create tool's schema, settable fields or payload (AD-10, unconditional and both paths).
- Never make `Path` settable by the caller. `Security.Applications.Create` creates the directory if it does not exist; the server derives `Path` from `WSGIAppLocation` for a WSGI/ASGI create and leaves it alone otherwise.
- Never add a validate-only route (see DW-376 under Design Notes), never author a field sentence in the client, and never hand-transcribe a field list (AD-3).
- Never edit `src/OcuPilot/Kernel/Restraint.cls`, `src/OcuPilot/Port/LogSourcePort.cls`, `src/OcuPilot/Install/Smoke.cls`, `ui/src/app/areas/tasks/**` or `ui/src/app/areas/logs/**` — Epic 7 owns them. `src/OcuPilot/Port/AdminPort.cls` needs no edit: `WebApp.App/PUT` is already in `MUTATINGTYPES` and absent from `BODYLESSTYPES`.
- No Epic 9 work: the `web-applications/list/edit/:id` route opens with the created application loaded and a "Saved" confirmation; making it writable is Epic 9's web-application editor.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Create through the screen | `POST /api/ocupilot/web-applications` with a free name, `NameSpace`, and at least one auth method | 201; the response carries the created application; the client publishes `{kind:'changed', type:'web-application', scope:'instance', id, action:'created'}` and replaces the route with `web-applications/list/edit/<id>` | No error expected |
| Create through the agent | `webapp.list.create` minted, then user-originated confirm | The mint's read 404s, the payload is composed from the arguments, the diff is every supplied field against empty, `unchangedCount` 0; confirm re-reads, matches the absence fingerprint, writes, marks the audit event and publishes `created` | No error expected |
| Name already exists at mint | The `name` resolves to a live application | Mint refuses 400 `TOOL.ARGUMENTS`, "'<name>' is already present on this instance" | Refusal names the id argument; no proposal is stored |
| Name taken between mint and confirm | Proposal live; another party creates that name | Confirm's re-read answers an object, the absence digest differs, the proposal is closed `target-changed` and refused 409 `PROPOSAL.TARGETCHANGED` | The vendor upsert is never reached; no write occurs |
| Two spellings of one name | Mint on `/csp/App`, confirm while `/csp/app/` exists | Same refusal as the row above — `EntityRef` canonicalizes foldcase and the trailing slash before the key is built | Not two targets |
| Two live creates of one name | Two proposals on the same canonical `TargetRef` | The first confirm wins under the target lock; the sibling is closed `sibling` in the same transition (`Propose.cls:329-370`) | Loser refused with its terminal state, never retried |
| `MatchRoles` supplied | Any caller supplies `MatchRoles` in the create payload | Refused by the prohibited set inside the atomic transition; absent from the tool's schema so the model cannot author it | 403, code names the prohibition |
| Create at OcuPilot's own path | `name` resolves to a path that serves OcuPilot | Refused by the existing `ServesOcuPilot` predicate, whatever the caller | 403 |
| `NameSpace` omitted | Save with no namespace | The vendor answers 400 `MissingRequestBodyField` with `params:["NameSpace"]`; the port maps it to one `detail.violations[]` row; the banner takes focus, then the field | Sentence lands on the field it names |
| Unknown body field | A field outside the permitted create set reaches the payload | `UNCOVEREDFIELD` from the prohibited set before the port is touched; the vendor's own `UnexpectedRequestBodyField` short-circuits on the first offender and is the backstop | 403 / 400, one field named |
| No authentication method chosen | Save with `AutheEnabled` empty | Refused server-side on the `AutheEnabled` field; the application is never created with the vendor's unauthenticated default | Sentence lands on the auth-methods field |
| Name typed on blur | Blur on the Name field with a name already in use | `GET /api/ocupilot/web-applications/name?name=<n>` answers `{available:false, reason}` and the client renders the server's sentence | A failed look-up leaves the field unmarked rather than asserting availability |

</intent-contract>

## Code Map

**Write path (mine to change; `Kernel/Proposal/**` is not Epic 7's)**

- `src/OcuPilot/Screen/Tool/Write.cls` — the write base. `SENDSBODY` :67, `READTYPE` :57, `WRITETYPE` :62, `FINGERPRINTSUBJECT` :97, `PRECONDITIONFIELD` :105, `PORTCLASS` :114, `CHANGEACTION` :124 (its doc comment at :119 asserts "no shipped tool can be a create" — the sentence this story replaces). Abstract: `Endpoint()` :276, `SettableFields()` :283. `View()` :467 is `Final` and calls `Mint` once at :485.
- `src/OcuPilot/Kernel/Proposal/Mint.cls` — `Mint()` :112. Unconditional fresh read :141-143; 404 refusal :144-147; non-object refusal :154-157; `Merge()` :351 whose :370-372 refuses any settable field the read did not carry; `pUnchanged = tTotal - tChanged` :409; fingerprint :198-214; stored values :216-245; `GuardedMint` :246.
- `src/OcuPilot/Kernel/Proposal/Confirm.cls` — `Transition()` :238; prohibited call :303-318; `FingerprintMatches` :603, whose :630 re-reads, :636 gives up on a non-object and :650-655 compares two digests; `GuardedClaimAndClose` :384-399; body merge :408-410; ledger :423-425; marker :457.
- `src/OcuPilot/Kernel/Proposal/Fingerprint.cls` — `Of()` :39 refuses a non-`%DynamicObject` at :44; `Projection()` :65.
- `src/OcuPilot/Kernel/Proposal/Prohibited.cls` — `Prohibits()` :334 with the absent-target early-out at :380-383 ("not prohibited, because the fingerprint re-read refuses it moments later" — false for a create); `PermittedChangeFields` :267; `AlwaysProhibitedFields` :283 (`MatchRoles`, `DispatchClass`); `WebApplication()` :439; `ServesOcuPilot()` :1338; `UncoveredWriteTools()` :407 (must stay empty).
- `src/OcuPilot/Kernel/EntityRef.cls` — `Key()` :114, `Parse()` :134, `Validate()` :314, `IDRULES` :59 (`web-application:foldcase-striptrailingslash`), `NormalizedId()` :238.
- `src/OcuPilot/Kernel/State/Propose.cls` — `TargetRef` :78; `GuardedClaimAndClose` :329 with the target lock :348-355 and the sibling cancel :367.

**Tool, descriptor and derivation:**

- `src/OcuPilot/Screen/Tool/WebAppUpdate.cls` (109 lines) — the closest precedent. Copy its shape: `TOOLNAME` :34, `DESCRIPTORCLASS` :36, named exclusion parameters with stated reasons :41/:45, `PERMITTEDFIELDS` :51, `WRITERESOURCE`/`WRITEPERMISSION` :60/:62, `Endpoint()` :64, `SettableFields()` :71 → `..AdmittedFields()`, `PrivilegePairs()` :100 with its `$ListFind` de-duplication (DW-1208).
- `src/OcuPilot/Screen/Tool/FieldLists.cls:505-558` — `WebApp.App`, `source: "template"`, `method: "RequestBodySchema"`, 52 rows. **Already derived; no regeneration needed.**
- `src/OcuPilot/Screen/Tool/Classification.cls` — hand-written, keyed by tool name; three entries today. `ui/tools/field-lists.mjs` joins it with `FieldLists.cls` to emit `ToolFields.cls`; `DEFAULT_CLASS = 'secret'` :46 so an unclassified row fails closed.
- `src/OcuPilot/Screen/Descriptor/WebAppList.cls` — `primaryAction {"id":"", "selfProtection":""}` :57, `rowActions: []` :58, `table.emptyNextKey: "tableReadOnlyEmptyNext"` :82, `emptyAgentKey: ""` :83. `Screen/Registry.cls:1897-1903` enforces the pair: a write-capable descriptor declares `emptyAgentKey` and not `emptyNextKey`.
- `src/OcuPilot/Screen/Descriptor/AgentDefinitionForm.cls` — the one `form-page` descriptor; copy its declaration shape.
- `src/OcuPilot/Screen/Archetype.cls:70` — `form-page` classifies `linkOut: "detail"`.
- `src/OcuPilot/Port/AdminPort.cls` — `MUTATINGTYPES` :166 already carries `WebApp.App/PUT`; `Invoke` :414 refuses a mutating non-bodyless call whose body is not an object :453. **No edit.**
- `src/OcuPilot/Api/Router.cls:77-118` — every write route today is over OcuPilot's own state except `POST /account/password`, which AD-49 carves out as the user's own action on their own account, outside the write path and outside any port. The three new routes go in the family order the REST convention requires (sub-resource before single-segment).

**Client:**

- `ui/src/app/areas/agent/definition-form.page.ts` — the page shape. `generation = signal(0)` :501, subscribe-bump :509-516, `DestroyRef.onDestroy` :525-534; error summary `role="alert" tabindex="-1"` :97-114; `fieldView()` :1077 composing `aria-invalid`/`aria-describedby`; `afterRefusal()` :1054 → `focusRefusal()` :1068 (summary, then first invalid field, via `afterNextRender` — not `queueMicrotask`, reasoning at :1047-1052); sticky bar :433-456; leave dialog :459-469, `answerLeave()` :1034; create→edit URL replacement `onSave` :967-981, `editorUrl` :1097, `idFromUrl` :1103.
- `ui/src/app/areas/agent/definition-form.store.ts` — buffer, `violations()` :293, `dropStaleViolation` :541, `save()` :563, `outcome()` :350, `retainAcrossRouteReplacement()` :378, `inject(FormDirty)` :162.
- `ui/src/app/areas/agent/definition-actions.ts:65-71` — the tab-scoped Create handler, root-provided, constructed from `ui/src/app/app.ts:220`, registering for the life of the tab. The exact template for this story's handler, and the reason DW-246's NG0100 half does not arise.
- `ui/src/app/core/form-dirty.ts:30` — `setDirty` :60, `requestLeave` :78, `answer` :95, `reset` :114. No registration API: `ui/src/app/app.routes.ts:24` attaches `leaveFormGuard` to every `archetype === 'form-page'` route (:27, :72-76). `ui/src/app/shell/agent-navigator.ts:97-108` honours the same answer.
- `ui/src/app/core/screen-actions.ts:84` — `register` :95 (notifies synchronously at :103), `has` :115, `run` :121; `ACTION_LABELS.create = STRINGS.actionCreate` :63.
- `ui/src/app/shell/command-bar.ts:484-489` — renders the primary action only when the descriptor declares an id **and** a handler is registered; click at :786. `:455` is the subscription whose signal write is DW-246's NG0100 surface.
- `ui/src/app/shell/screen-outlet.ts:59` `ARCHETYPE_PAGES['form-page'] = DefinitionFormPage`; `:86` `DESCRIPTOR_PAGES` is the per-descriptor override, resolved first — the seam this story uses.
- `ui/src/app/core/change-bus.ts:40` — `ChangeAction` already includes `'created'`; `publish()` :133 validates the triple. `ui/src/app/core/refresh.ts:242` is the bus's only subscriber and re-fetches the bound list at :613, so the list updates from one publish and nothing else.
- `ui/src/app/shell/list-page.ts:132` registers Refresh page-scoped; `:158-168` is the `<route>/:id` pending-selection path.
- `ui/src/styles/_metrics.scss:56-59` — `--ocu-form-max-width: 720px`, `--ocu-field-max-width: 480px`, `--ocu-form-bar-height: 56px`. `ui/src/styles/_components.scss:2840-3022` is the whole `form-page` block. **`ui/tools/design-tokens.test.mjs` pins neither width — that is the gap AC4 closes.**
- `ui/browser/classic-link-card.browser-spec.mjs:173-224` — the geometry idiom: one `page.evaluate()` returning measurements, reading a CSS custom property off `document.documentElement` and comparing it to a `getBoundingClientRect()`, with an assertion that the token is non-zero so the test cannot compare 0 to 0.
- `ui/browser/definitions.browser-spec.mjs` — the form spec shape; `browser.config.mjs`, `shell-entry.mjs`, `preferences-reset.mjs`, `list-spec.mjs` are the harness.

**Rosters that redden:**

- `ui/tools/navigation.test.mjs:157-159, :246-251` — the web-applications listed/built route literals and the prose count.
- `src/OcuPilot/Test/SurfaceCoverage.cls` `XData Coverage` — the write half is derived from `Registry.ListTools()`; a new tool needs a row.
- `src/OcuPilot/Test/EndpointCoverage.cls` `XData Probes` — a row per new REST route.
- `src/OcuPilot/Test/ToolWrite.cls:868-881` — `IsMutating`/`IsBodyless` per tool and the exact-length equality at :878. `tReached` de-duplicates, so a second tool on `WebApp.App/PUT` keeps it green; :881 asserts exactly one shipped write uses another port.
- `src/OcuPilot/Test/Prohibited.cls:292` (no write tool admits an always-prohibited field) and `:395` (`UncoveredWriteTools()` empty).
- `ui/tools/strings.test.mjs:533`/`:557` — forward and reverse set equality against EXPERIENCE.md's Fixed strings table.

## Tasks & Acceptance

**Execution:**

*The create write kind:*

- `src/OcuPilot/Screen/Tool/Write.cls` -- add `Parameter CREATES = 0` and `ClassMethod Creates() As %Boolean`; replace the `CHANGEACTION` doc-comment sentence at :119 that asserts no shipped tool can be a create -- so the declaration and its documentation agree.
- `src/OcuPilot/Kernel/Proposal/Mint.cls` -- add a `CreatesOf(pToolClass)` seam beside `ReadTypeOf` :437; for a create, invert the acceptance of the fresh read (404 proceeds, an object refuses 400 `TOOL.ARGUMENTS` naming the id argument); add a private `Compose()` that builds the payload from the arguments over `SettableFields()` instead of `Merge()`, with every supplied field a diff row against empty and `tUnchanged = 0`; add `AbsenceState(pPresent)` as the **one** producer of the `%DynamicObject` the create's fingerprint is taken over -- so the mint and the confirm cannot disagree about its shape.
- `src/OcuPilot/Kernel/Proposal/Confirm.cls` -- branch `FingerprintMatches` :630-655 for a create: the re-read's outcome becomes `Mint.AbsenceState(present)` and is digested and compared unchanged, so a name taken since the mint reaches the existing `REASONTARGETCHANGED` close and 409 rather than `pMatches = 0` -- reusing the refusal path instead of adding one.
- `src/OcuPilot/Kernel/Proposal/Prohibited.cls` -- add `PermittedCreateFields(pType)`; make the absent-target early-out at :380-383 conditional on the tool not being a create, and evaluate the create predicates instead (`ServesOcuPilot` on the intended path; `MatchRoles` present; any field outside the create list as `UNCOVEREDFIELD`) -- because a create's target is *correctly* absent and the fingerprint no longer refuses it.

*The tool and its derived schema:*

- `src/OcuPilot/Screen/Tool/WebAppCreate.cls` -- new: `TOOLNAME = "webapp.list.create"`, `DESCRIPTORCLASS = OcuPilot.Screen.Descriptor.WebAppList`, `CREATES = 1`, `CHANGEACTION = "created"`, `Endpoint() = "WebApp.App"`, `SettableFields()` → `..AdmittedFields()`, `ExcludedFields()` → `MatchRoles`, `PERMITTEDFIELDS = "AutheEnabled,Description,DispatchClass,Enabled,NameSpace,Recurse,Resource,WSGIAppLocation,WSGIAppName,WSGICallable,WSGIType"`, `WRITERESOURCE = "%Admin_Secure"` at `USE`, and `PrivilegePairs()` copied from `WebAppUpdate.cls:100` including its `$ListFind` guard.
- `src/OcuPilot/Screen/Tool/Classification.cls` -- append a `webapp.list.create` entry over the existing `WebApp.App` field list, classifying every classifiable row; no new derivation is needed because `FieldLists.cls:505` already carries it.
- `src/OcuPilot/Screen/Tool/ToolFields.cls` -- regenerate with `node tools/field-lists.mjs` and commit; never hand-edit.

*The screen and its routes:*

- `src/OcuPilot/Screen/Descriptor/WebAppList.cls` -- set `primaryAction.id = "create"` and swap `table.emptyNextKey` for a new `emptyAgentKey`, because `Screen/Registry.cls:1897-1903` enforces the two as a pair once a descriptor is write-capable.
- `src/OcuPilot/Screen/Descriptor/WebAppForm.cls` -- new `form-page` descriptor: `route: "web-applications/list/edit"`, `sideBarPosition: 0`, `built: true`, `refreshes: false`, `id: {"kind":"single","parts":[]}`, `entityType: "web-application"`, `scope: "instance"`, privileges `%Admin_Secure:USE` + `%DB_IRISSYS:READ`, `classicPage: "%CSP.UI.Portal.Applications.Web"`, `classicLinkExemption.exempt: false`, `toolIdentifier: "webapp.form"`, no `read`, no `table` -- the route `editorScreenFor` (`ui/src/app/core/navigation.ts:177`) already resolves for this list.
- `src/OcuPilot/Area/WebApp/Create.cls` -- new: the one operation both callers use. It resolves `WebAppCreate` for the endpoint, request type, settable fields and payload composition, evaluates `Prohibited.Prohibits` before the port is touched, derives `Path` from `WSGIAppLocation` for a WSGI/ASGI create, and invokes the port -- so the screen's Save passes AD-10 exactly as the confirm does.
- `src/OcuPilot/Api/Router.cls` -- add `GET /web-applications/form`, `GET /web-applications/name` and `POST /web-applications` with thin `Call=` wrappers, sub-resource routes before the single-segment one per the REST ordering convention.
- `src/OcuPilot/Area/WebApp/FormRules.cls` -- new: the form bootstrap read. It answers the authentication methods the instance itself has enabled (`Security.System.AutheEnabled` intersected with `$$$CSPApplicationValidAuthe`), the required-field set, the per-field maximum lengths, and the **server-authored sentence for every field rule** -- the `keyShapeReason` precedent, which is what makes inline-on-blur reachable with no second copy source.
- `src/OcuPilot/Api/Error.cls` -- add the create's field-level reasons beside the existing envelope reasons, emitted as AD-39 `detail.violations[]` rows `{field, code, reason}`; map the vendor's `params[0]` (dotted, `MatchRoles[0].MatchRole` for nesting) onto `field` at the port boundary so a vendor refusal lands on the field it names.

*Client:*

- `ui/src/app/areas/web-applications/create-form.page.ts` -- new: the form-page. Fields in the classic order (name, description, namespace, enable, type, the type's own fields, resource, authentication methods); Material outlined fields with the label above and helper text beneath; the asterisk and `STRINGS.formRequiredFieldsLegend`; the error summary, focus choreography and sticky bar copied from `definition-form.page.ts` :97-114, :1054, :1068, :433-456.
- `ui/src/app/areas/web-applications/create-form.store.ts` -- new: buffer, `FormDirty` delegation, violations, `save()`, and the create→edit route replacement modeled on `definition-form.store.ts`.
- `ui/src/app/areas/web-applications/web-app-actions.ts` -- new: the tab-scoped `create` handler on `WebAppList`, the `DefinitionActions` shape, with a doc comment saying why it is tab-scoped rather than page-scoped (DW-246).
- `ui/src/app/shell/screen-outlet.ts` -- add the `DESCRIPTOR_PAGES` entry for `WebAppForm`, so the new descriptor does not fall through to `DefinitionFormPage`.
- `ui/src/app/app.ts` -- construct `WebAppActions` beside `DefinitionActions` at :220, so the handler exists before the first change-detection pass.
- `ui/src/app/core/strings.ts` -- **APPEND ONLY**, a `// Story 8.1` block immediately before `} as const;`; one `key: 'value',` per line, `\uXXXX` escapes for any non-ASCII byte. Never reorder or reflow.
- `ui/src/styles/_components.scss` -- **APPEND ONLY** if a rule is genuinely needed, as a new `// --- ... (Story 8.1) ---` banner after the last line. Prefer the existing `form-page` block at :2840-3022 and add nothing.
- `ui/src/app/core/screens.generated.ts` -- regenerate with `node tools/screen-mirror.mjs`; never hand-edit.

*Planning artifacts (AC4's binding half):*

- `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md` -- add a Fixed strings row for every new key, because `strings.test.mjs:557` holds the table and `strings.ts` set-equal in both directions.
- `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/DESIGN.md` -- replace the `[ASSUMPTION]` marker on the two widths at `:896`, `:963` and `:1064` with the confirmed figures, and do the same to the UX-DR80 roll-up row at `epics.md:491`. Delete the assumption wording; do not append a paragraph about it.

*Tests and rosters:*

- `ui/tools/design-tokens.test.mjs` -- pin `--ocu-form-max-width: 720px` and `--ocu-field-max-width: 480px`; this is what makes the confirmed figures bind every later form in Epics 8 and 9 rather than being a measurement taken once.
- `ui/browser/web-applications-create.browser-spec.mjs` -- new; `resetRememberedState()` before each context (`browser-reset.mjs` fails the build otherwise). Covers AC1, AC2, AC3, AC4 and DW-246.
- `src/OcuPilot/Test/ProposalCreate.cls` -- new, ≤500 lines: the create write kind against the port. Mint refuses a present name; mint proceeds on a 404; the payload is the arguments and `unchangedCount` is 0; confirm matches the absence fingerprint; confirm refuses 409 `PROPOSAL.TARGETCHANGED` when the name was taken since the mint; two spellings of one name are one target; two live creates of one name serialize and the sibling is canceled.
- `src/OcuPilot/Test/WebAppCreate.cls` -- new, ≤500 lines: the tool's schema excludes `MatchRoles`, its permitted set equals `Prohibited.PermittedCreateFields("web-application")`, `AutheEnabled` is required, `Path` is derived and not settable, and the screen route and the tool produce the same payload from the same arguments.
- `src/OcuPilot/Test/Prohibited.cls` -- add the create legs: `UncoveredWriteTools()` stays empty with a non-zero floor; a create at OcuPilot's own path is refused; `MatchRoles` is refused on a create; a field outside the create list is `UNCOVEREDFIELD`.
- `src/OcuPilot/Test/SurfaceCoverage.cls` -- add the `webapp.list.create` row.
- `src/OcuPilot/Test/EndpointCoverage.cls` -- add a probe row per new REST route; this omission was Story 15.3's sole high finding.
- `ui/tools/navigation.test.mjs` -- update the web-applications route literals at :157-159 and :246-251, the prose count, and add the `isListedScreen(...) === false` leg for the unlisted form.
- `scripts/ci-throwaway.sh` and `ui/tools/ci.test.mjs` -- update the `# classes:` arming roster **only if** a new `OcuPilot.Test.*` class declares an arming parameter; the two are held equal in both directions.

**Acceptance Criteria:**

- Given the create form, when it renders, then it captures type (CSP, REST, WSGI or ASGI), namespace, dispatch class, resource and authentication methods, in the classic order, and the type control shows only the fields its type uses.
- Given a valid Save, when the server accepts it, then the application is created with `AutheEnabled` sent explicitly, the route is replaced with `web-applications/list/edit/<id>`, the created application is loaded, and `STRINGS.formSaved` reads in the sticky bar's caption slot.
- Given the Web applications list, when its command bar renders, then Create is offered, runs exactly once per click, survives navigating away and back, and raises no `ExpressionChangedAfterItHasBeenCheckedError` in the console (DW-246).
- Given the create form over a validating endpoint, when a field is blurred, then the rule's sentence comes from the form's own bootstrap read and no validate-only route exists or is added (DW-376).
- Given the shipped `form-page` tokens, when the create form is rendered at the longest label and the longest value, then the measured column width equals `--ocu-form-max-width` (720px), the measured field width equals `--ocu-field-max-width` (480px), the longest label renders on one line without clipping, a longer value scrolls inside the input rather than widening the field, and both tokens are pinned by `design-tokens.test.mjs` so every later form in Epics 8 and 9 inherits the confirmed figures.
- Given `webapp.list.create` in the registry, when the agent proposes a create and the user confirms it, then the write is marked with an audit event, a ledger row records the fields actually sent, and a `created` change event reaches the list.
- Given any caller, when `MatchRoles` is supplied or the intended path serves OcuPilot, then the write is refused on the instance inside the atomic transition.

## Spec Change Log

## Review Triage Log

## Design Notes

### Governing architecture decisions

AD-1 (in-process), AD-2 (the vendor endpoint through `AdminPort`), AD-3 (derived field list, reviewed classification), AD-4 (complete property set; a create composes rather than merges), AD-5 (one descriptor per screen; write-capable by declared action), AD-6 (server-minted, fingerprinted, single-use, closed confirm channel), AD-8 (privilege pairs, administrative resource at `USE`), AD-10 (prohibited by effect, one home, evaluated at the write), AD-12 / AD-39 (one envelope; `detail.violations[]` carries `{field, code, reason}`), AD-13 (one percent-encoded segment; the canonical spelling rule decides identity), AD-14 (one change event; screens re-fetch, never patch), AD-15 (agent marker), AD-19 (zoneless, OnPush, store-owned state), AD-27 (the admin API confined to the port), AD-34 (one atomic transition, per-target lock, sibling cancel), AD-36 (one declared read), AD-40 (confirm is user-originated; every gate is on the write), AD-44 (the classic page key), AD-49 (the self-service carve-out this story is *not* — a web application is nobody's own account, so the screen's Save stays on the write path), AD-51 (the action-style write, whose inverted fingerprint is this decision's precedent), AD-52 (the tool declares its port).

### `SPINE DECISION NEEDED:` the create write kind

**Proposed Rule.** A write tool declares whether it **creates** its target, defaulting to false. A create write reaches its target through the same declared port, the same endpoint and the same read type as any other write, and changes exactly two things. First, the mint's fresh read keeps its place and **inverts its acceptance**: the target must be absent, a 404 is the success precondition, and a present target refuses the mint. Second, the fingerprint covers **the target's absence under AD-13's canonical spelling**, not a property set — for a create the property set is entirely the caller's own arguments and nothing about it can move, while what must be protected is that the name is still free. Confirm re-reads and refuses `PROPOSAL.TARGETCHANGED` when the name has been taken since the mint. The payload is composed from the caller's arguments over the endpoint's derived field list rather than merged over a fresh read, so every supplied field is a diff row and the unchanged count is zero. `TargetRef` carries the canonical intended name from the mint, so AD-34's per-target lock and sibling cancel, AD-15's marker and AD-41's ledger row are unchanged. `CHANGEACTION` is `created`.

This is AD-51's move applied one step further: AD-51 inverted *what the fingerprint covers* for a write that sends no body; a create inverts *what the fresh read must find*. AD-6's purpose survives both inversions intact, because what it prevents is a write against state that moved under the reviewed diff — and for a create the reviewed state is "this name is free".

Why the protection is load-bearing rather than ceremonial: `%Api.Admin.Endpoints.WebApp.App:RunPut` calls `Security.Applications.Exists` and falls through to `Modify` when the name is taken, returning 200 instead of 201, with **no refusal path**. Without the absence fingerprint a confirmed create silently rewrites whichever fields it sends on somebody else's application.

### `SPINE DECISION NEEDED:` the prohibited set's field lists are keyed by create versus change

**Proposed Rule.** `PermittedChangeFields` and `AlwaysProhibitedFields` answer "what may a change to a live target touch". A create has no prior state, so it carries its own reviewed per-type list, and the absent-target early-out in `Prohibits` — which today reasons that the fingerprint re-read will refuse an absent target moments later — does not apply to a create tool, whose target is correctly absent. `MatchRoles` stays prohibited on both paths, because AD-10 names setting application roles on **any** web application unconditionally. `DispatchClass` is prohibited on a change and permitted on a create: DW-1207's owner decision is about repointing a *serving* application at arbitrary compiled code, and a create repoints nothing — it is also what makes a REST application a REST application, which this story's first acceptance criterion requires. Creating at a path that serves OcuPilot is refused by the existing `ServesOcuPilot` predicate.

### `SPINE DECISION NEEDED:` a screen's own Save against an instance object resolves through the tool

**Proposed Rule.** This is the product's first screen-side write against an instance object **through a port**, and therefore the first one that has to pass AD-10's prohibited set. The only other screen-side instance write is `POST /account/password`, which AD-49 places deliberately outside the write path as the user's own action on their own account. The screen's Save and the agent's confirm are two callers of **one tool class**: the route resolves the tool for its endpoint, request type, settable fields and payload composition, and evaluates the prohibited set before the port is touched. The screen mints no proposal and takes no confirm token; it inherits every gate AD-10 and AD-40 place "at the write". A screen path that composes its own payload or names its own endpoint is a second source for the thing AD-5 and AD-3 exist to keep single.

The lead claims the `AD-n` ids and writes the spine entries at the spec gate (Rule 20); nothing here edits the spine.

### DW-246 — addressed

The `create` handler is registered **tab-scoped**, from `app.ts`, on the `DefinitionActions` precedent (`definition-actions.ts:65-71`). That is the cheapest correct resolution: `ScreenActions.register()` notifies synchronously (`screen-actions.ts:103` → `:136`), `CommandBar` subscribes at `command-bar.ts:455` and writes its own `generation` signal, and its template reads that signal through `hasPrimaryAction` (`:484-489`) — so a handler registered from a routed page's constructor writes a signal an already-checked OnPush sibling depends on, in the same change-detection pass. Registering before the first pass removes the shape entirely. The "outlive its page" half is already settled convention: nine shipped sites register page-scoped and tear down through `DestroyRef`, and `takeUntilDestroyed` is used nowhere. The browser spec pins both halves of the entry's evidence line — navigate away and back, Create present each time, exactly one run per click, no NG0100 in the console — without contorting the registration into the shape that causes the bug.

### DW-376 — addressed, and no validate-only route is added

The admin API publishes **no** validate-only operation: all 305 paths of the live v1 spec were searched and the only validate-style routes are for license keys, SSL and LDAP configurations and journal/database integrity. `ValidateRequest` and `ValidateSemantics` are internal dispatch hooks with no route of their own. So one would have to be written, and it would buy nothing here, for two reasons read off the instance rather than assumed. The vendor's shape layer produces exactly four field-level refusals, of which only `MissingRequestBodyField` and `UnexpectedRequestBodyField` are reachable from a form over a fixed field list — and the first is required-ness, which is declarative (`aria-required` plus the asterisk and the published legend), not a sentence. The classic portal's own "Required." hints on Name, Dispatch Class and WSGI Application Name are client-side only, with no server counterpart at all.

What DW-376 actually needs is a way to hand the client a **server-authored sentence** without a save, and the shipped precedent for that is `keyShapeReason` travelling on `GET /agent/providers`. So the rules and their sentences ship with the create form's own bootstrap read, authored once on the server. The one rule that is not a shape rule — the name is already taken — is a **read**, not a validation, and goes through `GET /web-applications/name`; it also matters more than the rest, because the vendor's PUT is an upsert and a taken name is the difference between a create and overwriting somebody's application.

### Consumes

- Story 5.1-5.5 — the proposal mint, fingerprint, atomic confirm, prohibited set, audit marker and ledger; `webapp.list.update` as the write-tool precedent.
- Story 6.x — `WebAppList`, its declared read, its gate, `ListPage`, the command bar and the change-event bus.
- Story 3.5 — the Definition form, `FormDirty`, the `form-page` archetype guard, the error-summary and focus choreography.
- Story 2.2 — the build-time field-list derivation; `FieldLists.cls:505` already carries `WebApp.App`.

### Consumed-by

- Story 8.2 (create a user), 8.3 (create a role), 8.4 (the resource editor), 8.5 (X.509 import), 8.6 (the wallet secret form), 8.8 (the device editor) — each is a create over the same write kind and the same `form-page` contract, and each adds its own entity type's canonical-spelling rule.
- Epic 9's six large editors — they extend this contract into tabs and take over the `web-applications/list/edit/:id` route.
- The confirmed 720px and 480px figures bind every form in both epics through `design-tokens.test.mjs`.

### Integration AC

The Integration AC is the third acceptance criterion: the Web applications list is the consumer, it reads nothing of this module's internals, and its observable effect is that the row appears without a manual refresh — driven by one `ChangeBus.publish`, with `RefreshService` (`refresh.ts:242`, `:613`) as the bus's only subscriber.

### Where "the classic order" lives

No project artifact captures it. The authority is `%CSP.UI.Portal.Applications.Web`'s `XData contentPane`, read from the instance: name, description, namespace (with the default-application checkbox), enable, the type radio group with its own sub-fields, then Security Settings (resource, group-by-ID, authentication methods, permitted classes), Session Settings, CSP File Settings and Custom Pages. Create and edit share one page and therefore one order, so what this story records binds Epic 9's editor too. The acceptance criterion's five fields are positions 1, 4, 6 and 7 of that order, not an order of their own.

### Two things settled on the instance that would otherwise be guessed

`Type` is hard-coded to `$$$AppTypeCSP` by the endpoint and refused in the body, so the four-way type choice is a form control over a combination of other fields, and the list's `Type` column can never read "REST". `WSGIType` travels as its **display** string (`"WSGI"` / `"ASGI"`), not the integer, because the endpoint runs `WSGITypeDisplayToLogical` over it — as it does for `ServeFiles`, `UseCookies`, `SessionScope` and `UserCookieScope`.

### For the spec gate

Whether creating an application that is reachable unauthenticated should join AD-10's prohibited set for the agent path is DW-1207's question one step on, and this story does not answer it: it closes the *default* (at least one method is required and `AutheEnabled` is always sent explicitly) without prohibiting a choice a `%Admin_Secure` holder may make through the screen. It is a ledger candidate, not a silent omission.

## Verification

**Targeted (loop) — inside the implement stage, on every pass:**

- `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/` -- expected: the bundle the spec will actually load is the one just built. A browser result read without this proves nothing.
- `cd ui && OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci node --test --test-concurrency=1 browser/web-applications-create.browser-spec.mjs` -- expected: all tests pass.
- `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.ProposalCreate` -- expected: 0 failures. **One test class per tool call; wait for it to land before the next.**
- `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.WebAppCreate` -- expected: 0 failures.
- `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.Prohibited` -- expected: 0 failures.
- `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.ToolWrite` -- expected: 0 failures, including the `MUTATINGTYPES` exact-length equality at :878.
- `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.SurfaceCoverage` -- expected: 0 failures.
- `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.EndpointCoverage` -- expected: 0 failures.
- `cd ui && npm run test:tools` -- expected: 0 failures, including `design-tokens`, `navigation`, `strings` and `screen-actions`.
- `cd ui && npm run test:components` -- expected: 0 failures.
- `cd ui && node tools/screen-mirror.mjs --check && node tools/field-lists.mjs --check && node tools/classic-links.mjs && node tools/client-lint.mjs && node tools/browser-reset.mjs` -- expected: no drift reported by any checker.
- `uv run scripts/check-objectscript.py <changed paths>` -- expected: no findings.
- `bash scripts/lint-docs.sh` -- expected: clean, for the DESIGN.md and EXPERIENCE.md edits.

**Full sweeps (once, before `dev_complete`):**

- The full ObjectScript sweep on a **fresh** throwaway brought up after the last edit, per class, aggregating the totals and verifying them against `%UnitTest_Result` -- expected: 0 failures, and a non-zero executed count.
- `cd ui && npm run build && npm test` -- expected: green, all seven prebuild checkers included.
- `bash scripts/smoke.sh --container ocupilot-slot-b --user _SYSTEM --password SYS` -- expected: all checks pass; zero executed checks is a failure, never a pass.

The **full browser suite is deliberately not run locally** (owner instruction 2026-09-22, Rule 29): CI runs it in its own `browser` job against a fresh throwaway, and DW-1447 measured the suite non-idempotent on a reused container, so a local run is a less trustworthy duplicate of a more reliable gate.

**Pinning tests and their mutations (Rule 19 — the implementer writes each `mutation:` line beside its test):**

| Acceptance criterion | Pinning test | Mutation to apply |
|---|---|---|
| The form captures the field set in the classic order | `web-applications-create.browser-spec.mjs`, the field-roster test | Remove the authentication-methods field from the template |
| A server refusal lands on the field it names | the same spec's failed-Save test | Drop `params[0]` when mapping the vendor status onto `detail.violations[].field` |
| The list reflects the change without a refresh | the same spec's create-then-return test | Remove the `ChangeBus.publish` call from the create store |
| 720px and 480px confirmed | the same spec's geometry test, plus `design-tokens.test.mjs` | Change `--ocu-form-max-width` to 640px in `_metrics.scss` |
| Create runs once per click, no NG0100 | the same spec's command-bar test | Move the handler registration into the page constructor |
| A name taken since the mint is refused | `ProposalCreate.cls` | Return the stored digest unchanged from the create branch of `FingerprintMatches` |
| `MatchRoles` is refused on a create | `Prohibited.cls` | Add `MatchRoles` to `PermittedCreateFields("web-application")` |

## Auto Run Result

Status: ready-for-dev
Blocking condition: none

Planned only; the invocation directed a halt after planning. Nothing was implemented and the spec
is left uncommitted for the lead's validation gate. Three `SPINE DECISION NEEDED:` lines under
`## Design Notes` await the lead's `AD-n` ids (Rule 20). Both routed ledger entries are addressed
rather than declined: DW-246 by a tab-scoped handler plus a browser spec that pins its evidence
line, DW-376 by server-authored field rules on the form's own bootstrap read, with the admin API's
absence of any validate-only route settled against the live spec.
