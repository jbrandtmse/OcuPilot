# Harvest map — iris-execute-mcp-v2 (OcuPilot governance + handler bodies)

`/Users/jbrandt/git/iris-execute-mcp-v2` · 68 `.cls` under `src/ExecuteMCPv2/` (~26,642 lines; 39 production + 29 test), 8 pnpm workspace packages under `packages/`. 104 tools across 5 MCP servers.

## THE key finding — the `%Atelier.REST` seam

Every handler extends `ExecuteMCPv2.REST.Base Extends %Atelier.REST`, and **every handler's only contact with the envelope is one call**:

```objectscript
Do ..RenderResponseBody(tSC, , tResult)
```

**738 such call sites across 15 handlers.** A new OcuPilot base class with a compatible signature —
`RenderResponseBody(pStatus As %Status, pMsgPart As %DynamicArray, pResPart As %DynamicObject) As %Status`
— replaces the `{status, console, result}` envelope with **zero call-site edits**. That is exactly the technique `REST/Base.cls` already demonstrates (it wraps `##super()` for pre-flight). **This is the cheapest path to harvesting the 39 production handler bodies without inheriting the Atelier envelope**, and it collapses the PRD's assumption that the custom-REST harvest is Stage 5 work.

Why the envelope is coupled to `%Atelier` (what OcuPilot is replacing):
1. The envelope is inherited, not authored — handlers never write JSON themselves.
2. `%Atelier.REST.RenderResponseBody` interleaves `Write` with `%ToJSON()` **directly against the response device**, so a mid-way serialization failure flushes a truncated body as HTTP 200. `REST/Base.cls` (173 lines) exists solely to pre-flight the message and result parts into a `%Stream.TmpCharacter` first. *(Note its stated limits: the status part is not pre-flighted — circular — and only serializability is proven, not the device write.)*
3. The error format is Atelier's `status.errors[]`; the TS client treats HTTP 400 with `status.errors.length === 0` as a successful empty result.
4. Transport coupling beyond the envelope: `POST /work` → 202 + `Location` header; version negotiation; ETag/caching.
5. CSP/Atelier calling conventions leak in — boolean query params must be numeric `1`/`0`; `%`-prefixed doc names must be URI-encoded; `POST /action/query` returns rows as key-value objects at `result.content`, not `{columns, rows}`.

## Handler bodies — the OcuPilot area map

| File | Lines | Covers | OcuPilot area |
|---|---|---|---|
| `REST/Security.cls` | **3494** | users, roles, resources, webapps, SSL, OAuth2, services, LDAP, X.509, auditing | **Permissions (5.6) + Security & secrets (5.7) + Web apps (5.5)** |
| `REST/Interop.cls` | 2728 | productions, items, credentials, lookup tables, rules, transforms, REST apps, message trace | Stage 4 |
| `REST/Monitor.cls` | **1427** | metrics, jobs, locks, journal, mirror, audit events, DB check/actions, backup, license, ECP, processes | **OS management (5.9) + Logs (5.10)** |
| `REST/Config.cls` | 700 | namespaces, databases, global/package/routine mappings | OS management (5.9), Stage 2 |
| `REST/Task.cls` | **332** | task scheduler — `TaskList`, `TaskManage`, `TaskRun`, `TaskHistory` | **Tasks (5.8)** |
| `REST/SystemConfig.cls` | 291 | CPF get/set/export | Stage 2 |
| `REST/Command.cls` | 376 | ObjectScript execution + classmethod invocation; `Redirects()` I/O-mnemonic labels | Stage 5 |
| `REST/Global.cls` | 279 | global CRUD | Stage 5 |
| `REST/UnitTest.cls` | 333 | `%UnitTest` runs | Stage 5 |
| `REST/Analytics.cls` | 364 | DeepSee | Stage 4 rider |
| `REST/Health.cls` | 532 | composite health check (9 areas) | Stage 4/5 |
| `REST/MessageResend.cls` | 619 | resend + preview, the double-gate reference | Stage 4 |
| `REST/EnvSync.cls` | 261 | per-document hashes | Stage 5 |
| `REST/SqlAdvisor.cls` | 323 | SQL advisor | Stage 3 |
| `Utils.cls` | **1163** | `SwitchNamespace`/`RestoreNamespace`, `ValidateRequired/String/Integer/Boolean`, `SanitizeError`, `ApplyOutputCeiling`, `SurrogateSafeCutLength`, `InvokeWithArgs`, `DecodeUtf8Stream`, `ReadRequestBody`. Params `OUTPUTCEILING=32768`, `BYREFNODECEILING=1000`, `UTF8CHUNKSIZE=1000000` | **shared — take early** |
| `REST/Dispatch.cls` | 183 | `XData UrlMap`, ~90 routes | pattern |
| `Setup.cls` | 223 | web-app install, 5 `[SqlProc]` methods | pattern |

`REST/Security.cls` names the IRIS classes OcuPilot needs: `Security.Users`, `Security.Roles`, `Security.Resources`, `Security.Applications`, `Security.SSLConfigs`, `Security.Services`, `Security.LDAPConfigs`, `Security.Events`, `Security.System`, `%SYS.Audit`, **`%SYS.X509Credentials`**, `%SYS.OAuth2.Registration`, `OAuth2.Client`, `OAuth2.Server.Configuration`, `OAuth2.ServerDefinition`, `%SQL.Manager.API`. **`%SYS.X509Credentials` answers PRD Open Question 4 for X.509.**

Support libraries: `Diagram/*` (7 classes, 1,470 lines — Loader → Correlator → Compressor → Writer → Mermaid `sequenceDiagram`) and `Loc/*` (3 classes, 649 lines).

## Governance model — 100% TypeScript, needs an ObjectScript rewrite

**None of it lives in ObjectScript.** ~2,000 lines in `@iris-mcp/shared` with zero IRIS dependency. OcuPilot's governance runs *on the instance*, so this is a port of the **model**, not the code.

| Piece | File | Lines |
|---|---|---|
| Policy engine (key model, cascade, seed, preset, file channel) | `packages/shared/src/governance.ts` | 1045 |
| Frozen baseline (generated, DO-NOT-EDIT) | `packages/shared/src/governance-baseline.ts` | 184 — `GOVERNANCE_BASELINE_HASH="1e62c5ad5bf7"`, **141 keys** |
| Read/write classifications (hand-curated) | `packages/shared/src/baseline-classifications.ts` | 243 — key-set parity enforced by test |
| Shared key derivation (generator ↔ gate lock-step) | `packages/shared/src/governance-baseline-derivation.ts` | 131 |
| Call-time gate (the ONE chokepoint) | `packages/shared/src/server-base.ts` **1373–1456** | 2316 total |
| Audit log | `packages/shared/src/audit.ts` | 373 |
| Governance CLI | `packages/shared/src/cli/governance.ts` | 1555 |

Key scheme: `tool` for single-operation tools, `tool:action` for one value of a multi-action tool's `action` enum.

```ts
export type MutationClass = "read" | "write";
export type GovernancePreset = "read-only" | "full";
export type GovernanceLayer = Record<string, boolean>;
export interface GovernanceConfig { global?: GovernanceLayer; profiles?: Record<string, GovernanceLayer>; }
```

**Frozen-baseline rule:** membership ⇒ pre-existing ⇒ enabled. Absent ⇒ new ⇒ `defaultSeed` disables it iff `mutates === "write"`. **The file must never be regenerated to grow** — that would re-grandfather every new write. `assertGovernanceClassification` throws at registration if a non-baseline key has no `mutates`.

**The cascade** — ALL env layers above ALL file layers, `??` never `||`, so an explicit `false` at any layer is honored:
```
effective(key, profile) = env.profile ?? env.global ?? file.profile ?? file.global ?? presetSeed ?? defaultSeed
```
Every layer read goes through own-property-only accessors; `RESERVED_KEYS = {__proto__, constructor, prototype}` rejected at parse; policy maps built with `Object.defineProperty` so a prototype-colliding key still becomes a real own key.

**Read-only preset** resolves class from `BASELINE_ACTION_CLASSIFICATIONS` first, then `mutatesLookup`; `"read"` ⇒ true, else false. **Never consults `defaultEnabledWrites`** — read-only overrides default-enable. An unclassifiable key **fails safe (blocked)**.

**Gate ordering (decision D5):** Zod validate → resolve `server`→profile → compute key → evaluate → deny-or-proceed. It sits **after** profile resolution and **before** `getOrCreateClient`, so a denied call never opens a connection and never reaches the handler. Tools stay advertised in `tools/list`. Denial:
```ts
{ code: "GOVERNANCE_DISABLED", action: governanceKey, server: profile.name, presetApplied? }
```
`presetCaused` = preset set AND no explicit override at any of the four layers AND `presetSeed === false` — so an operator can tell "I disabled this" from "the preset disabled this".

**Audit log is not governable.** `audit.ts:1-17`: *"Logging is server CONFIGURATION, not a governed tool — it is deliberately NOT bypassable via `IRIS_GOVERNANCE`."*
```ts
const REDACT_KEY_PATTERN = /password|passwd|secret|token|credential|apikey|api_key|authorization/i;
const MAX_STRING_BYTES = 2048; const TRUNCATED_KEEP_CHARS = 256;
```
`redactValue` is pure and never mutates input. JSONL with `sessionStart` header and `shutdown` footer carrying `droppedEntries`; serialized write queue; single-generation rotation; **degrade-never-throw** (failures counted, never surfaced to the call); `params` written only when explicitly enabled, and only after redaction.

## The dryRun / confirm double gate

Outer gate = governance default-disable. `confirm`/`dryRun` is the **inner intent gate**. Enforcement is **duplicated** — TS refuses early, ObjectScript refuses structurally.

| Tool | Contract | ObjectScript |
|---|---|---|
| `iris_message_resend:resendFiltered` | `dryRun` default **true**; executing needs `dryRun:false` **AND** `confirm:true`. Either alone ⇒ refused, "No changes were made." | `REST/MessageResend.cls:383` |
| `iris_env_promote:execute` | 4 refuse-before-any-write gates: G1 `confirm`, G2 `steps` allowlist in-plan, G3 plan-hash freshness (+step consistency, +diff/profile match), G4 target-profile governance | none (TS only) |
| `iris_audit_manage:purge` | `confirm:true` AND at least one real bound (`source:"*"` is a wildcard, not a bound) | `REST/Security.cls:2871` |
| `iris_production_control:clean` + `killAppData` | `killAppData` needs `confirm:true`; `clean` ships enabled via `defaultEnabled` | `REST/Interop.cls:150` |

Structural server-side refusal, verbatim:
```objectscript
; --- dryRun/confirm double-gate — structural
Set tDryRun = 1
If tBody.%IsDefined("dryRun") { Set tDryRun = +tBody.%Get("dryRun") }
If tBody.%IsDefined("confirm") { Set tConfirm = +tBody.%Get("confirm") }
```

Dry-run returns a **distinct typed shape** from executed. Additional structural guards worth copying: a 100-id cap on explicit ids; `maxMessages` default 100 / **hard cap 500** where a match count over the cap is *refused*, never truncated-and-executed; a 7-day max window.

## Tool definitions (TS side)

A tool is a plain exported `ToolDefinition`: `name`, `title`, `description`, `inputSchema` (Zod v4 `ZodObject`, `.describe()` on every field — these become the JSON-Schema descriptions the LLM reads), `annotations` (`destructiveHint`/`readOnlyHint`/`idempotentHint`/`openWorldHint`), `scope` (`NS`/`SYS`/`BOTH`/`NONE`), `mutates`, `defaultEnabled`, `handler`.

`registerTool` stores an **extended** schema — `inputSchema.extend({ server: z.string().optional() })`. A tool declaring its own `server` field **fails fast at registration**. At call time, `safeParse` then `const { server, ...validatedArgs }` so the handler never sees it.

Each package's `tools/presets.ts` exports `core`/`developer` include/exclude lists whose union must equal the full tool set — `assertPresetCoverage` throws at construction.

## Self-install — read the warnings

`scripts/gen-bootstrap.mjs` reads a **hand-maintained ordered roster of 29 `.cls` files**, normalizes CRLF→LF, hashes, and emits `packages/shared/src/bootstrap-classes.ts` (**16,152 lines, generated output — never read as source**).

`probeCustomRest` yields a quad-state, which is a good model:
```ts
type ProbeResult =
  | { status: "missing" }        // full deploy+compile+configure+map
  | { status: "current" }        // skip everything
  | { status: "unconfigured" }   // classes current but webapp absent → re-run privileged steps (self-heal)
  | { status: "stale"; deployedVersion: string };
```
`deployClasses` PUTs each as `{enc:false, content: content.split("\n")}` with **`?ignoreConflict=1`** — without it every auto-upgrade 409s.

**What the repo's own docs say is broken:**
1. **`ipm/module.xml` is materially stale.** It lists **13** production classes; the bootstrap embeds **29**. Missing: `REST.Base`, `REST.Health`, `REST.EnvSync`, `REST.Loc`, `REST.MessageResend`, `REST.SqlAdvisor`, all 7 `Diagram.*`, all 3 `Loc.*`. An IPM install today would fail to compile. The project's own Rule #39 lists the rosters a new class must join and **omits `ipm/module.xml`** — so it drifted silently for ~16 classes.
2. `SourcesRoot` is probably wrong — `module.xml` sits in `ipm/` but says `<SourcesRoot>src</SourcesRoot>`; likely needs `../src` or the manifest at repo root. Unresolved.
3. `<Version>0.1.0</Version>` never tracked the npm versions.
4. IPM publishing is deferred; never published to npm or IPM.
5. **CSP Gateway registration gap:** `Security.Applications.Create()` does not notify the CSP Gateway, so a new web app may 404 until an SMP Save or Gateway restart. **Affects OcuPilot's installer directly.**
6. `%Admin_Manage` is required for the privileged step; without it bootstrap reports `configured:false` + manual instructions and self-heals on a later privileged launch.
7. On migrated / `%SYS`-reset instances the `unconfigured` state also forces a **recompile**, because a matching source hash does not prove the compiled objects are valid — otherwise dispatch throws `<NULL VALUE>` HTTP 500.

**Lesson for OcuPilot:** make the IPM manifest **generated from the same roster** as everything else, never hand-kept.

## Names to rename

npm scope `@iris-mcp/*`, workspace `iris-mcp-suite` · bins `iris-{dev,admin,interop,ops,data}-mcp`, `iris-mcp-{credentials,governance,clients}` · **ObjectScript package `ExecuteMCPv2`** (+ `.REST`, `.Diagram`, `.Loc`, `.Tests`) · web path `/api/executemcp/v2` (also `CookiePath`, and `const BASE_URL` in ~14 tool files) · dispatch class `ExecuteMCPv2.REST.Dispatch` · web-app `Resource = "%Development"` · package mapped into **`%ALL`** via `Config.MapPackages` (creates `%ALL` if absent) · SQL procs `ExecuteMCPv2.Setup_Configure|_ConfigureMapping|_IsConfigured|_EnsureUnitTestRoot|_GetBootstrapVersion` · globals **`^UnitTestRoot`**, `^UnitTestConfig`, `^ExecuteMCPv2Test`, `^ExecuteMCPv2CmdTest` · routine `ExecuteMCPv2.REST.Command.1` with labels `wstr/wchr/wnl/wff/wtab/rstr/rchr` · public vars `%ExecuteMCPOutput`, `%ExecuteMCPTruncated` · **tool prefix `iris_`** · reserved tool arg `server` · URI scheme `iris-governance://` · denial code `GOVERNANCE_DISABLED` · truncation marker `[IRIS-MCP-TRUNCATED ceiling=<N>chars]` · IPM module `iris-execute-mcp-v2` · **all `IRIS_*` environment variables** (~30 of them).
