---
title: 'Story 3.5: The Definition form'
type: 'feature'
created: '2026-09-15'
status: 'blocked'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md'
  - '{project-root}/_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/DESIGN.md'
warnings: ['oversized', 'multiple-goals']
deferred: []
---

<intent-contract>

## Intent

**Problem:** Epic 3 shipped eight agent-definition routes and nothing that drives them.
`ui/src/app/areas/` holds `home` and `logs`; no `form-page` archetype page exists, no screen has ever
read OcuPilot's own protected state, and the client has never issued a write of any kind. Six routed
ledger entries and two ledger-only ones are all waiting on this surface.

**Approach:** Two descriptors in the `agent` area — a Definitions list served by `ListPage` over a new
descriptor read source that reads OcuPilot's own state, and a Definition form served by a new
`form-page` archetype page. A framework-free store owns the edit buffer, the dirty flag and the
per-field violations; one `CanDeactivate` guard on the form route answers the unsaved-changes
question for every caller, because every programmatic navigation in this client already goes through
`Router.navigateByUrl`. Refusal copy is server text throughout: the envelope's `reason` for
envelope-level codes, and a new per-violation `reason` beside `field` and `code` for the field-level
ones.

## Boundaries & Constraints

**Always:**

- **Render from the response body, never from what was sent.** A `PUT` carrying `enabled: true`
  together with a changed security field answers **200** with `enabled: false` — `AgentRules.Validate`
  runs against the *stored* `connectionVerified` and passes, then `Agent.GuardedUpdate` clears both
  flags. Sending state and then rendering it would show an enabled definition that is disabled.
- **The key is write-only.** No route returns it, the field is never pre-filled, pastes are not
  trimmed, and the field is empty after a save under the published `Stored.` caption.
- **Every refusal sentence the form renders is server text** — the envelope's `reason`, or a
  violation's own `reason`. `strings.ts` carries no per-code copy; `ui/tools/strings.test.mjs` would
  refuse it, and AD-39 assigns the human half to the server anyway.
- The two descriptors declare `"classicPage": ""` with `classicLinkExemption.exempt` false — AD-44's
  explicit way to say a screen has no classic equivalent — and `refreshes: false` (AD-43).
- Non-ASCII is authored as `\uXXXX` (Rule 14); every template text node is `{{ STRINGS.key }}`; every
  `@if` condition is a paren-free member reference (`client-lint.mjs` blanks templates and a call
  expression defeats it).
- One `iris_execute_tests` call per message, and never a re-submit on a client-side timeout.
- Every IRIS MCP call passes `server: "ocupilot-iris"`.

**Never:**

- **No real outbound provider call, planned or made.** Test connection is exercised through
  `OcuPilot.Test.ProviderStub`, never against a paid API.
- **Nothing is created on the live `ocupilot` container** — no principal, credential entry, SSL
  configuration, definition, audit change or `^ERRORS` write. It holds zero `OcuPilot`-named
  credential entries and zero definitions; it stays that way. Browser work runs against the
  `ocupilot-ci` throwaway on 52776 (`sh scripts/ci-throwaway.sh up|down`).
- Never send `enabled: true` on a create — the server forces `connectionVerified` to 0 and the rule
  refuses it.
- Never switch on the envelope's `code` to find a field-level violation: every one of them arrives
  under `code: "AGENT.VALIDATION"` with the real code in `detail.violations[].code`.
- Never populate the form from `GET /agent/definitions` — that list is a fixed six-key projection for
  every caller, not a narrowed full object.
- No per-user read-only affordance, no second provider, no retention enforcement (spine `## Deferred`).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Create, no key | Form on `agent/definitions/new`, Save | `POST /agent/definitions` without `enabled`; 201; route replaced with the new id's editor; sticky bar `formSavedPendingTest` | No error expected |
| Create, key present, Test connection pressed | Gate landing: Anthropic selected, key pasted, Test connection | `POST` (disabled) → `POST :id/credential` → `POST :id/test`, one progress indicator across all three, URL replaced with the new id | Any step's fault renders under the button and the sequence stops there |
| Test succeeds | 200 `{connected, reply, replyTruncated, latencyMs, connectionVerified, testedAsStored}` | `formTestConnectionResult` with `reply`, `role="status"`; the row is re-read with `GET :id` | No error expected |
| Test succeeds after a security-field edit | 200 with `connectionVerified: true`, `testedAsStored: false` | The connect sentence renders; `connectionVerified` from the test body is **ignored**; the sticky bar keeps `formSavedPendingTest` | **DW-359** |
| Test refused by the provider | 502 `PROVIDER.REFUSED` with `detail.providerText` | `formTestConnectionFailure` with `<text>` resolved | **DW-355** |
| Test refused any other way | Any of the other eight `PROVIDER.*` codes, or `REFUSED` without text | The envelope's `reason`, verbatim | **DW-355** |
| Save with violations | 422, `detail.violations[]` | Error summary banner takes focus, one link per violation; each named field takes `aria-invalid` and its violation's `reason` via `aria-describedby`; first invalid field focused | **DW-339**, **DW-366** |
| Credential name over 50 characters | `credType: "creds"`, 51+ characters, Save | 422 `AGENT.CREDNAME.LENGTH` on `credentialName`, before any store attempt | **DW-344** — previously a 500 at store time |
| Store a key against an `env` definition | `POST :id/credential` | 422 `AGENT.CREDENTIAL.ENVUNWRITABLE` on `apiKey`; the caption explains the operator sets the variable on the host | No key is written |
| Navigate away while dirty | Any `navigateByUrl` to another route | `formLeaveWithoutSaving` confirmation; decline resolves the navigation `false` and the form stays | **AC2** |
| Set default onto a disabled definition | Row action on the list | 422; envelope `code: AGENT.VALIDATION`, `detail.violations[0]` = `default` / `AGENT.DEFAULT.DISABLED` with its `reason` | **DW-366** |
| Non-administrator opens the area | `OcuPilotAdmin:USE` refused | Rail item ungated with its attention dot; both side-bar entries gated, naming `OcuPilotAdmin:USE` | **AC5** |

</intent-contract>

## Code Map

**Server — what the form drives (read; do not re-derive).**

- `src/OcuPilot/Api/Definitions.cls` — eight routes. `Fields()` **:79** is the closed writable set (15
  wire names); `FullProjection` **:903**; `SelectionProjection` **:923** (six keys, ungated list);
  `MergeBody` **:853** silently drops an unknown key, an object/array value, and a boolean sent as a
  string; `HandleCreate` **:194** forces `connectionVerified` 0 and applies `ApiCatalogDefaults`
  **:875** only for keys the body omitted; `HandleUpdate` **:254** has no catalog fallback;
  `ViolationsJson` **:322** emits `{field, code}` — the shape this story extends;
  `CredentialRefusal` **:643** (four codes, in order, on field `apiKey`);
  `HandleSetDefault` **:346** (`AGENT.DEFAULT.DISABLED`); `ConnectionOutcome` **:590** (the test 200
  body; `tVerified` **:560** is the stored flag — DW-359); `GuardedClearVerification` at **:420**
  clears `ConnectionVerified` **and** `Enabled` when a key is stored.
- `src/OcuPilot/Api/Error.cls` — every `code` and every published `reason`, including the nine
  `PROVIDER.*` reasons. This is where refusal copy already lives; the new violation sentences join it.
- `src/OcuPilot/Kernel/AgentRules.cls` — `Normalize` **:53**, `Validate` **:104**. Seventeen codes,
  accumulated, never short-circuited. Only `name` (64) and `systemPromptOverride` (8192) have length
  rules; `credentialName` has none — DW-344.
- `src/OcuPilot/Kernel/State/Agent.cls` — MAXLENs (`Model` 128, `EndpointUrl` 512, `EnvVarName` 128,
  `CredentialName` 128, `ReadOnly` **InitialExpression 1**); `SecurityFields()` **:127** is the six
  whose change clears both flags in `GuardedUpdate` **:186**; `GuardedList` **:297** orders by ID;
  `GuardedRebalanceDefault` **:403**.
- `src/OcuPilot/Kernel/Provider/Catalog.cls` **:52** — the only shipped row. `label`, `defaultModel`,
  `modelSuggestions`, `defaultEndpoint`, `endpointRequired`, `canonicalMaxTokens`,
  `canonicalTemperature`, `defaultEnvVarName`, `defaultCredentialName`, `keyPrefix` (`sk-ant-`),
  `allowsLocal` false. **No route serves it to a client.**
- `src/OcuPilot/Kernel/Provider/Base.cls` **:160, :208, :221** — `tProviderText` is assigned at one
  site only, inside the non-retryable branch, whose code is always `PROVIDER.REFUSED`. DW-355 verified.
- `src/OcuPilot/Test/AgentConnection.cls` **:473**, **:502** — the two legs of DW-365. Each asserts
  `PROVIDER.CREDENTIAL`; on an instance without the `OcuPilotProvider` SSL configuration the port
  answers `PROVIDER.TLS`, also 503, so the status assertion passes and the code assertion fails.
  `src/OcuPilot/Test/AgentWireSecurity.cls` **:20** is the `ARMINGVARIABLE` skip-and-say-so pattern.

**Screen machinery — the seams this story extends.**

- `src/OcuPilot/Kernel/EntityType.cls` **:22** — the closed `TYPES` list. **`agent-definition` is not
  in it**, and `Screen/Registry.cls` **:167** fails a descriptor that names an unknown type.
- `src/OcuPilot/Screen/Read.cls` **:131** — the single read path: `PortClass().Invoke(source.endpoint, …)`,
  an AdminPort endpoint. There is no source kind that reads OcuPilot's own state.
- `src/OcuPilot/Screen/Registry.cls` **:371 `AreaCoverageProblem`** — refuses a screen privilege pair
  the area does not declare. `Screen/Area.cls` **:91** gives `agent` `"privileges": []`, because
  EXPERIENCE.md requires the rail item never to gate. A Definitions screen requiring
  `OcuPilotAdmin:USE` fails this rule as written.
- `src/OcuPilot/Screen/Archetype.cls` **:70** — `form-page` is already in the vocabulary.
- `src/OcuPilot/Screen/Descriptor/SslConfigList.cls` — the 25-key declaration to copy.

**Client — patterns to follow, not reinvent.**

- `ui/src/app/core/api.ts` — one method, `requestJson<T>(path, {method, headers, body: <string>})`;
  `JsonResult` **:107** is `ok | installing | error`, with `detail` an untyped
  `Record<string, unknown>`. `detail.violations[]` is modeled nowhere; the only detail idiom today is
  `error-log.store.ts` **:373** narrowing to `kind === 'error'` and `typeof` -guarding `failedPair`.
  **This is the client's first write caller.**
- `ui/src/app/core/fault.ts` **:69** `classifyFault` — total, and carries no `detail`; a caller that
  needs violations keeps the `JsonResult`.
- `ui/src/app/areas/logs/error-log.store.ts` **:122** — the area-store shape: `@Injectable`, a plain
  subscriber set, `injector.get(ApiService)` on first read, a `generation` counter that drops a late
  answer, `reset()` called from `app.ts` **:318**.
- `ui/src/app/areas/logs/error-log.page.ts` **:220** — the signal mirror: `generation = signal(0)`
  bumped by `subscribe`, every template getter calling it first.
- `ui/src/app/shell/sign-in.ts` **:112** — the only field anatomy that exists: `.ocu-field` /
  `.ocu-field-label` / `.ocu-field-input`, `[attr.aria-invalid]`, `[attr.aria-describedby]`, a masked
  input with a reveal toggle and `[attr.aria-pressed]`, `<p role="alert" class="ocu-form-error">`.
  **`aria-invalid` there is a whole-form boolean, not per-field**, and no `(blur)` handler exists on
  any text field in `ui/src`.
- `ui/src/app/areas/logs/audit.page.ts` **:291** — the `aria-disabled`-not-`disabled` discipline.
- `ui/src/app/shell/screen-outlet.ts` **:41–50** — `ArchetypePages` requires a page for every
  `BuiltArchetypeKey`, so adding `'form-page'` to that union (generated at
  `ui/src/app/core/screens.generated.ts` **:43**) and to `ARCHETYPE_PAGES` is one change, and the
  build fails until both land.
- `ui/src/app/app.routes.ts` **:33** `buildRoutes` — the only place a route is constructed; `path`,
  `pathMatch`, `component`, plus `<route>/:id` when `id.kind !== 'none'`. No guard exists anywhere.
- `ui/src/app/core/navigation.ts` **:209** `withQuery` — every navigation is
  `void router.navigateByUrl(withQuery(route, router.url))`; ten call sites, no other mechanism.
- `ui/src/app/shell/dialog.ts` **:22** — one action only; **the projection slot for a second action
  does not exist**, so a Confirm/Cancel leave dialog needs one added.
- `ui/src/app/shell/side-bar.ts` **:140** — gated entries stay in the roving-tabindex order with
  `aria-disabled`, a resource span, and a TypeScript refusal in `open()`.
- `ui/tools/strings.test.mjs` **:337–364** — `strings.ts` may hold nothing but table literals, seven
  prose extractions and exactly three named extras, and the key count must equal that sum.
- `ui/browser/list-spec.mjs` — `filterToSubset` clears to the whole list first and requires
  `0 < kept < total`; `clickRowCentre` is hit-tested. `viewCount` reads `aria-rowcount`, never DOM rows.

## Tasks & Acceptance

**Execution:**

1. `src/OcuPilot/Kernel/EntityType.cls` -- add `agent-definition` to `TYPES` -- no descriptor can
   declare its entity type otherwise, and without it AD-14's change event has no vocabulary entry.
2. `src/OcuPilot/Screen/Registry.cls` -- teach `AreaCoverageProblem` that an area declaring **no**
   privileges is a never-gating area whose screens gate independently -- AC5 requires exactly that
   pairing, and the rule as written refuses it. Keep the refusal for an area that declares a
   non-empty, non-covering set.
3. `src/OcuPilot/Api/Error.cls` -- add `AGENT.CREDNAME.LENGTH` and one `REASON…` parameter per
   field-level violation code, beside the nine `PROVIDER.*` reasons already there -- one home for
   refusal copy. **(DW-339, DW-344, DW-366.)**
4. `src/OcuPilot/Kernel/AgentRules.cls` -- add the `credentialName` length rule (at most the
   credential entry's `SystemName` length, declared as a parameter with the measured value 50) and
   return each violation's reason -- **(DW-344.)**
5. `src/OcuPilot/Api/Definitions.cls` -- `ViolationsJson` emits `{field, code, reason}`; the four
   credential refusals and `AGENT.DEFAULT.DISABLED` carry theirs -- the one mechanism that gives every
   field-level refusal a sentence. **(DW-339, DW-366.)**
6. `src/OcuPilot/Api/Definitions.cls`, `src/OcuPilot/Api/Router.cls` -- add
   `GET /agent/providers`, gated `OcuPilotAdmin:USE`, projecting each catalog row's `key`, `label`,
   `defaultModel`, `modelSuggestions`, `defaultEndpoint`, `endpointRequired`, `canonicalMaxTokens`,
   `canonicalTemperature`, `defaultEnvVarName`, `defaultCredentialName`, `keyPrefix`, `allowsLocal` --
   the provider cascade and the inline key-shape check both need it, and a hand-copied second table is
   the divergence AD-5 exists to prevent.
7. `src/OcuPilot/Screen/Read.cls`, `src/OcuPilot/Screen/Registry.cls`, `ui/tools/screen-mirror.mjs` --
   add a second declared read source kind for OcuPilot's own state, resolved against a kernel store's
   guarded list, keeping `fields` / `filter` / `sort` / `paging` and the row cap -- so the Definitions
   list and its read tool stay one declared read (AD-36) rather than a bespoke page.
8. `src/OcuPilot/Screen/Descriptor/AgentDefinitionList.cls` -- the list descriptor: route
   `agent/definitions`, area `agent`, archetype `list`, `entityType` `agent-definition`, scope
   `instance`, privileges `OcuPilotAdmin:USE`, `refreshes` false, `classicPage` `""` with
   `exempt: false`, `toolIdentifier` `agent.definitions`, the five columns and the three row actions.
9. `src/OcuPilot/Screen/Descriptor/AgentDefinitionForm.cls` -- the form descriptor: route
   `agent/definitions/edit`, archetype `form-page`, `id.kind` single, no `read`, no `table`,
   `context.secretFields` naming the key so AD-24 can never send it.
10. `src/OcuPilot/Test/AgentConnection.cls` -- make the two DW-365 legs assert the
    `OcuPilotProvider` configuration is present before they claim to test a credential refusal, and
    record a named skip when it is not -- never create one on a live instance. **(DW-365.)**
11. `ui/src/app/core/screens.generated.ts` -- regenerate with `node tools/screen-mirror.mjs`; never
    hand-edit.
12. `ui/src/app/shell/screen-outlet.ts` -- register `'form-page'` in `ARCHETYPE_PAGES`.
13. `ui/src/app/core/form-dirty.ts` -- a framework-free registry of the open form's dirty state and
    its confirmation answer, subscribable like every other `core/` store, so `node --test` pins it and
    the guard and any later agent path read one flag.
14. `ui/src/app/app.routes.ts` -- attach a `CanDeactivateFn` to every `form-page` route; it reads
    task 13 and resolves the confirmation. **(AC2.)**
15. `ui/src/app/shell/dialog.ts` -- add the second-action projection slot the confirm shape needs.
16. `ui/src/app/areas/agent/definition-form.store.ts` -- the edit buffer, the loaded record, the dirty
    flag, per-field violations, the save and test orchestration, `reset()`.
17. `ui/src/app/areas/agent/definition-form.page.ts` -- the `form-page` page: field order above the
    fold, the closed-by-default Advanced disclosure, the masked key field, Test connection, the sticky
    bar, the error summary banner. **(DW-339, DW-340, DW-354.)**
18. `ui/src/app/app.ts` -- inject the new store and call its `reset()` on sign-out, beside the others.
19. `ui/src/app/core/strings.ts` -- add the keys the two new EXPERIENCE.md rows authorize (see
    **Preconditions**); no per-violation-code copy.
20. `ui/src/app/styles/_components.scss` -- the sticky action bar, the Advanced disclosure and the
    per-field error treatment, from DESIGN.md's `form-page` tokens; tokens only, no literal colors.
21. `ui/tools/*.test.mjs`, `ui/src/**/*.spec.ts`, `ui/browser/definitions.browser-spec.mjs` -- the
    three tiers: `node --test` for `form-dirty.ts` and the violation reader, vitest+jsdom for the page
    and the list, and the browser spec for the sticky bar's geometry and a real refused navigation.
22. `src/OcuPilot/Test/` -- wire legs for the new violation shape, the new length rule, the providers
    route and the new read source, one class per concern under the 500-line guidance.

**Acceptance Criteria:**

- **AC1** -- Given the Definition form, when it renders, then name, provider, model, endpoint, the key
  field and Test connection are in the document before the Advanced disclosure, and maximum tokens,
  temperature, maximum iterations, the system-prompt override and retention are inside a disclosure
  whose expanded state is false on first render. Retention is `aria-disabled` under its published
  caption, because nothing enforces it until Story 14.4.
- **AC2** -- Given a form with an unsaved change, when any caller invokes `Router.navigateByUrl` for
  another route, then the guard asks `formLeaveWithoutSaving`, a decline leaves the route unchanged
  and resolves that call's promise `false`, and an accept clears the dirty flag and proceeds. Given a
  failed Save, then the error summary banner receives focus with one link per violation, each named
  field carries `aria-invalid="true"` and its violation's `reason` through `aria-describedby`, and the
  first invalid field is focused.
- **AC3** -- Given Save succeeds on a create, when it completes, then the route is replaced with the
  new definition's editor; on an edit the editor stays and the sticky bar shows `formSaved`, or
  `formSavedPendingTest` when the response body reads `enabled: false`. Given no definition had ever
  been saved before, then the sticky bar also offers `formGoToHome`.
- **AC4** -- Given the Definitions list, when it renders, then it shows name, provider, model, enabled
  and default, and enable, disable and set-default act on the selected row in place, publishing the
  `(agent-definition, instance, id)` change event that re-fetches the row without a reload.
- **AC5** -- Given a user who does not hold `OcuPilotAdmin:USE`, when they open the Agent co-pilot
  area, then the rail item is not gated and carries its attention dot, and both side-bar entries are
  gated with `OcuPilotAdmin:USE` named in the entry's own `aria-describedby`.
- **Integration AC (Rule 1)** -- Consumer `ui/browser/definitions.browser-spec.mjs`, driving the
  throwaway container, creates a definition through the form, observes the sticky bar's saved sentence
  and the row appearing in the list, and observes a declined leave-confirmation leaving the route
  unchanged — asserted on rendered DOM and the real URL, not on store state.

**Routed from the deferred-work ledger** — each is addressed or declined:

- **DW-339** -- addressed. Tasks 6, 17: the key field checks the catalog's `keyPrefix` on blur and
  renders `AGENT.KEY.SHAPE` on the same field through the same `aria-invalid` / `aria-describedby`
  wiring, so the inline check and the server refusal are one presentation.
- **DW-340** -- addressed. Task 17: empty after save under `formSecretStored`, a labeled reveal
  toggle with `aria-pressed`, `(paste)` untouched so nothing trims.
- **DW-344** -- addressed, server half and client half both. Tasks 3, 4: the rule and its code; task
  17 sets `maxlength` as an affordance only.
- **DW-354** -- addressed. Task 17: one progress indicator spanning the whole sequence, the button
  `aria-disabled` for its duration with focus kept, and the call order below.
- **DW-355** -- addressed. Decision below; no new string.
- **DW-359** -- addressed. Decision below; the form ignores `connectionVerified` from the test body.
- **DW-365** -- addressed. Task 10.
- **DW-366** -- addressed by the same mechanism as DW-339: tasks 3 and 5 give every field-level
  violation, this one included, its own sentence, so no separate published string is needed.

## Spec Change Log

## Review Triage Log

## Design Notes

**Governing ADs:** AD-4 (send the complete property set), AD-5 (one descriptor), AD-8 (privilege
pairs), AD-11 rule 3 (navigation is a proposal), AD-13 (route grammar, scoped triple), AD-14 (change
event), AD-19 (framework-free store, signal mirror), AD-24 (secret-typed fields never leave), AD-35
(secrets never reach a surface OcuPilot displays), AD-36 (one declared read), AD-37 (weak references),
AD-39 (one envelope, two renderings), AD-42 (egress allow-list), AD-44 (classic key, `?ns=`).

**Consumes:** Story 3.1's definition schema and validator, 3.2's provider catalog and egress rules,
3.3's credential ladder and its four refusals, 3.4's test route. **Consumed-by:** Story 3.6 (the gate
lands on this form and reads its first-save state), Story 3.7 (Switches is the second `form-page` and
the second screen over OcuPilot's own state), Story 3.8 (gating and audit over these same writes).

### The call order, and why it is two buttons rather than four chores

The routes impose it: `POST :id/credential` opens the row first and 404s before it reads a body, so a
key cannot be stored before an id exists; `HandleCreate` forces `connectionVerified` to 0 and
`AGENT.ENABLE.UNVERIFIED` refuses `enabled: true`; only a passing test sets the flag. So the sequence
is create disabled → store the key → test → save enabled.

The form expresses it as **two buttons the user already understands**, each of which may issue more
than one request:

- **Test connection** on a create route performs create → store key → test, replaces the URL with the
  new definition's editor, and reports one outcome. This is not a choice: the published gate landing
  banner tells the administrator to paste a key and press Test connection, with no Save between, and
  the routes cannot serve that any other way.
- **Save** sends the whole writable field set (AD-4) and renders the response. Where the response
  reads `enabled: false` the sticky bar says `formSavedPendingTest` — the published sentence for
  exactly this.

The user sees: fill the fields, press Test connection, press Save. The ordering constraint never
surfaces as a chore because no button ever asks for a step the previous one could have taken.

### DW-355 and DW-366 — what renders for every code, and where those strings live

They are the same shape, and the answer is that **OcuPilot already writes both sentences; the form
renders them rather than republishing them**. AD-39 says the screen renders the human half.

- **Envelope-level codes** (all nine `PROVIDER.*`, plus `AGENT.NOTFOUND`, `AGENT.BADBODY`,
  `INTERNAL`): the form renders the envelope's `reason`, verbatim. `PROVIDER.REFUSED` is the one
  exception and only when `detail.providerText` is present — then the published
  `formTestConnectionFailure` is used with `<text>` resolved, because that sentence is written around
  provider text and reads broken without it. `AUTH.NOPRIVILEGE` keeps the published
  `privilegeDeniedAction` with `detail.failedPair`. Verified: `tProviderText` is assigned at
  `Provider/Base.cls` **:208** alone, in the branch whose code is always `PROVIDER.REFUSED`.
- **Field-level violations** (22 codes under `code: "AGENT.VALIDATION"`, `AGENT.DEFAULT.DISABLED`
  among them): the envelope's `reason` there is the generic *"The agent definition was refused"*,
  which names no rule, so the violation needs its own sentence. Tasks 3 and 5 put one in
  `detail.violations[]` beside `field` and `code`, authored in `Api/Error.cls` where the nine
  `PROVIDER.*` reasons already live. The form maps `field` to its control and renders that `reason`.

This is deliberately not 22 new `strings.ts` keys: `ui/tools/strings.test.mjs` **:337** admits only
what EXPERIENCE.md's Fixed strings table and seven named extractors authorize, and its own comment
calls growing the three-item bypass "the bypass it must not become". Server-authored refusal text is
data, like the envelope's `reason` — not client copy.

### DW-359 — two true facts that read as one false sentence

`ConnectionOutcome` **:560** reads `tVerified` from the stored row and overwrites it only when
`testedAsStored` is true, so an already-verified definition tested with an edited endpoint answers
`connectionVerified: true` beside `testedAsStored: false`.

**Decision: the form never renders `connectionVerified` from the test response, and never renders it
as a field at all.** The test result sentence describes the call just made, which is what
`testedAsStored` is about; the row's verification is re-read with `GET :id` afterwards and shows only
through whether Enabled can be ticked. When `testedAsStored` is false the sticky bar keeps
`formSavedPendingTest`, which is honest: saving those edits will clear both flags in
`Agent.GuardedUpdate` **:186**. The misleading juxtaposition therefore never reaches a surface.

### DW-344 — which half this story ships

Both, and they are not equal. A client `maxlength` alone would leave the API able to answer 500 to any
other caller, so the fix is the **server rule** (task 4): a new `AGENT.CREDNAME.LENGTH` accumulated
with the rest, refusing a `credentialName` longer than the credential entry's `SystemName` when
`credType` is `creds`. The limit is a declared parameter carrying the measured value 50 —
`Ens.Config.Credentials.SystemName` is `%String` with no MAXLEN override, so `%Library.String`'s
default applies — with a test that reddens if that vendor limit ever changes rather than drifting
silently. The client's `maxlength` is an affordance over that rule, never the enforcement.

### AC2 — what "agent navigation waits for the same answer" means mechanically

Every programmatic navigation in this client is `Router.navigateByUrl(...)`; there are ten call sites
and no other mechanism (`rail.ts` **:168**, `side-bar.ts` **:224**, `locator-bar.ts` **:266**,
`command-box.ts` **:361**, `header.ts` **:115**, `fault-banner.ts` **:158**, `data-table.ts` **:667**
and **:706**, `home.page.ts` **:300**, `audit.page.ts` **:325**). Angular runs a route's
`CanDeactivateFn` inside that call and lets it return `Promise<boolean>`; a `false` cancels the
navigation and the promise `navigateByUrl` returned resolves `false`.

So one guard on the `form-page` route answers for every caller, and the agent's navigation tool —
which does not exist in `ui/` yet — inherits the answer by construction when it lands, because it will
call the same method. "Waits for the same answer" is `await router.navigateByUrl(...)` instead of
`void router.navigateByUrl(...)`; the shell's own call sites may keep `void`, since a user who
declined already sees the result.

What this story can pin today: the guard refuses while dirty and the confirmation is declined; the
refusal is observable as the resolved `false` at a non-component caller; and no navigation path
bypasses `navigateByUrl`. What it cannot pin is the agent's side of it — see the amendments.

### Sizing

This spec covers five acceptance criteria, eight ledger entries, four new server seams and the first
`form-page` in the project. It is recorded here as one story because a plan stage does not change the
epic's structure; the honest seam and the recommendation are in the return to the lead.

### Preconditions the lead must settle before implementation

Each is a planning-artifact amendment with architectural weight (Rule 20) that this stage may not
take, and each blocks a named acceptance criterion:

1. **EXPERIENCE.md Fixed strings** needs two rows in the shape its eight per-screen rows already
   use — one for the Definitions list (screen title, the columns beyond the shared Name and Enabled,
   the empty state, and the three row actions) and one for the Definition form (its field labels,
   `Advanced`, the reveal toggle's label, the retention caption, and `Create`). None of those literals
   is published anywhere today; `ui/tools/strings.test.mjs` **:337** admits only what the table, seven
   named extractors and exactly three named extras authorize, and `client-lint.mjs` fails the build on
   a literal text node. **Blocks AC1, AC3, AC4.** Most of the labels are unquoted and lower-case at
   EXPERIENCE.md `:150`, so no extractor can lift them and the rows are the only route.
2. **AD-39** gains a clause: a validation envelope's `detail.violations[]` carries the same human and
   machine pair the envelope does — `{field, code, reason}` — the screen rendering the `reason` on the
   field the `field` names, the tool result rendering the `code`. Without it, tasks 3 and 5 read as a
   slice adding a field for its own use, which AD-39 forbids. **Blocks AC2, DW-339, DW-366.**
3. **AD-36 / AD-5** gain the second read source kind of task 7, so a screen over OcuPilot's own
   protected state still resolves through one declared read. `Screen/Read.cls` **:131** has exactly one
   source — an AdminPort endpoint — and `ListPage` **:80** renders no table for a screen with no read,
   so AC4 has no mechanism today. Story 3.7's Switches needs the same seam. **Blocks AC4.**
4. **AD-11 rule 3** gains a refusal path: a navigation the user did not initiate may be refused by the
   departing screen, the refusal reaches the turn as an ordinary tool result (AD-39), and the
   announcement is withdrawn rather than left standing. As written, rule 3 gives agent navigation an
   announcement and no refusal, and no sentence is published for a refused one. **Blocks the second
   clause of AC2** — the guard mechanism is buildable and testable without it, but the agent's half of
   the promise is not.

Two strains this spec resolves without an amendment, recorded so a reviewer does not re-open them:

- **`Screen/Registry.AreaCoverageProblem` refuses AC5 as written** — the `agent` area declares no
  privileges, because EXPERIENCE.md requires the rail item never to gate, while both its screens must
  gate on `OcuPilotAdmin:USE`. Task 2 restates the rule for a never-gating area. This is a shipped
  method, not a planning artifact, and the product promise is unchanged, so it is Rule 5's apply-and-
  report tier: apply it, and list it under `amendments:` at the story's gate.
- **AD-44's `?ns=` on an instance-scoped screen** needs no ruling: all eight shipped descriptors
  already declare `"scope": "instance"`, so Definitions inherits whatever the namespace switch does
  for SSL/TLS configurations today.

### Browser-spec discipline (DW-368)

The new browser spec uses `list-spec.mjs`'s helpers and nothing hand-rolled. Any filter leg is
measured against the whole list (`filterToSubset` clears first and requires `0 < kept < total`), never
against another leg's survivors, and any substring asserted to isolate a row names that row alone
rather than relying on a word this corpus happens not to repeat. The throwaway starts with zero
definitions, so the spec creates the rows it filters and tears them down.

## Verification

**Commands:**

- `mcp__iris-dev__iris_doc_load` with `server: "ocupilot-iris"`, `namespace: "HSCUSTOM"`,
  `path: "/Users/jbrandt/git/OcuPilot/src/**/*.cls"`, `baseDir: "/Users/jbrandt/git/OcuPilot/src"`,
  `compile: true`, `flags: "cku"` -- expected: zero compile errors.
- `uv run scripts/check-objectscript.py <changed paths>` -- expected: no findings.
- `cd ui && npm run build` -- expected: the six prebuild checkers pass, `screen-mirror.mjs --check`
  clean against the regenerated mirror, and `ng build` succeeds (it fails until `'form-page'` has a
  page in `ARCHETYPE_PAGES`).
- `cd ui && npm test` -- expected: `node --test tools/*.test.mjs` then the vitest component run, both
  green, with `strings.test.mjs`'s count assertion satisfied by the new EXPERIENCE.md rows.
- `sh scripts/ci-throwaway.sh up` then `cd ui && npm run test:browser`, then
  `sh scripts/ci-throwaway.sh down` -- expected: green against 52776; tear down only what this run
  started.
- `mcp__iris-dev__iris_execute_tests` -- one class per message, waited for, then the totals read back
  from `%UnitTest_Result` with the numeric run-index probe.

**Mutations (Rule 19) -- one per AC, recorded at implementation:**

- **AC1** -- set the Advanced disclosure's initial expanded state to true -> the layout spec goes red.
- **AC2** -- make the guard return `true` unconditionally -> the decline leg goes red on the resolved
  navigation promise.
- **AC3** -- render `formSaved` regardless of the response body's `enabled` -> the
  save-after-endpoint-edit leg goes red.
- **AC4** -- drop the change-event publish from the row action -> the in-place refresh leg goes red.
- **AC5** -- give the `agent` area a non-empty privilege set -> the ungated-rail leg goes red.
- **DW-344** -- remove the length rule -> the 422 leg goes red at 500.
- **DW-355** -- render `formTestConnectionFailure` for every `PROVIDER.*` code -> the eight-code leg
  goes red on the empty `Provider said:` tail.
- **DW-359** -- render `connectionVerified` from the test body -> the edited-endpoint leg goes red.

**Manual checks:**

- `docker compose exec` -based inspection only; the live `ocupilot` container holds zero definitions
  and zero `OcuPilot`-named credential entries before and after this story.

## Auto Run Result

Status: blocked
Blocking condition: intent gap

**What this pass produced.** A complete plan for all five acceptance criteria and all eight owned
ledger entries, verified against the shipped server (`Api/Definitions.cls`, `Api/Error.cls`,
`Kernel/AgentRules.cls`, `Kernel/State/Agent.cls`, `Kernel/Provider/Catalog.cls`, `Kernel/Provider/Base.cls`),
the shipped client, both UX documents in full, and all 48 ADs. Nothing was implemented; the working
tree is unchanged apart from this spec and the regenerated `epic-3-context.md`.

**Why it is blocked rather than ready.** Four of the plan's dependencies are amendments to planning
artifacts, which `bmad-build-auto` may not make mid-run (Rule 5). Each blocks a named AC, and each is
specified in **Design Notes > Preconditions** with the amendment recommended:

1. EXPERIENCE.md's Fixed strings table has no row for the Definition form or the Definitions list, so
   the form has no authorized label for any field — blocks AC1, AC3, AC4.
2. AD-39 does not admit a per-violation `reason` inside `detail.violations[]`, which is the one
   mechanism that gives all 22 field-level codes a sentence — blocks AC2, DW-339, DW-366.
3. AD-36 / AD-5 have no read source for a screen over OcuPilot's own protected state, and
   `Screen/Read.cls` speaks only to AdminPort endpoints — blocks AC4.
4. AD-11 rule 3 gives agent navigation an announcement and no refusal path — blocks the second clause
   of AC2.

**Sizing.** This is two stories, not one. The seam is between the Definitions **list** — the entity
type, the read source, the descriptor, the row actions and the area-gating rule, which is where three
of the four amendments land — and the Definition **form** itself, which owns AC1, AC2, AC3 and seven
of the eight ledger entries. The plan is written as one story because a plan stage does not change the
epic's structure; splitting it is a `/bmad-correct-course` the owner runs.

**On re-dispatch.** Once the four amendments land, reset this spec's `status` to `draft`, re-run the
epic-context pre-warm (the amendments make the planning artifacts newer than `epic-3-context.md`), and
re-dispatch on the spec path. The Code Map, the decisions on DW-355 / DW-359 / DW-344 and the AC2
mechanism survive unchanged; only the Preconditions section should shrink.
