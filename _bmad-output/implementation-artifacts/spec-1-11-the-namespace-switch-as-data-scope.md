---
title: 'Story 1.11 — The namespace switch as data scope'
type: 'feature'
created: '2026-09-12'
status: 'done'
baseline_revision: '2c8e5b71fe42d40e38d86ecf0a8097d0ba944eca'
baseline_commit: '2c8e5b71fe42d40e38d86ecf0a8097d0ba944eca'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-1-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-1-10-header-status-bar-and-page-chrome.md'
  - '{project-root}/.claude/rules/objectscript-testing.md'
warnings: ['oversized']
deferred:
  - summary: >-
      The switch's trigger has no accessible name saying what it controls: its name is the
      namespace value alone, and the word 'Namespace' is a sibling span in header.ts with no
      aria-labelledby link.
    evidence: |-
      AC1 names the listbox, which is satisfied, and the popup does not exist until the trigger
      is activated -- so a screen-reader user meets 'HSCUSTOM, button, has popup listbox'.
      account-menu.ts solves this with an id plus aria-labelledby. Not patched here: the fix
      changes the announced name of a header control whose copy DESIGN.md and EXPERIENCE.md
      govern, and DW-139 already has those two escalated as divergent on chrome detail.
    location: >-
      ui/src/app/shell/namespace-switch.ts (trigger) with ui/src/app/shell/header.ts:60
    severity: medium
  - summary: >-
      GET /namespaces calls %SYS.Namespace.GetAllNSInfo once per namespace with DontConnect
      defaulted to 0, so on an instance with ECP- or remote-mapped namespaces every list read is
      a connection attempt per namespace with no timeout budget.
    evidence: |-
      irislib/%SYS/Namespace.cls:80 is GetAllNSInfo(Namespace, ByRef Info, DontConnect As
      %Boolean = 0) and Api/Namespaces.cls passes two arguments. Free on this container (six
      local namespaces, probed). Not patched: passing 1 changes which namespaces are listed on
      exactly the instances this project cannot test, so it needs an instance that has one.
    location: >-
      src/OcuPilot/Api/Namespaces.cls GlobalDatabase()
    severity: medium
  - summary: >-
      NavigationService.reload() joins a map read already in flight rather than queueing one, so
      a scope change inside that window leaves the map computed against the previous namespace.
    evidence: |-
      Mechanism verified: reload() calls the same single-flight load(), which returns the
      running promise. Harmless while every Epic 1 verdict is an instance-wide %Admin_* pair,
      so the wrong-verdict outcome is not reachable today; it becomes reachable with the first
      namespace-scoped gate. Settled by a test that starts a map read, changes the scope before
      it settles, and asserts the second read carries the new ns.
    location: >-
      ui/src/app/core/navigation.ts reload()
    severity: medium (unverified)
  - summary: >-
      The declared `scope` is refused only by Screen.Registry.Validate, while the two build
      gates that refuse the sibling entity-type vocabulary do not read it.
    evidence: |-
      scripts/check-objectscript.py has no scope check and ui/tools/screen-mirror.mjs only
      copies `scope` into the generated interface (:263). Registry.cls states nothing on the
      serving path calls Validate, so a third spelling compiles, mirrors, and makes ScopeFor
      return '' silently. Test/Descriptor.cls TestTheProductionRosterValidates catches a
      shipped descriptor, so the gap is a build step, not a release risk. The false claim in
      Registry.cls's header that both tools already refuse it was corrected in this pass.
    location: >-
      ui/tools/screen-mirror.mjs and scripts/check-objectscript.py
    severity: medium
  - summary: >-
      The matrix's unknown-ns row says the client 'never sends one', and the implementation
      sends exactly one verification request per requested name.
    evidence: |-
      The two rows cannot both hold literally: the failed pair exists only inside a refusal,
      and a client that never sends a bad ns never earns one. The DW-8 acceptance criterion
      says 'when a request is made', and the implementation follows the AC; the decision is
      recorded in this spec's Spec Change Log and pinned by scope.test.mjs. Amending the
      matrix's rationale clause is the lead's under Rule 5 -- the intent contract is frozen to
      the build stage.
    location: >-
      spec I/O & Edge-Case Matrix, the DW-8 unknown-ns row
    severity: medium
---

<intent-contract>

## Intent

**Problem:** `?ns=` survives every navigation affordance and selects nothing. `OnPreDispatch` resolves it, validates that it exists, and drops it on the floor (DW-33), so no handler can read the scope a request was made in; it also accepts any namespace that exists, whether or not the caller may enter it (DW-8). The header carries a slot where the switch goes and no control in it, and no code anywhere constructs the `(entity type, scope, id)` triple AD-13 requires of a reference that crosses a boundary.

**Approach:** Make the resolved namespace a value the request carries. `OnPreDispatch` gains an entry check and stashes the result in one kernel seam; `GET /api/ocupilot/namespaces` reads that stash back and lists the namespaces the caller may enter with their write verdicts; `Kernel.EntityRef` builds and parses the triple from a descriptor's declared `scope`. On the client a framework-free scope service owns the selected namespace, `ApiService` attaches it to every call, the header's slot becomes the switch, and a scope change re-fetches its consumer in place instead of re-routing.

## Boundaries & Constraints

**Always:** The namespace is chosen from the set the user can read, never taken as a caller string (AD-21, AD-48). Privilege is the caller's, checked at call time, denials naming the failed pair (AD-8). One response writer and one error writer, `code` a stable dotted-uppercase identifier (AD-12, AD-39). Reaching `%SYS` is explicit save/restore with the restore first in every `Catch` (AD-16) — enumeration does **not** need it: `%SYS.Namespace` is a `%`-class and answers in `HSCUSTOM` (probed). `%CSP.REST` route order is preserved and the admin gate stays ahead of the namespace check (AD conventions; `Test/Wire.cls:404`). Client core modules stay framework-free so `node --test` can import them; components are standalone, zoneless, `OnPush`, signal-based (AD-19). Every API path is absolute through `ApiService` (AD-20). Non-ASCII in source is a `\uXXXX` escape (Rule 14).

**Never:** No new user-facing string — `headerNamespaceLabel` ('Namespace') and `privilegeRequiresResource` ('Requires <resource>') already exist and are already extracted; `REQUIRED_ALONGSIDE_TABLE` stays at three and no planning artifact is edited (DW-126). No namespace or database is created, deleted, mounted or dismounted anywhere, on any instance. No screen store, no per-screen read, no auto-refresh timer — 1.12 and 1.14. No connectivity probe and no uniform error surface — 1.13. No agent panel and no context chip — Epic 5. No change-event bus publisher: nothing writes yet. No dialog and no URL rewritten into another web application (`EXPERIENCE.md:552`).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| The switch opens | caller holds `%DB_X:RW` on some of the instance's namespaces | a `role="listbox"` named `Namespace` lists exactly those; the current scope is the trigger's value | none |
| **DW-33** the stash is consumable | `GET /api/ocupilot/namespaces?ns=USER` | body `scope:"USER"`, read from `Kernel.Scope.Current()` and not from `$Namespace` | none |
| `ns` absent | no query parameter | `scope` is the install namespace; the client sends no `ns` until the list has loaded | none |
| **DW-8** unknown `ns` | `?ns=NOPE` | 400 `bad_request` / `NS.UNKNOWN` (unchanged). The server answers this on any request carrying an unknown `ns` - a pasted or stale deep link reaches it. The client's own namespaces read is the one call that never carries `ns`, so the recovery channel stays open | falls back to the echoed `scope`, `replaceUrl` |
| **DW-8** `ns` the caller cannot enter | `?ns=USER` without `%DB_USER:READ` | 403 `forbidden` / `NS.DENIED`, `detail.failedPair` = `%DB_USER:READ` | client falls back and names the pair through `formatRequires` |
| **DW-7** readable, not writable | caller holds `%DB_USER:R` and not `:W` | `/namespaces` lists `USER` with `writable:false` and its `failedPair`; the switch does not offer it; a route already scoped there is honoured and every read runs there | none |
| Read-only mount | `HSLIB` reports `GlobalDB.ReadOnly = 1` (this container) | `writable:false` with **no** `failedPair` — the reason is the mount, not a missing pair | none |
| Percent-encoded `ns` | `?ns=%25SYS` | resolves to `%SYS`; the framework decodes a query parameter once and the entity-id codec is not involved | 400 / 403 as above |
| Selection | `USER` chosen on `/logs?ns=HSCUSTOM` | URL becomes `/logs?ns=USER`; the path is unchanged, `ScreenOutlet` is not re-created, and the scope's consumer re-reads carrying `ns=USER` | none |
| Scope half of a reference | descriptor declares `scope:"namespace"` vs `"instance"` | `EntityRef.ScopeFor` yields `Kernel.Scope.Current()` vs the literal `instance` | a declared scope outside the two fails `Registry.Validate` |
| One name, two namespaces | `task`/`USER`/`Nightly purge` against `task`/`HSCUSTOM`/`Nightly purge` | two different keys, each parsing back to its own triple | unknown entity type refused by `EntityType.IsKnown` |

</intent-contract>

## Code Map

Anchors verified 2026-09-12 against the working tree, the live `ocupilot` instance and the vendor export. **Extend, never duplicate.**

- `src/OcuPilot/Api/Router.cls` — `OnPreDispatch` `:162-208`, four gates in order: install `:167-182`, identity `:184-189`, admin resource `:191-195`, namespace `:197-202`. **`:197-198` is DW-33**: `tNs` is read, tested with `%SYS.Namespace.Exists()`, and never referenced again. `UrlMap` `:56-62` (two routes); thin `Call=` targets `:66-78`; `HoldsAdminResource` `:110-122`; doc `:142-146` (a caller who reached this class holds read on the install namespace) and `:152-159`.
- `src/OcuPilot/Api/Navigation.cls` — the handler seam to copy: `Payload(Output pObject)` `:19`, `Handle()` `:73-87`. `Api/Instance.cls` adds `Parameter LOGSUBSYSTEM` `:16`, `LogDetail` `:195-198`.
- `src/OcuPilot/Api/Error.cls` — `Render(pStatus, pSlug, pReason, pCode, pDetail)` `:120`; 12-slug enum `:20-54`; declared codes `:59-105`. `NS.UNKNOWN` is an inline literal at `Router.cls:200` — promote it and `NS.DENIED` to parameters beside the others.
- `src/OcuPilot/Screen/Gate.cls` — `EvaluatePairs` `:89-109` (a pair-set is a `%List` of `$ListBuild(resource, permission)`; the failure is reported `resource_":"_permission` `:100`), `HoldsPrivilege` `:123-126`. The namespace list needs that same `$System.Security.Check` shape, not a new gate.
- `src/OcuPilot/Kernel/EntityId.cls` (96 lines) — `Encode` `:47`, `Decode` `:91` (the tree's only decode point), `Parameter COMPOSITESEPARATOR = 1` `:71`, `JoinComposite` `:74` / `SplitComposite` `:81`. **`Encode` and `Decode` are deliberately not inverses** — a reference key must copy the `COMPOSITESEPARATOR` pattern, never this pair. `Kernel/EntityType.cls` — `Parameter TYPES` `:22` (26 members), `IsKnown` `:28`. `Kernel/Utils.cls` — `SwitchNamespace` `:43` / `RestoreNamespace` `:58`.
- `src/OcuPilot/Screen/Descriptor/Base.cls` — `Scope()` `:174`, `ParentScope()` `:181`, `PrimaryEntityType()` `:148`; the two literals are documented `:171-173`. `Descriptor/Home.cls:31` declares `"instance"`; `Test/Screen/Composite.cls:23`, `Sub.cls:19`, `Unbuilt.cls:22` declare `"namespace"`. `Screen/Registry.cls` `Validate` `:116-180` checks area, route uniqueness and pair shape and **not `scope`** — the open seam.
- **Namespace enumeration, probed on `ocupilot-iris` 2026-09-12; sample = this container's six namespaces, all six read.** `%SYS.Namespace.ListAll(.a)` answers in `HSCUSTOM` (no `%SYS` switch needed) and returns `%SYS, HSCUSTOM, HSLIB, HSSYS, HSSYSLOCALTEMP, USER`; `GetAllNSInfo(ns, .i)` gives `i("GlobalDB","Resource")` = `%DB_<NAME>` for all six, `Mounted` 1 for all six, `ReadOnly` 1 for `HSLIB` alone. Vendor source `irislib/%SYS/Namespace.cls`: `Exists` `:29`, `ListAll` `:165` (implicit namespaces come back `^`-prefixed), `GetAllNSInfo` `:80` with its field list `:68-79`, `Query List` `:237`, `CheckNamespaceSystemAccess` `:252` whose own doc says it does **not** check permissions. **No vendor call filters by the caller's privileges** — that filter is OcuPilot's to write.
- `src/OcuPilot/Test/Wire.cls` — the throwaway-principal pattern the privilege tests follow: `OcuPilotWire`-prefixed parameters `:21-45`; `OnBeforeAllTests` `:68-118` (random in-memory password `:76`, `%SYS` bracket `:78`/`:113`, derives the install namespace's routine-DB resource `:81-96`, `EnsurePrincipal` `:169-186`, proves the privilege difference with `$SYSTEM.Security.CheckUserPermission` `:108` before any test runs); `OnAfterAllTests` `:130-165` (deletes, re-tests, returns a failing `%Status` rather than an assertion). `TestAdministrativeGateRefusesBeforeTheNamespaceIsValidated` `:404` pins the gate order this story must not disturb.
- `src/OcuPilot/Test/Http.cls` `AbsoluteRequest` `:206` (per-principal live HTTP); `Test/Dispatch.cls` `Invoke(..., pParams, ...)` `:44` (how `?ns=` is injected in-process); `Test/Routing.cls` namespace tests `:114`, `:123`, `:137`; `Test/EntityId.cls` `ClassMethod Corpus()` `:35` (17 values) and `ServerDecode` `:44`; `Test/Descriptor.cls` is where registry refusals are pinned — `TestAnUnknownEntityTypeIsRefusedByTheRegistry` `:181` is the precedent, with `Test/Pair/Bad.cls` as the malformed-fixture pattern.
- `ui/src/app/shell/header.ts` — the slot: `.ocu-header-namespace` `:57-62`, eyebrow `:58`, `@if (hasNamespace)` `:59` over the plain value span `:60`; `namespace()` `:74-80` parses `?ns=` off `router.url`; `generation` signal `:72`/`:82-85`; `homeHref` `:102-105`; `goHome` `:118-124`. Doc `:37-40` hands the list, the selection and the re-fetch to this story.
- `ui/src/app/core/navigation.ts` — `NAMESPACE_PARAM` `:125`, `withQuery` `:142-150` (only `ns` travels), `formatRequires` `:120`, `RESOURCE_PLACEHOLDER` `:102`, `NavigationService` `:195`, `load()` single-flight `:275-294`, `noteForbidden()` `:306`, `runLoad()` `:324-357` whose fetch `:326` carries no query today.
- `ui/src/app/core/api.ts` — `ApiOptions` `:27-38` (`onForbidden` `:37` is the forward-reference seam to copy), `API_PATH_PREFIX` `:90`, `isOcuPilotApiPath` `:125-135`, `request()` `:154-183`, `requestJson()` `:193-246`, `buildInit()` `:248-256`. `path` reaches `fetch` verbatim; nothing in `ui/` appends a query anywhere.
- `ui/src/main.ts` — the value-provider bootstrap; `onForbidden: () => navigation.noteForbidden()` `:50` with its comment `:42-45` is the established way to close a construction cycle. Providers `:74-85`.
- `ui/src/app/core/overlay-stack.ts` — `push(id, close, position)` `:45-51`, `remove` `:54-58`, `closeTop()` `:75-82`; registration exemplars `command-box.ts:343`/`:360` and `account-menu.ts:145`/`:157`, both with a `DestroyRef` cleanup.
- `ui/src/app/shell/screen-outlet.ts` — `query` `:75` (`toSignal` of `queryParamMap`), `namespace()` `:97`, `data-ns` `:50`. Changing only the query re-emits here **without** re-creating the component: that is the observable "re-fetches in place, never re-routes".
- `ui/src/app/core/strings.ts` — `headerNamespaceLabel: 'Namespace'` `:318` (its comment `:315-317` names this story), `privilegeRequiresResource: 'Requires <resource>'` `:196`. `ui/tools/strings.test.mjs` — `extractNamespaceSwitchName` `:123` already derives the name from `EXPERIENCE.md:315`; `EXTRACTED_FROM_PROSE` `:161-167`; `REQUIRED_ALONGSIDE_TABLE` `:255-259` with its do-not-grow comment.
- `ui/src/app/core/screens.generated.ts` — `entityType` `:58`, `scope` `:60`, and `ENTITY_TYPES` mirrored from `Kernel/EntityType.cls` (`ui/tools/screen-mirror.mjs:276-277`, refusal `:200-205`), so the client validates a type without a second vocabulary.
- `ui/src/styles/_components.scss` — header band `:827-842`, lockup `:849-864`, namespace slot `:866-887`; popup surfaces to reuse: account menu `:421-441`, command-box sheet `:957-1025`. `_tokens.scss` `--ocu-surface-container-lowest` `:77`, `--ocu-elevation-2` `:196`, `--ocu-on-shell`, `--ocu-shell-edge`; `_metrics.scss` `--ocu-header-height` `:30`, radii `:22-25`.
- UX anchors: `EXPERIENCE.md:315` (accessible name, list rule, selection behaviour, no rewrite, no dialog), `:66`/`:177` (the route form), `:320` (namespace is not a locator segment), `:326` (context-chip — Epic 5), `:552` (the two bans), `:622` (why it re-fetches rather than rewrites); `DESIGN.md:1007` (eyebrow at 100% over the name in `caption`, dotted 1px underline, `▾`, hover `on-shell` at 8%, focus ring on chrome), `:821` (the contrast figures at the gradient's end).

## Tasks & Acceptance

**Execution — server:**

- `src/OcuPilot/Kernel/Scope.cls` *(new)* — the request-scoped resolved namespace: `Set(pNamespace)`, `Current()` (falls back to `$Namespace` when unset), `Clear()`, and `Parameter SCOPEINSTANCE = "instance"`. Backed by a process-private global holding a string; `Set` assigns and `Clear()` kills; what stops a value surviving into the next request on a reused process is `OnPreDispatch` calling `Clear()` at dispatch entry, not anything `Set` does (corrected by the lead 2026-09-12 - the code was always right, the claim named the wrong mechanism).
- `src/OcuPilot/Api/Router.cls` — in `OnPreDispatch` `:197-202`, keep the existing 400 for a namespace that does not exist, add a 403 (`forbidden`, `NS.DENIED`, `detail.failedPair`) when the caller lacks READ on the target's global-database resource, and **stash the survivor** in `Kernel.Scope` (**DW-33**). Skip the entry check when the request's namespace is already `$Namespace` — a caller who reached this class holds read there by construction (`:142-146`). The check stays after the admin gate. Promote `NS.UNKNOWN` and `NS.DENIED` to `Api.Error` parameters.
- `src/OcuPilot/Api/Namespaces.cls` *(new)* + the `/namespaces` GET route in `UrlMap` `:56-62` and its thin `Call=` target — `{scope, namespaces:[{name, writable[, failedPair]}]}` in the `Api/Navigation.cls` shape. `scope` is read from `Kernel.Scope.Current()`. The roster comes from `%SYS.Namespace.ListAll`, dropping `^`-prefixed implicit namespaces, keeping those whose global-database resource the caller can READ, and setting `writable` from WRITE on that resource **and** `GlobalDB.ReadOnly = 0`. No namespace switch is needed; do not add one.
- `src/OcuPilot/Kernel/EntityRef.cls` *(new)* — the `(entity type, scope, id)` triple of AD-13: `Key(pType, pScope, pId, Output pKey)`, `Parse(pKey, Output pType, Output pScope, Output pId)`, `Wire(pType, pScope, pId, Output pObject)` emitting `{type, scope, id}`, and `ScopeFor(pDeclaredScope)` returning `Kernel.Scope.Current()` for `namespace` and `Scope.#SCOPEINSTANCE` for `instance`. The type is validated against `EntityType.IsKnown`. Join with a separator one code point above `EntityId`'s `COMPOSITESEPARATOR`, documented with the same inference, so a composite id passes through a key unharmed. Do **not** build the key from `EntityId.Encode`: encode-twice has no inverse.
- `src/OcuPilot/Screen/Registry.cls` — extend `Validate` `:116-180` to refuse a descriptor whose declared `scope` is neither `namespace` nor `instance`, so AC4's scope half cannot be spelled two ways.
- `src/OcuPilot/Test/Namespaces.cls` *(new)*, `src/OcuPilot/Test/EntityRef.cls` *(new)*, and extensions to `Test/Routing.cls` (the 403 and the stash), `Test/Wire.cls` (a throwaway principal holding read on the install namespace and not on a second one, over real HTTP) and `Test/Descriptor.cls` (the scope refusal, in the shape of `TestAnUnknownEntityTypeIsRefusedByTheRegistry` `:181`, with a bad-scope fixture under `Test/Screen/` in the `Test/Pair/Bad.cls` pattern). `Test/EntityRef.cls` reuses `Test/EntityId.cls`'s `ClassMethod Corpus()` `:35` for the id half.

**Execution — client:**

- `ui/src/app/core/scope.ts` *(new, framework-free, no `@angular/*` import)* — `ScopeService`: `setRequested(ns)`, `requested()`, `namespaces()`, `namespace()` (the permitted, resolved scope — the requested one when the list allows it, otherwise the server's echoed `scope`), `unresolved()` (the requested value the list rejected, with its `failedPair` when there is one), `load()` (reads `/api/ocupilot/namespaces` **without** `ns`, so it is the recovery channel a bad `ns` cannot close), `select(ns)`, `subscribe(fn)`.
- `ui/src/app/core/api.ts` — add `scope?: () => string` to `ApiOptions` `:27-38`, defaulting to `() => ''`, and append `?ns=<encodeURIComponent>` in `request()` when it is non-empty. Wired in `main.ts` with the forward reference `:42-50` already uses.
- `ui/src/app/core/navigation.ts` — add `reload()` (what `noteForbidden()` `:306` already does, named for the general case) and keep `withQuery` as the one place that decides what travels.
- `ui/src/main.ts` — construct `ScopeService`, pass its `namespace()` as the API's scope source, subscribe `navigation.reload()` to it, and provide it the `useValue` way beside the other core services `:74-85`.
- `ui/src/app/shell/namespace-switch.ts` *(new)* — the control in the header's slot: a trigger carrying the eyebrow and the current scope per `DESIGN.md:1007` (dotted 1px underline, the `▾` glyph authored as its escape per Rule 14, `on-shell` at 100%), `aria-haspopup="listbox"` / `aria-expanded`, opening a `role="listbox"` named by `STRINGS.headerNamespaceLabel` whose options are the writable namespaces with `aria-selected` on the current one. Registers with the overlay stack in the `command-box.ts:343` shape; watches `router.events` for the route's `ns` and hands it to `scope.setRequested`; `select` navigates with the query alone so the path never changes. When the route's namespace is unresolvable it replaces it with the resolved scope using `replaceUrl`, and where the cause is a missing pair it names it with `formatRequires(STRINGS.privilegeRequiresResource, failedPair)`.
- `ui/src/app/shell/header.ts` — replace the value span `:60` with `<app-namespace-switch />`, keeping the band and the eyebrow's authority. `namespace()` `:74-80` moves into the switch; the header keeps `homeHref`/`goHome`.
- `ui/src/app/core/entity-ref.ts` *(new, framework-free)* — the client mirror of the triple: `INSTANCE_SCOPE`, `entityRefKey(type, scope, id)`, `parseEntityRefKey(key)`, validating the type against `ENTITY_TYPES` from `core/screens.generated.ts`. It is what 1.14 routes a re-fetch on.
- `ui/src/styles/_components.scss` — the switch's trigger and popup from the existing tokens (`--ocu-surface-container-lowest`, `--ocu-elevation-2`, `--ocu-on-shell`, the `radius-sm`/`md` pair). Add no colour token.

**Execution — tests:**

- `ui/tools/scope.test.mjs` *(new)*, `ui/tools/entity-ref.test.mjs` *(new)*, and extensions to `ui/tools/api.test.mjs` (the scope source and the no-scope default), `navigation.test.mjs` (`reload`), `strings.test.mjs` (the key count is unchanged — assert it).
- `ui/src/app/shell/namespace-switch.spec.ts` *(new)*; extend `header.spec.ts` and `screen-outlet.spec.ts`. Focus assertions `document.body.appendChild(fixture.nativeElement)` first, as `side-bar.spec.ts:304-307` does.

**Acceptance Criteria:**

- Given a signed-in user, when the namespace switch opens, then a `role="listbox"` whose accessible name is `Namespace` lists exactly the namespaces the user can read **and** write, the current scope is the trigger's value and marked `aria-selected`, and nothing else in the header changes.
- Given the user chooses a namespace, when the selection resolves, then the route's `ns` is replaced and the path, the fragment and every other query parameter are untouched; `ScreenOutlet` is not re-created; no URL leaves the `/ocupilot` application; and no dialog opens.
- Given any request the shell makes, when it is sent, then it carries the resolved scope as `?ns=`, `OnPreDispatch` resolves and stashes that namespace once, and a handler reads it from `Kernel.Scope` rather than from `$Namespace` — with the namespaces read itself sending no `ns`, so a bad one cannot close the recovery channel.
- Given a descriptor that declares `scope`, when a reference to one of its entities is constructed, then it carries `(entity type, scope, id)` with the scope half resolved to the request's namespace for `namespace` and to the literal `instance` for `instance`, and `task`/`USER`/`Nightly purge` and `task`/`HSCUSTOM`/`Nightly purge` produce different keys that each parse back to their own triple.
- Given an entity id carrying a leading underscore, a slash, a space, a percent sign or a non-ASCII character, when it is placed in a route and read back, then it occupies exactly one path segment through `Kernel.EntityId` and its client mirror, the fixed corpus round-trips, and a reference key built over the same corpus parses back to the id unchanged.
- **Integration AC** — given the scope changes, when `ScopeService` publishes it, then its consumer `NavigationService` re-reads `GET /api/ocupilot/navigation` carrying the new `?ns=` and the rail and side bar render from the returned verdicts, while the router URL's path is unchanged — the observable form of "re-fetches in place, never re-routes".
- **DW-8** — given a route carrying a namespace that does not exist or that the caller cannot enter, when a request is made, then the API answers 400 `NS.UNKNOWN` or 403 `NS.DENIED` with the failed pair in `detail`, and the shell falls back to the resolved scope with `replaceUrl`, naming the missing pair through `Requires <resource>` where there is one.

### Review Findings

**2026-09-12 — code review (full-opus, four layers: blind-hunter, edge-case-hunter,
verification-gap, acceptance-auditor). 63 rows → 32 entries: high 1, medium 7, low 23, false 1.
Story status `done`; 2 entries stay open, both ledgered with an owner and non-blocking.**

**Patched in this pass (7 medium, 6 low)** — each with a demonstrated mutation in `## Verification`:

1. `[med]` **One namespace was not one scope spelling.** Three sightings of one invariant.
   `Router.CanonicalNamespace`'s pattern excluded `-` and `_`, which the System Administration
   Guide's *Rules for Namespace Names* documents as legal after the first character (verified
   against the 2026.2 page; `Config.Namespaces` carries `CAPITALNAME = 1`) — so `?ns=abc_test`
   was admitted and stashed verbatim against a roster carrying `ABC_TEST`, reopening for those
   names the exact divergence the implement stage added the method to close. The client never
   canonicalised at all (`isListed()` was `entry.name === namespace`), so `?ns=user` — which the
   server *does* canonicalise and admit — read as unresolvable and `replaceUnresolved()` moved the
   user off a namespace the instance had just accepted, silently. `runVerify` compounded it by
   returning on `result.kind !== 'error'`, discarding the 200 that is the only answer in the one
   case where the list and the gate disagree. Fixed on both sides from one documented rule.
2. `[med]` **DW-158's other half.** `Screen.Registry.Validate` refuses `""` with no exemption, so a
   descriptor that simply *omits* `scope` failed on the instance and passed both build gates — the
   build-versus-runtime split DW-158 exists to close, for the likelier authoring mistake. Added to
   `check-objectscript.py` (the commit-blocking hook gate); every on-disk declaration block already
   declares a scope, so it flags nothing today. `screen-mirror.mjs`'s `scope !== ''` exemption is
   left as it is: its doc states the reason (a synthetic in-test fixture declares no scope) and its
   production input is the same on-disk set.
3. `[med]` **The ledger said open for two items this diff fixes.** DW-155 and DW-158 still read
   `status=open owner=1-11-…` in the commit that closes them. Both closures verified and recorded
   through the tool. The spec's frontmatter `deferred:` list and Residual risk 4 still carry them —
   a spec edit, so left for the lead's adjudication.
4. `[med]` **`detail` was executed by no test.** The fourth envelope key is the only path
   `%DB_USER:READ` takes to the user, and both consumer suites hand `ScopeService` hand-built
   error objects. Making `envelopeDetail` return `null` shipped DW-8's user-visible half broken
   with 469 tests green. Two rows added to `api.test.mjs`'s envelope-reader section.
5. `[med]` **The generation guard — the implement review's own headline patch — was pinned by
   nothing.** No row held a read open across `reset()`. Two added, one per await.
6. `[med]` **`main.ts`'s `loaded()` guard was matched by `/onScopeChange\(\s*scope,/`**, which
   stops at the comma and never reads the callback body; the behavioural test writes its own copy
   of the wiring. Clause tightened to cover the guard.
7. `[low]` The dotted 1px underline (`DESIGN.md:1007`) and the `min-width: 0` that makes the
   ellipsis reachable moved onto `.ocu-namespace-switch-value`, which `design-tokens.test.mjs` no
   longer named. Row added.
8. `[low]` Four doc/comment claims corrected at their origin: `core/scope.ts`'s "the one call that
   never carries `ns`", contradicted three paragraphs later by its own verification read;
   `CanonicalNamespace`'s six-item probe cited as evidence for a documented population rule;
   `strings.test.mjs`'s comment claiming a key-name filter establishes that no sentence exists;
   and two stale `mutation:` lines (a 122-test count now 124, and an attribution naming the wrong
   assertion — re-verified by applying the mutation, not by reading).

**Open, ledgered, non-blocking (1 high, 1 medium):**

- `[high]` `routed owner=1-17-…` **DW-159 — no UI surface is tested against a real browser
  runtime.** Rule 3 wants browser-MCP or Playwright DOM assertions for a user-facing story and
  says the lead's later manual smoke does not count; `ui/` has no browser harness at all, so every
  shell assertion since 1.5 is jsdom, which computes no layout. **Rule 3's API half IS satisfied**
  — `Test/Wire.cls` makes real HTTP requests as throwaway principals and asserts status, body and
  side effect (13/13 re-run this pass). Graded out-of-footprint and routed rather than blocking:
  the gap is epic-wide rather than 1.11's, a harness is a story rather than a fix-pack item, and
  the container still serves the pre-1.11 bundle, so a browser test could not exercise this code
  today. **For 1.11 specifically the covering gate is the lead's own browser check in
  `## Verification` → Manual checks (Rule 7), which runs next** — this story's rendered surface
  remains unobserved until it does, and that is the one finding the lead should not wave through.
- `[med]` `routed owner=1-14-…` **DW-157, the join-versus-queue gap — QA's pin-not-fix disposition
  is right, its stated reason is not the whole one.** "The naive fix hangs the suite" is a reason
  not to apply *that* fix; what makes the gap safe today is the spec's own argument, that every
  Epic 1 verdict is an instance-wide `%Admin_*` pair, so a map computed against the previous
  namespace yields identical verdicts. Two corrections: the window is wider than "a narrow race" —
  `app.ts` starts `navigation.load()` and `scope.load()` in the same tick, so a map read is
  usually outstanding when the list lands, making this the cold-sign-in path, and the composed pin
  sequences the two loads in an order the shell does not produce. And the correct fix is not
  "queue a second load" but mark-dirty-and-re-run-once with re-entrancy protection, which is a
  design change owned by the story that owns re-fetch routing. Re-owned to 1.14, fix-risk upgraded
  to high, third sighting recorded (DW-4, DW-102, DW-157). **The same shape does not recur
  elsewhere in this diff:** `ScopeService.load()` is also single-flight, but its only input is the
  principal, and `reset()` bumps the generation and nulls `inFlight`, so it has no changed-input case.

**Closed at emission.** `by-design`: the refusal's persistence into `[attr.title]` — now read as the
accessible *description* because QA's `aria-labelledby` wins the name — is the behaviour
`scope.test.mjs`'s DW-8 row pins and the implement stage's triage deliberately kept.
`wontfix-theoretical` (each with what would make it real): `choose()` ignoring a rejected
navigation (a route guard on a shell route); `GlobalDatabase` ignoring `GlobalDB.Mounted`/`Status`
(a namespace reporting a resource with an unmounted global database — not demonstrable without
dismounting one, which this run is forbidden to do); the gate/list divergence from the
install-namespace short-circuit and from `^`-prefixed implicit namespaces (an instance whose
install namespace splits its global and routine databases); `?ns=` present-but-empty (the client
never emits it — `withNamespace` and `scopedPath` both drop an empty value); `screen-mirror.mjs`'s
`scopeWords ?? []` (a second production caller of `buildMirror`; `readSources` already throws);
`EntityRef.Key` not refusing a separator inside `type`/`scope` (a caller-supplied scope reaching
`ScopeFor`). `wontfix-accepted` (`reopen_if`): `Test/Namespaces.cls`'s `%Size() = 1` against the
unarmed live roster (an instance where two namespaces share a global-database resource);
`NamespaceFixture.Arm("")` unable to express an empty roster (a test needing one);
`SCOPE_FIELD_RE`'s body-wide scan (a declaration gaining a nested `"scope"` key); the
`aria-labelledby` id dangling in the switch's own standalone specs (a second switch mounted, or the
eyebrow leaving `header.ts`); `Kernel.Scope.Clear()` in `OnPreDispatch` asserted by nothing (a
handler reading `Current()` on a path `OnPreDispatch` does not reach); `/namespaces` uncapped
(AD-36 binds list screens and read tools, and `/instance` and `/navigation` are uncapped the same
way — a shell-endpoint precedent, not this story's). `false`: "`Kernel.Scope` has no post-dispatch
`Clear()`" — `OnPreDispatch` clears it as its first statement, which closes the same hole at the
other end.

**Rejected because the fix is to edit this spec** (recorded for the lead, who owns them): the
`## Auto Run Result` is a stage stale — it reports 336 Node + 122 component against a measured 345
+ 124, omits QA's four files, and its patch tallies do not reconcile with the triage log; the
frontmatter `status: done` disagrees with `sprint-status.yaml`'s `review` and the `deferred:` list
carries two closed items; and the task line for `Kernel/Scope.cls` still claims `Set` "kills before
it writes", the claim whose correction at its other origin the implement review already applied.

**Rule 6 (ADs).** All 48 read, not only the fourteen in `## Design Notes`. AD-44, AD-13, AD-8,
AD-21, AD-48, AD-12, AD-39, AD-5, AD-14, AD-19, AD-20, AD-29 conform. **AD-16 has nothing to
violate**: no `Set $NAMESPACE` or `New $NAMESPACE` appears anywhere in the diff's server code —
`%SYS.Namespace.*` are `%`-classes that answer in place — and `Test/Namespaces` and `Test/Routing`
both assert `$Namespace` is unchanged across the new paths, so the spec's "not reached here" is
confirmed rather than assumed. AD-13/AD-21's caveat was finding 1, now fixed. AD-36 is the one
tension, graded low on the epic-precedent above. **Rule 1** satisfied: `Kernel.Scope` names two
consumers, `ScopeService` has the Integration AC, and `Kernel.EntityRef` / `core/entity-ref.ts` take
the permitted consumer-less escape explicitly. **Rule 5**: the lead's amendment of the unknown-`ns`
row was the right instrument; no other NFR is worked around with comments plus a ledger entry.
**Rule 14**: no literal non-ASCII byte in any new or changed source file. The `Never` clauses all
hold — no new string, `REQUIRED_ALONGSIDE_TABLE` still three, no planning artifact edited, no
namespace or database created, deleted, mounted or dismounted.

## Spec Change Log

- 2026-09-12 (lead, Rule 5 amendment after implement): the unknown-`ns` matrix row read "the client ... never sends one",
  which cannot hold alongside DW-8's acceptance criterion ("when a request is made") - a pasted or stale deep link
  carries an unknown `ns` whatever the client does. The row now separates the server's obligation on any request from
  the one client call that deliberately omits `ns`. The implementation already followed the AC; only the row was wrong.

**The failed pair comes from a request, because the list cannot carry it.** The Tasks list gives
`unresolved()` a `failedPair` "when there is one", and there never is one: `/namespaces` lists only
namespaces the caller may enter, so a namespace they may not is absent rather than listed as
refused, and absence names no privilege. AC "DW-8" says "**when a request is made**", so the
request is made: one `GET /api/ocupilot/namespaces?ns=<requested>`, at most once per requested
name, whose `NS.DENIED` carries the pair (and whose `NS.UNKNOWN` carries none, which is why that
case stays silent). `ScopeService` gains `refusal()` beside `unresolved()` for it — the refusal
lands *after* the switch has already corrected the URL, so the live answer is `null` by then and a
remembered one is the only thing there is to say.

**`JsonResult`'s error variant gains `detail`.** The envelope has carried four keys since 1.1
(AD-39) and the client read three; the pair above is in the fourth. No new shape, no second
endpoint.

**The bad-scope fixture is its own package, not a file under `Test/Screen/`.** The Tasks list names
both. `OcuPilot.Test.ScreenRegistry`'s roster is asserted *sound* by three existing tests, so a
malformed descriptor inside it would refuse that roster; `Test/Pair/Bad.cls`'s own header states
the rule this follows — one fault per fixture package, or each refusal stops pinning the one it
names. `OcuPilot.Test.Scope.Bad` with `OcuPilot.Test.ScopeRegistry`.

**`Kernel.Scope` declares both scope words, not only `instance`.** `SCOPENAMESPACE` sits beside
`SCOPEINSTANCE` so the registry's refusal and `EntityRef.ScopeFor` read one source; spelling
`namespace` as a literal in two places is the divergence AC4 exists to prevent.

## Review Triage Log

### 2026-09-12 — Review pass

- verdicts: 50 findings — high 0, medium 23, low 25, false 2, maybe-false 0
- findings:
  - `[medium]` `[patch]` `ScopeService` has no generation guard, so `reset()` cannot cancel an in-flight read — verified: `runLoad`/`runVerify` resume past their `await` and write `entries`/`loadedOnce`; `NavigationService:208,328,337,342` carries the counter for this exact hazard. Added the same counter, read across both awaits.
  - `[medium]` `[patch]` Only a presentational component ever loads the namespace list — verified: `scope.load()` was called from `namespace-switch.ts:197` alone. `App.verifyWhenSignedIn()` now calls it too; both reach the same single-flight `load()`.
  - `[low]` `[reject]` The list is never re-read after the first load — real, but a privilege granted mid-session is not everyday use and a list re-read per 403 adds a request to every refusal; the App-level `load()` above gives a later signed-in pass the retry.
  - `[low]` `[reject]` The refusal is cleared only by `select()`, so its tooltip persists — the persistence is the specified behaviour: the refusal arrives after the URL is corrected, and `scope.test.mjs`'s DW-8 row pins that it survives. I applied the clear-on-listed fix and that row went red; reverted.
  - `[medium]` `[patch]` The `role="status"` region is created together with its text, so it does not announce — verified against the project's own `command-bar.ts:73` and its rule at `:152`. Region now mounted unconditionally and empty.
  - `[medium]` `[defer]` The trigger has no accessible name saying what it controls — verified; AC1's listbox name is satisfied, and the fix changes a header control's announced name under DW-139's escalated DESIGN/EXPERIENCE divergence. Deferred with both candidate fixes.
  - `[medium]` `[patch]` `entity-ref.test.mjs`'s corpus is not the corpus its header claims — verified: `Corpus()` carries 17, the file carried 10, and it included `a~b` which `entity-id.test.mjs` deliberately excludes. All 17 now present; the claim states why `a~b` belongs to a key grammar.
  - `[medium]` `[patch]` `Screen/Registry.cls`'s header claims a build gate that does not exist — verified: `screen-mirror.mjs` only emits `scope` (:263) and `check-objectscript.py` has no scope check. Sentence corrected to say what is true; the gate itself deferred.
  - `[medium]` `[defer]` `GetAllNSInfo` is called with `DontConnect` defaulted to 0, once per namespace per request — verified against `irislib/%SYS/Namespace.cls:80`; free on this container, and the fix changes which namespaces are listed on instances that cannot be tested here.
  - `[low]` `[patch]` The install-namespace skip is justified by a note about the code database while the check tests the global database — verified at `Router.cls:165-169`; no escalation (IRIS still protects the globals), so the defect is the justification. Sentence corrected to the real reason.
  - `[low]` `[patch]` `Kernel/Scope.cls` claims a guarantee `Kill`-then-`Set` does not provide — verified: `^||OcuPilotScope` is a scalar node. Claim corrected to name `OnPreDispatch`'s `Clear()`, and the redundant `Kill` removed.
  - `[low]` `[reject]` `RouterFixture.MayEnterNamespace` re-implements the pair spelling — a spelling change goes red in `Test/Wire.cls`, which asserts `%DB_IRISSYS:READ` against the real gate; the fix adds fixture indirection for no extra coverage.
  - `[low]` `[reject]` The 403-with-no-pair branch is never exercised through the router — not reachable there: every namespace `Exists()` admits on this instance reports a guarding resource, so the branch needs a state not shown reachable.
  - `[low]` `[reject]` `Test/Routing.cls` reads the new codes two ways — the literal assertion pins the wire value, which is the stronger contract for a wire test; not a defect.
  - `[low]` `[patch]` `header.spec.ts`'s new comment says the header no longer parses `?ns=` — verified false: `header.ts:92` and `:111` still call `withQuery`. Comment corrected.
  - `[low]` `[reject]` Three `ns`-on-a-URL functions now live in three modules — real drift with a named future cost, but the fix moves a public export between modules and adds a test file; not a direct correction.
  - `[low]` `[patch]` The client mirror spells `'namespace'` as a bare literal — `NAMESPACE_SCOPE` exported beside `INSTANCE_SCOPE` and used by `scopeFor`.
  - `[low]` `[patch]` The dotted underline runs under the caret glyph — verified: declared on the trigger, so it spans the caret span; `design-tokens.test.mjs:377` asserts only `color`, so the move is safe. Moved to the value span. The padding/hover half needs a browser and stays the lead's Manual check.
  - `[low]` `[reject]` An empty offered set still opens an empty popup — needs a principal readable everywhere and writable nowhere, and suppressing or disabling the trigger is a design call EXPERIENCE.md's privilege rule bears on.
  - `[low]` `[reject]` `scopedPath` concatenates, so a path already carrying `ns` or a fragment misbehaves — no caller passes either to `ApiService.request`; theoretical hardening.
  - `[medium]` `[defer]` `reload()` joins an in-flight map read — mechanism verified; the wrong-verdict harm needs a namespace-scoped verdict and every Epic 1 verdict is an instance-wide `%Admin_*` pair.
  - `[low]` `[patch]` The spec's frontmatter and its run-result section disagreed on status — an artefact of this run's staging; finalize sets `done` and rewrites the section.
  - `[low]` `[reject]` The spec is flagged `oversized` and grew — triage rejects findings whose fix is to edit this build's spec; finalize keeps the run result inside the budget.
  - `[medium]` `[patch]` (edge-case) `reset()` during an in-flight read reinstates the signed-out principal's list — same root cause as the generation guard above.
  - `[medium]` `[patch]` Sign-out's `scope.reset()` drops the resolved scope to `''`, which wakes the map read the same sign-out just dropped — verified: `app.ts` resets navigation then scope, and the scope change publishes. `main.ts` now guards on `scope.loaded()`.
  - `[medium]` `[patch]` The one `scope.load()` failing leaves `loadedOnce` false for the session, with no retry and no other caller — same root cause as the single-loader finding above.
  - `[medium]` `[patch]` A `?ns=` in another case is admitted and stashed verbatim — verified live: `Exists("user")` = 1, `GetAllNSInfo("user")` returns `%DB_USER`, `MayEnter("user")` = 1, while the roster carries `USER`. Added `Router.CanonicalNamespace` and a pinning test.
  - `[low]` `[reject]` A namespace whose global database is dismounted is still listed and enterable — an operator-caused state; IRIS still refuses the reads, and the guard cannot be demonstrated without dismounting a database, which this run is forbidden to do.
  - `[medium]` `[defer]` (edge-case) `GetAllNSInfo` connection attempts on ECP namespaces — same root cause as the `DontConnect` finding above.
  - `[low]` `[reject]` (edge-case) A trigger that opens an empty listbox — same root cause as the empty-offered-set finding above.
  - `[low]` `[reject]` (edge-case) The refusal persists after the route reaches a resolvable namespace — same root cause as the refusal-clearing finding above.
  - `[medium]` `[patch]` (edge-case) The live region is inserted with its content — same root cause as the `role="status"` finding above.
  - `[low]` `[patch]` `.ocu-namespace-switch-value` is a flex item with `min-width: auto`, so a long name overflows instead of ellipsizing — `min-width: 0` added.
  - `[medium]` `[patch]` (edge-case) The Registry header's build-gate claim — same root cause as the Registry finding above.
  - `[medium]` `[patch]` (edge-case) The corpus parity claim — same root cause as the corpus finding above.
  - `[low]` `[patch]` (edge-case) The `Kill`-then-`Set` claim — same root cause as the `Kernel/Scope.cls` finding above.
  - `[medium]` `[defer]` (edge-case) The Integration AC against an in-flight map read — same root cause as the `reload()` finding above.
  - `[medium]` `[patch]` (gap, pre-verified) `main.ts`'s three new wirings are executed by no test — verified: `session.test.mjs:2153` is the established mechanism and carries clauses for `onForbidden` and `OverlayStack` but none for these. Added all three, plus a composed test building the real `ApiService`, `ScopeService` and `NavigationService` over one stub `fetch`.
  - `[medium]` `[patch]` (gap, pre-verified) Sign-out's `scope.reset()` is unobserved — `app.spec.ts`'s `StubScope` now records `load`/`reset`, and a sign-out test asserts the reset.
  - `[medium]` `[defer]` (gap, pre-verified) The new `scope` refusal is not adopted by the two build gates — deferred; the false header sentence it rests on was corrected in this pass.
  - `[low]` `[patch]` (gap, Rule 19) `scope.test.mjs`'s `assert.equal(entries.length, 3)` asserts a literal declared nine lines above it and cannot fail — deleted; the claim it stood for is pinned against a real service later in the file.
  - `[low]` `[reject]` (gap, Rule 19) `strings.test.mjs`'s `REQUIRED_ALONGSIDE_TABLE.length === 3` is the same shape — it pins a Never-clause of the intent contract, so deleting it loses a tripwire the spec asked for.
  - `[low]` `[reject]` (gap) `screen-outlet.ts` still parses the route's `ns` itself — pre-existing from Story 1.10; no screen reads `data-ns` yet and 1.14 owns the re-fetch routing.
  - `[medium]` `[defer]` (intent) The diff sends the `ns` the matrix's unknown-`ns` row says it never sends — verified; the row's rationale clause and the DW-8 AC cannot both hold literally, the implementation follows the AC, and amending a frozen matrix is the lead's under Rule 5.
  - `[medium]` `[patch]` (intent) The Integration AC is exercised as four disjoint stubs with the joining lines untested — same root cause as the `main.ts` gap above; the composed test closes it.
  - `[false]` `[reject]` (intent) `screen-outlet.spec.ts` pins code this story did not touch — pinning a behaviour the story depends on is regression pinning; `data-ns` being older does not make the assertion vacuous.
  - `[low]` `[reject]` (intent) The percent-encoding row asserts the decode pre-applied — the real decode is exercised over HTTP in `Test/Wire.cls` on the denied path, which proves the server saw `%SYS`; a successful `%SYS` entry would need a throwaway principal granted `%DB_IRISSYS:READ`, which this run must not create.
  - `[false]` `[reject]` (intent) The triple crosses no boundary — the spec's Design Notes state exactly that under Rule 1, naming 1.14 and Epic 5 as the first consumers.
  - `[medium]` `[patch]` (intent) The named pair reaches no one — same root cause as the `role="status"` finding; with the region mounted the announcement fires.
  - `[low]` `[reject]` (intent) The service owns the value while a component owns both its inputs, costing a second map read per sign-in — one extra `/navigation` per sign-in, not user-visible; removing it would mean not reading the map until the list lands.

## Design Notes

**Governing architecture decisions (Rule 6).** AD-44 (namespace is data scope; switching re-fetches rather than re-routes), AD-13 (one path segment, one codec, and the `(type, scope, id)` triple), AD-8 (privilege is the caller's, per call, denials naming the pair), AD-21 and AD-48 (the namespace comes from the set the user can read, never from a caller string), AD-16 (explicit save/restore where `%SYS` is reached — not reached here), AD-12 / AD-39 (one envelope, one writer, a dotted-uppercase `code`), AD-5 (the descriptor's `scope` is the declaration this story finally validates and consumes), AD-14 (the triple is what a change event will carry), AD-19 / AD-20 (client model and absolute paths), AD-36 (the read contract is uniform), AD-29 (a port declares its own gate). Conventions rows: REST route ordering, Ids and keys, Error shape, ObjectScript naming, Angular naming, Status handling. No AC here contradicts an AD's Rule.

**Decision (overnight) — the switch offers writable namespaces; the route honours readable ones (DW-7).** `epics.md:1397` and `EXPERIENCE.md:315` both say the switch lists only namespaces the user can read *and* write, so it is built that way. DW-7's harm — read-only screens becoming unreachable — is answered where it bites instead: `/namespaces` reports `writable` and its `failedPair` for **every** readable namespace, the request gate admits any namespace the caller can read, and a route already scoped to a read-only one is honoured and scopes every read there. **Residual, for the lead:** once a user leaves a read-only namespace the switch will not take them back. The endpoint already carries the verdict, so reversing the rule is a filter change in `namespace-switch.ts` and nothing else.

**Decision (overnight) — the switch is a listbox, not a native `<select>`.** `EXPERIENCE.md:315` calls it "a select"; `DESIGN.md:1007` draws an eyebrow over a value with a dotted 1px underline and a `▾` glyph, which no native select chrome produces, and `EXPERIENCE.md`'s own privilege-gating rule rejects natively-disabled options. Built as the trigger-plus-`role="listbox"` pattern `command-box.ts` established, on the same overlay stack. "No dialog" is honoured: nothing modal opens.

**Decision (overnight) — a bad `ns` is refused at the gate and recovered from without new copy.** The namespaces read is the one call that never carries `ns`, so a hand-typed or stale namespace cannot lock the shell out of the list that would fix it. Recovery replaces the parameter with the resolved scope using `replaceUrl` so Back is not polluted. Where the cause is a missing pair the shell names it with the published `Requires <resource>`; where the namespace simply does not exist **no published sentence exists** — `EXPERIENCE.md`'s Fixed-strings table has no namespace row — so the fallback is silent and the missing row is filed against DW-126's root cause with Story 1.13, which owns the uniform error surface, as the place a sentence should land. No string is invented here.

**Decision (overnight) — the context chip is Epic 5's.** `EXPERIENCE.md:326` places the chip at the top of the agent transcript, which does not exist in Epic 1. The scope-change channel this story publishes is what the chip will subscribe to; that channel, not the chip, is this story's observable.

**A reference key is not a URL segment.** `EntityId.Encode` percent-encodes twice because the web server decodes once in transit, so `Decode(Encode(x)) '= x` by design. Building a key from that pair would be the "call `Decode` more than once" failure the codec's own header warns about. The key therefore reuses the `COMPOSITESEPARATOR` idea with its own code point and leaves the URL codec untouched.

**AD-48's boundary, recorded before it is crossed.** The request's `ns` and `Kernel.Scope` are the *route's* scope. `LogSourcePort` takes its namespace as an explicit call parameter from the screen's descriptor state and must not read this stash — two sources would let a compliant delete purge a namespace other than the one on screen. Nothing in this story reads the stash from a port.

**Integration ACs (Rule 1).** `Kernel.Scope` has two consumers in this story: `Api.Namespaces` echoes it and `Kernel.EntityRef.ScopeFor` resolves the scope half from it. `ScopeService`'s consumer is `NavigationService` (the Integration AC above). `Kernel.EntityRef` and `core/entity-ref.ts` have **no production consumer in this story** — nothing writes yet, so nothing publishes a change event; the first consumers are Story 1.14's re-fetch routing and Epic 5's proposal targets and audit markers.

**Ledger inbox (Rule 17).** DW-7 — addressed as above, with its residual stated. DW-8 — a matrix row, a task and an AC, server and client, with the unknown-namespace sentence filed rather than invented. DW-33 — addressed: the stash and its two first consumers land together, which is what the entry's own note asked for.

**Consumes:** 1.1 (`Api.Response`, `Api.Error`, `Kernel.EntityId`, `Kernel.EntityType`), 1.3 (`Kernel.Utils`), 1.5 (`Api.Router` ordering invariants, `Test.Http`, `Test.Dispatch`), 1.8 (`core/instance.ts`), 1.9 (`Screen.Registry`, `Screen.Gate`, `core/navigation.ts`, `core/screens.generated.ts`, the component runner), 1.10 (`header.ts`'s slot, `withQuery`, `core/overlay-stack.ts`, `screen-outlet.ts`'s `namespace()`).

**Consumed-by:** 1.12 — Home's instance line reads the resolved scope; 1.13 — owns the sentence a bad namespace should carry and the uniform error surface behind `NS.UNKNOWN` / `NS.DENIED`; 1.14 — subscribes to the scope-change channel and routes a re-fetch on `entityRefKey`; Epic 2 onward — every slice read runs against `Kernel.Scope.Current()` and every write's proposal target carries `EntityRef.Wire`; Epic 5 — the context chip's `<Screen>, <NAMESPACE>` segment and the proposal target.

**Not resolved here.** DW-126 (EXPERIENCE.md publishes no Fixed-strings rows for several surfaces this epic renders) stays escalated; this story adds no string and grows no table.

## Verification

**Environments.** Every check runs against the live `ocupilot` container (web 52774, SuperServer 1973) through the IRIS MCP tools with **`server: "ocupilot-iris"`** on every call. That container must **not** be recreated: no `docker compose up` / `down` / `restart` against this repository's compose file (`ps`, `logs`, `exec`, `cp` are safe). **Nothing in this story creates, deletes, mounts or dismounts a namespace or a database**, so **no throwaway container is required** — enumeration and entry are read-only, and every privilege case is exercised by purpose-built throwaway *principals* in the `Test/Wire.cls:68-118` pattern (random in-memory password, created in `%SYS` inside an explicit switch/restore, the privilege difference proved with `CheckUserPermission` before any test runs, all of them deleted and re-tested in `OnAfterAllTests:130-165`). No real account is created, modified, locked or expired — `_SYSTEM` is the owner's working account and holds a live browser session. If a case ever needs a namespace that does not exist, it belongs on a separate scratch compose project with its own project name, container name, host ports (never 52774/1973) and scratch volume, torn down with `down -v` — not on this instance.

**One test class per tool call.** Send **one** `iris_execute_tests` call per message, wait for it to land in `%UnitTest_Result`, and never re-submit on a client-side timeout — a returned call is not a finished run, and these classes share one instance.

**Commands:**

- `npm --prefix ui test` — expected: green; the Node tool suite and the component suite both run.
- `npm --prefix ui run build` — expected: exit 0, `client-lint: clean`, `initial` under the 1MB budget.
- `uv run scripts/check-objectscript.py` — expected: no findings.
- `bash scripts/lint-docs.sh` — expected: clean.
- `iris_doc_load` then `iris_doc_compile` on `src/OcuPilot/` (`server: "ocupilot-iris"`) — expected: clean compile.
- `iris_execute_tests` on `OcuPilot.Test.Namespaces`, then `OcuPilot.Test.EntityRef`, then `OcuPilot.Test.Routing`, then `OcuPilot.Test.Descriptor`, then `OcuPilot.Test.Wire` — one class per message, totals confirmed by the `%UnitTest_Result` SQL probe in `.claude/rules/objectscript-testing.md`.

**Pinning tests (Rule 19) — one per acceptance criterion:**

- The switch lists writable namespaces and is named `Namespace` → `namespace-switch.spec.ts`, over `ui/tools/scope.test.mjs` for the filter and `OcuPilot.Test.Namespaces` for the verdicts behind it.
  `mutation: made writableNamespaces return every entry → scope.test.mjs's DW-7 filter row and its select row red, and namespace-switch.spec.ts's AC1 row red alone among the 124 component tests; observed and reverted`
- Selection replaces `ns` and nothing else; the outlet is not re-created → `namespace-switch.spec.ts` with `screen-outlet.spec.ts`.
  `mutation: made withNamespace emit ns alone instead of rejoining the other pairs → scope.test.mjs's withNamespace row and namespace-switch.spec.ts's AC2 row red (the page parameter and the fragment were lost); observed and reverted`
- Every request carries the resolved scope; `OnPreDispatch` stashes it; a handler reads it back (**DW-33**) → `OcuPilot.Test.Namespaces` and `OcuPilot.Test.Routing` for the server half, `ui/tools/api.test.mjs` for the attachment and for the namespaces read sending none.
  `mutation: deleted Kernel.Scope.Set from OnPreDispatch → Routing's stash row and Namespaces' through-the-router row red, both reading the install namespace; separately, made ApiService.scopedPath always return the caller's path → api.test.mjs's three scope rows red; both observed and reverted`
- The reference triple, and two namespaces making two entities → `OcuPilot.Test.EntityRef` with `ui/tools/entity-ref.test.mjs`.
  `mutation: dropped the scope from the key in Kernel.EntityRef.Key → TestOneNameInTwoNamespacesIsTwoEntities red on "the same task name in two namespaces is two keys"; observed and reverted`
- The id corpus round-trips through one codec, in a route and in a key → `OcuPilot.Test.EntityId` and `OcuPilot.Test.EntityRef` over the shared `Corpus()`, with `ui/tools/entity-id.test.mjs`.
  `mutation: built the key from Kernel.EntityId.Encode → OcuPilot.Test.EntityRef 3 of 7 red, naming 10 corpus rows; the same change in core/entity-ref.ts → 4 of 7 entity-ref.test.mjs rows red; both observed and reverted`
- **Integration AC** (the scope's consumer re-reads with the new `ns`, the path unchanged) → `ui/tools/navigation.test.mjs` and `ui/tools/scope.test.mjs`, with `namespace-switch.spec.ts` for the URL.
  `mutation: made onScopeChange call its listener on every notification rather than on a changed resolution → scope.test.mjs's Integration row red on its selection assertion, which sees three notifications where the resolution moved twice; the later repeat assertion is guarded by setRequested's own early return, not by onScopeChange (re-verified at review, attribution corrected)`
- **DW-8** (400 `NS.UNKNOWN`, 403 `NS.DENIED` with the failed pair, client fallback) → `OcuPilot.Test.Wire` over real HTTP as a throwaway principal, with `ui/tools/scope.test.mjs` for the fallback and `namespace-switch.spec.ts` for `replaceUrl` and the named pair.
  `mutation: deleted the MayEnterNamespace block from OnPreDispatch → Wire's over-the-wire row red with a 200 and a version report for a principal holding no %DB_IRISSYS:READ, and Routing's in-process row red on all five assertions; observed and reverted`
- **DW-7** (a readable, non-writable namespace is reported, not offered, and still scopes reads) → `OcuPilot.Test.Namespaces` for `writable:false` with its `failedPair`, `OcuPilot.Test.Wire` for the honoured route, `ui/tools/scope.test.mjs` for the switch's filter.
  `mutation: set writable from the READ check instead of the WRITE check in Api.Namespaces.Payload → TestAReadableNamespaceThatIsNotWritableIsListedWithItsFailedPair red on both the verdict and the pair; observed and reverted`
- A descriptor declaring a scope outside the two is refused by the registry → `OcuPilot.Test.Descriptor`.
  `mutation: added a third accepted spelling to the pair Screen.Registry.Validate admits → TestADeclaredScopeOutsideTheTwoIsRefusedByTheRegistry red on all three refusal assertions; observed and reverted`

**QA stage (2026-09-12) — closing the four deferred gaps:**

- **DW-155**, the switch's accessible name — `header.ts`'s eyebrow gained an `id`, the switch's value span gained one too, and the trigger now carries `aria-labelledby` pairing them, the `account-menu.ts` pattern. No new string. → `ui/src/app/shell/header.spec.ts` (QA).
  `mutation: removed aria-labelledby from the trigger → the new DW-155 row in header.spec.ts red (expected 2 labelledby ids, got 0); observed and reverted`
- **DW-157**, `reload()` joining an in-flight map read — pinned, not fixed: a naive queue-behind-the-current-read fix was written and tried, and it makes `reload()` queue a second `load()` once the in-flight one settles. Run in isolation this flips the new pin red as expected (2 calls, not 1). Run against the whole file it also hangs the process: the existing `noteForbidden()`-inside-`requestJson` test in this same file calls `reload()` from inside every settling read, so the same fix turns that one 403 into an unbounded chain of reads — confirmed by a genuine hang, killed rather than waited out. That hazard, not "small and safe," is why this gap stays deferred rather than fixed in this pass. → `ui/tools/navigation.test.mjs` (QA).
  `mutation: made reload() queue this.load() behind the in-flight promise instead of joining it → the new DW-157 row red in isolation (api.calls.length 2 !== 1); the full file additionally hangs via the pre-existing DW-9 "re-reads nothing" test's self-referencing stub, so the mutation was verified against the isolated test (--test-name-pattern) and then reverted`
- **DW-158**, the scope build gates — `scripts/check-objectscript.py` and `ui/tools/screen-mirror.mjs` now refuse a descriptor's declared `scope` outside `OcuPilot.Kernel.Scope`'s two Parameter values, read from that class rather than duplicated as a literal pair, the same shape as the existing entity-type gate. `Screen/Registry.cls`'s header comment corrected: it no longer claims neither build gate reads `scope`. → `scripts/test_check_objectscript.py` (QA, `TestScreenScopeRule`), `ui/tools/screen-mirror.test.mjs` (QA).
  `mutation: made check_screen_scope's refusal condition unreachable (if False) → test_a_third_spelling_is_refused_naming_the_file_and_the_value red (expected the value refused, got none); observed and reverted`
  `mutation: made the JS scope check unreachable the same way in buildMirror → the AD-13 scope-refusal row in screen-mirror.test.mjs red (missing expected exception); observed and reverted`
- **DW-156**, `GetAllNSInfo` connecting per namespace when `DontConnect` defaults to 0 — left as deferred. This container has six local namespaces and no ECP- or remote-mapped one (probed at Story 1.11's implement stage), so the hazard cannot be pinned here without a namespace this run is forbidden to create; a test asserting against a namespace this instance does not have would be unfalsifiable rather than a real pin. No test added.

**Code-review stage (2026-09-12) — the five gaps patched in the review pass:**

- **One namespace is one scope spelling, on both sides of the wire.** `CanonicalNamespace`'s pattern
  now admits the dash and underscore IRIS documents as legal after the first character, and
  `core/scope.ts` gained `canonicalNamespace()` mirroring it, applied in `setRequested` and
  `select`. → `OcuPilot.Test.Routing` (server), `ui/tools/scope.test.mjs` (client).
  `mutation: narrowed the server pattern back to ^[A-Za-z%][A-Za-z0-9%]*$ → TestANamespaceNamedInAnotherCaseResolvesToOneScope red on both the dash and the underscore assertions (Routing 17/18, runIndex 924); made the client canonicaliser the identity function → scope.test.mjs's two canonicalisation rows red; both observed and reverted (Routing 18/18, runIndex 925)`
- **The generation guard is pinned.** Two rows hold a read open across `reset()`, one per await.
  → `ui/tools/scope.test.mjs`.
  `mutation: deleted the generation check from runLoad → "AD-8: a list answered after a reset settles nothing" red alone (20/21); observed and reverted`
- **`detail` is read from a real envelope.** The path `%DB_USER:READ` takes to the user is parsed
  rather than hand-built by both consumer suites. → `ui/tools/api.test.mjs`.
  `mutation: made envelopeDetail return null unconditionally → the DW-8 detail row red alone (35/36); observed and reverted`
- **`main.ts`'s `loaded()` guard is matched in the callback body**, not only at the call site.
  → `ui/tools/session.test.mjs`.
  `mutation: dropped "if (scope.loaded())" from main.ts's onScopeChange callback → the main.ts bootstrap row red (82/83); observed and reverted`
- **A declaration naming no `scope` is refused at the build gate**, closing DW-158's other half:
  `Screen.Registry.Validate` refuses `""` on the instance, so the omitted case was failing at
  runtime and passing the build. → `scripts/test_check_objectscript.py`.
  `mutation: made check_screen_scope's omitted-scope branch unreachable (if False) → test_a_declaration_naming_no_scope_is_refused red (expected the omitted scope refused by file, got []); observed and reverted`
- **The DESIGN.md treatment is pinned.** The dotted 1px underline and the `min-width: 0` that makes
  the ellipsis reachable are asserted as stylesheet text. → `ui/tools/design-tokens.test.mjs`.

Whoever adds or materially changes a pinning test writes its `mutation:` line in the same pass: name the smallest change that violates the AC, apply it, observe red, revert, and confirm `git status --short` and `git diff --stat` are unchanged.

**Manual checks:**

- Desktop Chrome against the live instance at `http://localhost:52774/ocupilot/`: the switch sits in the header's right slot at the gradient's `shell-edge` end with the eyebrow at 100%, the dotted underline and the `▾`; keyboard open, arrow, Enter and Escape; Escape order across the switch, the command box and the side bar; and the URL after a selection — path unchanged, only `ns` different, no reload.
- **Rendered geometry and contrast (lead, browser MCP per Rule 7):** the trigger and its popup stay inside the 48px band and the popup does not overflow the viewport at 400px; `on-shell` at 100% over the gradient's end measures the 5.35:1 light / 6.43:1 dark `DESIGN.md:821` states. jsdom computes no layout, so neither is a claim the component suite makes.

## Auto Run Result

Status: done
Blocking condition: none

**What shipped.** Server: `Kernel/Scope.cls` (the request-scoped namespace and the two scope
words), `Kernel/EntityRef.cls` (the AD-13 triple), `Api/Namespaces.cls` behind `GET /namespaces`,
the entry check plus the stash in `OnPreDispatch` with `NS.UNKNOWN`/`NS.DENIED` promoted to
`Api.Error` parameters, and the scope refusal in `Screen.Registry.Validate`. Client:
`core/scope.ts`, `core/entity-ref.ts`, `?ns=` attached in `ApiService.request`, `detail` on the
error result, `NavigationService.reload()`, `shell/namespace-switch.ts` in the header's slot, and
its stylesheet rules from existing tokens. No string was added; `REQUIRED_ALONGSIDE_TABLE` is
still three.

**Files changed.** Server, new: `Kernel/Scope.cls`, `Kernel/EntityRef.cls`, `Api/Namespaces.cls`,
`Test/Namespaces.cls`, `Test/EntityRef.cls`, `Test/NamespaceFixture.cls`, `Test/ScopeRegistry.cls`,
`Test/Scope/Bad.cls`. Server, extended: `Api/Router.cls`, `Api/Error.cls`, `Screen/Registry.cls`,
`Test/RouterFixture.cls`, `Test/Routing.cls`, `Test/Descriptor.cls`, `Test/Wire.cls`. Client, new:
`core/scope.ts`, `core/entity-ref.ts`, `shell/namespace-switch.ts` and its spec,
`tools/scope.test.mjs`, `tools/entity-ref.test.mjs`. Client, extended: `core/api.ts`,
`core/navigation.ts`, `app.ts`, `main.ts`, `shell/header.ts`, `styles/_components.scss`, and the
`api`, `navigation`, `strings`, `design-tokens` and `session` tool suites plus `app.spec.ts`,
`header.spec.ts` and `screen-outlet.spec.ts`.

**Review.** Four layers, 50 findings: high 0, medium 23, low 25, false 2. Sixteen entries patched
in-pass (9 medium, 7 low), five deferred, the rest rejected on their refutation — every one
recorded with its evidence in `## Review Triage Log`. The patches: a generation guard on
`ScopeService` so a sign-out cannot be overtaken by its own in-flight read; `App` loading the
namespace list so one transient failure no longer costs the switch for the session; a `loaded()`
guard so sign-out does not wake the map read it just dropped; the `role="status"` region mounted
rather than created with its text, so the refusal actually announces; `Router.CanonicalNamespace`,
because the instance admits `?ns=user` and the roster says `USER`; three `main.ts` clauses and a
composed test that builds the real `ApiService`, `ScopeService` and `NavigationService` over one
stub `fetch`; a recorded `scope.reset()` on sign-out; the client id corpus aligned to all
seventeen; one unfalsifiable assertion deleted; and four doc claims corrected at their origin.

**Verification.** `npm --prefix ui test` 345 Node + 124 component, green (corrected by the lead after QA and review added tests). `npm --prefix ui run
build` exit 0, `client-lint: clean`, initial 335.26 kB. `check-objectscript.py` and
`lint-docs.sh` clean. `iris_doc_load` + `iris_doc_compile` on `src/OcuPilot/` clean, 100/100. One
`iris_execute_tests` call per class: `Namespaces` 8/8, `EntityRef` 7/7, `Routing` 18/18,
`Descriptor` 13/13, `Wire` 13/13, plus the regression classes the edits could reach — `Instance`
21/21, `Envelope` 12/12, `Navigation` 11/11 — confirmed against `%UnitTest_Result` by the SQL
probe in `.claude/rules/objectscript-testing.md`. Every matrix row has a covering test that ran
and passed. All nine `mutation:` lines were applied, observed red and reverted by the stage agent
itself (eleven applications: the scope, id-corpus and DW-8 lines have a server and a client half),
with the whole working tree byte-identical to its pre-mutation state afterwards by SHA-256 of the
full diff; the two tests added during review carry their own demonstrated mutations.

**Follow-up review recommended: true** — nine medium entries were patched. The specific unverified
risk: the patches changed the server's namespace resolution and the client's scope lifecycle
(the generation guard, the App-level load, the sign-out guard) and the live region's mounting, and
none of that has been seen in a browser — the container still serves the pre-1.11 bundle, so the
Manual checks below need a redeploy the owner owns.

**Residual risks.**

1. **The rendered surface is unobserved.** The dotted underline (now on the value, not the
   button), the popup inside the 48px band, the glyph and the `on-shell` contrast at the
   gradient's end are asserted as stylesheet text; jsdom computes no layout. Lead's browser gate.
2. **One extra request in the failure case.** A requested namespace the list does not carry costs
   one scoped read, at most once per name, and its 403 also reaches `onForbidden`.
3. **DW-7's residual stands as the spec states it** — leaving a read-only namespace is one-way
   through the switch; reversing it is a filter change in `writableNamespaces`.
4. **Five deferred items** are in the frontmatter `deferred:` list for the lead to harvest, two of
   which bear on later stories: `reload()` joining an in-flight map read (the first
   namespace-scoped verdict makes it real) and the matrix's unknown-`ns` rationale clause, which
   the DW-8 acceptance criterion contradicts and only the lead can amend.
