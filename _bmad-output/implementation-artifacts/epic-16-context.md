# Epic 16 Context: The remaining polish-week extras

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

This is the voting-week work. It finishes the second-tier screens and actions of the six areas (FR-74, FR-76 to FR-78), the six stories deferred from the contest build (16.11 to 16.16) and the contest-survey additions (16.17 to 16.24).

- **Done:** 16.1, 16.2, 16.3, 16.5, 16.8, 16.9, and 16.16 to 16.24.
- **Next on slot A:** implement 16.6 (ready for dev), plan 16.7, then 16.10 to 16.12.
- **Waiting:** 16.4, on Epic 18's PathPort follow-up.
- **Backlog:** 16.13 to 16.15.

**Nothing here may break a Release 1 screen or a Release 1 agent write.** Anything that risks either waits for Stage 2.

## Stories

- Story 16.1: The try-it request console
- Story 16.2: Web sessions, listed and ended
- Story 16.3: Effective privileges and the permission-check tool
- Story 16.4: Task export and import
- Story 16.5: Background tasks
- Story 16.6: Broadcast a message to processes
- Story 16.7: License usage and the full dashboard
- Story 16.8: The six secondary log viewers
- Story 16.9: The unified log hub
- Story 16.10: External language servers
- Story 16.11: Start, suspend and resume the Task Manager
- Story 16.12: Remove locks - one, all of a process, all of a remote client
- Story 16.13: The service editor
- Story 16.14: The LDAP and Kerberos editor
- Story 16.15: The data-egress line
- Story 16.16: The agent audit viewer
- Story 16.17: The read-back line
- Story 16.18: Home's performance row
- Story 16.19: Impact lines on removals
- Story 16.20: Older messages.log files
- Story 16.21: Security findings, with a fix you confirm
- Story 16.22: The Guardrails page
- Story 16.23: Any table, downloaded as CSV
- Story 16.24: A try-it request, copied as curl

## Requirements & Constraints

- **Every story.**
  - A screen is one descriptor with its derived read tool. An action ships with its confirmed write tool.
  - The action's governance key joins `Kernel/Governance/Baseline.cls` in the same change. It is enabled unless the criteria say disabled.
  - A write tool's port gives a `Snippet` branch for every `Invoke` branch.
  - A field the instance normalizes on save declares a read-back `compare`.
  - A new prohibited arm needs reason text, because the Guardrails page is generated from the prohibited set. Tests fail on each of these gaps.
- **Copy.** New strings go into EXPERIENCE.md's Fixed strings and `strings.ts` in the same change. EXPERIENCE.md is edited in place and stays at 993 lines, so no line citation shifts. Publish a refusal sentence once, and pin the kernel's reason equal to it.
- **Bundle.** 16.5 deployed at about 2.06 MB against a 2107kB `maximumWarning`.
  - A story that crosses the warning re-bases it to 5% above the measured total. It updates the `angular-json.test.mjs` literal in the same change (DW-1166).
  - Stop and ask above 3800kB. The hard stop is 4000kB.
- **Side-bar pins.** A screen-adding story extends every browser spec that pins its area's side-bar list (`grep -l ocu-side-bar-label ui/browser`). 16.5 missed this and CI failed (DW-1774).
- **16.6.** The broadcast reaches the selected processes, and the confirmation names how many will receive it. It is the one screen needing multi-select, so the data table's selection model is extended here rather than assumed.
- **16.7.**
  - **License usage.** Show the summary plus the by-process, by-user and distributed views.
  - **Dashboard.** Draw every meter group: performance, ECP and shadowing, status, usage, errors and alerts, licensing, and task manager. The CPU meter belongs here.
  - **Meter names and values.** They come from the instance's own monitor answers, as System usage takes them from `Monitor` through `AdminPort`. The classic `EnsembleMonitor` page is the Interoperability monitor and defines neither the meters nor their thresholds.
  - **Alerts (DW-1116).** Every vendor `Alerts()` call advances an instance-wide SAM cursor that other scrapers share, whatever the tag. So the monitoring half was never shipped, and alerts.log is read through `LogSourcePort` alone. The errors-and-alerts group re-opens that decision, so make it explicitly. The earlier implementation is recoverable at `33361dc` on `OCU-1-epic6`.
- **16.10.** The list shows each server's status, and start and stop update the row in place. The activity log opens in the shared log viewer. Create, edit and delete round-trip through the admin API, and delete confirms by name. **DW-253:** the template is evaluated at its default type, so derive one field list per language-server type, as `Wallet.Secret` does, and amend AD-3.
- **16.11.** `Task.Manager` publishes no body template, so the tool is action-style, never a hand-typed field list. Suspending first warns that no scheduled task will run until it is resumed. The suspended banner sits above the table with a privilege-gated Resume, and the rows still list; its copy for the suspended and stopped states is already published. **DW-1638:** task delete, suspend, resume and run must judge `TaskRules.Permitted` in `ArgumentProblem`, as the task edit does.
- **16.12.** `Lock` publishes no body template, so the tool is action-style. It offers three scopes, each naming what it removes. **DW-1073:** warn from the endpoint's own 409 "is currently in a transaction", never from a `$zu` probe. **DW-1074:** suppress the Process details link on a row with a remote owner.
- **16.4 (waiting).** The acceptance is the export-import round trip, not either half alone. The file field takes a root and a relative name through `Port/PathPort` (AD-21's sixth case), with `%Admin_FileSystemAccess:USE` and `%DB_IRISSYS:READ`, and resolves again at the write. An import reads an existing file as a `source`. DW-1798 (an overwriting consumer reaching OcuPilot's own bundle) is decision-pending.
- **16.13 to 16.15 (backlog).** The service editor draws disabling `%Service_WebGateway` disabled (refused for both callers) and mints an address or authentication change destructive (DW-1016: an empty diff cell needs a word). The LDAP editor keeps list, get and put synchronous, and its test connection goes through `AdminPort`'s async path (DW-1639: the Enabled column reads wrong). The egress line derives from the configuration the request actually uses.

## Technical Decisions

- **16.6's spine amendments.**
  - **Multi-select (AD-5).** A list may declare one `multiSelect {action, eligible, max, ineligibleKey}`. The shared table keeps a checked set in the screen's store beside the unchanged single selection (AD-19). The action acts on that set from the command bar and command box, never from the row menu. `Screen/Registry.cls` and `screen-mirror.mjs` validate it alike, and a list that declares nothing behaves exactly as before.
  - **Pid sets (AD-13).** A `process` id may name a set of pids. Its rule canonicalizes the set to unique plain-decimal pids in ascending order, and a single pid reads as before.
  - **Body (AD-51).** `ProcessPort` builds `Process` `BROADCAST`'s body `{Message, PidList}` from the tool's declared `Message` and the target's canonical pid set.
  - **Prohibited set (AD-10).** The process-termination arm is not evaluated for a broadcast. The port refuses an ineligible recipient on both callers; the vendor's `CanReceiveBroadcast` reads 0 for system processes and for OcuPilot's own.
  - **No vendor audit (AD-15, AD-53).** IRIS records no event for a broadcast. The agent's marker is its only record, and the screen action leaves no audit row.
- **Reads (AD-5, AD-36).** A descriptor is hand-written with at least three suggested prompts. A list declares `table` and may declare one cross-screen row target. Screen and tool share one bounded read that reports truncation, optionally with a per-row `rowGet`. Its source is a port endpoint, a kernel store's guarded list, or a composition.
- **Privilege (AD-8, AD-29).**
  - Pair sets are checked at call time, with no elevation. An administrative resource is required at `USE`, never `WRITE`.
  - Establish a set by reading the backing class's own check in `irislib/`, then running a least-privileged principal on the throwaway. Never use `%Operator` to prove a denial.
  - Pairs beyond the area's set go in the screen's `ownPrivileges`, each a named AD-8 case.
  - A write tool may add pairs only where its vendor writes a database the screen's read does not, or where an endpoint its call must reach names the pair. The mint refuses a caller who lacks one by name, before any port call.
  - `MonitorPort` alone names the dashboard sensors, read in-process under `%Admin_Operate:USE` and `%DB_IRISSYS:READ`.
- **Classic pages (AD-44).** A descriptor names the classic page class it replaces. A write tool that performs another classic page's operation names it in `CLASSICPAGES`, and its pairs union that page's custom resource. Only a detail view may carry a classic-link exemption.
- **Writes.**
  - **Two callers.** A screen action and the agent's write are one operation. The screen caller mints no proposal, emits no marker, and ignores read-only and the kill switch (AD-53, AD-55).
  - **Declared shape.** Each tool declares its port, `AdminPort` by default (AD-52). An action-style write declares its request type, sends no body, and fingerprints a declared subject holding every precondition field (AD-51). A create fingerprints the target's absence (AD-54). A screen action accepts only declared values, and list fields change by a server-side delta (AD-56).
  - **Prohibited set.** It lives once in the kernel, is defined by effect, and is evaluated inside the confirm transition for both callers (AD-10, AD-34).
  - **Vendor class.** Where the admin API cannot carry a call, a port may use the vendor's `%SYS` class after repeating its guard. Each use is a named AD-27 case; the latest is `BackgroundTaskPort`.
  - **Queued writes.** `AdminPort`'s async path is the only poller. A write that would queue is refused unless it is on `QUEUEDWRITES` (AD-26).
  - **Unaudited writes.** Measure each new write with auditing on. Where IRIS records nothing, name it as a further case in AD-15 and AD-53.
  - **Gates.** Governance is checked at dispatch and again at Confirm (AD-22). Every write reads its target back (AD-58) and renders a copy-out script (AD-59).
- **Files and logs (AD-21, AD-60).** No endpoint accepts a path. A log is a fixed-enum `LogSourcePort` source, and log text reaches the model only through the sanitizer.
- **Identity and refresh (AD-11, AD-13, AD-14, AD-43).** Ids are encoded twice and decoded once. Each write story adds its entity type's canonical-spelling rule, from the kernel's closed enum. A screen joins auto-refresh only by declaring it and appearing in EXPERIENCE.md's roster. Nothing rendered from a reply or tool result requests any host.
- **Conventions.** The client is zoneless and `OnPush`; framework-free `core/` stores are mirrored into signals and reset at sign-out; API URLs are absolute. The envelope is `{error, reason, code, detail}`, and tools are named `<area>.<screen>.<verb>`. A test depends on no other test, no order and no instance uptime, because CI shards regroup.

## UX & Interaction Patterns

- **Placement.** A screen appears in the side bar only once it is built.
  - **OS management:** License usage and Dashboard as meters, and External language servers as a list followed by a form-page editor.
  - **Dialogs from lists:** Broadcast from the Processes multi-select, and Remove locks from the Locks row menu.
  - **Task schedule command bar:** Suspend Task Manager, with Export and Import as dialogs.
- **Meters.** Each shows label, value and unit, with its state (Normal, Warning or Troubled) as a word and a color. It shows "—" with a skeleton until the first value, and puts an error in its tooltip. The needle never animates.
- **Dialogs.** One level deep, never stacked, titled with the action and the target. A screen's destructive dialog asks for the typed name; an agent proposal does not. A non-destructive warning, such as Suspend Task Manager, uses a primary button and states the consequence.
- **Controls.** A gated control uses `aria-disabled` and reads "Requires <resource>". An instance-only refusal stays offered, and the instance answers the click with the published sentence.
- **Rows.** Color never carries meaning alone. Row actions update the row in place with "Changed", and every data table offers Download CSV.

## Cross-Story Dependencies

- **Keep intact.** Earlier Epic 16 work: try-it and Copy as curl, Web sessions' refusals, `Kernel.Shell.Effective` and the own-pair screens, the log viewers and hub, the ledger viewer, Background tasks and `BackgroundTaskPort`, and 16.17 to 16.23. Epic 14's baseline, sanitizer and per-user read-only bind new work.
- **Within the epic.**
  - 16.6's multi-select changes the shared data table every list uses (16.23's CSV, 16.12's Locks row menu), so every other list must render unchanged.
  - 16.7's dashboard reads through the `MonitorPort` that 16.18 introduced.
  - 16.11's Task Manager resume becomes 16.21's Operations "Fix it". Until then, that finding links to the screen.
  - 16.12 extends Story 6.10's Locks list and its owner link.
  - 16.13 and 16.14 each remove one classic-link exemption (`ServiceForm`, `LdapConfigForm`).
- **Epic 18.** 16.4 waits on its PathPort follow-up; DW-1080 moved to Story 18.3. The branch has just integrated feature, with 18.2's namespaces, 18.14's `NamespacePort` case and the DW-1790 PathPort fix. Shared rosters and one-line lists (`EntityType`, `Prohibited`'s covered types, `ReadTool` counts, `AdminPort`'s mutating and bodyless types, the screen mirror) are unioned at each merge, so keep edits to them additive (inference). Slot B runs Epic 18 and also touches `ui/tools/**`, `scripts/ci-throwaway.sh` and EXPERIENCE.md. DW-1768 (the any-screen rail) awaits the owner.
- **Slot A.** It uses `ocupilot-slot-a` and the `ocupilot-ci` throwaway (52776/1975).
- **Release 1.0.3.** It is cut Tue 2026-09-29 at 14:00 PDT. No story starts after 12:00 PDT unless it reaches its boundary by 14:00.
