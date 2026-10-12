---
title: 'Story 18.12: The agent grows with the stage'
type: 'feature'
created: '2026-10-11'
status: 'blocked'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-18-context.md'
warnings: ['multiple-goals', 'oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** The agent has to keep pace with Stage 2. Every new screen must reach it through its descriptor. The roughly doubled tool roster needs history kept within a budget. An operator behind a proxy or a custom CA needs provider egress they can configure. The credential ladder lacks a wallet rung.

**Approach (as epics.md states it):** There are four criteria:

- every Stage 2 screen's read and confirmed write tools come from its descriptor (C1);
- turn history is trimmed and budgeted (C2);
- proxy and SSL settings for the provider call are configuration, not code (C3);
- a wallet-backed rung joins the `env` and `creds` rungs (C4).

The ledger inbox holds DW-1756, DW-1084 and DW-2321.

## Boundaries & Constraints

**Always:** No secret reaches a status, an error or a surface OcuPilot displays (AD-35, AD-42). The tool listing stays 20.24's per-process cache (AD-5). Rule 31 forbids a second cache.

**Never:** Build on a `decision-pending` entry. Use the owner's provider keys outside the implement stage's live check on a throwaway.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| DW-2321 | The agent changes one entry of an application's `MatchRoles` or `Routines` | A read tool answers the current list, so the update sends it whole with one entry changed | A caller without the list's pairs is refused by name (AD-8) |
| DW-1756 | Guardrails, with turns an hour set on Switches | The limits section names the setting in force | No limit set reads as no limit |

</intent-contract>

## Proposed Split

The planned scope does not fit one implement pass or a 16 KB spec. Each of C2, C3 and C4 is the size of a story in this epic. C1 with DW-2321 is a fourth. Narrowing 18.12's criteria and adding stories is Rule 5's ask-first tier, so this plan halts here. The lead (or orchestrator) amends `epics.md`, and 18.12 is planned again.

Keep the key `18-12-the-agent-grows-with-the-stage`, so the ledger inbox needs no re-own; retitling it is the lead's call. Number the three new stories after 18.38 (18.39 to 18.41). The burn-down then takes the next number at its gate (Rule 17 (3)). The rulings the epic context lists under "18.39" go with the burn-down story, not with the number.

1. **18.12: the agent reaches every Stage 2 screen (C1), DW-2321 and DW-1756.**
   - **C1, read as AD-3 and the epic preamble.** A read tool is derived from each descriptor that declares a read. Each write tool's field list is derived from the endpoint's template. Only the semantic half (description, required, enum) is hand-written per tool. The literal "no hand-written tool code" contradicts AD-3, because every write tool is a declarative class (Rule 5's restate-to-measurable tier). C1 lands as one completeness test over Epic 18's descriptors. A declared read names its read tool. Every action names an advertised write tool whose `DESCRIPTORCLASS` is that descriptor or its list. Every settable field is a row of the tool's `ToolFields` entry or an argument the tool authors (`MATCHROLESARGUMENT`).
   - **DW-2321.** Read tools for a web application's `MatchRoles` and a privileged routine application's `MatchRoles` and `Routines`. Each is a detail read with one row per entry, over the existing `GET` through `source.rows` (Story 18.5) or an `AdminPort` composed type (Story 18.36's `RESOURCEROWS`). The agent then sends the current list with one entry changed.
   - **DW-1756.** Guardrails' limits gain `turnsPerHour`.
   - **No spine amendment** unless a composed type is chosen: that would be an AD-36 row at the spec gate.
2. **New 18.39: the context budget (C2).**
   - **The problem today.** Every provider call carries the whole advertised tool array. Within a turn, every earlier tool result stays in the message array, and nothing trims it.
   - **The work.** Measure first: Task 0 on a throwaway, the advertised array's characters and one stub turn's request size per iteration. Then budget history against what the tools and the system prompt leave. History means prior turns and, within a turn, earlier tool results replaced by a marked stub.
   - **Spine.** It needs an AD-24 amendment ("earlier tool results ... are never replayed" covers prior turns only), and possibly a provider-specific context bound (AD-42).
   - **Contention.** It edits `Kernel/Agent/Loop.cls`, which the spawn prompt names as contended.
3. **New 18.40: provider proxy and custom CA settings (C3).**
   - **What exists.** The settings already live in OcuPilot's protected state, but no route reads or writes them.
   - **The work.** An OcuPilot administrator's surface: GET/PUT beside Switches, a section on an Agent co-pilot page, and strings. Each write is judged as a destination (AD-42) and audited as a security change.
   - **Custom CA.** A custom CA can only be another SSL/TLS configuration named here. AD-10's `PROHIBITED.OCUPILOTSSL` refuses `CAFile` on `OcuPilotProvider`. The named configuration must be a client with `VerifyPeer` on (AD-32); today only its existence is checked.
   - **Spine.** It needs an AD-32 amendment.
4. **New 18.41: the wallet credential rung (C4).**
   - **The work.** A third `CredType` naming a key-value secret, the definition editor's choice of rung, Test connection, and a ladder arm.
   - **Two vendor paths:**
     - `%Net.HttpRequest.UseSecret` sets the key as a header and never returns it (inference: closer to AD-35 than reading the value).
     - `%Wallet.KeyValue.GetSecretValue` returns the value.
   - **What both share.** Each needs the secret's usage flag, or `%Admin_Wallet:USE` for a value read, and the collection's resource. The vendor also writes a `WalletSecretUse` audit row per use.
   - **Spine.** That per-call row is likely a seventh AD-7 vendor-write shape (inference), so the AD-42 ladder, AD-35 and AD-7 are amended at its gate.
   - **Task 0.** Run as a least-privileged principal on a throwaway.
   - It needs no interoperability, unlike `creds` (18.13's validation reads that).

**Why the scope is too big (evidence):**

- 18.36, with four reads and no amendment, reached 16.3 KB at plan. Slice 1 is that size (inference).
- Slices 2, 3 and 4 each need a spine amendment at the spec gate. Slices 2 and 4 each need a Task 0 measurement this stage could not run. `ocupilot-ci` is running 18.11's sweep, and the dev instance is stale (see Design Notes).
- Slices 3 and 4 each add an operator surface: a route, a page section, strings and a browser spec.

## Code Map

Paths are under `src/OcuPilot/` unless stated.

**Slice 1:**

- **Listing.**
  - `Screen/Tool/Registry.cls` `BuildListing` :204 claims one read tool per descriptor with a read (:259-268); `ProviderTools` :354.
  - `Screen/Tool/Write.cls` takes `TOOLFIELDSCLASS` :41 (`ToolFields`); `SettableFields` :572 and `InputSchema` :830.
  - The generated lists are in `Screen/Tool/FieldLists.cls`.
- **Existing pins:**
  - `Test/ReadTool.cls` :93 (356 tools) and :94.
  - `Test/SurfaceCoverage.cls` `TestEveryWriteToolHasACoverageRowAndBack` :620.
  - `Test/ToolEmit.cls` `TestEveryLiveToolRequiresItsScreensPairs` :158.
  - `Test/DerivedFields`, and `ui/tools/field-lists.mjs --check`.
- **DW-2321:**
  - `Screen/Descriptor/RoutineAppList.cls` read :61-71 and `WebAppList.cls` read :91-97 carry neither list.
  - The lists reach only the form read, `Area/WebApp/RoutineAppRules.FormRead` :122-149.
  - `Screen/Tool/RoutineAppUpdate.cls` takes both lists whole (`InputSchema`, `SettableFields`).
  - `WebAppUpdate.cls` takes `MatchRoles` whole (`MATCHROLESARGUMENT` :44).
  - Vendor shapes: `MatchRoles` `[{MatchRole, TargetRoles[]}]` and `Routines` `[{RoutineOrClass, Db, Type}]`.
- **DW-1756:**
  - `Kernel/Shell/Guardrails.cls` `limits` :105-109; `Kernel/State/Switch.cls` `turnsPerHour` :126-141.
  - Client: `ui/src/app/core/guardrails.ts` :52 and :136-140, and `guardrails.page.ts`.
  - EXPERIENCE.md :583 holds the limits line. `Test/Guardrails`, `GuardrailsWire`.

**Slice 2:**

- **History.** `Kernel/Agent/Loop.cls`:
  - history seeding :160-205 (`Kernel/State/Convo.cls` `HistoryMessages` :250, `HISTORYMAXLENGTH` 65,536);
  - `Advertise` once per turn :212, and the whole array on every `Invoke` :235;
  - `AnswerTools` :479 appends each reply's results, which share `TOOLRESULTMAXLENGTH` :463.
- **Bounds.** `Kernel/Agent/Limits.cls` `MAXITERATIONS` 100, `MAXTOKENS` 500,000, `TOOLROWS` 200.
- No `cache_control` appears in `Kernel/Provider/*`.

**Slice 3:**

- **Stored settings.** `Kernel/State/Egress.cls`:
  - proxy server, port, `ProxyHttps`, `ProxyTunnel`, timeout, attempts and `SslConfiguration`;
  - its header says no route renders it; `SetGuarded` is the one writer.
- **Use at call time:**
  - `Kernel/Provider/Base.cls` :489 (`SSLCheckServerIdentity` 1) and :502-509 apply them;
  - `Port/ProviderPort.cls` :307-349 judges the proxy host and tunnels https;
  - `SslConfigurationMissing` :641 checks existence only.
- **Installer.** `Install/Installer.cls` :2940-2975 sets `OcuPilotProvider` (`Kernel/State/Base.cls` `SSLCONFIG` :95).
- **Refusal.** `Kernel/Proposal/Prohibited.cls` `OCUPILOTSSL` :236.
- **Sibling surface.** `Api/Switches.cls` and the routes at `Api/Router.cls` :79-80.

**Slice 4:**

- **Ladder.** `Kernel/Secret/Ladder.cls` `Resolve` :84, reached through `ProviderPort` `SECRETCLASS` :49 and `Kernel/Provider/Base.cls` :136.
- **Rung vocabulary.** `Kernel/AgentRules.cls` `CREDTYPE*` :30-44, and `Kernel/State/Agent.cls` `CredType` (`MAXLEN` 8) :72.
- **Client.** `ui/src/app/areas/agent/definition-form.page.ts` and `.store.ts`.
- **Wallet port.** `Port/WalletPort.cls` lists secrets and never reads a value.
- **Vendor source:**
  - `irislib/%Wallet/KeyValue.cls` `GetSecretValue` :125-143 and `ApplyHTTP` :211-290;
  - `Secret.cls` `AuditUsage` :394.

## Tasks & Acceptance

Not planned. The plan halted at the size check (see Proposed Split). The re-plan of the narrowed 18.12 writes its tasks and criteria.

## Design Notes

**Ledger.**

- DW-2321 is addressed by slice 1 (Code Map).
- DW-1756 is addressed by slice 1 (Code Map).
- Declined DW-1084: already met. `Kernel/Agent/Prompt.cls` `BUILTIN` asks for row names in backticks (Story 4.7, `237d9de7`). Since Story 11.4's citation chips (`526fb8dc`), it also says the user can click the name and not to offer to select rows. The offer half was replaced by the chip, not left without a producer. The lead closes it at adjudication.

**Governing ADs:** AD-3, 5, 7, 10, 22, 24, 31, 32, 35, 36, 41, 42, 53 and 60.

**For the lead (Rule 20):**

- **Tool roster (measured from source).**
  - 356 tools are registered (`Test/ReadTool` :93). Three are unadvertised (AD-53).
  - The 221 `DESCRIPTION` parameters in `Screen/Tool/` hold 94,069 characters of text, 426 on average.
  - Each call's token weight is unmeasured. Slice 2's Task 0 measures it.
- **The dev instance is stale.** `ocupilot` has compiled 89 of the branch's 176 descriptors and 118 of its 277 tool classes (one SQL read of `%Dictionary.CompiledClass`). No roster or listing measurement can be taken there.
- **C1's wording** needs Rule 5's restate-to-measurable amendment (Proposed Split, item 1).
- **Slice 3.** AD-32 gains: "an operator-named provider configuration must be a client with `VerifyPeer` on".
- **Slice 4.** The wallet-use audit row is a candidate seventh AD-7 shape (inference).
- **No vendor defect candidate was found.**
- **Contention (Rule 11).** At plan time, Epic 20's diff against the feature branch is empty. Its uncommitted 20.5 tree touches none of `Loop.cls`, `Dispatch.cls`, `Screen/Tool/Registry.cls` or `Write.cls`, which the spawn prompt names. Each slice re-checks this at its own plan.

## Verification

Not planned. The re-plan writes it, with its `Shared surfaces:` line and the standing criterion.

## Auto Run Result

Status: blocked
Blocking condition: The scope exceeds one implement pass and the 16 KB spec cap. It holds four story-sized criteria: Stage 2 tools from descriptors (C1), the context budget (C2), proxy and custom-CA configuration (C3) and the wallet credential rung (C4). It also holds DW-2321 and DW-1756, and DW-1084 is declined as already met. The proposed split is in ## Proposed Split. 18.12 keeps C1, DW-2321 and DW-1756, and three new stories (18.39 to 18.41) take C2, C3 and C4. Narrowing 18.12's criteria and adding stories is Rule 5's ask-first tier, the lead's or orchestrator's call.
