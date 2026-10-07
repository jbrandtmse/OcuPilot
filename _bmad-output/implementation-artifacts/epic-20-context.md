# Epic 20 Context: Stage 4 - Interoperability, with the Analytics rider

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Give interoperability developers and operators their area inside OcuPilot, where the vendor's new UI covers it only partly. The Interoperability category appears only in namespaces that support it. It covers productions, items, per-host tabs, queues and jobs, lookup tables, tests, messages, and the vendor's rule, BPL and DTL editors and schema viewers embedded in place. An Analytics rider adds cube listing, the model browser, the MDX tool and the cube manager, and the agent gains guided workflows and Investigate runs. Every feature keeps the post-Release-1 contract: one descriptor per screen, one port per backing system, and every write a confirmed proposal made as the signed-in user. Embedding never weakens the origin and never puts a password or a token within a frame's reach.

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

## Requirements & Constraints

- **Two decisions are held for the owner.** Neither is decided or built by a story before the owner answers.
  - **(1) The hand-off design (DW-2141).** Story 20.13 carries it and gates every embed.
    - *Measured at 20.1's plan.* No in-place design keeps AD-28 and AD-47 as written. An unsandboxed same-origin frame signs in silently but can read the tab's token pair. A `noopener` tab keeps both ADs but leaves the shell. A sandboxed frame never signs in.
    - *The silent sign-in.* In normal mode an editor uses the `CSPBrowserId` cookie (`path=/`, SameSite Strict) and an empty-body `POST /api/interop-editors/login`, then keeps its tokens in `sessionStorage` (`Rule_Editor-0-*`).
    - *Why VSCODE mode does not help.* 20.7 needs the `saved`, `compiled`, `bad*` and `compatible` messages, which the editors post only under `?VSCODE=1`. That mode waits for `postMessage({type:"auth", username, password})`, which is forbidden and has no origin check.
    - The measurements and candidates are in 20.1's blocked spec at commit `9faa902f`. 20.13 is planned only once the owner decides.
  - **(2) The API floor (DW-2140).** The floor is `Screen/Gate.cls`'s `ADMINRESOURCES` plus `%Development`, and it refuses a caller before any route runs.
    - *Measured.* No `%EnsRole_*` role holds an `ADMINRESOURCES` member. So `%EnsRole_Operator`, `_Administrator` and `_Monitor` are refused, and `%EnsRole_Developer` enters through `%Development`. `%DeepSee_Portal` is public `U`, so it cannot be the floor.
    - *Meanwhile.* 20.2 to 20.6 proceed under the current floor. Every new Interoperability or Analytics surface declares its classic page's gate (for example `%Ens_Portal:USE`) as a screen-own pair from the start, so a later widening touches only pre-existing surfaces. No story widens the floor.
- **Other gating unknowns.** Each must be settled before the stories it gates are built.
  - **20.2 introduces the first Stage 4 port, and no AD names it yet.** FR-80 allows exactly one port per backing system, and AD-29 requires each to carry a named gate, so 20.2 needs one new AD. The next free id is AD-62; the runner claims it, never a stage. The Capability map's Stage 4 row reads "AD-5, AD-44 (`appliesWhen`), staged". AD-36 would need a new source kind, as `docdb` and `sqlactivity` did (inference).
  - **The production-update vocabulary has never been read**, nor what `/productions/production/state/{class}` means. Story 20.2 establishes both on the instance first. The v7 OpenAPI spec is readable only from `irissys/%Api/InteropEditors/v7/spec.cls`, because the live `/api/mgmnt/v2` route refuses it (#8753).
  - **The Analytics rider needs a DeepSee-enabled namespace** for everything except its three links. Measured on `ocupilot-b-ci`: HSLIB and HSSYS report analytics; HSCUSTOM and USER report interoperability only; `%SYS` reports neither.
  - **Four rows ship read-only first**, because their actions need custom endpoints: queue actions (`Ens.Queue`), job actions (`Ens.Job`), business-partner save and remove (`Ens.Config.BusinessPartner`), and the message-contents renderer (`Ens.Util.MessageBodyMethods`, or the embed). Such a read is a stated partial, not a completed row.
  - **Also unproven.** The schema viewer's document parameter (20.8), VSCODE-mode messages (20.7, never exercised live), and the interop editor's `HOST=` and `NEW=1` (inferred from selector names).
- **The contract every screen keeps (FR-80).** Acceptance is this contract plus each row's own backing route.
  - One descriptor per screen, and exactly one port to the outside.
  - The read tool comes from the descriptor, and write field lists are derived, never hand-typed.
  - Every write is a server-minted proposal with an instance-computed diff, an explicit confirmation and an agent marker.
  - Every read is bounded and reports truncation, and every gate checks the caller's own privileges at call time.
- **Scope.** 41 catalog rows: SH-23, SH-25, CP-37, CP-38, IO-02 to IO-29 and AN-02 to AN-10. They are backed by the interop-editors v7 API, the DeepSee API, and vendor bundles loaded in place from `/ui/interop/<app>/index.html`. The bundles are never copied, and they carry no license text.
- **Category gating shipped in 20.1 (AD-44).** A rail area may declare `appliesWhen` from a closed vocabulary: `interoperability` or `analytics`. The server answers `applies` on every area of every navigation read, for the route's namespace. A non-applying area is drawn nowhere but stays on the wire with its verdict, and a vendor check that throws, or an unknown feature, answers false. Applicability is not a privilege gate: an area that applies and that the caller cannot open is drawn unavailable, naming its pair (AD-8). DW-1921 closed with it: the event log declares `%Ens_EventLog:USE` and `%Ens_Portal:USE` as its own pairs.
- **Governance (AD-22).** Each new write key joins `Kernel/Governance/Baseline.cls` in the same change, and every new destructive key ships disabled.
- **Budgets.** The bundle warns at 3012kB, with a hard error at 4000kB (`ui/angular.json`). Fixed strings are bounded at 2,800 literals (`ui/tools/strings.test.mjs:588`), and each move of the bound carries a comment.

## Technical Decisions

- **Every call goes through OcuPilot's own API, in process.** Tools run in process (AD-1), and a screen and its tool share one declared read through a port (AD-36). So neither the browser nor a tool calls `/api/interop-editors` or `/api/deepsee`. Every JWT application accepts the tab's token, but only AD-57's try-it console uses that reach, and it is not the write path.
- **One class confines the vendor's classes.** As in AD-2, AD-27 and AD-61, a port names the vendor's `%Api.*` classes and reproduces their dispatch in process. It supplies stub CSP state, runs its gate first, and reads the outcome from both the status and `%response.Status`. A Stage 4 port would follow it (inference). A custom half enters only as a named AD-27 case.
- **Privileges (AD-8, AD-29, AD-44).**
  - Establish a pair set two ways: read the backing class's own check, then run the read as a least-privileged principal on the throwaway.
  - The Interoperability area declares `%Ens_Portal:USE`, the classic menu's `CheckSecurity`. The classic `CheckPrivileges` also needs READ on the namespace's database, which depends on the namespace, so each 20.2+ screen and port resolves it at call time, as System Explorer does.
  - The Analytics area declares `%DeepSee_Portal:USE`, which is public `U` on a stock instance, so the area opens for every caller past the floor. Each 20.11 screen declares its classic page's own resource as an own pair (DW-1853).
  - A descriptor names the classic page it replaces, and its pairs union that page's custom resource. `AreaCoverageProblem` holds an area's set to its screens' pairs, less their own pairs. A tool lists any other pages it performs in `CLASSICPAGES`.
- **What 20.2 to 20.12 consume from 20.1.**
  - `Kernel/Shell/NamespaceFeatures`: `FEATURES` (the closed vocabulary), `Reports(feature, ns)` and `Applies(feature, ns)`, over `%Library.EnsembleMgr.IsEnsembleNamespace` and `%DeepSee.Utils.%IsDeepSeeEnabled`. They take the namespace as an argument, switch no namespace and escalate nothing (AD-9, AD-16). Analytics is never `%SYS` or an implied namespace.
  - `Screen/Area.cls`: `interoperability` at rail position 9 and `analytics` at 10, with Agent co-pilot at 11. A new screen joins its area and inherits its applicability on route and on namespace switch.
  - The client's `NavigationService` fails closed on applicability (until the current namespace's map answers true) and open on verdicts. Its `areas()`, `screensForArea()` and `builtScreens()` return only what applies, and it re-reads the map on a `namespace` change event (AD-14). No component computes applicability.
- **Write kinds.** Each write tool declares its port (AD-52).
  - Merge (AD-4): item settings. Whether a v7 `PUT` keeps keys its body omits is unmeasured.
  - Action-style (AD-51): control actions, enable and disable. No body, and a declared fingerprint subject covering every field the precondition reads, such as production state.
  - Create (AD-54): an added item or a new lookup table, fingerprinted on the target's absence.
- **Rules that apply to every write.**
  - A screen action and the agent's write are one operation with two callers (AD-53, AD-55).
  - The write reads its target back (AD-58), using `READBACKFIELDS` where the port has no derived field list.
  - A port that defines `Invoke` needs a `Snippet` for each of its branches (AD-59).
  - Where IRIS records no audit event for a write, that is a new named gap in AD-15 and AD-53.
  - Where v7 write field lists are derived from is undecided (inference).
- **Long writes.** A confirm runs its write in the foreground request (AD-7), so a production start or stop that outlasts the Web Gateway's timeout has no spine path yet (inference).
- **Identity.** New entity types join the kernel's closed enum (AD-14), each with a canonical-spelling rule (AD-13). A production item is a composite id in one path segment. The scope is the route's namespace, which travels into proposals and change events (AD-44).
- **Content safety.**
  - Event text and message content are untrusted (AD-11) and pass the sanitizer (AD-60).
  - Message bodies have no schema and can hold patient data, so by precedent they stay screen-only (AD-48, AD-36's journal values; inference).
  - Lookup-table import and export carry content, never a server path (AD-21; inference).
  - MDX text is the caller's own query, but AD-21 has no MDX clause yet (inference).
- **Embedding (pending DW-2141).**
  - The shell's `default-src 'self'` admits a same-origin frame (AD-47), and `/ui/interop` sends no frame-blocking headers.
  - The rule editor loads at exactly `/ui/interop/rule-editor/index.html?$NAMESPACE=<ns>&rule=<class>`.
  - The other addresses are BPL `BP=`, DTL `DTL=`, `/ui/interop/interop-editor` with `$PRODUCTION`, and `/ui/interop/schema-viewer`.
  - Sign-out ends the browser-level login, which signs the editors out too (AD-28).
- **Workflows and Investigate.** The turn job never mutates (AD-7), so Investigate is read-only. Confirming a proposal cancels its siblings on the same target (AD-34), and a proposal dies with its turn (AD-40). So a workflow mints each write only after the previous one is confirmed, within one turn's limits (AD-31, AD-41; inference).
- **Code to harvest from the MCP suite.** Take handler bodies only, and rename every `ExecuteMCPv2` name.
  - `REST/Interop.cls` and `REST/Analytics.cls`.
  - `REST/MessageResend.cls`, the double-gate reference. `dryRun` defaults to true, and executing needs `confirm`. A larger match is refused rather than truncated, at 100 ids or 500 messages, within a 7-day window.
  - `Diagram/*`, for 20.9's sequence diagram.
- **Existing code to reuse.**
  - Home reads production status through `Ens.Director.GetProductionStatus`.
  - The catalog backs SH-25 with Atelier's namespace features, but `AtelierPort`'s gate adds `%Development:USE` (inference: it would refuse operators).

## UX & Interaction Patterns

- **Navigation.** The rail reads Home · Logs · OS management · Tasks · Permissions · Web applications and REST API explorer · Security and secrets · System Explorer · Interoperability · Analytics, with Agent co-pilot pinned at the bottom. Home shows one tile per applying area (seven to nine). The side bar lists only built screens, and a namespace switch re-fetches rather than re-routes; an open side bar whose area stops applying closes. Per-host tabs are one descriptor per tab, grouped by `tab` and parent-scoped (AD-5).
- **Confirmations.** Destructive writes take the typed-name confirmation, a non-delete write states its warning first, and dialogs never stack. Proposal cards carry the recover-before-clean line, show a resend's dry run, and name the required privileges (AD-8).
- **Strings and prompts.** Each new literal goes into EXPERIENCE.md's Fixed strings and `strings.ts`; the two area names are already there. Each built screen declares at least three suggested prompts. After editing EXPERIENCE.md or epics.md, run `cd ui && npm run test:tools`.
- **Investigate** starts from alerts and log entries, beside the unified log hub (16.9). It reuses Explain this entry's marker (AD-24) and cites rows through citation chips (AD-11).

## Cross-Story Dependencies

- **Within this epic.**
  - 20.1 built no screen in either category, so 20.2's browser spec pins the command box and locator legs. 20.2 also carries DW-2148: EXPERIENCE.md's rail row (:612, "nine rail-items") and area-tile row (:653, "Seven tiles") understate a namespace that reports either feature.
  - 20.13 runs before 20.7 and gates the embeds of 20.7, 20.8 and 20.10, and 20.9's contents viewer if it embeds. The runner stops before 20.7 unless the owner's hand-off answer has arrived.
  - 20.2's first task is the vocabulary.
  - 20.10 needs 20.7's editors.
  - 20.11's Analytics screens sit under the area's pair set and `AreaCoverageProblem`.
  - 20.12's navigation into these categories reads `shell.privileges.read`'s `applies`, and its recover-stuck-production and resend-failed-messages workflows need 20.2 and 20.9.
- **Prerequisites.** Epic 20 depends on Epics 11 and 12, both merged. Sprint planning passed with CONCERNS, naming the hand-off, the port, the vocabulary, the DeepSee namespace and the read-only rows.
- **Parallel run.** By the owner's decision of 2026-10-06, Epic 20 runs whole on slot B while slot A runs the rest of Epic 18 (18.8, 18.25 to 18.27, 18.9 to 18.13, burn-down 18.28), then Story 23.5.
  - 18.12 overlaps 20.12 (the tool registry), and 18.13 overlaps 20.1's `navigation.ts` (per-namespace state). Whichever merges second rebases.
  - 20.1's contended edits were cleared by the orchestrator: EXPERIENCE.md :66 and :310, `Test/Descriptor.cls`, `Test/Wire.cls`, `Test/WireAreaAnyScreen.cls`, `navigation.test.mjs`, `screen-mirror.test.mjs`, and `screens.generated.ts`. The second epic to merge takes the union and regenerates `screens.generated.ts` whole.
  - Keep other shared-file edits add-only (`Baseline.cls`, `strings.ts`, EXPERIENCE.md, `SurfaceCoverage`, `angular.json`).
- **Slot B.** Use profile `ocupilot-slot-b`, throwaway `ocupilot-b-ci` (52777/1976) and `OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci`. Run one test class per call, and never restart an `ocupilot-slot-*` container.
