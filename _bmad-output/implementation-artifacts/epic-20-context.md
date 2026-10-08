# Epic 20 Context: Stage 4 - Interoperability, with the Analytics rider

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Give interoperability developers and operators their area inside OcuPilot, where the vendor's new UI covers it only partly. The Interoperability category appears only in namespaces that support it. It covers productions, items, per-host tabs, queues and jobs, lookup tables, tests, messages, and the vendor's rule, BPL and DTL editors and schema viewers embedded in place. An Analytics rider adds cube listing, the model browser, the MDX tool and the cube manager. The owner's 2026-10-07 decisions widen the epic. Interoperability-only accounts are admitted once every screen has its own permission check. A screen's permission is visible and adjustable, and the agent proposes such changes but refuses on a screen the user cannot open. The agent may propose class, routine, rule, DTL and BPL source edits and creates, each on the person's confirmation. The agent also gains guided workflows and Investigate runs. Every feature keeps the post-Release-1 contract: one descriptor per screen, one port per backing system, and every write a confirmed proposal made as the signed-in user. Embedding never weakens the origin, and no password ever crosses into a frame.

## Stories

Run order: 20.1, 20.2, 20.14, 20.15, 20.18, 20.17, 20.3 to 20.6, 20.13, 20.7, 20.16, 20.8 to 20.12. Stories 20.1, 20.2, 20.14 and 20.15 are done.

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
- Story 20.14: Interoperability holders reach OcuPilot (done)
- Story 20.15: Per-screen permissions, seen and adjusted (done)
- Story 20.16: The agent edits rule, DTL and BPL content behind the embedded editors
- Story 20.17: The agent proposes class and routine source edits, on the person's confirmation
- Story 20.18: The agent proposes permission changes and refuses on a screen the user cannot open

## Requirements & Constraints

- **The contract every screen keeps (FR-80).** Acceptance is this contract plus each row's own backing route.
  - One descriptor per screen, and exactly one port to the outside.
  - The read tool comes from the descriptor, and write field lists are derived, never hand-typed.
  - Every write is a server-minted proposal with an instance-computed diff, an explicit confirmation and an agent marker.
  - Every read is bounded and reports truncation, and every gate checks the caller's own privileges at call time.
- **Scope.** The epic covers 41 catalog rows: SH-23, SH-25, CP-37, CP-38, IO-02 to IO-29 and AN-02 to AN-10, plus the owner's Stories 20.14 to 20.18. Vendor bundles load in place from `/ui/interop/<app>/index.html`. They are never copied, and they carry no license text.
- **The owner's decisions of 2026-10-07.**
  - **DW-2141 is decided as AD-63, option A.** The editors load in a same-origin frame in normal mode; see Technical Decisions.
  - **DW-2140 is decided as Story 20.14, shipped (AD-8 amended).** The API floor admits `%Ens_Portal:USE` holders. Such a caller, holding no `%Admin_*` and no `%Development:USE`, reaches exactly the surfaces whose own pairs they hold. `AtelierPort`'s gate adds `%Development:USE`, so SH-25's Atelier-backed features would refuse operators (inference).
  - **"Agent starts switched on."** The governance keys of 20.15, 20.16 and 20.17 ship enabled. Every other new destructive key still ships disabled (AD-22), and each new write key joins `Kernel/Governance/Baseline.cls` in the same change.
- **Story 20.18 must build** (the agent half of 20.15, split at its merge gate):
  - Advertise `agent.screenpermissions.addpair`, `.removepair` and `.reset`. The card shows the pairs before and after and the "requires" line. Confirming writes the agent marker and `SecurityChange`.
  - Mint the agent's lowering as a delete is: the destructive treatment, with no typed name (AD-10's privilege-grant precedent).
  - When the user lacks a write tool's screen's effective pairs, an adjustment included, dispatch refuses before any mint, naming the screen and the failed pair. The prompt says the user cannot access that screen and proposes nothing. The demo operator's refusal names the screen too.
  - Screen context carries the current screen's own verdict, derived on the instance, and marks which of its tools the user cannot use.
  - An integration turn, run as a principal lacking an adjusted screen's pair, is refused at that screen, creates no proposal row, and completes.
  - DW-2181: run the tools' agent propose-and-confirm path end to end (the state diff, `Reset`'s port-query payload branch, the gone read-back). It was declared and never run.
  - Starting point, read at 20.15's plan: dispatch already refuses a missing pair with `AUTH.NOPRIVILEGE` and `detail.failedPair` before any mint, and follows an adjustment. Screen context's `tools` is unfiltered, the prompt has no `AUTH.NOPRIVILEGE` line, and the card's "requires" line is a mint snapshot while the confirm re-gates live.
- **Still unproven, so settle each before building on it.**
  - The Analytics rider needs a DeepSee-enabled namespace for everything except its three links. Measured on `ocupilot-b-ci`: HSLIB and HSSYS report analytics, HSCUSTOM and USER report interoperability only, and `%SYS` reports neither.
  - The schema viewer's document parameter (20.8), and the interop editor's `HOST=` and `NEW=1` parameters, which are inferred only from selector names.
- **Four rows ship read-only first**, because their actions need custom endpoints: queue actions (`Ens.Queue`), job actions (`Ens.Job`), business-partner save and remove (`Ens.Config.BusinessPartner`), and the message-contents renderer. Such a read is a stated partial, not a completed row.
- **Budgets.** The bundle warns at 3165 kB and errors at 4000 kB (`ui/angular.json`), and stands at about 3.12 MB. The Fixed-strings bound is 3000 literals (`ui/tools/strings.test.mjs`). Each move of the bound carries a comment.

## Technical Decisions

- **Everything is in process (AD-1, AD-36).** A screen and its tool share one declared read through a port. No browser or tool calls `/api/interop-editors` or `/api/deepsee`. Only AD-57's try-it console uses a JWT application's reach, and it is not the write path.
- **AD-62 `Port/InteropPort` is the only way to interoperability.** Every Interoperability screen, read tool and write tool goes through it.
  - **What it calls.** It calls `Ens.Director`, `Ens.Config.Production:ProductionStatus` and `%Dictionary.ClassDefinition:SubclassOf`, as the signed-in user. It never calls `%Api.InteropEditors.*`, whose state route lacks update and restart, answers an unknown state with success, and is `[Hidden]`. It never calls `CleanProduction`, and never makes an HTTP call.
  - **Gate first (AD-29).** The port checks the endpoint's pairs, then READ on the namespace's globals database, or WRITE for a write, and names the failed pair. The vendor's reads check nothing, so this gate is the whole gate for a read.
  - **Namespace (AD-16, AD-44).** The namespace must report interoperability (`INTEROP.NAMESPACE` otherwise). The port switches by explicit save and restore, and calls no `OcuPilot.*` class while switched. DW-2161 is accepted as wontfix: a confirm from a different namespace than the mint resolves the tool's database pair in the confirming request's scope, and the port re-gates the correct namespace.
  - **Escalation (AD-8).** The vendor escalates; OcuPilot never does. `%SYS.Ensemble` checks the caller's run resource, then runs start, stop, restart and update as `_Ensemble`. Recover runs as the caller.
  - **Writes are action-style (AD-51)** over a port-composed `STATE` read. Each refuses by name, before any vendor call, every state the vendor would answer as a silent success. Each finishes in its own request (AD-7): the production's own timeout is capped at 15 s, a busy production is refused (`INTEROP.PRODUCTION.BUSY`) and left as it was, and no job is spawned.
  - **Pairs beyond the screens' sets.** The production tools declare `%Ens_ProductionRun:USE` and WRITE on the globals database. The rules, transformations and processes lists declare `%Ens_Code:READ`, standing in for the classic page's OR list. That is a named narrower audience, as is Update for a holder of only `%Ens_ConfigItemRun`.
  - **Source kind `interop`.** Today it offers `LIST` on four endpoints, with no criteria, detail call or parts. A `production` id is the class name, kept exactly (AD-13). Anything beyond this vocabulary amends AD-62 and AD-36 at the story's spec gate.
- **What 20.2 shipped.** `Port/InteropPort`, with new interop codes in `Api/InteropError.cls`; the `production` entity type; four `ListPage` screens (`interop.productions`, `.processes`, `.transforms`, `.rules`); five non-destructive, enabled tools (`interop.productions.start`, `.stop`, `.restart`, `.update`, `.recover`) over `Screen/Tool/InteropProductionAction`. Probe productions come from `Test/ProductionProbe`, because `Test/InteropProbe` belongs to Story 18.15.
- **What 20.14 shipped, and the rule it sets for every later story.**
  - `Screen.Gate.FloorResources()` ends with `%Ens_Portal`.
  - A surface's own pair is any pair on a resource other than `%Ens_Portal`. A surface with none is listed, with its reason, in `Test.InteropFloorOwnPairs`' `FLOORONLY` roster.
  - `Test.InteropFloor`, `InteropFloorRoutes` and `InteropFloorTurn` pin four principals' rosters: E (`%Ens_Portal` only), `%EnsRole_Monitor`, `_Operator` and `_Administrator`.
  - Every new Interoperability or Analytics screen, tool or route either declares its own pair or joins `FLOORONLY` with its reason. A new surface whose pairs a stock `%EnsRole_*` grants joins those principals' rosters in its own story.
- **What 20.15 shipped (AD-64).**
  - **Store and one reader.** `Kernel/State/Access` holds one instance-wide row per adjusted screen, keyed by `toolIdentifier`, replacing its declared `privileges`. `Screen.Gate.RequiredPairs` is its one reader, on every call, never cached; a failed read refuses. Every screen, area, read, tool, dispatch, confirm and route gate follows an adjustment. A write tool's own extra pairs and `CLASSICPAGES` resources are added on top, unchanged.
  - **The classic custom resource stays.** `RequiredPairs` unions the classic page's custom resource (AD-44), which only the classic portal clears. OcuPilot never writes `%SYS.Portal.Resources`.
  - **Screen permissions** (`agent.screenpermissions`, source kind `access`, entity type `screen-permission`) lists every built screen's declared pairs, adjustment, classic resource and effective pairs. Its write tools `.addpair` and `.removepair` apply one `Pair` as a server-side delta over the fresh read, and `.reset` clears the row, all through `Port/ScreenAccessPort`. The tools are unadvertised until 20.18, and their keys ship enabled.
  - **The either-of.** Screen permissions, its read and its three tools admit `%Development:USE` OR `%Admin_Secure:USE` (owner, 2026-10-08), AD-8's one either-of exception. It is one pair whose resource is `%Development|%Admin_Secure` (`Gate.AdjusterPairs`); `Gate.Alternatives` splits only that pair. A refusal names both. Never generalize descriptors to any-of.
  - **Never adjustable.** Ports' and the vendor's checks, an area's set, and the Home and Agent co-pilot groups (`Screen.Gate.Adjustable`), refused `PROHIBITED.OCUPILOTSCREEN`. A set holds 1 to 8 pairs on defined resources at READ, WRITE or USE; an emptying set is refused 422 `ACCESS.PAIRS.EMPTY`.
  - **Audit.** Each adjustment records `OcuPilot/Security/SecurityChange` with the pairs before and after, plus the agent's marker for an agent write.
  - **Client.** No client code derives availability from the mirror's `privileges`. The shell re-reads the navigation map on a `screen-permission` change event.
- **Tests and browser specs.**
  - A test that adjusts a screen resets it in its `OnAfter*` method.
  - Anything read before the navigation map answers waits for `waitForMapAnswered(page, timeoutMs)` from `ui/browser/namespace-features.mjs`. A structural gate measured right after `setViewport` can flake (DW-2163, outside this epic).
  - A browser spec holds whatever another spec left on the instance: never assert a store empty that another spec can write (20.14's secondary-logs lesson). A long-lived throwaway accumulates rows (DW-2182).
- **Audit gaps (AD-15, AD-53).** Production update and recover record no vendor event; start, stop and restart record `%Ensemble/%Production/StartStop`. These are AD-15's nineteenth named case and AD-53's named gap twenty. Measure every new write with auditing on, and name a gap where the vendor is silent.
- **AD-63: the vendor editors in a same-origin frame (Story 20.13, and every embed in 20.7, 20.8 and 20.10).**
  - **Fixed source.** The frame loads `/ui/interop/<editor>/index.html` on the instance's own origin, with only the editor's own query parameters. Their values come from a read OcuPilot answered, never from a person's text. Example: `rule-editor/index.html?$NAMESPACE=<ns>&rule=<class>`.
  - **Normal mode only.** Never use `?VSCODE=1`, whose message listener accepts a username and password from any sender. Never pre-write tokens into the editor's storage.
  - **OcuPilot reaches nothing in the frame.** It posts nothing, reads nothing, and touches no storage or messages there. The editor signs itself in from the browser-level login.
  - **Sign-out and sandboxing.** Sign-out ends the editors' sign-in. The frame is not sandboxed, because a sandboxed frame never signs in.
  - **Accepted consequence.** The editor's script can read the tab's `ocupilot.token-pair`, no more than any same-origin code gets. Saved and compiled notices exist only in VSCODE mode, so 20.7 re-scopes its messages criterion, and a reload after an agent write (20.16) has to come from the host side (inference).
- **AD-53 reversed (Story 20.17).**
  - `explorer.classes.save` and `explorer.routines.save` become advertised, agent-offered confirmed writes, with their keys enabled. They stay unadvertised until 20.17 ships.
  - The card shows the whole diff and the compile outcome, and a confirm is refused if the document changed after the mint (ETag or fingerprint).
  - A create shows the whole new document, fingerprints the name's absence (AD-54), and targets the current namespace, which needs write access to its code database, settled against the screen's effective pairs.
  - Unchanged: AD-10 refuses OcuPilot's own packages (new names included), system and `%` names, and the read-only system databases. `explorer.sqldata.save` stays person-only and unadvertised.
  - 20.16 applies the same pattern to rule, DTL and BPL content: warn the person to save the editor first, then read the stored content, propose with the diff and the marker, refuse a stale confirm, and reload the editor.
- **Privileges (AD-8, AD-29, AD-44).**
  - Establish a pair set two ways: read the backing class's own check, then run the read as a least-privileged principal on the throwaway.
  - The Interoperability area declares `%Ens_Portal:USE`. Analytics declares `%DeepSee_Portal:USE`, which is public `U`, so each 20.11 screen declares its classic page's resource as its own pair.
  - A descriptor names the classic page it replaces, and its pairs union that page's resource. `AreaCoverageProblem` holds an area's set to its screens' pairs. A tool lists the other pages it performs in `CLASSICPAGES`.
- **From 20.1.** `Kernel/Shell/NamespaceFeatures` provides `Reports` and `Applies(feature, ns)`; neither switches namespace or escalates. In `Screen/Area.cls`, `interoperability` sits at rail position 9 and `analytics` at 10; a new screen joins its area and inherits its `appliesWhen`. The client's `NavigationService` fails closed on applicability and re-reads on a namespace change; no component computes applicability.
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
- **Harvest.** Take handler bodies only from the MCP suite, and rename every `ExecuteMCPv2` name: `REST/Interop.cls` and `REST/Analytics.cls`; `REST/MessageResend.cls` (`dryRun` defaults to true, executing needs `confirm`, a match over 100 ids or 500 messages within a 7-day window is refused); `Diagram/*` for 20.9's sequence diagram.

## UX & Interaction Patterns

- **Navigation.**
  - The rail draws eleven items where both categories apply and nine where neither does, with Agent co-pilot pinned to the bottom. Home shows one tile per applying area, seven to nine.
  - Interoperability's side bar reads Productions · Business processes · Data transformations · Business rules, and lists only built screens.
  - A namespace switch re-fetches rather than re-routes.
  - Per-host tabs are one descriptor per tab, grouped by `tab` and parent-scoped (AD-5).
- **Confirmations.**
  - A destructive write takes the typed-name confirmation, except the agent's screen-permission lowering (20.18), which gets the destructive treatment with no typed name. A person's lowering states its consequence at the dialog.
  - The five production writes are non-destructive and show warning dialogs whose text is also the card's consequence line.
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
  - **20.18** runs next and builds on 20.15's store, gate and tools.
  - **20.17** follows 20.18 and depends on its refusal at dispatch. Its create is settled against the screen's effective pairs from 20.15.
  - **20.3 to 20.6, 20.9 and 20.12** extend `InteropPort` and the `production` entity. 20.12's recover-stuck-production workflow uses `interop.productions.recover` and `.start`. 20.9 resends what recover marked.
  - **20.3 owns DW-2157 and DW-2162.** A stop answers the state its post-write read finds, with new `INTEROP.*` codes and Fixed-strings sentences for a production that ends Suspended, or half-stopped past the 15 s cap.
  - **20.13** runs before 20.7 and gates the embeds in 20.7, 20.8 and 20.10, and 20.9's contents viewer if it embeds.
  - **20.16** follows 20.7 and builds on 20.17. **20.10** needs 20.7's editors.
  - **20.11** sits under the Analytics area's pair set and `AreaCoverageProblem`.
- **Prerequisites.** Epics 11 and 12 are merged. Epic 19 is done, and 20.17 builds on its Story 19.3 saves (`Screen/Tool/ExplorerClassSave`, `ExplorerRoutineSave`). Sprint planning passed with CONCERNS.
- **Parallel run.** Epic 20 runs whole on slot B. Slot A runs the rest of Epic 18 (18.9 to 18.13, burn-down 18.28), then Story 23.5. 18.25 and 18.26 are merged into this branch, and 18.27 closed unbuilt.
  - The branch holds 62 entity types, written out in `Test/Descriptor`, `Test/MftConnectionDescriptor` and `Test/SuperserverDescriptor`; a new type bumps all three.
  - 18.12 overlaps 20.12 in the tool registry, and 18.13 overlaps `navigation.ts`. Whichever merges second rebases.
  - Keep shared-file edits add-only: `Baseline.cls`, `strings.ts`, EXPERIENCE.md, `SurfaceCoverage`, `Prohibited.cls`, the `Api/Error.cls` prefix lines, and the count bumps in `EntityType.cls`, the three descriptor tests above and `Test/ReadTool.cls`. The second epic to merge regenerates `screens.generated.ts` whole.
- **Slot B.**
  - Use profile `ocupilot-slot-b`, and throwaway `ocupilot-b-ci` on 52777/1976.
  - Before loading, sync the worktree's `src` into `/Users/jbrandt/.ocupilot-throwaways/ocupilot-b-ci/src`, then load through `docker exec ocupilot-b-ci`. Never use the MCP loader for this, because it reaches the dev instance.
  - Run one test class per call (`node tools/ci-runner.mjs --container ocupilot-b-ci --class ...`).
  - Before any browser run, rebuild the bundle and `docker cp` it in, with `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777` and `OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci`.
  - Never restart an `ocupilot-slot-*` container.
