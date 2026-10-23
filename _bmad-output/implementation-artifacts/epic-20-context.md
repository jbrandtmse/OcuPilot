# Epic 20 Context: Stage 4 - Interoperability, with the Analytics rider

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Bring the classic portal's Interoperability work into OcuPilot for namespaces that support it, with Analytics riding along, and give the agent guided multistep workflows and Investigate, so the largest area the classic portal still owns can be used here. Most of the epic has shipped: productions, items, settings, per-host tabs, queues and jobs, lookup tables, read-only partners, host and transformation tests, messages with trace and resend, the embedded vendor editors and the agent's edits behind them, per-screen permissions, the agent's source reads, saves and creates, guided workflows, and the analytics port with its lists, links, MDX tool and the agent's MDX read. What remains is 20.37, a fix-forward that keeps release 1.0.12's stored layout for background runs so the 1.0.13 update strands nothing. The current dispatch covers 20.37 alone, followed by an upgrade re-check, a report and a hold. After that come 20.34 (cube manager), 20.36 (Investigate), 20.25 (item runtime actions), 20.26 (partner writes), then the burn-down.

## Stories

- Story 20.1: Namespace category gating
- Story 20.2: Productions, listed and controlled
- Story 20.3: Production items
- Story 20.4: Per-host tabs, the monitor, queues and jobs
- Story 20.5: Lookup tables and business partners
- Story 20.6: Testing hosts and transformations
- Story 20.7: The three embedded vendor editors
- Story 20.8: The schema viewers and the production configuration diagram
- Story 20.9: Messages - search, view, resend and trace
- Story 20.10: Source-control hooks
- Story 20.11: The Analytics rider
- Story 20.12: The agent gains guided workflows and Investigate
- Story 20.13: The sign-in hand-off to the embedded vendor editors
- Story 20.14: Interoperability holders reach OcuPilot
- Story 20.15: Per-screen permissions, seen and adjusted
- Story 20.16: The agent edits rule, DTL and BPL content behind the embedded editors
- Story 20.17: Long blocks in the agent panel start collapsed
- Story 20.18: The agent proposes permission changes and refuses on a screen the user cannot open
- Story 20.19: The agent reads class and routine source
- Story 20.20: The agent creates new classes and routines, on the person's confirmation
- Story 20.21: The agent saves edits to existing classes and routines
- Story 20.22: Production item settings
- Story 20.23: Queue and job actions
- Story 20.24: Agent tool calls stop re-listing the tool registry
- Story 20.25: Item runtime and configuration actions
- Story 20.26: Business partners saved and removed
- Story 20.27: Transformations tested
- Story 20.28: OcuPilot compiles in a namespace without interoperability
- Story 20.29: Screens load on demand
- Story 20.30: The session trace
- Story 20.31: Message resend and edit-and-resend
- Story 20.32: The analytics links
- Story 20.33: The MDX query tool
- Story 20.34: The cube manager's build and synchronize
- Story 20.35: The agent's MDX read
- Story 20.36: Investigate
- Story 20.37: SqlRun stored slot order

## Requirements & Constraints

### 20.37: stored slot order (current)

- **The defect.** `Kernel/State/SqlRun` gained `Kind` between `Namespace` and `State`. The class has no source Storage section, so the compiler numbers data slots by declaration order, and an update from 1.0.12 shifts slots 4 to 10. A background run saved before the update then reads 404 and is never swept. The release upgrade check found this, and the owner chose to fix it before the 1.0.13 cut.
- **The fix is declaration order only.** RunKey, UserName, Namespace, State, JobId, CancelRequested, QueuedAt, StartedAt, EndedAt and Answer keep slots 1 to 10, and Kind becomes slot 11. No other product code changes: the code that reads and writes Kind and the existing tests stay as they are. Never hand-write a Storage section.
- **One small test** reads the compiled storage map and asserts the eleven slots. Show it red under the mutation (Kind moved back between Namespace and State), then revert the mutation.
- **Out of scope.** A general check that compares every persistent class's stored property order against the previous release is backlog (DW-2501), not built now. `SCHEMAVERSION` does not move, because no stored row's meaning changes.
- A dev or throwaway instance may hold SqlRun rows written under the shifted layout. Such rows would read wrongly after the fix, but they are swept 900 s after their run ends (inference).

### Rest of the epic

- **Every write** is a server-minted proposal with a diff the instance computes, an explicit Confirm and an agent marker. A new write key joins the governance baseline in the same change, and a destructive key ships `false`. Each plan states the action's destructiveness, its key's default and its audit record. Posture questions go to the orchestrator with options and a recommendation.
- **No compile-time dependency on interoperability.** No shipped class names an `Ens.*`, `EnsLib.*` or `EnsPortal.*` class anywhere the compiler resolves it. Such values are typed `%RegisteredObject` or `%String` and reached at run time.
- **Secrets.** A secret-named setting reads as empty, and an attempt to set one is refused.
- **20.34, the cube manager** (Analytics side bar position 8, `%DeepSee_Admin:USE`). Build and Synchronize run through `AnalyticsPort`'s `CubeManager` `BUILD`/`SYNCHRONIZE`, behind `MANAGERPAIRS` plus WRITE on `^DeepSee.Fact`'s database (read-only: 409 `ANALYTICS.CUBE.READONLY`), over a port-composed `STATE` that spans the cube and its dependents.
  - **Refused by name** before any vendor call: `ANALYTICS.CUBE.BUSY`; for a synchronize, also `ANALYTICS.CUBE.NODSTIME` and `ANALYTICS.CUBE.NOTBUILT`.
  - **Keys.** Build's key ships `false` (it kills facts first) and Synchronize's ships `true`. Repair is offered as Build.
  - **Running and audit.** The vendor calls run inside an output capture. The vendor audits nothing, so OcuPilot records its own `ConfigChange`. A build that outlasts the gateway timeout loses its answer.
- **20.36, Investigate.** Investigate is one more catalog entry in `Kernel/Agent/Workflow`'s `XData Catalog`, with no new mechanism.
  - **The entry:** no `writes`, `entry: true`, offered by no suggested prompt, and every `reads` name resolves as a read.
  - **Writes.** Every write in the turn answers `WORKFLOW.NOTASTEP`.
  - **The answer** is a recap and hypotheses ranked most likely first, citing the rows used.
  - **Never added:** a new route, tool, governance key, screen, descriptor, entity type, suggested prompt or system-prompt sentence.
  - **Owns DW-2468 and DW-2469.** A step's tools join the turn's starting tool set, and `previous` reports a turn only when it ran the same workflow.
- **20.25, item runtime actions.** Temporary stop, start and restart of one item, copy, and change of class, each over a fresh read through the interoperability port. A runtime action is followed by the production update the vendor requires. A vendor no-op (a stopped production, a disabled item) is refused by name. The vendor audits copy and change of class.
- **20.26, partner writes** on `Ens.Config.BusinessPartner`, each confirmed over a fresh read and recording OcuPilot's own audit row.
  - **Rename** is either refused or run in one transaction.
  - **Remove** first reads the items that name the partner.
  - **Pairs** go to the orchestrator (`%Ens_ProductionConfig:WRITE` recommended).

## Technical Decisions

- **New stored properties are declared after every existing one** on any `%Persistent` class of OcuPilot's own state. A rename or removal needs a migration step. `SCHEMAVERSION` moves only when a stored row's meaning changes. Upgrade is "install again", and downgrade is not supported.
- **Ports are the whole gate.** The vendor's production, partner, test, resend and analytics calls check no privilege. Each port therefore gates first, in this order: the endpoint's pairs, the tool's pairs, then database READ (WRITE for a write). A refusal names the failed pair. Every new surface declares its own pair.
- **`InteropPort`** is the only class that controls a production. A new read or write names its case in the interoperability AD at its spec gate. Each write is action-style over a port-composed read, finishes in its own request, and refuses vendor silent successes by name. Namespace switches use explicit save and restore and call no `OcuPilot.*` class while switched.
- **`AnalyticsPort`** calls `%DeepSee` in process as the signed-in person, never `/api/deepsee`. Before any vendor call it checks, in order: the pairs, the namespace's shape, that the namespace reports analytics (else 409 `ANALYTICS.NAMESPACE`), then database READ. It uses only reads measured to write nothing.
- **Background runs** (`Kernel/Shell/BackgroundRun`, shared by the SQL console and MDX, stored in `SqlRun`). A run never mutates. Each user gets one live run per kind, and the instance allows five. The answer is held for its owner alone and swept 900 s after the run ends, and another user's run reads as 404.
- **Client.** Zoneless and `OnPush`. `screens.generated.ts` is generated and never hand-edited. Bundle limits are a 2,500 kB warning and a 4,000 kB hard stop. A crossing is reported to the owner, never re-based.
- **Untrusted content** (vendor text, names, MDX, message bodies) reaches the screen only as interpolated text, and reaches the model only through the one sanitizer.
- **Tests.** No test class depends on state another class left. Run one test class at a time and wait for each run to land in `%UnitTest_Result`. Read results from that global.

## UX & Interaction Patterns

- **Gated controls are never hidden.** They stay focusable and `aria-disabled`, and they name the failed pair or reason. Investigate is gated exactly like Explain this and sits beside every Explain this entry.
- **The workflow chip** above the composer reads "Guided workflow", followed by the starting text, then Continue and End workflow.
- **Destructive actions.** A person's destructive screen action, such as the cube manager's Build, uses the typed-name confirm. An agent's destructive card carries no typed-name confirm. Dialogs never stack.
- **New strings** go into EXPERIENCE.md's Fixed strings and `strings.ts` with unique values, with no internal ids in user-facing copy.

## Cross-Story Dependencies

- **Status.** Done: 20.1 to 20.24, 20.27 to 20.33, and 20.35. Ready for development: 20.34 and 20.36 (spec written). Backlog: 20.37, 20.25 and 20.26.
- **Order.** 20.37, then 20.34, 20.36, 20.25, 20.26 and the burn-down.
- **20.37** touches only `SqlRun`, which 20.33's MDX runs and the SQL console share. The 1.0.13 upgrade check from release 1.0.12 is re-run after it lands.
- **20.34** consumes 20.11's port, error and probe types, 20.33's checks and 20.23's action-write shape. DW-2485 (the cache-snapshot `MAXSTRING`) rides with it.
- **20.36** consumes 20.12's catalog, workflow call, refusals and chip.
- **Shared rosters take add-only edits.** These include the governance baseline, `strings.ts`, the screen mirror, `ReadTool`, `ToolRoundTrip`, `ToolEmit`, `SurfaceCoverage` and the floor rosters. `ToolWrite`'s other-port write count (51) moves with 20.34, 20.25 and 20.26. Ask first before any non-add-only edit to `Screen/Registry.cls`, `Kernel/EntityType.cls`, the prohibited set, `Kernel/Proposal/*`, `app.routes.ts` or the CI files.
- **Known flakes:** DW-2461, DW-2472 and DW-2493. Re-run a failed job once; a second red on the same head is a story red.
- **Epic 21 waits on this epic.** 21.8 waits on 20.11, and 21.7 and 21.11 wait on all of Epic 20.
