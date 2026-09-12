---
title: 'Story 1.11 — The namespace switch as data scope'
type: 'feature'
created: '2026-09-12'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-1-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-1-10-header-status-bar-and-page-chrome.md'
  - '{project-root}/.claude/rules/objectscript-testing.md'
warnings: ['oversized']
deferred: []
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
| **DW-8** unknown `ns` | `?ns=NOPE` | 400 `bad_request` / `NS.UNKNOWN` (unchanged); the client reads the list without `ns`, so it never sends one | falls back to the echoed `scope`, `replaceUrl` |
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

- `src/OcuPilot/Kernel/Scope.cls` *(new)* — the request-scoped resolved namespace: `Set(pNamespace)`, `Current()` (falls back to `$Namespace` when unset), `Clear()`, and `Parameter SCOPEINSTANCE = "instance"`. Backed by a process-private global holding a string; `Set` kills before it writes so a value cannot survive into the next request on a reused process.
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

## Spec Change Log

## Review Triage Log

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
  `mutation: _(implement stage)_`
- Selection replaces `ns` and nothing else; the outlet is not re-created → `namespace-switch.spec.ts` with `screen-outlet.spec.ts`.
  `mutation: _(implement stage)_`
- Every request carries the resolved scope; `OnPreDispatch` stashes it; a handler reads it back (**DW-33**) → `OcuPilot.Test.Namespaces` and `OcuPilot.Test.Routing` for the server half, `ui/tools/api.test.mjs` for the attachment and for the namespaces read sending none.
  `mutation: _(implement stage)_`
- The reference triple, and two namespaces making two entities → `OcuPilot.Test.EntityRef` with `ui/tools/entity-ref.test.mjs`.
  `mutation: _(implement stage)_`
- The id corpus round-trips through one codec, in a route and in a key → `OcuPilot.Test.EntityId` and `OcuPilot.Test.EntityRef` over the shared `Corpus()`, with `ui/tools/entity-id.test.mjs`.
  `mutation: _(implement stage)_`
- **Integration AC** (the scope's consumer re-reads with the new `ns`, the path unchanged) → `ui/tools/navigation.test.mjs` and `ui/tools/scope.test.mjs`, with `namespace-switch.spec.ts` for the URL.
  `mutation: _(implement stage)_`
- **DW-8** (400 `NS.UNKNOWN`, 403 `NS.DENIED` with the failed pair, client fallback) → `OcuPilot.Test.Wire` over real HTTP as a throwaway principal, with `ui/tools/scope.test.mjs` for the fallback and `namespace-switch.spec.ts` for `replaceUrl` and the named pair.
  `mutation: _(implement stage)_`
- **DW-7** (a readable, non-writable namespace is reported, not offered, and still scopes reads) → `OcuPilot.Test.Namespaces` for `writable:false` with its `failedPair`, `OcuPilot.Test.Wire` for the honoured route, `ui/tools/scope.test.mjs` for the switch's filter.
  `mutation: _(implement stage)_`
- A descriptor declaring a scope outside the two is refused by the registry → `OcuPilot.Test.Descriptor`.
  `mutation: _(implement stage)_`

Whoever adds or materially changes a pinning test writes its `mutation:` line in the same pass: name the smallest change that violates the AC, apply it, observe red, revert, and confirm `git status --short` and `git diff --stat` are unchanged.

**Manual checks:**

- Desktop Chrome against the live instance at `http://localhost:52774/ocupilot/`: the switch sits in the header's right slot at the gradient's `shell-edge` end with the eyebrow at 100%, the dotted underline and the `▾`; keyboard open, arrow, Enter and Escape; Escape order across the switch, the command box and the side bar; and the URL after a selection — path unchanged, only `ns` different, no reload.
- **Rendered geometry and contrast (lead, browser MCP per Rule 7):** the trigger and its popup stay inside the 48px band and the popup does not overflow the viewport at 400px; `on-shell` at 100% over the gradient's end measures the 5.35:1 light / 6.43:1 dark `DESIGN.md:821` states. jsdom computes no layout, so neither is a claim the component suite makes.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none
