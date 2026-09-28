# Epic 16 Context: The remaining polish-week extras

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

This is the voting-week work. It completes the second-tier screens and actions of the six areas, and it also takes the six stories deferred from the contest build (16.11 to 16.16) and the contest-survey additions (16.17 to 16.24).

- **Done:** 16.1, 16.2, 16.3, 16.8, 16.9, and 16.16 to 16.24.
- **Next on slot A:** 16.5, 16.6 and 16.7, then 16.10 to 16.12 as time allows.
- **Waiting:** 16.4 waits on Epic 18's PathPort follow-up.
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
  - **Screens and actions.** A screen is one descriptor with its derived read tool. An action ships with its confirmed write tool.
  - **Governance key.** The action's key joins `Kernel/Governance/Baseline.cls` in the same change, enabled unless the criteria say disabled.
  - **Write-tool gates.** Each write tool needs a `Snippet` branch for every `Invoke` branch, and a read-back comparison with `compare` declared for any field the instance normalizes on save. A new prohibited arm needs reason text, because the Guardrails page is generated from the prohibited set. Tests fail on each gap.
- **Copy.** New strings go into EXPERIENCE.md's Fixed strings and `strings.ts` in the same change. Edit EXPERIENCE.md in place and keep it at 993 lines (fold new strings into existing rows), so no `EXPERIENCE.md:n` citation shifts. Publish a refusal sentence once, and pin the kernel's reason equal to it.
- **Bundle.** 16.2 deployed at about 2.05 MB against a 2107kB `maximumWarning`. A story that crosses the warning re-bases it to 5% above the measured total and updates the `angular-json.test.mjs` literal with it (DW-1166). Stop and ask above 3800kB (hard stop 4000kB).
- **16.5.**
  - **List and actions.** The screen lists status, namespace, details and error count. Cancel, pause and resume each update the row in place.
  - **Both halves.** The admin API's `/async-results` covers only the tasks that API owns. The classic portal's `%SYS.BackgroundTask` jobs need a custom endpoint, and no admin-API class reaches them (its `RunningInDatabase` query is Final and Internal). Take that port decision here and record it in the spine, not by quietly widening AD-36's sources (DW-1080). If only the first half ships, the story states that it is partial parity.
  - **Async results.** Read a finished async task once only. A second read raises `ERROR #7846` and turns the instance state to Warning. `AdminPort` reads the end once and deletes the row. Views stop polling at the end and share one poller.
  - **Routed `AdminPort` defects.**
    - DW-1101: the port awaits only a 202 with an async location, so `ForgetTask` never runs for rows that end any other way.
    - DW-1136 and DW-1137, fixed together: the `ForgetTask` guard leaves a row behind on every unprivileged async read, and `ASYNCTASKPAIR` is a literal rather than IRISLOCALDATA's actual resource.
  - **Task row actions (DW-1638).** Delete, suspend, resume and run must judge `TaskRules.Permitted` the way the task edit does.
- **16.6.** Confirmation names how many processes will receive the message. This is the only multi-select screen, so the data table's selection model is extended here.
- **16.7.**
  - **License usage.** Show the summary plus the by-process, by-user and distributed views.
  - **Dashboard.** Draw every meter group: performance, ECP and shadowing, status, usage, errors and alerts, licensing, and task manager. The CPU meter belongs here too.
  - **Meter state and names.** Meter state reads as a word as well as a color. Names and thresholds come from the instance's own monitor answers, because `%CSP.UI.Portal.EnsembleMonitor` defines none of them.
  - **Alerts (DW-1116).** Every vendor `Alerts()` call advances the instance-wide SAM cursor, whatever the tag, which another scraper shares. So the monitoring half was never shipped, and alerts.log is read through `LogSourcePort` alone. The errors-and-alerts group re-opens that decision.
- **16.10.**
  - **Servers.** The screen lists servers with their status. Start and stop update the row in place, and the activity log opens in the shared log viewer.
  - **Admin API writes.** Create, edit and delete round-trip through the admin API, and delete confirms by name.
  - **Field lists (DW-253).** Derive one field list per language-server type, as `Wallet.Secret` does, and amend AD-3.
- **16.11 and 16.12.**
  - **Action-style.** `Task.Manager` and `Lock` publish no body template. Record each as action-style, never with a hand-typed field list.
  - **Suspend.** Suspending first warns that no scheduled task will run until it is resumed. The suspended banner carries a privilege-gated Resume.
  - **Lock removal.** It offers three scopes, each naming what it removes. It warns on the endpoint's own 409 "is currently in a transaction".
  - **Remote locks (DW-1074).** Suppress the Process details link on a lock row with a remote owner.
- **16.13 to 16.15.**
  - **Service editor.** Disabling `%Service_WebGateway` is drawn disabled and refused on the instance for both callers. Changing its addresses or authentication is minted destructive, with a consequence line. It also carries DW-1016, an empty-cell word for diff rows.
  - **LDAP editor.** It covers the classic LDAP page's fields. List, get and put stay synchronous, and test connection goes through `AdminPort`'s async path.
  - **Egress line.** It derives from the configuration the request actually uses. A local provider on a private network reads as not leaving the instance.

## Technical Decisions

- **Reads (AD-5, AD-24, AD-36).**
  - **Descriptor.** It is hand-written and carries at least three suggested prompts. A list declares `table`, with column kinds and an optional `emptyKey`, and may declare one cross-screen row target, such as the owning process.
  - **Shared read.** Screen and tool share one bounded read that reports truncation. Its source is a port endpoint, a kernel store's guarded list, or a composition of other screens' reads.
- **Privilege (AD-8, AD-29).**
  - **Pair sets.** They are checked at call time, with no elevation. An administrative resource is required at `USE`, never `WRITE`.
  - **Confirming a pair set.** `ResourcesOR()` is a lower bound. Read the backing class's own check in `irislib/`, then run a least-privileged principal on the throwaway. Never use `%Operator` to prove a denial.
  - **A screen's own pairs.** A screen that needs pairs beyond its area's declares them in `ownPrivileges`, and each is a named case in AD-8. The newest is Web sessions' `%Admin_Operate:USE`.
  - **A tool's extra pairs.** A write tool may add pairs only in two cases, each measured and named in AD-8. The first is where the vendor writes a database the screen's read does not, such as `webapp.sessions.end`'s `%DB_IRISSYS:WRITE`. The second is where an endpoint the call must reach names the pair, such as the `AsyncResult` poll's `%Admin_Operate:USE`.
  - **Dashboard sensors.** `MonitorPort` reads them in-process under `%Admin_Operate:USE` and `%DB_IRISSYS:READ`.
- **Writes.**
  - **Two callers.** A screen action and the agent's write are one operation. The screen caller mints no proposal and ignores read-only and the kill switch (AD-53, AD-55).
  - **Declared shape.** Each tool declares its port (AD-52). An action-style write declares its request type, sends no body, and fingerprints a declared subject (AD-51). A create fingerprints the target's absence (AD-54). A screen action accepts only declared values, and list fields change by a server-side delta (AD-56).
  - **Prohibited set.** It lives once in the kernel, is defined by effect, and is evaluated inside the confirm transition (AD-10, AD-34).
  - **Vendor class.** Where the admin API cannot carry a call, the port may use the vendor's documented `%SYS` class after repeating its guard. Each such use is a new named case in AD-27.
  - **Queued writes.** A write that would queue is refused unless it is on `QUEUEDWRITES`. No slice writes polling logic (AD-26).
  - **Unaudited writes.** Measure with auditing on whether IRIS records an event for each new write. Where it records none, as with OAuth revoke and `WebSession` `DELETE`, the agent's marker is the only record and the screen action leaves no audit row. Name the write as a further case in AD-15 and AD-53.
  - **Governance and read-back.** Governance is checked at dispatch and again at Confirm (AD-22). Every write reads its target back (AD-58).
- **Files and logs (AD-21, AD-60).**
  - **No paths.** No endpoint accepts a path. A log is a fixed-enum `LogSourcePort` source.
  - **Server-path fields (16.4).** They take a root and a relative name through `Port/PathPort`, with `%Admin_FileSystemAccess:USE` and `%DB_IRISSYS:READ`, and resolve again at the write.
  - **Model input.** Log text reaches the model only through the sanitizer.
- **Identity and refresh (AD-11, AD-13, AD-14, AD-43, AD-44).**
  - **Ids and entity types.** Ids are encoded twice and decoded once, and each write story adds its entity type's canonical-spelling rule. Entity types come from the kernel's closed enum.
  - **Classic page.** Each descriptor names the classic page class it replaces.
  - **Auto-refresh.** A screen joins it only by declaring it and appearing in EXPERIENCE.md's Auto-refresh roster.
  - **No outbound requests.** Nothing rendered from a reply or tool result requests any host, the instance's own origin included, so images render as alt text.
- **Conventions.**
  - **Client.** It is zoneless and `OnPush`. Framework-free `core/` stores are mirrored into signals and reset at sign-out, and API URLs are absolute (AD-19, AD-20).
  - **Errors and naming.** The envelope is `{error, reason, code, detail}`, and tools are named `<area>.<screen>.<verb>`.
  - **Tests.** They depend on no other test, no order and no instance uptime, because CI shards regroup.

## UX & Interaction Patterns

- **Placement.** It follows EXPERIENCE.md, and a screen appears in the side bar only once it is built.
  - **Tasks side bar:** Background tasks. Export and Import are dialogs on the Task schedule command bar, which also holds Suspend Task Manager.
  - **OS management side bar:** License usage (meters), Dashboard (meters), and External language servers (a list, then a form-page editor).
  - **Dialogs from lists:** Broadcast comes from the Processes multi-select, and Remove locks from the Locks row menu.
- **Meters.** Each shows label, value and unit, with the dashboard's own state (Normal, Warning or Troubled) as a word and a color. A meter shows "—" with a skeleton until its first value arrives, and its needle never animates.
- **Dialogs.** They are one level deep and never stack, and the title names the action and the target. A screen's destructive dialog asks for the typed name; an agent proposal does not. A non-destructive warning, such as Suspend Task Manager, uses a primary button and states the consequence.
- **Controls.** A gated control uses `aria-disabled`, never `disabled`, and reads "Requires <resource>".
  - **Instance-only refusals.** A refusal the list cannot show stays offered, and the instance answers the click with the published sentence (16.2's preserve-mode session).
  - **Color and rows.** Color never carries meaning alone. Row actions update the row in place with the "Changed" highlight, and every data table offers Download CSV.

## Cross-Story Dependencies

- **Keep intact.**
  - **Earlier Epic 16 work:** try-it and Copy as curl (16.1, 16.24); Web sessions' own-session and preserve-mode refusals (16.2, AD-10); `Kernel.Shell.Effective` and Security's own pairs (16.3, 16.19); the log viewers and hub, whose members are pinned to the listed Logs screens (16.8, 16.9); the ledger viewer (16.16); and 16.17 to 16.23.
  - **Epic 14:** it is done, and its baseline, sanitizer and per-user read-only bind new work.
- **16.4.** It waits on Epic 18's PathPort follow-up: DW-1778, a read-existing file mode so an import can name an existing file, and DW-1777, which refuses the instance's configuration file and its system databases. It must not build on the overwrite workaround.
- **Within the epic.**
  - 16.11's Task Manager resume becomes 16.21's Operations Fix it. That finding links to the screen until then.
  - 16.13 and 16.14 each remove one AD-44 classic-link exemption (`ServiceForm`, `LdapConfigForm`).
  - 16.12 extends Story 6.10's Locks list.
- **Slot B runs Epic 18.** Both epics touch `ui/tools/**`, `scripts/ci-throwaway.sh` and EXPERIENCE.md, so keep shared roster edits additive (inference). DW-1768 (the any-screen rail) awaits the owner after the voting week.
- **Slot A.** It uses `ocupilot-slot-a` and the `ocupilot-ci` throwaway (52776/1975).
- **Release 1.0.3.** It is cut Tue 2026-09-29 at 14:00 PDT. No story starts after 12:00 PDT unless its boundary lands by 14:00.
