# Epic 16 Context: The remaining polish-week extras

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

This is the voting-week work. It gives the classic portal's remaining second-tier screens and actions an OcuPilot equivalent that both a person and the agent can use (FR-74, FR-76 to FR-78). It also covers the six stories deferred from the contest build (16.11 to 16.16) and the contest-survey additions (16.17 to 16.24). **Nothing here may break a Release 1 screen or a Release 1 agent write.** Anything that risks either waits for Stage 2.

- **Done:** 16.1, 16.2, 16.3, 16.5, 16.6, 16.8, 16.9 and 16.16 to 16.24.
- **Next on slot A:** implement 16.7 (planned), then plan 16.10, 16.11 and 16.12.
- **Waiting:** 16.4, on Epic 18's PathPort follow-up.
- **Backlog:** 16.13 to 16.15.

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
  - A screen is one hand-written descriptor, with its derived read tool and at least three suggested prompts.
  - An action ships with its confirmed write tool. Its governance key joins `Kernel/Governance/Baseline.cls` in the same change, enabled unless the criteria say disabled.
  - The tool's port gives a `Snippet` branch for every `Invoke` branch.
  - A field the instance normalizes on save declares a read-back `compare`.
  - A new prohibited arm needs reason text, because the Guardrails page is generated from the prohibited set.
  - Tests fail on each of these gaps.
- **Copy.** New strings go into EXPERIENCE.md's Fixed strings and `strings.ts` in the same change. Publish a refusal sentence once, and pin the kernel's reason equal to it. Edit EXPERIENCE.md in place so it stays at 993 lines and no line citation shifts. After touching it or epics.md, run `cd ui && npm run test:tools`.
- **Bundle.** 16.6 left the bundle at about 2.09 MB, against a 2107kB `maximumWarning`. A story that crosses the warning re-bases it to 5% above the measured total and updates the `angular-json.test.mjs` literal in the same change (DW-1166). Stop and ask above 3800kB. The hard stop is 4000kB.
- **Side-bar pins.** A screen-adding story extends every browser spec that pins its area's side-bar list (`grep -l ocu-side-bar-label ui/browser`). Story 16.5 missed this and CI failed (DW-1774). Stories 16.7 and 16.10 add OS management entries.
- **16.7.**
  - **License usage** shows the summary and the by-process, by-user and distributed views.
  - **Dashboard** draws every meter group: performance, ECP and shadowing, status, usage, errors and alerts, licensing, and task manager. The CPU meter belongs here.
  - **Meter source.** Meter names and values come from the instance's own `Monitor` answers. The classic `EnsembleMonitor` page is the Interoperability monitor and defines neither meters nor thresholds.
- **16.10.**
  - **List and actions.** The list shows each server's status. Start and stop update the row in place, and the activity log opens in the shared log viewer.
  - **Create, edit and delete** round-trip through the admin API, and delete confirms by name.
  - **Admin API routes.** The catalog maps them to `/ext-lang-servers` and `/ext-lang-server`, with its start, stop and activity routes. This sub-area is known from the UrlMap alone, so treat it as unverified until exercised.
  - **DW-253.** The template is evaluated at its default type, so derive one field list per server type, as `Wallet.Secret` does, and amend AD-3.
- **16.11.**
  - **Tool shape.** `Task.Manager` publishes no body template, so the tool is action-style, never a hand-typed field list.
  - **Suspend** first warns that no scheduled task will run until it is resumed.
  - **Banner.** The suspended banner sits above the table with a privilege-gated Resume, and the rows still list. Its copy for the suspended and stopped states is already published.
  - **DW-1638.** Task delete, suspend, resume and run must judge `TaskRules.Permitted` in `ArgumentProblem`, as the task edit does.
- **16.12.**
  - **Tool shape.** `Lock` publishes no body template, so the tool is action-style.
  - **Scopes.** It offers three scopes, each naming what it removes.
  - **DW-1073.** Warn from the endpoint's own 409 "is currently in a transaction", never from a `$zu` probe.
  - **DW-1074.** Suppress the Process details link on a row with a remote owner.
- **16.4 (waiting).** Task export and import have no admin-API route; they go through the vendor's `%SYS.Task`. The acceptance is the export-import round trip, not either half alone. The file field takes a root and a relative name through `Port/PathPort` (AD-21's sixth case). An import reads an existing file as a `source`. DW-1798 is decision-pending: whether an overwriting consumer is also refused OcuPilot's own bundle.
- **16.13 to 16.15 (backlog).**
  - **Service editor.** Disabling `%Service_WebGateway` is drawn disabled and refused for both callers. An address or authentication change on it is minted destructive. DW-1016: an empty diff cell needs a word.
  - **LDAP editor.** List, get and put stay synchronous, and its test goes through `AdminPort`'s async path. DW-1639: the Enabled column reads wrong.
  - **Egress line.** It derives from the configuration the request actually uses.

## Technical Decisions

- **16.7's spine amendments.**
  - **License usage (AD-5, AD-36).** It is a four-tab group, following the OAuth 2.0 tab-group precedent. It reads `Monitor` `LICENSEUSAGE` as a list over one named member (`source.rows`). The vendor's `maxRows` is the cap plus one, and any other answer fails the read.
  - **Dashboard (AD-29, AD-36).** It is a parts read, with one `{port: monitor, type: SENSORS}` part for CPU, answered behind `MonitorPort`'s gate (`%Admin_Operate:USE`, `%DB_IRISSYS:READ`).
  - **Auto-refresh (AD-43).** The Dashboard joins the refresh set as its ninth member, default off, so EXPERIENCE.md's Auto-refresh controls row must name it.
  - **Alerts (AD-7, DW-1116).** `PrometheusMetrics()` rewrites the SAM sensor baseline, a named AD-7 shape. Nothing calls `SYS.Monitor.SAM.Sensors.Alerts()` or `/api/monitor/alerts`, which advance the shared `LastAlertSent` cursor. The errors-and-alerts group reads the dashboard answer's counts.
- **16.6's changes to shared code.**
  - **Multi-select (AD-5, AD-19).** A list may declare one `multiSelect {action, eligible, max, ineligibleKey}`. The table keeps a checked set beside the unchanged single selection, and a list that declares nothing behaves as before.
  - **Pid sets (AD-13).** A `process` id may name a canonical, ascending set of pids.
  - **Body (AD-51).** `ProcessPort` builds the `BROADCAST` body.
- **Reads (AD-5, AD-36).**
  - A list declares `table`, and may declare one cross-screen row target.
  - Screen and tool share one bounded read that reports truncation, optionally with a per-row `rowGet`.
  - A tab group is one descriptor per tab.
- **Privilege (AD-8, AD-29).**
  - Pair sets are checked at call time, with no elevation. An administrative resource is required at `USE`, never `WRITE`.
  - To establish a set, read the backing class's own check in `irislib/`, then run a least-privileged principal on the throwaway. Never use `%Operator` to prove a denial.
  - A pair beyond the area's set goes in the screen's `ownPrivileges`, each a named AD-8 case.
  - A write tool adds pairs only where its vendor writes a database the screen's read does not, or where an endpoint its call must reach names the pair. It refuses by name before any port call.
- **Classic pages (AD-44).** A descriptor names the classic page class it replaces. A write tool that performs another page's operation names it in `CLASSICPAGES`, and its pairs union that page's custom resource.
- **Writes.**
  - **Two callers.** A screen action and the agent's write are one operation. The screen caller mints no proposal, emits no marker, and ignores read-only and the kill switch (AD-53, AD-55).
  - **Declared shape.** Each tool declares its port, `AdminPort` by default (AD-52). An action-style write declares its request type, sends no body, and fingerprints a declared subject that holds every precondition field (AD-51). A create fingerprints the target's absence (AD-54). A screen action accepts only declared values (AD-56).
  - **Prohibited set.** It is defined by effect and evaluated inside the confirm transition for both callers (AD-10, AD-34).
  - **Vendor class.** A port may use the vendor's `%SYS` class only as a named AD-27 case, after repeating the endpoint's guard.
  - **Queued writes.** A write that would queue is refused unless it is listed on `QUEUEDWRITES` (AD-26).
  - **Unaudited writes.** Measure each new write with auditing on. Where IRIS records nothing, name it as a further case in AD-15 and AD-53.
  - **Gates.** Governance is checked at dispatch and again at Confirm (AD-22). Every write reads its target back (AD-58) and renders a copy-out script (AD-59).
- **Files and logs (AD-21, AD-60).** No endpoint accepts a path. Log text reaches the model only through the sanitizer.
- **Identity and refresh (AD-11, AD-13, AD-14).**
  - Ids are encoded twice and decoded once.
  - Each write story adds its entity type's canonical-spelling rule, from the kernel's closed enum.
  - Nothing rendered from a reply or tool result requests any host.
- **Conventions.**
  - The client is zoneless and `OnPush`. Its framework-free `core/` stores are mirrored into signals and reset at sign-out, and API URLs are absolute.
  - The error envelope is `{error, reason, code, detail}`, and tools are named `<area>.<screen>.<verb>`.
  - A test depends on no other test, no order and no instance uptime.

## UX & Interaction Patterns

- **Placement.** A screen appears in the side bar only once it is built.
  - **OS management** gains License usage, Dashboard (meters) and External language servers (a list, then a form-page editor).
  - **Remove locks** is a dialog from the Locks row menu.
  - **Suspend Task Manager** is on the Task schedule command bar, with Export and Import as dialogs.
- **Meters.** Each shows label, value and unit, with its state as a word and a color. The state is Normal, Warning or Troubled, the dashboard's own words. A percentage meter turns warning at 85% and error at 95%. A meter shows "—" with a skeleton until its first value, and puts an error in its tooltip. The needle never animates.
- **Dialogs.** One level deep, never stacked, and titled with the action and target. A screen's destructive dialog asks for the typed name. A non-destructive warning, such as Suspend Task Manager, uses a primary button and states the consequence.
- **Controls and rows.** A gated control uses `aria-disabled` and reads "Requires <resource>". Color never carries meaning alone. Row actions update the row in place with "Changed", and every data table offers Download CSV.

## Cross-Story Dependencies

- **Keep intact.** Earlier Epic 16 work, and Epic 14's baseline, sanitizer and per-user read-only.
- **Within the epic.**
  - 16.6's multi-select changed the shared data table, so every other list must render as before.
  - 16.7 reads through 16.18's `MonitorPort`.
  - 16.11's Task Manager resume becomes 16.21's Operations "Fix it". Until then, that finding links to the screen.
  - 16.12 extends Story 6.10's Locks list and its owner link.
  - 16.13 and 16.14 each remove one classic-link exemption (`ServiceForm`, `LdapConfigForm`).
- **Epic 18.**
  - 16.4 waits on its PathPort follow-up.
  - Shared rosters and one-line lists are unioned at each merge, so keep edits to them additive: `EntityType`, `Prohibited`'s covered types, `ReadTool` counts, `AdminPort`'s mutating and bodyless types, and the screen mirror.
  - Slot B runs Epic 18 and also touches `ui/tools/**`, `scripts/ci-throwaway.sh` and EXPERIENCE.md.
  - DW-1768 (the any-screen rail) and DW-1815 (an ineligible row's reason) await the owner.
- **Slot A.** It uses `ocupilot-slot-a` and the `ocupilot-ci` throwaway (52776/1975).
- **Release 1.0.3.** It is cut Tue 2026-09-29 at 14:00 PDT. No story starts after 12:00 PDT unless it reaches its boundary by 14:00.
