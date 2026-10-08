---
title: 'Story 20.15: Per-screen permissions, seen and adjusted'
type: 'feature'
created: '2026-10-07'
status: 'in-progress'
baseline_revision: 'd782877aec9da7280d74e7e8316abb0a51705850'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-20-context.md'
warnings: ['oversized']
deferred:
  - 'A Pairs read-back for add-pair and remove-pair: the action kind reads nothingSent, because the composed GET refuses the repeated change after the write (READBACKFIELDS Pairs is declared and unused). A plain re-read would let AD-58 compare the stored set.'
  - summary: >-
      The port's stale-write mapping to 409 STATE.CONFLICT is pinned only at the store (ScreenAccessGate), not through ScreenAccessPort.
    evidence: |-
      No added test interleaves two writers through the port; every port test uses one writer.
    location: >- # optional
      src/OcuPilot/Port/ScreenAccessPort.cls (Stored)
    severity: medium
  - summary: >-
      The agent propose-and-confirm path of the three unadvertised tools is declared but never run end to end.
    evidence: |-
      ScreenAccessWire drives the row-action route; ScreenAccessDescriptor asserts declarations only. Story 20.18 advertises the tools and should add the run (StateDiff, Reset.PortQuery payload branch, ReadBackGone).
    location: >- # optional
      src/OcuPilot/Tool/ScreenAccessAddPair.cls, ScreenAccessRemovePair.cls, ScreenAccessReset.cls
    severity: medium
---

<intent-contract>

## Intent

**Problem:** A screen's required `(resource, permission)` pairs are fixed in its descriptor, and nobody can see them whole or fit them to the instance. On 2026-10-07 the owner decided that Developer accounts, Admin accounts and any `%All` holder may see and change them, even below the classic page's own requirement, and that every change is audited.

**Approach:**

- Store an adjusted pair set per screen in OcuPilot's protected state.
- Make `Screen.Gate.RequiredPairs`, which every screen, tool and route gate already reads, the one reader of that store.
- Add an Agent co-pilot list, Screen permissions, that shows each screen's pairs as the instance evaluates them.
- Its Add, Remove and Reset actions are each a write tool's one operation (AD-53), audited by OcuPilot's existing `SecurityChange` event.

This is the first half of a recommended split (Design Notes › Split). The agent's proposal, and its refusal on a screen the user cannot open, ship in Story 20.18.

## Boundaries & Constraints

**Always:**

- **One reader.**
  - `Screen.Gate.RequiredPairs` reads a screen's adjustment on every call, in the calling process, and never caches it (AD-8).
  - It then unions the classic page's custom resource, as today (AD-44).
  - If the store read fails, it answers `pResolved` 0, and the screen is refused.
  - The hot path is one escalated frame with two global reads on the store's IdKey (`%ExistsId`, `PairsGetStored`). It never uses SQL.
- **Declared stays the default.**
  - When there is no row, the descriptor's `privileges` apply.
  - The descriptor, `Descriptor.Base.PrivilegePairs` and the client mirror are unchanged.
  - No client code computes availability from the mirror's pairs.
- **Never adjustable:**
  - a port's own pair constants (AD-29);
  - the vendor's checks (AD-2's `ResourcesOR()`);
  - an area's declared set;
  - a write tool's own extra pairs and its `CLASSICPAGES` resources;
  - any screen in an area that declares no pair (Home, Agent co-pilot).

  `Screen.Gate.Adjustable` is the one home of that last predicate. `RequiredPairs` ignores a stored row for such a screen, and the prohibited set refuses writing one.
- **Screen permissions' own gate is fixed.** It declares `%Development:USE`. Its three write tools read that declared pair from the descriptor. Its read tool gets it through `RequiredPairs`, which ignores any row for a screen that cannot be adjusted.
- **One operation, two callers (AD-53, AD-55).** Each change goes through its write tool for both callers:
  - the fresh read, through the tool's port;
  - AD-34's per-target hold, through `Operation` (DW-1882);
  - the prohibited set;
  - a fingerprint over the stored set (AD-51);
  - the read-back (AD-58).

  A change is one pair at a time: `add-pair` or `remove-pair`, with the value `Pair`, applied on the server over the fresh read (AD-56 (ii)). This is the Users list's add-role and remove-role pattern.
- **Valid sets.** A set holds 1 to 8 pairs. Each permission is `READ`, `WRITE` or `USE`. Each resource must exist on the instance, checked with `$System.Security.ResourceExists`, which is `[Internal]`, so a test pins its signature.
- **Audit.** After the store write, the port calls `Kernel.Audit.Event.Record` with `SecurityChange` and `changes.pairs {old, new}`. That covers both callers, and the call never fails the write (AD-15).
- **Probes stay on the throwaway.** Probes and principals run on `ocupilot-b-ci` only and are removed afterwards. A test that adjusts a screen resets it in its `OnAfter*` method.

**Never:**

- Never write `%SYS.Portal.Resources` (the classic page store), a resource, a role or a user.
- No new audit event, API route, governance preset or per-user scope.
- No change to any descriptor's declared pairs.
- The tools are not advertised in this story (AD-53's named case, until Story 20.18).
- No line inserted into EXPERIENCE.md outside the Fixed-strings table. Edit rows :169 and :173 in place.

## I/O & Edge-Case Matrix

Two principals, each holding READ on the install namespace's code database:

- **Dev** also holds `%Development:U`.
- **Op** also holds `%Admin_Operate:U` and `%DB_IRISSYS:R`.

Screens are named by their `toolIdentifier`. An action is `POST /screens/agent.screenpermissions/action` with `{action, id, values: {Pair}}`.

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| View | Dev: `GET /screens/agent.screenpermissions/read`, and `agent.screenpermissions.read` | 200. One row per built screen, with `Screen`, `Area`, `Declared`, `Adjustment`, `ClassicResource`, `Effective` (= `RequiredPairs`), `Holds`, `FailedPair` and `Adjustable`. The tool answers the same rows | none |
| Not an adjuster | Op: the read, and each of the three actions | 403 `AUTH.NOPRIVILEGE` naming `%Development:USE`. The side bar lists the screen unavailable, naming it | nothing stored |
| Raise | Dev: `add-pair` `osmgmt.locks` `%Admin_Secure:USE` | 200. In Op's `/navigation`, Locks reads `allowed:false` with `failedPair` `%Admin_Secure:USE`. Op's Locks read, `osmgmt.locks.read` and the Remove locks action each refuse, naming it | 403 `AUTH.NOPRIVILEGE` |
| Reset | Dev: `reset` `osmgmt.locks`, then a second `reset` | The first answers 200, and Op opens Locks again. The second answers 409 `ACCESS.NOTADJUSTED` | nothing stored |
| Lower | Dev: `remove-pair` `osmgmt.processes` `%Admin_Manage:USE` | 200. Op's `/navigation` shows Processes allowed. Op's read is not refused naming `%Admin_Manage:USE`; Task 0 records its answer | none |
| Lower past the vendor | Dev on `webapp.list`: `add-pair %Admin_Operate:USE`, then `remove-pair` of `%Admin_Secure:USE` and of `%DB_IRISSYS:READ` | Each answers 200. Op's side bar opens Web applications. Its read is refused by AdminPort's own gate, not by the screen gate. Task 0 measures this; a 403 naming `%Admin_Secure:USE` is expected (inference) | the port's refusal |
| Empty | `remove-pair` `explorer.classes` `%Development:USE`, which is its only pair | 422 `ACCESS.PAIRS.EMPTY` on `Pair` | nothing stored |
| Bad pair | `add-pair` `NoSuchRes:USE`; `add-pair` `%Admin_Secure:RUN` or `x` | 422 `ACCESS.RESOURCE.UNKNOWN`; 422 `ACCESS.PAIR.MALFORMED` | nothing stored |
| Absent / present / too many | Removing a pair the set lacks; adding one it holds; a ninth pair | 422 `ACCESS.PAIR.ABSENT`; `ACCESS.PAIR.PRESENT`; `ACCESS.PAIRS.TOOMANY` | nothing stored |
| Own screens | Any action on `agent.switches`, `agent.screenpermissions` or `shell.home` | Refused `PROHIBITED.OCUPILOTSCREEN` (AD-10), from either caller | nothing stored |
| Unknown screen | Any action on `no.such` | 404 `ACCESS.SCREEN.UNKNOWN` | nothing stored |
| Audit | Auditing on, each accepted write | One `OcuPilot/Security/SecurityChange` row: actor Dev; target `screen-permission`/`instance`/`<screen>`; verb `updated` or `reset`; `changes.pairs {old, new}` | the write still succeeds |
| Classic union | Locks' classic page carries a custom resource (`ClassicPageGate`'s fixture), and the screen has an adjustment | `Effective` = the adjusted set ∪ `<custom>:USE` | none |

</intent-contract>

## Code Map

### The seam and what already reads it

- `src/OcuPilot/Screen/Gate.cls`:
  - `RequiredPairs` :222-238 is the seam.
  - `HoldsPrivilege` :378 and `ClassicResource` :389 are the overridable-seam precedent.
  - `ParsePairSpec` :343.
- These callers reach the seam unchanged, so an adjustment reaches all of them:
  - `Evaluate` :102, `EvaluateEntry` :173 and `EvaluateArea` :147;
  - `Kernel/Shell/Navigation.cls` :73;
  - `Api/ScreenRead.cls` :58;
  - `Screen/Timeline.cls` :84;
  - `Screen/Tool/Read.cls` :64;
  - 133 tool `PrivilegePairs`, 132 of them through `..#DESCRIPTORCLASS`, plus 66 inheritors;
  - `Kernel/Agent/Dispatch.cls` :260 and :501;
  - `Kernel/Proposal/Operation.cls` :398 and :496, which serve the screen action and the confirm;
  - `Kernel/Shell/Effective.cls` :318;
  - `PermissionCheck.cls` :105;
  - `Kernel/Audit/Ledger.cls` :94;
  - `Screen/Tool/Navigate.cls` :168;
  - 61 `Gate.Evaluate(..#DESCRIPTORCLASS)` sites under `Area/`.
- `src/OcuPilot/Screen/Descriptor/Base.cls`:
  - `PrivilegePairs` :213, the declared set, unchanged;
  - `ToolIdentifier` :508;
  - the per-process declaration cache, :95-123.
- `src/OcuPilot/Screen/Registry.cls` `DescriptorForTool` :3721.
- `src/OcuPilot/Screen/Area.cls` :81-91: Home and Agent declare `[]`. `PrivilegePairs` is at :169.

### The new read (source kind `access`)

- `src/OcuPilot/Screen/Read.cls`:
  - `SOURCE*` :164-298;
  - the kind list :405;
  - the dispatch from :415.
  - The `timeline` branch is the template for a composition that lives under `Screen/`.
- `src/OcuPilot/Screen/Registry.cls`: the source-kind doc :1109, and the `sqlactivity` validation block :1255-1275 to copy.
- `ui/tools/screen-mirror.mjs`: constants :973 and validation :1378-1395. It must refuse exactly what the Registry refuses.

### The store and the write

- `src/OcuPilot/Kernel/State/Base.cls`:
  - `GuardedSaveIfCurrent` :193;
  - `GuardedProbeGet` :427, the shape of the hot path.
  - No re-entry (:29-40), enforced by `scripts/check-objectscript.py` `REENTRY_TOKENS` :643. So the store names no `Screen`, `Port` or `Api` class.
- `src/OcuPilot/Kernel/State/Policy.cls`: the instance-wide keyed store being copied.
- `Test/State.cls` :329: its sweep covers every state class, so FR-29 covers the new store with no edit.
- `src/OcuPilot/Port/InteropPort.cls`: a non-admin port.
  - `Invoke` :287, `PreconditionCodes` :250, `SnippetForm` :719, `Snippet` :734.
  - `Screen/Tool/InteropProductionAction.cls` is its write tool.
- `src/OcuPilot/Screen/Tool/ErrorDelete.cls` :218: `ReadBackGone`.
- The precedent for `SCREENACTIONS` and `SCREENVALUES` is `src/OcuPilot/Screen/Tool/UserUpdate.cls` :55-59 (`add-role=Role,remove-role=Role`). For a one-value action with `ARGUMENT`, see `EcpDataServerChangeStatus.cls` :44-50.
- `src/OcuPilot/Api/ScreenAction.cls` `Values` :497-545: values must be exactly the declared names, each a non-empty string.
- `src/OcuPilot/Screen/Tool/Write.cls`: `READBACKFIELDS` :934, `PRECONDITIONCODES` :502, `StateDiff` :525.
- `src/OcuPilot/Kernel/Audit/Event.cls` `Record` :194: `pType` must be a known entity type. `Api/Governance.cls` :224-263 is the precedent for the `changes` shape.
- `src/OcuPilot/Kernel/Proposal/Prohibited.cls`:
  - `COVEREDTYPES` :250;
  - the type chain :1257;
  - the arms from :1272;
  - `Codes` :893 and `ReasonFor` :901;
  - the `OCUPILOTCODE` precedent :630.
- `src/OcuPilot/Kernel/EntityType.cls` `TYPES` :94.
- `src/OcuPilot/Kernel/Governance/Baseline.cls` :17-200: one line per key, in name order.
- `src/OcuPilot/Api/Error.cls` prefix arms: `ReasonForToolCode` :1224-1232 and `ReasonForViolation` :1418-1436. Follow the `Api/InteropError.cls` sibling pattern.
- `src/OcuPilot/Screen/Descriptor/AgentDefinitionList.cls`: an Agent list. Its prompts are at :71-75. `PROMPTGROUPKEYS` is at `Screen/Registry.cls` :2946.

### Client

- `ui/src/app/areas/os-management/ecp-data-server-list.page.ts` and `ecp-data-server-status-dialog.ts`: the page and dialog templates.
- `ui/src/app/shell/screen-action-handler.ts`:
  - `SCREEN_ACTION_DESCRIPTORS` :64;
  - `UNDRAWN_ACTIONS` :328;
  - the warning consequences, near :449.
- `ui/src/app/core/screen-actions.ts` labels :155-249, and `ui/src/app/shell/screen-outlet.ts` `DESCRIPTOR_PAGES` :150.
- `ui/src/app/core/navigation.ts` `onChange` :1090, which today re-reads only on a `namespace` event.
- `ui/src/app/core/strings.ts`; the `ui/tools/strings.test.mjs` bound is at :593.
- `ui/browser/interop-floor.browser-spec.mjs`: the template for principals and their cleanup.

### Tests that change

- `Test/DeveloperFloor.cls` `SCREENS` :35 and `TOOLS` :38: add the screen and its four tools.
- `Test/ReadTool.cls` :93-94: 299 → 303 tools, and the name list.
- `Test/Descriptor.cls`:
  - :1756: 60 → 61 entity types;
  - a `ReadShapes` row, near :175.
- `Test/SurfaceCoverage.cls`: rows for the screen and its four tools.
- `Test/RefusalCopy.cls` :109 and `ui/tools/self-protection.test.mjs` :282: add `OCUPILOTSCREEN`.
- `scripts/ci-throwaway.sh` :312: `# classes:` under `OCUPILOT_ALLOW_PRINCIPALS`.
- `Test/InteropFloorOwnPairs` needs no row: `%Development:USE` is an own pair.

### Contended with Epic 18 (Rule 11), checked 2026-10-07

Every edit in this table is `CONTENDED non-add-only`.

| File | Lines | Why |
|---|---|---|
| `Kernel/Proposal/Prohibited.cls` | `COVEREDTYPES` :250 and the type chain :1257 | Epic 18's `mft-connection` change edits the same lines |
| `Kernel/EntityType.cls` | `TYPES` :94 | the same line |
| `Test/Descriptor.cls` | :1756 | a count bump |
| `Test/ReadTool.cls` | :93-94 | a count bump and the name list |
| EXPERIENCE.md | :169 (Agent co-pilot row) and :173 (Dialogs) | :169 is adjacent to Epic 18's :168 |
| `ui/src/app/core/screens.generated.ts` | the whole file | it is regenerated |

Every other edit is add-only. Each new entry sits beside the agent entries or at a list's start, never at a list's end, where Epic 18 appends.

## Tasks & Acceptance

**Execution** (in dependency order):

- **Task 0, on `ocupilot-b-ci`.** Record these lines under the Auto Run Result:
  - what Op's Processes read answers after the Lower row;
  - what Op's Web applications read answers after the Lower-past-the-vendor row;
  - `Navigation.Payload` timed 5×, before and after the change, with no adjustment (46 ms at plan).
- `src/OcuPilot/Kernel/EntityType.cls`: add `screen-permission`. Its id is the screen's `toolIdentifier`, kept exactly, under scope `instance`.
- `src/OcuPilot/Api/AccessError.cls` (new): the eight `ACCESS.*` codes and their reasons, following `Api/InteropError.cls`. Add an `ACCESS.` arm to each of `Api/Error.cls`'s two resolvers (add-only).
- `src/OcuPilot/Kernel/State/Access.cls` (new; the name is 28 characters):
  - Properties: `Screen` (the IdKey; a built screen's `toolIdentifier`), `Pairs` (a `resource:permission` spec), `ChangedBy`, `ChangedAt`.
  - Methods, all through `Base`: `GuardedPairsFor(pScreen, .pPairs, .pFound)` (the hot path), `GuardedAll(.pMap)`, `GuardedPut(pScreen, pPairs, pExpectedVersion)` and `GuardedRemove(pScreen, pExpectedVersion)`.
  - `SCHEMAVERSION` does not move: a new table changes no stored row's meaning. Record that reason at the class.
- `src/OcuPilot/Screen/Gate.cls`:
  - `Adjustable(pDescriptor)`: true when the screen's area declares a pair.
  - `AdjustedPairs(pDescriptor, .pFound, .pResolved)`: the store read, overridable for in-process tests.
  - `BasePairs(pScreen, .pDescriptor, .pResolved)`: the adjusted set if there is one, else the declared set. No classic union.
  - `RequiredPairs`: use `AdjustedPairs` when the screen is adjustable and has a row, then union the classic resource.
  - Correct the docs.
- `src/OcuPilot/Screen/Access.cls` (new): `Rows(.pRows, pMaxRows, .pTruncated)`.
  - One row per built descriptor, ordered by area and then identifier, carrying the View fields.
  - One `GuardedAll` call.
  - `Effective` comes from `RequiredPairs`; `Holds` and `FailedPair` from `EvaluatePairs`, in the caller's process.
- `src/OcuPilot/Screen/Read.cls`: add `SOURCEACCESS = "access"` to the kind list :405, with a branch that calls `Screen.Access.Rows`.
- `src/OcuPilot/Screen/Registry.cls` and `ui/tools/screen-mirror.mjs`:
  - An `access` source is endpoint `Screens`, type `LIST`, with no criteria, `rowGet`, parts, rows or query.
  - Both refuse anything else, identically.
  - `ui/tools/screen-mirror.test.mjs` pins one refusal.
- `src/OcuPilot/Port/ScreenAccessPort.cls` (new). It names `Screen.Gate` (as `MonitorPort` does) and the store. It does not name `Screen.Registry`.
  - `GET Screen` answers `{Screen, Pairs, Adjusted}` through `BasePairs`, or 404 `ACCESS.SCREEN.UNKNOWN`.
  - `PUT` runs `Apply(pCurrent, pAddPair, pRemovePair, .pNew, .pViolation)`, which enforces the matrix rules on `Pair`. Then it writes the store and calls `Event.Record("updated", "screen-permission", <screen>, {pairs:{old,new}}, 1)`.
  - `DELETE` refuses 409 `ACCESS.NOTADJUSTED` when nothing is adjusted. Otherwise it removes the row and records `reset`.
  - It also defines `PreconditionCodes`, `ReasonFor`, `SnippetForm` and `Snippet`. `Snippet` renders the port's own public call for each branch (AD-59).
- `src/OcuPilot/Screen/Tool/ScreenAccessAddPair.cls` and `ScreenAccessRemovePair.cls` (new): `agent.screenpermissions.addpair` and `.removepair`.
  - Action-style (AD-51): `PORTCLASS` is the new port, `SENDSBODY 0`, `FINGERPRINTSUBJECT Pairs,Adjusted`.
  - `SCREENACTIONS add-pair` and `remove-pair`, each with `SCREENVALUES <action>=Pair`. The input schema is `{Screen, Pair}`.
  - `StateDiff` builds the `Pairs` old → new row through `Apply`.
  - `READBACKFIELDS Pairs`, `ADVERTISED 0`, `DESTRUCTIVE 0`.
  - `PrivilegePairs` is the descriptor's declared set plus `WithClassicPages`, never `RequiredPairs`.
- `src/OcuPilot/Screen/Tool/ScreenAccessReset.cls` (new): `agent.screenpermissions.reset`.
  - Same port, `WRITETYPE DELETE`, `PRECONDITIONCODES ACCESS.NOTADJUSTED`.
  - `ReadBackGone` when `Adjusted` is false.
  - `ADVERTISED 0`, and the same `PrivilegePairs`.
- `src/OcuPilot/Kernel/Proposal/Prohibited.cls`:
  - Add `TYPESCREENPERMISSION`, append it to `COVEREDTYPES` and to the type chain.
  - The arm refuses `PROHIBITED.OCUPILOTSCREEN` when `'Screen.Gate.Adjustable`, with the reason "This is OcuPilot's own screen. Its permissions cannot be changed."
  - Add the code to `Codes()` and `ReasonFor()`.
- `src/OcuPilot/Kernel/Governance/Baseline.cls`: `agent.screenpermissions.addpair`, `.removepair` and `.reset`, each `true`.
- `src/OcuPilot/Screen/Descriptor/AgentScreenPermissions.cls` (new):
  - Placement: area `agent`, `sideBarPosition` 7, archetype `list`.
  - Pairs: `privileges [%Development:USE]`, and `classicPage ""` (Design Notes).
  - Identity: entity type `screen-permission`; `toolIdentifier` `agent.screenpermissions`.
  - Read: source `{port: access, endpoint: Screens, type: LIST}`.
  - Table: columns Screen, Area, Effective, Adjustment and You hold, with a filter on `Screen` and `Area`.
  - `read.note`: "Changing a screen's permissions changes who OcuPilot lets open it; the instance still checks every read and write."
  - `rowActions`: `add-pair`, `remove-pair` and `reset`.
  - Three prompts in `userPromptGroupAccess`:
    - "Which permissions does the Web applications screen require?"
    - "Which screens can't I open, and which permission is missing?"
    - "Which screens have adjusted permissions?"
- **Client:**
  - `ui/src/app/areas/agent/screen-permissions.page.ts` and `screen-permissions-dialog.ts` (new, each with a `.spec.ts`):
    - The page wraps `<app-list-page/>`. It registers `add-pair` and `remove-pair` as undrawn and opens Change permissions.
    - The dialog lists the row's current pairs, each with a Remove that sends `remove-pair`. It also has an Add row: a resource field, a READ/WRITE/USE select, and a button that sends `add-pair`.
    - It re-reads after each write and keeps a refusal on its field.
    - A Remove shows: "More accounts may open this screen. The instance still checks what they do there."
  - `reset` is a drawn row action with a warning dialog: "This screen will require its declared permissions again."
  - Register all of these in `screen-action-handler.ts`, `screen-actions.ts` and `screen-outlet.ts` (add-only).
  - `ui/src/app/core/navigation.ts` `onChange`: a `changed` `screen-permission` event also re-reads the map.
  - `strings.ts`: about 22 literals, which takes the count to about 2,886 of 2,900 (estimate). If that bound is crossed, the runner moves it.
- **EXPERIENCE.md:**
  - Row :169 gains "· Screen permissions (Stage 4, Story 20.15)".
  - Row :173 gains "· change a screen's permissions (Agent co-pilot's Screen permissions, Story 20.15)".
  - Add the new literals as rows at the end of the Fixed-strings table.
  - Then run `cd ui && npm run test:tools`.
- `node ui/tools/screen-mirror.mjs`: regenerate `screens.generated.ts`.
- **Tests (new).** Each is at most about 500 lines, and none has a property named `Test*`.
  - `Test/ScreenAccessGate.cls`, in process:
    - the store: put, get, remove, and a version conflict;
    - `RequiredPairs` through the `AdjustedPairs` seam: it replaces the set, keeps the classic union, is ignored when not adjustable, and is unresolved on failure;
    - `osmgmt.locks.remove` is the adjusted set ∪ `%DB_IRISSYS:WRITE`;
    - the port constants are untouched;
    - Screen permissions' tools read the declared set even with a stray row.
  - `Test/ScreenAccessFixture.cls` (not a TestCase; it refuses unless armed): Dev and Op from the `DeveloperFloorFixture` helpers, plus `RemovePrincipals()` and `ResetAll()`.
  - `Test/ScreenAccessWire.cls`, as the real principals: the View, Not an adjuster, Raise, Reset, Lower, Lower past the vendor, Audit and Classic union rows.
  - `Test/ScreenAccessRefusals.cls`: the Empty, Bad pair, Absent / present / too many, Own screens and Unknown screen rows. Each asserts the store is unchanged.
  - `Test/ScreenAccessDescriptor.cls`:
    - the descriptor's shape and its three prompts;
    - each tool's kind, port, pairs and key;
    - that the tools are unadvertised: absent from the provider list, the dispatch lookup and the screen context's `tools`;
    - the entity type;
    - the `ResourceExists` signature pin.
- **Tests (edited):** as listed in the Code Map. `ui/tools/navigation.test.mjs` also covers the re-read on `screen-permission`.
- `ui/browser/screen-permissions.browser-spec.mjs` (new): AC7. Its `after` removes Dev and resets the adjustment.

- [ ] [Owner] The owner decided on 2026-10-08 that a security administrator holding `%Admin_Secure:USE` but not `%Development:USE` may also adjust screen permissions (AD-64 item 4 and AD-8's one either-of note, both amended). Build it narrowly.
  - **Scope.** An either-of declared only for the Screen permissions screen, its read and its three write tools, through `Port/ScreenAccessPort`. Do not generalize descriptors to any-of.
  - **Gates.** The navigation verdict (rail, side bar, command box), the read route and tool, the screen action route, dispatch and the confirm gate each accept either pair. A caller holding neither is refused, and the refusal names both pairs.
  - **Rosters.** `InteropFloorOwnPairs`, `DeveloperFloor` and the coverage rosters still pass. Where a roster cannot express an either-of, add a named entry with its reason; never weaken the roster.
  - **Tests.** A principal holding only `%Admin_Secure:USE`, and READ on the install namespace's code database, with no `%Development`, sees the screen and changes a pair. A principal holding neither is refused, naming both. A mutation drops each arm in turn: drop `%Development` and the Developer principal reddens; drop `%Admin_Secure` and the security-only principal reddens.
  - Update AC2 and the matrix rows to the either-of in place.
  - DW-2179 and DW-2180 (open, owned here): settle them in this pass if each is a small, in-scope change, or leave them to the code review.

**Acceptance Criteria:**

- **AC1 (view).**
  - **Given** Dev,
  - **when** Screen permissions' read route is opened or `agent.screenpermissions.read` is called,
  - **then** every built screen is one row. Its `Effective` is what `Screen.Gate.RequiredPairs` evaluates for that screen, the classic custom resource included. `Holds` and `FailedPair` are the caller's own verdict.
- **AC2 (who may).**
  - **Given** an account without `%Development:USE` (Op),
  - **when** it opens the screen, calls the read tool or sends any of the three actions,
  - **then** each is refused naming `%Development:USE`. The stock `%Developer`, `%Manager` and `%All` roles all hold that pair (measured).
- **AC3 (Integration: every gate follows a change).**
  - **Given** Dev's Raise and then Reset on Locks,
  - **when** Op reads `/navigation`, Locks' read route and `osmgmt.locks.read`, and sends Remove locks,
  - **then** each refuses naming `%Admin_Secure:USE` while the adjustment stands, and each answers as before once it is reset.
- **AC4 (below the classic requirement).**
  - **Given** Dev's two Lower rows,
  - **when** they are written,
  - **then** they are accepted, and Op's side bar opens those screens. OcuPilot's screen gate no longer names the removed pairs, while a port's or the vendor's own check still refuses by name.
- **AC5 (audited write).**
  - **Given** auditing is on,
  - **when** an add, a remove or a reset is written through the screen,
  - **then** it is the write tool's operation (AD-53), and the audit database holds one `OcuPilot/Security/SecurityChange` row naming the screen and the pairs before and after.
- **AC6 (self-protection and validation).**
  - **Given** the matrix's refusal rows,
  - **when** each is sent,
  - **then** it is refused with its code, and the store is unchanged.
- **AC7 (browser).**
  - **Given** Dev in a real browser,
  - **when** Dev adds `%Admin_Secure:USE` to Classes (`explorer.classes`) through the dialog,
  - **then** the row shows the adjustment, and System Explorer's side bar shows Classes unavailable, naming `%Admin_Secure:USE`, without a reload. Reset restores it.
- **AC8 (keys).**
  - **Given** the baseline,
  - **when** it is read,
  - **then** all three keys are `true`, and all three tools stay unadvertised until Story 20.18.

## Spec Change Log

- 2026-10-08, runner: re-opened for the owner's either-of decision (AD-64 item 4, AD-8 note; orchestrator placement: in 20.15 before its review). The pass covers only the `[Owner]` item.

- 2026-10-07, runner spec gate: the orchestrator ruled A on Q1 to Q6 (by=merge_gate), approved the split (Story 20.18 chartered, ordered 20.15, 20.18, 20.17) and cleared the six contended edits on union terms. This story's three tools ship unadvertised, and every dispatch and confirm gate reads `Screen.Gate.RequiredPairs`, so the agent never proposes against an adjusted pair unchecked. AD-64 is claimed and written with its one-line amendments; CLAUDE.md's AD count reads 64.

## Review Triage Log

### 2026-10-08 — Review pass

- verdicts: 8 findings — high 0, medium 3, low 4, false 1, maybe-false 0
- findings:

  - `[medium]` `[patch]` Port `Snippet`/`SnippetForm` untested — added `ScreenAccessDescriptor.TestTheScriptRendersTheWritesAndNotTheRead`; `Literal` no longer doubling a quote reddened it, reverted byte-identical.
  - `[medium]` `[defer]` Stale-write 409 unpinned at the port — deferred; the store-level version check is pinned.
  - `[medium]` `[defer]` Agent propose-and-confirm path unrun — deferred to Story 20.18, which advertises the tools.
  - `[low]` `[reject]` PAIRPRESENT/PAIRABSENT have no separate mutation line — same check shape as the ninth-pair leg; AC6's line covers the family.
  - `[low]` `[reject]` `Gate.Adjustable` cache invalidation unasserted — the cache is keyed on the compiled Area class hash and bypassed when the hash is empty; no reachable failure.
  - `[low]` `[reject]` `Invoke` GET with both addpair and removepair takes the add branch — no tool or route builds that query.
  - `[false]` `[reject]` Intent-alignment layer: no divergence; reading A implemented, deliberate deviations (unique index, nothingSent read-back) are recorded.
  - `[low]` `[reject]` `WireSecurityRead` task-history "nothing is cut at 1,000" red — the throwaway holds 1224 history rows; not this story's code, and CI starts fresh.

## Design Notes

**Governing ADs:**

- AD-5, AD-8 and AD-44: the declared set, call-time gates and the classic union.
- AD-9 and AD-50: the store, which is not AD-50's per-user store.
- AD-10: the new arm.
- AD-13 and AD-14: the `screen-permission` type.
- AD-15: `SecurityChange`.
- AD-22: the keys are `true`, per the owner's "starts switched on".
- AD-29 and AD-2: neither port gates nor vendor gates are adjustable.
- AD-34, AD-51, AD-53, AD-55, AD-56, AD-58 and AD-59: the write.
- AD-36: source kind `access`.

**Proposed AD (the runner claims the id): "A screen's required pairs may be adjusted on the instance; the adjustment lives in OcuPilot's protected state, and `Screen.Gate.RequiredPairs` is its one reader".**

- **Binds:** Stories 20.15 and 20.18, and every gate that reads a screen's pairs; AD-5, AD-8, AD-9, AD-10, AD-15, AD-22, AD-29, AD-34, AD-36, AD-44, AD-51, AD-53, AD-56 and AD-58.
- **Prevents:**
  - a second source of a screen's requirement that some gates read and others do not;
  - an adjustment that widens a port's check or the vendor's;
  - OcuPilot's own administration being adjusted away;
  - a client that computes availability from a copy.
- **Rule:**
  1. **Store.** `Kernel/State/Access` holds one instance-wide row per adjusted screen. The row is keyed by the screen's `toolIdentifier` and holds the set that replaces its declared `privileges`. No row means the declared set applies. The descriptor stays the one source of what a screen declares.
  2. **One reader.** `Screen.Gate.RequiredPairs` reads the row on every call, in the calling process, and never caches it. It then unions the classic page's custom resource.
     - Every screen, area, read, tool and route gate already reaches requirements through this method.
     - A write tool's own extra pairs and its `CLASSICPAGES` resources are added on top of the result, unchanged.
     - A failed read refuses.
     - Each read is one escalated frame with two global reads. Measured: 0.016 ms. The navigation map reads about 300 requirements, and the whole map takes 46 ms.
  3. **Not adjustable:** a port's pairs (AD-29), the vendor's checks (AD-2), an area's set, and every screen in an area that declares no pair (Home, Agent co-pilot).
     - `Screen.Gate.Adjustable` is that predicate's home.
     - The write refuses such a screen with `PROHIBITED.OCUPILOTSCREEN`, and `RequiredPairs` ignores any row for one.
     - So a lowered screen opens, and the instance still refuses by name whatever it never allowed.
  4. **The write.**
     - **The list.** Screen permissions (source kind `access`, AD-36) shows every built screen's declared pairs, adjustment, classic resource and effective pairs.
     - **The tools.** `agent.screenpermissions.addpair` and `.removepair` each change one pair as a server-side delta (AD-56 (ii)); `.reset` clears the adjustment. All three reach the store through `Port/ScreenAccessPort`, AD-51's port-built case. They require the declared `%Development:USE`, which the stock `%Developer`, `%Manager` and `%All` roles hold.
     - **What a set may hold.** It is never empty, holds at most eight pairs, and each pair names a resource the instance defines, at READ, WRITE or USE.
     - **The write path.** The keys ship enabled. Each write takes AD-34's hold, fingerprints the stored set and reads back.
     - **Audit.** Both callers record `OcuPilot/Security/SecurityChange` with the pairs before and after. The agent's caller also records its marker (AD-15).
     - **Advertising.** The tools stay unadvertised until Story 20.18 (AD-53).
  5. **Client.** The client never derives availability from the generated mirror's `privileges`. The shell re-reads the navigation map on a `screen-permission` change event. Another tab learns of a change at its next map read; every gate holds at the call regardless.

**Spine amendments for the runner (Rule 20), one line each beside the new AD:**

- **AD-5:** a declared set may be adjusted at runtime (the new AD).
- **AD-8:** "pairs a screen declares" now reads "declares, or that its adjustment replaces".
- **AD-10:** the `PROHIBITED.OCUPILOTSCREEN` arm.
- **AD-13:** a `screen-permission` id is the screen's `toolIdentifier`, kept exactly.
- **AD-15:** an adjustment records `SecurityChange` from either caller.
- **AD-36:** a new source kind, `access`: `LIST` on `Screens`, with no criteria, detail call or parts.
- **AD-51:** a named case for `ScreenAccessPort`.
- **AD-53:** the three tools are unadvertised until Story 20.18.
- **AD-58:** `READBACKFIELDS Pairs`.
- **Deferred:** the Story 20.15 row is decided by the new AD.

**Questions for the orchestrator.** The plan builds each recommended option; none of them halts.

| # | Question | Options | Recommended (planned) |
|---|---|---|---|
| Q1 | Who may view and adjust | **A** `%Development:USE` alone. Held by `%Developer`, `%Manager` and `%All`, and through them by `%EnsRole_Developer` and `%HS_Administrator`: exactly the owner's three kinds, as an ordinary pair set. **B** `%Development:USE` or `%Admin_Secure:USE`. Also admits a custom security-only role, but needs an any-of gate that the descriptor, gate and mirror do not have. **C** Both, together. The Planner's pairs read as a set: this refuses `%Developer` accounts and matches the classic Resource Assign dialog's `%Admin_Secure:USE` | A |
| Q2 | May an adjustment remove every pair? | **A** No: at least one pair stays. **B** Yes: the screen then opens to every account past the floor. **C** At least one pair on a resource other than `%Ens_Portal`, which keeps 20.14's own-check condition | A |
| Q3 | Which screens may be adjusted? | **A** All except those in an area that declares no pair: Home and Agent co-pilot, which covers the kill switch, definitions, governance and this screen. **B** All except this screen and Switches. **C** All except this screen | A |
| Q4 | Does an adjustment move the screen's write tools? | **A** Yes: their screen-derived base follows the adjustment; their extra pairs, `CLASSICPAGES` resources, port checks and vendor checks stay. **B** No: only the screen and its read follow it. **C** Yes, and an adjustment may also set a tool's extra pairs | A |
| Q5 | Does the classic page's custom resource still apply to an adjusted screen? | **A** Yes, AD-44 is kept: it is shown as fixed and is cleared only in the classic portal. **B** No: the adjustment replaces it too | A |
| Q6 | How strongly is a lowering confirmed? | **A** The person's dialog states the consequence, and the agent's proposal (Story 20.18) gets the destructive treatment, as AD-10's privilege grants do. **B** The ordinary confirmation for both. **C** A typed name for the person as well | A |

**Split (recommended).** The whole story is about three implement passes, and the last three specs were flagged oversized. This spec is the first half: the read view, the store, the gate and a person's changes (AC1 to AC8). The second half is **Story 20.18, "The agent proposes permission changes and refuses on a screen the user cannot open"**, ordered before 20.17, which cites its refusal rule. Its ACs:

- **(a) Proposing a change.** The three tools are advertised, and the agent proposes a change as a confirmed proposal. The card shows `Pairs` old → new, the "requires" line and the Q6 treatment. Confirming writes the AD-15 marker and `SecurityChange`.
- **(b) Refusing before the mint.** When the user lacks a write tool's screen's effective pairs, an adjustment included, dispatch refuses before any mint, naming the screen and the failed pair. The built-in prompt then says the user cannot access that screen, and proposes nothing. The demo operator's refusal names the screen too.
- **(c) Screen context.** Screen context gains the current screen's own verdict, derived on the instance, and marks which of its `tools` the user cannot use.
- **(d) Integration.** A turnprobe turn, run as a principal lacking an adjusted screen's pair, is refused at that screen. No proposal row is created, and the turn completes.

**What 20.18 builds on, read at this plan:**

- Dispatch already refuses a write tool's missing pair with `AUTH.NOPRIVILEGE` and `detail.failedPair` before any mint (`Dispatch.cls` :260-271). That is the README's demo-operator path (README :58-59, inference). Because every tool's pairs include its screen's `RequiredPairs`, this half already makes that refusal follow an adjustment.
- Screen context's `tools` is not filtered by the user's grants (`Screen/Context.cls` :176).
- The prompt has no line for `AUTH.NOPRIVILEGE` (`Kernel/Agent/Prompt.cls` :19).
- The proposal card's "requires" line is a snapshot taken at the mint (`Disclosure.cls` :96-114). The confirm re-gates live.
- A tool bound to a `parentScope` descriptor follows the parent's adjustment.

**Measured on `ocupilot-b-ci`, 2026-10-07.** The probe user and role were removed, and their absence confirmed.

- **Stock roles:**
  - `%Developer` holds `%Development:U` and no `%Admin_*`.
  - `%Manager` holds `%Development:U` and every `%Admin_*` except `RoleEdit` and `UserEdit`.
  - `%EnsRole_Developer` grants `%Developer`; `%HS_Administrator` grants `%Manager`.
  - Neither `%Development` nor `%Admin_Secure` is public.
- **`$System.Security.ResourceExists`**, run as a principal holding only `%Development:U` and `%DB_HSCUSTOM:R`: 1 for `%Admin_Secure`, 0 for an undefined name, and case-insensitive.
- **Costs:**
  - an escalated global read: 0.016 ms;
  - a unique-index exists: 0.063 ms;
  - the governance store's SQL read: 0.53 ms;
  - `Gate.RequiredPairs`: 0.107 ms;
  - `Navigation.Payload`: 46 ms, over 163 verdicts.
- **Audit events:** `OcuPilot/Security/SecurityChange` and `AgentWrite` are registered.

**Read in code and source:**

- No client code reads the mirror's `privileges`.
- Every port holds its own pair constant.
- 133 of the 137 tool `PrivilegePairs` go through `RequiredPairs`. The rest go through `##super`, or are empty.
- Screen action values must be the declared names, each a non-empty string. Hence one pair per action.
- The classic Resource Assign dialog (`%CSP.Portal.ResourceDialog`, `RESOURCE` `%Admin_Secure:USE`) writes one extra resource per classic page into `%SYS.Portal.Resources`. That store can neither lower a requirement nor express a Developer account. So OcuPilot reads it (AD-44) and never writes it, and Screen permissions declares `classicPage ""`.

**Integration ACs (Rules 1 and 2):**

- **Consumes:** `Screen.Gate`, `Screen.Registry`, `Kernel.State.Base`, `Kernel.Audit.Event`, `Operation` and the `DeveloperFloorFixture` helpers.
- **Consumed-by:**
  - Story 20.18: the proposal and the refusal.
  - Story 20.17: its create is "settled against the screen's effective pairs".
  - Every later new screen: its pairs appear in this list with no edit.

**Ledger:** this story owns no entries.

## Verification

**Setup (slot B):**

- Before each load, sync: `rsync -a --delete /Users/jbrandt/git/OcuPilot/.worktrees/epic-20/src/ /Users/jbrandt/.ocupilot-throwaways/ocupilot-b-ci/src/`.
- Load in `docker exec -i ocupilot-b-ci iris session iris -U HSCUSTOM` with `$System.OBJ.LoadDir("/opt/ocupilot/src/OcuPilot","ck-d",.tErrors,1)`, checking both the status and `tErrors`.
- Run one class or spec file per call, and never re-submit after a client-side timeout.
- Before a browser run:
  - run `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`;
  - set `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777` and `OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci`.

**Commands:**

- `(loop)` `uv run scripts/check-objectscript.py <changed .cls>`: expected clean.
- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.<C>`, one class per call. Expected: 0 failed, read from `%UnitTest_Result`. The classes:
  - the new ones: `ScreenAccessGate`, `ScreenAccessWire`, `ScreenAccessRefusals`, `ScreenAccessDescriptor`;
  - the touched ones: `Descriptor`, `ReadTool`, `SurfaceCoverage`, `GovernanceBaseline`, `Prohibited`, `RefusalCopy`, `DeveloperFloor`, `InteropFloor`, `InteropFloorOwnPairs`, `ClassicPageGate`, `PortGate`, `ScreenRead`, `State`.
- `(loop)` `cd ui && node --test --test-concurrency=1 browser/screen-permissions.browser-spec.mjs`: expected pass.
- `(loop)` `cd ui && npm run test:tools && npm run test:components && node tools/screen-mirror.mjs --check`, then `bash scripts/lint-docs.sh`: expected clean.
- `(once, before dev_complete)` the full ObjectScript sweep, one class at a time, then:
  - `cd ui && npm test && npm run build`, with the bundle under 3165 kB;
  - `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS`;
  - Task 0's timing.
- `(CI)` The full browser suite runs in CI's shards only (Rule 29).

**Planned pinning mutations (Rule 19).** Apply each on the throwaway, observe red, revert to byte-identical, and record a `mutation:` line here.

| AC | Mutation | Expected red |
|---|---|---|
| AC1 | `Screen.Access` takes `Effective` from the declared set | `ScreenAccessWire` View, on an adjusted row |
| AC2 | The descriptor's `privileges` set to `[]`; separately, a tool's `PrivilegePairs` routed through `RequiredPairs`, with a stray row present | `ScreenAccessRefusals` Not an adjuster; `ScreenAccessGate`'s declared-only check |
| AC3 | `RequiredPairs` ignores the store | `ScreenAccessWire` Raise (navigation, read, tool and action) and `ScreenAccessGate` |
| AC4 | `Apply` refuses the removal of a declared pair | `ScreenAccessWire`'s two Lower rows |
| AC5 | The port's `Event.Record` call removed | `ScreenAccessWire` Audit |
| AC6 | In turn: the empty check, `ResourceExists`, the `Adjustable` arm | the matching `ScreenAccessRefusals` row |
| AC7 | `navigation.ts` `onChange` ignores `screen-permission` | the browser spec, whose side bar stays stale |
| AC8 | A key set to `false`; separately, `ADVERTISED 1` | `GovernanceBaseline`; `ScreenAccessDescriptor` |

**Mutations run (Rule 19)**, each applied to the throwaway's source, reloaded, observed red and reverted by a reload of the unmutated tree:

- mutation: AC1 - `Screen.Access` takes `Effective` from the declared set: `ScreenAccessWire` View and Classic union red.
- mutation: AC2 - descriptor `privileges` set to `[]`: `ScreenAccessWire` Not an adjuster red. `Gate.Adjustable` answering 1: `ScreenAccessGate` stray-row descriptor legs red and the tool legs green; with a tool's `PrivilegePairs` also routed through `RequiredPairs`, the three tool legs red.
- mutation: AC3 - `Gate.BaseSet` ignores the stored row: `ScreenAccessWire` Raise (map, read route) and `ScreenAccessGate` red.
- mutation: AC4 - `ScreenAccessPort.Apply` refuses removing a held pair: `ScreenAccessWire` Lower and audit legs red.
- mutation: AC5 - the port's `Event.Record` call replaced: `ScreenAccessWire` Audit red (both rows read 0).
- mutation: AC6 - the empty check, then `ResourceDefined`, then `Gate.Adjustable` in turn: the matching `ScreenAccessRefusals` method red each time.
- mutation: AC7 - `NavigationService.onChange` ignores `screen-permission`, bundle rebuilt and redeployed: `screen-permissions.browser-spec.mjs` times out waiting for Classes to read unavailable; reverted, rebuilt, green.
- mutation: AC8 - `agent.screenpermissions.reset` set to `false` in `Baseline`, then `ScreenAccessAction.ADVERTISED` 1: `ScreenAccessDescriptor` red both times.
- mutation: script form - `ScreenAccessPort.Literal` stops doubling a quote: `ScreenAccessDescriptor.TestTheScriptRendersTheWritesAndNotTheRead` red.
- mutation: rosters - `AgentScreenPermissions` removed from `DeveloperFloor.SCREENS`, then `agent.screenpermissions.read` from `TOOLS`: `DeveloperFloor` red each time. `InteropFloorOwnPairs` needs no row: the screen and tools declare `%Development:USE`.

## Auto Run Result

Status: done
Blocking condition: none

- Change: `Kernel/State/Access` (a unique index on `Screen`, since `Base` owns the IdKey; the hot path is the index's `Exists` plus `PairsGetStored`, in `Base.GuardedStoredValue`'s one frame), `Screen.Gate` (`Adjustable`, `AdjustedPairs`, `BaseSet`, `BasePairs`; `RequiredPairs` the one reader; `Adjustable` keeps the static area answer per process, hash-checked), `Port/ScreenAccessPort` (composed `GET`, `PUT`, `DELETE`; `COMPOSEDTYPES Screen/PUT`), three tools over an abstract `ScreenAccessAction`, `Screen/Access`, source kind `access` (Registry, Read, mirror), the descriptor, `Api/AccessError`, `screen-permission` (EntityType, `PROHIBITED.OCUPILOTSCREEN` arm, Baseline keys), and the client page, dialog, handler, label, outlet and `onChange` entries. New literals extend EXPERIENCE.md row 604 rather than adding rows, because strings.ts cites that table by line.
- Tests added: `ScreenAccessDescriptor`, `ScreenAccessGate` (+ `ScreenAccessGateSeam`), `ScreenAccessWire`, `ScreenAccessRefusals`, `ScreenAccessFixture`, `ScreenAccessPortGateSeam`, `ui/tools/access.test.mjs`, two component specs, `screen-permissions.browser-spec.mjs`. Rosters and counts moved in `Descriptor`, `ReadTool`, `SurfaceCoverage`, `Prohibited` (32 codes; also `AuditingUpdate`, `AuthOptionsDescriptor`, `EncryptionStartupDescriptor`, `SuperserverDescriptor`), `DeveloperFloor`, `PortGate`, `ToolEmit`, `ToolRoundTrip`, `ToolWrite`, `Wire`, `RefusalCopy`, `AdminPairCorpus` and three descriptor corpora, `navigation`, `screen-mirror`, `self-protection` and `strings` (bound 2900 to 3000); `ci-throwaway.sh` arming line.
- Task 0 (ocupilot-b-ci): after Processes loses `%Admin_Manage:USE`, Op's map opens it and its read answers 403 `PORT.ACCESSDENIED` naming `%Admin_Manage:USE` (AdminPort's gate). After Web applications gains `%Admin_Operate:USE` and loses `%Admin_Secure:USE` and `%DB_IRISSYS:READ`, Op's map opens it and its read answers 403 `PORT.ACCESSDENIED` with no pair named (the vendor's check). `Navigation.Payload`, 5 runs, no adjustment: store never read 58-60 ms; store read 69-75 ms in the same session (the planned 46 ms was a quieter machine).
- Verified: full sweep 515 classes, 4096 tests; the 9 failures were roster counts, fixed and re-run green, except `WireSecurityRead.TestTaskHistoryPairSetsAreEnforcedForARealPrincipal` ("nothing is cut at 1,000"), a task-history row count on a long-lived instance in a screen this story does not touch. `test:tools` 1888, components 2647, `a11y-structural-invariants` 13, `screen-permissions` browser spec, smoke 50/50, bundle 3.12 MB; every AC has a `mutation:` line.
- Residual: the full browser suite is CI's. The spine's AD-64 and its one-line amendments were already present and were not edited.
- Review: 1 patch applied (script-form test), 2 deferred (port stale-write mapping, agent confirm path), 5 rejected with reasons in the triage log. Follow-up review not recommended. Targeted rerun green after the patch: `ScreenAccessDescriptor`.
