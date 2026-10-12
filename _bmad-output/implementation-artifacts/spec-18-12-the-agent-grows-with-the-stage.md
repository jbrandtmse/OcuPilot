---
title: 'Story 18.12: The agent grows with the stage'
type: 'feature'
created: '2026-10-11'
status: 'draft'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-18-context.md'
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** The agent has to keep pace with Stage 2: every new screen must reach it through its descriptor, and two gaps remain (no read tool answers a privileged routine application's `MatchRoles` or `Routines`, DW-2321; Guardrails omits the turns-per-hour limit, DW-1756).

**Approach:** C1 as a completeness test over Epic 18's descriptors: every Stage 2 screen brings a read tool and a confirmed single-write tool declared from the same descriptor, with no hand-written dispatch or field list (the orchestrator's tier-1 restatement per AD-3). Plus DW-2321 and DW-1756. Split on the orchestrator's ruling (2026-10-11, Rule 5): the context budget is Story 18.39's, proxy and custom CA Story 18.40's, the wallet rung Story 18.41's. DW-1084 is closed `by-design` with its evidence (the live prompt's backtick line, Story 11.4's criterion).

## Boundaries & Constraints

**Always:** The tool listing stays 20.24's per-process cache (AD-5); Rule 31 forbids a second cache.

**Never:** Build on a `decision-pending` entry. Build the context budget, proxy or CA configuration, or the wallet rung (Stories 18.39 to 18.41).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| DW-2321 | The agent changes one entry of an application's `MatchRoles` or `Routines` | A read tool answers the current list, so the update sends it whole with one entry changed | A caller without the list's pairs is refused by name (AD-8) |
| DW-1756 | Guardrails, with turns an hour set on Switches | The limits section names the setting in force | No limit set reads as no limit |

</intent-contract>


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

## Spec Change Log

- 2026-10-11, lead: narrowed on the orchestrator's split ruling (feature 5b86e803, Rule 5): 18.12 keeps C1 (restated per AD-3), DW-2321 and DW-1756; C2 to C4 moved to Stories 18.39, 18.40 and 18.41 (their anchors stay in this Code Map, to be compressed to pointers at the re-plan). DW-1084 closed by-design. Intent narrowed, Proposed Split removed, status reset to draft for a re-plan in place.
