# Epic 20 Context: Stage 4 - Interoperability, with the Analytics rider

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Bring the classic portal's Interoperability work into OcuPilot for namespaces that support it, with Analytics riding along. That covers productions, items, per-host tabs, lookup tables, partners, messages, the embedded vendor editors, cubes and MDX. The agent also gains guided multistep workflows and Investigate, so the largest area the classic portal still owns can be used here. Most of the epic has shipped. This resumed run (slot B) finishes the remainder in this order: 20.34 (cube manager, implemented and in review), 20.39 (every list's name opens something), 20.36 (Investigate), 20.25 (item runtime and configuration actions), 20.26 (business-partner writes), then the burn-down.

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
- Story 20.38: A schema opens its tables, views and procedures
- Story 20.39: Every list's name opens something

## Requirements & Constraints

- **Every write** is a server-minted, single-use, fingerprinted proposal. The instance computes its diff, it needs an explicit Confirm, and it carries the agent marker. A workflow is a sequence of confirmations, never a batch approval.
  - A new write key joins the governance baseline in the same change, and a new destructive key ships disabled.
  - Each plan states every action's destructiveness, its key's default and its audit record.
  - Security-posture questions go to the orchestrator with options and a recommendation.
- **20.39.** Story 20.38's link check holds an exact allow-list of 17 lists whose name links back to the list itself, so a click changes the address and the page stays put. This story empties that allow-list, and the check still fails on any new self-link.
  - Each name opens that object's existing screen, or renders as plain text where nothing should open.
  - Where more than one target is plausible, the plan names the choice and its reason, and plain text is the default. The lists with more than one plausible target are SQL privileges, web-application class access, database free space, DocDB, business partners, analytics folder items and screen permissions.
  - The spec lists each list and what it now does. DW-2504 (stale doc comments now pointing at `navigation.ts`'s `nameLinkTarget`) rides along.
  - Out of scope: new screens for objects that have none, stored data and the installer.
- **20.36, Investigate.** Choosing Investigate on an alert or a log entry starts a multistep run. It returns a recap and hypotheses ranked most likely first, citing the rows it used.
  - It reuses 20.12's workflow catalog, its synthetic workflow call and its refusals. The outline is in 20.12's spec, Design Notes › Split, and 20.36's spec is already written.
  - It owns DW-2468: a workflow's step tools must join the turn's starting tool set.
  - It owns DW-2469: `previous` must report only the same workflow's earlier turns.
- **20.25, item actions.** It covers a temporary stop, a start and a restart of one item of the running production.
  - Each runs over a fresh read and is followed by the production update the vendor requires.
  - Each is refused by name before any vendor call where the vendor would answer success while doing nothing: a stopped production, or a disabled item.
  - Copy and change of class run as the classic page does, and the vendor's own audit records them.
  - It updates ToolWrite's other-port write count in the same pass (DW-2407).
- **20.26, partner writes.** Create, update and remove run on `Ens.Config.BusinessPartner` as confirmed writes over a fresh read, and each records OcuPilot's own audit row, because the vendor records none.
  - **Rename.** The vendor renames as a delete and a create with no transaction, so the plan either refuses a rename or performs it in one transaction.
  - **Remove.** It first reads the items whose `BusinessPartner` setting names the partner, then refuses or warns, as the plan states.
  - **Pairs.** The pairs posture goes to the orchestrator; the recommendation is `%Ens_ProductionConfig:WRITE`. A stricter pair is the spec gate's call, while a looser one or a new escalation is the owner's.

## Technical Decisions

- **`Port/InteropPort`** is the only class that controls productions or reads interoperability configuration. It calls the vendor's classes in process as the signed-in user and never calls `%Api.InteropEditors`.
  - The vendor's reads check no privilege, so the port's gate is the whole gate. A refusal names the failed pair.
  - Namespace switches use explicit save and restore.
- **Item writes:**
  - an item is identified by `[Production, Name]`, never by the vendor's integer id;
  - every item write also calls `SaveToClass`, after which a running production reads update pending;
  - a namespace under source control refuses item writes with `INTEROP.ITEM.SOURCECONTROL`;
  - item pairs are `%Ens_ProductionConfig:WRITE` plus WRITE on the namespace's globals and routines databases.
- **Partners.** The partner entity type is `business-partner`, keyed by the partner's name exactly. The reads use `%Ens_ProductionConfig:READ`, and lookup and partner writes record OcuPilot's own `ConfigChange`.
- **Write shapes:**
  - An action-style write declares its request type, sends no body and fingerprints the fresh read (AD-51).
  - A create, a copy included, inverts the fresh read and fingerprints the target's absence (AD-54).
  - A tool declares the port it writes through (AD-52), and a confirmed write reads its target back (AD-58).
- **No compile-time dependency on interoperability.** There is no `Ensemble` include and no `Ens.*` type in a signature; take `%RegisteredObject` or `%String` and reach `Ens.*` only at run time.
- **Secrets.** A secret-named setting is never returned and never set.
- **Untrusted content.** Vendor text reaches the model only through the one sanitizer, and reaches the screen only as interpolated text.
- **Workflows (AD-66).** The catalog is `Kernel/Agent/Workflow`'s `XData Catalog`, and a new workflow is a new entry, never a code path.
  - An unknown workflow id is refused with `WORKFLOW.UNKNOWN`.
  - Dispatch refuses a write that no step names (`WORKFLOW.NOTASTEP`) and a second proposal in the same turn (`WORKFLOW.ONECHANGE`).
  - The prohibited set, both switches and the governance policy are evaluated at the write.
- **Screen descriptors (AD-5).** One hand-written descriptor per screen is the source of its route, gate, read tool, context and links. `screens.generated.ts` is emitted by `screen-mirror.mjs`, and any grammar change is validated alike by `Screen/Registry.cls` and the mirror.
  - **Name-cell link options:**
    - a paired viewer at the parent list's `<route>/document`, unlisted;
    - one cross-screen row target, naming the target screen's route and the id field;
    - `unless`, which renders the name as text when a row field reads true;
    - a parent-scoped tab group.
  - A new link grammar, or any AD change, goes to the orchestrator, never into a slice.
- **Stored state.** A new stored property is declared after every existing one, because the source has no Storage section (20.37's fix-forward).
- **Client.** The client is zoneless, `OnPush` and store-held. Each page loads on demand. Bundle limits are a 2,500 kB warning and a 4,000 kB stop; a crossing is reported to the owner, never re-based.
- **Tests.** Run one test class at a time and read the totals from `%UnitTest_Result`. A browser spec runs against the deployed bundle, so rebuild and redeploy before reading a result.

## UX & Interaction Patterns

- **Gated controls** are never hidden. They are `aria-disabled` and name the failed pair. The name cell navigates.
- **Strings.** A new string goes into EXPERIENCE.md's Fixed strings and into `strings.ts`, without internal ids; then run `cd ui && npm run test:tools`.
  - Inference: 20.26 retires the fixed string "Business partners are added and changed in the classic Business Partners page."
- **Destructive actions** get the destructive treatment, and dialogs never stack.
- **The workflow chip** reads "Guided workflow", followed by Continue and End workflow, and sits above the composer.

## Cross-Story Dependencies

- **Status.** Every story except 20.25, 20.26, 20.36 and 20.39 is done. 20.34 is at `f60db04b`, in its review stages.
- **20.39.** It needed 23.12 merged, which is done, because the task and database descriptors are 23.12's too.
- **20.25** consumes 20.3's items and 20.4's per-host tabs, and **20.26** consumes 20.5's partner screen and read.
- **Epic 23 runs 23.9 on slot A beside this epic.** 23.9 lifts the delete tools' repeated state-diff body into the shared write base. Check its diff before editing shared write or registry files: add-only edits are fine, and anything else is an ask.
- **Shared rosters take add-only edits.** These are the governance baseline, `strings.ts`, the screen mirror, `ReadTool`, `ToolRoundTrip`, `ToolEmit`, `SurfaceCoverage` and `ToolWrite`'s other-port count.
- **Epic 21 waits on this epic.** 21.7 (interoperability parity) and 21.11 (the harvested tools and undo) wait until Epic 20 merges into feature.
