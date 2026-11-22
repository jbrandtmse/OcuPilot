# Epic 24 Context: Stage 5, second lane - interoperability, analytics, developer tools and the agent's harvested tools

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Bring the rest of Stage 5's custom-REST parity onto a second slot, running beside Epic 21. That means the remaining interoperability surfaces, the analytics editors the Epic 20 rider left out, a developer-tools set (unit-test runner, consoles, web terminal, environment diff and promote), and, for the agent, the 28 harvested inspection tools plus undo by snapshot and revert. Every classic leaf that has a backing class but no route becomes reachable, built the same way as every earlier screen, so OcuPilot moves toward classic-portal parity without a second way of building anything.

## Stories

- Story 24.1: Developer tools (LOC metrics and drift hashes)
- Story 24.2: The analytics editors (term-list editor)
- Story 24.3: Interoperability parity (auto-start and shutdown groups, plus routed cleanup)
- Story 24.4: The agent gains the harvested tools and undo (session and message reads)
- Story 24.5: Unit-test runner and work-queue viewer
- Story 24.6: The command and class-method consoles
- Story 24.7: Web terminal
- Story 24.8: Remote instance profiles and environment diff
- Story 24.9: Environment promote
- Story 24.10: Folder manager transfer and term-list import, export and copy
- Story 24.11: Listing groups
- Story 24.12: Quality measures
- Story 24.13: Analytics settings
- Story 24.14: PMML model tester and dashboard viewer
- Story 24.15: Credentials, default settings and schedules
- Story 24.16: Purge, suspended messages, export and the archive manager
- Story 24.17: Managed alerts, logs, the system monitor and workflow
- Story 24.18: PEX, record maps and HL7 authoring
- Story 24.19: The registries, interface maps and references, port authority and deployment
- Story 24.20: Undo by snapshot and revert
- Story 24.21: The agent's harvested log, process, source and configuration tools
- Story 24.22: The agent's harvested message body searches
- Story 24.23: The agent's harvested vocabulary tool

## Requirements & Constraints

- **One contract for every stage.** Each new screen has exactly one screen descriptor and reaches the outside through exactly one port. Its read tool and its write tools' field lists derive from that descriptor, never from hand-written tool code. Every agent write goes through a server-minted proposal, an instance-computed diff, an explicit confirmation and an agent marker. A story is accepted on that contract plus a round trip over each row's own backing class. Nothing finer is invented in advance.
- **Governance.** Every new write key joins the governance baseline in the change that ships it. It is enabled unless the story's criteria say otherwise, and every new destructive key ships disabled. A key missing from the baseline defaults to disabled when it mutates, and a test names any write key the baseline lacks.
- **Harvest discipline.** Take handler bodies only. The MCP suite's manifest is stale and its bootstrap is driven by TypeScript, so nothing else is taken. Read the current body before harvesting it, because known defects (the task-history filter, resource creation with a description) have unverified fix status. Rename every harvested name: packages, globals, audit sources, web paths and the `iris_` tool prefix, which becomes `<area>.<screen>.<verb>`.
- **Single instance.** No request leaves the instance. Environment diff and promote work only between namespaces of this instance. Remote instance profiles and the work-queue viewer are recorded as not planned in the test-held exclusion register (`docs/exclusion-register.md`), each with its reason; the unit-test runner's own run record replaces the work-queue viewer. A feature the architecture does not allow, or that no IRIS class backs, goes to the register's "not planned" group.
- **Developer tools.**
  - The execute-command console's output is bounded by the harvested output ceiling.
  - Promote keeps four gates: plan, execute-with-confirm, a steps allow-list, and plan-hash freshness. It states that it has no rollback rather than implying one.
  - Deployment writes its log and rollback files, and its history offers rollback and delete.
- **Agent tools.** Every harvested tool declares `read` or `write` at definition time and passes the single call-time gate. Undo captures a snapshot before the write and offers a one-click revert. The revert is itself a confirmed proposal with its own diff and audit marker, and its state-capture model is designed here rather than retrofitted.
- A stage may add to the prohibited set, but only where that set is declared, never in a policy file.

## Technical Decisions

- **Harvest seam (Story 21.1, on the feature branch).** Harvested handlers inherit an OcuPilot base class whose `RenderResponseBody(pStatus, pMsgPart, pResPart)` emits OcuPilot's single error/response envelope. Only the base class changes; the body is never edited to reshape the response, and the no-double-envelope assertion must still pass.
- **In-process, as the user.** Tools call IRIS classes directly in the caller's process, with no HTTP hop and no elevation. Privilege is checked at call time and never cached. Each port evaluates its declared resource pairs before any vendor call, because many vendor classes check nothing. Pairs are established by reading the vendor's own check and then running the read as a least-privileged principal on a throwaway.
- **InteropPort** is the only path to production writes and interoperability configuration reads:
  - It never calls `%Api.InteropEditors`.
  - The namespace must report interoperability, and it is switched by explicit save and restore, with no `OcuPilot.*` call while switched.
  - An item is identified by `[Production, Name]`. A namespace under source control refuses item writes, and a secret-named setting is refused.
  - Action-style writes refuse the vendor's silent no-ops by name before any vendor call.
  - A vendor `/ui/interop` editor is embedded only in a same-origin, unsandboxed frame in normal mode (never `?VSCODE=1`), with a source built from a closed vocabulary; OcuPilot posts nothing into it and reads nothing from it.
- **AnalyticsPort** calls `%DeepSee` classes in process, never `/api/deepsee`:
  - Checks run in order: pairs, namespace shape, analytics enabled, then READ on the namespace's databases. The vendor's own cube and folder checks still apply.
  - Only reads measured to write nothing are called. `%GetMemberTree`, `%GetDimensionMembers` and `%GetFavoritesForUser` are never called.
  - MDX that runs code is detected by the shared detector, which fails closed.
  - Analytics ids, such as a term-list name, a folder-item full name or a run-time variable or icon name, are kept exactly; a name that differs only in case is another name.
- **Background runs (PMML test).** A person's read-kind background run supervises a child job that runs the vendor model; on cancel (only the owner's stop flag counts), bound or end, the supervisor ends the child, drops the test id's IRISTEMP rows with a bound `DELETE`, and writes the final state. Only a job's direct parent ends it without escalation. Export to cube runs its test in the confirm or action request (never a background run), copies rows through the object layer, composes no SQL, never builds the cube, refuses a held class or a name whose compiled storage already holds data (`ANALYTICS.PMML.DATAHELD`), and deletes every class it saved when a later step fails.
- **Class-backed definitions** (listing groups, quality measures, export-to-cube classes) are written by saving and compiling their class. A compile the instance refuses puts the class back as it was. Class names are refused in the `%` and `OcuPilot` packages, and two classes defining one item are refused.
- **AtelierPort** is the only class naming `%Api.Atelier.*`. Its writes (save, compile, delete, import) also require WRITE on the target namespace's routines-database resource, resolved at call time, because the API checks none itself. A port answer above the capture ceiling (about 3.6 million characters) is refused `PORT.UNAVAILABLE`; only the Globals export has its own `GLOBAL.TOOLARGE`.
- **Write and fresh-read types are distinct.** A read and a write cannot share a request type, so a port-composed fresh read gets its own type name beside the write's.
- **Read-back.** After a write reads OK, its caller re-reads the target through the tool's declared port with the caller's own privileges and reports `readBack {verdict, fields, written, reason?}` without altering the write's answer. A tool with no derived field list may declare `READBACKFIELDS`. A tool that sends no body may also declare `READBACKPAYLOAD`, so it reads `matches` or `differs` rather than `nothingSent`.
- **Run-code exception (unit-test runner, consoles, terminal):**
  - The tool belongs to a person alone: it declares `PERSONGATE`, is unadvertised, and is refused `PROHIBITED.PERSONONLY` if the agent reaches it.
  - Its governance key ships `false` and is asked by the screen action route.
  - Every run is confirmed, and the confirmation names the consequence. A command naming OcuPilot, or a class in an `OcuPilot` package, is refused by the port.
  - Console output, return values and error text reach the screen only, never the model, ledger, audit payload, log or screen context.
  - A console run records OcuPilot's own `SecurityChange` row, which names the console and namespace but never the command, arguments or answer.
- **One operation, two callers.** A screen action and an agent write share target resolution through the declared port, the fresh read, prohibited-set evaluation under the per-target lock, the change event and the read-back. A screen action mints no proposal, emits no marker, and is not gated by read-only or the kill switch.
- **Copy-out scripts.** A draft is rendered on the instance from the stored proposal through the branches of the tool's declared port, runs no write, shape-checks every name it renders, and renders nothing when one fails.
- **Reads.** A screen and its tool share one bounded, descriptor-declared read that reports truncation. A parent-scoped declared read (an analytics, interoperability or locale source) takes its parent's route id as `read.criteria`. Every tool result passes the one sanitizer. An agent read tool never executes code.
- **Guided workflows** are declared catalog entries, never code paths; a workflow write must be a named step, one proposal per turn. The harvested promote workflow has no steps until Story 24.9's promote tool exists.
- **Files.** No endpoint accepts a filesystem path. A file is named by a fixed enum or a single validated segment and resolved under a directory computed on the instance.
- **Audit.** Many interoperability and analytics writes have no vendor audit event. Measure each write with auditing on. Where the vendor records nothing, record OcuPilot's own `ConfigChange` or `SecurityChange`, or name the gap. A cube build or synchronize records OcuPilot's own `ConfigChange` from either caller (with `failed` true, naming only cubes the vendor's statistics report updated, when the vendor's run then failed; none when no cube was updated).
- A `%Persistent` class name is 29 characters or fewer. When an architecture decision must change, amend it in the spine rather than working around it.

## UX & Interaction Patterns

- Every screen registers the standard screen contract: route with `?ns=`, side-bar entry, archetype, privilege resource, entity-type key, context serializer, actions (destructive last), empty-state sentence, fixed strings and aliases.
- A sub-screen or tab opened from an item's name or a screen's later tab (a listing group's listings, a quality measure's groups and documentation, the analytics settings' worklists, run-time variables and icons, a folder item's Definition and Widgets tabs, a PMML model's Test screen) is never in the side bar and carries its own actions and empty-state agent phrase.
- On write-capable lists the "Or ask the agent: …" line takes a short phrase, never a full sentence. A screen with no action names no agent phrase.
- An action's label is also its dialog's title. On a change the name is fixed, and a rename is a remove and an add, never an in-place move.
- A secret is never shown: a stored secret value reads as the mask, and it is set only by its own action, which asks for the value when that action is confirmed. Stored expressions and paths are shown as text and never run or loaded. An expression may be checked for syntax before it is saved, never run; where a stored expression runs later as code, its add or change carries a consequence saying whose rights it runs with.
- A setting that is not stored shows the classic page's default value. Where the classic page saves a whole form at once, saving stores every setting with the value shown, as the classic Save does, and the card, dialog and answer say so.
- Gated controls stay focusable with `aria-disabled` and name their reason; they are never hidden.
- A screen's destructive action or removal uses the confirm dialog with a typed name. An agent's destructive proposal uses the destructive card. Confirmations always name the target, and a delete or removal that OcuPilot cannot reverse says so in its consequence.
- Refusals are the server's sentences, shown as sent. Vendor text is logged, never shown.
- Result and status lines are announced to assistive technology (`role=status`).
- Each story's fixed strings are in the experience spine's string table, and the story must use them; reuse the words other screens already publish (Edit, Copy, Delete, New name, New class, Class, Caption, Description, Disabled, Name, Setting, Value, Expression, Comment, Context, Path, Page, Set value, Show, Hide).

## Cross-Story Dependencies

- Every story harvests through Story 21.1's seam. The interoperability stories (24.3, 24.15 to 24.19) extend Epic 20's InteropPort. The analytics stories (24.2, 24.10 to 24.14) extend its AnalyticsPort.
- Story 24.5 establishes the run-code exception and `PERSONGATE`. Stories 24.6 and 24.7 build under it, and they rely on Story 21.30's guarded stores to protect OcuPilot's administrative state.
- Story 24.8's environment diff compares the per-namespace default settings that Story 24.15 reads (DW-2636). Story 24.9's promote is the tool the harvested promote guided workflow is waiting for.
- Story 24.10 extends the term-list editor from Story 24.2. Story 24.12's quality measures reuse the listing groups' (24.11) class-save pattern and refusal sentences.
- The 28 harvested tools are split across Stories 24.4 (14), 24.21 (10), 24.22 (3) and 24.23 (1). Story 24.20's undo applies to the write path as a whole.
- Stories 24.5, 24.8 and 24.14 add rows to Epic 22's exclusion register, and its test holds the register equal to the catalog. Epic 21's Story 21.38 (DW-2474) waits until Story 24.14 is on the feature branch.
