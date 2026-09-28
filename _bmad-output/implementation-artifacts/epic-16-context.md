# Epic 16 Context: The remaining polish-week extras

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

This is the voting-week work. It completes the second-tier screens and actions of the six areas, and it also takes the six stories deferred from the contest build (16.11 to 16.16) and the contest-survey additions (16.17 to 16.24).

- **Done:** 16.1, 16.3, 16.8, 16.9, and 16.16 to 16.24.
- **Next on slot A:** 16.2, 16.5, 16.6 and 16.7, then 16.10 to 16.12 as time allows.
- **Waiting:** 16.4 waits on Epic 18.
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
  - **Governance key.** The action's governance key joins `Kernel/Governance/Baseline.cls` in the same change, enabled unless the criteria say disabled.
  - **Write-tool gates.** Each write tool needs a `Snippet` branch for every `Invoke` branch, and a read-back comparison with `compare` declared for any field the instance normalizes on save. Any new prohibited arm needs reason text, because the Guardrails page is generated from the prohibited set. Tests fail on each gap.
- **Copy.** New strings go into EXPERIENCE.md's Fixed strings and `strings.ts` in the same change. Edit EXPERIENCE.md in place and keep it at 993 lines (fold new strings into existing rows), so no `EXPERIENCE.md:n` citation shifts. Publish a refusal sentence once, and pin the kernel's reason equal to it.
- **Bundle.** The bundle is about 2.05 MB against a 2107kB `maximumWarning`. A story that crosses the warning re-bases it to 5% above the measured total, and updates the `angular-json.test.mjs` literal with it (DW-1166). Stop and ask above 3800kB (hard stop 4000kB). On-demand loading is a separate later story.
- **16.2.**
  - **List.** The screen lists user, application and process, and the process links to Process details.
  - **End.** Ending a session confirms by naming it.
  - **Self-protection.** Ending the caller's own session is refused on the instance as well as in the UI, the same shape as the process self-protection.
- **16.5.**
  - **List and actions.** The screen lists status, namespace, details and error count. Cancel, pause and resume each update the row in place.
  - **Both halves.** The screen needs the admin API's `/async-results` for the tasks that API owns, and a custom endpoint for the classic portal's `%CSP.UI.System.BackgroundTask` jobs. If only the first half ships, the story states that it is partial parity.
  - **Async results.** Read a finished async task once only. A second read raises `ERROR #7846` and turns the instance state to Warning. `AdminPort` reads the end once and deletes the row. Views stop polling at the end and share one poller.
  - **Routed entries.** DW-1080 (Database details' background tasks) and DW-1101 (`ForgetTask` does not always run).
- **16.6.** Confirmation names how many processes will receive the message. This is the only multi-select screen, so the data table's selection model is extended here.
- **16.7.**
  - **License usage.** Show the summary plus the by-process, by-user and distributed views.
  - **Dashboard.** Draw every meter group: performance, ECP and shadowing, status, usage, errors and alerts, licensing, and task manager. The CPU meter belongs here too.
  - **Meter state** reads as a word as well as a color.
  - **Names and thresholds** come from the instance's own monitor answers. `%CSP.UI.Portal.EnsembleMonitor` defines none of them.
- **16.10.**
  - **Server actions.** The screen lists servers with their status. Start and stop update the row in place.
  - **Activity log.** It opens in the shared log viewer.
  - **Admin API writes.** Create, edit and delete round-trip through the admin API, and delete confirms by name.
  - **DW-253.** Derive one field list per language-server type, as `Wallet.Secret` does, amending AD-3.
- **16.11 and 16.12.**
  - **Action-style.** `Task.Manager` and `Lock` publish no body template. Record each as action-style, never with a hand-typed field list.
  - **Suspend.** Suspending the Task Manager first warns that no scheduled task will run until it is resumed. The suspended banner carries a privilege-gated Resume.
  - **Lock removal.** It offers three scopes, each naming what it removes. It warns when the owning process is in a transaction, based on the endpoint's own 409 "is currently in a transaction".
  - **DW-1074.** Suppress the Process details link on a lock row with a remote owner.
- **16.13 and 16.14.**
  - **Service editor.** Disabling `%Service_WebGateway` is drawn disabled with the published sentence and is refused on the instance for both callers. Changing that service's addresses or authentication is permitted, minted destructive with a consequence line. It also carries DW-1016, an empty-cell word for diff rows.
  - **LDAP editor.** It covers the classic LDAP page's fields. List, get and put stay synchronous. Test connection goes through `AdminPort`'s async path and reports the instance's own result text.
- **16.15.** The egress line derives from the configuration the request actually uses. A local provider on a private network reads as not leaving the instance.

## Technical Decisions

- **Reads (AD-5, AD-24, AD-36).**
  - **Descriptor.** It is hand-written and carries at least three suggested prompts. A list declares `table`, with column kinds and an optional `emptyKey`. An editor takes `sideBarPosition` 0.
  - **Shared read.** Screen and tool share one bounded read that reports truncation.
  - **Sources.** A read's source is a port endpoint, a kernel store's guarded list, or a composition of other screens' reads.
  - **Cross-screen link.** A list may declare one cross-screen row target, such as the owning process.
- **Privilege (AD-8, AD-29).**
  - **Pair sets** are checked at call time, with no elevation. An administrative resource is required at `USE`, never `WRITE`.
  - **`ResourcesOR()` is a lower bound.** Confirm a screen's pair set by reading the backing class's own check in `irislib/`, then by running a least-privileged principal on the throwaway. Never use `%Operator` to prove a denial.
  - **Extra pairs.** A screen that needs pairs beyond its area's declares them in `ownPrivileges`. A tool may add pairs only under AD-8's named clauses.
  - **Dashboard sensors.** `MonitorPort` reads them in-process under `%Admin_Operate:USE` and `%DB_IRISSYS:READ`.
- **Writes.**
  - **Two callers.** A screen action and the agent's write are one operation. The screen caller mints no proposal and ignores read-only and the kill switch (AD-53, AD-55).
  - **Declared shape.** Each tool declares its port (AD-52). An action-style write declares its request type, sends no body, and fingerprints a declared subject (AD-51). A create fingerprints the target's absence (AD-54). A screen action accepts only declared values, and list fields change by a server-side delta (AD-56).
  - **Prohibited set.** It lives once in the kernel, is defined by effect, and is evaluated inside the confirm transition (AD-10, AD-34).
  - **Vendor class.** Where the admin API cannot carry a call, the port may use the vendor's documented `%SYS` class after repeating its guard. Each such use is a new named case in AD-27.
  - **Queued writes.** A write that would queue is refused unless it is on `QUEUEDWRITES`, and no slice writes polling logic (AD-26).
  - **Governance and read-back.** Governance is checked at dispatch and again at Confirm (AD-22). Every write reads its target back (AD-58).
- **Files and logs (AD-21, AD-60).**
  - **No paths.** No endpoint accepts a path. A log is a fixed-enum `LogSourcePort` source.
  - **Server-path fields (16.4)** take a root and a relative name through `Port/PathPort`, with `%Admin_FileSystemAccess:USE` and `%DB_IRISSYS:READ`.
  - **Model input.** Log text reaches the model only through the sanitizer.
- **Identity and refresh (AD-11, AD-13, AD-14, AD-43, AD-44).**
  - **Ids** are encoded twice and decoded once. Each write story adds its entity type's canonical-spelling rule.
  - **Entity types** come from the kernel's closed enum.
  - **Classic page.** Each descriptor names the classic page class it replaces.
  - **Auto-refresh.** A screen joins it only by declaring it and appearing in EXPERIENCE.md's Auto-refresh roster.
  - **No outbound requests.** Nothing rendered from a reply or tool result requests any host, including the instance's own origin, so images render as alt text.
- **Conventions.**
  - **Client:** zoneless; `OnPush`; framework-free `core/` stores mirrored into signals and reset at sign-out; absolute API URLs (AD-19, AD-20).
  - **Errors and naming:** the envelope is `{error, reason, code, detail}`, and tools are named `<area>.<screen>.<verb>`.
  - **Tests** depend on no other test, no order, and no instance uptime, because CI shards regroup.

## UX & Interaction Patterns

- **Placement** follows EXPERIENCE.md, and a screen appears in the side bar only once it is built:
  - Web sessions: Web applications side bar.
  - Background tasks: Tasks side bar. Export and Import are dialogs on the Task schedule command bar.
  - License usage (meters), Dashboard (meters), and External language servers (list, then form-page editor): OS management side bar.
  - Broadcast: a dialog from the Processes multi-select.
  - Remove locks: a dialog from the Locks row menu.
  - Suspend Task Manager: the Task schedule command bar.
- **Dialogs** are one level deep and never stack, and the title names the action and the target. A screen's destructive dialog asks for the typed name; an agent proposal does not. A non-destructive warning, such as Suspend Task Manager, uses a primary button and states the consequence. Both Task Manager banner sentences are already published.
- **Controls.** A gated control uses `aria-disabled`, never `disabled`, and reads "Requires <resource>". Color never carries meaning alone: meter state and severity each carry a word. Row actions update the row in place with the "Changed" highlight. Download CSV comes with every data table.

## Cross-Story Dependencies

- **Keep intact:** try-it and Copy as curl (16.1, 16.24); `Kernel.Shell.Effective` and Security's own pairs (16.19, 16.3); the log viewers and hub, whose members are pinned to the listed Logs screens (16.8, 16.9); the ledger viewer (16.16); and 16.17 to 16.23. Epic 14 is done, and its baseline, sanitizer and per-user read-only bind new work.
- **16.4** waits until Epic 18's PathPort follow-ups, DW-1778 and DW-1777, are on feature. It must not build on the overwrite workaround.
- **Within the epic.**
  - 16.11's Task Manager resume becomes 16.21's Operations Fix it. That finding links to the screen until then.
  - 16.13 and 16.14 each remove one AD-44 classic-link exemption (`ServiceForm`, `LdapConfigForm`).
  - 16.12 extends Story 6.10's Locks list.
- **Slot B runs Epic 18**, with 18.2 and 18.14 next. Both epics touch `ui/tools/**`, `scripts/ci-throwaway.sh` and EXPERIENCE.md, so keep shared roster edits additive (inference). DW-1768 (the any-screen rail) is an owner decision.
- **Slot A** uses `ocupilot-slot-a` and the `ocupilot-ci` throwaway (52776/1975).
- **Release 1.0.3** is cut Tue 2026-09-29 at 14:00 PDT. No story starts after 12:00 PDT unless its boundary lands by 14:00.
