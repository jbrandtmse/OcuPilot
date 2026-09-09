---
title: OcuPilot sibling harvest plan
status: draft
created: '2026-09-08'
updated: '2026-09-08'
---

# Sibling harvest plan

The PRD addendum §5 map, turned into file-level moves ordered by the PRD's build steps (§10.1). Per-repo detail: [iris-session-agent](iris-session-agent.md) · [iris-execute-mcp-v2](iris-execute-mcp-v2.md) · [iris-couch](iris-couch.md) · [iris-table-editor](iris-table-editor.md).

**The rule that governs all of it:** siblings are *pattern and code sources, never runtime dependencies* (PRD §8). Nothing OcuPilot ships may reference a sibling package, path, role, global, task or credential. Every rename table in the four maps is a checklist, not a suggestion.

## What the architecture changed about the harvest

Three spine decisions move work across the plan:

1. **AD-1 / AD-2 — tools call `%Api.Admin.Endpoints.*` in-process.** The PRD assumed the `ExecuteMCPv2` handler-body harvest would be Release 1 work *if* tools ran in-process. It resolved that way, but the vendor's own endpoints turn out to cover the six areas, so the handler harvest shrinks to **only what has no admin API route** — the log endpoints — plus Stage 5 parity. This is the single largest reduction in the plan.
2. **AD-23 — `RenderResponseBody` is the one seam.** When a handler body *is* harvested, it moves unedited; only the base class changes.
3. **AD-7 — the turn runs in a background job.** `iris-session-agent`'s `AgentLoop.RunTurn` is synchronous by construction, so the loop is a **rewrite against a harvested provider layer**, not a port.

## Step 0 — shell and install path

| Take | From | Into | Treatment |
|---|---|---|---|
| `Util/Response.cls` (33), `Util/Error.cls` (224) | iris-couch | `Api/` | Copy; rename slugs; keep the nested-`Catch` `Return $$$OK` rule and the `}{` assertion test (AD-12) |
| `Util/Log.cls` (101) | iris-couch | `Kernel/Audit/` | Copy; change the line prefix |
| Router thin-wrapper + `OnPreDispatch` structure, `ReportHttpStatusCode`, `Http405` | iris-couch `API/Router.cls` (762) | `Api/Router.cls` | Copy the **structure**, not the 90 CouchDB routes. Keep all three UrlMap ordering invariants |
| `AdminUIHandler.cls` (313) | iris-couch | `Api/StaticHandler.cls` | Copy: traversal checks (both the `..` literal and the post-normalization prefix check), `IsHashedAsset` cache headers, deep-link fallback, 32 KB streaming |
| `Utils.cls` (1163) — `SwitchNamespace`/`RestoreNamespace`, `ValidateRequired/String/Integer/Boolean`, `SanitizeError`, `ApplyOutputCeiling`, `SurrogateSafeCutLength`, `DecodeUtf8Stream`, `ReadRequestBody` | iris-execute-mcp-v2 | `Kernel/` | Copy; drop the `%Atelier` coupling. **Take this early** — everything downstream uses it |
| Installer idempotency shape (guard-then-act, re-run privileged steps on the existing-app path, `Uninstall` returns OK when absent), `$NAMESPACE` restore as the first line of every `Catch` | iris-couch `Installer.cls` (211) | `Install/Installer.cls` | Copy the shape. **Fix its gaps:** create the dedicated database and resource (AD-9), and generate the IPM manifest from the roster (AD-17) |
| `probeCustomRest` quad-state (`missing` / `current` / `unconfigured` / `stale`) | iris-execute-mcp-v2 `bootstrap.ts` | `Install/` | Port the **model** to ObjectScript; the self-heal and forced-recompile-on-`unconfigured` reasoning both transfer |
| `couch-api.service.ts` absolute-base-path discipline | iris-couch `ui/` | `ui/src/app/core/api.service.ts` | Copy the rule (AD-20). The rest of the service is CouchDB-shaped |
| `error-mapping.ts` + `feature-error.component.ts` | iris-couch `ui/` | `ui/src/app/core/` | Copy; the envelope shape matches AD-12 |
| `MakeRequest` static test helper | iris-couch `Test/HttpIntegrationTest.cls` | `Test/` | Copy including the JSON-vs-raw sniff and the configurable-endpoint accessors |

**Do not take:** iris-couch's cookie session (no `SameSite`, no `Secure`, no CSRF), its per-database RBAC, its `proxy.conf.js` route-exclusion regex, its `module.xml` (incomplete by its own account), the `%Atelier.REST` envelope, iris-execute-mcp-v2's TypeScript self-install, or its `%Development`-gated web application pattern.

## Step 1 — one live list per area

| Take | From | Into | Treatment |
|---|---|---|---|
| Nothing new | — | — | Step 1 rides on `AdminPort` (AD-2), which is OcuPilot's own ~40 lines reproducing `%Api.Admin.Dispatch.v1:Main()`. The reads come from the vendor's endpoint objects |
| `Metrics/{Collector,Record,Endpoint}.cls` (87 / 113 / 159) | iris-couch | `Kernel/` *(optional)* | Only if OcuPilot wants a Prometheus endpoint. The **cardinality-control** idea — `ClassifyEndpoint` never emitting an entity name — is the transferable part |

## Step 2 — agent core, one confirmed write per area

The largest harvest. From **iris-session-agent**, take nearly verbatim (~2,200 lines, rename-only):

| Take | Lines | Into | Treatment |
|---|---|---|---|
| `LLM/Provider.cls` | 598 | `Kernel/Provider/Base.cls` | Copy. Keep the never-throw discipline and the `Invoke()` template. **Add** configurable SSL and proxy support — both are hardcoded/absent |
| `LLM/AnthropicProvider.cls` | 757 | `Kernel/Provider/Anthropic.cls` | Copy. The only provider in the Release 1 floor |
| `LLM/{OpenAI,Gemini,OpenAICompat}Provider.cls` | 612 / 770 / 702 | `Kernel/Provider/` | Copy at **build step 7**, not before (owner trim: Anthropic only in the floor) |
| `LLM/Util/MessageAdapter.cls`, `ToolDefAdapter.cls` | 692 / ~190 | `Kernel/Provider/` | Copy with the other adapters at step 7; Anthropic is the canonical shape and needs no translation |
| `Util/RetryWithBackoff.cls` | 440 | `Kernel/Provider/` | Copy the pure helpers. Keep the inline retry loop and the **mid-flight idempotency rule** (a throw breaks without retrying) |
| `Util/EnvSecret.cls` | ~160 | `Kernel/Secret/` | Copy the ladder. **Swap rung 2** — `Ens.Config.Credentials` needs an interop-enabled namespace, which plain IRIS Community may not have (PRD OQ16) |
| `Agent/{CallerContext,TurnResult,ProviderResponse,ProviderOverride}.cls` | ~390 | `Kernel/Agent/` | Copy. Keep the invariant that tools never touch `%session`, `%request`, `$NAMESPACE` — it is exactly what AD-7's detached job requires |
| `Audit/{Emit,LlmCall,ToolCall}.cls` | 629 | `Kernel/Audit/` | Copy the dual-write and `EnsureEvents()`; extend for the agent marker (AD-15) |
| `Chat/History.cls` | 249 | `Kernel/Agent/` | Copy the per-conversation exclusive-lock protocol (`%OpenId(id, 4)`, both branches return an identically-locked OREF, guaranteed release on every exit path) |
| The locked cross-vendor JSON-Schema subset **rule** | `Tool/Base.cls` | `Screen/Tool/` | Copy the rule verbatim. It is what makes one tool array work across four providers |
| `Tool.Search.Base.BuildBoundedWhereClause` | 246 | `Screen/Tool/` | Copy the anti-runaway-query guard for any SQL-backed screen |
| The 11 config-form validation rules + XOR credential invariant + preserve-when-customized cascade | `UI/AgentConfig.cls` (1553) | `ui/` + `Api/` | Port the **contracts** to Angular reactive-form validators plus a REST save endpoint. Accumulate errors into one round-trip. **Keep the absence of an `ApiKey` property** — that absence is the schema invariant |

**Rewrite, do not port:** `Agent/AgentLoop.cls` (930) — synchronous by construction, and with no context-window trimming at all. AD-7 makes it a background job; AD-24 makes trimming mandatory. Take the 10-step flow and the max-iteration fallback as the design.

**Improve while porting:** `Tool/Registry.cls` (323) — replace the flat-`Super` equality SQL with `%IsA` or a recursive walk, and add the schema-driven argument validator the original lacks (validation is currently per-tool and hand-written).

From **iris-execute-mcp-v2**, port the governance **model** to ObjectScript (AD-22) — the key scheme, frozen baseline, null-coalescing cascade, fail-safe read-only preset, call-time gate placement, `GOVERNANCE_DISABLED` result, and the non-governable audit log. Also copy the `dryRun`/`confirm` double-gate's *structural* server-side refusal and its guard style: hard caps that **refuse** rather than truncate.

**Do not take:** the Zen chat panel, `chat-panel.js` (1944), `EnsPortal/*`, `UI/ChatPanel.cls`, `Sample/*` (1000), the 28 Ensemble tools (~7,400 lines), or `Search/*` vocabulary learning. Keep only the JSON envelope shapes from the panel: bootstrap context, tool-call card `{name, args, result, status}`, citation chip, lock-poll response.

## Steps 3–6 — remaining screens and editors

No new harvest. Every screen is a descriptor (AD-5) over `AdminPort` (AD-2). The work is descriptors and Angular pages, not ported code.

## Logs (step 1 and step 4)

| Take | From | Into | Treatment |
|---|---|---|---|
| The tail-with-byte-offset-paging pattern | new | `Port/LogSourcePort` | No sibling has it. `messages.log` and `alerts.log` are plain files in `$System.Util.ManagerDirectory()`; the endpoint takes a **fixed enum**, never a path (AD-21). The application error log is not a file — it is the `^ERRORS` global per namespace, owned by the same port (AD-48) |
| Application error log access | `SYS.ApplicationError` (`%SYS`) | `Port/LogSourcePort` | System class, not a harvest. **Not** `%CSP.ErrorLog`, which is the default CSP error *page*, not a store. Owned by the port, never by the slice (AD-48) |

## Stage 3 — System Explorer

From **iris-table-editor**, lift with zero host coupling: `SqlBuilder.ts` (201), `DataTypeFormatter.ts` (338), `UrlBuilder.ts` (88), `ErrorHandler.ts` (256), the model types (~650), `theme.css`'s 84-token contract (135), `grid-styles.css` (2064).

Port the three algorithms out of `grid.js` (6023, vanilla DOM): keyboard nav (3358–3553, 5894–6011, 3224–3357), filter logic (3681–4124), and staging/dirty cells (20–166, 587–666, 1597–2005, 2556–2890) — especially the PK-keyed reconciliation with stale-index recovery after pagination.

Rework the Atelier services: Basic is hardcoded, `(username, password)` are positional on ~9 methods, `Buffer.from` is Node-only, and 401 is terminal with no refresh hook. Introduce a transport seam. **Do not carry** the plaintext-password-in-server-memory session pattern.

## Stages 4–5 — interoperability and custom-REST parity

Harvest `ExecuteMCPv2.REST.*` handler bodies under AD-23 — inherit an OcuPilot base with the same `RenderResponseBody` signature so all 738 call sites move unedited. `REST/Interop.cls` (2728) for Stage 4; `Diagram/*` (1470, 7 classes) for the message-trace generator; `REST/Health.cls` (532) plus its TypeScript threshold layer for the composite health check; `REST/{Command,Global,UnitTest,EnvSync,SqlAdvisor}.cls` for Stage 5 parity.

## Rename checklist

Every name below must be absent from OcuPilot's source. The four per-repo maps carry the full inventories.

| Kind | Must not appear | OcuPilot uses |
|---|---|---|
| Packages | `SessionAgent.*`, `ExecuteMCPv2.*`, `IRISCouch.*` | `OcuPilot.*` |
| Web paths | `/csp/<ns>/sa-static/`, `/api/executemcp/v2`, `/iris-couch/`, `/iris-couch/_utils/` | `/ocupilot`, `/api/ocupilot` |
| Roles | `SessionAgent_ReadOnly`, `IRISCouch_Admin` | OcuPilot's own |
| Audit sources | `SessionAgent`, `IRISCouch` | OcuPilot's own |
| Globals | `^SessionAgent*`, `^SessionAgenC88B*`, `^IRISCouch*`, `^UnitTestRoot`, `^ExecuteMCPv2*` | `^OcuPilot*`, in the protected database (AD-9) |
| SQL schemas | `SessionAgent_Chat`, `_Audit`, `_Search`, `_Config` | OcuPilot's own |
| Credentials | `SessionAgentOpenAI` / `Anthropic` / `Gemini` | OcuPilot's own |
| Tasks | `SessionAgent.Purge*`, `SessionAgent.UserVocabularyDecay` | OcuPilot's own |
| SQL procedures | `ExecuteMCPv2.Setup_*` | OcuPilot's own |
| Tool prefix | `iris_*` | `<area>.<screen>.<verb>` |
| Env vars | every `IRIS_*` | none required at runtime |
| Mappings | `%ALL` mapping creation | a dedicated database with explicit mappings (AD-9) |
| JS / CSS | `window.SessionAgentChat*`, `--sa-*`, `--ite-*` (bridged, not adopted) | OcuPilot's tokens |

## Traps carried forward

- **`Security.Applications.Create()` does not notify the CSP Gateway** — a new web application may 404 until an SMP Save or Gateway restart (iris-execute-mcp-v2 README). AD-17 requires the installer to report it.
- **The anonymous `%All` hole** — `%Service_CSP.DEFAULT_USER` ships `UnknownUser` with `%All`, so a `$ROLES`-only check lets anonymous browsers in. iris-couch hit it; OcuPilot will too. Check the resolved user, and reject `UnknownUser` / `_PUBLIC`.
- **Compiler-hashed storage globals** — both iris-session-agent (`^SessionAgenC88B*`) and iris-couch (`^IRISCouch.Proje4479.MangoIndexD`) got them from over-long class names. Keep OcuPilot's class names short.
- **The double-envelope bug class** — a bare `Quit` in a nested `Catch` resumes the enclosing `Try` and writes a second envelope. AD-12 carries the rule and the test.
- **A hand-kept manifest drifts** — iris-execute-mcp-v2's `module.xml` fell 16 classes behind its bootstrap roster because the project's own rule listing required rosters omitted it. AD-17 requires generation from one source.
