# Epic 20 Context: Stage 4 - Interoperability, with the Analytics rider

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Give interoperability developers and operators their area inside OcuPilot, where the vendor's new UI covers it only partly. The Interoperability category appears only in namespaces that support it. It covers productions, items, per-host tabs, queues and jobs, lookup tables, tests, messages, and the vendor's rule, BPL and DTL editors and schema viewers embedded in place. An Analytics rider adds cube listing, the model browser, the MDX tool and the cube manager. The owner's 2026-10-07 decisions widen the epic. Interoperability-only accounts are admitted once every screen has its own permission check. A screen's permission becomes visible and adjustable. The agent may propose class, routine, rule, DTL and BPL source edits and creates, each on the person's confirmation. The agent also gains guided workflows and Investigate runs. Every feature keeps the post-Release-1 contract: one descriptor per screen, one port per backing system, and every write a confirmed proposal made as the signed-in user. Embedding never weakens the origin, and no password ever crosses into a frame.

## Stories

Run order: 20.1, 20.2, 20.14, 20.15, 20.17, 20.3 to 20.6, 20.13, 20.7, 20.16, 20.8 to 20.12. Stories 20.1 and 20.2 are done.

- Story 20.1: Namespace category gating (done)
- Story 20.2: Productions, listed and controlled (done)
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
- Story 20.17: The agent proposes class and routine source edits, on the person's confirmation

## Requirements & Constraints

- **The contract every screen keeps (FR-80).** Acceptance is this contract plus each row's own backing route.
  - One descriptor per screen, and exactly one port to the outside.
  - The read tool comes from the descriptor, and write field lists are derived, never hand-typed.
  - Every write is a server-minted proposal with an instance-computed diff, an explicit confirmation and an agent marker.
  - Every read is bounded and reports truncation, and every gate checks the caller's own privileges at call time.
- **Scope.** The epic covers 41 catalog rows: SH-23, SH-25, CP-37, CP-38, IO-02 to IO-29 and AN-02 to AN-10, plus the owner's Stories 20.14 to 20.17. Vendor bundles load in place from `/ui/interop/<app>/index.html`. They are never copied, and they carry no license text.
- **The owner's decisions of 2026-10-07.** Both former holds are closed.
  - **DW-2141 is decided as AD-63, option A.** The editors load in a same-origin frame in normal mode; see Technical Decisions.
  - **DW-2140 is decided as Story 20.14.** First, every screen, route and tool that relied on the API floor alone declares its own pair matching its classic page's check, as Story 19.12 did. Then the floor widens to admit `%Ens_Portal:USE` holders. Such a caller, holding no `%Admin_*` and no `%Development:USE`, reaches exactly the surfaces whose own pairs they hold, and each other surface is refused by its named pair. Today the floor (`Screen/Gate.cls`, `ADMINRESOURCES` plus `%Development`) refuses `%EnsRole_Operator`, `_Administrator` and `_Monitor`. `AtelierPort`'s gate adds `%Development:USE`, so SH-25's Atelier-backed features would refuse operators (inference).
  - **Story 20.15: per-screen permissions.**
    - A screen's required pairs are shown as the instance evaluates them.
    - Developer accounts, Admin accounts and any `%All` holder may change them, even below the classic page's own requirement. The plan proposes the exact pairs; the Planner suggests `%Development:USE` and `%Admin_Secure:USE`.
    - Each change is a confirmed write that the agent may also propose. Its key ships enabled.
    - Each change is audited by a fitting existing event, or else by a custom OcuPilot event registered at install (`Security.Events.Create` guarded by `Exists`).
    - The agent checks whether the user holds a screen's effective pairs before it proposes on that screen, and refuses if they do not. The check builds on Story 11.8's privilege line and on how the agent treats the demo's operator account.
    - Where an adjusted pair lives, and how the descriptor, the gate, the client mirror and the tools read it, is designed at 20.15's spec gate.
  - **"Agent starts switched on."** The governance keys of 20.15, 20.16 and 20.17 ship enabled. Every other new destructive key still ships disabled (AD-22), and each new write key joins `Kernel/Governance/Baseline.cls` in the same change.
- **Still unproven, so settle each before building on it.**
  - The Analytics rider needs a DeepSee-enabled namespace for everything except its three links. Measured on `ocupilot-b-ci`: HSLIB and HSSYS report analytics, HSCUSTOM and USER report interoperability only, and `%SYS` reports neither.
  - The schema viewer's document parameter (20.8), and the interop editor's `HOST=` and `NEW=1` parameters, which are inferred only from selector names.
- **Four rows ship read-only first**, because their actions need custom endpoints: queue actions (`Ens.Queue`), job actions (`Ens.Job`), business-partner save and remove (`Ens.Config.BusinessPartner`), and the message-contents renderer. Such a read is a stated partial, not a completed row.
- **Budgets.** The bundle warns at 3165kB and errors at 4000kB (`ui/angular.json`); 20.2 built at 3.05 MB. The Fixed-strings bound is 2900 literals (`ui/tools/strings.test.mjs:592`), and the table holds 2,828 after 20.2. Each move of the bound carries a comment.

## Technical Decisions

- **Everything is in process (AD-1, AD-36).** A screen and its tool share one declared read through a port. No browser or tool calls `/api/interop-editors` or `/api/deepsee`. Only AD-57's try-it console uses a JWT application's reach, and it is not the write path.
- **AD-62 `Port/InteropPort` is the only way to interoperability.** Every Interoperability screen, read tool and write tool goes through it.
  - **What it calls.** It calls `Ens.Director`, `Ens.Config.Production:ProductionStatus` and `%Dictionary.ClassDefinition:SubclassOf`, as the signed-in user. It never calls `%Api.InteropEditors.*`, whose state route lacks update and restart, answers an unknown state with success, and is `[Hidden]`. It never calls `CleanProduction`, and never makes an HTTP call.
  - **Gate first (AD-29).** The port checks the endpoint's pairs, then READ on the namespace's globals database, or WRITE for a write, and names the failed pair. The vendor's reads check nothing, so this gate is the whole gate for a read.
  - **Namespace (AD-16, AD-44).** The namespace must report interoperability (`INTEROP.NAMESPACE` otherwise). The port switches by explicit save and restore, and calls no `OcuPilot.*` class while switched.
  - **Escalation (AD-8).** The vendor escalates; OcuPilot never does. `%SYS.Ensemble` checks the caller's run resource, then runs start, stop, restart and update as `_Ensemble`. Recover runs as the caller.
  - **Writes are action-style (AD-51)** over a port-composed `STATE` read. Each refuses by name, before any vendor call, every state the vendor would answer as a silent success. Each finishes in its own request (AD-7): the production's own timeout is capped at 15 s, a busy production is refused (`INTEROP.PRODUCTION.BUSY`) and left as it was, and no job is spawned.
  - **Pairs beyond the screens' sets.** The production tools declare `%Ens_ProductionRun:USE` and WRITE on the globals database. The rules, transformations and processes lists declare `%Ens_Code:READ`, standing in for the classic page's OR list. That is a named narrower audience, as is Update for a holder of only `%Ens_ConfigItemRun`.
  - **Source kind `interop`.** Today it offers `LIST` on four endpoints, with no criteria, detail call or parts. A `production` id is the class name, kept exactly (AD-13). Anything beyond this vocabulary amends AD-62 and AD-36 at the story's spec gate.
- **What 20.2 shipped for later stories to consume.**
  - `Port/InteropPort`, and the `INTEROP.*` codes in `Api/InteropError.cls`, where new interop codes go.
  - The `production` entity type.
  - Four list screens, `interop.productions`, `interop.processes`, `interop.transforms` and `interop.rules`, all rendered by the generic `ListPage`.
  - Five tools, `interop.productions.start`, `.stop`, `.restart`, `.update` and `.recover`, over the abstract `Screen/Tool/InteropProductionAction`. All five are non-destructive and enabled.
  - Tests: `InteropDescriptor`, `InteropControl`, `InteropGate` and `InteropGateSeam`. Probe productions come from `Test/ProductionProbe`, because `Test/InteropProbe` belongs to Story 18.15.
  - Browser specs call `waitForMapAnswered(page, timeoutMs)` from `ui/browser/namespace-features.mjs` before asserting anything that depends on the navigation map. This fixed a CI race.
- **Audit gaps (AD-15, AD-53).** Production update and recover record no vendor event; start, stop and restart record `%Ensemble/%Production/StartStop`. These are AD-15's nineteenth named case and AD-53's named gap twenty. Measure every new write with auditing on, and name a gap where the vendor is silent.
- **AD-63: the vendor editors in a same-origin frame (Story 20.13, and every embed in 20.7, 20.8 and 20.10).**
  - **Fixed source.** The frame loads `/ui/interop/<editor>/index.html` on the instance's own origin, with only the editor's own query parameters. Their values come from a read OcuPilot answered, never from a person's text. Example: `rule-editor/index.html?$NAMESPACE=<ns>&rule=<class>`.
  - **Normal mode only.** Never use `?VSCODE=1`, whose message listener accepts a username and password from any sender. Never pre-write tokens into the editor's storage.
  - **OcuPilot reaches nothing in the frame.** It posts nothing, reads nothing, and touches no storage or messages there. The editor signs itself in from the browser-level login, with no password and no message.
  - **Sign-out and sandboxing.** Sign-out ends the editors' sign-in. The frame is not sandboxed, because a sandboxed frame never signs in.
  - **Accepted consequence.** The editor's script can read the tab's `ocupilot.token-pair`, which is no more than any same-origin code already gets. Saved and compiled notices exist only in VSCODE mode, so OcuPilot never receives them, and 20.7 re-scopes its messages criterion. A reload after an agent write (20.16) therefore has to come from the host side (inference).
- **AD-53 reversed (Story 20.17).**
  - `explorer.classes.save` and `explorer.routines.save` become advertised, agent-offered confirmed writes, with their keys enabled. They stay unadvertised until 20.17 ships.
  - The card shows the whole diff and the compile outcome, and a confirm is refused if the document changed after the mint (ETag or fingerprint).
  - A create shows the whole new document, fingerprints the name's absence (AD-54), and targets the current namespace, which needs write access to its code database.
  - Unchanged: AD-10 refuses OcuPilot's own packages (new names included), system and `%` names, and the read-only system databases. `explorer.sqldata.save` stays person-only and unadvertised.
  - 20.16 applies the same pattern to rule, DTL and BPL content: warn the person to save the editor first, then read the stored content, propose with the diff and the marker, refuse a stale confirm, and reload the editor.
- **Privileges (AD-8, AD-29, AD-44).**
  - Establish a pair set two ways: read the backing class's own check, then run the read as a least-privileged principal on the throwaway.
  - The Interoperability area declares `%Ens_Portal:USE`. Analytics declares `%DeepSee_Portal:USE`, which is public `U`, so each 20.11 screen declares its classic page's resource as its own pair.
  - A descriptor names the classic page it replaces, and its pairs union that page's resource. `AreaCoverageProblem` holds an area's set to its screens' pairs. A tool lists the other pages it performs in `CLASSICPAGES`.
- **From 20.1.**
  - `Kernel/Shell/NamespaceFeatures` provides `Reports` and `Applies(feature, ns)`. Neither switches namespace or escalates.
  - In `Screen/Area.cls`, `interoperability` sits at rail position 9 and `analytics` at 10. A new screen joins its area and inherits its `appliesWhen`.
  - The client's `NavigationService` fails closed on applicability and re-reads on a namespace change. No component computes applicability.
- **Write kinds (AD-52: each declares its port).**
  - Action-style (AD-51): control actions, enable and disable.
  - Create (AD-54): an added item, a new lookup table, a new class.
  - Merge (AD-4): item settings, though whether the vendor's save keeps keys its body omits is unmeasured.
  - Every write reads its target back (AD-58), and a port that defines `Invoke` needs a `Snippet` for each branch (AD-59).
  - A screen action and the agent's write are one operation (AD-53, AD-55).
  - Any write that cannot finish within the request has no spine path yet (inference).
- **Identity and content.**
  - New entity types join the kernel's closed enum (AD-14) with a canonical-spelling rule (AD-13). A production item is a composite id in one path segment, scoped to the route's namespace (AD-44).
  - Event text, message content and production, item and class names are untrusted (AD-11) and pass the sanitizer (AD-60).
  - Message bodies can hold patient data, so they stay screen-only (inference).
  - Lookup-table import and export carry content, never a server path (AD-21).
- **Workflows and Investigate.** The turn job never mutates (AD-7), so Investigate is read-only. Confirming a proposal cancels its siblings (AD-34), and a proposal dies with its turn (AD-40). So a workflow mints each write only after the previous one is confirmed, never as a batch approval (inference). The prohibited set, both switches and the governance policy are still evaluated at each write.
- **Harvest.** Take handler bodies only from the MCP suite, and rename every `ExecuteMCPv2` name.
  - `REST/Interop.cls` and `REST/Analytics.cls`.
  - `REST/MessageResend.cls`: `dryRun` defaults to true, and executing needs `confirm`. A match over 100 ids or 500 messages within a 7-day window is refused.
  - `Diagram/*`, for 20.9's sequence diagram.

## UX & Interaction Patterns

- **Navigation.**
  - The rail draws eleven items where both categories apply and nine where neither does, with Agent co-pilot pinned to the bottom. Home shows one tile per applying area, seven to nine.
  - Interoperability's side bar reads Productions · Business processes · Data transformations · Business rules, and lists only built screens.
  - A namespace switch re-fetches rather than re-routes.
  - Per-host tabs are one descriptor per tab, grouped by `tab` and parent-scoped (AD-5).
- **Confirmations.**
  - A destructive write takes the typed-name confirmation. The five production writes are non-destructive and show warning dialogs whose text is also the card's consequence line.
  - Recover's card says recover comes before clean. A resend's card shows its dry run.
  - Cards name the required privileges (AD-8), and dialogs never stack.
- **Long blocks in the agent panel (20.17, panel-wide).**
  - A block over about eight lines starts collapsed behind "Show more" / "Show less". The control is keyboard-operable and announces its state, and an expanded block stays expanded across re-renders.
  - A collapsed card always shows a summary line, such as "AcmeApp.Orders.cls: +42 / -3 lines", plus the compile outcome, and Confirm never requires expanding.
  - EXPERIENCE.md is amended at 20.17's spec gate. The plan may split the collapse into its own story, ordered first.
- **Strings and prompts.** Each new literal goes into EXPERIENCE.md's Fixed strings and `strings.ts`, and each built screen declares at least three suggested prompts. After editing EXPERIENCE.md or epics.md, run `cd ui && npm run test:tools`.
- **Investigate** starts from alerts and log entries, beside the unified log hub (16.9). It reuses Explain this entry's marker (AD-24) and cites rows with citation chips (AD-11).

## Cross-Story Dependencies

- **Within the epic.**
  - **20.14** runs right after 20.2, whose screens already declare their own pairs. **20.15** follows 20.14. **20.17** follows 20.15 and uses its rule that the agent refuses to propose on a screen the user cannot access.
  - **20.3 to 20.6, 20.9 and 20.12** extend `InteropPort` and the `production` entity. 20.12's recover-stuck-production workflow uses `interop.productions.recover` and `.start`. 20.9 resends what recover marked.
  - **20.13** runs before 20.7 and gates the embeds in 20.7, 20.8 and 20.10, and 20.9's contents viewer if it embeds.
  - **20.16** follows 20.7 and builds on 20.17. **20.10** needs 20.7's editors.
  - **20.11** sits under the Analytics area's pair set and `AreaCoverageProblem`.
- **Open from 20.2.** A stop from Running once left a production reading Suspended while the tool answered success (deferred, unverified).
- **Prerequisites.** Epics 11 and 12 are merged. Epic 19 is done, and 20.17 builds on its Story 19.3 saves (`Screen/Tool/ExplorerClassSave`, `ExplorerRoutineSave`). Sprint planning passed with CONCERNS.
- **Parallel run.** Epic 20 runs whole on slot B. Slot A runs the rest of Epic 18 (18.25 to 18.27, 18.9 to 18.13, burn-down 18.28), then Story 23.5.
  - 18.12 overlaps 20.12 in the tool registry, and 18.13 overlaps `navigation.ts`. Whichever merges second rebases.
  - Keep shared-file edits add-only: `Baseline.cls`, `strings.ts`, EXPERIENCE.md, `SurfaceCoverage`, `Prohibited.cls`, the `Api/Error.cls` prefix lines, and the count bumps in `EntityType.cls`, `Test/Descriptor.cls` and `Test/ReadTool.cls`. The second epic to merge regenerates `screens.generated.ts` whole.
- **Slot B.**
  - Use profile `ocupilot-slot-b`, and throwaway `ocupilot-b-ci` on 52777/1976.
  - Before loading, sync the worktree's `src` into `/Users/jbrandt/.ocupilot-throwaways/ocupilot-b-ci/src`, then load through `docker exec ocupilot-b-ci`. Never use the MCP loader for this, because it reaches the dev instance.
  - Run one test class per call (`node tools/ci-runner.mjs --container ocupilot-b-ci --class ...`).
  - Before any browser run, rebuild the bundle and `docker cp` it in, with `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777` and `OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci`.
  - Never restart an `ocupilot-slot-*` container.
