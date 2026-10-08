# Epic 20 Context: Stage 4 - Interoperability, with the Analytics rider

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Bring the classic portal's Interoperability work into OcuPilot for namespaces that support it: productions and their items, per-host tabs, queues and jobs, lookup tables and business partners, host and transformation testing, message search, resend and trace, schema viewers, and the vendor's rule, BPL and DTL editors embedded in place. Analytics rides along with cubes, the model browser, the MDX tool and the cube manager. The agent grows with the stage. It gains guided multistep workflows and Investigate, proposes screen-permission changes, edits rule, DTL and BPL content, and proposes confirmed edits and creates of classes and routines. Owner-added stories make each screen's required permission visible and adjustable, and keep long agent-panel content readable.

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
- Story 20.19: The agent edits existing classes and routines, on the person's confirmation
- Story 20.20: The agent creates new classes and routines, on the person's confirmation

## Requirements & Constraints

- **One build contract for every screen.** A screen has exactly one descriptor and reaches the outside through exactly one port. Its read tool and its write tools' field lists come from that descriptor. Every write is a server-minted proposal with an instance-computed diff, an explicit confirmation and an agent marker. A story is accepted on that contract plus each row's own backing route or class; finer detail is authored when the story is picked up, never invented.
- **Governance keys.** A new write key joins the baseline enabled; a new destructive key ships disabled. The owner set these keys enabled: the screen-permission tools, rule, DTL and BPL edits, and class and routine saves and creates.
- **Vendor bundles are never copied or redistributed.** They load in place from the instance.
- **Read-only first.** These ship as a stated partial, not a completed row, because their action halves need custom endpoints: queue and job actions (abort, abort all, suspend, stop), business-partner save and remove, and the message-contents renderer.
- **Writes with extra rules.**
  - Message resend and edit-and-resend: a dry run, then a confirm, with a bounded cap on how many messages one action resends.
  - A transformation test is a confirmed write, because it executes code.
  - A cube build, synchronize or repair is the one analytics write.
  - Architect, Analyzer and the User Portal are linked, not rebuilt. Analytics beyond links needs a DeepSee-enabled namespace.
- **Guided workflows.** A workflow is a sequence of individually confirmed proposals, never a batch approval. Each write is still checked against the prohibited set, both switches and governance. Investigate, run from an alert or a log entry, returns a recap and ranked hypotheses citing the rows it used. Harvested prompts keep their call sites but take OcuPilot's names: no `iris_` prefix and no sibling package names.
- **Agent edits of classes and routines (20.19).**
  - Both Save tools are advertised and offered to the agent.
  - The model reads a document's source through a read tool capped at about 60,000 characters. The result passes the tool-result sanitizer and reports truncation.
  - The card shows the whole diff. Before Confirm it says the compile runs on Confirm. After Confirm it reports the compile outcome, saying plainly when the document saved but failed to compile.
  - Confirm is refused when the document changed after the mint (ETag or fingerprint).
  - Today the spine keeps a document's whole text screen-only. The source read tool needs that rule amended at the spec gate.
- **Agent creates (20.20).**
  - The card shows the whole new document and its compile outcome.
  - The fingerprint is the name's absence, so a create never silently overwrites.
  - The create targets the user's current namespace and needs WRITE on its code database, settled against the screen's effective pairs.
- **Always refused to the agent, at the mint and again at Confirm.** Documents under OcuPilot's own packages (new names too), every `%` name, system classes and the read-only system databases. `explorer.sqldata.save` stays a person's action and stays unadvertised. A person's own Save is unchanged.
- **Rule, DTL and BPL edits (20.16).**
  - First warn the user to save the editor, because OcuPilot cannot read the frame's unsaved state.
  - Then read the stored content and propose the edit with its diff and marker. The proposal is refused if the stored content changed after the mint.
  - Reload the editor after the write.
  - A typed-name confirmation is raised only for a concrete reason.
- **Posture questions go up.** Any further security-posture question a plan finds goes back to the orchestrator, with options and a recommendation.

## Technical Decisions

- **The interoperability port.**
  - **Sole entry point.** It is the only class that starts, stops, restarts, updates or recovers a production, and the only declared-read source for interoperability configuration (source kind `interop`).
  - **What it calls.** The documented classes the classic pages call, in the caller's process: `Ens.Director`, `Ens.Config.Production:ProductionStatus` and `%Dictionary.ClassDefinition:SubclassOf`. It never calls `%Api.InteropEditors.*`.
  - **Gate first.** Before any vendor call it checks the endpoint's pairs, then READ on the namespace's globals database (WRITE for a write), then `%Ens_ProductionRun:USE` for a production write. The vendor's reads check nothing, so this gate is the whole gate.
  - **Namespace.** The namespace must report interoperability. The port switches by explicit save and restore, and calls no OcuPilot class while switched.
  - **No elevation of OcuPilot's own.** The vendor itself runs start, stop, restart and update as `_Ensemble`.
  - **Writes.** Each is action-style over a port-composed STATE read and refuses a would-be silent no-op by name. Each finishes in its own request. Stop, restart and update are capped at 15 s; a production that will not quiesce answers `INTEROP.PRODUCTION.BUSY`. There is no new spawn site and no `PORT.STARTED`.
  - **Recover, never Clean.** Recover is the response to a troubled production, and its card says so.
  - **Ids.** A `production` id is the class name, kept exactly.
  - **Audit.** Update and recover record no vendor audit event, so the agent's marker is their only record.
  - **Accepted narrower audiences.** The code lists declare `%Ens_Code:READ`. A holder of only `%Ens_ConfigItemRun` is refused Update.
- **Category gating.**
  - A rail area declares `appliesWhen`. `interoperability` is `%Library.EnsembleMgr.IsEnsembleNamespace` and `analytics` is `%DeepSee.Utils.%IsDeepSeeEnabled`.
  - It is read in the caller's process for the route's namespace on every navigation read. A check that throws answers false.
  - This is applicability, not privilege: an area that applies but that the caller cannot open is still drawn, gated.
  - The Interoperability area declares `%Ens_Portal:USE`; the Analytics area declares `%DeepSee_Portal:USE`.
- **API floor and own pairs.**
  - The API's floor admits `%Ens_Portal:USE` beside `%Admin_*` and `%Development`.
  - Every new surface declares its own pair, matching its classic page's check, and goes on the `InteropFloor*` rosters.
  - `%DeepSee_Portal` is public USE, so it can never be the floor.
- **Embedded editors.**
  - Each editor loads in a same-origin `<iframe>` at `/ui/interop/<editor>/index.html`, carrying only the editor's own query parameters, with values from a read OcuPilot answered.
  - Normal mode only. Never `?VSCODE=1`, whose message-based login has no origin check, and never tokens pre-written into the editor's storage.
  - OcuPilot posts nothing into the frame, reads nothing from it, and touches none of its storage or messages. The frame is not sandboxed, because a sandboxed frame never signs in.
  - Sign-out ends the editors' sign-in.
  - The editors' saved, compiled and invalid notices are not available in normal mode.
  - The origin stays hostile ground: tokens stay per tab, with no cross-tab broadcast.
- **Screen permissions.**
  - An adjustment lives in OcuPilot's protected state, keyed by the screen's `toolIdentifier`.
  - `Screen.Gate.RequiredPairs` is the one reader. It reads at every gate, uncached, and always unions the classic page's custom resource.
  - Not adjustable: port pairs, vendor checks, area sets, and the Home and Agent co-pilot screens (`PROHIBITED.OCUPILOTSCREEN`).
  - `%Development:USE` or `%Admin_Secure:USE` admits the five Screen permissions surfaces. This is the product's only either-of check.
  - Writes record `OcuPilot/Security/SecurityChange`. An agent proposal that lowers a requirement gets the destructive treatment, with no typed name.
  - Screen context carries the screen's `verdict` and its `unavailable` tools. A privilege refusal names the screen.
  - The client never derives availability from the generated mirror.
- **Code writes go through the Atelier port.**
  - A save seeds If-None-Match with the version it read and never sends `ignoreConflict`; a conflict answers `EXPLORER.DOCUMENT.CONFLICT`.
  - A write requires WRITE on the target namespace's routines-database resource.
  - Compile console lines reach the screen and the proposal card only, never the model, the ledger or a log.
  - A create is a create-kind write: the fresh read must find the name absent.
- **Write-path patterns, reused unchanged.**
  - A screen action and the agent's write are one operation through one tool. The screen caller mints no proposal, emits no marker, and is not gated by the agent's switches.
  - Action-style writes declare their request type and an adequate fingerprint subject.
  - Every write reads its target back afterwards.
  - A write tool declares pairs beyond its screen's set only where the instance has been measured to need them, refusing by name before any port call.
  - `CLASSICPAGES` unions each replaced classic page's custom resource.
- **Measure, don't assume.** Settle a pair set by reading the classic page's own check and by running as a real least-privileged principal on a throwaway. Amend the spine at the spec gate rather than working around it.

## UX & Interaction Patterns

- **Rail.** Interoperability and Analytics follow System Explorer and are drawn only where the namespace reports the feature, so the rail shows nine to eleven items.
- **Side bar.** The Interoperability side bar starts with Productions, Business processes, Data transformations and Business rules. Screen permissions is listed under Agent co-pilot.
- **Gated controls are never hidden.** They stay focusable with `aria-disabled` and name the failed pair.
- **Long blocks.** A transcript block over eight lines starts collapsed; every further 80 characters of a long line counts as another line.
  - Show more / Show less is a native button carrying `aria-expanded` and `aria-controls`.
  - Focus moving into a collapsed block opens it, and an opened block stays open for the conversation.
  - A streaming reply never collapses.
  - A proposal card holding a long block shows a summary line naming what changes and how big, plus the compile outcome once it has run.
  - Confirming never requires expanding anything.
  - Strings live in EXPERIENCE.md's Fixed strings and in `strings.ts`.
- **Proposal cards follow the standard lifecycle.** Production cards carry recover-before-clean guidance. An agent's destructive card uses the destructive Confirm and no typed name.
- **Other embeds and viewers.**
  - The production configuration diagram renders in place; its sibling editors open in new tabs.
  - The HL7, X12 and ASTM schema browsers are read-only, with their document-selection parameter established against the instance.
  - A session trace renders visually, with a generated sequence diagram as the alternative.

## Cross-Story Dependencies

- **Orchestrator-set order.** 20.17, then 20.19, then 20.20, then 20.3 to 20.6. 20.14 follows 20.2; 20.18 follows 20.15.
- **The sign-in hand-off.** 20.13 gates every embed: 20.7, 20.8 and 20.10. 20.16 follows 20.7 and builds on 20.19's agent source edits.
- **The agent's code writes.**
  - 20.19 and 20.20 rely on 20.18's refusal to propose on a screen the user cannot open, and on 20.17's collapse.
  - 20.20 settles create access against 20.15's effective pairs.
  - Both build on Epic 19's Atelier port and System Explorer saves.
- **Interoperability screens.** 20.3, 20.4, 20.5, 20.6 and 20.9 build on the interoperability port and 20.2's production screens.
- **Analytics.** 20.11 needs a DeepSee-enabled namespace for anything beyond links.
- **Into Epic 21.** 20.12's diagnose-slow-query workflow is reused by Epic 21, which gives it its screens.
